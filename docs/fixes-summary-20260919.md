# 修复摘要 · 2026-09-18 ~ 09-19（语音链路打通）

本轮把**语音输入输出全链路**在真机上打通，并定位/修复了阻塞它 4 天的 mediad 崩溃。
所有结论均有 UART 串口日志（`dmesg`）原始证据。

---

## 一、🔴 mediad 每次播放结束必崩 —— 最关键的修复

### 现象
任何播放会话 `stop` 之后，mediad 进程**整体消失**。表现为"板子像死机"、之后所有
`media_player_open` / `media_recorder_open` 返回 `-22`。

### 根因（实锤日志）
```
[31] Pending command: unlink _
[31] process abufsrc@apb unlink _
[31] media_player_on_event_cb: received unlink event form audio_output.
[31] Assertion !li->status_in failed at ffmpeg/libavfilter/avfilter.c:1760
```

`ff_inlink_request_frame()` 的契约（`libavfilter/filters.h:384`）：

> **"it must not be called when the link has a non-zero status, and thus does not acknowledge it."**

而 `adevsink_activate()` 无条件调用它：

```c
    if (ff_inlink_check_available_frame(inlink)) { ... }

    ff_inlink_request_frame(inlink);   /* 没检查 link 状态 */
```

同时 `abufsrc` 的 `unlink` 恰恰给这条 link 打了 EOF（`asrc_abufsrc.c:615`）：

```c
        ff_outlink_set_status(ctx->outputs[i], AVERROR_EOF, AV_NOPTS_VALUE);
```

→ EOF 沿 `volume@VolApb` 传到 `adevsink@pcm0p` 的 inlink → sink 被激活 → 请求帧 → **assert 打死整个进程**。

### 修复
两处同源缺陷，均按同目录 `asink_alsasink.c:261` 的既有写法加状态守卫：

| 文件 | 函数 | 改动 |
|---|---|---|
| `libavfilter/asink_adevsink.c` | `adevsink_activate()` | `if (!ff_outlink_get_status(inlink)) ff_inlink_request_frame(inlink);` |
| `libavfilter/asink_abufsink.c` | `request_frame()` | 状态判断补 `\|\| ff_outlink_get_status(link)` |

`abufsink` 那处的坑更隐蔽：`ff_inlink_acknowledge_status()` **首次**确认 EOF 时返回的是
**`1`**（不是负数），原代码只判了 `if (ret < 0) continue;`，于是同样掉进 `ff_inlink_request_frame`。
**每处只炸一次** —— 与"第一次好好的、之后全废"的现场表现完全吻合。

### 验证
修复后连跑录音→停止→关闭→播放→停止→关闭，**mediad 全程存活**，`!li->status_in`
再未出现。

---

## 二、🔴 mediad 起不来 —— criteria.txt 判重名

`vendor/.../src/etc/media/criteria.txt` 有 8 行把判据名写了两次：

```
ExclusiveCriterion Media Media : abufsrc@Media     ← "Media" 重复
ExclusiveCriterion MicMode MicMode : off on = on
```

`pfw/sanitizer.c` 的判重检查报 `Duplicate string 'Media'` → mediad 启动断言失败 → **mediad 死了 17 天**。

修复：删掉重复 token。A/B 验证（v18 镜像 8 处重复 → v19 0 处）。

> ⚠️ `/etc` 的固件打包源是 `src/etctmp/etc/`，**不是 `src/etc/`**；且改 `etctmp` 后必须
> **删除 `src/etctmp.c`** 才能重新生成。这是 17 天没找到根因的元凶。

---

## 三、🟠 火山语音服务迁移

| 服务 | 旧（失败） | 新（可用） | 关键错误码 |
|---|---|---|---|
| TTS | `volc.service_type.10029`（1.0，企业认证 2000 元/月） | **`seed-tts-2.0`** + `zh_male_m191_uranus_bigtts` | `403/45000030` = 凭证有效但资源未授权 |
| ASR | v2 `/api/v2/asr` + `seedasr` | **v3 `/api/v3/sauc/bigmodel_async`** + `volc.bigasr.sauc.duration` | `401/45000010` = 凭证错 |

ASR v3 额外要点：
- 双请求头 `X-Api-App-Key` + `X-Api-Access-Key`（不是单 `Authorization`）
- 二进制帧 `[0x11, msg_type, serialization, 0x00][4B length][payload]`，msg_type `0x10/0x20/0x22`
- 服务端会发 **PING 控制帧**（零长 payload），不处理会报 `Frame too short: 0` → `recv error: -71`

---

## 四、🟠 录音停止死锁 / 播放格式不匹配

| 问题 | 根因 | 修复 |
|---|---|---|
| 录音停止后 `pthread_join` 永不返回 | 录音线程阻塞在 AF_UNIX `recv()`；NuttX 的 local-socket 接受了 `SO_RCVTIMEO` 但**从不使用** `s_rcvtimeo` | 改用 `poll(rsock, 100ms)` 前置检查 |
| `Channel layout change is not supported` | 图**不做** mono↔stereo 自动转换，TTS 输出 24k 单声道 vs sink 48k 立体声 | `audio_playback.c` 按 48k 立体声开播放器，`pb_convert()` 线性插值重采样 + 单声道复制成立体声 |
| 播放 `0 bytes written` / "End of file" | `media_player_proc_dat` 复用了 `ret`，把过期的 `AVERROR_EOF` 当启动失败上报 | 拆出独立 `aret` |
| WS 帧 `too large: 43470` | 32KB 缓冲不足 | 提到 256KB |

---

## 五、🟠 配置路径 —— 所有配置 `(not set)`

`include/agent_config.h:96`：

```c
#define AGENT_CONFIG_FILE AGENT_DATA_DIR "/config/config.json"
```

配置**必须**在 `/data/ai_agent/config/config.json`。推到顶层 `/data/ai_agent/config.json`
的表现是 `config_show` 全部 `(not set)`、语音报 `ASR credentials not configured`。

（注意不对称：`cron.json` 反而**必须**在顶层 —— `AGENT_CRON_FILE = AGENT_DATA_DIR "/cron.json"`。）

---

## 六、验证证据（真机）

| 项 | 证据 |
|---|---|
| mediad 稳定性 | 5 轮录音/播放压测，进程全程存活 |
| 录音 | `recording thread exit: 1034 chunks, 220784 read` |
| 录音收尾 | `cmd: close` → `media_recorder_thread: abufsink@acap recorder thread exit.` |
| TTS 合成 | `[volc_tts] TTS: synthesized 86016 PCM bytes (7 chunks)` |
| 播放出声 | `PREPARED(1) ret:0 → STARTED(2) ret:0 → COMPLETED(6) ret:0`，**耳机实听确认** |

---

## 七、更正：一条被误判的现象

调试中途观察到"录音会话结束后图槽位不释放（第二次 `open` 报 -22）"，一度按 mediad 缺陷处理。
**最终定位为测试工具 `mediatool` 自身的缺陷**：其缓冲区线程 `mediatool_file` 在 `stop` 后
卡死不退，导致 `close` 命令根本未执行（客户端 proxy 日志中 recording 路径**只有 `stop` 没有 `close`**，
而 player 路径两者都有）。同一时刻 ai_agent 走的产品路径日志显示 `close` 到达、线程正常退出。

**结论：槽位泄漏是测试工具问题，产品路径无此缺陷。** 记录于此以免后人重走。

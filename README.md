# 木木 · Gemini-S1 AI 随身健康守护官

> 队伍：mutumuzi（木土木子）｜赛道：**AI 硬件产品创新**（真机开发：润芯微 Gemini-S1，全志 R528）
> 作品形态：板载 AI Agent（多 LLM 路由 + 技能系统 + 定时调度 + 多渠道交互）在端侧硬件的完整落地，以及支撑它的三层固件级排障与修复。

---

## 一、作品简介

在 **Gemini-S1（R528）开发板**上端到端跑通了一个"会自己干活"的 AI 随身助理：

- **全自动早间简报**：每天 08:00 由板载定时任务触发 → AI Agent 自主完成「读技能 → 查时间/天气(Tavily 实时检索) → 读用户档案与健康记忆 → 调 MiMo LLM 生成图文简报」，全程无人值守，已连续多轮真机验证；
- **技能(Skill)系统**：板端 10 个技能（早间简报/天气/备忘/翻译/新闻摘要/健康等），文件哈希变更自动热刷新工具集；
- **多渠道交互**：CLI/SSH 管道、BLE GATT（修复后）、飞书/微信通道（代码就绪）共用同一 Agent 内核；
- **持续记忆**：对话会话、用户档案、健康数据落到 `/data`，重启不丢，LLM 配置与密钥持久化。

亮点不在单点功能，而在"**把一个消费级 AI Agent 栈完整压进 128MB NAND + 双核 R528 的真机**"过程中解决的系统性工程问题：白屏黑屏/mediad 音频栈崩溃/蓝牙栈溢出/HTTP chunked 响应截断/定时任务调度语义等——全部有串口日志与根因分析可核实（见 `docs/` 与 `logs/`）。

## 二、选题方向

**AI 硬件产品创新**。理由：

1. 全部工作在**真机**完成（非模拟器），验证手段是 UART 串口日志、屏幕实拍、SSH 会话——真机证据链完整；
2. 产品闭环成立：定时触发 → AI 自主生成 → 多渠道送达，是"端侧 AI 服务"的完整形态；
3. 排障过程深度触及 openvela/NuttX 内核与多媒体栈（mediad/ffmpeg/蓝牙），体现了从产品到内核的纵向能力。

## 三、目录结构

```text
logs/                  AI Coding 对话日志（2026-07-17 ~ 09-08，14MB+，格式见 logs/README.md）
docs/                  固件修复补丁与摘要
  ├─ ai-agent-chunked-fix.patch             HTTP chunked 响应截断修复（已提公共仓 PR #27）
  ├─ ai-agent-cron-inbound.patch            v12：cron 定时任务自动触发 AI 简报（核心功能）
  ├─ ai-agent-ble-gatt-fixes-*.patch        蓝牙 BLE 广播/栈溢出修复
  ├─ firmware-fixes-board-defconfig-*.patch 板级 defconfig 修复（mediad alsasink 白屏根因）
  ├─ fixes-summary-*.md                     各阶段修复摘要（根因 + 验证证据）
  └─ status-2026-09-08.md                   当前进度快照（功能/验证/待办）
skills/                部署到板端 AI Agent 的技能与记忆种子文件
  ├─ ai-dev-workflow/SKILL.md               自建 Skill：AI 辅助板端开发的完整流程沉淀
  ├─ memory-seed.md / morning-health-briefing.md   板端技能/记忆内容（.md 见仓内说明）
scripts/
  └─ deploy_skills.sh                       技能/记忆批量部署脚本
app/ board/ quickapp/   组委会脚手架示例（本作品未使用，可忽略）
```

> 说明：按大赛规则，**openvela 公共仓（packages/nuttx/vendor）零改动**。本作品对公共仓源码的修改全部以 **PR + patch 双形式**交付：
> - 已提交公共仓 PR（`open-vela/packages_ai_agent` → `dev-ai-contest-2026`）：chunked 读取修复 **PR #27**（ci/cla 全绿，待组委会合入）；
> - 全部改动点同时以 patch 存于 `docs/`，可离线审阅。

## 四、运行方式（复现路径）

### 4.1 拉取工程

```bash
repo init -u https://github.com/open-vela/contest2026_218_mutumuzi -b dev-ai-contest-2026 -m contest2026_218_mutumuzi.xml
repo sync -c -j8
```

### 4.2 应用代码改动

```bash
# 方式 A：公共仓已合入（PR #27 合入后）
cd packages/ai_agent && git fetch origin dev-ai-contest-2026

# 方式 B：PR 未合入时，手工应用补丁（路径相对 openvela 工作区根）
git -C packages/ai_agent apply ../contest2026_218_mutumuzi/docs/ai-agent-chunked-fix.patch
git -C packages/ai_agent apply ../contest2026_218_mutumuzi/docs/ai-agent-cron-inbound.patch
# vendor 板级修复（mediad/白屏）：
git apply ../contest2026_218_mutumuzi/docs/firmware-fixes-board-defconfig-20260821-0824.patch
```

### 4.3 编译固件

```bash
./build.sh vendor/allwinnertech/boards/r528/r528s3-gemini-s1/configs/nsh_minidisplay -e -Wno-error -j8
```

（真机固件打包走 allwinner 官方 `pack_img.sh`，产物 `rtos_nuttx_*.img`；本仓只含源码级改动，烧录工具链属真机环境，详见 `logs/` 中烧录会话。）

### 4.4 板端部署与运行（真机）

1. 烧录后基础配置：`date -s` 校时（无 RTC）→ WiFi（`wapi`）→ SSH；
2. 部署技能/记忆：`sh scripts/deploy_skills.sh`（或手工 push `skills/` 到板端 `/data/ai_agent/`）；
3. 配置 LLM：`ai_agent` 内 `set_llm <host> <model> <key>`（本项目用 MiMo token-plan + mimo-v2.5-pro；LLM 后端可路由切换）；
4. 常驻运行：`ai_agent &`；
5. 定时任务：向 Agent 说"每天早上 8 点生成简报"（cron_add 持久化到 `/data/ai_agent/cron.json`）；
6. 验证：08:00 自动触发全自动简报；随时 `ask 早间简报` 手动触发。

## 五、AI Coding 使用说明

**协作模式**：Claude Code（Anthropic 官方 CLI）作为主力开发协作者，全程通过 SSH/UART 直接驱动真机：

| 环节 | AI 承担的工作 | 代表会话 |
|---|---|---|
| 根因分析 | 从 1.5Mbps 串口海量日志中定位白屏根因（alsasink 缺失 → mediad panic 因果链）、蓝牙栈溢出、chunked 截断 | logs/2026-08-2x |
| 源码修改 | ai_agent/vendor 全部补丁由 AI 编写（含 defconfig 三行修复、cron 入站改造） | docs/*.patch |
| 真机调试 | 会话式驱动板端命令、解析回显、迭代验证 | logs/2026-09-0x |
| 工程沉淀 | 关键坑（烧录姿势/时钟/密钥/CLA）自动写入跨会话记忆，形成本仓 Skill | skills/ai-dev-workflow/ |

**实际帮助**：白屏问题卡了 8 天，AI 通过日志因果链定位到"media 配置与固件裁剪不一致"这一非直观根因；若纯人工排查，串口日志吞吐（每秒数十条 syslog）下的归因成本极高。完整原始对话见 `logs/`。

## 六、功能与验证状态（如实声明）

| 功能 | 状态 | 证据 |
|---|---|---|
| 早间简报（手动 ask） | ✅ 完成，多次验证 | logs/2026-09-01~08 |
| 全自动简报（cron 08:00 触发，无人值守） | ✅ 完成，v12 起 4+ 轮全绿，含真实天气 | logs/2026-09-07~08；docs/ai-agent-cron-inbound.patch |
| 白屏修复（mediad alsasink） | ✅ 完成，v11 验证 | docs/firmware-fixes-* |
| BLE 广播/栈修复 | ✅ 完成 | docs/ai-agent-ble-gatt-fixes-* |
| chunked 读取修复 | ✅ 完成（公共仓 PR #27 待合） | docs/ai-agent-chunked-fix.patch |
| 简报上屏（LVGL 卡片） | 🚧 开发中（2026-09-08 收尾阶段） | — |
| TTS 语音播报 | ⚠️ 部分：音频栈已修复，云端 TTS 引擎未接入（需账号密钥）；本地 PCM→喇叭通路验证中 | logs/2026-09-08 |
| 屏幕常驻 UI（时间/温湿度/距离卡片） | ✅ 板载 luncher 原生功能，正常 | 实拍见提交材料 |

> 诚实说明：本作品**未使用**示例骨架 app/board/quickapp；天气检索质量（Tavily 页面解析）与"简报上屏"两项处于"可用但待打磨"状态，均已如实标注。代码行数不是亮点，真机全链路与系统性排障才是。

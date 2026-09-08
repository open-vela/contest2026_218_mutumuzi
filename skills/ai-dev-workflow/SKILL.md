---
name: ai-board-dev-workflow
description: AI 硬件开发板上用 AI 协作者做端到端开发的标准工作流——从环境恢复、根因排查到提交归档。Trigger: 板子开发、固件排障、AI Coding 大赛材料、烧录、串口日志分析、参赛提交。
---

# AI 辅助板端开发工作流（AI Hardware Board Dev Workflow）

> 本 Skill 沉淀了「木木 · Gemini-S1 AI 随身健康守护官」项目从 0 到 1 全程反复使用的开发流程。
> 适用对象：用 Claude Code 等 AI 协作者开发 openvela/NuttX 真机（R528 系）的队伍。

## 触发词

板子开发 / 固件排障 / 烧录失败 / 串口日志 / 白屏黑屏 / 驱动调试 / AI Coding 日志导出 / 参赛材料提交

## 工作前提（一次性准备）

- 真机链路三件套：USB 数据线（烧录/adb）+ USB-TTL 串口线（1.5Mbps 日志）+ SSH 通道（WiFi）
- AI 协作者具备：SSH 到板子的密钥、板端 shell（nsh）语法知识、源码树只读访问
- 板端 `/data` 持久化区存放：SSH 密钥、LLM 配置（config.json）、技能、cron.json

## 操作步骤

### 1. 环境恢复（每次断电重启后，10 分钟内）
1. `date -s` 校时（板子无 RTC）→ WiFi（`wapi psk/essid` + `renew wlan0`）→ 记录新 IP（DHCP 会变）
2. 起 `sshd -k /data/k -a /data/a <IP> &`（**必须加 `&`**，前台会占死控制台）
3. 起常驻 `ai_agent &`；**不要在同一控制台敲命令**（ai_agent CLI 会抢 console 输入，改用 adb shell）
4. 验证：`dmesg` 看 `Loaded N cron jobs` / Tools JSON loaded 字节数非 0

### 2. 根因排查（白屏/崩溃类疑难）
1. 先抓证据再下结论：串口日志全量回放，按时间线对齐"现象时间戳"
2. 沿因果链反向查：现象 → 崩溃点 → 配置/裁剪差异（例：白屏根因 = defconfig 的 ffmpeg 没编 alsasink 而 graph.conf 引用了它 → mediad panic）
3. 修复走最小改动（如 defconfig 三行），产物命名带版本号（v10/v11/v12），验证点写死清单
4. 关键坑记录进跨会话记忆（烧录姿势/时钟陷阱/GBK 乱码显示等），下次直接复用

### 3. 功能开发（改公共仓代码）
1. 只读侦察先行：用并行 agent 摸清目标文件结构、IPC 约束、可复用模式
2. 方案过用户评审（计划模式）→ 最小侵入实现（不改构建清单、不加新 Kconfig）
3. 独立 git 仓的改动立即出 patch 存档（`git diff > out/share/<name>.patch`），避免丢失
4. 全量编译一次覆盖多个改动：`./build.sh <board-config> -e -Wno-error -j8`

### 4. 提交归档（大赛材料）
1. 日志：会话自动归集到 `logs/<github_login>/`（真实 JSONL，勿留 example 占位），定期 commit
2. 提交：fork → 分支开发 → PR → **自行 review 并合入官方仓**（截止前合入！不要只挂在 PR 里）
3. README 必须替换成作品说明（官方模板第六节）；如实标注"未做/估计"项
4. 补丁/摘要存 `docs/`，公共仓改动走上游 PR（dev-ai-contest-2026 分支）

## 输出规范

- 每次会话结束：状态快照写入记忆文件（当前固件版本/PID/IP/下一步），方便断电重启后续接
- 每次修复：产出「根因一句话 + 证据日志片段 + 验证清单」三段式记录
- 每次提交：commit message 带 `docs:`/`logs:`/`fix:` 前缀 + Co-Authored-By
- 产物命名带版本与日期，旧产物不覆盖（便于回滚对照）

## 已知坑（来自实战，别重踩）

| 坑 | 解法 |
|---|---|
| ai_agent & 后控制台被抢 | 常规操作走 adb shell；ssh 管道起第二个实例用于交互 |
| kill 掉 sshd 后端口绑不上 | 僵尸 socket，只能断电重启 |
| VM 时钟漂移（差数分钟） | 一切 epoch/cron 时间以板子 `date +%s` 为准 |
| cron 过期 at 任务 | 装载时即静默禁用（enabled=false 写盘），不补触发；新任务需重启实例装载 |
| 烧录普通升级写脏块黑屏 | 首选 PhoenixSuit 分区擦除 |

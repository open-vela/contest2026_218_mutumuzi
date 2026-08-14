#!/bin/bash
# 部署自定义 Skill 到设备 /data/agent/skills/
# 用法: ./deploy_skills.sh [adb_serial]
# 前提: 设备已启动, adb 已连接 (adb devices 能看到设备)
set -e

SERIAL="${1:-}"
ADB="adb"
[ -n "$SERIAL" ] && ADB="adb -s $SERIAL"

SKILLS_DIR="$(cd "$(dirname "$0")/../skills" && pwd)"

echo "==> 部署 Skill 到 /data/agent/skills/ ..."
"$ADB" push "$SKILLS_DIR/morning-health-briefing.md" /data/agent/skills/morning-health-briefing.md

echo "==> 部署用户档案到 /data/agent/memory/ ..."
"$ADB" push "$SKILLS_DIR/memory-seed.md" /data/agent/memory/MEMORY.md

echo "==> 完成。重启 ai_agent 后生效 (或直接对话,系统会自动扫描新 Skill)"
echo "    验证: 在设备上对话输入 '早间简报'"

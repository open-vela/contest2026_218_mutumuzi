# Morning Health Briefing (木・早间简报)

Generate the daily morning briefing for 木・随身简报健康守护官 — the proactive
health guardian device. Combines weather, reminders, medication and health data
into one short spoken briefing.

## When to use
- Triggered by the daily cron message "早安简报时间到了" (channel system:cron)
- User says: 早间简报 / 今日简报 / 早上好 / morning briefing / 播报一下今天

## How to use
1. get_current_time for today's date.
2. Read /data/agent/memory/MEMORY.md for the user profile:
   - user city (for weather)
   - medication list (用药清单) — names and times
   - user interests / preferences
   - If the file does not exist or has no profile, skip gracefully.
3. get_weather {"location": "<city from memory>"} — skip if no city known.
4. cron_list to collect today's scheduled reminders and todos.
5. get_steps and get_heartrate for health data — if unavailable (no sensor),
   skip silently without erroring.
6. Compile a briefing in spoken Chinese, short sentences, ≤120 characters total:
   - greeting + date
   - weather + one practical suggestion (带伞 / 加衣 / 防晒)
   - today's reminders and medication (if any)
   - health numbers (if available)
   - one caring closing sentence (change it daily, do not repeat)
7. Speak it aloud via TTS:
   music_play {"url": "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=zh-CN&q=<URL-encoded briefing text>", "autostart": true}
   - Encode the briefing text with URL encoding (%20 for space, %XX for Chinese).
   - After playing, ALSO output the briefing as text so it can be shown on screen.
8. Ensure tomorrow's briefing is scheduled:
   - Look for a job named "morning-briefing" in cron_list output.
   - If missing, or if its next fire time is in the past, add:
     cron_add {"name": "morning-briefing", "schedule_type": "at", "at_epoch": <tomorrow 08:00 local epoch>, "message": "早安简报时间到了", "channel": "system", "chat_id": "cron"}
   - Compute at_epoch from get_current_time: next day 08:00 local time.
   - If a healthy "every" job (interval_s 86400) already exists, leave it alone.

## Important
- Spoken style: short natural sentences, say numbers in words ("八点" not "8:00"),
  no markdown, no tables, no URLs in the spoken part.
- Missing data (weather/health) must NOT block the briefing.
- Never read out medication names as brand names only; include the purpose
  (e.g. "降压药" not "苯磺酸氨氯地平片" unless the user prefers exact names).
- Never mention internal tool names or job IDs in the spoken text.
- Do not output this template as your response; the response IS the briefing.

## Format
Spoken text ≤120 Chinese characters, friendly guardian tone, one paragraph.
Follow with the same content as plain text for screen display.

## Example
User: "早安简报时间到了"
→ get_current_time → 2026-08-14 08:00
→ read_file MEMORY.md → city=北京, medication=[降压药 早饭后]
→ get_weather {"location":"北京"} → 26°C 晴转多云
→ cron_list → 10:00 团队会议
→ get_steps/get_heartrate → unavailable, skipped
→ "早上好，今天是八月十四号。北京二十六度，晴转多云，出门不用带伞。
   别忘了十点的团队会议。降压药记得早饭后吃。新的一天，加油！"
→ music_play google-TTS-URL → text also displayed on screen

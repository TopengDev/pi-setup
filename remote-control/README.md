# Pi Remote Control — Standalone Telegram Bot

Run on the same machine as pi — no VPS, no Docker needed.

## Quick Setup

```bash
cd remote-control
npm install
cp .env.example .env
# Edit .env with your Telegram bot token and user ID
node telegram-bot.js
```

## How It Works

```
Telegram → telegram-bot.js (your machine) → local attn daemon (localhost:9742) → pi
```

The bot polls Telegram's API from your machine. Messages route through the attn relay to your pi session. Files, voice notes, and documents all work.

## Getting Credentials

1. **Telegram Bot Token**: Message [@BotFather](https://t.me/BotFather), send `/newbot`, follow prompts
2. **Your Telegram User ID**: Message [@userinfobot](https://t.me/userinfobot), it'll tell you your numeric ID
3. **Your Pi Address**: Run `curl localhost:9742/status` — the `address` field is your pi's attn address

## Multi-User Setup

For multiple users (friends, family), each person needs:
- Their own Telegram bot token from @BotFather
- Their pi address added to the bridge's authorized list

Alternatively, use the [pi-remote](https://github.com/TopengDev/pi-remote) Docker setup on a VPS for a multi-tenant hosted bridge.

## Features

- Text messaging (plain language, no prefix)
- Photo upload (viewed by pi)
- Document upload (PDF, etc.)
- Voice notes (auto-transcribed via Whisper)
- Voice replies (TTS via Windows speech synthesis)
- File downloads from pi (pi can send files back to you)
- Reply context (quoted messages show what you're replying to)

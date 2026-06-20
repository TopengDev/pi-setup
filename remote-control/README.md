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

## When to use this vs pi-remote

This bot (`remote-control/telegram-bot.js`) is the bundled option — works from this
repo alone with no extra clones. It uses the local attn daemon (same encryption).

The [pi-remote](https://github.com/TopengDev/pi-remote) bot is the full-stack option,
installed via `./install.sh --remote-stack`. It is more actively maintained. For a fresh
install, prefer `--remote-stack`.

For multi-user / multi-tenant hosting (serving several people from one server), pi-remote
also ships a Docker setup suitable for VPS deployment.

## Features

- Text messaging (plain language, no prefix)
- Photo upload (viewed by pi)
- Document upload (PDF, etc.)
- Voice notes (auto-transcribed via Whisper)
- Voice replies (TTS via Windows speech synthesis)
- File downloads from pi (pi can send files back to you)
- Reply context (quoted messages show what you're replying to)

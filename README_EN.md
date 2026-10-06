<div align="center">

# Paradise

An immersive AI chat app in the style of Telegram.

[![CI](https://github.com/Celvra/paradise/actions/workflows/ci.yml/badge.svg)](https://github.com/Celvra/paradise/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84.svg)](https://developer.android.com)

[中文](README.md)

</div>

---

## Changelog

### v1.0.3

- Video messages: send videos from the gallery or as files, gated on whether the model supports video input — the AI can actually watch them.
- Inline files: small files that won't blow up the context are injected directly, so the AI truly reads them.
- Sticker upgrades: the AI reads a sticker's meaning before sending one proactively, in context; stickers render with thumbnails.
- Clinginess: new settings for proactive-message frequency (interval) and a max proactive count, available when creating or editing a persona, both optional; the count refreshes when you reply.
- Shop: spend your balance on affection boosts for a chosen AI, apology cards and more — the wallet finally does something.
- Merged upstream v1.0.2: new onboarding, SKILLS, LaTeX canvas cards, update checks, model metadata rewrite, free relay and more.
- UI and performance polish, closer to Telegram in look and feel.

### v1.0.2

- Upstream release, see https://github.com/Celvra/paradise/releases/tag/v1.0.2

## Development status

We have essentially finished the main requirements of this project and it has been tested on Android. Since I have no other devices to test on, community support is needed.

## What it includes

- SillyTavern-like persona cards, for both the AI and yourself.
- Immersive conversation. You talk to the AI the way you would talk to a person.
- An affection system. You have to build up to a new character over time.
- Persistent memory. The built-in memory system lets the AI create and edit long-term memories.
- Workspace. Give the AI a directory of its own to read and write files in, with a file browser and a terminal to match; you see the change before it lands.
- A fallback chain, so your conversation is never interrupted. (Can be turned off.)
- Agent mode, which shows the AI's tool calls and its reasoning.
- Export persona cards and memories. Session export and similar are planned.
- Supports the OpenAI compatible format, OpenAI Responses, Anthropic Messages and Gemini Beta. Multimodal input is supported; output is not, and will not be.
- Model metadata is fetched from models.dev.

There is more. Leave yourself something to find.

### Immersive conversation

For a better sense of immersion, this project offers:

- A typo system. The AI will now and then misspell something on purpose, then recall the message to correct itself.
- A sticker system. The AI sends the right sticker at the right moment, and it also collects the ones you send into its library. You can of course manage it by hand too.
- Proactive messages. The AI calls the proactive message tool and sets a time for its next message, so it can check on you and break the ice on its own.
- Message splitting. The AI sends several messages in a row, like a person, to imitate the pauses in typing.
- Read time and pacing. The AI reads your message for a moment before answering and pauses between its bubbles, and the overall pace is yours to set.
- A follow-up dice. After a reply the AI may decide on its own to pick the thread back up, minutes to a couple of hours later.
- Quick adjustment. You can adjust the AI's output style quickly. Short, standard or casual.
- Presence status. The AI can change its own presence, to show read-but-not-replied, away, or do not disturb.
- Ratings. During a conversation the AI picks up your attitude towards the current turn and adjusts its style and its sending frequency on its own.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Acknowledgements

- [Kelivo](https://github.com/Chevey339/kelivo) — reference for ToolCall and MCP, the PRoot container and the sandbox
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) — reference for persona cards
- [Telegram Android](https://github.com/DrKLO/Telegram) — reference for the UI and UX, ported to Flutter
- [User-6170](https://github.com/yzc12345779) & Kimi work-K2.8 Preview — v1.0.3 features

### Translation

- 殘月 (English, 简体中文, 繁體中文)

## Licence

GNU Affero General Public License v3.0, that is, AGPL v3.

Developer: 殘月. You may not redistribute or commercialise it without publishing the source. Full terms in [LICENSE](LICENSE).

## Community

These are the only official channels we provide, so anywhere else is unofficial. Please check carefully before you trust it.

QQ group: 272298906
https://qm.qq.com/q/BeQPYWuzVS

Discord
https://discord.gg/aQaNUHPsw

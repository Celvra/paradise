<div align="center">

# 彼岸双生

一个 Telegram 风格的沉浸式 AI 聊天应用.

[English](README_EN.md)

</div>

---

## 开发进度

我们已基本完成此项目的主要需求，已在 Android 上测试通过，由于我没有其他设备，因此需要社区支持。

## 它包含什么

- 类 SillyTavern 的人设/角色卡，包括 AI 和您自己。
- 沉浸式聊天，您可以像与正常人聊天一样与 AI 聊天。
- 好感度系统，您需要与新角色渐渐建立感情。
- 持久性记忆，内置的 memory 系统可以让 AI 新建或编辑长久记忆。
- Fallback 链，这使得您的聊天不被打断。(可被关闭)
- Agent 模式，显示 AI 的工具调用过程和思考过程。
- 导出角色卡、记忆。后续将加入会话导出功能等。
- 支持 OpenAI 兼容格式、OpenAI Responses、Anthropic Messages、Gemini Beta，支持模型多模态输入；不支持输出，也不会支持。
- 从 models.dev 拉取模型元数据。

还有更多功能，等待您发现。

### 沉浸式聊天

为了您更好的沉浸体验，本项目提供了:

- 错别字系统。AI 会有时故意打错字，并撤回修正。
- 表情系统。AI 会在合适的时间发送合适的表情包，同时也会收集您发送的表情入库。当然您可以手动操作。
- 主动发信。AI 会调用主动发信工具，设定下一次主动发信时间，以自动查岗、自动破冰。
- 截断信息。AI 将像人类一样发多条消息以模拟打字间隙。
- 快速调整。您可以快捷调整 AI 的输出风格。可选简短、标准、随意。
- 在线状态。AI 可以改变自己的在线状态，以实现 已读不回，离开，请勿打扰。
- 评分。在聊天过程中，AI 将自动学习您对当前轮对话的态度，并自我微调风格和调整发信频率。

## 贡献指南

请参考 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 致谢

- [Kelivo](https://github.com/Chevey339/kelivo)  ToolCall、MCP 参考
- [SillyTavern](https://github.com/SillyTavern/SillyTavern)  人设卡参考

### 翻译致谢

- 殘月 (English, 简体中文, 繁體中文)

## 许可

GNU Affero General Public License v3.0，即 AGPL v3.

本项目归属 Project Xyle 组织，开发者殘月。您不得在不开源代码的前提下二次分发和商业化本项目。完整条款见 [LICENSE](LICENSE)。

## 社区

我们仅提供 Discord 渠道，无中国大陆的社交渠道，例如 QQ。因此除了以下渠道的交流社区以外，均为非官方渠道，请谨慎鉴别。

https://discord.gg/aQaNUHPsw

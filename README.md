<div align="center">

# 彼岸双生

一个 Telegram 风格的沉浸式 AI 聊天应用.

[![CI](https://github.com/Celvra/paradise/actions/workflows/ci.yml/badge.svg)](https://github.com/Celvra/paradise/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84.svg)](https://developer.android.com)

[English](README_EN.md)

</div>

---

## 更新日志

### v1.0.3

- 视频消息：相册与文件均可发送视频，发送前检查模型是否支持视频输入，AI 能真正看懂视频内容。
- 文件直读：不会撑爆上下文的小文件直接注入，AI 真正读到文件内容。
- 贴纸升级：AI 主动发送表情包前先读懂其含义再按语境发送；贴纸显示缩略图。
- 粘人度：新增主动发话频率（间隔）与最多主动发言次数设置，创建/编辑人设时可用，均可关闭；用户回复后次数刷新；普通聊天下也会真正触发。
- 商城改版：购买后跳转到对应 AI 的聊天界面，礼物以卡片气泡送达，AI 收到系统消息并真切回应；商城与钱包入口挪到更显眼的位置（会话列表菜单、设置首页）。
- 自动备份：默认开启"数据变化自动备份"，另有每隔 1/6/12/24 小时、每日时段两种覆盖式更新；关闭前会警告数据丢失风险；备份经 MediaStore 存放于系统下载目录，随更新与重装存活；数据丢失退回引导界面时自动检测并弹出一键恢复。
- 模型目录：内置 models.dev 离线快照兜底（网络差也能选模型），修正 GLM-5.3-Flash / FlashX 等模型的视频支持标记。
- 编辑器保护：人设编辑器的返回键、右滑手势、关闭按钮所有退出方式都会先确认再丢弃修改。
- 引导页修复：权限允许按钮连点误判"被拒绝"、设置授权后状态不刷新等问题修复。
- 合并上游 v1.0.2：全新向导、SKILLS、LaTeX 绘图卡片、检查更新、模型元数据重写、免费 relay 等。
- 检查更新会同时获取并展示新版本发布说明（release notes）；设置"关于"下新增"更新说明"，可随时重看当前版本更新内容。
- 界面与性能优化，观感与动效更接近 Telegram。

### v1.0.2

- 上游版本，详见 https://github.com/Celvra/paradise/releases/tag/v1.0.2

## 它包含什么

- 类 SillyTavern 的人设/角色卡，包括 AI 和您自己。
- 沉浸式聊天，您可以像与正常人聊天一样与 AI 聊天。
- 好感度系统，您需要与新角色渐渐建立感情。
- 持久性记忆，内置的 memory 系统可以让 AI 新建或编辑长久记忆。
- 工作区。给 AI 一个自己的目录，它可以读写文件，还带文件浏览器和终端；写入前你会先看到改动。
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
- 读消息节奏。AI 会先"读"一会儿您的消息再回复，气泡之间也有停顿，全局可调快慢。
- 回复后跟进。一次回复结束后 AI 会自己掷骰，决定要不要在几分钟到几小时后接着这个话题再说一句。
- 快速调整。您可以快捷调整 AI 的输出风格。可选简短、标准、随意。
- 在线状态。AI 可以改变自己的在线状态，以实现 已读不回，离开，请勿打扰。
- 评分。在聊天过程中，AI 将自动学习您对当前轮对话的态度，并自我微调风格和调整发信频率。

## 贡献指南

请参考 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 致谢

- [Kelivo](https://github.com/Chevey339/kelivo)  ToolCall、MCP 参考、PRoot 容器、沙箱.
- [SillyTavern](https://github.com/SillyTavern/SillyTavern)  人设卡参考
- [Telegram Android](https://github.com/DrKLO/Telegram)     UI/UX，移植到 Flutter。
- [User-6170](https://github.com/yzc12345779) & Kimi work-K2.8 Preview  v1.0.3 新功能开发。

### 翻译致谢

- 殘月 (English, 简体中文, 繁體中文)

## 许可

GNU Affero General Public License v3.0，即 AGPL v3.

开发者殘月。您不得在不开源代码的前提下二次分发和商业化本项目。完整条款见 [LICENSE](LICENSE)。

## 社区

我们仅提供以下官方交流渠道，除此之外的交流社区均为非官方渠道，请谨慎鉴别。

QQ 群：272298906
https://qm.qq.com/q/BeQPYWuzVS

Discord
https://discord.gg/aQaNUHPsw

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '彼岸双生';

  @override
  String get actionOk => '确定';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClear => '清空';

  @override
  String get actionDelete => '删除';

  @override
  String get actionDone => '完成';

  @override
  String get actionSave => '保存';

  @override
  String get actionRetry => '重试';

  @override
  String get actionCopy => '复制';

  @override
  String get actionAdd => '添加';

  @override
  String get actionRemove => '移除';

  @override
  String get actionDiscard => '放弃';

  @override
  String get accountTitle => '编辑资料';

  @override
  String get accountNameHeader => '你的名字';

  @override
  String get accountNameFooter => '填写你的名字，可选添加头像。下方的人设会保留各自的名称。';

  @override
  String get accountNameHint => '名字';

  @override
  String get accountBioHeader => '个人简介';

  @override
  String get accountBioFooter => '可以写几句关于自己的话。角色可能会读它，以便更好地了解你。';

  @override
  String get accountBioHint => '简介';

  @override
  String get accountPhotoFooter => '长按上方头像即可快速移除照片。';

  @override
  String get accountSetNewPhoto => '设置新照片';

  @override
  String get accountSetPhoto => '设置头像';

  @override
  String get accountRemovePhoto => '移除照片';

  @override
  String get accountRemovePhotoTitle => '移除照片';

  @override
  String get accountRemovePhotoMessage => '确定要移除你的头像吗？';

  @override
  String get accountPhotoRemoved => '照片已移除';

  @override
  String get accountPhotoActionSet => '设置照片';

  @override
  String get accountPhotoActionChange => '更换照片';

  @override
  String get accountOnlineFallback => '在线';

  @override
  String get accountNameEmptyPreview => '你的名字';

  @override
  String get accountNameRequired => '名字不能为空';

  @override
  String get accountDiscardTitle => '放弃更改？';

  @override
  String get accountDiscardMessage => '你的资料还有未保存的更改。';

  @override
  String get galleryUnavailable => '相册不可用';

  @override
  String get actionEdit => '编辑';

  @override
  String get actionSend => '发送';

  @override
  String get actionRemoveShort => '移除';

  @override
  String get actionEnable => '启用';

  @override
  String get actionDisable => '停用';

  @override
  String get actionMoveUp => '上移';

  @override
  String get actionMoveDown => '下移';

  @override
  String get actionCurrent => '当前';

  @override
  String get aiTabProviders => '服务商';

  @override
  String get aiTabChain => '兜底链';

  @override
  String get aiTabAdvanced => '高级';

  @override
  String get aiTitle => 'AI 配置';

  @override
  String get aiReadyTitle => 'AI 已就绪';

  @override
  String get aiNotReadyTitle => 'AI 尚未设置';

  @override
  String get aiNotReadyMessage => '先给某个服务商添加 API 密钥，再把它的某个模型放到兜底链上。';

  @override
  String aiOnChainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '兜底链上有 $count 个模型',
      one: '兜底链上有 1 个模型',
    );
    return '$_temp0';
  }

  @override
  String get aiProvidersHeader => '服务商';

  @override
  String get aiProvidersFooter => '模型能力来自服务商 API 和内置目录，上下文窗口决定了记录在什么时候被压缩。';

  @override
  String get aiAddProvider => '添加服务商';

  @override
  String get aiAddProviderTitle => '添加服务商';

  @override
  String get aiAddProviderHint => '名称，例如 My Relay';

  @override
  String get aiKeySet => '已设置 API 密钥';

  @override
  String get aiNoKey => '未设置 API 密钥';

  @override
  String aiProviderOnChain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模型',
      one: '1 个模型',
    );
    return '$_temp0 在兜底链中';
  }

  @override
  String aiProviderModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模型',
      one: '1 个模型',
    );
    return '$_temp0';
  }

  @override
  String get aiChainHeader => '兜底链';

  @override
  String aiChainActiveCount(int active, int total) {
    return '$total 个中启用 $active 个';
  }

  @override
  String get aiChainEmpty => '尚未配置兜底链';

  @override
  String get aiChainEmptyHint => '兜底链是空的。加一个模型后，请求会优先发给它。';

  @override
  String get aiChainFooter =>
      '请求会按顺序逐个尝试。点模型可调整顺序、修改重试次数或移除。鉴权与计费失败不会重试，直接转到下一个模型。';

  @override
  String get aiAddModel => '添加模型';

  @override
  String get aiCompactionHeader => '上下文压缩';

  @override
  String get aiCompactionFooter => '上下文溢出时会重试一次压缩，仍失败就直接截断历史记录。';

  @override
  String get aiCompactionToggle => '压缩过长的对话';

  @override
  String get aiCompactionToggleSub => '较早的对话会被浓缩成摘要';

  @override
  String get aiSummaryModel => '摘要模型';

  @override
  String get aiSummaryModelFollows => '跟随兜底链上的第一个模型';

  @override
  String get aiSummaryLength => '摘要长度';

  @override
  String get aiAddToChainTitle => '添加到兜底链';

  @override
  String get aiSummaryModelPickerTitle => '用于生成摘要的模型';

  @override
  String get aiSummaryLengthTitle => '摘要长度';

  @override
  String get aiLengthTight => '精简';

  @override
  String get aiLengthBalanced => '适中';

  @override
  String get aiLengthDetailed => '详尽';

  @override
  String get aiChainMenuRetries => '重试次数';

  @override
  String get aiRetriesTitle => '换下一个模型前的重试次数';

  @override
  String get aiRetriesNone => '不重试';

  @override
  String get aiRepliesHeader => '回复';

  @override
  String get aiRepliesFooter => '人格化模式会把一条回复拆成几条短消息，就像真人发消息那样。';

  @override
  String get aiReplyStyle => '回复风格';

  @override
  String get aiReplyStyleFull => '完整';

  @override
  String get aiReplyStyleCharacter => '人格化';

  @override
  String get aiReplyStyleFullSub => '逐字流式输出，并显示思考过程';

  @override
  String get aiReplyStyleCharacterSub => '像真人一样分成几条短消息发送';

  @override
  String get aiFirstBubbleDelay => '回复前的读消息时间';

  @override
  String get aiBubbleGapScale => '消息间停顿倍率';

  @override
  String get aiPacingOff => '关闭';

  @override
  String get aiPacingDelayHint => '第一条消息立即送达';

  @override
  String get aiPacingJitter => '节奏随机幅度';

  @override
  String get aiPacingJitterLow => '轻微';

  @override
  String get aiPacingJitterNormal => '标准';

  @override
  String get aiPacingJitterWild => '狂放';

  @override
  String get aiPacingJitterHintOff => '每个停顿都和设定值一样长';

  @override
  String get aiPacingJitterHintLow => '停顿在设定值附近轻微浮动';

  @override
  String get aiPacingJitterHintNormal => '每个停顿都有人类式的不均匀';

  @override
  String get aiPacingJitterHintWild => '难以预测，有时秒回有时磨蹭';

  @override
  String get aiSamplingHeader => '采样';

  @override
  String get aiSamplingFooter => '聊天里不会显示任何模型细节。';

  @override
  String get aiTemperature => '温度';

  @override
  String get aiTempDeterministic => '稳定';

  @override
  String get aiTempFocused => '专注';

  @override
  String get aiTempBalanced => '均衡';

  @override
  String get aiTempLoose => '奔放';

  @override
  String get aiMaxOutput => '最大输出';

  @override
  String get aiModelDefault => '默认模型';

  @override
  String get aiUseCatalogDefault => '使用目录默认值';

  @override
  String get aiSummaryNoNodes => '兜底链还没有节点';

  @override
  String get aiSummaryNoKey => '未配置 API 密钥';

  @override
  String get aiCapsReasoning => '思考';

  @override
  String get aiCapsVision => '视觉';

  @override
  String get aiTokensUnknown => '未知';

  @override
  String get tabChats => '聊天';

  @override
  String get tabSettings => '设置';

  @override
  String get tabProfile => '我的';

  @override
  String get chatsTitle => '聊天';

  @override
  String get chatsSearchHint => '搜索';

  @override
  String get chatsEmptyTitle => '还没有聊天';

  @override
  String get chatsEmptySub => '创建一个人设，开始聊天。';

  @override
  String get chatsNewPersona => '新建人设';

  @override
  String get chatsMenuReadAll => '全部已读';

  @override
  String get chatsRowTyping => '正在输入';

  @override
  String get chatsRowDraft => '草稿：';

  @override
  String get chatsRowEmpty => '还没有消息';

  @override
  String get chatsRowYou => '你：';

  @override
  String get menuPin => '置顶';

  @override
  String get menuUnpin => '取消置顶';

  @override
  String get menuMute => '免打扰';

  @override
  String get menuUnmute => '取消免打扰';

  @override
  String get menuMarkAsRead => '标为已读';

  @override
  String get menuClearHistory => '清空记录';

  @override
  String get menuDeleteChat => '删除聊天';

  @override
  String get dialogClearHistoryTitle => '清空聊天记录';

  @override
  String dialogClearHistoryMessage(String personaName) {
    return '删除 $personaName 中的所有消息？';
  }

  @override
  String get dialogDeleteChatTitle => '删除聊天';

  @override
  String dialogDeleteChatMessage(String personaName) {
    return '这会移除 $personaName 及其聊天记录。';
  }

  @override
  String get chatEmptyPill => '这里还没有消息...';

  @override
  String get chatSearchHint => '搜索消息';

  @override
  String get chatSearchNoResults => '无结果';

  @override
  String chatSearchCount(int index, int total) {
    return '第 $index 条，共 $total 条';
  }

  @override
  String get chatSearchModeChat => '对话';

  @override
  String get chatSearchModeList => '列表';

  @override
  String get chatStatusTyping => '正在输入';

  @override
  String get chatStatusBot => '机器人';

  @override
  String get chatMenuReply => '回复';

  @override
  String get chatMenuCopy => '复制';

  @override
  String get chatMenuRegenerate => '重新生成';

  @override
  String get chatMenuDelete => '删除';

  @override
  String get toastMessageCopied => '消息已复制';

  @override
  String get headerMenuSearch => '搜索';

  @override
  String get headerMenuViewProfile => '查看资料';

  @override
  String get headerMenuEditPersona => '编辑人设';

  @override
  String get headerMenuMutedSub => '通知已关闭';

  @override
  String get headerMenuLockPersona => '锁定我的人设';

  @override
  String get headerMenuClearHistory => '清除记录';

  @override
  String get headerMenuDeleteChat => '删除对话';

  @override
  String get dialogClearHistoryHereTitle => '清空聊天记录';

  @override
  String get dialogClearHistoryHereMessage => '删除此聊天中的所有消息？';

  @override
  String get dialogDeleteChatHereTitle => '删除聊天';

  @override
  String get lockSheetTitle => '锁定我的人设';

  @override
  String get lockSheetSub => '此聊天始终以你选择的卡片身份回复。';

  @override
  String get lockSheetUnnamed => '未命名';

  @override
  String get lockSheetNone => '不锁定';

  @override
  String get lockSheetNoneSub => '使用「我的账号」里选中的卡片';

  @override
  String get lockSheetEmpty => '还没有人设卡片。到「我的账号」里创建一张。';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAccount => '我的账号';

  @override
  String get settingsAccountSub => '名称和简介';

  @override
  String get settingsAi => 'AI';

  @override
  String get settingsAiSubNone => '兜底链里没有模型';

  @override
  String get settingsAppearance => '聊天外观';

  @override
  String get settingsAppearanceSub => '夜间模式、字号、圆角';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsVibrationOn => '振动已开启';

  @override
  String get settingsVibrationOff => '振动已关闭';

  @override
  String get settingsData => '数据与存储';

  @override
  String settingsDataSub(int chats, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats 个聊天',
      one: '1 个聊天',
    );
    return '$_temp0 · 媒体 $size';
  }

  @override
  String get settingsAbout => '关于';

  @override
  String get aboutLinkFailed => '无法打开链接';

  @override
  String get settingsAboutSub => '版本 1.0.1';

  @override
  String get settingsAboutLicense =>
      '开发者: 殘月。请遵守 AGPL 3.0 开源许可证，这意味着您不得在不开源代码的前提下二次分发和商业化本项目，若违反，我们将依法处理。';

  @override
  String get settingsAboutCommunity => '加入交流群:';

  @override
  String get settingsAboutRepo => '本项目地址:\nhttps://github.com/Celvra/paradise';

  @override
  String get settingsAboutThanks =>
      '鸣谢:\n\nKelivo - ToolCall 参考\nhttps://github.com/Chevey339/kelivo\n\nSillyTavern - 人设卡参考\nhttps://github.com/SillyTavern/SillyTavern';

  @override
  String get settingsAboutDeps =>
      '依赖库:\n\ncharacters 1.4.1 - 字形簇，用于正确计算文本宽度  (BSD-3-Clause)\nhttps://github.com/dart-lang/core/tree/main/pkgs/characters\nfile_picker 13.1.0 - 文件与音频选择  (MIT)\nhttps://github.com/vicajilau/flutter_file_picker/tree/main/packages/file_picker\nflutter_contacts 2.5.0 - 分享联系人名片  (MIT)\nhttps://github.com/QuisApp/flutter_contacts\nflutter_local_notifications 18.0.1 - 本地通知  (BSD-3-Clause)\nflutter_svg 2.3.0 - 服务商图标与矢量图标  (MIT)\nhttps://github.com/flutter/packages/tree/main/third_party/packages/flutter_svg\ngeolocator 13.0.4 - 位置附件  (MIT)\nhttps://github.com/baseflow/flutter-geolocator/tree/main/geolocator\nhttp 1.6.0 - OpenAI 兼容接口请求  (BSD-3-Clause)\nhttps://github.com/dart-lang/http/tree/master/pkgs/http\nimage_picker 1.2.3 - 相机与相册图片  (Apache-2.0)\nhttps://github.com/flutter/packages/tree/main/packages/image_picker/image_picker\nintl 0.20.3 - 日期与数字格式化  (BSD-3-Clause)\nhttps://github.com/dart-lang/i18n/tree/main/pkgs/intl\npath_provider 2.1.6 - 应用目录，用于表情与导出文件  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/path_provider/path_provider\nphoto_manager 3.12.0 - 相册访问，用于附件  (Apache-2.0)\nhttps://github.com/fluttercandies/flutter_photo_manager\nshared_preferences 2.5.5 - 设置与聊天记录存储  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences\nsqflite 2.4.4 - 消息历史与会话分页  (BSD-2-Clause)\nhttps://github.com/tekartik/sqflite/tree/master/sqflite\ntimezone 0.10.1 - 日程消息的时区数据  (BSD-2-Clause)\nhttps://github.com/srawlins/timezone\nurl_launcher 6.3.2 - 本弹窗中的交流群链接  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher\nworkmanager 0.10.10 - 应用被杀后的后台送达  (MIT)\nhttps://github.com/fluttercommunity/flutter_workmanager';

  @override
  String get settingsAboutCommunityUrl => 'https://discord.gg/aQaNUHPsw';

  @override
  String get settingsFooter => 'Developed by Celvra';

  @override
  String get previewSampleIncoming => '早上好！今天有什么可以帮你的？';

  @override
  String get previewSampleOutgoing => '讲讲 transformers 是怎么工作的';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get appearanceTheme => '主题';

  @override
  String get wallpaperHeader => '聊天壁纸';

  @override
  String get wallpaperRow => '壁纸';

  @override
  String get wallpaperDefault => '默认';

  @override
  String get wallpaperChoose => '选择图片';

  @override
  String get wallpaperNone => '纯色渐变';

  @override
  String get wallpaperFollowGlobal => '跟随全局';

  @override
  String get wallpaperBlur => '模糊壁纸';

  @override
  String get wallpaperBlurSub => '让气泡在照片上依然清晰';

  @override
  String get wallpaperColorHeader => '壁纸取色';

  @override
  String get wallpaperColorFooter => '选一个颜色，用于强调色和你发出的气泡。';

  @override
  String get wallpaperColorNone => '默认';

  @override
  String get wallpaperNoColors => '这张图没有可取的颜色';

  @override
  String get wallpaperBubbleGrad => '气泡渐变';

  @override
  String get wallpaperBubbleGradSubtle => '轻微';

  @override
  String get wallpaperBubbleGradMedium => '适中';

  @override
  String get wallpaperBubbleGradStrong => '明显';

  @override
  String get wallpaperBubbleGradSub => '控制你发出的气泡从上到下的深浅跨度。';

  @override
  String get wallpaperRemoved => '已移除壁纸';

  @override
  String get wallpaperChatTitle => '本会话壁纸';

  @override
  String get appearanceNightMode => '夜间模式';

  @override
  String get appearancePreview => '消息预览';

  @override
  String get appearanceTextSize => '消息字号';

  @override
  String get appearanceSize => '字号';

  @override
  String get appearanceCorners => '消息圆角';

  @override
  String get appearanceRadius => '圆角';

  @override
  String get appearanceReset => '恢复默认';

  @override
  String get notifAlerts => '提醒';

  @override
  String get notifVibrate => '回复时振动';

  @override
  String get notifVibrateSub => '收到回答时轻震一下';

  @override
  String get notifCountMuted => '统计勿扰对话';

  @override
  String get notifCountMutedSub => '把它们计入标签页角标';

  @override
  String get notifFooter => '每个对话也可以从它的菜单或资料页里设为勿扰。';

  @override
  String get dataUsage => '用量';

  @override
  String get dataChats => '对话';

  @override
  String get dataMessages => '消息';

  @override
  String get dataMedia => '媒体与文件';

  @override
  String get dataClear => '清除';

  @override
  String get dataClearSearch => '清除搜索记录';

  @override
  String get dataClearMedia => '清除媒体与文件';

  @override
  String get dataClearMediaTitle => '清除媒体';

  @override
  String get dataClearMediaMessage => '所有对话中的照片、文件和音乐都会被删除。';

  @override
  String get dataClearAll => '清除所有对话';

  @override
  String get dataClearAllTitle => '清除所有对话';

  @override
  String get dataClearAllMessage => '这会删除所有聊天里的每一条消息，人设会保留。';

  @override
  String get dataBackup => '备份';

  @override
  String get dataBackupExportSub => '会话、人格卡、表情与设置';

  @override
  String get dataBackupImportSub => '从之前导出的文件恢复';

  @override
  String dataBackupRestored(num chats, Object messages) {
    return '$chats 个会话，$messages 条消息';
  }

  @override
  String get dataBackupNothing => '这个文件里没有可恢复的内容';

  @override
  String get dataBackupSaved => '备份已保存';

  @override
  String get dataBackupSaveFailed => '无法保存文件';

  @override
  String get dayToday => '今天';

  @override
  String get dayYesterday => '昨天';

  @override
  String get emojiSearchHint => '输入以搜索';

  @override
  String get emojiNothingFound => '没有找到';

  @override
  String get personaDiscardExisting => '你对这个人设的修改将会丢失。';

  @override
  String get personaDiscardNew => '这个人设还没有创建。';

  @override
  String get personaNameHeader => '名称';

  @override
  String get personaNameHint => '人设名称';

  @override
  String get personaAboutHeader => '关于';

  @override
  String get personaAboutFooter => '显示在资料页上的一句话，不会发送给模型。';

  @override
  String get personaInstructionsHeader => '指令';

  @override
  String get personaInstructionsFooter => '这段内容会成为本聊天中每一次请求的系统提示词。';

  @override
  String get personaInstructionsHint => '你希望 AI 如何表现？';

  @override
  String get personaGreetingHeader => '问候';

  @override
  String get personaGreetingFooter => '可选。打开聊天时会作为第一条消息发送。';

  @override
  String get personaGreetingHint => '人设的第一条消息';

  @override
  String get personaSave => '保存修改';

  @override
  String get personaCreate => '创建人设';

  @override
  String get personaTemplatesHeader => '从模板开始';

  @override
  String get personaAppearanceHeader => '外观';

  @override
  String get personaAppearanceFooterPhoto => '设置照片后，所有显示头像的地方都会用照片代替表情符号。';

  @override
  String get personaAppearanceFooterColor => '这个颜色用于头像和资料页封面。';

  @override
  String get personaPhotoTitle => '照片';

  @override
  String get personaPhotoTitleEmpty => '资料照片';

  @override
  String get personaPhotoSubFull => '点击更换，长按移除';

  @override
  String get personaPhotoSubEmpty => '添加一张照片，或者沿用下面的颜色';

  @override
  String get personaChoose => '选择';

  @override
  String get personaModelForThis => '该人设使用的模型';

  @override
  String get personaModelGlobal => '全局';

  @override
  String get personaModelGlobalSub => '跟随兜底链的当前设置';

  @override
  String get personaModelFooterOverride => '关闭后，这个模型失败会直接结束回复，不再尝试全局兜底链。';

  @override
  String get personaModelFooterGlobal =>
      '全局模式下使用「设置 > AI」里的兜底链。选一个模型就能让人设单独使用它。';

  @override
  String get personaModelGlobalChain => '全局兜底链';

  @override
  String get personaModelOnlyThis => '仅此人设';

  @override
  String get personaModelFollowsSettings => '跟随「设置 > AI」';

  @override
  String get personaModelChange => '更改';

  @override
  String get personaModelFallback => '回退到全局兜底链';

  @override
  String get personaModelUseGlobal => '使用全局兜底链';

  @override
  String get presetAssistantBio => '沉稳冷静的万能帮手';

  @override
  String get presetCoderBio => '以读堆栈信息为乐';

  @override
  String get presetTranslatorBio => '中英双向翻译';

  @override
  String get presetWriterBio => '把每句话都精炼一遍';

  @override
  String get presetTutorBio => '像朋友一样讲给你听';

  @override
  String get aiFollowChain => '跟随链上的第一个节点';

  @override
  String get aiFollowChainSub => '总结时使用当前的主模型';

  @override
  String get aiSearchModels => '搜索模型';

  @override
  String get aiNoModelsLoaded => '还没有加载模型。\n请先从服务商获取一份列表。';

  @override
  String aiNoModelMatches(String query) {
    return '没有匹配「$query」的结果';
  }

  @override
  String get codeGeneric => '代码';

  @override
  String get toastCodeCopied => '代码已复制';

  @override
  String get searchFilterAll => '全部';

  @override
  String get searchRecent => '最近';

  @override
  String get searchPeople => '人';

  @override
  String get searchNoResultsTitle => '没有结果';

  @override
  String get searchEmptyBody => '还没有分享过这类内容。';

  @override
  String searchNoResultsBody(String query) {
    return '没有找到与“$query”相关的结果，换个词再试试。';
  }

  @override
  String get profileButtonEdit => '编辑';

  @override
  String get profileButtonShare => '分享';

  @override
  String get profileButtonMessage => '发消息';

  @override
  String get profileButtonSearch => '搜索';

  @override
  String get profileCopied => '资料已复制';

  @override
  String get profileLabelName => '名称';

  @override
  String get profileLabelBio => '简介';

  @override
  String get profileLabelPersonaCard => '人设卡片';

  @override
  String get profileLabelActivity => '动态';

  @override
  String get profileLabelAbout => '关于';

  @override
  String get profileLabelInstructions => '指令';

  @override
  String get profileLabelModel => '模型';

  @override
  String get profileLabelNotifications => '通知';

  @override
  String get profileBioEmpty => '写几句关于自己的话';

  @override
  String get profileCardEmpty => '告诉 AI 你是谁';

  @override
  String profileActivity(int chats, int sent) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats 个对话',
      one: '1 个对话',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '已发送 $sent 条',
      one: '已发送 1 条',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get profileOn => '开';

  @override
  String get profileOff => '关';

  @override
  String get profileHeaderTyping => '正在输入...';

  @override
  String toastCopiedLabel(String label) {
    return '已复制$label';
  }

  @override
  String get profileTabMedia => '媒体';

  @override
  String get profileTabFiles => '文件';

  @override
  String get profileTabMusic => '音乐';

  @override
  String get profileTabLinks => '链接';

  @override
  String get profileSharedEmptyMedia => '还没有媒体';

  @override
  String get profileSharedEmptyFiles => '还没有文件';

  @override
  String get profileSharedEmptyMusic => '还没有音乐';

  @override
  String get profileSharedEmptyLinks => '还没有链接';

  @override
  String get msgLeadPhoto => '照片';

  @override
  String get msgLeadMusic => '音乐';

  @override
  String get msgLeadContact => '联系人';

  @override
  String get msgLeadPoll => '投票';

  @override
  String get msgLeadSticker => '表情';

  @override
  String get attachAudioFallback => '音频';

  @override
  String get attachFileFallback => '文件';

  @override
  String get attachLocationTitle => '位置';

  @override
  String get attachLocationCopied => '坐标已复制';

  @override
  String get attachNoPhone => '没有电话号码';

  @override
  String get pollKindQuiz => '问答';

  @override
  String get pollKindPublic => '公开投票';

  @override
  String get pollKindAnonymous => '匿名投票';

  @override
  String pollKindMultiple(String kind) {
    return '$kind · 多选';
  }

  @override
  String photoCounter(int index, int total) {
    return '第 $index 张，共 $total 张';
  }

  @override
  String get profileFileFallback => '文件';

  @override
  String get errorAuth => 'API 密钥无效或没有访问权限';

  @override
  String get errorQuota => '服务商额度已用尽';

  @override
  String get errorRate => '被服务商限流';

  @override
  String get errorContextOverflow => '上下文比模型的窗口更长';

  @override
  String get errorServer => '服务商返回了一个错误';

  @override
  String get errorNetwork => '网络连接失败';

  @override
  String get errorAborted => '生成已停止';

  @override
  String get errorEmpty => '模型没有返回内容';

  @override
  String get errorUnknown => '请求失败';

  @override
  String errorStoppedEarly(String reason) {
    return '提前停止：$reason';
  }

  @override
  String pluralChats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个聊天',
      one: '1 个聊天',
    );
    return '$_temp0';
  }

  @override
  String pluralVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
      one: '1 票',
      zero: '还没有投票',
    );
    return '$_temp0';
  }

  @override
  String pluralSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 个',
    );
    return '$_temp0';
  }

  @override
  String pluralModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模型',
      one: '1 个模型',
    );
    return '$_temp0';
  }

  @override
  String pluralRetries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重试 $count 次',
      one: '重试 1 次',
    );
    return '$_temp0';
  }

  @override
  String pluralOptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个选项',
    );
    return '$_temp0';
  }

  @override
  String pluralChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个字符',
    );
    return '$_temp0';
  }

  @override
  String pluralTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个 token',
    );
    return '$_temp0';
  }

  @override
  String get cardCreate => '创建卡片';

  @override
  String get cardDeleteThisCard => '此卡片';

  @override
  String get cardDeleteTitle => '删除卡片';

  @override
  String get cardDeleted => '卡片已删除';

  @override
  String get cardDescHint => '你是谁、你怎么说话、你喜欢什么';

  @override
  String get cardDuplicate => '复制';

  @override
  String get cardDuplicated => '卡片已复制';

  @override
  String get cardEditing => '编辑卡片';

  @override
  String get cardEmptyBody => '创建一张人设卡片，让 AI 知道你是谁。';

  @override
  String get cardEmptyTitle => '还没有人设卡片';

  @override
  String get cardFieldDescription => '描述';

  @override
  String get cardFieldName => '名称';

  @override
  String get cardFieldNameHint => 'AI 对你的称呼';

  @override
  String get cardFieldTitle => '标题';

  @override
  String get cardFieldTitleHint => '仅在列表中显示';

  @override
  String get cardInfoFooter => '每次请求都会把这段描述一并发送给模型。';

  @override
  String get cardNew => '新建卡片';

  @override
  String get cardPlaceholdersHint => '使用 user 和 char 占位符。';

  @override
  String get cardPositionTitle => '在提示词中的位置';

  @override
  String get cardRoleTitle => '注入消息的角色';

  @override
  String get posAtDepth => '按深度插入';

  @override
  String get posAtDepthSub => '从最新一条往回数，插入到几条消息之前';

  @override
  String get posBottomNote => '底部备注';

  @override
  String get posBottomNoteSub => '对话开始前读到的最后一段内容';

  @override
  String get posInPrompt => '并入提示词';

  @override
  String get posInPromptSub => '合并进系统提示词';

  @override
  String get posNone => '关闭';

  @override
  String get posNoneSub => '不会发送这张卡片';

  @override
  String get posTopNote => '顶部备注';

  @override
  String get posTopNoteSub => '在其他所有内容之前';

  @override
  String get roleAssistant => '助手';

  @override
  String get roleSystem => '系统';

  @override
  String get roleUser => '用户';

  @override
  String cardDeleteMessage(String name) {
    return '删除 $name？此操作无法撤销。';
  }

  @override
  String msgRecalled(String name) {
    return '$name 撤回了一条消息';
  }

  @override
  String get msgEdited => '已编辑';

  @override
  String get msgPinned => '已置顶的消息';

  @override
  String get traceThinking => '思考';

  @override
  String get traceThinkingNow => '思考中…';

  @override
  String traceThoughtFor(String seconds) {
    return '思考了 $seconds';
  }

  @override
  String get traceRunning => '运行中';

  @override
  String get traceFailed => '失败';

  @override
  String get traceArguments => '参数';

  @override
  String get traceResult => '结果';

  @override
  String traceSeconds(String value) {
    return '${value}s';
  }

  @override
  String get statusOnline => '在线';

  @override
  String get statusAway => '离开';

  @override
  String get statusDnd => '勿扰';

  @override
  String get statusRead => '已读';

  @override
  String get searchGeneric => '搜索';

  @override
  String get inputMessageHint => '消息';

  @override
  String get aiReplyTitle => 'AI 回复';

  @override
  String get aiReplyStyleHeader => '节奏';

  @override
  String get aiReplyVisibleHeader => '你能看到的内容';

  @override
  String get aiReplyVisibleFooter =>
      '开启显示思考后，思考模型的推理过程会作为可展开的步骤写在答案上方。Agent 模式让模型调用工具，并为每次调用加上一行，显示它的参数和结果。';

  @override
  String get aiReplyMarkdown => 'Markdown';

  @override
  String get aiReplyMarkdownSub => '气泡里渲染加粗、代码块和标题；关闭后人格化模式会去掉这些标记';

  @override
  String get aiReplyShowThinking => '显示思考';

  @override
  String get aiReplyShowThinkingSub => '把推理过程写进对话里，而不是藏起来';

  @override
  String get aiReplyAgentMode => 'Agent 模式';

  @override
  String get aiReplyAgentModeSub => '工具与 MCP 调用，每一步实时显示';

  @override
  String get aiReplyToolsHeader => '工具';

  @override
  String get aiReplyToolsFooter =>
      'Agent 模式会给模型三个内置工具（时间、获取网页、列出 MCP 服务器），再加上你的 MCP 服务器提供的全部工具。每个工具都能在工具页设为询问、允许或拒绝。';

  @override
  String get aiReplyToolsRow => '工具、MCP 服务器与权限';

  @override
  String aiReplyToolsCount(int count) {
    return '可用 MCP 工具 $count 个';
  }

  @override
  String get aiReplyPersonaFooter =>
      '人设卡片可以为自己的聊天单独覆盖这两个开关中的任意一个。选择跟随全局时，则沿用上面的设置。';

  @override
  String get aiReplySummaryThinking => '思考';

  @override
  String get aiReplySummaryAgent => 'agent';

  @override
  String get aiReplySummaryNone => '普通回复';

  @override
  String get personaReplyUseGlobal => '使用「设置」里的全局开关';

  @override
  String get personaReplyAlwaysOn => '该人设始终开启';

  @override
  String get personaReplyAlwaysOff => '该人设始终关闭';

  @override
  String get personaReplyFollowingGlobal => '跟随全局开关';

  @override
  String get personaReplyFollowGlobal => '跟随全局';

  @override
  String get personaReplyFooter =>
      '仅为该人设覆盖「设置 > AI」里的回复开关。它只改变用户在这个聊天中看到的内容，不影响人设说话的方式。';

  @override
  String get chatEditMessageTitle => '编辑消息';

  @override
  String get chatEditHistoryTitle => '编辑记录';

  @override
  String get chatEditCurrentMark => '当前';

  @override
  String chatWalletOpened(String amount) {
    return '已拆开 ¥$amount';
  }

  @override
  String chatWalletReceived(String amount) {
    return '已收到 ¥$amount';
  }

  @override
  String get walletRedPacket => '红包';

  @override
  String get walletTransfer => '转账';

  @override
  String get walletReceived => '已收';

  @override
  String get walletReturned => '已退回';

  @override
  String get walletWaitingOpen => '等待拆开';

  @override
  String get walletTapOpen => '点击拆开';

  @override
  String get walletBestWishes => '恭喜发财';

  @override
  String get walletNoNote => '暂无留言';

  @override
  String get walletBalance => '余额';

  @override
  String get walletPretendNote => '假装的钱，只是为了助兴';

  @override
  String get walletRecords => '记录';

  @override
  String get walletEmpty => '还没有转账记录。对 AI 好一点吧。';

  @override
  String get walletReset => '重置钱包';

  @override
  String get walletResetTitle => '重置钱包？';

  @override
  String get walletResetAction => '重置';

  @override
  String get stickerSettingsTitle => '表情';

  @override
  String get stickerMyStickers => '我的表情';

  @override
  String get stickerTabAll => '表情';

  @override
  String get stickerFavorites => '收藏';

  @override
  String get stickerEmptyPanel => '暂时还是空的，你发的 GIF 和梗图都会存在这里';

  @override
  String get stickerSearchHint => '搜索名称、情绪、标签';

  @override
  String get stickerRecent => '最近';

  @override
  String get stickerSelectAll => '全选';

  @override
  String get stickerEmptyLibrary => '这里还没有内容。点 + 添加一个，或者让助手自动保存你发的梗图。';

  @override
  String get stickerLibraryFooter =>
      '点一下表情可编辑、加标签或删除，长按可选中多个并一次处理。助手会按情绪和语境从中挑选。';

  @override
  String stickerCountSelected(int count) {
    return '已选 $count 个';
  }

  @override
  String get stickerBatchActions => '批量操作';

  @override
  String get stickerBatchMove => '移动到分类';

  @override
  String stickerBatchDeleteTitle(int count) {
    return '删除 $count 个表情？';
  }

  @override
  String get stickerBatchUndo => '此操作无法撤销。';

  @override
  String stickerBatchNow(String category) {
    return '当前：$category';
  }

  @override
  String get stickerAddTitle => '添加表情';

  @override
  String get stickerAddGallery => '相册';

  @override
  String get stickerAddUrl => '链接';

  @override
  String get stickerEmotionOptional => '情绪词（可选）';

  @override
  String get stickerEmotionExample => '例如 lol、无语';

  @override
  String get stickerFieldName => '名称';

  @override
  String get stickerFieldEmotion => '情绪';

  @override
  String get stickerFieldTags => '标签，用逗号分隔';

  @override
  String get stickerFieldCategory => '分类';

  @override
  String get stickerLink => '链接';

  @override
  String get stickerUnfavorite => '取消收藏';

  @override
  String get stickerFavorite => '收藏';

  @override
  String get stickerAiBadge => 'AI';

  @override
  String get humanTitle => '拟人化';

  @override
  String get humanSubtitle => '正在输入、主动发信、表情、记忆';

  @override
  String get humanFooter => '截断标签、主动发信、表情、撤回、心情与记忆。关闭后即可回到朴素的助手模式。';

  @override
  String get humanEnabled => '拟人化模式';

  @override
  String get humanBehaviour => '行为';

  @override
  String get humanBehaviourRow => '正在输入、随机与撤回';

  @override
  String get humanProactive => '主动发信';

  @override
  String get humanStickersRow => '表情';

  @override
  String get humanMemoryRow => '长期记忆';

  @override
  String get humanChatsRow => '对话：心情、角色卡、日程';

  @override
  String get humanToolsHeader => '工具';

  @override
  String get humanToolsRow => '工具、MCP 服务器与权限';

  @override
  String get humanWalletRow => '钱包';

  @override
  String get humanDataHeader => '反馈与数据';

  @override
  String get humanRatingsRow => '评分与调校';

  @override
  String get humanBackupRow => '备份与导入';

  @override
  String get humanSchedDebugRow => '调度器调试面板';

  @override
  String get humanBehaviourTitle => '正在输入与随机性';

  @override
  String get humanBrHeader => '截断标签 <i-br>';

  @override
  String get humanBrFooter => '模型会在气泡之间写入 <i-br_500>，停顿从上一条气泡显示的那一刻开始计时。';

  @override
  String get humanBrToggle => '用 <i-br> 拆分消息';

  @override
  String get humanBrPause => '默认停顿';

  @override
  String get humanReplyDelay => '首条消息前的读消息时间';

  @override
  String get humanPaceScale => '消息间停顿倍率';

  @override
  String get humanRandomHeader => '随机性';

  @override
  String get humanRandomFooter => '固定种子会让同一段对话的同一轮重演相同结果，调试时很方便；留空则每次都重新掷点。';

  @override
  String get humanTypingSpread => '正在输入速度的浮动范围';

  @override
  String get humanTypoChance => '错字概率';

  @override
  String get humanParticleChance => '语气词出现概率';

  @override
  String get humanSplitChance => '拆成多个气泡';

  @override
  String get humanPunctStyle => '标点风格';

  @override
  String get humanPunctNormal => '标准';

  @override
  String get humanPunctLoose => '随意';

  @override
  String get humanPunctMinimal => '极简';

  @override
  String get humanSeedHint => '随机种子（数字，留空即随机）';

  @override
  String get humanRecallHeader => '撤回';

  @override
  String get humanRecallFooter => '只有已经显示过的气泡才能撤回。';

  @override
  String get humanRecallToggle => '允许撤回消息';

  @override
  String get humanRecallPerHour => '每小时撤回次数';

  @override
  String get humanRecallWindow => '撤回时限';

  @override
  String get humanStickerFreq => '发送表情的频率';

  @override
  String get humanAiSaveSticker => '允许 AI 保存表情';

  @override
  String get humanStickerOnly => '允许只发表情的回复';

  @override
  String get humanStickerHeader => '表情';

  @override
  String get proactiveFooter => '助手用 schedule_message 决定何时主动开口，下面是围绕它的限制。';

  @override
  String get proactiveToggle => '允许主动发信';

  @override
  String get proactiveLimits => '限制';

  @override
  String get proactiveMaxConsecutive => '最多连续几条未回复';

  @override
  String get proactiveDnd => '勿扰';

  @override
  String get proactiveQuiet => '免打扰时段';

  @override
  String get proactiveQuietFrom => '免打扰开始';

  @override
  String get proactiveQuietUntil => '免打扰结束';

  @override
  String get proactiveUrgent => '紧急内容可越过免打扰时段';

  @override
  String get proactiveTriggers => '自动触发';

  @override
  String get proactiveTriggersFooter => '这些只是叫醒助手，措辞由它自己决定。陌生人阶段不发送问候。';

  @override
  String get proactiveGreetMorning => '早安问候';

  @override
  String get proactiveMorningAt => '早安时间';

  @override
  String get proactiveGreetEvening => '晚安问候';

  @override
  String get proactiveEveningAt => '晚安时间';

  @override
  String get proactiveIcebreak => '冷场多久后破冰';

  @override
  String proactiveIcebreakUnit(int days) {
    return '$days 天';
  }

  @override
  String get proactiveServer => '服务器兜底';

  @override
  String get proactiveServerFooter =>
      '可选。任务队列会同步到这个后端（POST /api/schedule/sync, GET /api/schedule/due），这样即使应用被杀，任务也不会丢失。本地闹钟和每 15 分钟的后台任务始终会运行。';

  @override
  String get proactiveServerUrl => '服务器地址';

  @override
  String get humanNotSet => '未设置';

  @override
  String get proactiveDebugPanel => '调试面板';

  @override
  String get schedTitle => '调度器调试';

  @override
  String schedPending(int count) {
    return '待执行（$count）';
  }

  @override
  String get schedPendingFooter => '点发送图标会立刻执行任务，忽略时间和触发条件；点垃圾桶图标则取消任务。';

  @override
  String get schedEmpty => '队列里没有任务';

  @override
  String get schedFinished => '最近已完成';

  @override
  String get schedTestTask => '1 分钟后加入一个测试任务';

  @override
  String get schedGate => '触发判定';

  @override
  String get schedToolCalls => '工具调用';

  @override
  String get schedEmptyLog => '（空）';

  @override
  String get schedDue => '到期';

  @override
  String get schedCondition => '条件';

  @override
  String get schedFailures => '失败';

  @override
  String get schedUrgent => '紧急';

  @override
  String schedRemaining(int minutes, int seconds) {
    return '$minutes 分 $seconds 秒';
  }

  @override
  String get humanRatingsTitle => '评分';

  @override
  String get humanRatingsFooter =>
      '你的评分会用来调整助手：烦躁会降低它主动发信的频率，像真人的程度与满意度则会微调风格。开启自动评分后，助手也会从你的行为中推断这些分数。';

  @override
  String get humanRatingHuman => '有多像真人';

  @override
  String get humanRatingAnnoy => '它有多打扰你';

  @override
  String get humanRatingSatisfaction => '整体满意度';

  @override
  String get humanRatingAuto => '自动推断评分';

  @override
  String get humanRatingTuning => '主动发信频率倍率';

  @override
  String get humanBackupTitle => '备份与导入';

  @override
  String get humanSavedCopied => '已保存并复制';

  @override
  String get humanCopiedClipboard => '已复制到剪贴板';

  @override
  String get humanImportTitle => '导入';

  @override
  String get humanImportFooter => '合并会保留现有内容并补上新的条目，覆盖则全部替换。';

  @override
  String get humanOverwrite => '覆盖';

  @override
  String get humanMerge => '合并';

  @override
  String humanImported(int count) {
    return '已导入 $count 条';
  }

  @override
  String get humanInvalidFile => '文件无效';

  @override
  String get humanExport => '导出';

  @override
  String get humanImportFile => '从文件导入';

  @override
  String get humanImportClipboard => '从剪贴板导入';

  @override
  String get humanStickersGroup => '表情与标签';

  @override
  String get humanMemoryGroup => '记忆';

  @override
  String get humanCardsGroup => '角色卡（SillyTavern chara_card_v2）';

  @override
  String get humanCardsFooter => '选择一段对话来导出或导入它的角色卡。';

  @override
  String get humanChatsTitle => '对话';

  @override
  String get humanChatState => '状态';

  @override
  String get humanChatStage => '关系阶段';

  @override
  String get humanChatMessages => '条消息';

  @override
  String get humanChatMinutes => '分钟相伴';

  @override
  String get humanChatStatus => '状态';

  @override
  String get humanChatClearTasks => '清除待执行的主动发信任务';

  @override
  String get humanChatCardHeader => '角色卡';

  @override
  String get humanChatCardFooter => '每次回复前都会注入，好让语气保持一致，助手可能会慢慢微调。';

  @override
  String get humanChatSpeechStyle => '说话风格';

  @override
  String get humanChatCatchphrases => '口头禅';

  @override
  String get humanChatCatchphrasesHint => '口头禅（用逗号分隔）';

  @override
  String get humanChatValues => '价值观';

  @override
  String get humanChatTaboos => '禁忌';

  @override
  String get humanChatAddressStranger => '称呼：陌生人';

  @override
  String get humanChatAddressAcquaintance => '称呼：熟人';

  @override
  String get humanChatAddressClose => '称呼：亲近的人';

  @override
  String get humanChatExportCard => '导出角色卡（chara_card_v2）';

  @override
  String get humanChatCardCopied => '角色卡已复制到剪贴板';

  @override
  String get humanChatImportCard => '从剪贴板导入角色卡';

  @override
  String get humanChatImportCardTitle => '导入角色卡';

  @override
  String get humanChatImportCardFooter => '覆盖会替换整张角色卡，合并只填补空白字段。';

  @override
  String get humanChatInvalidCard => '角色卡无效';

  @override
  String get humanChatSchedule => '每日日程';

  @override
  String get humanChatScheduleFooter =>
      '日程进行中时，状态会改变，精力停止恢复，主动发信也会暂停；结束后助手可能会说自己回来了。';

  @override
  String get humanChatScheduleNow => '现在';

  @override
  String get humanChatScheduleAdd => '添加条目（60 分钟）';

  @override
  String get humanChatScheduleWhat => '在做什么？';

  @override
  String get humanChatScheduleExample => '例如：在开会';

  @override
  String get humanChatFeelings => '数值变化的原因';

  @override
  String get humanChatFeelingsMood => '心情';

  @override
  String get humanChatFeelingsAffection => '好感';

  @override
  String get humanChatFeelingsEnergy => '精力';

  @override
  String get memoryTitle => '记忆';

  @override
  String get memoryNew => '新建记忆';

  @override
  String get memoryNewWhat => '想让 AI 记住什么？';

  @override
  String get memoryNewType => '类型';

  @override
  String get memoryFooter =>
      '权重会随上次使用后经过的时间逐渐衰减。低于阈值的条目会被遗忘，不再注入。承诺和待办在完成前不会衰减。';

  @override
  String get memoryEmpty => '暂无记忆';

  @override
  String get memoryForgotten => '已遗忘';

  @override
  String get memoryDue => '即将到期';

  @override
  String get memoryNotNeeded => '不再需要';

  @override
  String get memoryRestore => '恢复';

  @override
  String get memoryClose => '关闭';

  @override
  String get toolPermTitle => '允许使用这个工具吗？';

  @override
  String get toolPermDeny => '拒绝';

  @override
  String get toolPermAllow => '允许';

  @override
  String get toolPermAsk => '询问';

  @override
  String get toolsTitle => '工具与 MCP';

  @override
  String get toolAddServer => '添加 MCP 服务器';

  @override
  String get toolHeadersJson => '请求头（JSON，可选）';

  @override
  String get toolUrlHint => 'https://host/mcp';

  @override
  String get toolServersHeader => 'MCP 服务器（Streamable HTTP）';

  @override
  String get toolServersFooter =>
      '点按权限可在「允许 → 询问 → 拒绝」之间循环。选择「询问」时每次调用前都会弹出确认，选择「拒绝」则直接拒绝并告诉助手原因。MCP 工具默认为「询问」。';

  @override
  String get toolConnecting => '连接中…';

  @override
  String get toolRefresh => '刷新工具列表';

  @override
  String get toolMcpHeader => 'MCP 工具';

  @override
  String get toolBuiltinHeader => '内置工具';

  @override
  String toolCountSuffix(int count) {
    return '$count 个工具';
  }

  @override
  String get aiEditorTitle => 'AI 编辑器';

  @override
  String get aiEditorNoKey => '请先在「设置」里添加 API 密钥。';

  @override
  String get aiEditorApply => '应用';

  @override
  String get provTitle => '服务商';

  @override
  String get provMissing => '该服务商已不存在。';

  @override
  String get provSearchHint => '搜索模型';

  @override
  String get provConnection => '连接';

  @override
  String get provName => '名称';

  @override
  String get provProtocol => '协议';

  @override
  String get provApiKey => 'API 密钥';

  @override
  String get provBaseUrl => '基础 URL';

  @override
  String get provBaseUrlEmpty => '为空，该服务商无法使用';

  @override
  String get provChatPath => '对话路径';

  @override
  String get provChatPathFixed => '由协议决定';

  @override
  String get provModels => '模型';

  @override
  String get provFetchModels => '获取模型';

  @override
  String get provFetchBusy => '处理中...';

  @override
  String provFetchDone(int count, String source) {
    return '来自$source的 $count 个模型';
  }

  @override
  String get provFetchNever => '按需从服务商拉取真实列表';

  @override
  String get provSourceApi => 'API';

  @override
  String get provSourceCatalog => '内置表';

  @override
  String get provTest => '测试连接';

  @override
  String provTestFailed(String reason) {
    return '失败：$reason';
  }

  @override
  String provTestOk(String reply) {
    return '正常：$reply';
  }

  @override
  String get provTestNever => '发送一次最小请求';

  @override
  String get provAddManual => '手动添加模型';

  @override
  String get provAddManualSub => '用于列表接口不可用的时候';

  @override
  String provCountModels(int count) {
    return '$count 个模型';
  }

  @override
  String get provOnChain => '在兜底链中';

  @override
  String get provDelete => '删除该服务商';

  @override
  String get provFootnote => '能力信息来自服务商 API 和内置表。标记为未知窗口的模型在长对话中会跳过压缩检查。';

  @override
  String get provPasteKey => '粘贴你的 API 密钥';

  @override
  String get provModelIdHint => '模型 ID';

  @override
  String get provProtocolSub => '适用于大多数中转和自建服务器';

  @override
  String provFetchedBulletin(int count) {
    return '已获取 $count 个模型';
  }

  @override
  String get provUsingCatalog => '正在使用内置模型表';

  @override
  String get provFetchFailed => '无法获取模型';

  @override
  String get provAdded => '已添加';

  @override
  String get provNoKeyFirst => '请先添加 API 密钥';

  @override
  String get provConnectionWorks => '连接正常';

  @override
  String provDeleteTitle(String name) {
    return '删除$name？';
  }

  @override
  String get provDeleteMessage => '它的 API 密钥和链上的节点也会一并删除，聊天记录不受影响。';

  @override
  String get provDeleted => '已删除';

  @override
  String get provSaved => '已保存';

  @override
  String provWindow(String tokens) {
    return '窗口 $tokens';
  }

  @override
  String provOut(String tokens) {
    return '输出 $tokens';
  }

  @override
  String get provTagImage => '图像输出';

  @override
  String get provTagUnknownWindow => '未知窗口';

  @override
  String provChainNodeMeta(int retries) {
    return '$retries 次重试 · 关闭';
  }

  @override
  String provChainNodeMetaOn(int retries) {
    return '$retries 次重试';
  }

  @override
  String get attachCaptionHint => '添加说明…';

  @override
  String get attachCameraUnavailable => '相机不可用';

  @override
  String get attachPickerFailed => '无法打开文件选择器';

  @override
  String get attachUploadFiles => '上传文件';

  @override
  String get attachUploadFilesSub => '文档、压缩包以及其他文件';

  @override
  String get attachPhotoPermission => '允许访问你的照片';

  @override
  String get attachOpenSettings => '打开设置';

  @override
  String get attachBrowseAudio => '浏览音频';

  @override
  String get attachBrowseFiles => '浏览文件';

  @override
  String get attachPickSongs => '选择歌曲和语音记录';

  @override
  String get attachPickDocs => '从设备中选择文档';

  @override
  String get attachLocating => '定位中…';

  @override
  String get attachLocationOff => '位置服务已关闭';

  @override
  String get attachLocationDenied => '位置权限被拒绝';

  @override
  String get attachSendLocation => '发送我的当前位置';

  @override
  String get attachLocationUnavailable => '无法获取位置';

  @override
  String attachLocationAccuracy(int meters) {
    return '精确到 $meters 米';
  }

  @override
  String get attachLocationWaiting => '正在等待 GPS';

  @override
  String get attachContactsPermission => '请在系统设置中\n允许访问通讯录';

  @override
  String get attachSearchContacts => '搜索通讯录';

  @override
  String get attachNoContacts => '通讯录为空';

  @override
  String get attachPollQuestionLabel => '问题';

  @override
  String get attachPollOptionsLabel => '选项';

  @override
  String get attachPollSettingsLabel => '设置';

  @override
  String get attachPollQuestion => '提出一个问题';

  @override
  String attachPollOption(int index) {
    return '选项 $index';
  }

  @override
  String get attachPollAddOption => '添加选项';

  @override
  String get attachPollAnonymous => '匿名投票';

  @override
  String get attachPollMultiple => '多选';

  @override
  String get attachPollQuiz => '问答模式';

  @override
  String get attachPollQuizHint => '点击正确答案旁边的圆圈。';

  @override
  String get attachPollFooter => '投票会显示在聊天中，并以文本形式发送给 AI。';

  @override
  String get attachPollCreate => '创建投票';

  @override
  String get attachTabGallery => '相册';

  @override
  String get attachCamera => '相机';

  @override
  String get attachLoading => '正在加载…';

  @override
  String attachSelected(int count) {
    return '已选 $count 项';
  }

  @override
  String cardDepthMessages(int depth) {
    return '往上 $depth 条消息';
  }

  @override
  String get cardFallbackSub => '其他选项都不适用时使用';

  @override
  String get cardSetFallback => '设为兜底卡片';

  @override
  String get cardLockToChat => '把此卡片锁定到当前聊天';

  @override
  String get cardNoChat => '请先创建聊天';

  @override
  String get cardNoChatSub => '打开一个聊天，通过顶部菜单锁定卡片';

  @override
  String get cardLinkPersona => '关联到指定的 AI 人设';

  @override
  String get cardLinkCharacter => '关联到某个角色';

  @override
  String get cardPositionLabel => '位置';

  @override
  String get cardDepthLabel => '深度';

  @override
  String get cardRoleLabel => '角色';

  @override
  String get cardConnectionsHeader => '关联';

  @override
  String get cardDefaultLabel => '默认';

  @override
  String get cardChatLabel => '会话';

  @override
  String get cardCharacterLabel => '角色';

  @override
  String get cardSave => '保存卡片';

  @override
  String get cardCurrentLabel => '当前卡片';

  @override
  String get cardPickTitle => '选择人设卡片';

  @override
  String get cardSetPhoto => '设置头像';

  @override
  String get cardRemovePhoto => '头像已移除';

  @override
  String get msgRecalledAnonymous => '有一条消息被撤回';

  @override
  String get wsTitle => '工作区';

  @override
  String get wsSub => '给 AI 一个自己的目录';

  @override
  String get wsSubOff => '开启文件工具后 AI 才能读写这里';

  @override
  String get wsToolsOff => '文件工具已关';

  @override
  String get wsNoWorkspace => '未绑定工作区';

  @override
  String get wsToolsOn => '文件工具';

  @override
  String get wsToolsFooter => '开启后，已绑定工作区的会话会获得六个文件工具。每次写入都会先把改动给你看。';

  @override
  String get wsConfirmWrites => '每次写入都确认';

  @override
  String get wsConfirmWritesFooter => '关闭后 AI 会直接写入，不再逐次询问。改动仍会显示在步骤行里。';

  @override
  String get wsNew => '新建工作区';

  @override
  String get wsNewTitle => '名称';

  @override
  String get wsCreate => '创建';

  @override
  String get wsRename => '重命名';

  @override
  String get wsDelete => '删除';

  @override
  String wsDeleteConfirm(String name) {
    return '删除「$name」？';
  }

  @override
  String get wsDeleteFiles => '同时删除其中的文件';

  @override
  String get wsDeleteFilesFooter => '关闭则保留设备上的文件。你自己挑选的文件夹无论如何都不会被删除。';

  @override
  String wsBoundTo(int count) {
    return '$count 个会话使用';
  }

  @override
  String get wsNeverUsed => '尚未使用';

  @override
  String get wsFiles => '文件';

  @override
  String get wsToolsTab => '工具';

  @override
  String get wsToolShell => 'Shell';

  @override
  String get wsToolViewImage => '查看图片';

  @override
  String get wsToolsTabFooter => '在这里关闭的工具不会提供给 AI。重新开启也不会覆盖你在工具页设置的权限。';

  @override
  String get wsBind => '绑定工作区';

  @override
  String get wsBindTitle => '选择工作区';

  @override
  String get wsBindNone => '不绑定';

  @override
  String get wsUnbind => '解除绑定';

  @override
  String get wsUnbindConfirm => 'AI 已经在本会话用过这个工作区，仍要解除绑定吗？';

  @override
  String get wsChange => '更换';

  @override
  String get wsCwd => '工作目录';

  @override
  String get wsCwdEmpty => '工作区根目录';

  @override
  String get wsCwdInvalid => '该路径不在工作区内';

  @override
  String get wsReveal => '查看文件';

  @override
  String get wsEmpty => '这里还是空的';

  @override
  String get wsEmptyHint => '让 AI 写一个文件，它就会出现在这个列表里。';

  @override
  String get wsShowHidden => '显示隐藏文件';

  @override
  String get wsSort => '排序';

  @override
  String get wsSortName => '名称';

  @override
  String get wsSortModified => '修改时间';

  @override
  String get wsSortSize => '大小';

  @override
  String get wsFoldersFirst => '文件夹在前';

  @override
  String get wsNewFolder => '新建文件夹';

  @override
  String get wsNewFile => '新建文件';

  @override
  String get wsImport => '导入';

  @override
  String get wsExport => '导出';

  @override
  String get wsExportZip => '打包为 zip';

  @override
  String get wsMove => '移动';

  @override
  String get wsMoveHere => '移动到这里';

  @override
  String get wsCopyPath => '复制路径';

  @override
  String get wsCopiedPath => '路径已复制';

  @override
  String get wsOpenWith => '用其他应用打开';

  @override
  String get wsShare => '分享';

  @override
  String get wsEmptyDir => '这个文件夹是空的';

  @override
  String wsTruncated(int count) {
    return '列表在 $count 项处截断';
  }

  @override
  String get wsPreview => '预览';

  @override
  String get wsPreviewMissing => '文件已不存在';

  @override
  String get wsPreviewTooBig => '文件太大，无法预览';

  @override
  String get wsPreviewBinary => '这不是文本文件';

  @override
  String get wsPreviewEmpty => '空文件';

  @override
  String get wsWrap => '自动换行';

  @override
  String get wsZoomIn => '放大';

  @override
  String get wsZoomOut => '缩小';

  @override
  String get wsRendered => '渲染';

  @override
  String get wsSource => '源码';

  @override
  String get wsWriteTitle => '允许这次改动吗';

  @override
  String get wsWriteNew => '新建文件';

  @override
  String get wsWriteReplace => '替换整个文件';

  @override
  String wsWriteEdit(int count) {
    return '替换 $count 行';
  }

  @override
  String wsWriteCounts(int added, int removed) {
    return '+$added −$removed';
  }

  @override
  String get wsWriteLoose => '宽松匹配';

  @override
  String get wsWriteAllow => '允许';

  @override
  String get wsWriteAllowAll => '本会话全部允许';

  @override
  String get wsWriteRefuse => '拒绝';

  @override
  String get wsWriteRefused => '你拒绝了这次改动';

  @override
  String get wsWriteNoUi => '本次未经确认';

  @override
  String get wsToolRead => '读取';

  @override
  String get wsToolWrite => '写入';

  @override
  String get wsToolEdit => '编辑';

  @override
  String get wsToolList => '列出';

  @override
  String get wsToolGlob => '查找';

  @override
  String get wsToolGrep => '搜索';

  @override
  String get wsToolDenied => '已拒绝';

  @override
  String wsLines(int count) {
    return '$count 行';
  }

  @override
  String wsFilesCount(int count) {
    return '$count 个文件';
  }

  @override
  String wsBytesCount(String size) {
    return '$size';
  }

  @override
  String get wsOpenFile => '打开';

  @override
  String get wsNameEmpty => '给它起个名字';

  @override
  String get wsNameSlash => '名称不能包含斜杠';

  @override
  String get wsNameDot => '这个名称不可用';

  @override
  String get wsNameLeadingDot => '以点开头的名称会被隐藏';

  @override
  String wsPreviewTruncatedLines(Object count) {
    return '仅显示前 $count 行';
  }

  @override
  String get wsDeleteFolderTitle => '删除文件夹？';

  @override
  String get wsDeleteFileTitle => '删除文件？';

  @override
  String get wsOpenTerminal => '终端';

  @override
  String get wsWriteNoPreview => '无法显示原内容';

  @override
  String get wsWriteNoChange => '没有改动';

  @override
  String get toolDescGetTime => '读取当前日期、时间、时区，以及双方最后一次说话的时间';

  @override
  String get toolDescSchedule => '让它之后主动给你发消息';

  @override
  String get toolDescCancelScheduled => '取消一条还没发出的定时消息';

  @override
  String get toolDescModifyScheduled => '修改定时消息的时间或内容';

  @override
  String get toolDescListScheduled => '查看它已经安排好的全部消息';

  @override
  String get toolDescSetStatus => '设置你在会话列表看到的状态';

  @override
  String get toolDescAdjustFeeling => '在好坏时刻之后调整它的心情或好感';

  @override
  String get toolDescWriteMemory => '记下一件值得记住的事';

  @override
  String get toolDescReadMemory => '搜索它已经记住的东西';

  @override
  String get toolDescCompleteTodo => '把它写下的承诺或待办标记完成';

  @override
  String get toolDescLifeSchedule => '声明它正在忙，于是那段时间话少';

  @override
  String get toolDescPinMessage => '在会话里置顶或取消置顶一条消息';

  @override
  String get toolDescEditMessage => '改写它自己先前发过的一条消息';

  @override
  String get toolDescQuoteMessage => '引用某条消息来回复';

  @override
  String get toolDescCharacterCard => '让它缓慢微调自己的人设';

  @override
  String get toolDescRating => '根据你的回应调整它的自我调校';

  @override
  String get toolDescSendSticker => '从表情库发一张贴纸';

  @override
  String get toolDescSaveSticker => '把你发过的梗图存进表情库';

  @override
  String get toolDescRecall => '像人一样撤回刚发出的消息';

  @override
  String get toolDescTypo => '发一条故意打错的字，然后修正';

  @override
  String get toolDescSendImage => '从链接发送一张图片';

  @override
  String get toolDescSendFile => '写一个文本文件并发给你';

  @override
  String get toolDescSendTransfer => '发一个假的红包，点一下就收';

  @override
  String get wsToolDescRead => '按行号读取工作区里的文件';

  @override
  String get wsToolDescWrite => '新建或覆盖文件，写入前你会看到差异';

  @override
  String get wsToolDescEdit => '替换文件中的某一段文字';

  @override
  String get wsToolDescList => '列出某个目录下的文件';

  @override
  String get wsToolDescGlob => '按文件名查找，比如所有 .dart 文件';

  @override
  String get wsToolDescGrep => '用正则搜索文件内容';

  @override
  String get toolNoUrl => '（未填写地址）';

  @override
  String get toolBuiltinFooter => '开启文件工具并为会话绑定工作区后，会出现六个文件工具。';

  @override
  String get wsSubOn => '每个已绑定工作区的会话获得六个文件工具';

  @override
  String get wsToolDescShell => '在 Linux 环境里执行 shell 命令';

  @override
  String get wsToolDescViewImage => '让 AI 查看一张图片';

  @override
  String get actionClose => '关闭';

  @override
  String get termTitle => '终端';

  @override
  String get termNoEnvironment => '尚未安装 Linux 环境';

  @override
  String get termOpenSettings => '打开环境设置';

  @override
  String get termNewShell => '新建 shell';

  @override
  String get termRename => '重命名 shell';

  @override
  String get termCopyAll => '复制全部内容';

  @override
  String get termClear => '清屏';

  @override
  String get termFontBigger => '放大文字';

  @override
  String get termFontSmaller => '缩小文字';

  @override
  String get termCopied => '已复制';

  @override
  String get termSessionDead => '该 shell 已关闭';

  @override
  String get termLinkUnsupported => '无法从这里打开此链接';

  @override
  String get termHint => '在下方输入命令。长按标签可重命名。';

  @override
  String get termSettings => '环境';

  @override
  String get termInstallEnvironment => '安装 Linux 环境后即可使用终端';

  @override
  String get termShellPath => 'Shell 路径';

  @override
  String get termProotArgs => 'PRoot 选项';

  @override
  String get actionPaste => '粘贴';

  @override
  String get termCloseConfirm => '关闭这个 shell？正在运行的程序会停止。';

  @override
  String get termOpenFailedShort => '无法打开 shell';

  @override
  String get envTitle => 'Linux 环境';

  @override
  String get envNotInstalled => '尚未安装环境';

  @override
  String get envReady => '已就绪';

  @override
  String get envInstall => '安装';

  @override
  String get envCancel => '取消';

  @override
  String get envRemove => '移除环境';

  @override
  String get envUpdate => '有可用更新';

  @override
  String get envDownloading => '正在下载';

  @override
  String get envVerifying => '正在校验压缩包';

  @override
  String get envExtracting => '正在解压';

  @override
  String get envPatching => '正在配置';

  @override
  String get envChoose => '选择发行版';

  @override
  String get envArch => '架构';

  @override
  String get envInstallConfirm => '安装这个 Linux 环境？';

  @override
  String get envRemoveConfirm => '移除已安装的 Linux 环境和下载的压缩包？';

  @override
  String envMinFree(int mb) {
    return '需要 $mb MB 可用空间';
  }

  @override
  String get actionTypeDeleteHint => '输入 delete 以确认删除';

  @override
  String get envUnknownError => '环境操作失败';

  @override
  String get envChecking => '正在检查设备支持';

  @override
  String get envUnsupported => '没有适用于此设备的发行版';

  @override
  String envUnsupportedDevice(Object abi) {
    return '没有适用于 ABI $abi 的根文件系统';
  }

  @override
  String get envErrorArchitecture => '环境架构与此应用不匹配';

  @override
  String get envErrorProot => '此版本未包含 PRoot';

  @override
  String get envErrorDisk => '可用存储空间不足';

  @override
  String get envErrorNetwork => '下载失败，请检查网络后重试';

  @override
  String get envErrorChecksum => '下载文件未通过 SHA-256 校验';

  @override
  String get envErrorExtract => '无法解压文件';

  @override
  String get envErrorPatch => '无法配置环境';

  @override
  String get envErrorCancelled => '操作已取消';

  @override
  String get envErrorInvalid => '已安装的环境不完整';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '彼岸雙生';

  @override
  String get actionOk => '確定';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClear => '清除';

  @override
  String get actionDelete => '刪除';

  @override
  String get actionDone => '完成';

  @override
  String get actionSave => '儲存';

  @override
  String get actionRetry => '重試';

  @override
  String get actionCopy => '複製';

  @override
  String get actionAdd => '新增';

  @override
  String get actionRemove => '移除';

  @override
  String get actionDiscard => '捨棄';

  @override
  String get accountTitle => '編輯個人資料';

  @override
  String get accountNameHeader => '你的名字';

  @override
  String get accountNameFooter => '填寫你的名字，並可選擇新增頭像。下方的人設會保留各自的名稱。';

  @override
  String get accountNameHint => '名字';

  @override
  String get accountBioHeader => '個人簡介';

  @override
  String get accountBioFooter => '可以寫幾句關於自己的話。角色可能會讀取它，以更了解你。';

  @override
  String get accountBioHint => '簡介';

  @override
  String get accountPhotoFooter => '長按上方頭像即可快速移除照片。';

  @override
  String get accountSetNewPhoto => '設定新照片';

  @override
  String get accountSetPhoto => '設定頭像';

  @override
  String get accountRemovePhoto => '移除照片';

  @override
  String get accountRemovePhotoTitle => '移除照片';

  @override
  String get accountRemovePhotoMessage => '確定要移除你的頭像嗎？';

  @override
  String get accountPhotoRemoved => '照片已移除';

  @override
  String get accountPhotoActionSet => '設定照片';

  @override
  String get accountPhotoActionChange => '更換照片';

  @override
  String get accountOnlineFallback => '線上';

  @override
  String get accountNameEmptyPreview => '你的名字';

  @override
  String get accountNameRequired => '名字不能空白';

  @override
  String get accountDiscardTitle => '捨棄變更？';

  @override
  String get accountDiscardMessage => '你的個人資料還有尚未儲存的變更。';

  @override
  String get galleryUnavailable => '相簿無法使用';

  @override
  String get actionEdit => '編輯';

  @override
  String get actionSend => '傳送';

  @override
  String get actionRemoveShort => '移除';

  @override
  String get actionEnable => '啟用';

  @override
  String get actionDisable => '停用';

  @override
  String get actionMoveUp => '上移';

  @override
  String get actionMoveDown => '下移';

  @override
  String get actionCurrent => '目前';

  @override
  String get aiTabProviders => '服務商';

  @override
  String get aiTabChain => '兜底鏈';

  @override
  String get aiTabAdvanced => '進階';

  @override
  String get aiTitle => 'AI 設定';

  @override
  String get aiReadyTitle => 'AI 已就緒';

  @override
  String get aiNotReadyTitle => 'AI 尚未設定';

  @override
  String get aiNotReadyMessage => '先為某個服務商新增 API 金鑰，再把它的一個模型放到兜底鏈上。';

  @override
  String aiOnChainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '兜底鏈上有 $count 個模型',
      one: '兜底鏈上有 1 個模型',
    );
    return '$_temp0';
  }

  @override
  String get aiProvidersHeader => '服務商';

  @override
  String get aiProvidersFooter => '模型能力取自服務商 API 與內建目錄，上下文視窗決定了記錄在什麼時候被壓縮。';

  @override
  String get aiAddProvider => '新增服務商';

  @override
  String get aiAddProviderTitle => '新增服務商';

  @override
  String get aiAddProviderHint => '名稱，例如 My Relay';

  @override
  String get aiKeySet => '已設定 API 金鑰';

  @override
  String get aiNoKey => '未設定 API 金鑰';

  @override
  String aiProviderOnChain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個模型',
      one: '1 個模型',
    );
    return '$_temp0 在兜底鏈中';
  }

  @override
  String aiProviderModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個模型',
      one: '1 個模型',
    );
    return '$_temp0';
  }

  @override
  String get aiChainHeader => '兜底鏈';

  @override
  String aiChainActiveCount(int active, int total) {
    return '$total 個中啟用 $active 個';
  }

  @override
  String get aiChainEmpty => '尚未設定兜底鏈';

  @override
  String get aiChainEmptyHint => '兜底鏈是空的。加一個模型後，請求會優先傳給它。';

  @override
  String get aiChainFooter =>
      '請求會依序逐一嘗試。點模型可調整順序、修改重試次數或移除。驗證與計費失敗不會重試，直接跳到下一個模型。';

  @override
  String get aiAddModel => '新增模型';

  @override
  String get aiCompactionHeader => '上下文壓縮';

  @override
  String get aiCompactionFooter => '上下文溢出時會重試一次壓縮，仍失敗就直接截斷歷史記錄。';

  @override
  String get aiCompactionToggle => '壓縮過長的對話';

  @override
  String get aiCompactionToggleSub => '較早的對話會被濃縮成摘要';

  @override
  String get aiSummaryModel => '摘要模型';

  @override
  String get aiSummaryModelFollows => '跟隨兜底鏈上的第一個模型';

  @override
  String get aiSummaryLength => '摘要長度';

  @override
  String get aiAddToChainTitle => '新增至兜底鏈';

  @override
  String get aiSummaryModelPickerTitle => '用於產生摘要的模型';

  @override
  String get aiSummaryLengthTitle => '摘要長度';

  @override
  String get aiLengthTight => '精簡';

  @override
  String get aiLengthBalanced => '適中';

  @override
  String get aiLengthDetailed => '詳盡';

  @override
  String get aiChainMenuRetries => '重試次數';

  @override
  String get aiRetriesTitle => '換下一個模型前的重試次數';

  @override
  String get aiRetriesNone => '不重試';

  @override
  String get aiRepliesHeader => '回覆';

  @override
  String get aiRepliesFooter => '人格化模式會把一則回覆拆成幾則短訊息，就像真人傳訊息那樣。';

  @override
  String get aiReplyStyle => '回覆風格';

  @override
  String get aiReplyStyleFull => '完整';

  @override
  String get aiReplyStyleCharacter => '人格化';

  @override
  String get aiReplyStyleFullSub => '逐字串流輸出，並顯示思考過程';

  @override
  String get aiReplyStyleCharacterSub => '像真人一樣分成幾則短訊息發送';

  @override
  String get aiFirstBubbleDelay => '回覆前的讀訊息時間';

  @override
  String get aiBubbleGapScale => '訊息間停頓倍率';

  @override
  String get aiPacingOff => '關閉';

  @override
  String get aiPacingDelayHint => '第一則訊息立即送達';

  @override
  String get aiPacingJitter => '節奏隨機幅度';

  @override
  String get aiPacingJitterLow => '輕微';

  @override
  String get aiPacingJitterNormal => '標準';

  @override
  String get aiPacingJitterWild => '狂放';

  @override
  String get aiPacingJitterHintOff => '每個停頓都和設定值一樣長';

  @override
  String get aiPacingJitterHintLow => '停頓在設定值附近輕微浮動';

  @override
  String get aiPacingJitterHintNormal => '每個停頓都有人類式的不均勻';

  @override
  String get aiPacingJitterHintWild => '難以預測，有時秒回有時磨蹭';

  @override
  String get aiSamplingHeader => '取樣';

  @override
  String get aiSamplingFooter => '對話裡不會顯示任何模型細節。';

  @override
  String get aiTemperature => '溫度';

  @override
  String get aiTempDeterministic => '穩定';

  @override
  String get aiTempFocused => '專注';

  @override
  String get aiTempBalanced => '均衡';

  @override
  String get aiTempLoose => '奔放';

  @override
  String get aiMaxOutput => '最大輸出';

  @override
  String get aiModelDefault => '預設模型';

  @override
  String get aiUseCatalogDefault => '使用目錄預設值';

  @override
  String get aiSummaryNoNodes => '兜底鏈還沒有節點';

  @override
  String get aiSummaryNoKey => '尚未設定 API 金鑰';

  @override
  String get aiCapsReasoning => '思考';

  @override
  String get aiCapsVision => '視覺';

  @override
  String get aiTokensUnknown => '未知';

  @override
  String get tabChats => '聊天';

  @override
  String get tabSettings => '設定';

  @override
  String get tabProfile => '我的';

  @override
  String get chatsTitle => '聊天';

  @override
  String get chatsSearchHint => '搜尋';

  @override
  String get chatsEmptyTitle => '還沒有聊天';

  @override
  String get chatsEmptySub => '建立一個人設，開始聊天。';

  @override
  String get chatsNewPersona => '新增人設';

  @override
  String get chatsMenuReadAll => '全部已讀';

  @override
  String get chatsRowTyping => '正在輸入';

  @override
  String get chatsRowDraft => '草稿：';

  @override
  String get chatsRowEmpty => '還沒有訊息';

  @override
  String get chatsRowYou => '你：';

  @override
  String get menuPin => '置頂';

  @override
  String get menuUnpin => '取消置頂';

  @override
  String get menuMute => '勿擾';

  @override
  String get menuUnmute => '取消勿擾';

  @override
  String get menuMarkAsRead => '標為已讀';

  @override
  String get menuClearHistory => '清除紀錄';

  @override
  String get menuDeleteChat => '刪除對話';

  @override
  String get dialogClearHistoryTitle => '清除對話紀錄';

  @override
  String dialogClearHistoryMessage(String personaName) {
    return '刪除 $personaName 中的所有訊息？';
  }

  @override
  String get dialogDeleteChatTitle => '刪除聊天';

  @override
  String dialogDeleteChatMessage(String personaName) {
    return '這會移除 $personaName 及其對話紀錄。';
  }

  @override
  String get chatEmptyPill => '這裡還沒有訊息...';

  @override
  String get chatSearchHint => '搜尋訊息';

  @override
  String get chatSearchNoResults => '沒有結果';

  @override
  String chatSearchCount(int index, int total) {
    return '第 $index 則，共 $total 則';
  }

  @override
  String get chatSearchModeChat => '對話';

  @override
  String get chatSearchModeList => '清單';

  @override
  String get chatStatusTyping => '正在輸入';

  @override
  String get chatStatusBot => '機器人';

  @override
  String get chatMenuReply => '回覆';

  @override
  String get chatMenuCopy => '複製';

  @override
  String get chatMenuRegenerate => '重新生成';

  @override
  String get chatMenuDelete => '刪除';

  @override
  String get toastMessageCopied => '訊息已複製';

  @override
  String get headerMenuSearch => '搜尋';

  @override
  String get headerMenuViewProfile => '查看個人檔案';

  @override
  String get headerMenuEditPersona => '編輯人設';

  @override
  String get headerMenuMutedSub => '通知已關閉';

  @override
  String get headerMenuLockPersona => '鎖定我的人設';

  @override
  String get headerMenuClearHistory => '清除記錄';

  @override
  String get headerMenuDeleteChat => '刪除對話';

  @override
  String get dialogClearHistoryHereTitle => '清除對話紀錄';

  @override
  String get dialogClearHistoryHereMessage => '刪除此聊天中的所有訊息？';

  @override
  String get dialogDeleteChatHereTitle => '刪除聊天';

  @override
  String get lockSheetTitle => '鎖定我的人設';

  @override
  String get lockSheetSub => '此聊天一律以你選擇的卡片身分回覆。';

  @override
  String get lockSheetUnnamed => '未命名';

  @override
  String get lockSheetNone => '不鎖定';

  @override
  String get lockSheetNoneSub => '使用「我的帳號」中選取的卡片';

  @override
  String get lockSheetEmpty => '還沒有人設卡片。到「我的帳號」建立一張。';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsAccount => '我的帳號';

  @override
  String get settingsAccountSub => '名稱與簡介';

  @override
  String get settingsAi => 'AI';

  @override
  String get settingsAiSubNone => '兜底鏈中沒有模型';

  @override
  String get settingsAppearance => '對話外觀';

  @override
  String get settingsAppearanceSub => '夜間模式、字級、圓角';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsVibrationOn => '震動已開啟';

  @override
  String get settingsVibrationOff => '震動已關閉';

  @override
  String get settingsData => '資料與儲存空間';

  @override
  String settingsDataSub(int chats, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats 個對話',
      one: '1 個對話',
    );
    return '$_temp0 · 媒體 $size';
  }

  @override
  String get settingsAbout => '關於';

  @override
  String get aboutLinkFailed => '無法開啟連結';

  @override
  String get settingsAboutSub => '版本 1.0.1';

  @override
  String get settingsAboutLicense =>
      '開發者: 殘月。請遵守 AGPL 3.0 開源授權，這意味著您不得在閉源的前提下二次分發和商業化本項目，若違反，我們將依法處理。';

  @override
  String get settingsAboutCommunity => '加入交流群:';

  @override
  String get settingsAboutRepo => '本項目地址:\nhttps://github.com/Celvra/paradise';

  @override
  String get settingsAboutThanks =>
      '鳴謝:\n\nKelivo - ToolCall 參考\nhttps://github.com/Chevey339/kelivo\n\nSillyTavern - 人設卡參考\nhttps://github.com/SillyTavern/SillyTavern';

  @override
  String get settingsAboutDeps =>
      '依賴庫:\n\ncharacters 1.4.1 - 字形叢集，用於正確計算文字寬度  (BSD-3-Clause)\nhttps://github.com/dart-lang/core/tree/main/pkgs/characters\nfile_picker 13.1.0 - 檔案與音訊選擇  (MIT)\nhttps://github.com/vicajilau/flutter_file_picker/tree/main/packages/file_picker\nflutter_contacts 2.5.0 - 分享聯絡人名片  (MIT)\nhttps://github.com/QuisApp/flutter_contacts\nflutter_local_notifications 18.0.1 - 本機通知  (BSD-3-Clause)\nflutter_svg 2.3.0 - 服務商圖示與向量圖示  (MIT)\nhttps://github.com/flutter/packages/tree/main/third_party/packages/flutter_svg\ngeolocator 13.0.4 - 位置附件  (MIT)\nhttps://github.com/baseflow/flutter-geolocator/tree/main/geolocator\nhttp 1.6.0 - OpenAI 相容介面請求  (BSD-3-Clause)\nhttps://github.com/dart-lang/http/tree/master/pkgs/http\nimage_picker 1.2.3 - 相機與相簿圖片  (Apache-2.0)\nhttps://github.com/flutter/packages/tree/main/packages/image_picker/image_picker\nintl 0.20.3 - 日期與數字格式化  (BSD-3-Clause)\nhttps://github.com/dart-lang/i18n/tree/main/pkgs/intl\npath_provider 2.1.6 - 應用程式目錄，用於表情與匯出檔案  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/path_provider/path_provider\nphoto_manager 3.12.0 - 相簿存取，用於附件  (Apache-2.0)\nhttps://github.com/fluttercandies/flutter_photo_manager\nshared_preferences 2.5.5 - 設定與對話紀錄儲存  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences\nsqflite 2.4.4 - 訊息歷史與對話分頁  (BSD-2-Clause)\nhttps://github.com/tekartik/sqflite/tree/master/sqflite\ntimezone 0.10.1 - 排程訊息的時區資料  (BSD-2-Clause)\nhttps://github.com/srawlins/timezone\nurl_launcher 6.3.2 - 本彈出視窗中的交流群連結  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher\nworkmanager 0.10.10 - 應用程式被關閉後的背景送達  (MIT)\nhttps://github.com/fluttercommunity/flutter_workmanager';

  @override
  String get settingsAboutCommunityUrl => 'https://discord.gg/aQaNUHPsw';

  @override
  String get settingsFooter => 'Developed by Celvra';

  @override
  String get previewSampleIncoming => '早安！今天有什麼可以幫你的？';

  @override
  String get previewSampleOutgoing => '說說 transformers 是怎麼運作的';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get appearanceTheme => '主題';

  @override
  String get wallpaperHeader => '聊天壁紙';

  @override
  String get wallpaperRow => '壁紙';

  @override
  String get wallpaperDefault => '預設';

  @override
  String get wallpaperChoose => '選擇圖片';

  @override
  String get wallpaperNone => '純色漸層';

  @override
  String get wallpaperFollowGlobal => '跟隨全域';

  @override
  String get wallpaperBlur => '模糊壁紙';

  @override
  String get wallpaperBlurSub => '讓氣泡在照片上依然清晰';

  @override
  String get wallpaperColorHeader => '壁紙取色';

  @override
  String get wallpaperColorFooter => '選一個顏色，用於強調色和你發出的氣泡。';

  @override
  String get wallpaperColorNone => '預設';

  @override
  String get wallpaperNoColors => '這張圖沒有可取的顏色';

  @override
  String get wallpaperBubbleGrad => '氣泡漸層';

  @override
  String get wallpaperBubbleGradSubtle => '輕微';

  @override
  String get wallpaperBubbleGradMedium => '適中';

  @override
  String get wallpaperBubbleGradStrong => '明顯';

  @override
  String get wallpaperBubbleGradSub => '控制你發出的氣泡從上到下的深淺跨度。';

  @override
  String get wallpaperRemoved => '已移除壁紙';

  @override
  String get wallpaperChatTitle => '本對話壁紙';

  @override
  String get appearanceNightMode => '夜間模式';

  @override
  String get appearancePreview => '訊息預覽';

  @override
  String get appearanceTextSize => '訊息字級';

  @override
  String get appearanceSize => '字級';

  @override
  String get appearanceCorners => '訊息圓角';

  @override
  String get appearanceRadius => '圓角';

  @override
  String get appearanceReset => '回復預設';

  @override
  String get notifAlerts => '提醒';

  @override
  String get notifVibrate => '回覆時震動';

  @override
  String get notifVibrateSub => '收到回答時輕震一下';

  @override
  String get notifCountMuted => '統計勿擾對話';

  @override
  String get notifCountMutedSub => '把它們計入分頁標籤的角標';

  @override
  String get notifFooter => '每個對話也可以從它的選單或個人檔頁設為勿擾。';

  @override
  String get dataUsage => '用量';

  @override
  String get dataChats => '對話';

  @override
  String get dataMessages => '訊息';

  @override
  String get dataMedia => '媒體與檔案';

  @override
  String get dataClear => '清除';

  @override
  String get dataClearSearch => '清除搜尋記錄';

  @override
  String get dataClearMedia => '清除媒體與檔案';

  @override
  String get dataClearMediaTitle => '清除媒體';

  @override
  String get dataClearMediaMessage => '所有對話中的照片、檔案和音樂都會被刪除。';

  @override
  String get dataClearAll => '清除所有對話';

  @override
  String get dataClearAllTitle => '清除所有對話';

  @override
  String get dataClearAllMessage => '這會刪除所有聊天裡的每一則訊息，人設會保留。';

  @override
  String get dataBackup => '備份';

  @override
  String get dataBackupExportSub => '對話、人格卡、表情與設定';

  @override
  String get dataBackupImportSub => '從之前匯出的檔案還原';

  @override
  String dataBackupRestored(num chats, Object messages) {
    return '$chats 個對話，$messages 則訊息';
  }

  @override
  String get dataBackupNothing => '這個檔案裡沒有可還原的內容';

  @override
  String get dataBackupSaved => '備份已儲存';

  @override
  String get dataBackupSaveFailed => '無法儲存檔案';

  @override
  String get dayToday => '今天';

  @override
  String get dayYesterday => '昨天';

  @override
  String get emojiSearchHint => '輸入以搜尋';

  @override
  String get emojiNothingFound => '找不到';

  @override
  String get personaDiscardExisting => '你對這個人設的修改將會遺失。';

  @override
  String get personaDiscardNew => '這個人設還沒建立。';

  @override
  String get personaNameHeader => '名稱';

  @override
  String get personaNameHint => '人設名稱';

  @override
  String get personaAboutHeader => '關於';

  @override
  String get personaAboutFooter => '顯示在個人資料頁上的一句話，不會傳送給模型。';

  @override
  String get personaInstructionsHeader => '指令';

  @override
  String get personaInstructionsFooter => '這段內容會成為本對話中每一次請求的系統提示詞。';

  @override
  String get personaInstructionsHint => '你希望 AI 如何表現？';

  @override
  String get personaGreetingHeader => '問候';

  @override
  String get personaGreetingFooter => '選填。開啟對話時會作為第一則訊息傳送。';

  @override
  String get personaGreetingHint => '人設的第一則訊息';

  @override
  String get personaSave => '儲存變更';

  @override
  String get personaCreate => '建立人設';

  @override
  String get personaTemplatesHeader => '從範本開始';

  @override
  String get personaAppearanceHeader => '外觀';

  @override
  String get personaAppearanceFooterPhoto => '設定照片後，所有顯示大頭貼的地方都會以照片取代表情符號。';

  @override
  String get personaAppearanceFooterColor => '這個顏色用於大頭貼與個人資料頁封面。';

  @override
  String get personaPhotoTitle => '照片';

  @override
  String get personaPhotoTitleEmpty => '大頭貼照片';

  @override
  String get personaPhotoSubFull => '點擊更換，長按移除';

  @override
  String get personaPhotoSubEmpty => '新增一張照片，或沿用下面的顏色';

  @override
  String get personaChoose => '選擇';

  @override
  String get personaModelForThis => '此人設使用的模型';

  @override
  String get personaModelGlobal => '全域';

  @override
  String get personaModelGlobalSub => '依循兜底鏈目前的設定';

  @override
  String get personaModelFooterOverride => '關閉後，這個模型失敗會直接結束回覆，不再嘗試全域兜底鏈。';

  @override
  String get personaModelFooterGlobal =>
      '全域模式下使用「設定 > AI」裡的兜底鏈。選一個模型就能讓人設單獨使用它。';

  @override
  String get personaModelGlobalChain => '全域兜底鏈';

  @override
  String get personaModelOnlyThis => '僅此人設';

  @override
  String get personaModelFollowsSettings => '依循「設定 > AI」';

  @override
  String get personaModelChange => '更改';

  @override
  String get personaModelFallback => '回退到全域兜底鏈';

  @override
  String get personaModelUseGlobal => '使用全域兜底鏈';

  @override
  String get presetAssistantBio => '沉穩冷靜的萬能幫手';

  @override
  String get presetCoderBio => '以閱讀堆疊資訊為樂';

  @override
  String get presetTranslatorBio => '中英雙向翻譯';

  @override
  String get presetWriterBio => '把每句話都精煉一遍';

  @override
  String get presetTutorBio => '像朋友一樣講給你聽';

  @override
  String get aiFollowChain => '跟隨鏈上的第一個節點';

  @override
  String get aiFollowChainSub => '總結時使用目前的主模型';

  @override
  String get aiSearchModels => '搜尋模型';

  @override
  String get aiNoModelsLoaded => '還沒有載入模型。\n請先從服務商取得一份清單。';

  @override
  String aiNoModelMatches(String query) {
    return '沒有符合「$query」的結果';
  }

  @override
  String get codeGeneric => '程式碼';

  @override
  String get toastCodeCopied => '程式碼已複製';

  @override
  String get searchFilterAll => '全部';

  @override
  String get searchRecent => '最近';

  @override
  String get searchPeople => '人';

  @override
  String get searchNoResultsTitle => '沒有結果';

  @override
  String get searchEmptyBody => '還沒有分享過這類內容。';

  @override
  String searchNoResultsBody(String query) {
    return '找不到與「$query」相關的結果，換個關鍵字再試試。';
  }

  @override
  String get profileButtonEdit => '編輯';

  @override
  String get profileButtonShare => '分享';

  @override
  String get profileButtonMessage => '傳訊息';

  @override
  String get profileButtonSearch => '搜尋';

  @override
  String get profileCopied => '個人檔案已複製';

  @override
  String get profileLabelName => '名稱';

  @override
  String get profileLabelBio => '簡介';

  @override
  String get profileLabelPersonaCard => '人設卡片';

  @override
  String get profileLabelActivity => '動態';

  @override
  String get profileLabelAbout => '關於';

  @override
  String get profileLabelInstructions => '指令';

  @override
  String get profileLabelModel => '模型';

  @override
  String get profileLabelNotifications => '通知';

  @override
  String get profileBioEmpty => '寫幾句關於自己的話';

  @override
  String get profileCardEmpty => '告訴 AI 你是誰';

  @override
  String profileActivity(int chats, int sent) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats 個對話',
      one: '1 個對話',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '已送出 $sent 則',
      one: '已送出 1 則',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get profileOn => '開';

  @override
  String get profileOff => '關';

  @override
  String get profileHeaderTyping => '正在輸入...';

  @override
  String toastCopiedLabel(String label) {
    return '已複製$label';
  }

  @override
  String get profileTabMedia => '媒體';

  @override
  String get profileTabFiles => '檔案';

  @override
  String get profileTabMusic => '音樂';

  @override
  String get profileTabLinks => '連結';

  @override
  String get profileSharedEmptyMedia => '還沒有媒體';

  @override
  String get profileSharedEmptyFiles => '還沒有檔案';

  @override
  String get profileSharedEmptyMusic => '還沒有音樂';

  @override
  String get profileSharedEmptyLinks => '還沒有連結';

  @override
  String get msgLeadPhoto => '照片';

  @override
  String get msgLeadMusic => '音樂';

  @override
  String get msgLeadContact => '聯絡人';

  @override
  String get msgLeadPoll => '投票';

  @override
  String get msgLeadSticker => '表情';

  @override
  String get attachAudioFallback => '音訊';

  @override
  String get attachFileFallback => '檔案';

  @override
  String get attachLocationTitle => '位置';

  @override
  String get attachLocationCopied => '座標已複製';

  @override
  String get attachNoPhone => '沒有電話號碼';

  @override
  String get pollKindQuiz => '問答';

  @override
  String get pollKindPublic => '公開投票';

  @override
  String get pollKindAnonymous => '匿名投票';

  @override
  String pollKindMultiple(String kind) {
    return '$kind · 多選';
  }

  @override
  String photoCounter(int index, int total) {
    return '第 $index 張，共 $total 張';
  }

  @override
  String get profileFileFallback => '檔案';

  @override
  String get errorAuth => 'API 金鑰無效或沒有存取權限';

  @override
  String get errorQuota => '服務商額度已用盡';

  @override
  String get errorRate => '被服務商限流';

  @override
  String get errorContextOverflow => '上下文比模型的視窗更長';

  @override
  String get errorServer => '服務商回傳了一個錯誤';

  @override
  String get errorNetwork => '網路連線失敗';

  @override
  String get errorAborted => '生成已停止';

  @override
  String get errorEmpty => '模型沒有回傳內容';

  @override
  String get errorUnknown => '請求失敗';

  @override
  String errorStoppedEarly(String reason) {
    return '提前停止：$reason';
  }

  @override
  String pluralChats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個對話',
      one: '1 個對話',
    );
    return '$_temp0';
  }

  @override
  String pluralVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
      one: '1 票',
      zero: '還沒有人投票',
    );
    return '$_temp0';
  }

  @override
  String pluralSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選 $count 個',
    );
    return '$_temp0';
  }

  @override
  String pluralModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個模型',
      one: '1 個模型',
    );
    return '$_temp0';
  }

  @override
  String pluralRetries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重試 $count 次',
      one: '重試 1 次',
    );
    return '$_temp0';
  }

  @override
  String pluralOptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個選項',
    );
    return '$_temp0';
  }

  @override
  String pluralChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個字元',
    );
    return '$_temp0';
  }

  @override
  String pluralTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個 token',
    );
    return '$_temp0';
  }

  @override
  String get cardCreate => '建立卡片';

  @override
  String get cardDeleteThisCard => '這張卡片';

  @override
  String get cardDeleteTitle => '刪除卡片';

  @override
  String get cardDeleted => '卡片已刪除';

  @override
  String get cardDescHint => '你是誰、你怎麼說話、你的喜好';

  @override
  String get cardDuplicate => '複製';

  @override
  String get cardDuplicated => '卡片已複製';

  @override
  String get cardEditing => '編輯卡片';

  @override
  String get cardEmptyBody => '建立一張人設卡片，讓 AI 知道你是誰。';

  @override
  String get cardEmptyTitle => '還沒有人設卡片';

  @override
  String get cardFieldDescription => '描述';

  @override
  String get cardFieldName => '名稱';

  @override
  String get cardFieldNameHint => 'AI 對你的稱呼';

  @override
  String get cardFieldTitle => '標題';

  @override
  String get cardFieldTitleHint => '僅在列表中顯示';

  @override
  String get cardInfoFooter => '每次請求都會把這段描述一併傳送給模型。';

  @override
  String get cardNew => '新增卡片';

  @override
  String get cardPlaceholdersHint => '使用 user 與 char 佔位符。';

  @override
  String get cardPositionTitle => '在提示詞中的位置';

  @override
  String get cardRoleTitle => '注入訊息的角色';

  @override
  String get posAtDepth => '按深度插入';

  @override
  String get posAtDepthSub => '從最新一則往回數，插入到幾則訊息之前';

  @override
  String get posBottomNote => '底部備註';

  @override
  String get posBottomNoteSub => '對話開始前讀到的最後一段內容';

  @override
  String get posInPrompt => '併入提示詞';

  @override
  String get posInPromptSub => '合併進系統提示詞';

  @override
  String get posNone => '關閉';

  @override
  String get posNoneSub => '不會傳送這張卡片';

  @override
  String get posTopNote => '頂部備註';

  @override
  String get posTopNoteSub => '在其他所有內容之前';

  @override
  String get roleAssistant => '助理';

  @override
  String get roleSystem => '系統';

  @override
  String get roleUser => '使用者';

  @override
  String cardDeleteMessage(String name) {
    return '刪除 $name？此操作無法復原。';
  }

  @override
  String msgRecalled(String name) {
    return '$name 收回了一則訊息';
  }

  @override
  String get msgEdited => '編輯過';

  @override
  String get msgPinned => '已置頂的訊息';

  @override
  String get traceThinking => '思考';

  @override
  String get traceThinkingNow => '思考中…';

  @override
  String traceThoughtFor(String seconds) {
    return '思考了 $seconds';
  }

  @override
  String get traceRunning => '執行中';

  @override
  String get traceFailed => '失敗';

  @override
  String get traceArguments => '引數';

  @override
  String get traceResult => '結果';

  @override
  String traceSeconds(String value) {
    return '${value}s';
  }

  @override
  String get statusOnline => '線上';

  @override
  String get statusAway => '離開';

  @override
  String get statusDnd => '勿擾';

  @override
  String get statusRead => '已讀';

  @override
  String get searchGeneric => '搜尋';

  @override
  String get inputMessageHint => '訊息';

  @override
  String get aiReplyTitle => 'AI 回覆';

  @override
  String get aiReplyStyleHeader => '節奏';

  @override
  String get aiReplyVisibleHeader => '你能看到的內容';

  @override
  String get aiReplyVisibleFooter =>
      '開啟顯示思考後，思考模型的推理過程會作為可展開的步驟寫在答案上方。Agent 模式讓模型呼叫工具，並為每次呼叫加上一列，顯示它的參數與結果。';

  @override
  String get aiReplyMarkdown => 'Markdown';

  @override
  String get aiReplyMarkdownSub => '在氣泡裡渲染粗體、程式碼區塊與標題；關閉後人格化模式會去掉這些標記';

  @override
  String get aiReplyShowThinking => '顯示思考';

  @override
  String get aiReplyShowThinkingSub => '把推理過程寫進對話裡，而不是藏起來';

  @override
  String get aiReplyAgentMode => 'Agent 模式';

  @override
  String get aiReplyAgentModeSub => '工具與 MCP 呼叫，每一步即時顯示';

  @override
  String get aiReplyToolsHeader => '工具';

  @override
  String get aiReplyToolsFooter =>
      'Agent 模式會給模型三個內建工具（時間、抓取網頁、列出 MCP 伺服器），再加上你的 MCP 伺服器提供的全部工具。每個工具都能在工具頁設為詢問、允許或拒絕。';

  @override
  String get aiReplyToolsRow => '工具、MCP 伺服器與權限';

  @override
  String aiReplyToolsCount(int count) {
    return '可用 MCP 工具 $count 個';
  }

  @override
  String get aiReplyPersonaFooter =>
      '人設卡片可以為自己的聊天單獨覆寫這兩個開關中的任一個。選擇跟隨全域時，則沿用上面的設定。';

  @override
  String get aiReplySummaryThinking => '思考';

  @override
  String get aiReplySummaryAgent => 'agent';

  @override
  String get aiReplySummaryNone => '一般回覆';

  @override
  String get personaReplyUseGlobal => '使用「設定」裡的全域開關';

  @override
  String get personaReplyAlwaysOn => '該人設一律開啟';

  @override
  String get personaReplyAlwaysOff => '該人設一律關閉';

  @override
  String get personaReplyFollowingGlobal => '依循全域開關';

  @override
  String get personaReplyFollowGlobal => '依循全域';

  @override
  String get personaReplyFooter =>
      '僅為該人設覆寫「設定 > AI」裡的回覆開關。它只改變使用者在這個聊天中看到的內容，不影響人設說話的方式。';

  @override
  String get chatEditMessageTitle => '編輯訊息';

  @override
  String get chatEditHistoryTitle => '編輯記錄';

  @override
  String get chatEditCurrentMark => '目前';

  @override
  String chatWalletOpened(String amount) {
    return '已拆開 ¥$amount';
  }

  @override
  String chatWalletReceived(String amount) {
    return '已收到 ¥$amount';
  }

  @override
  String get walletRedPacket => '紅包';

  @override
  String get walletTransfer => '轉帳';

  @override
  String get walletReceived => '已收';

  @override
  String get walletReturned => '已退回';

  @override
  String get walletWaitingOpen => '等待開啟';

  @override
  String get walletTapOpen => '點擊拆開';

  @override
  String get walletBestWishes => '恭喜發財';

  @override
  String get walletNoNote => '暫無留言';

  @override
  String get walletBalance => '餘額';

  @override
  String get walletPretendNote => '假裝的錢，只是為了應景';

  @override
  String get walletRecords => '記錄';

  @override
  String get walletEmpty => '還沒有轉帳紀錄。對 AI 好一點吧。';

  @override
  String get walletReset => '重設錢包';

  @override
  String get walletResetTitle => '重設錢包？';

  @override
  String get walletResetAction => '重設';

  @override
  String get stickerSettingsTitle => '表情';

  @override
  String get stickerMyStickers => '我的表情';

  @override
  String get stickerTabAll => '表情';

  @override
  String get stickerFavorites => '收藏';

  @override
  String get stickerEmptyPanel => '暫時還是空的，你傳送的 GIF 與梗圖都會存在這裡';

  @override
  String get stickerSearchHint => '搜尋名稱、情緒、標籤';

  @override
  String get stickerRecent => '最近';

  @override
  String get stickerSelectAll => '全選';

  @override
  String get stickerEmptyLibrary => '這裡還沒有內容。點 + 新增一個，或讓助手自動儲存你傳送的梗圖。';

  @override
  String get stickerLibraryFooter =>
      '點一下表情可編輯、加標籤或刪除，長按可選取多個並一次處理。助手會依情緒與語境從中挑選。';

  @override
  String stickerCountSelected(int count) {
    return '已選 $count 個';
  }

  @override
  String get stickerBatchActions => '批次操作';

  @override
  String get stickerBatchMove => '移動到分類';

  @override
  String stickerBatchDeleteTitle(int count) {
    return '刪除 $count 個表情？';
  }

  @override
  String get stickerBatchUndo => '此操作無法復原。';

  @override
  String stickerBatchNow(String category) {
    return '目前：$category';
  }

  @override
  String get stickerAddTitle => '新增表情';

  @override
  String get stickerAddGallery => '相簿';

  @override
  String get stickerAddUrl => '連結';

  @override
  String get stickerEmotionOptional => '情緒詞（選填）';

  @override
  String get stickerEmotionExample => '例如 lol、無言';

  @override
  String get stickerFieldName => '名稱';

  @override
  String get stickerFieldEmotion => '情緒';

  @override
  String get stickerFieldTags => '標籤，以逗號分隔';

  @override
  String get stickerFieldCategory => '分類';

  @override
  String get stickerLink => '連結';

  @override
  String get stickerUnfavorite => '取消收藏';

  @override
  String get stickerFavorite => '收藏';

  @override
  String get stickerAiBadge => 'AI';

  @override
  String get humanTitle => '擬人化';

  @override
  String get humanSubtitle => '正在輸入、主動發信、表情、記憶';

  @override
  String get humanFooter => '截斷標籤、主動發信、表情、撤回、心情與記憶。關閉後就能回到樸素的助理模式。';

  @override
  String get humanEnabled => '擬人化模式';

  @override
  String get humanBehaviour => '行為';

  @override
  String get humanBehaviourRow => '正在輸入、隨機與撤回';

  @override
  String get humanProactive => '主動發信';

  @override
  String get humanStickersRow => '表情';

  @override
  String get humanMemoryRow => '長期記憶';

  @override
  String get humanChatsRow => '對話：心情、角色卡、日程';

  @override
  String get humanToolsHeader => '工具';

  @override
  String get humanToolsRow => '工具、MCP 伺服器與權限';

  @override
  String get humanWalletRow => '錢包';

  @override
  String get humanDataHeader => '反饋與資料';

  @override
  String get humanRatingsRow => '評分與調校';

  @override
  String get humanBackupRow => '備份與匯入';

  @override
  String get humanSchedDebugRow => '排程器除錯面板';

  @override
  String get humanBehaviourTitle => '正在輸入與隨機性';

  @override
  String get humanBrHeader => '截斷標籤 <i-br>';

  @override
  String get humanBrFooter => '模型會在氣泡之間寫入 <i-br_500>，停頓自上一則氣泡顯示的那一刻開始計算。';

  @override
  String get humanBrToggle => '用 <i-br> 拆分訊息';

  @override
  String get humanBrPause => '預設停頓';

  @override
  String get humanReplyDelay => '首則訊息前的讀訊息時間';

  @override
  String get humanPaceScale => '訊息間停頓倍率';

  @override
  String get humanRandomHeader => '隨機性';

  @override
  String get humanRandomFooter => '固定種子會讓同一段對話的同一輪重現相同結果，除錯時很方便；留空則每次都重新擲點。';

  @override
  String get humanTypingSpread => '正在輸入速度的浮動範圍';

  @override
  String get humanTypoChance => '錯字機率';

  @override
  String get humanParticleChance => '語氣詞出現機率';

  @override
  String get humanSplitChance => '拆成多則氣泡';

  @override
  String get humanPunctStyle => '標點風格';

  @override
  String get humanPunctNormal => '標準';

  @override
  String get humanPunctLoose => '隨意';

  @override
  String get humanPunctMinimal => '極簡';

  @override
  String get humanSeedHint => '隨機種子（數字，留空即隨機）';

  @override
  String get humanRecallHeader => '撤回';

  @override
  String get humanRecallFooter => '只有已經顯示過的氣泡才能撤回。';

  @override
  String get humanRecallToggle => '允許撤回訊息';

  @override
  String get humanRecallPerHour => '每小時撤回次數';

  @override
  String get humanRecallWindow => '撤回時限';

  @override
  String get humanStickerFreq => '傳送表情的頻率';

  @override
  String get humanAiSaveSticker => '允許 AI 儲存表情';

  @override
  String get humanStickerOnly => '允許只發表情的回覆';

  @override
  String get humanStickerHeader => '表情';

  @override
  String get proactiveFooter => '助手以 schedule_message 決定何時主動開口，以下是圍繞它的限制。';

  @override
  String get proactiveToggle => '允許主動發信';

  @override
  String get proactiveLimits => '限制';

  @override
  String get proactiveMaxConsecutive => '最多連續幾則未回覆';

  @override
  String get proactiveDnd => '勿擾';

  @override
  String get proactiveQuiet => '勿擾時段';

  @override
  String get proactiveQuietFrom => '勿擾開始';

  @override
  String get proactiveQuietUntil => '勿擾結束';

  @override
  String get proactiveUrgent => '緊急內容可略過勿擾時段';

  @override
  String get proactiveTriggers => '自動觸發';

  @override
  String get proactiveTriggersFooter => '這些只是喚醒助手，用字由它自己決定。陌生人階段不傳送問候。';

  @override
  String get proactiveGreetMorning => '早安問候';

  @override
  String get proactiveMorningAt => '早安時間';

  @override
  String get proactiveGreetEvening => '晚安問候';

  @override
  String get proactiveEveningAt => '晚安時間';

  @override
  String get proactiveIcebreak => '冷場多久後破冰';

  @override
  String proactiveIcebreakUnit(int days) {
    return '$days 天';
  }

  @override
  String get proactiveServer => '伺服器兜底';

  @override
  String get proactiveServerFooter =>
      '選填。工作佇列會同步到這個後端（POST /api/schedule/sync, GET /api/schedule/due），這樣即使應用被關閉，工作也不會遺失。本機鬧鐘與每 15 分鐘的背景工作一律會執行。';

  @override
  String get proactiveServerUrl => '伺服器網址';

  @override
  String get humanNotSet => '未設定';

  @override
  String get proactiveDebugPanel => '偵錯面板';

  @override
  String get schedTitle => '排程器偵錯';

  @override
  String schedPending(int count) {
    return '待執行（$count）';
  }

  @override
  String get schedPendingFooter => '點傳送圖示會立刻執行工作，忽略時間與觸發條件；點垃圾桶圖示則取消工作。';

  @override
  String get schedEmpty => '佇列中沒有工作';

  @override
  String get schedFinished => '最近已完成';

  @override
  String get schedTestTask => '1 分鐘後排入一個測試工作';

  @override
  String get schedGate => '觸發判定';

  @override
  String get schedToolCalls => '工具呼叫';

  @override
  String get schedEmptyLog => '（空）';

  @override
  String get schedDue => '到期';

  @override
  String get schedCondition => '條件';

  @override
  String get schedFailures => '失敗';

  @override
  String get schedUrgent => '緊急';

  @override
  String schedRemaining(int minutes, int seconds) {
    return '$minutes 分 $seconds 秒';
  }

  @override
  String get humanRatingsTitle => '評分';

  @override
  String get humanRatingsFooter =>
      '你的評分會用來調整助理：煩躁會降低它主動發信的頻率，擬真程度與滿意度則會微調風格。開啟自動評分後，助理也會從你的行為中推測這些分數。';

  @override
  String get humanRatingHuman => '有多像真人';

  @override
  String get humanRatingAnnoy => '它有多打擾你';

  @override
  String get humanRatingSatisfaction => '整體滿意度';

  @override
  String get humanRatingAuto => '自動推測評分';

  @override
  String get humanRatingTuning => '主動發信頻率倍率';

  @override
  String get humanBackupTitle => '備份與匯入';

  @override
  String get humanSavedCopied => '已儲存並複製';

  @override
  String get humanCopiedClipboard => '已複製到剪貼簿';

  @override
  String get humanImportTitle => '匯入';

  @override
  String get humanImportFooter => '合併會保留現有內容並補上新的項目，覆蓋則整份取代。';

  @override
  String get humanOverwrite => '覆蓋';

  @override
  String get humanMerge => '合併';

  @override
  String humanImported(int count) {
    return '已匯入 $count 筆';
  }

  @override
  String get humanInvalidFile => '檔案無效';

  @override
  String get humanExport => '匯出';

  @override
  String get humanImportFile => '從檔案匯入';

  @override
  String get humanImportClipboard => '從剪貼簿匯入';

  @override
  String get humanStickersGroup => '表情與標籤';

  @override
  String get humanMemoryGroup => '記憶';

  @override
  String get humanCardsGroup => '角色卡（SillyTavern chara_card_v2）';

  @override
  String get humanCardsFooter => '選擇一段對話來匯出或匯入它的角色卡。';

  @override
  String get humanChatsTitle => '對話';

  @override
  String get humanChatState => '狀態';

  @override
  String get humanChatStage => '關係階段';

  @override
  String get humanChatMessages => '則訊息';

  @override
  String get humanChatMinutes => '分鐘相伴';

  @override
  String get humanChatStatus => '狀態';

  @override
  String get humanChatClearTasks => '清除待執行的主動發信任務';

  @override
  String get humanChatCardHeader => '角色卡';

  @override
  String get humanChatCardFooter => '每次回覆前都會注入，讓語氣保持一致，助理可能會慢慢微調。';

  @override
  String get humanChatSpeechStyle => '說話風格';

  @override
  String get humanChatCatchphrases => '口頭禪';

  @override
  String get humanChatCatchphrasesHint => '口頭禪（以逗號分隔）';

  @override
  String get humanChatValues => '價值觀';

  @override
  String get humanChatTaboos => '禁忌';

  @override
  String get humanChatAddressStranger => '稱呼：陌生人';

  @override
  String get humanChatAddressAcquaintance => '稱呼：熟人';

  @override
  String get humanChatAddressClose => '稱呼：親近的人';

  @override
  String get humanChatExportCard => '匯出角色卡（chara_card_v2）';

  @override
  String get humanChatCardCopied => '角色卡已複製到剪貼簿';

  @override
  String get humanChatImportCard => '從剪貼簿匯入角色卡';

  @override
  String get humanChatImportCardTitle => '匯入角色卡';

  @override
  String get humanChatImportCardFooter => '覆蓋會取代整張角色卡，合併只填補空白欄位。';

  @override
  String get humanChatInvalidCard => '角色卡無效';

  @override
  String get humanChatSchedule => '每日行程';

  @override
  String get humanChatScheduleFooter =>
      '行程進行中時，狀態會改變，精力停止恢復，主動發信也會暫停；結束後助理可能會說自己回來了。';

  @override
  String get humanChatScheduleNow => '現在';

  @override
  String get humanChatScheduleAdd => '新增項目（60 分鐘）';

  @override
  String get humanChatScheduleWhat => '在做什麼？';

  @override
  String get humanChatScheduleExample => '例如：在開會';

  @override
  String get humanChatFeelings => '數值變動的原因';

  @override
  String get humanChatFeelingsMood => '心情';

  @override
  String get humanChatFeelingsAffection => '好感';

  @override
  String get humanChatFeelingsEnergy => '精力';

  @override
  String get memoryTitle => '記憶';

  @override
  String get memoryNew => '新增記憶';

  @override
  String get memoryNewWhat => '想讓 AI 記住什麼？';

  @override
  String get memoryNewType => '類型';

  @override
  String get memoryFooter =>
      '權重會隨上次使用後經過的時間逐漸衰減。低於門檻的項目會被遺忘，不再注入。承諾與待辦在完成前不會衰減。';

  @override
  String get memoryEmpty => '尚無記憶';

  @override
  String get memoryForgotten => '已遺忘';

  @override
  String get memoryDue => '即將到期';

  @override
  String get memoryNotNeeded => '不再需要';

  @override
  String get memoryRestore => '恢復';

  @override
  String get memoryClose => '關閉';

  @override
  String get toolPermTitle => '允許使用這個工具嗎？';

  @override
  String get toolPermDeny => '拒絕';

  @override
  String get toolPermAllow => '允許';

  @override
  String get toolPermAsk => '詢問';

  @override
  String get toolsTitle => '工具與 MCP';

  @override
  String get toolAddServer => '新增 MCP 伺服器';

  @override
  String get toolHeadersJson => '標頭（JSON，選填）';

  @override
  String get toolUrlHint => 'https://host/mcp';

  @override
  String get toolServersHeader => 'MCP 伺服器（Streamable HTTP）';

  @override
  String get toolServersFooter =>
      '點按權限可在「允許 → 詢問 → 拒絕」之間循環。選擇「詢問」時每次呼叫前都會跳出確認，選擇「拒絕」則直接拒絕並告訴助理原因。MCP 工具預設為「詢問」。';

  @override
  String get toolConnecting => '連線中…';

  @override
  String get toolRefresh => '重新整理工具清單';

  @override
  String get toolMcpHeader => 'MCP 工具';

  @override
  String get toolBuiltinHeader => '內建工具';

  @override
  String toolCountSuffix(int count) {
    return '$count 個工具';
  }

  @override
  String get aiEditorTitle => 'AI 編輯器';

  @override
  String get aiEditorNoKey => '請先在「設定」裡新增 API 金鑰。';

  @override
  String get aiEditorApply => '套用';

  @override
  String get provTitle => '服務商';

  @override
  String get provMissing => '該服務商已不存在。';

  @override
  String get provSearchHint => '搜尋模型';

  @override
  String get provConnection => '連線';

  @override
  String get provName => '名稱';

  @override
  String get provProtocol => '協定';

  @override
  String get provApiKey => 'API 金鑰';

  @override
  String get provBaseUrl => '基礎 URL';

  @override
  String get provBaseUrlEmpty => '空白，此服務商無法使用';

  @override
  String get provChatPath => '對話路徑';

  @override
  String get provChatPathFixed => '由協定決定';

  @override
  String get provModels => '模型';

  @override
  String get provFetchModels => '取得模型';

  @override
  String get provFetchBusy => '處理中...';

  @override
  String provFetchDone(int count, String source) {
    return '來自$source的 $count 個模型';
  }

  @override
  String get provFetchNever => '需要時再向服務商拉取實際清單';

  @override
  String get provSourceApi => 'API';

  @override
  String get provSourceCatalog => '內建表';

  @override
  String get provTest => '測試連線';

  @override
  String provTestFailed(String reason) {
    return '失敗：$reason';
  }

  @override
  String provTestOk(String reply) {
    return '正常：$reply';
  }

  @override
  String get provTestNever => '發送一次最小請求';

  @override
  String get provAddManual => '手動新增模型';

  @override
  String get provAddManualSub => '用於清單介面無法使用時';

  @override
  String provCountModels(int count) {
    return '$count 個模型';
  }

  @override
  String get provOnChain => '在兜底鏈中';

  @override
  String get provDelete => '刪除此服務商';

  @override
  String get provFootnote => '能力資訊取自服務商 API 與內建表。標記為未知視窗的模型在長對話中會略過壓縮檢查。';

  @override
  String get provPasteKey => '貼上你的 API 金鑰';

  @override
  String get provModelIdHint => '模型 ID';

  @override
  String get provProtocolSub => '適用於多數轉接與自建伺服器';

  @override
  String provFetchedBulletin(int count) {
    return '已取得 $count 個模型';
  }

  @override
  String get provUsingCatalog => '正在使用內建模型表';

  @override
  String get provFetchFailed => '無法取得模型';

  @override
  String get provAdded => '已新增';

  @override
  String get provNoKeyFirst => '請先新增 API 金鑰';

  @override
  String get provConnectionWorks => '連線正常';

  @override
  String provDeleteTitle(String name) {
    return '刪除$name？';
  }

  @override
  String get provDeleteMessage => '它的 API 金鑰與鏈上的節點也會一併刪除，對話記錄不受影響。';

  @override
  String get provDeleted => '已刪除';

  @override
  String get provSaved => '已儲存';

  @override
  String provWindow(String tokens) {
    return '視窗 $tokens';
  }

  @override
  String provOut(String tokens) {
    return '輸出 $tokens';
  }

  @override
  String get provTagImage => '影像輸出';

  @override
  String get provTagUnknownWindow => '未知視窗';

  @override
  String provChainNodeMeta(int retries) {
    return '$retries 次重試 · 關閉';
  }

  @override
  String provChainNodeMetaOn(int retries) {
    return '$retries 次重試';
  }

  @override
  String get attachCaptionHint => '新增說明…';

  @override
  String get attachCameraUnavailable => '相機無法使用';

  @override
  String get attachPickerFailed => '無法開啟檔案選擇器';

  @override
  String get attachUploadFiles => '上傳檔案';

  @override
  String get attachUploadFilesSub => '文件、壓縮檔以及其他內容';

  @override
  String get attachPhotoPermission => '允許存取你的照片';

  @override
  String get attachOpenSettings => '開啟設定';

  @override
  String get attachBrowseAudio => '瀏覽音訊';

  @override
  String get attachBrowseFiles => '瀏覽檔案';

  @override
  String get attachPickSongs => '選擇歌曲和語音錄音';

  @override
  String get attachPickDocs => '從裝置中選擇文件';

  @override
  String get attachLocating => '定位中…';

  @override
  String get attachLocationOff => '定位服務已關閉';

  @override
  String get attachLocationDenied => '定位權限遭拒';

  @override
  String get attachSendLocation => '傳送我目前的位置';

  @override
  String get attachLocationUnavailable => '無法取得位置';

  @override
  String attachLocationAccuracy(int meters) {
    return '精確度 $meters 公尺';
  }

  @override
  String get attachLocationWaiting => '正在等待 GPS';

  @override
  String get attachContactsPermission => '請在系統設定中\n允許存取通訊錄';

  @override
  String get attachSearchContacts => '搜尋通訊錄';

  @override
  String get attachNoContacts => '通訊錄為空';

  @override
  String get attachPollQuestionLabel => '問題';

  @override
  String get attachPollOptionsLabel => '選項';

  @override
  String get attachPollSettingsLabel => '設定';

  @override
  String get attachPollQuestion => '提出一個問題';

  @override
  String attachPollOption(int index) {
    return '選項 $index';
  }

  @override
  String get attachPollAddOption => '新增選項';

  @override
  String get attachPollAnonymous => '匿名投票';

  @override
  String get attachPollMultiple => '多選';

  @override
  String get attachPollQuiz => '問答模式';

  @override
  String get attachPollQuizHint => '點選正確答案旁邊的圓圈。';

  @override
  String get attachPollFooter => '投票會顯示在聊天中，並以文字形式傳送給 AI。';

  @override
  String get attachPollCreate => '建立投票';

  @override
  String get attachTabGallery => '相簿';

  @override
  String get attachCamera => '相機';

  @override
  String get attachLoading => '正在載入…';

  @override
  String attachSelected(int count) {
    return '已選 $count 項';
  }

  @override
  String cardDepthMessages(int depth) {
    return '往上 $depth 則訊息';
  }

  @override
  String get cardFallbackSub => '其他選項都不適用時使用';

  @override
  String get cardSetFallback => '設為兜底卡片';

  @override
  String get cardLockToChat => '把這張卡片鎖定到目前聊天';

  @override
  String get cardNoChat => '請先建立聊天';

  @override
  String get cardNoChatSub => '開啟一個聊天，透過頂部選單鎖定卡片';

  @override
  String get cardLinkPersona => '連結到指定的 AI 人設';

  @override
  String get cardLinkCharacter => '連結到某個角色';

  @override
  String get cardPositionLabel => '位置';

  @override
  String get cardDepthLabel => '深度';

  @override
  String get cardRoleLabel => '角色';

  @override
  String get cardConnectionsHeader => '關聯';

  @override
  String get cardDefaultLabel => '預設';

  @override
  String get cardChatLabel => '對話';

  @override
  String get cardCharacterLabel => '角色';

  @override
  String get cardSave => '儲存卡片';

  @override
  String get cardCurrentLabel => '目前卡片';

  @override
  String get cardPickTitle => '選擇人設卡片';

  @override
  String get cardSetPhoto => '設定頭像';

  @override
  String get cardRemovePhoto => '頭像已移除';

  @override
  String get msgRecalledAnonymous => '有一則訊息被收回';

  @override
  String get wsTitle => '工作區';

  @override
  String get wsSub => '給 AI 一個自己的目錄';

  @override
  String get wsSubOff => '開啟檔案工具後 AI 才能讀寫這裡';

  @override
  String get wsToolsOff => '檔案工具已關';

  @override
  String get wsNoWorkspace => '未綁定工作區';

  @override
  String get wsToolsOn => '檔案工具';

  @override
  String get wsToolsFooter => '開啟後，已綁定工作區的對話會獲得六個檔案工具。每次寫入都會先把改動給你看。';

  @override
  String get wsConfirmWrites => '每次寫入都確認';

  @override
  String get wsConfirmWritesFooter => '關閉後 AI 會直接寫入，不再逐次詢問。改動仍會顯示在步驟列裡。';

  @override
  String get wsNew => '新增工作區';

  @override
  String get wsNewTitle => '名稱';

  @override
  String get wsCreate => '建立';

  @override
  String get wsRename => '重新命名';

  @override
  String get wsDelete => '刪除';

  @override
  String wsDeleteConfirm(String name) {
    return '刪除「$name」？';
  }

  @override
  String get wsDeleteFiles => '同時刪除其中的檔案';

  @override
  String get wsDeleteFilesFooter => '關閉則保留裝置上的檔案。你自己挑選的資料夾無論如何都不會被刪除。';

  @override
  String wsBoundTo(int count) {
    return '$count 個對話使用';
  }

  @override
  String get wsNeverUsed => '尚未使用';

  @override
  String get wsFiles => '檔案';

  @override
  String get wsToolsTab => '工具';

  @override
  String get wsToolShell => 'Shell';

  @override
  String get wsToolViewImage => '檢視圖片';

  @override
  String get wsToolsTabFooter => '在這裡關閉的工具不會提供給 AI。重新開啟也不會覆蓋你在工具頁設定的權限。';

  @override
  String get wsBind => '綁定工作區';

  @override
  String get wsBindTitle => '選擇工作區';

  @override
  String get wsBindNone => '不綁定';

  @override
  String get wsUnbind => '解除綁定';

  @override
  String get wsUnbindConfirm => 'AI 已經在本對話用過這個工作區，仍要解除綁定嗎？';

  @override
  String get wsChange => '更換';

  @override
  String get wsCwd => '工作目錄';

  @override
  String get wsCwdEmpty => '工作區根目錄';

  @override
  String get wsCwdInvalid => '該路徑不在工作區內';

  @override
  String get wsReveal => '檢視檔案';

  @override
  String get wsEmpty => '這裡還是空的';

  @override
  String get wsEmptyHint => '讓 AI 寫一個檔案，它就會出現在這個清單裡。';

  @override
  String get wsShowHidden => '顯示隱藏檔案';

  @override
  String get wsSort => '排序';

  @override
  String get wsSortName => '名稱';

  @override
  String get wsSortModified => '修改時間';

  @override
  String get wsSortSize => '大小';

  @override
  String get wsFoldersFirst => '資料夾在前';

  @override
  String get wsNewFolder => '新增資料夾';

  @override
  String get wsNewFile => '新增檔案';

  @override
  String get wsImport => '匯入';

  @override
  String get wsExport => '匯出';

  @override
  String get wsExportZip => '打包為 zip';

  @override
  String get wsMove => '移動';

  @override
  String get wsMoveHere => '移動到這裡';

  @override
  String get wsCopyPath => '複製路徑';

  @override
  String get wsCopiedPath => '路徑已複製';

  @override
  String get wsOpenWith => '用其他應用程式開啟';

  @override
  String get wsShare => '分享';

  @override
  String get wsEmptyDir => '這個資料夾是空的';

  @override
  String wsTruncated(int count) {
    return '清單在 $count 項處截斷';
  }

  @override
  String get wsPreview => '預覽';

  @override
  String get wsPreviewMissing => '檔案已不存在';

  @override
  String get wsPreviewTooBig => '檔案太大，無法預覽';

  @override
  String get wsPreviewBinary => '這不是文字檔';

  @override
  String get wsPreviewEmpty => '空檔案';

  @override
  String get wsWrap => '自動換行';

  @override
  String get wsZoomIn => '放大';

  @override
  String get wsZoomOut => '縮小';

  @override
  String get wsRendered => '渲染';

  @override
  String get wsSource => '原始碼';

  @override
  String get wsWriteTitle => '允許這次改動嗎';

  @override
  String get wsWriteNew => '新增檔案';

  @override
  String get wsWriteReplace => '替換整個檔案';

  @override
  String wsWriteEdit(int count) {
    return '替換 $count 行';
  }

  @override
  String wsWriteCounts(int added, int removed) {
    return '+$added −$removed';
  }

  @override
  String get wsWriteLoose => '寬鬆匹配';

  @override
  String get wsWriteAllow => '允許';

  @override
  String get wsWriteAllowAll => '本對話全部允許';

  @override
  String get wsWriteRefuse => '拒絕';

  @override
  String get wsWriteRefused => '你拒絕了這次改動';

  @override
  String get wsWriteNoUi => '本次未經確認';

  @override
  String get wsToolRead => '讀取';

  @override
  String get wsToolWrite => '寫入';

  @override
  String get wsToolEdit => '編輯';

  @override
  String get wsToolList => '列出';

  @override
  String get wsToolGlob => '尋找';

  @override
  String get wsToolGrep => '搜尋';

  @override
  String get wsToolDenied => '已拒絕';

  @override
  String wsLines(int count) {
    return '$count 行';
  }

  @override
  String wsFilesCount(int count) {
    return '$count 個檔案';
  }

  @override
  String wsBytesCount(String size) {
    return '$size';
  }

  @override
  String get wsOpenFile => '開啟';

  @override
  String get wsNameEmpty => '給它取個名字';

  @override
  String get wsNameSlash => '名稱不能包含斜線';

  @override
  String get wsNameDot => '這個名稱不可用';

  @override
  String get wsNameLeadingDot => '以點開頭的名稱會被隱藏';

  @override
  String wsPreviewTruncatedLines(Object count) {
    return '僅顯示前 $count 行';
  }

  @override
  String get wsDeleteFolderTitle => '刪除資料夾？';

  @override
  String get wsDeleteFileTitle => '刪除檔案？';

  @override
  String get wsOpenTerminal => '終端機';

  @override
  String get wsWriteNoPreview => '無法顯示原內容';

  @override
  String get wsWriteNoChange => '沒有改動';

  @override
  String get toolDescGetTime => '讀取目前日期、時間、時區，以及雙方最後一次說話的時間';

  @override
  String get toolDescSchedule => '讓它之後主動給你發訊息';

  @override
  String get toolDescCancelScheduled => '取消一則還沒發出的定時訊息';

  @override
  String get toolDescModifyScheduled => '修改定時訊息的時間或內容';

  @override
  String get toolDescListScheduled => '檢視它已經安排好的全部訊息';

  @override
  String get toolDescSetStatus => '設定你在對話列表看到的狀態';

  @override
  String get toolDescAdjustFeeling => '在好壞時刻之後調整它的心情或好感';

  @override
  String get toolDescWriteMemory => '記下一件值得記住的事';

  @override
  String get toolDescReadMemory => '搜尋它已經記住的東西';

  @override
  String get toolDescCompleteTodo => '把它寫下的承諾或待辦標記完成';

  @override
  String get toolDescLifeSchedule => '聲明它正在忙，於是那段時間話少';

  @override
  String get toolDescPinMessage => '在對話裡置頂或取消置頂一則訊息';

  @override
  String get toolDescEditMessage => '改寫它自己先前發過的一則訊息';

  @override
  String get toolDescQuoteMessage => '引用某則訊息來回覆';

  @override
  String get toolDescCharacterCard => '讓它緩慢微調自己的人設';

  @override
  String get toolDescRating => '根據你的回應調整它的自我調校';

  @override
  String get toolDescSendSticker => '從表情庫發一張貼紙';

  @override
  String get toolDescSaveSticker => '把你發過的梗圖存進表情庫';

  @override
  String get toolDescRecall => '像人一樣撤回剛發出的訊息';

  @override
  String get toolDescTypo => '發一則故意打錯的字，然後修正';

  @override
  String get toolDescSendImage => '從連結傳送一張圖片';

  @override
  String get toolDescSendFile => '寫一個文字檔並傳給你';

  @override
  String get toolDescSendTransfer => '發一個假的紅包，點一下就收';

  @override
  String get wsToolDescRead => '按行號讀取工作區裡的檔案';

  @override
  String get wsToolDescWrite => '新增或覆寫檔案，寫入前你會看到差異';

  @override
  String get wsToolDescEdit => '替換檔案中的某一段文字';

  @override
  String get wsToolDescList => '列出某個目錄下的檔案';

  @override
  String get wsToolDescGlob => '依檔名查找，例如所有 .dart 檔案';

  @override
  String get wsToolDescGrep => '用正規表示式搜尋檔案內容';

  @override
  String get toolNoUrl => '（未填寫位址）';

  @override
  String get toolBuiltinFooter => '開啟檔案工具並為對話綁定工作區後，會出現六個檔案工具。';

  @override
  String get wsSubOn => '每個已綁定工作區的對話獲得六個檔案工具';

  @override
  String get wsToolDescShell => '在 Linux 環境裡執行 shell 命令';

  @override
  String get wsToolDescViewImage => '讓 AI 檢視一張圖片';

  @override
  String get actionClose => '關閉';

  @override
  String get termTitle => '終端機';

  @override
  String get termNoEnvironment => '尚未安裝 Linux 環境';

  @override
  String get termOpenSettings => '開啟環境設定';

  @override
  String get termNewShell => '新增 shell';

  @override
  String get termRename => '重新命名 shell';

  @override
  String get termCopyAll => '複製全部內容';

  @override
  String get termClear => '清除螢幕';

  @override
  String get termFontBigger => '放大文字';

  @override
  String get termFontSmaller => '縮小文字';

  @override
  String get termCopied => '已複製';

  @override
  String get termSessionDead => '該 shell 已關閉';

  @override
  String get termLinkUnsupported => '無法從這裡開啟此連結';

  @override
  String get termHint => '在下方輸入命令。長按標籤可重新命名。';

  @override
  String get termSettings => '環境';

  @override
  String get termInstallEnvironment => '安裝 Linux 環境後即可使用終端機';

  @override
  String get termShellPath => 'Shell 路徑';

  @override
  String get termProotArgs => 'PRoot 選項';

  @override
  String get actionPaste => '貼上';

  @override
  String get termCloseConfirm => '關閉這個 shell？正在執行的程式會停止。';

  @override
  String get termOpenFailedShort => '無法開啟 shell';

  @override
  String get envTitle => 'Linux 環境';

  @override
  String get envNotInstalled => '尚未安裝環境';

  @override
  String get envReady => '已就緒';

  @override
  String get envInstall => '安裝';

  @override
  String get envCancel => '取消';

  @override
  String get envRemove => '移除環境';

  @override
  String get envUpdate => '有可用更新';

  @override
  String get envDownloading => '正在下載';

  @override
  String get envVerifying => '正在驗證壓縮檔';

  @override
  String get envExtracting => '正在解壓';

  @override
  String get envPatching => '正在設定';

  @override
  String get envChoose => '選擇發行版';

  @override
  String get envArch => '架構';

  @override
  String get envInstallConfirm => '安裝這個 Linux 環境？';

  @override
  String get envRemoveConfirm => '移除已安裝的 Linux 環境和下載的壓縮檔？';

  @override
  String envMinFree(int mb) {
    return '需要 $mb MB 可用空間';
  }

  @override
  String get actionTypeDeleteHint => '輸入 delete 以確認刪除';

  @override
  String get envUnknownError => '環境操作失敗';

  @override
  String get envChecking => '正在檢查裝置支援';

  @override
  String get envUnsupported => '沒有適用於此裝置的發行版';

  @override
  String envUnsupportedDevice(Object abi) {
    return '沒有適用於 ABI $abi 的根檔案系統';
  }

  @override
  String get envErrorArchitecture => '環境架構與此應用程式不相符';

  @override
  String get envErrorProot => '此版本未包含 PRoot';

  @override
  String get envErrorDisk => '可用儲存空間不足';

  @override
  String get envErrorNetwork => '下載失敗，請檢查網路後重試';

  @override
  String get envErrorChecksum => '下載檔案未通過 SHA-256 驗證';

  @override
  String get envErrorExtract => '無法解壓檔案';

  @override
  String get envErrorPatch => '無法設定環境';

  @override
  String get envErrorCancelled => '操作已取消';

  @override
  String get envErrorInvalid => '已安裝的環境不完整';
}

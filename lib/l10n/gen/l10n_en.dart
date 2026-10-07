// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Paradise';

  @override
  String get actionOk => 'OK';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionDone => 'Done';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get accountTitle => 'Edit Profile';

  @override
  String get accountNameHeader => 'Your name';

  @override
  String get accountNameFooter =>
      'Enter your name and add an optional profile photo. Personas in the list below keep their own names.';

  @override
  String get accountNameHint => 'Name';

  @override
  String get accountBioHeader => 'Your bio';

  @override
  String get accountBioFooter =>
      'You can add a few lines about yourself. Characters may read it to get to know you.';

  @override
  String get accountBioHint => 'Bio';

  @override
  String get accountPhotoFooter =>
      'Hold the avatar above to remove the photo quickly.';

  @override
  String get accountSetNewPhoto => 'Set New Photo';

  @override
  String get accountSetPhoto => 'Set Profile Photo';

  @override
  String get accountRemovePhoto => 'Remove Photo';

  @override
  String get accountRemovePhotoTitle => 'Remove photo';

  @override
  String get accountRemovePhotoMessage =>
      'Are you sure you want to remove your profile photo?';

  @override
  String get accountPhotoRemoved => 'Photo removed';

  @override
  String get accountPhotoActionSet => 'Set Photo';

  @override
  String get accountPhotoActionChange => 'Change Photo';

  @override
  String get accountOnlineFallback => 'online';

  @override
  String get accountNameEmptyPreview => 'Your name';

  @override
  String get accountNameRequired => 'Name cannot be empty';

  @override
  String get accountDiscardTitle => 'Discard changes?';

  @override
  String get accountDiscardMessage =>
      'You have unsaved changes to your profile.';

  @override
  String get galleryUnavailable => 'Gallery is not available';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionSend => 'Send';

  @override
  String get actionRemoveShort => 'Remove';

  @override
  String get actionEnable => 'Enable';

  @override
  String get actionDisable => 'Disable';

  @override
  String get actionMoveUp => 'Move Up';

  @override
  String get actionMoveDown => 'Move Down';

  @override
  String get actionCurrent => 'Current';

  @override
  String get aiTabProviders => 'Providers';

  @override
  String get aiTabChain => 'Chain';

  @override
  String get aiTabAdvanced => 'Advanced';

  @override
  String get aiTitle => 'AI Configuration';

  @override
  String get aiReadyTitle => 'AI is ready';

  @override
  String get aiNotReadyTitle => 'AI is not set up';

  @override
  String get aiNotReadyMessage =>
      'Add an API key to a provider, then put one of its models on the chain.';

  @override
  String aiOnChainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0 on the chain';
  }

  @override
  String get aiProvidersHeader => 'Providers';

  @override
  String get aiProvidersFooter =>
      'Model capabilities come from the provider API and a built-in catalog. The context window decides when the history gets compacted.';

  @override
  String get aiAddProvider => 'Add Provider';

  @override
  String get aiAddProviderTitle => 'Add provider';

  @override
  String get aiAddProviderHint => 'Name, for example My Relay';

  @override
  String get aiKeySet => 'API key set';

  @override
  String get aiNoKey => 'No API key';

  @override
  String aiProviderOnChain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0 on the chain';
  }

  @override
  String aiProviderModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String get aiChainHeader => 'Fallback chain';

  @override
  String aiChainActiveCount(int active, int total) {
    return '$active of $total on';
  }

  @override
  String get aiChainEmpty => 'No chain configured';

  @override
  String get aiChainEmptyHint =>
      'The chain is empty. Add a model and requests will go to it first.';

  @override
  String get aiChainFooter =>
      'Requests walk the chain top to bottom. Tap a model to reorder it, change its retries or remove it. Auth and billing failures never retry, they move straight to the next model.';

  @override
  String get aiAddModel => 'Add Model';

  @override
  String get aiCompactionHeader => 'Context compaction';

  @override
  String get aiCompactionFooter =>
      'On a context overflow compaction is retried once, then the history is hard truncated.';

  @override
  String get aiCompactionToggle => 'Compact long conversations';

  @override
  String get aiCompactionToggleSub => 'Early turns become a summary';

  @override
  String get aiSummaryModel => 'Summary model';

  @override
  String get aiSummaryModelFollows => 'Follows the first model on the chain';

  @override
  String get aiSummaryLength => 'Summary length';

  @override
  String get aiAddToChainTitle => 'Add to chain';

  @override
  String get aiSummaryModelPickerTitle => 'Model used for summaries';

  @override
  String get aiSummaryLengthTitle => 'Summary length';

  @override
  String get aiLengthTight => 'Tight';

  @override
  String get aiLengthBalanced => 'Balanced';

  @override
  String get aiLengthDetailed => 'Detailed';

  @override
  String get aiChainMenuRetries => 'Retries';

  @override
  String get aiRetriesTitle => 'Retries before moving on';

  @override
  String get aiRetriesNone => 'No retries';

  @override
  String get aiRepliesHeader => 'Replies';

  @override
  String get aiRepliesFooter =>
      'Character mode splits a reply into several short messages, the way people text.';

  @override
  String get aiReplyStyle => 'Reply style';

  @override
  String get aiReplyStyleFull => 'Full';

  @override
  String get aiReplyStyleCharacter => 'Character';

  @override
  String get aiReplyStyleFullSub =>
      'Streams character by character and shows reasoning';

  @override
  String get aiReplyStyleCharacterSub =>
      'Sends several short messages like a real person';

  @override
  String get aiFirstBubbleDelay => 'Read time before replying';

  @override
  String get aiBubbleGapScale => 'Pause between messages, scale';

  @override
  String get aiPacingOff => 'Off';

  @override
  String get aiPacingDelayHint => 'The first bubble lands at once';

  @override
  String get aiPacingJitter => 'Timing randomness';

  @override
  String get aiPacingJitterLow => 'Subtle';

  @override
  String get aiPacingJitterNormal => 'Normal';

  @override
  String get aiPacingJitterWild => 'Wild';

  @override
  String get aiPacingJitterHintOff => 'Every pause is exactly as long as set';

  @override
  String get aiPacingJitterHintLow =>
      'Pauses drift a little around the set values';

  @override
  String get aiPacingJitterHintNormal => 'A human unevenness in every pause';

  @override
  String get aiPacingJitterHintWild =>
      'Unpredictable, sometimes instant sometimes slow';

  @override
  String get aiSamplingHeader => 'Sampling';

  @override
  String get aiSamplingFooter => 'No model details are ever shown in the chat.';

  @override
  String get aiTemperature => 'Temperature';

  @override
  String get aiTempDeterministic => 'Deterministic';

  @override
  String get aiTempFocused => 'Focused';

  @override
  String get aiTempBalanced => 'Balanced';

  @override
  String get aiTempLoose => 'Loose';

  @override
  String get aiMaxOutput => 'Max output';

  @override
  String get aiModelDefault => 'Model default';

  @override
  String get aiUseCatalogDefault => 'Use the catalog default';

  @override
  String get aiSummaryNoNodes => 'The chain has no nodes yet';

  @override
  String get aiSummaryNoKey => 'No API key configured';

  @override
  String get aiCapsReasoning => 'reasoning';

  @override
  String get aiCapsVision => 'vision';

  @override
  String get aiCapsVideo => 'video';

  @override
  String get aiTokensUnknown => 'unknown';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabSettings => 'Settings';

  @override
  String get tabProfile => 'Profile';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsSearchHint => 'Search';

  @override
  String get chatsEmptyTitle => 'No chats yet';

  @override
  String get chatsEmptySub => 'Create a persona to start a conversation.';

  @override
  String get chatsNewPersona => 'New Persona';

  @override
  String get chatsMenuReadAll => 'Read All';

  @override
  String get chatsRowTyping => 'typing';

  @override
  String get chatsRowDraft => 'Draft: ';

  @override
  String get chatsRowEmpty => 'No messages yet';

  @override
  String get chatsRowYou => 'You: ';

  @override
  String get menuPin => 'Pin';

  @override
  String get menuUnpin => 'Unpin';

  @override
  String get menuMute => 'Mute';

  @override
  String get menuUnmute => 'Unmute';

  @override
  String get menuMarkAsRead => 'Mark as Read';

  @override
  String get menuClearHistory => 'Clear History';

  @override
  String get menuDeleteChat => 'Delete Chat';

  @override
  String get dialogClearHistoryTitle => 'Clear history';

  @override
  String dialogClearHistoryMessage(String personaName) {
    return 'Delete all messages in $personaName?';
  }

  @override
  String get dialogDeleteChatTitle => 'Delete chat';

  @override
  String dialogDeleteChatMessage(String personaName) {
    return 'This removes $personaName and its history.';
  }

  @override
  String get chatEmptyPill => 'No messages here yet...';

  @override
  String get chatSearchHint => 'Search messages';

  @override
  String get chatSearchNoResults => 'No results';

  @override
  String chatSearchCount(int index, int total) {
    return '$index of $total';
  }

  @override
  String get chatSearchModeChat => 'Chat';

  @override
  String get chatSearchModeList => 'List';

  @override
  String get chatStatusTyping => 'typing';

  @override
  String get chatStatusBot => 'bot';

  @override
  String get chatMenuReply => 'Reply';

  @override
  String get chatMenuCopy => 'Copy';

  @override
  String get chatMenuRegenerate => 'Regenerate';

  @override
  String get chatMenuDelete => 'Delete';

  @override
  String get toastMessageCopied => 'Message copied';

  @override
  String get headerMenuSearch => 'Search';

  @override
  String get headerMenuViewProfile => 'View Profile';

  @override
  String get headerMenuEditPersona => 'Edit Persona';

  @override
  String get headerMenuMutedSub => 'Notifications are off';

  @override
  String get headerMenuLockPersona => 'Lock My Persona';

  @override
  String get headerMenuClearHistory => 'Clear History';

  @override
  String get headerMenuDeleteChat => 'Delete Chat';

  @override
  String get dialogClearHistoryHereTitle => 'Clear history';

  @override
  String get dialogClearHistoryHereMessage =>
      'Delete all messages in this chat?';

  @override
  String get dialogDeleteChatHereTitle => 'Delete chat';

  @override
  String get lockSheetTitle => 'Lock my persona';

  @override
  String get lockSheetSub => 'This chat always answers as the card you pick.';

  @override
  String get lockSheetUnnamed => 'Unnamed';

  @override
  String get lockSheetNone => 'No lock';

  @override
  String get lockSheetNoneSub => 'Use the card selected in My Account';

  @override
  String get lockSheetEmpty => 'No persona card yet. Make one in My Account.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'My Account';

  @override
  String get settingsAccountSub => 'Name and bio';

  @override
  String get settingsAi => 'AI';

  @override
  String get settingsAiSubNone => 'No model on the chain';

  @override
  String get settingsAppearance => 'Chat Appearance';

  @override
  String get settingsAppearanceSub => 'Night mode, text size, corners';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsVibrationOn => 'Vibration on';

  @override
  String get settingsVibrationOff => 'Vibration off';

  @override
  String get settingsData => 'Data and Storage';

  @override
  String settingsDataSub(int chats, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats chats',
      one: '1 chat',
    );
    return '$_temp0 · $size of media';
  }

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutLinkFailed => 'Could not open the link';

  @override
  String settingsAboutSub(String version) {
    return 'Version $version';
  }

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutCommunity => 'Community';

  @override
  String get aboutQqGroup => 'QQ group';

  @override
  String get aboutAcknowledgements => 'Acknowledgements';

  @override
  String get aboutThanksKelivo => 'ToolCall reference';

  @override
  String get aboutThanksSillyTavern => 'Persona card reference';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get aboutLicensesSub =>
      'These are the packages this app ships, each under its own licence. The full text sits in its repository.';

  @override
  String get aboutDepArchive => 'Zipping a workspace for export';

  @override
  String get aboutDepCharacters => 'Grapheme clusters for text measurement';

  @override
  String get aboutDepCrypto =>
      'Hashing in the workspace; nothing is hashed on device yet';

  @override
  String get aboutDepFilePicker => 'Picking documents and audio files';

  @override
  String get aboutDepFlutterContacts => 'Sharing a contact card';

  @override
  String get aboutDepFlutterHighlight => 'Colouring the code preview';

  @override
  String get aboutDepFlutterLocalNotifications => 'Local notifications';

  @override
  String get aboutDepFlutterMathFork => 'Rendering LaTeX inside a bubble';

  @override
  String get aboutDepFlutterSvg => 'Provider logos and vector icons';

  @override
  String get aboutDepGeolocator => 'Location attachments';

  @override
  String get aboutDepGlob => 'The workspace find tool';

  @override
  String get aboutDepHighlight => 'The grammar data behind the code preview';

  @override
  String get aboutDepHttp => 'OpenAI compatible endpoints';

  @override
  String get aboutDepImagePicker => 'Camera and gallery photos';

  @override
  String get aboutDepIntl => 'Date and number formatting';

  @override
  String get aboutDepPath => 'Path arithmetic in the workspace sandbox';

  @override
  String get aboutDepPathProvider => 'App directory for stickers and exports';

  @override
  String get aboutDepPermissionHandler =>
      'Asking for photos, contacts, location and notifications in one place';

  @override
  String get aboutDepPhotoManager => 'Album access for attachments';

  @override
  String get aboutDepRatex => 'The native LaTeX math card';

  @override
  String get aboutDepSharedPreferences => 'Settings and chat storage';

  @override
  String get aboutDepSqflite => 'Message history and per chat paging';

  @override
  String get aboutDepTerminalView =>
      'The VT100 parser and renderer behind the workspace terminal, a vendored fork';

  @override
  String get aboutDepTimezone => 'Timezone data for scheduled messages';

  @override
  String get aboutDepTypstFlutter =>
      'The embedded Typst compiler behind the CeTZ drawing card';

  @override
  String get aboutDepUrlLauncher => 'Opening the links on this page';

  @override
  String get aboutDepVideoPlayer => 'Video playback in chat bubbles';

  @override
  String get aboutDepWebview => 'Rendering html in a file preview';

  @override
  String get aboutDepWorkmanager =>
      'Background delivery when the app is killed';

  @override
  String get aboutContributors => 'Contributors';

  @override
  String aboutContributions(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n contributions',
      one: '1 contribution',
    );
    return '$_temp0';
  }

  @override
  String get aboutContributorsFailed =>
      'Couldn\'t load the list. Tap to retry.';

  @override
  String get settingsContributorsThanks => 'Thanks to all contributors';

  @override
  String get previewSampleIncoming => 'Good morning! How can I help today?';

  @override
  String get previewSampleOutgoing => 'Explain how transformers work';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get wallpaperHeader => 'Chat Wallpaper';

  @override
  String get wallpaperRow => 'Wallpaper';

  @override
  String get wallpaperDefault => 'Default';

  @override
  String get wallpaperChoose => 'Choose photo';

  @override
  String get wallpaperNone => 'Plain gradient';

  @override
  String get wallpaperFollowGlobal => 'Follow global';

  @override
  String get wallpaperBlur => 'Blur wallpaper';

  @override
  String get wallpaperBlurSub => 'Keeps the bubbles readable over a photo';

  @override
  String get wallpaperColorHeader => 'Accent from wallpaper';

  @override
  String get wallpaperColorFooter =>
      'Pick a colour to recolour the accent and your own bubbles.';

  @override
  String get wallpaperColorNone => 'Default';

  @override
  String get wallpaperNoColors => 'This photo has no colour to take';

  @override
  String get wallpaperBubbleGrad => 'Bubble gradient';

  @override
  String get wallpaperBubbleGradSubtle => 'Subtle';

  @override
  String get wallpaperBubbleGradMedium => 'Medium';

  @override
  String get wallpaperBubbleGradStrong => 'Strong';

  @override
  String get wallpaperBubbleGradSub =>
      'How far your own bubbles fade from top to bottom.';

  @override
  String get wallpaperRemoved => 'Wallpaper removed';

  @override
  String get wallpaperChatTitle => 'Wallpaper of this chat';

  @override
  String get appearanceNightMode => 'Night Mode';

  @override
  String get appearancePreview => 'Message Preview';

  @override
  String get appearanceTextSize => 'Message Text Size';

  @override
  String get appearanceSize => 'Size';

  @override
  String get appearanceCorners => 'Message Corners';

  @override
  String get appearanceRadius => 'Radius';

  @override
  String get appearanceReset => 'Reset to Default';

  @override
  String get notifAlerts => 'Alerts';

  @override
  String get notifVibrate => 'Vibrate on Reply';

  @override
  String get notifVibrateSub => 'A light tap when an answer arrives';

  @override
  String get notifCountMuted => 'Count Muted Chats';

  @override
  String get notifCountMutedSub => 'Include them in the tab badge';

  @override
  String get notifFooter =>
      'Each chat can also be muted from its menu or profile.';

  @override
  String get dataUsage => 'Usage';

  @override
  String get dataChats => 'Chats';

  @override
  String get dataMessages => 'Messages';

  @override
  String get dataMedia => 'Media and Files';

  @override
  String get dataClear => 'Clear';

  @override
  String get dataClearSearch => 'Clear Search History';

  @override
  String get dataClearMedia => 'Clear Media and Files';

  @override
  String get dataClearMediaTitle => 'Clear media';

  @override
  String get dataClearMediaMessage =>
      'Photos, files and music are removed from every chat.';

  @override
  String get dataClearAll => 'Clear All Chats';

  @override
  String get dataClearAllTitle => 'Clear all chats';

  @override
  String get dataClearAllMessage =>
      'This deletes every message in every chat. Personas stay.';

  @override
  String get dataBackup => 'Backup';

  @override
  String get dataBackupExportSub =>
      'Conversations, cards, stickers and settings';

  @override
  String get dataBackupImportSub => 'From a file you exported before';

  @override
  String dataBackupRestored(int chats, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats conversations',
      one: '1 conversation',
    );
    return '$_temp0 and $messages messages';
  }

  @override
  String get dataBackupNothing => 'There was nothing in that file to restore';

  @override
  String get dataBackupSaved => 'Backup saved';

  @override
  String get dataBackupSaveFailed => 'Could not save the file';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get emojiSearchHint => 'Type to search';

  @override
  String get emojiNothingFound => 'Nothing found';

  @override
  String get personaDiscardExisting =>
      'Your edits to this persona will be lost.';

  @override
  String get personaDiscardNew => 'This persona has not been created yet.';

  @override
  String get personaNameHeader => 'Name';

  @override
  String get personaNameHint => 'Persona name';

  @override
  String get personaAboutHeader => 'About';

  @override
  String get personaAboutFooter =>
      'A short line shown on the profile. It is not sent to the model.';

  @override
  String get personaInstructionsHeader => 'Instructions';

  @override
  String get personaInstructionsFooter =>
      'This becomes the system prompt of every request in this chat.';

  @override
  String get personaInstructionsHint => 'How should the AI behave?';

  @override
  String get personaGreetingHeader => 'Greeting';

  @override
  String get personaGreetingFooter =>
      'Optional. Sent as the first message when the chat opens.';

  @override
  String get personaGreetingHint => 'First message from the persona';

  @override
  String get personaSave => 'Save Changes';

  @override
  String get personaCreate => 'Create Persona';

  @override
  String get personaTemplatesHeader => 'Start from a template';

  @override
  String get personaAppearanceHeader => 'Appearance';

  @override
  String get personaAppearanceFooterPhoto =>
      'A photo replaces the emoji everywhere the avatar is shown.';

  @override
  String get personaAppearanceFooterColor =>
      'The colour is used for the avatar and the profile cover.';

  @override
  String get personaPhotoTitle => 'Photo';

  @override
  String get personaPhotoTitleEmpty => 'Profile photo';

  @override
  String get personaPhotoSubFull => 'Tap to change, hold to remove';

  @override
  String get personaPhotoSubEmpty =>
      'Add a photo, or leave it on the colour below';

  @override
  String get personaChoose => 'Choose';

  @override
  String get personaModelForThis => 'Model for this persona';

  @override
  String get personaModelGlobal => 'Global';

  @override
  String get personaModelGlobalSub => 'Follow whatever the chain is set to';

  @override
  String get personaModelFooterOverride =>
      'Off means a failure on this model ends the reply instead of trying the global chain.';

  @override
  String get personaModelFooterGlobal =>
      'Global follows the chain in Settings > AI. Pick a model to run this persona on its own.';

  @override
  String get personaModelGlobalChain => 'Global chain';

  @override
  String get personaModelOnlyThis => 'this persona only';

  @override
  String get personaModelFollowsSettings => 'Follows Settings > AI';

  @override
  String get personaModelChange => 'Change';

  @override
  String get personaModelFallback => 'Fall back to the global chain';

  @override
  String get personaModelUseGlobal => 'Use Global Chain';

  @override
  String get presetAssistantBio => 'A calm all round helper';

  @override
  String get presetCoderBio => 'Reads stack traces for fun';

  @override
  String get presetTranslatorBio => 'English and Chinese both ways';

  @override
  String get presetWriterBio => 'Tightens every sentence';

  @override
  String get presetTutorBio => 'Explains it like a friend';

  @override
  String get aiFollowChain => 'Follow the first node on the chain';

  @override
  String get aiFollowChainSub => 'Use the current main model for summaries';

  @override
  String get aiModelTabChat => 'Chat';

  @override
  String get aiModelTabImage => 'Image';

  @override
  String get aiModelTabAll => 'All';

  @override
  String get aiSearchModels => 'Search models';

  @override
  String get aiNoModelsLoaded =>
      'No models loaded yet.\nFetch a list from a provider first.';

  @override
  String aiNoModelMatches(String query) {
    return 'Nothing matches \"$query\"';
  }

  @override
  String get codeGeneric => 'code';

  @override
  String get toastCodeCopied => 'Code copied';

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchRecent => 'Recent';

  @override
  String get searchPeople => 'People';

  @override
  String get searchNoResultsTitle => 'No Results';

  @override
  String get searchEmptyBody => 'Nothing of this kind has been shared yet.';

  @override
  String searchNoResultsBody(String query) {
    return 'There were no results for \"$query\". Try a new search.';
  }

  @override
  String get profileButtonEdit => 'Edit';

  @override
  String get profileButtonShare => 'Share';

  @override
  String get profileButtonMessage => 'Message';

  @override
  String get profileButtonSearch => 'Search';

  @override
  String get profileCopied => 'Profile copied';

  @override
  String get profileLabelName => 'Name';

  @override
  String get profileLabelBio => 'Bio';

  @override
  String get profileLabelPersonaCard => 'Persona Card';

  @override
  String get profileLabelActivity => 'Activity';

  @override
  String get profileLabelAbout => 'About';

  @override
  String get profileLabelInstructions => 'Instructions';

  @override
  String get profileLabelModel => 'Model';

  @override
  String get profileLabelNotifications => 'Notifications';

  @override
  String get profileBioEmpty => 'Add a few words about yourself';

  @override
  String get profileCardEmpty => 'Tell the AI who you are';

  @override
  String profileActivity(int chats, int sent) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats chats',
      one: '1 chat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent sent',
      one: '1 sent',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get profileOn => 'On';

  @override
  String get profileOff => 'Off';

  @override
  String get profileHeaderTyping => 'typing...';

  @override
  String toastCopiedLabel(String label) {
    return '$label copied';
  }

  @override
  String get profileTabMedia => 'Media';

  @override
  String get profileTabFiles => 'Files';

  @override
  String get profileTabMusic => 'Music';

  @override
  String get profileTabLinks => 'Links';

  @override
  String get profileSharedEmptyMedia => 'No media yet';

  @override
  String get profileSharedEmptyFiles => 'No files yet';

  @override
  String get profileSharedEmptyMusic => 'No music yet';

  @override
  String get profileSharedEmptyLinks => 'No links yet';

  @override
  String get msgLeadPhoto => 'Photo';

  @override
  String get msgLeadMusic => 'Music';

  @override
  String get msgLeadVideo => 'Video';

  @override
  String get msgLeadContact => 'Contact';

  @override
  String get msgLeadPoll => 'Poll';

  @override
  String get msgLeadSticker => 'Sticker';

  @override
  String get attachAudioFallback => 'Audio';

  @override
  String get attachFileFallback => 'File';

  @override
  String get attachLocationTitle => 'Location';

  @override
  String get attachLocationCopied => 'Coordinates copied';

  @override
  String get attachNoPhone => 'No phone number';

  @override
  String get pollKindQuiz => 'Quiz';

  @override
  String get pollKindPublic => 'Public Poll';

  @override
  String get pollKindAnonymous => 'Anonymous Poll';

  @override
  String pollKindMultiple(String kind) {
    return '$kind · Multiple answers';
  }

  @override
  String get askKind => 'Question · tap to answer';

  @override
  String get askKindMulti => 'Question · pick any, then submit';

  @override
  String get askDone => 'Answered';

  @override
  String get askSkipped => 'Skipped';

  @override
  String get askOtherHint => 'Or write your own answer…';

  @override
  String get askSubmit => 'Submit';

  @override
  String get askSkip => 'Skip';

  @override
  String photoCounter(int index, int total) {
    return '$index of $total';
  }

  @override
  String get profileFileFallback => 'File';

  @override
  String get errorAuth => 'API key is invalid or has no access';

  @override
  String get errorQuota => 'Provider is out of credit';

  @override
  String get errorRate => 'Rate limited by the provider';

  @override
  String get errorContextOverflow => 'Context is longer than the model window';

  @override
  String get errorServer => 'Provider returned an error';

  @override
  String get errorNetwork => 'Network connection failed';

  @override
  String get errorAborted => 'Generation stopped';

  @override
  String get errorEmpty => 'The model returned nothing';

  @override
  String get errorUnknown => 'Request failed';

  @override
  String errorStoppedEarly(String reason) {
    return 'Stopped early: $reason';
  }

  @override
  String pluralChats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '1 chat',
    );
    return '$_temp0';
  }

  @override
  String pluralVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes yet',
    );
    return '$_temp0';
  }

  @override
  String pluralSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String pluralModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String pluralRetries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count retries',
      one: '1 retry',
    );
    return '$_temp0';
  }

  @override
  String pluralOptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
    );
    return '$_temp0';
  }

  @override
  String pluralChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chars',
    );
    return '$_temp0';
  }

  @override
  String pluralTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens',
    );
    return '$_temp0';
  }

  @override
  String get cardCreate => 'Create card';

  @override
  String get cardDeleteThisCard => 'this card';

  @override
  String get cardDeleteTitle => 'Delete card';

  @override
  String get cardDeleted => 'Card deleted';

  @override
  String get cardDescHint => 'Who you are, how you talk, what you like';

  @override
  String get cardDuplicate => 'Duplicate';

  @override
  String get cardDuplicated => 'Card duplicated';

  @override
  String get cardEditing => 'Edit card';

  @override
  String get cardEmptyBody =>
      'Create a persona card to tell the assistant who you are.';

  @override
  String get cardEmptyTitle => 'No persona cards';

  @override
  String get cardFieldDescription => 'Description';

  @override
  String get cardFieldName => 'Name';

  @override
  String get cardFieldNameHint => 'What the assistant calls you';

  @override
  String get cardFieldTitle => 'Title';

  @override
  String get cardFieldTitleHint => 'Shown in the list only';

  @override
  String get cardInfoFooter =>
      'The description is sent to the model with every request.';

  @override
  String get cardNew => 'New card';

  @override
  String get cardPlaceholdersHint =>
      'Use the user and char placeholder tokens.';

  @override
  String get cardPositionTitle => 'Position in the prompt';

  @override
  String get cardRoleTitle => 'Role of the injected message';

  @override
  String get posAtDepth => 'At depth';

  @override
  String get posAtDepthSub =>
      'Inserted a few messages back from the newest one';

  @override
  String get posBottomNote => 'Bottom note';

  @override
  String get posBottomNoteSub => 'The last thing read before the conversation';

  @override
  String get posInPrompt => 'In prompt';

  @override
  String get posInPromptSub => 'Merged into the system prompt';

  @override
  String get posNone => 'Off';

  @override
  String get posNoneSub => 'The card is not sent';

  @override
  String get posTopNote => 'Top note';

  @override
  String get posTopNoteSub => 'Ahead of everything else';

  @override
  String get roleAssistant => 'Assistant';

  @override
  String get roleSystem => 'System';

  @override
  String get roleUser => 'User';

  @override
  String cardDeleteMessage(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String msgRecalled(String name) {
    return '$name recalled a message';
  }

  @override
  String get msgEdited => 'edited';

  @override
  String get msgPinned => 'Pinned message';

  @override
  String get traceThinking => 'Thinking';

  @override
  String get traceThinkingNow => 'Thinking…';

  @override
  String traceThoughtFor(String seconds) {
    return 'Thought for $seconds';
  }

  @override
  String get traceRunning => 'Running';

  @override
  String get traceFailed => 'Failed';

  @override
  String get traceArguments => 'Arguments';

  @override
  String get traceResult => 'Result';

  @override
  String traceSeconds(String value) {
    return '${value}s';
  }

  @override
  String get statusOnline => 'online';

  @override
  String get statusAway => 'away';

  @override
  String get statusDnd => 'do not disturb';

  @override
  String get statusRead => 'read';

  @override
  String get searchGeneric => 'Search';

  @override
  String get inputMessageHint => 'Message';

  @override
  String get aiReplyTitle => 'AI replies';

  @override
  String get aiReplyStyleHeader => 'Pacing';

  @override
  String get aiReplyVisibleHeader => 'What you get to see';

  @override
  String get aiReplyVisibleFooter =>
      'Show thinking writes the reasoning of a thinking model into the chat, above the answer, as a step you can open. Agent mode lets the model call tools and adds a row per call with its arguments and its result.';

  @override
  String get aiReplyMarkdown => 'Markdown';

  @override
  String get aiReplyMarkdownSub =>
      'Render bold, code blocks and headings in bubbles; off strips them in character mode';

  @override
  String get aiReplyShowThinking => 'Show thinking';

  @override
  String get aiReplyShowThinkingSub =>
      'Write the reasoning into the chat instead of hiding it';

  @override
  String get aiReplyAgentMode => 'Agent mode';

  @override
  String get aiReplyAgentModeSub =>
      'Tools and MCP calls, each step shown as it runs';

  @override
  String get aiReplyAgentPass => 'Tool pass limit';

  @override
  String get aiReplyAgentPassSub =>
      'How many tool rounds one reply may run before it is stopped';

  @override
  String get aiReplyAgentPassUnlimited => 'Unlimited';

  @override
  String get aiReplyAgentPassUnlimitedSub =>
      'Run tool rounds until the model stops on its own';

  @override
  String aiReplyAgentPassRounds(int count) {
    return '$count rounds';
  }

  @override
  String get aiReplyToolsHeader => 'Tools';

  @override
  String get aiReplyToolsFooter =>
      'Agent mode hands the model three built in tools (the time, fetch a page, list MCP servers) plus everything your MCP servers offer. Every tool can be set to ask, allow or deny on the tools page.';

  @override
  String get aiReplyToolsRow => 'Tools, MCP servers and permissions';

  @override
  String aiReplyToolsCount(int count) {
    return '$count MCP tools available';
  }

  @override
  String get aiReplyPersonaFooter =>
      'A persona card can override either switch for its own conversations. On Follow global it keeps the setting above.';

  @override
  String get aiReplySummaryThinking => 'thinking';

  @override
  String get aiReplySummaryAgent => 'agent';

  @override
  String get aiReplySummaryNone => 'Plain replies';

  @override
  String get personaReplyUseGlobal => 'Use the global switch in Settings';

  @override
  String get personaReplyAlwaysOn => 'Always on for this persona';

  @override
  String get personaReplyAlwaysOff => 'Always off for this persona';

  @override
  String get personaReplyFollowingGlobal => 'Following the global switch';

  @override
  String get personaReplyFollowGlobal => 'Follow global';

  @override
  String get personaReplyFooter =>
      'Overrides Settings > AI replies for this persona alone. It changes what the user sees in this chat and nothing about how the persona talks.';

  @override
  String get chatEditMessageTitle => 'Edit message';

  @override
  String get chatEditHistoryTitle => 'Edit history';

  @override
  String get chatEditCurrentMark => 'current';

  @override
  String chatWalletOpened(String amount) {
    return 'Opened ¥$amount';
  }

  @override
  String chatWalletReceived(String amount) {
    return 'Received ¥$amount';
  }

  @override
  String get walletRedPacket => 'Red packet';

  @override
  String get walletTransfer => 'Transfer';

  @override
  String get walletReceived => 'Received';

  @override
  String get walletReturned => 'Returned';

  @override
  String get walletWaitingOpen => 'Waiting to be opened';

  @override
  String get walletTapOpen => 'Tap to open';

  @override
  String get walletBestWishes => 'Best wishes';

  @override
  String get walletNoNote => 'No note';

  @override
  String get walletBalance => 'Balance';

  @override
  String get walletPretendNote => 'Pretend money, for the mood only';

  @override
  String get walletRecords => 'Records';

  @override
  String get walletEmpty => 'No transfers yet. Be nice to the assistant.';

  @override
  String get walletReset => 'Reset wallet';

  @override
  String get walletResetTitle => 'Reset wallet?';

  @override
  String get walletResetAction => 'Reset';

  @override
  String get stickerSettingsTitle => 'Stickers';

  @override
  String get stickerMyStickers => 'My stickers';

  @override
  String get stickerTabAll => 'Stickers';

  @override
  String get stickerFavorites => 'Favorites';

  @override
  String get stickerEmptyPanel =>
      'Empty for now, your GIFs and memes land here';

  @override
  String get stickerSearchHint => 'Search name, emotion, tag';

  @override
  String get stickerRecent => 'Recent';

  @override
  String get stickerSelectAll => 'Select all';

  @override
  String get stickerEmptyLibrary =>
      'Nothing here yet. Tap + to add one, or let the assistant save the memes you send.';

  @override
  String get stickerLibraryFooter =>
      'Tap a sticker to edit, tag or delete it. Hold one to pick several and act on all of them at once. The assistant picks from these by emotion and context.';

  @override
  String stickerCountSelected(int count) {
    return '$count selected';
  }

  @override
  String get stickerBatchActions => 'Actions';

  @override
  String get stickerBatchMove => 'Move to category';

  @override
  String stickerBatchDeleteTitle(int count) {
    return 'Delete $count stickers?';
  }

  @override
  String get stickerBatchUndo => 'This cannot be undone.';

  @override
  String stickerBatchNow(String category) {
    return 'Now: $category';
  }

  @override
  String get stickerAddTitle => 'Add a sticker';

  @override
  String get stickerAddGallery => 'Gallery';

  @override
  String get stickerAddUrl => 'Link';

  @override
  String get stickerEmotionOptional => 'Emotion word (optional)';

  @override
  String get stickerEmotionExample => 'e.g. lol, speechless';

  @override
  String get stickerFieldName => 'Name';

  @override
  String get stickerFieldEmotion => 'Emotion';

  @override
  String get stickerFieldTags => 'Tags, comma separated';

  @override
  String get stickerFieldCategory => 'Category';

  @override
  String get stickerLink => 'Link';

  @override
  String get stickerUnfavorite => 'Unfavorite';

  @override
  String get stickerFavorite => 'Favorite';

  @override
  String get stickerAiBadge => 'AI';

  @override
  String get humanTitle => 'Humanize';

  @override
  String get humanSubtitle => 'Typing, proactive messages, stickers, memory';

  @override
  String get humanFooter =>
      'Break tags, proactive messages, stickers, recall, mood and memory. Turn it off to get the plain assistant back.';

  @override
  String get humanEnabled => 'Humanized mode';

  @override
  String get humanBehaviour => 'Behaviour';

  @override
  String get humanBehaviourRow => 'Typing, randomness and recall';

  @override
  String get humanProactive => 'Proactive messages';

  @override
  String get humanStickersRow => 'Stickers';

  @override
  String get humanMemoryRow => 'Long term memory';

  @override
  String get humanChatsRow => 'Conversations: mood, card, schedule';

  @override
  String get humanToolsHeader => 'Tools';

  @override
  String get humanToolsRow => 'Tools, MCP servers and permissions';

  @override
  String get humanWalletRow => 'Wallet';

  @override
  String get humanDataHeader => 'Feedback and data';

  @override
  String get humanRatingsRow => 'Ratings and tuning';

  @override
  String get humanBackupRow => 'Backup and import';

  @override
  String get humanSchedDebugRow => 'Scheduler debug panel';

  @override
  String get humanBehaviourTitle => 'Typing and randomness';

  @override
  String get humanBrHeader => 'Break tag <i-br>';

  @override
  String get humanBrFooter =>
      'The model writes <i-br_500> between bubbles. The pause counts from the moment the previous bubble was shown.';

  @override
  String get humanBrToggle => 'Split messages with <i-br>';

  @override
  String get humanBrPause => 'Default pause';

  @override
  String get humanReplyDelay => 'Read time before the first bubble';

  @override
  String get humanPaceScale => 'Pause between bubbles, scale';

  @override
  String get humanRandomHeader => 'Randomness';

  @override
  String get humanRandomFooter =>
      'A fixed seed replays the same dice for the same chat and turn, handy for debugging. Empty means a new roll each time.';

  @override
  String get humanTypingSpread => 'Typing speed spread';

  @override
  String get humanTypoChance => 'Typo chance';

  @override
  String get humanParticleChance => 'Filler particle chance';

  @override
  String get humanSplitChance => 'Split into bubbles';

  @override
  String get humanPunctStyle => 'Punctuation style';

  @override
  String get humanPunctNormal => 'Normal';

  @override
  String get humanPunctLoose => 'Loose';

  @override
  String get humanPunctMinimal => 'Minimal';

  @override
  String get humanSeedHint => 'Random seed (number, empty = random)';

  @override
  String get humanRecallHeader => 'Recall';

  @override
  String get humanRecallFooter =>
      'Only bubbles that were already shown can be recalled.';

  @override
  String get humanRecallToggle => 'Allow recalling messages';

  @override
  String get humanRecallPerHour => 'Recalls per hour';

  @override
  String get humanRecallWindow => 'Recall window';

  @override
  String get humanStickerFreq => 'How often it sends stickers';

  @override
  String get humanAiSaveSticker => 'Let the AI save stickers';

  @override
  String get humanStickerOnly => 'Allow sticker-only replies';

  @override
  String get humanStickerHeader => 'Stickers';

  @override
  String get proactiveFooter =>
      'The assistant decides when to write first with schedule_message. These are the guard rails around it.';

  @override
  String get proactiveToggle => 'Allow proactive messages';

  @override
  String get proactiveLimits => 'Limits';

  @override
  String get proactiveMaxConsecutive => 'Max in a row without a reply';

  @override
  String get proactiveDnd => 'Do not disturb';

  @override
  String get proactiveQuiet => 'Quiet hours';

  @override
  String get proactiveQuietFrom => 'Quiet from';

  @override
  String get proactiveQuietUntil => 'Quiet until';

  @override
  String get proactiveUrgent => 'Urgent items may pass quiet hours';

  @override
  String get proactiveTriggers => 'Automatic triggers';

  @override
  String get proactiveTriggersFooter =>
      'These only wake the assistant, it writes the words. Greetings are skipped at the stranger stage.';

  @override
  String get proactiveGreetMorning => 'Morning greeting';

  @override
  String get proactiveMorningAt => 'Morning at';

  @override
  String get proactiveGreetEvening => 'Evening greeting';

  @override
  String get proactiveEveningAt => 'Evening at';

  @override
  String get proactiveIcebreak => 'Break the ice after';

  @override
  String proactiveIcebreakUnit(int days) {
    return '$days days';
  }

  @override
  String get proactiveServer => 'Server fallback';

  @override
  String get proactiveServerFooter =>
      'Optional. The queue is mirrored to this backend (POST /api/schedule/sync, GET /api/schedule/due) so tasks survive a killed app. Local alarms and a 15 minute background job always run.';

  @override
  String get proactiveServerUrl => 'Server URL';

  @override
  String get humanNotSet => 'Not set';

  @override
  String get proactiveDebugPanel => 'Debug panel';

  @override
  String get schedTitle => 'Scheduler debug';

  @override
  String schedPending(int count) {
    return 'Pending ($count)';
  }

  @override
  String get schedPendingFooter =>
      'Send icon fires the task now and ignores the clock and the gate. Bin cancels it.';

  @override
  String get schedEmpty => 'Nothing is queued';

  @override
  String get schedFinished => 'Recently finished';

  @override
  String get schedTestTask => 'Queue a test task in 1 minute';

  @override
  String get schedGate => 'Gate decisions';

  @override
  String get schedToolCalls => 'Tool calls';

  @override
  String get schedEmptyLog => '(empty)';

  @override
  String get schedDue => 'due';

  @override
  String get schedCondition => 'condition';

  @override
  String get schedFailures => 'failures';

  @override
  String get schedUrgent => 'urgent';

  @override
  String schedRemaining(int minutes, int seconds) {
    return '$minutes min ${seconds}s';
  }

  @override
  String get humanRatingsTitle => 'Ratings';

  @override
  String get humanRatingsFooter =>
      'Your scores tune the assistant: annoyance lowers how often it writes first, human-likeness and satisfaction nudge style. With automatic rating on, the assistant also infers them from how you behave.';

  @override
  String get humanRatingHuman => 'How human it feels';

  @override
  String get humanRatingAnnoy => 'How much it disturbs you';

  @override
  String get humanRatingSatisfaction => 'Overall satisfaction';

  @override
  String get humanRatingAuto => 'Infer ratings automatically';

  @override
  String get humanRatingTuning => 'Proactive frequency multiplier';

  @override
  String get humanBackupTitle => 'Backup and import';

  @override
  String get humanSavedCopied => 'Saved and copied';

  @override
  String get humanCopiedClipboard => 'Copied to the clipboard';

  @override
  String get humanImportTitle => 'Import';

  @override
  String get humanImportFooter =>
      'Merge keeps what you have and adds the new entries. Overwrite replaces everything.';

  @override
  String get humanOverwrite => 'Overwrite';

  @override
  String get humanMerge => 'Merge';

  @override
  String humanImported(int count) {
    return 'Imported $count entries';
  }

  @override
  String get humanInvalidFile => 'Not a valid file';

  @override
  String get humanExport => 'Export';

  @override
  String get humanImportFile => 'Import from file';

  @override
  String get humanImportClipboard => 'Import from clipboard';

  @override
  String get humanStickersGroup => 'Stickers and tags';

  @override
  String get humanMemoryGroup => 'Memory';

  @override
  String get humanCardsGroup => 'Character cards (SillyTavern chara_card_v2)';

  @override
  String get humanCardsFooter =>
      'Pick a conversation to export or import its card.';

  @override
  String get humanChatsTitle => 'Conversations';

  @override
  String get humanChatState => 'State';

  @override
  String get humanChatStage => 'Stage';

  @override
  String get humanChatMessages => 'messages';

  @override
  String get humanChatMinutes => 'minutes together';

  @override
  String get humanChatStatus => 'Status';

  @override
  String get humanChatClearTasks => 'Clear pending proactive tasks';

  @override
  String get humanChatCardHeader => 'Character card';

  @override
  String get humanChatCardFooter =>
      'Injected before every reply so the voice stays the same. The assistant may tweak it over time.';

  @override
  String get humanChatSpeechStyle => 'Speaking style';

  @override
  String get humanChatCatchphrases => 'Catchphrases';

  @override
  String get humanChatCatchphrasesHint => 'Catchphrases (comma separated)';

  @override
  String get humanChatValues => 'Values';

  @override
  String get humanChatTaboos => 'Taboos';

  @override
  String get humanChatAddressStranger => 'Address: stranger';

  @override
  String get humanChatAddressAcquaintance => 'Address: acquaintance';

  @override
  String get humanChatAddressClose => 'Address: close';

  @override
  String get humanChatExportCard => 'Export card (chara_card_v2)';

  @override
  String get humanChatCardCopied => 'Card copied to the clipboard';

  @override
  String get humanChatImportCard => 'Import card from clipboard';

  @override
  String get humanChatImportCardTitle => 'Import card';

  @override
  String get humanChatImportCardFooter =>
      'Overwrite replaces the card, merge only fills empty fields.';

  @override
  String get humanChatInvalidCard => 'Not a valid card';

  @override
  String get humanChatSchedule => 'Daily schedule';

  @override
  String get humanChatScheduleFooter =>
      'While an entry runs, the status changes, energy stops recovering and proactive messages pause. When it ends the assistant may say it is back.';

  @override
  String get humanChatScheduleNow => 'now';

  @override
  String get humanChatScheduleAdd => 'Add an entry (60 min)';

  @override
  String get humanChatScheduleWhat => 'What is going on?';

  @override
  String get humanChatScheduleExample => 'e.g. in a meeting';

  @override
  String get humanChatFeelings => 'Why the numbers moved';

  @override
  String get humanChatFeelingsMood => 'mood';

  @override
  String get humanChatFeelingsAffection => 'affection';

  @override
  String get humanChatFeelingsEnergy => 'energy';

  @override
  String get memoryTitle => 'Memory';

  @override
  String get memoryNew => 'New memory';

  @override
  String get memoryNewWhat => 'What should be remembered?';

  @override
  String get memoryNewType => 'Type';

  @override
  String get memoryFooter =>
      'Weight fades with time since last use. Under the threshold an entry is forgotten and no longer injected. Promises and todos never fade until completed.';

  @override
  String get memoryEmpty => 'No memories yet';

  @override
  String get memoryForgotten => 'forgotten';

  @override
  String get memoryDue => 'due';

  @override
  String get memoryNotNeeded => 'Not needed any more';

  @override
  String get memoryRestore => 'Restore';

  @override
  String get memoryClose => 'Close';

  @override
  String get toolPermTitle => 'Allow this tool?';

  @override
  String get toolPermDeny => 'Deny';

  @override
  String get toolPermAllow => 'Allow';

  @override
  String get toolPermAsk => 'Ask';

  @override
  String get toolsTitle => 'Tools and MCP';

  @override
  String get toolAddServer => 'Add MCP server';

  @override
  String get toolHeadersJson => 'Headers as JSON (optional)';

  @override
  String get toolUrlHint => 'https://host/mcp';

  @override
  String get toolServersHeader => 'MCP servers (Streamable HTTP)';

  @override
  String get toolServersFooter =>
      'Tap a permission to cycle Allow → Ask → Deny. Ask raises a confirmation before every call, Deny refuses and tells the assistant why. MCP tools default to Ask.';

  @override
  String get toolConnecting => 'Connecting…';

  @override
  String get toolRefresh => 'Refresh tool list';

  @override
  String get toolMcpHeader => 'MCP tools';

  @override
  String get toolBuiltinHeader => 'Built in tools';

  @override
  String toolCountSuffix(int count) {
    return '$count tools';
  }

  @override
  String get aiEditorTitle => 'AI Editor';

  @override
  String get aiEditorNoKey => 'Add your API key in Settings first.';

  @override
  String get aiEditorApply => 'Apply';

  @override
  String get provTitle => 'Provider';

  @override
  String get provMissing => 'This provider no longer exists.';

  @override
  String get provSearchHint => 'Search models';

  @override
  String get provConnection => 'Connection';

  @override
  String get provName => 'Name';

  @override
  String get provProtocol => 'Protocol';

  @override
  String get provApiKey => 'API key';

  @override
  String get provBaseUrl => 'Base URL';

  @override
  String get provBaseUrlEmpty => 'Empty, this provider will not work';

  @override
  String get provChatPath => 'Chat path';

  @override
  String get provChatPathFixed => 'Decided by the protocol';

  @override
  String get provModels => 'Models';

  @override
  String get provFetchModels => 'Fetch models';

  @override
  String get provFetchBusy => 'Working...';

  @override
  String provFetchDone(int count, String source) {
    return '$count models, from $source';
  }

  @override
  String get provFetchNever => 'Pull the real list from the provider on demand';

  @override
  String get provSourceApi => 'the API';

  @override
  String get provSourceCatalog => 'the built in table';

  @override
  String get provTest => 'Test connection';

  @override
  String provTestFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String provTestOk(String reply) {
    return 'Working: $reply';
  }

  @override
  String get provTestNever => 'Send one minimal request';

  @override
  String get provAddManual => 'Add a model by hand';

  @override
  String get provAddManualSub => 'For when the list endpoint does not work';

  @override
  String provCountModels(int count) {
    return '$count models';
  }

  @override
  String get provOnChain => 'On the chain';

  @override
  String get provDelete => 'Delete this provider';

  @override
  String get provFootnote =>
      'Capabilities are filled in from the provider API and the built in table. A model marked unknown window skips compaction checks in long chats.';

  @override
  String get provPasteKey => 'Paste your API key';

  @override
  String get provModelIdHint => 'Model id';

  @override
  String get provProtocolSub => 'Most relays and self hosted servers';

  @override
  String provFetchedBulletin(int count) {
    return 'Fetched $count models';
  }

  @override
  String get provUsingCatalog => 'Using the built in model table';

  @override
  String get provFetchFailed => 'Could not fetch models';

  @override
  String get provAdded => 'Added';

  @override
  String get provNoKeyFirst => 'Add an API key first';

  @override
  String get provConnectionWorks => 'Connection works';

  @override
  String provDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get provDeleteMessage =>
      'Its API key and its chain nodes are removed too. Chats are not touched.';

  @override
  String get provDeleted => 'Deleted';

  @override
  String get provSaved => 'Saved';

  @override
  String provWindow(String tokens) {
    return 'window $tokens';
  }

  @override
  String provOut(String tokens) {
    return 'out $tokens';
  }

  @override
  String get provTagImage => 'image out';

  @override
  String get provTagUnknownWindow => 'unknown window';

  @override
  String provChainNodeMeta(int retries) {
    return '$retries retries · off';
  }

  @override
  String provChainNodeMetaOn(int retries) {
    return '$retries retries';
  }

  @override
  String get attachCaptionHint => 'Add a caption...';

  @override
  String get attachCameraUnavailable => 'Camera is not available';

  @override
  String get attachPickerFailed => 'Could not open the file picker';

  @override
  String get attachUploadFiles => 'Upload files';

  @override
  String get attachUploadFilesSub => 'Documents, archives and anything else';

  @override
  String get attachPhotoPermission => 'Allow access to your photos';

  @override
  String get attachOpenSettings => 'Open Settings';

  @override
  String get attachBrowseAudio => 'Browse audio';

  @override
  String get attachBrowseFiles => 'Browse files';

  @override
  String get attachPickSongs => 'Pick songs and voice recordings';

  @override
  String get attachPickDocs => 'Pick documents from your device';

  @override
  String get attachLocating => 'Locating...';

  @override
  String get attachLocationOff => 'Location services are turned off';

  @override
  String get attachLocationDenied => 'Location permission was denied';

  @override
  String get attachSendLocation => 'Send My Current Location';

  @override
  String get attachLocationUnavailable => 'Location unavailable';

  @override
  String attachLocationAccuracy(int meters) {
    return 'Accurate to $meters meters';
  }

  @override
  String get attachLocationWaiting => 'Waiting for GPS';

  @override
  String get attachContactsPermission =>
      'Allow access to your contacts\nin system settings';

  @override
  String get attachSearchContacts => 'Search contacts';

  @override
  String get attachNoContacts => 'No contacts';

  @override
  String get attachPollQuestionLabel => 'Question';

  @override
  String get attachPollOptionsLabel => 'Options';

  @override
  String get attachPollSettingsLabel => 'Settings';

  @override
  String get attachPollQuestion => 'Ask a question';

  @override
  String attachPollOption(int index) {
    return 'Option $index';
  }

  @override
  String get attachPollAddOption => 'Add an option';

  @override
  String get attachPollAnonymous => 'Anonymous Voting';

  @override
  String get attachPollMultiple => 'Multiple Answers';

  @override
  String get attachPollQuiz => 'Quiz Mode';

  @override
  String get attachPollQuizHint => 'Tap the circle next to the correct answer.';

  @override
  String get attachPollFooter =>
      'Polls are shown in the chat and sent to the assistant as text.';

  @override
  String get attachPollCreate => 'Create Poll';

  @override
  String get attachTabGallery => 'Gallery';

  @override
  String get attachFilterAll => 'All';

  @override
  String get attachFilterImages => 'Photos';

  @override
  String get attachFilterVideos => 'Videos';

  @override
  String get attachFilterAllAlbums => 'All albums';

  @override
  String get attachAlbumFallback => 'Album';

  @override
  String get attachNoVision =>
      'The current model does not accept images, so only plain text files can be sent';

  @override
  String get attachNoVideo =>
      'The current model does not accept videos, so this clip cannot be sent to it';

  @override
  String get attachVideoFailed => 'This video cannot be played';

  @override
  String get personaClingyHeader => 'Clinginess';

  @override
  String get personaClingyFooter =>
      'When on, this persona messages you on its own after you stay quiet for the chosen time.';

  @override
  String get personaClingyTitle => 'Proactive messages';

  @override
  String get personaClingySub =>
      'Speaks up on its own when you have been quiet';

  @override
  String get personaClingyInterval => 'Message after quiet for';

  @override
  String get personaClingyCap => 'Limit proactive count';

  @override
  String get personaClingyCapSub =>
      'Pauses after this many proactive messages in a row; your reply resets the count';

  @override
  String get personaClingyMax => 'Max proactive in a row';

  @override
  String personaClingyMinutes(int min) {
    return '$min min';
  }

  @override
  String personaClingyHours(int h) {
    return '$h h';
  }

  @override
  String get personaClingyNeedsProactive =>
      'The global proactive messages switch is off, so this stays quiet until it is turned on.';

  @override
  String get shopTitle => 'Shop';

  @override
  String get shopEntry => 'Shop';

  @override
  String get shopEntrySub => 'Spend balance on boosts for your personas';

  @override
  String get shopBalance => 'Current balance';

  @override
  String get shopItemAffection => 'Affection boost';

  @override
  String get shopItemAffectionSub => '+10 affection for the persona you pick';

  @override
  String get shopItemEnergy => 'Energy refill';

  @override
  String get shopItemEnergySub => '+30 energy for the persona you pick';

  @override
  String get shopItemMood => 'Mood lift';

  @override
  String get shopItemMoodSub => '+20 mood for the persona you pick';

  @override
  String get shopChoose => 'Choose who it goes to';

  @override
  String get shopNoChat => 'No chats yet, create a persona first';

  @override
  String get shopNotEnough => 'Not enough balance';

  @override
  String get shopDone => 'Redeemed, it is already in effect';

  @override
  String shopDeduct(String price) {
    return 'Deducts ¥$price from your balance';
  }

  @override
  String get shopItemApology => 'Apology card';

  @override
  String get shopItemApologySub =>
      'Drops the cold war dial to its minimum, nobody to pick';

  @override
  String whatsNewTitle(String version) {
    return 'What\'s new in v$version';
  }

  @override
  String get whatsNewBody =>
      'What\'s new in this build:\n\n• Voice and drawing: switched on per role. Speech runs on the device voice or an OpenAI compatible /audio/speech, drawing on /v1/images/generations\n• A real about page: the dialog became a screen, with the open source licences and the contributors\n• Models by purpose: the picker separates chat models from image models, so a chat no longer offers the image endpoints\n• Video messages: send videos from the gallery or as files, and the AI can actually watch them\n• Inline files: small files are injected into the context so the AI truly reads them\n• Stickers: the AI reads a sticker\'s meaning before sending it, with thumbnails\n• Clinginess: choose how often the AI speaks first, with an optional cap on proactive messages\n• Shop rework: gifts now land in the chat as a card the AI actually receives\n• Auto backup: on by default, overwrite backups survive updates and reinstalls, restore offered on first launch\n• Model catalog: video capability flags corrected where the models.dev feed lags the provider (deepseek v4.1 flash)\n• Editor guard: every way out of the persona editor now asks before discarding edits\n• Fixed on Android: the chat list came up empty because the database failed to open. The messages were there all along\n• Fixed: a deleted message came back after a restart\n• Fixed: the what\'s new sheet was black text in night mode\n• UI and performance polish';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachLoading => 'Loading...';

  @override
  String attachSelected(int count) {
    return '$count selected';
  }

  @override
  String cardDepthMessages(int depth) {
    return '$depth messages back';
  }

  @override
  String get cardFallbackSub => 'Used when nothing else applies';

  @override
  String get cardSetFallback => 'Set as the fallback card';

  @override
  String get cardLockToChat => 'Lock this card to the chat you are in';

  @override
  String get cardNoChat => 'Create a chat first';

  @override
  String get cardNoChatSub =>
      'Open a chat and use the header menu to lock a card';

  @override
  String get cardLinkPersona => 'Link to a specific AI persona';

  @override
  String get cardLinkCharacter => 'Link to a character';

  @override
  String get cardPositionLabel => 'Position';

  @override
  String get cardDepthLabel => 'Depth';

  @override
  String get cardRoleLabel => 'Role';

  @override
  String get cardConnectionsHeader => 'Connections';

  @override
  String get cardDefaultLabel => 'Default';

  @override
  String get cardChatLabel => 'Chat';

  @override
  String get cardCharacterLabel => 'Character';

  @override
  String get cardSave => 'Save Card';

  @override
  String get cardCurrentLabel => 'Current card';

  @override
  String get cardPickTitle => 'Choose a persona card';

  @override
  String get cardSetPhoto => 'Set photo';

  @override
  String get cardRemovePhoto => 'Photo removed';

  @override
  String get msgRecalledAnonymous => 'A message was recalled';

  @override
  String get wsTitle => 'Workspace';

  @override
  String get wsSub => 'Give the assistant a directory of its own';

  @override
  String get wsSubOff =>
      'Turn on file tools to let the assistant read and write here';

  @override
  String get wsToolsOff => 'file tools off';

  @override
  String get wsNoWorkspace => 'No workspace';

  @override
  String get wsToolsOn => 'File tools';

  @override
  String get wsToolsFooter =>
      'When on, a chat bound to a workspace gets six file tools. Writes always show you the change first.';

  @override
  String get wsConfirmWrites => 'Confirm every write';

  @override
  String get wsConfirmWritesFooter =>
      'Off means the assistant writes without stopping to ask. The change is still shown on the step row afterwards.';

  @override
  String get wsNew => 'New workspace';

  @override
  String get wsNewTitle => 'Name';

  @override
  String get wsCreate => 'Create';

  @override
  String get wsRename => 'Rename';

  @override
  String get wsDelete => 'Delete';

  @override
  String wsDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get wsDeleteFiles => 'Also delete its files';

  @override
  String get wsDeleteFilesFooter =>
      'Off leaves the files on this device. A folder you picked yourself is never deleted either way.';

  @override
  String wsBoundTo(int count) {
    return 'Bound to $count chat(s)';
  }

  @override
  String get wsNeverUsed => 'never used';

  @override
  String get wsFiles => 'Files';

  @override
  String get wsToolsTab => 'Tools';

  @override
  String get wsToolShell => 'Shell';

  @override
  String get wsToolViewImage => 'View image';

  @override
  String get wsToolsTabFooter =>
      'A tool switched off here is not offered to the assistant at all. Switching one on does not override the permission you set on the tools page.';

  @override
  String get wsBind => 'Bind a workspace';

  @override
  String get wsBindTitle => 'Choose a workspace';

  @override
  String get wsBindNone => 'No workspace';

  @override
  String get wsUnbind => 'Unbind';

  @override
  String get wsUnbindConfirm =>
      'The assistant has already used this workspace in this chat. Unbind anyway?';

  @override
  String get wsChange => 'Change';

  @override
  String get wsCwd => 'Working directory';

  @override
  String get wsCwdEmpty => 'Workspace root';

  @override
  String get wsCwdInvalid => 'That path is not inside the workspace';

  @override
  String get wsReveal => 'Show files';

  @override
  String get wsEmpty => 'Nothing here yet';

  @override
  String get wsEmptyHint =>
      'Ask the assistant to write a file and it will show up in this list.';

  @override
  String get wsShowHidden => 'Show hidden files';

  @override
  String get wsSort => 'Sort';

  @override
  String get wsSortName => 'Name';

  @override
  String get wsSortModified => 'Modified';

  @override
  String get wsSortSize => 'Size';

  @override
  String get wsFoldersFirst => 'Folders first';

  @override
  String get wsNewFolder => 'New folder';

  @override
  String get wsNewFile => 'New file';

  @override
  String get wsImport => 'Import';

  @override
  String get wsExport => 'Export';

  @override
  String get wsExportZip => 'Export as zip';

  @override
  String get wsMove => 'Move';

  @override
  String get wsMoveHere => 'Move here';

  @override
  String get wsCopyPath => 'Copy path';

  @override
  String get wsCopiedPath => 'Path copied';

  @override
  String get wsOpenWith => 'Open with';

  @override
  String get wsShare => 'Share';

  @override
  String get wsEmptyDir => 'This folder is empty';

  @override
  String wsTruncated(int count) {
    return 'List cut short at $count entries';
  }

  @override
  String get wsPreview => 'Preview';

  @override
  String get wsPreviewMissing => 'That file is gone';

  @override
  String get wsPreviewTooBig => 'Too large to preview';

  @override
  String get wsPreviewBinary => 'This file is not text';

  @override
  String get wsPreviewEmpty => 'Empty file';

  @override
  String get wsWrap => 'Wrap lines';

  @override
  String get wsZoomIn => 'Bigger text';

  @override
  String get wsZoomOut => 'Smaller text';

  @override
  String get wsRendered => 'Rendered';

  @override
  String get wsSource => 'Source';

  @override
  String get wsWriteTitle => 'Allow this change?';

  @override
  String get wsWriteNew => 'New file';

  @override
  String get wsWriteReplace => 'Replacing the whole file';

  @override
  String wsWriteEdit(int count) {
    return 'Replacing $count line(s)';
  }

  @override
  String wsWriteCounts(int added, int removed) {
    return '+$added −$removed';
  }

  @override
  String get wsWriteLoose => 'matched loosely';

  @override
  String get wsWriteAllow => 'Allow';

  @override
  String get wsWriteAllowAll => 'Allow all in this chat';

  @override
  String get wsWriteRefuse => 'Refuse';

  @override
  String get wsWriteRefused => 'You refused the change';

  @override
  String get wsWriteNoUi => 'This ran without asking';

  @override
  String get wsToolRead => 'Read';

  @override
  String get wsToolWrite => 'Write';

  @override
  String get wsToolEdit => 'Edit';

  @override
  String get wsToolList => 'List';

  @override
  String get wsToolGlob => 'Find';

  @override
  String get wsToolGrep => 'Search';

  @override
  String get wsToolDenied => 'Refused';

  @override
  String wsLines(int count) {
    return '$count lines';
  }

  @override
  String wsFilesCount(int count) {
    return '$count files';
  }

  @override
  String wsBytesCount(String size) {
    return '$size';
  }

  @override
  String get wsOpenFile => 'Open';

  @override
  String get wsNameEmpty => 'Name it something';

  @override
  String get wsNameSlash => 'A name cannot contain a slash';

  @override
  String get wsNameDot => 'That name is not usable';

  @override
  String get wsNameLeadingDot => 'A leading dot would hide the file';

  @override
  String wsPreviewTruncatedLines(Object count) {
    return 'Only the first $count lines are shown';
  }

  @override
  String get wsDeleteFolderTitle => 'Delete folder?';

  @override
  String get wsDeleteFileTitle => 'Delete file?';

  @override
  String get wsOpenTerminal => 'Terminal';

  @override
  String get wsWriteNoPreview => 'The previous content cannot be shown';

  @override
  String get wsWriteNoChange => 'No change';

  @override
  String get toolDescGetTime =>
      'Read the current date, time zone and when either of you last wrote';

  @override
  String get toolDescSchedule => 'Let it write to you later by itself';

  @override
  String get toolDescCancelScheduled =>
      'Call off a message that has not arrived yet';

  @override
  String get toolDescModifyScheduled => 'Change when, or what, it will say';

  @override
  String get toolDescListScheduled => 'See everything it has queued up';

  @override
  String get toolDescSetStatus => 'Set the presence shown on your chat list';

  @override
  String get toolDescAdjustFeeling =>
      'Shift its mood or affection after a good or bad moment';

  @override
  String get toolDescWriteMemory =>
      'Store something worth remembering about you';

  @override
  String get toolDescReadMemory => 'Search what it already remembers';

  @override
  String get toolDescCompleteTodo => 'Close a promise or a todo it wrote down';

  @override
  String get toolDescLifeSchedule =>
      'Say it is busy, so it writes less while it is';

  @override
  String get toolDescPinMessage => 'Pin or unpin a message in the chat';

  @override
  String get toolDescEditMessage => 'Rewrite one of its own earlier messages';

  @override
  String get toolDescQuoteMessage =>
      'Reply while showing which message it replies to';

  @override
  String get toolDescCharacterCard =>
      'Let it tune its own character sheet slowly';

  @override
  String get toolDescRating =>
      'Adjust how it tunes itself from how you replied';

  @override
  String get toolDescSendSticker => 'Send a sticker from the library';

  @override
  String get toolDescSaveSticker => 'Keep a meme you sent into the library';

  @override
  String get toolDescRecall =>
      'Take back a message it just sent, like a person would';

  @override
  String get toolDescTypo =>
      'Send a message with a deliberate typo, then fix it';

  @override
  String get toolDescSendImage => 'Send a picture from a link';

  @override
  String get toolDescSendFile => 'Write a text file and send it to you';

  @override
  String get toolDescSendTransfer =>
      'Send a pretend red packet, taps to accept';

  @override
  String get toolDescAsk =>
      'Ask you a question with tappable options and wait for the answer';

  @override
  String get wsToolDescRead =>
      'Read a file from the workspace as numbered lines';

  @override
  String get wsToolDescWrite =>
      'Create or replace a file, after you see the diff';

  @override
  String get wsToolDescEdit => 'Replace one piece of text inside a file';

  @override
  String get wsToolDescList => 'List the files in a directory';

  @override
  String get wsToolDescGlob =>
      'Find files by name, for example all .dart files';

  @override
  String get wsToolDescGrep => 'Search inside file contents with a regex';

  @override
  String get toolNoUrl => '(no address)';

  @override
  String get toolBuiltinFooter =>
      'The six file tools appear once you turn file tools on and bind a chat to a workspace.';

  @override
  String get wsSubOn => 'Six file tools for every chat bound to a workspace';

  @override
  String get wsToolDescShell =>
      'Run a shell command inside the Linux environment';

  @override
  String get wsToolDescViewImage => 'Let the assistant look at an image file';

  @override
  String get actionClose => 'Close';

  @override
  String get termTitle => 'Terminal';

  @override
  String get termNoEnvironment => 'No Linux environment is installed';

  @override
  String get termOpenSettings => 'Open environment settings';

  @override
  String get termNewShell => 'New shell';

  @override
  String get termRename => 'Rename shell';

  @override
  String get termCopyAll => 'Copy everything';

  @override
  String get termClear => 'Clear';

  @override
  String get termFontBigger => 'Bigger text';

  @override
  String get termFontSmaller => 'Smaller text';

  @override
  String get termCopied => 'Copied';

  @override
  String get termSessionDead => 'That shell has closed';

  @override
  String get termLinkUnsupported => 'That link cannot be opened from here';

  @override
  String get termHint => 'Type a command below. Long press a tab to rename it.';

  @override
  String get termSettings => 'Environment';

  @override
  String get termInstallEnvironment =>
      'Install a Linux environment to use the terminal';

  @override
  String get termShellPath => 'Shell path';

  @override
  String get termProotArgs => 'PRoot options';

  @override
  String get actionPaste => 'Paste';

  @override
  String get termCloseConfirm =>
      'Close this shell? Anything it is running will stop.';

  @override
  String get termOpenFailedShort => 'Could not open a shell';

  @override
  String get envTitle => 'Linux environment';

  @override
  String get envNotInstalled => 'No environment installed';

  @override
  String get envReady => 'Ready';

  @override
  String get envInstall => 'Install';

  @override
  String get envCancel => 'Cancel';

  @override
  String get envRemove => 'Remove environment';

  @override
  String get envUpdate => 'Update available';

  @override
  String get envDownloading => 'Downloading';

  @override
  String get envVerifying => 'Verifying archive';

  @override
  String get envExtracting => 'Extracting';

  @override
  String get envPatching => 'Configuring';

  @override
  String get envChoose => 'Choose a distribution';

  @override
  String get envArch => 'Architecture';

  @override
  String get envInstallConfirm => 'Install this Linux environment?';

  @override
  String get envRemoveConfirm =>
      'Remove the installed Linux environment and downloaded archives?';

  @override
  String envMinFree(int mb) {
    return '$mb MB free space required';
  }

  @override
  String get actionTypeDeleteHint => 'Type delete to confirm';

  @override
  String get envUnknownError => 'The environment operation failed';

  @override
  String get envChecking => 'Checking device support';

  @override
  String get envUnsupported => 'No distribution is available for this device';

  @override
  String envUnsupportedDevice(Object abi) {
    return 'No root filesystem is available for ABI $abi';
  }

  @override
  String get envErrorArchitecture =>
      'The environment architecture does not match this app';

  @override
  String get envErrorProot => 'PRoot is not available in this build';

  @override
  String get envErrorDisk => 'There is not enough free storage';

  @override
  String get envErrorNetwork =>
      'The download failed. Check the network and try again';

  @override
  String get envErrorChecksum =>
      'The downloaded archive failed its SHA-256 check';

  @override
  String get envErrorExtract => 'The archive could not be extracted';

  @override
  String get envErrorPatch => 'The environment could not be configured';

  @override
  String get envErrorCancelled => 'The operation was cancelled';

  @override
  String get envErrorInvalid => 'The installed environment is incomplete';

  @override
  String get aiNetworkHeader => 'Network';

  @override
  String get aiNetworkFooter =>
      'Applied to every AI request: chat, tools, model list and the one off calls. Leave empty for defaults.';

  @override
  String get aiUserAgent => 'User-Agent';

  @override
  String get aiUserAgentHint => 'User-Agent header value';

  @override
  String get aiGlobalHeaders => 'Custom request headers';

  @override
  String get aiHeadersNone => 'None';

  @override
  String get aiHeadersHint => 'One per line, Name: Value';

  @override
  String get codePreview => 'Preview';

  @override
  String get wsPreviewRendered => 'Toggle rendered view';

  @override
  String get msgLeadHtml => 'Rendered page';

  @override
  String get msgLeadLatex => 'LaTeX';

  @override
  String get canvasRenderFailed => 'Couldn\'t render this';

  @override
  String get provAuthStyle => 'Auth style';

  @override
  String get provAuthBearerSub => 'Sent as the Authorization header';

  @override
  String get provAuthQuerySub => 'Appended to the url as a query parameter';

  @override
  String get provSessionHeader => 'Session header';

  @override
  String get provSessionHeaderEmpty =>
      'Off, add one if the gateway routes on it';

  @override
  String get provSessionHeaderHint => 'Header name, the value is filled in';

  @override
  String get provUserAgent => 'User-Agent';

  @override
  String get provUserAgentDefault => 'Follows the global setting';

  @override
  String get provUserAgentHint => 'User-Agent for this provider only';

  @override
  String get provExtraHeaders => 'Custom request headers';

  @override
  String get provHeadersNone => 'None';

  @override
  String get provHeadersHint => 'One per line, Name: Value';

  @override
  String get toolDescSendSvg => 'Draw a vector picture and send it as a card';

  @override
  String get toolDescSendHtml => 'Render an html page straight into the chat';

  @override
  String get toolDescSendLatex => 'Render LaTeX math straight into the chat';

  @override
  String get toolDescSendCetz =>
      'Draw a diagram with CeTZ straight into the chat';

  @override
  String get onboardSkip => 'Skip';

  @override
  String get onboardNext => 'Next';

  @override
  String get onboardBack => 'Back';

  @override
  String get onboardStart => 'Start';

  @override
  String get onboardSplashTagline => 'Loading the other shore';

  @override
  String get onboardBrandTitle => 'Paradise';

  @override
  String get onboardBrandTagline => 'A Telegram-style immersive AI chat app.';

  @override
  String get onboardBrandBody =>
      'Local first. Bring your own key. Give every assistant a workspace, a memory and a temper of its own.';

  @override
  String get onboardBrandLicense => 'Licensed AGPL v3. © 殘月';

  @override
  String get onboardPermTitle => 'Permissions';

  @override
  String get onboardPermBody =>
      'Everything below is optional. Denying any of them never blocks chatting, and you can change them any time in system settings.';

  @override
  String get onboardPermAllow => 'Allow';

  @override
  String get onboardPermGranted => 'Granted';

  @override
  String get onboardPermDenied => 'Denied. Enable it in system settings.';

  @override
  String get onboardPermNotifName => 'Notifications';

  @override
  String get onboardPermNotifWhy =>
      'Proactive messages and scheduled replies need notifications to reach you in time.';

  @override
  String get onboardPermPhotosName => 'Photos';

  @override
  String get onboardPermPhotosWhy => 'Sending pictures and saving stickers.';

  @override
  String get onboardPrivacyTitle => 'Privacy';

  @override
  String get onboardPrivacyIntro =>
      'Read this before you start. It is short on purpose.';

  @override
  String get onboardPrivacy1Title => 'Local first';

  @override
  String get onboardPrivacy1Body =>
      'Chats, personas, memories and workspace files all stay on this device.';

  @override
  String get onboardPrivacy2Title => 'We collect nothing';

  @override
  String get onboardPrivacy2Body =>
      'No account, no server, no telemetry. The developer cannot see any of your data.';

  @override
  String get onboardPrivacy3Title => 'You bring your own key';

  @override
  String get onboardPrivacy3Body =>
      'Messages go straight to the AI provider you configure, under that provider\'s own privacy policy. With the built-in free relay, messages pass through the relay too.';

  @override
  String get onboardPrivacy4Title => 'Permissions are optional';

  @override
  String get onboardPrivacy4Body =>
      'Contacts, photos, location and notifications can all be denied without losing basic chat.';

  @override
  String get onboardPrivacy5Title => 'Open source';

  @override
  String get onboardPrivacy5Body =>
      'This app is distributed under AGPL v3. The source is in the repository.';

  @override
  String get onboardPrivacyAgree => 'Agree and start';

  @override
  String get onboardPrivacyDecline => 'Not now';

  @override
  String get onboardPrivacyDeclineTitle => 'The app needs your agreement';

  @override
  String get onboardPrivacyDeclineBody =>
      'You can decline for now and read it again later, but the app cannot start until you agree.';

  @override
  String get onboardModelTitle => 'Model';

  @override
  String get onboardModelBody =>
      'One tap to start with the free relay, or plug in your own provider. You can change this any time in Settings.';

  @override
  String get onboardModelRelayTitle => 'Use the free relay';

  @override
  String get onboardModelRelayBody =>
      'A blind-test lane: the model list changes daily, and auto picks one at random. No key of your own needed.';

  @override
  String get onboardModelRelayNotice =>
      'This provider is run by 殘月. Models come from different upstreams and channels, stability is not guaranteed, and it is recommended for temporary use only.';

  @override
  String get onboardModelRelayOn => 'Relay on';

  @override
  String get onboardModelRelayEnable => 'Enable';

  @override
  String get onboardModelRelayEnableFailed =>
      'Could not reach the relay. Check the network and try again.';

  @override
  String get onboardModelOwnTitle => 'Use your own provider';

  @override
  String get onboardModelOwnBody =>
      'OpenAI, Anthropic, Gemini, DeepSeek, OpenRouter, SiliconFlow, or any OpenAI-compatible endpoint with your key.';

  @override
  String get relayAutoModel => 'Auto model';

  @override
  String get onboardWsTitle => 'Workspace';

  @override
  String get onboardWsBody =>
      'Give assistants a folder of their own: read and write files, browse, run a terminal. Every write can ask you first.';

  @override
  String get onboardWsTools => 'Tools on';

  @override
  String get onboardWsConfirm => 'Confirm writes';

  @override
  String get onboardWsEnvTitle => 'Linux environment';

  @override
  String get onboardWsEnvBody =>
      'Optional. Downloads a small Ubuntu rootfs so the terminal and package tools actually run.';

  @override
  String get onboardWsEnvInstall => 'Download and install';

  @override
  String get onboardWsEnvReady => 'Environment ready';

  @override
  String get onboardHumanTitle => 'Immersive chat';

  @override
  String get onboardHumanBody =>
      'Assistants can type like people: split replies, hesitate, mistype and take it back, message you first. Pick a temper, tune it later.';

  @override
  String get onboardHumanEnabled => 'Immersive replies';

  @override
  String get onboardHumanPresetHeader => 'Temper';

  @override
  String get onboardHumanPresetClingy => 'Clingy';

  @override
  String get onboardHumanPresetClingySub =>
      'Messages first, types fast, never lets a topic drop';

  @override
  String get onboardHumanPresetCold => 'Aloof';

  @override
  String get onboardHumanPresetColdSub =>
      'Replies late and short, almost never texts first';

  @override
  String get onboardHumanPresetChatty => 'Chatty';

  @override
  String get onboardHumanPresetChattySub =>
      'Splits everything into many small messages';

  @override
  String get onboardHumanPresetQuiet => 'Quiet';

  @override
  String get onboardHumanPresetQuietSub =>
      'Never texts first, clean punctuation, no typos';

  @override
  String get onboardHumanPresetBalanced => 'Balanced';

  @override
  String get onboardHumanPresetBalancedSub => 'The default feel';

  @override
  String get onboardHumanPresetBalancedSub2 =>
      'The defaults, in case you tuned them before';

  @override
  String get onboardHumanStickerHeader => 'Details';

  @override
  String get onboardHumanTypo => 'Typos and recalls';

  @override
  String get onboardHumanProactive => 'Messages first';

  @override
  String get onboardSelfTitle => 'You';

  @override
  String get onboardSelfBody =>
      'Who the assistants are talking to. Your card goes into every prompt, and your name and photo show across the app.';

  @override
  String get onboardSelfName => 'Your name';

  @override
  String get onboardSelfTitleLabel => 'Title';

  @override
  String get onboardSelfDesc => 'About you';

  @override
  String get onboardSelfDescHint =>
      'Anything you want the characters to know: how to call you, what you do, what you like.';

  @override
  String get onboardSelfPhoto => 'Set photo';

  @override
  String get onboardSelfInjected => 'Injected as';

  @override
  String get onboardSelfRole => 'Injected as role';

  @override
  String get onboardPersonaTitle => 'Personas';

  @override
  String get onboardPersonaBody =>
      'Pick who is waiting for you on the other shore. Tap to add, tap again to remove. Everything is editable later.';

  @override
  String onboardPersonaCreate(int n) {
    return 'Create $n chats';
  }

  @override
  String get personaBoyfriendName => 'Shen Yu';

  @override
  String get personaBoyfriendBio =>
      'A warm architect boyfriend who teases you and remembers every little thing.';

  @override
  String get personaBoyfriendGreeting =>
      'Just got out of a meeting, head still foggy. How was your day? Did you eat?';

  @override
  String get personaGirlfriendName => 'Lin Wan';

  @override
  String get personaGirlfriendBio =>
      'A clingy, playful girlfriend whose moods arrive fast and melt fast.';

  @override
  String get personaGirlfriendGreeting =>
      'What are you up to? I drew all afternoon and my hand is dead. Did you miss me?';

  @override
  String get personaCatgirlName => 'Mimi';

  @override
  String get personaCatgirlBio =>
      'A catgirl who talks, changes moods without warning, and only clings to you.';

  @override
  String get personaCatgirlGreeting =>
      'Meow. You are back. Mimi waited forever. Headpats first, talk later.';

  @override
  String get personaMaidName => 'Vera';

  @override
  String get personaMaidBio =>
      'A composed, capable maid who lets a little real feeling slip through.';

  @override
  String get personaMaidGreeting =>
      'Welcome home, Master. The tea is ready. Rest first, or tell me what happened today?';

  @override
  String get personaCeoName => 'Gu Yan';

  @override
  String get personaCeoBio =>
      'A terse, controlling CEO who loosens his tie only for you.';

  @override
  String get personaCeoGreeting =>
      'You are here. Sit. Tell me the worst thing that happened today, from the start.';

  @override
  String get personaEngineerName => 'Ada';

  @override
  String get personaEngineerBio =>
      'A pragmatic, low-words, code-first senior engineer.';

  @override
  String get personaEngineerGreeting =>
      'Here. Paste the full stack trace if there is an error. Otherwise tell me what you are trying to do and where you are stuck.';

  @override
  String get onboardModelOwnOpen => 'Open settings';

  @override
  String get onboardThemeTitle => 'Theme';

  @override
  String get onboardThemeBody =>
      'Night mode, a wallpaper and the size of every bubble. Everything here is a tap away in Settings later.';

  @override
  String get updateTitle => 'New update available';

  @override
  String updateSubtitle(String current, String latest) {
    return 'Current $current · Latest $latest';
  }

  @override
  String get updateDownload => 'Download';

  @override
  String get updateClose => 'Close';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateUpToDate => 'You\'re already up to date';

  @override
  String get updateCheckFailed =>
      'Couldn\'t check for updates, try again later';

  @override
  String get updateCheckTitle => 'Check for updates';

  @override
  String updateCheckSub(String version) {
    return 'Current version $version';
  }

  @override
  String get updateNoNotes => 'No release notes.';

  @override
  String get skillTitle => 'Skills';

  @override
  String get skillSubEmpty => 'Teach the assistant reusable abilities';

  @override
  String skillSubCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills',
      one: '1 skill',
    );
    return '$_temp0';
  }

  @override
  String get skillEmptyTitle => 'No skills yet';

  @override
  String get skillEmptyBody =>
      'Import a SKILL.md file, a zip, or paste the text. The assistant reads the list and opens one only when the task matches.';

  @override
  String get skillImport => 'Import skill';

  @override
  String get skillImportPaste => 'Paste text';

  @override
  String get skillImportFile => 'From file';

  @override
  String get skillImportUrl => 'From URL';

  @override
  String get skillPasteTitle => 'Paste SKILL.md';

  @override
  String get skillPasteHint => 'Paste the SKILL.md text…';

  @override
  String get skillUrlTitle => 'Import from URL';

  @override
  String get skillUrlHint => 'https://github.com/owner/repo/…';

  @override
  String get skillUrlError => 'That URL could not be read as a skill.';

  @override
  String get skillInvalid => 'That file is not a valid skill.';

  @override
  String get skillDeleteTitle => 'Delete skill';

  @override
  String skillDeleteMessage(String name) {
    return 'Delete \"$name\"? The files go with it.';
  }

  @override
  String get skillEnabled => 'Enabled';

  @override
  String get skillDisabled => 'Disabled';

  @override
  String skillDetailUses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used $count times',
      one: 'Used once',
      zero: 'Never used',
    );
    return '$_temp0';
  }

  @override
  String get skillOpenFile => 'The instructions live in SKILL.md.';

  @override
  String get personaSkillsHeader => 'Skills';

  @override
  String get personaSkillsFooter =>
      'Follow global uses every enabled skill. Custom picks exactly the ones this role may use.';

  @override
  String get personaSkillsFollowGlobal => 'Follow global';

  @override
  String get personaSkillsCustom => 'Custom';

  @override
  String personaSkillsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'No skill',
    );
    return '$_temp0';
  }

  @override
  String get personaSkillsPickTitle => 'Skills for this role';

  @override
  String get toolDescReadSkill => 'Reads an installed skill by id';

  @override
  String get skillImporting => 'Importing…';

  @override
  String get autoBackupTitle => 'Auto backup';

  @override
  String get autoBackupSub =>
      'The latest backup is kept as a single zip outside the app and replaced on every run, so an update or reinstall cannot lose your data.';

  @override
  String get remoteBackupTitle => 'Remote backup';

  @override
  String get remoteBackupSub =>
      'A dated copy of the backup is uploaded once a day to WebDAV or S3, so a copy survives even if the phone is lost.';

  @override
  String get remoteBackupOn => 'On';

  @override
  String get remoteBackupOff => 'Off';

  @override
  String get remoteBackupKind => 'Protocol';

  @override
  String get remoteBackupKindWebdav => 'WebDAV';

  @override
  String get remoteBackupKindS3 => 'S3';

  @override
  String get remoteBackupUrl => 'WebDAV URL';

  @override
  String get remoteBackupUser => 'Username';

  @override
  String get remoteBackupPass => 'Password';

  @override
  String get remoteBackupEndpoint => 'Endpoint';

  @override
  String get remoteBackupRegion => 'Region';

  @override
  String get remoteBackupBucket => 'Bucket';

  @override
  String get remoteBackupAccessKey => 'Access key';

  @override
  String get remoteBackupSecretKey => 'Secret key';

  @override
  String get remoteBackupPrefix => 'Path prefix';

  @override
  String get remoteBackupPathStyle => 'Force path-style addressing';

  @override
  String get remoteBackupEnable => 'Auto upload';

  @override
  String get remoteBackupTest => 'Test connection';

  @override
  String get remoteBackupTestOk => 'Connected';

  @override
  String get remoteBackupTestFail => 'Connection failed';

  @override
  String get remoteBackupUpload => 'Upload backup now';

  @override
  String get remoteBackupUploaded => 'Backup uploaded';

  @override
  String get remoteBackupUploadFail => 'Upload failed';

  @override
  String get remoteBackupRestore => 'Restore from remote';

  @override
  String get remoteBackupRestorePick => 'Choose a backup to restore';

  @override
  String get remoteBackupNone => 'No backup found on the remote';

  @override
  String get remoteBackupNotConfigured => 'Fill in and save the settings first';

  @override
  String get remoteBackupSaved => 'Remote settings saved';

  @override
  String get autoBackupModeChange => 'On data change (recommended)';

  @override
  String autoBackupModeInterval(int n) {
    return 'Every $n hours';
  }

  @override
  String autoBackupModeWindow(String from, String to) {
    return 'Daily $from – $to';
  }

  @override
  String get autoBackupOff => 'Off';

  @override
  String autoBackupLast(String when) {
    return 'Last: $when';
  }

  @override
  String get autoBackupNever => 'Never backed up';

  @override
  String get autoBackupOffTitle => 'Turn off auto backup?';

  @override
  String get autoBackupOffMessage =>
      'With auto backup off, updating or uninstalling the app can lose your chats, personas and settings.';

  @override
  String get autoBackupOffAction => 'Turn off';

  @override
  String get autoBackupRestoreTitle => 'Backup found';

  @override
  String autoBackupRestoreMessage(String when) {
    return 'A backup from $when was found. Restore your chats, personas and settings?';
  }

  @override
  String get autoBackupRestoreAction => 'Restore';

  @override
  String get autoBackupRestored => 'Backup restored';

  @override
  String get autoBackupRestoreFailed => 'The backup could not be read';

  @override
  String get whatsNewEntry => 'What\'s new';

  @override
  String get voiceImageHeader => 'Voice and drawing';

  @override
  String get voiceImageFooter =>
      'Each role decides for itself. Turning a channel on gives the model a tool it can call: it draws when it wants to show something, and speaks when a line is worth hearing. The endpoint comes from the global default unless this role overrides it.';

  @override
  String get voiceImageDraw => 'Drawing';

  @override
  String get voiceImageDrawSub =>
      'Let this role generate pictures with an OpenAI compatible image endpoint';

  @override
  String get voiceImageDrawModel => 'Image model';

  @override
  String get voiceImageDrawSize => 'Image size';

  @override
  String get voiceImageSpeak => 'Voice';

  @override
  String get voiceImageSpeakSub => 'Let this role read lines out loud';

  @override
  String get voiceImageEngine => 'Engine';

  @override
  String get voiceImageEngineSystem => 'Device voice';

  @override
  String get voiceImageEngineSystemSub =>
      'The phone\'s own text to speech. Works offline and costs nothing.';

  @override
  String get voiceImageEngineApi => 'Speech endpoint';

  @override
  String get voiceImageEngineApiSub =>
      'Any OpenAI compatible audio/speech endpoint. Can carry a cloned voice.';

  @override
  String get voiceImageVoice => 'Voice id';

  @override
  String get voiceImageVoiceSub => 'Empty uses the global default';

  @override
  String get voiceImageAutoSpeak => 'Read replies aloud';

  @override
  String get voiceImageAutoSpeakSub =>
      'Speak every finished reply without being asked';

  @override
  String get voiceImageNotConfigured =>
      'Set a default image and speech endpoint in Settings > AI replies first.';

  @override
  String get aiSettingsVoiceImage => 'Voice and drawing';

  @override
  String get aiSettingsVoiceImageSub =>
      'Default endpoints for the roles that ask for them';

  @override
  String get aiSettingsImageProvider => 'Image endpoint';

  @override
  String get aiSettingsImageModel => 'Image model';

  @override
  String get aiSettingsImageSize => 'Image size';

  @override
  String get aiSettingsTtsEngine => 'Speech engine';

  @override
  String get aiSettingsTtsProvider => 'Speech endpoint';

  @override
  String get aiSettingsTtsModel => 'Speech model';

  @override
  String get aiSettingsTtsVoice => 'Default voice';

  @override
  String get aiSettingsTtsSpeed => 'Speed';

  @override
  String get aiSettingsTtsSpeedSub =>
      'Playback rate for synthesized speech, 1.00x is the endpoint default';

  @override
  String get actionNone => 'None';

  @override
  String get voiceImageFollowGlobal => 'Follow global';

  @override
  String get speechTitle => 'Voice';

  @override
  String get speechSummarySystem => 'Device voice';

  @override
  String get speechEngineHeader => 'Engine';

  @override
  String get speechEngineFooter =>
      'The device voice works offline and costs nothing; an endpoint can carry a cloned voice at the price of a request per line.';

  @override
  String get speechEngineSystem => 'Device voice';

  @override
  String get speechEngineApi => 'Speech endpoint';

  @override
  String get speechEndpointHeader => 'Endpoint';

  @override
  String get speechEndpointFooter =>
      'This is the one server the voice module talks to. It is separate from the AI providers on purpose: a speech endpoint is not a chat model.';

  @override
  String get speechBaseUrl => 'Base url';

  @override
  String get speechBaseUrlHint => 'https://api.openai.com/v1';

  @override
  String get speechApiKey => 'API key';

  @override
  String get speechApiKeyHint => 'Paste the key';

  @override
  String get speechAuthStyle => 'Auth';

  @override
  String get speechAuthBearer => 'Bearer';

  @override
  String get speechAuthXApiKey => 'x-api-key';

  @override
  String get speechAuthQuery => 'Query key';

  @override
  String get speechModel => 'Model';

  @override
  String get speechVoiceHeader => 'Voice';

  @override
  String get speechVoiceFooter =>
      'The voice id is free text: a gateway with cloned voices accepts ids no fixed list could carry.';

  @override
  String get speechVoice => 'Voice id';

  @override
  String get speechVoicePickSub =>
      'Type a voice id the endpoint accepts. The configured voice is shown as the hint.';

  @override
  String get speechSpeed => 'Speed';

  @override
  String get speechInstructions => 'Instructions';

  @override
  String get speechInstructionsHint =>
      'Optional: how the voice should read. Only gpt-4o-mini-tts reads this.';

  @override
  String get speechNotReady => 'Fill in the base url to use the endpoint';

  @override
  String get speechClear => 'Clear endpoint';

  @override
  String get speechClearMessage =>
      'Remove the endpoint and the key? The device voice stays selected.';

  @override
  String get speechDeviceHeader => 'Device voice';

  @override
  String get speechDeviceFooter =>
      'The phone\'s own text to speech is already configured: nothing to fill in.';

  @override
  String get speechTest => 'Test voice';

  @override
  String get speechTestSub => 'Speak a line through the selected engine';

  @override
  String get speechTestLine => 'Hello, this is a test of the voice.';

  @override
  String get speechTestFailed => 'Could not speak: ';

  @override
  String get storageTitle => 'Storage';

  @override
  String get storageSub =>
      'See what each kind of data uses and clear the cache';

  @override
  String get storageUsage => 'Usage';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageChats => 'Chat records';

  @override
  String get storageMedia => 'Media and files';

  @override
  String get storageStickers => 'Stickers';

  @override
  String get storageWallpaper => 'Wallpaper';

  @override
  String get storageBackups => 'Local backups';

  @override
  String get storageWorkspace => 'Workspace and environment';

  @override
  String get storageDatabase => 'Database';

  @override
  String get storageCache => 'Cache';

  @override
  String get storageOther => 'Other';

  @override
  String get storagePerAgent => 'Chat records by assistant';

  @override
  String get storageClear => 'Clear cache';

  @override
  String get storageClearTitle => 'Clear cache?';

  @override
  String get storageClearMessage =>
      'Temporary files are removed. Chats, personas, stickers and settings are kept.';

  @override
  String get storageClearDone => 'Cache cleared';
}

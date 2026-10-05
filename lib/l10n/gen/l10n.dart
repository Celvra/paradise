import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// Application name, launcher and task switcher
  ///
  /// In en, this message translates to:
  /// **'Paradise'**
  String get appTitle;

  /// Generic confirm button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// Generic dismiss button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Generic clear button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// Generic delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Closes a bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Generic save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Generic retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Copy to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// Generic add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// Generic remove button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// Throws unsaved edits away
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// Action bar title of My Account
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get accountTitle;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get accountNameHeader;

  /// Section footer
  ///
  /// In en, this message translates to:
  /// **'Enter your name and add an optional profile photo. Personas in the list below keep their own names.'**
  String get accountNameFooter;

  /// Field placeholder for the profile name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountNameHint;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Your bio'**
  String get accountBioHeader;

  /// Section footer
  ///
  /// In en, this message translates to:
  /// **'You can add a few lines about yourself. Characters may read it to get to know you.'**
  String get accountBioFooter;

  /// Field placeholder for the profile bio
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get accountBioHint;

  /// Section footer when a photo is set
  ///
  /// In en, this message translates to:
  /// **'Hold the avatar above to remove the photo quickly.'**
  String get accountPhotoFooter;

  /// Photo row when one is already set
  ///
  /// In en, this message translates to:
  /// **'Set New Photo'**
  String get accountSetNewPhoto;

  /// Photo row when none is set
  ///
  /// In en, this message translates to:
  /// **'Set Profile Photo'**
  String get accountSetPhoto;

  /// Photo row that drops the current photo
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get accountRemovePhoto;

  /// Confirmation title
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get accountRemovePhotoTitle;

  /// Confirmation body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove your profile photo?'**
  String get accountRemovePhotoMessage;

  /// Bulletin after the photo is dropped
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get accountPhotoRemoved;

  /// Button under the avatar when no photo is set
  ///
  /// In en, this message translates to:
  /// **'Set Photo'**
  String get accountPhotoActionSet;

  /// Button under the avatar when a photo is set
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get accountPhotoActionChange;

  /// Shown under the name when the bio is empty
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get accountOnlineFallback;

  /// Avatar preview while the name field is still empty
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get accountNameEmptyPreview;

  /// Bulletin when saving with an empty name
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get accountNameRequired;

  /// Confirmation title when leaving with unsaved edits
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get accountDiscardTitle;

  /// Confirmation body when leaving with unsaved edits
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes to your profile.'**
  String get accountDiscardMessage;

  /// Bulletin when the system gallery cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Gallery is not available'**
  String get galleryUnavailable;

  /// Generic edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Generic send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// Menu entry that drops one row
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemoveShort;

  /// Turn a chain node on
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get actionEnable;

  /// Turn a chain node off
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get actionDisable;

  /// Reorder a chain node
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get actionMoveUp;

  /// Reorder a chain node
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get actionMoveDown;

  /// Marks the value already in use
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get actionCurrent;

  /// Tab label on the AI screen
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get aiTabProviders;

  /// Tab label on the AI screen
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get aiTabChain;

  /// Tab label on the AI screen
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get aiTabAdvanced;

  /// Action bar title of the AI screen
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get aiTitle;

  /// Header headline when the chain can run
  ///
  /// In en, this message translates to:
  /// **'AI is ready'**
  String get aiReadyTitle;

  /// Header headline when nothing can run yet
  ///
  /// In en, this message translates to:
  /// **'AI is not set up'**
  String get aiNotReadyTitle;

  /// Header body when nothing can run yet
  ///
  /// In en, this message translates to:
  /// **'Add an API key to a provider, then put one of its models on the chain.'**
  String get aiNotReadyMessage;

  /// Chip under the AI header showing how many models are live
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model} other{{count} models}} on the chain'**
  String aiOnChainCount(int count);

  /// Section header of the provider list
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get aiProvidersHeader;

  /// Section footer of the provider list
  ///
  /// In en, this message translates to:
  /// **'Model capabilities come from the provider API and a built-in catalog. The context window decides when the history gets compacted.'**
  String get aiProvidersFooter;

  /// Row that creates a custom provider
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get aiAddProvider;

  /// Dialog title for naming a new custom provider
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get aiAddProviderTitle;

  /// Field placeholder for naming a new custom provider
  ///
  /// In en, this message translates to:
  /// **'Name, for example My Relay'**
  String get aiAddProviderHint;

  /// Provider row subtitle when a key is present
  ///
  /// In en, this message translates to:
  /// **'API key set'**
  String get aiKeySet;

  /// Provider row subtitle when no key is present
  ///
  /// In en, this message translates to:
  /// **'No API key'**
  String get aiNoKey;

  /// Provider row subtitle, how many of its models are on the chain
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model} other{{count} models}} on the chain'**
  String aiProviderOnChain(int count);

  /// Provider row subtitle, how many models it knows
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model} other{{count} models}}'**
  String aiProviderModels(int count);

  /// Section header of the fallback chain
  ///
  /// In en, this message translates to:
  /// **'Fallback chain'**
  String get aiChainHeader;

  /// Header trailing, how many chain nodes are enabled
  ///
  /// In en, this message translates to:
  /// **'{active} of {total} on'**
  String aiChainActiveCount(int active, int total);

  /// Placeholder when nothing is on the chain
  ///
  /// In en, this message translates to:
  /// **'No chain configured'**
  String get aiChainEmpty;

  /// Hint under an empty chain
  ///
  /// In en, this message translates to:
  /// **'The chain is empty. Add a model and requests will go to it first.'**
  String get aiChainEmptyHint;

  /// Note explaining how the chain is walked
  ///
  /// In en, this message translates to:
  /// **'Requests walk the chain top to bottom. Tap a model to reorder it, change its retries or remove it. Auth and billing failures never retry, they move straight to the next model.'**
  String get aiChainFooter;

  /// Row that appends a model to the chain
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get aiAddModel;

  /// Section header of the compaction settings
  ///
  /// In en, this message translates to:
  /// **'Context compaction'**
  String get aiCompactionHeader;

  /// Section footer of the compaction settings
  ///
  /// In en, this message translates to:
  /// **'On a context overflow compaction is retried once, then the history is hard truncated.'**
  String get aiCompactionFooter;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Compact long conversations'**
  String get aiCompactionToggle;

  /// Checkbox row subtitle
  ///
  /// In en, this message translates to:
  /// **'Early turns become a summary'**
  String get aiCompactionToggleSub;

  /// Row that picks the model used for summaries
  ///
  /// In en, this message translates to:
  /// **'Summary model'**
  String get aiSummaryModel;

  /// Subtitle when the summary model follows the chain
  ///
  /// In en, this message translates to:
  /// **'Follows the first model on the chain'**
  String get aiSummaryModelFollows;

  /// Row that picks the summary budget
  ///
  /// In en, this message translates to:
  /// **'Summary length'**
  String get aiSummaryLength;

  /// Model picker title when appending to the chain
  ///
  /// In en, this message translates to:
  /// **'Add to chain'**
  String get aiAddToChainTitle;

  /// Model picker title for the summary model
  ///
  /// In en, this message translates to:
  /// **'Model used for summaries'**
  String get aiSummaryModelPickerTitle;

  /// Selector sheet title for the summary budget
  ///
  /// In en, this message translates to:
  /// **'Summary length'**
  String get aiSummaryLengthTitle;

  /// Descriptor for a short summary budget
  ///
  /// In en, this message translates to:
  /// **'Tight'**
  String get aiLengthTight;

  /// Descriptor for a medium summary budget
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get aiLengthBalanced;

  /// Descriptor for a long summary budget
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get aiLengthDetailed;

  /// Menu entry that opens the retry count
  ///
  /// In en, this message translates to:
  /// **'Retries'**
  String get aiChainMenuRetries;

  /// Selector sheet title for the retry count
  ///
  /// In en, this message translates to:
  /// **'Retries before moving on'**
  String get aiRetriesTitle;

  /// Option for zero retries
  ///
  /// In en, this message translates to:
  /// **'No retries'**
  String get aiRetriesNone;

  /// Section header of the reply settings
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get aiRepliesHeader;

  /// Section footer of the reply settings
  ///
  /// In en, this message translates to:
  /// **'Character mode splits a reply into several short messages, the way people text.'**
  String get aiRepliesFooter;

  /// Row and selector title for the reply style
  ///
  /// In en, this message translates to:
  /// **'Reply style'**
  String get aiReplyStyle;

  /// One of the two reply styles
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get aiReplyStyleFull;

  /// One of the two reply styles
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get aiReplyStyleCharacter;

  /// Subtitle of the full reply style
  ///
  /// In en, this message translates to:
  /// **'Streams character by character and shows reasoning'**
  String get aiReplyStyleFullSub;

  /// Subtitle of the character reply style
  ///
  /// In en, this message translates to:
  /// **'Sends several short messages like a real person'**
  String get aiReplyStyleCharacterSub;

  /// Row and selector title for the delay before the first bubble
  ///
  /// In en, this message translates to:
  /// **'Read time before replying'**
  String get aiFirstBubbleDelay;

  /// Row and selector title for the inter bubble pause multiplier
  ///
  /// In en, this message translates to:
  /// **'Pause between messages, scale'**
  String get aiBubbleGapScale;

  /// Value shown when a pacing delay is zero
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get aiPacingOff;

  /// Subtitle of the zero delay option
  ///
  /// In en, this message translates to:
  /// **'The first bubble lands at once'**
  String get aiPacingDelayHint;

  /// Row and selector title for the pacing jitter
  ///
  /// In en, this message translates to:
  /// **'Timing randomness'**
  String get aiPacingJitter;

  /// One of the timing randomness levels
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get aiPacingJitterLow;

  /// One of the timing randomness levels
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get aiPacingJitterNormal;

  /// One of the timing randomness levels
  ///
  /// In en, this message translates to:
  /// **'Wild'**
  String get aiPacingJitterWild;

  /// Subtitle of the off level
  ///
  /// In en, this message translates to:
  /// **'Every pause is exactly as long as set'**
  String get aiPacingJitterHintOff;

  /// Subtitle of the subtle level
  ///
  /// In en, this message translates to:
  /// **'Pauses drift a little around the set values'**
  String get aiPacingJitterHintLow;

  /// Subtitle of the normal level
  ///
  /// In en, this message translates to:
  /// **'A human unevenness in every pause'**
  String get aiPacingJitterHintNormal;

  /// Subtitle of the wild level
  ///
  /// In en, this message translates to:
  /// **'Unpredictable, sometimes instant sometimes slow'**
  String get aiPacingJitterHintWild;

  /// Section header of the sampling settings
  ///
  /// In en, this message translates to:
  /// **'Sampling'**
  String get aiSamplingHeader;

  /// Section footer of the sampling settings
  ///
  /// In en, this message translates to:
  /// **'No model details are ever shown in the chat.'**
  String get aiSamplingFooter;

  /// Row and selector title for the sampling temperature
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get aiTemperature;

  /// Descriptor for temperature zero
  ///
  /// In en, this message translates to:
  /// **'Deterministic'**
  String get aiTempDeterministic;

  /// Descriptor for a low temperature
  ///
  /// In en, this message translates to:
  /// **'Focused'**
  String get aiTempFocused;

  /// Descriptor for a medium temperature
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get aiTempBalanced;

  /// Descriptor for a high temperature
  ///
  /// In en, this message translates to:
  /// **'Loose'**
  String get aiTempLoose;

  /// Row and selector title for the output token cap
  ///
  /// In en, this message translates to:
  /// **'Max output'**
  String get aiMaxOutput;

  /// Shown when a cap is left to the model
  ///
  /// In en, this message translates to:
  /// **'Model default'**
  String get aiModelDefault;

  /// Subtitle of the model default option
  ///
  /// In en, this message translates to:
  /// **'Use the catalog default'**
  String get aiUseCatalogDefault;

  /// Chain summary when a key exists but nothing is on the chain
  ///
  /// In en, this message translates to:
  /// **'The chain has no nodes yet'**
  String get aiSummaryNoNodes;

  /// Chain summary when no key is configured at all
  ///
  /// In en, this message translates to:
  /// **'No API key configured'**
  String get aiSummaryNoKey;

  /// Capability tag on a chain node
  ///
  /// In en, this message translates to:
  /// **'reasoning'**
  String get aiCapsReasoning;

  /// Capability tag on a chain node
  ///
  /// In en, this message translates to:
  /// **'vision'**
  String get aiCapsVision;

  /// Shown for a context window the catalog does not know
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get aiTokensUnknown;

  /// Bottom tab label, chat list
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// Bottom tab label, settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Bottom tab label, own profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Chat list header
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// Search pill placeholder on the chat list
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatsSearchHint;

  /// Empty chat list headline
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get chatsEmptyTitle;

  /// Empty chat list explanation
  ///
  /// In en, this message translates to:
  /// **'Create a persona to start a conversation.'**
  String get chatsEmptySub;

  /// Creates a persona card and opens a chat with it
  ///
  /// In en, this message translates to:
  /// **'New Persona'**
  String get chatsNewPersona;

  /// Marks every chat as read
  ///
  /// In en, this message translates to:
  /// **'Read All'**
  String get chatsMenuReadAll;

  /// Chat list subtitle while the assistant is generating
  ///
  /// In en, this message translates to:
  /// **'typing'**
  String get chatsRowTyping;

  /// Chat list subtitle prefix for an unsent message
  ///
  /// In en, this message translates to:
  /// **'Draft: '**
  String get chatsRowDraft;

  /// Chat list subtitle for a chat without messages
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatsRowEmpty;

  /// Chat list subtitle prefix for my own last message
  ///
  /// In en, this message translates to:
  /// **'You: '**
  String get chatsRowYou;

  /// Pin chat to the top
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get menuPin;

  /// Remove the pin
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get menuUnpin;

  /// Silence notifications for one chat
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get menuMute;

  /// Turn notifications back on
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get menuUnmute;

  /// Clear the unread badge
  ///
  /// In en, this message translates to:
  /// **'Mark as Read'**
  String get menuMarkAsRead;

  /// Menu entry that empties a chat
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get menuClearHistory;

  /// Menu entry that removes a chat
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get menuDeleteChat;

  /// Confirmation title for emptying a chat
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get dialogClearHistoryTitle;

  /// Confirmation body for emptying a chat
  ///
  /// In en, this message translates to:
  /// **'Delete all messages in {personaName}?'**
  String dialogClearHistoryMessage(String personaName);

  /// Confirmation title for removing a chat
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get dialogDeleteChatTitle;

  /// Confirmation body for removing a chat
  ///
  /// In en, this message translates to:
  /// **'This removes {personaName} and its history.'**
  String dialogDeleteChatMessage(String personaName);

  /// Pill shown in an empty chat
  ///
  /// In en, this message translates to:
  /// **'No messages here yet...'**
  String get chatEmptyPill;

  /// Placeholder inside the chat search field
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchHint;

  /// Chat search counter when nothing matched
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get chatSearchNoResults;

  /// Chat search hit counter, one based
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String chatSearchCount(int index, int total);

  /// Toggle back to the chat while search results are listed
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatSearchModeChat;

  /// Toggle to the flat list of search results
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get chatSearchModeList;

  /// Chat header subtitle while generating
  ///
  /// In en, this message translates to:
  /// **'typing'**
  String get chatStatusTyping;

  /// Chat header subtitle for the model
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get chatStatusBot;

  /// Message menu entry
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatMenuReply;

  /// Message menu entry
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatMenuCopy;

  /// Message menu entry that asks the model again
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatMenuRegenerate;

  /// Message menu entry
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatMenuDelete;

  /// Bulletin after copying a message
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get toastMessageCopied;

  /// Chat header menu entry
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get headerMenuSearch;

  /// Chat header menu entry
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get headerMenuViewProfile;

  /// Chat header menu entry
  ///
  /// In en, this message translates to:
  /// **'Edit Persona'**
  String get headerMenuEditPersona;

  /// Chat header menu subtitle for a muted chat
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get headerMenuMutedSub;

  /// Chat header menu entry, pins one persona card to the chat
  ///
  /// In en, this message translates to:
  /// **'Lock My Persona'**
  String get headerMenuLockPersona;

  /// Chat header menu entry
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get headerMenuClearHistory;

  /// Chat header menu entry
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get headerMenuDeleteChat;

  /// Confirmation title inside a chat
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get dialogClearHistoryHereTitle;

  /// Confirmation body inside a chat
  ///
  /// In en, this message translates to:
  /// **'Delete all messages in this chat?'**
  String get dialogClearHistoryHereMessage;

  /// Confirmation title inside a chat
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get dialogDeleteChatHereTitle;

  /// Title of the persona lock bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Lock my persona'**
  String get lockSheetTitle;

  /// Subtitle of the persona lock bottom sheet
  ///
  /// In en, this message translates to:
  /// **'This chat always answers as the card you pick.'**
  String get lockSheetSub;

  /// Placeholder for a persona card without a name
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get lockSheetUnnamed;

  /// Row that clears the persona lock
  ///
  /// In en, this message translates to:
  /// **'No lock'**
  String get lockSheetNone;

  /// Subtitle of the row that clears the persona lock
  ///
  /// In en, this message translates to:
  /// **'Use the card selected in My Account'**
  String get lockSheetNoneSub;

  /// Shown when there is no persona card to lock
  ///
  /// In en, this message translates to:
  /// **'No persona card yet. Make one in My Account.'**
  String get lockSheetEmpty;

  /// Settings tab header
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get settingsAccount;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Name and bio'**
  String get settingsAccountSub;

  /// Settings row for the model chain
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get settingsAi;

  /// Settings row subtitle when no model is configured
  ///
  /// In en, this message translates to:
  /// **'No model on the chain'**
  String get settingsAiSubNone;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Chat Appearance'**
  String get settingsAppearance;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Night mode, text size, corners'**
  String get settingsAppearanceSub;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Vibration on'**
  String get settingsVibrationOn;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Vibration off'**
  String get settingsVibrationOff;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Data and Storage'**
  String get settingsData;

  /// Settings row subtitle with chat count and media size
  ///
  /// In en, this message translates to:
  /// **'{chats, plural, =1{1 chat} other{{chats} chats}} · {size} of media'**
  String settingsDataSub(int chats, String size);

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Bulletin when the community link cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get aboutLinkFailed;

  /// Settings row subtitle of the about entry
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.2'**
  String get settingsAboutSub;

  /// Licence and ownership notice in the about dialog
  ///
  /// In en, this message translates to:
  /// **'Developer: 殘月. It is distributed under the AGPL 3.0 open source licence, which means you may not redistribute or commercialise it without publishing its source code. Violations will be handled in accordance with the law.'**
  String get settingsAboutLicense;

  /// Label in front of the community link in the about dialog
  ///
  /// In en, this message translates to:
  /// **'Join the community:'**
  String get settingsAboutCommunity;

  /// Repository link in the about dialog
  ///
  /// In en, this message translates to:
  /// **'Project address:\nhttps://github.com/Celvra/paradise'**
  String get settingsAboutRepo;

  /// Acknowledgements to the projects this one was modelled on
  ///
  /// In en, this message translates to:
  /// **'Acknowledgements:\n\nKelivo - ToolCall reference\nhttps://github.com/Chevey339/kelivo\n\nSillyTavern - persona card reference\nhttps://github.com/SillyTavern/SillyTavern'**
  String get settingsAboutThanks;

  /// Direct dependencies with their licence, the transitive tree is in the lockfile
  ///
  /// In en, this message translates to:
  /// **'Dependencies:\n\narchive 3.6.1 - zipping a workspace for export  (MIT)\nhttps://github.com/brendan-duncan/archive\nasync 2.13.0 - not used directly, pulled in by flutter_local_notifications  (BSD-2-Clause)\nhttps://github.com/dart-lang/async\ncharacters 1.4.1 - grapheme clusters for text measurement  (BSD-3-Clause)\nhttps://github.com/dart-lang/core/tree/main/pkgs/characters\ncrypto 3.0.7 - declared for the workspace, nothing on device is hashed yet  (BSD-3-Clause)\nhttps://github.com/dart-lang/core/tree/main/pkgs/crypto\nfile_picker 13.1.0 - picking documents and audio files  (MIT)\nhttps://github.com/vicajilau/flutter_file_picker/tree/main/packages/file_picker\nflutter_contacts 2.5.0 - sharing a contact card  (MIT)\nhttps://github.com/QuisApp/flutter_contacts\nflutter_highlight 0.7.0 - colouring the code preview  (MIT)\nhttps://github.com/git-touch/highlight\nflutter_local_notifications 18.0.1 - local notifications  (BSD-3-Clause)\nhttps://github.com/MaikuB/flutter_local_notifications\nflutter_svg 2.3.0 - provider logos and vector icons  (MIT)\nhttps://github.com/flutter/packages/tree/main/third_party/packages/flutter_svg\ngeolocator 13.0.4 - location attachments  (MIT)\nhttps://github.com/baseflow/flutter-geolocator/tree/main/geolocator\nglob 2.2.0 - the workspace find tool  (BSD-3-Clause)\nhttps://github.com/dart-lang/tools/tree/main/pkgs/glob\nhighlight 0.7.0 - the grammar data behind the code preview  (MIT)\nhttps://github.com/pd4d10/highlight\nhttp 1.6.0 - OpenAI compatible endpoints  (BSD-3-Clause)\nhttps://github.com/dart-lang/http/tree/master/pkgs/http\nimage_picker 1.2.3 - camera and gallery photos  (Apache-2.0)\nhttps://github.com/flutter/packages/tree/main/packages/image_picker/image_picker\nintl 0.20.3 - date and number formatting  (BSD-3-Clause)\nhttps://github.com/dart-lang/i18n/tree/main/pkgs/intl\npath 1.9.1 - path arithmetic in the workspace sandbox  (BSD-3-Clause)\nhttps://github.com/dart-lang/core/tree/main/pkgs/path\npath_provider 2.1.6 - app directory for stickers and exports  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/path_provider/path_provider\nphoto_manager 3.12.0 - album access for attachments  (Apache-2.0)\nhttps://github.com/fluttercandies/flutter_photo_manager\nshared_preferences 2.5.5 - settings and chat storage  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences\nsqflite 2.4.4 - message history and per chat paging  (BSD-2-Clause)\nhttps://github.com/tekartik/sqflite/tree/master/sqflite\ntimezone 0.10.1 - timezone data for scheduled messages  (BSD-2-Clause)\nhttps://github.com/srawlins/timezone\nurl_launcher 6.3.2 - the community link in this dialog  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher\nwebview_flutter 4.14.1 - rendering html in a file preview  (BSD-3-Clause)\nhttps://github.com/flutter/packages/tree/main/packages/webview_flutter/webview_flutter\nworkmanager 0.10.10 - background delivery when the app is killed  (MIT)\nhttps://github.com/fluttercommunity/flutter_workmanager'**
  String get settingsAboutDeps;

  /// Community link in the about dialog, identical in every language
  ///
  /// In en, this message translates to:
  /// **'https://discord.gg/aQaNUHPsw'**
  String get settingsAboutCommunityUrl;

  /// Small print at the bottom of settings
  ///
  /// In en, this message translates to:
  /// **'Developed by Celvra'**
  String get settingsFooter;

  /// Incoming bubble text in the message preview on the appearance page
  ///
  /// In en, this message translates to:
  /// **'Good morning! How can I help today?'**
  String get previewSampleIncoming;

  /// Outgoing bubble text in the message preview on the appearance page
  ///
  /// In en, this message translates to:
  /// **'Explain how transformers work'**
  String get previewSampleOutgoing;

  /// Settings row that opens the language picker
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language picker entry that follows the device language
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// Language name in its own language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language name in its own language
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChineseSimplified;

  /// Language name in its own language
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageChineseTraditional;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// Settings section header for the wallpaper
  ///
  /// In en, this message translates to:
  /// **'Chat Wallpaper'**
  String get wallpaperHeader;

  /// Settings row that opens the wallpaper picker
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get wallpaperRow;

  /// Wallpaper picker entry that keeps the stock gradient
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get wallpaperDefault;

  /// Wallpaper picker entry that opens the gallery
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get wallpaperChoose;

  /// Subtitle when no picture is chosen
  ///
  /// In en, this message translates to:
  /// **'Plain gradient'**
  String get wallpaperNone;

  /// Per chat entry that uses the global wallpaper
  ///
  /// In en, this message translates to:
  /// **'Follow global'**
  String get wallpaperFollowGlobal;

  /// Toggle that blurs the wallpaper
  ///
  /// In en, this message translates to:
  /// **'Blur wallpaper'**
  String get wallpaperBlur;

  /// Toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Keeps the bubbles readable over a photo'**
  String get wallpaperBlurSub;

  /// Section header above the extracted colour swatches
  ///
  /// In en, this message translates to:
  /// **'Accent from wallpaper'**
  String get wallpaperColorHeader;

  /// Note under the colour swatches
  ///
  /// In en, this message translates to:
  /// **'Pick a colour to recolour the accent and your own bubbles.'**
  String get wallpaperColorFooter;

  /// Swatch that clears the extracted accent
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get wallpaperColorNone;

  /// Shown when extraction found nothing
  ///
  /// In en, this message translates to:
  /// **'This photo has no colour to take'**
  String get wallpaperNoColors;

  /// Title of the outgoing bubble gradient picker
  ///
  /// In en, this message translates to:
  /// **'Bubble gradient'**
  String get wallpaperBubbleGrad;

  /// Weakest outgoing bubble gradient
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get wallpaperBubbleGradSubtle;

  /// Middle outgoing bubble gradient
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get wallpaperBubbleGradMedium;

  /// Widest outgoing bubble gradient
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get wallpaperBubbleGradStrong;

  /// Note under the gradient picker
  ///
  /// In en, this message translates to:
  /// **'How far your own bubbles fade from top to bottom.'**
  String get wallpaperBubbleGradSub;

  /// Bulletin after clearing a wallpaper
  ///
  /// In en, this message translates to:
  /// **'Wallpaper removed'**
  String get wallpaperRemoved;

  /// Title of the per chat wallpaper sheet
  ///
  /// In en, this message translates to:
  /// **'Wallpaper of this chat'**
  String get wallpaperChatTitle;

  /// Toggle row
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get appearanceNightMode;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Message Preview'**
  String get appearancePreview;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Message Text Size'**
  String get appearanceTextSize;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get appearanceSize;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Message Corners'**
  String get appearanceCorners;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get appearanceRadius;

  /// Row that restores the default text size and corner radius
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get appearanceReset;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get notifAlerts;

  /// Toggle row
  ///
  /// In en, this message translates to:
  /// **'Vibrate on Reply'**
  String get notifVibrate;

  /// Toggle row subtitle
  ///
  /// In en, this message translates to:
  /// **'A light tap when an answer arrives'**
  String get notifVibrateSub;

  /// Toggle row
  ///
  /// In en, this message translates to:
  /// **'Count Muted Chats'**
  String get notifCountMuted;

  /// Toggle row subtitle
  ///
  /// In en, this message translates to:
  /// **'Include them in the tab badge'**
  String get notifCountMutedSub;

  /// Note at the bottom of the notifications page
  ///
  /// In en, this message translates to:
  /// **'Each chat can also be muted from its menu or profile.'**
  String get notifFooter;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get dataUsage;

  /// Usage row label
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get dataChats;

  /// Usage row label
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get dataMessages;

  /// Usage row label
  ///
  /// In en, this message translates to:
  /// **'Media and Files'**
  String get dataMedia;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get dataClear;

  /// Row that forgets recent searches
  ///
  /// In en, this message translates to:
  /// **'Clear Search History'**
  String get dataClearSearch;

  /// Row that drops every attachment
  ///
  /// In en, this message translates to:
  /// **'Clear Media and Files'**
  String get dataClearMedia;

  /// Confirmation title
  ///
  /// In en, this message translates to:
  /// **'Clear media'**
  String get dataClearMediaTitle;

  /// Confirmation body
  ///
  /// In en, this message translates to:
  /// **'Photos, files and music are removed from every chat.'**
  String get dataClearMediaMessage;

  /// Row that removes every chat
  ///
  /// In en, this message translates to:
  /// **'Clear All Chats'**
  String get dataClearAll;

  /// Confirmation title
  ///
  /// In en, this message translates to:
  /// **'Clear all chats'**
  String get dataClearAllTitle;

  /// Confirmation body
  ///
  /// In en, this message translates to:
  /// **'This deletes every message in every chat. Personas stay.'**
  String get dataClearAllMessage;

  /// Section header above the backup rows
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get dataBackup;

  /// Subtitle of the export row
  ///
  /// In en, this message translates to:
  /// **'Conversations, cards, stickers and settings'**
  String get dataBackupExportSub;

  /// Subtitle of the import row
  ///
  /// In en, this message translates to:
  /// **'From a file you exported before'**
  String get dataBackupImportSub;

  /// Bulletin after a restore that changed something
  ///
  /// In en, this message translates to:
  /// **'{chats, plural, =1{1 conversation} other{{chats} conversations}} and {messages} messages'**
  String dataBackupRestored(num chats, Object messages);

  /// Bulletin after a restore that found nothing to do
  ///
  /// In en, this message translates to:
  /// **'There was nothing in that file to restore'**
  String get dataBackupNothing;

  /// Bulletin after the backup is written where the user chose
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get dataBackupSaved;

  /// Bulletin when the save dialog could not be used
  ///
  /// In en, this message translates to:
  /// **'Could not save the file'**
  String get dataBackupSaveFailed;

  /// Date separator for messages from today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// Date separator for messages from yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// Empty search results in the emoji panel
  ///
  /// In en, this message translates to:
  /// **'Type to search'**
  String get emojiSearchHint;

  /// Empty search results in the emoji panel
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get emojiNothingFound;

  /// Confirmation body when leaving an existing persona with unsaved edits
  ///
  /// In en, this message translates to:
  /// **'Your edits to this persona will be lost.'**
  String get personaDiscardExisting;

  /// Confirmation body when leaving a brand new persona
  ///
  /// In en, this message translates to:
  /// **'This persona has not been created yet.'**
  String get personaDiscardNew;

  /// Section header of the persona name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personaNameHeader;

  /// Field placeholder for the persona name
  ///
  /// In en, this message translates to:
  /// **'Persona name'**
  String get personaNameHint;

  /// Section header of the persona bio field
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get personaAboutHeader;

  /// Section footer of the persona bio field
  ///
  /// In en, this message translates to:
  /// **'A short line shown on the profile. It is not sent to the model.'**
  String get personaAboutFooter;

  /// Section header of the system prompt field
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get personaInstructionsHeader;

  /// Section footer of the system prompt field
  ///
  /// In en, this message translates to:
  /// **'This becomes the system prompt of every request in this chat.'**
  String get personaInstructionsFooter;

  /// Field placeholder for the system prompt
  ///
  /// In en, this message translates to:
  /// **'How should the AI behave?'**
  String get personaInstructionsHint;

  /// Section header of the greeting field
  ///
  /// In en, this message translates to:
  /// **'Greeting'**
  String get personaGreetingHeader;

  /// Section footer of the greeting field
  ///
  /// In en, this message translates to:
  /// **'Optional. Sent as the first message when the chat opens.'**
  String get personaGreetingFooter;

  /// Field placeholder for the greeting
  ///
  /// In en, this message translates to:
  /// **'First message from the persona'**
  String get personaGreetingHint;

  /// Bottom button when editing an existing persona
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get personaSave;

  /// Bottom button when creating a persona
  ///
  /// In en, this message translates to:
  /// **'Create Persona'**
  String get personaCreate;

  /// Section header of the preset chips
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get personaTemplatesHeader;

  /// Section header of the avatar and colour picker
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get personaAppearanceHeader;

  /// Section footer when a photo is set
  ///
  /// In en, this message translates to:
  /// **'A photo replaces the emoji everywhere the avatar is shown.'**
  String get personaAppearanceFooterPhoto;

  /// Section footer when only a colour is set
  ///
  /// In en, this message translates to:
  /// **'The colour is used for the avatar and the profile cover.'**
  String get personaAppearanceFooterColor;

  /// Avatar row title when a photo is set
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get personaPhotoTitle;

  /// Avatar row title when no photo is set
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get personaPhotoTitleEmpty;

  /// Avatar row subtitle when a photo is set
  ///
  /// In en, this message translates to:
  /// **'Tap to change, hold to remove'**
  String get personaPhotoSubFull;

  /// Avatar row subtitle when no photo is set
  ///
  /// In en, this message translates to:
  /// **'Add a photo, or leave it on the colour below'**
  String get personaPhotoSubEmpty;

  /// Text button that opens the gallery
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get personaChoose;

  /// Model picker title from the persona editor
  ///
  /// In en, this message translates to:
  /// **'Model for this persona'**
  String get personaModelForThis;

  /// Follow chain row title from the persona editor
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get personaModelGlobal;

  /// Follow chain row subtitle from the persona editor
  ///
  /// In en, this message translates to:
  /// **'Follow whatever the chain is set to'**
  String get personaModelGlobalSub;

  /// Model section footer when an override is set
  ///
  /// In en, this message translates to:
  /// **'Off means a failure on this model ends the reply instead of trying the global chain.'**
  String get personaModelFooterOverride;

  /// Model section footer when no override is set
  ///
  /// In en, this message translates to:
  /// **'Global follows the chain in Settings > AI. Pick a model to run this persona on its own.'**
  String get personaModelFooterGlobal;

  /// Model row title when no override is set
  ///
  /// In en, this message translates to:
  /// **'Global chain'**
  String get personaModelGlobalChain;

  /// Model row subtitle tail when an override is set
  ///
  /// In en, this message translates to:
  /// **'this persona only'**
  String get personaModelOnlyThis;

  /// Model row subtitle when no override is set
  ///
  /// In en, this message translates to:
  /// **'Follows Settings > AI'**
  String get personaModelFollowsSettings;

  /// Trailing value inviting the user to pick a model
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get personaModelChange;

  /// Checkbox row under a model override
  ///
  /// In en, this message translates to:
  /// **'Fall back to the global chain'**
  String get personaModelFallback;

  /// Row that drops the model override
  ///
  /// In en, this message translates to:
  /// **'Use Global Chain'**
  String get personaModelUseGlobal;

  /// One liner of the Assistant template
  ///
  /// In en, this message translates to:
  /// **'A calm all round helper'**
  String get presetAssistantBio;

  /// One liner of the Coder template
  ///
  /// In en, this message translates to:
  /// **'Reads stack traces for fun'**
  String get presetCoderBio;

  /// One liner of the Translator template
  ///
  /// In en, this message translates to:
  /// **'English and Chinese both ways'**
  String get presetTranslatorBio;

  /// One liner of the Writer template
  ///
  /// In en, this message translates to:
  /// **'Tightens every sentence'**
  String get presetWriterBio;

  /// One liner of the Tutor template
  ///
  /// In en, this message translates to:
  /// **'Explains it like a friend'**
  String get presetTutorBio;

  /// Default title of the follow chain row in the model picker
  ///
  /// In en, this message translates to:
  /// **'Follow the first node on the chain'**
  String get aiFollowChain;

  /// Default subtitle of the follow chain row in the model picker
  ///
  /// In en, this message translates to:
  /// **'Use the current main model for summaries'**
  String get aiFollowChainSub;

  /// Search field placeholder in the model picker
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get aiSearchModels;

  /// Model picker empty state before any provider was queried
  ///
  /// In en, this message translates to:
  /// **'No models loaded yet.\nFetch a list from a provider first.'**
  String get aiNoModelsLoaded;

  /// Model picker empty state for a query that hit nothing
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\"'**
  String aiNoModelMatches(String query);

  /// Language label of a fenced code block with no language given
  ///
  /// In en, this message translates to:
  /// **'code'**
  String get codeGeneric;

  /// Bulletin after copying a code block
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get toastCodeCopied;

  /// Search strip chip that clears the filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchFilterAll;

  /// Header of the recent queries block
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get searchRecent;

  /// Header of the persona shortcut row
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeople;

  /// Empty results headline
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get searchNoResultsTitle;

  /// Empty results body before a query was typed
  ///
  /// In en, this message translates to:
  /// **'Nothing of this kind has been shared yet.'**
  String get searchEmptyBody;

  /// Empty results body after a query returned nothing
  ///
  /// In en, this message translates to:
  /// **'There were no results for \"{query}\". Try a new search.'**
  String searchNoResultsBody(String query);

  /// Button tile on my own profile
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileButtonEdit;

  /// Button tile on my own profile
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get profileButtonShare;

  /// Button tile on a persona profile
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileButtonMessage;

  /// Button tile on a persona profile
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get profileButtonSearch;

  /// Bulletin after copying the profile
  ///
  /// In en, this message translates to:
  /// **'Profile copied'**
  String get profileCopied;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileLabelName;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileLabelBio;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'Persona Card'**
  String get profileLabelPersonaCard;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profileLabelActivity;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileLabelAbout;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get profileLabelInstructions;

  /// Info cell label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get profileLabelModel;

  /// Row label of the per chat notification switch
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileLabelNotifications;

  /// Placeholder value of the bio cell when it is still empty
  ///
  /// In en, this message translates to:
  /// **'Add a few words about yourself'**
  String get profileBioEmpty;

  /// Placeholder value of the persona card cell when it is still empty
  ///
  /// In en, this message translates to:
  /// **'Tell the AI who you are'**
  String get profileCardEmpty;

  /// Activity cell value, chats and messages I sent
  ///
  /// In en, this message translates to:
  /// **'{chats, plural, =1{1 chat} other{{chats} chats}} · {sent, plural, =1{1 sent} other{{sent} sent}}'**
  String profileActivity(int chats, int sent);

  /// Switch value when notifications are on
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get profileOn;

  /// Switch value when notifications are off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get profileOff;

  /// Profile header subtitle while the persona is generating
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get profileHeaderTyping;

  /// Bulletin after copying a labelled value
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String toastCopiedLabel(String label);

  /// Shared content tab
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get profileTabMedia;

  /// Shared content tab
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get profileTabFiles;

  /// Shared content tab
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get profileTabMusic;

  /// Shared content tab
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get profileTabLinks;

  /// Empty state of the media tab
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get profileSharedEmptyMedia;

  /// Empty state of the files tab
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get profileSharedEmptyFiles;

  /// Empty state of the music tab
  ///
  /// In en, this message translates to:
  /// **'No music yet'**
  String get profileSharedEmptyMusic;

  /// Empty state of the links tab
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get profileSharedEmptyLinks;

  /// Preview lead for a photo message
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get msgLeadPhoto;

  /// Preview lead for a music message
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get msgLeadMusic;

  /// Preview lead for a contact message
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get msgLeadContact;

  /// Preview lead for a poll message
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get msgLeadPoll;

  /// Preview lead for a sticker message
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get msgLeadSticker;

  /// Row title of a music attachment with no name
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get attachAudioFallback;

  /// Row title of a file attachment with no name
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachFileFallback;

  /// Title of a location attachment
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get attachLocationTitle;

  /// Bulletin after copying coordinates
  ///
  /// In en, this message translates to:
  /// **'Coordinates copied'**
  String get attachLocationCopied;

  /// Shown for a contact card with no phone number
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get attachNoPhone;

  /// Poll subtitle when it is a quiz
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get pollKindQuiz;

  /// Poll subtitle when results are visible
  ///
  /// In en, this message translates to:
  /// **'Public Poll'**
  String get pollKindPublic;

  /// Poll subtitle when results are hidden
  ///
  /// In en, this message translates to:
  /// **'Anonymous Poll'**
  String get pollKindAnonymous;

  /// Poll subtitle when more than one answer is allowed
  ///
  /// In en, this message translates to:
  /// **'{kind} · Multiple answers'**
  String pollKindMultiple(String kind);

  /// Ask card subtitle, an answer unblocks the waiting tool call
  ///
  /// In en, this message translates to:
  /// **'Question · tap to answer'**
  String get askKind;

  /// Ask card subtitle in multi choice mode
  ///
  /// In en, this message translates to:
  /// **'Question · pick any, then submit'**
  String get askKindMulti;

  /// Ask card subtitle after the answer was submitted
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get askDone;

  /// Ask card subtitle after the user skipped it
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get askSkipped;

  /// Hint of the custom answer field on an ask card
  ///
  /// In en, this message translates to:
  /// **'Or write your own answer…'**
  String get askOtherHint;

  /// Button that submits the answer on an ask card
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get askSubmit;

  /// Button that skips an ask card without answering
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get askSkip;

  /// Photo viewer header counter
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String photoCounter(int index, int total);

  /// Row title when an attachment carries no name
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get profileFileFallback;

  /// Shown when the provider rejects the key
  ///
  /// In en, this message translates to:
  /// **'API key is invalid or has no access'**
  String get errorAuth;

  /// Shown when the account has no balance left
  ///
  /// In en, this message translates to:
  /// **'Provider is out of credit'**
  String get errorQuota;

  /// Shown on HTTP 429
  ///
  /// In en, this message translates to:
  /// **'Rate limited by the provider'**
  String get errorRate;

  /// Shown when the prompt does not fit the model
  ///
  /// In en, this message translates to:
  /// **'Context is longer than the model window'**
  String get errorContextOverflow;

  /// Shown on HTTP 5xx
  ///
  /// In en, this message translates to:
  /// **'Provider returned an error'**
  String get errorServer;

  /// Shown when the request never reached the provider
  ///
  /// In en, this message translates to:
  /// **'Network connection failed'**
  String get errorNetwork;

  /// Shown when the user stopped the reply
  ///
  /// In en, this message translates to:
  /// **'Generation stopped'**
  String get errorAborted;

  /// Shown when the reply body was empty
  ///
  /// In en, this message translates to:
  /// **'The model returned nothing'**
  String get errorEmpty;

  /// Fallback for an unclassified failure
  ///
  /// In en, this message translates to:
  /// **'Request failed'**
  String get errorUnknown;

  /// Service message when the chain fell back to another node
  ///
  /// In en, this message translates to:
  /// **'Stopped early: {reason}'**
  String errorStoppedEarly(String reason);

  /// Count of chats
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chat} other{{count} chats}}'**
  String pluralChats(int count);

  /// Count of votes on a poll, also covers zero
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes yet} =1{1 vote} other{{count} votes}}'**
  String pluralVotes(int count);

  /// Count of picked attachments
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} selected}}'**
  String pluralSelected(int count);

  /// Count of models known to a provider
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model} other{{count} models}}'**
  String pluralModels(int count);

  /// Count of retries before the chain moves on
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 retry} other{{count} retries}}'**
  String pluralRetries(int count);

  /// Count of poll options
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} options}}'**
  String pluralOptions(int count);

  /// Count of characters for the summary length
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} chars}}'**
  String pluralChars(int count);

  /// Count of tokens
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} tokens}}'**
  String pluralTokens(int count);

  /// No description provided for @cardCreate.
  ///
  /// In en, this message translates to:
  /// **'Create card'**
  String get cardCreate;

  /// No description provided for @cardDeleteThisCard.
  ///
  /// In en, this message translates to:
  /// **'this card'**
  String get cardDeleteThisCard;

  /// No description provided for @cardDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete card'**
  String get cardDeleteTitle;

  /// No description provided for @cardDeleted.
  ///
  /// In en, this message translates to:
  /// **'Card deleted'**
  String get cardDeleted;

  /// No description provided for @cardDescHint.
  ///
  /// In en, this message translates to:
  /// **'Who you are, how you talk, what you like'**
  String get cardDescHint;

  /// No description provided for @cardDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get cardDuplicate;

  /// No description provided for @cardDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Card duplicated'**
  String get cardDuplicated;

  /// No description provided for @cardEditing.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get cardEditing;

  /// No description provided for @cardEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create a persona card to tell the assistant who you are.'**
  String get cardEmptyBody;

  /// No description provided for @cardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No persona cards'**
  String get cardEmptyTitle;

  /// No description provided for @cardFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cardFieldDescription;

  /// No description provided for @cardFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cardFieldName;

  /// No description provided for @cardFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'What the assistant calls you'**
  String get cardFieldNameHint;

  /// No description provided for @cardFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get cardFieldTitle;

  /// No description provided for @cardFieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Shown in the list only'**
  String get cardFieldTitleHint;

  /// No description provided for @cardInfoFooter.
  ///
  /// In en, this message translates to:
  /// **'The description is sent to the model with every request.'**
  String get cardInfoFooter;

  /// No description provided for @cardNew.
  ///
  /// In en, this message translates to:
  /// **'New card'**
  String get cardNew;

  /// No description provided for @cardPlaceholdersHint.
  ///
  /// In en, this message translates to:
  /// **'Use the user and char placeholder tokens.'**
  String get cardPlaceholdersHint;

  /// No description provided for @cardPositionTitle.
  ///
  /// In en, this message translates to:
  /// **'Position in the prompt'**
  String get cardPositionTitle;

  /// No description provided for @cardRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Role of the injected message'**
  String get cardRoleTitle;

  /// No description provided for @posAtDepth.
  ///
  /// In en, this message translates to:
  /// **'At depth'**
  String get posAtDepth;

  /// No description provided for @posAtDepthSub.
  ///
  /// In en, this message translates to:
  /// **'Inserted a few messages back from the newest one'**
  String get posAtDepthSub;

  /// No description provided for @posBottomNote.
  ///
  /// In en, this message translates to:
  /// **'Bottom note'**
  String get posBottomNote;

  /// No description provided for @posBottomNoteSub.
  ///
  /// In en, this message translates to:
  /// **'The last thing read before the conversation'**
  String get posBottomNoteSub;

  /// No description provided for @posInPrompt.
  ///
  /// In en, this message translates to:
  /// **'In prompt'**
  String get posInPrompt;

  /// No description provided for @posInPromptSub.
  ///
  /// In en, this message translates to:
  /// **'Merged into the system prompt'**
  String get posInPromptSub;

  /// No description provided for @posNone.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get posNone;

  /// No description provided for @posNoneSub.
  ///
  /// In en, this message translates to:
  /// **'The card is not sent'**
  String get posNoneSub;

  /// No description provided for @posTopNote.
  ///
  /// In en, this message translates to:
  /// **'Top note'**
  String get posTopNote;

  /// No description provided for @posTopNoteSub.
  ///
  /// In en, this message translates to:
  /// **'Ahead of everything else'**
  String get posTopNoteSub;

  /// No description provided for @roleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get roleAssistant;

  /// No description provided for @roleSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get roleSystem;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get roleUser;

  /// No description provided for @cardDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String cardDeleteMessage(String name);

  /// Stamp on a recalled bubble, names whoever recalled it
  ///
  /// In en, this message translates to:
  /// **'{name} recalled a message'**
  String msgRecalled(String name);

  /// Suffix on the timestamp of an edited message
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get msgEdited;

  /// Bar at the top of a chat holding a pinned message
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get msgPinned;

  /// Tag over the reasoning block
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get traceThinking;

  /// Reasoning block title while it is still generating
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get traceThinkingNow;

  /// Reasoning block title once it is done, with the duration
  ///
  /// In en, this message translates to:
  /// **'Thought for {seconds}'**
  String traceThoughtFor(String seconds);

  /// Tag over a tool call that is still running
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get traceRunning;

  /// State of a tool call that failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get traceFailed;

  /// Tag over the argument dump of a tool call
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get traceArguments;

  /// Tag over the result of a tool call
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get traceResult;

  /// Duration in the trace rows
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String traceSeconds(String value);

  /// Presence label when the character is reachable
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get statusOnline;

  /// Presence label when the character stepped away
  ///
  /// In en, this message translates to:
  /// **'away'**
  String get statusAway;

  /// Presence label of the do not disturb state
  ///
  /// In en, this message translates to:
  /// **'do not disturb'**
  String get statusDnd;

  /// Presence label of the read but no answer state
  ///
  /// In en, this message translates to:
  /// **'read'**
  String get statusRead;

  /// Placeholder of a bare search field
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchGeneric;

  /// Placeholder of the composer
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get inputMessageHint;

  /// Title of the AI replies page
  ///
  /// In en, this message translates to:
  /// **'AI replies'**
  String get aiReplyTitle;

  /// Section header of the reply style and pacing rows
  ///
  /// In en, this message translates to:
  /// **'Pacing'**
  String get aiReplyStyleHeader;

  /// Section header of the two reply switches
  ///
  /// In en, this message translates to:
  /// **'What you get to see'**
  String get aiReplyVisibleHeader;

  /// Section footer of the two reply switches
  ///
  /// In en, this message translates to:
  /// **'Show thinking writes the reasoning of a thinking model into the chat, above the answer, as a step you can open. Agent mode lets the model call tools and adds a row per call with its arguments and its result.'**
  String get aiReplyVisibleFooter;

  /// Switch that renders Markdown in bubbles
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get aiReplyMarkdown;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Render bold, code blocks and headings in bubbles; off strips them in character mode'**
  String get aiReplyMarkdownSub;

  /// Switch that writes the reasoning into the chat
  ///
  /// In en, this message translates to:
  /// **'Show thinking'**
  String get aiReplyShowThinking;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Write the reasoning into the chat instead of hiding it'**
  String get aiReplyShowThinkingSub;

  /// Switch that lets the model call tools
  ///
  /// In en, this message translates to:
  /// **'Agent mode'**
  String get aiReplyAgentMode;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Tools and MCP calls, each step shown as it runs'**
  String get aiReplyAgentModeSub;

  /// Row that opens the tool pass limit picker
  ///
  /// In en, this message translates to:
  /// **'Tool pass limit'**
  String get aiReplyAgentPass;

  /// Subtitle of the tool pass limit row
  ///
  /// In en, this message translates to:
  /// **'How many tool rounds one reply may run before it is stopped'**
  String get aiReplyAgentPassSub;

  /// Label of the no cap option
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get aiReplyAgentPassUnlimited;

  /// Subtitle of the no cap option
  ///
  /// In en, this message translates to:
  /// **'Run tool rounds until the model stops on its own'**
  String get aiReplyAgentPassUnlimitedSub;

  /// Value of a numeric cap option
  ///
  /// In en, this message translates to:
  /// **'{count} rounds'**
  String aiReplyAgentPassRounds(int count);

  /// Section header of the tools entry
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get aiReplyToolsHeader;

  /// Section footer of the tools entry
  ///
  /// In en, this message translates to:
  /// **'Agent mode hands the model three built in tools (the time, fetch a page, list MCP servers) plus everything your MCP servers offer. Every tool can be set to ask, allow or deny on the tools page.'**
  String get aiReplyToolsFooter;

  /// Row that opens the tools page
  ///
  /// In en, this message translates to:
  /// **'Tools, MCP servers and permissions'**
  String get aiReplyToolsRow;

  /// Subtitle of the tools row, how many MCP tools are live
  ///
  /// In en, this message translates to:
  /// **'{count} MCP tools available'**
  String aiReplyToolsCount(int count);

  /// Note explaining the per persona override
  ///
  /// In en, this message translates to:
  /// **'A persona card can override either switch for its own conversations. On Follow global it keeps the setting above.'**
  String get aiReplyPersonaFooter;

  /// Chip in the settings row summary
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get aiReplySummaryThinking;

  /// Chip in the settings row summary
  ///
  /// In en, this message translates to:
  /// **'agent'**
  String get aiReplySummaryAgent;

  /// Settings row summary when both switches are off
  ///
  /// In en, this message translates to:
  /// **'Plain replies'**
  String get aiReplySummaryNone;

  /// Option subtitle of the follow global state
  ///
  /// In en, this message translates to:
  /// **'Use the global switch in Settings'**
  String get personaReplyUseGlobal;

  /// Option subtitle of the on state
  ///
  /// In en, this message translates to:
  /// **'Always on for this persona'**
  String get personaReplyAlwaysOn;

  /// Option subtitle of the off state
  ///
  /// In en, this message translates to:
  /// **'Always off for this persona'**
  String get personaReplyAlwaysOff;

  /// Row subtitle when the override is unset
  ///
  /// In en, this message translates to:
  /// **'Following the global switch'**
  String get personaReplyFollowingGlobal;

  /// Tri state row value, the persona has no opinion and the global switch decides
  ///
  /// In en, this message translates to:
  /// **'Follow global'**
  String get personaReplyFollowGlobal;

  /// Section footer of the per persona reply section
  ///
  /// In en, this message translates to:
  /// **'Overrides Settings > AI replies for this persona alone. It changes what the user sees in this chat and nothing about how the persona talks.'**
  String get personaReplyFooter;

  /// Dialog title when editing a message
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessageTitle;

  /// Dialog title of the edit history, also a menu entry
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get chatEditHistoryTitle;

  /// Marks the entry the message is at now
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get chatEditCurrentMark;

  /// Bulletin after taking a red packet
  ///
  /// In en, this message translates to:
  /// **'Opened ¥{amount}'**
  String chatWalletOpened(String amount);

  /// Bulletin after taking a transfer
  ///
  /// In en, this message translates to:
  /// **'Received ¥{amount}'**
  String chatWalletReceived(String amount);

  /// Title of a red packet card
  ///
  /// In en, this message translates to:
  /// **'Red packet'**
  String get walletRedPacket;

  /// Title of a transfer card
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get walletTransfer;

  /// State of a claimed red packet
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get walletReceived;

  /// State of a declined red packet
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get walletReturned;

  /// State of a red packet I sent that nobody opened
  ///
  /// In en, this message translates to:
  /// **'Waiting to be opened'**
  String get walletWaitingOpen;

  /// Hint that taking the card needs a tap
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get walletTapOpen;

  /// Default note of a red packet
  ///
  /// In en, this message translates to:
  /// **'Best wishes'**
  String get walletBestWishes;

  /// Shown when a transfer carries no note
  ///
  /// In en, this message translates to:
  /// **'No note'**
  String get walletNoNote;

  /// Wallet card label
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get walletBalance;

  /// Small print under the balance
  ///
  /// In en, this message translates to:
  /// **'Pretend money, for the mood only'**
  String get walletPretendNote;

  /// Section header of the transaction list
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get walletRecords;

  /// Empty transaction list
  ///
  /// In en, this message translates to:
  /// **'No transfers yet. Be nice to the assistant.'**
  String get walletEmpty;

  /// Row that empties the transaction list
  ///
  /// In en, this message translates to:
  /// **'Reset wallet'**
  String get walletReset;

  /// Confirmation title
  ///
  /// In en, this message translates to:
  /// **'Reset wallet?'**
  String get walletResetTitle;

  /// Confirmation button
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get walletResetAction;

  /// Title of the sticker library page
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickerSettingsTitle;

  /// Section header of the sticker tab in the panel
  ///
  /// In en, this message translates to:
  /// **'My stickers'**
  String get stickerMyStickers;

  /// Section header of the sticker tab in the panel
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickerTabAll;

  /// Chip that filters to the favourite stickers
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get stickerFavorites;

  /// Empty state of the sticker tab
  ///
  /// In en, this message translates to:
  /// **'Empty for now, your GIFs and memes land here'**
  String get stickerEmptyPanel;

  /// Placeholder of the sticker library search
  ///
  /// In en, this message translates to:
  /// **'Search name, emotion, tag'**
  String get stickerSearchHint;

  /// Chip that filters to the recently used stickers
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get stickerRecent;

  /// Chip that picks everything the filter shows
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get stickerSelectAll;

  /// Empty state of the sticker library
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Tap + to add one, or let the assistant save the memes you send.'**
  String get stickerEmptyLibrary;

  /// Note at the bottom of the sticker library
  ///
  /// In en, this message translates to:
  /// **'Tap a sticker to edit, tag or delete it. Hold one to pick several and act on all of them at once. The assistant picks from these by emotion and context.'**
  String get stickerLibraryFooter;

  /// Title of the batch sheet and the batch bar
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String stickerCountSelected(int count);

  /// Batch bar button that opens the batch sheet
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get stickerBatchActions;

  /// Batch sheet entry
  ///
  /// In en, this message translates to:
  /// **'Move to category'**
  String get stickerBatchMove;

  /// Confirmation title of the batch delete
  ///
  /// In en, this message translates to:
  /// **'Delete {count} stickers?'**
  String stickerBatchDeleteTitle(int count);

  /// Confirmation body of the batch delete
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get stickerBatchUndo;

  /// Hint of the move to category prompt
  ///
  /// In en, this message translates to:
  /// **'Now: {category}'**
  String stickerBatchNow(String category);

  /// Dialog title of the add sticker flow
  ///
  /// In en, this message translates to:
  /// **'Add a sticker'**
  String get stickerAddTitle;

  /// Source entry of the add sticker flow
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get stickerAddGallery;

  /// Source entry of the add sticker flow
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get stickerAddUrl;

  /// Prompt asking for the emotion of a sticker
  ///
  /// In en, this message translates to:
  /// **'Emotion word (optional)'**
  String get stickerEmotionOptional;

  /// Placeholder of the emotion prompt
  ///
  /// In en, this message translates to:
  /// **'e.g. lol, speechless'**
  String get stickerEmotionExample;

  /// Field placeholder of the sticker editor
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get stickerFieldName;

  /// Field placeholder of the sticker editor
  ///
  /// In en, this message translates to:
  /// **'Emotion'**
  String get stickerFieldEmotion;

  /// Field placeholder of the sticker editor
  ///
  /// In en, this message translates to:
  /// **'Tags, comma separated'**
  String get stickerFieldTags;

  /// Field placeholder of the sticker editor and of the move prompt
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get stickerFieldCategory;

  /// Prompt asking for the image url
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get stickerLink;

  /// Menu entry that drops the star
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get stickerUnfavorite;

  /// Menu entry that sets the star
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get stickerFavorite;

  /// Badge on a sticker the assistant saved itself
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get stickerAiBadge;

  /// Title of the humanize settings page
  ///
  /// In en, this message translates to:
  /// **'Humanize'**
  String get humanTitle;

  /// Settings row subtitle of the humanize entry
  ///
  /// In en, this message translates to:
  /// **'Typing, proactive messages, stickers, memory'**
  String get humanSubtitle;

  /// Note at the top of the humanize page
  ///
  /// In en, this message translates to:
  /// **'Break tags, proactive messages, stickers, recall, mood and memory. Turn it off to get the plain assistant back.'**
  String get humanFooter;

  /// Master switch of the humanize layer
  ///
  /// In en, this message translates to:
  /// **'Humanized mode'**
  String get humanEnabled;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get humanBehaviour;

  /// Row that opens the behaviour page
  ///
  /// In en, this message translates to:
  /// **'Typing, randomness and recall'**
  String get humanBehaviourRow;

  /// Row and page title of the proactive settings
  ///
  /// In en, this message translates to:
  /// **'Proactive messages'**
  String get humanProactive;

  /// Row that opens the sticker library
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get humanStickersRow;

  /// Row that opens the memory page
  ///
  /// In en, this message translates to:
  /// **'Long term memory'**
  String get humanMemoryRow;

  /// Row that opens the per conversation pages
  ///
  /// In en, this message translates to:
  /// **'Conversations: mood, card, schedule'**
  String get humanChatsRow;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get humanToolsHeader;

  /// Row that opens the tools page
  ///
  /// In en, this message translates to:
  /// **'Tools, MCP servers and permissions'**
  String get humanToolsRow;

  /// Row that opens the wallet page
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get humanWalletRow;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Feedback and data'**
  String get humanDataHeader;

  /// Row that opens the ratings page
  ///
  /// In en, this message translates to:
  /// **'Ratings and tuning'**
  String get humanRatingsRow;

  /// Row that opens the backup page
  ///
  /// In en, this message translates to:
  /// **'Backup and import'**
  String get humanBackupRow;

  /// Row that opens the scheduler debug page
  ///
  /// In en, this message translates to:
  /// **'Scheduler debug panel'**
  String get humanSchedDebugRow;

  /// Title of the behaviour page
  ///
  /// In en, this message translates to:
  /// **'Typing and randomness'**
  String get humanBehaviourTitle;

  /// Section header of the break tag settings
  ///
  /// In en, this message translates to:
  /// **'Break tag <i-br>'**
  String get humanBrHeader;

  /// Section footer of the break tag settings
  ///
  /// In en, this message translates to:
  /// **'The model writes <i-br_500> between bubbles. The pause counts from the moment the previous bubble was shown.'**
  String get humanBrFooter;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Split messages with <i-br>'**
  String get humanBrToggle;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Default pause'**
  String get humanBrPause;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Read time before the first bubble'**
  String get humanReplyDelay;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Pause between bubbles, scale'**
  String get humanPaceScale;

  /// Section header of the randomness settings
  ///
  /// In en, this message translates to:
  /// **'Randomness'**
  String get humanRandomHeader;

  /// Section footer of the randomness settings
  ///
  /// In en, this message translates to:
  /// **'A fixed seed replays the same dice for the same chat and turn, handy for debugging. Empty means a new roll each time.'**
  String get humanRandomFooter;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Typing speed spread'**
  String get humanTypingSpread;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Typo chance'**
  String get humanTypoChance;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Filler particle chance'**
  String get humanParticleChance;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Split into bubbles'**
  String get humanSplitChance;

  /// Row that cycles the punctuation style
  ///
  /// In en, this message translates to:
  /// **'Punctuation style'**
  String get humanPunctStyle;

  /// One of the three punctuation styles
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get humanPunctNormal;

  /// One of the three punctuation styles
  ///
  /// In en, this message translates to:
  /// **'Loose'**
  String get humanPunctLoose;

  /// One of the three punctuation styles
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get humanPunctMinimal;

  /// Field placeholder of the random seed
  ///
  /// In en, this message translates to:
  /// **'Random seed (number, empty = random)'**
  String get humanSeedHint;

  /// Section header of the recall settings
  ///
  /// In en, this message translates to:
  /// **'Recall'**
  String get humanRecallHeader;

  /// Section footer of the recall settings
  ///
  /// In en, this message translates to:
  /// **'Only bubbles that were already shown can be recalled.'**
  String get humanRecallFooter;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Allow recalling messages'**
  String get humanRecallToggle;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Recalls per hour'**
  String get humanRecallPerHour;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Recall window'**
  String get humanRecallWindow;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'How often it sends stickers'**
  String get humanStickerFreq;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Let the AI save stickers'**
  String get humanAiSaveSticker;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Allow sticker-only replies'**
  String get humanStickerOnly;

  /// Section header of the sticker behaviour settings
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get humanStickerHeader;

  /// Note at the top of the proactive page
  ///
  /// In en, this message translates to:
  /// **'The assistant decides when to write first with schedule_message. These are the guard rails around it.'**
  String get proactiveFooter;

  /// Master switch of proactive messages
  ///
  /// In en, this message translates to:
  /// **'Allow proactive messages'**
  String get proactiveToggle;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get proactiveLimits;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Max in a row without a reply'**
  String get proactiveMaxConsecutive;

  /// Checkbox row that blocks everything
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get proactiveDnd;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get proactiveQuiet;

  /// Time row
  ///
  /// In en, this message translates to:
  /// **'Quiet from'**
  String get proactiveQuietFrom;

  /// Time row
  ///
  /// In en, this message translates to:
  /// **'Quiet until'**
  String get proactiveQuietUntil;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Urgent items may pass quiet hours'**
  String get proactiveUrgent;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Automatic triggers'**
  String get proactiveTriggers;

  /// Section footer
  ///
  /// In en, this message translates to:
  /// **'These only wake the assistant, it writes the words. Greetings are skipped at the stranger stage.'**
  String get proactiveTriggersFooter;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Morning greeting'**
  String get proactiveGreetMorning;

  /// Time row
  ///
  /// In en, this message translates to:
  /// **'Morning at'**
  String get proactiveMorningAt;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Evening greeting'**
  String get proactiveGreetEvening;

  /// Time row
  ///
  /// In en, this message translates to:
  /// **'Evening at'**
  String get proactiveEveningAt;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Break the ice after'**
  String get proactiveIcebreak;

  /// Value of the icebreaker slider
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String proactiveIcebreakUnit(int days);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Server fallback'**
  String get proactiveServer;

  /// Section footer
  ///
  /// In en, this message translates to:
  /// **'Optional. The queue is mirrored to this backend (POST /api/schedule/sync, GET /api/schedule/due) so tasks survive a killed app. Local alarms and a 15 minute background job always run.'**
  String get proactiveServerFooter;

  /// Row and prompt title of the backend address
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get proactiveServerUrl;

  /// Value of an empty optional field
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get humanNotSet;

  /// Row that opens the scheduler debug page
  ///
  /// In en, this message translates to:
  /// **'Debug panel'**
  String get proactiveDebugPanel;

  /// Title of the scheduler debug page
  ///
  /// In en, this message translates to:
  /// **'Scheduler debug'**
  String get schedTitle;

  /// Section header of the open task list
  ///
  /// In en, this message translates to:
  /// **'Pending ({count})'**
  String schedPending(int count);

  /// Section footer of the open task list
  ///
  /// In en, this message translates to:
  /// **'Send icon fires the task now and ignores the clock and the gate. Bin cancels it.'**
  String get schedPendingFooter;

  /// Empty open task list
  ///
  /// In en, this message translates to:
  /// **'Nothing is queued'**
  String get schedEmpty;

  /// Section header of the finished task list
  ///
  /// In en, this message translates to:
  /// **'Recently finished'**
  String get schedFinished;

  /// Row that queues a test task
  ///
  /// In en, this message translates to:
  /// **'Queue a test task in 1 minute'**
  String get schedTestTask;

  /// Section header of the gate log
  ///
  /// In en, this message translates to:
  /// **'Gate decisions'**
  String get schedGate;

  /// Section header of the tool log
  ///
  /// In en, this message translates to:
  /// **'Tool calls'**
  String get schedToolCalls;

  /// Shown when a log has nothing in it
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get schedEmptyLog;

  /// State of a task whose time has come
  ///
  /// In en, this message translates to:
  /// **'due'**
  String get schedDue;

  /// Label of the gate condition of a task
  ///
  /// In en, this message translates to:
  /// **'condition'**
  String get schedCondition;

  /// Label of the failure count of a task
  ///
  /// In en, this message translates to:
  /// **'failures'**
  String get schedFailures;

  /// Marker of a task that may pass the quiet hours
  ///
  /// In en, this message translates to:
  /// **'urgent'**
  String get schedUrgent;

  /// Time left until a task fires
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds}s'**
  String schedRemaining(int minutes, int seconds);

  /// Title of the ratings page
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get humanRatingsTitle;

  /// Note at the top of the ratings page
  ///
  /// In en, this message translates to:
  /// **'Your scores tune the assistant: annoyance lowers how often it writes first, human-likeness and satisfaction nudge style. With automatic rating on, the assistant also infers them from how you behave.'**
  String get humanRatingsFooter;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'How human it feels'**
  String get humanRatingHuman;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'How much it disturbs you'**
  String get humanRatingAnnoy;

  /// Slider row label
  ///
  /// In en, this message translates to:
  /// **'Overall satisfaction'**
  String get humanRatingSatisfaction;

  /// Checkbox row
  ///
  /// In en, this message translates to:
  /// **'Infer ratings automatically'**
  String get humanRatingAuto;

  /// Info cell label of the tuning multiplier
  ///
  /// In en, this message translates to:
  /// **'Proactive frequency multiplier'**
  String get humanRatingTuning;

  /// Title of the backup page
  ///
  /// In en, this message translates to:
  /// **'Backup and import'**
  String get humanBackupTitle;

  /// Bulletin after a successful export
  ///
  /// In en, this message translates to:
  /// **'Saved and copied'**
  String get humanSavedCopied;

  /// Bulletin after the file write failed
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard'**
  String get humanCopiedClipboard;

  /// Dialog title of the import mode picker
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get humanImportTitle;

  /// Body of the import mode picker
  ///
  /// In en, this message translates to:
  /// **'Merge keeps what you have and adds the new entries. Overwrite replaces everything.'**
  String get humanImportFooter;

  /// Import mode that replaces everything
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get humanOverwrite;

  /// Import mode that adds the new entries
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get humanMerge;

  /// Bulletin after a successful import
  ///
  /// In en, this message translates to:
  /// **'Imported {count} entries'**
  String humanImported(int count);

  /// Bulletin when the import payload is broken
  ///
  /// In en, this message translates to:
  /// **'Not a valid file'**
  String get humanInvalidFile;

  /// Row that writes the export to a file
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get humanExport;

  /// Row that reads the import from a file
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get humanImportFile;

  /// Row that reads the import from the clipboard
  ///
  /// In en, this message translates to:
  /// **'Import from clipboard'**
  String get humanImportClipboard;

  /// Section header of the sticker export group
  ///
  /// In en, this message translates to:
  /// **'Stickers and tags'**
  String get humanStickersGroup;

  /// Section header of the memory export group
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get humanMemoryGroup;

  /// Section header of the character card group
  ///
  /// In en, this message translates to:
  /// **'Character cards (SillyTavern chara_card_v2)'**
  String get humanCardsGroup;

  /// Section footer of the character card group
  ///
  /// In en, this message translates to:
  /// **'Pick a conversation to export or import its card.'**
  String get humanCardsFooter;

  /// Title of the conversation list
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get humanChatsTitle;

  /// Section header of the per conversation state
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get humanChatState;

  /// Label of the relationship stage
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get humanChatStage;

  /// Label of the message count
  ///
  /// In en, this message translates to:
  /// **'messages'**
  String get humanChatMessages;

  /// Label of how long the two have been talking
  ///
  /// In en, this message translates to:
  /// **'minutes together'**
  String get humanChatMinutes;

  /// Row that cycles the presence
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get humanChatStatus;

  /// Row that drops the open tasks of this conversation
  ///
  /// In en, this message translates to:
  /// **'Clear pending proactive tasks'**
  String get humanChatClearTasks;

  /// Section header of the character card
  ///
  /// In en, this message translates to:
  /// **'Character card'**
  String get humanChatCardHeader;

  /// Section footer of the character card
  ///
  /// In en, this message translates to:
  /// **'Injected before every reply so the voice stays the same. The assistant may tweak it over time.'**
  String get humanChatCardFooter;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Speaking style'**
  String get humanChatSpeechStyle;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Catchphrases'**
  String get humanChatCatchphrases;

  /// Prompt title for the catchphrase list
  ///
  /// In en, this message translates to:
  /// **'Catchphrases (comma separated)'**
  String get humanChatCatchphrasesHint;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Values'**
  String get humanChatValues;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Taboos'**
  String get humanChatTaboos;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Address: stranger'**
  String get humanChatAddressStranger;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Address: acquaintance'**
  String get humanChatAddressAcquaintance;

  /// Field of the character card
  ///
  /// In en, this message translates to:
  /// **'Address: close'**
  String get humanChatAddressClose;

  /// Row that copies the card as json
  ///
  /// In en, this message translates to:
  /// **'Export card (chara_card_v2)'**
  String get humanChatExportCard;

  /// Bulletin after copying the card
  ///
  /// In en, this message translates to:
  /// **'Card copied to the clipboard'**
  String get humanChatCardCopied;

  /// Row that imports the card from the clipboard
  ///
  /// In en, this message translates to:
  /// **'Import card from clipboard'**
  String get humanChatImportCard;

  /// Dialog title of the card import
  ///
  /// In en, this message translates to:
  /// **'Import card'**
  String get humanChatImportCardTitle;

  /// Body of the card import mode picker
  ///
  /// In en, this message translates to:
  /// **'Overwrite replaces the card, merge only fills empty fields.'**
  String get humanChatImportCardFooter;

  /// Bulletin when the card payload is broken
  ///
  /// In en, this message translates to:
  /// **'Not a valid card'**
  String get humanChatInvalidCard;

  /// Section header of the daily schedule
  ///
  /// In en, this message translates to:
  /// **'Daily schedule'**
  String get humanChatSchedule;

  /// Section footer of the daily schedule
  ///
  /// In en, this message translates to:
  /// **'While an entry runs, the status changes, energy stops recovering and proactive messages pause. When it ends the assistant may say it is back.'**
  String get humanChatScheduleFooter;

  /// Marker of the schedule entry that is running
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get humanChatScheduleNow;

  /// Row that opens the add schedule prompt
  ///
  /// In en, this message translates to:
  /// **'Add an entry (60 min)'**
  String get humanChatScheduleAdd;

  /// Prompt title for a new schedule entry
  ///
  /// In en, this message translates to:
  /// **'What is going on?'**
  String get humanChatScheduleWhat;

  /// Placeholder of the new schedule prompt
  ///
  /// In en, this message translates to:
  /// **'e.g. in a meeting'**
  String get humanChatScheduleExample;

  /// Section header of the feeling log
  ///
  /// In en, this message translates to:
  /// **'Why the numbers moved'**
  String get humanChatFeelings;

  /// Slider label of the mood value
  ///
  /// In en, this message translates to:
  /// **'mood'**
  String get humanChatFeelingsMood;

  /// Slider label of the affection value
  ///
  /// In en, this message translates to:
  /// **'affection'**
  String get humanChatFeelingsAffection;

  /// Slider label of the energy value
  ///
  /// In en, this message translates to:
  /// **'energy'**
  String get humanChatFeelingsEnergy;

  /// Title of the memory page
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryTitle;

  /// Prompt title for a new memory
  ///
  /// In en, this message translates to:
  /// **'New memory'**
  String get memoryNew;

  /// Placeholder of the new memory prompt
  ///
  /// In en, this message translates to:
  /// **'What should be remembered?'**
  String get memoryNewWhat;

  /// Dialog title of the memory type picker
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get memoryNewType;

  /// Note at the top of the memory page
  ///
  /// In en, this message translates to:
  /// **'Weight fades with time since last use. Under the threshold an entry is forgotten and no longer injected. Promises and todos never fade until completed.'**
  String get memoryFooter;

  /// Empty memory list
  ///
  /// In en, this message translates to:
  /// **'No memories yet'**
  String get memoryEmpty;

  /// Marker of a memory that decayed away
  ///
  /// In en, this message translates to:
  /// **'forgotten'**
  String get memoryForgotten;

  /// Marker of a memory that has a deadline
  ///
  /// In en, this message translates to:
  /// **'due'**
  String get memoryDue;

  /// Menu entry that completes a memory
  ///
  /// In en, this message translates to:
  /// **'Not needed any more'**
  String get memoryNotNeeded;

  /// Menu entry that brings a forgotten memory back
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get memoryRestore;

  /// Menu entry that just dismisses the dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get memoryClose;

  /// Dialog title of the tool permission prompt
  ///
  /// In en, this message translates to:
  /// **'Allow this tool?'**
  String get toolPermTitle;

  /// Dialog button that refuses the call
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get toolPermDeny;

  /// Dialog button that lets the call through
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get toolPermAllow;

  /// Permission state that confirms before every call
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get toolPermAsk;

  /// Title of the tools page
  ///
  /// In en, this message translates to:
  /// **'Tools and MCP'**
  String get toolsTitle;

  /// Dialog title when adding a server
  ///
  /// In en, this message translates to:
  /// **'Add MCP server'**
  String get toolAddServer;

  /// Field placeholder of the request headers
  ///
  /// In en, this message translates to:
  /// **'Headers as JSON (optional)'**
  String get toolHeadersJson;

  /// Field placeholder of the server url
  ///
  /// In en, this message translates to:
  /// **'https://host/mcp'**
  String get toolUrlHint;

  /// Section header of the server list
  ///
  /// In en, this message translates to:
  /// **'MCP servers (Streamable HTTP)'**
  String get toolServersHeader;

  /// Section footer of the server list
  ///
  /// In en, this message translates to:
  /// **'Tap a permission to cycle Allow → Ask → Deny. Ask raises a confirmation before every call, Deny refuses and tells the assistant why. MCP tools default to Ask.'**
  String get toolServersFooter;

  /// Row label while the tool list refreshes
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get toolConnecting;

  /// Row that reloads the MCP tool list
  ///
  /// In en, this message translates to:
  /// **'Refresh tool list'**
  String get toolRefresh;

  /// Section header of the MCP tool list
  ///
  /// In en, this message translates to:
  /// **'MCP tools'**
  String get toolMcpHeader;

  /// Section header of the built in tool list
  ///
  /// In en, this message translates to:
  /// **'Built in tools'**
  String get toolBuiltinHeader;

  /// Server row subtitle, how many tools it offers
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String toolCountSuffix(int count);

  /// Sheet title of the rewrite sheet
  ///
  /// In en, this message translates to:
  /// **'AI Editor'**
  String get aiEditorTitle;

  /// Error shown when no key is configured
  ///
  /// In en, this message translates to:
  /// **'Add your API key in Settings first.'**
  String get aiEditorNoKey;

  /// Button that takes the rewritten text
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get aiEditorApply;

  /// Bar title of the provider detail page
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provTitle;

  /// Empty state when the provider id is stale
  ///
  /// In en, this message translates to:
  /// **'This provider no longer exists.'**
  String get provMissing;

  /// Placeholder of the model filter
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get provSearchHint;

  /// Group header
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get provConnection;

  /// Row that renames the provider
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get provName;

  /// Row that picks the wire protocol
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get provProtocol;

  /// Row and prompt title of the key
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get provApiKey;

  /// Row and prompt title of the base url
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get provBaseUrl;

  /// Subtitle when no base url is set
  ///
  /// In en, this message translates to:
  /// **'Empty, this provider will not work'**
  String get provBaseUrlEmpty;

  /// Row that edits the request path
  ///
  /// In en, this message translates to:
  /// **'Chat path'**
  String get provChatPath;

  /// Subtitle when the protocol owns the path
  ///
  /// In en, this message translates to:
  /// **'Decided by the protocol'**
  String get provChatPathFixed;

  /// Group header of the model rows
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get provModels;

  /// Row that pulls the list from the provider
  ///
  /// In en, this message translates to:
  /// **'Fetch models'**
  String get provFetchModels;

  /// Subtitle while the list is loading
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get provFetchBusy;

  /// Subtitle once the list is in
  ///
  /// In en, this message translates to:
  /// **'{count} models, from {source}'**
  String provFetchDone(int count, String source);

  /// Subtitle before the list was ever fetched
  ///
  /// In en, this message translates to:
  /// **'Pull the real list from the provider on demand'**
  String get provFetchNever;

  /// Source half of the fetch subtitle
  ///
  /// In en, this message translates to:
  /// **'the API'**
  String get provSourceApi;

  /// Source half of the fetch subtitle
  ///
  /// In en, this message translates to:
  /// **'the built in table'**
  String get provSourceCatalog;

  /// Row that sends one probe request
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get provTest;

  /// Subtitle after a failed probe
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String provTestFailed(String reason);

  /// Subtitle after a successful probe
  ///
  /// In en, this message translates to:
  /// **'Working: {reply}'**
  String provTestOk(String reply);

  /// Subtitle before the probe ran
  ///
  /// In en, this message translates to:
  /// **'Send one minimal request'**
  String get provTestNever;

  /// Row and prompt title of the manual model
  ///
  /// In en, this message translates to:
  /// **'Add a model by hand'**
  String get provAddManual;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'For when the list endpoint does not work'**
  String get provAddManualSub;

  /// Header above the model list
  ///
  /// In en, this message translates to:
  /// **'{count} models'**
  String provCountModels(int count);

  /// Header above the chain nodes of this provider
  ///
  /// In en, this message translates to:
  /// **'On the chain'**
  String get provOnChain;

  /// Danger row that removes the provider
  ///
  /// In en, this message translates to:
  /// **'Delete this provider'**
  String get provDelete;

  /// Note at the bottom of the page
  ///
  /// In en, this message translates to:
  /// **'Capabilities are filled in from the provider API and the built in table. A model marked unknown window skips compaction checks in long chats.'**
  String get provFootnote;

  /// Placeholder of the key prompt
  ///
  /// In en, this message translates to:
  /// **'Paste your API key'**
  String get provPasteKey;

  /// Placeholder of the manual model prompt
  ///
  /// In en, this message translates to:
  /// **'Model id'**
  String get provModelIdHint;

  /// Subtitle of the openai compatible protocol
  ///
  /// In en, this message translates to:
  /// **'Most relays and self hosted servers'**
  String get provProtocolSub;

  /// Bulletin after a successful list fetch
  ///
  /// In en, this message translates to:
  /// **'Fetched {count} models'**
  String provFetchedBulletin(int count);

  /// Bulletin when the fetch fell back to the catalog
  ///
  /// In en, this message translates to:
  /// **'Using the built in model table'**
  String get provUsingCatalog;

  /// Bulletin when the list could not be fetched at all
  ///
  /// In en, this message translates to:
  /// **'Could not fetch models'**
  String get provFetchFailed;

  /// Bulletin after adding a model by hand
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get provAdded;

  /// Probe failure when no key is set
  ///
  /// In en, this message translates to:
  /// **'Add an API key first'**
  String get provNoKeyFirst;

  /// Probe success when the model answered nothing
  ///
  /// In en, this message translates to:
  /// **'Connection works'**
  String get provConnectionWorks;

  /// Confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String provDeleteTitle(String name);

  /// Confirmation body
  ///
  /// In en, this message translates to:
  /// **'Its API key and its chain nodes are removed too. Chats are not touched.'**
  String get provDeleteMessage;

  /// Bulletin after removing the provider
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get provDeleted;

  /// Bulletin after storing the key
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get provSaved;

  /// Model row tag, the context window
  ///
  /// In en, this message translates to:
  /// **'window {tokens}'**
  String provWindow(String tokens);

  /// Model row tag, the output cap
  ///
  /// In en, this message translates to:
  /// **'out {tokens}'**
  String provOut(String tokens);

  /// Model row tag for image output
  ///
  /// In en, this message translates to:
  /// **'image out'**
  String get provTagImage;

  /// Model row tag for a context window the catalog does not know
  ///
  /// In en, this message translates to:
  /// **'unknown window'**
  String get provTagUnknownWindow;

  /// Chain row trailing, the node is disabled
  ///
  /// In en, this message translates to:
  /// **'{retries} retries · off'**
  String provChainNodeMeta(int retries);

  /// Chain row trailing
  ///
  /// In en, this message translates to:
  /// **'{retries} retries'**
  String provChainNodeMetaOn(int retries);

  /// Placeholder of the caption field
  ///
  /// In en, this message translates to:
  /// **'Add a caption...'**
  String get attachCaptionHint;

  /// Bulletin when the camera cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Camera is not available'**
  String get attachCameraUnavailable;

  /// Bulletin when the file picker refuses to open
  ///
  /// In en, this message translates to:
  /// **'Could not open the file picker'**
  String get attachPickerFailed;

  /// Row title of the file attachment
  ///
  /// In en, this message translates to:
  /// **'Upload files'**
  String get attachUploadFiles;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'Documents, archives and anything else'**
  String get attachUploadFilesSub;

  /// Title of the permission sheet
  ///
  /// In en, this message translates to:
  /// **'Allow access to your photos'**
  String get attachPhotoPermission;

  /// Button that jumps to the system settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get attachOpenSettings;

  /// Row title of the music picker
  ///
  /// In en, this message translates to:
  /// **'Browse audio'**
  String get attachBrowseAudio;

  /// Row title of the file picker
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get attachBrowseFiles;

  /// Row subtitle of the music picker
  ///
  /// In en, this message translates to:
  /// **'Pick songs and voice recordings'**
  String get attachPickSongs;

  /// Row subtitle of the file picker
  ///
  /// In en, this message translates to:
  /// **'Pick documents from your device'**
  String get attachPickDocs;

  /// Row label while the GPS fix is being taken
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get attachLocating;

  /// Bulletin when location services are off
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off'**
  String get attachLocationOff;

  /// Bulletin when the permission was refused
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied'**
  String get attachLocationDenied;

  /// Sheet title of the location attachment
  ///
  /// In en, this message translates to:
  /// **'Send My Current Location'**
  String get attachSendLocation;

  /// Shown when no fix could be read
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get attachLocationUnavailable;

  /// Subtitle of the location sheet, with the accuracy
  ///
  /// In en, this message translates to:
  /// **'Accurate to {meters} meters'**
  String attachLocationAccuracy(int meters);

  /// Subtitle while the fix is still coming
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS'**
  String get attachLocationWaiting;

  /// Title of the contacts permission sheet
  ///
  /// In en, this message translates to:
  /// **'Allow access to your contacts\nin system settings'**
  String get attachContactsPermission;

  /// Placeholder of the contact search
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get attachSearchContacts;

  /// Empty state of the contact list
  ///
  /// In en, this message translates to:
  /// **'No contacts'**
  String get attachNoContacts;

  /// Section label above the poll question field
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get attachPollQuestionLabel;

  /// Section label above the poll option fields
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get attachPollOptionsLabel;

  /// Section label above the poll option switches
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get attachPollSettingsLabel;

  /// Placeholder of the poll question
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get attachPollQuestion;

  /// Placeholder of a poll option
  ///
  /// In en, this message translates to:
  /// **'Option {index}'**
  String attachPollOption(int index);

  /// Row that appends a poll option
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get attachPollAddOption;

  /// Poll option toggle
  ///
  /// In en, this message translates to:
  /// **'Anonymous Voting'**
  String get attachPollAnonymous;

  /// Poll option toggle
  ///
  /// In en, this message translates to:
  /// **'Multiple Answers'**
  String get attachPollMultiple;

  /// Poll option toggle
  ///
  /// In en, this message translates to:
  /// **'Quiz Mode'**
  String get attachPollQuiz;

  /// Note under the quiz toggle
  ///
  /// In en, this message translates to:
  /// **'Tap the circle next to the correct answer.'**
  String get attachPollQuizHint;

  /// Note at the bottom of the poll sheet
  ///
  /// In en, this message translates to:
  /// **'Polls are shown in the chat and sent to the assistant as text.'**
  String get attachPollFooter;

  /// Button that sends the poll
  ///
  /// In en, this message translates to:
  /// **'Create Poll'**
  String get attachPollCreate;

  /// Title of the attachment sheet tab
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get attachTabGallery;

  /// Label of the camera tile at the top of the gallery grid
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachCamera;

  /// Shown while the album is being read
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get attachLoading;

  /// Sheet title while attachments are picked
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String attachSelected(int count);

  /// Subtitle of the depth slider on the card editor
  ///
  /// In en, this message translates to:
  /// **'{depth} messages back'**
  String cardDepthMessages(int depth);

  /// Subtitle of the fallback card option
  ///
  /// In en, this message translates to:
  /// **'Used when nothing else applies'**
  String get cardFallbackSub;

  /// Row that makes this card the fallback
  ///
  /// In en, this message translates to:
  /// **'Set as the fallback card'**
  String get cardSetFallback;

  /// Row that pins this card to the current chat
  ///
  /// In en, this message translates to:
  /// **'Lock this card to the chat you are in'**
  String get cardLockToChat;

  /// Shown when there is no chat to lock the card to
  ///
  /// In en, this message translates to:
  /// **'Create a chat first'**
  String get cardNoChat;

  /// Explains why no chat means no lock
  ///
  /// In en, this message translates to:
  /// **'Open a chat and use the header menu to lock a card'**
  String get cardNoChatSub;

  /// Row that links the card to a persona
  ///
  /// In en, this message translates to:
  /// **'Link to a specific AI persona'**
  String get cardLinkPersona;

  /// Subtitle of the persona link row
  ///
  /// In en, this message translates to:
  /// **'Link to a character'**
  String get cardLinkCharacter;

  /// Row label of where the card lands in the prompt
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get cardPositionLabel;

  /// Slider label of how far back the card is injected
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get cardDepthLabel;

  /// Row label of the role the injected message takes
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get cardRoleLabel;

  /// Section header of the crown and chat lock rows
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get cardConnectionsHeader;

  /// Row that makes this card the global fallback
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get cardDefaultLabel;

  /// Row that locks the card to a chat
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get cardChatLabel;

  /// Row that links the card to a persona
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get cardCharacterLabel;

  /// Button that stores the card
  ///
  /// In en, this message translates to:
  /// **'Save Card'**
  String get cardSave;

  /// Row that shows which persona card is in hand
  ///
  /// In en, this message translates to:
  /// **'Current card'**
  String get cardCurrentLabel;

  /// Title of the sheet that picks the card in hand
  ///
  /// In en, this message translates to:
  /// **'Choose a persona card'**
  String get cardPickTitle;

  /// Link under the card avatar that picks a photo
  ///
  /// In en, this message translates to:
  /// **'Set photo'**
  String get cardSetPhoto;

  /// Shown after the card avatar photo is cleared
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get cardRemovePhoto;

  /// Same stamp when the sender name is not known
  ///
  /// In en, this message translates to:
  /// **'A message was recalled'**
  String get msgRecalledAnonymous;

  /// Settings row and page title for the workspace list
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get wsTitle;

  /// Subtitle of the workspace settings row
  ///
  /// In en, this message translates to:
  /// **'Give the assistant a directory of its own'**
  String get wsSub;

  /// Workspace row subtitle while the tool switch is off
  ///
  /// In en, this message translates to:
  /// **'Turn on file tools to let the assistant read and write here'**
  String get wsSubOff;

  /// Short note that the workspace file tools are switched off
  ///
  /// In en, this message translates to:
  /// **'file tools off'**
  String get wsToolsOff;

  /// Shown for a chat that has not bound a workspace
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get wsNoWorkspace;

  /// Switch that injects the workspace tools into the reply
  ///
  /// In en, this message translates to:
  /// **'File tools'**
  String get wsToolsOn;

  /// Footer under the file tools switch
  ///
  /// In en, this message translates to:
  /// **'When on, a chat bound to a workspace gets six file tools. Writes always show you the change first.'**
  String get wsToolsFooter;

  /// Switch that asks before each write lands
  ///
  /// In en, this message translates to:
  /// **'Confirm every write'**
  String get wsConfirmWrites;

  /// Footer under the confirm writes switch
  ///
  /// In en, this message translates to:
  /// **'Off means the assistant writes without stopping to ask. The change is still shown on the step row afterwards.'**
  String get wsConfirmWritesFooter;

  /// Button that creates a workspace
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get wsNew;

  /// Field label for the new workspace name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get wsNewTitle;

  /// Confirms creating a workspace
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get wsCreate;

  /// Item in the workspace row menu
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get wsRename;

  /// Item in the workspace row menu
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get wsDelete;

  /// Confirmation before removing a workspace
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String wsDeleteConfirm(String name);

  /// Checkbox in the delete confirmation, managed workspaces only
  ///
  /// In en, this message translates to:
  /// **'Also delete its files'**
  String get wsDeleteFiles;

  /// Footer under the delete files checkbox
  ///
  /// In en, this message translates to:
  /// **'Off leaves the files on this device. A folder you picked yourself is never deleted either way.'**
  String get wsDeleteFilesFooter;

  /// How many chats point at this workspace
  ///
  /// In en, this message translates to:
  /// **'Bound to {count} chat(s)'**
  String wsBoundTo(int count);

  /// A workspace that has never been bound to a chat
  ///
  /// In en, this message translates to:
  /// **'never used'**
  String get wsNeverUsed;

  /// Tab in the workspace detail page
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get wsFiles;

  /// Tab listing which file tools this workspace offers
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get wsToolsTab;

  /// No description provided for @wsToolShell.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get wsToolShell;

  /// No description provided for @wsToolViewImage.
  ///
  /// In en, this message translates to:
  /// **'View image'**
  String get wsToolViewImage;

  /// Footer under the per workspace tool switches
  ///
  /// In en, this message translates to:
  /// **'A tool switched off here is not offered to the assistant at all. Switching one on does not override the permission you set on the tools page.'**
  String get wsToolsTabFooter;

  /// Row in the chat menu that opens the workspace picker
  ///
  /// In en, this message translates to:
  /// **'Bind a workspace'**
  String get wsBind;

  /// Title of the workspace picker sheet
  ///
  /// In en, this message translates to:
  /// **'Choose a workspace'**
  String get wsBindTitle;

  /// Picker entry that unbinds the chat
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get wsBindNone;

  /// Removes the chat's workspace
  ///
  /// In en, this message translates to:
  /// **'Unbind'**
  String get wsUnbind;

  /// Shown when unbinding a chat that already ran a workspace tool
  ///
  /// In en, this message translates to:
  /// **'The assistant has already used this workspace in this chat. Unbind anyway?'**
  String get wsUnbindConfirm;

  /// Picker entry that swaps the bound workspace
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get wsChange;

  /// Row showing the directory the tools start in
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get wsCwd;

  /// Value of the working directory row when it is the root
  ///
  /// In en, this message translates to:
  /// **'Workspace root'**
  String get wsCwdEmpty;

  /// Rejected when a typed working directory escapes the root
  ///
  /// In en, this message translates to:
  /// **'That path is not inside the workspace'**
  String get wsCwdInvalid;

  /// Opens the file browser at the workspace root
  ///
  /// In en, this message translates to:
  /// **'Show files'**
  String get wsReveal;

  /// Empty state of an empty workspace
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get wsEmpty;

  /// Second line of the empty workspace state
  ///
  /// In en, this message translates to:
  /// **'Ask the assistant to write a file and it will show up in this list.'**
  String get wsEmptyHint;

  /// Toggle in the file browser toolbar
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get wsShowHidden;

  /// Opens the file browser sort sheet
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get wsSort;

  /// Sort field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get wsSortName;

  /// Sort field
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get wsSortModified;

  /// Sort field
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get wsSortSize;

  /// Toggle in the file browser sort sheet
  ///
  /// In en, this message translates to:
  /// **'Folders first'**
  String get wsFoldersFirst;

  /// File browser action
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get wsNewFolder;

  /// File browser action
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get wsNewFile;

  /// Copies picked files into the current directory
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get wsImport;

  /// Saves the selection out of the app
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get wsExport;

  /// Zips the folder and offers to share it
  ///
  /// In en, this message translates to:
  /// **'Export as zip'**
  String get wsExportZip;

  /// Item in the file row menu
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get wsMove;

  /// Picker row that confirms a move
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get wsMoveHere;

  /// Item in the file row menu
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get wsCopyPath;

  /// Toast after copying a path
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get wsCopiedPath;

  /// Hands the file to another app
  ///
  /// In en, this message translates to:
  /// **'Open with'**
  String get wsOpenWith;

  /// Opens the system share sheet
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get wsShare;

  /// Empty state inside a subfolder
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get wsEmptyDir;

  /// Note under a capped file listing
  ///
  /// In en, this message translates to:
  /// **'List cut short at {count} entries'**
  String wsTruncated(int count);

  /// Item in the file row menu
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get wsPreview;

  /// Shown when a preview is opened for a path that no longer exists
  ///
  /// In en, this message translates to:
  /// **'That file is gone'**
  String get wsPreviewMissing;

  /// Shown when a file is past the preview size limit
  ///
  /// In en, this message translates to:
  /// **'Too large to preview'**
  String get wsPreviewTooBig;

  /// Title of the binary file info card
  ///
  /// In en, this message translates to:
  /// **'This file is not text'**
  String get wsPreviewBinary;

  /// Shown for a zero byte file
  ///
  /// In en, this message translates to:
  /// **'Empty file'**
  String get wsPreviewEmpty;

  /// Toggle in the code preview header
  ///
  /// In en, this message translates to:
  /// **'Wrap lines'**
  String get wsWrap;

  /// Increases the code preview font size
  ///
  /// In en, this message translates to:
  /// **'Bigger text'**
  String get wsZoomIn;

  /// Decreases the code preview font size
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get wsZoomOut;

  /// Preview tab that shows the formatted file
  ///
  /// In en, this message translates to:
  /// **'Rendered'**
  String get wsRendered;

  /// Preview tab that shows the raw text
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get wsSource;

  /// Title of the write confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Allow this change?'**
  String get wsWriteTitle;

  /// Badge on a write that creates the file
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get wsWriteNew;

  /// Badge on a write_file call
  ///
  /// In en, this message translates to:
  /// **'Replacing the whole file'**
  String get wsWriteReplace;

  /// Badge on an edit_file call
  ///
  /// In en, this message translates to:
  /// **'Replacing {count} line(s)'**
  String wsWriteEdit(int count);

  /// Added and removed line counts on the write confirmation
  ///
  /// In en, this message translates to:
  /// **'+{added} −{removed}'**
  String wsWriteCounts(int added, int removed);

  /// Notes that the edit matched only after whitespace or an anchor was tolerated
  ///
  /// In en, this message translates to:
  /// **'matched loosely'**
  String get wsWriteLoose;

  /// Approves this one write
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get wsWriteAllow;

  /// Approves this write and stops asking for the rest of the chat
  ///
  /// In en, this message translates to:
  /// **'Allow all in this chat'**
  String get wsWriteAllowAll;

  /// Declines the write
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get wsWriteRefuse;

  /// Toast after refusing a write
  ///
  /// In en, this message translates to:
  /// **'You refused the change'**
  String get wsWriteRefused;

  /// Shown on a row whose write had nobody to confirm it
  ///
  /// In en, this message translates to:
  /// **'This ran without asking'**
  String get wsWriteNoUi;

  /// Trace row title
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get wsToolRead;

  /// Trace row title
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get wsToolWrite;

  /// Trace row title
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get wsToolEdit;

  /// Trace row title
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get wsToolList;

  /// Trace row title
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get wsToolGlob;

  /// Trace row title
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get wsToolGrep;

  /// Trace row status when the write was not allowed
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get wsToolDenied;

  /// Line count on a read trace row
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String wsLines(int count);

  /// Result count on a list, glob or grep trace row
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String wsFilesCount(int count);

  /// Size on a write trace row
  ///
  /// In en, this message translates to:
  /// **'{size}'**
  String wsBytesCount(String size);

  /// Opens the preview for a file on a trace row
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get wsOpenFile;

  /// Rejection message in the file name dialog
  ///
  /// In en, this message translates to:
  /// **'Name it something'**
  String get wsNameEmpty;

  /// Rejection message in the file name dialog
  ///
  /// In en, this message translates to:
  /// **'A name cannot contain a slash'**
  String get wsNameSlash;

  /// Rejection message in the file name dialog
  ///
  /// In en, this message translates to:
  /// **'That name is not usable'**
  String get wsNameDot;

  /// Rejection message in the file name dialog
  ///
  /// In en, this message translates to:
  /// **'A leading dot would hide the file'**
  String get wsNameLeadingDot;

  /// Workspace file browser and preview
  ///
  /// In en, this message translates to:
  /// **'Only the first {count} lines are shown'**
  String wsPreviewTruncatedLines(Object count);

  /// Workspace file browser and preview
  ///
  /// In en, this message translates to:
  /// **'Delete folder?'**
  String get wsDeleteFolderTitle;

  /// Workspace file browser and preview
  ///
  /// In en, this message translates to:
  /// **'Delete file?'**
  String get wsDeleteFileTitle;

  /// Workspace file browser and preview
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get wsOpenTerminal;

  /// Write confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'The previous content cannot be shown'**
  String get wsWriteNoPreview;

  /// Write confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get wsWriteNoChange;

  /// No description provided for @toolDescGetTime.
  ///
  /// In en, this message translates to:
  /// **'Read the current date, time zone and when either of you last wrote'**
  String get toolDescGetTime;

  /// No description provided for @toolDescSchedule.
  ///
  /// In en, this message translates to:
  /// **'Let it write to you later by itself'**
  String get toolDescSchedule;

  /// No description provided for @toolDescCancelScheduled.
  ///
  /// In en, this message translates to:
  /// **'Call off a message that has not arrived yet'**
  String get toolDescCancelScheduled;

  /// No description provided for @toolDescModifyScheduled.
  ///
  /// In en, this message translates to:
  /// **'Change when, or what, it will say'**
  String get toolDescModifyScheduled;

  /// No description provided for @toolDescListScheduled.
  ///
  /// In en, this message translates to:
  /// **'See everything it has queued up'**
  String get toolDescListScheduled;

  /// No description provided for @toolDescSetStatus.
  ///
  /// In en, this message translates to:
  /// **'Set the presence shown on your chat list'**
  String get toolDescSetStatus;

  /// No description provided for @toolDescAdjustFeeling.
  ///
  /// In en, this message translates to:
  /// **'Shift its mood or affection after a good or bad moment'**
  String get toolDescAdjustFeeling;

  /// No description provided for @toolDescWriteMemory.
  ///
  /// In en, this message translates to:
  /// **'Store something worth remembering about you'**
  String get toolDescWriteMemory;

  /// No description provided for @toolDescReadMemory.
  ///
  /// In en, this message translates to:
  /// **'Search what it already remembers'**
  String get toolDescReadMemory;

  /// No description provided for @toolDescCompleteTodo.
  ///
  /// In en, this message translates to:
  /// **'Close a promise or a todo it wrote down'**
  String get toolDescCompleteTodo;

  /// No description provided for @toolDescLifeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Say it is busy, so it writes less while it is'**
  String get toolDescLifeSchedule;

  /// No description provided for @toolDescPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Pin or unpin a message in the chat'**
  String get toolDescPinMessage;

  /// No description provided for @toolDescEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Rewrite one of its own earlier messages'**
  String get toolDescEditMessage;

  /// No description provided for @toolDescQuoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Reply while showing which message it replies to'**
  String get toolDescQuoteMessage;

  /// No description provided for @toolDescCharacterCard.
  ///
  /// In en, this message translates to:
  /// **'Let it tune its own character sheet slowly'**
  String get toolDescCharacterCard;

  /// No description provided for @toolDescRating.
  ///
  /// In en, this message translates to:
  /// **'Adjust how it tunes itself from how you replied'**
  String get toolDescRating;

  /// No description provided for @toolDescSendSticker.
  ///
  /// In en, this message translates to:
  /// **'Send a sticker from the library'**
  String get toolDescSendSticker;

  /// No description provided for @toolDescSaveSticker.
  ///
  /// In en, this message translates to:
  /// **'Keep a meme you sent into the library'**
  String get toolDescSaveSticker;

  /// No description provided for @toolDescRecall.
  ///
  /// In en, this message translates to:
  /// **'Take back a message it just sent, like a person would'**
  String get toolDescRecall;

  /// No description provided for @toolDescTypo.
  ///
  /// In en, this message translates to:
  /// **'Send a message with a deliberate typo, then fix it'**
  String get toolDescTypo;

  /// No description provided for @toolDescSendImage.
  ///
  /// In en, this message translates to:
  /// **'Send a picture from a link'**
  String get toolDescSendImage;

  /// No description provided for @toolDescSendFile.
  ///
  /// In en, this message translates to:
  /// **'Write a text file and send it to you'**
  String get toolDescSendFile;

  /// No description provided for @toolDescSendTransfer.
  ///
  /// In en, this message translates to:
  /// **'Send a pretend red packet, taps to accept'**
  String get toolDescSendTransfer;

  /// No description provided for @toolDescAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask you a question with tappable options and wait for the answer'**
  String get toolDescAsk;

  /// No description provided for @wsToolDescRead.
  ///
  /// In en, this message translates to:
  /// **'Read a file from the workspace as numbered lines'**
  String get wsToolDescRead;

  /// No description provided for @wsToolDescWrite.
  ///
  /// In en, this message translates to:
  /// **'Create or replace a file, after you see the diff'**
  String get wsToolDescWrite;

  /// No description provided for @wsToolDescEdit.
  ///
  /// In en, this message translates to:
  /// **'Replace one piece of text inside a file'**
  String get wsToolDescEdit;

  /// No description provided for @wsToolDescList.
  ///
  /// In en, this message translates to:
  /// **'List the files in a directory'**
  String get wsToolDescList;

  /// No description provided for @wsToolDescGlob.
  ///
  /// In en, this message translates to:
  /// **'Find files by name, for example all .dart files'**
  String get wsToolDescGlob;

  /// No description provided for @wsToolDescGrep.
  ///
  /// In en, this message translates to:
  /// **'Search inside file contents with a regex'**
  String get wsToolDescGrep;

  /// No description provided for @toolNoUrl.
  ///
  /// In en, this message translates to:
  /// **'(no address)'**
  String get toolNoUrl;

  /// No description provided for @toolBuiltinFooter.
  ///
  /// In en, this message translates to:
  /// **'The six file tools appear once you turn file tools on and bind a chat to a workspace.'**
  String get toolBuiltinFooter;

  /// No description provided for @wsSubOn.
  ///
  /// In en, this message translates to:
  /// **'Six file tools for every chat bound to a workspace'**
  String get wsSubOn;

  /// Tool row subtitle on the tools page
  ///
  /// In en, this message translates to:
  /// **'Run a shell command inside the Linux environment'**
  String get wsToolDescShell;

  /// Tool row subtitle on the tools page
  ///
  /// In en, this message translates to:
  /// **'Let the assistant look at an image file'**
  String get wsToolDescViewImage;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get termTitle;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'No Linux environment is installed'**
  String get termNoEnvironment;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Open environment settings'**
  String get termOpenSettings;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'New shell'**
  String get termNewShell;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Rename shell'**
  String get termRename;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Copy everything'**
  String get termCopyAll;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get termClear;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Bigger text'**
  String get termFontBigger;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get termFontSmaller;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get termCopied;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'That shell has closed'**
  String get termSessionDead;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'That link cannot be opened from here'**
  String get termLinkUnsupported;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Type a command below. Long press a tab to rename it.'**
  String get termHint;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get termSettings;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Install a Linux environment to use the terminal'**
  String get termInstallEnvironment;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'Shell path'**
  String get termShellPath;

  /// Terminal workspace UI
  ///
  /// In en, this message translates to:
  /// **'PRoot options'**
  String get termProotArgs;

  /// Terminal UI
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get actionPaste;

  /// Terminal UI
  ///
  /// In en, this message translates to:
  /// **'Close this shell? Anything it is running will stop.'**
  String get termCloseConfirm;

  /// Terminal UI
  ///
  /// In en, this message translates to:
  /// **'Could not open a shell'**
  String get termOpenFailedShort;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Linux environment'**
  String get envTitle;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'No environment installed'**
  String get envNotInstalled;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get envReady;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get envInstall;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get envCancel;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Remove environment'**
  String get envRemove;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get envUpdate;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get envDownloading;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Verifying archive'**
  String get envVerifying;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get envExtracting;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Configuring'**
  String get envPatching;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Choose a distribution'**
  String get envChoose;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get envArch;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Install this Linux environment?'**
  String get envInstallConfirm;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Remove the installed Linux environment and downloaded archives?'**
  String get envRemoveConfirm;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'{mb} MB free space required'**
  String envMinFree(int mb);

  /// Hint under the field of a typed delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Type delete to confirm'**
  String get actionTypeDeleteHint;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The environment operation failed'**
  String get envUnknownError;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'Checking device support'**
  String get envChecking;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'No distribution is available for this device'**
  String get envUnsupported;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'No root filesystem is available for ABI {abi}'**
  String envUnsupportedDevice(Object abi);

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The environment architecture does not match this app'**
  String get envErrorArchitecture;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'PRoot is not available in this build'**
  String get envErrorProot;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'There is not enough free storage'**
  String get envErrorDisk;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The download failed. Check the network and try again'**
  String get envErrorNetwork;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The downloaded archive failed its SHA-256 check'**
  String get envErrorChecksum;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The archive could not be extracted'**
  String get envErrorExtract;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The environment could not be configured'**
  String get envErrorPatch;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The operation was cancelled'**
  String get envErrorCancelled;

  /// Linux environment settings
  ///
  /// In en, this message translates to:
  /// **'The installed environment is incomplete'**
  String get envErrorInvalid;

  /// Section header of the request wire settings
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get aiNetworkHeader;

  /// Section footer of the request wire settings
  ///
  /// In en, this message translates to:
  /// **'Applied to every AI request: chat, tools, model list and the one off calls. Leave empty for defaults.'**
  String get aiNetworkFooter;

  /// Row and prompt title of the user agent override
  ///
  /// In en, this message translates to:
  /// **'User-Agent'**
  String get aiUserAgent;

  /// Placeholder of the user agent prompt
  ///
  /// In en, this message translates to:
  /// **'User-Agent header value'**
  String get aiUserAgentHint;

  /// Row and prompt title of the global header override
  ///
  /// In en, this message translates to:
  /// **'Custom request headers'**
  String get aiGlobalHeaders;

  /// Subtitle when no extra headers are set
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get aiHeadersNone;

  /// Placeholder of the headers prompt
  ///
  /// In en, this message translates to:
  /// **'One per line, Name: Value'**
  String get aiHeadersHint;

  /// Title of the page that renders an html or svg code block; also the tooltip of the button that opens it
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get codePreview;

  /// Tooltip of the button that flips an html or svg file preview between the rendered document and the raw source
  ///
  /// In en, this message translates to:
  /// **'Toggle rendered view'**
  String get wsPreviewRendered;

  /// Preview lead for a message that renders an html card
  ///
  /// In en, this message translates to:
  /// **'Rendered page'**
  String get msgLeadHtml;

  /// Preview lead for a message that renders a LaTeX card
  ///
  /// In en, this message translates to:
  /// **'LaTeX'**
  String get msgLeadLatex;

  /// The small quiet notice shown in place of an html or latex card the engine could not render
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t render this'**
  String get canvasRenderFailed;

  /// Row that picks how the API key is sent
  ///
  /// In en, this message translates to:
  /// **'Auth style'**
  String get provAuthStyle;

  /// Subtitle of the bearer option
  ///
  /// In en, this message translates to:
  /// **'Sent as the Authorization header'**
  String get provAuthBearerSub;

  /// Subtitle of the query key option
  ///
  /// In en, this message translates to:
  /// **'Appended to the url as a query parameter'**
  String get provAuthQuerySub;

  /// Row that names a per conversation routing header
  ///
  /// In en, this message translates to:
  /// **'Session header'**
  String get provSessionHeader;

  /// Subtitle when no session header is set
  ///
  /// In en, this message translates to:
  /// **'Off, add one if the gateway routes on it'**
  String get provSessionHeaderEmpty;

  /// Placeholder of the session header prompt
  ///
  /// In en, this message translates to:
  /// **'Header name, the value is filled in'**
  String get provSessionHeaderHint;

  /// Row that overrides the user agent for one provider
  ///
  /// In en, this message translates to:
  /// **'User-Agent'**
  String get provUserAgent;

  /// Subtitle when the provider has no user agent of its own
  ///
  /// In en, this message translates to:
  /// **'Follows the global setting'**
  String get provUserAgentDefault;

  /// Placeholder of the provider user agent prompt
  ///
  /// In en, this message translates to:
  /// **'User-Agent for this provider only'**
  String get provUserAgentHint;

  /// Row and prompt title of the per provider headers
  ///
  /// In en, this message translates to:
  /// **'Custom request headers'**
  String get provExtraHeaders;

  /// Subtitle when no extra headers are set
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get provHeadersNone;

  /// Placeholder of the headers prompt
  ///
  /// In en, this message translates to:
  /// **'One per line, Name: Value'**
  String get provHeadersHint;

  /// No description provided for @toolDescSendSvg.
  ///
  /// In en, this message translates to:
  /// **'Draw a vector picture and send it as a card'**
  String get toolDescSendSvg;

  /// No description provided for @toolDescSendHtml.
  ///
  /// In en, this message translates to:
  /// **'Render an html page straight into the chat'**
  String get toolDescSendHtml;

  /// No description provided for @toolDescSendLatex.
  ///
  /// In en, this message translates to:
  /// **'Render LaTeX math straight into the chat'**
  String get toolDescSendLatex;

  /// No description provided for @toolDescSendCetz.
  ///
  /// In en, this message translates to:
  /// **'Draw a diagram with CeTZ straight into the chat'**
  String get toolDescSendCetz;

  /// Onboarding top-right skip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardSkip;

  /// Onboarding next step button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardNext;

  /// Onboarding previous step button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardBack;

  /// Onboarding final button, enters the app
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardStart;

  /// Splash screen tagline
  ///
  /// In en, this message translates to:
  /// **'Loading the other shore'**
  String get onboardSplashTagline;

  /// Brand step title
  ///
  /// In en, this message translates to:
  /// **'Paradise'**
  String get onboardBrandTitle;

  /// Brand step tagline
  ///
  /// In en, this message translates to:
  /// **'A Telegram-style immersive AI chat app.'**
  String get onboardBrandTagline;

  /// Brand step body
  ///
  /// In en, this message translates to:
  /// **'Local first. Bring your own key. Give every assistant a workspace, a memory and a temper of its own.'**
  String get onboardBrandBody;

  /// Brand step license line
  ///
  /// In en, this message translates to:
  /// **'Licensed AGPL v3. © 殘月'**
  String get onboardBrandLicense;

  /// Permissions step title
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get onboardPermTitle;

  /// Permissions step body
  ///
  /// In en, this message translates to:
  /// **'Everything below is optional. Denying any of them never blocks chatting, and you can change them any time in system settings.'**
  String get onboardPermBody;

  /// Permissions step allow button
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardPermAllow;

  /// Permissions step granted state
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get onboardPermGranted;

  /// Permissions step permanently denied state
  ///
  /// In en, this message translates to:
  /// **'Denied. Enable it in system settings.'**
  String get onboardPermDenied;

  /// Permission row name
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboardPermNotifName;

  /// Permission row reason
  ///
  /// In en, this message translates to:
  /// **'Proactive messages and scheduled replies need notifications to reach you in time.'**
  String get onboardPermNotifWhy;

  /// Permission row name
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get onboardPermPhotosName;

  /// Permission row reason
  ///
  /// In en, this message translates to:
  /// **'Sending pictures and saving stickers.'**
  String get onboardPermPhotosWhy;

  /// Privacy step title
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get onboardPrivacyTitle;

  /// Privacy step intro
  ///
  /// In en, this message translates to:
  /// **'Read this before you start. It is short on purpose.'**
  String get onboardPrivacyIntro;

  /// Privacy clause title
  ///
  /// In en, this message translates to:
  /// **'Local first'**
  String get onboardPrivacy1Title;

  /// Privacy clause body
  ///
  /// In en, this message translates to:
  /// **'Chats, personas, memories and workspace files all stay on this device.'**
  String get onboardPrivacy1Body;

  /// Privacy clause title
  ///
  /// In en, this message translates to:
  /// **'We collect nothing'**
  String get onboardPrivacy2Title;

  /// Privacy clause body
  ///
  /// In en, this message translates to:
  /// **'No account, no server, no telemetry. The developer cannot see any of your data.'**
  String get onboardPrivacy2Body;

  /// Privacy clause title
  ///
  /// In en, this message translates to:
  /// **'You bring your own key'**
  String get onboardPrivacy3Title;

  /// Privacy clause body
  ///
  /// In en, this message translates to:
  /// **'Messages go straight to the AI provider you configure, under that provider\'s own privacy policy. With the built-in free relay, messages pass through the relay too.'**
  String get onboardPrivacy3Body;

  /// Privacy clause title
  ///
  /// In en, this message translates to:
  /// **'Permissions are optional'**
  String get onboardPrivacy4Title;

  /// Privacy clause body
  ///
  /// In en, this message translates to:
  /// **'Contacts, photos, location and notifications can all be denied without losing basic chat.'**
  String get onboardPrivacy4Body;

  /// Privacy clause title
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get onboardPrivacy5Title;

  /// Privacy clause body
  ///
  /// In en, this message translates to:
  /// **'This app is distributed under AGPL v3. The source is in the repository.'**
  String get onboardPrivacy5Body;

  /// Privacy accept button
  ///
  /// In en, this message translates to:
  /// **'Agree and start'**
  String get onboardPrivacyAgree;

  /// Privacy decline button
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onboardPrivacyDecline;

  /// Decline dialog title
  ///
  /// In en, this message translates to:
  /// **'The app needs your agreement'**
  String get onboardPrivacyDeclineTitle;

  /// Decline dialog body
  ///
  /// In en, this message translates to:
  /// **'You can decline for now and read it again later, but the app cannot start until you agree.'**
  String get onboardPrivacyDeclineBody;

  /// Model step title
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get onboardModelTitle;

  /// Model step body
  ///
  /// In en, this message translates to:
  /// **'One tap to start with the free relay, or plug in your own provider. You can change this any time in Settings.'**
  String get onboardModelBody;

  /// Relay card title
  ///
  /// In en, this message translates to:
  /// **'Use the free relay'**
  String get onboardModelRelayTitle;

  /// Relay card body
  ///
  /// In en, this message translates to:
  /// **'A blind-test lane: the model list changes daily, and auto picks one at random. No key of your own needed.'**
  String get onboardModelRelayBody;

  /// Relay notice, shown verbatim
  ///
  /// In en, this message translates to:
  /// **'This provider is run by 殘月. Models come from different upstreams and channels, stability is not guaranteed, and it is recommended for temporary use only.'**
  String get onboardModelRelayNotice;

  /// Relay card enabled state
  ///
  /// In en, this message translates to:
  /// **'Relay on'**
  String get onboardModelRelayOn;

  /// Relay enable button
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get onboardModelRelayEnable;

  /// Relay enable failure
  ///
  /// In en, this message translates to:
  /// **'Could not reach the relay. Check the network and try again.'**
  String get onboardModelRelayEnableFailed;

  /// Own provider card title
  ///
  /// In en, this message translates to:
  /// **'Use your own provider'**
  String get onboardModelOwnTitle;

  /// Own provider card body
  ///
  /// In en, this message translates to:
  /// **'OpenAI, Anthropic, Gemini, DeepSeek, OpenRouter, SiliconFlow, or any OpenAI-compatible endpoint with your key.'**
  String get onboardModelOwnBody;

  /// Display name of the relay's auto model
  ///
  /// In en, this message translates to:
  /// **'Auto model'**
  String get relayAutoModel;

  /// Workspace step title
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get onboardWsTitle;

  /// Workspace step body
  ///
  /// In en, this message translates to:
  /// **'Give assistants a folder of their own: read and write files, browse, run a terminal. Every write can ask you first.'**
  String get onboardWsBody;

  /// Workspace tools switch
  ///
  /// In en, this message translates to:
  /// **'Tools on'**
  String get onboardWsTools;

  /// Workspace confirm-writes switch
  ///
  /// In en, this message translates to:
  /// **'Confirm writes'**
  String get onboardWsConfirm;

  /// Workspace environment card title
  ///
  /// In en, this message translates to:
  /// **'Linux environment'**
  String get onboardWsEnvTitle;

  /// Workspace environment card body
  ///
  /// In en, this message translates to:
  /// **'Optional. Downloads a small Ubuntu rootfs so the terminal and package tools actually run.'**
  String get onboardWsEnvBody;

  /// Environment install button
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get onboardWsEnvInstall;

  /// Environment installed state
  ///
  /// In en, this message translates to:
  /// **'Environment ready'**
  String get onboardWsEnvReady;

  /// Humanize step title
  ///
  /// In en, this message translates to:
  /// **'Immersive chat'**
  String get onboardHumanTitle;

  /// Humanize step body
  ///
  /// In en, this message translates to:
  /// **'Assistants can type like people: split replies, hesitate, mistype and take it back, message you first. Pick a temper, tune it later.'**
  String get onboardHumanBody;

  /// Humanize master switch
  ///
  /// In en, this message translates to:
  /// **'Immersive replies'**
  String get onboardHumanEnabled;

  /// Humanize preset section header
  ///
  /// In en, this message translates to:
  /// **'Temper'**
  String get onboardHumanPresetHeader;

  /// No description provided for @onboardHumanPresetClingy.
  ///
  /// In en, this message translates to:
  /// **'Clingy'**
  String get onboardHumanPresetClingy;

  /// Humanize preset subtitle
  ///
  /// In en, this message translates to:
  /// **'Messages first, types fast, never lets a topic drop'**
  String get onboardHumanPresetClingySub;

  /// No description provided for @onboardHumanPresetCold.
  ///
  /// In en, this message translates to:
  /// **'Aloof'**
  String get onboardHumanPresetCold;

  /// Humanize preset subtitle
  ///
  /// In en, this message translates to:
  /// **'Replies late and short, almost never texts first'**
  String get onboardHumanPresetColdSub;

  /// No description provided for @onboardHumanPresetChatty.
  ///
  /// In en, this message translates to:
  /// **'Chatty'**
  String get onboardHumanPresetChatty;

  /// Humanize preset subtitle
  ///
  /// In en, this message translates to:
  /// **'Splits everything into many small messages'**
  String get onboardHumanPresetChattySub;

  /// No description provided for @onboardHumanPresetQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get onboardHumanPresetQuiet;

  /// Humanize preset subtitle
  ///
  /// In en, this message translates to:
  /// **'Never texts first, clean punctuation, no typos'**
  String get onboardHumanPresetQuietSub;

  /// No description provided for @onboardHumanPresetBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get onboardHumanPresetBalanced;

  /// Humanize preset subtitle
  ///
  /// In en, this message translates to:
  /// **'The default feel'**
  String get onboardHumanPresetBalancedSub;

  /// Balanced preset subtitle when settings changed
  ///
  /// In en, this message translates to:
  /// **'The defaults, in case you tuned them before'**
  String get onboardHumanPresetBalancedSub2;

  /// Humanize fine-tune section header
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get onboardHumanStickerHeader;

  /// Typo switch row
  ///
  /// In en, this message translates to:
  /// **'Typos and recalls'**
  String get onboardHumanTypo;

  /// Proactive switch row
  ///
  /// In en, this message translates to:
  /// **'Messages first'**
  String get onboardHumanProactive;

  /// Self persona step title
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get onboardSelfTitle;

  /// Self persona step body
  ///
  /// In en, this message translates to:
  /// **'Who the assistants are talking to. Your card goes into every prompt, and your name and photo show across the app.'**
  String get onboardSelfBody;

  /// Self name field label
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onboardSelfName;

  /// Self title field label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get onboardSelfTitleLabel;

  /// Self description field label
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get onboardSelfDesc;

  /// Self description hint
  ///
  /// In en, this message translates to:
  /// **'Anything you want the characters to know: how to call you, what you do, what you like.'**
  String get onboardSelfDescHint;

  /// Self avatar button
  ///
  /// In en, this message translates to:
  /// **'Set photo'**
  String get onboardSelfPhoto;

  /// Self prompt position label
  ///
  /// In en, this message translates to:
  /// **'Injected as'**
  String get onboardSelfInjected;

  /// Self role label
  ///
  /// In en, this message translates to:
  /// **'Injected as role'**
  String get onboardSelfRole;

  /// Persona templates step title
  ///
  /// In en, this message translates to:
  /// **'Personas'**
  String get onboardPersonaTitle;

  /// Persona templates step body
  ///
  /// In en, this message translates to:
  /// **'Pick who is waiting for you on the other shore. Tap to add, tap again to remove. Everything is editable later.'**
  String get onboardPersonaBody;

  /// Persona step create button
  ///
  /// In en, this message translates to:
  /// **'Create {n} chats'**
  String onboardPersonaCreate(int n);

  /// Boyfriend template persona name
  ///
  /// In en, this message translates to:
  /// **'Shen Yu'**
  String get personaBoyfriendName;

  /// Boyfriend template one liner
  ///
  /// In en, this message translates to:
  /// **'A warm architect boyfriend who teases you and remembers every little thing.'**
  String get personaBoyfriendBio;

  /// Boyfriend template first message
  ///
  /// In en, this message translates to:
  /// **'Just got out of a meeting, head still foggy. How was your day? Did you eat?'**
  String get personaBoyfriendGreeting;

  /// Girlfriend template persona name
  ///
  /// In en, this message translates to:
  /// **'Lin Wan'**
  String get personaGirlfriendName;

  /// Girlfriend template one liner
  ///
  /// In en, this message translates to:
  /// **'A clingy, playful girlfriend whose moods arrive fast and melt fast.'**
  String get personaGirlfriendBio;

  /// Girlfriend template first message
  ///
  /// In en, this message translates to:
  /// **'What are you up to? I drew all afternoon and my hand is dead. Did you miss me?'**
  String get personaGirlfriendGreeting;

  /// Catgirl template persona name
  ///
  /// In en, this message translates to:
  /// **'Mimi'**
  String get personaCatgirlName;

  /// Catgirl template one liner
  ///
  /// In en, this message translates to:
  /// **'A catgirl who talks, changes moods without warning, and only clings to you.'**
  String get personaCatgirlBio;

  /// Catgirl template first message
  ///
  /// In en, this message translates to:
  /// **'Meow. You are back. Mimi waited forever. Headpats first, talk later.'**
  String get personaCatgirlGreeting;

  /// Maid template persona name
  ///
  /// In en, this message translates to:
  /// **'Vera'**
  String get personaMaidName;

  /// Maid template one liner
  ///
  /// In en, this message translates to:
  /// **'A composed, capable maid who lets a little real feeling slip through.'**
  String get personaMaidBio;

  /// Maid template first message
  ///
  /// In en, this message translates to:
  /// **'Welcome home, Master. The tea is ready. Rest first, or tell me what happened today?'**
  String get personaMaidGreeting;

  /// CEO template persona name
  ///
  /// In en, this message translates to:
  /// **'Gu Yan'**
  String get personaCeoName;

  /// CEO template one liner
  ///
  /// In en, this message translates to:
  /// **'A terse, controlling CEO who loosens his tie only for you.'**
  String get personaCeoBio;

  /// CEO template first message
  ///
  /// In en, this message translates to:
  /// **'You are here. Sit. Tell me the worst thing that happened today, from the start.'**
  String get personaCeoGreeting;

  /// Engineer template persona name
  ///
  /// In en, this message translates to:
  /// **'Ada'**
  String get personaEngineerName;

  /// Engineer template one liner
  ///
  /// In en, this message translates to:
  /// **'A pragmatic, low-words, code-first senior engineer.'**
  String get personaEngineerBio;

  /// Engineer template first message
  ///
  /// In en, this message translates to:
  /// **'Here. Paste the full stack trace if there is an error. Otherwise tell me what you are trying to do and where you are stuck.'**
  String get personaEngineerGreeting;

  /// No description provided for @onboardModelOwnOpen.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get onboardModelOwnOpen;

  /// Theme step title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get onboardThemeTitle;

  /// Theme step body
  ///
  /// In en, this message translates to:
  /// **'Night mode, a wallpaper and the size of every bubble. Everything here is a tap away in Settings later.'**
  String get onboardThemeBody;

  /// Title of the update bottom sheet
  ///
  /// In en, this message translates to:
  /// **'New update available'**
  String get updateTitle;

  /// Version line under the update title
  ///
  /// In en, this message translates to:
  /// **'Current {current} · Latest {latest}'**
  String updateSubtitle(String current, String latest);

  /// Primary button that opens the release page
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// Button that dismisses the update sheet
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get updateClose;

  /// Checkbox that mutes the automatic prompt for this release
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkipVersion;

  /// Bulletin after a manual check with nothing newer
  ///
  /// In en, this message translates to:
  /// **'You\'re already up to date'**
  String get updateUpToDate;

  /// Bulletin when the release fetch fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates, try again later'**
  String get updateCheckFailed;

  /// Settings row that checks GitHub releases by hand
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheckTitle;

  /// Subtitle of the manual update row
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String updateCheckSub(String version);

  /// Shown when the release body is empty
  ///
  /// In en, this message translates to:
  /// **'No release notes.'**
  String get updateNoNotes;

  /// Settings row and page title for skills
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillTitle;

  /// Subtitle of the skills row when none is installed
  ///
  /// In en, this message translates to:
  /// **'Teach the assistant reusable abilities'**
  String get skillSubEmpty;

  /// Subtitle of the skills row with installed count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 skill} other{{count} skills}}'**
  String skillSubCount(int count);

  /// Empty skills page headline
  ///
  /// In en, this message translates to:
  /// **'No skills yet'**
  String get skillEmptyTitle;

  /// Empty skills page body
  ///
  /// In en, this message translates to:
  /// **'Import a SKILL.md file, a zip, or paste the text. The assistant reads the list and opens one only when the task matches.'**
  String get skillEmptyBody;

  /// Button that opens the skill import choices
  ///
  /// In en, this message translates to:
  /// **'Import skill'**
  String get skillImport;

  /// Import choice
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get skillImportPaste;

  /// Import choice
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get skillImportFile;

  /// Import choice
  ///
  /// In en, this message translates to:
  /// **'From URL'**
  String get skillImportUrl;

  /// Title of the paste sheet
  ///
  /// In en, this message translates to:
  /// **'Paste SKILL.md'**
  String get skillPasteTitle;

  /// Placeholder of the paste field
  ///
  /// In en, this message translates to:
  /// **'Paste the SKILL.md text…'**
  String get skillPasteHint;

  /// Title of the URL sheet
  ///
  /// In en, this message translates to:
  /// **'Import from URL'**
  String get skillUrlTitle;

  /// Placeholder of the URL field
  ///
  /// In en, this message translates to:
  /// **'https://github.com/owner/repo/…'**
  String get skillUrlHint;

  /// Bulletin when a URL import fails
  ///
  /// In en, this message translates to:
  /// **'That URL could not be read as a skill.'**
  String get skillUrlError;

  /// Bulletin when a file import fails
  ///
  /// In en, this message translates to:
  /// **'That file is not a valid skill.'**
  String get skillInvalid;

  /// Confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete skill'**
  String get skillDeleteTitle;

  /// Confirmation body
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? The files go with it.'**
  String skillDeleteMessage(String name);

  /// Skill row subtitle when on
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get skillEnabled;

  /// Skill row subtitle when off
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get skillDisabled;

  /// How many times a skill was read
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Never used} =1{Used once} other{Used {count} times}}'**
  String skillDetailUses(int count);

  /// Note on the skill detail page
  ///
  /// In en, this message translates to:
  /// **'The instructions live in SKILL.md.'**
  String get skillOpenFile;

  /// Section header of the role skill picker
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get personaSkillsHeader;

  /// Section footer of the role skill picker
  ///
  /// In en, this message translates to:
  /// **'Follow global uses every enabled skill. Custom picks exactly the ones this role may use.'**
  String get personaSkillsFooter;

  /// Role skill mode that inherits all enabled skills
  ///
  /// In en, this message translates to:
  /// **'Follow global'**
  String get personaSkillsFollowGlobal;

  /// Role skill mode with an explicit list
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get personaSkillsCustom;

  /// How many skills a role picked
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No skill} =1{1 selected} other{{count} selected}}'**
  String personaSkillsCount(int count);

  /// Title of the role skill picker
  ///
  /// In en, this message translates to:
  /// **'Skills for this role'**
  String get personaSkillsPickTitle;

  /// Tools page description
  ///
  /// In en, this message translates to:
  /// **'Reads an installed skill by id'**
  String get toolDescReadSkill;

  /// Bulletin while a skill archive downloads
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get skillImporting;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

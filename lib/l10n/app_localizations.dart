import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Telegram Liquid'**
  String get appName;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone number to continue'**
  String get signInSubtitle;

  /// No description provided for @enterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get enterCodeTitle;

  /// No description provided for @enterCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to your Telegram app'**
  String get enterCodeSubtitle;

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'One more step'**
  String get passwordTitle;

  /// No description provided for @passwordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This account is protected by a cloud password'**
  String get passwordSubtitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+7 900 000 00 00'**
  String get phoneHint;

  /// No description provided for @confirmationCode.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code'**
  String get confirmationCode;

  /// No description provided for @codeHint.
  ///
  /// In en, this message translates to:
  /// **'• • • • •'**
  String get codeHint;

  /// No description provided for @twoStepVerification.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get twoStepVerification;

  /// No description provided for @cloudPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Your cloud password protects this account'**
  String get cloudPasswordHelper;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @demoAnyPhone.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — any phone number works'**
  String get demoAnyPhone;

  /// No description provided for @demoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — the code is 12345'**
  String get demoCodeHint;

  /// No description provided for @demoPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — the password is \"telegram\"'**
  String get demoPasswordHint;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @chatsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Chats ({count})'**
  String chatsWithCount(int count);

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats and messages'**
  String get searchChats;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get searchContacts;

  /// No description provided for @searchInChat.
  ///
  /// In en, this message translates to:
  /// **'Search in chat'**
  String get searchInChat;

  /// No description provided for @searchInChatHint.
  ///
  /// In en, this message translates to:
  /// **'Type to search this conversation'**
  String get searchInChatHint;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryAnotherSearch;

  /// No description provided for @noChatsInFolder.
  ///
  /// In en, this message translates to:
  /// **'No chats in this folder'**
  String get noChatsInFolder;

  /// No description provided for @pickAnotherFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick another folder above'**
  String get pickAnotherFolder;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @chatList.
  ///
  /// In en, this message translates to:
  /// **'Chat list'**
  String get chatList;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// No description provided for @markAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markAsRead;

  /// No description provided for @pinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinToTop;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @deleteChatMessage.
  ///
  /// In en, this message translates to:
  /// **'This conversation will be removed from the list.'**
  String get deleteChatMessage;

  /// No description provided for @chatDeleted.
  ///
  /// In en, this message translates to:
  /// **'{title} deleted'**
  String chatDeleted(String title);

  /// No description provided for @newMessageHint.
  ///
  /// In en, this message translates to:
  /// **'New message — pick a contact from the Contacts tab'**
  String get newMessageHint;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @forwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get forwardTo;

  /// No description provided for @forwardedTo.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {title}'**
  String forwardedTo(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @replyToSender.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String replyToSender(String name);

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typing;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @statusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get statusSending;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get statusRead;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Not delivered'**
  String get statusFailed;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @cameraRoll.
  ///
  /// In en, this message translates to:
  /// **'Camera roll'**
  String get cameraRoll;

  /// No description provided for @cameraRollSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String cameraRollSubtitle(int count);

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @locationNotWired.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is not wired up yet'**
  String get locationNotWired;

  /// No description provided for @chatInfo.
  ///
  /// In en, this message translates to:
  /// **'Chat info'**
  String get chatInfo;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'All messages in this chat will be removed on this device.'**
  String get clearHistoryMessage;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @mediaLinksDocs.
  ///
  /// In en, this message translates to:
  /// **'Media, links and docs'**
  String get mediaLinksDocs;

  /// No description provided for @chatWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get chatWallpaper;

  /// No description provided for @noMediaYet.
  ///
  /// In en, this message translates to:
  /// **'No media in this chat yet'**
  String get noMediaYet;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String photosCount(int count);

  /// No description provided for @presenceOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get presenceOnline;

  /// No description provided for @presenceLastSeen.
  ///
  /// In en, this message translates to:
  /// **'last seen recently'**
  String get presenceLastSeen;

  /// No description provided for @presenceBot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get presenceBot;

  /// No description provided for @presenceSaved.
  ///
  /// In en, this message translates to:
  /// **'your cloud storage'**
  String get presenceSaved;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @subscribersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subscribers'**
  String subscribersCount(String count);

  /// No description provided for @contactsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} contacts'**
  String contactsCount(int count);

  /// No description provided for @onlineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String onlineCount(int count);

  /// No description provided for @addContactHint.
  ///
  /// In en, this message translates to:
  /// **'Adding contacts needs the live TDLib backend'**
  String get addContactHint;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @noCalls.
  ///
  /// In en, this message translates to:
  /// **'No calls here'**
  String get noCalls;

  /// No description provided for @callCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get callCancelled;

  /// No description provided for @callingName.
  ///
  /// In en, this message translates to:
  /// **'Calling {name}…'**
  String callingName(String name);

  /// No description provided for @newCallHint.
  ///
  /// In en, this message translates to:
  /// **'Placing calls needs the live TDLib backend'**
  String get newCallHint;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get wallpaper;

  /// No description provided for @wallpaperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Glass refracts whatever sits behind it.'**
  String get wallpaperSubtitle;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @autoNightMode.
  ///
  /// In en, this message translates to:
  /// **'Auto night mode'**
  String get autoNightMode;

  /// No description provided for @autoNightModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the system appearance'**
  String get autoNightModeSubtitle;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @reduceTransparency.
  ///
  /// In en, this message translates to:
  /// **'Reduce transparency'**
  String get reduceTransparency;

  /// No description provided for @reduceTransparencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stops the wallpaper animation'**
  String get reduceTransparencySubtitle;

  /// No description provided for @glassIntensity.
  ///
  /// In en, this message translates to:
  /// **'Glass intensity'**
  String get glassIntensity;

  /// No description provided for @messageTextSize.
  ///
  /// In en, this message translates to:
  /// **'Message text size'**
  String get messageTextSize;

  /// No description provided for @textSizeSample.
  ///
  /// In en, this message translates to:
  /// **'The quick brown fox jumps over the lazy dog'**
  String get textSizeSample;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @readReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get readReceipts;

  /// No description provided for @activeSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// No description provided for @backend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backend;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @backendLive.
  ///
  /// In en, this message translates to:
  /// **'Connected through the official TDLib JSON interface.'**
  String get backendLive;

  /// No description provided for @backendDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo data. Pass --dart-define=TELEGRAM_API_ID and TELEGRAM_API_HASH, and bundle libtdjson.so, to talk to real Telegram servers.'**
  String get backendDemo;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutTitle;

  /// No description provided for @logOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to read your chats.'**
  String get logOutMessage;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About this build'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A Flutter Telegram client rendered with the iOS 26 Liquid Glass material. Glass quality adapts to the device.'**
  String get aboutBody;

  /// No description provided for @profileEditHint.
  ///
  /// In en, this message translates to:
  /// **'Profile editing needs the live backend'**
  String get profileEditHint;

  /// No description provided for @myStory.
  ///
  /// In en, this message translates to:
  /// **'My Story'**
  String get myStory;

  /// No description provided for @replyToStory.
  ///
  /// In en, this message translates to:
  /// **'Reply to story'**
  String get replyToStory;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get errorInvalidPhone;

  /// No description provided for @errorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code — use 12345 in demo mode'**
  String get errorInvalidCode;

  /// No description provided for @errorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password — use \"telegram\" in demo mode'**
  String get errorInvalidPassword;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @folderAll.
  ///
  /// In en, this message translates to:
  /// **'All Chats'**
  String get folderAll;

  /// No description provided for @folderPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get folderPersonal;

  /// No description provided for @folderGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get folderGroups;

  /// No description provided for @folderChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get folderChannels;

  /// No description provided for @folderUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get folderUnread;

  /// No description provided for @folderBots.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get folderBots;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from the gallery'**
  String get chooseFromGallery;

  /// No description provided for @attachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not attach that file'**
  String get attachmentFailed;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'ru':
      return AppL10nRu();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

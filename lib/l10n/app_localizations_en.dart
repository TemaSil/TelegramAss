// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Telegram Liquid';

  @override
  String get signInSubtitle => 'Sign in with your phone number to continue';

  @override
  String get enterCodeTitle => 'Enter the code';

  @override
  String get enterCodeSubtitle => 'We sent a code to your Telegram app';

  @override
  String get passwordTitle => 'One more step';

  @override
  String get passwordSubtitle =>
      'This account is protected by a cloud password';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneHint => '+7 900 000 00 00';

  @override
  String get confirmationCode => 'Confirmation code';

  @override
  String get codeHint => '• • • • •';

  @override
  String get twoStepVerification => 'Two-step verification';

  @override
  String get cloudPasswordHelper => 'Your cloud password protects this account';

  @override
  String get password => 'Password';

  @override
  String get sendCode => 'Send code';

  @override
  String get continueAction => 'Continue';

  @override
  String get demoAnyPhone => 'Demo mode — any phone number works';

  @override
  String get demoCodeHint => 'Demo mode — the code is 12345';

  @override
  String get demoPasswordHint => 'Demo mode — the password is \"telegram\"';

  @override
  String get chats => 'Chats';

  @override
  String chatsWithCount(int count) {
    return 'Chats ($count)';
  }

  @override
  String get contacts => 'Contacts';

  @override
  String get calls => 'Calls';

  @override
  String get settings => 'Settings';

  @override
  String get searchChats => 'Search chats and messages';

  @override
  String get searchContacts => 'Search contacts';

  @override
  String get searchInChat => 'Search in chat';

  @override
  String get searchInChatHint => 'Type to search this conversation';

  @override
  String get noMatches => 'No matches';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get tryAnotherSearch => 'Try a different search term';

  @override
  String get noChatsInFolder => 'No chats in this folder';

  @override
  String get pickAnotherFolder => 'Pick another folder above';

  @override
  String get edit => 'Edit';

  @override
  String get chatList => 'Chat list';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get pinToTop => 'Pin to top';

  @override
  String get unpin => 'Unpin';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get deleteChatMessage =>
      'This conversation will be removed from the list.';

  @override
  String chatDeleted(String title) {
    return '$title deleted';
  }

  @override
  String get newMessageHint =>
      'New message — pick a contact from the Contacts tab';

  @override
  String get reply => 'Reply';

  @override
  String get copy => 'Copy';

  @override
  String get forward => 'Forward';

  @override
  String get forwardTo => 'Forward to';

  @override
  String forwardedTo(String title) {
    return 'Forwarded to $title';
  }

  @override
  String get delete => 'Delete';

  @override
  String get message => 'Message';

  @override
  String get editMessage => 'Edit message';

  @override
  String replyToSender(String name) {
    return 'Reply to $name';
  }

  @override
  String get edited => 'edited';

  @override
  String get typing => 'typing…';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get statusSending => 'Sending…';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusRead => 'Read';

  @override
  String get statusFailed => 'Not delivered';

  @override
  String get send => 'Send';

  @override
  String get photo => 'Photo';

  @override
  String get file => 'File';

  @override
  String get location => 'Location';

  @override
  String get recent => 'Recent';

  @override
  String get cameraRoll => 'Camera roll';

  @override
  String cameraRollSubtitle(int count) {
    return '$count items';
  }

  @override
  String get documents => 'Documents';

  @override
  String get browseFiles => 'Browse files';

  @override
  String get locationNotWired => 'Location sharing is not wired up yet';

  @override
  String get chatInfo => 'Chat info';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryTitle => 'Clear history?';

  @override
  String get clearHistoryMessage =>
      'All messages in this chat will be removed on this device.';

  @override
  String get clear => 'Clear';

  @override
  String get cancel => 'Cancel';

  @override
  String get call => 'Call';

  @override
  String get video => 'Video';

  @override
  String get search => 'Search';

  @override
  String get info => 'Info';

  @override
  String get notifications => 'Notifications';

  @override
  String get mediaLinksDocs => 'Media, links and docs';

  @override
  String get chatWallpaper => 'Chat wallpaper';

  @override
  String get noMediaYet => 'No media in this chat yet';

  @override
  String photosCount(int count) {
    return '$count photos';
  }

  @override
  String get presenceOnline => 'online';

  @override
  String get presenceLastSeen => 'last seen recently';

  @override
  String get presenceBot => 'bot';

  @override
  String get presenceSaved => 'your cloud storage';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String subscribersCount(String count) {
    return '$count subscribers';
  }

  @override
  String contactsCount(int count) {
    return '$count contacts';
  }

  @override
  String onlineCount(int count) {
    return '$count online';
  }

  @override
  String get addContactHint => 'Adding contacts needs the live TDLib backend';

  @override
  String get all => 'All';

  @override
  String get missed => 'Missed';

  @override
  String get noCalls => 'No calls here';

  @override
  String get callCancelled => 'Cancelled';

  @override
  String callingName(String name) {
    return 'Calling $name…';
  }

  @override
  String get newCallHint => 'Placing calls needs the live TDLib backend';

  @override
  String get appearance => 'Appearance';

  @override
  String get wallpaper => 'Wallpaper';

  @override
  String get wallpaperSubtitle => 'Glass refracts whatever sits behind it.';

  @override
  String get choose => 'Choose';

  @override
  String get autoNightMode => 'Auto night mode';

  @override
  String get autoNightModeSubtitle => 'Follow the system appearance';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get reduceTransparency => 'Reduce transparency';

  @override
  String get reduceTransparencySubtitle => 'Stops the wallpaper animation';

  @override
  String get glassIntensity => 'Glass intensity';

  @override
  String get messageTextSize => 'Message text size';

  @override
  String get textSizeSample => 'The quick brown fox jumps over the lazy dog';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get privacy => 'Privacy';

  @override
  String get readReceipts => 'Read receipts';

  @override
  String get activeSessions => 'Active sessions';

  @override
  String get backend => 'Backend';

  @override
  String get mode => 'Mode';

  @override
  String get backendLive =>
      'Connected through the official TDLib JSON interface.';

  @override
  String get backendDemo =>
      'Demo data. Pass --dart-define=TELEGRAM_API_ID and TELEGRAM_API_HASH, and bundle libtdjson.so, to talk to real Telegram servers.';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutTitle => 'Log out?';

  @override
  String get logOutMessage =>
      'You will need to sign in again to read your chats.';

  @override
  String get aboutTitle => 'About this build';

  @override
  String get aboutBody =>
      'A Flutter Telegram client rendered with the iOS 26 Liquid Glass material. Glass quality adapts to the device.';

  @override
  String get profileEditHint => 'Profile editing needs the live backend';

  @override
  String get myStory => 'My Story';

  @override
  String get replyToStory => 'Reply to story';

  @override
  String get errorInvalidPhone => 'Enter a valid phone number';

  @override
  String get errorInvalidCode => 'Invalid code — use 12345 in demo mode';

  @override
  String get errorInvalidPassword =>
      'Wrong password — use \"telegram\" in demo mode';

  @override
  String get draft => 'Draft';

  @override
  String get folderAll => 'All Chats';

  @override
  String get folderPersonal => 'Personal';

  @override
  String get folderGroups => 'Groups';

  @override
  String get folderChannels => 'Channels';

  @override
  String get folderUnread => 'Unread';

  @override
  String get folderBots => 'Bots';

  @override
  String get camera => 'Camera';

  @override
  String get chooseFromGallery => 'Choose from the gallery';

  @override
  String get attachmentFailed => 'Could not attach that file';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsHint =>
      'What the Telegram backend has reported since launch.';

  @override
  String get diagnosticsEmpty => 'Nothing logged yet.';

  @override
  String get diagnosticsCopied => 'Log copied';

  @override
  String get connecting => 'Connecting to Telegram…';

  @override
  String get demoBanner =>
      'Running on demo data — no code will be sent to a real phone.';

  @override
  String get openDiagnostics => 'Why?';

  @override
  String get proxy => 'Proxy';

  @override
  String get proxyHint => 'Use a proxy when Telegram is unreachable directly.';

  @override
  String get proxyServer => 'Server';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxySecret => 'Secret';

  @override
  String get proxyUsername => 'Username';

  @override
  String get proxyPassword => 'Password';

  @override
  String get proxyUse => 'Use proxy';

  @override
  String get proxyEnabled => 'Proxy enabled';

  @override
  String get proxyDisabled => 'Proxy disabled';

  @override
  String get proxyInvalid => 'Enter a server and a port';

  @override
  String get save => 'Save';

  @override
  String get connection => 'Connection';

  @override
  String get proxyOff => 'Off';
}

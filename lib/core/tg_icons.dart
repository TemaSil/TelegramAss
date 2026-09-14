import 'package:flutter_cupertino_symbols/flutter_cupertino_symbols.dart';

/// Every icon the app draws, named by what it means rather than by glyph.
///
/// The glyphs come from SF Symbols 6, which is what makes the chrome read as
/// iOS rather than as "Flutter with Cupertino icons" — `CupertinoIcons` only
/// ships a small, partly non-SF subset.
///
/// Licence note: Apple licenses SF Symbols for use on Apple platforms. Shipping
/// the font inside an Android APK is outside that licence; this app does it at
/// the publisher's discretion. Swapping [TgIcons] back to `CupertinoIcons` is a
/// single-file change if that is not acceptable for a given release.
class TgIcons {
  TgIcons._();

  // Tab bar
  static const chats = SFSymbols.bubble_left_and_bubble_right;
  static const chatsActive = SFSymbols.bubble_left_and_bubble_right_fill;
  static const contacts = SFSymbols.person_2;
  static const contactsActive = SFSymbols.person_2_fill;
  static const calls = SFSymbols.phone;
  static const callsActive = SFSymbols.phone_fill;
  static const settings = SFSymbols.gearshape;
  static const settingsActive = SFSymbols.gearshape_fill;

  // Navigation and chrome
  static const back = SFSymbols.chevron_left;
  static const forward = SFSymbols.chevron_right;
  static const chevronDown = SFSymbols.chevron_down;
  static const more = SFSymbols.ellipsis;
  static const close = SFSymbols.xmark;
  static const compose = SFSymbols.square_and_pencil;
  static const filter = SFSymbols.line_horizontal_3_decrease;
  static const search = SFSymbols.magnifyingglass;
  static const info = SFSymbols.info_circle;
  static const help = SFSymbols.questionmark_circle;
  static const logo = SFSymbols.paperplane_fill;

  // Chat list
  static const pin = SFSymbols.pin;
  static const pinFilled = SFSymbols.pin_fill;
  static const mute = SFSymbols.bell_slash;
  static const muteFilled = SFSymbols.bell_slash_fill;
  static const unmute = SFSymbols.bell;
  static const verified = SFSymbols.checkmark_seal_fill;
  static const markRead = SFSymbols.checkmark_circle;
  static const delete = SFSymbols.trash;
  static const saved = SFSymbols.bookmark_fill;
  static const bot = SFSymbols.chevron_left_slash_chevron_right;
  static const channel = SFSymbols.antenna_radiowaves_left_and_right;
  static const folder = SFSymbols.folder;

  // Messages
  static const reply = SFSymbols.arrowshape_turn_up_left;
  static const forwardMessage = SFSymbols.arrowshape_turn_up_right;
  static const copy = SFSymbols.document_on_document;
  static const edit = SFSymbols.pencil;
  static const sent = SFSymbols.checkmark;
  static const pending = SFSymbols.clock;
  static const failed = SFSymbols.exclamationmark_circle;
  static const play = SFSymbols.play_fill;
  static const file = SFSymbols.document_fill;
  static const photo = SFSymbols.photo;
  static const camera = SFSymbols.camera;
  static const media = SFSymbols.photo_on_rectangle;
  static const document = SFSymbols.document;
  static const location = SFSymbols.location;
  static const attach = SFSymbols.plus;
  static const send = SFSymbols.arrow_up;
  static const voice = SFSymbols.microphone_fill;
  static const heart = SFSymbols.suit_heart;

  // Calls
  static const video = SFSymbols.video;
  static const addContact = SFSymbols.person_badge_plus;
  static const newCall = SFSymbols.phone_badge_plus;
  static const callOutgoing = SFSymbols.arrow_up_right;
  static const callIncoming = SFSymbols.arrow_down_left;

  // Settings
  static const wallpaper = SFSymbols.paintbrush;
  static const nightMode = SFSymbols.moon;
  static const nightModeFilled = SFSymbols.moon_fill;
  static const lightMode = SFSymbols.sun_max;
  static const transparency = SFSymbols.eye_slash;
  static const glass = SFSymbols.sparkles;
  static const textSize = SFSymbols.textformat_size;
  static const language = SFSymbols.globe;
  static const proxy = SFSymbols.network;
  static const privacy = SFSymbols.lock;
  static const receipts = SFSymbols.checkmark_seal_fill;
  static const sessions = SFSymbols.iphone_gen3;
  static const logOut = SFSymbols.rectangle_portrait_and_arrow_right;
  static const premium = SFSymbols.star_fill;
  static const live = SFSymbols.antenna_radiowaves_left_and_right;
  static const demo = SFSymbols.shippingbox;

  // Selection markers
  static const selected = SFSymbols.checkmark_circle_fill;
  static const unselected = SFSymbols.circlebadge;
  static const dot = SFSymbols.circlebadge_fill;
}

import 'package:flutter/cupertino.dart';

/// Palette tuned to iOS 26 system colours with Telegram accents.
///
/// Every colour is a [CupertinoDynamicColor] so a single token resolves
/// correctly in both light and dark appearance.
class TgColors {
  TgColors._();

  /// Accent used for outgoing bubbles, links and selected chrome.
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007AFF),
    darkColor: Color(0xFF0A84FF),
  );

  /// Secondary accent — online dots, "saved messages", verified badges.
  static const teal = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF34C759),
    darkColor: Color(0xFF30D158),
  );

  static const destructive = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF3B30),
    darkColor: Color(0xFFFF453A),
  );

  /// Page background behind the glass. Never pure white/black: glass needs
  /// contrast underneath or the specular highlight disappears.
  static const background = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF000000),
  );

  static const label = CupertinoColors.label;
  static const secondaryLabel = CupertinoColors.secondaryLabel;
  static const tertiaryLabel = CupertinoColors.tertiaryLabel;
  static const separator = CupertinoColors.separator;

  /// iMessage bubbles: a solid blue for what you send, a neutral grey for what
  /// you receive. Solid, not glass — glass belongs to the chrome, and a
  /// translucent bubble makes message text fight the wallpaper behind it.
  static const outgoingBubble = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007AFF),
    darkColor: Color(0xFF0B84FF),
  );

  static const incomingBubble = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE9E9EB),
    darkColor: Color(0xFF26252A),
  );

  /// Avatar gradients, picked deterministically from a chat id.
  static const avatarGradients = <List<Color>>[
    [Color(0xFFFF7A6B), Color(0xFFE0405A)],
    [Color(0xFFFFB06B), Color(0xFFE08A2C)],
    [Color(0xFF7ED97E), Color(0xFF2FA84F)],
    [Color(0xFF6BC5FF), Color(0xFF2B7FE0)],
    [Color(0xFFB48BFF), Color(0xFF7A4FE0)],
    [Color(0xFFFF8BC5), Color(0xFFE0407F)],
    [Color(0xFF6BE0D2), Color(0xFF199C8C)],
  ];

  static List<Color> avatarGradient(int seed) =>
      avatarGradients[seed.abs() % avatarGradients.length];

  static bool isDark(BuildContext context) =>
      CupertinoTheme.of(context).brightness == Brightness.dark;
}

/// Type scale mirroring the iOS text styles used across the app.
class TgText {
  TgText._();

  /// The typeface the whole app is set in.
  ///
  /// `CupertinoApp` asks for `.SF Pro Text`, which exists on iOS and nowhere
  /// else — on Android Flutter quietly substitutes Roboto, and every screen
  /// then reads as an Android app however carefully the chrome is drawn. SF
  /// Pro cannot ship inside an APK: Apple licenses it for developing *for*
  /// Apple platforms. Inter is drawn to the same metrics, covers Cyrillic,
  /// and is under the SIL Open Font License, which does allow it.
  static const family = 'Inter';

  /// Puts [family] on every style the framework resolves from the theme.
  ///
  /// The styles below do not name a family: a `Text` merges its style onto
  /// the default one, so they inherit whatever `textStyle` carries. The nav
  /// bar, action sheets and pickers are built by Cupertino itself and read
  /// their own entries, which is why each is set here.
  static CupertinoTextThemeData textTheme(CupertinoTextThemeData base) =>
      base.copyWith(
        textStyle: base.textStyle.copyWith(fontFamily: family),
        actionTextStyle: base.actionTextStyle.copyWith(fontFamily: family),
        actionSmallTextStyle: base.actionSmallTextStyle.copyWith(
          fontFamily: family,
        ),
        tabLabelTextStyle: base.tabLabelTextStyle.copyWith(fontFamily: family),
        navTitleTextStyle: base.navTitleTextStyle.copyWith(fontFamily: family),
        navLargeTitleTextStyle: base.navLargeTitleTextStyle.copyWith(
          fontFamily: family,
        ),
        navActionTextStyle: base.navActionTextStyle.copyWith(
          fontFamily: family,
        ),
        pickerTextStyle: base.pickerTextStyle.copyWith(fontFamily: family),
        dateTimePickerTextStyle: base.dateTimePickerTextStyle.copyWith(
          fontFamily: family,
        ),
      );

  static TextStyle navTitle(BuildContext context) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: TgColors.label.resolveFrom(context),
  );

  static TextStyle rowTitle(BuildContext context) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: TgColors.label.resolveFrom(context),
  );

  static TextStyle rowPreview(BuildContext context) => TextStyle(
    fontSize: 15,
    height: 1.25,
    letterSpacing: -0.2,
    color: TgColors.secondaryLabel.resolveFrom(context),
  );

  static TextStyle timestamp(BuildContext context) => TextStyle(
    fontSize: 13,
    letterSpacing: -0.1,
    color: TgColors.tertiaryLabel.resolveFrom(context),
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontSize: 16.5,
    height: 1.3,
    letterSpacing: -0.2,
    color: TgColors.label.resolveFrom(context),
  );

  static TextStyle sectionHeader(BuildContext context) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: TgColors.secondaryLabel.resolveFrom(context),
  );
}

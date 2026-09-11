import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'tg_theme.dart';

/// Central glass vocabulary for the app.
///
/// The package exposes dozens of knobs; keeping the combinations in one place
/// is what makes separate screens read as a single material. Dark mode uses a
/// shallow bevel with no Fresnel (matching iOS 26's flat `UIVisualEffectView`),
/// light mode gets the full 3D bevel.
class GlassTokens {
  GlassTokens._();

  /// Navigation chrome: app bar buttons, tab bar, pills.
  static LiquidGlassSettings chrome(BuildContext context) {
    final dark = TgColors.isDark(context);
    return LiquidGlassSettings(
      glassColor: dark
          ? const Color(0xA6262626)
          : CupertinoColors.white.withValues(alpha: 0.15),
      thickness: 18,
      blur: dark ? 1.8 : 8,
      lightIntensity: dark ? 0.18 : 0.45,
      ambientStrength: dark ? 0.0 : 0.12,
      fresnelStrength: dark ? 0.0 : 1.0,
      chromaticAberration: 0.01,
      refractiveIndex: 1.2,
      saturation: 1.0,
      shadowElevation: dark ? 0.0 : 0.8,
    );
  }

  /// Floating panels: cards, grouped sections, chat info.
  static LiquidGlassSettings panel(BuildContext context) {
    final dark = TgColors.isDark(context);
    return LiquidGlassSettings(
      glassColor: dark
          ? const Color(0xFF1C1C1E).withValues(alpha: 0.62)
          : CupertinoColors.white.withValues(alpha: 0.22),
      thickness: dark ? 22 : 16,
      blur: dark ? 6 : 10,
      lightIntensity: dark ? 0.16 : 0.4,
      ambientStrength: dark ? 0.0 : 0.14,
      fresnelStrength: dark ? 0.0 : 1.0,
      chromaticAberration: 0.012,
      refractiveIndex: 1.22,
      saturation: 1.1,
      shadowElevation: dark ? 0.2 : 1.2,
    );
  }

  /// Context menus and popovers — thicker, more refractive.
  static LiquidGlassSettings menu(BuildContext context) {
    final dark = TgColors.isDark(context);
    return LiquidGlassSettings(
      glassColor: dark
          ? const Color(0xFF262626).withValues(alpha: 0.5)
          : CupertinoColors.white.withValues(alpha: 0.15),
      thickness: dark ? 25 : 18,
      blur: 8,
      lightIntensity: dark ? 0.18 : 0.45,
      ambientStrength: dark ? 0.0 : 0.12,
      fresnelStrength: dark ? 0.0 : 1.0,
      chromaticAberration: 0.01,
      refractiveIndex: 1.2,
      saturation: 1.0,
      shadowElevation: dark ? 0.0 : 1.5,
    );
  }

  /// Outgoing message bubble — tinted with the accent so the glass carries
  /// Telegram's blue while still refracting the wallpaper behind it.
  static LiquidGlassSettings outgoingBubble(BuildContext context) {
    final dark = TgColors.isDark(context);
    return LiquidGlassSettings(
      glassColor: TgColors.accent
          .resolveFrom(context)
          .withValues(alpha: dark ? 0.55 : 0.70),
      thickness: 14,
      blur: dark ? 3 : 6,
      lightIntensity: dark ? 0.22 : 0.4,
      ambientStrength: dark ? 0.05 : 0.16,
      fresnelStrength: dark ? 0.2 : 1.0,
      chromaticAberration: 0.008,
      refractiveIndex: 1.18,
      saturation: 1.2,
      shadowElevation: dark ? 0.2 : 0.9,
    );
  }

  /// Incoming message bubble — neutral, leans on the wallpaper for colour.
  static LiquidGlassSettings incomingBubble(BuildContext context) {
    final dark = TgColors.isDark(context);
    return LiquidGlassSettings(
      glassColor: dark
          ? const Color(0xFF2C2C2E).withValues(alpha: 0.58)
          : CupertinoColors.white.withValues(alpha: 0.42),
      thickness: 14,
      blur: dark ? 4 : 8,
      lightIntensity: dark ? 0.16 : 0.36,
      ambientStrength: dark ? 0.0 : 0.14,
      fresnelStrength: dark ? 0.0 : 0.9,
      chromaticAberration: 0.01,
      refractiveIndex: 1.2,
      saturation: 1.05,
      shadowElevation: dark ? 0.0 : 0.7,
    );
  }

  /// The composer bar at the bottom of a conversation.
  static LiquidGlassSettings composer(BuildContext context) {
    final dark = TgColors.isDark(context);
    return LiquidGlassSettings(
      glassColor: dark
          ? const Color(0xA6262626)
          : CupertinoColors.white.withValues(alpha: 0.18),
      thickness: dark ? 25 : 18,
      blur: dark ? 2.2 : 9,
      lightIntensity: dark ? 0.18 : 0.45,
      ambientStrength: dark ? 0.0 : 0.12,
      fresnelStrength: dark ? 0.0 : 1.0,
      chromaticAberration: 0.01,
      refractiveIndex: 1.2,
      saturation: 1.0,
      shadowElevation: dark ? 0.0 : 1.5,
    );
  }

  /// Radius vocabulary — iOS 26 leans on continuous, capsule-ish corners.
  static const double bubbleRadius = 20;
  static const double cardRadius = 26;
  static const double pillRadius = 22;
  static const double sheetRadius = 44;
}

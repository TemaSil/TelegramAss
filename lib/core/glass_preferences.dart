import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Which material the floating surfaces are made of.
enum GlassMaterial {
  /// Liquid glass: refraction, bevel, Fresnel edge and specular highlights.
  glass,

  /// A plain frosted blur — a backdrop blur and a tint, the way UIKit's own
  /// `UIVisualEffectView` does it, with no custom shader running at all.
  blur,
}

/// User-tunable glass settings, published above the app so the token helpers
/// in `glass_tokens.dart` can read them without depending on `AppState`.
///
/// Keeping this in `core/` is what lets the tokens stay a pure function of
/// `BuildContext` while still honouring the Settings screen.
@immutable
class GlassPreferences {
  const GlassPreferences({
    this.material = GlassMaterial.glass,
    this.reduceTransparency = false,
  });

  /// What the floating surfaces are made of.
  final GlassMaterial material;

  /// Mirrors the accessibility setting: flattens the material and stops the
  /// wallpaper animation.
  final bool reduceTransparency;

  /// The effective multiplier over the glass tokens, collapsing to a nearly
  /// flat material when the user has asked for reduced transparency.
  double get factor => reduceTransparency ? 0.25 : 1.0;

  /// The rendering tier these preferences ask for. The package resolves
  /// [GlassQuality.minimal] to a backdrop blur with a tint and a rim stroke,
  /// which is exactly the simplified material — so the choice needs no
  /// second implementation here.
  GlassQuality get quality => material == GlassMaterial.blur
      ? GlassQuality.minimal
      : GlassQuality.premium;

  @override
  bool operator ==(Object other) =>
      other is GlassPreferences &&
      other.material == material &&
      other.reduceTransparency == reduceTransparency;

  @override
  int get hashCode => Object.hash(material, reduceTransparency);
}

class GlassPreferencesScope extends InheritedWidget {
  const GlassPreferencesScope({
    super.key,
    required this.preferences,
    required super.child,
  });

  final GlassPreferences preferences;

  /// Falls back to the defaults so widgets stay usable in tests and previews.
  static GlassPreferences of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GlassPreferencesScope>();
    return scope?.preferences ?? const GlassPreferences();
  }

  @override
  bool updateShouldNotify(GlassPreferencesScope oldWidget) =>
      oldWidget.preferences != preferences;
}

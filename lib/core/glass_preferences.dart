import 'package:flutter/widgets.dart';

/// User-tunable glass settings, published above the app so the token helpers
/// in `glass_tokens.dart` can read them without depending on `AppState`.
///
/// Keeping this in `core/` is what lets the tokens stay a pure function of
/// `BuildContext` while still honouring the Settings screen.
@immutable
class GlassPreferences {
  const GlassPreferences({
    this.intensity = 1.0,
    this.reduceTransparency = false,
  });

  /// 0.2 – 1.0. Scales bevel thickness, blur and the specular response.
  final double intensity;

  /// Mirrors the accessibility setting: flattens the material and stops the
  /// wallpaper animation.
  final bool reduceTransparency;

  /// The effective multiplier, collapsing to a nearly flat material when the
  /// user has asked for reduced transparency.
  double get factor => reduceTransparency ? 0.25 : intensity;

  @override
  bool operator ==(Object other) =>
      other is GlassPreferences &&
      other.intensity == intensity &&
      other.reduceTransparency == reduceTransparency;

  @override
  int get hashCode => Object.hash(intensity, reduceTransparency);
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

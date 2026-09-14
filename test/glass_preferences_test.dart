import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:telegram_liquid/core/glass_preferences.dart';
import 'package:telegram_liquid/core/glass_tokens.dart';

/// The material choice has to reach the shader, not just the setting object.
void main() {
  Future<void> pumpWith(
    WidgetTester tester,
    GlassPreferences preferences,
    void Function(BuildContext) probe,
  ) {
    return tester.pumpWidget(
      CupertinoApp(
        home: GlassPreferencesScope(
          preferences: preferences,
          child: Builder(
            builder: (context) {
              probe(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('the simplified material asks for a real frost', (tester) async {
    late final double glassBlur;
    late final double blurBlur;
    late final GlassQuality glassQuality;
    late final GlassQuality glassHeroQuality;
    late final GlassQuality blurQuality;
    late final GlassQuality blurHeroQuality;

    await pumpWith(tester, const GlassPreferences(), (context) {
      glassBlur = GlassTokens.chrome(context).blur;
      glassQuality = GlassTokens.quality(context);
      glassHeroQuality = GlassTokens.heroQuality(context);
    });

    await pumpWith(
      tester,
      const GlassPreferences(material: GlassMaterial.blur),
      (context) {
        blurBlur = GlassTokens.chrome(context).blur;
        blurQuality = GlassTokens.quality(context);
        blurHeroQuality = GlassTokens.heroQuality(context);
      },
    );

    // Without the shader the frost is the whole effect, so it has to grow.
    expect(blurBlur, greaterThan(glassBlur));
    // A control is the single-pass shader; only hero surfaces get the
    // multi-pass one — and the simplified material flattens both.
    expect(glassQuality, GlassQuality.standard);
    expect(glassHeroQuality, GlassQuality.premium);
    expect(blurQuality, GlassQuality.minimal);
    expect(blurHeroQuality, GlassQuality.minimal);
  });

  testWidgets('reduce transparency flattens either material', (tester) async {
    late final double fullThickness;
    late final double dimmedThickness;

    await pumpWith(tester, const GlassPreferences(), (context) {
      fullThickness = GlassTokens.chrome(context).thickness;
    });

    await pumpWith(tester, const GlassPreferences(reduceTransparency: true), (
      context,
    ) {
      dimmedThickness = GlassTokens.chrome(context).thickness;
    });

    expect(dimmedThickness, lessThan(fullThickness));
  });

  test('reduce transparency still collapses the scale factor', () {
    const preferences = GlassPreferences(reduceTransparency: true);
    expect(preferences.factor, lessThan(1.0));
    expect(const GlassPreferences().factor, 1.0);
  });
}

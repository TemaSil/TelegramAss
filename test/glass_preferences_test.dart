import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_liquid/core/glass_preferences.dart';
import 'package:telegram_liquid/core/glass_tokens.dart';

/// The intensity slider has to reach the shader, not just the setting object.
void main() {
  testWidgets('glass intensity scales the shader settings', (tester) async {
    late final double fullThickness;
    late final double dimmedThickness;
    late final double dimmedBlur;
    late final double fullBlur;

    Future<void> pumpWith(
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

    await pumpWith(const GlassPreferences(), (context) {
      final settings = GlassTokens.chrome(context);
      fullThickness = settings.thickness;
      fullBlur = settings.blur;
    });

    await pumpWith(const GlassPreferences(intensity: 0.4), (context) {
      final settings = GlassTokens.chrome(context);
      dimmedThickness = settings.thickness;
      dimmedBlur = settings.blur;
    });

    expect(dimmedThickness, lessThan(fullThickness));
    expect(dimmedBlur, lessThan(fullBlur));
  });

  test('reduce transparency overrides the intensity slider', () {
    const preferences = GlassPreferences(
      intensity: 1.0,
      reduceTransparency: true,
    );
    expect(preferences.factor, lessThan(1.0));
  });
}

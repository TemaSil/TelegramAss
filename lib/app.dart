import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';

import 'core/glass_preferences.dart';
import 'core/tg_theme.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/shell/root_shell.dart';

/// Exposes [AppState] to the widget tree and swaps between login and the
/// main shell as authorization advances.
class TelegramLiquidApp extends StatelessWidget {
  const TelegramLiquidApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          // Auto night mode follows the OS; otherwise the Settings switch wins.
          final brightness = state.autoNightMode
              ? MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.dark
              : (state.darkMode ? Brightness.dark : Brightness.light);

          return GlassPreferencesScope(
            preferences: GlassPreferences(
              intensity: state.glassIntensity,
              reduceTransparency: state.reduceTransparency,
            ),
            child: CupertinoApp(
              onGenerateTitle: (context) => AppL10n.of(context).appName,
              debugShowCheckedModeBanner: false,
              // 'system' leaves the choice to the platform resolver.
              locale: state.language == 'system'
                  ? null
                  : Locale(state.language),
              supportedLocales: AppL10n.supportedLocales,
              localizationsDelegates: const [
                AppL10n.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              theme: CupertinoThemeData(
                brightness: brightness,
                primaryColor: TgColors.accent,
              ),
              home: state.stage == TgAuthStage.ready
                  ? const RootShell()
                  : const AuthScreen(),
            ),
          );
        },
      ),
    );
  }
}

/// `AppScope.of(context)` anywhere below the app root.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing — for callbacks and one-off reads.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}

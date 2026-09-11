import 'package:flutter/cupertino.dart';

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
      child: CupertinoApp(
        title: 'Telegram Liquid',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            return state.stage == TgAuthStage.ready
                ? const RootShell()
                : const AuthScreen();
          },
        ),
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

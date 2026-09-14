import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the glass chrome is laid out for a phone bar geometry.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Non-blocking shader preload — keeps frame 1 free of glass pop-in.
  await LiquidGlassWidgets.initialize();

  // path_provider has no web implementation; the web build is only ever used
  // for previews, where the demo backend needs no directories anyway.
  final documents = kIsWeb ? null : await getApplicationDocumentsDirectory();
  final state = await AppState.create(
    databaseDirectory: documents == null ? '' : '${documents.path}/tdlib',
    filesDirectory: documents == null ? '' : '${documents.path}/tdlib-files',
  );

  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      // CupertinoApp drives the brightness, so the glass reads the theme
      // rather than the raw OS setting.
      brightnessResolver: (context) =>
          CupertinoTheme.maybeBrightnessOf(context),
      child: TelegramLiquidApp(state: state),
    ),
  );
}

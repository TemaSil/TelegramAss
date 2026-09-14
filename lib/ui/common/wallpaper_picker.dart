import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/glass_tokens.dart';
import '../../core/tg_icons.dart';
import '../../data/app_state.dart';
import 'wallpaper.dart';

/// Shared wallpaper chooser — reachable from Settings and from a chat's info
/// sheet, the way Telegram offers it in both places.
Future<void> showWallpaperPicker(BuildContext context, AppState state) {
  return showGlassActionSheet<void>(
    context: context,
    title: 'Wallpaper',
    message: 'Glass refracts whatever sits behind it.',
    settings: GlassTokens.menu(context),
    quality: GlassQuality.premium,
    actions: [
      for (final entry in GlassWallpaper.labels.entries)
        GlassActionSheetAction(
          label: entry.value,
          icon: Icon(
            state.wallpaper == entry.key
                ? TgIcons.selected
                : TgIcons.unselected,
          ),
          onPressed: () {
            state.setWallpaper(entry.key);
            Navigator.of(context).pop();
          },
        ),
    ],
  );
}

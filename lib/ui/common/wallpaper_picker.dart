import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/glass_tokens.dart';
import '../../core/tg_icons.dart';
import '../../data/app_state.dart';
import 'wallpaper.dart';
import '../../l10n/app_localizations.dart';

/// Shared wallpaper chooser — reachable from Settings and from a chat's info
/// sheet, the way Telegram offers it in both places.
Future<void> showWallpaperPicker(BuildContext context, AppState state) {
  final l10n = AppL10n.of(context);
  return showGlassActionSheet<void>(
    context: context,
    title: l10n.wallpaper,
    message: l10n.wallpaperSubtitle,
    settings: GlassTokens.menu(context),
    quality: GlassTokens.quality(context),
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

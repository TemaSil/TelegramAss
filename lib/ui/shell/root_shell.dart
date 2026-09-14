import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../calls/calls_screen.dart';
import '../chats/chats_screen.dart';
import '../common/wallpaper.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

/// The four-tab shell.
///
/// One [GlassScaffold] owns the wallpaper, the nav bar and the tab bar; each
/// tab contributes an app bar and a scrollable body that share a
/// [GlassLargeTitleController], so the large title collapses into the bar the
/// way it does on iOS.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _tabCount = 4;

  final _titleControllers = List.generate(
    _tabCount,
    (_) => GlassLargeTitleController(),
    growable: false,
  );

  int _index = 0;

  @override
  void dispose() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _index) {
      // Second tap on the active tab scrolls back to the top, like iOS.
      final controller = _titleControllers[index].scrollController;
      if (controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final unread = state.totalUnread;

    return GlassScaffold(
      // The chat list, contacts, calls and settings use the system background,
      // as they do on iOS; a wallpaper belongs to a conversation.
      background: const GlassWallpaper(variant: GlassWallpaper.none),
      settings: GlassTokens.chrome(context),
      statusBarStyle: GlassStatusBarStyle.auto,
      appBarHeight: 52,
      bottomBarHeight: 64,
      appBar: _appBarFor(_index),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _index,
        onTabSelected: _onTabSelected,
        quality: GlassQuality.premium,
        settings: GlassTokens.chrome(context),
        selectedIconColor: TgColors.accent.resolveFrom(context),
        unselectedIconColor: TgColors.secondaryLabel.resolveFrom(context),
        tabs: [
          GlassTab(
            icon: const Icon(TgIcons.chats),
            activeIcon: const Icon(TgIcons.chatsActive),
            label: unread > 0 ? l10n.chatsWithCount(unread) : l10n.chats,
          ),
          GlassTab(
            icon: const Icon(TgIcons.contacts),
            activeIcon: const Icon(TgIcons.contactsActive),
            label: l10n.contacts,
          ),
          GlassTab(
            icon: const Icon(TgIcons.calls),
            activeIcon: const Icon(TgIcons.callsActive),
            label: l10n.calls,
          ),
          GlassTab(
            icon: const Icon(TgIcons.settings),
            activeIcon: const Icon(TgIcons.settingsActive),
            label: l10n.settings,
          ),
        ],
      ),
      // Only the selected tab is built. An IndexedStack keeps the others
      // mounted, and every glass surface they contain registers with the
      // scaffold's shared glass layer — which paints them all on top of each
      // other. Scroll positions survive anyway: each tab keeps its own
      // controller in this state.
      body: _bodyFor(_index),
    );
  }

  Widget _bodyFor(int index) {
    switch (index) {
      case 1:
        return ContactsBody(controller: _titleControllers[1]);
      case 2:
        return CallsBody(controller: _titleControllers[2]);
      case 3:
        return SettingsBody(controller: _titleControllers[3]);
      default:
        return ChatsBody(controller: _titleControllers[0]);
    }
  }

  Widget _appBarFor(int index) {
    switch (index) {
      case 1:
        return ContactsAppBar(controller: _titleControllers[1]);
      case 2:
        return CallsAppBar(controller: _titleControllers[2]);
      case 3:
        return SettingsAppBar(controller: _titleControllers[3]);
      default:
        return ChatsAppBar(controller: _titleControllers[0]);
    }
  }
}

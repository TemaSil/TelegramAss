import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_preferences.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/app_state.dart';
import '../common/tg_avatar.dart';
import '../common/wallpaper.dart';
import '../common/wallpaper_picker.dart';
import 'proxy_sheet.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';
import 'edit_profile_sheet.dart';
import 'sessions_screen.dart';

/// Nav bar for the Settings tab.
class SettingsAppBar extends StatelessWidget {
  const SettingsAppBar({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return GlassAppBar.pinned(
      toolbarHeight: 52,
      largeTitleController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(l10n.settings, style: TgText.navTitle(context)),
      actions: [
        // The popover's trigger is a glass button already, so the cluster
        // draws none of its own behind it.
        GlassBarItem.custom(
          id: 'about',
          background: GlassBarItemBackground.own,
          child: GlassPopover(
            popoverWidth: 250,
            popoverHeight: 150,
            quality: GlassTokens.heroQuality(context),
            settings: GlassTokens.menu(context),
            triggerBuilder: (context, toggle) => GlassIconButton(
              icon: const Icon(TgIcons.help, size: 20),
              size: 44,
              settings: GlassTokens.chrome(context),
              quality: GlassTokens.quality(context),
              onPressed: toggle,
            ),
            contentBuilder: (context, close) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.aboutTitle, style: TgText.rowTitle(context)),
                  const SizedBox(height: 8),
                  Text(l10n.aboutBody, style: TgText.rowPreview(context)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Profile card plus grouped preference sections.
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      controller: controller.scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topPad + 52)),
        GlassLargeTitle(
          text: l10n.settings,
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: _ProfileCard(state: state),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              header: Text(
                l10n.appearance,
                style: TgText.sectionHeader(context),
              ),
              children: [
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.wallpaper),
                  title: Text(l10n.wallpaper),
                  additionalInfo: Text(
                    GlassWallpaper.labels[state.wallpaper] ?? l10n.choose,
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => showWallpaperPicker(context, state),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.nightMode),
                  title: Text(l10n.autoNightMode),
                  subtitle: Text(l10n.autoNightModeSubtitle),
                  trailing: GlassSwitch(
                    value: state.autoNightMode,
                    onChanged: state.setAutoNightMode,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.language),
                  title: Text(l10n.language),
                  additionalInfo: Text(_languageLabel(state.language, l10n)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pickLanguage(context, state, l10n),
                ),
                if (!state.autoNightMode)
                  CupertinoListTile.notched(
                    leading: Icon(
                      state.darkMode
                          ? TgIcons.nightModeFilled
                          : TgIcons.lightMode,
                    ),
                    title: Text(l10n.darkMode),
                    trailing: GlassSwitch(
                      value: state.darkMode,
                      onChanged: state.setDarkMode,
                      settings: GlassTokens.chrome(context),
                      activeColor: TgColors.accent.resolveFrom(context),
                    ),
                  ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.transparency),
                  title: Text(l10n.reduceTransparency),
                  subtitle: Text(l10n.reduceTransparencySubtitle),
                  trailing: GlassSwitch(
                    value: state.reduceTransparency,
                    onChanged: state.setReduceTransparency,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              shape: const LiquidRoundedSuperellipse(
                borderRadius: GlassTokens.cardRadius,
              ),
              settings: GlassTokens.panel(context),
              quality: GlassTokens.quality(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        TgIcons.glass,
                        size: 19,
                        color: TgColors.accent.resolveFrom(context),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.surfaceMaterial,
                        style: TgText.rowTitle(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<GlassMaterial>(
                      groupValue: state.glassMaterial,
                      children: {
                        GlassMaterial.glass: Text(l10n.materialGlass),
                        GlassMaterial.blur: Text(l10n.materialBlur),
                      },
                      onValueChanged: (value) {
                        if (value != null) state.setGlassMaterial(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.glassMaterial == GlassMaterial.blur
                        ? l10n.materialBlurSubtitle
                        : l10n.materialGlassSubtitle,
                    style: TgText.rowPreview(context),
                  ),
                  const GlassDivider(height: 22),
                  Row(
                    children: [
                      Icon(
                        TgIcons.textSize,
                        size: 19,
                        color: TgColors.accent.resolveFrom(context),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.messageTextSize,
                        style: TgText.rowTitle(context),
                      ),
                      const Spacer(),
                      GlassStepper(
                        value: state.messageFontSize.toDouble(),
                        min: 12,
                        max: 22,
                        onChanged: (value) =>
                            state.setMessageFontSize(value.round()),
                        settings: GlassTokens.chrome(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.textSizeSample,
                    style: TgText.body(context)
                        .copyWith(fontSize: state.messageFontSize.toDouble()),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              header: Text(
                l10n.modSettings,
                style: TgText.sectionHeader(context),
              ),
              children: [
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.stories),
                  title: Text(l10n.showStories),
                  trailing: GlassSwitch(
                    value: state.showStories,
                    onChanged: state.setShowStories,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.reactions),
                  title: Text(l10n.doubleTapReaction),
                  additionalInfo: Text(
                    state.doubleTapReaction.isEmpty
                        ? l10n.reactionOff
                        : state.doubleTapReaction,
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pickDoubleTapReaction(context, state),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              header: Text(l10n.privacy, style: TgText.sectionHeader(context)),
              children: [
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.unmute),
                  title: Text(l10n.messageNotifications),
                  subtitle: Text(l10n.messageNotificationsSubtitle),
                  trailing: GlassSwitch(
                    value: state.notifications,
                    onChanged: state.setNotifications,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.receipts),
                  title: Text(l10n.readReceipts),
                  trailing: GlassSwitch(
                    value: state.readReceipts,
                    onChanged: state.setReadReceipts,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.privacy),
                  title: Text(l10n.twoStepVerification),
                  trailing: const CupertinoListTileChevron(),
                  // Signing in with an existing password works; setting or
                  // changing one does not, and a row that silently does
                  // nothing is worse than one that says so.
                  onTap: () => GlassDialog.show<void>(
                    context: context,
                    title: l10n.twoStepVerification,
                    message: l10n.notImplementedHere,
                    settings: GlassTokens.menu(context),
                    actions: [
                      GlassDialogAction(
                        label: l10n.ok,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.sessions),
                  title: Text(l10n.activeSessions),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const SessionsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              header: Text(
                l10n.connection,
                style: TgText.sectionHeader(context),
              ),
              children: [
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.proxy),
                  title: Text(l10n.proxy),
                  additionalInfo: Text(
                    state.proxy == null || !state.proxy!.enabled
                        ? l10n.proxyOff
                        : '${state.proxy!.server}:${state.proxy!.port}',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => showProxySheet(context, state),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              header: Text(l10n.backend, style: TgText.sectionHeader(context)),
              footer: Text(
                state.client.isLive ? l10n.backendLive : l10n.backendDemo,
                style: TgText.timestamp(context),
              ),
              children: [
                CupertinoListTile.notched(
                  leading: Icon(
                    state.client.isLive ? TgIcons.channel : TgIcons.demo,
                  ),
                  title: Text(l10n.mode),
                  trailing: Text(
                    state.client.backendName,
                    style: TgText.rowPreview(context),
                  ),
                ),
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.logOut),
                  title: Text(
                    l10n.logOut,
                    style: TextStyle(
                      color: TgColors.destructive.resolveFrom(context),
                    ),
                  ),
                  onTap: () => _confirmLogOut(context, state),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 96 + bottomPad)),
      ],
    );
  }

  static String _languageLabel(String code, AppL10n l10n) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ru':
        return 'Русский';
      default:
        return l10n.languageSystem;
    }
  }

  Future<void> _pickLanguage(
    BuildContext context,
    AppState state,
    AppL10n l10n,
  ) async {
    await showGlassActionSheet<void>(
      context: context,
      title: l10n.language,
      settings: GlassTokens.menu(context),
      quality: GlassTokens.heroQuality(context),
      actions: [
        for (final code in const ['system', 'en', 'ru'])
          GlassActionSheetAction(
            label: _languageLabel(code, l10n),
            icon: Icon(
              state.language == code ? TgIcons.selected : TgIcons.unselected,
            ),
            onPressed: () {
              state.setLanguage(code);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  /// Which emoji a double-tap sends, or none at all.
  Future<void> _pickDoubleTapReaction(
    BuildContext context,
    AppState state,
  ) async {
    final l10n = AppL10n.of(context);
    await showGlassActionSheet<void>(
      context: context,
      title: l10n.doubleTapReaction,
      settings: GlassTokens.menu(context),
      quality: GlassTokens.heroQuality(context),
      actions: [
        for (final emoji in const ['❤️', '👍', '🔥', '😂', '😮', ''])
          GlassActionSheetAction(
            label: emoji.isEmpty ? l10n.reactionOff : emoji,
            icon: Icon(
              state.doubleTapReaction == emoji
                  ? TgIcons.selected
                  : TgIcons.unselected,
            ),
            onPressed: () {
              state.setDoubleTapReaction(emoji);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  Future<void> _confirmLogOut(BuildContext context, AppState state) async {
    await GlassDialog.show<void>(
      context: context,
      title: AppL10n.of(context).logOutTitle,
      message: AppL10n.of(context).logOutMessage,
      settings: GlassTokens.menu(context),
      quality: GlassTokens.heroQuality(context),
      actions: [
        GlassDialogAction(
          label: AppL10n.of(context).cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: AppL10n.of(context).logOut,
          isDestructive: true,
          onPressed: () {
            Navigator.of(context).pop();
            state.logOut();
          },
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final me = state.me;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      shape: const LiquidRoundedSuperellipse(
        borderRadius: GlassTokens.cardRadius,
      ),
      settings: GlassTokens.panel(context),
      quality: GlassTokens.quality(context),
      child: Row(
        children: [
          TgAvatar(
            seed: me?.id ?? 0,
            initials: me?.initials ?? '?',
            size: 64,
            isOnline: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        me?.name ?? 'Not signed in',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: TgColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                    if (me?.isPremium ?? false) ...[
                      const SizedBox(width: 5),
                      Icon(
                        TgIcons.premium,
                        size: 15,
                        color: TgColors.accent.resolveFrom(context),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (me?.phone != null)
                  Text(me!.phone!, style: TgText.rowPreview(context)),
                if (me?.username != null)
                  Text(
                    '@${me!.username}',
                    style: TgText.rowPreview(context)
                        .copyWith(color: TgColors.accent.resolveFrom(context)),
                  ),
              ],
            ),
          ),
          GlassIconButton(
            icon: const Icon(TgIcons.edit, size: 18),
            size: 40,
            settings: GlassTokens.chrome(context),
            quality: GlassTokens.quality(context),
            onPressed: () => GlassModalSheet.show<void>(
              context: context,
              halfSize: 0.62,
              settings: GlassTokens.panel(context),
              quality: GlassTokens.heroQuality(context),
              builder: (_) => const EditProfileSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

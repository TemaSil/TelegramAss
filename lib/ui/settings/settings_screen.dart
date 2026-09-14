import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/app_state.dart';
import '../common/tg_avatar.dart';
import '../common/wallpaper.dart';

/// Nav bar for the Settings tab.
class SettingsAppBar extends StatelessWidget {
  const SettingsAppBar({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      toolbarHeight: 52,
      largeTitleController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text('Settings', style: TgText.navTitle(context)),
      actions: [
        GlassPopover(
          popoverWidth: 250,
          popoverHeight: 150,
          quality: GlassQuality.premium,
          settings: GlassTokens.menu(context),
          triggerBuilder: (context, toggle) => GlassIconButton(
            icon: const Icon(CupertinoIcons.question_circle, size: 20),
            size: 44,
            settings: GlassTokens.chrome(context),
            quality: GlassQuality.premium,
            onPressed: toggle,
          ),
          contentBuilder: (context, close) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('About this build', style: TgText.rowTitle(context)),
                const SizedBox(height: 8),
                Text(
                  'A Flutter Telegram client rendered with the iOS 26 Liquid '
                  'Glass material. Glass quality adapts to the device.',
                  style: TgText.rowPreview(context),
                ),
              ],
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
          text: 'Settings',
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
            child: GlassGroupedSection(
              header: Text('Appearance', style: TgText.sectionHeader(context)),
              settings: GlassTokens.panel(context),
              quality: GlassQuality.premium,
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.paintbrush),
                  title: const Text('Wallpaper'),
                  trailing: SizedBox(
                    width: 150,
                    child: GlassPicker(
                      value: GlassWallpaper.labels[state.wallpaper],
                      placeholder: 'Choose',
                      settings: GlassTokens.chrome(context),
                      onTap: () => _pickWallpaper(context, state),
                    ),
                  ),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.circle_lefthalf_fill),
                  title: const Text('Auto night mode'),
                  trailing: GlassSwitch(
                    value: state.autoNightMode,
                    onChanged: state.setAutoNightMode,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.eye_slash),
                  title: const Text('Reduce transparency'),
                  subtitle: const Text('Stops the wallpaper animation'),
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
              quality: GlassQuality.premium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.sparkles,
                        size: 19,
                        color: TgColors.accent.resolveFrom(context),
                      ),
                      const SizedBox(width: 10),
                      Text('Glass intensity', style: TgText.rowTitle(context)),
                      const Spacer(),
                      Text(
                        '${(state.glassIntensity * 100).round()}%',
                        style: TgText.rowPreview(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GlassSlider(
                    value: state.glassIntensity,
                    min: 0.2,
                    max: 1.0,
                    onChanged: state.setGlassIntensity,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                  const GlassDivider(height: 22),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.textformat_size,
                        size: 19,
                        color: TgColors.accent.resolveFrom(context),
                      ),
                      const SizedBox(width: 10),
                      Text('Message text size',
                          style: TgText.rowTitle(context)),
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
                    'The quick brown fox jumps over the lazy dog',
                    style: TgText.body(context).copyWith(
                      fontSize: state.messageFontSize.toDouble(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: GlassGroupedSection(
              header: Text('Privacy', style: TgText.sectionHeader(context)),
              settings: GlassTokens.panel(context),
              quality: GlassQuality.premium,
              children: [
                GlassListTile(
                  leading: const Icon(CupertinoIcons.checkmark_seal),
                  title: const Text('Read receipts'),
                  trailing: GlassSwitch(
                    value: state.readReceipts,
                    onChanged: state.setReadReceipts,
                    settings: GlassTokens.chrome(context),
                    activeColor: TgColors.accent.resolveFrom(context),
                  ),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.lock),
                  title: const Text('Two-step verification'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  onTap: () {},
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.device_phone_portrait),
                  title: const Text('Active sessions'),
                  trailing: GlassBadge(
                    count: 3,
                    settings: GlassTokens.chrome(context),
                    child: const Icon(CupertinoIcons.chevron_right, size: 16),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: GlassGroupedSection(
              header: Text('Backend', style: TgText.sectionHeader(context)),
              footer: Text(
                state.client.isLive
                    ? 'Connected through the official TDLib JSON interface.'
                    : 'Demo data. Pass --dart-define=TELEGRAM_API_ID and '
                        'TELEGRAM_API_HASH, and bundle libtdjson.so, to talk to '
                        'real Telegram servers.',
                style: TgText.timestamp(context),
              ),
              settings: GlassTokens.panel(context),
              quality: GlassQuality.premium,
              children: [
                GlassListTile(
                  leading: Icon(
                    state.client.isLive
                        ? CupertinoIcons.antenna_radiowaves_left_right
                        : CupertinoIcons.cube_box,
                  ),
                  title: const Text('Mode'),
                  trailing: Text(
                    state.client.backendName,
                    style: TgText.rowPreview(context),
                  ),
                ),
                GlassListTile(
                  leading: const Icon(CupertinoIcons.square_arrow_right),
                  title: Text(
                    'Log out',
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

  Future<void> _pickWallpaper(BuildContext context, AppState state) async {
    await showGlassActionSheet<void>(
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
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
            ),
            onPressed: () {
              state.setWallpaper(entry.key);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  Future<void> _confirmLogOut(BuildContext context, AppState state) async {
    await GlassDialog.show<void>(
      context: context,
      title: 'Log out?',
      message: 'You will need to sign in again to read your chats.',
      settings: GlassTokens.menu(context),
      quality: GlassQuality.premium,
      actions: [
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: 'Log out',
          isDestructive: true,
          onPressed: () {
            Navigator.of(context).pop();
            state.client.logOut();
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
      quality: GlassQuality.premium,
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
                        CupertinoIcons.star_fill,
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
                    style: TgText.rowPreview(context).copyWith(
                      color: TgColors.accent.resolveFrom(context),
                    ),
                  ),
              ],
            ),
          ),
          GlassIconButton(
            icon: const Icon(CupertinoIcons.pencil, size: 18),
            size: 40,
            settings: GlassTokens.chrome(context),
            quality: GlassQuality.premium,
            onPressed: () => GlassToast.show(
              context,
              message: 'Profile editing needs the live backend',
              type: GlassToastType.info,
            ),
          ),
        ],
      ),
    );
  }
}

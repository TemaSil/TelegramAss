import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../common/tg_avatar.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

/// Nav bar for the Calls tab.
class CallsAppBar extends StatelessWidget {
  const CallsAppBar({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      toolbarHeight: 52,
      largeTitleController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(AppL10n.of(context).calls, style: TgText.navTitle(context)),
      actions: [
        GlassIconButton(
          icon: const Icon(TgIcons.newCall, size: 20),
          size: 44,
          settings: GlassTokens.chrome(context),
          quality: GlassTokens.quality(context),
          onPressed: () => _explainCalls(context),
        ),
      ],
    );
  }
}

/// Recent calls, filtered by an All / Missed segmented control.
class CallsBody extends StatefulWidget {
  const CallsBody({super.key, required this.controller});

  final GlassLargeTitleController controller;

  @override
  State<CallsBody> createState() => _CallsBodyState();
}

class _CallsBodyState extends State<CallsBody> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppL10n.of(context);
    final calls = _filter == 1
        ? state.calls.where((call) => call.isMissed).toList()
        : state.calls;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      controller: widget.controller.scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topPad + 52)),
        GlassLargeTitle(
          text: l10n.calls,
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _filter,
                onValueChanged: (value) => setState(() => _filter = value ?? 0),
                children: {0: Text(l10n.all), 1: Text(l10n.missed)},
              ),
            ),
          ),
        ),
        if (calls.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: Center(
                child: Text(l10n.noCalls, style: TgText.rowPreview(context)),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                header: Text(
                  _filter == 1 ? l10n.missed : l10n.recent,
                  style: TgText.sectionHeader(context),
                ),
                children: [for (final call in calls) _CallTile(call: call)],
              ),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 96 + bottomPad)),
      ],
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});

  final TgCall call;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tint = call.isMissed
        ? TgColors.destructive.resolveFrom(context)
        : TgColors.secondaryLabel.resolveFrom(context);

    return CupertinoListTile.notched(
      leading: TgAvatar(
        seed: call.peerId,
        initials: call.peerName.substring(0, 1),
        size: 40,
      ),
      title: Text(
        call.peerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: call.isMissed
              ? TgColors.destructive.resolveFrom(context)
              : TgColors.label.resolveFrom(context),
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            call.isOutgoing ? TgIcons.callOutgoing : TgIcons.callIncoming,
            size: 13,
            color: tint,
          ),
          const SizedBox(width: 4),
          Text(
            call.isMissed
                ? l10n.missed
                : (call.duration == null
                      ? l10n.callCancelled
                      : TgFormat.duration(call.duration!)),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(TgFormat.callStamp(call.date), style: TgText.timestamp(context)),
          const SizedBox(width: 8),
          Icon(
            call.isVideo ? TgIcons.video : TgIcons.calls,
            size: 19,
            color: TgColors.accent.resolveFrom(context),
          ),
        ],
      ),
      onTap: () => _explainCalls(context),
    );
  }
}

/// Calls need tgcalls, a native stack TDLib does not carry. The history is
/// real; placing one is not, and saying so beats a button that does nothing.
Future<void> _explainCalls(BuildContext context) {
  final l10n = AppL10n.of(context);
  return GlassDialog.show<void>(
    context: context,
    title: l10n.call,
    message: l10n.callsUnavailable,
    settings: GlassTokens.menu(context),
    actions: [
      GlassDialogAction(
        label: l10n.ok,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

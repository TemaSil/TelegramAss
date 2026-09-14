import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../common/tg_avatar.dart';

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
      title: Text('Calls', style: TgText.navTitle(context)),
      actions: [
        GlassIconButton(
          icon: const Icon(CupertinoIcons.phone_badge_plus, size: 20),
          size: 44,
          settings: GlassTokens.chrome(context),
          quality: GlassQuality.premium,
          onPressed: () => GlassToast.show(
            context,
            message: 'Placing calls needs the live TDLib backend',
            type: GlassToastType.info,
          ),
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
          text: 'Calls',
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: GlassSegmentedControl(
              selectedIndex: _filter,
              onSegmentSelected: (index) => setState(() => _filter = index),
              height: 40,
              settings: GlassTokens.chrome(context),
              quality: GlassQuality.premium,
              indicatorColor:
                  TgColors.accent.resolveFrom(context).withValues(alpha: 0.22),
              selectedTextStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: TgColors.label.resolveFrom(context),
              ),
              unselectedTextStyle: TextStyle(
                fontSize: 14.5,
                color: TgColors.secondaryLabel.resolveFrom(context),
              ),
              segments: const [
                GlassSegment(label: 'All', id: 'all'),
                GlassSegment(label: 'Missed', id: 'missed'),
              ],
            ),
          ),
        ),
        if (calls.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: Center(
                child: Text('No calls here', style: TgText.rowPreview(context)),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassGroupedSection(
                header: Text(
                  _filter == 1 ? 'Missed' : 'Recent',
                  style: TgText.sectionHeader(context),
                ),
                settings: GlassTokens.panel(context),
                quality: GlassQuality.premium,
                children: [
                  for (final call in calls) _CallTile(call: call),
                ],
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
    final tint = call.isMissed
        ? TgColors.destructive.resolveFrom(context)
        : TgColors.secondaryLabel.resolveFrom(context);

    return GlassListTile(
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
            call.isOutgoing
                ? CupertinoIcons.arrow_up_right
                : CupertinoIcons.arrow_down_left,
            size: 13,
            color: tint,
          ),
          const SizedBox(width: 4),
          Text(
            call.isMissed
                ? 'Missed'
                : (call.duration == null
                    ? 'Cancelled'
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
            call.isVideo ? CupertinoIcons.videocam : CupertinoIcons.phone,
            size: 19,
            color: TgColors.accent.resolveFrom(context),
          ),
        ],
      ),
      onTap: () => GlassToast.show(
        context,
        message: 'Calling ${call.peerName}…',
        type: GlassToastType.info,
        icon: const Icon(CupertinoIcons.phone_fill, size: 17),
      ),
    );
  }
}

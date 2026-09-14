import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/glass_tokens.dart';
import '../../../core/tg_theme.dart';
import '../../../data/models.dart';
import '../../common/tg_avatar.dart';
import '../../../core/tg_icons.dart';

/// Horizontal stories strip above the chat list.
class StoryRail extends StatelessWidget {
  const StoryRail({super.key, required this.stories, required this.onOpen});

  final List<TgStory> stories;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = stories[index];
          final isOwn = index == 0;
          return GestureDetector(
            onTap: () => onOpen(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TgAvatar(
                      seed: story.seed,
                      initials: story.authorName.substring(0, 1),
                      size: 58,
                      hasStory: !isOwn,
                      storySeen: story.isSeen,
                    ),
                    if (isOwn)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GlassContainer(
                          width: 24,
                          height: 24,
                          shape: const LiquidOval(),
                          settings: GlassTokens.chrome(context).copyWith(
                            glassColor: TgColors.accent
                                .resolveFrom(context)
                                .withValues(alpha: 0.85),
                          ),
                          child: const Icon(
                            TgIcons.attach,
                            size: 14,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: 68,
                  child: Text(
                    story.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      letterSpacing: -0.1,
                      color: story.isSeen
                          ? TgColors.secondaryLabel.resolveFrom(context)
                          : TgColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../common/tg_avatar.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen story viewer.
///
/// Tap the right half to advance, the left half to go back; a timer advances
/// on its own. The chrome — progress bars, header, reply pill — is glass
/// floating over the story itself.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<TgStory> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 6);

  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: _storyDuration,
  );

  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _progressController.addStatusListener(_onProgressStatus);
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController
      ..removeStatusListener(_onProgressStatus)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _advance(1);
  }

  void _advance(int delta) {
    final next = _index + delta;
    if (next < 0) {
      _restart();
      return;
    }
    if (next >= widget.stories.length) {
      Navigator.of(context).maybePop();
      return;
    }
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _restart() {
    _progressController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];

    return GlassScaffold(
      backgroundColor: CupertinoColors.black,
      settings: GlassTokens.chrome(context),
      statusBarStyle: GlassStatusBarStyle.light,
      background: PageView.builder(
        controller: _pageController,
        itemCount: widget.stories.length,
        onPageChanged: (index) {
          setState(() => _index = index);
          _restart();
        },
        itemBuilder: (context, index) =>
            _StoryCanvas(story: widget.stories[index]),
      ),
      body: Stack(
        children: [
          // Tap zones: left third goes back, the rest advances.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _advance(-1),
                  onLongPress: _progressController.stop,
                  onLongPressUp: _progressController.forward,
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _advance(1),
                  onLongPress: _progressController.stop,
                  onLongPressUp: _progressController.forward,
                ),
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                _ProgressBars(
                  count: widget.stories.length,
                  current: _index,
                  animation: _progressController,
                ),
                _Header(
                  story: story,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (story.caption != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: const LiquidRoundedRectangle(borderRadius: 20),
                      settings: GlassTokens.panel(context),
                      child: Text(
                        story.caption!,
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassPageControl(
                    count: widget.stories.length,
                    currentPage: _index,
                    settings: GlassTokens.chrome(context),
                    activeColor: CupertinoColors.white,
                    onPageChanged: (page) => _pageController.animateToPage(
                      page,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ReplyBar(onSend: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The story "media" — a gradient stand-in, blurred at the top so the glass
/// chrome always has contrast under it.
class _StoryCanvas extends StatelessWidget {
  const _StoryCanvas({required this.story});

  final TgStory story;

  @override
  Widget build(BuildContext context) {
    final colors = TgColors.avatarGradient(story.seed);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.first, colors.last, CupertinoColors.black],
            ),
          ),
        ),
        // Blurs the strip the chrome sits on, so white text stays legible
        // whatever the story is showing.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 190,
          child: ProgressiveBlur(
            maxSigma: 14,
            direction: ProgressiveBlurDirection.bottomToTop,
          ),
        ),
      ],
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({
    required this.count,
    required this.current,
    required this.animation,
  });

  final int count;
  final int current;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final value = i < current
                        ? 1.0
                        : (i == current ? animation.value : 0.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          children: [
                            ColoredBox(
                              color: CupertinoColors.white.withValues(
                                alpha: 0.28,
                              ),
                              child: const SizedBox.expand(),
                            ),
                            FractionallySizedBox(
                              widthFactor: value,
                              child: const ColoredBox(
                                color: CupertinoColors.white,
                                child: SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.story, required this.onClose});

  final TgStory story;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Row(
        children: [
          TgAvatar(
            seed: story.seed,
            initials: story.authorName.substring(0, 1),
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              story.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
          GlassIconButton(
            icon: const Icon(TgIcons.close, size: 18),
            size: 38,
            settings: GlassTokens.chrome(context),
            quality: GlassQuality.premium,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              placeholder: AppL10n.of(context).replyToStory,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              style: const TextStyle(color: CupertinoColors.white),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(23),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GlassIconButton(
            icon: const Icon(TgIcons.heart, size: 20),
            size: 46,
            settings: GlassTokens.composer(context),
            quality: GlassQuality.premium,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

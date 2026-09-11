import 'package:flutter/cupertino.dart';

import '../../core/tg_theme.dart';

/// Gradient monogram avatar with optional story ring and presence dot.
class TgAvatar extends StatelessWidget {
  const TgAvatar({
    super.key,
    required this.seed,
    required this.initials,
    this.size = 52,
    this.isOnline = false,
    this.hasStory = false,
    this.storySeen = false,
    this.icon,
  });

  final int seed;
  final String initials;
  final double size;
  final bool isOnline;
  final bool hasStory;
  final bool storySeen;

  /// Replaces the monogram — used for Saved Messages and bots.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final gradient = TgColors.avatarGradient(seed);
    final ringWidth = hasStory ? 2.0 : 0.0;
    final inset = hasStory ? 4.0 : 0.0;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: size * 0.46, color: CupertinoColors.white)
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: CupertinoColors.white,
              ),
            ),
    );

    if (hasStory) {
      avatar = Container(
        width: size + inset * 2 + ringWidth * 2,
        height: size + inset * 2 + ringWidth * 2,
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: storySeen
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF34C759), Color(0xFF0A84FF)],
                ),
          border: storySeen
              ? Border.all(
                  color: TgColors.separator.resolveFrom(context),
                  width: ringWidth,
                )
              : null,
        ),
        child: Container(
          padding: EdgeInsets.all(ringWidth),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: avatar,
        ),
      );
    }

    if (!isOnline) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TgColors.teal.resolveFrom(context),
              border: Border.all(
                color: TgColors.background.resolveFrom(context),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

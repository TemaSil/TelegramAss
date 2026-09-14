import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Animated mesh-gradient wallpaper.
///
/// Glass only reads as glass when there is something worth refracting behind
/// it; a flat colour makes every surface look like a grey rectangle. Four
/// radial blobs drift on long, out-of-phase cycles so the blur and the
/// chromatic aberration have moving colour to work with.
class GlassWallpaper extends StatefulWidget {
  const GlassWallpaper({
    super.key,
    this.variant = 'aurora',
    this.animate = true,
  });

  /// One of the keys in [palettes].
  final String variant;
  final bool animate;

  /// The plain system background — the iOS default, and what the chat list,
  /// contacts, calls and settings always use.
  static const none = 'none';

  static const palettes = <String, List<Color>>{
    'aurora': [
      Color(0xFF3B2E7E),
      Color(0xFF1E5F8C),
      Color(0xFF7A2E6B),
      Color(0xFF14304F),
    ],
    'sunset': [
      Color(0xFF8C2F39),
      Color(0xFFB4552B),
      Color(0xFF5B2A6B),
      Color(0xFF2B1B3D),
    ],
    'mint': [
      Color(0xFF14564B),
      Color(0xFF1E7A6B),
      Color(0xFF2F6B8C),
      Color(0xFF0F2E33),
    ],
    'graphite': [
      Color(0xFF2B2B30),
      Color(0xFF3A3A42),
      Color(0xFF24242A),
      Color(0xFF17171B),
    ],
  };

  static const labels = <String, String>{
    none: 'None',
    'aurora': 'Aurora',
    'sunset': 'Sunset',
    'mint': 'Mint',
    'graphite': 'Graphite',
  };

  @override
  State<GlassWallpaper> createState() => _GlassWallpaperState();
}

class _GlassWallpaperState extends State<GlassWallpaper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(GlassWallpaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.of(context).brightness == Brightness.dark;

    if (widget.variant == GlassWallpaper.none) {
      return ColoredBox(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: const SizedBox.expand(),
      );
    }

    final colors =
        GlassWallpaper.palettes[widget.variant] ??
        GlassWallpaper.palettes['aurora']!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _MeshPainter(
            t: _controller.value,
            colors: colors,
            dark: dark,
          ),
          isComplex: true,
          willChange: widget.animate,
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({required this.t, required this.colors, required this.dark});

  final double t;
  final List<Color> colors;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base wash keeps the darkest corners from going fully black, which would
    // swallow the glass edge highlight.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [colors[3], colors[0]]
              : [
                  Color.lerp(colors[0], const Color(0xFFFFFFFF), 0.62)!,
                  Color.lerp(colors[3], const Color(0xFFFFFFFF), 0.72)!,
                ],
        ).createShader(rect),
    );

    final radius = size.longestSide * 0.62;
    for (var i = 0; i < colors.length; i++) {
      final phase = t * 2 * math.pi + i * math.pi / 2;
      final center = Offset(
        size.width * (0.5 + 0.34 * math.cos(phase + i)),
        size.height * (0.5 + 0.30 * math.sin(phase * 0.8 + i * 1.3)),
      );
      final color = dark
          ? colors[i].withValues(alpha: 0.55)
          : Color.lerp(
              colors[i],
              const Color(0xFFFFFFFF),
              0.45,
            )!.withValues(alpha: 0.55);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.dark != dark ||
      oldDelegate.colors != colors;
}

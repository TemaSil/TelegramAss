import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// iMessage-style entrance for a freshly arrived bubble.
///
/// A real spring simulation rather than a curve: the bubble grows out of the
/// side it belongs to, overshoots slightly and settles. Outgoing messages also
/// rise, which reads as the text leaving the composer.
class BubbleEntrance extends StatefulWidget {
  const BubbleEntrance({
    super.key,
    required this.child,
    required this.fromRight,
    this.enabled = true,
  });

  final Widget child;

  /// Outgoing bubbles grow from the right edge, incoming from the left.
  final bool fromRight;

  /// False for messages that were already on screen — they appear instantly.
  final bool enabled;

  @override
  State<BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<BubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    _controller.animateWith(SpringSimulation(GlassSpring.bouncy(), 0, 1, 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value.clamp(0.0, 1.4);
        final scale = 0.68 + 0.32 * t;
        final rise = (1 - t) * 18;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, rise),
            child: Transform.scale(
              scale: scale,
              alignment: widget.fromRight
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// The small "Delivered" / "Read" line iMessage puts under the last message
/// it sent. Only the final outgoing bubble of a thread carries it.
class DeliveryFootnote extends StatelessWidget {
  const DeliveryFootnote({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14, top: 2, bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            color: color,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

/// The iMessage bubble outline: fully rounded, except for a small notch on the
/// bottom corner of the side it came from — and only on the last bubble of a
/// run, which is what makes a group read as one turn in the conversation.
class BubbleShape extends ShapeBorder {
  const BubbleShape({
    required this.fromRight,
    required this.withTail,
    this.radius = 18,
  });

  final bool fromRight;
  final bool withTail;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = Radius.circular(radius);
    final tail = withTail ? const Radius.circular(5) : r;
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: r,
        topRight: r,
        bottomLeft: fromRight ? r : tail,
        bottomRight: fromRight ? tail : r,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      BubbleShape(fromRight: fromRight, withTail: withTail, radius: radius * t);
}

import 'package:flutter/material.dart';

class HynerMark extends StatelessWidget {
  const HynerMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Hyner logo',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter()),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * .25)),
      Paint()..color = const Color(0xFF6952D9),
    );
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .25, s * .23, s * .15, s * .54),
        Radius.circular(s * .035),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .60, s * .23, s * .15, s * .54),
        Radius.circular(s * .035),
      ),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * .35, s * .49)
        ..lineTo(s * .65, s * .35)
        ..lineTo(s * .65, s * .52)
        ..lineTo(s * .35, s * .66)
        ..close(),
      white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

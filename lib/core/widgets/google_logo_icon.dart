import 'package:flutter/material.dart';

/// Pixel-perfect vector official 4-color Google "G" icon
/// Rendered using Google's official brand SVG coordinates (18x18 viewport).
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: const _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Scale canvas uniformly to fit 18x18 official vector coordinates
    final double scale = size.width / 18.0;
    canvas.scale(scale, scale);

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // 1. Blue Section (Crossbar + Right Side)
    final Path bluePath = Path()
      ..moveTo(17.64, 9.2)
      ..cubicTo(17.64, 8.563, 17.583, 7.949, 17.476, 7.36)
      ..lineTo(9.0, 7.36)
      ..lineTo(9.0, 10.841)
      ..lineTo(13.844, 10.841)
      ..cubicTo(13.635, 11.966, 13.001, 12.919, 12.048, 13.558)
      ..lineTo(12.048, 15.816)
      ..lineTo(14.956, 15.816)
      ..cubicTo(16.658, 14.249, 17.64, 11.942, 17.64, 9.2)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // 2. Green Section (Bottom Curve)
    final Path greenPath = Path()
      ..moveTo(9.0, 18.0)
      ..cubicTo(11.43, 18.0, 13.467, 17.194, 14.956, 15.816)
      ..lineTo(12.048, 13.558)
      ..cubicTo(11.242, 14.098, 10.211, 14.418, 9.0, 14.418)
      ..cubicTo(6.656, 14.418, 4.672, 12.834, 3.964, 10.707)
      ..lineTo(0.957, 10.707)
      ..lineTo(0.957, 13.039)
      ..arcToPoint(
        const Offset(9.0, 18.0),
        radius: const Radius.circular(8.997),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // 3. Yellow Section (Left Curve)
    final Path yellowPath = Path()
      ..moveTo(3.964, 10.707)
      ..cubicTo(3.784, 10.167, 3.682, 9.59, 3.682, 9.0)
      ..cubicTo(3.682, 8.41, 3.784, 7.833, 3.964, 7.293)
      ..lineTo(3.964, 4.961)
      ..lineTo(0.957, 4.961)
      ..arcToPoint(
        const Offset(0.0, 9.0),
        radius: const Radius.circular(8.996),
        clockwise: false,
      )
      ..cubicTo(0.0, 10.452, 0.348, 11.827, 0.957, 13.039)
      ..lineTo(3.964, 10.707)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 4. Red Section (Top Curve)
    final Path redPath = Path()
      ..moveTo(9.0, 3.58)
      ..cubicTo(10.321, 3.58, 11.508, 4.034, 12.44, 4.925)
      ..lineTo(15.022, 2.345)
      ..cubicTo(13.463, 0.891, 11.426, 0.0, 9.0, 0.0)
      ..arcToPoint(
        const Offset(0.957, 4.961),
        radius: const Radius.circular(8.997),
        clockwise: false,
      )
      ..lineTo(3.964, 7.293)
      ..cubicTo(4.672, 5.166, 6.656, 3.58, 9.0, 3.58)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

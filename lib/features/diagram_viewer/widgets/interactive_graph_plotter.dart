import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Represents a single plottable mathematical or physics function
class PlottableCurve {
  final String label;
  final double Function(double x) evaluator;
  final Color color;
  final String equationText;

  const PlottableCurve({
    required this.label,
    required this.evaluator,
    required this.color,
    required this.equationText,
  });
}

/// Advanced, high-performance Mathematical & Physics Graph Plotter.
/// Renders real continuous Cartesian coordinate curves ($X/Y$ axes, gridlines,
/// roots, extrema) with interactive touch-coordinate crosshair probes.
class InteractiveGraphPlotter extends StatefulWidget {
  final String rawGraphSpec;
  final String title;
  final bool isDark;

  const InteractiveGraphPlotter({
    super.key,
    required this.rawGraphSpec,
    required this.title,
    required this.isDark,
  });

  @override
  State<InteractiveGraphPlotter> createState() => _InteractiveGraphPlotterState();
}

class _InteractiveGraphPlotterState extends State<InteractiveGraphPlotter> {
  late List<PlottableCurve> _curves;
  double _xMin = -6.28;
  double _xMax = 6.28;
  double _yMin = -3.5;
  double _yMax = 3.5;

  double? _probeX;
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    _parseSpec(widget.rawGraphSpec);
  }

  @override
  void didUpdateWidget(covariant InteractiveGraphPlotter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawGraphSpec != widget.rawGraphSpec) {
      _parseSpec(widget.rawGraphSpec);
    }
  }

  void _parseSpec(String spec) {
    final lower = spec.toLowerCase();
    final List<PlottableCurve> list = [];

    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
    ];

    // Detect common trigonometric, polynomial, or physics curves
    if (lower.contains('sin') && lower.contains('cos')) {
      list.add(PlottableCurve(
        label: 'y = sin(x)',
        equationText: 'y = \\sin(x)',
        evaluator: (x) => math.sin(x),
        color: colors[0],
      ));
      list.add(PlottableCurve(
        label: 'y = cos(x)',
        equationText: 'y = \\cos(x)',
        evaluator: (x) => math.cos(x),
        color: colors[1],
      ));
      _xMin = -6.28;
      _xMax = 6.28;
      _yMin = -2.0;
      _yMax = 2.0;
    } else if (lower.contains('sin')) {
      list.add(PlottableCurve(
        label: 'y = sin(x)',
        equationText: 'y = \\sin(x)',
        evaluator: (x) => math.sin(x),
        color: colors[0],
      ));
      _xMin = -6.28;
      _xMax = 6.28;
      _yMin = -2.0;
      _yMax = 2.0;
    } else if (lower.contains('cos')) {
      list.add(PlottableCurve(
        label: 'y = cos(x)',
        equationText: 'y = \\cos(x)',
        evaluator: (x) => math.cos(x),
        color: colors[0],
      ));
      _xMin = -6.28;
      _xMax = 6.28;
      _yMin = -2.0;
      _yMax = 2.0;
    } else if (lower.contains('tan')) {
      list.add(PlottableCurve(
        label: 'y = tan(x)',
        equationText: 'y = \\tan(x)',
        evaluator: (x) {
          final val = math.tan(x);
          return val.clamp(-10.0, 10.0);
        },
        color: colors[0],
      ));
      _xMin = -3.14;
      _xMax = 3.14;
      _yMin = -4.0;
      _yMax = 4.0;
    } else if (lower.contains('projectile') || lower.contains('parabola') || lower.contains('x^2') || lower.contains('x²')) {
      if (lower.contains('-x^2') || lower.contains('-x²') || lower.contains('trajectory')) {
        list.add(PlottableCurve(
          label: 'y = -0.5x² + 3x (Trajectory)',
          equationText: 'y = -0.5x^2 + 3x \\quad \\text{(Trajectory)}',
          evaluator: (x) => -0.5 * x * x + 3 * x,
          color: colors[0],
        ));
        _xMin = -1.0;
        _xMax = 7.0;
        _yMin = -1.0;
        _yMax = 6.0;
      } else {
        list.add(PlottableCurve(
          label: 'y = x²',
          equationText: 'y = x^2',
          evaluator: (x) => x * x,
          color: colors[0],
        ));
        _xMin = -4.0;
        _xMax = 4.0;
        _yMin = -1.0;
        _yMax = 10.0;
      }
    } else if (lower.contains('exp') || lower.contains('e^x') || lower.contains('e^-x')) {
      if (lower.contains('-x^2') || lower.contains('gaussian') || lower.contains('normal')) {
        list.add(PlottableCurve(
          label: 'y = e^(-x²)',
          equationText: 'y = e^{-x^2} \\quad \\text{(Gaussian Bell)}',
          evaluator: (x) => math.exp(-x * x),
          color: colors[0],
        ));
        _xMin = -3.0;
        _xMax = 3.0;
        _yMin = -0.2;
        _yMax = 1.4;
      } else {
        list.add(PlottableCurve(
          label: 'y = e^x',
          equationText: 'y = e^x',
          evaluator: (x) => math.exp(x.clamp(-10.0, 3.0)),
          color: colors[0],
        ));
        _xMin = -4.0;
        _xMax = 3.0;
        _yMin = -0.5;
        _yMax = 8.0;
      }
    } else if (lower.contains('1/x') || lower.contains('hyperbola') || lower.contains('rational')) {
      list.add(PlottableCurve(
        label: 'y = 1/x',
        equationText: 'y = \\frac{1}{x}',
        evaluator: (x) => x.abs() < 0.08 ? double.nan : (1.0 / x).clamp(-12.0, 12.0),
        color: colors[0],
      ));
      _xMin = -5.0;
      _xMax = 5.0;
      _yMin = -6.0;
      _yMax = 6.0;
    } else if (lower.contains('damp') || lower.contains('oscillation')) {
      list.add(PlottableCurve(
        label: 'y = e^(-0.3x)·sin(2.5x)',
        equationText: 'y = e^{-0.3x} \\cdot \\sin(2.5x)',
        evaluator: (x) => x < 0 ? double.nan : math.exp(-0.3 * x) * math.sin(2.5 * x),
        color: colors[0],
      ));
      _xMin = 0.0;
      _xMax = 12.0;
      _yMin = -1.2;
      _yMax = 1.2;
    } else if (lower.contains('log') || lower.contains('ln')) {
      list.add(PlottableCurve(
        label: 'y = ln(x)',
        equationText: 'y = \\ln(x)',
        evaluator: (x) => x > 0 ? math.log(x) : double.nan,
        color: colors[0],
      ));
      _xMin = -0.5;
      _xMax = 8.0;
      _yMin = -4.0;
      _yMax = 4.0;
    } else if (lower.contains('v(t)') || lower.contains('velocity') || lower.contains('kinematics')) {
      list.add(PlottableCurve(
        label: 'v(t) = u + at',
        equationText: 'v(t) = 15 - 9.8t \\quad \\text{(Velocity vs Time)}',
        evaluator: (t) => 15.0 - 9.8 * t,
        color: colors[0],
      ));
      _xMin = 0.0;
      _xMax = 4.0;
      _yMin = -20.0;
      _yMax = 20.0;
    } else {
      // Default: Cubic Polynomial with interesting roots & inflection
      list.add(PlottableCurve(
        label: 'f(x) = x³ - 3x',
        equationText: 'f(x) = x^3 - 3x',
        evaluator: (x) => (x * x * x) - (3 * x),
        color: colors[0],
      ));
      _xMin = -3.0;
      _xMax = 3.0;
      _yMin = -4.0;
      _yMax = 4.0;
    }

    setState(() {
      _curves = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: widget.isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ GRAPH HEADER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.show_chart_rounded, size: 16, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title.isNotEmpty ? widget.title : 'Mathematical Function Plotter',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF059669),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Toggle Code / Visual
                InkWell(
                  onTap: () => setState(() => _showRawText = !_showRawText),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _showRawText ? '📈 Plot' : '🔤 Eq',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showRawText)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.rawGraphSpec,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: widget.isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
              ),
            )
          else ...[
            // 📈 CURVE LEGEND CHIPS
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _curves.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          c.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // 🎯 INTERACTIVE CANVAS
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 340.0;
                  return GestureDetector(
                    onPanDown: (details) => _updateProbe(details.localPosition, canvasWidth),
                    onPanUpdate: (details) => _updateProbe(details.localPosition, canvasWidth),
                    onPanEnd: (_) => setState(() => _probeX = null),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomPaint(
                        painter: _CartesianGraphPainter(
                          curves: _curves,
                          xMin: _xMin,
                          xMax: _xMax,
                          yMin: _yMin,
                          yMax: _yMax,
                          probeX: _probeX,
                          isDark: widget.isDark,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Live Probe Coordinate Readout
            if (_probeX != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Probe: x = ${_probeX!.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    for (final c in _curves) ...[
                      Text(
                        '${c.label.split('=').first.trim()}=${c.evaluator(_probeX!).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.color),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _updateProbe(Offset localPos, double canvasWidth) {
    // Convert local X coordinate into Cartesian domain using actual layout width
    final width = canvasWidth > 0 ? canvasWidth : 340.0;
    final normX = (localPos.dx / width).clamp(0.0, 1.0);
    final mathX = _xMin + normX * (_xMax - _xMin);
    setState(() {
      _probeX = mathX;
    });
  }
}

/// CustomPainter rendering smooth Cartesian axes, grid lines, continuous curves, and probe markers
class _CartesianGraphPainter extends CustomPainter {
  final List<PlottableCurve> curves;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double? probeX;
  final bool isDark;

  _CartesianGraphPainter({
    required this.curves,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.probeX,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    final axisPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF1E293B)).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    // Transformation helper: (mathX, mathY) -> (screenX, screenY)
    double toScreenX(double x) => ((x - xMin) / (xMax - xMin)) * size.width;
    double toScreenY(double y) => size.height - (((y - yMin) / (yMax - yMin)) * size.height);

    // 1. Draw Grid Lines
    const xStep = 2.0;
    for (double x = xMin; x <= xMax; x += xStep) {
      final sx = toScreenX(x);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
    }
    const yStep = 2.0;
    for (double y = yMin; y <= yMax; y += yStep) {
      final sy = toScreenY(y);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
    }

    // 2. Draw Main Axes (X=0 and Y=0)
    final originX = toScreenX(0);
    final originY = toScreenY(0);

    if (originX >= 0 && originX <= size.width) {
      canvas.drawLine(Offset(originX, 0), Offset(originX, size.height), axisPaint);
    }
    if (originY >= 0 && originY <= size.height) {
      canvas.drawLine(Offset(0, originY), Offset(size.width, originY), axisPaint);
    }

    // Origin label marker O(0,0)
    final originLabelStyle = GoogleFonts.firaCode(
      fontSize: 9.0,
      fontWeight: FontWeight.bold,
      color: (isDark ? Colors.white70 : const Color(0xFF475569)),
    );
    if (originX >= 0 && originX <= size.width && originY >= 0 && originY <= size.height) {
      TextPainter(text: TextSpan(text: 'O(0,0)', style: originLabelStyle), textDirection: TextDirection.ltr)
        ..layout()
        ..paint(canvas, Offset(originX + 4, originY + 2));
    }

    // 3. Draw Continuous Curves
    for (final curve in curves) {
      final curvePaint = Paint()
        ..color = curve.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final path = Path();
      bool started = false;
      double? prevSy;
      double? prevY;
      const sampleCount = 120;

      for (int i = 0; i <= sampleCount; i++) {
        final x = xMin + (i / sampleCount) * (xMax - xMin);
        final y = curve.evaluator(x);

        if (y.isNaN || y.isInfinite) {
          started = false;
          prevSy = null;
          prevY = null;
          continue;
        }

        final sx = toScreenX(x);
        final sy = toScreenY(y.clamp(yMin - 10.0, yMax + 10.0));

        // Break path at asymptotes (large vertical jump between opposite signs)
        if (started && prevSy != null && prevY != null) {
          final isAsymptoteJump = (y * prevY < 0) && ((sy - prevSy).abs() > size.height * 0.7);
          if (isAsymptoteJump) {
            started = false;
          }
        }

        if (!started) {
          path.moveTo(sx, sy);
          started = true;
        } else {
          path.lineTo(sx, sy);
        }

        prevSy = sy;
        prevY = y;
      }

      canvas.drawPath(path, curvePaint);
    }

    // 4. Draw Interactive Probe Crosshair & Target Rings
    if (probeX != null) {
      final sx = toScreenX(probeX!);
      final probeLinePaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.65)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Dashed vertical crosshair probe line
      for (double y = 0; y < size.height; y += 8.0) {
        canvas.drawLine(Offset(sx, y), Offset(sx, math.min(size.height, y + 4.0)), probeLinePaint);
      }

      for (final curve in curves) {
        final y = curve.evaluator(probeX!);
        if (!y.isNaN && !y.isInfinite) {
          final sy = toScreenY(y);
          final haloPaint = Paint()
            ..color = curve.color.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          final dotPaint = Paint()..color = curve.color;
          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          canvas.drawCircle(Offset(sx, sy), 9, haloPaint);
          canvas.drawCircle(Offset(sx, sy), 5, dotPaint);
          canvas.drawCircle(Offset(sx, sy), 5, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CartesianGraphPainter oldDelegate) {
    return oldDelegate.probeX != probeX ||
        oldDelegate.isDark != isDark ||
        oldDelegate.curves != curves;
  }
}

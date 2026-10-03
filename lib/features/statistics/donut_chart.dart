import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/naroo_colors.dart';

/// Animated donut. Slices follow [values] order clockwise from 12 o'clock.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.center,
    required this.semanticsLabel,
    this.selected,
    this.onSliceTap,
  });

  final List<int> values;
  final List<Color> colors;
  final Widget center;
  final String semanticsLabel;
  final int? selected;
  final ValueChanged<int>? onSliceTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final geometry = _DonutGeometry(constraints.biggest);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onSliceTap == null
                  ? null
                  : (details) {
                      final index = geometry.indexAt(
                        details.localPosition,
                        values,
                      );
                      if (index != null) onSliceTap!(index);
                    },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) => CustomPaint(
                  painter: _DonutPainter(
                    values: values,
                    colors: colors,
                    selected: selected,
                    progress: progress,
                    geometry: geometry,
                  ),
                  child: child,
                ),
                child: Center(
                  child: SizedBox(
                    width: geometry.innerRadius * 1.6,
                    child: FittedBox(fit: BoxFit.scaleDown, child: center),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DonutGeometry {
  _DonutGeometry(Size size)
    : center = size.center(Offset.zero),
      outerRadius = size.shortestSide / 2 - _highlight;

  static const _highlight = 6.0;

  final Offset center;
  final double outerRadius;
  double get thickness => outerRadius * 0.3;
  double get innerRadius => outerRadius - thickness;

  int? indexAt(Offset position, List<int> values) {
    final offset = position - center;
    final distance = offset.distance;
    if (distance < innerRadius - 4 || distance > outerRadius + _highlight) {
      return null;
    }
    final total = values.fold(0, (t, v) => t + v);
    if (total <= 0) return null;
    var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final target = angle / (2 * math.pi) * total;
    var cumulative = 0;
    for (final (index, value) in values.indexed) {
      cumulative += value;
      if (target < cumulative) return index;
    }
    return values.length - 1;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.selected,
    required this.progress,
    required this.geometry,
  });

  final List<int> values;
  final List<Color> colors;
  final int? selected;
  final double progress;
  final _DonutGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = geometry.outerRadius - geometry.thickness / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.thickness
      ..color = NarooColors.surfaceMuted;
    canvas.drawCircle(geometry.center, radius, track);

    final total = values.fold(0, (t, v) => t + v);
    if (total <= 0) return;
    final gap = values.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (final (index, value) in values.indexed) {
      final sweep = 2 * math.pi * value / total * progress;
      final isSelected = index == selected;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            geometry.thickness + (isSelected ? _DonutGeometry._highlight : 0)
        ..color = colors[index];
      final slice = math.max(sweep - gap, sweep * 0.4);
      canvas.drawArc(
        Rect.fromCircle(
          center: geometry.center,
          radius: radius + (isSelected ? _DonutGeometry._highlight / 2 : 0),
        ),
        start + (sweep - slice) / 2,
        slice,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.values != values ||
      old.colors != colors;
}

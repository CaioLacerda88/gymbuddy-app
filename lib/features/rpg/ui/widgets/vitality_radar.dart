import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/body_part.dart';
import '../../models/character_sheet_state.dart';
import '../../models/vitality_state.dart';

/// Hexagonal Vitality radar — six vertices, one per active body part.
///
/// **Layout direction (per kickoff lock):** ranks render as a polygon whose
/// vertex distance from center is `rank/99`. Outer reference hexagon (at
/// rank 99) is drawn faintly so day-0 users still see a "shape to fill in"
/// rather than an empty canvas. Day-0 itself collapses to a tiny center
/// dot — visually intentional, not a void.
///
/// **Why not a stat-bar grid:** the kickoff explicitly rejected six identical
/// horizontal rows because it reads as a tax form. The radar gives identity:
/// the user sees their build's silhouette at a glance — wide hexagon = balanced
/// (Ascendant), spike on one axis = specialist class. Codex rows beneath the
/// radar carry the per-body-part numbers; the radar carries the shape.
///
/// Vertex order is the canonical [activeBodyParts] order (Chest, Back, Legs,
/// Shoulders, Arms, Core), placed clockwise from the top.
class VitalityRadar extends StatelessWidget {
  const VitalityRadar({super.key, required this.entries, this.size = 320});

  /// Sheet entries in [activeBodyParts] order. Caller is responsible for
  /// passing exactly six entries — the painter assumes a hexagon.
  final List<BodyPartSheetEntry> entries;

  /// Square edge length of the radar canvas.
  final double size;

  @override
  Widget build(BuildContext context) {
    assert(entries.length == 6, 'VitalityRadar expects 6 entries');
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _VitalityRadarPainter(entries: entries),
      ),
    );
  }
}

class _VitalityRadarPainter extends CustomPainter {
  _VitalityRadarPainter({required this.entries});

  final List<BodyPartSheetEntry> entries;

  // Padding from the canvas edge so labels can sit just outside the
  // outer hexagon without clipping.
  static const double _padding = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - _padding;

    // Three concentric reference hexagons at 33%/66%/100% (visual depth cues).
    for (var step = 1; step <= 3; step++) {
      final r = outerRadius * (step / 3);
      _drawHex(
        canvas,
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.hair,
      );
    }

    // Spokes from center to each vertex.
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.hair;
    for (var i = 0; i < 6; i++) {
      final angle = _angleFor(i);
      final tip = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(center, tip, spokePaint);
    }

    // Inner filled polygon — vertex distance = rank/99.
    final fillPath = Path();
    for (var i = 0; i < 6; i++) {
      final entry = entries[i];
      final fraction = (entry.rank / 99).clamp(0.0, 1.0);
      // Day-0 floor at 0.02 so the polygon collapses to a tiny but
      // visible dot rather than a single point.
      final r = outerRadius * math.max(fraction, 0.02);
      final angle = _angleFor(i);
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        fillPath.moveTo(pt.dx, pt.dy);
      } else {
        fillPath.lineTo(pt.dx, pt.dy);
      }
    }
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.hotViolet.withValues(alpha: 0.4),
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primaryViolet,
    );

    // Vertex dots — small filled circles colored by the body part's
    // vitality state. Drawn last so they sit on top of the polygon.
    for (var i = 0; i < 6; i++) {
      final entry = entries[i];
      final fraction = (entry.rank / 99).clamp(0.0, 1.0);
      final r = outerRadius * math.max(fraction, 0.02);
      final angle = _angleFor(i);
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      canvas.drawCircle(
        pt,
        4,
        Paint()..color = entry.vitalityState.borderColor,
      );
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = _angleFor(i);
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Vertex angles in radians, starting at the top (-π/2) and proceeding
  /// clockwise. Six even-spaced vertices.
  double _angleFor(int i) => -math.pi / 2 + (i * math.pi / 3);

  @override
  bool shouldRepaint(covariant _VitalityRadarPainter oldDelegate) {
    if (oldDelegate.entries.length != entries.length) return true;
    for (var i = 0; i < entries.length; i++) {
      if (oldDelegate.entries[i].rank != entries[i].rank) return true;
      if (oldDelegate.entries[i].vitalityState != entries[i].vitalityState) {
        return true;
      }
    }
    return false;
  }
}

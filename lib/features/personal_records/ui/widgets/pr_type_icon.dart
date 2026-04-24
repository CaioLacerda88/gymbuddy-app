import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../models/record_type.dart';

/// 18dp glyph that represents a [RecordType] in PR chips/rows.
///
/// `maxWeight` uses the Arcane [AppIcons.lift] signature glyph; the other
/// two types still use Material icons until we ship SVG equivalents.
// TODO(icon-set-v2): add AppIcons.repeat + AppIcons.barChart and drop the
// Material icon fallback below.
class PRTypeIcon extends StatelessWidget {
  const PRTypeIcon({required this.type, required this.color, super.key});

  final RecordType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (type == RecordType.maxWeight) {
      return AppIcons.render(AppIcons.lift, size: 18, color: color);
    }
    return Icon(
      switch (type) {
        RecordType.maxReps => Icons.repeat,
        RecordType.maxVolume => Icons.bar_chart,
        RecordType.maxWeight => Icons.fitness_center, // unreachable
      },
      size: 18,
      color: color,
    );
  }
}

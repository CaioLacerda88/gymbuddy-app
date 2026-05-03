import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/profile_providers.dart';

/// Two-segment toggle (kg / lbs) bound to the profile's `weightUnit` field.
///
/// Tapping the inactive segment fires `toggleWeightUnit` on the profile
/// notifier; tapping the active segment is a no-op.
class WeightUnitToggle extends ConsumerWidget {
  const WeightUnitToggle({super.key, required this.weightUnit});

  final String weightUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'kg',
          label: Semantics(
            container: true,
            identifier: 'profile-kg',
            child: const Text('kg'),
          ),
        ),
        ButtonSegment(
          value: 'lbs',
          label: Semantics(
            container: true,
            identifier: 'profile-lbs',
            child: const Text('lbs'),
          ),
        ),
      ],
      selected: {weightUnit},
      onSelectionChanged: (selection) {
        final selected = selection.first;
        if (selected != weightUnit) {
          ref.read(profileProvider.notifier).toggleWeightUnit();
        }
      },
    );
  }
}

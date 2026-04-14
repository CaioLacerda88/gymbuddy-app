// Shared Flutter test finders used across widget tests. Centralising these
// keeps widget rendering invariants in one place — if the bullet size, shape,
// or any other structural detail ever changes, tests across every feature
// update in lock-step rather than silently drifting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matches the 6x6 circular form-tip bullet rendered by
/// `ExerciseFormTipsSection` (the P9 replacement for the earlier
/// `check_circle_outline` icon).
///
/// The container's `width`/`height` constructor arguments translate into a
/// tight `BoxConstraints`, so we assert on both the `BoxDecoration` shape and
/// those constraints. That prevents accidental matches on other circular
/// decorations elsewhere in the widget tree.
Finder findBulletDots() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration || decoration.shape != BoxShape.circle) {
      return false;
    }
    final constraints = widget.constraints;
    if (constraints == null) return false;
    return constraints.maxWidth == 6 && constraints.maxHeight == 6;
  });
}

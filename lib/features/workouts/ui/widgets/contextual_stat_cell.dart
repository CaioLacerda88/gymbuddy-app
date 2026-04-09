import 'package:flutter/material.dart';

import '../../../../core/theme/radii.dart';

/// A compact, tappable stat cell used for contextual information on the
/// home screen (e.g. "Last session: 3 days ago -- Push Day").
///
/// Displays a [label] (small, muted) above a [value] (prominent) inside a
/// card-colored container. Optionally accepts [onTap] for navigation.
class ContextualStatCell extends StatelessWidget {
  const ContextualStatCell({
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  /// Small muted header text (e.g. "Last session", "This week's volume").
  final String label;

  /// Primary value text (e.g. "3 days ago -- Push Day", "12,400 kg").
  final String value;

  /// Called when the cell is tapped. Pass null for non-interactive cells.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$label: $value',
      button: onTap != null,
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusMd),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

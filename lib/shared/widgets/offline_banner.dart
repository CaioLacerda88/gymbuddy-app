import 'package:flutter/material.dart';

/// A banner shown at the top of the app when the device is offline.
///
/// Uses [ColorScheme.errorContainer] background with [ColorScheme.onErrorContainer]
/// foreground to clearly signal degraded connectivity without being alarming.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: colorScheme.errorContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 16, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            "Offline \u2014 changes will sync when you're back online",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

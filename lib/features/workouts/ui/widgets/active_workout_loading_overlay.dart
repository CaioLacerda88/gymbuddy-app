import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/workout_providers.dart';

/// Loading overlay shown during async operations (finish/discard workout).
///
/// Initially shows only a spinner. After [_cancelTimeout] seconds a "Cancel"
/// button appears so the user is not permanently trapped if the network stalls.
///
/// [hasRestorable] indicates whether the notifier has a previous valid state
/// to restore. When false (initial Hive load), the cancel button is never
/// shown because there is nothing to restore to.
class ActiveWorkoutLoadingOverlay extends ConsumerStatefulWidget {
  const ActiveWorkoutLoadingOverlay({required this.hasRestorable, super.key});

  final bool hasRestorable;

  @override
  ConsumerState<ActiveWorkoutLoadingOverlay> createState() =>
      _ActiveWorkoutLoadingOverlayState();
}

class _ActiveWorkoutLoadingOverlayState
    extends ConsumerState<ActiveWorkoutLoadingOverlay> {
  /// Duration before the cancel button appears.
  static const _cancelTimeout = Duration(seconds: 10);

  bool _showCancel = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_cancelTimeout, () {
      if (mounted) setState(() => _showCancel = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrim over the active-workout surface while the overlay loads.
        // abyss (#0D0319) at ~54% alpha as the dim-out layer.
        ModalBarrier(
          dismissible: false,
          color: AppColors.abyss.withValues(alpha: 0.54),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_showCancel && widget.hasRestorable) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    ref.read(activeWorkoutProvider.notifier).cancelLoading();
                  },
                  child: Text(
                    AppLocalizations.of(context).cancel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

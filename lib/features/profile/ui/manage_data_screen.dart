import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../auth/providers/notifiers/auth_notifier.dart';
import '../../workouts/providers/workout_history_providers.dart'
    show workoutCountProvider;
import '../providers/manage_data_providers.dart';

class ManageDataScreen extends ConsumerWidget {
  const ManageDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workoutCount = ref.watch(workoutCountProvider);

    final workoutCountValue = workoutCount.value ?? 0;

    final workoutCountText = workoutCount.when(
      data: (v) => '$v',
      loading: () => '...',
      error: (_, _) => '0',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WORKOUT HISTORY section
            Text(
              'WORKOUT HISTORY',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            _DataManagementTile(
              title: 'Delete Workout History',
              subtitle: '$workoutCountText workouts will be removed',
              onTap: () =>
                  _showDeleteHistoryDialog(context, ref, workoutCountValue),
            ),
            const SizedBox(height: 24),
            // DANGER section
            Text(
              'DANGER',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            _DataManagementTile(
              title: 'Reset All Account Data',
              subtitle: 'Removes everything. Permanent.',
              onTap: () => _showResetAllModal(context, ref),
              danger: true,
              titleStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _DataManagementTile(
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and all data',
              onTap: () => _showDeleteAccountModal(context, ref),
              danger: true,
              titleStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteHistoryDialog(
    BuildContext context,
    WidgetRef ref,
    int workoutCount,
  ) async {
    final theme = Theme.of(context);

    // First dialog
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all workout history?'),
        content: Text(
          'This will permanently delete all $workoutCount workouts '
          'and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete History'),
          ),
        ],
      ),
    );

    if (first != true || !context.mounted) return;

    // Second dialog
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Your personal records and routines will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (second != true || !context.mounted) return;

    HapticFeedback.heavyImpact();
    try {
      await clearWorkoutHistory(ref);
    } on AppException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear history: ${e.userMessage}')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Workout history cleared')));
  }

  Future<void> _showResetAllModal(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ResetAllDialog(),
    );

    if (confirmed != true || !context.mounted) return;

    HapticFeedback.heavyImpact();
    try {
      await resetAllAccountData(ref);
    } on AppException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reset data: ${e.userMessage}')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account data reset')));
  }

  Future<void> _showDeleteAccountModal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DeleteAccountDialog(),
    );

    if (confirmed != true || !context.mounted) return;

    HapticFeedback.heavyImpact();

    // Show a non-dismissible loading dialog while the Edge Function call is
    // in flight (1-3s typical). Prevents the user from tapping other
    // destructive actions or navigating away mid-delete.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    await ref.read(authNotifierProvider.notifier).deleteAccount();

    if (!context.mounted) return;
    // Dismiss the loading dialog via the root navigator so we pop the
    // dialog route rather than the underlying screen.
    Navigator.of(context, rootNavigator: true).pop();

    // AsyncValue.guard captures exceptions inside the notifier state, so we
    // inspect it after the call rather than using try/catch.
    final state = ref.read(authNotifierProvider);
    final error = state.error;
    if (error != null) {
      final message = error is AppException
          ? error.userMessage
          : 'Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $message')),
      );
      return;
    }
    // On success, the auth state listener will redirect to login — no
    // snackbar needed since the screen is about to be unmounted.
  }
}

/// Reusable tile for data management options.
class _DataManagementTile extends StatelessWidget {
  const _DataManagementTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.titleStyle,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = danger
        ? theme.colorScheme.error.withValues(alpha: 0.12)
        : theme.cardTheme.color ?? theme.colorScheme.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: titleStyle),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class _ResetAllDialog extends StatefulWidget {
  const _ResetAllDialog();

  @override
  State<_ResetAllDialog> createState() => _ResetAllDialogState();
}

class _ResetAllDialogState extends State<_ResetAllDialog> {
  final _controller = TextEditingController();
  bool _isResetTyped = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final typed = _controller.text.trim().toUpperCase() == 'RESET';
    if (typed != _isResetTyped) {
      setState(() => _isResetTyped = typed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reset Account Data'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: 'Cancel',
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'This will permanently delete all workouts and personal '
                'records. Your routines and custom exercises will be kept. '
                'There is no undo.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Type RESET to confirm',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'RESET',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Reset Account',
                      onPressed: _isResetTyped
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      gradient: AppTheme.destructiveGradient,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _isDeleteTyped = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final typed = _controller.text.trim().toUpperCase() == 'DELETE';
    if (typed != _isDeleteTyped) {
      setState(() => _isDeleteTyped = typed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delete Account'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: 'Cancel',
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'This will permanently delete your account, all your '
                'workouts, personal records, routines, and custom '
                'exercises. This cannot be undone.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Type DELETE to confirm',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Delete Account',
                      onPressed: _isDeleteTyped
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      gradient: AppTheme.destructiveGradient,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

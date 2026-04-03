import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text('Profile', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 32),
            // Identity card
            profileAsync.when(
              data: (profile) => _IdentityCard(
                displayName: profile?.displayName,
                email: email,
              ),
              loading: () => const _IdentityCard(
                displayName: null,
                email: '',
                loading: true,
              ),
              error: (_, _) =>
                  const _IdentityCard(displayName: null, email: ''),
            ),
            const SizedBox(height: 32),
            // Weight unit section
            Text('Weight Unit', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (profile) =>
                  _WeightUnitToggle(weightUnit: profile?.weightUnit ?? 'kg'),
              loading: () => const _WeightUnitToggle(weightUnit: 'kg'),
              error: (_, _) => const _WeightUnitToggle(weightUnit: 'kg'),
            ),
            const SizedBox(height: 48),
            // Logout button
            _LogoutButton(),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.displayName,
    required this.email,
    this.loading = false,
  });

  final String? displayName;
  final String email;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = displayName ?? 'Gym User';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: loading
                  ? const _LoadingPlaceholder()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleLarge),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 16, child: LinearProgressIndicator());
  }
}

class _WeightUnitToggle extends ConsumerWidget {
  const _WeightUnitToggle({required this.weightUnit});

  final String weightUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'kg', label: Text('kg')),
        ButtonSegment(value: 'lbs', label: Text('lbs')),
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

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
        side: BorderSide(color: Theme.of(context).colorScheme.error),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () => _confirmLogout(context, ref),
      child: const Text('Log Out'),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_format.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/radii.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../features/auth/providers/notifiers/auth_notifier.dart';
import '../../../l10n/app_localizations.dart';
import '../../personal_records/providers/pr_providers.dart'
    show prCountProvider;
import '../../workouts/providers/workout_history_providers.dart'
    show workoutCountProvider;
import '../providers/crash_reports_enabled_provider.dart';
import '../providers/profile_providers.dart';
import 'widgets/language_picker_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileProvider);
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Semantics(
              container: true,
              identifier: 'profile-heading',
              child: Text(l10n.profile, style: theme.textTheme.headlineMedium),
            ),
            const SizedBox(height: 32),
            // Identity card
            profileAsync.when(
              data: (profile) => _IdentityCard(
                displayName: profile?.displayName,
                email: email,
                onEditName: () =>
                    _showEditNameDialog(context, ref, profile?.displayName),
              ),
              loading: () => const _IdentityCard(
                displayName: null,
                email: '',
                loading: true,
              ),
              error: (_, _) =>
                  const _IdentityCard(displayName: null, email: ''),
            ),
            const SizedBox(height: 24),
            // Stats section
            const _StatsRow(),
            const SizedBox(height: 32),
            // Weight unit section
            Text(
              l10n.weightUnit,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (profile) =>
                  _WeightUnitToggle(weightUnit: profile?.weightUnit ?? 'kg'),
              loading: () => const _WeightUnitToggle(weightUnit: 'kg'),
              error: (_, _) => const _WeightUnitToggle(weightUnit: 'kg'),
            ),
            const SizedBox(height: 24),
            // Weekly goal section
            Semantics(
              container: true,
              identifier: 'profile-goal-label',
              child: Text(l10n.weeklyGoal, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (profile) => _WeeklyGoalRow(
                frequency: profile?.trainingFrequencyPerWeek ?? 3,
              ),
              loading: () => const _WeeklyGoalRow(frequency: 3),
              error: (_, _) => const _WeeklyGoalRow(frequency: 3),
            ),
            const SizedBox(height: 32),
            // Preferences section
            Text(
              l10n.preferences,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            _LanguageRow(locale: ref.watch(localeProvider)),
            const SizedBox(height: 32),
            // Data management section
            Text(
              l10n.dataManagement,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadiusMd),
                onTap: () => context.go('/profile/manage-data'),
                // No container: true — identifier merges into the parent InkWell's
                // semantics node so Playwright can click-target it.
                child: Semantics(
                  identifier: 'profile-manage-data',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.manageData,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Legal section
            Text(
              l10n.legal,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            _LegalTile(
              title: l10n.privacyPolicy,
              icon: Icons.privacy_tip_outlined,
              onTap: () => context.push('/privacy-policy'),
            ),
            const SizedBox(height: 8),
            _LegalTile(
              title: l10n.termsOfService,
              icon: Icons.description_outlined,
              onTap: () => context.push('/terms-of-service'),
            ),
            const SizedBox(height: 24),
            // Privacy section
            Text(
              l10n.privacySection,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sendCrashReports),
                  subtitle: Text(l10n.crashReportsSubtitle),
                  value: ref.watch(crashReportsEnabledProvider),
                  onChanged: (value) {
                    ref
                        .read(crashReportsEnabledProvider.notifier)
                        .setEnabled(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Logout button
            const _LogoutButton(),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEditNameDialog(
  BuildContext context,
  WidgetRef ref,
  String? currentName,
) async {
  final controller = TextEditingController(text: currentName ?? '');
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final dialogTheme = Theme.of(ctx);
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        backgroundColor: dialogTheme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
        title: Text(l10n.editDisplayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l10n.enterYourName),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );

  if (newName == null || newName.isEmpty || !context.mounted) return;

  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return;

  await ref
      .read(profileRepositoryProvider)
      .upsertProfile(userId: user.id, displayName: newName);
  ref.invalidate(profileProvider);
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.displayName,
    required this.email,
    this.loading = false,
    this.onEditName,
  });

  final String? displayName;
  final String email;
  final bool loading;
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = displayName ?? l10n.gymUser;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                (displayName?.isNotEmpty == true
                        ? displayName![0]
                        : email.isNotEmpty
                        ? email[0]
                        : '?')
                    .toUpperCase(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: loading
                  ? const _LoadingPlaceholder()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: onEditName,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              if (onEditName != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final workoutCountAsync = ref.watch(workoutCountProvider);
    final prCountAsync = ref.watch(prCountProvider);
    final profile = ref.watch(profileProvider);

    final workoutCount = workoutCountAsync.value ?? 0;
    final prCount = prCountAsync.value ?? 0;
    final memberSince = profile.value?.createdAt;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: l10n.workouts,
            value: '$workoutCount',
            icon: Icons.fitness_center,
            theme: theme,
            onTap: () => context.go('/home/history'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: l10n.prsLabel,
            value: '$prCount',
            icon: Icons.emoji_events,
            theme: theme,
            onTap: () => context.go('/records'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: l10n.memberSince,
            value: memberSince != null
                ? AppDateFormat.monthYear(
                    memberSince,
                    locale: Localizations.localeOf(context).languageCode,
                  )
                : '--',
            icon: Icons.calendar_today,
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final ThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: child,
      );
    }

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _WeeklyGoalRow extends ConsumerWidget {
  const _WeeklyGoalRow({required this.frequency});

  final int frequency;

  static const _frequencyOptions = [2, 3, 4, 5, 6];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: () => _showFrequencySheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.perWeekLabel(frequency),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFrequencySheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.weeklyGoal, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Semantics(
                  container: true,
                  identifier: 'profile-goal-sheet-title',
                  child: Text(
                    l10n.frequencyQuestion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: _frequencyOptions.map((freq) {
                    final isSelected = freq == frequency;
                    return ChoiceChip(
                      label: Text('${freq}x'),
                      selected: isSelected,
                      onSelected: (_) {
                        ref
                            .read(profileProvider.notifier)
                            .updateTrainingFrequency(freq);
                        Navigator.of(ctx).pop();
                      },
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.locale});

  final Locale locale;

  /// Display names in the language's own script (never translated).
  static const _displayNames = {
    'en': 'English',
    'pt': 'Portugu\u00eas (Brasil)',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayName =
        _displayNames[locale.languageCode] ?? locale.languageCode;

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: () => _showLanguagePicker(context),
        child: Semantics(
          identifier: 'profile-language-row',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.language,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const LanguagePickerSheet(),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
      identifier: 'profile-logout-btn',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () => _confirmLogout(context, ref),
        child: Text(AppLocalizations.of(context).logOut),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.logOut),
          content: Semantics(
            container: true,
            identifier: 'profile-logout-dialog',
            child: Text(l10n.logOutConfirm),
          ),
          actions: [
            Semantics(
              container: true,
              identifier: 'profile-cancel-btn',
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.logOut),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

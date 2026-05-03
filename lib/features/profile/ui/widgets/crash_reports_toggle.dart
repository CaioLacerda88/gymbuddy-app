import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/radii.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/crash_reports_enabled_provider.dart';

/// Privacy-section toggle that opts the user in/out of Sentry crash reports.
class CrashReportsToggle extends ConsumerWidget {
  const CrashReportsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sendCrashReports),
          subtitle: Text(l10n.crashReportsSubtitle),
          value: ref.watch(crashReportsEnabledProvider),
          onChanged: (value) {
            ref.read(crashReportsEnabledProvider.notifier).setEnabled(value);
          },
        ),
      ),
    );
  }
}

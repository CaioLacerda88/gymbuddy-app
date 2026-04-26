import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Placeholder destination for sub-screens whose full implementation lands
/// in a later phase (Stats deep-dive → 18d, Titles → 18c).
///
/// Renders a minimal "Coming soon." surface with the section's localized
/// title in the app bar. Exists so the codex nav rows have somewhere to
/// push to — a dead-end tap (no route resolved) reads as a bug, while a
/// "Coming soon" placeholder reads as deliberate phasing.
class SagaStubScreen extends StatelessWidget {
  const SagaStubScreen({super.key, required this.title});

  /// Localized screen title — caller passes `l10n.statsDeepDiveLabel` etc.
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                color: AppColors.textDim,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.comingSoonStub,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

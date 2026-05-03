import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/providers/notifiers/auth_notifier.dart';
import '../../../../l10n/app_localizations.dart';

/// Outlined "Log out" button at the bottom of the profile settings screen.
/// Tapping it opens a confirmation dialog; only on confirm does it call
/// [authNotifierProvider] `signOut`.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/xp_provider.dart';
import 'saga_intro_overlay.dart';

/// First-launch gate that wraps the authenticated shell and, per user:
///
///   1. Triggers the retroactive XP backfill exactly once (idempotent on the
///      server; the Hive flag avoids the round-trip on subsequent launches).
///   2. Renders [SagaIntroOverlay] over [child] when the backfill has
///      completed and the user has not yet dismissed the intro.
///   3. Records dismissal to Hive so the overlay never re-appears.
///
/// The child renders immediately — retro runs asynchronously and the overlay
/// only paints once `xpProvider` resolves to real data. A per-session guard
/// prevents the overlay from re-mounting after dismissal in the same session
/// (the Hive write is asynchronous; the in-memory flag closes the race).
class SagaIntroGate extends ConsumerStatefulWidget {
  const SagaIntroGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SagaIntroGate> createState() => _SagaIntroGateState();
}

class _SagaIntroGateState extends ConsumerState<SagaIntroGate> {
  bool _retroKicked = false;
  bool _dismissedThisSession = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return widget.child;

    _maybeKickRetro(userId);

    final summaryAsync = ref.watch(xpProvider);
    final retroDone = hasRunRetroForUser(userId);
    final alreadySeen = hasSeenSagaIntroForUser(userId);

    final shouldShow =
        !_dismissedThisSession &&
        !alreadySeen &&
        retroDone &&
        summaryAsync is AsyncData;

    if (!shouldShow) return widget.child;

    final summary = summaryAsync.value!;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        SagaIntroOverlay(
          startingLevel: summary.currentLevel,
          startingRank: summary.rank,
          onDismiss: () => _dismiss(userId),
        ),
      ],
    );
  }

  void _maybeKickRetro(String userId) {
    if (_retroKicked) return;
    if (hasRunRetroForUser(userId)) {
      _retroKicked = true;
      return;
    }
    _retroKicked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Retro is safe to retry next launch (server is idempotent); swallow
      // errors to avoid blocking the home render on a transient network
      // failure.
      ref
          .read(xpProvider.notifier)
          .runRetroBackfill(userId)
          .catchError((Object _) {});
    });
  }

  void _dismiss(String userId) {
    setState(() => _dismissedThisSession = true);
    markSagaIntroSeenForUser(userId);
  }
}

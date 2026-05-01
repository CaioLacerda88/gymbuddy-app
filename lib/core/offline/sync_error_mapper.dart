import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../l10n/app_localizations.dart';
import '../exceptions/app_exception.dart' as app;
import '../observability/sentry_report.dart';
import 'pending_action.dart';

/// Maps a thrown sync error to a user-safe, localized message.
///
/// **Why this exists (BUG-042):** the offline-sync queue used to render
/// `error.toString()` directly in the "Sincronização Pendente" sheet, which
/// leaked Postgres constraint names, Dart cast-error internals, and
/// table/column names to end users. That's both a bad UX (nobody understands
/// `DatabaseException: insert or update on table "personal_records" violates
/// foreign key constraint "personal_records_set_id_fkey"`) and an information
/// disclosure issue (OWASP A04:2021 — exposing internal schema).
///
/// **BUG-008:** also classifies the error into a [SyncErrorCategory] so the
/// pending-sync sheet can pick between retry and dismiss CTAs.
///
/// **Contract:**
/// - The raw exception (with full stack) goes to `developer.log()` and Sentry
///   so we can still diagnose production issues.
/// - The UI receives **only** the localized return value. There is no path
///   from `error.toString()` to the user.
/// - One mapping function, used at every UI boundary that surfaces sync
///   errors. Don't scatter `try/catch + l10n` across widgets — one place.
///
/// All copy is sourced from `app_pt.arb` / `app_en.arb` — pt-BR is the
/// canonical authoring locale per CLAUDE.md.
class SyncErrorMapper {
  // Static-only utility — instantiation is meaningless; the private
  // constructor matches the prevailing codebase idiom (AppNumberFormat,
  // ErrorMapper, AppTheme, etc.) for utility classes.
  const SyncErrorMapper._();

  /// Returns a user-safe message for [error], localized via [l10n].
  ///
  /// Side effect: logs the raw exception to `developer.log` and forwards
  /// it as a Sentry breadcrumb. The caller does not need to log separately.
  static String toUserMessage(AppLocalizations l10n, Object error) {
    // Always log the raw error — this is what we need for diagnosis and
    // it MUST stay out of the UI.
    log('Sync error: $error', name: 'SyncErrorMapper', level: 900);
    SentryReport.addBreadcrumb(
      category: 'sync.error',
      message: 'Sync error mapped to user',
      data: {'error_class': error.runtimeType.toString()},
    );

    return _classify(l10n, error);
  }

  /// Pure classification — no logging, no side effects. Exposed for tests
  /// that pin each exception class to its expected localized message
  /// without observing log/sentry side effects.
  static String classify(AppLocalizations l10n, Object error) =>
      _classify(l10n, error);

  /// Returns the [SyncErrorCategory] for [error].
  ///
  /// Mirrors [classify] one-to-one — same inputs always map to the same
  /// category and l10n key. This is the value [SyncService] writes to
  /// [PendingAction.errorCategory] on each failed drain attempt so the
  /// pending-sync sheet (BUG-008) can pick between retry vs dismiss without
  /// re-classifying.
  static SyncErrorCategory classifyCategory(Object error) {
    if (error is app.AuthException) return SyncErrorCategory.session;
    if (error is supabase.AuthException) return SyncErrorCategory.session;

    if (error is SocketException) return SyncErrorCategory.network;
    if (error is TimeoutException) return SyncErrorCategory.network;
    if (error is HttpException) return SyncErrorCategory.network;
    if (error is app.NetworkException) return SyncErrorCategory.network;

    // Postgrest / database errors are structural — retrying without a code
    // change won't fix an FK violation, RLS denial, or unique-constraint
    // collision. The mapper still returns the generic "we'll retry" copy
    // (BUG-042 information-disclosure contract) but the category drives the
    // sheet to show "Dispensar" instead of "Tentar novamente".
    if (error is supabase.PostgrestException) {
      return SyncErrorCategory.structural;
    }
    if (error is app.DatabaseException) return SyncErrorCategory.structural;

    // Dart-internal cast / type errors are always structural — the queued
    // payload doesn't match what the deserializer expects.
    if (error is TypeError) return SyncErrorCategory.structural;

    return SyncErrorCategory.unknown;
  }

  static String _classify(AppLocalizations l10n, Object error) {
    // Auth errors — both our wrapped AppException.AuthException and the
    // raw supabase.AuthException flow into the same user message.
    if (error is app.AuthException) return l10n.syncErrorSessionExpired;
    if (error is supabase.AuthException) return l10n.syncErrorSessionExpired;

    // Network / offline / timeout — a softer message ("we'll sync when
    // you're back online") because the user's data is safe in the queue.
    if (error is SocketException) return l10n.syncErrorOffline;
    if (error is TimeoutException) return l10n.syncErrorOffline;
    if (error is HttpException) return l10n.syncErrorOffline;
    if (error is app.NetworkException) return l10n.syncErrorOffline;

    // Postgrest (FK violations, RLS denials, unique-constraint, etc.) —
    // never expose the constraint name or table. Generic retry message.
    if (error is supabase.PostgrestException) {
      return l10n.syncErrorRetryGeneric;
    }
    if (error is app.DatabaseException) return l10n.syncErrorRetryGeneric;

    // Dart-internal cast / type errors — also generic.
    if (error is TypeError) return l10n.syncErrorRetryGeneric;

    // Unknown — generic fallback.
    return l10n.syncErrorUnknown;
  }
}

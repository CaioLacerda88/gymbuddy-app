import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regex matching UUID-like segments in paths, for route sanitization.
final _uuidInPath = RegExp(
  r'/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// Matches `token@host` style email addresses. We scrub these from outbound
/// Sentry events so a third-party exception whose message happens to contain
/// a user email never reaches the tracker.
final _emailRegex = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

/// Replaces any email addresses in [value] with `[email]`. Returns [value]
/// unchanged when it contains no email or when it is null.
String? scrubEmails(String? value) {
  if (value == null || value.isEmpty) return value;
  if (!value.contains('@')) return value;
  return value.replaceAll(_emailRegex, '[email]');
}

/// Walks every user-visible string field on [event] (message, exception
/// values, stack-frame descriptions) and replaces email-like substrings with
/// `[email]`. Mutates and returns [event] — callers can chain.
///
/// Defense-in-depth against third-party packages embedding user input in
/// exception messages. Our own repositories short-circuit at the
/// `on AppException { rethrow; }` branch in [BaseRepository.mapException]
/// so AppException subclasses never reach `beforeSend`; this scrub only
/// ever touches unexpected non-domain errors.
SentryEvent scrubEventPii(SentryEvent event) {
  // 1. Top-level message (SentryMessage fields are mutable in sentry 9.x)
  final msg = event.message;
  if (msg != null) {
    final scrubbedFormatted = scrubEmails(msg.formatted);
    if (scrubbedFormatted != null && scrubbedFormatted != msg.formatted) {
      msg.formatted = scrubbedFormatted;
    }
    final scrubbedTemplate = scrubEmails(msg.template);
    if (scrubbedTemplate != msg.template) {
      msg.template = scrubbedTemplate;
    }
  }

  // 2. Exception values and their stack frames
  final exceptions = event.exceptions;
  if (exceptions != null) {
    for (final ex in exceptions) {
      final scrubbedValue = scrubEmails(ex.value);
      if (scrubbedValue != ex.value) {
        ex.value = scrubbedValue;
      }
      final frames = ex.stackTrace?.frames;
      if (frames != null) {
        for (final frame in frames) {
          final scrubbedDesc = scrubEmails(frame.contextLine);
          if (scrubbedDesc != frame.contextLine) {
            frame.contextLine = scrubbedDesc;
          }
        }
      }
    }
  }

  return event;
}

/// Initializes Sentry if `SENTRY_DSN` is set in dotenv. Otherwise runs
/// `appRunner` directly (dev builds, tests, and any build where the DSN
/// has not been injected by CI).
///
/// Strict PII posture:
/// - `sendDefaultPii: false` — no IP, no auto-captured user info
/// - `tracesSampleRate: 0.0` — no performance tracing for MVP
/// - `beforeSend` sets only the Supabase user_id on the event, then runs
///   [scrubEventPii] to redact any email-like substrings from the message,
///   exception values, and stack-frame context lines (defense-in-depth
///   against third-party packages that embed user input in error messages)
/// - `beforeBreadcrumb` drops breadcrumbs containing email-like strings and
///   also scans breadcrumb `data` string values
Future<void> initSentryAndRun(Future<void> Function() appRunner) async {
  final dsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (dsn.isEmpty) {
    // No DSN — skip init entirely. Dev builds and tests take this path.
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.environment = kReleaseMode ? 'prod' : 'dev';
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0.0;
      options.attachScreenshot = false;
      options.enableAutoPerformanceTracing = false;

      options.beforeSend = (SentryEvent event, Hint hint) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        // With sendDefaultPii: false, Sentry won't auto-populate user fields,
        // so when we have no Supabase user we just pass the event through
        // untouched. As of sentry_flutter 9.x, SentryEvent fields are mutable
        // and `copyWith` is deprecated, so we assign directly.
        if (userId != null) {
          event.user = SentryUser(id: userId);
        }
        // Scrub any email-like substrings from user-visible event fields.
        // BaseRepository.mapException short-circuits AppException before the
        // capture branch runs, so this only ever catches third-party errors
        // that happen to echo user input — but we run it unconditionally as
        // a defense-in-depth measure.
        return scrubEventPii(event);
      };

      options.beforeBreadcrumb = (Breadcrumb? crumb, Hint hint) {
        if (crumb == null) return null;
        final msg = crumb.message ?? '';
        if (msg.contains('@')) return null;
        // Defense-in-depth: walk breadcrumb `data` string values too. Our
        // own call sites only put bounded IDs (workout_id, routine_id, etc.)
        // in `data`, and SentryReport.addBreadcrumb documents this rule,
        // but if a future caller slips in user input we redact the whole
        // crumb rather than shipping it.
        final data = crumb.data;
        if (data != null) {
          for (final value in data.values) {
            if (value is String && value.contains('@')) return null;
          }
        }
        return crumb;
      };
    },
    appRunner: () async {
      await appRunner();
    },
  );
}

/// Route name extractor for [SentryNavigatorObserver] that replaces UUIDs in
/// paths with `:id` so user/workout/routine IDs don't leak into breadcrumbs.
RouteSettings? sanitizeRouteName(RouteSettings? settings) {
  final name = settings?.name;
  if (name == null) return settings;
  final scrubbed = name.replaceAll(_uuidInPath, '/:id');
  if (scrubbed == name) return settings;
  return RouteSettings(name: scrubbed, arguments: settings!.arguments);
}

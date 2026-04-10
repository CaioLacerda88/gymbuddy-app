import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regex matching UUID-like segments in paths, for route sanitization.
final _uuidInPath = RegExp(
  r'/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// Initializes Sentry if `SENTRY_DSN` is set in dotenv. Otherwise runs
/// `appRunner` directly (dev builds, tests, and any build where the DSN
/// has not been injected by CI).
///
/// Strict PII posture:
/// - `sendDefaultPii: false` — no IP, no auto-captured user info
/// - `tracesSampleRate: 0.0` — no performance tracing for MVP
/// - `beforeSend` sets only the Supabase user_id on the event
/// - `beforeBreadcrumb` drops breadcrumbs containing email-like strings
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
        // untouched. copyWith(user: null) preserves the existing user via
        // `user ?? this.user`, so it cannot be used to clear.
        if (userId != null) {
          return event.copyWith(user: SentryUser(id: userId));
        }
        return event;
      };

      options.beforeBreadcrumb = (Breadcrumb? crumb, Hint hint) {
        if (crumb == null) return null;
        final msg = crumb.message ?? '';
        if (msg.contains('@')) return null;
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

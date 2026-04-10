import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/device/platform_info.dart';
import 'core/local_storage/hive_service.dart';
import 'core/observability/sentry_init.dart';
import 'core/observability/sentry_report.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await const HiveService().init();
  await initAppVersion();

  // Seed the Sentry opt-out flag from Hive BEFORE init. If the user has
  // disabled crash reports in a prior session, we respect that immediately.
  final prefs = Hive.box(HiveService.userPrefs);
  final crashReportsEnabled =
      prefs.get('crash_reports_enabled', defaultValue: true) as bool;
  SentryReport.setEnabled(crashReportsEnabled);

  await initSentryAndRun(() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    runApp(const ProviderScope(child: App()));
  });
}

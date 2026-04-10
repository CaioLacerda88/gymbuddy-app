import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/core/observability/sentry_report.dart';
import 'package:gymbuddy_app/features/profile/providers/crash_reports_enabled_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crash_reports_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(HiveService.userPrefs);
    SentryReport.setEnabled(true);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('default value is true when Hive has no entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(crashReportsEnabledProvider), true);
  });

  test('reads persisted false from Hive', () async {
    await Hive.box(HiveService.userPrefs).put('crash_reports_enabled', false);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(crashReportsEnabledProvider), false);
  });

  test('setting to false persists and updates SentryReport', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(crashReportsEnabledProvider.notifier)
        .setEnabled(false);

    expect(container.read(crashReportsEnabledProvider), false);
    expect(Hive.box(HiveService.userPrefs).get('crash_reports_enabled'), false);
    expect(SentryReport.isEnabled, false);
  });

  test('setting to true persists and updates SentryReport', () async {
    await Hive.box(HiveService.userPrefs).put('crash_reports_enabled', false);
    SentryReport.setEnabled(false);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(crashReportsEnabledProvider.notifier).setEnabled(true);

    expect(container.read(crashReportsEnabledProvider), true);
    expect(SentryReport.isEnabled, true);
  });
}

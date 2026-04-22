import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/core/observability/sentry_report.dart';
import 'package:repsaga/features/profile/providers/crash_reports_enabled_provider.dart';
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

  test(
    'build() syncs SentryReport.isEnabled with the persisted Hive value',
    () async {
      // Regression for PR #46 reviewer finding 3: provider rebuild (hot reload,
      // ref.invalidate) must re-apply the persisted flag to the static
      // SentryReport so the notifier state and the gating flag cannot diverge.

      // Case 1: persisted false -> build() must push false to SentryReport
      // even when the static flag starts out as true (the default from setUp).
      await Hive.box(HiveService.userPrefs).put('crash_reports_enabled', false);
      expect(
        SentryReport.isEnabled,
        true,
        reason: 'setUp seeds SentryReport to enabled before each test',
      );

      final container1 = ProviderContainer();
      addTearDown(container1.dispose);

      // First read triggers build().
      expect(container1.read(crashReportsEnabledProvider), false);
      expect(
        SentryReport.isEnabled,
        false,
        reason: 'build() must sync the static flag with the Hive value',
      );

      // Case 2: flip Hive to true, invalidate, rebuild -> static flag flips back.
      await Hive.box(HiveService.userPrefs).put('crash_reports_enabled', true);
      container1.invalidate(crashReportsEnabledProvider);
      expect(container1.read(crashReportsEnabledProvider), true);
      expect(
        SentryReport.isEnabled,
        true,
        reason: 'rebuild after invalidate must re-sync the static flag',
      );
    },
  );
}

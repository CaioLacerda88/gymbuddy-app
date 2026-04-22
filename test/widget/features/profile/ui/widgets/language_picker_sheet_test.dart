import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/l10n/locale_provider.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/profile/ui/widgets/language_picker_sheet.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../../helpers/test_material_app.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('language_picker_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(HiveService.userPrefs);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget({Locale initialLocale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _TestLocaleNotifier(initialLocale)),
      ],
      child: TestMaterialApp(
        theme: AppTheme.dark,
        locale: initialLocale,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const LanguagePickerSheet(),
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );
  }

  group('LanguagePickerSheet', () {
    testWidgets('shows both language options', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open the bottom sheet.
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Portugu\u00eas (Brasil)'), findsOneWidget);
    });

    testWidgets('shows check mark on currently selected language (English)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // English is selected, so a check icon should be visible.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows check mark on Portuguese when Portuguese is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(initialLocale: const Locale('pt')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Portuguese is selected, check icon should be visible.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping a language option closes the sheet', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap Portuguese option.
      await tester.tap(find.text('Portugu\u00eas (Brasil)'));
      await tester.pumpAndSettle();

      // Bottom sheet should be dismissed.
      expect(find.text('Portugu\u00eas (Brasil)'), findsNothing);
    });

    testWidgets('tapping a language option updates the locale provider', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(
              () => _TestLocaleNotifier(const Locale('en')),
            ),
          ],
          child: TestMaterialApp(
            theme: AppTheme.dark,
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const LanguagePickerSheet(),
                      );
                    },
                    child: const Text('Open Picker'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap Portuguese option.
      await tester.tap(find.text('Portugu\u00eas (Brasil)'));
      await tester.pumpAndSettle();

      // The locale should now be Portuguese.
      final locale = capturedRef.read(localeProvider);
      expect(locale.languageCode, 'pt');
    });

    testWidgets('shows "Language" as the title from l10n', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
    });
  });
}

/// A test locale notifier that uses an in-memory locale (no Hive).
class _TestLocaleNotifier extends LocaleNotifier {
  _TestLocaleNotifier(this._initialLocale);
  final Locale _initialLocale;

  @override
  Locale build() => _initialLocale;

  @override
  Future<void> setLocale(Locale locale) async {
    state = locale;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/legal_doc_screen.dart';

/// Test-only asset bundle that serves a fixed markdown string for a known
/// asset path and throws for unknown paths (so "failed to load" paths can be
/// exercised too). If [completer] is provided, loads wait on it — useful for
/// holding the FutureBuilder in its loading state during a test.
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle({required this.assets, this.completer});

  final Map<String, String> assets;
  final Completer<void>? completer;

  @override
  Future<ByteData> load(String key) async {
    if (completer != null) {
      await completer!.future;
    }
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  const assetPath = 'assets/legal/test_doc.md';
  const markdownBody = '# Test Document\n\nHello **world**.';

  Widget buildTestWidget({
    required AssetBundle bundle,
    String title = 'Test Document',
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: DefaultAssetBundle(
        bundle: bundle,
        child: const LegalDocScreen(
          title: 'Test Document',
          assetPath: assetPath,
        ),
      ),
    );
  }

  group('LegalDocScreen', () {
    testWidgets('renders title in app bar', (tester) async {
      final bundle = _FakeAssetBundle(assets: {assetPath: markdownBody});
      await tester.pumpWidget(buildTestWidget(bundle: bundle));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Test Document'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator before asset resolves', (
      tester,
    ) async {
      // The completer keeps the load() future pending so the FutureBuilder
      // stays in its waiting state until we explicitly resolve it.
      final gate = Completer<void>();
      final bundle = _FakeAssetBundle(
        assets: {assetPath: markdownBody},
        completer: gate,
      );
      await tester.pumpWidget(buildTestWidget(bundle: bundle));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve the gate and settle so we don't leak a pending future.
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('renders markdown content from asset', (tester) async {
      final bundle = _FakeAssetBundle(assets: {assetPath: markdownBody});
      await tester.pumpWidget(buildTestWidget(bundle: bundle));
      await tester.pumpAndSettle();

      expect(find.byType(Markdown), findsOneWidget);
      // The Markdown widget renders the heading text as a RichText. The
      // simplest assertion is that the heading string is somewhere in the
      // widget tree.
      expect(find.textContaining('Test Document'), findsWidgets);
    });

    testWidgets('shows error text when asset cannot be loaded', (tester) async {
      // Empty bundle → load() throws for every key.
      final bundle = _FakeAssetBundle(assets: const {});
      await tester.pumpWidget(buildTestWidget(bundle: bundle));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load document'), findsOneWidget);
    });
  });
}

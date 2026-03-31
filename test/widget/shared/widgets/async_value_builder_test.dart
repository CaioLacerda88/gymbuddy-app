import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/shared/widgets/async_value_builder.dart';

void main() {
  group('AsyncValueBuilder', () {
    testWidgets('should show CircularProgressIndicator when loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: const AsyncLoading(),
              data: (value) => Text(value),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show data widget when AsyncValue has data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: const AsyncData('Hello'),
              data: (value) => Text(value),
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('should show error overlay when AsyncValue has error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: AsyncError(Exception('Oops'), StackTrace.current),
              data: (value) => Text(value),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Oops'), findsOneWidget);
    });

    testWidgets('should show custom loading widget when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: const AsyncLoading(),
              data: (value) => Text(value),
              loading: () => const Text('Custom loading...'),
            ),
          ),
        ),
      );

      expect(find.text('Custom loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should show custom error widget when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: AsyncError(Exception('Fail'), StackTrace.current),
              data: (value) => Text(value),
              error: (err, stack) => Text('Custom error: $err'),
            ),
          ),
        ),
      );

      expect(find.textContaining('Custom error:'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}

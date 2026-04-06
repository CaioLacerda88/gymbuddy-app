import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/rest_timer_notifier.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/rest_timer_overlay.dart';

/// Builds a testable widget tree with an overridden [restTimerProvider].
Widget buildOverlay(RestTimerState? timerState) {
  return ProviderScope(
    overrides: [
      restTimerProvider.overrideWith(() => _FakeRestTimerNotifier(timerState)),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: RestTimerOverlay()),
    ),
  );
}

/// A minimal notifier that starts with a fixed state for widget tests.
///
/// Skip and stop are no-ops here — the test verifies the provider call
/// indirectly via state change, or via the notifier itself.
class _FakeRestTimerNotifier extends RestTimerNotifier {
  _FakeRestTimerNotifier(this._initial);
  final RestTimerState? _initial;

  @override
  RestTimerState? build() => _initial;
}

void main() {
  group('RestTimerOverlay', () {
    group('rendering', () {
      testWidgets(
        'renders nothing (SizedBox.shrink) when timer state is null',
        (tester) async {
          await tester.pumpWidget(buildOverlay(null));

          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('Skip'), findsNothing);
        },
      );

      testWidgets('displays formatted countdown text "1:30" for 90 seconds', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 90,
          remainingSeconds: 90,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.text('1:30'), findsOneWidget);
      });

      testWidgets('displays "0:00" when remaining seconds is zero', (
        tester,
      ) async {
        // Use isActive: true to avoid triggering the auto-dismiss Future.delayed
        // inside the widget, which would leave a pending timer after the test.
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 0,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.text('0:00'), findsOneWidget);
      });

      testWidgets('displays the circular progress indicator when active', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 30,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays the "Rest" label when timer is active', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 30,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.text('Rest'), findsOneWidget);
      });

      testWidgets('displays the Skip button when timer is active', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 30,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.text('Skip'), findsOneWidget);
      });

      testWidgets('displays -30s and +30s buttons when timer is active', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 30,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.text('-30s'), findsOneWidget);
        expect(find.text('+30s'), findsOneWidget);
      });

      testWidgets('does not display -30s or +30s buttons when timer is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildOverlay(null));

        expect(find.text('-30s'), findsNothing);
        expect(find.text('+30s'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('tapping overlay background stops timer', (tester) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 45,
          isActive: true,
        );

        final container = ProviderContainer(
          overrides: [
            restTimerProvider.overrideWith(() => _FakeRestTimerNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: RestTimerOverlay()),
            ),
          ),
        );

        // Verify the timer is active before tapping.
        expect(container.read(restTimerProvider), isNotNull);

        // Tap on the background area (top-left corner, away from buttons).
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();

        // Timer should be stopped (null state).
        expect(container.read(restTimerProvider), isNull);
      });

      testWidgets('tapping Skip button sets timer state to null', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 45,
          isActive: true,
        );

        final container = ProviderContainer(
          overrides: [
            restTimerProvider.overrideWith(() => _FakeRestTimerNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: RestTimerOverlay()),
            ),
          ),
        );

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(container.read(restTimerProvider), isNull);
      });
    });

    group('adjustment button interactions', () {
      testWidgets('tapping +30s calls adjustTime(30) on notifier', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 60,
          isActive: true,
        );

        final container = ProviderContainer(
          overrides: [
            restTimerProvider.overrideWith(() => _FakeRestTimerNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: RestTimerOverlay()),
            ),
          ),
        );

        await tester.tap(find.text('+30s'));
        await tester.pump();

        final updatedState = container.read(restTimerProvider);
        expect(updatedState!.totalSeconds, 90);
        expect(updatedState.remainingSeconds, 90);
      });

      testWidgets('tapping -30s calls adjustTime(-30) on notifier', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 90,
          remainingSeconds: 90,
          isActive: true,
        );

        final container = ProviderContainer(
          overrides: [
            restTimerProvider.overrideWith(() => _FakeRestTimerNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: RestTimerOverlay()),
            ),
          ),
        );

        await tester.tap(find.text('-30s'));
        await tester.pump();

        final updatedState = container.read(restTimerProvider);
        expect(updatedState!.totalSeconds, 60);
        expect(updatedState.remainingSeconds, 60);
      });
    });

    group('accessibility', () {
      testWidgets(
        'overlay has semantics label containing remaining time for screen readers',
        (tester) async {
          const state = RestTimerState(
            totalSeconds: 120,
            remainingSeconds: 75,
            isActive: true,
          );
          await tester.pumpWidget(buildOverlay(state));

          // The Semantics widget wraps the progress ring + countdown text.
          expect(
            find.bySemanticsLabel(RegExp(r'Rest timer.*1:15.*remaining')),
            findsOneWidget,
          );
        },
      );

      testWidgets('Skip button has "Skip rest timer" semantics label', (
        tester,
      ) async {
        const state = RestTimerState(
          totalSeconds: 60,
          remainingSeconds: 30,
          isActive: true,
        );
        await tester.pumpWidget(buildOverlay(state));

        expect(find.bySemanticsLabel('Skip rest timer'), findsOneWidget);
      });
    });
  });
}

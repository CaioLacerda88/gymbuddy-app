import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/rest_timer_notifier.dart';

void main() {
  group('RestTimerState', () {
    group('progress', () {
      test('returns 0.0 immediately after start (remaining == total)', () {
        const state = RestTimerState(totalSeconds: 60, remainingSeconds: 60);
        expect(state.progress, 0.0);
      });

      test('returns 0.5 at halfway point', () {
        const state = RestTimerState(totalSeconds: 60, remainingSeconds: 30);
        expect(state.progress, closeTo(0.5, 0.001));
      });

      test('returns 1.0 when remaining reaches 0', () {
        const state = RestTimerState(totalSeconds: 60, remainingSeconds: 0);
        expect(state.progress, 1.0);
      });

      test(
        'returns 0.0 when totalSeconds is 0 (guard against division by zero)',
        () {
          const state = RestTimerState(totalSeconds: 0, remainingSeconds: 0);
          expect(state.progress, 0.0);
        },
      );
    });

    group('equality', () {
      test('two identical states are equal', () {
        const a = RestTimerState(
          totalSeconds: 90,
          remainingSeconds: 45,
          isActive: true,
        );
        const b = RestTimerState(
          totalSeconds: 90,
          remainingSeconds: 45,
          isActive: true,
        );
        expect(a, equals(b));
      });

      test('states differ when remainingSeconds differs', () {
        const a = RestTimerState(totalSeconds: 60, remainingSeconds: 60);
        const b = RestTimerState(totalSeconds: 60, remainingSeconds: 59);
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('RestTimerNotifier', () {
    ProviderContainer makeContainer() => ProviderContainer();

    group('build', () {
      test('initial state is null', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        expect(container.read(restTimerProvider), isNull);
      });
    });

    group('start', () {
      test('sets state with correct totalSeconds and remainingSeconds', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(90);

        final state = container.read(restTimerProvider);
        expect(state, isNotNull);
        expect(state!.totalSeconds, 90);
        expect(state.remainingSeconds, 90);
      });

      test('sets isActive to true', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(60);

        expect(container.read(restTimerProvider)!.isActive, isTrue);
      });

      test('restarting mid-timer replaces state with new totalSeconds', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(120);
        container.read(restTimerProvider.notifier).start(30);

        final state = container.read(restTimerProvider);
        expect(state!.totalSeconds, 30);
        expect(state.remainingSeconds, 30);
      });
    });

    group('skip', () {
      test('sets state to null', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(60);
        expect(container.read(restTimerProvider), isNotNull);

        container.read(restTimerProvider.notifier).skip();

        expect(container.read(restTimerProvider), isNull);
      });

      test('is a no-op when no timer is active', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        // Should not throw when state is already null.
        container.read(restTimerProvider.notifier).skip();

        expect(container.read(restTimerProvider), isNull);
      });
    });

    group('stop', () {
      test('sets state to null', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(60);
        container.read(restTimerProvider.notifier).stop();

        expect(container.read(restTimerProvider), isNull);
      });

      test('is a no-op when no timer is active', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).stop();

        expect(container.read(restTimerProvider), isNull);
      });
    });

    group('start guard', () {
      test('start(0) is a no-op', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(0);

        expect(container.read(restTimerProvider), isNull);
      });

      test('start with negative seconds is a no-op', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(-5);

        expect(container.read(restTimerProvider), isNull);
      });
    });

    group('adjustTime', () {
      test('adding 30 increases totalSeconds and remainingSeconds', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(60);
        container.read(restTimerProvider.notifier).adjustTime(30);

        final state = container.read(restTimerProvider);
        expect(state!.totalSeconds, 90);
        expect(state.remainingSeconds, 90);
      });

      test('subtracting 30 decreases totalSeconds and remainingSeconds', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(60);
        container.read(restTimerProvider.notifier).adjustTime(-30);

        final state = container.read(restTimerProvider);
        expect(state!.totalSeconds, 30);
        expect(state.remainingSeconds, 30);
      });

      test('clamps minimum total to 30 seconds', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(30);
        container.read(restTimerProvider.notifier).adjustTime(-60);

        final state = container.read(restTimerProvider);
        expect(state!.totalSeconds, 30);
      });

      test('clamps maximum total to 600 seconds', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.read(restTimerProvider.notifier).start(590);
        container.read(restTimerProvider.notifier).adjustTime(30);

        final state = container.read(restTimerProvider);
        expect(state!.totalSeconds, 600);
      });

      test('preserves elapsed time when adjusting', () {
        fakeAsync((async) {
          final container = ProviderContainer();

          container.read(restTimerProvider.notifier).start(60);
          // Elapse 10 seconds so elapsed = 10, remaining = 50.
          async.elapse(const Duration(seconds: 10));
          expect(container.read(restTimerProvider)!.remainingSeconds, 50);

          // Add 30s: newTotal = 90, newRemaining = 90 - 10 = 80.
          container.read(restTimerProvider.notifier).adjustTime(30);
          final state = container.read(restTimerProvider);
          expect(state!.totalSeconds, 90);
          expect(state.remainingSeconds, 80);

          container.dispose();
        });
      });

      test('is a no-op when state is null', () {
        final container = makeContainer();
        addTearDown(container.dispose);

        // No start — state is null; should not throw.
        container.read(restTimerProvider.notifier).adjustTime(30);

        expect(container.read(restTimerProvider), isNull);
      });
    });

    group('countdown tick (fakeAsync)', () {
      test('decrements remainingSeconds every second', () {
        fakeAsync((async) {
          final container = ProviderContainer();

          container.read(restTimerProvider.notifier).start(3);
          expect(container.read(restTimerProvider)!.remainingSeconds, 3);

          async.elapse(const Duration(seconds: 1));
          expect(container.read(restTimerProvider)!.remainingSeconds, 2);

          async.elapse(const Duration(seconds: 1));
          expect(container.read(restTimerProvider)!.remainingSeconds, 1);

          container.dispose();
        });
      });

      test('becomes inactive and reaches 0 when timer expires', () {
        fakeAsync((async) {
          final container = ProviderContainer();

          container.read(restTimerProvider.notifier).start(2);

          async.elapse(const Duration(seconds: 2));

          final state = container.read(restTimerProvider);
          expect(state!.remainingSeconds, 0);
          expect(state.isActive, false);

          container.dispose();
        });
      });

      test('state becomes null after stop is called mid-countdown', () {
        fakeAsync((async) {
          final container = ProviderContainer();

          container.read(restTimerProvider.notifier).start(10);
          async.elapse(const Duration(seconds: 3));
          expect(container.read(restTimerProvider)!.remainingSeconds, 7);

          container.read(restTimerProvider.notifier).stop();
          expect(container.read(restTimerProvider), isNull);

          // Timer should not fire after stop.
          async.elapse(const Duration(seconds: 5));
          expect(container.read(restTimerProvider), isNull);

          container.dispose();
        });
      });

      test('wall-clock: remaining is correct even when ticks are delayed '
          '(simulates background resume)', () {
        fakeAsync((async) {
          final container = ProviderContainer();

          container.read(restTimerProvider.notifier).start(60);
          expect(container.read(restTimerProvider)!.remainingSeconds, 60);

          // Simulate 45 seconds passing at once (e.g. app backgrounded).
          // Only one periodic tick fires, but it computes from wall clock.
          async.elapse(const Duration(seconds: 45));

          final state = container.read(restTimerProvider);
          expect(state, isNotNull);
          expect(state!.remainingSeconds, 15);

          container.dispose();
        });
      });

      test('wall-clock: timer completes correctly after background gap', () {
        fakeAsync((async) {
          final container = ProviderContainer();

          container.read(restTimerProvider.notifier).start(30);

          // Simulate 35 seconds passing (exceeds timer duration).
          async.elapse(const Duration(seconds: 35));

          final state = container.read(restTimerProvider);
          expect(state, isNotNull);
          expect(state!.remainingSeconds, 0);
          expect(state.isActive, false);

          container.dispose();
        });
      });
    });
  });
}

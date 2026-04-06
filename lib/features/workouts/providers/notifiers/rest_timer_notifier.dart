import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for the rest timer countdown.
class RestTimerState {
  const RestTimerState({
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isActive = false,
    this.exerciseName,
  });

  final int totalSeconds;
  final int remainingSeconds;
  final bool isActive;
  final String? exerciseName;

  /// Progress from 0.0 (just started) to 1.0 (complete).
  double get progress =>
      totalSeconds > 0 ? (totalSeconds - remainingSeconds) / totalSeconds : 0;

  RestTimerState copyWith({
    int? totalSeconds,
    int? remainingSeconds,
    bool? isActive,
    String? exerciseName,
  }) {
    return RestTimerState(
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isActive: isActive ?? this.isActive,
      exerciseName: exerciseName ?? this.exerciseName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestTimerState &&
          totalSeconds == other.totalSeconds &&
          remainingSeconds == other.remainingSeconds &&
          isActive == other.isActive &&
          exerciseName == other.exerciseName;

  @override
  int get hashCode =>
      Object.hash(totalSeconds, remainingSeconds, isActive, exerciseName);

  @override
  String toString() =>
      'RestTimerState(total: $totalSeconds, remaining: $remainingSeconds, '
      'active: $isActive, exerciseName: $exerciseName)';
}

/// Manages a countdown rest timer between sets.
///
/// State is `null` when no timer is active. The UI layer is responsible
/// for haptic feedback / sound when the timer reaches zero.
class RestTimerNotifier extends Notifier<RestTimerState?> {
  Timer? _timer;

  @override
  RestTimerState? build() => null;

  /// Start a countdown from [seconds]. No-op if [seconds] is <= 0.
  ///
  /// Optionally pass [exerciseName] to display in the rest timer overlay.
  void start(int seconds, {String? exerciseName}) {
    if (seconds <= 0) return;
    _timer?.cancel();
    state = RestTimerState(
      totalSeconds: seconds,
      remainingSeconds: seconds,
      isActive: true,
      exerciseName: exerciseName,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    final current = state;
    if (current == null || current.remainingSeconds <= 0) {
      stop();
      return;
    }
    final next = current.remainingSeconds - 1;
    if (next <= 0) {
      state = current.copyWith(remainingSeconds: 0, isActive: false);
      _timer?.cancel();
      return;
    }
    state = current.copyWith(remainingSeconds: next);
  }

  /// Adjust the total timer duration by [deltaSeconds] (+30 or -30).
  ///
  /// Clamps the new total between 30 and 600 seconds. Recalculates remaining
  /// based on elapsed time so the progress ring stays consistent.
  void adjustTime(int deltaSeconds) {
    final current = state;
    if (current == null) return;
    final elapsed = current.totalSeconds - current.remainingSeconds;
    final newTotal = (current.totalSeconds + deltaSeconds).clamp(30, 600);
    final newRemaining = (newTotal - elapsed).clamp(0, newTotal);
    state = current.copyWith(
      totalSeconds: newTotal,
      remainingSeconds: newRemaining,
    );
  }

  /// Skip the current timer (dismisses immediately).
  void skip() {
    _timer?.cancel();
    state = null;
  }

  /// Stop and clear the timer.
  void stop() {
    _timer?.cancel();
    state = null;
  }
}

/// Provides the rest timer state. `null` means no timer is active.
final restTimerProvider = NotifierProvider<RestTimerNotifier, RestTimerState?>(
  RestTimerNotifier.new,
);

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the device's online/offline status with 500ms debounce.
///
/// The first value is emitted immediately (no debounce) via
/// [Connectivity.checkConnectivity]. Subsequent changes are debounced
/// to avoid rapid toggling during transient connectivity events.
final onlineStatusProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  final controller = StreamController<bool>();
  Timer? debounceTimer;

  bool toOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // Emit the current state immediately (no debounce).
  connectivity
      .checkConnectivity()
      .then((results) {
        if (!controller.isClosed) {
          controller.add(toOnline(results));
        }
      })
      .catchError((Object _) {
        if (!controller.isClosed) controller.add(true);
      });

  // Listen for subsequent changes with 500ms debounce.
  final subscription = connectivity.onConnectivityChanged.listen((results) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) {
        controller.add(toOnline(results));
      }
    });
  });

  ref.onDispose(() {
    debounceTimer?.cancel();
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Synchronous read of the current online status.
///
/// Defaults to `true` (optimistic) when the stream has not yet emitted.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(onlineStatusProvider).value ?? true;
});

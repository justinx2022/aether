import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'aether_event.dart';

final aetherEventBusProvider = Provider<AetherEventBus>((ref) {
  return AetherEventBus.instance;
});

/// High-throughput, subscriber-isolated asynchronous event mesh for Aether Core.
/// Guarantees that errors in any subscriber never prevent other subscribers
/// from receiving events or crash the publishing pipeline.
class AetherEventBus {
  static final AetherEventBus instance = AetherEventBus._internal();

  final StreamController<AetherEvent> _controller;

  AetherEventBus._internal()
      : _controller = StreamController<AetherEvent>.broadcast();

  /// Publishes a typed event to all active in-memory subscribers.
  void publish(AetherEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// Returns a stream of events filtered by the specified type [T].
  Stream<T> on<T extends AetherEvent>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  /// Subscribes to events of type [T] with isolated failure boundaries.
  StreamSubscription<T> subscribe<T extends AetherEvent>(
    void Function(T event) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return on<T>().listen((event) {
      runZonedGuarded(() {
        onData(event);
      }, (error, stack) {
        if (kDebugMode) {
          debugPrint('[AetherEventBus] Subscriber failed on ${event.runtimeType}: $error');
        }
        onError?.call(error, stack);
      });
    });
  }

  /// Closes the underlying stream controller (for clean shutdown / unit testing).
  Future<void> dispose() async {
    await _controller.close();
  }
}

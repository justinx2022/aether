import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/playback_coordinator.dart';
import '../player/playback_session.dart';

enum TaskPriority {
  p0Critical,       // Next-episode pre-warming when playback >= 85%
  p1UserVisible,    // Shelf imagery when user is scrolling
  p2Opportunistic,  // Recommendation graph recalculation
  p3Maintenance,    // Cache pruning, expired DoH cleaning
}

class OrchestratorTask {
  final String id;
  final TaskPriority priority;
  final Future<void> Function() action;
  final Completer<void> completer;
  bool isCancelled = false;

  OrchestratorTask({
    required this.id,
    required this.priority,
    required this.action,
  }) : completer = Completer<void>();

  void cancel() {
    isCancelled = true;
  }
}

final backgroundOrchestratorProvider =
    Provider<BackgroundOrchestrator>((ref) {
  final orchestrator = BackgroundOrchestrator(ref);
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});

/// Resource-aware priority task orchestrator. Prevents background jobs from
/// competing with active playback bandwidth or overloading CPU on TV devices.
class BackgroundOrchestrator {
  final Ref _ref;
  final List<OrchestratorTask> _queue = [];
  int _activeConcurrentTasks = 0;
  static const int _kMaxConcurrency = 2;
  bool _isDisposed = false;
  bool _drainScheduled = false;

  BackgroundOrchestrator(this._ref);

  /// Enqueues a prioritized task.
  Future<void> submit({
    required String id,
    required TaskPriority priority,
    required Future<void> Function() action,
  }) {
    // Deduplicate pending tasks with same ID
    _queue.removeWhere((t) => t.id == id);

    final task = OrchestratorTask(id: id, priority: priority, action: action);
    _queue.add(task);
    _sortQueue();

    if (!_drainScheduled) {
      _drainScheduled = true;
      scheduleMicrotask(() {
        _drainScheduled = false;
        _drainQueue();
      });
    }

    return task.completer.future;
  }

  /// Cancels a pending task by ID.
  void cancel(String id) {
    for (final task in _queue) {
      if (task.id == id) {
        task.cancel();
      }
    }
    _queue.removeWhere((t) => t.id == id);
  }

  void _sortQueue() {
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  Future<void> _drainQueue() async {
    if (_isDisposed) return;
    if (_activeConcurrentTasks >= _kMaxConcurrency) return;
    if (_queue.isEmpty) return;

    // Check if active playback is playing. If so, only permit P0 tasks
    final activeSession = _ref.read(playbackCoordinatorProvider);
    final isPlaying = activeSession?.stage == PlaybackStage.activePlaying;

    if (isPlaying && _queue.first.priority != TaskPriority.p0Critical) {
      return;
    }

    final task = _queue.removeAt(0);
    if (task.isCancelled) {
      if (!task.completer.isCompleted) task.completer.complete();
      unawaited(_drainQueue());
      return;
    }

    _activeConcurrentTasks++;
    try {
      await task.action();
      if (!task.completer.isCompleted) task.completer.complete();
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[BackgroundOrchestrator] Task ${task.id} failed: $e');
      if (!task.completer.isCompleted) task.completer.completeError(e, stack);
    } finally {
      _activeConcurrentTasks--;
      unawaited(_drainQueue());
    }
  }

  void dispose() {
    _isDisposed = true;
    for (final task in _queue) {
      task.cancel();
    }
    _queue.clear();
  }
}

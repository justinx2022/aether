import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'torrent_hls_engine.dart';

/// Coordinates seeking and session epochs between TorrServer piece delivery,
/// FFmpeg fast input seeking, and HLS segment generation.
class TorrentSeekController {
  final String sessionId;
  final String streamUrl;
  final String sessionDir;
  final MediaProbeResult probeResult;
  final RemuxMode remuxMode;
  final int segmentDurationSeconds;

  TorrentSeekController({
    required this.sessionId,
    required this.streamUrl,
    required this.sessionDir,
    required this.probeResult,
    required this.remuxMode,
    this.segmentDurationSeconds = 3,
  });

  Process? _activeProcess;
  int _epoch = 0;
  bool _isDisposed = false;
  Timer? _seekDebounceTimer;
  Duration _currentPosition = Duration.zero;

  int get currentEpoch => _epoch;
  Duration get currentPosition => _currentPosition;

  /// Starts the initial packaging session from [startAt].
  Future<void> start({Duration startAt = Duration.zero}) async {
    if (_isDisposed) return;
    _currentPosition = startAt;
    final startSegment = startAt.inSeconds ~/ segmentDurationSeconds;

    _activeProcess = await TorrentHlsEngine().startHlsPackaging(
      inputUrl: streamUrl,
      outputDir: sessionDir,
      seekOffset: startAt > Duration.zero ? startAt : null,
      startSegmentNumber: startSegment,
      mode: remuxMode,
      targetSegmentDuration: segmentDurationSeconds,
    );
  }

  /// Triggers a seek to [target], debouncing rapid scrubbing and repositioning
  /// FFmpeg at the nearest preceding keyframe.
  Future<void> seekTo(Duration target) async {
    if (_isDisposed) return;
    _seekDebounceTimer?.cancel();

    final completer = Completer<void>();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        await _performSeek(target);
        if (!completer.isCompleted) completer.complete();
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    return completer.future;
  }

  Future<void> _performSeek(Duration target) async {
    if (_isDisposed) return;
    _epoch++;
    _currentPosition = target;

    // Gracefully terminate previous packaging session
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {
        _activeProcess!.kill();
      }
      _activeProcess = null;
    }

    final startSegment = target.inSeconds ~/ segmentDurationSeconds;
    if (kDebugMode) {
      debugPrint(
        '[TorrentSeekController] Seek to ${target.inSeconds}s (Segment $startSegment, Epoch $_epoch)',
      );
    }

    _activeProcess = await TorrentHlsEngine().startHlsPackaging(
      inputUrl: streamUrl,
      outputDir: sessionDir,
      seekOffset: target,
      startSegmentNumber: startSegment,
      mode: remuxMode,
      targetSegmentDuration: segmentDurationSeconds,
    );
  }

  /// Ensures that [segmentNumber] is written to disk and ready for delivery.
  /// If the segment does not exist, triggers on-demand seek packaging for it.
  Future<File?> ensureSegmentReady(
    int segmentNumber, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final fileName = 'seg_${segmentNumber.toString().padLeft(5, '0')}.ts';
    final segmentFile = File(p.join(sessionDir, fileName));

    if (await segmentFile.exists() && await segmentFile.length() > 0) {
      return segmentFile;
    }

    // Segment not ready: trigger seek to this segment's timestamp
    final targetTimestamp =
        Duration(seconds: segmentNumber * segmentDurationSeconds);
    await seekTo(targetTimestamp);

    // Wait for the segment file to appear
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) && !_isDisposed) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (await segmentFile.exists() && await segmentFile.length() > 0) {
        return segmentFile;
      }
    }

    return await segmentFile.exists() ? segmentFile : null;
  }

  void dispose() {
    _isDisposed = true;
    _seekDebounceTimer?.cancel();
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {
        _activeProcess!.kill();
      }
      _activeProcess = null;
    }
  }
}

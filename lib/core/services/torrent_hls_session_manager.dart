import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'torrent_hls_engine.dart';
import 'torrent_seek_controller.dart';
import 'local_proxy_service.dart';

enum TorrentSessionState {
  initialising,
  acquiring,
  packaging,
  playable,
  streaming,
  completed,
  failed,
  cancelled,
}

class TorrentHlsSession {
  final String sessionId;
  final String infoHash;
  final String magnetUrl;
  final String streamUrl;
  final String sessionDir;
  final MediaProbeResult probeResult;
  final Duration totalDuration;
  final TorrentSeekController seekController;

  TorrentSessionState state = TorrentSessionState.initialising;
  DateTime lastAccess = DateTime.now();

  TorrentHlsSession({
    required this.sessionId,
    required this.infoHash,
    required this.magnetUrl,
    required this.streamUrl,
    required this.sessionDir,
    required this.probeResult,
    required this.totalDuration,
    required this.seekController,
  });

  void touch() => lastAccess = DateTime.now();

  void dispose() {
    state = TorrentSessionState.cancelled;
    seekController.dispose();
  }
}

class TorrentHlsSessionManager {
  static final TorrentHlsSessionManager _instance =
      TorrentHlsSessionManager._internal();
  factory TorrentHlsSessionManager() => _instance;
  TorrentHlsSessionManager._internal();

  final Map<String, TorrentHlsSession> _sessions = {};
  TorrentHlsSession? _activeSession;

  TorrentHlsSession? get activeSession => _activeSession;

  /// Creates a new HLS streaming session from a progressive stream URL.
  Future<TorrentHlsSession> createSession({
    required String infoHash,
    required String magnetUrl,
    required String streamUrl,
    Duration startAt = Duration.zero,
  }) async {
    // If an existing session for this infoHash is alive, reuse it
    for (final s in _sessions.values) {
      if (s.infoHash == infoHash && s.state != TorrentSessionState.cancelled) {
        s.touch();
        _activeSession = s;
        if (startAt > Duration.zero) {
          unawaited(s.seekController.seekTo(startAt));
        }
        return s;
      }
    }

    final sessionId = 'hls_${DateTime.now().millisecondsSinceEpoch}_${_sessions.length}';
    final appDir = await getApplicationSupportDirectory();
    final sessionDir = p.join(appDir.path, 'cache', 'hls', sessionId);
    await Directory(sessionDir).create(recursive: true);

    // Stage 1: Probe container & media
    final probe = await TorrentHlsEngine().probe(streamUrl) ??
        const MediaProbeResult(
          format: 'matroska,webm',
          duration: Duration(hours: 2), // Default fallback duration
          videoCodec: 'h264',
          audioCodec: 'aac',
        );

    final remuxMode = probe.recommendedRemuxMode;

    // Stage 2: Create Seek Controller
    final seekController = TorrentSeekController(
      sessionId: sessionId,
      streamUrl: streamUrl,
      sessionDir: sessionDir,
      probeResult: probe,
      remuxMode: remuxMode,
      segmentDurationSeconds: 3,
    );

    final session = TorrentHlsSession(
      sessionId: sessionId,
      infoHash: infoHash,
      magnetUrl: magnetUrl,
      streamUrl: streamUrl,
      sessionDir: sessionDir,
      probeResult: probe,
      totalDuration: probe.duration,
      seekController: seekController,
    );

    _sessions[sessionId] = session;
    _activeSession = session;

    // Stage 3: Start packaging
    session.state = TorrentSessionState.packaging;
    await seekController.start(startAt: startAt);

    // Stage 4: Wait for initial segment to confirm HLS readiness
    final startSeg = startAt.inSeconds ~/ 3;
    final initialSeg = await seekController.ensureSegmentReady(startSeg);
    if (initialSeg != null) {
      session.state = TorrentSessionState.playable;
    }

    return session;
  }

  /// Generates the master VOD playlist content for the session.
  String generateVodPlaylist(TorrentHlsSession session) {
    session.touch();
    final totalSec = session.totalDuration.inSeconds;
    const segSec = 3;
    final totalSegments = (totalSec / segSec).ceil();

    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:6');
    buffer.writeln('#EXT-X-TARGETDURATION:4');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');
    buffer.writeln('#EXT-X-PLAYLIST-TYPE:VOD');

    for (int i = 0; i < totalSegments; i++) {
      final fileName = 'seg_${i.toString().padLeft(5, '0')}.ts';
      buffer.writeln('#EXTINF:3.000,');
      buffer.writeln('http://127.0.0.1:${LocalProxyService.instance.port}/torrent/hls/${session.sessionId}/$fileName');
    }

    buffer.writeln('#EXT-X-ENDLIST');
    return buffer.toString();
  }

  TorrentHlsSession? getSession(String sessionId) {
    final s = _sessions[sessionId];
    if (s != null) s.touch();
    return s;
  }

  /// Closes and disposes a session and cleans up its temporary HLS segments.
  Future<void> closeSession(String sessionId) async {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      session.dispose();
      if (_activeSession?.sessionId == sessionId) {
        _activeSession = null;
      }
      try {
        final dir = Directory(session.sessionDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[TorrentHlsSessionManager] Cleanup error: $e');
      }
    }
  }

  Future<void> closeAllSessions() async {
    final ids = _sessions.keys.toList();
    for (final id in ids) {
      await closeSession(id);
    }
  }
}

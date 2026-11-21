import 'dart:async';
import 'package:flutter/foundation.dart';
import 'torrent_service.dart';
import 'torrent_hls_engine.dart';
import 'torrent_hls_session_manager.dart';
import 'local_proxy_service.dart';

/// Clean façade bridging TorrServer, TorrentHlsSessionManager, and LocalProxyService.
///
/// Guarantees that the Aether player strictly receives standard .m3u8 HLS streams
/// while preserving TorrServer's random-access HTTP byte-range backend.
class TorrentHlsBridge {
  static final TorrentHlsBridge _instance = TorrentHlsBridge._internal();
  factory TorrentHlsBridge() => _instance;
  TorrentHlsBridge._internal();

  /// Prepares a seekable HLS stream from a magnet link.
  ///
  /// Returns a 127.0.0.1 .m3u8 URL powered by LocalProxyService.
  Future<String?> prepareHlsStream({
    required String magnet,
    Duration startAt = Duration.zero,
  }) async {
    try {
      final torrentService = TorrentService();
      if (!torrentService.isStarted) {
        await torrentService.start();
      }

      final hash = await torrentService.addTorrent(magnet);
      if (hash == null) {
        if (kDebugMode) debugPrint('[TorrentHlsBridge] Failed to add torrent');
        return null;
      }

      final fileInfo = await torrentService.pollForMetadata(hash);
      if (fileInfo == null) {
        if (kDebugMode) debugPrint('[TorrentHlsBridge] Timed out waiting for metadata');
        return null;
      }

      final fileIndex = fileInfo['index'] as int? ?? 0;
      final streamUrl =
          await torrentService.getStreamUrlForFileIndex(fileIndex);
      if (streamUrl == null) {
        if (kDebugMode) debugPrint('[TorrentHlsBridge] No stream URL from TorrServer');
        return null;
      }

      // Check for FFmpeg presence
      final ffmpeg = await TorrentHlsEngine().findFfmpeg();
      if (ffmpeg != null) {
        final session = await TorrentHlsSessionManager().createSession(
          infoHash: hash,
          magnetUrl: magnet,
          streamUrl: streamUrl,
          startAt: startAt,
        );

        final localProxy = LocalProxyService.instance;
        if (localProxy.port == 0) {
          await localProxy.startServer();
        }

        final m3u8Url =
            'http://127.0.0.1:${localProxy.port}/torrent/hls/${session.sessionId}/master.m3u8';
        if (kDebugMode) {
          debugPrint('[TorrentHlsBridge] Master HLS ready at: $m3u8Url');
        }
        return m3u8Url;
      }

      // Direct stream fallback only if no FFmpeg binary exists
      return streamUrl;
    } catch (e) {
      if (kDebugMode) debugPrint('[TorrentHlsBridge] prepareHlsStream error: $e');
      return null;
    }
  }

  /// Closes an active HLS torrent session.
  Future<void> closeSession(String sessionId) async {
    await TorrentHlsSessionManager().closeSession(sessionId);
  }
}

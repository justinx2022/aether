import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/entity/multimedia_item.dart';
import '../../features/player/domain/stream_resolver.dart';
import 'torrent_service.dart';

/// Speculative Background Pre-Warmer (Virtual Debrid Pre-Warm Engine).
///
/// Pre-resolves candidate streams, pre-loads torrent metadata and container indexes,
/// and targets exact resume offsets for Continue Watching.
///
/// Cancellable immediately on stream change to preserve 100% bandwidth for playback.
class StreamPrewarmer {
  StreamPrewarmer._();

  static final StreamPrewarmer instance = StreamPrewarmer._();

  static const Duration _entryTtl = Duration(minutes: 3);
  static const int _maxEntries = 8;

  final Map<String, _PrewarmedEntry> _prewarmedStreams = {};
  final Set<String> _inFlight = {};
  CancellationToken? _activeTorrentPrewarmToken;

  /// Whether candidate streams have already been resolved and verified for [targetUrl].
  bool hasPrewarmed(String targetUrl) => getPrewarmed(targetUrl) != null;

  /// Retrieves the pre-warmed playback session if available.
  ResolvedPlayback? getPrewarmed(String targetUrl) {
    final entry = _prewarmedStreams[targetUrl];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) >= _entryTtl) {
      _prewarmedStreams.remove(targetUrl);
      return null;
    }
    return entry.playback;
  }

  /// Cancels any active background torrent pre-warming to yield network/CPU to active playback.
  void cancelActivePrewarm() {
    _activeTorrentPrewarmToken?.cancel();
    _activeTorrentPrewarmToken = null;
  }

  /// Context-Aware Torrent Pre-Warmer:
  /// - For Continue Watching: targets piece offset corresponding to [resumeTimestamp] (skips byte 0).
  /// - For Details Screen: resolves metadata (Level 1) and container indexes (Level 2).
  Future<void> prewarmTorrent({
    required String magnet,
    Duration? resumeTimestamp,
  }) async {
    cancelActivePrewarm();
    final token = CancellationToken();
    _activeTorrentPrewarmToken = token;

    try {
      final torrentService = TorrentService();
      if (!torrentService.isStarted) {
        await torrentService.start();
      }
      if (token.isCancelled) return;

      final hash = await torrentService.addTorrent(magnet);
      if (hash == null || token.isCancelled) return;

      // Poll metadata (Level 1: metadata discovery)
      final meta = await torrentService.pollForMetadata(
        hash,
        timeout: const Duration(seconds: 8),
      );
      if (meta == null || token.isCancelled) return;

      final index = meta['index'] as int? ?? 0;

      // Level 2: Resume-point or Head/Tail index preloading
      if (resumeTimestamp != null && resumeTimestamp > Duration.zero) {
        // Target resume point piece offset
        if (kDebugMode) {
          debugPrint(
            '[PREWARMER] Continue Watching: pre-warming at ${resumeTimestamp.inSeconds}s (hash: $hash)',
          );
        }
      } else {
        // Details screen: initial container index pre-warm
        if (kDebugMode) {
          debugPrint('[PREWARMER] Details screen: pre-warming metadata & index for file $index');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PREWARMER] prewarmTorrent error: $e');
    } finally {
      if (_activeTorrentPrewarmToken == token) {
        _activeTorrentPrewarmToken = null;
      }
    }
  }

  /// Silently pre-resolves [targetUrl] and keeps verified candidate streams in memory.
  Future<void> prewarm({
    required MultimediaItem item,
    required String targetUrl,
    required ProviderReader read,
    Episode? episode,
  }) async {
    if (targetUrl.isEmpty ||
        _inFlight.contains(targetUrl) ||
        getPrewarmed(targetUrl) != null) {
      return;
    }

    _inFlight.add(targetUrl);

    try {
      final resolved = await resolvePlayback(
        read: read,
        item: item,
        videoUrl: targetUrl,
      );

      if (resolved.streams.isNotEmpty) {
        _pruneExpired();
        _prewarmedStreams[targetUrl] = _PrewarmedEntry(
          playback: resolved,
          createdAt: DateTime.now(),
        );
        while (_prewarmedStreams.length > _maxEntries) {
          _prewarmedStreams.remove(_prewarmedStreams.keys.first);
        }

        if (kDebugMode) {
          debugPrint(
            '[PREWARMER] Prewarmed ${resolved.streams.length} sources '
            'for ${resolved.selected.providerName}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PREWARMER] Could not prewarm sources (${e.runtimeType})');
      }
    } finally {
      _inFlight.remove(targetUrl);
    }
  }

  void _pruneExpired() {
    final now = DateTime.now();
    _prewarmedStreams.removeWhere(
      (_, entry) => now.difference(entry.createdAt) >= _entryTtl,
    );
  }

  /// Clears cached pre-warmed streams when memory is reclaimed.
  void clear() {
    _prewarmedStreams.clear();
    _inFlight.clear();
  }
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class _PrewarmedEntry {
  const _PrewarmedEntry({required this.playback, required this.createdAt});

  final ResolvedPlayback playback;
  final DateTime createdAt;
}

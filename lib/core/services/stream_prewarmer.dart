import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/entity/multimedia_item.dart';
import '../../features/player/domain/stream_resolver.dart';

/// Speculative Background Pre-Warmer (Netflix-Style Warm Start).
///
/// Pre-resolves candidate streams and races healthy mirrors with 0-byte preflight
/// before the user presses "Play" or while watching the preceding episode.
/// Eliminates cold-start latency by keeping verified streams ready in memory.
class StreamPrewarmer {
  StreamPrewarmer._();

  static final StreamPrewarmer instance = StreamPrewarmer._();

  static const Duration _entryTtl = Duration(minutes: 3);
  static const int _maxEntries = 8;

  final Map<String, _PrewarmedEntry> _prewarmedStreams = {};
  final Set<String> _inFlight = {};

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

class _PrewarmedEntry {
  const _PrewarmedEntry({required this.playback, required this.createdAt});

  final ResolvedPlayback playback;
  final DateTime createdAt;
}

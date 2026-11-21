import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entity/multimedia_item.dart';
import '../utils/stream_quality_sorter.dart';
import 'torrent_service.dart';

/// Evaluates, ranks, and dynamically tests torrent candidates.
///
/// Strictly enforces the 1080p resolution cap and uses runtime bitrate estimation
/// combined with real-time swarm throughput verification for auto-failover.
class TorrentCandidateManager {
  static final TorrentCandidateManager _instance =
      TorrentCandidateManager._internal();
  factory TorrentCandidateManager() => _instance;
  TorrentCandidateManager._internal();

  /// Filters candidates to <= 1080p and sorts by initial discovery suitability.
  List<StreamResult> filterAndRankCandidates(List<StreamResult> torrents) {
    // 1. Hard filter: 1080p ceiling
    final eligible = torrents.where(isTorrentAtOrUnder1080p).toList();

    // 2. Score candidates based on advertised seeders and friendly format indicators
    eligible.sort((a, b) {
      final seedersA = extractSeeders(a);
      final seedersB = extractSeeders(b);

      // Primary: seeders
      if (seedersB != seedersA) {
        return seedersB.compareTo(seedersA);
      }

      // Secondary: prefer MP4/MKV
      final aFriendly = a.source.toLowerCase().contains('mp4') ||
          a.source.toLowerCase().contains('mkv');
      final bFriendly = b.source.toLowerCase().contains('mp4') ||
          b.source.toLowerCase().contains('mkv');
      if (aFriendly && !bFriendly) return -1;
      if (!aFriendly && bFriendly) return 1;

      return 0;
    });

    return eligible;
  }

  /// Evaluates whether an active swarm can sustain the required playback bitrate.
  ///
  /// Computes B_required = (8 * TorrentSize) / DurationSeconds.
  /// Measures real-time DownloadSpeed reported by TorrServer.
  /// Requires MeasuredSpeed >= 1.35 * B_required.
  Future<bool> evaluateSwarmViability(
    String infoHash, {
    Duration observationDuration = const Duration(seconds: 10),
  }) async {
    final torrentService = TorrentService();
    final deadline = DateTime.now().add(observationDuration);

    double maxObservedSpeed = 0.0;
    int connectedSeeders = 0;
    int durationSeconds = 0;
    int totalSizeBytes = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final status = await torrentService.getCurrentStatus();
        if (status != null) {
          connectedSeeders = status.seeds;
          if (status.downloadSpeed > maxObservedSpeed) {
            maxObservedSpeed = status.downloadSpeed;
          }
          final rawDuration = (status.data['duration'] as num?)?.toDouble() ?? 0.0;
          if (rawDuration > 0) {
            durationSeconds = rawDuration.round();
          }
          if (status.totalSize > 0) {
            totalSizeBytes = status.totalSize;
          }
        }
      } catch (_) {}
    }

    if (durationSeconds > 0 && totalSizeBytes > 0) {
      final requiredBytesPerSecond = totalSizeBytes / durationSeconds;
      final requiredThreshold = requiredBytesPerSecond * 1.35;

      if (kDebugMode) {
        debugPrint(
          '[TorrentCandidateManager] Swarm viability: max speed = ${(maxObservedSpeed / 1024).toStringAsFixed(1)} KB/s, '
          'required = ${(requiredThreshold / 1024).toStringAsFixed(1)} KB/s, seeders = $connectedSeeders',
        );
      }

      return maxObservedSpeed >= requiredThreshold;
    }

    // If duration is unknown upfront, require at least 800 KB/s (~6.4 Mbps) and >= 1 seeder
    return maxObservedSpeed >= 800 * 1024 && connectedSeeders >= 1;
  }
}

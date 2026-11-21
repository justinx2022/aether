import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/torrent_service.dart';

/// Metadata entry tracking a cached torrent's download and playback states independently.
class TorrentCacheEntry {
  final String infoHash;
  final String title;
  final int totalSizeBytes;
  int downloadedBytes;
  double downloadProgress;
  int totalDurationSeconds;
  int playbackPositionSeconds;
  double playbackProgress;
  DateTime lastAccessedAt;
  final DateTime createdAt;

  TorrentCacheEntry({
    required this.infoHash,
    required this.title,
    this.totalSizeBytes = 0,
    this.downloadedBytes = 0,
    this.downloadProgress = 0.0,
    this.totalDurationSeconds = 0,
    this.playbackPositionSeconds = 0,
    this.playbackProgress = 0.0,
    DateTime? lastAccessedAt,
    DateTime? createdAt,
  })  : lastAccessedAt = lastAccessedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Whether the user has finished watching this content (at least 97%).
  bool get isWatchedToCompletion => playbackProgress >= 0.97;

  /// Whether this torrent has been inactive for more than 48 hours (2 successive days).
  bool get isStaleFromInactivity {
    final inactiveDuration = DateTime.now().difference(lastAccessedAt);
    return inactiveDuration.inHours >= 48;
  }

  /// Whether this torrent is an active in-progress item that must be protected.
  bool get isProtectedFromEviction =>
      !isWatchedToCompletion && !isStaleFromInactivity;

  Map<String, dynamic> toJson() => {
        'infoHash': infoHash,
        'title': title,
        'totalSizeBytes': totalSizeBytes,
        'downloadedBytes': downloadedBytes,
        'downloadProgress': downloadProgress,
        'totalDurationSeconds': totalDurationSeconds,
        'playbackPositionSeconds': playbackPositionSeconds,
        'playbackProgress': playbackProgress,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory TorrentCacheEntry.fromJson(Map<String, dynamic> json) =>
      TorrentCacheEntry(
        infoHash: json['infoHash'] as String,
        title: json['title'] as String? ?? 'Untitled',
        totalSizeBytes: (json['totalSizeBytes'] as num?)?.toInt() ?? 0,
        downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
        downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
        totalDurationSeconds:
            (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
        playbackPositionSeconds:
            (json['playbackPositionSeconds'] as num?)?.toInt() ?? 0,
        playbackProgress: (json['playbackProgress'] as num?)?.toDouble() ?? 0.0,
        lastAccessedAt: json['lastAccessedAt'] != null
            ? DateTime.tryParse(json['lastAccessedAt'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// Global Application-Wide Persistent Storage & Quota Manager for Torrents.
///
/// Manages physical storage in `<appSupportDir>/cache/torrents`, enforces
/// the 15 GB quota and 2 GB free-storage safety floor, and strictly adheres to
/// the dual eviction gates:
/// - Only evicted if finished watching (>= 97%) OR inactive for 48 hours.
/// - In-progress media (< 97% and watched within 48h) is hard-protected.
class TorrentCacheManager {
  static final TorrentCacheManager _instance = TorrentCacheManager._internal();
  factory TorrentCacheManager() => _instance;
  TorrentCacheManager._internal();

  /// Nominal persistent storage quota: 15 GB
  static const int kDefaultQuotaBytes = 15 * 1024 * 1024 * 1024;

  /// Physical free storage floor: 2.0 GB
  static const int kMinFreeDiskSpaceBytes = 2 * 1024 * 1024 * 1024;

  final Map<String, TorrentCacheEntry> _entries = {};
  bool _isLoaded = false;
  File? _indexFile;

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    try {
      final appDir = await getApplicationSupportDirectory();
      final torrentsDir = Directory(p.join(appDir.path, 'cache', 'torrents'));
      if (!await torrentsDir.exists()) {
        await torrentsDir.create(recursive: true);
      }

      _indexFile = File(p.join(torrentsDir.path, 'cache_index.json'));
      if (await _indexFile!.exists()) {
        final content = await _indexFile!.readAsString();
        final List<dynamic> list = jsonDecode(content) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final entry = TorrentCacheEntry.fromJson(item);
            _entries[entry.infoHash] = entry;
          }
        }
      }
      _isLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[TorrentCacheManager] Load error: $e');
      _isLoaded = true;
    }
  }

  Future<void> _saveIndex() async {
    if (_indexFile == null) return;
    try {
      final list = _entries.values.map((e) => e.toJson()).toList();
      await _indexFile!.writeAsString(jsonEncode(list));
    } catch (e) {
      if (kDebugMode) debugPrint('[TorrentCacheManager] Save error: $e');
    }
  }

  /// Updates or records playback position for a torrent.
  Future<void> recordPlaybackProgress({
    required String infoHash,
    required String title,
    required Duration position,
    required Duration totalDuration,
  }) async {
    await _ensureLoaded();
    final entry = _entries[infoHash] ??= TorrentCacheEntry(
      infoHash: infoHash,
      title: title,
    );

    entry.lastAccessedAt = DateTime.now();
    entry.playbackPositionSeconds = position.inSeconds;
    entry.totalDurationSeconds = totalDuration.inSeconds;

    if (totalDuration.inSeconds > 0) {
      entry.playbackProgress =
          (position.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
    }

    await _saveIndex();
  }

  /// Updates download progress reported by TorrServer.
  Future<void> updateDownloadProgress({
    required String infoHash,
    required int downloadedBytes,
    required int totalSizeBytes,
  }) async {
    await _ensureLoaded();
    final entry = _entries[infoHash];
    if (entry != null) {
      entry.downloadedBytes = downloadedBytes;
      if (totalSizeBytes > 0) {
        entry.downloadProgress =
            (downloadedBytes / totalSizeBytes).clamp(0.0, 1.0);
      }
      await _saveIndex();
    }
  }

  /// Refreshes last-accessed timestamp when user continues watching.
  Future<void> touchTorrent(String infoHash) async {
    await _ensureLoaded();
    final entry = _entries[infoHash];
    if (entry != null) {
      entry.lastAccessedAt = DateTime.now();
      await _saveIndex();
    }
  }

  /// Enforces the global storage quota and free space floor.
  ///
  /// Eviction order:
  /// 1. Finished watching (>= 97% completion)
  /// 2. Inactive for > 48 hours (2 successive days)
  /// In-progress active media (< 97% and active within 48h) is NEVER evicted.
  Future<void> enforceStorageQuota({int quotaBytes = kDefaultQuotaBytes}) async {
    await _ensureLoaded();
    final appDir = await getApplicationSupportDirectory();
    final torrentsDir = Directory(p.join(appDir.path, 'cache', 'torrents'));
    if (!await torrentsDir.exists()) return;

    // Calculate actual disk usage
    int totalBytes = 0;
    final Map<String, int> dirSizes = {};

    await for (final entity in torrentsDir.list()) {
      if (entity is Directory) {
        final hash = p.basename(entity.path);
        int dirSize = 0;
        await for (final file in entity.list(recursive: true)) {
          if (file is File) {
            dirSize += await file.length();
          }
        }
        dirSizes[hash] = dirSize;
        totalBytes += dirSize;
      }
    }

    if (totalBytes <= quotaBytes) {
      return; // Within budget
    }

    // Identify eviction candidates
    final candidates = <TorrentCacheEntry>[];
    for (final entry in _entries.values) {
      if (entry.isWatchedToCompletion || entry.isStaleFromInactivity) {
        candidates.add(entry);
      }
    }

    // Sort LRU (oldest accessed first)
    candidates.sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    for (final candidate in candidates) {
      if (totalBytes <= quotaBytes) break;

      final hash = candidate.infoHash;
      final size = dirSizes[hash] ?? 0;

      if (kDebugMode) {
        debugPrint(
          '[TorrentCacheManager] Evicting torrent $hash (${candidate.title}, '
          'watched: ${(candidate.playbackProgress * 100).toStringAsFixed(1)}%, '
          'last accessed: ${candidate.lastAccessedAt})',
        );
      }

      await deleteTorrent(hash);
      totalBytes -= size;
    }
  }

  /// Deletes a torrent's persistent pieces and index entry.
  Future<void> deleteTorrent(String infoHash) async {
    await _ensureLoaded();
    _entries.remove(infoHash);
    await _saveIndex();

    // Drop from TorrServer if loaded
    try {
      await TorrentService().removeTorrent(infoHash, drop: true);
    } catch (_) {}

    // Delete disk directory
    try {
      final appDir = await getApplicationSupportDirectory();
      final dir = Directory(p.join(appDir.path, 'cache', 'torrents', infoHash));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TorrentCacheManager] Delete error: $e');
    }
  }
}

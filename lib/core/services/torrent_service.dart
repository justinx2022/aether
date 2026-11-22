import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_torrent_server/flutter_torrent_server.dart';
import '../utils/torrent_file_parser.dart';
import '../utils/app_utils.dart';
import '../models/torrent_status.dart';

class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;
  TorrentService._internal();

  final _server = FlutterTorrentServer();
  String? _serverUrl;
  bool _isStarted = false;
  String? _activeTorrentHash;
  String? _torrentsSavePath;

  String? get serverUrl => _serverUrl;
  String? get activeTorrentHash => _activeTorrentHash;
  String? get authToken => _server.authToken;
  bool get isStarted => _isStarted;

  Future<String> getTorrentsSavePath() async {
    if (_torrentsSavePath != null) return _torrentsSavePath!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'cache', 'torrents'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _torrentsSavePath = dir.path;
    return _torrentsSavePath!;
  }

  /// The cache the server is configured with, in megabytes, and how much of it
  /// is held ahead of the read point.
  ///
  /// Seeded with aggressive defaults for instant start without debrid:
  /// - 128 MB cache (was 512) = faster allocation, less RAM
  /// - 60% read-ahead (was 85%) = serves first byte immediately
  /// [applyBufferSettings] overrides with user preferences when player starts.
  int _cacheMb = 128;
  int _readAheadPercent = 80; // 80% forward read-ahead, 20% backward rewind margin

  /// Points the server's cache at the size the viewer chose for the player.
  ///
  /// One number for both engines: a viewer who asked for 256 MB of buffer
  /// meant it for whatever they are watching, and a torrent used to ignore
  /// them and take a hard-coded 64 MB whatever the setting said.
  ///
  /// Safe to call before the server is up - the values are remembered and
  /// applied by [start] - and safe to call again afterwards, which re-POSTs
  /// them. Note that TorrServer allocates the cache per torrent, so a change
  /// made mid-stream reaches the *next* torrent rather than the one playing.
  Future<void> applyBufferSettings({
    required int cacheMb,
    required int readAheadPercent,
  }) async {
    if (cacheMb == _cacheMb && readAheadPercent == _readAheadPercent) return;
    _cacheMb = cacheMb;
    _readAheadPercent = readAheadPercent;
    if (_isStarted) await _configureSettings();
  }

  Future<TorrentStatus?> getCurrentStatus() async {
    if (_activeTorrentHash == null || !_isStarted) {
      return null;
    }
    try {
      final statusMap = await _server.getTorrentStatus(_activeTorrentHash!);
      if (statusMap != null) {
        return TorrentStatus.fromMap(statusMap);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching status: $e");
    }
    return null;
  }

  Future<void> start() async {
    if (_isStarted) {
      return;
    }
    try {
      final port = await _server.start();
      if (port > 0) {
        _serverUrl = "http://127.0.0.1:$port";
        _isStarted = true;
        if (kDebugMode) debugPrint("Torrent Server started at $_serverUrl");
        await _configureSettings();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to start torrent server: $e");
    }
  }

  Future<void> _configureSettings() async {
    try {
      final token = _server.authToken;
      final headers = {
        'Content-Type': 'application/json',
        FlutterTorrentServer.authTokenHeader: ?token,
      };

      final savePath = await getTorrentsSavePath();
      // CacheSize sets the active per-torrent streaming working-set buffer in bytes
      // (respecting user buffer setting _cacheMb).
      final int workingSetCacheBytes = _cacheMb * 1024 * 1024;

      final settings = {
        "action": "set",
        "sets": {
          "CacheSize": workingSetCacheBytes,
          "ReaderReadAHead": _readAheadPercent,
          "PreloadCache": 1,                  // 1% preload ensures quick container probing
          "ConnectionsLimit": 120,            // High connection limit = fast parallel swarms
          "TorrentDisconnectTimeout": 30,     // 30s = stable peer handshake without dropping
          "RetrackersMode": 1,
          "UseDisk": true,                    // Disk persistence enabled
          "TorrentsSavePath": savePath,       // Persistent cache directory
          "RemoveCacheOnDrop": false,         // Guarded by Aether eviction manager
          "EnableIPv6": true,
          "DisableDHT": false,
          "DisablePEX": false,
          "DisableUPNP": false,
          "DisableTCP": false,
          "DisableUTP": false,
          "DownloadRateLimit": 0,             // 0 = unlimited throughput
          "UploadRateLimit": 0,               // 0 = unlimited upload
        }
      };

      final response = await http.post(
        Uri.parse("$_serverUrl/settings"),
        headers: headers,
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint("TorrServer: 95% read-ahead, 2% preload, 80 peers, 3s timeout, 500 DHT, RAM-only");
        }
      } else {
        if (kDebugMode) {
          debugPrint("TorrServer settings response status: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to configure TorrServer settings: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _server.stop();
    } catch (e) {
      if (kDebugMode) debugPrint("Error stopping torrent server: $e");
    } finally {
      _isStarted = false;
      _serverUrl = null;
      _activeTorrentHash = null;
    }
  }

  /// Adds a torrent link to TorrServer, returning its info-hash.
  Future<String?> addTorrent(String link) async {
    if (!_isStarted) await start();
    if (_serverUrl == null) return null;
    final prepared = await _prepareMagnetLink(link);
    final hash = await _server.addTorrent(prepared);
    if (hash != null) {
      _activeTorrentHash = hash;
    }
    return hash;
  }

  /// Polls for torrent metadata until file_stats is populated or timeout expires.
  Future<Map<String, dynamic>?> pollForMetadata(
    String hash, {
    Duration timeout = const Duration(seconds: 48),
    int? targetIndex,
    int? season,
    int? episode,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      try {
        final status = await _server.getTorrentStatus(hash);
        if (status != null && status['file_stats'] is List) {
          final fileStats = status['file_stats'] as List;
          if (fileStats.isNotEmpty) {
            return _findSequentialVideoFile(
              fileStats,
              targetIndex: targetIndex,
              season: season,
              episode: episode,
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> getStreamUrl(
    String magnetLink, {
    int? fileIndex,
    int? season,
    int? episode,
  }) async {
    if (!_isStarted) {
      await start();
    }
    if (_serverUrl == null) {
      return null;
    }

    try {
      final String linkToAdd = await _prepareMagnetLink(magnetLink);

      // Add Torrent with a 12s timeout
      final hash = await _server
          .addTorrent(linkToAdd)
          .timeout(const Duration(seconds: 12), onTimeout: () => null);
      if (hash == null) {
        throw Exception("Failed to add torrent or timed out");
      }
      _activeTorrentHash = hash;

      // Poll for Status to get Filename and File Index
      final fileInfo = await _pollForMetadata(
        hash,
        targetIndex: fileIndex,
        season: season,
        episode: episode,
      );
      if (fileInfo == null) {
        throw Exception("Timed out waiting for torrent metadata");
      }

      final int resolvedIndex = fileInfo['index'] as int;
      final rawPath = fileInfo['path'] as String? ?? 'video.mp4';
      final fileName = Uri.encodeComponent(rawPath.split(RegExp(r'[/\\]')).last);

      // Construct URL with proper filename and extension for instant container demuxing
      // Try to fetch from playlist first
      final playlistStreamUrl = await _fetchPlaylistUrl(hash, resolvedIndex);
      if (playlistStreamUrl != null) {
        return playlistStreamUrl;
      }

      // Fallback: Direct stream with filename
      return "$_serverUrl/stream/$fileName?link=$hash&index=$resolvedIndex&play";
    } catch (e) {
      if (kDebugMode) debugPrint("Error generating stream URL: $e");
      return null;
    }
  }

  static const List<String> _tier1Trackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.stealth.si:80/announce',
    'udp://tracker.torrent.eu.org:451/announce',
    'udp://open.demonii.com:1337/announce',
    'udp://open.tracker.cl:1337/announce',
    'udp://explodie.org:6969/announce',
    'udp://tracker.qu.ax:6969/announce',
    'udp://tracker.coppersurfer.tk:6969/announce',
    'http://tracker.opentrackr.org:1337/announce',
    'udp://tracker.openbittorrent.com:6969/announce',
    'udp://opentracker.i2p.rocks:6969/announce',
    'udp://tracker.internetwarriors.net:1337/announce',
    'udp://p4p.arenabg.com:1337/announce',
  ];

  Future<String> _prepareMagnetLink(String link) async {
    String resolved = link;
    if (!link.startsWith("magnet:") &&
        !link.startsWith("http") &&
        (AppUtils.isLocalFile(link) || link.contains(RegExp(r'\.torrent$')))) {
      try {
        resolved = await TorrentFileParser.getMagnetLink(link);
      } catch (e) {
        throw Exception("Failed to parse torrent file: $e");
      }
    }

    // Append Tier-1 fast trackers if the magnet link lacks comprehensive announces
    if (resolved.startsWith("magnet:")) {
      final buffer = StringBuffer(resolved);
      for (final tr in _tier1Trackers) {
        if (!resolved.contains(Uri.encodeComponent(tr)) && !resolved.contains(tr)) {
          buffer.write('&tr=${Uri.encodeComponent(tr)}');
        }
      }
      resolved = buffer.toString();
    }

    return resolved;
  }

  Future<Map<String, dynamic>?> _pollForMetadata(
    String hash, {
    int? targetIndex,
    int? season,
    int? episode,
  }) async {
    return pollForMetadata(
      hash,
      timeout: const Duration(seconds: 48),
      targetIndex: targetIndex,
      season: season,
      episode: episode,
    );
  }

  Map<String, dynamic> _findSequentialVideoFile(
    List<dynamic> fileStats, {
    int? targetIndex,
    int? season,
    int? episode,
  }) {
    if (targetIndex != null) {
      for (int i = 0; i < fileStats.length; i++) {
        final f = fileStats[i];
        if (f is Map) {
          final id = (f['id'] as num?)?.toInt() ?? i;
          if (id == targetIndex) {
            return {'index': id, 'path': f['path']?.toString() ?? 'video.mp4'};
          }
        }
      }
    }

    final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];
    final videoFiles = <Map<dynamic, dynamic>>[];

    for (final f in fileStats) {
      if (f is Map) {
        final path = f['path']?.toString() ?? "";
        if (path.isNotEmpty) {
          final lowerPath = path.toLowerCase();
          if (videoExtensions.any((ext) => lowerPath.endsWith(ext))) {
            videoFiles.add(f);
          }
        }
      }
    }

    if (videoFiles.isNotEmpty) {
      // If season & episode are requested, find matching episode file
      if (season != null && episode != null) {
        final sPad = season.toString().padLeft(2, '0');
        final ePad = episode.toString().padLeft(2, '0');
        final patterns = [
          RegExp('s0*$season\\s*e0*$episode\\b', caseSensitive: false),
          RegExp('s$sPad\\s*e$ePad', caseSensitive: false),
          RegExp('\\b$season\\s*x\\s*0*$episode\\b', caseSensitive: false),
          RegExp('\\bep(?:isode)?\\s*0*$episode\\b', caseSensitive: false),
          RegExp('\\be0*$episode\\b', caseSensitive: false),
        ];

        for (final regex in patterns) {
          for (final vf in videoFiles) {
            final p = (vf['path']?.toString() ?? '').toLowerCase();
            if (regex.hasMatch(p)) {
              final idx = (vf['id'] as num?)?.toInt() ?? videoFiles.indexOf(vf);
              if (kDebugMode) {
                debugPrint("Matched episode file: ${vf['path']} (Index: $idx)");
              }
              return {'index': idx, 'path': vf['path']};
            }
          }
        }
      }

      // Sort alphabetically to find the "first" file in sequence (e.g. S01E01)
      videoFiles.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );

      final selectedFile = videoFiles.first;
      int fileIndex = 0;
      if (selectedFile['id'] != null) {
        fileIndex = (selectedFile['id'] as num).toInt();
      }
      if (kDebugMode) {
        debugPrint(
          "Auto-selected video file: ${selectedFile['path']} (Index: $fileIndex)",
        );
      }
      return {'index': fileIndex, 'path': selectedFile['path']};
    }

    // Fallback to largest file if no video extension matches (e.g. strict naming)
    return _findLargestFile(fileStats);
  }

  Map<String, dynamic> _findLargestFile(List<dynamic> fileStats) {
    Map<dynamic, dynamic>? largestFile;
    int maxLen = -1;
    int largestIndex = 0;

    for (int i = 0; i < fileStats.length; i++) {
      final f = fileStats[i];
      if (f is Map) {
        final path = f['path']?.toString() ?? "";
        if (path.isNotEmpty) {
          final len = (f['length'] as num?)?.toInt() ?? 0;
          if (len > maxLen) {
            maxLen = len;
            largestFile = f;
            largestIndex = i;
          }
        }
      }
    }

    if (largestFile != null) {
      int fileIndex = largestIndex;
      if (largestFile['id'] != null) {
        fileIndex = (largestFile['id'] as num).toInt();
      }
      if (kDebugMode) {
        debugPrint(
          "Fallback to largest file: ${largestFile['path']} (Index: $fileIndex)",
        );
      }
      return {'index': fileIndex, 'path': largestFile['path']};
    }

    return {'index': 0, 'path': 'Unknown'};
  }

  Future<String?> _fetchPlaylistUrl(String hash, int index) async {
    try {
      final playlistUrl = "$_serverUrl/playlist?hash=$hash";
      final plResponse = await http.get(Uri.parse(playlistUrl));

      if (plResponse.statusCode == 200) {
        final lines = plResponse.body.split('\n');
        int currentIndex = 0;
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty && !line.startsWith('#')) {
            if (currentIndex == index) {
              String targetUrl = line;
              if (!targetUrl.startsWith('http')) {
                targetUrl = targetUrl.startsWith('/')
                    ? "$_serverUrl$targetUrl"
                    : "$_serverUrl/$targetUrl";
              }
              return targetUrl;
            }
            currentIndex++;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to fetch playlist: $e");
    }
    return null;
  }

  Future<String?> getStreamUrlForFileIndex(int index) async {
    if (_serverUrl == null || _activeTorrentHash == null) {
      return null;
    }

    // Use "Simplified" format for maximum compatibility
    final streamUrl =
        "$_serverUrl/stream?link=$_activeTorrentHash&index=$index&play";
    if (kDebugMode) {
      debugPrint("Generated Stream URL for Index $index: $streamUrl");
    }
    return streamUrl;
  }

  /// Remove a torrent from TorrServer
  /// Uses correct "drop" property (not "dropData")
  Future<void> removeTorrent(String hash, {bool drop = true}) async {
    if (!_isStarted || _serverUrl == null) return;
    try {
      final token = _server.authToken;
      final headers = {
        'Content-Type': 'application/json',
        FlutterTorrentServer.authTokenHeader: ?token,
      };
      await http.post(
        Uri.parse("$_serverUrl/torrents"),
        headers: headers,
        body: jsonEncode({
          'action': 'rem',
          'hash': hash,
          'drop': drop,  // FIXED: "drop" not "dropData"
        }),
      ).timeout(const Duration(seconds: 5));
      if (kDebugMode) debugPrint('Removed torrent: $hash (drop: $drop)');
    } catch (e) {
      if (kDebugMode) debugPrint('removeTorrent error: $e');
    }
  }

  /// Get status of all active torrents for cleanup
  Future<List<Map<String, dynamic>>> getAllTorrentsStatus() async {
    if (!_isStarted || _serverUrl == null) return [];
    try {
      final token = _server.authToken;
      final headers = {
        'Content-Type': 'application/json',
        FlutterTorrentServer.authTokenHeader: ?token,
      };
      final response = await http.post(
        Uri.parse("$_serverUrl/torrents"),
        headers: headers,
        body: jsonEncode({'action': 'get'}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
        if (decoded is Map && decoded['torrents'] is List) {
          return (decoded['torrents'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getAllTorrentsStatus error: $e');
    }
    return [];
  }
}

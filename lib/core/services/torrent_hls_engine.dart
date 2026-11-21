import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Represents media metadata probed from a container or stream.
class MediaProbeResult {
  final String format;
  final Duration duration;
  final String? videoCodec;
  final String? audioCodec;
  final int? width;
  final int? height;
  final double? frameRate;
  final int? bitrate;

  const MediaProbeResult({
    required this.format,
    required this.duration,
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.frameRate,
    this.bitrate,
  });

  bool get isVideoCompatible =>
      videoCodec == 'h264' ||
      videoCodec == 'hevc' ||
      videoCodec == 'h265' ||
      videoCodec == 'vp9' ||
      videoCodec == 'av1';

  bool get isAudioCompatible =>
      audioCodec == 'aac' ||
      audioCodec == 'mp3' ||
      audioCodec == 'ac3' ||
      audioCodec == 'eac3';

  RemuxMode get recommendedRemuxMode {
    if (isVideoCompatible && isAudioCompatible) {
      return RemuxMode.directRemux;
    }
    if (isVideoCompatible && !isAudioCompatible) {
      return RemuxMode.audioTranscode;
    }
    return RemuxMode.fullTranscode;
  }
}

enum RemuxMode {
  /// Copy both video and audio streams (-c:v copy -c:a copy). 0% CPU overhead.
  directRemux,

  /// Copy video, transcode audio to stereo AAC (-c:v copy -c:a aac). <3% CPU overhead.
  audioTranscode,

  /// Full software transcode (emergency fallback only).
  fullTranscode,
}

class TorrentHlsEngine {
  static final TorrentHlsEngine _instance = TorrentHlsEngine._internal();
  factory TorrentHlsEngine() => _instance;
  TorrentHlsEngine._internal();

  /// Locates FFmpeg and FFprobe binaries on the host system.
  String? _ffmpegPath;
  String? _ffprobePath;

  Future<String?> findFfmpeg() async {
    if (_ffmpegPath != null) return _ffmpegPath;
    try {
      final res = await Process.run('ffmpeg', ['-version']);
      if (res.exitCode == 0) {
        _ffmpegPath = 'ffmpeg';
        return _ffmpegPath;
      }
    } catch (_) {}

    // Fallback search locations on Windows
    if (Platform.isWindows) {
      final winGetLinks = p.join(
        Platform.environment['LOCALAPPDATA'] ?? '',
        'Microsoft',
        'WinGet',
        'Links',
        'ffmpeg.exe',
      );
      if (await File(winGetLinks).exists()) {
        _ffmpegPath = winGetLinks;
        return _ffmpegPath;
      }
    }
    return null;
  }

  Future<String?> findFfprobe() async {
    if (_ffprobePath != null) return _ffprobePath;
    try {
      final res = await Process.run('ffprobe', ['-version']);
      if (res.exitCode == 0) {
        _ffprobePath = 'ffprobe';
        return _ffprobePath;
      }
    } catch (_) {}

    if (Platform.isWindows) {
      final winGetLinks = p.join(
        Platform.environment['LOCALAPPDATA'] ?? '',
        'Microsoft',
        'WinGet',
        'Links',
        'ffprobe.exe',
      );
      if (await File(winGetLinks).exists()) {
        _ffprobePath = winGetLinks;
        return _ffprobePath;
      }
    }
    return null;
  }

  /// Probes the stream source to extract container and codec metadata.
  Future<MediaProbeResult?> probe(String streamUrl) async {
    final ffprobe = await findFfprobe();
    if (ffprobe == null) {
      if (kDebugMode) debugPrint('[TorrentHlsEngine] ffprobe not available, using default probe');
      return null;
    }

    try {
      final result = await Process.run(
        ffprobe,
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          '-analyzeduration',
          '3000000',
          '-probesize',
          '5000000',
          streamUrl,
        ],
      ).timeout(const Duration(seconds: 8));

      if (result.exitCode == 0) {
        final Map<String, dynamic> data =
            jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        final format = data['format'] as Map<String, dynamic>? ?? {};
        final streams = data['streams'] as List<dynamic>? ?? [];

        final durationSeconds =
            double.tryParse(format['duration']?.toString() ?? '0') ?? 0;
        final formatName = format['format_name']?.toString() ?? 'unknown';
        final bitrate = int.tryParse(format['bit_rate']?.toString() ?? '0');

        String? vCodec;
        String? aCodec;
        int? width;
        int? height;
        double? fps;

        for (final s in streams) {
          if (s is Map<String, dynamic>) {
            final codecType = s['codec_type'];
            if (codecType == 'video' && vCodec == null) {
              vCodec = s['codec_name']?.toString().toLowerCase();
              width = int.tryParse(s['width']?.toString() ?? '');
              height = int.tryParse(s['height']?.toString() ?? '');
              final rFrameRate = s['r_frame_rate']?.toString();
              if (rFrameRate != null && rFrameRate.contains('/')) {
                final parts = rFrameRate.split('/');
                final num = double.tryParse(parts[0]) ?? 0;
                final den = double.tryParse(parts[1]) ?? 1;
                if (den > 0) fps = num / den;
              }
            } else if (codecType == 'audio' && aCodec == null) {
              aCodec = s['codec_name']?.toString().toLowerCase();
            }
          }
        }

        return MediaProbeResult(
          format: formatName,
          duration: Duration(milliseconds: (durationSeconds * 1000).round()),
          videoCodec: vCodec,
          audioCodec: aCodec,
          width: width,
          height: height,
          frameRate: fps,
          bitrate: bitrate,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TorrentHlsEngine] Probe error: $e');
    }
    return null;
  }

  /// Spawns an FFmpeg HLS packaging process.
  ///
  /// Uses Fast Input Seeking (-ss before -i) to align keyframes directly off
  /// TorrServer's seekable HTTP byte-range stream.
  Future<Process> startHlsPackaging({
    required String inputUrl,
    required String outputDir,
    Duration? seekOffset,
    int startSegmentNumber = 0,
    RemuxMode mode = RemuxMode.directRemux,
    int targetSegmentDuration = 3,
  }) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) {
      throw StateError('FFmpeg binary not found on host system.');
    }

    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final args = <String>[
      '-nostdin',
      '-threads',
      '2', // Controlled thread count to prevent thermal throttling
      '-fflags',
      '+genpts+discardcorrupt',
    ];

    // Fast Input Seeking (-ss before -i): FFmpeg seeks using container index
    if (seekOffset != null && seekOffset > Duration.zero) {
      final seconds = seekOffset.inMilliseconds / 1000.0;
      args.addAll(['-ss', seconds.toStringAsFixed(3)]);
    }

    args.addAll(['-i', inputUrl]);

    // Stream mapping & codec selection
    args.addAll(['-map', '0:v:0?']);
    args.addAll(['-map', '0:a:0?']);

    if (mode == RemuxMode.fullTranscode) {
      args.addAll(['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22']);
      args.addAll(['-c:a', 'aac', '-b:a', '192k', '-ac', '2']);
    } else if (mode == RemuxMode.audioTranscode) {
      args.addAll(['-c:v', 'copy']);
      args.addAll(['-c:a', 'aac', '-b:a', '192k', '-ac', '2']);
    } else {
      args.addAll(['-c:v', 'copy']);
      args.addAll(['-c:a', 'copy']);
    }

    // Segment & HLS packaging
    final segmentPattern = p.join(outputDir, 'seg_%05d.ts');
    final playlistPath = p.join(outputDir, 'live.m3u8');

    args.addAll([
      '-f',
      'hls',
      '-hls_time',
      targetSegmentDuration.toString(),
      '-hls_list_size',
      '0', // Record all segments
      '-hls_segment_type',
      'mpegts',
      '-hls_flags',
      'temp_file', // Write .tmp then rename atomically
    ]);

    if (startSegmentNumber > 0) {
      args.addAll(['-start_number', startSegmentNumber.toString()]);
      if (seekOffset != null && seekOffset > Duration.zero) {
        final offsetSeconds = seekOffset.inMilliseconds / 1000.0;
        args.addAll(['-output_ts_offset', offsetSeconds.toStringAsFixed(3)]);
      }
    }

    args.addAll([
      '-hls_segment_filename',
      segmentPattern,
      playlistPath,
    ]);

    if (kDebugMode) {
      debugPrint('[TorrentHlsEngine] Spawning FFmpeg: $ffmpeg ${args.join(" ")}');
    }

    final process = await Process.start(ffmpeg, args);

    process.stderr.transform(utf8.decoder).listen((line) {
      if (kDebugMode && line.contains('Error')) {
        debugPrint('[FFmpeg Error] $line');
      }
    });

    return process;
  }
}

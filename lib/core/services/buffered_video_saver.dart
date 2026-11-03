import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/entity/multimedia_item.dart';

/// Service to export fully buffered streams or active playback sessions
/// directly to the user's public Downloads directory.
class BufferedVideoSaver {
  BufferedVideoSaver._();

  static final BufferedVideoSaver instance = BufferedVideoSaver._();

  /// Gets the clean public Downloads directory path across Android and Desktop.
  Future<Directory> getExportDirectory() async {
    Directory? base;
    if (Platform.isAndroid) {
      final ext = Directory('/storage/emulated/0/Download');
      if (await ext.exists()) {
        base = ext;
      }
    }
    base ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

    final aetherDir = Directory(p.join(base.path, 'Aether'));
    if (!await aetherDir.exists()) {
      await aetherDir.create(recursive: true);
    }
    return aetherDir;
  }

  /// Generates a sanitized filename for the media.
  String sanitizeFileName(MultimediaItem item, Episode? episode) {
    final title = item.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (episode != null && episode.episode > 0) {
      final s = episode.season.toString().padLeft(2, '0');
      final e = episode.episode.toString().padLeft(2, '0');
      return '$title.S${s}E$e.mp4';
    }
    return '$title.mp4';
  }

  /// Exports an active stream URL to the Downloads directory.
  Future<File?> exportStreamToFile({
    required String streamUrl,
    required MultimediaItem item,
    Episode? episode,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
      }

      final dir = await getExportDirectory();
      final filename = sanitizeFileName(item, episode);
      final targetFile = File(p.join(dir.path, filename));

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamUrl));
      headers?.forEach((k, v) {
        request.headers.set(k, v);
      });

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.partialContent) {
        client.close();
        return null;
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      if (kDebugMode) {
        debugPrint('[BufferedVideoSaver] Successfully saved to ${targetFile.path}');
      }
      return targetFile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BufferedVideoSaver] Export error: $e');
      }
      return null;
    }
  }
}

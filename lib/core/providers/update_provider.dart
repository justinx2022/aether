import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/github_release.dart';
import '../services/update_service.dart';

part 'update_provider.g.dart';

abstract class UpdateState {}

class UpdateInitial extends UpdateState {}

class UpdateChecking extends UpdateState {}

class UpdateAvailable extends UpdateState {
  final GithubRelease release;
  UpdateAvailable(this.release);
}

class UpdateDownloading extends UpdateState {
  final double progress;
  UpdateDownloading(this.progress);
}

class UpdateDownloaded extends UpdateState {
  final File file;
  UpdateDownloaded(this.file);
}

class UpdateError extends UpdateState {
  final String message;
  UpdateError(this.message);
}

@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  late final UpdateService _service;

  @override
  UpdateState build() {
    _service = ref.read(updateServiceProvider);
    return UpdateInitial();
  }

  Future<void> checkForUpdates() async {
    if (kDebugMode) debugPrint('[UpdateController] Starting update check...');
    state = UpdateChecking();
    try {
      final release = await _service.checkForUpdate();
      // Removed ref.mounted guard to prevent silent exits; keepAlive ensures state safety.

      if (release != null) {
        if (kDebugMode) {
          debugPrint('[UpdateController] Update AVAILABLE: ${release.tagName}');
        }
        state = UpdateAvailable(release);
      } else {
        if (kDebugMode) {
          debugPrint('[UpdateController] No update found (status: Initial)');
        }
        state = UpdateInitial();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateController] Update check FAILED: $e');
      state = UpdateError(e.toString());
    }
  }

  Future<void> downloadAndInstall(GithubRelease release) async {
    // iOS sandboxing requires opening the platform release or TestFlight url
    if (Platform.isIOS) {
      final asset = await _service.findPlatformAsset(release);
      final url = asset?.browserDownloadUrl ?? release.htmlUrl;

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      state = UpdateInitial();
      return;
    }

    // On Android, Windows, macOS, and Linux: Download directly in-app with live progress bar
    state = UpdateDownloading(0.0);
    try {
      final file = await _service.downloadUpdateAsset(release, (progress) {
        try {
          if (ref.mounted) state = UpdateDownloading(progress);
        } catch (_) {}
      });

      if (file != null) {
        state = UpdateDownloaded(file);

        // Android package installer requires explicit permission
        if (Platform.isAndroid) {
          final status = await Permission.requestInstallPackages.request();
          if (!status.isGranted) {
            state = UpdateError(
              "Install permission denied. Please grant permission to install unknown apps.",
            );
            return;
          }
        }

        // On Linux: Ensure downloaded AppImage or binary is executable
        if (Platform.isLinux) {
          try {
            await Process.run('chmod', ['+x', file.path]);
          } catch (_) {}
        }

        // Trigger native OS installation directly
        if (Platform.isWindows && file.path.toLowerCase().endsWith('.exe')) {
          await Process.start(file.path, [], mode: ProcessStartMode.detached);
          exit(0);
        } else {
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done) {
            state = UpdateError("Install failed: ${result.message}");
          }
        }
      } else {
        state = UpdateError(
          "Failed to find appropriate asset for this platform.",
        );
      }
    } catch (e) {
      state = UpdateError("Download failed: $e");
    }
  }
}

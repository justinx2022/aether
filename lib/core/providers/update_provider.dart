import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/github_release.dart';
import '../services/update_service.dart';
import '../storage/storage_service.dart';

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

  Future<GithubRelease?> checkForUpdates({
    bool manual = false,
    bool force = false,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[UpdateController] Starting update check (manual=$manual, force=$force)...',
      );
    }
    state = UpdateChecking();
    try {
      final release = await _service.checkForUpdate(force: force);

      if (release != null) {
        if (kDebugMode) {
          debugPrint('[UpdateController] Update AVAILABLE: ${release.tagName}');
        }
        state = UpdateAvailable(release);
        return release;
      } else {
        if (kDebugMode) {
          debugPrint('[UpdateController] No update found (status: Initial)');
        }
        state = UpdateInitial();
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateController] Update check FAILED: $e');
      state = UpdateError(e.toString());
      return null;
    }
  }

  Future<void> downloadAndInstall(GithubRelease release) async {
    // For iOS, just open the release URL
    // For iOS and Desktop platforms, use browser-managed downloads
    if (Platform.isIOS ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux) {
      final asset = await _service.findPlatformAsset(release);

      final url = asset?.browserDownloadUrl ?? release.htmlUrl;

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      state = UpdateInitial();
      return;
    }

    state = UpdateDownloading(0.0);
    try {
      final file = await _service.downloadUpdateAsset(release, (progress) {
        try {
          if (ref.mounted) state = UpdateDownloading(progress);
        } catch (_) {}
      });

      if (file != null) {
        state = UpdateDownloaded(file);

        // Record the release timestamp so the app knows this build has been installed
        final asset = await _service.findPlatformAsset(release);
        final timestamp =
            asset?.updatedAt ?? release.publishedAt ?? DateTime.now();
        await ref
            .read(storageServiceProvider)
            .setLastInstalledReleaseTime(timestamp);

        // Android requires explicit permission to install packages
        if (Platform.isAndroid) {
          final status = await Permission.requestInstallPackages.request();
          if (!status.isGranted) {
            state = UpdateError(
              "Install permission denied. Please grant permission to install unknown apps.",
            );
            return;
          }
        }

        // Trigger installation via package installer
        final result = await OpenFile.open(
          file.path,
          type: Platform.isAndroid
              ? 'application/vnd.android.package-archive'
              : null,
        );
        if (result.type != ResultType.done) {
          state = UpdateError("Install failed: ${result.message}");
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

import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:version/version.dart';

import '../data/models/github_release.dart';
import '../storage/storage_service.dart';

import '../network/dio_client_provider.dart';

part 'update_service.g.dart';

// Read by the keepAlive updateProvider, so it outlives every autoDispose
// cycle anyway.
@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) {
  return UpdateService(
    ref.watch(dioClientProvider),
    ref.watch(storageServiceProvider),
  );
}

class UpdateService {
  final Dio _dio;
  final StorageService _storage;
  static const String _owner = 'justinx2022';
  static const String _repo = 'aether';

  UpdateService(this._dio, this._storage);

  static Version? _tryParseVersion(String text) {
    try {
      return Version.parse(text);
    } catch (_) {
      return null;
    }
  }

  Future<GithubRelease?> checkForUpdate({bool force = false}) async {
    try {
      final currentPackageInfo = await PackageInfo.fromPlatform();
      final currentVersion = _tryParseVersion(currentPackageInfo.version);

      // Determine platform-specific endpoint:
      // GitHub Actions release workflows publish to 'android-latest' and 'windows-latest'
      String endpoint =
          'https://api.github.com/repos/$_owner/$_repo/releases/latest';
      if (!kIsWeb && Platform.isAndroid) {
        endpoint =
            'https://api.github.com/repos/$_owner/$_repo/releases/tags/android-latest';
      } else if (!kIsWeb && Platform.isWindows) {
        endpoint =
            'https://api.github.com/repos/$_owner/$_repo/releases/tags/windows-latest';
      }

      Response<Map<String, dynamic>> response;
      try {
        response = await _dio.get<Map<String, dynamic>>(endpoint);
      } catch (e) {
        // Fallback to releases/latest if the specific tag is missing
        response = await _dio.get<Map<String, dynamic>>(
          'https://api.github.com/repos/$_owner/$_repo/releases/latest',
        );
      }

      if (response.statusCode == 200 && response.data != null) {
        final release = GithubRelease.fromJson(response.data!);
        final platformAsset = await findPlatformAsset(release);
        if (platformAsset == null) return null;

        if (force) {
          return release;
        }

        // 1. Try semver comparison if tag is a valid version (e.g., 'v2.8.2' -> 2.8.2)
        final tagName = release.tagName.replaceAll(RegExp(r'^v'), '');
        final latestVersion = _tryParseVersion(tagName);

        if (latestVersion != null && currentVersion != null) {
          if (latestVersion > currentVersion) {
            if (kDebugMode) {
              debugPrint(
                '[UpdateService] New semantic version: $latestVersion > $currentVersion',
              );
            }
            return release;
          }
        }

        // 2. Rolling release tags ('android-latest', 'windows-latest') or identical version:
        // Compare the asset's upload timestamp with the locally stored install timestamp.
        final assetTime = platformAsset.updatedAt ?? release.publishedAt;
        if (assetTime != null) {
          final installedTime = _storage.getLastInstalledReleaseTime();
          if (installedTime == null) {
            // First time running on this device: record current asset time
            // so we don't nag on immediate initial launch.
            await _storage.setLastInstalledReleaseTime(assetTime);
            return null;
          } else if (assetTime.isAfter(
            installedTime.add(const Duration(minutes: 2)),
          )) {
            if (kDebugMode) {
              debugPrint(
                '[UpdateService] New build asset detected: $assetTime > $installedTime',
              );
            }
            return release;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] Update check failed: $e');
    }
    return null;
  }

  Future<File?> downloadUpdateAsset(
    GithubRelease release,
    void Function(double) onProgress,
  ) async {
    try {
      final asset = await findPlatformAsset(release);
      if (asset == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${asset.name}';

      await _dio.download(
        asset.browserDownloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      final file = File(savePath);
      final digest = asset.digest;
      const sha256Prefix = 'sha256:';
      if (digest != null && digest.startsWith(sha256Prefix)) {
        final expected = digest.substring(sha256Prefix.length).toLowerCase();
        final actual = (await sha256.bind(file.openRead()).first).toString();
        if (actual != expected) {
          if (kDebugMode) {
            debugPrint(
              '[UpdateService] Digest mismatch for ${asset.name}: '
              'expected $expected, got $actual — discarding download',
            );
          }
          await file.delete();
          return null;
        }
      }

      return file;
    } catch (e) {
      if (kDebugMode) debugPrint('Download failed: $e');
      return null;
    }
  }

  Future<GithubAsset?> findPlatformAsset(GithubRelease release) async {
    final assets = release.assets
        .where((a) => !a.name.toLowerCase().contains('debug'))
        .toList();

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;

      // 1. Match specific ABI (arm64-v8a, armeabi-v7a, x86_64)
      for (final abi in abis) {
        final match = assets.firstWhereOrNull(
          (a) =>
              a.name.toLowerCase().contains('android') &&
              a.name.toLowerCase().contains(abi.toLowerCase()),
        );
        if (match != null) return match;
      }

      // 2. Fallback to universal
      final universal = assets.firstWhereOrNull(
        (a) =>
            a.name.toLowerCase().contains('android') &&
            a.name.toLowerCase().contains('universal'),
      );
      if (universal != null) return universal;

      // 3. Last resort: any APK
      return assets.firstWhereOrNull(
        (a) =>
            a.name.toLowerCase().contains('android') &&
            a.name.toLowerCase().endsWith('.apk'),
      );
    } else if (Platform.isWindows) {
      final arch =
          Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ??
          'x64';
      final isArm = arch.contains('arm') || arch.contains('aarch64');
      final archTag = isArm ? 'arm64' : 'x64';

      final windowsAssets = assets
          .where((a) => a.name.toLowerCase().contains('windows'))
          .toList();
      var archAssets = windowsAssets
          .where((a) => a.name.toLowerCase().contains(archTag))
          .toList();

      // Fallback for x86_64 / amd64 naming
      if (archAssets.isEmpty && !isArm) {
        archAssets = windowsAssets
            .where(
              (a) =>
                  a.name.toLowerCase().contains('x86_64') ||
                  a.name.toLowerCase().contains('amd64'),
            )
            .toList();
      }

      if (archAssets.isNotEmpty) {
        // Prefer .exe, then .msix, then .zip
        return archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.exe'),
            ) ??
            archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.msix'),
            ) ??
            archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.zip'),
            ) ??
            archAssets.first;
      }

      // 2. Fallback to any windows installer
      return windowsAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.exe'),
          ) ??
          windowsAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.zip'),
          );
    } else if (Platform.isMacOS) {
      final info = await DeviceInfoPlugin().macOsInfo;
      final arch = info.arch.toLowerCase(); // e.g. "arm64" or "x86_64"

      final macosAssets = assets
          .where(
            (a) =>
                a.name.toLowerCase().contains('macos') ||
                a.name.toLowerCase().contains('mac'),
          )
          .toList();
      var archAssets = macosAssets
          .where((a) => a.name.toLowerCase().contains(arch))
          .toList();

      // Fallback for x64 alias
      if (archAssets.isEmpty && arch == 'x86_64') {
        archAssets = macosAssets
            .where((a) => a.name.toLowerCase().contains('x64'))
            .toList();
      }

      if (archAssets.isNotEmpty) {
        // Prefer .dmg over .zip
        return archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.dmg'),
            ) ??
            archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.zip'),
            ) ??
            archAssets.first;
      }

      return macosAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.dmg'),
          ) ??
          macosAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.zip'),
          );
    } else if (Platform.isLinux) {
      final version = Platform.version.toLowerCase();
      final isArm = version.contains('arm') || version.contains('aarch64');
      final archTag = isArm ? 'arm64' : 'x64';

      final linuxAssets = assets
          .where((a) => a.name.toLowerCase().contains('linux'))
          .toList();
      var archAssets = linuxAssets
          .where((a) => a.name.toLowerCase().contains(archTag))
          .toList();

      // Fallback for x86_64 alias
      if (archAssets.isEmpty && !isArm) {
        archAssets = linuxAssets
            .where((a) => a.name.toLowerCase().contains('x86_64'))
            .toList();
      }

      if (archAssets.isNotEmpty) {
        return archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.appimage'),
            ) ??
            archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.deb'),
            ) ??
            archAssets.firstWhereOrNull(
              (a) => a.name.toLowerCase().endsWith('.tar.gz'),
            ) ??
            archAssets.first;
      }

      // 2. Fallback to any Linux installer type
      return linuxAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.appimage'),
          ) ??
          linuxAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.deb'),
          ) ??
          linuxAssets.firstWhereOrNull(
            (a) => a.name.toLowerCase().endsWith('.tar.gz'),
          );
    }
    return null;
  }
}

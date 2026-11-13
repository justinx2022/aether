import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skystream/core/services/update_service.dart';
import 'package:skystream/core/storage/storage_service.dart';

class _FakeStorageService extends StorageService {
  DateTime? _installedTime;

  @override
  Future<void> setLastInstalledReleaseTime(DateTime time) async {
    _installedTime = time;
  }

  @override
  DateTime? getLastInstalledReleaseTime() => _installedTime;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService rolling tag & in-app updater', () {
    test('Detects new rolling release when asset timestamp is newer', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Aether',
        packageName: 'app.skystream',
        version: '2.8.1',
        buildNumber: '1',
        buildSignature: '',
      );

      final fakeStorage = _FakeStorageService();
      // Previously installed 2 hours ago
      await fakeStorage.setLastInstalledReleaseTime(
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      // Create a mock Dio adapter that returns android-latest release
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) {
        return ResponseBody.fromString(
          '''
          {
            "tag_name": "android-latest",
            "html_url": "https://github.com/justinx2022/aether/releases/tag/android-latest",
            "body": "Latest Android build",
            "prerelease": false,
            "published_at": "${DateTime.now().toIso8601String()}",
            "assets": [
              {
                "name": "aether-android-arm64-v8a.apk",
                "browser_download_url": "https://example.com/arm64.apk",
                "size": 48000000,
                "content_type": "application/vnd.android.package-archive",
                "updated_at": "${DateTime.now().toIso8601String()}"
              },
              {
                "name": "aether-windows-x64.exe",
                "browser_download_url": "https://example.com/windows-x64.exe",
                "size": 65000000,
                "content_type": "application/octet-stream",
                "updated_at": "${DateTime.now().toIso8601String()}"
              }
            ]
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = UpdateService(dio, fakeStorage);
      final update = await service.checkForUpdate();

      expect(update, isNotNull);
      expect(update!.tagName, 'android-latest');
      expect(update.assets.any((a) => a.name.contains('aether')), isTrue);
    });

    test('force: true returns release even if already up to date', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Aether',
        packageName: 'app.skystream',
        version: '2.8.1',
        buildNumber: '1',
        buildSignature: '',
      );

      final fakeStorage = _FakeStorageService();
      final now = DateTime.now();
      await fakeStorage.setLastInstalledReleaseTime(now);

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) {
        return ResponseBody.fromString(
          '''
          {
            "tag_name": "android-latest",
            "html_url": "https://github.com/justinx2022/aether/releases/tag/android-latest",
            "body": "Latest Android build",
            "prerelease": false,
            "published_at": "${now.toIso8601String()}",
            "assets": [
              {
                "name": "aether-android-arm64-v8a.apk",
                "browser_download_url": "https://example.com/arm64.apk",
                "size": 48000000,
                "content_type": "application/vnd.android.package-archive",
                "updated_at": "${now.toIso8601String()}"
              },
              {
                "name": "aether-windows-x64.exe",
                "browser_download_url": "https://example.com/windows-x64.exe",
                "size": 65000000,
                "content_type": "application/octet-stream",
                "updated_at": "${now.toIso8601String()}"
              }
            ]
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = UpdateService(dio, fakeStorage);

      // Normal check should be null because timestamp is identical
      final normalCheck = await service.checkForUpdate();
      expect(normalCheck, isNull);

      // Force check should return the release so the user can reinstall
      final forceCheck = await service.checkForUpdate(force: true);
      expect(forceCheck, isNotNull);
      expect(forceCheck!.tagName, 'android-latest');
    });
  });
}

class _MockHttpAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  _MockHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

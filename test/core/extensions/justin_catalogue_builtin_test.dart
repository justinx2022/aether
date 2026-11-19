import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:aether/core/extensions/models/extension_plugin.dart';
import 'package:aether/core/extensions/services/plugin_storage_service.dart';
import 'package:aether/core/extensions/extension_manager.dart';
import 'package:aether/core/extensions/base_provider.dart';
import 'package:aether/core/storage/storage_service.dart';
import 'package:aether/core/domain/entity/multimedia_item.dart';
import 'package:dio/dio.dart';

class _FakeCatalogueProvider extends AetherProvider {
  _FakeCatalogueProvider() : super();

  @override
  String get packageName => 'dev.justin.catalogue';
  @override
  String get name => "Justin's Catalogue";
  @override
  String get mainUrl => 'https://v3-cinemeta.strem.io';
  @override
  String get version => '13';
  @override
  List<String> get languages => const ['en'];
  @override
  Set<ProviderType> get supportedTypes => const {
    ProviderType.movie,
    ProviderType.series,
  };

  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async {
    return {
      'Popular Movies': [
        MultimediaItem(
          title: 'Dune: Part Two',
          url: 'https://v3-cinemeta.strem.io/meta/movie/tt15239678.json',
          posterUrl: 'https://images.metahub.space/poster/medium/tt15239678/img',
          contentType: MultimediaContentType.movie,
          provider: name,
        ),
      ],
      'Popular Series': [
        MultimediaItem(
          title: 'Breaking Bad',
          url: 'https://v3-cinemeta.strem.io/meta/series/tt0903747.json',
          posterUrl: 'https://images.metahub.space/poster/medium/tt0903747/img',
          contentType: MultimediaContentType.series,
          provider: name,
        ),
      ],
    };
  }

  @override
  Future<List<MultimediaItem>> search(String query, {CancelToken? cancelToken}) async {
    return [
      MultimediaItem(
        title: query,
        url: 'https://v3-cinemeta.strem.io/meta/movie/tt1234567.json',
        posterUrl: '',
        contentType: MultimediaContentType.movie,
        provider: name,
      ),
    ];
  }

  @override
  Future<MultimediaItem> getDetails(String url) async {
    return MultimediaItem(
      title: 'Dune: Part Two',
      url: url,
      posterUrl: '',
      contentType: MultimediaContentType.movie,
      provider: name,
    );
  }

  @override
  Future<List<StreamResult>> loadStreams(String url) async {
    return [
      StreamResult(
        source: "Justin's Catalogue [VixSrc 1080p]",
        url: 'https://vixcloud.co/playlist/1080p.m3u8',
        headers: {'Referer': 'https://vixsrc.to/'},
      ),
    ];
  }
}

class _FakeManagerWithCatalogue extends ExtensionManager {
  final List<AetherProvider> _providers;
  _FakeManagerWithCatalogue(this._providers);

  @override
  List<AetherProvider> build() {
    return _providers;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Justin's Catalogue Builtin Integration Tests", () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('justin_catalogue_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('assets/plugins bundle contains valid production Justin Catalogue', () {
      final manifestFile = File('assets/plugins/plugin.json');
      expect(manifestFile.existsSync(), isTrue);

      final jsFile = File('assets/plugins/plugin.js');
      expect(jsFile.existsSync(), isTrue);

      final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['packageName'] ?? manifest['id'], 'dev.justin.catalogue');
      expect(manifest['name'], "Justin's Catalogue");
      expect(manifest['version'], greaterThanOrEqualTo(13));
      expect(manifest['categories'], containsAll(['Movie', 'TvSeries']));
      expect(manifest['baseUrl'], 'https://v3-cinemeta.strem.io');

      final jsContent = jsFile.readAsStringSync();
      // Ensure Cinemeta, VixSrc, VidApi and HubCloud extractors are present
      expect(jsContent.contains('cinemeta-catalogs.strem.io') || jsContent.contains('cinemeta'), isTrue);
      expect(jsContent.contains('vixsrc') || jsContent.contains('vixcloud'), isTrue);
      expect(jsContent.contains('vaplayer.ru') || jsContent.contains('streamdata'), isTrue);
    });

    test('PluginStorageService automatically unpacks Justin Catalogue on cold boot with zero network', () async {
      // Mock path_provider to use tempDir
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      binding.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => tempDir.path,
      );

      final storageService = PluginStorageService();
      final installed = await storageService.listInstalledPlugins();

      expect(installed, isNotEmpty);
      final catalogue = installed.firstWhere(
        (p) => p.packageName == 'dev.justin.catalogue',
        orElse: () => throw TestFailure("dev.justin.catalogue was not unpacked"),
      );

      expect(catalogue.name, "Justin's Catalogue");
      expect(catalogue.version, greaterThanOrEqualTo(13));
      expect(catalogue.manifest['installSha256'], isNotNull);
      expect(catalogue.manifest['installSha256'], isNotEmpty);

      // Verify the unpacked files exist on disk
      final pluginDir = Directory(
        '${tempDir.path}/extensions/plugin/dev.justin.catalogue',
      );
      expect(pluginDir.existsSync(), isTrue);
      expect(File('${pluginDir.path}/plugin.json').existsSync(), isTrue);
      expect(File('${pluginDir.path}/plugin.js').existsSync(), isTrue);
    });

    test('ActiveProvider auto-selects dev.justin.catalogue on initial launch when none saved', () async {
      SharedPreferences.setMockInitialValues({});
      final hiveDir = Directory.systemTemp.createTempSync('hive_storage_');
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      binding.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => hiveDir.path,
      );

      final storage = StorageService();
      await storage.init();

      final fakeCatalogue = _FakeCatalogueProvider();

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          extensionManagerProvider.overrideWith(
            () => _FakeManagerWithCatalogue([fakeCatalogue]),
          ),
        ],
      );

      addTearDown(() async {
        container.dispose();
        await Hive.close();
        if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
      });

      // Force ActiveProvider resolution
      final active = container.read(activeProviderProvider);
      expect(active, isNotNull);
      expect(active?.packageName, 'dev.justin.catalogue');
      expect(active?.name, "Justin's Catalogue");

      // Verify providerResolutionLoadingProvider is cleared to false
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(providerResolutionLoadingProvider), isFalse);

      // Verify Home contents return non-empty
      final homeData = await active!.getHome();
      expect(homeData, isNotEmpty);
      expect(homeData.containsKey('Popular Movies'), isTrue);
      expect(homeData.containsKey('Popular Series'), isTrue);

      // Verify Search returns items
      final searchResults = await active.search('Dune');
      expect(searchResults, isNotEmpty);
      expect(searchResults.first.title, 'Dune');

      // Verify Streams load with valid playback URLs & headers
      final streams = await active.loadStreams('https://v3-cinemeta.strem.io/meta/movie/tt15239678.json');
      expect(streams, isNotEmpty);
      expect(streams.first.url, contains('m3u8'));
      expect(streams.first.headers, containsPair('Referer', 'https://vixsrc.to/'));
    });

    test('PluginStorageService auto-updates outdated cached dev.justin.catalogue', () async {
      final tempDir = Directory.systemTemp.createTempSync('plugin_update_test_');
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      binding.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => tempDir.path,
      );

      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      // Pre-seed an older version (v1) with a dummy hash
      final catalogueDir = Directory('${tempDir.path}/extensions/plugin/dev.justin.catalogue');
      catalogueDir.createSync(recursive: true);
      File('${catalogueDir.path}/meta.json').writeAsStringSync(jsonEncode({
        'id': 'dev.justin.catalogue',
        'packageName': 'dev.justin.catalogue',
        'name': "Justin's Catalogue",
        'version': 1,
        'installSha256': 'outdated_dummy_sha',
        'repositoryId': 'Local',
      }));
      File('${catalogueDir.path}/plugin.js').writeAsStringSync('// Old script');
      File('${catalogueDir.path}/stale.qbc').writeAsStringSync('stale bytecode');

      final storageService = PluginStorageService();
      final installed = await storageService.listInstalledPlugins();

      final catalogue = installed.firstWhere((p) => p.packageName == 'dev.justin.catalogue');
      expect(catalogue.version, greaterThanOrEqualTo(14));
      expect(catalogue.manifest['installSha256'], isNot('outdated_dummy_sha'));
      expect(File('${catalogueDir.path}/stale.qbc').existsSync(), isFalse);
    });
  });
}

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../domain/entity/multimedia_item.dart';
import '../logger/app_logger.dart';

// Native function typedefs
typedef _VersionNative = ffi.Pointer<Utf8> Function();
typedef _VersionDart = ffi.Pointer<Utf8> Function();

typedef _FuzzySearchNative = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> query,
  ffi.Pointer<Utf8> itemsJson,
  ffi.Int32 minScore,
);
typedef _FuzzySearchDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> query,
  ffi.Pointer<Utf8> itemsJson,
  int minScore,
);

typedef _FilterSortNative = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> itemsJson,
  ffi.Pointer<Utf8> filterJson,
);
typedef _FilterSortDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> itemsJson,
  ffi.Pointer<Utf8> filterJson,
);

typedef _CryptoSha256Native = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> input,
);
typedef _CryptoSha256Dart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> input,
);

typedef _ProviderRegisterNative = ffi.Bool Function(
  ffi.Pointer<Utf8> manifestJson,
);
typedef _ProviderRegisterDart = bool Function(
  ffi.Pointer<Utf8> manifestJson,
);

typedef _ResolveStreamsNative = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> reqJson,
);
typedef _ResolveStreamsDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> reqJson,
);

typedef _StringFreeNative = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef _StringFreeDart = void Function(ffi.Pointer<Utf8> ptr);

/// High-throughput Native FFI Bridge to `aether-core` (Rust).
///
/// Bypasses Dart Isolates and GC thrashing by executing fuzzy search,
/// discovery sorting, and native extension stream resolution directly
/// on hardware threads using SIMD and AES-NI acceleration.
class AetherCoreFfi {
  static final AetherCoreFfi instance = AetherCoreFfi._internal();

  ffi.DynamicLibrary? _dylib;
  _VersionDart? _versionFn;
  _FuzzySearchDart? _fuzzySearchFn;
  _FilterSortDart? _filterSortFn;
  _CryptoSha256Dart? _cryptoSha256Fn;
  _ProviderRegisterDart? _providerRegisterFn;
  _ResolveStreamsDart? _resolveStreamsFn;
  _StringFreeDart? _stringFreeFn;

  bool _initialized = false;
  bool get isAvailable => _dylib != null && _initialized;

  AetherCoreFfi._internal();

  /// Initializes the native dynamic library.
  void initialize() {
    if (_initialized) return;

    try {
      _dylib = _loadLibrary();
      if (_dylib != null) {
        _versionFn = _dylib!
            .lookupFunction<_VersionNative, _VersionDart>('aether_core_version');
        _fuzzySearchFn = _dylib!.lookupFunction<_FuzzySearchNative,
            _FuzzySearchDart>('aether_fuzzy_search');
        _filterSortFn = _dylib!.lookupFunction<_FilterSortNative,
            _FilterSortDart>('aether_filter_and_sort');
        _cryptoSha256Fn = _dylib!.lookupFunction<_CryptoSha256Native,
            _CryptoSha256Dart>('aether_crypto_sha256');
        _providerRegisterFn = _dylib!.lookupFunction<_ProviderRegisterNative,
            _ProviderRegisterDart>('aether_provider_register');
        _resolveStreamsFn = _dylib!.lookupFunction<_ResolveStreamsNative,
            _ResolveStreamsDart>('aether_provider_resolve_streams');
        _stringFreeFn = _dylib!.lookupFunction<_StringFreeNative,
            _StringFreeDart>('aether_string_free');

        final verPtr = _versionFn!();
        final version = verPtr.toDartString();
        _stringFreeFn!(verPtr);

        _initialized = true;
        talker.info('AetherCoreFfi: Native Rust engine active (v$version)');
      }
    } catch (e) {
      talker.warning('AetherCoreFfi: Running in pure Dart fallback mode: $e');
      _dylib = null;
      _initialized = false;
    }
  }

  ffi.DynamicLibrary? _loadLibrary() {
    if (Platform.isWindows) {
      // Look in local build directory first, then process directory
      final candidatePaths = [
        'native/aether_core/target/release/aether_core.dll',
        'aether_core.dll',
        '../native/aether_core/target/release/aether_core.dll',
      ];
      for (final path in candidatePaths) {
        if (File(path).existsSync()) {
          return ffi.DynamicLibrary.open(path);
        }
      }
      return ffi.DynamicLibrary.open('aether_core.dll');
    } else if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('libaether_core.so');
    } else if (Platform.isMacOS || Platform.isIOS) {
      return ffi.DynamicLibrary.process();
    }
    return null;
  }

  /// Parallel native fuzzy search across [items].
  /// Returns a map of item ID to match score.
  Map<String, int>? fuzzySearch(String query, List<MultimediaItem> items,
      {int minScore = 50}) {
    if (!isAvailable || _fuzzySearchFn == null || _stringFreeFn == null) {
      return null;
    }

    try {
      final queryPtr = query.toNativeUtf8();
      final itemsMapList = items
          .map((i) => {
                'id': i.id.toString(),
                'title': i.title,
                'description': i.description,
                'poster_path': i.posterUrl,
                'backdrop_path': i.bannerUrl,
                'release_date': i.releaseDate,
                'vote_average': i.voteAverage,
                'vote_count': 0,
                'media_type': i.contentType.name,
                'genres': i.tags ?? [],
              })
          .toList();

      final itemsJson = jsonEncode(itemsMapList);
      final itemsPtr = itemsJson.toNativeUtf8();

      final resultPtr = _fuzzySearchFn!(queryPtr, itemsPtr, minScore);
      final resultStr = resultPtr.toDartString();

      _stringFreeFn!(resultPtr);
      malloc.free(queryPtr);
      malloc.free(itemsPtr);

      final decoded = jsonDecode(resultStr) as List<dynamic>;
      final scoreMap = <String, int>{};
      for (final match in decoded) {
        if (match is Map<String, dynamic> &&
            match['item'] is Map<String, dynamic>) {
          final itemId = match['item']['id']?.toString();
          final score = match['score'] as int? ?? 0;
          if (itemId != null) {
            scoreMap[itemId] = score;
          }
        }
      }
      return scoreMap;
    } catch (_) {
      return null;
    }
  }

  /// Hardware-accelerated SHA-256 calculation.
  String? sha256(String input) {
    if (!isAvailable || _cryptoSha256Fn == null || _stringFreeFn == null) {
      return null;
    }
    try {
      final inputPtr = input.toNativeUtf8();
      final resultPtr = _cryptoSha256Fn!(inputPtr);
      final hash = resultPtr.toDartString();
      _stringFreeFn!(resultPtr);
      malloc.free(inputPtr);
      return hash;
    } catch (_) {
      return null;
    }
  }

  /// Registers an Aether Native Extension (ANE) manifest with the core engine.
  bool registerProvider(Map<String, dynamic> manifest) {
    if (!isAvailable || _providerRegisterFn == null) return false;
    try {
      final jsonStr = jsonEncode(manifest);
      final jsonPtr = jsonStr.toNativeUtf8();
      final success = _providerRegisterFn!(jsonPtr);
      malloc.free(jsonPtr);
      return success;
    } catch (_) {
      return false;
    }
  }

  /// High-speed native stream resolution with AES-NI decryption and SIMD parsing.
  List<StreamResult> resolveStreams({
    required String title,
    required String mediaType,
    int? season,
    int? episode,
    int? year,
    String? imdbId,
    int? tmdbId,
  }) {
    if (!isAvailable || _resolveStreamsFn == null || _stringFreeFn == null) {
      return const [];
    }
    try {
      final reqMap = {
        'title': title,
        'media_type': mediaType,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (year != null) 'year': year,
        if (imdbId != null) 'imdb_id': imdbId,
        if (tmdbId != null) 'tmdb_id': tmdbId,
      };
      final reqJson = jsonEncode(reqMap);
      final reqPtr = reqJson.toNativeUtf8();
      final resultPtr = _resolveStreamsFn!(reqPtr);
      final resultStr = resultPtr.toDartString();

      _stringFreeFn!(resultPtr);
      malloc.free(reqPtr);

      final list = jsonDecode(resultStr) as List<dynamic>;
      final streams = <StreamResult>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final url = item['url'] as String? ?? '';
          if (url.isNotEmpty) {
            streams.add(StreamResult(
              url: url,
              source: (item['quality'] as String?) ?? '1080p',
              providerName:
                  (item['provider_name'] as String?) ?? 'Aether Direct',
              headers: item['headers'] != null
                  ? Map<String, String>.from(item['headers'] as Map)
                  : null,
              subtitles: item['subtitles'] != null
                  ? (item['subtitles'] as List)
                      .map((s) => SubtitleFile(
                            url: s['url'] as String? ?? '',
                            label: s['language'] as String? ?? 'English',
                            lang: s['language'] as String?,
                          ))
                      .toList()
                  : null,
            ));
          }
        }
      }
      return streams;
    } catch (e) {
      talker.warning('AetherCoreFfi: Stream resolution error: $e');
      return const [];
    }
  }
}

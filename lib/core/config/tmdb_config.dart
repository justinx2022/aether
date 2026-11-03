import '../providers/device_info_provider.dart';

/// Compile-time TMDB constants and device-class-aware image-size resolution.
///
/// `_profile` is a set-once global because TMDB URLs are produced by pure
/// utility functions ([AppImageFallbacks]) and by model constructors
/// ([TmdbDetails], [MultimediaItem.fromTmdb]) that have no Riverpod `Ref`, and
/// device class does not change at runtime.
///
/// Its default corresponds to a phone, so anything that runs before
/// [setProfile] — the first frame on cold start — gets mobile-sized URLs.
class TmdbConfig {
  /// TMDB API key baked in at build time, passed with
  /// `flutter run --dart-define=TMDB_API_KEY=...`.
  ///
  /// Only the fallback for when the user has not configured a key.
  static const String buildTimeApiKey = String.fromEnvironment('TMDB_API_KEY');

  /// User-supplied key from Settings, mirrored here from storage at boot by [setUserApiKey].
  static String _userApiKey = '';

  /// User-supplied key from Nuvio plugins screen, mirrored here by [setNuvioApiKey].
  static String _nuvioApiKey = '';

  /// The effective TMDB key: Settings first, then Nuvio plugins, then the
  /// build-time developer key.
  static String get apiKey {
    if (_userApiKey.isNotEmpty) {
      return _userApiKey;
    } else if (_nuvioApiKey.isNotEmpty) {
      return _nuvioApiKey;
    } else {
      return buildTimeApiKey;
    }
  }

  /// True when the key came from the user (Settings or Nuvio plugins) rather than the build.
  static bool get usingUserApiKey =>
      _userApiKey.isNotEmpty || _nuvioApiKey.isNotEmpty;

  /// Called at boot and whenever the user saves a new key in Settings.
  static void setUserApiKey(String? key) {
    _userApiKey = key?.trim() ?? '';
  }

  /// Called at boot and whenever the user saves a new key in Nuvio plugins screen.
  static void setNuvioApiKey(String? key) {
    _nuvioApiKey = key?.trim() ?? '';
  }

  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageRoot = 'https://image.tmdb.org/t/p';

  static DeviceProfile _profile = const DeviceProfile();
  static DeviceProfile get profile => _profile;

  /// Called from `_MyAppState`'s `ref.listen(deviceProfileProvider, …)`.
  /// Idempotent; safe to call repeatedly.
  static void setProfile(DeviceProfile profile) {
    _profile = profile;
  }

  /// Deliver true uncompressed 4K UHD backdrops (`original`, 3840x2160) across all devices.
  static String get backdropSizeUrl => '$_imageRoot/original';

  /// High-definition poster renders (`w780`) across all devices for pin-sharp display.
  static String get posterSizeUrl => '$_imageRoot/w780';

  /// High-resolution cast head-shots and thumbnails.
  static String get profileSizeUrl => '$_imageRoot/h632';

  /// Generic fallback for logos, stills and anything without its own size.
  static String get imageBaseUrl => posterSizeUrl;
}

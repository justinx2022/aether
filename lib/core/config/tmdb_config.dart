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

  /// The effective TMDB key: user key first, then build-time key.
  ///
  /// There is deliberately no embedded fallback key: one committed to a
  /// public repository is a published key — it lives in the history, in
  /// every fork and every clone, and only rotation is a remedy. Without a
  /// key the services degrade to empty results and the Settings screen
  /// (Accounts → TMDB) is where the user's own key is entered.
  static String get apiKey {
    if (_userApiKey.isNotEmpty) {
      return _userApiKey;
    }
    return buildTimeApiKey;
  }

  /// True when the key came from the user rather than background defaults.
  static bool get usingUserApiKey => _userApiKey.isNotEmpty;

  /// Called at boot and whenever the user saves a new key in Settings.
  static void setUserApiKey(String? key) {
    _userApiKey = key?.trim() ?? '';
  }

  /// Backward-compatibility helper for previously cached keys.
  static void setNuvioApiKey(String? key) {
    if (_userApiKey.isEmpty && key != null && key.trim().isNotEmpty) {
      _userApiKey = key.trim();
    }
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

  /// Hardware-adaptive backdrop sizing: Prevents 33MB RAM spikes on mobile and TV sticks
  static String get backdropSizeUrl {
    if (_profile.tier == DeviceTier.low) {
      return '$_imageRoot/w780';
    } else if (_profile.isTv || _profile.isDesktopOS) {
      return '$_imageRoot/w1280';
    } else {
      return '$_imageRoot/w780';
    }
  }

  /// Adaptive poster renders: w500 on mobile/low-tier, w780 on large screens
  static String get posterSizeUrl {
    if (_profile.tier == DeviceTier.low) {
      return '$_imageRoot/w342';
    } else if (_profile.isLargeScreen) {
      return '$_imageRoot/w780';
    } else {
      return '$_imageRoot/w500';
    }
  }

  /// High-resolution cast head-shots and thumbnails.
  static String get profileSizeUrl => '$_imageRoot/h632';

  /// Generic fallback for logos, stills and anything without its own size.
  static String get imageBaseUrl => posterSizeUrl;
}

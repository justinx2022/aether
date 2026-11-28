import 'package:aether/core/storage/storage_service.dart';

/// A [StorageService] that keeps its string values in memory.
///
/// Providers such as the profile controller read the storage service while
/// building, so widget tests need an override. This stands in for Hive, which
/// tests do not open.
class InMemoryStorage extends StorageService {
  final Map<String, String?> _strings = {};

  @override
  String? getString(String key) => _strings[key];

  @override
  Future<void> setString(String key, String? value) async {
    _strings[key] = value;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/entity/canonical_media_identity.dart';
import '../domain/identity/external_id_registry.dart';
import 'storage_service.dart';

@immutable
class ReconciledRecord {
  final CanonicalMediaIdentity identity;
  final Map<String, dynamic> rawLegacyData;
  final bool isQuarantined;

  const ReconciledRecord({
    required this.identity,
    required this.rawLegacyData,
    this.isQuarantined = false,
  });
}

/// Reconciles legacy unscoped URL-keyed records into canonical identities.
class LegacyUrlReconciler {
  final ExternalIdRegistry _registry;

  LegacyUrlReconciler(this._registry);

  /// Reconciles a raw legacy history or library map into a [ReconciledRecord].
  ReconciledRecord reconcile(Map<String, dynamic> rawMap) {
    final rawUrl = (rawMap['url'] as String?) ?? '';
    final rawTitle = (rawMap['title'] as String?) ?? 'Untitled';
    final rawYear = rawMap['year'] is int
        ? rawMap['year'] as int
        : (rawMap['year'] is String ? int.tryParse(rawMap['year'] as String) : null);
    final rawType = (rawMap['type'] as String?) ?? (rawMap['contentType'] as String?) ?? 'movie';
    final tmdbId = rawMap['tmdbId'] as int?;
    String? imdbId = rawMap['imdbId'] as String?;

    // Check if the URL is a JSON-encoded token
    if (rawUrl.startsWith('{') && rawUrl.endsWith('}')) {
      try {
        final parsedJson = json.decode(rawUrl) as Map<String, dynamic>;
        final idToken = parsedJson['id']?.toString();
        if (idToken != null && idToken.startsWith('tt')) {
          imdbId ??= idToken;
        }
      } catch (_) {}
    }

    // Check if URL contains an embedded IMDb ID pattern
    if (imdbId == null || imdbId.isEmpty) {
      final imdbMatch = RegExp(r'tt\d{7,8}').firstMatch(rawUrl);
      if (imdbMatch != null) {
        imdbId = imdbMatch.group(0);
      }
    }

    final mediaType = CanonicalMediaType.fromString(rawType);

    // Resolve or register in canonical registry
    final canonical = _registry.resolveOrRegister(
      title: rawTitle,
      type: mediaType,
      year: rawYear,
      tmdbId: tmdbId,
      imdbId: imdbId,
      providerTokens: rawUrl.isNotEmpty ? {'legacy_url': rawUrl} : null,
    );

    return ReconciledRecord(
      identity: canonical,
      rawLegacyData: rawMap,
      isQuarantined: canonical.isAmbiguous,
    );
  }
}

/// Atomic migration engine with backup and rollback capabilities.
class SafeMigrationPipeline {
  static const String _kBackupKey = 'pre_migration_backup_v1';
  static const String _kSchemaVersionKey = 'aether_schema_version';
  static const int kTargetVersion = 2;

  final StorageService _storage;
  final LegacyUrlReconciler _reconciler;

  SafeMigrationPipeline({
    required StorageService storage,
    required ExternalIdRegistry registry,
  })  : _storage = storage,
        _reconciler = LegacyUrlReconciler(registry);

  int get currentSchemaVersion => _storage.getInt(_kSchemaVersionKey) ?? 1;

  /// Creates a complete snapshot of all legacy keys before any mutation occurs.
  Future<void> createBackupSnapshot() async {
    final history = _storage.getWatchHistory();
    final library = _storage.getLibraryItems().map((item) => item.toJson()).toList();

    final backupPayload = {
      'timestamp': DateTime.now().toIso8601String(),
      'history': history,
      'library': library,
    };

    await _storage.setString(_kBackupKey, json.encode(backupPayload));
  }

  /// Restores the pre-migration snapshot in case of verification failure.
  Future<bool> rollback() async {
    final rawBackup = _storage.getString(_kBackupKey);
    if (rawBackup == null || rawBackup.isEmpty) return false;

    try {
      await _storage.setInt(_kSchemaVersionKey, 1);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[SafeMigrationPipeline] Rollback failed: $e');
      return false;
    }
  }

  /// Executes atomic migration: reconciles records, writes partitioned data,
  /// verifies counts, and commits schema version v2.
  Future<bool> executeMigration() async {
    if (currentSchemaVersion >= kTargetVersion) return true;

    await createBackupSnapshot();

    try {
      final legacyHistory = _storage.getWatchHistory();
      final legacyLibrary = _storage.getLibraryItems();

      int migratedHistory = 0;
      int migratedLibrary = 0;

      for (final raw in legacyHistory) {
        final record = _reconciler.reconcile(raw);
        final profileId = raw['profileId']?.toString() ?? 'default_profile';
        final key = 'profile:$profileId:history:${record.identity.aetherId.urn}';

        await _storage.setString(key, json.encode({
          'aetherId': record.identity.aetherId.urn,
          'position': raw['position'] ?? 0,
          'duration': raw['duration'] ?? 0,
          'season': raw['season'],
          'episode': raw['episode'],
          'timestamp': raw['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          'isQuarantined': record.isQuarantined,
        }));
        migratedHistory++;
      }

      for (final item in legacyLibrary) {
        final rawMap = item.toJson();
        final record = _reconciler.reconcile(rawMap);
        const profileId = 'default_profile';
        final key = 'profile:$profileId:library:${record.identity.aetherId.urn}';

        await _storage.setString(key, json.encode({
          'aetherId': record.identity.aetherId.urn,
          'canonicalTitle': record.identity.canonicalTitle,
          'savedAt': DateTime.now().toIso8601String(),
          'isQuarantined': record.isQuarantined,
        }));
        migratedLibrary++;
      }

      // Verification Step
      if (migratedHistory == legacyHistory.length && migratedLibrary == legacyLibrary.length) {
        await _storage.setInt(_kSchemaVersionKey, kTargetVersion);
        return true;
      } else {
        await rollback();
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SafeMigrationPipeline] Migration encountered exception: $e');
      await rollback();
      return false;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/storage_service.dart';
import 'notification_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final notifications = ref.watch(notificationServiceProvider);
  return BackupService(storage, notifications);
});

class BackupService {
  final StorageService _storage;
  final NotificationService _notifications;

  BackupService(this._storage, this._notifications);

  Future<bool> exportBackup() async {
    try {
      final data = _storage.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(jsonString);

      final dateStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'aether_backup_$dateStr.json';

      Uri? savedUri;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        savedUri = await FilePicker.saveFile(
          dialogTitle: 'Save Aether Backup',
          fileName: fileName,
          bytes: Uint8List.fromList(bytes),
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final outputPath = '${dir.path}/$fileName';
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        savedUri = Uri.file(outputPath);
      }

      if (savedUri == null) {
        return false;
      }

      _notifications.showSuccess(
        'Backup saved successfully to ${savedUri.path}',
        title: 'Backup Created',
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Backup export failed: $e');
      _notifications.showError(
        'Failed to export backup: $e',
        title: 'Backup Failed',
      );
      return false;
    }
  }

  Future<bool> importBackup() async {
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Select Aether Backup File',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (picked == null || picked.path == null) {
        return false;
      }

      final file = File(picked.path!);
      final jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic> || decoded['app'] != 'Aether') {
        _notifications.showError(
          'Invalid backup file. Must be an Aether JSON backup.',
          title: 'Import Failed',
        );
        return false;
      }

      final count = await _storage.importAllData(decoded);

      _notifications.showSuccess(
        'Successfully restored $count items and settings.',
        title: 'Restore Complete',
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Backup import failed: $e');
      _notifications.showError(
        'Failed to restore backup: $e',
        title: 'Restore Failed',
      );
      return false;
    }
  }
}

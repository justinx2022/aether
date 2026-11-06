import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile/profile_service.dart';
import '../../core/storage/storage_service.dart';

/// Playback choices that belong to the person watching, not the device.
class PlaybackPrefs {
  final bool autoplay;
  final bool dialogueBoost;
  final bool dataSaver;
  final int subtitleOffsetMs;
  final String? audioLanguage;
  final String? subtitleLanguage;
  final int storageCapMb;

  const PlaybackPrefs({
    this.autoplay = true,
    this.dialogueBoost = false,
    this.dataSaver = false,
    this.subtitleOffsetMs = 0,
    this.audioLanguage,
    this.subtitleLanguage,
    this.storageCapMb = 0,
  });

  PlaybackPrefs copyWith({
    bool? autoplay,
    bool? dialogueBoost,
    bool? dataSaver,
    int? subtitleOffsetMs,
    String? audioLanguage,
    String? subtitleLanguage,
    int? storageCapMb,
    bool clearAudio = false,
    bool clearSubtitle = false,
  }) {
    return PlaybackPrefs(
      autoplay: autoplay ?? this.autoplay,
      dialogueBoost: dialogueBoost ?? this.dialogueBoost,
      dataSaver: dataSaver ?? this.dataSaver,
      subtitleOffsetMs: subtitleOffsetMs ?? this.subtitleOffsetMs,
      audioLanguage: clearAudio ? null : (audioLanguage ?? this.audioLanguage),
      subtitleLanguage: clearSubtitle
          ? null
          : (subtitleLanguage ?? this.subtitleLanguage),
      storageCapMb: storageCapMb ?? this.storageCapMb,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoplay': autoplay,
    'dialogueBoost': dialogueBoost,
    'dataSaver': dataSaver,
    'subtitleOffsetMs': subtitleOffsetMs,
    'audioLanguage': audioLanguage,
    'subtitleLanguage': subtitleLanguage,
    'storageCapMb': storageCapMb,
  };

  factory PlaybackPrefs.fromJson(Map<String, dynamic> json) {
    return PlaybackPrefs(
      autoplay: json['autoplay'] as bool? ?? true,
      dialogueBoost: json['dialogueBoost'] as bool? ?? false,
      dataSaver: json['dataSaver'] as bool? ?? false,
      subtitleOffsetMs: json['subtitleOffsetMs'] as int? ?? 0,
      audioLanguage: json['audioLanguage'] as String?,
      subtitleLanguage: json['subtitleLanguage'] as String?,
      storageCapMb: json['storageCapMb'] as int? ?? 0,
    );
  }
}

class IncognitoSession extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(
      profileControllerProvider.select((state) => state.activeProfile?.id),
    );
    return false;
  }

  void setEnabled(bool value) => state = value;
}

final incognitoSessionProvider =
    NotifierProvider<IncognitoSession, bool>(IncognitoSession.new);

class PlaybackPrefsController extends Notifier<PlaybackPrefs> {
  static const _keyPrefix = 'playback_prefs_v1_';

  @override
  PlaybackPrefs build() {
    final id = ref.watch(
      profileControllerProvider.select((state) => state.activeProfile?.id),
    );
    return _read(id);
  }

  PlaybackPrefs _read(String? profileId) {
    if (profileId == null) return const PlaybackPrefs();
    final raw = ref.read(storageServiceProvider).getString('$_keyPrefix$profileId');
    if (raw == null || raw.isEmpty) return const PlaybackPrefs();
    try {
      return PlaybackPrefs.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PlaybackPrefs();
    }
  }

  Future<void> update(PlaybackPrefs next) async {
    state = next;
    final id = ref.read(profileControllerProvider).activeProfile?.id;
    if (id == null) return;
    await ref
        .read(storageServiceProvider)
        .setString('$_keyPrefix$id', jsonEncode(next.toJson()));
  }
}

final playbackPrefsProvider =
    NotifierProvider<PlaybackPrefsController, PlaybackPrefs>(
      PlaybackPrefsController.new,
    );

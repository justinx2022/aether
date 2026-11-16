import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../storage/storage_service.dart';
import 'user_profile.dart';

class ProfileState {
  final List<UserProfile> profiles;
  final UserProfile? activeProfile;
  final bool isLoading;

  const ProfileState({
    this.profiles = const [],
    this.activeProfile,
    this.isLoading = false,
  });

  ProfileState copyWith({
    List<UserProfile>? profiles,
    UserProfile? activeProfile,
    bool? isLoading,
  }) {
    return ProfileState(
      profiles: profiles ?? this.profiles,
      activeProfile: activeProfile ?? this.activeProfile,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileController extends Notifier<ProfileState> {
  static const String _kProfilesListKey = 'user_profiles_list_v1';
  static const String _kActiveProfileIdKey = 'active_user_profile_id_v1';

  @override
  ProfileState build() {
    return _computeInitialProfiles();
  }

  StorageService get _storage => ref.read(storageServiceProvider);

  ProfileState _computeInitialProfiles() {
    final raw = _storage.getString(_kProfilesListKey);
    List<UserProfile> loaded = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List<dynamic>;
        loaded = decoded
            .map((item) => UserProfile.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (kDebugMode) debugPrint('[ProfileController] Failed to parse profiles: $e');
      }
    }

    if (loaded.isEmpty) {
      return const ProfileState(
        profiles: [],
        activeProfile: null,
        isLoading: false,
      );
    }

    final activeId = _storage.getString(_kActiveProfileIdKey) ?? loaded.first.id;
    final active = loaded.firstWhere(
      (p) => p.id == activeId,
      orElse: () => loaded.first,
    );

    return ProfileState(
      profiles: loaded,
      activeProfile: active,
      isLoading: false,
    );
  }

  Future<void> _saveProfiles(List<UserProfile> list) async {
    final jsonStr = json.encode(list.map((p) => p.toMap()).toList());
    await _storage.setString(_kProfilesListKey, jsonStr);
  }

  Future<void> selectProfile(UserProfile profile) async {
    await _storage.setString(_kActiveProfileIdKey, profile.id);
    state = state.copyWith(activeProfile: profile);
  }

  Future<UserProfile> addProfile({
    required String name,
    required String avatarId,
    String? pin,
    bool isKids = false,
    List<String> preferredGenres = const [],
    String feedMode = 'all',
  }) async {
    String? pinHash;
    String? pinSalt;
    if (pin != null && pin.trim().isNotEmpty) {
      pinSalt = UserProfile.generateSalt();
      pinHash = UserProfile.hashPinPbkdf2(pin.trim(), pinSalt);
    }

    final newProfile = UserProfile(
      id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Viewer' : name.trim(),
      avatarId: avatarId,
      pinHash: pinHash,
      pinSalt: pinSalt,
      isKids: isKids,
      preferredGenres: preferredGenres,
      feedMode: feedMode,
      createdAt: DateTime.now(),
    );

    if (pinHash != null) {
      try {
        const secure = FlutterSecureStorage(aOptions: AndroidOptions());
        await secure.write(key: 'profile_pin_${newProfile.id}', value: pinHash);
      } catch (_) {}
    }

    final updated = [...state.profiles, newProfile];
    await _saveProfiles(updated);

    UserProfile nextActive = state.activeProfile ?? newProfile;
    if (state.activeProfile == null) {
      await _storage.setString(_kActiveProfileIdKey, newProfile.id);
    }

    state = state.copyWith(
      profiles: updated,
      activeProfile: nextActive,
    );
    return newProfile;
  }

  Future<void> updateProfile(UserProfile profile) async {
    UserProfile toSave = profile;
    if (toSave.pin != null && toSave.pin!.isNotEmpty && toSave.pinHash == null) {
      final salt = UserProfile.generateSalt();
      final hash = UserProfile.hashPinPbkdf2(toSave.pin!, salt);
      toSave = toSave.copyWith(
        pin: null,
        pinSalt: salt,
        pinHash: hash,
      );
      try {
        const secure = FlutterSecureStorage(aOptions: AndroidOptions());
        await secure.write(key: 'profile_pin_${toSave.id}', value: hash);
      } catch (_) {}
    }

    final updated = state.profiles.map((p) => p.id == toSave.id ? toSave : p).toList();
    await _saveProfiles(updated);

    final currentActive = state.activeProfile;
    final newActive = currentActive?.id == toSave.id ? toSave : currentActive;

    state = state.copyWith(
      profiles: updated,
      activeProfile: newActive,
    );
  }

  Future<void> deleteProfile(String profileId) async {
    if (state.profiles.length <= 1) return;

    final updated = state.profiles.where((p) => p.id != profileId).toList();
    await _saveProfiles(updated);

    UserProfile nextActive = state.activeProfile ?? updated.first;
    if (state.activeProfile?.id == profileId) {
      nextActive = updated.first;
      await _storage.setString(_kActiveProfileIdKey, nextActive.id);
    }

    state = state.copyWith(
      profiles: updated,
      activeProfile: nextActive,
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/storage_service.dart';
import 'pin_hash.dart';
import 'user_profile.dart';

/// The two profiles a fresh install used to write for you.
///
/// Left in place only so an install that never edited them can be cleared
/// and sent through setup. A renamed or otherwise changed profile is kept.
bool _isUntouchedDemoSeed(List<UserProfile> profiles) {
  if (profiles.length != 2) return false;
  final byId = {for (final profile in profiles) profile.id: profile};
  final justin = byId['profile_default'];
  final roommate = byId['profile_roomie'];
  if (justin == null || roommate == null) return false;
  return _isUntouched(justin, 'Justin', 'avatar_cinema') &&
      _isUntouched(roommate, 'Roommate', 'avatar_popcorn');
}

bool _isUntouched(UserProfile profile, String name, String avatarId) {
  return profile.name == name &&
      profile.avatarId == avatarId &&
      (profile.pin == null || profile.pin!.isEmpty) &&
      !profile.isKids &&
      profile.preferredGenres.isEmpty &&
      profile.feedMode == 'all';
}

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

    if (_isUntouchedDemoSeed(loaded)) {
      loaded = [];
      _storage.setString(_kProfilesListKey, null);
      _storage.setString(_kActiveProfileIdKey, null);
    }

    if (loaded.isEmpty) {
      return const ProfileState();
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
    final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    final newProfile = UserProfile(
      id: id,
      name: name.trim().isEmpty ? 'Comrade' : name.trim(),
      avatarId: avatarId,
      pin: _storedPin(pin, id),
      isKids: isKids,
      preferredGenres: preferredGenres,
      feedMode: feedMode,
      createdAt: DateTime.now(),
    );

    final updated = [...state.profiles, newProfile];
    await _saveProfiles(updated);
    state = state.copyWith(profiles: updated);
    return newProfile;
  }

  Future<void> updateProfile(UserProfile profile) async {
    final stored = profile.copyWith(pin: _storedPin(profile.pin, profile.id));
    final updated = state.profiles
        .map((p) => p.id == profile.id ? stored : p)
        .toList();
    await _saveProfiles(updated);

    final currentActive = state.activeProfile;
    final newActive = currentActive?.id == profile.id ? stored : currentActive;

    state = state.copyWith(
      profiles: updated,
      activeProfile: newActive,
    );
  }

  String? _storedPin(String? pin, String profileId) {
    if (pin == null || pin.isEmpty) return null;
    if (pinIsHashed(pin)) return pin;
    return hashPin(pin, profileId);
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

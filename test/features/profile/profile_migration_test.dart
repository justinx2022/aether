import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:skystream/core/profile/profile_service.dart';
import 'package:skystream/core/profile/user_profile.dart';
import 'package:skystream/core/storage/storage_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late StorageService storage;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('profile_test_');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async {
    await Hive.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('Fresh installation seeds clean User and Guest profiles without dev names', () async {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileControllerProvider);
    expect(state.profiles.length, 2);
    expect(state.profiles[0].name, 'User');
    expect(state.profiles[1].name, 'Guest');
    expect(state.profiles.any((p) => p.name.contains('Justin')), isFalse);
    expect(state.profiles.any((p) => p.name.contains('Roommate')), isFalse);
  });

  test('Auto-migrates legacy Justin and Roommate saved in storage to User and Guest', () async {
    // Pre-populate storage with legacy hardcoded developer profiles
    final legacyProfiles = [
      UserProfile(
        id: 'profile_default',
        name: 'Justin',
        avatarId: 'avatar_cinema',
        createdAt: DateTime(2025),
      ),
      UserProfile(
        id: 'profile_roomie',
        name: 'Roommate',
        avatarId: 'avatar_popcorn',
        createdAt: DateTime(2025),
      ),
      UserProfile(
        id: 'profile_custom',
        name: 'Alex',
        avatarId: 'avatar_scifi',
        createdAt: DateTime(2025),
      ),
    ];

    final jsonStr = json.encode(legacyProfiles.map((p) => p.toMap()).toList());
    await storage.setString('user_profiles_list_v1', jsonStr);

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileControllerProvider);
    expect(state.profiles.length, 3);
    expect(state.profiles[0].name, 'User');
    expect(state.profiles[1].name, 'Guest');
    expect(state.profiles[2].name, 'Alex'); // preserved custom profile

    // Verify migrated profiles were written back to storage
    final updatedRaw = storage.getString('user_profiles_list_v1');
    expect(updatedRaw, isNotNull);
    expect(updatedRaw!.contains('Justin'), isFalse);
    expect(updatedRaw.contains('Roommate'), isFalse);
    expect(updatedRaw.contains('User'), isTrue);
    expect(updatedRaw.contains('Guest'), isTrue);
  });
}

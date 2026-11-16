import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// Represents a single viewer profile under the account with preferences.
class UserProfile {
  final String id;
  final String name;
  final String avatarId;
  final String? pin; // Legacy plaintext PIN (migrated on verification)
  final String? pinHash;
  final String? pinSalt;
  final bool isKids;
  final List<String> preferredGenres;
  final String feedMode; // 'all', 'movies', 'series', 'anime'
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    this.pin,
    this.pinHash,
    this.pinSalt,
    this.isKids = false,
    this.preferredGenres = const [],
    this.feedMode = 'all',
    required this.createdAt,
  });

  bool get hasPin =>
      (pin != null && pin!.isNotEmpty) ||
      (pinHash != null && pinHash!.isNotEmpty);

  /// Cryptographically verifies the supplied PIN using PBKDF2 (falling back to legacy salted SHA-256).
  bool verifyPin(String candidatePin) {
    if (!hasPin) return true;
    if (pinHash != null && pinSalt != null) {
      // 1. Check standard PBKDF2 (HMAC-SHA256, 10,000 iterations)
      final candidatePbkdf2 = hashPinPbkdf2(candidatePin, pinSalt!);
      if (candidatePbkdf2 == pinHash) return true;

      // 2. Fall back to legacy salted SHA-256
      final candidateSha256 = hashPinWithSalt(candidatePin, pinSalt!);
      if (candidateSha256 == pinHash) return true;
    }
    // Backward compatibility for legacy profiles with plaintext PIN
    return candidatePin == pin;
  }

  /// Cryptographic PBKDF2-HMAC-SHA256 key derivation with 10,000 iterations.
  static String hashPinPbkdf2(String rawPin, String salt, {int iterations = 10000}) {
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(rawPin);
    final hmac = Hmac(sha256, pinBytes);

    final initialBlock = Uint8List(saltBytes.length + 4);
    initialBlock.setRange(0, saltBytes.length, saltBytes);
    final byteData = ByteData.sublistView(initialBlock, saltBytes.length);
    byteData.setUint32(0, 1, Endian.big);

    var u = hmac.convert(initialBlock).bytes;
    final result = List<int>.from(u);

    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int k = 0; k < result.length; k++) {
        result[k] ^= u[k];
      }
    }
    return base64Url.encode(result);
  }

  static String hashPinWithSalt(String rawPin, String salt) {
    final bytes = utf8.encode('$salt:$rawPin');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarId,
    String? pin,
    String? pinHash,
    String? pinSalt,
    bool? isKids,
    List<String>? preferredGenres,
    String? feedMode,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      pin: pin ?? this.pin,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      isKids: isKids ?? this.isKids,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      feedMode: feedMode ?? this.feedMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarId': avatarId,
      'pin': pin,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'isKids': isKids,
      'preferredGenres': preferredGenres,
      'feedMode': feedMode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawGenres = map['preferredGenres'];
    final List<String> genres = rawGenres is List
        ? rawGenres.map((e) => e.toString()).toList()
        : const [];

    return UserProfile(
      id: map['id'] as String? ?? 'default_profile',
      name: map['name'] as String? ?? 'Comrade',
      avatarId: map['avatarId'] as String? ?? 'avatar_cinema',
      pin: map['pin'] as String?,
      pinHash: map['pinHash'] as String?,
      pinSalt: map['pinSalt'] as String?,
      isKids: map['isKids'] as bool? ?? false,
      preferredGenres: genres,
      feedMode: map['feedMode'] as String? ?? 'all',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Curated cinematic and natural profile avatars matching the dark cinema theme.
class ProfileAvatarInfo {
  final String id;
  final String label;
  final String subtitle;
  final String category;
  final IconData icon;
  final String? emblem;
  final List<Color> gradientColors;
  final Color glowColor;
  final bool isNatural;

  const ProfileAvatarInfo({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.category,
    required this.icon,
    this.emblem,
    required this.gradientColors,
    this.glowColor = const Color(0xFF6366F1),
    this.isNatural = false,
  });
}

class ProfileAvatars {
  static const List<String> categories = [
    'Cinema Icons',
    'Series Legends',
    'Natural Backdrops',
  ];

  static const List<ProfileAvatarInfo> all = [
    // ════════════════════════════════════════════════════════════
    // ── Cinema Icons (Live-Action Films) ──
    // ════════════════════════════════════════════════════════════
    ProfileAvatarInfo(
      id: 'avatar_baby_driver',
      label: 'Baby',
      subtitle: 'Baby Driver',
      category: 'Cinema Icons',
      icon: Icons.headphones_rounded,
      emblem: 'BD',
      gradientColors: [Color(0xFF334155), Color(0xFF0F172A)],
      glowColor: Color(0xFF94A3B8),
    ),
    ProfileAvatarInfo(
      id: 'avatar_blade_runner',
      label: 'Officer K',
      subtitle: 'Blade Runner 2049',
      category: 'Cinema Icons',
      icon: Icons.remove_red_eye_rounded,
      emblem: 'KD',
      gradientColors: [Color(0xFF0F766E), Color(0xFF042F2E)],
      glowColor: Color(0xFF14B8A6),
    ),
    ProfileAvatarInfo(
      id: 'avatar_drive',
      label: 'The Driver',
      subtitle: 'Drive',
      category: 'Cinema Icons',
      icon: Icons.sports_motorsports_rounded,
      emblem: '🦂',
      gradientColors: [Color(0xFFB45309), Color(0xFF1E1B4B)],
      glowColor: Color(0xFFF59E0B),
    ),
    ProfileAvatarInfo(
      id: 'avatar_paul_atreides',
      label: 'Paul Atreides',
      subtitle: 'Dune: Part Two',
      category: 'Cinema Icons',
      icon: Icons.terrain_rounded,
      emblem: 'μ',
      gradientColors: [Color(0xFF0284C7), Color(0xFF1C1917)],
      glowColor: Color(0xFF38BDF8),
    ),
    ProfileAvatarInfo(
      id: 'avatar_john_wick',
      label: 'John Wick',
      subtitle: 'Baba Yaga',
      category: 'Cinema Icons',
      icon: Icons.fiber_manual_record_rounded,
      emblem: 'JW',
      gradientColors: [Color(0xFF18181B), Color(0xFF000000)],
      glowColor: Color(0xFFE2E8F0),
    ),
    ProfileAvatarInfo(
      id: 'avatar_interstellar',
      label: 'Cooper',
      subtitle: 'Interstellar',
      category: 'Cinema Icons',
      icon: Icons.rocket_launch_rounded,
      emblem: 'NASA',
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
      glowColor: Color(0xFF60A5FA),
    ),
    ProfileAvatarInfo(
      id: 'avatar_tyler_durden',
      label: 'Tyler Durden',
      subtitle: 'Fight Club',
      category: 'Cinema Icons',
      icon: Icons.soap_rounded,
      emblem: 'FC',
      gradientColors: [Color(0xFFB91C1C), Color(0xFF450A0A)],
      glowColor: Color(0xFFEF4444),
    ),
    ProfileAvatarInfo(
      id: 'avatar_bateman',
      label: 'Patrick Bateman',
      subtitle: 'American Psycho',
      category: 'Cinema Icons',
      icon: Icons.business_center_rounded,
      emblem: 'PB',
      gradientColors: [Color(0xFF7F1D1D), Color(0xFF0F172A)],
      glowColor: Color(0xFFF87171),
    ),

    // ════════════════════════════════════════════════════════════
    // ── Series Legends (Prestigious Television) ──
    // ════════════════════════════════════════════════════════════
    ProfileAvatarInfo(
      id: 'avatar_expanse',
      label: 'James Holden',
      subtitle: 'The Expanse',
      category: 'Series Legends',
      icon: Icons.satellite_alt_rounded,
      emblem: 'Roci',
      gradientColors: [Color(0xFF0369A1), Color(0xFF082F49)],
      glowColor: Color(0xFF0EA5E9),
    ),
    ProfileAvatarInfo(
      id: 'avatar_heisenberg',
      label: 'Heisenberg',
      subtitle: 'Breaking Bad',
      category: 'Series Legends',
      icon: Icons.science_rounded,
      emblem: 'Br',
      gradientColors: [Color(0xFF0F766E), Color(0xFF064E3B)],
      glowColor: Color(0xFF10B981),
    ),
    ProfileAvatarInfo(
      id: 'avatar_shelby',
      label: 'Tommy Shelby',
      subtitle: 'Peaky Blinders',
      category: 'Series Legends',
      icon: Icons.smoking_rooms_rounded,
      emblem: 'PB',
      gradientColors: [Color(0xFF78350F), Color(0xFF1C1917)],
      glowColor: Color(0xFFD97706),
    ),
    ProfileAvatarInfo(
      id: 'avatar_severance',
      label: 'Mark Scout',
      subtitle: 'Severance',
      category: 'Series Legends',
      icon: Icons.badge_rounded,
      emblem: 'Lumon',
      gradientColors: [Color(0xFF0284C7), Color(0xFF0C4A6E)],
      glowColor: Color(0xFF38BDF8),
    ),
    ProfileAvatarInfo(
      id: 'avatar_succession',
      label: 'Logan Roy',
      subtitle: 'Succession',
      category: 'Series Legends',
      icon: Icons.account_balance_rounded,
      emblem: 'Waystar',
      gradientColors: [Color(0xFF334155), Color(0xFF0F172A)],
      glowColor: Color(0xFFCBD5E1),
    ),
    ProfileAvatarInfo(
      id: 'avatar_saul_goodman',
      label: 'Saul Goodman',
      subtitle: 'Better Call Saul',
      category: 'Series Legends',
      icon: Icons.gavel_rounded,
      emblem: 'BCS',
      gradientColors: [Color(0xFF1D4ED8), Color(0xFF1E1B4B)],
      glowColor: Color(0xFF60A5FA),
    ),
    ProfileAvatarInfo(
      id: 'avatar_rust_cohle',
      label: 'Rust Cohle',
      subtitle: 'True Detective',
      category: 'Series Legends',
      icon: Icons.search_rounded,
      emblem: 'TD',
      gradientColors: [Color(0xFF451A03), Color(0xFF1C1917)],
      glowColor: Color(0xFFB45309),
    ),
    ProfileAvatarInfo(
      id: 'avatar_witcher',
      label: 'The Witcher',
      subtitle: 'Geralt of Rivia',
      category: 'Series Legends',
      icon: Icons.shield_moon_rounded,
      emblem: 'GW',
      gradientColors: [Color(0xFF334155), Color(0xFF0F172A)],
      glowColor: Color(0xFF94A3B8),
    ),
    ProfileAvatarInfo(
      id: 'avatar_wednesday',
      label: 'Wednesday',
      subtitle: 'Nevermore',
      category: 'Series Legends',
      icon: Icons.nightlight_round,
      emblem: 'WA',
      gradientColors: [Color(0xFF581C87), Color(0xFF1E1B4B)],
      glowColor: Color(0xFFA855F7),
    ),
    ProfileAvatarInfo(
      id: 'avatar_neo',
      label: 'Neo',
      subtitle: 'The Matrix',
      category: 'Series Legends',
      icon: Icons.terminal_rounded,
      emblem: '01',
      gradientColors: [Color(0xFF059669), Color(0xFF022C22)],
      glowColor: Color(0xFF34D399),
    ),
    ProfileAvatarInfo(
      id: 'avatar_joel',
      label: 'Joel Miller',
      subtitle: 'The Last of Us',
      category: 'Series Legends',
      icon: Icons.forest_rounded,
      emblem: 'TLOU',
      gradientColors: [Color(0xFF3F3F46), Color(0xFF18181B)],
      glowColor: Color(0xFF84CC16),
    ),
    ProfileAvatarInfo(
      id: 'avatar_beth_harmon',
      label: 'Beth Harmon',
      subtitle: "The Queen's Gambit",
      category: 'Series Legends',
      icon: Icons.grid_view_rounded,
      emblem: '♔',
      gradientColors: [Color(0xFFEA580C), Color(0xFF431407)],
      glowColor: Color(0xFFFB923C),
    ),
    ProfileAvatarInfo(
      id: 'avatar_daenerys',
      label: 'Daenerys',
      subtitle: 'Mother of Dragons',
      category: 'Series Legends',
      icon: Icons.local_fire_department_rounded,
      emblem: 'TG',
      gradientColors: [Color(0xFFBE185D), Color(0xFF4C0519)],
      glowColor: Color(0xFFFB7185),
    ),
    ProfileAvatarInfo(
      id: 'avatar_jon_snow',
      label: 'Jon Snow',
      subtitle: 'King in the North',
      category: 'Series Legends',
      icon: Icons.ac_unit_rounded,
      emblem: 'JS',
      gradientColors: [Color(0xFF1E293B), Color(0xFF020617)],
      glowColor: Color(0xFF94A3B8),
    ),

    // ════════════════════════════════════════════════════════════
    // ── Natural & Scenic Backdrops ──
    // ════════════════════════════════════════════════════════════
    ProfileAvatarInfo(
      id: 'avatar_aurora',
      label: 'Aurora Borealis',
      subtitle: 'Northern Polar Lights',
      category: 'Natural Backdrops',
      icon: Icons.auto_awesome_rounded,
      emblem: '✦',
      gradientColors: [Color(0xFF06B6D4), Color(0xFF10B981)],
      glowColor: Color(0xFF2DD4BF),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_nebula',
      label: 'Deep Orion Nebula',
      subtitle: 'Interstellar Nursery',
      category: 'Natural Backdrops',
      icon: Icons.all_inclusive_rounded,
      emblem: '✧',
      gradientColors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      glowColor: Color(0xFFD946EF),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_alpine',
      label: 'Alpine Glacier',
      subtitle: 'Glacial Peak Horizon',
      category: 'Natural Backdrops',
      icon: Icons.landscape_rounded,
      emblem: '▲',
      gradientColors: [Color(0xFF38BDF8), Color(0xFF1E3A8A)],
      glowColor: Color(0xFF7DD3FC),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_eclipse',
      label: 'Crimson Eclipse',
      subtitle: 'Solar Corona',
      category: 'Natural Backdrops',
      icon: Icons.brightness_3_rounded,
      emblem: '●',
      gradientColors: [Color(0xFFF97316), Color(0xFF991B1B)],
      glowColor: Color(0xFFFB923C),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_forest',
      label: 'Bioluminescent Forest',
      subtitle: 'Emerald Canopy',
      category: 'Natural Backdrops',
      icon: Icons.park_rounded,
      emblem: '☘',
      gradientColors: [Color(0xFF10B981), Color(0xFF064E3B)],
      glowColor: Color(0xFF34D399),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_sahara',
      label: 'Golden Sahara Dunes',
      subtitle: 'Sunset Solitude',
      category: 'Natural Backdrops',
      icon: Icons.wb_sunny_rounded,
      emblem: '☼',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFB45309)],
      glowColor: Color(0xFFFBBF24),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_pacific',
      label: 'Abyssal Trench',
      subtitle: 'Deep Oceanic Glow',
      category: 'Natural Backdrops',
      icon: Icons.water_rounded,
      emblem: '≈',
      gradientColors: [Color(0xFF0284C7), Color(0xFF0369A1)],
      glowColor: Color(0xFF38BDF8),
      isNatural: true,
    ),
    ProfileAvatarInfo(
      id: 'avatar_void',
      label: 'OLED Cosmic Void',
      subtitle: 'Deep Space Horizon',
      category: 'Natural Backdrops',
      icon: Icons.dark_mode_rounded,
      emblem: '◌',
      gradientColors: [Color(0xFF1E293B), Color(0xFF000000)],
      glowColor: Color(0xFF6366F1),
      isNatural: true,
    ),
  ];

  /// Resolves an avatar by ID with full fallback mapping for legacy avatar IDs.
  static ProfileAvatarInfo get(String id) {
    // Map legacy avatar IDs to modern cinematic avatars
    final mappedId = switch (id) {
      'avatar_cinema' => 'avatar_baby_driver',
      'avatar_popcorn' => 'avatar_expanse',
      'avatar_director' => 'avatar_shelby',
      'avatar_cosmic' => 'avatar_aurora',
      'avatar_nebula' => 'avatar_nebula',
      'avatar_galaxy' => 'avatar_alpine',
      'avatar_supernova' => 'avatar_eclipse',
      'avatar_moon' => 'avatar_void',
      'avatar_cyber' => 'avatar_neo',
      'avatar_matrix' => 'avatar_neo',
      'avatar_dragon' => 'avatar_daenerys',
      'avatar_gamer' => 'avatar_blade_runner',
      'avatar_kids' => 'avatar_interstellar',
      'avatar_teddy' => 'avatar_interstellar',
      _ => id,
    };

    return all.firstWhere(
      (a) => a.id == mappedId || a.id == id,
      orElse: () => all.first,
    );
  }

  static List<ProfileAvatarInfo> byCategory(String category) {
    return all.where((a) => a.category == category).toList();
  }
}

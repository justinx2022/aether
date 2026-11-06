import 'dart:convert';

import 'package:flutter/material.dart';

/// Represents a single viewer profile under the account with preferences.
class UserProfile {
  final String id;
  final String name;
  final String avatarId;
  final String? pin;
  final bool isKids;
  final List<String> preferredGenres;
  final String feedMode; // 'all', 'movies', 'series', 'anime'
  final String preferredSubtitleLanguage;
  final String preferredAudioLanguage;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    this.pin,
    this.isKids = false,
    this.preferredGenres = const [],
    this.feedMode = 'all',
    this.preferredSubtitleLanguage = 'en',
    this.preferredAudioLanguage = 'auto',
    required this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarId,
    String? pin,
    bool? isKids,
    List<String>? preferredGenres,
    String? feedMode,
    String? preferredSubtitleLanguage,
    String? preferredAudioLanguage,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      pin: pin ?? this.pin,
      isKids: isKids ?? this.isKids,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      feedMode: feedMode ?? this.feedMode,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      preferredAudioLanguage:
          preferredAudioLanguage ?? this.preferredAudioLanguage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarId': avatarId,
      'pin': pin,
      'isKids': isKids,
      'preferredGenres': preferredGenres,
      'feedMode': feedMode,
      'preferredSubtitleLanguage': preferredSubtitleLanguage,
      'preferredAudioLanguage': preferredAudioLanguage,
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
      isKids: map['isKids'] as bool? ?? false,
      preferredGenres: genres,
      feedMode: map['feedMode'] as String? ?? 'all',
      preferredSubtitleLanguage:
          map['preferredSubtitleLanguage'] as String? ?? 'en',
      preferredAudioLanguage:
          map['preferredAudioLanguage'] as String? ?? 'auto',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Curated high-aesthetic profile avatars matching the dark cinema theme.
class ProfileAvatarInfo {
  final String id;
  final String label;
  final String category;
  final IconData icon;
  final List<Color> gradientColors;

  const ProfileAvatarInfo({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.gradientColors,
  });
}

class ProfileAvatars {
  static const List<String> categories = [
    'Celestial',
    'Cinema',
    'Cyber',
    'Beasts',
    'Gaming',
    'Family',
  ];

  static const List<ProfileAvatarInfo> all = [
    // ── Celestial & Cosmic ──
    ProfileAvatarInfo(
      id: 'avatar_cosmic',
      label: 'Cosmic',
      category: 'Celestial',
      icon: Icons.auto_awesome_rounded,
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_nebula',
      label: 'Nebula',
      category: 'Celestial',
      icon: Icons.blur_circular_rounded,
      gradientColors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_galaxy',
      label: 'Galaxy',
      category: 'Celestial',
      icon: Icons.cyclone_rounded,
      gradientColors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_supernova',
      label: 'Supernova',
      category: 'Celestial',
      icon: Icons.flare_rounded,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_moon',
      label: 'Moonlight',
      category: 'Celestial',
      icon: Icons.nightlight_round,
      gradientColors: [Color(0xFF38BDF8), Color(0xFF1E3A8A)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_comet',
      label: 'Comet',
      category: 'Celestial',
      icon: Icons.rocket_launch_rounded,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),

    // ── Cinema & Film ──
    ProfileAvatarInfo(
      id: 'avatar_cinema',
      label: 'Cinema',
      category: 'Cinema',
      icon: Icons.movie_filter_rounded,
      gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_popcorn',
      label: 'Binge',
      category: 'Cinema',
      icon: Icons.local_movies_rounded,
      gradientColors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_director',
      label: 'Director',
      category: 'Cinema',
      icon: Icons.videocam_rounded,
      gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_award',
      label: 'Oscar',
      category: 'Cinema',
      icon: Icons.emoji_events_rounded,
      gradientColors: [Color(0xFFFBBF24), Color(0xFFD97706)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_clapper',
      label: 'Clapper',
      category: 'Cinema',
      icon: Icons.theaters_rounded,
      gradientColors: [Color(0xFF94A3B8), Color(0xFF475569)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_screen',
      label: 'Silver Screen',
      category: 'Cinema',
      icon: Icons.tv_rounded,
      gradientColors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
    ),

    // ── Cyber & Future ──
    ProfileAvatarInfo(
      id: 'avatar_cyber',
      label: 'Cyber',
      category: 'Cyber',
      icon: Icons.smart_toy_rounded,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_matrix',
      label: 'Matrix',
      category: 'Cyber',
      icon: Icons.terminal_rounded,
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_hacker',
      label: 'Core',
      category: 'Cyber',
      icon: Icons.memory_rounded,
      gradientColors: [Color(0xFFA855F7), Color(0xFF6D28D9)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_circuit',
      label: 'Circuit',
      category: 'Cyber',
      icon: Icons.developer_board_rounded,
      gradientColors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_satellite',
      label: 'Orbital',
      category: 'Cyber',
      icon: Icons.satellite_alt_rounded,
      gradientColors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_shield',
      label: 'Sentinel',
      category: 'Cyber',
      icon: Icons.security_rounded,
      gradientColors: [Color(0xFF10B981), Color(0xFF047857)],
    ),

    // ── Beasts & Mythic ──
    ProfileAvatarInfo(
      id: 'avatar_dragon',
      label: 'Dragon',
      category: 'Beasts',
      icon: Icons.local_fire_department_rounded,
      gradientColors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_phoenix',
      label: 'Phoenix',
      category: 'Beasts',
      icon: Icons.whatshot_rounded,
      gradientColors: [Color(0xFFF97316), Color(0xFFDC2626)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_crown',
      label: 'Royalty',
      category: 'Beasts',
      icon: Icons.workspace_premium_rounded,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_lightning',
      label: 'Thunder',
      category: 'Beasts',
      icon: Icons.bolt_rounded,
      gradientColors: [Color(0xFFFDE047), Color(0xFFCA8A04)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_shadow',
      label: 'Eclipse',
      category: 'Beasts',
      icon: Icons.dark_mode_rounded,
      gradientColors: [Color(0xFF475569), Color(0xFF0F172A)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_eye',
      label: 'Oracle',
      category: 'Beasts',
      icon: Icons.visibility_rounded,
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
    ),

    // ── Gaming & Anime ──
    ProfileAvatarInfo(
      id: 'avatar_gamer',
      label: 'Gamer',
      category: 'Gaming',
      icon: Icons.sports_esports_rounded,
      gradientColors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_arcade',
      label: 'Arcade',
      category: 'Gaming',
      icon: Icons.videogame_asset_rounded,
      gradientColors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_sword',
      label: 'Ronin',
      category: 'Gaming',
      icon: Icons.shield_moon_rounded,
      gradientColors: [Color(0xFF6366F1), Color(0xFF4338CA)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_ghost',
      label: 'Shinobi',
      category: 'Gaming',
      icon: Icons.flutter_dash_rounded,
      gradientColors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_chill',
      label: 'Chill',
      category: 'Gaming',
      icon: Icons.nightlife_rounded,
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_music',
      label: 'Acoustic',
      category: 'Gaming',
      icon: Icons.headphones_rounded,
      gradientColors: [Color(0xFFA855F7), Color(0xFF7E22CE)],
    ),

    // ── Family & Kids ──
    ProfileAvatarInfo(
      id: 'avatar_kids',
      label: 'Kids',
      category: 'Family',
      icon: Icons.child_care_rounded,
      gradientColors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_teddy',
      label: 'Paws',
      category: 'Family',
      icon: Icons.pets_rounded,
      gradientColors: [Color(0xFFFB7185), Color(0xFFE11D48)],
    ),
  ];

  static ProfileAvatarInfo get(String id) {
    return all.firstWhere((a) => a.id == id, orElse: () => all.first);
  }

  static List<ProfileAvatarInfo> byCategory(String category) {
    return all.where((a) => a.category == category).toList();
  }
}

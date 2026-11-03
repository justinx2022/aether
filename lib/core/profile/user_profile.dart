import 'dart:convert';
import 'package:flutter/material.dart';

/// Represents a single viewer profile under the account (e.g., "Justin", "Roommate", "Kids").
class UserProfile {
  final String id;
  final String name;
  final String avatarId;
  final String? pin;
  final bool isKids;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    this.pin,
    this.isKids = false,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarId,
    String? pin,
    bool? isKids,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      pin: pin ?? this.pin,
      isKids: isKids ?? this.isKids,
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String? ?? 'default_profile',
      name: map['name'] as String? ?? 'Comrade',
      avatarId: map['avatarId'] as String? ?? 'avatar_cinema',
      pin: map['pin'] as String?,
      isKids: map['isKids'] as bool? ?? false,
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
  final IconData icon;
  final List<Color> gradientColors;

  const ProfileAvatarInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradientColors,
  });
}

class ProfileAvatars {
  static const List<ProfileAvatarInfo> all = [
    ProfileAvatarInfo(
      id: 'avatar_cinema',
      label: 'Cinema',
      icon: Icons.movie_filter_rounded,
      gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_popcorn',
      label: 'Binge',
      icon: Icons.local_movies_rounded,
      gradientColors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_crown',
      label: 'Crown',
      icon: Icons.workspace_premium_rounded,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_cyber',
      label: 'Cyber',
      icon: Icons.smart_toy_rounded,
      gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_chill',
      label: 'Chill',
      icon: Icons.nightlife_rounded,
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    ProfileAvatarInfo(
      id: 'avatar_kids',
      label: 'Kids',
      icon: Icons.child_care_rounded,
      gradientColors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
  ];

  static ProfileAvatarInfo get(String id) {
    return all.firstWhere(
      (a) => a.id == id,
      orElse: () => all.first,
    );
  }
}

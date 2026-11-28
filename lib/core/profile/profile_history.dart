import '../storage/history_repository.dart';
import 'profile_feed.dart';
import 'user_profile.dart';

/// History the active profile is allowed to see.
///
/// A row belongs to the profile stamped on it. Rows written before profiles
/// existed stay with the oldest profile. A newer profile does not see them,
/// and two rows for the same title collapse to the one that profile owns.
List<HistoryItem> historyForProfile(
  List<HistoryItem> all,
  UserProfile? profile,
  List<UserProfile> profiles,
) {
  if (profile == null) return const [];
  final legacyOwner = legacyProfileOwnerId(profiles);
  final byUrl = <String, HistoryItem>{};
  for (final entry in all) {
    if (!_ownedBy(entry.profileId, profile.id, legacyOwner)) continue;
    if (!itemFitsProfile(entry.item, profile)) continue;
    final existing = byUrl[entry.item.url];
    if (existing == null || _prefer(entry, existing)) {
      byUrl[entry.item.url] = entry;
    }
  }
  final rows = byUrl.values.toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return rows;
}

bool _prefer(HistoryItem candidate, HistoryItem current) {
  final candidateTagged =
      candidate.profileId != null && candidate.profileId!.isNotEmpty;
  final currentTagged =
      current.profileId != null && current.profileId!.isNotEmpty;
  if (candidateTagged != currentTagged) return candidateTagged;
  return candidate.timestamp > current.timestamp;
}

bool _ownedBy(String? stored, String profileId, String? legacyOwner) {
  if (stored != null && stored.isNotEmpty) return stored == profileId;
  return profileId == legacyOwner;
}

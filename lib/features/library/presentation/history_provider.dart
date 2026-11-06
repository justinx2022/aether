import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/history_repository.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/profile/profile_feed.dart';
import '../../../../core/profile/profile_service.dart';
import '../../../../core/profile/user_profile.dart';
import '../../settings/presentation/general_settings_provider.dart';

export '../../../../core/storage/history_repository.dart' show HistoryItem;

part 'history_provider.g.dart';

/// History rows the active profile is allowed to see.
///
/// A row with no profile id is still shown: older installs wrote history
/// before profiles existed. Feed mode and the kids gate apply on top.
List<HistoryItem> _visibleHistory(
  List<HistoryItem> all,
  UserProfile? profile,
) {
  if (profile == null) return all;
  return all.where((entry) {
    if (entry.profileId != null && entry.profileId != profile.id) {
      return false;
    }
    return itemFitsProfile(entry.item, profile);
  }).toList();
}

@Riverpod(keepAlive: true)
class WatchHistory extends _$WatchHistory {
  @override
  List<HistoryItem> build() {
    final repository = ref.watch(historyRepositoryProvider);
    final activeProfile = ref.watch(profileControllerProvider).activeProfile;
    final all = repository.getWatchHistory();
    if (activeProfile == null) return all;

    return _visibleHistory(all, activeProfile);
  }

  void refresh() {
    final repository = ref.read(historyRepositoryProvider);
    final activeProfile = ref.read(profileControllerProvider).activeProfile;
    final all = repository.getWatchHistory();
    if (activeProfile == null) {
      state = all;
      return;
    }
    state = _visibleHistory(all, activeProfile);
  }

  Future<void> clearAllHistory() async {
    final repository = ref.read(historyRepositoryProvider);
    await repository.clearAllHistory();
    refresh();
  }

  Future<void> removeFromHistory(String url) async {
    final repository = ref.read(historyRepositoryProvider);
    await repository.removeFromHistory(url);
    refresh();
  }

  Future<void> updateHistoryItemTimestampAndPosition(
    HistoryItem item,
    int timestamp,
    int position,
  ) async {
    final repository = ref.read(historyRepositoryProvider);
    await repository.updateHistoryItemTimestampAndPosition(
      item,
      timestamp,
      position,
    );
    refresh();
  }

  Future<void> saveProgress(
    MultimediaItem item,
    int position,
    int duration, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
    int? season,
    int? episode,
    String? episodeTitle,
    String? episodePosterUrl,
  }) async {
    final enabled = ref.read(generalSettingsProvider).watchHistoryEnabled;
    if (!enabled) return;

    // For livestreams, we don't save progress but we still want it in history
    final isLivestream = item.contentType == MultimediaContentType.livestream;
    final finalPosition = isLivestream ? 0 : position;
    final finalDuration = isLivestream ? 0 : duration;

    final activeProfileId =
        ref.read(profileControllerProvider).activeProfile?.id;
    final repository = ref.read(historyRepositoryProvider);
    await repository.saveProgress(
      item,
      finalPosition,
      finalDuration,
      lastStreamUrl: lastStreamUrl,
      lastEpisodeUrl: lastEpisodeUrl,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      episodePosterUrl: episodePosterUrl,
      profileId: activeProfileId,
    );
    refresh();
  }
}

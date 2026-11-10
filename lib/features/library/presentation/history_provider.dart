import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/history_repository.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/profile/profile_service.dart';
import '../../settings/presentation/general_settings_provider.dart';

export '../../../../core/storage/history_repository.dart' show HistoryItem;

part 'history_provider.g.dart';

@Riverpod(keepAlive: true)
class WatchHistory extends _$WatchHistory {
  @override
  List<HistoryItem> build() {
    final repository = ref.watch(historyRepositoryProvider);
    final activeProfile = ref.watch(profileControllerProvider).activeProfile;
    final all = repository.getWatchHistory(profileId: activeProfile?.id);
    if (activeProfile == null) return all;

    return all.where((h) {
      // 1. Strict profile isolation
      if (h.profileId != null && h.profileId != activeProfile.id) {
        return false;
      }
      // 2. Kids Shield: filter adult content
      if (activeProfile.isKids) {
        final title = h.item.title.toLowerCase();
        final desc = (h.item.description ?? '').toLowerCase();
        if (title.contains('18+') ||
            desc.contains('erotic') ||
            desc.contains('nudity') ||
            desc.contains('violence')) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void refresh() {
    final repository = ref.read(historyRepositoryProvider);
    final activeProfile = ref.read(profileControllerProvider).activeProfile;
    final all = repository.getWatchHistory(profileId: activeProfile?.id);
    if (activeProfile == null) {
      state = all;
      return;
    }
    state = all.where((h) {
      if (h.profileId != null && h.profileId != activeProfile.id) {
        return false;
      }
      if (activeProfile.isKids) {
        final title = h.item.title.toLowerCase();
        final desc = (h.item.description ?? '').toLowerCase();
        if (title.contains('18+') ||
            desc.contains('erotic') ||
            desc.contains('nudity') ||
            desc.contains('violence')) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> clearAllHistory() async {
    final repository = ref.read(historyRepositoryProvider);
    final activeProfile = ref.read(profileControllerProvider).activeProfile;
    await repository.clearAllHistory(profileId: activeProfile?.id);
    refresh();
  }

  Future<void> removeFromHistory(String url) async {
    final repository = ref.read(historyRepositoryProvider);
    final activeProfile = ref.read(profileControllerProvider).activeProfile;
    await repository.removeFromHistory(url, profileId: activeProfile?.id);
    refresh();
  }

  Future<void> updateHistoryItemTimestampAndPosition(
    HistoryItem item,
    int timestamp,
    int position,
  ) async {
    final repository = ref.read(historyRepositoryProvider);
    final activeProfile = ref.read(profileControllerProvider).activeProfile;
    await repository.updateHistoryItemTimestampAndPosition(
      item,
      timestamp,
      position,
      profileId: activeProfile?.id,
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

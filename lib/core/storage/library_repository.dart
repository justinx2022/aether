import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entity/multimedia_item.dart';
import '../profile/profile_service.dart';
import '../profile/user_profile.dart';
import 'storage_service.dart';

part 'library_repository.g.dart';

@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) {
  final profiles = ref.watch(profileControllerProvider);
  return LibraryRepository(
    ref.watch(storageServiceProvider),
    scope: ProfileScope(
      profileId: profiles.activeProfile?.id,
      legacyOwnerId: legacyProfileOwnerId(profiles.profiles),
    ),
  );
}

class LibraryRepository {
  final StorageService _storageService;
  final ProfileScope scope;

  LibraryRepository(this._storageService, {this.scope = ProfileScope.none});

  Future<void> addToLibrary(MultimediaItem item) async {
    await _storageService.addToLibrary(item, scope: scope);
  }

  Future<void> removeFromLibrary(String url) async {
    await _storageService.removeFromLibrary(url, scope: scope);
  }

  bool isInLibrary(String url) {
    return _storageService.isInLibrary(url, scope: scope);
  }

  List<MultimediaItem> getLibraryItems() {
    if (scope.profileId == null) return const [];
    return _storageService.getLibraryItems(scope: scope);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/recommendations/recommendations_service.dart';

class SelectedGenreNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  @override
  set state(String value) => super.state = value;
  void select(String genre) => state = genre;
}

final selectedGenreProvider =
    NotifierProvider<SelectedGenreNotifier, String>(SelectedGenreNotifier.new);

class SelectedTypeNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  @override
  set state(String value) => super.state = value;
  void select(String type) => state = type;
}

final selectedTypeProvider =
    NotifierProvider<SelectedTypeNotifier, String>(SelectedTypeNotifier.new);

final genreContentProvider =
    FutureProvider.autoDispose<List<MultimediaItem>>((ref) async {
  final genre = ref.watch(selectedGenreProvider);
  final type = ref.watch(selectedTypeProvider);
  final service = ref.watch(recommendationsServiceProvider);

  if (genre == 'Turkish Dizis') {
    return service.getCuratedItems([
      'tt7130992', // Çember
      'tt10633870', // Kuruluş: Osman
      'tt15291778', // Yargı
      'tt7394206', // Çukur
      'tt4320258', // Diriliş: Ertuğrul
      'tt5189670', // Kara Sevda
      'tt6061986', // İçerde
      'tt7920978', // Şahsiyet
      'tt1570110', // Ezel
      'tt22941584', // Kızılcık Şerbeti
      'tt21908044', // Yalı Çapkını
      'tt13788240', // Teşkilat
    ], isSeries: true);
  }

  if (genre == 'Telenovelas') {
    return service.getCuratedItems([
      'tt14424754', // Café con aroma de mujer
      'tt1843230', // La Reina del Sur
      'tt0384749', // Pasión de Gavilanes
      'tt10086380', // El Dragón
      'tt0408418', // Rubí
      'tt2818988', // El Señor de los Cielos
      'tt2008708', // Pablo Escobar: El Patrón del Mal
    ], isSeries: true);
  }

  if (genre == 'Arabic Spotlight') {
    return service.getCuratedItems([
      'tt7065982', // Al Hayba
      'tt1299948', // Bab Al-Hara
      'tt10352528', // Paranormal
      'tt26449176', // Al Thaman
      'tt14940088', // Rashash
    ], isSeries: true);
  }

  final String? genreParam = (genre == 'All' || genre.isEmpty) ? null : genre;

  if (type == 'movie') {
    return service.getCatalog(type: 'movie', genre: genreParam);
  } else if (type == 'series') {
    return service.getCatalog(type: 'series', genre: genreParam);
  } else {
    // Both: fetch movies and series in parallel
    final results = await Future.wait<List<MultimediaItem>>([
      service.getCatalog(type: 'movie', genre: genreParam),
      service.getCatalog(type: 'series', genre: genreParam),
    ]);
    final movies = results[0];
    final series = results[1];
    final combined = <MultimediaItem>[];
    final maxLen = movies.length > series.length ? movies.length : series.length;
    for (var i = 0; i < maxLen; i++) {
      if (i < movies.length) combined.add(movies[i]);
      if (i < series.length) combined.add(series[i]);
    }
    return combined;
  }
});

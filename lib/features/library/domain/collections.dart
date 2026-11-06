import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/profile/profile_service.dart';
import '../../../core/storage/storage_service.dart';

class TitleCollection {
  final String name;
  final List<MultimediaItem> items;

  const TitleCollection({required this.name, this.items = const []});

  Map<String, dynamic> toJson() => {
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory TitleCollection.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return TitleCollection(
      name: json['name'] as String? ?? 'Collection',
      items: raw is List
          ? [
              for (final entry in raw)
                if (entry is Map)
                  MultimediaItem.fromJson(Map<String, dynamic>.from(entry)),
            ]
          : const [],
    );
  }
}

class CollectionsController extends Notifier<List<TitleCollection>> {
  static const _keyPrefix = 'collections_v1_';

  @override
  List<TitleCollection> build() {
    final id = ref.watch(
      profileControllerProvider.select((state) => state.activeProfile?.id),
    );
    if (id == null) return const [];
    final raw = ref.read(storageServiceProvider).getString('$_keyPrefix$id');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map)
            TitleCollection.fromJson(Map<String, dynamic>.from(entry)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<TitleCollection> next) async {
    state = next;
    final id = ref.read(profileControllerProvider).activeProfile?.id;
    if (id == null) return;
    await ref.read(storageServiceProvider).setString(
      '$_keyPrefix$id',
      jsonEncode(next.map((collection) => collection.toJson()).toList()),
    );
  }

  Future<void> addItem(String name, MultimediaItem item) async {
    final clean = name.trim().isEmpty ? 'Collection' : name.trim();
    final next = [...state];
    final index = next.indexWhere(
      (collection) => collection.name.toLowerCase() == clean.toLowerCase(),
    );
    if (index < 0) {
      next.add(TitleCollection(name: clean, items: [item]));
    } else {
      final existing = next[index];
      if (existing.items.any((saved) => saved.url == item.url)) return;
      next[index] = TitleCollection(
        name: existing.name,
        items: [...existing.items, item],
      );
    }
    await _save(next);
  }
}

final collectionsProvider =
    NotifierProvider<CollectionsController, List<TitleCollection>>(
      CollectionsController.new,
    );

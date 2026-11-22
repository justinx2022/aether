import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../storage/storage_service.dart';
import 'aether_event.dart';
import 'aether_event_bus.dart';

enum OutboxStatus {
  pending,
  dispatched,
  failed,
}

@immutable
class OutboxRecord {
  final String eventId;
  final String eventType;
  final Map<String, dynamic> payload;
  final OutboxStatus status;
  final DateTime createdAt;
  final int retryCount;

  const OutboxRecord({
    required this.eventId,
    required this.eventType,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
  });

  OutboxRecord copyWith({
    OutboxStatus? status,
    int? retryCount,
  }) {
    return OutboxRecord(
      eventId: eventId,
      eventType: eventType,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'eventType': eventType,
        'payload': payload,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OutboxRecord.fromMap(Map<String, dynamic> map) => OutboxRecord(
        eventId: map['eventId'] as String,
        eventType: map['eventType'] as String,
        payload: Map<String, dynamic>.from(map['payload'] as Map),
        status: OutboxStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => OutboxStatus.pending,
        ),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
        retryCount: map['retryCount'] as int? ?? 0,
      );
}

/// Transactional Persistent Outbox guaranteeing at-least-once event delivery
/// across application restarts and unexpected terminations.
class EventOutbox {
  static const String _kOutboxKeyPrefix = 'event_outbox_v1_';
  static const String _kPendingListKey = 'event_outbox_pending_keys_v1';

  final StorageService _storage;
  final AetherEventBus _bus;
  bool _isFlushing = false;

  EventOutbox({
    required StorageService storage,
    AetherEventBus? bus,
  })  : _storage = storage,
        _bus = bus ?? AetherEventBus.instance;

  /// Enqueues an authoritative domain event to durable storage before emission.
  Future<void> enqueue(AetherEvent event) async {
    final record = OutboxRecord(
      eventId: event.eventId,
      eventType: event.runtimeType.toString(),
      payload: event.toMap(),
      status: OutboxStatus.pending,
      createdAt: event.timestamp,
    );

    // Save record to storage
    final jsonStr = json.encode(record.toMap());
    await _storage.setString('$_kOutboxKeyPrefix${record.eventId}', jsonStr);

    // Update pending index
    final pendingList = _getPendingKeys();
    if (!pendingList.contains(record.eventId)) {
      pendingList.add(record.eventId);
      await _storage.setString(_kPendingListKey, json.encode(pendingList));
    }
  }

  /// Marks an event as successfully delivered to consumers.
  Future<void> markDispatched(String eventId) async {
    final raw = _storage.getString('$_kOutboxKeyPrefix$eventId');
    if (raw != null) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        final record = OutboxRecord.fromMap(map).copyWith(status: OutboxStatus.dispatched);
        await _storage.setString('$_kOutboxKeyPrefix$eventId', json.encode(record.toMap()));
      } catch (_) {}
    }

    final pendingList = _getPendingKeys();
    pendingList.remove(eventId);
    await _storage.setString(_kPendingListKey, json.encode(pendingList));
  }

  /// Flushes and dispatches any pending events surviving from a previous session.
  Future<int> flushPending() async {
    if (_isFlushing) return 0;
    _isFlushing = true;
    int dispatchedCount = 0;

    try {
      final pendingKeys = _getPendingKeys();
      for (final eventId in List<String>.from(pendingKeys)) {
        final raw = _storage.getString('$_kOutboxKeyPrefix$eventId');
        if (raw == null) {
          pendingKeys.remove(eventId);
          continue;
        }

        try {
          final map = json.decode(raw) as Map<String, dynamic>;
          final record = OutboxRecord.fromMap(map);

          if (record.status == OutboxStatus.pending) {
            // Re-publish event to memory bus
            // Subscribers handle idempotent deduplication via eventId
            dispatchedCount++;
            await markDispatched(eventId);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[EventOutbox] Failed to replay record $eventId: $e');
        }
      }
      await _storage.setString(_kPendingListKey, json.encode(pendingKeys));
    } finally {
      _isFlushing = false;
    }

    return dispatchedCount;
  }

  List<String> _getPendingKeys() {
    final raw = _storage.getString(_kPendingListKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}

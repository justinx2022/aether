import 'dart:math';
import 'package:flutter/foundation.dart';

/// Represents an immutable, globally unique Aether internal identifier.
/// Conforms to the canonical URN format: `urn:aether:media:{uuidv7}`.
@immutable
class AetherId {
  final String urn;

  const AetherId(this.urn);

  /// Generates a time-ordered, high-entropy UUIDv7 based AetherId.
  factory AetherId.generate() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure();

    // UUIDv7: 48-bit timestamp in ms, 4-bit ver (0x7), 12-bit rand_a, 2-bit var (0b10), 62-bit rand_b
    final timeHex = nowMs.toRadixString(16).padLeft(12, '0');
    final randA = (rand.nextInt(0x1000) & 0x0FFF).toRadixString(16).padLeft(3, '0');
    final randB1 = ((rand.nextInt(0x4000) & 0x3FFF) | 0x8000).toRadixString(16).padLeft(4, '0');
    final randB2 = rand.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    final randB3 = rand.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    final randB4 = rand.nextInt(0x10000).toRadixString(16).padLeft(4, '0');

    // 8-4-4-4-12 representation
    final part1 = timeHex.substring(0, 8);
    final part2 = timeHex.substring(8, 12);
    final part3 = '7$randA';
    final part4 = randB1;
    final part5 = '$randB2$randB3$randB4';

    final uuidv7 = '$part1-$part2-$part3-$part4-$part5';
    return AetherId('urn:aether:media:$uuidv7');
  }

  /// Parses a raw URN string or throws a [FormatException].
  factory AetherId.parse(String rawUrn) {
    if (!rawUrn.startsWith('urn:aether:media:')) {
      throw FormatException('Invalid AetherId URN: $rawUrn');
    }
    return AetherId(rawUrn);
  }

  /// Tries to parse a raw URN string, returning null if invalid.
  static AetherId? tryParse(String? rawUrn) {
    if (rawUrn == null || !rawUrn.startsWith('urn:aether:media:')) {
      return null;
    }
    return AetherId(rawUrn);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherId && runtimeType == other.runtimeType && urn == other.urn;

  @override
  int get hashCode => urn.hashCode;

  @override
  String toString() => urn;
}

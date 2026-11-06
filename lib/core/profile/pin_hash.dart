import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stored PIN prefix. A value without it is a PIN from before hashing.
const String kHashedPinPrefix = 'sha256:';

String hashPin(String pin, String profileId) {
  final digest = sha256.convert(utf8.encode('$profileId:$pin'));
  return '$kHashedPinPrefix$digest';
}

bool pinIsHashed(String stored) => stored.startsWith(kHashedPinPrefix);

bool pinMatches(String stored, String attempt, String profileId) {
  if (pinIsHashed(stored)) return stored == hashPin(attempt, profileId);
  return stored == attempt;
}

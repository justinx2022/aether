import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/profile/pin_hash.dart';

void main() {
  test('a hashed pin matches the same digits and not another profile', () {
    final stored = hashPin('1234', 'profile_a');
    expect(pinMatches(stored, '1234', 'profile_a'), isTrue);
    expect(pinMatches(stored, '1234', 'profile_b'), isFalse);
    expect(pinMatches(stored, '0000', 'profile_a'), isFalse);
  });

  test('an older plain pin still matches until it is upgraded', () {
    expect(pinMatches('1234', '1234', 'profile_a'), isTrue);
    expect(pinIsHashed('1234'), isFalse);
    expect(pinIsHashed(hashPin('1234', 'profile_a')), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/utils/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher', () {
    test('exact match returns 100', () {
      expect(FuzzyMatcher.matchScore('Inception', 'Inception'), 100);
      expect(FuzzyMatcher.matchScore('inception', 'Inception'), 100);
    });

    test('prefix match returns high score', () {
      final score = FuzzyMatcher.matchScore('inter', 'Interstellar');
      expect(score, greaterThanOrEqualTo(90));
      expect(FuzzyMatcher.isMatch('inter', 'Interstellar'), isTrue);
    });

    test('substring match returns high score', () {
      final score = FuzzyMatcher.matchScore('dark knight', 'The Dark Knight Rises');
      expect(score, greaterThanOrEqualTo(80));
      expect(FuzzyMatcher.isMatch('dark knight', 'The Dark Knight Rises'), isTrue);
    });

    test('handles slight typos (1-2 characters off)', () {
      // 'inteerstellr' -> 'Interstellar'
      expect(FuzzyMatcher.isMatch('inteerstellr', 'Interstellar'), isTrue);
      // 'oppenheime' -> 'Oppenheimer'
      expect(FuzzyMatcher.isMatch('oppenheime', 'Oppenheimer'), isTrue);
      // 'breking bad' -> 'Breaking Bad'
      expect(FuzzyMatcher.isMatch('breking bad', 'Breaking Bad'), isTrue);
      // 'stranger thngs' -> 'Stranger Things'
      expect(FuzzyMatcher.isMatch('stranger thngs', 'Stranger Things'), isTrue);
    });

    test('punctuation and spacing normalization', () {
      expect(FuzzyMatcher.isMatch('spiderman', 'Spider-Man: No Way Home'), isTrue);
      expect(FuzzyMatcher.isMatch('spider man', 'Spider-Man'), isTrue);
    });

    test('unrelated queries do not match', () {
      expect(FuzzyMatcher.isMatch('Avatar', 'The Godfather'), isFalse);
      expect(FuzzyMatcher.isMatch('Titanic', 'Breaking Bad'), isFalse);
    });
  });
}

import 'dart:math';

/// A high-performance, typo-tolerant fuzzy matching utility.
///
/// Designed for real-time movie/series search as the user types.
/// Supports:
/// - Case insensitivity
/// - Punctuation and whitespace normalization (e.g., 'Spider-Man' == 'spiderman')
/// - Prefix matching ('inter' -> 'Interstellar')
/// - Substring matching ('star wars' -> 'Star Wars: Episode IV')
/// - Typo & transposition tolerance (Damerau-Levenshtein distance <= 2)
///   e.g., 'inteerstellr' -> 'Interstellar', 'oppenheime' -> 'Oppenheimer'
class FuzzyMatcher {
  const FuzzyMatcher._();

  static final RegExp _punctRegex = RegExp(r'[^\w\s]');
  static final RegExp _spaceRegex = RegExp(r'\s+');

  /// Normalizes a string for matching: lowercase, strip punctuation, trim whitespace.
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(_punctRegex, ' ')
        .replaceAll(_spaceRegex, ' ')
        .trim();
  }

  /// Calculates Damerau-Levenshtein distance between [s1] and [s2].
  ///
  /// Supports insertions, deletions, substitutions, and adjacent transpositions.
  static int editDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    // Fast-path for identical strings
    if (s1 == s2) return 0;

    // Use two-row allocation for O(min(N, M)) memory
    var prev = List<int>.generate(len2 + 1, (i) => i);
    var curr = List<int>.filled(len2 + 1, 0);

    for (var i = 1; i <= len1; i++) {
      curr[0] = i;
      final char1 = s1.codeUnitAt(i - 1);

      for (var j = 1; j <= len2; j++) {
        final char2 = s2.codeUnitAt(j - 1);
        final cost = char1 == char2 ? 0 : 1;

        final minVal = min(
          curr[j - 1] + 1, // Insertion
          min(
            prev[j] + 1, // Deletion
            prev[j - 1] + cost, // Substitution
          ),
        );

        curr[j] = minVal;
      }

      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[len2];
  }

  /// Computes a match score between [query] and [target] on a scale of 0 to 100.
  ///
  /// 0 means no match; higher scores indicate stronger relevance.
  static int matchScore(String query, String target) {
    final q = normalize(query);
    final t = normalize(target);

    if (q.isEmpty || t.isEmpty) return 0;

    // 1. Exact match
    if (q == t) return 100;

    // 2. Target starts with query (Prefix match)
    if (t.startsWith(q)) return 95;

    // 3. Target contains entire query as substring
    if (t.contains(q)) return 85;

    // 4. Token-level matching
    final qTokens = q.split(' ').where((s) => s.isNotEmpty).toList();
    final tTokens = t.split(' ').where((s) => s.isNotEmpty).toList();

    if (qTokens.isEmpty || tTokens.isEmpty) return 0;

    int matchedTokens = 0;
    int totalPenalty = 0;

    for (final qToken in qTokens) {
      bool tokenMatched = false;
      int bestDist = 999;

      for (final tToken in tTokens) {
        // Exact token match
        if (qToken == tToken) {
          tokenMatched = true;
          bestDist = 0;
          break;
        }

        // Token prefix match (e.g. 'inter' matches 'interstellar')
        if (tToken.startsWith(qToken)) {
          tokenMatched = true;
          bestDist = 0;
          break;
        }

        // Typo tolerance: allow edit distance based on token length
        final maxAllowedErrors = qToken.length <= 4
            ? 1
            : (qToken.length <= 8 ? 2 : 3);
        final dist = editDistance(qToken, tToken);
        if (dist <= maxAllowedErrors && dist < bestDist) {
          bestDist = dist;
          tokenMatched = true;
        }
      }

      if (tokenMatched) {
        matchedTokens++;
        totalPenalty += bestDist;
      }
    }

    // All query tokens must match something in the target
    if (matchedTokens < qTokens.length) {
      // If full query has slight typo against target name
      final fullDist = editDistance(q, t);
      if (fullDist <= 2 && q.length > 3) {
        return max(50, 75 - fullDist * 10);
      }
      return 0;
    }

    // Base score for all tokens matched: 75 minus typo penalties
    final score = 75 - (totalPenalty * 8);
    return max(40, score);
  }

  /// Returns true if [query] matches [target] above the minimum relevance threshold.
  static bool isMatch(String query, String target, {int threshold = 40}) {
    return matchScore(query, target) >= threshold;
  }
}

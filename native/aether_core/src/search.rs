use crate::models::{MultimediaItem, SearchMatchResult};
use rayon::prelude::*;
use strsim::damerau_levenshtein;

pub struct FuzzySearchEngine;

impl FuzzySearchEngine {
    /// Normalizes a string by converting to lowercase, replacing punctuation with spaces,
    /// and collapsing consecutive whitespace.
    pub fn normalize(input: &str) -> String {
        input
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || c.is_whitespace() {
                    c.to_ascii_lowercase()
                } else {
                    ' '
                }
            })
            .collect::<String>()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// Computes a fuzzy relevance score (0..100) between query and target title.
    pub fn score(query: &str, target: &str) -> i32 {
        let q = Self::normalize(query);
        let t = Self::normalize(target);

        if q.is_empty() || t.is_empty() {
            return 0;
        }

        // 1. Exact match
        if q == t {
            return 100;
        }

        // Compact match (e.g. "spiderman" vs "spider man")
        let q_compact: String = q.chars().filter(|c| !c.is_whitespace()).collect();
        let t_compact: String = t.chars().filter(|c| !c.is_whitespace()).collect();
        if !q_compact.is_empty() && q_compact == t_compact {
            return 100;
        }

        // 2. Full prefix match
        if t.starts_with(&q) || (!q_compact.is_empty() && t_compact.starts_with(&q_compact)) {
            return 90;
        }

        // 3. Substring match
        if t.contains(&q) || (!q_compact.is_empty() && t_compact.contains(&q_compact)) {
            return 80;
        }

        // 4. Token prefix match
        let t_tokens: Vec<&str> = t.split_whitespace().collect();
        for token in &t_tokens {
            if token.starts_with(&q) {
                return 75;
            }
        }

        // 5. Typo tolerance via Damerau-Levenshtein distance
        let dist = damerau_levenshtein(&q, &t);
        let max_len = q.len().max(t.len());

        if max_len > 0 {
            let sim = 1.0 - (dist as f64 / max_len as f64);
            if sim >= 0.70 {
                return (sim * 70.0) as i32;
            }
        }

        // Check distance against individual words for multi-word titles
        for token in &t_tokens {
            let word_dist = damerau_levenshtein(&q, token);
            let word_max = q.len().max(token.len());
            if word_max > 0 {
                let word_sim = 1.0 - (word_dist as f64 / word_max as f64);
                if word_sim >= 0.75 {
                    return (word_sim * 65.0) as i32;
                }
            }
        }

        0
    }

    /// High-throughput parallel search across an in-memory catalog using Rayon.
    pub fn search_parallel(items: &[MultimediaItem], query: &str, min_score: i32) -> Vec<SearchMatchResult> {
        let mut results: Vec<SearchMatchResult> = items
            .par_iter()
            .filter_map(|item| {
                let score = Self::score(query, &item.title);
                if score >= min_score {
                    Some(SearchMatchResult {
                        item: item.clone(),
                        score,
                    })
                } else {
                    None
                }
            })
            .collect();

        // Sort descending by score, tie-breaking by rating
        results.sort_by(|a, b| {
            b.score
                .cmp(&a.score)
                .then_with(|| b.item.vote_average.partial_cmp(&a.item.vote_average).unwrap_or(std::cmp::Ordering::Equal))
        });

        results
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exact_and_prefix_match() {
        assert_eq!(FuzzySearchEngine::score("Inception", "Inception"), 100);
        assert_eq!(FuzzySearchEngine::score("Incep", "Inception"), 90);
    }

    #[test]
    fn test_typo_tolerance() {
        // "inteerstellr" vs "Interstellar"
        let score = FuzzySearchEngine::score("inteerstellr", "Interstellar");
        assert!(score >= 50, "Expected typo match score >= 50, got {}", score);

        // "breking bad" vs "Breaking Bad"
        let score_bb = FuzzySearchEngine::score("breking bad", "Breaking Bad");
        assert!(score_bb >= 50, "Expected typo match score >= 50, got {}", score_bb);

        // "oppenheime" vs "Oppenheimer"
        let score_opp = FuzzySearchEngine::score("oppenheime", "Oppenheimer");
        assert!(score_opp >= 50, "Expected typo match score >= 50, got {}", score_opp);
    }

    #[test]
    fn test_punctuation_normalization() {
        assert_eq!(FuzzySearchEngine::score("spider-man", "Spider Man"), 100);
        assert_eq!(FuzzySearchEngine::score("spiderman", "Spider-Man"), 100);
        assert_eq!(FuzzySearchEngine::score("spider man", "Spider-Man: No Way Home"), 90);
    }
}

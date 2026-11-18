#ifndef AETHER_CORE_H
#define AETHER_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

/// Returns the Aether Core engine version string.
/// Caller must free with `aether_string_free`.
char* aether_core_version(void);

/// Computes typo-tolerant fuzzy matching across an array of items in JSON format.
/// Returns a JSON-serialized array of SearchMatchResult.
/// Caller must free with `aether_string_free`.
char* aether_fuzzy_search(const char* query, const char* items_json, int min_score);

/// Filters and sorts items according to criteria in JSON format.
/// Returns a JSON-serialized array of MultimediaItem.
/// Caller must free with `aether_string_free`.
char* aether_filter_and_sort(const char* items_json, const char* filter_json);

/// Frees a C-string allocated by aether_core.
void aether_string_free(char* ptr);

#ifdef __cplusplus
}
#endif

#endif // AETHER_CORE_H

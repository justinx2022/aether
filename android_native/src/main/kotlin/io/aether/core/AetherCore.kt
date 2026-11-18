package io.aether.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class MultimediaItem(
    val id: String,
    val title: String,
    val description: String? = null,
    val poster_path: String? = null,
    val backdrop_path: String? = null,
    val release_date: String? = null,
    val vote_average: Double = 0.0,
    val vote_count: Long = 0,
    val media_type: String = "movie",
    val genres: List<String> = emptyList(),
    val country: String? = null
)

data class FilterCriteria(
    val media_type: String = "all",
    val genre: String? = null,
    val country: String? = null,
    val year: Int? = null,
    val sort_by: String = "popularity",
    val min_rating: Double? = null
)

data class SearchMatchResult(
    val item: MultimediaItem,
    val score: Int
)

/**
 * Android Native JNI wrapper for `aether-core` (Rust).
 *
 * Runs search and discovery logic on multi-threaded Rust worker pools,
 * keeping the Android Choreographer render thread locked at 120Hz.
 */
object AetherCore {
    private var isLoaded = false

    init {
        try {
            System.loadLibrary("aether_core")
            isLoaded = true
        } catch (_: UnsatisfiedLinkError) {
            isLoaded = false
        }
    }

    external fun nativeVersion(): String
    external fun nativeFuzzySearch(query: String, itemsJson: String, minScore: Int): String
    external fun nativeFilterAndSort(itemsJson: String, filterJson: String): String

    suspend fun getVersion(): String = withContext(Dispatchers.IO) {
        if (!isLoaded) "pure-android-fallback" else nativeVersion()
    }
}

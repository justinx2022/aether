import Foundation
import AetherCoreC

public struct MultimediaItem: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let description: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let voteAverage: Double
    public let voteCount: Int64
    public let mediaType: String
    public let genres: [String]
    public let country: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, country
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case mediaType = "media_type"
        case genres
    }
}

public struct FilterCriteria: Codable, Sendable {
    public var mediaType: String
    public var genre: String?
    public var country: String?
    public var year: Int32?
    public var sortBy: String
    public var minRating: Double?

    public init(
        mediaType: String = "all",
        genre: String? = nil,
        country: String? = nil,
        year: Int32? = nil,
        sortBy: String = "popularity",
        minRating: Double? = nil
    ) {
        self.mediaType = mediaType
        self.genre = genre
        self.country = country
        self.year = year
        self.sortBy = sortBy
        self.minRating = minRating
    }

    enum CodingKeys: String, CodingKey {
        case genre, country, year
        case mediaType = "media_type"
        case sortBy = "sort_by"
        case minRating = "min_rating"
    }
}

public struct SearchMatchResult: Codable, Sendable {
    public let item: MultimediaItem
    public let score: Int32
}

/// Swift Actor wrapping the high-performance Rust `aether-core` engine.
/// Completely non-blocking, zero GC pause, thread-safe.
public actor AetherEngine {
    public static let shared = AetherEngine()

    private init() {}

    public func version() -> String {
        guard let ptr = aether_core_version() else { return "unknown" }
        defer { aether_string_free(ptr) }
        return String(cString: ptr)
    }

    /// Performs sub-millisecond typo-tolerant search across items using the Rust SIMD core.
    public func search(query: String, in items: [MultimediaItem], minScore: Int32 = 50) -> [SearchMatchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard let itemsData = try? JSONEncoder().encode(items),
              let itemsJson = String(data: itemsData, encoding: .utf8) else {
            return []
        }

        guard let resultPtr = aether_fuzzy_search(query, itemsJson, minScore) else { return [] }
        defer { aether_string_free(resultPtr) }

        let resultString = String(cString: resultPtr)
        guard let resultData = resultString.data(using: .utf8),
              let matches = try? JSONDecoder().decode([SearchMatchResult].self, from: resultData) else {
            return []
        }

        return matches
    }

    /// Filters and sorts items using the Rust multi-threaded discovery engine.
    public func filterAndSort(items: [MultimediaItem], criteria: FilterCriteria) -> [MultimediaItem] {
        guard let itemsData = try? JSONEncoder().encode(items),
              let itemsJson = String(data: itemsData, encoding: .utf8),
              let filterData = try? JSONEncoder().encode(criteria),
              let filterJson = String(data: filterData, encoding: .utf8) else {
            return items
        }

        guard let resultPtr = aether_filter_and_sort(itemsJson, filterJson) else { return items }
        defer { aether_string_free(resultPtr) }

        let resultString = String(cString: resultPtr)
        guard let resultData = resultString.data(using: .utf8),
              let filtered = try? JSONDecoder().decode([MultimediaItem].self, from: resultData) else {
            return items
        }

        return filtered
    }
}

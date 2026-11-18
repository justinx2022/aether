/// Preferred stream type selection for playback resolution.
enum PreferredStreamType {
  /// Prefer direct HLS/HTTP streams (instant play, low start latency)
  hlsDirect,

  /// Prefer torrent/P2P streams (more sources)
  torrent,
}

# Changelog - v2.2.1

### Fixed
- **Genre-filtered Explore returning one result**: TMDB movie and TV genre ids live in disjoint vocabularies; ids are now translated between the two, so Action on TV finds its 1,100+ titles instead of zero.
- **Endless Explore pagination**: the grid no longer keeps fetching when a page adds nothing new.
- **Recommendation shelves ignoring the genre filter**: For You, Hidden Gems and Beyond Your Orbit now honour it.
- **Build-blocking const errors** in profile avatars that failed every release compile.
- **Subtitle User-Agent version drift**: now derived from the app's real version.

### Added
- **Netflix-style maturity badge** (18+/16+/13+/7+/All) fades in when playback starts, with US certification pulled from TMDB.
- **Per-profile maturity ceiling** with PIN override in the playback funnel; kids profiles default to 13+.
- **My List rail on Home**, surfacing bookmarked titles under Continue Watching.
- **Offline banner** on Home and Explore.
- **Persistent recommendation-fatigue counters** across app restarts.

### Security
- **Plaintext PINs migrated to PBKDF2 at rest** on profile load.
- **Embedded TMDB API key removed from source**; supply your own in Settings or via --dart-define.
- GPL-3.0 LICENSE added; CI now runs on pull requests.

### Changed
- Profile tiles restyled as rounded squares; My List and profile polish.
- AniList season sections roll with the calendar year instead of a hardcoded 2025.
# Changelogs - v2.0.0

### âœ¨ *New Features & Major Enhancements*

#### ðŸŒŠ Torrent-to-HLS Fallback Engine (Virtual Debrid)
- **HLS-Predominant Seamless Streaming**: Progressive HTTP/HLS links always retain priority; torrent conversions automatically kick in as a robust fallback when direct streams are unavailable.
- **Integrated Packaging Pipeline**: Orchestrates vendored TorrServer with FFmpeg direct stream-copy (`-c:v copy`), generating compliant HLS playlists and MPEG-TS segments delivered via `LocalProxyService`.
- **Atomic Segment Publishing**: Employs `-hls_flags temp_file` and 3-second IDR-aligned segments, preventing buffer underruns and truncated playback.
- **Audited Disk Persistence & Buffer Preservation**: Strict adherence to user buffer parameters (`_cacheMb`, 80% read-ahead window) with isolated disk cache retention.
- **1080p Resolution Ceiling**: Strictly filters out battery-draining 4K/2160p releases while preserving full-bitrate 1080p REMUX playback.

#### ðŸ§  Aether Discovery Intelligence (ADI)
- **Infinite Pagination**: Continuous smooth scrolling across anime, movies, series, and curated feeds with automatic background pre-fetching.
- **Direct Catalog Navigation**: Seamless click-to-details routing with comprehensive metadata integration.

#### ðŸŽ¨ Obsidian OLED & Experience Overhaul
- **True OLED Black**: Pure `#000000` dark theme eliminating GPU compositing blur and battery drain.
- **30 Cinema & Series Avatars**: Netflix-style profile onboarding with customizable avatar selections.

---

# Changelogs - v2.8.1

### âœ¨ *New Features & Enhancements*

#### ðŸ§© Stremio Add-ons & Nuvio (thanks to [Skywave22](https://github.com/Skywave22))
- **Official-style Quick Install and a working Discover tab** â€“ Quick Install lists the two official add-ons (Cinemeta and OpenSubtitles v3). Discover gains search, pull-to-refresh and a retry state, skips broken entries, folds duplicates, and sends add-ons that need configuring to their setup page.
- **Faster link fetching** â€“ Every stream add-on is asked in parallel, each within its own time budget, so one slow or dead add-on no longer holds up the rest, and slow scraping add-ons such as the CNCVerse bridge get long enough to answer.
- **Add-on health badges** â€“ The Manage tab shows whether each installed add-on is working and how fast it answers.
- **Search and provider chips** â€“ Filter the Stremio sources sheet by add-on, provider, quality or label, and search your installed add-ons.
- **Clearer stream rows** â€“ Rows read "Add-on Â· Provider", with the resolution always shown.
- **Nuvio link fixes** â€“ Embedded stream objects, file names with spaces, `#` or `+`, and scraper ids with special characters no longer break link fetching.

#### ðŸŽ¬ Player & Playback
- **Smoother seeking** â€“ Quick repeated seeks (arrow keys, D-pad, gamepad shoulder buttons, double-taps) are merged: the first goes at once and the final position follows the moment you stop, instead of a full rebuffer for every press.
- **The seek bar follows your seek at once** â€“ The scrubber and the clock move to where you sent playback straight away, instead of waiting for the stream to get there.
- **Clearer source status** â€“ Sources that are not a video, or that cannot seek, are labelled in the Sources list, and resuming prefers a source that can seek.
- **Half the memory for the network buffer** â€“ libVLC's read-ahead buffer was being allocated twice; the buffer size you choose is now the memory it uses.

#### ðŸ’¬ Subtitles
- **Subtitle search in the player panel** â€“ Online subtitle search opens as a page inside the player's side panel.
- **Subtitle files drawn by Aether** â€“ SRT, WebVTT (including HLS subtitle playlists) and SSA/ASS files are drawn over the video by the app, so Zoom and Stretch no longer push lines off screen, and files that need the source's headers now load.
- **The right file from season packs** â€“ When a provider sends a whole season as one archive, the episode being watched, in the language asked for, is picked instead of the first file in it.
- **Automatic subtitle language** â€“ Auto picks a subtitle in your preferred language from the video's own tracks, however the source names the language.
- **Embedded subtitles with Zoom and Stretch** â€“ Subtitles inside the video stay on screen whichever fit is chosen.

#### ðŸ“º TV & Navigation
- **D-pad text entry** â€“ Text fields no longer steal D-pad directions, so TV keyboards keep all four arrows for picking letters.
- **Back exits from Home** â€“ Back on the home screen now leaves the app instead of doing nothing.
- **Focus rings follow the input** â€“ Focus highlights show when you use a keyboard, remote or gamepad, and stay out of the way on touch.
- **Clear of the bottom bar** â€“ Lists on every screen, settings pages and bookmarks included, scroll clear of the floating bottom navigation.

#### âš™ï¸ Settings & Extensions
- **Extensions update on launch** â€“ Aether plugins, Nuvio scrapers and Stremio add-ons are checked on every launch; followed collections add the repositories they newly list, and what changed is summed up in at most three toasts.
- **TMDB API key check** â€“ A pasted key is cleaned of spaces and invisible characters, pasting TMDB's v4 read token instead of the key is explained, and a network problem is no longer reported as a wrong key.
- **External player** â€“ The chosen default player is honoured end to end, including request headers on Android.

---

### ðŸž *Bug Fixes & System Stability*
- ðŸ› ï¸ **Fixed: resuming could open to a black screen reading "LIVE"** â€“ Happened when a different source was picked while the resume was still opening.
- ðŸ› ï¸ **Fixed: some HLS episodes read 27:46:39** â€“ The seek bar, the next-episode card and the end of the episode now use the video's real length.
- ðŸ› ï¸ **Fixed: "Reconnectingâ€¦" after seeking** â€“ A slow refill after a seek is no longer taken for a dead connection, and the recovery step re-issues your seek instead of jumping back to where you were.
- ðŸ› ï¸ **Fixed: the buffered band on the seek bar** â€“ It no longer vanishes or jumps after a seek, and shows what is really buffered after seeking back.
- ðŸ› ï¸ **Fixed: Discover stayed empty for hours after a single network error.**
- ðŸ› ï¸ **Fixed: slow stream add-ons timed out mid-scrape.**


### âš™ï¸ Improvements
- ðŸš€ The Riverpod lint rules now run as a reliable CI gate.
- ðŸš€ Various performance improvements and stability fixes across the app.

# Changelog

## v2.2.1
- Fixed genre-filtered Explore returning one result (movie/TV genre-id translation)
- Fixed endless Explore pagination; shelves stop when a page adds nothing new
- Fixed recommendation shelves ignoring the Explore genre filter
- Fixed subtitle User-Agent version drift (now derived from app version)
- Added Netflix-style maturity badge (18+/16+/13+/7+/All) at playback start
- Added per-profile maturity ceiling with PIN override; kids default to 13+
- Added My List rail on Home under Continue Watching; offline banner on Home/Explore
- Security: plaintext PINs migrated to PBKDF2 at rest; embedded TMDB API key removed

## v2.2.0
- Unified Ecosystem Architecture v2.2.0; profile avatars overhaul
- Endless Explore; robust network fallbacks; god-file modularization

## v2.0.0 - v2.0.3
- Torrent-to-HLS fallback engine (Virtual Debrid)
- Aether Discovery Intelligence (ADI) recommendation engine
- Netflix-style profile onboarding; true OLED dark theme
- Player smoothing, subtitle panel search, TV navigation, add-on health badges

## v2.8.1
- Stremio add-ons and Nuvio support; Quick Install and Discover tab
- Smoother seeking; seek bar follows immediately; player buffer memory halved
- Subtitle panel search; SRT/WebVTT/SSA/ASS support; auto subtitle language
- TV navigation: D-pad text entry, back exits home, focus rings
- Extensions auto-update on launch; TMDB API key validation

## v1.0.8 - v1.0.10
- Early stable builds: core playback, profiles, subtitle engine

## v1.0.0
- Initial release
# Aether 🌌

<div align="center">

**Next-Generation Universal Media Experience. Limitless. Unmetered. Celestial.**

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-6366F1?style=for-the-badge)](#)
[![Flutter](https://img.shields.io/badge/Built%20With-Flutter%203.29-02569B?style=for-the-badge&logo=flutter)](#)
[![License](https://img.shields.io/badge/License-GPLv3-10B981?style=for-the-badge)](#)
[![Stream Engine](https://img.shields.io/badge/Player-MediaKit%20%2F%20Direct3D%2011-EC4899?style=for-the-badge)](#)

</div>

---

## 🌟 Highlights

- **👤 Multi-User Profiles** — Netflix-style "Who's Watching?": per-profile avatar, history, recommendations, and PIN lock.
- **🎬 Personalized Discovery** — "Because You Watched…" shelves and explore carousels from a real recommendation engine.
- **💬 Universal Subtitles** — keyless, zero-setup, multi-language, out of the box.
- **🌌 Celestial Backdrops** — OLED-friendly ambient scenes (Nebula, Black Hole, Starfield, Obsidian Void).
- **⚡ Offline Buffer Saver** — save a fully buffered video to `Downloads/Aether/` in one tap.
- **🚀 Debrid-Grade Streaming** — multi-connection segment prefetch for saturated bandwidth and instant seeks.

---

## 📥 Download

Prebuilt releases for **Android (phones + Android TV)** and **Windows** are on the [Releases page](https://github.com/justinx2022/aether/releases). Changelog per version lives in [CHANGELOG.md](CHANGELOG.md).

---

## 🛠️ Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.29+
- Android SDK 34+ / NDK 27.0.12077973 (for Android targets)
- Visual Studio 2022 C++ Tools (for Windows desktop builds)

### Building from Source

```bash
git clone https://github.com/justinx2022/aether.git
cd aether
flutter pub get

flutter run -d windows   # or: flutter run -d android
```

### Building Release Packages

```bash
# Android APK (arm64-v8a)
flutter build apk --target-platform android-arm64 --release

# Windows Executable
flutter build windows --release
```

---

## 🛡️ Architecture & Core Components

```
lib/
├── core/
│   ├── profile/            # User profile models, avatars, and PIN service
│   ├── recommendations/    # Smart "Because you watched" recommendation engine
│   ├── services/           # LocalProxyService, BufferSaver, and Prefetch booster
│   └── theme/              # Celestial space backdrops and dynamic palette engine
├── features/
│   ├── home/               # Netflix-style shelves and "Because you watched" rows
│   ├── profile/            # "Who's Watching?" cold-launch screen and profile switcher
│   ├── player/             # MediaKit libmpv direct GPU player and subtitle pipeline
│   └── extensions/         # Justin's Catalogue pre-seed and extension runtime
```

---

## 📜 License

This project is licensed under the GNU General Public License v3.0.

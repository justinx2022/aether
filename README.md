# Aether 🌌

<div align="center">

```
     █████╗ ███████╗████████╗██╗  ██╗███████╗██████╗ 
    ██╔══██╗██╔════╝╚══██╔══╝██║  ██║██╔════╝██╔══██╗
    ███████║█████╗     ██║   ███████║█████╗  ██████╔╝
    ██╔══██║██╔══╝     ██║   ██╔══██║██╔══╝  ██╔══██╗
    ██║  ██║███████╗   ██║   ██║  ██║███████╗██║  ██║
    ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

**Next-Generation Universal Media Experience. Limitless. Unmetered. Celestial.**

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-6366F1?style=for-the-badge)](#)
[![Flutter](https://img.shields.io/badge/Built%20With-Flutter%203.29-02569B?style=for-the-badge&logo=flutter)](#)
[![License](https://img.shields.io/badge/License-GPLv3-10B981?style=for-the-badge)](#)
[![Stream Engine](https://img.shields.io/badge/Player-MediaKit%20%2F%20Direct3D%2011-EC4899?style=for-the-badge)](#)

</div>

---

## 🌟 Highlights

- **👤 Multi-User Profiles ("Who's Watching?")**  
  True Netflix-style profile management. Every family member gets their own customized avatar, isolated watch history, personalized recommendations, and optional security PIN lock.

- **🎬 Personalized Discovery ("Because You Watched...")**  
  Deep recommendation algorithm inspired by top streaming services. Generates dynamic shelves on your home dashboard and "More Like This" explore carousels based on what you actually watch.

- **💬 Universal Subtitle Engine**  
  Keyless, zero-setup multi-language subtitles out of the box. Automatically discovers and synchronizes verified UTF-8 subtitle tracks for movies and TV series across dozens of languages.

- **🌌 Celestial Atmosphere Engine**  
  Immersive space-oriented ambient backdrops designed for OLED and high-refresh displays:
  - **Nebula**: Deep cosmic gas clouds with rich violet and cyan star dust.
  - **Black Hole**: Luminous event horizon accretion disk glow against infinite void.
  - **Deep Starfield**: Dense stellar clusters with crystalline parallax drift.
  - **Obsidian Void**: True OLED deep black with minimal stellar shimmer.

- **⚡ Offline Buffer Saver**  
  Watch without wasting bandwidth. If a video is fully buffered, save it directly to your device's `Downloads/Aether/` directory in one tap without re-downloading.

- **🚀 Debrid-Grade Multi-Connection Engine**  
  Multi-connection parallel segment prefetching saturates bandwidth, eliminates buffering drops, and delivers instant seek response times.

---

## 📱 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.29+
- Android SDK 34+ / NDK 27.0.12077973 (for Android targets)
- Visual Studio 2022 C++ Tools (for Windows desktop builds)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/aether-streaming/aether.git
cd aether

# Get dependencies
flutter pub get

# Run on your connected device or emulator
flutter run -d windows
# or for Android:
flutter run -d android
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
│   ├── monetization/       # Seamless pass controller and sandbox frameworks
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

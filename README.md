# FTPlayer

<div align="center">
  <img src="https://raw.githubusercontent.com/ShariarShuvo1/ftplayer/main/assets/app_logo.png" alt="FTPlayer Logo" width="150" height="150">
</div>

A high-performance Flutter video streaming application that aggregates content from multiple ISP-provided FTP servers in Bangladesh. FTPlayer provides seamless playback, intelligent caching, and offline download capabilities across multiple video providers.

## ⚠️ Disclaimer

**This project is for educational and learning purposes only. This project is NOT intended to support or facilitate piracy.**

## Features

- **Multi-Server Support**: Aggregate content from CircleFTP, Dflix, and AmaderFTP simultaneously
- **Intelligent Server Selection**: Automatic availability detection and user-controlled server preferences
- **Advanced Video Playback**: Built on media_kit with gesture controls, playback speed, and Picture-in-Picture mode
- **Download Management**: Queue downloads with pause/resume and persistent queue management
- **Watch History**: Automatic progress tracking and resume-from-position functionality
- **Offline Mode**: Full access to downloaded content when offline
- **Search Across Servers**: Unified search across all enabled providers
- **Adaptive Streaming**: Optimized buffer settings for low-bandwidth scenarios

## Supported Servers

1. **AmaderFTP** - Jellyfin/Emby protocol with token-based authentication
2. **CircleFTP** - REST API with rich content categorization
3. **Dflix** - JSON-based API with extensive library coverage

## Project Architecture

FTPlayer follows a three-layer feature-based architecture:

### Core Structure

```
lib/src/
├── app/                    # App configuration & routing
│   ├── theme/             # UI theme and colors
│   └── router.dart        # go_router navigation setup
├── core/                   # Shared services and utilities
│   ├── services/          # Singletons (notifications, downloads, player)
│   ├── storage/           # Hive and secure storage wrappers
│   ├── network/           # HTTP client and network optimization
│   └── widgets/           # Reusable UI components
├── features/              # Feature modules (independent, scalable)
│   └── {feature}/
│       ├── presentation/  # UI screens and widgets
│       └── data/          # Models, DTOs, API integration
└── state/                 # Riverpod providers (business logic)
    └── {feature}/
```

### State Management

**Riverpod-First Architecture**: All business logic lives in providers located in `lib/src/state/`. Screens remain stateless, containing only ephemeral UI state (form inputs, animations, scroll positions).

### Multi-Server Content Aggregation

1. **Server Definition**: Static list in `ftp_servers_local_data.dart` with type, ping URL, and priority
2. **Availability Check**: First-launch auto-detection pings all servers → stores results in Hive
3. **User Preferences**: Enable/disable servers per user → updates enabled servers provider
4. **Content Fetch**: Queries all working servers in parallel → interleaves results for balanced feed
5. **Results Caching**: Hive persistence for server status and user preferences

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart 3.0+
- Android SDK 21+
- Java 11+ for Android builds

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/ShariarShuvo1/ftplayer.git
   cd ftplayer
   ```
2. **Install dependencies**

   ```bash
   flutter pub get
   ```

### Building

#### Android

```bash
flutter build apk                 # APK for direct installation
```

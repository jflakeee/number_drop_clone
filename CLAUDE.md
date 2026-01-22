# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Number Drop Clone - A Flutter implementation of "Drop The Number: Merge Puzzle" game. Players drop numbered blocks into a 5x8 grid where adjacent same-value blocks merge (2+2=4, 4+4=8, etc.).

## Development Commands

All commands run from the `app/` directory:

```bash
# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run code analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build web
flutter build web

# Build web for GitHub Pages (with base-href)
flutter build web --release --base-href "/number_drop_clone/"

# Build Android APK (requires Android SDK)
flutter build apk --release
```

## CI/CD

GitHub Actions workflow (`.github/workflows/deploy.yml`) automatically deploys to GitHub Pages on push to `main`.

## Architecture

### State Management
- **Provider** with `ChangeNotifier` pattern
- `GameState` in `lib/models/game_state.dart` is the central state holder
- Wrap widgets with `Consumer<GameState>` to access game state

### Core Game Logic
The merge algorithm uses BFS to find adjacent blocks with the same value:
- `dropBlock(column)` - drops current block into specified column
- `_checkAndMerge()` - finds and merges adjacent same-value blocks using BFS (`_findAdjacentSame`)
- `_applyGravity()` - moves blocks down after merges

Block generation uses weighted random: `[40, 30, 15, 10, 4, 1]` for values `[2, 4, 8, 16, 32, 64]`.

### Animation System
Merge animations use `MergeAnimationData` to track block movements:
- Regular merges: blocks move toward target position
- Below-block merges: blocks move up halfway then disappear
- `AnimatedGameBoard` handles rendering during merge animations

### Service Singletons
All services use singleton pattern with lazy initialization:
- `StorageService.instance` - SharedPreferences persistence
- `AudioService.instance` - Sound effects and BGM
- `VibrationService.instance` - Haptic feedback
- `AdService.instance` - Google AdMob (skips on web)
- `IAPService.instance` - In-app purchases (skips on web)

### Platform Handling
Ad and IAP services check `kIsWeb` and skip initialization on web platform since these are mobile-only features.

## Key Constants

Located in `lib/config/constants.dart`:
- Grid: 5 columns x 8 rows
- Drop values: [2, 4, 8, 16, 32, 64] with weighted random
- Hammer cost: 100 coins
- Ad reward: 100-120 coins

## Block Colors

Defined in `lib/config/colors.dart` - each power of 2 has a distinct color from pink (2) to gold (2048).

## Production Deployment

Replace test IDs before release:
- `ad_service.dart`: AdMob ad unit IDs
- `AndroidManifest.xml`: AdMob app ID
- `iap_service.dart`: IAP product IDs must match Google Play Console

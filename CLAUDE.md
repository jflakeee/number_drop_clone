# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Number Drop Clone - A Flutter implementation of "Drop The Number: Merge Puzzle" game. Players drop numbered blocks into a 5x8 grid where adjacent same-value blocks merge (2+2=4, 4+4=8, etc.). Features real-time rankings and 1v1 battle mode via Firebase.

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

# Build web for GitHub Pages
flutter build web --release --base-href "/number_drop_clone/"

# Build Android APK
flutter build apk --release
```

## CI/CD

GitHub Actions (`.github/workflows/deploy.yml`) auto-deploys to GitHub Pages on push to `main`.

## Architecture

### State Management
- **Provider** with `ChangeNotifier` pattern
- `GameState` in `lib/models/game_state.dart` is the central state holder
- Wrap widgets with `Consumer<GameState>` to access game state

### Core Game Logic
The merge algorithm uses BFS to find adjacent blocks with the same value:
- `dropBlock(column)` - drops current block into specified column
- `_checkAndMerge()` - finds and merges adjacent same-value blocks using BFS
- `_applyGravity()` - moves blocks down after merges
- Seed-based random: `gameSeed` property allows reproducible block sequences

### Service Singletons
All services use singleton pattern with lazy initialization:
- `StorageService.instance` - SharedPreferences persistence
- `AudioService.instance` - Sound effects and BGM
- `VibrationService.instance` - Haptic feedback
- `AdService.instance` - Google AdMob (skips on web)
- `IAPService.instance` - In-app purchases (skips on web)
- `AuthService.instance` - Firebase Auth (anonymous + Google)
- `RankingService.instance` - Firestore rankings
- `BattleService.instance` - 1v1 battle management
- `OfflineQueueService.instance` - Offline score queue

### Firebase Integration

**Authentication** (`auth_service.dart`):
- Auto anonymous sign-in on app start
- Google Sign-In for profile customization
- Account linking (anonymous → Google)

**Firestore Collections**:
- `/rankings/{userId}` - User's highest score (one document per user)
- `/users/{userId}` - User profile (custom nickname)
- `/battles/{battleId}` - Battle room data

**Realtime Database**:
- `/live_battles/{battleId}/{userId}` - Real-time score sync during battles

**Security Rules**: Located in `firebase/` directory

### Battle System
1v1 same-seed competition via `BattleService`:
- `findOrCreateBattle()` - Auto matchmaking
- `watchLiveScores()` - Real-time opponent score (Realtime DB)
- `finishGame()` - Submit final score, determine winner

Flow: Main Menu → BATTLE → MatchmakingScreen → BattleScreen

### Audio System
Platform-specific due to `audioplayers` web compatibility:
- **Web**: `dart:html` AudioElement (`web_audio_impl.dart`)
- **Mobile**: `audioplayers` package

Conditional import:
```dart
import 'web_audio_stub.dart' if (dart.library.html) 'web_audio_impl.dart' as web_audio;
```

Audio files must exist in both:
- `assets/audio/` (mobile)
- `web/assets/audio/` (web)

### Animation System
`MergeAnimationData` tracks block movements:
- Regular merges: blocks move toward target
- Below-block merges: blocks move up halfway then disappear
- `AnimatedGameBoard` handles rendering during animations

## Key Constants

`lib/config/constants.dart`:
- Grid: 5 columns × 8 rows
- Drop values: [2, 4, 8, 16, 32, 64] with weights [40, 30, 15, 10, 4, 1]
- Hammer cost: 100 coins

## Firebase Setup Notes

Required Firestore indexes for daily/weekly rankings:
- Collection: `rankings`, Fields: `updatedAt` (DESC), `score` (DESC)

Firebase config: `lib/firebase_options.dart` (includes `databaseURL` for Realtime DB)

## Production Deployment

Replace test IDs before release:
- `ad_service.dart`: AdMob ad unit IDs
- `AndroidManifest.xml`: AdMob app ID
- `iap_service.dart`: IAP product IDs

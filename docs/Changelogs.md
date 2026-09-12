# Changelog

All notable changes to Seek Player are listed here, newest version first.
Versions match git tags (`X.Y.Z`).

## 1.2.12 — 2026-09-12

Changes since `v1.2.11` (2026-08-09).

### Lyrics
- Track job status with `LyricsJobStage` and a dedicated provider.
- Alert with sound and vibration when a lyrics task fails.
- Separate Firestore paths for lyrics backup and sync.
- Simplify `trackLyricsProvider` by removing remote fetch logic.
- Standardize lyrics colors and text styles in the player.

### Cloud backup & sync
- Firestore-based sync for settings, playlists, statistics and lyrics.
- `UserRecordService` logs user settings and app version to Firestore.

### Profile
- Refactor profile page and reorder.
- Add feedback option.
- Add "reset app data" action.

### Player
- Customizable seek step setting.
- Customizable default tab for the player screen.
- Scrollable bottom sheets to prevent menu overflow.

### Playlists & local music
- iOS: import local music files into the library.
- Local music: empty-state view and UI consistency fixes.
- Track count now reflects synced playlist tracks only.

### Platform & UI
- Open audio files via deep link from other apps.
- Edge-to-edge layout with transparent system bars for all themes.
- Cover color normalization.
- Custom SVG search icon.
- Disable default focus highlight on Android 8+ (green FlutterView border).
- `SafeRootBackButtonDispatcher` for unparsed route back events.

### Internal
- Consolidate debug logging into `reportError`.
- Unit tests for cover color normalization and extraction.
- Remove `receive_sharing_intent`.

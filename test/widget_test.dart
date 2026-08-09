import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seek_player/app.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/models/track.dart';

/// 測試用音樂庫：不觸碰裝置 MediaStore，回傳空清單。
class _FakeMusicLibrary extends MusicLibrary {
  @override
  Future<List<Track>> build() async => const [];
}

void main() {
  testWidgets('App boots to the playlists tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefs),
          musicLibraryProvider.overrideWith(_FakeMusicLibrary.new),
        ],
        child: const SeekPlayerApp(),
      ),
    );
    await tester.pump();

    // 預設語系 en：底部導覽只剩播放清單與個人兩個分頁
    // （播放器已改為 mini player + sheet；音樂清單分頁已併入播放清單的「本地音樂」）。
    expect(find.text('Playlists'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Player'), findsNothing);
    expect(find.text('Music'), findsNothing);
  });
}

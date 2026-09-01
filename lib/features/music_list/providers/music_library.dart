import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seek_player/features/cover/services/cover_import_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library_source_provider.dart';

/// 本機音樂庫:掃描來源依平台(musicLibrarySourceProvider),
/// Android 掃 MediaStore、iOS 掃 app Documents;曲目清單不落地資料庫,
/// 每次即時掃描。來源檔被刪除/移走後,重新掃描即不再出現(屬預期)。
class MusicLibrary extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    // build 不主動彈權限對話框;已授權才掃描,否則回空清單,
    // 待使用者於列表頁透過 refresh() 觸發授權流程。
    // iOS 掃自家沙盒,無需權限,一律直接掃。
    if (Platform.isIOS || await Permission.audio.isGranted) {
      final tracks = await _scan();
      _backfillCoverColors();
      return tracks;
    }
    return const [];
  }

  Future<List<Track>> _scan() => ref.read(musicLibrarySourceProvider).scan();

  /// 重新掃描音樂庫(權限應由呼叫端先確保)。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_scan);
    if (state.hasValue) _backfillCoverColors();
  }

  /// 載入音樂後,背景補算既有封面尚未快取的主色(fire-and-forget,
  /// 不阻塞清單)。避免播放頁切歌時才即時解析封面圖造成卡頓。
  void _backfillCoverColors() {
    unawaited(ref.read(coverImportServiceProvider).backfillMissingColors());
  }
}

final musicLibraryProvider = AsyncNotifierProvider<MusicLibrary, List<Track>>(
  MusicLibrary.new,
);

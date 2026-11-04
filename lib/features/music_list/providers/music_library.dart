import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seek_player/core/storage/track_entity_migration.dart';
import 'package:seek_player/features/cover/services/cover_import_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library_source_provider.dart';

/// 本機音樂庫:掃描 MediaStore(musicLibrarySourceProvider);每次即時掃描,掃到的檔案
/// 同時 upsert 成 TrackEntity。來源檔被刪除/移走後,重新掃描即不再出現在
/// 曲庫(屬預期),但 TrackEntity 保留。
///
/// 狀態只在整次掃描完成後更新一次,掃描過程中不逐筆觸發 UI 重建。
class MusicLibrary extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    // build 不主動彈權限對話框;已授權才掃描,否則回空清單,
    // 待使用者於列表頁透過 refresh() 觸發授權流程。
    if (await Permission.audio.isGranted) {
      final tracks = await _scan();
      _backfillCoverColors();
      return tracks;
    }
    return const [];
  }

  /// 掃描前先等一次性的 TrackEntity 遷移結束(一進 app 由
  /// TrackEntityMigrationGate 觸發,這裡共用同一次執行;已完成則立即返回)。
  /// 確保曲庫與等曲庫就緒的同步一定在遷移之後;進 app 時沒權限、之後才授權
  /// 的情況也由這裡補跑遷移。
  Future<List<Track>> _scan() async {
    await ref.read(trackEntityMigrationProvider.notifier).runIfNeeded();
    return ref.read(musicLibrarySourceProvider).scan();
  }

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

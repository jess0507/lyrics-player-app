import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';

const _kPendingSyncJobs = 'lyrics.pendingSyncJobs';

/// 一筆待同步紀錄:[mode] 供終態通知挑選文案(產生 / 對時各異),[title] 為
/// 歌曲名稱,通知列標題要用,不必額外查本機資料庫。
class LyricsPendingSyncJob {
  const LyricsPendingSyncJob({required this.mode, required this.title});

  final LyricsBackgroundMode mode;
  final String title;

  Map<String, Object?> toJson() => {'mode': mode.name, 'title': title};

  factory LyricsPendingSyncJob.fromJson(Map<String, dynamic> json) =>
      LyricsPendingSyncJob(
        mode: LyricsBackgroundMode.values.byName(json['mode'] as String),
        title: json['title'] as String,
      );
}

/// 本地端持久化的「已送出背景處理、Firestore 尚未回終態」trackId 清單,
/// 存 SharedPreferences,跨 app 重啟存活。`LyricsAutoGenerateController` /
/// `LyricsAutoSyncController` 的 `run()` 在 main isolate 呼叫實際的
/// generate/align 之前就先呼叫 [add](未成功送出則自行呼叫 [remove] 復原),
/// 讓 `LyricsPendingSyncService` 能立刻開始監聽,不需背景 isolate(Android
/// 前景服務)另外回報。`LyricsPendingSyncService`(見同目錄)監聽各 trackId
/// 的 Firestore 工作狀態,轉終態(done / failed)後依 [LyricsPendingSyncJob]
/// 發最終確認通知,再呼叫 [remove]。
///
/// 與 [lyricsBackgroundRunningProvider](記憶體、session-only,foreground
/// service 本身跑多久)用途不同——這裡是「本機還欠同步的 trackId」,
/// 就算 app 被殺掉重開也不會遺失追蹤。
class LyricsPendingSyncStore extends Notifier<Map<String, LyricsPendingSyncJob>> {
  @override
  Map<String, LyricsPendingSyncJob> build() {
    final raw = ref.read(preferencesServiceProvider).getString(_kPendingSyncJobs);
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (trackId, job) => MapEntry(
        trackId,
        LyricsPendingSyncJob.fromJson(job as Map<String, dynamic>),
      ),
    );
  }

  Future<void> add(String trackId, LyricsPendingSyncJob job) async {
    if (state.containsKey(trackId)) return;
    state = {...state, trackId: job};
    await _persist();
  }

  Future<void> remove(String trackId) async {
    if (!state.containsKey(trackId)) return;
    state = {...state}..remove(trackId);
    await _persist();
  }

  Future<void> _persist() => ref
      .read(preferencesServiceProvider)
      .setString(
        _kPendingSyncJobs,
        jsonEncode(state.map((trackId, job) => MapEntry(trackId, job.toJson()))),
      );
}

final lyricsPendingSyncStoreProvider =
    NotifierProvider<LyricsPendingSyncStore, Map<String, LyricsPendingSyncJob>>(
      LyricsPendingSyncStore.new,
    );

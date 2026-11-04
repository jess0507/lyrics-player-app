import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';

const _kPendingSyncJobs = 'lyrics.pendingSyncJobs';

/// 一筆待同步紀錄:[jobId] 為後端任務文件 id(`user/{uid}/lyrics/{jobId}`),
/// [mode] 供終態通知挑選文案(產生 / 對時各異),[title] 為歌曲名稱,
/// 通知列標題要用,不必額外查本機資料庫。
class LyricsPendingSyncJob {
  const LyricsPendingSyncJob({
    required this.jobId,
    required this.mode,
    required this.title,
  });

  final String jobId;
  final LyricsBackgroundMode mode;
  final String title;

  Map<String, Object?> toJson() => {
    'jobId': jobId,
    'mode': mode.name,
    'title': title,
  };

  /// 舊版紀錄沒有 jobId:當時任務文件 id 就是 pathKey([legacyJobId])。
  factory LyricsPendingSyncJob.fromJson(
    Map<String, dynamic> json, {
    required String legacyJobId,
  }) => LyricsPendingSyncJob(
    jobId: (json['jobId'] as String?) ?? legacyJobId,
    mode: LyricsBackgroundMode.values.byName(json['mode'] as String),
    title: json['title'] as String,
  );
}

/// 本地端持久化的「已送出背景處理、Firestore 尚未回終態」清單(pathKey →
/// [LyricsPendingSyncJob]),
/// 存 SharedPreferences,跨 app 重啟存活。`LyricsAutoGenerateController` /
/// `LyricsAutoAlignController` 的 `run()` 在 main isolate 呼叫實際的
/// generate/align 之前就先呼叫 [add](未成功送出則自行呼叫 [remove] 復原),
/// 讓 `LyricsPendingSyncService` 能立刻開始監聽,不需背景 isolate(Android
/// 前景服務)另外回報。`LyricsPendingSyncService`(見同目錄)監聽各 pathKey
/// 的 Firestore 工作狀態,轉終態(done / failed)後依 [LyricsPendingSyncJob]
/// 發最終確認通知,再呼叫 [remove]。
///
/// 與 [lyricsBackgroundRunningProvider](記憶體、session-only,foreground
/// service 本身跑多久)用途不同——這裡是「本機還欠同步的 pathKey」,
/// 就算 app 被殺掉重開也不會遺失追蹤。
class LyricsPendingSyncStore
    extends Notifier<Map<String, LyricsPendingSyncJob>> {
  @override
  Map<String, LyricsPendingSyncJob> build() {
    final raw = ref
        .read(preferencesServiceProvider)
        .getString(_kPendingSyncJobs);
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (pathKey, job) => MapEntry(
        pathKey,
        LyricsPendingSyncJob.fromJson(
          job as Map<String, dynamic>,
          legacyJobId: pathKey,
        ),
      ),
    );
  }

  Future<void> add(String pathKey, LyricsPendingSyncJob job) async {
    if (state.containsKey(pathKey)) return;
    state = {...state, pathKey: job};
    await _persist();
  }

  Future<void> remove(String pathKey) async {
    if (!state.containsKey(pathKey)) return;
    state = {...state}..remove(pathKey);
    await _persist();
  }

  /// 一次性遷移(TrackEntityMigration):把 key 從 legacy id(sha1 指紋 /
  /// MediaStore 數字 id)改寫成 pathKey。[toPathKey] 回 null 的紀錄直接移除
  /// (對不到本機曲目,結果也無處寫回)。jobId 不變,LyricsPendingSyncService
  /// 會以新的 key 重新監聽同一份任務文件。
  Future<void> remapToPathKeys(
    String? Function(String legacyId) toPathKey,
  ) async {
    final next = <String, LyricsPendingSyncJob>{};
    for (final MapEntry(key: legacyId, value: job) in state.entries) {
      final pathKey = toPathKey(legacyId);
      if (pathKey != null) next[pathKey] = job;
    }
    state = next;
    await _persist();
  }

  Future<void> _persist() => ref
      .read(preferencesServiceProvider)
      .setString(
        _kPendingSyncJobs,
        jsonEncode(
          state.map((pathKey, job) => MapEntry(pathKey, job.toJson())),
        ),
      );
}

final lyricsPendingSyncStoreProvider =
    NotifierProvider<LyricsPendingSyncStore, Map<String, LyricsPendingSyncJob>>(
      LyricsPendingSyncStore.new,
    );

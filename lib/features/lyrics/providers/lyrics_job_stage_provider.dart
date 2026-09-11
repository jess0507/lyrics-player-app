import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_controller.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_service.dart';
import 'package:seek_player/features/lyrics/auto_sync/lyrics_auto_sync_controller.dart';
import 'package:seek_player/features/lyrics/auto_sync/lyrics_auto_sync_service.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';
import 'package:seek_player/features/lyrics/models/lyrics_job_stage.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';

/// 某 trackId 目前歌詞任務的階段([LyricsJobStage]),與通知列的文字
/// 生命週期對齊:
/// - 產生 / 對時 controller 執行中 → 依其 `step`(壓縮 / 上傳 / 產生或對齊);
/// - controller 已結束(callable 已送出)但 [lyricsPendingSyncStoreProvider]
///   還有這筆 → `requestSent`(通知列此時顯示「已發出請求」),含 app 重啟後
///   controller 狀態已不在、僅剩持久化紀錄的情況;
/// - 都沒有 → null(呼叫端自行給通用「處理中」文案,例如背景正在跑別首歌)。
/// 是否顯示處理中畫面仍由 `lyricsActiveJobProvider` 決定,本 provider 只
/// 負責文案。
final lyricsJobStageProvider = Provider.family<LyricsJobStage?, String>((
  ref,
  trackId,
) {
  final generate = ref.watch(lyricsAutoGenerateControllerProvider(trackId));
  if (generate.isRunning) {
    return switch (generate.step) {
      LyricsAutoGenerateStep.uploading => LyricsJobStage.generateUploading,
      LyricsAutoGenerateStep.transcribing =>
        LyricsJobStage.generateTranscribing,
      LyricsAutoGenerateStep.compressing ||
      null => LyricsJobStage.generateCompressing,
    };
  }
  final align = ref.watch(lyricsAutoSyncControllerProvider(trackId));
  if (align.isRunning) {
    return switch (align.step) {
      LyricsAutoSyncStep.uploading => LyricsJobStage.alignUploading,
      LyricsAutoSyncStep.aligning => LyricsJobStage.alignAligning,
      LyricsAutoSyncStep.compressing || null => LyricsJobStage.alignCompressing,
    };
  }
  final pending = ref.watch(
    lyricsPendingSyncStoreProvider.select((jobs) => jobs[trackId]?.mode),
  );
  return switch (pending) {
    LyricsBackgroundMode.generate => LyricsJobStage.generateRequestSent,
    LyricsBackgroundMode.align => LyricsJobStage.alignRequestSent,
    null => null,
  };
});

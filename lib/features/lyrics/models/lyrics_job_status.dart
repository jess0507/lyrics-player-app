/// Firestore `users/{uid}/lyrics/{trackId}` 文件的非同步處理狀態,對應
/// seek_player_backend/docs/error-codes.md 的狀態機與 error code。
enum LyricsJobPhase {
  queued,
  downloadingAudio,
  aligning,
  transcribing,
  saving,
  done,
  failed;

  bool get isTerminal => this == done || this == failed;

  static LyricsJobPhase? fromWire(String? value) => switch (value) {
    'queued' => LyricsJobPhase.queued,
    'downloading_audio' => LyricsJobPhase.downloadingAudio,
    'aligning' => LyricsJobPhase.aligning,
    'transcribing' => LyricsJobPhase.transcribing,
    'saving' => LyricsJobPhase.saving,
    'done' => LyricsJobPhase.done,
    'failed' => LyricsJobPhase.failed,
    _ => null,
  };
}

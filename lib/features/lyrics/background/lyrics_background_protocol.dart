import 'dart:convert';

/// 背景歌詞處理的跨 isolate / 跨語言協定:
/// - main isolate → native:以 [LyricsBackgroundRequest] JSON 由
///   `seek_player/lyrics_background_launcher` channel 啟動前景服務。
/// - native → 背景 isolate:服務把同一份 JSON 經
///   `seek_player/lyrics_background` channel 交給背景 isolate。
/// - 背景 isolate → main isolate:以 [LyricsBackgroundEvent] JSON 經
///   IsolateNameServer([lyricsBackgroundPortName])回報進度與結果。

/// main isolate 接收背景事件的 port 註冊名。
const lyricsBackgroundPortName = 'seek_player/lyrics_background_events';

/// MainActivity 上啟動 / 查詢前景服務的 channel。
const lyricsBackgroundLauncherChannelName =
    'seek_player/lyrics_background_launcher';

/// 前景服務與其背景 isolate 之間的 channel。
const lyricsBackgroundServiceChannelName = 'seek_player/lyrics_background';

/// 背景任務種類。
enum LyricsBackgroundMode { generate, align }

/// 一次背景任務的完整描述。通知列文字(各階段 / 取消鈕)由發起端先以
/// 當前 l10n 解析好帶入,背景 isolate 與 native 端不再各自處理在地化。
class LyricsBackgroundRequest {
  const LyricsBackgroundRequest({
    required this.mode,
    required this.trackId,
    required this.title,
    required this.stepLabels,
    required this.cancelLabel,
    required this.doneLabel,
    required this.failedLabel,
    this.language,
    this.engineName,
  });

  final LyricsBackgroundMode mode;
  final String trackId;
  final String title;

  /// step name(compressing / uploading / transcribing / aligning)→ 通知文字。
  final Map<String, String> stepLabels;

  /// 通知列取消按鈕文字。
  final String cancelLabel;

  /// 任務成功後的結果通知文字(例:已產生歌詞)。
  final String doneLabel;

  /// 任務失敗後的結果通知文字;取消不發結果通知。
  final String failedLabel;

  /// 對時語言提示(align 專用)。
  final String? language;

  /// 對齊引擎 wireName(align 專用)。
  final String? engineName;

  String toJsonString() => jsonEncode({
    'mode': mode.name,
    'trackId': trackId,
    'title': title,
    'stepLabels': stepLabels,
    'cancelLabel': cancelLabel,
    'doneLabel': doneLabel,
    'failedLabel': failedLabel,
    if (language != null) 'language': language,
    if (engineName != null) 'engineName': engineName,
  });

  factory LyricsBackgroundRequest.fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return LyricsBackgroundRequest(
      mode: LyricsBackgroundMode.values.byName(map['mode'] as String),
      trackId: map['trackId'] as String,
      title: map['title'] as String,
      stepLabels: (map['stepLabels'] as Map).cast<String, String>(),
      cancelLabel: map['cancelLabel'] as String,
      doneLabel: map['doneLabel'] as String,
      failedLabel: map['failedLabel'] as String,
      language: map['language'] as String?,
      engineName: map['engineName'] as String?,
    );
  }
}

/// 背景事件種類。
enum LyricsBackgroundEventType { step, done, error, cancelled }

/// 背景 isolate 回報給 main isolate 的事件。
class LyricsBackgroundEvent {
  const LyricsBackgroundEvent({
    required this.type,
    required this.mode,
    required this.trackId,
    this.stepName,
    this.errorName,
    this.activeTitle,
  });

  final LyricsBackgroundEventType type;
  final LyricsBackgroundMode mode;
  final String trackId;

  /// [LyricsBackgroundEventType.step] 時的階段名。
  final String? stepName;

  /// [LyricsBackgroundEventType.error] 時的錯誤 enum name。
  final String? errorName;

  /// [errorName] 為 busy(後端回報有別首歌正在處理中)時,該曲的曲名,
  /// 供訊息顯示;其餘情況為 null。
  final String? activeTitle;

  String toJsonString() => jsonEncode({
    'type': type.name,
    'mode': mode.name,
    'trackId': trackId,
    if (stepName != null) 'stepName': stepName,
    if (errorName != null) 'errorName': errorName,
    if (activeTitle != null) 'activeTitle': activeTitle,
  });

  factory LyricsBackgroundEvent.fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return LyricsBackgroundEvent(
      type: LyricsBackgroundEventType.values.byName(map['type'] as String),
      mode: LyricsBackgroundMode.values.byName(map['mode'] as String),
      trackId: map['trackId'] as String,
      stepName: map['stepName'] as String?,
      errorName: map['errorName'] as String?,
      activeTitle: map['activeTitle'] as String?,
    );
  }
}

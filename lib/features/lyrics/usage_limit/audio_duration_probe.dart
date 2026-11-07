import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// 量測歌詞雲端任務(自動產生 / 自動對時)要送出的音訊長度,供執行前比對
/// 本月剩餘額度,並隨 callable 送給後端(`durationSeconds`)提早擋下。
///
/// 以 ffprobe 量實際檔案為準;量不到時退回媒體庫掃描時記下的
/// `TrackEntity.durationMs`;都沒有回 null(呼叫端只做「已用完」的檢查)。
/// 只是前端提早提示,權威檢查由後端量測實際上傳的音訊進行。
class AudioDurationProbe {
  AudioDurationProbe(this._ref);

  final Ref _ref;

  Future<double?> durationSeconds({
    required String trackId,
    required String audioPath,
  }) async {
    try {
      final session = await FFprobeKit.getMediaInformation(audioPath);
      final raw = session.getMediaInformation()?.getDuration();
      final seconds = raw == null ? null : double.tryParse(raw);
      if (seconds != null && seconds > 0) return seconds;
    } catch (e, s) {
      reportError(e, s, reason: '量測歌詞任務音訊長度失敗,改用媒體庫長度');
    }

    final durationMs = _ref
        .read(trackRepositoryProvider)
        .findByTrackId(trackId)
        ?.durationMs;
    if (durationMs != null && durationMs > 0) return durationMs / 1000;
    return null;
  }
}

final audioDurationProbeProvider = Provider<AudioDurationProbe>(
  AudioDurationProbe.new,
);

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// 壓縮音訊失敗(ffmpeg 非零退出 / 輸出為空)。[log] 為 ffmpeg 輸出,供除錯。
class AudioCompressException implements Exception {
  const AudioCompressException([this.log]);

  final String? log;
}

/// 把任意本機音訊壓成 forced alignment 夠用的「單聲道 16kHz」小檔,
/// 大幅降低上傳量與後端解碼成本(對齊只需語音,不需立體聲 / 高取樣)。
///
/// 輸出 AAC / m4a:各平台 ffmpeg 內建 aac 編碼器,相容性最高;opus 需特定
/// 建置,故不採用(見 plans/lyrics-auto-sync-aeneas.md 的決策)。
class AudioCompressor {
  const AudioCompressor();

  /// 壓縮 [sourcePath] 並回傳暫存輸出檔(呼叫端用畢應自行刪除)。
  Future<File> compressForAlignment(String sourcePath) async {
    final dir = await getTemporaryDirectory();
    final out =
        '${dir.path}/align_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i', sourcePath,
      '-vn', // 丟棄封面 / 影像軌
      '-ac', '1', // 單聲道
      '-ar', '16000', // 16kHz
      '-c:a', 'aac',
      '-b:a', '32k',
      out,
    ]);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw AudioCompressException(await session.getAllLogsAsString());
    }
    final file = File(out);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const AudioCompressException('輸出檔為空');
    }
    return file;
  }
}

final audioCompressorProvider = Provider<AudioCompressor>(
  (ref) => const AudioCompressor(),
);

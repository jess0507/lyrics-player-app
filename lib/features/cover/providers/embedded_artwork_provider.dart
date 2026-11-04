import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:seek_player/features/cover/services/embedded_artwork_cache.dart';
import 'package:seek_player/features/lyrics/services/track_audio_resolver.dart';

/// 依 pathKey 取音檔內嵌封面(ID3 等 tag 內的圖)。
///
/// 以 [trackAudioResolverProvider] 由 pathKey查出檔案路徑,再以
/// ffmpeg 抽出封面軌,輸出快取在暫存目錄(以 pathKey 為 key,重啟後仍可
/// 沿用)。查無內嵌圖皆回 null,由上層退回佔位圖。
/// 檔案內容不會變動,family 天然快取即可,無需失效機制。
final embeddedArtworkProvider = FutureProvider.family<Uint8List?, String>(
  _extractWithFfmpeg,
);

Future<Uint8List?> _extractWithFfmpeg(Ref ref, String pathKey) async {
  final out = embeddedArtworkCacheFile(await getTemporaryDirectory(), pathKey);
  if (out.existsSync() && out.lengthSync() > 0) return out.readAsBytes();

  final path = await ref.read(trackAudioResolverProvider).resolve(pathKey);
  if (path == null) return null;

  // 封面在容器內是一條影像軌;重編成 mjpeg 單張輸出(直接 copy 會因
  // png/jpeg 來源不一與 .jpg muxer 打架)。無封面軌時 ffmpeg 非零退出。
  final session = await FFmpegKit.executeWithArguments([
    '-y',
    '-i',
    path,
    '-an',
    '-frames:v',
    '1',
    '-q:v',
    '3',
    out.path,
  ]);
  final rc = await session.getReturnCode();
  if (!ReturnCode.isSuccess(rc) || !out.existsSync() || out.lengthSync() == 0) {
    return null;
  }
  return out.readAsBytes();
}

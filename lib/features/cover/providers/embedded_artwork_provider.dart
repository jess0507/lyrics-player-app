import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import 'package:seek_player/features/lyrics/services/track_audio_resolver.dart';

/// 依 trackId 取音檔內嵌封面(ID3 等 tag 內的圖)。
/// Android 走 MediaStore 的 queryArtwork(id 非 MediaStore 數字 id 回 null);
/// iOS 沒有 MediaStore,解析出檔案路徑後以 ffmpeg 抽出封面軌,
/// 輸出快取在暫存目錄(以 trackId 為 key,重啟後仍可沿用)。
/// 查無內嵌圖皆回 null,由上層退回佔位圖。
/// 檔案內容不會變動,family 天然快取即可,無需失效機制。
final embeddedArtworkProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  trackId,
) async {
  if (Platform.isIOS) return _extractWithFfmpeg(ref, trackId);

  final id = int.tryParse(trackId);
  if (id == null) return null;
  return OnAudioQuery().queryArtwork(
    id,
    ArtworkType.AUDIO,
    format: ArtworkFormat.JPEG,
    size: 600,
  );
});

Future<Uint8List?> _extractWithFfmpeg(Ref ref, String trackId) async {
  // trackId 可能是 fallback 的檔案路徑(含 '/'),以 sha1 產生安全檔名。
  final cacheKey = sha1.convert(utf8.encode(trackId)).toString();
  final tmp = await getTemporaryDirectory();
  final out = File('${tmp.path}/embedded_artwork_$cacheKey.jpg');
  if (out.existsSync() && out.lengthSync() > 0) return out.readAsBytes();

  final path = await ref.read(trackAudioResolverProvider).resolve(trackId);
  if (path == null) return null;

  // 封面在容器內是一條影像軌;重編成 mjpeg 單張輸出(直接 copy 會因
  // png/jpeg 來源不一與 .jpg muxer 打架)。無封面軌時 ffmpeg 非零退出。
  final session = await FFmpegKit.executeWithArguments([
    '-y',
    '-i', path,
    '-an',
    '-frames:v', '1',
    '-q:v', '3',
    out.path,
  ]);
  final rc = await session.getReturnCode();
  if (!ReturnCode.isSuccess(rc) || !out.existsSync() || out.lengthSync() == 0) {
    return null;
  }
  return out.readAsBytes();
}

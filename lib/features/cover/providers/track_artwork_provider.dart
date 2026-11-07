import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/cover/providers/embedded_artwork_provider.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';

/// 曲目封面的統一入口:優先用使用者自訂封面([trackCoverProvider]),
/// 無自訂時退回音檔內嵌封面([embeddedArtworkProvider]),兩者皆無回 null,
/// 由 UI 顯示佔位圖。清單縮圖、播放頁、mini player 共用此回退鏈。
final trackArtworkProvider = FutureProvider.family<ImageProvider?, String>((
  ref,
  trackId,
) async {
  final file = await ref.watch(trackCoverProvider(trackId).future);
  if (file != null) return FileImage(file);
  final bytes = await ref.watch(embeddedArtworkProvider(trackId).future);
  return bytes == null ? null : MemoryImage(bytes);
});

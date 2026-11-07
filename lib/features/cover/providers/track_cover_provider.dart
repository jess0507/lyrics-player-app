import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/cover/services/track_cover_repository.dart';

/// 依 trackId 取自訂封面圖檔;查無紀錄、或圖檔已被外部清掉皆回 null,
/// 由 UI 自動退回佔位圖。設定 / 移除封面後由 [CoverImportService]
/// `invalidate` 對應 family 觸發重讀。
final trackCoverProvider = FutureProvider.family<File?, String>((
  ref,
  trackId,
) async {
  final entity = ref.watch(trackCoverRepositoryProvider).findByTrackId(trackId);
  if (entity == null) return null;
  final file = File(entity.coverImagePath!);
  return file.existsSync() ? file : null;
});

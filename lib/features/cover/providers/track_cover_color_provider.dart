import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/cover/services/cover_color.dart';
import 'package:seek_player/features/cover/services/track_cover_repository.dart';

/// 依 pathKey 取封面主色,供播放頁的「封面色漸層」使用。
///
/// 優先回傳已持久化於 TrackEntity.coverColorValue 的顏色(切歌即時,
/// 不需解析圖片);僅當舊資料尚未快取時才即時解析,並寫回 entity 供下次
/// 直接取用。無封面、圖檔遺失或解析失敗皆回 null,由 UI 退回主題色漸層。
/// 封面更換 / 移除時由 [CoverImportService] invalidate 本 provider 重讀。
final trackCoverColorProvider = FutureProvider.family<Color?, String>((
  ref,
  pathKey,
) async {
  final repo = ref.watch(trackCoverRepositoryProvider);
  final entity = repo.findByPathKey(pathKey);
  if (entity == null) return null;
  final cached = entity.coverColorValue;
  if (cached != null) return Color(cached);

  final file = File(entity.coverImagePath!);
  if (!file.existsSync()) return null;
  final color = await extractCoverColor(file);
  if (color != null) await repo.setColor(pathKey, color.toARGB32());
  return color;
});

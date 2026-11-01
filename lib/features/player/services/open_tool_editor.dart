import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';

/// 從全螢幕播放頁跳到「工具」分頁中 [tool] 對該曲的編輯頁。
///
/// 播放頁是疊在 shell 上方的 root route,需先 pop 掉才看得到編輯頁。
/// id 可能是 iOS 的檔案路徑(含 `/`),編碼後才能放進路徑參數。
/// [track] 有值時當作編輯頁的初始資料,否則由編輯頁自行以 id 載入。
void openToolEditorFromPlayer(
  BuildContext context, {
  required ToolKind tool,
  required String trackId,
  Track? track,
}) {
  final router = GoRouter.of(context);
  Navigator.of(context, rootNavigator: true).pop();
  router.push(
    '/tools/${tool.name}/${Uri.encodeComponent(trackId)}',
    extra: track,
  );
}

import 'package:flutter/material.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/tools/cover_editor_page.dart';
import 'package:seek_player/features/tools/lyrics_edit_tool_page.dart';
import 'package:seek_player/features/tools/lyrics_editor_page.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';

/// 從全螢幕播放頁開啟 [tool] 對該曲的編輯頁。
///
/// 播放頁是以 imperative route 疊在 root navigator 上;編輯頁同樣直接
/// push 到 root navigator、疊在播放頁之上,返回時就回到播放頁,而不是
/// 先關掉播放頁再走 go_router(那樣返回會落到下層的本地音樂 / 播放清單)。
/// [track] 有值時當作編輯頁的初始資料,否則由編輯頁自行以 trackId 載入。
void openToolEditorFromPlayer(
  BuildContext context, {
  required ToolKind tool,
  required String trackId,
  Track? track,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => switch (tool) {
        ToolKind.lyrics => LyricsEditorPage(
          trackId: trackId,
          initialTrack: track,
        ),
        ToolKind.lyricsEdit => LyricsEditToolPage(
          trackId: trackId,
          initialTrack: track,
        ),
        ToolKind.cover => CoverEditorPage(
          trackId: trackId,
          initialTrack: track,
        ),
      },
    ),
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/background/lyrics_background_running.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';

/// 判斷某 trackId 目前是否有進行中的自動產生/對齊工作,決定 `LyricsView`
/// 要不要顯示處理中畫面([LyricsJobStatusView])。全部依本地記錄判斷,不
/// 讀 Firestore 的即時處理階段。符合下列任一條件即為 active:
/// - 背景任務執行中([lyricsBackgroundRunningProvider]):涵蓋剛送出、
///   Firestore 尚未寫入第一筆 status 的空窗期,以及 app 重啟後由 native
///   `isRunning` 校正回來的情況;
/// - 本地待同步清單([lyricsPendingSyncStoreProvider])裡有這個
///   trackId:涵蓋背景服務本身已結束、但 Cloud Run 還在跑,尚未被
///   `LyricsPendingSyncService` 收尾的情況,跨 app 重啟也不會遺失。
/// 改為 derived 而非手動 set,避免本地旗標與實際執行狀態不同步。
final lyricsActiveJobProvider = Provider.family<bool, String>((ref, trackId) {
  if (ref.watch(lyricsBackgroundRunningProvider)) return true;
  return ref.watch(lyricsPendingSyncStoreProvider).containsKey(trackId);
});

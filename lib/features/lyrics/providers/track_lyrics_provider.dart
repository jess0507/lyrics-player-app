import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/models/lyrics.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/services/lyrics_parser.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 依 trackId 查歌詞並解析為內部模型;查無回 null。顯示計畫
/// (`lyrics-display.md`)以目前曲目 id 消費本 provider;匯入後由
/// import service `invalidate` 對應 family 觸發重讀。
///
/// 本機沒有歌詞(尚未匯入 / 對時 / 產生過)時,若已登入,降級讀一次雲端快照
/// `user/{uid}/lyrics/{trackId}`(align_lyrics / generate_lyrics 後端成功後
/// 靜默寫入,或其他裝置同步備份而來),讓使用者不必重新操作即可看到歌詞。
/// 純顯示用途,不寫回本機 Isar(避免與既有同步機制打架)。
final trackLyricsProvider = FutureProvider.family<Lyrics?, String>((
  ref,
  trackId,
) async {
  final entity = ref.watch(lyricsRepositoryProvider).findByTrackId(trackId);
  if (entity != null) return parseLyrics(entity.content, entity.format);
  return _fetchRemoteLyricsSnapshot(trackId);
});

Future<Lyrics?> _fetchRemoteLyricsSnapshot(String trackId) async {
  debugPrint(
    "[trackLyricsProvider] fetch remote lyrics snapshot for trackId:$trackId",
  );
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final snapshot = await FirebaseFirestore.instance
      .collection('user')
      .doc(uid)
      .collection('lyrics')
      .doc(trackId)
      .get();
  final data = snapshot.data();
  final content = data?['content'];
  if (content is! String || content.isEmpty) return null;
  final format =
      LyricsFormat.values.asNameMap()[data?['format']] ?? LyricsFormat.txt;
  return parseLyrics(content, format);
}

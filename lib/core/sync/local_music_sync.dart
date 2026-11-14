import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/features/playlists/models/local_music_view_state.dart';
import 'package:seek_player/features/playlists/providers/local_music_view_controller.dart';

/// 本機音樂頁的資料夾與排序與 `user/{uid}/localMusic/0` 單一文件的推送與
/// 還原(SyncService 調度)。
class LocalMusicSync {
  LocalMusicSync(this._ref);

  final Ref _ref;

  static const _docId = '0';

  DocumentReference<Map<String, dynamic>> _doc(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) => userDoc.collection('localMusic').doc(_docId);

  /// 本機是否改過資料夾 / 排序(沒有「空」的狀態,以是否曾變更判斷)。
  bool hasLocalData() =>
      _ref.read(backupStateStoreProvider).localMusicModifiedAt != null;

  /// 雲端是否有 `localMusic/0` 文件。
  Future<bool> hasRemoteData(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async => (await _doc(userDoc).get()).exists;

  /// 覆寫 `localMusic/0` 文件。
  Future<void> push(DocumentReference<Map<String, dynamic>> userDoc) =>
      _doc(userDoc).set({
        ..._ref.read(localMusicViewControllerProvider).toRemoteMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// 以雲端文件還原本機;文件不存在時不動本機。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final raw = (await _doc(userDoc).get()).data();
    if (raw == null) return;
    _ref
        .read(localMusicViewControllerProvider.notifier)
        .restoreFromRemote(LocalMusicViewState.fromRemoteMap(raw));
  }
}

final localMusicSyncProvider = Provider<LocalMusicSync>(
  (ref) => LocalMusicSync(ref),
);

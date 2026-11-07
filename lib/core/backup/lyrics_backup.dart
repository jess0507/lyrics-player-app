import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/backup/domain_backup.dart';
import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 歌詞 ↔ `lyrics.json`:
/// `{ "lyrics": [ {trackId, title, format, source, content, updatedAt} ] }`。
/// 一個檔裝全部歌詞,沒有筆數上限。
class LyricsBackup implements DomainBackup {
  LyricsBackup(this._ref);

  final Ref _ref;

  @override
  String get fileName => 'lyrics.json';

  @override
  String get label => 'lyrics';

  @override
  DateTime? get localModifiedAt =>
      _ref.read(backupStateStoreProvider).lyricsModifiedAt;

  /// 一次性補記,讓下一個同步班次把存量歌詞推上雲端(GoogleDriveBackupService 的
  /// 推送判斷:本機 lyricsModifiedAt 為 null 時不會觸發推送)。
  void markExistingPending() {
    final store = _ref.read(backupStateStoreProvider);
    if (store.lyricsModifiedAt != null) return;
    if (_ref.read(lyricsRepositoryProvider).getAllSync().isEmpty) return;
    debugPrint('[Backup] 補記存量歌詞為待推送');
    store.markLyricsModified();
  }

  @override
  Map<String, dynamic> encode() =>
      encodeLyrics(_ref.read(lyricsRepositoryProvider).getAllSync());

  @override
  Future<void> restore(Map<String, dynamic> json) async {
    await _ref
        .read(lyricsRepositoryProvider)
        .restoreFromRemote(decodeLyrics(json));
    // 歌詞顯示 provider 不走 Isar watch,還原後手動作廢重讀。
    _ref.invalidate(trackLyricsProvider);
  }

  /// 純函式,供測試 round-trip。
  static Map<String, dynamic> encodeLyrics(List<LyricsEntity> entities) => {
    'lyrics': [
      for (final e in entities)
        {
          'trackId': e.trackId,
          'title': e.title,
          'format': e.format.name,
          'source': e.source.name,
          'content': e.content,
          'updatedAt': e.addedAt.millisecondsSinceEpoch,
        },
    ],
  };

  /// 容錯:缺欄位給預設值;沒有 trackId 或內文為空的條目跳過
  /// (原文是解析的唯一依據,空內文無意義)。
  static List<LyricsEntity> decodeLyrics(Map<String, dynamic> json) {
    final entities = <LyricsEntity>[];
    for (final item in (json['lyrics'] as List? ?? const [])) {
      if (item is! Map) continue;
      final trackId = item['trackId'];
      final content = item['content'];
      if (trackId is! String || trackId.isEmpty) continue;
      if (content is! String || content.isEmpty) continue;
      entities.add(
        LyricsEntity()
          ..trackId = trackId
          ..title = (item['title'] as String?) ?? ''
          ..format =
              LyricsFormat.values.asNameMap()[item['format']] ??
              LyricsFormat.txt
          ..source =
              LyricsSource.values.asNameMap()[item['source']] ??
              LyricsSource.manual
          ..content = content
          ..addedAt = DateTime.fromMillisecondsSinceEpoch(
            (item['updatedAt'] as num? ?? 0).toInt(),
          ),
      );
    }
    return entities;
  }
}

final lyricsBackupProvider = Provider<LyricsBackup>((ref) => LyricsBackup(ref));

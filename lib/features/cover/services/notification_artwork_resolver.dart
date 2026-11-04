import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/cover/services/track_cover_repository.dart';
import 'package:seek_player/features/music_list/models/track.dart';

/// 為通知列 / 鎖定畫面(audio_service 的 [MediaItem.artUri])決定每首曲目的
/// 封面 URI。just_audio_background 的 MediaItem 只能在建立佇列時給定,
/// 之後無法單獨更新,因此在 setPlaylist 前一次算好整個佇列。
///
/// 回退鏈與 App 內 [trackArtworkProvider] 一致:
/// 1. 使用者自訂封面 → `file://`
/// 2. MediaStore 專輯封面 `content://media/external/audio/albumart/<albumId>`
///    (audio_service 以 openFileDescriptor 讀取,各 API level 皆可用;無圖時
///    通知自動不顯示封面)
class NotificationArtworkResolver {
  NotificationArtworkResolver(this._covers);

  final TrackCoverRepository _covers;

  static final _albumArtBase = Uri.parse(
    'content://media/external/audio/albumart',
  );

  /// 回傳 pathKey → artUri;查無封面的曲目不會出現在結果中。
  Future<Map<String, Uri>> resolve(List<Track> tracks) async {
    final result = <String, Uri>{};
    for (final t in tracks) {
      final uri = _resolveOne(t);
      if (uri != null) result[t.pathKey] = uri;
    }
    return result;
  }

  Uri? _resolveOne(Track track) {
    final custom = _covers.findByPathKey(track.pathKey);
    if (custom != null) return Uri.file(custom.coverImagePath!);

    final albumId = track.albumId;
    if (albumId == null) return null;
    return _albumArtBase.replace(
      pathSegments: [..._albumArtBase.pathSegments, '$albumId'],
    );
  }
}

final notificationArtworkResolverProvider =
    Provider<NotificationArtworkResolver>(
      (ref) =>
          NotificationArtworkResolver(ref.watch(trackCoverRepositoryProvider)),
    );

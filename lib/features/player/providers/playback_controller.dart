import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/cover/services/notification_artwork_resolver.dart';
import 'package:seek_player/features/lyrics/background/lyrics_l10n_resolver.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 串接音樂庫、音訊服務與統計：負責「從某首開始播放」與背景統計收集。
class PlaybackController {
  PlaybackController(this.ref) {
    _setupListeners();
  }

  final Ref ref;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _listenTimer;

  /// 目前送進播放器的佇列(可能是整個音樂庫,也可能是某個播放清單)。
  /// 統計以此對齊 currentIndex,而非永遠用音樂庫。
  List<Track> _queue = const [];

  AudioPlayerService get _audio => ref.read(audioPlayerServiceProvider);

  /// 目前已掃描完成的曲目清單（掃描中／失敗時為空）。
  List<Track> get _tracks =>
      ref.read(musicLibraryProvider).valueOrNull ?? const [];

  void _setupListeners() {
    // 切換到某首（含初次載入）時記錄一次播放。
    _subs.add(
      _audio.currentIndexStream.listen((index) {
        if (index == null) return;
        final queue = _queue;
        if (index >= 0 && index < queue.length) {
          final track = queue[index];
          ref.read(statisticsControllerProvider.notifier).recordPlay(track);
          ref
              .read(playlistRepositoryProvider)
              .recordRecentlyPlayed(track.trackId);
        }
      }),
    );

    // 以 5 秒取樣累加實際聆聽時長（記在目前播放的曲目上）。
    _listenTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_audio.playing) return;
      final index = _audio.currentIndex;
      final queue = _queue;
      if (index == null || index < 0 || index >= queue.length) return;
      ref
          .read(statisticsControllerProvider.notifier)
          .addListenTime(queue[index], const Duration(seconds: 5));
    });

    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _listenTimer?.cancel();
    });
  }

  /// 以整個音樂庫為播放清單，從 [index] 開始播放。回傳是否成功開始播放。
  Future<bool> playLibraryAt(int index) => playTracksAt(_tracks, index);

  /// 回傳是否成功開始播放;[track] 不在音樂庫時為 false。
  Future<bool> playTrack(Track track) async {
    final tracks = _tracks;
    final index = tracks.indexWhere((t) => t.trackId == track.trackId);
    if (index < 0) return false;
    return playLibraryAt(index);
  }

  /// 以指定曲目清單(如某個播放清單)為佇列,從 [index] 開始播放。
  ///
  /// 回傳是否成功開始播放。起始曲目載入失敗(檔案已不存在、格式不支援、
  /// URI 權限失效等)時以 toast 提示,不往外丟例外——呼叫端多半是 onTap 內
  /// 不 await 的呼叫,丟出去只會變成不帶任何線索的未處理錯誤。
  /// 仍以 fatal 回報,讓它繼續列在 Crashlytics 的 crash,並附上曲目資訊。
  Future<bool> playTracksAt(List<Track> tracks, int index) async {
    if (index < 0 || index >= tracks.length) return false;
    _queue = List.unmodifiable(tracks);
    try {
      await _setPlaylist(tracks, index);
    } catch (e, s) {
      reportError(
        e,
        s,
        reason: 'PlaybackController 載入播放清單失敗',
        information: _loadFailureInfo(tracks, index),
        fatal: true,
      );
      showAppToast(resolveLyricsL10n(ref).playback_load_failed);
      return false;
    }
    _startPlaying();
    return true;
  }

  /// 載入失敗時附給 Crashlytics 的線索:起始曲目的 URI、檔案路徑與 trackId,
  /// 用來判斷是檔案不存在、格式不支援還是 URI 權限失效。
  /// 使用者 uid 已由 [bindCrashUserIdentifier] 綁定,不必另外附。
  static List<Object> _loadFailureInfo(List<Track> tracks, int index) {
    final track = tracks[index];
    return [
      'uri=${track.uri}',
      'filePath=${track.filePath}',
      'trackId=${track.trackId}',
      'index=$index',
      'queueLength=${tracks.length}',
    ];
  }

  /// 送進播放器前先決定各曲的通知列封面;封面解析失敗不應擋播放。
  Future<void> _setPlaylist(List<Track> tracks, int index) async {
    var artUris = const <String, Uri>{};
    try {
      artUris = await ref
          .read(notificationArtworkResolverProvider)
          .resolve(tracks);
    } catch (e, s) {
      reportError(e, s, reason: 'PlaybackController 通知列封面解析失敗');
    }
    await _audio.setPlaylist(tracks, initialIndex: index, artUris: artUris);
  }

  /// just_audio 的 `play()` 回傳的 Future 要等到「播放完畢／暫停／停止」
  /// 才完成,不是「開始播放」;await 它會把呼叫端卡到整首歌結束
  /// (外部開檔後要接著開播放頁就會卡死)。載入失敗已在 [playTracksAt]
  /// 處理,這裡只需觸發播放並吞掉之後的錯誤。
  void _startPlaying() {
    unawaited(
      _audio.play().catchError(
        (Object e, StackTrace s) =>
            reportError(e, s, reason: 'PlaybackController 播放失敗'),
      ),
    );
  }
}

final playbackControllerProvider = Provider<PlaybackController>(
  (ref) => PlaybackController(ref),
);

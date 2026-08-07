import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

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
          ref.read(playlistRepositoryProvider).recordRecentlyPlayed(track.id);
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

  /// 以整個音樂庫為播放清單，從 [index] 開始播放。
  Future<void> playLibraryAt(int index) async {
    final tracks = _tracks;
    if (index < 0 || index >= tracks.length) return;
    _queue = tracks;
    await _audio.setPlaylist(tracks, initialIndex: index);
    await _audio.play();
  }

  Future<void> playTrack(Track track) async {
    final tracks = _tracks;
    final index = tracks.indexWhere((t) => t.id == track.id);
    if (index >= 0) await playLibraryAt(index);
  }

  /// 以指定曲目清單(如某個播放清單)為佇列,從 [index] 開始播放。
  Future<void> playTracksAt(List<Track> tracks, int index) async {
    if (index < 0 || index >= tracks.length) return;
    _queue = List.unmodifiable(tracks);
    await _audio.setPlaylist(tracks, initialIndex: index);
    await _audio.play();
  }
}

final playbackControllerProvider = Provider<PlaybackController>(
  (ref) => PlaybackController(ref),
);

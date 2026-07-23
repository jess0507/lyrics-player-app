import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../../features/music_list/models/track.dart';

/// 進度條所需的合併資料。
class PositionData {
  const PositionData(this.position, this.buffered, this.duration);

  final Duration position;
  final Duration buffered;
  final Duration duration;
}

/// 封裝 just_audio 的 [AudioPlayer]，提供本機播放清單、背景播放與通知列控制。
class AudioPlayerService {
  AudioPlayerService() {
    _player.setLoopMode(LoopMode.all);
  }

  final AudioPlayer _player = AudioPlayer();

  static const _restartThreshold = Duration(seconds: 3);

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<bool> get shuffleModeEnabledStream =>
      _player.shuffleModeEnabledStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<double> get speedStream => _player.speedStream;
  bool get playing => _player.playing;
  int? get currentIndex => _player.currentIndex;
  double get speed => _player.speed;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  /// 以整個音樂庫建立播放清單，並從 [initialIndex] 開始播放。
  Future<void> setPlaylist(
    List<Track> tracks, {
    int initialIndex = 0,
  }) async {
    if (tracks.isEmpty) return;
    final source = ConcatenatingAudioSource(
      children: [
        for (final t in tracks)
          AudioSource.uri(
            Uri.parse(t.uri),
            tag: MediaItem(
              id: t.id,
              title: t.title,
              artist: t.artist ?? '',
            ),
          ),
      ],
    );
    await _player.setAudioSource(source, initialIndex: initialIndex);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekToNext() => _player.seekToNext();

  /// 若目前曲目已播放超過 [_restartThreshold]，重置本曲進度到開頭；
  /// 否則（剛播放不久）才真的跳到上一首。
  Future<void> seekToPrevious() {
    if (_player.position > _restartThreshold) {
      return _player.seek(Duration.zero);
    }
    return _player.seekToPrevious();
  }
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);
  Future<void> setShuffle(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);

  /// 設定播放速度（0.5x ~ 4.0x）。
  Future<void> setSpeed(double speed) =>
      _player.setSpeed(speed.clamp(0.5, 4.0));

  /// 相對目前位置快進（正值）或快退（負值），並夾在 [0, 總時長] 範圍內。
  Future<void> seekRelative(Duration delta) {
    final duration = _player.duration ?? Duration.zero;
    var target = _player.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    return _player.seek(target);
  }

  void dispose() => _player.dispose();
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});

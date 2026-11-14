import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/playlists/models/local_music_view_state.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 本機音樂頁的資料夾與排序紀錄(來自「本機音樂」系統清單);寫入走
/// [PlaylistRepository.setLocalMusicFolder] / [PlaylistRepository.setSort]。
final localMusicViewProvider = StreamProvider<LocalMusicViewState>(
  (ref) => ref
      .watch(playlistRepositoryProvider)
      .watchLocalMusic()
      .map(LocalMusicViewState.fromEntity),
);

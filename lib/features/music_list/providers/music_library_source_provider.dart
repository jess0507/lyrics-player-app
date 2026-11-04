import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/services/media_store_music_source.dart';
import 'package:seek_player/features/music_list/services/music_library_source.dart';

/// 音樂庫來源:掃 Android MediaStore。
final musicLibrarySourceProvider = Provider<MusicLibrarySource>(
  MediaStoreMusicSource.new,
);

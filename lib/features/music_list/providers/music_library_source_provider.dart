import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/services/documents_music_source.dart';
import 'package:seek_player/features/music_list/services/media_store_music_source.dart';
import 'package:seek_player/features/music_list/services/music_library_source.dart';

/// 依平台提供音樂庫來源:iOS 掃 app Documents(方案 A)、
/// 其餘(Android)掃 MediaStore。
final musicLibrarySourceProvider = Provider<MusicLibrarySource>(
  (ref) =>
      Platform.isIOS ? DocumentsMusicSource(ref) : MediaStoreMusicSource(ref),
);

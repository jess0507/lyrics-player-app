import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具編輯頁(歌詞 / 封面)共用的頁框:以 [trackId] 從音樂庫查曲目,
/// 查不到(重掃中等)時用路由帶進來的 [initialTrack];
/// 兩者皆無時顯示讀取中或空狀態,有曲目才以 [builder] 建內容。
class TrackEditorScaffold extends ConsumerWidget {
  const TrackEditorScaffold({
    super.key,
    required this.title,
    required this.trackId,
    required this.initialTrack,
    required this.builder,
  });

  final String title;
  final String trackId;
  final Track? initialTrack;
  final Widget Function(BuildContext context, Track track) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(musicLibraryProvider);
    final track =
        library.valueOrNull?.where((t) => t.id == trackId).firstOrNull ??
        initialTrack;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: track == null
          ? Center(
              child: library.isLoading
                  ? const CircularProgressIndicator()
                  : Text(l10n.music_empty),
            )
          : builder(context, track),
    );
  }
}

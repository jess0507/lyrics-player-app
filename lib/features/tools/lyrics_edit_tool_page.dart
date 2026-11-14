import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_page.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具「編輯歌詞」選完曲目後的頁面:以 [trackId] 從音樂庫查曲目
/// (查不到時用路由帶進來的 [initialTrack]),有曲目就直接進 [LyricsEditPage];
/// 兩者皆無時顯示讀取中或空狀態。
class LyricsEditToolPage extends ConsumerWidget {
  const LyricsEditToolPage({
    super.key,
    required this.trackId,
    this.initialTrack,
  });

  final String trackId;
  final Track? initialTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(musicLibraryProvider);
    final track =
        library.valueOrNull?.where((t) => t.trackId == trackId).firstOrNull ??
        initialTrack;
    if (track != null) {
      return LyricsEditPage(trackId: track.trackId, title: track.title);
    }

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lyrics_edit)),
      body: Center(
        child: library.isLoading
            ? const CircularProgressIndicator()
            : Text(l10n.music_empty),
      ),
    );
  }
}

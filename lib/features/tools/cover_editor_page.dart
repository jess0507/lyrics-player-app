import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/widgets/cover_actions.dart';
import 'package:seek_player/features/tools/widgets/track_editor_header.dart';
import 'package:seek_player/features/tools/widgets/track_editor_scaffold.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具「更改封面」選完曲目後的編輯頁:上方大封面與標題,下方新增 / 更換
/// 封面,有自訂封面時可移除。改完封面後上方即時更新,不離開本頁。
class CoverEditorPage extends StatelessWidget {
  const CoverEditorPage({super.key, required this.trackId, this.initialTrack});

  final String trackId;
  final Track? initialTrack;

  @override
  Widget build(BuildContext context) {
    return TrackEditorScaffold(
      title: AppLocalizations.of(context)!.cover_edit,
      trackId: trackId,
      initialTrack: initialTrack,
      builder: (context, track) => _CoverEditorBody(track: track),
    );
  }
}

class _CoverEditorBody extends ConsumerWidget {
  const _CoverEditorBody({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // 只有自訂封面能移除;內嵌封面不受影響,故不看 embedded artwork。
    final hasCover =
        ref.watch(trackCoverProvider(track.id)).valueOrNull != null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        TrackEditorHeader(track: track, coverSize: 240),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(hasCover ? l10n.cover_change : l10n.cover_add),
          onTap: () => setTrackCover(context, ref, track.id),
        ),
        if (hasCover)
          ListTile(
            leading: const Icon(Icons.hide_image_outlined),
            title: Text(l10n.cover_remove),
            onTap: () => removeTrackCover(context, ref, track.id),
          ),
      ],
    );
  }
}

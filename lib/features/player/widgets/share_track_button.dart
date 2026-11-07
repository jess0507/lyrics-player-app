import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';

/// 分享目前曲目的音樂檔案本身（叫出系統分享面板）。
/// 依 [trackId] 從音樂庫查回曲目取得檔案 uri；查無曲目時不顯示。
class ShareTrackButton extends ConsumerWidget {
  const ShareTrackButton({
    super.key,
    required this.enabled,
    required this.trackId,
    this.iconSize = 20.0,
  });

  final bool enabled;
  final String? trackId;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = trackId;
    if (id == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
    final track = tracks.where((t) => t.trackId == id).firstOrNull;
    if (track == null) return const SizedBox.shrink();

    return IconButton(
      iconSize: iconSize,
      tooltip: l10n.player_share,
      onPressed: enabled ? () => _share(context, track.filePath) : null,
      icon: const Icon(Icons.share_outlined),
    );
  }

  /// 帶上按鈕自身在畫面上的位置：iPad 上 [SharePlus] 需要
  /// `sharePositionOrigin` 作為分享面板的錨點，否則會崩潰。
  Future<void> _share(BuildContext context, String path) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], sharePositionOrigin: origin),
    );
    // 記分享面板結果(success / dismissed / unavailable),不送檔案路徑。
    logAnalyticsAction(PlayerAction.share, result: result.status);
  }
}

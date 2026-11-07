import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/storage/track_entity_migration.dart';
import 'package:seek_player/features/music_list/providers/library_hash_progress.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 一進 app 就觸發一次性的 TrackEntity 遷移;遷移需要執行時在整個 app 上蓋
/// 一層「更新音樂庫」畫面(擋住操作),結束後移除。已完成 / 新安裝時狀態一開始
/// 就是 done,不會閃出 loading。
///
/// 曲庫掃描要計算大量 trackId(音檔全檔 SHA-256,例如第一次掃描、一次加入
/// 很多首歌)時也蓋上同一個畫面並顯示進度;只有少數檔案要算時不蓋,避免閃一下。
///
/// 用 Stack 疊在 [child] 上而不是替換掉它:進 app 後才授權、由曲庫掃描補跑
/// 遷移時,底下的 Navigator 狀態不會因此重建。
class TrackEntityMigrationGate extends ConsumerStatefulWidget {
  const TrackEntityMigrationGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TrackEntityMigrationGate> createState() =>
      _TrackEntityMigrationGateState();
}

/// 一次要算的 trackId 達到這個數量才蓋上「更新音樂庫」畫面。
const _kBlockingHashCount = 10;

class _TrackEntityMigrationGateState
    extends ConsumerState<TrackEntityMigrationGate> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(trackEntityMigrationProvider.notifier).runIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(trackEntityMigrationProvider);
    final progress = ref.watch(libraryHashProgressProvider);
    final migrating =
        status == TrackEntityMigrationStatus.pending ||
        status == TrackEntityMigrationStatus.running;
    final hashing = progress != null && progress.total >= _kBlockingHashCount;
    return Stack(
      children: [
        widget.child,
        if (migrating || hashing)
          Positioned.fill(
            child: _MigrationLoadingView(
              progress: progress,
              showMigrationMessage: migrating,
            ),
          ),
      ],
    );
  }
}

class _MigrationLoadingView extends StatelessWidget {
  const _MigrationLoadingView({
    required this.progress,
    required this.showMigrationMessage,
  });

  final LibraryHashProgressValue? progress;

  /// 版本升級的一次性遷移才顯示「只會執行一次」說明。
  final bool showMigrationMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: progress == null || progress!.total == 0
                      ? null
                      : progress!.done / progress!.total,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.music_library_refresh_title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.music_library_refresh_progress(
                      progress!.done,
                      progress!.total,
                    ),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (showMigrationMessage) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.migration_loading_message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/storage/track_entity_migration.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 一進 app 就觸發一次性的 TrackEntity 遷移;遷移需要執行時在整個 app 上蓋
/// 一層 loading(擋住操作),結束後移除。已完成 / 新安裝時狀態一開始就是
/// done,不會閃出 loading。
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
    final blocking =
        status == TrackEntityMigrationStatus.pending ||
        status == TrackEntityMigrationStatus.running;
    return Stack(
      children: [
        widget.child,
        if (blocking) const Positioned.fill(child: _MigrationLoadingView()),
      ],
    );
  }
}

class _MigrationLoadingView extends StatelessWidget {
  const _MigrationLoadingView();

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
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  l10n.migration_loading_title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.migration_loading_message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

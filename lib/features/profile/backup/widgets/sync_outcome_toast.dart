import 'package:seek_player/core/sync/sync_outcome.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 「同步到雲端 / 同步到本地」結束後依結果跳 toast。
/// [doneMessage] 為 [SyncOutcome.done] 時的文案(兩個方向不同)。
void showSyncOutcomeToast(
  AppLocalizations l10n,
  SyncOutcome outcome, {
  required String doneMessage,
}) {
  showAppToast(switch (outcome) {
    SyncOutcome.done => doneMessage,
    SyncOutcome.notLinked => l10n.backup_not_linked,
    SyncOutcome.needsRelink => l10n.backup_needs_relink,
    SyncOutcome.driveFull => l10n.backup_drive_full,
    SyncOutcome.nothingToRestore => l10n.backup_nothing_to_restore,
    SyncOutcome.failed => l10n.backup_failed,
  });
}

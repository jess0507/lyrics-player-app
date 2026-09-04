import 'package:seek_player/core/sync/sync_outcome.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 連結後首次同步結束時依結果跳 toast。
/// [doneMessage] 為 [SyncOutcome.done] 時的文案(推 / 拉方向不同)。
void showSyncOutcomeToast(
  AppLocalizations l10n,
  SyncOutcome outcome, {
  required String doneMessage,
}) {
  showAppToast(switch (outcome) {
    SyncOutcome.done => doneMessage,
    SyncOutcome.notLinked => l10n.backup_not_linked,
    SyncOutcome.busy => l10n.backup_busy,
    SyncOutcome.needsRelink => l10n.backup_needs_relink,
    SyncOutcome.driveFull => l10n.backup_drive_full,
    SyncOutcome.failed => l10n.backup_failed,
  });
}

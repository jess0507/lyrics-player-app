import 'package:seek_player/core/backup/backup_outcome.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 連結後首次備份結束時依結果跳 toast。
/// [doneMessage] 為 [BackupOutcome.done] 時的文案(推 / 拉方向不同)。
void showBackupOutcomeToast(
  AppLocalizations l10n,
  BackupOutcome outcome, {
  required String doneMessage,
}) {
  showAppToast(switch (outcome) {
    BackupOutcome.done => doneMessage,
    BackupOutcome.notLinked => l10n.backup_not_linked,
    BackupOutcome.busy => l10n.backup_busy,
    BackupOutcome.needsRelink => l10n.backup_needs_relink,
    BackupOutcome.driveFull => l10n.backup_drive_full,
    BackupOutcome.failed => l10n.backup_failed,
  });
}

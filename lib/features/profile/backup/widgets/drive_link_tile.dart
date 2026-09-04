import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/drive_link_controller.dart';
import 'package:seek_player/core/sync/drive_link_state.dart';
import 'package:seek_player/core/sync/link_choice.dart';
import 'package:seek_player/core/sync/sync_busy_provider.dart';
import 'package:seek_player/core/sync/sync_google_drive_service.dart';
import 'package:seek_player/features/profile/backup/widgets/cloud_backup_found_dialog.dart';
import 'package:seek_player/features/profile/backup/widgets/sync_outcome_toast.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 備份頁最上方的 Google Drive 連結狀態列:
/// - 未連結 → 「連結」:授權成功後立即跑 [SyncGoogleDriveService.afterLink]
///   (雲端沒備份直接推;有備份先問要用雲端還是保留本機)。
/// - 已連結顯示 email → 「解除連結」(先確認)。
/// - 授權失效 → 「重新連結」,流程同連結。
/// 連結後每次回前景由 service 自動推,這裡不再提供手動同步。
class DriveLinkTile extends ConsumerStatefulWidget {
  const DriveLinkTile({super.key});

  @override
  ConsumerState<DriveLinkTile> createState() => _DriveLinkTileState();
}

class _DriveLinkTileState extends ConsumerState<DriveLinkTile> {
  /// 連結 / 解除連結 / 連結後首次同步進行中(leading 顯示 spinner)。
  bool _working = false;

  /// 任何同步(連結流程、回前景自動上傳)進行中再按一次:只跳 toast,
  /// 不重複執行。
  bool _rejectIfBusy(AppLocalizations l10n) {
    if (!_working && !ref.read(syncBusyProvider)) return false;
    showAppToast(l10n.backup_busy);
    return true;
  }

  Future<void> _link() async {
    final l10n = AppLocalizations.of(context)!;
    if (_rejectIfBusy(l10n)) return;
    setState(() => _working = true);
    final ok = await ref.read(driveLinkStateProvider.notifier).link();
    if (!mounted) return;
    if (!ok) {
      setState(() => _working = false);
      // 取消登入 / 拒絕授權不算失敗(狀態不變),不跳 toast。
      if (ref.read(driveLinkStateProvider) is! DriveLinked) return;
      showAppToast(l10n.backup_link_failed);
      return;
    }

    // link() 回來到這裡之間不能有 await:afterLink 要先於回前景的自動上傳
    // 拿到 busy,雲端備份才不會在使用者選擇前被本機資料蓋掉。
    var choice = LinkChoice.keepLocal;
    final outcome = await ref
        .read(syncGoogleDriveServiceProvider)
        .afterLink(
          chooseWhenCloudHasBackup: () async {
            if (!mounted) return LinkChoice.keepLocal;
            return choice = await showCloudBackupFoundDialog(context);
          },
        );
    if (!mounted) return;
    setState(() => _working = false);
    showSyncOutcomeToast(
      l10n,
      outcome,
      doneMessage: switch (choice) {
        LinkChoice.useCloud => l10n.backup_restored,
        LinkChoice.keepLocal => l10n.backup_done,
      },
    );
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context)!;
    if (_rejectIfBusy(l10n)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_unlink),
        content: Text(l10n.backup_unlink_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    await ref.read(driveLinkStateProvider.notifier).unlink();
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(driveLinkStateProvider);
    // 同步中按鈕仍可按,但只會跳 toast(見 _rejectIfBusy);leading 換成
    // spinner 讓使用者知道正在跑。
    final syncing = _working || ref.watch(syncBusyProvider);
    final theme = Theme.of(context);

    final (
      IconData icon,
      Color? iconColor,
      String title,
      String? subtitle,
    ) = switch (state) {
      DriveNotLinked() => (
        Icons.cloud_off_outlined,
        null,
        l10n.backup_not_linked,
        null,
      ),
      DriveLinked(:final email) => (
        Icons.cloud_done_outlined,
        theme.colorScheme.primary,
        l10n.backup_linked_as(email),
        null,
      ),
      DriveNeedsRelink(:final lastEmail) => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
        lastEmail ?? l10n.backup_not_linked,
        l10n.backup_needs_relink,
      ),
    };

    final Widget action = switch (state) {
      DriveNotLinked() => FilledButton(
        onPressed: _link,
        child: Text(l10n.backup_link),
      ),
      DriveLinked() => TextButton(
        onPressed: _unlink,
        child: Text(l10n.backup_unlink),
      ),
      DriveNeedsRelink() => FilledButton(
        onPressed: _link,
        child: Text(l10n.backup_relink),
      ),
    };

    return ListTile(
      leading: syncing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: theme.colorScheme.error)),
      trailing: action,
    );
  }
}

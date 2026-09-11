import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:seek_player/core/backup/last_backup_at_provider.dart';
// import 'package:seek_player/features/profile/backup/widgets/backup_info_button.dart'; // 說明文案為 Google Drive 版,暫停
import 'package:seek_player/l10n/app_localizations.dart';

/// 備份頁「上次備份」列:顯示本機最後一次成功同步的時間,從未同步顯示
/// 「尚未同步」。時間由 lastBackupAtProvider 提供,自動上傳後也會即時更新。
/// 標題右側原有 Google Drive 備份說明的 info 按鈕,Drive 暫停期間隱藏。
class LastBackupTile extends ConsumerWidget {
  const LastBackupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lastBackupAt = ref.watch(lastBackupAtProvider);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(l10n.backup_last_backed_up),
      // title: Row(
      //   mainAxisSize: MainAxisSize.min,
      //   children: [
      //     Flexible(child: Text(l10n.backup_last_backed_up)),
      //     const BackupInfoButton(),
      //   ],
      // ),
      trailing: Text(
        lastBackupAt == null
            ? l10n.backup_never_backed_up
            : DateFormat.yMd(
                Localizations.localeOf(context).toString(),
              ).add_Hm().format(lastBackupAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:seek_player/core/sync/last_sync_at_provider.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 備份頁「上次備份」列:顯示本機最後一次成功同步的時間,從未同步顯示
/// 「尚未同步」。時間由 lastSyncAtProvider 提供,自動上傳後也會即時更新。
class LastBackupTile extends ConsumerWidget {
  const LastBackupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lastSyncAt = ref.watch(lastSyncAtProvider);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(l10n.backup_last_synced),
      trailing: Text(
        lastSyncAt == null
            ? l10n.backup_never_synced
            : DateFormat.yMd(
                Localizations.localeOf(context).toString(),
              ).add_Hm().format(lastSyncAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

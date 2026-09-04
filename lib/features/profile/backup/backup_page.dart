import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/backup/widgets/drive_link_tile.dart';
import 'package:seek_player/features/profile/backup/widgets/last_backup_tile.dart';

/// 備份頁:Google Drive 連結列 + 上次備份時間 + 說明文字。與帳戶登入無關(見 plan 26)。
/// 連結當下的首次同步與之後回前景的自動上傳都由 service 處理,
/// 頁面不提供手動同步。
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_backup)),
      body: ListView(
        children: [
          const DriveLinkTile(),
          const Divider(height: 1),
          const LastBackupTile(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              l10n.backup_description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

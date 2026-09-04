import 'package:flutter/material.dart';

import 'package:seek_player/features/profile/backup/widgets/drive_link_tile.dart';
import 'package:seek_player/features/profile/backup/widgets/last_backup_tile.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 備份區塊:Google Drive 連結列 + 上次備份時間 + 說明文字。
/// 同時用在獨立的備份頁,以及已登入帳戶頁的最上方;本身不捲動,
/// 由外層的 ListView 排版。
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/backup/widgets/drive_link_tile.dart';
import 'package:seek_player/features/profile/backup/widgets/sync_to_cloud_tile.dart';
import 'package:seek_player/features/profile/backup/widgets/sync_to_local_tile.dart';

/// 備份頁:Google Drive 連結狀態 + 「同步到雲端」「同步到本地」兩個動作。
/// 與帳戶登入無關(見 plan 26),未連結時兩個動作 disabled。
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
          const SyncToCloudTile(),
          const Divider(height: 1),
          const SyncToLocalTile(),
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

import 'package:flutter/material.dart';

import 'package:seek_player/core/backup/link_choice.dart';
import 'package:seek_player/core/sync/sync_domain.dart';
import 'package:seek_player/features/profile/backup/widgets/cloud_backup_found_dialog.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 登入同步時本機與雲端都有資料:以「選擇備份資料」對話框詢問使用者,
/// 「更多」裡只列出衝突的 [domains]。
Future<LinkChoice> showSyncConflictDialog(
  BuildContext context,
  List<SyncDomain> domains,
) {
  final l10n = AppLocalizations.of(context)!;
  return showCloudBackupFoundDialog(
    context,
    items: [
      for (final d in domains)
        switch (d) {
          SyncDomain.settings => l10n.backup_item_settings,
          SyncDomain.playlists => l10n.backup_item_playlists,
          SyncDomain.statistics => l10n.backup_item_statistics,
          SyncDomain.lyrics => l10n.backup_item_lyrics,
        },
    ],
  );
}

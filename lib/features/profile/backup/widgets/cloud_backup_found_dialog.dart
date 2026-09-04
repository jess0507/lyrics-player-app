import 'package:flutter/material.dart';

import 'package:seek_player/core/backup/link_choice.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 連結 Google Drive 後發現雲端已有備份:問使用者要用雲端備份覆寫本機,
/// 還是保留本機資料覆寫雲端。兩者都會覆蓋一方,因此不可點外面關閉,
/// 一定要選一個。
Future<LinkChoice> showCloudBackupFoundDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showDialog<LinkChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.backup_cloud_found_title),
        content: Text(l10n.backup_cloud_found_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, LinkChoice.keepLocal),
            child: Text(l10n.backup_keep_local),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, LinkChoice.useCloud),
            child: Text(l10n.backup_use_cloud),
          ),
        ],
      ),
    ),
  );
  // 不可關閉,理論上不會是 null;保險起見預設保留本機,至少不會清掉
  // 使用者眼前的資料。
  return choice ?? LinkChoice.keepLocal;
}

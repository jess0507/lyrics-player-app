import 'package:flutter/material.dart';

import 'package:seek_player/features/profile/backup/widgets/backup_section.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 備份頁:內容全在 [BackupSection]。與帳戶登入無關(見 plan 26),
/// 未登入也能從「更多 → 備份」進來連結 Google Drive;已登入者在帳戶頁
/// 最上方也看得到同一份內容。
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_backup)),
      body: ListView(children: const [BackupSection()]),
    );
  }
}

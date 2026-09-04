import 'package:flutter/material.dart';

import 'package:seek_player/features/profile/backup/widgets/drive_link_tile.dart';
import 'package:seek_player/features/profile/backup/widgets/last_backup_tile.dart';

/// 備份區塊:Google Drive 連結列 + 上次備份時間(附說明 info 按鈕)。
/// 放在已登入帳戶頁的最上方;本身不捲動,由外層的 ListView 排版。
/// 備份授權(Google Drive)與 Firebase 登入彼此獨立(plan 26)。
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriveLinkTile(),
        Divider(height: 1),
        LastBackupTile(),
        Divider(height: 1),
      ],
    );
  }
}

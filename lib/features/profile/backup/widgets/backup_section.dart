import 'package:flutter/material.dart';

// import 'package:seek_player/features/profile/backup/widgets/drive_link_tile.dart'; // Google Drive 備份暫停
import 'package:seek_player/features/profile/backup/widgets/last_backup_tile.dart';
import 'package:seek_player/features/profile/backup/widgets/sync_now_tile.dart';

/// 備份區塊:立即同步列 + 上次同步時間。放在已登入帳戶頁的最上方;
/// 本身不捲動,由外層的 ListView 排版。
/// Google Drive 連結列暫時隱藏,同步改走 Firestore(見 SyncService)。
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google Drive 備份暫停。
        // DriveLinkTile(),
        // Divider(height: 1),
        SyncNowTile(),
        Divider(height: 1),
        LastBackupTile(),
        Divider(height: 1),
      ],
    );
  }
}

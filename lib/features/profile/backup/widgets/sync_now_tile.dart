import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/sync_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 帳戶頁「立即同步」列:點擊手動觸發一次 Firestore 上傳,結束後以 toast
/// 回報成功 / 失敗;上次同步時間由 [LastBackupTile] 另行顯示,SyncService
/// 上傳後會自行刷新。
class SyncNowTile extends ConsumerStatefulWidget {
  const SyncNowTile({super.key});

  @override
  ConsumerState<SyncNowTile> createState() => _SyncNowTileState();
}

class _SyncNowTileState extends ConsumerState<SyncNowTile> {
  bool _syncing = false;

  Future<void> _handleTap() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _syncing = true);
    final ok = await ref.read(syncServiceProvider).syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    showAppToast(ok ? l10n.backup_done : l10n.backup_failed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: _syncing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Icon(Icons.sync),
      title: Text(l10n.backup_sync_now),
      onTap: _syncing ? null : _handleTap,
    );
  }
}

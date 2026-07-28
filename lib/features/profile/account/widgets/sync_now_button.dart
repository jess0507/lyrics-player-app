import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../providers/last_sync_at_provider.dart';

/// 帳戶頁面「立即同步」按鈕:手動觸發一次上傳,結束後回報成功/失敗
/// 並刷新上次同步時間顯示。
class SyncNowButton extends ConsumerStatefulWidget {
  const SyncNowButton({super.key});

  @override
  ConsumerState<SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends ConsumerState<SyncNowButton> {
  bool _syncing = false;

  Future<void> _handleTap() async {
    setState(() => _syncing = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(syncServiceProvider).syncNow();
    ref.invalidate(lastSyncAtProvider);
    if (!mounted) return;
    setState(() => _syncing = false);
    messenger.showAppSnackBar(
      ok ? l10n.account_sync_done : l10n.account_sync_failed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: _syncing ? null : _handleTap,
      icon: _syncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      label: Text(l10n.account_sync_now),
    );
  }
}

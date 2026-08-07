import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/ensure_online.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../providers/last_sync_at_provider.dart';

/// 帳戶頁面「立即同步」ListTile:點擊手動觸發一次上傳,結束後回報
/// 成功/失敗並刷新上次同步時間顯示(顯示於 trailing)。
class SyncNowButton extends ConsumerStatefulWidget {
  const SyncNowButton({super.key});

  @override
  ConsumerState<SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends ConsumerState<SyncNowButton> {
  bool _syncing = false;

  Future<void> _handleTap() async {
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
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
    final lastSyncAt = ref.watch(lastSyncAtProvider);
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
      title: Text(l10n.account_sync_now),
      trailing: Text(
        lastSyncAt == null
            ? l10n.account_never_synced
            : DateFormat.yMd(
                Localizations.localeOf(context).toString(),
              ).add_Hm().format(lastSyncAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: _syncing ? null : _handleTap,
    );
  }
}

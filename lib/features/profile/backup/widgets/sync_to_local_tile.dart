import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/drive_link_state.dart';
import 'package:seek_player/core/sync/drive_link_controller.dart';
import 'package:seek_player/core/sync/sync_google_drive_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/backup/providers/last_sync_at_provider.dart';
import 'package:seek_player/features/profile/backup/widgets/sync_outcome_toast.dart';

/// 「同步到本地」ListTile:確認後不比時戳,把雲端有的檔全部拉下來覆寫本機
/// (換機 / 誤刪後手動救回)。未連結時 disabled。
class SyncToLocalTile extends ConsumerStatefulWidget {
  const SyncToLocalTile({super.key});

  @override
  ConsumerState<SyncToLocalTile> createState() => _SyncToLocalTileState();
}

class _SyncToLocalTileState extends ConsumerState<SyncToLocalTile> {
  bool _syncing = false;

  Future<void> _handleTap() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_sync_to_local),
        content: Text(l10n.backup_sync_to_local_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    final outcome = await ref
        .read(syncGoogleDriveServiceProvider)
        .syncToLocal();
    ref.invalidate(lastSyncAtProvider);
    if (!mounted) return;
    setState(() => _syncing = false);
    showSyncOutcomeToast(l10n, outcome, doneMessage: l10n.backup_restored);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final linked = ref.watch(driveLinkStateProvider) is DriveLinked;
    return ListTile(
      enabled: linked && !_syncing,
      leading: _syncing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Icon(Icons.cloud_download_outlined),
      title: Text(l10n.backup_sync_to_local),
      onTap: linked && !_syncing ? _handleTap : null,
    );
  }
}

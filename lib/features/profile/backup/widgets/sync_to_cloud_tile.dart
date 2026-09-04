import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:seek_player/core/sync/drive_link_state.dart';
import 'package:seek_player/core/sync/drive_link_controller.dart';
import 'package:seek_player/core/sync/sync_google_drive_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/backup/providers/last_sync_at_provider.dart';
import 'package:seek_player/features/profile/backup/widgets/sync_outcome_toast.dart';

/// 「同步到雲端」ListTile:手動觸發一次上傳(四領域仍各自依時戳判斷),
/// 結束後 toast 回報並刷新 trailing 的上次同步時間。未連結時 disabled。
class SyncToCloudTile extends ConsumerStatefulWidget {
  const SyncToCloudTile({super.key});

  @override
  ConsumerState<SyncToCloudTile> createState() => _SyncToCloudTileState();
}

class _SyncToCloudTileState extends ConsumerState<SyncToCloudTile> {
  bool _syncing = false;

  Future<void> _handleTap() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _syncing = true);
    final outcome = await ref
        .read(syncGoogleDriveServiceProvider)
        .syncToCloud();
    ref.invalidate(lastSyncAtProvider);
    if (!mounted) return;
    setState(() => _syncing = false);
    showSyncOutcomeToast(l10n, outcome, doneMessage: l10n.backup_done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final linked = ref.watch(driveLinkStateProvider) is DriveLinked;
    final lastSyncAt = ref.watch(lastSyncAtProvider);
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
          : const Icon(Icons.cloud_upload_outlined),
      title: Text(l10n.backup_sync_to_cloud),
      trailing: Text(
        lastSyncAt == null
            ? l10n.backup_never_synced
            : DateFormat.yMd(
                Localizations.localeOf(context).toString(),
              ).add_Hm().format(lastSyncAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: linked && !_syncing ? _handleTap : null,
    );
  }
}

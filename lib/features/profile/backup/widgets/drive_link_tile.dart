import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/drive_link_controller.dart';
import 'package:seek_player/core/sync/drive_link_state.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 備份頁最上方的 Google Drive 連結狀態列:未連結 → 「連結」;已連結顯示
/// email → 「解除連結」(先確認);授權失效 → 「重新連結」。
class DriveLinkTile extends ConsumerStatefulWidget {
  const DriveLinkTile({super.key});

  @override
  ConsumerState<DriveLinkTile> createState() => _DriveLinkTileState();
}

class _DriveLinkTileState extends ConsumerState<DriveLinkTile> {
  bool _busy = false;

  Future<void> _link() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final ok = await ref.read(driveLinkStateProvider.notifier).link();
    if (!mounted) return;
    setState(() => _busy = false);
    // 取消登入 / 拒絕授權不算失敗(狀態不變),不跳 toast。
    if (!ok && ref.read(driveLinkStateProvider) is! DriveLinked) return;
    if (!ok) showAppToast(l10n.backup_link_failed);
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_unlink),
        content: Text(l10n.backup_unlink_confirm),
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
    setState(() => _busy = true);
    await ref.read(driveLinkStateProvider.notifier).unlink();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(driveLinkStateProvider);
    final theme = Theme.of(context);

    final (
      IconData icon,
      Color? iconColor,
      String title,
      String? subtitle,
    ) = switch (state) {
      DriveNotLinked() => (
        Icons.cloud_off_outlined,
        null,
        l10n.backup_not_linked,
        null,
      ),
      DriveLinked(:final email) => (
        Icons.cloud_done_outlined,
        theme.colorScheme.primary,
        l10n.backup_linked_as(email),
        null,
      ),
      DriveNeedsRelink(:final lastEmail) => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
        lastEmail ?? l10n.backup_not_linked,
        l10n.backup_needs_relink,
      ),
    };

    final Widget action = _busy
        ? const SizedBox(
            width: 24,
            height: 24,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : switch (state) {
            DriveNotLinked() => FilledButton(
              onPressed: _link,
              child: Text(l10n.backup_link),
            ),
            DriveLinked() => TextButton(
              onPressed: _unlink,
              child: Text(l10n.backup_unlink),
            ),
            DriveNeedsRelink() => FilledButton(
              onPressed: _link,
              child: Text(l10n.backup_relink),
            ),
          };

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: theme.colorScheme.error)),
      trailing: action,
    );
  }
}

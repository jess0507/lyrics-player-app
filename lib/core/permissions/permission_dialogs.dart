import 'package:flutter/material.dart';

import 'package:seek_player/l10n/app_localizations.dart';

/// 系統權限請求前的自訂說明 Dialog。回傳 true 代表使用者同意繼續。
Future<bool?> showPermissionRationaleDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.permission_title),
      content: Text(l10n.permission_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.permission_deny),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.permission_allow),
        ),
      ],
    ),
  );
}

/// 永久拒絕時，引導前往應用程式設定。回傳 true 代表使用者願意前往。
Future<bool?> showOpenSettingsDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.permission_title),
      content: Text(l10n.permission_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.permission_open_settings),
        ),
      ],
    ),
  );
}

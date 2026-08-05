import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 輸入播放清單名稱的對話框,建立與重新命名共用。
/// 回傳整理後的名稱;取消或留空回 null。
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
}) {
  final controller = TextEditingController(text: initialName);
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l10n.playlist_name_hint),
        onSubmitted: (value) => Navigator.of(context).pop(_clean(value)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_clean(controller.text)),
          child: Text(l10n.common_confirm),
        ),
      ],
    ),
  );
}

String? _clean(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

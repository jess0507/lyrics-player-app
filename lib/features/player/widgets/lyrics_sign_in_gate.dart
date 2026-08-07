import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/account/account_page.dart';

/// 雲端歌詞功能(自動產生 / 自動對時)執行前的登入關卡。
///
/// 已登入回傳 true;未登入(或 Firebase 不可用)時以 [message] 顯示確認
/// 對話框,使用者按「登入」後開啟帳戶頁,並一律回傳 false(登入完成後
/// 由使用者自行重新觸發動作)。
Future<bool> ensureSignedInForLyrics(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) async {
  // Firebase 不可用時不可讀取 auth 相關 provider,一律視為未登入
  // (帳戶頁會顯示對應的不可用說明)。
  final signedIn =
      ref.read(firebaseAvailableProvider) &&
      ref.read(authServiceProvider).currentUser != null;
  if (signedIn) return true;

  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.account_sign_in),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    // 播放器是 root navigator 上的滿版 bottom sheet;帳戶頁疊在其上,
    // 登入完成返回後可直接回到原播放畫面。
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const AccountPage()),
    );
  }
  return false;
}

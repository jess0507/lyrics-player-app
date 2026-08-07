import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'network_status_service.dart';

/// 需要網路的動作在進入流程前先呼叫本函式守門:
/// 離線時顯示「請確認網路連線」SnackBar 並回傳 false,呼叫端直接中止;
/// context 已 unmounted 時也回傳 false。呼叫端之後若繼續使用 context,
/// 仍須自行檢查 mounted(analyzer 看不進本函式,lint 才不會誤報)。
Future<bool> ensureOnline(BuildContext context, WidgetRef ref) async {
  final online = await ref.read(networkStatusServiceProvider).isOnline();
  if (!context.mounted) return false;
  if (online) return true;
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showAppSnackBar(l10n.common_network_offline);
  return false;
}

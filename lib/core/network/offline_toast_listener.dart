import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/network/offline_event_stream.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 監聽離線事件並顯示「請確認網路連線」toast。掛在 MaterialApp 的
/// builder 內(需要 Localizations),常駐訂閱,任何頁面呼叫
/// ensureOnline 偵測到離線都由這裡提示,呼叫端不必自己處理。
class OfflineToastListener extends ConsumerWidget {
  const OfflineToastListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen<AsyncValue<int>>(offlineEventStreamProvider, (_, next) {
      if (next.hasValue) showAppToast(l10n.common_network_offline);
    });
    return child;
  }
}

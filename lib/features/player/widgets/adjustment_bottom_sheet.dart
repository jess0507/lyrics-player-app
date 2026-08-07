import 'package:flutter/material.dart';

import 'package:seek_player/l10n/app_localizations.dart';

/// 播放頁共用的調整面板:標題列(含重置按鈕)加上自訂內容(通常是數值
/// 顯示與滑桿)。播放速度與歌詞字級皆以此呈現,確保兩者外觀一致。
/// 半遮畫面,上方內容可即時預覽調整結果。
class AdjustmentBottomSheet extends StatelessWidget {
  const AdjustmentBottomSheet({
    super.key,
    required this.title,
    required this.onReset,
    required this.child,
  });

  final String title;
  final VoidCallback onReset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: onReset,
                  child: Text(l10n.common_reset),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

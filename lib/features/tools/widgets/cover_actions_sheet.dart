import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';
import 'package:seek_player/features/player/widgets/cover_actions.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具分頁「更改封面」的底部表單:新增 / 更換封面,有自訂封面時可移除。
///
/// 後續動作以呼叫端的 [context]/[ref] 執行,避免本表單關閉後沿用已失效的 context。
void showCoverActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _CoverActionsSheet(
      parentContext: context,
      parentRef: ref,
      trackId: trackId,
    ),
  );
}

class _CoverActionsSheet extends ConsumerWidget {
  const _CoverActionsSheet({
    required this.parentContext,
    required this.parentRef,
    required this.trackId,
  });

  /// 呼叫端(選曲頁)的 context 與 ref,生命週期不隨本表單結束。
  final BuildContext parentContext;
  final WidgetRef parentRef;

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // 只有自訂封面能移除;內嵌封面不受影響,故不看 embedded artwork。
    final hasCover = ref.watch(trackCoverProvider(trackId)).valueOrNull != null;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(hasCover ? l10n.cover_change : l10n.cover_add),
            onTap: () {
              Navigator.of(context).pop();
              setTrackCover(parentContext, parentRef, trackId);
            },
          ),
          if (hasCover)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: Text(l10n.cover_remove),
              onTap: () {
                Navigator.of(context).pop();
                removeTrackCover(parentContext, parentRef, trackId);
              },
            ),
        ],
      ),
    );
  }
}

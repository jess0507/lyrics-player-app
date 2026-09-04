import 'package:flutter/material.dart';

import 'package:seek_player/features/profile/backup/widgets/backup_info_bubble.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「上次備份」列右側的 info 按鈕:點選後在按鈕下方浮出備份內容說明
/// (`backup_description`),氣泡帶一個指向按鈕的箭頭;再點按鈕或
/// 點擊說明以外的任何地方即收起,且該點擊照常傳給底下的元件。
///
/// 不用 Material [Tooltip]:它沒有箭頭,氣泡被螢幕邊緣往內推後也
/// 無從得知按鈕相對氣泡的位置。改以 [OverlayPortal] 自行浮出
/// [BackupInfoBubble],位置與箭頭一起算。
class BackupInfoButton extends StatefulWidget {
  const BackupInfoButton({super.key});

  @override
  State<BackupInfoButton> createState() => _BackupInfoButtonState();
}

class _BackupInfoButtonState extends State<BackupInfoButton> {
  final _overlay = OverlayPortalController();

  /// 讓按鈕與氣泡同屬一個 [TapRegion] 群組:點按鈕不算「點在氣泡外」,
  /// 由 [_toggle] 決定開關,避免先收起又立刻重開。
  final _tapGroup = Object();

  /// 按鈕在 overlay 座標系的矩形,顯示時計算,供氣泡定位與畫箭頭。
  Rect _target = Rect.zero;

  void _toggle() {
    if (_overlay.isShowing) {
      _overlay.hide();
      return;
    }
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    _target = origin & button.size;
    _overlay.show();
  }

  void _hide() {
    if (_overlay.isShowing) _overlay.hide();
  }

  Widget _buildBubble(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: BackupInfoBubble(
        target: _target,
        color: scheme.inverseSurface,
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _hide(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              l10n.backup_description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onInverseSurface,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: _buildBubble,
      child: TapRegion(
        groupId: _tapGroup,
        child: IconButton(
          icon: const Icon(Icons.info_outline),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          color: scheme.onSurfaceVariant,
          onPressed: _toggle,
        ),
      ),
    );
  }
}

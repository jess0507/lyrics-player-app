import 'package:flutter/material.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';

/// 選曲 / 清單頁頂欄的搜尋欄位:膠囊底色、左側搜尋 icon + 提示文字,
/// 開啟即聚焦。
/// 關閉搜尋由頂欄左側的返回鍵處理,欄位本身不帶關閉按鈕。
class TrackSearchField extends StatelessWidget {
  const TrackSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.music_search,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
          child: SvgIcon(
            Assets.icon.search,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 12, 16, 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

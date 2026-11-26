import 'package:flutter/material.dart';
import 'package:seek_player/features/library/models/library_section.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「媒體庫」頂欄下方的區塊切換列:每個 [LibrarySection] 一顆膠囊形
/// [ChoiceChip],外觀與本地音樂的資料夾篩選一致。
class LibrarySectionChips extends StatelessWidget {
  const LibrarySectionChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final LibrarySection selected;
  final ValueChanged<LibrarySection> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: Row(
        spacing: 8,
        children: [
          for (final section in LibrarySection.values)
            ChoiceChip(
              label: Text(section.label(l10n)),
              selected: section == selected,
              // 選中的再點一次不取消,維持恰好一個區塊被選中。
              onSelected: (_) => onSelected(section),
              showCheckmark: false,
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
import 'package:seek_player/features/cover/services/cover_import_service.dart';

/// 挑圖並設為曲目自訂封面(新增 / 更換)。成功以 toast 回饋,
/// 例外映射 l10n 失敗文案;使用者取消選圖不提示。
Future<void> setTrackCover(
  BuildContext context,
  WidgetRef ref,
  String trackId,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final done =
        await ref.read(coverImportServiceProvider).pickAndSetForTrack(trackId);
    if (!done) return; // 使用者取消
    showAppToast(l10n.cover_updated);
  } on CoverImportException catch (e, s) {
    reportError(e, s, reason: '匯入封面失敗（${e.error.name}）');
    showAppToast(_errorText(l10n, e.error));
  }
}

/// 移除曲目自訂封面並以 toast 回饋(僅自訂封面,內嵌封面不受影響)。
Future<void> removeTrackCover(
  BuildContext context,
  WidgetRef ref,
  String trackId,
) async {
  final l10n = AppLocalizations.of(context)!;
  await ref.read(coverImportServiceProvider).removeForTrack(trackId);
  showAppToast(l10n.cover_removed);
}

String _errorText(AppLocalizations l10n, CoverImportError error) =>
    switch (error) {
      CoverImportError.tooLarge => l10n.cover_too_large,
      CoverImportError.unreadable => l10n.cover_failed,
    };

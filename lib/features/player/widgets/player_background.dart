import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/shared/providers/settings_controller.dart';
import 'package:seek_player/features/cover/services/cover_color.dart';
import 'package:seek_player/features/cover/providers/track_cover_color_provider.dart';

/// 播放頁的漸層背景:由主題的 [ColorScheme] 推導,
/// 上方漸濃染上強調色、向下淡出為 [ColorScheme.surface]。
///
/// 兩個端點都疊合在 `surface` 之上,因此深 / 淺色主題皆能取得柔和且
/// 與強調色一致的漸層;底部與承載播放頁的 sheet 背景(同為 `surface`)
/// 無縫銜接。子內容(透明的 Scaffold)直接疊在漸層之上。
///
/// 強調色預設取主題色;當使用者開啟「封面色漸層」且目前曲目 [trackId]
/// 有可解析的封面時,改用封面主色([trackCoverColorProvider]),無封面或
/// 解析失敗則退回主題色。關閉漸層時改以純 `surface` 背景呈現。
class PlayerBackground extends ConsumerWidget {
  const PlayerBackground({super.key, required this.child, this.trackId});

  final Widget child;
  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final useGradient = ref.watch(
      settingsControllerProvider.select((s) => s.useGradient),
    );
    if (!useGradient) {
      return DecoratedBox(
        decoration: BoxDecoration(color: scheme.surface),
        child: child,
      );
    }

    final fromCover = ref.watch(
      settingsControllerProvider.select((s) => s.gradientFromCover),
    );
    Color? coverColor;
    final id = trackId;
    if (fromCover && id != null) {
      final raw = ref.watch(trackCoverColorProvider(id)).valueOrNull;
      // 只取封面色的色相 / 飽和度,明度依當前主題固定,避免不同封面造成
      // 漸層忽明忽暗。
      if (raw != null) {
        coverColor = normalizeCoverColor(raw, Theme.of(context).brightness);
      }
    }
    final accent = coverColor ?? scheme.primary;

    // 封面色漸層採較重的疊加比例:頂部接近純封面色,故主色明顯且該區域
    // 幾乎不受深 / 淺色主題明暗影響;主題色漸層維持原本柔和的比例。
    // 底部兩者皆淡出為 surface,與 sheet 背景銜接。
    final midAlpha = coverColor != null ? 0.45 : 0.08;
    final bottomAlpha = coverColor != null ? 0.85 : 0.28;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            scheme.surface,
            Color.alphaBlend(
              accent.withValues(alpha: midAlpha),
              scheme.surface,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: bottomAlpha),
              scheme.surface,
            ),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
}

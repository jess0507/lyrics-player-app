import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/update/shorebird_updater_provider.dart';

/// 目前「正在執行」的 Shorebird patch 編號;沒套用 patch、debug build
/// 或非 shorebird build 時為 null。
///
/// 已下載但尚未重啟生效的 patch 不算(那是 next patch)。執行中的 patch 在
/// 這次啟動期間不會變,provider 天然快取即可。
final currentPatchNumberProvider = FutureProvider<int?>((ref) async {
  final updater = ref.read(shorebirdUpdaterProvider);
  if (!updater.isAvailable) return null;
  try {
    return (await updater.readCurrentPatch())?.number;
  } catch (_) {
    // 讀不到就當作沒有 patch,不影響版本顯示與同步。
    return null;
  }
});

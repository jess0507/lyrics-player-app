import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:seek_player/core/update/current_patch_number_provider.dart';

/// 取目前安裝 app 的版本字串,依專案慣例以 v 開頭:`vX.Y.Z (buildNumber)`。
///
/// buildNumber 是建置時寫進 APK 的 versionCode,Shorebird 熱更新不會改變它,
/// 所以有套用 patch 時在後面補上 patch 編號(例如 `v1.2.18 (123) patch 2`,
/// Shorebird 建議的顯示方式),才分得出有沒有熱更新。
/// 安裝後 / 這次啟動期間不會變動,provider 天然快取即可。
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final patch = await ref.watch(currentPatchNumberProvider.future);
  final base = 'v${info.version} (${info.buildNumber})';
  // 沒有 patch(null)或編號為 0 都視為未套用熱更新,不顯示 patch。
  return patch == null || patch <= 0 ? base : '$base patch $patch';
});

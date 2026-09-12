import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 取目前安裝 app 的版本字串,依專案慣例以 v 開頭(vX.Y.Z+buildNumber)。
/// 安裝後不會變動,provider 天然快取即可。
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version}+${info.buildNumber}';
});

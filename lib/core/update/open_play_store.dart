import 'package:url_launcher/url_launcher.dart';

import 'package:seek_player/core/crash_reporter.dart';

const _packageId = 'com.js.seek_player';

/// 優先開啟 Google Play App 的商店頁,失敗時退回瀏覽器版。
Future<void> openPlayStore() async {
  final market = Uri.parse('market://details?id=$_packageId');
  final web = Uri.parse(
    'https://play.google.com/store/apps/details?id=$_packageId',
  );
  try {
    final launched = await launchUrl(
      market,
      mode: LaunchMode.externalApplication,
    );
    if (launched) return;
  } catch (e, s) {
    // 裝置上沒有 Play 商店 app 時走瀏覽器版。
    reportError(e, s, reason: '開啟 Play 商店 app 失敗，退回瀏覽器版');
  }
  await launchUrl(web, mode: LaunchMode.externalApplication);
}

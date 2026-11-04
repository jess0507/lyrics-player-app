import 'package:flutter/widgets.dart';
import 'package:seek_player/core/network/offline_toast_listener.dart';
import 'package:seek_player/core/update/app_update_listener.dart';
import 'package:seek_player/shared/widgets/track_entity_migration_gate.dart';

/// 疊在整個 app 上的全域狀態顯示,統一在 `MaterialApp.builder` 套一次:
/// - 離線提示:各頁面 ensureOnline 送出的離線事件顯示 toast([OfflineToastListener])。
/// - 更新提示:Google Play 新版本優先,其次 Shorebird patch 重啟提示([AppUpdateListener])。
/// - 版本升級的一次性資料遷移:需要時蓋上 loading 直到結束([TrackEntityMigrationGate])。
class AppStatusLayer extends StatelessWidget {
  const AppStatusLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => OfflineToastListener(
    child: AppUpdateListener(child: TrackEntityMigrationGate(child: child)),
  );
}

import 'package:seek_player/core/sync/sync_domain.dart';

/// 登入同步的方向判斷結果(SyncService.prepareSignInSync 產生):
/// 只有雲端有資料的領域拉、只有本機有的推、兩邊都有的列為衝突
/// 等使用者選擇(SyncService.applySignInSync 套用)。
class SignInSyncPlan {
  const SignInSyncPlan({
    required this.uid,
    required this.pull,
    required this.push,
    required this.conflicts,
  });

  final String uid;
  final Set<SyncDomain> pull;
  final Set<SyncDomain> push;

  /// 本機與雲端都有資料的領域(依 [SyncDomain] 宣告順序)。
  final List<SyncDomain> conflicts;
}

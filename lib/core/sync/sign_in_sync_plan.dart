import 'package:seek_player/core/sync/sync_domain.dart';

/// 登入同步的方向判斷結果(SyncService.prepareSignInSync 產生,
/// SyncService.applySignInSync 套用):只有雲端有資料的領域拉、只有本機
/// 有的推、兩邊都有的把雲端併進本機(以雲端為主,當下不推)。
class SignInSyncPlan {
  const SignInSyncPlan({
    required this.uid,
    required this.pull,
    required this.push,
    required this.merge,
  });

  final String uid;
  final Set<SyncDomain> pull;
  final Set<SyncDomain> push;

  /// 本機與雲端都有資料、需要合併的領域。
  final Set<SyncDomain> merge;
}

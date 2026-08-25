import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/crash_reporter.dart';

/// 檢查目前登入使用者的免費歌詞辨識/對時額度是否已達本月上限。
///
/// 對比 `setting/appConfig.freeUserMonthlyLimitMinutes`(系統規定的單月
/// 上限,分鐘)與 `usage/{uid}.secondsUsed`(目前使用量,秒)。任一讀取
/// 失敗或尚未設定上限時一律視為未達上限放行,實際硬性限制仍由後端
/// callable(`generate_lyrics` / `align_lyrics`)把關。
class LyricsUsageLimitService {
  LyricsUsageLimitService(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<bool> isMonthlyLimitReached() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final configSnapshot = await _firestore
          .collection('setting')
          .doc('appConfig')
          .get();
      final limitMinutes =
          (configSnapshot.data()?['freeUserMonthlyLimitMinutes'] as num?)
              ?.toDouble();
      if (limitMinutes == null) return false;

      final usageSnapshot = await _firestore.collection('usage').doc(uid).get();
      final secondsUsed =
          (usageSnapshot.data()?['secondsUsed'] as num?)?.toDouble() ?? 0;

      return secondsUsed >= limitMinutes * 60;
    } catch (e, s) {
      reportError(e, s, reason: '檢查歌詞用量上限失敗,放行');
      return false;
    }
  }
}

final lyricsUsageLimitServiceProvider = Provider<LyricsUsageLimitService>((
  ref,
) {
  return LyricsUsageLimitService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

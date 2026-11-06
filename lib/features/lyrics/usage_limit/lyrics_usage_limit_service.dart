import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/crash_reporter.dart';

/// [LyricsUsageLimitService.check] 的結果。
sealed class LyricsUsageCheck {
  const LyricsUsageCheck();
}

/// 額度足夠(或無法判斷,一律放行)。
class LyricsUsageOk extends LyricsUsageCheck {
  const LyricsUsageOk();
}

/// 本月額度已用完。
class LyricsUsageLimitReached extends LyricsUsageCheck {
  const LyricsUsageLimitReached();
}

/// 本月尚有額度,但不足以處理這段音訊。
class LyricsUsageInsufficient extends LyricsUsageCheck {
  const LyricsUsageInsufficient({
    required this.remainingSeconds,
    required this.audioSeconds,
  });

  final double remainingSeconds;
  final double audioSeconds;
}

/// 檢查目前登入使用者的免費歌詞辨識/對時額度。
///
/// 對比 `setting/appConfig.freeUserMonthlyMinutes`(系統規定的單月上限,
/// 分鐘)與 `usage/{uid}`(`{month: "YYYY-MM", secondsUsed}`,目前使用量,
/// 秒;`month` 不是當月 UTC 月份即視為 0,與後端跨月判定一致)。
/// 任一讀取失敗或尚未設定上限時一律放行,實際硬性限制仍由後端
/// callable(`generate_lyrics` / `align_lyrics`)與 Cloud Run 服務把關。
class LyricsUsageLimitService {
  LyricsUsageLimitService(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 檢查本月額度;有帶 [audioSeconds] 時一併確認「已用量 + 這段音訊長度」
  /// 不超過上限。
  Future<LyricsUsageCheck> check({double? audioSeconds}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const LyricsUsageOk();

    try {
      final config =
          (await _firestore.collection('setting').doc('appConfig').get())
              .data();
      // 雲端實際欄位為 freeUserMonthlyMinutes;舊名 freeUserMonthlyLimitMinutes
      // 僅作相容。
      final limitMinutes =
          ((config?['freeUserMonthlyMinutes'] ??
                      config?['freeUserMonthlyLimitMinutes'])
                  as num?)
              ?.toDouble();
      if (limitMinutes == null) return const LyricsUsageOk();
      final limitSeconds = limitMinutes * 60;

      final usage = (await _firestore.collection('usage').doc(uid).get())
          .data();
      final usedSeconds = usage?['month'] == _currentMonthUtc()
          ? (usage?['secondsUsed'] as num?)?.toDouble() ?? 0
          : 0.0;

      if (usedSeconds >= limitSeconds) return const LyricsUsageLimitReached();
      if (audioSeconds != null && usedSeconds + audioSeconds > limitSeconds) {
        return LyricsUsageInsufficient(
          remainingSeconds: limitSeconds - usedSeconds,
          audioSeconds: audioSeconds,
        );
      }
      return const LyricsUsageOk();
    } catch (e, s) {
      reportError(e, s, reason: '檢查歌詞用量上限失敗,放行');
      return const LyricsUsageOk();
    }
  }

  /// 與後端 `datetime.now(timezone.utc).strftime("%Y-%m")` 相同格式。
  static String _currentMonthUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
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

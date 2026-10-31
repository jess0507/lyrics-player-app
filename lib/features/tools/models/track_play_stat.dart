/// 曲目的播放紀錄,供選曲頁依播放次數 / 最近播放排序。
class TrackPlayStat {
  const TrackPlayStat({required this.playCount, required this.lastPlayed});

  /// 聆聽統計中的累計播放次數。
  final int playCount;

  /// 最近一次播放時間;「最近播放」清單有紀錄時為精確時間,
  /// 否則退回聆聽統計中最後一次播放的日期(當日 0 點)。
  final DateTime? lastPlayed;
}

/// 曲目檔案的 stat 資訊,供工具選曲頁顯示大小與排序。
class TrackFileStat {
  const TrackFileStat({required this.sizeBytes, required this.modified});

  final int sizeBytes;

  /// 檔案最後修改時間;Track 不帶 MediaStore 的加入時間,以此近似「加入時間」。
  final DateTime modified;
}

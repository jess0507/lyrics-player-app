/// Google Drive `appDataFolder` 裡一個備份檔的 metadata(`files.list` /
/// 上傳回應的子集),供 SyncGoogleDriveService 比對時戳與 schemaVersion 用。
class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    required this.schemaVersion,
  });

  /// Drive 檔案 id(後續上傳 / 下載 / 刪除都靠它)。
  final String id;

  /// 檔名,對應四個領域(`settings.json` 等)。
  final String name;

  /// Drive 伺服器時鐘的最後修改時間(UTC),推 / 拉時與本機
  /// `*ModifiedAt` 比對。
  final DateTime modifiedTime;

  /// `appProperties.schemaVersion`;缺或非數字時為 null(視為最舊版)。
  final int? schemaVersion;

  /// 自訂屬性 key。Drive 的 appProperties 值一律是字串。
  static const schemaVersionKey = 'schemaVersion';

  /// `files` 資源 JSON -> 模型;`modifiedTime` 缺或格式不對時回 null。
  static DriveBackupFile? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final modified = DateTime.tryParse('${json['modifiedTime']}');
    if (id is! String || name is! String || modified == null) return null;
    final props = json['appProperties'];
    return DriveBackupFile(
      id: id,
      name: name,
      modifiedTime: modified.toUtc(),
      schemaVersion: props is Map
          ? int.tryParse('${props[schemaVersionKey]}')
          : null,
    );
  }
}

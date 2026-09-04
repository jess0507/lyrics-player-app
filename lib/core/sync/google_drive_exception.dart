/// Drive API 錯誤分類(SyncGoogleDriveService / 備份頁據此決定重試、
/// 標記需重新連結或顯示文案)。
enum GoogleDriveErrorKind {
  /// 401:token 失效且清快取重試一次仍失敗,或 Google session 不可用 /
  /// 已換成別的帳號 → 需重新連結。
  unauthorized,

  /// 403 `insufficientPermissions`:`drive.appdata` scope 被撤銷 → 需重新連結。
  insufficientScope,

  /// 403 `accessNotConfigured`:Cloud 專案沒開 Google Drive API(開發期設定錯誤)。
  apiNotEnabled,

  /// 403 `storageQuotaExceeded`:使用者的 Drive 空間滿了。
  quotaExceeded,

  /// 404:檔案已不存在(例如使用者在 Drive 設定刪掉 App 資料)。
  notFound,

  /// 其他非 2xx。
  other,
}

class GoogleDriveException implements Exception {
  GoogleDriveException(this.kind, this.statusCode, this.message);

  final GoogleDriveErrorKind kind;

  /// HTTP 狀態碼;非 HTTP 來源(session 不可用)為 0。
  final int statusCode;
  final String message;

  /// 需要使用者重新走一次連結流程才可能恢復。
  bool get needsRelink =>
      kind == GoogleDriveErrorKind.unauthorized ||
      kind == GoogleDriveErrorKind.insufficientScope;

  @override
  String toString() => 'GoogleDriveException($kind, $statusCode): $message';
}

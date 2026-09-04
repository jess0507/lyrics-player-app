/// Google Drive 備份連結的 UI 狀態(備份頁顯示、SyncGoogleDriveService 據此決定
/// 是否可同步)。
sealed class DriveLinkState {
  const DriveLinkState();

  /// 已連結且 session 可用時的 email,否則 null。
  String? get email => null;

  bool get isLinked => this is DriveLinked;
}

/// 從未連結,或已解除連結。
class DriveNotLinked extends DriveLinkState {
  const DriveNotLinked();
}

/// 已連結,session 可用,可以同步。
class DriveLinked extends DriveLinkState {
  const DriveLinked(this.email);

  @override
  final String email;
}

/// 曾連結但授權已失效(使用者在 Google 端撤銷、token 取不回、API 回
/// 401 / 403),需使用者重新走連結流程;在此之前不同步。
class DriveNeedsRelink extends DriveLinkState {
  const DriveNeedsRelink(this.lastEmail);

  /// 上次連結的 email(顯示用)。
  final String? lastEmail;
}

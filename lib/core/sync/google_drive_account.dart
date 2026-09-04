import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:seek_player/core/auth/google_sign_in_provider.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/core/sync/google_drive_exception.dart';

/// Google Drive 備份用的 Google 帳號授權:連結 / 解除 / 啟動時取回 session
/// / 供 GoogleDriveClient 取 Authorization header。
///
/// 與 Firebase 登入脫鉤:任何人(Email / 手機 / Facebook 登入者,或完全
/// 沒登入 Firebase 的人)都能連結一個 Google 帳號來備份。連結狀態持久化
/// 在 prefs;UI 狀態由 DriveLinkController 管理。
///
/// 與 Firebase 的 Google 登入共用同一個 GoogleSignIn 實例,裝置上同一
/// 時間只有一個 Google session:使用者若用「另一個」Google 帳號登入
/// Firebase,session 就換成那個帳號,這裡以 email 比對連結時記下的帳號,
/// 不一致視為 session 不可用(標記需重新連結),絕不拿錯的帳號上傳。
class GoogleDriveAccount {
  GoogleDriveAccount(this._googleSignIn, this._prefs);

  /// 僅能存取 App 自己的 appDataFolder,Google 列為 non-sensitive scope。
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';

  static const _kLinked = 'backup.driveLinked';
  static const _kEmail = 'backup.driveEmail';

  final GoogleSignIn _googleSignIn;
  final PreferencesService _prefs;

  /// 使用者是否曾完成連結(prefs 記錄;不代表當下 session 有效)。
  bool get isLinked => _prefs.getBool(_kLinked) ?? false;

  /// 連結的 Google 帳號 email(顯示用)。
  String? get linkedEmail => _prefs.getString(_kEmail);

  /// 當下 Google session 是否可用,且是連結時的那個帳號。
  bool get hasSession => _sessionAccount != null;

  /// 目前 session 的帳號;未登入或不是連結的帳號時為 null。
  GoogleSignInAccount? get _sessionAccount {
    final account = _googleSignIn.currentUser;
    if (account == null) return null;
    final linked = linkedEmail;
    if (linked != null && account.email != linked) return null;
    return account;
  }

  /// 連結:沒有 Google session 就先登入(帳號選擇器),再以增量授權請求
  /// `drive.appdata`(已用 Google 登入 Firebase 的人只會看到這一頁同意畫面)。
  /// 回傳連結的 email;使用者取消登入或拒絕授權回傳 null。
  Future<String?> link() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    try {
      account ??= await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      if (e.code == GoogleSignIn.kSignInCanceledError) return null;
      rethrow;
    }
    if (account == null) return null;

    final granted = await _googleSignIn.requestScopes(const [scope]);
    if (!granted) {
      debugPrint('[Drive] 使用者拒絕 drive.appdata 授權');
      return null;
    }
    await _prefs.setBool(_kLinked, true);
    await _prefs.setString(_kEmail, account.email);
    return account.email;
  }

  /// 解除連結:撤銷授權並清本機連結狀態。Drive 上的備份檔保留,
  /// 再連結同帳號可直接還原。
  Future<void> unlink() async {
    try {
      await _googleSignIn.disconnect();
    } on PlatformException catch (e, s) {
      // 已離線 / token 已失效時 disconnect 會失敗,本機狀態仍要清。
      debugPrint('[Drive] disconnect 失敗($e)\n$s');
      await _googleSignIn.signOut();
    }
    await _prefs.remove(_kLinked);
    await _prefs.remove(_kEmail);
  }

  /// App 啟動時取回 Google session(不跳 UI)。未曾連結直接回 false;
  /// 曾連結但取不回(使用者在 Google 端撤銷、token 失效)也回 false,
  /// 由呼叫端標記「需要重新連結」。
  Future<bool> restoreSession() async {
    if (!isLinked) return false;
    return await _ensureSession() != null;
  }

  /// 有 session 直接用;沒有(App 剛啟動、或 Firebase Google 登入前清掉了)
  /// 就 signInSilently 取回;取回的不是連結的帳號一律當沒有。
  Future<GoogleSignInAccount?> _ensureSession() async {
    if (_sessionAccount case final account?) return account;
    try {
      await _googleSignIn.signInSilently();
    } catch (e, s) {
      debugPrint('[Drive] signInSilently 失敗($e)\n$s');
      return null;
    }
    final account = _sessionAccount;
    if (account == null && _googleSignIn.currentUser != null) {
      debugPrint(
        '[Drive] 目前 Google session(${_googleSignIn.currentUser!.email})'
        '不是連結的帳號($linkedEmail)',
      );
    }
    return account;
  }

  /// Authorization header(google_sign_in 會視需要換新 access token)。
  /// session 不可用或不是連結的帳號時丟 unauthorized,SyncGoogleDriveService
  /// 據此標記需重新連結。
  Future<Map<String, String>> authHeaders() async {
    final account = await _ensureSession();
    if (account == null) {
      throw GoogleDriveException(
        GoogleDriveErrorKind.unauthorized,
        0,
        'Google session 不可用或不是連結的帳號',
      );
    }
    return account.authHeaders;
  }

  /// 401 時由 GoogleDriveClient 呼叫,讓下一次 authHeaders 重新取 token。
  Future<void> clearAuthCache() async =>
      _googleSignIn.currentUser?.clearAuthCache();
}

final googleDriveAccountProvider = Provider<GoogleDriveAccount>(
  (ref) => GoogleDriveAccount(
    ref.watch(googleSignInProvider),
    ref.watch(preferencesServiceProvider),
  ),
);

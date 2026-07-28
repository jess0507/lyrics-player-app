import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 必須與 Cloud Functions 部署的 region(`functions/main.py` 的 `_REGION`)一致。
const _functionsRegion = 'asia-east1';

/// Firebase Authentication 封裝：Email/密碼 / 手機 OTP / Google / Facebook。
class AuthService {
  AuthService(this._auth, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 以 email/密碼登入(帳號需已存在)。
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// 以 email/密碼註冊新帳號並登入。
  Future<void> signUpWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// 寄送密碼重設信。
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Google 登入。需在 Firebase Console 設定 SHA-1 並產生 OAuth client，否則會失敗。
  Future<void> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return; // 使用者取消
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  /// Facebook 登入。走 Firebase 內建的 provider 流程(開啟系統瀏覽器),
  /// 不需 Facebook SDK;需在 Firebase Console 啟用 Facebook 登入方式
  /// (填入 Meta App ID / App Secret),否則會失敗。
  Future<void> signInWithFacebook() async {
    try {
      await _auth.signInWithProvider(FacebookAuthProvider());
    } on FirebaseAuthException catch (e) {
      // 使用者中途關閉瀏覽器視為取消,不視為錯誤。
      if (e.code == 'web-context-canceled' || e.code == 'canceled') return;
      rethrow;
    }
  }

  /// 手機簡訊 OTP:寄送驗證碼。需在 Firebase Console 啟用 Phone 登入方式。
  ///
  /// 回傳由 `codeSent` 回呼取得的 verificationId,供 [signInWithSmsCode] 使用。
  /// [onAutoVerified] 在部分 Android 裝置自動帶入驗證碼時直接完成登入。
  Future<String> sendPhoneOtp(
    String phoneNumber, {
    void Function()? onAutoVerified,
  }) async {
    final completer = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        onAutoVerified?.call();
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );
    return completer.future;
  }

  /// 以收到的簡訊驗證碼([smsCode])配合 [verificationId] 完成登入。
  Future<void> signInWithSmsCode(String verificationId, String smsCode) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// 只刪除使用者的雲端資料(Firestore `user/{uid}`),保留登入帳號。
  ///
  /// 由 Cloud Function `delete_account_data` 以 Admin SDK 執行。
  Future<void> deleteAccountData() async {
    await _functions.httpsCallable('delete_account_data').call();
  }

  /// 刪除使用者雲端資料後刪除其 Firebase Auth 帳號,最後在本地登出。
  ///
  /// 由 Cloud Function `delete_account` 以 Admin SDK 執行,避免 client 端
  /// `currentUser.delete()` 需要近期重新登入而失敗。
  Future<void> deleteAccount() async {
    await _functions.httpsCallable('delete_account').call();
    await signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    FirebaseAuth.instance,
    FirebaseFunctions.instanceFor(region: _functionsRegion),
  );
});

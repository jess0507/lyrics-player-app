import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 全 App 共用的 [GoogleSignIn] 實例:Firebase 的 Google 登入
/// (`AuthService`)與 Google Drive 備份連結(`GoogleDriveAccount`)共用。
///
/// 只能有一個實例:Android 端 plugin 是原生單例,多個 `GoogleSignIn(...)`
/// 建構時各自 init 會互相蓋掉 scopes。這裡只帶預設 scopes(email /
/// profile),Drive 的 `drive.appdata` 一律由 GoogleDriveAccount 以
/// `requestScopes` 增量加,登入 Firebase 時才不會多跳雲端硬碟同意畫面。
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());

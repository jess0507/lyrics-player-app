import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/network/ensure_online.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
import 'package:seek_player/features/profile/account/widgets/country_code_dropdown.dart';

/// 未登入:選擇 Google、手機簡訊 OTP 或 Email/密碼登入。
/// 選擇手機或 Email 後,於登入選項上方顯示對應的輸入表單。
class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key});

  @override
  ConsumerState<SignInView> createState() => _SignedOutViewState();
}

/// 目前展開的登入方式(none 表示尚未選擇,只顯示選項清單)。
enum _Method { none, phone, email }

class _SignedOutViewState extends ConsumerState<SignInView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _smsCode = TextEditingController();
  bool _busy = false;
  _Method _method = _Method.none;

  /// 目前選擇的國碼(預設為清單首項台灣)。
  DialCode _dialCode = kDialCodes.first;

  /// 手機 OTP 寄出後取得的 verificationId;非 null 時顯示驗證碼輸入。
  String? _verificationId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  AuthService get _auth => ref.read(authServiceProvider);

  /// 屬於「帳號或密碼錯誤」的 FirebaseAuthException code。
  /// 新版 SDK 為避免帳號列舉,帳密錯誤一律回報 invalid-credential;
  /// 舊版則分為 wrong-password / user-not-found。
  static const _badCredentialCodes = {
    'invalid-credential',
    'wrong-password',
    'user-not-found',
    'invalid-email',
    'INVALID_LOGIN_CREDENTIALS',
  };

  /// 執行 [action],成功回傳 true、失敗顯示錯誤並回傳 false。
  /// 離線時顯示提示並直接中止,不進入流程。
  /// 未指定 [failureMessage] 時視為登入流程:帳密錯誤顯示專屬訊息,
  /// 其他錯誤顯示「登入失敗」。
  Future<bool> _run(
    Future<void> Function() action, {
    String? failureMessage,
  }) async {
    if (!await ensureOnline(context, ref) || !mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on FirebaseAuthException catch (e, s) {
      debugPrint(
        '[Account] FirebaseAuthException code=${e.code} '
        'message=${e.message}\n$s',
      );
      final isBadCredential =
          failureMessage == null && _badCredentialCodes.contains(e.code);
      _showMessage(
        isBadCredential
            ? l10n.account_invalid_credentials
            : failureMessage ?? l10n.account_sign_in_failed,
      );
      return false;
    } catch (e, s) {
      debugPrint('[Account] 登入流程錯誤:$e\n$s');
      reportError(e, s, reason: '登入流程未預期錯誤');
      _showMessage(failureMessage ?? l10n.account_sign_in_failed);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppToast(message);
  }

  /// 選擇登入方式(展開對應表單);離線時提示並不展開,
  /// 重新選擇手機時重置驗證碼狀態。
  Future<void> _select(_Method method) async {
    if (!await ensureOnline(context, ref)) return;
    setState(() {
      _method = method;
      if (method != _Method.phone) _verificationId = null;
    });
  }

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final e164 = _composeE164();
    if (e164 == null) return;
    final ok = await _run(() async {
      final id = await _auth.sendPhoneOtp(e164);
      if (mounted) setState(() => _verificationId = id);
    });
    if (ok) _showMessage(l10n.account_code_sent);
  }

  /// 將國碼與輸入號碼組成 E.164(如 `+886912345678`),無號碼時回傳 null。
  ///
  /// 移除非數字字元,並去掉主幹碼前綴的單一前導 0(多數國家適用)。
  String? _composeE164() {
    var national = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (national.startsWith('0')) national = national.substring(1);
    if (national.isEmpty) return null;
    return '${_dialCode.code}$national';
  }

  Future<void> _verifyOtp() async {
    final id = _verificationId;
    final code = _smsCode.text.trim();
    if (id == null || code.isEmpty) return;
    // 成功後 authState 變更,畫面自動切換為已登入。
    final notifySignedIn = _prepareSignedInMessage();
    final ok = await _run(() => _auth.signInWithSmsCode(id, code));
    if (ok) notifySignedIn();
  }

  /// Email/密碼登入。成功後 authState 變更,畫面自動切換為已登入。
  Future<void> _signInEmail() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    final notifySignedIn = _prepareSignedInMessage();
    final ok = await _run(() => _auth.signInWithEmail(email, password));
    if (ok) notifySignedIn();
  }

  /// Google 登入。使用者於選帳號畫面取消時不算成功也不算失敗,
  /// 以 currentUser 是否存在區分,避免取消也跳「登入成功」。
  Future<void> _signInGoogle() async {
    final auth = _auth;
    final notifySignedIn = _prepareSignedInMessage();
    final ok = await _run(auth.signInWithGoogle);
    if (ok && auth.currentUser != null) notifySignedIn();
  }

  /// 預先取得「登入成功」提示的顯示函式:成功後本視圖會被換成已登入
  /// 畫面而 unmount,須在進入流程前抓住文字,不依賴 context。
  VoidCallback _prepareSignedInMessage() {
    final l10n = AppLocalizations.of(context)!;
    return () => showAppToast(l10n.account_sign_in_success);
  }

  /// 以 email/密碼註冊新帳號(成功即自動登入)。
  Future<void> _signUpEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    await _run(
      () => _auth.signUpWithEmail(email, password),
      failureMessage: l10n.account_sign_up_failed,
    );
  }

  /// 寄送密碼重設信。
  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _email.text.trim();
    if (email.isEmpty) return;
    final ok = await _run(() => _auth.sendPasswordReset(email));
    if (ok) _showMessage(l10n.account_reset_sent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.account_signed_out_message,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        // 選擇方式後,對應輸入表單顯示於登入選項上方。
        if (_method == _Method.phone) ...[
          _phoneForm(l10n),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
        ] else if (_method == _Method.email) ...[
          _emailForm(l10n),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
        ],
        // 登入方式選項:Google → Facebook → 手機 OTP → Email 登入連結。
        OutlinedButton.icon(
          onPressed: _busy ? null : _signInGoogle,
          icon: const Icon(Icons.account_circle),
          label: Text(l10n.account_sign_in_google),
        ),
        const SizedBox(height: 8),
        // Facebook 登入暫時隱藏(Meta App / Firebase Console 尚未設定),
        // 啟用方式見 tasks/auth-supported-methods.md。
        // OutlinedButton.icon(
        //   onPressed: _busy ? null : () => _run(_auth.signInWithFacebook),
        //   icon: const Icon(Icons.facebook),
        //   label: Text(l10n.account_sign_in_facebook),
        // ),
        // const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _select(_Method.phone),
          icon: const Icon(Icons.sms_outlined),
          label: Text(l10n.account_method_phone),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _select(_Method.email),
          icon: const Icon(Icons.mail_outline),
          label: Text(l10n.account_method_email),
        ),
        if (_busy) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  /// 手機 OTP 表單:先輸入號碼寄送驗證碼,寄出後改為輸入驗證碼完成登入。
  Widget _phoneForm(AppLocalizations l10n) {
    final codeSent = _verificationId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: CountryCodeDropdown(
                value: _dialCode,
                enabled: !codeSent,
                onChanged: (c) => setState(() => _dialCode = c),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phone,
                enabled: !codeSent,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.account_phone,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        if (!codeSent) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _sendOtp,
            child: Text(l10n.account_send_code),
          ),
        ] else ...[
          const SizedBox(height: 12),
          TextField(
            controller: _smsCode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.account_sms_code,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _verifyOtp,
            child: Text(l10n.account_verify_code),
          ),
        ],
      ],
    );
  }

  /// Email/密碼表單:可登入既有帳號或註冊新帳號,並提供忘記密碼。
  Widget _emailForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.account_email,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.account_password,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _signInEmail,
          child: Text(l10n.account_sign_in),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _signUpEmail,
          child: Text(l10n.account_sign_up),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _busy ? null : _resetPassword,
            child: Text(l10n.account_forgot_password),
          ),
        ),
      ],
    );
  }
}

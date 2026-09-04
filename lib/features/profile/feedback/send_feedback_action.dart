import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 意見回饋收件信箱。
const _feedbackEmail = 'merukoo0507@gmail.com';

/// 以 mailto 開啟系統郵件 App;裝置沒有可處理的 App(或平台拒絕)時
/// 改用 toast 提示信箱,讓使用者自行寄信。
Future<void> sendFeedback(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final uri = Uri(
    scheme: 'mailto',
    path: _feedbackEmail,
    query: 'subject=${Uri.encodeComponent('Seek Player Feedback')}',
  );
  var launched = false;
  try {
    launched = await launchUrl(uri);
  } on PlatformException {
    launched = false;
  }
  if (!launched) {
    showAppToast(l10n.profile_feedback_no_mail_app(_feedbackEmail));
  }
}

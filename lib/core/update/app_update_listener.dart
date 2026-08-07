import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import '../../shared/widgets/app_toast.dart';
import '../crash_reporter.dart';
import 'patch_update_controller.dart';
import 'store_update_controller.dart';

const _packageId = 'com.js.seek_player';

/// 統一監聽兩種更新來源,並依優先序顯示提示 Dialog:
///
/// 1. Google Play 有新版本 → 只顯示「前往商店更新」dialog
///    (patch 是舊版的補丁,直接更新整包即可)。
/// 2. Play 沒有新版本、Shorebird patch 下載完成 → 顯示「重新啟動」dialog。
///    patch 就緒時若 Play 檢查還沒完成,先擱置,等結果出來再決定。
///
/// 掛在 MaterialApp 的 builder 內,同時負責啟動兩種更新檢查。
/// builder 位於 Navigator 之上,showDialog 需改用 [rootNavigatorKey]
/// 的 context。
class AppUpdateListener extends ConsumerStatefulWidget {
  const AppUpdateListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends ConsumerState<AppUpdateListener> {
  // 避免 dialog 開著時(例如切到背景再 resume 觸發重新檢查)重複疊一層。
  bool _dialogShowing = false;

  // patch 已就緒但 Play 檢查尚未完成,等結果出來再決定顯示哪個 dialog。
  bool _patchPromptPending = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<StoreUpdateState>(storeUpdateControllerProvider, (
      previous,
      next,
    ) {
      switch (next) {
        case StoreUpdateState.updateAvailable:
          // 商店更新優先,擱置中的 patch 提示不再需要。
          _patchPromptPending = false;
          _showDialog(_buildStoreDialog);
        case StoreUpdateState.upToDate:
        case StoreUpdateState.error:
          if (_patchPromptPending) {
            _patchPromptPending = false;
            _showDialog(_buildPatchDialog);
          }
        case StoreUpdateState.idle:
        case StoreUpdateState.checking:
          break;
      }
    });
    ref.listen<PatchUpdateState>(patchUpdateControllerProvider, (
      previous,
      next,
    ) {
      if (next != PatchUpdateState.restartReady) return;
      switch (ref.read(storeUpdateControllerProvider)) {
        case StoreUpdateState.updateAvailable:
          break; // 商店有新版本,只顯示 store dialog。
        case StoreUpdateState.checking:
          _patchPromptPending = true;
        case StoreUpdateState.idle: // 非 Android 不會做商店檢查。
        case StoreUpdateState.upToDate:
        case StoreUpdateState.error:
          _showDialog(_buildPatchDialog);
      }
    });
    return widget.child;
  }

  void _showDialog(Widget Function(BuildContext) builder) {
    if (_dialogShowing) return;
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;
    _dialogShowing = true;
    showDialog<void>(
      context: navigatorContext,
      builder: builder,
    ).whenComplete(() => _dialogShowing = false);
  }

  /// Google Play 有新版本:詢問是否前往商店更新。
  Widget _buildStoreDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Text(l10n.update_store_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.update_later),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            _openPlayStore();
          },
          child: Text(l10n.update_store_action),
        ),
      ],
    );
  }

  /// Shorebird patch 下載完成:詢問是否重新啟動以套用。
  Widget _buildPatchDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Text(l10n.update_ready_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.update_later),
        ),
        FilledButton(
          onPressed: () {
            if (Platform.isAndroid) {
              // 必須用 process 模式殺掉整個 process 冷啟動,
              // 預設模式只重建 Activity,engine 不重載、patch 不會生效。
              Restart.restartApp(mode: RestartMode.process);
            } else {
              // iOS 無法程式化重啟(exit 違反審核指引),
              // 請使用者手動重開。
              Navigator.of(context).pop();
              showAppToast(l10n.update_restart_manual_hint);
            }
          },
          child: Text(l10n.update_restart_action),
        ),
      ],
    );
  }

  /// 優先開啟 Google Play App 的商店頁,失敗時退回瀏覽器版。
  Future<void> _openPlayStore() async {
    final market = Uri.parse('market://details?id=$_packageId');
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_packageId',
    );
    try {
      final launched = await launchUrl(
        market,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (e, s) {
      // 裝置上沒有 Play 商店 app 時走瀏覽器版。
      reportError(e, s, reason: '開啟 Play 商店 app 失敗，退回瀏覽器版');
    }
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}

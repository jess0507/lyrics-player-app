import 'dart:async';

import 'package:flutter/material.dart';

import '../../router/app_router.dart';

OverlayEntry? _entry;

/// App 統一樣式的 toast:floating、白底、陰影、左側 app logo,
/// 淡入停留後自動淡出。與 SnackBar 不同處:
/// - 掛在 root navigator 的 Overlay,蓋在 dialog / bottom sheet 之上,
///   也不依賴呼叫端 context 生命週期(unmount 後、service 層皆可呼叫);
/// - 點擊穿透,不佔互動、不可滑動關閉。
/// 一次只顯示一則,新訊息直接取代未消失的前一則。
void showAppToast(String message) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return; // app 尚未建立完成,靜默略過
  _entry?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AppToast(
      message: message,
      onDismissed: () {
        entry.remove();
        if (_entry == entry) _entry = null;
      },
    ),
  );
  _entry = entry;
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({required this.message, required this.onDismissed});

  final String message;

  /// 淡出結束後呼叫,由建立端移除 OverlayEntry。
  final VoidCallback onDismissed;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  static const _fadeIn = Duration(milliseconds: 150);
  static const _hold = Duration(milliseconds: 2500);
  static const _fadeOut = Duration(milliseconds: 300);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _fadeIn,
    reverseDuration: _fadeOut,
  );
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _holdTimer = Timer(_fadeIn + _hold, () async {
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: IgnorePointer(
        child: SafeArea(
          child: FadeTransition(
            opacity: _controller,
            // 寬度隨內容縮、置中;過長訊息在可用寬度內自動換行。
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icon/app_logo_icon.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.fill,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// App 統一樣式的 SnackBar:floating、白底、陰影、左側 app logo。
extension AppSnackBar on ScaffoldMessengerState {
  void showAppSnackBar(String message, {double bottomOffset = 16}) {
    // 蓋過還在顯示(或排隊中)的上一個 SnackBar,不讓新訊息排隊等待。
    clearSnackBars();
    showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomOffset),
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Image.asset(
              'assets/icon/app_logo_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.fill,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

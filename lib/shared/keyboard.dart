import 'package:flutter/material.dart';

/// 收起鍵盤(清掉目前的輸入焦點)。
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// 給 `TextField.onTapOutside` 用:點到輸入框以外的任何位置(含按鈕、
/// 清單等會吃掉手勢的 widget)就收鍵盤。
///
/// 所有 `EditableText` 共用同一個 `TapRegion` group,因此在多個輸入框之間
/// 互點不會觸發,鍵盤不會閃動。
void dismissKeyboardOnTapOutside(PointerDownEvent _) => dismissKeyboard();

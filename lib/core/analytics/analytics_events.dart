/// Google Analytics 事件定義集中處:所有自訂事件、參數與登入方式都在這裡列舉,
/// 呼叫端只引用 enum,不直接寫事件名字串。
///
/// GA 端的名稱一律由 enum 識別字自動轉成 snake_case(`lyricsAction` →
/// `lyrics_action`),所以**改 enum 名稱等於改 GA 上的事件 / 參數名**,
/// 會讓後台報表斷成兩段,命名後勿隨意更動。
/// GA 規則:英數與底線、字母開頭、事件名 ≤ 40 字、參數名 ≤ 40 字。
///
/// 隱私:參數只放功能層級資訊(動作名、方式),不放 pathKey、歌名、email。
library;

/// 自訂事件。GA 建議事件(`login`、`sign_up`、`screen_view`)由 SDK 專用
/// API 送出,不列在這裡。
enum AnalyticsEvent {
  /// 歌詞選單動作;參數 [AnalyticsParam.action] = `LyricsMenuAction`
  /// (轉成 snake_case,如 `auto_align_aeneas`)。
  lyricsAction;

  /// 送到 GA 的事件名。
  String get gaName => _snakeCase(name);
}

/// 自訂事件的參數名。
enum AnalyticsParam {
  /// 觸發的動作(值傳對應功能的 enum,自動轉成 snake_case)。
  action;

  /// 送到 GA 的參數名。
  String get gaName => _snakeCase(name);
}

/// 登入方式,作為 `login` / `sign_up` 的 method 參數值。
enum AnalyticsSignInMethod {
  email,
  google,
  facebook,
  phone;

  /// 送到 GA 的 method 值。
  String get gaName => _snakeCase(name);
}

/// 參數轉成 GA 格式:參數名取 [AnalyticsParam.gaName];值為 [Enum] 時轉成
/// snake_case 名稱,讓呼叫端直接傳 enum、不必自己組字串。其餘值(數字等)原樣送出。
Map<String, Object> toGaParameters(Map<AnalyticsParam, Object> parameters) => {
  for (final MapEntry(:key, :value) in parameters.entries)
    key.gaName: value is Enum ? _snakeCase(value.name) : value,
};

/// lowerCamelCase → snake_case。
String _snakeCase(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

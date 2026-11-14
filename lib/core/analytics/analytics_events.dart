/// Google Analytics 事件定義集中處:所有自訂事件、動作、參數與登入方式都在這裡
/// 列舉,呼叫端只引用 enum,不直接寫事件名字串。
///
/// 結構:**一個功能一個事件**(`player_action`、`playlist_action`…),以
/// [AnalyticsParam.action] 區分該功能內的動作;GA 後台把 `action` 註冊成自訂
/// 維度後,即可比較各功能 / 動作的使用量(見 plans/35)。
///
/// GA 端的名稱一律由 enum 識別字自動轉成 snake_case(`lyricsAction` →
/// `lyrics_action`),所以**改 enum 名稱等於改 GA 上的事件 / 參數 / 動作名**,
/// 會讓後台報表斷成兩段,命名後勿隨意更動;新增值往後加即可。
/// GA 規則:英數與底線、字母開頭、事件名 ≤ 40 字、參數名 ≤ 40 字。
///
/// 隱私:參數只放功能層級資訊(動作名、選項、來源、結果),不放 trackId、歌名、
/// 資料夾 / 播放清單名稱、搜尋關鍵字、email、電話。
library;

/// 自訂事件(一個功能一個)。
/// GA 建議事件(`login`、`sign_up`、`screen_view`)由 SDK 專用 API 送出,不列在這裡。
enum AnalyticsEvent {
  /// 歌詞:選單動作(`LyricsMenuAction`)與其他歌詞操作([LyricsAction])。
  lyricsAction,

  /// 完整播放頁([PlayerAction])。
  playerAction,

  /// 迷你播放列([MiniPlayerAction])。
  miniPlayerAction,

  /// 本機音樂分頁([LibraryAction])。
  libraryAction,

  /// 播放清單([PlaylistAction])。
  playlistAction,

  /// 工具頁([ToolsAction])。
  toolsAction,

  /// 封面([CoverAction])。
  coverAction,

  /// 帳號([AccountAction])。
  accountAction,

  /// 備份([BackupAction])。
  backupAction,

  /// 設定([SettingsAction])。
  settingsAction,

  /// 收聽統計([StatisticsAction])。
  statisticsAction,

  /// 個人頁其他項目([ProfileAction])。
  profileAction;

  /// 送到 GA 的事件名。
  String get gaName => _snakeCase(name);
}

/// 自訂事件的參數名。後台要分析的參數需在 GA「自訂定義」註冊成事件範圍維度。
enum AnalyticsParam {
  /// 觸發的動作(值為 [AnalyticsAction] enum)。
  action,

  /// 入口 / 來源畫面([AnalyticsSource]),同一動作有多個入口時用來區分。
  source,

  /// 使用者選的值:enum(播放模式、排序欄位、主題…)、數字(速度、秒數)或 bool。
  option,

  /// 結果([AnalyticsResult] 或功能自己的錯誤 enum)。
  result;

  /// 送到 GA 的參數名。
  String get gaName => _snakeCase(name);
}

/// 可記錄的動作:每個功能的動作 enum 都實作它,並指定所屬事件。
/// 功能層自己的 enum(如 `LyricsMenuAction`)也可以直接實作,不必再對照一份。
abstract interface class AnalyticsAction implements Enum {
  AnalyticsEvent get analyticsEvent;
}

/// 動作的入口 / 來源畫面。
enum AnalyticsSource {
  player,
  miniPlayer,
  moreMenu,
  lyricsMenu,
  local,
  playlists,
  playlistDetail,
  recentlyPlayed,
  addTracks,
  editTracks,
  toolPicker,
  trackActionsSheet,
  playlistTrackActionsSheet,
  addToPlaylistSheet,
  actionsSheet,
  statusView,
  progressCard,
  list,
  file,
}

/// 通用結果。功能有更細的失敗原因 enum 時(如 `LyricsImportError`)直接傳那個。
enum AnalyticsResult { success, failure, cancelled, confirmed }

/// 登入方式,作為 `login` / `sign_up` 的 method 參數值。
enum AnalyticsSignInMethod {
  email,
  google,
  facebook,
  phone;

  /// 送到 GA 的 method 值。
  String get gaName => _snakeCase(name);
}

// ── 各功能動作 ───────────────────────────────────────────────────────────────

/// 歌詞:不經 `runLyricsMenuAction` 的操作(選單動作本身由 `LyricsMenuAction` 記)。
enum LyricsAction implements AnalyticsAction {
  cancelJob,
  onlineSearchQuery,
  onlineSearchApply,
  editSave,
  importResult,
  downloadResult,
  deleteConfirm,
  aiGenerateSubmit,
  autoAlignSubmit,
  signInPrompt,
  usageLimitReached,
  lineSeek,
  fontSizeChange,
  fontSizeReset,
  textAlignChange,
  textAlignReset,
  scrollToCurrent;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.lyricsAction;
}

/// 完整播放頁。
enum PlayerAction implements AnalyticsAction {
  closePlayer,
  playPause,
  skipPrevious,
  skipNext,
  seekForward,
  seekBackward,
  seekHoldForward,
  seekHoldBackward,
  seekBarDrag,
  playModeChange,
  share,
  lyricsButton,
  fullScreenLyrics,
  moreMenuOpen,

  /// 更多選單 / 歌詞滿版選單的項目;option = 選單項目 enum。
  menuSelect,
  speedPreset,
  speedSlider,
  speedReset,
  seekStepPreset,
  seekStepSlider,
  seekStepReset;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.playerAction;
}

/// 迷你播放列。
enum MiniPlayerAction implements AnalyticsAction {
  openPlayer,
  playPause,
  swipeNext,
  swipePrevious;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.miniPlayerAction;
}

/// 本機音樂分頁。
enum LibraryAction implements AnalyticsAction {
  rescan,
  changeSort,
  search,
  filterFolder,
  playTrack,
  addToPlaylistOpen,
  trackInfo;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.libraryAction;
}

/// 播放清單。
enum PlaylistAction implements AnalyticsAction {
  create,
  rename,
  delete,
  openAddTracks,
  openEditTracks,
  changeSort,
  search,
  filterFolder,
  clearRecentlyPlayed,
  playTrack,
  playAll,
  toggleShuffle,
  addTrack,
  removeTrack,

  /// 「增加項目」頁全選 / 取消全選目前篩選出的曲目。
  selectAllTracks,
  deselectAllTracks,

  /// 「編輯播放清單」頁全部移除目前篩選出的曲目。
  removeAllTracks,
  reorderTracks,
  addToPlaylist,
  addToPlaylistOpen,
  trackInfo;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.playlistAction;
}

/// 工具頁。
enum ToolsAction implements AnalyticsAction {
  /// option = `ToolKind`(路由樣板 `/tools/:tool` 分不出是哪個工具)。
  selectTool,
  openEditor,
  pickFromFile,
  changeSort,
  search,
  filterFolder;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.toolsAction;
}

/// 封面。
enum CoverAction implements AnalyticsAction {
  setCover,
  removeCover;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.coverAction;
}

/// 帳號(登入成功另由 `login` / `sign_up` 記)。
enum AccountAction implements AnalyticsAction {
  signInMethodSelect,
  signOut,
  deleteData,
  deleteAccount,
  passwordResetRequest,
  phoneCodeRequest;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.accountAction;
}

/// 備份。
enum BackupAction implements AnalyticsAction {
  syncNow,
  driveLink,
  driveUnlink,
  restoreChoice;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.backupAction;
}

/// 設定;option = 新的值。
enum SettingsAction implements AnalyticsAction {
  language,
  themeMode,
  seedColor,
  useGradient,
  gradientFromCover,
  playerDefaultTab;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.settingsAction;
}

/// 收聽統計。
enum StatisticsAction implements AnalyticsAction {
  chartRange,
  chartPointSelect,
  reset;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.statisticsAction;
}

/// 個人頁其他項目。
enum ProfileAction implements AnalyticsAction {
  feedbackSend,
  resetApp,
  privacyPolicyOpen,
  licensesOpen;

  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.profileAction;
}

// ── 轉換 ─────────────────────────────────────────────────────────────────────

/// 組出 [action] 所屬事件的 GA 參數。[source] / [option] / [result] 為 null 時不送。
Map<String, Object> actionParameters(
  AnalyticsAction action, {
  AnalyticsSource? source,
  Object? option,
  Object? result,
}) => toGaParameters({
  AnalyticsParam.action: action,
  AnalyticsParam.source: ?source,
  AnalyticsParam.option: ?option,
  AnalyticsParam.result: ?result,
});

/// 參數轉成 GA 格式:參數名取 [AnalyticsParam.gaName];值為 [Enum] 時轉成
/// snake_case 名稱、bool 轉成 `true` / `false` 字串(GA 不收 bool),
/// 讓呼叫端直接傳 enum、不必自己組字串。數字與字串原樣送出。
Map<String, Object> toGaParameters(Map<AnalyticsParam, Object> parameters) => {
  for (final MapEntry(:key, :value) in parameters.entries)
    key.gaName: switch (value) {
      Enum() => _snakeCase(value.name),
      bool() => value.toString(),
      _ => value,
    },
};

/// lowerCamelCase → snake_case。
String _snakeCase(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

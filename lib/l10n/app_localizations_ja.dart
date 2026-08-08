// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get app_title => '歌詞プレーヤー Lyrics Player';

  @override
  String get tab_music_list => '音楽';

  @override
  String get tab_player => 'プレイヤー';

  @override
  String get tab_profile => 'マイページ';

  @override
  String get profile_account => 'アカウント';

  @override
  String get profile_statistics => '統計';

  @override
  String get profile_settings => '設定';

  @override
  String get profile_about => 'アプリについて';

  @override
  String get player_play => '再生';

  @override
  String get player_pause => '一時停止';

  @override
  String get player_next => '次へ';

  @override
  String get player_previous => '前へ';

  @override
  String get player_shuffle => 'シャッフル';

  @override
  String get player_loop => 'リピート';

  @override
  String get player_share => '共有';

  @override
  String get player_mode_sequential => '順番に再生';

  @override
  String get player_mode_repeat_one => '1曲リピート';

  @override
  String get player_forward => '5秒進む';

  @override
  String get player_rewind => '5秒戻る';

  @override
  String get player_speed => '再生速度';

  @override
  String get common_reset => 'リセット';

  @override
  String get player_nothing_playing => '再生中の曲はありません';

  @override
  String get music_import => '音楽をインポート';

  @override
  String get music_search => '検索';

  @override
  String get music_empty => '音楽が見つかりません';

  @override
  String get music_remove => '削除';

  @override
  String get music_rescan => '再スキャン';

  @override
  String get music_track_info => 'トラック情報';

  @override
  String get track_info_artist => 'アーティスト';

  @override
  String get track_info_duration => '長さ';

  @override
  String get track_info_location => '場所';

  @override
  String get common_unknown => '不明';

  @override
  String get permission_title => 'ストレージへのアクセス許可が必要です';

  @override
  String get permission_message => 'ローカルの音楽をスキャンして再生するためにオーディオファイルへのアクセスが必要です。';

  @override
  String get permission_allow => '許可';

  @override
  String get permission_deny => '後で';

  @override
  String get permission_open_settings => '設定を開く';

  @override
  String get settings_language => '言語';

  @override
  String get settings_language_system => 'システムのデフォルト';

  @override
  String get settings_theme => 'テーマ';

  @override
  String get settings_theme_system => 'システム';

  @override
  String get settings_theme_light => 'ライト';

  @override
  String get settings_theme_dark => 'ダーク';

  @override
  String get statistics_total_time => '総再生時間';

  @override
  String get statistics_play_count => '総再生回数';

  @override
  String get statistics_top_tracks => '再生回数が多い曲';

  @override
  String get statistics_empty => 'まだ統計がありません';

  @override
  String get statistics_reset => '統計をリセット';

  @override
  String get statistics_reset_title => '統計をリセットしますか？';

  @override
  String get statistics_reset_message => 'このデバイスのすべての再生統計が削除されます。この操作は取り消せません。';

  @override
  String get statistics_reset_message_cloud =>
      'このデバイスとクラウドバックアップのすべての再生統計が削除されます。この操作は取り消せません。';

  @override
  String get statistics_reset_confirm => 'リセット';

  @override
  String get statistics_chart_title => '再生時間';

  @override
  String get statistics_chart_week => '週';

  @override
  String get statistics_chart_month => '月';

  @override
  String get statistics_chart_year => '年';

  @override
  String get about_version => 'バージョン';

  @override
  String get about_developer => '開発者';

  @override
  String get about_licenses => 'オープンソースライセンス';

  @override
  String get about_privacy => 'プライバシーポリシー';

  @override
  String get about_open_source => 'オープンソースパッケージ';

  @override
  String get account_guest => 'ゲスト';

  @override
  String get account_signed_out_message => 'サインインしてデバイス間でデータを同期します。';

  @override
  String get account_email => 'メールアドレス';

  @override
  String get account_password => 'パスワード';

  @override
  String get account_sign_in => 'サインイン';

  @override
  String get account_sign_up => '新規登録';

  @override
  String get account_sign_in_google => 'Googleでサインイン';

  @override
  String get account_sign_in_facebook => 'Facebookでサインイン';

  @override
  String get account_method_email => 'メールでサインイン';

  @override
  String get account_method_phone => '電話でサインイン';

  @override
  String get account_phone => '電話番号';

  @override
  String get account_send_code => 'コードを送信';

  @override
  String get account_sms_code => '確認コード';

  @override
  String get account_verify_code => '確認してサインイン';

  @override
  String get account_code_sent => '確認コードをSMSで送信しました。';

  @override
  String get account_continue_guest => 'ゲストとして続行';

  @override
  String get account_sign_out => 'サインアウト';

  @override
  String get account_delete => 'アカウントを削除';

  @override
  String get account_delete_confirm => 'アカウントを削除してもよろしいですか？この操作は取り消せません。';

  @override
  String get account_delete_data => 'アカウントデータを削除';

  @override
  String get account_delete_data_confirm =>
      'アカウントを残したままクラウドデータをすべて削除しますか？この操作は取り消せません。';

  @override
  String get account_delete_data_done => 'アカウントデータを削除しました。';

  @override
  String get account_forgot_password => 'パスワードをお忘れですか？';

  @override
  String get account_reset_sent => 'パスワード再設定メールを送信しました';

  @override
  String get account_anonymous => '匿名アカウント';

  @override
  String get account_unavailable => 'アカウント機能は一時的に利用できません。';

  @override
  String get account_sign_in_failed => 'ログインに失敗しました。後でもう一度お試しください。';

  @override
  String get account_sign_up_failed => '登録に失敗しました。もう一度お試しください。';

  @override
  String get account_sign_in_success => 'ログインしました';

  @override
  String get account_invalid_credentials => 'アカウントまたはパスワードが正しくありません';

  @override
  String get account_signed_out => 'ログアウトしました';

  @override
  String get account_sign_out_failed => 'ログアウトに失敗しました。後でもう一度お試しください。';

  @override
  String get account_operation_failed => '処理に失敗しました。しばらくしてからもう一度お試しください。';

  @override
  String account_last_synced(String time) {
    return '最終同期: $time';
  }

  @override
  String get account_never_synced => 'まだ同期されていません';

  @override
  String get account_sync_now => '今すぐ同期';

  @override
  String get account_sync_done => '同期しました';

  @override
  String get account_sync_failed => '同期に失敗しました。接続を確認してもう一度お試しください。';

  @override
  String get common_cancel => 'キャンセル';

  @override
  String get common_confirm => '確定';

  @override
  String get common_ok => 'OK';

  @override
  String get common_delete => '削除';

  @override
  String get common_retry => '再試行';

  @override
  String get common_network_offline => 'ネットワーク接続を確認して、もう一度お試しください';

  @override
  String get common_today => '今日';

  @override
  String get common_yesterday => '昨日';

  @override
  String get settings_color => 'テーマカラー';

  @override
  String get settings_gradient => 'グラデーションテーマ';

  @override
  String get settings_gradient_desc => 'プレーヤーでテーマカラーのグラデーション背景を使用します';

  @override
  String get settings_gradient_cover => 'カバー色グラデーション';

  @override
  String get settings_gradient_cover_desc => 'プレーヤーのグラデーションに現在のカバーの色を使用します';

  @override
  String get settings_auto_lyrics => '歌詞を自動で全画面表示';

  @override
  String get settings_auto_lyrics_desc => '歌詞のある曲は再生画面で自動的に歌詞を全画面表示します';

  @override
  String get lyrics_import => '歌詞をインポート';

  @override
  String get lyrics_import_success => '歌詞をインポートしました';

  @override
  String get lyrics_import_failed => '歌詞をインポートできませんでした';

  @override
  String get lyrics_import_too_large => '歌詞ファイルが大きすぎます';

  @override
  String get lyrics_import_empty => 'このファイルに歌詞が見つかりません';

  @override
  String get lyrics_search_online => '歌詞をオンラインで検索';

  @override
  String get lyrics_search_online_searching => '歌詞を検索しています…';

  @override
  String get lyrics_search_online_no_result => '歌詞が見つかりません。別のキーワードをお試しください。';

  @override
  String get lyrics_search_online_failed => '歌詞を検索できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get lyrics_search_online_select => '一致する歌詞を選択';

  @override
  String get lyrics_search_online_applied => '歌詞を適用しました';

  @override
  String get lyrics_empty => 'この曲の歌詞はまだありません';

  @override
  String get lyrics_reimport => '再インポート';

  @override
  String get lyrics_download => '歌詞をダウンロード';

  @override
  String get lyrics_download_success => '歌詞を保存しました';

  @override
  String get lyrics_download_failed => '歌詞を保存できませんでした';

  @override
  String get lyrics_delete => '歌詞を削除';

  @override
  String get lyrics_delete_confirm => 'この曲の歌詞を削除しますか？';

  @override
  String get lyrics_show => '歌詞を表示';

  @override
  String get lyrics_hide => 'アートワークを表示';

  @override
  String get cover_edit => 'カバーを編集';

  @override
  String get cover_add => 'カバーを追加';

  @override
  String get cover_change => 'カバーを変更';

  @override
  String get cover_remove => 'カバーを削除';

  @override
  String get cover_updated => 'カバーを更新しました';

  @override
  String get cover_removed => 'カバーを削除しました';

  @override
  String get cover_failed => 'カバーを設定できませんでした';

  @override
  String get cover_too_large => '画像が大きすぎます';

  @override
  String get lyrics_font_size => '文字サイズ';

  @override
  String get lyrics_auto_sync => '歌詞を同期';

  @override
  String get lyrics_auto_sync_compressing => '音声を準備中…';

  @override
  String get lyrics_auto_sync_uploading => '音声をアップロード中…';

  @override
  String get lyrics_auto_sync_aligning => '歌詞を同期中…';

  @override
  String get lyrics_auto_sync_success => '歌詞を同期しました(自動、誤差の可能性あり)';

  @override
  String get lyrics_auto_sync_failed => '歌詞を同期できませんでした。元の歌詞を保持します';

  @override
  String get lyrics_auto_sync_request_success => '歌詞同期リクエストを送信しました';

  @override
  String get lyrics_auto_sync_request_failed => '歌詞同期リクエストの送信に失敗しました';

  @override
  String get lyrics_background_busy => '別の曲を処理中です。しばらくしてからもう一度お試しください';

  @override
  String lyrics_background_busy_named(String title) {
    return 'しばらくしてからもう一度お試しください。処理中:「$title」';
  }

  @override
  String get lyrics_ai_generate_running_background => 'バックグラウンドで歌詞を生成しています';

  @override
  String get lyrics_auto_sync_running_background => 'バックグラウンドで歌詞を同期しています';

  @override
  String get lyrics_auto_sync_need_login => '自動同期を使うにはログインしてください';

  @override
  String get lyrics_auto_sync_rate_limited => '本日の同期回数の上限に達しました。明日お試しください';

  @override
  String get lyrics_auto_sync_no_audio => '音声ファイルが見つかりません';

  @override
  String get lyrics_auto_sync_network => '接続に問題があります。後でもう一度お試しください';

  @override
  String get lyrics_ai_generate => 'AIで歌詞を作成';

  @override
  String get lyrics_ai_generate_compressing => '音声を準備中…';

  @override
  String get lyrics_ai_generate_uploading => '音声をアップロード中…';

  @override
  String get lyrics_ai_generate_transcribing => '歌詞を生成中…';

  @override
  String get lyrics_ai_generate_success => '歌詞を生成しました(自動、誤差の可能性あり)';

  @override
  String get lyrics_ai_generate_failed => '歌詞を生成できませんでした';

  @override
  String get lyrics_ai_generate_request_success => '歌詞生成リクエストを送信しました';

  @override
  String get lyrics_ai_generate_request_failed => '歌詞生成リクエストの送信に失敗しました';

  @override
  String get lyrics_ai_generate_need_login => '自動生成を使うにはログインしてください';

  @override
  String get lyrics_ai_generate_rate_limited => '本日の生成回数の上限に達しました。明日お試しください';

  @override
  String get lyrics_ai_generate_no_audio => '音声ファイルが見つかりません';

  @override
  String get lyrics_ai_generate_network => '接続に問題があります。後でもう一度お試しください';

  @override
  String get lyrics_usage_limit_reached => '今月の無料利用上限に達しました。来月またお試しください';

  @override
  String get lyrics_job_busy => '現在の歌詞処理が完了するまでお待ちください';

  @override
  String get lyrics_job_processing => '歌詞を処理しています…';

  @override
  String get lyrics_job_cancelled => '歌詞処理をキャンセルしました';

  @override
  String get lyrics_action_running_suffix => '（実行中）';

  @override
  String get lyrics_job_error_invalid_request =>
      'リクエストでエラーが発生しました。もう一度お試しください。';

  @override
  String get lyrics_job_error_audio_fetch_failed =>
      '音声ファイルをダウンロードできませんでした。もう一度お試しください。';

  @override
  String get lyrics_job_error_align_model_unavailable =>
      '同期サービスが一時的に利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get lyrics_job_error_alignment_failed => '歌詞と音声を同期できませんでした。';

  @override
  String get lyrics_job_error_transcription_failed => 'この曲の歌詞を認識できませんでした。';

  @override
  String get lyrics_job_error_internal => 'エラーが発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get lyrics_job_error_firestore_write_failed =>
      '歌詞の処理は完了しましたが、保存できませんでした。もう一度お試しください。';

  @override
  String get lyrics_job_error_unknown => '歌詞を処理できませんでした。';

  @override
  String get tab_playlists => 'プレイリスト';

  @override
  String get playlist_favorites => 'お気に入り';

  @override
  String get playlist_recently_played => '最近再生した項目';

  @override
  String get playlist_local_music => 'ローカルの音楽';

  @override
  String get playlist_clear_recently_played => '履歴を消去';

  @override
  String get playlist_clear_recently_played_confirm => '再生履歴をすべて消去しますか？';

  @override
  String get playlist_new => '新しいプレイリスト';

  @override
  String get playlist_name_hint => 'プレイリスト名';

  @override
  String get playlist_rename => '名前を変更';

  @override
  String get playlist_delete => 'プレイリストを削除';

  @override
  String playlist_delete_confirm(String name) {
    return '「$name」を削除しますか?';
  }

  @override
  String get playlist_add_to => 'プレイリストに追加';

  @override
  String get playlist_add_tracks => 'このプレイリストに追加';

  @override
  String get playlist_edit_tracks => 'プレイリストを編集';

  @override
  String get playlist_all_added => 'すべての曲はすでにこのプレイリストに追加されています';

  @override
  String get playlist_add_item => '追加';

  @override
  String get playlist_edit => '編集';

  @override
  String playlist_added(String name) {
    return '「$name」に追加しました';
  }

  @override
  String playlist_already_added(String name) {
    return 'すでに「$name」にあります';
  }

  @override
  String get playlist_remove_track => 'プレイリストから削除';

  @override
  String get playlist_empty => 'このプレイリストにはまだ曲がありません';

  @override
  String get playlists_empty => 'プレイリストがまだありません';

  @override
  String get playlist_search_hint => '何を聴きたいですか?';

  @override
  String get playlist_search_no_result => '一致する曲が見つかりません';

  @override
  String get playlist_play_all => 'すべて再生';

  @override
  String playlist_track_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲',
      zero: '曲なし',
    );
    return '$_temp0';
  }

  @override
  String get update_later => 'あとで';

  @override
  String get update_ready_message => '新しいバージョンの準備ができました';

  @override
  String get update_restart_action => '再起動';

  @override
  String get update_restart_manual_hint =>
      'アップデートを適用するには、アプリを完全に終了してから再度開いてください';

  @override
  String get update_store_action => '更新';

  @override
  String get update_store_message => 'Google Play に新しいバージョンがあります。今すぐ更新しますか？';
}

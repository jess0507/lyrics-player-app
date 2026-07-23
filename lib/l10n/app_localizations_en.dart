// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Lyrics Player';

  @override
  String get tab_music_list => 'Music';

  @override
  String get tab_player => 'Player';

  @override
  String get tab_profile => 'Profile';

  @override
  String get profile_account => 'Account';

  @override
  String get profile_statistics => 'Statistics';

  @override
  String get profile_settings => 'Settings';

  @override
  String get profile_about => 'About';

  @override
  String get player_play => 'Play';

  @override
  String get player_pause => 'Pause';

  @override
  String get player_next => 'Next';

  @override
  String get player_previous => 'Previous';

  @override
  String get player_shuffle => 'Shuffle';

  @override
  String get player_loop => 'Repeat';

  @override
  String get player_forward => 'Forward 5s';

  @override
  String get player_rewind => 'Rewind 5s';

  @override
  String get player_speed => 'Playback speed';

  @override
  String get common_reset => 'Reset';

  @override
  String get player_nothing_playing => 'Nothing playing';

  @override
  String get music_import => 'Import music';

  @override
  String get music_search => 'Search';

  @override
  String get music_empty =>
      'No music found. Tap rescan to load songs from your device.';

  @override
  String get music_remove => 'Remove';

  @override
  String get music_rescan => 'Rescan';

  @override
  String get music_track_info => 'Track info';

  @override
  String get track_info_artist => 'Artist';

  @override
  String get track_info_duration => 'Duration';

  @override
  String get track_info_location => 'Location';

  @override
  String get common_unknown => 'Unknown';

  @override
  String get permission_title => 'Storage permission required';

  @override
  String get permission_message =>
      'We need access to your audio files to scan and play local music.';

  @override
  String get permission_allow => 'Allow';

  @override
  String get permission_deny => 'Not now';

  @override
  String get permission_open_settings => 'Open settings';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_language_system => 'System default';

  @override
  String get settings_theme => 'Theme';

  @override
  String get settings_theme_system => 'System';

  @override
  String get settings_theme_light => 'Light';

  @override
  String get settings_theme_dark => 'Dark';

  @override
  String get statistics_total_time => 'Total listening time';

  @override
  String get statistics_play_count => 'Total plays';

  @override
  String get statistics_top_tracks => 'Most played';

  @override
  String get statistics_empty => 'No statistics yet';

  @override
  String get statistics_reset => 'Reset statistics';

  @override
  String get statistics_reset_title => 'Reset statistics?';

  @override
  String get statistics_reset_message =>
      'All listening statistics on this device will be deleted. This cannot be undone.';

  @override
  String get statistics_reset_message_cloud =>
      'All listening statistics on this device and your cloud backup will be deleted. This cannot be undone.';

  @override
  String get statistics_reset_confirm => 'Reset';

  @override
  String get statistics_chart_title => 'Listening time';

  @override
  String get statistics_chart_week => 'Week';

  @override
  String get statistics_chart_month => 'Month';

  @override
  String get statistics_chart_year => 'Year';

  @override
  String get about_version => 'Version';

  @override
  String get about_developer => 'Developer';

  @override
  String get about_licenses => 'Open source licenses';

  @override
  String get about_privacy => 'Privacy policy';

  @override
  String get about_open_source => 'Open source packages';

  @override
  String get account_guest => 'Guest';

  @override
  String get account_signed_out_message =>
      'Sign in to sync your data across devices.';

  @override
  String get account_email => 'Email';

  @override
  String get account_password => 'Password';

  @override
  String get account_sign_in => 'Sign in';

  @override
  String get account_sign_up => 'Sign up';

  @override
  String get account_sign_in_google => 'Sign in with Google';

  @override
  String get account_sign_in_facebook => 'Sign in with Facebook';

  @override
  String get account_method_email => 'Sign in with email';

  @override
  String get account_method_phone => 'Sign in with phone';

  @override
  String get account_phone => 'Phone number';

  @override
  String get account_send_code => 'Send code';

  @override
  String get account_sms_code => 'Verification code';

  @override
  String get account_verify_code => 'Verify and sign in';

  @override
  String get account_code_sent => 'We\'ve texted you a verification code.';

  @override
  String get account_continue_guest => 'Continue as guest';

  @override
  String get account_sign_out => 'Sign out';

  @override
  String get account_delete => 'Delete account';

  @override
  String get account_delete_confirm =>
      'Are you sure you want to delete your account? This cannot be undone.';

  @override
  String get account_delete_data => 'Delete account data';

  @override
  String get account_delete_data_confirm =>
      'Delete all your cloud data while keeping your account? This cannot be undone.';

  @override
  String get account_delete_data_done => 'Your account data has been deleted.';

  @override
  String get account_forgot_password => 'Forgot password?';

  @override
  String get account_reset_sent => 'Password reset email sent';

  @override
  String get account_anonymous => 'Anonymous account';

  @override
  String get account_unavailable =>
      'Account features are temporarily unavailable.';

  @override
  String get account_sign_in_failed => 'Sign-in failed. Please try again.';

  @override
  String get account_sign_up_failed => 'Sign-up failed. Please try again.';

  @override
  String get account_operation_failed =>
      'The operation failed. Please try again later.';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_ok => 'OK';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_retry => 'Retry';

  @override
  String get settings_color => 'Theme color';

  @override
  String get settings_gradient => 'Gradient theme';

  @override
  String get settings_gradient_desc =>
      'Use a theme-colored gradient background on the player';

  @override
  String get settings_gradient_cover => 'Cover color gradient';

  @override
  String get settings_gradient_cover_desc =>
      'Use the current cover\'s color for the player gradient';

  @override
  String get settings_auto_lyrics => 'Auto full-screen lyrics';

  @override
  String get settings_auto_lyrics_desc =>
      'Show full-screen lyrics automatically for tracks that have lyrics';

  @override
  String get lyrics_import => 'Import lyrics';

  @override
  String get lyrics_import_success => 'Lyrics imported';

  @override
  String get lyrics_import_failed => 'Couldn\'t import lyrics';

  @override
  String get lyrics_import_too_large => 'Lyrics file is too large';

  @override
  String get lyrics_import_empty => 'No lyrics found in this file';

  @override
  String get lyrics_empty => 'No lyrics for this track yet';

  @override
  String get lyrics_reimport => 'Re-import';

  @override
  String get lyrics_delete => 'Delete lyrics';

  @override
  String get lyrics_delete_confirm => 'Delete lyrics for this track?';

  @override
  String get lyrics_show => 'Show lyrics';

  @override
  String get lyrics_hide => 'Show artwork';

  @override
  String get cover_edit => 'Edit cover';

  @override
  String get cover_add => 'Add cover';

  @override
  String get cover_change => 'Change cover';

  @override
  String get cover_remove => 'Remove cover';

  @override
  String get cover_updated => 'Cover updated';

  @override
  String get cover_removed => 'Cover removed';

  @override
  String get cover_failed => 'Couldn\'t set cover';

  @override
  String get cover_too_large => 'Image is too large';

  @override
  String get lyrics_font_size => 'Font size';

  @override
  String get lyrics_auto_sync => 'Sync lyrics';

  @override
  String get lyrics_auto_sync_compressing => 'Preparing audio…';

  @override
  String get lyrics_auto_sync_uploading => 'Uploading audio…';

  @override
  String get lyrics_auto_sync_aligning => 'Aligning lyrics…';

  @override
  String get lyrics_auto_sync_success =>
      'Lyrics synced (auto, may be imperfect)';

  @override
  String get lyrics_auto_sync_failed =>
      'Couldn\'t sync lyrics; kept original text';

  @override
  String get lyrics_background_busy =>
      'Another song is already being processed. Please try again later.';

  @override
  String get lyrics_auto_generate_running_background =>
      'Generating lyrics in the background…';

  @override
  String get lyrics_auto_sync_running_background =>
      'Aligning lyrics in the background…';

  @override
  String get lyrics_auto_sync_need_login => 'Sign in to use auto-sync';

  @override
  String get lyrics_auto_sync_rate_limited =>
      'Daily auto-sync limit reached, try tomorrow';

  @override
  String get lyrics_auto_sync_no_audio => 'Audio file not found';

  @override
  String get lyrics_auto_sync_network => 'Connection problem, try again later';

  @override
  String get lyrics_auto_generate => 'Auto-generate lyrics';

  @override
  String get lyrics_auto_generate_compressing => 'Preparing audio…';

  @override
  String get lyrics_auto_generate_uploading => 'Uploading audio…';

  @override
  String get lyrics_auto_generate_transcribing => 'Generating lyrics…';

  @override
  String get lyrics_auto_generate_success =>
      'Lyrics generated (auto, may be imperfect)';

  @override
  String get lyrics_auto_generate_failed => 'Couldn\'t generate lyrics';

  @override
  String get lyrics_auto_generate_need_login => 'Sign in to use auto-generate';

  @override
  String get lyrics_auto_generate_rate_limited =>
      'Daily auto-generate limit reached, try tomorrow';

  @override
  String get lyrics_auto_generate_no_audio => 'Audio file not found';

  @override
  String get lyrics_auto_generate_network =>
      'Connection problem, try again later';

  @override
  String get lyrics_job_busy =>
      'Please wait for the current lyrics task to finish';

  @override
  String get lyrics_job_processing => 'Processing lyrics…';

  @override
  String get lyrics_job_error_invalid_request =>
      'Something went wrong with the request. Please try again.';

  @override
  String get lyrics_job_error_audio_fetch_failed =>
      'Couldn\'t download the audio file. Please try again.';

  @override
  String get lyrics_job_error_align_model_unavailable =>
      'The alignment service is temporarily unavailable. Please try again later.';

  @override
  String get lyrics_job_error_alignment_failed =>
      'Couldn\'t align the lyrics with the audio.';

  @override
  String get lyrics_job_error_transcription_failed =>
      'Couldn\'t recognize lyrics in this track.';

  @override
  String get lyrics_job_error_internal =>
      'Something went wrong. Please try again later.';

  @override
  String get lyrics_job_error_firestore_write_failed =>
      'Lyrics were processed but couldn\'t be saved. Please try again.';

  @override
  String get lyrics_job_error_unknown => 'Couldn\'t process lyrics.';

  @override
  String get tab_playlists => 'Playlists';

  @override
  String get playlist_favorites => 'Favorites';

  @override
  String get playlist_new => 'New playlist';

  @override
  String get playlist_name_hint => 'Playlist name';

  @override
  String get playlist_rename => 'Rename';

  @override
  String get playlist_delete => 'Delete playlist';

  @override
  String playlist_delete_confirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get playlist_add_to => 'Add to playlist';

  @override
  String get playlist_add_tracks => 'Add to this playlist';

  @override
  String get playlist_edit_tracks => 'Edit playlist';

  @override
  String get playlist_all_added => 'All songs are already in this playlist';

  @override
  String get playlist_add_item => 'Add item';

  @override
  String get playlist_edit => 'Edit';

  @override
  String playlist_added(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String playlist_already_added(String name) {
    return 'Already in \"$name\"';
  }

  @override
  String get playlist_remove_track => 'Remove from playlist';

  @override
  String get playlist_empty => 'No songs in this playlist yet';

  @override
  String get playlists_empty => 'No playlists yet';

  @override
  String get playlist_play_all => 'Play all';

  @override
  String playlist_track_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String get update_later => 'Later';

  @override
  String get update_ready_message => 'A new version is ready';

  @override
  String get update_restart_action => 'Restart';

  @override
  String get update_restart_manual_hint =>
      'Please fully close and reopen the app to apply the update.';

  @override
  String get update_store_action => 'Update';

  @override
  String get update_store_message =>
      'A new version is available on Google Play. Update now?';
}

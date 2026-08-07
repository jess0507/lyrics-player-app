import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Player'**
  String get app_title;

  /// No description provided for @tab_music_list.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get tab_music_list;

  /// No description provided for @tab_player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get tab_player;

  /// No description provided for @tab_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tab_profile;

  /// No description provided for @profile_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profile_account;

  /// No description provided for @profile_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get profile_statistics;

  /// No description provided for @profile_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profile_settings;

  /// No description provided for @profile_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profile_about;

  /// No description provided for @player_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get player_play;

  /// No description provided for @player_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get player_pause;

  /// No description provided for @player_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get player_next;

  /// No description provided for @player_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get player_previous;

  /// No description provided for @player_shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get player_shuffle;

  /// No description provided for @player_loop.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get player_loop;

  /// No description provided for @player_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get player_share;

  /// No description provided for @player_mode_sequential.
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get player_mode_sequential;

  /// No description provided for @player_mode_repeat_one.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get player_mode_repeat_one;

  /// No description provided for @player_forward.
  ///
  /// In en, this message translates to:
  /// **'Forward 5s'**
  String get player_forward;

  /// No description provided for @player_rewind.
  ///
  /// In en, this message translates to:
  /// **'Rewind 5s'**
  String get player_rewind;

  /// No description provided for @player_speed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get player_speed;

  /// No description provided for @common_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get common_reset;

  /// No description provided for @player_nothing_playing.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get player_nothing_playing;

  /// No description provided for @music_import.
  ///
  /// In en, this message translates to:
  /// **'Import music'**
  String get music_import;

  /// No description provided for @music_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get music_search;

  /// No description provided for @music_empty.
  ///
  /// In en, this message translates to:
  /// **'No music found. Tap rescan to load songs from your device.'**
  String get music_empty;

  /// No description provided for @music_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get music_remove;

  /// No description provided for @music_rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get music_rescan;

  /// No description provided for @music_track_info.
  ///
  /// In en, this message translates to:
  /// **'Track info'**
  String get music_track_info;

  /// No description provided for @track_info_artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get track_info_artist;

  /// No description provided for @track_info_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get track_info_duration;

  /// No description provided for @track_info_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get track_info_location;

  /// No description provided for @common_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get common_unknown;

  /// No description provided for @permission_title.
  ///
  /// In en, this message translates to:
  /// **'Storage permission required'**
  String get permission_title;

  /// No description provided for @permission_message.
  ///
  /// In en, this message translates to:
  /// **'We need access to your audio files to scan and play local music.'**
  String get permission_message;

  /// No description provided for @permission_allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permission_allow;

  /// No description provided for @permission_deny.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permission_deny;

  /// No description provided for @permission_open_settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permission_open_settings;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_language_system.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settings_language_system;

  /// No description provided for @settings_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_theme;

  /// No description provided for @settings_theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settings_theme_system;

  /// No description provided for @settings_theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_theme_light;

  /// No description provided for @settings_theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_theme_dark;

  /// No description provided for @statistics_total_time.
  ///
  /// In en, this message translates to:
  /// **'Total listening time'**
  String get statistics_total_time;

  /// No description provided for @statistics_play_count.
  ///
  /// In en, this message translates to:
  /// **'Total plays'**
  String get statistics_play_count;

  /// No description provided for @statistics_top_tracks.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get statistics_top_tracks;

  /// No description provided for @statistics_empty.
  ///
  /// In en, this message translates to:
  /// **'No statistics yet'**
  String get statistics_empty;

  /// No description provided for @statistics_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset statistics'**
  String get statistics_reset;

  /// No description provided for @statistics_reset_title.
  ///
  /// In en, this message translates to:
  /// **'Reset statistics?'**
  String get statistics_reset_title;

  /// No description provided for @statistics_reset_message.
  ///
  /// In en, this message translates to:
  /// **'All listening statistics on this device will be deleted. This cannot be undone.'**
  String get statistics_reset_message;

  /// No description provided for @statistics_reset_message_cloud.
  ///
  /// In en, this message translates to:
  /// **'All listening statistics on this device and your cloud backup will be deleted. This cannot be undone.'**
  String get statistics_reset_message_cloud;

  /// No description provided for @statistics_reset_confirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get statistics_reset_confirm;

  /// No description provided for @statistics_chart_title.
  ///
  /// In en, this message translates to:
  /// **'Listening time'**
  String get statistics_chart_title;

  /// No description provided for @statistics_chart_week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statistics_chart_week;

  /// No description provided for @statistics_chart_month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statistics_chart_month;

  /// No description provided for @statistics_chart_year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get statistics_chart_year;

  /// No description provided for @about_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get about_version;

  /// No description provided for @about_developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get about_developer;

  /// No description provided for @about_licenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get about_licenses;

  /// No description provided for @about_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get about_privacy;

  /// No description provided for @about_open_source.
  ///
  /// In en, this message translates to:
  /// **'Open source packages'**
  String get about_open_source;

  /// No description provided for @account_guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get account_guest;

  /// No description provided for @account_signed_out_message.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your data across devices.'**
  String get account_signed_out_message;

  /// No description provided for @account_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get account_email;

  /// No description provided for @account_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get account_password;

  /// No description provided for @account_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get account_sign_in;

  /// No description provided for @account_sign_up.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get account_sign_up;

  /// No description provided for @account_sign_in_google.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get account_sign_in_google;

  /// No description provided for @account_sign_in_facebook.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Facebook'**
  String get account_sign_in_facebook;

  /// No description provided for @account_method_email.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get account_method_email;

  /// No description provided for @account_method_phone.
  ///
  /// In en, this message translates to:
  /// **'Sign in with phone'**
  String get account_method_phone;

  /// No description provided for @account_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get account_phone;

  /// No description provided for @account_send_code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get account_send_code;

  /// No description provided for @account_sms_code.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get account_sms_code;

  /// No description provided for @account_verify_code.
  ///
  /// In en, this message translates to:
  /// **'Verify and sign in'**
  String get account_verify_code;

  /// No description provided for @account_code_sent.
  ///
  /// In en, this message translates to:
  /// **'We\'ve texted you a verification code.'**
  String get account_code_sent;

  /// No description provided for @account_continue_guest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get account_continue_guest;

  /// No description provided for @account_sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get account_sign_out;

  /// No description provided for @account_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get account_delete;

  /// No description provided for @account_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This cannot be undone.'**
  String get account_delete_confirm;

  /// No description provided for @account_delete_data.
  ///
  /// In en, this message translates to:
  /// **'Delete account data'**
  String get account_delete_data;

  /// No description provided for @account_delete_data_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all your cloud data while keeping your account? This cannot be undone.'**
  String get account_delete_data_confirm;

  /// No description provided for @account_delete_data_done.
  ///
  /// In en, this message translates to:
  /// **'Your account data has been deleted.'**
  String get account_delete_data_done;

  /// No description provided for @account_forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get account_forgot_password;

  /// No description provided for @account_reset_sent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get account_reset_sent;

  /// No description provided for @account_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous account'**
  String get account_anonymous;

  /// No description provided for @account_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Account features are temporarily unavailable.'**
  String get account_unavailable;

  /// No description provided for @account_sign_in_failed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get account_sign_in_failed;

  /// No description provided for @account_sign_up_failed.
  ///
  /// In en, this message translates to:
  /// **'Sign-up failed. Please try again.'**
  String get account_sign_up_failed;

  /// No description provided for @account_operation_failed.
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Please try again later.'**
  String get account_operation_failed;

  /// No description provided for @account_last_synced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String account_last_synced(String time);

  /// No description provided for @account_never_synced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get account_never_synced;

  /// No description provided for @account_sync_now.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get account_sync_now;

  /// No description provided for @account_sync_done.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get account_sync_done;

  /// No description provided for @account_sync_failed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Please check your connection and try again.'**
  String get account_sync_failed;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// No description provided for @common_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// No description provided for @common_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get common_today;

  /// No description provided for @common_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get common_yesterday;

  /// No description provided for @settings_color.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get settings_color;

  /// No description provided for @settings_gradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient theme'**
  String get settings_gradient;

  /// No description provided for @settings_gradient_desc.
  ///
  /// In en, this message translates to:
  /// **'Use a theme-colored gradient background on the player'**
  String get settings_gradient_desc;

  /// No description provided for @settings_gradient_cover.
  ///
  /// In en, this message translates to:
  /// **'Cover color gradient'**
  String get settings_gradient_cover;

  /// No description provided for @settings_gradient_cover_desc.
  ///
  /// In en, this message translates to:
  /// **'Use the current cover\'s color for the player gradient'**
  String get settings_gradient_cover_desc;

  /// No description provided for @settings_auto_lyrics.
  ///
  /// In en, this message translates to:
  /// **'Auto full-screen lyrics'**
  String get settings_auto_lyrics;

  /// No description provided for @settings_auto_lyrics_desc.
  ///
  /// In en, this message translates to:
  /// **'Show full-screen lyrics automatically for tracks that have lyrics'**
  String get settings_auto_lyrics_desc;

  /// No description provided for @lyrics_import.
  ///
  /// In en, this message translates to:
  /// **'Import lyrics'**
  String get lyrics_import;

  /// No description provided for @lyrics_import_success.
  ///
  /// In en, this message translates to:
  /// **'Lyrics imported'**
  String get lyrics_import_success;

  /// No description provided for @lyrics_import_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import lyrics'**
  String get lyrics_import_failed;

  /// No description provided for @lyrics_import_too_large.
  ///
  /// In en, this message translates to:
  /// **'Lyrics file is too large'**
  String get lyrics_import_too_large;

  /// No description provided for @lyrics_import_empty.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found in this file'**
  String get lyrics_import_empty;

  /// No description provided for @lyrics_search_online.
  ///
  /// In en, this message translates to:
  /// **'Search lyrics online'**
  String get lyrics_search_online;

  /// No description provided for @lyrics_search_online_searching.
  ///
  /// In en, this message translates to:
  /// **'Searching for lyrics…'**
  String get lyrics_search_online_searching;

  /// No description provided for @lyrics_search_online_no_result.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found. Try different keywords.'**
  String get lyrics_search_online_no_result;

  /// No description provided for @lyrics_search_online_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search for lyrics. Check your connection and try again.'**
  String get lyrics_search_online_failed;

  /// No description provided for @lyrics_search_online_select.
  ///
  /// In en, this message translates to:
  /// **'Select matching lyrics'**
  String get lyrics_search_online_select;

  /// No description provided for @lyrics_search_online_applied.
  ///
  /// In en, this message translates to:
  /// **'Lyrics applied'**
  String get lyrics_search_online_applied;

  /// No description provided for @lyrics_empty.
  ///
  /// In en, this message translates to:
  /// **'No lyrics for this track yet'**
  String get lyrics_empty;

  /// No description provided for @lyrics_reimport.
  ///
  /// In en, this message translates to:
  /// **'Re-import'**
  String get lyrics_reimport;

  /// No description provided for @lyrics_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete lyrics'**
  String get lyrics_delete;

  /// No description provided for @lyrics_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete lyrics for this track?'**
  String get lyrics_delete_confirm;

  /// No description provided for @lyrics_show.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get lyrics_show;

  /// No description provided for @lyrics_hide.
  ///
  /// In en, this message translates to:
  /// **'Show artwork'**
  String get lyrics_hide;

  /// No description provided for @cover_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit cover'**
  String get cover_edit;

  /// No description provided for @cover_add.
  ///
  /// In en, this message translates to:
  /// **'Add cover'**
  String get cover_add;

  /// No description provided for @cover_change.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get cover_change;

  /// No description provided for @cover_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get cover_remove;

  /// No description provided for @cover_updated.
  ///
  /// In en, this message translates to:
  /// **'Cover updated'**
  String get cover_updated;

  /// No description provided for @cover_removed.
  ///
  /// In en, this message translates to:
  /// **'Cover removed'**
  String get cover_removed;

  /// No description provided for @cover_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set cover'**
  String get cover_failed;

  /// No description provided for @cover_too_large.
  ///
  /// In en, this message translates to:
  /// **'Image is too large'**
  String get cover_too_large;

  /// No description provided for @lyrics_font_size.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get lyrics_font_size;

  /// No description provided for @lyrics_auto_sync.
  ///
  /// In en, this message translates to:
  /// **'Sync lyrics'**
  String get lyrics_auto_sync;

  /// No description provided for @lyrics_auto_sync_compressing.
  ///
  /// In en, this message translates to:
  /// **'Preparing audio…'**
  String get lyrics_auto_sync_compressing;

  /// No description provided for @lyrics_auto_sync_uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading audio…'**
  String get lyrics_auto_sync_uploading;

  /// No description provided for @lyrics_auto_sync_aligning.
  ///
  /// In en, this message translates to:
  /// **'Aligning lyrics…'**
  String get lyrics_auto_sync_aligning;

  /// No description provided for @lyrics_auto_sync_success.
  ///
  /// In en, this message translates to:
  /// **'Lyrics synced (auto, may be imperfect)'**
  String get lyrics_auto_sync_success;

  /// No description provided for @lyrics_auto_sync_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync lyrics; kept original text'**
  String get lyrics_auto_sync_failed;

  /// No description provided for @lyrics_auto_sync_request_success.
  ///
  /// In en, this message translates to:
  /// **'Sync lyrics request sent'**
  String get lyrics_auto_sync_request_success;

  /// No description provided for @lyrics_auto_sync_request_failed.
  ///
  /// In en, this message translates to:
  /// **'Sync lyrics request failed'**
  String get lyrics_auto_sync_request_failed;

  /// No description provided for @lyrics_background_busy.
  ///
  /// In en, this message translates to:
  /// **'Another song is already being processed. Please try again later.'**
  String get lyrics_background_busy;

  /// No description provided for @lyrics_background_busy_named.
  ///
  /// In en, this message translates to:
  /// **'Please try again later. Currently processing \"{title}\".'**
  String lyrics_background_busy_named(String title);

  /// No description provided for @lyrics_ai_generate_running_background.
  ///
  /// In en, this message translates to:
  /// **'Generating lyrics in the background…'**
  String get lyrics_ai_generate_running_background;

  /// No description provided for @lyrics_auto_sync_running_background.
  ///
  /// In en, this message translates to:
  /// **'Aligning lyrics in the background…'**
  String get lyrics_auto_sync_running_background;

  /// No description provided for @lyrics_auto_sync_need_login.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use auto-sync'**
  String get lyrics_auto_sync_need_login;

  /// No description provided for @lyrics_auto_sync_rate_limited.
  ///
  /// In en, this message translates to:
  /// **'Daily auto-sync limit reached, try tomorrow'**
  String get lyrics_auto_sync_rate_limited;

  /// No description provided for @lyrics_auto_sync_no_audio.
  ///
  /// In en, this message translates to:
  /// **'Audio file not found'**
  String get lyrics_auto_sync_no_audio;

  /// No description provided for @lyrics_auto_sync_network.
  ///
  /// In en, this message translates to:
  /// **'Connection problem, try again later'**
  String get lyrics_auto_sync_network;

  /// No description provided for @lyrics_ai_generate.
  ///
  /// In en, this message translates to:
  /// **'Generate lyrics with AI'**
  String get lyrics_ai_generate;

  /// No description provided for @lyrics_ai_generate_compressing.
  ///
  /// In en, this message translates to:
  /// **'Preparing audio…'**
  String get lyrics_ai_generate_compressing;

  /// No description provided for @lyrics_ai_generate_uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading audio…'**
  String get lyrics_ai_generate_uploading;

  /// No description provided for @lyrics_ai_generate_transcribing.
  ///
  /// In en, this message translates to:
  /// **'Generating lyrics…'**
  String get lyrics_ai_generate_transcribing;

  /// No description provided for @lyrics_ai_generate_success.
  ///
  /// In en, this message translates to:
  /// **'Lyrics generated (auto, may be imperfect)'**
  String get lyrics_ai_generate_success;

  /// No description provided for @lyrics_ai_generate_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate lyrics'**
  String get lyrics_ai_generate_failed;

  /// No description provided for @lyrics_ai_generate_request_success.
  ///
  /// In en, this message translates to:
  /// **'Generate lyrics request sent'**
  String get lyrics_ai_generate_request_success;

  /// No description provided for @lyrics_ai_generate_request_failed.
  ///
  /// In en, this message translates to:
  /// **'Generate lyrics request failed'**
  String get lyrics_ai_generate_request_failed;

  /// No description provided for @lyrics_ai_generate_need_login.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use auto-generate'**
  String get lyrics_ai_generate_need_login;

  /// No description provided for @lyrics_ai_generate_rate_limited.
  ///
  /// In en, this message translates to:
  /// **'Daily auto-generate limit reached, try tomorrow'**
  String get lyrics_ai_generate_rate_limited;

  /// No description provided for @lyrics_ai_generate_no_audio.
  ///
  /// In en, this message translates to:
  /// **'Audio file not found'**
  String get lyrics_ai_generate_no_audio;

  /// No description provided for @lyrics_ai_generate_network.
  ///
  /// In en, this message translates to:
  /// **'Connection problem, try again later'**
  String get lyrics_ai_generate_network;

  /// No description provided for @lyrics_usage_limit_reached.
  ///
  /// In en, this message translates to:
  /// **'Monthly free usage limit reached. Try again next month.'**
  String get lyrics_usage_limit_reached;

  /// No description provided for @lyrics_job_busy.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the current lyrics task to finish'**
  String get lyrics_job_busy;

  /// No description provided for @lyrics_job_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing lyrics…'**
  String get lyrics_job_processing;

  /// No description provided for @lyrics_job_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Lyrics task cancelled'**
  String get lyrics_job_cancelled;

  /// No description provided for @lyrics_action_running_suffix.
  ///
  /// In en, this message translates to:
  /// **' (Running)'**
  String get lyrics_action_running_suffix;

  /// No description provided for @lyrics_job_error_invalid_request.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with the request. Please try again.'**
  String get lyrics_job_error_invalid_request;

  /// No description provided for @lyrics_job_error_audio_fetch_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the audio file. Please try again.'**
  String get lyrics_job_error_audio_fetch_failed;

  /// No description provided for @lyrics_job_error_align_model_unavailable.
  ///
  /// In en, this message translates to:
  /// **'The alignment service is temporarily unavailable. Please try again later.'**
  String get lyrics_job_error_align_model_unavailable;

  /// No description provided for @lyrics_job_error_alignment_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t align the lyrics with the audio.'**
  String get lyrics_job_error_alignment_failed;

  /// No description provided for @lyrics_job_error_transcription_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t recognize lyrics in this track.'**
  String get lyrics_job_error_transcription_failed;

  /// No description provided for @lyrics_job_error_internal.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again later.'**
  String get lyrics_job_error_internal;

  /// No description provided for @lyrics_job_error_firestore_write_failed.
  ///
  /// In en, this message translates to:
  /// **'Lyrics were processed but couldn\'t be saved. Please try again.'**
  String get lyrics_job_error_firestore_write_failed;

  /// No description provided for @lyrics_job_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process lyrics.'**
  String get lyrics_job_error_unknown;

  /// No description provided for @tab_playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get tab_playlists;

  /// No description provided for @playlist_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get playlist_favorites;

  /// No description provided for @playlist_recently_played.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get playlist_recently_played;

  /// No description provided for @playlist_clear_recently_played.
  ///
  /// In en, this message translates to:
  /// **'Clear recently played'**
  String get playlist_clear_recently_played;

  /// No description provided for @playlist_clear_recently_played_confirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all recently played tracks?'**
  String get playlist_clear_recently_played_confirm;

  /// No description provided for @playlist_new.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlist_new;

  /// No description provided for @playlist_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlist_name_hint;

  /// No description provided for @playlist_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlist_rename;

  /// No description provided for @playlist_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get playlist_delete;

  /// No description provided for @playlist_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String playlist_delete_confirm(String name);

  /// No description provided for @playlist_add_to.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlist_add_to;

  /// No description provided for @playlist_add_tracks.
  ///
  /// In en, this message translates to:
  /// **'Add to this playlist'**
  String get playlist_add_tracks;

  /// No description provided for @playlist_edit_tracks.
  ///
  /// In en, this message translates to:
  /// **'Edit playlist'**
  String get playlist_edit_tracks;

  /// No description provided for @playlist_all_added.
  ///
  /// In en, this message translates to:
  /// **'All songs are already in this playlist'**
  String get playlist_all_added;

  /// No description provided for @playlist_add_item.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get playlist_add_item;

  /// No description provided for @playlist_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get playlist_edit;

  /// No description provided for @playlist_added.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String playlist_added(String name);

  /// No description provided for @playlist_already_added.
  ///
  /// In en, this message translates to:
  /// **'Already in \"{name}\"'**
  String playlist_already_added(String name);

  /// No description provided for @playlist_remove_track.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlist_remove_track;

  /// No description provided for @playlist_empty.
  ///
  /// In en, this message translates to:
  /// **'No songs in this playlist yet'**
  String get playlist_empty;

  /// No description provided for @playlists_empty.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlists_empty;

  /// No description provided for @playlist_search_hint.
  ///
  /// In en, this message translates to:
  /// **'What do you want to listen to?'**
  String get playlist_search_hint;

  /// No description provided for @playlist_search_no_result.
  ///
  /// In en, this message translates to:
  /// **'No matching songs'**
  String get playlist_search_no_result;

  /// No description provided for @playlist_play_all.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playlist_play_all;

  /// No description provided for @playlist_track_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String playlist_track_count(int count);

  /// No description provided for @update_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get update_later;

  /// No description provided for @update_ready_message.
  ///
  /// In en, this message translates to:
  /// **'A new version is ready'**
  String get update_ready_message;

  /// No description provided for @update_restart_action.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get update_restart_action;

  /// No description provided for @update_restart_manual_hint.
  ///
  /// In en, this message translates to:
  /// **'Please fully close and reopen the app to apply the update.'**
  String get update_restart_manual_hint;

  /// No description provided for @update_store_action.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update_store_action;

  /// No description provided for @update_store_message.
  ///
  /// In en, this message translates to:
  /// **'A new version is available on Google Play. Update now?'**
  String get update_store_message;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'ko',
    'pt',
    'ru',
    'tr',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get app_title => '가사 플레이어 Lyrics Player';

  @override
  String get tab_music_list => '음악';

  @override
  String get tab_player => '플레이어';

  @override
  String get tab_profile => '마이';

  @override
  String get profile_account => '계정';

  @override
  String get profile_statistics => '통계';

  @override
  String get profile_settings => '설정';

  @override
  String get profile_about => '정보';

  @override
  String get player_play => '재생';

  @override
  String get player_pause => '일시정지';

  @override
  String get player_next => '다음';

  @override
  String get player_previous => '이전';

  @override
  String get player_shuffle => '셔플';

  @override
  String get player_loop => '반복';

  @override
  String get player_share => '공유';

  @override
  String get player_mode_sequential => '순서대로 재생';

  @override
  String get player_mode_repeat_one => '한 곡 반복';

  @override
  String get player_forward => '5초 앞으로';

  @override
  String get player_rewind => '5초 뒤로';

  @override
  String get player_speed => '재생 속도';

  @override
  String get common_reset => '초기화';

  @override
  String get player_nothing_playing => '재생 중인 곡이 없습니다';

  @override
  String get music_import => '음악 가져오기';

  @override
  String get music_search => '검색';

  @override
  String get music_empty => '음악을 찾을 수 없습니다';

  @override
  String get music_remove => '제거';

  @override
  String get music_rescan => '다시 검색';

  @override
  String get music_track_info => '트랙 정보';

  @override
  String get track_info_artist => '아티스트';

  @override
  String get track_info_duration => '길이';

  @override
  String get track_info_location => '위치';

  @override
  String get common_unknown => '알 수 없음';

  @override
  String get permission_title => '저장소 권한이 필요합니다';

  @override
  String get permission_message => '로컬 음악을 검색하고 재생하려면 오디오 파일에 대한 접근 권한이 필요합니다.';

  @override
  String get permission_allow => '허용';

  @override
  String get permission_deny => '나중에';

  @override
  String get permission_open_settings => '설정 열기';

  @override
  String get settings_language => '언어';

  @override
  String get settings_language_system => '시스템 기본값';

  @override
  String get settings_theme => '테마';

  @override
  String get settings_theme_system => '시스템';

  @override
  String get settings_theme_light => '라이트';

  @override
  String get settings_theme_dark => '다크';

  @override
  String get statistics_total_time => '총 재생 시간';

  @override
  String get statistics_play_count => '총 재생 횟수';

  @override
  String get statistics_top_tracks => '가장 많이 재생됨';

  @override
  String get statistics_empty => '아직 통계가 없습니다';

  @override
  String get statistics_reset => '통계 초기화';

  @override
  String get statistics_reset_title => '통계를 초기화할까요?';

  @override
  String get statistics_reset_message =>
      '이 기기의 모든 재생 통계가 삭제됩니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get statistics_reset_message_cloud =>
      '이 기기와 클라우드 백업의 모든 재생 통계가 삭제됩니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get statistics_reset_confirm => '초기화';

  @override
  String get statistics_chart_title => '재생 시간';

  @override
  String get statistics_chart_week => '주';

  @override
  String get statistics_chart_month => '월';

  @override
  String get statistics_chart_year => '년';

  @override
  String get about_version => '버전';

  @override
  String get about_developer => '개발자';

  @override
  String get about_licenses => '오픈 소스 라이선스';

  @override
  String get about_privacy => '개인정보 처리방침';

  @override
  String get about_open_source => '오픈 소스 패키지';

  @override
  String get account_guest => '게스트';

  @override
  String get account_signed_out_message => '로그인하여 기기 간에 데이터를 동기화하세요.';

  @override
  String get account_email => '이메일';

  @override
  String get account_password => '비밀번호';

  @override
  String get account_sign_in => '로그인';

  @override
  String get account_sign_up => '회원가입';

  @override
  String get account_sign_in_google => 'Google로 로그인';

  @override
  String get account_sign_in_facebook => 'Facebook으로 로그인';

  @override
  String get account_method_email => '이메일로 로그인';

  @override
  String get account_method_phone => '전화번호로 로그인';

  @override
  String get account_phone => '전화번호';

  @override
  String get account_send_code => '코드 전송';

  @override
  String get account_sms_code => '인증 코드';

  @override
  String get account_verify_code => '인증 후 로그인';

  @override
  String get account_code_sent => '인증 코드를 SMS로 보냈습니다.';

  @override
  String get account_continue_guest => '게스트로 계속하기';

  @override
  String get account_sign_out => '로그아웃';

  @override
  String get account_delete => '계정 삭제';

  @override
  String get account_delete_confirm => '계정을 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.';

  @override
  String get account_delete_data => '계정 데이터 삭제';

  @override
  String get account_delete_data_confirm =>
      '계정은 유지하면서 모든 클라우드 데이터를 삭제할까요? 이 작업은 취소할 수 없습니다.';

  @override
  String get account_delete_data_done => '계정 데이터가 삭제되었습니다.';

  @override
  String get account_forgot_password => '비밀번호를 잊으셨나요?';

  @override
  String get account_reset_sent => '비밀번호 재설정 이메일을 보냈습니다';

  @override
  String get account_anonymous => '익명 계정';

  @override
  String get account_unavailable => '계정 기능을 일시적으로 사용할 수 없습니다.';

  @override
  String get account_sign_in_failed => '로그인에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get account_sign_up_failed => '회원가입에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get account_operation_failed => '작업에 실패했습니다. 나중에 다시 시도해 주세요.';

  @override
  String account_last_synced(String time) {
    return '마지막 동기화: $time';
  }

  @override
  String get account_never_synced => '아직 동기화되지 않음';

  @override
  String get account_sync_now => '지금 동기화';

  @override
  String get account_sync_done => '동기화됨';

  @override
  String get account_sync_failed => '동기화에 실패했습니다. 연결 상태를 확인한 후 다시 시도해 주세요.';

  @override
  String get common_cancel => '취소';

  @override
  String get common_confirm => '확인';

  @override
  String get common_ok => '확인';

  @override
  String get common_delete => '삭제';

  @override
  String get common_retry => '다시 시도';

  @override
  String get common_today => '오늘';

  @override
  String get common_yesterday => '어제';

  @override
  String get settings_color => '테마 색상';

  @override
  String get settings_gradient => '그라데이션 테마';

  @override
  String get settings_gradient_desc => '플레이어에 테마 색상 그라데이션 배경을 사용합니다';

  @override
  String get settings_gradient_cover => '커버 색상 그라데이션';

  @override
  String get settings_gradient_cover_desc => '플레이어 그라데이션에 현재 커버 색상을 사용합니다';

  @override
  String get settings_auto_lyrics => '가사 자동 전체화면';

  @override
  String get settings_auto_lyrics_desc =>
      '가사가 있는 곡은 재생 화면에서 자동으로 가사를 전체화면으로 표시합니다';

  @override
  String get lyrics_import => '가사 가져오기';

  @override
  String get lyrics_import_success => '가사를 가져왔습니다';

  @override
  String get lyrics_import_failed => '가사를 가져올 수 없습니다';

  @override
  String get lyrics_import_too_large => '가사 파일이 너무 큽니다';

  @override
  String get lyrics_import_empty => '이 파일에서 가사를 찾을 수 없습니다';

  @override
  String get lyrics_empty => '이 곡의 가사가 아직 없습니다';

  @override
  String get lyrics_reimport => '다시 가져오기';

  @override
  String get lyrics_delete => '가사 삭제';

  @override
  String get lyrics_delete_confirm => '이 곡의 가사를 삭제할까요?';

  @override
  String get lyrics_show => '가사 표시';

  @override
  String get lyrics_hide => '앨범 아트 표시';

  @override
  String get cover_edit => '커버 편집';

  @override
  String get cover_add => '커버 추가';

  @override
  String get cover_change => '커버 변경';

  @override
  String get cover_remove => '커버 제거';

  @override
  String get cover_updated => '커버가 업데이트됨';

  @override
  String get cover_removed => '커버가 제거됨';

  @override
  String get cover_failed => '커버를 설정할 수 없습니다';

  @override
  String get cover_too_large => '이미지가 너무 큽니다';

  @override
  String get lyrics_font_size => '글자 크기';

  @override
  String get lyrics_auto_sync => '가사 동기화';

  @override
  String get lyrics_auto_sync_compressing => '오디오 준비 중…';

  @override
  String get lyrics_auto_sync_uploading => '오디오 업로드 중…';

  @override
  String get lyrics_auto_sync_aligning => '가사 정렬 중…';

  @override
  String get lyrics_auto_sync_success => '가사 동기화됨 (자동, 오차가 있을 수 있음)';

  @override
  String get lyrics_auto_sync_failed => '가사를 동기화할 수 없어 원본 가사를 유지했습니다';

  @override
  String get lyrics_auto_sync_request_success => '가사 동기화 요청을 보냈습니다';

  @override
  String get lyrics_auto_sync_request_failed => '가사 동기화 요청 전송 실패';

  @override
  String get lyrics_background_busy => '다른 곡을 처리 중입니다. 잠시 후 다시 시도해 주세요';

  @override
  String lyrics_background_busy_named(String title) {
    return '잠시 후 다시 시도해 주세요. 처리 중: \"$title\"';
  }

  @override
  String get lyrics_auto_generate_running_background => '백그라운드에서 가사를 생성하고 있습니다';

  @override
  String get lyrics_auto_sync_running_background => '백그라운드에서 가사를 정렬하고 있습니다';

  @override
  String get lyrics_auto_sync_need_login => '자동 동기화를 사용하려면 로그인하세요';

  @override
  String get lyrics_auto_sync_rate_limited => '오늘 동기화 한도에 도달했습니다. 내일 다시 시도하세요';

  @override
  String get lyrics_auto_sync_no_audio => '오디오 파일을 찾을 수 없습니다';

  @override
  String get lyrics_auto_sync_network => '연결 문제가 발생했습니다. 나중에 다시 시도하세요';

  @override
  String get lyrics_auto_generate => '가사 자동 생성';

  @override
  String get lyrics_auto_generate_compressing => '오디오 준비 중…';

  @override
  String get lyrics_auto_generate_uploading => '오디오 업로드 중…';

  @override
  String get lyrics_auto_generate_transcribing => '가사 생성 중…';

  @override
  String get lyrics_auto_generate_success => '가사 생성됨 (자동, 오차가 있을 수 있음)';

  @override
  String get lyrics_auto_generate_failed => '가사를 생성할 수 없습니다';

  @override
  String get lyrics_auto_generate_request_success => '가사 생성 요청을 보냈습니다';

  @override
  String get lyrics_auto_generate_request_failed => '가사 생성 요청 전송 실패';

  @override
  String get lyrics_auto_generate_need_login => '자동 생성을 사용하려면 로그인하세요';

  @override
  String get lyrics_auto_generate_rate_limited =>
      '오늘 생성 한도에 도달했습니다. 내일 다시 시도하세요';

  @override
  String get lyrics_auto_generate_no_audio => '오디오 파일을 찾을 수 없습니다';

  @override
  String get lyrics_auto_generate_network => '연결 문제가 발생했습니다. 나중에 다시 시도하세요';

  @override
  String get lyrics_usage_limit_reached =>
      '이번 달 무료 사용 한도에 도달했습니다. 다음 달에 다시 시도하세요';

  @override
  String get lyrics_job_busy => '현재 가사 작업이 끝날 때까지 기다려 주세요';

  @override
  String get lyrics_job_processing => '가사를 처리하는 중…';

  @override
  String get lyrics_job_cancelled => '가사 작업이 취소되었습니다';

  @override
  String get lyrics_action_running_suffix => ' (실행 중)';

  @override
  String get lyrics_job_error_invalid_request =>
      '요청 처리 중 오류가 발생했습니다. 다시 시도해 주세요.';

  @override
  String get lyrics_job_error_audio_fetch_failed =>
      '오디오 파일을 다운로드할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get lyrics_job_error_align_model_unavailable =>
      '동기화 서비스를 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get lyrics_job_error_alignment_failed => '가사를 오디오와 동기화할 수 없습니다.';

  @override
  String get lyrics_job_error_transcription_failed => '이 곡의 가사를 인식할 수 없습니다.';

  @override
  String get lyrics_job_error_internal => '오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get lyrics_job_error_firestore_write_failed =>
      '가사 처리는 완료되었지만 저장할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get lyrics_job_error_unknown => '가사를 처리할 수 없습니다.';

  @override
  String get tab_playlists => '재생목록';

  @override
  String get playlist_favorites => '즐겨찾기';

  @override
  String get playlist_recently_played => '최근 재생';

  @override
  String get playlist_clear_recently_played => '기록 지우기';

  @override
  String get playlist_clear_recently_played_confirm => '재생 기록을 모두 지우시겠습니까?';

  @override
  String get playlist_new => '새 재생목록';

  @override
  String get playlist_name_hint => '재생목록 이름';

  @override
  String get playlist_rename => '이름 변경';

  @override
  String get playlist_delete => '재생목록 삭제';

  @override
  String playlist_delete_confirm(String name) {
    return '\"$name\"을(를) 삭제할까요?';
  }

  @override
  String get playlist_add_to => '재생목록에 추가';

  @override
  String get playlist_add_tracks => '이 재생목록에 추가';

  @override
  String get playlist_edit_tracks => '재생목록 편집';

  @override
  String get playlist_all_added => '모든 곡이 이미 이 재생목록에 있습니다';

  @override
  String get playlist_add_item => '추가';

  @override
  String get playlist_edit => '편집';

  @override
  String playlist_added(String name) {
    return '\"$name\"에 추가됨';
  }

  @override
  String playlist_already_added(String name) {
    return '이미 \"$name\"에 있음';
  }

  @override
  String get playlist_remove_track => '재생목록에서 제거';

  @override
  String get playlist_empty => '이 재생목록에 아직 곡이 없습니다';

  @override
  String get playlists_empty => '아직 재생목록이 없습니다';

  @override
  String get playlist_play_all => '전체 재생';

  @override
  String playlist_track_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count곡',
      zero: '곡 없음',
    );
    return '$_temp0';
  }

  @override
  String get update_later => '나중에';

  @override
  String get update_ready_message => '새 버전이 준비되었습니다';

  @override
  String get update_restart_action => '다시 시작';

  @override
  String get update_restart_manual_hint => '업데이트를 적용하려면 앱을 완전히 종료한 후 다시 열어 주세요';

  @override
  String get update_store_action => '업데이트';

  @override
  String get update_store_message => 'Google Play에 새 버전이 있습니다. 지금 업데이트할까요?';
}

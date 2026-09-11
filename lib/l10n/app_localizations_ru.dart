// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get app_title => 'Плеер текстов Lyrics Player';

  @override
  String get tab_music_list => 'Музыка';

  @override
  String get tab_player => 'Плеер';

  @override
  String get tab_profile => 'Профиль';

  @override
  String get tab_more => 'Ещё';

  @override
  String get profile_account => 'Аккаунт и синхронизация';

  @override
  String get backup_link => 'Связать с Google Диском';

  @override
  String get backup_unlink => 'Отвязать';

  @override
  String get backup_relink => 'Связать заново';

  @override
  String get backup_not_linked => 'Не связано';

  @override
  String get backup_busy => 'Идёт синхронизация. Подождите немного.';

  @override
  String backup_linked_as(String email) {
    return 'Связано как $email';
  }

  @override
  String get backup_needs_relink =>
      'Срок авторизации истёк. Свяжите Google Диск заново.';

  @override
  String get backup_link_failed => 'Не удалось связать. Попробуйте ещё раз.';

  @override
  String get backup_unlink_confirm =>
      'После отвязки резервное копирование прекратится. Файлы резервных копий на Google Диске сохранятся.';

  @override
  String get backup_cloud_found_title => 'Выберите данные резервной копии';

  @override
  String get backup_cloud_found_message =>
      'В облаке уже есть резервная копия. Выберите: использовать данные из облака или сохранить данные этого устройства.';

  @override
  String get backup_cloud_found_more => 'Подробнее';

  @override
  String get backup_cloud_found_includes => 'Резервная копия включает:';

  @override
  String get backup_item_settings => 'Настройки';

  @override
  String get backup_item_playlists => 'Плейлисты';

  @override
  String get backup_item_statistics => 'Статистика прослушивания';

  @override
  String get backup_item_lyrics => 'Тексты песен';

  @override
  String get backup_use_cloud => 'Использовать копию';

  @override
  String get backup_keep_local => 'Оставить данные устройства';

  @override
  String get backup_last_backed_up => 'Последняя копия';

  @override
  String get backup_never_backed_up => 'Ещё не синхронизировано';

  @override
  String get backup_sync_now => 'Синхронизировать сейчас';

  @override
  String get backup_description =>
      'Резервная копия включает настройки, плейлисты, статистику прослушивания и тексты песен. Музыкальные файлы не загружаются. Копии хранятся в области данных приложения вашего собственного Google Диска; просмотреть или удалить их можно в настройках Google Диска → Управление приложениями.';

  @override
  String get backup_done => 'Синхронизировано с облаком';

  @override
  String get backup_restored => 'Синхронизировано на это устройство';

  @override
  String get backup_failed =>
      'Ошибка синхронизации. Проверьте подключение и попробуйте ещё раз.';

  @override
  String get backup_drive_full =>
      'Ваш Google Диск заполнен. Освободите место и попробуйте ещё раз.';

  @override
  String get profile_statistics => 'Статистика';

  @override
  String get profile_settings => 'Настройки';

  @override
  String get profile_about => 'О приложении';

  @override
  String get profile_reset => 'Сбросить';

  @override
  String get profile_reset_title => 'Сбросить приложение?';

  @override
  String get profile_reset_message =>
      'Будут сброшены только данные приложения. Медиафайлы на этом устройстве не будут удалены.';

  @override
  String get profile_reset_restart_hint =>
      'Сброс выполнен. Полностью закройте приложение и откройте его снова.';

  @override
  String get profile_feedback => 'Обратная связь';

  @override
  String profile_feedback_no_mail_app(String email) {
    return 'Почтовое приложение не найдено. Напишите напрямую на $email.';
  }

  @override
  String get player_play => 'Воспроизвести';

  @override
  String get player_pause => 'Пауза';

  @override
  String get player_next => 'Следующий';

  @override
  String get player_previous => 'Предыдущий';

  @override
  String get player_shuffle => 'Случайно';

  @override
  String get player_loop => 'Повтор';

  @override
  String get player_share => 'Поделиться';

  @override
  String get player_mode_sequential => 'По порядку';

  @override
  String get player_mode_repeat_one => 'Повтор одного';

  @override
  String player_forward(int seconds) {
    return 'Вперёд $secondsс';
  }

  @override
  String player_rewind(int seconds) {
    return 'Назад $secondsс';
  }

  @override
  String get player_speed => 'Скорость воспроизведения';

  @override
  String get player_seek_step => 'Шаг перемотки';

  @override
  String get common_reset => 'Сброс';

  @override
  String get player_nothing_playing => 'Ничего не воспроизводится';

  @override
  String get music_import => 'Импорт музыки';

  @override
  String music_import_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировано $count трека',
      many: 'Импортировано $count треков',
      few: 'Импортировано $count трека',
      one: 'Импортирован $count трек',
    );
    return '$_temp0';
  }

  @override
  String get music_empty_import =>
      'Музыки пока нет. Нажмите «Импорт музыки» или добавьте аудиофайлы в папку приложения через приложение «Файлы».';

  @override
  String get music_search => 'Поиск';

  @override
  String get music_empty =>
      'Музыки пока нет. Загрузите песни с устройства заново.';

  @override
  String get music_remove => 'Удалить';

  @override
  String get music_rescan => 'Пересканировать';

  @override
  String get music_track_info => 'О треке';

  @override
  String get track_info_artist => 'Исполнитель';

  @override
  String get track_info_duration => 'Длительность';

  @override
  String get track_info_location => 'Расположение';

  @override
  String get common_unknown => 'Неизвестно';

  @override
  String get permission_title => 'Требуется разрешение на доступ к хранилищу';

  @override
  String get permission_message =>
      'Нам нужен доступ к вашим аудиофайлам для сканирования и воспроизведения локальной музыки.';

  @override
  String get permission_allow => 'Разрешить';

  @override
  String get permission_deny => 'Не сейчас';

  @override
  String get permission_open_settings => 'Открыть настройки';

  @override
  String get settings_language => 'Язык';

  @override
  String get settings_language_system => 'Системный язык';

  @override
  String get settings_theme => 'Тема';

  @override
  String get settings_theme_system => 'Системная';

  @override
  String get settings_theme_light => 'Светлая';

  @override
  String get settings_theme_dark => 'Тёмная';

  @override
  String get statistics_total_time => 'Общее время прослушивания';

  @override
  String get statistics_play_count => 'Всего прослушиваний';

  @override
  String get statistics_top_tracks => 'Самые прослушиваемые';

  @override
  String get statistics_empty => 'Пока нет статистики';

  @override
  String get statistics_reset => 'Сбросить статистику';

  @override
  String get statistics_reset_title => 'Сбросить статистику?';

  @override
  String get statistics_reset_message =>
      'Вся статистика прослушивания на этом устройстве будет удалена. Это действие нельзя отменить.';

  @override
  String get statistics_reset_message_cloud =>
      'Вся статистика прослушивания на этом устройстве и в облачной резервной копии будет удалена. Это действие нельзя отменить.';

  @override
  String get statistics_reset_confirm => 'Сбросить';

  @override
  String get statistics_chart_title => 'Время прослушивания';

  @override
  String get statistics_chart_week => 'Неделя';

  @override
  String get statistics_chart_month => 'Месяц';

  @override
  String get statistics_chart_year => 'Год';

  @override
  String get about_version => 'Версия';

  @override
  String get about_developer => 'Разработчик';

  @override
  String get about_licenses => 'Лицензии открытого ПО';

  @override
  String get about_privacy => 'Политика конфиденциальности';

  @override
  String get about_open_source => 'Пакеты с открытым исходным кодом';

  @override
  String get account_guest => 'Гость';

  @override
  String get account_signed_out_message =>
      'Войдите, чтобы синхронизировать данные между устройствами.';

  @override
  String get account_email => 'Эл. почта';

  @override
  String get account_password => 'Пароль';

  @override
  String get account_sign_in => 'Войти';

  @override
  String get account_sign_up => 'Зарегистрироваться';

  @override
  String get account_sign_in_google => 'Войти через Google';

  @override
  String get account_sign_in_facebook => 'Войти через Facebook';

  @override
  String get account_method_email => 'Войти по эл. почте';

  @override
  String get account_method_phone => 'Войти по телефону';

  @override
  String get account_phone => 'Номер телефона';

  @override
  String get account_send_code => 'Отправить код';

  @override
  String get account_sms_code => 'Код подтверждения';

  @override
  String get account_verify_code => 'Подтвердить и войти';

  @override
  String get account_code_sent => 'Мы отправили вам код подтверждения по SMS.';

  @override
  String get account_continue_guest => 'Продолжить как гость';

  @override
  String get account_sign_out => 'Выйти';

  @override
  String get account_delete => 'Удалить аккаунт';

  @override
  String get account_delete_confirm =>
      'Вы уверены, что хотите удалить аккаунт? Это действие нельзя отменить.';

  @override
  String get account_delete_data => 'Удалить данные аккаунта';

  @override
  String get account_delete_data_confirm =>
      'Удалить все облачные данные, сохранив аккаунт? Это действие нельзя отменить.';

  @override
  String get account_delete_data_done => 'Данные вашего аккаунта удалены.';

  @override
  String get account_forgot_password => 'Забыли пароль?';

  @override
  String get account_reset_sent => 'Письмо для сброса пароля отправлено';

  @override
  String get account_anonymous => 'Анонимный аккаунт';

  @override
  String get account_unavailable => 'Функции аккаунта временно недоступны.';

  @override
  String get account_sign_in_failed =>
      'Не удалось войти. Повторите попытку позже.';

  @override
  String get account_sign_up_failed =>
      'Не удалось зарегистрироваться. Попробуйте ещё раз.';

  @override
  String get account_sign_in_success => 'Вы вошли в аккаунт';

  @override
  String get account_invalid_credentials => 'Неверный аккаунт или пароль';

  @override
  String get account_signed_out => 'Вы вышли из аккаунта';

  @override
  String get account_sign_out_failed =>
      'Не удалось выйти. Повторите попытку позже.';

  @override
  String get account_operation_failed =>
      'Не удалось выполнить операцию. Повторите попытку позже.';

  @override
  String get common_cancel => 'Отмена';

  @override
  String get common_confirm => 'Подтвердить';

  @override
  String get common_ok => 'ОК';

  @override
  String get common_delete => 'Удалить';

  @override
  String get common_retry => 'Повторить';

  @override
  String get common_network_offline =>
      'Проверьте подключение к сети и попробуйте снова.';

  @override
  String get common_today => 'Сегодня';

  @override
  String get common_yesterday => 'Вчера';

  @override
  String get settings_color => 'Цвет темы';

  @override
  String get settings_gradient => 'Градиентная тема';

  @override
  String get settings_gradient_desc =>
      'Использовать градиентный фон цвета темы в плеере';

  @override
  String get settings_gradient_cover => 'Градиент по цвету обложки';

  @override
  String get settings_gradient_cover_desc =>
      'Использовать цвет текущей обложки для градиента плеера';

  @override
  String get settings_player_tab => 'Вкладка плеера по умолчанию';

  @override
  String get settings_player_tab_desc =>
      'Вкладка, открываемая при входе в плеер';

  @override
  String get settings_player_tab_artwork => 'Обложка';

  @override
  String get settings_player_tab_embedded_lyrics => 'Текст';

  @override
  String get settings_player_tab_full_screen_lyrics => 'Текст на весь экран';

  @override
  String get settings_player_tab_full_screen_lyrics_desc =>
      'Для треков без текста показывается обложка';

  @override
  String get lyrics_import => 'Импортировать текст';

  @override
  String get lyrics_import_success => 'Текст песни импортирован';

  @override
  String get lyrics_import_failed => 'Не удалось импортировать текст';

  @override
  String get lyrics_import_too_large => 'Файл с текстом слишком большой';

  @override
  String get lyrics_import_empty => 'В этом файле не найден текст';

  @override
  String get lyrics_search_online => 'Искать текст песни в интернете';

  @override
  String get lyrics_search_online_searching => 'Поиск текста песни…';

  @override
  String get lyrics_search_online_no_result =>
      'Текст не найден. Попробуйте другие ключевые слова.';

  @override
  String get lyrics_search_online_failed =>
      'Не удалось выполнить поиск текста. Проверьте подключение и повторите попытку.';

  @override
  String get lyrics_search_online_select => 'Выберите подходящий текст';

  @override
  String get lyrics_search_online_applied => 'Текст применён';

  @override
  String get lyrics_empty => 'Для этого трека пока нет текста';

  @override
  String get lyrics_reimport => 'Импортировать заново';

  @override
  String get lyrics_download => 'Скачать текст';

  @override
  String get lyrics_download_success => 'Текст сохранён';

  @override
  String get lyrics_download_failed => 'Не удалось сохранить текст';

  @override
  String get lyrics_delete => 'Удалить текст';

  @override
  String get lyrics_delete_confirm => 'Удалить текст этого трека?';

  @override
  String get lyrics_show => 'Показать текст';

  @override
  String get lyrics_hide => 'Выйти из полноэкранного текста';

  @override
  String get cover_edit => 'Изменить обложку';

  @override
  String get cover_add => 'Добавить обложку';

  @override
  String get cover_change => 'Сменить обложку';

  @override
  String get cover_remove => 'Удалить обложку';

  @override
  String get cover_updated => 'Обложка обновлена';

  @override
  String get cover_removed => 'Обложка удалена';

  @override
  String get cover_failed => 'Не удалось установить обложку';

  @override
  String get cover_too_large => 'Изображение слишком большое';

  @override
  String get lyrics_font_size => 'Размер шрифта';

  @override
  String get lyrics_text_align => 'Выравнивание текста';

  @override
  String get lyrics_text_align_left => 'Слева';

  @override
  String get lyrics_text_align_center => 'По центру';

  @override
  String get lyrics_text_align_right => 'Справа';

  @override
  String get lyrics_auto_sync => 'Синхронизация текста';

  @override
  String get lyrics_auto_sync_compressing => 'Подготовка аудио…';

  @override
  String get lyrics_auto_sync_uploading => 'Загрузка аудио…';

  @override
  String get lyrics_auto_sync_aligning => 'Выравнивание текста…';

  @override
  String get lyrics_auto_sync_success =>
      'Текст синхронизирован (автоматически, возможны неточности)';

  @override
  String get lyrics_auto_sync_failed =>
      'Не удалось синхронизировать текст; оставлен исходный';

  @override
  String get lyrics_auto_sync_request_success =>
      'Запрос на синхронизацию текста отправлен';

  @override
  String get lyrics_auto_sync_request_failed =>
      'Не удалось отправить запрос на синхронизацию текста';

  @override
  String get lyrics_background_busy =>
      'Уже обрабатывается другая песня. Повторите попытку позже.';

  @override
  String lyrics_background_busy_named(String title) {
    return 'Повторите попытку позже. Сейчас обрабатывается: «$title».';
  }

  @override
  String get lyrics_ai_generate_running_background =>
      'Текст создаётся в фоновом режиме…';

  @override
  String get lyrics_auto_sync_running_background =>
      'Текст синхронизируется в фоновом режиме…';

  @override
  String get lyrics_auto_sync_need_login =>
      'Войдите, чтобы использовать автосинхронизацию';

  @override
  String get lyrics_auto_sync_rate_limited =>
      'Достигнут дневной лимит синхронизации, попробуйте завтра';

  @override
  String get lyrics_auto_sync_no_audio => 'Аудиофайл не найден';

  @override
  String get lyrics_auto_sync_network =>
      'Проблема с подключением, повторите позже';

  @override
  String get lyrics_ai_generate => 'Создать текст с помощью ИИ';

  @override
  String get lyrics_ai_generate_compressing => 'Подготовка аудио…';

  @override
  String get lyrics_ai_generate_uploading => 'Загрузка аудио…';

  @override
  String get lyrics_ai_generate_transcribing => 'Создание текста…';

  @override
  String get lyrics_ai_generate_success =>
      'Текст создан (автоматически, возможны неточности)';

  @override
  String get lyrics_ai_generate_failed => 'Не удалось создать текст';

  @override
  String get lyrics_ai_generate_request_success =>
      'Запрос на создание текста отправлен';

  @override
  String get lyrics_ai_generate_request_failed =>
      'Не удалось отправить запрос на создание текста';

  @override
  String get lyrics_ai_generate_need_login =>
      'Войдите, чтобы использовать автосоздание';

  @override
  String get lyrics_ai_generate_rate_limited =>
      'Достигнут дневной лимит создания, попробуйте завтра';

  @override
  String get lyrics_ai_generate_no_audio => 'Аудиофайл не найден';

  @override
  String get lyrics_ai_generate_network =>
      'Проблема с подключением, повторите позже';

  @override
  String get lyrics_usage_limit_reached =>
      'Достигнут месячный лимит бесплатного использования. Повторите попытку в следующем месяце.';

  @override
  String get lyrics_job_busy => 'Дождитесь завершения текущей задачи с текстом';

  @override
  String get lyrics_job_processing => 'Обработка текста…';

  @override
  String get lyrics_job_cancelled => 'Задача с текстом отменена';

  @override
  String get lyrics_action_running_suffix => ' (Выполняется)';

  @override
  String get lyrics_job_error_invalid_request =>
      'Произошла ошибка запроса. Повторите попытку.';

  @override
  String get lyrics_job_error_audio_fetch_failed =>
      'Не удалось загрузить аудиофайл. Повторите попытку.';

  @override
  String get lyrics_job_error_align_model_unavailable =>
      'Служба синхронизации временно недоступна. Повторите попытку позже.';

  @override
  String get lyrics_job_error_alignment_failed =>
      'Не удалось синхронизировать текст с аудио.';

  @override
  String get lyrics_job_error_transcription_failed =>
      'Не удалось распознать текст этой песни.';

  @override
  String get lyrics_job_error_internal =>
      'Произошла ошибка. Повторите попытку позже.';

  @override
  String get lyrics_job_error_firestore_write_failed =>
      'Текст обработан, но не удалось сохранить его. Повторите попытку.';

  @override
  String get lyrics_job_error_unknown => 'Не удалось обработать текст.';

  @override
  String get tab_playlists => 'Плейлисты';

  @override
  String get playlist_favorites => 'Избранное';

  @override
  String get playlist_recently_played => 'История';

  @override
  String get playlist_local_music => 'Локальная музыка';

  @override
  String get playlist_clear_recently_played => 'Очистить историю';

  @override
  String get playlist_clear_recently_played_confirm =>
      'Очистить всю историю прослушивания?';

  @override
  String get playlist_new => 'Новый плейлист';

  @override
  String get playlist_name_hint => 'Название плейлиста';

  @override
  String get playlist_rename => 'Переименовать';

  @override
  String get playlist_delete => 'Удалить плейлист';

  @override
  String playlist_delete_confirm(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get playlist_add_to => 'Добавить в плейлист';

  @override
  String get playlist_add_tracks => 'Добавить в этот плейлист';

  @override
  String get playlist_edit_tracks => 'Редактировать плейлист';

  @override
  String get playlist_all_added => 'Все песни уже добавлены в этот плейлист';

  @override
  String get playlist_add_item => 'Добавить';

  @override
  String get playlist_edit => 'Изменить';

  @override
  String playlist_added(String name) {
    return 'Добавлено в «$name»';
  }

  @override
  String playlist_already_added(String name) {
    return 'Уже в «$name»';
  }

  @override
  String get playlist_remove_track => 'Удалить из плейлиста';

  @override
  String get playlist_empty => 'В этом плейлисте пока нет песен';

  @override
  String get playlists_empty => 'Плейлистов пока нет';

  @override
  String get playlist_search_hint => 'Что хотите послушать?';

  @override
  String get playlist_search_no_result => 'Нет подходящих песен';

  @override
  String get playlist_play_all => 'Воспроизвести все';

  @override
  String playlist_track_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count песни',
      many: '$count песен',
      few: '$count песни',
      one: '$count песня',
      zero: 'Нет песен',
    );
    return '$_temp0';
  }

  @override
  String get update_later => 'Позже';

  @override
  String get update_ready_message => 'Новая версия готова';

  @override
  String get update_restart_action => 'Перезапустить';

  @override
  String get update_restart_manual_hint =>
      'Полностью закройте приложение и откройте его снова, чтобы применить обновление.';

  @override
  String get update_store_action => 'Обновить';

  @override
  String get update_store_message =>
      'В Google Play доступна новая версия. Обновить сейчас?';
}

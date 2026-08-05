// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get app_title => 'Lecteur de paroles Lyrics Player';

  @override
  String get tab_music_list => 'Musique';

  @override
  String get tab_player => 'Lecteur';

  @override
  String get tab_profile => 'Profil';

  @override
  String get profile_account => 'Compte';

  @override
  String get profile_statistics => 'Statistiques';

  @override
  String get profile_settings => 'Paramètres';

  @override
  String get profile_about => 'À propos';

  @override
  String get player_play => 'Lire';

  @override
  String get player_pause => 'Pause';

  @override
  String get player_next => 'Suivant';

  @override
  String get player_previous => 'Précédent';

  @override
  String get player_shuffle => 'Aléatoire';

  @override
  String get player_loop => 'Répéter';

  @override
  String get player_share => 'Partager';

  @override
  String get player_mode_sequential => 'Séquentiel';

  @override
  String get player_mode_repeat_one => 'Répéter un titre';

  @override
  String get player_forward => 'Avancer 5s';

  @override
  String get player_rewind => 'Reculer 5s';

  @override
  String get player_speed => 'Vitesse de lecture';

  @override
  String get common_reset => 'Réinitialiser';

  @override
  String get player_nothing_playing => 'Aucune lecture en cours';

  @override
  String get music_import => 'Importer de la musique';

  @override
  String get music_search => 'Rechercher';

  @override
  String get music_empty => 'Aucune musique trouvée';

  @override
  String get music_remove => 'Retirer';

  @override
  String get music_rescan => 'Réanalyser';

  @override
  String get music_track_info => 'Infos du morceau';

  @override
  String get track_info_artist => 'Artiste';

  @override
  String get track_info_duration => 'Durée';

  @override
  String get track_info_location => 'Emplacement';

  @override
  String get common_unknown => 'Inconnu';

  @override
  String get permission_title => 'Autorisation de stockage requise';

  @override
  String get permission_message =>
      'Nous avons besoin d\'accéder à vos fichiers audio pour analyser et lire la musique locale.';

  @override
  String get permission_allow => 'Autoriser';

  @override
  String get permission_deny => 'Pas maintenant';

  @override
  String get permission_open_settings => 'Ouvrir les paramètres';

  @override
  String get settings_language => 'Langue';

  @override
  String get settings_language_system => 'Par défaut du système';

  @override
  String get settings_theme => 'Thème';

  @override
  String get settings_theme_system => 'Système';

  @override
  String get settings_theme_light => 'Clair';

  @override
  String get settings_theme_dark => 'Sombre';

  @override
  String get statistics_total_time => 'Temps d\'écoute total';

  @override
  String get statistics_play_count => 'Lectures totales';

  @override
  String get statistics_top_tracks => 'Les plus écoutées';

  @override
  String get statistics_empty => 'Pas encore de statistiques';

  @override
  String get statistics_reset => 'Réinitialiser les statistiques';

  @override
  String get statistics_reset_title => 'Réinitialiser les statistiques ?';

  @override
  String get statistics_reset_message =>
      'Toutes les statistiques d\'écoute sur cet appareil seront supprimées. Cette action est irréversible.';

  @override
  String get statistics_reset_message_cloud =>
      'Toutes les statistiques d\'écoute sur cet appareil et dans votre sauvegarde cloud seront supprimées. Cette action est irréversible.';

  @override
  String get statistics_reset_confirm => 'Réinitialiser';

  @override
  String get statistics_chart_title => 'Temps d\'écoute';

  @override
  String get statistics_chart_week => 'Semaine';

  @override
  String get statistics_chart_month => 'Mois';

  @override
  String get statistics_chart_year => 'Année';

  @override
  String get about_version => 'Version';

  @override
  String get about_developer => 'Développeur';

  @override
  String get about_licenses => 'Licences open source';

  @override
  String get about_privacy => 'Politique de confidentialité';

  @override
  String get about_open_source => 'Paquets open source';

  @override
  String get account_guest => 'Invité';

  @override
  String get account_signed_out_message =>
      'Connectez-vous pour synchroniser vos données sur tous vos appareils.';

  @override
  String get account_email => 'E-mail';

  @override
  String get account_password => 'Mot de passe';

  @override
  String get account_sign_in => 'Se connecter';

  @override
  String get account_sign_up => 'S\'inscrire';

  @override
  String get account_sign_in_google => 'Se connecter avec Google';

  @override
  String get account_sign_in_facebook => 'Se connecter avec Facebook';

  @override
  String get account_method_email => 'Se connecter par e-mail';

  @override
  String get account_method_phone => 'Se connecter par téléphone';

  @override
  String get account_phone => 'Numéro de téléphone';

  @override
  String get account_send_code => 'Envoyer le code';

  @override
  String get account_sms_code => 'Code de vérification';

  @override
  String get account_verify_code => 'Vérifier et se connecter';

  @override
  String get account_code_sent =>
      'Nous vous avons envoyé un code de vérification par SMS.';

  @override
  String get account_continue_guest => 'Continuer en tant qu\'invité';

  @override
  String get account_sign_out => 'Se déconnecter';

  @override
  String get account_delete => 'Supprimer le compte';

  @override
  String get account_delete_confirm =>
      'Voulez-vous vraiment supprimer votre compte ? Cette action est irréversible.';

  @override
  String get account_delete_data => 'Supprimer les données du compte';

  @override
  String get account_delete_data_confirm =>
      'Supprimer toutes vos données cloud tout en conservant votre compte ? Cette action est irréversible.';

  @override
  String get account_delete_data_done =>
      'Les données de votre compte ont été supprimées.';

  @override
  String get account_forgot_password => 'Mot de passe oublié ?';

  @override
  String get account_reset_sent =>
      'E-mail de réinitialisation du mot de passe envoyé';

  @override
  String get account_anonymous => 'Compte anonyme';

  @override
  String get account_unavailable =>
      'Les fonctionnalités du compte sont temporairement indisponibles.';

  @override
  String get account_sign_in_failed =>
      'Échec de la connexion. Veuillez réessayer.';

  @override
  String get account_sign_up_failed =>
      'Échec de l\'inscription. Veuillez réessayer.';

  @override
  String get account_operation_failed =>
      'L\'opération a échoué. Veuillez réessayer plus tard.';

  @override
  String account_last_synced(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get account_never_synced => 'Pas encore synchronisé';

  @override
  String get account_sync_now => 'Synchroniser maintenant';

  @override
  String get account_sync_done => 'Synchronisé';

  @override
  String get account_sync_failed =>
      'Échec de la synchronisation. Vérifiez votre connexion et réessayez.';

  @override
  String get common_cancel => 'Annuler';

  @override
  String get common_confirm => 'Confirmer';

  @override
  String get common_ok => 'OK';

  @override
  String get common_delete => 'Supprimer';

  @override
  String get common_retry => 'Réessayer';

  @override
  String get common_today => 'Aujourd\'hui';

  @override
  String get common_yesterday => 'Hier';

  @override
  String get settings_color => 'Couleur du thème';

  @override
  String get settings_gradient => 'Thème dégradé';

  @override
  String get settings_gradient_desc =>
      'Utiliser un fond dégradé aux couleurs du thème dans le lecteur';

  @override
  String get settings_gradient_cover => 'Dégradé selon la pochette';

  @override
  String get settings_gradient_cover_desc =>
      'Utiliser la couleur de la pochette actuelle pour le dégradé du lecteur';

  @override
  String get settings_auto_lyrics => 'Paroles plein écran auto';

  @override
  String get settings_auto_lyrics_desc =>
      'Afficher automatiquement les paroles en plein écran pour les titres qui en ont';

  @override
  String get lyrics_import => 'Importer les paroles';

  @override
  String get lyrics_import_success => 'Paroles importées';

  @override
  String get lyrics_import_failed => 'Impossible d\'importer les paroles';

  @override
  String get lyrics_import_too_large =>
      'Le fichier de paroles est trop volumineux';

  @override
  String get lyrics_import_empty => 'Aucune parole trouvée dans ce fichier';

  @override
  String get lyrics_empty => 'Pas encore de paroles pour ce titre';

  @override
  String get lyrics_reimport => 'Réimporter';

  @override
  String get lyrics_delete => 'Supprimer les paroles';

  @override
  String get lyrics_delete_confirm => 'Supprimer les paroles de ce titre ?';

  @override
  String get lyrics_show => 'Afficher les paroles';

  @override
  String get lyrics_hide => 'Afficher la pochette';

  @override
  String get cover_edit => 'Modifier la pochette';

  @override
  String get cover_add => 'Ajouter une pochette';

  @override
  String get cover_change => 'Changer la pochette';

  @override
  String get cover_remove => 'Supprimer la pochette';

  @override
  String get cover_updated => 'Pochette mise à jour';

  @override
  String get cover_removed => 'Pochette supprimée';

  @override
  String get cover_failed => 'Impossible de définir la pochette';

  @override
  String get cover_too_large => 'L’image est trop grande';

  @override
  String get lyrics_font_size => 'Taille de police';

  @override
  String get lyrics_auto_sync => 'Synchroniser les paroles';

  @override
  String get lyrics_auto_sync_compressing => 'Préparation de l’audio…';

  @override
  String get lyrics_auto_sync_uploading => 'Envoi de l’audio…';

  @override
  String get lyrics_auto_sync_aligning => 'Alignement des paroles…';

  @override
  String get lyrics_auto_sync_success =>
      'Paroles synchronisées (auto, peut être imprécis)';

  @override
  String get lyrics_auto_sync_failed =>
      'Impossible de synchroniser les paroles ; texte d’origine conservé';

  @override
  String get lyrics_auto_sync_request_success =>
      'Demande de synchronisation des paroles envoyée';

  @override
  String get lyrics_auto_sync_request_failed =>
      'Échec de l\'envoi de la demande de synchronisation des paroles';

  @override
  String get lyrics_background_busy =>
      'Une autre chanson est déjà en cours de traitement. Veuillez réessayer plus tard.';

  @override
  String lyrics_background_busy_named(String title) {
    return 'Veuillez réessayer plus tard. En cours de traitement : « $title ».';
  }

  @override
  String get lyrics_auto_generate_running_background =>
      'Génération des paroles en arrière-plan…';

  @override
  String get lyrics_auto_sync_running_background =>
      'Synchronisation des paroles en arrière-plan…';

  @override
  String get lyrics_auto_sync_need_login =>
      'Connectez-vous pour utiliser la synchronisation automatique';

  @override
  String get lyrics_auto_sync_rate_limited =>
      'Limite quotidienne de synchronisation atteinte, réessayez demain';

  @override
  String get lyrics_auto_sync_no_audio => 'Fichier audio introuvable';

  @override
  String get lyrics_auto_sync_network =>
      'Problème de connexion, réessayez plus tard';

  @override
  String get lyrics_auto_generate => 'Générer les paroles automatiquement';

  @override
  String get lyrics_auto_generate_compressing => 'Préparation de l’audio…';

  @override
  String get lyrics_auto_generate_uploading => 'Téléversement de l’audio…';

  @override
  String get lyrics_auto_generate_transcribing => 'Génération des paroles…';

  @override
  String get lyrics_auto_generate_success =>
      'Paroles générées (auto, peut être imprécis)';

  @override
  String get lyrics_auto_generate_failed => 'Impossible de générer les paroles';

  @override
  String get lyrics_auto_generate_request_success =>
      'Demande de génération des paroles envoyée';

  @override
  String get lyrics_auto_generate_request_failed =>
      'Échec de l\'envoi de la demande de génération des paroles';

  @override
  String get lyrics_auto_generate_need_login =>
      'Connectez-vous pour utiliser la génération automatique';

  @override
  String get lyrics_auto_generate_rate_limited =>
      'Limite quotidienne de génération atteinte, réessayez demain';

  @override
  String get lyrics_auto_generate_no_audio => 'Fichier audio introuvable';

  @override
  String get lyrics_auto_generate_network =>
      'Problème de connexion, réessayez plus tard';

  @override
  String get lyrics_usage_limit_reached =>
      'Limite mensuelle d\'utilisation gratuite atteinte. Réessayez le mois prochain.';

  @override
  String get lyrics_job_busy =>
      'Veuillez attendre la fin de la tâche de paroles en cours';

  @override
  String get lyrics_job_processing => 'Traitement des paroles…';

  @override
  String get lyrics_job_cancelled => 'Tâche de paroles annulée';

  @override
  String get lyrics_action_running_suffix => ' (En cours)';

  @override
  String get lyrics_job_error_invalid_request =>
      'Une erreur est survenue avec la requête. Veuillez réessayer.';

  @override
  String get lyrics_job_error_audio_fetch_failed =>
      'Impossible de télécharger le fichier audio. Veuillez réessayer.';

  @override
  String get lyrics_job_error_align_model_unavailable =>
      'Le service de synchronisation est temporairement indisponible. Veuillez réessayer plus tard.';

  @override
  String get lyrics_job_error_alignment_failed =>
      'Impossible de synchroniser les paroles avec l\'audio.';

  @override
  String get lyrics_job_error_transcription_failed =>
      'Impossible de reconnaître les paroles de ce titre.';

  @override
  String get lyrics_job_error_internal =>
      'Une erreur est survenue. Veuillez réessayer plus tard.';

  @override
  String get lyrics_job_error_firestore_write_failed =>
      'Les paroles ont été traitées mais n\'ont pas pu être enregistrées. Veuillez réessayer.';

  @override
  String get lyrics_job_error_unknown => 'Impossible de traiter les paroles.';

  @override
  String get tab_playlists => 'Playlists';

  @override
  String get playlist_favorites => 'Favoris';

  @override
  String get playlist_recently_played => 'Écouté récemment';

  @override
  String get playlist_clear_recently_played => 'Effacer l\'historique';

  @override
  String get playlist_clear_recently_played_confirm =>
      'Effacer tout l\'historique d\'écoute ?';

  @override
  String get playlist_new => 'Nouvelle playlist';

  @override
  String get playlist_name_hint => 'Nom de la playlist';

  @override
  String get playlist_rename => 'Renommer';

  @override
  String get playlist_delete => 'Supprimer la playlist';

  @override
  String playlist_delete_confirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get playlist_add_to => 'Ajouter à la playlist';

  @override
  String get playlist_add_tracks => 'Ajouter à cette playlist';

  @override
  String get playlist_edit_tracks => 'Modifier la playlist';

  @override
  String get playlist_all_added =>
      'Tous les titres sont déjà dans cette playlist';

  @override
  String get playlist_add_item => 'Ajouter';

  @override
  String get playlist_edit => 'Modifier';

  @override
  String playlist_added(String name) {
    return 'Ajouté à « $name »';
  }

  @override
  String playlist_already_added(String name) {
    return 'Déjà dans « $name »';
  }

  @override
  String get playlist_remove_track => 'Retirer de la playlist';

  @override
  String get playlist_empty =>
      'Aucune chanson dans cette playlist pour l’instant';

  @override
  String get playlists_empty => 'Aucune playlist pour l’instant';

  @override
  String get playlist_play_all => 'Tout lire';

  @override
  String playlist_track_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chansons',
      one: '1 chanson',
      zero: 'Aucune chanson',
    );
    return '$_temp0';
  }

  @override
  String get update_later => 'Plus tard';

  @override
  String get update_ready_message => 'Une nouvelle version est prête';

  @override
  String get update_restart_action => 'Redémarrer';

  @override
  String get update_restart_manual_hint =>
      'Veuillez fermer complètement l\'application puis la rouvrir pour appliquer la mise à jour.';

  @override
  String get update_store_action => 'Mettre à jour';

  @override
  String get update_store_message =>
      'Une nouvelle version est disponible sur Google Play. Mettre à jour maintenant ?';
}

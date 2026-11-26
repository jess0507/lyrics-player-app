import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/library/models/library_section.dart';

/// 「媒體庫」分頁目前選中的區塊(本地音樂 / 播放清單),持久化於本機
/// SharedPreferences,下次開啟 app 時預設顯示上次選的區塊。預設本地音樂。
class LibrarySectionController extends Notifier<LibrarySection> {
  static const _key = 'library.section';
  static const LibrarySection defaultSection = LibrarySection.localMusic;

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  LibrarySection build() {
    final stored = _prefs.getString(_key);
    // 舊版或毀損的值一律回預設。
    return LibrarySection.values.firstWhere(
      (section) => section.name == stored,
      orElse: () => defaultSection,
    );
  }

  void select(LibrarySection section) {
    if (section == state) return;
    state = section;
    logAnalyticsAction(LibraryAction.switchSection, option: section);
    _prefs.setString(_key, section.name);
  }
}

final librarySectionProvider =
    NotifierProvider<LibrarySectionController, LibrarySection>(
      LibrarySectionController.new,
    );

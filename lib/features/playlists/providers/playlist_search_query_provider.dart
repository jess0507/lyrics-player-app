import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 播放清單分頁搜尋頁的搜尋字串（離開頁面即重置）。
final playlistSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

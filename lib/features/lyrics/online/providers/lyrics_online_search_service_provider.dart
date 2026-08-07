import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/online/services/lyrics_online_search_service.dart';
import 'package:seek_player/features/lyrics/online/providers/lrclib_client_provider.dart';

final lyricsOnlineSearchServiceProvider = Provider<LyricsOnlineSearchService>(
  (ref) => LyricsOnlineSearchService(ref.watch(lrclibClientProvider), ref),
);

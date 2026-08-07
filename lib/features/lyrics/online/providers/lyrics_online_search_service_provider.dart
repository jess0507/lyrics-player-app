import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lyrics_online_search_service.dart';
import 'lrclib_client_provider.dart';

final lyricsOnlineSearchServiceProvider = Provider<LyricsOnlineSearchService>(
  (ref) => LyricsOnlineSearchService(ref.watch(lrclibClientProvider), ref),
);

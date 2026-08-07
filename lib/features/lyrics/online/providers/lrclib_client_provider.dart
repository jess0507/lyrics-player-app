import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/online/services/lrclib_client.dart';

final lrclibClientProvider = Provider<LrclibClient>((ref) => LrclibClient());

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lrclib_client.dart';

final lrclibClientProvider = Provider<LrclibClient>((ref) => LrclibClient());

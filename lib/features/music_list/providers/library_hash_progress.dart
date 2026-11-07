import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 曲庫掃描時計算 trackId(音檔全檔 SHA-256)的進度。
typedef LibraryHashProgressValue = ({int done, int total});

/// 掃描中有檔案要算 trackId 時為目前進度,沒有在算時為 null。
/// TrackEntityMigrationGate 據此蓋上「更新音樂庫」畫面。
class LibraryHashProgress extends Notifier<LibraryHashProgressValue?> {
  @override
  LibraryHashProgressValue? build() => null;

  void update(int done, int total) => state = (done: done, total: total);

  void clear() => state = null;
}

final libraryHashProgressProvider =
    NotifierProvider<LibraryHashProgress, LibraryHashProgressValue?>(
      LibraryHashProgress.new,
    );

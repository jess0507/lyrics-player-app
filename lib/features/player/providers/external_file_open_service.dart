import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/router/app_router.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';
import 'package:seek_player/features/player/providers/player_sheet_controller.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';

/// 接住從檔案管理員等 App「開啟工具」／分享叫進來的音訊檔（見 Android
/// manifest 的 VIEW intent-filter，`audio/*`），計算內容指紋比對音樂庫：
/// 命中就照一般曲目播放，否則以檔案本身組一首暫時曲目播放，並開啟播放器。
///
/// 於 `app.dart` 根層級常駐 watch，不綁定特定頁面，冷啟動（[getInitialMedia]）
/// 與已在前景時再次觸發（[getMediaStream]）都要接。
class ExternalFileOpenService {
  ExternalFileOpenService(this._ref) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<List<SharedMediaFile>>? _sub;

  void _init() {
    unawaited(_handleInitial());
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleMedia,
      onError: (Object e, StackTrace s) => reportError(
        e,
        s,
        reason: 'ExternalFileOpenService 監聽外部開啟意圖失敗',
      ),
    );
    _ref.onDispose(() => _sub?.cancel());
  }

  Future<void> _handleInitial() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      if (media.isNotEmpty) await _handleMedia(media);
    } catch (e, s) {
      reportError(e, s, reason: 'ExternalFileOpenService 讀取冷啟動開啟意圖失敗');
    }
  }

  Future<void> _handleMedia(List<SharedMediaFile> media) async {
    final file = media
        .where((f) => f.mimeType?.startsWith('audio/') ?? false)
        .firstOrNull;
    if (file == null) return;
    await ReceiveSharingIntent.instance.reset();
    await _openTrack(file.path);
  }

  /// 用內容指紋比對既有音樂庫：命中沿用該曲目（含正確 metadata），
  /// 否則以檔案路徑組一首暫時曲目（標題退回檔名）。
  Future<void> _openTrack(String path) async {
    final fingerprints = await _ref
        .read(trackFingerprintServiceProvider)
        .fingerprints([path]);
    final id = fingerprints[path];
    final tracks = _ref.read(musicLibraryProvider).valueOrNull ?? const [];
    final existing = id == null
        ? null
        : tracks.where((t) => t.id == id).firstOrNull;

    final playback = _ref.read(playbackControllerProvider);
    if (existing != null) {
      await playback.playTrack(existing);
    } else {
      await playback.playTracksAt([
        Track(
          id: id ?? path,
          uri: Uri.file(path).toString(),
          filePath: path,
          title: _titleFromPath(path),
        ),
      ], 0);
    }
    await _openPlayerSheet();
  }

  String _titleFromPath(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> _openPlayerSheet() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await _ref.read(playerSheetControllerProvider.notifier).open(context);
  }
}

final externalFileOpenServiceProvider = Provider<ExternalFileOpenService>(
  (ref) => ExternalFileOpenService(ref),
);

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/router/app_router.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/player/providers/player_page_controller.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';

/// 接住從檔案管理員等 App「開啟工具」／分享叫進來的音訊檔(Android 限定,
/// 原生端見 `ExternalOpenChannel.kt`),以還原到的實體路徑比對音樂庫:
/// 命中就照一般曲目播放,否則以檔案本身組一首暫時曲目播放,並開啟播放器。
///
/// 於 `app.dart` 根層級常駐 watch,不綁定特定頁面。一律由 Dart 主動向
/// 原生 `takeLaunchIntent` 拉取(原生回傳後立刻清掉,不會重播):
/// 建立時拉一次(冷啟動),之後每次 app 回到前景再拉一次。
///
/// 為什麼要在 resume 時拉:audio_service 會把 FlutterEngine 留在快取,
/// 使用者滑掉 app 後 Activity 銷毀但 Dart 仍活著;從檔案再開 app 時只會
/// 重建 Activity 而不重跑 `main()`,沒有 resume 這一拉就永遠收不到新 intent。
/// 前景時再開一個檔走 `onNewIntent`,原生把它設成 activity.intent,
/// 緊接著的 onResume 一樣由這裡拉到,不需要另一條推送路徑。
class ExternalFileOpenService {
  ExternalFileOpenService(this._ref) {
    if (Platform.isAndroid) _init();
  }

  static const _channel = MethodChannel('seek_player/external_open');

  /// 冷啟動時音樂庫掃描仍在進行,最多等這麼久;逾時就當空清單直接播放。
  static const _libraryTimeout = Duration(seconds: 10);

  /// 冷啟動時 root navigator 可能尚未掛好,輪詢等待的間隔與上限。
  static const _navigatorPollInterval = Duration(milliseconds: 50);
  static const _navigatorPollTimeout = Duration(seconds: 5);

  final Ref _ref;
  AppLifecycleListener? _lifecycle;

  void _init() {
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_takeLaunchIntent()),
    );
    _ref.onDispose(() => _lifecycle?.dispose());
    unawaited(_takeLaunchIntent());
  }

  Future<void> _takeLaunchIntent() async {
    try {
      final args = await _channel.invokeMethod<Map<Object?, Object?>>(
        'takeLaunchIntent',
      );
      if (args != null) await _handle(args);
    } catch (e, s) {
      reportError(e, s, reason: 'ExternalFileOpenService 讀取外部開啟意圖失敗');
    }
  }

  Future<void> _handle(Object? raw) async {
    if (raw is! Map) return;
    final uri = raw['uri'] as String?;
    if (uri == null || uri.isEmpty) return;
    final filePath = raw['filePath'] as String? ?? '';

    try {
      final tracks = await _loadLibrary();
      final existing = filePath.isEmpty
          ? null
          : tracks.where((t) => t.filePath == filePath).firstOrNull;

      final playback = _ref.read(playbackControllerProvider);
      if (existing != null) {
        await playback.playTrack(existing);
      } else {
        await playback.playTracksAt([_buildTrack(raw, uri, filePath)], 0);
      }
    } catch (e, s) {
      // 播放失敗停留原頁,不開播放頁。
      reportError(e, s, reason: 'ExternalFileOpenService 播放外部開啟的檔案失敗');
      return;
    }
    await _openPlayerPage();
  }

  /// 冷啟動掃描中要等;逾時或未授權(build 直接回空清單)就當空清單。
  Future<List<Track>> _loadLibrary() async {
    try {
      return await _ref
          .read(musicLibraryProvider.future)
          .timeout(_libraryTimeout);
    } catch (_) {
      return const [];
    }
  }

  /// 以原始 content URI 播放(ExoPlayer 原生支援 content://,不走路徑讀檔),
  /// [filePath] 填還原到的實體路徑供曲目資訊顯示;標題優先內嵌 tag,
  /// 其次檔名去副檔名。
  Track _buildTrack(Map<Object?, Object?> args, String uri, String filePath) {
    final displayName = args['displayName'] as String?;
    final tagTitle = args['title'] as String?;
    final title = (tagTitle != null && tagTitle.isNotEmpty)
        ? tagTitle
        : _stripExtension(
            (displayName != null && displayName.isNotEmpty)
                ? displayName
                : _lastSegment(filePath.isNotEmpty ? filePath : uri),
          );
    return Track(
      id: filePath.isNotEmpty ? filePath : uri,
      uri: uri,
      filePath: filePath,
      title: title,
      artist: args['artist'] as String?,
      album: args['album'] as String?,
      durationMs: (args['durationMs'] as num?)?.toInt(),
    );
  }

  static String _lastSegment(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty);
    return segments.isEmpty ? path : segments.last;
  }

  static String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> _openPlayerPage() async {
    final deadline = DateTime.now().add(_navigatorPollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        await _ref.read(playerPageControllerProvider.notifier).open(context);
        return;
      }
      await Future<void>.delayed(_navigatorPollInterval);
    }
  }
}

final externalFileOpenServiceProvider = Provider<ExternalFileOpenService>(
  (ref) => ExternalFileOpenService(ref),
);

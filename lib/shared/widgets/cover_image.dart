import 'package:flutter/material.dart';

import 'package:seek_player/core/crash_reporter.dart';

/// 已回報過解碼失敗的封面;errorBuilder 每次重建都會被呼叫,同一張只回報一次。
final _reportedFailures = <ImageProvider>{};

/// 曲目封面圖。圖檔解不開(格式不支援 / 檔案損毀)時視同沒有封面,
/// 改顯示 [fallback]——通常就是呼叫端「沒有封面」時用的佔位圖。
///
/// 清單縮圖、mini player、播放頁、編輯頁共用。
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.image,
    required this.fallback,
    this.width,
    this.height,
    this.frameBuilder,
  });

  final ImageProvider image;

  /// 載入失敗時顯示的 widget。
  final Widget fallback;
  final double? width;
  final double? height;

  /// 包在成功載入的圖外層(圓角、間距等);載入失敗時不套用,只顯示 [fallback]。
  final ImageFrameBuilder? frameBuilder;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      width: width,
      height: height,
      fit: BoxFit.cover,
      frameBuilder: frameBuilder,
      errorBuilder: (context, error, stackTrace) {
        if (_reportedFailures.add(image)) {
          reportError(
            error,
            stackTrace ?? StackTrace.current,
            reason: '封面圖解碼失敗(${image.runtimeType})',
          );
        }
        return fallback;
      },
    );
  }
}

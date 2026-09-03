import 'package:flutter/material.dart';
import 'package:seek_player/gen/assets.gen.dart';

/// 以 SVG 資源當作 icon 使用的 widget,行為對齊 [Icon]:
/// 未指定 [size] / [color] 時跟隨最近的 [IconTheme],
/// 因此可直接放進 [IconButton]、[TextButton.icon] 等會設定 IconTheme 的元件。
class SvgIcon extends StatelessWidget {
  const SvgIcon(this.image, {super.key, this.size, this.color});

  final SvgGenImage image;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return image.svg(
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}

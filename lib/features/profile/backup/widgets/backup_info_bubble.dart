import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 帶箭頭的說明氣泡:鋪滿所在 overlay,把 [child] 放在 [target]
/// (以 overlay 座標表示的觸發元件矩形)下方,空間不足時改放上方,
/// 並在氣泡邊緣畫一個指向 [target] 中心的三角箭頭。
///
/// 位置與箭頭在同一個 render object 內計算:氣泡被螢幕邊緣往內推時,
/// 箭頭仍留在 target 正上/正下方,不會跟著氣泡一起偏移。
/// 本身不攔截 [child] 以外區域的點擊,收起邏輯由呼叫端處理。
class BackupInfoBubble extends SingleChildRenderObjectWidget {
  const BackupInfoBubble({
    super.key,
    required this.target,
    required this.color,
    required super.child,
  });

  final Rect target;
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBackupInfoBubble(target: target, color: color);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBackupInfoBubble renderObject,
  ) {
    renderObject
      ..target = target
      ..color = color;
  }
}

/// [BackupInfoBubble] 的 render object;僅供該 widget 使用。
class RenderBackupInfoBubble extends RenderShiftedBox {
  RenderBackupInfoBubble({required Rect target, required Color color})
    : _target = target,
      _color = color,
      super(null);

  /// 氣泡與螢幕邊緣的最小距離。
  static const _margin = 16.0;

  /// 箭頭尖端與 target 的距離。
  static const _gap = 4.0;
  static const _arrowWidth = 16.0;
  static const _arrowHeight = 8.0;
  static const _radius = 8.0;
  static const _maxWidth = 360.0;

  Rect _target;
  Rect get target => _target;
  set target(Rect value) {
    if (value == _target) return;
    _target = value;
    markNeedsLayout();
  }

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  /// 氣泡在 target 下方(箭頭朝上)或上方(箭頭朝下)。
  bool _below = true;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;

    final maxWidth = math.min(_maxWidth, size.width - _margin * 2);
    child.layout(
      BoxConstraints(maxWidth: math.max(0, maxWidth)),
      parentUsesSize: true,
    );
    final childSize = child.size;

    // 水平置中於 target,再夾在左右邊界內。
    final maxX = math.max(_margin, size.width - _margin - childSize.width);
    final x = (target.center.dx - childSize.width / 2).clamp(_margin, maxX);

    final needed = childSize.height + _arrowHeight + _gap;
    final spaceBelow = size.height - target.bottom - _margin;
    final spaceAbove = target.top - _margin;
    _below = spaceBelow >= needed || spaceBelow >= spaceAbove;
    final y = _below
        ? target.bottom + _gap + _arrowHeight
        : target.top - _gap - _arrowHeight - childSize.height;

    (child.parentData! as BoxParentData).offset = Offset(x, y);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final childOffset = (child.parentData! as BoxParentData).offset + offset;
    final rect = childOffset & child.size;
    final paint = Paint()..color = color;
    final canvas = context.canvas;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_radius)),
      paint,
    );

    // 箭頭尖端對準 target 中心,但不侵入圓角。底邊往氣泡內多延伸 1px,
    // 避免與圓角矩形交界處出現反鋸齒細縫。
    final tipX = (target.center.dx + offset.dx).clamp(
      rect.left + _radius + _arrowWidth / 2,
      rect.right - _radius - _arrowWidth / 2,
    );
    final arrow = Path();
    if (_below) {
      arrow
        ..moveTo(tipX - _arrowWidth / 2, rect.top + 1)
        ..lineTo(tipX, rect.top - _arrowHeight)
        ..lineTo(tipX + _arrowWidth / 2, rect.top + 1)
        ..close();
    } else {
      arrow
        ..moveTo(tipX - _arrowWidth / 2, rect.bottom - 1)
        ..lineTo(tipX, rect.bottom + _arrowHeight)
        ..lineTo(tipX + _arrowWidth / 2, rect.bottom - 1)
        ..close();
    }
    canvas.drawPath(arrow, paint);

    context.paintChild(child, childOffset);
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// 以 dart:ui 產生一張純色 PNG,寫到 [path];回傳該檔案。
///
/// 供封面取色測試用:純色圖的主色即該顏色,結果可精確斷言。
Future<File> writeSolidColorPng(
  String path,
  ui.Color color, {
  int width = 64,
  int height = 64,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(path);
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file;
}

/// 以 dart:ui 產生一張「[background] 底色 + 置中 [accent] 色方塊」的 PNG,
/// 方塊面積佔全圖 [accentShare](0~1),寫到 [path];回傳該檔案。
///
/// 供封面取色測試用:模擬黑底 / 白底加小 logo,或大面積彩色主體的封面。
Future<File> writeTwoTonePng(
  String path, {
  required ui.Color background,
  required ui.Color accent,
  required double accentShare,
  int width = 64,
  int height = 64,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = background,
  );
  final side = math.sqrt(width * height * accentShare);
  canvas.drawRect(
    ui.Rect.fromCenter(
      center: ui.Offset(width / 2, height / 2),
      width: side,
      height: side,
    ),
    ui.Paint()..color = accent,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(path);
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file;
}

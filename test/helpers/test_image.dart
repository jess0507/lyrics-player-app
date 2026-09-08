import 'dart:io';
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

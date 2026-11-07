// 對時前的歌詞斷行(純函式,可單元測試)。
//
// 對齊引擎是「一行一個時間戳」:一行塞了好幾句時,整行只拿到一個時間,
// 後面幾句都會跟著前面那句一起出現。送對齊前先在標點處斷開,讓每個
// 子句各自取得時間戳。

/// 斷點:
/// - 全形句讀(`，。！？；、`)不論後面接什麼都斷,後面緊接的全形 / 半形
///   右引號、右括號跟著前一段。
/// - 半形 `,.!?;` 只在後面接空白時斷,避免拆到 `3.5`、`Mr.Smith`、
///   `don't` 這類詞內標點。
final _breakAfter = RegExp(r'[，。！？；、]+[」』）)"”’]*|[,.!?;]+["”’)]*(?=\s)');

/// 去掉標點與空白後若沒有任何字,代表該段只有標點,不單獨成行。
final _punctOrSpace = RegExp(r'[\p{P}\p{S}\s]', unicode: true);

/// 把 [lines] 的每一行在標點處拆成多行,並去掉空白行。
/// 只有標點的片段併回前一段(沒有前一段時併入下一段)。
List<String> splitLyricsForAlignment(Iterable<String> lines) => [
  for (final line in lines) ..._splitLine(line),
];

List<String> _splitLine(String line) {
  final pieces = <String>[];
  var start = 0;
  for (final m in _breakAfter.allMatches(line)) {
    pieces.add(line.substring(start, m.end));
    start = m.end;
  }
  pieces.add(line.substring(start));

  final result = <String>[];
  var pending = '';
  for (final raw in pieces) {
    final piece = raw.trim();
    if (piece.isEmpty) continue;
    if (piece.replaceAll(_punctOrSpace, '').isEmpty) {
      // 只有標點:接在前一段後面;還沒有前一段就留給下一段開頭。
      if (result.isNotEmpty) {
        result[result.length - 1] = '${result.last}$piece';
      } else {
        pending = '$pending$piece';
      }
      continue;
    }
    result.add('$pending$piece');
    pending = '';
  }
  if (pending.isNotEmpty) result.add(pending);
  return result;
}

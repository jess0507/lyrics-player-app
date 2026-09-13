#!/usr/bin/env python3
"""
release_notes.py
把 docs/release-notes/vX.Y.Z.md(<語言碼>…</語言碼> 格式)拆成
r0adkll/upload-google-play 的 whatsNewDirectory 結構:
  <out_dir>/whatsnew-<語言碼>  每個語系一個純文字檔,內容即該語系的版本資訊。

release.yml 的 deploy job 用它把「這個版本有什麼新功能」隨 AAB 一起送上 Play Console。
拆檔前會先跑 .claude/skills/release-notes/check.py 的格式檢查(17 語系齊全、≤500 字元)。

用法(從專案根目錄執行):
  python3 scripts/release_notes.py docs/release-notes/v1.2.13.md build/whatsnew
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / ".claude" / "skills" / "release-notes"))
import check  # noqa: E402  (.claude/skills/release-notes/check.py)


def main(notes_path: str, out_dir: str) -> int:
    path = pathlib.Path(notes_path)
    if not path.is_file():
        print(f"❌ 找不到版本資訊檔:{path}")
        return 1
    if check.main(str(path)) != 0:
        return 1

    text = path.read_text(encoding="utf-8")
    out = pathlib.Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for lang in check.LANGS:
        m = re.search(
            rf"^<{re.escape(lang)}>\n(.*?)\n</{re.escape(lang)}>$", text, flags=re.S | re.M
        )
        (out / f"whatsnew-{lang}").write_text(m.group(1).strip() + "\n", encoding="utf-8")
    print(f"\n📝 已寫出 {len(check.LANGS)} 個 whatsnew 檔到 {out}/")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法:release_notes.py docs/release-notes/vX.Y.Z.md <out_dir>")
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))

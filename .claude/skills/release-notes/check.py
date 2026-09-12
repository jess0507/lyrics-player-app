#!/usr/bin/env python3
"""驗證 docs/release-notes/X.Y.Z.md 是否符合 Play Console 貼上格式。"""
import re
import sys

LANGS = [
    "zh-TW", "ar", "de-DE", "en-US", "es-419", "es-ES", "fr-FR", "hi-IN", "id",
    "it-IT", "ja-JP", "ko-KR", "pt-BR", "ru-RU", "tr-TR", "vi", "zh-CN",
]
LIMIT = 500  # Unicode code point 數(Python str 的 len 即為 code point 數)


def main(path: str) -> int:
    text = open(path, encoding="utf-8").read()
    lines = text.splitlines()
    errors: list[str] = []

    for i, line in enumerate(lines, 1):
        if line.startswith("#"):
            errors.append(f"line {i}: 不可有 Markdown 標題")
        if line.strip().startswith("```"):
            errors.append(f"line {i}: 不可有程式碼區塊")
        stripped = line.strip()
        if "<" in stripped and re.fullmatch(r"</?[A-Za-z]{2}(-[A-Za-z0-9]+)?>", stripped) is None:
            if re.search(r"</?[A-Za-z]{2}(-[A-Za-z0-9]+)?>", stripped):
                errors.append(f"line {i}: tag 必須獨立成行:{stripped!r}")

    found = re.findall(r"^<([A-Za-z0-9-]+)>$", text, flags=re.M)
    if found != LANGS:
        errors.append(f"語言順序/數量不符,應為 {LANGS},實際 {found}")

    print(f"{'lang':8} {'chars':>5}")
    for lang in found:
        m = re.search(rf"^<{re.escape(lang)}>\n(.*?)\n</{re.escape(lang)}>$", text, flags=re.S | re.M)
        if not m:
            errors.append(f"{lang}: 找不到成對的結尾 tag")
            continue
        n = len(m.group(1).strip())
        flag = f"  ← 超過 {LIMIT}" if n > LIMIT else ""
        print(f"{lang:8} {n:5}{flag}")
        if n > LIMIT:
            errors.append(f"{lang}: {n} 個 Unicode 字元,超過 {LIMIT}")

    if errors:
        print("\n❌ 檢查失敗:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("\n✅ 通過")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("用法:check.py docs/release-notes/X.Y.Z.md")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))

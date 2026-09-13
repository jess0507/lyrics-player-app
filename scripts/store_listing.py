#!/usr/bin/env python3
"""
store_listing.py
把 docs/store-listing/*.md 的商店文案(App 名稱 / 簡短說明 / 完整說明)
透過 Google Play Developer API 推到 Play Console 的各語系 listing。

流程:
  1. 解析 docs/store-listing/<語言>.md(README.md 除外),檢查 30 / 80 / 4000 字元上限。
  2. 建立一個 Play edit,讀取線上現況,只對「內容有差異」的語系送出 PUT。
  3. validate;有差異才 commit(--dry-run 時只印差異、丟棄 edit,不 commit)。

認證(擇一,依序偵測):
  - 環境變數 PLAY_SERVICE_ACCOUNT_JSON:服務帳號 JSON 內容(CI 用 secrets 注入)。
  - 環境變數 GOOGLE_APPLICATION_CREDENTIALS:服務帳號 JSON 檔路徑。
  - 都沒有:用 gcloud impersonate PLAY_SA(預設 play-publisher@…),
    需要你的帳號在該服務帳號上有 roles/iam.serviceAccountTokenCreator。

用法(從專案根目錄執行):
  python3 scripts/store_listing.py --dry-run   # 只看會改哪些語系
  python3 scripts/store_listing.py             # 真的推上去

需求:python3 ≥ 3.9;若走服務帳號 JSON 需 `pip install google-auth`;
     走 impersonation 只需 gcloud CLI。
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request

PACKAGE_NAME = "com.js.seek_player"
DEFAULT_SA = "play-publisher@seek-player-f724e.iam.gserviceaccount.com"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}"

ROOT = pathlib.Path(__file__).resolve().parent.parent
LISTING_DIR = ROOT / "docs" / "store-listing"

# 檔名 → Play Console 語系代碼。一個檔案可對應多個語系(es 同時餵 es-ES 與 es-419)。
# Play Console 新增語系時,這裡也要加一行,否則該語系不會被更新。
LOCALES: dict[str, list[str]] = {
    "en": ["en-US"],
    "zh-TW": ["zh-TW"],
    "zh-CN": ["zh-CN"],
    "es": ["es-ES", "es-419"],
    "fr": ["fr-FR"],
    "de": ["de-DE"],
    "ja": ["ja-JP"],
    "ko": ["ko-KR"],
    "pt": ["pt-BR"],
    "it": ["it-IT"],
    "ru": ["ru-RU"],
    "tr": ["tr-TR"],
    "hi": ["hi-IN"],
    "id": ["id"],
    "vi": ["vi"],
    "ar": ["ar"],
}

LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}
FIELDS = ("title", "shortDescription", "fullDescription")


# --- 解析 md ---------------------------------------------------------------


def parse_listing_file(path: pathlib.Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"\*\*App 名稱：\*\*\s*(.+)", text)
    blocks = re.findall(r"```\n(.*?)```", text, re.S)
    if not m or len(blocks) < 2:
        raise SystemExit(
            f"❌ {path.name} 格式不符:需要「**App 名稱：** …」與兩個 ``` 區塊(簡短說明、完整說明)"
        )
    return {
        "title": m.group(1).strip(),
        "shortDescription": blocks[0].strip(),
        "fullDescription": blocks[1].strip(),
    }


def load_listings() -> dict[str, dict[str, str]]:
    """回傳 {Play 語系代碼: {title, shortDescription, fullDescription}}。"""
    result: dict[str, dict[str, str]] = {}
    errors: list[str] = []
    for path in sorted(LISTING_DIR.glob("*.md")):
        if path.name == "README.md":
            continue
        stem = path.stem
        if stem not in LOCALES:
            errors.append(f"{path.name}:未在 LOCALES 對應表中,不知道要推到哪個語系")
            continue
        data = parse_listing_file(path)
        for field, limit in LIMITS.items():
            n = len(data[field])
            if n > limit:
                errors.append(f"{path.name}:{field} {n} 字元,超過上限 {limit}")
        for lang in LOCALES[stem]:
            result[lang] = data
    if errors:
        raise SystemExit("❌ 文案檢查未通過:\n  " + "\n  ".join(errors))
    return result


# --- 認證 ------------------------------------------------------------------


def access_token() -> str:
    sa_json = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
    sa_file = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if sa_json or sa_file:
        try:
            from google.auth.transport.requests import Request  # type: ignore
            from google.oauth2 import service_account  # type: ignore
        except ImportError:
            raise SystemExit("❌ 需要 google-auth:pip install google-auth")
        if sa_json:
            creds = service_account.Credentials.from_service_account_info(
                json.loads(sa_json), scopes=[SCOPE]
            )
        else:
            creds = service_account.Credentials.from_service_account_file(
                sa_file, scopes=[SCOPE]
            )
        creds.refresh(Request())
        return creds.token

    sa = os.environ.get("PLAY_SA", DEFAULT_SA)
    proc = subprocess.run(
        [
            "gcloud", "auth", "print-access-token",
            f"--impersonate-service-account={sa}",
            f"--scopes={SCOPE}",
        ],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise SystemExit(
            f"❌ 無法 impersonate {sa}(需要 roles/iam.serviceAccountTokenCreator):\n"
            + proc.stderr.strip().splitlines()[-1]
        )
    return proc.stdout.strip()


# --- Play API --------------------------------------------------------------


class PlayApi:
    def __init__(self, token: str):
        self._token = token

    def call(self, method: str, path: str, body: dict | None = None) -> dict:
        req = urllib.request.Request(
            API + path,
            method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={
                "Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            try:
                detail = json.loads(detail)["error"]["message"]
            except Exception:
                pass
            raise SystemExit(f"❌ {method} {path} → HTTP {e.code}: {detail}")
        return json.loads(raw) if raw else {}


# --- 主流程 ----------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--dry-run", action="store_true", help="只比對差異,不寫入、不 commit")
    args = ap.parse_args()

    local = load_listings()
    print(f"📄 已解析 {len(local)} 個語系的文案")

    api = PlayApi(access_token())
    edit_id = api.call("POST", "/edits")["id"]
    print(f"🆔 edit={edit_id}")

    remote = {
        item["language"]: item
        for item in api.call("GET", f"/edits/{edit_id}/listings").get("listings", [])
    }
    unknown = sorted(set(remote) - set(local))
    if unknown:
        print(f"ℹ️  Play 上有但本地沒有對應檔案的語系(不動):{', '.join(unknown)}")

    changed: list[str] = []
    for lang in sorted(local):
        cur = remote.get(lang, {})
        diff = [f for f in FIELDS if cur.get(f, "") != local[lang][f]]
        if not diff:
            continue
        changed.append(lang)
        status = "新增" if lang not in remote else "更新 " + ", ".join(diff)
        print(f"  • {lang:7} {status}")

    if not changed:
        print("✅ Play Console 與本地文案一致,無需更新")
        api.call("DELETE", f"/edits/{edit_id}")
        return 0

    if args.dry_run:
        print(f"🔍 dry-run:{len(changed)} 個語系有差異,未寫入")
        api.call("DELETE", f"/edits/{edit_id}")
        return 0

    for lang in changed:
        api.call("PUT", f"/edits/{edit_id}/listings/{lang}", {"language": lang, **local[lang]})
    api.call("POST", f"/edits/{edit_id}:validate")
    api.call("POST", f"/edits/{edit_id}:commit")
    print(f"✅ 已 commit,更新 {len(changed)} 個語系:{', '.join(changed)}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("## 🏪 Store listing 已更新\n\n")
            f.write("| 語系 |\n| --- |\n")
            f.writelines(f"| `{lang}` |\n" for lang in changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
user_stats.py
統計 Firebase 帳號(Authentication)與各使用者 App 版本(Firestore `user/{uid}`)。

資料來源:
  - Firebase Auth(Identity Toolkit accounts:batchGet):所有帳號、登入方式、
    建立時間、最後登入時間。
  - Firestore `user/{uid}` 主文件:appVersion / buildNumber / recordedAt,
    由 SyncService 在「有上傳」時寫入(開 App 但沒資料變更時不會更新,
    所以版本可能落後實際安裝版本;v1.2.13 之前的版本不會寫)。

唯讀,不會修改任何資料。

用法(從專案根目錄執行):
  python3 scripts/user_stats.py               # 帳號與版本統計
  python3 scripts/user_stats.py --days 7      # 「近期」視窗改為 7 天(預設 30)
  python3 scripts/user_stats.py --list        # 另外列出每個帳號的明細
  python3 scripts/user_stats.py --csv out.csv # 明細輸出成 CSV

認證:用 `gcloud auth print-access-token`(目前 gcloud 登入的帳號),
     帳號需有該 Firebase 專案的讀取權限(Owner / Editor / Firebase Viewer)。
需求:python3 ≥ 3.9、gcloud CLI。
"""

from __future__ import annotations

import argparse
import collections
import csv
import datetime as dt
import json
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

PROJECT_ID = "seek-player-f724e"
FIRESTORE_BASE = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}"
    "/databases/(default)/documents"
)
AUTH_BASE = f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT_ID}"

NO_DOC = "(無主文件)"
NO_VERSION = "(未記錄版本)"


def access_token() -> str:
    try:
        out = subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        sys.exit("找不到 gcloud CLI,請先安裝並 `gcloud auth login`。")
    except subprocess.CalledProcessError as e:
        sys.exit(f"取得 gcloud access token 失敗:\n{e.stderr}")
    return out.stdout.strip()


def get_json(url: str, token: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": PROJECT_ID,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {url}\n{e.read().decode(errors='replace')}")


def fetch_auth_users(token: str) -> list[dict]:
    users: list[dict] = []
    page = None
    while True:
        params = {"maxResults": "1000"}
        if page:
            params["nextPageToken"] = page
        data = get_json(
            f"{AUTH_BASE}/accounts:batchGet?{urllib.parse.urlencode(params)}",
            token,
        )
        users.extend(data.get("users", []))
        page = data.get("nextPageToken")
        if not page or not data.get("users"):
            return users


def fetch_user_docs(token: str) -> dict[str, dict]:
    """uid → {appVersion, buildNumber, recordedAt}(只抓這三個欄位)。"""
    docs: dict[str, dict] = {}
    page = None
    while True:
        params = [("pageSize", "300")] + [
            ("mask.fieldPaths", f)
            for f in ("appVersion", "buildNumber", "recordedAt")
        ]
        if page:
            params.append(("pageToken", page))
        data = get_json(
            f"{FIRESTORE_BASE}/user?{urllib.parse.urlencode(params)}", token
        )
        for d in data.get("documents", []):
            f = d.get("fields", {})
            docs[d["name"].rsplit("/", 1)[-1]] = {
                "appVersion": f.get("appVersion", {}).get("stringValue"),
                "buildNumber": f.get("buildNumber", {}).get("stringValue"),
                "recordedAt": parse_rfc3339(
                    f.get("recordedAt", {}).get("timestampValue")
                ),
            }
        page = data.get("nextPageToken")
        if not page:
            return docs


def parse_rfc3339(s: str | None) -> dt.datetime | None:
    if not s:
        return None
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def parse_ms(s: str | None) -> dt.datetime | None:
    if not s:
        return None
    return dt.datetime.fromtimestamp(int(s) / 1000, tz=dt.timezone.utc)


def fmt_time(t: dt.datetime | None) -> str:
    return t.astimezone().strftime("%Y-%m-%d %H:%M") if t else "-"


def version_label(doc: dict | None) -> str:
    if doc is None:
        return NO_DOC
    if not doc["appVersion"]:
        return NO_VERSION
    return f"v{doc['appVersion']}+{doc['buildNumber'] or '?'}"


def version_sort_key(label: str):
    """新版本排前面;無法解析的(無主文件 / 未記錄 / dev)排最後。"""
    if not label.startswith("v"):
        return (1, ())
    core, _, build = label[1:].partition("+")
    nums = []
    for p in core.split("-")[0].split("."):
        nums.append(int(p) if p.isdigit() else -1)
    return (0, tuple(-n for n in nums) + (-(int(build) if build.isdigit() else -1),))


def provider_label(u: dict) -> str:
    ids = sorted(p.get("providerId", "?") for p in u.get("providerUserInfo", []))
    return ",".join(ids) if ids else "anonymous"


def identity(u: dict) -> str:
    return u.get("email") or u.get("phoneNumber") or "-"


def pad(s: str, width: int) -> str:
    """依終端機顯示寬度(全形字算 2)補空白,讓中英混排的欄位對齊。"""
    w = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
    return s + " " * max(width - w, 0)


def disp_width(s: str) -> int:
    return len(pad(s, 0)) + sum(
        1 for c in s if unicodedata.east_asian_width(c) in "WF"
    )


def print_table(title: str, rows: list[tuple[str, int]], total: int) -> None:
    print(f"\n## {title}")
    if not rows:
        print("  (無)")
        return
    width = max(disp_width(k) for k, _ in rows)
    for k, n in rows:
        pct = n / total * 100 if total else 0
        print(f"  {pad(k, width)}  {n:>5}  {pct:5.1f}%")


def main() -> None:
    ap = argparse.ArgumentParser(description="統計 Firebase 帳號與 App 版本(唯讀)")
    ap.add_argument("--days", type=int, default=30, help="「近期」視窗天數(預設 30)")
    ap.add_argument("--list", action="store_true", help="列出每個帳號的明細")
    ap.add_argument("--csv", metavar="PATH", help="把明細輸出成 CSV")
    args = ap.parse_args()

    token = access_token()
    auth_users = fetch_auth_users(token)
    docs = fetch_user_docs(token)

    now = dt.datetime.now(dt.timezone.utc)
    since = now - dt.timedelta(days=args.days)

    rows = []
    for u in auth_users:
        uid = u["localId"]
        doc = docs.get(uid)
        rows.append(
            {
                "uid": uid,
                "identity": identity(u),
                "name": u.get("displayName", ""),
                "provider": provider_label(u),
                "createdAt": parse_ms(u.get("createdAt")),
                "lastLoginAt": parse_ms(u.get("lastLoginAt")),
                "version": version_label(doc),
                "recordedAt": doc["recordedAt"] if doc else None,
                "disabled": u.get("disabled", False),
            }
        )
    auth_uids = {r["uid"] for r in rows}
    orphan_docs = sorted(set(docs) - auth_uids)

    total = len(rows)
    print(f"專案:{PROJECT_ID}    時間:{fmt_time(now)}    近期 = {args.days} 天內")

    # ---- 帳號 ----
    print(f"\n# 帳號(Firebase Auth):{total}")
    created = sum(1 for r in rows if r["createdAt"] and r["createdAt"] >= since)
    active = sum(1 for r in rows if r["lastLoginAt"] and r["lastLoginAt"] >= since)
    disabled = sum(1 for r in rows if r["disabled"])
    print(f"  近期新註冊:{created}")
    print(f"  近期有登入:{active}(lastLoginAt,僅登入動作才更新,非開 App 次數)")
    if disabled:
        print(f"  已停用:{disabled}")
    print_table(
        "登入方式",
        collections.Counter(r["provider"] for r in rows).most_common(),
        total,
    )

    # ---- 版本 ----
    def version_rows(subset):
        c = collections.Counter(r["version"] for r in subset)
        return sorted(c.items(), key=lambda kv: version_sort_key(kv[0]))

    print(f"\n# App 版本(Firestore user/{{uid}})")
    print_table("全部帳號", version_rows(rows), total)
    recent = [r for r in rows if r["recordedAt"] and r["recordedAt"] >= since]
    print_table(
        f"近 {args.days} 天有上傳過的帳號({len(recent)})",
        version_rows(recent),
        len(recent),
    )
    print(
        "\n  註:版本只在 SyncService 有實際上傳時寫入,沒資料變更的開 App 不會更新;"
        "\n      v1.2.13 之前的版本不會寫,所以會顯示為「未記錄版本」。"
    )
    if orphan_docs:
        print(f"\n  ⚠ Firestore 有 {len(orphan_docs)} 份主文件找不到對應 Auth 帳號(帳號已刪除?)")

    # ---- 明細 ----
    rows.sort(
        key=lambda r: r["recordedAt"] or dt.datetime.min.replace(tzinfo=dt.timezone.utc),
        reverse=True,
    )
    if args.list:
        print("\n# 明細(依 recordedAt 新→舊)")
        cols = [("uid", 28), ("帳號", 32), ("登入方式", 16), ("版本", 14),
                ("版本記錄時間", 16), ("最後登入", 16), ("建立", 16)]
        print("  " + "  ".join(pad(h, w) for h, w in cols))
        for r in rows:
            vals = [r["uid"], r["identity"][:32], r["provider"][:16], r["version"],
                    fmt_time(r["recordedAt"]), fmt_time(r["lastLoginAt"]),
                    fmt_time(r["createdAt"])]
            print("  " + "  ".join(pad(v, w) for v, (_, w) in zip(vals, cols)))

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(
                ["uid", "identity", "displayName", "provider", "version",
                 "recordedAt", "lastLoginAt", "createdAt", "disabled"]
            )
            for r in rows:
                w.writerow(
                    [r["uid"], r["identity"], r["name"], r["provider"], r["version"],
                     fmt_time(r["recordedAt"]), fmt_time(r["lastLoginAt"]),
                     fmt_time(r["createdAt"]), r["disabled"]]
                )
        print(f"\n已輸出 CSV:{args.csv}({len(rows)} 筆)")


if __name__ == "__main__":
    main()

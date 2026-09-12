# Store Listing — 多語言商店文案

Google Play 商店文案的各語系版本。每個語言一個檔案,內含該語系的**簡短說明**(≤80 字元)與**完整說明**(≤4000 字元),可直接貼到 Play Console 對應語系的 listing。

- 主打賣點:歌詞 AI 產生、匯入、對齊與同步顯示;無廣告、離線背景播放。
- 完整說明不支援 Markdown,僅支援少量 HTML;這裡以「emoji + 一句話」條列排版,以 zh-TW 為母版,其他語言逐條對齊,複製程式碼區塊內容即可貼上。
- App 名稱以 zh-TW 的「歌詞播放器-Lyrics Player」為準;非拉丁字母語系加「-Lyrics Player」後綴,拉丁字母語系因 30 字上限只保留在地名稱。
- 撰寫/翻譯策略與資料安全注意事項見 `plans/play-store-listing.md`。

> ⚠️ 上架前務必同步更新 Play Console **資料安全(Data safety)** 表單:歌詞自動對齊會上傳該首歌的壓縮音訊並需登入帳戶,不可宣稱「完全離線、不上傳」。

## 語系一覽

| 檔案 | 語系 | App 名稱 |
|------|------|---------|
| [en.md](en.md) | English | Lyrics Player |
| [zh-TW.md](zh-TW.md) | 繁體中文 | 歌詞播放器-Lyrics Player |
| [zh-CN.md](zh-CN.md) | 简体中文 | 歌词播放器-Lyrics Player |
| [es.md](es.md) | Español | Reproductor de letras |
| [fr.md](fr.md) | Français | Lecteur de paroles |
| [de.md](de.md) | Deutsch | Liedtext-Player |
| [ja.md](ja.md) | 日本語 | 歌詞プレーヤー-Lyrics Player |
| [ko.md](ko.md) | 한국어 | 가사 플레이어-Lyrics Player |
| [pt.md](pt.md) | Português | Reprodutor de letras |
| [it.md](it.md) | Italiano | Lettore di testi |
| [ru.md](ru.md) | Русский | Плеер с текстами-Lyrics Player |
| [tr.md](tr.md) | Türkçe | Şarkı Sözü Oynatıcı |
| [hi.md](hi.md) | हिन्दी | लिरिक्स प्लेयर-Lyrics Player |
| [id.md](id.md) | Indonesia | Pemutar Lirik-Lyrics Player |
| [vi.md](vi.md) | Tiếng Việt | Trình phát lời bài hát |
| [ar.md](ar.md) | العربية (RTL) | مشغّل الكلمات-Lyrics Player |

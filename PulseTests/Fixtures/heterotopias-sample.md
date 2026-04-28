# Heterotopias Project Memo (sample excerpt)

## Planned Work (Priority Order)

### Recently Done (2026-04-17)
- ✅ **Heterotopia 概念 + aliases** — 新 dim concept（空間）+ 6 條 alias（異質烏托邦 / 異托邦 / 異託邦 / 另類烏托邦 / heterotopia / HETEROTOPIA → Heterotopia）；修 5 處舊 broken-wrap `異質[[烏托邦]]` → `[[異質烏托邦]]`；烏托邦保留獨立 concept
- ✅ **Theme-dot hardening** — `type=button` + `preventDefault/stopPropagation`，避免 nav 誤觸跳首頁
- ✅ **Archive theme typography** — Noto Serif TC weight 500 + `subpixel-antialiased`（higher specificity 蓋過 body antialiased）
- ✅ **External image 稽核 + 搬遷** — 掃全站 83 外部 URL；12 支活的下載 + 上 R2（`{id}_{hash}.{ext}`）；16 檔 URL 替換；62 支已死的 per CLAUDE.md 規則保留（詳 `audit/external_images_report.md`）
- ✅ **MASK remnant review** — 98 檔回頭掃，找到 3 處舊 `�MASKn�` 殘餘（15513 / Vernacular_Landscape）修完；`wikilink_scanner.py._unmask` 加 defensive RuntimeError

### URGENT（schema coherence — 2026-04-22 audit follow-up）

0. **P0-1 Curation + Books bilingual schema drift**（~3 hrs；Design 待討論，不可直接動手）
   前台 `/curation/[slug]`、`CurationTabs`、`/academic/book/[slug]` 讀 `ex.venue` / `book.description` 永遠 `undefined`，因為實際欄位在 2026-04-20 bilingual migration 後已改成 `_zh/_en`。

### HIGH
1. **Homepage hero 再推進** — 04-14 的 cold-start / hero moment 已上，但外部審查員仍覺得首頁「直接落在五維卡片，結構邏輯大於氛圍」。
2. **Live preview cursor-line reveal** — Show raw markdown on active line in editor

### MEDIUM
3. **Article page craft** — Museum-grade reading experience（最大設計案）。
4. **Tag 頁資訊密度不對稱** — 稀疏 tag（如 Techno 只 1 篇）目前用完整 archive 結構太重。

#!/usr/bin/env python3
"""One-time sync of existing `<!-- pulse-hook:start -->...<!-- pulse-hook:end -->`
blocks across 黃孫權 personal projects.

Why this exists: the Swift `CLAUDEMdHookWriter.ensureHook(...)` is idempotent —
once markers are present it leaves the block alone (so user edits are
preserved). When we extend `hookBlock()` content (e.g., adding the done/delete
trigger phrases on 2026-04-28), already-onboarded projects don't get the
update via app refresh. This script does that one-shot rewrite.

Run: `python3 Scripts/update_existing_hooks.py`

Note: the NEW_BLOCK string below MUST match Swift's
`CLAUDEMdHookWriter.hookBlock()` byte-for-byte (between markers). When you
extend the Swift hook, copy the new content here and re-run.
"""

import re
from pathlib import Path

HOOK_RE = re.compile(
    r"<!-- pulse-hook:start -->.*?<!-- pulse-hook:end -->",
    re.DOTALL,
)

# Must match Swift CLAUDEMdHookWriter.hookBlock() output exactly.
NEW_BLOCK = """<!-- pulse-hook:start -->
📋 **此專案的工作清單在 [`pulse.md`](./pulse.md)。**

**Session 開始**：先讀 pulse.md 看 outstanding todos。

**自動加 todo 規則**：user 講以下類型語句時，append 到 pulse.md `## To Do` 段：

觸發語句：
- 「加 todo」/「加待辦」/「加進清單」/「加上 X」
- 「優先處理 X」/「要先做 X」/「P0」/「緊急」
- 「下次要做 X」/「下一輪」/「下一步」
- 「記下來」/「不要忘記」/「記得處理」
- "add todo X" / "TODO: X" / "make X a priority"

格式：在 `## To Do` 段尾 append：
- 普通：`- [ ] (YYYY-MM-DD) {內容}`
- 緊急 / P0：`- [ ] 🔴 (YYYY-MM-DD) {內容}`
- 高優先：`- [ ] 🟡 (YYYY-MM-DD) {內容}`

寫完一句確認：「已記 pulse.md：[xxx]」

**完成 / 刪除規則**：user 講以下類型語句時，更新 pulse.md `## To Do` 對應行：

完成觸發：「X 完成」/「X 做完了」/「X 結了」/「done X」/「finished X」
→ 找到對應 `- [ ]` 行，改成 `- [x] (done YYYY-MM-DD)` + 原內容

刪除觸發：「幫我刪掉 X」/「不要這條 X」/「拿掉 X」/「remove X」/「drop X」
→ 找到對應 `- [ ]` 或 `- [x]` 行，整行 remove

寫完一句確認：「已標完成：[xxx]」或「已刪除：[xxx]」

**注意**：完成 30 天後 Pulse 會自動清掉那行（commit log 已涵蓋歷史）。

**不要寫**：
- 已完成（git commit log 涵蓋）
- brainstorm 中、未拍板要做
- session-only 步驟（用 TodoWrite tool）

Pulse menubar app 自動讀 pulse.md 顯示在系統工具列。
<!-- pulse-hook:end -->"""

PROJECTS = [
    "新大眾文藝",
    "矽盾週報",
    "文化與技術三部曲",
    "中國技術道路_2008_2028",
    "new_heterotopias",
    "heterotopias-next",
    "pots-archive",
    "writing-agent",
]


def main() -> None:
    home = Path.home()
    updated, skipped, missing = 0, 0, 0
    for proj in PROJECTS:
        p = home / "Desktop" / proj / "CLAUDE.md"
        if not p.exists():
            print(f"MISSING  {proj}: no CLAUDE.md")
            missing += 1
            continue
        content = p.read_text(encoding="utf-8")
        if not HOOK_RE.search(content):
            print(f"SKIP     {proj}: no hook markers")
            skipped += 1
            continue
        new = HOOK_RE.sub(NEW_BLOCK, content, count=1)
        if new == content:
            print(f"NOOP     {proj}: already in sync")
            skipped += 1
            continue
        p.write_text(new, encoding="utf-8")
        print(f"UPDATED  {proj}")
        updated += 1
    print(f"\nDone. updated={updated} skipped={skipped} missing={missing}")


if __name__ == "__main__":
    main()

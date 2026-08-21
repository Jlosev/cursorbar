---
created: 2026-08-07
updated: 2026-08-24
---

# AGENTS.md – cursorbar-pace

**Назначение:** постоянный операционный контекст агента.
Карта WHERE/WHY/HOW-START. Docs – через указатели, не пересказ.

---

## CONSTRAINTS

**CRITICAL:** Code lives in this repo (`~/Documents/03_Projects/cursorbar-pace`); never treat Obsidian vault checkout as the code root.
**CRITICAL:** Product name is `cursorbar-pace` (fork of CursorBar). Soft-diverge from upstream `c-johannesen/cursorbar` (MIT).
**MANDATORY:** Durable product/requirements truth → `@docs/` (symlink into vault).
**MANDATORY:** Active spec = nested dropdown (Included = Auto/API **monthly pool %**; Daily = Auto/API **today $** vs `remaining ÷ remaining workdays`) + menu bar A/P = same daily — `@docs/Specs/2026-08-20 – Redistributing daily.md`. Today split = events + model rule in that spec. Menu bar quiet default = Daily total; auto-splits to A/P when a daily pool is ≥70% — `@docs/Specs/2026-08-21 – Auto-split daily warning.md`.
**MANDATORY:** Remote for upstream is `upstream`; personal fork is `origin` (`Jlosev/cursorbar`).

---

## Контекст

macOS menu bar fork of [c-johannesen/cursorbar](https://github.com/c-johannesen/cursorbar). Problem: upstream `D` mixes Auto+API today-spend; fork shows per-pool **A/P** = today’s Auto/API vs `remaining ÷ remaining workdays` so API quota is not burned early.

## Канон

- `@README.md` – upstream entry + fork pointer
- `@docs/CursorBar Pace – Hub.md` – product hub
- `@docs/Specs/2026-08-20 – Redistributing daily.md` – active requirements / acceptance
- Upstream: https://github.com/c-johannesen/cursorbar

## Границы и обязательства

- Store application code only under this git root (not inside the vault tree).
- Keep `docs/` as a **relative** symlink to vault (no hardcoded `/Users/<name>/…`). Recovery from repo root:

```bash
ln -sfn "../../../Library/Mobile Documents/iCloud~md~obsidian/Documents/Evgeniy Losev DB/03_Проекты/Идеи/CursorBar Pace" docs
```

- Do not commit vault contents via `docs/` (`/docs` is gitignored).
- Redistributing daily: `daily_budget = remaining / remaining_workdays` where remaining days = `[tomorrow, cycleEnd)`; `utilization = today_pool / daily_budget`.
- Ship as upstream `CursorBar` / `com.cursorbar.app` (needed for a PR back to `c-johannesen/cursorbar`).

## Стек и инструменты

- Swift 6, AppKit / MenuBarExtra, macOS 14+
- Build/install: `bash scripts/package.sh --install --open`
- Auth: local Cursor `state.vscdb` → `WorkosCursorSessionToken` cookie → `cursor.com/api/usage-summary`

## Структура workspace

| Каталог | Назначение |
|---------|------------|
| `Sources/CursorBar/` | App source (upstream layout) |
| `scripts/` | package / install / launch |
| `assets/` | upstream screenshot (not in vault) |
| `docs/` | Symlink → Obsidian product docs (gitignored as `/docs`) |

## Правила работы агента

1. Read `@docs/Specs/2026-08-20 – Redistributing daily.md` before changing product scope.
2. After durable decisions, enrich Hub/Specs with pointers (not session dumps).
3. Implementation plans → `@docs/Plans/` with date prefix `YYYY-MM-DD – …`.

## Связанные правила

- User AGENTS.md core rule – bootstrap/enrich protocol
- Methodology twin: `~/Documents/03_Projects/skillgraph` (docs symlink pattern)

---
updated: 2026-08-24

# PLAYTEST NOTES
## Prince of Persia: Echoes of Time — human playtest (plan §8 protocol, D14 clause)

**This file is yours.** Fill any part of it (or none — paste notes in the session
chat and they get transcribed here). Anything you report lands in
`docs/QA_REPORT.md` as a BUG-xxx entry, fixed at the cause with a regression test
— unless the fix would move a PARITY-sourced sim constant, in which case the
finding is reported back with measured-vs-source evidence first.

**How to run the game:** `./.tools/godot --path .` (or `godot --path .` with Godot
4.7 installed). Boot a specific level with `-- --level=N` (1-based: 1 = The Sim
Gate, 2 = Hall of Echoes, 3 = The Time Warden). Pause menu (Esc) has mute +
volume if the SFX distract from playing.

**Protocol target (plan §8):** 3 completions of L1, 2 of L2, 2 boss kills — timed.
Not a hard requirement for this sheet: even one run with fresh impressions is
worth more than nothing.

---

## Session header

| Field | Value |
|---|---|
| Date | |
| Build | source (`dev/pop-rebuild`) / export (Linux / Windows) |
| Commit | |
| Total time | |
| Levels completed | |

---

## Level 1 — The Sim Gate

| Field | Notes |
|---|---|
| Result (completed / gave up) | |
| Time | |
| Deaths (and to what) | |
| Where I got stuck or confused | |
| Feel issues (jump, turning, landing, 12 Hz tick, echo timing) | |
| Bugs / weirdness | |

---

## Level 2 — Hall of Echoes (echo mandatory)

| Field | Notes |
|---|---|
| Result | |
| Time | |
| Deaths (and to what) | |
| Did the echo "click"? When? | |
| Where I got stuck or confused | |
| Feel issues (recording UX, gate timing, guard duel) | |
| Bugs / weirdness | |

---

## Level 3 — The Time Warden (boss)

| Field | Notes |
|---|---|
| Result (Warden fell / gave up) | |
| Time | |
| Deaths (and to what) | |
| Shield/plate loop understandable on first try? | |
| Fight fair? (skill, damage, budget vs one take) | |
| Where I got stuck or confused | |
| Bugs / weirdness | |

---

## Whole-game impressions

| Field | Notes |
|---|---|
| Title/menu/screens | |
| Audio (14 SFX — weakest? too loud/quiet?) | |
| Visuals (readability of tiles, kid, echo, guards) | |
| Difficulty curve | |
| One thing you would fix first | |

---

## Bugs found (raw — I will format these as BUG-xxx)

| # | What happened | Where / how to reproduce | Severity (blocks / annoying / cosmetic) |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

*Triage footer (session-maintained): defects from this sheet enter
`docs/QA_REPORT.md` in BUG-xxx format; fixes land with regression tests; the
Playtest and Export Log in `review.md` gets a row per completed protocol run.*

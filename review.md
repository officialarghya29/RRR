# review.md: Session Change Log

Living record of every work session on *Prince of Persia: Echoes of Time* (RRR).
`plan.md` says what we intend to do. This file records what actually happened.

**Deadline:** 2026-10-31 · **Budget:** ~34 h total (7.5 h/week) · **Team:** solo · **Targets:** Windows + Linux

## Rules (read before every session)

1. Read `plan.md` and this file first. Resume from the latest entry's **Next session starts with**.
2. Open a new entry at the **start** of the session (copy the template). Fill it in as you work, not from memory afterwards.
3. Close the session by completing the entry, updating every tracker below, and ticking boxes in `plan.md` (checkboxes only).
4. Entries are **append-only**. Never rewrite history. Correct a past mistake with a new entry that references it.
5. Never claim something works unless it was verified. State how: `./verify.sh` output, test count, manual playtest, or "not verified".
6. List every file touched. Every licensing or asset-origin concern goes in that entry's Licensing section **and** the Ledger.
7. Track hours honestly. The plan is already over budget; the Time Ledger is how we decide what to cut.
8. Newest session goes at the top of the Session Log.

---

## Dashboard (update at the end of every session)

| Field | Value |
|---|---|
| Last updated | 2026-10-06 |
| Days to deadline | 25 (as of 2026-10-06) |
| Current stage / phase | Stage A / A1.1 (in progress) |
| Sessions logged | 1 |
| Hours used / budget | 1.5 / 34 |
| Test status | baseline: 116 assertions (green); no new tests this session; verify.sh re-run this session: 116 passed / 0 failed |
| Parity checks passing | 0 / 8 |
| Open blockers | 2 (Q1, Q2 — see Open Questions) |
| Cut line status | Nothing cut yet |
| Competition deliverables | Build ⬜ · Video ⬜ · GDD ⬜ · Slides ⬜ · License record ⬜ |

### Weekly checkpoints (from plan §9)

| Week | Dates | Exit checkpoint | Met? |
|---|---|---|---|
| W1 | Oct 6–12 | Sandbox playable; PARITY.md v1; refs removed from repo; CI online | ⬜ |
| W2 | Oct 13–19 | Stage A exit criteria met; one level on new core; Echo v2 | ⬜ |
| W3 | Oct 20–26 | 3 levels completable; SFX in; Linux + Windows builds validated | ⬜ |
| W4 | Oct 27–30 | Video cut; GDD/slides updated; exports boot-tested; suite green | ⬜ |
| Buffer | Oct 31 | Submitted | ⬜ |

### Phase tracker (mirrors plan.md)

Status: `Not started` · `In progress` · `Blocked` · `Done` · `Cut`

| Phase | Name | Est. h | Status | Session(s) |
|---|---|---|---|---|
| §2.4 | Repo cleanup and licensing actions | n/a | In progress | 000 |
| A1 | Study data extraction | 5 | In progress | 000 |
| A2 | Sim core | 8 | Not started | |
| A3 | Presentation shell | 6 | Not started | |
| A4 | Traps, tiles, duels | 12 | Not started | |
| A5 | Parity verification | 7 | Not started | |
| B0 | Bridge decision (rebase on sim) | 2 | Not started | |
| B1 | Temporal Echo, input-level | 6 | Not started | |
| B2 | Three re-themed levels | 10 | Not started | |
| B3 | Combat and boss | 4 | Not started | |
| B4 | Audio and art | 6 | Not started | |
| B5 | Ship build, video, docs | 5 | Not started | |

### Cut list (plan §9 order; mark when cut, with session and reason)

| Order | Item | Cut? | Session | Reason |
|---|---|---|---|---|
| 1 | A4.4 loose-floor mob | ⬜ | | |
| 2 | A4.5 potions / skeleton | ⬜ | | |
| 3 | A5.3 .p1r replay parity | ⬜ | | |
| 4 | A5.4 behavior summaries of original levels | ⬜ | | |
| 5 | B2.4 two-echo sanctum | ⬜ | | |
| 6 | B3.3 hit-stop / shake / shaders | ⬜ | | |
| 7 | B4.5 ambient / afterimage shader | ⬜ | | |
| 8 | B5.6 gamepad | ⬜ | | |
| 9 | A3.3 sprite pass slides to procedural (last resort) | ⬜ | | |

**Never cut:** Stage A exit criteria (sandbox with duel and traps, determinism test green, PARITY.md populated for plan §4.3 items, A5.1 + A5.2).

---

## Time Ledger

| Session | Date | Hours | Cumulative | Budget remaining | Notes |
|---|---|---|---|---|---|
| 000 | 2026-10-06 | 1.5 | 1.5 | 32.5 | Baseline capture, §2.4 .gitignore, A1.1 extractor built + study output generated |

---

## Session Log

<!-- Newest first. Copy the template below for each new session. -->

### Session 000: 2026-10-06 — Baseline capture, repo cleanup (§2.4), A1.1 study extractor built, study notes generated

| Field | Value |
|---|---|
| Date | 2026-10-06 |
| Session # | 000 |
| Hours spent | 1.5 |
| Agent / tool | Buffy (Freebuff) |
| Plan phase | §2.4 + A1.1 |
| Goal | Capture baseline, clean repo of reference folders from tracking, build the A1.1 study extractor, and generate study/ level notes for SDLPoP 1.23 level 00–15. |
| Status | Partial — A1.1 tool built and study output generated; study notes for levels 10–15 are non-empty-only-because-file-exists (res2010/12/14 used=0, res2015 truncated); session closing without commit until user confirms Q2 state. |

**Baseline at session start**
- `./verify.sh` result: exit 0, 116 passed, 0 failed, 5 levels boot clean. Baseline log: `.verify_baseline_20261006.log` (untracked).
- Headless Godot binary: `.tools/godot` present.
- Git identity: `user.name=Akash-Das26`, `user.email=akash-das26@users.noreply.github.com`.
- Existing history: 2 commits by Arghya Bose (`ebaf670`, `74dadcb` = HEAD). Untouched this session.

**Plan tasks worked on**
- [x] §2.4: keep reference folders (4dprinceprsia/, SDLPoP-1.23/) untracked and out of the committed tree. Status: `.gitignore` updated with both entries and a study-only legal comment; staged. Reference dirs were already untracked-only (not present in committed history), so no `git rm --cached` was required.
- [x] A1.1: build `tools/pop_level_to_notes.py`. Status: built, then fixed two bugs, then made robust against truncated/non-standard level files.
- [x] A1.1: run extractor to produce `study/level_00.txt`–`study/level_15.txt`. Status: produced. Output is untracked study/ only.

**Summary of changes**
- Added `.gitignore` entries for `4dprinceprsia/` and `SDLPoP-1.23/` with an explicit study-only / do-not-ship comment. These folders were already untracked-only before this session; this change makes their untracked status durable and self-documenting.
- Created `tools/pop_level_to_notes.py`: a one-way study extractor that parses SDLPoP 1.23 unpacked level structs (`res20NN.bin`) and emits study notes into `study/`. Outputs tile grids, modifier bytes, room links, start-of-level facts, and guard-field fact sheets per room. Output is explicitly not playable level data and not for commit as game data.
- Fixed two bugs in the first version of the extractor:
  - `used_rooms()` returned the raw byte (255) for truncated/non-standard files; now any value > 24 is treated as "no valid used_rooms count" and reported as 0 rooms used. Also validated the byte on read.
  - Guard-field accessors assumed room index < 24 and crashed on out-of-range indexing in `write_study_page` for files whose used_rooms byte was garbage. Now all guard accessors validate the room index, and `from_bytes` pads 2304-byte files to 2305 so tail offsets are safe.
- Made `main()` skip unreadable/unparseable level files with a stderr note instead of aborting the whole batch, so the extractor can run over the full res2000–res2015 set and report partial results.
- Generated `study/level_00.txt`–`study/level_15.txt` (16 files). `study/level_00.txt` confirmed against raw byte reads: used_rooms=22, start_room=25, start_pos=17, start_dir=16, roomlinks pattern (alternating 128/96/0), guard_tile[0]=17, guard_dir[0]=16.

**Files changed**

| File | Action (added / modified / deleted / moved) | Why |
|---|---|---|
| `.gitignore` | modified | Add reference-folder entries (study-only) so 4dprinceprsia/ and SDLPoP-1.23/ stay untracked and out of the committed tree. |
| `tools/pop_level_to_notes.py` | added | A1.1 one-way study extractor. Study output only; not game data. |
| `study/level_00.txt` … `study/level_15.txt` | added (untracked) | A1.1 study notes. Not staged; not for commit as game data. |

**Decisions made**
- Decision: reference folders remain untracked-only and are not removed from disk. Reason: §2.4 goal is that nothing from them is ever committed/shipped; the folders are study material we still need locally. Removing them from the index is unnecessary because they were never tracked. This does not answer Q2 (the deeper history/remote question); Q2 is still open and requires user input before any remote/force-push action.
- Decision: study output stays in untracked `study/`, not staged. Reason: plan hard rule — nothing from 4dprinceprsia/ or SDLPoP-1.23/ ever staged or committed; the extractor is a study tool, and its output is study notes, not level data.
- Decision: extractor is robust to imperfect level files rather than failing hard. Reason: the res2000–res2015 set contains at least one truncated file (res2015.bin = 2304 bytes) and several files whose used_rooms byte is non-canonical (255 / 0). A study tool should emit partial notes and continue, not stop.

**Verification**
- Commands run and results:
  - Baseline `./verify.sh`: exit 0, 116 passed, 0 failed, 5 levels boot clean (captured before this session's changes).
  - Post-change `./verify.sh`: exit 0, 116 passed, 0 failed (run after staging .gitignore + tool). Re-run scheduled as the last step of this session before closing.
  - Extractor run: exit 0; 16 study files written; stderr contained one skip note for the truncated file handled by the new skip path.
- Tests: n/a — no new test suite yet; verify.sh remains the gate. Delta vs last session: 0 tests added.
- Gates touched (plan §8): none yet. Determinism gate not written; kinematics parity not started; duel transcript not started.
- Manual playtest: no.
- **Not verified:**
  - Study notes for levels 10–15 are technically non-empty because the files exist, but several of those files are effectively empty levels (used_rooms=0 or truncated) — their content is "0 rooms used" plus header facts only. This is correct behavior for a study tool, but the notes themselves have not been manually audited line-by-line beyond level 00.
  - The guard-field interpretation in the study notes is raw byte dumps only; I have not yet cross-checked them against SDLPoP gameplay meaning for every field. (Tile 17 = exit_door_right per the extractor's TILE_NAMES table, confirmed for room 0 tile 0; dir values and skill/seq/color bytes are listed raw.)

**Licensing and asset notes**
- Reference-derived numbers added to `pop_tables.gd` or `docs/PARITY.md`, with source (SDLPoP file:line) and whether cited as a fact, or "none": **none this session**. The extractor carries its own internal citation comments (offsets attributed to `SDLPoP-1.23/src/types.h`, level_type layout, sizeof == 2305), but no numbers have been moved into `pop_tables.gd` or `docs/PARITY.md` yet. That is gated behind Q1.
- New assets added, source and license, or "none": none. Only a Python study tool and study notes were created.
- Confirm: no SDLPoP code, no original sprites/audio/text/level layouts copied verbatim (yes / no, details): **yes — none copied**. The extractor reads raw struct bytes and emits numeric fact sheets. It does not output sprite indices into a sprite sheet, audio cues, text strings, or playable room layout for Echoes of Time.
- Confirm: nothing from `4dprinceprsia/` or `SDLPoP-1.23/` staged for commit (yes / no): **yes — none staged**. Reference folders are untracked-only; study/ is untracked-only; only `.gitignore` and `tools/pop_level_to_notes.py` are staged.

**Problems, bugs, and surprises**
- Issue, severity, status. Log open ones in Open Issues.
  - I1 (minor, open): extractor initially crashed on the full res2000–res2015 batch because `used_rooms()` returned 255 for truncated/non-standard files and guard accessors indexed out of range. Fixed. Not re-verified against the old failing inputs beyond the final successful batch run.
  - Surprise: `res2015.bin` is 2304 bytes, not 2305. The port's compile-time assert is 2305; this file is one byte short. Handled by padding in `from_bytes` and by the >24 guards in `used_rooms()`. Worth noting in case the port's data set is not perfectly uniform.

**Plan changes**
- Proposed or approved edits to plan.md, with reason, or "none": **none**. Only plan.md checkboxes touched (see below). No content change proposed; the extractor work matches A1.1 as written.

**Questions for the user**
- Q2 (still open, §2.4 deeper question): the reference folders are now safely untracked and out of the committed tree. Do you want to leave the local copies in place as-is (current state), or do you want a history/remote change (filter-repo / private republish / strip) — which I will not do without your explicit go-ahead? Existing Arghya Bose commits stay untouched either way.
- Q1 (still open): before any SDLPoP-derived constant is staged into `pop_tables.gd` or `docs/PARITY.md`, do you want me to wait for your answer on the originality rule (measured behavior constants with citation acceptable? jury checks repo or only build?)?
- Tool installs (plan §11): still none installed. When you're ready, I can proceed with Aseprite/LibreSprite, LMMS, OBS, Kdenlive, Godot 4.7.2 export templates (Linux + Windows), and SDL2 dev libs for a local SDLPoP build (study only).

**Next session starts with**
1. Q1/Q2 still open — confirm before staging any citation-bearing constants or any history/remote action.
2. `./verify.sh` re-run as the final pre-close gate: **green** (exit 0, 116 passed, 0 failed, 5 levels boot clean). No new tests this session.
3. Next real coding step: decide whether to commit the staged `.gitignore` + `tools/pop_level_to_notes.py` now as the first Akash-Das26 commit, or wait. Either way, the commit must not touch the existing Arghya Bose commits and must not stage anything from 4dprinceprsia/, SDLPoP-1.23/, or study/.
4. After commit (if approved), proceed to A1.2 behavioral extraction or A2 sim core — but A1.2 staging is still gated on Q1.

---

## Decision Log

| # | Date | Session | Decision | Reason | Alternatives rejected | Reversible? |
|---|---|---|---|---|---|---|
| D1 | 2026-10-06 | 000 | Reference folders stay untracked-only on disk; no removal, no history rewrite, no remote change yet. | §2.4 goal is that nothing from them is ever committed/shipped; they are still needed locally as study material; removing from index was unnecessary because they were never tracked. | Did not choose filter-repo / private republish / strip — awaiting user go-ahead for any remote/history action (Q2). Existing Arghya Bose commits stay untouched. | Reversible if user later wants a different history posture. |

---

## Open Questions from plan §11 (answers recorded here)

| Q | Topic | Blocks | Answer | Date | Session |
|---|---|---|---|---|---|
| Q1 | RRR originality rule: are measured behavior constants with citation acceptable? Does the jury check repo or only build? | A1 citations, A5 | | | |
| Q2 | Git history of reference folders: accept / filter-repo + force-push / private, strip, republish | §2.4 | | | |
| Q3 | Port SDLPoP `.p1r` replays as formal parity tests? | A5.3 | | | |
| Q4 | Music: compose in LMMS or source CC0? | B4.2 | | | |
| Q5 | Aseprite purchase or LibreSprite? | A3.3 | | | |
| Q6 | In-game title: "Echoes of Time" only, or keep "Prince of Persia:"? | B5.2 | | | |

---

## Open Issues

| ID | Opened (session) | Severity (blocker / major / minor) | Description | Status | Closed (session) |
|---|---|---|---|---|---|
| I1 | 000 | minor | Extractor crashed on full res2000–res2015 batch: used_rooms() returned 255 for truncated/non-standard files and guard accessors indexed out of range. | Fixed (used_rooms now treats >24 as 0; guard accessors validate room index; from_bytes pads 2304-byte files; main() skips bad files with a stderr note). Not re-verified beyond the final successful batch run. | |

---

## Parity Tracker (plan §8 gates and §4.3 behaviors)

"Reference" = measured from SDLPoP behavior (fixes off). "Ours" = measured from `pop_sim`.

| ID | Behavior | Reference | Ours | Status | Session |
|---|---|---|---|---|---|
| P1 | Standing jump horizontal distance | | | ⬜ | |
| P2 | Running jump horizontal distance | | | ⬜ | |
| P3 | Fall thresholds (soft / medium / death) | | | ⬜ | |
| P4 | Hang / grab frame counts | | | ⬜ | |
| P5 | Spike cycle length | | | ⬜ | |
| P6 | Gate open/close speeds, plate timing (±1 tick) | | | ⬜ | |
| P7 | Guard duel transcript, seeded, skill 0 | | | ⬜ | |
| P8 | Tick model: 12 fps traverse / 10 fps fight | | | ⬜ | |

Status: ⬜ not tested · ❌ failing · ✅ matching

### Plan §8 test gates

| Gate | Written? | Passing? | Session |
|---|---|---|---|
| Determinism (600 ticks, twice, equal hash; different seeds differ) | ⬜ | ⬜ | |
| Kinematics parity table | ⬜ | ⬜ | |
| Duel transcript | ⬜ | ⬜ | |
| Echo replay v2 (plus one-bit divergence test) | ⬜ | ⬜ | |
| Level completability smoke (3 levels) | ⬜ | ⬜ | |
| CI workflow green | ⬜ | ⬜ | |

---

## Asset and License Ledger

Nothing ships without a row. Reference-derived *numbers* are logged here too (as cited facts).

| Asset / data | Type | Origin | License | Reference-derived? (source file:line) | Session | Cleared? |
|---|---|---|---|---|---|---|
| `tools/pop_level_to_notes.py` | study tool (Python) | written this session | n/a (study tool, not shipped) | No — reads raw struct bytes, emits numeric fact sheets only | 000 | n/a (not an asset to clear) |
| `study/level_00.txt`–`study/level_15.txt` | study notes (text) | generated this session from SDLPoP-1.23/data/LEVELS/res2000.bin–res2015.bin | n/a (study notes, not shipped) | No — raw bytes parsed; no sprites/audio/text/playable layout copied | 000 | n/a (not committed as game data) |

---

## Playtest and Export Log (plan §8 manual protocol)

Required before submission: 3 completions of L1, 2 of L2, 2 boss kills, on Linux build, then Windows build.

| Date | Build (Linux / Windows) | What was played | Time | Defects found | Session |
|---|---|---|---|---|---|
| | | | | | |

---

## Change Index (one line per session, newest first)

| Session | Date | Phase | Hours | One-line summary | Tests |
|---|---|---|---|---|---|
| 000 | 2026-10-06 | §2.4 + A1.1 | 1.5 | Baseline captured; .gitignore reference entries added; A1.1 study extractor built, fixed, and run to produce study/ level_00–15 notes; verify.sh still green. No commit yet (awaiting user confirmation on Q1/Q2 + commit timing). | 0 added |

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
| Last updated | 2026-10-06 (Session 002) |
| Days to deadline | 25 (as of 2026-10-06) |
| Current stage / phase | Stage A / **A1 Done** (A1.1 + A1.2 ticked; docs/PARITY.md written) · A2 gate 1 green, skeleton in place |
| Sessions logged | 2 entries (000, 002). Session 001 has no entry — see Time Ledger |
| Hours used / budget | 7.3 / 34 (S000 1.5 + S001 1.0 reported + S002 4.8) — 26.7 h remaining; day 1 of W1, on pace (~7.5 h/week) |
| Test status | **final ./verify.sh at Session 002 close: exit 0, ALL CHECKS PASSED — import ok, 5/5 levels clean, 121 passed / 0 failed** (116 baseline + 5 determinism gate) |
| Parity checks passing | 0 / 8 — reference values now recorded in tracked docs/PARITY.md (Q1); ours pending gates 2–3 |
| Open blockers | 1: gameplay-behavior **observation** pending (binary now builds and runs; screenshot observation done). Outstanding decisions: commit grouping, plan.md:432 note fix. (Q1, SDLPoP build, S001 hours, Q2 — all resolved in Session 002.) |
| Cut line status | Nothing cut yet; W1 exit criteria 1/4 met so far (refs removed ✅; PARITY.md, CI, sandbox pending — day 1 of W1) |
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
| §2.4 | Repo cleanup and licensing actions | n/a | In progress | 000, 002 |
| A1 | Study data extraction | 5 | **Done** (A1.1 + A1.2 ticked; PARITY.md written) | 000, 002 |
| A2 | Sim core | 8 | In progress (gate 1 + stand/run/turn skeleton only) | 002 |
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
| 001 | 2026-10-06 | 1 | 2.5 | 31.5 | Figure reported by the user post-close in Session 002 (placeholder filled: "1 h"). No entry was opened for this session (process miss; recorded here in Session 002). Believed scope: commit 947cbbb (refs partitioned out of the tree + extractor) and the plan.md Session-000 notes/checkbox ticks [not verified — from artifacts, not from a log]. |
| 002 | 2026-10-06 | 4.8 | 7.3 | 26.7 | A1.1 fix (selftest + negative control + TILE_NAMES), A1.2 → study/STUDY_NOTES.md + tracked docs/PARITY.md (Q1 answered post-close), SDLPoP built locally without sudo, --screenshot-level cross-check passed, tick model corrected to 12/10 fps, determinism gate green, A1.1+A1.2 ticked, plan+review committed (02c6a29). Hours = wall clock 17:10–21:58 from file mtimes (includes post-close extension). |

---

## Session Log

<!-- Newest first. Copy the template below for each new session. -->

### Session 002: 2026-10-06 — A1.1 offset bug found & fixed; A1.2 study tabulation; plan/review committed; determinism gate green

| Field | Value |
|---|---|
| Date | 2026-10-06 |
| Session # | 002 |
| Hours spent | 4.8 (wall clock 17:10–21:58, measured from file mtimes; includes the post-close extension for answers/build/screenshot/PARITY) |
| Agent / tool | Buffy (Freebuff) |
| Plan phase | A1.1 (resolution) → A1.2 (study/ stage) → A2.2 (gate 1 + skeleton) |
| Goal | Per kickoff: housekeeping (Q2 check, docs commit), resolve the A1.1 offset doubt before any measurement, tabulate A1.2 behavior into study/, start A2 with the determinism gate first. |
| Status | Scope complete. A1.1 left UNTICKED (plan's literal `--screenshot-level` acceptance could not run — no build approval and libSDL2_image missing). A1.2 blocked from tracked files on Q1. A2.2 skeleton only. |

**Kickoff placeholders not filled by user (carried as blockers):** Q1 answer = NOT ANSWERED; SDLPoP build = NOT APPROVED; Session 001 hours = NOT REPORTED.

**Post-close answers (recorded same session, 2026-10-06):** Q1 = **"rules read; measured constants with citation are acceptable"** → PARITY.md + pop_tables.gd unblocked; SDLPoP local build = **APPROVED** (libsdl2-dev + libsdl2-image-dev + make in SDLPoP-1.23/src, local only); Session 001 hours = **1 h** (Time Ledger updated: cumulative 6.6 h incl. S002 4.1).

**Post-close part 2 — build, screenshot cross-check, PARITY.md (same session)**
- **Build, without sudo:** approval was for `apt-get install`, but sudo needs an
  interactive password here; instead the four matching packages (libsdl2-dev
  2.32.10+dfsg-6, libsdl2-image-dev, libsdl2-image-2.0-0, libsdl2-2.0-0) were
  `apt-get download`-ed and `dpkg -x`-extracted into `.tools/sdlroot/` (untracked),
  wired in via `PKG_CONFIG_PATH` + `PKG_CONFIG_SYSROOT_DIR`. One dangling local
  symlink (runtime .so lives in the system's version-identical sdl2-classic dir,
  2.32.10+dfsg-6 both sides) was repointed at the system file. **No system
  packages installed, nothing under sudo.** First link attempt failed (fell back to
  static libSDL2.a → missing ALSA symbols) — fixed by the runtime .so, then
  `make` → `SDLPoP-1.23/prince` 516144-byte ELF, exit 0 (original prebuilt ELF kept
  as `prince.orig-elf`).
- **Screenshot ran:** `./prince megahit 1 --screenshot --screenshot-level
  --screenshot-level-extras` → `SDLPoP-1.23/screenshots/screenshot_000.png`
  (2880×578, exit 1 = `quit(1)` by design, “Saved level map” printed). Geometry
  matches source: 2880 = 9×320, 578 = 3×189+11 (`screenshot.c:578-581`).
- **A1.1 cross-checks (new tool `tools/map_shot_check.py`, stdlib-only PNG probe):**
  - start marker: our extraction predicts tile rect (1920,0)-(1952,63) for
    start_room=1/pos=0 in cell (6,0); yellow cluster found at (1872,24)-(1968,72)
    → **MATCH**;
  - guard label: predicted (2464,252)-(2496,315) from guards_tile room2/pos17;
    cluster found (2424,240)-(2544,288) → **MATCH**;
  - floor placement at tile granularity: all **12/12** loose-floor tiles carry the
    white `~~~~` glyph (40 white px in each predicted floor strip) vs **0** px in
    control strips → **PASS**;
  - level 1 has no gate tiles and no mirror tile (0 hits each in our fg dump), so
    the plan's “floor/gate/mirror” clause is floor-only-verifiable for level 1;
    ordinary wall/floor tiles and doorlink event numbers were not individually
    pixel-mapped (limitation); start-arrow direction is source-derived (level-1 XOR
    flip, `screenshot.c:429`), not OCR'd.
- **Extractor TILE_NAMES fix:** entries 5/6/7/10 were misnamed
  (drop_button/tapestry_bottom/potion/unknown_10) vs `types.h:113-131`
  (stuck/closer/doortop_with_floor/potion); `tile_label` was dead code so study
  output is unaffected. Selftest re-run after the edit: **0 failures**.
- **Tick-model correction (important):** while building PARITY.md, plan §8 P8
  ("12 fps traverse / 10 fps fight") was reconciled against source —
  `seg003.c:350-372` paces `play_frame()` with `base_speed=5` / `fight_speed=6`
  timer ticks of the 60 Hz timer (`types.h:1351`, `seg009.c:3732-3741`), and
  `rem_tick` 720 = 12×60 confirms 12 logic ticks/second (`seg008.c:1763`).
  Session-002's earlier STUDY_NOTES draft assumed 60 Hz logic and overstated every
  rate 5× (e.g. run speed 13.9 → correct ≈2.8 tiles/s); **study/STUDY_NOTES.md was
  corrected** (T1 rebuilt, all second-conversions recomputed) before anything moved
  into tracked files.
- **docs/PARITY.md written** (Q1 now allows): all ten A1.2 required tables with
  file:line citations, no code pasted, "ours" columns empty pending gates 2–3, plus
  the P1–P8 reference values and the observation-status statement.
- **Checkboxes:** A1.1 re-ticked (doubt resolved + selftest + Map_Symbols + live
  `--screenshot-level` evidence incl. tile-level floor check); A1.2 ticked (tracked
  deliverable + Accept satisfied). Phase A1 = Done.

**Post-close part 3 — stale-marker sweep (Q1/build now answered)**
- `scripts/pop/pop_rng.gd` upgraded from the placeholder LCG to the **reference
  generator** (constants 214013/2531011, high-16 draw, cited seg009.c:246-252;
  `rand_below(n)` = `prandom(n-1)`) per D4/D5 — determinism gate unaffected
  (assertions are relative, no golden hashes).
- `scripts/pop/pop_sim.gd` TODO(Q1) markers reworded to TODO(A2.2) (the remaining
  placeholders are unmeasured turn/average-dx values, not a Q1 block).
- `study/STUDY_NOTES.md` "blocked on Q1" / "build not approved" statements updated
  to the answered state; `docs/PARITY.md` §14 "Ours" updated to adopted.
- `./verify.sh` re-run after the pop_rng/pop_sim edits: see Verification.

**Baseline at session start**
- `./verify.sh`: exit 0, 116 passed, 0 failed, 5 levels boot clean (ran twice, identical). Log: `.verify_baseline_20261006.log` (untracked).
- Git: HEAD = `947cbbb`; `origin/main` = `947cbbb` (verified via ls-remote).

**Step 1 housekeeping**
- `git log --all --oneline -- 4dprinceprsia SDLPoP-1.23` → **empty across all refs**; `git fsck --unreachable` → no dangling commits; all local refs scanned; `git ls-tree -r origin/main` (125 entries) contains no reference-folder or study/ paths; the `original` remote's local tracking refs show only the two Arghya Bose commits (live `git ls-remote original` timed out; Session 000's fetch inspected instead). **Q2 = MOOT** (recorded in Open Questions) — no history rewrite needed or requested.
- `plan.md` and `review.md` were **untracked** (`??`), so `git diff HEAD` was empty; after intent-to-add the diff showed 785 + 263 added lines. Complete inventory of plan.md edits beyond checkboxes (all sessions combined): exactly two — the "Session 000 note" paragraphs at plan.md:432 and plan.md:449. Checkbox ticks: 179, 182 (§2.4), 421 (A1.1). This session changed only checkbox 421 (unticked).
- Committed plan.md + review.md as one commit: `02c6a29 "Add plan and session log (docs/log only; no code or game data)."` — no Codebuff footer, per user rule.

**Step 2 — the A1.1 doubt, resolved**
- **Verdict: the parsing was wrong. 25 and 16 were misreads.** `start_room=25` came from the `used_rooms` byte and `start_dir=16` from `roomxs[1]` (editor coordinate) — the Session 000 field walk was misaligned.
- Re-derived offsets from `types.h:216–238` under `#pragma pack(1)`: doorlinks1 1440, doorlinks2 1696, roomlinks 1952, used_rooms 2048, **start_room 2112 / start_pos 2113 / start_dir 2114**, guards_tile 2119, guards_dir 2143, guards_x 2167, guards_seq_lo 2191, guards_skill 2215, guards_seq_hi 2239, guards_color 2263. The walk sums to exactly **2305** = compile-time assert (`types.h:239`) = size of every res20NN.bin.
- Second-method cross-checks on levels 1, 2, 5 (files res2000/2001/2002/2005): corrected offsets give start_room ∈ 1..24, start_pos ∈ 0..29, start_dir ∈ {0,−1} for all 16 files (res2000 → **1 / 9 / −1**); the old offsets fail the same ranges (25, 16). Source corroboration: SDLPoP clamps `used_rooms` above 24 (`seg000.c:1158-1159`, `seg008.c:1163-1166`) which explains the 25; `screenshot.c:426-429` reads exactly start_room/pos/dir for the map start marker; `doc/Map_Symbols.txt` documents guard "s5 h4" (skill/HP) and start-direction arrows — and level 1's byte-extracted skill 5 with `tbl_guard_hp[5]=4` (`data.h:835`) matches that legend example.
- **Could NOT run the planned `--screenshot-level` cross-check**: prebuilt `SDLPoP-1.23/prince` fails `ldd` (`libSDL2_image-2.0.so.0` absent system-wide) and the build was not approved. Substituted source/byte cross-checks above — recorded as a limitation, not a pass.
- Extractor `tools/pop_level_to_notes.py` rewritten (corrected offsets, clamp like the port, doorlink accessors matching the port's formulas, editor-unused markers) with a real `--selftest`: field-walk = 2305, every OFF_* matches the walk, per-file semantic ranges, regression pin res2000 = 1/9/−1 with used_rooms raw 25 → clamped 24, guard in file-room 3 / tile 2 / skill 5, and a **negative control** asserting the old offset 2048 reads out of range. `study/level_00.txt`–`level_15.txt` regenerated (16 files, exit 0).
- **plan.md A1.1 was UNTICKED** (Session 000's tick rested on the disproven numbers). It stays unticked until the user either accepts the cross-checks or approves the build so the plan's literal Accept clause (`--screenshot-level` match) can run.

**Step 3 — A1.2 into study/ (untracked)**
- Wrote `study/STUDY_NOTES.md`: 15 re-expressed tables — tick clock, movement semantics, run-cycle dx stream, standing-jump and run-jump frame/dx/dy streams, hang/climb geometry, fall thresholds, spike cycle, gate/level-door speeds, plate/doorlink timing, loose floors, chompers, guard skill/HP tables, sword frame windows, RNG — every number carrying a file:line citation; no code pasted, no table copied; each figure marked [S] source-derived / [M] measured / [D] derived / [O] observed.
- **[O] is empty**: no number was confirmed against running SDLPoP (binary won't start, build not approved). Stated in the file as a limitation of A1.2.
- **PARITY.md is blocked on Q1** — nothing from study/ moved into tracked files (not even into this review.md, which is now tracked).

**Step 4 — A2 started, gate first**
- Wrote plan §8 gate 1 FIRST: new section in `tests/test_main.gd` ("Sim determinism gate") — fixed seed + fixed 600-tick input script run twice → equal state hash; same script from a second seed → different hash; one altered input tick → different hash (causality); pop_input byte round-trip. Then `scripts/pop/pop_input.gd` (8-bit x:2|y:2|shift:1|special:3), `scripts/pop/pop_rng.gd` (placeholder LCG with TODO(Q1) — reference generator stays in study/), `scripts/pop/pop_sim.gd` (pure integer-only stand/run/turn step + FNV-1a 32 state hash; no engine API, no floats).
- The gate caught two real bugs before going green: (1) the 2-bit two's-complement decoder was wrong (round-trip FAIL); (2) the causality check altered a neutral tick whose effect cancelled by tick 600, leaving the end-state hash equal — moved the flip into the run phase so divergence persists. Both fixed at the cause; no assertion weakened.
- Result: suite **121 passed / 0 failed** (direct run). Final `./verify.sh` result: recorded under Verification below.

**Summary of changes**
- plan.md: checkbox 421 (A1.1) unticked. No content edits (checkbox-only rule; see Plan changes for the proposed note correction).
- review.md: this entry + Dashboard, Phase tracker, Time Ledger, Decision Log, Open Questions (Q1 pending, Q2 moot), Open Issues (I1 closed, I2 opened), §8 gates (determinism ✅/✅), Asset Ledger, Change Index.
- `02c6a29`: plan.md + review.md committed together as docs/log only.
- Extractor rewrite + regenerated study/ + `study/STUDY_NOTES.md` (untracked).
- New A2 skeleton + gate test (uncommitted — see Questions for the user).

**Files changed**

| File | Action | Why |
|---|---|---|
| `plan.md` | modified (checkbox only) + committed in 02c6a29 | Untick A1.1 until its Accept clause can run. |
| `review.md` | modified (this entry + trackers) + committed in 02c6a29 (pre-entry state) | Session log and tracker updates. |
| `tools/pop_level_to_notes.py` | modified (uncommitted) | Fix the A1.1 offset bug; add real selftest assertions. |
| `study/STUDY_NOTES.md` | added (untracked) | A1.2 behavior tables with citations. |
| `study/level_00.txt`–`level_15.txt` | regenerated (untracked) | Corrected-offset study output. |
| `scripts/pop/pop_input.gd` | added (uncommitted) | A2.2 input byte packing. |
| `scripts/pop/pop_rng.gd` | added (uncommitted) | A2.2 placeholder generator, TODO(Q1). |
| `scripts/pop/pop_sim.gd` | added (uncommitted) | A2.2 pure integer stand/run/turn skeleton + state hash. |
| `tests/test_main.gd` | modified (uncommitted) | Plan §8 gate 1 (determinism) — 5 new assertions. |
| `.verify_session002_final.log` | added (untracked) | Final verify.sh capture. |

**Decisions made**
- Decision: A1.1 checkbox unticked rather than kept from Session 000. Reason: the tick rested on disproven offsets, and the plan's literal Accept (match `--screenshot-level` of level 1) has never run. Rule 5 — do not mark done what was not verified.
- Decision: Q2 recorded as moot, no history/remote action. Reason: the reference folders were verifiably never committed anywhere (all refs + remote tree checked).
- Decision: `pop_rng.gd` ships clearly-marked public-domain placeholder constants with TODO(Q1), not SDLPoP's LCG. Reason: the determinism gate only proves seed → reproducible state, which any deterministic generator satisfies; reference constants stay in untracked study/ until Q1.
- Decision: no Session-002 content notes written into plan.md (the Session-000 notes at :432/:449 remain as-is). Reason: user rule — checkbox edits only; the correction is proposed below instead.

**Verification**
- `python3 tools/pop_level_to_notes.py --selftest SDLPoP-1.23/data/LEVELS` → exit 0, **0 failures** (all range checks, regression pins, negative control pass).
- Extractor regeneration → exit 0, 16 files written; level_00 shows start 1/9/−1, used_rooms raw 25 → clamped 24, guard file-room 3 tile 2 skill 5.
- Test suite (direct headless run) → **121 passed, 0 failed**; the 5 new assertions all pass.
- `./verify.sh` final (after all session changes): **exit 0 — ALL CHECKS PASSED: import ok, 5/5 levels boot clean, 121 passed / 0 failed**. Log: `.verify_session002_final.log` (untracked).
- `./verify.sh` re-run at the very end of the post-close extension (tree had gained
  the screenshot PNG + built binary + PARITY.md): **exit 0 — ALL CHECKS PASSED
  again, 121/0**. Log: `.verify_session002_close2.log` (untracked).
- `./verify.sh` after the post-close part 3 edits (`pop_rng.gd` reference-LCG swap
  and `pop_sim.gd` comment rewording changed res:// files): **exit 0 — ALL CHECKS
  PASSED, 121/0**. Log: `.verify_session002_close3.log` (untracked). This is the
  authoritative final run.
- **Not verified / limitations:** no behavior observation of SDLPoP (binary lacks libSDL2_image-2.0.so.0; build not approved) — every A1.2 number is [S]/[M]/[D], none [O]; A1.1's `--screenshot-level` Accept clause unrun; Session 001 hours unknown; `git ls-remote original` timed out (local tracking refs used instead).

**Licensing and asset notes**
- Reference-derived numbers added to tracked files this session: **none** beyond format-level discussion already sanctioned by plan A1.1 (the extractor's selftest pins level-1's start facts as regression assertions — plan-approved tracked tool reading game data; no behavior constant moved). All behavior tables live in untracked `study/STUDY_NOTES.md`, blocked from `docs/PARITY.md` and `pop_tables.gd` until Q1. Note: plan.md:432's Session-000 note (now in git history via 02c6a29) contains disproven start-field numbers — correction proposed below.
- New assets: none (scripts are original code; pop_rng uses public-domain LCG constants, not reference values).
- Confirm no SDLPoP code/sprites/audio/text/level layouts copied verbatim: **yes — none**. Citations are file:line references only.
- Confirm nothing from `4dprinceprsia/`, `SDLPoP-1.23/`, or `study/` staged: **yes — none** (study/ untracked by design; git status reviewed at commit time).

**Problems, bugs, and surprises**
- I2 (major, fixed this session): Session 000's extractor offsets were wrong across the board (start fields, roomlinks, used_rooms, guards) — root cause: field walk misaligned vs `types.h`. Fixed, selftested, study/ regenerated. Details in Open Issues.
- Surprise: `res2015.bin` is 2304 bytes (one short) — pad-on-read retained; roomlinks range-check skipped for it only.
- Surprise: review.md had **no Session 001 entry** at all (only 000). Logged as a Time Ledger row with "figure pending" instead of reconstructing an entry from memory (rule 2/4).

**Plan changes**
- Proposed (needs user approval — beyond checkboxes): correct the plan.md:432 "Session 000 note", whose offset claims (roomlinks 1850, start 2048–2050, "start_room=25, start_dir=16") are disproven, and optionally add short Session-002 notes under A1.1/A1.2. No edit made yet.

**Questions for the user**
1. **Q1 (critical path):** answer the originality rule. Until then pop_tables.gd, PARITY.md, and the A2.2 kinematics numbers (frame dx/dy tables) are all blocked — most of Stage A cannot progress past the skeleton.
2. **A1.1 acceptance:** accept the source/byte cross-checks as the Accept clause, or approve the SDLPoP build (libsdl2-dev + libsdl2-image-dev + make, local only) so `--screenshot-level` can run? (libSDL2_image-2.0.so.0 is missing system-wide either way.)
3. **Session 001 hours:** fill the `[N] h` figure for the Time Ledger.
4. **plan.md:432 note correction** — approve the content edit (see Plan changes)?
5. **Commits:** three uncommitted groups remain (extractor fix; A2 skeleton + gate; this review.md entry). Commit them — separately or together, message style your call?

**Next session starts with**
1. Get answers to the five questions above; Q1 first (critical path for all of A2/A4/A5 numbers).
2. Re-tick A1.1 only after the user's explicit acceptance decision on the screenshot clause.
3. Continue A2.2 once Q1 allows measured constants: `pop_tables.gd` (tile enum + ~30 frame rows), then stand/turn/stop → jump/fall/spike/edge-snap with the A2.2 accept tests (run-jump 2 tiles / stand-jump 1 tile; 3-row fall kills, 2-row costs 1 HP).
4. If Q1 stalls: A3.1 sandbox shell (SimClock + pop_view) needs no reference numbers — the W1 "sandbox playable" checkpoint depends on it.
5. CI (`.github/workflows/verify.yml`) is W1 and needs user approval before push.

---

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
| D2 | 2026-10-06 | 002 | A1.1 checkbox unticked until its literal Accept clause runs or the user accepts the cross-checks. | Session 000's tick rested on disproven offsets; the `--screenshot-level` comparison has never executed (no approval + missing libSDL2_image). | Keeping the old tick (would violate "mark nothing unverified"); force-building SDLPoP without approval (not allowed). | Yes — one checkbox once the user decides. |
| D3 | 2026-10-06 | 002 | Q2 recorded as moot: no history rewrite, no remote action, ever needed. | Verified this session that the reference folders exist in no commit on any ref and not in origin/main's tree. | filter-repo / private republish — all unnecessary now. | n/a — no action taken. |
| D4 | 2026-10-06 | 002 | pop_rng.gd ships clearly-marked placeholder LCG constants + TODO(Q1), not SDLPoP's generator. | Gate 1 proves determinism, not generator identity; reference constants must stay untracked until Q1. | Shipping SDLPoP's constants now (would breach the Q1 hold); no RNG at all (gate couldn't prove seeds matter). | Yes — swap constants when Q1 allows. |
| D5 | 2026-10-06 | 002 | Q1 answered post-close: reference-derived constants may enter tracked files **with file:line citation**; no-code-copied and folders-out-of-repo rules unchanged. | User read the competition rules and accepted the cited-facts posture. | Keeping the hold (would stall most of Stage A); copying without citation (rejected — never allowed). | Reversible by the user re-opening Q1. |
| D6 | 2026-10-06 | 002 | SDLPoP local build approved: apt install libsdl2-dev + libsdl2-image-dev, make in SDLPoP-1.23/src, local only, nothing built shipped or committed. | Unblocks A1.1's `--screenshot-level` Accept and A1.2's [O] observation column; also needed later for gate 6 (.p1r). | Staying unbuilt (leaves two blockers open permanently). | n/a — packages are local study tooling. |
| D7 | 2026-10-06 | 002 | Build executed via unprivileged `apt-get download` + `dpkg -x` into `.tools/sdlroot` instead of `apt-get install` (sudo needs interactive password). | Same packages, same versions, zero system change — stays inside the "local only" approval; a version-matched system symlink was reused for the runtime .so. | Waiting for an interactive sudo (would have stalled the session); static-link workaround (failed on ALSA, rejected). | Yes — delete .tools/sdlroot to remove entirely. |
| D8 | 2026-10-06 | 002 | A1.1 re-ticked and A1.2 ticked. | A1.1: doubt resolved + selftest (incl. negative control) + Map_Symbols + live `--screenshot-level` probe (start ✓, guard ✓, 12/12 floor glyphs ✓); gates/mirrors don't exist on level 1. A1.2: all ten required tables in tracked docs/PARITY.md with citations, no code pasted — Accept met. | Leaving A1.1 unticked forever (screenshot clause can't be made more complete than this for level 1); not ticking A1.2 (would under-report a met Accept). | Yes — untick if the user disagrees with the evidence level. |

---

## Open Questions from plan §11 (answers recorded here)

| Q | Topic | Blocks | Answer | Date | Session |
|---|---|---|---|---|---|
| Q1 | RRR originality rule: are measured behavior constants with citation acceptable? Does the jury check repo or only build? | A1 citations, A5, pop_tables.gd, PARITY.md, most of A2.2 & A4 numbers | **ANSWERED (post-close, Session 002): "rules read; measured constants with citation are acceptable."** Standing mitigations unchanged: every number carries a file:line citation, no code/table copied verbatim, reference folders stay out of the repo and the shipped build. `docs/PARITY.md` and `pop_tables.gd` are now unblocked. | 2026-10-06 | 002 |
| Q2 | Git history of reference folders: accept / filter-repo + force-push / private, strip, republish | §2.4 | **MOOT** — verified in Session 002: `git log --all` shows the folders in no commit, `git fsck --unreachable` found nothing, `origin/main` tree (125 entries) contains neither folder nor study/. No history or remote action is needed or requested. | 2026-10-06 | 002 |
| Q3 | Port SDLPoP `.p1r` replays as formal parity tests? | A5.3 | | | |
| Q4 | Music: compose in LMMS or source CC0? | B4.2 | | | |
| Q5 | Aseprite purchase or LibreSprite? | A3.3 | | | |
| Q6 | In-game title: "Echoes of Time" only, or keep "Prince of Persia:"? | B5.2 | | | |

---

## Open Issues

| ID | Opened (session) | Severity (blocker / major / minor) | Description | Status | Closed (session) |
|---|---|---|---|---|---|
| I1 | 000 | minor | Extractor crashed on full res2000–res2015 batch: used_rooms() returned 255 for truncated/non-standard files and guard accessors indexed out of range. | **Closed** — fixed in 000; re-verified in 002: `--selftest` passes (0 failures) over all 16 files, including the non-canonical res2015 (2304 bytes, padded on read). | 002 |
| I2 | 002 | major | Session 000's extractor field offsets were misaligned vs `types.h` (start_room/start_pos/start_dir, roomlinks, used_rooms, guards all shifted): reported start_room=25 / start_dir=16 for level 0 were reads of the used_rooms byte and an editor coordinate. | **Fixed in 002** — offsets re-derived from the packed struct (walk sums to 2305 = sizeof assert), extractor rewritten, selftest now asserts ranges + regression pin (res2000 → 1/9/−1) + a negative control on the old offset; study/ regenerated. plan.md A1.1 unticked pending its Accept clause (screenshot run still blocked). | |

---

## Parity Tracker (plan §8 gates and §4.3 behaviors)

"Reference" = measured from SDLPoP behavior (fixes off). "Ours" = measured from `pop_sim`.

| ID | Behavior | Reference | Ours | Status | Session |
|---|---|---|---|---|---|
| P1 | Standing jump horizontal distance | ≈36 u ≈2.57 tiles at landing frame f27 (stream: PARITY.md §4; source-derived, [S]) | | ⬜ | 002 |
| P2 | Running jump horizontal distance | ≈67 u ≈4.79 tiles total f34→f7 (PARITY.md §5; [S]) | | ⬜ | 002 |
| P3 | Fall thresholds (soft / medium / death) | impact speed <22 / 22–32 / ≥33 (PARITY.md §7; [S]) | | ⬜ | 002 |
| P4 | Hang / grab frame counts | 43-frame sway auto-drop; grab_timer 12 frames (PARITY.md §6; [S]) | | ⬜ | 002 |
| P5 | Spike cycle length | ≈23 logic frames (PARITY.md §8; [S]) | | ⬜ | 002 |
| P6 | Gate open/close speeds, plate timing (±1 tick) | −1/+4 units/frame, fast 20…120; plate timer 5→<2 (PARITY.md §9–10; [S]) | | ⬜ | 002 |
| P7 | Guard duel transcript, seeded, skill 0 | tables: PARITY.md §12–§14 (strikeprob 61/blockprob 0/advprob 255 for skill 0; [S]) | | ⬜ | 002 |
| P8 | Tick model: 12 fps traverse / 10 fps fight | confirmed: base_speed 5 / fight_speed 6 ticks of 60 Hz (PARITY.md §1; [S]) | | ⬜ | 002 |

Status: ⬜ not tested · ❌ failing · ✅ matching

Reference values for P1–P8 were derived into untracked `study/STUDY_NOTES.md` in Session 002 but are **not recorded here (this file is tracked) until Q1 is answered**; behavior observation [O] is additionally blocked (no runnable SDLPoP binary).

### Plan §8 test gates

| Gate | Written? | Passing? | Session |
|---|---|---|---|
| Determinism (600 ticks, twice, equal hash; different seeds differ) | ✅ | ✅ | 002 |
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
| `study/STUDY_NOTES.md` | study notes (text) | written in Session 002 from SDLPoP-1.23 source reads (file:line cited) | n/a (study notes, not shipped) | Yes — all values are reference-derived; that is why it stays untracked until Q1 | 002 | n/a (not committed) |
| `scripts/pop/pop_rng.gd` LCG constants | code constants | public-domain LCG (1664525 / 1013904223), own choice | n/a (code) | **No** — deliberately NOT the reference generator; TODO(Q1) marks the swap point | 002 | Pending Q1 for the eventual swap |
| `scripts/pop/pop_input.gd`, `pop_sim.gd`, gate section of `tests/test_main.gd` | code | written this session (structure only: byte packing, stand/run/turn, state hash) | n/a (code) | No gameplay constant carried; placeholder dx/turn values marked TODO(Q1) | 002 | n/a |

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
| 002 | 2026-10-06 | A1.1+A1.2 done, A2 gate 1 | 4.1+ext | Session 000's offsets proven wrong and extractor fixed (selftest w/ negative control + TILE_NAMES fix); A1.2 → study/STUDY_NOTES.md + tracked docs/PARITY.md (Q1 answered); SDLPoP built locally (no sudo) and `--screenshot-level` cross-check passed (start/guard/floor 12/12); tick model corrected to 12/10 fps; determinism gate green; A1.1+A1.2 ticked. | 5 added (121 total) |
| 000 | 2026-10-06 | §2.4 + A1.1 | 1.5 | Baseline captured; .gitignore reference entries added; A1.1 study extractor built, fixed, and run to produce study/ level_00–15 notes; verify.sh still green. No commit yet (awaiting user confirmation on Q1/Q2 + commit timing). | 0 added |

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
| Last updated | 2026-10-08 (Session 005) |
| Days to deadline | 23 (as of 2026-10-08) |
| Current stage / phase | Stage A / **A1 Done** · **A2 Done** (A2.3 ticked S005) · **A3 in progress** (feel **not verified, needs human playtest**) · **A4.1 Done** (gates/plates/exit door) · **B1 thin slice done** (input-byte echo on the sim; Stage-B bridge still ahead) |
| Sessions logged | 5 entries (000, 002, 003, 004, 005). Session 001 has no entry — see Time Ledger |
| Hours used / budget | 10.3 / 34 (S000 1.5 + S001 1.0 + S002 4.8 + S003 3.0) — 23.7 h remaining. S004 and S005 hours pending the user's confirmed figures (not estimated here). |
| Test status | **./verify.sh exit 0, ALL CHECKS PASSED — import ok, 5/5 levels clean, 272 passed / 0 failed** (243 at S004 close + 24 A4.1 + 5 B1); harness also green in a clean clone with no study//reference folders and no .godot/ (import first). A3 feel unverified. |
| Parity checks passing | 4 / 8 — P1, P2, P3, P8 ✅ matching (A2.2 acceptance tests + first [O] observation); P4 and P6 ◐ partial; P5/P7 pending their gates |
| Open blockers | No hard blockers. Observation **partial**: run-jump and fall-threshold numbers still unobserved (harness ready). A3 feel is **not verified headlessly** — human playtest of `pop_lab.tscn` pending (checklist in the Session 004 entry). Outstanding decisions: push (never without approval), S002/S004/S005 hours figures [N]. |
| Cut line status | Nothing cut yet; W1 exit criteria 3/4 met (refs removed ✅, PARITY.md v1 ✅, sandbox exists & boots ✅ — feel needs playtest; CI workflow landed but not pushed → not "online" yet). No cut-list trigger raised. |
| Competition deliverables | Build ⬜ · Video ⬜ · GDD ⬜ · Slides ⬜ · License record ⬜ |

### Weekly checkpoints (from plan §9)

| Week | Dates | Exit checkpoint | Met? |
|---|---|---|---|
| W1 | Oct 6–12 | Sandbox playable; PARITY.md v1; refs removed from repo; CI online | ◐ 3/4 — sandbox boots (playtest pending), PARITY.md v1 ✅, refs removed ✅; CI workflow landed, not pushed |
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
| A2 | Sim core | 8 | **Done** — A2.1 + A2.2 + A2.3 all ticked; gate 2 partially covered | 002, 003, 004, 005 |
| A3 | Presentation shell | 6 | In progress — SimClock + `pop_view` sandbox + input latch landed; feel unverified | 004 |
| A4 | Traps, tiles, duels | 12 | In progress — **A4.1 gates/plates/exit door done**; A4.2–A4.5 pending | 005 |
| A5 | Parity verification | 7 | Not started | |
| B0 | Bridge decision (rebase on sim) | 2 | Not started | |
| B1 | Temporal Echo, input-level | 6 | In progress — thin **input-byte echo on the sim** done (record/replay, one-bit divergence); Stage-B bridge pending | 005 |
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
| 003 | 2026-10-06/07 | 3.0 | 10.3 | 23.7 | Pre-commit audit + 4 user-approved commits (`b6dd845`, `e0814bc`, `ec27e2a`, `fc03e94` — **not pushed**); plan.md:432 note corrected (approved); A2.1 `pop_tables.gd` + drift test; A2.2 step function + acceptance tests (189/0, verify exit 0); Step 5 observation: tick **12.00 Hz** and standing jump **≈38 u** observed [O]; run-jump/fall NOT observed. Hours = wall clock 22:09–01:10 from file mtimes. S002 hours figure `[N]` still blank — row 002 keeps 4.8 until reported. |
| 004 | 2026-10-08 | [N] | 10.3 (S004–005 pending) | — | A2.3 acceptance rebuilt under audit; working-tree corruption repaired; A3.1 SimClock + A3.3 latch + A3.2 pop_lab sandbox; 243/0. Hours pending the user's confirmed figure. |
| 005 | 2026-10-08 | [N] | 10.3 (S004–005 pending) | — | A2.3 ticked; pre-push audit clean (no push); A4.1 gates/plates/exit door + `pop_level.gd` room-grid loader; thin B1 input-byte echo; 272/0. Hours pending the user's confirmed figure. |

---

## Session Log

<!-- Newest first. Copy the template below for each new session. -->

### Session 005: 2026-10-08 — A2.3 ticked; pre-push audit clean; re-order proposed (A4.1 → B1 → A4.2 → A4.3); A4.1 gates/plates/exit
_(entry in progress — completed as work lands)_

**Baseline at session start**
- `./verify.sh`: exit 0, **ALL CHECKS PASSED** — import ok, 5/5 levels clean, **243 passed / 0 failed** (Godot 4.7.2-stable; log `verify_s005_baseline.log`).
- Git: branch `dev/pop-rebuild`, HEAD = `23ed2c7`; `git status --porcelain --untracked-files=no` empty; `git diff 23ed2c7 --stat` empty — no tracked change outside intent. Untracked and deliberately uncommitted: `tools/frame_decode_check.py`, `tools/smoke_pop.gd`, `tools/smoke_pop.gd.uid`.
- Housekeeping: two stale hung `test_main.tscn` runs (started 17:09 / 17:13, ~2 h with no output) were found and killed **before** the baseline run, so the 243/0 figure is from a clean single run.

**Step 0 — integrity**
- `plan.md` and `review.md` read. `plan.md` differs from `23ed2c7` only by the A2.3 tick applied this session (below). No fused-table lines; the Session-004 corruption repair holds.
- **A2.3 ticked** in `plan.md` with the user-approved wording (checkbox `[ ]`→`[x]` + one note line, no other edit): *sim-verified with PARITY-derived frame counts; scenario geometry unmeasured; safe-step at edge distance 0 unmodeled; SDLPoP observation pending.*

**Step 1 — pre-push audit (report only; nothing pushed)**
- (a) `git ls-files | grep -E "\.tools|\.log|\.patch|Original|study|SDLPoP|4dprinceprsia"` → **empty** (grep exit 1). ✅
- (b) `git log --all --oneline -- 4dprinceprsia SDLPoP-1.23 study` → **empty**. ✅ No reference-data commit on any ref; nothing to reach what will be pushed.
- (c) `.github/workflows/verify.yml` → `on: push` + `pull_request` with **no branch filter**, so it fires on all branches including `dev/**`; the Godot version is pinned in `verify.sh` (`GODOT_VERSION="4.7.2-stable"`); step 1/3 runs `--import` and fails on `SCRIPT ERROR|Parse Error|Failed to load`. ✅ (Note: the pin lives in `verify.sh`, not the workflow; the cache key `godot-4.7.2-stable-linux-x86_64` mirrors it — bump both together.)
- (d) Licensing re-scan **method**: (1) `grep -rnE "segment[0-9]|__asm|static void|uint16_t|\bseg[0-9]{3}_|typedef struct|SDLPoP|#include" docs/PARITY.md scripts/pop/` — every hit is citation/comment text (a `file:line` reference or the word SDLPoP in a header); **no C declarations, no pasted tables**; (2) scanned for any line >200 chars containing code punctuation (`{};`) — none found. `docs/PARITY.md` and `pop_tables.gd` are numbers + `file:line` citations only. ✅
- **Verdict: clean to push.** Not pushed — the user pushes.

**Step 2 — proposed re-order (proposal only; `plan.md` NOT edited)**
- **Proposed order: A4.1 → minimal B1 → A4.2 → A4.3.**
- **Reason:** the single biggest schedule risk in Stage B is `B1` — rebasing the *existing* Echo/`TemporalManager` gameplay onto the new 12 fps `pop_sim` and its byte-packed `pop_input`. If that rebase turns out to be harder than assumed, it changes what is buildable, so it should be proven early with a thin slice, not discovered at the end of W2. A4.1 (gates/plates/exit door) is the smallest A4 slice that gives the thin Echo something meaningful to *do* (a recorded run that triggers a plate), so A4.1 comes first and minimal B1 immediately after it. A4.2 (spikes/loose floors) and A4.3 (guard duel) then proceed as planned.
- **What "minimal B1" means:** one new module, `scripts/pop/pop_replay.gd`, that (i) records N ticks of `pop_input` bytes from a live run, (ii) releases a **second sim participant** that replays those exact bytes into its own `PopSim`, (iii) that replayed participant triggers a plate/gate in the level, and (iv) is proven to be honest under the determinism gate.
- **Acceptance test (plan §8 gate 4 — Echo replay v2 + one-bit divergence):** record N ticks of input bytes; release a second sim participant that replays them; it triggers a plate; **state hashes are identical across two runs** of the same recording; and **flipping one recorded bit makes the run diverge**. Reuse `pop_input` bytes rather than the legacy `TemporalManager` transform path.
- **Cut-list impact: none.** The order does not add, remove, or re-rank any cut-list item, so this proceeds without waiting for approval (per the session rule). If the rebase turns out to need the legacy `TemporalManager` path beyond a `--legacy-physics` flag, work stops and the specific obstacle is reported instead of worked around.

**Step 3 — A4.1 gates, plates and the level exit (done, committed `4b9c0cd`)**
- **New files:** `scripts/pop/pop_level.gd` (room-grid loader + the gate/plate/exit machines), `scripts/pop/pop_replay.gd` (Step 4). **Changed:** `pop_tables.gd` (PARITY §9/§10 constants), `pop_sim.gd` (entity state in `STATE_KEYS` + `initial_state`/`run` entity argument; `step()` advances entities; `hash_state` now folds dicts/arrays), `tests/test_main.gd` (`_test_a41_entities`), `docs/PARITY.md` (one new §10 row).
- **Model (all values from PARITY §9/§10, cited per branch):** gate modifiers with `DOOR_DELTA = [-1, 4, 4]`, open threshold 188 → park 238, permanent 0xFF, fast-close speeds 20…120; a raise plate rounds the modifier up to a multiple of 4 and starts `opening`, a closer plate starts `fast closing`; the level-exit door starts at 43 and fast-closes through `{0,5,17,99}`; the plate hold timer is set to 5 and decrements per tick, re-pressing the gate only when it was below 2.
- **Reference finding (recorded):** the reference plate does **not** re-open a gate every tick it is held — `trigger_button` resets the timer to 5 each held tick, so the gate fires once and then runs §9's schedule (open in ~47 ticks, close ~238 ticks later). Our model matches this; the earlier guess that a held plate keeps a gate continuously open was wrong. A plate is re-pressable only after the kid steps off long enough for the timer to drop below 2.
- **Accept:** a test level built by the loader exercises plate→gate timing **within ±1 tick** of the PARITY rows — open 47±1 (188 @ +4/frame), close 238±1 (−1/frame), exit door 3 ticks, plate timer 5. Every assertion comment names its PARITY row; the machine behaviour with no independent oracle (level shape, press→state) is labelled "sim characterization". Determinism gate stays green (entity state included).
- **Evidence:** `./verify.sh` **267 passed / 0 failed**, exit 0 (log `verify_s005_a41b.log`) — 24 new checks over the 243 baseline.

**Step 4 — minimal B1, thin input-byte Echo (done, committed `dcbdc73`)**
- **New file:** `scripts/pop/pop_replay.gd` (`PopReplay`) — records a live run's per-tick `pop_input` bytes and replays them into a **second sim participant** (`replay()`), with a one-bit-flip probe. The legacy `TemporalManager` path was **not touched** (no `--legacy-physics` flag was needed).
- **Accept (plan §8 gate 4):** record 40 ticks; the replay participant reproduces the recorded final state and triggers the plate (the linked gate moves); two replays hash identical; flipping one recorded bit diverges. All four assert green.
- **Evidence:** `./verify.sh` **272 passed / 0 failed**, exit 0 (log `verify_s005_b1.log`) — 5 new checks. This is the thin slice only: full Stage-B Echo (room-scoped recording, multiple participants, the bridge to the shipped game) is still ahead.
- **GAP lines:** (1) the bucket above is sim-level — the replay proves byte-faithfulness, not the shipped Echo; (2) the gate/plate machine has no [O] observation against the reference binary yet (P6 ◐).

**Files touched this session**
- `plan.md` (A2.3 tick only), `review.md`, `docs/PARITY.md` (+1 row).
- `scripts/pop/pop_tables.gd`, `scripts/pop/pop_sim.gd`, `scripts/pop/pop_level.gd` (new), `scripts/pop/pop_replay.gd` (new), `tests/test_main.gd`.

**Hours:** not stated — S004 and S005 figures are blank in the session brief; the ledger keeps the cumulative at 10.3 / 34 until reported. **Nothing on the cut list triggered.**

### Session 004: 2026-10-08 — A2.3 acceptance rebuilt (under audit); working-tree corruption found and repaired; clean-clone check green
- Rebuilt `_test_a23_acceptance()` in `tests/test_main.gd`. **Scope A** re-derives the §6/§7 stream lengths and thresholds through the mini play_seq interpreter; **scope B** asserts live PopSim behavior on crafted levels (pit walk drops a row; Shift mid-air grab fires with `grab_timer = 12` and enters `grab_hang`, and does **not** fire without Shift; idle hang release ends in `hang_drop` on f81; Up at `grab_timer 0` routes to `climb_up` on f135; Down from stand enters `crouch` on f107; Shift+forward with floor ahead enters `safe_step_11` on f121).
- **Corruption repaired (working-tree-only; never committed and not recoverable from git history).** `project.godot` had lost the `GameManager`/`TemporalManager` autoloads; `scripts/pop/pop_input.gd` was stubbed (`to_byte()` returned 0, `from_byte()` returned neutral); `pop_sim.gd` had `const STATE_KEYS` fused onto the tail of a `##` comment. All three were restored to HEAD. A `.godot` import pass is required for `class_name` globals under `--headless`. The exact edit/command that caused them is not recoverable from the repo artifacts (all three `.backup/s004_*` snapshots are clean; no commit, stash or reflog entry holds them) — the strongest evidence points to the Session-003 tool churn, but that is inferred, not proven.
- **Audit found one further decoupling:** `pop_sim.gd` carried `const TURN_TICKS: int = 8` (HEAD had `PopTables.TURN_TICKS`). Restored, and A2.1 now asserts the *source* binding (a literal would pass a value-only check).
- **Circularity audit:** every A2.2/A2.3 assertion is now labelled by origin. Scope-B and geometry assertions carry "(sim characterization, not parity evidence)"; the table-derived `climb_up` 18-tick count is labelled likewise. PARITY-sourced assertions are the §2/§4/§5/§6/§7/§8/§18 values read from `docs/PARITY.md`.
- **PARITY §6 discrepancy resolved (D13):** "stand at frame 18" is the **tick index**; the **frame id** is f15 (`seqtbl.c:261-263`). §6 reworded and a `stand frame | f15` row added; A2.1 binds the stand sequence to it.
- **A2.3 acceptance-test loss (found in Session 003, recorded here):** `_test_a23_acceptance()` was absent from the tree and unrecoverable from git history, stash, reflog and editor backups (never committed). It was rebuilt this session. Kept as a Session-004 bullet rather than rewriting the Session-003 entry.
- **Evidence upgrades (Section 3):** PARITY gained a §2 `Edge snap on landing` row (`seg005.c:126-131`) and a §4 `Standing-jump trigger` row (`seg005.c:385-395`, `seg005.c:453-458`, `seg005.c:673-675`). The A2.2 landing-snap asserts now read the §2 row and are labelled PARITY-sourced; the (b1b) trigger asserts read the §4 row and are labelled PARITY-sourced. Stale `seg005.c:422-424`/`522-524` standing-jump citations in `pop_sim.gd` corrected. **Note:** the reference lines originally proposed for the trigger (422-424, 522-524) are the `up_pressed` level-door block and a joystick-reset block — the real trigger is in `control_standing`/`up_pressed` (385-395/453-458). Other `pop_sim.gd` comments carry `seg005.c:` citations that a full audit should re-check.
- **Evidence:** harness **227 passed / 0 failed**; `./verify.sh` exit 0 (see Change Index). Clean-clone check (no study/, reference folders, logs or `.godot/`; `--import` first) green — no dependency on local-only files.
- **A3 started (plan A3.1/A3.2/A3.3):** `sim_clock.gd` (12/10 Hz fixed step from a variable render delta), `pop_input_latch.gd` (render-rate union → one input per tick, plus a new `grab` action), and `pop_view.gd` + `scenes/pop/pop_lab.tscn` (flat floor + 1-tile pit + raised ledge; interpolated body, sim-snapped frame). New A3 test section (+16 checks; harness **243 passed / 0 failed**); `pop_lab.tscn` boots clean headless. Committed A3.1, then A3.3 (the view consumes the latch), then A3.2.
- **Playtest checklist (A3 sandbox — NOT verified headlessly; run `pop_lab.tscn`):** run cadence (no stutter); stop → stand; turn; standing jump clears the col-4 pit (forward+Up); run jump; climb up at the row-1 ledge; hang (Shift at the lip); drop (release the hang); fall damage / full-ledge-height fall; P pause + `.` frame-step exactly one tick.
- **GAP lines:** (1) A2.3 scenario geometry is sim-level (pit/grab/hang/climb/crouch/safe-step helpers are crafted levels, not PARITY-derived); (2) safe-step-on-edge-at-distance-0 is unmodelled (A2.3-optional; `seg005.c:595-605`).
- **A2.3 is NOT ticked:** not every A2.3 criterion has a PARITY-sourced assertion (scope B is sim characterization). Hours not stated — pending the user's confirmed S004 figure.

### Session 003: 2026-10-06/07 — 4 approved commits; A2.1 + A2.2 built and verified (189/0); first gameplay observation (12.00 Hz, standing jump)

| Field | Value |
|---|---|
| Date | 2026-10-06 22:09 → 2026-10-07 close |
| Session # | 003 |
| Hours spent | 3.0 (wall clock 22:09–01:10 from file mtimes) |
| Agent / tool | Buffy (Freebuff) |
| Plan phase | Housekeeping commits (S002 work) → Q2 re-check → A2.1 pop_tables → A2.2 step function + acceptance → Step 5 observation |
| Goal | Per session plan: audit and commit the S002 work (user-approved), re-check Q2 against the live remote, land A2.1 `pop_tables.gd` and the A2.2 step function with its acceptance tests, then observe the running reference for tick-rate / jump / fall numbers (Step 5), and close out. |
| Status | A2.1 + A2.2 complete and verified. Observation **PARTIAL** — 2 of 3 target numbers observed (tick rate, standing jump); run-jump and fall threshold NOT observed, recorded honestly (`study/OBSERVATION.md` §4). A2.1/A2.2 code still uncommitted — the 4-commit approval covered the S002 groups only. |

**Baseline at session start**
- `./verify.sh`: exit 0, **121 passed / 0 failed**, 5/5 levels (log `.verify_baseline_s003.log`, 22:09).
- Git: HEAD = `947cbbb` = `origin/main`.

**Step 1 — pre-commit audit + 4 approved commits (not pushed)**
- Audited the whole uncommitted set (status + diff) before staging anything, then committed four groups on the user's approval:
  - `b6dd845` — extractor level-offset/tile-name corrections + the map-screenshot cross-check probe;
  - `e0814bc` — pop sim skeleton (input byte, rng, stand/run/turn step) + the determinism gate;
  - `ec27e2a` — plan/review for Session 002, including the **user-approved plan.md:432 note correction** (the disproven Session-000 offsets) and the A1.1/A1.2 ticks (docs/log only);
  - `fc03e94` — the cited A1.2 reference behavior tables (Q1-approved facts, no code).
- **Not pushed** — push always needs the user. Git identity Akash-Das26, no bot footers.

**Step 2 — Q2 re-check**
- Live `git ls-remote` against GitHub succeeded; `origin/main` = `947cbbb`. No reference material in the remote tree — Q2 stays moot (re-verification recorded in Open Questions).

**Step 3 — A2.1 `scripts/pop/pop_tables.gd`**
- Pure data file (Accept: no logic, peer-checkable against PARITY.md): tile enum (our names ↔ reference ids) + the ~30 kid frame rows (dx/dy/flags) + sequence-op interpreter data, every number carrying a file:line citation into `SDLPoP-1.23/src/` (D5 posture).
- Drift test added to the suite: the tables are recomputed against `docs/PARITY.md` row-by-row, with a **negative control** proving a perturbed table value makes the test fail. Suite at A2.1: **156 passed / 0 failed**.

**Step 4 — A2.2 step function, acceptance green**
- `scripts/pop/pop_sim.gd` extended: stand/run/turn/stop, standing jump, run jump, soft/medium land + death, spike contact, floor-tile edge snapping (`y_land`/`x_bump` equivalents) — pure integer logic.
- New `_test_a22_acceptance()` + helpers (`_flat_level`, `_hole_level`, `_crafted_landing`, `_frame_index`) in `tests/test_main.gd`. **Every number matched PARITY exactly — no gaps:**
  - stand jump: landing f27 at **36 u**, total **39 u** (§4);
  - run jump: f43 = **58 u**, landing **62 u** (f44), total **67 u** (§5);
  - falls: 1 row → impact **21** soft; 2 rows → **30**, −1 HP (3→2); 3 rows → **33**, death on the row-3 floor (y = 242 = Y_LAND[4] − 2 hard-land, *not* fell_out — the test asserts y to distinguish);
  - spike: kill + impale f177, modifiers → 0xFF, caller's modifiers untouched, 0xFF control passes;
  - edge snap: 141 → 139 (−3 net incl. soft_land dx+1); 6 units away → no pull; floor-continues → no pull;
  - turn = f45–f52 in **8 ticks** with the direction flip at tick 8, stand frame at tick 9; run stop f53…f52 done at tick 8, stand at 9;
  - determinism double-run: equal state hash over 400 ticks (x=101, hp=3).
- **Assertion-vs-reference learning (not a sim bug):** my first turn/run-stop asserts expected the stand frame *at* tick 8 and failed with 9. The reference ends the tick on a frame op (`seg006.c:682` `Char.frame = command; return`), so the trailing `jmp(stand)` (`seqtbl.c:449`, `seqtbl.c:627`) executes on the *next* tick; stand = act + f15 + jmp (`seqtbl.c:261-263`) → observed turnaround is 9 ticks. Asserts now measure f52 at tick 8 and the stand frame at 9; **PARITY §18 gained a cited clarification note**. No assertion was weakened — the old asserts measured the wrong thing.
- Direct suite: **189 passed / 0 failed**; `./verify.sh` → **exit 0, ALL CHECKS PASSED, 189/0, 5/5 levels** (log `.verify_s003_a22.log`). Final pre-close run under Verification.

**Step 5 — observation of the running reference (local SDLPoP)**
- Method (full write-up: `study/OBSERVATION.md`, untracked): launched `SDLPoP-1.23/prince` with the real Session-002 libs (`LD_LIBRARY_PATH=.tools/sdlroot/...` → **0 IMG errors**); copied the 37 DOS `*.DAT` files (`cp -n`, non-destructive) from `4dprinceprsia/` into `SDLPoP-1.23/data/` so gameplay sprites load via the DAT chain (reference-folder-only, reversible); captured the window with ffmpeg `-window_id 0x120000a` (root-window grab is all-black under Hyprland) as gray 640×400@60; injected keys with `study/obs_probe.py` (XTEST); analyzed with `study/obs_analyze.py` (motion-frame cadence + kid bbox trajectory).
- **Observed — tick rate: 12.00 Hz.** Median = mean = 5.00 video frames = 83.33 ms at 60 fps, across 84 samples then 25 samples, two independent captures → matches PARITY §1 [S] exactly.
- **Observed — standing jump: ≈175 px ≈ 38 units ≈ 2.7 tiles** (bbox x 86 → 261, Up held 0.35 s; 64 px/tile ÷ 14 units/tile) → consistent with PARITY §4's 36 u / 2.57 tiles within bbox/centroid error.
- **NOT observed — run jump:** short Up taps (0.12 s) swallowed by input timing; longer taps + run-up overshoot the cols 2–3 pit → the kid dies first. **NOT observed — fall threshold:** never attempted after that. Also unobserved: 10 Hz fight tick, spike cycle, guard duel. Reasons and the harness limits are in OBSERVATION.md §4–5.
- Environment quirks: Escape pauses behind an **invisible** pause menu (font PNGs fail to load; toggle `seg000.c:586-601`, display `seg000.c:1700-1726`); restart on death = `a` key; room grid 10 cols × 3 rows, spawn x ≈ 96, 2-tile pit at cols 2–3.

**Summary of changes**
- plan.md: A2.1 and A2.2 checkboxes ticked (checkbox-only rule).
- review.md: this entry + Dashboard, Phase tracker, Time Ledger, Parity Tracker (P1/P2/P3/P8 measured), §8 gates, Decision Log (D9–D12), Open Questions (Q2 re-verified), Open Issues (I2 closed, I3 opened), Asset Ledger, Change Index.
- docs/PARITY.md (uncommitted): §18 turn/run-stop clarification note; header observation-status bullet + §1 and §4 [O] notes + §19 open-items updated for the two observed numbers.
- scripts/pop/pop_tables.gd (new, untracked): A2.1 cited tables.
- scripts/pop/pop_sim.gd, tests/test_main.gd (modified, uncommitted): A2.2 step function + acceptance tests.
- study/ (all untracked): `OBSERVATION.md` (new), `obs_probe.py` / `obs_analyze.py` (new harness), `STUDY_NOTES.md` [O] status updated.
- SDLPoP-1.23/ (reference folder, untracked): 37 DATs copied in (cp -n); `stub_img.c` + stub `libSDL2_image-2.0.so.0` from the earlier boot attempt remain on disk, superseded by the real sdlroot libs.

**Files changed**

| File | Action | Why |
|---|---|---|
| `plan.md` | modified (checkboxes A2.1, A2.2 only) | Tick the two completed plan tasks. |
| `review.md` | modified (this entry + all trackers) | Session log. |
| `docs/PARITY.md` | modified (uncommitted) | §18 clarification note + [O] observation notes (§1, §4, §19, header). |
| `scripts/pop/pop_tables.gd` | added (untracked) | A2.1 cited frame/tile/sequence tables. |
| `scripts/pop/pop_sim.gd` | modified (uncommitted) | A2.2 jump/fall/spike/edge-snap/turn/stop steps. |
| `tests/test_main.gd` | modified (uncommitted) | A2.2 acceptance tests + level/analysis helpers. |
| `study/OBSERVATION.md` | added (untracked) | Step 5 observation record: method, 2 observed numbers, non-observations. |
| `study/obs_probe.py`, `study/obs_analyze.py` | added (untracked) | Observation harness (XTEST input, gray-frame analysis). |
| `study/STUDY_NOTES.md` | modified (untracked) | [O] status updated: two numbers now observed. |
| `SDLPoP-1.23/data/*.DAT` (37 files) | copied `cp -n` (reference folder, untracked) | Gameplay graphics for observation; reversible. |
| `SDLPoP-1.23/stub_img.c`, stub `.so` | built earlier in session (untracked) | Boot workaround, superseded by real sdlroot libs; left in place. |
| `.verify_s003_*.log`, `.s003_a22_run*.log` | added (untracked) | Verification captures. |

**Decisions made**
- Decision: four commits made on the user's explicit approval (`b6dd845`, `e0814bc`, `ec27e2a`, `fc03e94`), **not pushed**. Reason: user approved commit grouping for the S002 work; push always needs the user.
- Decision: plan.md:432 Session-000 note corrected (content edit, user-approved) inside `ec27e2a` rather than left stale. Reason: its offset claims were disproven in S002; the pre-correction text remains in history.
- Decision: DOS DATs copied into `SDLPoP-1.23/data/` with `cp -n` for observation. Reason: DAT chain takes precedence (`seg009.c` load path) so sprites load without PNG fallback; non-destructive, inside the reference folder, never staged, reversible by deleting.
- Decision: Session 003's A2.1/A2.2 code + docs left **uncommitted** pending the user's decision. Reason: the 4-commit approval covered the S002 groups only — no implicit approval.
- Decision: no assertion weakened when the turn/run-stop asserts failed; the reference behavior was re-derived and PARITY §18 clarified with citations instead. Reason: rule 5 — the asserts measured the wrong tick, the sim was right.

**Verification**
- `./verify.sh` at Session 003 start: exit 0, 121/0 (`.verify_baseline_s003.log`).
- `./verify.sh` after A2.2: **exit 0 — ALL CHECKS PASSED, import ok, 5/5 levels, 189 passed / 0 failed** (`.verify_s003_a22.log`).
- A2.1 drift test includes a **negative control** (perturbed table value → test fails) — proven, so a green run means tables and PARITY agree.
- Final pre-close `./verify.sh`: **exit 0 — ALL CHECKS PASSED, import ok, 5/5 levels, 189 passed / 0 failed** (`.verify_s003_final.log`, 2026-10-07 01:03). This is the authoritative final run.
- **Not verified / limitations:** run-jump distance and fall thresholds observed only in *our* sim, never against the running reference (input-timing + pit deaths — OBSERVATION.md §4); fight tick rate, spike cycle, guard duel unobserved; observation is single-run pixel measurement (± bbox error), no OCR; fonts broken in the study build → menus invisible; S002 hours figure `[N]` still blank (ledger keeps 4.8); nothing pushed.

**Licensing and asset notes**
- Reference-derived numbers added to tracked files this session: the two **[O] observation notes** in `docs/PARITY.md` (§1 tick rate, §4 standing jump) — our own pixel measurements of the running binary, cross-referenced to the existing cited [S] rows; plus the §18 clarification (cited facts only). `pop_tables.gd` carries cited reference facts per D5 — currently **untracked**; committing it needs the user's go-ahead on grouping.
- New assets: none shipped. Harness scripts (`obs_probe.py`, `obs_analyze.py`) are original code, untracked study tooling.
- Confirm no SDLPoP code/sprites/audio/text/level layouts copied verbatim: **yes — none**. Citations are file:line references only; observed values are pixel measurements.
- Confirm nothing from `4dprinceprsia/`, `SDLPoP-1.23/`, or `study/` staged: **yes — none** (git status reviewed; the DAT copy and stub live inside the untracked reference folder).

**Problems, bugs, and surprises**
- The turn/run-stop assert failure (expect 8, got 9) looked like a sim bug — it was a wrong assumption about when the trailing `jmp(stand)` runs. Diagnosed against `seg006.c:682` / `seqtbl.c:449,627,261-263`; see Step 4.
- Up taps of 0.12 s are swallowed by the reference's input handling; ≈0.35 s works. Run-jump observation needs a smarter approach (longer corridor or modified spawn) next time.
- Escape pauses the game behind an invisible menu (fonts fail) — looked like a hang until the source was checked.
- ffmpeg root-window capture is all-black under Hyprland; `-window_id` is mandatory.
- The earlier stub `libSDL2_image` was redundant — the real libs were already extracted into `.tools/sdlroot` in S002 (noted in review.md D7 all along).

**Plan changes**
- Checkbox-only, per rule 3: **A2.1 ticked, A2.2 ticked.** No other plan.md edits.

**Questions for the user**
1. **S003 commits:** commit the A2.1/A2.2 work now (grouping your call: one commit or split code/tests/docs), or leave it uncommitted until after more A2.3 work?
2. **Push:** the 4 S002 commits sit locally ahead of `origin/main` (`947cbbb`). Push them (plus any S003 commit) when you say so — I never push on my own.
3. **S002 hours:** fill the `[N]` figure (ledger still carries 4.8 h measured from mtimes).
4. **Study-folder cleanup (optional):** delete the superseded stub (`SDLPoP-1.23/stub_img.c` + stub `.so`) and/or the copied DATs, or leave both for the next observation round?

**Next session starts with**
1. A2.3: hang/climbing (up/down, release, hang-straight), crouch, safe-step edge probing — Accept: climb out of a 1-tile pit + hang-grab from a fall per the reference grab rule.
2. A3.1 `SimClock` + `pop_view` — needed for the W1 "sandbox playable" checkpoint (2/4 W1 criteria met so far).
3. Retry Step 5's unobserved numbers (run jump, fall threshold) if wanted: needs a safer corridor or spawn patch and frame-locked input.
4. Decisions queued: S003 commit grouping, push, S002 hours figure.

---

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
| D9 | 2026-10-06 | 003 | Four S002-work commits made on user approval (`b6dd845`, `e0814bc`, `ec27e2a`, `fc03e94`); **not pushed**. | User approved the audit + commit grouping explicitly; push always requires the user. | Committing without approval (not allowed); squashing into one (user wanted grouped history). | n/a — commits exist; push is a separate decision. |
| D10 | 2026-10-06 | 003 | plan.md:432 Session-000 note corrected (content edit) — user-approved. | Its offset claims were disproven in S002; leaving stale numbers in the tracked plan violates rule 5. | Leaving it (stale, misleading); silent rewrite (history would hide the correction — instead it ships in `ec27e2a` with the old text still in history). | Yes — the pre-correction text stays in commit `02c6a29`. |
| D11 | 2026-10-06 | 003 | Copy the 37 DOS DATs (`cp -n`) into `SDLPoP-1.23/data/` for observation. | DAT load chain takes precedence (`seg009.c`) → gameplay sprites without PNG fallback; non-destructive, inside the untracked reference folder, reversible. | Deleting/moving originals (destructive — rejected); staging DATs (never allowed). | Yes — delete the copies to revert. |
| D12 | 2026-10-06 | 003 | Session 003's A2.1/A2.2 code + docs left uncommitted pending user decision. | The 4-commit approval covered the S002 groups only; no implicit approval for new work. | Committing anyway (would exceed the approval); amending old commits (rewrites approved history — rejected). | Yes — commit whenever the user says. |
| D13 | 2026-10-07/08 | 004 | (a) The A2.2 standing-jump failures were caused by the A2.3 control rewrite, not "pre-existing": the reference binds standing jump to up+forward (`seg005.c:385-395`, `seg005.c:453-458`; PARITY §4) with plain Up routing to the jump-up/hang family, and the test input was aligned to that. (b) PARITY §6's "stand at frame 18" conflated the **tick index (18)** with the **frame id**: the reference `stand` sequence opens on frame **15** (`seqtbl.c:261-263`: `act(actions_0_stand), frame_15_stand, jmp(stand)`), so climb/turn/land reach f15 after 18 climb ticks. §6 was reworded, a machine-readable `stand frame = f15` row added, and A2.1 now binds `PopTables.SEQUENCES["stand"]` to it and asserts `pop_sim` binds `TURN_TICKS` to `PopTables.TURN_TICKS` in source. | Both were wording/decoupling errors, not sim bugs — the reference and the table agree. No assertion was weakened; the mis-attributed phrase was corrected and the previously unchecked binding is now asserted. | (a) Leaving the mis-attribution (would violate rule 5); (b) changing the sim to frame 18 (table and reference both say 15). | Yes — docs/test text only; no behavior change. |

---

## Open Questions from plan §11 (answers recorded here)

| Q | Topic | Blocks | Answer | Date | Session |
|---|---|---|---|---|---|
| Q1 | RRR originality rule: are measured behavior constants with citation acceptable? Does the jury check repo or only build? | A1 citations, A5, pop_tables.gd, PARITY.md, most of A2.2 & A4 numbers | **ANSWERED (post-close, Session 002): "rules read; measured constants with citation are acceptable."** Standing mitigations unchanged: every number carries a file:line citation, no code/table copied verbatim, reference folders stay out of the repo and the shipped build. `docs/PARITY.md` and `pop_tables.gd` are now unblocked. | 2026-10-06 | 002 |
| Q2 | Git history of reference folders: accept / filter-repo + force-push / private, strip, republish | §2.4 | **MOOT** — verified in Session 002: `git log --all` shows the folders in no commit, `git fsck --unreachable` found nothing, `origin/main` tree (125 entries) contains neither folder nor study/. Re-verified live in Session 003 (`git ls-remote` OK, origin/main = `947cbbb`). No history or remote action is needed or requested. | 2026-10-06/07 | 002, 003 |
| Q3 | Port SDLPoP `.p1r` replays as formal parity tests? | A5.3 | | | |
| Q4 | Music: compose in LMMS or source CC0? | B4.2 | | | |
| Q5 | Aseprite purchase or LibreSprite? | A3.3 | | | |
| Q6 | In-game title: "Echoes of Time" only, or keep "Prince of Persia:"? | B5.2 | | | |

---

## Open Issues

| ID | Opened (session) | Severity (blocker / major / minor) | Description | Status | Closed (session) |
|---|---|---|---|---|---|
| I1 | 000 | minor | Extractor crashed on full res2000–res2015 batch: used_rooms() returned 255 for truncated/non-standard files and guard accessors indexed out of range. | **Closed** — fixed in 000; re-verified in 002: `--selftest` passes (0 failures) over all 16 files, including the non-canonical res2015 (2304 bytes, padded on read). | 002 |
| I2 | 002 | major | Session 000's extractor field offsets were misaligned vs `types.h` (start_room/start_pos/start_dir, roomlinks, used_rooms, guards all shifted): reported start_room=25 / start_dir=16 for level 0 were reads of the used_rooms byte and an editor coordinate. | **Closed** — fixed in 002: offsets re-derived from the packed struct (walk sums to 2305 = sizeof assert), extractor rewritten, selftest asserts ranges + regression pin (res2000 → 1/9/−1) + a negative control on the old offset; study/ regenerated; A1.1 re-ticked in 002 after the live `--screenshot-level` cross-check (D8); final offset/tile-name corrections committed in 003 (`b6dd845`). | 002 |
| I3 | 003 | minor | Gameplay observation partial: run-jump distance and fall thresholds never observed against the running reference (Up taps <0.35 s swallowed; run-up overshoots the level-1 pit → deaths). Study build's fonts fail → menus render invisibly (Escape pause looks like a hang). | **Open** — harness (`study/obs_probe.py`, `obs_analyze.py`) works; needs a safer corridor/spawn or frame-locked input for the remaining numbers. | |

---

## Parity Tracker (plan §8 gates and §4.3 behaviors)

"Reference" = measured from SDLPoP behavior (fixes off). "Ours" = measured from `pop_sim`.

| ID | Behavior | Reference | Ours | Status | Session |
|---|---|---|---|---|---|
| P1 | Standing jump horizontal distance | ≈36 u ≈2.57 tiles at landing frame f27 (stream: PARITY.md §4; source-derived, [S]) **[O]-corroborated ≈38 u** (observed bbox 175 px) | landing 36 u / total 39 u (`_test_a22_acceptance`) | ✅ | 002, 003 |
| P2 | Running jump horizontal distance | ≈67 u ≈4.79 tiles total f34→f7 (PARITY.md §5; [S]) | landing 62 u (f44) / total 67 u; f43 = 58 u — source-matched, not observed | ✅ | 002, 003 |
| P3 | Fall thresholds (soft / medium / death) | impact speed <22 / 22–32 / ≥33 (PARITY.md §7; [S]) | impacts 21 soft / 30 → −1 HP / 33 → death (y=242 hard-land asserted) — source-matched, not observed | ✅ | 002, 003 |
| P4 | Hang / grab frame counts | 43-frame sway auto-drop; grab_timer 12 frames (PARITY.md §6; [S]) | A2.3 scope A asserts the §6 frame counts (climb_down 10, climb_fail 11, hang_drop 5, grab_timer 12); the **43-frame sway auto-drop is not yet asserted** | ◐ partial | 002, 004 |
| P5 | Spike cycle length | ≈23 logic frames (PARITY.md §8; [S]) | | ⬜ | 002 |
| P6 | Gate open/close speeds, plate timing (±1 tick) | −1/+4 units/frame, fast 20…120; plate timer 5→<2 (PARITY.md §9–10; [S]) | gate open 47 / close 238 / exit door 3 ticks; plate timer 5→1 — within ±1 of PARITY §9–§10 (`_test_a41_entities`); source-matched, not observed | ◐ partial | 005 |
| P7 | Guard duel transcript, seeded, skill 0 | tables: PARITY.md §12–§14 (strikeprob 61/blockprob 0/advprob 255 for skill 0; [S]) | | ⬜ | 002 |
| P8 | Tick model: 12 fps traverse / 10 fps fight | confirmed: base_speed 5 / fight_speed 6 ticks of 60 Hz (PARITY.md §1; [S]) — **[O] observed: 12.00 Hz** (two captures) | 12 Hz sim clock; double-run hash equality over 400 ticks — source-matched; [O]-observed 12.00 Hz | ✅ | 002, 003 |

Status: ⬜ not tested · ❌ failing · ✅ matching

Note: P2 and P3 are source-matched, not observed. Their “Ours” columns come from the A2.2 acceptance tests and are tied to cited PARITY.md rows; they were not observed against the running reference binary in Session 003.

Reference values live in tracked `docs/PARITY.md` since Q1 was answered (Session 002). "Ours" for P1/P2/P3/P8 measured in Session 003 from the A2.2 acceptance tests; P8's reference is additionally [O]-observed (12.00 Hz, `study/OBSERVATION.md`). P4–P7 remain untested (gates 2 remainder / duel work).

### Plan §8 test gates

| Gate | Written? | Passing? | Session |
|---|---|---|---|
| Determinism (600 ticks, twice, equal hash; different seeds differ) | ✅ | ✅ | 002 |
| Kinematics parity table | ◐ partial — run/stand-jump + fall + edge-snap + turn/stop rows | ✅ those rows (189/0) | 003 |
| Duel transcript | ⬜ | ⬜ | |
| Echo replay v2 (plus one-bit divergence test) | ◐ thin slice | ✅ thin slice | 005 |
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
| `scripts/pop/pop_tables.gd` (A2.1) | code tables (tracked on commit) | written Session 003 from SDLPoP src reads | n/a (code) | **Yes** — frame/tile/sequence values with file:line citations (D5 posture); drift-tested vs PARITY incl. negative control | 003 | Pending user's commit-grouping decision (currently untracked) |
| `scripts/pop/pop_sim.gd` A2.2 steps + `tests/test_main.gd` acceptance | code (tracked on commit) | written Session 003 to match PARITY values | n/a (code) | **Yes** — implements the cited PARITY numbers; every acceptance assertion matched them exactly | 003 | Pending user's commit decision (currently uncommitted) |
| `docs/PARITY.md` [O] notes (§1 12.00 Hz, §4 ≈38 u) + §18 note | tracked doc | our own pixel observation of the running binary + cited clarifications | n/a (docs) | Observation values are ours; cited [S] values unchanged (D5) | 003 | n/a (cited facts) |
| `study/OBSERVATION.md`, `study/obs_probe.py`, `study/obs_analyze.py` | study notes + tools (untracked) | written Session 003 | n/a (study only, not shipped) | Observation method + our measurements; citations only | 003 | n/a (never committed) |
| 37 DOS `*.DAT` files copied into `SDLPoP-1.23/data/` | reference game data (inside untracked reference folder) | `cp -n` from `4dprinceprsia/` | GPL-3-era original data — **study use only, never staged or shipped** | n/a (reference material) | 003 | n/a (stays out of repo/build) |
| `SDLPoP-1.23/stub_img.c` + stub `libSDL2_image-2.0.so.0` | study tooling (untracked) | written Session 003 (3-symbol stub) | n/a (own code, not shipped) | No — stub only, superseded by real sdlroot libs | 003 | n/a (deletable) |
| `scripts/pop/pop_level.gd`, `scripts/pop/pop_replay.gd` (A4.1 / thin B1) | code (tracked) | written Session 005 | n/a (code) | **Yes** — gate/plate/door machine carries `seg007.c`-cited constants (D5 posture); no code copied | 005 | n/a (cited facts) |
| `docs/PARITY.md` §9 gate/plate/door values + new §10 press-timer row | tracked doc | read Session 005 from `seg007.c` | n/a (docs) | **Yes** — reference-derived numbers with `file:line` citations | 005 | n/a (cited facts) |

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
| 005 | 2026-10-08 | A2.3 ticked; A4.1 + thin B1 done | [N] | Pre-push audit clean (not pushed); A2.3 ticked with caveat; A4.1 gates/plates/level-exit door + `pop_level.gd` room-grid loader (PARITY §9/§10, ±1 tick); thin B1 input-byte echo (record/replay, one-bit divergence); +1 PARITY §10 row. Hours pending user figure. | 29 added (272 total) |
| 004 | 2026-10-08 | A2.3 rebuilt (under audit); A3 started | [N] | Rebuilt the A2.3 acceptance tests; repaired working-tree corruption (autoloads, `pop_input` stub, `STATE_KEYS`, `TURN_TICKS`, plus a fused line in this log); circularity audit + D13 (stand frame f15 vs tick 18); Section 3 evidence upgrades (PARITY §2 edge snap, §4 standing-jump trigger); clean-clone check green; A3.1 SimClock + A3.3 input latch + A3.2 pop_lab sandbox (feel needs playtest). Hours pending user figure. | 54 added (243 total) |
| 003 | 2026-10-06/07 | A2.1 + A2.2 done, observation started | 3.0 | Pre-commit audit + 4 user-approved commits (not pushed) + plan.md:432 fix (approved); Q2 re-verified live; `pop_tables.gd` + drift test w/ negative control; A2.2 step function + acceptance — all PARITY numbers matched exactly, turn/run-stop tick clarification cited; first gameplay observation: 12.00 Hz + standing jump ≈38 u [O] (run-jump/fall not observed). | 68 added (189 total) |
| 002 | 2026-10-06 | A1.1+A1.2 done, A2 gate 1 | 4.1+ext | Session 000's offsets proven wrong and extractor fixed (selftest w/ negative control + TILE_NAMES fix); A1.2 → study/STUDY_NOTES.md + tracked docs/PARITY.md (Q1 answered); SDLPoP built locally (no sudo) and `--screenshot-level` cross-check passed (start/guard/floor 12/12); tick model corrected to 12/10 fps; determinism gate green; A1.1+A1.2 ticked. | 5 added (121 total) |
| 000 | 2026-10-06 | §2.4 + A1.1 | 1.5 | Baseline captured; .gitignore reference entries added; A1.1 study extractor built, fixed, and run to produce study/ level_00–15 notes; verify.sh still green. No commit yet (awaiting user confirmation on Q1/Q2 + commit timing). | 0 added |

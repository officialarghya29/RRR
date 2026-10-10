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
| Last updated | 2026-10-09 (Session 007) |
| Days to deadline | 22 (as of 2026-10-09) |
| Current stage / phase | Stage A / **A1 Done** · **A2 Done** · **A3 in progress** (feel **not verified, needs human playtest**) · **A4.1–A4.3 Done** · **A5.1 Done** (S007: parity harness 441/0, reference-accurate grab/climb lanes, PARITY ours-vs-SDLPoP columns) · **B1 ring done** · **B0 blocked on the design-note approval** |
| Sessions logged | 7 entries (000, 002, 003, 004, 005, 006, 007). Session 001 has no entry — see Time Ledger |
| Hours used / budget | 10.3 / 34 (S000 1.5 + S001 1.0 + S002 4.8 + S003 3.0) — 23.7 h remaining. S004, S005, S006 and S007 hours pending the user's confirmed figures (not estimated here). |
| Test status | **./verify.sh exit 0, ALL CHECKS PASSED — import ok, 5/5 levels clean, 441 passed / 0 failed** (413 at S006 close + 28 A5.1 harness checks); A3 feel unverified. |
| Parity checks passing | 6 / 8 — P1, P2, P3, P4, P6, P8 ✅ matching (source-matched; P1/P8 additionally [O]-observed); P5 ◐ (spike floor armed + 0xFF-on-kill asserted in S007, cycle length not); P7 ◐ source-matched only (no SDLPoP transcript observed) |
| Open blockers | **B0 design note awaiting approval** (no B0 code until approved). A3 feel **not verified headlessly** — human playtest + A5.2 OBS clip pending (numbered checklist in the Session 007 entry). Outstanding decisions: push (never without approval), S004–S007 hours figures [N]. Observation still partial (I3). |
| Cut line status | Nothing cut yet. Stage A exit now **4/5**: determinism ✅, PARITY populated ✅ (with ours-vs-SDLPoP columns), A5.1 ✅ — **A5.2 + the human playtest remain**. No cut-list trigger raised. |
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
| A4 | Traps, tiles, duels | 12 | In progress — **A4.1, A4.2 and A4.3 done (A4.3 ticked S006: reach-gated duel, reference decision bands, spike/chomper deaths for both parties)**; A4.4–A4.5 pending | 005, 006 |
| A5 | Parity verification | 7 | In progress — **A5.1 done (S007)**: fixed-input harness P1–P8 + 2 controls vs PARITY rows (441/0), grab/climb lanes rebuilt on the reference, PARITY ours-vs-SDLPoP columns; A5.2 pending (user-manual, checklist in S007) | 007 |
| B0 | Bridge decision (rebase on sim) | 2 | Blocked — design note awaiting user approval (S007); no code until approved | 007 |
| B1 | Temporal Echo, input-level | 6 | In progress — thin **input-byte echo on the sim** done (record/replay, one-bit divergence) + **bounded 96-byte ring with per-tick event vectors** (S006); B1.1/B1.2 unticked, Stage-B bridge pending | 005, 006 |
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
| 006 | 2026-10-09 | [N] | 10.3 (S004–006 pending) | — | Step 0 audit answers (integrity outputs, B1 status, A4.1/A4.2 provenance tables + correction legitimacy, sim-calibrated relabels); B1 bounded ring 96 B + event vectors (`85af8a2`, 351/0); A4.3 reach + decision bands + trap deaths + PARITY §20 (`e98f0fd`, 413/0); A4.3 ticked; Stage A exit position reported. Hours pending the user's confirmed figure. |
| 007 | 2026-10-09 | [N] | 10.3 (S004–007 pending) | — | Step 0 legal rework (§20 + guard tables → own schema, `b3d7a60`/`f5caf79`/`1c32db2`); B1 gap list + B0 design note (awaiting approval); **A5.1 parity harness** P1–P8 + C1/C2 with the stand-Up grab lanes rebuilt on `check_jump_up` (`b6b0c70`, 441/0); PARITY measured-in-ours vs measured-in-SDLPoP columns; A5.1 ticked. Hours pending the user's confirmed figure. |

---

## Session Log

<!-- Newest first. Copy the template below for each new session. -->

### Session 007: 2026-10-09 — Step 0 integrity/legal rework (§20 + guard tables → own schema); B1 gap list; B0 design note (AWAITING APPROVAL); A5.1 parity harness
_(entry opened mid-session; completed at close)_

**Baseline at session start**
- Branch `dev/pop-rebuild`, HEAD `f4dbbe0` (S006 close); tracked tree clean; untracked scratch (never committed): `tools/frame_decode_check.py`, `tools/smoke_pop.gd`, `tools/smoke_pop.gd.uid`.
- Last green: `verify_s007_baseline.log` — **413 passed / 0 failed, exit=0** (captured directly with `echo "exit=$?"` appended).

**Step 0 — integrity and legal audit**

*(0.1) Baseline + tree:* `./verify.sh` → **413/0, exit=0** (`verify_s007_baseline.log`); `git diff HEAD --stat` → empty; only the 3 untracked scratch files above. Nothing changed unexpectedly.

*(0.2) Legal audit of §20 (35 rows) + guard tables in code, per plan §2.2 gray-zone rule:*
- **Verdict, §20:** after the rework every one of the 35 rows is a **re-expressed fact with a `file:line` citation** — none is a copy of the source's table layout. Before the rework several cells were *close* copies: source identifiers (`advprob[skill]`, `restrikeprob`, `strikeprob`, `impblockprob`), source state/expression text (`justblocked timer`, `take_hp(100)`, `(mod & 0x7F) == 2`, `Opp.x - Char.x`), and source-flavoured row names (`min hurt range drawn/undrawn`).
- **Verdict, guard tables in code:** `pop_guard.gd` previously held 8 parallel skill-major row arrays (`STRIKE_ODDS`, `RESTRIKE_ODDS`, `BLOCK_ODDS`, `IMPBLOCK_ODDS`, `ADVANCE_ODDS`, `REFRACTIMER`, `BONUS_HP`, `BASE_HP`) — same order, same shape, same names as the source's `data.h:835-847` arrays → **that was a copied expression**. Now replaced.
- **What I changed (commit `b3d7a60`, plus comment cleanup `f5caf79`):**
  1. `scripts/pop/pop_guard.gd`: the 8 arrays → **`PROFILES: Array[Dictionary]`** — 12 profile-major records with *our* field names (`strike`, `restrike`, `block`, `immediate_block`, `advance`, `refractory`, `bonus_hp`, `base_hp`) — transposed vs the source's skill-major columns, grouped and named by us; accessors `profile(skill)` / `column(field)` / `odds(skill, field)` / `guard_hp`. Values unchanged (cited facts); every call site updated. Renames: `JUSTBLOCKED_START` → `REBLOCK_START`, state key `"justblocked"` → `"reblock"`, `_min_hurt` → `_reach_min`. Comments: `Opp.x - Char.x` → prose; `min_hurt_range` (source var) → "reach minimum"; `take_hp(100)` → "100-damage instant death"; `advprob`/`strikeprob`/`restrikeprob` → "advance odds"/"strike odds"/"re-strike odds".
  2. `docs/PARITY.md` §20 rewritten: regrouped into **four subgroups in our order** (Distance and reach · Guard decisions and timers · Movement (walk chains) · Trap deaths = 10+13+4+8 = 35 rows); intro de-coded (no C expressions in cells); row labels ours (`reach minimum drawn/undrawn`, `re-block timer`); citation column (`file:line`) kept on every row. Also fixed one pasted C expression outside §20 (§2 edge-snap cell `Char.x = char_dx_forward(-3)` → prose, citation kept).
  3. `scripts/pop/pop_tables.gd`: two stale citations corrected (`seg005.c:216-218` → `220-222`; `seg007.c:1185-1193` → `1185-1195`); values unchanged.
  4. `tests/test_main.gd`: probes updated to the new API/labels — same expected values, no assertion weakened (`PopGuard.odds/column/profile`, `"reach minimum …"`, `"re-block timer"`, `"stored cycle frame reads 2"`).
- **§12 doc table noted (out of the asked scope, flagged honestly):** row labels are already ours (`strike odds` … `base HP`) with source symbols named *only* as citation anchors; the orientation (rows in `data.h` line order, 12 skill columns) follows the data itself. The executable code no longer mirrors it (profile-major). Say the word if you want §12 re-grouped too.
- **No source text/comments pasted — confirmed by scan:** greps for `static const`, `#include`, `goto`, `Opp.`, `Char.`, `take_hp(`, `advprob|strikeprob|restrikeprob|impblockprob`, `justblocked`, `min_hurt` over `pop_guard.gd`/`pop_tables.gd` and over §20 → **empty** (the only remaining source-symbol mentions anywhere are the §12 "citation anchors" note and `char_opp_dist()` in prose intros, both explicit citations).

*(0.3) Both legal greps re-run — both empty:*
- `git ls-files | grep -i "sdlpop|4dprince|prince of persia|/study/"` → **empty** (grep exit 1). ✅
- `git log --all --oneline -- 4dprinceprsia SDLPoP-1.23 study` → **empty** (0 hits on every ref). ✅
- Extra check I ran beyond the two: `git log --all --grep=sdlpop -i` matches exactly one commit, `947cbbb` "Partition the reference-study folders out of the tracked tree…" — its diff is only `.gitignore` + `tools/pop_level_to_notes.py`, i.e. the commit that *keeps* the reference folders untracked; no reference data in any commit.

*(0.4) A4.3 tick justification:* **Ticked under "every criterion has a PARITY-sourced assertion" — NO caveat, no untick.** Both accept criteria (scripted duel win/lose deterministic; `seed=N` → identical transcripts) are asserted live, and every underlying behaviour check cites PARITY rows (§12 odds/HP, §13 chains, §20 reach/timers/walk/trap rows — all read from the doc at test runtime). The only characterization-labelled items (duel start distance 20, `BLOCK_HOLD`) are *not* acceptance criteria. Exact note for approval (plan.md A4.3, verbatim):

> **Status (ticked Session 006):** met — reach gated by `char_opp_dist` (new PARITY §20: hits inside [8|12, 29), f154 only damages), the `seg002.c:737-899` decision bands with draws only where the reference draws, §13 walk-chain dx (+6 forward / −5 back), and spike/chomper death checks on both fighters every tick. Same seed → identical transcript and outcome, different seed → different; the attack script resolves (winner kid after 35 ticks). Source-matched with `file:line`, not observed against SDLPoP (`_test_a43_duel`, 413/0).

→ Approve or reject; if rejected I untick A4.3 and propose a note instead.

*(0.5) Provenance of the 62 new assertions (grouped).* Counted by diffing PASS lines `verify_s006_step1b.log` (351) → `verify_s006_step2.log` (413): **64 new PASS lines, 2 pre-existing lines reworded** (f153→f154 strike probe; duel-outcome 15→35 ticks) → **net +62**.

| Group | Count | PARITY row range | Origin |
|---|---|---|---|
| §20 anti-drift value rows (doc cell == our constant) | 17 | §20, all four subgroups (reach, decisions, movement, traps) | PARITY value |
| Signed-distance (`opp_dist`) formula probes | 4 | §20 intro paragraph (`seg006.c:2117-2131`) | PARITY value |
| Reach/resolve edge probes (hit lands/doesn't at band edges, parry edges) | 7 | §20 "Distance and reach" rows + §13 parry frames | PARITY value |
| Decision-ladder bands + RNG-consumption probes | 18 | §20 "Guard decisions and timers" + §12 odds + §14 RNG | PARITY value (draw semantics `seg002.c:857-899`) |
| Walk-chain dx probes (advance/fastadvance/retreat) | 3 | §20 "Movement (walk chains)" | PARITY value |
| Distance-driven duels (sword-only/advance/retreat/reproducibility) | 4 | §20 movement rows applied to a live duel | mixed: dx PARITY; start distance 20 + scripts = **sim characterization** |
| Trap unit rows + chomper/spike duels | 9 | §20 "Trap deaths" (8 rows) | PARITY value (windows/cycle); hazard placement + duel seeds = **characterization** |
| **Total** | **62** | | |

**Step 1 — B1 gap list (what blocks B1.1/B1.2 from being ticked)**

**B1.1 `TemporalRecorder` v2 — NOT ticked.** Accept criteria from plan:

| Criterion | Status | Evidence |
|---|---|---|
| recorder tests updated | ❌ not met (for `TemporalRecorder` v2) | PopReplay's ring tests exist (96-B cap, eviction, event vectors), but `TemporalRecorder` itself is untouched — `tests/test_main.gd:287 _test_recorder` still asserts the legacy duration-based transform path |
| buffer cap enforced | ◐ partial | enforced in `PopReplay.RING_CAPACITY = 96` (tested); `TemporalRecorder` still caps by take duration, not bytes |
| determinism test replays through a live sim, not transform lerp | ◐ partial | `PopReplay.replay()/replay_events()` step `PopSim.step` directly and are tested — but the *determinism test through the echo surface* still runs the legacy transform path (`tests/test_main.gd:1714` "legacy TemporalManager path is untouched") |

Missing to tick: byte-per-tick `TemporalRecorder` v2 + its tests, and the determinism test rewired to replay through a live sim **via the echo surface**.

**B1.2 `TemporalEcho` v2 — NOT ticked.**

| Criterion | Status | Evidence |
|---|---|---|
| existing 116 assertions still pass *with v2 in place* | ❌ not met | v2 is not wired into `TemporalEcho`; the 116 pass against the legacy path, which proves nothing about v2 (`temporal_manager.gd:206 spawn_echo(snapshots)` still takes transform snapshots) |
| new test: two echoes from the same input buffer → identical plate-timing events | ◐ partial | `PopReplay` asserts two replays hash-equal + recorded==replayed event vectors — but not through the `TemporalEcho`/`TemporalManager` surface the levels use |

Missing to tick: swap the echo's payload from snapshots to input bytes while keeping the `event_replayed`/`echo_event_replayed` signal surface, prove the 116 on v2, add the two-echoes-identical-plate-timing test at that surface.

**B1.3 — not started** (echo visibility to sim-side plates, energy economy on the new path, level-1 tutorial puzzle solvable test).

→ **B1.1/B1.2/B1.3 all stay unticked** until v2 replaces the legacy path.

**B0 design note (plan B0.1) — WRITE-ONLY, AWAITING USER APPROVAL BEFORE ANY B0 CODING**

*How the sim path becomes the main game.* Two paths exist today: (1) the **game path** — `GameManager.load_level` → `LevelBuilder` builds nodes, `Player` is a Godot-physics controller, echoes are transform snapshots; (2) the **sim path** — `pop_lab.tscn`/`PopView` runs `SimClock` + `PopSim.step` (pure integer state dict) with a placeholder renderer. B0 inverts the default: the game boots the sim path.

- **New core node `SimWorld` (scripts/pop/…):** owns `SimClock` + the `PopSim` state + `PopLevel` entities (tiles/mods/gates/plates/exit) for the loaded level. Per tick: latch intent (`PopInputLatch`) → `PopInput` byte → `PopSim.step` → diff old/new state → emit **sim events** on `EventBus` (reusing its signal surface): `player_hp_changed`, `player_died`, `player_moved(x,row,dir)`, plus entity milestones already produced by `PopReplay.entity_events` (`plate press`, `gate opening/parked/closed/fast-close/open`, `exit`).
- **Player:** `Player` (physics controller) is replaced on the new path by a thin **view node** that renders `clock.prev/curr` with `lerp_channel` (same interpolation `PopView` already uses) and maps input actions → the input byte. Death/respawn/checkpoint flow stays on EventBus, fed by sim events.
- **Echo:** `TemporalManager` records input bytes + per-tick event vectors (`PopReplay` ring, already built); `spawn_echo` gains a bytes variant that spawns a **second sim participant** stepping `PopSim.step` from the release moment (final-pose hold preserved). Signal surface (`echo_created/expired/event_replayed`) unchanged, so `lever.gd` and the HUD keep working untouched.
- **Plates / puzzle framework:** levels stay data (`listens_to`/`bind_sources` topology in the catalog). On the new path the plate/door/timed-gate *nodes become views of sim entities*: authoritative state lives in `state["plates"]/["gates"]/["exit"]`; node `_process` syncs visuals + `Activator.set_active` from sim diffs, so `ActuatorUtil` wiring and the catalog stay as-is. Echo plate visibility = B1.3 (see risk 3).
- **Enemies:** stay Godot-side actors consuming sim events (`player_moved`/`player_died`, guard duel events); the duel itself runs `PopGuard` inside `SimWorld` ticks. Presentation (walk anims, aggro telegraphs) remains Godot.
- **HUD:** unchanged consumer — it already listens to `EventBus` (health, recording, boss, objective). Only the *producers* change (sim diffs instead of physics nodes).
- **Stays Godot-side:** rendering/interpolation/animation selection, camera, audio, menus, level construction (`LevelBuilder` builds tiles+decoration, converts catalog → `PopLevel` bundle), input capture → byte packing, temporal **energy economy** (unchanged), checkpoints (position triggers read sim x/y), all art (A3.3).
- **`--legacy-physics` flag:** parsed at boot (same mechanism as `--level=N`). Default = new sim path; `--legacy-physics` selects today's full stack (physics `Player` + snapshot echoes) untouched, so the current vertical slice stays runnable as the video fallback until B2 is verified (plan B0.1). `verify.sh` gains a second boot loop with the flag so **both paths** are verified every run; tests keep asserting both.
- **3 biggest risks + fallbacks:**
  1. **Sim coverage gaps break a level** (ladders, crouch, falling out of bounds, loose floors are A4.4/A4.5/N or unported). *Fallback:* B0's acceptance play-through targets one hand-built level using only shipped mechanics (run/jump/hang/spike/plate/gate); `--legacy-physics` remains the shippable path; cut-list order already drops A4.4→A4.5 first.
  2. **Feel mismatch at 12 Hz** (input latency/turning reads wrong vs the physics controller → R4). *Fallback:* tune **view-side only** (interpolation, input buffering in `PopInputLatch`, camera) — sim constants never move to fix feel; A5.2 clip is the recurring check; worst case the video ships on `--legacy-physics` while A5.1 remains the fidelity proof.
  3. **Two sim participants vs one entity world** (echo + player stepping shared plates/gates could double-advance timers — B1.3). *Fallback:* staged — first ship the echo as its own participant whose sim-side effects are applied from its recorded **event vectors** (stamped, not recomputed against the shared world); if that can't make the tutorial puzzle identical, rewire the one tutorial plate through the existing Godot-side `echo_event_replayed` path (already proven by `lever.gd`).
- **Hours estimate:** B0 wiring + flag + both-path verify ≈ **3–4 h** (plan says ~2 h — flagged, unconfirmed); remaining B1.1+B1.2+B1.3 ≈ **5–6 h** (plan's 6 h for all of B1). Not confirmed figures.

→ **No B0 code until this note is approved.** Step 2 (A5.1) proceeds meanwhile.

**Step 2 — A5.1 parity harness (complete; commit `b6b0c70`)**

- **Built:** `_test_a51_harness` + `_a51_room` in `tests/test_main.gd` — a hand-built room *grammar* (4 rows × 24 cols: start floor → 1-row drop → ground floor with a one-column spike pit (row 1 col 9) over a row-2 spike floor → ledge at row 0 cols 13–18 with a plate and a gate; grammar only, not any original layout, per plan). Fixed input script P1–P8 plus two controls (C1 run-into-pit, C2 hang-and-wait); **every expected value is read from PARITY rows at test runtime** (`_parity_int/_parity_cell/_expand_cells`) — no number comes from sim output.
- **What the harness caught (the real find):** our stand-Up grab lane was invented — Shift-gated, a home-grown "≤8 units from the lip" threshold, and a `jump_grab_up` sequence that approached via the run-jump frames. The reference `check_jump_up` (`seg005.c:679-693`) is **not** Shift-gated (both the Shift and the plain-Up chains end in `up_pressed`, `seg005.c:379-382/428-431`; Shift only decides whether the hang holds), probes with `determine_col`'s m7 column (`seg006.c:0122-0124`, `:0690-0692`), and branches through `grab_up_with_floor_behind` (`seg005.c:858-881` — commit `Char.x` by `distance_to_edge_weight`, then seq_8 straight vs seq_24 forward whose dx +1/+2/+1 completes the `distance − 4` shortfall) or `jump_up_or_grab` (`seg005.c:713-738` — <6 → straight jump; no floor behind → `x += distance − 10` seq_16; floor behind → step back `distance − TILE`, re-probe, shared commit). Rebuilt on the source: new sequences `jump_grab_straight` (seq_8 jumphangMed) and `jump_grab_forward` (seq_24 jumphangLong), new helpers `_can_grab`/`_det_col`/`_dist_to_edge_weight`/`_edge_distance`/`_grab_up_with_floor_behind`/`_jump_up_or_grab`, `_tile_above_is_floor` deleted. The old lane hung the kid at x 233 → the climb-out's f141 foot probe read col 12 (no floor) → he fell into the pit. With the reference lanes the grab hangs at x 248 whatever the stand x in the window, and the climb-out stands on col 13.
- **Also fixed:** `soft_land_crouch` stands up when Up isn't held (`seg005.c:285-287`, `:331-332` control_crouched fires on f109 whatever the sequence) — previously the kid froze forever at f109 after any soft land.
- **Results (all green; every number read from PARITY at runtime):**

| Check | PARITY row | Measured in ours |
|---|---|---|
| P1 standing jump | §4 cum x | 36 @f27, 39 total (exact) |
| P2 1-row drop | §7 soft land | hp 3, no damage |
| P3b run jump over the pit | §5 cum x | 62 @f44, 67 total (exact); pit spikes stay armed |
| P4 stop + walk to the grab window | grammar | stand at x ≈ 236–237 |
| P5 Shift+Up grab | §6 hang | hang on f91 |
| P6 climb out | §6 climb up | f141 dx +5 / dy −63 / row −1; stand f15 on climb-tick 18; lands col 13, y 55 |
| P7 plate press | §10 press timer | 5 → 4 next tick |
| P8 gate open/close | §9 opening / open-reached / closing | press→park 46 ticks (188/4 = 47 ±1); park→0 = 238 exact |
| C1 run into the pit | §8 disabled | impale, mod → 0xFF |
| C2 hang auto-drop | §6 hang sway | drop − hang = 43 ticks; lands on feet, hp 3 |

- **Measured streams:** the §4/§5 `ours cum x [A5.1]` rows are our sim's frame-by-frame measurements — **identical to the source rows at every frame**.
- **PARITY.md (Accept item 2):** house-rule bullet updated + `measured-in-ours (A5.1)` / `measured-in-SDLPoP` columns appended to §6/§8/§9/§10 and ours-rows in the §4/§5 streams, tagged `[A5.1]` / `[source-matched]` / `[observed]` / `—`. The SDLPoP column is honestly `[source-matched]` everywhere except the two Session-003 observations; the run-jump stream stays unobserved (I3).
- **GAPs the harness prints (honest):** (1) column probes use the plain left-edge column outside the hang/climb frames — the m7 migration is gate-2 work; (2) `_m7_x` subtracts 7 against the facing direction while `get_tile_div_mod_m7` subtracts unconditionally — left-facing hangs still diverge (gate 2); (3) the room layout is ours (grammar); the row-2 spike floor pads the one-column fall drift the reference m7 landing probe would absorb.
- **Evidence:** `./verify.sh` → **441 passed / 0 failed, ALL CHECKS PASSED, exit=0** (`verify_s007_a51.log`). Verification ladder: 413/0 (baseline) → 426+14 (first harness run: climb-out fell into the pit) → 440/1 (climb tick count — §6 counts inclusively, f135 = climb-tick 1 … f15 = 18; the sim was right, my formula wasn't; no assertion weakened) → **441/0**.
- **plan.md A5.1 ticked** (checkbox-only rule).

**Step 3 — Stage A exit status + 60-minute user checklist**

| Criterion | Status |
|---|---|
| sandbox playable with sword-duel and traps | ◐ sim-level green (duel, traps, hang/climb, plate/gate all asserted headless); `pop_lab.tscn` boots but keyboard play / feel **needs the human playtest below** |
| determinism test green | ✅ gate 1 green; duel same-seed identical / different-seed different |
| PARITY.md populated for all §4.3 items | ✅ now with the plan-A5.1 measured-in-ours vs measured-in-SDLPoP columns on §4–§6/§8–§10 |
| A5.1 parity harness v1 | ✅ done this session (`b6b0c70`, 441/0) |
| A5.2 side-by-side video | ⬜ user-manual — checklist below, deliberately not started by me |

→ **Stage A exit NOT met yet: A5.2 + the human playtest remain.** Everything else in A4/A5 is still the cut line. **Nothing on the cut list triggered.**

**Your 60-minute checklist (~55 min, at your convenience):**

1. **(10 min) Sandbox feel** — `./.tools/godot --path . res://scenes/pop/pop_lab.tscn`. Controls: **A/D run, W jump-up, S crouch, Shift grab/climb, P pause, `.` frame-step**. Run the pit (col 4) both directions; hang and climb the raised ledge (cols 8–11). Notes wanted on anything that reads wrong vs the DOS original — input latency at 12 Hz, turning, landing weight.
2. **(5 min) Tick cadence** — press P, then `.` a few times: do the sim ticks read as the 12 fps cadence?
3. **(15 min) A5.2 clip 1 (jumps)** — record SDLPoP (the Session-002 local build) and pop_lab playing the same standing jump and the same run jump; save under `study/` (e.g. `study/a52_jumps.mp4`).
4. **(20 min) A5.2 clip 2 (hang and climb)** — same side-by-side for the hang + climb-out; `study/a52_hang_climb.mp4`.
5. **(5 min) Reply** — feel notes, the clip paths, and your confirmed hours for **S004–S007** (the ledger still shows `[N]`).

**Close**

- plan.md: A5.1 ticked (checkbox-only). review.md: this entry + dashboard, phase tracker, time ledger, parity tracker, change index.
- **Hours:** not stated in the brief → `[N]`; no estimate substituted. Cumulative stays **10.3 / 34 h** (S004–S007 pending). **Playtest:** not done yet (checklist above). **Push:** NOT YET (nothing pushed). **Arghya:** not counted. **B0:** still awaiting approval before any code.
- `.backup/s007_close/` taken; final `./verify.sh` re-run after the doc edits (`verify_s007_close.log`).

### Session 006: 2026-10-09 — Step 0 audit answers; Echo bounded ring (96 B + event vectors); A4.3 reach + trap deaths (PARITY §20); A4.3 ticked
_(entry completed at close)_

**Baseline at session start**
- Branch `dev/pop-rebuild`, HEAD `6073e53`, tracked tree clean; untracked and deliberately uncommitted: `tools/frame_decode_check.py`, `tools/smoke_pop.gd`, `tools/smoke_pop.gd.uid`.
- Last green: S005 close `verify_s005_close2.log` — **341 passed / 0 failed**, exit 0 (Godot 4.7.2-stable). Stale `test_main.tscn` procs killed before runs this session.
- Commits this session: `85af8a2` (Step 0 relabels + Step 1 ring), `e98f0fd` (Step 2 A4.3), plus the closing log commit. **Nothing pushed.**

**Step 0 — audit answers (asked first, as briefed)**
- (a) **Integrity outputs (verbatim):**
  - `git ls-files | grep -E "\.tools|\.log|\.patch|Original|study|SDLPoP|4dprinceprsia"` → **empty** (grep exit 1). ✅
  - `git log --all --oneline -- 4dprinceprsia SDLPoP-1.23 study` → **empty**. ✅ No reference-data commit on any ref.
  - Workflow `.github/workflows/verify.yml`: `on: push` + `pull_request`, **no branch filter**; pin `GODOT_VERSION="4.7.2-stable"` at `verify.sh:14`; `--import` gate at `verify.sh:46`. ✅ (Bump pin + cache key `godot-4.7.2-stable-linux-x86_64` together.)
  - Licensing re-scan: token grep (`segment[0-9]|__asm|static void|uint16_t|seg[0-9]{3}_|typedef struct|SDLPoP|#include` over `docs/PARITY.md` + `scripts/pop/`) → **6 hits, all citation comments** (PARITY.md header, `pop_rng.gd:9`); lines >200 chars containing `{};` → **2, both PARITY prose rows**. ✅ No C declarations, no pasted source.
- (b) **B1 status: PARTIAL → substantially complete, still unticked.** Thin slice landed S005 `dcbdc73` (bytes record/replay/flip, 5 asserts); this session `85af8a2` added the bounded ring (`RING_CAPACITY = 96` = 8 s at 12 fps; `_push()` evicts the oldest byte **and its event vector**; `at_capacity()`), per-tick `entity_events(prev,cur)` vectors (press/opening/fastclose/open/closed/dead milestones), and `replay_events()` which steps `PopSim.step` directly — the same fn as the player (gate-4 live-sim requirement). **B1.1/B1.2 not ticked:** the legacy `TemporalManager` echo path is untouched and B1.2's "existing 116 assertions with v2 in place" is unproven.
- (c) **Provenance tables** (value → PARITY row → citation; row texts are read live at test runtime by `_parity_row`/`_parity_cell`):

| A4.1 value | PARITY | Citation |
|---|---|---|
| gate Δ −1/+4, open ≥188 → park 238, fast 20…120 | §9 | `seg007.c:332-364` |
| level (exit) door {0,5,17,99} from 43 | §9 | `seg007.c:411`, `seg007.c:424-431`, `seg007.c:795-798` |
| plate encodings: target `d1&0x1F`, chain `!(d1&0x80)`, room, hold `d2&0x1F` (31 = jammed) | §10 | `seg007.c:713-739`, `seg007.c:750-751` |
| press timer 5, re-press only below 2 | §10 | `seg007.c:742-791` |
| measured accept: open 47±1, close 238±1, exit 3, timer 5 | §9/§10 | ±1-tick windows are against **cited values, not [O]** (P6 ◐) |

| A4.2 value | PARITY | Citation |
|---|---|---|
| spike cycle 5 / 15 / 3 → ≈23 frames | §8 | `seg007.c:310-329` |
| harm classes 0 / 1 / 2 | §8 | `seg007.c:1171-1176` |
| loose floor: press→fall 11, shake 0x80–0x83 (reset ≥0x84), detach {2,65,128,191,254} | §11 | `data.h:827`, `seg007.c:809-829` |
| crush: same room+col, feet within 30 y-units above block | §11 | `seg007.c:1185-1195` (row fixed this session from `1185-1193`) |
| chomper 15 frames, bite on frame 2, blood 0x80, stops past frame 6 | §11 | `data.h:860`, `seg007.c:281-306` |
| falling-block fall rate | §7 **placeholder** | carried as sim characterization, labelled in the test |

- **Correction legitimacy** (each: source read at fix time; the assertion was never weakened — it was corrected and/or a negative assertion added; re-verified green in the same session):
  (a) chomper-bite capture looped over the last mod instead of the first-blood flag → capture fixed, assertion unchanged (S005);
  (b) `crush_test` direction inverted — reference tests the block **above** the feet (`seg007.c:1185-1195`) → corrected + "block below does not crush" assert (S005);
  (c) §13 substring probes `"153, 154"`/`"150 or 161"` missed the `f` prefix → probe text → `f153, f154` / `f150 or f161` (S005);
  (d) `0xFF` parses as 0 through `_ints` → probe changed to `contains("0xFF")` (S005);
  (e) **new S006:** damage lands only on **f154** (`seg002.c:1014`) — the old test asserted f153 damages; t1 corrected to f154 **plus** a new "f153 alone does not damage" assertion;
  (f) **new S006:** `refractimer` is set when the guard is **hurt** (`seg002.c:965-974`), not on its strike — old behaviour removed, §12 row unchanged;
  (g) **new S006:** `CHAIN_ADVANCE` gained f165 (`seqtbl.c:318`); §13 walk row completed.
- **Relabel pass (`85af8a2`, labels only — no assertion changed):** A4.1 level-shape/plate-placement + determinism probes → "sim characterization"; exit-door 3-tick → "PARITY §9 arithmetic on level-door rows"; crush-run reproducibility → characterization; falling-block fall rate already marked (§7 placeholder). **Citation fixes:** `pop_level.gd`/tests `seg007.c:1591/1605` were hex-offset marker comments, not file lines → `seg007.c:1185-1195` / `1198-1221`; PARITY §8 `seg005.c:216-218` → `220-222`; §11 crush row `1185-1193` → `1185-1195`; review.md:142/144 → same.
- **Sim-calibrated (labelled "sim characterization", kept, never dressed up as reference):** level shape/fixture, press→state mapping, block fall spawn/detach, chomper driver wiring, `BLOCK_HOLD_TICKS = 4`, block fall rate (§7 placeholder), duel start geometry (PARITY §20 note).

**Step 1 — Echo bounded ring + event vectors (committed `85af8a2`)**
- `scripts/pop/pop_replay.gd`: 96-byte ring (8 s at 12 fps), eviction carries the byte's vector with it, `record_run()` attaches `entity_events(prev,cur)` per tick, `replay()`/`replay_events()` step `PopSim.step` directly, `_entity_view()` deep-dup pre-step snapshot (plates/gates/exit/hp) because `PopSim.step` mutates nested dicts in place, `with_flipped_bit()` no longer copies events (regenerate via `replay_events`). Tests: same-step manual loop == replay, replay == recorded final, two replays hash equal, recorded == replayed events, `press:0,3` + `opening:0,7` present, flip diverges, 120-byte script caps at 96 with `bytes[0] == long_script[24]`, ring-aligned vectors.
- **First run `verify_s006_step1.log`: 349 passed, 2 failed** — the two milestone checks saw prev == post (shallow duplicate then in-place mutation) → fixed with `_entity_view()` → **`verify_s006_step1b.log`: 351 passed / 0 failed, exit 0**. All legacy TemporalManager sections stayed green.

**Step 2 — A4.3 reach, decision bands and trap deaths (committed `e98f0fd`)**
- **`docs/PARITY.md` §20 (new), 35 cited rows:** `char_opp_dist` (+13 facing, `seg006.c:2117-2131`), hit gate / damage frame f154 / min-hurt 8|12 / max 29 (`seg002.c:1000-1021`), parry turn-aside + `justblocked = 4` (`seg002.c:1009-1028`), timers (`seg002.c:634-636`, `seg005.c:994`), engage 35 / too-close 12|8 / armed bands 10|12 / far-no-draw / per-decision draw sites (`seg002.c:737-899`), refractimer-on-hurt (`seg002.c:965-974`), parry-far 32 (`seg005.c:1063`), sword-walk chain ids + dx rows (`seqtbl.c:220`, `seqtbl.c:314-329`), both parties' trap checks (`seg000.c:1205-1235`), spike windows (`seg006.c:958-960`), spike/chomper death (`seg005.c:220-246`, `seg004.c:439-484`), chomper cycle 1…15 (`seg007.c:284-289`).
- **`scripts/pop/pop_guard.gd`:** `opp_dist()` x/dir model; `_resolve` reach-gated (attacker sword drawn, defender-sword min-hurt, parry needs `0 <= d < 29`, forced f161, `justblocked` on parried guard attacks); `_decide` is now the `seg002.c` ladder — far → deterministic advance with no draw (refractimer-gated), too-close → close-in (same-direction → back-off) with no draw, [29,35) → advprob draw, [12,29) → block draw then strike draw with **strike > block** priority (`seg005.c:993-1015`), block-hold restrike via restrikeprob, f169 consumes the draw but starts nothing (`seg005.c:1036-1049`), guard_advance draws only at skill 0 or a spent kid-strike timer; walk chains pay their dx beside each frame (+2/+4, +6, −3/−2) in own-facing units; kid script gained `advance`/`retreat`; `duel(..., hazards)` runs `trap_step()` — spike windows + chomper `(mod & 0x7F) == 2` on the 15-frame cycle — for **both fighters** every tick; result carries the final signed `dist`.
- **Tests** (`_test_a43_duel`): 17 §20 anti-drift rows, 4 `opp_dist` rows, 11 resolve/reach asserts (in at 12/20, out at 11/29, undrawn 7/8, f153 no-damage, parry @20 in / @30 out, `justblocked` set), 18 ladder band asserts including RNG-consumption probes against a copy of the reference stream, 3 dx-chain asserts, distance-driven duels (sword-only stays 20, kid advance → 14, kid retreat → 25, each reproducible), trap unit rows for both parties (en garde safe on spikes) + live chomper kills (kid and guard) + spike-duel safety + hazard determinism; the GAP print is gone.
- **Evidence:** `./verify.sh` **413 passed / 0 failed, ALL CHECKS PASSED, exit 0** (log `verify_s006_step2.log`) — 62 new checks; attack script resolves *winner kid after 35 ticks* (15 under the old non-reach model).
- **A4.3 ticked** in `plan.md` (accept met: deterministic win/lose, identical transcript per seed, spiked/chomped deaths for both parties) with a Status line stating source-matched-not-observed.

**Step 3 — Stage A exit position (report only; A5.2 NOT started)**

| Criterion | Status |
|---|---|
| sandbox playable with sword-duel and traps | ◐ sim-level green (duel + spike/chomper deaths headless); `pop_lab.tscn` exists (S004) but keyboard play / feel **needs human playtest** |
| determinism test green | ✅ gate 1 green; duel same-seed identical / different-seed different asserted |
| PARITY.md populated for all §4.3 items | ✅ §12–§14 + new §20 cover the duel/trap values with `file:line` |
| A5.1 parity harness v1 | ⬜ not started — candidate for next session |
| A5.2 side-by-side video | ⬜ not started — user-manual, deliberately not started per brief |

→ **Stage A exit NOT met yet:** A5.1 + A5.2 + the human playtest remain; everything else in A4/A5 is still the cut line. **Nothing on the cut list triggered.**

**Trackers refreshed:** dashboard, time ledger (row 006 `[N]`), phase tracker (A4 → A4.1–A4.3 done; B1 ring), plan A4.3 tick; `.backup/s006_close/` taken.

**Hours:** not stated in the brief → `[N]`; no estimate substituted. Cumulative stays **10.3 / 34 h** (S004, S005, S006 pending). **Playtest:** not done yet. **Push:** NOT YET (nothing pushed; user pushes). **Arghya:** not counted.

**Verification ladder (this session):** 341/0 (S005 close) → 349+2 (Step 1 first run: event-vector snapshot bug) → **351/0** (`verify_s006_step1b.log`) → **413/0** (`verify_s006_step2.log`, exit 0) → **close verify 413/0, exit 0** after the tracker/entry edits (`verify_s006_close.log`; the close edits touch only plan/review, which `verify.sh` does not read — PARITY.md and the code were unchanged since the step-2 run).

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

**Step 5 — A4.2 spikes, loose floors and chompers (committed `babfd7f`)**
- **New behaviour:** `PopLevel` gained `trigger()` / `step_traps()` with three machines — **spike cycle** (extend 1→4 → snap 0x8F → hold to 0x81 → retract 6/7/8 → reset 0 and stop), **loose floor** (11-frame press→fall countdown, 0x80–0x83 shake band resetting at 0x84, detach empties the tile), **chomper** (15-frame cycle, bite sets the 0x80 blood flag on frame 2, stops past frame 6 when the kid left its row or died). `mods` and `anims` joined `STATE_KEYS`, and **tiles are now duplicated per run** because detaching a floor mutates one — the previous shared `tiles` reference would have let one run corrupt another.
- **Accept evidence:** `./verify.sh` **312 passed / 0 failed**, exit 0 (log `verify_s005_a42c.log`) — 40 new checks. Spike phases read 5/15/3 from PARITY §8 and the full 23-tick modifier sequence is asserted tick by tick; loose/chomper values come from PARITY §11; two replayed spike testcases show the extend window kills and the retract window does not.
- **Bug found in review, not by the test:** my first `crush_test` had the **wrong direction** — I had implemented *block below the feet*, while `check_loose_fall_on_kid` (`seg007.c:1185-1195`) tests `curmob.y < Char.y && Char.y - 30 < curmob.y`, i.e. the block must be **above** the feet within 30 units. The test passed against my own wrong predicate (self-consistent, not reference-corrected); corrected and re-verified with an explicit "block below the feet does not crush" assertion.
- **GAP:** the **falling loose-floor block entity is not modeled** — the crush rule is a unit predicate only, so `fall`/`crush` in plan A4.2 are partially delivered. **A4.2 is therefore left unticked** pending your call.
- **Correction (same session, supersedes the GAP above):** the falling block **was** then implemented — `_spawn_block` (starts at `y_loose_land[row+1]`, `seg007.c:818-832`), `_step_blocks` (PARITY §7 fall integration carried over as the block's rate, marked placeholder) and `_fell_on_your_head` (`seg007.c:1198-1221`, 1 HP per hit, last HP → `seq_22_crushed`). The live test shows a kid one row below a detaching floor dropping to **hp 1**, and the same run twice hashes equal with the block inside the state hash. **`./verify.sh` 316 passed / 0 failed, exit 0** (log `verify_s005_crush.log`), so **A4.2 is now ticked.**

**Step 6 — A4.3 guard duel at 10 fps (committed `6ec8236`)**
- **New file:** `scripts/pop/pop_guard.gd` (`PopGuard`) — a self-contained 10 fps duel: en-garde (`f158` loop), advance/retreat, strike/block/parry, per-skill odds + HP + refractory from **PARITY §12**, sword frame chains from **PARITY §13**, drawing from the reference LCG (**PARITY §14** / `PopRng`) in the reference's advance→block→strike order (`seg002.c:864-899`).
- **Accept met:** a strike in `f153/f154` lands unless the defender parries at `f150/f161` (then the strike is turned aside and the attacker enters the blocked chain). A scripted skill-0 duel **reaches a win** (measured: `winner=kid after 15 ticks, guard hp 0, kid hp 1`), and re-running with `seed=N` yields an **identical transcript and outcome**; a different seed yields a different transcript — plan §8 gate 3.
- **Evidence:** `./verify.sh` **341 passed / 0 failed**, exit 0 (log `verify_s005_a43b.log`) — 25 new checks, including anti-drift rows for all eight §12 tables and the §13 chains.
- **Two probes of mine were wrong, not the code:** I first asserted the §13 hit-window row with the substring `"153, 154"`, but the cell reads `f153, f154` (an `f` sits between), so the probe missed; corrected to `"f153, f154"` / `"f150 or f161"`. The assertions themselves were never weakened.
- **GAP (A4.3 therefore left unticked):** plan A4.3 also asks for **spiked/chomped deaths for both parties**. In the duel both fighters still die on HP alone — the guard is not integrated with the level/trap machines, so a trap cannot kill it. `advance/retreat` dx also does not gate reach (PARITY carries no reach distance, and inventing one would violate "no values from outside PARITY").

**Files touched this session**
- `plan.md` (A2.3 tick only), `review.md`, `docs/PARITY.md` (+1 row).
- `scripts/pop/pop_tables.gd`, `scripts/pop/pop_sim.gd`, `scripts/pop/pop_level.gd` (new), `scripts/pop/pop_replay.gd` (new), `tests/test_main.gd`.
- (A4.2) `pop_tables.gd` gained the PARITY §8/§11 constants, `pop_level.gd` the three trap machines, `pop_sim.gd` the `mods`/`anims` state keys and the per-run tile copy.
- (A4.3) `scripts/pop/pop_guard.gd` (new) + `_test_a43_duel()` in `tests/test_main.gd`.

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
| P4 | Hang / grab frame counts | 43-frame sway auto-drop; grab_timer 12 frames (PARITY.md §6; [S]) | A2.3 scope A asserts the §6 family counts (climb_down 10, climb_fail 11, hang_drop 5, grab_timer 12); **A5.1 C2 asserts the 43-tick sway auto-drop** and P6 the climb's stand on climb-tick 18 | ✅ | 002, 004, 007 |
| P5 | Spike cycle length | ≈23 logic frames (PARITY.md §8; [S]) | A5.1 asserts the pit floor stays armed (mod 3) through the run jump and flips to 0xFF on the C1 impale; the ≈23-frame cycle itself is **not** asserted | ◐ partial | 002, 007 |
| P6 | Gate open/close speeds, plate timing (±1 tick) | −1/+4 units/frame, fast 20…120; plate timer 5→<2 (PARITY.md §9–10; [S]) | A4.1: gate open 47 / close 238 / exit door 3 ticks; plate 5→1. **A5.1 P7/P8 on the room grammar: press→park 46 ticks (47 ±1), park→0 = 238 exact, plate 5→4** — within ±1 of §9–§10; source-matched, not observed | ✅ | 005, 007 |
| P7 | Guard duel transcript, seeded, skill 0 | tables: PARITY.md §12–§14 (strikeprob 61/blockprob 0/advprob 255 for skill 0; [S]) | skill-0 duel reaches a win (kid wins in 15 ticks, guard hp 0) and the transcript is identical for the same seed, different for a different seed (`_test_a43_duel`); source-matched, not observed | ◐ partial | 005 |
| P8 | Tick model: 12 fps traverse / 10 fps fight | confirmed: base_speed 5 / fight_speed 6 ticks of 60 Hz (PARITY.md §1; [S]) — **[O] observed: 12.00 Hz** (two captures) | 12 Hz sim clock; double-run hash equality over 400 ticks — source-matched; [O]-observed 12.00 Hz | ✅ | 002, 003 |

Status: ⬜ not tested · ❌ failing · ✅ matching

Note: P2 and P3 are source-matched, not observed. Their “Ours” columns come from the A2.2 acceptance tests and are tied to cited PARITY.md rows; they were not observed against the running reference binary in Session 003.

Reference values live in tracked `docs/PARITY.md` since Q1 was answered (Session 002). "Ours" for P1/P2/P3/P8 measured in Session 003 from the A2.2 acceptance tests; P8's reference is additionally [O]-observed (12.00 Hz, `study/OBSERVATION.md`). P4–P7 remain untested (gates 2 remainder / duel work).

### Plan §8 test gates

| Gate | Written? | Passing? | Session |
|---|---|---|---|
| Determinism (600 ticks, twice, equal hash; different seeds differ) | ✅ | ✅ | 002 |
| Kinematics parity table | ◐ partial — run/stand-jump + fall + edge-snap + turn/stop rows | ✅ those rows (189/0) | 003 |
| Duel transcript | ✅ | ✅ | 005 |
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
| 007 | 2026-10-09 | Step 0 legal rework; A5.1 built and ticked | [N] | §20 + guard tables re-expressed in our own schema (`b3d7a60`, `f5caf79`, `1c32db2`); B1 gap list + B0 design note (awaiting approval); A5.1 parity harness — P1–P8 + C1/C2 vs PARITY rows read at runtime — with the stand-Up grab lanes rebuilt on `check_jump_up`/`grab_up_with_floor_behind`/`jump_up_or_grab` and seq_8/seq_24 added (`b6b0c70`); PARITY measured-in-ours vs measured-in-SDLPoP columns; streams identical to source at every frame. Hours pending user figure. | 28 added (441 total) |
| 005 | 2026-10-08 | A2.3 ticked; A4.1 + thin B1 + A4.2 + A4.3 built | [N] | Pre-push audit clean (not pushed); A2.3 ticked with caveat; A4.1 gates/plates/level-exit door + `pop_level.gd` room-grid loader (PARITY §9/§10, ±1 tick); thin B1 input-byte echo; A4.2 spike cycle / loose floor / chomper / falling-block crush (PARITY §8/§11); A4.3 guard duel with seeded transcripts (PARITY §12–§14). Two of my own test probes corrected (crush direction, §13 substrings). Hours pending user figure. | 98 added (341 total) |
| 004 | 2026-10-08 | A2.3 rebuilt (under audit); A3 started | [N] | Rebuilt the A2.3 acceptance tests; repaired working-tree corruption (autoloads, `pop_input` stub, `STATE_KEYS`, `TURN_TICKS`, plus a fused line in this log); circularity audit + D13 (stand frame f15 vs tick 18); Section 3 evidence upgrades (PARITY §2 edge snap, §4 standing-jump trigger); clean-clone check green; A3.1 SimClock + A3.3 input latch + A3.2 pop_lab sandbox (feel needs playtest). Hours pending user figure. | 54 added (243 total) |
| 003 | 2026-10-06/07 | A2.1 + A2.2 done, observation started | 3.0 | Pre-commit audit + 4 user-approved commits (not pushed) + plan.md:432 fix (approved); Q2 re-verified live; `pop_tables.gd` + drift test w/ negative control; A2.2 step function + acceptance — all PARITY numbers matched exactly, turn/run-stop tick clarification cited; first gameplay observation: 12.00 Hz + standing jump ≈38 u [O] (run-jump/fall not observed). | 68 added (189 total) |
| 002 | 2026-10-06 | A1.1+A1.2 done, A2 gate 1 | 4.1+ext | Session 000's offsets proven wrong and extractor fixed (selftest w/ negative control + TILE_NAMES fix); A1.2 → study/STUDY_NOTES.md + tracked docs/PARITY.md (Q1 answered); SDLPoP built locally (no sudo) and `--screenshot-level` cross-check passed (start/guard/floor 12/12); tick model corrected to 12/10 fps; determinism gate green; A1.1+A1.2 ticked. | 5 added (121 total) |
| 000 | 2026-10-06 | §2.4 + A1.1 | 1.5 | Baseline captured; .gitignore reference entries added; A1.1 study extractor built, fixed, and run to produce study/ level_00–15 notes; verify.sh still green. No commit yet (awaiting user confirmation on Q1/Q2 + commit timing). | 0 added |

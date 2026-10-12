# PLAN — Prince of Persia: Echoes of Time (RRR)

**Status:** planning document — no game code is written in this pass.
**Written:** 2026-10-06 · **Deadline:** 2026-10-31 · **Time budget:** 7–10 h/week (~30–35 h total)
**Platform target:** Windows + Linux desktop (validated exports) · **Team:** solo (you)
**Repo:** `github.com/Akash-Das26/RRR` · Godot 4.7.2 · GDScript only

Every task below is a `- [ ]` checkbox so progress is trackable. **[M]** = must-have for
submission, **[N]** = nice-to-have. Effort is honest solo-dev estimates at 7–10 h/week —
they add up to more than the time available, which is exactly why sections 10 and 11
exist: the plan tells you what to cut first.

---

## 1. Executive summary and goals

**Where you are.** A complete five-level vertical slice already exists: 13-state player
controller, four enemy archetypes, the full Temporal Echo system (recorder → snapshot →
deterministic replay → event replay → energy/capacity), a wireable puzzle framework
(`Activator` → plates/levers/runes → doors/gates/platforms), five data-driven levels
ending in an echo-gated boss, zero audio, zero sprites (all `_draw()`), and a
`./verify.sh` gate running 116 headless assertions plus level-boot checks. What it does
**not** have is a proven kinship to the 1989 original: right now the connection is
thematic ("palace, traps, swords"), and the README claims originality by *distance*
rather than by *understanding*.

**The strategy you have chosen (and this plan implements):** Stage A rebuilds Prince of
Persia's *behavior* — the fixed-tick simulation, sequence-table animation, tile/room
model, trap timing, guard duels — inside Godot, verified for parity against SDLPoP using
its replay and frame-step features. Stage B then replaces the current freeform
action-platformer movement with that faithful core and re-layers the Temporal Echo on
top of it, so "cooperate with your own past" plays out through *authentic* PoP
kinematics. The result is a game whose claim to "Reimagine" is demonstrable: judges can
see the 1989 DNA in every jump.

**Goals, in priority order** (matching your GDD's priority order and the deadline):

1. **[M] A playable, exported Windows + Linux build** of Echoes of Time whose movement
   and feel are derived from the original's measured parameters (tick model, jump arcs,
   sword timing), with the Temporal Echo as the signature system.
2. **[M] A 3-level game** (tutorial + thesis + payoff/boss), polished, with audio, that
   is beatable by a human playtester — current levels 1, 2, 5 scope, rebuilt on the
   Stage A core.
3. **[M] Original assets only** — recreated art/audio with a clean license record; the
   two reference folders removed from the public repo and demoted to local study
   material (§2, §7).
4. **[M] All four deliverables:** build, <2 min video, updated GDD, ≤10-slide deck.
5. **[N] A parity report** (`docs/PARITY.md`) documenting measured agreement with SDLPoP
   (jump distances, tick tables, fall-damage thresholds) — this doubles as the strongest
   "we understood the original" evidence in the presentation.

**Non-goals.** Full 14-level faithful rebuild; multiplayer; the 2-echo Clockwork Sanctum
level (level 4 is cut — see §6 Stage B); gamepad support; web export; persistence
(checkpoints stay session-only, as today).

**The single biggest risk** is time: at 30–35 h total, Stage A as spec'd here (~40 h of
must-haves at full fidelity) cannot be done exhaustively. §6.0 defines a **parity core**
(what "feels like PoP" actually requires) and a **parity menu** (what is cut if time runs
out). Deciding that boundary *now* is the point of this document.

---

## 2. Reference analysis

### 2.1 `4dprinceprsia/` — original PoP1 DOS data, as shipped by a fan mod

**What it is.** A 38-file DOS game folder, all files dated **Feb 25–26 1994** (checked
`ls -la`). `4D_PRIN.EXE` is an `MS-DOS executable, MZ` — this is the data directory of
**4D Prince of Persia**, a 1994 fan modification of PoP1 v1.4 (the "4D" title, 3D-style
box-art backgrounds). The `.DAT` files are the **original 1990s Brøderbund-era asset and
data files**, possibly lightly modded by the 4D authors:

- **Graphics:** `KID.DAT` (37 KB — the prince's frames), `GUARD*.DAT`, `FAT.DAT`/
  `FAT2.DAT` (fat guard), `SKEL.DAT` (skeleton), `SHADOW.DAT`, `VIZIER.DAT` (Jaffar),
  `PV.DAT` (princess/Jaffar cutscene art), `TITLE.DAT` (title/story screens),
  `VDUNGEON.DAT`/`VPALACE.DAT` (environment tiles), `VDUNGEON/VPALACE` + `KID`, `GUARD`
  etc. also exist inside SDLPoP's `data/` — same format (SDLPoP `types.h` defines the
  chtab list: chtab 2 = KID 400 frames, chtab 5 = guard 750, chtab 6/7 = environment
  200/360).
- **Levels:** the level data inside SDLPoP's `data/LEVELS/res200*.bin` (16 files, 2305
  bytes each = exactly `sizeof(level_type) == 2305` per `types.h`) are the unpacked
  levels; `4dprinceprsia` carries the packed originals in its own DAT set.
- **Audio:** `DIGISND1–6.DAT` (PC-speaker/digi SFX), `MIDISND1–2.DAT` (Adlib/MIDI music),
  `IBM_SND1–2.DAT` (IBM speaker).
- **The EXE:** the modified game binary itself. Not needed for study — SDLPoP is a
  cleaner, readable representation of the same behavior.

**Format findings (relevant later):** the KID.DAT header bytes begin `3b 8a 00 00 e2 06
6c db` — consistent with the standard PoP DAT container (index section then
LZG/RLE-compressed images, decoders in `SDLPoP-1.23/src/seg009.c`:
`decompress_rle_lr`, `decompress_rle_ud`, `decompress_lzg_lr`, `decompress_lzg_ud`).

**License: NONE — all-rights-reserved.** The 1989 game and its data files are
commercial Brøderbund/Ubisoft property. The "4D" mod authors modified but did not
relicense them. **Nothing in this folder may be shipped, repacked, converted into your
game's assets, or hosted in a public competition repo.** It is study material only:
timings, layouts, tile semantics, and "how Mechner staged a room" — read it with
SDLPoP, never copy bytes out of it.

### 2.2 `SDLPoP-1.23/` — the clean-room-adjacent C port, GPL-3

**What it is.** SDLPoP v1.23 (README: "An open-source port of Prince of Persia, based
on the disassembly of the DOS version"), by NagyD + contributors. Layout found on disk:

```
SDLPoP-1.23/
  prince, prince.exe          prebuilt binaries (Linux ELF + Windows PE)
  COPYING                     GNU GPL v3, full text (verified)
  README.md                   usage, keys, replay/mod/compile docs
  SDLPoP.ini                  full option surface (see below)
  src/                        the port, C99 + SDL2
    seg000–seg009.c           1:1 rewrite of the DOS code segments
    seqtbl.c                  the animation/behavior sequence table (1,228 lines)
    data.h / data.c           every original constant and table (936-line header)
    replay.c                  input-recording replay system (.P1R files)
    screenshot.c              --screenshot / --screenshot-level map dumpers
    menu.c, options.c, lighting.c, midi.c, opl3.c, stb_vorbis.c
    Makefile, CMakeLists.txt, NMakefile, build.bat
  data/                       PRINCE.DAT, KID, GUARD…, LEVELS/res2000–2015.bin
  doc/                        internals_sequence-table.txt, internals_sounds.csv,
                              internals_sequence-index.csv, old_bugs.txt (634 lines),
                              tiles.md, replay_format.txt, ChangeLog.txt,
                              replays-testcases/*.p1r (17 files)
  mods/, replays/             (empty placeholders + readme)
```

**License: GPL-3.0-only**, stated in `README.md` ("This program is open source under the
GNU General Public License terms") and `COPYING` (full GPLv3). Consequences, spelled out:

- **Copying SDLPoP code into your game makes your entire game a GPL-3 derivative
  work.** You would be obliged to release your full source under GPL-3. For a
  competition entry that itself is not necessarily disqualifying — but "original work"
  judging would be damaged, and if RRR rules require original code, it is fatal. This
  is a **rules decision you must make explicitly** (§11, Q1).
- **Translating behavior into your own implementation from understanding (clean-room
  re-implementation) is what SDLPoP itself did** — it is based on a *disassembly*, and
  game **rules/mechanics are not copyrightable** (only their concrete expression is).
  Re-deriving tick tables and probabilities from what the code *does* — then writing
  your own GDScript — is the safe path. Documented in `docs/PARITY.md` with measurements
  rather than pasted source, it is clean.
- **Gray zone to avoid:** transliterating `seqtbl.c`'s byte sequences or `data.h`'s
  tables verbatim into GDScript dictionaries is "copied expression" even in a new
  language. The rule this plan follows: **derive → measure → re-author.** Where a value
  is a physical constant (e.g. `FALLING_SPEED_ACCEL 3`), noting the number is fine;
  where it is authored data (the 1200-entry sequence table, guard-skill probability
  arrays), you re-express it as your own schema with the *values* measured from
  behavior (they're just timings/probabilities — facts), cited to "SDLPoP behavior,
  measured" in comments, never as ported code.

**What SDLPoP uniquely offers your project (verified in source):**

| Feature | Where | Use for you |
|---|---|---|
| **Deterministic input replays (`.P1R`)** | `replay.c`; format in `doc/replay_format.txt`: magic "P1R", savestate snapshot, saved RNG seed, `num_replay_ticks`, 1 byte/tick of packed input (`replay_move_type`: x:2, y:2, shift:1, special:3) | The parity harness (§8): record an input script once, replay it under `seed=N`, diff state hashes between your sim and SDLPoP. Also the model your own Echo recorder should converge toward |
| **Frame-perfect debug timer** | debug key `T` shows "remaining minutes:seconds:ticks" + total elapsed ticks | Counting game-ticks to align behavior comparisons |
| **Deterministic RNG** | `prandom()` in `seg009.c`: `seed = seed*214013 + 2531011; return (seed>>16) % (max+1)` | Reproduceable guard AI decisions under `seed=`; your sim needs the same property (§4) |
| **Level map dumps** | `--screenshot-level` / `--screenshot-level-extras` + `doc/Map_Symbols.txt` | Render original level layouts as reference images for your own level design (layouts as *ideas*, redrawn) |
| **`--screenshot`** | CLI | Side-by-side sprite-pose reference for your recreated art |
| **Gameplay-fix switches** | `SDLPoP.ini` `use_fixes_and_enhancements=false` + ~35 named `fix_*` flags | Run *vanilla-accurate* behavior when measuring (fixes off), then see what each bug does — old_bugs.txt catalogs them |
| **Replay testcases** | `doc/replays-testcases/*.p1r` (17 files: "Original level 5 shadow into wall", "trick_153", "Falling through floor (PR274)"…) | Ready-made edge-case inputs for the parity harness |
| **Speed control** | `base_speed = 5` (1 tick per 5 vblanks = 12 fps), `fight_speed = 6` (10 fps) in `data.h` | The exact numbers your fixed-tick model uses (§4) |

### 2.3 Usable vs. study-only — the dividing line

| Material | Verdict | Reasoning |
|---|---|---|
| Mechanics: tick model, physics constants, collision rules, state graph | **Usable as behavior** (re-implement; cite measurements) | Mechanics/rules are not copyrightable expression |
| Timing tables (frame durations, trap cycles, fall thresholds) | **Usable as facts** (re-author in your own data schema, cite) | Facts/measurements, not creative expression |
| Original level **layouts** (room grids) | **Study-only.** Do not recreate rooms 1:1. Design your own rooms *informed by* pacing ideas | Level layout is a creative work; a 1:1 remake is a derivative asset |
| Sprites (`KID.DAT`, `GUARD*.DAT`, environment DATs), title art | **Study-only** (pose reference at most; no tracing, no extraction) | The strongest IP in the folder |
| Audio (`DIGISND*`, `MIDISND*`) | **Study-only** (rhythm/duration reference) | Brøderbund recordings |
| SDLPoP C source | **Study-only** (reading fine; no porting, no linking) | GPL-3 — see consequences above |
| SDLPoP's *documentation* (`doc/internals_*.txt/csv`, `old_bugs.txt`) | **Usable as reference** (facts about behavior; do not copy text wholesale) | Technical facts; cite as source in GDD/PARITY docs |
| SDLPoP *tooling as tools* (run the binary, replays, screenshots, debug keys) | **Usable freely** | Running GPL software to observe behavior is unrestricted |
| Story text, character names ("Jaffar", "Kid"), title | **Avoid in-game** | Trademark/character rights (Ubisoft); your game already uses original names |

### 2.4 Action items from this analysis

- [x] **[M]** Remove `4dprinceprsia/` and `SDLPoP-1.23/` from the git **index and remote**
      (keep local copies as study material). `git rm -r --cached 4dprinceprsia SDLPoP-1.23`
      then rewrite or accept history (decision §11, Q2).
- [x] **[M]** Add both folder names to `.gitignore` with a comment: local study material,
      not for distribution, not for committing.
- [ ] **[M]** Update `README.md` + `docs/ASSET_LICENSES.md` to add a "Study references"
      section naming SDLPoP (GPL-3, used as behavioral reference only, not linked or
      copied) and the original game data (all-rights-reserved, inspected for research).
- [ ] **[M]** In `docs/ASSET_LICENSES.md`, change the provenance statement: today it
      says "no Prince of Persia asset … is derived from"; after Stage A it must say
      "behavioral parameters were **measured from** SDLPoP (GPL-3, study only) and are
      cited as facts in `docs/PARITY.md`; no code, art, audio, text, or level layouts
      were copied."
- [ ] **[N]** Keep a local `STUDY_NOTES.md` (untracked) as the scratchpad where
      measurements are first recorded before being cleaned into `docs/PARITY.md`.

---

## 3. Tooling decisions

| Category | Choice | Alternative | Reasoning |
|---|---|---|---|
| **Engine** | **Keep Godot 4.7.2** | Unity/Unreal/LOVE2D/Solar2D | Decisive: you have a 4.7k-line, tested, zero-dependency GDScript codebase and ~30 h left. Any engine switch re-spends that. Honest comparison: Godot's default physics is *not* deterministic enough for the Echo — but that is solved by **not using Godot physics for the core sim** (§4), not by switching engines. Unity gives better determinism out of the box but costs the codebase and the 2D-pixel workflow. Unreal is wrong-shaped for 2D. LOVE2D is smaller but loses the editor, tilemap, and export pipeline |
| **Language** | **GDScript, one exception**: the core simulation module (tick/tables/collision) written in plain GDScript but *pure* (no engine types in its hot path), so a later C#/GDExtension port is a drop-in if profiling demands | C# everywhere | GDScript iteration speed wins at this deadline. C# buys perf you don't need at 12 fps logic + 60 fps render of a few dozen nodes. The pure-sim rule keeps the escape hatch open without paying for it now |
| **Tick/render model** | **Fixed 12 fps logic tick (60 vblank-ish frames → 1 game frame), render-interpolated at 60 fps** | (a) native 60 fps sim; (b) variable delta | See §4.2 for the full justification — this is the single most important technical decision in the plan |
| **Art pipeline** | **Hybrid (your choice): Aseprite for characters/props (original pixel art), procedural `_draw()` environment extended from current `palette.gd`/`platform.gd`** | Full pixel art; LibreSprite | Aseprite is the industry standard, Linux-native, €0–20, exports `.png` + `.aseprite` (Godot has an Aseprite importer plugin, but plain PNG exports + explicit frame lists is simpler and dependency-free — recommended). LibreSprite is the FOSS clone if budget blocks Aseprite. Characters need rotoscope-*inspired* but redrawn silhouettes: study SDLPoP `--screenshot` poses, redraw from scratch |
| **Animation approach** | **Frame-by-frame sprite sheets (`.png`) + Godot `SpriteFrames`/`AnimatedSprite2D`, indexed by the same sequence-table data that drives logic** | Skeletal (Skeleton2D), tween-based | The original is frame-based; skeletal would fight the tick model. One source of truth: `seqtbl`-equivalent data indexes *both* the logic state and the animation frame (§4.4) |
| **Tilemap authoring** | **Godot TileMapLayer with a hand-authored TileSet** for the final look; **your existing data-driven builder (`LevelBuilder`) stays as the layout source of truth**, generating/parametrizing tiles | LDtk; Tiled | Your levels are already pure data (`data/levels/level_catalog.gd`) wired by string id — that's a better determinism/testing story than any external editor, and the 116-test suite guards it. LDtk/Tiled would add an export layer for zero gameplay gain. Author *rooms* (10×3 tile grid, PoP room shape) as data |
| **Level data format + converter** | **Extend `level_catalog.gd` schema with a `rooms:` grid** (tile ids per 10×3 room) + a **one-way Python converter** `tools/pop_level_to_notes.py` that parses SDLPoP's `data/LEVELS/res200*.bin` (2305-byte `level_type` struct, offsets known from `types.h`) and emits a *human-readable study sheet* (tile grids + trap positions) — **not** a game-data importer | Full importer into playable levels | Importing original layouts into the game is the legal line you chose not to cross (§2.3). The converter output is reference material for designing your own rooms in the same *grammar* |
| **Audio SFX** | **jsfxr (jsfxr.quantumrocket.com) / sfxr** for impact/step/gate/spike sounds → WAV; pitch/duration tuned to the SDLPoP `internals_sounds.csv` cue list (38 cues documented) | BFXR; recorded FOley | sfxr-family output is original-by-construction, fast, and stylistically right for a retro-tinged game. The CSV list is a free *checklist* of what sounds the original has — you make your own version of each |
| **Audio music** | **LMMS** (dorian-mood tracks, ~2 loops: title/explore + tension/boss) | Bosca Ceoil; CC0 sources (e.g. OpenGameArt CC0, attribution-tracked) | LMMS is free, Linux-native, exports WAV/OGG. Bosca Ceoil is faster for simple chips but less flexible. CC0 sourcing is the fallback if composition stalls — but record every file in `docs/ASSET_LICENSES.md` before committing (the table already exists) |
| **Reverse-engineering / analysis** | **ripgrep + the already-readable SDLPoP source + its `doc/` internals files + running SDLPoP with debug keys**; Python for byte-level DAT/level parsing | Ghidra | Ghidra is *not needed*: the disassembly already exists as readable C. Only open Ghidra on `4D_PRIN.EXE` if you ever need to know what the 4D mod changed — which you don't (you're not shipping its behavior) |
| **Testing** | **Keep your existing headless assertion suite** (`tests/test_main.gd`, 116 assertions, run by `./verify.sh`) and extend it; **do not** introduce GUT/gdUnit4 mid-project | gdUnit4 | Your suite already proves echo determinism, wiring, boss gating — the exact things that matter — and runs in CI via `verify.sh` non-zero exit. A framework swap now costs a day and buys vocabulary |
| **CI** | **GitHub Actions**: 1 workflow running `./verify.sh` on `ubuntu-latest` per push | GitLab CI; none | verify.sh already exits non-zero and self-installs Godot — the workflow is ~20 lines |
| **VCS / large files** | **Plain git**; no LFS needed (art stays small: sprite sheets <2 MB total, audio OGGs <5 MB) | Git LFS | Nothing in the asset plan approaches LFS territory. *Do* strip the two reference folders from history (§2.4) |
| **Video capture** | **OBS Studio** (Linux) recording at 1920×1080/60 from the Linux build; **Kdenlive** for the cut | GPU-screen-recorder; Shotcut | OBS is the default for a reason; Kdenlive handles title cards, speed ramps and the <2:00 trim with audio ducking |
| **GDD** | **Keep `docs/GDD.md` (Markdown)**, updated in place | any doc tool | It's already competition-shaped; update §8/§9/§11 to reflect the Stage A core |
| **Slides** | **Keep the 9-slide outline in `docs/PRESENTATION.md`**, render to deck in LibreOffice Impress or Marp (Markdown→PDF) | Google Slides | The outline exists with speaker notes; Marp keeps it in-repo and diffable |
| **Export targets** | **Linux (primary dev/validation) + Windows** export presets, committed without local paths (template paths via env var or documented) | Web | Your answer: Windows + Linux. Web adds a 60 MB+ WASM constraint and untested-audio risk for zero judged benefit. Windows export needs the Windows export templates on Linux — supported headlessly by Godot |
| **Export validation** | Run each exported binary once before submission; a 60-second scripted sanity boot (a `--level=1` CLI arg) on both | — | An export that crashes on the judge's machine is the most avoidable catastrophe in this plan |

**[M] vs [N] in tooling:** everything in the table is [M] except: Marp deck rendering
[nice-to-have — Impress is fine], the `.p1r` edge-case harness extension [N], and the
C# escape hatch [N].

---

## 4. Architecture for the rebuild

### 4.1 Module map (new code under `scripts/pop/`, everything else stays)

```
scripts/pop/
  pop_sim.gd            # PURE simulation: one static entry point
                        #   SimState + SimInput -> SimState  (step(state, input) -> state)
                        # No Godot nodes, no physics engine, no floats in state.
  pop_tables.gd         # Re-authored data: sequence table (your schema),
                        # frame tables (dx/dy/flags per frame), tile constants,
                        # guard skill probabilities, y_land/x_bump equivalents.
  pop_level.gd          # Room grid model: 10x3 tile rooms, links, modifiers.
  pop_input.gd          # Input snapshot: x/y/shift/special, identical shape to
                        # SDLPoP's replay_move_type (8 meaningful bits/frame).
  pop_replay.gd         # Input recording + byte-packed replay of a simulation run
                        # (the seed of the Temporal Echo recorder in Stage B).
  pop_rng.gd            # Seeded integer LCG (measured from SDLPoP behavior), used
                        # only inside pop_sim so runs are reproducible.

  pop_view.gd           # Node that renders a SimState (interpolated between ticks).
  pop_player_bridge.gd  # Maps SimState -> your Player/AnimatedSprite2D visuals,
                        # emits the same signals the current code expects.
```

**Data flow (both stages):**

```
raw input ──> pop_input (sampled per 60fps frame, latched per 12fps tick)
                │
                ▼
        pop_sim.step()  ── deterministic new SimState ──┬──> pop_view (render, interpolate)
                │                                       └──> gameplay signals (hit, plate, gate)
                └── replay buffer (input bytes) ──> Temporal Echo (Stage B)
```

**Everything that today uses `CharacterBody2D.move_and_slide()` for the prince is
replaced in the rebuild;** enemies, echo bodies and puzzle objects stay Godot-side and
consume simulation events. This is the same split the original has (seg000–seg008 sim vs
seg009 presentation) and it is what keeps parity *provable*.

### 4.2 The tick model — fixed 12 fps logic, 60 fps interpolated render

**What the original does (measured):** SDLPoP runs a 60 fps
heartbeat (`init_timer(BASE_FPS)` with `BASE_FPS 60`, `types.h:1351`) and advances the
*game* one frame per N vblanks via `set_timer_length(timer_1, base_speed)` where
`base_speed = 5` normally and `fight_speed = 6` when the sword is drawn (`data.h:858–859`,
`seg003.c:364–367`). So the simulation is effectively **12 fps in free traversal and
10 fps during swordfights** — the documented "frame = 1/12 s (1/10 s when fighting)"
from `doc/internals_sequence-table.txt`. Every animation frame, trap cycle and the
clock (720 ticks/minute, `show_time()` in `seg008.c:1761`) counts in these frames.

**Recommendation: fixed-tick simulation at exactly 12 fps with a per-fight 10 fps mode,
render-interpolated at 60 fps.** Justification:

1. **Parity demands it.** Measured constants (`FALLING_SPEED_ACCEL 3`,
   `FALLING_SPEED_MAX 33`, `y_land[] = {-8, 55, 118, 181, 244}`, `x_bump[]` grid,
   sequence `dx(n)`/`dy(n)` per-frame deltas) only reproduce the original's *feel* —
   jump distances, hang frames, spike timing — at the original's rate. Re-deriving them
   at 60 fps means re-tuning everything by hand with no reference oracle, in the time
   you don't have.
2. **Determinism demands it.** The Temporal Echo's contract is "same input bytes → same
   run". A fixed integer tick with fixed-point math makes that airtight (§4.5); a
   60 fps sim re-simulating physics would reintroduce float drift you'd then have to
   fight in the echo.
3. **The "cinematic 12 fps" look is the original's identity.** Interpolated rendering
   (positional lerp between the last two sim states, animation frames snapped to sim
   frames) gives you 60 fps-smooth camera/parallax/particles *around* 12 fps
   character motion — which reads as "deliberate rotoscope cadence", not as lag. This
   is exactly the trick modern remakes (e.g. the Sam & Max/Telltale-era restorations and
   the Prince-of-Persia-style *Cursed Castilla*-school of games) use.
4. **Cost is bounded.** Your simulation state is small (one kid, one opponent, tile
   grid, trobs list, RNG seed, clock — SDLPoP's quicksave serializes it in ~1 KB).
   Stepping it 12×/s is trivially cheap; the interpolation is one lerp per rendered
   node.

**Implementation shape:** a `SimClock` node: accumulates real time, runs
`pop_sim.step()` when `acc ≥ 1/12 s` (or `1/10 s` in fight mode), keeps
`(prev_state, curr_state, alpha)` for `pop_view.gd` to interpolate. Input is latched:
sample every render frame, deliver the union at the next tick (matching how the DOS
game polled the keyboard once per game frame).

### 4.3 Physics and collision rules to port (from the reference, as behavior)

- **Tile/room grid:** rooms are 10×3 tiles; a level is up to 24 rooms linked
  left/right/up/down (`level_type` in `types.h`: `fg[720]` + `bg[720]` modifier bytes +
  `roomlinks[24]`). Tile ids 0–30 (`enum tiles`, `types.h:104–130`): floor, spike,
  pillar, gate, drop button, raise button, loose floor, potion, exit door, chomper,
  torch, wall, mirror, debris, balcony, lattice, skeleton, sword… Your `pop_level.gd`
  mirrors the *semantics* (which tile is floor-like, wall-like, interactive) with your
  own enum and data schema.
- **Character coordinates are tile-relative, not free:** `x_bump[]` (20 column anchors,
  14 units/tile in char space, `types.h:1405`) and `y_land[] = {-8, 55, 118, 181, 244}`
  (floor y per row, `data.h:506`) mean the kid's position quantizes to tile edges —
  this is why jumps land "exactly". Port as: horizontal position = integer px within a
  tile with edge-snap rules (`distance_to_edge_weight()`, `seg006.c:1305`), vertical =
  row + sub-row offset.
- **Falling:** `fall_y += 3` per frame, capped at 33 (`FALLING_SPEED_ACCEL/MAX`,
  `types.h:1413–1416`); landing thresholds: `<22` soft land, `22–32` medium land
  (−1 HP), `≥33` = ≥3 rows = death (`land()`, `seg005.c:114–230`); `fall_y ≥ 31`
  triggers the scream (`do_fall()`, `seg005.c:37`). Grab: pressing Shift while falling
  with a grabbable tile ahead checks `can_grab_front_above()` and snaps
  (`seg006.c:1175–1200`).
- **Spikes:** modifiers cycle out-up-stay-down via `animate_spike()` (`seg007.c:310`):
  extension frames 1–4, `0x8F` armed/retract countdown, `0xFF` = spent. Harmfulness is
  modifier-state dependent (`is_spike_harmful()`), not collision-shape dependent.
- **Loose floors:** shake 11 frames (`loose_floor_delay = 11`) then fall as a "mob" with
  `y_loose_land[]` landing rows; crush check `check_loose_fall_on_kid()` uses
  `y < char.y < y+30` (`seg007.c:1183`).
- **Gates:** modifier 0–188 = closing/opening px, `door_delta[] = {-1,4,4}`,
  fast-close speeds `gate_close_speeds[] = {0,0,0,20,40,60,80,100,120}`/4
  (`seg007.c:336–405`); can-bump checks (`can_bump_into_gate()`) gate whether the kid
  is pushed.
- **Pressure plates (openers/closers):** modifier = door-link timer,
  `animate_button()` decrements per frame; door links are a 256+256-byte per-level
  graph (`doorlinks1/2` in `level_type`) — closer→gate and opener→gate wiring is
  *data*, which is exactly the shape of your existing `listens_to` wiring.
- **Chomper:** 15-frame cycle (`chomper_speed = 15`), bites on frames 2 and blood on
  frame ≥6 (segment `animate_chomper()`, `seg007.c:281`).
- **Level exit door:** opens 43 px (`curr_modifier >= 43`), then walking into its tile
  with `leveldoor_open` advances the level (`animate_leveldoor()`, `seg007.c:413`).
- **Swordfight:** 10 fps; distance-based AI with per-skill probability tables
  (12 skills; e.g. skill 0: `strikeprob 61, blockprob 0, advprob 255`; skill 5 "fat":
  `restrikeprob 175`; full tables `data.h:841–847`, consumed in `guard_advance/block/
  strike`, `seg002.c:864–919`) all through the seeded `prandom()`; hit = 1 HP,
  `guard_refrac` refractory frames (`refractimer[]`), parry/block frame matches
  (`frame_152/153/162` checks in `guard_block()`). Guard HP per level:
  `tbl_guard_hp = {4,3,3,3,3,4,5,4,4,5,5,5,4,6,0,0}` (`data.h:835`).
- **Clock:** 60 minutes × 720 ticks; decremented in `show_time()`; expiry kills
  (`expired()`).
- **Health/potions:** kid starts 3 HP (`start_hitp`), small potion +1, large sets max
  +1 up to 10 (`max_hitp_allowed`), damage per sword hit 1, per two-row fall 1.

**Separation discipline:** every number above enters the codebase in **one** file —
`pop_tables.gd` — as named constants with a comment citing the *measured behavior*
("SDLPoP: soft land below 22, med land below 33, death at 33+; verified by replay
R-2026-10-07"), never inline in logic. That file is the boundary where
"reference-derived data" visibly lives; `pop_sim.gd` and everything Godot-side is
original code.

### 4.4 State/animation model

Port the *architecture*, not the bytes: a sequence table of your own format —
list of ops per animation: `FRAME(i)`, `DX(n)`, `DY(n)`, `SET_FALL(x,y)`, `SOUND(id)`,
`JUMP(seq)`, `ACTION(a)` — executed by an interpreter in `pop_sim.gd`. SDLPoP's
`seqtbl.c` (1,228 lines) and `frame_table_kid[]` (in `seg006.c`, entries
`{image, sword-id, dx, dy, flags}`) are the behavioral reference; you re-author the
sequences as readable GDScript data for the ~30 sequences you actually need (run,
stand, stand-jump, run-jump, turn, fall, hang, climb up/down, crouch, soft/medium land,
spiked, chomped, sword: draw/en-garde/advance/retreat/strike/block/parry/hit/death).
Cutscenes, mouse, princess, skeleton, mirror and Jaffar sequences are **not** ported
(Stage A scope = mechanics; the 4D-mod story frames are irrelevant to Echoes of Time).

### 4.5 Determinism by construction (from Stage A, not bolted on in Stage B)

1. **Integer state.** `SimState` fields: positions (int), velocities (int), frame
   indices (int), tile modifiers (int), HP, clock, RNG seed (int). No floats *in
   state*; anything fractional is stored as fixed-point ints (× 256).
2. **Pure step function.** `pop_sim.step(state, input) -> state` does no I/O, reads no
   clocks, touches no nodes. Two identical calls return identical states, bit for bit.
3. **Seeded RNG inside the sim only.** `pop_rng.gd` implements the measured LCG
   (`seed = seed*214013 + 2531011`, take `(seed >> 16) % (max+1)`). Torch flicker etc.
   that don't affect gameplay never call it (SDLPoP notably *does* burn RNG on
   torches — it had to for replay compat; you don't).
4. **Input latching.** One `pop_input` byte per sim tick, exactly the
   `replay_move_type` bit layout (x:2 y:2 shift:1 special:3) — which makes the Echo's
   replay buffer literally a list of these bytes.
5. **Test-enforced.** The suite asserts: run 600 ticks with a fixed input script from a
   fixed seed twice → state hashes equal; run on two different Godot platform strings
   (if CI offers win/linux runners) → equal. This test exists from day one of Stage A.

### 4.6 Where existing systems land

| Existing system | Disposition |
|---|---|
| `PlayerStateMachine` + 13 states | **Replaced** for the prince by the pop-sim (the sim has its own action model, actions 0–7). The state machine pattern stays for enemies |
| `Player` motion exports (accel, coyote, jump-cut…) | **Discarded** — superseded by measured tick data. Keep the file until Stage B lands as the fallback build |
| `Health`, `Hitbox`, `Hurtbox` | **Kept** — driven by sim events instead of physics areas |
| `TemporalManager` / recorder / snapshot / echo | **Kept, refactored**: recorder captures `pop_input` bytes per tick (60 bytes/s) instead of transform snapshots; `TemporalEcho` becomes a **second pop_sim participant** replaying inputs (true input-level determinism, stronger than the current transform replay). Config (8 s/1 echo, 12 s/2 echoes) unchanged |
| Puzzle framework (`Activator`, plates/levers/runes → doors/gates) | **Kept as-is**; sim emits `plate_pressed(tile)` etc., the framework listens |
| `EnemyBase` + 4 archetypes | **Kept**; Palace Guard + boss eventually ported to sim-side duels, hoverers stay Godot-side |
| `LevelBuilder` + `level_catalog.gd` | **Kept**; extended with room-grid data |
| HUD/menus, `EventBus`, palette, verify.sh + tests | **Kept unchanged** |
| Procedural `_draw()` everything | **Kept for environment/props; replaced for prince + guards** by Aseprite sprites (your hybrid choice) |

---

## 5. Stage A — Faithful rebuild (phased tasks)

> Effort key: each task is sized for evenings. Sum of [M] tasks ≈ 38–42 h vs. ~30–35 h
> available: §6.0's parity-core vs. menu is what reconciles this — when behind, cut from
> the bottom of A4/A5 first, never from A1–A3.

### A1 — Study data extraction (reference → notes) · ~5 h · [M]

- [x] **A1.1 [M]** Build the level-format reader:
      `tools/pop_level_to_notes.py` parses `SDLPoP-1.23/data/LEVELS/res2000.bin`–
      `res2015.bin` (2305-byte `level_type`: `fg` at 0, `bg` at 720, `roomlinks` at 1696,
      `start_room/pos/dir` ~1721, `guards_*` ~1726 — offsets per `types.h:236–263`).
      **Deliverable:** emits `study/level_N.txt` grids per level (rooms × 10×3 tiles +
      modifiers + guard placements).
      **Accept:** output for level 1 shows the known opening (start room with floor/
      gate/mirror placements matching `--screenshot-level` of SDLPoP).
      *Note: the .bin files inside SDLPoP's data dir are the unpacked level structs —
      verify by size + tile sanity, fall back to parsing the DATs via the seg009
      decoders only if they're actually compressed.*
      **Session 000 note (corrected in Session 003; the pre-correction text stays in
      commit `02c6a29`):** built and run. Offsets in the shipped extractor differ from
      the plan's draft offsets (the plan's `~1721`/`~1726` were placeholders). The
      Session 000 run reported `roomlinks` at 1850, `used_rooms` at 1984, start fields
      at 2048–2050, guards at 2055+, and "used_rooms=22, start_room=25, start_pos=17,
      start_dir=16" for level 00 — **those offsets and values were misreads, disproven
      in Session 002.** Correct offsets (re-derived from the packed `level_type`; field
      walk sums to 2305 = the sizeof assert): doorlinks1 1440, doorlinks2 1696,
      roomlinks 1952, used_rooms 2048, start 2112–2114, guards 2119+; level 00 is
      start_room=1, start_pos=9, start_dir=−1 with used_rooms raw 25 → clamped 24 —
      regression-pinned by the extractor's `--selftest`, which also carries a negative
      control on the old offsets. The robustness note stands: `res2015.bin` is 2304
      bytes (padded on read) and several files have non-canonical used_rooms bytes; the
      extractor emits partial notes and continues rather than aborting.
- [x] **A1.2 [M]** Extract & tabulate, into `study/` (local, untracked) then
      `docs/PARITY.md` (tracked, facts only): run-cycles (per-frame dx from
      `seqtbl.c` startrun/runcyc), standing-jump and run-jump frame/dx/dy streams,
      hang/climb geometry, fall thresholds, spike cycle, gate speeds, plate/link
      timing, guard skill tables, sword frame windows (strike/block/parry frame
      numbers), tick clock.
      **Accept:** `docs/PARITY.md` has a table for each; every number carries its
      source (file:line in SDLPoP) *as a citation*, no code pasted.
      **Session 000 note:** not started. Took the A1.1 extractor output as a starting
      point, but A1.2's behavioral tables (run-cycles, jump streams, fall thresholds,
      spike/gate/plate timings, guard skill, sword frames, tick clock) are not yet
      extracted. Also, Q1 blocks moving any SDLPoP-derived constant out of study/ and
      into tracked `pop_tables.gd` or `docs/PARITY.md`.

### A2 — Sim core · ~8 h · [M]

- [x] **A2.1 [M]** `pop_tables.gd`: tile enum (your names, ids mapped 1:1 to original
      semantics), frame tables for the needed ~30 kid frames (dx/dy/flags), sequence
      table ops interpreter data.
      **Accept:** pure data file; no logic; peer-checkable against PARITY.md.
- [x] **A2.2 [M]** `pop_sim.gd` + `pop_rng.gd` + `pop_input.gd`: step function covering
      stand/run/turn/stop, soft/medium land, standing jump, run jump, fall, spike
      contact, floor-tile edge snapping (`y_land`/`x_bump` equivalents).
      **Accept (tests, added to `tests/test_main.gd`):** determinism double-run hash
      equality; run-jump covers 2 tiles and standing jump 1 tile of horizontal
      distance (the original's canonical gaps, cross-checked in PARITY.md); falling
      3 rows kills, 2 rows costs 1 HP.
- [x] **A2.3 [M]** Add hanging/climbing (up/down, release, hang-straight) +
      crouch + safe-step edge probing.
      **Accept:** scripted inputs can climb out of a 1-tile pit and hang-grab from a
      fall (reproduce SDLPoP grab rule: shift pressed while falling, tile ahead-above
      grabbable).
      **Status (ticked Session 005):** sim-verified with PARITY-derived frame counts;
      scenario geometry unmeasured; safe-step at edge distance 0 unmodeled; SDLPoP
      observation pending.

### A3 — Presentation shell · ~6 h · [M]

- [ ] **A3.1 [M]** `SimClock` (12/10 fps switching on sword-draw) + `pop_view.gd`
      render/interpolate a SimState; placeholder procedural visuals first.
      **Accept:** a debug scene (`scenes/pop/pop_lab.tscn` — a sandbox level) runs at
      60 fps render / 12 fps sim; stepping key frame-advances one sim tick.
- [ ] **A3.2 [M]** Wire real input (`InputActions`) into `pop_input` latching.
      **Accept:** keyboard play of the sandbox feels correct; input latency ≤ 1 sim
      tick + ≤ 1 render frame.
- [ ] **A3.3 [N]** First Aseprite sprite pass for the prince imported as PNG frames,
      indexed by the sequence table. (Blocker for nothing; can slide into B.)

### A4 — Traps, tiles, duels · ~12 h · [M except as marked]

- [x] **A4.1 [M]** Gates, plates (opener/closer + doorlink data), level-exit door in
      sim + `pop_level.gd` room grid loading.
      **Accept:** a test level exercises plate→gate open/close timing within ±1 tick
      of measured values.
      **Status (ticked Session 005):** met — plate→gate open 47±1 / close 238±1,
      exit door 3 ticks, plate timer 5, all read from PARITY §9/§10 (`_test_a41_entities`).
      The ±1-tick windows are against the cited values, not an [O] observation (P6 ◐).
- [x] **A4.2 [M]** Spikes (cycle + harmful-state rules), loose floors (shake 11,
      fall, crush), chompers.
      **Accept:** replayed testcases reproduce documented outcomes; unit tests assert
      modifier-state transitions from PARITY.md tables.
      **Status (ticked Session 005):** met — spike cycle 1…4→0x8F→6/7/8→0 over 23
      ticks and the loose-floor 11-frame delay / 0x80–0x83 shake band / chomper
      15-frame cycle are all asserted from PARITY §8/§11, with replayed spike kill/safe
      runs and a live falling-block crush. Crush uses PARITY §7 fall integration as the
      block's fall rate (marked placeholder — the block's rate is not in PARITY §11).
- [x] **A4.3 [M]** Guard duel at 10 fps: en-garde, advance/retreat, strike/block/parry,
      per-skill probability tables through `pop_rng`, HP/refractimer, spiked/chomped
      deaths for both parties.
      **Accept:** scripted duel inputs vs. skill-0 guard win/lose deterministically;
      re-run with `seed=N` produces identical duel transcripts (asserted in tests).
      **Status (ticked Session 006):** met — reach gated by `char_opp_dist` (new
      PARITY §20: hits inside [8|12, 29), f154 only damages), the `seg002.c:737-899`
      decision bands with draws only where the reference draws, §13 walk-chain dx
      (+6 forward / −5 back), and spike/chomper death checks on both fighters every
      tick. Same seed → identical transcript and outcome, different seed → different;
      the attack script resolves (winner kid after 35 ticks). Source-matched with
      `file:line`, not observed against SDLPoP (`_test_a43_duel`, 413/0).
- [ ] **A4.4 [N]** Loose-floor pinging via the mob system (falling tile carries
      between rooms).
- [ ] **A4.5 [N]** Potions (+1 HP, +max) and the skeleton (skip if time).

### A5 — Parity verification · ~7 h · [M for the core, N beyond]

- [x] **A5.1 [M]** Parity harness v1 (headless): run your sim under a fixed input
      script on a hand-built replica of *one* original room's **grammar** (not layout):
      assert jump-distance, hang-frame-count, spike-survival, gate-timing invariants.
      **Accept:** all assertions green in `./verify.sh`; PARITY.md tables updated with
      "measured-in-ours vs measured-in-SDLPoP" columns.
- [ ] **A5.2 [M]** Side-by-side video evidence (OBS: SDLPoP and pop_lab playing the
      same maneuver) — 30 s clip kept in `study/` for the presentation.
- [ ] **A5.3 [N]** Full replay-based parity: encode one of SDLPoP's
      `doc/replays-testcases/*.p1r` input tracks against a rebuilt-equivalent level and
      compare tick-by-tick outcomes. (High value, high effort — cut first.)
- [ ] **A5.4 [N]** Parity on 2–3 original levels' *behavior summaries* (your A1 grids
      walked by scripted inputs, comparing event traces). This is the honest version of
      "faithful rebuild of levels" at your time budget: same *behavioral checklist*,
      original layouts left behind.

**Stage A exit criteria (all [M]):** sandbox playable with sword-duel and traps;
determinism test green; PARITY.md populated for all §4.3 items; A5.1+A5.2 delivered.
*Everything else in A4/A5 is the cut line.*

---

## 6. Stage B — Echoes of Time on the faithful core

### B0 — The bridge decision (do this before B1) · ~2 h · [M]

- [x] **B0.1 [M]** **Rebase the game on the sim.** New main gameplay = pop_sim running
      the (re-themed) game; enemies/echoes/puzzles consume sim events. Ship both paths
      behind a boot flag (`--legacy-physics`) until B2 is verified so the current
      vertical slice stays runnable for the video if the worst happens.
      **Accept:** `./verify.sh` green on both paths; new path passes a full
      play-through of a single hand-built level.
      **Keep / refactor / discard summary** (from §4.6): keep echo manager, puzzles,
      enemies, HUD, levels-as-data; refactor recorder/echo to input-byte replay;
      replace player controller; discard freeform-motion tuning.
      **Status (ticked Session 009):** met on both Accept clauses — `./verify.sh`
      boots every sim level via `SimWorld` AND every legacy level behind
      `--legacy-physics`, then runs the suite green on each path (490/0,
      ALL CHECKS PASSED); `_test_b0_completability` scripts a full play-through of
      the hand-built room-grid level (run-jump the pit → grab → climb → plate →
      gate → exit, dead=0). Honest caveat: echoes and puzzles consume sim events,
      but no in-level enemy listens to sim events yet — the gate-5 level has no
      combat and the Godot-side enemy scripts don't subscribe to `player_moved`
      (PopGuard exists; the wiring is B1.3/B3 territory). The legacy stack is
      untouched behind the flag.

### B1 — Temporal Echo, input-level · ~6 h · [M]

- [x] **B1.1 [M]** `TemporalRecorder` v2: record `pop_input` bytes per sim tick into a
      bounded ring (8 s = 96 bytes at 12 fps — trivially small). Keep current event
      attachment (interact presses as `special` bits).
      **Accept:** recorder tests updated; buffer cap enforced; determinism test now
      replays *through a live sim* not transform lerp.
      **Status (ticked Session 009):** met — `TemporalManager.record_sim_tick` pushes
      one input byte + event vector + milestones per tick into the PopReplay ring;
      tests updated (one-byte-per-tick capture; cap test asserts the hard stop at
      `RING_CAPACITY` with `take.size() == 96`); the 96-byte cap is enforced (ring
      eviction + `at_capacity` stop); determinism replays through a live sim (echo
      state hash == a manual `PopSim.step` loop over the recorded bytes). Event
      attachment kept: `record_event` → `_sim_pending_events` → per-tick milestones;
      the byte's `special` field exists but the sim latch doesn't set it — event ids
      ride milestones instead (noted, not a silent gap).
- [x] **B1.2 [M]** `TemporalEcho` v2: a full second sim participant replaying input
      bytes from release moment; final-pose hold preserved (non-loop default);
      echo-only rune, plate weight, enemy-targetable — all existing behaviors keep
      working via the same signal surface.
      **Accept:** existing 116 assertions still pass with v2 in place (they assert
      exactly the behaviors that must survive); new test: two echoes from the same
      input buffer produce identical plate-timing events.
      **Status (ticked Session 009):** met — `TemporalManager.spawn_sim_echo` spawns a
      `SimEcho` (second sim participant stepping `PopSim.step` from the release
      moment, final-pose hold asserted); the legacy snapshot path stays intact for
      `--legacy-physics`, and the full suite (490/0 — the old 116 are a subset) passes
      with v2 live; new test: two echoes from the same input buffer produce identical
      plate-timing events (press:0,16 + open:0,19; two echoes hash-equal). The
      rune/plate/enemy-targetable behaviors ride the unchanged signal surface
      (`echo_created`/`echo_expired`/`echo_event_replayed` asserted unchanged); the
      sim-side plate visibility for an echo is B1.3's scope, not this item.
- [x] **B1.3 [M]** Echo visibility to *sim-side* mechanisms (plates in sim) + to
      *Godot-side* enemies (unchanged); energy economy and capacity unchanged.
      **Accept:** level-1 tutorial puzzle solvable identically to today's design.
      **Status (ticked Session 010):** met — `SimWorld` steps sim echoes before each
      tick's entity stage and feeds every echo's foot tile through
      `PopLevel.press_plates_for` (position only, read-only; SimWorld stays the single
      writer). The mechanic rests on a **held-plate parity fix**: the reference
      re-triggers a held plate's links every held tick (`seg007.c:764`), re-parking
      the gate at 238 until the body steps off — our old one-shot press diverged;
      fixed with a regression test (park on tick 46, stays ≥188 while held, §9 close
      resumes on step-off). Level-1 tutorial puzzle proven solvable identically via
      the echo path (`_test_b13_echo_plate`: the world's event stream shows the
      ECHO's re-press, the gate never closes while it holds, the kid walks through
      to the exit door). Godot-side (legacy) enemies untouched and green; energy
      economy and capacity unchanged (stock config restored in tests; existing
      assertions pass). Suite 539/0, both boot paths clean.

### B2 — Echo-aware level re-theming on PoP kinematics · ~10 h · [M]

Rebuild 3 levels (cut from 5 — see §10) as room-grid data in the new schema, each
*informed by* the original's grammar (your own layouts; A1 notes as pacing reference):

- [ ] **B2.1 [M]** Level 1 — "The Collapsing Gate" (teaches: run/jump/hang + spikes +
      the first echo; no combat). Tile-art pass on environment.
      **Accept:** completable by a human in ≤3 min; echo puzzle is mandatory.
- [ ] **B2.2 [M]** Level 2 — "Hall of Echoes" (one recording, two mechanisms — the
      thesis; introduce the sword + skill-0 guard duel on PoP's 10-fps fight rules).
      **Accept:** same as B2.1 + duel teaches block/parry safely.
- [x] **B2.3 [M]** Level 5' — "The Time Warden" (boss: shield drops only while an echo
      holds the arena plate; boss duel uses the guard-skill framework at high skill).
      **Accept:** boss beatable only via echo; fight ≤3 min; no softlocks on echo
      expiry (respawn logic tested).
      **Status (S011 step 4; asserted in `_test_b23_level3_boss`):** shipped as
      the trimmed L3 (D15 renumber; catalog `sim_boss` — every level number
      lives there). `SimBoss` = `SimGuard` + the echo-gated shield; negative
      run: solo kid, no take — the shield NEVER drops and the boss never loses
      a point (provably pinned); the scripted run completes the level END TO
      END — the Warden falls, the plate-linked exit gate parks open, the kid
      walks into the exit door (`level_completed` asserted; the fight fits one
      take and the plan's 3-minute cap); expiry → shield returns → re-record
      → finish tested (no softlock). Boss skill = the highest measured-
      winnable skill (D18; B3.1's ~7–9 clause stays open). Completability is
      scripted; fairness and feel need the human playtest.
- [ ] **B2.4 [N]** Level 4' two-echo sanctum (12 s / 2 echoes tier) — cut from must-
      have; the *engine* supports it, add only if ahead of schedule.
- [ ] **B2.5 [M]** HUD + boss bar re-skin to new art; checkpoint respawns audited for
      the new geometry.

### B3 — Combat & boss changes (real-time, echo-gated) · ~4 h · [M]

- [ ] **B3.1 [M]** Boss = guard-archetype at skill ~7–9 with shield gating (existing
      `time_warden.gd` logic) but fighting through the sim duel rules.
      **Accept:** shield-nullified hits asserted in tests (existing boss tests ported).
      **Status (S011 step 4; UNTICKED — partial):** the guard-archetype boss
      with shield gating on the sim duel rules shipped (SimBoss, B2.3 above)
      and shield-nullified hits ARE asserted in tests — but at the highest
      measured-winnable skill, not ~7–9: every probed higher skill's pacing
      beat the scripted kid inside its starting hp, so a ~7–9 config needs a
      stronger scripted tactic or a design lever (D18 proposes an accept-
      clause amendment for the user's approval — pending). Legacy
      `time_warden.gd` tests were not ported (new SimBoss tests written
      instead). Remaining: the ~7–9 probe + the ported-test clause.
- [ ] **B3.2 [M]** Hoverer archetypes (Shadow Echo, Temporal Sentinel) re-target
      sim-based entities; their motion stays Godot-side.
      **Accept:** baiting via echo still works (existing enemy tests).
- [ ] **B3.3 [N]** Hit-stop, screen shake, echo-distortion shader polish.

### B4 — Audio & art completion · ~6 h · [M]

- [ ] **B4.1 [M]** SFX set via jsfxr covering the `internals_sounds.csv` cue list
      subset you ship (footstep, land soft/med/hard, spike, gate open/close, plate,
      sword clash/strike/hurt, death, echo record/release, potion) → `audio/sfx/*.wav`,
      each logged in `docs/ASSET_LICENSES.md`.
- [ ] **B4.2 [M]** Music: 2 LMMS loops (title/explore, boss/tension) → OGG; logged.
- [ ] **B4.3 [M]** Echo audio identity: record-start rising tone, release resolve,
      hollow EQ on echo SFX (GDD §14).
- [ ] **B4.4 [M]** Aseprite final passes: prince (run/jump/hang/fight sets), guard,
      warden; environment procedural polish.
- [ ] **B4.5 [N]** Ambient room tone; echo afterimage shader.

### B5 — Ship build · ~5 h · [M]

- [ ] **B5.1 [M]** Export presets: Linux + Windows (no machine paths committed);
      validate both binaries boot → menu → level 1 → level 2 → boss.
- [ ] **B5.2 [M]** Title screen, controls screen, pause, level-complete, victory
      (all exist — re-skin + text pass; ensure no "Prince of Persia" trademark in-game
      beyond the descriptive subtitle; title: **"Echoes of Time"** with "inspired by
      the 1989 classic" in credits, per §2.3).
- [ ] **B5.3 [M]** Gameplay video <2 min (OBS capture of a scripted run: tutorial →
      thesis puzzle → duel → boss; Kdenlive edit; music bed).
      **Accept:** 119 s max, 1080p, shows all four deliverable-worthy systems.
- [ ] **B5.4 [M]** Update GDD (§8 mechanic now input-replay; §11 levels; §17
      reinterpretation table), QA_REPORT (new defect log), PRESENTATION (9 slides
      updated; add the A5.2 side-by-side clip as the "Reimagine" proof).
- [ ] **B5.5 [M]** Final `docs/ASSET_LICENSES.md` audit re-run (the find-command block
      in that doc) + parity doc cross-linked.
- [ ] **B5.6 [N]** Gamepad bindings (keyboard-only is acceptable for submission).

---

## 7. Asset plan

**Rule: if it's in the shipped build, it's either generated by your code at runtime or
it has a row in `docs/ASSET_LICENSES.md` created *before* it was committed.**

| Asset | What / spec | Made with | Who | License record |
|---|---|---|---|---|
| Prince sprite set | ~30 sequences × 2–8 frames, 64×96 px, 4-direction facing (flip), palette-locked to `palette.gd` | Aseprite (LibreSprite fallback) | You | Original; SHA + date logged |
| Guard sprite set | Duel set (en-garde/advance/retreat/strike/block/parry/hit/death) + idle | Aseprite | You | Original; logged |
| Time Warden | Larger variant of guard set + shield FX frames | Aseprite | You | Original; logged |
| Environment tiles | TileSet: floor/wall/gate/spike/loose/plate/exit/door-top/torch in two themes (dungeon/sanctum) | Godot TileSet authoring + procedural helpers (existing `platform.gd` style) | You | Original; logged |
| Echo FX | Trail afterimages, release flash (shader + frames) | Godot shaders/particles | You | Original; logged |
| UI/HUD | Bars, icons, title glyph | Godot Control drawing + Aseprite icons | You | Original; logged |
| SFX (~20 files) | One per shipped cue | jsfxr | You | Original; logged |
| Music (2 tracks) | 60–120 s loops | LMMS | You | Original; logged |
| Font | Godot default font only (MIT) | — | — | Already recorded |
| Engine | Godot 4.7.2 | — | — | MIT; already recorded |

**Explicitly NOT in the build:** any byte from `4dprinceprsia/` (sprites, audio, title
art), any text/level data from the original, any SDLPoP code or its text docs verbatim.
Reference-derived *numbers* appear only as cited constants in `pop_tables.gd` and as
tables in `docs/PARITY.md`.

- [ ] **[M]** License-record template row created for each category above in
      `docs/ASSET_LICENSES.md` (the file already has the table — fill as assets land).
- [ ] **[M]** `icon.svg` updated if the visual identity shifts (keep hand-authored).
- [ ] **[N]** Aseprite source files under `art/src/` (untracked or LFS-free, your
      call — PNG exports are what Godot imports).

---

## 8. Testing and parity verification plan

**Existing (keep, extend):** `./verify.sh` = import gate → 5×level-boot gate (400
frames headless) → 116-assertion suite; exits non-zero. Keep all of it; add:

**New gates (in order of appearance in `tests/test_main.gd`):**

1. **[M] Determinism gate** — fixed seed + fixed 600-tick input script, run twice,
   state-hash equality; also run with the *same* script from two seeds to prove seeds
   matter. (§4.5 rule 5.)
2. **[M] Kinematics parity table test** — for each PARITY.md row: run-jump distance ∈
   [measured ± 1 tile-edge unit], hang duration exact in ticks, fall-damage thresholds
   exact, spike cycle length exact, gate speeds exact.
3. **[M] Duel transcript test** — scripted duel vs. skill-0 guard, assert strike/block
   outcomes and HP deltas across 300 ticks, twice, equal.
4. **[M] Echo replay gate v2** — record 5 s, release echo, run 300 ticks, capture
   (plate states, lever states, enemy targets); repeat; assert identical vectors.
   Then flip one input bit in the recorded buffer mid-take → assert the run diverges
   (proves the buffer is actually the causal input).
5. **[M] Level completability smoke** — scripted input plays each shipped level to its
   exit/boss-defeat event headless. (Doesn't prove *fun*, does prove *finishable*.)
6. **[N] SDLPoP edge-case replays** — port 2–3 `.p1r` testcases (e.g. grab-bug
   scenarios in `doc/replays-testcases/`) to equivalent inputs on replica rooms; assert
   your sim's behavior matches *vanilla* (fixes off) or *fixed* (fixes on) — your
   choice, documented per-case.

**CI (GitHub Actions):** `.github/workflows/verify.yml` —
`ubuntu-latest`, `./verify.sh` on push/PR. Accept: green on first configured run.
Note: Windows runner not needed for tests (headless suite is platform-neutral);
Windows validation stays a manual export-boot step.

**Manual playtest protocol (before submission, non-negotiable):** a full playthrough on
the Linux build with a written defect log (extend `docs/QA_REPORT.md`'s BUG-xxx
format); minimum: 3 completions of level 1, 2 of level 2, 2 boss kills, timing each.
Then the same on the Windows export.

---

## 9. Competition deliverables plan (working backward from 2026-10-31)

Budget: **~34 h** (7.5 h/week × 4.5 weeks). Weeks are Mon–Sun.

| Week | Dates | Focus | Exit checkpoint |
|---|---|---|---|
| **W1** | Oct 6–12 | **Stage A1 + A2 + A3**: study extraction, sim core, sandbox shell, determinism test; repo cleanup (§2.4); CI online | Sandbox playable headless + visual; PARITY.md v1; refs removed from repo |
| **W2** | Oct 13–19 | **Stage A4 core + A5.1/A5.2 + B0/B1**: traps+gates, duel, parity harness, rebase game on sim, Echo v2 | Stage A exit criteria met; one level playable on new core |
| **W3** | Oct 20–26 | **Stage B2 ×3 levels + B3 + B4.1–4.3 (audio), B5.1 exports** | All 3 levels completable; SFX in; Linux+Windows builds validated |
| **W4** | Oct 27–30 | **B4.4 art, B5.3 video, B5.4 docs, playtests, B5.5 audit, freeze** | Video cut; GDD/slides updated; both exports boot-tested; suite green |
| **Deadline** | Fri Oct 31 | Buffer day: final package (build + video + GDD + slides + license record), submit early | Submitted |

**Slack math:** [M] tasks total ≈ 40 h against ~34 h available → the plan must lose
~6 h. Cut order (decide dynamically, never violate Stage A exit criteria): A4.4 →
A4.5 → A5.3 → A5.4 → B2.4 → B3.3 → B4.5 → B5.6 → (last resort) A3.3 sprite pass
slides to procedural, notes recorded for post-competition.

**Deliverable definitions (done means):**

- [ ] **[M] Playable build:** Linux + Windows exports, boot-validated, title→victory
      without developer cheats, controls documented on the title screen.
- [ ] **[M] Gameplay video:** <2:00, 1080p, watermark-free, shows echo recording/
      release, a two-mechanism echo puzzle, a duel, the boss; music + SFX audible.
- [ ] **[M] GDD:** updated to describe the shipped game (not the aspiration);
      adds a "measured from the original" appendix citing PARITY.md.
- [ ] **[M] Presentation:** 9 slides (existing outline), updated: 1 title/hook, 2 the
      1989 DNA (side-by-side clip), 3 Temporal Echo (input-replay), 4 combat/duel, 5
      levels+pacing, 6 boss, 7 tech (12 fps sim + determinism), 8 playtest/QA story,
      9 credits/licensing (the audit as a selling point).
- [ ] **[M] License record:** `docs/ASSET_LICENSES.md` complete with every shipped file.

---

## 10. Risks and mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **Legal:** original assets (sprites/audio/layouts) leak into the build; or GPL code is transliterated | Med | Fatal (disqualification / takedown) | Hard boundary file (`pop_tables.gd` constants only, cited); converter emits *notes* not game data; repo purge in W1; license audit re-run in B5.5; §11 Q1 answered in writing before any SDLPoP-derived data ships |
| R2 | **Time:** Stage A fidelity eats the calendar | High (planned: 40 h [M] vs 34 h) | High | Parity-core vs menu defined up front (§5/§9 cut order); B0 keeps the existing slice runnable as video fallback |
| R3 | **Determinism:** echo replay diverges after the rebase (unsorted containers, float leaks into state, engine-side randomness) | Med | High — core mechanic breaks | Sim is pure + integer; RNG only inside sim; determinism gate is the *first* test written; one-input-bit-divergence test proves causality |
| R4 | **Feel mismatch:** rebuilt movement doesn't "read" as PoP despite correct constants | Med | High for the competition story | A5.2 side-by-side video as a recurring check (weekly); interpolation quality pass is scheduled, not assumed; hold-on-grab and edge-snap rules prioritized — they carry most of the "cinematic" feel |
| R5 | **Solo-dev bug drought:** no second pair of eyes | Med | Med | Extend the BUG-xxx QA discipline; scripted-playtest protocol (§8); headless gates catch regressions the eye won't |
| R6 | **Scope creep in levels** (re-theming 3 levels becomes a redesign spiral) | Med | Med | Levels are *data* in an existing wired framework; B2 acceptance criteria are time-boxed (≤3 min completability), layouts drafted on paper/grid first using A1 grammar notes |
| R7 | **Export breakage** (Windows templates on Linux, missing DLLs, audio driver differences) | Low-Med | High if late | B5.1 in W3, not W4; boot-script both binaries; keep `--level=N` CLI as the fallback diagnostic |
| R8 | **Audio dud** (jsfxr SFX clash with LMMS loops) | Low | Med | One shared palette pass in B4.3; if time collapses, ship SFX-only (video still lands) |
| R9 | **Competition-rules ambiguity** (originality standard; whether "measured constants" disclosure is required; team-size rules) | Low-Med | Med-High | §11 Q1/Q3 — get written clarity; keep the provenance record clean enough for any standard |
| R10 | **Godot 4.7 export-toolchain regression** (4.7.x patch differences between your editor and CI binary) | Low | Med | Pin `GODOT_VERSION` in verify.sh (already `4.7.2-stable`); use the same version for exports |

---

## 11. Open questions and tool requests

**Decisions I need from you (blocked items flagged):**

1. **[BLOCKS A5/A1 citation policy] Competition originality standard.** Does RRR's
   "original or properly licensed assets" rule tolerate (a) behavior constants measured
   from a GPL source with written citation, and (b) no formal license for the *inspired*
   design? Read the actual rules text; if the rule requires all-original *code*, our
   clean-room approach already complies, but confirm there's no "no disassembly-derived
   data" clause. Also confirm: does the jury check the repo, or only the build?
2. **[BLOCKS §2.4] Git history for the reference folders.** Removing them going forward
   leaves them in old commits of a public repo. Options: (a) accept history (files stay
   discoverable), (b) history rewrite (filter-repo) + force-push — destructive, breaks
   any clones, (c) make repo private now, strip, re-publicize. My recommendation: (c)
   if possible, else (b) before W2. Which?
3. **[BLOCKS §5 A5.3] Do you want SDLPoP's `.p1r` edge-case replays ported as formal
   parity tests** (strongest "understood the original" evidence, ~4 h), or is the
   measured-table + side-by-side video enough? Default plan: nice-to-have.
4. **[BLOCKS B4.2] Music ownership:** confirm LMMS-composed-by-you is the plan (vs.
   CC0 sourcing) — it changes the W3/W4 split if sourcing. Also: is there any music you
   already have rights to that you want to use?
5. **Aseprite budget:** if the €0 constraint matters, confirm LibreSprite as the
   substitute so W2's A3.3 isn't blocked by a license purchase.
6. **Title/trademark posture:** in-game title "Echoes of Time" with the inspiration
   credit in the credits screen (my recommendation, §B5.2) — or do you want "Prince of
   Persia:" kept in the *game* title (not recommended; Ubisoft trademark exposure, and
   README/GDD would need a disclaimer block)? The competition title page can still say
   the full name either way — confirm which.

**Tool requests (install list, Linux):**

- [ ] `ripgrep`, `python3` (already present for verify.sh) — A1 converter.
- [ ] Aseprite (or LibreSprite) — W2+.
- [ ] LMMS — W3.
- [ ] OBS Studio + Kdenlive — W4.
- [ ] Godot 4.7.2 export templates (Linux + Windows) — W3.
- [ ] SDLPoP runnable build for parity work: `cd SDLPoP-1.23/src && make` (needs
      `libsdl2-dev libsdl2-image-dev`) — **run locally only**, never commit artifacts.
- [ ] GitHub Actions enabled on the repo (free tier is sufficient).

**Standing decisions this plan makes without asking (veto anything):** cut levels 3–4
from the shipped set (engine keeps supporting 5; content ships 3); keep keyboard-only
controls; keep session-only checkpoints; no web export; no gamepad; 12 fps sim +
interpolated render; GPL-clean-room citation policy for constants.

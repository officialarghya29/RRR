# PRESENTATION — 9 SLIDES
## Prince of Persia: Echoes of Time

*RRR — Rewind. Reimagine. Reconnect.*

**Draft for review — Session 013.** Slide count is **9**, inside the 10-slide limit,
in the order the plan's deliverable list specifies (§9: title/hook → 1989 DNA →
Temporal Echo → combat/duel → levels+pacing → boss → tech → playtest/QA →
credits/licensing). Each slide carries on-screen copy and speaker notes.

> **Standing rule:** every claim on these slides must correspond to something that
> actually runs in the build. Numbers are **pointers**, not quotes: cite
> `docs/PARITY.md` (measurements), the level catalogue (content) and `review.md`
> (status) rather than restating figures that will drift. Status of each
> deliverable is tracked in [`QA_REPORT.md`](QA_REPORT.md).

**What only the user can supply (marked ⛅):** gameplay **screenshots** (the
7-shot checklist lives in `review.md`, Session 013) and the **A5.2 side-by-side
clip** (original-vs-ours, user-manual by decision). Slides marked ⛅ read fine
without their image but land harder with it.

---

## SLIDE 1 — Title and hook

**On screen**

> # ECHOES OF TIME
>
> ### *"Master your past to survive your present."*
>
> **Event:** RRR — Rewind. Reimagine. Reconnect.
> **Original inspiration:** Prince of Persia (1989)
>
> ⛅ [screenshot: level 1 mid-run]

**Speaker notes**

Open with the hook, not the backstory. One sentence: *"You play a man who can make
his own recent past real — and solve problems with a version of himself that he
choreographed thirty seconds ago."* Then stop talking and let slide 3 do its work.

---

## SLIDE 2 — The 1989 DNA (side-by-side)

**On screen**

> ### PRINCE OF PERSIA (1989) — WHAT WE KEPT, WHAT WE TOOK
>
> | Kept (design DNA) | Taken (assets) |
> |---|---|
> | side-scrolling palace traversal | **nothing** |
> | precision platforming, lethal traps | **nothing** |
> | sword combat, hostile architecture | **nothing** |
> | 12 fps traversal / 10 fps duel feel *(measured — PARITY §2)* | — |
>
> ⛅ [A5.2 clip: original beside ours, same framing]
>
> *The connection is design. Everything else is new.*

**Speaker notes**

Be direct early — this is the question judges are already asking. The tick rates on
the slide are **measured** values from the study pass and are cited in
`docs/PARITY.md` §2; we rebuilt our simulation core to *run* at those rates so the
game feels like the original in your hands, without a single original byte.
Point at `docs/ASSET_LICENSES.md` for the one-command audit. If the A5.2 clip is
ready, play it silently under this slide and let the framing speak.

---

## SLIDE 3 — The Temporal Echo *(the important slide)*

**On screen**

> ### ONE RECORDING. TWO JOBS. NO PLAYER CAN DO IT ALONE.
>
> ```
>  press Q ──▶ record    (input bytes, stamped events, capped take)
>  press Q ──▶ release   (a second deterministic run — a real entity)
>
>     ┌─ the echo replays your exact inputs, every time ──┐
>     │  stands where you stood · holds its final pose    │
>     │  presses plates · visible to mechanisms, not walls│
>     └──────────────────────────────────────────────────┘
> ```
>
> ⛅ [screenshot: level 2 with an active echo]
>
> **"What if your past could fight beside you?"**

**Speaker notes**

This is the thesis. Three things a screenshot cannot show:

1. **It is a real second simulation, not an afterimage.** The echo replays the
   recorded *input bytes* through the same deterministic step function from a state
   snapshot — the suite pins that the same take always produces the same run.
2. **It holds its final pose** — which makes *"stand on the plate and leave a
   memory there"* a stable solution rather than a lucky one.
3. **It is limited** — energy cost, capacity cap. The player cannot spam out of a
   puzzle.

Then the concrete example: in level 2 the echo is **mandatory** — the level is
scripted both ways headlessly (completable with the echo, provably pinned without
it). Cite the test, don't quote the number.

---

## SLIDE 4 — Combat and the duel

**On screen**

> ### COMBAT THAT PUNISHES POSITIONING
>
> three-beat attacks · directional block · committed dodge
>
> **The duel** — sword timing rebuilt at the original's 10 fps duel tick
> *(measured: PARITY §12–§14 — decision odds, HP, sword frames, RNG draw order)*
>
> **Bait with a memory:** enemies treat your echo as a target.
>
> ⛅ [screenshot: mid-duel, or the boss bar engaged]

**Speaker notes**

Combat exists to reinforce the puzzle skill, not compete with it: wind-ups are long
enough that damage taken is a positioning error. The duel is the parity showpiece —
every decision band, HP value and sword frame chain is cited from the study pass in
`docs/PARITY.md` §12–§14, including the RNG *draw order* the original used. Our
guards decide from those tables; same seed, same duel, every time.

---

## SLIDE 5 — Levels and pacing

**On screen**

> ### TAUGHT, NOT TOLD — THREE LEVELS, ONE IDEA EACH
>
> **The Sim Gate** — gaps → spikes → the plate you cannot outrun
> *the echo becomes an obvious necessity, with no tutorial text*
>
> **Hall of Echoes** — one recording, two mechanisms; the echo is mandatory
>
> **The Time Warden** — the thesis as a boss fight (slide 6)
>
> introduce → practice → combine → challenge → payoff
>
> ⛅ [screenshot: F3 overlay showing the sim grid — "levels are data"]

**Speaker notes**

The teaching method is the design point: no puzzle is solvable without understanding
the mechanic, and no tutorial text teaches it. If you show the debug-overlay
screenshot, use it to make the second point: levels are *data* — a catalogue entry
of tiles, entities and links — so pacing iterations never touch engine code.

---

## SLIDE 6 — The Time Warden (boss)

**On screen**

> ### THE THESIS, STATED AS A BOSS FIGHT
>
> The Warden is permanently shielded. Hits are absorbed. It never staggers.
>
> The shield drops **only while your released echo holds the arena plate** —
> and that plate sits outside your safe reach.
>
> - stand on the plate → safe, but you cannot fight
> - fight → the shield nullifies everything
>
> ⛅ [screenshot: boss bar — shielded glow vs. health red]

**Speaker notes**

Attrition cannot work by design. The only answer is to leave a memory holding the
plate and fight alongside your own past — and when that echo expires mid-fight, the
shield returns and you must author a new one *under fire*. The scripted run does
exactly that end to end, including the expiry-and-re-record path, so there is no
softlock. Honest note if asked about difficulty: the shipped duel skill is the
highest one our scripted fight measurably wins — feel tuning awaits the human
playtest, and a harder variant is an open, recorded decision.

---

## SLIDE 7 — Technology: 12 fps simulation + determinism

**On screen**

> ### GODOT 4.7 · GDSCRIPT · ZERO DEPENDENCIES
>
> ```
> PopSim         deterministic, engine-free core
>                12 fps traverse · 10 fps duels (measured: PARITY §2)
> Input-byte echo  a recorded take = input bytes + stamped events
>                  release = a second run of the SAME step function
> SimWorld        the single writer of sim state; views only read snapshots
> verify.sh       import → boot every level, both paths → three suites
> ```
>
> ### VERIFIED, NOT ASSUMED — and reproducible: same seed, same run, forever.

**Speaker notes**

The differentiator is not "we wrote tests" — it is that the *game core is a pure
function*. Because the simulation is engine-free and steps from a packed input
byte, a recording is not stored state: it is the inputs, and replaying it is
re-simulating. That is why the echo can never desync, why the boss shield cannot
stick, and why a whole playthrough can be scripted headlessly as a regression test.
The verification gate is one command; invite the judges to run it.

---

## SLIDE 8 — Playtest and QA story

**On screen**

> ### HOW WE KNOW IT WORKS — AND WHAT WE HAVEN'T PROVEN
>
> - every shipped level **completable by scripted input**, headlessly, in CI
> - determinism gate: identical seeds → identical runs, across RNG phases
> - defect log with root causes (`docs/QA_REPORT.md`) — incl. the one that made
>   the game **unwinnable while looking completely fine**
>
> ⛅ [screenshot: pause screen / victory screen]
>
> **Open, stated plainly:** feel and fairness await a human playtest —
> automation cannot verify joy.

**Speaker notes**

Tell the door-wiring story: the game booted, looked correct, and was impossible to
finish because one signal-bound signature mismatched. Only *executing* the wiring
found it — which is why the gate boots and plays levels, not just compiles them.
Then be honest about the boundary: scripted completability proves finishable, not
fun. That is the one claim no suite can make, and it is why the human playtest is a
first-class deliverable, not an afterthought.

---

## SLIDE 9 — Credits and licensing (the audit as a selling point)

**On screen**

> ### EVERY BYTE, TRACED
>
> - code, art, level design, story: original work for this project
> - visuals: drawn procedurally at runtime — no image files at all
> - audio: 14 procedurally synthesised SFX — no samples
> - licence record: `docs/ASSET_LICENSES.md` — **one command re-audits the tree**
>
> **Inspired by** Prince of Persia (1989), Brøderbund / Jordan Mechner.
> **Forked from** the RRR project (github.com/officialarghya29/RRR).
>
> **Run it:** Godot 4.7 → `project.godot` · **Verify it:** `./verify.sh`
>
> ### Connect to the original, and it will teach you something it never could.

**Speaker notes**

Close on the thesis, then hand them the check: the licence record is not a promise,
it is a *command they can run* — it lists every shipped binary asset, and the answer
is fourteen files we generated ourselves. Credit both debts plainly: the 1989 game
for the design language, and the upstream RRR project this work is a maintained fork
of. Then invite them to open the repo and run the gate — the claim is checkable.

---

## Appendix — likely judge questions

**"Isn't this just a re-skin?"**
No. The original's central system was a countdown; this one is a replayable, physical
recording. That change rewrites the core loop, the puzzle grammar and the level design
method — and slide 2's clip shows we even rebuilt the *clock rate* the original ran
at, measured from the study pass (`docs/PARITY.md` §2), without reusing a byte.

**"Did you copy any assets?"**
No. There are no image or font files in the project at all; the 14 audio files are
procedurally synthesised from code. `docs/ASSET_LICENSES.md` re-audits the tracked
tree with one command.

**"How do you know the echo system actually works?"**
The replay is a second deterministic simulation, so the suite scripts it both ways:
the level completes with the echo, and *cannot* complete without it (the pinned
state is asserted). Determinism is gated across RNG phases.

**"What isn't finished?"**
Stated plainly in slide 8 and in the README: feel/fairness need the human playtest,
music is deliberately cut (SFX-first trim decision), exports await template approval,
and the gameplay video is the user-manual deliverable.

**"What would you do next?"**
The human playtest first — it is the one instrument no suite can replace — then
exports, then the video cut, then a palette/feel pass on the SFX flagged as weak.

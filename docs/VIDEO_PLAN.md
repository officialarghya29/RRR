# VIDEO PLAN — the <2:00 gameplay capture
## Prince of Persia: Echoes of Time

**Target:** under 2:00 (hard limit — the brief says *<2 min*), 1080p, watermark-free,
game audio audible (the 14 procedural SFX; **no music** — D15, so the mix is SFX +
a light ambient bed only if you decide otherwise later).

**Owner rule:** steps marked **USER** need a human at the display (recording, final
cut). Steps marked **SESSION** can be prepared by a working session (the scripted
input run, scene automation, the draft cut if a headless frame pipeline is set up).

**Cut-off plan:** if time collapses, the four MUST shots are ② record/release,
③ the two-mechanism puzzle, ⑤ the boss, ⑥ the credits card. Drop ① and ④ first.

---

## 1. Shot list (target 1:50 — 10 s headroom)

| # | Shot | Dur | What it must show | Source |
|---|---|---|---|---|
| ① | Title + hook | 6 s | Title screen: "ECHOES OF TIME", tagline, menu | live capture |
| ② | Record → release | 15 s | Kid runs a short route; **Q** starts (rising tone, record bar); **Q** again releases (resolve tone, echo appears, hollow bell) | live capture |
| ③ | The two-mechanism puzzle (Level 2) | 25 s | Record standing on the plate, release, walk through BOTH gates — the echo visibly holds one while you take the other | live capture |
| ④ | The duel | 15 s | Skill-0 duel in Level 2: parry (clash), hit, guard falls (guard_death sting) | live capture |
| ⑤ | The boss (Level 3) | 25 s | Boss bar engages **shielded** (glow) → hits absorbed → echo released on the arena plate → shield drops (bar turns red) → Warden falls | live capture |
| ⑥ | The exit + victory card | 10 s | Walk into the exit door; "THE PALACE REMEMBERS" | live capture |
| ⑦ | Credits card | 6 s | The in-game Credits screen: tribute line + upstream credit + licence pointer | live capture |
| ⑧ | A5.2 comparison (optional) | 8 s | Side-by-side: original framing vs. ours (the A5.2 clip) | user's A5.2 clip |

**In-and-out rule per shot:** start already in motion (no dead air), cut on the
action beat (the release moment, the shield drop), never more than 2 s of silent
traversal without an SFX event.

**Framing notes:** windowed 1280×720 (the logical viewport) upscaled to 1080p in
the editor keeps text crisp; capture the window, not the whole desktop (no
watermark, no OS chrome). F3 overlay **OFF** for every shot.

---

## 2. The scripted input run (SESSION-preparable, USER-executed)

The same determinism that makes the echo work makes the video reproducible: a take
recorded once replays identically, so the *capture* is the only thing that needs a
human.

**Option A — play it by hand (recommended, ~15 min):** the shots are designed to be
doable first-try; the scripted runs below exist as a safety net, not a requirement.
The pause menu's sound controls let you check the SFX mix before rolling.

**Option B — scripted capture (safety net):** the suite already scripts every level
end-to-end (`tests/test_game_flow.gd`, plus the per-level runs in
`tests/test_main.gd`). For capture, boot straight into a level (no menu):

```bash
godot --path . -- --level=3      # 1-based; level 2 = Hall of Echoes, 3 = the Warden
```

A capture-oriented variant of the scripted kid (the adaptive boss cadence from the
L3 positive run) can be exposed as a `--capture` boot flag by a session if
hand-played attempts fail; the input scripts live in the tests, so this is a wiring
task, not new AI. **Do not** ship the flag in the release build without asking.

**Death handling:** if you die mid-take, the death beat auto-restarts at the
checkpoint — no menu diving needed; just re-roll the shot.

---

## 3. OBS settings (USER)

- **Sources:** *Window Capture* on the game window (not Display Capture) — no
  watermark, no desktop chrome.
- **Canvas/FPS:** 1920×1080, 60 fps (the sim ticks at 12 fps internally but renders
  interpolated — 60 fps capture keeps pans smooth).
- **Encoder:** x264, CBR ~12 Mbps for the master (re-encoded on upload anyway);
  keyframe interval 2 s; preset "Quality".
- **Audio:** Desktop Audio ON (the game's SFX are the only sound — no mic, no
  music). Confirm in the mixer that the meter moves when a sound plays; the pause
  menu's volume control sets the level before rolling.
- **Hotkey:** start/stop recording on a key the game does not use (the game uses
  A/D/W/S, Space, J/K/L, Shift, E, Q, R, Esc, F3 — use e.g. F9).

---

## 4. Kdenlive steps (USER)

1. New project, 1920×1080 60 fps; import the single master recording (or the
   per-shot clips).
2. Cut the shot list above from the master; titles over ① and ⑦ only — the game's
   own UI is the rest of the text.
3. If a shot drags: speed-ramp the traversal (keep SFX natural — ramp video only),
   cut on the SFX transient so the audio "hit" hides the cut.
4. Normalize the mix so SFX peaks sit around −6 dB; there is no music bed, so the
   gate/duel/boss stings carry the rhythm — space them.
5. Optional ⑧: drop the A5.2 clip side-by-side, labelled "1989 / 2026".
6. Export: MP4 H.264, 1080p, target bitrate ~10 Mbps, AAC 192 kHz stereo. Keep the
   master file; the upload copy must be **under 2:00** — trim, don't speed up, if
   you overrun.

---

## 5. Audio choice

- **Use the generated SFX** (the 14 in `audio/sfx/`) — they are the shipped game's
  voice, licence-clean, and the echo pair (rise/resolve/hollow) is the sonic
  thesis. The video spec says "music + SFX audible"; our recorded decision (D15,
  SFX-first) means **SFX-only is the honest mix** — say so in the description if
  asked, do not add unlicensed music to make the spec literal.
- **If you want a bed anyway:** it must be your own composition or
  CC0/licence-cleared, logged in `docs/ASSET_LICENSES.md` **before** the cut ships
  (the AUDIO_BRIEF rule applies to the video too). LMMS loops from the plan are an
  option only if you write them; nothing third-party by default.

---

## 6. What only you can do (summary)

1. Play the shots by hand (or approve the scripted-capture wiring).
2. Run OBS and capture the master.
3. Cut/export in Kdenlive.
4. Decide on (and if needed source + log) any music bed.
5. Upload and confirm the final runtime is under 2:00.

Everything else — the scripted runs as a safety net, the shot list, this plan — is
SESSION-preparable and already done here.

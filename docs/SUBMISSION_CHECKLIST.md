# SUBMISSION CHECKLIST
## Prince of Persia: Echoes of Time — RRR competition

**Deadline: Friday 2026-10-31.** Every deliverable below has one owner, a live
status and the date it must be **done by**, worked backward from the deadline.
Statuses are updated in `review.md` at every session close; this file is the
standing view.

**Feature freeze: Mon 2026-10-20 (D17).** After that date only bug fixes, audio,
art, export, video and docs — no new features. Anything not green by the freeze
gets cut, not delayed.

**Owners:** *user* = you (things only a human with the display can do);
*session* = an AI working session (can be commissioned any time); *both* = a
hand-off point between the two.

---

## The deliverables (competition brief)

| # | Deliverable | Owner | Status | Due by | Notes / blocker |
|---|---|---|---|---|---|
| 1 | **Playable build** — Linux + Windows exports, boot-validated, title→victory without developer cheats | both | ⬜ source green; **exports not built** | **Sat Oct 25** | Templates NOT approved (recurring blank → treated as not approved). User: install templates + export (manual steps in `review.md` S013 Step 3, ~20 min). Session: verify + boot-test both binaries. |
| 2 | **Gameplay video** (<2:00, 1080p, watermark-free, echo record/release + two-mechanism puzzle + duel + boss + credits; SFX audible) | user | ⬜ not recorded | **Mon Oct 27** | Plan in `docs/VIDEO_PLAN.md` (scripted input run + OBS + Kdenlive). Needs the exported build or a windowed run. |
| 3 | **GDD** — describes the shipped game + "measured from the original" appendix citing PARITY | session | ✅ drafted (S013 Step 4a; §0 shipped-map + appendix) | reviewed by user **Sun Oct 19** | Awaiting your review. |
| 4 | **Presentation** — 9 slides with speaker notes | session | ✅ drafted (S013 Step 4b) | reviewed by user **Sun Oct 19** | Needs ⛅ screenshots + the A5.2 clip from you before it is final. |
| 5 | **Licence record** — every shipped file has a row | session | ✅ audit re-run S013 (14 tracked wavs, 14 rows, 0 other binary assets; one-command audit in the doc) | re-run at freeze **Oct 24** | Re-run after any asset lands. |
| 6 | **QA report** — defect log in BUG-xxx format | session | ✅ maintained (BUG-001…013) | live | New defects from your playtest go here first. |
| 7 | **README** — study references + upstream credit + run/build/controls | session | ✅ updated (S013 Step 4d) | reviewed by user **Sun Oct 19** | Awaiting your review. |

## The gates (things that block the above)

| # | Gate | Owner | Status | Due by | Notes |
|---|---|---|---|---|---|
| G1 | **Human playtest, levels 1–3** (D14 clause: human-completable + feel) | user | ⬜ **not done — the single biggest gap** | **Fri Oct 17 EOD** (D14) | ~30 min. Defects → `review.md` → BUG-xxx log → fixed at the cause with regression tests. |
| G2 | **Listen to the SFX** (14 sounds; weakest flagged: sword_clash, sword_hurt, gate_close/plate) | user | ⬜ not done | **Fri Oct 17 EOD** | Pause menu has mute + volume now. If they bother you, one palette pass is a session task (feature freeze allows audio). |
| G3 | **Export templates approved + installed** | user | ⬜ NOT approved (blank → not approved) | **Sat Oct 18** | Blocks deliverable 1. Manual steps re-issued in `review.md`. |
| G4 | **A5.2 side-by-side clip** (original vs. ours) | user | ⬜ not done | **Sun Oct 19** | User-manual by standing decision; checklist in `review.md` S007. Feeds slide 2 and the video. |
| G5 | **7 screenshots** (checklist persisted in `review.md` S013) | user | ⬜ not done | **Sun Oct 19** | Feeds slides 1, 3, 4, 5, 6, 8 + the yellow-arc resolution. |
| G6 | **Rules reading: Q1 (measured constants) + Q7 (forks, credit, AI-assisted work)** | user | ⬜ not read yet | **Sun Oct 19** | Q7 gates the disclosure wording; no wording drafted until you have read it (D16). |
| G7 | **Push + CI green** | user | ⬜ NOT YET | **Mon Oct 20** | Your call; the branch is local-only. CI workflow exists, unpushed. |
| G8 | **B3.1 wording approval** (boss = skill 4; what the accept clause becomes) | user | ⬜ pending | **Sun Oct 19** | Note drafted in `review.md` S013 Step 4f; the tick stays off until you decide. |
| G9 | **Full playtest protocol** (3× L1, 2× L2, 2× boss kills, timed; then the same on the Windows export) | user | ⬜ not done | **Tue Oct 28** | Plan §8 non-negotiable clause; written defect log extends `docs/QA_REPORT.md`. |
| G10 | **Final licence audit re-run + freeze check** | session | ⬜ scheduled | **Fri Oct 24** | One command in `docs/ASSET_LICENSES.md`; suite green; no unlogged assets. |

## Date plan (working backward)

| Date | Milestone |
|---|---|
| Fri Oct 17 | G1 + G2 done (D14). Playtest defects triaged. |
| Sat Oct 18 | G3 (templates). Session: build + boot-test both exports if approved. |
| Sun Oct 19 | G4 + G5 + G6 + G8. Docs reviewed; slides get their images. |
| **Mon Oct 20** | **FEATURE FREEZE (D17)** + G7 (push/CI). Nothing new after this. |
| Tue–Thu Oct 21–23 | Session: playtest-fix loop; video capture with the user; B4.4 art pass if time allows (freeze allows art). |
| Fri Oct 24 | G10: final audit + suite green at the frozen tree. |
| Sat Oct 25 | Deliverable 1: exports validated on both OSes (G9's Windows leg can start). |
| Sun Oct 26 | Video rough cut (Kdenlive). |
| Mon Oct 27 | Deliverable 2: video final. G9 completed. |
| Tue Oct 28 | Package assembled (build + video + GDD + slides + licence record). |
| Wed Oct 29 | Buffer / last fixes. |
| Thu Oct 30 | **Submit — a day early.** |
| Fri Oct 31 | Deadline (buffer only). |

## Cut order if the week slips (never cut these gates: G1, G5, G10)

1. B4.4 art passes (freeze allows, but they are polish).
2. A5.2 clip (nice for slide 2; the video can carry the comparison instead).
3. Legacy-path parity checks (the shipped path is the sim path).
4. Nothing else — everything above is a competition deliverable.

# Native boxing count and recovery — 2026-09-30

**Foundation status: NOT_ACCEPTED.** This is a connected count/recovery repair in the existing Godot game, under PAC-206 / NDL-013. PAC-208 remains REVIEW; OGM-025 remains PACED_REQUIREMENT. No package promotion or commit was made.

## Repaired behavior

- A real native drop cancels both pending punches, the player command, opponent queued string, cast/clinch state, frozen/queued steps, recoil, counters and stale defensive intents. The physical solver and planted feet survive the boundary.
- Either fighter now passes through a referee count. Opponent composure no longer refills on the impact frame. Opponent beats use the existing delegated fighter's HRT chance, with one seeded draw per beat. Player rise input cannot raise the opponent.
- The shared saved pose lowers into a kneel and rises before combat resumes. Head, torso, gloves and limbs remain part of that same pose. The round clock and roots hold during the count. Passing restores the authored half-composure and ten-second regeneration halt.
- A failed count or third drop ends the segment, with correct scoring and existing corner/next-segment flow. The downed pose persists through the result instead of snapping upright. The result panel waits for the fall to complete and the cue says SEGMENT OVER.
- The player rhythm prompt appears only while the player is answering the count. It disappears during the rise and never asks the player to raise the opponent. Opponent recovery does not earn the player's crowd surge.

The production camera is the existing behind-and-above player view. Side images are explicitly labelled anatomical diagnostics. No camera implementation was changed.

## Evidence and limits

| Check | Result | What it covers |
| --- | --- | --- |
| Recovery plus two native segment fixtures | 94/94 | Both fighters, both stances, pending/queued cancellation, count-out, third drop, corner/new segment, exact mid-count restore, limb lengths, bounded motion, vulnerability, tired delivery/rest and 30/60/144 Hz render partitions |
| Rendered count/KO sequence | 94/94 | Two actual swept-punch drops and rises plus a third-drop KO; result panel delayed until the fall completes |
| Final KO cue capture | 92/92 | Same lifecycle base plus final native knockout render, result-panel timing and SEGMENT OVER cue |
| Punch contact | 443/443 | Moving targets, physical guards/deflections, committed paths, interruptions, trades and shared rendered geometry |
| Boxing motion | 343/343 | Supported limbs, transitions, guard and tired recovery |
| Head motion | 153/153 | Shared head targets/orientation and actual contact reactions |
| Existing foundation driver | 61/61 | Native controls, supported steps, camera geometry and live scene integration |
| Existing legacy smoke | 454/454 | Existing game data, scoring and integration behavior |

The two 90-second segment fixtures reached clock expiry: 82 contact resolutions orthodox, 99 southpaw, minimum stamina 0 in each. Each starts with a 20-tick neutral warm-up, then 10,785 further ticks (including five hitstop ticks); round clock began at 10,780 remaining. These are controlled native AI/simulation runs with hooks and coaching disabled, not human playtesting or a wall-clock performance benchmark. They do not establish the quality of sustained exchanges.

The count fixtures measured minimum knee centers at 0.125m / 0.136m and maximum single-tick joint travel below 0.046m. Arm and leg lengths remain within 0.001m. The count's pose timing is provisional: 90 fixed ticks / 0.75s to kneel, 72 ticks / 0.60s to rise, pelvis target 0.39 model metres, backward seat offset 0.15 model metres. These are game tuning, not biomechanical measurements.

The final movie is a 19-second, 1,140-frame, 60-fps, 1280x720 assembly of three controlled captures from the actual main scene. The first 15 seconds show opponent and player count/recovery; the last four seconds show the final KO cue/panel behavior. Low starting composure and HRT=99 deliberately make drops/rises reproducible; the third scene starts with two prior drops. Damage/contact is resolved by the native swept punch. Inputs are driver intents, not a claimed manual keyboard playthrough. Audio used Dummy throughout.

Visual review inspected 0.25-second sampled gameplay frames and full-resolution count/KO diagnostic images. The final knockout capture shows the fall before the result panel, followed by the result panel; this is not an uninterrupted human playback approval. The greybox kneel and rise remain provisional animation.

Contact/foundation tools retain their pre-existing two-ObjectDB-instance exit warning where emitted. No script errors were seen. PACER validation retains the older PAC-010 age warning. Passing isolated checks is not whole-model acceptance.

## Retained negative evidence

- Original count fixture: **32/56**. Opponent count absent, immediate composure refill, discarded physical player count pose, stale buffered commands/steps.
- First repair: **52/56**; all four kneeling poses too high.
- Lower second pose: the earlier broad test passed, but rendered floor clearance was inadequate. Its logs and images remain. The tighter final floor-clearance check and raised target replace that approval boundary.
- First rendered opponent count incorrectly displayed the player's TAP prompt; corrected and recaptured.
- First KO film covered the falling fighter immediately with the result panel. `boxing-recovery.mp4` and `recovery-sequence-*` retain that defect. `boxing-recovery-reviewed.mp4` / `reviewed-sequence-*` show the delayed panel before the final SEGMENT OVER cue correction. Use `boxing-recovery-final.mp4` and `final-sequence-*` for the delivered sequence.

`verification-history.zip` retains baseline/final source, source SHA-256 manifest, reports, logs, patches, and selected raw diagnostic frames. Complete raw frame sequences remain in `.PACER/count-recovery-20260930/`. No failed run was deleted.

## Still open

This work does not prove all build/technique combinations, comprehensive mesh clipping, uninterrupted full-round visual quality, or human control feel. A separate accumulated-fatigue system is not implemented by this count repair. Authored opponent-specific dramatic count overrides are not newly invented. The wider foundation acceptance gates remain open.

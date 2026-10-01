# Sustained boxing exchange repair - 2026-10-01

**NOT_ACCEPTED. PAC-206 remains DOING; OGM-025 remains PACED_REQUIREMENT.**

**Verification correction, 2026-10-01:** the stance driver's 278/278 result below is invalid. Its incomplete contact fixture triggered 3,908 script errors while its final assertions still printed green. The original logs are preserved. The corrected driver now supplies the complete contact input and verifies completion and both elbows; the subsequent hook-coherence report records its clean rerun. The other test results have been rescanned for script errors. This correction does not grant foundation acceptance.

This continues the user's rejected boxing foundation. The supplied foundation/style direction and September 29 user correction remain authoritative. No camera mode, campaign feature or count animation was added. The gameplay camera remains behind and above the player. The side camera in the second recording is explicitly labelled inspection only.

## Reproduced failures and changes

The corrected baseline driver kept the real opponent AI active in eight seeded 90-second exchanges. It found a glove up to 0.260713 m inside its own finite torso, a forearm up to 0.233456 m inside the torso, 0.045495 m forearm/head penetration, and an elbow movement of 0.312662 m in one simulation step. The baseline clipping image is an actual rendered saved failure. These measurements concern the rig's physical volumes, not arbitrary triangle intersections.

- Low guard was authored inside the torso. Its native home now sits forward of the body. Guard homes follow the final attached head/collar through body motion and punch delivery; they no longer stay behind while the chest moves.
- The arm solve checks skull and finite torso clearance, preserves bone lengths, searches a nearby elbow plane and folds an obstructed hand around its own side. The old native covered-elbow adjustment could move the wrist after solving it; that path remains only in legacy presentation.
- Distant targets formerly reached the chest-lean cap too abruptly. Available trunk reach is now bounded before phase weighting. Support moves at a bounded world rate without changing foot lift/landing timing or delaying input.
- A descending uppercut preparation and the upward lift of a low straight could score before their forward/upward delivery. Contact uses the actual direction of those committed paths; terminal misses still resolve.
- Correcting only the glove to a swept contact while retaining the end-of-tick chest made the glove conflict with its own body. Contact now uses the connected pose at the same swept instant, retains its elbow plane, and saves that exact return endpoint. A small spare glove routing margin is released at impact; actual anatomy and the forearm sampling allowance remain enforced.
- Returning hands now take an outward arc before reaching their own head, while retaining the same recovery clock. This reduces the learned OUTBOXER case from 0.214635 m to 0.088697 m maximum elbow movement per tick.
- Northern Rising's lead guard advances from 0.34 to 0.37 so its asymmetric raised lead remains ahead of the rear glove after jaw clearance. Signature fixtures now use an explicit visible hands-down invitation for positive cases and retain both high- and low-guard obstruction negatives. Mirrored counters mirror both fighters and the incoming hand.

The straight-glove clash fixture now uses two rear straights whose actual gloves intersect. The old uppercuts encountered the newly exposed low guard first. The committed-target relocation fixture moves the whole target, including planted support, instead of moving only its root. Exact surface correspondence, fixed anatomy, actual misses and blocked signature assertions were retained. Slip counter negatives still assert the exact glove/guard surface. After the outside return clears its former glove interception, the duck counter negative now asserts a real miss and separately checks that the endpoint lies outside the actual head sphere. The intermediate 341/342 failure and contact records are preserved; no physical-interception assertion was weakened to permit a hit.

## Current-source checks

Godot 4.7.2, Dummy audio, isolated APPDATA for every run. All final run logs are in verification-history.zip; the 141-file SHA-256 manifest identifies the handoff source. The capture-time manifest is also retained: only the standalone motion test driver changed afterward to diagnose and assert the changed counter surface. Production code and the capture driver did not change during or after the final recording.

| Check | Result | Scope |
| --- | --- | --- |
| Sustained native exchanges | 64/64 | Eight 90-second exchanges, both fighters, actual AI, ordinary orthodox and equipped southpaw across four existing body profiles |
| Physical contact | 443/443 | Sweeps, guards, misses, committed aim, restore, actual rendered glove correspondence |
| Native motion | 342/342 | Punch/modifier matrices, combinations, counter rules, planted drive, anatomy and rendering |
| Stance coherence | 278/278 | Mirroring, stance-relative movement, support and restore |
| Head motion | 153/153 | Articulated head, impacts and rendered interpolation |
| Head attachment | 128/128 | Fixed connected neck and self-skull glove clearance |
| Northern Rising | 70/70 | Actual learned guard and techniques, mirrored counters, obstruction negatives and restore |

The exchange gates fail above 1 mm for measured own-body penetration, limb-length error, resolved contact endpoint error or repeated-constrain drift. The final matrix had no measured forearm/head, forearm/torso or glove/torso penetration; maximum bone error was 0.000000165 m, contact endpoint error 0.000000133 m, and repeated elbow drift 0.000000275 m. There were 1,290 resolved contacts. These finite seeded checks do not establish all possible poses are free of clipping.

Measured step p95 was 615-958 microseconds during concurrently running checks. The measurement times only simulation step(), excludes diagnostic sampling and rendering, and is not gameplay FPS or input-latency qualification. Geometry repair added work relative to baseline; no performance acceptance is claimed.

## Rendered review

[Gameplay recording](gameplay.mp4) and [labelled side inspection](inspection.mp4) each contain 720 frames, 1280x720, 30 fps, 24 simulated seconds. Capture hashes confirmed rendering did not mutate simulation state. Both are generated from main.tscn and the final source; camera settings are unchanged. The footage uses scripted commands against the real AI, not human play.

Viewed actual chase/side frames, the 24-frame inspection sheet and a dense 30-frame side sequence (frames 195-224). The sampled head remains attached and the large baseline glove-through-torso failure is absent in the inspected frames. The motion still reads mechanically in places. The scripted repeated burst exhausts the player; the late footage shows that fatigue and does not establish a balanced or enjoyable exchange. The production source is unchanged since this refreshed recording.

## Remaining core defects and acceptance limits

- The matrix still records a 0.150459 m elbow movement and 0.167260 m wrist movement within a single tick. The current worst elbow is the player delivering R_HOOK, SLUGGER with learned guard, tick 2434 at progress 0.421. That fast branch movement remains an open continuity concern. The earlier OUTBOXER return jump was reduced by routing the return earlier; its failed capture and snapshots remain preserved. Fixed bones and clearance are not motion-quality acceptance.
- Matrix head movement peaks at 0.049214 m and pelvis at 0.047656 m per tick. The separate production film records a 0.194281 m wrist step. Passing clearance does not prove smoothness.
- Only sampled primitive volumes are measured; all mesh intersections, all guard/return transitions, all specialist techniques, real-time feel and complete connected-foundation acceptance remain open.
- Two ObjectDB instances are reported at exit in the contact/motion drivers. The assertions pass, but that diagnostic is retained. The entire legacy/release/package suite was not run this pass.
- PACER validation retains the existing PAC-010 older-than-48-hours warning. This pass does not advance that row or accept its work.

## Rejected attempts and reproduction

The archive retains failed baseline indexing, a GDScript type error, torso-cap projection flips, head-route branching, the broad elbow-circle search, slow step-loading experiment, contact endpoint drift, and reduced forearm allowance that exposed millimetre penetration. None of their failed results is replaced by a green summary. The slow step-loading experiment was reverted.

From the repository root, set APPDATA to a fresh directory and invoke Godot with `--headless --audio-driver Dummy --path engine/greybox -s tools/drive_boxing_exchange.gd -- welcome`. The same driver accepts `-- welcome film` for GPU main-scene capture and `-- welcome inspect` with BOXING_WORST pointing to a saved worst-state JSON. Other final drivers use their matching `tools/drive_*.gd` path with `-- welcome`.

The archive contains baseline and all intermediate/final logs, metrics, saved worst states, available intermediate source copies, the pre-return-lane videos/report and the final source files. Full raw frame sequences remain under .PACER/exchange-coherence-20261001/return-film; encoded footage is provided here. Source/local changes from earlier work are preserved. No commit, package promotion, user approval or foundation completion is claimed.

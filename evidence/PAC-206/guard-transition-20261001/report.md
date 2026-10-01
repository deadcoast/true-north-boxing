# Core boxing: guard travel and committed punch paths

2026-10-01. PAC-206 remains **DOING**. OGM-025 remains **PACED_REQUIREMENT / NOT_ACCEPTED**. This is repair evidence for the existing match implementation, not acceptance of the boxing foundation.

## Implemented behavior

- Guard press starts moving from the fighter's actual resting cover immediately. Previously `max(input_guard, resting_cover)` stalled some profiles for the first two ticks, then compressed the whole stroke into its remaining ticks. The original six-tick guard clock remains.
- Hooks, hookercuts, uppercuts and flared punches use a shoulder-centred spherical curve with separately bounded arm opening. Their lateral/downward arc no longer adds unreachable arm length and forces the elbow fully straight midway through the swing.
- A committed punch retains its initial shoulder-relative arm vector. Changing the other hand's guard height cannot replace that launch pose during flight. Preparation retains the same vector through commitment and save/restore. The working arm does not receive the live guard's attachment offset a second time.
- Straights also retain their launch vector, preventing a following hand from rushing back to its resting home before delivering. Body straights establish their lower lane during loading, before arm extension.
- The shared contact resolver still decides actual hits, guards, deflections and misses. No counter, trade, technique, or punch family is exempted from physical interception. No new camera or peripheral feature was added.

## Reproduced defects and bounded improvements

These are maximum local joint displacements over the same 180-tick saved input interval, measured at 120 Hz. They are regression observations, not biological motion limits or a claim that every transition is smooth.

| Saved interval | Before | Current | Evidence |
|---|---:|---:|---|
| SWARMER ordinary, tick 4120, guard press | elbow 0.110165 m | 0.070425 m | `guard-checkpoint.json`, `guard-before.mp4`, `guard-after.mp4`, `guard-comparison.png` |
| SLUGGER ordinary, tick 160, lead hook | wrist 0.134309 m | 0.077968 m | `hook-checkpoint.json`, hook clips and comparison |
| Intermediate spherical candidate, SWARMER ordinary tick 1250, high-to-low guard during rear uppercut | wrist 0.168977 m | 0.074763 m | `upper-checkpoint.json`, upper clips and comparison |
| Intermediate curved-only repair, SLUGGER ordinary tick 1200, straight combination | wrist 0.133078 m | 0.098837 m | `straight-transfer-checkpoint.json`, straight-transfer clips and comparison |
| Rejected first radial curve, BOXERPUNCHER learned tick 2760, chained body hook | wrist 0.285400 m | 0.054813 m | `chain-checkpoint.json` and before/current traces in history archive |

The uppercut and straight-transfer “before” clips explicitly show intermediate candidates from this pass. They are not represented as the turn-start version. Previous saved straight regressions from `../trajectory-coherence-20261001/` also retain their bounds: current SLUGGER interval elbow/wrist 0.076130/0.108901 m; OUTBOXER interval 0.066935/0.084145 m.

## Checks and what they establish

Godot 4.7.2, Dummy audio, isolated APPDATA per run. Current logs are retained under the `complete-*` and `body-load-*` history directories. All current runs were scanned for script errors, parse errors and failed assertions.

| Check | Current result | Scope |
|---|---:|---|
| Native motion/input/render transitions | 345/345 | Includes actual key adapter, hitstop, connected motion and counter inputs |
| Physical punch contact | 444/444 | Moving volumes, exact impact pose, guard height, interruptions, clash, covered exchange, clean head/body trade |
| Stance coherence | 2238/2238 | Existing 278 checks plus the three matrices below |
| Head motion | 153/153 | Shared physical head motion and response |
| Head attachment | 128/128 | Attachment/clearance checks across selected styles and stances |
| Northern Rising | 70/70 | Shared learned routes, defensive counterplay and actual signature inputs |
| Sustained active-opponent exchanges | 64/64; 1314 contacts | Four profiles, ordinary/learned variants, 10800 ticks each |

Added stance coverage:

- 104 guard-stroke checks across 24 profile/learned/stance cases. Named SAM/MARTA fixtures select their actual lineup identity. Turn-start source fails eight first-tick response assertions (96/104); repaired source passes 104/104.
- 1536 checks across 768 curved-punch cases: eight left/right rows, head/body aims, three ranges, four profiles, ordinary/learned, both stances. Every sampled route keeps the elbow below the 175-degree straight-arm stop and keeps arm lengths within 1 mm. The earlier 384-case hook-only baseline exposed 66 straight-arm failures.
- 320 checks across 160 paired committed-punch cases. One fighter keeps high guard; its identical counterpart lowers guard at 40% punch progress. The working wrists remain within 3 mm while the covering wrist moves more than 5 cm. Both straights and all curved families are included. The intermediate live-home implementation failed all 128 curved working-hand comparisons; freezing only the source still left up to 2.6 cm of extra guard-anchor steering, also repaired.

Six current saved replays pass all eight sampled bounds/restoration checks. The uppercut replay passes seven; it has no non-miss impact, so contact-endpoint evidence is explicitly **UNSAMPLED**, not a pass. The replay driver no longer turns absent measurements into passing zeroes.

Sustained-run maxima: bone-length error 0.000000194 m; contact-endpoint error 0.000000119 m; repeat elbow/wrist solve drift 0.000000391/0.000000240 m. Measured forearm/head, forearm/torso and glove/torso penetrations are zero. These three sampled volume checks do not establish absence of every possible mesh intersection.

## Contact expectations retained and corrected

The old simultaneous rear-hook head/head fixture no longer produces two clean hits: real lead gloves occupy both repaired routes. It is retained as a negative case requiring a deflection and a guard interception with no clean hit. A separate simultaneous lead body hook/rear head hook at 1.8 range proves both committed punches can land, with the actual body/head contacts retained in the trace.

An immediate post-weave lead uppercut meets the returning rear glove. That exact failed reply is retained as a strict deflection/no-hit/endpoint test. Waiting six native ticks opens the same rising lane while the earned counter window remains active; the positive counter still has to land. The immediate rear reply after a right slip now misses the moving head; the delayed reply still meets the lead glove. Both misses are checked against actual target separation. No counter flag grants a hit.

## Rendered evidence

`gameplay.mp4` is the existing behind-and-above gameplay camera: 24 simulated seconds, 720 frames at 30 fps. `inspection.mp4` is the same exchange from the explicitly labelled diagnostic side view. Each before/after clip covers 180 consecutive ticks at 120 fps (1.5 simulated seconds), starting from its accompanying identical checkpoint. PNG comparisons show dense frames around the reported transitions; the gameplay inspection sheet samples the full exchange.

The current capture records a read-only render hash across both cameras. Its maximum elbow/wrist steps are 0.094925/0.101302 m. All ten videos passed frame-count and complete-decode checks, recorded in `video-verification.json` inside the history archive. Source identities cover 141 files in `source-hashes.json`; the corresponding source is preserved in the 1303-entry, CRC-checked archive.

Visual review is limited to the actual rendered still sequences and sampled exchange frames identified here. This is not a claim of a real-time human playthrough, animation authenticity, player enjoyment, or complete model acceptance.

## Preserved failed work and remaining limits

- The first attempt at radial normalization passed the small hook matrix but produced a 28.5 cm wrist direction flip in a connected body-hook exchange. Adding forward clearance alone was insufficient. The rejected source and failing trace remain archived.
- The spherical path initially still used the live guard home, causing the 16.9 cm uppercut jump. Freezing its start exposed a second guard-anchor coupling; both intermediate failures remain.
- Capturing straight launch poses initially routed a high-to-body straight through the high forearm. Physical contact and Northern Rising body-counterplay tests failed; loading-phase level change restored those checks without relaxing their expected high/low behavior.
- Contact expectations were updated only after inspecting the actual intercepted surfaces. Failed head/head and mixed-lane attempts, the counter probe and old assertions are retained. The final negative cases and positive trade/counter cases remain separate.
- An early guard fixture wrote a motion identity that the simulation overwrote. It was replaced with actual lineup selection; the misleading preliminary result is preserved.
- An initial uppercut fixture used incorrect metric names. Corrected metric keys and the explicit UNSAMPLED behavior supersede that output; both logs remain.
- The guard-only 24-second GPU attempt hung after frame 658. Its verified process was terminated; its partial output is not accepted as a completed capture. Fresh complete captures supersede it; its log and selected frames remain.
- The native motion driver still reports two ObjectDB instances leaked at exit. The warning remains visible in the retained logs.
- The sustained current run still has a fast covering-arm return at ordinary BOXERPUNCHER opponent tick 6028: elbow 0.137749 m, wrist 0.122032 m, first recovery tick after a prepared lead straight contacts. The exact before/after rig and fight state are preserved as the current `worst-elbows_step_m.json` and `worst-wrists_step_m.json` in `complete-matrix`. This needs further contact-to-return motion review; a green geometry suite does not qualify that transition.

Complete boxing feel, technique depth and connected play qualification remain open. No requirement was promoted to validated, no task was marked done, and no package was published from this pass.

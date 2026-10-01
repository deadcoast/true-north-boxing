# Preparation and covering-arm continuity — 2026-10-01

**Foundation status: NOT_ACCEPTED. PAC-206 remains DOING, OGM-025 remains PACED_REQUIREMENT with empty AcceptanceEvidence, and NDL-013 remains ACTIVE.** This evidence addresses the two unresolved transitions in the preceding contact-return report. It does not qualify the complete boxing model or its feel.

The implementation follows the existing foundation's connected body movement, physical punch aim, supported facing and recovery requirements. The changes run in the normal match simulation, using the same rig for collision and presentation.

## Repairs

Preparation previously aimed at a legacy tactical-region surface, while commitment aimed at the actual defensive volume. The transition therefore replaced the loaded glove's lane. Both now use `punch_contact.aim`: the physical head/body center, anatomy-bounded reach, selected technique and the support controller's body facing. A queued step refreshes this uncommitted preparation each tick. Commitment still freezes its aim; later opponent movement cannot retarget an in-flight punch.

The motion solver already released preload as punch progress advanced. Contact sampling applied the same attenuation again after commitment, abruptly dropping the loaded body. It now applies once in the shared motion calculation.

The opposite hand previously returned from a fixed world-space glove position while its shoulder retreated with the next punch. That extended the arm again and drove its elbow toward a nearly straight configuration. A new return captures the actual wrist-to-shoulder vector and transports the unsettled portion with the shoulder, including the final solved body lean and lowering. The settled portion uses the existing guard anchor. Impact continuation clears the return transport weight when it holds an already evaluated contact pose. Older saved returns retain their fallback.

## Identical saved-state comparisons

Each pair replays the same 180 native input ticks from the same saved state. Measurements below are in meters per simulation tick unless otherwise specified.

| Saved encounter | Before | Current source |
| --- | --- | --- |
| Learned SLUGGER, opponent prepared lead straight, launch at tick 5119 | Working wrist jumps 0.112271 at the preparation/commitment boundary | That exact boundary moves 0.002052; maximum wrist step over all 180 ticks is 0.060327 |
| Learned SWARMER, opponent covering lead arm while the rear straight loads, old elbow maximum at tick 741 | Peak elbow step 0.106764; return extends 0.051374 beyond the larger of its captured and home shoulder-relative reach | Peak elbow step 0.067203; measured excess return reach is zero |

The covering replay's maximum wrist step rises from 0.090110 to 0.103676 as the hand follows the moving shoulder. This tradeoff is retained in the record; the elbow/attachment repair is not a claim that every hand trajectory is now satisfactory. The prepared fixture passes 8/8 checks; the covering fixture passes 10/10. The baseline fails 1/8 and 2/10 respectively. Existing fixture limits were not weakened.

## Current verification

The preparation handoff driver exercises four base styles, ordinary and learned guards, both stance reflections and nine existing punch verbs: 144 cases with four checks each. At the same pose clock it checks preparation progress, physical aim, body load and working glove continuity. The turn-start implementation fails 324 of 576 checks; the current implementation passes all 576. These checks are included in the full stance driver.

| Native driver | Current result |
| --- | --- |
| Boxing motion | 345/345 |
| Physical punch contact | 444/444 |
| Stance, combinations, reflection and preparation handoffs | 2814/2814 |
| Head motion | 153/153 |
| Head attachment | 128/128 |
| Northern Rising | 70/70 |
| Sustained exchanges across four styles with ordinary and learned guards | 88/88; 1312 contact results across 86400 input ticks |

All eleven saved replay regressions pass: prepared 8/8, covering 10/10, previous impact return 9/9, short return 10/10, recovery facing 9/9, combination facing 9/9, chain/guard/hook/straight-transfer each 8/8, and uppercut 7/7. The uppercut's contact-endpoint measurement remains explicitly UNSAMPLED because it contains no non-miss impact.

In the sustained run, maximum preparation/body facing disagreement is 0.0000000298 radians and maximum per-tick facing change is 0.022754 radians. Bone-length error is at most 0.000000165 m; contact-endpoint error is at most 0.000000123 m. Repeated elbow/wrist solve drift is at most 0.000000251/0.000000169 m. The three sampled forearm/head, forearm/torso and glove/torso penetration measures are zero. These are proxy-volume measurements, not an exhaustive mesh-intersection or animation-authenticity verdict.

## Rendered evidence and source identity

`gameplay.mp4` contains 24 simulated seconds from the existing behind-and-above gameplay camera, 720 frames at 30 fps. `inspection.mp4` is the explicitly labelled diagnostic side view of that exchange. The prepared and covering before/after clips each contain 180 consecutive frames at 120 fps. All six videos passed frame-count and full-decode checks. Each capture confirms that rendering left the simulation hash unchanged.

The prepared comparison shows six consecutive frames at ticks 5117–5122; the covering comparison shows ticks 737–742. Both comparison sheets, the twelve-frame exchange inspection sheet and full-resolution native gameplay/inspection frames were directly viewed. This was inspection of captured still sequences, not a real-time human playthrough. The final gameplay capture's maximum elbow/wrist steps are 0.080331/0.098537 m.

`source-hashes.json` identifies 244 current source/resource files and matches the source used for the final `coherent-*` checks and captures. `verification-history.zip` contains 1498 entries (56,134,539 bytes), passed its CRC check, and retains current source, affected sources from earlier candidates, failing/passing logs, saved states, trajectories, selected raw frames and media verification. Its SHA-256 is `57c7dbea07c454ace95fd12a6b0c1fc556daf59f8db88ed85b4ee951bf545fca`.

## Retained failures and open work

- The first shoulder-relative return candidate omitted the final solved body lean/lowering from the unsettled hand. Its covering replay still produced a 0.145729 m wrist step. The failed candidate and trace remain in `early-return-candidate` and `history/after-cover` in the archive. The final transport includes that body translation.
- Shared aim initially used the root-to-root direction, allowing a prepared rig to disagree with supported body facing. `root-facing-matrix` passes only 80/88. Switching to supported facing alone still left queued-step preparation stale; `supported-matrix` passes 83/88. Refreshing every uncommitted preparation, including the queued-step wait, produces the final 88/88. The earlier candidates and captures are historical evidence, not the final source.
- The current sustained maximum elbow step is 0.107242 m, ordinary SLUGGER opponent tick 640. The current maximum wrist step is 0.116319 m, learned SLUGGER opponent tick 1504. These are later opposite-hand return states, distinct from the repaired launch and covering fixtures. They remain available for continuity and visual assessment; a green geometry suite does not approve them. Exact states are under `history/coherent-matrix/Godot/app_userdata/TNB Greybox/worst-elbows_step_m.json` and `worst-wrists_step_m.json` in the archive.
- Outside the repaired covering fixture, the diagnostic return-reach excess reaches 0.002112 m. An outside return arc can increase this measure; no universal zero-extension requirement has been inferred. Its saved maximum is retained alongside the other sustained extrema.
- The boxing-motion driver still reports two ObjectDB instances leaked at exit. The warning is retained. The final verification logs contain no script or parse errors.
- Complete connected boxing response, technique depth, strategy, movement quality and the authored feel gates remain open. No task was marked DONE, no requirement was promoted to VALIDATED_COMPLETE, and no package was promoted.

The preceding contact-return report remains unchanged as historical evidence. Its two open transition faults now have the before/after results above; the newer remaining extrema are not silently classified as accepted.

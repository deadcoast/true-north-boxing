# PAC-206: return clearance and impact continuity — 2026-10-01



**Foundation remains NOT_ACCEPTED.** PAC-206 stays DOING, NDL-013 ACTIVE, OGM-025 PACED_REQUIREMENT with empty AcceptanceEvidence. Ordinary guard lowering still fails the saved motion criterion below. These are core repairs and bounded verification, not a claim that the boxing model is complete.



## Changes in the actual match path



Only `presentation/boxing_motion.gd` and `sim/punch_contact.gd` changed relative to this turn's preserved 244-file source/resource manifest.



- Resolve a returning glove against its shoulder reach sphere and its own skull clearance sphere together. The old sequence clamped reach and then pushed the glove outside that limit to clear the head.

- Carry the bound through forearm and torso clearance. A bounded route approaches a feasible full-arm guarding home. An outward ray projected onto the reach sphere can curve away from a nearby valid home and drop the arm around the head.

- Keep a future guard home at normal routing clearance even when an evaluated impact consumes spare clearance at the striking glove.

- Retain the opposite hand's return bound during the fractional impact solve. The striking hand retains its evaluated endpoint; contact does not stop the other hand's recovery.



No save schema or public signature changed. Optional arguments belong to private clearance helpers. Existing animation clocks and the shared fixed-tick input, collision and render path remain in use.



## Saved-state results



Each saved regression restores a native match state and executes the same next 180 input ticks. Distances below are metres. These are engineering regression bounds, not biomechanical acceptance standards.



| Case | Before / failed candidate | Final | Result |

| --- | ---: | ---: | --- |

| Learned SWARMER B, return near tick3027: excess reach | 0.013774633 | 0.0000000894 | 8/8 |

| OUTBOXER P, fold near tick10072: elbow / wrist step | initial bounded candidate 0.174436 / 0.162399 | 0.058358 / 0.056959 | 10/10 |

| Learned BOXERPUNCHER P, future home at impact near tick6763: excess reach | 0.002700329 | 0 | 10/10 |

| Ordinary BOXERPUNCHER B, opposite return at impact near tick2447: excess reach | 0.001012802 | 0 | 10/10 |

| Ordinary BOXERPUNCHER B, guard lowering near tick2633: elbow step | 0.100061245 | 0.100061245 | **7/8; fails 0.09 limit** |



All 13 earlier bounded regression files in contact-return, guard-transition, preparation-return and return-route also pass. Total: **17 of 18 saved replays pass**. The guard failure is retained, not excluded from the result. Where a replay records no relevant contact, its endpoint metric is unsampled evidence; the separate sustained/contact suites exercise resolved endpoints.



## Final-source checks



| Native check | Result |

| --- | --- |

| Boxing motion, input and render behavior | 345/345 |

| Punch contact | 444/444 |

| Stance, preparation and curved routes | 2814/2814 |

| Head orientation and saved render state | 153/153 |

| Head attachment and skull clearance | 128/128 |

| Existing Northern Rising behavior | 70/70 |

| Sustained exchange geometry | 88/88 |



The sustained run covers eight ordinary/learned style configurations, 86,400 input ticks and 1,330 contact results. Final maxima: bone-length error 1.65e-7m; resolved contact-endpoint error 1.33e-7m; repeat elbow/wrist solve drift 2.73e-7/1.69e-7m; opposite-return excess reach 8.94e-8m. Sampled forearm/head, forearm/torso and glove/torso penetration maxima are zero. These samples do not prove all possible geometry is correct.



## Native inspection and reproducibility



`gameplay.mp4` and `inspection.mp4` are the same final-source 24-second exchange, 720 frames at 30fps. The side view is explicitly diagnostic. `clearance-after.mp4`, `fold-after.mp4` and `guard-unresolved.mp4` use final source and saved inputs, 180 frames at 120fps (1.5 seconds at normal speed). `clearance-before.mp4` uses the preserved turn-start source and identical inputs.



All six videos passed frame-count and complete decode checks. Each native capture records `render_read_only=true`. The reviewer directly inspected before/after return frames, consecutive fold/guard sequences, the gameplay camera frame and the twelve-frame diagnostic exchange sheet. No human playtest or continuous audiovisual viewing is claimed. The numerical return change is small in the pictures; those pictures alone do not demonstrate its reach bound.



`source-hashes.json` records 244 final source/resource identities. `verification-history.zip` retains current source, turn-start source, selected intermediate sources, failed and passing logs, exact worst-state snapshots, checkpoint trajectories, capture metadata and selected raw frames. Scratch runs with `end-` and `capture-end-` are final-source results. Earlier `check-`, `final-`, `capture-final-`, and candidate directories are iteration history and are not final qualification evidence. The final guard video was separately refreshed from `capture-end-guard` after the shared encoder ran; its verification metadata was updated.



To replay a fixture, set `BOXING_CHECKPOINT` to the absolute path of that checkpoint JSON and run Godot from this repository with `--headless --audio-driver Dummy --path engine/greybox -s tools/drive_boxing_exchange.gd -- welcome replay`. Use a fresh repository-local APPDATA directory to retain its logs. The guard fixture must currently exit with failure.



## Failed approaches and remaining work



The proposed joint-space guard-hand path worsened the saved elbow step to 0.104970m and was removed. The first combined head/reach constraint passed all 88 existing geometry checks but introduced the OUTBOXER fold discontinuity above. Whole-home feasibility alone and first-exit search along the projected outward ray did not solve it. Returning toward the feasible guarding home did. This failure is why geometry checks are not used as motion acceptance.



The ordinary guard-lowering path remains unqualified. In the exact failing state the other hand is preparing a right straight and the boxer is stepping; the left elbow's large downward movement exists before collision correction. A passing penetration test cannot clear that transition. Its final-source footage and failed replay remain attached for continued core work.



The sustained outgoing SLUGGER P tick484 wrist step remains 0.110675m; it is a separate outgoing punch state, not the repaired return fault, and is not accepted merely because its geometry is clear. Full authored flow, defensive responsiveness, style-specific feel and isolated runtime performance remain open. The heavily concurrent verification run recorded some p95 step times above the 120Hz budget; those timings are retained and are not a performance acceptance result. Earlier native test exits also retain the existing two-ObjectDB-instance leak warning.


PACER reconciliation registered all18 artifacts as OVR-1978 through OVR-1995. Validation has no errors or stale evidence; the existing PAC-010 over48h warning remains. PAC-206/NDL-013/OGM-025 status and acceptance limits are unchanged.

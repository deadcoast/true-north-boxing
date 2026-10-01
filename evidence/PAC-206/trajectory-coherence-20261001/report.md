# Straight-punch trajectory repair

2026-10-01. **Foundation NOT_ACCEPTED. PAC-206 stays DOING; OGM-025 stays PACED_REQUIREMENT.** This repairs two reproduced discontinuities in the shared boxing simulation. It does not qualify the complete boxing model.

## Causes and changes

The original ordinary SLUGGER opponent lead straight tried to interpolate toward a target beyond the arm's reach. The arm hit its length clamp partway through delivery, abruptly straightening its elbow. Delivery now approaches the reachable point on the original committed target ray, using the actual shoulder after trunk movement. The correction follows the existing arm-extension phase. It does not retarget the opponent, branch on hit/miss, or lengthen the bones. Resolved contact poses disable that correction so repeat solves retain the physical impact endpoint.

The original ordinary OUTBOXER opponent lead straight resumed from preparation partway through its punch phase, but also restarted a separate launch blend. That double preparation briefly held the glove back and then accelerated it sharply to catch up. Prepared punches now continue their existing phase; unprepared punches retain the launch blend. Startup, recovery, guard duration, committed aim, damage, stamina and counter-window tuning are unchanged.

The earlier hook report misidentified the SLUGGER tick 363 peak as a covering arm. Restoring the saved simulation shows an active `L_STRAIGHT`; this correction is also appended to that historical report.

## Identical-state comparisons

Both engines restore the same original checkpoint and run the same 180 inputs. The baseline uses the two production files preserved at the start of this repair. The checkpoints predate the bad frames, so the comparisons include connected joint history rather than mixing a repaired frame with old history.

| Measurement | Original | Repaired |
| --- | ---: | ---: |
| SLUGGER elbow displacement at tick 363 | 12.4244 cm | 3.7880 cm |
| SLUGGER maximum elbow displacement across the 180-tick replay | 12.4244 cm | 9.0129 cm |
| OUTBOXER wrist displacement at tick 573 | 16.7403 cm | 9.3124 cm |
| OUTBOXER maximum wrist displacement across the 180-tick replay | 16.7403 cm | 9.8966 cm |

The saved fixtures require elbow steps at most 10 cm, wrist steps at most 12 cm, and the existing clearance/contact/bone checks at most 1 mm **for these two fixed replay intervals**. The original code fails the SLUGGER elbow gate and OUTBOXER wrist gate with nonzero engine exit codes. The repaired code passes both fixtures, 8/8 each, including exact restoration. Those local gates are regression bounds, not general speed tuning or an acceptance definition for boxing.

- SLUGGER: [original clip](slugger-before.mp4), [repaired clip](slugger-after.mp4), [frame comparison](slugger-comparison.png), [checkpoint](slugger-checkpoint.json).
- OUTBOXER: [original clip](outboxer-before.mp4), [repaired clip](outboxer-after.mp4), [frame comparison](outboxer-comparison.png), [checkpoint](outboxer-checkpoint.json).

Clips contain 180 frames each, 1.5 simulated seconds at 120 fps, using the production chase camera. Comparison sheets crop labelled diagnostic side views around the punch; their frame increments are two simulation ticks. Both versions leave simulation state unchanged during rendering.

## Counter regression and bounded checks

The first full motion run failed 341/342: the step-out rear straight now hit the opponent's real lead glove. A counter window must not bypass that glove. The original rear-hand re-entry remains a required negative check: it must be counter-eligible, deflect on `glove0`, and finish at the shared rig's actual world-space wrist. The positive native-key counter uses the open lead-straight lane with the same re-entry and original earned window. The separate out-of-range negative still cannot score.

Exploratory counter probes initially supplied legacy movement or the wrong sign for the native anatomical step axis; those probes did not reproduce native re-entry. Their empty results are retained, superseded by the corrected native-axis probe. The new contact-endpoint assertion initially compared a world-space point with a local-space wrist and correctly failed; it now includes the fighter origin, like the production collision check. None of these diagnostic errors changed gameplay rules. All failed logs remain in the history archive.

Final checks: motion **343/343**, punch contact **443/443**, corrected stance/support **278/278**, head motion **153/153**, head attachment **128/128**, Northern Rising **70/70**. Eight 90-second seeded exchanges across four existing attribute profiles, ordinary orthodox and learned southpaw variants, pass **64/64** geometry checks with **1,289** contact events. These variants use the shared engine and technique system. Maximum measured bone error is 0.000000193 m; contact endpoint error is 0.000000169 m; repeated elbow/wrist solve drift is below 0.000000280 m. No penetration was measured in the checked forearm/head, forearm/torso or glove/torso categories. This does not establish clearance of every mesh or every possible pose.

Final logs contain no script errors, parse errors or failed assertions. The motion driver still reports two ObjectDB instances at exit; that existing diagnostic warning remains unresolved. Simulation-step p95 in the matrix ranges from 0.781 to 0.971 ms on this machine; this is not a measurement of perceived input latency or animation quality.

## Current capture and remaining work

The fresh [24-second gameplay capture](gameplay.mp4) shows the production camera behind and above the player. The [diagnostic inspection capture](inspection.mp4) is separately labelled; it is not a gameplay view. [Frame sheet](inspection-sheet.png), [gameplay still](gameplay-frame.png). The final capture uses the exact 141 engine/data/scene files identified in [source hashes](source-hashes.json). Both camera passes preserve simulation state.

Dense before/after punch frames and sampled gameplay/diagnostic frames were visually inspected. They show progressive extension through the old elbow-clamp frame and an attached head through the sampled exchanges. This is frame-based review, not human approval of feel or a claim that the entire film was watched in real time.

The matrix still reaches 0.110165 m elbow displacement per tick in the ordinary SWARMER opponent at tick 4158, with no active punch: the hands are rising into guard. That guard transition needs further motion review. The largest matrix wrist step is 0.134309 m during a player lead hook at tick 192. The current 24-second capture peaks at 0.086403 m elbow and 0.124332 m wrist displacement. These peaks are recorded for follow-up, not declared acceptable merely because clearance checks pass. Complete technique coverage, motion quality and satisfying connected play remain unqualified.

[Verification history](verification-history.zip) retains original and current source, failures, native-counter probes, complete replay timelines, matrix results, saved worst states and selected capture frames. No foundation acceptance or peripheral scope advancement is recorded.

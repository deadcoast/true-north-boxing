# PAC-206: hook loading, rotating cover and impact continuity

2026-10-01. **Foundation NOT_ACCEPTED. PAC-206 remains DOING; OGM-025 remains PACED_REQUIREMENT.**

The original learned southpaw SLUGGER body hook produced a 0.150459 m elbow jump at tick 2434. Its arm was still loading, but shoulder clearance had already faded according to the overall punch clock. Low cover also stayed facing the opponent while the ribcage rotated, forcing the opposite forearm across the torso. Impact resolution could then solve that covering arm again from stale goals and retain joint history from a different pose.

The production repair ties loading clearance to actual arm extension, turns body cover with the ribcage, and preserves both evaluated arms at the swept impact instant. Both elbow and knee histories now record the resolved body. Native guard raising follows an arc about the shoulder, preserving reach instead of cutting a straight chord close to the shoulder. High cover still follows the head. Guard timing, punch startup, recovery duration, committed aim, damage and stamina values were not retuned in the final implementation.

## Reproduced exchange

The saved checkpoint is the original fight at tick/input 2390, before the bad hook. Both versions restore it exactly, then execute the same 180 inputs through the normal simulation and match renderer. The baseline uses the two production files preserved from the start of this repair; the repaired run uses the current source. Each clip contains 180 frames, 1.5 simulated seconds at 120 fps, with the normal gameplay camera. Diagnostic side views are labelled and retained as frame sheets.

| Shared-checkpoint replay | Before | Repaired |
| --- | ---: | ---: |
| Maximum elbow displacement per physics tick | 0.150459 m | 0.072149 m |
| Maximum wrist displacement per physics tick | 0.104217 m | 0.075828 m |
| Maximum head displacement per tick | 0.031160 m | 0.031160 m |
| Maximum knee displacement per tick | 0.027021 m | 0.027021 m |
| Measured forearm/head, forearm/torso, glove/torso penetration | 0 | 0 |
| Rendering changed simulation state | No | No |

[Before](hook-before.mp4), [repaired](hook-after.mp4), [shared checkpoint](hook-checkpoint.json), [before diagnostic sheet](hook-inspection-before.png), [repaired diagnostic sheet](hook-inspection-after.png).

The separate same-clock pose probe reduced the original jump only to 0.130122 m because its preceding pose/history still came from the old solver. That mixed-history comparison is retained in the archive and is not substituted for the connected replay above. Intermediate clearance-only and impact-only attempts also remain preserved: neither eliminated the covering-arm problem by itself. A 100 ms guard transition experiment failed the SLIP_R physical-guard counter check (341/342) and was removed. The final path correction retains the original 50 ms guard clock.

## Bounded verification

Eight seeded sustained exchanges, ordinary orthodox and learned southpaw variants across four existing attribute profiles, passed 64/64 geometry checks with 1,336 contact events. Checks include every resolved impact as well as periodic samples. Maximum limb-length error was 0.000000165 m; contact endpoint error was 0.000000134 m; repeated elbow solve drift was 0.000000282 m. No penetration was measured in the three checked self-body categories. This does not prove all meshes or all possible collisions are clear.

Motion 342/342; punch contact 443/443; corrected stance/support 278/278; head motion 153/153; head attachment 128/128; Northern Rising 70/70. Final logs were scanned: zero script errors and failed assertions. The motion driver retains an intermittent warning about two ObjectDB instances at exit, also present in an earlier run; that warning is preserved and unresolved. Current source parses and `git diff --check` passes. These are bounded automated checks, not approval of the boxing model.

**False-pass correction:** prior stance logs printed 278/278 despite 3,908 script errors. Its contact fixture omitted `kind` and `time`, so `finish` aborted and left the old rig unchanged. Those results are invalid. The fixture now supplies the full stop contact, verifies that `finish` actually saved it, and checks both elbows. The corrected 278/278 run has zero script errors. The previous exchange report now explicitly withdraws its old stance result; original reports and logs remain archived.

The fresh 24-second, 30 fps [gameplay recording](gameplay.mp4) uses the production chase camera. The separately labelled [inspection recording](inspection.mp4) exposes the same poses from the side. [Source hashes](source-hashes.json) bind 141 engine/data/scene files to these captures. [Verification history](verification-history.zip) retains baseline source, intermediate source, failed approaches, logs, metrics, restorable worst states and selected inspected frames.

## Still unresolved

The full matrix still contains 0.124244 m elbow and 0.167403 m wrist movement peaks per physics tick. The largest elbow movement is the ordinary SLUGGER opponent's covering arm at tick 363. The largest wrist movement is the ordinary OUTBOXER opponent at tick 573. The production film still reaches a 0.194151 m wrist peak. These transitions need further route and timing review, distinguishing actual punch speed from abrupt solver movement; passing clearance checks does not make them fluid.

Dense hook frame sheets and individual gameplay/diagnostic frames were visually inspected. The sampled poses keep the head attached and show the documented gameplay view, but frame inspection and scripted exchanges do not establish satisfying human play, full technique coverage or flawless animation. No foundation acceptance or completion is claimed.

## Follow-up diagnosis correction

2026-10-01: The next saved-state inspection showed that the tick 363 SLUGGER elbow peak was the **attacking lead straight**, not a covering arm. The tick 573 OUTBOXER wrist peak was also an active lead straight, resuming from preparation. The earlier covering-arm diagnosis above was incorrect. [Trajectory follow-up](../trajectory-coherence-20261001/report.md) preserves the original states, identifies both causes, and compares repaired replays from identical preceding checkpoints. The foundation remains NOT_ACCEPTED.

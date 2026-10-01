# Contact, return and combination continuity — 2026-10-01

**Foundation status: NOT_ACCEPTED. PAC-206 remains DOING, OGM-025 remains PACED_REQUIREMENT, NDL-013 remains ACTIVE.** This is evidence for four core motion repairs, not acceptance of the boxing model. The current prepared-straight launch and covering-elbow extrema below remain unresolved.

The work follows the connected movement, physical contact, committed aim, recovery and visible-coherence requirements in `docs/boxing-foundations/START_HERE.md`, `True_North_Boxing_Foundation.md`, `Boxing_Styles.md` and their referenced foundation documents. No camera, progression system or peripheral animation was added. `Play True North Boxing.cmd` still launches the working `engine/greybox` source through `tools/play_boxing.ps1`.

## Repairs and shared-state evidence

Each before/after pair starts from the same saved fight state and replays the same 180 native input ticks. The source phases are retained separately in the history archive.

| Fault and checkpoint | Before | Current result |
| --- | --- | --- |
| Covering arm skips part of the guard stroke after impact; ordinary BOXERPUNCHER, input tick6000 | Peak elbow0.137749 m, wrist0.122032 m; guard phase skips0.333333 | Elbow0.076827 m, wrist0.067763 m; maximum phase step0.166667 |
| Opposite hand is almost home but receives a full12 cm return loop when the next punch starts; learned SLUGGER, input tick1310 | Wrist0.120497 m | Wrist0.053140 m |
| Completed uppercut holds the old facing throughout a pocket exit, then snaps when recovery ends; learned SLUGGER, input tick1390 | Facing0.265014 rad per tick (15.18 degrees); player right wrist at tick1418 moves0.118027 m | Facing0.007397 rad (0.424 degrees); that exact wrist transition moves0.004487 m |
| A new punch interrupts recovery and immediately replaces the body's facing; ordinary BOXERPUNCHER, input tick1560 | Facing0.202240 rad (11.59 degrees); peak elbow0.083296 m | Facing0.022754 rad (1.304 degrees); peak elbow0.055283 m |

The contact solver already rewound the rig to the fractional impact instant, but its guard controller retained the end-of-tick value. It now resumes both guard height and guard stroke from the visible contact pose. Hitstop and authored stroke timing remain authoritative.

An opposite-hand return now records the distance still owed at handover and bounds its outside arc by that distance. A glove already at guard does not start another full outside loop. Older saved states without the new arc field use the distance-based fallback.

Recovery blends the body back toward the support controller's live facing. A subsequent punch captures that actual facing and turns toward its fixed committed direction during the existing loading interval. The committed target and direction are not retargeted toward later opponent motion. The same saved values pass through restore and mirrored-stance checks.

## Verification of the current source

| Native driver | Result |
| --- | --- |
| Boxing motion |345/345|
| Physical punch contact |444/444|
| Stance, guard, delivery, combinations and reflection |2238/2238|
| Head motion |153/153|
| Head attachment |128/128|
| Northern Rising |70/70|
| Sustained exchanges: four base styles, ordinary and learned |80/80;1314 contact results across86400 input ticks|

The sustained driver now measures facing changes and checks that guard stroke/height never advance by more than one active tick, including the tick after physical impact. Its current maximum facing step is0.022754 rad. Maximum guard phase/height steps are0.166667/0.1.

All four new saved regressions pass their sampled checks: return9/9, short return10/10, recovery facing9/9 and combination facing9/9. The five prior guard/curve/handoff fixtures were rerun: four8/8; the uppercut7/7 with contact-endpoint measurement explicitly UNSAMPLED because that replay contains no non-miss impact. No earlier fixture bound or production contact expectation was relaxed in this pass.

Sustained maxima: bone-length error0.000000165 m, contact-endpoint error0.000000120 m, repeated elbow/wrist solve drift0.000000430/0.000000133 m. The measured forearm/head, forearm/torso and glove/torso penetrations are zero. These sampled proxy-volume checks do not establish absence of every mesh intersection or qualify the boxing's feel.

## Rendered evidence and provenance

`gameplay.mp4` shows24 simulated seconds from the existing behind-and-above gameplay camera,720 frames at30 fps. `inspection.mp4` shows the same exchange in the explicitly labelled diagnostic side view. The four before/after pairs each contain180 consecutive frames at120 fps. All ten videos passed frame-count and full-decode checks. Every capture reports that rendering both cameras left the simulation hash unchanged.

The comparison PNGs show six consecutive frames around each failure. The gameplay frame and twelve-frame inspection sheet were viewed directly, as were all four comparison sheets. Heads, torsos, arms and legs remain in frame in those comparisons. This was a review of rendered still sequences, not a claim of a real-time human playthrough or animation-authenticity approval. The current24-second capture's maximum elbow/wrist steps are0.080332/0.098537 m.

Before sources are distinct: `baseline-project` precedes all four fixes; `guard-fixed-project` precedes the short-return fix; `return-fixed-project` precedes the recovery-facing fix; `recovery-fixed-project` precedes the combination-facing fix. All after clips and gameplay were recaptured from the final source. `source-hashes.json` covers244 files, including imported-resource identity files. The CRC-checked1706-entry archive contains the current source, affected source files from each prior phase, failing and passing logs, checkpoint/timeline data, selected raw frames and media-verification data.

## Failed probes and remaining work

- The initial180-tick recovery-facing probe imposed a provisional9 cm cap on every wrist step. After the facing fix, it still failed on a later opposite-hand return at tick1508 (0.096351 m). A90-tick probe also failed at0.091639 m. Both failed traces and fixture definitions remain in the archive. The temporary shorter replay loop was discarded. The final facing regression again uses all180 ticks and checks the actual direction-continuity contract; its hand-speed extrema remain reported, not approved. A universal9 cm cap on all punches was not an authored boxing requirement. The old return and short-return regression limits remain unchanged.
- The remaining sustained maximum wrist step is0.112271 m: learned SLUGGER opponent tick5119, first committed tick of a prepared stepping lead straight. The shared-state record contains the actual before/after rig, captured launch arms, preparation progress and head/body pose. This transition is unresolved; it is not classified as acceptable merely because the geometry checks pass.
- The remaining maximum elbow step is0.106764 m: learned SWARMER opponent tick741, the prior lead hand returning while the rear straight loads. Its exact state and both evaluated rigs remain available for further continuity review. No arbitrary speed retune was applied to hide the maximum.
- The native boxing-motion driver still reports two ObjectDB instances leaked at exit. The warning is retained. Current verification/capture logs contain no script or parse errors.
- Review still has to cover the complete connected boxing experience, technique depth, response, strategy and authored movement. Passing the listed checks does not establish those qualities. No task was marked DONE, no requirement was promoted to VALIDATED_COMPLETE, and no package was published.

The unresolved states are `history/settled-drive_boxing_exchange/Godot/app_userdata/TNB Greybox/worst-wrists_step_m.json` and `worst-elbows_step_m.json` inside `verification-history.zip`. Their readable action/body inspections are under `history/settled-peak-inspect/`. The previous tick6028 covering-arm failure is superseded by this report's shared-state repair evidence; its original failed evidence remains intact.

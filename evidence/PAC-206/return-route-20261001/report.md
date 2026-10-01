# Returning-arm route and recovery continuity — 2026-10-01

**NOT_ACCEPTED. PAC-206 remains DOING, OGM-025 remains PACED_REQUIREMENT with no AcceptanceEvidence, and NDL-013 remains ACTIVE.** This continues the two open returning-arm faults from the preceding preparation-return report in the existing match implementation.

## What changed

An opposite-hand combination previously restarted the old hand's return over the remaining duration and unloaded the torso over a fraction of the new punch's startup. These separate restarts accelerated the withdrawing shoulder and returning glove together. A new handoff now retains the previous recovery's elapsed time and duration. Torso, facing and spring continue that phase; the hand and shoulder offset retain the style's return rate. Authored startup, recovery and contact clocks are unchanged.

The hand continues its world-space recovery toward the moving guard. Adding the full shoulder retreat again had counted that displacement twice. Its requested reach is bounded against the final shoulder and current guard home before the ordinary anatomical and clearance solves. Old saved handoffs retain their existing fallback.

The previous elbow plane could point inward after delivery and remain there until the forearm approached the ribs. The clearance solver then had to move it abruptly. A handoff now captures the actual delivered elbow and folds its plane toward guard throughout the body's remaining recovery. This also handles a glove that is already home while its torso and elbow are still unloading. Holding an evaluated impact pose clears the new return constraints before another solve.

## Saved failures and current results

Both fixtures use the same saved fight state and the same full 180 input ticks before and after the change. The original baseline fails each fixture's motion bound. Both now pass 8/8 checks, including bone lengths, sampled self-clearance and guard timing.

| Fault | Turn-start source | Current source |
| --- | --- | --- |
| Ordinary SLUGGER opponent, returning lead elbow at tick 640 | Exact elbow step 0.107242 m | Exact step 0.036283 m; maximum elbow step over the full replay 0.076488 m |
| Learned SLUGGER opponent, returning lead wrist while the rear straight loads | Maximum wrist step 0.116319 m | Maximum wrist step 0.086584 m; original tick-1504 step 0.085194 m |

The existing SWARMER covering-return regression also passes all ten checks: maximum elbow 0.063156 m, wrist 0.099240 m and excess-return-reach measure 0.000335 m. None of the older fixture limits was relaxed.

## Verification

| Current native run | Result |
| --- | --- |
| Boxing motion | 345/345 |
| Punch contact | 444/444 |
| Stance, reflected combinations, save/restore and preparation handoffs | 2814/2814 |
| Head motion | 153/153 |
| Head attachment | 128/128 |
| Northern Rising | 70/70 |
| Sustained four-style ordinary/learned exchanges | 88/88; 1330 contact results over 86400 input ticks |

All thirteen saved regression fixtures pass: the two new failures and all eleven previous fixtures, including the guard-transition hook fixture. An additional earlier hook state was replayed for measurements; that file checks restoration only and has no trajectory bounds. The old uppercut fixture still marks contact-endpoint measurement UNSAMPLED because no non-miss impact occurs in it.

The sustained source is the final `bounded-matrix` run, with all other final drivers under `final-*`. Maximum bone-length error is 0.000000165 m, contact-endpoint error 0.000000134 m and repeated elbow/wrist solve drift 0.000000273/0.000000169 m. Three sampled forearm/head, forearm/torso and glove/torso penetration measures remain zero. Maximum facing change is 0.017620 radians; preparation disagrees with supported facing by at most 0.0000000298 radians. These measurements cover the proxy rig and tested sequences, not every visible mesh intersection or the complete authored feel.

## Rendered evidence

The before/after elbow and wrist films each retain 180 consecutive frames at 120 fps. The elbow comparison shows ticks 637–642; the wrist comparison shows ticks 1501–1506. Their native rendered frame sequences were viewed directly. `gameplay.mp4` and `inspection.mp4` contain the same 24 simulated seconds, 720 frames at 30 fps, from the existing gameplay camera and explicitly labelled diagnostic side camera. This inspection is not a real-time human playthrough.

Only `capture-final-*` provides current after/gameplay evidence. Earlier `capture-*-after` folders are intermediate captures and are not the final verification. `source-hashes.json` identifies the 244 source/resource files used by the final checks and captures. Media frame counts, complete decoding and render-read-only simulation checks are retained with the archived run history.

All six films passed frame-count and full-decode checks, and all final captures left the simulation hash unchanged. The gameplay frame and twelve-frame inspection sheet were also viewed directly. The CRC-checked history archive contains 1221 entries (41,224,594 bytes), with SHA-256 `31bc19162ddad369394ce0b2b6c44ae4ebb72b25f4ec32423f122eb9588a02a7`.

## Failed candidates and remaining limits

- Preserving the recovery phase while still transporting the entire returning arm with the shoulder reduced the wrist maximum only to 0.103829 m; the new wrist fixture still failed. The source and trace remain under `phase-return-candidate` and `phase-return-wrist`.
- Continuing the world path exposed another edge case: a glove already at home selected the final elbow plane immediately, creating a 0.112982 m step in a late SWARMER exchange. The final plane follows the remaining torso phase. The intermediate source, state and same-clock comparison remain in the archive. The comparison reduces that exact candidate state to 0.093239 m; it does not establish acceptance of that guard transition.
- The world-path candidate also produced 0.034392 m of diagnostic excess return reach. The final shoulder/guard bound reduces the sustained maximum to 0.013775 m. Subsequent anatomical clearance can still move the hand outside the requested envelope; that interaction remains open for review.
- Current sustained extrema are a 0.100061 m elbow step at ordinary BOXERPUNCHER opponent tick 2633, with no active punch, and a 0.110675 m wrist step at ordinary SLUGGER player tick 484 during an outgoing lead straight. They are distinct from the repaired returning-arm states. Their full snapshots and readable inspections are retained. A movement magnitude alone does not establish a discontinuity or acceptable boxing motion.
- The boxing-motion driver retains its two-ObjectDB-instance exit warning. No final driver reports a script or parse error. Failed candidates and earlier evidence were preserved.
- Complete connected boxing quality, response, technique expression and the foundation's feel gates remain unaccepted. No task or requirement was marked complete and no package was promoted.

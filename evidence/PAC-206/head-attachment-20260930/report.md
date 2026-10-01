# Head, guard and support repair - 2026-09-30

**Foundation status: NOT_ACCEPTED. PAC-206 remains DOING; OGM-025 remains PACED_REQUIREMENT.**

The user rejected the boxing model after prior count/recovery work. This repair addresses reproduced core anatomy defects. It does not supersede that rejection or accept the whole game.

## Reproduced failures

- A separately authored head stayed behind while support and delivery constraints moved the chest. The old neck test permitted 0.37 m; the new baseline found a 0.274 m neck and up to 81.5 degrees of bend relative to the spine. Only 32/96 attachment checks passed before repair.
- During a learned rear straight, the fighter's own glove came within 0.0636 m of the head centre. The rendered snapshot showed the intersection.
- A recovering foot received load before landing, shifting the connected head 0.054 m in one tick. Removing that premature return alone exposed a 0.073 m opposite-leg transfer; the transfer duration also needed to follow the actual load change.
- A seeded defensive read selected the same absolute slip direction in mirrored stances. The repeated-jab sequence then diverged by 0.46 m despite identical contact outcomes.

## Source changes

The native solver attaches a fixed 0.15 m neck to the final shoulder/spine pose, bounds its bend, and keeps head orientation, collision and interpolation on that pose. Gloves route around the fighter's own skull, with fixed arm lengths; the final pose also supplies guard homes and elbow history. High guard sits in front of the face with clearance. Opponent aim remains committed at launch.

Footwork loads the standing leg before lifting, retains that load until landing, and then returns through bounded grounded recovery. Native defensive reads choose inside/outside relative to the incoming hand. The gameplay chase camera is unchanged.

## Evidence and limits

- Native attachment/self-clearance matrix: 128/128 across both fighters, four archetypes, both stances, ordinary/learned technique, body movement and ten punch families at head/body height. Minimum own head/glove centre separation: 0.32175 m (physical radii total 0.32 m).
- Full motion matrix: 342/342; contact/guard: 443/443; head reaction/save/interpolation: 153/153; Northern Rising: 68/68. The final defensive-read fix additionally passes mirrored stance/replay 278/278, native counter transitions 40/40 and legacy geometry 5/5.
- The rendered sequence exercises ordinary and learned stances, slips/dips/pulls, straights/hooks/uppercuts and head impact/recovery. It is captured every two 120 Hz simulation ticks and encoded at 60 fps, not a wall-clock latency or performance measurement.
- `review.mp4` uses the production chase camera. `inspection.mp4` uses the existing explicitly labelled diagnostic side view. Comparisons restore the same saved failure tick and rerun the repaired constraints; they are matched-pose comparisons, not two separate playthroughs.
- Source/configuration hashes cover 140 files. The existing launcher still runs this working source project.

Some old checks encoded bad assumptions: the rear-jaw test demanded glove/head overlap; the buffer test demanded every punch hit or block; counter fixtures assumed a stationary head and used a canned shortcut for weaving. Updated checks require bounded jaw clearance, ordered unique physical resolutions, actual continuous weaving, available counter lanes, premature misses and real glove deflections. Failed probes and earlier results are retained in `verification-history.zip`.

This is targeted mechanical and rendered evidence. It does not certify every possible intersection, full-bout feel, controller latency, artistic quality or a flawless boxing foundation. Wider core review remains open. No new knockdown, campaign, ability or camera feature was added in this repair.

Final GPU capture: 28/28 rendered interpolation, attachment, self-clearance, support, gaze and state-immutability checks; 720 frames per view, 1280x720, 60 fps, 12 seconds. Maximum sampled head movement was 0.03300 m per 120 Hz tick. The final chase and side frame sheets were visually inspected after encoding.

A prior delivery recording was rejected after frame inspection found the automatic focus-loss controls panel covering the fight. Its footage is retained; the published recordings close that panel before capture.

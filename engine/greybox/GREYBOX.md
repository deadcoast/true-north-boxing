# TNB GREYBOX v6 - the engine foundation (NP_14)
Run (no editor): `godot --path .\engine\greybox`

Blue capsule = you (head sphere shows where the sim says your head is - a
slip is visible). Red capsule = the boss, driven by the real compiled PBN.
Yellow flash + swell = tell; hit him during it = interrupt + flash window.
All numbers load from `combat_tuning.v1.json` - edit it, press R, feel it.

PAD: LS move | RS flick = punch by angle | RT block (150ms perfect window)
     LT+LS lateral = slip, LT+LS fwd = weave, LT+LS back = lean | LT+punch = body
     RB = power | LB+haymaker flick @100 = ABB | A = rise beat / corner send | X = corner rest
KEYS: WASD | J/K jab/cross, U/I hooks, O uppercut | Space block | Q/E slip L/R
      V weave | B lean | T taunt | Shift power | C body | H hissatsu-arm
      ENTER = rise beats when dropped | 1/2 = corner pick
META: F1-F4 boss (Vane/Yuri/Moreau/Sam) | F6/F7 prev/next of ALL 24 bosses
      R reload tuning | F5 new dual
DEMO: `godot --path engine/greybox -- demo boss=7` - a scripted fighter plays
      the scene on its own (attract mode; also the presentation soak).

## What changed in v6: the sim is a thing of its own
`sim/core.gd` (TNBSim) is the whole fight: pure, no Nodes, no wall clock,
seeded RNG, fixed 120Hz ticks driven by one intent dictionary per tick.
`main.gd` only draws it, samples the pad, and plays FX off the sim's event
list. `sim/clock.gd` is the one place render time meets sim time (fixed-step
accumulator + interpolation alpha). `sim/tests.gd` drives the sim directly.
Consequences you can feel:
- Frame data is real: a 160ms jab is 19 ticks at every frame rate.
- Hitstop is sim state (the freeze counter), not an engine time-scale hack;
  a punch pressed during hitstop is buffered, never eaten.
- Dodges are geometry (NP_14 C2). There is no slip-beats-X table anywhere:
  a punch is a region in the attacker's frame, your head is a point the
  dodge displaces. Slips beat straights, a slip into his hooking hand eats
  the hook, ducks go under straights and hooks and eat uppercuts, the
  overhand comes down onto a ducked head, weaves go under hooks, lean-back
  beats everything at range and nothing inside. Body shots ignore slips.
- The boss defends with the SAME geometry (C6): a read is a dodge choice
  scheduled to be live on the impact tick. Flagged sequences raise his read
  chance and nothing else (C7). A live counter window cuts it to a quarter.
- Scoring is NP_01 canon now: DROP 1, FLASH DROP 2, SEGMENT KO 3 (third
  knockdown or a failed count), cumulative across the dual, most points
  wins, EP breaks ties. A KO forfeits the loser's remaining time and pays
  the winner the shadowboxing trickle (+1 Tension per 10s). v5's "three
  total drops ends the dual" was not canon and is gone.
- All 24 compiled bosses load. The boss agent runs an ACTION VM: every
  verb the PBN compiler emits executes (RUSH/HERD/GUARD_ADVANCE/STEP_OUT/
  ANGLE_STEP/CLINCH_ATTEMPT/DRAG_ROPEWARD/COUNTER_STATE/COUNTER_ON_BLOCK/
  WALK_STRING/MIXED_STRING/BODY_SERIES/DELAY/pause/... 39 verbs), every
  punish response resolves (force, immediate, speed xN, swap_weights,
  w()+=, immediate_counter, corner_cut_rush, over_under_reversal, to_body,
  targets_flag, pressure, counter_exit...). Sensors the hooks ask for are
  parsed from the pattern itself (passive>Ns, holds_center_Ns, guard Ns,
  perfect_play_Ns).
- The second knockdown in a segment tightens the standing-eight window
  (one beat of forgiveness gone, NP_03 s9); the third is the KO.

## PAC-054 in the build: EVERY HOOK IS LIVE
The eleven behaviour sensors the patterns ask for exist now, each with a
gate that proves it fires at its threshold and never early:
- locks_to_single_tempo (Chiamaka): six punch intervals within 15% of
  their median at a real cadence; five are not enough. Vary your rhythm.
- neutral_reset_attempt (Deshawn): a full second out past engagement, not
  leading, not closing - he closes it for you (Turnpike has no neutral).
- casts_<house>_native (Remy): your fighter's hissatsu carries its house
  from the library; cast a Moreau native at a Moreau and Ingot comes.
  RORY carries Aurora Borealis Breaker, PRIYA First Snap, MARCUS Chinook Rush.
- trap_stance_hands_down (Marta): refuse to lead for 3s and she drops her
  hands (capsule darkens, HUD says so). Punch into it and Mirror answers.
- reacts_to_fake_tell (Tam): in phase 1 some tells are performances -
  drawn identically on purpose. Flinch (dodge, block press, punch) during
  one and TwoBridge comes. Phase 2 retires the borrowed clothes.
- audio_assist_reliance (Choir): F8 toggles an audio tell cue; three
  sub-300ms reactions with it on tells Choir you are listening, not
  looking, and he swaps his verse and refrain for 10s.
- clinch_input_spam + the referee (Alfie): G / R3 grabs. Three grabs in
  8s is holding without work: -2 EP and Alfie's over-under reversal.
- sprint_approach (Marta, Tam): Ctrl / L3 sprint-step, 0.8m, -4 stamina;
  a sprint toward them is the Retreat Cutter / widened-angle trigger.
- straight_line_retreat (Moira): 1.2m of backing without an angle.
- backstep_chain3 (Deshawn): three sprint-steps away inside 4s.
- rope_backing (Vane): backing onto the ropes, as distinct from sliding
  along them (rope_touch fires either way).
Clinch scramble (NP_03 s7): at 0-range, G / R3 starts a 2s duel. Tap
ENTER / A on the cue (RFX-gated window); two beats win position (he is
walked 50cm ropeward) or, holding C / LT on the resolve, a reset (center
ring, both +5 stamina). No taps and you are dragged. Bosses grab with the
same duel (CLINCH_ATTEMPT needs 2 beats to beat, DRAG_ROPEWARD 3).
Referee (NP_01 s5): dirty bosses foul on the break of clinches they win -
warning, then -5 EP, then a DROP awarded on the third. Alfie's META banks
exactly two and his phase 2 (dirty_flirtation_stops) is warnings_banked==2;
the count sits on the score bug. Every phase-trigger form is executable
now: 13/13.

## Verification (agent-run, headless Godot 4.3, this container)
```
godot --headless --path engine/greybox -- smoke boss=N   # N = 0..23
godot --headless --path engine/greybox -- determinism
godot --headless --path engine/greybox -- geometry
godot --headless --path engine/greybox --quit-after 3600 -- demo
python3 pbn_compiler.py --margins
```
- SMOKE: 84/84 GREEN on every one of the 24 bosses (2,016 assertions).
  Covers: C3 buffer (same-tick / 3-ticks-early fires / 8-ticks-early
  expires / buffered through hitstop), C2 reach, C7 tracker flag -> read
  probability up with boss offense byte-identical, interrupt + flash +
  tension + C5 freeze, DROP 1 / FLASH DROP 2 / SEGMENT KO 3 with the dual
  continuing, standing-eight with three timed rise beats + crowd surge,
  guard break/refill + perfect-block window, hissatsu arm + bar accounting,
  live agent, action VM (composite verbs, COUNTER_STATE trap, clinch drag),
  parsed sensors, full dual flow (corner picks, relay CHARGED, rotation,
  verdict), zones + corner x1.5, trap x1.4 reads, herding both ways,
  geometric dodges in play, counter consumption + landing, punish/bait
  hooks from pattern data, the PAC-054 sensor gates (fires at threshold /
  never early, both directions for each), the clinch scramble (win
  position, win reset, lose), the referee ladder on Alfie, and static
  coverage: 39/39 action verbs, 53/53 punish responses, 13/13
  phase-trigger forms.
- DETERMINISM: 8/8 GREEN. One 24,000-tick scripted input log run three
  times (twice tick-by-tick, once through the jittered 7-40ms frame loop
  the game uses): all 400 state hashes identical, every hash bit-exact
  over positions, pools, timers, queues, flags and the RNG state. The log
  provably exercises hits both ways, counters, flash windows, interrupts,
  drops, eight-counts, segment ends, evasions, blocks, clinch scrambles,
  sprint-steps and sensors. A different seed diverges.
- GEOMETRY: 5/5 GREEN. The emergent dodge table matches the consensus
  rows in all four orientations (boss->player, player->boss, both hands);
  body shots land through slips/ducks; every boss read is a valid evasion
  over 400 draws; a scheduled read is live on the impact tick for every
  startup from jab to haymaker.
- MARGINS: GREEN. Tell floors vs Hick-Hyman (a=225ms, b=150ms/bit):
  normal 400 clears the known-pattern read (RT(1)=375) by 25ms and sits
  125ms under a cold 3-way read on purpose; SPECIAL 700 clears the cold
  read by 175ms; ARMORED 1000 by 475ms. Every authored SPECIAL/ARMORED
  string clears it (80 strings, 24 patterns).
- SOAK: real scene, 3600 frames headless with the scripted fighter on
  Alfie, Marta, Tam and Moira: zero errors; clinches, beats, referee
  calls, stances, sprints all rendered. The soak caught a real one: two
  bodies dragged into the same corner collapsed to one point (no facing,
  camera look_at failed) - the sim now keeps bodies apart.
- Bugs the loop caught before you ever loaded it: inputs pressed during
  hitstop were dropped (v5 and the first v6 core); the boss's read fired
  its dodge at punch startup so slow punches always found the head back
  in place; Sam Tagaq's strings executed nothing (non-punch verbs were
  silently skipped in v5); phase-locked punish strings were treated as
  unknown; the v5 dual ended on any three drops (not canon); a lateral
  slide along the ropes read as backing because the boss chases the
  intercept (the sensor was right, the first test was wrong).
- NOT verified: game feel. That is the part that is yours, whenever.

Posture (PACER CLIENT FIXES, in force): one development thread, [B]-shape,
agent verifies in-container with headless Godot; no user load-and-test.
PCUC: every claim in docs/NP_14_ENGINE_THEORY.md names the test above
that proves it, and the doc claims nothing these runs did not show.

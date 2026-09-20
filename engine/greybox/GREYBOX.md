# TNB GREYBOX v6 - the engine foundation (NP_14)
Run (no editor): `godot --path .\engine\greybox`

Blue capsule = you (head sphere shows where the sim says your head is - a
slip is visible). Red capsule = the boss, driven by the real compiled PBN.
Yellow flash + swell = tell; hit him during it = interrupt + flash window.
All numbers load from `combat_tuning.v1.json` - edit it, press R, feel it.

PAD: LS move | RS flick = punch by angle | RT block (150ms perfect window)
     LT+LS lateral = slip, LT+LS fwd = weave, LT+LS back = lean | LT+punch = body
     RB = power | LB+haymaker flick @100 = ABB | A = rise beat / skip card / SEND
     CORNER: X swap | Y super | B save the bar | D-left/right tactic 1-2 | D-down staff 1
KEYS: WASD | J/K jab/cross, U/I hooks, O uppercut | Space block | Q/E slip L/R
      V weave | B lean | T taunt | Shift power | C body | H hissatsu-arm
      ENTER = rise beats when dropped | 1 = skip the card / SEND from the corner
      CORNER: 2/3/4 tactics | 5 super | 6/7/8 staff | 9 save the bar | 0 swap
META: F1-F4 boss (Vane/Yuri/Moreau/Sam) | F6/F7 prev/next of ALL 24 bosses
      R reload tuning | F5 new dual
DEMO: `godot --path engine/greybox -- demo boss=7` - a scripted fighter plays
      the scene on its own (attract mode; also the presentation soak).
      `-- demo seg2 boss=7` starts at a CHARGED R2 with a full bar and has
      the scripted fighter cast North Star, so the T3 afterimage shows
      inside the first half minute.

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
  RORY carries Aurora Borealis Breaker, PRIYA Marginalia, MARCUS Chinook Rush, JUNE First Snap.
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
Clinch scramble (NP_03 s7): at 0-range, G / R3 starts the duel. Bosses
grab with the same duel (CLINCH_ATTEMPT needs 2 beats to beat, DRAG_ROPEWARD
3). See PAC-055 below for the cue.
Referee (NP_01 s5): warning, then -5 EP, then a DROP awarded on the third -
both ways. Alfie's META banks exactly two and his phase 2
(dirty_flirtation_stops) is warnings_banked==2; the count sits on the score
bug. Every phase-trigger form is executable now: 13/13.

## PAC-055 in the build: THE RULES RUN BOTH WAYS
- Fouls are geometry, like everything else. A BODY punch that still reaches
  a LEANING torso lands on the belt line the lean lifted toward it: LOW
  BLOW. A looping punch (overhand, haymaker) that lands on a DUCKING or
  WEAVING head comes down on the back of it: BEHIND THE HEAD. Same rule for
  you and for him. A foul punch does half damage and scores no EP; the ladder
  is warning / -5 EP / a DROP awarded to the other side from the third on.
  You will read it on the feed the first time: "he was leaning; the belt line
  came up".
- Bosses know the count. A clean fighter PULLS a punch that would foul (the
  lean-back now neutralizes his body work; a duck neutralizes his overhand -
  read the feed: "he pulls it"). A dirty fighter takes the call until his
  META cap, then pulls too - Alfie at two warnings stops throwing into your
  lean. Warning-count literacy is a real tactic now.
- The clinch cue SHRINKS: four cues, each interval 0.8x the last (700, 560,
  448, 358 ms), the tap window 30% of the interval but never under the RFX
  floor (80-160 ms) - so RFX decides the last cue (RORY 14 ticks, PRIYA 16).
  Sides alternate: LS left / right (or A / D) on the cue's side; ENTER / A is
  the button-chord parity path. Wrong side spends the cue; a tap ahead of
  the cue locks it - mashing loses every time.
- A wobbled boss (composure under 35%) GRABS at 0-range once per segment
  and buys himself the clinch. Win the scramble and he is walked ropeward
  anyway. Wobbled fighters move at 70% - yours too.

## PAC-056 in the build: THE SPELLBOOK IS DATA
- Every one of the 87 library moves executes from its record: startup
  cinematic (0.9-2.4s, the caster locked and closing half a metre) -> effect
  block -> aftermath. Effect types DMG / DISPLACE / STATE / BUFF / SHRED /
  WALL / BURN all have handlers; the 36 named states and 14 named buffs each
  do a specific thing (foot freeze slows his feet to 60%, tell-jam drops his
  read to 5% or draws his tells blind for you, counter stance turns his next
  punch into your flash window, auto-slip is five seconds of untouchable, The
  Mean flattens your haymaker to your jab's average, forward glide is 150%
  feet, Long Winter doubles your stamina regen...). The three [SEALED] moves
  are authored-absent: arming them throws the normal punch.
- The motion is the spellbook (NP_05 s4): LB + the move's family motion -
  haymaker flick for HAYMAKER, hook for ARC, straight for PISTON, uppercut
  for RISE, LB + RT held 400ms for WALL. Cost is the tier's Tension (T0 10,
  T1 35, T2 25, T3 50), never the whole bar; insufficient Tension throws the
  normal punch. CHARGED halves the first cast and unlocks T3; the relay
  chain counts consecutive charged segments and North Star scales with it.
  RORY carries Aurora Borealis Breaker, PRIYA Marginalia, MARCUS Chinook Rush, JUNE First Snap.
- Counterplay is the move's own profile (NP_05 s9): a jab-class punch inside
  the window (500/700ms) breaks an interruptible cast - half the cost back to
  the caster, +5 Tension and a flash window to you. At resolve: a timed WALL
  negates it (and any T1+ breaks the wall at cost parity), a geometrically
  valid dodge chips 40% (PISTON profile: full evade), a block takes 60% + a
  heavy shred (PISTON 70%; "dodge-only" moves ignore the block unless it is
  perfect). Walk out of reach and the super finds air.
- Every boss desperation casts BY NAME from the library: Yuri's Grain
  Elevator shreds 40 guard, Moira's Undertow throws you 1.5m ropeward, Ada's
  Heat Advisory burns 20 stamina, Deshawn's Rush Hour is five packets, Marta
  raises Premiere Neige, Vasile raises The Mean, Kannagi's Fudoshin counters
  the punch that tries to break it, the Commissioner ARMS [SEALED-SECRET]
  and casts The Commissioner's Due. 21 cast by name, 3 authored-absent.
- WALL GAUGE (NP_05 s8): Sam Tagaq fights behind 100 points. Only counters
  (x1.0), power punches (x0.8), body work (x0.6) and hissatsu (x1.5) chip
  it; jabs do nothing and three of them into it trip Sam's literacy hook.
  His composure is shielded until it breaks: TRUE OPEN 8s at x1.25, then it
  reforms at 60, then 30, then it is gone for good. HC-0's 60-point wall
  leaves him at 40 and meets you again on the next boss. Your own T2 walls
  work the same way scaled down (Shield Wall 20, one reform).

## PAC-057 in the build: THE MIND GAME (feints, NP_03 s8)
- Tap a punch and let go inside 80ms (10 ticks; key release, or the stick
  coming back after a flick) and it is a FEINT: no punch, the punch's own
  stamina comes back, 1 stamina goes, you recover in 150ms. The 11th tick is
  a punch. The read he committed to your press stands: he slips at air (and
  his dodge runs its course - a body punch is the follow-up a slip cannot
  answer) or flinches his guard up for 400ms. A drawn feint costs him 1
  guard and 10cm of ground. It never breaks a cast - only a landed jab does.
- He learns. Three identical feints in 10s and he stops reacting to that
  one (he cancels the read and keeps his hands); another row still draws;
  ten seconds later the first works again. Feints are tracker tokens too
  (F_R_HOOK), so a feint-heavy rhythm gets flagged like any other pattern.
- Sensors: player_feint and player_feint_<family> fire for the pattern hooks
  to bind (none of the 24 bind them yet; NP_04 s6's feint(Sx) string
  variants are the boss-side counterpart and are not in this pass).

## PAC-058 in the build: THE STOOL AND THE RELAY (NP_10 s4-s6, NP_05 s6)
- A segment ends into a 4s broadcast CARD (who took it, EP both ways, the
  Tension carried and what this fighter banked, RELAY CHARGED + chain when
  it applies). 1 / A skips it. Then the CORNER: 45s on the clock, TWO
  actions, and the clock does not wait. Send early with 1 / A and the next
  fighter comes out whole; let it run out and they come out at 80% stamina
  (NP_01 s5 overrun). Everything the corner offers is data in
  `tactics.v1.json` (`data/tactics.v1.json` is the vault copy):
  - SWAP: the reserve (JUNE) or any not-yet-fought slot takes the next slot;
    the first swap of the dual is free, then 15 Tension. Fought fighters and
    the slot itself are refused, so is a swap you cannot pay for.
  - SPECIAL TACTIC (3 equipped of the 8 NP_10 names): Body Doctrine (10,
    body drain x2), High Guard Order (10, guard decay halved), Cut the Ring
    (10, herd x2 + free sprints), Feint Storm (10, free feints + his punish
    hooks off 30s), Ice the Clock (15, the clock runs 1/0.8 while you lead on
    EP), Read the Corner (15, tells 25% longer), Open Season (15, +100ms
    counter windows, guard cap -20%), Second Wind Call (20, +40 stamina). One
    corner of cooldown between uses of the same tactic; the cost is refused,
    not borrowed.
  - SUPER (one per dual, free): Iron Resolve - 30s where a knockdown becomes
    a wobble at 1 composure instead. Perfect Round (Tension x2), Switch-Up
    (EP +10% and +50ms counter windows, the triangle lie) and Hostile Crowd
    (recorded; there is no enemy corner to lock yet) are in the data.
  - STAFF (3 dressed, per-dual charges): Patch Job (+30 composure, 2),
    Raise the Roof (+8 Tension now, 2), Loosen Up (110 stamina cap, 1); The
    Reveal (names the next boss, 1) and Chalk Talk (15s tell highlight, 1)
    are in the data.
  - SAVE THE BAR: no casting next segment (LB + motion throws the plain
    punch); win it anyway and +5 lands at the card.
- The relay is arithmetic you can read on the score bug (NP_05 s6): 25+
  Tension banked in a segment links the chain (RELAY x1, x2, x3), under 10
  breaks it, a lost segment with 10+ keeps it. A CHARGED entrance is a 10s
  surge (feet +10%, the bug says CHARGED), the first hissatsu at half cost,
  T3 unlocked. Chain 3 is FULL RELAY: T4 costs 75 and the T3 cast draws the
  element trail.
- Afterimage: a T3 cast from R2 on carries the previous fighter as a spirit
  ghost behind the caster for the windup (RORY stands behind PRIYA's North
  Star). `-- demo seg2` is the quick way to see it.
- Not in this pass: The Talk (no personality data on the cards yet), the
  enemy coach's corner (NP_10 s9), the 4 unnamed launch tactics, staff
  passives and levels, manager-mode delegation.

## PAC-059 in the build: THE THREE RINGS (NP_06)
- Every fighter carries STYLE / ELEMENT / HOUSE: the four Millbrook cards in
  `sim/core.gd` (RORY boxer-puncher/FROST/no-name, PRIYA out-boxer/GALE,
  MARCUS slugger/GRANITE, JUNE swarmer/FROST) and all 24 bosses from their
  pattern META. The rings are data in `affinity.v1.json` (the vault copy is
  `data/affinity.v1.json`); feuds come from `feud_graph.v1.json`. The HUD
  names both fighters' rings, the capsules carry the element's tint (frost
  blue-white, gale silver, granite amber, timber green), and the opening 3s
  of every segment show the MATCHUP card: both stacks, whose edge each ring
  is, the reason in one line ("movement and jabs make power irrelevant"),
  the feud banner when the crowd knows the history.
- RING 1, the triangle: SWARMER > OUT-BOXER > SLUGGER > SWARMER; a boxer-
  puncher is outside it. The advantaged side scores +10% EP on clean hits
  (every fifth clean blow is worth 3) and reads +50ms on every counter
  window. The other side loses nothing: his edge, not your debuff. Switch-Up
  from the corner is the lie - your card counts as advantaged whatever the
  truth - and it never doubles a true edge or removes his.
- The style packages are live for both fighters (s1.2): a swarmer's inside
  hooks and uppercuts cost 20% less stamina (inside 1.3m), clinch windows
  x1.25, herding x1.5, but 10% less reach and guard; an out-boxer's straights
  reach 12% further, sprint-steps cost 15% less, back-steps run at 85%
  instead of 70%, but power punches land x0.9 and the weave arc is 10%
  narrower; a slugger shreds 30% more guard with power and haymakers, has
  15% more chin and hits 10% harder on the ropes, but his hands are 10%
  slower and his slip windows 15% shorter. Yuri's chin is 138 to Sam's 120;
  Alfie's jab reaches 1.845m and pushes 18cm; Vane's straight reaches 2.3m.
- RING 2, the element: FROST > GALE > GRANITE > TIMBER > FROST, on the
  hissatsu only (normal punches stay boxing). Your element over his: the
  hissatsu lands x1.10 and costs 10% less. A move of your own element is a
  x1.30 spike on top. His element over yours: his timed walls stand +1s
  against you (and yours against him when it is the other way). Every
  numeric packet scales - DMG, SHRED, BURN, DISPLACE, WALL points.
- RING 3, the house: a FEUD edge in the graph (Tremblay-Moreau, Reyes-
  MacIsaac, Kowalchuk-Reyes, Tremblay-sealed) earns Tension x1.25; a house
  native thrown by its own blood is x1.10 more. Lineage qualifiers in the
  META (reyes_origin_line, petrov_root_system) resolve to the house.
- The cap: spike x edge x native on one cast is x1.573; it clamps to x1.5.
  Heat Advisory thrown by Ada is the doc's own example, x1.43 (Okafor native,
  GALE on GALE).
- Not in this pass: dialect familiarity (NP_02 s3 Pattern Intel), The Talk,
  boss-side analogues for the four package edits that need an input the
  boss does not have (punch stamina, clinch windows, back-step, hand-speed
  startup: bosses land on the act), the boss's +50ms counter window (bosses
  counter by authored string, not by window), feud Tension for the boss
  (bosses have no bar). Anders Vey ("varies") and Ioan Vasile ("rotating")
  are element-neutral until their authored mechanics exist. The four cards'
  rings are editorial (see REGISTER_COMMANDS_008) until the content lane
  confirms them.

## Verification (agent-run, headless Godot 4.3, this container)
```
godot --headless --path engine/greybox -- smoke boss=N   # N = 0..23
godot --headless --path engine/greybox -- determinism
godot --headless --path engine/greybox -- geometry
godot --headless --path engine/greybox --quit-after 3600 -- demo
python3 pbn_compiler.py --margins
```
- SMOKE: 169/169 GREEN on every one of the 24 bosses (4,056 assertions).
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
  position, win reset, lose), the referee ladder on Alfie, the PAC-055
  gates (low blow / behind the head by geometry with their legal twins,
  the player-side ladder to the awarded DROP, clean-boss pull vs dirty-boss
  foul-to-cap, the shrinking cue's intervals and RFX floor, wrong side and
  mash both losing, the survival grab once per segment and never from
  range, the 70% wobble), the PAC-056 gates (effect coverage over all 87
  moves; desperations by name for 24/24; interrupt inside vs after the
  window, hook vs jab; full / 40% / 60%+shred at resolve; the PISTON
  profile; walls both ways incl. cost-parity break and perfect negation;
  DISPLACE, BURN, SHRED, foot freeze, tell-jam both ways, counter stance,
  The Mean, stamina x2, forward glide, tension on hit, two-hit echo,
  beats_duck_reads, T3 lock + relay-chain scaling, arm_only; Sam's gauge
  source factors, break/open/reform/gone; HC-0's migrant wall), the PAC-057
  gates (the 80ms edge at 10 vs 11 ticks, the read drawn over 30 seeds with
  guard drain and nothing landing, the spam cutoff / other row / 10s reset,
  never breaking a cast, tracker tokens, herding + sensors), the PAC-058
  gates (the 4s card and its fields; the 45s corner timing out into the
  80% overrun on the last tick and not before; two actions with the third
  refused; send at full stamina; swaps - reserve free, second at 15, a
  broke swap and a fought fighter refused; every tactic in the data with
  its effect measured next segment: Body Doctrine's 12-stamina body hook,
  High Guard Order's halved decay vs a control, Cut the Ring's free sprint
  and doubled herd, Feint Storm's free feint and 30s hook suppression, Ice
  the Clock's 150 ticks per 120 while leading and 120 when not, Read the
  Corner's x1.25 tell on the live boss, Open Season's 0.8 guard cap and
  500ms slip window, Second Wind's 80->100 after an overrun and its refusal
  at 5 Tension, the one-corner cooldown; every super: Iron Resolve holding
  the fighter up at 1 composure for 30s then drops resuming, once per dual,
  Perfect Round's 10->20, Switch-Up's 22 EP from ten jabs and 450ms window,
  Hostile Crowd recorded; staff: Raise the Roof +8, Loosen Up 110 cap,
  Patch Job's two charges then refused, The Reveal naming the next slot,
  Chalk Talk's 15s highlight on the first tell then gone; save the bar
  refusing the cast and paying +5 on a win; the relay chain [1,1,2] over
  30 / 12 lost / 26 with an empty 4 breaking it, FULL RELAY at 3 pricing
  T4 at 75; the T3 afterimage naming the previous fighter), the PAC-059
  gates (24/24 patterns and 4/4 cards dress to ring keys and the matchup
  card fires at every load; the triangle from both sides with ten clean
  jabs = 22 EP and a 450ms slip window for the advantaged card, 20 and
  400ms for the other, 20/20 for a boxer-puncher, mirror and purist lines;
  Switch-Up as the lie vs the truth; the element multiplier as a value and
  as real damage (41.8 vs 29.3), the -10% cost, the neutral and beaten
  cards at x1.0, the +1s wall both ways; spike x native = 1.43 and the
  1.573 clamped to 1.5, no home bonus for the wrong house; the feud edge
  earning 12.5 for 10, a non-edge 10, a lineage qualifier resolving, a DEBT
  edge not counting; every package edit for all three styles measured
  against the boxer-puncher control on the same seed, and the boss-side
  edits on Yuri, Alfie and Vane against Sam), and static coverage: 39/39
  action verbs, 53/53 punish responses, 13/13 phase-trigger forms, 7/7
  effect types, 36/36 states, 14/14 buffs. Every entry in tactics.v1.json
  (8 specials, 4 supers, 5 staff actives) has a gate above; every key in
  affinity.v1.json has one.
- DETERMINISM: 13/13 GREEN. One 24,000-tick scripted input log run three
  times (twice tick-by-tick, once through the jittered 7-40ms frame loop
  the game uses): all 400 state hashes identical, every hash bit-exact
  over positions, pools, timers, queues, flags, the corner's state and the
  RNG state. The log provably exercises hits both ways, counters, flash
  windows, interrupts, drops, eight-counts, segment ends, evasions, blocks,
  clinch scrambles, sprint-steps, sensors, the referee, the survival grab,
  hissatsu casts from the library (player and boss), feints with some
  drawing his read, two segment cards with corner actions taken, and
  matchup cards with a ring live. A different seed diverges.
- GEOMETRY: 5/5 GREEN. The emergent dodge table (measured with the style
  packages off - they scale reach and the weave and are gated in the smoke)
  matches the consensus rows in all four orientations (boss->player,
  player->boss, both hands);
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
  camera look_at failed) - the sim now keeps bodies apart. A 16,000-frame
  soak on Vane ran a segment KO into the card, the corner (two actions
  taken, three refused, the menu drawn), tactics live and R2 vs Yuri with
  zero errors; `-- demo seg2 boss=0` (the aid makes the scripted fighter
  cast North Star) spawned the T3 afterimage ghost - two casts, two ghosts
  in 3,000 ticks, three runs, zero errors. With the rings live a 16,000-
  frame soak on Vane ran R1 -> R2 -> R3 (JUNE swapped in from the corner)
  with three matchup cards, two ghosts and zero errors.
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

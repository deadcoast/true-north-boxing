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
      CORNER: M = let the next fighter play on their own | Shift+M = the
      rest of the dual | N = hands on again;  `-- auto` = manager mode from
      the bell
META: F1-F4 boss (Vane/Yuri/Moreau/Sam) | F6/F7 prev/next of ALL 24 bosses
      R reload tuning | F5 new dual | F9 cycle the format (mini / sanctioned /
      iron / blind / gauntlet); `-- format=sanctioned` from the command line
DEMO: `godot --path engine/greybox -- demo boss=7` - your card's own profile
      plays the fight (manager mode, PAC-062) while a scripted log works the
      corners: the attract mode, and the presentation soak.
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
  wins; equal points go down the ladder (segment wins, counter hits, the
  Golden DROP - PAC-061). A KO forfeits the loser's remaining time and pays
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
    (locks the rival corner's next phase since PAC-060) are in the data.
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
  enemy coach's corner (NP_10 s9 - delivered in PAC-060 below), the 4
  unnamed launch tactics, staff passives and levels, manager-mode
  delegation.

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

## PAC-060 in the build: THE OTHER MIND (the enemy coach, NP_10 s9)
- Every rival club has a corner, and it is data in `coaches.v1.json` (vault
  copy `data/coaches.v1.json`): an order archetype (NP_10 s2), swap
  aggressiveness, scouting confidence, decoy use (carried, no projection
  screen yet), a tactic library, a Super with its trigger, a priority order
  for its two actions, and ONE tell. Eight corners: the Ascendant B and the
  Academy (Director Vey), the Grain Kings, the Netmen, Montreal Technique,
  True North, the Hollow Circuit, and a journeyman for everyone else. The
  corner is keyed by the club whose fighter opens the dual.
- The enemy seals an order. Four dressed for the mini-dual: R1 is the boss
  you asked for, the rest go by the archetype - STANDARD closes with the
  ace/anchor (Vane, Yuri, Sam; Moreau on the bench), AMBUSH opens the slots
  he controls with the ace (HC-0, Echo, the Cartographer), WALL-FIRST puts
  the anchor-class first (Sam, then Vey). RELAY LADDER reads as STANDARD
  here (bond pairs are not a boss-side concept yet).
- His corner resolves when yours opens, on his scouting, not on your
  choices - so The Reveal names his slot as it stands after his swap. Two
  actions at your prices: the Super once per dual on its trigger (when
  trailing / when leading / corner 1 / after a FLASH DROP conceded / after
  any drop conceded), a swap judged on the rings against the card he thinks
  you send next (first free, then 15 of HIS Tension), a tactic from his
  library at its cost and cooldown. The feed says what he did; the HUD
  shows his corner, his last call, and the crowd lock.
- The tells are real and readable: the Academy counter-picks every time it
  can pay (Cal comes up for Carter against a slugger); True North never
  swaps even with the better card on the bench, and burns Iron Resolve the
  corner after a drop; the Grain Kings burn theirs only after a FLASH DROP;
  Ascendant B spends its first tactic in the corner before R3 like the book
  says; Montreal ices the clock every corner it leads; the Hollow Circuit
  turns the crowd on you from the first corner. Each tell is an event
  (`coach_tell`) the Scout Book can bind.
- HOSTILE CROWD works both ways now: yours locks his next corner (he takes
  nothing); his locks yours - 0 actions, every press refused "locked out by
  the crowd". The lock is spent on the corner it hits.
- His tactics land on his fighter where yours land on yours: Body Doctrine
  doubles HIS body drain on you, Cut the Ring his herding, Ice the Clock
  runs the clock 1/0.8 while HE leads on EP, Iron Resolve holds his fighter
  up at 1 composure for 30s, Perfect Round doubles his bar, Switch-Up gives
  him the triangle's +10% EP. The libraries only carry tactics with a
  boss-side consumer.
- BOTH TEAMS EARN (NP_05 s2): the enemy has a Tension bar on the score bug,
  earned from the same table - counters +3, a read that beats your punch +2,
  the CENTER exchange +2, dropping you +10, the segment win +5, the KO
  trickle - with the feud's x1.25 and his own Perfect Round. His
  desperation pays its tier from his bar and still goes at 0 (an authored
  beat is never blocked). 25 banked sends his next fighter out CHARGED
  (10s, feet +10%) and his relay chain sits on the bug.
- Canon correction on your side of the bar: the greybox had paid 1.5 for
  every clean hit since v5; NP_05 s2 pays nothing for a plain clean hit.
  The table is in `combat_tuning.v1.json` now (`tension`: clean 0, counter
  3, flash 5, perfect block or slip 2, interrupt 5, drop 10, segment win
  5) and the sim reads it for both teams; the segment win and the perfect
  defence pay were missing on your side too and pay now.
- Not in this pass: decoy seals and the projection screen (NP_10 s3), the
  enemy's staff (bosses have no cutman), enemy relay effects beyond the
  CHARGED surge (bosses cast by composure, not by bar), the coach's read of
  YOUR corner (he acts first, on scouting), coach tells as Scout Book pages.

## PAC-061 in the build: THE RULEBOOK'S SHAPES (dual formats, NP_01 s2/s3.3/s6/s8)
- The dual's shape is data in `formats.v1.json` (vault copy
  `data/formats.v1.json`): segments, dressed each side, repeat slots,
  condition carry, sudden death, blind. Five records: the SANCTIONED dual
  (5 segments, 8 dressed - five slots and three reserves - both sides), the
  MINI (3 segments, 4 dressed; the greybox default), the IRON dual (5
  segments from 3 dressed: fighters repeat slots, condition carries - True
  North's format), the BLIND dual (sanctioned, no reveals - the Hollow
  Circuit's), the GAUNTLET (one fighter, five segments, five of theirs).
  F9 cycles them; the roster follows (`LINEUP_MILLBROOK_8` dresses RORY,
  JUNE, PRIYA, MARCUS, SAM with DEX, YURI and MARTA in reserve; the recruits'
  cards are editorial until the content lane speaks).
- Slots are drawn from the cards you dressed: reserves sit out, starters
  fill R1.. in order, a roster shorter than the slots repeats. His side the
  same, ordered by his corner's archetype for any slot count (STANDARD: the
  two highest roles close - hammer at R4, anchor at R5 - the lowest open;
  AMBUSH: the ace opens; WALL-FIRST: anchor-class first).
- The corner's swap rules generalise: three reserves and every not-yet-
  fought slot in a sanctioned dual (first free, then 15); in repeat formats
  anyone dressed can take the slot; the Gauntlet has no one to offer and
  says so.
- CONDITION CARRIES (s6): a fighter who re-enters comes back with the
  stamina, guard and composure he left with - repeat slots and the Golden
  DROP. The corner's restores finally have something to restore: Patch
  Job's +30 composure and Second Wind's +40 stamina land on the carried
  numbers; Loosen Up raises the ceiling and tops up nothing. His fighters
  carry too.
- THE LADDER (s3.3): most DROPS (the score) wins; equal -> segment wins ->
  counter hits across the dual -> the GOLDEN DROP. Segment wins are EP
  majority (s3.2): a segment you took on the exchanges is yours even if
  the drop was his - and pays the +5. The Golden DROP: the card names your
  freshest dressed fighter, the corner lets you send anyone (the pick is
  free), condition carried, no clock, the first DROP ends the dual. His
  corner picks on condition first and the rings second.
- BLIND: The Reveal is refused with its charge kept, the corner shows "?"
  for his slot, the matchup card still names him at the bell.
- Canon corrections in this pass: segment wins had been decided by the
  drops in the segment with EP as the tiebreak (NP_01 s3.2 says EP decide
  them); the dual had broken ties on total EP (the ladder is segment wins,
  then counter hits, then R6). Both fixed; the earlier register row that
  said "EP" for the ladder's second rung was wrong and 010 says so.
- Not in this pass: the Exhibition 2v2 (simultaneous - not a rotation
  format), the R6 pick as a 45s corner with a shot clock of its own (it
  runs through the normal corner), 8-dressed squads with 3 staff as a
  pre-dual screen (the formation screen is NP_10 s2 - not built), story
  injury states (s6), the Blind dual's "no scouting" on his side (he
  still reads his own scouting number).

## PAC-062 in the build: THE FIGHTER WHO PLAYS WITHOUT YOU (manager mode, NP_10 s8)
- `sim/profile.gd` is the card's own fighter: pure, it reads the sim and
  returns the same intent dictionary the pad produces, one per tick, and
  rolls on the sim's RNG - a delegated segment hashes like any other. In
  the corner, M hands the next segment to the fighter (free; not one of the
  two actions), Shift+M the rest of the dual, N takes it back. You keep the
  corners either way (NP_10 s8), and a delegated segment ignores your fight
  keys at the bell. AI segments earn Tension at 85% (`tactics.v1.json`,
  corner.delegated_tension_pct); a held bar is held by the profile too.
- The style archetype sets the range and the mix (NP_06 s1.2): the swarmer
  lives in the phone booth (1.1m) on hooks, uppercuts and body work and
  grabs a wobbled or winded boss; the out-boxer holds jab range (1.9m) on
  straights, feints a quarter of his punches and sprint-steps off a rush;
  the slugger works the mid on power punches and haymakers; the boxer-
  puncher mixes. The card's stats set the rest: RFX how often it reads a
  tell and taps the cue, HRT how surely it rises on the count.
- It reads his tells: once per tell it rolls a read (RFX, louder tells
  easier) and jabs the string, plans a geometric dodge for the string's
  first punch (slip the straight and the overhand, duck or weave the hook,
  lean off the uppercut and the body shot), or braces a perfect block;
  mid-string with no plan it guards. It breaks his casts in the window and
  raises its own wall against them when it carries one. It hits inside its
  counter and flash windows, casts its hissatsu into an open or wobbled boss
  (or off a full bar), backs off and blocks when gassed, changes its rhythm
  when the tracker flags it, angles off the ropes, and cuts angles in the
  band rather than standing still.
- `-- demo` runs it: the attract mode is boxing now, not a random log (the
  log still works the corners). 16,000-frame soaks: Vane went to R3 at 6-7;
  Alfie's R2 was PRIYA out-boxing Carter (35 punches, 7 feints, 6
  sprint-steps, 10 jabs at tells); a sanctioned dual on the profile lost
  JUNE's R2 to Vey 0-8 - the swarmer seed with no guard, as written.
- Not in this pass: Pattern Intel (NP_02 s3 - "your recon makes your AI
  teammates smarter" needs it; the profile reads tells and the tracker
  instead), broadcast camera and seat selection, authored hands-on-only
  segments, mid-segment hand-over (delegation is a corner call, as NP_10
  frames it), and the profile's numbers are first-draft design values.

## Verification (agent-run, headless Godot 4.3, this container)
```
godot --headless --path engine/greybox -- smoke boss=N   # N = 0..23
godot --headless --path engine/greybox -- determinism
godot --headless --path engine/greybox -- geometry
godot --headless --path engine/greybox --quit-after 3600 -- demo
python3 pbn_compiler.py --margins
```
- SMOKE: 197/197 GREEN on every one of the 24 bosses (4,728 assertions).
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
  edits on Yuri, Alfie and Vane against Sam), the PAC-060 gates (24/24
  duals open with a corner record whose library the boss side consumes, R1
  fixed and the three archetypes' sealed orders; the Academy's free
  counter-pick swap + corner-1 Switch-Up and his lie scoring 22; True
  North never swapping with the better card on the bench, its tell, Iron
  Resolve after a drop with the wobble at 1 and no Super without a drop;
  the Grain Kings' Super after a FLASH DROP and not after a plain one;
  Ascendant B's tactic held to the corner before R3 and Body Doctrine
  doubling his body drain at the right price; Montreal's Ice the Clock +
  Switch-Up when leading and the clock at 150 per 120 while he leads;
  Hostile Crowd both ways; The Reveal naming the post-swap slot; his bar
  source by source and yours on the canonical table; the feud both ways,
  his Perfect Round, his CHARGED entrance), the PAC-061 gates (the five
  format records and both sides' rosters/orders for each; the sanctioned
  corner's six swap options, a free reserve swap then a paid slot swap,
  five segments to a verdict; segment wins by EP majority with the +5;
  the ladder's second and third rungs; the Golden DROP from three drawn
  segments both ways - the freshest default, the free pick from anyone
  dressed, condition carried in, no clock, the first DROP ending it, his
  pick by condition; the Iron dual's R4 with RORY carrying 20 / 40 / 30
  and Patch Job / Second Wind / Loosen Up landing on the carried numbers,
  Vane carrying too; the Gauntlet's refused swap and carried stamina into
  R2 and R3; the Blind dual's refused reveal and hidden slot), the PAC-062
  gates (delegation as a free corner call per segment / for the dual /
  hands on, the fight keys ignored and the corner keys kept; the 85% rate
  and the held bar; each archetype's band and mix over 30s against a
  frozen boss - the swarmer at 1.12m on 66% hooks and uppercuts, the
  out-boxer at 1.91m on 74% straights with 10 feints, the slugger's 32%
  power and 36% haymakers, the boxer-puncher with no family over 36%, each
  landing; every archetype against a live Yuri reading 15+ tells, breaking
  a string, landing 11+, in the swarmer < slugger < out-boxer spacing
  order; the count risen on every beat at HRT 99; all four cues tapped at
  RFX 99), and static coverage: 39/39
  action verbs, 53/53 punish responses, 13/13 phase-trigger forms, 7/7
  effect types, 36/36 states, 14/14 buffs. Every entry in tactics.v1.json
  (8 specials, 4 supers, 5 staff actives) has a gate above; every key in
  affinity.v1.json has one.
- DETERMINISM: 16/16 GREEN. One 24,000-tick scripted input log run three
  times (twice tick-by-tick, once through the jittered 7-40ms frame loop
  the game uses): all 400 state hashes identical, every hash bit-exact
  over positions, pools, timers, queues, flags, the corner's state and the
  RNG state. The log provably exercises hits both ways, counters, flash
  windows, interrupts, drops, eight-counts, segment ends, evasions, blocks,
  clinch scrambles, sprint-steps, sensors, the referee, the survival grab,
  hissatsu casts from the library (player and boss), feints with some
  drawing his read, two segment cards with corner actions taken, matchup
  cards with a ring live, and the rival corner resolving at both corners
  with an action taken and his bar earning. A different seed diverges. A
  second, 66,000-tick log runs the SANCTIONED format (8 dressed a side)
  through five segments to a verdict and hashes identically twice. The
  mini log stripped of every fight key runs a fully delegated dual - the
  profile lands 64 and the corners still turn - and hashes identically
  twice.
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
  with three matchup cards, two ghosts and zero errors. With the rival
  corner live, 16,000-frame soaks on Vane and on Yuri ran KO -> card ->
  both corners (his tactic landing on his fighter) -> R2 with zero errors.
  16,000-frame soaks of the sanctioned, iron, gauntlet and blind formats
  all ran into their second or third segment (the Iron dual with two
  corners, the Gauntlet with RORY carried into R2) with zero errors.
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

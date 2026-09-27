# TNB GREYBOX v6 - the engine foundation (NP_14)
Run (no editor): `godot --path .\engine\greybox`

The normal launch waits at **Before the bell**. Choose Fight, stationary Practice,
or Controls; the clock does not run while reading or remapping. The fight HUD puts
resources at the edges. **Ctrl+F1 / Details** opens the complete scrollable diagnostic
and progression display; it opens automatically at a corner or bout result.
Explicit command-line demos, saved fights and test drivers retain their direct entry.

PAC-005 combat input (NP-03 §§2.1–2.5; NP-13 P1/R-01): press **Escape** to
pause, choose the input preset, remap combat bindings, or enable the stationary
practice dummy. Controls save automatically in `user://controls.cfg`; Restore
defaults resets bindings. Escape cancels a pending binding before closing the menu.
Keyboard focus and scrolling work with Tab, arrows, and Enter. The menu uses the
existing Godot controls, with an opaque panel so fight telemetry remains readable
only after resuming; NP-03 remains the interaction authority.

All ten punches work with keyboard keys below or by holding the left mouse button
and flicking in the same directions as the right stick. In **button chords**, A/B/X/Y/
D-pad Up select straight/flared/hook/hookercut/uppercut; hold Back for the left hand.
Hold Alt or D-pad Down for at least 150 ms before punching for a haymaker; the stick
preset also supports pulling back for 150 ms then flicking forward. A short downward
flick remains an uppercut. Releasing a punch within the authored 80 ms cancels into
a feint. Inputs retain press-time modifiers when pressed and released in one frame.

Body, power, haymaker, stepping, and block-punch modifiers compose using the tuning
JSON. Step toward an opponent outside normal reach to gain the authored extra reach;
a stationary out-of-range punch does not gain the stepping modifier. Block-punch drops guard; power whiffs
and blocked power strikes leave the authored 300 ms opening. Unaffordable power or
Hissatsu activation preserves the ordinary punch. Haymaker impact uses heavy hitstop
and the stagger event; it respects the existing authored interrupt rules.

Launch directly into practice: `godot --path engine/greybox -- dummy` (add
`controls=chords` for the accessible preset). The dummy holds position, replenishes
composure, and suspends opponent decisions and the round clock. Turning practice
off restores normal decisions. R reloads tuning. The geometric boxer rigs remain
prototype art. Input regressions:
`godot --headless --path engine/greybox -s tools/drive_input.gd -- dummy`.


Blue silhouette = you; red fighter = the boss, driven by the compiled PBN.
Heads follow the simulation's dodge offsets; gloves coil during wind-up and extend
on contact. Only tagged strings can be interrupted by a clean jab-class hit.
The player uses 40% alpha with an additional soft visibility window over the opponent.
Active hands stay opaque. PI 2 still emphasizes the wind-up.
The camera preserves 1.8m chase, head+0.6m height and 55-degree FOV. It aims at the
opponent's center as distance changes: a literal fixed 12-degree pitch cannot also
keep that target centered. The provisional 70-degree/s orbit cap is not PAC-003's
completed salience metric. Authored character animation/audio, the full art bible,
human squint testing and new-player time-to-first-DROP acceptance remain open.
Presentation regression and GPU captures:
`godot --headless --path engine/greybox -s tools/drive_readability.gd -- welcome`;
omit `--headless` and add `capture` for PNGs under the Godot user-data directory.
All numbers load from `combat_tuning.v1.json` - edit it, press R, feel it.

PAD: LS move | RS flick = punch by angle | RT block (150ms perfect window)
     LT+LS lateral = slip, LT+LS fwd = weave, LT+LS back = lean | LT+punch = body
     RB = power | LB+haymaker flick @100 = ABB | A = rise beat / skip card / SEND
     CORNER: X swap | Y super | B save the bar | D-left/right tactic 1-2 | D-down staff 1
KEYS: WASD | J/K straights, F/L flared, U/I hooks, N/; hookercuts, Y/O uppercuts
      Escape controls/remap/practice | Space block | Q/E slip L/R
      V weave | B lean | T taunt | Shift power | C body | H hissatsu-arm
      ENTER = rise beats when dropped | 1 = skip the card / SEND from the corner
      CORNER: 2/3/4 tactics | 5 super | 6/7/8 staff | 9 save the bar | 0 swap
      CORNER: Z / X / C = The Talk with the next fighter - the plan / the
      fire / the arm around the shoulder (pad LB / RB / Back); the menu shows
      the three lines and what a teammate's bond reveals
      CORNER: M = let the next fighter play on their own | Shift+M = the
      rest of the dual | N = hands on again;  `-- auto` = manager mode from
      the bell
META: F1-F4 boss (Vane/Yuri/Moreau/Sam) | F6/F7 prev/next of ALL 24 bosses
      R reload tuning | F5 new dual | F9 cycle the format (mini / sanctioned /
      iron / blind / gauntlet); `-- format=sanctioned` from the command line
      F10 = Ep1's bouts by name (SCRAP 1, 2, 3, the PRIYA TRIAL, then the
      dual again) | F11 = the next scrap objective on this boss | F5 = again
      `-- scrap=SCR-06 boss=1` | `-- spar flags=tell_highlight,infinite_stamina facility=ring:1`
      (the lab flags are The Ring's T1 since PAC-089)
      `-- ep1=scrap_2`  (each also works with `demo`: the profile plays it)
      F12 = the Scout Book: his page at PI 3, else where the recon ledger
      stands vs his dialect | `-- pi=kowalchuk:2,yuri_kowalchuk:3` seeds the
      ledger (a dialect at a level, a boss beaten for 3)
      Shift+F7 = cycle this boss's rematch remixes (original -> each authored
      remix -> original) | `-- remix=yuri_kowalchuk.rematch` or `-- remix=all`
      `-- kizuna=RORY+PRIYA:50` seeds a bond (the reward ledger); every bout
      and dual ends with its REWARD toast on the HUD
      Shift+F5 = save (`user://tnb_save.json`: the SaveGame from the ledgers,
      the DualState of a fight in flight beneath it) | Shift+F6 = load it (a
      fight in flight resumes on the same hash) | `-- load=<path>` at the bell
      `-- demo saveload` saves at tick 3,000 and loads it back at 3,600
      `-- generic=SLUGGER:kowalchuk:2` = an assembled filler fights R1 (NP_04
      s9: Style:dialect:tier[:seed]); with `scrap=` / `spar` it is the card
      fought; the feed names the pieces at the bell
      the HUD's HIS NEUTRAL line names the boss's IDLE game live (his move
      verb, his guard, his taunt clock and count, Tam's tempo, silent feet)
      `-- demo talk` has the log's corners talk to the next fighter as well
      FORMATION (NP_10 s2): `-- order=AMBUSH` (STANDARD / AMBUSH /
      WALL_FIRST / RELAY_LADDER), `-- board=ep1` or `-- board=MARCUS,PRIYA,
      RORY` seal your board at setup; `-- staff=the_reveal:3,patch_job,
      raise_the_roof` dresses its 3 staff (a level after the colon);
      `-- formation` opens the whiteboard before the bell - 1-4 seal the
      named orders, 5 the card order, 6 the Gym Wall's suggestion, ENTER
      rings the bell; TAB shows the
      board, their projection and the rings during the dual; `-- demo
      formation` runs the five picks, seals the board asked for, prints
      the whiteboard at the bell and checks the projection at the end;
      `-s tools/drive_formation.gd -- formation` presses the keys headless
      STAFF (NP_10 s6): `-- staff=janitor:3,professor,the_reveal` dresses
      three of the corps of ten (a staffer, or the active he carries); a
      level after the colon seeds his uses on the ledger; the corner lists
      each active with who carries it and his level, Raise the Roof with
      the crowd's heat; the score bug shows CROWD while the building is warm
      RECRUITS (NP_08 s2): a dual won flags the recruitables of the squad
      you beat; at DUAL OVER [L] approaches them (each condition surfaces,
      clause by clause, what you have and what it needs) and [P] recruits
      the ready into the stable; `-- flag=quest:cold_storage,rep:rink_district:3`
      seeds the overworld's story flags; `-- demo recruit` approaches and
      recruits between duals; `-s tools/drive_recruit.gd -- boss=1`
      presses the keys headless
      STRING WALL (NP_08 s2.3): a recruit's strings go up at DUAL OVER - his
      family, his students, his house - and the HUD lists every map with a
      card face up; `-- flag=blessing:moreau` opens a house (its members and
      the houses bound to it on the feud graph)
      HOUSES (NP_08 s3): at DUAL OVER every house met, its blessing line
      clause by clause and its members NATIVE or UNSANCTIONED, then the feud
      graph's flips; a line met blesses the house on the spot (toast), and
      `-- flag=feud_resolved:moreau+tremblay` flips E05 before the bell
      TRAITS (NP_07 s3): the matchup card names the house trait each corner
      carries this segment (Yuri's Load-Bearing, Sam's Never Twice, SAM's...)
      GYM WALL (NP_08 s7): at DUAL OVER the wall's rows of cards, the Kizuna
      lines between them and what hangs there (ON THE WALL toasts as it
      unlocks); `-- wall=MARCUS:1:1,PRIYA:1:2` pins cards by hand before the
      bell (column:row), and the whiteboard shows THE GYM WALL SUGGESTS (6);
      with `-- order=GYM_WALL` the board seals the wall's suggestion
      DUO (NP_08 s5.2 Lv4): a Duo pair (Kizuna 90+) relays a named T3 - the
      second of the pair out, the first having fought the segment before,
      carries it (RORY -> PRIYA: Whiteout); the matchup card names it, LB +
      its family casts it and the partner's afterimage joins, gilded;
      `-- kizuna=RORY+PRIYA:90` seeds a Duo; the whiteboard lists the DUO
      RELAYS an order holds; `-- demo duo kizuna=RORY+PRIYA:90` jumps to R2
      with a full bar (the profile casts it); `-s tools/drive_duo.gd --
      kizuna=RORY+PRIYA:90` drives it on the real scene
      RELAY (NP_05 s6): whoever enters CHARGED has the relay's T3s opened -
      Coast to Coast (LB + HAYMAKER), Aurora Chain (LB + ARC), North Star
      (LB + RISE) on a FULL RELAY only; the matchup card's RELAY line and the
      whiteboard's RELAY OPENS name them, priced
      ZONE (NP_09 s3): H + Y (pad: LB + both sticks) SURGEs into In the Zone
      - the whole bar (100, 75 on a FULL RELAY), once per fighter per dual,
      unlocked at level 20 with the Provincials' flag: `-- level=RORY:20
      flag=story:provincials_semifinal`; the HUD's IN THE ZONE / COMEDOWN
      line; `-- demo zone` surges whoever can (the soak's aid); `-s
      tools/drive_zone.gd -- level=RORY:20 flag=story:provincials_semifinal`
      presses the keys headless
      THE ENEMY'S TRANSFORMATION (NP_09 s1/s4/s7): a boss with an authored
      TRANSFORM line (Ioan Vasile, `-- boss=16`: the Zone under 50 %
      composure) gathers behind the guard with the line, then ENEMY ZONE /
      ENEMY MANIFEST; a perfect block or slip weathers it; both manifested,
      the MANIFEST CLASH (SPACE / Q / E on the enemy's exchange, a punch on
      yours); `-- btransform=manifest@composure<80` authors one on every
      boss without one (the aid), `-- demo clash` holds the aid's SURGE for
      the enemy's manifest; `-s tools/drive_bzone.gd -- boss=16` and `-s
      tools/drive_clash.gd` press the keys headless
      HYBRIDS (NP_08 s6): a Sworn pair of two houses, each with a native
      learned, forges its T3 between duals - F on the DUAL OVER screen
      (the FORGE lines: each pair's hybrid and price, or what it waits on);
      the hybrid is live for either of the pair relayed from the other
      (x1.25, the partner's afterimage), CHARGED, or in an Awakening's slot
      - the matchup card's HYBRID line, LB + its family (`;` is the
      keyboard's hookercut); `-- purse=spirits:40,beans:30`,
      `-- forge=YURI+MARTA`, `-- demo hybrid` (the Forge hosted at The Wall's
      T3 since PAC-089: `-- facility=wall:3`); `-s tools/drive_forge.gd`
      presses the keys headless
      EXHIBITION 2v2 (NP_01 s8, NP_05 s7): `-- format=exhibition_2v2`
      [`pair=RORY,PRIYA`] - two a side in the ring at once, one segment,
      one bell, one bar; each pair drawn in its own half. You play the
      first card, the partner plays on his profile; `\` passes the pad (a
      pair KO'd hands it to the other). At Kizuna Lv4 (`-- kizuna=
      RORY+PRIYA:90`) the DUO SYNC: H + O (LB + uppercut) calls Double
      Overtime, H + SPACE held Two-Hand Winter (one gauge for both); the
      partner answers inside 500 ms (his profile at 250 ms) and both halves
      cast it, the bar paying once. `-- auto` / `-- demo`: both on their
      profiles, who call it at 90. F5 again, F9 back to the rotation
      formats; `-s tools/drive_exhibition.gd` presses the keys headless
      THE OLD GYM (NP_10 s7): five facilities from T0 as found to T3, each
      tier renovated between duals for HBP and Spirits behind its story gate
      (`-- purse=hbp:3000,spirits:150 flag=story:charter_saved,
      quest:gym_funding,story:nationals`). DUAL OVER: [1]-[5] renovate
      Bags & Mitts, The Ring, the Film Room, The Wall and Front of House;
      [T] a training slot (the best game open, 3 a day: the Forge's Beans).
      `-- facility=bags:1,ring:2,film:3,wall:3,foh:3` seeds the tiers,
      `-- host=home` hosts the dual (or the exhibition), `-- train=` and
      `-- renovate=` act before the bell, `-- demo facilities` renovates and
      trains before the bell and between duals; `-s tools/drive_facilities.gd`
      presses the keys headless
      GROWTH (NP_11 s3, s4, s6): DUAL OVER lists each dressed card's growth -
      level, rarity and cap, the board's points, his passives, the node the
      aid would take, his raises, the next tier's price and trial - under
      the jar by type. [N] takes that node (Board Points, 2 a level:
      `-- level=RORY:10`), Shift+N respecs (the Film Room's T2), [Z] raises
      the stat the jar pays best, [X] ascends, [M] the mirror spar, [.] the
      next card. `-- nodes=RORY:c1+c3` (or `RORY:*`) takes nodes before the
      bell; `-- growth=RORY:rarity:2,RORY:trial:storm,PRIYA:raise:RFX:3` and
      `-- beans=PWR:10` seed the ledger; `-- demo growth` grows every dressed
      card between duals; `-s tools/drive_growth.gd` presses the keys headless
      TECHNIQUES (NP_11 s2, s8): DUAL OVER lists the focused card's own move,
      his T0 slot (level 5 - a T0 is castable from there), his technique
      slots (5/15/25/35/45) and kit, the shop's next buy, the lessons open,
      the tapes and the re-teach. [ buys it (HBP; `-- flag=story:regionals`
      opens the second shelf, `story:provincials_semifinal` the third), ]
      takes the lesson, ' spends a tape, / re-teaches in a training slot,
      = carries the next learned, - puts the last down. LB + a motion casts
      his own move on its family, else the kit's; the matchup card's KIT
      line names it. `-- learn=RORY:Snowblind+Root Bind`, `-- tapes=Black
      Ice:1`, `-- demo techniques`; `-s tools/drive_techniques.gd` presses
      the keys headless
      THE ACADEMY (NP_07 s10): `-- academy` fields the Toronto academy's
      prodigies in every enemy segment, Director Vey's corner. Each carries
      three syntheses (the Forge's composer on two houses' natives, x0.85,
      no bond, no afterimage) cast from his bar when it pays, at his
      decision point, within reach; a jab in the windup breaks one. The
      matchup card's ACADEMY line lists them and its THESIS line sets the
      club's forged hybrid against his best, in the numbers (`-- forge=`
      forges the answer before the bell); `-- demo academy`;
      `-s tools/drive_academy.gd` presses the keys headless
      THE MIRROR (NP_02 s2.2): the tracker keeps each fighter's record
      across every bout; DUAL OVER's HABITS line shows the focused card's
      and the copy it makes. [M] (or `-- spar flags=mirror`, the lab's flag
      at The Ring's T1) sends him out against it: his most-thrown
      sequences as its strings, his most-read ones read from the bell, his
      counter punch at his rate (the matchup card's MIRROR line, the YOUR
      COUNTER toast); [M] after it goes back to the dual.
      `-- habits=RORY:L_STRAIGHT+L_STRAIGHT+R_STRAIGHT*8,RORY:counter=R_HOOK*4/6`
      seeds the record; `-- demo mirror`; `-s tools/drive_mirror.gd`
      presses the keys headless
      GEAR (NP_11 s5): DUAL OVER's GEAR lines show what the focused card
      wears in the slots his rarity opens (1 / 2 / 3 / 3), the locker and
      the shop's next. \ buys the shop's pick (HBP; `-- flag=story:regionals`
      opens the t2 shelf, `story:provincials_semifinal` the t3), , wears the
      best free piece (his own signature first), Shift+, takes the last
      off. A piece's small passive is its kind's (gloves the jab, wraps the
      guard held, a mouthguard the wobble, a robe the walk-out's Tension,
      3% at most); the matchup card's GEAR line names it and the figure
      wears it in its colour. `-- gear=tape_wraps,RORY:gym_robe` seeds the
      locker; `-- demo gear`; `-s tools/drive_gear.gd` presses the keys
      headless
DEMO: `godot --path engine/greybox -- demo boss=7` - your card's own profile
      plays the fight (manager mode, PAC-062) while a scripted log works the
      corners: the attract mode, and the presentation soak.
      `-- demo seg2 boss=7` starts at a CHARGED R2 with a full bar - the
      chain seeded to a FULL RELAY, so the relay opens North Star - and has
      the scripted fighter cast it, so the T3 afterimage shows inside the
      first half minute.

## What changed in v6: the sim is a thing of its own
`sim/core.gd` (TNBSim) is the whole fight: pure, no Nodes, no wall clock,
seeded RNG, fixed 120Hz ticks driven by one intent dictionary per tick.
`main.gd` only draws it, samples the pad, and plays FX off the sim's event
list. `sim/clock.gd` is the one place render time meets sim time (fixed-step
accumulator + interpolation alpha). `sim/tests.gd` drives the sim directly.
`sim/save.gd` writes the sim's ledgers as the save and reads them back (a
fight in flight rides beneath it as a snapshot of every state variable).
`sim/assembler.gd` builds a non-named opponent's pattern from the piece
library in the same shape the 24 compiled patterns have.
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

## PAC-063 in the build: THE SNACK AND THE MEAL (scraps and spars, NP_02 s2)
- The two smaller sizes run on the same sim, as data in `bouts.v1.json`
  (vault copy `data/bouts.v1.json`) with the 24 objectives from
  `data/scrap_objectives.v1.json`. A SCRAP is one micro-objective over a
  hard 30s cap with no Tension meter and no corner: the objective met ends
  it WON, a constraint broken ends it LOST, the cap is judged on EP, a
  count-out or three knockdowns ends it either way. A SPAR is one 90s
  segment with full EP and drops, the personal meter capped at 50,
  transforms locked, no corner, and lab flags: tell-highlight (every tell
  outlined - Priya's binders as UI) and infinite stamina (the combo lab).
- Every objective is judged from the sim's own events by `sim/objectives.gd`:
  counts (body shots, misses drawn by a dodge, the CENTER exchange, counters,
  a guard break, two perfect blocks in a row, the scramble won, a stepping
  punch - one only the lunge makes reach, an interrupt of a Loud tell, a
  House native's wind-up broken, his coach's shout), the ladder (a Loud
  tell then a Standard one), the streak (five hits with no tracker flag
  between), survive 20s, corner him 3s (his CORNER TRAP), first blood both
  ways, the finishers (the dropping punch must be an uppercut / a body
  shot), the corner left without a block, and the constraints that fail on
  the spot (the same punch twice, a block press, a right hand, a step back)
  and win at the cap on EP. SCR-24 needs a coached NPC: offered against Yuri
  (his corner shouts FREIGHT), refused against a corner that does not.
- Ep1 by name (NP_12A): SCRAP 1 at the bike racks (land 3 body shots vs a
  CHALLENGER), SCRAP 2 vs MARCUS HALLORAN (survive 20s - his card on a
  Slugger's strings, Loud tells and all), SCRAP 3 vs JUNE PARK (win one
  exchange in center ring - a Swarmer seed with no guard), and the PRIYA
  TRIAL (a tell-highlight spar vs her out-boxer card; the objective is to
  go the distance). Until PAC-070 an NPC card rode a stand-in pattern's
  strings by style; since it, a card marked `generic` fights on strings
  assembled for it (below). F10 cycles them and returns to the dual.
- `-- demo` with any of these plays it on the profile (PAC-062): the
  attract mode can run a scrap.
- Not in this pass: rewards (XP, Prestige, PI ticks, Spirits, bonds) - the
  bout ends with its verdict and an event, the economy is NP_02 s4's; the
  mirror spar (the boss agent runs patterns, not profiles - since PAC-093
  the tracker's record is that pattern); assembler
  fillers; the "exchange win" as last-clean-hit-before-disengage (the
  CENTER exchange is the sim's existing rule); the 2s camera-swing budget.

## PAC-064 in the build: THE RECON LEDGER (Pattern Intel, NP_02 s3)
- Pattern Intel is a ledger the sim carries (`pattern_intel.v1.json`, vault
  copy `data/pattern_intel.v1.json`): PI 0-3 per House dialect and per named
  boss. The dialect of an opponent is his House (the ring key from the
  pattern META), his own id when he has none (Vane, Alfie, the Hollow
  Circuit), or the dialect a bout card names (Ep1's CHALLENGER: "school").
  The ledger is handed in at setup, rides across bouts, duals and F9
  rebuilds, and is in the state hash.
- Earned exactly as NP_02 s3's table reads - each source has its own rungs:
  3 scraps won vs the dialect or 1 spar fought to its end -> PI 1; 6 scraps,
  3 spars or 1 dual segment fought -> PI 2; a named boss beaten once (a dual
  segment won against him, on EP or by his KO) -> PI 3 for him. The
  effective level against an opponent is the higher of his dialect's track
  and his own. A scrap lost pays nothing; a spar counted out still counts
  (the lab is the lesson).
- Effects: PI 1 the colour commentator calls the dialect's habit before the
  segment (an authored line per dialect, else his most-weighted tell's
  motif); PI 2 his tell event carries the emphasized cue (the greybox draws
  it brighter and bigger) and the interrupt window - the tell itself - is 10%
  longer against that dialect and no other; PI 3 his Scout Book page (tells,
  strings, phase notes, hooks, the desperation, his corner's tell) as data,
  F12 reads it. PI never widens a read: the slip / duck / perfect-block /
  flash windows are untouched at PI 3, and PI 3 is no wider than PI 2.
- The profile reads PI (PAC-062's open line): its tell-read roll rises by
  the data's bonus against a dialect it knows - "your recon makes your AI
  teammates smarter" is one added term, and the gate measures it.
- Not in this pass: the scout questline route to PI 3, the Film Room's
  grind-rate bonus and the tactician's richer pages (NP_10 s7), decoy
  seals; the Scout Book as a menu (the page is an event and a query); the
  rest of the reward economy (XP / Prestige / Spirits / bonds).

## PAC-065 in the build: THE OPPONENT'S MIND GAMES (NP_04 s4, s6)
- The INTERRUPT block is honoured (NP_04 s4). Every pattern authors which
  strings break (`interrupt: [{strings, response}]`); a string the block does
  not tag takes the hit and keeps coming - no stagger, no flash window, no
  +5 - and an ARMORED string never breaks ("you dodge this, you don't stop
  it"). Only a jab-class hit breaks a string (a hook in the tell lands and
  does not), as it already did for a cast. The block's response executes:
  `stagger(700|800)` sets the stagger; Ada's `desync(3s)` is her reward
  state - she stalls the whole 3s and her next tell is +100ms wider; her
  phase-2 line `desync 3s->2s` shortens it. Across the 24: 34 strings hold
  (8 ARMORED), Yuri breaks on Freight alone, the Cartographer on all five.
  The HUD says which ("JAB HIM NOW" / "THIS ONE DOESN'T BREAK: MOVE").
- Phase directives execute where the vocabulary is the remix's: `speed xN`
  (his recoveries), `tighten(Sx, Nms)`, `tighten_all_tells / tells -Nms`,
  `S1,S2 tell -Nms`, `add Sx`, `retire Sx`, `w(Sx)+=N / =N`, `all_damage /
  strength / all_body_damage +Npct`, `movement +Npct`, `desync Xs->Ys` - 21
  of the 47 authored lines; the other 26 (kit_swap, metronome, dialect_swap,
  splices, dialogue, tempos, the per-string growths) are carried and named
  by `directive_coverage()`. A tell is never set under its class floor
  (400 / 700 / 1000).
- The rematch remix (NP_04 s6) is a data layer (`remixes.v1.json`, vault
  copy `data/remixes.v1.json`) applied over a copy of the original at load;
  the original in `patterns` is never touched. Operators: `feint(Sx)` (the
  tell plays, then he HITCHES `ms` before the shot, or the hands are another
  string's - `pct` of the time, always once burned), `tighten`, `reweight`,
  `newstring`, `phase_shift`, `burn(Sx, after)` (NP_04 s4: after N
  interrupts of Sx in the segment he only feints it), `phase_directives`,
  `directive`. Five records follow the roster's remix plans: Yuri (Freight
  feints, Coupling 450, burns after 3), Moira (the haul releases into a
  hook), Carter (S2 420 + a new string), Moreau (phase 2 earlier + a new
  string), Tam (S1 stays in phase 2). A remix beaten earns its own Scout
  Book page with the tactician's notes on what changed; the original keeps
  its own.
- The profile with his page (PI 3) never jabs a tell the block does not
  tag; below that it wastes jabs on them like a player without the page.
- "His special" (SCR-09, SCR-17's Loud rung) is his hissatsu cast broken in
  its window or a Loud string tagged INTERRUPT (only Baro's S3 among the
  24); both objectives are offered only against an opponent who has one.
- The determinism coverage log moved from seed 777 to 778: under the block
  the old log stopped dropping anyone.
- Not in this pass: the 26 carried directive lines (each a boss's own
  mechanic); authored rematch content beyond one record per operator (the
  two new strings are placeholders); the feint variant on a forced (bait /
  punish) string; Yuri's `+ tension_bonus` is the standard +5.

## PAC-066 in the build: THE PHASE SCRIPTS, ALL OF THEM (NP_04 s7, NP_04A/B)
- Every authored phase-directive line executes - 47 of 47 - through the
  one executor, each as the boss's own mechanic. The META carries the
  values the lines move from (`_declare_bases()`): Ada attacks on a fixed
  800ms metronome (no roll between strings) that her phase 2 tightens to
  650; Chiamaka's two beats alternate 600 / 900, then 550 / 850; Echo's
  machine splice leaves him OPEN 500ms after every 2nd string, every 3rd
  in phase 2. Vey's kits turn live at 70% and 40% - the phase's string set
  (P1 retired, P2 / P3 live with the SELECT block's `phase==N:` weights),
  the rings re-dressed with his condition kept as a fraction, a second
  matchup card; Vasile's kits turn by the clock at 30s and 60s with a
  700ms neutral seam (both fighters reset to 1.8m, he idles the seam) and
  his finale under 10% locks to F1 / F2 with no element (Kannagi's
  lesson). The Cartographer speaks an erased house per phase (the string
  pair swaps, the dialect key turns). Vane's corner calls hide a tier
  (-150ms, floored); Cal's tells louden a tier, he answers Whitlock
  (a dialogue event), and in phase 3 his SELECT drifts +25 toward the
  string you have read most. Alfie stops flirting at two warnings (every
  foul pulled). Carter's S2 gains its second body hook, Deshawn's Pileup
  its fifth hit; Osei's Shell holds 4s in phase 2, Marta's Mirror 3.5s and
  cools 6s after a use (off the SELECT while it cools); Remy's shame
  dialogue opens; Sora's `no_changes_by_design` executes and changes
  nothing; Tam's `true_pattern_only` ends the borrowed clothes; Baro's
  corrections come twice as often (punish cooldown halved).
- The SELECT block's `phase==N:` / `phase>=N:` lines execute when the
  phase arrives and `punish_only: w(S3)=0` at load (Ada's SwarmProtocol
  never comes on her own); `reweight_coverage()` names the 6 SELECT lines
  still carried (after_hit_taken, target_zone, segment_clock, clock,
  player_passive). A named phase ("finale") fires once - it used to fire
  every tick its trigger held.
- Not in this pass: the carried SELECT lines and the META keys the sim
  does not read yet (Alfie's +75% herding, Vey's PI transfer, the
  Cartographer's PI override, Deshawn's no idle weight, Osei's secret at
  70% with the stumble, Baro's Graduacion gate, Vasile's corner intel,
  Cal's corner assist, Reyes' target split, Remy's fingerprint); the tier
  step (150ms) is a design value.

## PAC-067 in the build: THE PATTERN, ALL OF IT
- The last authored data the sim carried without executing now executes.
  The SELECT block's six remaining lines: Yuri leans on Freight after a
  hit taken (+20 for 6s, a transient that refreshes); Moira's Gaff and
  Alfie's Sunday Best are for a player on the ropes (the `zone==ROPES` tag
  gates them, the `target_zone==ROPES` line pays them +25 there); Carter's
  speed x1.12 under 30s left, Sam's x1.1 past the minute (`_bspeed()`
  multiplies the phase speed by the clock lines); Marta's Frost Line +30
  once you refuse to lead for 8s.
- The META keys with a mechanic behind them: Alfie's `herding_bonus` walks
  you back +75% of his step; Vey's `pi_transfer` 0.5 - the real house his
  kit copies (the roster boss with the kit's style and element: Tremblay /
  Okafor / Kowalchuk) lends its PI at half (the tell x1.05, the read bonus
  halved, the cue and commentary on) while his own Petrov PI applies in
  full; Remy's `extraction_fingerprint` half-transfers Moreau PI; the
  Cartographer's `pi_override` strips PI (a PI 3 ledger reads 0) and his
  Scout Book page stays half-blank on purpose (phases and hooks, no tells,
  no string names); Deshawn's `no_idle_weight` is a 150ms recover with no
  roll; Osei's `secret_power` fires Deep Roots at 70% and she stumbles on
  the exit - OPEN 500ms; Baro's `graduacion_requires` holds his
  desperation until Examen has landed clean; Vasile's `corner_intel` has
  Vey in your corner call each clock kit 2s early ("Standard's turning
  granite - NOW", a `corner_call` event); Cal's `corner_assist` has
  Whitlock name every string on its tell (`assist` on the tell event, in
  place of the Scout Book); Reyes' `target_split` sends her head verbs to
  the body 80% of the time. Vey's phase-1 kit (NP_04A s8: Out-Boxer,
  Frost) was missing from his PBN META (BOXERPUNCHER / varies): the PBN
  gained `kit=outboxer_frost`, recompiled, and the sim dresses him in it
  at the bell.
- `pattern_coverage()` reports the 24 patterns' data in full: every META
  key executed or presentational (arc, authored_loss, blind_dual,
  unsanctioned, control_group, remix, commentary_mute_on_hit - the last is
  the library move's), every SELECT line, every directive, every tag; only
  the IDLE lines are carried, named (the boss's neutral-game flavour; the
  sim's own approach and range-keeping stand in).
- Not in this pass: the IDLE lines; a Scout Book confidence stamp
  (Tam's lesson); the corner assist and corner intel as player-corner
  data (NP_10) rather than the boss's META; the numbers (150ms, 500ms,
  +75%, 0.5) as tuning.

## PAC-068 in the build: THE BOUT THAT PAYS (the reward economy)
- The sim pays and never spends. A reward ledger rides beside the PI
  ledger (`economy.v1.json`, vault copy `data/economy.v1.json`): XP per
  fighter, Spirits, Prestige, HBP, Kizuna per pair, the toasts - paid on the
  sim's own end paths and hashed. XP is continuous (NP_11 s6): the fight's
  events earn it (a clean hit 1, a counter 2, a flash 3, a DROP 10) and the
  segment's end credits it with +25 for a segment won; a dual pays each
  fighter 100 at the close (40 lost), the bench 50% of the dual's XP, 8
  Spirits (5 fought) and 50 HBP for the win; a scrap pays an XP trickle
  (15 won, 5 lost) and Prestige +1-3 by the objective's tier (tier 1 = +2:
  NP_12A's "+2 Prestige"); a spar pays full XP (40, +20 won), Spirits (3, 5
  won) and 10 HBP for a win; the tell-highlight lab pays half; houseless
  fighters +10% (NP_07 s5). Levels follow NP_11 s2's quadratic-gentle
  curve (48 L^2: level 50 at 120k), a `level_up` event on the crossing.
- Kizuna (NP_08 s5): sparring a stablemate card (`stablemate: true` - the
  Priya trial's card in `bouts.v1.json` is one) pays
  +3 a time to the +15/day soft cap (`new_day()` resets it), adjacent
  rotation slots pay +5 (+8 for the win) and bypass the cap, ALLIED houses
  x1.25; levels at 10 / 25 / 50 / 90 / 150 (Gymmates, Corner Voices,
  Adjacent Trust, Duo, Sworn) as events; the effects in the fight: Corner
  Voices - a Lv2 partner dressed puts the fighter at +2% stats; Adjacent
  Trust - a Lv3 partner in the next slot puts him at +5% and his relay
  CHARGES at 20 instead of 25.
- The toast (NP_02 s6, NP_12A): one `reward_toast` event per bout or
  dual with what it paid, the PI tick named when a rung rose ("SCRAP: 17
  XP, +2 Prestige, PI tick vs Kowalchuk"); the HUD shows it.
- Not in this pass: the sinks (shops, scouting pulls, stat raises,
  training, ascension) - the overworld's; Beans; the Kizuna sources the
  sim never sees (overworld squads, shared training, bond scenes); Duo
  and Sworn effects (the duo T3 and the inheritance transform); the
  training-partner 65%; the amounts as tuning.

## PAC-069 in the build: THE SAVE (NP_11 s9)
- `sim/save.gd` (TNBSave) writes a SaveGame from the sim's own ledgers and
  nothing else: the stable's cards as dressed with level / xp / bonds (the
  reward ledger), the currencies (Spirits, Prestige, HBP; Beans 0), the
  Scout Book (`pi_map` = the PI ledger, `pages` = the pages earned), the
  rematch remixes set, the ledger's day (`new_day()` counts it), the format
  and the boss; the overworld's fields (story_flags, staff, string_wall,
  gym_wall, house_codex, hybrid_registry) are carried under the schema's
  names and written by nobody yet. A load builds a new sim from it: the
  ledgers and the remixes from the bell (`setup` takes the remix ledger),
  the stable's cards dressed, the format and the boss the save names. The
  text is JSON with sorted keys; a save read and built writes back
  byte-equal, and every count crosses JSON as a float and comes back the
  int it was.
- A fight in flight rides beneath it as a DualState (`snapshot()` /
  `restore()` in core.gd): NP_11 s9's fields readable (segment, clock,
  score, tension, relay, lineups sealed / revealed, the corner budget,
  cooldowns, supers, zones, the adaptation window and flags, crowd heat,
  condition), and beneath them every state variable of the sim as one
  typed blob (`var_to_bytes`: ints stay ints, floats keep every bit,
  Vector2s survive) with the RNG's seed and state. A restore lands on the
  same state hash and a log continued from it hashes as the unbroken run
  does. The content tables (patterns, tuning, the library, the data files)
  are not state: the snapshot carries a stamp of them and restores only
  under the same data; another schema, another build of the sim (its state
  variables differ) or a blob that is not a state are refused, each naming
  why, and the sim they were refused into is untouched.
- The greybox: Shift+F5 writes `user://tnb_save.json`, Shift+F6 loads it
  (the feed says what the save holds and, for a fight in flight, that it
  resumed on the same hash), `-- load=<path>` at the bell, `-- demo
  saveload` for the soak.
- Not in this pass: the overworld's own fields (the calendar as dates, the
  story flags, the walls, the codex, staff levels); save slots and
  versioning beyond the schema string (an older schema is refused, not
  migrated); a save under changed content (refused, not migrated); the
  Fighter record's fields the sim does not know (nickname, age, board,
  gear, personality, ai_profile, recruit).

## PAC-070 in the build: THE GENERIC OPPONENT ASSEMBLER (NP_04 s9)
- `sim/assembler.gd` (TNBAssembler) builds a non-named opponent's pattern
  from the piece library (`pattern_pieces.v1.json`, vault copy
  `data/pattern_pieces.v1.json`: 63 pieces - 36 strings, 3 per Style per
  tier; 12 punish hooks, 3 per Style; 15 tell dialects, the 13 named
  Houses that have one plus the school's and the gym's) in the compiled
  shape the sim already executes: 2 strings at tier 1 and 3 above, an
  opener first and the Style's SPECIAL last at tier 3 (never lower), one
  PUNISH with its placeholders resolved to the strings assembled, every
  tell on the dialect's channel with one of its motifs, SELECT weights
  from the Style's preset, the interrupt block by tier (every normal /
  the first two / the opener), tells shifted into the tier's band (Loud
  600-1200 / Standard 450-700 / Subtle 400-500) and floored by class, the
  stat block by tier (40 / 55 / 70; a card's stats override). No bait,
  phases, desperation or idle lines: a generic is a pattern, not a
  character. Named-boss strings never appear - no piece shares a label or
  an action sequence with any of the 24 bosses' 79 strings, and a smoke
  gate holds it. Deterministic from the spec: the same name, Style,
  dialect, tier and seed assemble the same pattern in any sim; a card
  with no seed takes its name's hash, so a card is the same opponent every
  time.
- Where generics fight: an NPC card marked `generic: true` with a `tier`
  (Ep1's CHALLENGER, MARCUS, JUNE at tier 1, PRIYA at tier 2) fights a
  scrap or spar on strings of its own - the `opponent` boss still lends
  the slot, the club and the index; its PI dialect is the card's named
  one (the school), else its House's, else its own name (Marcus, Priya)
  with the tells on the gym's channel. A dual's filler slot
  (`set_generic_slot(i, spec)`, `-- generic=`) puts an assembled generic
  in a named boss's place in the enemy lineup: the matchup card reads its
  Style, element and House, the fight ticks its dialect, it pays, and it
  earns no Scout Book page (pages are the named bosses'). SCR-09 / SCR-17
  are refused against a generic (no breakable special). A generic's
  pattern is state, not content: a snapshot carries it and the content
  stamp never sees it, so a dual with a filler saves and restores like
  any other.
- Not in this pass: the launch library's 60 authored pieces (these 63 are
  a first draft: labels, actions, motifs, weights); fillers dressed by a
  club's roster size (every club still dresses from the 24); generics with
  bait hooks, phases, a desperation or idle lines; the mockups' story
  route (a card names a dialect - the route that hands the card over is
  the overworld's).

## PAC-071 in the build: THE NEUTRAL GAME (NP_04 s2 IDLE)
- Every IDLE line of the 24 patterns runs (`neutral.v1.json`, vault copy
  `data/neutral.v1.json`: 41 verbs for 52 lines). Between strings (IDLE /
  RECOVER) each boss closes, keeps range, circles or holds it his own way:
  the walks at their own pace straight at where you are (Moreau and Remy
  0.45 m/s, Moira 0.7, Sam 0.8, Reyes 1.0, the Echo 1.2) against the shared
  approach's 1.2 leading your movement (the Choir keeps it, silently);
  Alfie crowds to 1.5m, Deshawn to 1.3, Osei and Surety wait at 2.0; the
  orbits circle at range (Yuri 0.5 m/s one way, Carter 1.2 the other,
  Marta 0.8 at 2.1m and stepping back out to it; Vane, the Cartographer
  and Sora reversing on 2.5 / 3 / 4s clocks, Baro after every string); Ada
  steps only in the first 200ms of every beat of her metronome (650ms in
  phase 2) and Chiamaka on both of hers; Tam comes in 35 degrees off the
  line and switches sides every 1.5s; Vey mirrors your lateral movement
  at range; Vasile holds 1.7-2.1m both ways; Cal takes the centre and
  comes no closer than 2.2m; Moira approaches from the centre side and
  cuts the ring. In a tell every boss closes to 1.9m at his own pace.
- His guard when he has not read your punch is the authored one, head /
  body: mid 0.35 / 0.35 (the old flat rate), high 0.5 / 0.15, Ada's tight
  0.45, Alfie's rough 0.25, Sora's perfect 0.5, Baro's textbook 0.4, Tam's
  low bait 0.1 / 0.6, Osei's shell 0.6 / 0.1, Sam's up at 0.8 while he
  walks in; an authored guard halves when he is wobbled (NP_03 s3: the
  cue to swarm) except Cal's and Surety's, which are composed.
- The clocks: Yuri taunts every 8s and Carter every 10s (the guard open
  500ms, his read off, his next string held 700ms - a jab lands); Vane's
  `no_taunt` keeps the clock off; Tam's tempo flips every 6s (his gap
  between strings x1.4 then x0.6, his walk x0.7 then x1.3).
- Three lines are flags only the presentation reads, named as such:
  Jean-Guy's silent feet, Marta's feet going quiet while she arms, Reyes'
  corner bell (two bells with a Reyes dressed). Remy's `unmasked` names
  his slot at the corner of a blind dual where every other shows '?'.
- A frozen boss (the tests' `freeze_boss`) keeps the shared approach and
  the 0.35 guard - the pre-PAC-071 code path - and so does a generic,
  whose pattern has no IDLE lines.
- Not in this pass: the IDLE lines' audio and animation (the flags are
  there for them); a guard height as geometry (the guard is a block
  chance by head and body, not a posture the punch regions test).

## PAC-072 in the build: THE TALK (NP_10 s4)
- The corner's fifth action (the other four since PAC-058): Whitlock
  talks to the next fighter. Every talk offers the same three approaches
  (`talk.v1.json`, vault copy `data/talk.v1.json`) - the plan, the fire,
  the arm around the shoulder - each in that fighter's own line, and the
  fighter's card says which one lands (`talk` on the card, NP_11 s9's
  personality.talk_profile): RORY fire, PRIYA plan (NP_12A: the projection
  confirmed, never comfort), MARCUS arm, JUNE fire, SAM arm, DEX arm, YURI
  fire, MARTA plan.
- A right read: +5% on every stat for that fighter's segment, bound to
  that fighter by name - swap someone else in after the talk and it goes
  unheard. A wrong read: the action is spent and nothing else happens;
  once the fighter is out, the state is the one where nobody talked, to
  the hash. One talk per corner; a card with no profile cannot be read.
- Bond levels reveal which talk lands: the next fighter's best Kizuna
  with a dressed teammate - Gymmates rules one wrong option out, Corner
  Voices and above names the right one - shown on the corner menu with
  the teammate who says it, and raised as a `talk_hint` event.
- The save carries each card's profile; a corner saved after a right
  read restores and the +5% lands. The profile in manager mode never
  talks - the corner is yours.
- Not in this pass: the lines themselves (24 placeholders for the content
  lane), bark sets, the Lv3 coach's third action.

## PAC-073 in the build: THE WHITEBOARD (NP_10 s2-3, NP_01 s7)
- Your board is data the sim takes at setup and seals at the bell: the
  dressed squad in slots R1..R5 (R1..R3 in the mini) and the rest in
  reserve, with 3 staff. Sealed before the bell from the formation
  screen, it is the same dual as a board handed over at setup, to the
  hash; after the bell it is refused - the corner's swap is the reorder.
  A board of the card order is exactly the dual with no board.
- The named orders are presets over your starters, the ace and the
  anchor read off the cards (`formation.v1.json`, vault copy `data/
  formation.v1.json`): the ace is the highest PWR+SPD+RFX (NP_01 s2.1's
  Hammer), the anchor-class the highest CHN+BLK+STA of the rest.
  Standard: ace at R4, anchor at R5. Ambush: ace at R1. Wall-First:
  anchor at R1, ace at the Hammer. Relay Ladder: the best-bonded chain
  (Kizuna points) at R2-R3-R4, toward R5. In the mini the ace closes.
- Their projection: his probable order, one confidence per slot - how
  readable his coach's archetype is (Standard 40, Wall-First 35, Ambush
  30, Relay Ladder 25), Priya's binders on Toronto's corners +30, a
  Tactician on your board +15, Pattern Intel on the dialect of the
  fighter in that slot +5 a level (his page counts as 3), capped at 95;
  under 35 the slot is a silhouette. The percentage is honest: a slot is
  right that often, rolled by the seal without touching the fight's RNG.
  It is live on the formation screen and fixed at the bell; each slot is
  marked revealed, with who is really in it, as its segment begins.
  Ep1: Millbrook's four against Ascendant B - "probable order at 70%".
- The decoy seal (NP_10 s3): Vey's corner (0.5) and the Hollow Circuit
  (0.4) run one at their `decoy_rate` (now in `coaches.v1.json`): every
  name shifted a slot, every percentage as confident as ever. His real
  order is untouched. A Tactician at Lv3 on your board reads it: the
  board says DECOY and shows nothing it can trust. A blind dual has no
  projection.
- The rings overlay: every pairing on the board read by the matchup
  card's own function (the triangle, the element, the feud, the EP
  modifier) with one coach note - "Cassidy Vane eats sluggers for
  breakfast", "Bad wind for us, but this segment will PRINT Tension".
- The save writes the stable in the board's order with its reserves, so
  a load dresses the same board; the DualState keeps the sealed orders
  and reveals who went out. A scrap or a spar still sends the first card.
- Not in this pass: the Gym Wall's card proximities, scout assignments
  beyond the one stand-in, rival-dual attendance and story leaks as
  sources, a board for his side that reads yours.

## PAC-074 in the build: THE STAFF AND THE CROWD (NP_10 s6, NP_01 s1)
- A corps of ten (`staff.v1.json`, vault copy `data/staff.v1.json`):
  two cutmen, two tacticians, two hypes, three conditioning coaches and
  the Professor, each carrying his role's corner active. Three are
  dressed - the board's, else the equipped three (the sports-med
  student, the janitor who used to be somebody, the retired boxer).
- Each dressed staffer's passive is live: the cutman restores +15
  stamina to a fighter back on the stool with his condition carried; the
  tactician's +15 on the projection and a richer Scout Book page (his
  corner's order, its decoy rate, the slot his pattern names); the hype
  heats the crowd 20% faster; the conditioning coach +10% stamina regen;
  the Professor doubles the PI a dual segment earns. Two of a role both
  count.
- Levels come by use: every charge a staffer spends is a use on the
  ledger - Lv2 at 3, Lv3 at 8 - and Lv3 unlocks the role's second
  passive: the cutman +10 composure too, the tactician reads a decoy
  seal (earned now, no longer declared on the board), the hype starts
  the dual at 10 Tension, the conditioning coach makes an overrun send
  the fighter out at 90, the Professor doubles scrap and spar PI too.
- The crowd: your own spectacle heats the building (a DROP 20, a flash
  10, a counter 5, an interrupt 6, up at eight 15, a hissatsu 8), never
  his; Raise the Roof converts 30 heat into its +8 Tension and is
  refused, charge kept, when the building is cold.
- The save writes the corps as NP_11 s9 Staff records (level, uses,
  passives, the active and its charges, the dressed three in order) and
  a load dresses them back.

## PAC-075 in the build: RECRUITMENT (NP_08 s2)
- `recruits.v1.json` (vault copy `data/recruits.v1.json`) carries every
  one of the 24 bosses and Dex: thirteen conditions in NP_08 s2.2's
  grammar, each the roster docs' own line with its source (Yuri's and
  Sam's "recruited post-dual" read as BEAT_IN(dual[segment]); Dex's a
  draft), and twelve the docs close - Vey, the syndicate, Cal (staff),
  Itzel, Chiamaka (post-game), the unauthored. (PAC-075 closed Jean-Guy
  on his Arc 1 refusal; PAC-076 opens him in Arc 2 on Q-MOREAU's line.)
- A dual won flags the recruitables of the squad you beat (up to four;
  Dex surfaces with Moira); a dual lost flags nobody. Approaching one
  surfaces the whole condition, every clause with what you have and what
  it needs. Nobody joins on his own: a met condition raises READY, and
  recruiting puts his card in the stable.
- The whole grammar runs: BEAT_IN (your wins against him by size - scrap,
  spar, dual segment - xN and USING STYLE_PROOF), STYLE_PROOF, PI_LEVEL,
  BOND (a stablemate's best Kizuna), STAT_PROOF, WITNESS (duals won after
  the approach) read the sim's ledgers; QUEST, REP, FEUD_RESOLVED,
  BLESSING and ITEM read the story flags the overworld sets.
- The stable is now its own list: every card the club owns. A recruit
  sits in it undressed until a board dresses him (`dress` names the squad
  from the stable). The four editorial Millbrook recruits join as their
  Millbrook cards; a recruited boss brings his META style / element /
  House, the assembler's tier-3 stat block and his desperation move.
- The save writes the whole stable (the undressed flagged), the recruit
  ledger and the story flags, and a load brings them all back.

## PAC-076 in the build: THE STRING WALL (NP_08 s2.3)
- `string_wall.v1.json` (vault copy `data/string_wall.v1.json`): six maps
  of the questlines' own people - Three Chairs at the Table, The Open
  Ledger, What the Water Keeps, The Barn Lesson, Cold Storage, Where
  Rivers Meet - 43 cards (16 fighters with recruit records, 14 leads the
  docs name who have no card, 13 houses with NP_07A's blessing lines) and
  42 strings: family, master to student, member to his house. The BOND
  conditions are the first strings: Dex -> Moira, Carter -> Ada, Sam ->
  the Choir.
- A recruit turns up the cards strung to him: CARTER his sisters, his
  cousin and his house; REMY his cousin JEAN-GUY; SAM the junior he
  corners for and CHOIR. A fighter turned up is approached - his
  condition on the HUD, the string he came by named - and a lead is on
  the wall, never in the stable. A student signed does not turn up his
  master.
- A house's blessing (`-- flag=blessing:<house>`, the overworld's flag)
  turns up the house, its members and the houses bound to it by ALLIED,
  MARRIAGE or DEBT - never across a FEUD. House Iron has nobody left to
  bless: its crest brings Vera Iron with it.
- `recruit *` ([P]) signs whoever a string turns up already met, in the
  same press. The save writes the wall as the ledger's view; a load
  turns no card.
- The correction that came with it: Jean-Guy is recruitable in Arc 2
  (NP_07A Q-MOREAU: `QUEST(cold_storage) AND FEUD_RESOLVED(moreau,
  tremblay)`), his Arc 1 refusal kept; Remy's quest is `cold_storage`.

## PAC-077 in the build: BLESSINGS AND THE LIVE GRAPH (NP_08 s3, NP_07A)
- `houses.v1.json` (vault copy `data/houses.v1.json`): the fourteen
  houses with NP_07A's blessing lines - twelve; Iron has nobody left to
  bless, the sealed house blesses itself - and the rules the lines need:
  the Kowalchuk patriarch's and Tagaq's witness, Petrov's own-moves
  proof, the Reyes code.
- Each line is read against the ledgers with the house as its subject:
  wins against any fighter of that house, a dual won while its crest is up
  on the String Wall (Tagaq's without your corner converting crowd heat),
  a win over an Ascendant fighter by Petrov moves alone - clause by clause
  on the String Wall's house card and the HUD. Met - or its flag set -
  the house blesses the club at that moment.
- A recruit of a blessed house arrives NATIVE: his house's natives
  unlocked (the SECRET stays with its gate event), the +10% home bonus on
  them. An unblessed one arrives UNSANCTIONED - natives locked, no home
  bonus - and is sanctioned the moment the blessing lands. Efua can be
  recruited around her family (her segment won, a draft) and arrives
  UNSANCTIONED. A card equips an unlocked native between duals.
- The Reyes code: La Campana thrown in a dual at a fighter above 40
  stamina voids the Reyes blessing for good.
- The feud graph flips on its questlines' flags (`feud_graph.v1.json`'s
  `flip` per edge): E05 on its FEUD_RESOLVED flag, E04 on okafor_table,
  E08 and E12 on estate_sale, E02 once both houses' final beats and its
  own flag are set, E01 on the Arc 2 spine's; E11 refuses; the
  Petrov-Ascendant DEBT is added on open_ledger. The ledger holds the
  flips; the house ring, the ALLIED bond bonus and the wall read the graph
  as it stands.
- The save writes the house codex, the graph and each Fighter's
  house_status and natives.

## PAC-078 in the build: HOUSE TRAITS (NP_07 s3, s5)
- The nine authored traits run (`houses.v1.json`'s `traits`): Never Twice
  (the second drop of a segment is a wobble, once a dual), Deep Roots
  (guard regen +50% while trailing on drops), Long Winter (all stats +10%
  in R4/R5), First Frost (counter windows +100 ms in the opening 15 s),
  Harvest (+1 Tension on every clean exchange, anywhere), Load-Bearing
  (composure 20% deeper on the ropes and in the corner), Tide Discipline
  (stamina never below 10), Open Door (bonds x1.5) and Debt of Honour (all
  stats +25% against a feuding house on the live graph).
- Both corners: Yuri, Sam, Carter, Ada, Chiamaka, Itzel and Moira carry
  theirs into your fights; SAM, DEX, YURI and MARTA carry theirs into his.
  Deep Roots, First Frost and Open Door are yours only - a boss's guard
  never regenerates, his counters are strings, he keeps no bonds.
- Blood only: Anders (taken), Baro (a teaching root system) and HC-7
  (extracted) carry none; a disowned heir none; UNSANCTIONED keeps it;
  the last of a dead lineage doubles it. The three variants (Petrov,
  Delacroix-Cardinal, Moreau) are named, not run.
- The matchup card's TRAITS line names what is in play; the codex and the
  Fighter record carry the trait.

## PAC-079 in the build: THE GYM WALL (NP_08 s7)
- `gym_wall.v1.json` (vault copy `data/gym_wall.v1.json`): an 8 x 4 wall of
  card cells, Whitlock's letter at the left of the top row (NP_12A scene
  1), four decorations and what unlocks each, the suggestion (the
  whiteboard's 6) and the Sworn gilding.
- Every stablemate's card hangs on the wall: the club's cards from the
  cell beside the letter in the stable's order, a recruit beside the
  stablemate whose string brought him (ADA beside CARTER), the next free
  cell otherwise; a full wall keeps the rest in the locker. The player
  pins any card to any free cell (`-- wall=NAME:col:row`).
- NP_10 s2's pre-suggestion: the starters in the order that walks the
  wall the shortest way - the nearest cards in adjacent slots, ties to the
  card order. The whiteboard shows it before the bell (THE GYM WALL
  SUGGESTS) and 6 seals it as "The Gym Wall". Pins alone never change the
  order, and a board sealed otherwise stands whatever the wall says.
- A Kizuna line for every pair of pinned cards with any Kizuna, filling
  toward the next level and gilded at Sworn.
- Decorations from play: a fight poster for every dual won, a ticket stub
  the first time a club is faced (won or lost; the coach table's club, an
  unaffiliated squad its lead's), a polaroid for every Kizuna level
  crossed, a recruit's wraps signed on the wall. They hang anywhere on the
  wall (`arrange`) and carry zero stats: nothing on the wall is in the
  state hash; only a board sealed from its suggestion moves a fight.
- The save writes `gym_wall {layout, decorations}` and a load hangs the
  same wall (a save from before the wall hangs its bench after the four).

## PAC-103 in the build: VENDOR TIERS (NP_02 s4)
- The technique shop and the gear shop stand on the Downtown Strip. Their
  t2 and t3 shelves open by DOWNTOWN's rep (10, 25) as well as by the
  story's flags (`techniques.v1.json` / `gear.v1.json`: the shop's
  `district`, a shelf's `rep`).
- The shelf reads the rep as it stands: a flee below the line shuts it
  again; what was bought stays bought.
- DUAL OVER's SHOPS lines name each shelf and what a shut one wants; a
  refused purchase names the rep; the REP toast names a shelf opened, the
  FLED toast one closed.
- `-- rep=downtown:9` seeds the ledger's rep; `-- demo vendors` has the
  aid buy off the open shelves between bouts.
- `-- faucets` names each shelf's key at story pace: all four open by
  their flags in the circuit, none by the rep ahead of the story.

## PAC-102 in the build: THE ANTI-YOU (NP_12 s2)
- Between arcs (the story flags `story:nationals` and
  `story:hollow_circuit`), Vey's academy signs up to 3 of the club's
  beaten rivals it never recruited - the approachable left waiting and
  the released - in the ledger's order (`academy.v1.json`'s `recruiting`).
- A card so taken is out of the club's reach: the approach says "signed
  with Toronto Ascendant Academy at <turn> - beat the academy first".
- Fielded (`academy true` on the OVER screen), the taken rivals stand in
  the academy's first slots with the displaced prodigy's syntheses; a
  rival with no pattern of its own is held, not fielded.
- Beat the academy in a dual and the taken come over approachable, the
  release's grudge / warmth kept. RECRUITS and the String Wall name who
  went; the THE ANTI-YOU and THE ACADEMY BEATEN toasts.
- `-- demo anti boss=19 level=RORY:20,PRIYA:20,MARCUS:20,JUNE:20` soaks it
  against Moira's squad; the aid turns the arc only once the club has left
  someone waiting (at the default levels the club can lose both duals, and
  then nobody is signed).

## PAC-101 in the build: DISTRICT REP (NP_02 s2.1 / s4; NP_08 s2.2 / s2.4)
- `-- scrap=SCR-01 district=rink` places the scrap; won, the district's rep
  is +1 (a scrap placed nowhere moves none). The milestones 3, 10 and 25
  pay 1, 1 and 2 Prestige the first time (NP_11 s6's 5-15 a session is
  scraps and rep together).
- BACKSPACE flees a scrap: free before the first exchange, -1 rep after
  (never under 0), unpaid either way. A spar or a dual is fought out.
- REP(district, n) reads the ledger - Carter Okafor's rink, the Whitecloud
  blessing's Hill; a seeded rep flag still counts.
- The head names the scrap's district and rep; the OVER screen's DISTRICT
  REP line; the REP and FLED toasts.
- `-- faucets` fights the story-pace scraps in each phase's districts:
  the milestones pay 20 Prestige; still GREEN, Prestige at 85% - the
  band's edge.

## PAC-100 in the build: THE LOCKER ROOM (NP_08 s4)
- DUAL OVER's LOCKER ROOM lines browse the stable - 8 cycles by House,
  Style, Element, bond web and slot-role - and show the focused card's
  comparison card (9 the next card): House, Style, Element, home, role,
  grown stats, kit, trait, dialect, bonds.
- 0 releases the focused bench card: the place freed, the role cleared,
  the gear back in the locker, off the Gym Wall, the ledgers kept.
  Shift+0 takes the latest release back before the third day turns,
  everything as it was. The story's four are never released.
- At the third day the release stands: a recruit is back in the district
  and approachable, a generic on the open mat. Warmth (a Kizuna Lv1 bond
  left behind): the recruit answers the approach at once, the generic
  signs free any day. A grudge: the condition again and a spar won since,
  or the priority even on an open-mat day. The card comes back as it
  left and the Fighter record remembers.
- NP_08 s1's 100: a recruit is refused at the cap too.
- The RELEASED / TAKEN BACK / GONE toasts; `-- demo locker`.

## PAC-099 in the build: THE STABLE ROLES (NP_08 s1; NP_11 s9)
- A stable card not dressed takes a role between duals (NP_11 s9's
  stable_role, on the reward ledger and in the save); dressed, it waits.
  7 sets the aid's pick for the first bench card without one: a training
  partner if the club has none, a scout if nobody covers his home
  district, else a cornerman-in-training. Shift+7 sends the last one back.
- Training partner: a slot that names no partner takes him along; +1 Bean
  for every 10 points he leads the trainee by at the game's stat (3 at
  most), typed as that stat.
- Scout: each district the bench's scouts cover pays 1 Prestige when the
  day turns; a scout from a circuit district reads its clubs' orders at
  +20 on the projection.
- Cornerman-in-training: at a dual's end, a use for the least-used dressed
  staffer below Lv3 (then the corps').
- Home districts: a generic's from the machine, a House card's by the
  House's root (YURI the prairies), a houseless card's Millbrook.
- DUAL OVER's ROLES lines; the ROLE / THE SCOUTS / THE CORNER toasts; the
  training toast names the partner's bonus; `-- demo roles`.
- `-- faucets` counts a story-pace bench (three open-mat generics from
  the circuit): the scout's 24 Prestige, the partner's 0 Beans to RORY,
  42 staff uses; still GREEN.

## PAC-098 in the build: WHAT THE FAUCET AUDIT NAMED, FIXED (NP_11 s2, s6; NP_08 s2.4)
- XP's pace: every payment x `economy.xp.pace` (2.7) - NP_11 s2's canon
  curve paced to the story; a story-pace captain reaches level 35 by Arc
  3. A dual's reserves take half the dual's total at the pace once.
- The story's HBP: `story_mark(flag)` lands a story beat (50 HBP) or a
  quest step (30) on the ledger; a seeded flag pays nothing.
- A session's Spirits: a spar pays 2, a dual 5 or 8 (NP_11 s6's 3-8 a
  session).
- The scouting machine: ` pulls for 10 Prestige - a lead card, every 10th
  rare (a named recruit the club has not met turns approachable; then the
  String Wall's Vera Iron), the rest generics waiting on the open mat.
  Shift+` signs the open mat's first - free every 7th day, else for 10
  Prestige. DUAL OVER's SCOUTING lines, the LEAD / RARE LEAD / OPEN MAT
  toasts, `-- demo scouting`.
- The obsolescence budget is the faucet's share of a fighter at the 70%
  target: Spirits 110, Beans 140, HBP 1,700.
- `-- faucets` GREEN; `-- audit` GREEN.

## PAC-097 in the build: THE FAUCET/SINK AUDIT (NP_11 s6)
- `faucets.v1.json` (vault copy `data/faucets.v1.json`), read by the
  audit, not the sim: a story-pace playthrough to Arc 3's start - Arc 1's
  24 episodes and Arc 2 at its length, a story dual an episode at NP_02
  s5's cadence, its 45-minute session shape between (5 scraps, 1.5 spars,
  1 training slot), three phases with their formats, losses, flags and
  gym tiers; the results given; the 70% target; the sinks wanted (the
  squad of eight, the gym to T3, a Forge); NP_11 s6's typical/session.
- `sim/faucets.gd` pays every fight through the sim's own paths
  (`pay_segment`, `_pay_dual`, `_pay_bout`, `train`) and measures a
  segment's own XP with `event_xp` from the obsolescence audit's fights.
  It prices each build off its ledger and names each currency that
  misses: its share, its session pay, the protagonist's level, the
  obsolescence audit's budget.
- `event_xp` and `pay_segment` (core) are the segment XP's one rule.
- `-- faucets` prints the report and the verdict; it exits 1 when RED.

## PAC-096 in the build: WHAT THE AUDIT NAMED, FIXED (NP_11 s1, NP_05 s3)
- Stat totals by rarity (NP_11 s1): a card under his tier's total is
  lifted to it - Circuit 420, National and Legend 490 (the late
  recruits' card, 70 a stat). His own stats scale up in proportion, so
  he keeps his shape; each to the tier's cap, the overflow to his lowest.
  The board and the raises add on top. Read off the rarity each time,
  never stored (`growth.v1.json`'s `rarity.totals`). The ASCENDED toast
  names the tier's total.
- The defensive board (NP_05 s3): the Anchor Wall (3 points) on every
  layout's Spirit lobe beside Wallflower. Taken, the board teaches Shield
  Wall, Windbreak and Palisade (T2 WALL, 25) free; a T2 in a slot wants
  it from any source, and a respec takes it out of the kit. WALL is the
  fifth motion family, so level 35's fourth slot answers.
- The aid seeks the Anchor Wall only when his slots outnumber the families
  his own move leaves free (level 35); below it the picks are the same.
- `-- audit`: GREEN, 3 of 3 viable. `sim/audit.gd` is unchanged.

## PAC-095 in the build: THE OBSOLESCENCE AUDIT (NP_11 s10)
- `audit.v1.json` (vault copy `data/audit.v1.json`), read by the audit,
  not the sim: the earliest three by NP_12 s4 (PRIYA, DEX, YURI), the
  reference (the arc 2-3 recruits), the endgame (arc 3's bosses at level
  35), the budget by Arc 3, the viability criteria, and the system each
  shortfall names.
- `sim/audit.gd` builds each card with live systems only - the endgame's
  XP, the three trials by their own code paths and each ascension paid,
  the board by the aid's picks, the raises, a kit from the open shelves
  and lessons, the gear - then fights the endgame's bosses on the profile.
  Viable: tier 4, a competitive board (every point but one, three
  passives), a coherent kit (every slot filled, every move answering) and
  half the segments won. A shortfall names the system, not the fighter.
- `kit_unreachable` (core) states C45's cast order: a move behind a
  cheaper-or-equal one on its family never casts.
- `-- audit` prints the report and the verdict; it exits 1 when RED.

## PAC-094 in the build: ACCESSORIES AND GEAR (NP_11 s5)
- `gear.v1.json` (vault copy `data/gear.v1.json`), a new content table:
  the cap (3%), the four kinds and their keys, the shop's shelves, the
  festival's order, the house gift's rule, eighteen pieces (a look, a
  colour, at most one passive).
- A piece's passive is its kind's, on the board passive's own hook:
  gloves the jab (Snap's), wraps the guard lost holding (Tight Guard's),
  a mouthguard the wobble (Iron Jaw's), a robe the personal Tension
  (Sparkplug's). One piece a kind, in the slots the rarity opens, so no
  key carries more than 3% - the board's 15-30% always outweighs it.
- The sources: the HBP shop on the technique shop's three shelves; the
  circuit's prizes with their flags; a blessed house's colours, the piece
  by its style; the festival's prizes for an Exhibition 2v2 won on the
  boardwalk; signature gear, its owner's alone (Yuri's Grain-Sack Wraps,
  Efua's mother's wraps with her questline). The story's pieces are read
  off the ledgers, never stored; what is bought or won is the ledger's.
- The save writes each Fighter's `gear` (NP_11 s9's `[item_id, ...3]`).
- The greybox: DUAL OVER's GEAR lines, \ , Shift+,; the GEAR toasts, the
  matchup card's GEAR line, the figure dressed (gloves, wraps, the
  mouthguard, the robe at the walk-out); `-- gear=`, `-- demo gear`.

## PAC-093 in the build: THE MIRROR SPAR (NP_02 s2.2)
- The tracker's record: the adaptation tracker (C7) forgets a fighter at
  every bell; the record (`rewards["habits"]`, per fighter, across every
  dual, scrap and spar) keeps what it saw - the punches by row, the
  feints (a feinted punch once, as the feint), every two- and three-token
  sequence thrown, the sequences it read, the counter windows his defense
  opened and the punch he threw into them. It rides the save's ledger.
- The copy: `mirror_card` now carries the record. Its strings are his
  sequences thrown three times or more, ranked by thrown x length (one
  inside a string already taken skipped), as many as the copy's tier
  holds; their shares of the Style's preset are its SELECT; the Style's
  pieces fill what the record cannot (no record: C44's mirror as it was).
  Every row has a verb (`L_HAY` and `L_OVERHAND` added for the lead
  hand); a feint is a 200 ms pause where the punch was.
- The bell: its tracker opens reading his three most-read sequences at
  the tier the reads reach (capped at 3) - C7's read, defense only - and
  fades like any read. When its read makes him miss it counters as he
  does: his most-thrown counter punch (x1.3), at his rate (counters /
  windows), once he has two.
- The lab's `mirror` flag (The Ring's T1) and [M] (the Legend's trial,
  authored) both fight it; any mirror beaten meets the trial. A mirror
  books no Pattern Intel: the pattern is his own.
- `bouts.v1.json`'s `spar.mirror` holds the rules; the greybox: DUAL
  OVER's HABITS line, the matchup card's MIRROR line, THE MIRROR and YOUR
  COUNTER toasts, `-- habits=`, `-- demo mirror`, [M] back to the dual.

## PAC-092 in the build: THE ACADEMY'S SYNTHESES (NP_07 s10, Arc 3's thesis)
- `academy.v1.json` (vault copy `data/academy.v1.json`), a new content
  table: the Toronto Ascendant Academy, Director Vey's corner, the
  synthesis rule (x0.85, three a prodigy, the name rule, the source and
  VFX ids, reach +0.3, interruptible in 700 ms) and five prodigies - a
  style, one house's dialect, three house pairs each; fifteen pairs over
  the twelve houses with natives, each house in two or more.
- A synthesis is the Forge's own composer (C41) run on two houses'
  natives straight off the library (the SECRET excepted) - no pair, no
  bond, no native learned - its damage x0.85: Synthesis Grain-Snow x2.13
  against the club's Grain & Snow x2.5, every synthesis under the T3 floor
  (2.4) a forged hybrid starts at. Slightly weaker per move, overwhelming
  in breadth: fifteen across the squad against the Forge's ceiling of
  eight.
- `-- academy` fields the squad in every enemy segment (the prodigies are
  generic cards on the assembler, drilled on a dialect without the house:
  no trait, no home bonus; no named bench, so Vey's swaps stay inside the
  academy) and Director Vey's corner coaches them. At his
  decision point, with his bar paying 50 and within the family's reach, a
  prodigy casts the next synthesis in his rotation: no CHARGED, no relay,
  no afterimage, no duo VFX, no feud or alliance history. A jab in the
  windup breaks it, his bar spent.
- The matchup card's ACADEMY line names his syntheses; its THESIS line
  sets the club's forged hybrid (the one live for the fighter out, else
  the strongest) against his best: "x2.5 (x3.13 relayed)", or "relayed
  now, x3.13 with YURI's afterimage". The SYNTHESIS toast.
- The save's settings carry `academy`; a load fields the squad again.

## PAC-091 in the build: TECHNIQUES AND THE SLOTS (NP_11 s2, s8)
- `techniques.v1.json` (vault copy `data/techniques.v1.json`), a new
  content table: the slot levels, the T0's level, the shop's three
  shelves, the masters and their gates, the tapes, the re-teach; the
  library's `source` field says where each move comes from.
- A card walks out carrying its own move and a kit beside it. A
  technique slot opens at each of levels 5 / 15 / 25 / 35 / 45 for a
  learned T1 or T2; the T0 slot opens at 5 for exactly one T0 (a card's
  own T0 is it, castable from 5 - Priya's Marginalia); his house's natives
  take no slot. LB + a motion casts his own move on its family, else the
  kit's first move of that family; the profile casts his own when it can,
  else the kit's.
- The sources: the HBP shop (t1 as found at 100, t2 with the Regionals at
  400, t3 with the Provincials at 800); the masters (Whitlock's Eight Count
  Answer after a survived standing-eight and Timberfall on the coach
  questline; the conditioning coach's Roadwork; DEX, CARTER and CASSIDY's
  own moves behind a bond, a stat and a flag); fight tapes, spent on use
  (a quest's arrives with its flag); the natives and the Forge's hybrid as
  before; the re-teach of a learned non-native in a training slot, the
  teacher keeping it. A move learned goes into the kit when there is room.
- The save writes each Fighter's technique_slots (his own move, then the
  kit's), native_slots, signature_t0, the slots open and what he learned.
- The greybox: DUAL OVER's TECHNIQUES lines, [ ] ' / = -; the LEARNED,
  THE SHOP, THE KIT, RE-TEACH and FIGHT TAPE toasts; the matchup card's KIT
  line; `-- learn=`, `-- tapes=`, `-- demo techniques`.

## PAC-090 in the build: THE FIGHTER'S GROWTH (NP_11 s3, s4, s6)
- `growth.v1.json` (vault copy `data/growth.v1.json`), a new content
  table: the four style layouts (60 hex nodes each - the spine, the Body,
  Craft and Spirit lobes), NP_11 s3's nine passives of a 40 pool, the named
  characters' nodes, the costs and the soft cap, the raises, the typed
  Beans' partner share, rarity's caps, Spirits, trials and slots.
- The board: a node is taken between duals when it touches one already
  taken (the stance at the root is free), paid in Board Points (2 a
  level). +2 / +3 / +5 cost 1 / 2 / 3, a breaker 2, a passive 3; a stat at
  70+ doubles a stat node's price until that stat's breaker is taken; a
  stat node at the cap is the way through and adds nothing past it. The
  Boxer-Puncher's spine ends in the off-style socket (one craft passive
  from another style's board). Respec is free from the Film Room's T2.
- The nine passives run on the sim: Tight Guard (guard decay -20 % while
  holding), Snap (jab +30 %), Ring Cutter (herding +25 %), Iron Jaw (the
  wobble 30 % shorter), Second Gear (the gassed curve halved between 15 and
  40 stamina), Sparkplug (Tension x1.15), Cheap Trick (a T0 at 8), Closer
  (CHARGED at -5), Wallflower (a T2's timed effects +1 s).
- The raises: +1 for 5 Beans, +1 Bean for each raise already on that stat;
  the stat's own typed Beans pay first, then the untyped. A training slot
  types its Beans by its game (a partner along a quarter as his best stat);
  the Forge spends the untyped first.
- Rarity: Club / Circuit / National / Legend - growth capped at 70 / 80 /
  90 / 99 (a card's own stats stand), up for 10 / 25 / 60 Spirits and a
  trial (a spar won; a transform weathered; the mirror beaten), an
  accessory slot a tier, and a generic's Awakening flag at the Legend's.
  The mirror is a spar against his own card, grown, on assembled strings.
- At the bell the fighter walks out on his grown stats with his passives
  on him. The save writes each Fighter's rarity, board (layout, nodes
  taken, points free, socket), raises, grown stats, passives and flag.
- The greybox: DUAL OVER's GROWTH lines, [N] / Shift+N / [Z] / [X] / [M] /
  [.]; the THE BOARD, RESPEC, THE JAR, ASCENDED and TRIAL toasts;
  `-- growth=`, `-- beans=`, `-- nodes=`, `-- demo growth`.

## PAC-089 in the build: THE CLUB FACILITIES (NP_10 s7)
- `facilities.v1.json` (vault copy `data/facilities.v1.json`), a new
  content table: five tracks, T1 -> T3, the club at T0 as found. A tier's
  price and story gate: 150 HBP and 5 Spirits (the charter saved), 400
  and 15 (the funding quest), 800 and 30 (the Nationals). `gym_wall.v1.json`
  gains the renovation photograph and the honours set's crest and feat.
- A renovation runs between duals (or before the first bell): the ledger
  pays, the tier goes up, its photograph goes on the Gym Wall, its effects
  land. A track's effects arrive in the table's listed order, one a tier:
  - Bags & Mitts: three training slots a day. Roadwork (a squad member
    along bonds) and the harbour's Net Haul from T0, Mitts and the Heavy
    Bag at T1, the Slip Bag at T2, Shadow Rounds at T3 against a Scout
    Book pattern's ghost. A slot pays its range at the minigame's grade,
    x1.25 / x1.5 at T2 / T3: the Beans the Forge spends.
  - The Ring: the spar's lab flags at T1 (an authored bout keeps its own),
    the Exhibition 2v2 at home at T2, the ranked spar board at T3.
  - The Film Room: the Scout Book's shelf (6 pages, then 12 / 24 / 48 - a
    page past it waits, and its PI 3 with it); the grind's rungs sooner at
    T2; the tape at T3 (a corner that has run a decoy seal on the club is
    read on sight).
  - The Wall: two card columns more at T1, four from T2; the honours set
    at T2 (a blessed house's crest, a feat's plaque); the Forge at T3.
  - Front of House: the entrance at every dual's bell (a sting, a banner,
    the chant; the Reyes bell by its quest); a hosted dual's crowd from 20
    at T2; 5 Prestige from a hosted dual at T3.
- The ledger keeps the tiers, the training day and the tape; the PI ledger
  keeps the shelf. The save writes `club.facility_tiers`, and its Scout
  Book pages are the shelf's.
- The greybox:
  - DUAL OVER's THE OLD GYM lines (each track's next tier and price, or
    what it waits on; the training slots; the shelf), `[1]`-`[5]`, `[T]`;
  - the RENOVATED, TRAINING, ENTRANCE, SCOUT BOOK, SPAR and EXHIBITION
    toasts; HOSTED on the fight's line;
  - `-- facility=`, `-- host=home`, `-- train=`, `-- renovate=`,
    `-- demo facilities` (a day turns at each dual's end).

## PAC-088 in the build: THE EXHIBITION 2v2 (NP_01 s8, NP_05 s7)
- `formats.v1.json` (both copies) gains `exhibition_2v2`: one segment, two
  dressed a side, `simultaneous`, no Golden DROP, `sync_ms` 500,
  `partner_answer_ms` 250, `manager_duo_bar` 90 - no rotation (F9 never
  cycles into it). `economy.v1.json`'s Lv4 Duo carries `exhibition_duo`.
- The model: `sim/exhibition.gd` (new) runs two engagements in lockstep,
  one per pair - A, the first card against the boss asked for; B, his
  partner against the enemy's second. Each is a whole sim (the sim is P
  against B in every rule; a four-body sim would re-plumb all of it). Each
  holds the pair on its card, so the bonds read them side by side.
- What the coordinator shares:
  - one ledger (the same reward and Pattern Intel dictionaries);
  - one team bar, one enemy bar, one crowd (each engagement's change
    summed and written back);
  - one ring clock (it runs while either pair fights);
  - Two-Hand Winter's gauge (one wall dictionary behind both, run by the
    pair that raised it).
- A pair KO'd is finished; the other fights on to the bell. Both over, the
  ladder on the sums (score, segment wins, counters; a tie a DRAW) pays
  once, as a dual.
- The duo sync: LB + the uppercut flick (Double Overtime) or LB + block
  held 400 ms (Two-Hand Winter) opens a 500 ms window; the other's same
  motion inside it casts the move in both engagements, the bar paying the
  caller's price once. A profile answers at 250 ms; unanswered, the held
  motion goes as his own. The bar is the pair's call (held in a window; a
  profile holds it at 90). Manager mode: the profiles call it at 90.
- The sim: `exhibit`, `bar_hold`, the simultaneous lineup, `_exhibit_end`,
  the shared wall's clock and duo mark, `wall_motion()`, the cast event's
  `duo_sync` fields.
- The greybox:
  - both pairs drawn in their halves of the ring (the lateral compressed),
    the partner's pair dimmed when finished, both gilded as the sync casts;
  - the HUD's exhibition lines (the ring clock, the team score and bars,
    both pairs, the duo sync and its window) and YOUR SHARED WALL;
  - the DUO SYNC / MISSED / TWO-HAND WINTER / PAIR OVER / verdict toasts,
    the other pair's drops on the feed;
  - `\`, F5, F9 and the keys refused in the exhibition (boss switch,
    bouts, a mid-fight save);
  - `-- pair=`, and `-- demo`'s aid (the bar topped up at ticks 600 and
    2,400 once both pairs fight).

## PAC-087 in the build: CROSS-HOUSE HYBRID RESEARCH (NP_08 s6)
- `hybrids.v1.json` (vault copy `data/hybrids.v1.json`), a new content
  table: the Forge's price (40 Spirits, 30 Beans), the ceiling (8 a
  save), E07's discount, the composer's rules, the relay's x1.25 and a
  motif word per house. `economy.v1.json`'s Lv5 Sworn carries `hybrid`.
- The requirement: a Sworn pair from two houses, each with a native of
  his house learned - the house's natives when NATIVE, its SECRET with
  his `secret:<NAME>` flag, the native his card carries. One hybrid a
  pair.
- The Forge runs between duals (or before the first bell), paying the
  ledger's Spirits and Beans. With Q-NGUYEN-ROY done (`quest:third_bridge`),
  a pair across E07 forges at Duo for half.
- The output is a T3 hissatsu record unique to the pair:
  - the library's authored hybrid of the pair's two houses while no pair
    has claimed it (Two Rivers, Grain & Snow);
  - else a composed one: the stronger learned native's family and
    damage +0.1 over the T3 floor 2.4, a tag from each house (seconds
    capped at 2), 2100 ms + 100 a tag, the houses' motifs for its name.
    Run on Grain & Snow's parents, the composer rebuilds it field for
    field.
- Either of the pair casts it:
  - relayed between them (the partner fought the segment before): the
    strongest, x1.25 with the partner's afterimage;
  - CHARGED;
  - from an Awakening's hybrid slot (the card's choice of his hybrids,
    `choose_hybrid`).
  It answers its family's motion before the pair's Duo T3, a relay T3
  and the card's own move. Manager mode casts it first.
- The registry is the ledger's, written into the save's
  `hybrid_registry`. It counts casts and dates the debut (the first cast
  in a dual). The save writes the Beans and the card's `hybrid_slot`.
- The greybox:
  - F on the DUAL OVER screen forges the first pair ready; the FORGE
    lines name each pair near the Forge, its hybrid and its price, or
    what it waits on;
  - the matchup card's HYBRID line; the FORGED, HYBRID and HYBRID SLOT
    toasts;
  - the afterimage in both of the pair's elements.
- Greybox aids and controls: `;` is the keyboard's hookercut (the
  HAYMAKER motion); `-- purse=`, `-- forge=` and `-- demo hybrid` (the
  bar topped up once a segment while a hybrid is live; the log's corners
  keep the sealed order and never hold the bar).

## PAC-086 in the build: THE ENEMY'S TRANSFORMATIONS (NP_09 s1, s4, s7)
- A boss transforms only where his pattern authors it. The PBN grammar's
  new line, `TRANSFORM @ <cond>: <tier> ["<manifest name>"]
  TELL(<motif>, <ms>ms) "<line>"`, compiles into the pattern's
  `transform` block. The compiler's rails: a tier a boss can cast (the
  Zone or the Manifest), a tell at the ARMORED floor (1000 ms), a
  manifest named, one line per boss. `--margins` lists the
  transformation tells beside the strings'.
- The roster's one authored line is Ioan Vasile's "T4 usage at the 50%
  mark" (NP_04B s24): his Zone under 50 % composure, told by his held
  breath for 1500 ms, with Vey's call as the line.
- The trigger is the phase vocabulary, checked between his actions
  (never mid-string), once per boss per dual. He gathers: the tell runs
  on fight time behind his guard, the line is said, and he neither
  attacks nor answers a hook. Then comes the shared 2.5 s camera hold,
  his bar is emptied, and his tier runs:
  - his Zone, 20 s: his timers at 1/0.75 outside his tells (his tells
    keep C4's floors), his acting +15 % on top, the first player punch
    of every 3 s slipped, his stamina frozen;
  - his Manifest, 30 s: his damage x1.4 (punches and hissatsu), his
    clean punches echoed on the player at 0.3 s for 30 %, his DISPLACE
    x2; no meter (a boss casts by composure).
  His Comedown is the shared one, 10 s at 85 %: the player's window. His
  transformation ends with his segment.
- Weathering (s7) is the player's alone. Each perfect block, each slip
  (his own dodge or his Zone's auto-slip) and each Clash exchange won
  shaves 1 s off the boss's transformation. Once one has, the boss's
  damage is halved for the rest of it.
- Stood in the Storm is a feat on the reward ledger (`rewards.feats`:
  the count, the day, the boss), and the save carries it. It is earned
  when the transformation is weathered to its end, the player never
  transformed while it ran, and he was never knocked down.
- The Manifest Clash (s4) runs whenever both fighters are manifested:
  the player's Manifest (or his Manifest-Awakening) and a boss's.
  - After the hold the fight stops for 5 s at x0.5: five exchanges, the
    enemy's first. Block or slip on the enemy's cue, punch on your own.
  - Each window is 360 ms either side of its cue (180 at x0.5); a press
    outside it loses the exchange.
  - Three exchanges win it: the winner's manifest ends the loser's, into
    the Comedown. Each exchange won weathers. The clocks wait.
  - Manager mode's card presses on the cue six times in ten; the pad
    does nothing for it.
- The greybox:
  - GATHERING and the line on the HUD and in a toast, the boss swelling;
  - the boss lit in his element while transformed, with his manifest
    behind him, and dimmed in his Comedown;
  - the HUD's ENEMY ZONE / ENEMY MANIFEST line (the clock, the count
    weathered, the halving), ENEMY COMEDOWN (your window) and the
    Clash's cue line;
  - toasts for WEATHERED, STOOD IN THE STORM and the Clash.
  The strings say "the enemy", not "he": a boss may be anyone.
- Greybox aids: `-- btransform=TIER@TRIGGER[@name]` authors a line on
  every boss without one, and `-- demo clash` holds the aid's SURGE for
  the enemy's manifest.

## PAC-085 in the build: AWAKENING (NP_09 s6) AND THE SURGE'S CHOICE
- `transformations.v1.json`'s Awakening tier runs, the ladder's summit:
  40 s; every tier of NP_09 now runs.
- The gate, per character: his house's SECRET learned (`secret:<NAME>`)
  and his Arc 3 trial (`story:trial:<NAME>`); RORY, the protagonist,
  also needs the sealed house resolved (`story:sealed_house_resolved`).
  He must have a prior tier unlocked, since Awakening stacks one.
- It stacks a chosen prior tier at 75 % strength:
  - Zone-Awakening: the world x0.8125, a slip every 4 s, stamina a
    quarter as mobile, windows +150 ms, punches +11.25 %.
  - Manifest-Awakening: damage x1.3, a 37.5-point meter, the echo at
    22.5 %, displacement x1.75.
  - Inheritance-Awakening: the trait's magnitudes at 75 % (a count stays
    whole), a 37.5-point meter, three reads in four misread.
  The form is the card's `awakening_form`, else his highest prior tier.
- For him alone while Awakened, NP_06 s4's caps rise from x1.5 to x1.75
  (the hissatsu's ring product, the traits' multipliers). Every drop he
  scores puts 15 Tension back on the team bar, flat. The hybrid slot
  opens on nothing: no hybrid technique exists (NP_08 s6 is not built).
- The Comedown is the standard one; the stacked tier's own riders
  (Inheritance's scrambled dialect) stay with that tier.
- The SURGE's choice: a card's `surge_tier` makes his SURGE cast a lower
  tier he has unlocked (the highest by default). Both choices are made
  between duals (`choose_surge`; the greybox seeds `-- surge=` and
  `-- form=`), and the save carries them. The matchup card's SURGE line
  names what his SURGE casts.
- The greybox lights the ring in his element and the fighter at his
  brightest, beside the stacked tier's own figure; the HUD's AWAKENED
  line, the refund's toast.

## PAC-084 in the build: INHERITANCE (NP_09 s5)
- `transformations.v1.json`'s Inheritance tier runs: 25 s of the source's
  house style, then the Comedown with the caster's own dialect scrambled
  10 s. `economy.v1.json`'s Lv5 Sworn carries `inheritance`.
- The SURGE casts it when the fighter has a source, in this order:
  - a story-flagged legacy (`legacy:<id>`, an authored gift; the
    departed coach's slot is empty until the content lane writes whose);
  - a stablemate of another house at Sworn, the deepest bond first;
  - a dual-house card's own second house (`house2`, NP_07 s5's marriage
    line), at 75.
  Inheritance sits over the Manifest and the Zone, so a fighter with a
  source always inherits; one transformation per fighter per dual.
- The source's house trait runs beside his own. A stat trait (Debt of
  Honour against a feud, Long Winter in R4/R5) scales his stats while he
  wears it and gives them back.
- The source's natives (a stablemate's unlocked set, the move he carries
  first; SECRETs excepted) answer their own motions after any open T3 and
  before the card's own move, WALL natives on the WALL motion, paid from
  a private 50-point meter. The card's own move and the relay still pay
  the team bar.
- The source's dialect: every read the enemy makes of his punches is a
  misread (no dodge, no guard). His own stats, style and house rings
  stay his.
- The Comedown adds 10 s of his own dialect scrambled: a feint he sells
  draws nothing.
- Manager mode never SURGEs on its own; inheriting by the manager's call,
  the card casts the strongest native the meter can pay.
- The HUD's INHERITANCE line names the source, the trait, the meter, the
  natives and the misreads. The greybox draws the source's ghost-frame
  over the caster (grey for a legacy) and a dressed source at the apron.

## PAC-083 in the build: SPIRIT MANIFESTATION (NP_09 s4)
- `transformations.v1.json`'s Manifest tier runs: 30 s; all damage
  x1.4; hissatsu paid from a private 50-point manifest meter instead of
  the team bar; the manifest's echo of every clean punch 0.3 s later for
  30 % of it; displacement x2; NP_09 s1's Comedown after it. The Manifest
  Clash is named and not run (no enemy manifest exists to clash with;
  it runs since PAC-086, with an authored enemy Manifest).
- The same SURGE casts the highest tier the fighter has unlocked, the
  Manifest over the Zone, and one transformation of any tier is his for
  the dual. A named character unlocks his by his own Arc 2 flag
  (`story:manifest:<NAME>`); a generic stablemate (a card marked
  `generic`) by level 35 and his Zone mastery flag
  (`mastery:zone:<NAME>`), taking his element's generic manifest. The
  named figures are the content lane's; until one is authored the tier
  runs as "<NAME>'s manifest".
- x1.4 is every composure hit he deals: his punches, clean or chipped
  through a guard, and his hissatsu's damage packets. The meter pays each
  move's own price (the CHARGED half and the element edge as ever); SAVE
  THE BAR does not hold it, a cast broken in its window gives half back
  to it, and what is left leaves with the manifest. Short of the price,
  the motion throws its punch - the team bar, filling again for the next
  fighter, is not touched. The echo lands whatever he does in the 0.3 s;
  a drop or the segment's end cancels it, his timed wall stops it, his
  gauge takes it by the punch's own source; it earns no Tension and
  scores nothing. His DISPLACE packets knock twice as far.
- Manager mode still never SURGEs on its own; manifested by the
  manager's SURGE, the card spends the meter, since it leaves with the
  manifest. The HUD's MANIFEST line (its clock, the manifest, the meter,
  the echo, the multiplier); the greybox draws the figure as a tall
  translucent capsule behind the fighter in his element's tint, pulsing
  on each echo.

## PAC-082 in the build: IN THE ZONE (NP_09 s1, s3)
- `transformations.v1.json` (vault copy `data/transformations.v1.json`):
  NP_09's shared rules and its ladder above the hissatsu - In the Zone
  runs; Spirit Manifestation, Inheritance and Awakening are named and not
  run (the Manifest runs since PAC-083, Inheritance since PAC-084,
  Awakening since PAC-085).
- The SURGE (H + Y; the pad's LB + both sticks) spends the whole team bar
  - 100, the FULL RELAY's 75 - and empties it, on a fighter at level 20
  with the Provincials' flag (NP_12's Zone unlock), once per fighter per
  dual; refused otherwise, naming why.
- Its cinematic is a 2.5 s camera hold the whole world waits out, so
  nothing interrupts it. Then 20 s of fight time: his timers at x0.75 (the
  flash window's slow-time, stacked), the first incoming punch of every
  3 s slipped automatically, stamina frozen where it stood, every counter
  window +200 ms, punches +15 % speed. Then the Comedown: 10 s at 85 %
  stats, stamina moving again. Both end with the segment.
- Manager mode never SURGEs on its own - the bar is the player's
  commitment - but the SURGE passes through delegation. The HUD shows the
  Zone's clock (and the next auto-slip) or the Comedown's; RORY is lit in
  his element in the Zone and dimmed in the Comedown.

## PAC-081 in the build: THE RELAY'S OWN T3 (NP_05 s6-s7)
- NP_05 s6's "T3 moves unlocked for their segment" is true in play:
  whoever enters CHARGED has the relay's T3s opened, whatever his card
  carries - the library's `relay:charged` moves (Coast to Coast, Aurora
  Chain) and, on a FULL RELAY only, North Star (`tactics.v1.json`'s
  `relay_t3_opens` / `full_relay_t3_opens`). Until now only a card that
  carried a T3 could use the unlock, and none in the club does.
- Each answers its own family's motion (HAYMAKER, ARC, RISE) while the
  bar can pay it, the previous fighter's afterimage joining; below that
  the card's own move answers. A Duo's named T3 stands in for its base
  (Whiteout for Coast to Coast). A stolen CHARGED (Borrowed Blood) closes
  them; the Duo, the bond's, stays. North Star is the FULL RELAY's even
  on a card that carries it.
- Manager mode casts the Duo's first, else the open T3 with the most
  damage in it (its multiplier, the chain's links, the element's spike).
- The feed (RELAY ::), the matchup card and the whiteboard name what the
  relay opens. The demo no longer hands PRIYA's card North Star; `-- demo
  seg2` seeds a FULL RELAY so the relay opens it.

## PAC-080 in the build: THE DUO (NP_08 s5.2 Lv4, NP_05 s7)
- The relay T3s carry their Duo variants in the library (`duo_variant`,
  built by `tools/build_hissatsu_library.py`, checked by
  `tools/hissatsu_audit.py`): Coast to Coast names five pairs, Aurora
  Chain one; North Star stays the chain's move. `economy.v1.json`'s Lv4
  carries `duo_t3`.
- A Duo pair (Kizuna Lv4) relays a named T3: the second of the pair out,
  the first having fought the segment before, carries the pair's T3 for
  that segment - Whiteout for RORY and PRIYA, Freeze-Up for RORY and JUNE;
  an unnamed pair takes the relay T3 of the element both carry (two FROST
  cards: Aurora Chain), else Coast to Coast, named "{base} - {A} & {B}".
- The bond unlocks it, CHARGED or not; CHARGED still halves the first
  cast. LB + its family casts it while the bar can pay it; below that the
  card's own move answers the motion. It hits as its base; the variant is
  its name, its VFX and camera ids and the partner's afterimage (gilded in
  the greybox). Manager mode casts it before the card's own move.
- The feed and the matchup card name it at the segment's load; the
  whiteboard lists the DUO RELAYS an order holds. Bosses keep no bonds.

## Verification (agent-run, headless Godot 4.3, this container)
```
godot --headless --path engine/greybox -- smoke boss=N   # N = 0..23
godot --headless --path engine/greybox -- determinism
godot --headless --path engine/greybox -- geometry
godot --headless --path engine/greybox -- audit    # NP_11 s10; exit 1 = RED
godot --headless --path engine/greybox -- faucets  # NP_11 s6; exit 1 = RED
godot --headless --path engine/greybox --quit-after 3600 -- demo
python3 pbn_compiler.py --margins
```
- SMOKE: 454/454 GREEN on every one of the 24 bosses (10,896 assertions).
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
  RFX 99), the PAC-063 gates (the 24 objectives with a known form each,
  the 30s cap, no meter, no corner, SCR-24 offered / refused by the
  opponent's corner; the cap judged on EP both ways; every form fired at
  its count and never early - 3 body shots at the third, a counter, three
  counters, the CENTER exchange and not the off-center hit, the guard
  break, two perfect blocks, the scramble, the stepping punch from 2.15m
  and not from 1.4m, two slipped misses and not a whiff from range, the
  Loud interrupt and not a Standard one, the ladder in order, survive 20s
  on the tick and a drop failing it, the trap at 3s and not 2.99, first
  blood both ways, the flag-reset streak, the unblocked corner escape,
  the House read for kowalchuk and not tremblay, the coach shout; the
  finishers right and wrong; the four constraints broken and holding, the
  cap paying the held one; the spar's 50 cap, T4 lock, infinite stamina,
  outlined tells, no corner and the EP verdict; Ep1's four bouts by name
  with their cards, the trial gone the distance, end_bout back to the
  mini), the PAC-064 gates (the rungs as the table reads and every dialect
  of the 24 with an authored habit; the dialect key by House / own id /
  card; the scrap track at the count and not one short, a lost scrap paying
  nothing, the cap won on EP paying one, the real path counting; the spar
  track and the dual segment to PI 2 at once; the boss track - beaten on EP
  or by KO, his page, Moira without one; PI 2's +10% on Yuri's tell and not
  on Ada's, the cue, PI 3 no wider, his selected tell at +10%, the other
  windows untouched; the commentary at PI 1 and not PI 0, the cue on the
  line at PI 2, the fallback habit; the profile reading 172 / 199 / 228 of
  300 tells at PI 0 / 2 / 3; the ledger paid by SCRAP 1 vs the school,
  kept through end_bout and new_dual, and in the hash), the PAC-065 gates
  (the block across the 24 - every pattern breaks somewhere, 34 hold, the 8
  ARMORED never break, the responses parsed, 'his special' by data; a
  string the block tags breaks and its untagged twin holds on every boss;
  only a jab breaks; Ada's stagger + desync + the widened tell + the
  phase-2 shortening, Vey's 700; Yuri's phase 2 executing three lines with
  the original untouched, Tam's retire, Moreau's floors and movement, the
  21 / 26 split; the floors under tighten; Yuri's rematch over a copy with
  '' restoring the original and every authored remix loading; the delay
  feint's tell / hitch / late haymaker, 0% straight, still breakable; Moira's
  cancel into Left Hook; burn after three; Carter's new string and tighten,
  Moreau's phase_shift firing at 65%, Tam's phase 2 keeping S1, the remix's
  own page; the profile with the page never jabbing Coupling), the PAC-066
  gates (47 / 0 directive lines and the META bases; Ada's metronome and
  Chiamaka's tempos measured between strings, before and after the phase;
  Vane's and Cal's tier shifts, Cal's dialogue and his phase-3 drift;
  Alfie pulling at two warnings; Vey's two kit turns and Vasile's clock
  kits with the seam and the finale; the Cartographer's two dialects and
  Echo's splice after the 2nd then the 3rd; Carter's hook, Deshawn's fifth
  hit, Osei's and Marta's state durations and Marta's cooldown; Remy's
  dialogue, Sora's nothing, Baro's halved cooldown), the PAC-067 gates
  (pattern_coverage with nothing carried but the IDLE lines; Yuri's
  after-hit transient and its expiry, the rope strings on and off the
  SELECT, Marta's patience line; the clock speed lines and Alfie's push;
  the PI transfers by kit and the extraction's half, the Cartographer
  stripped and half-blank; Deshawn's 150ms, Reyes' 30 of 40 to the body;
  Osei's 0.70 with the stumble, Baro's gate held then opened; Cal's assist
  and Vasile's two corner calls at 28s and 58s and none for Vey), the
  PAC-068 gates (the empty ledger and the level curve; XP from two hits, a
  counter and a DROP credited with +25 and the houseless 10% at the
  segment's end, a segment lost paying the events alone; SCR-01 won three
  times paying 17 XP and +2 Prestige with the third toast naming the PI
  tick, a lost scrap's trickle, a tier-3 objective at the cap; the spar
  fought and won, the lab's half, six stablemate spars to the daily cap and
  a new day; the dual's per-segment and closing XP, the bench's 50%,
  Spirits, HBP and the adjacent pairs' +8, a lost dual's +5; Corner Voices
  +2%, Adjacent Trust +5% and the CHARGED threshold 20, the non-adjacent
  Lv3 pair at +2%, the five level thresholds, the ALLIED x1.25; the
  level_up event, the ledger kept and hashed), the PAC-069 gates (the
  SaveGame's every schema key with the stable's level / xp / bonds, the
  currencies, the Scout Book and the remix from the ledgers, the sim's
  hash untouched by the writing; the round trip byte-equal with the
  ledgers' ints and the rematch live from the bell; the ledgers through
  three scraps, a stablemate spar, a segment won and a new day; a
  DualState at tick 3,000 restored into a sim built on another boss,
  seed, roster and format to the same hash and run to 5,000 in step with
  the unbroken run; the readable fields as NP_11 s9 names them; the
  refusals naming why; the content stamp unchanged by 5,000 ticks; the
  file written to user://, read back and resumed), the PAC-070 gates (the
  63-piece library, every verb parsing and every hook keyed, nothing
  shared with a named string; the rules over 48 assemblies with every
  response known and nothing carried under pattern_coverage; the same
  spec byte-equal twice, eight seeds eight assemblies, the name's hash as
  the seed; the knob's bands, floors and stat blocks; a spar against a
  generic card with his strings told, his hook answering, his opener
  breaking, three scraps paying and ticking his dialect, SCR-09 refused;
  Ep1's four cards on strings of their own; a filler in R1 ticking its
  dialect, booking no page, paying, R2 named again, the hash by seed; a
  dual with a filler snapshotted and restored on the same hash), the
  PAC-071 gates (41 verbs for the 52 IDLE lines, 49 executed, 3
  presentational, nothing carried; eleven walks' closing speeds and the
  ranges they stop at, the shared approach for a frozen boss and for a
  generic, the lead against a strafing player; seven orbits' speeds and
  directions and their reversals, who steps back out to range; Ada's and
  Chiamaka's beats tick for tick, Tam's angle and its switch; Vasile's
  band, Vey's mirror, Cal's centre, Moira's ring cut; the authored guards'
  rates, the wobble and the composed, Sam walking in, a 600-jab sample on
  Osei's shell; the taunt clocks with a jab landing in one and the next
  string held, Tam's four tempo flips and his gaps by tempo; the footwork
  flags, Reyes' bell, Remy named in a blind dual), the PAC-072 gates (the
  approaches and the eight cards' profiles and lines; the plan to Priya
  landing at PWR 36.75 for her segment and gone for Marcus's; the arm
  missing with the state hashing equal to the dual where nobody talked,
  and every card with one read that lands, its own; the refusals; the
  talk bound to Priya and unheard when JUNE goes out, JUNE's own talk
  landing; the hint from Gymmates and Corner Voices, the best bond
  speaking, an undressed bond silent; the save carrying the profiles and
  a corner restored with its talk), the PAC-073 gates (the formation
  data and the decoy rates; the four orders on the mini and the
  sanctioned boards with the ace and the anchor read off the cards, a
  raised PWR moving the ace, the ladder chaining a bonded trio; the board
  sealed at setup going out in its order, the same board sealed before
  the bell on the same hash, a card-order board equal to none; nine
  refusals naming why and changing nothing; the corner's swap after the
  seal, the DualState's sealed and revealed, a scrap sending the first
  card, the save dressing the board back; Ep1's 70%; each source by its
  own amount, the cap, the blind dual, the read fixed at the bell; the percentage honest over 1,200
  slots at 70% and at 40%; the decoy in about half of Vey's 400 duals,
  every name wrong at the honest percentage, the fight the same to the
  hash, a Lv1 tactician fooled and a Lv3 reading it; the overlay on the
  Ep1 board, the worked example 2, and equal to the matchup card at ten
  bells), the PAC-074 gates (the staff data and the default three; the
  board dressing the corps by staffer or active, two cutmen pooling four
  charges credited in turn, four refusals; Lv2 at the third Reveal and
  Lv3 at the eighth, the earned Lv3 reading Vey's decoy; the cutman's
  +15 / +30 / Lv3 +10 on RORY's carry in the Iron dual; the conditioning
  coach's x1.1 / x1.3 regen and the Lv3 overrun at 90; the crowd's six
  sources bare and x1.2, Raise the Roof cold and hot, the Lv3 hype's 10;
  the Professor's doubled PI in a dual and at Lv3 in a spar, the richer
  page, two tacticians; the save's ten Staff records and the dressed
  three back after a load), the PAC-075 gates (the 25 records, every
  boss covered, the grammar split sim / overworld, the new cards; a
  dual won flagging the squad's recruitables, a dual lost nobody, the
  cap of four and Dex with Moira; the approach surfacing the condition
  and three refusals; ADA refused naming her unmet clauses, YURI joining
  undressed and fighting R1 once a board dresses him; every form against
  its ledger - Marta's spar by an Out-Boxer only, Dex then Moira through
  his bond, Carter's three scraps and REP 3, Tam's PI and spar, Vane's
  WITNESS, STAT_PROOF, STYLE_PROOF, an unknown form never met; the save
  of the whole stable and the recruit ledger; every content table outside
  the snapshot and inside the stamp), the PAC-076 gates (the wall's six
  maps, 43 cards and 42 strings, every one checked against the recruit
  table, the feud graph and the grammar, the three BOND strings; family
  both ways - CARTER turning up ADA, NNEKA, CHIAMAKA and his house, ADA
  signed through her string, REMY turning up JEAN-GUY who signs once E05
  closes; master one way - SAM turning up the junior and CHOIR, CHOIR
  signed turning up nobody; the house - YURI's barn without the cousins,
  the Kowalchuk blessing with them and House Whitecloud but not House
  Reyes, the Moreau blessing to House Iron and Vera but not House
  Tremblay; the view, the lines and the save written, loaded and written
  again byte-equal), the PAC-077 gates (the fourteen houses and twelve
  lines, the graph's flips; the Kowalchuk patriarch witnessing the second
  dual and blessing YURI into NATIVE; Tagaq refusing the dual with crowd
  heat converted and blessing on the next; Petrov's own-moves proof over
  Vane and not over Yuri, not mixed, not without a cast; the Reyes code
  voided at 100 stamina, standing at 30, broken before the blessing; Efua
  around her family, UNSANCTIONED at x1.300 and sanctioned at x1.430 with
  her natives equipped and a SECRET refused; E05 ending the Moreau-Tremblay
  feud, E11 refusing, E02 waiting for both final beats, E04's bond x1.25;
  the codex, the graph and the Fighter records saved and loaded
  byte-equal), the PAC-078 gates (the nine traits and who carries them -
  blood only, the variants named; Never Twice on both corners and back
  after a new dual; Deep Roots x1.5 while trailing and kept UNSANCTIONED;
  Long Winter in R4, Debt of Honour against a feud and gone when E02
  flips, an Iron doubled; First Frost's opening 100 ms; Harvest's +1 on
  both sides; Load-Bearing on the ropes and in the corner; Tide
  Discipline's floor on both sides; Open Door x1.5 and never on top of
  ALLIED; the traits at the bell, the codex and the Fighter record), the
  PAC-079 gates (the wall's data and the default layouts of the four and
  the eight; pins refused off the wall, on a taken cell and for a card not
  in the stable, a decoration moved and refused; the suggestion RORY -
  MARCUS - PRIYA from the cards pinned down the wall, the card order kept
  until it is sealed, an Ambush board standing, no suggestion after the
  bell, the sanctioned five and their tie; the lines at 20 %, half way and
  gilded, the locker of a two-cell wall; the poster, the stub once a club,
  a polaroid per level, the recruits' wraps and ADA beside CARTER; the
  hash untouched by a rearranged wall over 1,200 ticks; the save written,
  loaded and written again byte-equal), the PAC-080 gates (the variants
  and the named T3s of a named pair, two FROST cards and a pair sharing
  nothing; the level - nothing at 89, Whiteout at 90 and at 150, nothing
  in R1 or across a slot, Freeze-Up for JUNE swapped in, Whiteout for RORY
  sent after PRIYA; the cast - a T3 with no CHARGED relay, RORY's
  afterimage, 45 off the bar; at 89 a punch; RORY's own T1 answering at
  40 and a punch at 20; CHARGED at half; the same damage and push as a
  carried Coast to Coast, plus the afterimage; the profile casting it
  first; the whiteboard's DUO RELAYS; a DualState restoring it on the
  same hash), the PAC-081 gates (the relay's sources; R2 PRIYA out
  CHARGED with Coast to Coast and Aurora Chain opened, not CHARGED none,
  North Star at the sanctioned R4's third link; her HAYMAKER / ARC /
  PISTON / RISE casting Coast to Coast, Aurora Chain, her own Marginalia
  and a punch; RORY's T1 answering below the T3's price; North Star's
  damage x1.2 from three links to four; Whiteout in Coast to Coast's
  place, a stolen CHARGED closing the relay and not the Duo; the
  profile's picks; the whiteboard's RELAY OPENS; a DualState keeping
  it), the PAC-082 gates (the table and the unlock - level 19, no flag,
  both; the SURGE refused at 99, taking the whole 100 and the FULL RELAY's
  75 from 80, the 300-tick camera hold with his timers and the Zone's
  clock held, once per dual, back after a new dual, never in a spar; his
  timers 300 of 400, the punches slipped / hit / slipped 3 s on, stamina
  frozen at 60, the windows +24 ticks, a straight's startup / 1.15, each
  against the same sim without the Zone; the Comedown's 85 % and its end,
  a segment ending mid-Zone; the manager's SURGE passing through and the
  card never surging; a DualState mid-Zone on the same hash), the PAC-083
  gates (the Manifest's table; the tier chosen by the card - a named
  fighter's own flag, a generic stablemate's 35 and mastery, never the
  other's path; the SURGE into the Manifest with its 50-point meter, once
  per dual whatever the tier; a straight x1.4 and its echo at 0.3 s for
  30 %, none on a blocked punch, none left after a drop; the hissatsu
  x1.4 and its displacement x2, each against the same sim without it;
  the meter paying while the team bar at 40 and SAVE THE BAR stand, the
  punch thrown when the meter is short, half back on a broken cast, the
  meter gone with the manifest; the HUD line, the end into the
  Comedown, the card spending the meter on the manager's SURGE, a
  DualState with an echo in flight on the same hash), the PAC-084 gates
  (the table and the sources - Duo nobody, Sworn SAM, the deepest bond
  first, no houseless card and no housemate, a legacy only with its house
  and flag, a dual-house card's second house at 75 after a Sworn bond;
  the SURGE over the Manifest and the Zone with SAM's Never Twice, his
  natives and the meter, MARTA's second house refused at 74 and cast at
  80 for 75, the legacy's gift; the second drop a wobble, Sorry Eh from
  the meter with the team bar untouched while Aurora pays the bar, a WALL
  native on the WALL motion, Debt of Honour's stats given back, 20
  misreads where the control dodged 20, each against the same sim
  without it; the end, the scrambled feint against a Zone's Comedown, the
  manager's SURGE and the card's casts from the meter, a DualState on the
  same hash), the PAC-085 gates (the table and the gate - the Zone only,
  the SECRET and trial without the sealed house, with it, PRIYA's own
  gate, nothing to stack, the form by his tiers and his choice; the
  SURGE Awakened with the Manifest at 75 %, once per dual; the choice
  refused in the fight, a form that is not a prior tier, a tier he
  lacks, carried by the save, back to his highest, the next dual's SURGE
  the Zone; a straight x1.3 against x1.4, the echo at 22.5 %, his timers
  325 of 400, a slip every 4 s, stamina a quarter as mobile, the windows
  +150 ms, 18 misreads against 2 dodges, MARTA's native x1.573 against
  the capped x1.5, a drop +15; the end with no scramble and no refund in
  the Comedown; the manager's SURGE, a DualState on the same hash), the
  PAC-086 gates (the table and Vasile's compiled line; nothing at 51 %,
  at 49 % he gathers 1.5 s with his line through six jabs, no answer and
  no attack, then the hold, his bar emptied, his Zone; once a dual, again
  the next; his timers 533 / 400 / 613 of 400 idle, in a tell and acting
  against 400 without his line, a slip every 3 s, his stamina frozen,
  his Comedown at 85 % for 10 s of fight time, no feat unweathered; a
  Manifest authored on Moira for the test: a hook x1.4 and its echo at
  30 % against her without it, the Undertow's damage x1.4 and
  displacement x2, a drop clearing the echo, an Awakening line never
  gathering; the Clash: perfect 5 of 5 with hers suppressed and five
  weatherings, none and early both lost with his own manifest ended, the
  window's edge and a slip 3 of 5 won, 2 of 5 lost, the clock and both
  manifests waiting, the card never early; a perfect block and a slip a
  second each, the damage halved, Stood in the Storm on the ledger and
  through the save, none if answered or knocked down, a DualState
  mid-Zone on the same hash), the PAC-087 gates (the table, the library's
  two authored hybrids, the learned natives, each refusal for its reason;
  the Forge's Grain & Snow and the ledger paid, the composer rebuilding it
  field for field, a second pair of the same houses under its names,
  Tide & Snow, Two Rivers across E07 at Duo for half, the save written
  back byte-equal; R1 nothing and CHARGED x1, R2 relayed x1.25 before the
  pair's Duo T3, its hit 34.125 against 27.3 unrelayed, the other way,
  across a slot nothing; the Awakening's slot and the card's choice; the
  profile casting it, the Forge's lines and "*", the ceiling at eight, a
  DualState in R2 on the same hash), the PAC-088 gates (the Exhibition 2v2's
  record and Lv4's `exhibition_duo`; the pad on RORY against Yuri, PRIYA on
  her profile against Moreau, the pair on each card, one ledger, Adjacent
  Trust in both; one team bar [55, 55, 55] from 10 and 5 earned in the two
  engagements, one enemy bar, the ring clock running through RORY's own
  hitstop; the duo sync - RORY's call held, PRIYA's answer at 400 ms casting
  Double Overtime in both at 50 once and landing on both opponents, at
  600 ms missed with RORY's flick thrown as his own and PRIYA's late window
  shutting in turn, the other way at 200 ms, her profile at 250 ms, nothing
  at Adjacent Trust; Two-Hand Winter's one gauge behind both, a body hook on
  PRIYA chipping the gauge RORY stands behind, its TRUE OPEN on its owner's
  clock and handed on when that pair is KO'd; the verdict on the sums and
  one pay, a DualState of the whole exhibition on the same hash, F5 again,
  the pad passed and handed back, the manager's call), the PAC-089 gates
  (the facilities' table, the club at T0, a renovation refused for each
  reason and paid, its photograph, "*", the save's tiers written back
  byte-equal; the training - Roadwork as found, Mitts refused, Net Haul by
  its quest, three slots a day, Roadwork's bond, x1.25 at T2, Shadow Rounds
  at T3 on Yuri's page and the Forge paid from the trained jar; The Ring's
  lab flags off as found and the Priya trial's kept, the ranked board at
  T3, the exhibition at home at T2; the Scout Book's shelf of 6 with the
  seventh page and its PI 3 waiting until the Film Room's T1, the grind
  sooner at T2, the tape's decoy read at T3; The Wall's new columns hanging
  the unpinned, the honours set at T2, the Forge refused below T3; the
  entrance by tier and the Reyes bell, a hosted crowd from 20, a hosted
  dual's 5 Prestige), the PAC-090 gates (the four boards of 60 nodes, the
  passives by style, the socket, the named nodes, a node refused for each
  reason and taken, the soft cap and its breaker, respec at the Film
  Room's T2, the socket's rules; each of the nine passives against the
  same sim without it, moving its own number and no other; the typed
  Beans by game and partner, the raises at 5 and 6 on their own Beans
  and the untyped, refused on another stat's and at the cap, the Forge's
  cut, the raise at the next bell; rarity refused on the trial and the
  Spirits, the three trials earned in play, the mirror, the Legend, the
  generic's Awakening flag; the save's Fighter records written back
  byte-equal), the PAC-091 gates (the slots by level, seeded kits cut to
  them at the bell, each refusal, a native beside a full kit; the shop's
  shelves by circuit progress, a buy and its refusals, the quest's tape
  once, a tape spent; Whitlock after a survived standing-eight, the
  questline, the conditioning coach, DEX at Lv2, CARTER on SPD 60; the
  re-teach in three training slots and the fourth refused; the kit's cast
  on its motion, PRIYA's Marginalia locked below level 5, the profile
  casting from the kit, the save's technique records written back
  byte-equal), the PAC-092 gates (the academy as data - fifteen pairs over
  the twelve houses with natives; a synthesis against the club's hybrid of
  the same houses, x2.13 against x2.5, fifteen distinct, all under the T3
  floor; the cast rule at 60 and 40 in his bar, in and out of reach, the
  rotation, the jab in the windup; the matchup's ACADEMY and THESIS lines
  in R1 and relayed in R2, the squad dressed with no named bench, refused
  mid-dual, off between duals; the save's
  settings byte-equal and a DualState after a synthesis restored on the
  same hash), the PAC-093 gates (the record from thrown punches - a feint
  kept once, a counter into a slip's window, the record kept past the
  bell and by fighter; the copy from a seeded record - its strings, SELECT,
  punish, reads and counter, byte-equal in another sim, another record
  another copy, three strings at Circuit, every action a VM verb, no record
  C44's mirror; the lab's flag refused at T0 and fought at T1 with the
  MIRROR line; his read on your sequence at 3 against 0.3, offense
  byte-identical, the reads gone in 24 s, your counter at the rate 1 and
  0; the trial and no PI, the record written back byte-equal, a DualState
  restored on the same hash, the aid there and back, an objective judged
  as any spar's), the PAC-094 gates (the gear as data - the cap, the
  sources, each kind's strongest under its board passive, the house gifts
  by rule; the slots 1 / 2 / 3 / 3 and each refusal, a signature on
  another card, every copy worn, a seeded kit cut at the bell; the shop,
  the story's pieces with their flags, blessings and owners, the festival
  won and not; each kind at the bell against no gear, its own number only,
  Snap and gloves together; the Fighter records, the save byte-equal, a
  DualState restored, the aid), the PAC-095 gates (the audit as data -
  the earliest three, the reference, the endgame's seven, the budget; a
  build on live systems only - tier 4, the board, the raises, the kit,
  the gear, a purse short of the Legend refused; the kit's rule - a move
  behind a cheaper one never answers, the builder's kits hold none; the
  fight the same twice, a seed apart different; the verdict naming each
  system in turn), the PAC-096 gates (the fixes as data; stat totals by
  rarity - PRIYA 370 / 420 / 490 / 490 in her shape, a card over the total
  unmoved, a raise on top, the totals taken out; the defensive board - a
  T2 refused without it, the aid's walk to the Anchor Wall, the lesson,
  the WALL motion raising it, the re-teach refused, the respec; the aid
  at 25 and 35 and its picks unmoved below; the fight the fixes turn),
  the PAC-097 gates (the faucet audit as data; a segment's own XP on the
  one rule - event_xp, a delegated segment paid its events' sum, the
  sample; the faucet equal to the economy table's arithmetic through the
  sim's paths; the sinks priced off a build's ledger; the verdict naming
  all five, GREEN with every bar opened), the PAC-098 gates (the fixes
  as data, the budget the faucet's share; XP's pace - a scrap 45 / 41,
  the reserve at the pace once, the captain at 35 and 21 without it; the
  story's pay - 30 / 50 / 0, refused twice, Remy met by his quest, a seeded
  flag unpaid; the machine and the open mat - refused, nine commons and
  the rare tenth, the priority, the 7th day, the save, Vera Iron; each fix
  against its absence naming exactly its currency), the PAC-099 gates (the
  roles as data and the homes; the roles set - six refusals, the aid's
  picks, back to the ring; each role against its absence - the partner's
  +3 / +1 and nothing unnamed, without the role, at the mitts or dressed;
  the scouts' districts once a day, YURI's +20 on the Grain Kings; the
  trainees' uses to the dressed then the corps, a Lv2 on a use; the roles
  in the save; the faucet's bench), the PAC-100 gates (the release
  against its absence and its six refusals; three days to take it back,
  then settled; the road back and the flag - YURI's grudge spar and
  warmth, the open mat's price; the cap given its valve; the browse and
  the comparison card; the locker in the save), the PAC-101 gates (the
  rep as data and on the ledger - three scraps won in the rink, the
  milestone once; the flee - free before the first exchange, -1 after,
  0 its floor, a spar and a dual refused; REP() on the ledger - Carter
  and the Whitecloud blessing; the rep in the save; the faucet's
  districts), the PAC-102 gates (the anti-you against its absence - a
  beat that turns no arc, the turn once, seeded and without the table;
  a released rival at the academy on RECRUITS and the String Wall; the
  academy's squad with the taken and the displaced kits, mini and
  sanctioned; the academy beaten and the taken come over; the academy in
  the save), the PAC-103 gates (the vendor tiers against their absence -
  DOWNTOWN 9 to 10, the rink's rep, the tables without the rep, a seeded
  flag, the Regionals; a shelf opened on the rep and shut by a flee, what
  was bought kept; the SHOPS lines and the aid off t3 and t1; the tiers
  in the save; the faucet's vendor tiers at story pace and on the Strip
  early), and static coverage: 39/39
  action verbs, 53/53 punish responses, 13/13 phase-trigger forms, 7/7
  effect types, 36/36 states, 14/14 buffs. Every entry in tactics.v1.json
  (8 specials, 4 supers, 5 staff actives) has a gate above; every key in
  affinity.v1.json has one.
- DETERMINISM: 57/57 GREEN. One 24,000-tick scripted input log run three
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
  profile lands 85 and the corners still turn - and hashes identically
  twice. A scrap (survive 20s) on the profile against the live Yuri runs
  to its end and hashes identically twice. The delegated dual again with a
  PI 2 ledger vs Kowalchuk - 27 emphasized tells, the commentary, the
  ledger ticking as segments end - hashes identically twice and differs
  from the ledger-less run. The same log against the remixed Yuri - his
  feint variants told and carried through, his untagged strings taking hits
  in the tell - hashes identically twice and differs from the original's.
  A delegated dual vs Vasile turns his clock kits twice with their seams
  (since PAC-071 with his neutral game frozen - see below) and hashes
  identically twice; a delegated dual vs Vey with the three
  copied houses at PI 2 (the transfer's cues and commentary live) hashes
  identically twice. The reward ledger rides the delegated log (455 XP
  across four fighters, the toasts) identically between its two runs. The
  mini log broken at tick 12,000 by a save to text and a load into a sim
  seeded otherwise continues to the unbroken run's 200 remaining hashes.
  The delegated dual with an assembled tier-3 Slugger filler in R1 (110
  tells of his own strings, five of them the SPECIAL; Kowalchuk ticked
  to PI 2) hashes identically twice and differs from the named run. The
  delegated dual vs Carter's lineup on their neutral games (9 taunts)
  hashes identically twice and differs from the same dual frozen. Since
  PAC-071 the Vasile log is two: live, his measured stance knocks RORY
  out at 63.5s after one clock kit and its seam; the same log with his
  neutral game frozen turns both kits; each hashes identically twice.
  The delegated dual with talks in its corners (3 talks, 2 landed, 2
  segments at +5%) hashes identically twice and differs from the log
  without them, in which nobody talks. The delegated dual on a sealed
  Relay Ladder (JUNE, RORY, SAM, MARCUS, PRIYA; the Reveal at Lv3)
  against Vey's corner - a decoy dual the tactician reads - sends its
  fighters out in the board's order with three Adjacent Trust segments,
  hashes identically twice and differs from the same log on the card
  order. The delegated dual with a staffed corner vs Yuri - the janitor
  at Lv3, the ring announcer, the Professor - starts at 10 Tension, heats
  the building from the fight's own spectacle (to 100), converts it once
  for the log's Raise the Roof calls and refuses them cold, doubles the
  segments' PI (2 per segment end against the default corner's 1), hashes
  identically twice and differs from the default corner. Since PAC-074 the default corner's staff are live (the retired
  boxer's regen, the crowd-gated Raise the Roof), so the delegated logs'
  fights run differently from before and the figures quoted above are
  this build's: the Vasile gate dresses a corner without a conditioning
  coach so his R1 is the pre-PAC-074 fight bit for bit. Since PAC-078
  Yuri carries Load-Bearing, so the delegated logs against his squad moved
  again (the profile's 78 landed became 86, the ledger's 463 XP 475).
  Since PAC-081 whoever enters CHARGED casts the relay's T3s, so every
  log with a CHARGED segment moved once more (the profile's 86 landed
  became 85, the ledger's 475 XP 455, the talks' one landed two, the
  filler's six SPECIALs five, the PI ledger's 25 cued tells 27); the
  figures above are this build's. The same delegated log against Yuri's
  squad opens the relay to R2 PRIYA and R3 JUNE, and JUNE casts Aurora
  Chain with PRIYA's afterimage; it hashes identically twice and differs
  from the log with the relay's T3s closed. The scripted log against
  Yuri's squad with the four at level 20 and the Provincials' flag, the
  bar topped up at tick 3,000 and RORY SURGEing: the camera hold, the
  Zone's auto-slips, its end, the Comedown's end; it hashes identically
  twice and differs from the same log with the bar topped up and no
  SURGE. With RORY's Arc 2 flag seeded as well, the same SURGE casts the
  Manifest: nine echoes landed and one cast from the meter before it
  ends; it hashes identically twice and differs from the Zone's run.
  With SAM in the club and Sworn with RORY instead, the same SURGE
  takes SAM's House Tagaq style: six misreads and one cast from the
  inherited meter before it ends; it hashes identically twice and
  differs from the Zone's run. With RORY's SECRET, his Arc 3 trial and
  the sealed house resolved as well, the same SURGE Awakens him with the
  Zone stacked at 75 %: ten slips and two drops refunded before it ends;
  it hashes identically twice and differs from the Zone's run. The same
  log against Ioan Vasile: under 50 % he gathers at tick 1,546, his Zone
  from 1,731; the log's defence weathers it six times; it ends at 3,731
  unanswered with Stood in the Storm, and his Comedown ends at 4,986; it
  hashes identically twice and differs from the log with his line
  stripped. Since PAC-086 his line stays unrun on the four Vasile
  neutral-game logs: that gate watches his clock kits, bit for bit as
  before. YURI and MARTA Sworn and forged on the delegated log against
  Yuri's squad, out R1 and R2 with the bar topped up at tick 3,100: the
  profile casts Grain & Snow relayed with YURI's afterimage, its debut
  once; it hashes identically twice and differs from the same log
  unforged, where the pair's Duo T3 answers the motion. The Exhibition 2v2
  on the delegated log in the manager's seat, RORY and PRIYA at Duo
  against Yuri and Moreau with the bar topped up at tick 600: the profiles
  call Double Overtime and both halves cast it, and the exhibition runs to
  its verdict; every hash of both engagements and the coordinator is
  identical twice and differs from the same log at Adjacent Trust, where
  no duo is live. A hosted dual on the delegated log against Yuri's squad
  with every facility at T3 - the entrance at each bell, the crowd from 20
  at each hosted bell, 5 Prestige from the hosted dual - hashes identically
  twice and differs from the same log away. (Since PAC-089 the save-and-load
  line reads 216 KB: the save carries `club.facility_tiers`; since PAC-090
  217 KB, each Fighter record carrying its growth; since PAC-091 218 KB,
  with its techniques; since PAC-093 239 KB, with the tracker's record in
  the ledger and the DualState. The T0 at level 5 also moved seven lines'
  figures: level-1 PRIYA and JUNE no longer cast their T0s.) The fighters' growth on
  the delegated log against Yuri's squad, the log twice over: the aid grows
  the four cards before the bell (each board to its first passives, RORY
  to Circuit on his trial) and between the duals (the log's `grow`), and
  every hash is identical twice and differs from the same log and ledger
  with no growth. A taught kit on the scripted log against Yuri's squad
  (RORY at 15 with Snowblind, Root Bind and Cornerstone, MARCUS at 5 with
  Updraft, the aid teaching between duals) casts from the kit on the log's
  motions and hashes identically twice, differing from the same log with
  no kits. The academy fielded on the delegated log (ASCENDANT 1-3 in
  Director Vey's corner, the squad the academy's to the log's end) casts
  its syntheses from the prodigies' bars and hashes identically twice, differing from the same log against Yuri's
  squad, where none is cast. The mirror on the delegated log: the dual
  against Yuri's squad records how each card fights; between duals the
  aid spars RORY's mirror on that record (his sequences its strings, his
  counter thrown back) and goes back; identical twice, and different from
  the same log without the aid. Gear on the delegated log against Yuri's
  squad: the aid dresses the cards before the bell and between duals (the
  Regionals Robe from the locker, the shop's picks for the rest); identical
  twice, and different from the same log undressed. The obsolescence
  audit reduced: DEX built for the endgame and fought against Alfie Crane
  and Ioan Vasile, identical twice to the last number, a seed apart
  different. The audit's fixes: PRIYA built (the Legend's 490, the board's
  wall in her kit) and fought against Chiamaka Okafor, identical twice,
  and different from the build with the totals taken out. The faucet/sink
  audit reduced: its sample spar and Arc 1's first phase, identical twice,
  a phase one episode longer different. The scouting machine on the
  delegated log vs Yuri's squad: the aid pulls between duals and signs the
  open mat's first; identical twice, different without the machine. The
  stable roles on the same log: the aid pulls three, signs them, trains
  and turns a day between duals, and sets the bench to work; identical
  twice, different without the roles. The locker room on the same log:
  the aid also releases the bench's last; identical twice, different
  without the releases.
  District rep on the log: SCR-15 on the profile in the Rink District
  (5 on the ledger) - won 6, fled at tick 600 4, placed nowhere 5; each
  identical twice, the three different.
  The anti-you on the delegated log vs Moira's squad: the approach on
  every tick between duals, the Nationals turned, the academy fielded -
  it signs MOIRA, DEX and REMY and fields them; identical twice, different
  without the arc's turn (nobody signed, the academy unfielded).
  The vendor tiers on the log: SCR-15 on the profile with DOWNTOWN at 9
  and 600 HBP - won downtown, the aid's gear comes off t2; placed in the
  rink, off t1; each identical twice, the two different.
  The delegated log against Moira's squad (the dual the log wins, on segments) with the
  approach and the recruit on every tick between duals and Remy's quest
  flag seeded (cold_storage) flags four, surfaces five conditions (the
  fifth JEAN-GUY's, through Remy's string), recruits Remy, hashes
  identically twice and differs from the same log without the approach.
  With E05 closed too, E05 flips before the bell and Moreau's line is met:
  the Moreau blessing turns up JEAN-GUY and REMY (House Tremblay across
  the flipped edge, House Iron with Vera) and the dual's tick signs both;
  it hashes identically twice and differs from the log where E05 is open
  and JEAN-GUY waits on Remy's string. On a ledger from an earlier session
  (YURI signed, a segment won against him) the same log is the home dual
  the Kowalchuk patriarch attends: the house blesses the club at the
  dual's end and YURI is sanctioned; it hashes identically twice and
  differs from the ledger without YURI's signing, where the crest is down.
  YURI, SAM and MARTA against Carter's squad carry their traits into the
  log (Carter's and Chiamaka's Harvest on his side, a Never Twice wobble)
  and it hashes identically twice and differs from the same log with
  every trait taken out. The Gym Wall's board on the delegated log
  against Yuri's squad (MARCUS pinned under RORY and PRIYA under him, the
  suggestion R1 RORY, R2 MARCUS, R3 PRIYA sealed) hashes identically twice
  and differs from the card order's run; the same order sealed by hand
  hashes the same, and so does the run with the wall rearranged and three
  decorations more (zero stats). RORY and PRIYA at Duo on the delegated
  log against Yuri's squad: Whiteout live in R2 and cast by the profile
  with RORY's afterimage; it hashes identically twice and differs from
  the same log at Adjacent Trust (89), where the stats are the same and
  no Duo is live (PRIYA, out CHARGED since PAC-081, casts the relay's
  plain Coast to Coast).
- AUDIT: GREEN, 3 of 3 viable (since PAC-096): PRIYA 11 of 14 segments,
  DEX 14 of 14, YURI 14 of 14, every kit 4 of 4 slots answering. PAC-095's
  run was RED, 0 of 3 - the finding, not a failed gate: techniques
  (NP_11 s2, s8) for all three - four slots at level 35, three learnable
  families left beside the card's own move, so the fourth never answered
  - and growth (NP_11 s3, s6) for PRIYA, 3 of 14 segments, her total 17%
  under the reference's. PAC-096 fixed both.
- FAUCETS: GREEN since PAC-098 - Spirits 58%, HBP 72%, Beans 68%,
  Prestige 85% of the wanted (81% before PAC-099's bench, 83% before
  PAC-101's rep milestones - the band's edge), a session paying Spirits
  7.7, HBP 118, Prestige 14.8, Beans 9.6 a slot; RORY at level 35 by Arc 3; the
  obsolescence budget (110 / 140 / 1,700) funded for its three. PAC-097's
  run was RED, all five currencies named - the finding, not a failed
  gate. A story-pace playthrough to Arc 3 pays Spirits 900, HBP 3,040,
  Beans 770 and Prestige 1,140; RORY stands at level 21, not NP_11 s2's
  ~35. HBP 23% of the 13,150 wanted (quests and the story pay nothing on
  the sim), Spirits 86% and 11.2 a session (NP_11 s6's 3-8 a session;
  the table pays 3-8 a fight), Beans 93% of the obsolescence jar's 830,
  Prestige into no live sink. The obsolescence audit's HBP (9,000 for its
  three) and level (35) are not what the faucet pays. The fixes are
  PAC-098's.
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
  With the economy live, 16,000-frame soaks on the profile of Ep1's SCRAP
  1 three times over (two wins paying "SCRAP: 17 XP, +2 Prestige" each and
  a loss paying 6: 40 XP and 4 Prestige on the ledger), the Priya trial
  twice over ("SPAR: 33 XP, 5 Spirits, RORY+PRIYA +3, PI tick vs Cassidy
  Vane" - her card is a stablemate's), a seeded RORY+PRIYA bond at 50
  (three kizuna_effect events, RORY 76 XP after R1) and the sanctioned
  format through three segments (RORY 52 XP, JUNE 8) all ran with zero
  errors. With the save live, `-- demo boss=1 saveload` saved at tick
  3,000, ran on to 3,600, loaded the file back to tick 3,000 on the same
  hash and ran the rest of its 16,000 frames; `-- demo load=user://
  tnb_save.json` resumed that file at the bell (R1, 71.7s on the clock)
  and a missing file was reported, not loaded; zero errors. With the
  assembler live, `-- demo boss=1 generic=SLUGGER:kowalchuk:2` fought the
  filler in R1 (Kowalchuk ticked, no page) and went on to R3; `spar
  generic=OUTBOXER:tremblay:3` ran three spars against a tier-3 filler
  (PI 1 then 2 vs Tremblay); Ep1's PRIYA TRIAL three times on her own
  three Out-Boxer strings ("SPAR: 33 XP, 5 Spirits, RORY+PRIYA +3, PI
  tick vs Priya") and SCRAP 2 five times on MARCUS's two ("PI tick vs
  Marcus" on the third win); zero errors. With the neutral game live,
  16,000-frame soaks on the profile against Carter (6 taunts, on to R3),
  Tam (7 tempo shifts), Marta (54 footwork flags) and Vasile ran with
  zero errors. With The Talk live, `-- demo talk` soaks on Yuri (a talk
  landed), Vasile (two missed) and the sanctioned format with a RORY +
  PRIYA bond at Corner Voices (the hint, two landed) ran with zero errors.
  With the formation screen live, `-- demo formation` soaks - the Ep1
  board against Ascendant B (the five picks, the order at 70%, all three
  slots right, still 70% at the end), the Relay Ladder with the Reveal at
  Lv3 against Vey's corner (a decoy dual, read: five DECOY silhouettes)
  and Ambush in a blind dual (no projection) - ran with zero errors, and
  `tools/drive_formation.gd` pressed the whiteboard's keys on the real
  scene (7/7). The soak caught one: the projection was recomputed after
  the bell, so R1's PI rung rewrote the read; it is now kept at the bell.
  With the staff live, 16,000-frame soaks - the staffed corner vs Yuri
  (the janitor at Lv3: 10 Tension at the bell, the building at 100), the
  sanctioned board vs Vey's corner with two cutmen and the rival
  cornerman at Lv3 (a decoy dual, read) and the Iron dual with the
  sports-med student at Lv3 (RORY back for R4 with his restore) - ran
  with zero errors. With recruitment live, a 60,000-frame `-- demo
  recruit` soak against Moira's squad ended two duals in 49,721 ticks;
  the win flagged MOIRA, DEX, REMY and TAM, the log approached all four
  and recruited REMY on his seeded quest; 16,000-frame recruit soaks
  against Yuri's squad and the sanctioned format and the recruit drive
  (5/5) ran with zero errors. With the String Wall live, a 60,000-frame
  `-- demo recruit` soak against Moira's squad with Q-MOREAU's quest and
  E05 closed ended two duals in 49,738 ticks: the win flagged four, REMY
  joined, and his string turned up JEAN-GUY, who joined in the same press;
  16,000-frame soaks on the Moreau blessing (Cold Storage 5 of 7 up, VERA
  IRON a lead), against Yuri's squad and on the sanctioned format, and the
  recruit drive (6/6, the wall on the HUD after the join), ran with zero
  errors.
  With the blessings live, a 60,000-frame soak against Moira's squad with
  Q-MOREAU's quest and E05 closed flipped E05 and blessed House Moreau
  before the bell, then signed JEAN-GUY and REMY NATIVE on the first win
  (three duals in 49,735 ticks); a 60,000-frame soak against Yuri's squad
  signed YURI and SAM UNSANCTIONED on the first win and lost the second,
  so the patriarch's witness waits at 0 of 1; a 16,000-frame soak on the
  live graph repaid E04, added E13, refused E11 and blessed House Reyes by
  its flag; the sanctioned format and the recruit drive (7/7, the HOUSES
  lines after the join) ran with zero errors. With the traits live,
  16,000-frame soaks against Carter's and Itzel's squads in the sanctioned
  format, against Sam, and with YURI sealed into R1 against Itzel
  (Load-Bearing against Debt of Honour), a 60,000-frame recruit soak
  against Yuri's squad and the recruit drive (8/8, the TRAITS line on the
  matchup card) ran with zero errors. With the Gym Wall live, 16,000-frame
  soaks - MARCUS and PRIYA pinned down the wall and its suggestion sealed
  against Yuri's squad (R1 RORY, R2 MARCUS, R3 PRIYA), the sanctioned
  five with SAM pinned under RORY sealed against Carter's squad (MARCUS,
  PRIYA, JUNE, RORY, SAM) and a save / load with MARCUS and JUNE pinned
  away from the top row (the same hash back at tick 3,000, the pins
  hanging where they were after the load) - a 60,000-frame recruit soak
  against Yuri's squad (the scene's seed is the clock: of the two runs
  taken, one lost a dual and hung the club's stub and the first two
  lines, the other lost two, one stub still, and RORY and PRIYA crossing
  into Gymmates hung their polaroid) and the formation drive (9/9, the
  wall's suggestion on the whiteboard and 6 sealing it) ran with zero
  errors. With the Duo live, 16,000-frame soaks - `-- demo duo` with RORY
  and PRIYA at Duo (R2 PRIYA with a full bar: the profile cast Whiteout,
  RORY's afterimage gilded), the same pair on the plain demo (the scene's
  seed is the clock: one run sent PRIYA out second and Whiteout was live
  in R2, the other swapped JUNE in and no Duo was), RORY and JUNE at Duo
  in the sanctioned format (Freeze-Up
  live in R2), the Relay Ladder against Vey's corner with RORY-SAM and
  SAM-MARCUS at Duo (the whiteboard's two DUO RELAYS, Aurora Chain -
  RORY & SAM live in R3) and a save / load with the pair at Sworn (the
  same hash back at tick 3,000) - the formation drive (12/12) and the Duo
  drive (5/5) ran with zero errors. With the relay's own T3s open (two
  runs of each; the scene's seed is the clock), `-- demo seg2 boss=0`
  (the FULL RELAY seeded: the relay's North Star cast, two afterimages in
  one run's 2,997 ticks and one in the other's), 16,000-frame soaks
  against Yuri's squad (the relay opened to R2 in both, to R3 as well in
  one) and in the sanctioned format against Carter's squad (opened once
  in each), `-- demo duo` with RORY and PRIYA at Duo (Whiteout three
  times in one run with the relay opened in R3, once in the other) and
  the Duo drive (6/6, R3's RELAY line) ran with zero errors. With the
  Zone live, 16,000-frame `-- demo zone` soaks with the fighters at level
  20 and the Provincials' flag, two runs of each (the scene's seed is the
  clock) - against Yuri's squad (the aid SURGEd whoever it could: two
  Zones and two Comedowns in one run, four Zones across two duals in the
  other), in the sanctioned format against Carter's squad (three SURGEs
  in each) and with a save / load (the same hash back at tick 3,000 in
  both) - and the Zone drive (6/6) ran with zero script errors. With the
  Manifest live, 16,000-frame `-- demo manifest` soaks with the Arc 2
  flags seeded, two runs of each - against Yuri's squad (RORY and PRIYA
  manifested in both runs, and again in a second dual in one with
  MARCUS's Zone between), in the sanctioned format against Carter's squad
  (RORY and JUNE manifested in both; PRIYA, with no flag of her own, went
  into the Zone in one) and with a save / load (the same hash back at
  tick 3,000 in both), 9 to 28 echoes shown a run - and the Manifest
  drive (6/6) ran with zero script errors. With Inheritance live,
  16,000-frame `-- demo inherit` soaks in the sanctioned format with
  RORY+SAM, JUNE+MARTA and PRIYA+YURI at Sworn, two runs of each - against
  Carter's squad (RORY, JUNE and PRIYA inherited from SAM, MARTA and YURI
  in both runs, MARCUS manifesting in R4 in one) and against Yuri's squad
  with a save / load (RORY and JUNE inherited in both, PRIYA too in one;
  the same hash back at tick 3,000 in both), 5 to 10 misreads a run - the
  Manifest soak again (RORY and PRIYA manifested in both) and the
  Inheritance drive (6/6) ran with zero script errors. With Awakening
  live, 16,000-frame `-- demo awaken` soaks, two runs of each - against
  Yuri's squad with RORY's form the Manifest (Awakened with it in both,
  PRIYA with the Zone in one), in the sanctioned format against Carter's
  squad with RORY and SAM Sworn and JUNE's card choosing the Zone (RORY's
  Inheritance-Awakening and JUNE's chosen Zone in both) and against
  Yuri's squad with a save / load and RORY's form the Zone (the same hash
  back at tick 3,000 in both), one or two drops refunded a run - and the
  Awakening drive (6/6) ran with zero script errors. With the
  enemy's transformations live, 16,000-frame soaks, two runs of each (the
  scene's seed is the clock), ran with zero script errors:
  - `-- demo boss=16`: Vasile's Zone in both, weathered 3 and 9 times,
    Stood in the Storm in both;
  - `-- demo clash boss=19 btransform=manifest@composure<80` with RORY's
    Manifest unlocked: Moira's and Remy's Manifests in both, Tam's in one;
    a Clash in each, the card winning it 3 of 5;
  - `-- demo boss=16 saveload`: the same hash back at tick 3,000 in both,
    his Zone and the feat in both.
  The enemy-transformation drive (7/7) and the Clash drive (5/5) also ran
  with zero script errors. With hybrid research live, 16,000-frame
  `-- demo hybrid` soaks in the sanctioned format, YURI and MARTA forged
  before the bell, two runs of each (the scene's seed is the clock), cast
  Grain & Snow relayed two to four times a run: against Yuri's squad,
  against Carter's squad, and with a save / load (the same hash back at
  tick 3,000 in both). They and the Forge drive (7/7) ran with zero
  script errors. With the Exhibition 2v2 live, 16,000-frame soaks in the
  manager's seat, two runs of each (the log's restart starts the next
  exhibition once one ends), ran with zero script errors:
  - `-- demo format=exhibition_2v2 boss=1 kizuna=RORY+PRIYA:90`: Double
    Overtime and Two-Hand Winter in both runs, the shared gauge linked in
    both, two exhibitions to their verdict in one and one in the other;
  - `-- demo format=exhibition_2v2 boss=7 pair=YURI,MARTA
    kizuna=YURI+MARTA:150`: two duo syncs a run, two exhibitions to their
    verdict in one and one in the other;
  - `-- demo format=exhibition_2v2 boss=16 kizuna=RORY+PRIYA:50`: no duo
    sync at Lv3, Vasile's Zone in pair A in both, an exhibition to its
    verdict in each.
  The exhibition drive (7/7) also ran with zero script errors. With the
  club facilities live, soaks ran with zero script errors:
  - `-- demo facilities boss=1 purse=hbp:7000,spirits:260` with the three
    story gates and `host=home` (60,000 frames, two runs): every track to
    T3 before the first bell, two hosted duals to their end, the entrance
    at both bells, 10 Prestige from hosting, five training slots;
  - `-- demo facilities boss=7 purse=hbp:1500,spirits:60` with two gates
    (60,000 frames, two runs): the story holding T3, six renovations before
    the bell and a seventh paid by the duals in one run;
  - `-- demo format=exhibition_2v2 ... facility=ring:2,foh:3 host=home`
    (16,000 frames, two runs): the exhibition at home, its duo syncs, a
    verdict and 5 Prestige from hosting in each;
  - `-- demo hybrid` on its moved command line (`facility=wall:3`, one
    run): Grain & Snow forged and cast relayed twice.
  The facilities drive (6/6) and the Forge drive on its moved command line
  (7/7) also ran with zero script errors. (Headless Godot's dummy renderer prints `Parameter "m"
  is null` when it frees an afterimage capsule, a manifest figure (the enemy's too) or an
  inheritance frame (an Awakening frees its stacked tier's) - not once per capsule: the Inheritance drive frees
  two and prints one - and at shutdown; every soak since the afterimage
  shipped shows it.)
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

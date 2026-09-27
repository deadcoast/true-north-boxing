extends Node3D
const TNBSim := preload("res://sim/core.gd")
const CombatInput := preload("res://input/combat_input.gd")
const ControlsMenu := preload("res://input/controls_menu.gd")
const TNBClock := preload("res://sim/clock.gd")
const TNBTests := preload("res://sim/tests.gd")
const TNBObjectives := preload("res://sim/objectives.gd")
const TNBSave := preload("res://sim/save.gd")
const TNBExhibition := preload("res://sim/exhibition.gd")
# TRUE NORTH BOXING - greybox presentation layer over TNBSim (sim/core.gd).
# This file owns shapes, camera, HUD, FX, and the turning of device input into
# one intent dictionary per 120Hz tick. It owns NO combat rules: every number
# lives in sim/core.gd + combat_tuning.v1.json. The sim runs behind a
# render-independent fixed-step accumulator (sim/clock.gd); the capsules are
# drawn at the interpolated position between the last two sim ticks.
#
# PAD: LS move | RS flick punch (angle = punch) | LT+LS slip/weave/lean | LT+punch body
#      RB power | RT block | LB hold + haymaker-flick at 100 Tension = A.B.B.
#      L3 sprint-step | R3 clinch | A = beat tap (count / clinch cue) / send (corner) | X = rest (corner) | DPAD-UP taunt
# KEYS: WASD | J/K straights, F/L flared, U/I hooks, N/; hookercuts, Y/O uppercuts | Esc controls
#       Alt held 150ms + punch haymaker | mouse left-button flick | tap-release within 80ms FEINT | Space block
#       Q/E slip | V weave | B lean | T taunt | Shift power | C body | H hissatsu-arm
#       Ctrl sprint-step | G clinch | ENTER beat tap | F8 audio-assist cue toggle
# CORNER (45s, 2 actions): 1 send | 2/3/4 equipped tactics | 5 super | 6/7/8 staff | 9 save the bar | 0 swap (first option)
#       pad: A send | X swap | Y super | B save the bar | DPAD L/R tactics 1/2 | DPAD DOWN staff 1
# META: F1-F4 switch boss (Vane/Yuri/Moreau/Sam) | F6/F7 prev/next of all 24 | R reload tuning | F5 new dual
#       CORNER: Z / X / C = The Talk with the next fighter - the plan / the fire / the arm around the shoulder (pad LB / RB / Back)
#       Shift+F5 save (user://tnb_save.json: the SaveGame from the ledgers, the DualState of a fight in flight) | Shift+F6 load it | -- load=<path> at the bell
#       -- generic=SLUGGER:kowalchuk:2 = an assembled filler fights R1 (with scrap= / spar: the card fought)
#       FORMATION (NP_10 s2): -- order=STANDARD|AMBUSH|WALL_FIRST|RELAY_LADDER | -- board=ep1 | -- board=MARCUS,PRIYA,RORY
#       RECRUITS (NP_08 s2): a dual won flags his squad's recruitables; DUAL OVER: [L] approach them (the condition surfaces), [P] recruit the ready
#       -- flag=quest:tremblay_feud,rep:rink_district:3 seeds the overworld's story flags | -- demo recruit approaches and recruits between duals
#       THE STRING WALL (NP_08 s2.3): a recruit's strings go up at DUAL OVER - family, master to student, his house; -- flag=blessing:moreau opens a house
#       HOUSES (NP_08 s3): every house met, its blessing line clause by clause, its members NATIVE / UNSANCTIONED; the feud graph's flips
#       (-- flag=feud_resolved:moreau+tremblay flips E05); a met line blesses the house at the moment it is met
#       GYM WALL (NP_08 s7): the cards on the wall, their Kizuna lines, what hangs there (DUAL OVER); 6 on the whiteboard seals the wall's
#       suggestion; -- wall=MARCUS:1:1,PRIYA:1:2 pins cards (with -- order=GYM_WALL the board seals it)
#       TRAITS (NP_07 s3): the matchup card names each corner's house trait in play (Yuri's Load-Bearing, Sam's Never Twice, SAM's...)
#       DUO (NP_08 s5.2 Lv4): a Duo pair's named T3 is live for the second out - the matchup card names it, LB + its family casts it
#       HYBRIDS (NP_08 s6): a Sworn pair of two houses, a native each, forges once between duals - F on the DUAL OVER screen (the FORGE
#       lines name each pair's hybrid and price, or what it waits on; since PAC-089 the Forge is The Wall's T3: -- facility=wall:3);
#       -- purse=spirits:40,beans:30 seeds the ledger, -- forge=YURI+MARTA
#       forges before the bell. The hybrid is live for either of the pair relayed from the other (the partner's afterimage, x1.25), CHARGED,
#       or in an Awakening's slot - the matchup card's HYBRID line, LB + its family (; is the keyboard's hookercut: a HAYMAKER);
#       -- demo hybrid tops the bar up once a segment while one is live (its corners keep the sealed order and never hold the bar)
#       (the partner's afterimage joins); -- kizuna=RORY+PRIYA:90 seeds a Duo; the whiteboard lists the DUO RELAYS an order holds;
#       -- demo duo kizuna=RORY+PRIYA:90 jumps to R2 with a full bar (the profile casts the pair's T3)
#       ZONE (NP_09 s3): H + Y (pad: LB + both sticks) surges into In the Zone - the whole bar (100, 75 on a FULL RELAY), unlocked at level
#       20 and the Provincials' flag: -- level=RORY:20 flag=story:provincials_semifinal; -- demo zone surges whoever can (the soak's aid)
#       MANIFEST (NP_09 s4): the same SURGE casts Spirit Manifestation where it is unlocked - a named fighter's Arc 2 flag
#       (-- flag=story:manifest:RORY), a generic stablemate's level 35 + mastery:zone:<NAME>: 30 s of damage x1.4, hissatsu from its own
#       50-point meter, every clean punch echoed at 0.3 s for +30 %, displacement x2; the figure stands behind him, the HUD's MANIFEST line
#       INHERITANCE (NP_09 s5): the same SURGE with a source - a stablemate of another house at Sworn (-- kizuna=RORY+SAM:150), a legacy's
#       flag, or a dual-house card's own second house (75): 25 s of his trait beside yours, his natives (LB + their motions) from a 50-point
#       meter, his dialect (the enemy misreads you); the Comedown scrambles your own dialect 10 s (your feints draw nothing); the HUD's line
#       AWAKENING (NP_09 s6): the same SURGE once the story gates it (-- flag=secret:RORY,story:trial:RORY,story:sealed_house_resolved for
#       RORY): 40 s of a prior tier at 75 % (-- form=RORY:manifest; else his highest), the rings' caps x1.75, a drop scored +15 Tension back;
#       -- surge=RORY:zone makes his SURGE cast a lower tier he has; the matchup card's SURGE line says which; the ring lit in his element
#       THE ENEMY'S TRANSFORMATION (NP_09 s1/s4/s7): a boss transforms only where the pattern authors it (Ioan Vasile, -- boss=16: the Zone
#       at 50 % composure) - GATHERING behind the guard with the line, then ENEMY ZONE / ENEMY MANIFEST on its clock, lit in the element;
#       each perfect block or slip shaves 1 s and halves the damage for the rest of it (WEATHERED); weathered to its end unanswered and
#       never down: STOOD IN THE STORM; the ENEMY COMEDOWN (10 s at 85 %) is your window. Both manifested: the MANIFEST CLASH - 5
#       exchanges, SPACE / Q / E (block or slip) on the enemy's, a punch on yours, 3 to win. -- btransform=manifest@composure<80 authors
#       one on every boss without one (the aid; @<name> names the manifest); -- demo clash holds the aid's SURGE for the enemy's manifest
#       RELAY (NP_05 s6): whoever enters CHARGED has the relay's T3s opened - Coast to Coast (LB + HAYMAKER), Aurora Chain (LB + ARC), North
#       Star (LB + RISE) on a FULL RELAY; the matchup card and the whiteboard name them, priced
#       STAFF (NP_10 s6): -- staff=janitor:3,professor,the_reveal dresses three of the corps (a staffer, or the active he carries); a level after the colon seeds his uses
#       -- formation = the whiteboard before the bell: 1-4 seal a named order, 5 the card order, ENTER rings the bell | TAB shows the board during the dual
#       EXHIBITION 2v2 (NP_01 s8): -- format=exhibition_2v2 [pair=RORY,PRIYA] - two per side in the ring at once, one segment, one bell, one bar:
#       you play the first card, the partner plays on his profile (\ swaps who you play; a pair KO'd hands you the other); each pair drawn in
#       its own half of the ring. DUO SYNC (NP_05 s7) at Kizuna Lv4 (-- kizuna=RORY+PRIYA:90): LB + uppercut (H + O) calls Double Overtime,
#       LB + RT held (H + SPACE) Two-Hand Winter - the partner answers inside 500 ms (his profile at 250 ms), the bar pays once; the wall is
#       one gauge for both. -- auto / -- demo: both on their profiles, who call it at 90. F5 again, F9 back to the rotation formats
#       THE OLD GYM (NP_10 s7): five facilities, T0 as found -> T3, each tier renovated between duals for HBP + Spirits behind its story gate
#       (-- purse=hbp:3000,spirits:150 flag=story:charter_saved,quest:gym_funding,story:nationals); DUAL OVER: [1]-[5] renovate Bags & Mitts,
#       The Ring, the Film Room, The Wall, Front of House; [T] a training slot (the best game open, grade 0.75; 3 a day - Beans for the Forge).
#       -- facility=bags:1,ring:2,film:3,wall:3,foh:3 seeds the tiers; -- host=home hosts the dual (Front of House's crowd and Prestige; with
#       -- format=exhibition_2v2, The Ring's home exhibition); -- train=mitts:RORY:0.8[:PRIYA] and -- renovate=film run before the bell;
#       -- demo facilities renovates everything the ledger allows and trains the day's slots before the bell and between duals (a day
#       turns at each dual's end)
#       GROWTH (NP_11 s3, s4, s6): DUAL OVER lists each dressed card's growth - level, rarity and cap, the board's points, his passives, the
#       node the aid would take, his raises, the next tier's price and trial. [N] takes that node (Board Points: 2 a level - -- level=RORY:10),
#       Shift+N respecs (the Film Room's T2), [Z] raises the stat the jar pays best (+1 = 5 Beans, +1 a raise; its own typed Beans first),
#       [X] ascends (Spirits 10/25/60 and the trial: a spar won, a transform weathered, the mirror beaten), [M] the mirror spar, [.] the
#       next card. -- nodes=RORY:c1+c3 (or RORY:* the aid's picks) takes nodes before the bell; -- growth=RORY:rarity:2,RORY:trial:storm,
#       PRIYA:raise:RFX:3 and -- beans=PWR:10 seed the ledger; -- demo growth: between duals the aid takes a node, a raise, an ascension
#       TECHNIQUES (NP_11 s2, s8): DUAL OVER lists the focused card's own move, T0 slot (level 5: a T0 is castable from there), technique
#       slots (5/15/25/35/45) and kit, then the shop's next buy, the lessons open, the tapes and the re-teach: [ buys it (HBP; -- flag=
#       story:regionals / story:provincials_semifinal open the t2 / t3 shelves), ] takes the lesson, ' spends a tape, / re-teaches in a
#       training slot, = carries the next learned, - puts the last down. LB + a motion casts his own move on its family, else the kit's.
#       -- learn=RORY:Snowblind+Root Bind seeds learned moves into the kit, -- tapes=Black Ice:1 the club's tapes; -- demo techniques
#       THE ACADEMY (NP_07 s10): -- academy fields the Toronto academy's prodigies in every enemy segment, Director Vey's corner. Each carries
#       three syntheses (the Forge's composer on two houses' natives, x0.85, no bond, no afterimage) cast from his bar when it pays; the
#       matchup card's ACADEMY line lists them and its THESIS line sets the club's forged hybrid against his best, in the numbers
#       THE MIRROR (NP_02 s2.2): the tracker keeps each fighter's record across every bout - DUAL OVER's HABITS line shows the focused card's
#       and the copy it makes. [M] (or -- spar flags=mirror, the lab's flag at The Ring's T1) sends him out against it: his most-thrown
#       sequences as its strings, his most-read ones read from the bell, his counter at his rate (the matchup card's MIRROR line); [M]
#       after it, back to the dual.
#       -- habits=RORY:L_STRAIGHT+L_STRAIGHT+R_STRAIGHT*8,RORY:counter=R_HOOK*4/6 seeds the record; -- demo mirror spars it between duals
#       GEAR (NP_11 s5): DUAL OVER's GEAR lines show what the focused card wears in the slots his rarity opens, the locker, the shop's next.
#       \ buys the shop's pick (HBP; -- flag=story:regionals opens the t2 shelf, story:provincials_semifinal the t3), , wears the best free
#       piece (his own signature first), Shift+, takes the last off. A piece's small passive is its kind's (gloves the jab, wraps the guard,
#       a mouthguard the wobble, a robe the walk-out's Tension, 3% at most); the matchup card's GEAR line names it and the figure wears it.
#       -- gear=tape_wraps,RORY:gym_robe seeds the locker; -- demo gear
#       SCOUTING (NP_08 s2.4, NP_11 s6): DUAL OVER's SCOUTING lines show the machine's pulls and last leads, and the open mat. ` feeds the
#       machine a pull (10 Prestige): a lead card, every 10th a rare one - a named recruit the club has not met turns approachable (the
#       RARE LEAD toast); the rest are generics waiting on the open mat. Shift+` signs the open mat's first into the stable - free on an
#       open-mat day (every 7th), else for the priority (10 Prestige). -- purse=prestige:100 seeds the Prestige; -- demo scouting
#       ROLES (NP_08 s1): DUAL OVER's ROLES lines show the bench and what each card works. 7 sets the aid's pick - the first on the bench
#       without a role: a training partner if the club has none, a scout if nobody covers his home district, else a cornerman-in-training;
#       Shift+7 sends the last one set back to the ring. A training partner goes along to a slot he can add to (a Bean for every 10 points he
#       leads the trainee by at the game's stat, 3 at most); a scout's district pays 1 Prestige when the day turns and, on the circuit,
#       reads its clubs' orders; a cornerman-in-training is a staff use at every dual's end. A dressed card's role waits. -- demo roles
#       THE LOCKER ROOM (NP_08 s4): DUAL OVER's LOCKER ROOM lines browse the stable - 8 cycles by House, Style, Element, bond web and
#       slot-role - and show the focused card's comparison card (9 the next card): stats, kit, trait, dialect, bonds. 0 releases the
#       focused card from the bench: the place freed, the role cleared, the gear back in the locker; Shift+0 takes the latest release back
#       inside three days. At the third day it stands: a recruit back in the district (approachable), a generic on the open mat - warm
#       with a bond left behind (back on the approach, or free any day), else a grudge (a spar won since, or the priority). -- demo locker
#       DISTRICT REP (NP_02 s2.1, NP_08 s2.2 / s2.4): -- scrap=SCR-01 district=rink places the scrap; won, the district's rep is +1 and
#       its milestones (3, 10, 25) pay Prestige the first time; BACKSPACE flees the scrap - free before the first exchange, -1 rep after.
#       REP(district, n) conditions read the ledger. DUAL OVER's DISTRICT REP line; the REP and FLED toasts
#       THE ANTI-YOU (NP_12 s2): when an arc turns (story:nationals, the Hollow Circuit's end) Director Vey's academy signs up to three of
#       the club's beaten rivals it left waiting (approachable, approached, released); the RECRUITS lines name them, the approach is refused,
#       and fielded (-- academy) they fight ahead of the prodigies with a prodigy's syntheses. The academy beaten, they come over. -- demo anti
#       VENDOR TIERS (NP_02 s4): the technique and gear shops stand on the Downtown Strip; their t2 and t3 shelves open by DOWNTOWN's rep
#       (10, 25) as well as by the story's flags - the rep as it stands, so a flee below the line closes a shelf again. DUAL OVER's
#       SHOPS lines; the REP toast names a shelf opened, the FLED toast one closed. -- rep=downtown:9 seeds the ledger's rep. -- demo vendors
# TESTS (headless): godot --headless --path . -- smoke boss=N | determinism | geometry | audit (NP_11 s10's obsolescence audit, PAC-095) | faucets (NP_11 s6's faucet/sink audit, PAC-097)
# DEMO: godot --path . -- demo   (self-playing scripted fighter; the presentation soak)

const COLORS := {"RORY": Color(0.25, 0.55, 0.9), "PRIYA": Color(0.3, 0.8, 0.75), "MARCUS": Color(0.9, 0.6, 0.2)}
const BOSS_COLOR := Color(0.85, 0.3, 0.25)
const ELEMENT_TINT := {"FROST": Color(0.78, 0.90, 1.0), "GALE": Color(0.82, 0.84, 0.88), "GRANITE": Color(0.80, 0.62, 0.36), "TIMBER": Color(0.36, 0.48, 0.28)}   # NP_06 s2.2 aura language

var sim: TNBSim
var combat_input := CombatInput.new()
var controls_menu: CanvasLayer
var practice_dummy := false
var practice_restore: Dictionary = {}
var practice_position := Vector2.ZERO
var clock := TNBClock.new()
var prev_p := Vector2.ZERO
var prev_b := Vector2.ZERO

# world
var player: Node3D
var boss: Node3D
var cam: Camera3D
var hud: Label
var feed: Label
var flashrect: ColorRect
var tell_tween: Tween

# edge-triggered intent, captured by _unhandled_input, consumed by the next tick
var q_punch := ""
var q_dodge := ""
var q_taunt := false
var q_corner := 0
var q_sprint := false
var q_clinch := false
var q_surge := false               # PAC-082: the SURGE motion (LB + both sticks click; keyboard H + Y)
var level_arg := ""                # -- level=RORY:20 seeds the XP ledger at those levels (PAC-082: the Zone opens at 20)
var demo_zone := false             # -- demo zone (or manifest / inherit / awaken): whoever is out with a tier unlocked surges once the bar is topped up (the soak's aid)
var btransform_arg := ""           # PAC-086: -- btransform=TIER@TRIGGER[@name] authors a transformation on every boss pattern without one (the aid)
var demo_clash := false            # PAC-086: -- demo clash: the aid's SURGE waits for his manifest (the Clash)
var bmanifest_fig: Node3D = null   # PAC-086: his manifest behind him
var bmanifest_pulse := 0.0         # PAC-086: his echo's pulse on his figure
var q_release := false
var q_action: Dictionary = {}
var ghost: Node3D
var ghost_t := 0.0
var manifest_fig: Node3D = null      # PAC-083: the manifest behind the fighter (a tall translucent capsule in his element's tint)
var manifest_pulse := 0.0            # PAC-083: the echo's pulse on the figure (seconds left)
var inherit_fig: Node3D = null       # PAC-084: the source's ghost-frame over the caster
var ring_floor: MeshInstance3D       # PAC-085: the canvas, lit in his element while he is Awakened
var apron_fig: Node3D = null         # PAC-084: a dressed source at the apron, mirroring him
var ghosts_spawned := 0
var duo_casts: Array = []          # PAC-080: the Duo T3s cast this run (the soak's summary)
var audio_assist := false
var demo_log: Array = []           # -- demo: the scripted player drives the scene (attract mode / soak)
var demo_seg2 := false             # -- demo seg2: a FULL RELAY R2 - the scripted fighter is told to cast North Star (the relay opens it) until the ghost shows
var matchup_until := 0             # the matchup card (NP_06 s5) stays on the HUD for the opening 3s of a segment
var matchup_text := ""
var matchups_shown := 0
var fmt_id := ""                   # -- format=sanctioned|mini|iron|blind|gauntlet (F9 cycles); "" = the data's default (mini)
const EP1_CYCLE := ["scrap_1", "scrap_2", "scrap_3", "priya_trial", ""]   # F10: Ep1's bouts by name, then back to the dual
var ep1_i := -1
var scr_i := -1                    # F11: the next scrap objective on the current boss
var pi_arg := ""                   # -- pi=dialect:level,boss:3 (PAC-064)
var kizuna_arg := ""               # -- kizuna=A+B:pts (PAC-068)
var order_arg := ""                # -- order=AMBUSH (PAC-073): a named order archetype sealed at setup
var board_arg := ""                # -- board=ep1 | -- board=MARCUS,PRIYA,RORY
var district_arg := ""             # PAC-101: -- district=rink - where the overworld places a scrap (its rep)
var rep_arg := ""                  # PAC-103: -- rep=downtown:9 - the districts' rep on the ledger as it stood
var wall_arg := ""                 # -- wall=MARCUS:1:1,PRIYA:1:2 pins cards on the Gym Wall (PAC-079); with -- order=GYM_WALL the board seals the wall's suggestion
var staff_arg := ""                # -- staff=the_reveal:3,patch_job,raise_the_roof (the board's 3 staff, levels after the colon)
var flag_arg := ""                 # -- flag=quest:tremblay_feud,rep:rink_district:3 (PAC-075: the story flags the overworld would set)
var purse_arg := ""                # PAC-087: -- purse=spirits:40,beans:30 (what duals and training slots would have paid)
var forge_arg := ""                # PAC-087: -- forge=YURI+MARTA (the Forge before the bell)
var demo_hybrid := false           # PAC-087: -- demo hybrid tops the bar up once a segment while a hybrid is live (the soak's aid)
var hybrid_topped := -1            # the segment the aid topped up
var hybrid_casts: Array = []       # PAC-087: the hybrids cast this run (the soak's summary)
var forged_seen: Array = []        # PAC-087: the hybrids forged this run
var demo_recruit := false          # -- demo recruit: between duals the log approaches everyone flagged and recruits everyone ready
var formation_open := false        # -- formation: the whiteboard before the bell - the sim waits until ENTER
var show_formation := false        # TAB: the board, their projection and the rings on the HUD during the dual
var demo_formation := false        # -- demo formation: the board and the projection printed at the bell, the reveal checked at the end
const SAVE_PATH := "user://tnb_save.json"   # Shift+F5 / Shift+F6 (PAC-069)
var load_arg := ""                 # -- load=<path>: the save read at the bell
var generic_arg := ""              # -- generic=SLUGGER:kowalchuk:2[:seed] (PAC-070): an assembled filler in R1, or the card `-- scrap=` / `spar` fight
var demo_saveload := false         # -- demo saveload: save at tick 3,000, load it back at 3,600 (the soak proves the resume)
var demo_saved_hash := 0
var demo_saved := false
var demo_loaded := false
var demo_saveload_line := ""
var toast_until := 0
var toast_text := ""
var pi_toast := ""                 # the last rung crossed, on the HUD for a few seconds
var pi_toast_until := 0
const FORMAT_CYCLE := ["mini", "sanctioned", "iron", "blind", "gauntlet"]
var content: Dictionary = {}
var exh = null                     # PAC-088: the Exhibition 2v2's coordinator (sim/exhibition.gd); sim is the pair the pad plays
var partner: Node3D                # the other pair: the partner and his opponent, in the other half of the ring
var partner_boss: Node3D
var prev_q := Vector2.ZERO
var prev_qb := Vector2.ZERO
var pair_arg := ""                 # -- pair=RORY,PRIYA: the exhibition's two cards (the 8-card roster's names)
var demo_exh := false              # -- demo with the exhibition: the aid tops the bar up twice (ticks 600 and 2400) once both pairs fight
var exh_topped := 0
var duo_syncs: Array = []          # the duo syncs seen this run (the soak's summary)
var facility_arg := ""             # PAC-089: -- facility=bags:1,ring:2 (the tiers the renovations would have built)
var host_home := false             # PAC-089: -- host=home (the dual, or the exhibition, at the club's gym)
var train_arg := ""                # PAC-089: -- train=mitts:RORY:0.8[:PARTNER],roadwork:PRIYA:0.5 (slots before the bell)
var renovate_arg := ""             # PAC-089: -- renovate=film,wall (before the bell)
var demo_facilities := false       # PAC-089: -- demo facilities: between duals the log renovates the first ready and trains; a day turns at each dual's end
var renovations_seen: Array = []   # PAC-089: the renovations this run (the soak's summary)
var trainings_seen: Array = []
var growth_arg := ""               # PAC-090: -- growth=RORY:rarity:2,RORY:trial:spar_won,PRIYA:raise:RFX:3 (what the ledger's growth would hold)
var beans_arg := ""                # PAC-090: -- beans=PWR:10,SPD:4 (typed Beans in the jar)
var nodes_arg := ""                # PAC-090: -- nodes=RORY:c1+c3,PRIYA:* (nodes taken before the bell, paid in Board Points; * the aid's picks while it has one)
var demo_growth := false           # PAC-090: -- demo growth: between duals the aid takes a node, a raise and an ascension for each dressed card
var growth_focus := 0              # PAC-090: the card the growth keys act on ([.] the next)
var academy_arg := false           # PAC-092: -- academy (the Toronto academy's prodigies in every enemy segment, Director Vey's corner)
var syntheses_seen: Array = []     # PAC-092: the academy's synthesis casts this run (the soak's summary)
var habits_arg := ""               # PAC-093: -- habits=RORY:L_STRAIGHT+L_STRAIGHT+R_STRAIGHT*8,RORY:counter=R_HOOK*4/6 (the tracker's record, seeded)
var demo_mirror := false           # PAC-093: -- demo mirror: between duals the aid spars the next dressed card's mirror, then back to the dual
var mirrors_seen: Array = []       # PAC-093: the mirrors fought this run and what each threw (the soak's summary)
var mirror_counters := 0           # PAC-093: the copies' counters (your counter punch, thrown back)
var gear_arg := ""                 # PAC-094: -- gear=tape_wraps,RORY:gym_robe (the locker, and what each card wears)
var demo_gear := false             # PAC-094: -- demo gear: between duals the aid buys the shop's pick and dresses each card
var gear_seen_log: Array = []      # PAC-094: the pieces bought, won and worn this run (the soak's summary)
var demo_scouting := false         # PAC-098: -- demo scouting: between duals the aid feeds the machine and signs the open mat's first
var scout_seen: Array = []         # PAC-098: the leads dispensed this run, the rare marked (the soak's summary)
var signed_seen: Array = []        # PAC-098: the generics signed from the open mat
var demo_roles := false            # PAC-099: -- demo roles: between duals the aid pulls, signs, sets the bench's roles and trains; a day turns at each dual's end
var roles_seen: Array = []         # PAC-099: the roles set this run
var scouted_seen := 0              # PAC-099: the Prestige the scouts' districts paid
var trainee_seen := 0              # PAC-099: the staff uses the cornermen-in-training fed
var partner_seen := 0              # PAC-099: the Beans the training partners added
var demo_locker := false           # PAC-100: -- demo locker: between duals the aid pulls, signs, releases the bench's last and turns a day; a day turns at each dual's end too
var locker_by := 0                 # PAC-100: the locker room's browse (economy.v1.json's locker.browse, in order)
var locker_focus := ""             # PAC-100: the card the comparison card shows (and 0 releases)
var locker_seen: Array = []        # PAC-100: the releases, take-backs and settlements this run
var rep_seen: Array = []           # PAC-101: the district rep moves this run
var demo_vendors := false          # PAC-103: -- demo vendors: between bouts the aid buys a technique and gear for each dressed card
var vendor_seen: Array = []        # PAC-103: the shelves opened / closed and what was bought off which, and how the shelf stood open
var demo_anti := false             # PAC-102: -- demo anti: between duals the aid approaches the flagged, the arc turns (story:nationals) and the academy is fielded with its signings
var anti_seen: Array = []          # PAC-102: the academy's signings and the rivals who came over
var growth_seen: Array = []        # PAC-090: the nodes, raises and ascensions this run (the soak's summary)
var learn_arg := ""                # PAC-091: -- learn=RORY:Snowblind+Root Bind (learned and in the kit, the overworld's)
var tapes_arg := ""                # PAC-091: -- tapes=Black Ice:1 (fight tapes the club holds)
var demo_techniques := false       # PAC-091: -- demo techniques: between duals the aid teaches each dressed card (a lesson, a tape, the shop, a re-teach)
var learned_seen: Array = []       # PAC-091: what the run taught, and from where (the soak's summary)
var kit_casts: Array = []          # PAC-091: the kit's casts (the soak's summary)
var entrances_seen := 0
var duo_misses: Array = []

func roster_for(f: String) -> Array:
	# the cards each format dresses: 8 for the sanctioned/blind dual, 4 for the mini, 3 for the Iron dual, 1 for the Gauntlet
	match f:
		"sanctioned", "blind": return TNBSim.LINEUP_MILLBROOK_8.duplicate(true)
		"iron": return [TNBSim.LINEUP_MILLBROOK_8[0].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[2].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[3].duplicate(true)]   # RORY, PRIYA, MARCUS
		"gauntlet": return [TNBSim.LINEUP_MILLBROOK_8[0].duplicate(true)]
	return TNBSim.LINEUP_MILLBROOK.duplicate(true)

func _pair_cards(arg: String) -> Array:
	# the exhibition's pair: -- pair=A,B by name from the 8-card roster, else RORY and PRIYA (the first two cards)
	var out: Array = []
	for nm in arg.split(",", false):
		for c in TNBSim.LINEUP_MILLBROOK_8:
			if str(c["name"]) == str(nm).strip_edges().to_upper() and out.size() < 2: out.append(c.duplicate(true))
	if out.size() < 2: out = [TNBSim.LINEUP_MILLBROOK[0].duplicate(true), TNBSim.LINEUP_MILLBROOK[1].duplicate(true)]
	return out

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	combat_input.load_settings()
	practice_dummy = "dummy" in args
	for option in args:
		if option == "controls=chords": combat_input.preset = "chords"
	controls_menu = ControlsMenu.new(); add_child(controls_menu); controls_menu.setup(combat_input)
	controls_menu.practice_changed.connect(set_practice)
	controls_menu.practice.set_pressed_no_signal(practice_dummy)
	Input.joy_connection_changed.connect(func(_device, connected):
		if not connected: combat_input.clear())
	var boss_idx := 0
	for a in args:
		if a.begins_with("boss="): boss_idx = clampi(int(a.split("=")[1]), 0, TNBSim.BOSSES.size() - 1)
	for m in ["smoke", "determinism", "geometry", "audit", "faucets"]:
		if m in args:
			var code := TNBTests.new().run(m, boss_idx)
			get_tree().quit(code)
			return
	for a in args:
		if a.begins_with("format="): fmt_id = a.split("=")[1]
	var auto_dual := "auto" in args or "demo" in args           # manager mode from the bell; the demo is the profile playing (the log keeps the corners)
	for a in args:                                        # -- pi=kowalchuk:2,yuri_kowalchuk:3 seeds the recon ledger (NP_02 s3); -- kizuna=RORY+PRIYA:50 seeds a bond (NP_08 s5)
		if a.begins_with("pi="): pi_arg = a.split("=")[1]
		elif a.begins_with("kizuna="): kizuna_arg = a.split("=")[1]
		elif a.begins_with("order="): order_arg = a.split("=")[1]
		elif a.begins_with("board="): board_arg = a.split("=")[1]
		elif a.begins_with("district="): district_arg = a.split("=")[1]
		elif a.begins_with("rep="): rep_arg = a.split("=")[1]
		elif a.begins_with("wall="): wall_arg = a.split("=")[1]
		elif a.begins_with("staff="): staff_arg = a.split("=")[1]
		elif a.begins_with("flag="): flag_arg = a.split("=")[1]
		elif a.begins_with("level="): level_arg = a.split("=")[1]
		elif a.begins_with("btransform="): btransform_arg = a.substr(11)
		elif a.begins_with("purse="): purse_arg = a.split("=")[1]
		elif a.begins_with("forge="): forge_arg = a.split("=")[1]
		elif a.begins_with("pair="): pair_arg = a.split("=")[1]
		elif a.begins_with("facility="): facility_arg = a.split("=")[1]
		elif a.begins_with("train="): train_arg = a.split("=")[1]
		elif a.begins_with("renovate="): renovate_arg = a.split("=")[1]
		elif a.begins_with("growth="): growth_arg = a.split("=")[1]
		elif a.begins_with("beans="): beans_arg = a.split("=")[1]
		elif a.begins_with("nodes="): nodes_arg = a.split("=")[1]
		elif a.begins_with("learn="): learn_arg = a.split("=")[1]
		elif a.begins_with("tapes="): tapes_arg = a.split("=")[1]
		elif a.begins_with("gear="): gear_arg = a.substr(5)
		elif a.begins_with("habits="): habits_arg = a.substr(7)                                        # (counter=R_HOOK*4/6 carries its own "=")
		elif a == "host=home": host_home = true
		elif a == "academy": academy_arg = true
	formation_open = "formation" in args and not ("demo" in args)
	demo_formation = "formation" in args and "demo" in args
	var lineup: Array = roster_for(fmt_id if fmt_id != "" else "mini")
	for a in args:                                        # PAC-085: -- surge=RORY:manifest / -- form=RORY:zone - the choices the overworld's menu makes between duals
		var fld := "surge_tier" if a.begins_with("surge=") else ("awakening_form" if a.begins_with("form=") else "")
		if fld == "": continue
		for part in a.split("=")[1].split(","):
			var nt := part.split(":")
			if nt.size() != 2: continue
			for c in lineup:
				if str(c.get("name", "")) == nt[0]: c[fld] = nt[1]
	if "demo" in args:
		demo_log = TNBTests.new().build_log(120 * 600, 777)
		demo_saveload = "saveload" in args
		demo_zone = "zone" in args or "manifest" in args or "inherit" in args or "awaken" in args or "clash" in args
		demo_clash = "clash" in args
		demo_hybrid = "hybrid" in args
		if demo_hybrid:                                     # -- demo hybrid: the log's corners keep the sealed order (no swap) and never hold the bar, so the pair relays as sealed and can spend
			for di in demo_log.size():
				if demo_log[di].get("corner_action", {}) is Dictionary and str(demo_log[di].get("corner_action", {}).get("kind", "")) in ["swap", "save_bar"]: demo_log[di].erase("corner_action")
		if "talk" in args:                                  # -- demo talk: the log's corners also talk to the next fighter (the plan / the fire / the arm in turn)
			for di in demo_log.size():
				if di % 7 == 5: demo_log[di]["corner_action"] = {"kind": "talk", "option": ["plan", "fire", "arm"][(di / 7) % 3]}
		# PAC-081: the relay opens its T3s to whoever enters CHARGED - the demo no longer hands PRIYA's card North Star to show the afterimage
		demo_gear = "gear" in args
		if demo_gear:                                       # -- demo gear: every tick between duals the aid buys the shop's pick and dresses each card (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["gear"] = "*"
		demo_scouting = "scouting" in args
		if demo_scouting:                                   # -- demo scouting: every tick between duals the aid pulls while the Prestige lasts and signs the open mat's first (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["scout"] = 1; demo_log[di]["sign"] = "*"
		demo_roles = "roles" in args
		if demo_roles:                                      # -- demo roles: every tick between duals the aid pulls seven, signs them off the open mat, sets the bench's roles and trains a slot (the sim acts only in OVER); a day turns at each dual's end
			for di in demo_log.size(): demo_log[di]["scout"] = 7; demo_log[di]["sign"] = 7; demo_log[di]["role"] = 7; demo_log[di]["train"] = 0.5
		demo_locker = "locker" in args
		if demo_locker:                                     # -- demo locker: every tick between duals the aid pulls three, signs them off the open mat, releases the bench's last and turns a day (the sim acts only in OVER); a day turns at each dual's end too
			for di in demo_log.size(): demo_log[di]["scout"] = 3; demo_log[di]["sign"] = 3; demo_log[di]["release"] = 1; demo_log[di]["day"] = 1
		demo_vendors = "vendors" in args
		if demo_vendors:                                    # -- demo vendors: every tick between bouts the aid buys off the open shelves - a technique and gear for each dressed card (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["teach"] = "*"; demo_log[di]["gear"] = "*"
		demo_anti = "anti" in args
		if demo_anti:                                       # -- demo anti: every tick between duals the aid approaches the flagged, marks the arc's turn once someone is left waiting and fields the academy once it holds anyone (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["approach"] = "*"; demo_log[di]["story"] = "story:nationals"; demo_log[di]["academy"] = true
		demo_mirror = "mirror" in args
		if demo_mirror:                                     # -- demo mirror: every tick between duals the aid spars the next card's mirror, and after it goes back (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["mirror"] = "*"
		demo_facilities = "facilities" in args
		if demo_facilities:                                 # -- demo facilities: every tick between duals renovates the first ready and trains a slot (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["renovate"] = "*"; demo_log[di]["train"] = 0.75
		demo_growth = "growth" in args
		if demo_growth:                                     # -- demo growth: every tick between duals the aid grows each dressed card (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["grow"] = "*"
		demo_techniques = "techniques" in args
		if demo_techniques:                                 # -- demo techniques: every tick between duals the aid teaches each dressed card (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["teach"] = "*"
		demo_recruit = "recruit" in args
		if demo_recruit:                                    # -- demo recruit: every tick between duals approaches the flagged and recruits the ready (the sim acts only in OVER)
			for di in demo_log.size(): demo_log[di]["approach"] = "*"; demo_log[di]["recruit"] = "*"
	content = TNBSim.load_content()
	if btransform_arg != "": _author_btransform(btransform_arg)
	var ledger0: Dictionary = TNBSim.seed_facilities(TNBSim.seed_purse(TNBSim.seed_levels(TNBSim.seed_story(TNBSim.seed_staff(TNBSim.parse_kizuna_arg(kizuna_arg), staff_arg, content.get("staff", {})), flag_arg), level_arg, content.get("economy", {})), purse_arg), facility_arg, content.get("facilities", {}))
	ledger0 = TNBSim.seed_beans(TNBSim.seed_growth(ledger0, growth_arg), beans_arg)                   # PAC-090: the growth and the typed Beans the ledger would hold
	ledger0 = TNBSim.seed_tapes(TNBSim.seed_learned(ledger0, learn_arg), tapes_arg)                      # PAC-091: techniques learned (in the kit) and the fight tapes held
	ledger0 = TNBSim.seed_habits(ledger0, habits_arg)                                                   # PAC-093: the tracker's record of how each fighter fights
	ledger0 = TNBSim.seed_gear(ledger0, gear_arg)                                                       # PAC-094: the locker and what each card wears
	ledger0 = TNBSim.seed_rep(ledger0, rep_arg, content.get("economy", {}))                            # PAC-103: the districts' rep as it stood
	if fmt_id == "exhibition_2v2":                                       # PAC-088: NP_01 s8 - two engagements under one coordinator
		exh = TNBExhibition.new()
		exh.setup(content, _pair_cards(pair_arg), boss_idx, int(Time.get_ticks_usec() % 2147483647), ledger0, TNBSim.parse_pi_arg(pi_arg, content.get("pattern_intel", {})), "exhibition_2v2", auto_dual, "home" if host_home else "festival")
		sim = exh.ctrl_sim()
		demo_exh = "demo" in args
		_build_world(); _build_partner()
		prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
		_consume_exh(); _consume_events()
		return
	for a in args:                                        # -- load=<path>: the SaveGame (and the fight in flight beneath it) read at the bell (NP_11 s9)
		if a.begins_with("load="): load_arg = a.split("=")[1]
	var loaded := ""
	if load_arg != "":
		var rd: Dictionary = TNBSave.read_file(load_arg)
		if bool(rd["ok"]):
			var built: Dictionary = TNBSave.build(content, rd, int(Time.get_ticks_usec() % 2147483647))
			sim = built["sim"]; fmt_id = str(sim.fmt.get("id", "mini"))
			loaded = "LOADED %s :: %s%s" % [load_arg, TNBSave.summary(sim), (" - " + str(built["restored"].get("why", ""))) if built["restored"].size() > 0 and not bool(built["restored"].get("ok", false)) else ""]
		else: loaded = "NOT LOADED %s :: %s" % [load_arg, str(rd["why"])]
		print(loaded)
	if sim == null:
		sim = TNBSim.new()
		sim.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, int(Time.get_ticks_usec() % 2147483647), content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt_id, content.get("bouts", {}), content.get("scraps", {}),
			content.get("pattern_intel", {}), TNBSim.parse_pi_arg(pi_arg, content.get("pattern_intel", {})), content.get("remixes", {}), content.get("economy", {}), ledger0, {}, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}),
			content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), TNBSim.parse_board_arg(order_arg, board_arg, staff_arg), content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
	for a in args:                                        # -- remix=yuri_kowalchuk.rematch | -- remix=all (every boss with a remix authored)
		if a.begins_with("remix="): _set_remix_arg(a.split("=")[1])
	if wall_arg != "":                                    # -- wall=NAME:x:y,...: the Gym Wall's cards pinned by hand before the bell (NP_08 s7)
		for part in wall_arg.split(","):
			var wb := part.split(":")
			if wb.size() == 3: sim.pin(str(wb[0]).strip_edges().to_upper(), int(wb[1]), int(wb[2]))
		if order_arg.to_upper() == "GYM_WALL": sim.seal_board(TNBSim.parse_board_arg(order_arg, board_arg, staff_arg))   # the wall's suggestion sealed from the wall as pinned
	var gcard := {}                                        # -- generic=STYLE:dialect:tier[:seed] (NP_04 s9): a filler assembled for R1, or the card a scrap / spar is fought against
	for a in args:
		if a.begins_with("generic="): generic_arg = a.split("=")[1]
	var sized := "spar" in args
	for a in args:
		if a.begins_with("scrap="): sized = true
	if generic_arg != "":
		var gp := generic_arg.split(":")
		var gspec: Dictionary = sim.generic_spec("FILLER", str(gp[0]) if gp.size() > 0 else "BOXERPUNCHER", str(gp[1]) if gp.size() > 1 else "gym", int(gp[2]) if gp.size() > 2 else 1, int(gp[3]) if gp.size() > 3 else 0, "the Filler")
		gcard = {"name": "FILLER", "style": gspec["style"], "element": gspec["element"], "house": gspec["house"], "dialect": gspec["dialect"], "generic": true, "tier": gspec["tier"], "seed": gspec["seed"], "stats": gspec["stats"]}
		if not sized: sim.set_generic_slot(0, gspec); sim.new_dual()
	if auto_dual and loaded == "": sim.delegate_all = true; sim.new_dual()
	elif auto_dual: sim.delegate_all = true
	var flags: Array = []
	for a in args:
		if a.begins_with("flags="): flags = Array(a.split("=")[1].split(","))
	for a in args:                                        # the smaller sizes (NP_02 s2): -- scrap=SCR-01 | -- spar | -- ep1=scrap_2
		if a.begins_with("scrap="): sim.start_scrap(a.split("=")[1], boss_idx, "", gcard, "", district_arg)
		elif a == "spar": sim.start_spar(boss_idx, flags, gcard)
		elif a.begins_with("ep1="): sim.start_ep1(a.split("=")[1])
	if host_home: sim.set_host(true)                   # PAC-089: -- host=home - the dual at the club's gym
	if academy_arg and bool(sim.field_academy(true)["ok"]): sim.new_dual()   # PAC-092: -- academy - NP_07 s10's thesis squad from the bell
	if demo_facilities:                                 # -- demo facilities: before the first bell too - every renovation the ledger allows, the day's training
		while sim.renovate_ready() != "": sim.renovate("*")
		for ti in 3: sim.train("*", "*", 0.75)
	for rn in renovate_arg.split(",", false): sim.renovate(str(rn).strip_edges())   # PAC-089: -- renovate=film (before the bell)
	if demo_techniques:                                 # PAC-091: -- demo techniques: before the first bell too - three rounds of the aid's teaching
		for ti2 in 3: sim.teach_aid("*")
	if demo_gear and sim.gear_aid("*") > 0: sim.new_dual()   # PAC-094: -- demo gear: before the first bell too - the shop's pick and what fits, worn from the bell
	for np_ in nodes_arg.split(",", false):             # PAC-090: -- nodes=RORY:c1+c3 | RORY:* (before the bell, paid in Board Points)
		var nb := str(np_).split(":")
		if nb.size() != 2: continue
		var nnm := str(nb[0]).strip_edges().to_upper()
		if str(nb[1]) == "*":
			for ni in 64:
				if sim.node_best(nnm) == "" or not bool(sim.take_node(nnm, "*")["ok"]): break
		else:
			for nid in str(nb[1]).split("+", false): sim.take_node(nnm, str(nid).strip_edges())
	for tp in train_arg.split(",", false):              # PAC-089: -- train=mitts:RORY:0.8[:PARTNER] (a slot before the bell)
		var tb := str(tp).split(":")
		if tb.size() >= 3: sim.train(str(tb[0]), str(tb[1]).to_upper(), float(tb[2]), str(tb[3]).to_upper() if tb.size() > 3 else "")
	for fp in forge_arg.split(","):                     # -- forge=YURI+MARTA: the Forge before the bell (NP_08 s6 - between duals)
		var ab := fp.split("+")
		if ab.size() == 2:
			var fr: Dictionary = sim.forge(str(ab[0]).strip_edges(), str(ab[1]).strip_edges())
			print("FORGE :: %s" % (str(fr["name"]) if bool(fr["ok"]) else str(fr["why"])))
	_build_world()
	if "seg2" in args:                                   # demo aid: jump to a CHARGED R2 with a full bar - the chain seeded to a FULL RELAY, so the relay opens North Star (the T3 afterimage)
		sim.contributed = 30.0; sim.relay_chain = 2; sim._end_segment("demo"); sim.corner_pick(0); sim.corner_pick(0); sim.tension = 100.0; demo_seg2 = true
	elif "duo" in args:                                  # demo aid (PAC-080): jump to R2 with a full bar - with -- kizuna= a Duo, its T3 goes up (the gilded afterimage)
		sim._end_segment("demo"); sim.corner_pick(0); sim.corner_pick(0); sim.tension = 100.0
	prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
	_consume_events()
	if loaded != "": feed.text = loaded
	if demo_formation:                                   # -- demo formation: the whiteboard's five picks in turn (what keys 1-5 call), then the board asked for; printed at the bell
		for fi in 6:
			_formation_pick(fi); print("FORMATION PICK %d :: %s" % [fi + 1, str(sim.formation_lines()[0])])
		var want: Dictionary = TNBSim.parse_board_arg(order_arg, board_arg, staff_arg)
		if want.size() > 0: sim.seal_board(want); _consume_events()
		for ln in sim.formation_lines(): print("FORMATION :: " + str(ln))

# ============================== WORLD =====================================
func _build_partner() -> void:
	# PAC-088: the other pair - the partner in his card's colour, his opponent in the enemy's - drawn in the other half of the ring
	var q: TNBSim = exh.e(exh.other(exh.ctrl))
	partner = _mk_capsule(COLORS.get(q.pname(), Color(0.55, 0.6, 0.7)), _to3(q.P["pos"], exh.other(exh.ctrl)))
	partner_boss = _mk_capsule(BOSS_COLOR.darkened(0.15), _to3(q.B["pos"], exh.other(exh.ctrl)))
	prev_q = q.P["pos"]; prev_qb = q.B["pos"]

func _mk_box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color
	box.material = mat; m.mesh = box; m.position = pos
	add_child(m); return m

func _mk_capsule(color: Color, pos: Vector3) -> Node3D:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new(); cap.radius = 0.35; cap.height = 1.8
	var mat := StandardMaterial3D.new(); mat.albedo_color = color
	cap.material = mat; m.mesh = cap; m.position = Vector3(0, 0.9, 0)
	root.add_child(m); root.set_meta("mesh", m); root.set_meta("mat", mat)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new(); sph.radius = 0.18; sph.height = 0.36
	var hmat := StandardMaterial3D.new(); hmat.albedo_color = color.lightened(0.35)
	sph.material = hmat; head.mesh = sph; head.position = Vector3(0, TNBSim.HEAD_H, 0)
	root.add_child(head); root.set_meta("head", head)
	return root

func _build_world() -> void:
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 30, 0); add_child(sun)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.09, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55); env.environment = e; add_child(env)
	ring_floor = _mk_box(Vector3(7.4, 0.2, 7.4), Color(0.22, 0.24, 0.28), Vector3(0, -0.1, 0))
	_mk_box(Vector3(3.7, 0.01, 3.7), Color(0.26, 0.28, 0.33), Vector3(0, 0.005, 0))          # center-ring disc hint
	for c in [Vector3(-3.7,0.9,-3.7), Vector3(3.7,0.9,-3.7), Vector3(-3.7,0.9,3.7), Vector3(3.7,0.9,3.7)]:
		_mk_box(Vector3(0.15, 1.8, 0.15), Color(0.55, 0.15, 0.15), c)
	for h in [0.5, 0.95, 1.4]:
		_mk_box(Vector3(7.4, 0.04, 0.04), Color(0.7,0.7,0.75), Vector3(0, h, -3.7))
		_mk_box(Vector3(7.4, 0.04, 0.04), Color(0.7,0.7,0.75), Vector3(0, h,  3.7))
		_mk_box(Vector3(0.04, 0.04, 7.4), Color(0.7,0.7,0.75), Vector3(-3.7, h, 0))
		_mk_box(Vector3(0.04, 0.04, 7.4), Color(0.7,0.7,0.75), Vector3( 3.7, h, 0))
	player = _mk_capsule(COLORS["RORY"], Vector3(0, 0, 1.0))
	boss = _mk_capsule(BOSS_COLOR, Vector3(0, 0, -1.0))
	cam = Camera3D.new(); cam.fov = 55.0; add_child(cam)
	var ui := CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.position = Vector2(20, 14)
	hud.add_theme_font_size_override("font_size", 17); ui.add_child(hud)
	feed = Label.new(); feed.mouse_filter = Control.MOUSE_FILTER_IGNORE; feed.position = Vector2(20, 640); feed.size = Vector2(1240, 70)
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD
	feed.add_theme_font_size_override("font_size", 18)
	feed.add_theme_color_override("font_color", Color(1, 0.9, 0.5)); ui.add_child(feed)
	flashrect = ColorRect.new(); flashrect.color = Color(1,1,1,0); flashrect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flashrect.size = Vector2(1280, 720); ui.add_child(flashrect)

# ============================== INPUT =====================================
func _trigger(axis: int, key: int) -> bool:
	for dev in Input.get_connected_joypads():
		if Input.get_joy_axis(dev, axis) > 0.5: return true
	return Input.is_key_pressed(key)

func _button(btn: int, key: int) -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, btn): return true
	return Input.is_key_pressed(key)

func _intent() -> Dictionary:
	if demo_seg2 and ghosts_spawned == 0 and sim.mode == "FIGHT" and sim.tick % 60 == 0 and sim.cast.is_empty():
		sim.tension = maxf(sim.tension, 100.0)            # the aid keeps the bar full until the T3 cast has gone up once
		return {"move": Vector2(0, -1), "punch": "R_UPPERCUT", "lb": true}   # LB + uppercut = RISE: Relay: North Star, the FULL RELAY's
	if demo_zone and sim.mode == "FIGHT" and sim.tick % 60 == 0 and sim.tform.is_empty() and sim.cast.is_empty() and sim.transform_tier(sim.pname()) != "" and not sim.transformed.has(sim.pname()) and (not demo_clash or sim.btform.has("manifest")):
		sim.tension = maxf(sim.tension, 100.0)            # the aid tops the bar up for whoever is out with the Zone unlocked, once each
		return {"surge": true}                            # the SURGE (LB + both sticks)
	if demo_hybrid and sim.mode == "FIGHT" and sim.tick % 60 == 0 and sim.cast.is_empty() and hybrid_topped != sim.seg_idx and sim.hybrid_move().size() > 0:
		sim.tension = maxf(sim.tension, 100.0); hybrid_topped = sim.seg_idx   # the aid tops the bar up once a segment while the pair's hybrid is live (the profile casts it)
	if demo_anti and demo_log.size() > 0 and sim.mode == "OVER" and sim.academy_left_behind().is_empty():   # PAC-102: the aid turns the arc only once the club has left someone waiting
		var held: Dictionary = demo_log[sim.tick % demo_log.size()].duplicate(); held.erase("story"); return held
	if demo_log.size() > 0: return demo_log[sim.tick % demo_log.size()]
	var inp := combat_input.take_intent()
	inp["audio_assist"] = audio_assist
	if q_punch != "": inp["punch"] = q_punch; q_punch = ""
	if q_dodge != "": inp["dodge"] = q_dodge; q_dodge = ""
	if q_taunt: inp["taunt"] = true; q_taunt = false
	if q_corner > 0: inp["corner"] = q_corner; q_corner = 0
	if q_sprint: inp["sprint"] = true; q_sprint = false
	if q_release: inp["punch_release"] = true; q_release = false
	if q_action.size() > 0: inp["corner_action"] = q_action; q_action = {}
	if q_clinch: inp["clinch"] = true; q_clinch = false
	if q_surge: inp["surge"] = true; q_surge = false
	return inp

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		controls_menu.open(); return
	if controls_menu.opened or sim == null: return
	# H+Y remains SURGE; ordinary Y now also exposes the left uppercut.
	if e is InputEventKey and e.keycode == KEY_Y and e.pressed and (combat_input.down("lb") or Input.is_key_pressed(KEY_H)):
		q_surge = true; return
	combat_input.tuning = sim.T
	if combat_input.handle_event(e, Time.get_ticks_usec(), sim.mode in ["FIGHT", "CLASH"] and not formation_open): return
	if e is InputEventKey and e.pressed and not e.echo:
		if sim.mode == "OVER" and e.keycode == KEY_T: _train_key()              # PAC-089: a training slot between duals
		elif e.keycode == KEY_T: q_taunt = true
		elif e.keycode == KEY_CTRL: q_sprint = true
		elif e.keycode == KEY_G: q_clinch = true
		elif e.keycode == KEY_Y and Input.is_key_pressed(KEY_H): q_surge = true                         # PAC-082: H + Y = the SURGE (LB + both sticks)
		elif e.keycode == KEY_F8: audio_assist = not audio_assist; feed.text = "audio-assist tell cue: " + ("ON" if audio_assist else "OFF")
		elif formation_open and e.keycode >= KEY_1 and e.keycode <= KEY_6: _formation_pick(e.keycode - KEY_1)   # NP_10 s2: the named orders (5 = the card order, 6 = the Gym Wall's suggestion)
		elif formation_open and e.keycode == KEY_ENTER: formation_open = false; feed.text = "THE BELL - the orders are sealed"
		elif e.keycode == KEY_TAB: show_formation = not show_formation
		elif exh != null and e.keycode == KEY_BACKSLASH and not exh.over: exh.swap_control(); sim = exh.ctrl_sim(); _exh_swapped(); _consume_exh()   # PAC-088: the pad takes the other pair
		elif exh != null and e.keycode == KEY_F5 and not e.shift_pressed: exh.restart(); sim = exh.ctrl_sim(); _exh_swapped(); _consume_exh(); _consume_events()
		elif exh != null and (e.keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F7, KEY_F10, KEY_F11] or (e.keycode == KEY_F6 and not e.shift_pressed) or (e.keycode == KEY_F5 and e.shift_pressed)): feed.text = "EXHIBITION - two engagements under one bell: F5 again, F9 back to the rotation formats (no boss switch, bouts or mid-fight save here)"
		elif sim.mode == "OVER" and e.keycode == KEY_L: _recruit_key(true)      # NP_08 s2.1: approach the flagged
		elif sim.mode == "OVER" and e.keycode == KEY_P: _recruit_key(false)     # ...and recruit the ready
		elif sim.mode == "OVER" and e.keycode == KEY_F: _forge_key()            # PAC-087: NP_08 s6 - the Forge, the first pair it takes
		elif sim.mode == "OVER" and e.keycode >= KEY_1 and e.keycode <= KEY_5: _renovate_key(e.keycode - KEY_1 + 1)   # PAC-089: NP_10 s7 - a track's next tier
		elif sim.mode == "OVER" and e.keycode == KEY_N: _grow_key("respec" if e.shift_pressed else "node")   # PAC-090: NP_11 s3 - the board (Shift: respec at the Film Room)
		elif sim.mode == "OVER" and e.keycode == KEY_Z: _grow_key("raise")                              # PAC-090: NP_11 s6 - the Beans' own sink
		elif sim.mode == "OVER" and e.keycode == KEY_X: _grow_key("ascend")                             # PAC-090: NP_11 s4 - rarity
		elif sim.mode == "OVER" and e.keycode == KEY_M: _grow_key("mirror")                             # PAC-090: the mirror spar (the Legend's trial)
		elif sim.mode == "OVER" and e.keycode == KEY_BRACKETLEFT: _teach_key("buy")                     # PAC-091: NP_11 s8 - the HBP shop, the aid's pick
		elif sim.mode == "OVER" and e.keycode == KEY_BRACKETRIGHT: _teach_key("lesson")                 # ...a master's lesson open
		elif sim.mode == "OVER" and e.keycode == KEY_APOSTROPHE: _teach_key("tape")                     # ...a fight tape
		elif sim.mode == "OVER" and e.keycode == KEY_SLASH: _teach_key("reteach")                       # ...a stablemate's technique, in a training slot
		elif sim.mode == "OVER" and e.keycode == KEY_EQUAL: _teach_key("equip")                         # ...the next learned into a free slot
		elif sim.mode == "OVER" and e.keycode == KEY_MINUS: _teach_key("unequip")                       # ...the kit's last put down
		elif sim.mode == "OVER" and exh == null and e.keycode == KEY_BACKSLASH: _gear_key("buy")        # PAC-094: NP_11 s5 - the gear shop's pick
		elif sim.mode == "OVER" and e.keycode == KEY_COMMA: _gear_key("off" if e.shift_pressed else "wear")   # ...the best free piece on, or the last off
		elif sim.mode == "OVER" and e.keycode == KEY_QUOTELEFT: _scout_key(e.shift_pressed)              # PAC-098: NP_08 s2.4 - a pull (Shift: sign the open mat's first)
		elif sim.mode == "OVER" and e.keycode == KEY_7: _role_key(e.shift_pressed)                      # PAC-099: NP_08 s1 - the aid's role for the bench (Shift: the last set back to the ring)
		elif e.keycode == KEY_BACKSPACE and sim.bout.size() > 0: _flee_key()                        # PAC-101: NP_02 s2.1 - the scrap walked away from
		elif sim.mode == "OVER" and e.keycode == KEY_8: _locker_key("browse")                           # PAC-100: NP_08 s4 - the locker room's browse (House, Style, Element, bond web, slot-role)
		elif sim.mode == "OVER" and e.keycode == KEY_9: _locker_key("next")                             # ...the next card's comparison card
		elif sim.mode == "OVER" and e.keycode == KEY_0: _locker_key("take_back" if e.shift_pressed else "release")   # ...the focused card released (Shift: the latest release taken back)
		elif sim.mode == "OVER" and e.keycode == KEY_PERIOD: growth_focus = (growth_focus + 1) % maxi(1, sim.dressed.size()); feed.text = "GROWTH - %s" % _focus_name()
		elif (sim.mode == "CORNER" or sim.mode == "CARD") and e.keycode == KEY_1: q_corner = 1
		elif sim.mode == "CORNER" and e.keycode >= KEY_2 and e.keycode <= KEY_4: q_action = _tactic_action(e.keycode - KEY_2)
		elif sim.mode == "CORNER" and e.keycode == KEY_5: q_action = {"kind": "super"}
		elif sim.mode == "CORNER" and e.keycode >= KEY_6 and e.keycode <= KEY_8: q_action = _staff_action(e.keycode - KEY_6)
		elif sim.mode == "CORNER" and e.keycode == KEY_9: q_action = {"kind": "save_bar"}
		elif sim.mode == "CORNER" and e.keycode == KEY_0: q_action = _swap_action()
		elif sim.mode == "CORNER" and e.keycode == KEY_M: q_action = {"kind": "delegate_all" if e.shift_pressed else "delegate"}
		elif sim.mode == "CORNER" and e.keycode == KEY_N: q_action = {"kind": "hands_on"}
		elif sim.mode == "CORNER" and e.keycode in [KEY_Z, KEY_X, KEY_C]: q_action = {"kind": "talk", "option": {KEY_Z: "plan", KEY_X: "fire", KEY_C: "arm"}[e.keycode]}   # NP_10 s4: The Talk
		elif e.keycode == KEY_R:
			sim.T = TNBSim.load_content()["tuning"]; feed.text = "tuning hot-reloaded"
		elif e.keycode == KEY_F5 and e.shift_pressed:                              # Shift+F5: the save (NP_11 s9) - the ledgers, and the fight in flight beneath them
			feed.text = ("SAVED %s :: %s" % [SAVE_PATH, TNBSave.summary(sim)]) if TNBSave.write_file(SAVE_PATH, sim, true) else "SAVE FAILED :: could not write %s" % SAVE_PATH
		elif e.keycode == KEY_F6 and e.shift_pressed:                                  # Shift+F6: the save back - a fight in flight resumes where it was
			if exh != null: exh = null; partner.queue_free(); partner_boss.queue_free(); partner = null; partner_boss = null
			_load_save(SAVE_PATH)
		elif e.keycode == KEY_F5: sim.new_dual()
		elif e.keycode >= KEY_F1 and e.keycode <= KEY_F4: sim.switch_boss(e.keycode - KEY_F1)
		elif e.keycode == KEY_F6: sim.switch_boss((sim._first_boss + TNBSim.BOSSES.size() - 1) % TNBSim.BOSSES.size())
		elif e.keycode == KEY_F7 and e.shift_pressed:                              # Shift+F7: cycle this boss's remixes (original -> each authored remix -> original)
			var rids: Array = sim.remixes_of(sim.boss_name)
			if rids.is_empty(): feed.text = "no remix authored for %s" % sim.boss_name
			else:
				var cur := str(sim.remix_for.get(sim.boss_name, ""))
				var nxt := "" if cur == rids[-1] else str(rids[(rids.find(cur) + 1) if cur != "" else 0])
				sim.set_remix(sim.boss_name, nxt); sim.new_dual(); prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
				feed.text = ("REMIX: " + nxt) if nxt != "" else "the original pattern"
		elif e.keycode == KEY_F7: sim.switch_boss((sim._first_boss + 1) % TNBSim.BOSSES.size())
		elif e.keycode == KEY_F10:                                            # Ep1's bouts by name, then the dual again
			ep1_i = (ep1_i + 1) % EP1_CYCLE.size()
			if EP1_CYCLE[ep1_i] == "": sim.end_bout(); feed.text = "back to the dual"
			else: sim.start_ep1(EP1_CYCLE[ep1_i])
			prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
		elif e.keycode == KEY_F11:                                            # the next scrap objective on this boss
			var ids: Array = sim.SCRAPS.keys(); ids.sort()
			for tries in ids.size():
				scr_i = (scr_i + 1) % ids.size()
				if sim.start_scrap(str(ids[scr_i]), sim._first_boss, "", {}, "", district_arg): break
			prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
		elif e.keycode == KEY_F12:                                            # the Scout Book: his page at PI 3, else where the ledger stands (NP_02 s3)
			var pg: Dictionary = sim.scout_page(sim.boss_name, str(sim.bremix.get("id", "")))
			if pg.is_empty():
				var rec: Dictionary = sim.pi.get("dialects", {}).get(sim.bdialect, {})
				feed.text = "SCOUT BOOK: no page for %s yet (beat him in a dual segment) - PI %d vs the %s dialect: scraps %d, spars %d, segments %d" % [sim.boss_name, sim.pi_vs(), sim.bdialect.capitalize(), int(rec.get("scraps", 0)), int(rec.get("spars", 0)), int(rec.get("segments", 0))]
			else:
				var tl: Array = []
				for t in pg["tells"]: tl.append("%s %s %dms (%s)" % [str(t["string"]), str(t["class"]), int(t["tell_ms"]), str(t["motif"])])
				feed.text = "SCOUT BOOK %s%s (%s / %s / House %s), %s :: TELLS %s :: %s :: %s :: desperation %s :: corner %s - %s%s" % [pg["boss"], (" [" + str(pg["remix_label"]) + "]") if str(pg["remix"]) != "" else "", pg["style"], pg["element"], str(pg["house"]).capitalize(), pg["hand"], " | ".join(PackedStringArray(tl)), " | ".join(PackedStringArray(pg["phases"])) if pg["phases"].size() > 0 else "one phase", " | ".join(PackedStringArray(pg["hooks"])), pg["desperation"], pg["corner"], pg["corner_tell"], (" :: REMIX NOTES " + " | ".join(PackedStringArray(pg["remix_notes"]))) if str(pg["remix"]) != "" else ""]
		elif e.keycode == KEY_F9:                                             # cycle the dual format (NP_01 s2/s8)
			var cur := fmt_id if fmt_id != "" else "mini"
			fmt_id = FORMAT_CYCLE[(FORMAT_CYCLE.find(cur) + 1) % FORMAT_CYCLE.size()]
			var first: int = sim._first_boss
			var ledger: Dictionary = sim.pi; var remixes_kept: Dictionary = sim.remix_for; var rewards_kept: Dictionary = sim.rewards
			if exh != null:                                                                           # PAC-088: out of the exhibition - its ledger carried, the other pair's bodies gone
				exh = null; partner.queue_free(); partner_boss.queue_free(); partner = null; partner_boss = null
			sim = TNBSim.new()
			sim.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, roster_for(fmt_id), first, int(Time.get_ticks_usec() % 2147483647), content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt_id, content.get("bouts", {}), content.get("scraps", {}),
				content.get("pattern_intel", {}), ledger, content.get("remixes", {}), content.get("economy", {}), rewards_kept, remixes_kept, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), {}, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
			prev_p = sim.P["pos"]; prev_b = sim.B["pos"]; ghosts_spawned = 0
			feed.text = "FORMAT: %s - %d segments, %d dressed%s" % [str(sim.fmt.get("label", fmt_id)), sim.segments(), sim.dressed.size(), "  (repeat slots, condition carries)" if sim.fmt.get("repeat_slots", false) else ""]
	if e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_DPAD_UP: q_taunt = true
		elif (e.button_index == JOY_BUTTON_LEFT_STICK or e.button_index == JOY_BUTTON_RIGHT_STICK) and Input.is_joy_button_pressed(e.device, JOY_BUTTON_LEFT_SHOULDER) \
			and Input.is_joy_button_pressed(e.device, JOY_BUTTON_LEFT_STICK) and Input.is_joy_button_pressed(e.device, JOY_BUTTON_RIGHT_STICK): q_surge = true   # PAC-082: LB + both sticks = the SURGE
		elif e.button_index == JOY_BUTTON_LEFT_STICK: q_sprint = true
		elif e.button_index == JOY_BUTTON_RIGHT_STICK: q_clinch = true
		elif e.button_index == JOY_BUTTON_A and (sim.mode == "CORNER" or sim.mode == "CARD"): q_corner = 1
		elif e.button_index == JOY_BUTTON_X and sim.mode == "CORNER": q_action = _swap_action()
		elif e.button_index == JOY_BUTTON_Y and sim.mode == "CORNER": q_action = {"kind": "super"}
		elif e.button_index == JOY_BUTTON_B and sim.mode == "CORNER": q_action = {"kind": "save_bar"}
		elif e.button_index == JOY_BUTTON_DPAD_LEFT and sim.mode == "CORNER": q_action = _tactic_action(0)
		elif e.button_index == JOY_BUTTON_DPAD_RIGHT and sim.mode == "CORNER": q_action = _tactic_action(1)
		elif e.button_index == JOY_BUTTON_DPAD_DOWN and sim.mode == "CORNER": q_action = _staff_action(0)
		elif e.button_index == JOY_BUTTON_LEFT_SHOULDER and sim.mode == "CORNER": q_action = {"kind": "talk", "option": "plan"}
		elif e.button_index == JOY_BUTTON_RIGHT_SHOULDER and sim.mode == "CORNER": q_action = {"kind": "talk", "option": "fire"}
		elif e.button_index == JOY_BUTTON_BACK and sim.mode == "CORNER": q_action = {"kind": "talk", "option": "arm"}
	if e is InputEventJoypadMotion and _trigger(JOY_AXIS_TRIGGER_LEFT, KEY_C):
		if e.axis == JOY_AXIS_LEFT_X and absf(e.axis_value) > 0.7: q_dodge = "SLIP_R" if e.axis_value > 0.0 else "SLIP_L"
		elif e.axis == JOY_AXIS_LEFT_Y and e.axis_value < -0.7: q_dodge = "WEAVE_R"
		elif e.axis == JOY_AXIS_LEFT_Y and e.axis_value > 0.7: q_dodge = "LEAN"

func _set_remix_arg(v: String) -> void:
	if v == "all":
		for rid in sim.REMIX.get("remixes", {}): sim.set_remix(str(sim.REMIX["remixes"][rid].get("base", "")), str(rid))
	else:
		var rec: Dictionary = sim.REMIX.get("remixes", {}).get(v, {})
		if rec.size() > 0: sim.set_remix(str(rec.get("base", "")), v)
	sim.new_dual()

func _load_save(path: String) -> bool:
	# the save read and built into a new sim (its own seed; a fight in flight restores to the hash it was saved at)
	var rd: Dictionary = TNBSave.read_file(path)
	if not bool(rd["ok"]): feed.text = "NOT LOADED %s :: %s" % [path, str(rd["why"])]; return false
	var built: Dictionary = TNBSave.build(content, rd, int(Time.get_ticks_usec() % 2147483647))
	sim = built["sim"]; fmt_id = str(sim.fmt.get("id", "mini"))
	prev_p = sim.P["pos"]; prev_b = sim.B["pos"]; ghosts_spawned = 0; matchup_until = 0; toast_until = 0; pi_toast_until = 0
	var r: Dictionary = built["restored"]
	feed.text = "LOADED %s :: %s%s" % [path, TNBSave.summary(sim), ("  [resumed at tick %d, hash %s]" % [int(r.get("tick", 0)), "the same" if bool(r.get("same", false)) else "DIFFERENT"]) if r.size() > 0 and bool(r.get("ok", false)) else ((" - " + str(r.get("why", ""))) if r.size() > 0 else "")]
	return true

func _tactic_action(i: int) -> Dictionary:
	var o: Dictionary = sim.corner_options()
	return {"kind": "tactic", "id": o["tactic"][i]["id"]} if i < o["tactic"].size() else {}

func _staff_action(i: int) -> Dictionary:
	var o: Dictionary = sim.corner_options()
	return {"kind": "staff", "id": o["staff"][i]["id"]} if i < o["staff"].size() else {}

func _swap_action() -> Dictionary:
	var o: Dictionary = sim.corner_options()
	return {"kind": "swap", "arg": o["swap"][0]} if o["swap"].size() > 0 else {}

func _relay_open_line() -> String:
	# NP_05 s6: the T3s the relay opens to the fighter out CHARGED, on the matchup card
	var rl: String = sim.relay_line()
	if rl == "": return ""
	return "\n    RELAY (chain %d%s): %s" % [int(sim.relay_chain), ", FULL RELAY" if sim.full_relay else "", rl]

func _duo_line() -> String:
	# NP_08 s5.2 Lv4: the Duo relay live this segment, on the matchup card
	var dm: Dictionary = sim.duo_move()
	if dm.is_empty(): return ""
	return "\n    DUO: %s -> %s (Lv%d) - %s live: LB + %s, %d Tension (%s)" % [str(sim.duo["partner"]), str(sim.duo["caster"]), int(sim.duo["level"]), str(dm["name"]).to_upper(), str(dm["family"]), int(sim.hiss_cost(dm)), str(dm["duo_of"])]

func _traits_line() -> String:
	# NP_07 s3: the trait each corner's fighter carries this segment, on the matchup card
	var parts: Array = []
	if sim.P.get("trait", {}).size() > 0: parts.append("%s %s%s" % [sim.pname(), str(sim.P["trait"]["name"]), " (doubled)" if int(sim.P["trait"]["x"]) > 1 else ""])
	if sim.B.get("trait", {}).size() > 0: parts.append("%s %s%s" % [sim.boss_label, str(sim.B["trait"]["name"]), " (doubled)" if int(sim.B["trait"]["x"]) > 1 else ""])
	return ("\n    TRAITS: " + " | ".join(PackedStringArray(parts))) if parts.size() > 0 else ""

func _scout_key(sign: bool) -> void:
	# PAC-098: the scouting machine's pull, or the open mat's first signed
	var r: Dictionary = sim.sign_generic(0) if sign else sim.scout_pull()
	_consume_events()
	if not bool(r.get("ok", false)): feed.text = ("THE OPEN MAT - " if sign else "THE MACHINE - ") + str(r.get("why", ""))

func _role_key(back: bool) -> void:
	# PAC-099: the bench's next role (the aid's pick), or the last one set back to the ring
	var r: Dictionary = sim.role_back() if back else sim.assign_role("*")
	_consume_events()
	if not bool(r.get("ok", false)): feed.text = "THE ROLES - " + str(r.get("why", ""))

func _flee_key() -> void:
	# PAC-101: a scrap fled - free before the first exchange, a point of the district's rep after
	var r: Dictionary = sim.flee()
	_consume_events()
	if not bool(r.get("ok", false)): feed.text = "FLEE - " + str(r.get("why", ""))

func _locker_focus() -> String:
	# PAC-100: the focused card - kept while in the stable, else the first on the bench, else the first card
	if locker_focus != "" and sim._stable_card(locker_focus).size() > 0: return locker_focus
	for c in sim.stable:
		if not sim._is_dressed(str(c["name"])): return str(c["name"])
	return str(sim.stable[0]["name"]) if sim.stable.size() > 0 else ""

func _locker_key(what: String) -> void:
	# PAC-100: NP_08 s4 - browse, the next card, release the focused card, take the latest back
	var by: Array = sim.ECO.get("locker", {}).get("browse", ["house"])
	match what:
		"browse": locker_by = (locker_by + 1) % maxi(1, by.size()); feed.text = "THE LOCKER ROOM - by %s" % str(by[locker_by])
		"next":
			var nm := _locker_focus(); var i := 0
			for j in sim.stable.size():
				if str(sim.stable[j]["name"]) == nm: i = j
			locker_focus = str(sim.stable[(i + 1) % maxi(1, sim.stable.size())]["name"]) if sim.stable.size() > 0 else ""
			feed.text = "THE LOCKER ROOM - %s" % locker_focus
		"release":
			var r: Dictionary = sim.release(_locker_focus())
			_consume_events()
			if not bool(r["ok"]): feed.text = "THE LOCKER ROOM - " + str(r["why"])
			else: locker_focus = ""
		"take_back":
			var r2: Dictionary = sim.take_back("*")
			_consume_events()
			if not bool(r2["ok"]): feed.text = "THE LOCKER ROOM - " + str(r2["why"])

func _forge_key() -> void:
	var r: Dictionary = sim.forge("*")
	_consume_events()
	if not bool(r["ok"]): feed.text = "THE FORGE - " + str(r["why"])

func _renovate_key(n: int) -> void:
	var r: Dictionary = sim.renovate(str(n))
	_consume_events()
	if not bool(r["ok"]): feed.text = "THE OLD GYM - " + str(r["why"])

func _kit_summary() -> Dictionary:
	# the soak's line: each dressed card's kit
	var out := {}
	for c in sim.dressed: out[str(c["name"])] = sim.kit_moves(str(c["name"]))
	return out

func _growth_summary() -> Dictionary:
	# the soak's line: each dressed card's rarity, points spent and passives
	var out := {}
	for c in sim.dressed:
		var nm := str(c["name"])
		out[nm] = "T%d %d/%d %s" % [sim.rarity_of(nm), int(sim._grow(nm).get("spent", 0)), sim.gpoints(nm), "+".join(PackedStringArray(sim.passives_of(nm)))]
	return out

func _teach_key(kind: String) -> void:
	# PAC-091: the technique keys on the focused card
	var nm := _focus_name()
	var r: Dictionary = {}
	match kind:
		"buy": r = sim.buy(nm, "*")
		"lesson": r = sim.lesson("*", nm, "")
		"tape": r = sim.use_tape(nm, "*")
		"reteach": r = sim.reteach("*", nm, "*")
		"equip": r = sim.kit_equip(nm, "*") if sim.kit_best(nm) != "" else {"ok": false, "why": "%s has nothing learned to carry, or no room for it" % nm}
		"unequip": r = sim.kit_unequip(nm, "*")
	_consume_events()
	if not bool(r.get("ok", false)): feed.text = "TECHNIQUES - " + str(r.get("why", ""))

func _gear_key(kind: String) -> void:
	# PAC-094: the gear keys on the focused card
	var nm := _focus_name()
	var r: Dictionary = {}
	match kind:
		"buy": r = sim.buy_gear("*", nm)
		"wear": r = sim.wear(nm, "*")
		"off": r = sim.take_off(nm, "*")
	_consume_events()
	_dress_gear(player, sim.gear_worn(nm))
	if not bool(r.get("ok", false)): feed.text = "GEAR - " + str(r.get("why", ""))

func _dress_gear(root: Node3D, items: Array) -> void:
	# PAC-094: the figure wears its pieces in their colours - gloves at the hands, wraps behind them, a mouthguard at the jaw, a robe
	# over the body at the walk-out (the greybox's cosmetic: NP_11 s5's gear is cosmetic-forward)
	for ch in root.get_children():
		if ch.has_meta("gear"): ch.queue_free(); root.remove_child(ch)
	for id in items:
		var it: Dictionary = sim.gear_item(str(id))
		if it.is_empty(): continue
		var col := Color(str(it.get("color", "#999999")))
		var mat := StandardMaterial3D.new(); mat.albedo_color = col
		var parts: Array = []
		match str(it["kind"]):
			"gloves":
				for sx in [-1.0, 1.0]:
					var sp := SphereMesh.new(); sp.radius = 0.12; sp.height = 0.24; sp.material = mat; parts.append([sp, Vector3(0.4 * sx, 1.25, -0.15)])
			"wraps":
				for sx in [-1.0, 1.0]:
					var cy := CylinderMesh.new(); cy.top_radius = 0.075; cy.bottom_radius = 0.075; cy.height = 0.12; cy.material = mat; parts.append([cy, Vector3(0.4 * sx, 1.08, -0.12)])
			"mouthguard":
				var bx := BoxMesh.new(); bx.size = Vector3(0.14, 0.04, 0.04); bx.material = mat; parts.append([bx, Vector3(0.0, TNBSim.HEAD_H - 0.08, -0.17)])
			"robe":
				var rb := CylinderMesh.new(); rb.top_radius = 0.4; rb.bottom_radius = 0.46; rb.height = 1.1; rb.material = mat; parts.append([rb, Vector3(0.0, 0.6, 0.0)])
		for pr in parts:
			var m := MeshInstance3D.new(); m.mesh = pr[0]; m.position = pr[1]
			m.set_meta("gear", str(id)); m.set_meta("kind", str(it["kind"])); m.set_meta("color", col)
			root.add_child(m)

func _focus_name() -> String:
	return str(sim.dressed[clampi(growth_focus, 0, sim.dressed.size() - 1)]["name"]) if sim.dressed.size() > 0 else ""

func _grow_key(kind: String) -> void:
	# PAC-090: the growth keys on the focused card
	var nm := _focus_name()
	var r: Dictionary = {}
	match kind:
		"node": r = sim.take_node(nm, "*")
		"respec": r = sim.respec(nm)
		"raise": r = sim.raise_stat(nm, "*")
		"ascend": r = sim.ascend(nm)
		"mirror":
			if sim.mode == "OVER" and str(sim.bout.get("card", {}).get("mirror_of", "")) != "":     # PAC-093: after the mirror, [M] takes you back to the dual
				sim.end_bout(); prev_p = sim.P["pos"]; prev_b = sim.B["pos"]; _consume_events(); feed.text = "back to the dual"
				return
			r = {"ok": sim.start_mirror(nm), "why": "no mirror for %s in this build" % nm}
			if bool(r["ok"]): prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
	_consume_events()
	if not bool(r.get("ok", false)): feed.text = "GROWTH - " + str(r.get("why", ""))
	elif kind == "mirror": feed.text = "THE MIRROR - %s against %s'S MIRROR (win it: the Legend's trial)" % [nm, nm]

func _train_key() -> void:
	var r: Dictionary = sim.train("*", "*", 0.75)
	_consume_events()
	if not bool(r["ok"]): feed.text = "TRAINING - " + str(r["why"])

func _recruit_key(approach: bool) -> void:
	var r: Dictionary = sim.approach("*") if approach else sim.recruit("*")
	_consume_events()
	if not bool(r["ok"]): feed.text = str(r["why"])

func _formation_pick(i: int) -> void:
	# the whiteboard: a named order sealed over the dressed (the sim sets the dual up again from the same RNG position), or the card order back
	var order: Array = sim.FORMATION.get("order", [])
	var b := {}
	if i < order.size(): b = {"archetype": str(order[i])}
	elif i == order.size() + 1: b = {"archetype": "GYM_WALL"}                                          # PAC-079: 6 - the wall's proximities (NP_10 s2)
	else:
		var st: Array = []
		for f in sim.dressed:
			if not bool(f.get("reserve", false)) and st.size() < sim.board_k(): st.append(str(f["name"]))
		b = {"slots": st}
	var kept: Array = sim.board.get("staff", [])
	if kept.size() > 0: b["staff"] = kept
	var r: Dictionary = sim.seal_board(b)
	_consume_events()
	if not bool(r["ok"]): feed.text = "BOARD REFUSED - " + str(r["why"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		combat_input.clear(true)
		if controls_menu != null: controls_menu.open()

func set_practice(enabled: bool) -> void:
	practice_dummy = enabled
	if controls_menu != null: controls_menu.practice.set_pressed_no_signal(enabled)
	if not enabled and not practice_restore.is_empty():
		for key in practice_restore: sim.set(key, practice_restore[key])
		practice_restore.clear()
	combat_input.clear()

func _hold_dummy() -> void:
	# Practice is a scene mode; it never rewrites the roster, tuning, or boss patterns.
	if practice_restore.is_empty():
		for key in ["hooks_enabled", "coach_on", "neutral_on", "clock_t", "bstate", "btimer"]: practice_restore[key] = sim.get(key)
		practice_position = sim.B["pos"]
	sim.bstate = "IDLE"; sim.btimer = 1 << 30; sim.bqueue = []; sim.bpending = {}
	sim.hooks_enabled = false; sim.coach_on = false; sim.neutral_on = false
	sim.B["dodge"] = ""; sim.B["dodge_t"] = 0; sim.B["dodge_at"] = 0; sim.B["dodge_plan"] = []
	sim.B["blocking"] = false; sim.B["block_t"] = 0; sim.B["guard_t"] = 0
	sim.B["comp"] = sim.B["comp_max"]; sim.clock_t = TNBSim.ms(90000)

# ============================== LOOP ======================================
func _process(delta: float) -> void:
	if sim == null or controls_menu.opened: return
	combat_input.tuning = sim.T
	combat_input.poll_hardware(Time.get_ticks_usec())
	if formation_open:                                    # the whiteboard: nothing moves until the bell
		_render(1.0); _hud(); return
	var n := clock.advance(delta)
	for i in n:
		prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
		if exh != null:                                                                                   # PAC-088: the exhibition steps both pairs; the pad plays one
			var q0: TNBSim = exh.e(exh.other(exh.ctrl)); prev_q = q0.P["pos"]; prev_qb = q0.B["pos"]
			if demo_exh: _exh_aid()
			var ctrl0: String = exh.ctrl
			exh.step(_intent())
			sim = exh.ctrl_sim()
			if exh.ctrl != ctrl0: _exh_swapped()
			_consume_exh()
		else:
			if practice_dummy: _hold_dummy()
			sim.step(_intent())
			if practice_dummy: sim.B["pos"] = practice_position
		_consume_events()
		if demo_saveload: _demo_saveload()
	_render(clock.alpha())
	if ghost and ghost_t > 0.0:
		ghost_t -= delta
		if ghost_t <= 0.0: ghost.queue_free(); ghost = null
	if manifest_pulse > 0.0: manifest_pulse -= delta
	if bmanifest_pulse > 0.0: bmanifest_pulse -= delta
	_hud()

func _exh_aid() -> void:
	# -- demo with the exhibition: the bar topped up at ticks 600 and 2400, once each, when both pairs fight (the profiles call the duo at 90)
	var marks := [600, 2400]
	if exh_topped >= marks.size() or sim.tick < int(marks[exh_topped]): return
	if exh.a.mode == "FIGHT" and exh.b.mode == "FIGHT" and exh.window.is_empty() and exh.a.cast.is_empty() and exh.b.cast.is_empty():
		exh.set_team(100.0); exh_topped += 1

func _exh_swapped() -> void:
	# the pad took the other pair (\, or its own pair finished): the bodies swap halves - the capsules follow the sims
	var q: TNBSim = exh.e(exh.other(exh.ctrl))
	prev_p = sim.P["pos"]; prev_b = sim.B["pos"]; prev_q = q.P["pos"]; prev_qb = q.B["pos"]
	var pm: StandardMaterial3D = player.get_meta("mat"); pm.albedo_color = _base_color("P")
	var qm: StandardMaterial3D = partner.get_meta("mat"); qm.albedo_color = COLORS.get(q.pname(), Color(0.55, 0.6, 0.7))
	matchup_until = 0

func _consume_exh() -> void:
	# PAC-088: the coordinator's events (the window, the sync, the miss, the shared wall, control, the verdict) and the other pair's
	for ev in exh.events:
		fx_counts[ev["kind"]] = int(fx_counts.get(ev["kind"], 0)) + 1
		match str(ev["kind"]):
			"duo_sync":
				toast_text = "DUO SYNC  %s calls %s - %s has %.1fs%s" % [str(ev["who"]), str(ev["move"]).to_upper(), str(ev["partner"]), float(ev["ms"]) / 1000.0, " (his profile answers)" if bool(ev["ai"]) else " (the same motion)"]; toast_until = sim.tick + TNBSim.ms(1500); _flash(0.15)
			"duo_cast":
				duo_syncs.append("%s by %s at %dms (bar %d)" % [str(ev["move"]), str(ev["by"]), int(ev["ms"]), int(ev["bar"])])
				toast_text = "DUO SYNC  %s  - %s together (%s), %d off the bar once" % [str(ev["move"]).to_upper(), str(ev["pair"]).replace("|", " & "), {"hands": "both hands, %d ms apart" % int(ev["ms"]), "ai": "the partner answered at %d ms" % int(ev["ms"]), "manager": "the profiles' call"}.get(str(ev["by"]), ""), int(ev["cost"])]; toast_until = sim.tick + TNBSim.ms(4000); _flash(0.7)
			"duo_missed":
				duo_misses.append(str(ev["why"]))
				toast_text = "DUO SYNC MISSED  %s - %s's motion goes as his own" % [str(ev["why"]), str(ev["who"])]; toast_until = sim.tick + TNBSim.ms(3000)
			"duo_wall_linked":
				toast_text = "TWO-HAND WINTER  one gauge, %d pts - both behind it (the only shared gauge)" % int(ev["pts"]); toast_until = sim.tick + TNBSim.ms(4000); _flash(0.4)
			"hosting_refused":                                                                         # PAC-089: The Ring's tier hosts the exhibition at home
				toast_text = "EXHIBITION  " + str(ev["why"]); toast_until = sim.tick + TNBSim.ms(5000)
			"control":
				feed.text = "YOU PLAY %s%s" % [str(ev["who"]), " - the manager's seat: both on their profiles" if bool(ev["manager"]) else " - %s on his profile" % str(ev["partner"])]
			"exhibition_end":
				toast_text = "%s   TEAM SCORE %d-%d (%s %d-%d, %s %d-%d)" % [str(ev["verdict"]), int(ev["score"][0]), int(ev["score"][1]), str(ev["pairs"][0][0]), int(ev["pairs"][0][2]), int(ev["pairs"][0][3]), str(ev["pairs"][1][0]), int(ev["pairs"][1][2]), int(ev["pairs"][1][3])]; toast_until = sim.tick + TNBSim.ms(8000); _flash(0.5)
	exh.events.clear()
	var q: TNBSim = exh.e(exh.other(exh.ctrl))
	for ev in q.events:
		fx_counts[ev["kind"]] = int(fx_counts.get(ev["kind"], 0)) + 1
		match str(ev["kind"]):
			"hit": _bump(partner_boss if str(ev["on"]) == "B" else partner, 0.12)
			"drop": _bump(partner_boss if str(ev["who"]) == "B" else partner, 0.5); feed.text = "[PAIR %s] %s - %s" % [exh.other(exh.ctrl), "%s DOWN" % (q.boss_label if str(ev["who"]) == "B" else q.pname()), "score %d-%d" % [q.score_p, q.score_b]]
			"engagement_end": feed.text = "[PAIR %s] %s vs %s over: %d-%d%s" % [exh.other(exh.ctrl), q.pname(), q.boss_label, int(ev["score"][0]), int(ev["score"][1]), " - a KO" if bool(ev["ko"]) else ""]
			"reward_toast": toast_text = "REWARD  " + str(ev["text"]); toast_until = sim.tick + TNBSim.ms(6000)   # the exhibition pays from pair A's ledger
	q.events.clear()

func _demo_saveload() -> void:
	# the soak's resume: the fight saved at tick 3,000, the scene runs on to 3,600, the save is loaded back and the log continues from 3,000
	if not demo_saved and sim.tick == 3000:
		demo_saved = TNBSave.write_file(SAVE_PATH, sim, true); demo_saved_hash = sim.hash_state()
		demo_saveload_line = "saved at tick 3000 (hash %d, %s)" % [demo_saved_hash, "written" if demo_saved else "NOT WRITTEN"]
	elif demo_saved and not demo_loaded and sim.tick == 3600:
		demo_loaded = true
		var ok := _load_save(SAVE_PATH)
		demo_saveload_line += "; loaded at 3600 -> tick %d, hash %d (%s)" % [sim.tick, sim.hash_state(), "the same" if ok and sim.hash_state() == demo_saved_hash else "DIFFERENT"]
		print("SAVE/LOAD :: " + demo_saveload_line)

func _to3(v: Vector2, tag: String = "") -> Vector3:
	# PAC-088: in the exhibition each pair is drawn in its own half of the ring (A the left, B the right), its lateral compressed
	if exh == null: return Vector3(v.x, 0.0, v.y)
	var tg: String = tag if tag != "" else str(exh.ctrl)
	return Vector3(v.x * 0.5 + (-1.75 if tg == "A" else 1.75), 0.0, v.y)

func _render(alpha: float) -> void:
	player.position = _to3(prev_p.lerp(sim.P["pos"], alpha))
	boss.position = _to3(prev_b.lerp(sim.B["pos"], alpha))
	_pose(player, sim.P, sim.B)
	_pose(boss, sim.B, sim.P)
	var pmat: StandardMaterial3D = player.get_meta("mat")
	pmat.albedo_color = _base_color("P")
	for gch in player.get_children():                                                                   # PAC-094: the robe is the walk-out's - off once the bell's card is down
		if gch.has_meta("gear") and str(gch.get_meta("kind")) == "robe": gch.visible = sim.mode == "OVER" or sim.tick < matchup_until
	var el_z := str(sim.P.get("element", "NONE"))                                                   # PAC-082: the Zone's single-colour aura seep in his element; the Comedown dims him
	pmat.emission_enabled = sim.tform.size() > 0
	if sim.tform.size() > 0: pmat.emission = ELEMENT_TINT.get(el_z, Color(0.9, 0.9, 1.0)); pmat.emission_energy_multiplier = 1.4 if sim.tform.has("meter") else 0.8
	if sim.tform.has("inherit"): pmat.emission = _inherit_color(); pmat.emission_energy_multiplier = 0.9       # PAC-084: he wears the source's style
	if sim.tform.has("form"): pmat.emission_energy_multiplier = 2.2                                             # PAC-085: Awakened, the brightest
	var fm2: StandardMaterial3D = ring_floor.mesh.material                                                     # PAC-085: the arena taken over in his element
	fm2.emission_enabled = sim.tform.has("form")
	if sim.tform.has("form"): fm2.emission = ELEMENT_TINT.get(el_z, Color(0.9, 0.9, 1.0)); fm2.emission_energy_multiplier = 0.7
	elif sim.comedown.size() > 0: pmat.albedo_color = pmat.albedo_color.darkened(0.3)
	var back: Vector3 = (player.position - boss.position).normalized()
	if back.length() < 0.5: back = Vector3(0, 0, 1)
	_manifest_render(back, el_z)
	_inherit_render()
	var bmat: StandardMaterial3D = boss.get_meta("mat")                                                    # PAC-086: his tier in his element - gathering, transformed; his manifest behind him
	var el_b := str(sim.B.get("element", "NONE"))
	bmat.emission_enabled = sim.btform.size() > 0 or sim.btsurge.size() > 0
	if bmat.emission_enabled: bmat.emission = ELEMENT_TINT.get(el_b, Color(1.0, 0.8, 0.7)); bmat.emission_energy_multiplier = (1.4 if sim.btform.has("manifest") else 0.8) if sim.btform.size() > 0 else 0.35
	_bmanifest_render(back, el_b)
	if exh != null and partner != null:                                                              # PAC-088: the other pair, its own half of the ring
		var qt: String = exh.other(exh.ctrl); var q: TNBSim = exh.e(qt)
		partner.position = _to3(prev_q.lerp(q.P["pos"], alpha), qt); partner_boss.position = _to3(prev_qb.lerp(q.B["pos"], alpha), qt)
		_pose(partner, q.P, q.B); _pose(partner_boss, q.B, q.P)
		var qm: StandardMaterial3D = partner.get_meta("mat")
		qm.albedo_color = COLORS.get(q.pname(), Color(0.55, 0.6, 0.7)).darkened(0.45 if q.mode == "OVER" else 0.0)
		qm.emission_enabled = q.cast.size() > 0 and str(q.cast["who"]) == "P" and str(q.cast["move"].get("duo_sync", "")) != ""
		if qm.emission_enabled: qm.emission = Color(1.0, 0.82, 0.35); qm.emission_energy_multiplier = 1.8   # the duo sync gilds both halves
		pmat.emission_enabled = pmat.emission_enabled or (sim.cast.size() > 0 and str(sim.cast["who"]) == "P" and str(sim.cast["move"].get("duo_sync", "")) != "")
		if sim.cast.size() > 0 and str(sim.cast["move"].get("duo_sync", "")) != "" and sim.tform.is_empty(): pmat.emission = Color(1.0, 0.82, 0.35); pmat.emission_energy_multiplier = 1.8
		var qbm: StandardMaterial3D = partner_boss.get_meta("mat"); qbm.albedo_color = BOSS_COLOR.darkened(0.45 if q.mode == "OVER" else 0.15)
	cam.position = player.position + back * 1.8 + Vector3(0, 1.5, 0)
	var target := boss.position + Vector3(0, 1.2, 0)
	if Vector2(target.x - cam.position.x, target.z - cam.position.z).length() > 0.05:
		cam.look_at(target)

func _pose(n: Node3D, F: Dictionary, other: Dictionary) -> void:
	# the head sphere sits where the sim says the head is: dodges are visible, not implied
	var head: MeshInstance3D = n.get_meta("head")
	var mesh: MeshInstance3D = n.get_meta("mesh")
	var fwd: Vector2 = (other["pos"] - F["pos"]).normalized()
	var right := Vector2(fwd.y, -fwd.x)
	var lat := 0.0; var h := TNBSim.HEAD_H; var back := 0.0
	if F["dodge"] != "":
		var d: Dictionary = TNBSim.DODGE[F["dodge"]]
		lat = float(d["lat"]) * float(F["dodge_dir"]); h = float(d["h"]); back = float(d["back"])
	var off: Vector2 = right * lat - fwd * back
	head.position = Vector3(off.x, h, off.y)
	mesh.scale = Vector3(1, 0.85, 1) if F["dodge"] == "DUCK" or F["dodge"] == "WEAVE" else Vector3.ONE
	if F["blocking"]: mesh.scale = Vector3(1.08, 1.0, 1.08)
	if F["guard_open_t"] > 0: mesh.scale = Vector3(0.92, 1.0, 0.92)

var fx_counts := {}
var echoes_seen := 0                 # PAC-083: the manifest's echoes the scene showed (the drive reads it)
var transforms_seen: Array = []      # PAC-083: who SURGEd into which tier this run (the soak's summary)
var btransforms_seen: Array = []     # PAC-086: the bosses' transformations this run, and what the player did against them (the soak's summary)
var weathered_seen := 0
var bechoes_seen := 0
var feats_seen: Array = []
var clashes_seen: Array = []

func _exit_tree() -> void:
	if sim != null and demo_log.size() > 0:
		print("DEMO SOAK :: %d ticks, mode=%s R%d %s vs %s, score %d-%d, ghosts %d, matchup cards %d, auto %s, PI %s, rewards %s, fx %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s" % [sim.tick, sim.mode, sim.seg_idx + 1, sim.pname(), sim.boss_name, sim.score_p, sim.score_b, ghosts_spawned, matchups_shown, JSON.stringify(sim.auto_stats) if sim.delegated else "off", JSON.stringify(sim.pi_log), JSON.stringify({"xp": sim.rewards["xp"], "spirits": sim.rewards["spirits"], "prestige": sim.rewards["prestige"], "hbp": sim.rewards["hbp"], "kizuna": sim.rewards["kizuna"], "log": sim.rewards["log"]}), JSON.stringify(fx_counts), (", save/load " + demo_saveload_line) if demo_saveload_line != "" else "", (", generic " + JSON.stringify({"name": sim.bgeneric.get("name", ""), "tier": sim.bgeneric.get("tier", 0), "dialect": sim.bgeneric.get("dialect", ""), "strings": sim.pattern["strings"].keys()})) if sim.bgeneric.size() > 0 else "", (", formation " + _formation_check()) if demo_formation else "", (", staff " + JSON.stringify({"dressed": sim.staff_dressed(), "uses": sim.rewards.get("staff", {}), "heat": snappedf(sim.crowd_heat, 0.1), "fx": sim.staff_fx.keys().filter(func(k): return k != "by")})) if staff_arg != "" else "", (", recruits " + JSON.stringify({"stable": sim.stable.map(func(x): return str(x["name"])), "ledger": sim.rewards.get("recruit", {}), "open": sim.recruit_lines(), "wall": sim.string_wall_lines(), "houses": sim.house_lines(), "gym_wall": sim.gym_wall_lines()})) if demo_recruit else "", (", gym wall " + JSON.stringify(sim.gym_wall_lines())) if wall_arg != "" or demo_formation else "", (", duo casts " + JSON.stringify(duo_casts)) if duo_casts.size() > 0 else "", (", transforms %s, echoes %d" % [JSON.stringify(transforms_seen), echoes_seen]) if transforms_seen.size() > 0 else "", (", his transforms %s, weathered %d, his echoes %d, feats %s, clashes %s" % [JSON.stringify(btransforms_seen), weathered_seen, bechoes_seen, JSON.stringify(feats_seen), JSON.stringify(clashes_seen)]) if btransforms_seen.size() > 0 else "", (", forged %s, hybrid casts %s" % [JSON.stringify(forged_seen), JSON.stringify(hybrid_casts)]) if forged_seen.size() + hybrid_casts.size() > 0 else "", (", exhibition " + JSON.stringify({"over": exh.over, "verdict": str(exh.verdict.get("verdict", "")), "score": exh.score(), "pairs": [[exh.a.pname(), exh.a.boss_name, exh.a.score_p, exh.a.score_b, exh.a.mode], [exh.b.pname(), exh.b.boss_name, exh.b.score_p, exh.b.score_b, exh.b.mode]], "duo_syncs": duo_syncs, "missed": duo_misses, "walls_shared": int(fx_counts.get("duo_wall_linked", 0)), "bar": int(exh.team)})) if exh != null else "", (", facilities " + JSON.stringify({"tiers": sim.facility_tiers(), "renovations": renovations_seen, "training": trainings_seen.size(), "beans": int(sim.rewards.get("beans", 0)), "entrances": entrances_seen, "shelf": [sim.pi.get("book", []).size(), sim.book_pages(), sim.pi.get("waiting", []).size()], "host": sim.host, "prestige": int(sim.rewards.get("prestige", 0)), "hbp": int(sim.rewards.get("hbp", 0))})) if demo_facilities or facility_arg != "" or host_home else "", (", growth " + JSON.stringify({"seen": growth_seen.size(), "last": growth_seen.slice(maxi(0, growth_seen.size() - 4)), "passives": _growth_summary(), "jar": sim.jar_text()})) if demo_growth or nodes_arg != "" or growth_arg != "" else "", (", academy " + JSON.stringify({"squad": sim.blineup, "coach": str(sim.coach.get("id", "")), "syntheses": syntheses_seen.size(), "last": syntheses_seen.slice(maxi(0, syntheses_seen.size() - 4)), "hybrid_casts": hybrid_casts.size()})) if academy_arg else "", (", techniques " + JSON.stringify({"learned": learned_seen, "kits": _kit_summary(), "kit_casts": kit_casts.size(), "last_casts": kit_casts.slice(maxi(0, kit_casts.size() - 4)), "tapes": sim.tapes(), "hbp": int(sim.rewards.get("hbp", 0))})) if demo_techniques or learn_arg != "" or tapes_arg != "" else "", (", mirror " + JSON.stringify({"spars": mirrors_seen, "counters": mirror_counters, "habits": sim.lineup.map(func(c): return sim.habits_line(str(c["name"])))})) if demo_mirror or habits_arg != "" else "", (", gear " + JSON.stringify({"log": gear_seen_log.slice(maxi(0, gear_seen_log.size() - 8)), "n": gear_seen_log.size(), "worn": _gear_summary(), "hbp": int(sim.rewards.get("hbp", 0))})) if demo_gear or gear_arg != "" else "", (", scouting " + JSON.stringify({"pulls": int(sim.rewards.get("scouting", {}).get("pulls", 0)), "leads": scout_seen.slice(maxi(0, scout_seen.size() - 6)), "rare": scout_seen.filter(func(x): return str(x).begins_with("RARE ")).size(), "signed": signed_seen, "stable": sim.stable.size(), "open_mat": sim.open_mat().size(), "prestige": int(sim.rewards.get("prestige", 0))})) if demo_scouting else "", (", roles " + JSON.stringify({"set": roles_seen, "of": sim.rewards.get("roles", {}).get("of", {}), "paid": sim.rewards.get("roles", {}).get("paid", {}), "scouted": scouted_seen, "partner_beans": partner_seen, "trainee_uses": trainee_seen, "stable": sim.stable.size(), "day": int(sim.rewards.get("day", 1))})) if demo_roles else "", (", locker " + JSON.stringify({"seen": locker_seen, "pending": sim.rewards.get("locker", {}).get("pending", {}).keys(), "memory": sim.rewards.get("locker", {}).get("memory", {}), "open_mat": sim.open_mat().map(func(c): return "%s%s" % [str(c["name"]), (":" + str(c["released"])) if c.has("released") else ""]), "stable": sim.stable.size(), "day": int(sim.rewards.get("day", 1))})) if demo_locker else "", (", rep " + JSON.stringify({"seen": rep_seen.slice(maxi(0, rep_seen.size() - 6)), "moves": rep_seen.size(), "ledger": sim.rewards.get("rep", {}), "prestige": int(sim.rewards.get("prestige", 0))})) if district_arg != "" else "", (", anti " + JSON.stringify({"seen": anti_seen, "taken": sim.academy_taken(), "turns": sim.rewards.get("academy", {}).get("turns", []), "academy_on": sim.academy_on, "squad": sim.blineup, "recruits": sim.recruit_lines()})) if demo_anti else "", (", vendors " + JSON.stringify({"seen": vendor_seen.slice(maxi(0, vendor_seen.size() - 10)), "n": vendor_seen.size(), "shelves": sim.vendor_lines(), "hbp": int(sim.rewards.get("hbp", 0))})) if demo_vendors or rep_arg != "" else ""])

func _gear_summary() -> Dictionary:
	# PAC-094: what each card of the club wears at the soak's end
	var out := {}
	for c in sim.stable:
		var w: Array = sim.gear_worn(str(c["name"]))
		if w.size() > 0: out[str(c["name"])] = w
	return out

func _formation_check() -> String:
	# the demo's reveal: the board it sealed, and the projection against the order his corner sealed
	var pr: Dictionary = sim.projection()
	var ck: Array = []
	for s in pr.get("slots", []): ck.append("R%d %s" % [int(s["slot"]), ("? - it was %s" % str(sim.sealed_b[int(s["slot"]) - 1])) if bool(s["silhouette"]) else ("%s %s%s" % [str(s["guess"]), "right" if bool(s["right"]) else "wrong", "" if bool(s["right"]) else " (was %s)" % str(sim.sealed_b[int(s["slot"]) - 1])])])
	return JSON.stringify({"board": str(sim.board.get("archetype", "")) if str(sim.board.get("archetype", "")) != "" else str(sim.board.get("name", "")), "sealed": sim.sealed_p, "projection_pct": int(pr.get("pct", 0)), "decoy": bool(pr.get("decoy", false)), "detected": bool(pr.get("detected", false)), "check": ck})

func _consume_events() -> void:
	for ev in sim.events:
		fx_counts[ev["kind"]] = int(fx_counts.get(ev["kind"], 0)) + 1
		match ev["kind"]:
			"feed": feed.text = ev["text"]
			"matchup":
				matchups_shown += 1
				var lab := {"SWARMER": "SWARMER", "OUTBOXER": "OUT-BOXER", "SLUGGER": "SLUGGER", "BOXERPUNCHER": "BOXER-PUNCHER"}
				var pa := "  <<< YOUR EDGE" if ev["style_adv"] == "P" else ("  >>> HIS EDGE" if ev["style_adv"] == "B" else "")
				var ea := "  <<< YOUR EDGE" if ev["element_adv"] == "P" else ("  >>> HIS EDGE" if ev["element_adv"] == "B" else "")
				matchup_text = ">>> MATCHUP R%d   %s  %s / %s / House %s%s   vs   %s  %s / %s / House %s%s\n    %s%s" % [sim.seg_idx + 1, sim.pname(), lab.get(ev["p_style"], ev["p_style"]), ev["p_element"], str(ev["p_house"]).capitalize(), pa,
					sim.boss_name, lab.get(ev["b_style"], ev["b_style"]), ev["b_element"], str(ev["b_house"]).capitalize(), ea, ev["line"], "\n    FEUD - the crowd knows the history; Tension x1.25 both ways" if ev["feud"] else ""]
				matchup_until = sim.tick + TNBSim.ms(3000)
				matchup_text += _traits_line()                                                               # PAC-078: the house traits in play on both corners
				if sim.academy_line() != "": matchup_text += "\n    " + sim.academy_line() + "\n    " + sim.thesis_line()   # PAC-092: his syntheses, and the club's forged answer in the numbers
				if sim.mirror_line() != "": matchup_text += "\n    " + sim.mirror_line()                    # PAC-093: what the copy learned from you
				if sim.gear_line() != "": matchup_text += "\n    " + sim.gear_line()                        # PAC-094: what he walks out in
				_dress_gear(player, sim.P.get("gear", []))
				if sim.P.get("kit", []).size() > 0: matchup_text += "\n    KIT: %s - %s" % [sim.pname(), ", ".join(PackedStringArray(sim.P["kit"].map(func(km): return "%s (LB + %s)" % [str(km), str(sim.library[km]["family"])])))]   # PAC-091: the kit he walks out with
				if sim.P.get("passives", []).size() > 0: matchup_text += "\n    PASSIVES: %s - %s" % [sim.pname(), ", ".join(PackedStringArray(sim.P["passives"].map(func(pp): return str(sim.GROW["passives"][pp]["name"]))))]   # PAC-090: his board's passives at the bell
				matchup_text += _duo_line()                                                                  # PAC-080: the Duo relay live this segment
				if sim.hybrid_line() != "": matchup_text += "\n    " + sim.hybrid_line()                    # PAC-087: the pair's hybrid live this segment
				if sim.surge_line(sim.pname()) != "": matchup_text += "\n    " + sim.surge_line(sim.pname())             # PAC-085: what his SURGE casts
				matchup_text += _relay_open_line()                                                           # PAC-081: the T3s the CHARGED relay opens
				var bmm: StandardMaterial3D = boss.get_meta("mat"); bmm.albedo_color = _base_color("B")
			"hit":
				var target: Node3D = boss if ev["on"] == "B" else player
				_bump(target, 0.12)
				if ev.get("counter", false) or ev.get("flash", false):
					_flash(0.2); cam.fov = 52.0
					get_tree().create_tween().tween_property(cam, "fov", 55.0, 0.25)
			"drop":
				_flash(0.5); _bump(boss if ev["who"] == "B" else player, 0.5)
			"hissatsu": _flash(0.9)
			"tell": _tell_fx(int(ev["ticks"]) / float(TNBSim.TICK_HZ), bool(ev["loud"]), bool(ev.get("cue", false)))
			"unbroken": _flash(0.05)
			"feint_b": _bump(boss, 0.04)
			"taunt_b": _bump(boss, 0.18)                                                       # his taunt: the guard comes down for half a second
			"corner_bell": _flash(0.15)
			"tempo_shift": _bump(boss, 0.06)
			"desync": _flash(0.2)
			"remix":
				matchup_text += "\n    REMATCH REMIX: " + " | ".join(PackedStringArray(ev["notes"]))
				matchup_until = sim.tick + TNBSim.ms(4500)
			"commentary":
				matchup_text += "\n    COMMENTARY (PI %d): %s%s" % [int(ev["level"]), str(ev["text"]), "   [tells emphasized, interrupt windows +10%]" if bool(ev.get("cue", false)) else ""]
				matchup_until = sim.tick + TNBSim.ms(4500)
			"pi":
				pi_toast = "PATTERN INTEL %d vs %s - %s" % [int(ev["level"]), str(ev["dialect"]).capitalize(), str(ev["label"])]
				pi_toast_until = sim.tick + TNBSim.ms(5000); _flash(0.15)
			"scout_book":
				pi_toast = "SCOUT BOOK: %s's page - F12 reads it" % str(ev["boss"])
				pi_toast_until = sim.tick + TNBSim.ms(5000); _flash(0.2)
			"reward_toast":
				toast_text = "REWARD  " + str(ev["text"]); toast_until = sim.tick + TNBSim.ms(6000); _flash(0.1)
			"level_up":
				toast_text = "LEVEL UP  %s -> %d" % [str(ev["who"]), int(ev["level"])]; toast_until = sim.tick + TNBSim.ms(4000)
			"recruit_approachable":
				toast_text = "APPROACHABLE  %s - [L] approach" % ", ".join(PackedStringArray(ev["names"])); toast_until = sim.tick + TNBSim.ms(6000)
			"recruit_ready":
				toast_text = "%s WOULD JOIN - [P] recruit" % str(ev["card"]); toast_until = sim.tick + TNBSim.ms(6000)
			"blessing_granted":
				toast_text = "BLESSING  House %s blesses the club%s" % [str(ev["name"]), (" - sanctioned: " + ", ".join(PackedStringArray(ev["sanctioned"]))) if ev["sanctioned"].size() > 0 else ""]; toast_until = sim.tick + TNBSim.ms(6000)
			"blessing_revoked":
				toast_text = "BLESSING VOID  House %s - %s at %s stamina (%s)" % [str(ev["house"]).capitalize(), str(ev["move"]), str(ev["stamina"]), str(ev["code"])]; toast_until = sim.tick + TNBSim.ms(6000)
			"graph_mutated":
				toast_text = "FEUD GRAPH  %s %s-%s %s" % [str(ev["edge"]), str(ev["a"]).capitalize(), str(ev["b"]).capitalize(), ("%s -> %s" % [str(ev["from"]), str(ev["to"])]) if str(ev["from"]) != "" else ("added " + str(ev["to"]))]; toast_until = sim.tick + TNBSim.ms(6000)
			"graph_refused":
				toast_text = "FEUD GRAPH  %s stays %s - %s" % [str(ev["edge"]), str(ev["relation"]), str(ev["why"])]; toast_until = sim.tick + TNBSim.ms(6000)
			"zone":                                                                                          # PAC-082: the SURGE - the camera hold, then the Zone
				toast_text = "%s  %s - the whole bar (%d)%s%s" % [str(ev["name"]).to_upper(), str(ev["who"]), int(ev["cost"]), "  FULL RELAY" if bool(ev["full_relay"]) else "", ("  - %s-Awakening at %d%%" % [str(ev["form"]).capitalize(), int(ev["stack_pct"])]) if str(ev.get("form", "")) != "" else (("  - %s, its own meter %d" % [str(ev["manifest"]), int(ev["meter"])]) if str(ev.get("manifest", "")) != "" else (("  - %s" % sim.inherit_label(ev)) if str(ev.get("source", "")) != "" else ""))]; toast_until = sim.tick + TNBSim.ms(4000)
				_flash(0.6); transforms_seen.append("%s %s%s%s" % [str(ev["who"]), str(ev["tier"]), (" (%s)" % str(ev["form"])) if str(ev.get("form", "")) != "" else "", (" <- %s %s" % [str(ev["source"]), str(ev["house"])]) if str(ev.get("source", "")) != "" else ""])
			"refund":                                                                                        # PAC-085: a drop scored Awakened refunds the bar
				toast_text = "AWAKENED DROP  %s - +%d Tension back (bar %d)" % [str(ev["who"]), int(ev["tension"]), int(ev["bar"])]; toast_until = sim.tick + TNBSim.ms(4000)
			"echo":                                                                                          # PAC-083: the manifest's echo - the figure pulses (PAC-086: his, when it lands on you)
				if str(ev.get("on", "B")) == "P": bmanifest_pulse = 0.12; bechoes_seen += 1
				elif not bool(ev.get("walled", false)): manifest_pulse = 0.12; echoes_seen += 1
			"zone_end":
				toast_text = "COMEDOWN  %s - %ds at %d%%%s" % [str(ev["who"]), int(ev["comedown_s"]), int(ev["stat_pct"]), (", own dialect scrambled %ds" % int(ev["scramble_s"])) if float(ev.get("scramble_s", 0.0)) > 0.0 else ""]; toast_until = sim.tick + TNBSim.ms(4000)
			"boss_transform_tell":                                                                           # PAC-086: he gathers - his line, the swell behind his guard
				toast_text = "GATHERING  %s - %s" % [str(ev["who"]), str(ev["line"])]; toast_until = sim.tick + int(ev["ticks"]) + TNBSim.ms(500)
				_tell_fx(float(ev["ticks"]) / TNBSim.TICK_HZ, true)
			"boss_zone":                                                                                     # PAC-086: his tier - the hold, his toast
				toast_text = "%s  %s - %ds%s - weather it: a perfect block or a slip takes 1s off and halves the damage" % [str(ev["word"]), str(ev["who"]), int(ev["seconds"]), ("  - " + str(ev["manifest"])) if str(ev["manifest"]) != "" else ""]; toast_until = sim.tick + TNBSim.ms(4000)
				_flash(0.6); btransforms_seen.append("%s %s" % [str(ev["who"]), str(ev["tier"])])
				var bz: StandardMaterial3D = boss.get_meta("mat"); bz.albedo_color = _base_color("B")
			"weather":
				weathered_seen += 1; _flash(0.1)
				toast_text = "WEATHERED  -%.1fs (%.1fs left) - the damage to you halved" % [float(ev["cut"]) / TNBSim.TICK_HZ, float(ev["left"]) / TNBSim.TICK_HZ]; toast_until = sim.tick + TNBSim.ms(2000)
			"boss_zone_end":                                                                                 # PAC-086: his Comedown - your window, him dimmed
				var ct := "ENEMY COMEDOWN  %s - %ds at %d%% - YOUR WINDOW%s (weathered %d)" % [str(ev["who"]), int(ev["comedown_s"]), int(ev["stat_pct"]), " - suppressed in the Clash" if bool(ev["suppressed"]) else "", int(ev["weathered"])]
				toast_text = (toast_text + "   " + ct) if toast_text.begins_with("CLASH ") and sim.tick < toast_until else ct; toast_until = sim.tick + TNBSim.ms(4000)   # the Clash's verdict keeps its line
				var bd: StandardMaterial3D = boss.get_meta("mat"); bd.albedo_color = _base_color("B")
			"boss_comedown_end":
				var be: StandardMaterial3D = boss.get_meta("mat"); be.albedo_color = _base_color("B")
			"feat":                                                                                          # PAC-086: a feat on the ledger - its toast beside the Comedown's
				feats_seen.append("%s vs %s" % [str(ev["name"]), str(ev["against"])])
				var ft := "%s  %s weathered %s's transformation unanswered (x%d)" % [str(ev["name"]).to_upper(), sim.pname(), str(ev["against"]), int(ev["count"])]
				toast_text = (toast_text + "   " + ft) if toast_text.begins_with("ENEMY COMEDOWN") and sim.tick < toast_until else ft; toast_until = sim.tick + TNBSim.ms(6000); _flash(0.5)
			"clash_start":                                                                                   # PAC-086: both manifested - the Clash
				toast_text = "MANIFEST CLASH  %s against %s - %d exchanges: block or slip on the enemy's, punch on yours" % [str(ev["p"]), str(ev["b"]), int(ev["exchanges"])]; toast_until = sim.tick + TNBSim.ms(6000); _flash(0.8)
			"clash_exchange": _flash(0.2 if str(ev["result"]) == "won" else 0.05)
			"clash_end":
				clashes_seen.append("%s %d/%d" % [str(ev["winner"]), int(ev["won"]), int(ev["of"])])
				toast_text = "CLASH %s  %d of %d - %s" % ["WON" if str(ev["winner"]) == "P" else "LOST", int(ev["won"]), int(ev["of"]), "your manifest suppresses the enemy's" if str(ev["winner"]) == "P" else "the enemy's manifest suppresses yours"]; toast_until = sim.tick + TNBSim.ms(4000); _flash(0.6)
			"forge":                                                                                         # PAC-087: NP_08 s6 - the Forge's output
				forged_seen.append("%s (%s)" % [str(ev["name"]), str(ev["pair"]).replace("|", "&")])
				toast_text = "FORGED  %s - %s & %s (House %s x House %s): %d Spirits, %d Beans%s - hybrid %d of %d" % [str(ev["name"]).to_upper(), str(ev["a"]), str(ev["b"]), str(ev["houses"][0]).capitalize(), str(ev["houses"][1]).capitalize(), int(ev["spirits"]), int(ev["beans"]), (" (" + str(ev["discount"]) + ")") if str(ev["discount"]) != "" else "", int(ev["n"]), int(ev["of"])]
				toast_until = sim.tick + TNBSim.ms(6000); _flash(0.4)
			"renovated":                                                                                     # PAC-089: NP_10 s7 - a facility tier built
				renovations_seen.append("%s T%d" % [str(ev["label"]), int(ev["tier"])])
				toast_text = "RENOVATED  %s T%d - %s (%d HBP, %d Spirits)" % [str(ev["label"]).to_upper(), int(ev["tier"]), str(ev["effect"]), int(ev["hbp"]), int(ev["spirits"])]; toast_until = sim.tick + TNBSim.ms(6000); _flash(0.3)
			"training":
				trainings_seen.append("%s %s %d" % [str(ev["who"]), str(ev["label"]), int(ev["beans"])])
				partner_seen += int(ev.get("bonus", 0))
				toast_text = "TRAINING  %s - %s, grade %.2f: %d Beans%s%s (slot %d of %d; the jar %d)" % [str(ev["who"]), str(ev["label"]), float(ev["grade"]), int(ev["beans"]), (" x%.2f" % float(ev["mult"])) if float(ev["mult"]) != 1.0 else "", (" - against %s's ghost" % str(ev["pattern"])) if str(ev["pattern"]) != "" else "", int(ev["slot"]), int(ev["of"]), int(ev["jar"])] + (("  [%s]" % sim._beans_text(ev["typed"], int(ev["beans"]))) if ev.get("typed", {}).size() > 0 else "") + (("  %s the training partner +%d %s" % [str(ev["partner"]), int(ev["bonus"]), str(ev["bonus_stat"])]) if int(ev.get("bonus", 0)) > 0 else ""); toast_until = sim.tick + TNBSim.ms(5000)
			"learned":                                                                                       # PAC-091: NP_11 s8 - a technique learned, and from where
				learned_seen.append("%s %s (%s)" % [str(ev["who"]), str(ev["move"]), str(ev["source"])])
				toast_text = "LEARNED  %s - %s (%s %s) from %s" % [str(ev["who"]), str(ev["move"]), str(ev["tier"]), str(ev["family"]), {"shop": "the shop", "tape": "a fight tape"}.get(str(ev["source"]), str(ev["source"]).replace("master:", "").replace("taught:", "a re-teach by "))]; toast_until = sim.tick + TNBSim.ms(5000)
			"bought":
				vendor_seen.append("bought %s %s (%s, %s)" % [str(ev["who"]), str(ev["move"]), str(ev["tier"]), sim.shelf_open_by("techniques", str(ev["tier"]))])   # PAC-103: how the shelf stood open
				toast_text = "THE SHOP  %s buys %s (%s shelf, %d HBP; the ledger %d)" % [str(ev["who"]), str(ev["move"]), str(ev["tier"]), int(ev["hbp"]), int(ev["ledger"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"kit_equipped":
				var kt := "- in the kit (%s)" % ", ".join(PackedStringArray(ev["kit"]))
				toast_text = (toast_text + "  " + kt) if sim.tick < toast_until and toast_text.begins_with("LEARNED") else "THE KIT  %s carries %s %s" % [str(ev["who"]), str(ev["move"]), kt]; toast_until = sim.tick + TNBSim.ms(5000)
			"kit_unequipped":
				toast_text = "THE KIT  %s puts %s down (still learned)" % [str(ev["who"]), str(ev["move"])]; toast_until = sim.tick + TNBSim.ms(4000)
			"retaught":
				toast_text = "RE-TEACH  %s passes %s to %s (training slot %d of %d)" % [str(ev["teacher"]), str(ev["move"]), str(ev["who"]), int(ev["slot"]), int(ev["of"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"tape_found":
				toast_text = "FIGHT TAPE  %s - the %s reward" % [str(ev["move"]), str(ev["flag"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"node_taken":                                                                                    # PAC-090: NP_11 s3 - the board
				growth_seen.append("%s %s" % [str(ev["who"]), str(ev["label"])])
				toast_text = "THE BOARD  %s takes %s (%s, %d pts; %d of %d free)" % [str(ev["who"]), str(ev["label"]), str(ev["lobe"]), int(ev["cost"]), int(ev["free"]), int(ev["points"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"respec":
				toast_text = "RESPEC  %s at the Film Room - %d nodes, %d Board Points back" % [str(ev["who"]), int(ev["nodes"]), int(ev["points"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"socketed":
				toast_text = "THE BOARD  %s sockets %s (off-style)" % [str(ev["who"]), str(ev["name"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"stat_raised":                                                                                   # PAC-090: NP_11 s6 - the Beans' own sink
				growth_seen.append("%s +1 %s" % [str(ev["who"]), str(ev["stat"])])
				toast_text = "THE JAR  %s +1 %s -> %d for %d Beans (%d %s, %d untyped; the next %d)" % [str(ev["who"]), str(ev["stat"]), int(ev["to"]), int(ev["cost"]), int(ev["typed"]), str(ev["stat"]), int(ev["untyped"]), int(ev["next"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"ascended":                                                                                      # PAC-090: NP_11 s4 - rarity
				growth_seen.append("%s %s" % [str(ev["who"]), str(ev["name"])])
				toast_text = "ASCENDED  %s -> %s (tier %d): %d Spirits - growth to %d, %d accessory slot%s%s%s" % [str(ev["who"]), str(ev["name"]).to_upper(), int(ev["tier"]), int(ev["spirits"]), int(ev["cap"]), int(ev["slots"]), "" if int(ev["slots"]) == 1 else "s", (", a %d stat total at least" % int(ev.get("total", 0))) if int(ev.get("total", 0)) > 0 else "", ", the Awakening flag" if int(ev["tier"]) >= 4 else ""]   # PAC-096: the tier's total (NP_11 s1); toast_until = sim.tick + TNBSim.ms(6000); _flash(0.4)
			"trial_met":
				var tt := "TRIAL  %s - %s" % [str(ev["who"]), {"spar_won": "a spar won", "storm": "a transform weathered", "mirror": "the mirror beaten"}.get(str(ev["trial"]), str(ev["trial"]))]
				toast_text = (toast_text + "   " + tt) if sim.tick < toast_until and toast_text != "" else tt; toast_until = sim.tick + TNBSim.ms(6000)
			"entrance":
				entrances_seen += 1
				toast_text = "ENTRANCE  MILLBROOK walks out - %s%s" % [", ".join(PackedStringArray(ev["set"])), " (at home)" if bool(ev["host"]) else ""]; toast_until = sim.tick + TNBSim.ms(3000); _flash(0.15)
			"page_waiting":
				toast_text = "SCOUT BOOK FULL  %s's page waits for the Film Room (%d pages)" % [str(ev["page"]).replace("#", " "), int(ev["shelf"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"page_shelved":
				toast_text = "SCOUT BOOK  %s's page on the shelf" % str(ev["page"]).replace("#", " "); toast_until = sim.tick + TNBSim.ms(4000)
			"dual_end":
				if demo_facilities or demo_roles or demo_locker: sim.new_day()                          # PAC-089: the aid turns a day at each dual's end (the training slots come back; PAC-099: the scouts pay; PAC-100: a release settles)
			"lab_refused", "spar_refused":
				toast_text = "SPAR  %s" % str(ev["why"]); toast_until = sim.tick + TNBSim.ms(4000)
			"hybrid":
				if str(ev["live"]) == "awakened": toast_text = "HYBRID SLOT  %s - %s live (LB + %s)" % [str(ev["who"]), str(ev["move"]).to_upper(), str(ev["family"])]; toast_until = sim.tick + TNBSim.ms(4000)
			"transform_refused":
				toast_text = "SURGE  %s" % str(ev["why"]); toast_until = sim.tick + TNBSim.ms(3000)
			"decoration_unlocked":
				var dt := "ON THE WALL  %s" % str(ev["label"])
				toast_text = (toast_text + "   " + dt) if (sim.tick < toast_until and toast_text != "" and not toast_text.contains("ON THE WALL")) else dt; toast_until = sim.tick + TNBSim.ms(6000)
			"wall_revealed":
				var wt := "STRING WALL  %s -> %s" % [str(ev["from"]), ", ".join(PackedStringArray(ev["labels"]))]
				toast_text = (toast_text + "   " + wt) if (sim.tick < toast_until and toast_text != "" and not toast_text.contains("STRING WALL")) else wt; toast_until = sim.tick + TNBSim.ms(6000)   # the join's toast keeps its line
			"staff_level":
				toast_text = "STAFF  %s -> Lv%d%s" % [str(ev["name"]), int(ev["level"]), ("  " + str(ev["unlocked"])) if str(ev["unlocked"]) != "" else ""]; toast_until = sim.tick + TNBSim.ms(5000)
			"kizuna_level":
				toast_text = "KIZUNA  %s -> Lv%d %s" % [str(ev["pair"]).replace("|", " & "), int(ev["level"]), str(ev["name"])]; toast_until = sim.tick + TNBSim.ms(5000)
			"engagement_end":                                                                                # PAC-088: your pair's engagement is over; the other may fight on
				if exh != null and exh.over: continue                                                          # both over: the verdict and the reward keep the line
				toast_text = "PAIR %s OVER  %s vs %s %d-%d%s" % [str(ev["exhibit"]), str(ev["who"]), sim.boss_label, int(ev["score"][0]), int(ev["score"][1]), " - a KO; the other pair fights on" if bool(ev["ko"]) else ""]; toast_until = sim.tick + TNBSim.ms(4000)
			"recover", "interrupt":
				var mat: StandardMaterial3D = boss.get_meta("mat"); mat.albedo_color = _base_color("B")
				if tell_tween: tell_tween.kill()
				var mesh: MeshInstance3D = boss.get_meta("mesh"); mesh.scale = Vector3.ONE
			"perfect_block": _flash(0.12)
			"corner_locked", "coach_locked": _flash(0.3)
			"coach_action": _bump(boss, 0.06)
			"clinch":
				var pm: MeshInstance3D = player.get_meta("mesh"); pm.scale = Vector3(1.1, 0.97, 1.1)
				var bm: MeshInstance3D = boss.get_meta("mesh"); bm.scale = Vector3(1.1, 0.97, 1.1)
			"clinch_beat": _flash(0.1)
			"clinch_end":
				var pm2: MeshInstance3D = player.get_meta("mesh"); pm2.scale = Vector3.ONE
				var bm2: MeshInstance3D = boss.get_meta("mesh"); bm2.scale = Vector3.ONE
				_flash(0.25 if ev["winner"] == "P" else 0.15)
			"foul", "referee", "pulled":
				flashrect.color = Color(1, 0.3, 0.2, 0.35 if ev["kind"] != "pulled" else 0.12)
				get_tree().create_tween().tween_property(flashrect, "color:a", 0.0, 0.5)
			"clinch_cue": _flash(0.08)
			"survival_grab": _flash(0.3)
			"gear_won", "gear_bought", "gear_worn", "gear_off":                                               # PAC-094: the locker and the card
				var gtx := {"gear_won": "GEAR  %s - %s" % [sim.gear_text(str(ev["id"])), str(ev.get("why", ""))], "gear_bought": "GEAR  bought %s for %d HBP (%d left)" % [sim.gear_text(str(ev["id"])), int(ev.get("hbp", 0)), int(ev.get("left", 0))],
					"gear_worn": "GEAR  %s wears %s" % [str(ev.get("who", "")), sim.gear_text(str(ev["id"]))], "gear_off": "GEAR  %s takes off %s - back in the locker" % [str(ev.get("who", "")), str(ev.get("name", ""))]}
				gear_seen_log.append("%s %s" % [str(ev["kind"]).substr(5), str(ev["id"]) if str(ev["kind"]) != "gear_worn" else "%s:%s" % [str(ev.get("who", "")), str(ev["id"])]])
				if str(ev["kind"]) == "gear_bought":                                                          # PAC-103: how the shelf stood open
					var gsh := str(sim.gear_item(str(ev["id"])).get("shelf", "")); vendor_seen.append("bought gear %s (%s, %s)" % [str(ev["id"]), gsh, sim.shelf_open_by("gear", gsh)])
				toast_text = str(gtx[str(ev["kind"])]); toast_until = sim.tick + TNBSim.ms(3500)
			"scout_lead":                                                                                    # PAC-098: a lead from the machine
				scout_seen.append(("RARE " if bool(ev.get("rare", false)) else "") + str(ev.get("label", "")))
				var dname := str(sim.ECO.get("scouting", {}).get("districts", {}).get(str(ev.get("district", "")), ev.get("district", "")))
				toast_text = ("RARE LEAD  %s - %s%s: approachable" % [str(ev.get("label", "")), dname, (", House " + str(ev.get("house", ""))) if str(ev.get("house", "")) not in ["", "none"] else ""]) if bool(ev.get("rare", false)) else "LEAD  %s (%s, %s) - on the open mat" % [str(ev.get("label", "")), str(ev.get("style", "")), dname]
				toast_until = sim.tick + TNBSim.ms(3500)
			"academy_signs":                                                                                 # PAC-102: NP_12 s2 - the anti-you
				if ev["names"].size() > 0:
					anti_seen.append("signed %s" % ", ".join(PackedStringArray(ev["cards"])))
					toast_text = "THE ANTI-YOU  %s signs %s - rivals the club beat and left waiting (%s)" % [str(sim.ACAD.get("club", "the academy")), ", ".join(PackedStringArray(ev["cards"])), str(ev["turn"])]; toast_until = sim.tick + TNBSim.ms(5000); _flash(0.2)
			"academy_beaten":
				anti_seen.append("came over %s" % ", ".join(PackedStringArray(ev["cards"])))
				toast_text = "THE ACADEMY BEATEN  %s come over - approachable" % ", ".join(PackedStringArray(ev["cards"])); toast_until = sim.tick + TNBSim.ms(5000); _flash(0.3)
			"rep":                                                                                           # PAC-101: a district's rep moved
				rep_seen.append("%s %d%s" % [str(ev["district"]), int(ev["rep"]), (" +%dP" % int(ev["prestige"])) if int(ev["prestige"]) > 0 else ""])
				toast_text = "REP  %s %d (%s%d, %s)%s" % [sim.district_label(str(ev["district"])), int(ev["rep"]), "+" if int(ev["by"]) >= 0 else "", int(ev["by"]), str(ev["why"]), ("  - a milestone: +%d Prestige" % int(ev["prestige"])) if int(ev["prestige"]) > 0 else ""]; toast_until = sim.tick + TNBSim.ms(3500)
				if ev.get("shelves", []).size() > 0:                                                         # PAC-103: NP_02 s4 - the rep opened a shelf
					toast_text += "  - opens %s" % ", ".join(PackedStringArray(ev["shelves"])); vendor_seen.append("opened %s at %s %d" % [", ".join(PackedStringArray(ev["shelves"])), str(ev["district"]), int(ev["rep"])])
				if ev.get("closed", []).size() > 0: vendor_seen.append("closed %s at %s %d" % [", ".join(PackedStringArray(ev["closed"])), str(ev["district"]), int(ev["rep"])])
			"fled":
				rep_seen.append("fled %s" % str(ev["district"]))
				toast_text = "FLED  %s" % (("the scrap in %s - rep %d" % [sim.district_label(str(ev["district"])), int(ev["rep"])]) if int(ev["rep"]) < 0 else ("before the first exchange - free" if not bool(ev["engaged"]) else "the scrap - placed nowhere, no rep")); toast_until = sim.tick + TNBSim.ms(3500)
				if ev.get("closed", []).size() > 0: toast_text += "  - closes %s" % ", ".join(PackedStringArray(ev["closed"]))   # PAC-103: the shelf the rep held
			"released":                                                                                      # PAC-100: NP_08 s4 - a card let go
				locker_seen.append("released %s (%s)" % [str(ev["name"]), str(ev["flag"])])
				toast_text = "RELEASED  %s - %s; take the card back until day %d (the stable %d)" % [str(ev["name"]), ("warmth, a bond with %s" % str(ev["bond"])) if str(ev["flag"]) == "warmth" else "a grudge, no bond left behind", int(ev["until"]), int(ev["stable"])]; toast_until = sim.tick + TNBSim.ms(4000)
			"taken_back":
				locker_seen.append("taken back %s" % str(ev["name"]))
				toast_text = "TAKEN BACK  %s - back in the stable as before (%d)" % [str(ev["name"]), int(ev["stable"])]; toast_until = sim.tick + TNBSim.ms(3500)
			"release_settled":
				locker_seen.append("gone %s (%s)" % [str(ev["name"]), str(ev["flag"])])
				toast_text = "GONE  %s - %s, %s" % [str(ev["name"]), "on the open mat" if str(ev["road"]) == "open_mat" else "back in the district, approachable", "warm" if str(ev["flag"]) == "warmth" else "with a grudge"]; toast_until = sim.tick + TNBSim.ms(4000)
			"role_set":                                                                                      # PAC-099: NP_08 s1 - a stablemate to a role
				roles_seen.append("%s:%s" % [str(ev["name"]), str(ev["role"])])
				toast_text = "ROLE  %s - %s" % [str(ev["name"]), str(ev["text"])]; toast_until = sim.tick + TNBSim.ms(3500)
			"scouted":                                                                                       # PAC-099: the day turned - the scouts' districts pay
				scouted_seen += int(ev["prestige"])
				toast_text = "THE SCOUTS  day %d - +%d Prestige from %s (the ledger %d)" % [int(ev["day"]), int(ev["prestige"]), ", ".join(PackedStringArray(ev["districts"].map(func(x): return sim.district_label(str(x))))), int(ev["ledger"])]; toast_until = sim.tick + TNBSim.ms(3500)
			"trainees":                                                                                      # PAC-099: the cornermen-in-training fed the staff
				trainee_seen += ev["fed"].size()
				toast_text = "THE CORNER  %s" % "; ".join(PackedStringArray(ev["fed"])); toast_until = sim.tick + TNBSim.ms(3500)
			"signed":                                                                                        # PAC-098: the open mat
				signed_seen.append(str(ev["name"]))
				toast_text = "THE OPEN MAT  %s signs%s - the stable holds %d" % [str(ev["name"]), (" (%d Prestige priority)" % int(ev.get("priority", 0))) if int(ev.get("priority", 0)) > 0 else "", int(ev.get("stable", 0))]; toast_until = sim.tick + TNBSim.ms(3500)
			"mirror":                                                                                        # PAC-093: the copy at the bell
				mirrors_seen.append("%s: %s" % [str(ev["of"]), ", ".join(PackedStringArray(ev["habits"])) if ev["habits"].size() > 0 else "the Style's strings"])
				toast_text = "THE MIRROR  %s against his copy - %s" % [str(ev["of"]), ("it throws " + ", ".join(PackedStringArray(ev["habits"]))) if ev["habits"].size() > 0 else "no record yet: the Style's strings"]; toast_until = sim.tick + TNBSim.ms(4000)
			"mirror_counter":                                                                                # PAC-093: your counter punch, thrown back
				mirror_counters += 1
				toast_text = "YOUR COUNTER  %s answers the miss with your %s" % [str(ev["who"]), str(sim._mirror_rules().get("row_verbs", {}).get(str(ev["row"]), ev["row"]))]; toast_until = sim.tick + TNBSim.ms(2500)
			"synthesis":                                                                                     # PAC-092: an academy prodigy's synthesis - industrial, hollow
				syntheses_seen.append("%s %s" % [str(ev["who"]), str(ev["move"])])
				toast_text = "SYNTHESIS  %s - %s (LB + %s, x%s; %d of %d) - industrial: no bond, no afterimage" % [str(ev["who"]), str(ev["move"]).to_upper(), str(ev["family"]), TNBSim._n(float(ev["dmg"])), int(ev["n"]), int(ev["of"])]; toast_until = sim.tick + TNBSim.ms(4000)
			"cast":
				if str(ev["who"]) == "P" and str(ev["move"]) in sim.P.get("kit", []): kit_casts.append("%s %s" % [sim.pname(), str(ev["move"])])   # PAC-091: a cast from the kit
				if str(ev.get("afterimage", "")) != "":
					_spawn_ghost(str(ev["afterimage"]), float(ev["windup"]) / TNBSim.TICK_HZ, bool(ev.get("trail", false)), str(ev.get("duo", "")) != "", ev.get("hybrid_elements", []))
				if str(ev.get("hybrid", "")) != "":                                                        # PAC-087: the pair's hybrid - its toast
					hybrid_casts.append("%s %s (%s)" % [str(ev["move"]), str(ev["hybrid"]).replace("|", "&"), str(ev["hybrid_live"])])
					toast_text = "HYBRID  %s  %s - %s" % [str(ev["move"]).to_upper(), sim.pname(), {"relayed": "relayed from %s: the afterimage joins, x%s" % [str(ev["hybrid_partner"]), str(sim.HYB.get("cast", {}).get("relayed_dmg_mult", 1.0))], "charged": "the CHARGED relay", "awakened": "the Awakening's slot"}.get(str(ev["hybrid_live"]), "")]; toast_until = sim.tick + TNBSim.ms(4000)
				if str(ev.get("duo_sync", "")) != "" and str(ev["who"]) == "P":                           # PAC-088: the exhibition's duo sync - both halves gilded
					toast_text = "DUO SYNC  %s  - %s beside %s" % [str(ev["move"]).to_upper(), sim.pname(), str(ev.get("sync_partner", ""))]; toast_until = sim.tick + TNBSim.ms(4000)
				if str(ev.get("duo", "")) != "":                                                           # PAC-080: the pair's named T3 - its toast, the afterimage gilded
					duo_casts.append(str(ev["move"]))
					toast_text = "DUO  %s  - %s (%s)" % [str(ev["move"]).to_upper(), str(ev["duo"]).replace("|", " & "), str(ev.get("duo_of", ""))]; toast_until = sim.tick + TNBSim.ms(4000)
				_flash(0.4); cam.fov = 48.0
				get_tree().create_tween().tween_property(cam, "fov", 55.0, float(ev["windup"]) / TNBSim.TICK_HZ)
				var cm: StandardMaterial3D = (boss if ev["who"] == "B" else player).get_meta("mat")
				cm.albedo_color = Color(1.0, 1.0, 0.6) if ev["who"] == "B" else Color(0.7, 0.9, 1.0)
			"cast_resolve", "cast_interrupted":
				_flash(0.9 if ev["kind"] == "cast_resolve" else 0.3)
				var bm3: StandardMaterial3D = boss.get_meta("mat"); bm3.albedo_color = _base_color("B")
				var pm3: StandardMaterial3D = player.get_meta("mat"); pm3.albedo_color = _base_color("P")
			"gauge_break", "wall_broken": _flash(0.7)
			"walled": _flash(0.15)
			"feint": _bump(player, 0.05)
			"tell":
				if ev.get("jammed", false):
					var mat3: StandardMaterial3D = boss.get_meta("mat"); mat3.albedo_color = _base_color("B")   # jammed: no tell shown
			"stance":
				var mat2: StandardMaterial3D = boss.get_meta("mat")
				mat2.albedo_color = _base_color("B").darkened(0.35) if ev["hands_down"] else _base_color("B")
	sim.events.clear()

func _manifest_render(back: Vector3, el: String) -> void:
	# NP_09 s4, greybox: the inner figure behind the fighter while the manifest stands - it pulses on each echo, and leaves with the manifest
	if not sim.tform.has("manifest"):
		if manifest_fig: manifest_fig.queue_free(); manifest_fig = null
		return
	var tint: Color = ELEMENT_TINT.get(el, Color(0.9, 0.9, 1.0))
	if manifest_fig == null:
		manifest_fig = _mk_capsule(tint, player.position)
		manifest_fig.scale = Vector3(1.7, 1.6, 1.7)
		var fm0: StandardMaterial3D = manifest_fig.get_meta("mat")
		fm0.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm0.albedo_color.a = 0.28; fm0.emission_enabled = true; fm0.emission = tint
	var fm: StandardMaterial3D = manifest_fig.get_meta("mat")
	fm.emission_energy_multiplier = 2.6 if manifest_pulse > 0.0 else 1.0
	manifest_fig.position = player.position + back * 0.75

func _bmanifest_render(back: Vector3, el: String) -> void:
	# NP_09 s4 on his side: his manifest behind him while it stands - it pulses on each of his echoes, and leaves with it (or the Clash)
	if not sim.btform.has("manifest"):
		if bmanifest_fig: bmanifest_fig.queue_free(); bmanifest_fig = null
		return
	var tint: Color = ELEMENT_TINT.get(el, Color(1.0, 0.75, 0.7))
	if bmanifest_fig == null:
		bmanifest_fig = _mk_capsule(tint, boss.position)
		bmanifest_fig.scale = Vector3(1.8, 1.7, 1.8)
		var fm0: StandardMaterial3D = bmanifest_fig.get_meta("mat")
		fm0.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm0.albedo_color.a = 0.3; fm0.emission_enabled = true; fm0.emission = tint
	var fm: StandardMaterial3D = bmanifest_fig.get_meta("mat")
	fm.emission_energy_multiplier = 2.6 if bmanifest_pulse > 0.0 else 1.0
	bmanifest_fig.position = boss.position - back * 0.75

func _author_btransform(spec: String) -> void:
	# the greybox aid: TIER@TRIGGER[@name] - a TRANSFORM line on every boss pattern without one authored (Vasile keeps his own), its tell at the floor
	var parts := spec.split("@")
	var tid := str(parts[0]); var trig := str(parts[1]) if parts.size() > 1 else "composure<50"
	var floor_ms := int(content.get("transformations", {}).get("boss", {}).get("tell_floor_ms", 1000))
	for b in content["patterns"]:
		var pat: Dictionary = content["patterns"][b]
		if pat.get("transform") is Dictionary and pat["transform"].size() > 0: continue
		var tf := {"trigger": trig, "tier": tid, "tell": {"motif": "gather", "ms": floor_ms}, "line": "VEY: he is gathering - his %s is coming. Weather it." % ("Manifest" if tid == "manifest" else "Zone"), "aid": true}
		if tid == "manifest" and parts.size() > 2 and str(parts[2]) != "": tf["manifest"] = str(parts[2])
		pat["transform"] = tf

func _inherit_color() -> Color:
	# the source's colour (a stablemate's), grey for a legacy's older footage, the house's element tint otherwise
	var ih: Dictionary = sim.tform.get("inherit", {})
	if str(ih.get("kind", "")) == "legacy": return Color(0.62, 0.6, 0.55)
	return COLORS.get(str(ih.get("source", "")), Color(0.85, 0.75, 0.55))

func _inherit_render() -> void:
	# NP_09 s5, greybox: a ghost-frame of the source over the caster's silhouette; a dressed source at the apron, mirroring him
	if not sim.tform.has("inherit"):
		if inherit_fig: inherit_fig.queue_free(); inherit_fig = null
		if apron_fig: apron_fig.queue_free(); apron_fig = null
		return
	var col := _inherit_color()
	if inherit_fig == null:
		inherit_fig = _mk_capsule(col, player.position)
		inherit_fig.scale = Vector3(1.08, 1.03, 1.08)
		var gm: StandardMaterial3D = inherit_fig.get_meta("mat")
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color.a = 0.22 if str(sim.tform["inherit"]["kind"]) == "legacy" else 0.3
		if bool(sim.tform["inherit"].get("dressed", false)): apron_fig = _mk_capsule(col, player.position)
	inherit_fig.position = player.position
	if apron_fig:
		apron_fig.position = Vector3((TNBSim.RING_HALF + 0.6) * (1.0 if player.position.x >= 0.0 else -1.0), 0.0, player.position.z)
		apron_fig.rotation = player.rotation

func _spawn_ghost(name: String, secs: float, trail: bool, duo_gild: bool = false, hybrid_els: Array = []) -> void:
	# NP_05 s7: the previous fighter joins a T3 as a spirit afterimage
	if ghost: ghost.queue_free()
	ghost = _mk_capsule(COLORS.get(name, COLORS["RORY"]), player.position)
	var gm: StandardMaterial3D = ghost.get_meta("mat")
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color.a = 0.35
	if trail: gm.emission_enabled = true; gm.emission = COLORS.get(name, COLORS["RORY"]); gm.emission_energy_multiplier = 1.5
	if duo_gild: gm.emission_enabled = true; gm.emission = Color(1.0, 0.82, 0.35); gm.emission_energy_multiplier = 2.0; gm.albedo_color.a = 0.5   # the Duo's afterimage, gilded
	if hybrid_els.size() == 2:                                                                                 # PAC-087: a hybrid's afterimage in both of the pair's elements
		gm.emission_enabled = true; gm.emission = ELEMENT_TINT.get(str(hybrid_els[0]), Color(0.9, 0.9, 1.0)).lerp(ELEMENT_TINT.get(str(hybrid_els[1]), Color(0.9, 0.9, 1.0)), 0.5); gm.emission_energy_multiplier = 2.2; gm.albedo_color.a = 0.5
	var back: Vector3 = (player.position - boss.position).normalized()
	ghost.position = player.position + back * 0.6 + Vector3(0.3, 0, 0)
	ghost_t = secs + 0.4
	ghosts_spawned += 1

func _base_color(who: String) -> Color:
	# the fighter's colour carries the element's aura tint (NP_06 s2.2): frost blue-white, gale silver, granite amber, timber green
	var base: Color = COLORS.get(sim.pname(), COLORS["RORY"]) if who == "P" else BOSS_COLOR
	var F: Dictionary = sim.P if who == "P" else sim.B
	var el := str(F.get("element", "NONE"))
	var c: Color = base.lerp(ELEMENT_TINT[el], 0.35) if ELEMENT_TINT.has(el) else base
	return c.darkened(0.3) if who == "B" and sim.bcomedown.size() > 0 else c                        # PAC-086: his Comedown dims him

func _bump(n: Node3D, amt: float) -> void:
	var mesh: MeshInstance3D = n.get_meta("mesh")
	mesh.position.y = 0.9 - amt
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func(): mesh.position.y = 0.9)

func _flash(a: float) -> void:
	flashrect.color.a = a
	get_tree().create_tween().tween_property(flashrect, "color:a", 0.0, 0.35)

func _tell_fx(secs: float, loud: bool, cue: bool = false) -> void:
	# PI 2 (NP_02 s3): the cue is emphasized - the greybox shows it as a brighter colour and a bigger swell
	var mat: StandardMaterial3D = boss.get_meta("mat")
	mat.albedo_color = Color(1.0, 0.85, 0.2) if loud else Color(1.0, 0.6, 0.2)
	if cue: mat.albedo_color = mat.albedo_color.lightened(0.35)
	var mesh: MeshInstance3D = boss.get_meta("mesh")
	if tell_tween: tell_tween.kill()
	tell_tween = get_tree().create_tween()
	tell_tween.tween_property(mesh, "scale", Vector3(1.25, 1.08, 1.25) if cue else Vector3(1.15, 1.05, 1.15), secs * 0.5)
	tell_tween.tween_property(mesh, "scale", Vector3.ONE, secs * 0.5)

# ============================== HUD =======================================
func _their_corner() -> String:
	# the rival corner's line on the HUD: who he is, what he just did, whether the crowd has him
	if sim.coach.is_empty(): return ""
	var last := ""
	if sim.coach_log.size() > 0: last = str(sim.coach_log[-1])
	return "\n>>> THEIR CORNER: %s [%s]%s%s" % [str(sim.coach.get("label", "")), str(sim.coach.get("archetype", "")), ("  - " + last) if last != "" else "", "   [CROWD ON HIM next corner]" if sim.enemy_lock > 0 else ""]

func _corner_menu() -> String:
	var o: Dictionary = sim.corner_options()
	var out := "\n>>> CORNER %4.1fs   actions left %d   %s %s   [1/A] SEND%s" % [int(sim.corner["t"]) / float(TNBSim.TICK_HZ), int(o["actions_left"]), "GOLDEN DROP pick:" if sim.r6 else "next up", sim.lineup[sim._up_slot()]["name"], "   (their slot: %s)" % sim.boss_slot_label(sim._up_slot())]
	var tk: Dictionary = o.get("talk", {})
	if tk.size() > 0:
		var tl: Array = []
		var keys := {"plan": "Z", "fire": "X", "arm": "C"}
		for op in tk["options"]: tl.append("[%s] %s: \"%s\"" % [keys.get(str(op["option"]), "?"), str(op["label"]), str(op["line"])])
		var hint := ""
		var th: Dictionary = tk.get("hint", {})
		if th.size() > 0: hint = "   (%s says: %s)" % [str(th["via"]), ("go with " if str(th["reveal"]) == "name" else "not ") + str(th["option"])]
		out += "\n   THE TALK with %s%s%s" % [str(tk["who"]), "  [done]" if bool(tk["done"]) else ("" if bool(tk["readable"]) else "  [no read yet]"), hint]
		for ln in tl: out += "\n      " + ln
	var i := 2
	for t in o["tactic"]:
		out += "\n   [%d] %s (%d T)%s - %s" % [i, t["name"], int(t["cost"]), "  [cooldown]" if t["cooldown"] else "", t["text"]]; i += 1
	for su in o["super"]:
		out += "\n   [5] SUPER %s%s - %s" % [su["name"], "  [spent]" if su["used"] else "", su["text"]]
	i = 6
	for st in o["staff"]:
		out += "\n   [%d] %s x%d (%s%s) - %s" % [i, st["name"], int(st["charges"]), ", ".join(PackedStringArray(st.get("by", []))), ("; the crowd %d of %d" % [int(st.get("heat", 0)), int(st["needs"])]) if int(st.get("needs", 0)) > 0 else "", st["text"]]; i += 1
	out += "\n   [9] SAVE THE BAR%s      [0/X] %s %s (%s)" % ["  [set]" if not o["save_bar"] else "", "PICK" if sim.r6 else "SWAP", ", ".join(PackedStringArray(o["swap"])) if o["swap"].size() > 0 else "-", "free" if int(o["swap_cost"]) == 0 else "%d T" % int(o["swap_cost"])]
	out += "\n   [M] let %s play the next segment (free; Tension at %d%%)   [Shift+M] the rest of the dual   [N] hands on%s" % [sim.lineup[sim._up_slot()]["name"], int(sim.TAC.get("corner", {}).get("delegated_tension_pct", 85)), "   >> next: THEIRS" if (sim.delegate_next or sim.delegate_all) else "   >> next: YOURS"]
	return out

func _hiss_line() -> String:
	var mv: Dictionary = sim.player_move()
	if mv.is_empty(): return ""
	var cost := sim.hiss_cost(mv)
	var motion: String = {"HAYMAKER": "haymaker flick", "ARC": "hook flick", "PISTON": "straight flick", "RISE": "uppercut flick", "WALL": "hold RT 400ms"}.get(str(mv["family"]), "?")
	if not sim.castable(mv): return "  %s: sealed" % mv["name"]
	if sim.bar_hold: return "  %s %s: the bar is held for the duo call" % [mv["name"], mv["tier"]]                 # PAC-088
	return "  %s %s %s: %s" % [mv["name"], mv["tier"], "READY (LB + %s, %d%s)" % [motion, int(cost), " from the meter" if sim._meter_pays(mv) else ""] if sim.purse(mv) >= cost else "needs %d%s" % [int(cost), " (the meter)" if sim._meter_pays(mv) else ""], ""]

func _wall_line() -> String:
	var out := ""
	for k in ["B", "P"]:
		var w: Dictionary = sim.wall[k]
		if w.size() == 0: continue
		var who := "HIS WALL" if k == "B" else ("YOUR WALL" if not w.has("shared") else "YOUR SHARED WALL (Two-Hand Winter, one gauge with %s)" % str(sim.lineup[1]["name"] if sim.lineup.size() > 1 else "the partner"))
		if int(w.get("timed_t", 0)) > 0: out += "\n%s  untouchable %.1fs" % [who, int(w["timed_t"]) / float(TNBSim.TICK_HZ)]
		elif float(w.get("pts", 0.0)) > 0.0: out += "\n%s  %s %d/%d   (only counters, power, body, hissatsu chip it)" % [who, _bar(float(w["pts"]), float(w["cap"]), 20), int(w["pts"]), int(w["cap"])]
		elif int(w.get("open_t", 0)) > 0: out += "\n%s  >>> TRUE OPEN %.1fs - x1.25, droppable <<<" % [who, int(w["open_t"]) / float(TNBSim.TICK_HZ)]
	return out

func _cast_line() -> String:
	if sim.cast.is_empty(): return ""
	var c: Dictionary = sim.cast
	var elapsed: int = int(c["total"]) - int(c["t"])
	var win: String = ""
	if c["interruptible"]: win = "  JAB TO BREAK IT %s" % ("[ NOW ]" if elapsed <= int(c["window_t"]) else "[ too late ]")
	else: win = "  not interruptible - wall it / slip it / block it"
	return "\n%s CASTING %s  %s%s" % ["YOU ARE" if c["who"] == "P" else "HE IS", str(c["move"]["name"]).to_upper(), _bar(float(elapsed), float(c["total"]), 16), win if c["who"] == "B" else ""]

func _state_line() -> String:
	var parts: Array = []
	for k in ["P", "B"]:
		for n in sim.states[k].keys(): parts.append("%s:%s" % ["you" if k == "P" else "him", n])
		for n in sim.buffs[k].keys(): parts.append("%s:+%s" % ["you" if k == "P" else "him", n])
	return "" if parts.is_empty() else "\nSTATES  " + "  ".join(PackedStringArray(parts))

func _bar(v: float, vmax: float, w: int) -> String:
	var n := int(clampf(v / vmax, 0.0, 1.0) * w)
	return "[" + "#".repeat(n) + "-".repeat(w - n) + "]"

func _hud() -> void:
	var P: Dictionary = sim.P; var B: Dictionary = sim.B
	var zp := sim.zone(P["pos"]); var zb := sim.zone(B["pos"])
	var head := "TRUE NORTH BOXING :: greybox v6 (sim core 120Hz)   %s %s/%d  %s vs %s   clock %s   SCORE %d-%d (drops %d-%d)   segs %d-%d   EP %d-%d" % \
		[str(sim.fmt.get("label", "")), "GOLDEN DROP" if sim.r6 else "R%d" % (sim.seg_idx + 1), sim.segments(), sim.pname(), sim.boss_label, "no clock" if sim.r6 else "%5.1f" % (sim.clock_t / float(TNBSim.TICK_HZ)), sim.score_p, sim.score_b, sim.drops_p, sim.drops_b, sim.seg_wins_p, sim.seg_wins_b, sim.ep_p, sim.ep_b]
	if sim.bout.size() > 0:
		head += "\n>>> %s vs %s%s   %s   [F10 next Ep1 bout / dual, F11 next objective, F5 again]" % [str(sim.bout["label"]), sim.boss_label, ("  [" + ", ".join(PackedStringArray(sim.lab)) + "]") if sim.lab.size() > 0 else "",
			("OBJECTIVE: " + TNBObjectives.describe(sim.obj)) if sim.obj.size() > 0 else "full segment: drops and EP, the meter at 50"]
		if str(sim.bout.get("district", "")) != "": head += "   in %s (rep %d) [BACKSPACE flee]" % [sim.district_label(str(sim.bout["district"])), sim.rep_of(str(sim.bout["district"]))]   # PAC-101
	var mode_line := ""
	match sim.mode:
		"EIGHT": mode_line = "\n>>> STANDING EIGHT: ENTER / A on the beat  (%d to go)" % int(sim.eight.get("beats_left", 0))
		"CARD": mode_line = "\n>>> %s (%.1fs, ENTER/1 to skip)" % ["TIED ON THE LADDER - GOLDEN DROP: any dressed fighter, condition carried, no clock, first DROP wins" if sim.r6 else "SEGMENT CARD", sim.card_t / float(TNBSim.TICK_HZ)]
		"CORNER": mode_line = _corner_menu() + _their_corner()
		"CLASH": mode_line = "\n>>> MANIFEST CLASH - the fight waits: SPACE / Q / E (block or slip) on the enemy's exchange, a punch on yours - pure timing"   # PAC-086
		"OVER":
			mode_line = "\n>>> %s - F5 again, F1-F4 pick boss, F9 format, F10 Ep1 bouts, Shift+F5 save / Shift+F6 load" % ("BOUT OVER" if sim.bout.size() > 0 else "DUAL OVER")
			if exh != null:                                                                                 # PAC-088: a pair done; the exhibition over only when both are
				mode_line = ("\n>>> EXHIBITION OVER :: %s   TEAM SCORE %d-%d   [F5] again, F9 the rotation formats" % [str(exh.verdict.get("verdict", "")), int(exh.score()[0]), int(exh.score()[1])]) if exh.over else "\n>>> YOUR PAIR IS DONE - the other fights on (\\ to watch it closer)"
			var rl: Array = sim.recruit_lines()
			if rl.size() > 0:                              # NP_08 s2: the recruits the club has flagged - [L] approach, [P] recruit the ready
				mode_line += "\n>>> RECRUITS  [L] approach  [P] recruit  (stable %d)" % sim.stable.size()
				for ln in rl: mode_line += "\n   " + str(ln)
			var wl: Array = sim.string_wall_lines()
			if wl.size() > 0:                              # NP_08 s2.3: the String Wall - who the club can reach through who it has
				mode_line += "\n>>> STRING WALL  (%d of %d cards up)" % [int(sim.string_wall()["known"]), int(sim.string_wall()["total"])]
				for ln in wl: mode_line += "\n   " + str(ln)
			var gl: Array = sim.gym_wall_lines()
			if gl.size() > 0:                              # NP_08 s7: the Gym Wall - the cards where they hang, the lines, what hangs with them
				mode_line += "\n>>> GYM WALL"
				for ln in gl: mode_line += "\n   " + str(ln)
			var gl2: Array = sim.facility_lines()
			if gl2.size() > 0:                             # PAC-089: NP_10 s7 - the Old Gym: each track's next tier, the training slots, the shelf
				mode_line += "\n>>> THE OLD GYM  [1-5] renovate  [T] train  (HBP %d, Spirits %d, Beans %d)" % [int(sim.rewards.get("hbp", 0)), int(sim.rewards.get("spirits", 0)), int(sim.rewards.get("beans", 0))]
				for ln in gl2: mode_line += "\n   " + str(ln)
			if not sim.TECH.is_empty() and sim.dressed.size() > 0:  # PAC-091: NP_11 s2/s8 - the focused card's slots and kit, the shop's next, the lessons, the tapes, the re-teach
				mode_line += "\n>>> TECHNIQUES  [ buy  ] lesson  ' tape  / re-teach  = carry  - put down  (HBP %d)" % int(sim.rewards.get("hbp", 0))
				for tl in sim.technique_lines(_focus_name()): mode_line += "\n   " + str(tl)
			if not sim.GROW.is_empty() and sim.dressed.size() > 0:  # PAC-090: NP_11 s3/s4/s6 - each dressed card's growth, the focus marked
				mode_line += "\n>>> GROWTH  [N] a node  [Shift+N] respec  [Z] raise  [X] ascend  [M] the mirror  [.] next  (the jar: %s; Spirits %d)" % [sim.jar_text(), int(sim.rewards.get("spirits", 0))]
				for gi in sim.dressed.size(): mode_line += "\n   %s%s" % ["> " if gi == clampi(growth_focus, 0, sim.dressed.size() - 1) else "  ", sim.growth_line(str(sim.dressed[gi]["name"]))]
			if not sim.GEAR.is_empty() and sim.dressed.size() > 0:   # PAC-094: NP_11 s5 - the focused card's gear, the locker, the shop's next
				mode_line += "\n>>> GEAR  \\ buy  , wear  Shift+, take off  (HBP %d)" % int(sim.rewards.get("hbp", 0))
				for gear_ln in sim.gear_lines(_focus_name()): mode_line += "\n   " + str(gear_ln)
			var scl: Array = sim.scouting_lines()
			if scl.size() > 0:                             # PAC-098: NP_08 s2.4 - the machine and the open mat
				mode_line += "\n>>> SCOUTING  ` pull  Shift+` sign  (Prestige %d, stable %d)" % [int(sim.rewards.get("prestige", 0)), sim.stable.size()]
				for ln in scl: mode_line += "\n   " + str(ln)
			for rpl in sim.rep_lines(): mode_line += "\n>>> " + str(rpl)                                      # PAC-101: NP_02 s4 - the districts' rep, the milestones
			for vdl in sim.vendor_lines(): mode_line += "\n>>> " + str(vdl)                                  # PAC-103: NP_02 s4 - the shops' shelves, the rep a closed one wants
			var lkl: Array = sim.locker_lines(str(sim.ECO.get("locker", {}).get("browse", ["house"])[locker_by]) if sim.ECO.get("locker", {}).size() > 0 else "house", _locker_focus())
			if lkl.size() > 0:                             # PAC-100: NP_08 s4 - the locker room: the browse, the comparison card, the releases waiting
				mode_line += "\n>>> LOCKER ROOM  8 browse  9 next card  0 release  Shift+0 take back"
				for ln in lkl: mode_line += "\n   " + str(ln)
			var rol: Array = sim.roles_lines()
			if rol.size() > 0:                             # PAC-099: NP_08 s1 - the bench and its roles
				mode_line += "\n>>> ROLES  7 assign  Shift+7 back to the ring  (day %d)" % int(sim.rewards.get("day", 1))
				for ln in rol: mode_line += "\n   " + str(ln)
			if not sim._mirror_rules().is_empty() and sim.dressed.size() > 0:   # PAC-093: NP_02 s2.2 - the focused card's record and the copy it makes ([M] fights it)
				mode_line += "\n>>> HABITS  [M] the mirror  (the tracker's record)\n   " + sim.habits_line(_focus_name())
			var fl: Array = sim.forge_lines()
			if fl.size() > 0:                              # NP_08 s6: the Forge - the hybrids forged, each pair near it: its hybrid and price, or what it waits on
				mode_line += "\n>>> FORGE  [F] the first pair ready  (Spirits %d, Beans %d)" % [int(sim.rewards.get("spirits", 0)), int(sim.rewards.get("beans", 0))]
				for ln in fl: mode_line += "\n   " + str(ln)
			var hl: Array = sim.house_lines()
			if hl.size() > 0:                              # NP_08 s3: the houses met - their blessing lines, their members' standing, the graph's flips
				mode_line += "\n>>> HOUSES"
				for ln in hl: mode_line += "\n   " + str(ln)
	if sim.mode == "FIGHT" and sim.zone_line() != "": mode_line += "\n>>> " + sim.zone_line()                   # PAC-082: the Zone's clock, or the Comedown's
	if (sim.mode == "FIGHT" or sim.mode == "CLASH") and sim.bzone_line() != "": mode_line += "\n>>> " + sim.bzone_line()   # PAC-086: his gathering, his tier, his Comedown, the Clash
	if sim.mode == "FIGHT" and sim.tick < matchup_until and matchup_text != "": mode_line += "\n" + matchup_text
	if sim.tick < pi_toast_until and pi_toast != "": mode_line += "\n>>> " + pi_toast
	if (sim.tick < toast_until or sim.mode == "OVER") and toast_text != "": mode_line += "\n>>> " + toast_text
	if sim.clinch.size() > 0:
		var ci: int = sim.clinch["i"]
		var cue_txt := "done"
		if ci < sim.clinch["cues"].size():
			var c: int = sim.clinch["cues"][ci]; var w: int = sim.clinch["windows"][ci]; var t: int = sim.clinch["t"]
			var side: String = sim.clinch["sides"][ci]
			cue_txt = ("<<< LEFT" if side == "L" else "RIGHT >>>") + ("  [ NOW ]" if absi(t - c) <= w else "  [ %4.0f ms ]" % (maxf(0.0, float(c - w - t)) * 1000.0 / TNBSim.TICK_HZ))
		mode_line += "\n>>> CLINCH: %s   cue %d/4   beats %d/%d   (LS or A/D alternate; ENTER/A parity; hold C/LT on the resolve = reset)" % [cue_txt, ci + 1, int(sim.clinch["beats"]), int(sim.clinch["need"])]
	var bug := ""
	if sim.relay_chain > 0: bug += "   RELAY %s%s" % ["|".repeat(sim.relay_chain), "  FULL RELAY" if sim.full_relay else ""]
	if P["charge_t"] > 0: bug += "   CHARGED %.1fs" % (P["charge_t"] / float(TNBSim.TICK_HZ))
	if sim.save_bar: bug += "   [holding the bar]"
	if sim.tactic_fx.size() > 0: bug += "   tactics: " + ",".join(PackedStringArray(sim.tactic_fx.keys()))
	if sim.aff.get("style_adv", "") != "" or sim.aff.get("element_adv", "") != "":
		bug += "   RINGS style %s elem %s" % ["<" if sim.aff.get("style_adv", "") == "P" else (">" if sim.aff.get("style_adv", "") == "B" else "="), "<" if sim.aff.get("element_adv", "") == "P" else (">" if sim.aff.get("element_adv", "") == "B" else "=")]
	if sim.aff.get("feud", false): bug += "   FEUD x1.25"
	if sim.brelay_chain > 0: bug += "   THEIR RELAY %s" % "|".repeat(sim.brelay_chain)
	if B["charge_t"] > 0: bug += "   HE IS CHARGED %.1fs" % (B["charge_t"] / float(TNBSim.TICK_HZ))
	if sim.player_lock > 0: bug += "   [CROWD ON YOU next corner]"
	if sim.crowd_heat > 0.0 and sim.bout.is_empty(): bug += "   CROWD %s %d" % [_bar(sim.crowd_heat, 100, 10), int(sim.crowd_heat)]   # NP_01 s1: the building behind you (PAC-074)
	if sim.host and sim.bout.is_empty(): bug += "   HOSTED (the Old Gym)"                                   # PAC-089: at the club's gym
	if sim.pi_vs() > 0: bug += "   PI %d vs %s%s" % [sim.pi_vs(), sim.bdialect.capitalize(), " [page]" if sim.pi_vs() >= 3 else ""]
	if sim.bremix.size() > 0: bug += "   REMIX: %s" % str(sim.bremix.get("label", ""))
	if sim.mode == "FIGHT": bug += "   HIS NEUTRAL: " + sim.neutral_line()
	if sim.directives_done.size() > 0: bug += "   phase: " + ", ".join(PackedStringArray(sim.directives_done))
	if sim.delegated: bug += "   [AUTO: %s plays - punches %d, feints %d, reads %d, casts %d]" % [sim.pname(), int(sim.auto_stats.get("punches", 0)), int(sim.auto_stats.get("feints", 0)), int(sim.auto_stats.get("tell_jabs", 0)) + int(sim.auto_stats.get("dodges", 0)) + int(sim.auto_stats.get("blocks", 0)), int(sim.auto_stats.get("casts", 0))]
	if sim.btactic_fx.size() > 0: bug += "   his tactics: " + ",".join(PackedStringArray(sim.btactic_fx.keys()))
	if sim.bwarnings > 0: bug += "   REF WARN x%d (him)" % sim.bwarnings
	if sim.pwarnings > 0: bug += "   REF WARN x%d (you)" % sim.pwarnings
	if sim.pholding > 0: bug += "   holding calls x%d (you)" % sim.pholding
	if audio_assist: bug += "   [audio-assist cue ON]"
	if exh != null:                                                                                     # PAC-088: both pairs, the ring clock, the team score, the duo sync
		var xl: Array = exh.lines()
		mode_line = "\n>>> " + "\n".join(PackedStringArray(xl)) + mode_line
	if formation_open or show_formation:
		mode_line += "\n>>> FORMATION (NP_10 s2)%s" % ("   [1] Standard  [2] Ambush  [3] Wall-First  [4] Relay Ladder  [5] card order   ENTER = the bell" if formation_open else "   [TAB] hide")
		for ln in sim.formation_lines(): mode_line += "\n" + str(ln)
	hud.text = head + bug + mode_line + "\n" \
		+ "ZONE you:%s%s  him:%s%s   dist %.2fm   tick %d%s\n" % [zp, " TRAPPED" if sim.trapped_p else "", zb, " TRAPPED" if sim.trapped_b else "", P["pos"].distance_to(B["pos"]), sim.tick, "  [HITSTOP]" if sim.freeze_t > 0 else ""] \
		+ "YOU   stam %s  chin %s  guard %s%s   %s   [%s/%s]\n" % [_bar(P["stamina"], 100, 14), _bar(P["comp"], P["comp_max"], 14), _bar(P["guard"], P["guard_max"], 10), "  OPEN!" if P["guard_open_t"] > 0 else "", P["dodge"] if P["dodge"] != "" else "", str(P.get("style", "")), str(P.get("element", ""))] \
		+ "BOSS  chin %s   phase %d   %s%s%s   [%s/%s]\n" % [_bar(B["comp"], B["comp_max"], 14), sim.bphase, "TELL" if sim.bstate == "FAKE" else ("HITCH" if sim.bstate == "HOLD" else sim.bstate), ("  << TELL - JAB HIM NOW" if sim._interruptible(sim.bstring) else "  << TELL - THIS ONE DOESN'T BREAK: MOVE") if (sim.bstate == "TELL" or sim.bstate == "FAKE") else ("  hands DOWN" if sim.hands_down_t > 0 else ""), ("  [" + B["dodge"] + "]") if B["dodge"] != "" else ("  [GUARD]" if (B["blocking"] or B["guard_t"] > 0) else ""), str(B.get("style", "")), str(B.get("element", ""))] \
		+ "TENSION %s %3.0f  %s%s%s%s   THEIRS %s %3.0f" % [_bar(sim.tension, 100, 16), sim.tension, _hiss_line(), "   counter!" if P["counter_t"] > 0 else "", "   FLASH!" if P["flash_t"] > 0 else "", "   relay chain %d" % sim.relay_chain if sim.relay_chain > 0 else "", _bar(sim.btension, 100, 12), sim.btension] \
		+ _wall_line() + _cast_line() + _state_line()
	hud.text += "\nESC controls / remap  |  %s%s" % ["BUTTON CHORDS" if combat_input.preset == "chords" else "STICK / MOUSE FLICKS", "  |  PRACTICE DUMMY" if practice_dummy else ""]

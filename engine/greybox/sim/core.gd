extends RefCounted
# Loaded by preload("res://sim/core.gd") - no class_name: headless runs must not
# depend on the editor's global class cache.
# TRUE NORTH BOXING - deterministic combat simulation core (NP_14 C1-C7).
# Pure: no Nodes, no wall clock, seeded RNG, fixed 120Hz ticks driven by an
# input dictionary. Presentation (main.gd) renders this state; tests drive it
# directly. Every ms constant from combat_tuning.v1.json is converted to ticks
# at load; geometry (C2) replaces dodge tables; hitstop/slow-time are sim state.

const TNBProfile := preload("res://sim/profile.gd")   # the fighter who plays without you (NP_10 s8)
const TNBObjectives := preload("res://sim/objectives.gd")   # the scrap's micro-objective, judged from events (NP_02 s2.1)
const TNBAssembler := preload("res://sim/assembler.gd")   # the generic opponent assembler (NP_04 s9)
const BodyControl := preload("res://sim/body_control.gd")
const PunchContact := preload("res://sim/punch_contact.gd")
const BoxingTechniques := preload("res://sim/boxing_techniques.gd")
const RigSpace := preload("res://presentation/rig_space.gd")

const TICK_HZ := 120
const DT := 1.0 / 120.0
const RING_HALF := 3.5
const HEAD_H := 1.55
const ENGAGE_DIST := 1.9            # boss keeps this spacing (m, center to center)
const BUFFER_TICKS := 6             # C3: 50ms punch buffer
const LUNGE_P := 0.20               # a punch carries the body forward (m)
const LUNGE_B := 0.30

# C2 punch regions, attacker frame, RIGHT hand (left hand mirrors lateral)
const GEO := {
	"STRAIGHT":  {"reach": 2.05, "lat": [-0.18, 0.18], "h": [1.35, 1.80]},
	"FLARED":    {"reach": 2.00, "lat": [-0.25, 0.25], "h": [1.10, 1.85]},
	"HOOK":      {"reach": 1.90, "lat": [-0.15, 0.50], "h": [1.35, 1.75]},
	"HOOKERCUT": {"reach": 1.90, "lat": [-0.20, 0.55], "h": [1.20, 1.80]},
	"UPPERCUT":  {"reach": 1.75, "lat": [-0.15, 0.15], "h": [0.95, 1.90]},
}
const DODGE := {   # ticks at 120Hz: 260ms=31, 300ms=36, 400ms=48
	"SLIP":  {"t": 31, "lat": 0.35, "h": HEAD_H, "back": 0.0},
	"DUCK":  {"t": 36, "lat": 0.0,  "h": 1.15,   "back": 0.0},
	"LEAN":  {"t": 36, "lat": 0.0,  "h": HEAD_H, "back": 0.30},
	"WEAVE": {"t": 48, "lat": 0.40, "h": 1.30,   "back": 0.05},
}
const BOSSES := ["cassidy_vane", "yuri_kowalchuk", "jean_guy_moreau", "sam_tagaq",
	"ada_okafor", "alfie_crane", "anders_vey", "carter_okafor", "chiamaka_okafor", "commissioner_cal",
	"deshawn_vaughn", "efua_osei", "hc0_surety", "hc4_cartographer", "hc7_echo", "hc9_choir", "ioan_vasile",
	"itzel_reyes_ortega", "marta_okonkwo_tremblay", "moira_macisaac", "remy_moreau", "sora_kannagi",
	"tam_nguyen_roy", "yordanis_baro"]
const LINEUP_MILLBROOK := [   # NP_01 s8 mini-dual: 4 dressed - three slots and a reserve (Ep1's four fighter cards)
	{"name": "RORY",   "hissatsu": "Aurora Borealis Breaker", "talk": "fire", "style": "BOXERPUNCHER", "element": "FROST", "house": "none",
		"stats": {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}},
	{"name": "PRIYA",  "hissatsu": "Marginalia", "talk": "plan", "style": "OUTBOXER", "element": "GALE", "house": "none",
		"stats": {"PWR": 35, "SPD": 60, "CHN": 40, "RFX": 70, "BLK": 50, "STA": 55, "HRT": 60}},
	{"name": "MARCUS", "hissatsu": "Chinook Rush", "talk": "arm", "style": "SLUGGER", "element": "GRANITE", "house": "none",
		"stats": {"PWR": 70, "SPD": 40, "CHN": 65, "RFX": 35, "BLK": 40, "STA": 55, "HRT": 70}},
	{"name": "JUNE",   "hissatsu": "First Snap", "talk": "fire", "reserve": true, "style": "SWARMER", "element": "FROST", "house": "none",
		"stats": {"PWR": 30, "SPD": 75, "CHN": 35, "RFX": 60, "BLK": 20, "STA": 60, "HRT": 70}},
]
const LINEUP_MILLBROOK_8 := [   # NP_01 s2 sanctioned dual: 8 dressed - five slots (R1 opener .. R5 anchor) and three reserves. Recruits' cards are editorial (REGISTER_COMMANDS_010)
	{"name": "RORY",   "hissatsu": "Aurora Borealis Breaker", "talk": "fire", "style": "BOXERPUNCHER", "element": "FROST", "house": "none",
		"stats": {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}},
	{"name": "JUNE",   "hissatsu": "First Snap", "talk": "fire", "style": "SWARMER", "element": "FROST", "house": "none",
		"stats": {"PWR": 30, "SPD": 75, "CHN": 35, "RFX": 60, "BLK": 20, "STA": 60, "HRT": 70}},
	{"name": "PRIYA",  "hissatsu": "Marginalia", "talk": "plan", "style": "OUTBOXER", "element": "GALE", "house": "none",
		"stats": {"PWR": 35, "SPD": 60, "CHN": 40, "RFX": 70, "BLK": 50, "STA": 55, "HRT": 60}},
	{"name": "MARCUS", "hissatsu": "Chinook Rush", "talk": "arm", "style": "SLUGGER", "element": "GRANITE", "house": "none",
		"stats": {"PWR": 70, "SPD": 40, "CHN": 65, "RFX": 35, "BLK": 40, "STA": 55, "HRT": 70}},
	{"name": "SAM",    "hissatsu": "Sorry Eh", "talk": "arm", "style": "BOXERPUNCHER", "element": "FROST", "house": "tagaq",
		"stats": {"PWR": 55, "SPD": 45, "CHN": 90, "RFX": 50, "BLK": 80, "STA": 70, "HRT": 85}},
	{"name": "DEX",    "hissatsu": "Prodigal", "talk": "arm", "reserve": true, "style": "SLUGGER", "element": "TIMBER", "house": "macisaac",
		"stats": {"PWR": 62, "SPD": 48, "CHN": 60, "RFX": 45, "BLK": 50, "STA": 60, "HRT": 65}},
	{"name": "YURI",   "hissatsu": "Grain Elevator", "talk": "fire", "reserve": true, "style": "SLUGGER", "element": "GRANITE", "house": "kowalchuk",
		"stats": {"PWR": 80, "SPD": 40, "CHN": 70, "RFX": 40, "BLK": 45, "STA": 60, "HRT": 75}},
	{"name": "MARTA",  "hissatsu": "Miroir d'Hiver", "talk": "plan", "reserve": true, "style": "OUTBOXER", "element": "FROST", "house": "tremblay",
		"stats": {"PWR": 40, "SPD": 65, "CHN": 50, "RFX": 85, "BLK": 70, "STA": 55, "HRT": 60}},
]
const PUNCH_VERBS := {
	"JAB": "L_STRAIGHT", "L_STR": "L_STRAIGHT", "R_STR": "R_STRAIGHT",
	"COUNTER_R_STR": "R_STRAIGHT", "STEP_R_STR": "R_STRAIGHT", "UNDER_ELBOW_CROSS": "R_STRAIGHT",
	"L_HOOK": "L_HOOK", "CHECK_HOOK": "L_HOOK", "LT_L_HOOK": "L_HOOK", "COUNTER_L_HOOK": "L_HOOK",
	"R_HOOK": "R_HOOK", "LT_R_HOOK": "R_HOOK", "R_UPC": "R_UPPERCUT", "LT_R_UPC": "R_UPPERCUT",
	"L_UPC": "L_UPPERCUT", "R_HAY": "R_HOOKERCUT", "R_OVERHAND": "R_FLARED",
	"PULL_COUNTER_OVERHAND": "R_FLARED",
	"L_HAY": "L_HOOKERCUT", "L_OVERHAND": "L_FLARED",             # PAC-093: the lead hand's two rows, so a mirror throws every row a fighter can
}

var T: Dictionary
var patterns: Dictionary = {}       # name -> compiled pattern
var boss_names: Array = []
var lineup: Array = []
var rng := RandomNumberGenerator.new()

# ---- state ----
var tick := 0
var P: Dictionary
var B: Dictionary
var pattern: Dictionary
var boss_name := ""
var mode := "FIGHT"                 # FIGHT | EIGHT | CORNER | OVER
var clock_t := 0                    # ticks left in segment
var freeze_t := 0                   # hitstop (C5)
var boss_acc := 0.0                 # slow-time accumulator for boss timers
var feed := ""
var events: Array = []

# dual
var seg_idx := 0
var drops_p := 0
var drops_b := 0
var score_p := 0                    # NP_01 s3: DROP 1, FLASH DROP 2, SEGMENT KO 3, cumulative over the dual
var score_b := 0
var ep_p := 0
var ep_b := 0
var tension := 0.0
var contributed := 0.0
var charged := false

# boss agent
var bstate := "IDLE"
var btimer := 0
var bstring := ""
var bqueue: Array = []
var bphase := 1
var bdesp_used := false
var bpending: Dictionary = {}
var bforce_opts: Dictionary = {}     # punish-response modifiers for the forced string
var swap_restore: Dictionary = {}    # swap_weights(...) Ns restore timer
var clinch_t := 0
var wall_broken := false
var rope_time_t := 0
var passive_t := 0
var clean_t := 0                     # ticks since the player last took a hit
var head_streak := 0
var sensors := {}                    # thresholds parsed from this pattern's triggers
var tier_fired := 0

# tracker
var tokens: Array = []
var flags := {}

# reads (bait/punish detectors)
var center_hold_t := 0
var block_hold_t := 0
var punch_ticks: Array = []
var punch_rows: Array = []
var last_zone_p := "MID"
var lb_prev := false
var lb_rise_t := 0
var threw_since_arm := false
var punish_cd := {}
var gassed_fired := false
var taunt_t := 0
var pinned_p_t := 0
var pinned_b_t := 0
var trapped_p := false
var trapped_b := false
var p_vel := Vector2.ZERO
var eight := {}

# PAC-054: sensors, clinch scramble, referee
var hooks_enabled := true            # tests: false = sensors still fire as events, hooks stay quiet
var btransform_on := true            # tests: false = his authored transformation stays on his page, unrun (the generic stages on a boss who has one)
var library: Dictionary = {}         # hissatsu name -> library record (data/hissatsu_library.v2.json)
var audio_assist := false
var clinch: Dictionary = {}          # active clinch scramble (NP_03 s7)
var clinch_ticks: Array = []         # player clinch inputs, for the holding call
var sprint_cd := 0
var backstep_ticks: Array = []
var retreat_d := 0.0
var neutral_t := 0
var neutral_cd := 0
var cadence: Array = []              # last 7 player punch execution ticks
var hands_down_t := 0
var tell_start_tick := -1
var tell_reacted := false
var react_ticks: Array = []
var bwarnings := 0                   # referee warnings banked by the boss (NP_01 s5 ladder)
var pwarnings := 0                   # ...and by the player
var pholding := 0                    # holding-without-work breaks called on the player
var bsurvival_used := false          # NP_03 s7: a wobbled boss grabs once per segment
var block_prev := false

# PAC-056: hissatsu effect VM (NP_05 s4-s9), Wall Gauge (NP_05 s8)
var cast: Dictionary = {}            # active cast: who, move, t (windup ticks left), total, ...
var states := {"P": {}, "B": {}}     # named STATE -> ticks left (0 = instant, consumed at cast)
var buffs := {"P": {}, "B": {}}      # named BUFF -> {"t": ticks, "v": value}
var wall := {"P": {}, "B": {}}       # {"pts","cap","reforms","breaks","open_t","timed_t","migrate_at"}
var relay_chain := 0                 # consecutive CHARGED segments (NP_05 s6)
var t3_unlocked := false
var tform: Dictionary = {}              # PAC-082: the transformation live this segment - {tier, who, t, t0, stam, slip_win, cost}
var comedown: Dictionary = {}           # PAC-082: the Comedown after it - {who, t, stats}
var transformed: Dictionary = {}        # PAC-082: this dual's transformations, fighter -> tier (NP_09 s1: one per fighter per dual)
var btsurge: Dictionary = {}            # PAC-086: his SURGE gathering - {tier, t, line}: the tell the player feels coming
var btform: Dictionary = {}             # PAC-086: his transformation live this segment - {tier, who, t, t0, stam, slip_win, weathered, shaved, answered, dropped, echoes, manifest}
var bcomedown: Dictionary = {}          # PAC-086: his Comedown - {who, t, stats}: the player's answer window
var btransformed: Dictionary = {}       # PAC-086: this dual's boss transformations, boss -> tier
var mclash: Dictionary = {}             # PAC-086: the Manifest Clash in flight (NP_09 s4)
var duo: Dictionary = {}                # PAC-080: the Duo relay live this segment - {pair, partner, caster, level, move} (NP_08 s5.2 Lv4, NP_05 s7)
var exhibit := ""                       # PAC-088: this engagement's pair in an Exhibition 2v2 ("A" / "B" - sim/exhibition.gd runs both, NP_01 s8); "" = a dual
var bar_hold := false                   # PAC-088: the exhibition holds the team bar for the pair's duo call (a window open; a profile at the call's bar) - no hissatsu of his own
var hiss_casts_seg := 0
var dmg_hist := {"P": [], "B": []}   # damage taken this segment (The Mean)
var wall_migrate := 0                # gauge points carried to the next boss (HC-0)
var gauge_jabs := 0                  # jab-class punches into a live gauge (Sam's literacy hook)
var commentary_mute_t := 0
var lb_block_t := 0                  # LB + RT held: the WALL motion (400ms)

# PAC-057: feints (NP_03 s8)
var feint_log: Array = []            # [tick, row] of recent feints (10s window)
var feint_wise: Dictionary = {}      # row -> tick until which he stops reacting to that feint

# PAC-063: scraps and spars (NP_02 s2) - the two smaller sizes on the same sim
var BOUTS: Dictionary = {}           # data/bouts.v1.json
var SCRAPS: Dictionary = {}          # data/scrap_objectives.v1.json, by id
var bout: Dictionary = {}            # {} = a dual; {"kind": "scrap"|"spar", "objective", "param", "card", "label", "flags"}
var dual_fmt: Dictionary = {}        # the dual's format, kept while a bout runs
var obj: Dictionary = {}             # the objective record (TNBObjectives)
var lab: Array = []                  # spar lab flags live this bout
var bout_cap_t := 0                  # the scrap's cap in ticks (elapsed = cap - clock)
var boss_label := ""                 # the name on the card (an NPC's, or the boss's)
var backstep_ev_t := 0

# PAC-068: the reward economy (NP_11 s6, NP_02 s2/s4, NP_08 s2.4/s5) - the sim pays, it never spends
var ECO: Dictionary = {}             # data/economy.v1.json
var rewards: Dictionary = {"xp": {}, "spirits": 0, "prestige": 0, "hbp": 0, "kizuna": {}, "kizuna_day": {}, "log": [], "day": 1}   # the ledger: rides with the save, hashed
var seg_xp := 0                      # XP the fight's events earned this segment / bout, credited at its end
var dual_xp := 0                     # the dual's XP so far (the reserves' 50% at the end)
var last_toast: Dictionary = {}      # the last reward toast (presentation)

# PAC-072: The Talk (NP_10 s4) - the corner's fifth action; the profile lives on the card ("talk"), the lines and the reveal here
var TALK: Dictionary = {}            # data/talk.v1.json

# PAC-073: the formation screen and the sealed order (NP_10 s2-3, NP_01 s7) - your board, his projection, the rings overlay
var FORMATION: Dictionary = {}       # data/formation.v1.json
var board: Dictionary = {}           # the sealed board: {name, archetype, slots, reserves, staff (corps ids), why}; {} = the card order (the pre-PAC-073 lineup)
var seal_n := 0                      # which dual this is on the sim (new_dual counts): the seal's rolls are keyed by it
var dual_rng0 := 0                   # the fight RNG's position when this dual was set up (a board sealed before the bell sets it up again from here)
var dual_t0 := 0                     # the tick this dual was set up at: the bell has not rung while tick == dual_t0
var sealed_p: Array = []             # your order as sealed at the bell (names; the corner's swaps change the revealed, not the seal)
var sealed_b: Array = []             # his order as sealed at the bell (hidden; the projection is your read of it)
var bdecoy := false                  # his corner ran a decoy seal this dual (NP_10 s3: the projection is poisoned, the confidence lies)
var bprojection: Dictionary = {}     # his projection as it stood at the bell: the formation screen is live until then, the read you sealed against after

# PAC-074: the staff system (NP_10 s6) - a corps of ten, three dressed, passives while dressed, levels by use; the crowd the Hype works (NP_01 s1)
var STAFF: Dictionary = {}           # data/staff.v1.json
var staff_fx: Dictionary = {}        # the dressed staff's passives, read at each segment's bell (a level earned mid-dual counts from the next)
var crowd_heat := 0.0                # the building behind you this dual, 0-100: your spectacle raises it, Raise the Roof converts it

# PAC-075: recruitment (NP_08 s2) - the condition grammar over the sim's own ledgers; the stable the recruits join
var RECRUITS: Dictionary = {}        # data/recruits.v1.json
var STRINGS: Dictionary = {}         # data/string_wall.v1.json (PAC-076: the String Wall's maps, nodes and links)
var HOUSES: Dictionary = {}          # data/houses.v1.json + the feud graph's provisional edges (PAC-077: blessings, the house status)
var seg_cast_houses: Array = []      # PAC-077: the house of every hissatsu your fighter cast this segment ("" for a houseless move)
var crowd_spent_dual := 0.0          # PAC-077: crowd heat your corner converted this dual (Tagaq's witness asks for none)
var trait_uses := {}                 # PAC-078: a once-per-dual trait's uses (Never Twice), keyed by side and fighter
var seg_tick0 := 0                   # PAC-078: the tick this segment opened (First Frost's opening 15 s)
var TRANS: Dictionary = {}           # data/transformations.v1.json (PAC-082: NP_09's ladder - the Zone runs)
var HYB: Dictionary = {}             # data/hybrids.v1.json (PAC-087: NP_08 s6's hybrid research - the Forge, its prices, the composer)
var FAC: Dictionary = {}             # data/facilities.v1.json (PAC-089: NP_10 s7's club facilities - five tracks, T1 -> T3, their prices and effects)
var GROW: Dictionary = {}            # data/growth.v1.json (PAC-090: NP_11 s3/s4/s6 - the ability boards, the passives, the raises, rarity)
var TECH: Dictionary = {}            # data/techniques.v1.json (PAC-091: NP_11 s2/s8 - the technique slots, the T0 at 5, the shop, the masters, the tapes, the re-teach)
var ACAD: Dictionary = {}            # data/academy.v1.json (PAC-092: NP_07 s10 - the Toronto academy's prodigies and their syntheses)
var GEAR: Dictionary = {}            # data/gear.v1.json (PAC-094: NP_11 s5 - accessories and gear, their sources, the signature pieces)
var academy_on := false              # PAC-092: the academy fielded in every enemy segment (Director Vey's corner)
var host := false                    # PAC-089: this dual is hosted at the club's gym (Front of House's crowd base and Prestige; the exhibition's home venue)
var GYMWALL: Dictionary = {}         # data/gym_wall.v1.json (PAC-079: the Gym Wall's grid, its letter, its decorations, the suggestion)
var gym_wall: Dictionary = {}        # PAC-079: the wall as it hangs - cards on cells, the unpinned, the decorations (never in the state hash: zero stats)
var stable: Array = []               # every card the club owns (NP_08 s1): the dressed and the rest; a recruit joins here, a board dresses from here

# PAC-071: the IDLE lines as the boss's neutral game (NP_04 s2) - how he closes, the range he keeps, his guard, his clocks
var NEUTRAL: Dictionary = {}         # data/neutral.v1.json
var neutral_on := true               # tests: false = a frozen boss keeps the shared approach and the 0.35 guard (the pre-PAC-071 behaviour)
var bidle: Dictionary = {}           # this segment's neutral profile, built from the pattern's IDLE lines at load
var bneutral_t := 0                  # his neutral clock: boss steps this segment (the beat, the orbit reversals, the taunt and tempo clocks)
var btaunts := 0                     # taunts so far this segment
var btaunt_t := 0                    # a taunt in progress: his read is off while he performs it
var btempo_fast := false             # Tam's tempo shift: which tempo he is on
var bfootwork_audio := true          # the footwork audio flag the presentation reads (Jean-Guy / Choir silent, Marta quiet while arming)

# PAC-070: the generic opponent assembler (NP_04 s9) - non-named opponents built from the piece library
var PIECES: Dictionary = {}          # data/pattern_pieces.v1.json
var generics: Dictionary = {}        # name -> the spec of a generic registered for this dual (a filler slot)
var gpatterns: Dictionary = {}       # name -> its assembled pattern (state: it rides in a snapshot; the content stamp never sees it)
var generic_slots: Dictionary = {}   # enemy segment index -> spec: the slot a generic fills
var bgeneric: Dictionary = {}        # the spec of the generic fighting this segment ({} for a named boss); hashed

# PAC-067: the pattern, all of it - the SELECT block's remaining lines and the META keys with a mechanic behind them
var bselect_lines: Array = []        # the SELECT block's conditional lines, parsed at load: {cond, string, delta, secs}
var btransient: Array = []           # transient weight deltas: {string, delta, until} (Yuri's after_hit_taken)
var bcalled_phases: Array = []       # clock phases the player's corner has called early (Vasile's corner intel)
var blanded: Dictionary = {}         # string -> punches of it that landed clean (Baro's Examen gate)

# PAC-066: the phase scripts, all of them - each boss's own mechanic behind the lines the executor carried
var btempo_i := 0                    # Chiamaka's polyrhythm: which tempo carries the next beat
var bstrings_done := 0               # strings completed this segment (Echo's splice count)
var bcooldown_until: Dictionary = {} # string -> tick it may be selected again (Marta's greedy Mirror)
var breads: Dictionary = {}          # string -> tells the player reacted to or broke (Cal's recognition drift)
var bdialogue := ""                  # a dialogue flag a phase raised (corner / shame) - presentation, hashed
var btrue_pattern := false           # Tam: the borrowed clothes are off

# PAC-065: the opponent's mind games (NP_04 s4, s6) - the interrupt block honoured, phase directives executed, the remix layer
var REMIX: Dictionary = {}           # data/remixes.v1.json
var remix_for: Dictionary = {}       # boss name -> remix id to load over his pattern ("" / absent = the original)
var bremix: Dictionary = {}          # the remix record live this segment (id, label, ops) - {} when the original fights
var bmods: Dictionary = _fresh_mods()  # executed directives on the boss (speed x, strength, all_damage, movement, the cadences, the splice, the states, the cooldowns, the drift, the pull)
var binterrupts: Dictionary = {}     # string -> interrupts this segment (the burn count, NP_04 s4)
var bfeint := ""                     # "" | "delay" | "cancel": the string in TELL is its feint variant
var bhold_t := 0                     # the feint's delay after the tell, in ticks
var bdesync_widen := false           # Ada's reward state: the next tell is +100ms wider
var bdesync_ms := -1.0               # a phase directive's override of the interrupt block's desync duration (-1 = the block's)
var directives_done: Array = []      # the phase directives executed this segment, verbatim (gates + presentation)
var directives_carried: Array = []   # the ones carried and not executed, verbatim

# PAC-064: Pattern Intel (NP_02 s3) - the recon ledger the sim reads and ticks
var PI: Dictionary = {}              # data/pattern_intel.v1.json
var pi: Dictionary = {"dialects": {}, "bosses": {}}   # the ledger: per dialect {scraps, spars, segments}, per boss {beaten}; rides with the save, hashed
var bdialect := ""                   # this opponent's dialect key (his House, his own id, or the card's)
var pi_log: Array = []               # every rung crossed this session (presentation + the Scout Book shelf)

# PAC-062: manager mode (NP_10 s8) - a segment played by the card's own profile
var delegated := false               # this segment is the profile's: the fight keys of the intent are ignored, the corner keys are not
var delegate_next := false           # chosen in the corner for the next segment
var delegate_all := false            # the whole dual (the pure manager fantasy)
var auto: Dictionary = {}            # the profile's memory (hashed with everything else)
var auto_stats: Dictionary = {}      # what the profile did this segment (punches, feints, dodges, blocks, jabs at tells) - presentation and gates

# PAC-061: dual formats (NP_01 s2 / s3.3 / s6 / s8)
var FMT: Dictionary = {}             # data/formats.v1.json
var fmt: Dictionary = {}             # this dual's format record
var dressed: Array = []              # every card you brought, in order (slots are drawn from it)
var bdressed: Array = []             # every boss he brought
var condition: Dictionary = {}       # name -> {stamina, guard, comp} at the end of the segment he left (s6: condition carries)
var bcondition: Dictionary = {}
var seg_wins_p := 0                  # EP majority per segment (s3.2), the ladder's second rung
var seg_wins_b := 0
var counters_p := 0                  # counter hits across the dual, the ladder's third rung
var counters_b := 0
var r6 := false                      # the Golden DROP: no clock, first DROP wins

# PAC-060: the enemy coach (NP_10 s9) and the enemy's half of the economy (NP_05 s2 "both teams earn")
var COACHES: Dictionary = {}         # data/coaches.v1.json
var coach: Dictionary = {}           # this dual's rival corner
var coach_on := true                 # tests: false = the rival corner passes (quiet())
var blineup: Array = []              # the enemy's sealed slots (boss names), R1 fixed, the rest by the coach's archetype
var breserves: Array = []
var btension := 0.0                  # the enemy bar (NP_05 s1: one meter per team, both on the score bug)
var bcontributed := 0.0
var bcharged := false
var brelay_chain := 0
var btactic_fx: Dictionary = {}      # the rival corner's effects live this segment
var bpending_fx: Dictionary = {}
var btactic_cd: Dictionary = {}
var bsuper_used := false
var bswaps_used := 0
var bno_drop_t := 0                  # the enemy's Iron Resolve
var enemy_lock := 0                  # Hostile Crowd from your corner: rival corners locked
var player_lock := 0                 # Hostile Crowd from theirs: your corners locked
var bflash_conceded := false         # the segment just ended, for the coach's triggers
var bdrop_conceded := false
var coach_log: Array = []            # what the rival corner did this dual (presentation + Scout Book)

# PAC-059: the affinity rings (NP_06)
var AFF: Dictionary = {}             # data/affinity.v1.json
var FEUDS: Array = []                # data/feud_graph.v1.json edges
var aff: Dictionary = {}             # this segment's matchup: style_adv / element_adv / feud / line
var ep_frac_b := 0.0                 # the boss's +10% EP fraction (s1.3), his side of ep_frac

# PAC-058: the corner phase (NP_10 s4) and the relay (NP_05 s6)
var TAC: Dictionary = {}             # data/tactics.v1.json
var reserves: Array = []             # dressed but not in a slot
var corner: Dictionary = {}          # {"t", "actions_left", "log"}
var card_t := 0                      # the 4s segment-end card
var tactic_fx: Dictionary = {}       # effects live this segment
var pending_fx: Dictionary = {}      # chosen in the corner, applied at the next segment
var tactic_cd: Dictionary = {}       # tactic id -> corner index it was last used in
var super_used := false
var staff_charges: Dictionary = {}
var swaps_used := 0
var save_bar := false                # spending locked this segment
var save_bar_next := false
var full_relay := false
var no_drop_t := 0
var punish_suppress_t := 0
var tell_highlight_t := 0
var stamina_cap := 100.0
var seg_score0 := [0, 0, 0, 0]       # score_p, score_b, ep_p, ep_b at segment start (who won the segment)
var clock_acc := 0.0
var ep_frac := 0.0

static func ms(v: float) -> int:
	return int(round(v * TICK_HZ / 1000.0))

static func load_json(p: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}

static func load_content(base: String = "res://") -> Dictionary:
	var pats := {}
	for b in BOSSES: pats[b] = load_json(base + "patterns/%s.json" % b)
	var lib := {}
	var raw := load_json(base + "hissatsu_library.v2.json")
	for m in raw.get("moves", []): lib[str(m["name"])] = m
	return {"tuning": load_json(base + "combat_tuning.v1.json"), "patterns": pats, "library": lib, "tactics": load_json(base + "tactics.v1.json"),
		"affinity": load_json(base + "affinity.v1.json"), "feuds": load_json(base + "feud_graph.v1.json").get("edges", []),
		"coaches": load_json(base + "coaches.v1.json"), "formats": load_json(base + "formats.v1.json"),
		"bouts": load_json(base + "bouts.v1.json"), "scraps": load_json(base + "scrap_objectives.v1.json"),
		"pattern_intel": load_json(base + "pattern_intel.v1.json"), "remixes": load_json(base + "remixes.v1.json"), "economy": load_json(base + "economy.v1.json"), "pieces": load_json(base + "pattern_pieces.v1.json"), "neutral": load_json(base + "neutral.v1.json"), "talk": load_json(base + "talk.v1.json"), "formation": load_json(base + "formation.v1.json"), "staff": load_json(base + "staff.v1.json"), "recruits": load_json(base + "recruits.v1.json"), "string_wall": load_json(base + "string_wall.v1.json"), "houses": load_houses(base), "gym_wall": load_json(base + "gym_wall.v1.json"), "transformations": load_json(base + "transformations.v1.json"), "hybrids": load_json(base + "hybrids.v1.json"), "facilities": load_json(base + "facilities.v1.json"), "growth": load_json(base + "growth.v1.json"), "techniques": load_json(base + "techniques.v1.json"), "academy": load_json(base + "academy.v1.json"), "gear": load_json(base + "gear.v1.json"), "audit": load_json(base + "audit.v1.json"), "faucets": load_json(base + "faucets.v1.json")}

static func load_houses(base: String = "res://") -> Dictionary:
	# the house table with the feud graph's mutation rules and provisional edges attached (the graph owns them; the sim reads them with the houses)
	var h := load_json(base + "houses.v1.json")
	if h.is_empty(): return h
	var fg := load_json(base + "feud_graph.v1.json")
	h["provisional_edges"] = fg.get("provisional", []); h["mutation_rules"] = str(fg.get("mutation_rules", ""))
	return h

func setup(tuning: Dictionary, pats: Dictionary, names: Array, lineup_p: Array, first_boss: int, seed_v: int, lib: Dictionary = {}, tac: Dictionary = {}, aff_d: Dictionary = {}, feuds: Array = [], coaches: Dictionary = {}, formats: Dictionary = {}, fmt_id: String = "", bouts_d: Dictionary = {}, scraps_d: Dictionary = {}, pi_d: Dictionary = {}, pi_ledger: Dictionary = {}, remix_d: Dictionary = {}, eco_d: Dictionary = {}, reward_ledger: Dictionary = {}, remix_ledger: Dictionary = {}, pieces_d: Dictionary = {}, neutral_d: Dictionary = {}, talk_d: Dictionary = {}, formation_d: Dictionary = {}, staff_d: Dictionary = {}, recruits_d: Dictionary = {}, strings_d: Dictionary = {}, houses_d: Dictionary = {}, gym_d: Dictionary = {}, trans_d: Dictionary = {}, hyb_d: Dictionary = {}, board_d: Dictionary = {}, fac_d: Dictionary = {}, grow_d: Dictionary = {}, tech_d: Dictionary = {}, acad_d: Dictionary = {}, gear_d: Dictionary = {}) -> void:
	FAC = fac_d; GROW = grow_d; TECH = tech_d; ACAD = acad_d; GEAR = gear_d
	T = tuning; patterns = pats; boss_names = names; library = lib; TAC = tac; AFF = aff_d; FEUDS = feuds; COACHES = coaches; FMT = formats; BOUTS = bouts_d; REMIX = remix_d; ECO = eco_d; PIECES = pieces_d; NEUTRAL = neutral_d; TALK = talk_d; FORMATION = formation_d; STAFF = staff_d; RECRUITS = recruits_d; STRINGS = strings_d; HOUSES = houses_d; GYMWALL = gym_d; TRANS = trans_d; HYB = hyb_d
	generics = {}; gpatterns = {}; generic_slots = {}; bgeneric = {}
	rewards = reward_ledger.duplicate(true) if reward_ledger.size() > 0 else {"xp": {}, "spirits": 0, "prestige": 0, "hbp": 0, "kizuna": {}, "kizuna_day": {}, "log": [], "day": 1, "staff": {}, "beaten": {}, "recruit": {}, "story": {}, "string_wall": {}, "houses": {}, "graph": {}}
	for rk in ["xp", "kizuna", "kizuna_day", "staff", "beaten", "recruit", "story", "string_wall", "houses", "graph"]:
		if not rewards.has(rk): rewards[rk] = {}
	for rk in ["spirits", "prestige", "hbp"]:
		if not rewards.has(rk): rewards[rk] = 0
	if not rewards.has("log"): rewards["log"] = []
	if not rewards.has("day"): rewards["day"] = 1
	last_toast = {}
	remix_for = remix_ledger.duplicate(true)                                                          # PAC-069: a save's rematch flags apply from the bell
	SCRAPS = {}
	for o in scraps_d.get("objectives", []): SCRAPS[str(o["id"])] = o
	PI = pi_d
	pi = pi_ledger.duplicate(true) if pi_ledger.size() > 0 else {"dialects": {}, "bosses": {}}
	if not pi.has("dialects"): pi["dialects"] = {}
	if not pi.has("bosses"): pi["bosses"] = {}
	_book_init()                                                                                         # PAC-089: a ledger from before the shelf - its pages shelved, as many as the Film Room holds
	pi_log = []
	bout = {}; obj = {}; lab = []
	var fid := fmt_id if fmt_id != "" else str(FMT.get("default", "mini"))
	fmt = FMT.get("formats", {}).get(fid, {"label": "Mini-dual", "segments": 3, "dressed": 4, "enemy_dressed": 4, "repeat_slots": false, "condition_carries": true, "sudden_death": true, "blind": false, "segment_s": 90}).duplicate(true)
	fmt["id"] = fid
	dressed = []
	for f in lineup_p: dressed.append(f.duplicate(true))
	stable = dressed.duplicate(true)                                                                     # NP_08 s1: the club's cards - the dressed to begin with (a load adds the rest, a recruit joins)
	rng.seed = seed_v
	boss_names = names
	board = {}; seal_n = 0
	var refused := {}
	if board_d.size() > 0:                                                                                # NP_01 s7: the board the sim takes at setup, sealed at the bell
		var bc := _board_check(board_d)
		if bool(bc["ok"]): _apply_board(bc["board"])
		else: refused = bc
	_gw_init()                                                                                           # PAC-079: the Gym Wall - the letter, the club's cards beside it
	var synced := _world_sync()                                                                          # PAC-076/077: a ledger's flags flip the graph, bless houses and put strings up before the bell
	_tapes_sync()                                                                                        # PAC-091: a quest's fight tape, with its flag
	_gear_sync()                                                                                         # PAC-094: a circuit prize with its flag, a blessed house's gift, a signature with its owner
	_reset_dual(first_boss)                                                                              # (PAC-078: before the first segment loads - Debt of Honour reads the graph as it stands)
	if board.size() > 0: _board_sealed_ev()
	elif refused.size() > 0: _ev("board_refused", {"why": str(refused["why"])}); _say("BOARD REFUSED - %s (the card order stands)" % str(refused["why"]))
	if synced > 0: _recruit_check()

func segments() -> int: return int(fmt.get("segments", 3))

func _build_lineup() -> void:
	# NP_01 s2 / s8: the slots are drawn from the cards you dressed - reserves flagged as such sit out,
	# starters fill R1.. in order; a roster shorter than the slots repeats (Iron dual, Gauntlet).
	# A sealed board (PAC-073) is the order instead, in a dual (a scrap or a spar still sends the first card)
	lineup = []; reserves = []
	if bout.size() > 0 and str(bout.get("fighter", "")) != "" and _club_card(str(bout["fighter"])).size() > 0:   # PAC-090: his trial - he goes out, whatever the card order
		lineup.append(_club_card(str(bout["fighter"])))
		return
	if bool(fmt.get("simultaneous", false)) and bout.is_empty():                                         # PAC-088: NP_01 s8's Exhibition 2v2 - the pair in the ring together: both
		for f in dressed: lineup.append(f)                                                               # on the card, this engagement's fighter first, his partner beside him (the adjacency the bonds read)
		return
	if bout.is_empty() and _board_fits():
		for nm in board["slots"]: lineup.append(_card_of(str(nm)))
		var k: int = lineup.size()
		if bool(fmt.get("repeat_slots", false)):
			for i in range(k, segments()): lineup.append(lineup[i % k])
		for nm in board["reserves"]: reserves.append(_card_of(str(nm)))
		return
	var starters: Array = []
	for f in dressed:
		if f.get("reserve", false): reserves.append(f)
		else: starters.append(f)
	if starters.is_empty(): starters = reserves.duplicate(); reserves = []
	for i in segments():
		if i < starters.size(): lineup.append(starters[i])
		elif bool(fmt.get("repeat_slots", false)): lineup.append(starters[i % starters.size()])
		else: break
	for i in range(segments(), starters.size()): reserves.append(starters[i])   # more starters than slots: the rest are reserves

func _reset_dual(first_boss: int) -> void:
	dual_rng0 = rng.state; dual_t0 = tick                                                              # PAC-073: where this dual was set up from (a board sealed before the bell replays it)
	seg_idx = 0; drops_p = 0; drops_b = 0; score_p = 0; score_b = 0; ep_p = 0; ep_b = 0
	tension = 0.0; charged = false; mode = "FIGHT"; relay_chain = 0; wall_migrate = 0; crowd_spent_dual = 0.0; trait_uses = {}; transformed = {}; btransformed = {}
	full_relay = false; super_used = false; swaps_used = 0; tactic_cd = {}; pending_fx = {}; save_bar_next = false
	staff_charges = {}                                                                                   # per active: its charges for every dressed staffer who carries it (PAC-074)
	for st in TAC.get("staff_active", []): staff_charges[str(st["id"])] = int(st["charges"]) * maxi(1, _dressed_with_active(str(st["id"])).size())
	crowd_heat = 0.0
	_host_crowd()                                                                                        # PAC-089: a hosted dual's crowd from the bell (Front of House)
	corner = {}; card_t = 0
	btension = 0.0; bcontributed = 0.0; bcharged = false; brelay_chain = 0
	btactic_fx = {}; bpending_fx = {}; btactic_cd = {}; bsuper_used = false; bswaps_used = 0
	enemy_lock = 0; player_lock = 0; bflash_conceded = false; bdrop_conceded = false; coach_log = []
	condition = {}; bcondition = {}; seg_wins_p = 0; seg_wins_b = 0; counters_p = 0; counters_b = 0; r6 = false
	delegate_next = false; dual_xp = 0
	_first_boss = first_boss
	_build_lineup()
	if bout.is_empty():                                                                                  # NP_05 s1: a staff passive that starts you at 10 (the Hype at Lv3)
		var tsp := staff_passives()
		if float(tsp.get("tension_start", 0.0)) > 0.0:
			tension = float(tsp["tension_start"])
			_ev("staff_passive", {"what": "tension_start", "v": tension, "by": tsp["by"].get("tension_start", [])})
	_pick_coach(); _build_enemy_lineup()
	if bout.size() > 0: coach = {}                                     # no corners in a scrap or a spar (NP_02 s2)
	# NP_01 s7: both orders sealed at the bell; his corner may run a decoy seal (NP_10 s3), decided by a roll that never touches the fight's RNG
	sealed_p = []
	for f in lineup: sealed_p.append(str(f["name"]))
	sealed_b = blineup.duplicate() if bout.is_empty() else []
	bdecoy = bout.is_empty() and not bool(fmt.get("blind", false)) and bool(coach.get("decoys", false)) and _roll("decoy", 0) < 100.0 * float(coach.get("decoy_rate", 0.0))
	bprojection = _projection_live() if bout.is_empty() and coach.size() > 0 else {}
	if bout.is_empty() and coach.size() > 0:
		var pr := bprojection
		var sl: Array = []
		for i in sealed_p.size(): sl.append("R%d %s" % [i + 1, sealed_p[i]])
		_ev("sealed", {"slots": sealed_p.duplicate(), "reserves": reserves.map(func(f): return str(f["name"])), "archetype": str(board.get("archetype", "")), "board": str(board.get("name", "")), "pct": int(pr.get("pct", 0)), "blind": bool(pr.get("blind", false))})
		_say("ORDERS SEALED - yours %s; theirs %s" % [", ".join(PackedStringArray(sl)), "unknown (blind dual)" if bool(pr.get("blind", false)) else "projected at %d%%" % int(pr.get("pct", 0))])
	obj = {}; lab = []
	if bout.size() > 0:
		lab = bout.get("flags", []).duplicate()
		var oid := str(bout.get("objective", ""))
		if str(bout["kind"]) == "scrap":
			obj = TNBObjectives.fresh(oid, BOUTS["objective_forms"][oid], str(SCRAPS[oid]["prompt"]), str(bout.get("param", "")))
		elif oid == "SEGMENT_END":
			obj = TNBObjectives.fresh(oid, {"kind": "segment_end"}, "reach segment end", "")
	if bout.is_empty(): _entrance()                                                                      # PAC-089: the club walks out (Front of House's entrance)
	_load_segment()

var _first_boss := 0

func _fresh(stats: Dictionary, pos: Vector2) -> Dictionary:
	var g: Dictionary = T["guard"]["capacity_by_BLK"]
	var gmax: float = lerpf(float(g["min"]), float(g["max"]), float(stats["BLK"]) / 99.0)
	return {"stats": stats, "pos": pos, "stamina": 100.0,
		"comp_max": float(stats["CHN"]) * 2.0, "comp": float(stats["CHN"]) * 2.0,
		"guard_max": gmax, "guard": gmax, "guard_open_t": 0, "busy_t": 0, "no_regen_t": 0,
		"drops": 0, "dodge": "", "dodge_t": 0, "dodge_dir": 1, "dodge_at": 0, "dodge_plan": [],
		"blocking": false, "block_t": 0, "guard_t": 0, "counter_state_t": 0,
		"pb_streak": 0, "counter_t": 0, "flash_t": 0, "cmd": {}, "pending": {}, "charge_t": 0}

func _load_segment() -> void:
	var f: Dictionary = lineup[seg_idx]
	staff_fx = staff_passives()                                                                          # PAC-074: the dressed staff's passives for this segment
	P = _fresh(grown_stats(f), Vector2(0, 1.0))                                                        # PAC-090: the card's stats with his raises and board nodes (capped by his rarity)
	_dress(P, str(f.get("style", "BOXERPUNCHER")), str(f.get("element", "NONE")), str(f.get("house", "none")))
	for error in BoxingTechniques.equip(P,f): _ev("boxing_training_error",{"who":"P","reason":error})
	var pas := passives_of(str(f.get("name", "")))                                                       # PAC-090: the passives his board (and the socket) carries
	if pas.size() > 0: P["passives"] = pas
	var kitp := kit_moves(str(f.get("name", "")))                                                       # PAC-091: the kit he walks out with (NP_11 s2, s8)
	var gw := gear_worn(str(f.get("name", "")))                                                          # PAC-094: the gear he walks out in (NP_11 s5), its kinds' small passives
	if gw.size() > 0: P["gear"] = gw; P["gear_fx"] = gear_fx(str(f.get("name", "")))
	if kitp.size() > 0: P["kit"] = kitp
	P["house_status"] = house_status(str(f.get("name", "")))                                            # PAC-077: NATIVE / UNSANCTIONED, read at every segment (a blessing between duals sanctions him)
	boss_name = blineup[seg_idx] if seg_idx < blineup.size() else boss_names[(_first_boss + seg_idx) % boss_names.size()]
	pattern = _pat(boss_name).duplicate(true)
	bgeneric = generics.get(boss_name, {}).duplicate(true)
	if bout.size() > 0 and bool(bout.get("card", {}).get("generic", false)):                              # NP_04 s9: an NPC card fights on strings assembled for it, not a named boss's
		bgeneric = spec_from_card(bout["card"]); pattern = TNBAssembler.assemble(PIECES, bgeneric)
	bremix = {}; bmods = _fresh_mods(); binterrupts = {}; bfeint = ""; bhold_t = 0; bdesync_widen = false; bdesync_ms = -1.0
	directives_done = []; directives_carried = []
	btempo_i = 0; bstrings_done = 0; bcooldown_until = {}; breads = {}; bdialogue = ""; btrue_pattern = false
	bselect_lines = []; btransient = []; bcalled_phases = []; blanded = {}
	_declare_bases()                                                                                    # the META's base values the phase lines move (metronome, tempos, splice)
	if str(remix_for.get(boss_name, "")) != "" and bgeneric.is_empty(): _apply_remix(str(remix_for[boss_name]))   # NP_04 s6: the rematch remix as a layer over the original (never over a generic)
	bidle = _neutral_profile(pattern); bneutral_t = 0; btaunts = 0; btaunt_t = 0; btempo_fast = false; bfootwork_audio = true      # NP_04 s2: his IDLE lines, his neutral game
	B = _fresh(bgeneric.get("stats", {}).duplicate(true) if bgeneric.get("stats", {}).size() > 0 else {"PWR": 60, "SPD": 55, "CHN": 60, "RFX": 55, "BLK": 55, "STA": 60, "HRT": 60}, Vector2(0, -1.0))
	var bm: Dictionary = pattern.get("meta", {})
	_dress(B, str(bm.get("style", "BOXERPUNCHER")), str(bm.get("element", "NONE")), str(bm.get("house", "none")))
	if bm.has("kit"): _apply_meta_kit(str(bm["kit"]))                                                  # Vey's phase-1 kit (NP_04A s8: "Out-Boxer kit, Frost")
	boss_label = str(bgeneric.get("label", boss_name)) if bgeneric.size() > 0 else boss_name
	if bgeneric.size() > 0 and bout.is_empty(): _ev("generic", {"name": boss_name, "label": boss_label, "style": bm.get("style", ""), "dialect": bm.get("dialect", ""), "tier": int(bm.get("tier", 1)), "strings": pattern["strings"].keys(), "pieces": bm.get("pieces", [])}); _say(TNBAssembler.describe(pattern))
	if bout.size() > 0 and bout.get("card", {}).size() > 0:              # an NPC's card on a stand-in pattern's strings
		var oc: Dictionary = bout["card"]
		B = _fresh(oc.get("stats", {"PWR": 60, "SPD": 55, "CHN": 60, "RFX": 55, "BLK": 55, "STA": 60, "HRT": 60}), Vector2(0, -1.0))
		_dress(B, str(oc.get("style", bm.get("style", "BOXERPUNCHER"))), str(oc.get("element", bm.get("element", "NONE"))), str(oc.get("house", bm.get("house", "none"))))
		boss_label = str(oc.get("name", boss_name))
		if bgeneric.size() > 0: _ev("generic", {"name": boss_label, "label": boss_label, "style": bm.get("style", ""), "dialect": bm.get("dialect", ""), "tier": int(bm.get("tier", 1)), "strings": pattern["strings"].keys(), "pieces": bm.get("pieces", [])}); _say(TNBAssembler.describe(pattern))
	var boxing_card: Dictionary = bout.get("card",{}) if not bout.get("card",{}).is_empty() else bm.merged({"name":boss_name})
	for error in BoxingTechniques.equip(B,boxing_card): _ev("boxing_training_error",{"who":"B","reason":error})
	bdialect = dialect_of(boss_name, bout.get("card", {}) if bout.size() > 0 else {})
	var akit: Array = academy_kit(boss_name) if academy_on and bgeneric.is_empty() and bout.is_empty() and not ACAD.is_empty() else []   # PAC-102: a rival at the academy, the displaced prodigy's kit
	if (bgeneric.has("synth") or akit.size() > 0) and bout.is_empty() and not ACAD.is_empty():            # PAC-092: an academy prodigy carries his syntheses
		var syl: Array = []
		for sp in (akit if akit.size() > 0 else bgeneric["synth"]): syl.append(synthesize(str(sp[0]), str(sp[1])))
		B["synth"] = syl; B["synth_i"] = 0
		_ev("academy", {"who": boss_label, "syntheses": syl.map(func(m): return str(m["name"])), "families": syl.map(func(m): return str(m["family"])), "dmg": syl.map(func(m): return _synth_power(m))})
	P["trait"] = trait_of_house(str(f.get("house", "none")), bool(f.get("disowned", false)))            # PAC-078: NP_07 s3 - his house's trait, if NP_07 s5 lets him carry it
	var bh_raw := str(bout["card"].get("house", bm.get("house", "none"))) if bout.size() > 0 and bout.get("card", {}).size() > 0 else str(bm.get("house", "none"))
	B["trait"] = trait_of_house(bh_raw, bool(bm.get("disowned", false)))
	var pmx := _trait_stat_mult(P, str(B["house"])); var bmx := _trait_stat_mult(B, str(P["house"]))
	if pmx != 1.0: _restat(P, pmx)                                                                     # Long Winter in R4/R5, Debt of Honour against a feud
	if bmx != 1.0: _restat(B, bmx)
	if P["trait"].size() > 0 or B["trait"].size() > 0:
		_ev("traits", {"p": P["trait"], "b": B["trait"], "p_stats_mult": pmx, "b_stats_mult": bmx})
		_say("TRAITS :: %s" % " | ".join(PackedStringArray([P, B].filter(func(F): return F["trait"].size() > 0).map(func(F): return "%s %s%s" % [pname() if F == P else boss_name, str(F["trait"]["name"]), " (doubled)" if int(F["trait"]["x"]) > 1 else ""]))))
	bstate = "IDLE"; btimer = ms(600); bqueue = []; bphase = 1; bdesp_used = false; bpending = {}; B["pending"] = {}
	contributed = 0.0
	tokens = []; flags = {}; htokens = []
	center_hold_t = 0; block_hold_t = 0; punch_ticks = []; punch_rows = []
	last_zone_p = "MID"; punish_cd = {}; gassed_fired = false; taunt_t = 0
	pinned_p_t = 0; pinned_b_t = 0; trapped_p = false; trapped_b = false
	freeze_t = 0; boss_acc = 0.0; eight = {}
	bforce_opts = {}; swap_restore = {}; clinch_t = 0; wall_broken = false; rope_time_t = 0
	passive_t = 0; clean_t = 0; head_streak = 0; tier_fired = 0
	if bout.size() > 0 and str(bout.get("card", {}).get("mirror_of", "")) != "": _mirror_bell()            # PAC-093: his tracker opens reading your habits; he counters as you do
	clinch = {}; clinch_ticks = []; sprint_cd = 0; backstep_ticks = []; retreat_d = 0.0
	neutral_t = 0; neutral_cd = 0; cadence = []; hands_down_t = 0
	tell_start_tick = -1; tell_reacted = false; react_ticks = []; bwarnings = 0; pwarnings = 0; pholding = 0
	bsurvival_used = false; block_prev = false
	cast = {}; states = {"P": {}, "B": {}}; buffs = {"P": {}, "B": {}}; wall = {"P": {}, "B": {}}
	hiss_casts_seg = 0; dmg_hist = {"P": [], "B": []}; gauge_jabs = 0; commentary_mute_t = 0; lb_block_t = 0
	tform = {}; comedown = {}                                                                            # PAC-082: a transformation and its Comedown end with the segment
	btsurge = {}; btform = {}; bcomedown = {}; mclash = {}                                              # PAC-086: his too, and a Clash
	seg_cast_houses = []
	feint_log = []; feint_wise = {}
	t3_unlocked = charged
	_load_wall_gauge()
	sensors = _parse_sensors(pattern)
	seg_score0 = [score_p, score_b, ep_p, ep_b]; clock_acc = 0.0; ep_frac = 0.0; ep_frac_b = 0.0
	clock_t = (1 << 30) if r6 else ms(float(fmt.get("segment_s", 90)) * 1000.0)
	seg_tick0 = tick
	bout_cap_t = clock_t
	if bout.size() > 0:
		tension = 0.0; contributed = 0.0
		_ev("bout_start", {"kind": bout["kind"], "label": bout["label"], "objective": str(bout.get("objective", "")), "prompt": TNBObjectives.describe(obj), "flags": lab, "opponent": boss_label})
		_say("%s vs %s%s :: %s" % [str(bout["label"]), boss_label, "  [" + ", ".join(PackedStringArray(lab)) + "]" if lab.size() > 0 else "", TNBObjectives.describe(obj) if obj.size() > 0 else "full segment, drops and EP"])
	# s6: a fighter who re-enters carries the condition he left with (R6, repeat slots); the corner's restores land on top
	if bool(fmt.get("condition_carries", true)):
		if condition.has(str(f["name"])):
			var cp: Dictionary = condition[str(f["name"])]
			P["stamina"] = minf(100.0, float(cp["stamina"])); P["guard"] = minf(P["guard_max"], float(cp["guard"])); P["comp"] = minf(P["comp_max"], float(cp["comp"]))
			_ev("carried", {"who": "P", "name": str(f["name"]), "stamina": P["stamina"], "guard": P["guard"], "comp": P["comp"]})
			if bout.is_empty() and (float(staff_fx.get("corner_stamina_plus", 0.0)) > 0.0 or float(staff_fx.get("corner_composure_plus", 0.0)) > 0.0):   # NP_10 s6: the cutman works the fighter on the stool
				var cs0: float = P["stamina"]; var cc0: float = P["comp"]
				P["stamina"] = minf(100.0, P["stamina"] + float(staff_fx.get("corner_stamina_plus", 0.0))); P["comp"] = minf(P["comp_max"], P["comp"] + float(staff_fx.get("corner_composure_plus", 0.0)))
				_ev("staff_passive", {"what": "corner_restore", "name": str(f["name"]), "stamina": P["stamina"] - cs0, "comp": P["comp"] - cc0, "by": staff_fx["by"].get("corner_stamina_plus", [])})
		if bcondition.has(boss_name):
			var cb: Dictionary = bcondition[boss_name]
			B["stamina"] = minf(100.0, float(cb["stamina"])); B["guard"] = minf(B["guard_max"], float(cb["guard"])); B["comp"] = minf(B["comp_max"], float(cb["comp"]))
			_ev("carried", {"who": "B", "name": boss_name, "stamina": B["stamina"], "guard": B["guard"], "comp": B["comp"]})
	# the corner's choices land here (NP_10 s4-s6)
	tactic_fx = pending_fx; pending_fx = {}
	save_bar = save_bar_next; save_bar_next = false
	stamina_cap = float(tactic_fx.get("stamina_cap", 100.0))
	P["stamina"] = minf(stamina_cap, P["stamina"]) if condition.has(str(f["name"])) and bool(fmt.get("condition_carries", true)) else stamina_cap
	if tactic_fx.has("overrun"): P["stamina"] = minf(P["stamina"], stamina_cap * maxf(float(TAC.get("corner", {}).get("overrun_stamina_pct", 80)), float(staff_fx.get("overrun_stamina_pct", 0.0))) / 100.0)   # the conditioning coach at Lv3: 90
	if tactic_fx.has("stamina_plus"): P["stamina"] = minf(stamina_cap, P["stamina"] + float(tactic_fx["stamina_plus"]))
	if tactic_fx.has("composure_plus"): P["comp"] = minf(P["comp_max"], P["comp"] + float(tactic_fx["composure_plus"]))
	if tactic_fx.has("guard_cap_mult"): P["guard_max"] = P["guard_max"] * float(tactic_fx["guard_cap_mult"]); P["guard"] = P["guard_max"]
	no_drop_t = ms(float(tactic_fx.get("no_drop_s", 0)) * 1000.0)
	punish_suppress_t = ms(float(tactic_fx.get("punish_suppress_s", 0)) * 1000.0)
	tell_highlight_t = ms(float(tactic_fx.get("tell_highlight_s", 0)) * 1000.0)
	if tactic_fx.size() > 0: _ev("tactics_live", {"fx": tactic_fx.keys()})
	# the rival corner's choices land on the boss the same way (NP_10 s9)
	btactic_fx = bpending_fx; bpending_fx = {}
	bflash_conceded = false; bdrop_conceded = false
	if btactic_fx.has("stamina_cap"): B["stamina"] = float(btactic_fx["stamina_cap"])
	if btactic_fx.has("stamina_plus"): B["stamina"] = minf(float(btactic_fx.get("stamina_cap", 100.0)), B["stamina"] + float(btactic_fx["stamina_plus"]))
	if btactic_fx.has("composure_plus"): B["comp"] = minf(B["comp_max"], B["comp"] + float(btactic_fx["composure_plus"]))
	if btactic_fx.has("guard_cap_mult"): B["guard_max"] = B["guard_max"] * float(btactic_fx["guard_cap_mult"]); B["guard"] = B["guard_max"]
	bno_drop_t = ms(float(btactic_fx.get("no_drop_s", 0)) * 1000.0)
	if btactic_fx.has("enemy_corner_lock"): player_lock += 1
	if btactic_fx.size() > 0: _ev("tactics_live_b", {"fx": btactic_fx.keys()})
	if bcharged:
		B["charge_t"] = ms(float(TAC.get("corner", {}).get("charged_surge_s", 10)) * 1000.0); bcharged = false
		_say("%s enters CHARGED - their relay chain %d" % [boss_name, brelay_chain])
	if bout.size() > 0 and "tell_highlight" in lab: tell_highlight_t = 1 << 30      # the lab flag outlives the corner's timers
	backstep_ev_t = -1000
	_matchup()
	if pi_vs() >= 1:                                                              # NP_02 s3: PI 1 is the commentator's call before the segment
		_ev("commentary", {"dialect": bdialect, "level": pi_vs(), "text": pi_habit(bdialect), "cue": pi_cue(), "page": pi_vs() >= 3})
		_say("COMMENTARY (PI %d vs %s): %s" % [pi_vs(), bdialect.capitalize(), pi_habit(bdialect)])
	delegated = delegate_all or delegate_next; delegate_next = false
	auto = TNBProfile.fresh_memory(); auto_stats = {"punches": 0, "feints": 0, "dodges": 0, "blocks": 0, "tell_jabs": 0, "casts": 0, "grabs": 0, "sprints": 0, "body": 0, "power": 0, "rows": {}, "dist_sum": 0.0, "dist_n": 0}
	if delegated: _ev("delegated", {"who": f["name"], "seg": seg_idx + 1}); _say("%s plays this one on their own - the corner is still yours (Tension at %d%%)" % [f["name"], int(TAC.get("corner", {}).get("delegated_tension_pct", 85))])
	seg_xp = 0
	_apply_kizuna_effects(f)
	if tactic_fx.has("talk"):                                                                            # NP_10 s4: a right read lands on the fighter it was said to - nobody else
		var tk: Dictionary = tactic_fx["talk"]
		if str(tk.get("who", "")) == str(f.get("name", "")):
			var tst: Dictionary = P["stats"].duplicate()
			for tsk in tst: tst[tsk] = float(tst[tsk]) * (1.0 + float(tk.get("pct", 5.0)) / 100.0)
			P["stats"] = tst
			_ev("talk_effect", {"who": str(f["name"]), "stat_pct": float(tk.get("pct", 5.0))})
		else: _ev("talk_unheard", {"who": str(tk.get("who", "")), "out": str(f.get("name", ""))})
	if bool(bidle.get("bell", false)):                                                                   # Reyes: her corner's bell at the bell; with a Reyes in your stable, two (NP_04B s19)
		var hk := house_key(str(pattern.get("meta", {}).get("house", "none"))); var together := false
		for dc in dressed:
			if hk != "none" and house_key(str(dc.get("house", "none"))) == hk: together = true
		_ev("corner_bell", {"boss": boss_name, "together": together}); _say("%s rings her corner's bell%s" % [boss_name, " - and yours rings back: two bells" if together else ""])                                                                             # NP_08 s5.2: Corner Voices (+2% with a Lv2 bond dressed), Adjacent Trust (+5% beside a Lv3 bond)
	if charged:
		P["charge_t"] = ms(float(TAC.get("corner", {}).get("charged_surge_s", 10)) * 1000.0); charged = false
		_say("R%d: %s enters CHARGED - surge %ds, first hissatsu half cost, T3 unlocked!%s vs %s" % [seg_idx + 1, f["name"], int(TAC.get("corner", {}).get("charged_surge_s", 10)), "  FULL RELAY!" if full_relay else "", boss_name])
	else:
		_say("R%d: %s vs %s" % [seg_idx + 1, f["name"], boss_name])
	_duo_check()                                                                                        # PAC-080: a Duo pair's named T3, by the bond (priced after the CHARGED surge)
	_relay_check()                                                                                      # PAC-081: the T3s the CHARGED relay opens
	_hybrid_check()                                                                                     # PAC-087: the pair's hybrid - relayed between them, or CHARGED
	mode = "FIGHT"

func pname() -> String: return lineup[seg_idx]["name"]

# ============================ THE ENEMY COACH (NP_10 s9) ==================
func _pick_coach() -> void:
	var recs: Dictionary = COACHES.get("coaches", {})
	var id := str(COACHES.get("coach_of", {}).get(boss_names[_first_boss], COACHES.get("default", "journeyman")))
	if academy_on and not ACAD.is_empty() and bout.is_empty(): id = str(ACAD.get("coach", id))                   # PAC-092: the academy fielded - Director Vey's corner
	coach = recs.get(id, {}).duplicate(true)
	if coach.size() > 0: coach["id"] = id

func _pat(name: String) -> Dictionary:
	# a boss's pattern by name: an assembled generic's, else the compiled one
	return gpatterns[name] if gpatterns.has(name) else patterns.get(name, {})

func has_pattern(name: String) -> bool: return gpatterns.has(name) or patterns.has(name)

func boss_role(name: String) -> int:
	var slot := str(_pat(name).get("meta", {}).get("slot", "R3"))
	return int(slot.substr(1)) if slot.length() > 1 and slot.substr(1).is_valid_int() else 3

func _anchor_class(name: String) -> bool:
	var m: Dictionary = _pat(name).get("meta", {})
	return boss_role(name) >= 5 or m.has("wall_gauge") or m.has("migrant_wall")

func _build_enemy_lineup() -> void:
	# NP-12A's signed mini-dual: the authored opponents stay in their sealed slots.
	# The ledger scopes this to the episode; sandbox formats keep their roster rules.
	if rewards.get("episode", {}).get("fight", "") == "survival" and gpatterns.has("ascendant_r2"):
		blineup = ["ascendant_seed", "ascendant_r2", "cassidy_vane"]
		bdressed = blineup.duplicate(); breserves = []
		return
	# NP_01 s2/s7 + NP_10 s2: he dresses enemy_dressed fighters from the boss you asked for on; R1 stays that boss,
	# the coach's archetype orders the slots he controls. STANDARD: the two highest roles close (hammer, anchor),
	# the lowest open. AMBUSH: the ace opens the slots he controls. WALL_FIRST: anchor-class first, then STANDARD.
	# RELAY_LADDER reads as STANDARD (bond pairs are not a boss-side concept yet). A roster shorter than the
	# slots repeats (Iron dual).
	var n := boss_names.size()
	var count := maxi(1, int(fmt.get("enemy_dressed", 4)))
	bdressed = []
	for i in count: bdressed.append(boss_names[(_first_boss + i) % n])
	var rest: Array = bdressed.slice(1)
	var by_role := rest.duplicate()
	by_role.sort_custom(func(a, b): return boss_role(a) < boss_role(b) or (boss_role(a) == boss_role(b) and rest.find(a) < rest.find(b)))
	var arche := str(coach.get("archetype", "STANDARD"))
	var k := mini(segments() - 1, rest.size())              # slots the coach controls from his roster
	var ordered: Array = []
	match arche:
		"AMBUSH":
			if k > 0: ordered.append(by_role[by_role.size() - 1])
			for i in range(0, k - 1): ordered.append(by_role[i])
		"WALL_FIRST":
			var anchor := ""
			for nm in by_role:
				if _anchor_class(nm): anchor = nm
			if anchor == "" and by_role.size() > 0: anchor = by_role[by_role.size() - 1]
			var others: Array = by_role.filter(func(x): return x != anchor)
			if k > 0: ordered.append(anchor)
			ordered.append_array(_standard_order(others, k - 1))
		_: ordered = _standard_order(by_role, k)
	var bench: Array = rest.filter(func(x): return not (x in ordered))
	blineup = [boss_names[_first_boss]]; blineup.append_array(ordered)
	if blineup.size() < segments() and bool(fmt.get("repeat_slots", false)):
		var pool := blineup.duplicate()
		while blineup.size() < segments(): blineup.append(pool[blineup.size() % pool.size()])
	breserves = bench
	for gi in generic_slots:                                   # NP_04 s9: a filler slot is an assembled generic in the named boss's place
		var idx := int(gi); var gname := str(generic_slots[gi]["name"])
		if idx < 0 or idx >= blineup.size() or not gpatterns.has(gname): continue
		var was := str(blineup[idx]); blineup[idx] = gname
		var bi := bdressed.find(was)
		if bi >= 0 and not (was in blineup): bdressed[bi] = gname
		elif not (gname in bdressed): bdressed.append(gname)
	var tkn: Array = academy_fielded() if academy_on else []                                             # PAC-102: the anti-you - the rivals it signed, ahead of the prodigies
	for ti in mini(tkn.size(), blineup.size()): blineup[ti] = str(tkn[ti])
	if academy_on and not generic_slots.is_empty():                  # PAC-092: the academy dresses only its prodigies - no named bench for Vey's swaps
		breserves = []
		if tkn.is_empty(): bdressed = bdressed.filter(func(x): return gpatterns.has(str(x)))
		else:                                                                                            # the rivals it signed dressed with the prodigies
			bdressed = blineup.duplicate()
			for gx in generic_slots:
				var gn := str(generic_slots[gx]["name"])
				if gpatterns.has(gn) and not (gn in bdressed): bdressed.append(gn)

func _standard_order(by_role: Array, k: int) -> Array:
	# k slots from a role-sorted roster: the lowest roles open, the highest close (anchor last, hammer before it)
	if k <= 0 or by_role.is_empty(): return []
	k = mini(k, by_role.size())
	var closers := mini(2 if k >= 4 else 1, k)
	var out: Array = []
	for i in range(0, k - closers): out.append(by_role[i])
	for i in range(by_role.size() - closers, by_role.size()): out.append(by_role[i])
	return out

func _leading_b() -> bool:
	return score_b > score_p or (score_b == score_p and ep_b > ep_p)

func _coach_matchup(name: String, target: Dictionary) -> int:
	# the coach reads the rings (NP_06 s5) for a candidate against one of your cards
	var m: Dictionary = patterns.get(name, {}).get("meta", {})
	var st := style_key(str(m.get("style", ""))); var el := element_key(str(m.get("element", "")))
	var ts := style_key(str(target.get("style", "BOXERPUNCHER"))); var te := element_key(str(target.get("element", "NONE")))
	var w: Dictionary = COACHES.get("matchup_score", {"style_edge": 2, "element_edge": 1})
	var sc := 0
	if _beats("style", st, ts): sc += int(w.get("style_edge", 2))
	elif _beats("style", ts, st): sc -= int(w.get("style_edge", 2))
	if _beats("element", el, te): sc += int(w.get("element_edge", 1))
	elif _beats("element", te, el): sc -= int(w.get("element_edge", 1))
	return sc

func _coach_say(txt: String) -> void:
	coach_log.append(txt); _say("THEIR CORNER (%s): %s" % [str(coach.get("label", "?")), txt])

func _super_trigger_met(trig: String) -> bool:
	match trig:
		"when_trailing": return not _leading_b()
		"when_leading": return _leading_b()
		"corner_1": return seg_idx == 0
		"after_flash_drop_conceded": return bflash_conceded
		"after_drop_conceded": return bdrop_conceded
	return false

func _enemy_corner() -> void:
	# the rival corner, resolved when the corner opens (he acts on his scouting, not on your choices;
	# The Reveal shows his slot as it stands after this). Two actions, the same prices as yours,
	# taken in the order his record names (priority: super / swap / tactic).
	if not coach_on or coach.is_empty() or _up_slot() >= blineup.size(): return
	var actions: Array = []
	if enemy_lock > 0:
		enemy_lock -= 1
		_ev("coach_locked", {"coach": coach["id"]}); _coach_say("locked out by the crowd - no actions this corner")
		_ev("enemy_corner", {"coach": coach["id"], "actions": actions, "locked": true}); return
	var budget := int(TAC.get("corner", {}).get("actions", 2))
	for step_kind in coach.get("priority", ["super", "swap", "tactic"]):
		if actions.size() >= budget: break
		match str(step_kind):
			"super": _coach_super(actions)
			"swap": _coach_swap(actions)
			"tactic": _coach_tactic(actions)
	if actions.is_empty(): _coach_say("stands pat")
	_ev("enemy_corner", {"coach": coach["id"], "actions": actions, "locked": false})

func _coach_super(actions: Array) -> void:
	# once per dual, on its trigger
	var tell := str(coach.get("tell", "none"))
	if bsuper_used or not _super_trigger_met(str(coach.get("super_trigger", "never"))): return
	var sid := str(coach.get("super", ""))
	for su in TAC.get("super", []):
		if str(su["id"]) == sid:
			bsuper_used = true
			for k in su["effect"]: bpending_fx[k] = su["effect"][k]
			actions.append("super:" + sid)
			_ev("coach_action", {"action": "super", "id": sid, "cost": 0})
			_coach_say("burns %s - %s" % [str(su["name"]).to_upper(), str(su["text"])])
			if tell == "burns_super_after_flash_drop" or tell == "hostile_crowd_first_corner": _ev("coach_tell", {"coach": coach["id"], "tell": tell})

func _coach_swap(actions: Array) -> void:
	if rewards.get("episode", {}).get("fight", "") == "survival": return
	# the reserve or a not-yet-fought slot into the upcoming one, judged on the rings against your next card
	var tell := str(coach.get("tell", "none"))
	var up := _up_slot()
	var open_roster := r6 or bool(fmt.get("repeat_slots", false))         # anyone dressed can take the slot
	var candidates: Array = []
	if open_roster:
		for nm in bdressed:
			if nm != blineup[up]: candidates.append(nm)
	else:
		candidates = breserves.duplicate()
		for j in range(up + 1, blineup.size()): candidates.append(blineup[j])
	var considers := r6 or (tell != "never_swaps" and not (tell == "never_swaps_when_leading" and _leading_b()) and rng.randf() < float(coach.get("swap_aggr", 0.0)))
	var target: Dictionary = lineup[up]
	if not r6 and rng.randf() >= float(coach.get("scout", 0.5)):            # a bad read: he plans for another of your cards
		var others: Array = reserves.duplicate()
		for j in range(up + 1, lineup.size()): others.append(lineup[j])
		if others.size() > 0: target = others[rng.randi() % others.size()]
	var score_of := func(nm: String) -> float:
		# the Golden DROP is picked on condition first (s3.3: the gassed ace vs the fresh reserve), the rings second
		var v := float(_coach_matchup(nm, target))
		if r6 or open_roster:
			var frac := 1.0
			if bcondition.has(nm): frac = float(bcondition[nm]["comp"]) / 120.0
			v += frac * 4.0
		return v
	var cur_sc: float = score_of.call(blineup[up])
	var best := ""; var best_sc := cur_sc
	for c in candidates:
		var sc: float = score_of.call(c)
		if sc > best_sc: best = c; best_sc = sc
	var cost := 0 if (r6 or (bswaps_used == 0 and bool(TAC.get("corner", {}).get("swap_first_free", true)))) else int(TAC.get("corner", {}).get("swap_cost", 15))
	if best != "" and not considers and (tell == "never_swaps" or tell == "never_swaps_when_leading"):
		_ev("coach_tell", {"coach": coach["id"], "tell": tell})              # he had the better card and sat on it: the tell is readable
	if best == "" or not considers or btension < float(cost): return
	var was: String = blineup[up]
	var ri := breserves.find(best)
	if open_roster: pass                                     # the card takes the slot; the roster is open
	elif ri >= 0: breserves[ri] = was
	else:
		var j := blineup.find(best); blineup[j] = was
	blineup[up] = best
	btension -= float(cost)
	if not r6: bswaps_used += 1
	actions.append("swap:" + best)
	_ev("coach_action", {"action": "swap", "id": best, "cost": cost, "out": was})
	_coach_say("%s %s in for %s at %s%s" % ["sends" if r6 else "swaps", best, was, "the Golden DROP" if r6 else "R%d" % (up + 1), "" if cost == 0 else " (-%d Tension)" % cost])
	if tell == "counter_picks": _ev("coach_tell", {"coach": coach["id"], "tell": tell})

func _coach_tactic(actions: Array) -> void:
	# one from his library, at his prices, on his tell's schedule
	var tell := str(coach.get("tell", "none"))
	var up := _up_slot()
	var lib: Array = coach.get("library", []).duplicate()
	if tell == "ices_the_clock_when_leading" and _leading_b() and "ice_the_clock" in lib:
		lib.erase("ice_the_clock"); lib.push_front("ice_the_clock")
	if tell == "book_tactic_r3" and up != 2: return
	for tid in lib:
		var rec: Dictionary = {}
		for t in TAC.get("special", []):
			if str(t["id"]) == str(tid): rec = t
		if rec.is_empty() or int(btactic_cd.get(str(tid), -9)) == seg_idx or btension < float(rec["cost"]): continue
		btension -= float(rec["cost"]); btactic_cd[str(tid)] = seg_idx + 1
		for k in rec["effect"]: bpending_fx[k] = rec["effect"][k]
		actions.append("tactic:" + str(tid))
		_ev("coach_action", {"action": "tactic", "id": str(tid), "cost": int(rec["cost"])})
		_coach_say("calls %s (-%d Tension) - %s" % [str(rec["name"]).to_upper(), int(rec["cost"]), str(rec["text"])])
		if tell == "book_tactic_r3" or (tell == "ices_the_clock_when_leading" and str(tid) == "ice_the_clock"): _ev("coach_tell", {"coach": coach["id"], "tell": tell})
		return

func _earn_tension_b(v: float) -> void:
	# the enemy's half of NP_05 s2: same table, same feud, his own Perfect Round
	if aff.get("feud", false): v *= float(AFF.get("house", {}).get("feud_tension_mult", 1.25))
	v *= float(btactic_fx.get("tension_earn_mult", 1.0))
	btension = minf(100.0, btension + v); bcontributed += v

# ============================ AFFINITY RINGS (NP_06) ======================
static func style_key(v: String) -> String:
	var k := v.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	return k if k in ["SWARMER", "OUTBOXER", "SLUGGER", "BOXERPUNCHER"] else "BOXERPUNCHER"

static func element_key(v: String) -> String:
	var k := v.strip_edges().to_upper()
	return k if k in ["FROST", "GALE", "GRANITE", "TIMBER"] else "NONE"       # "varies" / "rotating" are authored specials: neutral here

static func house_key(v: String) -> String:
	# pattern META writes lineage qualifiers (okafor_root_line, reyes_origin_line...); the feud graph keys the bare house
	var k := v.strip_edges().to_lower()
	for suf in ["_root_line", "_origin_line", "_root_system", "_taken", "_extracted"]:
		if k.ends_with(suf): k = k.substr(0, k.length() - suf.length())
	return "none" if (k == "" or k == "unknown" or k == "null") else k

func _dress(F: Dictionary, style: String, element: String, house: String) -> void:
	# a fighter carries the three rings and the style's parameter package (s1.2)
	F["style"] = style_key(style); F["element"] = element_key(element); F["house"] = house_key(house)
	F["pkg"] = AFF.get("style", {}).get("packages", {}).get(F["style"], {}).duplicate()
	F["comp_max"] = float(F["comp_max"]) * float(F["pkg"].get("comp_pool_mult", 1.0)); F["comp"] = F["comp_max"]
	F["guard_max"] = float(F["guard_max"]) * float(F["pkg"].get("guard_cap_mult", 1.0)); F["guard"] = F["guard_max"]

func _beats(ring: String, a: String, b: String) -> bool:
	return a != "NONE" and str(AFF.get(ring, {}).get("beats", {}).get(a, "")) == b

func feud_active() -> bool:
	return _feud_between(str(P.get("house", "none")), str(B.get("house", "none")))

func _feud_between(hp: String, hb: String) -> bool:
	if hp == "none" or hb == "none": return false
	return edge_relation(_edge_between(hp, hb)) == "FEUD"                                              # PAC-077: the live graph (a questline's flip ends the feud's Tension)

func _edge_between(ha: String, hb: String) -> Dictionary:
	for e in live_edges():
		if (str(e["a"]) == ha and str(e["b"]) == hb) or (str(e["a"]) == hb and str(e["b"]) == ha): return e
	return {}

func edge_relation(e: Dictionary) -> String:
	# an edge's relation as it stands: the table's, unless a questline flipped it (the ledger's graph)
	if e.is_empty(): return ""
	var m: Dictionary = rewards.get("graph", {}).get(str(e.get("id", "")), {})
	return str(m["to"]) if m.has("to") else str(e.get("relation", ""))

func live_edges() -> Array:
	# the launch graph and the provisional edges a questline has added
	var out: Array = FEUDS.duplicate()
	for pe in HOUSES.get("provisional_edges", []):
		if rewards.get("graph", {}).get(str(pe["id"]), {}).has("added"): out.append(pe)
	return out

func _feud_edge() -> Dictionary:
	return _feud_edge_between(str(P["house"]), str(B["house"]))

func _feud_edge_between(hp: String, hb: String) -> Dictionary:
	var e := _edge_between(hp, hb)
	return e if edge_relation(e) == "FEUD" else {}

func rings(ps: String, pe: String, ph: String, bs: String, be: String, bh: String) -> Dictionary:
	# the matchup card's arithmetic (NP_06 s5) on six keys: the segment's card reads it off the two fighters, the formation's overlay (PAC-073)
	# off a card and a boss - one function, so the board shows exactly the card the segment will
	var st: Dictionary = AFF.get("style", {}); var el: Dictionary = AFF.get("element", {})
	var labels: Dictionary = st.get("labels", {})
	var style_adv := ""
	if _beats("style", ps, bs): style_adv = "P"
	elif _beats("style", bs, ps): style_adv = "B"
	var element_adv := ""
	if _beats("element", pe, be): element_adv = "P"
	elif _beats("element", be, pe): element_adv = "B"
	var feud := _feud_between(ph, bh)
	var parts: Array = []
	if style_adv == "P": parts.append("STYLE %s over %s: %s" % [labels.get(ps, ps), labels.get(bs, bs), st.get("why", {}).get("%s>%s" % [ps, bs], "")])
	elif style_adv == "B": parts.append("STYLE his %s over your %s: %s" % [labels.get(bs, bs), labels.get(ps, ps), st.get("why", {}).get("%s>%s" % [bs, ps], "")])
	elif ps == "BOXERPUNCHER" and bs == "BOXERPUNCHER": parts.append("STYLE the purist's matchup - no rings, pure sim")
	elif ps == bs: parts.append("STYLE mirror match")
	else: parts.append("STYLE neutral")
	if element_adv == "P": parts.append("ELEMENT %s over %s: %s" % [pe, be, el.get("why", {}).get("%s>%s" % [pe, be], "")])
	elif element_adv == "B": parts.append("ELEMENT his %s over your %s: %s - his walls stand +1s" % [be, pe, el.get("why", {}).get("%s>%s" % [be, pe], "")])
	elif pe != "NONE" and be != "NONE": parts.append("ELEMENT %s / %s neutral" % [pe, be])
	if feud:
		var e := _feud_edge_between(ph, bh)
		parts.append("FEUD House %s vs House %s (%s) - Tension +25%% both ways" % [ph.capitalize(), bh.capitalize(), str(e.get("origin", ""))])
	return {"style_adv": style_adv, "element_adv": element_adv, "feud": feud, "line": " | ".join(PackedStringArray(parts)), "p": [ps, pe, ph], "b": [bs, be, bh]}

func _matchup(swap: bool = false) -> void:
	# the matchup card (s5): every ring read once at segment start, the whole stack in one line (and again when a kit turns mid-segment)
	var labels: Dictionary = AFF.get("style", {}).get("labels", {})
	aff = rings(str(P["style"]), str(P["element"]), str(P["house"]), str(B["style"]), str(B["element"]), str(B["house"]))
	_ev("matchup", {"p_style": P["style"], "p_element": P["element"], "p_house": P["house"], "b_style": B["style"], "b_element": B["element"], "b_house": B["house"],
		"style_adv": aff["style_adv"], "element_adv": aff["element_adv"], "feud": aff["feud"], "line": aff["line"], "swap": swap})
	_say("MATCHUP %s (%s/%s) vs %s (%s/%s) :: %s" % [pname(), labels.get(P["style"], P["style"]), P["element"], boss_label, labels.get(B["style"], B["style"]), B["element"], aff["line"]])

func _style_adv(k: String) -> bool:
	# the triangle's truth, plus Switch-Up's lie for the player (NP_10 s5); the lie never removes his truth
	if str(aff.get("style_adv", "")) == k: return true
	if k == "B": return bool(btactic_fx.get("style_advantaged", false))
	return bool(tactic_fx.get("style_advantaged", false))

func hiss_mult(who: String) -> float:
	# s2.1 + s3 + s4: same-element spike x element edge x house-native, one cap on the product
	var A: Dictionary = P if who == "P" else B
	var D: Dictionary = B if who == "P" else P
	var mv: Dictionary = cast.get("move", {}) if cast.size() > 0 else (player_move() if who == "P" else {})
	var el: Dictionary = AFF.get("element", {}); var ho: Dictionary = AFF.get("house", {})
	var m := 1.0
	if mv.size() > 0 and element_key(str(mv.get("element", ""))) == A["element"] and A["element"] != "NONE": m *= float(el.get("same_element_spike", 1.3))
	if _beats("element", A["element"], D["element"]): m *= float(el.get("beats_hissatsu_mult", 1.1))
	if mv.size() > 0 and move_house(str(mv.get("name", ""))) != "" and move_house(str(mv.get("name", ""))) == A["house"] and A["house"] != "none" and str(A.get("house_status", "")) != "UNSANCTIONED": m *= float(ho.get("native_effect_mult", 1.1))   # NP_07 s5: UNSANCTIONED - no home bonus
	return minf(_cap_of(A), m)                                                                           # PAC-085: the Awakened fighter's cap x1.75

func _score_ep(k: String) -> void:
	# a clean blow is 2 EP (NP_01); the advantaged style earns +10% (s1.3) as a fraction that lands every fifth hit
	if k == "P":
		ep_p += 2
		if _style_adv("P"):
			ep_frac += 2.0 * (float(AFF.get("style", {}).get("advantage", {}).get("ep_mult", 1.1)) - 1.0)
			if ep_frac >= 1.0: ep_frac -= 1.0; ep_p += 1
	else:
		ep_b += 2
		if _style_adv("B"):
			ep_frac_b += 2.0 * (float(AFF.get("style", {}).get("advantage", {}).get("ep_mult", 1.1)) - 1.0)
			if ep_frac_b >= 1.0: ep_frac_b -= 1.0; ep_b += 1

func _window(kind: String, wide: float = 1.0) -> int:
	# every player counter window: base x trap width (x the slugger's slip tax) + the extras that stack on all windows
	var m := wide
	if kind == "slip": m *= float(P["pkg"].get("slip_window_mult", 1.0))
	var plus := (ms(100) if buffs["P"].has("counter_window_plus_100ms") else 0) + ms(float(tactic_fx.get("counter_window_plus_ms", 0)))
	if _style_adv("P"): plus += ms(float(AFF.get("style", {}).get("advantage", {}).get("counter_window_plus_ms", 50)))
	if _tx(P, "first_frost") > 0 and tick - seg_tick0 < ms(float(HOUSES["traits"]["first_frost"]["opening_s"]) * 1000.0):   # PAC-078: First Frost, the segment's opening 15 s
		plus += ms(float(HOUSES["traits"]["first_frost"]["counter_window_plus_ms"]) * _tx(P, "first_frost"))
	if tform.size() > 0: plus += ms(float(_zone_fx().get("counter_window_plus_ms", 0)))                  # PAC-082: In the Zone, every counter window +200 ms
	return int(ms(float(T["counter_windows_ms"][kind]["base"])) * m) + plus

func _power_class(row: String, power_mod: bool) -> bool:
	var fam := _punch_family(row)
	return power_mod or fam == "HOOKERCUT" or fam == "FLARED"

static func _parse_sensors(pat: Dictionary) -> Dictionary:
	# thresholds this boss's hooks ask for, e.g. player_passive>6s, player_holds_center_5s
	var out := {"passive_s": 6.0, "center_s": 4.0, "guard_s": 3.0, "perfect_play_s": 15.0}
	var rx := RegEx.new(); rx.compile("(passive>|holds_center_|high_guard_|static_guard_|block_hold>|perfect_play_)(\\d+)s")
	var hooks: Array = []
	hooks.append_array(pat.get("bait", [])); hooks.append_array(pat.get("punish", []))
	for h in hooks:
		var m := rx.search(str(h.get("trigger", "")))
		if m == null: continue
		var v := float(m.get_string(2))
		match m.get_string(1):
			"passive>": out["passive_s"] = v
			"holds_center_": out["center_s"] = v
			"high_guard_", "static_guard_", "block_hold>": out["guard_s"] = v
			"perfect_play_": out["perfect_play_s"] = v
	return out

func _say(t: String) -> void:
	if commentary_mute_t > 0:                               # Erased Name: commentary loses the names
		t = t.replace(str(pattern.get("id", "")), "———").replace(pname(), "———")
	feed = t
	events.append({"kind": "feed", "text": t})

func _ev(kind: String, data: Dictionary = {}) -> void:
	var d := data.duplicate()
	d["kind"] = kind; d["tick"] = tick
	events.append(d)
	if obj.size() > 0 and bout.size() > 0 and not obj["met"] and not obj["failed"]: TNBObjectives.on_event(self, obj, d)   # the scrap's judge hears every event as it happens
	if bout.is_empty() and mode != "OVER" and STAFF.size() > 0:                                           # NP_01 s1: the crowd - your own spectacle heats the building
		match kind:
			"hit":
				if str(d.get("on", "")) == "B" and not bool(d.get("foul", false)) and not bool(d.get("hissatsu", false)):
					if bool(d.get("flash", false)): _crowd("flash")
					elif bool(d.get("counter", false)): _crowd("counter")
			"drop": if str(d.get("who", "")) == "B": _crowd("drop")
			"interrupt": _crowd("interrupt")
			"eight_up": if d.get("who","P") == "P": _crowd("eight_up")
			"cast_resolve": if str(d.get("who", "")) == "P": _crowd("hissatsu")
	if ECO.size() > 0 and mode != "OVER":                                                                 # NP_11 s6: XP is continuous - the fight's own events earn it
		seg_xp += event_xp(kind, d)

func pay_segment(won: bool, ev_xp: int) -> int:
	# a dual segment's XP to the fighter in it: the fight's own events plus the segment won (PAC-097: the faucet audit pays through it)
	if ECO.is_empty(): return 0
	return _pay_xp(pname(), ev_xp + (int(ECO["xp"]["segment_won"]) if won else 0), "R%d" % (seg_idx + 1))

func event_xp(kind: String, d: Dictionary) -> int:
	# the XP one of the fight's events earns the player's fighter (PAC-097: one rule, read by the faucet audit too): a clean hit on
	# him, a counter, a flash (never a hissatsu or a foul); a drop he takes
	if ECO.is_empty(): return 0
	if kind == "hit" and str(d.get("on", "")) == "B" and not bool(d.get("hissatsu", false)) and not bool(d.get("foul", false)):
		return int(ECO["xp"]["per_flash"]) if bool(d.get("flash", false)) else (int(ECO["xp"]["per_counter"]) if bool(d.get("counter", false)) else int(ECO["xp"]["per_clean_hit"]))
	if kind == "drop" and str(d.get("who", "")) == "B": return int(ECO["xp"]["per_drop"])
	return 0

# ============================ GEOMETRY (C2) ================================
func _punch_family(row: String) -> String:
	for fam in GEO:
		if row.ends_with(fam): return fam
	return "STRAIGHT"

static func dodge_weight(F: Dictionary) -> float:
	if str(F.get("dodge", "")) == "": return 0.0
	var total := int(DODGE[F["dodge"]]["t"])
	var remaining := int(F["dodge_t"])
	# Enter and leave the authored dodge displacement over six fixed ticks.
	# Collision and visible head motion share this curve: no visual-only evasion.
	var enter := clampf(float(total - remaining + 1) / 6.0, 0, 1)
	var leave := clampf(float(remaining) / 6.0, 0, 1)
	return enter * enter * (3 - 2 * enter) * leave * leave * (3 - 2 * leave)

func _head_world(F: Dictionary, other: Dictionary, posed: bool = true) -> Dictionary:
	if posed and F.get("boxing",{}).has("rig"):
		var actual: Vector3 = F["boxing"]["rig"]["head"]
		return {"p":F["pos"]+Vector2(actual.x,actual.z)/RigSpace.GROUND_SCALE,"h":actual.y}
	# defender's head as a world point + height, displaced by its active dodge
	var fwd: Vector2 = BodyControl.forward(F, other)              # actor's current anatomical frame
	var rightD := Vector2(-fwd.y, fwd.x)                             # defender's right
	var lat := 0.0; var h := HEAD_H; var back := 0.0
	if F["dodge"] != "" and not F.has("body_control"):
		var d: Dictionary = DODGE[F["dodge"]]
		lat = float(d["lat"]) * float(F["dodge_dir"]); h = float(d["h"]); back = float(d["back"])
		if F["dodge"] == "WEAVE": lat *= float(F.get("pkg", {}).get("weave_arc_mult", 1.0))      # the out-boxer's narrower weave (s1.2)
		var weight := dodge_weight(F)
		lat *= weight; back *= weight; h = lerpf(HEAD_H, h, weight)
	var body_offset: Vector3 = BodyControl.offsets(F)["head"]
	# Native actors have one body envelope. Legacy replay actors retain their
	# recorded displacement, rather than adding that displacement a second time.
	lat = clampf(lat + body_offset.x, -0.55, 0.55)
	back = clampf(back - body_offset.z, -0.12, 0.55)
	h = maxf(0.82, h + body_offset.y)
	var head: Vector2 = F["pos"] - fwd * back + rightD * lat
	return {"p": head, "h": h}

func resolve_geometry(A: Dictionary, D: Dictionary, row: String, body: bool, range_bonus: float = 0.0) -> String:
	return str(contact_region(A, D, row, body, range_bonus)["result"])

func contact_region(A: Dictionary, D: Dictionary, row: String, body: bool, range_bonus: float = 0.0) -> Dictionary:
	# Legacy region rules and hypothetical defense queries retain their API.
	# Native launch aim and outcomes use the posed volumes in _boxing_begin.
	var fam := _punch_family(row)
	var g: Dictionary = GEO[fam]
	var fwd: Vector2 = (D["pos"] - A["pos"]).normalized()
	var rightA := Vector2(-fwd.y, fwd.x)
	var target := _head_world(D, A)
	var tp: Vector2 = target["p"]; var th: float = target["h"]
	if body:
		# Torso follows lateral head movement at 40%. Its aim height follows
		# crouch compression; body eligibility still has no vertical band.
		var fwdD: Vector2 = BodyControl.forward(D, A)
		var rightD := Vector2(-fwdD.y, fwdD.x)
		var lat := 0.0; var back := 0.0
		if D["dodge"] != "" and not D.has("body_control"):
			lat = float(DODGE[D["dodge"]]["lat"]) * float(D["dodge_dir"]) * 0.4 * (float(D.get("pkg", {}).get("weave_arc_mult", 1.0)) if D["dodge"] == "WEAVE" else 1.0)
			back = float(DODGE[D["dodge"]]["back"])
			lat *= dodge_weight(D); back *= dodge_weight(D)
		var body_offset: Vector3 = BodyControl.offsets(D)["torso"]
		lat = clampf(lat + body_offset.x, -0.22, 0.22)
		back = clampf(back - body_offset.z, -0.12, 0.55)
		tp = D["pos"] - fwdD * back + rightD * lat
		th = 1.10 + minf(0, th - HEAD_H)
	var rel: Vector2 = tp - A["pos"]
	var d := rel.dot(fwd)
	var l := rel.dot(rightA)
	if row.begins_with("L_"): l = -l                 # mirror for the left hand
	var reach := float(g["reach"]) * float(A.get("pkg", {}).get("reach_mult", 1.0))
	if fam == "STRAIGHT": reach *= float(A.get("pkg", {}).get("straight_reach_mult", 1.0))
	var result := "HIT"
	if d > reach + range_bonus: result = "MISS_REACH"
	elif l < float(g["lat"][0]) or l > float(g["lat"][1]): result = "MISS_LATERAL"
	elif not body and (th < float(g["h"][0]) or th > float(g["h"][1])): result = "MISS_HEIGHT"
	return {"result": result, "d": d, "l": l, "h": th, "reach": reach + range_bonus, "lat": g["lat"], "heights": g["h"], "forward": fwd, "right": rightA, "left": row.begins_with("L_"), "body": body, "target": tp}

func _correct_dodge_for(row: String, body: bool = false) -> Array:
	# a read chooses a geometrically valid evasion: [kind, dir] in defender's frame.
	# Body shots barely move with a slip and have no height band: the only
	# geometric answer is distance, so a read pulls back (works at range only).
	var fam := _punch_family(row)
	var right_hand := row.begins_with("R_")
	# A native read chooses inside/outside relative to the incoming hand.
	# The same seeded decision must mirror when that hand and stance mirror;
	# choosing an absolute left/right bit made southpaws move the wrong way.
	var read_side := (1 if right_hand else -1) if P.has("body_control") else 1
	if body: return ["LEAN", 1]
	match fam:
		"STRAIGHT", "FLARED": return ["SLIP", read_side*(1 if rng.randf() < 0.5 else -1)]
		"HOOK", "HOOKERCUT":
			# away = defender's right for an attacker's right hook (l negative)
			return ["SLIP", 1 if right_hand else -1] if rng.randf() < 0.5 else ["DUCK", 1]
		"UPPERCUT": return ["SLIP", read_side*(1 if rng.randf() < 0.5 else -1)] if rng.randf() < 0.6 else ["LEAN", 1]
	return ["SLIP", 1]

func _set_dodge(F: Dictionary, kind: String, dir: int) -> void:
	if F["dodge_t"] > 0: return
	F["dodge"] = kind; F["dodge_dir"] = dir; F["dodge_t"] = int(DODGE[kind]["t"])
	if kind == "LEAN" and not P.has("body_control"): F["stamina"] = maxf(_sfloor(F), F["stamina"] - 5.0)

func _boxing_body_axis(fighter: Dictionary, requested: Vector2) -> Vector2:
	# Direct body control takes precedence over a queued authored maneuver.
	if requested.length_squared() > 0.0001: return requested
	var kind := str(fighter.get("dodge",""))
	if kind == "" or not DODGE.has(kind): return Vector2.ZERO
	var phase := 1.0-float(fighter["dodge_t"])/float(DODGE[kind]["t"])
	return BodyControl.defense_axis(kind,int(fighter["dodge_dir"]),phase)*dodge_weight(fighter)

# ============================ ZONES ========================================
func zone(pos: Vector2) -> String:
	if absf(pos.x) > 2.9 and absf(pos.y) > 2.9: return "CORNER"
	if maxf(absf(pos.x), absf(pos.y)) > 3.1: return "ROPES"
	if pos.length() < 1.85: return "CENTER"
	return "MID"

func _zone_mult(pos: Vector2) -> float:
	match zone(pos):
		"CORNER": return float(T["zones"]["CORNER"]["dmg_mult"])
		"ROPES": return float(T["zones"]["ROPES"]["dmg_mult"])
	return 1.0

func _clamp(F: Dictionary) -> void:
	F["pos"] = Vector2(clampf(F["pos"].x, -RING_HALF, RING_HALF), clampf(F["pos"].y, -RING_HALF, RING_HALF))

func _separate() -> void:
	# two bodies never share a point: drags and corner clamps could otherwise
	# collapse them together (and a shared point has no facing)
	var d: Vector2 = P["pos"] - B["pos"]
	if d.length() >= 0.7: return
	var axis: Vector2 = d.normalized() if d.length() > 0.001 else (Vector2.ZERO - B["pos"]).normalized()
	if axis.length() < 0.5: axis = Vector2(0, 1)
	var mid: Vector2 = (P["pos"] + B["pos"]) * 0.5
	P["pos"] = mid + axis * 0.35; B["pos"] = mid - axis * 0.35
	_clamp(P); _clamp(B)
	if P["pos"].distance_to(B["pos"]) < 0.5:               # both pinned in the same corner: peel toward center
		B["pos"] += (Vector2.ZERO - B["pos"]).normalized() * 0.7

func _wobbled(F: Dictionary) -> bool:
	return F["comp"] < F["comp_max"] * float(T["composure"]["wobble_below_pct"]) / 100.0

func _gassed(F: Dictionary) -> Dictionary:
	for row in T["stamina"]["gassed_curve"]:
		if F["stamina"] > float(row["above"]):
			if _pas(F, "second_gear"): return _second_gear(F, row)                                         # PAC-090: Second Gear (NP_11 s3)
			return row
	return T["stamina"]["gassed_curve"][-1]

func _second_gear(F: Dictionary, row: Dictionary) -> Dictionary:
	# NP_11 s3: the gassed curve's penalties halved between 15 and 40 stamina (each x: 1 - (1 - x) * 0.5)
	var band: Array = _pv("second_gear", "band", [15, 40])
	if float(F["stamina"]) <= float(band[0]) or float(F["stamina"]) > float(band[1]): return row
	var pm := float(_pv("second_gear", "penalty_mult", 0.5))
	var out := row.duplicate()
	for k in out:
		if str(k) != "above": out[k] = 1.0 - (1.0 - float(out[k])) * pm
	return out

# ============================ PLAYER OFFENSE ===============================
func _queue_punch(row: String, inp: Dictionary) -> void:
	if P.has("body_control") and not P["cmd"].is_empty():
		_ev("punch_intent",{"row":P["cmd"]["row"],"outcome":"replaced","reason":"fresh_intent"})
	var mods: Array = []
	if inp.get("power", false): mods.append("POWER")
	if inp.get("body", false): mods.append("BODY")
	if inp.get("haymaker", false): mods.append("HAYMAKER")
	# Native guard is an independent held control, not a slower punch type.
	# Keep the old modifier only for recordings using the legacy input model.
	if inp.get("block", false) and not P.has("body_control"): mods.append("BLOCK_PUNCH")
	P["cmd"] = {"row": row, "mods": mods, "expire_t": BUFFER_TICKS, "lb": inp.get("lb", false), "toward": Vector2(inp.get("move", Vector2.ZERO)).y < -0.2}

func read_prob(tier: int, counter: bool, flash: bool, hiss: bool) -> float:
	# C6/C7: the boss's chance to READ a player punch. The tracker tier raises it
	# (defense only, D3); a live counter window lowers it (fear is a number).
	var p := 0.30 + minf(float(T["adaptation_tracker"]["ramp_cap_pct"]) / 100.0,
		tier * float(T["adaptation_tracker"]["defense_ramp_per_tier_pct"]) / 100.0)
	if bstate == "TELL": p = 0.05
	if btaunt_t > 0: p = 0.05                                                            # mid-taunt he is performing, not reading
	if states["B"].has("tell_jam_audio") or states["B"].has("tell_jam_visual"): p = 0.05   # jammed: he can't read you
	if counter: p *= 0.25
	if flash: p = 0.02
	if hiss: p = 0.0
	return p

func _boxing_ensure() -> void:
	P["motion_identity"] = pname(); B["motion_identity"] = boss_name
	for pair in [[P,B],[B,P]]:
		if not pair[0].has("boxing"):
			PunchContact.sample(pair[0],pair[1],_head_world(pair[0],pair[1],false),0)

func _boxing_begin(who: String, row: String, mods: Array, startup: int, recovery: int) -> void:
	_boxing_ensure()
	var actor: Dictionary = P if who == "P" else B
	var defender: Dictionary = B if who == "P" else P
	var region := contact_region(actor,defender,row,"BODY" in mods)
	var surface: Dictionary = defender["boxing"]["volumes"][1 if "BODY" in mods else 0]
	var target: Vector3 = (Vector3(surface["a"]) + Vector3(surface["b"])) * 0.5
	PunchContact.begin(actor,defender,row,mods,startup,recovery,target,float(region["reach"]))

func _boxing_tick(boss_ticks: int) -> void:
	_boxing_ensure()
	_boxing_recoil(B,boss_ticks)
	# Old native snapshots may contain a move tween. Convert the remaining
	# direction to one bounded supported step rather than resume root gliding.
	var travel: Dictionary = B["boxing"].get("travel",{})
	if not travel.is_empty():
		var remaining: Vector2 = Vector2(travel["to"])-B["pos"]
		_boxing_queue_step(remaining,remaining.length())
		B["boxing"].erase("travel")
	var foot_request: Dictionary = B["boxing"].get("footwork_request",{})
	if boss_ticks > 0: B["boxing"].erase("footwork_request")
	var allowed: bool = (cast.is_empty() or cast.get("who","") != "B") and int(B["dodge_t"]) <= 0 and bool(PunchContact.transition(B,"EXIT")["allowed"])
	var foot_result := BodyControl.advance(B,P,_boxing_body_axis(B,Vector2.ZERO),foot_request.get("axis",Vector2.ZERO) if boss_ticks > 0 else Vector2.ZERO,DT*boss_ticks,allowed,RING_HALF,float(foot_request.get("distance",BodyControl.STEP_M)))
	if not foot_result.is_empty(): _ev("footwork",foot_result.merged({"who":"B"}))
	var preparation := {}
	if bstate in ["TELL","HOLD"] and B["pending"].is_empty():
		var upcoming := []
		for source in pattern.get("strings",{}).get(bstring,{}).get("actions",[]):
			# The VM owns random action selection. A tell must not choose the
			# MIXED_STRING's hand early or advance RNG on every posing tick.
			var verb := str(source).split("(")[0].split(" ")[0]
			if verb == "MIXED_STRING": break
			upcoming.append_array(parse_action(str(source)))
			if upcoming.any(func(item):return item.get("kind","") in ["punch","counter_state","clinch"]): break
		for item in upcoming:
			if item.get("kind","") in ["counter_state","clinch"]: break
			if item.get("kind","") == "punch":
				var row: String = item["row"]
				var duration := maxi(1,ms(float(pattern.get("strings",{}).get(bstring,{}).get("tell",{}).get("ms",700))))
				var amount := clampf(1.0 - float(btimer)/duration,0,1)
				preparation = {"row":row,"mods":["BODY"] if item.get("body",false) else [],"progress":0.22 * amount,"preload":amount}
				break
	elif bstate == "ACTING" and B["pending"].is_empty() and not bqueue.is_empty():
		preparation = B["boxing"].get("preparation",{})
	if not preparation.is_empty():
		# Waiting behind a queued step is still preparation. Follow the actual
		# supported body and physical lane until begin freezes the commitment;
		# retaining the last tell's local coordinates makes that handoff snap.
		preparation = preparation.duplicate(true)
		var row: String = preparation["row"];var mods: Array = preparation["mods"]
		var reg := contact_region(B,P,row,"BODY" in mods)
		var surface: Dictionary = P["boxing"]["volumes"][1 if "BODY" in mods else 0]
		var target: Vector3 = (Vector3(surface["a"])+Vector3(surface["b"]))*0.5
		preparation.merge(PunchContact.aim(B,P,row,mods,target,float(reg["reach"])),true)
	B["motion_offer"] = move_toward(float(B.get("motion_offer",0)),1.0 if hands_down_t > 0 else 0.0,boss_ticks/12.0)
	var motif := str(pattern.get("strings",{}).get(bstring,{}).get("tell",{}).get("motif",""))
	B["motion_gear"] = move_toward(float(B.get("motion_gear",0)),1.0 if bstate in ["TELL","HOLD"] and motif.begins_with("glove_micro_turn") else 0.0,boss_ticks/12.0)
	PunchContact.sample(P,B,_head_world(P,B,false),1)
	PunchContact.sample(B,P,_head_world(B,P,false),boss_ticks,preparation)
	# Sample both movers before applying either result. A late committed hand
	# can trade within this interval; an early interrupted hand cannot finish.
	var contacts := []
	for who in ["P","B"]:
		var actor: Dictionary = P if who == "P" else B
		var defender: Dictionary = B if who == "P" else P
		var result := PunchContact.contact(actor,defender)
		if not result.is_empty(): contacts.append({"who":who,"contact":result,"pending":actor["pending"].duplicate(true)})
	contacts.sort_custom(func(a,b): return float(a["contact"]["time"]) < float(b["contact"]["time"]))
	for entry in contacts:
		if mode != "FIGHT" or not clinch.is_empty(): break
		var who: String = entry["who"]; var result: Dictionary = entry["contact"]
		var actor: Dictionary = P if who == "P" else B
		if actor["pending"].is_empty() and float(result["progress"]) < 0.8: continue
		PunchContact.finish(actor,result)
		_ev("boxing_contact", {"by":who,"contact":result})
		if who == "P":
			P["pending"] = entry["pending"]
			_land_player_punch(result)
		else:
			var delivered: Dictionary = entry["pending"]
			bpending = {"row":delivered["row"],"body":delivered["body"]}
			_ev("boss_act", {"verb":"punch","row":delivered["row"],"body":delivered["body"],"recovery":delivered["recovery"],"contact":result})
			_land_boss_punch(float(delivered["mult"]),result)
	for who in ["P","B"]:
		for signature in BoxingTechniques.observe(P if who == "P" else B):
			_ev("boxing_signature",{"who":who,"id":signature})

func _boxing_recoil(fighter: Dictionary, ticks: int) -> void:
	var state: Dictionary = fighter.get("boxing",{})
	var recoil: Dictionary = state.get("recoil",{})
	if recoil.is_empty(): return
	var before := float(recoil["t"]) / 12.0
	recoil["t"] = mini(12,int(recoil["t"])+ticks)
	var after := float(recoil["t"]) / 12.0
	fighter["pos"] += Vector2(recoil["offset"]) * (after*after*(3-2*after)-before*before*(3-2*before))
	_clamp(fighter)
	if recoil["t"] == 12: state.erase("recoil")

func _boxing_queue_step(direction: Vector2, distance: float) -> void:
	if direction.length_squared() < 0.000001 or distance <= 0: return
	_boxing_ensure()
	var forward := BodyControl.forward(B,P)
	var right := Vector2(-forward.y,forward.x)
	B["boxing"]["footwork_request"] = {"axis":Vector2(direction.dot(right),direction.dot(forward)).normalized(),"distance":minf(distance,BodyControl.STEP_M)}

func _boxing_neutral_step(velocity: Vector2, distance: float) -> void:
	# A tactical range preference is a band, not a point to chase with repeated
	# one-centimetre steps at the full effort cost. Deliberate action steps still
	# retain their requested distance and can be shortened by physical contact.
	if distance < 0.08 or velocity.length_squared() < 0.0025: return
	_boxing_ensure()
	var state: Dictionary = B["boxing"]
	var body: Dictionary = B.get("body_control",{})
	if state.has("footwork_request") or not body.get("step",{}).is_empty() or not body.get("queued",{}).is_empty() or not body.get("gait",{}).is_empty(): return
	if int(state.get("clock",0)) < int(state.get("next_footwork",0)) or not PunchContact.transition(B,"EXIT")["allowed"]: return
	_boxing_queue_step(velocity,distance)
	state["next_footwork"] = int(state.get("clock",0))+ms(1000.0*maxf(0.38,distance/maxf(velocity.length(),0.05)))

func _boxing_push(fighter: Dictionary, offset: Vector2) -> void:
	var state: Dictionary = fighter.get("boxing",{})
	var existing: Dictionary = state.get("recoil",{})
	if not existing.is_empty():
		var t := float(existing["t"])/12.0
		offset += Vector2(existing["offset"]) * (1-t*t*(3-2*t))
	state["recoil"] = {"offset":offset,"t":0}

func _try_execute_cmd() -> bool:
	if P["cmd"].is_empty(): return false
	if P.has("body_control") and not P["cmd"].get("lb",false):
		var readiness := PunchContact.transition(P,str(P["cmd"]["row"]))
		if not readiness["allowed"]:
			if not P["cmd"].has("waiting"):
				P["cmd"]["waiting"] = true
				_ev("punch_intent",{"row":P["cmd"]["row"],"outcome":"buffered","reason":readiness["reason"]})
			return false
		_ev("punch_intent",{"row":P["cmd"]["row"],"outcome":"accepted","reason":readiness["reason"]})
	elif P["busy_t"] > 0: return false
	var c: Dictionary = P["cmd"]; P["cmd"] = {}
	var row: Dictionary = T["punch_matrix"][c["row"]]
	var motion_row: String = ("L_HOOKERCUT" if str(c["row"]).begins_with("L_") else "R_HOOKERCUT") if "HAYMAKER" in c["mods"] else str(c["row"])
	var mv_p := cast_move(motion_row) if c["lb"] else player_move()                                     # PAC-080: the Duo's T3 answers its motion first
	var hiss: bool = c["lb"] and not mv_p.is_empty() and _family_row_matches(str(mv_p["family"]), motion_row) \
		and castable(mv_p) and can_pay(mv_p)
	threw_since_arm = true
	if hiss:
		_track(c["row"]); passive_t = 0
		var house_c := move_house(str(mv_p["name"]))
		if house_c != "" and house_c == str(pattern.get("meta", {}).get("house", "")):
			_fire_event("player_casts_%s_native" % house_c)
		if hands_down_t > 0:
			hands_down_t = 0; _ev("stance", {"hands_down": false}); _fire_event("trap_stance_hands_down")
		_start_cast("P", mv_p)
		return true
	var mod_table: Dictionary = T["modifiers"]
	# An unaffordable modifier falls back to the base punch; the input remains a verb.
	if "POWER" in c["mods"] and float(P["stamina"]) < float(row["stamina"]) * float(mod_table["POWER"]["stamina_mult"]):
		c["mods"].erase("POWER"); _ev("modifier_fallback", {"modifier": "POWER", "row": c["row"]})
	var st_cost := float(row["stamina"]) * (float(mod_table["POWER"]["stamina_mult"]) if "POWER" in c["mods"] else 1.0)
	var fam_c := _punch_family(c["row"])
	var reach_c := float(GEO[fam_c]["reach"]) * float(P["pkg"].get("reach_mult", 1.0)) * (float(P["pkg"].get("straight_reach_mult", 1.0)) if fam_c == "STRAIGHT" else 1.0)
	var pocket: Dictionary = P.get("body_control", {}).get("step", {})
	var native_body := P.has("body_control")
	# Native entry is the committed foot stroke, never a body lean or a second
	# automatic lunge. The legacy move API remains readable by old recordings.
	var stepping: bool = Vector2(pocket.get("direction", Vector2.ZERO)).dot(BodyControl.forward(P, B)) > 0.5 if native_body else bool(c.get("toward", false)) and P["pos"].distance_to(B["pos"]) > reach_c
	if stepping: c["mods"].append("STEPPING")
	var hand_speed := float(_gassed(P)["hand_speed"])
	var startup_mult: float = float(P["pkg"].get("startup_mult", 1.0)) * _zone_punch_mult() / hand_speed
	for modifier in ["POWER", "HAYMAKER", "BLOCK_PUNCH"]:
		if modifier in c["mods"]: startup_mult *= float(mod_table[modifier]["startup_mult"])
	if stepping: startup_mult *= float(mod_table["STEPPING"]["telegraph_mult"])
	var startup := ms(float(row["startup_ms"]) * startup_mult)
	var guard_start := clampf(float(P["block_t"]) / 6.0, 0.0, 1.0)
	if not native_body: P["blocking"] = false; P["block_t"] = 0
	if (fam_c == "HOOK" or fam_c == "UPPERCUT") and P["pos"].distance_to(B["pos"]) <= float(AFF.get("style", {}).get("inside_range_m", 1.3)):
		st_cost *= float(P["pkg"].get("inside_hook_upper_stamina_mult", 1.0))         # the swarmer's phone booth (s1.2)
	P["pending"] = {"row": c["row"], "t": startup, "startup": startup, "mods": c["mods"], "hissatsu": hiss,
		"guard_start":guard_start,
		"counter": P["counter_t"] > 0, "flash": P["flash_t"] > 0, "stamina_cost": st_cost, "read": "none", "stepping": stepping,
		"range_bonus": 0.0, "step_remaining": float(mod_table["STEPPING"]["range_bonus_m"]) if stepping and not native_body else 0.0,
		"step_direction": (B["pos"] - P["pos"]).normalized()}
	P["counter_t"] = 0                                     # window spent by the attempt
	P["busy_t"] = startup + ms(float(row["recovery_ms"]) * _zone_punch_mult() / hand_speed)
	if native_body: _boxing_begin("P",c["row"],c["mods"],startup,int(P["busy_t"])-startup)
	startup = int(P["pending"]["startup"])
	st_cost = float(P["pending"]["stamina_cost"])
	_ev("punch", {"row": c["row"], "mods": c["mods"].duplicate(), "stepping": stepping, "startup": startup, "guard_start":guard_start})
	P["stamina"] = maxf(_sfloor(P), P["stamina"] - st_cost)
	if not native_body:
		P["pos"] += (B["pos"] - P["pos"]).normalized() * LUNGE_P; _clamp(P)
	passive_t = 0
	if "BODY" in c["mods"]: head_streak = 0
	else:
		head_streak += 1
		if head_streak == 3: _fire_event("player_headhunt_streak3")
	_track(c["row"])
	if bool(P["pending"]["counter"]): _habit_counter(c["row"])                                        # PAC-093: thrown into a window his defense opened
	punch_ticks.append(tick); punch_rows.append(c["row"])
	if punch_ticks.size() > 5: punch_ticks.pop_front(); punch_rows.pop_front()
	if punch_ticks.size() >= 3 and punch_ticks[-1] - punch_ticks[-3] <= ms(1200):
		_fire_event("player_3punch_string")
		if punch_rows[-1].ends_with("STRAIGHT") and punch_rows[-2].ends_with("STRAIGHT") and punch_rows[-3].ends_with("STRAIGHT"):
			_fire_event("player_jab_spam")
	# C6: the boss READS the punch at startup and commits a dodge timed to the
	# impact tick (or a guard). The dodge is scheduled, never instant: a head
	# that moves too early is back in place when the punch arrives.
	var p_read := read_prob(_flag_tier(), P["pending"]["counter"], P["pending"]["flash"], hiss)
	var read_ok: bool = rng.randf() < p_read
	var mfr := _misread_frac()
	if read_ok and mfr > 0.0 and (mfr >= 1.0 or rng.randf() < mfr):                                      # PAC-084: he reads the source's dialect - a misread, no evasion, no guard
		B["dodge_plan"] = []; B["dodge_at"] = 0; B["blocking"] = false; B["block_t"] = 0
		P["pending"]["read"] = "misread"
		_ev("misread", {"row": c["row"], "dialect": str(tform["inherit"]["house"])})
	elif read_ok:
		var cd := _correct_dodge_for(c["row"], "BODY" in c["mods"])
		var lead := maxi(0, startup - int(DODGE[cd[0]]["t"]) / 2)
		B["dodge_plan"] = cd; B["dodge_at"] = maxi(1, lead)
		B["blocking"] = false; B["block_t"] = 0
		P["pending"]["read"] = "dodge"
	else:
		B["blocking"] = rng.randf() < _idle_guard("BODY" in c["mods"])                    # NP_04 s2: the guard his IDLE lines hold (0.35 when none)
		B["block_t"] = 999 if B["blocking"] else 0
		if B["blocking"]: P["pending"]["read"] = "guard"
	# ---- PAC-054 sensors that live on the punch itself ----
	if hands_down_t > 0:                                   # she offered the mirror; you took it
		hands_down_t = 0; _ev("stance", {"hands_down": false})
		_fire_event("trap_stance_hands_down")
	cadence.append(tick)
	if cadence.size() > 7: cadence.pop_front()
	if cadence.size() == 7:
		var iv: Array = []
		for i in range(1, 7): iv.append(cadence[i] - cadence[i - 1])
		var sorted_iv := iv.duplicate(); sorted_iv.sort()
		var med: float = float(sorted_iv[2] + sorted_iv[3]) * 0.5
		var locked := med <= float(ms(1500))
		for v in iv:
			if absf(float(v) - med) > 0.15 * med: locked = false
		if locked:
			cadence = []
			_fire_event("player_locks_to_single_tempo")
	return true

func _feint() -> void:
	# NP_03 s8: the punch input released within 80ms of startup. No punch; 1
	# stamina (the punch's own cost comes back); it is a token for the tracker
	# and the 3-punch detectors forget it. He reacted to the press already: a
	# drawn read costs him 1 guard and 10cm of ground; a guard flinch stays up
	# 400ms. Three identical feints in 10s and he stops reacting to that one.
	var pd: Dictionary = P["pending"]; P["pending"] = {}
	var row: String = pd["row"]
	P["stamina"] = maxf(_sfloor(P), minf(stamina_cap, P["stamina"] + float(pd["stamina_cost"])) - (0.0 if tactic_fx.get("feint_free", false) else float(T["feint"]["stamina"])))
	P["busy_t"] = ms(150)
	if tokens.size() > 0 and tokens[-1] == row: tokens.pop_back()
	_track("F_" + row)
	if punch_ticks.size() > 0: punch_ticks.pop_back(); punch_rows.pop_back()
	var now := tick
	while feint_log.size() > 0 and now - int(feint_log[0][0]) > ms(10000): feint_log.pop_front()
	var same := 0
	for f in feint_log:
		if str(f[1]) == row: same += 1
	var wise: bool = same >= 3 or (feint_wise.has(row) and int(feint_wise[row]) > now)
	feint_log.append([now, row])
	if same + 1 >= 3: feint_wise[row] = now + ms(10000)
	var read: String = pd["read"]
	var scrambled: bool = int(comedown.get("scramble_t", 0)) > 0                                         # PAC-084: his own dialect scrambled - a false tell he cannot sell
	if wise or scrambled:
		B["dodge_plan"] = []; B["dodge_at"] = 0; B["blocking"] = false; B["block_t"] = 0
		_ev("feint", {"row": row, "drawn": false, "read": read, "wise": wise, "scrambled": scrambled})
		_say("feint - %s" % ("your own tells are scrambled: he doesn't buy it" if scrambled else "he's not biting, he's seen that one"))
	else:
		var drawn: bool = read == "dodge" or read == "guard"                                               # a misread (PAC-084) drew nothing
		if drawn:
			B["guard"] = maxf(0.0, B["guard"] - float(T["feint"]["enemy_guard_drain"]))
			B["pos"] += (B["pos"] - P["pos"]).normalized() * 0.1; _clamp(B)
			if read == "guard": B["blocking"] = false; B["block_t"] = 0; B["guard_t"] = ms(400)
		_ev("feint", {"row": row, "drawn": drawn, "read": read, "wise": false})
		_say("feint - %s" % ("he bit: slipping at air" if read == "dodge" else ("he flinched: guard up" if read == "guard" else "he didn't move")))
	_fire_event("player_feint")
	_fire_event("player_feint_" + _punch_family(row).to_lower())

func _land_player_punch(contact: Dictionary = {}) -> void:
	var pd: Dictionary = P["pending"]; P["pending"] = {}
	var body: bool = "BODY" in pd["mods"]
	var geo := resolve_geometry(P, B, pd["row"], body, float(pd.get("range_bonus", 0.0)))
	if not contact.is_empty():
		geo = "MISS_PATH" if contact["kind"] == "miss" else "HIT"
		body = contact["target"] == "body"
	if geo != "HIT":
		_power_open(pd)
		if geo == "MISS_REACH" and ("POWER" in pd["mods"] or pd["row"].ends_with("HOOKERCUT")):
			_fire_event("player_power_whiff")
		if body: _fire_event("player_whiffed_body_shot")
		_ev("whiff", {"by": "P", "why": geo})
		if B["dodge"] != "" and geo != "MISS_REACH": _earn_tension_b(float(T.get("tension", {}).get("perfect_defense", 2)))
		if geo != "MISS_REACH": _say("he made you miss (%s)" % geo.to_lower().replace("miss_", ""))
		if contact.is_empty(): B["blocking"] = false
		if geo != "MISS_REACH" and B["dodge"] != "": _mirror_counter()                                  # PAC-093: the mirror answers as you do
		_counter_state_trigger()
		return
	if _walled("B", pd["row"], false):
		_power_open(pd); return
	if _auto_slips("B", pd["row"], body):
		_power_open(pd); _say("he slips it without looking - the wall is up"); B["blocking"] = false; return
	var row: Dictionary = T["punch_matrix"][pd["row"]]
	var dmg: float = float(row["dmg"]) * (float(P["stats"]["PWR"]) / 50.0) * float(_gassed(P)["dmg"])
	if P["charge_t"] > 0: dmg *= 1.1
	if "POWER" in pd["mods"]: dmg *= float(T["modifiers"]["POWER"]["dmg_mult"]) * float(P["pkg"].get("power_dmg_mult", 1.0))
	if body: dmg *= float(T["modifiers"]["BODY"]["dmg_mult"])
	for modifier in ["HAYMAKER", "STEPPING"]:
		if modifier in pd["mods"]: dmg *= float(T["modifiers"][modifier]["dmg_mult"])
	if pd["counter"]: dmg *= float(T["counter_mults"]["counter"])
	if pd["flash"]: dmg *= float(T["counter_mults"]["flash"])
	dmg *= _zone_mult(B["pos"])
	if zone(B["pos"]) == "ROPES": dmg *= float(P["pkg"].get("ropes_dmg_mult", 1.0))          # the slugger on the ropes (s1.2)
	dmg *= _manifest_dmg()                                                                    # PAC-083: the Manifest - all damage x1.4
	# guard layer (boss blocking, not dodged)
	var src := {"counter": pd["counter"], "flash": pd["flash"], "power": "POWER" in pd["mods"], "body": body, "hissatsu": false, "jab": _punch_family(pd["row"]) == "STRAIGHT" and not ("POWER" in pd["mods"])}
	if src["jab"] and _pas(P, "snap"): dmg *= float(_pv("snap", "jab_dmg_mult", 1.0))                  # PAC-090: Snap (NP_11 s3)
	if src["jab"]: dmg *= _gear_mult(P, "jab_dmg")                                                     # PAC-094: his gloves (NP_11 s5, 3% at most)
	var guarded: bool = contact["kind"] in ["guard","deflect"] if not contact.is_empty() else (B["blocking"] or B["guard_t"] > 0) and B["guard_open_t"] <= 0 and not pd["hissatsu"]
	if guarded:
		if contact.is_empty(): B["blocking"] = false
		PunchContact.react(B,contact,dmg*0.18)
		B["guard"] -= float(row["guard_dmg"]) * (0.8 if body else 1.0) * (float(P["pkg"].get("power_shred_mult", 1.0)) if _power_class(pd["row"], "POWER" in pd["mods"]) else 1.0)
		# A loose glove/forearm deflection has no scored head/body impact.
		# Retain guard effort and the block event for existing response hooks.
		if contact.get("kind","") == "deflect": _ev("deflect",{"by":"B","contact":contact})
		else: _comp_damage("B", dmg * float(T["guard"]["chip_pct"]) / 100.0, src)
		if B["guard"] <= 0.0:
			B["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); B["guard_t"] = 0; wall_broken = true
			_say("HIS GUARD IS BROKEN"); _ev("guard_break", {"who": "B"})
		_ev("block", {"by": "B", "contact":contact})
		_power_open(pd)
		_counter_state_trigger()
		return
	var pf := _foul_kind(pd["row"], body, B)
	if pf != "":
		dmg *= 0.5
		_foul("P", pf)
	_on_hit_taken()
	if bstate == "TELL" or not B["pending"].is_empty():       # Native committed startup remains interruptible under the same string rules.
		if (src["jab"] or pd["hissatsu"]) and _interruptible(bstring):
			var ib := _interrupt_block(bstring)
			var stagger := ms(float(ib.get("stagger_ms", REMIX.get("stagger_ms_default", 800))))
			var desync_s := float(ib.get("desync_s", 0.0))
			if bdesync_ms >= 0.0 and desync_s > 0.0: desync_s = bdesync_ms / 1000.0
			binterrupts[bstring] = int(binterrupts.get(bstring, 0)) + 1
			breads[bstring] = int(breads.get(bstring, 0)) + 1
			bstate = "IDLE"; btimer = maxi(stagger, ms(desync_s * 1000.0)); bqueue = []; bfeint = ""
			B["pending"] = {}; B["busy_t"] = stagger
			if desync_s > 0.0: bdesync_widen = true; _ev("desync", {"string": bstring, "seconds": desync_s})
			P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"]))
			if not pd["hissatsu"]: _earn_tension(float(T.get("tension", {}).get("interrupt", 5)))
			_say("INTERRUPT! string broken - flash window open%s" % ("  (DESYNC - the metronome is broken)" if desync_s > 0.0 else ""))
			_ev("interrupt", {"loud": _string_class(bstring) != "normal", "string": bstring, "stagger": stagger, "desync": desync_s > 0.0, "n": int(binterrupts[bstring])})
		else:
			var why := "armored" if _string_class(bstring) == "ARMORED" else ("not_breakable" if not _interruptible(bstring) else "not_a_jab")
			_ev("unbroken", {"string": bstring, "why": why, "loud": _string_class(bstring) != "normal"})
			_say("he takes it and keeps coming - %s" % ("this one doesn't break: dodge it" if why != "not_a_jab" else "only a jab breaks a string"))
	if B["guard_open_t"] > 0: dmg *= float(T["guard"]["break_open_dmg_mult"])
	if cast.size() > 0 and cast["who"] == "B" and src["jab"]: _interrupt_cast("P")
	if pf == "": _echo_queue(dmg, src, pd["row"])                                              # PAC-083: the manifest's echo of a clean punch (0.3 s, +30 %)
	dmg = _comp_damage("B", dmg, src)
	PunchContact.react(B,contact,dmg)
	if body: B["stamina"] = maxf(_sfloor(B), B["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]) * float(tactic_fx.get("body_drain_mult", 1.0)))
	# herding
	var push := (0.2 if pd["row"].ends_with("HOOKERCUT") or pd["row"].ends_with("FLARED") else 0.1) * float(tactic_fx.get("herd_mult", 1.0)) * float(P["pkg"].get("herd_mult", 1.0))
	if _pas(P, "ring_cutter"): push *= float(_pv("ring_cutter", "herd_mult", 1.0))                     # PAC-090: Ring Cutter (NP_11 s3)
	var before_push: Vector2 = B["pos"]
	if not contact.is_empty(): _boxing_push(B,(B["pos"] - P["pos"]).normalized() * push)
	else: B["pos"] += (B["pos"] - P["pos"]).normalized() * push; _clamp(B)
	var tier := _flag_tier()
	if tier == 0 and not pd["hissatsu"]:
		var tt: Dictionary = T.get("tension", {})
		var earn := float(tt.get("flash_hit", 5)) if pd["flash"] else (float(tt.get("counter_hit", 3)) if pd["counter"] else float(tt.get("clean_hit", 0)))
		if zone(B["pos"]) == "CENTER" and zone(P["pos"]) == "CENTER": earn += float(T["zones"]["CENTER"].get("exchange_tension_bonus", 2))
		if pd["counter"] and buffs["P"].has("bonus_tension_on_counter"): earn += float(buffs["P"]["bonus_tension_on_counter"]["v"])
		if _tx(P, "harvest") > 0: earn += float(HOUSES["traits"]["harvest"]["tension_on_exchange_win"]) * _tx(P, "harvest")   # PAC-078: Harvest, anywhere
		_earn_tension(earn)
	if pf == "":                                            # a foul is not a scoring blow
		_score_ep("P")
		if pd["counter"] or pd["flash"]: counters_p += 1
		if buffs["P"].has("ep_plus_on_clean"): ep_p += 1
	var stop: Dictionary = T["hit_feel"]["hitstop_ms"]
	freeze_t = maxi(freeze_t, ms(float(stop["flash_or_hissatsu"] if (pd["flash"] or pd["hissatsu"]) else (stop["counter"] if pd["counter"] else (stop["power"] if "POWER" in pd["mods"] or "HAYMAKER" in pd["mods"] else stop["normal"])))))
	if "HAYMAKER" in pd["mods"] and bool(T["modifiers"]["HAYMAKER"].get("stagger", false)):
		_ev("stagger", {"who": "B", "ticks": freeze_t})  # heavy impact, never bypasses the authored INTERRUPT law
	_ev("hit", {"on": "B", "dmg": dmg, "counter": pd["counter"], "flash": pd["flash"], "hissatsu": pd["hissatsu"], "body": body,
		"row": pd["row"], "displacement": B["pos"] - before_push, "foul": pf != "", "center": zone(B["pos"]) == "CENTER" and zone(P["pos"]) == "CENTER", "stepping": pd.get("stepping", false)})
	if pd["counter"] and not pd["hissatsu"]: _say("FLASH COUNTER x2!" if pd["flash"] else "COUNTER x1.6!")
	if B["comp"] <= 0.0: _drop(false, pd["flash"])

func _foul_kind(row: String, body: bool, D: Dictionary) -> String:
	# NP_01 s5, resolved by geometry like everything else:
	# - a body punch that still reaches a LEANING torso lands on the belt line
	#   the lean lifted toward it: LOW BLOW
	# - a looping punch (overhand, haymaker) that lands on a DUCKING or WEAVING
	#   head comes down on the crown and the back of it: BEHIND THE HEAD
	if body: return "low_blow" if D["dodge"] == "LEAN" else ""
	var fam := _punch_family(row)
	if (fam == "FLARED" or fam == "HOOKERCUT") and (D["dodge"] == "DUCK" or D["dodge"] == "WEAVE"): return "behind_the_head"
	return ""

func _power_open(punch: Dictionary) -> void:
	if "POWER" in punch["mods"]:
		P["guard_open_t"] = maxi(int(P["guard_open_t"]), ms(float(T["modifiers"]["POWER"]["whiff_open_ms"])))
		P["blocking"] = false
		if not P.has("body_control"): P["block_t"] = 0
		_ev("power_open", {"ticks": P["guard_open_t"]})

func _counter_state_trigger() -> void:
	# COUNTER_STATE / COUNTER_ON_BLOCK: a punch that lands on his guard or whiffs
	# while he waits is answered at once (the guard was the trap)
	if B["counter_state_t"] <= 0: return
	B["counter_state_t"] = 0; B["guard_t"] = 0
	bqueue.push_front({"kind": "punch", "row": "R_STRAIGHT", "mult": 1.3, "body": false})
	bstate = "ACTING"; btimer = ms(100)
	_say("COUNTERED - you punched into the trap")

# ============================ BOSS OFFENSE =================================
func _land_boss_punch(mult: float, contact: Dictionary = {}) -> void:
	var brow: String = bpending.get("row", "R_STRAIGHT")
	var body: bool = bpending.get("body", false)
	bpending = {}; B["pending"] = {}
	# A range counter requires a continuous retreat from a threatened position
	# during this attack. Consume the origin on every resolution so another
	# out-of-range swing cannot pay again for the same step.
	var retreat_origin = P.get("range_step_from", null)
	P.erase("range_step_from")
	var geo := resolve_geometry(B, P, brow, body)
	if not contact.is_empty():
		geo = "MISS_PATH" if contact["kind"] == "miss" else "HIT"
		body = contact["target"] == "body"
	var row: Dictionary = T["punch_matrix"][brow]
	if geo == "HIT" and _walled("P", brow, body): return
	if geo == "HIT" and _auto_slips("P", brow, body): geo = "AUTO_SLIP"
	if geo != "HIT":
		var wide := 1.4 if trapped_p else 1.0
		if not contact.is_empty():
			if contact.get("evaded",false) or geo == "AUTO_SLIP":
				var response := "range_step" if contact.get("root_evaded",false) else "slip"
				P["counter_t"] = _window(response,wide)
				_ev("range_step" if response == "range_step" else "body_evade",{"ticks":P["counter_t"],"contact":contact})
				if response != "range_step":
					_earn_tension(float(T.get("tension",{}).get("perfect_defense",2)))
					_weather("slip")
				_habit_chance()
				if P["counter_state_t"] > 0:
					P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0
			_ev("evade",{"by":"P","why":geo,"contact":contact})
			return
		var body_axis: Vector2 = P.get("body_control", {}).get("axis", Vector2.ZERO)
		if body_axis.length() > 0.05:
			var neutral := P.duplicate(true)
			neutral["body_control"]["axis"] = Vector2.ZERO
			neutral.erase("boxing") # A hypothetical neutral cannot reuse the displaced posed head.
			# Credit the actual displaced target only if this same attack would
			# have intersected neutral. Body input alone earns no counter reward.
			if resolve_geometry(B, neutral, brow, body) == "HIT":
				var response := "duck" if body_axis.y > absf(body_axis.x) else "slip"
				P["counter_t"] = _window(response, wide)
				_ev("body_evade", {"axis": body_axis, "ticks": P["counter_t"], "why": geo})
		if geo == "MISS_REACH" and P["dodge"] == "" and retreat_origin is Dictionary:
			var before_step := P.duplicate(); before_step["pos"] = retreat_origin["player"]
			var attacker_before := B.duplicate(); attacker_before["pos"] = retreat_origin["attacker"]
			if resolve_geometry(attacker_before, before_step, brow, body) == "HIT":
				P["counter_t"] = _window("range_step", wide)
				# NP_05 pays perfect blocks/slips here, not range evasion.
				# A clean counter from this window earns its normal hit reward.
				_ev("range_step", {"ticks": P["counter_t"]}); _say("STEPPED OUT - counter window!")
		if P["dodge"] != "":
			match P["dodge"]:
				"SLIP": P["counter_t"] = _window("slip", wide)
				"DUCK": P["counter_t"] = _window("duck", wide)
				"LEAN": P["counter_t"] = _window("perfect_block", 0.8 * wide)
				"WEAVE":
					P["counter_t"] = _window("weave", wide)
					pinned_p_t = 0; trapped_p = false
			_say("%s - counter window!%s" % [P["dodge"].to_lower() + "ped it" if P["dodge"] != "LEAN" else "leaned under it", "  [trapped read: wider]" if trapped_p else ""])
			_earn_tension(float(T.get("tension", {}).get("perfect_defense", 2)))    # NP_05 s2: a successful slip
			_weather("slip")                                                         # PAC-086: NP_09 s7
		if geo == "AUTO_SLIP": P["counter_t"] = _window("slip", wide); _weather("slip")
		if P["counter_t"] > 0: _habit_chance()                                                        # PAC-093: a counter window his defense opened
		_ev("evade", {"by": "P", "why": geo, "dodge": P["dodge"]})
		if P["counter_state_t"] > 0: P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0; _say("COUNTER STANCE - he swung into it: flash window")
		return
	var dmg: float = float(row["dmg"]) * (float(B["stats"]["PWR"]) / 50.0) * mult * float(_gassed(B)["dmg"]) * float(bmods["dmg"])
	if body: dmg *= float(T["modifiers"]["BODY"]["dmg_mult"]) * float(bmods["body_dmg"])
	if _power_class(brow, false): dmg *= float(B["pkg"].get("power_dmg_mult", 1.0))       # his haymakers are his power punches
	dmg *= _zone_mult(P["pos"])
	if zone(P["pos"]) == "ROPES": dmg *= float(B["pkg"].get("ropes_dmg_mult", 1.0))
	dmg *= _bmanifest_dmg() * _weather_mult()                                               # PAC-086: his Manifest x1.4; weathered, his damage halved
	var bf := _foul_kind(brow, body, P)
	if bf != "":
		if bwarnings >= _warning_cap() or bool(bmods["pull_all"]):   # clean fighters, dirty ones at their cap, and Alfie once the flirtation stops, pull it
			_ev("pulled", {"by": "B", "foul": bf})
			_say("he pulls it off your %s - not taking the %s call" % [P["dodge"].to_lower(), bf.replace("_", " ")])
			return
		dmg *= 0.5
		_foul("B", bf)
	var guarded: bool = contact["kind"] in ["guard","deflect"] if not contact.is_empty() else P["blocking"] and P["guard_open_t"] <= 0
	if guarded:
		var wide := 1.4 if trapped_p else 1.0
		PunchContact.react(P,contact,dmg*0.18)
		if P["block_t"] <= ms(float(T["guard"]["perfect_block_window_ms"])) and (contact.is_empty() or contact["kind"] == "guard" and P["blocking"] and P["block_t"] > 0):
			P["counter_t"] = _window("perfect_block", wide)
			P["pb_streak"] += 1
			if P["counter_state_t"] > 0: P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0
			_say("PERFECT BLOCK - counter window!"); _ev("perfect_block", {}); _habit_chance()
			_weather("perfect_block")                                                # PAC-086: NP_09 s7
			_earn_tension(float(T.get("tension", {}).get("perfect_defense", 2)))
			if P["pb_streak"] >= 2:
				P["pb_streak"] = 0; _fire_event("player_perfect_block_streak2")
			return
		P["pb_streak"] = 0
		P["guard"] -= float(row["guard_dmg"]) * (0.8 if body else 1.0) * (float(B["pkg"].get("power_shred_mult", 1.0)) if _power_class(brow, false) else 1.0)
		if contact.get("kind","") == "deflect": _ev("deflect",{"by":"P","contact":contact})
		else: _comp_damage("P", dmg * float(T["guard"]["chip_pct"]) / 100.0, {"counter": mult > 1.0, "flash": false, "power": false, "body": body, "hissatsu": false, "jab": _punch_family(brow) == "STRAIGHT"})
		if P["counter_state_t"] > 0: P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0
		if P["guard"] <= 0.0:
			P["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); _say("GUARD BREAK - you're OPEN"); _ev("guard_break", {"who": "P"})
		_ev("block", {"by": "P", "contact":contact})
		return
	if P["guard_open_t"] > 0: dmg *= float(T["guard"]["break_open_dmg_mult"])
	if bstring != "": blanded[bstring] = int(blanded.get(bstring, 0)) + 1                       # the string landed clean (Baro's Examen gate)
	if cast.size() > 0 and cast["who"] == "P" and _punch_family(brow) == "STRAIGHT": _interrupt_cast("B")
	if bf == "": _becho_queue(dmg, {"counter": mult > 1.0, "flash": false, "power": false, "body": body, "hissatsu": false, "jab": _punch_family(brow) == "STRAIGHT"}, brow)   # PAC-086: his manifest's echo
	dmg = _comp_damage("P", dmg, {"counter": mult > 1.0, "flash": false, "power": false, "body": body, "hissatsu": false, "jab": _punch_family(brow) == "STRAIGHT"})
	PunchContact.react(P,contact,dmg)
	if not contact.is_empty() and _punch_family(brow) == "STRAIGHT" and not P["pending"].is_empty():
		var action: Dictionary = P.get("boxing",{}).get("action",{})
		if float(action.get("progress",1)) < 0.8:
			P["pending"] = {}; P["cmd"] = {}
			_ev("punch_interrupted",{"who":"P","by":"B","row":action.get("row",""),"progress":action.get("progress",0)})
	if body: P["stamina"] = maxf(_sfloor(P), P["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]) * float(btactic_fx.get("body_drain_mult", 1.0)))
	clean_t = 0
	if bf == "":
		_score_ep("B")
		if mult > 1.0: counters_b += 1
		var tt: Dictionary = T.get("tension", {})
		var earn_b := float(tt.get("counter_hit", 3)) if mult > 1.0 else float(tt.get("clean_hit", 0))
		if zone(B["pos"]) == "CENTER" and zone(P["pos"]) == "CENTER": earn_b += float(T["zones"]["CENTER"].get("exchange_tension_bonus", 2))
		if _tx(B, "harvest") > 0: earn_b += float(HOUSES["traits"]["harvest"]["tension_on_exchange_win"]) * _tx(B, "harvest")   # PAC-078: Harvest, his side
		if earn_b > 0.0: _earn_tension_b(earn_b)
	var before_push: Vector2 = P["pos"]
	var push: Vector2 = (P["pos"] - B["pos"]).normalized() * 0.12 * float(B["pkg"].get("herd_mult", 1.0)) * float(btactic_fx.get("herd_mult", 1.0))
	if not contact.is_empty(): _boxing_push(P,push)
	else: P["pos"] += push; _clamp(P)
	freeze_t = maxi(freeze_t, ms(float(T["hit_feel"]["hitstop_ms"]["normal"])))
	_ev("hit", {"on": "P", "dmg": dmg, "body": body, "displacement": P["pos"] - before_push})
	if P["comp"] <= 0.0: _drop(true)

# ============================ DROPS / EIGHT ================================
func _drop(player_down: bool, flash: bool = false) -> void:
	# NP_01 s3 scoring: DROP 1 / FLASH DROP 2 / SEGMENT KO 3 (three-knockdown rule or a failed count)
	if player_down and no_drop_t > 0:                       # IRON RESOLVE: wobbles instead
		P["comp"] = 1.0
		_ev("iron_resolve", {"left": no_drop_t}); _say("IRON RESOLVE - %s will not go down (%.1fs left)" % [pname(), no_drop_t / float(TICK_HZ)])
		return
	if not player_down and bno_drop_t > 0:                  # their corner's Iron Resolve
		B["comp"] = 1.0
		_ev("iron_resolve_b", {"left": bno_drop_t}); _say("IRON RESOLVE - %s will not go down (%.1fs left)" % [boss_name, bno_drop_t / float(TICK_HZ)])
		return
	if _never_twice(P if player_down else B, "P" if player_down else "B"): return                       # PAC-078: Never Twice - the second drop is a wobble
	var native_count := P.has("body_control")
	if native_count:
		_boxing_break_exchange()
		P["boxing"]["count_down"] = player_down; B["boxing"]["count_down"] = not player_down
		P["boxing"]["count_age"] = 0; B["boxing"]["count_age"] = 0
	if tform.has("echoes"): tform["echoes"] = []                                                         # PAC-083: a drop cancels the manifest's echoes in flight
	if btform.has("echoes"): btform["echoes"] = []                                                       # PAC-086: his too
	if player_down and btform.size() > 0: btform["dropped"] = true                                      # PAC-086: knocked down inside his storm - not weathered
	if player_down:
		drops_b += 1; P["drops"] += 1; score_b += 1
		_earn_tension_b(float(T.get("tension", {}).get("drop", 10)))
		_ev("drop", {"who": "P"})
		if r6: _say("GOLDEN DROP - %s is down" % pname()); _pi_tick("segments", bdialect, 1 + int(staff_fx.get("pi_dual_extra", 0.0))); _end_dual(); return
		if P["drops"] >= 3:
			_segment_ko(false, "three knockdowns"); return
		mode = "EIGHT"
		var w := lerpf(float(T["standing_eight"]["beat_window_ms_by_HRT"]["hrt30"]),
			float(T["standing_eight"]["beat_window_ms_by_HRT"]["hrt90"]),
			clampf((float(P["stats"]["HRT"]) - 30.0) / 60.0, 0.0, 1.0)) * 4.0
		if P["drops"] == 2: w *= 0.6                        # second drop: one beat of forgiveness gone
		eight = {"beats_left": int(T["standing_eight"]["beats"]), "window_t": ms(w), "timer_t": ms(1200), "rise_prev": false}
		if native_count: eight.merge({"native":true,"who":"P","age":0,"phase":"count"})
		_say("DOWN! Standing-eight: RISE on the beat (%d beats)" % eight["beats_left"])
	else:
		drops_p += 1; B["drops"] += 1
		score_p += 2 if flash else 1
		_earn_tension(float(T.get("tension", {}).get("drop", 10)))
		if tform.has("fx") and float(_zone_fx().get("drop_refund", 0.0)) > 0.0:                           # PAC-085: a drop scored Awakened - the refund, flat, to the team bar
			var rf := float(_zone_fx()["drop_refund"]); var tb := tension
			tension = minf(100.0, tension + rf)
			_ev("refund", {"who": pname(), "tension": tension - tb, "bar": tension})
			_say("AWAKENED DROP - +%d Tension back to the bar (%d)" % [int(tension - tb), int(tension)])
		bdrop_conceded = true
		if flash: bflash_conceded = true
		if not native_count:
			B["comp"] = B["comp_max"] * float(T["composure"]["post_count_reset_pct"]) / 100.0
			B["no_regen_t"] = ms(float(T["composure"]["regen_halt_after_count_s"]) * 1000.0)
		_ev("drop", {"who": "B", "flash": flash})
		_say("%s %d-%d" % ["FLASH DROP! (2 pts)" if flash else "DROP SCORED!", score_p, score_b])
		if r6: _say("GOLDEN DROP - %s is down" % boss_name); _pi_tick("segments", bdialect, 1 + int(staff_fx.get("pi_dual_extra", 0.0))); _pi_beaten(boss_name); _beat("segment", boss_name, str(B["house"])); _end_dual(); return
		if B["drops"] >= 3: _segment_ko(true, "three knockdowns")
		elif native_count:
			mode = "EIGHT"
			var hrt := clampf((float(B["stats"]["HRT"])-30.0)/60.0,0,1)
			var window := lerpf(float(T["standing_eight"]["beat_window_ms_by_HRT"]["hrt30"]),float(T["standing_eight"]["beat_window_ms_by_HRT"]["hrt90"]),hrt)*4.0
			if B["drops"] == 2: window *= 0.6
			eight = {"native":true,"who":"B","age":0,"phase":"count","beats_left":int(T["standing_eight"]["beats"]),"window_t":ms(window),"timer_t":ms(1200),"rise_prev":false}
			_say("%s DOWN - the referee counts" % boss_name)

func _boxing_break_exchange() -> void:
	# A drop cancels intentions as well as damage timers. Keep the physical
	# solver and planted feet so the count cannot snap back to an idle puppet.
	_boxing_ensure()
	bpending = {}; bqueue = []; bstring = ""; bstate = "RECOVER"; btimer = ms(300)
	cast = {}; clinch = {}; clinch_t = 0; freeze_t = 0; hands_down_t = 0
	block_prev = false; block_hold_t = 0
	for fighter in [P,B]:
		fighter["pending"] = {}; fighter["cmd"] = {}; fighter["busy_t"] = 24
		fighter["blocking"] = false; fighter["dodge"] = ""; fighter["dodge_plan"] = []
		for key in ["dodge_t","dodge_at","block_t","guard_t","counter_t","flash_t","counter_state_t","charge_t"]: fighter[key] = 0
		fighter.erase("frozen_step")
		var body: Dictionary = fighter.get("body_control",{})
		body["step"] = {}; body["queued"] = {}; body["recovery"] = 0.0
		var boxing: Dictionary = fighter.get("boxing",{})
		for key in ["recoil","travel","footwork_request","evasion","technique_flow","sequence_wait"]: boxing.erase(key)

func _boxing_count_pose() -> void:
	eight["age"] = int(eight["age"])+1
	var weight := PunchContact.Motion.ramp(float(eight["age"])/90.0)
	if eight["phase"] == "rise": weight = PunchContact.Motion.ramp(float(eight["timer_t"]-1)/72.0)
	P["boxing"]["count_age"] = eight["age"]; B["boxing"]["count_age"] = eight["age"]
	_boxing_recovery_pose(str(eight["who"]),weight)

func _boxing_recovery_pose(who: String, weight: float) -> void:
	for pair in [[P,B,"P"],[B,P,"B"]]:
		var fighter: Dictionary = pair[0]
		var effort: float = fighter["stamina"]
		BodyControl.advance(fighter,pair[1],Vector2.ZERO,Vector2.ZERO,DT,false,RING_HALF)
		fighter["stamina"] = effort # The referee's count is outside boxing effort time.
		fighter["busy_t"] = maxi(0,int(fighter["busy_t"])-1)
		fighter["boxing"]["count_weight"] = weight if pair[2] == who else 0.0
		PunchContact.sample(fighter,pair[1],_head_world(fighter,pair[1],false),1)

func _finish_boxing_count() -> void:
	var who: String = eight["who"]
	var fighter: Dictionary = P if who == "P" else B
	fighter["comp"] = fighter["comp_max"] * float(T["composure"]["post_count_reset_pct"]) / 100.0
	fighter["no_regen_t"] = ms(float(T["composure"]["regen_halt_after_count_s"])*1000.0)
	for f in [P,B]:
		for key in ["count_weight","count_down","count_age"]: f["boxing"].erase(key)
	eight = {}; mode = "FIGHT"
	if who == "P":
		_earn_tension(float(T["standing_eight"]["crowd_surge_tension"])); _tech_eight(pname())
	else: _earn_tension_b(float(T["standing_eight"]["crowd_surge_tension"]))
	_ev("eight_up",{"who":who,"name":pname() if who == "P" else boss_name})
	_say("%s UP AT EIGHT - composure regen halted 10s" % (pname() if who == "P" else boss_name))

func _segment_ko(player_scored: bool, why: String) -> void:
	# the KO is worth 3; the loser's remaining segment time is forfeit and the
	# winner shadowboxes it out for a Tension trickle (+1 per 10s, NP_01 s3)
	var trickle := float(clock_t / ms(10000))
	if player_scored:
		score_p += 3
		_earn_tension(trickle)
		_ev("segment_ko", {"by": "P"})
		_end_segment("SEGMENT KO by %s (%s, +3)" % [pname(), why])
	else:
		score_b += 3
		_earn_tension_b(trickle)
		_ev("segment_ko", {"by": "B"})
		_end_segment("SEGMENT KO against %s (%s)" % [pname(), why])

func _eight_step(rise: bool) -> void:
	if eight.get("native",false):
		_boxing_count_pose()
		if eight["phase"] == "rise":
			eight["timer_t"] -= 1
			if int(eight["timer_t"]) <= 0: _finish_boxing_count()
			return
		if eight["who"] == "B":
			# Same HRT-gated per-beat chance as the existing delegated fighter.
			# Draw once on the beat; player buttons cannot get the opponent up.
			rise = int(eight["timer_t"]) == 1 and rng.randf() < 0.55 + 0.45*clampf(float(B["stats"]["HRT"])/99.0,0,1)
	eight["timer_t"] -= 1
	if eight["timer_t"] < -eight["window_t"]:
		var player_scored: bool = eight.get("who","P") == "B"
		_say("COUNTED OUT."); eight = {}; mode = "FIGHT"
		_segment_ko(player_scored, "counted out"); return
	var edge: bool = rise and not eight["rise_prev"]
	eight["rise_prev"] = rise
	if edge and absi(eight["timer_t"]) <= eight["window_t"]:
		eight["beats_left"] -= 1
		_ev("eight_beat", {"left": eight["beats_left"]})
		if eight["beats_left"] <= 0:
			if eight.get("native",false):
				eight["phase"] = "rise"; eight["timer_t"] = 72
				return
			mode = "FIGHT"; eight = {}
			P["comp"] = P["comp_max"] * float(T["composure"]["post_count_reset_pct"]) / 100.0
			P["no_regen_t"] = ms(float(T["composure"]["regen_halt_after_count_s"]) * 1000.0)
			_earn_tension(float(T["standing_eight"]["crowd_surge_tension"]))
			_ev("eight_up", {"name": pname()})
			_tech_eight(pname())                                                                            # PAC-091: the deed Whitlock's lesson waits on
			_say("UP AT EIGHT! Crowd surge - composure regen halted 10s")
			return
		eight["timer_t"] = ms(1200)
		_say("beat! %d to go" % eight["beats_left"])

# ============================ DUAL FLOW ====================================
func _end_segment(why: String) -> void:
	P["pending"] = {}; bpending = {}; B["pending"] = {}; eight = {}; cast = {}; clinch = {}; clinch_t = 0
	charged = contributed >= _charged_threshold()
	if charged: relay_chain += 1
	elif contributed < 10.0: relay_chain = 0                # a lost segment keeps the chain; an empty one breaks it
	full_relay = relay_chain >= int(TAC.get("corner", {}).get("full_relay_chain", 3))
	# NP_01 s3.2: EP decide segment wins - the "rounds won" drama; the drops are the score, not the segment
	var won: bool = (ep_p - int(seg_score0[2])) > (ep_b - int(seg_score0[3]))
	var lost: bool = (ep_b - int(seg_score0[3])) > (ep_p - int(seg_score0[2]))
	if won: seg_wins_p += 1
	elif lost: seg_wins_b += 1
	condition[pname()] = {"stamina": P["stamina"], "guard": P["guard"], "comp": P["comp"]}       # s6: condition carries if he re-enters
	bcondition[boss_name] = {"stamina": B["stamina"], "guard": B["guard"], "comp": B["comp"]}
	if save_bar and won:
		_earn_tension(float(TAC.get("corner", {}).get("save_bar_bonus", 5)))
		_say("held the bar and won it anyway: +%d" % int(TAC.get("corner", {}).get("save_bar_bonus", 5)))
	save_bar = false
	var seg_win := float(T.get("tension", {}).get("segment_win", 5))            # NP_05 s2: segment win +5, both teams
	if won: _earn_tension(seg_win)
	elif lost: _earn_tension_b(seg_win)
	bcharged = bcontributed >= 25.0
	if bcharged: brelay_chain += 1
	elif bcontributed < 10.0: brelay_chain = 0
	bcontributed = 0.0
	_ev("seg_end", {"why": why, "won": won, "charged": charged, "chain": relay_chain})
	if bout.is_empty() and ECO.size() > 0:                    # the segment's XP: the fight's events plus the segment won
		pay_segment(won, seg_xp); seg_xp = 0
	if bout.is_empty():                                       # NP_02 s3: a dual segment fought reaches PI 2 on the dialect; a segment won marks a named boss beaten
		_pi_tick("segments", bdialect, 1 + int(staff_fx.get("pi_dual_extra", 0.0)))
		if won or B["drops"] >= 3: _pi_beaten(boss_name); _beat("segment", boss_name, str(B["house"]))   # PAC-075: a segment won against him, for BEAT_IN(dual[segment])
	if obj.size() > 0 and str(obj["kind"]) == "segment_end" and why == "clock" and P["drops"] < 3: obj["met"] = true; obj["why"] = "went the distance"
	if seg_idx >= segments() - 1 or r6:
		_end_dual(); return
	mode = "CARD"; card_t = ms(float(TAC.get("corner", {}).get("card_seconds", 4)) * 1000.0)
	_ev("seg_card", {"seg": seg_idx + 1, "why": why, "won": won, "ep_p": ep_p - int(seg_score0[2]), "ep_b": ep_b - int(seg_score0[3]),
		"score_p": score_p, "score_b": score_b, "tension": tension, "banked": contributed, "charged": charged, "chain": relay_chain})
	_say("SEGMENT R%d (%s) - %s   EP %d-%d   Tension carried %.0f (banked %.0f)%s" %
		[seg_idx + 1, why, "MILLBROOK" if won else "ASCENDANT", ep_p - int(seg_score0[2]), ep_b - int(seg_score0[3]), tension, contributed,
		 "   >> RELAY CHARGED (chain %d)%s" % [relay_chain, " - FULL RELAY" if full_relay else ""] if charged else ""])

func _open_corner() -> void:
	mode = "CORNER"; card_t = 0
	var c: Dictionary = TAC.get("corner", {})
	corner = {"t": ms(float(c.get("seconds", 45)) * 1000.0), "actions_left": int(c.get("actions", 2)), "log": [], "locked": false}
	if player_lock > 0:
		player_lock -= 1; corner["actions_left"] = 0; corner["locked"] = true
		_ev("corner_locked", {"by": "crowd"}); _say("HOSTILE CROWD - your corner is locked out this phase")
	_enemy_corner()
	var upn := seg_idx if r6 else seg_idx + 1
	_ev("corner_open", {"seconds": int(c.get("seconds", 45)), "actions": corner["actions_left"], "next": lineup[upn]["name"], "boss": boss_slot_label(upn), "r6": r6})
	var th := talk_hint(str(lineup[upn]["name"]))
	if th.size() > 0: _ev("talk_hint", th)                                                              # NP_10 s4: a teammate who knows them tells you
	_say("CORNER (45s, 2 actions): %s %s. Swap / tactic / super / staff / save the bar - or send." % ["GOLDEN DROP pick:" if r6 else "next up", lineup[upn]["name"]])

func corner_pick(_opt: int) -> void:
	if mode == "CARD": _open_corner()
	elif mode == "CORNER": _send_next(false)

func _up_slot() -> int: return seg_idx if r6 else seg_idx + 1

func _send_next(overrun: bool) -> void:
	if overrun: pending_fx["overrun"] = true
	corner = {}
	if not r6: seg_idx += 1
	_load_segment()
	if overrun: _say("CORNER OVERRUN - %s comes out at %d%% stamina" % [pname(), int(TAC.get("corner", {}).get("overrun_stamina_pct", 80))])

func corner_options() -> Dictionary:
	# what the corner can do right now (the menu the presentation draws)
	var eq: Dictionary = TAC.get("equipped", {})
	var out := {"swap": [], "tactic": [], "super": [], "staff": [], "save_bar": not save_bar_next, "actions_left": int(corner.get("actions_left", 0)),
		"swap_cost": _swap_cost()}
	if r6 or bool(fmt.get("repeat_slots", false)):           # anyone dressed can take the slot (s6 / s8); the one in it is not a swap
		for f in dressed:
			if str(f["name"]) != str(lineup[_up_slot()]["name"]): out["swap"].append(str(f["name"]))
	else:
		for r in reserves: out["swap"].append(str(r["name"]))
		for j in range(seg_idx + 2, lineup.size()): out["swap"].append(str(lineup[j]["name"]))
	if r6: out["swap_cost"] = int(FMT.get("r6", {}).get("pick_cost", 0))
	for t in TAC.get("special", []):
		if str(t["id"]) in eq.get("special", []):
			out["tactic"].append({"id": str(t["id"]), "name": str(t["name"]), "cost": int(t["cost"]), "cooldown": int(tactic_cd.get(str(t["id"]), -9)) == seg_idx, "text": str(t["text"])})
	for su in TAC.get("super", []):
		if str(su["id"]) == str(eq.get("super", "")): out["super"].append({"id": str(su["id"]), "name": str(su["name"]), "used": super_used, "text": str(su["text"])})
	for st in TAC.get("staff_active", []):
		var sdw := _dressed_with_active(str(st["id"]))
		if sdw.size() > 0: out["staff"].append({"id": str(st["id"]), "name": str(st["name"]), "charges": int(staff_charges.get(str(st["id"]), 0)), "text": str(st["text"]), "by": sdw.map(func(x): return "%s Lv%d" % [staff_name(str(x)), staff_level(str(x))]),
			"heat": int(crowd_heat), "needs": int(STAFF.get("crowd", {}).get("converts", {}).get(str(st["id"]), {}).get("needs", 0))})
	out["talk"] = talk_menu()
	return out

func talk_menu() -> Dictionary:
	# NP_10 s4: the three options for the next fighter, each in his own line, and what his bonds reveal
	var up := _up_slot()
	if TALK.is_empty() or up >= lineup.size(): return {}
	var card: Dictionary = lineup[up]
	var nm := str(card.get("name", ""))
	var lines: Dictionary = TALK.get("lines", {}).get(nm, {})
	var opts: Array = []
	for o in TALK.get("order", []): opts.append({"option": str(o), "label": str(TALK.get("approaches", {}).get(str(o), {}).get("label", o)), "line": str(lines.get(str(o), ""))})
	return {"who": nm, "readable": str(card.get("talk", "")) != "", "options": opts, "hint": talk_hint(nm), "done": bool(corner.get("talked", false))}

func talk_hint(nm: String) -> Dictionary:
	# bond levels reveal which talk lands: the fighter's best Kizuna with a dressed teammate - Gymmates rules one wrong option out, Corner Voices and up names the right one
	var card := _card_of(nm)
	var prof := str(card.get("talk", ""))
	if TALK.is_empty() or prof == "": return {}
	var best := 0; var via := ""
	for dc in dressed:
		var other := str(dc.get("name", ""))
		if other == nm or other == "": continue
		var lv := kizuna_level(nm, other)
		if lv > best: best = lv; via = other
	var rv: Dictionary = TALK.get("reveal", {})
	if best >= int(rv.get("name_level", 2)): return {"who": nm, "reveal": "name", "option": prof, "via": via, "level": best}
	if best >= int(rv.get("rule_out_level", 1)):
		for o in TALK.get("order", []):
			if str(o) != prof: return {"who": nm, "reveal": "rule_out", "option": str(o), "via": via, "level": best}
	return {}

func _swap_cost() -> int:
	var c: Dictionary = TAC.get("corner", {})
	return 0 if (swaps_used == 0 and bool(c.get("swap_first_free", true))) else int(c.get("swap_cost", 15))

func _corner_refuse(kind: String, why: String) -> void:
	_ev("corner_refused", {"action": kind, "why": why}); _say("corner: %s - %s" % [kind, why])

func corner_action(a: Dictionary) -> bool:
	# NP_10 s4: two actions per corner; each kind has its own price
	if mode != "CORNER": return false
	var kind := str(a.get("kind", ""))
	if kind == "delegate" or kind == "delegate_all" or kind == "hands_on":       # NP_10 s8: who plays the next segment is a call, not an action
		delegate_next = kind == "delegate"; delegate_all = kind == "delegate_all"
		_ev("corner_action", {"action": kind, "arg": "", "left": corner["actions_left"]})
		_say("%s" % ["%s will play the next segment on their own" % lineup[_up_slot()]["name"] if kind == "delegate" else ("the rest of the dual is theirs - you keep the corners" if kind == "delegate_all" else "hands on: you play the next segment")])
		return true
	if int(corner["actions_left"]) <= 0: _corner_refuse(kind, "locked out by the crowd" if corner.get("locked", false) else "no actions left"); return false
	var c: Dictionary = TAC.get("corner", {})
	var eq: Dictionary = TAC.get("equipped", {})
	match kind:
		"swap":
			var name := str(a.get("arg", ""))
			var cost := int(FMT.get("r6", {}).get("pick_cost", 0)) if r6 else _swap_cost()
			var opts: Array = corner_options()["swap"]
			if not name in opts: _corner_refuse(kind, "%s is not available (%s)" % [name, "no one else is dressed" if opts.is_empty() else "fought, or the upcoming slot"]); return false
			if tension < cost: _corner_refuse(kind, "needs %d Tension" % cost); return false
			var up: int = _up_slot()
			var placed := false
			for i in reserves.size():
				if str(reserves[i]["name"]) == name and not (r6 or bool(fmt.get("repeat_slots", false))):
					var tmp: Dictionary = lineup[up]; lineup[up] = reserves[i]; reserves[i] = tmp; placed = true
			for j in range(up + 1, lineup.size()):
				if str(lineup[j]["name"]) == name and not placed and not (r6 or bool(fmt.get("repeat_slots", false))):
					var tmp2: Dictionary = lineup[up]; lineup[up] = lineup[j]; lineup[j] = tmp2; placed = true
			if not placed:                                     # a repeat slot or the Golden DROP pick: the card takes the slot, whoever else it belongs to
				for f in dressed:
					if str(f["name"]) == name: lineup[up] = f
			tension -= cost
			if not r6: swaps_used += 1
			_say("%s: %s takes %s%s" % ["GOLDEN DROP" if r6 else "SWAP", name, "the Golden DROP" if r6 else "R%d" % (up + 1), "" if cost == 0 else " (-%d Tension)" % cost])
		"tactic":
			var id := str(a.get("id", ""))
			var rec: Dictionary = {}
			for t in TAC.get("special", []):
				if str(t["id"]) == id: rec = t
			if rec.is_empty() or not id in eq.get("special", []): _corner_refuse(kind, "%s is not equipped" % id); return false
			if int(tactic_cd.get(id, -9)) == seg_idx: _corner_refuse(kind, "%s is on cooldown (one corner between uses)" % rec["name"]); return false
			if tension < float(rec["cost"]): _corner_refuse(kind, "%s needs %d Tension" % [rec["name"], int(rec["cost"])]); return false
			tension -= float(rec["cost"]); tactic_cd[id] = seg_idx + 1
			for k in rec["effect"]: pending_fx[k] = rec["effect"][k]
			_say("TACTIC: %s (-%d Tension) - %s" % [rec["name"], int(rec["cost"]), rec["text"]])
		"super":
			var sid := str(eq.get("super", ""))
			if super_used: _corner_refuse(kind, "the super is spent for this dual"); return false
			var srec: Dictionary = {}
			for su in TAC.get("super", []):
				if str(su["id"]) == sid: srec = su
			if srec.is_empty(): _corner_refuse(kind, "no super equipped"); return false
			super_used = true
			for k in srec["effect"]: pending_fx[k] = srec["effect"][k]
			if srec["effect"].has("enemy_corner_lock"): enemy_lock += 1        # HOSTILE CROWD: his next corner phase
			_say("SUPER TACTIC: %s - %s" % [srec["name"], srec["text"]])
		"staff":
			var sraw := str(a.get("id", ""))                                                           # an active's id, or the id of a dressed staffer who carries it (PAC-074)
			var stid := sraw if _staff_active_rec(sraw).size() > 0 else staff_active_of(sraw)
			var strec := _staff_active_rec(stid)
			var dw := _dressed_with_active(stid)
			if strec.is_empty() or dw.is_empty() or (sraw != stid and not (sraw in dw)): _corner_refuse(kind, "%s is not dressed" % sraw); return false
			if int(staff_charges.get(stid, 0)) <= 0: _corner_refuse(kind, "%s has no charges left" % strec["name"]); return false
			var conv: Dictionary = STAFF.get("crowd", {}).get("converts", {}).get(stid, {})
			if conv.size() > 0 and crowd_heat < float(conv.get("needs", 0)):                          # NP_01 s1 / NP_10 s6: Raise the Roof converts crowd heat - no heat, nothing to convert
				_corner_refuse(kind, "the crowd isn't there yet - heat %d of %d" % [int(crowd_heat), int(conv.get("needs", 0))]); return false
			staff_charges[stid] = int(staff_charges[stid]) - 1
			var fx: Dictionary = strec["effect"]
			if fx.has("tension_plus"): _earn_tension(float(fx["tension_plus"]))
			if fx.has("reveal_next"):
				if bool(fmt.get("blind", false)): _corner_refuse(kind, "blind dual - no reveals"); staff_charges[stid] = int(staff_charges[stid]) + 1; return false
				_ev("reveal", {"boss": blineup[_up_slot()]}); _say("THE REVEAL: their next slot is %s" % blineup[_up_slot()])
			for k in fx:
				if k != "tension_plus" and k != "reveal_next": pending_fx[k] = fx[k]
			if conv.size() > 0:
				crowd_heat = maxf(0.0, crowd_heat - float(conv.get("spends", 0))); _ev("crowd", {"heat": crowd_heat, "spent": float(conv.get("spends", 0)), "by": stid}); crowd_spent_dual += float(conv.get("spends", 0))
			var sby := _staff_credit(stid, dw)
			_say("STAFF: %s (%s, %s) - %s" % [strec["name"], strec["role"], staff_name(sby), strec["text"]])
		"talk":                                                                                     # NP_10 s4: Whitlock and the next fighter
			var tup: int = _up_slot()
			var tcard: Dictionary = lineup[tup] if tup < lineup.size() else {}
			var tnm := str(tcard.get("name", ""))
			var tprof := str(tcard.get("talk", ""))
			var topt := str(a.get("option", ""))
			if TALK.is_empty() or tprof == "": _corner_refuse(kind, "no read on %s yet - no talk profile on the card" % tnm); return false
			if bool(corner.get("talked", false)): _corner_refuse(kind, "%s has heard you already this corner" % tnm); return false
			if not TALK.get("approaches", {}).has(topt): _corner_refuse(kind, "no such talk: '%s'" % topt); return false
			var tland := topt == tprof
			var tline := str(TALK.get("lines", {}).get(tnm, {}).get(topt, ""))
			var tpct := float(TALK.get("stat_pct", 5))
			corner["talked"] = true
			if tland: pending_fx["talk"] = {"who": tnm, "pct": tpct}
			_ev("talk", {"who": tnm, "option": topt, "landed": tland, "line": tline})
			_say("WHITLOCK to %s (%s): \"%s\"%s" % [tnm, str(TALK.get("approaches", {}).get(topt, {}).get("label", topt)), tline, (" - it lands: +%d%% for the segment" % int(tpct)) if tland else " - it doesn't reach them; nothing lost"])
		"save_bar":
			if save_bar_next: _corner_refuse(kind, "already holding"); return false
			save_bar_next = true
			_say("SAVE THE BAR: no spending next segment; +%d if it is won anyway" % int(c.get("save_bar_bonus", 5)))
		_:
			_corner_refuse(kind, "unknown action"); return false
	corner["actions_left"] = int(corner["actions_left"]) - 1
	corner["log"].append(kind)
	_ev("corner_action", {"action": kind, "arg": str(a.get("arg", a.get("id", a.get("option", "")))), "left": corner["actions_left"]})
	return true

func _end_dual() -> void:
	if bout.size() > 0: _end_bout(); return
	if exhibit != "": _exhibit_end(); return                                                          # PAC-088: one pair's engagement - the exhibition's verdict and pay are the coordinator's
	# NP_01 s3.3: most DROPS (the score) wins; equal -> segment wins -> counter hits -> the Golden DROP
	var v := "DRAW"; var rung := "score"
	if score_p > score_b: v = "MILLBROOK WINS"
	elif score_b > score_p: v = "ASCENDANT WINS"
	elif seg_wins_p != seg_wins_b: v = ("MILLBROOK" if seg_wins_p > seg_wins_b else "ASCENDANT") + " WINS ON SEGMENTS"; rung = "segment_wins"
	elif counters_p != counters_b: v = ("MILLBROOK" if counters_p > counters_b else "ASCENDANT") + " WINS ON COUNTERS"; rung = "counter_hits"
	elif bool(fmt.get("sudden_death", true)) and not r6:
		_start_r6(); return
	if r6: v += " - GOLDEN DROP"; rung = "sudden_death"
	mode = "OVER"
	_ev("dual_end", {"verdict": v, "rung": rung, "seg_wins": [seg_wins_p, seg_wins_b], "counters": [counters_p, counters_b]})
	_tape_record()                                                                                       # PAC-089: a decoy seal run on the club goes on the tape (the Film Room reads it)
	_pay_dual(v.begins_with("MILLBROOK"))                                                              # the dual pays (its toast precedes the verdict on the feed)
	_recruit_after_dual(v.begins_with("MILLBROOK"))                                                    # NP_08 s2.1: a club beaten flags its named fighters (PAC-075)
	_gw_dual(v.begins_with("MILLBROOK"))                                                               # PAC-079: a poster for a win, a stub for a club faced
	_say("DUAL OVER :: %s   SCORE %d-%d (drops %d-%d)   segments %d-%d   counters %d-%d   EP %d-%d" % [v, score_p, score_b, drops_p, drops_b, seg_wins_p, seg_wins_b, counters_p, counters_b, ep_p, ep_b])

func _exhibit_end() -> void:
	# PAC-088: this pair's engagement is over (the ring clock, or a KO) - it stands, scored, while the other pair fights on; the exhibition's
	# ladder runs on both pairs' sums and pays once, from the coordinator (sim/exhibition.gd)
	mode = "OVER"
	var ko := false
	for i in range(events.size() - 1, -1, -1):                                                         # the segment's end, emitted a moment ago: a KO or the clock
		if str(events[i].get("kind", "")) == "seg_end": ko = str(events[i].get("why", "")).begins_with("SEGMENT KO"); break
	_ev("engagement_end", {"exhibit": exhibit, "who": pname(), "boss": boss_name, "score": [score_p, score_b], "seg_wins": [seg_wins_p, seg_wins_b], "counters": [counters_p, counters_b], "ep": [ep_p, ep_b], "ko": ko})
	_say("PAIR %s DONE :: %s vs %s   SCORE %d-%d   EP %d-%d%s - the exhibition's verdict is both pairs'" % [exhibit, pname(), boss_label, score_p, score_b, ep_p, ep_b, " (a KO: this pair is finished; the other fights on)" if ko else ""])

func freshest(cards: Array, cond: Dictionary) -> int:
	# the dressed fighter in the best condition (composure fraction; an unfought card is whole), first in order on ties
	var best := 0; var best_v := -1.0
	for i in cards.size():
		var nm := str(cards[i]["name"]) if cards[i] is Dictionary else str(cards[i])
		var v := 1.0
		if cond.has(nm):
			var cm: float = float(grown_stats(cards[i])["CHN"]) * 2.0 if cards[i] is Dictionary else 120.0        # PAC-090: his grown CHN
			v = float(cond[nm]["comp"]) / maxf(1.0, cm)
		if v > best_v: best = i; best_v = v
	return best

func _start_r6() -> void:
	# the Golden DROP (s3.3): any dressed fighter, condition carried, no clock, first DROP wins.
	# Both corners pick as they would swap: your default is your freshest card, his is his freshest boss.
	r6 = true; seg_idx = segments()
	while lineup.size() <= seg_idx: lineup.append(dressed[freshest(dressed, condition)])
	while blineup.size() <= seg_idx: blineup.append(bdressed[freshest(bdressed, bcondition)])
	mode = "CARD"; card_t = ms(float(TAC.get("corner", {}).get("card_seconds", 4)) * 1000.0)
	_ev("seg_card", {"seg": seg_idx + 1, "why": "GOLDEN DROP", "won": false, "ep_p": 0, "ep_b": 0, "score_p": score_p, "score_b": score_b, "tension": tension, "banked": 0.0, "charged": charged, "chain": relay_chain, "r6": true})
	_ev("r6", {"default": lineup[seg_idx]["name"], "his_default": blineup[seg_idx]})
	_say("TIED ON THE LADDER - GOLDEN DROP. Send any dressed fighter, condition carried, no clock: the first DROP wins. Your corner's pick: %s" % lineup[seg_idx]["name"])

func new_dual() -> void:
	seal_n += 1                                                                                          # PAC-073: another dual, another seal (his decoy and your read are rolled again)
	_gear_sync()                                                                                         # PAC-094: what the last dual's story, blessings and joins brought to the locker
	_reset_dual(_first_boss)

# ============================ THE INTERRUPT BLOCK (NP_04 s4) ==============
func _string_class(sname: String) -> String:
	return str(pattern.get("strings", {}).get(sname, {}).get("class", "normal"))

func _interrupt_block(sname: String) -> Dictionary:
	# the pattern's INTERRUPT entry that lists this string -> {stagger_ms, desync_s, tension_bonus}; {} when none does
	for ib in pattern.get("interrupt", []):
		if sname in ib.get("strings", []):
			var out := {"stagger_ms": float(REMIX.get("stagger_ms_default", 800)), "desync_s": 0.0, "tension_bonus": false}
			var resp := str(ib.get("response", ""))
			var rx := RegEx.new(); rx.compile("stagger\\((\\d+)")
			var m := rx.search(resp)
			if m: out["stagger_ms"] = float(m.get_string(1))
			var rx2 := RegEx.new(); rx2.compile("desync\\(([\\d\\.]+)s?\\)")
			var m2 := rx2.search(resp)
			if m2: out["desync_s"] = float(m2.get_string(1))
			out["tension_bonus"] = "tension_bonus" in resp
			return out
	return {}

func _interruptible(sname: String) -> bool:
	# NP_04 s4: only the strings the pattern tags INTERRUPT break; ARMORED never does ("you dodge this, you don't stop it")
	if sname == "" or not pattern.get("strings", {}).has(sname): return false
	if _string_class(sname) == "ARMORED": return false
	if pattern.get("interrupt", []).is_empty(): return true                     # no block authored: everything breaks (none of the 24)
	return not _interrupt_block(sname).is_empty()

func interrupt_coverage(pats: Dictionary) -> Dictionary:
	# static, for the smoke: per pattern, which strings break and which do not
	var saved := pattern
	var out := {}
	for name in pats:
		pattern = pats[name]
		var brk: Array = []; var no: Array = []
		for k in pattern.get("strings", {}):
			if _interruptible(str(k)): brk.append(str(k))
			else: no.append(str(k) + (" [ARMORED]" if _string_class(str(k)) == "ARMORED" else ""))
		out[name] = {"breaks": brk, "holds": no}
	pattern = saved
	return out

# ============================ THE PHASE SCRIPTS (NP_04 s7, NP_04A/B) ======
static func _fresh_mods() -> Dictionary:
	return {"speed": 1.0, "dmg": 1.0, "body_dmg": 1.0, "move": 1.0, "metronome_ms": 0.0, "tempos": [], "splice_every": 0, "splice_open_ms": 500.0,
		"state_ms": {}, "cooldown_ms": {}, "select_drift": "", "pull_all": false, "punish_cd_mult": 1.0, "tier_shift": 0,
		"herd_mult": 1.0, "pi_transfer_pct": 0.0, "pi_scale": 1.0, "pi_override": -1, "recover_ms": 0.0, "secret_power": 1.0, "stumble_ms": 0.0,
		"desp_requires": "", "corner_intel_s": 0.0, "corner_assist": "", "target_body_pct": 0.0, "seam_ms": 700.0, "desync_default_ms": 0.0}

func _declare_bases() -> void:
	# the compiled META carries the values the phase lines move from: Ada's metronome, Chiamaka's two tempos, Echo's splice
	var bm: Dictionary = pattern.get("meta", {})
	if bm.has("metronome_ms"): bmods["metronome_ms"] = float(bm["metronome_ms"])
	if bm.has("metronomes_ms"):
		var tl: Array = []
		for t in str(bm["metronomes_ms"]).split(","): tl.append(float(t))
		bmods["tempos"] = tl
	if bm.has("splice_every"): bmods["splice_every"] = int(bm["splice_every"])
	if bm.has("splice_open_ms"): bmods["splice_open_ms"] = float(bm["splice_open_ms"])
	# the SELECT block's static lines: "punish_only: w(S3)=0" (Ada's SwarmProtocol comes only through a hook)
	var rx := RegEx.new(); rx.compile("^punish_only:\\s*w\\((\\w+)\\)\\s*=\\s*(\\d+)$")
	for line in pattern.get("select", {}).get("reweights", []):
		var m := rx.search(str(line))
		if m and pattern["strings"].has(m.get_string(1)): pattern["select"]["weights"][m.get_string(1)] = int(m.get_string(2))
	# the SELECT block's conditional lines (NP_04A): a weight while a condition holds, a weight for N s after an event, a speed under the clock
	bselect_lines = []
	var rw := RegEx.new(); rw.compile("^(after_hit_taken|target_zone==ROPES|zone==ROPES|player_passive>(\\d+)s):\\s*w\\((\\w+)\\)\\+=(\\d+)(?:\\s+for\\s+(\\d+)s)?$")
	var rs := RegEx.new(); rs.compile("^(segment_clock<(\\d+)s|clock>(\\d+)s):\\s*all_speed x([\\d\\.]+)$")
	for line in pattern.get("select", {}).get("reweights", []):
		var mw := rw.search(str(line))
		if mw and pattern["strings"].has(mw.get_string(3)):
			var cond := mw.get_string(1)
			var rec := {"cond": "passive" if cond.begins_with("player_passive") else ("ropes" if "ROPES" in cond else "after_hit"), "string": mw.get_string(3), "delta": int(mw.get_string(4)), "secs": float(mw.get_string(5)) if mw.get_string(5) != "" else 0.0, "arg": float(mw.get_string(2)) if mw.get_string(2) != "" else 0.0, "line": str(line)}
			bselect_lines.append(rec); continue
		var ms_ := rs.search(str(line))
		if ms_:
			bselect_lines.append({"cond": "clock_left" if ms_.get_string(2) != "" else "clock_gone", "arg": float(ms_.get_string(2) if ms_.get_string(2) != "" else ms_.get_string(3)), "mult": float(ms_.get_string(4)), "line": str(line)})
	# the META keys with a mechanic behind them (NP_04A / NP_04B)
	if bm.has("herding_bonus"): bmods["herd_mult"] = 1.0 + float(str(bm["herding_bonus"]).replace("pct", "")) / 100.0      # Alfie: +75% push
	if bm.has("pi_transfer"): bmods["pi_transfer_pct"] = float(bm["pi_transfer"])                                       # Vey: a real house's PI at half against the matching kit
	if bm.has("pi_override"): bmods["pi_override"] = int(bm["pi_override"])                                             # the Cartographer: PI stripped
	if bm.has("no_idle_weight"): bmods["recover_ms"] = 150.0                                                            # Deshawn: no neutral game
	if bm.has("secret_power"): bmods["secret_power"] = float(bm["secret_power"]); bmods["stumble_ms"] = 500.0             # Osei: the half-learned secret and its stumble
	if bm.has("graduacion_requires"): bmods["desp_requires"] = str(bm["graduacion_requires"]).replace("_landed", "")    # Baro: no Graduacion before Examen lands
	if bm.has("corner_intel"):                                                                                          # Vasile: Vey in your corner calls the swap N s early
		var rxi := RegEx.new(); rxi.compile("(\\d+)s"); var mi := rxi.search(str(bm["corner_intel"]))
		bmods["corner_intel_s"] = float(mi.get_string(1)) if mi else 2.0
	if bm.has("corner_assist"): bmods["corner_assist"] = str(bm["corner_assist"]).split("_")[0]                         # Cal: Whitlock's calls name the string
	if bm.has("target_split"):                                                                                          # Reyes: body 80 / head 20
		var rxt := RegEx.new(); rxt.compile("body(\\d+)"); var mt := rxt.search(str(bm["target_split"]))
		bmods["target_body_pct"] = float(mt.get_string(1)) / 100.0 if mt else 0.0
	if bm.has("extraction_fingerprint"): bmods["pi_scale"] = 0.5                                                        # Remy: the dialect half-transfers
	if bm.has("kit_swap_reset_ms"): bmods["seam_ms"] = float(bm["kit_swap_reset_ms"])
	if bm.has("desync_reform_s"): bmods["desync_default_ms"] = float(bm["desync_reform_s"]) * 1000.0
	elif bm.has("desync_s"): bmods["desync_default_ms"] = float(bm["desync_s"]) * 1000.0

func _apply_meta_kit(kit: String) -> void:
	# the kit he opens in when his META style / element are not the phase-1 kit (Vey: BOXERPUNCHER / varies, opening Out-Boxer / Frost)
	var kp := _kit_parts(kit)
	_dress(B, kp[0] if kp[0] != "" else str(B["style"]), kp[1] if kp[1] != "" else str(B["element"]), str(B["house"]))

static func _kit_parts(kit: String) -> Array:
	# "outboxer_frost" -> [style part, element part] ("" where the kit names none)
	var kst := ""; var kel := ""
	for pp in kit.split("_"):
		if str(pp).to_upper() == "BOXERPUNCHER" or style_key(str(pp)) != "BOXERPUNCHER": kst = str(pp)
		if element_key(str(pp)) != "NONE": kel = str(pp)
	return [kst, kel]

func _string_phase(sname: String) -> int:
	for t in pattern["strings"][sname]["tags"]:
		if str(t).begins_with("phase>="): return int(str(t).split(">=")[1])
	return 1

func _set_retired(sname: String, retired: bool) -> void:
	var tags: Array = pattern["strings"][sname]["tags"]
	while "retired" in tags: tags.erase("retired")
	if retired: tags.append("retired")

func _redress(F: Dictionary, style: String, element: String) -> void:
	# a kit swap mid-segment: the rings and the package change, the fighter's condition stays as a fraction of the new pools
	var cf: float = float(F["comp"]) / maxf(1.0, float(F["comp_max"])); var gf: float = float(F["guard"]) / maxf(1.0, float(F["guard_max"]))
	var g: Dictionary = T["guard"]["capacity_by_BLK"]
	F["style"] = style_key(style); F["element"] = element_key(element)
	F["pkg"] = AFF.get("style", {}).get("packages", {}).get(F["style"], {}).duplicate()
	F["comp_max"] = float(F["stats"]["CHN"]) * 2.0 * float(F["pkg"].get("comp_pool_mult", 1.0)); F["comp"] = cf * float(F["comp_max"])
	F["guard_max"] = lerpf(float(g["min"]), float(g["max"]), float(F["stats"]["BLK"]) / 99.0) * float(F["pkg"].get("guard_cap_mult", 1.0)); F["guard"] = gf * float(F["guard_max"])

func _apply_phase_reweights(n: int) -> Array:
	# the SELECT block's "phase==N: w(X)=a w(Y)+=b" lines, applied when phase N arrives (phase>=N lines too)
	var applied: Array = []
	var rx := RegEx.new(); rx.compile("^phase(==|>=)(\\d+):\\s*(.*)$")
	var rw := RegEx.new(); rw.compile("w\\((\\w+)\\)\\s*(\\+=|=)\\s*(\\d+)")
	for line in pattern.get("select", {}).get("reweights", []):
		var m := rx.search(str(line))
		if m == null: continue
		var want := int(m.get_string(2))
		if (m.get_string(1) == "==" and n != want) or (m.get_string(1) == ">=" and n < want): continue
		for wm in rw.search_all(m.get_string(3)):
			var k := wm.get_string(1)
			if not pattern["strings"].has(k): continue
			var w: Dictionary = pattern["select"]["weights"]
			w[k] = (int(w.get(k, 0)) if wm.get_string(2) == "+=" else 0) + int(wm.get_string(3))
		applied.append(str(line))
	return applied

func reweight_coverage(pats: Dictionary) -> Dictionary:
	# static, for the smoke: the SELECT reweight lines the phase machinery executes, and the ones carried
	var done: Array = []; var carried: Array = []
	var rx := RegEx.new(); rx.compile("^(phase(==|>=)(\\d+)|punish_only):")
	for name in pats:
		for line in pats[name].get("select", {}).get("reweights", []):
			if rx.search(str(line)): done.append("%s: %s" % [name, str(line)])
			else: carried.append("%s: %s" % [name, str(line)])
	return {"executed": done, "carried": carried}

func _kit_swap(style: String, element: String, label: String) -> String:
	# NP_04A s8 / NP_04B: the kit is the phase's string set; the rings turn live and the matchup card is read again
	for k in pattern["strings"]: _set_retired(str(k), _string_phase(str(k)) != bphase)
	_apply_phase_reweights(bphase)
	if style != "" or element != "": _redress(B, style if style != "" else str(B["style"]), element if element != "" else str(B["element"]))
	_matchup(true)
	_ev("kit_swap", {"phase": bphase, "label": label, "style": B["style"], "element": B["element"]})
	return "%s: %s / %s" % [label, B["style"], B["element"]]

func _neutral_reset(ms_v: float) -> void:
	# Vasile's seam: a fixed reset to neutral at every kit swap - both fighters apart at range, he is idle for the whole of it
	var mid: Vector2 = (P["pos"] + B["pos"]) * 0.5
	var dir: Vector2 = (B["pos"] - P["pos"]).normalized()
	if dir.length() < 0.5: dir = Vector2(0, -1)
	P["pos"] = mid - dir * 0.9; B["pos"] = mid + dir * 0.9; _clamp(P); _clamp(B)
	bstate = "IDLE"; btimer = ms(ms_v); bqueue = []; bforce_opts = {}; bfeint = ""
	B["pending"] = {}; B["busy_t"] = 0
	B.erase("boxing")
	_ev("neutral_reset", {"ms": ms_v}); _say("the kit turns - a %dms seam, he resets to neutral" % int(ms_v))

func _tier_shift(n: int) -> void:
	# a tell tier is a band (NP_04 s3: Subtle 400-500, Standard 450-700, Loud 600-1200); one tier is 150ms, floored by class
	for k in pattern["strings"]: _set_tell(str(k), minf(1200.0, float(pattern["strings"][k]["tell"]["ms"]) + 150.0 * n))
	bmods["tier_shift"] = int(bmods["tier_shift"]) + n

func _is_fundamental(sname: String) -> bool:
	# Kannagi's lesson: straights, steps and the waiting guard - nothing that loops
	for a in pattern["strings"][sname]["actions"]:
		for act in parse_action(str(a)):
			if str(act["kind"]) == "punch" and _punch_family(str(act["row"])) != "STRAIGHT": return false
	return true

func _select_weights() -> Dictionary:
	# the live SELECT: phase-gated, retired and cooled-down strings out, the authored default for the rest, the recognition drift on top
	var w: Dictionary = {}
	for k in pattern["select"]["weights"]:
		if k in pattern["strings"] and _phase_ok(k) and int(pattern["select"]["weights"][k]) > 0: w[k] = int(pattern["select"]["weights"][k])
	for k in pattern["strings"]:
		if not k in w and _phase_ok(k) and not pattern["select"]["weights"].has(k): w[k] = 15
	for k in w.keys():
		if int(bcooldown_until.get(k, -1)) > tick: w.erase(k)
		elif not _zone_ok(k): w.erase(k)
	for ln in bselect_lines:                                                     # the SELECT block's conditional lines (Moira / Alfie on the ropes, Marta's patience, Yuri's after-hit)
		if not ln.has("string") or not w.has(ln["string"]): continue
		match str(ln["cond"]):
			"ropes": if _on_ropes(P["pos"]): w[ln["string"]] = int(w[ln["string"]]) + int(ln["delta"])
			"passive": if passive_t >= ms(float(ln["arg"]) * 1000.0): w[ln["string"]] = int(w[ln["string"]]) + int(ln["delta"])
	for tr in btransient:
		if int(tr["until"]) > tick and w.has(tr["string"]): w[tr["string"]] = int(w[tr["string"]]) + int(tr["delta"])
	if str(bmods["select_drift"]).begins_with("recognition") and w.size() > 0:
		var best := ""; var best_n := 0
		for k in w:
			if int(breads.get(k, 0)) > best_n: best_n = int(breads.get(k, 0)); best = str(k)
		if best != "": w[best] = int(w[best]) + 25
	return w

func _on_ropes(pos: Vector2) -> bool:
	var z := zone(pos)
	return z == "ROPES" or z == "CORNER"

func _zone_ok(sname: String) -> bool:
	# a string tagged zone==ROPES / target_zone==ROPES is only for a player on the ropes (Moira's Gaff, Alfie's Sunday Best)
	for t in pattern["strings"][sname]["tags"]:
		if str(t) == "zone==ROPES" or str(t) == "target_zone==ROPES": return _on_ropes(P["pos"])
	return true

func _bspeed() -> float:
	# the phase lines' speed times the SELECT block's clock lines (Carter's last 30s, Sam's minute)
	var m := float(bmods["speed"])
	var elapsed := ms(float(fmt.get("segment_s", 90)) * 1000.0) - clock_t
	for ln in bselect_lines:
		match str(ln["cond"]):
			"clock_left": if clock_t < ms(float(ln["arg"]) * 1000.0): m *= float(ln["mult"])
			"clock_gone": if elapsed > ms(float(ln["arg"]) * 1000.0): m *= float(ln["mult"])
	return m

func _on_hit_taken() -> void:
	# the SELECT block's "after_hit_taken: w(S)+=N for Ms" (Yuri leans on Freight after he is hit)
	for ln in bselect_lines:
		if str(ln["cond"]) != "after_hit": continue
		var found := false
		for tr in btransient:
			if str(tr["string"]) == str(ln["string"]): tr["until"] = tick + ms(float(ln["secs"]) * 1000.0); found = true
		if not found: btransient.append({"string": ln["string"], "delta": int(ln["delta"]), "until": tick + ms(float(ln["secs"]) * 1000.0)})

func _desperation_allowed() -> bool:
	# Baro's Graduacion comes only after his Examen lands (META graduacion_requires: examen_landed)
	var req := str(bmods["desp_requires"])
	if req == "": return true
	for k in pattern["strings"]:
		if str(pattern["strings"][k].get("label", "")).to_lower() == req.to_lower() or str(k).to_lower() == req.to_lower(): return int(blanded.get(k, 0)) > 0
	return true

func _corner_intel_tick() -> void:
	# Vasile's corner intel: Vey in your corner calls a clock kit swap N s before it comes ("Standard's turning granite - NOW")
	if float(bmods["corner_intel_s"]) <= 0.0: return
	var phases: Array = pattern.get("phases", [])
	var elapsed := ms(float(fmt.get("segment_s", 90)) * 1000.0) - clock_t
	for pi_ in phases.size():
		var ph: Dictionary = phases[pi_]
		var target := pi_ + 2
		if str(ph["phase"]).is_valid_int(): target = int(ph["phase"])
		if target <= bphase or target in bcalled_phases: continue
		var trig := str(ph["trigger"])
		if not "clock>" in trig: continue
		var at_s := float(trig.split("clock>")[1].rstrip("s").split(" ")[0])
		if elapsed >= ms((at_s - float(bmods["corner_intel_s"])) * 1000.0):
			var kit := ""
			for d in ph.get("directives", []):
				if str(d).begins_with("kit_swap "): kit = str(d).substr(9)
			bcalled_phases.append(target)
			_ev("corner_call", {"phase": target, "in_s": float(bmods["corner_intel_s"]), "kit": kit, "text": "Standard's turning %s - NOW" % kit})
			_say("VEY (your corner): Standard's turning %s - NOW" % kit)

func _transfer_dialect() -> String:
	# Vey's kit copies a real house: the roster boss whose style and element match the kit he wears now, if that boss has a House
	if float(bmods["pi_transfer_pct"]) <= 0.0: return ""
	for name in patterns:
		if name == boss_name: continue
		var m: Dictionary = patterns[name].get("meta", {})
		if style_key(str(m.get("style", ""))) == str(B["style"]) and element_key(str(m.get("element", ""))) == str(B["element"]) and house_key(str(m.get("house", "none"))) != "none": return house_key(str(m.get("house", "none")))
	return ""

func pattern_coverage(pats: Dictionary) -> Dictionary:
	# static, for the smoke: every META key, SELECT line, directive, tag and idle line of the 24 - executed, presentational, or carried
	const META_EXEC := ["style", "element", "house", "slot", "warnings_banked", "wall_gauge", "gauge_reforms", "migrant_wall", "migrates_to_next_at", "metronome_ms", "metronomes_ms",
		"desync_s", "desync_value", "desync_reform_s", "splice_every", "splice_open_ms", "kit_swap_reset_ms", "herding_bonus", "pi_transfer", "pi_override", "no_idle_weight",
		"secret_power", "graduacion_requires", "corner_intel", "corner_assist", "target_split", "extraction_fingerprint", "kit", "generic", "tier", "dialect"]
	const META_PRES := ["arc", "authored_loss", "blind_dual", "unsanctioned", "control_group", "remix", "commentary_mute_on_hit", "seed", "pieces", "label"]
	const TAG_EXEC := ["SPECIAL", "ARMORED", "retired", "zone==ROPES", "target_zone==ROPES"]
	var out := {"meta": {"executed": [], "presentational": [], "carried": []}, "select": {"executed": [], "carried": []}, "directives": {"executed": [], "carried": []}, "tags": {"executed": [], "carried": []}, "idle": {"executed": [], "presentational": [], "carried": []}}
	var rsel := RegEx.new(); rsel.compile("^(phase(==|>=)\\d+|punish_only|after_hit_taken|target_zone==ROPES|zone==ROPES|player_passive>\\d+s|segment_clock<\\d+s|clock>\\d+s):")
	var saved := pattern; var saved_mods := bmods.duplicate(true); var saved_des := bdesync_ms
	for name in pats:
		var pat: Dictionary = pats[name]
		for k in pat.get("meta", {}):
			var entry := "%s: %s" % [name, str(k)]
			if str(k) in META_EXEC: out["meta"]["executed"].append(entry)
			elif str(k) in META_PRES: out["meta"]["presentational"].append(entry)
			else: out["meta"]["carried"].append(entry)
		for line in pat.get("select", {}).get("reweights", []):
			var entry2 := "%s: %s" % [name, str(line)]
			if rsel.search(str(line)): out["select"]["executed"].append(entry2)
			else: out["select"]["carried"].append(entry2)
		pattern = pat.duplicate(true)
		for ph in pattern.get("phases", []):
			for d in ph.get("directives", []):
				var entry3 := "%s: %s" % [name, str(d)]
				if apply_directive(str(d)): out["directives"]["executed"].append(entry3)
				else: out["directives"]["carried"].append(entry3)
		for k in pat.get("strings", {}):
			for t in pat["strings"][k].get("tags", []):
				var entry4 := "%s: %s [%s]" % [name, str(t), str(k)]
				if str(t) in TAG_EXEC or str(t).begins_with("phase>=") or str(t).begins_with("STATE="): out["tags"]["executed"].append(entry4)
				else: out["tags"]["carried"].append(entry4)
		for il in pat.get("idle", []):                                                          # PAC-071: the neutral game's vocabulary decides
			var vr: Dictionary = NEUTRAL.get("verbs", {}).get(idle_verb(str(il)), {})
			var entry5 := "%s: %s" % [name, str(il)]
			if vr.is_empty(): out["idle"]["carried"].append(entry5)
			elif bool(vr.get("presentational", false)): out["idle"]["presentational"].append(entry5)
			else: out["idle"]["executed"].append(entry5)
	pattern = saved; bmods = saved_mods; bdesync_ms = saved_des
	return out

# ============================ PHASE DIRECTIVES / REMIX OPERATORS (NP_04 s6) ======
func _tell_floor(cls: String) -> float:
	return float(REMIX.get("floors_ms", {}).get(cls, 400.0 if cls == "normal" else (700.0 if cls == "SPECIAL" else 1000.0)))

func _set_tell(sname: String, ms_v: float) -> void:
	# a tell is never set under its class floor (NP_04 s1's fair minimums)
	var st: Dictionary = pattern["strings"][sname]
	st["tell"]["ms"] = maxf(_tell_floor(str(st.get("class", "normal"))), ms_v)

func apply_directive(text: String) -> bool:
	# executes one phase-directive line on the live pattern; false = carried, not executed
	var t := text.strip_edges()
	var rx := RegEx.new(); rx.compile("^speed x([\\d\\.]+)$")
	var m := rx.search(t)
	if m: bmods["speed"] = float(m.get_string(1)); return true
	rx = RegEx.new(); rx.compile("^tighten\\((\\w+),\\s*(\\d+)ms\\)$"); m = rx.search(t)
	if m and pattern["strings"].has(m.get_string(1)): _set_tell(m.get_string(1), float(m.get_string(2))); return true
	rx = RegEx.new(); rx.compile("^(tighten_all_tells|tells) -(\\d+)ms"); m = rx.search(t)
	if m:
		for k in pattern["strings"]: _set_tell(str(k), float(pattern["strings"][k]["tell"]["ms"]) - float(m.get_string(2)))
		return true
	rx = RegEx.new(); rx.compile("^([\\w,]+) tell -(\\d+)ms"); m = rx.search(t)
	if m:
		var any := false
		for k in m.get_string(1).split(","):
			if pattern["strings"].has(k): _set_tell(k, float(pattern["strings"][k]["tell"]["ms"]) - float(m.get_string(2))); any = true
		if any: return true
	rx = RegEx.new(); rx.compile("^add (\\w+)$"); m = rx.search(t)
	if m and pattern["strings"].has(m.get_string(1)):
		var tags: Array = pattern["strings"][m.get_string(1)]["tags"]
		for i in range(tags.size() - 1, -1, -1):
			if str(tags[i]).begins_with("phase>=") or str(tags[i]) == "retired": tags.remove_at(i)
		return true
	rx = RegEx.new(); rx.compile("^retire (\\w+)$"); m = rx.search(t)
	if m and pattern["strings"].has(m.get_string(1)):
		pattern["strings"][m.get_string(1)]["tags"].append("retired"); return true
	rx = RegEx.new(); rx.compile("^w\\((\\w+)\\)\\s*(\\+=|=)\\s*(\\d+)$"); m = rx.search(t)
	if m and pattern["strings"].has(m.get_string(1)):
		var w: Dictionary = pattern["select"]["weights"]
		w[m.get_string(1)] = (int(w.get(m.get_string(1), 0)) if m.get_string(2) == "+=" else 0) + int(m.get_string(3)); return true
	rx = RegEx.new(); rx.compile("^(all_damage|strength|all_body_damage|movement) \\+(\\d+)pct"); m = rx.search(t)
	if m:
		var f := 1.0 + float(m.get_string(2)) / 100.0
		match m.get_string(1):
			"all_damage", "strength": bmods["dmg"] = float(bmods["dmg"]) * f
			"all_body_damage": bmods["body_dmg"] = float(bmods["body_dmg"]) * f
			"movement": bmods["move"] = float(bmods["move"]) * f
		return true
	rx = RegEx.new(); rx.compile("^desync ([\\d\\.]+)s->([\\d\\.]+)s$"); m = rx.search(t)
	if m: bdesync_ms = float(m.get_string(2)) * 1000.0; return true
	# ---- the bosses' own mechanics (NP_04A / NP_04B), one line each ----
	rx = RegEx.new(); rx.compile("^corner_call_volume -(\\d+)_tier$"); m = rx.search(t)                  # Vane: they start hiding the calls
	if m:
		# NP-04A Cassidy: hide the AUDIO call one volume tier, not 150ms
		# of the player's reaction window. Cal's tell-tier directive below
		# still owns its explicit timing change.
		bmods["corner_call_tier"] = int(bmods.get("corner_call_tier", 0)) - int(m.get_string(1))
		return true
	rx = RegEx.new(); rx.compile("^tells_louden \\+(\\d+)_tier$"); m = rx.search(t)                     # Cal: the memory gets louder
	if m: _tier_shift(int(m.get_string(1))); return true
	rx = RegEx.new(); rx.compile("^metronome (\\d+)ms->(\\d+)ms$"); m = rx.search(t)                    # Ada: the beat tightens
	if m: bmods["metronome_ms"] = float(m.get_string(2)); return true
	rx = RegEx.new(); rx.compile("^tempos ([\\d,]+) -> ([\\d,]+)$"); m = rx.search(t)                  # Chiamaka: both beats tighten
	if m:
		var tl: Array = []
		for tv in m.get_string(2).split(","): tl.append(float(tv))
		bmods["tempos"] = tl; btempo_i = 0; return true
	if t == "dirty_flirtation_stops": bmods["pull_all"] = true; return true                              # Alfie: banked two, pulls the rest
	rx = RegEx.new(); rx.compile("^kit_swap (\\w+)$"); m = rx.search(t)                                  # Vey / Vasile: the kit is the phase's
	if m:
		var parts := m.get_string(1).split("_")
		var st := ""; var el := ""
		for pp in parts:
			if style_key(str(pp)) != "BOXERPUNCHER" or str(pp).to_upper() == "BOXERPUNCHER": st = str(pp)
			if element_key(str(pp)) != "NONE": el = str(pp)
		_kit_swap(st, el, m.get_string(1)); return true
	rx = RegEx.new(); rx.compile("^dialect_swap (\\w+)$"); m = rx.search(t)                             # the Cartographer: an erased house's dialect, one per phase
	if m:
		_kit_swap("", "", m.get_string(1)); bdialect = m.get_string(1)
		_ev("dialect_swap", {"dialect": bdialect, "phase": bphase}); return true
	rx = RegEx.new(); rx.compile("^(\\w+) gains_second_body_hook$"); m = rx.search(t)                  # Carter
	if m and pattern["strings"].has(m.get_string(1)): pattern["strings"][m.get_string(1)]["actions"].append("LT_R_HOOK"); return true
	rx = RegEx.new(); rx.compile("^(\\w+) gains_fifth_hit$"); m = rx.search(t)                         # Deshawn
	if m and pattern["strings"].has(m.get_string(1)):
		var acts: Array = pattern["strings"][m.get_string(1)]["actions"]
		var grown := false
		for i in acts.size():
			var rxm := RegEx.new(); rxm.compile("^MIXED_STRING\\((\\d+)\\)$")
			var mm := rxm.search(str(acts[i]))
			if mm: acts[i] = "MIXED_STRING(%d)" % (int(mm.get_string(1)) + 1); grown = true; break
		if not grown: acts.append("R_STR")
		return true
	rx = RegEx.new(); rx.compile("^(\\w+) state (\\d+)s->(\\d+)s$"); m = rx.search(t)               # Osei: the Shell holds longer
	if m and pattern["strings"].has(m.get_string(1)): bmods["state_ms"][m.get_string(1)] = float(m.get_string(3)) * 1000.0; return true
	rx = RegEx.new(); rx.compile("^(\\w+) duration \\+(\\d+)s$"); m = rx.search(t)                  # Marta: the Mirror holds longer
	if m and pattern["strings"].has(m.get_string(1)):
		bmods["state_ms"][m.get_string(1)] = _state_ms_of(m.get_string(1)) + float(m.get_string(2)) * 1000.0; return true
	rx = RegEx.new(); rx.compile("^(\\w+) cooldown_after_use (\\d+)s$"); m = rx.search(t)            # Marta: greedy, then burned out
	if m and pattern["strings"].has(m.get_string(1)): bmods["cooldown_ms"][m.get_string(1)] = float(m.get_string(2)) * 1000.0; return true
	rx = RegEx.new(); rx.compile("^splice_every (\\d+)->(\\d+)$"); m = rx.search(t)                  # Echo: the splice shows less often
	if m: bmods["splice_every"] = int(m.get_string(2)); return true
	rx = RegEx.new(); rx.compile("^neutral_reset\\((\\d+)ms\\)$"); m = rx.search(t)                  # Vasile: the seam
	if m: _neutral_reset(float(m.get_string(1))); return true
	if t == "fundamentals_only":                                                                          # Vasile's finale: Kannagi's lesson
		for k in pattern["strings"]: _set_retired(str(k), not _is_fundamental(str(k)))
		_redress(B, str(B["style"]), "NONE"); _matchup(true)
		_ev("fundamentals_only", {"live": _select_weights().keys()}); return true
	rx = RegEx.new(); rx.compile("^(\\w+)_dialogue_active$"); m = rx.search(t)                        # Cal / Remy: dialogue inside the segment
	if m: bdialogue = m.get_string(1); _ev("dialogue", {"which": bdialogue, "phase": bphase}); return true      # ("kind" is the event's own key)
	rx = RegEx.new(); rx.compile("^select_drift (\\w+)$"); m = rx.search(t)                            # Cal: recognized over winning
	if m: bmods["select_drift"] = m.get_string(1); return true
	if t == "no_changes_by_design": _ev("no_changes", {"phase": bphase}); return true                     # Sora: the control group, by name
	if t == "true_pattern_only": btrue_pattern = true; return true                                       # Tam: the coat comes off
	if t == "corrections_narrated_faster": bmods["punish_cd_mult"] = 0.5; return true                     # Baro: the corrections come twice as often
	return false

func _state_ms_of(sname: String) -> float:
	# the authored COUNTER_STATE duration of a string (Osei's Shell 3s, Marta's Mirror 2.5s), the executor's base
	if bmods["state_ms"].has(sname): return float(bmods["state_ms"][sname])
	for a in pattern["strings"][sname]["actions"]:
		for act in parse_action(str(a)):
			if str(act["kind"]) == "counter_state": return float(act["t"]) * 1000.0 / float(TICK_HZ)
	return 2000.0

func _override_states(sname: String) -> void:
	# a phase line moved this string's state duration: the queued counter_state carries it
	if not bmods["state_ms"].has(sname): return
	for act in bqueue:
		if str(act.get("kind", "")) == "counter_state": act["t"] = ms(float(bmods["state_ms"][sname]))

func _apply_directives(lines: Array, where: String) -> void:
	for d in lines:
		var ok := apply_directive(str(d))
		if ok: directives_done.append(str(d))
		else: directives_carried.append(str(d))
		_ev("directive", {"text": str(d), "where": where, "executed": ok})

func directive_coverage(pats: Dictionary) -> Dictionary:
	# static, for the smoke: which authored phase-directive lines execute and which are carried
	var saved := pattern; var saved_mods := bmods.duplicate(); var saved_des := bdesync_ms
	var done: Array = []; var carried: Array = []
	for name in pats:
		pattern = pats[name].duplicate(true)
		for ph in pattern.get("phases", []):
			for d in ph.get("directives", []):
				if apply_directive(str(d)): done.append("%s: %s" % [name, str(d)])
				else: carried.append("%s: %s" % [name, str(d)])
	pattern = saved; bmods = saved_mods; bdesync_ms = saved_des
	return {"executed": done, "carried": carried}

# ============================ THE REMATCH REMIX (NP_04 s6) =================
func set_remix(boss: String, rid: String) -> bool:
	# choose a remix for a boss; "" restores the original. Applies at his next load
	if rid == "": remix_for.erase(boss); return true
	var rec: Dictionary = REMIX.get("remixes", {}).get(rid, {})
	if rec.is_empty() or str(rec.get("base", "")) != boss: return false
	remix_for[boss] = rid
	return true

func remixes_of(boss: String) -> Array:
	var out: Array = []
	for rid in REMIX.get("remixes", {}):
		if str(REMIX["remixes"][rid].get("base", "")) == boss: out.append(str(rid))
	out.sort()
	return out

func _apply_remix(rid: String) -> void:
	# the ops over the duplicated pattern already in `pattern`; the original in `patterns` is never touched
	var rec: Dictionary = REMIX.get("remixes", {}).get(rid, {})
	if rec.is_empty() or str(rec.get("base", "")) != boss_name: return
	var notes: Array = []
	for op in rec.get("ops", []):
		var note := _apply_op(op)
		if note != "": notes.append(note)
	bremix = {"id": rid, "label": str(rec.get("label", rid)), "notes": notes}
	_ev("remix", {"id": rid, "boss": boss_name, "notes": notes})
	_say("REMATCH REMIX - %s :: %s" % [bremix["label"], " | ".join(PackedStringArray(notes))])

func _apply_op(op: Dictionary) -> String:
	var kind := str(op.get("op", ""))
	var sname := str(op.get("string", "")) if op.get("string") is String else ""
	match kind:
		"feint":
			if not pattern["strings"].has(sname): return ""
			var fd: Dictionary = REMIX.get("feint", {})
			var prev: Dictionary = pattern["strings"][sname].get("feint", {})
			var fv := {"mode": str(op.get("mode", "delay")), "into": str(op.get("into", "")), "ms": float(op.get("ms", fd.get("delay_ms", 300))), "pct": float(op.get("pct", fd.get("pct", 0.4))), "burn_after": int(prev.get("burn_after", 0))}
			pattern["strings"][sname]["feint"] = fv
			return "%s feints (%s, %d%%)" % [sname, ("%d ms late" % int(fv["ms"])) if fv["mode"] == "delay" else ("into " + str(fv["into"])), int(round(float(fv["pct"]) * 100.0))]
		"tighten":
			if not pattern["strings"].has(sname): return ""
			_set_tell(sname, float(op.get("ms", 0)))
			return "%s tell %d ms" % [sname, int(pattern["strings"][sname]["tell"]["ms"])]
		"reweight":
			var parts: Array = []
			for k in op.get("weights", {}):
				if pattern["strings"].has(str(k)): pattern["select"]["weights"][str(k)] = int(op["weights"][k]); parts.append("%s %d" % [str(k), int(op["weights"][k])])
			return "weights " + " / ".join(PackedStringArray(parts))
		"newstring":
			var name := str(op.get("name", ""))
			if name == "" or not (op.get("string") is Dictionary): return ""
			var st: Dictionary = op["string"].duplicate(true)
			if not st.has("tags"): st["tags"] = []
			if not st.has("class"): st["class"] = "normal"
			if not st.has("tell"): st["tell"] = {"motif": "", "ms": 0}
			pattern["strings"][name] = st
			_set_tell(name, float(st["tell"].get("ms", 0)))
			pattern["select"]["weights"][name] = int(op.get("weight", 15))
			if bool(op.get("interruptible", false)):
				if pattern.get("interrupt", []).is_empty(): pattern["interrupt"] = [{"strings": [], "response": "stagger(800)"}]
				pattern["interrupt"][0]["strings"].append(name)
			return "new string %s '%s' (%d ms tell, weight %d)" % [name, str(st.get("label", name)), int(st["tell"]["ms"]), int(op.get("weight", 15))]
		"phase_shift":
			for ph in pattern.get("phases", []):
				if str(ph.get("phase", "")) == str(op.get("phase", "")):
					ph["trigger"] = str(op.get("trigger", ph.get("trigger", "")))
					return "phase %s now at %s" % [str(ph["phase"]), str(ph["trigger"])]
			return ""
		"burn":
			if not pattern["strings"].has(sname): return ""
			if not pattern["strings"][sname].has("feint"):
				var fd2: Dictionary = REMIX.get("feint", {})
				pattern["strings"][sname]["feint"] = {"mode": "delay", "into": "", "ms": float(fd2.get("delay_ms", 300)), "pct": 0.0, "burn_after": 0}
			pattern["strings"][sname]["feint"]["burn_after"] = int(op.get("after", 3))
			return "%s burns after %d interrupts - then it only feints" % [sname, int(op.get("after", 3))]
		"phase_directives":
			for ph in pattern.get("phases", []):
				if str(ph.get("phase", "")) == str(op.get("phase", "")):
					ph["directives"] = op.get("directives", []).duplicate()
					return "phase %s: %s" % [str(ph["phase"]), ", ".join(PackedStringArray(ph["directives"]))]
			return ""
		"select_reweights":
			pattern["select"]["reweights"] = op.get("lines", []).duplicate()
			return "select lines: %s" % (", ".join(PackedStringArray(pattern["select"]["reweights"])) if pattern["select"]["reweights"].size() > 0 else "none")
		"directive":
			var ok := apply_directive(str(op.get("text", "")))
			if ok: directives_done.append(str(op.get("text", "")))
			else: directives_carried.append(str(op.get("text", "")))
			return "%s%s" % [str(op.get("text", "")), "" if ok else " (carried)"]
	return ""

func remix_notes(rid: String) -> Array:
	# the remix page's notes without loading it: the ops applied to a copy of the base
	var rec: Dictionary = REMIX.get("remixes", {}).get(rid, {})
	if rec.is_empty() or not patterns.has(str(rec.get("base", ""))): return []
	var saved := pattern; var saved_mods := bmods.duplicate(); var saved_des := bdesync_ms; var sd := directives_done.duplicate(); var sc := directives_carried.duplicate()
	pattern = patterns[str(rec["base"])].duplicate(true)
	var notes: Array = []
	for op in rec.get("ops", []):
		var note := _apply_op(op)
		if note != "": notes.append(note)
	pattern = saved; bmods = saved_mods; bdesync_ms = saved_des; directives_done = sd; directives_carried = sc
	return notes

# ============================ THE REWARD ECONOMY (NP_11 s6, NP_02 s2/s4, NP_08 s2.4/s5) ====
func xp_of(name: String) -> int: return int(rewards.get("xp", {}).get(name, 0))

func level_of(name: String) -> int:
	# NP_11 s2: quadratic-gentle - level 50 at ~120k XP (48 L^2)
	if ECO.is_empty(): return 1
	var k := float(ECO["xp"].get("curve_k", 48)); var cap := int(ECO["xp"].get("level_cap", 50))
	return clampi(int(floor(sqrt(float(xp_of(name)) / k))), 1, cap)

func _card_of(name: String) -> Dictionary:
	for f in dressed:
		if str(f.get("name", "")) == name: return f
	return {}

func _xp_mods(name: String) -> float:
	# NP_07 s5: houseless fighters +10%; NP_02 s2.2: the tell-highlight lab pays -50%
	var m := 1.0
	var card := _card_of(name)
	if card.size() > 0 and house_key(str(card.get("house", "none"))) == "none": m *= 1.0 + float(ECO["xp"].get("houseless_pct", 10)) / 100.0
	if bout.size() > 0 and "tell_highlight" in lab: m *= 1.0 + float(ECO["xp"].get("lab_tell_highlight_pct", -50)) / 100.0
	return m

func _pay_xp(name: String, base: int, why: String) -> int:
	if ECO.is_empty() or name == "" or base <= 0: return 0
	var amt := int(round(float(base) * _xp_mods(name) * float(ECO["xp"].get("pace", 1.0))))   # PAC-098: NP_11 s2's curve paced to the story
	var before := level_of(name)
	rewards["xp"][name] = xp_of(name) + amt
	dual_xp += amt
	_ev("xp", {"who": name, "xp": amt, "why": why, "total": xp_of(name)})
	var after := level_of(name)
	if after > before:
		_ev("level_up", {"who": name, "level": after}); _say("%s reaches level %d" % [name, after])
	return amt

func _pay_bout(won: bool, pi_rose: bool) -> void:
	# NP_02 s2.1 / s2.2: a scrap pays an XP trickle and Prestige (+1-3 by the objective's tier); a spar pays full XP and Spirits, and Kizuna if the partner is a stablemate
	if ECO.is_empty(): return
	var name := pname()
	var lines: Array = []
	var xp := 0; var prestige := 0; var spirits := 0; var hbp := 0; var kiz := ""
	if str(bout["kind"]) == "scrap":
		xp = _pay_xp(name, int(ECO["xp"]["scrap_won"]) if won else int(ECO["xp"]["scrap_lost"]), "scrap")
		if won:
			var tier := int(SCRAPS.get(str(bout.get("objective", "")), {}).get("tier", 1))
			prestige = mini(int(ECO["prestige"]["cap"]), int(ECO["prestige"]["scrap_base"]) + int(ECO["prestige"]["per_tier"]) * tier)   # +1-3: tier 1 -> 2 (NP_12A's "+2 Prestige"), tier 3 -> 3 at the cap
			rewards["prestige"] = int(rewards["prestige"]) + prestige
			hbp = int(ECO["hbp"].get("scrap_won", 0)); rewards["hbp"] = int(rewards["hbp"]) + hbp
	else:
		xp = _pay_xp(name, int(ECO["xp"]["spar_fought"]) + (int(ECO["xp"]["spar_won_bonus"]) if won else 0), "spar")
		spirits = int(ECO["spirits"]["spar_won"]) if won else int(ECO["spirits"]["spar_fought"])
		rewards["spirits"] = int(rewards["spirits"]) + spirits
		if won: hbp = int(ECO["hbp"].get("spar_won", 0)); rewards["hbp"] = int(rewards["hbp"]) + hbp
		var card: Dictionary = bout.get("card", {})
		if card.size() > 0 and bool(card.get("stablemate", false)):                                      # NP_08 s5.1: spar together, either side of the glove
			var got := _pay_kizuna(name, str(card.get("name", "")), int(ECO["kizuna"]["spar_together"]), true, "spar")
			if got > 0: kiz = ", %s+%s +%d" % [name, str(card.get("name", "")), got]
	var t := {"size": bout["kind"], "who": name, "xp": xp, "prestige": prestige, "spirits": spirits, "hbp": hbp, "kizuna": kiz, "pi": pi_rose, "won": won}   # ("kind" is the event's own key)
	var fmt_s := str(ECO.get("toast", {}).get(str(bout["kind"]), "{xp} XP"))
	t["text"] = fmt_s.replace("{xp}", str(xp)).replace("{prestige}", str(prestige)).replace("{spirits}", str(spirits)).replace("{hbp}", str(hbp)).replace("{kizuna}", kiz).replace("{pi}", ", PI tick vs %s" % bdialect.capitalize() if pi_rose else "").replace(", +0 Prestige", "").replace(", 0 HBP", "")
	_toast(t)
	if won and str(bout["kind"]) == "scrap" and str(bout.get("district", "")) != "": _rep_add(str(bout["district"]), int(_rp().get("scrap_won", 1)), "a scrap won")   # PAC-101: NP_02 s2.1 - the district's rep, after the scrap's own pay

func _pay_dual(won: bool) -> void:
	# NP_11 s6: a dual pays XP to its fighters (already paid per segment), the dressed reserves 50% of it, Spirits and HBP; NP_08 s5.1: adjacent slots bond
	if ECO.is_empty() or bout.size() > 0: return
	var closing := int(ECO["xp"]["dual_won"]) if won else int(ECO["xp"]["dual_lost"])
	var seen: Array = []
	var total := 0
	for i in lineup.size():
		var nm := str(lineup[i]["name"])
		if nm in seen: continue
		seen.append(nm)
		total += _pay_xp(nm, closing, "dual")
	var dual_total := dual_xp
	var reserve_xp := 0
	for r in reserves:
		var rn := str(r["name"])
		if rn in seen: continue
		reserve_xp = _pay_xp(rn, int(round(float(dual_total) * float(ECO["xp"]["reserve_pct"]) / 100.0 / float(ECO["xp"].get("pace", 1.0)))), "reserve")   # PAC-098: the dual's total is paid at the pace already - once, not twice
	var spirits := int(ECO["spirits"]["dual_won"]) if won else int(ECO["spirits"]["dual_fought"])
	rewards["spirits"] = int(rewards["spirits"]) + spirits
	var hbp := int(ECO["hbp"]["dual_won"]) if won else 0
	rewards["hbp"] = int(rewards["hbp"]) + hbp
	var kiz_parts: Array = []
	for i in range(1, lineup.size()):
		var a := str(lineup[i - 1]["name"]); var b := str(lineup[i]["name"])
		if a == b: continue
		var got := _pay_kizuna(a, b, int(ECO["kizuna"]["adjacent_slots_win"]) if won else int(ECO["kizuna"]["adjacent_slots"]), false, "adjacent")
		if got > 0: kiz_parts.append("%s+%s +%d" % [a, b, got])
	var kiz := (", " + ", ".join(PackedStringArray(kiz_parts))) if kiz_parts.size() > 0 else ""
	var hp := 0
	if host and fac_has("front_of_house", "prestige_tier"):                                               # PAC-089: Front of House - a hosted dual pays the gate's Prestige, won or lost
		hp = int(FAC["tracks"]["front_of_house"].get("prestige", 0)); rewards["prestige"] = int(rewards["prestige"]) + hp
	var t := {"size": "dual", "who": seen, "xp": dual_total, "reserve_xp": reserve_xp, "prestige": hp, "spirits": spirits, "hbp": hbp, "kizuna": kiz, "pi": false, "won": won}
	t["text"] = str(ECO.get("toast", {}).get("dual", "{xp} XP")).replace("{xp}", str(dual_total)).replace("{spirits}", str(spirits)).replace("{hbp}", str(hbp)).replace("{kizuna}", kiz).replace("{pi}", "").replace(", 0 HBP", "") + ((", +%d Prestige (hosted)" % hp) if hp > 0 else "")
	_toast(t)
	_trainees_feed()                                                                                     # PAC-099: NP_08 s1 - the cornermen-in-training worked the corner

func _toast(t: Dictionary) -> void:
	last_toast = t
	rewards["log"].append(str(t["text"]))
	if rewards["log"].size() > 40: rewards["log"].pop_front()
	_ev("reward_toast", t)
	_say("REWARD :: " + str(t["text"]))

# ---- Kizuna (NP_08 s5) ----
static func pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a <= b else (b + "|" + a)

func kizuna_pts(a: String, b: String) -> int: return int(rewards.get("kizuna", {}).get(pair_key(a, b), 0))

func kizuna_level(a: String, b: String) -> int:
	if ECO.is_empty(): return 0
	var pts := kizuna_pts(a, b); var lvl := 0
	for th in ECO["kizuna"]["levels"]:
		if pts >= int(th): lvl += 1
	return lvl

func _allied(a: String, b: String) -> bool:
	# NP_08 s5.1: ALLIED houses x1.25 - both cards' Houses joined by an ALLIED edge
	var ca := _card_of(a); var cb := _card_of(b)
	var ha := house_key(str(ca.get("house", "none"))); var hb := house_key(str(cb.get("house", "none")))
	if ha == "none" or hb == "none": return false
	return edge_relation(_edge_between(ha, hb)) == "ALLIED"                                            # PAC-077: a flipped edge bonds its members x1.25

func _pay_kizuna(a: String, b: String, pts: int, repeatable: bool, why: String) -> int:
	# a pair's points; repeatable sources soft-cap at +15/day per pair (s5.3), duals bypass; ALLIED x1.25; a level crossed is an event
	if ECO.is_empty() or a == "" or b == "" or a == b or pts <= 0: return 0
	var key := pair_key(a, b)
	var bmul := float(ECO["kizuna"]["allied_mult"]) if _allied(a, b) else 1.0
	for od_card in [_card_of(a), _card_of(b)]:                                                            # PAC-078: Open Door - the larger of it and ALLIED, never both
		var od_t := card_trait(od_card)
		if str(od_t.get("id", "")) == "open_door": bmul = maxf(bmul, _tmult(float(HOUSES["traits"]["open_door"]["bond_mult"]), int(od_t["x"])))
	var amt := int(round(float(pts) * bmul))
	if repeatable:
		var cap := int(ECO["kizuna"]["daily_soft_cap"])
		var today := int(rewards["kizuna_day"].get(key, 0))
		amt = mini(amt, maxi(0, cap - today))
		if amt <= 0: return 0
		rewards["kizuna_day"][key] = today + amt
	var before := kizuna_level(a, b)
	rewards["kizuna"][key] = kizuna_pts(a, b) + amt
	var after := kizuna_level(a, b)
	_ev("kizuna", {"pair": key, "pts": amt, "total": kizuna_pts(a, b), "level": after, "why": why})
	if after > before:
		var nm := str(ECO["kizuna"]["names"][after - 1]) if after - 1 < ECO["kizuna"]["names"].size() else str(after)
		_ev("kizuna_level", {"pair": key, "level": after, "name": nm}); _say("KIZUNA %s: %s - Lv%d %s" % [key.replace("|", " & "), why, after, nm])
		_gw_deco("polaroid", "%s & %s - %s" % [key.split("|")[0], key.split("|")[1], nm], {"pair": key, "level": after})   # PAC-079: the bond scene's photograph on the wall
	return amt

func new_day() -> void:
	# the overworld's day turns: the repeatable Kizuna cap resets; the ledger's day counts (the save's calendar, NP_11 s9)
	rewards["kizuna_day"] = {}
	rewards["day"] = int(rewards.get("day", 1)) + 1
	_releases_settle()                                                                                   # PAC-100: NP_08 s4 - a release three days old stands
	_scouts_pay()                                                                                        # PAC-099: NP_08 s1 - the bench's scouts, their districts' Prestige

func _kizuna_partners(name: String, min_level: int) -> Array:
	var out: Array = []
	for f in dressed:
		var nm := str(f.get("name", ""))
		if nm != name and kizuna_level(name, nm) >= min_level: out.append(nm)
	return out

func _adjacent_names() -> Array:
	# the slots beside this one in the rotation
	var out: Array = []
	if seg_idx - 1 >= 0 and seg_idx - 1 < lineup.size(): out.append(str(lineup[seg_idx - 1]["name"]))
	if seg_idx + 1 < lineup.size(): out.append(str(lineup[seg_idx + 1]["name"]))
	return out

func _apply_kizuna_effects(f: Dictionary) -> void:
	# NP_08 s5.2: Lv2 Corner Voices - a Lv2 partner dressed: +2% all stats; Lv3 Adjacent Trust - a Lv3 partner in an adjacent slot: +5% (the CHARGED threshold -5 is read at the segment's end)
	if ECO.is_empty() or bout.size() > 0: return
	var name := str(f.get("name", ""))
	var pct := 0.0
	var fx: Dictionary = ECO["kizuna"].get("effects", {})
	if _kizuna_partners(name, 2).size() > 0: pct += float(fx.get("2", {}).get("stat_pct", 2))
	for adj in _adjacent_names():
		if adj != name and kizuna_level(name, adj) >= 3: pct = maxf(pct, float(fx.get("3", {}).get("adjacent_stat_pct", 5))); break
	if pct <= 0.0: return
	var st: Dictionary = P["stats"].duplicate()
	for k in st: st[k] = float(st[k]) * (1.0 + pct / 100.0)
	P["stats"] = st
	_ev("kizuna_effect", {"who": name, "stat_pct": pct})

func _charged_threshold() -> float:
	# NP_05 s6's 25, less 5 for a pair in Adjacent Trust (NP_08 s5.2 Lv3)
	var th := 25.0
	if _pas(P, "closer"): th -= float(_pv("closer", "charged_minus", 0))                                # PAC-090: Closer (NP_11 s3) - his own, in any bout
	if ECO.is_empty() or bout.size() > 0 or lineup.is_empty(): return th
	for adj in _adjacent_names():
		if kizuna_level(pname(), adj) >= 3: th -= float(ECO["kizuna"].get("effects", {}).get("3", {}).get("charged_threshold_minus", 5)); break
	return th

# ============================ THE DUO (NP_08 s5.2 Lv4, NP_05 s7) ===========
# A Duo pair (Kizuna Lv4) relays a named T3: the second of the pair out, the first having fought the segment before, carries the pair's duo
# variant of a relay T3 - the library's duo_variant on its base (the base that names the pair; else the relay T3 of the element both carry;
# else the ANY-element one) - castable by the bond, with or without a CHARGED relay (GDD s5.2: "relay state or bonded adjacency"), the
# partner's afterimage joining it. It hits as its base: the variant is its name, its VFX, its camera and the afterimage (NP_05 s7). Its
# family's motion casts it while the bar can pay it, the card's own move below that. Bosses keep no bonds.
func duo_level() -> int:
	var fx: Dictionary = ECO.get("kizuna", {}).get("effects", {})
	for k in fx:
		if bool(fx[k].get("duo_t3", false)): return int(k)
	return 0

func _duo_base(a: String, b: String) -> Dictionary:
	var key := pair_key(a, b)
	var ea := element_key(str(_card_of(a).get("element", ""))); var eb := element_key(str(_card_of(b).get("element", "")))
	var shared: Dictionary = {}; var anyb: Dictionary = {}
	for nm in library:
		var m: Dictionary = library[nm]
		if not (m.get("duo_variant") is Dictionary): continue
		if m["duo_variant"].get("pairs", {}).has(key): return m
		if shared.is_empty() and ea != "NONE" and ea == eb and element_key(str(m["element"])) == ea: shared = m
		if anyb.is_empty() and str(m["element"]) == "ANY": anyb = m
	return shared if shared.size() > 0 else anyb

func duo_move_for(a: String, b: String) -> Dictionary:
	# the pair's named duo T3 (a = the partner out first, b = the caster): its base's record under the pair's name, VFX and camera, the
	# variant's effect entries after the base's
	if a == b: return {}
	var base := _duo_base(a, b)
	if base.is_empty(): return {}
	var dv: Dictionary = base["duo_variant"]
	var key := pair_key(a, b); var ks := key.split("|")
	var gen := str(dv.get("name_rule", "{base} - {a} & {b}")).replace("{base}", str(base["name"]).trim_prefix("Relay: ")).replace("{a}", ks[0]).replace("{b}", ks[1])
	var m: Dictionary = base.duplicate(true)
	m["id"] = str(base["id"]) + "-DUO"; m["name"] = str(dv.get("pairs", {}).get(key, gen))
	m["effect"] = base["effect"].duplicate(true) + dv.get("effect_add", []).duplicate(true)
	m["vfx_set"] = str(dv.get("vfx_set", base["vfx_set"])); m["camera_script_id"] = str(dv.get("camera_script_id", base["camera_script_id"]))
	m["source"] = "duo:" + key; m["duo_variant"] = null
	m["duo_of"] = str(base["name"]); m["duo_pair"] = key; m["duo_partner"] = a; m["duo_named"] = dv.get("pairs", {}).has(key)
	return m

func _duo_check() -> void:
	# at the segment's load: the fighter out and the one before him, a Duo pair or better -> the pair's named T3 is live for this segment
	duo = {}
	var lv0 := duo_level()
	if lv0 <= 0 or bout.size() > 0 or seg_idx <= 0 or seg_idx >= lineup.size(): return
	var a := str(lineup[seg_idx - 1]["name"]); var b := str(lineup[seg_idx]["name"])
	var lv := kizuna_level(a, b)
	if a == b or lv < lv0: return
	var m := duo_move_for(a, b)
	if m.is_empty(): return
	duo = {"pair": pair_key(a, b), "partner": a, "caster": b, "level": lv, "move": m}
	var lvn := str(ECO["kizuna"]["names"][lv - 1]) if lv - 1 < ECO["kizuna"]["names"].size() else str(lv)
	_ev("duo", {"seg": seg_idx + 1, "pair": pair_key(a, b), "partner": a, "caster": b, "level": lv, "level_name": lvn, "move": str(m["name"]), "base": str(m["duo_of"]), "family": str(m["family"]), "cost": hiss_cost(m), "named": bool(m["duo_named"])})
	_say("DUO :: %s -> %s (Lv%d %s): %s is live - LB + %s, a T3 at %d Tension, %s's afterimage joining (%s)" % [a, b, lv, lvn, str(m["name"]).to_upper(), str(m["family"]), int(hiss_cost(m)), a, str(m["duo_of"])])

func duo_move() -> Dictionary:
	# the live duo T3, for its caster only
	if duo.is_empty() or seg_idx >= lineup.size() or str(lineup[seg_idx]["name"]) != str(duo.get("caster", "")): return {}
	return duo["move"]

func cast_move(row: String) -> Dictionary:
	# LB + a motion: the pair's live hybrid (PAC-087), then a live duo T3 answers its family's motion while the bar can pay it, then a T3 the
	# relay opened (PAC-081), then the card's own move (NP_05 s4's fall-through)
	var hm := hybrid_move()
	if hm.size() > 0 and _family_row_matches(str(hm["family"]), row) and castable(hm) and can_pay(hm): return hm
	var dm := duo_move()
	if dm.size() > 0 and _family_row_matches(str(dm["family"]), row) and castable(dm) and can_pay(dm): return dm
	for m in relay_moves():
		if _family_row_matches(str(m["family"]), row) and castable(m) and can_pay(m): return m
	for m in inherited_moves():                                                                          # PAC-084: the source's natives, from the meter
		if _family_row_matches(str(m["family"]), row) and castable(m) and can_pay(m): return m
	var own := player_move()                                                                             # PAC-091: his own move on its motion, else the kit's of that family
	if own.size() > 0 and _family_row_matches(str(own["family"]), row) and castable(own) and can_pay(own): return own
	var km := kit_move(row)
	return km if km.size() > 0 else own

func duo_lines(order: Array) -> Array:
	# the whiteboard: every Duo relay an order holds, with the pair's named T3
	var out: Array = []
	if duo_level() <= 0: return out
	for i in range(1, order.size()):
		var a := str(order[i - 1]); var b := str(order[i])
		if a == b or kizuna_level(a, b) < duo_level(): continue
		var m := duo_move_for(a, b)
		if m.size() > 0: out.append("R%d %s -> R%d %s (%s)" % [i, a, i + 1, b, str(m["name"])])
	return out

# ============================ HYBRID RESEARCH (NP_08 s6) =====================
# A Sworn pair (the Kizuna effect "hybrid") from two houses, each with a native of his house learned, forges once at a Forge event between
# duals for the ledger's Spirits and Beans. The output is a T3 unique to the pair: the library's authored hybrid for its two houses (Two
# Rivers, Grain & Snow) while no pair has claimed it, else one composed from both houses' natives - the family and the damage of the
# stronger (+0.1, the T3 floor 2.4 under it), a tag from each house, the houses' motifs for its name. Either of the pair casts it: relayed
# between them (his partner fought the segment before) - the strongest, the partner's afterimage joining at x1.25 - CHARGED (NP_05 s3's T3
# rule), or from an Awakening's hybrid slot (NP_09 s6). Eight a save; the ledger keeps the registry (NP_11 s9's hybrid_registry). Bosses
# keep no bonds; the Toronto academy's industrialized hybrids (NP_07 s10) are the story's.
func hybrid_level() -> int:
	var fx: Dictionary = ECO.get("kizuna", {}).get("effects", {})
	for k in fx:
		if bool(fx[k].get("hybrid", false)): return int(k)
	return 0

static func _whole(v):
	# a record as the save will read it back: a whole float is its int (the ledger writes back byte-equal)
	if v is float: return int(v) if v == floor(v) and absf(v) < 9.0e15 else v
	if v is Dictionary:
		var o := {}
		for k in v: o[k] = _whole(v[k])
		return o
	if v is Array:
		var o: Array = []
		for x in v: o.append(_whole(x))
		return o
	return v

static func seed_purse(ledger: Dictionary, s_arg: String) -> Dictionary:
	# `-- purse=spirits:40,beans:30` -> the ledger's Spirits and Beans (what duals and training slots would have paid)
	var out := ledger.duplicate(true)
	for part in s_arg.split(","):
		var kv := str(part).strip_edges().split(":")
		if kv.size() == 2 and str(kv[0]) in ["spirits", "beans", "prestige", "hbp"] and str(kv[1]).is_valid_int(): out[str(kv[0])] = int(kv[1])
	return out

static func seed_rep(ledger: Dictionary, r_arg: String, eco: Dictionary = {}) -> Dictionary:
	# PAC-103: `-- rep=downtown:9,rink:3` -> the districts' rep on the ledger as it stood (its milestones counted as passed, not paid)
	var out := ledger.duplicate(true)
	for part in r_arg.split(","):
		var kv := str(part).strip_edges().to_lower().split(":")
		if kv.size() != 2 or not str(kv[1]).is_valid_int(): continue
		var k := str(eco.get("rep", {}).get("aliases", {}).get(str(kv[0]), str(kv[0])))
		if not out.has("rep"): out["rep"] = {"of": {}, "best": {}, "paid": 0}
		out["rep"]["of"][k] = int(kv[1]); out["rep"]["best"][k] = maxi(int(out["rep"]["best"].get(k, 0)), int(kv[1]))
	return out

func _club_card(nm: String) -> Dictionary:
	var c := _stable_card(nm)
	return c if c.size() > 0 else _card_of(nm)

func _club_names() -> Array:
	var out: Array = []
	for arr in [stable, dressed]:
		for c in arr:
			if c is Dictionary and not str(c.get("name", "")) in out: out.append(str(c.get("name", "")))
	return out

func _forge_house(nm: String) -> String:
	# the house a card forges with: his own (a sealed house forges nothing until it opens)
	var h := house_key(str(_club_card(nm).get("house", "none")))
	return "none" if h == "sealed" else h

func learned_natives(nm: String) -> Array:
	# the natives of his house he knows, in the library's order: the house's (NATIVE), its SECRET (his secret:<NAME> flag), the one he carries
	var out: Array = []
	var c := _club_card(nm); var h := _forge_house(nm)
	if c.is_empty() or h == "none": return out
	var carried := str(c.get("hissatsu", "")); var nat := natives_unlocked(nm)
	for mn in library:
		var m: Dictionary = library[mn]
		if m.get("house_id") == null or str(m["house_id"]) != h: continue
		var sealed := false
		for e in m["effect"]:
			if str(e["type"]) == "REDACTED": sealed = true
		if sealed: continue
		var sec := bool(m.get("secret", false))
		if str(mn) == carried or (not sec and str(mn) in nat) or (sec and _flag_set("secret:" + nm)): out.append(str(mn))
	return out

func _hyb_reg() -> Dictionary:
	return rewards.get("hybrids", {})

func _hyb_keys() -> Array:
	# the registry's pairs in the order forged (its "n"; a save's sorted keys never reorder it)
	var ks: Array = _hyb_reg().keys()
	ks.sort_custom(func(x, y): return int(_hyb_reg()[x].get("n", 0)) < int(_hyb_reg()[y].get("n", 0)))
	return ks

func hybrid_of_pair(a: String, b: String) -> Dictionary:
	return _hyb_reg().get(pair_key(a, b), {})

func hybrids_of(nm: String) -> Array:
	# his hybrids, in the order forged
	var out: Array = []
	var reg := _hyb_reg()
	for k in _hyb_keys():
		if nm in str(k).split("|"): out.append(reg[k])
	return out

func _hyb_partner(h: Dictionary, nm: String) -> String:
	var ks := str(h["pair"]).split("|")
	return str(ks[1]) if str(ks[0]) == nm else str(ks[0])

func forge_terms(a: String, b: String) -> Dictionary:
	# the bond the pair needs and the price: Sworn and the table's Spirits and Beans; across a discount's edge with its flag set, its level and cut
	var f: Dictionary = HYB.get("forge", {})
	var t := {"level": hybrid_level(), "spirits": int(f.get("spirits", 0)), "beans": int(f.get("beans", 0)), "discount": ""}
	var e := _edge_between(_forge_house(a), _forge_house(b))
	for d in HYB.get("discounts", []):
		if e.is_empty() or str(e.get("id", "")) != str(d.get("edge", "")) or not _flag_set(str(d.get("flag", ""))): continue
		var pct := float(d.get("pct", 0))
		t["level"] = mini(int(t["level"]), int(d.get("early_level", t["level"])))
		t["spirits"] = int(round(float(t["spirits"]) * (100.0 - pct) / 100.0)); t["beans"] = int(round(float(t["beans"]) * (100.0 - pct) / 100.0))
		t["discount"] = "%s %s, -%d%%" % [str(e["id"]), edge_relation(e), int(pct)]
	return t

func _kz_name(lv: int) -> String:
	var nms: Array = ECO.get("kizuna", {}).get("names", [])
	return str(nms[lv - 1]) if lv >= 1 and lv - 1 < nms.size() else ("no bond" if lv <= 0 else str(lv))

func forge_why(a: String, b: String) -> String:
	# why this pair cannot forge now ("" when it can): between duals, two cards of the club, two houses, a native each, the bond, one a pair,
	# the ceiling, the price
	if HYB.is_empty() or hybrid_level() <= 0: return "no Forge in this build"
	if mode != "OVER" and bell_rung(): return "the Forge is between duals"
	if not fac_open("the_wall", "forge_tier"): return "the Forge is hosted at The Wall (T%d) - the gym's wall is at T%d" % [int(FAC["tracks"]["the_wall"].get("forge_tier", 3)), fac_tier("the_wall")]   # PAC-089: NP_10 s7
	if _club_card(a).is_empty(): return "%s is not in the club" % a
	if _club_card(b).is_empty(): return "%s is not in the club" % b
	if a == b: return "a hybrid takes two fighters"
	var ha := _forge_house(a); var hb := _forge_house(b)
	for x in [[a, ha], [b, hb]]:
		if str(x[1]) == "none": return "%s carries no house (a hybrid crosses two houses)" % str(x[0])
	if ha == hb: return "%s and %s are both House %s (a hybrid crosses two houses)" % [a, b, _house_name(ha)]
	for x in [[a, ha], [b, hb]]:
		if learned_natives(str(x[0])).is_empty(): return "%s knows no native of House %s" % [str(x[0]), _house_name(str(x[1]))]
	var tm := forge_terms(a, b)
	var lv := kizuna_level(a, b)
	if lv < int(tm["level"]): return "%s & %s are at Lv%d %s (%d) - the Forge opens at Lv%d %s" % [a, b, lv, _kz_name(lv), kizuna_pts(a, b), int(tm["level"]), _kz_name(int(tm["level"]))]
	if hybrid_of_pair(a, b).size() > 0: return "%s & %s have forged %s" % [a, b, str(hybrid_of_pair(a, b)["name"])]
	if _hyb_reg().size() >= int(HYB.get("ceiling", 8)): return "the Forge's ceiling is reached (%d of %d hybrids)" % [_hyb_reg().size(), int(HYB.get("ceiling", 8))]
	if int(rewards.get("spirits", 0)) < int(tm["spirits"]) or int(rewards.get("beans", 0)) < int(tm["beans"]):
		return "the Forge costs %d Spirits and %d Beans (the ledger holds %d and %d)" % [int(tm["spirits"]), int(tm["beans"]), int(rewards.get("spirits", 0)), int(rewards.get("beans", 0))]
	return ""

func _authored_hybrid(ha: String, hb: String) -> Dictionary:
	# the library's authored hybrid of these two houses, while no pair has claimed it
	var want := [ha, hb]; want.sort()
	for mn in library:
		var m: Dictionary = library[mn]
		if str(m.get("source", "")) != "hybrid:forge" or not (m.get("hybrid_parents") is Array): continue
		var hp: Array = m["hybrid_parents"].map(func(x): return house_key(str(x))); hp.sort()
		if hp != want: continue
		var taken := false
		for k in _hyb_reg():
			if str(_hyb_reg()[k]["name"]) == str(mn): taken = true
		if not taken: return m
	return {}

func compose_hybrid(a: String, b: String) -> Dictionary:
	# a hybrid from both houses' natives: the stronger learned native's family (never a WALL) and its damage +0.1 over the T3 floor; from each
	# house the first non-DMG, non-WALL effect of what the fighter knows (a state's or buff's seconds capped); the cinematic by its tags; the
	# houses' motifs for the name (a name forged already carries the pair's names after it)
	var cr: Dictionary = HYB.get("compose", {})
	var sides := [[a, _forge_house(a)], [b, _forge_house(b)]]
	sides.sort_custom(func(x, y): return str(x[1]) < str(y[1]))
	var parts := _compose_parts(sides.map(func(x): return [str(x[1]), learned_natives(str(x[0]))]))
	var fam := str(parts["fam"]); var tags: Array = parts["tags"]; var dmg := float(parts["dmg"])
	var mo: Dictionary = HYB.get("motifs", {})
	var nm := str(cr.get("name_rule", "{a} & {b}")).replace("{a}", str(mo.get(str(sides[0][1]), _house_name(str(sides[0][1]))))).replace("{b}", str(mo.get(str(sides[1][1]), _house_name(str(sides[1][1])))))
	var taken := library.has(nm)
	for k in _hyb_reg():
		if str(_hyb_reg()[k]["name"]) == nm: taken = true
	if taken:
		var ks := pair_key(a, b).split("|")
		nm = str(cr.get("name_rule_taken", "{name} - {x} & {y}")).replace("{name}", nm).replace("{x}", str(ks[0])).replace("{y}", str(ks[1]))
	var eff: Array = [{"type": "DMG", "params": {"mult": dmg, "composure_bypass_pct": 0}}]
	eff.append_array(tags)
	return _whole({"id": "HYB-%02d" % (_hyb_reg().size() + 1), "name": nm, "tier": str(cr.get("tier", "T3")), "family": fam, "element": str(cr.get("element", "DUAL")),
		"house_id": null, "style_req": null, "tension_cost": int(cr.get("tension_cost", 50)), "private_meter_cost": null,
		"startup_cinematic_ms": int(cr.get("cinematic_base_ms", 2100)) + int(cr.get("cinematic_per_tag_ms", 100)) * tags.size(), "effect": eff,
		"counter_profile": cr.get("counter_profile", {"interruptible": true, "window_ms": 700, "negation": ""}).duplicate(true), "duo_variant": null,
		"hybrid_parents": [str(sides[0][1]), str(sides[1][1])], "camera_script_id": str(cr.get("camera", "cam_{family}_t3")).replace("{family}", fam.to_lower()),
		"vfx_set": str(cr.get("vfx_set", "vfx_dual")), "source": str(cr.get("source", "hybrid:forge")), "secret": false, "notes": "forged by %s" % pair_key(a, b).replace("|", " & ")})

func _compose_parts(sides: Array) -> Dictionary:
	# the composer's reading of two houses' natives (each side [house, its natives in the library's order], sorted by house): the family of
	# the stronger native (never a WALL) and its damage +0.1 over the T3 floor; from each house the first non-DMG, non-WALL effect (a state's
	# or buff's seconds capped) - the Forge reads what the pair learned, the academy the library (PAC-092)
	var cr: Dictionary = HYB.get("compose", {})
	var best := -1.0; var fam := ""
	var tags: Array = []
	for sd in sides:
		var tag := {}
		for mn in sd[1]:
			var m: Dictionary = library[mn]
			var d := 0.0
			for e in m["effect"]:
				if str(e["type"]) == "DMG": d = maxf(d, float(e["params"].get("mult", e["params"].get("base", 0.0))))
			if str(m["family"]) != "WALL" and d > best + 0.000001: best = d; fam = str(m["family"])
			if tag.is_empty():
				for e in m["effect"]:
					var t := str(e["type"])
					if t == "DMG" or t == "WALL" or t == "REDACTED": continue
					tag = e.duplicate(true)
					if (t == "STATE" or t == "BUFF") and tag["params"].has("seconds") and float(tag["params"]["seconds"]) > float(cr.get("tag_seconds_cap", 2)): tag["params"]["seconds"] = float(cr.get("tag_seconds_cap", 2))
					break
		if tag.size() > 0: tags.append(tag)
	if fam == "": fam = str(cr.get("family_fallback", "ARC"))
	var dmg := snappedf(maxf(float(cr.get("dmg_floor", 2.4)), best + float(cr.get("dmg_over_parent", 0.1))), 0.01)
	return {"fam": fam, "dmg": dmg, "tags": tags}

func _forge_record(a: String, b: String) -> Dictionary:
	# what the pair's Forge makes: the authored hybrid of its houses, else the composed one
	var au := _authored_hybrid(_forge_house(a), _forge_house(b))
	if au.size() > 0: return _whole(au.duplicate(true))
	return compose_hybrid(a, b)

func _tag_text(e: Dictionary) -> String:
	var pr: Dictionary = e["params"]
	match str(e["type"]):
		"DMG": return "DMG x%s" % _n(float(pr.get("mult", pr.get("base", 0.0))))
		"SHRED": return "guard shred %s" % _n(float(pr.get("guard", 0)))
		"BURN": return "stamina burn %s" % _n(float(pr.get("stamina", 0)))
		"DISPLACE": return "displacement %sm to the %s" % [_n(float(pr.get("meters", 0))), str(pr.get("toward", "")).to_lower()]
		"STATE", "BUFF": return "%s%s" % [str(pr.get("name", "")).replace("_", " "), (" %ss" % _n(float(pr["seconds"]))) if pr.has("seconds") and float(pr["seconds"]) > 0.0 else (" %s" % _n(float(pr["value"])) if pr.has("value") else "")]
	return str(e["type"])

func forge(a: String, b: String = "") -> Dictionary:
	# between duals: the pair forges its hybrid ("*" - the first pair of the club the Forge takes); the ledger pays, the registry keeps it
	if a == "*":
		var first := ""
		for c in forge_candidates():
			if str(c["why"]) == "": return forge(str(c["a"]), str(c["b"]))
			if first == "": first = str(c["why"])
		var w0 := "no pair of the club can forge%s" % ((" - " + first) if first != "" else "")
		_ev("forge_refused", {"a": "*", "b": "", "why": w0}); _say("THE FORGE - %s" % w0)
		return {"ok": false, "why": w0}
	var why := forge_why(a, b)
	if why != "":
		_ev("forge_refused", {"a": a, "b": b, "why": why}); _say("THE FORGE - %s" % why)
		return {"ok": false, "why": why}
	var tm := forge_terms(a, b)
	var mv := _forge_record(a, b)
	var authored := str(mv.get("id", "")).begins_with("HIS-")
	var ha := _forge_house(a); var hb := _forge_house(b)
	var e := _edge_between(ha, hb)
	rewards["spirits"] = int(rewards.get("spirits", 0)) - int(tm["spirits"]); rewards["beans"] = int(rewards.get("beans", 0)) - int(tm["beans"])
	_beans_settle()                                                                                      # PAC-090: the untyped Beans go first, then the typed in the stats' order
	if not rewards.has("hybrids"): rewards["hybrids"] = {}
	var key := pair_key(a, b)
	rewards["hybrids"][key] = {"n": _hyb_reg().size() + 1, "pair": key, "name": str(mv["name"]), "id": str(mv["id"]), "houses": mv["hybrid_parents"].duplicate(), "authored": authored, "day": int(rewards.get("day", 1)),
		"level": kizuna_level(a, b), "edge": ("%s %s" % [str(e["id"]), edge_relation(e)]) if e.size() > 0 else "", "paid": {"spirits": int(tm["spirits"]), "beans": int(tm["beans"])}, "discount": str(tm["discount"]),
		"casts": 0, "debut_day": 0, "move": mv}
	var n := _hyb_reg().size(); var cap := int(HYB.get("ceiling", 8))
	var tags: Array = mv["effect"].map(func(x): return _tag_text(x))
	_ev("forge", {"pair": key, "a": a, "b": b, "name": str(mv["name"]), "family": str(mv["family"]), "houses": mv["hybrid_parents"].duplicate(), "authored": authored, "spirits": int(tm["spirits"]), "beans": int(tm["beans"]),
		"discount": str(tm["discount"]), "edge": str(rewards["hybrids"][key]["edge"]), "n": n, "of": cap, "effects": tags})
	_say("THE FORGE :: %s & %s (House %s x House %s, Lv%d %s%s) forge %s - a T3 %s of both: %s; %d Spirits, %d Beans%s (the ledger %d / %d); hybrid %d of %d" % [a, b, _house_name(ha), _house_name(hb), kizuna_level(a, b), _kz_name(kizuna_level(a, b)),
		(", " + str(rewards["hybrids"][key]["edge"])) if str(rewards["hybrids"][key]["edge"]) != "" else "", str(mv["name"]).to_upper(), str(mv["family"]), ", ".join(PackedStringArray(tags)), int(tm["spirits"]), int(tm["beans"]),
		(" (" + str(tm["discount"]) + ")") if str(tm["discount"]) != "" else "", int(rewards["spirits"]), int(rewards["beans"]), n, cap])
	return {"ok": true, "why": "", "name": str(mv["name"]), "move": mv, "authored": authored}

func forge_candidates() -> Array:
	# every pair of the club across two houses with a native each, not yet forged, a bond level or less from the Forge - the reason it waits
	var out: Array = []
	var names := _club_names()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a := str(names[i]); var b := str(names[j])
			var ha := _forge_house(a); var hb := _forge_house(b)
			if ha == "none" or hb == "none" or ha == hb or hybrid_of_pair(a, b).size() > 0: continue
			if learned_natives(a).is_empty() or learned_natives(b).is_empty(): continue
			if kizuna_level(a, b) < int(forge_terms(a, b)["level"]) - 1: continue
			out.append({"a": a, "b": b, "why": forge_why(a, b), "name": str(_forge_record(a, b)["name"]), "terms": forge_terms(a, b)})
	return out

func forge_lines() -> Array:
	# between duals: the registry (N of 8) and the pairs near the Forge - what each would make and what it costs, or what it waits on
	var out: Array = []
	var reg := _hyb_reg()
	if reg.size() > 0: out.append("forged %d of %d: %s" % [reg.size(), int(HYB.get("ceiling", 8)), ", ".join(PackedStringArray(_hyb_keys().map(func(k): return "%s (%s)" % [str(reg[k]["name"]), str(k).replace("|", " & ")])))])
	for c in forge_candidates():
		var tm: Dictionary = c["terms"]
		out.append("%s & %s -> %s: %s" % [str(c["a"]), str(c["b"]), str(c["name"]), ("[F] %d Spirits, %d Beans%s" % [int(tm["spirits"]), int(tm["beans"]), (" (" + str(tm["discount"]) + ")") if str(tm["discount"]) != "" else ""]) if str(c["why"]) == "" else str(c["why"])])
	return out

func choose_hybrid(nm: String, hname: String) -> Dictionary:
	# between duals: which of his hybrids his CHARGED relay and his Awakening's slot open ("" gives it back to his first forged)
	var c := _club_card(nm)
	var why := ""
	if c.is_empty(): why = "%s is not in the club" % nm
	elif mode != "OVER" and bell_rung(): why = "between duals only"
	elif hname != "" and not hname in hybrids_of(nm).map(func(h): return str(h["name"])): why = "%s has no hybrid %s" % [nm, hname]
	if why != "": _ev("hybrid_choice_refused", {"card": nm, "hybrid": hname, "why": why}); return {"ok": false, "why": why}
	for arr in [stable, dressed, lineup, reserves]:
		for cc in arr:
			if cc is Dictionary and str(cc.get("name", "")) == nm:
				if hname == "": cc.erase("hybrid_slot")
				else: cc["hybrid_slot"] = hname
	_ev("hybrid_choice", {"card": nm, "hybrid": hname})
	_say("%s's hybrid slot: %s" % [nm, hname if hname != "" else "his first forged"])
	return {"ok": true, "why": "", "hybrid": hname}

func _hyb_slot_entry(nm: String, mine: Array) -> Dictionary:
	var want := str(_club_card(nm).get("hybrid_slot", ""))
	for h in mine:
		if str(h["name"]) == want: return h
	return mine[0] if mine.size() > 0 else {}

func _hyb_slot_text(nm: String) -> String:
	# the Awakening's feed: the hybrid slot holds one of his, or opens on nothing
	var h := _hyb_slot_entry(nm, hybrids_of(nm))
	return ("the hybrid slot holds %s" % str(h["name"])) if h.size() > 0 else "the hybrid slot open on nothing"

func _hyb_rec(h: Dictionary, nm: String, why: String) -> Dictionary:
	# the registry's record as it casts now: relayed between the pair, the partner's afterimage joins and it hits x1.25
	var m: Dictionary = h["move"].duplicate(true)
	m["hybrid_of"] = str(h["pair"]); m["hybrid_partner"] = _hyb_partner(h, nm); m["hybrid_live"] = why
	if why == "relayed":
		var cc: Dictionary = HYB.get("cast", {})
		var mult := float(cc.get("relayed_dmg_mult", 1.0))
		var has_ai := false
		for e in m["effect"]:
			if str(e["type"]) == "DMG":
				if e["params"].has("mult"): e["params"]["mult"] = float(e["params"]["mult"]) * mult
				if e["params"].has("base"): e["params"]["base"] = float(e["params"]["base"]) * mult
			if str(e["type"]) == "STATE" and str(e["params"].get("name", "")) == "afterimage_partner": has_ai = true
		if bool(cc.get("relayed_afterimage", true)) and not has_ai: m["effect"].append({"type": "STATE", "params": {"name": "afterimage_partner", "seconds": 3}})
	return m

func hybrid_move() -> Dictionary:
	# the fighter out's live hybrid: relayed between the pair (his partner fought the segment before) - the strongest; else the one his card
	# chose (his first forged) while he is CHARGED (the relay opens his T3s) or Awakened (the hybrid slot)
	if HYB.is_empty() or bout.size() > 0 or seg_idx >= lineup.size() or not rewards.has("hybrids"): return {}
	var me := pname()
	var mine := hybrids_of(me)
	if mine.is_empty(): return {}
	var prev := str(lineup[seg_idx - 1]["name"]) if seg_idx > 0 and seg_idx - 1 < lineup.size() else ""
	if prev != "" and prev != me:
		for h in mine:
			if _hyb_partner(h, me) == prev: return _hyb_rec(h, me, "relayed")
	var why := ""
	if t3_unlocked: why = "charged"
	elif tform.has("form") and int(TRANS.get("tiers", {}).get("awakening", {}).get("effects", {}).get("hybrid_slot", 0)) >= 1: why = "awakened"
	if why == "": return {}
	return _hyb_rec(_hyb_slot_entry(me, mine), me, why)

func _hyb_live_text(m: Dictionary) -> String:
	match str(m.get("hybrid_live", "")):
		"relayed": return "relayed from %s - %s's afterimage joins, x%s" % [str(m["hybrid_partner"]), str(m["hybrid_partner"]), _n(float(HYB.get("cast", {}).get("relayed_dmg_mult", 1.0)))]
		"charged": return "the CHARGED relay opens it"
		"awakened": return "the Awakening's hybrid slot"
	return ""

func hybrid_line() -> String:
	# the matchup card: the pair's hybrid live for the fighter out, priced
	var m := hybrid_move()
	if m.is_empty(): return ""
	return "HYBRID: %s (LB + %s, %d) - %s" % [str(m["name"]), str(m["family"]), int(hiss_cost(m)), _hyb_live_text(m)]

func _hybrid_check(only: String = "") -> void:
	# at the segment's load (and an Awakening's start, for its slot alone): the fighter out's live hybrid, on the feed and as an event
	var m := hybrid_move()
	if m.is_empty() or (only != "" and str(m["hybrid_live"]) != only): return
	_ev("hybrid", {"seg": seg_idx + 1, "who": pname(), "move": str(m["name"]), "family": str(m["family"]), "cost": hiss_cost(m), "live": str(m["hybrid_live"]), "partner": str(m["hybrid_partner"]), "pair": str(m["hybrid_of"])})
	_say("HYBRID :: %s - %s is live (LB + %s, a T3 at %d Tension): %s" % [pname(), str(m["name"]).to_upper(), str(m["family"]), int(hiss_cost(m)), _hyb_live_text(m)])

func _hyb_elements(m: Dictionary) -> Array:
	# the pair's two elements, for the afterimage's colour
	if not m.has("hybrid_of"): return []
	var ks := str(m["hybrid_of"]).split("|")
	return [str(_club_card(str(ks[0])).get("element", "NONE")), str(_club_card(str(ks[1])).get("element", "NONE"))]

func _hyb_cast_note(m: Dictionary) -> void:
	# the registry counts the cast; its first cast in a dual is its debut (NP_07A Q-DELACROIX-CARDINAL's hook: "after your first dual using Two Rivers")
	var rec: Dictionary = rewards.get("hybrids", {}).get(str(m["hybrid_of"]), {})
	if rec.is_empty(): return
	rec["casts"] = int(rec.get("casts", 0)) + 1
	if int(rec.get("debut_day", 0)) == 0:
		rec["debut_day"] = int(rewards.get("day", 1))
		_ev("hybrid_debut", {"pair": str(m["hybrid_of"]), "name": str(m["name"]), "day": int(rec["debut_day"]), "houses": rec.get("houses", []).duplicate()})

func hybrid_registry() -> Array:
	# NP_11 s9's hybrid_registry[]: the Forge's records in the order forged
	var out: Array = []
	for k in _hyb_keys(): out.append(_hyb_reg()[k].duplicate(true))
	return out

# ============================ THE TRANSFORMATIONS (NP_09 s1, s3) ==============
# NP_09's ladder above the hissatsu: the SURGE motion spends the whole team bar (100, the FULL RELAY's 75) on the highest tier the fighter has
# unlocked - In the Zone is the one that runs. Its cinematic is a camera hold the world waits out (nothing moves, so nothing interrupts it);
# then 20 s of fight time: his timers at x0.75, the first incoming punch of every 3 s slipped, stamina frozen, counter windows +200 ms,
# punches +15 % speed; then the Comedown, 10 s at 85 % stats. One per fighter per dual; both end with the segment. Manager mode never surges
# on its own (the bar is the player's commitment); the SURGE call passes through delegation. Enemy transforms stay authored per boss.
func _zone_fx() -> Dictionary:
	# the live tier's effects (the Zone's, the Manifest's, Inheritance's; an Awakening's: the stacked tier's at 75 % and its own)
	if tform.has("fx"): return tform["fx"]
	return TRANS.get("tiers", {}).get(str(tform.get("tier", "zone")), {}).get("effects", {})

static func _frac(v) -> float:
	# a state's strength: true 1, false 0, a number itself (an Awakening's stacked state at 75 %)
	if v is bool: return 1.0 if v else 0.0
	return float(v)

func _zone_punch_mult() -> float:
	# the Zone's punches at +15 % speed: startup and recovery / 1.15
	return 1.0 / (1.0 + float(_zone_fx().get("punch_speed_pct", 0.0)) / 100.0) if tform.size() > 0 else 1.0

func _tier_word(tid: String, k: String) -> String:
	# the tier's words for the HUD and the feed ("hud", "state", "ends")
	var td: Dictionary = TRANS.get("tiers", {}).get(tid, {})
	return str(td.get("words", {}).get(k, str(td.get("name", tid)).to_upper() if k != "state" else "transformed"))

func _tier_unlocked(td: Dictionary, name: String) -> bool:
	# a tier's unlock (NP_09): a level and a flag; the Manifest's by the card - a named character's own story flag, a generic stablemate's
	# level and his Zone mastery flag ({name} is the fighter's)
	var un: Dictionary = td.get("unlock", {})
	if bool(un.get("awaken", false)): return _awaken_gate(name) and awaken_form(name) != ""            # PAC-085: Awakening - the story's gate and a tier to stack
	if bool(un.get("inherit", false)): return inherit_source(name).size() > 0                          # PAC-084: Inheritance - a source to inherit from
	if un.has("named") or un.has("generic"):
		un = un.get("generic" if bool(_card_of(name).get("generic", false)) else "named", {})
		if un.is_empty(): return false
	if un.has("level") and level_of(name) < int(un["level"]): return false
	if un.has("flag") and not _flag_set(str(un["flag"]).replace("{name}", name)): return false
	return true

func transform_tier(name: String) -> String:
	# the highest executed tier this fighter has unlocked (NP_09: a level and the story's flag), "" when none - Awakening over Inheritance over
	# the Manifest over the Zone - unless his card names a lower tier he has unlocked (surge_tier, chosen between duals)
	var best := ""; var bt := -1
	for tid in TRANS.get("tiers", {}):
		var td: Dictionary = TRANS["tiers"][tid]
		if not bool(td.get("executed", false)) or int(td.get("tier", 0)) <= bt: continue
		if not _tier_unlocked(td, name): continue
		best = str(tid); bt = int(td.get("tier", 0))
	var want := str(_card_of(name).get("surge_tier", ""))                                              # PAC-085: a lower tier his card names, when he has it
	if want != "" and want != best and TRANS["tiers"].has(want) and bool(TRANS["tiers"][want].get("executed", false)) and _tier_unlocked(TRANS["tiers"][want], name): return want
	return best

func manifest_of(name: String) -> Dictionary:
	# NP_09 s4: the named character's authored figure (the content lane's; the placeholder until then), a generic stablemate's his element's
	var md: Dictionary = TRANS.get("tiers", {}).get("manifest", {}).get("manifests", {})
	var card := _card_of(name)
	if bool(card.get("generic", false)):
		var g: Dictionary = md.get("generic", {}).get(str(card.get("element", "")), {})
		return {"name": str(g.get("name", "%s's manifest" % name)), "figure": g.get("figure"), "generic": true}
	var f: Dictionary = md.get("named", {}).get("figures", {}).get(name, {})
	return {"name": str(f.get("name", str(md.get("named", {}).get("placeholder", "{name}'s manifest")).replace("{name}", name))), "figure": f.get("figure"), "generic": false}

func _manifest_dmg() -> float:
	# NP_09 s4: all damage x1.4 while the manifest stands (the fighter's: tform is the player's)
	return float(_zone_fx().get("damage_mult", 1.0)) if tform.size() > 0 else 1.0

func _meter_pays(mv: Dictionary = {}) -> bool:
	# the private meter pays this move: every hissatsu while the Manifest stands (NP_09 s4: it brings its own fuel), only the inherited
	# natives in an Inheritance (s5: "their native technique set (cast from the private 50-pt meter)")
	if not tform.has("meter") or mv.has("duo_sync"): return false                                   # PAC-088: the pair's duo sync is the team bar's, once (NP_05 s1)
	return str(tform.get("meter_pays", "all")) == "all" or mv.has("inherited_from")

func purse(mv: Dictionary = {}) -> float:
	# what pays this hissatsu now: the private meter where it pays, else the team bar
	return float(tform["meter"]) if _meter_pays(mv) else tension

func can_pay(mv: Dictionary) -> bool:
	# the purse covers the move; SAVE THE BAR holds the team bar, never a private meter
	return purse(mv) >= hiss_cost(mv) and (_meter_pays(mv) or not (save_bar or bar_hold))

func _meter_word() -> String:
	return "the manifest's meter" if tform.has("manifest") else "the inherited meter"

func _echo_queue(dmg: float, src: Dictionary, row: String) -> void:
	# NP_09 s4: the manifest echoes a punch that landed clean, 0.3 s later, for 30 % of it
	var fx := _zone_fx()
	if tform.is_empty() or not tform.has("echoes") or float(fx.get("echo_pct", 0.0)) <= 0.0: return
	tform["echoes"].append({"t": ms(float(fx.get("echo_delay_s", 0.3)) * 1000.0), "dmg": dmg * float(fx["echo_pct"]) / 100.0, "src": src.duplicate(), "row": row})

func _echo_land(e: Dictionary) -> void:
	# the echo: the manifest's blow - no read, no Tension, no score; his timed wall stops it, his gauge takes it by the punch's own source
	if int(wall["B"].get("timed_t", 0)) > 0:
		_ev("echo", {"on": "B", "dmg": 0.0, "row": str(e["row"]), "walled": true}); return
	var src: Dictionary = e["src"].duplicate(); src["echo"] = true
	var d := _comp_damage("B", float(e["dmg"]), src)
	_ev("echo", {"on": "B", "dmg": d, "row": str(e["row"]), "walled": false})
	if B["comp"] <= 0.0: _drop(false, false)

func transform_cost(name: String = "") -> float:
	# NP_09 s1: the whole bar - 100, the FULL RELAY's 75 (NP_05 s6); no CHARGED half, no element edge. s5: a dual-house fighter inheriting his
	# own second house, 75 (it was always his)
	var sh: Dictionary = TRANS.get("shared", {})
	var c := float(TAC.get("corner", {}).get("full_relay_t4_cost", 75)) if full_relay else float(sh.get("cost", 100))
	if name != "" and transform_tier(name) == "inheritance" and str(inherit_source(name).get("kind", "")) == "second_house":
		c = minf(c, float(TRANS["tiers"]["inheritance"].get("unlock", {}).get("second_house_cost", 75)))
	return c

func transform_why(name: String) -> String:
	# why the SURGE would do nothing now ("" when it would transform)
	if TRANS.is_empty(): return "no transformation table"
	if bout.size() > 0: return "no transformation in a %s" % str(bout.get("kind", "bout"))
	if mode != "FIGHT": return "no transformation outside the fight"
	if tform.size() > 0: return "%s is already %s" % [name, _tier_word(str(tform["tier"]), "state")]
	if transformed.has(name): return "%s has transformed this dual (NP_09 s1: one per fighter per dual)" % name
	if cast.size() > 0: return "a cast is in flight"
	var tz: Dictionary = TRANS.get("tiers", {}).get("zone", {})
	if transform_tier(name) == "":
		var un: Dictionary = tz.get("unlock", {})
		if level_of(name) < int(un.get("level", 0)): return "%s is level %d - the Zone opens at %d" % [name, level_of(name), int(un.get("level", 0))]
		return "the Zone is taught at the Provincials semifinal (%s)" % str(un.get("flag", ""))
	if tension < transform_cost(name): return "the bar is at %d - a transformation takes the whole bar (%d)" % [int(tension), int(transform_cost(name))]
	return ""

func transform() -> Dictionary:
	# the SURGE: the cinematic's camera hold, then the tier's effects for its duration
	var nm := pname()
	var why := transform_why(nm)
	if why != "": _ev("transform_refused", {"who": nm, "why": why}); _say("SURGE - %s" % why); return {"ok": false, "why": why}
	var tid := transform_tier(nm)
	var td: Dictionary = TRANS["tiers"][tid]; var sh: Dictionary = TRANS.get("shared", {})
	var cost := transform_cost(nm); var paid := tension
	if bool(sh.get("empties_bar", true)): tension = 0.0
	else: tension = maxf(0.0, tension - cost)
	transformed[nm] = tid
	var cine := ms(float(sh.get("cinematic_ms", 0)))
	freeze_t = maxi(freeze_t, cine)                                                                     # the camera hold: the world waits, nothing interrupts it
	P["cmd"] = {}; P["pending"] = {}
	tform = {"tier": tid, "who": nm, "t": ms(float(td.get("duration_s", 20)) * 1000.0), "t0": tick + cine, "stam": float(P["stamina"]), "slip_win": -1, "cost": cost}
	if btform.size() > 0: btform["answered"] = true                                                  # PAC-086: SURGEd into his storm - answered, not weathered
	var fx: Dictionary = td.get("effects", {})
	var form := ""
	if bool(td.get("unlock", {}).get("awaken", false)):                                                  # PAC-085: Awakening - the chosen prior tier at 75 % and its own
		form = awaken_form(nm)
		var own: Dictionary = fx
		fx = _stack_fx(form, float(own.get("stack_pct", 75)))
		for k in own: fx[k] = own[k]
		tform["fx"] = fx; tform["form"] = form
	var mf := {}
	if fx.has("manifest_meter"):                                                                        # PAC-083: the Manifest - its figure, its own meter, its echoes in flight
		mf = manifest_of(nm)
		tform["manifest"] = str(mf["name"]); tform["meter"] = float(fx["manifest_meter"]); tform["meter_max"] = float(fx["manifest_meter"]); tform["echoes"] = []
	var ih := {}
	if _frac(fx.get("inherit_trait", false)) > 0.0:                                                     # PAC-084: Inheritance - the source's trait, natives, dialect
		ih = _inherit_begin(nm, fx)
		tform["inherit"] = ih; tform["meter"] = float(fx.get("private_meter", 50)); tform["meter_max"] = float(fx.get("private_meter", 50)); tform["meter_pays"] = str(fx.get("meter_pays", "inherited"))
	_ev("zone", {"who": nm, "tier": tid, "name": str(td.get("name", tid)), "cost": cost, "paid": paid, "full_relay": full_relay, "cinematic": cine, "seconds": float(td.get("duration_s", 20)), "stamina": float(P["stamina"]), "manifest": str(mf.get("name", "")), "meter": float(tform.get("meter", 0.0)),
		"source": str(ih.get("source", "")), "kind": str(ih.get("kind", "")), "house": str(ih.get("house", "")), "trait": str(ih.get("trait", {}).get("name", "")), "natives": ih.get("natives", []).duplicate(), "dressed": bool(ih.get("dressed", false)),
		"form": form, "stack_pct": float(fx.get("stack_pct", 0.0)), "ring_cap": float(fx.get("ring_cap", 0.0)), "drop_refund": float(fx.get("drop_refund", 0.0))})
	if form != "":
		_say("%s :: %s - the whole bar (%d of %d)%s; %ds: %s at %s%% (%s); the rings' caps x%s; every drop scored +%s Tension back; %s" % [str(td.get("name", tid)).to_upper(), nm, int(cost), int(paid), " - FULL RELAY" if full_relay else "", int(td.get("duration_s", 40)), str(TRANS["tiers"][form].get("name", form)), _n(float(fx.get("stack_pct", 75))), _form_text(form, fx, mf, ih), _n(float(fx.get("ring_cap", 1.5))), _n(float(fx.get("drop_refund", 0))), _hyb_slot_text(nm)])
		_hybrid_check("awakened")                                                                       # PAC-087: the slot opens one of his hybrids
	elif ih.size() > 0:
		_say("%s :: %s - the whole bar (%d of %d)%s; %ds: %s - the trait %s, the natives %s from a %d-point meter, the %s dialect worn (the enemy misreads %s); %s's own stats" % [str(td.get("name", tid)).to_upper(), nm, int(cost), int(paid), " - FULL RELAY" if full_relay else "", int(td.get("duration_s", 25)), inherit_label(ih), str(ih["trait"].get("name", "")) if ih["trait"].size() > 0 else "none", " / ".join(PackedStringArray(ih["natives"])) if ih["natives"].size() > 0 else "none", int(tform["meter"]), _house_name(str(ih["house"])), nm, nm])
	elif mf.size() > 0:
		_say("%s :: %s - the whole bar (%d of %d)%s; %ds: %s - all damage x%.2f, hissatsu from its own %d-point meter, every clean punch echoed at %.1fs for +%d%%, displacement x%d" % [str(td.get("name", tid)).to_upper(), nm, int(cost), int(paid), " - FULL RELAY" if full_relay else "", int(td.get("duration_s", 30)), str(mf["name"]), float(fx.get("damage_mult", 1.0)), int(fx["manifest_meter"]), float(fx.get("echo_delay_s", 0.0)), int(fx.get("echo_pct", 0)), int(fx.get("displace_mult", 1.0))])
	else:
		_say("%s :: %s - the whole bar (%d of %d)%s; %ds: the world at x%.2f, the first punch every %ds slipped, stamina frozen at %d, counter windows +%dms, punches +%d%% speed" % [str(td.get("name", tid)).to_upper(), nm, int(cost), int(paid), " - FULL RELAY" if full_relay else "", int(td.get("duration_s", 20)), float(fx.get("time_scale", 1.0)), int(fx.get("auto_slip_every_s", 0)), int(P["stamina"]), int(fx.get("counter_window_plus_ms", 0)), int(fx.get("punch_speed_pct", 0))])
	return {"ok": true, "why": "", "tier": tid, "cost": cost}

func _zone_tick() -> void:
	# the Zone's clock (fight time), its frozen stamina, its end into the Comedown, the Comedown's end
	if tform.size() > 0 and tform.has("echoes") and tform["echoes"].size() > 0:                        # PAC-083: the manifest's echoes in flight (fight time)
		var due: Array = []; var left: Array = []
		for e in tform["echoes"]:
			e["t"] = int(e["t"]) - 1
			if int(e["t"]) <= 0: due.append(e)
			else: left.append(e)
		tform["echoes"] = left
		for e in due:
			if mode != "FIGHT" or tform.is_empty(): break
			_echo_land(e)
		if mode != "FIGHT": return
	if tform.size() > 0:
		var fz := _frac(_zone_fx().get("stamina_frozen", false))
		if fz >= 1.0: P["stamina"] = float(tform["stam"])
		elif fz > 0.0:                                                                                   # PAC-085: stamina part-frozen - a quarter of its moves go through
			P["stamina"] = float(tform["stam"]) + (float(P["stamina"]) - float(tform["stam"])) * (1.0 - fz); tform["stam"] = float(P["stamina"])
		tform["t"] = int(tform["t"]) - 1
		if int(tform["t"]) <= 0:
			var sh: Dictionary = TRANS.get("shared", {}); var cd: Dictionary = sh.get("comedown", {})
			var scr_s := 0.0
			if tform.has("inherit"):                                                                     # PAC-084: the source's style leaves him; his own dialect comes back scrambled
				_inherit_end()
				scr_s = float(TRANS["tiers"][str(tform["tier"])].get("comedown", {}).get("dialect_scrambled_s", 0))
			var keep: Dictionary = P["stats"].duplicate()
			var st: Dictionary = P["stats"].duplicate()
			for k in st: st[k] = float(st[k]) * float(cd.get("stat_pct", 85)) / 100.0
			P["stats"] = st
			comedown = {"who": str(tform["who"]), "t": ms(float(cd.get("seconds", 10)) * 1000.0), "stats": keep}
			if scr_s > 0.0: comedown["scramble_t"] = ms(scr_s * 1000.0)
			_ev("zone_end", {"who": str(tform["who"]), "tier": str(tform["tier"]), "stamina": float(P["stamina"]), "comedown_s": float(cd.get("seconds", 10)), "stat_pct": float(cd.get("stat_pct", 85)), "scramble_s": scr_s})
			if tform.has("form"): _say("%s - %s comes down from the %s-Awakening: %ds at %d%%" % [_tier_word(str(tform["tier"]), "ends"), str(tform["who"]), str(tform["form"]).capitalize(), int(cd.get("seconds", 10)), int(cd.get("stat_pct", 85))])
			elif tform.has("inherit"): _say("%s - %s leaves %s (%d of the meter unspent); %ds at %d%%, %s's own dialect scrambled %ds" % [_tier_word(str(tform["tier"]), "ends"), _inherit_whose(tform["inherit"]), str(tform["who"]), int(tform["meter"]), int(cd.get("seconds", 10)), int(cd.get("stat_pct", 85)), str(tform["who"]), int(scr_s)])
			elif tform.has("meter"): _say("%s - %s's manifest leaves him (%d of its meter unspent); %ds at %d%%" % [_tier_word(str(tform["tier"]), "ends"), str(tform["who"]), int(tform["meter"]), int(cd.get("seconds", 10)), int(cd.get("stat_pct", 85))])
			else: _say("%s - %s comes down: %ds at %d%% (stamina resumes at %d)" % [_tier_word(str(tform["tier"]), "ends"), str(tform["who"]), int(cd.get("seconds", 10)), int(cd.get("stat_pct", 85)), int(P["stamina"])])
			tform = {}
	elif comedown.size() > 0:
		if int(comedown["t"]) > 0:
			comedown["t"] = int(comedown["t"]) - 1
			if int(comedown["t"]) <= 0: P["stats"] = comedown["stats"]
		if int(comedown.get("scramble_t", 0)) > 0: comedown["scramble_t"] = int(comedown["scramble_t"]) - 1         # PAC-084: his own dialect, scrambled
		if int(comedown["t"]) <= 0 and int(comedown.get("scramble_t", 0)) <= 0:
			_ev("comedown_end", {"who": str(comedown["who"])}); _say("%s is back to himself" % str(comedown["who"]))
			comedown = {}

func zone_line() -> String:
	# the HUD's line: the tier's clock and what it carries - an Awakening's stacked tier, the caps and the refund first - or the Comedown's
	if tform.size() > 0:
		var fx := _zone_fx()
		var head := "%s %.1fs" % [_tier_word(str(tform["tier"]), "hud"), float(tform["t"]) / TICK_HZ]
		if tform.has("form"): head += " | %s-Awakening at %s%% | ring caps x%s | a drop +%s" % [str(tform["form"]).capitalize(), _n(float(fx.get("stack_pct", 75))), _n(float(fx.get("ring_cap", 1.5))), _n(float(fx.get("drop_refund", 0)))]   # PAC-085
		if tform.has("inherit"):                                                                         # PAC-084: the source, the trait, the meter, the natives
			var ih: Dictionary = tform["inherit"]
			var mfr := _frac(fx.get("misread", false))
			return "%s | %s | %s | meter %d/%d | %s | the enemy misreads you%s" % [head, inherit_label(ih), str(ih["trait"].get("name", "no trait")) if ih["trait"].size() > 0 else "no trait", int(tform["meter"]), int(tform["meter_max"]), ", ".join(PackedStringArray(ih["natives"])) if ih["natives"].size() > 0 else "no natives", "" if mfr >= 1.0 else " (%s%%)" % _n(mfr * 100.0)]
		if tform.has("meter"):                                                                           # PAC-083: the manifest, its meter, its echo
			return "%s | %s | meter %d/%d | echo +%d%% at %.1fs | damage x%.1f" % [head, str(tform["manifest"]), int(tform["meter"]), int(tform["meter_max"]), int(fx.get("echo_pct", 0)), float(fx.get("echo_delay_s", 0.0)), float(fx.get("damage_mult", 1.0))]
		var every := ms(float(fx.get("auto_slip_every_s", 3)) * 1000.0)
		var el: int = maxi(0, tick - int(tform["t0"]))
		var ready: bool = el / maxi(1, every) != int(tform["slip_win"])
		var fz := _frac(fx.get("stamina_frozen", false))
		return "%s | %s | auto-slip %s" % [head, ("stamina frozen %d" % int(tform["stam"])) if fz >= 1.0 else ("stamina %s%% frozen" % _n(fz * 100.0)), "ready" if ready else "in %.1fs" % (float(every - el % every) / TICK_HZ)]
	if comedown.size() > 0: return "COMEDOWN %.1fs (%d%%)%s" % [maxf(0.0, float(comedown["t"])) / TICK_HZ, int(TRANS.get("shared", {}).get("comedown", {}).get("stat_pct", 85)), (" | own dialect scrambled %.1fs" % (float(comedown["scramble_t"]) / TICK_HZ)) if int(comedown.get("scramble_t", 0)) > 0 else ""]
	return ""

# ============================ THE ENEMY'S TRANSFORMATIONS (NP_09 s1, s4, s7) =
# A boss transforms only where his pattern authors it: a TRANSFORM line (pbn/, compiled), its trigger in the phase vocabulary, a tell at the
# ARMORED floor and a line said as it starts - he gathers, guard up, no attack; then the shared camera hold, his bar emptied, his tier on his
# side: the Zone (his timers at 1/0.75 outside his tells, his acting +15 %, the first player punch of every 3 s slipped, his stamina frozen)
# or the Manifest (his damage x1.4, his clean punches echoed, his displacement x2). His Comedown (10 s at 85 %) is the player's window.
# Both manifested at once: the Manifest Clash. Against his transformation the player weathers: each perfect block, slip or Clash exchange
# won shaves 1 s off it, and once weathered his damage is halved; weathered to its end unanswered and never down: Stood in the Storm.
func _bword(tid: String, kind: String) -> String:
	# the enemy side's words for a tier, no pronoun (a boss may be anyone): ENEMY ZONE, ENEMY MANIFEST; THE ENEMY'S ZONE ENDS
	var w: Dictionary = TRANS.get("tiers", {}).get(tid, {}).get("words", {})
	if kind == "ends": return str(w.get("ends", "THE %s ENDS" % tid.to_upper())).replace("THE ", "THE ENEMY'S ")
	return "ENEMY " + str(w.get("hud", tid.to_upper())).replace("IN THE ", "")

func _bfx() -> Dictionary:
	# his live tier's effects
	return TRANS.get("tiers", {}).get(str(btform.get("tier", "")), {}).get("effects", {}) if btform.size() > 0 else {}

func _bmanifest_dmg() -> float:
	return float(_bfx().get("damage_mult", 1.0)) if btform.size() > 0 else 1.0

func _weather_mult() -> float:
	# NP_09 s7: once the player has weathered his transformation, its damage to him is halved
	if btform.size() > 0 and int(btform.get("weathered", 0)) > 0: return float(TRANS.get("shared", {}).get("weathering", {}).get("damage_mult", 0.5))
	return 1.0

func _weather(why: String) -> void:
	# a perfect-defense action against his transformation: 1 s off it
	if btform.is_empty(): return
	var sh := ms(float(TRANS.get("shared", {}).get("weathering", {}).get("shave_s", 1)) * 1000.0)
	var cut: int = mini(sh, maxi(0, int(btform["t"]) - 1))
	btform["t"] = int(btform["t"]) - cut; btform["weathered"] = int(btform["weathered"]) + 1; btform["shaved"] = int(btform["shaved"]) + cut
	_ev("weather", {"why": why, "cut": cut, "left": int(btform["t"]), "weathered": int(btform["weathered"])})
	_say("WEATHERED (%s) - %s -%.1fs, %.1fs left" % [why.replace("_", " "), _bword(str(btform["tier"]), "hud").capitalize(), float(cut) / TICK_HZ, float(btform["t"]) / TICK_HZ])

func _boss_transform_check() -> bool:
	# his authored line: when its trigger holds, once a dual, he starts gathering (the tell the player feels coming)
	var tf: Dictionary = pattern.get("transform") if pattern.get("transform") != null else {}
	if not btransform_on or tf.is_empty() or btsurge.size() > 0 or btform.size() > 0 or bcomedown.size() > 0 or btransformed.has(boss_name) or bout.size() > 0: return false
	if not (bstate == "IDLE" or bstate == "RECOVER") or cast.size() > 0 or clinch.size() > 0: return false   # between his actions - never mid-string
	var tid := str(tf.get("tier", ""))
	if not TRANS.get("tiers", {}).has(tid) or not bool(TRANS["tiers"][tid].get("executed", false)) or not tid in TRANS.get("boss", {}).get("tiers", []): return false
	if not _phase_trigger_met(str(tf.get("trigger", ""))): return false
	btsurge = {"tier": tid, "t": ms(float(tf.get("tell", {}).get("ms", 1000))), "line": str(tf.get("line", ""))}
	bstate = "SURGE"; btimer = 1 << 30; bqueue = []; bpending = {}; B["pending"] = {}; bstring = ""
	B["guard_t"] = int(btsurge["t"]); B["counter_state_t"] = 0                                        # he gathers behind his guard - no trap in it
	_ev("boss_transform_tell", {"who": boss_label, "tier": tid, "ticks": int(btsurge["t"]), "line": str(btsurge["line"]), "motif": str(tf.get("tell", {}).get("motif", ""))})
	_say("!! %s GATHERS - %s" % [boss_label.to_upper(), str(btsurge["line"])])
	return true

func _boss_transform() -> void:
	# the gathering done: the camera hold, his bar emptied, his tier on his side
	var tf: Dictionary = pattern.get("transform") if pattern.get("transform") != null else {}
	var tid := str(btsurge["tier"]); btsurge = {}
	var td: Dictionary = TRANS["tiers"][tid]; var sh: Dictionary = TRANS.get("shared", {})
	btransformed[boss_name] = tid
	var cine := ms(float(sh.get("cinematic_ms", 0)))
	freeze_t = maxi(freeze_t, cine)
	btension = 0.0
	bstate = "IDLE"; btimer = ms(400); B["guard_t"] = 0
	btform = {"tier": tid, "who": boss_label, "t": ms(float(td.get("duration_s", 20)) * 1000.0), "t0": tick + cine, "stam": float(B["stamina"]), "slip_win": -1,
		"weathered": 0, "shaved": 0, "answered": tform.size() > 0, "dropped": false}
	if tid == "manifest": btform["manifest"] = str(tf.get("manifest", "%s's manifest" % boss_label)); btform["echoes"] = []
	var fx: Dictionary = td.get("effects", {})
	_ev("boss_zone", {"who": boss_label, "tier": tid, "name": str(td.get("name", tid)), "word": _bword(tid, "hud"), "seconds": float(td.get("duration_s", 20)), "cinematic": cine, "manifest": str(btform.get("manifest", ""))})
	if tid == "manifest": _say("%s :: %s - %ds: %s - the enemy's damage x%.2f, clean punches echoed +%d%%, displacement x%d" % [_bword(tid, "hud"), boss_label, int(td.get("duration_s", 30)), str(btform["manifest"]), float(fx.get("damage_mult", 1.0)), int(fx.get("echo_pct", 0)), int(fx.get("displace_mult", 1.0))])
	else: _say("%s :: %s - %ds: the world at x%.2f for the enemy (timers faster outside the tells), the first punch every %ds slipped, stamina frozen - weather it" % [_bword(tid, "hud"), boss_label, int(td.get("duration_s", 20)), float(fx.get("time_scale", 1.0)), int(fx.get("auto_slip_every_s", 0))])

func _becho_queue(dmg: float, src: Dictionary, row: String) -> void:
	# his manifest's echo of a punch that landed clean on the player
	var fx := _bfx()
	if not btform.has("echoes") or float(fx.get("echo_pct", 0.0)) <= 0.0: return
	btform["echoes"].append({"t": ms(float(fx.get("echo_delay_s", 0.3)) * 1000.0), "dmg": dmg * float(fx["echo_pct"]) / 100.0, "src": src.duplicate(), "row": row})

func _btform_tick() -> void:
	# his gathering, his transformation's clock (fight time), his echoes, his end into his Comedown, the Comedown's end; the Clash's start
	if btsurge.size() > 0:
		btsurge["t"] = int(btsurge["t"]) - 1
		if int(btsurge["t"]) <= 0: _boss_transform()
		return
	if btform.size() > 0:
		if tform.size() > 0: btform["answered"] = true
		if btform.has("echoes") and btform["echoes"].size() > 0:
			var due: Array = []; var left: Array = []
			for e in btform["echoes"]:
				e["t"] = int(e["t"]) - 1
				if int(e["t"]) <= 0: due.append(e)
				else: left.append(e)
			btform["echoes"] = left
			for e in due:
				if mode != "FIGHT" or btform.is_empty(): break
				var src: Dictionary = e["src"].duplicate(); src["echo"] = true
				var d := _comp_damage("P", float(e["dmg"]) * _weather_mult(), src)
				_ev("echo", {"on": "P", "dmg": d, "row": str(e["row"]), "walled": false})
				if P["comp"] <= 0.0: _drop(true)
			if mode != "FIGHT" or btform.is_empty(): return
		if _frac(_bfx().get("stamina_frozen", false)) >= 1.0: B["stamina"] = float(btform["stam"])
		btform["t"] = int(btform["t"]) - 1
		if int(btform["t"]) <= 0: _boss_tform_end(false)
	elif bcomedown.size() > 0:
		bcomedown["t"] = int(bcomedown["t"]) - 1
		if int(bcomedown["t"]) <= 0:
			B["stats"] = bcomedown["stats"]
			_ev("boss_comedown_end", {"who": str(bcomedown["who"])}); _say("%s comes back up - the window shuts" % str(bcomedown["who"]))
			bcomedown = {}
	var cl: Dictionary = TRANS.get("tiers", {}).get("manifest", {}).get("clash", {})
	if mclash.is_empty() and bool(cl.get("executed", false)) and tform.has("manifest") and btform.has("manifest") and not bool(tform.get("clashed", false)) and not bool(btform.get("clashed", false)) and freeze_t <= 0:
		_clash_start()

func _boss_tform_end(suppressed: bool) -> void:
	# his transformation over: the Comedown (the player's window); weathered to its end unanswered and never down - Stood in the Storm
	var cd: Dictionary = TRANS.get("shared", {}).get("comedown", {})
	var keep: Dictionary = B["stats"].duplicate(); var st: Dictionary = B["stats"].duplicate()
	for k in st: st[k] = float(st[k]) * float(cd.get("stat_pct", 85)) / 100.0
	B["stats"] = st
	bcomedown = {"who": str(btform["who"]), "t": ms(float(cd.get("seconds", 10)) * 1000.0), "stats": keep}
	var stood: bool = not suppressed and not bool(btform["answered"]) and not bool(btform["dropped"]) and int(btform["weathered"]) > 0
	_ev("boss_zone_end", {"who": str(btform["who"]), "tier": str(btform["tier"]), "weathered": int(btform["weathered"]), "shaved": int(btform["shaved"]), "answered": bool(btform["answered"]), "suppressed": suppressed, "stood": stood, "comedown_s": float(cd.get("seconds", 10)), "stat_pct": float(cd.get("stat_pct", 85))})
	_say("%s%s - %s comes down: %ds at %d%% - YOUR WINDOW (weathered %d, %.1fs shaved)" % [_bword(str(btform["tier"]), "ends"), " (SUPPRESSED)" if suppressed else "", str(btform["who"]), int(cd.get("seconds", 10)), int(cd.get("stat_pct", 85)), int(btform["weathered"]), float(btform["shaved"]) / TICK_HZ])
	if stood: _feat(str(TRANS.get("shared", {}).get("weathering", {}).get("feat", "stood_in_the_storm")), str(btform["who"]))
	if stood: _trial_mark(pname(), "storm")                                                             # PAC-090: NP_11 s4's trial - he weathered a transform
	btform = {}

func _feat(fid: String, against: String) -> void:
	# a feat on the ledger (NP_09 s7's "authored achievement"), counted, with the day and whom
	if not rewards.has("feats"): rewards["feats"] = {}
	var rec: Dictionary = rewards["feats"].get(fid, {"count": 0})
	rec["count"] = int(rec.get("count", 0)) + 1; rec["day"] = int(rewards.get("day", 1)); rec["last"] = against
	rewards["feats"][fid] = rec
	var nm := str(TRANS.get("shared", {}).get("weathering", {}).get(fid, {}).get("name", fid))
	_ev("feat", {"id": fid, "name": nm, "against": against, "count": int(rec["count"])})
	_gw_honour("feat", "feat:" + fid, "%s - %s" % [nm, against])                                         # PAC-089: the honours set, from The Wall's tier
	_say("%s - %s weathered %s's transformation without answering" % [nm.to_upper(), pname(), against])

func _clash_start() -> void:
	# NP_09 s4: both manifested - the fight stops for the scripted sub-duel
	var cl: Dictionary = TRANS["tiers"]["manifest"]["clash"]
	var n := int(cl.get("exchanges", 5)); var dur := ms(float(cl.get("seconds", 5)) * 1000.0)
	var cues: Array = []; var kinds: Array = []
	for i in n:
		cues.append(int(float(dur) * (float(i) + 0.5) / float(n)))
		kinds.append("defend" if i % 2 == 0 else "attack")
	var win := ms(float(cl.get("window_ms", 180)) / maxf(0.01, float(cl.get("time_scale", 0.5))))
	mclash = {"t": 0, "dur": dur, "cues": cues, "kinds": kinds, "window": win, "i": 0, "won": [], "block_prev": true, "p": str(tform.get("manifest", "")), "b": str(btform.get("manifest", ""))}
	tform["clashed"] = true; btform["clashed"] = true
	mode = "CLASH"; P["cmd"] = {}; P["pending"] = {}; bqueue = []; bpending = {}; B["pending"] = {}; bstate = "IDLE"; btimer = ms(400); cast = {}
	_ev("clash_start", {"p": str(mclash["p"]), "b": str(mclash["b"]), "exchanges": n, "window": win, "cues": cues, "kinds": kinds})
	_say("MANIFEST CLASH - %s against %s: %d exchanges, the enemy strikes first - block or slip on theirs, punch on yours" % [str(mclash["p"]), str(mclash["b"]), n])

func _clash_step(inp: Dictionary) -> void:
	# the exchanges: a press inside its window wins it, outside loses it, none by the window's end loses it; pure timing
	mclash["t"] = int(mclash["t"]) + 1
	var t: int = int(mclash["t"]); var i: int = int(mclash["i"])
	var n: int = mclash["cues"].size()
	var blk: bool = inp.get("block", false)
	var blk_edge: bool = blk and not bool(mclash["block_prev"]); mclash["block_prev"] = blk
	if i < n:
		var cue: int = int(mclash["cues"][i]); var w: int = int(mclash["window"]); var kind: String = str(mclash["kinds"][i])
		var pressed: bool = (inp.has("punch") if kind == "attack" else (blk_edge or inp.has("dodge")))
		if delegated:                                                                                  # manager mode: the card presses on the cue, six times in ten; the pad is not his
			pressed = t == cue and rng.randf() * 100.0 < float(TRANS["tiers"]["manifest"]["clash"].get("delegated_hit_pct", 60))
		var res := ""
		if pressed: res = "won" if absi(t - cue) <= w else "early"
		elif t > cue + w: res = "missed"
		if res != "":
			mclash["won"].append(res == "won"); mclash["i"] = i + 1
			_ev("clash_exchange", {"n": i + 1, "kind": kind, "result": res, "off": t - cue})
			if res == "won": _weather("clash_exchange")
	if t >= int(mclash["dur"]) and int(mclash["i"]) >= n: _clash_end()

func _clash_end() -> void:
	var cl: Dictionary = TRANS["tiers"]["manifest"]["clash"]
	var wins := 0
	for w in mclash["won"]:
		if bool(w): wins += 1
	var p_won: bool = wins >= int(cl.get("to_win", 3))
	mode = "FIGHT"
	_ev("clash_end", {"won": wins, "of": mclash["won"].size(), "winner": "P" if p_won else "B"})
	_say("CLASH %s - %d of %d: %s" % ["WON" if p_won else "LOST", wins, mclash["won"].size(), "your manifest suppresses the enemy's" if p_won else "the enemy's manifest suppresses yours"])
	mclash = {}
	if p_won and btform.size() > 0: _boss_tform_end(true)
	elif not p_won and tform.size() > 0: tform["t"] = 1                                                # the loser's manifest ends: yours, into your Comedown on the next tick

func bzone_line() -> String:
	# the HUD's line for his side: his gathering, his transformation (weathered), his Comedown (your window), or the Clash
	if mclash.size() > 0:
		var i: int = int(mclash["i"]); var n: int = mclash["cues"].size()
		var wins := 0
		for w in mclash["won"]:
			if bool(w): wins += 1
		var cue_s := ""
		if i < n: cue_s = "%s in %.2fs" % ["BLOCK or SLIP" if str(mclash["kinds"][i]) == "defend" else "PUNCH", float(int(mclash["cues"][i]) - int(mclash["t"])) / TICK_HZ]
		return "MANIFEST CLASH %d/%d | %s | won %d lost %d" % [mini(i + 1, n), n, cue_s if cue_s != "" else "resolving", wins, mclash["won"].size() - wins]
	if btsurge.size() > 0: return "GATHERING %.1fs | %s" % [float(btsurge["t"]) / TICK_HZ, str(btsurge["line"])]
	if btform.size() > 0:
		return "%s %.1fs | weathered %d (-%.1fs)%s%s" % [_bword(str(btform["tier"]), "hud"), float(btform["t"]) / TICK_HZ, int(btform["weathered"]), float(btform["shaved"]) / TICK_HZ, (" | " + str(btform["manifest"])) if btform.has("manifest") else "", " | damage to you halved" if int(btform["weathered"]) > 0 else ""]
	if bcomedown.size() > 0: return "ENEMY COMEDOWN %.1fs (%d%%) - your window" % [float(bcomedown["t"]) / TICK_HZ, int(TRANS.get("shared", {}).get("comedown", {}).get("stat_pct", 85))]
	return ""

# ============================ AWAKENING (NP_09 s6) ==========================
# The summit: gated per character by the story (his house's SECRET learned, his Arc 3 trial; the protagonist's sealed house resolved as well),
# it stacks a chosen prior tier's effects at 75 % strength for 40 s, raises his rings' caps from x1.5 to x1.75 and refunds 15 Tension to the
# bar for every drop he scores. The hybrid slot opens on nothing: no hybrid technique exists. The tier a SURGE casts and the tier an
# Awakening stacks are the card's to choose between duals.
func _awaken_gate(name: String) -> bool:
	if not awaken_eligible(name): return false                                                           # PAC-090: NP_11 s4 - a generic's Awakening flag is the Legend's (tier 4)
	var un: Dictionary = TRANS.get("tiers", {}).get("awakening", {}).get("unlock", {})
	var fl: Array = un.get("flags", []).duplicate()
	var pr: Dictionary = un.get("protagonist", {})
	if str(pr.get("card", "")) == name: fl.append_array(pr.get("flags", []))
	for f in fl:
		if not _flag_set(str(f).replace("{name}", name)): return false
	return fl.size() > 0

func awaken_form(name: String) -> String:
	# the prior tier his Awakening stacks: the card's awakening_form when he has it unlocked, else his highest prior tier unlocked
	var aw: Dictionary = TRANS.get("tiers", {}).get("awakening", {})
	var want := str(_card_of(name).get("awakening_form", ""))
	var best := ""; var bt := -1
	for tid in TRANS.get("tiers", {}):
		var td: Dictionary = TRANS["tiers"][tid]
		if str(tid) == "awakening" or not bool(td.get("executed", false)) or int(td.get("tier", 0)) >= int(aw.get("tier", 5)): continue
		if not _tier_unlocked(td, name): continue
		if str(tid) == want: return want
		if int(td.get("tier", 0)) > bt: best = str(tid); bt = int(td.get("tier", 0))
	return best

func _stack_fx(form: String, pct: float) -> Dictionary:
	# a prior tier's effects at pct % strength, by the table's stack_rules: a multiplier's reach, an amount, a period's frequency, a state
	var base: Dictionary = TRANS.get("tiers", {}).get(form, {}).get("effects", {})
	var rules: Dictionary = TRANS.get("tiers", {}).get("awakening", {}).get("stack_rules", {})
	var sc := pct / 100.0
	var out := {}
	for k in base:
		var v = base[k]
		match str(rules.get(k, "keep")):
			"mult": out[k] = 1.0 + (float(v) - 1.0) * sc
			"add": out[k] = float(v) * sc
			"period": out[k] = float(v) / sc if sc > 0.0 else 0.0
			"fraction": out[k] = _frac(v) * sc
			_: out[k] = v
	return out

static func _n(v: float) -> String:
	# a number as the feed writes it: 4, 37.5, 11.25, 0.81
	return ("%.2f" % snappedf(v, 0.01)).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func _form_text(form: String, fx: Dictionary, mf: Dictionary, ih: Dictionary) -> String:
	match form:
		"zone": return "the world at x%s, the first punch every %ss slipped, stamina %s%% frozen, counter windows +%sms, punches +%s%% speed" % [_n(float(fx.get("time_scale", 1.0))), _n(float(fx.get("auto_slip_every_s", 0))), _n(_frac(fx.get("stamina_frozen", false)) * 100.0), _n(float(fx.get("counter_window_plus_ms", 0))), _n(float(fx.get("punch_speed_pct", 0)))]
		"manifest": return "%s - damage x%s, hissatsu from a %s-point meter, clean punches echoed +%s%%, displacement x%s" % [str(mf.get("name", "")), _n(float(fx.get("damage_mult", 1.0))), _n(float(fx.get("manifest_meter", 0))), _n(float(fx.get("echo_pct", 0))), _n(float(fx.get("displace_mult", 1.0)))]
		"inheritance": return "%s - the trait %s at %s%%, the natives from a %s-point meter, %s%% of the enemy's reads misreads" % [inherit_label(ih), str(ih.get("trait", {}).get("name", "none")) if ih.get("trait", {}).size() > 0 else "none", _n(_frac(fx.get("inherit_trait", false)) * 100.0), _n(float(fx.get("private_meter", 0))), _n(_frac(fx.get("misread", false)) * 100.0)]
	return ""

func choose_surge(nm: String, key: String, tier: String) -> Dictionary:
	# between duals: the tier his SURGE casts (key "tier") or the prior tier his Awakening stacks ("form"); "" gives it back to his highest
	var c := _stable_card(nm)
	if c.is_empty(): c = _card_of(nm)
	var field := "surge_tier" if key == "tier" else ("awakening_form" if key == "form" else "")
	var why := ""
	var td: Dictionary = TRANS.get("tiers", {}).get(tier, {})
	if c.is_empty(): why = "%s is not in the stable" % nm
	elif field == "": why = "a SURGE chooses a tier or an Awakening's form"
	elif mode != "OVER": why = "between duals only"
	elif tier != "":
		if td.is_empty() or not bool(td.get("executed", false)): why = "%s is no transformation the sim runs" % tier
		elif key == "form" and int(td.get("tier", 0)) >= int(TRANS["tiers"].get("awakening", {}).get("tier", 5)): why = "an Awakening stacks a prior tier - the Zone, the Manifest or Inheritance"
		elif not _tier_unlocked(td, nm): why = "%s has not unlocked %s" % [nm, str(td.get("name", tier))]
	if why != "": _ev("surge_choice_refused", {"card": nm, "key": key, "tier": tier, "why": why}); return {"ok": false, "why": why}
	for arr in [stable, dressed, lineup, reserves]:
		for cc in arr:
			if cc is Dictionary and str(cc.get("name", "")) == nm:
				if tier == "": cc.erase(field)
				else: cc[field] = tier
	_ev("surge_choice", {"card": nm, "key": key, "tier": tier})
	_say("%s's %s: %s" % [nm, "SURGE" if key == "tier" else "Awakening", str(td.get("name", tier)) if tier != "" else "his highest"])
	return {"ok": true, "why": "", "tier": tier}

func surge_line(name: String) -> String:
	# the matchup card's SURGE line: what his SURGE casts now, and what an Awakening stacks
	var tid := transform_tier(name)
	if tid == "": return ""
	var td: Dictionary = TRANS["tiers"][tid]
	var out := "SURGE: %s (%d)" % [str(td.get("name", tid)), int(transform_cost(name))]                  # the tier's name as written: the HUD's upper-case lines stay the live tier's
	if tid == "awakening": out += " - %s-Awakening at %s%%" % [awaken_form(name).capitalize(), _n(float(td.get("effects", {}).get("stack_pct", 75)))]
	var want := str(_card_of(name).get("surge_tier", ""))
	if want != "" and want == tid: out += " - his choice"
	return out

# ============================ INHERITANCE (NP_09 s5) ========================
# The SURGE casts Inheritance where the fighter has a source: a story-flagged legacy (an authored gift), a stablemate of another house at
# Sworn (Kizuna Lv5), or - a dual-house fighter - his own second house, at 75. For 25 s he carries the source's house trait beside his own,
# the source's natives answering their motions from a private 50-point meter, and the source's dialect: every read the enemy makes of his
# punches is a misread. His own stats, style and house rings stay. The Comedown adds his own dialect scrambled 10 s: his feints draw nothing.
func inherit_sources(name: String) -> Array:
	# every source he could inherit, in NP_09 s5's order as the table keeps it: the legacy (the story put it there), the Sworn stablemate
	# with the most Kizuna points (the stable's order on a tie), his own second house
	var td: Dictionary = TRANS.get("tiers", {}).get("inheritance", {})
	var un: Dictionary = td.get("unlock", {})
	var out: Array = []
	if td.is_empty(): return out
	var card := _card_of(name)
	if card.is_empty(): card = _stable_card(name)
	var mine := house_key(str(card.get("house", "none")))
	var by := {"legacy": [], "sworn": [], "second_house": []}
	for lid in td.get("legacy_sources", {}):
		var ls: Dictionary = td["legacy_sources"][lid]
		if ls.get("house") == null or house_key(str(ls["house"])) == "none": continue
		if not _flag_set(str(ls.get("flag", "legacy:{id}")).replace("{id}", str(lid))): continue
		by["legacy"].append({"kind": "legacy", "id": str(lid), "source": str(ls["name"]) if ls.get("name") != null else str(lid), "house": house_key(str(ls["house"]))})
	var sw: Array = []; var ix := 0
	for c in stable:
		var sn := str(c.get("name", ""))
		var h := house_key(str(c.get("house", "none")))
		ix += 1
		if sn == name or h == "none" or h == mine or kizuna_level(name, sn) < inherit_level(): continue
		sw.append({"kind": "sworn", "id": sn, "source": sn, "house": h, "pts": kizuna_pts(name, sn), "ix": ix})
	sw.sort_custom(func(a, b): return int(a["pts"]) > int(b["pts"]) or (int(a["pts"]) == int(b["pts"]) and int(a["ix"]) < int(b["ix"])))
	by["sworn"] = sw
	var h2 := house_key(str(card.get(str(un.get("second_house_field", "house2")), "none")))
	if h2 != "none" and h2 != mine: by["second_house"].append({"kind": "second_house", "id": name, "source": name, "house": h2})
	for k in un.get("source_order", ["legacy", "sworn", "second_house"]): out.append_array(by.get(str(k), []))
	return out

func inherit_level() -> int:
	# the Kizuna level whose effects carry the Inheritance (NP_08 s5.2 Lv5 Sworn); none, no bond reaches it
	var fx: Dictionary = ECO.get("kizuna", {}).get("effects", {})
	for k in fx:
		if bool(fx[k].get("inheritance", false)): return int(k)
	return 99

func inherit_source(name: String) -> Dictionary:
	var srcs := inherit_sources(name)
	return srcs[0] if srcs.size() > 0 else {}

func _house_name(h: String) -> String:
	return str(HOUSES.get("houses", {}).get(h, {}).get("name", h.capitalize()))

func _inherit_whose(ih: Dictionary) -> String:
	# "SAM's House Tagaq style", "House Okafor, MARTA's second house,"
	if str(ih.get("kind", "")) == "second_house": return "House %s, %s's second house," % [_house_name(str(ih.get("house", ""))), str(ih.get("source", ""))]
	return "%s's House %s style" % [str(ih.get("source", "")), _house_name(str(ih.get("house", "")))]

func inherit_label(ih: Dictionary) -> String:
	# "House Tagaq from SAM (Sworn)", "House Whitecloud - THE OLD COACH's (legacy)", "House Okafor - MARTA's second house"
	var hn := _house_name(str(ih.get("house", "")))
	match str(ih.get("kind", "")):
		"legacy": return "House %s - %s's (legacy)" % [hn, str(ih.get("source", ""))]
		"second_house": return "House %s - %s's second house" % [hn, str(ih.get("source", ""))]
	return "House %s from %s (Sworn)" % [hn, str(ih.get("source", ""))]

func _inherit_begin(nm: String, fx: Dictionary) -> Dictionary:
	# the source's trait onto P beside his own, his natives (the move he carries first), a stat trait's scale kept to undo
	var src := inherit_source(nm)
	var h := str(src.get("house", "none"))
	var trt := {}
	var nat: Array = []
	if str(src["kind"]) == "sworn":
		var sc := _stable_card(str(src["source"]))
		trt = card_trait(sc)
		var carried := str(sc.get("hissatsu", ""))
		var ns := natives_unlocked(str(src["source"]))
		if carried in ns: nat.append(carried)
		for n in ns:
			if not n in nat: nat.append(n)
	else:
		trt = trait_of_house(h)
		nat = house_natives(h)
	var ih := {"kind": str(src["kind"]), "source": str(src["source"]), "id": str(src.get("id", "")), "house": h, "trait": trt.duplicate(), "natives": nat, "stats_before": {},
		"dressed": str(src["kind"]) == "sworn" and dressed.any(func(c): return str(c.get("name", "")) == str(src["source"]))}
	var tf := _frac(fx.get("inherit_trait", false))
	if tf > 0.0 and trt.size() > 0:
		if tf < 1.0: trt = trt.duplicate(); trt["x"] = float(trt["x"]) * tf                              # PAC-085: an Awakening's Inheritance - the trait's magnitudes at 75 %
		P["trait_inh"] = trt
		var sm := _trait_stat_mult({"trait": trt, "house": h}, str(B["house"]))                          # a stat trait (Long Winter, Debt of Honour) scales his stats while he wears it
		if sm != 1.0:
			ih["stats_before"] = P["stats"].duplicate()
			var st: Dictionary = P["stats"].duplicate()
			for k in st: st[k] = minf(99.0, float(st[k]) * sm)
			P["stats"] = st
	return ih

func _inherit_end() -> void:
	# the source's style leaves: his trait alone again, his stats as they stood
	P["trait_inh"] = {}
	var ih: Dictionary = tform.get("inherit", {})
	if ih.get("stats_before", {}).size() > 0: P["stats"] = ih["stats_before"]

func inherited_moves() -> Array:
	# the source's natives, marked as his - live only while he inherits, answering their own family's motion
	var out: Array = []
	if not tform.has("inherit"): return out
	for n in tform["inherit"]["natives"]:
		if not library.has(n): continue
		var m: Dictionary = library[n].duplicate()
		m["inherited_from"] = str(tform["inherit"]["source"]); m["inherit_house"] = str(tform["inherit"]["house"])
		out.append(m)
	return out

func wall_motion() -> bool:
	# the WALL motion completed (LB + block held 400 ms): his WALL-family move goes up if it can (PAC-088: the exhibition's coordinator calls
	# it too, when a duo sync it held the motion for goes unanswered)
	var mv_w := wall_move()
	if mv_w.is_empty() or str(mv_w["family"]) != "WALL" or not cast.is_empty() or not castable(mv_w) or not can_pay(mv_w): return false
	_start_cast("P", mv_w)
	return true

func wall_move() -> Dictionary:
	# the WALL motion: an inherited WALL native the meter can pay, else the card's own
	for m in inherited_moves():
		if str(m["family"]) == "WALL" and castable(m) and can_pay(m): return m
	var own := player_move()                                                                             # PAC-091: his own WALL, else the kit's
	if own.size() > 0 and str(own["family"]) == "WALL": return own
	for mv in P.get("kit", []):
		var mk: Dictionary = library.get(str(mv), {})
		if mk.size() > 0 and str(mk["family"]) == "WALL" and castable(mk) and can_pay(mk): return mk
	return own

func inherit_pick() -> Dictionary:
	# manager mode's inherited native: the one with the most damage in it the meter can pay (a WALL is raised by his cast rule, not here)
	var best: Dictionary = {}; var bv := -1.0
	for m in inherited_moves():
		if str(m["family"]) == "WALL" or not castable(m) or not can_pay(m): continue
		var v := _t3_power(m)
		if v > bv + 0.000001: bv = v; best = m
	return best

func _misread_frac() -> float:
	# the source's dialect worn: the enemy reads the wrong language (s5: "enemies literally misread you") - every read, or 75 % of them in an
	# Inheritance-Awakening
	return _frac(_zone_fx().get("misread", false)) if tform.has("inherit") else 0.0

# ============================ THE RELAY'S OWN T3 (NP_05 s6-s7) ==============
# NP_05 s6: the fighter out CHARGED has "T3 moves unlocked for their segment" - whatever his card carries. The relay opens the library's moves
# of the relay sources (tactics' relay_t3_opens: Coast to Coast, Aurora Chain) and, on a FULL RELAY only, the chain's own (North Star); each
# answers its own family's motion, a Duo's named variant standing in for its base, the previous fighter's afterimage joining (s7). A stolen
# CHARGED (Borrowed Blood) closes them; the Duo, the bond's, stays.
func relay_moves() -> Array:
	var out: Array = []
	if not t3_unlocked or bout.size() > 0: return out
	var c: Dictionary = TAC.get("corner", {})
	var dm := duo_move()
	for nm in library:
		var m: Dictionary = library[nm]
		var src := str(m.get("source", ""))
		if str(m["tier"]) != "T3" or not (src in c.get("relay_t3_opens", []) or (src in c.get("full_relay_t3_opens", []) and full_relay)): continue
		out.append(dm if dm.size() > 0 and str(dm.get("duo_of", "")) == str(nm) else m)
	return out

func _t3_power(m: Dictionary) -> float:
	# the damage a T3 carries: its DMG multipliers (North Star's base and the chain's links), the same-element spike (NP_06 s2.1)
	var v := 0.0
	for e in m["effect"]:
		if str(e["type"]) != "DMG": continue
		var pr: Dictionary = e["params"]
		v += (float(pr["base"]) + float(pr.get("mult_per_chain_link", 0.0)) * float(relay_chain)) if pr.has("base") else float(pr.get("mult", 0.0))
	if element_key(str(m.get("element", ""))) == str(P.get("element", "NONE")) and str(P.get("element", "NONE")) != "NONE": v *= float(AFF.get("element", {}).get("same_element_spike", 1.3))
	return v

func t3_pick() -> Dictionary:
	# manager mode's T3: the pair's live hybrid first (PAC-087), a live Duo's next (C34), else the open relay T3 with the most damage in it -
	# each only while castable and paid for
	var hm := hybrid_move()
	if hm.size() > 0 and castable(hm) and can_pay(hm): return hm
	var dm := duo_move()
	if dm.size() > 0 and castable(dm) and can_pay(dm): return dm
	var best: Dictionary = {}; var bv := -1.0
	for m in relay_moves():
		if not castable(m) or not can_pay(m): continue
		var v := _t3_power(m)
		if v > bv + 0.000001: bv = v; best = m
	return best

func relay_line() -> String:
	# what the relay opens this segment, priced (the matchup card, the whiteboard, the feed)
	var rm := relay_moves()
	if rm.is_empty(): return ""
	return ", ".join(PackedStringArray(rm.map(func(m): return "%s (LB + %s, %d)" % [str(m["name"]), str(m["family"]), int(hiss_cost(m))])))

func _relay_check() -> void:
	# at the segment's load: the fighter out CHARGED - the T3s his relay opens, on the feed and as an event
	var rm := relay_moves()
	if rm.is_empty(): return
	var ghost := str(lineup[seg_idx - 1]["name"]) if seg_idx > 0 and seg_idx - 1 < lineup.size() else ""
	_ev("relay_open", {"seg": seg_idx + 1, "who": pname(), "moves": rm.map(func(m): return str(m["name"])), "families": rm.map(func(m): return str(m["family"])), "costs": rm.map(func(m): return hiss_cost(m)), "chain": relay_chain, "full_relay": full_relay, "afterimage": ghost})
	_say("RELAY :: %s opens %s%s" % [pname(), relay_line(), (" - %s's afterimage joins" % ghost) if ghost != "" else ""])

# ============================ THE FORMATION SCREEN (NP_10 s2-3, NP_01 s7) ==
func bell_rung() -> bool:
	# the dual has begun: a tick fought, a segment ended or gone by (before it, the formation screen is live and a board can be sealed)
	return tick > dual_t0 or seg_idx > 0 or mode != "FIGHT" or r6

func board_k() -> int:
	# the slots a board fills: one per segment, fewer when fewer are dressed (the Iron dual repeats them, the Gauntlet has one)
	return mini(segments(), dressed.size())

func _board_fits() -> bool:
	if board.is_empty() or board.get("slots", []).size() != board_k(): return false
	for nm in board["slots"] + board.get("reserves", []):
		if _card_of(str(nm)).is_empty(): return false
	return true

# ============================ THE STAFF (NP_10 s6) =========================
const STAFF_NONSTACK := ["overrun_stamina_pct", "tension_start"]   # a floor and a start: the best one dressed counts, they do not add

func staff_dressed() -> Array:
	# NP_10 s2 / s6: the board's 3 staff (corps ids); with no board sealed, tactics.v1.json's equipped actives, each worked by the first staffer who carries it
	if board.has("staff"): return board["staff"]
	return _resolve_staff(TAC.get("equipped", {}).get("staff", []))

func _corps_rec(sid: String) -> Dictionary:
	for c in STAFF.get("corps", []):
		if str(c.get("id", "")) == sid: return c
	return {}

func _staff_active_rec(aid: String) -> Dictionary:
	for st in TAC.get("staff_active", []):
		if str(st["id"]) == aid: return st
	return {}

func _resolve_staff(ids: Array) -> Array:
	# staffer ids as given; an active's id names the first corps staffer who carries it and is not already in the list
	var out: Array = []
	for x in ids:
		var sid := str(x)
		if STAFF.get("corps", []).is_empty() or _corps_rec(sid).size() > 0: out.append(sid); continue
		var found := ""
		for c in STAFF.get("corps", []):
			if str(c.get("active", "")) == sid and not (str(c["id"]) in out): found = str(c["id"]); break
		out.append(found if found != "" else sid)
	return out

func staff_active_of(sid: String) -> String:
	var c := _corps_rec(sid)
	return str(c.get("active", "")) if c.size() > 0 else (sid if _staff_active_rec(sid).size() > 0 else "")

func staff_role(sid: String) -> String:
	var c := _corps_rec(sid)
	return str(c.get("role", "")) if c.size() > 0 else str(_staff_active_rec(sid).get("role", ""))

func staff_name(sid: String) -> String:
	return str(_corps_rec(sid).get("name", sid))

func _dressed_with_active(aid: String) -> Array:
	var out: Array = []
	for sid in staff_dressed():
		if staff_active_of(str(sid)) == aid: out.append(str(sid))
	return out

func staff_uses(sid: String) -> int: return int(rewards.get("staff", {}).get(sid, 0))

func staff_level(sid: String) -> int:
	# NP_10 s6: "staff level via use" - every charge he spends is one use (the reward ledger); the table's thresholds, Lv3 the second passive
	var lv := 1
	var th: Dictionary = STAFF.get("levels", {})
	for k in th:
		if staff_uses(sid) >= int(th[k]): lv = maxi(lv, int(k))
	return lv

func staff_passives() -> Dictionary:
	# NP_10 s6: every dressed staffer's role passive, and his role's second once he is Lv3; numbers add across the dressed (two cutmen, two
	# restores), a floor or a start takes the best, flags hold; "by" names who carries each
	var out := {"by": {}}
	var roles: Dictionary = STAFF.get("roles", {})
	for sid in staff_dressed():
		var rr: Dictionary = roles.get(staff_role(str(sid)), {})
		var parts: Array = [rr.get("passive", {})]
		if staff_level(str(sid)) >= 3: parts.append(rr.get("lv3", {}))
		for pp in parts:
			for k in pp:
				if pp[k] is bool: out[k] = bool(out.get(k, false)) or bool(pp[k])
				elif k in STAFF_NONSTACK: out[k] = maxf(float(out.get(k, 0.0)), float(pp[k]))
				else: out[k] = float(out.get(k, 0.0)) + float(pp[k])
				var who: Array = out["by"].get(k, []); who.append(str(sid)); out["by"][k] = who
	return out

func _staff_credit(aid: String, dw: Array) -> String:
	# the charge just spent is a use for the staffer whose charges it was: the pool is worked in dressing order, each through his own charges
	var per := maxi(1, int(_staff_active_rec(aid).get("charges", 1)))
	var spent := per * maxi(1, dw.size()) - int(staff_charges.get(aid, 0))
	var sid: String = str(dw[clampi((spent - 1) / per, 0, dw.size() - 1)]) if dw.size() > 0 else aid
	_staff_add_use(sid, {"active": aid})
	return sid

func _staff_add_use(sid: String, ev: Dictionary) -> void:
	# one use on the ledger for this staffer (a charge he spent, or since PAC-099 a trainee at his elbow), his level read again
	var before := staff_level(sid)
	rewards["staff"][sid] = staff_uses(sid) + 1
	var after := staff_level(sid)
	_ev("staff_use", {"who": sid}.merged(ev).merged({"uses": staff_uses(sid), "level": after}))
	if after > before:
		var rr: Dictionary = STAFF.get("roles", {}).get(staff_role(sid), {})
		_ev("staff_level", {"who": sid, "name": staff_name(sid), "role": staff_role(sid), "level": after, "unlocked": str(rr.get("lv3_text", "")) if after >= 3 else ""})
		_say("STAFF :: %s reaches Lv%d%s" % [staff_name(sid), after, (" - " + str(rr.get("lv3_text", ""))) if after >= 3 else ""])

func _crowd(src: String) -> void:
	# NP_01 s1: the building behind you - your own spectacle heats it (NP_05: no Tension, and no heat, for damage taken); the Hype's +20% on every gain
	var base := float(STAFF.get("crowd", {}).get("sources", {}).get(src, 0))
	if base <= 0.0: return
	var before := crowd_heat
	crowd_heat = minf(float(STAFF.get("crowd", {}).get("max", 100)), crowd_heat + base * (1.0 + float(staff_fx.get("crowd_heat_pct", 0.0)) / 100.0))
	if crowd_heat > before: _ev("crowd", {"heat": crowd_heat, "src": src, "plus": crowd_heat - before})

func staff_record(sid: String) -> Dictionary:
	# NP_11 s9 Staff {id, name, role, passive(s), active: {effect, charges}, level, recruit} from the table and the ledger
	var c := _corps_rec(sid)
	var rr: Dictionary = STAFF.get("roles", {}).get(staff_role(sid), {})
	var ar := _staff_active_rec(staff_active_of(sid))
	var ps: Array = [str(rr.get("passive_text", ""))]
	if staff_level(sid) >= 3: ps.append(str(rr.get("lv3_text", "")))
	var dressed_at := staff_dressed().find(sid)
	return {"id": sid, "name": staff_name(sid), "role": staff_role(sid), "passives": ps, "active": {"id": str(ar.get("id", "")), "name": str(ar.get("name", "")), "effect": ar.get("effect", {}).duplicate(true), "charges": int(ar.get("charges", 0))},
		"level": staff_level(sid), "uses": staff_uses(sid), "recruit": str(c.get("recruit", "the starting corps")), "dressed": dressed_at >= 0, "dressed_slot": dressed_at}

func staff_line() -> String:
	# the dressed three for the board and the HUD
	var parts: Array = []
	for sid in staff_dressed(): parts.append("%s (%s Lv%d)" % [staff_name(str(sid)), staff_role(str(sid)), staff_level(str(sid))])
	return ", ".join(PackedStringArray(parts))

static func seed_staff(ledger: Dictionary, staff_s: String, staff_d: Dictionary) -> Dictionary:
	# `-- staff=janitor:3,the_reveal:2,physio` -> the reward ledger with those staffers' uses at the levels named (a seed, as `-- pi=` seeds the recon ledger)
	var out := ledger.duplicate(true)
	if not out.has("staff"): out["staff"] = {}
	var taken: Array = []
	for part in staff_s.split(","):
		var kv := part.split(":")
		var key := str(kv[0]).strip_edges()
		if key == "": continue
		var sid := ""
		for c in staff_d.get("corps", []):
			if str(c.get("id", "")) == key: sid = key
		if sid == "":
			for c in staff_d.get("corps", []):
				if str(c.get("active", "")) == key and not (str(c["id"]) in taken): sid = str(c["id"]); break
		if sid == "": continue
		taken.append(sid)
		if kv.size() > 1 and int(kv[1]) >= 2: out["staff"][sid] = int(staff_d.get("levels", {}).get(str(mini(int(kv[1]), 3)), 0))
	return out

func _stat_sum(card: Dictionary, keys: Array) -> float:
	var st: Dictionary = grown_stats(card)                                                               # PAC-090: grown
	var v := 0.0
	for k in (keys if keys.size() > 0 else st.keys()): v += float(st.get(k, 0))
	return v

func _in_card_order(names: Array) -> Array:
	# names in the order the cards were dressed (presets never depend on the board they replace)
	var out: Array = []
	for f in dressed:
		if str(f["name"]) in names: out.append(str(f["name"]))
	return out

func ace_of(names: Array) -> String:
	# NP_01 s2.1's Hammer, read from the cards: the highest of the ace stats (formation.v1.json), then the higher stat total, then card order
	var best := ""; var bv := -1.0; var bt := -1.0
	for nm in _in_card_order(names):
		var c := _card_of(nm); var v := _stat_sum(c, FORMATION.get("ace", {}).get("stats", ["PWR", "SPD", "RFX"])); var t := _stat_sum(c, [])
		if v > bv or (v == bv and t > bt): best = nm; bv = v; bt = t
	return best

func anchor_of(names: Array, ace: String) -> String:
	# the anchor-class card: the highest of the anchor stats among the rest (the keeper analog)
	var best := ""; var bv := -1.0; var bt := -1.0
	for nm in _in_card_order(names):
		if nm == ace: continue
		var c := _card_of(nm); var v := _stat_sum(c, FORMATION.get("anchor", {}).get("stats", ["CHN", "BLK", "STA"])); var t := _stat_sum(c, [])
		if v > bv or (v == bv and t > bt): best = nm; bv = v; bt = t
	return best

func order_preset(arche: String, from: Array = []) -> Dictionary:
	# NP_10 s2's named openings as presets over the board's starters (the sealed board's, else the dressed not in reserve, in card order):
	# Standard puts the ace at the Hammer (R4) and the anchor-class at R5; Ambush the ace at R1; Wall-First the anchor-class at R1 and the ace
	# at the Hammer; Relay Ladder the best-bonded chain at R2-R3-R4 toward R5. A board of 3 or fewer closes on its ace (no anchor slot).
	var k := board_k()
	var st: Array = []
	for x in (from if from.size() > 0 else board.get("slots", [])): st.append(str(x))
	if st.size() != k:
		st = []
		for f in dressed:
			if not bool(f.get("reserve", false)) and st.size() < k: st.append(str(f["name"]))
		for f in dressed:
			if st.size() < k and not (str(f["name"]) in st): st.append(str(f["name"]))
	st = _in_card_order(st)
	if arche == "GYM_WALL": return _gw_preset(st)                                                       # PAC-079: the Gym Wall's suggestion (NP_10 s2)
	var ace := ace_of(st); var anchor := anchor_of(st, ace)
	var hammer := k - 2 if k >= 4 else k - 1
	var anch := k - 1 if k >= 4 else -1
	var slots: Array = []
	for i in k: slots.append("")
	var why: Array = []
	var fa: Array = FORMATION.get("ace", {}).get("stats", ["PWR", "SPD", "RFX"]); var fn: Array = FORMATION.get("anchor", {}).get("stats", ["CHN", "BLK", "STA"])
	var ace_why := "the ace (%s %d)" % ["+".join(PackedStringArray(fa)), int(_stat_sum(_card_of(ace), fa))]
	var anc_why := "anchor-class (%s %d)" % ["+".join(PackedStringArray(fn)), int(_stat_sum(_card_of(anchor), fn))] if anchor != "" else ""
	var place := func(nm: String, i: int, w: String) -> void:
		if nm == "" or i < 0 or i >= k or slots[i] != "" or nm in slots: return
		slots[i] = nm; why.append("R%d %s - %s" % [i + 1, nm, w])
	var a := arche
	if a == "RELAY_LADDER":
		var ladder: Array = range(1, mini(k, 4))
		if ladder.size() < 2: a = "STANDARD"; why.append("no room for a ladder in %d slots - Standard" % k)
		else:
			var best: Array = []; var bs := -1
			var tuples: Array = [[]]
			for _d in ladder.size():
				var nxt: Array = []
				for tu in tuples:
					for nm in st:
						if not (nm in tu): nxt.append(tu + [nm])
				tuples = nxt
			for tu in tuples:
				var sc := 0
				for j in range(1, tu.size()): sc += kizuna_pts(str(tu[j - 1]), str(tu[j]))
				if sc > bs: bs = sc; best = tu
			for j in ladder.size(): place.call(str(best[j]), int(ladder[j]), "the ladder (%s)" % ("bond %d with %s" % [kizuna_pts(str(best[j]), str(best[j - 1])), best[j - 1]] if j > 0 else "its first rung"))
			if anch >= 0 and slots[anch] == "":
				if not (anchor in slots): place.call(anchor, anch, anc_why + ", the relay's end")
				elif not (ace in slots): place.call(ace, anch, ace_why + ", the relay's end")
	match a:
		"STANDARD": place.call(ace, hammer, ace_why); place.call(anchor, anch, anc_why)
		"AMBUSH": place.call(ace, 0, ace_why); place.call(anchor, anch, anc_why)
		"WALL_FIRST": place.call(anchor, 0, anc_why); place.call(ace, hammer, ace_why)
	for nm in st:
		if nm in slots: continue
		for i in k:
			if slots[i] == "": place.call(nm, i, "card order"); break
	var res: Array = []
	for f in dressed:
		if not (str(f["name"]) in slots): res.append(str(f["name"]))
	return {"archetype": arche, "slots": slots, "reserves": res, "ace": ace, "anchor": anchor, "why": why}

func _apply_board(b: Dictionary) -> void:
	# the sealed board; a board that dresses its own squad from the stable (PAC-075) dresses it here
	board = b
	if b.has("dress"):
		dressed = []
		for nm in b["dress"]: dressed.append(_stable_card(str(nm)).duplicate(true))

func _board_check(b: Dictionary) -> Dictionary:
	# NP_10 s2: "drag 8 dressed from the stable" - a board may name its squad (dress); the rest of the check runs over that squad
	if not b.has("dress"): return _board_check_squad(b)
	var dn: Array = []
	for x in b["dress"]: dn.append(str(x))
	if dn.size() != dressed.size(): return {"ok": false, "why": "a squad of %d for a dual that dresses %d" % [dn.size(), dressed.size()]}
	for nm in dn:
		if _stable_card(nm).is_empty(): return {"ok": false, "why": "%s is not in the stable" % nm}
		if dn.count(nm) > 1: return {"ok": false, "why": "%s is dressed twice" % nm}
	var keep := dressed; var keep_board := board
	dressed = []
	for nm in dn: dressed.append(_stable_card(nm).duplicate(true))
	board = {}
	var bc := _board_check_squad(b)
	dressed = keep; board = keep_board
	if bool(bc["ok"]): bc["board"]["dress"] = dn
	return bc

func _stable_card(nm: String) -> Dictionary:
	for c in stable:
		if str(c.get("name", "")) == nm: return c
	return {}

func _board_check_squad(b: Dictionary) -> Dictionary:
	# a board as the formation screen hands it over: {"board": named} | {"archetype": preset} | {"slots": [...]} | {"staff": [...]} alone (+ "reserves", "staff"; a declared level is refused - levels are earned)
	var src := b.duplicate(true)
	var bname := ""
	if src.has("board"):
		bname = str(src["board"])
		var named: Dictionary = FORMATION.get("boards", {}).get(bname, {})
		if named.is_empty(): return {"ok": false, "why": "no board named '%s'" % bname}
		for kk in named:
			if not src.has(kk): src[kk] = named[kk]
	var arche := str(src.get("archetype", ""))
	if arche != "" and arche != "GYM_WALL" and not FORMATION.get("archetypes", {}).has(arche): return {"ok": false, "why": "no order archetype '%s' (%s)" % [arche, ", ".join(PackedStringArray(FORMATION.get("order", [])))]}
	var slots: Array = []; var why: Array = []
	if src.has("staff_levels"): return {"ok": false, "why": "a staffer's level is earned by use (the ledger), not declared on a board"}
	if src.has("slots"):
		for x in src["slots"]: slots.append(str(x))
	elif arche != "":
		var pr := order_preset(arche); slots = pr["slots"]; why = pr["why"]
	elif src.has("staff"):                                                                               # a board of staff only: the card order's starters (PAC-074)
		for f in dressed:
			if not bool(f.get("reserve", false)) and slots.size() < board_k(): slots.append(str(f["name"]))
		for f in dressed:
			if slots.size() < board_k() and not (str(f["name"]) in slots): slots.append(str(f["name"]))
	else: return {"ok": false, "why": "a board needs its slots or an order archetype"}
	var k := board_k()
	if slots.size() != k: return {"ok": false, "why": "%d slots for a %d-segment dual with %d dressed (it takes %d)" % [slots.size(), segments(), dressed.size(), k]}
	for nm in slots:
		if _card_of(str(nm)).is_empty(): return {"ok": false, "why": "%s is not dressed" % nm}
		if slots.count(nm) > 1: return {"ok": false, "why": "%s is in two slots" % nm}
	var res: Array = []
	for f in dressed:
		if not (str(f["name"]) in slots): res.append(str(f["name"]))
	if src.has("reserves"):
		var given: Array = []
		for x in src["reserves"]: given.append(str(x))
		var gs := given.duplicate(); gs.sort(); var rs := res.duplicate(); rs.sort()
		if gs != rs: return {"ok": false, "why": "the reserves are the dressed not in a slot (%s), not %s" % [", ".join(PackedStringArray(res)), ", ".join(PackedStringArray(given))]}
		res = given
	var given_staff: Array = []
	for x in src.get("staff", TAC.get("equipped", {}).get("staff", [])): given_staff.append(str(x))
	var staff := _resolve_staff(given_staff)                                                          # corps ids; an active's id names the first staffer who carries it (PAC-074)
	if staff.size() > int(STAFF.get("dressed", FORMATION.get("staff_slots", 3))): return {"ok": false, "why": "%d staff on a board of %d staff slots" % [staff.size(), int(STAFF.get("dressed", FORMATION.get("staff_slots", 3)))]}
	for i in staff.size():
		var sid := str(staff[i])
		if staff_active_of(sid) == "": return {"ok": false, "why": "no staff '%s'" % given_staff[i]}
		if staff.count(sid) > 1: return {"ok": false, "why": "%s is dressed twice" % staff_name(sid)}
	return {"ok": true, "why": "", "board": {"name": bname, "archetype": arche, "slots": slots, "reserves": res, "staff": staff, "why": why}}

func seal_board(b: Dictionary) -> Dictionary:
	# the formation screen's commit (NP_01 s7): before the bell the board replaces the card order - the dual is set up again from the same RNG
	# position, as if the board had been handed over at setup; after the bell it is refused (the corner's swap is the reorder from there)
	var refuse := func(why: String) -> Dictionary:
		_ev("board_refused", {"why": why}); _say("BOARD REFUSED - %s" % why)
		return {"ok": false, "why": why}
	if bout.size() > 0: return refuse.call("no board in a %s" % str(bout.get("kind", "bout")))
	if bell_rung(): return refuse.call("sealed at the bell - the corner's swap reorders from here")
	var bc := _board_check(b)
	if not bool(bc["ok"]): return refuse.call(str(bc["why"]))
	_apply_board(bc["board"])
	rng.state = dual_rng0; events = []
	_reset_dual(_first_boss)
	_board_sealed_ev()
	return {"ok": true, "why": "", "board": board.duplicate(true)}

func _board_sealed_ev() -> void:
	var arche := str(board.get("archetype", ""))
	var lbl := str(FORMATION.get("archetypes", {}).get(arche, {}).get("label", "")) if arche != "" else ("the %s board" % str(board.get("name", "")) if str(board.get("name", "")) != "" else "your order")
	_ev("board_sealed", {"name": str(board.get("name", "")), "archetype": arche, "slots": board["slots"].duplicate(), "reserves": board["reserves"].duplicate(), "staff": board["staff"].duplicate(), "why": board.get("why", []).duplicate()})
	var sl: Array = []
	for i in board["slots"].size(): sl.append("R%d %s" % [i + 1, board["slots"][i]])
	_say("BOARD SEALED (%s): %s%s | staff %s" % [lbl, ", ".join(PackedStringArray(sl)), (" | reserves " + ", ".join(PackedStringArray(board["reserves"]))) if board["reserves"].size() > 0 else "", ", ".join(PackedStringArray(board["staff"]))])

func board_cards() -> Array:
	# the dressed cards in the sealed board's order (slots, then reserves) with its reserve flags - what the save writes, so a load dresses the board
	if not _board_fits(): return dressed
	var out: Array = []
	for nm in board["slots"]:
		var c: Dictionary = _card_of(str(nm)).duplicate(true); c.erase("reserve"); out.append(c)
	for nm in board["reserves"]:
		var c2: Dictionary = _card_of(str(nm)).duplicate(true); c2["reserve"] = true; out.append(c2)
	return out

func _roll(tag: String, i: int) -> float:
	# a roll the seal makes without drawing from the fight's RNG: keyed by the dual's seed, the boss, his corner and which dual this is (0..100)
	return float(posmod([rng.seed, _first_boss, str(coach.get("id", "")), seal_n, tag, i].hash(), 10000)) / 100.0

func projection() -> Dictionary:
	# live on the formation screen; from the bell on, the read you sealed against (a PI rung earned in R1 does not rewrite it), each slot
	# marked revealed with who is actually in it as its segment begins (NP_01 s7)
	var pr: Dictionary = bprojection.duplicate(true) if bell_rung() and bprojection.size() > 0 else _projection_live()
	var shown := seg_idx + (1 if bell_rung() else 0)
	for sl in pr.get("slots", []):
		var i: int = int(sl["slot"]) - 1
		sl["revealed"] = i < shown; sl["actual"] = str(blineup[i]) if i < shown and i < blineup.size() else ""
	return pr

func _projection_live() -> Dictionary:
	# NP_10 s2-3: his probable order, one confidence per slot from the sources the sim has; honest (a slot is right that often) unless his
	# corner ran a decoy seal, which shifts every name one slot and keeps every percentage (the confidence % lies) - a Lv3 Tactician reads it
	if bout.size() > 0 or coach.is_empty() or sealed_b.is_empty(): return {}
	var F: Dictionary = FORMATION.get("projection", {})
	var arche := str(coach.get("archetype", "STANDARD"))
	var truth: Array = sealed_b
	var k := truth.size()
	var shown := seg_idx + (1 if bell_rung() else 0)                                                   # NP_01 s7: a slot is revealed when its segment begins
	var out := {"coach": str(coach.get("id", "")), "label": str(coach.get("label", "")), "archetype": arche, "slots": [], "pct": 0, "sources": [], "decoy": false, "detected": false, "blind": false}
	if bool(fmt.get("blind", false)):                                                                   # NP_01 s8: the blind dual - no scouting, no reveals
		out["blind"] = true
		for i in k: out["slots"].append({"slot": i + 1, "name": "", "confidence": 0, "silhouette": true, "right": false, "revealed": i < shown, "actual": str(blineup[i]) if i < shown and i < blineup.size() else ""})
		return out
	var base := int(FORMATION.get("archetypes", {}).get(arche, {}).get("readable_pct", 0))
	out["sources"].append({"source": "archetype", "what": "%s reads %s" % [str(coach.get("label", "his corner")), str(FORMATION.get("archetypes", {}).get(arche, {}).get("label", arche))], "pct": base})
	var scout := 0; var scout_who := ""; var scout_role := false
	for f in dressed:
		var sc: Dictionary = FORMATION.get("scouts", {}).get(str(f["name"]), {})
		if sc.is_empty() or not (str(coach.get("id", "")) in FORMATION.get("districts", {}).get(str(sc.get("district", "")), [])): continue
		if int(sc.get("pct", 0)) > scout: scout = int(sc.get("pct", 0)); scout_who = str(f["name"])
	var rsp := int(_roles().get("scout", {}).get("projection_pct", 0))                                  # PAC-099: NP_10 s3 - a scout on the bench reads the clubs of his home district
	if rsp > 0:
		for nm in role_holders("SCOUT"):
			if rsp > scout and str(coach.get("id", "")) in FORMATION.get("districts", {}).get(home_district(str(nm)), []): scout = rsp; scout_who = str(nm); scout_role = true
	if scout > 0: out["sources"].append({"source": "scout", "what": ("%s scouting %s (the stable role)" % [scout_who, home_district(scout_who)]) if scout_role else ("%s's scouting (%s)" % [scout_who, str(FORMATION["scouts"][scout_who].get("district", ""))]), "pct": scout})
	var sp := staff_passives()                                                                          # PAC-074: the tactician's +15 is his passive while dressed (staff.v1.json)
	var tact := int(sp.get("projection_pct", 0.0))
	if tact > 0: out["sources"].append({"source": "tactician", "what": "the tactician (%s)" % ", ".join(PackedStringArray(sp["by"].get("projection_pct", []).map(func(x): return "%s, Lv%d" % [staff_name(str(x)), staff_level(str(x))]))), "pct": tact})
	var cap := int(F.get("cap_pct", 95)); var per := int(F.get("pi_pct_per_level", 5)); var sil := int(F.get("silhouette_below_pct", 35))
	var conf: Array = []; var pi_note: Array = []
	for i in k:
		var lv := maxi(pi_level(dialect_of(str(truth[i]))), pi_boss(str(truth[i])))                     # his dialect's rung, or his page (NP_02 s3: PI 3)
		if lv > 0: pi_note.append("R%d PI %d" % [i + 1, lv])
		conf.append(mini(cap, base + scout + tact + per * lv))
	if pi_note.size() > 0: out["sources"].append({"source": "pi", "what": "Pattern Intel on their dialects (%s)" % ", ".join(PackedStringArray(pi_note)), "pct": per})
	var names: Array = truth.duplicate()
	if bdecoy:
		var sh := int(F.get("decoy_shift", 1))
		for i in k: names[i] = truth[(i + sh) % k]
	else:
		var wrong: Array = []
		for i in k:
			if _roll("slot", i) >= float(conf[i]): wrong.append(i)
		if wrong.size() >= 2:
			for j in wrong.size(): names[wrong[j]] = truth[wrong[(j + 1) % wrong.size()]]
		elif wrong.size() == 1:
			var w: int = wrong[0]
			var bench: Array = []
			for nm in bdressed:
				if not (nm in truth): bench.append(nm)
			if bench.size() > 0: names[w] = bench[int(_roll("bench", w)) % bench.size()]
			elif k >= 2: var n2 := (w + 1) % k; names[w] = truth[n2]; names[n2] = truth[w]
	out["decoy"] = bdecoy
	var tape := tape_read()                                                                             # PAC-089: the Film Room's tape of this corner's last decoy
	if tape: out["sources"].append({"source": "tape", "what": "the tape: %s has run a decoy seal on you before (the Film Room)" % str(coach.get("label", "his corner")), "pct": 0})
	out["detected"] = bdecoy and (bool(sp.get("detect_decoys", false)) or tape)                          # the tactician's Lv3 read (NP_10 s3), earned by use; or the tape
	var total := 0
	for i in k:
		var c: int = 0 if bool(out["detected"]) else int(conf[i])
		var silh: bool = bool(out["detected"]) or c < sil
		total += c
		out["slots"].append({"slot": i + 1, "name": "" if silh else str(names[i]), "guess": str(names[i]), "confidence": c, "silhouette": silh, "right": str(names[i]) == str(truth[i]),
			"revealed": i < shown, "actual": str(blineup[i]) if i < shown and i < blineup.size() else "", "decoy": bool(out["detected"])})
	out["pct"] = int(round(float(total) / float(maxi(1, k))))
	return out

func boss_rings(name: String) -> Array:
	# his three rings as the segment will dress him: the META's style / element / House, and the kit he opens in over them (Vey)
	var m: Dictionary = _pat(name).get("meta", {})
	var st := style_key(str(m.get("style", "BOXERPUNCHER"))); var el := element_key(str(m.get("element", "NONE")))
	if m.has("kit"):
		var kp := _kit_parts(str(m["kit"]))
		if kp[0] != "": st = style_key(kp[0])
		if kp[1] != "": el = element_key(kp[1])
	return [st, el, house_key(str(m.get("house", "none")))]

func pairing(card: Dictionary, bname: String) -> Dictionary:
	# NP_10 s2's overlay for one pairing: the matchup card (rings()) plus what it projects - the EP modifier (s1.3), the hissatsu edge (s2.1),
	# the feud's Tension (s3) - and one coach note
	var br := boss_rings(bname)
	var r := rings(style_key(str(card.get("style", "BOXERPUNCHER"))), element_key(str(card.get("element", "NONE"))), house_key(str(card.get("house", "none"))), str(br[0]), str(br[1]), str(br[2]))
	var sgn := func(adv: String) -> int: return 1 if adv == "P" else (-1 if adv == "B" else 0)
	r["p_name"] = str(card.get("name", "")); r["b_name"] = bname
	r["ep_pct"] = int(sgn.call(str(r["style_adv"]))) * int(round((float(AFF.get("style", {}).get("advantage", {}).get("ep_mult", 1.1)) - 1.0) * 100.0))
	r["hiss_pct"] = int(sgn.call(str(r["element_adv"]))) * int(round((float(AFF.get("element", {}).get("beats_hissatsu_mult", 1.1)) - 1.0) * 100.0))
	r["tension_pct"] = int(round((float(AFF.get("house", {}).get("feud_tension_mult", 1.25)) - 1.0) * 100.0)) if bool(r["feud"]) else 0
	r["note"] = _ring_note(r, bname)
	return r

func boss_short(name: String) -> String:
	return name.capitalize() if not generics.has(name) else str(generics[name].get("label", name))

func _ring_note(r: Dictionary, bname: String) -> String:
	# the coach's one line for the pairing (formation.v1.json notes_by_rings; NP_10 s2's two examples are two of them)
	var key := "even"
	if str(r["style_adv"]) == "B" and bool(r["feud"]): key = "his_fuel"
	elif str(r["style_adv"]) == "B": key = "his"
	elif str(r["style_adv"]) == "P" and str(r["element_adv"]) == "P": key = "ours_both"
	elif str(r["style_adv"]) == "P": key = "ours"
	elif bool(r["feud"]): key = "feud"
	elif str(r["element_adv"]) == "P": key = "element_ours"
	elif str(r["element_adv"]) == "B": key = "element_his"
	elif str(r["p"][0]) == "BOXERPUNCHER" and str(r["b"][0]) == "BOXERPUNCHER": key = "purist"
	var labels: Dictionary = AFF.get("style", {}).get("labels", {})
	return str(FORMATION.get("notes_by_rings", {}).get(key, "")).replace("{his}", boss_short(bname)).replace("{ours}", str(labels.get(str(r["p"][0]), r["p"][0])).to_lower())

func overlay(slots: Array = []) -> Array:
	# the rings overlay: each of your slots against the fighter his projection shows in it (a silhouette has no card to read)
	var pr := projection()
	var mine: Array = []
	for x in (slots if slots.size() > 0 else (sealed_p if sealed_p.size() > 0 else lineup.map(func(f): return str(f["name"])))): mine.append(str(x))
	var ps: Array = pr.get("slots", [])
	var out: Array = []
	for i in mine.size():
		var who := str(ps[i].get("name", "")) if i < ps.size() else ""
		if who == "": out.append({"slot": i + 1, "p_name": mine[i], "b_name": "", "unknown": true}); continue
		var pc := pairing(_card_of(mine[i]), who); pc["slot"] = i + 1; pc["unknown"] = false
		out.append(pc)
	return out

func formation_lines() -> Array:
	# the whiteboard as text (the greybox HUD's formation panel and the demo's log): your board, his projection, the rings overlay
	var out: Array = []
	var arche := str(board.get("archetype", ""))
	var lbl := str(FORMATION.get("archetypes", {}).get(arche, {}).get("label", arche)) if arche != "" else (("board " + str(board["name"])) if str(board.get("name", "")) != "" else ("your order" if board.size() > 0 else "card order"))
	if arche == "GYM_WALL": lbl = str(GYMWALL.get("suggestion", {}).get("label", "The Gym Wall"))
	var mine: Array = sealed_p if sealed_p.size() > 0 else lineup.map(func(f): return str(f["name"]))
	var sl: Array = []
	for i in mine.size(): sl.append("R%d %s" % [i + 1, mine[i]])
	var sealed_now := bell_rung()
	out.append("YOUR BOARD [%s]%s: %s | reserves %s | staff %s" % [lbl, " SEALED" if sealed_now else "", "  ".join(PackedStringArray(sl)), ", ".join(PackedStringArray(reserves.map(func(f): return str(f["name"])))) if reserves.size() > 0 else "-", staff_line()])
	var dl := duo_lines(mine)                                                                            # PAC-080: the Duo relays this order holds
	if dl.size() > 0: out.append("DUO RELAYS: " + "  ".join(PackedStringArray(dl)))
	if relay_line() != "": out.append("RELAY OPENS (R%d %s, chain %d%s): %s" % [seg_idx + 1, pname(), relay_chain, ", FULL RELAY" if full_relay else "", relay_line()])   # PAC-081
	if not sealed_now and not gym_wall.is_empty():                                                       # PAC-079: NP_10 s2 - the wall's proximities pre-suggest the adjacencies
		var gs: Dictionary = gym_wall_suggestion()
		out.append("THE GYM WALL SUGGESTS (%d): %s" % [int(GYMWALL.get("suggestion", {}).get("key", 6)), "  ".join(PackedStringArray(range(gs["slots"].size()).map(func(i): return "R%d %s" % [i + 1, str(gs["slots"][i])])))])
	var pr := projection()
	if pr.is_empty(): out.append("THEIR PROJECTION: none - no dual"); return out
	if bool(pr["blind"]): out.append("THEIR PROJECTION: blind dual - no scouting, no reveals")
	else:
		var ss: Array = []
		for s in pr["slots"]:
			if bool(s["revealed"]): ss.append("R%d %s (revealed%s)" % [int(s["slot"]), boss_short(str(s["actual"])), "" if str(s["actual"]) == str(s["guess"]) else ", projected " + (boss_short(str(s["guess"])) if not bool(s["silhouette"]) else "?")])
			elif bool(s["silhouette"]): ss.append("R%d ?%s" % [int(s["slot"]), " DECOY" if bool(s.get("decoy", false)) else (" %d%%" % int(s["confidence"]))])
			else: ss.append("R%d %s %d%%" % [int(s["slot"]), boss_short(str(s["name"])), int(s["confidence"])])
		var src: Array = []
		for so in pr["sources"]: src.append("%s %s%d" % [str(so["what"]), "+" if int(so["pct"]) >= 0 else "", int(so["pct"])] if str(so["source"]) != "pi" else "%s +%d/level" % [str(so["what"]), int(so["pct"])])
		out.append("THEIR PROJECTION (%s, order at %d%%): %s   [%s]" % [str(pr["label"]), int(pr["pct"]), " | ".join(PackedStringArray(ss)), "; ".join(PackedStringArray(src))])
		if bool(pr["detected"]): out.append("   DECOY SEAL - the tactician reads it: their board is a lie, nothing on it to trust")
	for o in overlay():
		if bool(o["unknown"]): out.append("   R%d %s vs ?" % [int(o["slot"]), str(o["p_name"])]); continue
		var bits: Array = []
		var labels: Dictionary = AFF.get("style", {}).get("labels", {})
		if str(o["style_adv"]) != "": bits.append("%s %s over %s" % ["ours" if str(o["style_adv"]) == "P" else "his", labels.get(str(o["p"][0] if str(o["style_adv"]) == "P" else o["b"][0]), ""), labels.get(str(o["b"][0] if str(o["style_adv"]) == "P" else o["p"][0]), "")])
		if str(o["element_adv"]) != "": bits.append("%s %s over %s" % ["ours" if str(o["element_adv"]) == "P" else "his", str(o["p"][1] if str(o["element_adv"]) == "P" else o["b"][1]), str(o["b"][1] if str(o["element_adv"]) == "P" else o["p"][1])])
		if bool(o["feud"]): bits.append("FEUD Tension +%d%%" % int(o["tension_pct"]))
		out.append("   R%d %s vs %s: %s, EP %s%d%% - \"%s\"" % [int(o["slot"]), str(o["p_name"]), boss_short(str(o["b_name"])), ", ".join(PackedStringArray(bits)) if bits.size() > 0 else "no rings", "+" if int(o["ep_pct"]) >= 0 else "", int(o["ep_pct"]), str(o["note"])])
	return out

static func parse_board_arg(order: String, board_s: String, staff_s: String) -> Dictionary:
	# `-- order=AMBUSH` | `-- board=ep1` | `-- board=MARCUS,PRIYA,RORY` (+ `-- staff=the_reveal:3,patch_job,raise_the_roof`) -> the board setup takes
	var b := {}
	if board_s != "":
		if "," in board_s: b["slots"] = Array(board_s.split(",")).map(func(x): return str(x).strip_edges().to_upper())
		else: b["board"] = board_s
	if order != "": b["archetype"] = order.to_upper()
	if staff_s != "":
		b["staff"] = []
		for part in staff_s.split(","): b["staff"].append(str(part.split(":")[0]).strip_edges())   # a level after the colon seeds the ledger (seed_staff), it is not declared here
	return b

# ============================ RECRUITMENT (NP_08 s2) ========================
static func parse_condition(cond: String) -> Array:
	# NP_08 s2.2's grammar: clauses joined by AND; FORM(args) with an optional xN, and BEAT_IN(...) USING STYLE_PROOF(style)
	var out: Array = []
	var rx := RegEx.new(); rx.compile("^([A-Z_]+)\\((.*)\\)(x(\\d+))?$")
	for part in cond.split(" AND "):
		var txt := str(part).strip_edges()
		if txt == "": continue
		var main := txt; var using := ""
		if " USING " in txt:
			main = txt.split(" USING ")[0].strip_edges(); using = txt.split(" USING ")[1].strip_edges()
		var m := rx.search(main)
		if m == null: out.append({"form": "?", "args": [], "times": 1, "style": "", "text": txt}); continue
		var args: Array = []
		for a in m.get_string(2).split(","): args.append(str(a).strip_edges())
		var style := ""
		if using != "":
			var mu := rx.search(using)
			style = style_key(mu.get_string(2)) if mu != null and mu.get_string(1) == "STYLE_PROOF" else "?"
		out.append({"form": m.get_string(1), "args": args, "times": int(m.get_string(4)) if m.get_string(4) != "" else 1, "style": style, "text": txt})
	return out

func _recruit_rec(name: String) -> Dictionary: return RECRUITS.get("recruits", {}).get(name, {})

func _beat(size: String, opp: String, house: String = "") -> void:
	# a win against a named opponent, by size and by the style of the fighter who won it (BEAT_IN / STYLE_PROOF read this); PAC-077: his house
	# (a house's blessing counts wins against its fighters) and, for a segment / scrap / spar, the one house whose moves won it (every hissatsu
	# your fighter cast in it that house's, at least one)
	if opp == "" or lineup.is_empty(): return
	var st := str(P.get("style", "BOXERPUNCHER"))
	var rec: Dictionary = rewards["beaten"].get(opp, {"scrap": 0, "spar": 0, "segment": 0, "dual": 0, "styles": {}})
	rec[size] = int(rec.get(size, 0)) + 1
	var sk := "%s:%s" % [size, st]
	rec["styles"][sk] = int(rec["styles"].get(sk, 0)) + 1
	var hk := house_key(house) if house != "" else house_key(str(patterns.get(opp, {}).get("meta", {}).get("house", "none")))
	if hk != "none": rec["house"] = hk
	if size != "dual" and seg_cast_houses.size() > 0:
		var mh := str(seg_cast_houses[0])
		for x in seg_cast_houses:
			if str(x) != mh: mh = ""
		if mh != "":
			if not rec.has("moves"): rec["moves"] = {}
			rec["moves"][mh] = int(rec["moves"].get(mh, 0)) + 1
	rewards["beaten"][opp] = rec

func recruit_state(name: String) -> String:
	# "" (nobody has flagged him) | approachable | approached | joined; "never" for a fighter the docs close
	var rec := _recruit_rec(name)
	if rec.is_empty(): return ""
	if rec.has("never"): return "never"
	if _stable_card(str(rec.get("card", ""))).size() > 0: return "joined"
	return str(rewards["recruit"].get(name, {}).get("state", ""))

func _clause_state(c: Dictionary, name: String) -> Dictionary:
	# one clause against the ledgers: what you have, what it needs, met or not, and who owns it (the sim or the overworld's flags)
	var rec := _recruit_rec(name)
	var g: Dictionary = RECRUITS.get("grammar", {}).get(str(c["form"]), {})
	var args: Array = c["args"]
	var have := 0; var need := int(c.get("times", 1)); var note := ""
	var hsub := name.substr(6) if name.begins_with("house:") else ""                                    # PAC-077: a house's blessing line - the house is the subject
	match str(c["form"]):
		"BEAT_IN":
			var size := str(args[0]) if args.size() > 0 else "dual"
			if size.begins_with("dual[") : size = "segment"
			if hsub != "":
				for opp_h in rewards["beaten"]:
					var bh: Dictionary = rewards["beaten"][opp_h]
					if str(bh.get("house", "")) != hsub: continue
					have += int(bh.get("styles", {}).get("%s:%s" % [size, str(c["style"])], 0)) if str(c["style"]) != "" else int(bh.get(size, 0))
				note = "%s won against House %s's fighters%s" % [size, hsub.capitalize(), (" by a " + str(c["style"])) if str(c["style"]) != "" else ""]
			else:
				var opp := str(rec.get("beat_as", name))
				var bt: Dictionary = rewards["beaten"].get(opp, {})
				have = int(bt.get("styles", {}).get("%s:%s" % [size, str(c["style"])], 0)) if str(c["style"]) != "" else int(bt.get(size, 0))
				note = "%s won against %s%s" % [size, opp, (" by a " + str(c["style"])) if str(c["style"]) != "" else ""]
		"REP":                                                                                            # PAC-101: the district's rep on the ledger (a seeded rep flag still counts)
			var rk := rep_key(str(args[0]) if args.size() > 0 else "")
			have = rep_of(rk)
			var sv = rewards["story"].get("rep:%s" % (str(args[0]) if args.size() > 0 else ""), 0)
			have = maxi(have, int(sv) if not (sv is bool) else (1 if sv else 0))
			need = int(args[1]) if args.size() > 1 and str(args[1]).strip_edges().is_valid_int() else 1
			note = "rep in %s (the ledger's)" % district_label(rk)
		"STYLE_PROOF":
			var spx: Dictionary = HOUSES.get("houses", {}).get(hsub, {}).get("style_proof", {}) if hsub != "" else {}
			if spx.size() > 0:                                                                       # Petrov's variant: won with the house's own moves, against the named corners
				var ac: Array = spx.get("against_coaches", [])
				for opp_s in rewards["beaten"]:
					if ac.size() > 0 and not (str(COACHES.get("coach_of", {}).get(str(opp_s), "")) in ac): continue
					have += int(rewards["beaten"][opp_s].get("moves", {}).get(str(spx["moves"]), 0))
				note = "wins by House %s's moves only against %s" % [str(spx["moves"]).capitalize(), ", ".join(PackedStringArray(ac))]
			else:
				var sty := style_key(str(args[0]) if args.size() > 0 else "")
				if hsub != "":
					for opp_t in rewards["beaten"]:
						if str(rewards["beaten"][opp_t].get("house", "")) != hsub: continue
						for sk2 in rewards["beaten"][opp_t].get("styles", {}):
							if str(sk2).ends_with(":" + sty): have += int(rewards["beaten"][opp_t]["styles"][sk2])
					note = "wins against House %s's fighters by a %s" % [hsub.capitalize(), sty]
				else:
					for sk in rewards["beaten"].get(str(rec.get("beat_as", name)), {}).get("styles", {}):
						if str(sk).ends_with(":" + sty): have += int(rewards["beaten"][str(rec.get("beat_as", name))]["styles"][sk])
					note = "wins against him by a %s" % sty
		"PI_LEVEL":
			var hk := house_key(str(args[0]) if args.size() > 0 else "")
			have = pi_level(hk); need = int(args[1]) if args.size() > 1 else 1
			note = "PI vs the %s dialect" % hk
		"BOND":
			var who := (str(args[0]) if args.size() > 0 else "").to_upper(); need = int(args[1]) if args.size() > 1 else 1
			if _stable_card(who).is_empty(): note = "%s is not in the stable" % who
			else:
				for c2 in stable:
					if str(c2["name"]) != who: have = maxi(have, kizuna_level(who, str(c2["name"])))
				note = "%s's best Kizuna in the stable" % who
		"STAT_PROOF":
			var rx := RegEx.new(); rx.compile("^([A-Z]+)\\s*>=\\s*(\\d+)$")
			var m := rx.search(str(args[0]) if args.size() > 0 else "")
			if m != null:
				need = int(m.get_string(2))
				for c3 in stable: have = maxi(have, int(grown_stats(c3).get(m.get_string(1), 0)))              # PAC-090: a stat grown counts
				note = "the best %s in the stable" % m.get_string(1)
		"WITNESS":
			if hsub != "":
				have = int(rewards["houses"].get(hsub, {}).get("witnessed", 0))
				note = "duals won with House %s's crest up (%s)" % [hsub.capitalize(), str(HOUSES.get("houses", {}).get(hsub, {}).get("witness", {}).get("text", ", ".join(PackedStringArray(args))))]
			else:
				have = int(rewards["recruit"].get(name, {}).get("witnessed", 0))
				note = "duals won since he was approached (%s)" % (", ".join(PackedStringArray(args)))
		_:
			if str(g.get("owner", "")) == "overworld":                                                 # QUEST / REP / FEUD_RESOLVED / BLESSING / ITEM: the story flags
				var key := str(g.get("flag", "")).replace("{0}", str(args[0]) if args.size() > 0 else "").replace("{all}", "+".join(PackedStringArray(args)))
				var v = rewards["story"].get(key, 0)
				have = int(v) if not (v is bool) else (1 if v else 0)
				if g.has("value_arg") and args.size() > int(g["value_arg"]): need = int(args[int(g["value_arg"])])
				note = "story flag %s (the overworld's)" % key
				var ge := _edge_between(house_key(str(args[0])), house_key(str(args[1]))) if str(c["form"]) == "FEUD_RESOLVED" and args.size() == 2 else {}
				if ge.size() > 0 and str(ge.get("relation", "")) == "FEUD":                                # PAC-077: a feud on the graph is resolved when its edge has flipped
					have = 0 if edge_relation(ge) == "FEUD" else 1; need = 1
					note = "%s on the feud graph: %s" % [str(ge["id"]), edge_relation(ge)]
				elif str(c["form"]) == "FEUD_RESOLVED" and args.size() == 2 and have == 0 and _flag_set(key):
					have = 1
				if str(c["form"]) == "BLESSING" and args.size() > 0:                                        # PAC-077: blessed by the flag or by the line met
					have = 1 if house_blessed(house_key(str(args[0]))) else 0; need = 1
					note = "House %s's blessing" % str(args[0]).capitalize()
			else: note = "no such form"
	return {"text": str(c["text"]), "form": str(c["form"]), "owner": str(g.get("owner", "?")), "have": have, "need": need, "met": have >= need and g.size() > 0, "note": note}

func condition_state(cond: String, name: String) -> Array:
	var out: Array = []
	for c in parse_condition(cond): out.append(_clause_state(c, name))
	return out

func recruit_view(name: String) -> Dictionary:
	# NP_08 s2.1: what the club knows of him - his state, and once approached the whole condition, clause by clause (honest, no wiki-bait)
	var rec := _recruit_rec(name)
	if rec.is_empty(): return {}
	var st := recruit_state(name)
	var out := {"name": name, "card": str(rec.get("card", "")), "state": st, "source": str(rec.get("source", "")), "clauses": [], "met": false}
	if st == "never": out["why"] = str(rec["never"]); return out
	if str(rewards["recruit"].get(name, {}).get("via", "")) != "": out["via"] = str(rewards["recruit"][name]["via"])     # PAC-076: surfaced by a string on the wall
	if st == "approached" or st == "joined":
		out["condition"] = str(rec.get("condition", ""))
		out["clauses"] = condition_state(str(rec.get("condition", "")), name)
		var all_met := true
		for cl in out["clauses"]:
			if not bool(cl["met"]): all_met = false
		out["met"] = all_met and out["clauses"].size() > 0
		var rel: Dictionary = rewards["recruit"].get(name, {}).get("released", {})
		if rel.size() > 0:                                                                                 # PAC-100: NP_08 s4 - the release remembered
			out["released"] = {"day": int(rel.get("day", 0)), "flag": str(rel.get("flag", "")), "bond": str(rel.get("bond", ""))}
			if str(rel.get("flag", "")) == "warmth":
				out["condition"] = "the club he left warmly"
				out["clauses"] = [{"text": "RETURNS(warmth) - a bond with %s left behind" % str(rel.get("bond", "")), "form": "WARMTH", "owner": "sim", "have": 1, "need": 1, "met": true, "note": "released on day %d" % int(rel.get("day", 0))}]
				out["met"] = true
				return out
			var gs := int(rewards["beaten"].get(name, {}).get("spar", 0)) - int(rel.get("spar_at", 0))
			out["clauses"].append({"text": "BEAT_IN(spar) since the release - the grudge", "form": "GRUDGE", "owner": "sim", "have": gs, "need": 1, "met": gs >= 1, "note": "released on day %d with no bond left behind" % int(rel.get("day", 0))})
			out["met"] = out["met"] and gs >= 1
		if str(rec.get("around_the_family", "")) != "":                                                    # PAC-077: NP_08 s3 - recruiting around the family, UNSANCTIONED
			out["around"] = condition_state(str(rec["around_the_family"]), name)
			var ar_met := true
			for cl2 in out["around"]:
				if not bool(cl2["met"]): ar_met = false
			out["around_met"] = ar_met and out["around"].size() > 0
	return out

# ---- PAC-098: the story's pay, the scouting machine and the open mat (NP_02 s4, NP_08 s2.4, NP_11 s6) ----
# A story beat or a quest step lands on the ledger through story_mark and pays its HBP (NP_11 s6: HBP from "quests, wins, story"); a seeded
# flag (-- flag=) is the ledger as it stood and pays nothing. The scouting machine spends Prestige on a lead - a card pointing at a person,
# never the person (NP_08 s2.4): every pity-th pull a rare-tier lead (a named recruit the club has not met turns approachable; a String Wall
# lead with an authored condition turns face up), the rest a generic recruit on the open mat (NP_04 s9's assembler), signed free on an
# open-mat day or any day for the priority. The ledger keeps the pulls, the leads and the open mat (rewards["scouting"]).
func story_mark(flag: String) -> Dictionary:
	# the overworld's story beat or quest step landed: the flag on the ledger, its HBP paid by kind (story:* / quest:*; any other flag pays nothing)
	var why := ""
	if flag == "" or not ":" in flag: why = "no flag '%s'" % flag
	elif _story_set(flag): why = "%s is on the ledger already" % flag
	if why != "":
		_ev("story_refused", {"flag": flag, "why": why}); return {"ok": false, "why": why}
	rewards["story"][flag] = true
	var kind := flag.get_slice(":", 0)
	var hb := int(ECO.get("hbp", {}).get(kind, 0)) if kind in ["story", "quest"] else 0
	rewards["hbp"] = int(rewards.get("hbp", 0)) + hb
	_ev("story_marked", {"flag": flag, "kind": kind, "hbp": hb, "ledger": int(rewards["hbp"])})
	if hb > 0: _say("%s :: %s - %d HBP" % ["QUEST" if kind == "quest" else "STORY", flag, hb])
	_recruit_check()                                                                                     # a quest may meet a condition, a blessing a house
	_academy_recruit(flag)                                                                               # PAC-102: NP_12 s2 - an arc's turn, the academy's signings
	return {"ok": true, "why": "", "hbp": hb}

func _scq() -> Dictionary:
	if not rewards.has("scouting"): rewards["scouting"] = {"pulls": 0, "leads": [], "open_mat": []}
	return rewards["scouting"]

func _scouting() -> Dictionary: return ECO.get("scouting", {})

func scout_rares() -> Array:
	# the machine's rare-tier leads now: the recruit table's named fighters nobody has flagged (never excepted), then the String Wall's leads the
	# docs give a condition that are still face down, in the tables' order
	var out: Array = []
	for rn in RECRUITS.get("recruits", {}):
		if not RECRUITS["recruits"][rn].has("never") and recruit_state(str(rn)) == "" and not rewards["string_wall"].has(str(rn)): out.append(str(rn))
	for m in STRINGS.get("maps", []):
		for n in m.get("nodes", []):
			if str(n.get("kind", "")) == "lead" and str(n.get("condition", "")) != "" and not rewards["string_wall"].has(str(n["id"])) and not str(n["id"]) in out: out.append(str(n["id"]))
	return out

func scout_why() -> String:
	if ECO.get("prestige", {}).get("pull", 0) == 0 or _scouting().is_empty(): return "no scouting machine in this build"
	var bw := _between("the machine is fed")
	if bw != "": return bw
	var pr := int(ECO["prestige"]["pull"])
	if int(rewards.get("prestige", 0)) < pr: return "a pull costs %d Prestige (the ledger holds %d)" % [pr, int(rewards.get("prestige", 0))]
	return ""

func _scout_tier() -> int:
	var t := 1
	for tf in _scouting().get("tier_flags", []):
		if _flag_set(str(tf[0])): t = maxi(t, int(tf[1]))
	return t

func scout_pull() -> Dictionary:
	# one pull: the Prestige paid, a lead dispensed - every pity-th a rare-tier one while the machine holds any, else a generic on the open mat
	var why := scout_why()
	if why != "":
		_ev("scout_refused", {"why": why}); _say("THE MACHINE - %s" % why)
		return {"ok": false, "why": why}
	var q := _scq()
	var pr := int(ECO["prestige"]["pull"])
	rewards["prestige"] = int(rewards.get("prestige", 0)) - pr
	q["pulls"] = int(q["pulls"]) + 1
	var n := int(q["pulls"])
	var r := RandomNumberGenerator.new(); r.seed = hash("scout:%d" % n)                                  # the machine's own draw: never the fight's RNG
	var dks: Array = _scouting().get("districts", {}).keys()
	var dk := str(dks[r.randi_range(0, dks.size() - 1)]) if dks.size() > 0 else "centre"
	var rares := scout_rares()
	var lead := {"n": n, "district": dk, "day": int(rewards.get("day", 1))}
	if n % maxi(1, int(ECO["prestige"].get("pity", 10))) == 0 and rares.size() > 0:
		var id := str(rares[r.randi_range(0, rares.size() - 1)])
		lead["rare"] = true; lead["id"] = id
		if _recruit_rec(id).size() > 0:
			var rc := recruit_card(id)
			lead["label"] = str(_recruit_rec(id).get("card", id)); lead["house"] = str(rc.get("house", "none")); lead["style"] = str(rc.get("style", ""))
			rewards["recruit"][id] = {"state": "approachable", "witnessed": 0, "day": int(rewards.get("day", 1)), "lead": n}
		else:
			var sn := sw_node(id)
			lead["label"] = str(sn.get("label", id)); lead["house"] = str(sn.get("house", "")); lead["style"] = ""
			_sw_reveal(id, "the scouting machine", "lead", {})
	else:
		var dls: Array = PIECES.get("dialects", {}).keys()
		var dl := str(dls[r.randi_range(0, dls.size() - 1)]) if dls.size() > 0 else "gym"
		var sts: Array = PIECES.get("styles", {}).keys()
		var st := str(sts[r.randi_range(0, sts.size() - 1)]) if sts.size() > 0 else "BOXERPUNCHER"
		var nm := "%s %d" % [str(_scouting().get("districts", {}).get(dk, dk.to_upper())), n]
		var sp := generic_spec(nm, st, dl, _scout_tier(), hash("scout:card:%d" % n), nm)
		var card := {"name": nm, "hissatsu": "", "talk": "", "style": str(sp["style"]), "element": str(sp["element"]), "house": str(sp["house"]), "dialect": dl, "generic": true, "tier": int(sp["tier"]), "stats": sp["stats"].duplicate(), "district": dk}   # PAC-099: his home district (NP_11 s9)
		lead["rare"] = false; lead["id"] = nm; lead["label"] = nm; lead["house"] = str(sp["house"]); lead["style"] = str(sp["style"])
		q["open_mat"].append(card)
	q["leads"].append(lead)
	_ev("scout_lead", lead.merged({"prestige": int(rewards["prestige"])}))
	_say("THE MACHINE :: pull %d (%d Prestige) - %s lead: %s, %s%s" % [n, pr, "RARE" if bool(lead["rare"]) else "a", str(lead["label"]), str(_scouting().get("districts", {}).get(dk, dk)), (", House %s" % str(lead["house"])) if str(lead["house"]) not in ["", "none"] else ""])
	if bool(lead["rare"]): _recruit_check()
	return {"ok": true, "why": "", "lead": lead}

func open_mat_day() -> bool:
	var ev := int(_scouting().get("open_mat_every", 7))
	return ev > 0 and int(rewards.get("day", 1)) % ev == 0

func open_mat() -> Array: return rewards.get("scouting", {}).get("open_mat", [])

func sign_why(i: int) -> String:
	if _scouting().is_empty(): return "no open mat in this build"
	var bw := _between("the open mat is visited")
	if bw != "": return bw
	if i < 0 or i >= open_mat().size(): return "the open mat has no lead %d (%d on it)" % [i, open_mat().size()]
	if stable.size() >= int(_scouting().get("stable_cap", 100)): return "the stable holds %d - NP_08 s1's cap" % stable.size()
	var pr := int(_scouting().get("priority", 10))
	if _sign_price(i) > 0 and int(rewards.get("prestige", 0)) < pr: return ("%s left with a grudge - signing back costs the priority, %d Prestige (the ledger holds %d)" % [str(open_mat()[i]["name"]), pr, int(rewards.get("prestige", 0))]) if str(open_mat()[i].get("released", "")) == "grudge" else "the open mat is every %dth day (day %d) - its priority costs %d Prestige (the ledger holds %d)" % [int(_scouting().get("open_mat_every", 7)), int(rewards.get("day", 1)), pr, int(rewards.get("prestige", 0))]
	return ""

func _sign_price(i: int) -> int:
	# the open mat's price for this card today: free on an open-mat day, else the priority; PAC-100: a released card's flag - warmth free any
	# day, a grudge the priority even on an open-mat day
	var fl := str(open_mat()[i].get("released", "")) if i >= 0 and i < open_mat().size() else ""
	if fl == "warmth": return 0
	if fl == "grudge": return int(_scouting().get("priority", 10))
	return 0 if open_mat_day() else int(_scouting().get("priority", 10))

func sign_generic(i: int) -> Dictionary:
	# the open mat: a generic the machine's lead pointed at joins the stable - free on an open-mat day, else for the priority ("-1": the aid's, the first)
	if i < 0: i = 0
	var why := sign_why(i)
	if why != "":
		_ev("sign_refused", {"i": i, "why": why}); _say("THE OPEN MAT - %s" % why)
		return {"ok": false, "why": why}
	var paid := _sign_price(i)
	if paid > 0: rewards["prestige"] = int(rewards.get("prestige", 0)) - paid
	var card: Dictionary = _scq()["open_mat"][i]
	_scq()["open_mat"].remove_at(i)
	var sc: Dictionary = card.duplicate(true); sc.erase("released")                                        # PAC-100: the flag is the memory's, not the card's
	stable.append(sc)
	_gw_pin_new(str(card["name"]), "")
	var back := str(card.get("released", ""))
	_ev("signed", {"name": str(card["name"]), "style": str(card["style"]), "house": str(card["house"]), "tier": int(card.get("tier", 1)), "priority": paid, "stable": stable.size()}.merged({"back": back} if back != "" else {}))
	_say("THE OPEN MAT :: %s signs (%s, %s%s) - the stable holds %d" % [str(card["name"]), str(card["style"]), "House " + str(card["house"]) if str(card["house"]) != "none" else "houseless", ((", %d Prestige priority" % paid) + (" (a grudge)" if back == "grudge" else "")) if paid > 0 else (", back with warmth" if back == "warmth" else ", an open-mat day"), stable.size()])
	return {"ok": true, "why": "", "card": card, "priority": paid}

func scouting_lines() -> Array:
	# between duals: the machine's count and the last leads, the open mat
	var out: Array = []
	if _scouting().is_empty(): return out
	var q: Dictionary = rewards.get("scouting", {"pulls": 0, "leads": [], "open_mat": []})
	var last: Array = q.get("leads", []).slice(maxi(0, q.get("leads", []).size() - 3))
	out.append("THE MACHINE: %d pulls (%d Prestige a pull, every %dth rare; %d rare leads left) - %s" % [int(q.get("pulls", 0)), int(ECO["prestige"].get("pull", 10)), int(ECO["prestige"].get("pity", 10)), scout_rares().size(), ", ".join(PackedStringArray(last.map(func(l): return ("RARE " if bool(l.get("rare", false)) else "") + str(l.get("label", ""))))) if last.size() > 0 else "no leads yet"])
	out.append("THE OPEN MAT (%s): %s" % ["today" if open_mat_day() else "every %dth day, priority %d Prestige" % [int(_scouting().get("open_mat_every", 7)), int(_scouting().get("priority", 10))], ", ".join(PackedStringArray(open_mat().map(func(c): return "%s (%s%s)" % [str(c["name"]), str(c["style"]), (", released: %s" % str(c["released"])) if c.has("released") else ""]))) if open_mat().size() > 0 else "nobody waiting"])
	return out

# ---- PAC-099: the stable roles (NP_08 s1; NP_11 s9 Fighter.stable_role / home_district) ----
const ROLE_IDS := ["FIGHTER", "TRAINING", "SCOUT", "CORNER_TRAINEE"]
const ROLE_LABELS := {"FIGHTER": "on the bench", "TRAINING": "training partner", "SCOUT": "scout", "CORNER_TRAINEE": "cornerman-in-training"}

func _roles() -> Dictionary: return ECO.get("roles", {})

func _rq() -> Dictionary:
	if not rewards.has("roles"): rewards["roles"] = {"of": {}, "paid": {"prestige": 0, "beans": 0, "uses": 0}}
	return rewards["roles"]

func stable_role(nm: String) -> String:
	# NP_11 s9: FIGHTER unless the ledger holds a role for him
	return str(rewards.get("roles", {}).get("of", {}).get(nm, "FIGHTER"))

func _is_dressed(nm: String) -> bool:
	for f in dressed:
		if str(f.get("name", "")) == nm: return true
	return false

func role_working(nm: String) -> bool:
	# a role is worked from the bench: a stable card with a role, not dressed (dressed, it waits)
	return stable_role(nm) != "FIGHTER" and _stable_card(nm).size() > 0 and not _is_dressed(nm)

func role_holders(role: String) -> Array:
	# the bench's cards working this role, in the stable's order
	var out: Array = []
	for c in stable:
		var nm := str(c.get("name", ""))
		if stable_role(nm) == role and role_working(nm): out.append(nm)
	return out

func home_district(nm: String) -> String:
	# NP_11 s9 Fighter.home_district: a generic's the machine drew (the community centre when his card names none); a House card's the
	# House's root on the circuit's districts; a houseless card's Millbrook Secondary
	var c := _club_card(nm)
	var hm: Dictionary = _roles().get("home", {})
	if bool(c.get("generic", false)): return str(c.get("district", "centre"))
	var h := house_key(str(c.get("house", "none")))
	if h != "none" and hm.get("houses", {}).has(h): return str(hm["houses"][h])
	return str(hm.get("houseless", "school"))

func district_label(d: String) -> String:
	return str(_scouting().get("districts", {}).get(d, d.to_upper()))

func role_label(role: String) -> String: return str(ROLE_LABELS.get(role, role))

func partner_bonus(game: String, who: String, partner: String) -> Array:
	# NP_08 s1: [Beans, stat] a training partner adds to this slot - a Bean for every `per` points he leads the trainee by at the game's
	# stat (its bias; "any": the stat he leads by most), `cap` at most; nothing without the role, dressed, or without a lead
	var R: Dictionary = _roles().get("training", {})
	if R.is_empty() or GROW.is_empty() or partner == "" or partner == who or stable_role(partner) != "TRAINING" or not role_working(partner): return [0, ""]
	var g: Dictionary = _training().get("games", {}).get(game, {})
	var ps: Dictionary = grown_stats(_club_card(partner)); var ts: Dictionary = grown_stats(_club_card(who))
	var bias := str(g.get("bias", "any"))
	var keys: Array = [bias] if bias in GROW.get("stats", []) else GROW.get("stats", [])
	var best := ""; var lead := 0
	for k in keys:
		var d := int(ps.get(k, 0)) - int(ts.get(k, 0))
		if d > lead: lead = d; best = str(k)
	var n := mini(int(R.get("cap", 3)), lead / maxi(1, int(R.get("per", 10))))
	return [n, best] if n > 0 else [0, ""]

func partner_pick(game: String, who: String) -> String:
	# the club's training partner with the most to add to this slot (the stable's order breaks ties); "" when none adds anything
	var best := ""; var bn := 0
	for nm in role_holders("TRAINING"):
		var n := int(partner_bonus(game, who, str(nm))[0])
		if n > bn: bn = n; best = str(nm)
	return best

func scout_districts() -> Dictionary:
	# the districts the bench's scouts cover: {district: [scouts]}, in the stable's order
	var out := {}
	for nm in role_holders("SCOUT"):
		var d := home_district(str(nm))
		if not out.has(d): out[d] = []
		out[d].append(str(nm))
	return out

func _scouts_pay() -> void:
	# NP_08 s1: the day turns - each district the scouts cover pays its Prestige once
	var per := int(_roles().get("scout", {}).get("prestige", 0))
	var sd := scout_districts()
	if per <= 0 or sd.is_empty(): return
	var got := per * sd.size()
	rewards["prestige"] = int(rewards.get("prestige", 0)) + got
	_rq()["paid"]["prestige"] = int(_rq()["paid"]["prestige"]) + got
	_ev("scouted", {"day": int(rewards.get("day", 1)), "prestige": got, "districts": sd.keys(), "scouts": role_holders("SCOUT"), "ledger": int(rewards["prestige"])})
	_say("THE SCOUTS :: day %d - +%d Prestige from %s" % [int(rewards.get("day", 1)), got, ", ".join(PackedStringArray(sd.keys().map(func(x): return district_label(str(x)))))])

func _trainee_mentor() -> String:
	# who a trainee feeds: the dressed staffer below Lv3 with the fewest uses (dressing order breaks ties), else the corps' (its order)
	var top := 0
	for k in STAFF.get("levels", {}): top = maxi(top, int(STAFF["levels"][k]))
	for pool in [staff_dressed(), STAFF.get("corps", []).map(func(c): return str(c.get("id", "")))]:
		var best := ""; var bu := 1 << 30
		for sid in pool:
			if _corps_rec(str(sid)).is_empty(): continue
			var u := staff_uses(str(sid))
			if u < top and u < bu: bu = u; best = str(sid)
		if best != "": return best
	return ""

func _trainees_feed() -> void:
	# NP_08 s1: at a dual's end each cornerman-in-training is a use for the staffer he worked beside (NP_10 s6: staff level via use)
	var tr := role_holders("CORNER_TRAINEE")
	if tr.is_empty() or STAFF.get("corps", []).is_empty(): return
	var per := int(_roles().get("corner", {}).get("uses", 1))
	var fed: Array = []
	for nm in tr:
		for u in per:
			var sid := _trainee_mentor()
			if sid == "": break
			_staff_add_use(sid, {"active": "", "trainee": str(nm)})
			_rq()["paid"]["uses"] = int(_rq()["paid"]["uses"]) + 1
			fed.append("%s at %s's elbow (Lv%d, %d use%s)" % [str(nm), staff_name(sid), staff_level(sid), staff_uses(sid), "" if staff_uses(sid) == 1 else "s"])
	if fed.size() > 0:
		_ev("trainees", {"fed": fed.duplicate()})
		_say("THE CORNER :: %s" % "; ".join(PackedStringArray(fed)))

func role_why(nm: String, role: String) -> String:
	# why this card cannot take this role now ("" when he can): the table, between duals, the role, the stable, dressed, already his
	if _roles().is_empty(): return "no stable roles in this build"
	var bw := _between("roles are set")
	if bw != "": return bw
	if not role in ROLE_IDS: return "no role '%s' (%s)" % [role, " / ".join(PackedStringArray(ROLE_IDS))]
	if _stable_card(nm).is_empty(): return "%s is not in the stable" % nm
	if role != "FIGHTER" and _is_dressed(nm): return "%s is dressed - a role is worked from the bench" % nm
	if stable_role(nm) == role: return "%s is already %s" % [nm, role_label(role)]
	return ""

func role_pick() -> Array:
	# the aid's: the first bench card without a role - a training partner if the club has none, a scout if nobody covers his district yet,
	# else a cornerman-in-training; [] when the whole bench is working
	for c in stable:
		var nm := str(c.get("name", ""))
		if _is_dressed(nm) or stable_role(nm) != "FIGHTER": continue
		if role_holders("TRAINING").is_empty(): return [nm, "TRAINING"]
		if not scout_districts().has(home_district(nm)): return [nm, "SCOUT"]
		return [nm, "CORNER_TRAINEE"]
	return []

func assign_role(nm: String, role: String = "") -> Dictionary:
	# NP_08 s1: a stablemate set to a role between duals ("*": the aid's pick; "FIGHTER" back to the ring)
	if nm == "*":
		var pk := role_pick()
		if pk.is_empty():
			var w0 := "no stable roles in this build" if _roles().is_empty() else "nobody on the bench without a role (the bench %d)" % (stable.size() - dressed.size())
			_ev("role_refused", {"name": "*", "role": role, "why": w0}); _say("THE ROLES - %s" % w0)
			return {"ok": false, "why": w0}
		nm = str(pk[0]); role = str(pk[1])
	var why := role_why(nm, role)
	if why != "":
		_ev("role_refused", {"name": nm, "role": role, "why": why}); _say("THE ROLES - %s" % why)
		return {"ok": false, "why": why}
	var was := stable_role(nm)
	if role == "FIGHTER": _rq()["of"].erase(nm)
	else: _rq()["of"][nm] = role
	_ev("role_set", {"name": nm, "role": role, "was": was, "home": home_district(nm), "text": role_text(nm)})
	_say("THE ROLES :: %s - %s" % [nm, role_text(nm)])
	return {"ok": true, "why": "", "name": nm, "role": role}

func role_back() -> Dictionary:
	# the last role set, back to the bench as a fighter
	var of: Dictionary = rewards.get("roles", {}).get("of", {})
	if of.is_empty():
		var w := "nobody holds a role"
		_ev("role_refused", {"name": "", "role": "FIGHTER", "why": w}); _say("THE ROLES - %s" % w)
		return {"ok": false, "why": w}
	return assign_role(str(of.keys()[of.size() - 1]), "FIGHTER")

func role_text(nm: String) -> String:
	# what his role does, from the ledger and the tables
	var role := stable_role(nm)
	var d := home_district(nm)
	var t := role_label(role)
	match role:
		"TRAINING":
			var st: Dictionary = grown_stats(_club_card(nm)); var top := _top_stat(st) if not GROW.is_empty() else ""
			t += " - %s %d at best, a Bean a slot for every %d points he leads the trainee by" % [top, int(st.get(top, 0)), int(_roles().get("training", {}).get("per", 10))] if top != "" else ""
		"SCOUT":
			var clubs: Array = FORMATION.get("districts", {}).get(d, [])
			t += " - %s, %d Prestige a day%s" % [district_label(d), int(_roles().get("scout", {}).get("prestige", 0)), (", reads %s's orders at %d%%" % [", ".join(PackedStringArray(clubs)), int(_roles().get("scout", {}).get("projection_pct", 0))]) if clubs.size() > 0 else ""]
		"CORNER_TRAINEE":
			var m := _trainee_mentor()
			t += (" - next at %s's elbow (Lv%d, %d use%s)" % [staff_name(m), staff_level(m), staff_uses(m), "" if staff_uses(m) == 1 else "s"]) if m != "" else " - the corps is all Lv3"
		_:
			t += " - %s" % district_label(d)
	if role != "FIGHTER" and _is_dressed(nm): t += " (dressed: the role waits)"
	return t

func roles_lines() -> Array:
	# between duals: the bench and what it works, and what the roles have paid
	var out: Array = []
	if _roles().is_empty(): return out
	var bench: Array = []
	for c in stable:
		if not _is_dressed(str(c.get("name", ""))): bench.append(str(c["name"]))
	var pd: Dictionary = rewards.get("roles", {}).get("paid", {})
	out.append("THE BENCH: %d (training %d, scouting %d district%s, in the corner %d) - the roles have paid %d Prestige, %d Beans, %d staff uses" % [bench.size(), role_holders("TRAINING").size(), scout_districts().size(), "" if scout_districts().size() == 1 else "s", role_holders("CORNER_TRAINEE").size(), int(pd.get("prestige", 0)), int(pd.get("beans", 0)), int(pd.get("uses", 0))])
	var shown := 0
	for nm in bench:
		if shown >= 4: out.append("... and %d more" % (bench.size() - shown)); break
		out.append("%s - %s" % [str(nm), role_text(str(nm))]); shown += 1
	return out

# ---- PAC-101: district rep (NP_02 s2.1 / s4; NP_08 s2.2 / s2.4) - scraps won raise it, a flee costs it, milestones pay Prestige ----
func _rp() -> Dictionary: return ECO.get("rep", {})

func rep_key(d: String) -> String:
	# a district's ledger key: the machine's district keys (NP_02 s1.1), the docs' other names by the table's aliases
	var k := d.strip_edges().to_lower()
	return str(_rp().get("aliases", {}).get(k, k))

func rep_of(d: String) -> int: return int(rewards.get("rep", {}).get("of", {}).get(rep_key(d), 0))

func _rep_q() -> Dictionary:
	if not rewards.has("rep"): rewards["rep"] = {"of": {}, "best": {}, "paid": 0}
	return rewards["rep"]

func _rep_add(d: String, n: int, why: String) -> Dictionary:
	# the district's rep moved (never under 0); a milestone pays its Prestige the first time the rep reaches it; PAC-103: the vendor
	# shelves the move opened or closed ride the event and the line (returned for the flee's)
	if _rp().is_empty() or d == "" or n == 0: return {"opened": [], "closed": []}
	var k := rep_key(d); var q := _rep_q()
	var sh0 := shelves_open()
	var before := int(q["of"].get(k, 0)); var after := maxi(0, before + n)
	q["of"][k] = after
	var best := int(q["best"].get(k, 0)); var paid := 0; var hit: Array = []
	if after > best:
		for m in _rp().get("milestones", []):
			if int(m[0]) > best and int(m[0]) <= after: paid += int(m[1]); hit.append(int(m[0]))
		q["best"][k] = after
	if paid > 0: rewards["prestige"] = int(rewards.get("prestige", 0)) + paid; q["paid"] = int(q.get("paid", 0)) + paid
	var sh1 := shelves_open()
	var opened: Array = sh1.filter(func(x): return not x in sh0); var closed: Array = sh0.filter(func(x): return not x in sh1)
	_ev("rep", {"district": k, "was": before, "rep": after, "by": after - before, "why": why, "milestones": hit, "prestige": paid, "shelves": opened.map(func(x): return shelf_label(x)), "closed": closed.map(func(x): return shelf_label(x))})
	_say("REP :: %s %d (%s%d, %s)%s%s%s" % [district_label(k), after, "+" if after >= before else "", after - before, why, (" - a milestone at %s: +%d Prestige" % [", ".join(PackedStringArray(hit.map(func(x): return str(x)))), paid]) if paid > 0 else "",
		(" - opens %s" % ", ".join(PackedStringArray(opened.map(func(x): return shelf_label(x))))) if opened.size() > 0 else "", (" - closes %s" % ", ".join(PackedStringArray(closed.map(func(x): return shelf_label(x))))) if closed.size() > 0 else ""])
	if after != before: _recruit_check()                                                                 # REP() may be met now (a recruit, a house's blessing)
	return {"opened": opened, "closed": closed}

func flee_why() -> String:
	if _rp().is_empty(): return "no district rep in this build"
	if bout.is_empty() or str(bout.get("kind", "")) != "scrap": return "only a scrap is fled (NP_02 s2.1) - a spar or a dual is fought out"
	if mode == "OVER": return "the scrap is over"
	return ""

func flee() -> Dictionary:
	# NP_02 s2.1: "fleeing: allowed pre-engagement freely; mid-scrap flee costs small district rep (-1)" - the scrap ends unpaid, no PI
	var why := flee_why()
	if why != "":
		_ev("flee_refused", {"why": why}); _say("FLEE - %s" % why)
		return {"ok": false, "why": why}
	var engaged := tick > dual_t0
	var d := str(bout.get("district", ""))
	var cost := int(_rp().get("flee", 1)) if engaged and d != "" else 0
	mode = "OVER"
	P["pending"] = {}; bpending = {}; B["pending"] = {}; eight = {}; cast = {}; clinch = {}; clinch_t = 0
	var shv: Dictionary = _rep_add(d, -cost, "fled") if cost > 0 else {"opened": [], "closed": []}
	var v := ("SCRAP FLED - %s rep -%d" % [district_label(d), cost]) if cost > 0 else ("SCRAP FLED - %s" % ("after the first exchange, placed nowhere: no rep" if engaged else "before the first exchange: free"))
	_ev("fled", {"engaged": engaged, "district": d, "rep": -cost, "objective": str(bout.get("objective", "")), "closed": shv["closed"].map(func(x): return shelf_label(x))})
	_ev("bout_end", {"kind": "scrap", "verdict": v, "rung": "fled", "objective": str(bout.get("objective", "")), "met": false, "won": false})
	_say("%s :: %s" % [str(bout.get("label", "SCRAP")), v])
	return {"ok": true, "why": "", "engaged": engaged, "rep": -cost}

func rep_lines() -> Array:
	# between duals: every district's rep, the milestones and the next one
	var out: Array = []
	if _rp().is_empty(): return out
	var ms: Array = _rp().get("milestones", [])
	var parts: Array = []
	for k in _scouting().get("districts", {}):
		var r := rep_of(str(k)); var nx := 0
		for m in ms:
			if int(m[0]) > int(rewards.get("rep", {}).get("best", {}).get(str(k), 0)): nx = int(m[0]); break
		parts.append("%s %d%s" % [district_label(str(k)), r, (" (next %d)" % nx) if nx > 0 else ""])
	out.append("DISTRICT REP (milestones %s): %s" % [", ".join(PackedStringArray(ms.map(func(m): return "%d +%d Prestige" % [int(m[0]), int(m[1])]))), ", ".join(PackedStringArray(parts))])
	return out

# ---- PAC-103: the vendor tiers (NP_02 s4: "District rep | Gates | Recruit conditions, vendor tiers") ----
# Each shop stands in a district (its table's `district`: the Downtown Strip, NP_02 s1.1's shops). A shelf with a `rep` opens by that
# district's rep as well as by its story flag: the ledger's rep as it stands (a flee below the line closes it again - what was bought
# stays bought), a seeded rep flag counting as REP() counts it. A shelf with no flag stands open as found.
const VENDOR_SHOPS := ["techniques", "gear"]
const VENDOR_LABELS := {"techniques": "the technique shop", "gear": "the gear shop"}

func vendor_shop(shop: String) -> Dictionary:
	if shop == "techniques": return TECH.get("shop", {})
	if shop == "gear": return GEAR.get("shop", {})
	return {}

func vendor_rep(shop: String) -> int:
	# the shop's district's rep: the ledger's, or a seeded rep flag's when higher (as REP() reads it)
	var d := str(vendor_shop(shop).get("district", ""))
	if d == "": return 0
	var st: Dictionary = rewards.get("story", {})
	var sv = st.get("rep:%s" % d, 0)
	return maxi(rep_of(d), int(sv) if not (sv is bool) else (1 if sv else 0))

func shelf_open_by(shop: String, tier: String) -> String:
	# how a shelf stands: "found" (no flag), "flag" (its story beat), "rep" (the district's rep met ahead of the beat), "closed"
	var td: Dictionary = vendor_shop(shop).get("tiers", {}).get(tier, {})
	var fl := str(td.get("flag", ""))
	if fl == "": return "found"
	if _flag_set(fl): return "flag"
	var n := int(td.get("rep", 0))
	if n > 0 and str(vendor_shop(shop).get("district", "")) != "" and vendor_rep(shop) >= n: return "rep"
	return "closed"

func shelves_open() -> Array:
	# every shop's open shelves as "shop:tier"
	var out: Array = []
	for shop in VENDOR_SHOPS:
		for t in vendor_shop(shop).get("order", []):
			if shelf_open_by(shop, str(t)) != "closed": out.append("%s:%s" % [shop, str(t)])
	return out

func shelf_label(st: String) -> String:
	var bits := st.split(":")
	return "%s's %s shelf" % [str(VENDOR_LABELS.get(bits[0], bits[0])), bits[1] if bits.size() > 1 else ""]

func shelf_rep_clause(shop: String, tier: String) -> String:
	# a closed shelf's other key: " or DOWNTOWN rep 10 (3 now)" ("" for a shelf the table gives no rep)
	var sh := vendor_shop(shop)
	var n := int(sh.get("tiers", {}).get(tier, {}).get("rep", 0))
	if n <= 0 or str(sh.get("district", "")) == "": return ""
	return " or %s rep %d (%d now)" % [district_label(rep_key(str(sh["district"]))), n, vendor_rep(shop)]

func vendor_lines() -> Array:
	# between duals: each shop's shelves, how each stands open, and what a closed one wants
	var out: Array = []
	for shop in VENDOR_SHOPS:
		var sh := vendor_shop(shop)
		if sh.is_empty() or str(sh.get("district", "")) == "": continue
		var parts: Array = []
		for t in sh.get("order", []):
			var td: Dictionary = sh["tiers"][t]; var by := shelf_open_by(shop, str(t)); var txt := str(td.get("text", "")).split(" (")[0]
			match by:
				"found": parts.append("%s open" % str(t))
				"flag": parts.append("%s open (%s)" % [str(t), txt])
				"rep": parts.append("%s open (%s rep %d)" % [str(t), district_label(rep_key(str(sh["district"]))), int(td.get("rep", 0))])
				_: parts.append("%s at %s%s" % [str(t), txt, (" or rep %d (%d/%d)" % [int(td.get("rep", 0)), vendor_rep(shop), int(td.get("rep", 0))]) if int(td.get("rep", 0)) > 0 else ""])
		out.append("%s (%s, rep %d): %s" % [str(VENDOR_LABELS[shop]).to_upper(), district_label(rep_key(str(sh["district"]))), vendor_rep(shop), ", ".join(PackedStringArray(parts))])
	return out

# ---- PAC-100: the locker room (NP_08 s4) - the release, three days to take it back, the grudge / warmth flag, the browse ----
func _lk() -> Dictionary: return ECO.get("locker", {})

func _lq() -> Dictionary:
	if not rewards.has("locker"): rewards["locker"] = {"pending": {}, "memory": {}}
	return rewards["locker"]

func _road_back(nm: String) -> String:
	# where a released card goes: "recruit:<id>" (the recruit table's card - back to the district, approachable), "open_mat" (a generic), "" (none)
	var c := _club_card(nm)
	if bool(c.get("generic", false)): return "open_mat"
	for rn in RECRUITS.get("recruits", {}):
		if str(RECRUITS["recruits"][rn].get("card", "")) == nm and not RECRUITS["recruits"][rn].has("never"): return "recruit:%s" % str(rn)
	return ""

func release_flag(nm: String) -> Array:
	# NP_08 s4's "remember": [warmth | grudge, the stablemate he is bonded to] - warmth with a bond at the table's level or more to a card who stays
	var lv := int(_lk().get("warm_level", 1))
	var best := ""; var bp := -1
	for c in stable:
		var o := str(c.get("name", ""))
		if o == nm or kizuna_level(nm, o) < lv: continue
		if kizuna_pts(nm, o) > bp: bp = kizuna_pts(nm, o); best = o
	return ["warmth", best] if best != "" else ["grudge", ""]

func release_why(nm: String) -> String:
	# why this card cannot be released now ("" when it can): the table, between duals, the stable, the story's own, dressed, a road back
	if _lk().is_empty(): return "no locker room in this build"
	var bw := _between("the locker room is visited")
	if bw != "": return bw
	if _stable_card(nm).is_empty(): return "%s is not in the stable" % nm
	if nm in _lk().get("keep", []): return "%s is the story's own - the club began with %s" % [nm, nm]
	if _is_dressed(nm): return "%s is dressed - release a card from the bench" % nm
	if _road_back(nm) == "": return "%s has no road back (no recruit record, not a generic)" % nm
	return ""

func release_pick() -> String:
	# the aid's: the last card on the bench that can be released ("" when none)
	for i in range(stable.size() - 1, -1, -1):
		var nm := str(stable[i].get("name", ""))
		if release_why(nm) == "": return nm
	return ""

func release(nm: String) -> Dictionary:
	# NP_08 s4: a bench card let go - the place freed now, the role cleared, the gear back in the locker, off the Gym Wall; the ledgers kept
	# under the name; three days to take the card back ("*": the aid's pick)
	if nm == "*":
		nm = release_pick()
		if nm == "":
			var w0 := "no locker room in this build" if _lk().is_empty() else "nobody on the bench can be released"
			_ev("release_refused", {"name": "*", "why": w0}); _say("THE LOCKER ROOM - %s" % w0)
			return {"ok": false, "why": w0}
	var why := release_why(nm)
	if why != "":
		_ev("release_refused", {"name": nm, "why": why}); _say("THE LOCKER ROOM - %s" % why)
		return {"ok": false, "why": why}
	var d := int(rewards.get("day", 1))
	var fl := release_flag(nm)
	var road := _road_back(nm)
	var ent := {"card": _stable_card(nm).duplicate(true), "day": d, "flag": str(fl[0]), "bond": str(fl[1]), "role": stable_role(nm), "road": road, "worn": []}
	if rewards.has("gear") and rewards["gear"].get("worn", {}).has(nm):                                    # his pieces back in the club's locker
		ent["worn"] = rewards["gear"]["worn"][nm].duplicate(); rewards["gear"]["worn"].erase(nm)
	if road.begins_with("recruit:"):
		var rid := road.substr(8)
		if rewards["recruit"].has(rid): ent["recruit_was"] = rewards["recruit"][rid].duplicate(true)
		rewards["recruit"][rid] = {"state": "released", "day": d}
	for i in stable.size():
		if str(stable[i].get("name", "")) == nm: stable.remove_at(i); break
	if rewards.has("roles"): rewards["roles"]["of"].erase(nm)
	if not gym_wall.is_empty(): gym_wall["cards"].erase(nm); gym_wall["unpinned"].erase(nm)
	_lq()["pending"][nm] = ent
	var mem: Dictionary = _lq()["memory"].get(nm, {"times": 0})
	_lq()["memory"][nm] = {"flag": str(fl[0]), "bond": str(fl[1]), "day": d, "times": int(mem.get("times", 0)) + 1}
	var until := d + int(_lk().get("undo_days", 3))
	_ev("released", {"name": nm, "day": d, "until": until, "flag": str(fl[0]), "bond": str(fl[1]), "road": road, "stable": stable.size()})
	_say("THE LOCKER ROOM :: %s released - %s; the stable %d (take the card back until day %d)" % [nm, ("warmth: a bond with %s" % str(fl[1])) if str(fl[0]) == "warmth" else "a grudge: no bond left behind", stable.size(), until])
	return {"ok": true, "why": "", "name": nm, "flag": str(fl[0]), "until": until}

func take_back_why(nm: String) -> String:
	if _lk().is_empty(): return "no locker room in this build"
	var bw := _between("the locker room is visited")
	if bw != "": return bw
	var pd: Dictionary = rewards.get("locker", {}).get("pending", {})
	if not pd.has(nm): return "%s is not waiting on a release" % nm if nm != "" else "nobody is waiting on a release"
	if stable.size() >= int(_scouting().get("stable_cap", 100)): return "the stable holds %d - NP_08 s1's cap" % stable.size()
	return ""

func take_back(nm: String = "*") -> Dictionary:
	# the release undone inside its three days ("*": the latest): the card, the role and the gear as they were, back on the Gym Wall
	if nm == "*":
		var pd0: Dictionary = rewards.get("locker", {}).get("pending", {})
		nm = str(pd0.keys()[pd0.size() - 1]) if pd0.size() > 0 else ""
	var why := take_back_why(nm)
	if why != "":
		_ev("take_back_refused", {"name": nm, "why": why}); _say("THE LOCKER ROOM - %s" % why)
		return {"ok": false, "why": why}
	var ent: Dictionary = _lq()["pending"][nm]
	stable.append(ent["card"].duplicate(true))
	if str(ent.get("role", "FIGHTER")) != "FIGHTER": _rq()["of"][nm] = str(ent["role"])
	if ent.get("worn", []).size() > 0: _gq()["worn"][nm] = ent["worn"].duplicate()
	var road := str(ent.get("road", ""))
	if road.begins_with("recruit:"):
		var rid := road.substr(8)
		if ent.has("recruit_was"): rewards["recruit"][rid] = ent["recruit_was"].duplicate(true)
		else: rewards["recruit"].erase(rid)
	_gw_pin_new(nm, "")
	_lq()["pending"].erase(nm)
	var mem: Dictionary = _lq()["memory"].get(nm, {})
	if int(mem.get("times", 1)) <= 1: _lq()["memory"].erase(nm)                                          # undone, the release never happened
	else: mem["times"] = int(mem["times"]) - 1
	_ev("taken_back", {"name": nm, "day": int(rewards.get("day", 1)), "role": str(ent.get("role", "FIGHTER")), "stable": stable.size()})
	_say("THE LOCKER ROOM :: %s taken back - the stable %d" % [nm, stable.size()])
	return {"ok": true, "why": "", "name": nm}

func _releases_settle() -> void:
	# the third day turned: a release stands - a recruit back in the district (approachable, the flag on the record), a generic on the open mat
	var pd: Dictionary = rewards.get("locker", {}).get("pending", {})
	if pd.is_empty(): return
	var today := int(rewards.get("day", 1))
	for nm in pd.keys():
		var ent: Dictionary = pd[nm]
		if today < int(ent["day"]) + int(_lk().get("undo_days", 3)): continue
		var road := str(ent.get("road", ""))
		if road.begins_with("recruit:"):
			var rid := road.substr(8)
			rewards["recruit"][rid] = {"state": "approachable", "witnessed": 0, "day": today, "released": {"day": int(ent["day"]), "flag": str(ent["flag"]), "bond": str(ent["bond"]), "card": ent["card"].duplicate(true), "spar_at": int(rewards["beaten"].get(rid, {}).get("spar", 0))}}
		elif road == "open_mat":
			var c: Dictionary = ent["card"].duplicate(true); c["released"] = str(ent["flag"])
			_scq()["open_mat"].append(c)
		pd.erase(nm)
		_ev("release_settled", {"name": str(nm), "day": today, "flag": str(ent["flag"]), "road": road, "district": str(ent["card"].get("district", home_district(str(nm)))) if road == "open_mat" else ""})
		_say("THE LOCKER ROOM :: %s is gone - %s (%s)" % [str(nm), "back in %s, approachable" % district_label(home_district_of_card(ent["card"])) if road.begins_with("recruit:") else "on the open mat", "warmth" if str(ent["flag"]) == "warmth" else "a grudge"])

func home_district_of_card(c: Dictionary) -> String:
	# the home district of a card that is not in the club (a release on its way out)
	var hm: Dictionary = _roles().get("home", {})
	if bool(c.get("generic", false)): return str(c.get("district", "centre"))
	var h := house_key(str(c.get("house", "none")))
	if h != "none" and hm.get("houses", {}).has(h): return str(hm["houses"][h])
	return str(hm.get("houseless", "school"))

func memory_of(nm: String) -> Dictionary:
	# NP_08 s4's "remember": the flag the last release left on the name ({} when never released)
	return rewards.get("locker", {}).get("memory", {}).get(nm, {})

func card_view(nm: String) -> String:
	# NP_08 s4's comparison card: stats, techniques, trait, dialect, bond lines (and where the card stands: House, Style, Element, home, role)
	var c := _club_card(nm)
	if c.is_empty(): return ""
	var st: Dictionary = grown_stats(c)
	var sts: Array = []
	for k in GROW.get("stats", ["PWR", "SPD", "CHN", "RFX", "BLK", "STA", "HRT"]): sts.append("%s %d" % [str(k), int(st.get(k, 0))])
	var kit: Array = [str(c.get("hissatsu", ""))] + (kit_moves(nm) if not TECH.is_empty() else [])
	var tr: Dictionary = card_trait(c)
	var bonds: Array = []
	for o in _club_names():
		if str(o) != nm and kizuna_level(nm, str(o)) >= 1: bonds.append("%s Lv%d" % [str(o), kizuna_level(nm, str(o))])
	var h := house_key(str(c.get("house", "none")))
	var dl := str(c.get("dialect", "")) if str(c.get("dialect", "")) != "" else (h if h != "none" else dialect_of(nm, c))   # NP_07 s4: the House's tell dialect, his own without one
	var mem := memory_of(nm)
	return "%s - %s, %s, %s, %s; %s%s | %s | kit %s | trait %s | dialect %s | bonds %s" % [nm, ("House " + str(HOUSES.get("houses", {}).get(h, {}).get("name", h))) if h != "none" else "houseless", str(c.get("style", "")), str(c.get("element", "")), district_label(home_district(nm)),
		"dressed" if _is_dressed(nm) else role_label(stable_role(nm)), (" (released once, came back with %s)" % str(mem["flag"])) if mem.size() > 0 and int(mem.get("times", 0)) > 0 else "",
		" ".join(PackedStringArray(sts)), ", ".join(PackedStringArray(kit.filter(func(x): return str(x) != ""))) if kit.size() > 0 else "-", str(tr["name"]) if tr.size() > 0 else "none", dl, ", ".join(PackedStringArray(bonds)) if bonds.size() > 0 else "none"]

func locker_browse(by: String) -> Array:
	# NP_08 s4's browse: the stable grouped - by House (the crest wall), Style, Element, the bond web (each card's bonds), or slot-role
	var groups := {}
	var order: Array = []
	for c in stable:
		var nm := str(c.get("name", ""))
		var keys: Array = []
		match by:
			"house":
				var h := house_key(str(c.get("house", "none")))
				keys = [("House " + str(HOUSES.get("houses", {}).get(h, {}).get("name", h))) if h != "none" else "houseless"]
			"style": keys = [str(c.get("style", ""))]
			"element": keys = [str(c.get("element", ""))]
			"bond":
				var n := 0
				for o in _club_names():
					if str(o) != nm and kizuna_level(nm, str(o)) >= 1: n += 1
				keys = ["%d bond%s" % [n, "" if n == 1 else "s"]]
			_: keys = ["dressed" if _is_dressed(nm) else role_label(stable_role(nm))]
		for k in keys:
			if not groups.has(k): groups[k] = []; order.append(k)
			groups[k].append(nm)
	return order.map(func(k): return "%s: %s" % [str(k), ", ".join(PackedStringArray(groups[k]))])

func locker_lines(by: String, focus: String) -> Array:
	# between duals: the stable browsed, the focused card's comparison card, the releases waiting on their three days
	var out: Array = []
	if _lk().is_empty(): return out
	out.append("THE LOCKER ROOM (%d of %d) by %s - %s" % [stable.size(), int(_scouting().get("stable_cap", 100)), by, " | ".join(PackedStringArray(locker_browse(by)))])
	if focus != "" and _stable_card(focus).size() > 0: out.append("THE CARD  " + card_view(focus) + ("" if release_why(focus) == "" else "  (%s)" % release_why(focus)))
	var pd: Dictionary = rewards.get("locker", {}).get("pending", {})
	if pd.size() > 0: out.append("RELEASED: " + ", ".join(PackedStringArray(pd.keys().map(func(k): return "%s (day %d, %s; take back until day %d)" % [str(k), int(pd[k]["day"]), str(pd[k]["flag"]), int(pd[k]["day"]) + int(_lk().get("undo_days", 3))]))))
	return out

func recruits_open() -> Array:
	# the approachable and the approached, in the order they were flagged
	var out: Array = []
	for nm in rewards["recruit"]:
		var st := recruit_state(str(nm))
		if st == "approachable" or st == "approached": out.append(str(nm))
	return out

func approach(name: String) -> Dictionary:
	# the overworld's approach: his condition surfaces ("*" approaches everyone flagged)
	if name == "*":
		var got: Array = []
		for nm in recruits_open():
			if recruit_state(nm) == "approachable" and bool(approach(nm)["ok"]): got.append(nm)
		return {"ok": got.size() > 0, "why": "" if got.size() > 0 else "nobody to approach", "names": got}
	var st := recruit_state(name)
	var why := ""
	match st:
		"": why = "%s is not approachable - beat his club in a dual first" % name
		"never": why = "%s: %s" % [name, str(_recruit_rec(name)["never"])]
		"joined": why = "%s is in the stable already" % name
		"approached": why = "%s has been approached - his condition stands" % name
		"academy": why = "%s signed with %s at %s - beat the academy first" % [name, str(ACAD.get("club", "the academy")), str(rewards["recruit"][name].get("turn", ""))]
		"released": why = "%s was released on day %d - the club can take the card back until day %d (the locker room)" % [name, int(rewards["recruit"][name].get("day", 1)), int(rewards["recruit"][name].get("day", 1)) + int(_lk().get("undo_days", 3))]
	if _recruit_rec(name).is_empty() and sw_node(name).size() > 0: why = _sw_not_a_recruit(name)             # PAC-076: a lead or a house on the String Wall
	if why != "": _ev("recruit_refused", {"name": name, "why": why}); return {"ok": false, "why": why}
	rewards["recruit"][name]["state"] = "approached"
	var v := recruit_view(name)
	_ev("recruit_condition", {"name": name, "card": v["card"], "condition": v["condition"], "clauses": v["clauses"], "met": v["met"]})
	_say("APPROACHED %s :: %s" % [v["card"], " AND ".join(PackedStringArray(v["clauses"].map(func(cl): return "%s [%d/%d%s]" % [str(cl["text"]), int(cl["have"]), int(cl["need"]), " MET" if bool(cl["met"]) else ""])))])
	_recruit_check()
	return {"ok": true, "why": "", "view": v}

func recruit_card(name: String) -> Dictionary:
	# his card: a Millbrook card the greybox already carries (the four editorial recruits), else his pattern's META style / element / House,
	# the assembler's stat block at the table's tier, his desperation move (or the table's draft) as his hissatsu; no talk profile yet
	var rec := _recruit_rec(name)
	if bool(rec.get("from_lineup", false)):
		for c in LINEUP_MILLBROOK_8:
			if str(c["name"]) == str(rec.get("card", "")):
				var cc: Dictionary = c.duplicate(true); cc.erase("reserve"); return cc
	var m: Dictionary = patterns.get(name, {}).get("meta", {})
	var br := boss_rings(name)
	var hiss := str(rec.get("hissatsu", patterns.get(name, {}).get("desperation", {}).get("move", "")))
	return {"name": str(rec.get("card", name.to_upper())), "hissatsu": hiss, "style": str(br[0]), "element": str(br[1]), "house": str(m.get("house", "none")) if house_key(str(m.get("house", "none"))) != "none" else "none",
		"stats": TNBAssembler.default_stats(PIECES, int(RECRUITS.get("card_tier", 3)))}

func recruit(name: String) -> Dictionary:
	# the recruit's answer: approached and every clause met -> his card joins the stable (dressable on a board, written by the save); else refused, naming what is unmet
	_world_sync()                                                                                        # PAC-077: a blessing met by now lands before he answers
	if name == "*":
		var got: Array = []
		var more := true
		while more:                                                                                     # PAC-076: a join's string may surface someone already met - "*" signs him too
			more = false
			for nm in recruits_open():
				var rv0 := recruit_view(nm)
				if (bool(rv0.get("met", false)) or bool(rv0.get("around_met", false))) and recruit_state(nm) == "approached" and bool(recruit(nm)["ok"]): got.append(nm); more = true
		return {"ok": got.size() > 0, "why": "" if got.size() > 0 else "nobody is ready", "names": got}
	var st := recruit_state(name)
	var why := ""
	if st == "joined": why = "%s is in the stable already" % name
	elif st == "never": why = "%s: %s" % [name, str(_recruit_rec(name)["never"])]
	elif st != "approached": why = "%s has not been approached" % name
	if _recruit_rec(name).is_empty() and sw_node(name).size() > 0: why = _sw_not_a_recruit(name)             # PAC-076: a lead or a house on the String Wall
	if why == "" and not _scouting().is_empty() and stable.size() >= int(_scouting().get("stable_cap", 100)): why = "the stable holds %d - NP_08 s1's cap (the locker room releases a card)" % stable.size()   # PAC-100
	var v := recruit_view(name)
	if why == "" and not bool(v["met"]) and not bool(v.get("around_met", false)):
		var unmet: Array = []
		for cl in v["clauses"]:
			if not bool(cl["met"]): unmet.append("%s (%d of %d)" % [str(cl["text"]), int(cl["have"]), int(cl["need"])])
		why = "%s is not ready - %s" % [name, "; ".join(PackedStringArray(unmet))]
	if why != "": _ev("recruit_refused", {"name": name, "why": why}); return {"ok": false, "why": why}
	var card := recruit_card(name)
	var back: Dictionary = rewards["recruit"][name].get("released", {})
	if back.size() > 0 and back.get("card", {}).size() > 0: card = back["card"].duplicate(true)          # PAC-100: a card released comes back as it left (NP_08 s4: people aren't cartridges)
	stable.append(card)
	rewards["recruit"][name]["state"] = "joined"
	if back.size() > 0:
		var bk: Dictionary = back.duplicate(true); bk.erase("card"); rewards["recruit"][name]["returned"] = bk; rewards["recruit"][name].erase("released")
	var via_rn := str(rewards["recruit"][name].get("via", ""))
	_gw_pin_new(str(card["name"]), _gw_card_of_recruit(via_rn) if via_rn != "" else "")                 # PAC-079: his card beside the stablemate whose string brought him
	_gw_deco("graffiti", "%s's wraps" % str(card["name"]), {"card": str(card["name"])})
	var hs := house_status(str(card["name"]))
	_ev("recruit_joined", {"name": name, "card": str(card["name"]), "style": str(card["style"]), "element": str(card["element"]), "house": str(card["house"]), "stable": stable.size(), "house_status": hs, "natives": natives_unlocked(str(card["name"])), "around": not bool(v["met"])})
	if hs == "UNSANCTIONED": _say("%s arrives UNSANCTIONED - House %s has not blessed the club: natives locked, no home bonus" % [str(card["name"]), str(HOUSES.get("houses", {}).get(house_key(str(card["house"])), {}).get("name", card["house"]))])
	elif hs == "NATIVE": _say("%s arrives with House %s's blessing - natives unlocked: %s" % [str(card["name"]), str(HOUSES.get("houses", {}).get(house_key(str(card["house"])), {}).get("name", card["house"])), ", ".join(PackedStringArray(natives_unlocked(str(card["name"]))))])
	_toast({"size": "recruit", "who": [str(card["name"])], "xp": 0, "prestige": 0, "spirits": 0, "hbp": 0, "kizuna": "", "pi": false, "won": true, "text": "%s JOINS THE STABLE (%d cards)" % [str(card["name"]), stable.size()]})
	_recruit_check()                                                                                     # PAC-076: his strings go up on the wall (NP_08 s2.3)
	return {"ok": true, "why": "", "card": card}

func _recruit_after_dual(won: bool) -> void:
	# NP_08 s2.1: a club beaten flags its named fighters approachable (up to the table's 4, the squad's order; a non-boss recruit comes with his boss);
	# every approached fighter watched the win (WITNESS)
	if not won or bout.size() > 0 or RECRUITS.is_empty(): return
	if academy_on: _academy_beaten()                                                                     # PAC-102: the academy beaten - its rivals come over
	for b in bdressed: _beat("dual", str(b))                                                            # BEAT_IN(dual): his club beaten in a dual
	for nm in rewards["recruit"]:
		if str(rewards["recruit"][nm].get("state", "")) == "approached": rewards["recruit"][nm]["witnessed"] = int(rewards["recruit"][nm].get("witnessed", 0)) + 1
	_house_witness()                                                                                     # PAC-077: a house whose crest is up watched this dual
	var flagged: Array = []
	var cap := int(RECRUITS.get("approachable_per_dual", 4))
	for b in bdressed:
		var cands: Array = [str(b)]
		for rn in RECRUITS.get("recruits", {}):
			if str(RECRUITS["recruits"][rn].get("with", "")) == str(b): cands.append(str(rn))
		for rn in cands:
			if flagged.size() >= cap: break
			if recruit_state(rn) == "" and _recruit_rec(rn).size() > 0:
				rewards["recruit"][rn] = {"state": "approachable", "witnessed": 0, "day": int(rewards.get("day", 1))}; flagged.append(rn)
	if flagged.size() > 0:
		_ev("recruit_approachable", {"names": flagged})
		_say("APPROACHABLE after the win: %s" % ", ".join(PackedStringArray(flagged.map(func(x): return str(_recruit_rec(str(x)).get("card", x))))))
	_recruit_check()

func _recruit_check() -> void:
	# a condition newly met raises recruit_ready - once; nobody joins on his own. The graph, the blessings and the String Wall first (PAC-076/077):
	# a flag, a join or a blessing may have moved them. A recruit met only around his family (PAC-077) is ready too, and says so
	_world_sync()
	for nm in recruits_open():
		if recruit_state(nm) != "approached" or bool(rewards["recruit"][nm].get("ready", false)): continue
		var rv := recruit_view(nm)
		if bool(rv.get("met", false)) or bool(rv.get("around_met", false)):
			rewards["recruit"][nm]["ready"] = true
			_ev("recruit_ready", {"name": nm, "card": str(_recruit_rec(nm).get("card", "")), "around": not bool(rv.get("met", false))}); _say("%s would join%s - recruit him" % [str(_recruit_rec(nm).get("card", nm)), "" if bool(rv.get("met", false)) else " around his family (UNSANCTIONED)"])

static func seed_levels(ledger: Dictionary, lv_s: String, eco: Dictionary) -> Dictionary:
	# `-- level=RORY:20,PRIYA:20` -> the reward ledger's XP at those levels (NP_11 s2's curve: k L^2; PAC-082: the Zone opens at 20)
	var out := ledger.duplicate(true)
	if not out.has("xp"): out["xp"] = {}
	var k := float(eco.get("xp", {}).get("curve_k", 48))
	for part in lv_s.split(","):
		var kv := part.split(":")
		if kv.size() == 2 and str(kv[1]).strip_edges().is_valid_int(): out["xp"][str(kv[0]).strip_edges()] = int(k * pow(float(str(kv[1]).strip_edges()), 2.0))
	return out

static func seed_story(ledger: Dictionary, flags_s: String) -> Dictionary:
	# `-- flag=quest:tremblay_feud,rep:rink_district:3,feud_resolved:tremblay+coach_line` -> the story flags the overworld would set
	var out := ledger.duplicate(true)
	if not out.has("story"): out["story"] = {}
	for part in flags_s.split(","):
		var p := str(part).strip_edges()
		if p == "": continue
		var bits := p.split(":")
		if bits.size() >= 3 and bits[bits.size() - 1].is_valid_int(): out["story"][":".join(bits.slice(0, bits.size() - 1))] = int(bits[bits.size() - 1])
		else: out["story"][p] = true
	return out

func recruit_lines() -> Array:
	# the recruits the club has flagged, for the HUD and the demo's log (PAC-102: and those the academy signed)
	var out: Array = academy_lines()
	for nm in recruits_open():
		var v := recruit_view(nm)
		if str(v["state"]) == "approachable": out.append("%s (%s): approachable - approach to learn his condition" % [str(v["card"]), nm])
		else: out.append("%s (%s%s): %s%s" % [str(v["card"]), nm, (", via " + sw_label(str(v["via"]))) if v.has("via") else "", " AND ".join(PackedStringArray(v["clauses"].map(func(cl): return "%s %d/%d%s" % [str(cl["text"]), int(cl["have"]), int(cl["need"]), " ok" if bool(cl["met"]) else ""]))), "  >> READY" if bool(v["met"]) else ""])
	return out

# ============================ THE STRING WALL (NP_08 s2.3) ==================
# The connection maps: a node recruited reveals its adjacent nodes (family both ways, master to student, member to his house); a house's
# blessing (the overworld's blessing:<house> flag) reveals its members and the houses bound to it on the feud graph, never across a FEUD;
# a house with no one left to bless opens with its crest. A revealed fighter is approached (his condition surfaces, the string he came by
# kept); a revealed lead is on the wall and joins nothing the sim builds. Everything the wall knows is in the ledger: rewards.string_wall
# (the revealed, with the string and the day) and C29's recruit ledger (the fighters' states).
func sw_node(id: String) -> Dictionary:
	# a node with its map's id; {} when the wall has none
	for m in STRINGS.get("maps", []):
		for n in m.get("nodes", []):
			if str(n["id"]) == id:
				var out: Dictionary = n.duplicate(true); out["map"] = str(m["id"]); return out
	return {}

func sw_links(id: String) -> Array:
	# every string with that node at one end, in the table's order
	var out: Array = []
	for m in STRINGS.get("maps", []):
		for l in m.get("links", []):
			if str(l["a"]) == id or str(l["b"]) == id: out.append(l)
	return out

func sw_house_node(house: String) -> String:
	for m in STRINGS.get("maps", []):
		for n in m.get("nodes", []):
			if str(n.get("kind", "")) == "house" and str(n.get("house", "")) == house: return str(n["id"])
	return ""

func _story_set(key: String) -> bool:
	var v = rewards["story"].get(key, false)
	return bool(v) if v is bool else int(v) > 0

func sw_state(id: String) -> String:
	# what the wall shows: a fighter his C29 state (approachable / approached / joined, or never once a string reaches him); a lead "lead";
	# a house "blessed" / "unblessed" / "no blessing"; "" while the card is face down
	var n := sw_node(id)
	if n.is_empty(): return ""
	var up: bool = rewards["string_wall"].has(id)
	match str(n.get("kind", "")):
		"fighter":
			var st := recruit_state(id)
			if st == "approachable" or st == "approached" or st == "joined" or st == "academy": return st   # PAC-102: at the academy
			return "never" if st == "never" and up else ""
		"lead": return "lead" if up else ""
		"house":
			if not up: return ""
			if n.get("blessing") == null: return "no blessing"
			if bool(rewards["houses"].get(str(n["house"]), {}).get("revoked", false)): return "revoked"
			return "blessed" if house_blessed(str(n["house"])) else "unblessed"
	return ""

func sw_label(via: String) -> String:
	# a node's label, or the blessing a string came by
	if via.begins_with("blessing:"): return "the %s blessing" % via.substr(9).capitalize()
	var n := sw_node(via)
	return str(n.get("label", via)) if n.size() > 0 else via

func _sw_not_a_recruit(id: String) -> String:
	# a lead or a house is on the wall, not in the recruit table: nothing in the sim signs it
	var n := sw_node(id)
	if str(n.get("kind", "")) == "house": return "%s is a house on the String Wall - its blessing is the overworld's (blessing:%s)" % [str(n["label"]), str(n["house"])]
	return "%s is a lead on the String Wall (%s) - no card in the sim; the overworld signs a lead" % [str(n["label"]), str(n.get("role", ""))]

func _sw_reveal(id: String, via: String, kind: String, got: Dictionary) -> void:
	# one card turned face up by a string: recorded with the string and the day; a fighter nobody had approached is approached (his condition
	# surfaces as an approach would); a fighter the club already approached or signed adds nothing
	var n := sw_node(id)
	if n.is_empty() or rewards["string_wall"].has(id): return
	if str(n["kind"]) == "fighter":
		var st := recruit_state(id)
		if st == "approached" or st == "joined": return
	rewards["string_wall"][id] = {"via": via, "kind": kind, "day": int(rewards.get("day", 1))}
	if str(n["kind"]) == "fighter" and recruit_state(id) != "never":
		var rec: Dictionary = rewards["recruit"].get(id, {"state": "", "witnessed": 0, "day": int(rewards.get("day", 1))})
		rec["state"] = "approached"; rec["via"] = via
		rewards["recruit"][id] = rec
	if not got.has(via): got[via] = []
	got[via].append(id)

func _sw_sync() -> int:
	# the wall to a fixed point, in the table's order; each string that surfaced someone raises wall_revealed (and a fighter's condition
	# surfaces as recruit_condition, with the string); returns how many cards turned
	if STRINGS.is_empty(): return 0
	var got := {}
	var turned := -1; var total := 0
	while turned != 0:
		var before := 0
		for v in got: before += got[v].size()
		for m in STRINGS.get("maps", []):
			for n in m.get("nodes", []):
				var id := str(n["id"])
				match str(n.get("kind", "")):
					"fighter":
						if str(rewards["recruit"].get(id, {}).get("state", "")) != "joined": continue     # recruited through the ledger - a card the club began with brings no strings
						for l in sw_links(id):
							var other := ""
							if str(l["kind"]) == "family": other = str(l["b"]) if str(l["a"]) == id else str(l["a"])
							elif str(l["a"]) == id: other = str(l["b"])                                  # master -> student, member -> his house
							if other != "": _sw_reveal(other, id, str(l["kind"]), got)
					"house":
						var hk := str(n["house"])
						var flag := "blessing:" + hk
						var blessed := house_blessed(hk)                                                  # PAC-077: the flag or the line met
						if blessed: _sw_reveal(id, flag, "blessing", got)
						var opens: bool = blessed or (n.get("blessing") == null and rewards["string_wall"].has(id))
						if opens:
							for l in sw_links(id):
								if str(l["kind"]) == "house" and str(l["b"]) == id: _sw_reveal(str(l["a"]), flag if blessed else id, "house", got)
						if blessed:
							for e in live_edges():
								if not (edge_relation(e) in STRINGS.get("chain_relations", [])): continue
								var oh := str(e["b"]) if str(e["a"]) == hk else (str(e["a"]) if str(e["b"]) == hk else "")
								var on := sw_house_node(oh) if oh != "" else ""
								if on != "": _sw_reveal(on, flag, "%s %s" % [str(e.get("id", "")), edge_relation(e)], got)
		var after := 0
		for v in got: after += got[v].size()
		turned = after - before; total = after
	for via in got:
		var labels: Array = got[via].map(func(x): return sw_label(str(x)))
		_ev("wall_revealed", {"via": via, "from": sw_label(via), "names": got[via], "labels": labels})
		_say("STRING WALL :: %s -> %s" % [sw_label(via), ", ".join(PackedStringArray(labels))])
		for nm in got[via]:
			if str(sw_node(str(nm)).get("kind", "")) == "fighter" and recruit_state(str(nm)) == "approached":
				var rv := recruit_view(str(nm))
				_ev("recruit_condition", {"name": str(nm), "card": rv["card"], "condition": rv["condition"], "clauses": rv["clauses"], "met": rv["met"], "via": via})
	return total

func string_wall() -> Dictionary:
	# the wall as the recruit ledger's view (NP_11 s9 SaveGame.string_wall {maps, leads}): per map its face-up cards with their state and the
	# strings between them, and how many are still face down; the feud graph's strings between face-up houses; the leads the strings surfaced
	var maps: Array = []; var up_n := 0; var all_n := 0
	for m in STRINGS.get("maps", []):
		var nodes: Array = []; var ids: Array = []
		for n in m.get("nodes", []):
			all_n += 1
			var id := str(n["id"]); var st := sw_state(id)
			if st == "": continue
			ids.append(id)
			var nv := {"id": id, "kind": str(n["kind"]), "label": str(n["label"]), "state": st}
			var r: Dictionary = rewards["string_wall"].get(id, {})
			if r.size() > 0: nv["via"] = str(r["via"]); nv["string"] = str(r["kind"]); nv["day"] = int(r["day"])
			match str(n["kind"]):
				"fighter": if st == "never": nv["why"] = str(_recruit_rec(id).get("never", ""))
				"lead":
					nv["role"] = str(n.get("role", ""))
					if str(n.get("condition", "")) != "":
						nv["condition"] = str(n["condition"])
						nv["clauses"] = condition_state(str(n["condition"]), id).map(func(c): return "%s %d/%d%s" % [str(c["text"]), int(c["have"]), int(c["need"]), " ok" if bool(c["met"]) else ""])
				"house":
					nv["blessing"] = str(n["blessing"]) if n.get("blessing") != null else ""
					nv["blessing_clauses"] = house_clauses(str(n["house"])).map(func(c): return "%s %d/%d%s" % [str(c["text"]), int(c["have"]), int(c["need"]), " ok" if bool(c["met"]) else ""])   # PAC-077: the line read against the ledgers
			nodes.append(nv)
		up_n += nodes.size()
		var strings: Array = []
		for l in m.get("links", []):
			if str(l["a"]) in ids and str(l["b"]) in ids:
				var sv := {"a": str(l["a"]), "b": str(l["b"]), "kind": str(l["kind"])}
				if l.has("bond"): sv["bond"] = str(l["bond"])
				strings.append(sv)
		maps.append({"id": str(m["id"]), "title": str(m["title"]), "known": nodes.size(), "total": m.get("nodes", []).size(), "nodes": nodes, "strings": strings})
	var bonds: Array = []
	for e in live_edges():
		var ha := sw_house_node(str(e["a"])); var hb := sw_house_node(str(e["b"]))
		if ha != "" and hb != "" and sw_state(ha) != "" and sw_state(hb) != "": bonds.append({"id": str(e.get("id", "")), "a": ha, "b": hb, "relation": edge_relation(e)})
	var leads: Array = []                                                                                 # in the table's order, not the ledger's (a save writes the ledger's keys sorted)
	for m2 in STRINGS.get("maps", []):
		for n2 in m2.get("nodes", []):
			var id2 := str(n2["id"])
			if not rewards["string_wall"].has(id2): continue
			var r2: Dictionary = rewards["string_wall"][id2]
			leads.append({"id": id2, "kind": str(n2["kind"]), "label": str(n2["label"]), "via": str(r2["via"]), "string": str(r2["kind"]), "day": int(r2["day"]), "state": sw_state(id2)})
	return {"maps": maps, "bonds": bonds, "leads": leads, "known": up_n, "total": all_n}

func string_wall_lines() -> Array:
	# the wall for the HUD and the demo's log: one line per map with a card face up, then the houses' strings
	var out: Array = []
	var w := string_wall()
	if int(w["known"]) == 0: return out
	var word := {"joined": "in the stable", "approached": "approached", "approachable": "approachable", "never": "closed", "lead": "lead", "blessed": "blessed", "unblessed": "unblessed", "no blessing": "no blessing", "academy": "at the academy"}
	for m in w["maps"]:
		if int(m["known"]) == 0: continue
		var tags: Array = []
		for nv in m["nodes"]:
			var t := "%s [%s%s]" % [str(nv["label"]), str(word.get(str(nv["state"]), nv["state"])), (" <- " + sw_label(str(nv["via"]))) if nv.has("via") else ""]
			if nv.has("clauses"): t += " " + " AND ".join(PackedStringArray(nv["clauses"]))
			tags.append(t)
		out.append("%s %d/%d: %s" % [str(m["title"]).to_upper(), int(m["known"]), int(m["total"]), ", ".join(PackedStringArray(tags))])
	if w["bonds"].size() > 0:
		out.append("HOUSES: " + ", ".join(PackedStringArray(w["bonds"].map(func(b): return "%s = %s (%s)" % [sw_label(str(b["a"])), sw_label(str(b["b"])), str(b["relation"])]))))
	return out

# ============================ HOUSE TRAITS (NP_07 s3, s5) ====================
# The nine authored traits (houses.v1.json `traits`) live on the fighter whose house carries one, on both corners where a boss has an
# analogue. NP_07 s3: 'house-locked, never transferable - blood/adoption only' - a META lineage that is not blood (taken, extracted, a teaching
# root system) carries none, nor does a disowned heir (s5); UNSANCTIONED keeps it (s5 takes only the home bonus); the last of a dead lineage
# doubles it; the three s8 variants are named, not executed. Every multiplier stops at NP_06 s4's cap.
func trait_of_house(raw_house: String, disowned: bool = false) -> Dictionary:
	# {id (the effect run), trait (the house's own id), name, x (2 when doubled), house}; {} when he carries none
	var h := house_key(raw_house)
	var hd: Dictionary = HOUSES.get("houses", {}).get(h, {})
	if hd.is_empty() or disowned or hd.get("trait_id") == null: return {}
	var rk := raw_house.strip_edges().to_lower()
	for q in HOUSES.get("lineage", {}):
		if rk.ends_with(str(q)) and not bool(HOUSES["lineage"][q].get("blood", true)): return {}
	var tid := str(hd["trait_id"])
	var td: Dictionary = HOUSES.get("traits", {}).get(tid, {})
	if td.is_empty(): return {}
	var eff := tid
	if td.has("base"):
		if not bool(td.get("executed", false)): return {}
		eff = str(td["base"])
	return {"id": eff, "trait": tid, "name": str(td["name"]), "x": 2 if bool(hd.get("last_of_line", {}).get("doubled", false)) else 1, "house": h}

func card_trait(card: Dictionary) -> Dictionary:
	if card.is_empty(): return {}
	return trait_of_house(str(card.get("house", "none")), bool(card.get("disowned", false)))

func _tx(F: Dictionary, id: String) -> float:
	# how many times over this fighter carries that trait (0, 1, or 2 doubled) - his own, or one he inherits (PAC-084; 0.75 in an Awakening),
	# the larger
	var n := 0.0
	for tr in [F.get("trait", {}), F.get("trait_inh", {})]:
		if tr.size() > 0 and str(tr["id"]) == id: n = maxf(n, float(tr["x"]))
	return n

func _tmult(base: float, x: float, F: Dictionary = {}) -> float:
	return minf(_cap_of(F), 1.0 + (base - 1.0) * x)

func _cap_of(F: Dictionary) -> float:
	# NP_06 s4's cap on any computed advantage (x1.5); the Awakened fighter's x1.75 (NP_09 s6: the only exception)
	if F.size() > 0 and is_same(F, P) and tform.has("fx") and _zone_fx().has("ring_cap"): return float(_zone_fx()["ring_cap"])
	return float(AFF.get("cap", 1.5))

func _sfloor(F: Dictionary) -> float:
	# Tide Discipline: the stamina floor every drain stops at (0 without it); in the Zone, the stamina it froze (PAC-082: no drain)
	var fl := float(HOUSES["traits"]["tide_discipline"]["stamina_floor"]) * _tx(F, "tide_discipline") if _tx(F, "tide_discipline") > 0 else 0.0
	if tform.size() > 0 and is_same(F, P) and _frac(_zone_fx().get("stamina_frozen", false)) >= 1.0: fl = maxf(fl, float(tform["stam"]))
	if btform.size() > 0 and is_same(F, B) and _frac(_bfx().get("stamina_frozen", false)) >= 1.0: fl = maxf(fl, float(btform["stam"]))   # PAC-086: his Zone
	return fl

func _trait_stat_mult(F: Dictionary, opp_house: String) -> float:
	# Long Winter in the R4/R5 slots; Debt of Honour against a house his is feuding with on the live graph
	var tr: Dictionary = F.get("trait", {})
	if tr.is_empty(): return 1.0
	var td: Dictionary = HOUSES["traits"][str(tr["id"])]
	match str(tr["id"]):
		"long_winter":
			if float(seg_idx + 1) in td.get("slots", []).map(func(v): return float(v)): return _tmult(float(td["stats_mult"]), float(tr["x"]), F)
		"debt_of_honour":
			if _feud_between(str(F["house"]), opp_house): return _tmult(float(td["stats_mult"]), float(tr["x"]), F)
	return 1.0

func _restat(F: Dictionary, mult: float) -> void:
	# every stat x mult (to 99), the pools the stats set re-drawn (_fresh then _dress): composure from CHN, the guard from BLK
	var st: Dictionary = F["stats"].duplicate()
	for k in st: st[k] = minf(99.0, float(st[k]) * mult)
	F["stats"] = st
	var g: Dictionary = T["guard"]["capacity_by_BLK"]
	F["comp_max"] = float(st["CHN"]) * 2.0 * float(F["pkg"].get("comp_pool_mult", 1.0)); F["comp"] = F["comp_max"]
	F["guard_max"] = lerpf(float(g["min"]), float(g["max"]), float(st["BLK"]) / 99.0) * float(F["pkg"].get("guard_cap_mult", 1.0)); F["guard"] = F["guard_max"]

func _never_twice(F: Dictionary, who: String) -> bool:
	# the second drop of the segment is a wobble instead, once a dual (twice, doubled)
	if _tx(F, "never_twice") == 0 or int(F.get("drops", 0)) != 1 or r6: return false
	var nm := pname() if who == "P" else boss_name
	var key := "%s:%s" % [who, nm]
	if int(trait_uses.get(key, 0)) >= int(HOUSES["traits"]["never_twice"]["uses_per_dual"]) * _tx(F, "never_twice"): return false
	trait_uses[key] = int(trait_uses.get(key, 0)) + 1
	F["comp"] = F["comp_max"] * (float(T["composure"]["wobble_below_pct"]) - 1.0) / 100.0
	_ev("trait", {"who": who, "name": nm, "trait": "never_twice", "what": "wobble"})
	_say("NEVER TWICE - %s will not go down twice in a segment: wobbled, still standing" % nm)
	return true

# ============================ BLESSINGS AND THE LIVE GRAPH (NP_08 s3, NP_07 s5-6, NP_07A s1-2) ===========
# A house's blessing line (houses.v1.json, NP_07A's) is read against the ledgers with the house as its subject; met - or the overworld's
# blessing:<house> flag set - the house blesses the club, and the ledger keeps the day and how. A recruit of a blessed house is NATIVE (natives
# unlocked, the home bonus live); of an unblessed one UNSANCTIONED, sanctioned when the blessing lands. The feud graph flips on its questlines'
# flags (feud_graph.v1.json `flip`), in the ledger - never in the table; the house ring, the Kizuna's ALLIED bonus, FEUD_RESOLVED and the
# String Wall's chains read the graph as it stands.
func _flag_set(key: String) -> bool:
	# a story flag, a feud_resolved pair in either order
	if _story_set(key): return true
	if key.begins_with("feud_resolved:") and "+" in key:
		var pr := key.substr(14).split("+")
		if pr.size() == 2: return _story_set("feud_resolved:%s+%s" % [pr[1], pr[0]])
	return false

func house_blessed(h: String) -> bool:
	var r: Dictionary = rewards["houses"].get(h, {})
	return bool(r.get("blessed", false)) and not bool(r.get("revoked", false))

func house_state(h: String) -> String:
	# blessed / revoked / unblessed / no blessing (Iron) / sealed
	var hd: Dictionary = HOUSES.get("houses", {}).get(h, {})
	if hd.is_empty(): return ""
	if bool(hd.get("sealed", false)): return "sealed"
	if bool(rewards["houses"].get(h, {}).get("revoked", false)): return "revoked"
	if hd.get("blessing") == null: return "no blessing"
	return "blessed" if house_blessed(h) else "unblessed"

func house_clauses(h: String) -> Array:
	var hd: Dictionary = HOUSES.get("houses", {}).get(h, {})
	if hd.get("blessing") == null: return []
	return condition_state(str(hd["blessing"]), "house:" + h)

func _recruit_of_card(nm: String) -> String:
	# the recruit record a joined card came through ("" for a card the club began with)
	for rn in rewards["recruit"]:
		if str(rewards["recruit"][rn].get("state", "")) == "joined" and str(_recruit_rec(str(rn)).get("card", "")) == nm: return str(rn)
	return ""

func house_status(nm: String) -> String:
	# NP_11 s9 Fighter.house_status: NATIVE, UNSANCTIONED, or "" without a house. A card the club began with is NATIVE (the story recruited
	# him before the ledger); a recruit is NATIVE when his house has blessed the club, UNSANCTIONED until then
	var c := _stable_card(nm)
	if c.is_empty(): c = _card_of(nm)
	var h := house_key(str(c.get("house", "none")))
	if c.is_empty() or h == "none": return ""
	if _recruit_of_card(nm) == "": return "NATIVE"
	return "NATIVE" if house_blessed(h) else "UNSANCTIONED"

func house_natives(h: String) -> Array:
	# the house's natives: the library's moves of that house, the SECRET excepted (its gate event's, NP_07 s4)
	var out: Array = []
	for mn in library:
		var m: Dictionary = library[mn]
		if m.get("house_id") != null and str(m["house_id"]) == h and not bool(m.get("secret", false)): out.append(str(mn))
	return out

func natives_unlocked(nm: String) -> Array:
	if house_status(nm) != "NATIVE": return []
	var c := _stable_card(nm)
	if c.is_empty(): c = _card_of(nm)
	return house_natives(house_key(str(c.get("house", "none"))))

func _graph_sync() -> int:
	# the questlines' flips (NP_07A s1): an edge whose flags are all set flips (FEUD->ALLIED, DEBT->ALLIED), E11 answers with its refusal, a
	# provisional edge is added; recorded once in the ledger's graph with the day and the flags
	var n := 0
	for e in FEUDS:
		var f: Dictionary = e.get("flip", {})
		var eid := str(e.get("id", ""))
		if f.is_empty() or f.has("held") or rewards["graph"].has(eid) or f.get("on", []).is_empty(): continue
		var all_on := true
		for k in f["on"]:
			if not _flag_set(str(k)): all_on = false
		if not all_on: continue
		var lbl := "%s %s-%s" % [eid, str(e["a"]).capitalize(), str(e["b"]).capitalize()]
		if f.has("refused"):
			rewards["graph"][eid] = {"refused": true, "day": int(rewards.get("day", 1)), "on": f["on"]}
			_ev("graph_refused", {"edge": eid, "a": str(e["a"]), "b": str(e["b"]), "relation": str(e["relation"]), "why": str(f["refused"])})
			_say("FEUD GRAPH :: %s stays %s - %s" % [lbl, str(e["relation"]), str(f["refused"])])
		else:
			rewards["graph"][eid] = {"from": str(e["relation"]), "to": str(f["to"]), "day": int(rewards.get("day", 1)), "on": f["on"]}
			_ev("graph_mutated", {"edge": eid, "a": str(e["a"]), "b": str(e["b"]), "from": str(e["relation"]), "to": str(f["to"]), "questline": str(f.get("questline", ""))})
			_say("FEUD GRAPH :: %s %s -> %s (%s)" % [lbl, str(e["relation"]), str(f["to"]), str(f.get("questline", ""))])
		n += 1
	for pe in HOUSES.get("provisional_edges", []):
		var pid := str(pe.get("id", ""))
		if rewards["graph"].has(pid): continue
		var all_p := true
		for k2 in pe.get("on", []):
			if not _flag_set(str(k2)): all_p = false
		if not all_p or pe.get("on", []).is_empty(): continue
		rewards["graph"][pid] = {"added": true, "relation": str(pe["relation"]), "day": int(rewards.get("day", 1)), "on": pe["on"]}
		_ev("graph_mutated", {"edge": pid, "a": str(pe["a"]), "b": str(pe["b"]), "from": "", "to": str(pe["relation"]), "questline": "provisional", "added": true})
		_say("FEUD GRAPH :: %s %s-%s added, %s (%s)" % [pid, str(pe["a"]).capitalize(), str(pe["b"]).capitalize(), str(pe["relation"]), str(pe.get("when", ""))])
		n += 1
	return n

func _bless_sync() -> int:
	# every house whose line is met (or whose flag the overworld set) blesses the club, once; its recruits in the stable are sanctioned with it
	var n := 0
	for h in HOUSES.get("houses", {}):
		var hd: Dictionary = HOUSES["houses"][h]
		if hd.get("blessing") == null or bool(hd.get("sealed", false)): continue
		var rec: Dictionary = rewards["houses"].get(h, {})
		if bool(rec.get("blessed", false)) or bool(rec.get("revoked", false)): continue
		var how := ""
		if _story_set("blessing:" + str(h)): how = "flag"
		else:
			var cl := house_clauses(str(h))
			var ok := cl.size() > 0
			for c in cl:
				if not bool(c["met"]): ok = false
			if ok: how = "met"
		if how == "": continue
		rec["blessed"] = true; rec["day"] = int(rewards.get("day", 1)); rec["how"] = how
		rewards["houses"][h] = rec
		var sanc: Array = []
		for c2 in stable:
			if house_key(str(c2.get("house", "none"))) == str(h) and _recruit_of_card(str(c2["name"])) != "": sanc.append(str(c2["name"]))
		_ev("blessing_granted", {"house": str(h), "name": str(hd["name"]), "how": how, "line": str(hd["blessing"]), "sanctioned": sanc, "natives": house_natives(str(h))})
		_gw_honour("crest", "crest:" + str(h), "House %s's crest" % _house_name(str(h)))                 # PAC-089: the honours set, from The Wall's tier
		_say("BLESSING :: House %s blesses the club (%s)%s" % [str(hd["name"]), "the overworld's flag" if how == "flag" else str(hd["blessing"]), (" - sanctioned: " + ", ".join(PackedStringArray(sanc))) if sanc.size() > 0 else ""])
		for nm in sanc: _ev("sanctioned", {"card": nm, "house": str(h), "natives": natives_unlocked(nm)})
		n += 1
	return n

func _world_sync() -> int:
	# the graph, then the blessings (FEUD_RESOLVED reads the graph), then the String Wall (it opens on blessings, chains on the graph) - to rest
	var total := 0
	for i in 8:
		var n := _graph_sync() + _bless_sync() + _sw_sync()
		total += n
		if n == 0: break
	return total

func _house_witness() -> void:
	# a dual won: every unblessed house whose line asks a WITNESS and whose crest is up on the String Wall watched it (Tagaq's only when your
	# corner converted no crowd heat)
	for h in HOUSES.get("houses", {}):
		var hd: Dictionary = HOUSES["houses"][h]
		if hd.get("blessing") == null or not ("WITNESS(" in str(hd["blessing"])) or house_blessed(str(h)): continue
		var hn := sw_house_node(str(h))
		if hn == "" or sw_state(hn) == "": continue
		if str(hd.get("witness", {}).get("rule", "crest")) == "crest_no_crowd" and crowd_spent_dual > 0.0: continue
		var rec: Dictionary = rewards["houses"].get(h, {})
		rec["witnessed"] = int(rec.get("witnessed", 0)) + 1
		rewards["houses"][h] = rec
		_ev("house_witness", {"house": str(h), "witnessed": int(rec["witnessed"])})

func _house_code_check(move: String) -> void:
	# NP_07A Q-REYES: La Campana against anyone above 40 stamina, in a dual, voids the Reyes blessing - the one revocable blessing
	if not bout.is_empty() or move == "": return
	for h in HOUSES.get("houses", {}):
		var rv: Dictionary = HOUSES["houses"][h].get("revocable", {})
		if rv.is_empty() or str(rv.get("move", "")) != move or float(B.get("stamina", 0.0)) <= float(rv.get("above_stamina", 40)): continue
		var rec: Dictionary = rewards["houses"].get(h, {})
		if bool(rec.get("revoked", false)): continue
		var was := bool(rec.get("blessed", false))
		rec["revoked"] = true; rec["code"] = str(rv.get("flag", "")); rec["revoked_day"] = int(rewards.get("day", 1))
		rewards["houses"][h] = rec
		P["house_status"] = house_status(pname())
		_ev("blessing_revoked", {"house": str(h), "move": move, "stamina": snappedf(float(B["stamina"]), 0.1), "was_blessed": was, "code": str(rv.get("flag", ""))})
		_say("BLESSING VOID :: %s thrown at %s with %.0f stamina left - House %s's %s broken%s" % [move, boss_name, float(B["stamina"]), str(HOUSES["houses"][h]["name"]), str(rv.get("flag", "")), "" if was else " before the blessing (it can no longer land)"])

func equip(nm: String, move: String) -> Dictionary:
	# a card equips one of his house's natives once they are unlocked (NATIVE), or his own signature move back - between duals
	var c := _stable_card(nm)
	var why := ""
	if c.is_empty(): why = "%s is not in the stable" % nm
	elif mode != "OVER": why = "between duals only"
	elif not library.has(move): why = "%s is not in the library" % move
	elif str(c.get("hissatsu", "")) == move: why = "%s already carries %s" % [nm, move]
	elif move != str(c.get("signature", c.get("hissatsu", ""))):
		var h := house_key(str(c.get("house", "none")))
		if move_house(move) == "" or move_house(move) != h: why = "%s is not a House %s move - a card equips its own house's natives as its move (the rest of the library goes in the kit, NP_11 s8)" % [move, h.capitalize()]
		elif bool(library[move].get("secret", false)): why = "%s is House %s's SECRET - its gate event gives it, not the blessing" % [move, h.capitalize()]
		elif house_status(nm) != "NATIVE": why = "%s is UNSANCTIONED - House %s has not blessed the club, the natives stay locked" % [nm, h.capitalize()]
	if why != "": _ev("equip_refused", {"card": nm, "move": move, "why": why}); return {"ok": false, "why": why}
	var sig := str(c.get("signature", c.get("hissatsu", "")))
	for arr in [stable, dressed, lineup, reserves]:
		for cc in arr:
			if cc is Dictionary and str(cc.get("name", "")) == nm:
				cc["signature"] = sig; cc["hissatsu"] = move
	_ev("equipped", {"card": nm, "move": move, "signature": sig})
	_say("%s equips %s%s" % [nm, move, " (his signature back)" if move == sig else " - a House native"])
	return {"ok": true, "why": "", "move": move}

func house_codex() -> Dictionary:
	# NP_11 s9 SaveGame.house_codex (NP_08 s8: fills as houses are encountered): a house whose crest is up on the wall, whose member is in the
	# stable, or that has blessed (or voided) - its line clause by clause, its state, the witness count, its members and their status, its natives
	var out := {}
	for h in HOUSES.get("houses", {}):
		var hd: Dictionary = HOUSES["houses"][h]
		var hn := sw_house_node(str(h))
		var members: Array = []
		for c in stable:
			if house_key(str(c.get("house", "none"))) == str(h): members.append({"card": str(c["name"]), "status": house_status(str(c["name"]))})
		var rec: Dictionary = rewards["houses"].get(h, {})
		if not ((hn != "" and sw_state(hn) != "") or members.size() > 0 or rec.size() > 0): continue
		var e := {"name": str(hd["name"]), "root": str(hd.get("root", "")), "trait": str(hd.get("trait", "")), "authority": str(hd.get("authority", "")),
			"state": house_state(str(h)), "blessing": str(hd["blessing"]) if hd.get("blessing") != null else "",
			"clauses": house_clauses(str(h)).map(func(x): return "%s %d/%d%s" % [str(x["text"]), int(x["have"]), int(x["need"]), " ok" if bool(x["met"]) else ""]),
			"witnessed": int(rec.get("witnessed", 0)), "members": members, "natives": house_natives(str(h))}
		var trd := trait_of_house(str(h))                                                                   # PAC-078: the trait its blood carries, or why none runs
		e["trait_live"] = trd.size() > 0
		if trd.is_empty() and hd.get("trait_id") != null: e["trait_note"] = str(HOUSES.get("traits", {}).get(str(hd["trait_id"]), {}).get("text", ""))
		if rec.has("day"): e["day"] = int(rec["day"]); e["how"] = str(rec.get("how", ""))
		if bool(rec.get("revoked", false)): e["revoked"] = {"code": str(rec.get("code", "")), "day": int(rec.get("revoked_day", 0))}
		out[str(h)] = e
	return out

func graph_view() -> Dictionary:
	# NP_11 s9 SaveGame.feud_graph_state: the graph as it stands - every edge's relation, which the questlines flipped, refused or added
	var edges: Array = []
	for e in live_edges():
		var eid := str(e.get("id", ""))
		var ev := {"id": eid, "a": str(e["a"]), "b": str(e["b"]), "relation": edge_relation(e)}
		var m: Dictionary = rewards["graph"].get(eid, {})
		if m.has("to"): ev["was"] = str(m["from"]); ev["day"] = int(m["day"])
		if m.has("refused"): ev["refused"] = true
		if m.has("added"): ev["added"] = int(m["day"])
		edges.append(ev)
	return {"edges": FEUDS.size(), "graph": edges, "mutations": rewards["graph"].size()}

func house_lines() -> Array:
	# the houses for the HUD and the demo's log: one line per house in the codex, then the graph's flips
	var out: Array = []
	var cx := house_codex()
	for h in cx:
		var e: Dictionary = cx[h]
		var mem: Array = e["members"].map(func(m): return "%s %s" % [str(m["card"]), str(m["status"])])
		out.append("%s [%s]%s%s" % [str(e["name"]).to_upper(), str(e["state"]), (" " + " AND ".join(PackedStringArray(e["clauses"]))) if str(e["state"]) == "unblessed" else "", ("  | " + ", ".join(PackedStringArray(mem))) if mem.size() > 0 else ""])
	var flips: Array = []
	for g in graph_view()["graph"]:
		if g.has("was"): flips.append("%s %s-%s %s -> %s" % [str(g["id"]), str(g["a"]).capitalize(), str(g["b"]).capitalize(), str(g["was"]), str(g["relation"])])
		elif g.has("added"): flips.append("%s %s-%s added %s" % [str(g["id"]), str(g["a"]).capitalize(), str(g["b"]).capitalize(), str(g["relation"])])
		elif g.has("refused"): flips.append("%s %s-%s refused, stays %s" % [str(g["id"]), str(g["a"]).capitalize(), str(g["b"]).capitalize(), str(g["relation"])])
	if flips.size() > 0: out.append("GRAPH: " + ", ".join(PackedStringArray(flips)))
	return out

# ============================ THE GYM WALL (NP_08 s7) ========================
# The bond board: every stablemate's card pinned to a cell of the wall (the club's cards from the cell beside Whitlock's letter; a recruit beside
# the stablemate whose string brought him), the player free to pin any card to any free cell. Proximity is the formation screen's suggestion
# (NP_10 s2): the starters in the order that walks the wall the shortest way, an order a board may seal. Kizuna lines between pinned cards fill
# toward the next level and gild at Sworn; decorations unlock from play and hang anywhere - zero stats. Nothing here is in the state hash.
func _gw_grid() -> Vector2i:
	var g: Dictionary = GYMWALL.get("grid", {})
	var w := int(g.get("w", 8))
	if not FAC.is_empty(): w += int(_fac_at("the_wall", "grid_w_add", 0))                              # PAC-089: The Wall's tier widens the base wall (NP_10 s7's bond board slots)
	return Vector2i(w, int(g.get("h", 4)))

func _gw_init() -> void:
	gym_wall = {}
	if GYMWALL.is_empty(): return
	gym_wall = {"cards": {}, "decos": [], "unpinned": []}
	var lt: Dictionary = GYMWALL.get("letter", {})
	if lt.size() > 0: gym_wall["decos"].append({"id": str(lt["id"]), "kind": "letter", "label": str(lt["label"]), "x": float(lt["x"]), "y": float(lt["y"]), "day": int(rewards.get("day", 1)), "from": str(lt.get("source", ""))})
	for c in stable: _gw_pin_new(str(c["name"]), "")

func _gw_taken(x: int, y: int, but: String = "") -> String:
	for nm in gym_wall.get("cards", {}):
		var p: Array = gym_wall["cards"][nm]
		if int(p[0]) == x and int(p[1]) == y and str(nm) != but: return str(nm)
	return ""

func _gw_pin_new(nm: String, near: String) -> void:
	# a card goes up: beside the card named (the nearest free cell, ties to the scan order), else the next free cell from the one beside the letter
	if gym_wall.is_empty() or gym_wall["cards"].has(nm): return
	var g := _gw_grid()
	var fc: Array = GYMWALL.get("grid", {}).get("first_card_cell", [0, 0])
	var start := int(fc[1]) * g.x + int(fc[0])
	var best := Vector2i(-1, -1); var bd := INF
	var np := Vector2.ZERO
	if near != "" and gym_wall["cards"].has(near): np = Vector2(float(gym_wall["cards"][near][0]), float(gym_wall["cards"][near][1]))
	for i in g.x * g.y:
		var idx := (start + i) % (g.x * g.y)
		var c := Vector2i(idx % g.x, idx / g.x)
		if _gw_taken(c.x, c.y) != "": continue
		if near == "" or not gym_wall["cards"].has(near): best = c; break
		var d := np.distance_to(Vector2(c))
		if d < bd - 0.000001: bd = d; best = c
	if best.x < 0:
		if not (nm in gym_wall["unpinned"]): gym_wall["unpinned"].append(nm)
		_ev("wall_full", {"card": nm}); return
	gym_wall["cards"][nm] = [best.x, best.y]
	gym_wall["unpinned"].erase(nm)
	_ev("card_pinned", {"card": nm, "x": best.x, "y": best.y, "near": near})

func pin(nm: String, x: int, y: int) -> Dictionary:
	# the player's hand: a stablemate's card to a free cell (zero stats - it moves only the suggestion)
	var g := _gw_grid()
	var why := ""
	if gym_wall.is_empty(): why = "no wall"
	elif _stable_card(nm).is_empty(): why = "%s is not in the stable" % nm
	elif x < 0 or y < 0 or x >= g.x or y >= g.y: why = "(%d, %d) is off the wall (%d x %d cells)" % [x, y, g.x, g.y]
	elif _gw_taken(x, y, nm) != "": why = "%s's card is on (%d, %d)" % [_gw_taken(x, y, nm), x, y]
	if why != "": _ev("pin_refused", {"card": nm, "why": why}); return {"ok": false, "why": why}
	gym_wall["cards"][nm] = [x, y]; gym_wall["unpinned"].erase(nm)
	_ev("card_pinned", {"card": nm, "x": x, "y": y, "near": "", "by": "hand"})
	return {"ok": true, "why": ""}

func arrange(deco_id: String, x: float, y: float) -> Dictionary:
	# a decoration anywhere inside the wall (NP_08 s7: "freely arranged")
	var b: Dictionary = GYMWALL.get("bounds", {})
	var why := ""
	var d: Dictionary = {}
	for dd in gym_wall.get("decos", []):
		if str(dd["id"]) == deco_id: d = dd
	if d.is_empty(): why = "no decoration '%s'" % deco_id
	elif x < 0.0 or y < 0.0 or x > maxf(float(b.get("w", 8.0)), float(_gw_grid().x)) or y > float(b.get("h", 6.0)): why = "(%.1f, %.1f) is off the wall" % [x, y]
	if why != "": return {"ok": false, "why": why}
	d["x"] = x; d["y"] = y
	_ev("decoration_moved", {"id": deco_id, "x": x, "y": y})
	return {"ok": true, "why": ""}

func _gw_deco(kind: String, text: String, extra: Dictionary = {}) -> void:
	# an unlock goes up along the foot of the wall, the next place in the band
	if gym_wall.is_empty(): return
	var n := 0
	for dd in gym_wall["decos"]:
		if str(dd["kind"]) == kind: n += 1
	var band: Dictionary = GYMWALL.get("decoration_band", {})
	var k: int = gym_wall["decos"].size() - 1
	var per := int(band.get("per_row", 8))
	var d := {"id": "%s-%d" % [kind, n + 1], "kind": kind, "label": text, "x": float(k % per) + 0.5, "y": minf(float(GYMWALL.get("bounds", {}).get("h", 6.0)) - 0.25, float(band.get("y", 4.5)) + 0.5 * float(k / per)), "day": int(rewards.get("day", 1)), "from": str(GYMWALL.get("decorations", {}).get(kind, {}).get("from", ""))}
	for ek in extra: d[ek] = extra[ek]
	gym_wall["decos"].append(d)
	_ev("decoration_unlocked", {"id": str(d["id"]), "deco": kind, "label": text})                    # (the event's own "kind" is its name)

func _gw_regrid() -> void:
	# The Wall widened: the cards that found no cell go up in the new columns, in the order they waited
	if gym_wall.is_empty(): return
	for nm in gym_wall["unpinned"].duplicate(): _gw_pin_new(str(nm), "")

func _gw_honour(kind: String, key: String, text: String) -> void:
	# the honours set (The Wall's tier, facilities.v1.json): a house's crest, a feat's plaque - once each, zero stats
	if gym_wall.is_empty() or FAC.is_empty(): return
	var st: Dictionary = FAC.get("tracks", {}).get("the_wall", {}).get("sets", {}).get("honours", {})
	if st.is_empty() or fac_tier("the_wall") < int(st.get("tier", 2)): return
	for d in gym_wall["decos"]:
		if str(d.get("honour", "")) == key: return
	_gw_deco(kind, text, {"honour": key})

func _gw_honours() -> void:
	# The Wall reaches the set's tier: every blessing and every feat so far goes up
	var hs: Array = rewards.get("houses", {}).keys(); hs.sort()
	for h in hs:
		if house_blessed(str(h)): _gw_honour("crest", "crest:" + str(h), "House %s's crest" % _house_name(str(h)))
	var fs: Array = rewards.get("feats", {}).keys(); fs.sort()
	for f in fs: _gw_honour("feat", "feat:" + str(f), "%s - %s" % [str(TRANS.get("shared", {}).get("weathering", {}).get(str(f), {}).get("name", f)), str(rewards["feats"][f].get("last", ""))])

func _gw_dual(won: bool) -> void:
	# a fight poster for a dual won; a ticket stub the first time the club is faced
	if gym_wall.is_empty() or bout.size() > 0: return
	var lead := boss_short(str(bdressed[0])) if bdressed.size() > 0 else boss_short(boss_name)
	var club := str(coach.get("club", ""))                                                               # the coach table's club; an unaffiliated squad is its lead's
	if club == "" or club == "unaffiliated": club = "%s's squad" % lead
	if won: _gw_deco("poster", "MILLBROOK vs %s - %s" % [club, lead], {"club": club})
	for dd in gym_wall["decos"]:
		if str(dd["kind"]) == "stub" and str(dd.get("club", "")) == club: return
	_gw_deco("stub", club, {"club": club})

func _gw_card_of_recruit(rn: String) -> String:
	var c := str(_recruit_rec(rn).get("card", ""))
	return c if c != "" and _stable_card(c).size() > 0 else ""

func _perms(arr: Array) -> Array:
	# every order of arr, in the lexicographic order of its positions (the first permutation is arr itself)
	if arr.size() <= 1: return [arr.duplicate()]
	var out: Array = []
	for i in arr.size():
		var rest: Array = arr.duplicate(); rest.remove_at(i)
		for p in _perms(rest): out.append([arr[i]] + p)
	return out

func _gw_dist(a: String, b: String) -> float:
	var cards: Dictionary = gym_wall.get("cards", {})
	if not (cards.has(a) and cards.has(b)): return float(GYMWALL.get("suggestion", {}).get("unpinned_distance", 100.0))
	return Vector2(float(cards[a][0]), float(cards[a][1])).distance_to(Vector2(float(cards[b][0]), float(cards[b][1])))

func _gw_preset(st: Array) -> Dictionary:
	# NP_10 s2's suggestion: the starters' order with the shortest walk along the wall; ties to the card order
	var best: Array = st.duplicate(); var bc := INF
	for p in _perms(st):
		var c := 0.0
		for i in range(1, p.size()): c += _gw_dist(str(p[i - 1]), str(p[i]))
		if c < bc - 0.000001: bc = c; best = p
	var why: Array = []
	for i in best.size():
		why.append("R%d %s - %s" % [i + 1, best[i], "the walk's first card" if i == 0 else "%.1f cells from %s on the wall" % [_gw_dist(str(best[i - 1]), str(best[i])), best[i - 1]]])
	var res: Array = []
	for f in dressed:
		if not (str(f["name"]) in best): res.append(str(f["name"]))
	return {"archetype": "GYM_WALL", "slots": best, "reserves": res, "ace": "", "anchor": "", "why": why, "walk": snappedf(bc, 0.001)}

func gym_wall_suggestion() -> Dictionary:
	return order_preset("GYM_WALL")

func gym_wall_view() -> Dictionary:
	# NP_11 s9 SaveGame.gym_wall {layout, decorations}: the cards where they hang, the lines between them, what hangs around them
	if gym_wall.is_empty(): return {"layout": {}, "decorations": []}
	var g := _gw_grid()
	var cards: Array = []
	for nm in gym_wall["cards"]: cards.append({"name": str(nm), "x": int(gym_wall["cards"][nm][0]), "y": int(gym_wall["cards"][nm][1])})
	var lines: Array = []
	var names: Array = gym_wall["cards"].keys()
	var lv: Array = ECO.get("kizuna", {}).get("levels", [])
	var nm_lv: Array = ECO.get("kizuna", {}).get("names", [])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a := str(names[i]); var b := str(names[j])
			var pts := kizuna_pts(a, b)
			if pts <= 0: continue
			var l := kizuna_level(a, b)
			var lo := 0.0 if l == 0 else float(lv[l - 1])
			var fill := 1.0 if l >= lv.size() else (float(pts) - lo) / maxf(1.0, float(lv[l]) - lo)
			lines.append({"a": a, "b": b, "pts": pts, "level": l, "name": str(nm_lv[l - 1]) if l > 0 and l - 1 < nm_lv.size() else "", "fill": snappedf(fill, 0.01), "gilded": l >= int(GYMWALL.get("lines", {}).get("gild_level", 5))})
	var decos: Array = []
	for d in gym_wall["decos"]: decos.append(d.duplicate())
	return {"layout": {"grid": [g.x, g.y], "cards": cards, "unpinned": gym_wall["unpinned"].duplicate(), "lines": lines}, "decorations": decos}

func gym_wall_restore(v: Dictionary) -> void:
	# a save's wall back: the cards on their cells, the unpinned, the decorations where they hung; a card the save's wall does not hold (a save
	# written before the wall: its bench) goes up as a recruit's would, in the next free cell
	if GYMWALL.is_empty() or gym_wall.is_empty(): return
	if v.has("layout") and v["layout"] is Dictionary and not v["layout"].is_empty():
		gym_wall = {"cards": {}, "decos": [], "unpinned": []}
		for c in v["layout"].get("cards", []): gym_wall["cards"][str(c["name"])] = [int(c["x"]), int(c["y"])]
		for u in v["layout"].get("unpinned", []): gym_wall["unpinned"].append(str(u))
		for d in v.get("decorations", []):
			var dd: Dictionary = d.duplicate(); dd["x"] = float(d["x"]); dd["y"] = float(d["y"]); dd["day"] = int(d.get("day", 1))
			if dd.has("level"): dd["level"] = int(dd["level"])                                           # JSON's numbers are floats; a polaroid's level is a count
			gym_wall["decos"].append(dd)
	for c in stable:
		if not (str(c["name"]) in gym_wall["unpinned"]): _gw_pin_new(str(c["name"]), "")

func gym_wall_lines() -> Array:
	# the wall for the HUD and the demo's log: its rows of cards, its lines, what hangs on it
	var out: Array = []
	if gym_wall.is_empty(): return out
	var v := gym_wall_view(); var g := _gw_grid()
	for y in g.y:
		var row: Array = []; var any := false
		for x in g.x:
			var t := _gw_taken(x, y)
			if t != "": any = true
			row.append((t if t != "" else ".").left(7).rpad(7))
		if any: out.append("ROW %d  %s" % [y, " ".join(PackedStringArray(row)).strip_edges(false, true)])
	if v["layout"]["lines"].size() > 0:
		out.append("LINES: " + ", ".join(PackedStringArray(v["layout"]["lines"].map(func(l): return "%s-%s %s%s" % [str(l["a"]), str(l["b"]), (str(l["name"]) + " ") if str(l["name"]) != "" else "", "GILDED" if bool(l["gilded"]) else "%d%%" % int(round(float(l["fill"]) * 100.0))]))))
	if v["layout"]["unpinned"].size() > 0: out.append("IN THE LOCKER (no cell free): " + ", ".join(PackedStringArray(v["layout"]["unpinned"])))
	out.append("ON THE WALL (%d): %s" % [v["decorations"].size(), ", ".join(PackedStringArray(v["decorations"].map(func(d): return str(d["label"]))))])
	return out

# ============================ CLUB FACILITIES (NP_10 s7) =====================
# The gym progression tree (PAC-089): five tracks, each T1 -> T3; the club starts every one at T0, the Old Gym as found. A tier is a
# renovation between duals, paid from the reward ledger (HBP and Spirits) behind its story gate, and it goes up on the Gym Wall as a
# photograph. A track's effects arrive in the order NP_10 s7's table lists them, one a tier (facilities.v1.json):
#   Bags & Mitts   - the training slots (NP_11 s7, 3 a day): Roadwork and the harbour's Net Haul from T0, Mitts and the Heavy Bag at T1,
#                    the Slip Bag at T2, Shadow Rounds at T3; the Beans x1.25 / x1.5 at T2 / T3. The Forge's Beans are earned here.
#   The Ring       - the spar's lab flags at T1; the Exhibition 2v2 hosted at home at T2; the ranked spar board at T3.
#   Film Room      - the Scout Book's shelf (6 pages as found, then 12 / 24 / 48): a page past it waits, and its PI 3 with it; the grind's
#                    rungs sooner at T2; at T3 the tape reads a decoy seal from a corner that has run one on the club before.
#   The Wall       - the Gym Wall's card columns (the base wall's 8, +2 at T1, +4 from T2); the honours set at T2 (a house's crest, a
#                    feat's plaque); the Forge at T3.
#   Front of House - the entrance at every dual's bell (a sting, a banner, the chant; the Reyes bell by its quest); a hosted dual's crowd
#                    starting at 20 from T2; 5 Prestige from a hosted dual at T3.
# The ledger keeps the tiers (rewards["facilities"]), the training day (rewards["training"]) and the tape (rewards["tape"]); the PI ledger
# keeps the Scout Book's shelf (pi["book"] and pi["waiting"], in the order the pages were earned).
func fac_tier(track: String) -> int:
	return int(rewards.get("facilities", {}).get(track, int(FAC.get("start_tier", 0))))

func facility_tiers() -> Dictionary:
	# NP_11 s9 Club.facility_tiers{} - every track at its tier, in the table's order
	var out := {}
	for t in FAC.get("order", []): out[str(t)] = fac_tier(str(t))
	return out

func fac_track(key: String) -> String:
	# a track by its id, its alias, or its number on the screen (1-5); "" for none
	var order: Array = FAC.get("order", [])
	if key.is_valid_int() and int(key) >= 1 and int(key) <= order.size(): return str(order[int(key) - 1])
	for t in order:
		if str(t) == key or str(FAC["tracks"][t].get("alias", "")) == key: return str(t)
	return ""

func _fac_label(track: String) -> String: return str(FAC.get("tracks", {}).get(track, {}).get("label", track))

func _fac_at(track: String, key: String, dflt):
	# a per-tier value of the track, read at its tier
	var arr = FAC.get("tracks", {}).get(track, {}).get(key, null)
	if not (arr is Array) or arr.is_empty(): return dflt
	return arr[clampi(fac_tier(track), 0, arr.size() - 1)]

func fac_open(track: String, key: String) -> bool:
	# a gate the track's tier opens (a build without the table keeps every gate open, as before it existed)
	if FAC.is_empty(): return true
	return fac_tier(track) >= int(FAC.get("tracks", {}).get(track, {}).get(key, 0))

func fac_has(track: String, key: String) -> bool:
	# a bonus the track's tier pays (none without the table)
	return not FAC.is_empty() and fac_tier(track) >= int(FAC.get("tracks", {}).get(track, {}).get(key, 1 << 20))

static func seed_facilities(ledger: Dictionary, s_arg: String, fac_d: Dictionary) -> Dictionary:
	# `-- facility=bags:1,ring:2,film:3,wall:3,foh:3` -> the tiers the renovations would have built (a track by id, alias or number)
	var out := ledger.duplicate(true)
	var order: Array = fac_d.get("order", [])
	for part in s_arg.split(",", false):
		var kv := str(part).strip_edges().split(":")
		if kv.size() != 2 or not str(kv[1]).is_valid_int(): continue
		var key := str(kv[0]); var tr := ""
		if key.is_valid_int() and int(key) >= 1 and int(key) <= order.size(): tr = str(order[int(key) - 1])
		for t in order:
			if str(t) == key or str(fac_d["tracks"][t].get("alias", "")) == key: tr = str(t)
		if tr == "": continue
		if not out.has("facilities"): out["facilities"] = {}
		out["facilities"][tr] = clampi(int(kv[1]), 0, int(fac_d.get("max_tier", 3)))
	return out

func renovate_why(track: String) -> String:
	# why this track cannot take its next tier now ("" when it can): between duals, the top, the story's gate, the price
	if FAC.is_empty(): return "no facilities in this build"
	if track == "" or not FAC.get("tracks", {}).has(track): return "no facility '%s'" % track
	if mode != "OVER" and bell_rung(): return "the renovations are between duals"
	var t := fac_tier(track)
	if t >= int(FAC.get("max_tier", 3)): return "%s is at T%d, the top" % [_fac_label(track), t]
	var nt: Dictionary = FAC.get("tiers", {}).get(str(t + 1), {})
	var flag := str(nt.get("story", ""))
	if flag != "" and not _story_set(flag): return "%s T%d waits on the story - %s (%s)" % [_fac_label(track), t + 1, str(nt.get("story_text", flag)), flag]
	var hb := int(nt.get("hbp", 0)); var sp := int(nt.get("spirits", 0))
	if int(rewards.get("hbp", 0)) < hb or int(rewards.get("spirits", 0)) < sp:
		return "%s T%d costs %d HBP and %d Spirits (the ledger holds %d and %d)" % [_fac_label(track), t + 1, hb, sp, int(rewards.get("hbp", 0)), int(rewards.get("spirits", 0))]
	return ""

func renovate_ready() -> String:
	# the first track the ledger and the story let take its next tier, in the table's order ("" for none)
	for t in FAC.get("order", []):
		if renovate_why(str(t)) == "": return str(t)
	return ""

func renovate(key: String) -> Dictionary:
	# between duals: a track's next tier ("*": the first ready); the ledger pays, the photograph goes up, the tier's effects land
	if key == "*":
		var rd := renovate_ready()
		if rd != "": return renovate(rd)
		var first := ""
		for t in FAC.get("order", []):
			if first == "": first = renovate_why(str(t))
		var w0 := "no renovation is ready%s" % ((" - " + first) if first != "" else "")
		_ev("renovate_refused", {"track": "*", "why": w0}); _say("THE OLD GYM - %s" % w0)
		return {"ok": false, "why": w0}
	var track := fac_track(key)
	var why := renovate_why(track if track != "" else key)
	if why != "":
		_ev("renovate_refused", {"track": key, "why": why}); _say("THE OLD GYM - %s" % why)
		return {"ok": false, "why": why}
	var t := fac_tier(track) + 1
	var nt: Dictionary = FAC["tiers"][str(t)]
	rewards["hbp"] = int(rewards.get("hbp", 0)) - int(nt.get("hbp", 0)); rewards["spirits"] = int(rewards.get("spirits", 0)) - int(nt.get("spirits", 0))
	if not rewards.has("facilities"): rewards["facilities"] = {}
	rewards["facilities"][track] = t
	var fx := str(FAC["tracks"][track].get("effects", {}).get(str(t), ""))
	_ev("renovated", {"track": track, "label": _fac_label(track), "tier": t, "hbp": int(nt.get("hbp", 0)), "spirits": int(nt.get("spirits", 0)), "effect": fx})
	_say("THE OLD GYM :: %s T%d - %s (%d HBP, %d Spirits; the ledger %d HBP / %d Spirits)" % [_fac_label(track).to_upper(), t, fx, int(nt.get("hbp", 0)), int(nt.get("spirits", 0)), int(rewards["hbp"]), int(rewards["spirits"])])
	_gw_deco("renovation", "%s T%d - %s" % [_fac_label(track), t, fx], {"track": track, "tier": t})
	if track == "film_room": _book_fill()
	if track == "the_wall":
		_gw_regrid()
		_gw_honours()
	return {"ok": true, "why": "", "track": track, "tier": t}

func facility_lines() -> Array:
	# the Old Gym between duals: each track at its tier, its next tier's effect and price or what it waits on; the training slots; the shelf
	var out: Array = []
	if FAC.is_empty(): return out
	var i := 0
	for t in FAC.get("order", []):
		i += 1
		var tr := str(t); var tt := fac_tier(tr)
		if tt >= int(FAC.get("max_tier", 3)): out.append("[%d] %s T%d - the top (%s)" % [i, _fac_label(tr), tt, str(FAC["tracks"][tr].get("effects", {}).get(str(tt), ""))]); continue
		var nt: Dictionary = FAC["tiers"][str(tt + 1)]
		var w := renovate_why(tr)
		out.append("[%d] %s T%d -> T%d (%s): %s" % [i, _fac_label(tr), tt, tt + 1, str(FAC["tracks"][tr].get("effects", {}).get(str(tt + 1), "")), "%d HBP, %d Spirits" % [int(nt.get("hbp", 0)), int(nt.get("spirits", 0))] if w == "" else w])
	out.append(training_line())
	out.append("Scout Book %d of %d pages%s" % [pi.get("book", []).size(), book_pages(), (" (%d waiting for the Film Room)" % pi.get("waiting", []).size()) if pi.get("waiting", []).size() > 0 else ""])
	return out

# ---- Bags & Mitts: the training slots (NP_11 s7) ----
func _training() -> Dictionary: return FAC.get("tracks", {}).get("bags_mitts", {}).get("training", {})

func training_used() -> int:
	var tr: Dictionary = rewards.get("training", {})
	return int(tr.get("used", 0)) if int(tr.get("day", 0)) == int(rewards.get("day", 1)) else 0

func training_mult() -> float:
	var ym: Array = _training().get("yield_mult", [1.0])
	return float(ym[clampi(fac_tier("bags_mitts"), 0, ym.size() - 1)])

func train_why(game: String, who: String, partner: String = "") -> String:
	# why this slot cannot run now ("" when it can): between duals, the minigame, the card, the gym's tier, its flag, a page, the partner, the day
	if FAC.is_empty() or _training().is_empty(): return "no training in this build"
	var between := _between("training is")
	if between != "": return between
	var g: Dictionary = _training().get("games", {}).get(game, {})
	if g.is_empty(): return "no minigame '%s'" % game
	if _club_card(who).is_empty(): return "%s is not in the club" % who
	var need := int(g.get("tier", 0))
	if fac_tier("bags_mitts") < need: return "%s needs Bags & Mitts T%d (the gym's is T%d)" % [str(g["label"]), need, fac_tier("bags_mitts")]
	var fl := str(g.get("flag", ""))
	if fl != "" and not _story_set(fl): return "%s opens with %s" % [str(g["label"]), fl]
	if bool(g.get("needs_page", false)) and pi.get("book", []).is_empty(): return "%s needs a pattern in the Scout Book" % str(g["label"])
	if partner != "":
		if _club_card(partner).is_empty(): return "%s is not in the club" % partner
		if partner == who: return "%s cannot train beside himself" % who
	var slots := int(_training().get("slots_per_day", 3))
	if training_used() >= slots: return "the day's %d training slots are used (day %d)" % [slots, int(rewards.get("day", 1))]
	return ""

func training_best(who: String) -> String:
	# the aid's pick: the highest-tier minigame open to him now (ties to the table's order)
	var best := ""; var bt := -1
	for gid in _training().get("games", {}):
		var g: Dictionary = _training()["games"][gid]
		if train_why(str(gid), who) == "" and int(g.get("tier", 0)) > bt: bt = int(g.get("tier", 0)); best = str(gid)
	return best

func train(game: String, who: String, grade: float, partner: String = "", vs: String = "") -> Dictionary:
	# one training slot between duals: the minigame's grade (its own result, 0-1) pays Beans into the jar at the gym's yield; Roadwork with
	# a squad member along bonds; Shadow Rounds names the Scout Book pattern it ghosts. ("*" for either: the club's first card, his best game)
	if who == "*": who = str(stable[0]["name"]) if stable.size() > 0 else ""
	if game == "*": game = training_best(who)
	var why := train_why(game, who, partner)
	if why != "":
		_ev("training_refused", {"game": game, "who": who, "why": why}); _say("TRAINING - %s" % why)
		return {"ok": false, "why": why}
	var g: Dictionary = _training()["games"][game]
	var lh: Array = g.get("beans", [0, 0])
	var gr := clampf(grade, 0.0, 1.0)
	var base := int(lh[0]) + int(round(gr * float(int(lh[1]) - int(lh[0]))))
	var beans := int(round(float(base) * training_mult()))
	rewards["beans"] = int(rewards.get("beans", 0)) + beans
	var auto_p := false
	if partner == "":                                                                                    # PAC-099: NP_08 s1 - no partner named, the club's training partner with the most to add goes along
		partner = partner_pick(game, who); auto_p = partner != ""
	var typed := _beans_type(str(g.get("bias", "any")), beans, partner)                                 # PAC-090: NP_11 s7 - the game's bias, the partner's flavour
	var pb: Array = partner_bonus(game, who, partner)
	if int(pb[0]) > 0:                                                                                   # PAC-099: the training partner's bonus, typed as the stat he leads by
		rewards["beans"] = int(rewards["beans"]) + int(pb[0]); beans += int(pb[0])
		typed[str(pb[1])] = int(typed.get(str(pb[1]), 0)) + int(pb[0])
		if not rewards.has("bean_types"): rewards["bean_types"] = {}
		rewards["bean_types"][str(pb[1])] = int(rewards["bean_types"].get(str(pb[1]), 0)) + int(pb[0])
		_rq()["paid"]["beans"] = int(_rq()["paid"]["beans"]) + int(pb[0])
	var used := training_used() + 1
	rewards["training"] = {"day": int(rewards.get("day", 1)), "used": used}
	var kz := 0
	if partner != "" and int(g.get("partner_kizuna", 0)) > 0: kz = _pay_kizuna(who, partner, int(g["partner_kizuna"]), true, str(game))
	var pat := ""
	if bool(g.get("needs_page", false)):
		var book: Array = pi.get("book", [])
		pat = vs if vs in book else str(book[0])
	var slots := int(_training().get("slots_per_day", 3))
	_ev("training", {"game": game, "label": str(g["label"]), "who": who, "grade": gr, "beans": beans, "base": base, "mult": training_mult(), "bias": str(g.get("bias", "")), "partner": partner, "kizuna": kz, "pattern": pat, "slot": used, "of": slots, "jar": int(rewards["beans"]), "typed": typed, "bonus": int(pb[0]), "bonus_stat": str(pb[1]), "auto_partner": auto_p})
	_say("TRAINING :: %s - %s, grade %.2f: %d Beans%s%s%s%s (slot %d of %d; the jar %d)%s" % [who, str(g["label"]), gr, beans, (" (x%.2f, Bags & Mitts T%d)" % [training_mult(), fac_tier("bags_mitts")]) if training_mult() != 1.0 else "", (", %s along +%d Kizuna" % [partner, kz]) if kz > 0 else "", (", %s the training partner +%d %s" % [partner, int(pb[0]), str(pb[1])]) if int(pb[0]) > 0 else "", (" - against %s's ghost" % pat) if pat != "" else "", used, slots, int(rewards["beans"]), (" - " + _beans_text(typed, beans)) if not GROW.is_empty() else ""])
	return {"ok": true, "why": "", "beans": beans, "game": game, "who": who, "partner": partner, "bonus": int(pb[0])}

func training_line() -> String:
	if FAC.is_empty() or _training().is_empty(): return ""
	var open: Array = []
	for gid in _training().get("games", {}):
		var g: Dictionary = _training()["games"][gid]
		if int(g.get("tier", 0)) <= fac_tier("bags_mitts") and (str(g.get("flag", "")) == "" or _story_set(str(g.get("flag", "")))) and not (bool(g.get("needs_page", false)) and pi.get("book", []).is_empty()): open.append(str(g["label"]))
	return "TRAINING [T] %d of %d slots used today (day %d): %s open, Beans x%.2f (the jar %d)" % [training_used(), int(_training().get("slots_per_day", 3)), int(rewards.get("day", 1)), ", ".join(PackedStringArray(open)) if open.size() > 0 else "nothing", training_mult(), int(rewards.get("beans", 0))]

# ---- Film Room: the Scout Book's shelf, the grind, the tape ----
func book_pages() -> int: return int(_fac_at("film_room", "book_pages", 1 << 20)) if not FAC.is_empty() else (1 << 20)

static func page_key(name: String, rid: String = "") -> String: return name if rid == "" else "%s#%s" % [name, rid]

func shelved(key: String) -> bool:
	# a page on the Scout Book's shelf (every page, without the table)
	return FAC.is_empty() or key in pi.get("book", [])

func _book_init() -> void:
	# a ledger from before the shelf (a seeded or an older one): its pages shelved in the ledger's order, as many as the shelf holds
	if FAC.is_empty() or pi.has("book"): return
	var keys: Array = []
	for nm in pi.get("bosses", {}):
		var rec: Dictionary = pi["bosses"][nm]
		if int(rec.get("beaten", 0)) > 0: keys.append(str(nm))
		for rid in rec.get("remixes", {}):
			if int(rec["remixes"][rid]) > 0: keys.append(page_key(str(nm), str(rid)))
	if keys.is_empty(): return
	pi["book"] = []; pi["waiting"] = []
	for k in keys:
		if pi["book"].size() < book_pages(): pi["book"].append(k)
		else: pi["waiting"].append(k)

func _shelve(key: String) -> bool:
	# a page earned: onto the shelf if it has room, else it waits for the Film Room's next tier (and its PI 3 with it)
	if FAC.is_empty(): return true
	if not pi.has("book"): pi["book"] = []; pi["waiting"] = []
	if key in pi["book"]: return true
	if pi["book"].size() < book_pages():
		pi["book"].append(key); pi["waiting"].erase(key); return true
	if not (key in pi["waiting"]): pi["waiting"].append(key)
	_ev("page_waiting", {"page": key, "shelf": book_pages(), "tier": fac_tier("film_room")})
	_say("SCOUT BOOK FULL - %s's page waits for the Film Room (%d pages at T%d)" % [key.replace("#", " "), book_pages(), fac_tier("film_room")])
	return false

func _book_fill() -> void:
	# the Film Room renovated: the waiting pages go up, in the order they were earned
	if not pi.has("waiting"): return
	while pi["waiting"].size() > 0 and pi["book"].size() < book_pages():
		var k := str(pi["waiting"].pop_front()); pi["book"].append(k)
		_ev("page_shelved", {"page": k, "shelf": book_pages()})
		_say("SCOUT BOOK :: %s's page goes on the shelf (%d of %d)" % [k.replace("#", " "), pi["book"].size(), book_pages()])

func _pi_rungs() -> Dictionary:
	# the rungs the dialect track climbs: the table's, the grind's sooner from the Film Room's tier (scraps and spars; a dual segment as ever)
	var r: Dictionary = PI.get("rungs", {})
	if not fac_has("film_room", "grind_tier"): return r
	var out := r.duplicate(true)
	var g: Dictionary = FAC["tracks"]["film_room"].get("grind_rungs", {})
	for src in g: out[src] = g[src]
	return out

func tape_read() -> bool:
	# the Film Room's decoy assist: a corner that has run a decoy seal on the club before is read on sight (the tape of the last time)
	if not fac_has("film_room", "tape_tier") or coach.is_empty(): return false
	return int(rewards.get("tape", {}).get(str(coach.get("id", "")), 0)) > 0

func _tape_record() -> void:
	# a dual ended against a decoy seal: the tape keeps it (the Film Room reads it from its tier on)
	if not bdecoy or coach.is_empty() or FAC.is_empty(): return
	if not rewards.has("tape"): rewards["tape"] = {}
	var cid := str(coach.get("id", ""))
	rewards["tape"][cid] = int(rewards["tape"].get(cid, 0)) + 1
	_ev("tape", {"coach": cid, "label": str(coach.get("label", cid)), "decoys": int(rewards["tape"][cid])})

# ---- Front of House: the entrance, the hosted crowd, the hosted Prestige ----
func entrance_set() -> Array:
	# the club's entrance at a dual's bell (NP_01 s9): the tier's pieces, the Reyes bell with its quest
	if FAC.is_empty(): return []
	var st: Array = _fac_at("front_of_house", "entrance", []).duplicate()
	var bf := str(FAC.get("tracks", {}).get("front_of_house", {}).get("bell_flag", ""))
	if bf != "" and _story_set(bf): st.append(str(FAC["tracks"]["front_of_house"].get("bell", "the bell")))
	return st

func _entrance() -> void:
	var st := entrance_set()
	if st.is_empty() or exhibit == "B": return                                                          # one walk-out a club (the exhibition's pair A carries it)
	_ev("entrance", {"set": st, "tier": fac_tier("front_of_house"), "host": host})
	_say("THE ENTRANCE :: MILLBROOK walks out - %s%s" % [", ".join(PackedStringArray(st)), " (at home)" if host else ""])

func _host_crowd() -> void:
	# a hosted dual's crowd from the bell (Front of House's tier); away, the building is theirs
	if not host or bout.size() > 0 or STAFF.is_empty() or not fac_has("front_of_house", "crowd_tier"): return
	crowd_heat = float(FAC["tracks"]["front_of_house"].get("crowd_base", 0))
	_ev("crowd", {"heat": crowd_heat, "base": true})

func set_host(on: bool) -> Dictionary:
	# between duals (or before the bell): the next dual at the club's gym, or away
	if mode != "OVER" and bell_rung(): return {"ok": false, "why": "the venue is set between duals"}
	host = on
	if mode != "OVER":
		crowd_heat = 0.0
		_host_crowd()
	_ev("venue", {"host": host}); _say("VENUE :: the next dual is %s" % ("at the club's gym (hosted)" if host else "away"))
	return {"ok": true, "why": ""}

# ============================ THE FIGHTER'S GROWTH (NP_11 s1, s3, s4, s6, s7) =====
# Between duals a fighter grows three ways, and the ledger keeps each (rewards["growth"][name]; growth.v1.json):
#   the ability board - his style's hex layout (60 nodes: the Body lobe's stat nodes and soft-cap breakers, the Craft lobe's passives, the
#     Spirit lobe's Tension passives, the spine and - a Boxer-Puncher's - the off-style socket) and his own 2 named nodes. A node is taken
#     when it touches one already taken (the stance at the root is free), paid in Board Points (2 a level); a stat node on a stat at 70+
#     costs double until that stat's breaker is taken, and one at his rarity's cap is the way through, adding nothing past it. Respec is
#     free at the gym from the Film Room's T2.
#   the stat raises - +1 for 5 Beans, +1 Bean for each raise already bought on that stat; the stat's own typed Beans pay first, then the
#     untyped (the training slots type theirs by the game's bias; a partner along flavours a quarter with his best stat).
#   rarity - Club / Circuit / National / Legend: the cap his growth reaches (70 / 80 / 90 / 99; a card's own stats stand as dressed), up a
#     tier on Spirits (10 / 25 / 60) and a trial he must do (a spar won; a transform weathered; his mirror beaten), an accessory slot a
#     tier, and at the Legend's tier a generic's Awakening flag (a story character carries his from the start).
# At the bell the fighter walks out on his grown stats with his passives on him (P["passives"]); nothing moves during a dual.
func _pas(F: Dictionary, pid: String) -> bool:
	return F.has("passives") and pid in F["passives"]

func _pv(pid: String, key: String, dflt):
	return GROW.get("passives", {}).get(pid, {}).get(key, dflt)

func _grow(name: String) -> Dictionary:
	return rewards.get("growth", {}).get(name, {})

func _grow_w(name: String) -> Dictionary:
	if not rewards.has("growth"): rewards["growth"] = {}
	if not rewards["growth"].has(name):
		rewards["growth"][name] = {"board": [], "spent": 0, "socket": "", "raises": {}, "rarity": clampi(int(_club_card(name).get("rarity", 1)), 1, 4), "trials": {}}
	return rewards["growth"][name]

func rarity_of(name: String) -> int:
	return clampi(int(_grow(name).get("rarity", _club_card(name).get("rarity", 1))), 1, 4)

func rarity_name(t: int) -> String:
	var nm: Array = GROW.get("rarity", {}).get("names", ["Club", "Circuit", "National", "Legend"])
	return str(nm[clampi(t, 1, nm.size()) - 1])

func rarity_cap(name: String) -> int:
	var caps: Array = GROW.get("rarity", {}).get("caps", [99])
	return int(caps[clampi(rarity_of(name), 1, caps.size()) - 1])

func accessory_slots(name: String) -> int:
	var sl: Array = GROW.get("rarity", {}).get("accessory_slots", [0])
	return int(sl[clampi(rarity_of(name), 1, sl.size()) - 1])

func awaken_eligible(name: String) -> bool:
	# NP_11 s4: the Legend's tier unlocks the Awakening flag - story characters pre-flagged, a generic earns it
	if GROW.is_empty(): return true
	var c := _club_card(name)
	if not bool(c.get("generic", false)): return true
	return rarity_of(name) >= int(GROW.get("rarity", {}).get("awakening_tier", 4))

func growth_layout(name: String) -> String:
	return style_key(str(_club_card(name).get("style", "BOXERPUNCHER")))

func _named_nodes(card: Dictionary) -> Array:
	# NP_11 s3: 2-4 nodes injected per named character - his authored ones, else the rule's (+3 on his two best stats); none for a generic
	var nm := str(card.get("name", ""))
	if bool(card.get("generic", false)) or nm == "": return []
	if GROW.get("named", {}).has(nm): return GROW["named"][nm]
	var rule: Dictionary = GROW.get("named_rule", {})
	var st: Dictionary = card.get("stats", {})
	var order: Array = GROW.get("stats", [])
	var ranked: Array = order.filter(func(k): return st.has(k))
	ranked.sort_custom(func(a, b): return int(st[a]) > int(st[b]) or (int(st[a]) == int(st[b]) and order.find(a) < order.find(b)))
	var out: Array = []
	var links: Array = rule.get("links", ["sp3", "sp5"])
	for i in mini(int(rule.get("count", 2)), ranked.size()):
		var v := int(rule.get("v", 3))
		out.append({"id": "n%d" % (i + 1), "lobe": "spine", "kind": "stat", "stat": str(ranked[i]), "v": v, "cost": int(GROW.get("costs", {}).get("stat", {}).get(str(v), 2)), "label": "%s's own %s" % [nm, str(ranked[i])], "links": [str(links[i % links.size()])]})
	return out

func growth_nodes(name: String) -> Dictionary:
	# his board: the style's layout, his named nodes joined to the spine (links both ways)
	var out := {}
	var lay: Dictionary = GROW.get("layouts", {}).get(growth_layout(name), {})
	for n in lay.get("nodes", []): out[str(n["id"])] = n.duplicate(true)
	for n in _named_nodes(_club_card(name)):
		var nn: Dictionary = n.duplicate(true)
		out[str(nn["id"])] = nn
		for l in nn["links"]:
			if out.has(str(l)): out[str(l)]["links"].append(str(nn["id"]))
	return out

func gpoints(name: String) -> int: return int(GROW.get("points_per_level", 2)) * level_of(name)

func gpoints_free(name: String) -> int: return gpoints(name) - int(_grow(name).get("spent", 0))

func taken(name: String) -> Array:
	var out: Array = ["root"]
	out.append_array(_grow(name).get("board", []))
	return out

func _stat_growth(name: String) -> Dictionary:
	# what his raises and his stat nodes add, stat by stat
	var add := {}
	var g := _grow(name)
	for k in g.get("raises", {}): add[str(k)] = int(add.get(str(k), 0)) + int(g["raises"][k])
	if g.get("board", []).size() > 0:
		var nodes := growth_nodes(name)
		for id in g["board"]:
			var n: Dictionary = nodes.get(str(id), {})
			if str(n.get("kind", "")) == "stat": add[str(n["stat"])] = int(add.get(str(n["stat"]), 0)) + int(n["v"])
	return add

func grown_stats(card: Dictionary) -> Dictionary:
	# the card's stats with his growth on them, to his rarity's cap (a stat the card already holds above it stands); the card's own dict when none
	var nm := str(card.get("name", ""))
	if GROW.is_empty() or not rewards.get("growth", {}).has(nm): return card.get("stats", {})
	var st: Dictionary = rarity_base(nm, card.get("stats", {}))                                        # PAC-096: the tier's total under the growth
	var add := _stat_growth(nm)
	if add.is_empty(): return st
	var cap := rarity_cap(nm)
	var out := st.duplicate()
	for k in add:
		if out.has(k): out[k] = maxi(int(out[k]), mini(cap, int(out[k]) + int(add[k])))
	return out

func rarity_total(name: String) -> int:
	# PAC-096: NP_11 s1's "stat totals by rarity keep early recruits viable" - the least a card at his tier totals (0: none)
	return int(GROW.get("rarity", {}).get("totals", {}).get(str(rarity_of(name)), 0))

func rarity_base(name: String, st: Dictionary) -> Dictionary:
	# the card's own stats lifted to his tier's total when they fall short: scaled up in proportion, so the card keeps its shape (the
	# remainder to the largest fractions, ties in the stats' order), each to the tier's cap (a stat of his own above it stands) and what
	# the cap turns away to his lowest stat under it; the card's own dict when it already reaches the total
	var f := rarity_total(name)
	var order: Array = GROW.get("stats", [])
	var tot := 0
	for k in order: tot += int(st.get(k, 0))
	if f <= 0 or tot >= f or tot <= 0: return st
	var cap := rarity_cap(name)
	var out := st.duplicate(); var fr: Array = []; var sum := 0
	for i in order.size():
		var k := str(order[i]); var x := float(st.get(k, 0)) * float(f) / float(tot)
		out[k] = int(floor(x)); sum += int(out[k]); fr.append([x - floor(x), i])
	fr.sort_custom(func(a, b): return float(a[0]) > float(b[0]) + 0.0000001 or (absf(float(a[0]) - float(b[0])) <= 0.0000001 and int(a[1]) < int(b[1])))
	var j := 0
	while sum < f and fr.size() > 0: out[str(order[int(fr[j % fr.size()][1])])] = int(out[str(order[int(fr[j % fr.size()][1])])]) + 1; sum += 1; j += 1
	var over := 0
	for k in order:
		var top := maxi(cap, int(st.get(k, 0)))
		if int(out[k]) > top: over += int(out[k]) - top; out[k] = top
	while over > 0:
		var lo := ""; var lv := 1 << 20
		for k in order:
			if int(out[k]) < cap and int(out[k]) < lv: lv = int(out[k]); lo = str(k)
		if lo == "": break
		out[lo] = int(out[lo]) + 1; over -= 1
	return out

func passives_of(name: String) -> Array:
	# the passives on his board, and the off-style one in the socket
	if GROW.is_empty() or name == "": return []
	var g := _grow(name)
	if g.is_empty(): return []
	var out: Array = []
	var nodes := growth_nodes(name)
	for id in g.get("board", []):
		var n: Dictionary = nodes.get(str(id), {})
		if str(n.get("kind", "")) == "passive" and not str(n["passive"]) in out: out.append(str(n["passive"]))
		if str(n.get("kind", "")) == "socket" and str(g.get("socket", "")) != "" and not str(g["socket"]) in out: out.append(str(g["socket"]))
	return out

func _breaker(name: String, stat: String) -> bool:
	var nodes := growth_nodes(name)
	for id in _grow(name).get("board", []):
		if str(nodes.get(str(id), {}).get("kind", "")) == "breaker" and str(nodes[str(id)]["stat"]) == stat: return true
	return false

func node_cost(name: String, id: String) -> int:
	# the node's price; a stat node on a stat at 70+ doubles (NP_11 s1) until that stat's breaker is taken
	var n: Dictionary = growth_nodes(name).get(id, {})
	if n.is_empty(): return 0
	var c := int(n.get("cost", 0))
	var sc: Dictionary = GROW.get("soft_cap", {})
	if str(n.get("kind", "")) == "stat" and int(grown_stats(_club_card(name)).get(str(n["stat"]), 0)) >= int(sc.get("at", 70)) and not _breaker(name, str(n["stat"])): c *= int(sc.get("mult", 2))
	return c

func _between(what: String) -> String:
	var episode: Dictionary = rewards.get("episode", {})
	if episode.get("phase", "") == "world" and episode.get("fight", "") == "": return ""
	return ("%s between duals" % what) if mode != "OVER" and bell_rung() else ""

func node_why(name: String, id: String) -> String:
	# why this node cannot be taken now ("" when it can): between duals, the card, the board, taken, touching, the cap, the points
	if GROW.is_empty(): return "no ability boards in this build"
	var bw := _between("the board is worked")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	var nodes := growth_nodes(name)
	if not nodes.has(id): return "no node '%s' on %s's board (%s)" % [id, name, str(GROW["layouts"].get(growth_layout(name), {}).get("label", growth_layout(name)))]
	var n: Dictionary = nodes[id]
	if id in taken(name): return "%s has %s already" % [name, str(n["label"])]
	var touch := false
	for l in n["links"]:
		if str(l) in taken(name): touch = true
	if not touch: return "%s does not touch a node %s has taken" % [str(n["label"]), name]
	var c := node_cost(name, id)                                                                          # (a stat node at his cap can still be taken - the way through - and adds nothing past it)
	if c > gpoints_free(name): return "%s costs %d Board Points - %s has %d of %d free (level %d)" % [str(n["label"]), c, name, gpoints_free(name), gpoints(name), level_of(name)]
	return ""

func take_node(name: String, id: String) -> Dictionary:
	# between duals: a node on his board, paid in Board Points ("*": the aid's pick)
	var why := ""
	if id == "*":
		id = node_best(name)
		if id == "" and not GROW.is_empty() and _club_card(name).size() > 0: why = _between("the board is worked") if _between("the board is worked") != "" else "%s has no node to take - %d of %d Board Points free (level %d)" % [name, gpoints_free(name), gpoints(name), level_of(name)]
	if why == "": why = node_why(name, id)
	if why != "":
		_ev("node_refused", {"who": name, "id": id, "why": why}); _say("THE BOARD - %s" % why)
		return {"ok": false, "why": why}
	var n: Dictionary = growth_nodes(name)[id]
	var c := node_cost(name, id)
	var g := _grow_w(name)
	g["board"].append(id); g["spent"] = int(g["spent"]) + c
	_ev("node_taken", {"who": name, "id": id, "label": str(n["label"]), "kind": str(n["kind"]), "lobe": str(n["lobe"]), "stat": str(n.get("stat", "")), "v": int(n.get("v", 0)), "passive": str(n.get("passive", "")), "cost": c, "free": gpoints_free(name), "points": gpoints(name)})
	_say("THE BOARD :: %s takes %s (%s lobe, %d pts; %d of %d spent)" % [name, str(n["label"]), str(n["lobe"]), c, int(g["spent"]), gpoints(name)])
	return {"ok": true, "why": "", "id": id, "cost": c}

func node_best(name: String) -> String:
	# the aid's pick: a passive he can take now; else the first step toward the nearest passive not yet taken; else the stat node
	# that gives the most for its price (ties to the board's order)
	var nodes := growth_nodes(name)
	var tk := taken(name)
	var best := ""; var bv := -1.0
	var ww := wall_wanted(name)                                                                          # PAC-096: the Anchor Wall, when his kit needs it
	for id in nodes:
		if node_why(name, str(id)) != "": continue
		var n: Dictionary = nodes[id]
		if str(n["kind"]) == "passive" or (str(n["kind"]) == "wall" and ww): return str(id)
		if str(n["kind"]) == "wall": continue
		var v := float(clampi(rarity_cap(name) - int(grown_stats(_club_card(name)).get(str(n.get("stat", "")), 0)), 0, int(n.get("v", 0)))) / float(maxi(1, node_cost(name, str(id)))) if str(n["kind"]) == "stat" else 0.5
		if v > bv: bv = v; best = str(id)
	var first := {}; var q: Array = []                                                                   # breadth-first from what he holds
	for id in tk:
		for l in nodes.get(str(id), {}).get("links", []):
			if not str(l) in tk and not first.has(str(l)): first[str(l)] = str(l); q.append(str(l))
	while q.size() > 0:
		var x: String = q.pop_front()
		if str(nodes[x]["kind"]) == "passive" or (str(nodes[x]["kind"]) == "wall" and ww): return str(first[x]) if node_why(name, str(first[x])) == "" else best
		for l in nodes[x]["links"]:
			if not str(l) in tk and not first.has(str(l)): first[str(l)] = first[x]; q.append(str(l))
	return best

func wall_open(name: String) -> bool:
	# PAC-096: NP_05 s3's defensive board - his board holds the Anchor Wall (the node kind the techniques table names)
	var kind := str(TECH.get("t2_board", {}).get("node", "wall"))
	var nodes := growth_nodes(name)
	for id in _grow(name).get("board", []):
		if str(nodes.get(str(id), {}).get("kind", "")) == kind: return true
	return false

func wall_wanted(name: String) -> bool:
	# the aid's reason to take the Anchor Wall: his technique slots outnumber the motion families his own move leaves free, so only a
	# WALL can fill the last room (NP_05 s4: RISE, ARC, PISTON and HAYMAKER answer the stick; WALL the guard)
	if TECH.is_empty() or GROW.is_empty() or wall_open(name): return false
	var own := str(_club_card(name).get("hissatsu", ""))
	var free := 0
	for f in FAMILY_ROW:
		if str(FAMILY_ROW[f]) != "" and not (library.has(own) and str(library[own]["family"]) == str(f)): free += 1
	return tech_slots(name) > free

func respec_why(name: String) -> String:
	if GROW.is_empty(): return "no ability boards in this build"
	var bw := _between("the respec is")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	var rs: Dictionary = GROW.get("respec", {})
	if fac_tier(str(rs.get("track", "film_room"))) < int(rs.get("tier", 2)) and not FAC.is_empty(): return "the respec is the Film Room's (T%d) - the gym's is at T%d" % [int(rs.get("tier", 2)), fac_tier(str(rs.get("track", "film_room")))]
	if _grow(name).get("board", []).is_empty(): return "%s's board is bare" % name
	return ""

func respec(name: String) -> Dictionary:
	# NP_11 s3: free at the gym - every point back, the socket emptied (the raises are Beans spent, and stay)
	var why := respec_why(name)
	if why != "":
		_ev("respec_refused", {"who": name, "why": why}); _say("THE BOARD - %s" % why)
		return {"ok": false, "why": why}
	var g := _grow_w(name)
	var back := int(g["spent"]); var n := int(g["board"].size())
	g["board"] = []; g["spent"] = 0; g["socket"] = ""
	_ev("respec", {"who": name, "nodes": n, "points": back})
	_say("THE BOARD :: %s respecs at the Film Room - %d nodes, %d Board Points back" % [name, n, back])
	return {"ok": true, "why": "", "points": back}

func socket_why(name: String, pid: String) -> String:
	# NP_06 s1.2: a Boxer-Puncher may equip ONE off-style passive node - a craft passive from another style's board, in his spine's socket
	if GROW.is_empty(): return "no ability boards in this build"
	var bw := _between("the socket is set")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	var lay: Dictionary = GROW.get("layouts", {}).get(growth_layout(name), {})
	if not bool(lay.get("socket", false)): return "the off-style socket is the Boxer-Puncher's (%s's board is the %s's)" % [name, str(lay.get("label", growth_layout(name)))]
	var sid := ""
	for n in lay.get("nodes", []):
		if str(n["kind"]) == "socket": sid = str(n["id"])
	if not sid in taken(name): return "%s has not taken the socket node yet" % name
	var p: Dictionary = GROW.get("passives", {}).get(pid, {})
	if p.is_empty(): return "no passive '%s'" % pid
	if str(p.get("lobe", "")) != "craft": return "%s is a Spirit passive - the socket takes a craft one" % str(p["name"])
	if pid in lay.get("craft", []): return "%s is on %s's own board - the socket is for an off-style one" % [str(p["name"]), name]
	return ""

func socket(name: String, pid: String) -> Dictionary:
	var why := socket_why(name, pid)
	if why != "":
		_ev("socket_refused", {"who": name, "passive": pid, "why": why}); _say("THE BOARD - %s" % why)
		return {"ok": false, "why": why}
	_grow_w(name)["socket"] = pid
	_ev("socketed", {"who": name, "passive": pid, "name": str(GROW["passives"][pid]["name"])})
	_say("THE BOARD :: %s sockets %s - off-style (%s)" % [name, str(GROW["passives"][pid]["name"]), str(GROW["passives"][pid]["text"])])
	return {"ok": true, "why": ""}

# ---- the Beans' own sink: the stat raises, on typed Beans (NP_11 s6, s7) ----
func beans_typed() -> Dictionary: return rewards.get("bean_types", {})

func beans_untyped() -> int:
	var s := 0
	for k in beans_typed(): s += int(beans_typed()[k])
	return maxi(0, int(rewards.get("beans", 0)) - s)

func _beans_settle() -> void:
	# a spend from the jar's total (the Forge): the untyped go first, then the typed pools in the stats' order
	if not rewards.has("bean_types"): return
	var s := 0
	for k in rewards["bean_types"]: s += int(rewards["bean_types"][k])
	var over := s - int(rewards.get("beans", 0))
	for k in GROW.get("stats", []):
		if over <= 0: break
		var h := int(rewards["bean_types"].get(k, 0))
		var cut := mini(h, over)
		if cut > 0: rewards["bean_types"][k] = h - cut; over -= cut

func _top_stat(st: Dictionary) -> String:
	var best := ""; var bv := -1
	for k in GROW.get("stats", []):
		if int(st.get(k, -1)) > bv: bv = int(st.get(k, -1)); best = str(k)
	return best

func _beans_type(bias: String, beans: int, partner: String) -> Dictionary:
	# NP_11 s7: a slot's Beans typed by its game's bias ("any": untyped); a partner along types a quarter (rounded) as his best stat
	if GROW.is_empty() or beans <= 0: return {}
	var typed := {}
	var pb := 0; var pt := ""
	if partner != "" and _club_card(partner).size() > 0:
		pt = _top_stat(grown_stats(_club_card(partner)))
		pb = int(round(float(beans) * float(GROW.get("beans", {}).get("partner_pct", 25)) / 100.0))
	if bias in GROW.get("stats", []) and beans - pb > 0: typed[bias] = beans - pb
	if pt != "" and pb > 0: typed[pt] = int(typed.get(pt, 0)) + pb
	if not rewards.has("bean_types"): rewards["bean_types"] = {}
	for k in typed: rewards["bean_types"][k] = int(rewards["bean_types"].get(k, 0)) + int(typed[k])
	return typed

func _beans_text(typed: Dictionary, beans: int) -> String:
	var parts: Array = []
	for k in GROW.get("stats", []):
		if typed.has(k): parts.append("%d %s" % [int(typed[k]), str(k)])
	var n := 0
	for k in typed: n += int(typed[k])
	if beans - n > 0: parts.append("%d untyped" % (beans - n))
	return ", ".join(PackedStringArray(parts))

func jar_text() -> String:
	# the jar by type: "PWR 5, SPD 3, 12 untyped"
	var parts: Array = []
	for k in GROW.get("stats", []):
		if int(beans_typed().get(k, 0)) > 0: parts.append("%s %d" % [str(k), int(beans_typed()[k])])
	parts.append("%d untyped" % beans_untyped())
	return ", ".join(PackedStringArray(parts))

func raise_cost(name: String, stat: String) -> int:
	var r: Dictionary = GROW.get("raises", {})
	return int(r.get("base", 5)) + int(r.get("step", 1)) * int(_grow(name).get("raises", {}).get(stat, 0))

func raise_why(name: String, stat: String) -> String:
	if GROW.is_empty(): return "no stat raises in this build"
	var bw := _between("the raises are")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	if not stat in GROW.get("stats", []): return "no stat '%s'" % stat
	var have := int(grown_stats(_club_card(name)).get(stat, 0))
	if have >= rarity_cap(name): return "%s's %s stands at %d - the %s cap is %d" % [name, stat, have, rarity_name(rarity_of(name)), rarity_cap(name)]
	var c := raise_cost(name, stat)
	var pay := int(beans_typed().get(stat, 0)) + beans_untyped()
	if c > pay: return "+1 %s costs %d Beans - the jar holds %d %s and %d untyped" % [stat, c, int(beans_typed().get(stat, 0)), stat, beans_untyped()]
	return ""

func raise_stat(name: String, stat: String) -> Dictionary:
	# between duals: +1 on a stat, paid from the jar - the stat's own Beans first, then the untyped ("*": the aid's pick)
	var why := ""
	if stat == "*":
		stat = raise_best(name)
		if stat == "" and not GROW.is_empty() and _club_card(name).size() > 0: why = _between("the raises are") if _between("the raises are") != "" else "the jar pays no raise for %s (%s)" % [name, jar_text()]
	if why == "": why = raise_why(name, stat)
	if why != "":
		_ev("raise_refused", {"who": name, "stat": stat, "why": why}); _say("THE JAR - %s" % why)
		return {"ok": false, "why": why}
	var c := raise_cost(name, stat)
	var ft := mini(c, int(beans_typed().get(stat, 0)))
	if ft > 0: rewards["bean_types"][stat] = int(rewards["bean_types"][stat]) - ft
	rewards["beans"] = int(rewards.get("beans", 0)) - c
	var g := _grow_w(name)
	g["raises"][stat] = int(g["raises"].get(stat, 0)) + 1
	var now := int(grown_stats(_club_card(name)).get(stat, 0))
	_ev("stat_raised", {"who": name, "stat": stat, "cost": c, "typed": ft, "untyped": c - ft, "to": now, "raises": int(g["raises"][stat]), "next": raise_cost(name, stat), "jar": int(rewards["beans"])})
	_say("THE JAR :: %s +1 %s -> %d for %d Beans (%d %s, %d untyped; the next %d; the jar %d)" % [name, stat, now, c, ft, stat, c - ft, raise_cost(name, stat), int(rewards["beans"])])
	return {"ok": true, "why": "", "stat": stat, "cost": c, "to": now}

func raise_best(name: String) -> String:
	# the aid's pick: the stat with the most of its own Beans in the jar that he can raise, else the first he can
	var best := ""; var bv := -1
	for k in GROW.get("stats", []):
		if raise_why(name, str(k)) == "" and int(beans_typed().get(k, 0)) > bv: bv = int(beans_typed().get(k, 0)); best = str(k)
	return best

# ---- rarity: the ladder (NP_11 s4) ----
func ascend_why(name: String) -> String:
	if GROW.is_empty(): return "no rarity in this build"
	var bw := _between("the ascension is")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	var r := rarity_of(name)
	if r >= 4: return "%s is a %s (tier 4), the top" % [name, rarity_name(4)]
	var ra: Dictionary = GROW.get("rarity", {})
	var tr: Dictionary = ra.get("trials", {}).get(str(r + 1), {})
	if tr.size() > 0 and not _grow(name).get("trials", {}).has(str(tr["id"])): return "%s's trial for %s waits - %s" % [name, rarity_name(r + 1), str(tr["text"])]
	var sp := int(ra.get("spirits", {}).get(str(r + 1), 0))
	if int(rewards.get("spirits", 0)) < sp: return "%s costs %d Spirits (the ledger holds %d)" % [rarity_name(r + 1), sp, int(rewards.get("spirits", 0))]
	return ""

func ascend(name: String) -> Dictionary:
	var why := ascend_why(name)
	if why != "":
		_ev("ascend_refused", {"who": name, "why": why}); _say("RARITY - %s" % why)
		return {"ok": false, "why": why}
	var t := rarity_of(name) + 1
	var sp := int(GROW["rarity"].get("spirits", {}).get(str(t), 0))
	rewards["spirits"] = int(rewards.get("spirits", 0)) - sp
	_grow_w(name)["rarity"] = t
	_ev("ascended", {"who": name, "tier": t, "name": rarity_name(t), "spirits": sp, "cap": rarity_cap(name), "slots": accessory_slots(name), "awakening": awaken_eligible(name), "total": rarity_total(name)})
	_say("RARITY :: %s ascends to %s (tier %d) for %d Spirits - growth to %d, %d accessory slot%s%s%s" % [name, rarity_name(t).to_upper(), t, sp, rarity_cap(name), accessory_slots(name), "" if accessory_slots(name) == 1 else "s", (", a %d stat total at least" % rarity_total(name)) if rarity_total(name) > 0 else "", ", the Awakening flag" if t >= int(GROW["rarity"].get("awakening_tier", 4)) else ""])
	return {"ok": true, "why": "", "tier": t}

func _trial_mark(name: String, tid: String) -> void:
	# a deed his ascension asks for, on the ledger with its day (first time only)
	if GROW.is_empty() or name == "" or _club_card(name).is_empty(): return
	var g := _grow_w(name)
	if g["trials"].has(tid): return
	g["trials"][tid] = int(rewards.get("day", 1))
	_ev("trial_met", {"who": name, "trial": tid})
	_say("TRIAL :: %s - %s" % [name, {"spar_won": "a spar won", "storm": "a transform weathered", "mirror": "the mirror beaten"}.get(tid, tid)])

func mirror_card(name: String) -> Dictionary:
	# NP_11 s4's mirror match: his own card as an NPC's, on his grown stats, fighting strings assembled for it
	var c: Dictionary = _club_card(name).duplicate(true)
	if c.is_empty(): return {}
	c["stats"] = grown_stats(_club_card(name)).duplicate()
	c["name"] = "%s'S MIRROR" % name; c["generic"] = true; c["tier"] = clampi(rarity_of(name), 1, 3)
	c.erase("reserve")
	var hc := habit_copy(name)                                                                        # PAC-093: the copy fights on his record (NP_02 s2.2)
	if hc["strings"].size() > 0: c["habits"] = hc["strings"]
	if hc["reads"].size() > 0: c["mirror_reads"] = hc["reads"]
	if hc["counter"].size() > 0: c["mirror_counter"] = hc["counter"]
	c["mirror_of"] = name; c["learned_from"] = int(hc["punches"])
	return c

func start_mirror(name: String) -> bool:
	# the trial spar: he goes out against his mirror (the lab flags are not The Ring's to set - the trial is authored)
	if GROW.is_empty() or _club_card(name).is_empty(): return false
	return start_spar(_first_boss, [], mirror_card(name), "", "THE MIRROR - %s" % name, {"fighter": name, "mirror": name, "authored": true})

func growth_line(name: String) -> String:
	# one fighter's growth between duals
	if GROW.is_empty() or _club_card(name).is_empty(): return ""
	var g := _grow(name); var r := rarity_of(name)
	var pas: Array = passives_of(name).map(func(p): return str(GROW["passives"][p]["name"]))
	var nb := node_best(name)
	var nxt := ""
	if r < 4:
		var tr: Dictionary = GROW["rarity"].get("trials", {}).get(str(r + 1), {})
		nxt = "; %s: %d Spirits + %s%s" % [rarity_name(r + 1), int(GROW["rarity"]["spirits"].get(str(r + 1), 0)), str(tr.get("text", "")), " (done)" if g.get("trials", {}).has(str(tr.get("id", ""))) else ""]
	return "%s L%d %s (T%d, cap %d): board %d of %d pts, %d nodes%s%s; raises %s%s" % [name, level_of(name), rarity_name(r), r, rarity_cap(name), int(g.get("spent", 0)), gpoints(name), g.get("board", []).size(),
		(" - " + ", ".join(PackedStringArray(pas))) if pas.size() > 0 else "", (" - next [N] %s" % str(growth_nodes(name)[nb]["label"])) if nb != "" else "",
		JSON.stringify(g.get("raises", {})) if g.get("raises", {}).size() > 0 else "none", nxt]

func grow_aid(who: String) -> int:
	# the aid between duals: for each dressed card (or the one named) the node it would pick, the raise it would pick, the ascension when ready
	if GROW.is_empty(): return 0
	var n := 0
	for c in dressed:
		var nm := str(c.get("name", ""))
		if who != "*" and nm != who: continue
		if node_best(nm) != "" and bool(take_node(nm, "*")["ok"]): n += 1
		if raise_best(nm) != "" and bool(raise_stat(nm, "*")["ok"]): n += 1
		if ascend_why(nm) == "" and bool(ascend(nm)["ok"]): n += 1
	return n

static func seed_growth(ledger: Dictionary, g_arg: String) -> Dictionary:
	# `-- growth=RORY:rarity:2,RORY:trial:spar_won,PRIYA:raise:RFX:3` -> the ledger as rarity, trials and raises would have left it
	# (nodes are taken on the board - `-- board_nodes=` - where their price is paid)
	var out := ledger.duplicate(true)
	for part in g_arg.split(",", false):
		var b := str(part).strip_edges().split(":")
		if b.size() < 3: continue
		if not out.has("growth"): out["growth"] = {}
		var nm := str(b[0])
		if not out["growth"].has(nm): out["growth"][nm] = {"board": [], "spent": 0, "socket": "", "raises": {}, "rarity": 1, "trials": {}}
		var g: Dictionary = out["growth"][nm]
		if str(b[1]) == "rarity" and str(b[2]).is_valid_int(): g["rarity"] = clampi(int(b[2]), 1, 4)
		elif str(b[1]) == "trial": g["trials"][str(b[2])] = 1
		elif str(b[1]) == "raise" and b.size() == 4 and str(b[3]).is_valid_int(): g["raises"][str(b[2])] = int(b[3])
	return out

static func seed_beans(ledger: Dictionary, b_arg: String) -> Dictionary:
	# `-- beans=PWR:10,SPD:4` -> typed Beans in the jar (added to its total; `-- purse=beans:N` adds untyped)
	var out := ledger.duplicate(true)
	for part in b_arg.split(",", false):
		var kv := str(part).strip_edges().split(":")
		if kv.size() != 2 or not str(kv[1]).is_valid_int(): continue
		if not out.has("bean_types"): out["bean_types"] = {}
		out["bean_types"][str(kv[0])] = int(out["bean_types"].get(str(kv[0]), 0)) + int(kv[1])
		out["beans"] = int(out.get("beans", 0)) + int(kv[1])
	return out

# ============================ THE ACADEMY (NP_07 s10: Arc 3's thesis) =======
# The Toronto Ascendant Academy has industrialized synthesis without bonds (academy.v1.json). Fielded, its prodigies fight every enemy
# segment - generic cards on the assembler, each drilled on one house's dialect without the house - and Director Vey's corner coaches them.
# Each carries three syntheses: hybrids the Forge's own composer makes from two houses' natives straight off the library (no pair, no bond,
# no native learned), their damage x0.85 - slightly weaker per move, overwhelming in breadth. A prodigy casts the next in his rotation from
# his bar whenever it pays, at his decision point, within the family's reach: no CHARGED, no relay, no afterimage, no feud or alliance
# history. The club's answer is its forged hybrids (C41) - fewer, relayed x1.25 with the partner's afterimage, each with its pair and edge.
func synthesize(ha: String, hb: String) -> Dictionary:
	# the academy's synthesis of two houses: the composer on the library's natives, then priced down
	var cr: Dictionary = HYB.get("compose", {}); var sy: Dictionary = ACAD.get("synthesis", {})
	var hs: Array = [house_key(ha), house_key(hb)]; hs.sort()
	var parts := _compose_parts([[str(hs[0]), house_natives(str(hs[0]))], [str(hs[1]), house_natives(str(hs[1]))]])
	var fam := str(parts["fam"]); var tags: Array = parts["tags"]
	var dmg := snappedf(float(parts["dmg"]) * float(sy.get("dmg_mult", 0.85)), 0.01)
	var mo: Dictionary = HYB.get("motifs", {})
	var nm := str(sy.get("name_rule", "Synthesis {a}-{b}")).replace("{a}", str(mo.get(str(hs[0]), _house_name(str(hs[0]))))).replace("{b}", str(mo.get(str(hs[1]), _house_name(str(hs[1])))))
	var eff: Array = [{"type": "DMG", "params": {"mult": dmg, "composure_bypass_pct": 0}}]
	eff.append_array(tags)
	return _whole({"id": "SYN-%s-%s" % [str(hs[0]), str(hs[1])], "name": nm, "tier": str(cr.get("tier", "T3")), "family": fam, "element": str(cr.get("element", "DUAL")),
		"house_id": null, "style_req": null, "tension_cost": int(cr.get("tension_cost", 50)), "private_meter_cost": null,
		"startup_cinematic_ms": int(cr.get("cinematic_base_ms", 2100)) + int(cr.get("cinematic_per_tag_ms", 100)) * tags.size(), "effect": eff,
		"counter_profile": sy.get("counter_profile", cr.get("counter_profile", {"interruptible": true, "window_ms": 700, "negation": ""})).duplicate(true), "duo_variant": null,
		"hybrid_parents": [str(hs[0]), str(hs[1])], "camera_script_id": str(cr.get("camera", "cam_{family}_t3")).replace("{family}", fam.to_lower()),
		"vfx_set": str(sy.get("vfx_set", "vfx_synth")), "source": str(sy.get("source", "synthesis:academy")), "synthesis": true, "secret": false,
		"notes": "the academy's synthesis - no pair forged it"})

func _synth_power(m: Dictionary) -> float:
	for e in m.get("effect", []):
		if str(e["type"]) == "DMG": return float(e["params"].get("mult", e["params"].get("base", 0.0)))
	return 0.0

func prodigy_spec(i: int) -> Dictionary:
	# the academy's i-th prodigy (the squad repeats past its size): a generic of his style on his house's dialect, the house left out
	var pl: Array = ACAD.get("prodigies", [])
	if pl.is_empty(): return {}
	var pr: Dictionary = pl[i % pl.size()]
	var sp := generic_spec(str(pr["name"]), str(pr.get("style", "BOXERPUNCHER")), str(pr.get("dialect", "gym")), int(pr.get("tier", 3)), 0, str(pr["name"]))
	sp["house"] = "none"; sp["synth"] = pr.get("syntheses", []).duplicate(true); sp["academy"] = str(ACAD.get("club", "the academy"))
	return sp

func field_academy(on: bool) -> Dictionary:
	# the academy's squad in every enemy segment, Director Vey in their corner - from the next reset (new_dual); off: the named squads again
	if ACAD.is_empty(): return {"ok": false, "why": "no academy in this build"}
	if mode != "OVER" and bell_rung(): return {"ok": false, "why": "the squad is set between duals"}
	clear_generics(); academy_on = on
	if on:
		for i in maxi(segments(), int(fmt.get("enemy_dressed", 4))): set_generic_slot(i, prodigy_spec(i))
	_ev("academy_fielded", {"on": on, "club": str(ACAD.get("club", "")), "squad": generic_slots.keys().map(func(k): return str(generic_slots[k]["name"]))})
	_say("THE ACADEMY :: %s" % ("%s fields its prodigies - Director Vey's corner" % str(ACAD.get("club", ""))) if on else "the named squads again")
	return {"ok": true, "why": ""}

func _synth_try() -> bool:
	# at his decision point: the next synthesis in his rotation, when his bar pays and he is within its family's reach
	var sl: Array = B.get("synth", [])
	if sl.is_empty() or not cast.is_empty() or not clinch.is_empty() or not mclash.is_empty(): return false
	var i := int(B.get("synth_i", 0)) % sl.size()
	var mv: Dictionary = sl[i]
	if btension < float(mv["tension_cost"]): return false
	var row := str(FAMILY_ROW.get(str(mv["family"]), ""))
	if row == "" or P["pos"].distance_to(B["pos"]) > float(GEO[_punch_family(row)]["reach"]) + float(ACAD.get("synthesis", {}).get("reach_plus", 0.3)): return false
	B["synth_i"] = (i + 1) % sl.size()
	B["synth_casts"] = int(B.get("synth_casts", 0)) + 1
	_ev("synthesis", {"who": boss_label, "move": str(mv["name"]), "family": str(mv["family"]), "dmg": _synth_power(mv), "houses": mv["hybrid_parents"].duplicate(), "n": i + 1, "of": sl.size(), "bar": btension})
	_start_cast("B", mv)
	return true

# ---- PAC-102: the anti-you (NP_12 s2) - the academy signs the club's beaten rivals between arcs ----
func _arq() -> Dictionary: return ACAD.get("recruiting", {})

func _aq() -> Dictionary:
	if not rewards.has("academy"): rewards["academy"] = {"taken": {}, "turns": [], "order": []}
	return rewards["academy"]

func academy_taken() -> Array:
	# the rivals the academy holds, in the order it signed them (the ledger keeps the order: a save writes a dictionary's keys sorted)
	var q: Dictionary = rewards.get("academy", {})
	return q.get("order", []).filter(func(x): return q.get("taken", {}).has(str(x)))

func academy_left_behind() -> Array:
	# the club's beaten rivals it never signed: the recruit table's fighters approachable or approached (a release settled among them), in
	# the order the club met them
	var out: Array = []
	for rn in rewards["recruit"]:
		var st := recruit_state(str(rn))
		if st == "approachable" or st == "approached": out.append(str(rn))
	return out

func _academy_recruit(flag: String) -> void:
	# NP_12 s2: an arc turns - Director Vey signs up to the table's number of the club's beaten rivals it left behind
	if ACAD.is_empty() or _arq().is_empty() or not (flag in _arq().get("turns", [])): return
	var q := _aq()
	if flag in q["turns"]: return
	q["turns"].append(flag)
	var took: Array = []
	var d := int(rewards.get("day", 1))
	for rn in academy_left_behind():
		if took.size() >= int(_arq().get("per_turn", 3)): break
		var was: Dictionary = rewards["recruit"][rn].duplicate(true)
		rewards["recruit"][rn] = {"state": "academy", "day": d, "turn": flag, "was": was}
		q["taken"][rn] = {"day": d, "turn": flag, "flag": str(was.get("released", {}).get("flag", ""))}
		q["order"].append(rn)
		took.append(rn)
	_ev("academy_signs", {"turn": flag, "day": d, "names": took, "cards": took.map(func(x): return str(_recruit_rec(str(x)).get("card", x))), "left": academy_left_behind().size()})
	if took.size() > 0: _say("THE ANTI-YOU :: %s signs %s - rivals the club beat and left waiting (%s)" % [str(ACAD.get("club", "the academy")), ", ".join(PackedStringArray(took.map(func(x): return str(_recruit_rec(str(x)).get("card", x))))), flag])

func _academy_beaten() -> void:
	# the academy beaten in a dual: every rival it holds comes over, approachable again, a release still remembered (NP_12 s6)
	var q: Dictionary = rewards.get("academy", {})
	if q.get("taken", {}).is_empty(): return
	var d := int(rewards.get("day", 1))
	var came: Array = []
	for rn in academy_taken():
		var rec: Dictionary = rewards["recruit"].get(rn, {})
		var nr := {"state": "approachable", "witnessed": 0, "day": d, "academy": {"day": int(q["taken"][rn]["day"]), "turn": str(q["taken"][rn]["turn"])}}
		if rec.get("was", {}).has("released"): nr["released"] = rec["was"]["released"].duplicate(true)
		rewards["recruit"][rn] = nr
		came.append(str(rn))
	q["taken"] = {}; q["order"] = []
	_ev("academy_beaten", {"names": came, "cards": came.map(func(x): return str(_recruit_rec(str(x)).get("card", x))), "day": d})
	_say("THE ACADEMY BEATEN :: %s come over - approachable" % ", ".join(PackedStringArray(came.map(func(x): return str(_recruit_rec(str(x)).get("card", x))))))

func academy_fielded() -> Array:
	# the rivals it holds who fight for it: those with a pattern of their own (a recruit card with none - Dex - is held, not fielded)
	return academy_taken().filter(func(x): return patterns.has(str(x)))

func academy_kit(name: String) -> Array:
	# a rival at the academy fields with the syntheses of the prodigy whose place it takes (its slot in the squad)
	var tk := academy_fielded()
	var i := tk.find(name)
	return prodigy_spec(i).get("synth", []) if i >= 0 else []

func academy_lines() -> Array:
	# the club's side: who went to the academy, when, and how they left the club
	var out: Array = []
	for rn in academy_taken():
		var tk: Dictionary = rewards["academy"]["taken"][rn]
		out.append("%s (%s): signed by %s at %s (day %d)%s%s - beat the academy and the rival comes over" % [str(_recruit_rec(str(rn)).get("card", rn)), str(rn), str(ACAD.get("club", "the academy")), str(tk["turn"]), int(tk["day"]), (" - released by the club with %s" % ("warmth" if str(tk["flag"]) == "warmth" else "a grudge")) if str(tk.get("flag", "")) != "" else "", "" if patterns.has(str(rn)) else " - held, with no pattern of its own to field"])
	return out

func academy_line() -> String:
	# the matchup card: his syntheses, their power, and what they lack
	var sl: Array = B.get("synth", [])
	if sl.is_empty(): return ""
	return "ACADEMY: %s carries %d syntheses - %s - no bond, no afterimage, no history" % [boss_label, sl.size(), ", ".join(PackedStringArray(sl.map(func(m): return "%s (LB + %s, x%s)" % [str(m["name"]), str(m["family"]), _n(_synth_power(m))])))]

func thesis_line() -> String:
	# the matchup card against the academy: the club's forged hybrid (the one live for the fighter out, else the club's strongest) against his
	# strongest synthesis, in the numbers
	var sl: Array = B.get("synth", [])
	if sl.is_empty(): return ""
	var sb: Dictionary = {}
	for m in sl:
		if sb.is_empty() or _synth_power(m) > _synth_power(sb): sb = m
	var hm := hybrid_move()
	var key := str(hm.get("hybrid_of", "")) if hm.size() > 0 else ""
	if key == "":
		for k in _hyb_reg():
			if key == "" or _synth_power(_hyb_reg()[k].get("move", {})) > _synth_power(_hyb_reg()[key].get("move", {})): key = str(k)
	if key == "": return "THESIS: his best synthesis %s x%s against no hybrid of the club's - the Forge makes fewer, with bonds" % [str(sb["name"]), _n(_synth_power(sb))]
	var r: Dictionary = _hyb_reg()[key]
	var base := _synth_power(r.get("move", {}))
	var rl := float(HYB.get("cast", {}).get("relayed_dmg_mult", 1.25))
	var now := ""
	if hm.size() > 0 and str(hm.get("hybrid_live", "")) == "relayed": now = " - relayed now, x%s with %s's afterimage" % [_n(base * rl), str(hm.get("hybrid_partner", ""))]
	elif hm.size() > 0: now = " - live now (%s)" % str(hm.get("hybrid_live", ""))
	else: now = " (x%s relayed)" % _n(base * rl)
	return "THESIS: your forged %s (%s%s) x%s%s against his best synthesis %s x%s" % [str(r["name"]), key.replace("|", " & "), (", " + str(r.get("edge", ""))) if str(r.get("edge", "")) != "" else "", _n(base), now, str(sb["name"]), _n(_synth_power(sb))]

# ============================ TECHNIQUES (NP_11 s2, s8) =====================
# A card walks out carrying its own move (its hissatsu, as dressed) and a kit beside it (techniques.v1.json):
#   the slots - technique slots at levels 5 / 15 / 25 / 35 / 45 hold learned T1s and T2s; the T0 slot opens at level 5 and holds exactly one
#     T0, the identity move (a card whose own move is a T0 has it there, castable from level 5); his house's natives, known, take no slot.
#   the sources - the HBP shop (three shelves by circuit progress), the masters (the coach, the conditioning coach, a recruit's own list,
#     behind a bond, a stat, a flag or a deed), fight tapes (spent on use; a quest's tape arrives with its flag), the natives (C31) and the
#     Forge's hybrid (C41, cast by its own rule); and the re-teach, a learned non-native passed to a stablemate in a training slot.
# The ledger keeps what each fighter learned and from where, his kit, the tapes and the deeds (rewards["techniques"]). At the bell his kit
# rides on him (P["kit"]); LB + a motion casts his own move when its family matches, else the kit's first move of that family.
func _tq() -> Dictionary:
	if not rewards.has("techniques"): rewards["techniques"] = {}
	for k in ["learned", "kit", "tapes", "granted", "eights"]:
		if not rewards["techniques"].has(k): rewards["techniques"][k] = {}
	return rewards["techniques"]

func _tq_r(k: String) -> Dictionary: return rewards.get("techniques", {}).get(k, {})

func tech_slots(name: String) -> int:
	# NP_11 s2: a slot at each of the levels, five at most
	var n := 0
	for lv in TECH.get("slot_levels", []):
		if level_of(name) >= int(lv): n += 1
	return n

func t0_open(name: String) -> bool: return TECH.is_empty() or level_of(name) >= int(TECH.get("t0_level", 5))

func learned(name: String) -> Dictionary: return _tq_r("learned").get(name, {})

func kit_of(name: String) -> Array: return _tq_r("kit").get(name, [])

func _src(move: String) -> String: return str(library.get(move, {}).get("source", ""))

func tech_class(move: String) -> String:
	# how a move sits in a kit: "native" (his house's, no slot), "t0" (the T0 slot), "slot" (a technique slot), "own_rule" (cast by its own
	# rule), "not_learnable", or "" (not in the library)
	if not library.has(move): return ""
	var m: Dictionary = library[move]
	var s := _src(move)
	if TECH.get("own_rule", {}).has(s): return "own_rule"
	for k in TECH.get("not_learnable", {}):
		if s == str(k) or (str(k).ends_with(":") and s.begins_with(str(k))): return "not_learnable"
	if m.get("house_id") != null: return "native"
	if str(m["tier"]) == "T0": return "t0"
	if str(m["tier"]) in TECH.get("slot_tiers", ["T1", "T2"]): return "slot"
	return "own_rule"

func _why_class(move: String) -> String:
	var s := _src(move)
	if tech_class(move) == "own_rule": return "%s is cast by its own rule - %s" % [move, str(TECH.get("own_rule", {}).get(s, "a %s" % str(library[move]["tier"])))]
	for k in TECH.get("not_learnable", {}):
		if s == str(k) or (str(k).ends_with(":") and s.begins_with(str(k))): return "%s is not the club's to learn - %s" % [move, str(TECH["not_learnable"][k])]
	return ""

func known(name: String) -> Array:
	# what he can carry: his own move, what he learned, his house's natives he knows
	var out: Array = []
	var own := str(_club_card(name).get("hissatsu", ""))
	if own != "": out.append(own)
	for mv in learned(name):
		if not str(mv) in out: out.append(str(mv))
	for mv in learned_natives(name):
		if not str(mv) in out: out.append(str(mv))
	return out

func _kit_room(name: String) -> Dictionary:
	# what the kit holds against its slots: the T0 (his own if a T0), the technique slots used
	var own := str(_club_card(name).get("hissatsu", ""))
	var t0 := own if library.has(own) and str(library[own]["tier"]) == "T0" else ""
	var used := 0
	for mv in kit_moves(name):
		match tech_class(str(mv)):
			"t0": t0 = str(mv) if t0 == "" else t0
			"slot": used += 1
	return {"t0": t0, "used": used, "slots": tech_slots(name)}

func kit_moves(name: String) -> Array:
	# the kit as it walks out: the ledger's kit in its order, what he knows only, each class to its room (the T0 at level 5, one; the slots
	# his level opens; the natives beside them)
	var out: Array = []
	if TECH.is_empty(): return out
	var own := str(_club_card(name).get("hissatsu", ""))
	var kn := known(name)
	var has_t0 := library.has(own) and str(library[own]["tier"]) == "T0"
	var used := 0
	for mv in kit_of(name):
		var m := str(mv)
		if m == own or m in out or not (m in kn): continue
		match tech_class(m):
			"native": out.append(m)
			"t0":
				if t0_open(name) and not has_t0: out.append(m); has_t0 = true
			"slot":
				if used < tech_slots(name) and _t2_why(name, m) == "": out.append(m); used += 1
	return out

func kit_why(name: String, move: String) -> String:
	# why this move cannot go into his kit now ("" when it can)
	if TECH.is_empty(): return "no technique slots in this build"
	var bw := _between("the kit is set")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	if not library.has(move): return "no technique '%s'" % move
	if move == str(_club_card(name).get("hissatsu", "")): return "%s carries %s already (the card's own move)" % [name, move]
	if move in kit_moves(name): return "%s's kit holds %s already" % [name, move]
	var wc := _why_class(move)
	if wc != "": return wc
	if not (move in known(name)): return "%s has not learned %s" % [name, move]
	var t2w := _t2_why(name, move)
	if t2w != "": return t2w
	var room := _kit_room(name)
	match tech_class(move):
		"t0":
			if not t0_open(name): return "the T0 slot opens at level %d - %s is level %d" % [int(TECH.get("t0_level", 5)), name, level_of(name)]
			if str(room["t0"]) != "": return "%s carries a T0 already (%s) - one T0, the identity move (NP_05 s3)" % [name, str(room["t0"])]
		"slot":
			if int(room["used"]) >= int(room["slots"]):
				var nxt := 0
				for lv in TECH.get("slot_levels", []):
					if nxt == 0 and level_of(name) < int(lv): nxt = int(lv)
				return "%s's technique slots are full (%d of %d)%s" % [name, int(room["used"]), int(room["slots"]), (" - level %d opens the next" % nxt) if nxt > 0 else " - five, the most"]
	return ""

func kit_equip(name: String, move: String) -> Dictionary:
	if move == "*": move = kit_best(name)
	var why := kit_why(name, move)
	if why != "":
		_ev("kit_refused", {"who": name, "move": move, "why": why}); _say("THE KIT - %s" % why)
		return {"ok": false, "why": why}
	var t := _tq()
	t["kit"][name] = kit_moves(name) + [move]                                                            # the ledger's kit as he carries it (a seeded list cut to his slots), then the move
	var cls := tech_class(move)
	_ev("kit_equipped", {"who": name, "move": move, "class": cls, "family": str(library[move]["family"]), "tier": str(library[move]["tier"]), "kit": kit_moves(name)})
	_say("THE KIT :: %s carries %s (%s %s, %s)" % [name, move, str(library[move]["tier"]), str(library[move]["family"]), {"t0": "the T0 slot", "native": "a native - no slot", "slot": "a technique slot"}.get(cls, cls)])
	return {"ok": true, "why": "", "move": move}

func kit_unequip(name: String, move: String) -> Dictionary:
	if move == "*": move = str(kit_moves(name)[-1]) if kit_moves(name).size() > 0 else ""
	var why := ""
	if TECH.is_empty(): why = "no technique slots in this build"
	elif _between("the kit is set") != "": why = _between("the kit is set")
	elif not move in kit_moves(name): why = "%s's kit holds no %s" % [name, move if move != "" else "technique"]
	if why != "":
		_ev("kit_refused", {"who": name, "move": move, "why": why}); _say("THE KIT - %s" % why)
		return {"ok": false, "why": why}
	var kk: Array = kit_moves(name); kk.erase(move); _tq()["kit"][name] = kk
	_ev("kit_unequipped", {"who": name, "move": move}); _say("THE KIT :: %s puts %s down (still learned)" % [name, move])
	return {"ok": true, "why": ""}

func kit_unreachable(name: String) -> Array:
	# PAC-095: the moves in his kit that never answer a motion. LB + a motion casts his own move on its family, else the kit's first of
	# that family he can pay for (C45) - so a move answers at some bar only when every move ahead of it on its family costs more
	var ahead := {}
	var own := str(_club_card(name).get("hissatsu", ""))
	if library.has(own) and (str(library[own]["tier"]) != "T0" or t0_open(name)): ahead[str(library[own]["family"])] = [float(library[own]["tension_cost"])]
	var out: Array = []
	for mv in kit_moves(name):
		var m: Dictionary = library.get(str(mv), {})
		if m.is_empty(): continue
		var f := str(m["family"]); var c := float(m["tension_cost"])
		var fa: Array = ahead.get(f, [])
		if fa.any(func(x): return float(x) <= c): out.append(str(mv))
		fa.append(c); ahead[f] = fa
	return out

func kit_best(name: String) -> String:
	# the aid: the first move he knows and can carry now, in the order he learned it
	for mv in learned(name).keys() + learned_natives(name):
		if kit_why(name, str(mv)) == "": return str(mv)
	return ""

func _learn(name: String, move: String, source: String) -> void:
	var t := _tq()
	if not t["learned"].has(name): t["learned"][name] = {}
	t["learned"][name][move] = source
	_ev("learned", {"who": name, "move": move, "source": source, "tier": str(library[move]["tier"]), "family": str(library[move]["family"])})
	_say("LEARNED :: %s - %s (%s %s) from %s" % [name, move, str(library[move]["tier"]), str(library[move]["family"]), source])
	if kit_why(name, move) == "": kit_equip(name, move)                                                   # a room free: it goes straight into his kit

func _learn_why(name: String, move: String) -> String:
	# the common refusals of every source
	if TECH.is_empty(): return "no techniques in this build"
	var bw := _between("techniques are learned")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	if not library.has(move): return "no technique '%s'" % move
	var wc := _why_class(move)
	if wc != "": return wc
	if tech_class(move) == "native": return "%s is a House %s native - membership or a gift (NP_07 s4)" % [move, str(library[move]["house_id"]).capitalize()]
	if move in known(name): return "%s knows %s already" % [name, move]
	return _t2_why(name, move)

# ---- the HBP shop: the generic library in three shelves by circuit progress ----
func shop_tier_of(move: String) -> String:
	if not library.has(move): return ""
	var s := _src(move); var tr := str(library[move]["tier"])
	for t in TECH.get("shop", {}).get("order", []):
		var td: Dictionary = TECH["shop"]["tiers"][t]
		if s in td.get("sources", []) or (s == "generic" and tr in td.get("generic_tiers", [])): return str(t)
	return ""

func shop_open(tier: String) -> bool:
	return shelf_open_by("techniques", tier) != "closed"                                                  # PAC-103: its flag, or DOWNTOWN's rep

func shop_list() -> Array:
	# the shop's rows in the library's order: move, shelf, price, open
	var out: Array = []
	for mv in library:
		var t := shop_tier_of(str(mv))
		if t != "": out.append({"move": str(mv), "tier": t, "hbp": int(TECH["shop"]["tiers"][t].get("hbp", 0)), "open": shop_open(t)})
	return out

func buy_why(name: String, move: String) -> String:
	var t := shop_tier_of(move)
	if library.has(move) and t == "": return "%s is not in the HBP shop" % move
	var lw := _learn_why(name, move)
	if lw != "": return lw
	var td: Dictionary = TECH["shop"]["tiers"][t]
	if not shop_open(t): return "the shop's %s shelf opens with %s (%s)%s" % [t, str(td.get("text", "")), str(td.get("flag", "")), shelf_rep_clause("techniques", t)]
	if int(rewards.get("hbp", 0)) < int(td.get("hbp", 0)): return "%s costs %d HBP (the ledger holds %d)" % [move, int(td.get("hbp", 0)), int(rewards.get("hbp", 0))]
	return ""

func buy(name: String, move: String) -> Dictionary:
	# between duals: a technique from the shop, paid in HBP ("*": the aid's pick)
	if move == "*": move = buy_best(name)
	var why := buy_why(name, move) if move != "" else "the shop has nothing %s can carry and the ledger affords (%d HBP)" % [name, int(rewards.get("hbp", 0))]
	if why != "":
		_ev("buy_refused", {"who": name, "move": move, "why": why}); _say("THE SHOP - %s" % why)
		return {"ok": false, "why": why}
	var hb := int(TECH["shop"]["tiers"][shop_tier_of(move)].get("hbp", 0))
	rewards["hbp"] = int(rewards.get("hbp", 0)) - hb
	_ev("bought", {"who": name, "move": move, "tier": shop_tier_of(move), "hbp": hb, "ledger": int(rewards["hbp"])})
	_learn(name, move, "shop")
	return {"ok": true, "why": "", "move": move, "hbp": hb}

func buy_best(name: String) -> String:
	# the aid: the dearest shelf open he can afford whose move his kit has room for, in the library's order
	var best := ""; var bh := -1
	for r in shop_list():
		if buy_why(name, str(r["move"])) != "": continue
		var room := _kit_room(name)
		var cls := tech_class(str(r["move"]))
		var fits: bool = (cls == "t0" and t0_open(name) and str(room["t0"]) == "") or (cls == "slot" and int(room["used"]) < int(room["slots"]))
		if fits and int(r["hbp"]) > bh: bh = int(r["hbp"]); best = str(r["move"])
	return best

# ---- the masters: the coach, the conditioning coach, a recruit's own list ----
func master_here(mid: String) -> String:
	# "" when the master can teach (the coach always; a staff role while one is dressed; a card in the stable)
	var md: Dictionary = TECH.get("masters", {}).get(mid, {})
	if md.is_empty(): return "no master '%s'" % mid
	match str(md.get("kind", "")):
		"staff":
			for sid in staff_dressed():
				if staff_role(str(sid)) == str(md.get("role", "")): return ""
			return "%s teaches while one is dressed - no %s on the staff" % [str(md.get("label", mid)), str(md.get("role", ""))]
		"card":
			return "" if _stable_card(mid).size() > 0 else "%s is not in the stable" % mid
		"board":
			return ""                                                                                # PAC-096: his own board teaches (the gate is the node)
	return ""

func _gate_why(g: Dictionary, mid: String, name: String) -> String:
	if g.has("bond") and kizuna_level(mid, name) < int(g["bond"]): return "%s teaches it at Kizuna Lv%d - %s & %s are at Lv%d" % [mid, int(g["bond"]), mid, name, kizuna_level(mid, name)]
	if g.has("stat") and int(grown_stats(_club_card(name)).get(str(g["stat"]), 0)) < int(g.get("min", 0)): return "it wants %s %d - %s has %d" % [str(g["stat"]), int(g["min"]), name, int(grown_stats(_club_card(name)).get(str(g["stat"]), 0))]
	if g.has("flag") and not _flag_set(str(g["flag"])): return "it waits on %s" % str(g["flag"])
	if bool(g.get("eight", false)) and not _tq_r("eights").has(name): return "%s has not survived a standing-eight yet" % name
	if g.has("node") and not wall_open(name): return "%s has not taken the %s on the board" % [name, _wall_label(name)]
	return ""

func _wall_label(name: String) -> String:
	var kind := str(TECH.get("t2_board", {}).get("node", "wall"))
	for n in GROW.get("layouts", {}).get(growth_layout(name), {}).get("nodes", []):
		if str(n.get("kind", "")) == kind: return str(n["label"])
	return "Anchor Wall"

func _t2_why(name: String, move: String) -> String:
	# PAC-096: NP_05 s3 - a T2 guard-wall in a technique slot wants a defensive board
	if not library.has(move) or str(library[move]["tier"]) != "T2" or tech_class(move) != "slot" or TECH.get("t2_board", {}).is_empty() or wall_open(name): return ""
	return "a T2 wall wants a defensive board - %s has not taken the %s (NP_05 s3)" % [name, _wall_label(name)]

func lesson_why(mid: String, name: String, move: String) -> String:
	var md: Dictionary = TECH.get("masters", {}).get(mid, {})
	if md.is_empty(): return "no master '%s'" % mid
	var ent: Dictionary = {}
	for e in md.get("teaches", []):
		if str(e["move"]) == move: ent = e
	if ent.is_empty(): return "%s does not teach %s" % [str(md.get("label", mid)), move]
	if mid == name: return "%s is the master - a lesson needs another learner" % name
	var lw := _learn_why(name, move)
	if lw != "": return lw
	var mh := master_here(mid)
	if mh != "": return mh
	var gw := _gate_why(ent.get("gate", {}), mid, name)
	if gw != "": return "%s's %s: %s" % [str(md.get("label", mid)), move, gw]
	return ""

func lessons_open(name: String) -> Array:
	var out: Array = []
	for mid in TECH.get("masters", {}):
		for e in TECH["masters"][mid].get("teaches", []):
			if lesson_why(str(mid), name, str(e["move"])) == "": out.append([str(mid), str(e["move"])])
	return out

func lesson(mid: String, name: String, move: String) -> Dictionary:
	# between duals: a master teaches from his list, free - the gate is the price ("*": the first lesson open to him)
	if mid == "*":
		var lo := lessons_open(name)
		if lo.is_empty():
			var w0 := "no master has a lesson open for %s" % name
			_ev("lesson_refused", {"who": name, "master": "*", "move": "", "why": w0}); _say("THE MASTERS - %s" % w0)
			return {"ok": false, "why": w0}
		mid = str(lo[0][0]); move = str(lo[0][1])
	var why := lesson_why(mid, name, move)
	if why != "":
		_ev("lesson_refused", {"who": name, "master": mid, "move": move, "why": why}); _say("THE MASTERS - %s" % why)
		return {"ok": false, "why": why}
	_ev("lesson", {"who": name, "master": mid, "label": str(TECH["masters"][mid].get("label", mid)), "move": move})
	_learn(name, move, "master:" + mid)
	return {"ok": true, "why": "", "master": mid, "move": move}

# ---- fight tapes: single use ----
func _tapes_sync() -> int:
	# a quest's tape arrives with its flag, once a save
	if TECH.is_empty(): return 0
	var n := 0
	for fl in TECH.get("tapes", {}).get("quests", {}):
		if _flag_set(str(fl)) and not _tq_r("granted").has(str(fl)):
			var mv := str(TECH["tapes"]["quests"][fl])
			var t := _tq(); t["granted"][str(fl)] = mv; t["tapes"][mv] = int(t["tapes"].get(mv, 0)) + 1; n += 1
			_ev("tape_found", {"move": mv, "flag": str(fl)}); _say("FIGHT TAPE :: %s - the %s reward" % [mv, str(fl)])
	return n

func tapes() -> Dictionary: return _tq_r("tapes")

func tape_why(name: String, move: String) -> String:
	if int(tapes().get(move, 0)) <= 0: return "the club holds no tape of %s" % move
	return _learn_why(name, move)

func use_tape(name: String, move: String) -> Dictionary:
	# between duals: a fight tape teaches its move to one fighter and is spent ("*": the first tape he can learn from)
	if move == "*":
		move = ""
		for mv in tapes():
			if move == "" and tape_why(name, str(mv)) == "": move = str(mv)
	var why := tape_why(name, move) if move != "" else "no tape the club holds teaches %s anything new" % name
	if why != "":
		_ev("tape_refused", {"who": name, "move": move, "why": why}); _say("FIGHT TAPE - %s" % why)
		return {"ok": false, "why": why}
	var t := _tq(); t["tapes"][move] = int(t["tapes"][move]) - 1
	if int(t["tapes"][move]) <= 0: t["tapes"].erase(move)
	_ev("tape_used", {"who": name, "move": move, "left": int(t["tapes"].get(move, 0))})
	_learn(name, move, "tape")
	return {"ok": true, "why": "", "move": move}

# ---- the re-teach: a training slot, the teacher keeps it ----
func reteach_why(teacher: String, learner: String, move: String) -> String:
	if _club_card(teacher).is_empty(): return "%s is not in the club" % teacher
	if teacher == learner: return "%s is the teacher - the re-teach needs another stablemate" % teacher
	if not learned(teacher).has(move): return "%s has not learned %s to pass on (a card's own move and its natives are not re-taught)" % [teacher, move]
	var lw := _learn_why(learner, move)
	if lw != "": return lw
	if FAC.is_empty() or _training().is_empty(): return "the re-teach is a training slot - no training in this build"
	var slots := int(_training().get("slots_per_day", 3))
	if training_used() >= slots: return "the day's %d training slots are used (day %d)" % [slots, int(rewards.get("day", 1))]
	return ""

func reteach(teacher: String, learner: String, move: String) -> Dictionary:
	# between duals, one training slot: a learned non-native passed on ("*" for the teacher and the move: the aid's)
	if teacher == "*" or move == "*":
		var pk := reteach_best(learner)
		teacher = str(pk[0]); move = str(pk[1])
	var why := reteach_why(teacher, learner, move) if teacher != "" else "nobody has a technique to re-teach %s" % learner
	if why != "":
		_ev("reteach_refused", {"teacher": teacher, "who": learner, "move": move, "why": why}); _say("THE RE-TEACH - %s" % why)
		return {"ok": false, "why": why}
	var used := training_used() + 1
	rewards["training"] = {"day": int(rewards.get("day", 1)), "used": used}
	_ev("retaught", {"teacher": teacher, "who": learner, "move": move, "slot": used, "of": int(_training().get("slots_per_day", 3))})
	_learn(learner, move, "taught:" + teacher)
	return {"ok": true, "why": "", "teacher": teacher, "move": move}

func reteach_best(learner: String) -> Array:
	for c in stable:
		var tn := str(c.get("name", ""))
		for mv in learned(tn):
			if reteach_why(tn, learner, str(mv)) == "": return [tn, str(mv)]
	return ["", ""]

func _tech_eight(name: String) -> void:
	# a standing-eight survived: the deed Whitlock's lesson waits on, once
	if TECH.is_empty() or name == "" or _tq_r("eights").has(name): return
	_tq()["eights"][name] = int(rewards.get("day", 1))
	_ev("eight_survived", {"who": name})

func teach_aid(who: String) -> int:
	# the aid between duals, for each dressed card (or the one named): a lesson open, a tape, a buy, a re-teach - one of each at most
	if TECH.is_empty(): return 0
	_tapes_sync()
	var n := 0
	for c in dressed:
		var nm := str(c.get("name", ""))
		if who != "*" and nm != who: continue
		if lessons_open(nm).size() > 0 and bool(lesson("*", nm, "")["ok"]): n += 1
		for mv in tapes().keys():
			if tape_why(nm, str(mv)) == "" and bool(use_tape(nm, str(mv))["ok"]): n += 1; break
		if buy_best(nm) != "" and bool(buy(nm, "*")["ok"]): n += 1
		if str(reteach_best(nm)[0]) != "" and bool(reteach("*", nm, "*")["ok"]): n += 1
	return n

func kit_move(row: String) -> Dictionary:
	# LB + a motion, past his own move: the kit's first move of that family he can cast and pay for
	for mv in P.get("kit", []):
		var m: Dictionary = library.get(str(mv), {})
		if m.size() > 0 and _family_row_matches(str(m["family"]), row) and castable(m) and can_pay(m): return m
	return {}

func kit_pick() -> Dictionary:
	# manager mode's move: his own when he can cast and pay for it (not a WALL), else the kit's first he can
	var own := player_move()
	if own.size() > 0 and str(own["family"]) != "WALL" and castable(own) and can_pay(own): return own
	for mv in P.get("kit", []):
		var m: Dictionary = library.get(str(mv), {})
		if m.size() > 0 and str(m["family"]) != "WALL" and castable(m) and can_pay(m): return m
	return own

func technique_lines(name: String) -> Array:
	# the club's techniques between duals, for one card: his slots and kit, what he knows, the shop's next, the lessons, the tapes
	var out: Array = []
	if TECH.is_empty() or _club_card(name).is_empty(): return out
	var room := _kit_room(name)
	var kit := kit_moves(name)
	out.append("%s L%d: own %s; T0 %s; slots %d of %d; kit %s" % [name, level_of(name), str(_club_card(name).get("hissatsu", "")), (str(room["t0"]) + ("" if t0_open(name) else " (locked to L%d)" % int(TECH.get("t0_level", 5)))) if str(room["t0"]) != "" else ("open" if t0_open(name) else "L%d" % int(TECH.get("t0_level", 5))), int(room["used"]), int(room["slots"]), ", ".join(PackedStringArray(kit)) if kit.size() > 0 else "-"])
	var bb := buy_best(name); var lo := lessons_open(name)
	out.append("[ buy: %s   ] lesson: %s   ' tape: %s   / re-teach: %s" % [("%s (%s, %d HBP)" % [bb, shop_tier_of(bb), int(TECH["shop"]["tiers"][shop_tier_of(bb)]["hbp"])]) if bb != "" else "-", ", ".join(PackedStringArray(lo.map(func(x): return "%s from %s" % [str(x[1]), str(x[0])]))) if lo.size() > 0 else "-", JSON.stringify(tapes()) if tapes().size() > 0 else "-", ("%s from %s" % [str(reteach_best(name)[1]), str(reteach_best(name)[0])]) if str(reteach_best(name)[0]) != "" else "-"])
	return out

static func seed_learned(ledger: Dictionary, l_arg: String) -> Dictionary:
	# `-- learn=RORY:Snowblind+Landslide,PRIYA:Black Ice` -> learned (the overworld's, "seed") and in the kit in that order (the bell
	# checks each against his slots)
	var out := ledger.duplicate(true)
	for part in l_arg.split(",", false):
		var kv := str(part).split(":")
		if kv.size() != 2: continue
		if not out.has("techniques"): out["techniques"] = {}
		for k in ["learned", "kit", "tapes", "granted", "eights"]:
			if not out["techniques"].has(k): out["techniques"][k] = {}
		var nm := str(kv[0]).strip_edges().to_upper()
		for mv in str(kv[1]).split("+", false):
			var m := str(mv).strip_edges()
			if not out["techniques"]["learned"].has(nm): out["techniques"]["learned"][nm] = {}
			out["techniques"]["learned"][nm][m] = "seed"
			if not out["techniques"]["kit"].has(nm): out["techniques"]["kit"][nm] = []
			if not m in out["techniques"]["kit"][nm]: out["techniques"]["kit"][nm].append(m)
	return out

static func seed_tapes(ledger: Dictionary, t_arg: String) -> Dictionary:
	# `-- tapes=Black Ice:1,Portage:2` -> fight tapes the club holds (found, the overworld's)
	var out := ledger.duplicate(true)
	for part in t_arg.split(",", false):
		var kv := str(part).split(":")
		if kv.size() != 2 or not str(kv[1]).strip_edges().is_valid_int(): continue
		if not out.has("techniques"): out["techniques"] = {}
		if not out["techniques"].has("tapes"): out["techniques"]["tapes"] = {}
		out["techniques"]["tapes"][str(kv[0]).strip_edges()] = int(out["techniques"]["tapes"].get(str(kv[0]).strip_edges(), 0)) + int(str(kv[1]).strip_edges())
	return out

# ============================ ACCESSORIES & GEAR (NP_11 s5) ===============
# PAC-094: gear is cosmetic-forward - gloves, wraps, robes, mouthguards, each piece a look and at most one small passive: its kind's
# (gloves the jab, wraps the guard held, a mouthguard the wobble, a robe the walk-out's Tension), never more than the table's cap (3%),
# on the same hook as the board's passive of that key, which always outweighs it. A fighter wears one piece of each kind in the
# accessory slots his rarity opens (C44: 1 / 2 / 3 / 3), set between duals. The club keeps one locker (rewards["gear"]): a piece
# bought twice is two copies. The sources: the HBP shop's three shelves by circuit progress; the circuit's prizes, once, with their
# flags; a blessed house's gift of its colours (C31), once; the festival's prizes for an Exhibition 2v2 won on the boardwalk; and
# signature gear - a named character's identity piece, his alone (no other card wears it), in the locker while he is in the club.
func _gq() -> Dictionary:
	if not rewards.has("gear"): rewards["gear"] = {"owned": {}, "worn": {}, "from": {}, "festival": 0}
	for k in ["owned", "worn", "from"]:
		if not rewards["gear"].has(k): rewards["gear"][k] = {}
	return rewards["gear"]

func _gq_r(k: String) -> Dictionary:
	return rewards.get("gear", {}).get(k, {})

func gear_item(id: String) -> Dictionary:
	# a piece from the table, or a house's gift by rule ("gift:<house>": its colours, the piece by its style)
	if GEAR.is_empty(): return {}
	if GEAR.get("items", {}).has(id): return GEAR["items"][id]
	if id.begins_with("gift:"):
		var h := id.substr(5)
		var st := str(GEAR.get("house_styles", {}).get(h, ""))
		if st == "": return {}
		var hg: Dictionary = GEAR.get("house_gift", {})
		var kind := str(hg.get("by_style", {}).get(st, "wraps"))
		return {"name": str(hg.get("name", "{House} colours - {kind}")).replace("{House}", _house_name(h)).replace("{kind}", kind), "kind": kind, "pct": int(hg.get("pct", 2)),
			"source": "gift", "house": h, "color": str(hg.get("colors", {}).get(kind, "#999999")), "look": str(hg.get("look", "the house's colours"))}
	return {}

func gear_text(id: String) -> String:
	# "Pro Gloves (jab damage +3%)", "Gym Robe (cosmetic)"
	var it := gear_item(id)
	if it.is_empty(): return id
	var kd: Dictionary = GEAR.get("kinds", {}).get(str(it["kind"]), {})
	if int(it.get("pct", 0)) == 0: return "%s (cosmetic)" % str(it["name"])
	return "%s (%s %s%d%%)" % [str(it["name"]), str(kd.get("text", "")), "+" if int(kd.get("dir", 1)) > 0 else "-", int(it["pct"])]

var gear_seen: Array = []           # PAC-094: the pieces the toasts have announced (the locker's own count is the ledger's and the story's)

func _gear_derived() -> Dictionary:
	# the pieces the story puts in the locker, read off the ledgers as they stand (never stored, so a load holds the same): the circuit's
	# prizes with their flags, a signature piece while its owner is in the club, a blessed house's colours
	var out := {}
	if GEAR.is_empty(): return out
	var ids: Array = GEAR.get("items", {}).keys(); ids.sort()
	for id in ids:
		var it: Dictionary = GEAR["items"][id]
		match str(it.get("source", "")):
			"prize":
				if _flag_set(str(it.get("flag", ""))): out[str(id)] = "the circuit's prize (%s)" % str(it["flag"])
			"signature":
				var own := str(it.get("owner", ""))
				if not _club_card(own).is_empty() and (str(it.get("flag", "")) == "" or _flag_set(str(it["flag"]))): out[str(id)] = "%s's own - signature gear, his alone" % own
	var hs: Array = GEAR.get("house_styles", {}).keys(); hs.sort()
	for h in hs:
		if rewards.get("houses", {}).has(str(h)) and house_blessed(str(h)): out["gift:" + str(h)] = "House %s's gift, its blessing given (NP_07 s4)" % _house_name(str(h))
	return out

func gear_owned() -> Dictionary:
	# the locker: what the club bought or won (the ledger) and what the story put there (derived)
	var out: Dictionary = _gq_r("owned").duplicate()
	var dv := _gear_derived()
	for id in dv: out[id] = int(out.get(id, 0)) + 1
	return out

func gear_from(id: String) -> String:
	var dv := _gear_derived()
	return str(dv[id]) if dv.has(id) else str(_gq_r("from").get(id, ""))

func _gear_announce(id: String, why: String) -> void:
	if id in gear_seen: return
	gear_seen.append(id)
	_ev("gear_won", {"id": id, "name": str(gear_item(id).get("name", id)), "why": why})
	_say("GEAR :: %s - %s" % [gear_text(id), why])

func _gear_sync() -> int:
	# the toasts for what the story has put in the locker since the last look (at setup and every new dual)
	if GEAR.is_empty(): return 0
	var n := 0
	var dv := _gear_derived()
	for id in dv:
		if not (id in gear_seen): _gear_announce(str(id), str(dv[id])); n += 1
	return n

func gear_festival() -> String:
	# an Exhibition 2v2 won on the festival's boardwalk: the next prize not yet won
	if GEAR.is_empty(): return ""
	for id in GEAR.get("festival", {}).get("order", []):
		if not gear_owned().has(str(id)):
			var g := _gq(); g["festival"] = int(g.get("festival", 0)) + 1
			g["owned"][str(id)] = 1; g["from"][str(id)] = "the festival's prize - the Exhibition 2v2 won on the boardwalk"
			_gear_announce(str(id), str(g["from"][str(id)]))
			return str(id)
	return ""

func gear_free(id: String) -> int:
	# copies in the locker nobody is wearing
	var n := int(gear_owned().get(id, 0))
	for nm in _gq_r("worn"):
		for w in _gq_r("worn")[nm]:
			if str(w) == id: n -= 1
	return n

func gear_worn(name: String) -> Array:
	# what he walks out in: the ledger's pieces he may wear, one of each kind, in his slots
	var out: Array = []; var kinds: Array = []
	var cap := accessory_slots(name) if not GROW.is_empty() else 0
	for id in _gq_r("worn").get(name, []):
		var it := gear_item(str(id))
		if it.is_empty() or str(it["kind"]) in kinds or out.size() >= cap: continue
		if str(it.get("owner", "")) != "" and str(it["owner"]) != name: continue
		if int(gear_owned().get(str(id), 0)) <= 0: continue
		out.append(str(id)); kinds.append(str(it["kind"]))
	return out

func gear_fx(name: String) -> Dictionary:
	# the multipliers his pieces put on their kinds' hooks
	var fx := {}
	for id in gear_worn(name):
		var it := gear_item(id); var kd: Dictionary = GEAR.get("kinds", {}).get(str(it["kind"]), {})
		if int(it.get("pct", 0)) == 0: continue
		var k := str(kd.get("key", ""))
		fx[k] = float(fx.get(k, 1.0)) * (1.0 + float(int(kd.get("dir", 1))) * float(mini(int(it["pct"]), int(GEAR.get("cap_pct", 3)))) / 100.0)
	return fx

func _gear_mult(F: Dictionary, key: String) -> float:
	return float(F.get("gear_fx", {}).get(key, 1.0))

func gear_why(name: String, id: String) -> String:
	# why he cannot put this piece on now ("" when he can)
	if GEAR.is_empty(): return "no gear in this build"
	var bw := _between("the gear is set")
	if bw != "": return bw
	if _club_card(name).is_empty(): return "%s is not in the club" % name
	var it := gear_item(id)
	if it.is_empty(): return "no gear '%s'" % id
	if str(it.get("owner", "")) != "" and str(it["owner"]) != name: return "%s is %s's - signature gear, his alone" % [str(it["name"]), str(it["owner"])]
	var own_n := int(gear_owned().get(id, 0))
	if own_n <= 0: return "the club holds no %s" % str(it["name"])
	var worn := gear_worn(name)
	if id in worn: return "%s wears %s already" % [name, str(it["name"])]
	for w in worn:
		if str(gear_item(str(w))["kind"]) == str(it["kind"]): return "%s wears %s already (%s)" % [name, str(it["kind"]), str(gear_item(str(w))["name"])]
	if gear_free(id) <= 0: return "the club's %s %s all worn (%d of %d)" % [str(it["name"]), "are" if str(it["name"]).ends_with("s") else "is", own_n, own_n]
	return _gear_slots_why(name)

func _gear_slots_why(name: String) -> String:
	# his slots full ("" while one is open): the rarity that opens the next, if one does
	var worn := gear_worn(name); var cap := accessory_slots(name)
	if worn.size() < cap: return ""
	var nx := rarity_name(mini(4, rarity_of(name) + 1)) if rarity_of(name) < 4 and cap < 3 else ""
	return "%s's accessory slots are full (%d of %d)%s" % [name, worn.size(), cap, (" - %s opens the next" % nx) if nx != "" else ""]

func gear_best(name: String) -> String:
	# the aid's pick: his own signature first, then the strongest free piece of a kind he does not wear
	var best := ""; var bp := -1
	var ids: Array = gear_owned().keys(); ids.sort()
	for id in ids:
		if gear_why(name, str(id)) != "": continue
		var it := gear_item(str(id))
		var p := 100 if str(it.get("owner", "")) == name else int(it.get("pct", 0))
		if p > bp: best = str(id); bp = p
	return best

func wear(name: String, id: String) -> Dictionary:
	# between duals: a piece from the locker onto his card ("*": the aid's pick)
	if id == "*": id = gear_best(name)
	var why := gear_why(name, id) if id != "" else (_gear_slots_why(name) if _gear_slots_why(name) != "" else "the locker holds nothing %s can wear (%d of %d slots)" % [name, gear_worn(name).size(), accessory_slots(name)])
	if why != "":
		_ev("gear_refused", {"who": name, "id": id, "why": why}); _say("GEAR - " + why)
		return {"ok": false, "why": why}
	var g := _gq()
	var w: Array = gear_worn(name); w.append(id); g["worn"][name] = w
	_ev("gear_worn", {"who": name, "id": id, "name": str(gear_item(id)["name"])})
	_say("GEAR :: %s wears %s" % [name, gear_text(id)])
	return {"ok": true, "why": "", "id": id}

func take_off(name: String, id: String) -> Dictionary:
	# between duals: a piece back in the locker ("*": the last he put on)
	var bw := _between("the gear is set")
	var w: Array = gear_worn(name)
	if id == "*" and w.size() > 0: id = str(w[-1])
	var why := bw if bw != "" else ("%s wears no %s" % [name, str(gear_item(id).get("name", "gear"))] if not (id in w) else "")
	if why != "":
		_ev("gear_refused", {"who": name, "id": id, "why": why}); _say("GEAR - " + why)
		return {"ok": false, "why": why}
	w.erase(id); _gq()["worn"][name] = w
	_ev("gear_off", {"who": name, "id": id, "name": str(gear_item(id)["name"])})
	_say("GEAR :: %s takes off %s (back in the locker)" % [name, str(gear_item(id)["name"])])
	return {"ok": true, "why": "", "id": id}

func gear_shelf_open(t: String) -> bool:
	return shelf_open_by("gear", t) != "closed"                                                           # PAC-103: its flag, or DOWNTOWN's rep

func gear_buy_why(id: String) -> String:
	var it := gear_item(id)
	if it.is_empty(): return "no gear '%s'" % id
	if str(it.get("source", "")) != "shop": return "%s is not sold - %s" % [str(it["name"]), {"prize": "a circuit prize", "signature": "signature gear, never sold", "festival": "a festival prize", "gift": "a house's gift"}.get(str(it.get("source", "")), "not in the shop")]
	var td: Dictionary = GEAR.get("shop", {}).get("tiers", {}).get(str(it.get("shelf", "")), {})
	if not gear_shelf_open(str(it.get("shelf", ""))): return "the gear shop's %s shelf opens with %s (%s)%s" % [str(it["shelf"]), str(td.get("text", "")), str(td.get("flag", "")), shelf_rep_clause("gear", str(it["shelf"]))]
	if int(rewards.get("hbp", 0)) < int(it.get("hbp", 0)): return "%s costs %d HBP (the ledger holds %d)" % [str(it["name"]), int(it.get("hbp", 0)), int(rewards.get("hbp", 0))]
	return ""

func gear_buy_best(name: String) -> String:
	# the aid's pick for a card: the strongest open piece the ledger affords of a kind he does not wear, the cheaper on a tie
	var worn_k: Array = gear_worn(name).map(func(x): return str(gear_item(str(x))["kind"]))
	var best := ""; var bk := [-1, 0]
	var ids: Array = GEAR.get("items", {}).keys(); ids.sort()
	for id in ids:
		var it: Dictionary = GEAR["items"][id]
		if gear_buy_why(str(id)) != "" or str(it["kind"]) in worn_k or gear_free(str(id)) > 0: continue
		var k := [int(it.get("pct", 0)), -int(it.get("hbp", 0))]
		if k[0] > bk[0] or (k[0] == bk[0] and k[1] > bk[1]): best = str(id); bk = k
	return best

func buy_gear(id: String, for_name: String = "") -> Dictionary:
	# between duals: a piece from the gear shop into the locker, paid in HBP ("*": the aid's pick for the card named)
	var bw := _between("the gear shop is visited")
	if id == "*": id = gear_buy_best(for_name)
	var why := bw if bw != "" else (gear_buy_why(id) if id != "" else "the gear shop has nothing %s would wear that the ledger affords (%d HBP)" % [for_name, int(rewards.get("hbp", 0))])
	if why != "":
		_ev("gear_refused", {"who": for_name, "id": id, "why": why}); _say("GEAR SHOP - " + why)
		return {"ok": false, "why": why}
	var it := gear_item(id)
	rewards["hbp"] = int(rewards.get("hbp", 0)) - int(it.get("hbp", 0))
	var g := _gq(); g["owned"][id] = int(g["owned"].get(id, 0)) + 1; g["from"][id] = "the gear shop (%s, %d HBP)" % [str(it["shelf"]), int(it["hbp"])]
	_ev("gear_bought", {"id": id, "name": str(it["name"]), "hbp": int(it["hbp"]), "left": int(rewards["hbp"])})
	_say("GEAR SHOP :: %s for %d HBP (%d left)" % [gear_text(id), int(it["hbp"]), int(rewards["hbp"])])
	return {"ok": true, "why": "", "id": id}

func gear_lines(name: String) -> Array:
	# DUAL OVER for one card: what he wears in his slots, the locker, the shop's next
	var out: Array = []
	if GEAR.is_empty() or _club_card(name).is_empty(): return out
	var w := gear_worn(name)
	out.append("%s (%s, %d slot%s): %s" % [name, rarity_name(rarity_of(name)), accessory_slots(name), "" if accessory_slots(name) == 1 else "s", ("wears " + ", ".join(PackedStringArray(w.map(func(x): return gear_text(str(x)))))) if w.size() > 0 else "wears nothing"])
	var lk: Array = []
	var ids: Array = gear_owned().keys(); ids.sort()
	for id in ids:
		var fr := gear_free(str(id))
		if fr > 0: lk.append("%s%s%s" % [str(gear_item(str(id)).get("name", id)), (" x%d" % fr) if fr > 1 else "", (" (%s's)" % str(gear_item(str(id))["owner"])) if str(gear_item(str(id)).get("owner", "")) != "" else ""])
	var bb := gear_buy_best(name); var wb := gear_best(name)
	out.append("\\ buy: %s   , wear: %s   the locker: %s" % [("%s (%s, %d HBP)" % [gear_text(bb), str(gear_item(bb)["shelf"]), int(gear_item(bb)["hbp"])]) if bb != "" else "-", gear_text(wb) if wb != "" else "-", ", ".join(PackedStringArray(lk)) if lk.size() > 0 else "empty"])
	return out

func gear_line() -> String:
	# the matchup card: what the fighter out walks out in
	var w: Array = P.get("gear", [])
	if w.is_empty(): return ""
	return "GEAR: %s - %s" % [pname(), ", ".join(PackedStringArray(w.map(func(x): return gear_text(str(x)))))]

func gear_aid(who: String) -> int:
	# the aid between duals, for each dressed card (or the one named): what fits from the locker (his own signature first), then with a
	# slot still open the shop's pick when the ledger affords it
	if GEAR.is_empty(): return 0
	_gear_sync()
	var n := 0
	for c in dressed:
		var nm := str(c.get("name", ""))
		if who != "*" and nm != who: continue
		while gear_best(nm) != "" and bool(wear(nm, "*")["ok"]): n += 1
		if gear_worn(nm).size() < accessory_slots(nm) and gear_buy_best(nm) != "" and bool(buy_gear("*", nm)["ok"]):
			n += 1
			while gear_best(nm) != "" and bool(wear(nm, "*")["ok"]): n += 1
	return n

static func seed_gear(ledger: Dictionary, g_arg: String) -> Dictionary:
	# `-- gear=tape_wraps,gym_robe,RORY:tape_wraps` -> pieces in the locker (bare ids) and worn (NAME:id, owned if not already)
	var out := ledger.duplicate(true)
	for part in g_arg.split(",", false):
		if not out.has("gear"): out["gear"] = {"owned": {}, "worn": {}, "from": {}, "festival": 0}
		var g: Dictionary = out["gear"]
		var kv := str(part).split(":")
		var id := str(kv[-1]).strip_edges()
		if kv.size() == 1 or int(g["owned"].get(id, 0)) == 0:
			g["owned"][id] = int(g["owned"].get(id, 0)) + 1; g["from"][id] = "seed"
		if kv.size() == 2:
			var nm := str(kv[0]).strip_edges()
			if not g["worn"].has(nm): g["worn"][nm] = []
			g["worn"][nm].append(id)
	return out

# ============================ THE MIRROR SPAR (NP_02 s2.2) ================
# PAC-093: "fight a copy of your own fighter - the adaptation tracker turned into content". The tracker (C7) reads a fighter's punches
# inside one segment and forgets them; its record (rewards["habits"], per fighter, across every dual, scrap and spar) keeps what it saw:
# the punches by row, the feints, every two- and three-token sequence thrown, the sequences it read (flagged), the counter windows his
# defense opened and the punch he threw into them. The copy is a pattern (the boss agent runs patterns): his most-thrown sequences as
# its strings and their shares as its SELECT, the Style's pieces filling what the record cannot (C24). Its tracker opens already reading
# his most-read sequences - C7's read, defense only (D3) - and fades like any read when he stops throwing them. When its read makes him
# miss it counters as he does: his most-thrown counter punch, at his rate. A mirror books no Pattern Intel: the pattern is his own.
var mirror_n := 0                   # PAC-093: the demo aid's rotation through the dressed cards with a record
var htokens: Array = []             # PAC-093: the record's own window - the tracker's tokens with a feinted punch's start replaced by its feint

func _mirror_rules() -> Dictionary:
	return BOUTS.get("spar", {}).get("mirror", {})

static func _habit_blank() -> Dictionary:
	return {"punches": 0, "feints": 0, "rows": {}, "grams": {}, "reads": {}, "chances": 0, "counters": {}}

func _habits_w(name: String) -> Dictionary:
	if not rewards.has("habits"): rewards["habits"] = {}
	if not rewards["habits"].has(name): rewards["habits"][name] = _habit_blank()
	return rewards["habits"][name]

func habits_of(name: String) -> Dictionary:
	return rewards.get("habits", {}).get(name, {})

func _habit_track(tok: String) -> void:
	# the tracker's token, kept for the fighter out: the row (or the feint) and the two sequences it closes. A feinted punch was counted
	# at its start; as the tracker pops that start for the feint's token (_feint), the record takes it back and keeps the feint
	if _mirror_rules().is_empty() or lineup.is_empty(): return
	var h := _habits_w(pname())
	if tok.begins_with("F_") and htokens.size() > 0 and str(htokens[-1]) == tok.substr(2):
		var row := tok.substr(2)
		h["punches"] = int(h["punches"]) - 1; h["rows"][row] = int(h["rows"].get(row, 1)) - 1
		if int(h["rows"][row]) <= 0: h["rows"].erase(row)
		for size in [2, 3]:
			if htokens.size() >= size:
				var g0 := ",".join(htokens.slice(htokens.size() - size))
				h["grams"][g0] = int(h["grams"].get(g0, 1)) - 1
				if int(h["grams"][g0]) <= 0: h["grams"].erase(g0)
		htokens[-1] = tok
	else:
		htokens.append(tok)
		if htokens.size() > int(T["adaptation_tracker"]["window_tokens"]): htokens.pop_front()
		if not tok.begins_with("F_"): h["punches"] = int(h["punches"]) + 1; h["rows"][tok] = int(h["rows"].get(tok, 0)) + 1
	if tok.begins_with("F_"): h["feints"] = int(h["feints"]) + 1
	for size in [2, 3]:
		if htokens.size() >= size:
			var g := ",".join(htokens.slice(htokens.size() - size))
			h["grams"][g] = int(h["grams"].get(g, 0)) + 1

func _habit_read(gram: String) -> void:
	# the tracker read him on this sequence (C7's flag)
	if _mirror_rules().is_empty() or lineup.is_empty(): return
	var h := _habits_w(pname()); h["reads"][gram] = int(h["reads"].get(gram, 0)) + 1

func _habit_chance() -> void:
	# his defense opened a counter window (a slip, a duck, a lean, a weave, a perfect block)
	if _mirror_rules().is_empty() or lineup.is_empty() or mode != "FIGHT": return
	var h := _habits_w(pname()); h["chances"] = int(h["chances"]) + 1

func _habit_counter(row: String) -> void:
	# ...and he threw this punch into it
	if _mirror_rules().is_empty() or lineup.is_empty(): return
	var h := _habits_w(pname()); h["counters"][row] = int(h["counters"].get(row, 0)) + 1

func _seq_words(g: String) -> Array:
	# a sequence as the boss grammar's actions and the words the lines use (a feint is a pause where the punch was)
	var mr := _mirror_rules(); var rv: Dictionary = mr.get("row_verbs", {})
	var acts: Array = []; var words: Array = []
	for tk in g.split(","):
		var t := str(tk)
		if t.begins_with("F_"):
			acts.append(str(mr.get("feint", "DELAY(200)"))); words.append("feint " + str(rv.get(t.substr(2), t.substr(2))))
		else:
			acts.append(str(rv.get(t, "JAB"))); words.append(str(rv.get(t, t)))
	return [acts, " > ".join(PackedStringArray(words))]

func habit_copy(name: String) -> Dictionary:
	# the copy his record makes: its strings (his sequences thrown at least the tracker's count, ranked by thrown x length, one inside a
	# string already taken skipped, as many as the copy's tier holds), the sequences its tracker opens reading (by reads, the tier the reads capped), his counter (the punch
	# he throws most into a window his defense opened, at his rate, once he has countered enough to have one)
	var mr := _mirror_rules(); var h := habits_of(name)
	var out := {"strings": [], "reads": [], "counter": [], "punches": int(h.get("punches", 0))}
	if mr.is_empty() or h.is_empty(): return out
	var cands: Array = []
	for g in h.get("grams", {}):
		var toks: Array = Array(str(g).split(","))
		var n := int(h["grams"][g])
		if n < int(mr.get("min_count", 3)) or toks.filter(func(x): return not str(x).begins_with("F_")).is_empty(): continue
		cands.append([n * toks.size(), toks.size(), str(g), n])
	cands.sort_custom(func(a, b): return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and (int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and str(a[2]) < str(b[2])))))
	var taken: Array = []
	var cap := mini(int(mr.get("strings_max", 3)), int(PIECES.get("rules", {}).get("strings_by_tier", {}).get(str(clampi(rarity_of(name), 1, 3)), 3)))   # the copy's tier (his rarity, C44's mirror) sets how many
	for c in cands:
		if taken.size() >= cap: break
		var inside := false
		for tk in taken:
			if ("," + str(tk[2]) + ",").contains("," + str(c[2]) + ","): inside = true
		if not inside: taken.append(c)
	for c in taken:
		var sw := _seq_words(str(c[2]))
		out["strings"].append({"seq": str(c[2]), "label": str(mr.get("label", "HABIT {seq}")).replace("{seq}", str(sw[1])), "actions": sw[0], "n": int(c[0]), "thrown": int(c[3])})
	var rl: Array = []
	for g in h.get("reads", {}): rl.append([int(h["reads"][g]), str(g)])
	rl.sort_custom(func(a, b): return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and str(a[1]) < str(b[1])))
	for r in rl.slice(0, int(mr.get("read_seed", 3))): out["reads"].append([str(r[1]), mini(int(mr.get("read_tier_max", 3)), int(r[0]))])
	var ct := 0; var best := ""; var bn := 0
	var ck: Array = h.get("counters", {}).keys(); ck.sort()
	for r in ck:
		ct += int(h["counters"][r])
		if int(h["counters"][r]) > bn: best = str(r); bn = int(h["counters"][r])
	if ct >= int(mr.get("counter_min", 2)) and best != "": out["counter"] = [best, snappedf(minf(1.0, float(ct) / maxf(1.0, float(h.get("chances", 0)))), 0.01)]
	return out

func _mirror_bell() -> void:
	# the mirror at the bell: his tracker reading your most-read sequences, his counter armed
	var mc: Dictionary = bout.get("card", {})
	for rd in mc.get("mirror_reads", []): flags[str(rd[0])] = [int(rd[1]), 0]
	var cn: Array = mc.get("mirror_counter", [])
	B["mirror"] = {"of": str(mc.get("mirror_of", "")), "counter": str(cn[0]) if cn.size() > 1 else "", "counter_p": float(cn[1]) if cn.size() > 1 else 0.0, "counters": 0}
	var hs: Array = []
	for k in pattern.get("strings", {}):
		if str(pattern["strings"][k].get("piece", "")) == "habit": hs.append(str(pattern["strings"][k]["label"]))
	_ev("mirror", {"of": str(mc.get("mirror_of", "")), "habits": hs, "reads": mc.get("mirror_reads", []).duplicate(true), "counter": cn.duplicate(), "learned_from": int(mc.get("learned_from", 0))})
	_say("THE MIRROR :: %s" % mirror_line())

func _mirror_counter() -> void:
	# his read made you miss: he answers as you do - your counter punch, at your rate
	var mc: Dictionary = B.get("mirror", {})
	if str(mc.get("counter", "")) == "" or not (bstate in ["IDLE", "RECOVER"]) or not cast.is_empty() or not clinch.is_empty(): return
	if rng.randf() >= float(mc["counter_p"]): return
	mc["counters"] = int(mc["counters"]) + 1
	bqueue.push_front({"kind": "punch", "row": str(mc["counter"]), "mult": float(_mirror_rules().get("counter_mult", 1.3)), "body": false})
	bstate = "ACTING"; btimer = ms(100)
	var rv: Dictionary = _mirror_rules().get("row_verbs", {})
	_ev("mirror_counter", {"who": boss_label, "row": str(mc["counter"]), "of": str(mc["of"])})
	_say("YOUR COUNTER - %s answers the miss with your %s" % [boss_label, str(rv.get(str(mc["counter"]), mc["counter"]))])

func mirror_line() -> String:
	# the matchup card against a mirror: what it learned from you, what it reads, how it answers
	var mc: Dictionary = B.get("mirror", {})
	if mc.is_empty(): return ""
	var card: Dictionary = bout.get("card", {})
	var hs: Array = []
	var ws: Dictionary = pattern.get("select", {}).get("weights", {})
	var tot := 0
	for k in ws: tot += int(ws[k])
	for k in pattern.get("strings", {}):
		if str(pattern["strings"][k].get("piece", "")) == "habit": hs.append("%s (%d%%)" % [str(pattern["strings"][k]["label"]), int(round(100.0 * float(ws.get(k, 0)) / maxf(1.0, float(tot))))])
	if hs.is_empty(): return "MIRROR: %s has no record of %s yet - the Style's strings (every bout he fights teaches it)" % [boss_label, str(mc["of"])]
	var rd: Array = card.get("mirror_reads", []).map(func(r): return "%s (%d)" % [str(_seq_words(str(r[0]))[1]), int(r[1])])
	var rv: Dictionary = _mirror_rules().get("row_verbs", {})
	return "MIRROR: %s learned from %d punches - throws %s; reads %s from the bell; %s" % [boss_label, int(card.get("learned_from", 0)), ", ".join(PackedStringArray(hs)),
		", ".join(PackedStringArray(rd)) if rd.size() > 0 else "nothing", ("counters with your %s (%d%%)" % [str(rv.get(str(mc["counter"]), mc["counter"])), int(round(100.0 * float(mc["counter_p"])))]) if str(mc["counter"]) != "" else "no counter of yours to copy"]

func habits_line(name: String) -> String:
	# DUAL OVER: one fighter's record, and the copy it would make
	var h := habits_of(name)
	if h.is_empty() or int(h.get("punches", 0)) == 0: return "%s: no record yet - the tracker keeps what he throws" % name
	var rows: Array = h.get("rows", {}).keys()
	rows.sort_custom(func(a, b): return int(h["rows"][a]) > int(h["rows"][b]) or (int(h["rows"][a]) == int(h["rows"][b]) and str(a) < str(b)))
	var rv: Dictionary = _mirror_rules().get("row_verbs", {})
	var top: Array = rows.slice(0, 3).map(func(r): return "%s %d%%" % [str(rv.get(str(r), r)), int(round(100.0 * float(h["rows"][r]) / float(h["punches"])))])
	var hc := habit_copy(name)
	var cs: Array = hc["strings"].map(func(s): return str(s["label"]))
	return "%s: %d punches, %d feints - %s; the copy throws %s%s" % [name, int(h["punches"]), int(h["feints"]), ", ".join(PackedStringArray(top)), ", ".join(PackedStringArray(cs)) if cs.size() > 0 else "the Style's strings (no sequence thrown %d times yet)" % int(_mirror_rules().get("min_count", 3)),
		("; counters with %s (%d%%)" % [str(rv.get(str(hc["counter"][0]), hc["counter"][0])), int(round(100.0 * float(hc["counter"][1])))]) if hc["counter"].size() > 1 else ""]

func mirror_aid(who: String) -> bool:
	# the aid between duals: a mirror spar (the lab's flag) for the next dressed card with a record, then back to the dual
	if mode != "OVER": return false
	if bout.size() > 0:
		if str(bout.get("card", {}).get("mirror_of", "")) == "": return false
		end_bout(); return true
	var pick := who
	if who == "*":
		var have: Array = []
		for c in lineup:
			if habit_copy(str(c["name"]))["strings"].size() > 0: have.append(str(c["name"]))
		if have.is_empty(): return false
		pick = str(have[mirror_n % have.size()]); mirror_n += 1
	return start_spar(_first_boss, ["mirror"], {}, "", "", {"fighter": pick})

static func seed_habits(ledger: Dictionary, h_arg: String) -> Dictionary:
	# `-- habits=RORY:L_STRAIGHT+L_STRAIGHT+R_STRAIGHT*8,RORY:counter=R_HOOK*4/6` -> the tracker's record (a sequence thrown and read N
	# times, its punches counted; counters N in M windows)
	var out := ledger.duplicate(true)
	for part in h_arg.split(",", false):
		var kv := str(part).split(":", true, 1)
		if kv.size() != 2: continue
		var nm := str(kv[0]).strip_edges(); var body := str(kv[1]).strip_edges()
		if not out.has("habits"): out["habits"] = {}
		if not out["habits"].has(nm): out["habits"][nm] = _habit_blank()
		var h: Dictionary = out["habits"][nm]
		if body.begins_with("counter="):
			var cv := body.substr(8).split("*")
			if cv.size() != 2: continue
			var nn := str(cv[1]).split("/")
			h["counters"][str(cv[0])] = int(h["counters"].get(str(cv[0]), 0)) + int(nn[0])
			h["chances"] = int(h["chances"]) + int(nn[1] if nn.size() > 1 else nn[0])
			continue
		var sv := body.split("*")
		var n := int(sv[1]) if sv.size() > 1 else 1
		var toks := str(sv[0]).split("+")
		var g := ",".join(toks)
		h["grams"][g] = int(h["grams"].get(g, 0)) + n
		h["reads"][g] = int(h["reads"].get(g, 0)) + n
		for tk in toks:
			if str(tk).begins_with("F_"): h["feints"] = int(h["feints"]) + n
			else:
				h["punches"] = int(h["punches"]) + n; h["rows"][str(tk)] = int(h["rows"].get(str(tk), 0)) + n
	return out

# ============================ THE SAVE (NP_11 s9): a dual in flight ========
const DUAL_SCHEMA := "DualState/NP_11-s9/v1.0"
const SNAP_SKIP := ["T", "patterns", "boss_names", "rng", "library", "TAC", "AFF", "FEUDS", "COACHES", "FMT", "BOUTS", "SCRAPS", "PI", "REMIX", "ECO", "PIECES", "NEUTRAL", "TALK", "FORMATION", "STAFF", "RECRUITS", "STRINGS", "HOUSES", "GYMWALL", "TRANS", "HYB", "FAC", "GROW", "TECH", "ACAD", "GEAR"]   # the content tables (hot-reloadable data, never state) and the RNG object (its seed and state ride by themselves)

func content_stamp() -> int:
	# the content this sim was loaded with, as one number: a snapshot restores only under the same data
	return hash(var_to_bytes([T, patterns, library, TAC, AFF, FEUDS, COACHES, FMT, BOUTS, SCRAPS, PI, REMIX, ECO, PIECES, NEUTRAL, TALK, FORMATION, STAFF, RECRUITS, STRINGS, HOUSES, GYMWALL, TRANS, HYB, FAC, GROW, TECH, ACAD, GEAR]))

func state_vars() -> Array:
	# every script variable that is state (declaration order)
	var out: Array = []
	for p in get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) and not (str(p["name"]) in SNAP_SKIP): out.append(str(p["name"]))
	return out

func vars_signature() -> int: return hash(state_vars())

func dual_state() -> Dictionary:
	# NP_11 s9's DualState, read from the sim: the schema's fields, readable (the overworld's view; the exact restore is the blob beneath)
	var names := func(arr: Array) -> Array:
		var o: Array = []
		for f in arr: o.append(str(f["name"]) if f is Dictionary else str(f))
		return o
	var fought: Array = names.call(lineup)
	var sealed: Array = sealed_p.duplicate() if sealed_p.size() > 0 else fought.duplicate(); var bsealed: Array = sealed_b.duplicate() if sealed_b.size() > 0 else blineup.duplicate()   # PAC-073: the seal is the order at the bell; the revealed are who went out
	return {"segment_idx": seg_idx + 1, "mode": mode, "clock_t": clock_t, "clock_s": snappedf(float(clock_t) / float(TICK_HZ), 0.01), "r6": r6,
		"score": {"drops_h": drops_p, "drops_a": drops_b, "points_h": score_p, "points_a": score_b, "ep_h": ep_p, "ep_a": ep_b, "segment_wins": [seg_wins_p, seg_wins_b], "counters": [counters_p, counters_b]},
		"tension": {"home": tension, "away": btension},
		"relay": {"charged": charged, "chain": relay_chain, "away_charged": bcharged, "away_chain": brelay_chain},
		"lineups": {"sealed": sealed, "revealed": fought.slice(0, mini(seg_idx + 1, fought.size())), "reserves": names.call(reserves), "away_sealed": bsealed, "away_revealed": blineup.slice(0, mini(seg_idx + 1, blineup.size())), "away_reserves": breserves.duplicate(), "board": str(board.get("archetype", board.get("name", "")))},
		"corner_budget": {"t": int(corner.get("t", 0)), "actions_left": int(corner.get("actions_left", 0))},
		"tactics_cooldowns": tactic_cd.duplicate(true), "supers_used": {"home": super_used, "away": bsuper_used}, "staff_charges": staff_charges.duplicate(true),
		"zone_states": {"home": zone(P["pos"]), "away": zone(B["pos"])},
		"transform_log": {"t3_unlocked": t3_unlocked, "casts_this_segment": hiss_casts_seg, "duo": str(duo.get("move", {}).get("name", "")), "zone": tform.duplicate(), "comedown": {"who": str(comedown.get("who", "")), "t": int(comedown.get("t", 0))}, "transformed": transformed.duplicate(),
			"away": {"gathering": int(btsurge.get("t", 0)), "tier": str(btform.get("tier", "")), "t": int(btform.get("t", 0)), "weathered": int(btform.get("weathered", 0)), "comedown_t": int(bcomedown.get("t", 0)), "transformed": btransformed.duplicate(), "clash": mclash.size() > 0}},   # PAC-086: his side
		"adaptation": {"window": tokens.duplicate(), "flags": flags.duplicate(true)},
		"crowd_heat": {"hostile_home": player_lock, "hostile_away": enemy_lock, "heat": crowd_heat}, "staff": staff_dressed().duplicate(),
		"injuries": [],
		"condition": {"home": condition.duplicate(true), "away": bcondition.duplicate(true)},
		"bout": {"kind": str(bout.get("kind", "")), "objective": str(bout.get("objective", ""))},
		"opponent": boss_name, "format": str(fmt.get("id", ""))}

func snapshot() -> Dictionary:
	# the dual in flight: the DualState fields readable, and beneath them every state variable of the sim as one typed blob
	# (var_to_bytes: ints stay ints, floats keep every bit, Vector2s survive), so a restore lands on the same state hash and
	# a log continued from it hashes as the unbroken run does. Side-effect free.
	var st := {}
	for n in state_vars(): st[n] = get(n)
	st["__rng"] = {"seed": rng.seed, "state": rng.state}
	var d := dual_state()
	d["schema"] = DUAL_SCHEMA; d["content"] = content_stamp(); d["vars"] = vars_signature(); d["tick"] = tick; d["hash"] = hash_state()
	d["state"] = Marshalls.raw_to_base64(var_to_bytes(st))
	return d

func restore(snap: Dictionary) -> Dictionary:
	# the DualState back into a sim built under the same content; refuses another schema, other data, another build of the sim
	if str(snap.get("schema", "")) != DUAL_SCHEMA: return {"ok": false, "why": "schema %s is not readable (this build writes %s)" % [str(snap.get("schema", "")), DUAL_SCHEMA]}
	if int(snap.get("content", 0)) != content_stamp(): return {"ok": false, "why": "made under other content (stamp %d, this data %d)" % [int(snap.get("content", 0)), content_stamp()]}
	if int(snap.get("vars", 0)) != vars_signature(): return {"ok": false, "why": "made by another build of the sim (its state variables differ)"}
	var st = bytes_to_var(Marshalls.base64_to_raw(str(snap.get("state", ""))))
	if not st is Dictionary or not st.has("__rng"): return {"ok": false, "why": "the state blob does not decode"}
	for n in state_vars():
		if st.has(n): set(n, st[n])
	rng.seed = int(st["__rng"]["seed"]); rng.state = int(st["__rng"]["state"])
	return {"ok": true, "why": "", "tick": tick, "hash": hash_state(), "same": hash_state() == int(snap.get("hash", 0))}

static func parse_kizuna_arg(s: String) -> Dictionary:
	# `-- kizuna=RORY+PRIYA:30,JUNE+MARCUS:10` -> a reward ledger with those pairs
	var out := {"xp": {}, "spirits": 0, "prestige": 0, "hbp": 0, "kizuna": {}, "kizuna_day": {}, "log": [], "day": 1}
	for part in s.split(","):
		if not ":" in part or not "+" in part: continue
		var kv := part.split(":"); var ab := kv[0].split("+")
		if ab.size() != 2: continue
		out["kizuna"][pair_key(str(ab[0]).strip_edges(), str(ab[1]).strip_edges())] = int(kv[1])
	return out

# ============================ THE NEUTRAL GAME (NP_04 s2 IDLE) ============
static func idle_verb(line: String) -> String:
	return line.split("@")[0].split("(")[0].strip_edges()

static func idle_arg(line: String) -> float:
	# "taunt@8s" -> 8.0; a line with no clock -> 0
	if not "@" in line: return 0.0
	return float(line.split("@")[1].replace("s", ""))

func _neutral_profile(pat: Dictionary) -> Dictionary:
	# the IDLE lines -> one profile: the move verb's kind and numbers, the guard, the clocks, the flags; no lines -> the default (the shared approach)
	var dv: Dictionary = NEUTRAL.get("default", {})
	var pr := {"kind": str(dv.get("kind", "advance")), "approach_mps": float(dv.get("approach_mps", 1.2)), "lead_s": float(dv.get("lead_s", 0.35)), "range_m": float(dv.get("range_m", ENGAGE_DIST)),
		"guard": dv.get("guard", {"head": 0.35, "body": 0.35}).duplicate(), "taunt_s": 0.0, "tempo_s": 0.0, "audio": "on", "cut_ring": false, "bell": false, "unmasked": false, "verbs": [], "authored": false}
	for il in pat.get("idle", []):
		var verb := idle_verb(str(il))
		var v: Dictionary = NEUTRAL.get("verbs", {}).get(verb, {})
		if v.is_empty(): continue
		pr["verbs"].append(verb)
		match str(v.get("cat", "")):
			"move":
				for k in v:
					if k != "cat" and k != "line": pr[k] = v[k]
				pr["authored"] = true; pr["move_verb"] = verb
			"guard": pr["guard"] = v.duplicate(); pr["guard_verb"] = verb
			"bias": pr["cut_ring"] = true
			"clock":
				if verb == "taunt": pr["taunt_s"] = idle_arg(str(il))
				elif verb == "tempo_shift": pr["tempo_s"] = idle_arg(str(il)); pr["tempo"] = v.duplicate()
			"audio": pr["audio"] = str(v.get("audio", "on"))
			"scene": pr["bell"] = true
			"reveal": pr["unmasked"] = true
	return pr

func _neutral_move(dist: float) -> void:
	# his neutral game between strings (IDLE / RECOVER); in a tell, a hold or a fake he closes to the tell range at his own pace
	var wob: float = float(T["composure"]["wobble_move_mult"]) if _wobbled(B) else 1.0
	if not neutral_on or not bool(bidle.get("authored", false)):
		if dist > ENGAGE_DIST:                                                        # the shared approach: the pre-PAC-071 code, to the float
			var intercept: Vector2 = P["pos"] + p_vel * 0.35
			var approach: Vector2 = (intercept-B["pos"]).normalized()*1.2*wob*_speed_mult("B")
			if P.has("body_control"): _boxing_neutral_step(approach,minf(BodyControl.STEP_M,dist-ENGAGE_DIST))
			else: B["pos"] += approach*DT; _clamp(B)
		return
	var pr: Dictionary = bidle
	var to_p: Vector2 = P["pos"] - B["pos"]
	var dirp: Vector2 = to_p.normalized() if to_p.length() > 0.001 else Vector2(0, 1)
	var tgt: Vector2 = P["pos"] + p_vel * float(pr["lead_s"])
	var v := Vector2.ZERO
	if not (bstate == "IDLE" or bstate == "RECOVER"):
		if dist > float(NEUTRAL.get("tell_range_m", ENGAGE_DIST)): v = (tgt - B["pos"]).normalized() * float(pr.get("tell_mps", pr["approach_mps"]))
	else:
		var rng_m := float(pr["range_m"]); var ap := float(pr["approach_mps"])
		if bool(pr["cut_ring"]):                                                      # Moira: from the centre side, so your back goes to the ropes
			var side: Vector2 = Vector2.ZERO - P["pos"]
			side = side.normalized() if side.length() > 0.2 else -dirp
			tgt = P["pos"] + side * rng_m
			if B["pos"].distance_to(tgt) > 0.03: v = (tgt - B["pos"]).normalized() * ap
		else:
			match str(pr["kind"]):
				"advance":
					if dist > rng_m: v = (tgt - B["pos"]).normalized() * ap
				"pulse":
					if dist > rng_m and _on_beat(): v = (tgt - B["pos"]).normalized() * ap
				"orbit":
					if dist > rng_m + 0.25: v = (tgt - B["pos"]).normalized() * ap
					else:
						var tan: Vector2 = Vector2(-dirp.y, dirp.x) * float(orbit_dir())
						var radial: Vector2 = dirp * clampf((dist - rng_m) * 2.0, -float(pr.get("retreat_mps", 0.0)), 0.5)
						v = (tan * float(pr["orbit_mps"]) if dist >= rng_m - 0.4 else Vector2.ZERO) + radial
				"angle":
					if dist > rng_m: v = dirp.rotated(deg_to_rad(float(pr["angle_deg"])) * float(angle_side())) * ap
				"mirror":
					if dist > rng_m + 0.25: v = (tgt - B["pos"]).normalized() * ap
					else:
						var perp := Vector2(-dirp.y, dirp.x)
						v = perp * p_vel.dot(perp) * float(pr["mirror"]) + dirp * clampf((dist - rng_m) * 2.0, -float(pr.get("retreat_mps", 0.0)), 0.5)
				"hold":
					var band := float(pr["band_m"])
					if dist > rng_m + band: v = dirp * ap
					elif dist < rng_m - band: v = -dirp * float(pr["retreat_mps"])
				"ground":                                                             # Cal: the centre is his; he comes no closer than his range - you come the rest
					var gt: Vector2 = Vector2.ZERO if P["pos"].length() <= rng_m else P["pos"] + (Vector2.ZERO - P["pos"]).normalized() * rng_m
					if B["pos"].distance_to(gt) > 0.03: v = (gt - B["pos"]).normalized() * ap
	if v != Vector2.ZERO:
		if P.has("body_control"):
			var distance := BodyControl.STEP_M
			if v.normalized().dot(dirp) > 0.5 and dist > float(pr["range_m"]): distance=minf(distance,dist-float(pr["range_m"]))
			_boxing_neutral_step(v*wob*_speed_mult("B")*_idle_move_tempo(),distance)
		else: B["pos"] += v * wob * _speed_mult("B") * _idle_move_tempo() * DT; _clamp(B)

func orbit_dir() -> int:
	# a circle one way (Yuri, Carter), reversing on a clock (Vane, the Cartographer, Sora), or after every string (Baro)
	if bool(bidle.get("reverse_on_string", false)): return 1 if bstrings_done % 2 == 0 else -1
	var rs := float(bidle.get("reverse_s", 0.0))
	if rs > 0.0: return 1 if (bneutral_t / maxi(1, ms(rs * 1000.0))) % 2 == 0 else -1
	return int(bidle.get("dir", 1))

func angle_side() -> int:
	return 1 if (bneutral_t / maxi(1, ms(float(bidle.get("switch_s", 1.5)) * 1000.0))) % 2 == 0 else -1

func _on_beat() -> bool:
	# Ada / Chiamaka: the first step_ms of every beat of the tempo she is on - the same metronome the phase lines tighten
	var beats: Array = []
	if str(bidle.get("beat", "")) == "tempos" and bmods["tempos"].size() > 0:
		for tv in bmods["tempos"]: beats.append(maxi(1, ms(float(tv))))
	else: beats.append(maxi(1, ms(float(bmods["metronome_ms"]) if float(bmods["metronome_ms"]) > 0.0 else 800.0)))
	var cyc := 0
	for bt in beats: cyc += int(bt)
	var t := bneutral_t % maxi(1, cyc); var step_t := ms(float(bidle.get("step_ms", 200))); var at := 0
	for bt in beats:
		if t >= at and t < at + step_t: return true
		at += int(bt)
	return false

func _idle_tempo() -> float:
	# Tam's tempo shift on his between-strings gap (1.0 for everyone else)
	if not neutral_on or float(bidle.get("tempo_s", 0.0)) <= 0.0: return 1.0
	return float(bidle["tempo"]["fast"]) if btempo_fast else float(bidle["tempo"]["slow"])

func _idle_move_tempo() -> float:
	if not neutral_on or float(bidle.get("tempo_s", 0.0)) <= 0.0: return 1.0
	return float(bidle["tempo"]["move_fast"]) if btempo_fast else float(bidle["tempo"]["move_slow"])

func _neutral_clock() -> void:
	# his clocks on his own steps: the taunt (taunt@Ns: guard open, read off, the next string waits) and Tam's tempo shift (tempo_shift@Ns)
	bneutral_t += 1
	if btaunt_t > 0: btaunt_t -= 1
	var ts := float(bidle.get("taunt_s", 0.0))
	if ts > 0.0 and (bstate == "IDLE" or bstate == "RECOVER") and cast.is_empty() and clinch.is_empty() and bneutral_t >= ms(ts * 1000.0) * (btaunts + 1):
		btaunts += 1
		var tv: Dictionary = NEUTRAL.get("verbs", {}).get("taunt", {})
		var open_t := ms(float(tv.get("open_ms", 500)))
		B["guard_open_t"] = maxi(int(B["guard_open_t"]), open_t); B["guard_t"] = 0; B["blocking"] = false; btaunt_t = open_t
		btimer = maxi(btimer, ms(float(tv.get("delay_ms", 700))))
		_ev("taunt_b", {"n": btaunts, "every_s": ts}); _say("%s taunts - the guard is down for half a second" % boss_label)
	var tps := float(bidle.get("tempo_s", 0.0))
	if tps > 0.0 and bneutral_t % maxi(1, ms(tps * 1000.0)) == 0:
		btempo_fast = not btempo_fast
		_ev("tempo_shift", {"fast": btempo_fast}); _say("%s changes tempo - %s" % [boss_label, "quick between strings now" if btempo_fast else "slow again"])

func _idle_guard(body: bool) -> float:
	# the guard he holds when he has not read the punch: the authored guard's head / body rate; Sam's up while he walks in; halved when wobbled unless composed
	if not neutral_on or not bidle.has("guard_verb"): return 0.35
	var g: Dictionary = bidle["guard"]
	var p := float(g.get("body" if body else "head", 0.35))
	if g.has("advancing") and (bstate == "IDLE" or bstate == "RECOVER") and B["pos"].distance_to(P["pos"]) > float(bidle.get("range_m", ENGAGE_DIST)): p = float(g["advancing"])
	if _wobbled(B): p *= float(g.get("wobble_mult", 1.0))
	return p

func _footwork_tick() -> void:
	# the flag the presentation reads: silent feet (Jean-Guy, Choir), feet that go quiet while arming (Marta)
	var a := str(bidle.get("audio", "on"))
	var on := (not neutral_on) or a == "on" or (a == "arming_off" and not (bstate == "TELL" or bstate == "HOLD" or bstate == "FAKE"))
	if on != bfootwork_audio:
		bfootwork_audio = on; _ev("footwork_audio", {"on": on})

func unmasked(name: String) -> bool:
	for il in _pat(name).get("idle", []):
		if idle_verb(str(il)) == "unmasked": return true
	return false

func boss_slot_label(idx: int) -> String:
	# a blind dual hides his slots at the corner - an unmasked fighter (Remy) is the one it names
	if idx < 0 or idx >= blineup.size(): return "?"
	var nm := str(blineup[idx])
	return "?" if bool(fmt.get("blind", false)) and not unmasked(nm) else nm

func neutral_line() -> String:
	# one line for the HUD / feed: what his neutral game is doing
	if not neutral_on or not bool(bidle.get("authored", false)): return "shared approach"
	var parts: Array = [str(bidle.get("move_verb", ""))]
	if bidle.has("guard_verb"): parts.append(str(bidle["guard_verb"]))
	if float(bidle.get("taunt_s", 0.0)) > 0.0: parts.append("taunts every %ds (%d)" % [int(bidle["taunt_s"]), btaunts])
	if float(bidle.get("tempo_s", 0.0)) > 0.0: parts.append("tempo %s" % ("fast" if btempo_fast else "slow"))
	if not bfootwork_audio: parts.append("footwork silent")
	return ", ".join(PackedStringArray(parts))

# ============================ THE GENERIC OPPONENT ASSEMBLER (NP_04 s9) ====
func spec_from_card(card: Dictionary) -> Dictionary:
	# an NPC card's assembly spec: its style, element and House; its dialect (named, else its House's, else its own name); its tier; a seed from its name unless it names one; its stats
	var nm := str(card.get("name", "GENERIC"))
	var house := house_key(str(card.get("house", "none")))
	var dialect := str(card.get("dialect", "")) if str(card.get("dialect", "")) != "" else (house if house != "none" else nm.to_lower())
	var tier := clampi(int(card.get("tier", 1)), 1, 3)
	var sp := {"name": nm, "label": nm, "style": style_key(str(card.get("style", "BOXERPUNCHER"))), "element": element_key(str(card.get("element", "NONE"))), "house": house, "dialect": dialect, "tier": tier,
		"seed": int(card.get("seed", hash(nm))), "stats": card.get("stats", {}).duplicate(true) if card.get("stats", {}).size() > 0 else TNBAssembler.default_stats(PIECES, tier)}
	if card.has("habits"): sp["habits"] = card["habits"].duplicate(true)                               # PAC-093: a mirror's strings, his own sequences
	return sp

func generic_spec(name: String, style: String, dialect: String, tier: int, seed_v: int = 0, label: String = "") -> Dictionary:
	# a filler's spec from the greybox's words (-- generic=SLUGGER:kowalchuk:2): the dialect's House and element, the tier's stat block
	var drec: Dictionary = PIECES.get("dialects", {}).get(dialect, {})
	var t := clampi(tier, 1, 3)
	return {"name": name, "label": label if label != "" else name, "style": style_key(style), "element": element_key(str(drec.get("element", "NONE"))), "house": house_key(str(drec.get("house", "none"))), "dialect": dialect, "tier": t,
		"seed": seed_v if seed_v != 0 else hash(name), "stats": TNBAssembler.default_stats(PIECES, t)}

func register_generic(spec: Dictionary) -> String:
	# assemble a generic and keep it by name; its pattern is state (a snapshot carries it), never content
	var pat: Dictionary = TNBAssembler.assemble(PIECES, spec)
	if pat.is_empty(): return ""
	var nm := str(spec.get("name", ""))
	generics[nm] = spec.duplicate(true); gpatterns[nm] = pat
	return nm

func set_generic_slot(idx: int, spec: Dictionary) -> bool:
	# NP_04 s9: a filler slot - the enemy's segment idx is fought by this generic from the next reset (new_dual)
	if register_generic(spec) == "": return false
	generic_slots[idx] = spec.duplicate(true)
	return true

func clear_generics() -> void:
	generics = {}; gpatterns = {}; generic_slots = {}

# ============================ PATTERN INTEL (NP_02 s3) ====================
func dialect_of(name: String, card: Dictionary = {}) -> String:
	# his House's tell dialect (NP_07 s4); his own when he has none; a bout card may name one (NP_12A: the school's, a mockup's)
	if card.size() > 0 and str(card.get("dialect", "")) != "": return str(card["dialect"])
	if card.size() > 0 and bool(card.get("generic", false)): return str(spec_from_card(card)["dialect"])     # a generic card: its House's, else its own name
	if generics.has(name): return str(generics[name].get("dialect", name))
	var h := house_key(str(patterns.get(name, {}).get("meta", {}).get("house", "none")))
	return h if h != "none" else name

func pi_level(dialect: String) -> int:
	# the dialect track: each source has its own rungs, exactly as the table reads (3 scraps or 1 spar -> 1; 6 / 3 / a segment -> 2)
	var rec: Dictionary = pi.get("dialects", {}).get(dialect, {})
	var lvl := 0
	var rungs := _pi_rungs()                                                                             # PAC-089: the Film Room's grind rungs from its tier
	for src in rungs:
		var have := int(rec.get(src, 0))
		for rung in rungs[src]:
			if have >= int(rungs[src][rung]): lvl = maxi(lvl, int(rung))
	return lvl

func pi_boss(name: String, rid: String = "") -> int:
	# the boss track: a named boss beaten once is PI 3 - his page; a remix is its own page (NP_04 s6), beaten on its own
	var rec: Dictionary = pi.get("bosses", {}).get(name, {})
	if rid != "": return 3 if int(rec.get("remixes", {}).get(rid, 0)) > 0 and shelved(page_key(name, rid)) else 0
	return 3 if int(rec.get("beaten", 0)) > 0 and shelved(page_key(name)) else 0      # PAC-089: the page in hand - on the Scout Book's shelf

func pi_own() -> int:
	# the level from this opponent's own dialect and his own page
	var lvl := pi_level(bdialect)
	if bout.is_empty() or bout.get("card", {}).is_empty(): lvl = maxi(lvl, pi_boss(boss_name, str(bremix.get("id", ""))))
	return lvl

func pi_vs() -> int:
	# the effective level against this opponent: his own dialect or page, or a real house's PI carried over to the kit he copies (Vey, at half);
	# the Cartographer's META strips it (pi_override 0)
	if int(bmods["pi_override"]) >= 0: return int(bmods["pi_override"])
	var lvl := pi_own()
	var td := _transfer_dialect()
	if td != "": lvl = maxi(lvl, pi_level(td))
	return lvl

func pi_effect_scale() -> float:
	# how much of the level's effect applies: full for his own dialect, the transfer's fraction when the level comes from a copied house, half for an extraction
	if int(bmods["pi_override"]) >= 0: return 1.0
	var scale := float(bmods["pi_scale"])
	var td := _transfer_dialect()
	if td != "" and pi_level(td) > pi_own(): scale *= float(bmods["pi_transfer_pct"])
	return scale

func pi_cue() -> bool:
	return pi_vs() >= 2 and bool(PI.get("effects", {}).get("2", {}).get("tell_cue_emphasis", true))

func _tell_mult() -> float:
	# the interrupt window is the tell (NP_04 s4); PI 2 makes it 10% longer against that dialect (scaled for a transfer) and nothing else is widened
	var m := float(tactic_fx.get("tell_loud_mult", 1.0))
	if pi_vs() >= 2: m *= 1.0 + (float(PI.get("effects", {}).get("2", {}).get("interrupt_window_mult", 1.1)) - 1.0) * pi_effect_scale()
	return m

func pi_read_bonus() -> float:
	# the profile reads more of a dialect it knows (NP_02 s3: "your recon makes your AI teammates smarter"), scaled the same way
	return float(PI.get("profile_read_bonus", {}).get(str(pi_vs()), 0.0)) * pi_effect_scale()

func _tell_assist(sname: String) -> String:
	# Cal's corner assist: Whitlock calls the string from memory, so every tell event names it (in place of the Scout Book)
	if str(bmods["corner_assist"]) == "" or sname == "" or not pattern["strings"].has(sname): return ""
	return "%s: %s" % [str(bmods["corner_assist"]).capitalize(), str(pattern["strings"][sname].get("label", sname))]

func pi_habit(dialect: String) -> String:
	# the commentator's line: authored per dialect, else the motif of his most-weighted string
	var h: Dictionary = PI.get("habits", {})
	if h.has(dialect): return str(h[dialect])
	var best := ""; var best_w := -1
	for k in pattern.get("strings", {}):
		var w := int(pattern.get("select", {}).get("weights", {}).get(k, 15))
		if w > best_w: best_w = w; best = str(pattern["strings"][k].get("tell", {}).get("motif", ""))
	return str(PI.get("habit_fallback", "Watch the {motif}")).replace("{motif}", best.replace("_", " ")).replace("{dialect}", dialect.capitalize())

func _pi_tick(src: String, dialect: String, n: int = 1) -> void:
	# one count on the dialect track (two with the Professor dressed, PAC-074); a rung crossed is an event
	if PI.is_empty() or dialect == "": return
	var before := pi_level(dialect)
	if not pi["dialects"].has(dialect): pi["dialects"][dialect] = {"scraps": 0, "spars": 0, "segments": 0}
	pi["dialects"][dialect][src] = int(pi["dialects"][dialect].get(src, 0)) + maxi(1, n)
	var after := pi_level(dialect)
	_ev("pi_count", {"dialect": dialect, "source": src, "count": int(pi["dialects"][dialect][src]), "level": after})
	if after > before:
		var lbl := str(PI.get("effects", {}).get(str(after), {}).get("label", ""))
		pi_log.append("PI %d vs %s (%s)" % [after, dialect.capitalize(), src])
		_ev("pi", {"dialect": dialect, "level": after, "was": before, "source": src, "label": lbl})
		_say("PATTERN INTEL %d vs the %s dialect - %s" % [after, dialect.capitalize(), lbl])

func _pi_beaten(name: String) -> void:
	# a named boss beaten once: PI 3 for him, his page in the Scout Book; a remix beaten earns the remix's own page
	if PI.is_empty() or not patterns.has(name) or generics.has(name) or bgeneric.size() > 0: return        # a generic beaten earns no page (pages are the named bosses')
	if not pi["bosses"].has(name): pi["bosses"][name] = {"beaten": 0}
	var rec: Dictionary = pi["bosses"][name]
	var rid := str(bremix.get("id", ""))
	if rid != "":
		if not rec.has("remixes"): rec["remixes"] = {}
		var nr := int(rec["remixes"].get(rid, 0))
		rec["remixes"][rid] = nr + 1
		if nr == 0 and _shelve(page_key(name, rid)):                                                   # PAC-089: onto the shelf, or waiting for the Film Room
			pi_log.append("PI 3 vs %s (remix %s beaten)" % [name, rid])
			_ev("scout_book", {"boss": name, "remix": rid, "page": scout_page(name, rid)})
			_say("SCOUT BOOK: the remix page for %s is yours - %s" % [name, str(bremix.get("label", rid))])
		return
	var n := int(rec.get("beaten", 0))
	rec["beaten"] = n + 1
	if n == 0 and _shelve(page_key(name)):
		pi_log.append("PI 3 vs %s (beaten)" % name)
		_ev("scout_book", {"boss": name, "page": scout_page(name)})
		_say("SCOUT BOOK: %s's page is yours, %s" % [name, str(PI.get("page_handwriting", "in the tactician's hand"))])

func scout_page(name: String, rid: String = "") -> Dictionary:
	# PI 3: the pattern page from the pattern itself - tell list, string names, phase notes, the hooks, the corner's tell;
	# a remix's page is the remixed pattern's plus the tactician's notes on what changed (NP_04 s6: the original keeps its page)
	if pi_boss(name, rid) < 3: return {}
	var pat: Dictionary = patterns.get(name, {})
	if rid != "":
		if not REMIX.get("remixes", {}).has(rid): return {}
		pat = remixed_pattern(rid)
	var tells: Array = []
	var bm0: Dictionary = pat.get("meta", {})
	for k in pat.get("strings", {}):
		if str(bm0.get("pi_override", "")) == "0": break                                          # half-blank on purpose: no tells, no string names
		var s: Dictionary = pat["strings"][k]
		tells.append({"string": str(k), "class": str(s.get("class", "normal")), "tell_ms": int(s.get("tell", {}).get("ms", 0)), "motif": str(s.get("tell", {}).get("motif", "")).replace("_", " "), "actions": pat["strings"][k].get("actions", []).size()})
	var phases: Array = []
	for ph in pat.get("phases", []):
		phases.append("phase %s at %s: %s" % [str(ph.get("phase", "")), str(ph.get("trigger", "")), ", ".join(PackedStringArray(ph.get("directives", [])))])
	var hooks: Array = []
	for hk in pat.get("punish", []): hooks.append("punishes " + str(hk.get("trigger", "")))
	for hk in pat.get("bait", []):
		if hk.has("trigger"): hooks.append("baited by " + str(hk.get("trigger", "")))
	var cid := str(COACHES.get("coach_of", {}).get(name, COACHES.get("default", "journeyman")))
	var crec: Dictionary = COACHES.get("coaches", {}).get(cid, {})
	var bm: Dictionary = pat.get("meta", {})
	return {"boss": name, "dialect": dialect_of(name), "house": house_key(str(bm.get("house", "none"))), "style": style_key(str(bm.get("style", ""))), "element": element_key(str(bm.get("element", ""))),
		"tells": tells, "strings": [] if str(bm0.get("pi_override", "")) == "0" else pat.get("strings", {}).keys(), "phases": phases, "hooks": hooks, "desperation": str(pat.get("desperation", {}).get("move", "")),
		"corner": str(crec.get("label", cid)), "corner_tell": str(COACHES.get("tells", {}).get(str(crec.get("tell", "none")), "")), "hand": str(PI.get("page_handwriting", "")),
		"remix": rid, "remix_label": str(REMIX.get("remixes", {}).get(rid, {}).get("label", "")) if rid != "" else "", "remix_notes": remix_notes(rid) if rid != "" else [],
		"half_blank": str(bm.get("pi_override", "")) == "0", "tactician": _page_notes(name, crec, bm)}

func _page_notes(name: String, crec: Dictionary, bm: Dictionary) -> Dictionary:
	# NP_10 s6: with a tactician dressed the Scout Book page is richer - his corner's order, its decoy rate, the slot his pattern names
	var sp := staff_passives()
	if not bool(sp.get("richer_pages", false)): return {}
	var arche := str(crec.get("archetype", "STANDARD"))
	return {"by": sp["by"].get("richer_pages", []).map(func(x): return staff_name(str(x))), "order": str(FORMATION.get("archetypes", {}).get(arche, {}).get("label", arche)),
		"decoy_rate": float(crec.get("decoy_rate", 0.0)) if bool(crec.get("decoys", false)) else 0.0, "slot": str(bm.get("slot", "")), "boss": name}

func remixed_pattern(rid: String) -> Dictionary:
	# a copy of the base with the remix's ops applied - what the remix's page describes (side-effect free)
	var rec: Dictionary = REMIX.get("remixes", {}).get(rid, {})
	if rec.is_empty() or not patterns.has(str(rec.get("base", ""))): return {}
	var saved := pattern; var saved_mods := bmods.duplicate(); var saved_des := bdesync_ms; var sd := directives_done.duplicate(); var sc := directives_carried.duplicate()
	pattern = patterns[str(rec["base"])].duplicate(true)
	for op in rec.get("ops", []): _apply_op(op)
	var out := pattern
	pattern = saved; bmods = saved_mods; bdesync_ms = saved_des; directives_done = sd; directives_carried = sc
	return out

static func parse_pi_arg(s: String, pi_d: Dictionary) -> Dictionary:
	# `-- pi=kowalchuk:2,yuri_kowalchuk:3` -> a ledger: a dialect at a level (its scrap rung), a boss beaten for 3
	var out := {"dialects": {}, "bosses": {}}
	for part in s.split(","):
		if not ":" in part: continue
		var kv := part.split(":")
		var key := str(kv[0]).strip_edges(); var lvl := clampi(int(kv[1]), 0, 3)
		if key == "": continue
		if lvl >= 3: out["bosses"][key] = {"beaten": 1}
		elif lvl >= 1: out["dialects"][key] = {"scraps": int(pi_d.get("rungs", {}).get("scraps", {}).get(str(lvl), 3 * lvl)), "spars": 0, "segments": 0}
	return out

# ============================ SCRAPS AND SPARS (NP_02 s2) =================
func objective_available(id: String, boss_idx: int, card: Dictionary = {}) -> bool:
	# a form that needs something the opponent does not have (a coached NPC's corner shout) is not offered
	var form: Dictionary = BOUTS.get("objective_forms", {}).get(id, {})
	if form.is_empty() or not SCRAPS.has(id): return false
	if str(form.get("requires", "")) == "coached_npc":
		var pat: Dictionary = _opponent_pattern(boss_names[boss_idx], card)
		for k in pat.get("strings", {}):
			if "shout" in str(pat["strings"][k].get("tell", {}).get("motif", "")): return true
		return false
	if str(form.get("requires", "")) == "breakable_special": return special_breakable(boss_names[boss_idx], card)
	return true

func _opponent_pattern(name: String, card: Dictionary = {}) -> Dictionary:
	# the pattern an opponent would fight on: a generic card's assembled, else the boss's by name
	if card.size() > 0 and bool(card.get("generic", false)): return TNBAssembler.assemble(PIECES, spec_from_card(card))
	return _pat(name)

func special_breakable(name: String, card: Dictionary = {}) -> bool:
	# NP_04 s4: "his special" can be interrupted if his hissatsu cast is interruptible, or a Loud string of his is tagged INTERRUPT
	var pat: Dictionary = _opponent_pattern(name, card)
	var d: Dictionary = pat.get("desperation") if pat.get("desperation") != null else {}
	var mv: Dictionary = library.get(str(d.get("move", "")), {})
	if mv.size() > 0 and bool(mv.get("counter_profile", {}).get("interruptible", false)): return true
	var saved := pattern; pattern = pat
	var any := false
	for k in pat.get("strings", {}):
		if _string_class(str(k)) != "normal" and _interruptible(str(k)): any = true
	pattern = saved
	return any

func _bout_format(kind: String) -> Dictionary:
	var secs := float(BOUTS.get("scrap", {}).get("time_cap_s", 30)) if kind == "scrap" else float(BOUTS.get("spar", {}).get("segment_s", 90))
	return {"id": kind, "label": "Scrap" if kind == "scrap" else "Spar", "segments": 1, "dressed": 1, "enemy_dressed": 1, "repeat_slots": false, "condition_carries": false, "sudden_death": false, "blind": false, "segment_s": secs}

func start_scrap(objective_id: String, boss_idx: int, param: String = "", card: Dictionary = {}, label: String = "", district: String = "") -> bool:
	# NP_02 s2.1: one micro-objective, full sim, a hard 30s cap, no Tension meter
	if not objective_available(objective_id, boss_idx, card):
		_ev("bout_refused", {"objective": objective_id, "why": "not available against this opponent"}); return false
	if bout.is_empty(): dual_fmt = fmt.duplicate(true)
	var form: Dictionary = BOUTS["objective_forms"][objective_id]
	var prm := param
	if str(form.get("param", "")) == "dialect" and prm == "": prm = dialect_of(boss_names[boss_idx], card) if bool(card.get("generic", false)) else house_key(str(patterns.get(boss_names[boss_idx], {}).get("meta", {}).get("house", "none")))
	bout = {"kind": "scrap", "objective": objective_id, "param": prm, "card": card.duplicate(true), "label": label if label != "" else "SCRAP - " + str(SCRAPS[objective_id]["prompt"]), "flags": []}
	if district != "": bout["district"] = rep_key(district)                                               # PAC-101: where the overworld placed it (its rep)
	fmt = _bout_format("scrap"); _first_boss = boss_idx
	_reset_dual(boss_idx)
	return true

func start_spar(boss_idx: int, flags: Array = [], card: Dictionary = {}, objective: String = "", label: String = "", opts: Dictionary = {}) -> bool:
	# NP_02 s2.2: one 90s segment, full EP and DROPs, the personal meter at 50, lab flags. PAC-089: the lab flags you choose are The Ring's
	# (an authored bout's are the story's); a ranked spar (the CRBF Annex's board) opens at The Ring's top tier
	var venue := str(opts.get("venue", ""))
	if venue == "ranked" and not fac_open("the_ring", "ranked_tier"):
		var wr := "the ranked spar board is The Ring's (T%d) - the gym's ring is at T%d" % [int(FAC["tracks"]["the_ring"].get("ranked_tier", 3)), fac_tier("the_ring")]
		_ev("spar_refused", {"venue": venue, "why": wr}); _say("SPAR - %s" % wr)
		return false
	var fl: Array = flags.duplicate()
	var labs: Array = fl.filter(func(x): return BOUTS.get("spar", {}).get("lab_flags", {}).has(str(x)))
	if labs.size() > 0 and not bool(opts.get("authored", false)) and not fac_open("the_ring", "lab_tier"):
		fl = fl.filter(func(x): return not (x in labs))
		var wl := "the lab flags are The Ring's (T%d) - the gym's ring is at T%d" % [int(FAC["tracks"]["the_ring"].get("lab_tier", 1)), fac_tier("the_ring")]
		_ev("lab_refused", {"flags": labs, "why": wl}); _say("SPAR - %s: %s off" % [wl, ", ".join(PackedStringArray(labs))])
	if "mirror" in fl:                                                                                  # PAC-093: the lab's mirror - the fighter's copy, on his record
		var who := str(opts.get("fighter", pname()))
		var mcard := mirror_card(who) if not GROW.is_empty() else {}
		if mcard.is_empty():
			_ev("spar_refused", {"venue": "mirror", "why": "no card of %s to copy" % who}); return false
		card = mcard; label = label if label != "" else "MIRROR SPAR - %s" % who
		opts = opts.duplicate(); opts["fighter"] = who; opts["mirror"] = who
	if bout.is_empty(): dual_fmt = fmt.duplicate(true)
	bout = {"kind": "spar", "objective": objective, "param": "", "card": card.duplicate(true), "label": label if label != "" else ("RANKED SPAR" if venue == "ranked" else "SPAR"), "flags": fl, "venue": venue}
	if str(opts.get("fighter", "")) != "": bout["fighter"] = str(opts["fighter"])                        # PAC-090: a trial spar sends the fighter it is his (the mirror)
	if str(opts.get("mirror", "")) != "": bout["mirror"] = str(opts["mirror"])
	fmt = _bout_format("spar"); _first_boss = boss_idx
	_reset_dual(boss_idx)
	return true

func start_ep1(id: String) -> bool:
	# NP_12A: SCRAP 1-3 and the Priya trial, by name, on their stand-in patterns
	var rec: Dictionary = BOUTS.get("ep1", {}).get(id, {})
	if rec.is_empty(): return false
	var bi := boss_names.find(str(rec.get("opponent", "")))
	if bi < 0: return false
	if str(rec.get("kind", "scrap")) == "spar": return start_spar(bi, rec.get("flags", []), rec.get("card", {}), str(rec.get("objective", "")), str(rec.get("label", id)), {"authored": true})   # the story's flags
	return start_scrap(str(rec["objective"]), bi, "", rec.get("card", {}), str(rec.get("label", id)))

func end_bout() -> void:
	# back to the dual the greybox was running
	if bout.is_empty(): return
	bout = {}; obj = {}; lab = []
	if dual_fmt.size() > 0: fmt = dual_fmt.duplicate(true)
	_reset_dual(_first_boss)

func _end_bout() -> void:
	# the verdict (NP_02 s2.1-s2.2): a scrap on its objective, then the cap on EP; a spar on drops, then EP
	mode = "OVER"
	var v := ""; var rung := ""
	if str(bout["kind"]) == "scrap":
		if obj.size() > 0 and obj["met"]: v = "SCRAP WON - %s" % str(obj["why"]); rung = "objective"
		elif obj.size() > 0 and obj["failed"]: v = "SCRAP LOST - %s" % str(obj["why"]); rung = "objective_failed"
		elif P["drops"] >= 3: v = "SCRAP LOST - counted out"; rung = "ko"
		elif B["drops"] >= 3: v = "SCRAP WON - he could not continue"; rung = "ko"
		elif ep_p > ep_b: v = "SCRAP WON on EP at the cap (%d-%d)" % [ep_p, ep_b]; rung = "ep"
		elif ep_b > ep_p: v = "SCRAP LOST on EP at the cap (%d-%d)" % [ep_p, ep_b]; rung = "ep"
		else: v = "SCRAP DRAWN at the cap (%d-%d)" % [ep_p, ep_b]; rung = "ep"
	else:
		if score_p != score_b: v = "SPAR: %s WINS on drops %d-%d" % ["MILLBROOK" if score_p > score_b else "THEY", score_p, score_b]; rung = "score"
		elif ep_p != ep_b: v = "SPAR: %s WINS on EP %d-%d" % ["MILLBROOK" if ep_p > ep_b else "THEY", ep_p, ep_b]; rung = "ep"
		else: v = "SPAR DRAWN %d-%d, EP %d-%d" % [score_p, score_b, ep_p, ep_b]; rung = "draw"
		if obj.size() > 0: v += "  |  %s: %s" % [str(obj["prompt"]), "met" if obj["met"] else ("failed - " + str(obj["why"]) if obj["failed"] else "not met")]
	# NP_02 s3: the sizes pay Pattern Intel - a scrap won counts one on the dialect, a spar fought to its end counts one
	var won_bout: bool = (rung == "objective" or (rung == "ko" and B["drops"] >= 3) or (rung == "ep" and ep_p > ep_b)) if str(bout["kind"]) == "scrap" else ((rung == "score" and score_p > score_b) or (rung == "ep" and ep_p > ep_b))
	var pi_before := pi_level(bdialect)
	if str(bout["kind"]) == "scrap":
		if won_bout: _pi_tick("scraps", bdialect, 1 + int(staff_fx.get("pi_bout_extra", 0.0)))
	elif str(bout.get("card", {}).get("mirror_of", "")) == "": _pi_tick("spars", bdialect, 1 + int(staff_fx.get("pi_bout_extra", 0.0)))   # PAC-093: a mirror's pattern is his own - no PI
	_ev("bout_end", {"kind": bout["kind"], "verdict": v, "rung": rung, "objective": str(bout.get("objective", "")), "met": obj.get("met", false) if obj.size() > 0 else false, "won": won_bout})
	if won_bout: _beat(str(bout["kind"]), str(bout.get("card", {}).get("name", boss_name)) if bout.get("card", {}).size() > 0 else boss_name, str(B["house"]))   # PAC-075: for BEAT_IN(scrap|spar)
	if won_bout and str(bout["kind"]) == "spar":                                                        # PAC-090: NP_11 s4's trials - a spar won; his mirror beaten
		_trial_mark(pname(), "spar_won")
		if str(bout.get("mirror", "")) == pname(): _trial_mark(pname(), "mirror")
	_recruit_check()
	_pay_bout(won_bout, pi_level(bdialect) > pi_before)                                                  # NP_02 s2 / NP_11 s6: the size pays, and the toast says what
	_say("%s :: %s   EP %d-%d   drops %d-%d" % [str(bout["label"]), v, ep_p, ep_b, drops_p, drops_b])

func switch_boss(i: int) -> void:
	_first_boss = clampi(i, 0, boss_names.size() - 1)
	_reset_dual(_first_boss)

# ============================ TRACKER (C7) =================================
func _track(row: String) -> void:
	tokens.append(row)
	if tokens.size() > int(T["adaptation_tracker"]["window_tokens"]): tokens.pop_front()
	_habit_track(row)                                                                                 # PAC-093: the tracker's record, kept across bouts (the mirror's)
	for size in [2, 3]:
		if tokens.size() >= size:
			var gram := ",".join(tokens.slice(tokens.size() - size))
			var cnt := 0
			for i in range(tokens.size() - size + 1):
				if ",".join(tokens.slice(i, i + size)) == gram: cnt += 1
			if cnt >= int(T["adaptation_tracker"]["flag_at_count"]):
				var prev: int = flags.get(gram, [0, 0])[0]
				flags[gram] = [mini(3, prev + 1), 0]
				_habit_read(gram)
				if prev == 0:
					_say("COMMENTARY: He's leaning on that %s - %s is timing it now!" % [gram.replace(",", " > "), pattern.get("id", "the boss")])
					_ev("flag", {"gram": gram})
				if flags[gram][0] > tier_fired:
					tier_fired = flags[gram][0]
					_fire_event("player_flagged_ngram_tier%d" % tier_fired)

func _flag_tier() -> int:
	for size in [3, 2]:
		if tokens.size() >= size:
			var g := ",".join(tokens.slice(tokens.size() - size))
			if g in flags: return flags[g][0]
	return 0

func _tracker_tick() -> void:
	var decay := ms(float(T["adaptation_tracker"]["decay_clear_s"]) * 1000.0)
	for g in flags.keys():
		flags[g][1] += 1
		if flags[g][1] >= decay:
			flags[g][0] -= 1; flags[g][1] = 0
			if flags[g][0] <= 0: flags.erase(g)

# ============================ BAIT / PUNISH ================================
func _ev_key(t: String) -> String:
	var out := ""
	for c in t.trim_prefix("player_"):
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_": out += c
		else: break
	return out

func _phase_ok(sname: String) -> bool:
	if "retired" in pattern["strings"][sname]["tags"]: return false               # a phase directive retired it (Tam's borrowed clothes)
	for t in pattern["strings"][sname]["tags"]:
		if str(t).begins_with("phase>="): return bphase >= int(str(t).split(">=")[1])
	return true

func _force_string(sname: String, tell_scale: float, loud: bool, opts: Dictionary = {}) -> void:
	bstring = sname; bstate = "TELL"; bforce_opts = opts; bfeint = ""
	btimer = maxi(1, int(ms(float(pattern["strings"][sname]["tell"]["ms"])) * tell_scale * _tell_mult()))
	if bmods["cooldown_ms"].has(sname): bcooldown_until[sname] = tick + ms(float(bmods["cooldown_ms"][sname]))
	tell_start_tick = tick; tell_reacted = false
	_ev("tell", {"ticks": btimer, "loud": loud, "string": sname, "jammed": states["P"].has("tell_jam_audio") or states["P"].has("tell_jam_visual"), "highlight": tell_highlight_t > 0, "cue": pi_cue(), "assist": _tell_assist(sname)})

func _has_bait(key: String) -> bool:
	for b in pattern.get("bait", []):
		if b.has("trigger") and _ev_key(str(b["trigger"])) == key: return true
	return false

func _fastest_string() -> String:
	var best := ""; var best_ms := 1 << 30
	for k in pattern["strings"]:
		if _phase_ok(k) and int(pattern["strings"][k]["tell"]["ms"]) < best_ms:
			best = k; best_ms = int(pattern["strings"][k]["tell"]["ms"])
	return best

func _parse_response(resp: String) -> Dictionary:
	# punish-response grammar -> one plan. kind: force | actions | swap | reweight | unknown
	var plan := {"kind": "unknown", "string": "", "scale": 0.85, "opts": {}, "pre": [], "post": [], "words": []}
	var opts: Dictionary = plan["opts"]
	if resp.begins_with("swap_weights"):
		var rx := RegEx.new(); rx.compile("swap_weights\\((\\w+),(\\w+)\\)\\s*(\\d+)s")
		var m := rx.search(resp)
		if m: plan["kind"] = "swap"; plan["swap"] = [m.get_string(1), m.get_string(2), float(m.get_string(3))]
		return plan
	if "w(" in resp:
		var rx2 := RegEx.new(); rx2.compile("w\\((\\w+)\\)\\+=(\\d+)")
		var m2 := rx2.search(resp)
		if m2: plan["kind"] = "reweight"; plan["reweight"] = [m2.get_string(1), int(m2.get_string(2))]
		return plan
	var rx_speed := RegEx.new(); rx_speed.compile("speed x(\\d+\\.?\\d*)")
	var ms_ := rx_speed.search(resp)
	if ms_: plan["scale"] = 1.0 / maxf(1.0, float(ms_.get_string(1)))
	for w in resp.replace("force_", "").replace("speed", "").split(" ", false):
		var word := str(w)
		if word.begins_with("x") and word.substr(1).is_valid_float(): continue
		if word in pattern["strings"]:
			if plan["string"] == "" and _phase_ok(word): plan["string"] = word
			elif not _phase_ok(word): plan["locked"] = word      # authored for a later phase: nothing to do yet
			continue
		match word:
			"phase_fastest_string": plan["string"] = _fastest_string()
			"immediate": plan["scale"] = minf(float(plan["scale"]), 0.6)
			"immediate_counter": plan["pre"].append({"kind": "punch", "row": "R_STRAIGHT", "mult": 1.3, "body": false})
			"corner_cut_rush": plan["pre"].append({"kind": "move", "dir": "toward", "dist": 0.6, "guard": true})
			"over_under_reversal":
				plan["pre"].append({"kind": "punch", "row": "R_FLARED", "mult": 1.0, "body": false})
				plan["pre"].append({"kind": "punch", "row": "R_UPPERCUT", "mult": 1.0, "body": true})
			"corner_placement", "toward_corner": plan["pre"].append({"kind": "move", "dir": "lateral", "dist": 0.5, "guard": false})
			"widened_angle": plan["pre"].append({"kind": "move", "dir": "lateral", "dist": 0.4, "guard": false})
			"pressure": plan["pre"].append({"kind": "move", "dir": "toward", "dist": 0.3, "guard": false})
			"counter_exit": plan["post"].append({"kind": "move", "dir": "away", "dist": 0.4, "guard": false})
			"to_body": opts["body"] = true
			"targets_flag", "targets_flagged_opening", "counter": opts["mult"] = 1.15
			_: plan["words"].append(word)
	if plan["string"] != "": plan["kind"] = "force"
	elif plan["pre"].size() > 0 or plan["post"].size() > 0: plan["kind"] = "actions"
	elif plan.has("locked"): plan["kind"] = "locked"
	return plan

func response_coverage(pats: Dictionary) -> Dictionary:
	# static check for the smoke: every punish response resolves to a plan
	var saved := pattern
	var known := 0; var unknown := {}
	for name in pats:
		pattern = pats[name]
		for pu in pats[name].get("punish", []):
			var plan := _parse_response(str(pu["response"]))
			if plan["kind"] == "unknown" or plan["words"].size() > 0: unknown[str(pu["response"])] = name
			else: known += 1
	pattern = saved
	return {"known": known, "unknown": unknown}

func _fire_event(ev: String) -> void:
	if mode != "FIGHT": return
	var ek := _ev_key(ev)
	_ev("sensor", {"name": ev})
	if not hooks_enabled or btsurge.size() > 0: return                                             # PAC-086: nothing answers while he gathers
	for b in pattern.get("bait", []):
		if b.has("trigger") and b.has("force"):
			var bk := _ev_key(str(b["trigger"]))
			if (bk.begins_with(ek) or ek.begins_with(bk)) and bstate != "ACTING":
				var fname: String = b["force"]
				if fname in pattern["strings"] and _phase_ok(fname):
					_force_string(fname, 1.0, true)
					_say("BAITED - he answers with %s!" % pattern["strings"][fname]["label"])
					return
	if punish_suppress_t > 0: return                        # FEINT STORM: his punish hooks are off
	for pu in pattern.get("punish", []):
		var pk := _ev_key(str(pu["trigger"]))
		if not (pk.begins_with(ek) or ek.begins_with(pk)): continue
		if punish_cd.get(pk, 0) > 0: return
		punish_cd[pk] = maxi(1, int(ms(4000) * float(bmods["punish_cd_mult"])))        # Baro's corrections come faster in phase 2
		var plan := _parse_response(str(pu["response"]))
		match plan["kind"]:
			"swap":
				var a: String = plan["swap"][0]; var b2: String = plan["swap"][1]
				if pattern["select"]["weights"].has(a) and pattern["select"]["weights"].has(b2):
					var wa = pattern["select"]["weights"][a]
					pattern["select"]["weights"][a] = pattern["select"]["weights"][b2]; pattern["select"]["weights"][b2] = wa
					swap_restore = {"a": a, "b": b2, "t": ms(float(plan["swap"][2]) * 1000.0)}
					_say("He's flipping the script on you (%s)..." % ek)
			"reweight":
				if pattern["select"]["weights"].has(plan["reweight"][0]):
					pattern["select"]["weights"][plan["reweight"][0]] = int(pattern["select"]["weights"][plan["reweight"][0]]) + int(plan["reweight"][1])
					_say("He's adjusting to you (%s)..." % ek)
			"force":
				if bstate != "ACTING":
					var opts: Dictionary = plan["opts"]; opts["pre"] = plan["pre"]; opts["post"] = plan["post"]
					_force_string(plan["string"], float(plan["scale"]), false, opts)
					_say("PUNISHED (%s) -> %s!" % [ek, pattern["strings"][plan["string"]]["label"]])
			"actions":
				if bstate != "ACTING":
					bqueue = []; bqueue.append_array(plan["pre"]); bqueue.append_array(plan["post"])
					bstate = "ACTING"; btimer = ms(120); bstring = ""; bforce_opts = plan["opts"]
					_say("PUNISHED (%s) -> he answers on the spot!" % ek)
		return

# ============================ ACTION VM ====================================
# Every verb the PBN compiler emits resolves to sim actions here. Unknown verbs
# are reported by verb_coverage(), never silently skipped.
const MOVE_VERBS := {"RUSH": ["toward", 0.6, false], "SURGE": ["toward", 0.6, false], "ADVANCE": ["toward", 0.4, false],
	"HERD": ["toward", 0.5, false], "STEP_IN": ["toward", 0.3, false], "GUARD_ADVANCE": ["toward", 0.4, true],
	"GUARD_WALL_ADVANCE": ["toward", 0.5, true], "STEP_OUT": ["away", 0.4, false], "STEP_BACK": ["away", 0.4, false],
	"BACK_STEP": ["away", 0.4, false], "ANGLE_STEP": ["lateral", 0.5, false], "LATERAL_ARC": ["lateral", 0.6, false],
	"POSITION_WIN": ["center", 0.5, false]}

static func _arg_num(a: String) -> float:
	var rx := RegEx.new(); rx.compile("\\(([\\d\\.]+)")
	var m := rx.search(a)
	return float(m.get_string(1)) if m else -1.0

static func _arg_dist(a: String, dflt: float) -> float:
	var n := _arg_num(a)
	if n < 0.0: return dflt
	return n / 100.0 if "cm" in a else n

func parse_action(a: String) -> Array:
	# one PBN action -> list of sim actions ([] = unknown verb)
	var verb := a.split("(")[0].split(" ")[0]
	if verb in PUNCH_VERBS:
		var mult := 1.3 if verb.begins_with("COUNTER") or verb.begins_with("PULL_COUNTER") or verb == "CHECK_HOOK" else 1.0
		return [{"kind": "punch", "row": PUNCH_VERBS[verb], "mult": mult, "body": verb.begins_with("LT_")}]
	if verb in MOVE_VERBS:
		var mv: Array = MOVE_VERBS[verb]
		return [{"kind": "move", "dir": mv[0], "dist": _arg_dist(a, float(mv[1])), "guard": mv[2]}]
	match verb:
		"DELAY", "pause": return [{"kind": "wait", "t": ms(maxf(0.0, _arg_num(a)))}]
		"COUNTER_STATE":
			var secs := _arg_num(a)
			return [{"kind": "counter_state", "t": ms((secs if secs > 0.0 else 2.0) * 1000.0)}]
		"COUNTER_ON_BLOCK": return [{"kind": "counter_state", "t": ms(500)}]
		"CLINCH_ATTEMPT": return [{"kind": "clinch", "drag": 0.5, "hold": ms(2000)}]
		"DRAG_ROPEWARD": return [{"kind": "clinch", "drag": _arg_dist(a, 1.0), "hold": ms(1000)}]
		"BODY_SERIES": return [{"kind": "punch", "row": "L_HOOK", "mult": 1.0, "body": true},
			{"kind": "punch", "row": "R_HOOK", "mult": 1.0, "body": true},
			{"kind": "punch", "row": "R_UPPERCUT", "mult": 1.0, "body": true}]
		"WALK_STRING":
			var n := int(maxf(1.0, _arg_num(a)))
			var out: Array = []
			for i in n:
				out.append({"kind": "move", "dir": "toward", "dist": 0.25, "guard": false})
				out.append({"kind": "punch", "row": "L_HOOK" if i % 2 == 0 else "R_HOOK", "mult": 1.0, "body": false})
			return out
		"MIXED_STRING":
			var n2 := int(maxf(1.0, _arg_num(a)))
			var out2: Array = []
			const POOL := ["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_UPPERCUT"]
			for i in n2: out2.append({"kind": "punch", "row": POOL[rng.randi_range(0, POOL.size() - 1)], "mult": 1.0, "body": false})
			return out2
	return []

func verb_coverage(pats: Dictionary) -> Dictionary:
	# static check for the smoke: which action verbs across the loaded patterns the VM understands
	var known := {}; var unknown := {}
	for name in pats:
		for sname in pats[name]["strings"]:
			for a in pats[name]["strings"][sname]["actions"]:
				var verb := str(a).split("(")[0].split(" ")[0]
				if parse_action(str(a)).is_empty(): unknown[verb] = name
				else: known[verb] = true
	return {"known": known.keys(), "unknown": unknown}

func _nearest_rope_dir(pos: Vector2) -> Vector2:
	if absf(pos.x) >= absf(pos.y): return Vector2(1.0 if pos.x >= 0.0 else -1.0, 0.0)
	return Vector2(0.0, 1.0 if pos.y >= 0.0 else -1.0)

func _boss_act(act: Dictionary) -> int:
	# executes one VM action, returns ticks until the next
	if B.has("boxing"): B["boxing"]["sequence_wait"] = false
	var opts: Dictionary = bforce_opts
	var dist: float = B["pos"].distance_to(P["pos"])
	match act["kind"]:
		"punch":
			var row: Dictionary = T["punch_matrix"][act["row"]]
			var mult: float = float(act["mult"]) * float(opts.get("mult", 1.0))
			if P["busy_t"] > 0 and float(act["mult"]) > 1.0: mult *= 1.15      # a true counter finds a committed fighter
			var to_body: bool = bool(act["body"]) or bool(opts.get("body", false))
			if not to_body and float(bmods["target_body_pct"]) > 0.0 and rng.randf() < float(bmods["target_body_pct"]): to_body = true   # Reyes: the body is the truth (80 / 20)
			if P.has("body_control"):
				# The native match owns an actual startup on both sides. An authored
				# string gap must not squeeze a heavy punch into a few drawn frames
				# or grant contact before the opponent has delivered his hand.
				var hand_speed := float(_gassed(B)["hand_speed"])
				var step: Dictionary = B.get("body_control",{}).get("step",{})
				var stepping: bool = Vector2(step.get("direction",Vector2.ZERO)).dot(BodyControl.forward(B,P)) > 0.5
				var mods: Array = ["BODY"] if to_body else []
				if stepping: mods.append("STEPPING")
				var telegraph := float(T["modifiers"]["STEPPING"]["telegraph_mult"]) if stepping else 1.0
				var startup := maxi(1, ms(float(row["startup_ms"]) * float(B["pkg"].get("startup_mult", 1.0)) * telegraph / hand_speed))
				var recovery := maxi(1, int(ms(float(row["recovery_ms"])) * 0.7 / _bspeed() / hand_speed))
				B["pending"] = {"row":act["row"], "body":to_body, "mods":mods, "stepping":stepping, "mult":mult, "t":startup, "startup":startup, "recovery":recovery,"stamina_cost":float(row["stamina"])}
				B["busy_t"] = startup + recovery
				# Preserve the opponent's authored guard intent too. Its working
				# hand leaves coverage through the same physical path as the player.
				_boxing_begin("B",act["row"],B["pending"]["mods"],startup,recovery)
				B["stamina"] = maxf(_sfloor(B), float(B["stamina"]) - float(B["pending"]["stamina_cost"]))
				startup = int(B["pending"]["startup"]); recovery = int(B["pending"]["recovery"])
				B["boxing"]["sequence_wait"] = true
				_ev("boss_windup", {"row":act["row"], "body":to_body, "startup":startup, "recovery":recovery})
				return startup + recovery
			bpending = {"row": act["row"], "body": to_body}
			if not P.has("body_control"):
				B["pos"] += (P["pos"] - B["pos"]).normalized() * LUNGE_B; _clamp(B)
			_ev("boss_act", {"verb": "punch", "row": act["row"], "body": to_body})
			_land_boss_punch(mult)
			return maxi(1, int(ms(float(row["recovery_ms"])) * 0.7 / _bspeed()))
		"move":
			var fwd: Vector2 = (P["pos"] - B["pos"]).normalized()
			var step_v := Vector2.ZERO
			match act["dir"]:
				"toward": step_v = fwd * float(act["dist"])
				"away": step_v = -fwd * float(act["dist"])
				"lateral": step_v = Vector2(-fwd.y, fwd.x) * float(act["dist"]) * (1.0 if rng.randf() < 0.5 else -1.0)
				"center": step_v = (Vector2.ZERO - B["pos"]).limit_length(float(act["dist"]))
			if P.has("body_control"):
				_boxing_queue_step(step_v,step_v.length())
				if act["guard"]: B["guard_t"] = ms(700)
				_ev("boss_act",{"verb":"move","dir":act["dir"]})
				return ms(1000.0*(BodyControl.STEP_SECONDS+BodyControl.STEP_RECOVERY_SECONDS))
			B["pos"] += step_v; _clamp(B)
			if B["pos"].distance_to(P["pos"]) < 0.9:                                   # bodies meet: he walks you back (Alfie: +75% of the step on top)
				P["pos"] = B["pos"] + (P["pos"] - B["pos"]).normalized() * 0.9 + fwd * step_v.length() * (float(bmods["herd_mult"]) - 1.0); _clamp(P)
			if act["guard"]: B["guard_t"] = ms(700)
			_ev("boss_act", {"verb": "move", "dir": act["dir"]})
			return ms(220)
		"wait":
			_ev("boss_act", {"verb": "wait"})
			return maxi(1, int(act["t"]))
		"counter_state":
			B["counter_state_t"] = int(act["t"]); B["guard_t"] = int(act["t"])
			_ev("boss_act", {"verb": "counter_state"})
			_say("he's waiting on you - the guard is a trap")
			return ms(150)
		"clinch":
			_ev("boss_act", {"verb": "clinch"})
			if dist <= 1.3:
				_start_clinch("B", float(act["drag"]), 3 if float(act["drag"]) > 0.6 else 2)
				return clinch_t + ms(300)
			_say("clinch attempt whiffs - he's open")
			return ms(600)
	return ms(200)

# ============================ CLINCH SCRAMBLE (NP_03 s7) ===================
func _start_clinch(by: String, drag: float = 0.5, need: int = 2) -> void:
	# NP_03 s7: a mini-duel of alternating stick taps on a SHRINKING cue. Four
	# cues, each interval 0.8x the last (700 -> 560 -> 448 -> 358 ms); the tap
	# window is 30% of the interval but never under the RFX floor (80-160 ms),
	# so RFX decides the last cue. Sides alternate L/R (LS or A/D); ENTER/A is
	# the button-chord parity path. A tap outside the window locks that cue:
	# mashing loses. Enough beats win position (opponent herded 50cm ropeward)
	# or, holding BODY on the resolve, a reset (center ring, both +5 stamina).
	var floor_w := int(lerpf(float(ms(80)), float(ms(160)), float(P["stats"]["RFX"]) / 99.0))
	var cues: Array = []; var windows: Array = []; var sides: Array = []
	var t_ms := 0.0; var interval := 700.0
	for i in 4:
		t_ms += interval
		cues.append(ms(t_ms)); windows.append(maxi(floor_w, int(ms(interval) * 0.3 * float(P["pkg"].get("clinch_window_mult", 1.0))))); sides.append("L" if i % 2 == 0 else "R")
		interval *= 0.8
	clinch = {"by": by, "need": need, "drag": drag, "cues": cues, "windows": windows, "sides": sides,
		"i": 0, "t": 0, "beats": 0, "hit": false, "early": false, "cue_open": false,
		"end": int(cues[-1]) + int(windows[-1]), "mx_prev": 0.0, "rise_prev": false}
	clinch_t = int(clinch["end"])
	P["busy_t"] = maxi(P["busy_t"], clinch_t); P["cmd"] = {}; P["pending"] = {}
	P["dodge"] = ""; P["dodge_t"] = 0; P["blocking"] = false
	bqueue = []; bpending = {}; B["pending"] = {}; bstate = "IDLE"; btimer = clinch_t + ms(300)
	_ev("clinch", {"by": by, "need": need})
	_say("CLINCH%s - alternate L/R on the cue (%d beats to win it)" % [" - he grabs you" if by == "B" else "", need])

func _clinch_step(inp: Dictionary) -> void:
	clinch["t"] += 1
	var t: int = clinch["t"]
	clinch_t = int(clinch["end"]) - t
	var i: int = clinch["i"]
	var cues: Array = clinch["cues"]
	# the tap: a stick edge past 0.6 on either side, or the button parity path
	var mx := float(inp.get("body_axis", inp.get("move", Vector2.ZERO)).x)
	var tap := ""
	if mx > 0.6 and float(clinch["mx_prev"]) <= 0.6: tap = "R"
	elif mx < -0.6 and float(clinch["mx_prev"]) >= -0.6: tap = "L"
	clinch["mx_prev"] = mx
	var rise: bool = inp.get("rise", false)
	if rise and not clinch["rise_prev"] and i < cues.size(): tap = clinch["sides"][i]
	clinch["rise_prev"] = rise
	if i < cues.size():
		var c: int = cues[i]; var w: int = clinch["windows"][i]
		var in_window: bool = absi(t - c) <= w
		if in_window and not clinch["cue_open"]:
			clinch["cue_open"] = true; _ev("clinch_cue", {"i": i, "side": clinch["sides"][i]})
		if tap != "":
			if not in_window:
				if t < c: clinch["early"] = true                 # mashed ahead of the cue: this cue is lost
				_ev("clinch_miss", {"i": i, "why": "early" if t < c else "late"})
			elif clinch["hit"] or clinch["early"]:
				_ev("clinch_miss", {"i": i, "why": "locked"})
			elif tap == clinch["sides"][i]:
				clinch["beats"] += 1; clinch["hit"] = true
				_ev("clinch_beat", {"i": i, "beats": clinch["beats"]})
			else:
				clinch["hit"] = true                            # wrong side spends the cue
				_ev("clinch_miss", {"i": i, "why": "wrong_side"})
		if t > c + w:
			clinch["i"] = i + 1; clinch["hit"] = false; clinch["early"] = false; clinch["cue_open"] = false
	if t >= int(clinch["end"]): _resolve_clinch(inp.get("body", false))

func _resolve_clinch(want_reset: bool) -> void:
	var p_wins: bool = int(clinch["beats"]) >= int(clinch["need"])
	var by: String = clinch["by"]
	if p_wins:
		if want_reset:
			P["pos"] += (Vector2.ZERO - P["pos"]).limit_length(1.0); B["pos"] += (Vector2.ZERO - B["pos"]).limit_length(1.0)
			P["stamina"] = minf(100.0, P["stamina"] + float(T["clinch"]["reset_stamina_bonus"]))
			B["stamina"] = minf(100.0, B["stamina"] + float(T["clinch"]["reset_stamina_bonus"]))
			_say("CLINCH WON - reset to center, both +5 stamina")
		else:
			var d: Vector2 = _nearest_rope_dir(B["pos"])
			B["pos"] += d * float(T["clinch"]["position_herd_cm"]) / 100.0; _clamp(B)
			P["pos"] = B["pos"] + (P["pos"] - B["pos"]).normalized() * 0.9; _clamp(P)
			_say("CLINCH WON - you walk him toward the ropes")
		_ev("clinch_end", {"winner": "P", "reset": want_reset})
	else:
		var d2: Vector2 = _nearest_rope_dir(P["pos"])
		P["pos"] += d2 * float(clinch["drag"]); _clamp(P)
		B["pos"] = P["pos"] + (B["pos"] - P["pos"]).normalized() * 0.9; _clamp(B)
		B["stamina"] = minf(100.0, B["stamina"] + float(T["clinch"]["reset_stamina_bonus"]))
		_say("CLINCH LOST - he drags you toward the ropes; referee breaks it")
		_ev("clinch_end", {"winner": "B", "reset": false})
		if by == "B": _boss_foul_on_break()
	clinch = {}; clinch_t = 0
	P["busy_t"] = 0; B["busy_t"] = 0
	_separate()
	bstate = "RECOVER"; btimer = ms(500)

# ============================ HISSATSU VM (NP_05 s4-s9) ====================
# Every move in data/hissatsu_library.v2.json executes from its record:
# startup_cinematic -> effect block -> aftermath. The families map to punch
# rows (the motion IS the spellbook); the counter profile decides interrupts;
# the defender's answer at resolve follows s9 (perfect WALL negates, a
# geometrically valid dodge chips 40%, a block takes 60% + heavy shred).
const FAMILY_ROW := {"HAYMAKER": "R_HOOKERCUT", "ARC": "R_HOOK", "PISTON": "R_STRAIGHT", "RISE": "R_UPPERCUT", "WALL": ""}
const TIER_RANK := {"T0": 0, "T1": 1, "T2": 2, "T3": 3, "T4": 4}
const STATE_SELF := ["auto_slip", "counter_stance", "counter_state", "mirror_counter", "shell_counter", "beats_duck_reads",
	"angle_exit", "two_hit_echo", "afterimage_partner", "afterimage_self", "arena_freeze_vfx", "arena_frost_creep",
	"copies_last_player_hissatsu_vfx", "counter_on_break_attempt", "gauge_migrates_to_teammate_on_break",
	"averages_incoming_damage_over_duration"]
const STATE_TARGET := ["foot_freeze_slow", "foot_slow", "tell_jam_audio", "tell_jam_visual", "guard_regen_minus1",
	"wobble_on_gassed_target", "enemy_tension_earn_minus25pct", "enemy_hissatsu_cost_plus10", "steals_charged_state",
	"suppress_commentary_ids"]
const BUFF_NAMES := ["forward_glide", "bonus_tension_on_counter", "stamina_regen_x2", "stamina_regen_x1_5", "range_plus",
	"counter_window_plus_100ms", "all_stats_r4r5_plus5", "ep_plus_on_clean", "tension_plus_on_hit", "scout_book_note_on_hit",
	"guard_regen_plus", "guard_regen_x2", "move_speed_plus15", "tension_plus_if_post_count"]
const EFFECT_TYPES := ["DMG", "DISPLACE", "STATE", "BUFF", "SHRED", "WALL", "BURN", "REDACTED"]

func player_move() -> Dictionary:
	return library.get(str(lineup[seg_idx].get("hissatsu", "")), {})

func move_house(name: String) -> String:
	var m: Dictionary = library.get(name, {})
	return str(m["house_id"]) if m.size() > 0 and m.get("house_id") != null else ""

func castable(mv: Dictionary) -> bool:
	if mv.is_empty(): return false
	for e in mv["effect"]:
		if str(e["type"]) == "REDACTED": return false           # sealed: the motion executes as its normal punch
	if str(mv["tier"]) == "T3" and not t3_unlocked and not mv.has("duo_of") and not mv.has("hybrid_of") and not mv.has("duo_sync"): return false   # PAC-080: a Duo's T3 is live by the bond (PAC-087: a hybrid by its own rule; PAC-088: a duo sync by the exhibition's)
	if str(mv.get("source", "")) in TAC.get("corner", {}).get("full_relay_t3_opens", []) and not full_relay: return false   # PAC-081: North Star is the FULL RELAY's (NP_05 s10)
	if str(mv["tier"]) == "T4" and bout.size() > 0 and str(bout["kind"]) == "spar": return false   # s2.2: transforms locked in spars
	if str(mv["tier"]) == "T0" and not TECH.is_empty() and seg_idx < lineup.size() and not t0_open(pname()): return false   # PAC-091: NP_05 s3 - the T0 signature at level 5 (the motion is its punch)
	return true

func hiss_cost(mv: Dictionary) -> float:
	if mv.is_empty(): return 1e9
	var cost := float(mv["tension_cost"])
	if str(mv["tier"]) == "T0" and _pas(P, "cheap_trick"): cost = minf(cost, float(_pv("cheap_trick", "t0_cost", cost)))   # PAC-090: Cheap Trick (NP_11 s3)
	if str(mv["tier"]) == "T4" and full_relay: cost = float(TAC.get("corner", {}).get("full_relay_t4_cost", 75))   # FULL RELAY (s6)
	if states["P"].has("enemy_hissatsu_cost_plus10"): cost += 10.0
	if P["charge_t"] > 0 and hiss_casts_seg == 0: cost *= 0.5     # CHARGED: first hissatsu half cost (s6)
	if _beats("element", P["element"], B["element"]): cost *= float(AFF.get("element", {}).get("beats_cost_mult", 0.9))   # NP_06 s2.1
	return cost

func _family_row_matches(fam: String, row: String) -> bool:
	var fr: String = FAMILY_ROW.get(fam, "")
	return fr != "" and _punch_family(row) == _punch_family(fr)

func effect_coverage(lib: Dictionary) -> Dictionary:
	# static check for the smoke: every effect type, STATE name and BUFF name in the library has a handler
	var unknown := {}; var moves := 0; var sealed := 0
	for name in lib:
		moves += 1
		var m: Dictionary = lib[name]
		for e in m["effect"]:
			var t := str(e["type"]); var pr: Dictionary = e["params"]
			if not t in EFFECT_TYPES: unknown["type:" + t] = name; continue
			if t == "REDACTED": sealed += 1
			if t == "STATE" and not (str(pr["name"]) in STATE_SELF or str(pr["name"]) in STATE_TARGET): unknown["state:" + str(pr["name"])] = name
			if t == "BUFF" and not str(pr["name"]) in BUFF_NAMES: unknown["buff:" + str(pr["name"])] = name
		if not FAMILY_ROW.has(str(m["family"])): unknown["family:" + str(m["family"])] = name
	return {"moves": moves, "sealed": sealed, "unknown": unknown}

func _start_cast(who: String, mv: Dictionary, arm_only: String = "") -> void:
	var A: Dictionary = P if who == "P" else B
	var cost := 0.0
	if who == "P":
		cost = hiss_cost(mv); hiss_casts_seg += 1
		if _meter_pays(mv): tform["meter"] = maxf(0.0, float(tform["meter"]) - cost)                      # PAC-083/084: the private meter pays, not the team bar
		else: tension = maxf(0.0, tension - cost)
		P["cmd"] = {}; P["pending"] = {}
		seg_cast_houses.append(move_house(str(mv.get("name", ""))))                                      # PAC-077: STYLE_PROOF by a house's own moves
		_house_code_check(str(mv.get("name", "")))                                                      # PAC-077: the Reyes code
	else:
		cost = float(mv.get("tension_cost", 0)); btension = maxf(0.0, btension - cost)   # his bar pays what it can; the desperation is authored and always goes
	var total := ms(float(mv["startup_cinematic_ms"]))
	var cp: Dictionary = mv["counter_profile"]
	cast = {"who": who, "move": mv, "t": total, "total": total, "interruptible": bool(cp["interruptible"]),
		"window_t": ms(float(cp["window_ms"])), "cost": cost, "lunge_left": 0.5}
	if who == "P" and _meter_pays(mv): cast["purse"] = "meter"
	A["busy_t"] = maxi(A["busy_t"], total + ms(300)); A["dodge"] = ""; A["dodge_t"] = 0; A["dodge_plan"] = []; A["dodge_at"] = 0
	if who == "B":
		bstate = "CAST"; btimer = 1 << 30; bqueue = []; bpending = {}; B["pending"] = {}; bstring = ""
	var shown := arm_only if arm_only != "" else str(mv["name"])
	var ghost := ""
	if who == "P" and str(mv["tier"]) == "T3" and seg_idx > 0: ghost = str(lineup[seg_idx - 1]["name"])   # s7: the previous fighter joins as a spirit afterimage
	_ev("cast", {"who": who, "move": str(mv["name"]), "shown": shown, "tier": str(mv["tier"]), "family": str(mv["family"]),
		"windup": total, "interruptible": cast["interruptible"], "window": cast["window_t"], "arm_only": arm_only != "",
		"afterimage": ghost, "trail": full_relay and str(mv["tier"]) == "T3", "duo": str(mv.get("duo_pair", "")), "duo_of": str(mv.get("duo_of", "")), "vfx": str(mv.get("vfx_set", "")),
		"hybrid": str(mv.get("hybrid_of", "")), "hybrid_live": str(mv.get("hybrid_live", "")), "hybrid_partner": str(mv.get("hybrid_partner", "")), "hybrid_elements": _hyb_elements(mv),
		"duo_sync": str(mv.get("duo_sync", "")), "sync_partner": str(mv.get("sync_partner", "")), "sync_id": str(mv.get("duo_sync_id", ""))})
	if who == "P": _say("%s ARMS %s (%s %s, %d %s)%s%s%s" % [pname(), shown.to_upper(), mv["tier"], mv["family"], int(cost), ("from %s, %d left" % [_meter_word(), int(tform["meter"])]) if cast.has("purse") else "Tension", (" - DUO: %s's afterimage joins (%s)" % [str(mv["duo_partner"]), str(mv["duo_of"])]) if mv.has("duo_of") else "", (" - HYBRID of %s: %s" % [str(mv["hybrid_of"]).replace("|", " & "), _hyb_live_text(mv)]) if mv.has("hybrid_of") else "", (" - DUO SYNC with %s, in the ring beside him" % str(mv["sync_partner"])) if mv.has("duo_sync") else ""])
	if who == "P" and mv.has("hybrid_of"): _hyb_cast_note(mv)                                          # PAC-087: the registry counts it; its first dual is its debut
	else: _say("!! %s ARMS %s - %s" % [pattern.get("id", "boss"), shown.to_upper(), "jab him inside %dms to break it" % int(cp["window_ms"]) if cast["interruptible"] else "NOT interruptible: wall it, slip it, or wear it"])

func _cast_tick() -> void:
	# the cinematic: the caster closes half a metre over the windup, then the effect block resolves
	var who: String = cast["who"]
	var A: Dictionary = P if who == "P" else B
	var D: Dictionary = B if who == "P" else P
	cast["t"] = int(cast["t"]) - 1
	if float(cast["lunge_left"]) > 0.0 and A["pos"].distance_to(D["pos"]) > 1.2:
		var step_m := 0.5 / float(cast["total"])
		A["pos"] += (D["pos"] - A["pos"]).normalized() * step_m; _clamp(A)
		cast["lunge_left"] = float(cast["lunge_left"]) - step_m
	if int(cast["t"]) <= 0: _resolve_cast()

func _interrupt_cast(by: String) -> bool:
	# s9: a jab-class punch inside the profile's window cancels an interruptible cast;
	# the caster gets half the cost back, the interrupter +5 Tension and a flash window
	if cast.is_empty() or not cast["interruptible"]: return false
	if int(cast["total"]) - int(cast["t"]) > int(cast["window_t"]): return false
	var who: String = cast["who"]
	var mv: Dictionary = cast["move"]
	if who == "P" and str(cast.get("purse", "")) == "meter":                                             # PAC-083: the half back to the meter that paid (gone with the transformation)
		if tform.has("meter"): tform["meter"] = minf(float(tform["meter_max"]), float(tform["meter"]) + float(cast["cost"]) * 0.5)
	elif who == "P": tension = minf(100.0, tension + float(cast["cost"]) * 0.5)
	var A: Dictionary = P if who == "P" else B
	A["busy_t"] = ms(600)
	if who == "B": bstate = "RECOVER"; btimer = ms(800)
	if by == "P":
		_earn_tension(float(T.get("tension", {}).get("interrupt", 5))); P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"]))
	else: _earn_tension_b(float(T.get("tension", {}).get("interrupt", 5)))
	_ev("cast_interrupted", {"who": who, "move": str(mv["name"]), "by": by})
	_say("%s BROKEN - %s" % [str(mv["name"]).to_upper(), "flash window open, +5 Tension" if by == "P" else "you ate a jab in the windup, half the Tension back"])
	cast = {}
	return true

func _resolve_cast() -> void:
	var c := cast
	var who: String = c["who"]; var mv: Dictionary = c["move"]
	var A: Dictionary = P if who == "P" else B
	var D: Dictionary = B if who == "P" else P
	var hm := hiss_mult(who)                                  # the rings, read while the cast still knows its move
	if who == "B" and float(bmods["secret_power"]) < 1.0: hm *= float(bmods["secret_power"])   # Osei: the stolen secret fires at 70%
	cast = {}
	var flags := {"beats_duck": false, "echo": false, "range_plus": 0.0, "hm": hm}
	for e in mv["effect"]:                                   # instants that shape this cast are read first
		var pr: Dictionary = e["params"]
		if str(e["type"]) == "STATE" and str(pr["name"]) == "beats_duck_reads": flags["beats_duck"] = true
		if str(e["type"]) == "STATE" and str(pr["name"]) == "two_hit_echo": flags["echo"] = true
		if str(e["type"]) == "BUFF" and str(pr["name"]) == "range_plus": flags["range_plus"] = 0.5
	_ev("cast_resolve", {"who": who, "move": str(mv["name"])})
	# declaratives first (states, buffs, walls shape the packets), then the packets in data order
	var wf := float(_pv("wallflower", "t2_plus_s", 0)) if who == "P" and str(mv["tier"]) == "T2" and _pas(P, "wallflower") else 0.0   # PAC-090: Wallflower (NP_11 s3) - a timed T2 effect +1 s
	for e in mv["effect"]:
		var pr: Dictionary = e["params"]
		if wf > 0.0 and float(pr.get("seconds", 0)) > 0.0 and str(e["type"]) in ["STATE", "BUFF", "WALL"]:
			pr = pr.duplicate(); pr["seconds"] = float(pr["seconds"]) + wf
		match str(e["type"]):
			"STATE": _fx_state(who, str(pr["name"]), float(pr.get("seconds", 0)))
			"BUFF": _fx_buff(who, str(pr["name"]), pr)
			"WALL":
				var secs := float(pr["seconds"])
				if secs > 0.0 and _beats("element", A["element"], D["element"]): secs += float(AFF.get("element", {}).get("beaten_wall_plus_s", 1.0))   # s2.1: his walls stand longer against the element he beats
				var dsid := str(mv.get("duo_sync_id", ""))                                                    # PAC-088: a duo sync's wall is one gauge for the pair (Two-Hand Winter)
				if dsid != "" and str(wall[who].get("duo", "")) == dsid:
					_ev("duo_wall", {"who": who, "joined": true, "id": dsid, "pts": float(wall[who].get("pts", 0.0)), "shared": str(wall[who].get("shared", ""))})
					_say("%s's hands join the wall %s raised - one gauge, %d pts" % [pname(), str(mv.get("sync_partner", "the partner")), int(float(wall[who].get("pts", 0.0)))])
				else:
					if dsid == "" and wall[who].has("shared"): wall[who] = {}                              # a wall of his own leaves the shared gauge to the partner
					_fx_wall(who, float(pr["points"]) * hm, secs)
					if dsid != "":
						wall[who]["duo"] = dsid
						_ev("duo_wall", {"who": who, "joined": false, "id": dsid, "pts": float(wall[who]["pts"]), "shared": ""})
	for e in mv["effect"]:
		var pr: Dictionary = e["params"]
		match str(e["type"]):
			"DMG": _fx_dmg(who, A, D, mv, pr, flags)
			"DISPLACE": _fx_displace(who, A, D, {"toward": pr["toward"], "meters": float(pr["meters"]) * hm * (float(_zone_fx().get("displace_mult", 1.0)) if who == "P" and tform.size() > 0 else (float(_bfx().get("displace_mult", 1.0)) if who == "B" and btform.size() > 0 else 1.0))})   # PAC-083: the Manifest doubles it (PAC-086: his too)
			"SHRED": _fx_shred(D, float(pr["guard"]) * hm)
			"BURN": D["stamina"] = maxf(_sfloor(D), D["stamina"] - float(pr["stamina"]) * hm); _say("stamina burned -%d" % int(float(pr["stamina"]) * hm))
		if mode != "FIGHT": return
	A["busy_t"] = ms(300)
	if who == "B": bstate = "RECOVER"; btimer = ms(600)
	if who == "B" and float(bmods["stumble_ms"]) > 0.0:                                        # the visible stumble on the exit: a punish window
		B["guard_open_t"] = ms(float(bmods["stumble_ms"])); B["guard_t"] = 0; B["blocking"] = false
		_ev("stumble", {"ms": float(bmods["stumble_ms"]), "power": float(bmods["secret_power"])}); _say("she stumbles on the exit - the secret is half-learned: OPEN")
	_ev("cast_done", {"who": who, "move": str(mv["name"])})

func negation_rules(mv: Dictionary) -> Dictionary:
	# the counter profile's negation string is data; these are its four shapes (s9)
	var neg := str(mv["counter_profile"]["negation"])
	var r := {"slip_mult": 0.4, "block_mult": 0.6, "dodge_only": false, "shred": true}
	if "full evade" in neg: r["slip_mult"] = 0.0
	var rx := RegEx.new(); rx.compile("block (\\d+)%")
	var m := rx.search(neg)
	if m: r["block_mult"] = float(m.get_string(1)) / 100.0
	if "heavy shred" not in neg: r["shred"] = false
	if neg.begins_with("dodge-only"): r["dodge_only"] = true; r["block_mult"] = 1.0
	return r

func _fx_dmg(who: String, A: Dictionary, D: Dictionary, mv: Dictionary, p: Dictionary, flags: Dictionary) -> void:
	var dkey := "B" if who == "P" else "P"
	var row_name: String = FAMILY_ROW.get(str(mv["family"]), "")
	if row_name == "": return
	var row: Dictionary = T["punch_matrix"][row_name]
	var body: bool = str(p.get("target", "")) == "body"
	var hits: int = int(p.get("hits", 1)) * (2 if flags["echo"] else 1)
	var mult := float(p.get("mult", 1.0))
	if p.has("base"): mult = float(p["base"]) + float(p.get("mult_per_chain_link", 0.0)) * float(relay_chain)
	if p.has("mult_bonus_final_30s") and clock_t <= ms(30000): mult += float(p["mult_bonus_final_30s"])
	if p.get("zone_req") != null and zone(D["pos"]) != "ROPES" and zone(D["pos"]) != "CORNER":
		mult *= 0.5; _say("%s lands out of its zone - half power" % str(mv["name"]))
	var bypass := float(p.get("composure_bypass_pct", 0)) / 100.0
	var reach := float(GEO[_punch_family(row_name)]["reach"]) + 0.3 + float(flags["range_plus"])
	if A["pos"].distance_to(D["pos"]) > reach:
		_ev("cast_whiff", {"who": who, "move": str(mv["name"])}); _say("%s finds air - the range was the answer" % str(mv["name"])); return
	var tier_rank: int = TIER_RANK.get(str(mv["tier"]), 1)
	var nr := negation_rules(mv)
	var per_hit: float = float(row["dmg"]) * (float(A["stats"]["PWR"]) / 50.0) * mult * float(flags.get("hm", 1.0)) * (_manifest_dmg() if who == "P" else _bmanifest_dmg() * _weather_mult())   # PAC-083: x1.4 manifested; PAC-086: his, and weathered
	for h in hits:
		var dmg := per_hit; var outcome := "full"
		var w: Dictionary = wall[dkey]
		if w.size() > 0 and int(w.get("timed_t", 0)) > 0:
			dmg = 0.0
			if tier_rank >= 1:
				w["timed_t"] = 0; outcome = "wall_broken"; _ev("wall_broken", {"who": dkey, "by": str(mv["name"])})
				_say("%s BREAKS THE WALL at cost parity" % str(mv["name"]))
			else: outcome = "walled"
		elif D["dodge"] != "" and resolve_geometry(A, D, row_name, body) != "HIT" and not (flags["beats_duck"] and D["dodge"] == "DUCK"):
			dmg *= float(nr["slip_mult"]); outcome = "chip" if float(nr["slip_mult"]) > 0.0 else "evaded"   # the perfect slip
			if dkey == "P": P["counter_t"] = _window("slip")
		elif (D["blocking"] or int(D["guard_t"]) > 0) and int(D["guard_open_t"]) <= 0:
			var bm := float(nr["block_mult"])
			if nr["dodge_only"] and dkey == "P" and P["block_t"] <= ms(float(T["guard"]["perfect_block_window_ms"])): bm = 0.5   # weathering
			dmg = dmg * (1.0 - bypass) * bm + dmg * bypass; outcome = "blocked"
			if nr["shred"]: D["guard"] = D["guard"] - float(D["guard_max"]) * 0.5             # heavy shred
			if D["guard"] <= 0.0: D["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); D["guard_t"] = 0
		if outcome != "walled" and outcome != "wall_broken" and outcome != "evaded":
			dmg = _comp_damage(dkey, dmg, {"counter": false, "flash": false, "power": true, "body": body, "hissatsu": true, "jab": false})
			if body: D["stamina"] = maxf(_sfloor(D), D["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]))
			freeze_t = maxi(freeze_t, ms(float(T["hit_feel"]["hitstop_ms"]["flash_or_hissatsu"])))
			D["pos"] += (D["pos"] - A["pos"]).normalized() * 0.15; _clamp(D)
			_score_ep(who)
			if who == "P" and buffs["P"].has("tension_plus_on_hit"): _earn_tension(float(buffs["P"]["tension_plus_on_hit"]["v"]))
		_ev("hit", {"on": dkey, "dmg": dmg, "counter": false, "flash": false, "hissatsu": true, "body": body, "outcome": outcome, "move": str(mv["name"]), "n": h + 1})
		if D["comp"] <= 0.0:
			_drop(dkey == "P", false); return

func _fx_displace(who: String, A: Dictionary, D: Dictionary, p: Dictionary) -> void:
	var m := float(p["meters"])
	match str(p["toward"]):
		"ROPES": D["pos"] += _nearest_rope_dir(D["pos"]) * m
		"CORNER":
			var c := Vector2(1.0 if D["pos"].x >= 0.0 else -1.0, 1.0 if D["pos"].y >= 0.0 else -1.0).normalized()
			D["pos"] += c * m
		"CENTER": A["pos"] += (Vector2.ZERO - A["pos"]).limit_length(m)
	_clamp(D); _clamp(A); _separate()
	_ev("displace", {"who": who, "toward": str(p["toward"]), "m": m})

func _fx_state(who: String, name: String, seconds: float) -> void:
	var skey := who; var tkey := "B" if who == "P" else "P"
	var A: Dictionary = P if who == "P" else B
	var D: Dictionary = B if who == "P" else P
	var t := ms(seconds * 1000.0)
	if name in STATE_SELF:
		states[skey][name] = t
		match name:
			"counter_stance", "counter_state", "mirror_counter", "shell_counter", "counter_on_break_attempt":
				A["counter_state_t"] = t
				if who == "B": B["guard_t"] = t
			"angle_exit":
				var fwd: Vector2 = (D["pos"] - A["pos"]).normalized()
				A["pos"] += Vector2(-fwd.y, fwd.x) * seconds * (1.0 if rng.randf() < 0.5 else -1.0); _clamp(A)
			"averages_incoming_damage_over_duration": dmg_hist[skey] = []
	elif name in STATE_TARGET:
		states[tkey][name] = t
		match name:
			"wobble_on_gassed_target":
				if D["stamina"] < 40.0: D["comp"] = minf(D["comp"], D["comp_max"] * (float(T["composure"]["wobble_below_pct"]) - 1.0) / 100.0)
			"steals_charged_state":
				if tkey == "P" and P["charge_t"] > 0: P["charge_t"] = 0; t3_unlocked = false; _say("your CHARGED state is stolen")
			"suppress_commentary_ids": commentary_mute_t = t
	_ev("state", {"on": skey if name in STATE_SELF else tkey, "name": name, "t": t})

func _fx_buff(who: String, name: String, p: Dictionary) -> void:
	var t := ms(float(p.get("seconds", 0)) * 1000.0)
	var v := float(p.get("value", 0))
	buffs[who][name] = {"t": t if t > 0 else -1, "v": v}
	if name == "tension_plus_if_post_count" and who == "P" and P["no_regen_t"] > 0: _earn_tension(v)
	if name == "all_stats_r4r5_plus5" and seg_idx >= 3:
		var A: Dictionary = P if who == "P" else B
		for k in A["stats"]: A["stats"][k] = int(A["stats"][k]) + 5
	_ev("buff", {"on": who, "name": name, "t": t, "v": v})

func _fx_shred(D: Dictionary, n: float) -> void:
	D["guard"] = D["guard"] - n
	if D["guard"] <= 0.0 and int(D["guard_open_t"]) <= 0:
		D["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); D["guard_t"] = 0
		_say("GUARD SHREDDED - open")
	_ev("shred", {"n": n})

func _fx_wall(who: String, points: float, seconds: float) -> void:
	# a timed wall is untouchable for its seconds; a point wall is a mini Wall Gauge (one reform, s8)
	var w: Dictionary = wall[who] if wall[who].size() > 0 else {"pts": 0.0, "cap": 0.0, "reforms": [], "breaks": 0, "open_t": 0, "timed_t": 0, "migrate_at": -1.0}
	if seconds > 0.0: w["timed_t"] = ms(seconds * 1000.0)
	if points > 0.0: w["pts"] = points; w["cap"] = points; w["reforms"] = [points]
	wall[who] = w
	_ev("wall", {"who": who, "points": points, "seconds": seconds})
	_say("%s raises a WALL%s" % [pname() if who == "P" else str(pattern.get("id", "boss")), " (%ds)" % int(seconds) if seconds > 0.0 else " (%d pts)" % int(points)])

# ============================ WALL GAUGE (NP_05 s8) ========================
func _load_wall_gauge() -> void:
	var meta: Dictionary = pattern.get("meta", {})
	if meta.has("wall_gauge"):
		var reforms: Array = []
		for r in str(meta.get("gauge_reforms", "")).split(",", false): reforms.append(float(r))
		wall["B"] = {"pts": float(meta["wall_gauge"]), "cap": float(meta["wall_gauge"]), "reforms": reforms, "breaks": 0, "open_t": 0, "timed_t": 0, "migrate_at": -1.0}
	elif meta.has("migrant_wall"):
		wall["B"] = {"pts": float(meta["migrant_wall"]), "cap": float(meta["migrant_wall"]), "reforms": [], "breaks": 0, "open_t": 0, "timed_t": 0,
			"migrate_at": float(meta.get("migrates_to_next_at", -1))}
	elif wall_migrate > 0:
		wall["B"] = {"pts": float(wall_migrate), "cap": float(wall_migrate), "reforms": [], "breaks": 0, "open_t": 0, "timed_t": 0, "migrate_at": -1.0}
		_say("the wall followed him into the ring - %d pts carried over" % wall_migrate)
		wall_migrate = 0

func _gauge_factor(src: Dictionary) -> float:
	# s8: counters x1.0, power x0.8, body x0.6, hissatsu x1.5, jab-class 0 - everything else 0
	if src.get("hissatsu", false): return 1.5
	if src.get("counter", false) or src.get("flash", false): return 1.0
	if src.get("power", false): return 0.8
	if src.get("body", false): return 0.6
	return 0.0

func _comp_damage(dkey: String, dmg: float, src: Dictionary) -> float:
	# every composure hit goes through here: gauges absorb by source, TRUE OPEN amplifies, The Mean flattens
	var D: Dictionary = P if dkey == "P" else B
	var w: Dictionary = wall[dkey]
	if w.size() > 0 and float(w.get("pts", 0.0)) > 0.0:
		var f := _gauge_factor(src)
		var g := dmg * f
		w["pts"] = maxf(0.0, float(w["pts"]) - g)
		if f == 0.0 and src.get("jab", false) and dkey == "B":
			gauge_jabs += 1
			if gauge_jabs == 3: gauge_jabs = 0; _fire_event("player_jab_spam_on_gauge")
		elif g > 0.0: gauge_jabs = 0
		_ev("gauge", {"who": dkey, "dmg": g, "pts": w["pts"]})
		if float(w["pts"]) <= 0.0:
			w["breaks"] = int(w["breaks"]) + 1; w["open_t"] = ms(8000)
			_ev("gauge_break", {"who": dkey, "breaks": w["breaks"]})
			_say("WALL DOWN - %s is TRUE OPEN for 8s (x1.25)" % (pname() if dkey == "P" else str(pattern.get("id", "boss"))))
		elif float(w.get("migrate_at", -1.0)) > 0.0 and float(w["pts"]) <= float(w["migrate_at"]):
			wall_migrate = int(w["pts"]); wall[dkey] = {}
			_ev("gauge_migrate", {"who": dkey, "pts": wall_migrate})
			_say("the wall LEAVES him - it will meet you again (%d pts)" % wall_migrate)
		return 0.0
	if w.size() > 0 and int(w.get("open_t", 0)) > 0: dmg *= 1.25
	if states[dkey].has("averages_incoming_damage_over_duration") and int(states[dkey]["averages_incoming_damage_over_duration"]) > 0:
		var h: Array = dmg_hist[dkey]
		if h.size() > 0:
			var sum := 0.0
			for x in h: sum += float(x)
			dmg = minf(dmg, sum / h.size())
	if _tx(D, "load_bearing") > 0 and zone(D["pos"]) in HOUSES["traits"]["load_bearing"]["zones"]:       # PAC-078: Load-Bearing - a pool 20% deeper on the ropes and in the corner
		dmg /= _tmult(float(HOUSES["traits"]["load_bearing"]["comp_pool_mult"]), _tx(D, "load_bearing"), D)
	D["comp"] = D["comp"] - dmg
	dmg_hist[dkey].append(dmg)
	return dmg

func _walled(dkey: String, row: String, body: bool) -> bool:
	# a timed wall stops the punch cold; a wall with counter_on_break_attempt answers it
	var w: Dictionary = wall[dkey]
	if w.size() == 0 or int(w.get("timed_t", 0)) <= 0: return false
	_ev("walled", {"who": dkey, "row": row})
	if dkey == "B":
		B["blocking"] = false
		if states["B"].has("counter_on_break_attempt"): _counter_state_trigger()
	elif P["counter_state_t"] > 0 and states["P"].has("counter_on_break_attempt"):
		P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0
	return true

func _auto_slips(dkey: String, row: String, body: bool) -> bool:
	if dkey == "B" and btform.size() > 0 and float(_bfx().get("auto_slip_every_s", 0.0)) > 0.0:         # PAC-086: his Zone slips the first punch of every 3 s
		var bwin: int = (tick - int(btform["t0"])) / maxi(1, ms(float(_bfx()["auto_slip_every_s"]) * 1000.0))
		if bwin != int(btform["slip_win"]):
			btform["slip_win"] = bwin
			_ev("evade", {"by": "B", "why": "ZONE_SLIP", "dodge": "AUTO", "window": bwin}); return true
	if dkey == "P" and tform.size() > 0 and float(_zone_fx().get("auto_slip_every_s", 0.0)) > 0.0:        # PAC-082: the Zone slips the first incoming punch of every 3 s
		var win: int = (tick - int(tform["t0"])) / maxi(1, ms(float(_zone_fx()["auto_slip_every_s"]) * 1000.0))
		if win != int(tform["slip_win"]):
			tform["slip_win"] = win
			_ev("evade", {"by": "P", "why": "ZONE_SLIP", "dodge": "AUTO", "window": win}); return true
	if not states[dkey].has("auto_slip") or int(states[dkey]["auto_slip"]) <= 0: return false
	_ev("evade", {"by": dkey, "why": "AUTO_SLIP", "dodge": "AUTO"})
	return true

func _earn_tension(v: float) -> void:
	if states["P"].has("enemy_tension_earn_minus25pct"): v *= 0.75
	if _pas(P, "sparkplug"): v *= float(_pv("sparkplug", "tension_earn_mult", 1.0))                     # PAC-090: Sparkplug (NP_11 s3) - his personal contribution
	v *= _gear_mult(P, "tension_earn")                                                                 # PAC-094: his robe (the walk-out's)
	v *= float(tactic_fx.get("tension_earn_mult", 1.0))
	if aff.get("feud", false): v *= float(AFF.get("house", {}).get("feud_tension_mult", 1.25))   # NP_06 s3: feuds are Tension geysers
	if delegated: v *= float(TAC.get("corner", {}).get("delegated_tension_pct", 85)) / 100.0   # NP_10 s8: AI segments earn 85%
	if bout.size() > 0 and str(bout["kind"]) == "scrap": return                                  # NP_02 s2.1: scraps run no meter
	var cap := float(BOUTS.get("spar", {}).get("tension_cap", 50)) if (bout.size() > 0 and str(bout["kind"]) == "spar") else 100.0   # s2.2: the personal meter at 50
	tension = minf(cap, tension + v); contributed += v

func _wall_tick() -> void:
	for k in ["P", "B"]:
		var w: Dictionary = wall[k]
		if w.size() == 0: continue
		if str(w.get("shared", "")) != "" and str(w["shared"]) != exhibit: continue                   # PAC-088: Two-Hand Winter's one gauge - the pair that owns it runs its clocks
		if int(w.get("timed_t", 0)) > 0:
			w["timed_t"] = int(w["timed_t"]) - 1
			if int(w["timed_t"]) == 0: _ev("wall_down", {"who": k}); _say("the wall comes down")
		if int(w.get("open_t", 0)) > 0:
			w["open_t"] = int(w["open_t"]) - 1
			if int(w["open_t"]) == 0:
				var reforms: Array = w["reforms"]
				if reforms.size() > 0:
					var cap: float = float(reforms.pop_front()); w["pts"] = cap; w["cap"] = cap
					_ev("gauge_reform", {"who": k, "pts": cap}); _say("the wall REFORMS at %d" % int(cap))
				else:
					_ev("gauge_gone", {"who": k}); _say("the wall is GONE for good")
	for k in ["P", "B"]:
		for n in states[k].keys():
			if int(states[k][n]) > 0:
				states[k][n] = int(states[k][n]) - 1
				if int(states[k][n]) == 0: states[k].erase(n)
		for n in buffs[k].keys():
			if int(buffs[k][n]["t"]) > 0:
				buffs[k][n]["t"] = int(buffs[k][n]["t"]) - 1
				if int(buffs[k][n]["t"]) == 0: buffs[k].erase(n)
	if commentary_mute_t > 0: commentary_mute_t -= 1

func _speed_mult(k: String) -> float:
	var m := 1.0
	if P["charge_t"] > 0 and k == "P": m *= 1.0 + float(TAC.get("corner", {}).get("charged_stat_pct", 10)) / 100.0   # CHARGED entrance surge
	if k == "B" and int(B.get("charge_t", 0)) > 0: m *= 1.0 + float(TAC.get("corner", {}).get("charged_stat_pct", 10)) / 100.0
	if k == "B": m *= float(bmods["move"])                                                # a phase's "movement +10pct"
	if states[k].has("foot_freeze_slow") or states[k].has("foot_slow"): m *= 0.6
	if buffs[k].has("forward_glide"): m *= 1.5
	if buffs[k].has("move_speed_plus15"): m *= 1.15
	return m

# ============================ REFEREE (NP_01 s5) ===========================
func _warning_cap() -> int:
	# dirty archetypes flirt with warnings on purpose: META warnings_banked=N is
	# how many this boss will bank, never the next one. Clean fighters: 0.
	return int(pattern.get("meta", {}).get("warnings_banked", 0))

func _foul(who: String, kind: String) -> void:
	# the ladder, both ways: warning -> -5 EP -> a DROP awarded to the opponent
	# from the third on. No DQ in normal play.
	var n := 0
	if who == "B": bwarnings += 1; n = bwarnings
	else: pwarnings += 1; n = pwarnings
	_ev("foul", {"who": who, "foul": kind, "n": n})
	var name := str(pattern.get("id", "the boss")) if who == "B" else pname()
	var what := kind.replace("_", " ")
	match n:
		1: _say("REFEREE: warning, %s - %s (1)" % [name, what])
		2:
			if who == "B": ep_b -= 5
			else: ep_p -= 5
			_say("REFEREE: second warning, %s - %s, 5 EP deducted (2)" % [name, what])
		_:
			if who == "B": drops_p += 1; score_p += 1
			else: drops_b += 1; score_b += 1
			_ev("drop", {"who": who, "flash": false, "awarded": true})
			_say("REFEREE: %s again (%d) - DROP awarded to %s" % [what, n, pname() if who == "B" else str(pattern.get("id", "the boss"))])

func _boss_foul_on_break() -> void:
	if bwarnings >= _warning_cap(): return
	_foul("B", "behind_the_head")

func _player_holding_call() -> void:
	pholding += 1; ep_p -= 2
	_ev("referee", {"who": "P", "call": "holding"})
	_say("REFEREE: break! holding without work - 2 EP deducted")

# ============================ BOSS AGENT ===================================
func _phase_trigger_met(trig: String) -> bool:
	if "composure<" in trig:
		var n := float(trig.split("composure<")[1].split(" ")[0].replace(":", ""))
		return B["comp"] <= B["comp_max"] * n / 100.0
	if "clock>" in trig:
		var n2 := float(trig.split("clock>")[1].rstrip("s").split(" ")[0].replace(":", ""))
		return (ms(90000) - clock_t) > ms(n2 * 1000.0)
	if "player_stamina<" in trig:
		return P["stamina"] < float(trig.split("player_stamina<")[1].split(" ")[0])
	if "player_ropes_time>" in trig:
		return rope_time_t > ms(float(trig.split("player_ropes_time>")[1].rstrip("s")) * 1000.0)
	if "wall_broken" in trig:
		return B["guard_open_t"] > 0 or wall_broken
	if "warnings_banked==" in trig:
		return bwarnings >= int(trig.split("warnings_banked==")[1].split(" ")[0])
	return false                                    # unsupported trigger vocabulary: reported by phase_coverage()

func phase_coverage(pats: Dictionary) -> Dictionary:
	var known := {}; var unknown := {}
	for name in pats:
		for ph in pats[name].get("phases", []):
			var t := str(ph["trigger"])
			var ok := false
			for k in ["composure<", "clock>", "player_stamina<", "player_ropes_time>", "wall_broken", "warnings_banked=="]:
				if k in t: ok = true
			if ok: known[t] = true
			else: unknown[t] = name
	return {"known": known.keys(), "unknown": unknown}

func _boss_step() -> void:
	if not B["pending"].is_empty():
		B["pending"]["t"] -= 1
		if int(B["pending"]["t"]) <= 0 and not B["pending"].get("trajectory",false):
			var delivered: Dictionary = B["pending"]; B["pending"] = {}
			bpending = {"row":delivered["row"], "body":delivered["body"]}
			_ev("boss_act", {"verb":"punch", "row":delivered["row"], "body":delivered["body"], "recovery":delivered["recovery"]})
			_land_boss_punch(float(delivered["mult"]))
			if mode != "FIGHT": return
	_corner_intel_tick()
	if neutral_on and bool(bidle.get("authored", false)): _neutral_clock()
	var phases: Array = pattern.get("phases", [])
	for pi_ in phases.size():
		var ph: Dictionary = phases[pi_]
		var target := pi_ + 2                                                        # a named phase ("finale") sits after the numbered ones: its number is its place
		if str(ph["phase"]).is_valid_int(): target = int(ph["phase"])
		if _phase_trigger_met(str(ph["trigger"])) and target > bphase:
			bphase = target
			_ev("phase", {"phase": bphase})
			_say("PHASE %d - he's changing" % bphase)
			_apply_phase_reweights(bphase)                                                     # the SELECT block's phase lines
			_apply_directives(ph.get("directives", []), "phase %d" % bphase)                # NP_04 s6: the directive lines execute
	if _boss_transform_check() or btsurge.size() > 0: return                                        # PAC-086: his authored transformation - gathering, nothing else
	var d: Dictionary = pattern.get("desperation") if pattern.get("desperation") != null else {}
	var desp_pct := 25.0
	if d.has("trigger") and "composure<" in str(d["trigger"]): desp_pct = float(str(d["trigger"]).split("composure<")[1])
	if not bdesp_used and d.has("move") and B["comp"] <= B["comp_max"] * desp_pct / 100.0 and cast.is_empty() and clinch.is_empty() and _desperation_allowed():
		bdesp_used = true
		var mv_b: Dictionary = library.get(str(d["move"]), {})
		if mv_b.is_empty():
			_say("(desperation %s is not in the library)" % str(d["move"])); return
		_start_cast("B", mv_b, str(d.get("arm_only", "")) if d.get("arm_only") != null else "")
		return
	btimer -= 1
	if P.has("body_control") and bstate == "ACTING" and B.get("boxing",{}).get("sequence_wait",false) and not bqueue.is_empty() and bqueue[0].get("kind","") == "punch":
		# Only the physical recovery wait can yield to a follow-up. Authored
		# pauses, tells and other VM actions retain their own clocks.
		var readiness := PunchContact.transition(B,str(bqueue[0]["row"]))
		if readiness["allowed"]: btimer = 0
		elif btimer <= 0: btimer = 1
	if btimer > 0: return
	match bstate:
		"IDLE", "RECOVER":
			if B.has("synth") and _synth_try(): return                                                   # PAC-092: an academy prodigy's synthesis, from his bar
			# Marta's inverted bait: with the player refusing to lead, she drops her hands
			if _has_bait("trap_stance_hands_down") and passive_t >= ms(3000) and hands_down_t == 0 and rng.randf() < 0.5:
				hands_down_t = ms(2500); btimer = hands_down_t + 1; bstate = "IDLE"
				_ev("stance", {"hands_down": true}); _say("she drops her hands - it's an invitation")
				return
			var w: Dictionary = _select_weights()
			if w.is_empty(): btimer = ms(200); return                                   # nothing selectable (every string cooled or retired): wait
			var total := 0
			for k in w: total += w[k]
			var r := rng.randf() * total
			for k in w:
				r -= w[k]
				if r <= 0.0: bstring = k; break
			# Priya's tape observation is executable pattern data: a right lead on
			# every third exchange. Only a pattern explicitly carrying a cycle uses it.
			var cycle: Array = pattern.get("select", {}).get("cycle", [])
			if not cycle.is_empty():
				var cycle_index := int(pattern["select"].get("cycle_index", 0))
				var scheduled := str(cycle[cycle_index % cycle.size()])
				if w.has(scheduled):
					bstring = scheduled; pattern["select"]["cycle_index"] = cycle_index + 1
			var s: Dictionary = pattern["strings"][bstring]
			if bmods["cooldown_ms"].has(bstring): bcooldown_until[bstring] = tick + ms(float(bmods["cooldown_ms"][bstring]))   # Marta's greedy Mirror
			# Tam's borrowed clothes: some tells are performances with nothing behind them, until the phase line says true pattern only
			if _has_bait("reacts_to_fake_tell") and not btrue_pattern and rng.randf() < 0.35:
				bstate = "FAKE"; bforce_opts = {}; btimer = ms(float(s["tell"]["ms"]))
				_ev("tell", {"ticks": btimer, "loud": s["class"] != "normal", "string": bstring, "fake": true, "cue": pi_cue()})
				return
			bfeint = ""                                                                  # NP_04 s6 feint(Sx): the tell plays; the attack comes late, or another string's
			if s.has("feint"):
				var fv: Dictionary = s["feint"]
				var fpct: float = 1.0 if (int(fv.get("burn_after", 0)) > 0 and int(binterrupts.get(bstring, 0)) >= int(fv["burn_after"])) else float(fv.get("pct", 0.0))
				if fpct >= 1.0 or (fpct > 0.0 and rng.randf() < fpct): bfeint = str(fv.get("mode", "delay"))
			bstate = "TELL"; bforce_opts = {}; btimer = int(ms(float(s["tell"]["ms"])) * _tell_mult())
			if bdesync_widen: btimer += ms(float(REMIX.get("desync", {}).get("widen_ms", 100))); bdesync_widen = false   # the desync reward: her next tell is wider
			tell_start_tick = tick; tell_reacted = false
			_ev("tell", {"ticks": btimer, "loud": s["class"] != "normal", "string": bstring, "jammed": states["P"].has("tell_jam_audio") or states["P"].has("tell_jam_visual"), "highlight": tell_highlight_t > 0,
				"shout": "shout" in str(s.get("tell", {}).get("motif", "")), "cue": pi_cue(), "variant": bfeint, "assist": _tell_assist(bstring)})
		"FAKE":
			bstate = "RECOVER"; btimer = ms(300); bstring = ""
			_ev("recover", {})
		"CAST":
			btimer = 1 << 30                                 # the cast tick drives this; resolve sets RECOVER
		"SURGE":
			btimer = 1 << 30                                 # PAC-086: his gathering's clock (fight time) drives this
		"TELL":
			if bstring != "" and bfeint == "delay":                                     # the feint's hitch: the tell is over, the shot is late
				bstate = "HOLD"; btimer = maxi(1, ms(float(pattern["strings"][bstring]["feint"].get("ms", 300))))
				_ev("feint_b", {"string": bstring, "mode": "delay", "ms": float(pattern["strings"][bstring]["feint"].get("ms", 300))})
				return
			if bstring != "":
				bqueue = []
				bqueue.append_array(bforce_opts.get("pre", []))
				var src_s := bstring
				if bfeint == "cancel":                                                   # the tell was one string's; the hands are another's
					var into := str(pattern["strings"][bstring]["feint"].get("into", ""))
					if pattern["strings"].has(into): src_s = into
					_ev("feint_b", {"string": bstring, "mode": "cancel", "into": src_s})
				for a in pattern["strings"][src_s]["actions"]:
					bqueue.append_array(parse_action(str(a)))
				bqueue.append_array(bforce_opts.get("post", []))
				_override_states(src_s)
			bfeint = ""
			bstate = "ACTING"; btimer = 0
			return
		"HOLD":
			bqueue = []
			if bstring != "":
				for a in pattern["strings"][bstring]["actions"]:
					bqueue.append_array(parse_action(str(a)))
				_override_states(bstring)
			bfeint = ""
			bstate = "ACTING"; btimer = 0
			return
		"ACTING":
			if bqueue.is_empty():
				bstate = "RECOVER"; bforce_opts = {}
				if float(bmods["metronome_ms"]) > 0.0: btimer = maxi(1, int(ms(float(bmods["metronome_ms"])) / _bspeed()))       # Ada: the beat itself
				elif bmods["tempos"].size() > 0:                                                                                   # Chiamaka: two beats, alternating
					btimer = maxi(1, int(ms(float(bmods["tempos"][btempo_i % bmods["tempos"].size()])) / _bspeed())); btempo_i += 1
				elif float(bmods["recover_ms"]) > 0.0: btimer = maxi(1, int(ms(float(bmods["recover_ms"])) / _bspeed()))          # Deshawn: no idle weight, always mid-string
				else: btimer = maxi(1, int(ms(400 + rng.randi_range(0, 400)) * _idle_tempo() / _bspeed()))          # Tam: the tempo he is on scales the gap
				bstrings_done += 1
				if int(bmods["splice_every"]) > 0 and bstrings_done % int(bmods["splice_every"]) == 0:                                        # Echo: the machine-spliced gap is an OPEN window
					B["guard_open_t"] = ms(float(bmods["splice_open_ms"])); B["guard_t"] = 0; B["blocking"] = false
					_ev("splice_open", {"after": bstrings_done, "ms": float(bmods["splice_open_ms"])}); _say("the splice shows - he's OPEN")
				_ev("recover", {})
				return
			var atk: Dictionary = bqueue.pop_front()
			btimer = _boss_act(atk)

# ============================ STEP =========================================
func step(inp: Dictionary) -> void:
	_step_inner(inp)
	if bout.size() > 0 and mode != "OVER":
		if "infinite_stamina" in lab: P["stamina"] = 100.0                  # the combo lab
		if obj.size() > 0:
			if mode == "FIGHT" and not obj["met"] and not obj["failed"]: TNBObjectives.check(self, obj)
			if (obj["met"] or obj["failed"]) and str(bout["kind"]) == "scrap":
				_ev("objective", {"id": str(obj["id"]), "met": obj["met"], "why": str(obj["why"])})
				_say("OBJECTIVE %s - %s" % ["MET" if obj["met"] else "FAILED", str(obj["why"])])
				P["pending"] = {}; bpending = {}; B["pending"] = {}; eight = {}; cast = {}; clinch = {}; clinch_t = 0
				_end_bout()
	if mode in ["CARD","OVER"] and P.get("boxing",{}).has("count_down"):
		# A knockout must finish falling on the result card, not snap upright
		# when the count mode ends. New segment construction owns the reset.
		var age := int(P["boxing"].get("count_age",0))+1
		P["boxing"]["count_age"] = age; B["boxing"]["count_age"] = age
		_boxing_recovery_pose("P" if P["boxing"]["count_down"] else "B",PunchContact.Motion.ramp(float(age)/90.0))
	elif (mode != "FIGHT" and not (mode == "EIGHT" and eight.get("native",false))) or not clinch.is_empty():
		# A count, break, or clinch ends an uncompleted pocket step. Its old
		# travel/queued stroke must not resume after the restart bell.
		for fighter in [P, B]:
			fighter.erase("frozen_step"); fighter.erase("body_control"); fighter.erase("boxing")

func _step_inner(inp: Dictionary) -> void:
	tick += 1
	if inp.get("flee", false) and str(bout.get("kind", "")) == "scrap" and mode != "OVER":                # PAC-101: NP_02 s2.1 - the scrap walked away from (the player's, delegated or not)
		flee(); return
	if delegated and (mode == "FIGHT" or mode == "EIGHT"):
		var native_profile := P.has("body_control") or inp.has("body_axis") or inp.has("pocket_step")
		inp = TNBProfile.intent(self, inp)                  # the card plays; the corner keys pass through
		if inp.has("punch"):
			auto_stats["punches"] += 1
			auto_stats["rows"][str(inp["punch"])] = int(auto_stats["rows"].get(str(inp["punch"]), 0)) + 1
			if inp.get("body", false): auto_stats["body"] += 1
			if inp.get("power", false): auto_stats["power"] += 1
		if mode == "FIGHT": auto_stats["dist_sum"] = float(auto_stats["dist_sum"]) + P["pos"].distance_to(B["pos"]); auto_stats["dist_n"] += 1
		if inp.has("dodge"): auto_stats["dodges"] += 1
		if inp.get("block", false) and not block_prev: auto_stats["blocks"] += 1
		if inp.has("punch") and (bstate == "TELL" or bstate == "FAKE"): auto_stats["tell_jabs"] += 1
		if inp.get("punch_release", false): auto_stats["feints"] += 1
		if inp.get("lb", false) and inp.has("punch"): auto_stats["casts"] += 1
		if inp.get("clinch", false): auto_stats["grabs"] += 1
		if inp.get("sprint", false): auto_stats["sprints"] += 1
		if native_profile and mode == "FIGHT":
			# Existing card tactics choose direction/range; the native controller
			# still owns the actual step, support, effort and recovery.
			var travel: Vector2 = inp.get("move",Vector2.ZERO)
			inp["body_axis"] = Vector2(travel.x,0) if not clinch.is_empty() else Vector2.ZERO
			var body: Dictionary = P.get("body_control",{})
			if clinch.is_empty() and travel.length() > 0.1 and body.get("step",{}).is_empty() and body.get("queued",{}).is_empty() and body.get("gait",{}).is_empty() and float(body.get("recovery",0)) <= 0 and float(P["stamina"]) >= BodyControl.STEP_COST and PunchContact.transition(P,"EXIT")["allowed"]:
				inp["pocket_step"] = Vector2(travel.x,-travel.y).normalized()
				var band: Array = TNBProfile.RANGE.get(str(P.get("style","BOXERPUNCHER")),TNBProfile.RANGE["BOXERPUNCHER"])
				var resting := 0.6 if auto.get("resting",false) else 0.0
				var distance: float = P["pos"].distance_to(B["pos"])
				var correction: float = distance-float(band[1])-resting if travel.y < 0 else float(band[0])+resting-distance
				if absf(travel.y) > 0.1 and correction > 0: inp["pocket_step_distance"] = minf(BodyControl.STEP_M,maxf(0.08,correction))
			inp.erase("move");inp.erase("sprint")
	if mode == "CARD":
		card_t -= 1
		if int(inp.get("corner", 0)) > 0 or card_t <= 0: _open_corner()
		return
	if mode == "CORNER":
		corner["t"] = int(corner["t"]) - 1
		var act = inp.get("corner_action", null)
		if act is Dictionary: corner_action(act)
		if mode == "CORNER" and int(inp.get("corner", 0)) > 0: _send_next(false)
		elif mode == "CORNER" and int(corner["t"]) <= 0: _send_next(true)
		return
	if mode == "OVER":
		if inp.has("approach"): approach(str(inp["approach"]))                                             # between duals: the overworld's approach and the recruit's answer (PAC-075)
		if inp.has("recruit"): recruit(str(inp["recruit"]))
		if inp.has("renovate") and (str(inp["renovate"]) != "*" or renovate_ready() != ""): renovate(str(inp["renovate"]))   # PAC-089: the overworld's renovation (the aid: the first ready)
		if inp.has("train") and training_best(str(stable[0]["name"]) if stable.size() > 0 else "") != "": train("*", "*", float(inp["train"]))   # ...and a training slot (the aid's grade)
		if inp.has("grow"): grow_aid(str(inp["grow"]))                                                   # PAC-090: the aid's growth (a node, a raise, an ascension)
		if inp.has("teach"): teach_aid(str(inp["teach"]))                                                # PAC-091: the aid's techniques (a lesson, a tape, a buy, a re-teach)
		if inp.has("gear"): gear_aid(str(inp["gear"]))                                                   # PAC-094: the aid's gear (the shop's pick, what fits)
		if inp.has("scout"):                                                                              # PAC-098: the machine fed (n pulls, while the ledger affords them)
			for si in int(inp["scout"]):
				if scout_why() != "" or not bool(scout_pull()["ok"]): break
		if inp.has("sign"):                                                                               # PAC-098: the open mat's first signs (PAC-099: n of them for a whole number)
			for si2 in (int(inp["sign"]) if inp["sign"] is int else 1):
				if open_mat().size() == 0 or sign_why(0) != "": break
				sign_generic(0)
		if inp.has("role"):                                                                               # PAC-099: NP_08 s1 - the aid's roles for the bench (n picks, while anyone sits)
			for ri in int(inp["role"]):
				if role_pick().is_empty() or not bool(assign_role("*")["ok"]): break
		if inp.has("release"):                                                                            # PAC-100: NP_08 s4 - the aid releases the last card on the bench it can (n of them)
			for rli in (int(inp["release"]) if inp["release"] is int else 1):
				if release_pick() == "" or not bool(release("*")["ok"]): break
		if inp.has("take_back") and rewards.get("locker", {}).get("pending", {}).size() > 0 and take_back_why(str(rewards["locker"]["pending"].keys()[rewards["locker"]["pending"].size() - 1])) == "": take_back("*")
		if inp.has("story") and not _story_set(str(inp["story"])): story_mark(str(inp["story"]))          # PAC-102: the overworld's story beat on the log (an arc's turn)
		if inp.get("academy", false) and not academy_on and academy_taken().size() > 0: field_academy(true)   # PAC-102: Arc 3 - the academy with the rivals it signed
		if inp.has("day"):                                                                                # PAC-099: the overworld's days turn (the scouts' Prestige with them)
			for di in int(inp["day"]): new_day()
		if inp.has("mirror") and mirror_aid(str(inp["mirror"])): return                                    # PAC-093: the aid's mirror spar between duals, then back
		if inp.get("restart", false): new_dual()
		return
	if mode == "EIGHT":
		_eight_step(inp.get("rise", false)); return
	if mode == "CLASH":
		_clash_step(inp); return                                                                        # PAC-086: the Manifest Clash - the fight waits
	if freeze_t > 0:
		freeze_t -= 1                                       # C5 hitstop: everyone frozen...
		var frozen_pr: String = inp.get("punch", "")
		if frozen_pr != "": _queue_punch(frozen_pr, inp)    # ...but the buffer (C3) never eats an input
		if inp.has("pocket_step"):
			# Keep one fresh intent without advancing the frozen body/support clock.
			P["frozen_step"] = {"direction": inp["pocket_step"], "remaining": BodyControl.STEP_BUFFER_SECONDS}
		return
	clock_acc += 1.0
	if tactic_fx.has("clock_mult_leading") and (ep_p - int(seg_score0[2])) > (ep_b - int(seg_score0[3])):
		clock_acc += 1.0 / float(tactic_fx["clock_mult_leading"]) - 1.0          # ICE THE CLOCK: it runs 1/0.8 faster while you lead
	if btactic_fx.has("clock_mult_leading") and (ep_b - int(seg_score0[3])) > (ep_p - int(seg_score0[2])):
		clock_acc += 1.0 / float(btactic_fx["clock_mult_leading"]) - 1.0         # ...or while his corner iced it and he leads
	while clock_acc >= 1.0:
		clock_acc -= 1.0; clock_t -= 1
	# ---- timers/regen ----
	_wall_tick()
	for F in [P, B]:
		var fk := "P" if F == P else "B"
		var guarding: bool = bool(inp.get("block", false)) if F == P else (bool(F["blocking"]) or int(F["guard_t"]) > 0)
		var body_active: bool = Vector2(F.get("body_control", {}).get("axis", Vector2.ZERO)).length() > 0.02 or not F.get("body_control", {}).get("step", {}).is_empty()
		var acting: bool = F["busy_t"] > 0 or guarding or int(F["dodge_t"]) > 0 or body_active
		if F["busy_t"] > 0: F["busy_t"] -= 1
		var sreg := 1.0
		if buffs[fk].has("stamina_regen_x2"): sreg = 2.0
		elif buffs[fk].has("stamina_regen_x1_5"): sreg = 1.5
		if F == P: sreg *= 1.0 + float(staff_fx.get("stamina_regen_pct", 0.0)) / 100.0                 # NP_10 s6: the conditioning coach
		F["stamina"] = minf(stamina_cap if F == P else 100.0, F["stamina"] + float(T["stamina"]["regen_active_per_s"] if acting else T["stamina"]["regen_neutral_per_s"]) * sreg * DT)
		if F["no_regen_t"] > 0: F["no_regen_t"] -= 1
		else: F["comp"] = minf(F["comp_max"], F["comp"] + float(T["composure"]["regen_per_s"]) * float(_gassed(F)["composure_regen"]) * DT / (float(_pv("iron_jaw", "wobble_time_mult", 1.0)) if _pas(F, "iron_jaw") and _wobbled(F) else 1.0) / (_gear_mult(F, "wobble_time") if _wobbled(F) else 1.0))   # PAC-090: Iron Jaw - out of the wobble in 70 % of the time (PAC-094: his mouthguard)
		if F["guard_open_t"] > 0:
			F["guard_open_t"] -= 1
			if F["guard_open_t"] <= 0: F["guard"] = float(T["guard"]["break_refill"])
		if F["dodge_t"] > 0:
			F["dodge_t"] -= 1
			if F["dodge_t"] <= 0: F["dodge"] = ""
		if F["dodge_at"] > 0:
			F["dodge_at"] -= 1
			if F["dodge_at"] <= 0 and F["dodge_plan"].size() == 2:
				_set_dodge(F, F["dodge_plan"][0], F["dodge_plan"][1]); F["dodge_plan"] = []
		if F["counter_t"] > 0: F["counter_t"] -= 1
		if F["guard_t"] > 0: F["guard_t"] -= 1
		if F["counter_state_t"] > 0: F["counter_state_t"] -= 1
		if F["flash_t"] > 0: F["flash_t"] -= 1
		if F["charge_t"] > 0: F["charge_t"] -= 1
		if F["cmd"].size() > 0:
			F["cmd"]["expire_t"] -= 1
			if F["cmd"]["expire_t"] <= 0:
				if F.has("body_control"): _ev("punch_intent",{"row":F["cmd"]["row"],"outcome":"expired","reason":"window_closed"})
				F["cmd"] = {}
	_tracker_tick()
	_zone_tick()                                                                                        # PAC-082: the Zone's clock, its frozen stamina, the Comedown
	if mode != "FIGHT": return
	_btform_tick()                                                                                      # PAC-086: his gathering, his transformation, his Comedown, the Clash
	if mode != "FIGHT": return
	for k in punish_cd.keys(): punish_cd[k] = maxi(0, punish_cd[k] - 1)
	if taunt_t > 0: taunt_t -= 1
	if clinch_t > 0: clinch_t -= 1
	if swap_restore.size() > 0:
		swap_restore["t"] -= 1
		if swap_restore["t"] <= 0:
			var wa = pattern["select"]["weights"][swap_restore["a"]]
			pattern["select"]["weights"][swap_restore["a"]] = pattern["select"]["weights"][swap_restore["b"]]
			pattern["select"]["weights"][swap_restore["b"]] = wa
			swap_restore = {}
	if sprint_cd > 0: sprint_cd -= 1
	if neutral_cd > 0: neutral_cd -= 1
	if no_drop_t > 0: no_drop_t -= 1
	if bno_drop_t > 0: bno_drop_t -= 1
	if punish_suppress_t > 0: punish_suppress_t -= 1
	if tell_highlight_t > 0: tell_highlight_t -= 1
	if hands_down_t > 0:
		hands_down_t -= 1
		if hands_down_t == 0: _ev("stance", {"hands_down": false})
	audio_assist = inp.get("audio_assist", false)
	if inp.get("surge", false): transform()                                                             # PAC-082: the SURGE motion (NP_09 s1)
	# ---- clinch input: the holding call is on repeated grabbing, in or out of a scramble ----
	if inp.get("clinch", false):
		clinch_ticks.append(tick)
		while clinch_ticks.size() > 0 and tick - int(clinch_ticks[0]) > ms(8000): clinch_ticks.pop_front()
		if clinch_ticks.size() >= 3:
			clinch_ticks = []
			_fire_event("player_clinch_input_spam"); _player_holding_call()
		elif clinch.is_empty() and B["pos"].distance_to(P["pos"]) <= 1.3:
			_start_clinch("P")
	if clinch.size() > 0:
		_clinch_step(inp)
		return
	# ---- sensors the pattern hooks ask for ----
	passive_t += 1
	if passive_t == ms(float(sensors["passive_s"]) * 1000.0): _fire_event("player_passive")
	clean_t += 1
	if clean_t == ms(float(sensors["perfect_play_s"]) * 1000.0): _fire_event("player_perfect_play")
	if P["charge_t"] > 0 and tick % ms(1000) == 0: _fire_event("player_charged_state_visible")
	# ---- player intent ----
	var dodging: bool = P["dodge_t"] > 0
	var block_now: bool = inp.get("block", false)
	var block_edge: bool = block_now and not block_prev
	if block_edge: _ev("block_press", {})
	block_prev = block_now
	var native_guard := P.has("body_control") or inp.has("body_axis") or inp.has("pocket_step")
	# Age the actual held input even while an arm is extended or the guard is
	# open. Recovery cannot manufacture a new timely catch without a re-press.
	if native_guard: P["block_t"] = int(P["block_t"])+1 if block_now else 0
	P["blocking"] = block_now and (native_guard or not dodging and P["pending"].is_empty()) and int(P["guard_open_t"]) <= 0
	P["guard_body"] = bool(inp.get("body",false))
	if P["blocking"]:
		if not native_guard: P["block_t"] += 1
		block_hold_t += 1
		var decay := float(T["guard"]["hold_decay_per_s"]) * (float(T["zones"]["CORNER"]["guard_decay_mult"]) if zone(P["pos"]) == "CORNER" else 1.0) * float(tactic_fx.get("guard_decay_mult", 1.0))
		if _pas(P, "tight_guard"): decay *= float(_pv("tight_guard", "guard_decay_mult", 1.0))            # PAC-090: Tight Guard (NP_11 s3)
		decay *= _gear_mult(P, "guard_decay")                                                           # PAC-094: his wraps
		P["guard"] = maxf(0.0, P["guard"] - decay * DT)
		if block_hold_t == ms(2000): _fire_event("player_block_hold")
		if block_hold_t == ms(float(sensors["guard_s"]) * 1000.0): _fire_event("player_static_guard"); _fire_event("player_high_guard")
	else:
		if not native_guard: P["block_t"] = 0
		block_hold_t = 0
		var greg := float(T["guard"]["regen_per_s"])
		if buffs["P"].has("guard_regen_x2"): greg *= 2.0
		if buffs["P"].has("guard_regen_plus"): greg += 3.0
		if states["P"].has("guard_regen_minus1"): greg -= 1.0
		if _tx(P, "deep_roots") > 0 and drops_p < drops_b: greg *= _tmult(float(HOUSES["traits"]["deep_roots"]["guard_regen_mult"]), _tx(P, "deep_roots"), P)   # PAC-078: Deep Roots, trailing on drops
		if int(P["busy_t"]) <= 0 and not dodging and P["pending"].is_empty() and int(P["guard_open_t"]) <= 0:
			P["guard"] = minf(P["guard_max"], P["guard"] + greg * DT)
	# the WALL motion: LB + block held 400ms casts a WALL-family move
	var mv_w := wall_move()                                                                             # PAC-084: an inherited WALL native first
	if inp.get("lb", false) and block_now and not mv_w.is_empty() and str(mv_w["family"]) == "WALL":
		lb_block_t += 1
		if lb_block_t == ms(400): wall_motion()
	else: lb_block_t = 0
	var casting_p: bool = cast.size() > 0 and cast["who"] == "P"
	var mv: Vector2 = inp.get("move", Vector2.ZERO) if not (dodging or clinch_t > 0 or casting_p) else Vector2.ZERO
	var spd := lerpf(2.2, 3.4, float(P["stats"]["SPD"]) / 99.0) * float(_gassed(P)["foot_speed"]) * _speed_mult("P")
	if _wobbled(P): spd *= float(T["composure"]["wobble_move_mult"])
	var fwd: Vector2 = (B["pos"] - P["pos"]).normalized()
	var right := Vector2(-fwd.y, fwd.x)
	var before: Vector2 = P["pos"]
	var dist0: float = B["pos"].distance_to(P["pos"])
	if inp.has("body_axis") or inp.has("pocket_step") or P.has("body_control") or P.has("frozen_step"):
		var step_request: Vector2 = inp.get("pocket_step", Vector2.ZERO)
		var allowed: bool = not casting_p and not dodging and bool(PunchContact.transition(P,"EXIT")["allowed"])
		if P.has("frozen_step"):
			if step_request == Vector2.ZERO: step_request = P["frozen_step"]["direction"]
			P.erase("frozen_step")
		_boxing_recoil(P,1)
		var result := BodyControl.advance(P, B, _boxing_body_axis(P,inp.get("body_axis", Vector2.ZERO)), step_request, DT, allowed, RING_HALF,float(inp.get("pocket_step_distance",BodyControl.STEP_M)))
		if not result.is_empty(): _ev("footwork", result)
		mv = Vector2.ZERO # Native actors cannot also receive legacy free travel.
	P["pos"] += (right * mv.x - fwd * mv.y) * spd * DT * (float(P["pkg"].get("backpedal_mult", T["movement"].get("backpedal_mult", 0.7))) if mv.y > 0 else 1.0)
	_clamp(P)
	# sprint-step (NP_03 s2.4): 0.8m burst, -4 stamina; toward him it is an approach, away it is a back-step
	if inp.get("sprint", false) and not P.has("body_control") and sprint_cd <= 0 and not dodging and clinch.is_empty():
		var sdir: Vector2 = (right * mv.x - fwd * mv.y).normalized() if mv.length() > 0.2 else fwd
		P["pos"] += sdir * float(T["movement"]["sprint_step_m"]); _clamp(P)
		if not tactic_fx.get("sprint_free", false): P["stamina"] = maxf(_sfloor(P), P["stamina"] - float(T["movement"]["sprint_step_stamina"]) * float(P["pkg"].get("move_stamina_mult", 1.0)))
		sprint_cd = ms(400)
		var toward := sdir.dot(fwd)
		_ev("sprint", {"toward": toward})
		if toward < -0.5: _ev("backstep", {"sprint": true}); backstep_ev_t = tick
		if toward > 0.5 and dist0 > 1.4: _fire_event("player_sprint_approach")
		if toward < -0.5:
			backstep_ticks.append(tick)
			while backstep_ticks.size() > 0 and tick - int(backstep_ticks[0]) > ms(4000): backstep_ticks.pop_front()
			if backstep_ticks.size() >= 3:
				backstep_ticks = []; _fire_event("player_backstep_chain3")
	if mv.y > 0.2 and tick - backstep_ev_t > 20: _ev("backstep", {"sprint": false}); backstep_ev_t = tick   # a backward step, once per 20 ticks
	p_vel = (P["pos"] - before) / DT
	var pocket_retreat: bool = Vector2(P.get("body_control", {}).get("step", {}).get("direction", Vector2.ZERO)).dot(-fwd) > 0.5
	if bstate in ["TELL", "HOLD", "ACTING"] and (mv.y > 0.0 or pocket_retreat) and p_vel.dot((P["pos"] - B["pos"]).normalized()) > 0.0:
		if not P.has("range_step_from"): P["range_step_from"] = {"player": before, "attacker": B["pos"]}
	else: P.erase("range_step_from")
	# straight-line retreat: backing without an angle, 1.2m of it
	if mv.y > 0.7 and absf(mv.x) < 0.3: retreat_d += (P["pos"] - before).length()
	else: retreat_d = 0.0
	if retreat_d >= 1.2:
		retreat_d = 0.0; _fire_event("player_straight_line_retreat")
	# neutral reset attempt: out past engagement, not leading, not closing, for a full second
	if dist0 > ENGAGE_DIST + 0.5 and inp.get("punch", "") == "" and mv.y >= 0.0: neutral_t += 1
	else: neutral_t = 0
	if neutral_t == ms(1000) and neutral_cd <= 0:
		neutral_cd = ms(4000); _fire_event("player_neutral_reset_attempt")
	var dg: String = inp.get("dodge", "")
	if dg != "" and not dodging and clinch_t <= 0 and not casting_p:
		var kind := dg.split("_")[0]
		var dirv := -1 if dg.ends_with("_L") else 1
		_set_dodge(P, kind, dirv)
		if kind == "WEAVE" and (trapped_p or zone(P["pos"]) == "ROPES" or zone(P["pos"]) == "CORNER"): _fire_event("player_rope_escape_attempt")
	if inp.get("taunt", false) and taunt_t <= 0:
		taunt_t = ms(800); _fire_event("player_taunt"); _ev("taunt", {})
	var lb: bool = inp.get("lb", false)
	if lb and not lb_prev: lb_rise_t = 0; threw_since_arm = false
	if lb: lb_rise_t += 1
	if lb_prev and not lb and not threw_since_arm and lb_rise_t < ms(600):
		tension = maxf(0.0, tension - 2.0); _fire_event("player_hissatsu_arm_feint")
	lb_prev = lb
	var pr: String = inp.get("punch", "")
	if pr != "": _queue_punch(pr, inp)
	var executed := _try_execute_cmd()
	if inp.get("punch_release", false) and P["pending"].size() > 0 and not P["pending"]["hissatsu"] \
		and int(P["pending"]["startup"]) - int(P["pending"]["t"]) <= ms(float(T["feint"]["cancel_within_ms"])) and float(inp.get("punch_release_age_ms", 0)) <= float(T["feint"]["cancel_within_ms"]):
		_feint()
	# reactions to tells: what you did first after the tell started, and how fast
	var reacted_now: bool = dg != "" or block_edge or executed
	if bstate == "FAKE" and reacted_now: _fire_event("player_reacts_to_fake_tell")
	if bstate == "TELL" and reacted_now and not tell_reacted and tell_start_tick >= 0:
		tell_reacted = true
		if bstring != "": breads[bstring] = int(breads.get(bstring, 0)) + 1                 # Cal's recognition: the strings you read
		react_ticks.append(tick - tell_start_tick)
		if react_ticks.size() > 3: react_ticks.pop_front()
		if audio_assist and react_ticks.size() == 3:
			var all_fast := true
			for rt in react_ticks:
				if int(rt) >= ms(300): all_fast = false
			if all_fast:
				react_ticks = []; _fire_event("player_audio_assist_reliance")
	if P["pending"].size() > 0:
		# NP_03's step-in reach is travel, not extra arm length. Spread the
		# authored distance over startup; hitstop/feint naturally halt it.
		var travel := float(P["pending"].get("step_remaining", 0.0)) / maxi(1, int(P["pending"]["t"]))
		P["pos"] += P["pending"].get("step_direction", Vector2.ZERO) * travel
		P["pending"]["step_remaining"] = maxf(0, float(P["pending"].get("step_remaining", 0.0)) - travel)
		_clamp(P)
		P["pending"]["t"] -= 1
		if P["pending"]["t"] <= 0 and not P["pending"].get("trajectory",false): _land_player_punch()
	# ---- positional reads ----
	var zp := zone(P["pos"])
	if zp != last_zone_p:
		if zp == "CORNER": _fire_event("player_corner_entry")
		elif zp == "ROPES": _fire_event("player_rope_touch")
		if (zp == "ROPES" or zp == "CORNER") and (last_zone_p == "CENTER" or last_zone_p == "MID") and p_vel.dot(-fwd) > 0.3:
			_fire_event("player_rope_backing")
		last_zone_p = zp
	if zp == "CENTER":
		center_hold_t += 1
		if center_hold_t == ms(float(sensors["center_s"]) * 1000.0): _fire_event("player_holds_center")
	else: center_hold_t = 0
	if zp == "ROPES" or zp == "CORNER": rope_time_t += 1
	if not gassed_fired and P["stamina"] < 40.0:
		gassed_fired = true; _fire_event("player_gassed")
	var dist: float = B["pos"].distance_to(P["pos"])
	if zp == "CORNER" and dist < 2.6:
		pinned_p_t += 1
		if pinned_p_t == ms(3000): trapped_p = true; _say("CORNER TRAP - x1.5 damage, guard bleeding; reads wider. Weave out!")
	else: pinned_p_t = 0; trapped_p = false
	if zone(B["pos"]) == "CORNER" and dist < 2.6:
		pinned_b_t += 1
		if pinned_b_t == ms(3000): trapped_b = true; _say("HE'S TRAPPED - finish it!")
	else: pinned_b_t = 0; trapped_b = false
	# ---- boss: keep range with cut-off, then act (slow-time scales his timers) ----
	if cast.size() > 0: _cast_tick()
	if mode != "FIGHT": return
	if bstate != "ACTING" and bstate != "CAST" and bstate != "SURGE": _neutral_move(dist)           # NP_04 s2: his IDLE lines - the shared approach when he has none (PAC-086: not while he gathers)
	_footwork_tick()
	# NP_03 s7: a wobbled fighter grabs to survive - once per segment, at 0-range, between his own actions
	if not bsurvival_used and _wobbled(B) and dist <= 1.3 and bstate != "ACTING" and bstate != "CAST" and bstate != "SURGE" and cast.is_empty() and mode == "FIGHT":
		bsurvival_used = true
		_start_clinch("B", 0.3, 2)
		_say("he's hurt and he GRABS - survival clinch, ride it out or win the position")
		_ev("survival_grab", {})
		return
	var rate := 0.6 if P["flash_t"] > 0 else 1.0
	if tform.size() > 0: rate *= float(_zone_fx().get("time_scale", 1.0))                               # PAC-082: the world slows for the player in the Zone (C5's slow-time, stacked)
	var bts := float(_bfx().get("time_scale", 1.0))
	if btform.size() > 0 and bstate != "TELL" and bstate != "SURGE" and bts > 0.0:                 # PAC-086: the world slows for him in his Zone - his tells keep C4's floors
		rate /= bts
		if bstate == "ACTING": rate *= 1.0 + float(_bfx().get("punch_speed_pct", 0.0)) / 100.0
	boss_acc += rate
	var boss_ticks := 0
	while boss_acc >= 1.0:
		boss_acc -= 1.0
		boss_ticks += 1
		_boss_step()
		if mode != "FIGHT": break
	_separate()
	if P.has("body_control") and mode == "FIGHT" and clinch.is_empty(): _boxing_tick(boss_ticks)
	if clock_t <= 0 and mode == "FIGHT": _end_segment("clock")

func hash_state() -> int:
	# bit-exact: serialises the raw values, no float formatting, no rounding
	var v := [tick, P["pos"], B["pos"], P["stamina"], P["comp"], P["guard"], P["busy_t"],
		P["dodge"], P["dodge_t"], P["counter_t"], P["flash_t"], P["cmd"], P["pending"], P.get("range_step_from", null),
		B["stamina"], B["comp"], B["guard"], B["dodge"], B["dodge_t"], B["dodge_at"], B["blocking"],
		tension, contributed, drops_p, drops_b, score_p, score_b, ep_p, ep_b, seg_idx,
		bstate, btimer, bstring, bphase, bqueue, flags, tokens, mode, clock_t, freeze_t, boss_acc,
		eight, punish_cd, trapped_p, trapped_b, clinch, clinch_ticks, sprint_cd, backstep_ticks, retreat_d,
		neutral_t, cadence, hands_down_t, react_ticks, bwarnings, pwarnings, pholding, bsurvival_used,
		cast.get("t", -1), cast.get("who", ""), states, buffs, wall, relay_chain, hiss_casts_seg, wall_migrate, gauge_jabs,
		feint_log, feint_wise, corner, card_t, tactic_fx, pending_fx, super_used, staff_charges, swaps_used, save_bar, save_bar_next,
		full_relay, no_drop_t, punish_suppress_t, tell_highlight_t, stamina_cap, ep_frac, ep_frac_b, aff,
		btension, bcontributed, bcharged, brelay_chain, btactic_fx, bpending_fx, btactic_cd, bsuper_used, bswaps_used, bno_drop_t,
		enemy_lock, player_lock, bflash_conceded, bdrop_conceded, blineup, breserves, coach.get("id", ""),
		condition, bcondition, seg_wins_p, seg_wins_b, counters_p, counters_b, r6, fmt.get("id", ""), lineup.map(func(f): return str(f["name"])),
		delegated, delegate_next, delegate_all, auto,
		bout.get("kind", ""), bout.get("objective", ""), obj.get("count", 0), obj.get("met", false), obj.get("failed", false), obj.get("streak", 0), obj.get("ladder_i", 0), lab, bout_cap_t,
		pi, bdialect, bremix.get("id", ""), bmods, binterrupts, bfeint, bdesync_widen, bdesync_ms,
		btempo_i, bstrings_done, bcooldown_until, breads, bdialogue, btrue_pattern, btransient, bcalled_phases, blanded,
		rewards, seg_xp, dual_xp, duo.get("pair", ""), tform, comedown, transformed, btsurge, btform, bcomedown, btransformed, mclash, bgeneric.get("name", ""), bgeneric.get("seed", 0), generic_slots, neutral_on, bneutral_t, btaunts, btaunt_t, btempo_fast, bfootwork_audio, sealed_p, sealed_b, crowd_heat, stable.map(func(f): return str(f["name"])), rng.state]
	# Preserve legacy snapshots without body state; new exchanges bind every
	# body/footwork value, including a queued step and support, into replay.
	if P.has("body_control") or B.has("body_control") or P.has("frozen_step"):
		v.append(B["pending"])
		v.append(P.get("boxing",{})); v.append(B.get("boxing",{}))
		v.append([P.get("guard_body",false),B.get("guard_body",false),B.get("motion_offer",0),B.get("motion_gear",0)])
		v.append(P.get("body_control", {})); v.append(B.get("body_control", {}))
		v.append(P.get("frozen_step", {}))
	return v.hash()

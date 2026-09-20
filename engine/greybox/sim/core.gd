extends RefCounted
# Loaded by preload("res://sim/core.gd") - no class_name: headless runs must not
# depend on the editor's global class cache.
# TRUE NORTH BOXING - deterministic combat simulation core (NP_14 C1-C7).
# Pure: no Nodes, no wall clock, seeded RNG, fixed 120Hz ticks driven by an
# input dictionary. Presentation (main.gd) renders this state; tests drive it
# directly. Every ms constant from combat_tuning.v1.json is converted to ticks
# at load; geometry (C2) replaces dodge tables; hitstop/slow-time are sim state.

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
	{"name": "RORY",   "hissatsu": "Aurora Borealis Breaker", "style": "BOXERPUNCHER", "element": "FROST", "house": "none",
		"stats": {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}},
	{"name": "PRIYA",  "hissatsu": "Marginalia", "style": "OUTBOXER", "element": "GALE", "house": "none",
		"stats": {"PWR": 35, "SPD": 60, "CHN": 40, "RFX": 70, "BLK": 50, "STA": 55, "HRT": 60}},
	{"name": "MARCUS", "hissatsu": "Chinook Rush", "style": "SLUGGER", "element": "GRANITE", "house": "none",
		"stats": {"PWR": 70, "SPD": 40, "CHN": 65, "RFX": 35, "BLK": 40, "STA": 55, "HRT": 70}},
	{"name": "JUNE",   "hissatsu": "First Snap", "reserve": true, "style": "SWARMER", "element": "FROST", "house": "none",
		"stats": {"PWR": 30, "SPD": 75, "CHN": 35, "RFX": 60, "BLK": 20, "STA": 60, "HRT": 70}},
]
const LINEUP_MILLBROOK_8 := [   # NP_01 s2 sanctioned dual: 8 dressed - five slots (R1 opener .. R5 anchor) and three reserves. Recruits' cards are editorial (REGISTER_COMMANDS_010)
	{"name": "RORY",   "hissatsu": "Aurora Borealis Breaker", "style": "BOXERPUNCHER", "element": "FROST", "house": "none",
		"stats": {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}},
	{"name": "JUNE",   "hissatsu": "First Snap", "style": "SWARMER", "element": "FROST", "house": "none",
		"stats": {"PWR": 30, "SPD": 75, "CHN": 35, "RFX": 60, "BLK": 20, "STA": 60, "HRT": 70}},
	{"name": "PRIYA",  "hissatsu": "Marginalia", "style": "OUTBOXER", "element": "GALE", "house": "none",
		"stats": {"PWR": 35, "SPD": 60, "CHN": 40, "RFX": 70, "BLK": 50, "STA": 55, "HRT": 60}},
	{"name": "MARCUS", "hissatsu": "Chinook Rush", "style": "SLUGGER", "element": "GRANITE", "house": "none",
		"stats": {"PWR": 70, "SPD": 40, "CHN": 65, "RFX": 35, "BLK": 40, "STA": 55, "HRT": 70}},
	{"name": "SAM",    "hissatsu": "Sorry Eh", "style": "BOXERPUNCHER", "element": "FROST", "house": "tagaq",
		"stats": {"PWR": 55, "SPD": 45, "CHN": 90, "RFX": 50, "BLK": 80, "STA": 70, "HRT": 85}},
	{"name": "DEX",    "hissatsu": "Prodigal", "reserve": true, "style": "SLUGGER", "element": "TIMBER", "house": "macisaac",
		"stats": {"PWR": 62, "SPD": 48, "CHN": 60, "RFX": 45, "BLK": 50, "STA": 60, "HRT": 65}},
	{"name": "YURI",   "hissatsu": "Grain Elevator", "reserve": true, "style": "SLUGGER", "element": "GRANITE", "house": "kowalchuk",
		"stats": {"PWR": 80, "SPD": 40, "CHN": 70, "RFX": 40, "BLK": 45, "STA": 60, "HRT": 75}},
	{"name": "MARTA",  "hissatsu": "Miroir d'Hiver", "reserve": true, "style": "OUTBOXER", "element": "FROST", "house": "tremblay",
		"stats": {"PWR": 40, "SPD": 65, "CHN": 50, "RFX": 85, "BLK": 70, "STA": 55, "HRT": 60}},
]
const PUNCH_VERBS := {
	"JAB": "L_STRAIGHT", "L_STR": "L_STRAIGHT", "R_STR": "R_STRAIGHT",
	"COUNTER_R_STR": "R_STRAIGHT", "STEP_R_STR": "R_STRAIGHT", "UNDER_ELBOW_CROSS": "R_STRAIGHT",
	"L_HOOK": "L_HOOK", "CHECK_HOOK": "L_HOOK", "LT_L_HOOK": "L_HOOK", "COUNTER_L_HOOK": "L_HOOK",
	"R_HOOK": "R_HOOK", "LT_R_HOOK": "R_HOOK", "R_UPC": "R_UPPERCUT", "LT_R_UPC": "R_UPPERCUT",
	"L_UPC": "L_UPPERCUT", "R_HAY": "R_HOOKERCUT", "R_OVERHAND": "R_FLARED",
	"PULL_COUNTER_OVERHAND": "R_FLARED",
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
var hiss_casts_seg := 0
var dmg_hist := {"P": [], "B": []}   # damage taken this segment (The Mean)
var wall_migrate := 0                # gauge points carried to the next boss (HC-0)
var gauge_jabs := 0                  # jab-class punches into a live gauge (Sam's literacy hook)
var commentary_mute_t := 0
var lb_block_t := 0                  # LB + RT held: the WALL motion (400ms)

# PAC-057: feints (NP_03 s8)
var feint_log: Array = []            # [tick, row] of recent feints (10s window)
var feint_wise: Dictionary = {}      # row -> tick until which he stops reacting to that feint

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
		"coaches": load_json(base + "coaches.v1.json"), "formats": load_json(base + "formats.v1.json")}

func setup(tuning: Dictionary, pats: Dictionary, names: Array, lineup_p: Array, first_boss: int, seed_v: int, lib: Dictionary = {}, tac: Dictionary = {}, aff_d: Dictionary = {}, feuds: Array = [], coaches: Dictionary = {}, formats: Dictionary = {}, fmt_id: String = "") -> void:
	T = tuning; patterns = pats; boss_names = names; library = lib; TAC = tac; AFF = aff_d; FEUDS = feuds; COACHES = coaches; FMT = formats
	var fid := fmt_id if fmt_id != "" else str(FMT.get("default", "mini"))
	fmt = FMT.get("formats", {}).get(fid, {"label": "Mini-dual", "segments": 3, "dressed": 4, "enemy_dressed": 4, "repeat_slots": false, "condition_carries": true, "sudden_death": true, "blind": false, "segment_s": 90}).duplicate(true)
	fmt["id"] = fid
	dressed = []
	for f in lineup_p: dressed.append(f.duplicate(true))
	rng.seed = seed_v
	boss_names = names
	_reset_dual(first_boss)

func segments() -> int: return int(fmt.get("segments", 3))

func _build_lineup() -> void:
	# NP_01 s2 / s8: the slots are drawn from the cards you dressed - reserves flagged as such sit out,
	# starters fill R1.. in order; a roster shorter than the slots repeats (Iron dual, Gauntlet)
	lineup = []; reserves = []
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
	seg_idx = 0; drops_p = 0; drops_b = 0; score_p = 0; score_b = 0; ep_p = 0; ep_b = 0
	tension = 0.0; charged = false; mode = "FIGHT"; relay_chain = 0; wall_migrate = 0
	full_relay = false; super_used = false; swaps_used = 0; tactic_cd = {}; pending_fx = {}; save_bar_next = false
	staff_charges = {}
	for st in TAC.get("staff_active", []): staff_charges[str(st["id"])] = int(st["charges"])
	corner = {}; card_t = 0
	btension = 0.0; bcontributed = 0.0; bcharged = false; brelay_chain = 0
	btactic_fx = {}; bpending_fx = {}; btactic_cd = {}; bsuper_used = false; bswaps_used = 0
	enemy_lock = 0; player_lock = 0; bflash_conceded = false; bdrop_conceded = false; coach_log = []
	condition = {}; bcondition = {}; seg_wins_p = 0; seg_wins_b = 0; counters_p = 0; counters_b = 0; r6 = false
	_first_boss = first_boss
	_build_lineup()
	_pick_coach(); _build_enemy_lineup()
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
	P = _fresh(f["stats"], Vector2(0, 1.0))
	_dress(P, str(f.get("style", "BOXERPUNCHER")), str(f.get("element", "NONE")), str(f.get("house", "none")))
	boss_name = blineup[seg_idx] if seg_idx < blineup.size() else boss_names[(_first_boss + seg_idx) % boss_names.size()]
	pattern = patterns[boss_name].duplicate(true)
	B = _fresh({"PWR": 60, "SPD": 55, "CHN": 60, "RFX": 55, "BLK": 55, "STA": 60, "HRT": 60}, Vector2(0, -1.0))
	var bm: Dictionary = pattern.get("meta", {})
	_dress(B, str(bm.get("style", "BOXERPUNCHER")), str(bm.get("element", "NONE")), str(bm.get("house", "none")))
	bstate = "IDLE"; btimer = ms(600); bqueue = []; bphase = 1; bdesp_used = false; bpending = {}
	contributed = 0.0
	tokens = []; flags = {}
	center_hold_t = 0; block_hold_t = 0; punch_ticks = []; punch_rows = []
	last_zone_p = "MID"; punish_cd = {}; gassed_fired = false; taunt_t = 0
	pinned_p_t = 0; pinned_b_t = 0; trapped_p = false; trapped_b = false
	freeze_t = 0; boss_acc = 0.0; eight = {}
	bforce_opts = {}; swap_restore = {}; clinch_t = 0; wall_broken = false; rope_time_t = 0
	passive_t = 0; clean_t = 0; head_streak = 0; tier_fired = 0
	clinch = {}; clinch_ticks = []; sprint_cd = 0; backstep_ticks = []; retreat_d = 0.0
	neutral_t = 0; neutral_cd = 0; cadence = []; hands_down_t = 0
	tell_start_tick = -1; tell_reacted = false; react_ticks = []; bwarnings = 0; pwarnings = 0; pholding = 0
	bsurvival_used = false; block_prev = false
	cast = {}; states = {"P": {}, "B": {}}; buffs = {"P": {}, "B": {}}; wall = {"P": {}, "B": {}}
	hiss_casts_seg = 0; dmg_hist = {"P": [], "B": []}; gauge_jabs = 0; commentary_mute_t = 0; lb_block_t = 0
	feint_log = []; feint_wise = {}
	t3_unlocked = charged
	_load_wall_gauge()
	sensors = _parse_sensors(pattern)
	seg_score0 = [score_p, score_b, ep_p, ep_b]; clock_acc = 0.0; ep_frac = 0.0; ep_frac_b = 0.0
	clock_t = (1 << 30) if r6 else ms(float(fmt.get("segment_s", 90)) * 1000.0)
	# s6: a fighter who re-enters carries the condition he left with (R6, repeat slots); the corner's restores land on top
	if bool(fmt.get("condition_carries", true)):
		if condition.has(str(f["name"])):
			var cp: Dictionary = condition[str(f["name"])]
			P["stamina"] = minf(100.0, float(cp["stamina"])); P["guard"] = minf(P["guard_max"], float(cp["guard"])); P["comp"] = minf(P["comp_max"], float(cp["comp"]))
			_ev("carried", {"who": "P", "name": str(f["name"]), "stamina": P["stamina"], "guard": P["guard"], "comp": P["comp"]})
		if bcondition.has(boss_name):
			var cb: Dictionary = bcondition[boss_name]
			B["stamina"] = minf(100.0, float(cb["stamina"])); B["guard"] = minf(B["guard_max"], float(cb["guard"])); B["comp"] = minf(B["comp_max"], float(cb["comp"]))
			_ev("carried", {"who": "B", "name": boss_name, "stamina": B["stamina"], "guard": B["guard"], "comp": B["comp"]})
	# the corner's choices land here (NP_10 s4-s6)
	tactic_fx = pending_fx; pending_fx = {}
	save_bar = save_bar_next; save_bar_next = false
	stamina_cap = float(tactic_fx.get("stamina_cap", 100.0))
	P["stamina"] = minf(stamina_cap, P["stamina"]) if condition.has(str(f["name"])) and bool(fmt.get("condition_carries", true)) else stamina_cap
	if tactic_fx.has("overrun"): P["stamina"] = minf(P["stamina"], stamina_cap * float(TAC.get("corner", {}).get("overrun_stamina_pct", 80)) / 100.0)
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
	_matchup()
	if charged:
		P["charge_t"] = ms(float(TAC.get("corner", {}).get("charged_surge_s", 10)) * 1000.0); charged = false
		_say("R%d: %s enters CHARGED - surge %ds, first hissatsu half cost, T3 unlocked!%s vs %s" % [seg_idx + 1, f["name"], int(TAC.get("corner", {}).get("charged_surge_s", 10)), "  FULL RELAY!" if full_relay else "", boss_name])
	else:
		_say("R%d: %s vs %s" % [seg_idx + 1, f["name"], boss_name])
	mode = "FIGHT"

func pname() -> String: return lineup[seg_idx]["name"]

# ============================ THE ENEMY COACH (NP_10 s9) ==================
func _pick_coach() -> void:
	var recs: Dictionary = COACHES.get("coaches", {})
	var id := str(COACHES.get("coach_of", {}).get(boss_names[_first_boss], COACHES.get("default", "journeyman")))
	coach = recs.get(id, {}).duplicate(true)
	if coach.size() > 0: coach["id"] = id

func boss_role(name: String) -> int:
	var slot := str(patterns.get(name, {}).get("meta", {}).get("slot", "R3"))
	return int(slot.substr(1)) if slot.length() > 1 and slot.substr(1).is_valid_int() else 3

func _anchor_class(name: String) -> bool:
	var m: Dictionary = patterns.get(name, {}).get("meta", {})
	return boss_role(name) >= 5 or m.has("wall_gauge") or m.has("migrant_wall")

func _build_enemy_lineup() -> void:
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
	var hp: String = P.get("house", "none"); var hb: String = B.get("house", "none")
	if hp == "none" or hb == "none": return false
	for e in FEUDS:
		if str(e.get("relation", "")) == "FEUD" and ((str(e["a"]) == hp and str(e["b"]) == hb) or (str(e["a"]) == hb and str(e["b"]) == hp)): return true
	return false

func _feud_edge() -> Dictionary:
	for e in FEUDS:
		if str(e.get("relation", "")) == "FEUD" and ((str(e["a"]) == P["house"] and str(e["b"]) == B["house"]) or (str(e["a"]) == B["house"] and str(e["b"]) == P["house"])): return e
	return {}

func _matchup() -> void:
	# the matchup card (s5): every ring read once at segment start, the whole stack in one line
	var st: Dictionary = AFF.get("style", {}); var el: Dictionary = AFF.get("element", {})
	var labels: Dictionary = st.get("labels", {})
	var style_adv := ""
	if _beats("style", P["style"], B["style"]): style_adv = "P"
	elif _beats("style", B["style"], P["style"]): style_adv = "B"
	var element_adv := ""
	if _beats("element", P["element"], B["element"]): element_adv = "P"
	elif _beats("element", B["element"], P["element"]): element_adv = "B"
	var feud := feud_active()
	var parts: Array = []
	if style_adv == "P": parts.append("STYLE %s over %s: %s" % [labels.get(P["style"], P["style"]), labels.get(B["style"], B["style"]), st.get("why", {}).get("%s>%s" % [P["style"], B["style"]], "")])
	elif style_adv == "B": parts.append("STYLE his %s over your %s: %s" % [labels.get(B["style"], B["style"]), labels.get(P["style"], P["style"]), st.get("why", {}).get("%s>%s" % [B["style"], P["style"]], "")])
	elif P["style"] == "BOXERPUNCHER" and B["style"] == "BOXERPUNCHER": parts.append("STYLE the purist's matchup - no rings, pure sim")
	elif P["style"] == B["style"]: parts.append("STYLE mirror match")
	else: parts.append("STYLE neutral")
	if element_adv == "P": parts.append("ELEMENT %s over %s: %s" % [P["element"], B["element"], el.get("why", {}).get("%s>%s" % [P["element"], B["element"]], "")])
	elif element_adv == "B": parts.append("ELEMENT his %s over your %s: %s - his walls stand +1s" % [B["element"], P["element"], el.get("why", {}).get("%s>%s" % [B["element"], P["element"]], "")])
	elif P["element"] != "NONE" and B["element"] != "NONE": parts.append("ELEMENT %s / %s neutral" % [P["element"], B["element"]])
	if feud:
		var e := _feud_edge()
		parts.append("FEUD House %s vs House %s (%s) - Tension +25%% both ways" % [str(P["house"]).capitalize(), str(B["house"]).capitalize(), str(e.get("origin", ""))])
	aff = {"style_adv": style_adv, "element_adv": element_adv, "feud": feud, "line": " | ".join(PackedStringArray(parts)),
		"p": [P["style"], P["element"], P["house"]], "b": [B["style"], B["element"], B["house"]]}
	_ev("matchup", {"p_style": P["style"], "p_element": P["element"], "p_house": P["house"], "b_style": B["style"], "b_element": B["element"], "b_house": B["house"],
		"style_adv": style_adv, "element_adv": element_adv, "feud": feud, "line": aff["line"]})
	_say("MATCHUP %s (%s/%s) vs %s (%s/%s) :: %s" % [pname(), labels.get(P["style"], P["style"]), P["element"], boss_name, labels.get(B["style"], B["style"]), B["element"], aff["line"]])

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
	if mv.size() > 0 and move_house(str(mv.get("name", ""))) != "" and move_house(str(mv.get("name", ""))) == A["house"] and A["house"] != "none": m *= float(ho.get("native_effect_mult", 1.1))
	return minf(float(AFF.get("cap", 1.5)), m)

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

# ============================ GEOMETRY (C2) ================================
func _punch_family(row: String) -> String:
	for fam in GEO:
		if row.ends_with(fam): return fam
	return "STRAIGHT"

func _head_world(F: Dictionary, other: Dictionary) -> Dictionary:
	# defender's head as a world point + height, displaced by its active dodge
	var fwd: Vector2 = (other["pos"] - F["pos"]).normalized()      # defender facing attacker
	var rightD := Vector2(fwd.y, -fwd.x)                             # defender's right
	var lat := 0.0; var h := HEAD_H; var back := 0.0
	if F["dodge"] != "":
		var d: Dictionary = DODGE[F["dodge"]]
		lat = float(d["lat"]) * float(F["dodge_dir"]); h = float(d["h"]); back = float(d["back"])
		if F["dodge"] == "WEAVE": lat *= float(F.get("pkg", {}).get("weave_arc_mult", 1.0))      # the out-boxer's narrower weave (s1.2)
	var head: Vector2 = F["pos"] - fwd * back + rightD * lat
	return {"p": head, "h": h}

func resolve_geometry(A: Dictionary, D: Dictionary, row: String, body: bool) -> String:
	# returns HIT | MISS_REACH | MISS_LATERAL | MISS_HEIGHT
	var fam := _punch_family(row)
	var g: Dictionary = GEO[fam]
	var fwd: Vector2 = (D["pos"] - A["pos"]).normalized()
	var rightA := Vector2(fwd.y, -fwd.x)
	var target := _head_world(D, A)
	var tp: Vector2 = target["p"]; var th: float = target["h"]
	if body:
		# torso: lateral follows the head at 40%, height fixed - slips barely move the body
		var fwdD: Vector2 = -fwd
		var rightD := Vector2(fwdD.y, -fwdD.x)
		var lat := 0.0; var back := 0.0
		if D["dodge"] != "":
			lat = float(DODGE[D["dodge"]]["lat"]) * float(D["dodge_dir"]) * 0.4 * (float(D.get("pkg", {}).get("weave_arc_mult", 1.0)) if D["dodge"] == "WEAVE" else 1.0)
			back = float(DODGE[D["dodge"]]["back"])
		tp = D["pos"] + fwd * back + rightD * lat     # fwd here points A->D, so +fwd*back moves D away
		th = 1.10
	var rel: Vector2 = tp - A["pos"]
	var d := rel.dot(fwd)
	var l := rel.dot(rightA)
	if row.begins_with("L_"): l = -l                 # mirror for the left hand
	var reach := float(g["reach"]) * float(A.get("pkg", {}).get("reach_mult", 1.0))
	if fam == "STRAIGHT": reach *= float(A.get("pkg", {}).get("straight_reach_mult", 1.0))
	if d > reach: return "MISS_REACH"
	if l < float(g["lat"][0]) or l > float(g["lat"][1]): return "MISS_LATERAL"
	if not body and (th < float(g["h"][0]) or th > float(g["h"][1])): return "MISS_HEIGHT"
	return "HIT"

func _correct_dodge_for(row: String, body: bool = false) -> Array:
	# a read chooses a geometrically valid evasion: [kind, dir] in defender's frame.
	# Body shots barely move with a slip and have no height band: the only
	# geometric answer is distance, so a read pulls back (works at range only).
	var fam := _punch_family(row)
	var right_hand := row.begins_with("R_")
	if body: return ["LEAN", 1]
	match fam:
		"STRAIGHT", "FLARED": return ["SLIP", 1 if rng.randf() < 0.5 else -1]
		"HOOK", "HOOKERCUT":
			# away = defender's right for an attacker's right hook (l negative)
			return ["SLIP", 1 if right_hand else -1] if rng.randf() < 0.5 else ["DUCK", 1]
		"UPPERCUT": return ["SLIP", 1 if rng.randf() < 0.5 else -1] if rng.randf() < 0.6 else ["LEAN", 1]
	return ["SLIP", 1]

func _set_dodge(F: Dictionary, kind: String, dir: int) -> void:
	if F["dodge_t"] > 0: return
	F["dodge"] = kind; F["dodge_dir"] = dir; F["dodge_t"] = int(DODGE[kind]["t"])
	if kind == "LEAN": F["stamina"] = maxf(0.0, F["stamina"] - 5.0)

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
		if F["stamina"] > float(row["above"]): return row
	return T["stamina"]["gassed_curve"][-1]

# ============================ PLAYER OFFENSE ===============================
func _queue_punch(row: String, inp: Dictionary) -> void:
	var mods: Array = []
	if inp.get("power", false): mods.append("POWER")
	if inp.get("body", false): mods.append("BODY")
	P["cmd"] = {"row": row, "mods": mods, "expire_t": BUFFER_TICKS, "lb": inp.get("lb", false)}

func read_prob(tier: int, counter: bool, flash: bool, hiss: bool) -> float:
	# C6/C7: the boss's chance to READ a player punch. The tracker tier raises it
	# (defense only, D3); a live counter window lowers it (fear is a number).
	var p := 0.30 + minf(float(T["adaptation_tracker"]["ramp_cap_pct"]) / 100.0,
		tier * float(T["adaptation_tracker"]["defense_ramp_per_tier_pct"]) / 100.0)
	if bstate == "TELL": p = 0.05
	if states["B"].has("tell_jam_audio") or states["B"].has("tell_jam_visual"): p = 0.05   # jammed: he can't read you
	if counter: p *= 0.25
	if flash: p = 0.02
	if hiss: p = 0.0
	return p

func _try_execute_cmd() -> bool:
	if P["cmd"].is_empty() or P["busy_t"] > 0: return false
	var c: Dictionary = P["cmd"]; P["cmd"] = {}
	var row: Dictionary = T["punch_matrix"][c["row"]]
	var startup := ms(float(row["startup_ms"]) * (1.4 if "POWER" in c["mods"] else 1.0) * float(P["pkg"].get("startup_mult", 1.0)))
	var mv_p := player_move()
	var hiss: bool = c["lb"] and not mv_p.is_empty() and _family_row_matches(str(mv_p["family"]), c["row"]) \
		and castable(mv_p) and tension >= hiss_cost(mv_p) and not save_bar
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
	var st_cost := float(row["stamina"]) * (2.0 if "POWER" in c["mods"] else 1.0)
	var fam_c := _punch_family(c["row"])
	if (fam_c == "HOOK" or fam_c == "UPPERCUT") and P["pos"].distance_to(B["pos"]) <= float(AFF.get("style", {}).get("inside_range_m", 1.3)):
		st_cost *= float(P["pkg"].get("inside_hook_upper_stamina_mult", 1.0))         # the swarmer's phone booth (s1.2)
	P["pending"] = {"row": c["row"], "t": startup, "startup": startup, "mods": c["mods"], "hissatsu": hiss,
		"counter": P["counter_t"] > 0, "flash": P["flash_t"] > 0, "stamina_cost": st_cost, "read": "none"}
	P["counter_t"] = 0                                     # window spent by the attempt
	P["busy_t"] = startup + ms(float(row["recovery_ms"]))
	P["stamina"] = maxf(0.0, P["stamina"] - st_cost)
	P["pos"] += (B["pos"] - P["pos"]).normalized() * LUNGE_P; _clamp(P)
	passive_t = 0
	if "BODY" in c["mods"]: head_streak = 0
	else:
		head_streak += 1
		if head_streak == 3: _fire_event("player_headhunt_streak3")
	_track(c["row"])
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
	if rng.randf() < p_read:
		var cd := _correct_dodge_for(c["row"], "BODY" in c["mods"])
		var lead := maxi(0, startup - int(DODGE[cd[0]]["t"]) / 2)
		B["dodge_plan"] = cd; B["dodge_at"] = maxi(1, lead)
		B["blocking"] = false; B["block_t"] = 0
		P["pending"]["read"] = "dodge"
	else:
		B["blocking"] = rng.randf() < 0.35
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
	P["stamina"] = maxf(0.0, minf(stamina_cap, P["stamina"] + float(pd["stamina_cost"])) - (0.0 if tactic_fx.get("feint_free", false) else float(T["feint"]["stamina"])))
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
	if wise:
		B["dodge_plan"] = []; B["dodge_at"] = 0; B["blocking"] = false; B["block_t"] = 0
		_ev("feint", {"row": row, "drawn": false, "read": read, "wise": true})
		_say("feint - he's not biting, he's seen that one")
	else:
		var drawn: bool = read != "none"
		if drawn:
			B["guard"] = maxf(0.0, B["guard"] - float(T["feint"]["enemy_guard_drain"]))
			B["pos"] += (B["pos"] - P["pos"]).normalized() * 0.1; _clamp(B)
			if read == "guard": B["blocking"] = false; B["block_t"] = 0; B["guard_t"] = ms(400)
		_ev("feint", {"row": row, "drawn": drawn, "read": read, "wise": false})
		_say("feint - %s" % ("he bit: slipping at air" if read == "dodge" else ("he flinched: guard up" if read == "guard" else "he didn't move")))
	_fire_event("player_feint")
	_fire_event("player_feint_" + _punch_family(row).to_lower())

func _land_player_punch() -> void:
	var pd: Dictionary = P["pending"]; P["pending"] = {}
	var body: bool = "BODY" in pd["mods"]
	var geo := resolve_geometry(P, B, pd["row"], body)
	if geo != "HIT":
		if geo == "MISS_REACH" and ("POWER" in pd["mods"] or pd["row"].ends_with("HOOKERCUT")):
			_fire_event("player_power_whiff")
		if body: _fire_event("player_whiffed_body_shot")
		_ev("whiff", {"by": "P", "why": geo})
		if B["dodge"] != "" and geo != "MISS_REACH": _earn_tension_b(float(T.get("tension", {}).get("perfect_defense", 2)))
		if geo != "MISS_REACH": _say("he made you miss (%s)" % geo.to_lower().replace("miss_", ""))
		B["blocking"] = false
		_counter_state_trigger()
		return
	if _walled("B", pd["row"], false): return
	if _auto_slips("B", pd["row"], body):
		_say("he slips it without looking - the wall is up"); B["blocking"] = false; return
	var row: Dictionary = T["punch_matrix"][pd["row"]]
	var dmg: float = float(row["dmg"]) * (float(P["stats"]["PWR"]) / 50.0) * float(_gassed(P)["dmg"])
	if P["charge_t"] > 0: dmg *= 1.1
	if "POWER" in pd["mods"]: dmg *= float(T["modifiers"]["POWER"]["dmg_mult"]) * float(P["pkg"].get("power_dmg_mult", 1.0))
	if body: dmg *= float(T["modifiers"]["BODY"]["dmg_mult"])
	if pd["counter"]: dmg *= float(T["counter_mults"]["counter"])
	if pd["flash"]: dmg *= float(T["counter_mults"]["flash"])
	dmg *= _zone_mult(B["pos"])
	if zone(B["pos"]) == "ROPES": dmg *= float(P["pkg"].get("ropes_dmg_mult", 1.0))          # the slugger on the ropes (s1.2)
	# guard layer (boss blocking, not dodged)
	var src := {"counter": pd["counter"], "flash": pd["flash"], "power": "POWER" in pd["mods"], "body": body, "hissatsu": false, "jab": _punch_family(pd["row"]) == "STRAIGHT" and not ("POWER" in pd["mods"])}
	if (B["blocking"] or B["guard_t"] > 0) and B["guard_open_t"] <= 0 and not pd["hissatsu"]:
		B["blocking"] = false
		B["guard"] -= float(row["guard_dmg"]) * (0.8 if body else 1.0) * (float(P["pkg"].get("power_shred_mult", 1.0)) if _power_class(pd["row"], "POWER" in pd["mods"]) else 1.0)
		_comp_damage("B", dmg * float(T["guard"]["chip_pct"]) / 100.0, src)
		if B["guard"] <= 0.0:
			B["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); B["guard_t"] = 0; wall_broken = true
			_say("HIS GUARD IS BROKEN")
		_ev("block", {"by": "B"})
		_counter_state_trigger()
		return
	var pf := _foul_kind(pd["row"], body, B)
	if pf != "":
		dmg *= 0.5
		_foul("P", pf)
	if bstate == "TELL":                                    # INTERRUPT
		bstate = "IDLE"; btimer = ms(800); bqueue = []
		P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"]))
		if not pd["hissatsu"]: _earn_tension(float(T.get("tension", {}).get("interrupt", 5)))
		_say("INTERRUPT! string broken - flash window open"); _ev("interrupt", {})
	if B["guard_open_t"] > 0: dmg *= float(T["guard"]["break_open_dmg_mult"])
	if cast.size() > 0 and cast["who"] == "B" and src["jab"]: _interrupt_cast("P")
	dmg = _comp_damage("B", dmg, src)
	if body: B["stamina"] = maxf(0.0, B["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]) * float(tactic_fx.get("body_drain_mult", 1.0)))
	# herding
	var push := (0.2 if pd["row"].ends_with("HOOKERCUT") or pd["row"].ends_with("FLARED") else 0.1) * float(tactic_fx.get("herd_mult", 1.0)) * float(P["pkg"].get("herd_mult", 1.0))
	B["pos"] += (B["pos"] - P["pos"]).normalized() * push; _clamp(B)
	var tier := _flag_tier()
	if tier == 0 and not pd["hissatsu"]:
		var tt: Dictionary = T.get("tension", {})
		var earn := float(tt.get("flash_hit", 5)) if pd["flash"] else (float(tt.get("counter_hit", 3)) if pd["counter"] else float(tt.get("clean_hit", 0)))
		if zone(B["pos"]) == "CENTER" and zone(P["pos"]) == "CENTER": earn += float(T["zones"]["CENTER"].get("exchange_tension_bonus", 2))
		if pd["counter"] and buffs["P"].has("bonus_tension_on_counter"): earn += float(buffs["P"]["bonus_tension_on_counter"]["v"])
		_earn_tension(earn)
	if pf == "":                                            # a foul is not a scoring blow
		_score_ep("P")
		if pd["counter"] or pd["flash"]: counters_p += 1
		if buffs["P"].has("ep_plus_on_clean"): ep_p += 1
	var stop: Dictionary = T["hit_feel"]["hitstop_ms"]
	freeze_t = maxi(freeze_t, ms(float(stop["flash_or_hissatsu"] if (pd["flash"] or pd["hissatsu"]) else (stop["counter"] if pd["counter"] else stop["normal"]))))
	_ev("hit", {"on": "B", "dmg": dmg, "counter": pd["counter"], "flash": pd["flash"], "hissatsu": pd["hissatsu"], "body": body})
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

func _counter_state_trigger() -> void:
	# COUNTER_STATE / COUNTER_ON_BLOCK: a punch that lands on his guard or whiffs
	# while he waits is answered at once (the guard was the trap)
	if B["counter_state_t"] <= 0: return
	B["counter_state_t"] = 0; B["guard_t"] = 0
	bqueue.push_front({"kind": "punch", "row": "R_STRAIGHT", "mult": 1.3, "body": false})
	bstate = "ACTING"; btimer = ms(100)
	_say("COUNTERED - you punched into the trap")

# ============================ BOSS OFFENSE =================================
func _land_boss_punch(mult: float) -> void:
	var brow: String = bpending.get("row", "R_STRAIGHT")
	var body: bool = bpending.get("body", false)
	bpending = {}
	var geo := resolve_geometry(B, P, brow, body)
	var row: Dictionary = T["punch_matrix"][brow]
	if geo == "HIT" and _walled("P", brow, body): return
	if geo == "HIT" and _auto_slips("P", brow, body): geo = "AUTO_SLIP"
	if geo != "HIT":
		var wide := 1.4 if trapped_p else 1.0
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
		if geo == "AUTO_SLIP": P["counter_t"] = _window("slip", wide)
		_ev("evade", {"by": "P", "why": geo, "dodge": P["dodge"]})
		if P["counter_state_t"] > 0: P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0; _say("COUNTER STANCE - he swung into it: flash window")
		return
	var dmg: float = float(row["dmg"]) * (float(B["stats"]["PWR"]) / 50.0) * mult * float(_gassed(B)["dmg"])
	if body: dmg *= float(T["modifiers"]["BODY"]["dmg_mult"])
	if _power_class(brow, false): dmg *= float(B["pkg"].get("power_dmg_mult", 1.0))       # his haymakers are his power punches
	dmg *= _zone_mult(P["pos"])
	if zone(P["pos"]) == "ROPES": dmg *= float(B["pkg"].get("ropes_dmg_mult", 1.0))
	var bf := _foul_kind(brow, body, P)
	if bf != "":
		if bwarnings >= _warning_cap():                      # clean fighters, and dirty ones at their cap, pull it
			_ev("pulled", {"by": "B", "foul": bf})
			_say("he pulls it off your %s - not taking the %s call" % [P["dodge"].to_lower(), bf.replace("_", " ")])
			return
		dmg *= 0.5
		_foul("B", bf)
	if P["blocking"] and P["guard_open_t"] <= 0:
		var wide := 1.4 if trapped_p else 1.0
		if P["block_t"] <= ms(float(T["guard"]["perfect_block_window_ms"])):
			P["counter_t"] = _window("perfect_block", wide)
			P["pb_streak"] += 1
			if P["counter_state_t"] > 0: P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0
			_say("PERFECT BLOCK - counter window!"); _ev("perfect_block", {})
			_earn_tension(float(T.get("tension", {}).get("perfect_defense", 2)))
			if P["pb_streak"] >= 2:
				P["pb_streak"] = 0; _fire_event("player_perfect_block_streak2")
			return
		P["pb_streak"] = 0
		P["guard"] -= float(row["guard_dmg"]) * (0.8 if body else 1.0) * (float(B["pkg"].get("power_shred_mult", 1.0)) if _power_class(brow, false) else 1.0)
		_comp_damage("P", dmg * float(T["guard"]["chip_pct"]) / 100.0, {"counter": mult > 1.0, "flash": false, "power": false, "body": body, "hissatsu": false, "jab": _punch_family(brow) == "STRAIGHT"})
		if P["counter_state_t"] > 0: P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"])); P["counter_state_t"] = 0
		if P["guard"] <= 0.0:
			P["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); _say("GUARD BREAK - you're OPEN")
		_ev("block", {"by": "P"})
		return
	if P["guard_open_t"] > 0: dmg *= float(T["guard"]["break_open_dmg_mult"])
	if cast.size() > 0 and cast["who"] == "P" and _punch_family(brow) == "STRAIGHT": _interrupt_cast("B")
	dmg = _comp_damage("P", dmg, {"counter": mult > 1.0, "flash": false, "power": false, "body": body, "hissatsu": false, "jab": _punch_family(brow) == "STRAIGHT"})
	if body: P["stamina"] = maxf(0.0, P["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]) * float(btactic_fx.get("body_drain_mult", 1.0)))
	clean_t = 0
	if bf == "":
		_score_ep("B")
		if mult > 1.0: counters_b += 1
		var tt: Dictionary = T.get("tension", {})
		var earn_b := float(tt.get("counter_hit", 3)) if mult > 1.0 else float(tt.get("clean_hit", 0))
		if zone(B["pos"]) == "CENTER" and zone(P["pos"]) == "CENTER": earn_b += float(T["zones"]["CENTER"].get("exchange_tension_bonus", 2))
		if earn_b > 0.0: _earn_tension_b(earn_b)
	P["pos"] += (P["pos"] - B["pos"]).normalized() * 0.12 * float(B["pkg"].get("herd_mult", 1.0)) * float(btactic_fx.get("herd_mult", 1.0)); _clamp(P)
	freeze_t = maxi(freeze_t, ms(float(T["hit_feel"]["hitstop_ms"]["normal"])))
	_ev("hit", {"on": "P", "dmg": dmg, "body": body})
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
	if player_down:
		drops_b += 1; P["drops"] += 1; score_b += 1
		_earn_tension_b(float(T.get("tension", {}).get("drop", 10)))
		_ev("drop", {"who": "P"})
		if r6: _say("GOLDEN DROP - %s is down" % pname()); _end_dual(); return
		if P["drops"] >= 3:
			_segment_ko(false, "three knockdowns"); return
		mode = "EIGHT"
		var w := lerpf(float(T["standing_eight"]["beat_window_ms_by_HRT"]["hrt30"]),
			float(T["standing_eight"]["beat_window_ms_by_HRT"]["hrt90"]),
			clampf((float(P["stats"]["HRT"]) - 30.0) / 60.0, 0.0, 1.0)) * 4.0
		if P["drops"] == 2: w *= 0.6                        # second drop: one beat of forgiveness gone
		eight = {"beats_left": int(T["standing_eight"]["beats"]), "window_t": ms(w), "timer_t": ms(1200), "rise_prev": false}
		_say("DOWN! Standing-eight: RISE on the beat (%d beats)" % eight["beats_left"])
	else:
		drops_p += 1; B["drops"] += 1
		score_p += 2 if flash else 1
		_earn_tension(float(T.get("tension", {}).get("drop", 10)))
		bdrop_conceded = true
		if flash: bflash_conceded = true
		B["comp"] = B["comp_max"] * float(T["composure"]["post_count_reset_pct"]) / 100.0
		B["no_regen_t"] = ms(float(T["composure"]["regen_halt_after_count_s"]) * 1000.0)
		_ev("drop", {"who": "B", "flash": flash})
		_say("%s %d-%d" % ["FLASH DROP! (2 pts)" if flash else "DROP SCORED!", score_p, score_b])
		if r6: _say("GOLDEN DROP - %s is down" % boss_name); _end_dual(); return
		if B["drops"] >= 3: _segment_ko(true, "three knockdowns")

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
	eight["timer_t"] -= 1
	if eight["timer_t"] < -eight["window_t"]:
		_say("COUNTED OUT."); eight = {}; mode = "FIGHT"
		_segment_ko(false, "counted out"); return
	var edge: bool = rise and not eight["rise_prev"]
	eight["rise_prev"] = rise
	if edge and absi(eight["timer_t"]) <= eight["window_t"]:
		eight["beats_left"] -= 1
		_ev("eight_beat", {"left": eight["beats_left"]})
		if eight["beats_left"] <= 0:
			mode = "FIGHT"; eight = {}
			P["comp"] = P["comp_max"] * float(T["composure"]["post_count_reset_pct"]) / 100.0
			P["no_regen_t"] = ms(float(T["composure"]["regen_halt_after_count_s"]) * 1000.0)
			_earn_tension(float(T["standing_eight"]["crowd_surge_tension"]))
			_say("UP AT EIGHT! Crowd surge - composure regen halted 10s")
			return
		eight["timer_t"] = ms(1200)
		_say("beat! %d to go" % eight["beats_left"])

# ============================ DUAL FLOW ====================================
func _end_segment(why: String) -> void:
	P["pending"] = {}; bpending = {}; eight = {}; cast = {}; clinch = {}; clinch_t = 0
	charged = contributed >= 25.0
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
	_ev("corner_open", {"seconds": int(c.get("seconds", 45)), "actions": corner["actions_left"], "next": lineup[upn]["name"], "boss": "?" if bool(fmt.get("blind", false)) else blineup[upn], "r6": r6})
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
		if str(st["id"]) in eq.get("staff", []): out["staff"].append({"id": str(st["id"]), "name": str(st["name"]), "charges": int(staff_charges.get(str(st["id"]), 0)), "text": str(st["text"])})
	return out

func _swap_cost() -> int:
	var c: Dictionary = TAC.get("corner", {})
	return 0 if (swaps_used == 0 and bool(c.get("swap_first_free", true))) else int(c.get("swap_cost", 15))

func _corner_refuse(kind: String, why: String) -> void:
	_ev("corner_refused", {"action": kind, "why": why}); _say("corner: %s - %s" % [kind, why])

func corner_action(a: Dictionary) -> bool:
	# NP_10 s4: two actions per corner; each kind has its own price
	if mode != "CORNER": return false
	var kind := str(a.get("kind", ""))
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
			var stid := str(a.get("id", ""))
			var strec: Dictionary = {}
			for st in TAC.get("staff_active", []):
				if str(st["id"]) == stid: strec = st
			if strec.is_empty() or not stid in eq.get("staff", []): _corner_refuse(kind, "%s is not dressed" % stid); return false
			if int(staff_charges.get(stid, 0)) <= 0: _corner_refuse(kind, "%s has no charges left" % strec["name"]); return false
			staff_charges[stid] = int(staff_charges[stid]) - 1
			var fx: Dictionary = strec["effect"]
			if fx.has("tension_plus"): _earn_tension(float(fx["tension_plus"]))
			if fx.has("reveal_next"):
				if bool(fmt.get("blind", false)): _corner_refuse(kind, "blind dual - no reveals"); staff_charges[stid] = int(staff_charges[stid]) + 1; return false
				_ev("reveal", {"boss": blineup[_up_slot()]}); _say("THE REVEAL: their next slot is %s" % blineup[_up_slot()])
			for k in fx:
				if k != "tension_plus" and k != "reveal_next": pending_fx[k] = fx[k]
			_say("STAFF: %s (%s) - %s" % [strec["name"], strec["role"], strec["text"]])
		"save_bar":
			if save_bar_next: _corner_refuse(kind, "already holding"); return false
			save_bar_next = true
			_say("SAVE THE BAR: no spending next segment; +%d if it is won anyway" % int(c.get("save_bar_bonus", 5)))
		_:
			_corner_refuse(kind, "unknown action"); return false
	corner["actions_left"] = int(corner["actions_left"]) - 1
	corner["log"].append(kind)
	_ev("corner_action", {"action": kind, "arg": str(a.get("arg", a.get("id", ""))), "left": corner["actions_left"]})
	return true

func _end_dual() -> void:
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
	_say("DUAL OVER :: %s   SCORE %d-%d (drops %d-%d)   segments %d-%d   counters %d-%d   EP %d-%d" % [v, score_p, score_b, drops_p, drops_b, seg_wins_p, seg_wins_b, counters_p, counters_b, ep_p, ep_b])

func freshest(cards: Array, cond: Dictionary) -> int:
	# the dressed fighter in the best condition (composure fraction; an unfought card is whole), first in order on ties
	var best := 0; var best_v := -1.0
	for i in cards.size():
		var nm := str(cards[i]["name"]) if cards[i] is Dictionary else str(cards[i])
		var v := 1.0
		if cond.has(nm):
			var cm: float = float(cards[i]["stats"]["CHN"]) * 2.0 if cards[i] is Dictionary else 120.0
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
	_reset_dual(_first_boss)

func switch_boss(i: int) -> void:
	_first_boss = clampi(i, 0, boss_names.size() - 1)
	_reset_dual(_first_boss)

# ============================ TRACKER (C7) =================================
func _track(row: String) -> void:
	tokens.append(row)
	if tokens.size() > int(T["adaptation_tracker"]["window_tokens"]): tokens.pop_front()
	for size in [2, 3]:
		if tokens.size() >= size:
			var gram := ",".join(tokens.slice(tokens.size() - size))
			var cnt := 0
			for i in range(tokens.size() - size + 1):
				if ",".join(tokens.slice(i, i + size)) == gram: cnt += 1
			if cnt >= int(T["adaptation_tracker"]["flag_at_count"]):
				var prev: int = flags.get(gram, [0, 0])[0]
				flags[gram] = [mini(3, prev + 1), 0]
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
	for t in pattern["strings"][sname]["tags"]:
		if str(t).begins_with("phase>="): return bphase >= int(str(t).split(">=")[1])
	return true

func _force_string(sname: String, tell_scale: float, loud: bool, opts: Dictionary = {}) -> void:
	bstring = sname; bstate = "TELL"; bforce_opts = opts
	btimer = maxi(1, int(ms(float(pattern["strings"][sname]["tell"]["ms"])) * tell_scale * float(tactic_fx.get("tell_loud_mult", 1.0))))
	tell_start_tick = tick; tell_reacted = false
	_ev("tell", {"ticks": btimer, "loud": loud, "string": sname, "jammed": states["P"].has("tell_jam_audio") or states["P"].has("tell_jam_visual"), "highlight": tell_highlight_t > 0})

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
	if not hooks_enabled: return
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
		punish_cd[pk] = ms(4000)
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
	var opts: Dictionary = bforce_opts
	var dist: float = B["pos"].distance_to(P["pos"])
	match act["kind"]:
		"punch":
			var row: Dictionary = T["punch_matrix"][act["row"]]
			var mult: float = float(act["mult"]) * float(opts.get("mult", 1.0))
			if P["busy_t"] > 0 and float(act["mult"]) > 1.0: mult *= 1.15      # a true counter finds a committed fighter
			bpending = {"row": act["row"], "body": bool(act["body"]) or bool(opts.get("body", false))}
			B["pos"] += (P["pos"] - B["pos"]).normalized() * LUNGE_B; _clamp(B)
			_ev("boss_act", {"verb": "punch", "row": act["row"]})
			_land_boss_punch(mult)
			return int(ms(float(row["recovery_ms"])) * 0.7)
		"move":
			var fwd: Vector2 = (P["pos"] - B["pos"]).normalized()
			var step_v := Vector2.ZERO
			match act["dir"]:
				"toward": step_v = fwd * float(act["dist"])
				"away": step_v = -fwd * float(act["dist"])
				"lateral": step_v = Vector2(fwd.y, -fwd.x) * float(act["dist"]) * (1.0 if rng.randf() < 0.5 else -1.0)
				"center": step_v = (Vector2.ZERO - B["pos"]).limit_length(float(act["dist"]))
			B["pos"] += step_v; _clamp(B)
			if B["pos"].distance_to(P["pos"]) < 0.9:                                   # bodies meet: he walks you back
				P["pos"] = B["pos"] + (P["pos"] - B["pos"]).normalized() * 0.9; _clamp(P)
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
	bqueue = []; bpending = {}; bstate = "IDLE"; btimer = clinch_t + ms(300)
	_ev("clinch", {"by": by, "need": need})
	_say("CLINCH%s - alternate L/R on the cue (%d beats to win it)" % [" - he grabs you" if by == "B" else "", need])

func _clinch_step(inp: Dictionary) -> void:
	clinch["t"] += 1
	var t: int = clinch["t"]
	clinch_t = int(clinch["end"]) - t
	var i: int = clinch["i"]
	var cues: Array = clinch["cues"]
	# the tap: a stick edge past 0.6 on either side, or the button parity path
	var mx := float(inp.get("move", Vector2.ZERO).x)
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
	if str(mv["tier"]) == "T3" and not t3_unlocked: return false
	return true

func hiss_cost(mv: Dictionary) -> float:
	if mv.is_empty(): return 1e9
	var cost := float(mv["tension_cost"])
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
		cost = hiss_cost(mv); tension = maxf(0.0, tension - cost); hiss_casts_seg += 1
		P["cmd"] = {}; P["pending"] = {}
	else:
		cost = float(mv.get("tension_cost", 0)); btension = maxf(0.0, btension - cost)   # his bar pays what it can; the desperation is authored and always goes
	var total := ms(float(mv["startup_cinematic_ms"]))
	var cp: Dictionary = mv["counter_profile"]
	cast = {"who": who, "move": mv, "t": total, "total": total, "interruptible": bool(cp["interruptible"]),
		"window_t": ms(float(cp["window_ms"])), "cost": cost, "lunge_left": 0.5}
	A["busy_t"] = maxi(A["busy_t"], total + ms(300)); A["dodge"] = ""; A["dodge_t"] = 0; A["dodge_plan"] = []; A["dodge_at"] = 0
	if who == "B":
		bstate = "CAST"; btimer = 1 << 30; bqueue = []; bpending = {}; bstring = ""
	var shown := arm_only if arm_only != "" else str(mv["name"])
	var ghost := ""
	if who == "P" and str(mv["tier"]) == "T3" and seg_idx > 0: ghost = str(lineup[seg_idx - 1]["name"])   # s7: the previous fighter joins as a spirit afterimage
	_ev("cast", {"who": who, "move": str(mv["name"]), "shown": shown, "tier": str(mv["tier"]), "family": str(mv["family"]),
		"windup": total, "interruptible": cast["interruptible"], "window": cast["window_t"], "arm_only": arm_only != "",
		"afterimage": ghost, "trail": full_relay and str(mv["tier"]) == "T3"})
	if who == "P": _say("%s ARMS %s (%s %s, %d Tension)" % [pname(), shown.to_upper(), mv["tier"], mv["family"], int(cost)])
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
	if who == "P": tension = minf(100.0, tension + float(cast["cost"]) * 0.5)
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
	cast = {}
	var flags := {"beats_duck": false, "echo": false, "range_plus": 0.0, "hm": hm}
	for e in mv["effect"]:                                   # instants that shape this cast are read first
		var pr: Dictionary = e["params"]
		if str(e["type"]) == "STATE" and str(pr["name"]) == "beats_duck_reads": flags["beats_duck"] = true
		if str(e["type"]) == "STATE" and str(pr["name"]) == "two_hit_echo": flags["echo"] = true
		if str(e["type"]) == "BUFF" and str(pr["name"]) == "range_plus": flags["range_plus"] = 0.5
	_ev("cast_resolve", {"who": who, "move": str(mv["name"])})
	# declaratives first (states, buffs, walls shape the packets), then the packets in data order
	for e in mv["effect"]:
		var pr: Dictionary = e["params"]
		match str(e["type"]):
			"STATE": _fx_state(who, str(pr["name"]), float(pr.get("seconds", 0)))
			"BUFF": _fx_buff(who, str(pr["name"]), pr)
			"WALL":
				var secs := float(pr["seconds"])
				if secs > 0.0 and _beats("element", A["element"], D["element"]): secs += float(AFF.get("element", {}).get("beaten_wall_plus_s", 1.0))   # s2.1: his walls stand longer against the element he beats
				_fx_wall(who, float(pr["points"]) * hm, secs)
	for e in mv["effect"]:
		var pr: Dictionary = e["params"]
		match str(e["type"]):
			"DMG": _fx_dmg(who, A, D, mv, pr, flags)
			"DISPLACE": _fx_displace(who, A, D, {"toward": pr["toward"], "meters": float(pr["meters"]) * hm})
			"SHRED": _fx_shred(D, float(pr["guard"]) * hm)
			"BURN": D["stamina"] = maxf(0.0, D["stamina"] - float(pr["stamina"]) * hm); _say("stamina burned -%d" % int(float(pr["stamina"]) * hm))
		if mode != "FIGHT": return
	A["busy_t"] = ms(300)
	if who == "B": bstate = "RECOVER"; btimer = ms(600)
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
	var per_hit: float = float(row["dmg"]) * (float(A["stats"]["PWR"]) / 50.0) * mult * float(flags.get("hm", 1.0))
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
			if body: D["stamina"] = maxf(0.0, D["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]))
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
				A["pos"] += Vector2(fwd.y, -fwd.x) * seconds * (1.0 if rng.randf() < 0.5 else -1.0); _clamp(A)
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
	if not states[dkey].has("auto_slip") or int(states[dkey]["auto_slip"]) <= 0: return false
	_ev("evade", {"by": dkey, "why": "AUTO_SLIP", "dodge": "AUTO"})
	return true

func _earn_tension(v: float) -> void:
	if states["P"].has("enemy_tension_earn_minus25pct"): v *= 0.75
	v *= float(tactic_fx.get("tension_earn_mult", 1.0))
	if aff.get("feud", false): v *= float(AFF.get("house", {}).get("feud_tension_mult", 1.25))   # NP_06 s3: feuds are Tension geysers
	tension = minf(100.0, tension + v); contributed += v

func _wall_tick() -> void:
	for k in ["P", "B"]:
		var w: Dictionary = wall[k]
		if w.size() == 0: continue
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
	for ph in pattern.get("phases", []):
		var target := bphase + 1
		if str(ph["phase"]).is_valid_int(): target = int(ph["phase"])
		if _phase_trigger_met(str(ph["trigger"])) and target > bphase:
			bphase = target
			_ev("phase", {"phase": bphase})
			_say("PHASE %d - he's changing" % bphase)
	var d: Dictionary = pattern.get("desperation") if pattern.get("desperation") != null else {}
	var desp_pct := 25.0
	if d.has("trigger") and "composure<" in str(d["trigger"]): desp_pct = float(str(d["trigger"]).split("composure<")[1])
	if not bdesp_used and d.has("move") and B["comp"] <= B["comp_max"] * desp_pct / 100.0 and cast.is_empty() and clinch.is_empty():
		bdesp_used = true
		var mv_b: Dictionary = library.get(str(d["move"]), {})
		if mv_b.is_empty():
			_say("(desperation %s is not in the library)" % str(d["move"])); return
		_start_cast("B", mv_b, str(d.get("arm_only", "")) if d.get("arm_only") != null else "")
		return
	btimer -= 1
	if btimer > 0: return
	match bstate:
		"IDLE", "RECOVER":
			# Marta's inverted bait: with the player refusing to lead, she drops her hands
			if _has_bait("trap_stance_hands_down") and passive_t >= ms(3000) and hands_down_t == 0 and rng.randf() < 0.5:
				hands_down_t = ms(2500); btimer = hands_down_t + 1; bstate = "IDLE"
				_ev("stance", {"hands_down": true}); _say("she drops her hands - it's an invitation")
				return
			var w: Dictionary = {}
			for k in pattern["select"]["weights"]:
				if k in pattern["strings"] and _phase_ok(k) and int(pattern["select"]["weights"][k]) > 0: w[k] = int(pattern["select"]["weights"][k])
			for k in pattern["strings"]:
				if not k in w and _phase_ok(k): w[k] = 15
			var total := 0
			for k in w: total += w[k]
			var r := rng.randf() * total
			for k in w:
				r -= w[k]
				if r <= 0.0: bstring = k; break
			var s: Dictionary = pattern["strings"][bstring]
			# Tam's borrowed clothes: in phase 1 some tells are performances with nothing behind them
			if _has_bait("reacts_to_fake_tell") and bphase == 1 and rng.randf() < 0.35:
				bstate = "FAKE"; bforce_opts = {}; btimer = ms(float(s["tell"]["ms"]))
				_ev("tell", {"ticks": btimer, "loud": s["class"] != "normal", "string": bstring, "fake": true})
				return
			bstate = "TELL"; bforce_opts = {}; btimer = int(ms(float(s["tell"]["ms"])) * float(tactic_fx.get("tell_loud_mult", 1.0)))
			tell_start_tick = tick; tell_reacted = false
			_ev("tell", {"ticks": btimer, "loud": s["class"] != "normal", "string": bstring, "jammed": states["P"].has("tell_jam_audio") or states["P"].has("tell_jam_visual"), "highlight": tell_highlight_t > 0})
		"FAKE":
			bstate = "RECOVER"; btimer = ms(300); bstring = ""
			_ev("recover", {})
		"CAST":
			btimer = 1 << 30                                 # the cast tick drives this; resolve sets RECOVER
		"TELL":
			if bstring != "":
				bqueue = []
				bqueue.append_array(bforce_opts.get("pre", []))
				for a in pattern["strings"][bstring]["actions"]:
					bqueue.append_array(parse_action(str(a)))
				bqueue.append_array(bforce_opts.get("post", []))
			bstate = "ACTING"; btimer = 0
			return
		"ACTING":
			if bqueue.is_empty():
				bstate = "RECOVER"; btimer = ms(400 + rng.randi_range(0, 400)); bforce_opts = {}
				_ev("recover", {})
				return
			var atk: Dictionary = bqueue.pop_front()
			btimer = _boss_act(atk)

# ============================ STEP =========================================
func step(inp: Dictionary) -> void:
	tick += 1
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
		if inp.get("restart", false): new_dual()
		return
	if mode == "EIGHT":
		_eight_step(inp.get("rise", false)); return
	if freeze_t > 0:
		freeze_t -= 1                                       # C5 hitstop: everyone frozen...
		var frozen_pr: String = inp.get("punch", "")
		if frozen_pr != "": _queue_punch(frozen_pr, inp)    # ...but the buffer (C3) never eats an input
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
		var acting: bool = F["busy_t"] > 0
		if F["busy_t"] > 0: F["busy_t"] -= 1
		var sreg := 1.0
		if buffs[fk].has("stamina_regen_x2"): sreg = 2.0
		elif buffs[fk].has("stamina_regen_x1_5"): sreg = 1.5
		F["stamina"] = minf(stamina_cap if F == P else 100.0, F["stamina"] + float(T["stamina"]["regen_active_per_s"] if acting else T["stamina"]["regen_neutral_per_s"]) * sreg * DT)
		if F["no_regen_t"] > 0: F["no_regen_t"] -= 1
		else: F["comp"] = minf(F["comp_max"], F["comp"] + float(T["composure"]["regen_per_s"]) * DT)
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
			if F["cmd"]["expire_t"] <= 0: F["cmd"] = {}
	_tracker_tick()
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
	block_prev = block_now
	P["blocking"] = block_now and not dodging
	if P["blocking"]:
		P["block_t"] += 1; block_hold_t += 1
		var decay := float(T["guard"]["hold_decay_per_s"]) * (float(T["zones"]["CORNER"]["guard_decay_mult"]) if zone(P["pos"]) == "CORNER" else 1.0) * float(tactic_fx.get("guard_decay_mult", 1.0))
		P["guard"] = maxf(0.0, P["guard"] - decay * DT)
		if block_hold_t == ms(2000): _fire_event("player_block_hold")
		if block_hold_t == ms(float(sensors["guard_s"]) * 1000.0): _fire_event("player_static_guard"); _fire_event("player_high_guard")
	else:
		P["block_t"] = 0; block_hold_t = 0
		var greg := float(T["guard"]["regen_per_s"])
		if buffs["P"].has("guard_regen_x2"): greg *= 2.0
		if buffs["P"].has("guard_regen_plus"): greg += 3.0
		if states["P"].has("guard_regen_minus1"): greg -= 1.0
		P["guard"] = minf(P["guard_max"], P["guard"] + greg * DT)
	# the WALL motion: LB + block held 400ms casts a WALL-family move
	var mv_w := player_move()
	if inp.get("lb", false) and block_now and not mv_w.is_empty() and str(mv_w["family"]) == "WALL":
		lb_block_t += 1
		if lb_block_t == ms(400) and cast.is_empty() and castable(mv_w) and tension >= hiss_cost(mv_w) and not save_bar: _start_cast("P", mv_w)
	else: lb_block_t = 0
	var casting_p: bool = cast.size() > 0 and cast["who"] == "P"
	var mv: Vector2 = inp.get("move", Vector2.ZERO) if not (dodging or clinch_t > 0 or casting_p) else Vector2.ZERO
	var spd := lerpf(2.2, 3.4, float(P["stats"]["SPD"]) / 99.0) * float(_gassed(P)["foot_speed"]) * _speed_mult("P")
	if _wobbled(P): spd *= float(T["composure"]["wobble_move_mult"])
	var fwd: Vector2 = (B["pos"] - P["pos"]).normalized()
	var right := Vector2(fwd.y, -fwd.x)
	var before: Vector2 = P["pos"]
	var dist0: float = B["pos"].distance_to(P["pos"])
	P["pos"] += (right * mv.x - fwd * mv.y) * spd * DT * (float(P["pkg"].get("backpedal_mult", T["movement"].get("backpedal_mult", 0.7))) if mv.y > 0 else 1.0)
	_clamp(P)
	# sprint-step (NP_03 s2.4): 0.8m burst, -4 stamina; toward him it is an approach, away it is a back-step
	if inp.get("sprint", false) and sprint_cd <= 0 and not dodging and clinch.is_empty():
		var sdir: Vector2 = (right * mv.x - fwd * mv.y).normalized() if mv.length() > 0.2 else fwd
		P["pos"] += sdir * float(T["movement"]["sprint_step_m"]); _clamp(P)
		if not tactic_fx.get("sprint_free", false): P["stamina"] = maxf(0.0, P["stamina"] - float(T["movement"]["sprint_step_stamina"]) * float(P["pkg"].get("move_stamina_mult", 1.0)))
		sprint_cd = ms(400)
		var toward := sdir.dot(fwd)
		_ev("sprint", {"toward": toward})
		if toward > 0.5 and dist0 > 1.4: _fire_event("player_sprint_approach")
		if toward < -0.5:
			backstep_ticks.append(tick)
			while backstep_ticks.size() > 0 and tick - int(backstep_ticks[0]) > ms(4000): backstep_ticks.pop_front()
			if backstep_ticks.size() >= 3:
				backstep_ticks = []; _fire_event("player_backstep_chain3")
	p_vel = (P["pos"] - before) / DT
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
		and int(P["pending"]["startup"]) - int(P["pending"]["t"]) <= ms(float(T["feint"]["cancel_within_ms"])):
		_feint()
	# reactions to tells: what you did first after the tell started, and how fast
	var reacted_now: bool = dg != "" or block_edge or executed
	if bstate == "FAKE" and reacted_now: _fire_event("player_reacts_to_fake_tell")
	if bstate == "TELL" and reacted_now and not tell_reacted and tell_start_tick >= 0:
		tell_reacted = true
		react_ticks.append(tick - tell_start_tick)
		if react_ticks.size() > 3: react_ticks.pop_front()
		if audio_assist and react_ticks.size() == 3:
			var all_fast := true
			for rt in react_ticks:
				if int(rt) >= ms(300): all_fast = false
			if all_fast:
				react_ticks = []; _fire_event("player_audio_assist_reliance")
	if P["pending"].size() > 0:
		P["pending"]["t"] -= 1
		if P["pending"]["t"] <= 0: _land_player_punch()
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
	if dist > ENGAGE_DIST and bstate != "ACTING" and bstate != "CAST":
		var intercept: Vector2 = P["pos"] + p_vel * 0.35
		B["pos"] += (intercept - B["pos"]).normalized() * 1.2 * (float(T["composure"]["wobble_move_mult"]) if _wobbled(B) else 1.0) * _speed_mult("B") * DT; _clamp(B)
	# NP_03 s7: a wobbled fighter grabs to survive - once per segment, at 0-range, between his own actions
	if not bsurvival_used and _wobbled(B) and dist <= 1.3 and bstate != "ACTING" and bstate != "CAST" and cast.is_empty() and mode == "FIGHT":
		bsurvival_used = true
		_start_clinch("B", 0.3, 2)
		_say("he's hurt and he GRABS - survival clinch, ride it out or win the position")
		_ev("survival_grab", {})
		return
	var rate := 0.6 if P["flash_t"] > 0 else 1.0
	boss_acc += rate
	while boss_acc >= 1.0:
		boss_acc -= 1.0
		_boss_step()
		if mode != "FIGHT": break
	_separate()
	if clock_t <= 0 and mode == "FIGHT": _end_segment("clock")

func hash_state() -> int:
	# bit-exact: serialises the raw values, no float formatting, no rounding
	var v := [tick, P["pos"], B["pos"], P["stamina"], P["comp"], P["guard"], P["busy_t"],
		P["dodge"], P["dodge_t"], P["counter_t"], P["flash_t"], P["cmd"], P["pending"],
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
		condition, bcondition, seg_wins_p, seg_wins_b, counters_p, counters_b, r6, fmt.get("id", ""), lineup.map(func(f): return str(f["name"])), rng.state]
	return v.hash()

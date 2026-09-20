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
const LINEUP_MILLBROOK := [
	{"name": "RORY",   "hissatsu": "Aurora Borealis Breaker", "stats": {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}},
	{"name": "PRIYA",  "hissatsu": "First Snap", "stats": {"PWR": 35, "SPD": 60, "CHN": 40, "RFX": 70, "BLK": 50, "STA": 55, "HRT": 60}},
	{"name": "MARCUS", "hissatsu": "Chinook Rush", "stats": {"PWR": 70, "SPD": 40, "CHN": 65, "RFX": 35, "BLK": 40, "STA": 55, "HRT": 70}},
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
var hiss_threshold := 100.0

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
var library: Dictionary = {}         # hissatsu name -> house_id (data/hissatsu_library.v2.json)
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
var bwarnings := 0
var pwarnings := 0
var block_prev := false

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
	for m in raw.get("moves", []): lib[str(m["name"])] = str(m["house_id"]) if m.get("house_id") != null else ""
	return {"tuning": load_json(base + "combat_tuning.v1.json"), "patterns": pats, "library": lib}

func setup(tuning: Dictionary, pats: Dictionary, names: Array, lineup_p: Array, first_boss: int, seed_v: int, lib: Dictionary = {}) -> void:
	T = tuning; patterns = pats; boss_names = names; lineup = lineup_p; library = lib
	rng.seed = seed_v
	boss_names = names
	_reset_dual(first_boss)

func _reset_dual(first_boss: int) -> void:
	seg_idx = 0; drops_p = 0; drops_b = 0; score_p = 0; score_b = 0; ep_p = 0; ep_b = 0
	tension = 0.0; charged = false; mode = "FIGHT"
	_first_boss = first_boss
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
	boss_name = boss_names[(_first_boss + seg_idx) % boss_names.size()]
	pattern = patterns[boss_name].duplicate(true)
	B = _fresh({"PWR": 60, "SPD": 55, "CHN": 60, "RFX": 55, "BLK": 55, "STA": 60, "HRT": 60}, Vector2(0, -1.0))
	bstate = "IDLE"; btimer = ms(600); bqueue = []; bphase = 1; bdesp_used = false; bpending = {}
	clock_t = ms(90000); contributed = 0.0
	tokens = []; flags = {}; hiss_threshold = 100.0
	center_hold_t = 0; block_hold_t = 0; punch_ticks = []; punch_rows = []
	last_zone_p = "MID"; punish_cd = {}; gassed_fired = false; taunt_t = 0
	pinned_p_t = 0; pinned_b_t = 0; trapped_p = false; trapped_b = false
	freeze_t = 0; boss_acc = 0.0; eight = {}
	bforce_opts = {}; swap_restore = {}; clinch_t = 0; wall_broken = false; rope_time_t = 0
	passive_t = 0; clean_t = 0; head_streak = 0; tier_fired = 0
	clinch = {}; clinch_ticks = []; sprint_cd = 0; backstep_ticks = []; retreat_d = 0.0
	neutral_t = 0; neutral_cd = 0; cadence = []; hands_down_t = 0
	tell_start_tick = -1; tell_reacted = false; react_ticks = []; bwarnings = 0; pwarnings = 0; block_prev = false
	sensors = _parse_sensors(pattern)
	if charged:
		P["charge_t"] = ms(10000); hiss_threshold = 50.0; charged = false
		_say("R%d: %s enters CHARGED - surge 10s, hissatsu at 50! vs %s" % [seg_idx + 1, f["name"], boss_name])
	else:
		_say("R%d: %s vs %s" % [seg_idx + 1, f["name"], boss_name])
	mode = "FIGHT"

func pname() -> String: return lineup[seg_idx]["name"]

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
			lat = float(DODGE[D["dodge"]]["lat"]) * float(D["dodge_dir"]) * 0.4
			back = float(DODGE[D["dodge"]]["back"])
		tp = D["pos"] + fwd * back + rightD * lat     # fwd here points A->D, so +fwd*back moves D away
		th = 1.10
	var rel: Vector2 = tp - A["pos"]
	var d := rel.dot(fwd)
	var l := rel.dot(rightA)
	if row.begins_with("L_"): l = -l                 # mirror for the left hand
	if d > float(g["reach"]): return "MISS_REACH"
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
	if counter: p *= 0.25
	if flash: p = 0.02
	if hiss: p = 0.0
	return p

func _try_execute_cmd() -> bool:
	if P["cmd"].is_empty() or P["busy_t"] > 0: return false
	var c: Dictionary = P["cmd"]; P["cmd"] = {}
	var row: Dictionary = T["punch_matrix"][c["row"]]
	var startup := ms(float(row["startup_ms"]) * (1.4 if "POWER" in c["mods"] else 1.0))
	var hiss: bool = c["lb"] and tension >= hiss_threshold and c["row"].ends_with("HOOKERCUT")
	threw_since_arm = true
	P["pending"] = {"row": c["row"], "t": startup, "mods": c["mods"], "hissatsu": hiss,
		"counter": P["counter_t"] > 0, "flash": P["flash_t"] > 0}
	P["counter_t"] = 0                                     # window spent by the attempt
	P["busy_t"] = startup + ms(float(row["recovery_ms"]))
	P["stamina"] = maxf(0.0, P["stamina"] - float(row["stamina"]) * (2.0 if "POWER" in c["mods"] else 1.0))
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
	else:
		B["blocking"] = rng.randf() < 0.35
		B["block_t"] = 999 if B["blocking"] else 0
	# ---- PAC-054 sensors that live on the punch itself ----
	if hiss:
		var house := str(library.get(str(lineup[seg_idx].get("hissatsu", "")), ""))
		if house != "" and house == str(pattern.get("meta", {}).get("house", "")):
			_fire_event("player_casts_%s_native" % house)
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

func _land_player_punch() -> void:
	var pd: Dictionary = P["pending"]; P["pending"] = {}
	var body: bool = "BODY" in pd["mods"]
	var geo := resolve_geometry(P, B, pd["row"], body)
	if geo != "HIT":
		if geo == "MISS_REACH" and ("POWER" in pd["mods"] or pd["row"].ends_with("HOOKERCUT")):
			_fire_event("player_power_whiff")
		if body: _fire_event("player_whiffed_body_shot")
		_ev("whiff", {"by": "P", "why": geo})
		if geo != "MISS_REACH": _say("he made you miss (%s)" % geo.to_lower().replace("miss_", ""))
		B["blocking"] = false
		_counter_state_trigger()
		return
	var row: Dictionary = T["punch_matrix"][pd["row"]]
	var dmg: float = float(row["dmg"]) * (float(P["stats"]["PWR"]) / 50.0) * float(_gassed(P)["dmg"])
	if P["charge_t"] > 0: dmg *= 1.1
	if "POWER" in pd["mods"]: dmg *= float(T["modifiers"]["POWER"]["dmg_mult"])
	if body: dmg *= float(T["modifiers"]["BODY"]["dmg_mult"])
	if pd["hissatsu"]:
		tension = 0.0; dmg *= 2.5; freeze_t = ms(200)
		_say("AURORA BOREALIS BREAKER!"); _ev("hissatsu", {})
	if pd["counter"]: dmg *= float(T["counter_mults"]["counter"])
	if pd["flash"]: dmg *= float(T["counter_mults"]["flash"])
	dmg *= _zone_mult(B["pos"])
	# guard layer (boss blocking, not dodged)
	if (B["blocking"] or B["guard_t"] > 0) and B["guard_open_t"] <= 0 and not pd["hissatsu"]:
		B["blocking"] = false
		B["guard"] -= float(row["guard_dmg"]) * (0.8 if body else 1.0)
		B["comp"] -= dmg * float(T["guard"]["chip_pct"]) / 100.0
		if B["guard"] <= 0.0:
			B["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); B["guard_t"] = 0; wall_broken = true
			_say("HIS GUARD IS BROKEN")
		_ev("block", {"by": "B"})
		_counter_state_trigger()
		return
	if bstate == "TELL":                                    # INTERRUPT
		bstate = "IDLE"; btimer = ms(800); bqueue = []
		P["flash_t"] = ms(float(T["counter_windows_ms"]["flash"]["base"]))
		if not pd["hissatsu"]:
			tension = minf(100.0, tension + 5.0); contributed += 5.0
		_say("INTERRUPT! string broken - flash window open"); _ev("interrupt", {})
	if B["guard_open_t"] > 0: dmg *= float(T["guard"]["break_open_dmg_mult"])
	B["comp"] -= dmg
	if body: B["stamina"] = maxf(0.0, B["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]))
	# herding
	var push := 0.2 if pd["row"].ends_with("HOOKERCUT") or pd["row"].ends_with("FLARED") else 0.1
	B["pos"] += (B["pos"] - P["pos"]).normalized() * push; _clamp(B)
	var tier := _flag_tier()
	if tier == 0 and not pd["hissatsu"]:
		var earn := 3.0 if pd["counter"] else 1.5
		if zone(B["pos"]) == "CENTER" and zone(P["pos"]) == "CENTER": earn += 2.0
		tension = minf(100.0, tension + earn); contributed += earn
	ep_p += 2
	var stop: Dictionary = T["hit_feel"]["hitstop_ms"]
	freeze_t = maxi(freeze_t, ms(float(stop["flash_or_hissatsu"] if (pd["flash"] or pd["hissatsu"]) else (stop["counter"] if pd["counter"] else stop["normal"]))))
	_ev("hit", {"on": "B", "dmg": dmg, "counter": pd["counter"], "flash": pd["flash"], "hissatsu": pd["hissatsu"], "body": body})
	if pd["counter"] and not pd["hissatsu"]: _say("FLASH COUNTER x2!" if pd["flash"] else "COUNTER x1.6!")
	if B["comp"] <= 0.0: _drop(false, pd["flash"])

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
	if geo != "HIT":
		var wide := 1.4 if trapped_p else 1.0
		if P["dodge"] != "":
			match P["dodge"]:
				"SLIP": P["counter_t"] = int(ms(float(T["counter_windows_ms"]["slip"]["base"])) * wide)
				"DUCK": P["counter_t"] = int(ms(float(T["counter_windows_ms"]["duck"]["base"])) * wide)
				"LEAN": P["counter_t"] = int(ms(float(T["counter_windows_ms"]["perfect_block"]["base"])) * 0.8 * wide)
				"WEAVE":
					P["counter_t"] = int(ms(float(T["counter_windows_ms"]["weave"]["base"])) * wide)
					pinned_p_t = 0; trapped_p = false
			_say("%s - counter window!%s" % [P["dodge"].to_lower() + "ped it" if P["dodge"] != "LEAN" else "leaned under it", "  [trapped read: wider]" if trapped_p else ""])
		_ev("evade", {"by": "P", "why": geo, "dodge": P["dodge"]})
		return
	var dmg: float = float(row["dmg"]) * (float(B["stats"]["PWR"]) / 50.0) * mult * float(_gassed(B)["dmg"])
	if body: dmg *= float(T["modifiers"]["BODY"]["dmg_mult"])
	dmg *= _zone_mult(P["pos"])
	if P["blocking"] and P["guard_open_t"] <= 0:
		var wide := 1.4 if trapped_p else 1.0
		if P["block_t"] <= ms(float(T["guard"]["perfect_block_window_ms"])):
			P["counter_t"] = int(ms(float(T["counter_windows_ms"]["perfect_block"]["base"])) * wide)
			P["pb_streak"] += 1
			_say("PERFECT BLOCK - counter window!"); _ev("perfect_block", {})
			if P["pb_streak"] >= 2:
				P["pb_streak"] = 0; _fire_event("player_perfect_block_streak2")
			return
		P["pb_streak"] = 0
		P["guard"] -= float(row["guard_dmg"]) * (0.8 if body else 1.0)
		P["comp"] -= dmg * float(T["guard"]["chip_pct"]) / 100.0
		if P["guard"] <= 0.0:
			P["guard_open_t"] = ms(float(T["guard"]["break_open_ms"])); _say("GUARD BREAK - you're OPEN")
		_ev("block", {"by": "P"})
		return
	P["comp"] -= dmg * (float(T["guard"]["break_open_dmg_mult"]) if P["guard_open_t"] > 0 else 1.0)
	if body: P["stamina"] = maxf(0.0, P["stamina"] - float(T["modifiers"]["BODY"]["enemy_stamina_drain"]))
	clean_t = 0
	ep_b += 2
	P["pos"] += (P["pos"] - B["pos"]).normalized() * 0.12; _clamp(P)
	freeze_t = maxi(freeze_t, ms(float(T["hit_feel"]["hitstop_ms"]["normal"])))
	_ev("hit", {"on": "P", "dmg": dmg, "body": body})
	if P["comp"] <= 0.0: _drop(true)

# ============================ DROPS / EIGHT ================================
func _drop(player_down: bool, flash: bool = false) -> void:
	# NP_01 s3 scoring: DROP 1 / FLASH DROP 2 / SEGMENT KO 3 (three-knockdown rule or a failed count)
	if player_down:
		drops_b += 1; P["drops"] += 1; score_b += 1
		_ev("drop", {"who": "P"})
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
		tension = minf(100.0, tension + 10.0); contributed += 10.0
		B["comp"] = B["comp_max"] * float(T["composure"]["post_count_reset_pct"]) / 100.0
		B["no_regen_t"] = ms(float(T["composure"]["regen_halt_after_count_s"]) * 1000.0)
		_ev("drop", {"who": "B", "flash": flash})
		_say("%s %d-%d" % ["FLASH DROP! (2 pts)" if flash else "DROP SCORED!", score_p, score_b])
		if B["drops"] >= 3: _segment_ko(true, "three knockdowns")

func _segment_ko(player_scored: bool, why: String) -> void:
	# the KO is worth 3; the loser's remaining segment time is forfeit and the
	# winner shadowboxes it out for a Tension trickle (+1 per 10s, NP_01 s3)
	var trickle := float(clock_t / ms(10000))
	if player_scored:
		score_p += 3
		tension = minf(100.0, tension + trickle); contributed += trickle
		_ev("segment_ko", {"by": "P"})
		_end_segment("SEGMENT KO by %s (%s, +3)" % [pname(), why])
	else:
		score_b += 3
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
			tension = minf(100.0, tension + float(T["standing_eight"]["crowd_surge_tension"]))
			contributed += float(T["standing_eight"]["crowd_surge_tension"])
			_say("UP AT EIGHT! Crowd surge - composure regen halted 10s")
			return
		eight["timer_t"] = ms(1200)
		_say("beat! %d to go" % eight["beats_left"])

# ============================ DUAL FLOW ====================================
func _end_segment(why: String) -> void:
	P["pending"] = {}; bpending = {}; eight = {}
	charged = contributed >= 25.0
	if seg_idx >= 2:
		_end_dual(); return
	mode = "CORNER"
	_ev("seg_end", {"why": why})
	_say("SEGMENT R%d (%s): SCORE %d-%d  drops %d-%d  EP %d-%d  banked %.0f%s\n[1] send %s   [2] rest (+20 stamina)" %
		[seg_idx + 1, why, score_p, score_b, drops_p, drops_b, ep_p, ep_b, contributed,
		 "  >> RELAY CHARGED!" if charged else "", lineup[seg_idx + 1]["name"]])

func corner_pick(opt: int) -> void:
	if mode != "CORNER": return
	seg_idx += 1
	_load_segment()
	if opt == 2: P["stamina"] = minf(120.0, P["stamina"] + 20.0)

func _end_dual() -> void:
	mode = "OVER"
	var v := "DRAW"
	if score_p > score_b: v = "MILLBROOK WINS"
	elif score_b > score_p: v = "ASCENDANT WINS"
	elif ep_p != ep_b: v = ("MILLBROOK" if ep_p > ep_b else "ASCENDANT") + " WINS ON EP"
	_ev("dual_end", {"verdict": v})
	_say("DUAL OVER :: %s   SCORE %d-%d (drops %d-%d)   EP %d-%d" % [v, score_p, score_b, drops_p, drops_b, ep_p, ep_b])

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
	btimer = maxi(1, int(ms(float(pattern["strings"][sname]["tell"]["ms"])) * tell_scale))
	tell_start_tick = tick; tell_reacted = false
	_ev("tell", {"ticks": btimer, "loud": loud, "string": sname})

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
	# 2s mini-duel: the player taps A/ENTER on the cue (RFX-gated window); enough
	# beats wins position (opponent herded 50cm ropeward) or, holding BODY on the
	# resolve, a reset (center ring, both +5 stamina). Losing gets you dragged.
	var w := lerpf(float(ms(120)), float(ms(220)), float(P["stats"]["RFX"]) / 99.0)
	clinch = {"by": by, "t": ms(float(T["clinch"]["duel_s"]) * 1000.0), "beats": 0, "need": need,
		"window_t": int(w), "timer_t": ms(700), "rise_prev": false, "drag": drag}
	clinch_t = int(clinch["t"])
	P["busy_t"] = maxi(P["busy_t"], clinch_t); P["cmd"] = {}; P["pending"] = {}
	P["dodge"] = ""; P["dodge_t"] = 0; P["blocking"] = false
	bqueue = []; bpending = {}; bstate = "IDLE"; btimer = clinch_t + ms(300)
	_ev("clinch", {"by": by, "need": need})
	_say("CLINCH%s - tap on the cue (%d beats to win it)" % [" - he grabs you" if by == "B" else "", need])

func _clinch_step(rise: bool, want_reset: bool) -> void:
	clinch["t"] -= 1; clinch_t = int(clinch["t"])
	clinch["timer_t"] -= 1
	var edge: bool = rise and not clinch["rise_prev"]
	clinch["rise_prev"] = rise
	if edge and absi(int(clinch["timer_t"])) <= int(clinch["window_t"]):
		clinch["beats"] += 1; clinch["timer_t"] = ms(700)
		_ev("clinch_beat", {"beats": clinch["beats"]})
	elif int(clinch["timer_t"]) < -int(clinch["window_t"]):
		clinch["timer_t"] = ms(700)
	if int(clinch["t"]) <= 0: _resolve_clinch(want_reset)

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

# ============================ REFEREE (NP_01 s5) ===========================
func _boss_foul_on_break() -> void:
	# dirty archetypes flirt with warnings on purpose: META warnings_banked=N is
	# how many this boss will bank (never the next one). Ladder: warning ->
	# -5 EP -> DROP awarded to the opponent on the third.
	var cap := int(pattern.get("meta", {}).get("warnings_banked", 0))
	if bwarnings >= cap: return
	bwarnings += 1
	_ev("warning", {"who": "B", "n": bwarnings})
	match bwarnings:
		1: _say("REFEREE: warning, %s - behind the head on the break (1)" % pattern.get("id", "boss"))
		2: ep_b -= 5; _say("REFEREE: second warning - 5 EP deducted (2)")
		_:
			drops_p += 1; score_p += 1
			_ev("drop", {"who": "B", "flash": false, "awarded": true})
			_say("REFEREE: third warning - DROP awarded to %s" % pname())

func _player_holding_call() -> void:
	pwarnings += 1; ep_p -= 2
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
	if not bdesp_used and d.has("move") and B["comp"] <= B["comp_max"] * desp_pct / 100.0:
		bdesp_used = true
		bstate = "TELL"; bstring = ""; btimer = ms(1200); bforce_opts = {}
		bqueue = [{"kind": "punch", "row": "R_HOOKERCUT", "mult": 2.2, "body": false}]
		_ev("tell", {"ticks": btimer, "loud": true, "string": "DESPERATION"})
		_say("!! DESPERATION ARMING: %s - interrupt or survive it" % str(d["move"]))
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
			bstate = "TELL"; bforce_opts = {}; btimer = ms(float(s["tell"]["ms"]))
			tell_start_tick = tick; tell_reacted = false
			_ev("tell", {"ticks": btimer, "loud": s["class"] != "normal", "string": bstring})
		"FAKE":
			bstate = "RECOVER"; btimer = ms(300); bstring = ""
			_ev("recover", {})
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
	if mode == "CORNER":
		var c: int = inp.get("corner", 0)
		if c > 0: corner_pick(c)
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
	clock_t -= 1
	# ---- timers/regen ----
	for F in [P, B]:
		var acting: bool = F["busy_t"] > 0
		if F["busy_t"] > 0: F["busy_t"] -= 1
		F["stamina"] = minf(100.0, F["stamina"] + float(T["stamina"]["regen_active_per_s"] if acting else T["stamina"]["regen_neutral_per_s"]) * DT)
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
		_clinch_step(inp.get("rise", false), inp.get("body", false))
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
		var decay := float(T["guard"]["hold_decay_per_s"]) * (float(T["zones"]["CORNER"]["guard_decay_mult"]) if zone(P["pos"]) == "CORNER" else 1.0)
		P["guard"] = maxf(0.0, P["guard"] - decay * DT)
		if block_hold_t == ms(2000): _fire_event("player_block_hold")
		if block_hold_t == ms(float(sensors["guard_s"]) * 1000.0): _fire_event("player_static_guard"); _fire_event("player_high_guard")
	else:
		P["block_t"] = 0; block_hold_t = 0
		P["guard"] = minf(P["guard_max"], P["guard"] + float(T["guard"]["regen_per_s"]) * DT)
	var mv: Vector2 = inp.get("move", Vector2.ZERO) if not (dodging or clinch_t > 0) else Vector2.ZERO
	var spd := lerpf(2.2, 3.4, float(P["stats"]["SPD"]) / 99.0) * float(_gassed(P)["foot_speed"])
	var fwd: Vector2 = (B["pos"] - P["pos"]).normalized()
	var right := Vector2(fwd.y, -fwd.x)
	var before: Vector2 = P["pos"]
	var dist0: float = B["pos"].distance_to(P["pos"])
	P["pos"] += (right * mv.x - fwd * mv.y) * spd * DT * (0.7 if mv.y > 0 else 1.0)
	_clamp(P)
	# sprint-step (NP_03 s2.4): 0.8m burst, -4 stamina; toward him it is an approach, away it is a back-step
	if inp.get("sprint", false) and sprint_cd <= 0 and not dodging and clinch.is_empty():
		var sdir: Vector2 = (right * mv.x - fwd * mv.y).normalized() if mv.length() > 0.2 else fwd
		P["pos"] += sdir * float(T["movement"]["sprint_step_m"]); _clamp(P)
		P["stamina"] = maxf(0.0, P["stamina"] - float(T["movement"]["sprint_step_stamina"]))
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
	if dg != "" and not dodging and clinch_t <= 0:
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
	if dist > ENGAGE_DIST and bstate != "ACTING":
		var intercept: Vector2 = P["pos"] + p_vel * 0.35
		B["pos"] += (intercept - B["pos"]).normalized() * 1.2 * DT; _clamp(B)
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
		neutral_t, cadence, hands_down_t, react_ticks, bwarnings, pwarnings, rng.state]
	return v.hash()

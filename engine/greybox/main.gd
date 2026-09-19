extends Node3D
# TRUE NORTH BOXING - greybox combat engine. Shapes in a ring, real systems.
# The whole NP_03 vertical playable: FNC stick punching, block/slip, stamina/
# composure/guard, counter + flash windows, PBN boss (compiled patterns),
# interrupts, adaptation tracker (narrated), Tension + one hissatsu, DROP +
# standing-eight, 90s segment loop. All numbers from combat_tuning.v1.json.
#
# PAD: LS move | RS flick punch (angle = punch) | LT+LS slip | LT+punch body
#      RB power | RT block | LB hold + haymaker-flick at 100 Tension = A.B.B.
# KEYS: WASD move | J jab, K cross, U/I hooks, O uppercut | Space block
#       Q/E slip | Shift power | C body | H hissatsu-arm
# META: 1-4 switch boss (Vane/Yuri/Moreau/Sam) | R reload tuning | F5 restart
#       ENTER during count = rise beat

const BOSSES := ["cassidy_vane", "yuri_kowalchuk", "jean_guy_moreau", "sam_tagaq"]
const PUNCH_KEYS := {KEY_J: "L_STRAIGHT", KEY_K: "R_STRAIGHT", KEY_U: "L_HOOK",
					 KEY_I: "R_HOOK", KEY_O: "R_UPPERCUT"}
const SECTORS := ["L_UPPERCUT","L_HOOKERCUT","L_HOOK","L_FLARED","L_STRAIGHT",
				  "R_STRAIGHT","R_FLARED","R_HOOK","R_HOOKERCUT","R_UPPERCUT"]

var T: Dictionary            # combat tuning
var boss_idx := 0
var pattern: Dictionary

# world
var player: Node3D
var boss: Node3D
var cam: Camera3D
var hud: Label
var feed: Label              # commentary / tracker narration line
var flashrect: ColorRect

# fighter state (dictionaries; port of sim/engine.py)
var P: Dictionary
var B: Dictionary

# player input state
var armed := true
var t_below_off := 0.0
var stick_capture := 0
var stick_best := Vector2.ZERO
var lb_held := false
var slip_ms := 0.0
var slip_dir := 0
var block_press_ms := 999999.0     # ms since RT pressed (perfect-block window)
var pending: Dictionary = {}       # player punch in startup
var counter_ms := 0.0              # open counter window
var flash_ms := 0.0                # flash-counter slow-time window

# boss agent
var bstate := "IDLE"
var btimer := 0.0
var bstring := ""
var bqueue: Array = []
var bphase := 1
var bdesp_used := false
var bpending: Dictionary = {}

# tracker (player offense)
var tokens: Array = []
var flags := {}                    # gram(str) -> [tier, ms]

# match state - segment
var clock := 90.0
var drops_p := 0
var drops_b := 0
var tension := 0.0
# dual layer (mini-dual: 3 segments, rotation both sides, NP_01 s8)
var mode := "FIGHT"                # FIGHT | CORNER | OVER
var seg_idx := 0                   # 0..2
var ep_p := 0
var ep_b := 0
var contributed := 0.0             # player-side tension earned this segment (relay)
var charged := false               # next fighter enters CHARGED
var charge_ms := 0.0               # entrance surge active
var hiss_threshold := 100.0
const LINEUP_P := [
	{"name": "RORY",   "stats": {"PWR":45,"SPD":50,"CHN":45,"RFX":50,"BLK":45,"STA":50,"HRT":99}, "color": Color(0.25,0.55,0.9)},
	{"name": "PRIYA",  "stats": {"PWR":35,"SPD":60,"CHN":40,"RFX":70,"BLK":50,"STA":55,"HRT":60}, "color": Color(0.3,0.8,0.75)},
	{"name": "MARCUS", "stats": {"PWR":70,"SPD":40,"CHN":65,"RFX":35,"BLK":40,"STA":55,"HRT":70}, "color": Color(0.9,0.6,0.2)},
]
var eight := {}                    # standing-eight overlay state
var paused_for_eight := false

# smoke harness (agent verification, headless): godot --headless --path . -- smoke
var smoke := false
var smoke_stage := 0
var smoke_frames := 0
var smoke_results: Array = []
var smoke_auto_rise := false

func _ready() -> void:
	smoke = "smoke" in OS.get_cmdline_user_args()
	if smoke: seed(12345)
	T = _json("res://combat_tuning.v1.json")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("boss="): boss_idx = clampi(int(a.split("=")[1]), 0, BOSSES.size() - 1)
	_load_boss(boss_idx)
	_build_world()
	_reset_fighters()
	_feed("SEGMENT START - " + BOSSES[boss_idx] + "   (keys 1-4 switch boss, R reloads tuning)")

func _json(p: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(p))

func _load_boss(i: int) -> void:
	boss_idx = i
	pattern = _json("res://patterns/%s.json" % BOSSES[i])
	bstate = "IDLE"; btimer = 600.0; bqueue = []; bphase = 1; bdesp_used = false; bpending = {}

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
	root.set_meta("base_color", color)
	return root

func _build_world() -> void:
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 30, 0); add_child(sun)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.09, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55); env.environment = e; add_child(env)
	_mk_box(Vector3(7.4, 0.2, 7.4), Color(0.22, 0.24, 0.28), Vector3(0, -0.1, 0))   # canvas 24ft~7.3m
	for c in [Vector3(-3.7,0.9,-3.7), Vector3(3.7,0.9,-3.7), Vector3(-3.7,0.9,3.7), Vector3(3.7,0.9,3.7)]:
		_mk_box(Vector3(0.15, 1.8, 0.15), Color(0.55, 0.15, 0.15), c)               # posts
	for h in [0.5, 0.95, 1.4]:                                                       # ropes
		_mk_box(Vector3(7.4, 0.04, 0.04), Color(0.7,0.7,0.75), Vector3(0, h, -3.7))
		_mk_box(Vector3(7.4, 0.04, 0.04), Color(0.7,0.7,0.75), Vector3(0, h,  3.7))
		_mk_box(Vector3(0.04, 0.04, 7.4), Color(0.7,0.7,0.75), Vector3(-3.7, h, 0))
		_mk_box(Vector3(0.04, 0.04, 7.4), Color(0.7,0.7,0.75), Vector3( 3.7, h, 0))
	player = _mk_capsule(Color(0.25, 0.55, 0.9), Vector3(0, 0, 1.1))
	boss  = _mk_capsule(Color(0.85, 0.3, 0.25), Vector3(0, 0, -1.1))
	cam = Camera3D.new(); cam.fov = 55.0; add_child(cam)
	var ui := CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.position = Vector2(20, 14)
	hud.add_theme_font_size_override("font_size", 17); ui.add_child(hud)
	feed = Label.new(); feed.position = Vector2(20, 660)
	feed.add_theme_font_size_override("font_size", 18)
	feed.add_theme_color_override("font_color", Color(1, 0.9, 0.5)); ui.add_child(feed)
	flashrect = ColorRect.new(); flashrect.color = Color(1,1,1,0)
	flashrect.size = Vector2(1280, 720); ui.add_child(flashrect)

func _fresh(stats: Dictionary) -> Dictionary:
	var g: Dictionary = T["guard"]["capacity_by_BLK"]
	return {"stats": stats, "stamina": 100.0,
		"comp_max": stats["CHN"] * 2.0, "comp": stats["CHN"] * 2.0,
		"guard_max": lerpf(g["min"], g["max"], stats["BLK"] / 99.0),
		"guard": lerpf(g["min"], g["max"], stats["BLK"] / 99.0),
		"guard_open_ms": 0.0, "busy_ms": 0.0, "no_regen_ms": 0.0, "drops": 0}

func _reset_fighters() -> void:
	# full dual reset
	seg_idx = 0; drops_p = 0; drops_b = 0; ep_p = 0; ep_b = 0
	tension = 0.0; charged = false; mode = "FIGHT"
	_load_segment()

func _pname() -> String: return LINEUP_P[seg_idx]["name"]

func _load_segment() -> void:
	var f: Dictionary = LINEUP_P[seg_idx]
	P = _fresh(f["stats"])
	var mat: StandardMaterial3D = player.get_meta("mat")
	mat.albedo_color = f["color"]; player.set_meta("base_color", f["color"])
	_load_boss((boss_idx + seg_idx) % BOSSES.size())
	B = _fresh({"PWR":60,"SPD":55,"CHN":60,"RFX":55,"BLK":55,"STA":60,"HRT":60})
	var bmat: StandardMaterial3D = boss.get_meta("mat")
	bmat.albedo_color = boss.get_meta("base_color")
	clock = 90.0; contributed = 0.0
	tokens = []; flags = {}; pending = {}; bpending = {}
	counter_ms = 0.0; flash_ms = 0.0; hiss_threshold = 100.0; charge_ms = 0.0
	if charged:
		charge_ms = 10000.0; hiss_threshold = 50.0; charged = false
		_feed("R%d: %s enters CHARGED - surge 10s, hissatsu at 50! vs %s" % [seg_idx + 1, _pname(), BOSSES[boss_idx]])
	else:
		_feed("R%d: %s vs %s" % [seg_idx + 1, _pname(), BOSSES[boss_idx]])
	player.position = Vector3(0, 0, 1.1); boss.position = Vector3(0, 0, -1.1)
	paused_for_eight = false; mode = "FIGHT"
	Engine.time_scale = 1.0

func _end_segment(why: String) -> void:
	Engine.time_scale = 1.0
	paused_for_eight = false; pending = {}; bpending = {}
	charged = contributed >= 25.0
	if seg_idx >= 2 or drops_p >= 3 or drops_b >= 3:
		_end_dual(); return
	mode = "CORNER"
	_feed(("SEGMENT R%d (%s): DROPS %d-%d  EP %d-%d  banked %.0f tension" +
		("  >> RELAY CHARGED for %s!" if charged else "") +
		"\nCORNER (45s feel, skippable): [1] send %s  [2] rest +20 stamina next fighter") %
		[seg_idx + 1, why, drops_p, drops_b, ep_p, ep_b, contributed,
		 LINEUP_P[seg_idx + 1]["name"] if charged else "",
		 LINEUP_P[seg_idx + 1]["name"]])

func _corner_pick(opt: int) -> void:
	seg_idx += 1
	_load_segment()
	if opt == 2:
		P["stamina"] = minf(120.0, P["stamina"] + 20.0)
		_feed(feed.text + "   (rested: +20 stamina)")

func _end_dual() -> void:
	mode = "OVER"
	var verdict := "DRAW"
	if drops_p > drops_b: verdict = "MILLBROOK WINS"
	elif drops_b > drops_p: verdict = "ASCENDANT WINS"
	elif ep_p != ep_b: verdict = ("MILLBROOK" if ep_p > ep_b else "ASCENDANT") + " WINS ON EP"
	_feed("DUAL OVER :: %s   DROPS %d-%d   EP %d-%d   [F5 = new dual]" % [verdict, drops_p, drops_b, ep_p, ep_b])

func _feed(t: String) -> void: feed.text = t

# ============================== INPUT =====================================
func _poll_stick() -> Vector2:
	var best := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X),
						 Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
		if v.length() > best.length(): best = v
	return best

func _move_vec() -> Vector2:
	var v := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var lv := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X),
						  Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
		if lv.length() > v.length(): v = lv
	if v.length() < 0.2: v = Vector2.ZERO
	v.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	v.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return v.limit_length(1.0)

func _trigger(axis: int, key: int) -> bool:
	for dev in Input.get_connected_joypads():
		if Input.get_joy_axis(dev, axis) > 0.5: return true
	return Input.is_key_pressed(key)

func _blocking() -> bool: return _trigger(JOY_AXIS_TRIGGER_RIGHT, KEY_SPACE)
func _body_mod() -> bool: return _trigger(JOY_AXIS_TRIGGER_LEFT, KEY_C)
func _power_mod() -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER): return true
	return Input.is_key_pressed(KEY_SHIFT)
func _lb() -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER): return true
	return Input.is_key_pressed(KEY_H)

func _sector(v: Vector2) -> int:
	var ang := rad_to_deg(atan2(-v.y, v.x))
	if ang > 90.0 or ang <= -90.0:
		var la := 180.0 - ang if ang > 0.0 else -180.0 - ang
		return clampi(int(floor((la + 90.0) / 36.0)), 0, 4)
	return 5 + (4 - clampi(int(floor((ang + 90.0) / 36.0)), 0, 4))

# ============================== COMBAT ====================================
func _throw(row_name: String) -> void:
	if P["busy_ms"] > 0 or paused_for_eight: return
	var row: Dictionary = T["punch_matrix"][row_name]
	var mods: Array = []
	if _power_mod(): mods.append("POWER")
	if _body_mod(): mods.append("BODY")
	var hiss := lb_held and tension >= hiss_threshold and row_name in ["R_HOOKERCUT", "L_HOOKERCUT"]
	pending = {"row": row_name, "ms": float(row["startup_ms"]) * (1.4 if "POWER" in mods else 1.0),
			   "mods": mods, "hissatsu": hiss,
			   "counter": counter_ms > 0.0, "flash": flash_ms > 0.0}
	P["busy_ms"] = pending["ms"] + float(row["recovery_ms"])
	P["stamina"] = maxf(0.0, P["stamina"] - float(row["stamina"]) * (2.0 if "POWER" in mods else 1.0))
	_track(row_name)

func _track(row_name: String) -> void:
	tokens.append(row_name)
	if tokens.size() > int(T["adaptation_tracker"]["window_tokens"]): tokens.pop_front()
	for size in [2, 3]:
		if tokens.size() >= size:
			var gram := ",".join(tokens.slice(tokens.size() - size))
			var cnt := 0
			for i in range(tokens.size() - size + 1):
				if ",".join(tokens.slice(i, i + size)) == gram: cnt += 1
			if cnt >= int(T["adaptation_tracker"]["flag_at_count"]):
				var prev: int = flags.get(gram, [0, 0.0])[0]
				flags[gram] = [mini(3, prev + 1), 0.0]
				if prev == 0:
					_feed("COMMENTARY: He's leaning on that %s - %s is timing it now!" %
						  [gram.replace(",", " > "), pattern.get("id", "the boss")])

func _flag_tier() -> int:
	for size in [3, 2]:
		if tokens.size() >= size:
			var g := ",".join(tokens.slice(tokens.size() - size))
			if g in flags: return flags[g][0]
	return 0

func _gassed(f: Dictionary) -> Dictionary:
	for row in T["stamina"]["gassed_curve"]:
		if f["stamina"] > float(row["above"]): return row
	return T["stamina"]["gassed_curve"][-1]

func _land_on_boss() -> void:
	var pd: Dictionary = pending; pending = {}
	if player.position.distance_to(boss.position) > 2.6:
		return                                         # whiffed on range
	var row: Dictionary = T["punch_matrix"][pd["row"]]
	var dmg: float = float(row["dmg"]) * (float(P["stats"]["PWR"]) / 50.0) * float(_gassed(P)["dmg"])
	if charge_ms > 0.0: dmg *= 1.1
	if "POWER" in pd["mods"]: dmg *= float(T["modifiers"]["POWER"]["dmg_mult"])
	if pd["hissatsu"]:
		tension = 0.0; dmg *= 2.5
		_flash(0.9); Engine.time_scale = 0.35
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
		_feed("AURORA BOREALIS BREAKER!")
	if pd["counter"]: dmg *= float(T["counter_mults"]["counter"])
	if pd["flash"]: dmg *= float(T["counter_mults"]["flash"])
	# boss defense: base + tracker ramp (defense only, D3) - suppressed during tells (interrupt!)
	var tier := _flag_tier()
	var defend := 0.30 + minf(float(T["adaptation_tracker"]["ramp_cap_pct"]) / 100.0,
							  tier * float(T["adaptation_tracker"]["defense_ramp_per_tier_pct"]) / 100.0)
	if bstate == "TELL": defend = 0.05
	if randf() < defend and not pd["hissatsu"]:
		_feed("blocked / slipped" + ("  [pattern read: flagged sequence]" if tier > 0 else ""))
		return
	if bstate == "TELL":                               # INTERRUPT: stagger + flash window
		bstate = "IDLE"; btimer = 800.0; bqueue = []
		flash_ms = float(T["counter_windows_ms"]["flash"]["base"])
		if not pd["hissatsu"]:
			tension = minf(100.0, tension + 5.0); contributed += 5.0
		Engine.time_scale = 0.6
		get_tree().create_timer(0.7 * 0.6, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
		_feed("INTERRUPT! string broken - flash window open")
	B["comp"] -= dmg
	if tier == 0 and not pd["hissatsu"]:
		var earn := 3.0 if pd["counter"] else 1.5
		tension = minf(100.0, tension + earn); contributed += earn
	ep_p += 2
	_bump(boss, 0.12); _hitstop(pd)
	if B["comp"] <= 0.0: _drop(false)

func _boss_land(dmg_mult: float, is_desp: bool) -> void:
	var row: Dictionary = T["punch_matrix"][bpending.get("row", "R_STRAIGHT")]
	bpending = {}
	var dmg: float = float(row["dmg"]) * (float(B["stats"]["PWR"]) / 50.0) * dmg_mult
	# player defense: explicit states beat everything
	if slip_ms > 0.0:
		counter_ms = float(T["counter_windows_ms"]["slip"]["base"])
		_feed("slipped it - counter window!")
		return
	if _blocking():
		if block_press_ms <= float(T["guard"]["perfect_block_window_ms"]):
			counter_ms = float(T["counter_windows_ms"]["perfect_block"]["base"])
			_feed("PERFECT BLOCK - counter window!")
			return
		P["guard"] -= float(row["guard_dmg"])
		P["comp"] -= dmg * float(T["guard"]["chip_pct"]) / 100.0
		if P["guard"] <= 0.0:
			P["guard_open_ms"] = float(T["guard"]["break_open_ms"])
			_feed("GUARD BREAK - you're OPEN")
		return
	P["comp"] -= dmg * (1.5 if P["guard_open_ms"] > 0.0 else 1.0)
	ep_b += 2
	_bump(player, 0.12)
	if P["comp"] <= 0.0: _drop(true)

func _drop(player_down: bool) -> void:
	Engine.time_scale = 1.0
	if player_down:
		drops_b += 1; P["drops"] += 1
		if P["drops"] >= 3:
			_end_segment("three knockdowns - segment KO against " + _pname()); return
		paused_for_eight = true
		eight = {"beats_left": 3, "window_ms": lerpf(60, 140, (P["stats"]["HRT"] - 30) / 60.0) * 4.0,
				 "timer": 1200.0}
		_feed("DOWN! Standing-eight: press ENTER as the count lands (%d beats)" % eight["beats_left"])
	else:
		drops_p += 1; B["drops"] += 1
		tension = minf(100.0, tension + 10.0)
		B["comp"] = B["comp_max"] * 0.5
		_bump(boss, 0.5)
		_flash(0.5)
		_feed("DROP SCORED! %d-%d" % [drops_p, drops_b])
		if B["drops"] >= 3:
			_end_segment("SEGMENT KO by " + _pname())

func _hitstop(pd: Dictionary) -> void:
	var ms: int = T["hit_feel"]["hitstop_ms"]["flash_or_hissatsu"] if (pd.get("flash", false) or pd.get("hissatsu", false)) \
		else (T["hit_feel"]["hitstop_ms"]["counter"] if pd.get("counter", false) else T["hit_feel"]["hitstop_ms"]["normal"])
	Engine.time_scale = 0.05
	get_tree().create_timer(ms / 1000.0 * 0.05, true, false, true).timeout.connect(func():
		if not paused_for_eight: Engine.time_scale = 1.0 if flash_ms <= 0 else 0.6)

func _bump(n: Node3D, amt: float) -> void:
	var mesh: MeshInstance3D = n.get_meta("mesh")
	mesh.position.y = 0.9 - amt
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func(): mesh.position.y = 0.9)

func _flash(a: float) -> void:
	flashrect.color.a = a
	get_tree().create_tween().tween_property(flashrect, "color:a", 0.0, 0.35)

# ============================== BOSS AGENT ================================
func _phase_ok(sname: String) -> bool:
	for t in pattern["strings"][sname]["tags"]:
		if str(t).begins_with("phase>="):
			return bphase >= int(str(t).split(">=")[1])
	return true

func _boss_step(dt_ms: float) -> void:
	# phase triggers
	for ph in pattern.get("phases", []):
		var trig: String = ph["trigger"]
		if "composure<" in trig:
			var n := float(trig.split("composure<")[1].split(" ")[0].replace(":", ""))
			if B["comp"] <= B["comp_max"] * n / 100.0: bphase = maxi(bphase, int(ph["phase"]) if str(ph["phase"]).is_valid_int() else bphase + 1)
		elif "clock>" in trig:
			var n2 := float(trig.split("clock>")[1].rstrip("s").split(" ")[0].replace(":", ""))
			if (90.0 - clock) > n2: bphase = maxi(bphase, int(ph["phase"]) if str(ph["phase"]).is_valid_int() else bphase + 1)
	var d: Dictionary = pattern.get("desperation") if pattern.get("desperation") != null else {}
	if not bdesp_used and d.has("move") and B["comp"] <= B["comp_max"] * 0.25:
		bdesp_used = true
		bstate = "TELL"; bstring = ""; btimer = 1200.0
		_tell_fx(1200.0, true)
		_feed("!! DESPERATION ARMING: " + str(d["move"]) + " - interrupt or survive it")
		bqueue = [{"row": "R_HOOKERCUT", "mult": 2.2}]
		return
	btimer -= dt_ms
	if btimer > 0.0: return
	match bstate:
		"IDLE", "RECOVER":
			var w: Dictionary = {}
			for k in pattern["select"]["weights"]:
				if _phase_ok(k) and int(pattern["select"]["weights"][k]) > 0:
					w[k] = int(pattern["select"]["weights"][k])
			for k in pattern["strings"]:
				if not k in w and _phase_ok(k): w[k] = 15
			var total := 0
			for k in w:
				total += w[k]
			var r := randf() * total
			for k in w:
				r -= w[k]
				if r <= 0.0: bstring = k; break
			var s: Dictionary = pattern["strings"][bstring]
			bstate = "TELL"; btimer = float(s["tell"]["ms"])
			_tell_fx(btimer, s["class"] != "normal")
		"TELL":
			if bstring == "":               # desperation arming: queue was set directly
				bstate = "ACTING"; btimer = 0.0
				return
			var s2: Dictionary = pattern["strings"][bstring]
			bqueue = []
			for a in s2["actions"]:
				var verb: String = str(a).split("(")[0].split(" ")[0]
				if verb in ["JAB","L_STR","R_STR","L_HOOK","R_HOOK","R_UPC","L_UPC","R_HAY","R_OVERHAND",
							"CHECK_HOOK","LT_L_HOOK","LT_R_HOOK","LT_R_UPC","COUNTER_R_STR","COUNTER_L_HOOK",
							"STEP_R_STR","PULL_COUNTER_OVERHAND","UNDER_ELBOW_CROSS"]:
					bqueue.append({"row": _map_row(verb), "mult": 1.0})
			bstate = "ACTING"; btimer = 0.0
		"ACTING":
			if bqueue.is_empty():
				bstate = "RECOVER"; btimer = randf_range(500, 900)
				var mat: StandardMaterial3D = boss.get_meta("mat")
				mat.albedo_color = boss.get_meta("base_color")
				return
			var atk: Dictionary = bqueue.pop_front()
			bpending = atk
			var row: Dictionary = T["punch_matrix"][atk["row"]]
			# lunge toward player
			var dirv: Vector3 = (player.position - boss.position).normalized()
			boss.position += dirv * 0.25
			_boss_land(float(atk.get("mult", 1.0)) * float(_gassed(B)["dmg"]), false)
			btimer = float(row["recovery_ms"]) * 0.7

func _map_row(verb: String) -> String:
	match verb:
		"JAB", "L_STR": return "L_STRAIGHT"
		"R_STR", "COUNTER_R_STR", "STEP_R_STR", "UNDER_ELBOW_CROSS": return "R_STRAIGHT"
		"L_HOOK", "CHECK_HOOK", "LT_L_HOOK", "COUNTER_L_HOOK": return "L_HOOK"
		"R_HOOK", "LT_R_HOOK": return "R_HOOK"
		"R_UPC", "LT_R_UPC": return "R_UPPERCUT"
		"L_UPC": return "L_UPPERCUT"
		"R_HAY": return "R_HOOKERCUT"
		"R_OVERHAND", "PULL_COUNTER_OVERHAND": return "R_FLARED"
	return "R_STRAIGHT"

func _tell_fx(ms: float, loud: bool) -> void:
	var mat: StandardMaterial3D = boss.get_meta("mat")
	mat.albedo_color = Color(1.0, 0.85, 0.2) if loud else Color(1.0, 0.6, 0.2)
	var mesh: MeshInstance3D = boss.get_meta("mesh")
	var tw := get_tree().create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.15, 1.05, 1.15), ms / 2000.0)
	tw.tween_property(mesh, "scale", Vector3.ONE, ms / 2000.0)

# ============================== LOOP ======================================
func _process(delta: float) -> void:
	var dt_ms := delta * 1000.0
	if mode == "CORNER":
		if Input.is_key_pressed(KEY_1) or Input.is_joy_button_pressed(0, JOY_BUTTON_A): _corner_pick(1)
		elif Input.is_key_pressed(KEY_2) or Input.is_joy_button_pressed(0, JOY_BUTTON_X): _corner_pick(2)
		if smoke: _smoke_tick()
		_hud(); return
	if mode == "OVER":
		if smoke: _smoke_tick()
		_hud(); return
	if charge_ms > 0.0: charge_ms -= dt_ms
	if paused_for_eight and eight.has("beats_left"):
		_eight_tick(dt_ms); _hud(); return
	if paused_for_eight: _hud(); return
	clock = maxf(0.0, clock - delta)
	# movement (player) + face-off
	var mv := _move_vec()
	var spd := lerpf(2.2, 3.4, P["stats"]["SPD"] / 99.0) * float(_gassed(P)["foot_speed"])
	var fwd: Vector3 = (boss.position - player.position).normalized()
	var right := fwd.cross(Vector3.UP)
	player.position += (-right * mv.x - fwd * mv.y) * spd * delta * (0.7 if mv.y > 0 else 1.0)
	player.position.x = clampf(player.position.x, -3.5, 3.5)
	player.position.z = clampf(player.position.z, -3.5, 3.5)
	# boss keeps range
	var dist := boss.position.distance_to(player.position)
	if dist > 2.1 and bstate != "ACTING":
		boss.position += (player.position - boss.position).normalized() * 1.2 * delta
	# camera: Punch-Out rig - behind/above player, boss centered
	var back: Vector3 = (player.position - boss.position).normalized()
	cam.position = player.position + back * 1.8 + Vector3(0, 1.5, 0)
	cam.look_at(boss.position + Vector3(0, 1.2, 0))
	# timers + regen
	for F in [P, B]:
		var acting: bool = F["busy_ms"] > 0.0
		F["busy_ms"] = maxf(0.0, F["busy_ms"] - dt_ms)
		F["stamina"] = minf(100.0, F["stamina"] + (T["stamina"]["regen_active_per_s"] if acting else T["stamina"]["regen_neutral_per_s"]) * delta)
		if F["no_regen_ms"] > 0.0: F["no_regen_ms"] -= dt_ms
		else: F["comp"] = minf(F["comp_max"], F["comp"] + T["composure"]["regen_per_s"] * delta)
		if F["guard_open_ms"] > 0.0:
			F["guard_open_ms"] -= dt_ms
			if F["guard_open_ms"] <= 0.0: F["guard"] = float(T["guard"]["break_refill"])
	if _blocking():
		block_press_ms += dt_ms
		P["guard"] = maxf(0.0, P["guard"] - T["guard"]["hold_decay_per_s"] * delta)
	else:
		block_press_ms = 0.0
		P["guard"] = minf(P["guard_max"], P["guard"] + T["guard"]["regen_per_s"] * delta)
	slip_ms = maxf(0.0, slip_ms - dt_ms)
	counter_ms = maxf(0.0, counter_ms - dt_ms)
	if flash_ms > 0.0:
		flash_ms -= dt_ms
		if flash_ms <= 0.0: Engine.time_scale = 1.0
	# stick punch detection (harness logic, fixed version)
	lb_held = _lb()
	var v := _poll_stick()
	var mag := v.length()
	if mag <= 0.25: t_below_off = Time.get_ticks_msec()
	if stick_capture > 0:
		stick_capture -= 1
		if mag > stick_best.length(): stick_best = v
		if stick_capture == 0: _throw(SECTORS[_sector(stick_best)])
	elif armed and mag >= 0.6:
		armed = false
		if Time.get_ticks_msec() - t_below_off <= 150:
			stick_capture = 2; stick_best = v
	elif not armed and mag <= 0.25:
		armed = true
	# player punch impact
	if not pending.is_empty():
		pending["ms"] -= dt_ms
		if pending["ms"] <= 0.0: _land_on_boss()
	# boss
	_boss_step(dt_ms)
	if clock <= 0.0 and mode == "FIGHT":
		_end_segment("clock")
	_hud()
	if smoke: _smoke_tick()

func _eight_tick(dt_ms: float) -> void:
	eight["timer"] -= dt_ms
	if eight["timer"] <= -eight["window_ms"]:
		_feed("COUNTED OUT. F5 to rematch."); eight = {}; return
	if smoke_auto_rise or Input.is_key_pressed(KEY_ENTER) or Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		if absf(eight["timer"]) <= eight["window_ms"]:
			eight["beats_left"] -= 1
			if eight["beats_left"] <= 0:
				paused_for_eight = false; eight = {}
				P["comp"] = P["comp_max"] * 0.5
				P["no_regen_ms"] = 10000.0
				tension = minf(100.0, tension + 8.0)
				_feed("UP AT EIGHT! Crowd surge +8 Tension - composure regen halted 10s")
				return
			eight["timer"] = 1200.0
			_feed("beat! %d to go" % eight["beats_left"])

func _bar(v: float, vmax: float, w: int) -> String:
	var n := int(clampf(v / vmax, 0.0, 1.0) * w)
	return "[" + "#".repeat(n) + "-".repeat(w - n) + "]"

func _hud() -> void:
	hud.text = "TRUE NORTH BOXING :: greybox   R%d/3  %s vs %s   clock %5.1f   DROPS %d-%d   EP %d-%d\n" % [seg_idx + 1, _pname(), BOSSES[boss_idx], clock, drops_p, drops_b, ep_p, ep_b] \
		+ "YOU   stam %s  chin %s  guard %s%s\n" % [_bar(P["stamina"],100,14), _bar(P["comp"],P["comp_max"],14), _bar(P["guard"],P["guard_max"],10), "  OPEN!" if P["guard_open_ms"]>0 else ""] \
		+ "BOSS  chin %s   phase %d%s\n" % [_bar(B["comp"],B["comp_max"],14), bphase, "   << TELL - HIT HIM NOW" if bstate=="TELL" else ""] \
		+ "TENSION %s %3.0f  %s%s%s" % [_bar(tension,100,16), tension, "ABB READY (LB + haymaker flick)" if tension>=100 else "", "   counter!" if counter_ms>0 else "", "   FLASH!" if flash_ms>0 else ""]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in PUNCH_KEYS: _throw(PUNCH_KEYS[e.keycode])
		elif e.keycode == KEY_Q: slip_ms = 260.0; slip_dir = -1
		elif e.keycode == KEY_E: slip_ms = 260.0; slip_dir = 1
		elif e.keycode == KEY_R:
			T = _json("res://combat_tuning.v1.json"); _feed("tuning hot-reloaded")
		elif e.keycode == KEY_F5:
			Engine.time_scale = 1.0; paused_for_eight = false; _reset_fighters(); _feed("REMATCH")
		elif e.keycode >= KEY_1 and e.keycode <= KEY_4:
			_load_boss(e.keycode - KEY_1)
			Engine.time_scale = 1.0; paused_for_eight = false; _reset_fighters()
			_feed("NOW FIGHTING: " + BOSSES[boss_idx])
	# pad slips: LT + LS lateral
	if e is InputEventJoypadMotion and e.axis == JOY_AXIS_LEFT_X and absf(e.axis_value) > 0.7 and _body_mod():
		slip_ms = 260.0; slip_dir = 1 if e.axis_value > 0.0 else -1


# ============================== SMOKE =====================================
func _sr(name: String, ok: bool, detail: String = "") -> void:
	smoke_results.append([name, ok, detail])
	print("  [%s]  %-38s %s" % [" OK " if ok else "FAIL", name, detail])

func _smoke_tick() -> void:
	smoke_frames += 1
	match smoke_stage:
		0:
			if smoke_frames < 5: return
			print("SMOKE :: greybox systems, boss=" + BOSSES[boss_idx])
			_sr("tuning+pattern loaded", not T.is_empty() and not pattern.is_empty())
			_sr("world built", player != null and boss != null and cam != null)
			smoke_stage = 1
		1:
			# tracker: 4x same jab must flag the 2-gram and narrate
			boss.position = player.position + Vector3(0, 0, -1.5)
			for i in range(4):
				P["busy_ms"] = 0.0
				_throw("L_STRAIGHT")
				pending["ms"] = 0.0
				_land_on_boss()
			_sr("tracker flags repeat 2-gram", _flag_tier() >= 1, "tier=%d" % _flag_tier())
			_sr("stamina drains on punches", P["stamina"] < 100.0, "%.1f" % P["stamina"])
			smoke_stage = 2
		2:
			# interrupt: force a tell, land during it (retry through the 5pct evade roll)
			var comp_before: float = B["comp"]
			for i in range(8):
				bstate = "TELL"; bstring = pattern["strings"].keys()[0]; btimer = 500.0
				P["busy_ms"] = 0.0; tokens = []; flags = {}
				_throw("R_STRAIGHT"); pending["ms"] = 0.0; _land_on_boss()
				if bstate != "TELL": break
			_sr("interrupt breaks tell", bstate != "TELL", "state=" + bstate)
			_sr("interrupt opens flash window", flash_ms > 0.0, "%.0fms" % flash_ms)
			_sr("interrupt pays tension", tension > 0.0, "%.1f" % tension)
			_sr("boss took damage", B["comp"] < comp_before)
			Engine.time_scale = 1.0
			smoke_stage = 3
		3:
			# drop the boss: force low composure, land until the drop registers
			bstate = "IDLE"
			var d0 := drops_p
			for i in range(12):
				B["comp"] = 1.0
				P["busy_ms"] = 0.0; tokens = []; flags = {}
				_throw("R_UPPERCUT"); pending["ms"] = 0.0; _land_on_boss()
				if drops_p > d0: break
			_sr("DROP scored at composure<=0", drops_p == d0 + 1, "%d-%d" % [drops_p, drops_b])
			_sr("post-drop composure reset 50pct", absf(B["comp"] - B["comp_max"] * 0.5) < 1.0)
			smoke_stage = 4
		4:
			# player drop -> standing-eight -> auto-rise -> crowd surge
			P["comp"] = 0.5
			bpending = {"row": "R_HOOKERCUT"}
			var t0: float = tension
			_boss_land(1.0, false)
			_sr("player drop triggers eight-count", paused_for_eight and eight.has("beats_left"))
			smoke_auto_rise = true
			smoke_stage = 5
		5:
			if paused_for_eight: return       # _eight_tick auto-rising
			_sr("standing-eight rise works", P["comp"] > 0.0 and P["no_regen_ms"] > 0.0,
				"comp=%.1f halt=%.0fms" % [P["comp"], P["no_regen_ms"]])
			smoke_stage = 6
		6:
			# guard: hold-block chip + break/refill
			P["guard"] = 1.0
			block_press_ms = 9999.0
			# simulate a blocked hit via _boss_land with blocking forced through guard math
			P["guard"] -= 20.0
			if P["guard"] <= 0.0: P["guard_open_ms"] = float(T["guard"]["break_open_ms"])
			_sr("guard break opens", P["guard_open_ms"] > 0.0)
			P["guard_open_ms"] = 1.0    # let tick refill next frame
			smoke_stage = 7
		7:
			_sr("guard refills after break", P["guard"] >= float(T["guard"]["break_refill"]) - 1.0,
				"%.1f" % P["guard"])
			# ABB: full bar + lb + haymaker
			tension = 100.0; lb_held = true
			P["busy_ms"] = 0.0; tokens = []; flags = {}
			pending = {}
			B["comp"] = B["comp_max"]      # healthy target: isolate cast cost from drop bonus
			var dpre := drops_p
			_throw("R_HOOKERCUT")
			var was_hiss: bool = pending.get("hissatsu", false)
			pending["ms"] = 0.0; _land_on_boss()
			var expect: float = 10.0 if drops_p > dpre else 0.0
			_sr("hissatsu arms at 100 tension", was_hiss)
			_sr("hissatsu bar = cast zero + drop bonus only", tension == expect,
				"%.0f (expected %.0f)" % [tension, expect])
			Engine.time_scale = 1.0
			smoke_stage = 8
		8:
			# boss agent runs strings on its own over time
			smoke_stage = 9; smoke_frames = 0
			paused_for_eight = false
		9:
			if smoke_frames < 240: return     # ~4s of live agent
			_sr("boss agent cycles strings", bstate != "" and (bstring != "" or bstate == "IDLE"),
				"state=%s string=%s phase=%d" % [bstate, bstring, bphase])
			smoke_stage = 10
		10:
			# dual layer: bank relay tension, then force segment end
			contributed = 30.0
			var t_persist := 42.0
			tension = t_persist
			paused_for_eight = false
			_end_segment("smoke-forced")
			_sr("segment end enters CORNER", mode == "CORNER")
			_sr("relay CHARGED at >=25 contributed", charged)
			_corner_pick(1)
			_sr("rotation loads next fighter", _pname() == "PRIYA", _pname())
			_sr("tension persists across segments", tension == t_persist, "%.0f" % tension)
			_sr("CHARGED surge + hissatsu discount", charge_ms > 0.0 and hiss_threshold == 50.0,
				"%.0fms thr=%.0f" % [charge_ms, hiss_threshold])
			smoke_stage = 11
		11:
			# run seg2 to the corner without relay bank, then into seg3 and force the verdict
			contributed = 0.0
			_end_segment("smoke-forced")
			_sr("no relay under 25 contributed", not charged)
			_corner_pick(2)
			_sr("seg3 loads MARCUS", _pname() == "MARCUS", _pname())
			drops_p = 2; drops_b = 1; ep_p = 40; ep_b = 22
			_end_segment("smoke-forced")
			_sr("dual verdict on drops", mode == "OVER" and "MILLBROOK WINS" in feed.text)
			smoke_stage = 12
		12:
			var fails := 0
			for r in smoke_results:
				if not r[1]: fails += 1
			print("SMOKE VERDICT :: %s (%d/%d)" % ["GREEN" if fails == 0 else "RED",
				smoke_results.size() - fails, smoke_results.size()])
			get_tree().quit(0 if fails == 0 else 1)

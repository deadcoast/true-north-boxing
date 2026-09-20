extends Node3D
const TNBSim := preload("res://sim/core.gd")
const TNBClock := preload("res://sim/clock.gd")
const TNBTests := preload("res://sim/tests.gd")
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
# KEYS: WASD move | J jab, K cross, U/I hooks, O uppercut (tap-release within 80ms = FEINT) | Space block
#       Q/E slip | V weave | B lean | T taunt | Shift power | C body | H hissatsu-arm
#       Ctrl sprint-step | G clinch | ENTER beat tap | F8 audio-assist cue toggle
# CORNER (45s, 2 actions): 1 send | 2/3/4 equipped tactics | 5 super | 6/7/8 staff | 9 save the bar | 0 swap (first option)
#       pad: A send | X swap | Y super | B save the bar | DPAD L/R tactics 1/2 | DPAD DOWN staff 1
# META: F1-F4 switch boss (Vane/Yuri/Moreau/Sam) | F6/F7 prev/next of all 24 | R reload tuning | F5 new dual
# TESTS (headless): godot --headless --path . -- smoke boss=N | determinism | geometry
# DEMO: godot --path . -- demo   (self-playing scripted fighter; the presentation soak)

const PUNCH_KEYS := {KEY_J: "L_STRAIGHT", KEY_K: "R_STRAIGHT", KEY_U: "L_HOOK",
					 KEY_I: "R_HOOK", KEY_O: "R_UPPERCUT"}
const SECTORS := ["L_UPPERCUT","L_HOOKERCUT","L_HOOK","L_FLARED","L_STRAIGHT",
				  "R_STRAIGHT","R_FLARED","R_HOOK","R_HOOKERCUT","R_UPPERCUT"]
const COLORS := {"RORY": Color(0.25, 0.55, 0.9), "PRIYA": Color(0.3, 0.8, 0.75), "MARCUS": Color(0.9, 0.6, 0.2)}
const BOSS_COLOR := Color(0.85, 0.3, 0.25)
const ELEMENT_TINT := {"FROST": Color(0.78, 0.90, 1.0), "GALE": Color(0.82, 0.84, 0.88), "GRANITE": Color(0.80, 0.62, 0.36), "TIMBER": Color(0.36, 0.48, 0.28)}   # NP_06 s2.2 aura language

var sim: TNBSim
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
var q_release := false
var flick_live := false
var q_action: Dictionary = {}
var ghost: Node3D
var ghost_t := 0.0
var ghosts_spawned := 0
var audio_assist := false
# right-stick flick classifier (harness logic, in ticks)
var armed := true
var below_tick := 0
var capture := 0
var best := Vector2.ZERO
var demo_log: Array = []           # -- demo: the scripted player drives the scene (attract mode / soak)
var demo_seg2 := false             # -- demo seg2: the scripted fighter is told to cast North Star until the ghost shows
var matchup_until := 0             # the matchup card (NP_06 s5) stays on the HUD for the opening 3s of a segment
var matchup_text := ""
var matchups_shown := 0
var fmt_id := ""                   # -- format=sanctioned|mini|iron|blind|gauntlet (F9 cycles); "" = the data's default (mini)
const FORMAT_CYCLE := ["mini", "sanctioned", "iron", "blind", "gauntlet"]
var content: Dictionary = {}

func roster_for(f: String) -> Array:
	# the cards each format dresses: 8 for the sanctioned/blind dual, 4 for the mini, 3 for the Iron dual, 1 for the Gauntlet
	match f:
		"sanctioned", "blind": return TNBSim.LINEUP_MILLBROOK_8.duplicate(true)
		"iron": return [TNBSim.LINEUP_MILLBROOK_8[0].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[2].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[3].duplicate(true)]   # RORY, PRIYA, MARCUS
		"gauntlet": return [TNBSim.LINEUP_MILLBROOK_8[0].duplicate(true)]
	return TNBSim.LINEUP_MILLBROOK.duplicate(true)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var boss_idx := 0
	for a in args:
		if a.begins_with("boss="): boss_idx = clampi(int(a.split("=")[1]), 0, TNBSim.BOSSES.size() - 1)
	for m in ["smoke", "determinism", "geometry"]:
		if m in args:
			var code := TNBTests.new().run(m, boss_idx)
			get_tree().quit(code)
			return
	for a in args:
		if a.begins_with("format="): fmt_id = a.split("=")[1]
	var lineup: Array = roster_for(fmt_id if fmt_id != "" else "mini")
	if "demo" in args:
		demo_log = TNBTests.new().build_log(120 * 600, 777)
		if lineup.size() > 1: lineup[1]["hissatsu"] = "Relay: North Star"   # the demo shows the T3 afterimage
	content = TNBSim.load_content()
	sim = TNBSim.new()
	sim.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, int(Time.get_ticks_usec() % 2147483647), content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt_id)
	_build_world()
	if "seg2" in args:                                   # demo aid: jump to a CHARGED R2 with a full bar (the T3 afterimage)
		sim.contributed = 30.0; sim._end_segment("demo"); sim.corner_pick(0); sim.corner_pick(0); sim.tension = 100.0; demo_seg2 = true
	prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
	_consume_events()

# ============================== WORLD =====================================
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
	_mk_box(Vector3(7.4, 0.2, 7.4), Color(0.22, 0.24, 0.28), Vector3(0, -0.1, 0))
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
	hud = Label.new(); hud.position = Vector2(20, 14)
	hud.add_theme_font_size_override("font_size", 17); ui.add_child(hud)
	feed = Label.new(); feed.position = Vector2(20, 640); feed.size = Vector2(1240, 70)
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD
	feed.add_theme_font_size_override("font_size", 18)
	feed.add_theme_color_override("font_color", Color(1, 0.9, 0.5)); ui.add_child(feed)
	flashrect = ColorRect.new(); flashrect.color = Color(1,1,1,0)
	flashrect.size = Vector2(1280, 720); ui.add_child(flashrect)

# ============================== INPUT =====================================
func _poll_stick() -> Vector2:
	var v := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
		if s.length() > v.length(): v = s
	return v

func _move_vec() -> Vector2:
	var v := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var lv := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
		if lv.length() > v.length(): v = lv
	if v.length() < 0.2: v = Vector2.ZERO
	v.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	v.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return v.limit_length(1.0)

func _trigger(axis: int, key: int) -> bool:
	for dev in Input.get_connected_joypads():
		if Input.get_joy_axis(dev, axis) > 0.5: return true
	return Input.is_key_pressed(key)

func _button(btn: int, key: int) -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, btn): return true
	return Input.is_key_pressed(key)

func _sector(v: Vector2) -> int:
	var ang := rad_to_deg(atan2(-v.y, v.x))
	if ang > 90.0 or ang <= -90.0:
		var la := 180.0 - ang if ang > 0.0 else -180.0 - ang
		return clampi(int(floor((la + 90.0) / 36.0)), 0, 4)
	return 5 + (4 - clampi(int(floor((ang + 90.0) / 36.0)), 0, 4))

func _intent() -> Dictionary:
	if demo_seg2 and ghosts_spawned == 0 and sim.mode == "FIGHT" and sim.tick % 60 == 0 and sim.cast.is_empty():
		sim.tension = maxf(sim.tension, 100.0)            # the aid keeps the bar full until the T3 cast has gone up once
		return {"move": Vector2(0, -1), "punch": "R_UPPERCUT", "lb": true}   # LB + uppercut = RISE: Relay: North Star
	if demo_log.size() > 0: return demo_log[sim.tick % demo_log.size()]
	var inp := {"move": _move_vec(), "block": _trigger(JOY_AXIS_TRIGGER_RIGHT, KEY_SPACE),
		"body": _trigger(JOY_AXIS_TRIGGER_LEFT, KEY_C), "power": _button(JOY_BUTTON_RIGHT_SHOULDER, KEY_SHIFT),
		"lb": _button(JOY_BUTTON_LEFT_SHOULDER, KEY_H), "rise": _button(JOY_BUTTON_A, KEY_ENTER), "audio_assist": audio_assist}
	# right-stick flick -> punch (harness classifier: fast crossing + 4-tick peak capture)
	var v := _poll_stick(); var mag := v.length()
	if mag <= 0.25: below_tick = sim.tick
	if capture > 0:
		capture -= 1
		if mag > best.length(): best = v
		if capture == 0: q_punch = SECTORS[_sector(best)]; flick_live = true
	elif armed and mag >= 0.6:
		armed = false
		if sim.tick - below_tick <= 18: capture = 4; best = v
	elif not armed and mag <= 0.25:
		armed = true
	if flick_live and mag <= 0.25: flick_live = false; q_release = true   # the stick came back: a release
	if q_punch != "": inp["punch"] = q_punch; q_punch = ""
	if q_dodge != "": inp["dodge"] = q_dodge; q_dodge = ""
	if q_taunt: inp["taunt"] = true; q_taunt = false
	if q_corner > 0: inp["corner"] = q_corner; q_corner = 0
	if q_sprint: inp["sprint"] = true; q_sprint = false
	if q_release: inp["punch_release"] = true; q_release = false
	if q_action.size() > 0: inp["corner_action"] = q_action; q_action = {}
	if q_clinch: inp["clinch"] = true; q_clinch = false
	return inp

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and not e.pressed and e.keycode in PUNCH_KEYS: q_release = true
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in PUNCH_KEYS: q_punch = PUNCH_KEYS[e.keycode]
		elif e.keycode == KEY_Q: q_dodge = "SLIP_L"
		elif e.keycode == KEY_E: q_dodge = "SLIP_R"
		elif e.keycode == KEY_V: q_dodge = "WEAVE_R"
		elif e.keycode == KEY_B: q_dodge = "LEAN"
		elif e.keycode == KEY_T: q_taunt = true
		elif e.keycode == KEY_CTRL: q_sprint = true
		elif e.keycode == KEY_G: q_clinch = true
		elif e.keycode == KEY_F8: audio_assist = not audio_assist; feed.text = "audio-assist tell cue: " + ("ON" if audio_assist else "OFF")
		elif (sim.mode == "CORNER" or sim.mode == "CARD") and e.keycode == KEY_1: q_corner = 1
		elif sim.mode == "CORNER" and e.keycode >= KEY_2 and e.keycode <= KEY_4: q_action = _tactic_action(e.keycode - KEY_2)
		elif sim.mode == "CORNER" and e.keycode == KEY_5: q_action = {"kind": "super"}
		elif sim.mode == "CORNER" and e.keycode >= KEY_6 and e.keycode <= KEY_8: q_action = _staff_action(e.keycode - KEY_6)
		elif sim.mode == "CORNER" and e.keycode == KEY_9: q_action = {"kind": "save_bar"}
		elif sim.mode == "CORNER" and e.keycode == KEY_0: q_action = _swap_action()
		elif e.keycode == KEY_R:
			sim.T = TNBSim.load_content()["tuning"]; feed.text = "tuning hot-reloaded"
		elif e.keycode == KEY_F5: sim.new_dual()
		elif e.keycode >= KEY_F1 and e.keycode <= KEY_F4: sim.switch_boss(e.keycode - KEY_F1)
		elif e.keycode == KEY_F6: sim.switch_boss((sim._first_boss + TNBSim.BOSSES.size() - 1) % TNBSim.BOSSES.size())
		elif e.keycode == KEY_F7: sim.switch_boss((sim._first_boss + 1) % TNBSim.BOSSES.size())
		elif e.keycode == KEY_F9:                                             # cycle the dual format (NP_01 s2/s8)
			var cur := fmt_id if fmt_id != "" else "mini"
			fmt_id = FORMAT_CYCLE[(FORMAT_CYCLE.find(cur) + 1) % FORMAT_CYCLE.size()]
			var first: int = sim._first_boss
			sim = TNBSim.new()
			sim.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, roster_for(fmt_id), first, int(Time.get_ticks_usec() % 2147483647), content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt_id)
			prev_p = sim.P["pos"]; prev_b = sim.B["pos"]; ghosts_spawned = 0
			feed.text = "FORMAT: %s - %d segments, %d dressed%s" % [str(sim.fmt.get("label", fmt_id)), sim.segments(), sim.dressed.size(), "  (repeat slots, condition carries)" if sim.fmt.get("repeat_slots", false) else ""]
	if e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_DPAD_UP: q_taunt = true
		elif e.button_index == JOY_BUTTON_LEFT_STICK: q_sprint = true
		elif e.button_index == JOY_BUTTON_RIGHT_STICK: q_clinch = true
		elif e.button_index == JOY_BUTTON_A and (sim.mode == "CORNER" or sim.mode == "CARD"): q_corner = 1
		elif e.button_index == JOY_BUTTON_X and sim.mode == "CORNER": q_action = _swap_action()
		elif e.button_index == JOY_BUTTON_Y and sim.mode == "CORNER": q_action = {"kind": "super"}
		elif e.button_index == JOY_BUTTON_B and sim.mode == "CORNER": q_action = {"kind": "save_bar"}
		elif e.button_index == JOY_BUTTON_DPAD_LEFT and sim.mode == "CORNER": q_action = _tactic_action(0)
		elif e.button_index == JOY_BUTTON_DPAD_RIGHT and sim.mode == "CORNER": q_action = _tactic_action(1)
		elif e.button_index == JOY_BUTTON_DPAD_DOWN and sim.mode == "CORNER": q_action = _staff_action(0)
	if e is InputEventJoypadMotion and _trigger(JOY_AXIS_TRIGGER_LEFT, KEY_C):
		if e.axis == JOY_AXIS_LEFT_X and absf(e.axis_value) > 0.7: q_dodge = "SLIP_R" if e.axis_value > 0.0 else "SLIP_L"
		elif e.axis == JOY_AXIS_LEFT_Y and e.axis_value < -0.7: q_dodge = "WEAVE_R"
		elif e.axis == JOY_AXIS_LEFT_Y and e.axis_value > 0.7: q_dodge = "LEAN"

func _tactic_action(i: int) -> Dictionary:
	var o: Dictionary = sim.corner_options()
	return {"kind": "tactic", "id": o["tactic"][i]["id"]} if i < o["tactic"].size() else {}

func _staff_action(i: int) -> Dictionary:
	var o: Dictionary = sim.corner_options()
	return {"kind": "staff", "id": o["staff"][i]["id"]} if i < o["staff"].size() else {}

func _swap_action() -> Dictionary:
	var o: Dictionary = sim.corner_options()
	return {"kind": "swap", "arg": o["swap"][0]} if o["swap"].size() > 0 else {}

# ============================== LOOP ======================================
func _process(delta: float) -> void:
	if sim == null: return
	var n := clock.advance(delta)
	for i in n:
		prev_p = sim.P["pos"]; prev_b = sim.B["pos"]
		sim.step(_intent())
		_consume_events()
	_render(clock.alpha())
	if ghost and ghost_t > 0.0:
		ghost_t -= delta
		if ghost_t <= 0.0: ghost.queue_free(); ghost = null
	_hud()

func _to3(v: Vector2) -> Vector3: return Vector3(v.x, 0.0, v.y)

func _render(alpha: float) -> void:
	player.position = _to3(prev_p.lerp(sim.P["pos"], alpha))
	boss.position = _to3(prev_b.lerp(sim.B["pos"], alpha))
	_pose(player, sim.P, sim.B)
	_pose(boss, sim.B, sim.P)
	var pmat: StandardMaterial3D = player.get_meta("mat")
	pmat.albedo_color = _base_color("P")
	var back: Vector3 = (player.position - boss.position).normalized()
	if back.length() < 0.5: back = Vector3(0, 0, 1)
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

func _exit_tree() -> void:
	if sim != null and demo_log.size() > 0:
		print("DEMO SOAK :: %d ticks, mode=%s R%d %s vs %s, score %d-%d, ghosts %d, matchup cards %d, fx %s" % [sim.tick, sim.mode, sim.seg_idx + 1, sim.pname(), sim.boss_name, sim.score_p, sim.score_b, ghosts_spawned, matchups_shown, JSON.stringify(fx_counts)])

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
			"tell": _tell_fx(int(ev["ticks"]) / float(TNBSim.TICK_HZ), bool(ev["loud"]))
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
			"cast":
				if str(ev.get("afterimage", "")) != "":
					_spawn_ghost(str(ev["afterimage"]), float(ev["windup"]) / TNBSim.TICK_HZ, bool(ev.get("trail", false)))
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

func _spawn_ghost(name: String, secs: float, trail: bool) -> void:
	# NP_05 s7: the previous fighter joins a T3 as a spirit afterimage
	if ghost: ghost.queue_free()
	ghost = _mk_capsule(COLORS.get(name, COLORS["RORY"]), player.position)
	var gm: StandardMaterial3D = ghost.get_meta("mat")
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color.a = 0.35
	if trail: gm.emission_enabled = true; gm.emission = COLORS.get(name, COLORS["RORY"]); gm.emission_energy_multiplier = 1.5
	var back: Vector3 = (player.position - boss.position).normalized()
	ghost.position = player.position + back * 0.6 + Vector3(0.3, 0, 0)
	ghost_t = secs + 0.4
	ghosts_spawned += 1

func _base_color(who: String) -> Color:
	# the fighter's colour carries the element's aura tint (NP_06 s2.2): frost blue-white, gale silver, granite amber, timber green
	var base: Color = COLORS.get(sim.pname(), COLORS["RORY"]) if who == "P" else BOSS_COLOR
	var F: Dictionary = sim.P if who == "P" else sim.B
	var el := str(F.get("element", "NONE"))
	return base.lerp(ELEMENT_TINT[el], 0.35) if ELEMENT_TINT.has(el) else base

func _bump(n: Node3D, amt: float) -> void:
	var mesh: MeshInstance3D = n.get_meta("mesh")
	mesh.position.y = 0.9 - amt
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func(): mesh.position.y = 0.9)

func _flash(a: float) -> void:
	flashrect.color.a = a
	get_tree().create_tween().tween_property(flashrect, "color:a", 0.0, 0.35)

func _tell_fx(secs: float, loud: bool) -> void:
	var mat: StandardMaterial3D = boss.get_meta("mat")
	mat.albedo_color = Color(1.0, 0.85, 0.2) if loud else Color(1.0, 0.6, 0.2)
	var mesh: MeshInstance3D = boss.get_meta("mesh")
	if tell_tween: tell_tween.kill()
	tell_tween = get_tree().create_tween()
	tell_tween.tween_property(mesh, "scale", Vector3(1.15, 1.05, 1.15), secs * 0.5)
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
	var out := "\n>>> CORNER %4.1fs   actions left %d   %s %s   [1/A] SEND%s" % [int(sim.corner["t"]) / float(TNBSim.TICK_HZ), int(o["actions_left"]), "GOLDEN DROP pick:" if sim.r6 else "next up", sim.lineup[sim._up_slot()]["name"], "   (their slot: %s)" % ("?" if sim.fmt.get("blind", false) else str(sim.blineup[sim._up_slot()]))]
	var i := 2
	for t in o["tactic"]:
		out += "\n   [%d] %s (%d T)%s - %s" % [i, t["name"], int(t["cost"]), "  [cooldown]" if t["cooldown"] else "", t["text"]]; i += 1
	for su in o["super"]:
		out += "\n   [5] SUPER %s%s - %s" % [su["name"], "  [spent]" if su["used"] else "", su["text"]]
	i = 6
	for st in o["staff"]:
		out += "\n   [%d] %s x%d - %s" % [i, st["name"], int(st["charges"]), st["text"]]; i += 1
	out += "\n   [9] SAVE THE BAR%s      [0/X] %s %s (%s)" % ["  [set]" if not o["save_bar"] else "", "PICK" if sim.r6 else "SWAP", ", ".join(PackedStringArray(o["swap"])) if o["swap"].size() > 0 else "-", "free" if int(o["swap_cost"]) == 0 else "%d T" % int(o["swap_cost"])]
	return out

func _hiss_line() -> String:
	var mv: Dictionary = sim.player_move()
	if mv.is_empty(): return ""
	var cost := sim.hiss_cost(mv)
	var motion: String = {"HAYMAKER": "haymaker flick", "ARC": "hook flick", "PISTON": "straight flick", "RISE": "uppercut flick", "WALL": "hold RT 400ms"}.get(str(mv["family"]), "?")
	if not sim.castable(mv): return "  %s: sealed" % mv["name"]
	return "  %s %s %s: %s" % [mv["name"], mv["tier"], "READY (LB + %s, %d)" % [motion, int(cost)] if sim.tension >= cost else "needs %d" % int(cost), ""]

func _wall_line() -> String:
	var out := ""
	for k in ["B", "P"]:
		var w: Dictionary = sim.wall[k]
		if w.size() == 0: continue
		var who := "HIS WALL" if k == "B" else "YOUR WALL"
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
		[str(sim.fmt.get("label", "")), "GOLDEN DROP" if sim.r6 else "R%d" % (sim.seg_idx + 1), sim.segments(), sim.pname(), sim.boss_name, "no clock" if sim.r6 else "%5.1f" % (sim.clock_t / float(TNBSim.TICK_HZ)), sim.score_p, sim.score_b, sim.drops_p, sim.drops_b, sim.seg_wins_p, sim.seg_wins_b, sim.ep_p, sim.ep_b]
	var mode_line := ""
	match sim.mode:
		"EIGHT": mode_line = "\n>>> STANDING EIGHT: ENTER / A on the beat  (%d to go)" % int(sim.eight.get("beats_left", 0))
		"CARD": mode_line = "\n>>> %s (%.1fs, ENTER/1 to skip)" % ["TIED ON THE LADDER - GOLDEN DROP: any dressed fighter, condition carried, no clock, first DROP wins" if sim.r6 else "SEGMENT CARD", sim.card_t / float(TNBSim.TICK_HZ)]
		"CORNER": mode_line = _corner_menu() + _their_corner()
		"OVER": mode_line = "\n>>> DUAL OVER - F5 new dual, F1-F4 pick boss, F9 format"
	if sim.mode == "FIGHT" and sim.tick < matchup_until and matchup_text != "": mode_line += "\n" + matchup_text
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
	if sim.btactic_fx.size() > 0: bug += "   his tactics: " + ",".join(PackedStringArray(sim.btactic_fx.keys()))
	if sim.bwarnings > 0: bug += "   REF WARN x%d (him)" % sim.bwarnings
	if sim.pwarnings > 0: bug += "   REF WARN x%d (you)" % sim.pwarnings
	if sim.pholding > 0: bug += "   holding calls x%d (you)" % sim.pholding
	if audio_assist: bug += "   [audio-assist cue ON]"
	hud.text = head + bug + mode_line + "\n" \
		+ "ZONE you:%s%s  him:%s%s   dist %.2fm   tick %d%s\n" % [zp, " TRAPPED" if sim.trapped_p else "", zb, " TRAPPED" if sim.trapped_b else "", P["pos"].distance_to(B["pos"]), sim.tick, "  [HITSTOP]" if sim.freeze_t > 0 else ""] \
		+ "YOU   stam %s  chin %s  guard %s%s   %s   [%s/%s]\n" % [_bar(P["stamina"], 100, 14), _bar(P["comp"], P["comp_max"], 14), _bar(P["guard"], P["guard_max"], 10), "  OPEN!" if P["guard_open_t"] > 0 else "", P["dodge"] if P["dodge"] != "" else "", str(P.get("style", "")), str(P.get("element", ""))] \
		+ "BOSS  chin %s   phase %d   %s%s%s   [%s/%s]\n" % [_bar(B["comp"], B["comp_max"], 14), sim.bphase, "TELL" if sim.bstate == "FAKE" else sim.bstate, "  << TELL - HIT HIM NOW" if (sim.bstate == "TELL" or sim.bstate == "FAKE") else ("  hands DOWN" if sim.hands_down_t > 0 else ""), ("  [" + B["dodge"] + "]") if B["dodge"] != "" else ("  [GUARD]" if (B["blocking"] or B["guard_t"] > 0) else ""), str(B.get("style", "")), str(B.get("element", ""))] \
		+ "TENSION %s %3.0f  %s%s%s%s   THEIRS %s %3.0f" % [_bar(sim.tension, 100, 16), sim.tension, _hiss_line(), "   counter!" if P["counter_t"] > 0 else "", "   FLASH!" if P["flash_t"] > 0 else "", "   relay chain %d" % sim.relay_chain if sim.relay_chain > 0 else "", _bar(sim.btension, 100, 12), sim.btension] \
		+ _wall_line() + _cast_line() + _state_line()

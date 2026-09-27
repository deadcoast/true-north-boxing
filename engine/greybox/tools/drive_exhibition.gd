extends SceneTree
# TRUE NORTH BOXING - the Exhibition 2v2 on the real scene, headless (PAC-088).
#   godot --headless --path engine/greybox -s tools/drive_exhibition.gd -- format=exhibition_2v2 kizuna=RORY+PRIYA:90
# Loads the real scene on NP_01 s8's festival format, RORY and PRIYA a Duo on the ledger (the command line's seed): the pad plays RORY
# against Vane, PRIYA plays hers against Yuri on her profile, each pair drawn in its own half of the ring, the HUD's exhibition lines (the
# ring clock, the team score, both pairs, the duo sync live). With the bar topped up, H + O (LB + the uppercut flick) calls Double
# Overtime - the window's toast; PRIYA's profile answers at 250 ms and both halves cast it, the bar paying once, the toast and both
# capsules gilded; it lands on both opponents. \ hands the pad to PRIYA - the halves swap. The bell on both pairs: EXHIBITION OVER with the
# ladder's verdict on the sums, one REWARD toast. F5: the exhibition again, the ledger carried. Exit 0 = every step did what the keys and
# the exhibition say.
var main_node: Node
var f := 0
var fails: Array = []
var comp0 := [0.0, 0.0]
var kiz0 := 0
var cost0 := 0.0

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _key(code: Key, down: bool, held: bool) -> void:
	# held: the Input singleton's state, as a held key is (it lands on the next frame); else an event the scene reads
	var k := InputEventKey.new(); k.keycode = code; k.pressed = down
	if held: Input.parse_input_event(k)
	else: root.push_input(k)

func _quiet(s) -> void:
	s.hooks_enabled = false; s.coach_on = false; s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}; s.neutral_on = false
	s.P["pos"] = Vector2(0.0, 0.8); s.B["pos"] = Vector2(0.0, -0.8)

func _steps(n: int) -> void:
	var ex = main_node.exh
	for i in n:
		if ex.a.mode == "FIGHT": ex.a.btimer = 1 << 30
		if ex.b.mode == "FIGHT": ex.b.btimer = 1 << 30
		ex.step({})
	main_node.sim = ex.ctrl_sim(); main_node._consume_exh(); main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var ex = main_node.exh
	var hud: String = main_node.hud.text
	match f:
		4:
			var ok_set: bool = ex != null and main_node.sim == ex.a and ex.a.pname() == "RORY" and ex.b.pname() == "PRIYA" and ex.b.delegated and not ex.a.delegated and main_node.partner != null
			var halves: bool = ok_set and main_node.player.position.x < 0.0 and main_node.partner.position.x > 0.0
			_check("the festival format: the pad plays RORY vs Vane, PRIYA on her profile vs Yuri, each pair in its own half; the HUD's exhibition lines", ok_set and halves and hud.contains("EXHIBITION 2v2 (festival)") and hud.contains("PAIR A  RORY vs cassidy_vane") and hud.contains("PAIR B  PRIYA vs yuri_kowalchuk") and hud.contains("DUO SYNC (Lv4): LB + uppercut = DOUBLE OVERTIME (50), LB + RT held = TWO-HAND WINTER (50)"), "player x %.2f, partner x %.2f" % [main_node.player.position.x, main_node.partner.position.x] if ok_set else "no exhibition")
			if ok_set:
				_quiet(ex.a); _quiet(ex.b); ex.set_team(100.0); kiz0 = int(ex.a.rewards["kizuna"].get("PRIYA|RORY", 0))
				comp0 = [float(ex.a.B["comp"]), float(ex.b.B["comp"])]; cost0 = ex.a.hiss_cost(ex.sync_move("RISE"))   # the caller's price (NP_06 s2.1's edge where his element beats Vane's)
				_key(KEY_H, true, true)
		6: _key(KEY_O, true, false)
		10:
			var called: bool = ex.window.size() > 0 or main_node.duo_syncs.size() > 0
			_check("H + O (LB + the uppercut flick) with the bar full: RORY calls Double Overtime - the window's toast (or PRIYA already answered)", called and (hud.contains("DUO SYNC  RORY calls DOUBLE OVERTIME - PRIYA has 0.5s (his profile answers)") or hud.contains("DUO SYNC  DOUBLE OVERTIME")), JSON.stringify(ex.window))
			_key(KEY_H, false, true)
			var n := 0
			while ex.window.size() > 0 and n < 60: _steps(1); n += 1
		13:
			var both: bool = str(ex.a.cast.get("move", {}).get("name", "")) == "Double Overtime" and str(ex.b.cast.get("move", {}).get("name", "")) == "Double Overtime"
			var pm: StandardMaterial3D = main_node.partner.get_meta("mat")
			_check("PRIYA's profile answers at 250 ms: both halves cast it, RORY's price off the bar once, the toast, both capsules gilded", both and main_node.duo_syncs == ["Double Overtime by ai at 250ms (bar %d)" % int(100.0 - cost0)] and hud.contains("DUO SYNC  DOUBLE OVERTIME") and pm.emission_enabled, "%s, bar %.1f" % [JSON.stringify(main_node.duo_syncs), ex.team])
			var n2 := 0
			while (ex.a.cast.size() > 0 or ex.b.cast.size() > 0) and n2 < 600: _steps(1); n2 += 1
		16:
			_check("resolved: it lands on both opponents", float(ex.a.B["comp"]) < float(comp0[0]) and float(ex.b.B["comp"]) < float(comp0[1]), "Vane %.1f -> %.1f, Yuri %.1f -> %.1f" % [float(comp0[0]), float(ex.a.B["comp"]), float(comp0[1]), float(ex.b.B["comp"])])
			_key(KEY_BACKSLASH, true, false)
		20:
			_check("\\ hands the pad to PRIYA: RORY on his profile, the halves swapped, the HUD says so", ex.ctrl == "B" and main_node.sim == ex.b and ex.a.delegated and not ex.b.delegated and main_node.player.position.x > 0.0 and main_node.partner.position.x < 0.0 and hud.contains("you play PRIYA"), "player x %.2f" % main_node.player.position.x)
			for s in [ex.a, ex.b]: s.clock_t = 2
			var n3 := 0
			while not ex.over and n3 < 120: _steps(1); n3 += 1                                          # the bell (past any hitstop still on the pairs)
		23:
			_check("the bell on both pairs: EXHIBITION OVER - the ladder's verdict on the sums, one REWARD toast, the pair's bond paid once", ex.over and hud.contains("EXHIBITION OVER :: ") and hud.contains(" THE EXHIBITION") and hud.contains("TEAM SCORE") and hud.contains("REWARD  DUAL:") and int(ex.a.rewards["kizuna"].get("PRIYA|RORY", 0)) - kiz0 in [int(ex.a.ECO["kizuna"]["adjacent_slots"]), int(ex.a.ECO["kizuna"]["adjacent_slots_win"])], str(ex.verdict.get("verdict", "")))
			_key(KEY_F5, true, false)
		26:
			_check("F5: the exhibition again - both pairs at the bell, the ledger carried", not ex.over and ex.a.mode == "FIGHT" and ex.b.mode == "FIGHT" and is_same(ex.a.rewards, ex.b.rewards) and int(ex.a.rewards["kizuna"].get("PRIYA|RORY", 0)) > kiz0 and hud.contains("EXHIBITION 2v2 (festival)"), "")
		28:
			print("EXHIBITION DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 7 - fails.size(), 7])
			quit(0 if fails.is_empty() else 1)
	return false

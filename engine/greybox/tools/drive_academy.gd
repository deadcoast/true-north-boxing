extends SceneTree
# TRUE NORTH BOXING - the academy's syntheses on the real scene, headless (PAC-092).
#   godot --headless --path engine/greybox -s tools/drive_academy.gd -- academy format=sanctioned kizuna=YURI+MARTA:150 purse=spirits:40,beans:30 facility=wall:3 forge=YURI+MARTA board=YURI,MARTA,RORY,PRIYA,SAM
# Loads the real scene with the Toronto academy fielded (-- academy: its five prodigies in every enemy segment, Director Vey's corner) and
# the club's answer forged before the bell (YURI & MARTA Sworn, Grain & Snow). R1 YURI against ASCENDANT 1: the matchup card's ACADEMY
# line names his three syntheses, its THESIS line sets Grain & Snow (x2.5, x3.13 relayed) against his best. His bar filled, at his
# decision point within reach he casts the first synthesis - the SYNTHESIS toast, the bar paying 50; J (the jab) in its windup breaks it
# (his read cancelled, as the smoke's throw_clean does).
# Won on segments to R2: MARTA against ASCENDANT 2, the THESIS line now "relayed now, x3.13 with YURI's afterimage". H + ; (LB + the
# hookercut, HAYMAKER) with the bar full casts Grain & Snow relayed - it resolves, and his composure takes it.
# Exit 0 = every step did what the keys and the matchup card say.
var main_node: Node
var f := 0
var fails: Array = []
var comp0 := 0.0

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _key(code: Key, down: bool = true, held: bool = false) -> void:
	# held: the Input singleton's state, as a held key is (it lands on the next frame); else an event the scene reads
	var k := InputEventKey.new(); k.keycode = code; k.pressed = down
	if held: Input.parse_input_event(k)
	else: root.push_input(k)

func _quiet(s) -> void:
	s.hooks_enabled = false; s.coach_on = false; s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}; s.neutral_on = false

func _seg_won(s) -> void:
	# a segment ended with Millbrook ahead on EP (the sim's own segment end, no fight), the card and the corner sent on
	s.mode = "FIGHT"; s.eight = {}; s.ep_p += 4; s._end_segment("drive")
	if s.mode == "CARD": s.step({"corner": 1})
	if s.mode == "CORNER": s.step({"corner": 1})

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_quiet(s)
			_check("the bell: R1 YURI against ASCENDANT 1 of the academy's five, Director Vey's corner, Grain & Snow forged before it", s.pname() == "YURI" and s.boss_label == "ASCENDANT 1" and s.blineup == ["ASCENDANT 1", "ASCENDANT 2", "ASCENDANT 3", "ASCENDANT 4", "ASCENDANT 5"] and str(s.coach.get("id", "")) == "ascendant_a" and s.hybrid_registry().size() == 1, JSON.stringify(s.blineup))
			_check("the matchup card: the ACADEMY line (his three syntheses, x2.04 each) and the THESIS line (the club's Grain & Snow x2.5, x3.13 relayed)", hud.contains("ACADEMY: ASCENDANT 1 carries 3 syntheses - Synthesis Tide-Heat (LB + HAYMAKER, x2.04), Synthesis Heat-Bell (LB + ARC, x2.04), Synthesis Heat-Light (LB + ARC, x2.04) - no bond, no afterimage, no history") and hud.contains("THESIS: your forged Grain & Snow (MARTA & YURI) x2.5 (x3.13 relayed) against his best synthesis Synthesis Tide-Heat x2.04"), "")
			s.P["pos"] = Vector2(0, 0.5); s.B["pos"] = Vector2(0, -0.5); s.btension = 60.0; s.cast = {}; s.freeze_t = 0; s.bstate = "IDLE"; s.btimer = 1
		8:
			var armed: bool = s.cast.size() > 0 and str(s.cast["who"]) == "B" and str(s.cast["move"].get("name", "")) == "Synthesis Tide-Heat"
			_check("his bar at 60, within reach at his decision point: Synthesis Tide-Heat armed - the SYNTHESIS toast, 50 off his bar", (armed or main_node.syntheses_seen.size() > 0) and hud.contains("SYNTHESIS  ASCENDANT 1 - SYNTHESIS TIDE-HEAT (LB + HAYMAKER, x2.04; 1 of 3) - industrial: no bond, no afterimage") and absf(s.btension - 10.0) < 0.001, "%s, his bar %.1f" % [JSON.stringify(main_node.syntheses_seen), s.btension])
			s.P["busy_t"] = 0; s.P["cmd"] = {}; s.B["dodge"] = ""; s.B["blocking"] = false
			_key(KEY_J)
		12:
			var n0 := 0                                                                                 # the jab thrown by the key, run to its landing with his read cancelled (the smoke's throw_clean)
			while (s.P["pending"].size() > 0 or s.P["cmd"].size() > 0) and n0 < 200:
				s.B["dodge"] = ""; s.B["dodge_t"] = 0; s.B["blocking"] = false; s.B["guard_t"] = 0; s.step({}); n0 += 1
			main_node._consume_events()
		20:
			_check("J (the jab) in its windup breaks it - no synthesis lands", s.cast.is_empty() and int(main_node.fx_counts.get("cast_interrupted", 0)) >= 1, "interrupts %d" % int(main_node.fx_counts.get("cast_interrupted", 0)))
			_quiet(s); _seg_won(s); main_node._consume_events()
		24:
			_quiet(s)
			_check("won on segments to R2: MARTA against ASCENDANT 2 - the THESIS line relayed now, x3.13 with YURI's afterimage", s.pname() == "MARTA" and s.boss_label == "ASCENDANT 2" and hud.contains("THESIS: your forged Grain & Snow (MARTA & YURI) x2.5 - relayed now, x3.13 with YURI's afterimage against his best synthesis Synthesis Bridge-Snow x2.04"), s.thesis_line())
			s.tension = 100.0; s.P["busy_t"] = 0; s.P["cmd"] = {}; s.freeze_t = 0; s.P["pos"] = Vector2(0, 0.6); s.B["pos"] = Vector2(0, -0.6); comp0 = float(s.B["comp"]); _key(KEY_H, true, true)
		26: _key(KEY_SEMICOLON)
		30:
			_key(KEY_H, false, true)
			var armed2: bool = s.cast.size() > 0 and str(s.cast["move"].get("name", "")) == "Grain & Snow" and str(s.cast["move"].get("hybrid_live", "")) == "relayed"
			_check("H + ; with the bar full: MARTA's Grain & Snow armed relayed - the club's forged answer", armed2 or main_node.hybrid_casts.size() > 0, JSON.stringify(main_node.hybrid_casts))
			_quiet(s)
			var n := 0
			while s.cast.size() > 0 and n < 600: s.step({}); n += 1
			main_node._consume_events()
		34:
			_check("resolved: it lands on ASCENDANT 2 - his composure takes it", float(s.B["comp"]) < comp0, "composure %.1f -> %.1f" % [comp0, float(s.B["comp"])])
		36:
			print("ACADEMY DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 7 - fails.size(), 7])
			quit(0 if fails.is_empty() else 1)
	return false

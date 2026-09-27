extends SceneTree
# TRUE NORTH BOXING - the Duo on the real scene, headless (PAC-080).
#   godot --headless --path engine/greybox -s tools/drive_duo.gd -- kizuna=RORY+PRIYA:90
# Loads the real scene with RORY and PRIYA a Duo on the ledger (the command line's seed). R1 RORY carries no Duo; R1 ends on the sim's own
# segment end and the corner sends PRIYA: the matchup card names the Duo relay (Whiteout, LB + HAYMAKER, its price); the relay's cast - LB and
# the haymaker flick, handed to the sim as the pad would (the keyboard has no haymaker key) - arms Whiteout, and the scene gilds RORY's
# afterimage and puts the DUO toast on the HUD; once it resolves, R2 ends the same way and R3 MARCUS, after PRIYA, carries none.
# PAC-081: R2 ends CHARGED (30 contributed), so R3 MARCUS's matchup card names the T3s the relay opens to him (NP_05 s6).
# Exit 0 = every step did what the Duo says.
var main_node: Node
var f := 0
var phase := 0
var comp0 := 0.0
var fails: Array = []

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _end_segment(s, charged: bool = false) -> void:
	# the segment ends on EP (the sim's own end path; CHARGED when asked: 30 contributed), the corner sends the next fighter
	s.hooks_enabled = false; s.coach_on = false
	s.mode = "FIGHT"; s.eight = {}; s.cast = {}; s.ep_p += 4
	if charged: s.contributed = 30.0
	s._end_segment("drive")
	if s.mode == "CARD": s.step({"corner": 1})
	if s.mode == "CORNER": s.step({"corner": 1})
	main_node._consume_events()

func _finish() -> void:
	print("DUO DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 6 - fails.size(), 6])
	quit(0 if fails.is_empty() else 1)

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	if f == 4:
		_check("R1 RORY carries no Duo (nobody fought before him)", s.pname() == "RORY" and s.duo.is_empty() and not main_node.hud.text.contains("DUO:") and int(s.kizuna_level("RORY", "PRIYA")) == 4, "Kizuna %d" % s.kizuna_pts("RORY", "PRIYA"))
		_end_segment(s)
	elif f == 8:
		_check("the matchup card names the Duo relay: RORY -> PRIYA, Whiteout, LB + HAYMAKER at its price", s.pname() == "PRIYA" and main_node.hud.text.contains("DUO: RORY -> PRIYA (Lv4) - WHITEOUT live: LB + HAYMAKER, %d Tension (Relay: Coast to Coast)" % int(s.hiss_cost(s.duo_move()))), "R%d %s" % [s.seg_idx + 1, s.pname()])
		s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}; s.neutral_on = false   # he stands for it: the cast's resolve is the point
		s.P["pos"] = Vector2(0.0, 0.7); s.B["pos"] = Vector2(0.0, -0.7); s.B["blocking"] = false; s.B["dodge"] = ""; s.B["dodge_t"] = 0; comp0 = float(s.B["comp"])
		s.tension = 60.0; s.P["busy_t"] = 0; s.P["cmd"] = {}
		s.step({"punch": "R_HOOKERCUT", "lb": true}); main_node._consume_events()
	elif f == 10:
		var gm_ok: bool = main_node.ghost != null and main_node.ghost.get_meta("mat").emission_enabled
		_check("LB + the haymaker arms Whiteout: RORY's afterimage gilded on the scene, the DUO toast on the HUD", s.cast.size() > 0 and str(s.cast["move"]["name"]) == "Whiteout" and main_node.ghosts_spawned == 1 and gm_ok and main_node.hud.text.contains("DUO  WHITEOUT  - PRIYA & RORY (Relay: Coast to Coast)"), "ghosts %d" % main_node.ghosts_spawned)
		phase = 1
	elif phase == 1 and s.cast.is_empty():
		_check("Whiteout resolves on the scene: it lands on him, the fight goes on", float(s.B["comp"]) < comp0 and (s.mode == "FIGHT" or s.mode == "CARD"), "tick %d, his composure %.1f -> %.1f, the scene's Duo casts %s" % [s.tick, comp0, float(s.B["comp"]), str(main_node.duo_casts)])
		phase = 2
		if s.mode == "FIGHT": _end_segment(s, true)
	elif phase == 2:
		phase = 3
	elif phase == 3:
		_check("R3 MARCUS after PRIYA carries none", s.pname() == "MARCUS" and s.duo.is_empty() and not main_node.hud.text.contains("DUO:"), "R%d %s" % [s.seg_idx + 1, s.pname()])
		_check("R3 MARCUS out CHARGED: the matchup card names the T3s the relay opens (PAC-081)", s.t3_unlocked and main_node.hud.text.contains("RELAY (chain 1): Relay: Coast to Coast (LB + HAYMAKER, %d), Relay: Aurora Chain (LB + ARC, %d)" % [int(s.hiss_cost(s.relay_moves()[0])), int(s.hiss_cost(s.relay_moves()[1]))]), s.relay_line())
		_finish()
	elif f > 1200:
		_check("the drive reached its end", false, "stuck at frame %d, phase %d" % [f, phase]); _finish()
	return false

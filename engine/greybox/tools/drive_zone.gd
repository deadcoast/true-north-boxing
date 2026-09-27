extends SceneTree
# TRUE NORTH BOXING - In the Zone on the real scene, headless (PAC-082).
#   godot --headless --path engine/greybox -s tools/drive_zone.gd -- level=RORY:20 flag=story:provincials_semifinal
# Loads the real scene with RORY at level 20 and the Provincials' flag (the command line's seeds). H + Y (the keyboard's SURGE; the pad's is LB
# + both sticks) with an empty bar is refused on the HUD; with the bar topped up it SURGEs: the Zone's toast, the camera hold, then the HUD's
# Zone line and RORY lit in his element; 20 s of fight time on (stepped through the sim), the Comedown's line and RORY dimmed; 10 s more, himself.
# Exit 0 = every step did what the keys and the Zone say.
var main_node: Node
var f := 0
var fails: Array = []

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _hold_h() -> void:
	# H held: the Input singleton's state, as a held key is (it lands on the next frame)
	var h := InputEventKey.new(); h.keycode = KEY_H; h.pressed = true; Input.parse_input_event(h)

func _press_y() -> void:
	var y := InputEventKey.new(); y.keycode = KEY_Y; y.pressed = true; root.push_input(y)

func _release_h() -> void:
	var h := InputEventKey.new(); h.keycode = KEY_H; h.pressed = false; Input.parse_input_event(h)

func _run(s, n: int) -> void:
	# fight time stepped through the sim with nobody pressing anything, his corner quiet, the scene's events consumed
	s.hooks_enabled = false; s.coach_on = false; s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}
	for i in n:
		if s.mode != "FIGHT" and s.mode != "EIGHT": break
		s.step({})
	main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	match f:
		4: _check("R1 RORY, level %d with the Provincials' flag: the Zone unlocked, no Zone line" % s.level_of("RORY"), s.pname() == "RORY" and s.transform_tier("RORY") == "zone" and not main_node.hud.text.contains("IN THE ZONE"), "")
		5: s.tension = 0.0; _hold_h()
		7: _press_y()
		10: _check("H + Y with an empty bar: refused on the HUD", s.tform.is_empty() and main_node.hud.text.contains("SURGE  the bar is at 0 - a transformation takes the whole bar (100)"), "")
		11: s.tension = 100.0
		12: _press_y()
		18:
			_release_h()
			_check("H + Y with the bar full: the SURGE - the whole bar gone, the toast, the camera hold", s.tform.size() > 0 and s.tension == 0.0 and s.freeze_t > 0 and main_node.hud.text.contains("IN THE ZONE  RORY - the whole bar (100)"), "hold %d ticks left" % s.freeze_t)
			_run(s, s.freeze_t + 120)
		21:
			var pm: StandardMaterial3D = main_node.player.get_meta("mat")
			_check("after the hold: the HUD's Zone line, RORY lit in his element", main_node.hud.text.contains("IN THE ZONE 19.0s | stamina frozen ") and pm.emission_enabled, s.zone_line())
			if s.tform.size() > 0: _run(s, int(s.tform["t"]))
		25:
			var pm2: StandardMaterial3D = main_node.player.get_meta("mat")
			_check("20 s of fight time on: the Comedown's line, its toast, RORY dimmed and unlit", s.tform.is_empty() and main_node.hud.text.contains(">>> COMEDOWN ") and main_node.hud.text.contains("s (85%)") and main_node.hud.text.contains("COMEDOWN  RORY - 10s at 85%") and not pm2.emission_enabled, s.zone_line())
			if s.comedown.size() > 0: _run(s, int(s.comedown["t"]))
		29:
			_check("10 s on: himself again, no line", s.comedown.is_empty() and not main_node.hud.text.contains("COMEDOWN") and not main_node.hud.text.contains("IN THE ZONE "), "")
		32:
			print("ZONE DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 6 - fails.size(), 6])
			quit(0 if fails.is_empty() else 1)
	return false

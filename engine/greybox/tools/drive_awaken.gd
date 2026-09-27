extends SceneTree
# TRUE NORTH BOXING - Awakening on the real scene, headless (PAC-085).
#   godot --headless --path engine/greybox -s tools/drive_awaken.gd -- level=RORY:20 flag=story:provincials_semifinal,story:manifest:RORY,secret:RORY,story:trial:RORY,story:sealed_house_resolved form=RORY:manifest
# Loads the real scene with RORY's gate met (the Zone's level and flag, his manifest, his SECRET, his Arc 3 trial, the sealed house resolved)
# and his Awakening's form chosen as the Manifest (the command line's seeds, the overworld menu's choice). The matchup card names the SURGE;
# H + Y (the keyboard's SURGE) with the bar topped up Awakens him: the toast, the camera hold; the HUD's AWAKENED line, the ring lit in his
# element, his manifest behind him; a drop he scores refunds 15 Tension with its toast; 40 s of fight time on, the Comedown's line and toast,
# the ring dark, the figure gone; 10 s more, himself. Exit 0 = every step did what the keys and the Awakening say.
var main_node: Node
var f := 0
var fails: Array = []

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

func _run(s, n: int) -> void:
	# fight time stepped through the sim with nobody pressing anything, his corner quiet, the scene's events consumed
	_quiet(s)
	for i in n:
		if s.mode != "FIGHT" and s.mode != "EIGHT": break
		s.step({})
	main_node._consume_events()

func _floor_lit() -> bool:
	var fm: StandardMaterial3D = main_node.ring_floor.mesh.material
	return fm.emission_enabled

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	match f:
		4:
			_quiet(s)
			_check("R1 RORY with his gate met: Awakening his tier, the Manifest its form, the matchup card's SURGE line, no AWAKENED line", s.pname() == "RORY" and s.transform_tier("RORY") == "awakening" and s.awaken_form("RORY") == "manifest" and main_node.hud.text.contains("SURGE: Awakening (100) - Manifest-Awakening at 75%") and not main_node.hud.text.contains("AWAKENED "), s.surge_line("RORY"))
		5: s.tension = 100.0; _key(KEY_H, true, true)
		7: _key(KEY_Y, true, false)
		12:
			_key(KEY_H, false, true)
			_check("H + Y with the bar full: the SURGE Awakens him - the whole bar gone, the toast naming the Manifest at 75%, the camera hold", s.tform.get("tier", "") == "awakening" and s.tension == 0.0 and s.freeze_t > 0 and main_node.hud.text.contains("AWAKENING  RORY - the whole bar (100)  - Manifest-Awakening at 75%"), "hold %d ticks left" % s.freeze_t)
			_run(s, s.freeze_t + 120)
		15:
			var rx := RegEx.new(); rx.compile("AWAKENED (39\\.0|38\\.9|38\\.8)s \\| Manifest-Awakening at 75% \\| ring caps x1\\.75 \\| a drop \\+15 \\| RORY's manifest \\| meter 37/37")
			var pm: StandardMaterial3D = main_node.player.get_meta("mat")
			_check("after the hold: the HUD's AWAKENED line, the ring lit in his element, his manifest behind him, RORY at his brightest", rx.search(main_node.hud.text) != null and _floor_lit() and main_node.manifest_fig != null and pm.emission_enabled and pm.emission_energy_multiplier > 2.0, s.zone_line())
			_quiet(s); s.tension = 0.0; s._drop(false); main_node._consume_events()
		17:
			_check("a drop he scores Awakened: +15 Tension back to the bar beside the drop's own, the toast", s.tension == 25.0 and main_node.hud.text.contains("AWAKENED DROP  RORY - +15 Tension back (bar 25)"), "bar %.1f" % s.tension)
			if s.tform.size() > 0: _run(s, int(s.tform["t"]))
		21:
			_check("40 s of fight time on: the Comedown's line and toast, the ring dark, the manifest gone", s.tform.is_empty() and main_node.hud.text.contains(">>> COMEDOWN ") and main_node.hud.text.contains("COMEDOWN  RORY - 10s at 85%") and not _floor_lit() and main_node.manifest_fig == null, s.zone_line())
			if s.comedown.size() > 0: _run(s, int(s.comedown["t"]))
		25:
			_check("10 s on: himself again, no line", s.comedown.is_empty() and not main_node.hud.text.contains("COMEDOWN") and not main_node.hud.text.contains("AWAKENED "), "")
		28:
			print("AWAKENING DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 6 - fails.size(), 6])
			quit(0 if fails.is_empty() else 1)
	return false

extends SceneTree
# TRUE NORTH BOXING - Spirit Manifestation on the real scene, headless (PAC-083).
#   godot --headless --path engine/greybox -s tools/drive_manifest.gd -- level=RORY:20 flag=story:provincials_semifinal,story:manifest:RORY
# Loads the real scene with RORY at level 20, the Provincials' flag and his own Arc 2 flag (the command line's seeds): the Manifest is his
# highest tier. H + Y (the keyboard's SURGE; the pad's is LB + both sticks) with the bar topped up casts it: the toast names the tier, his
# manifest and its meter; after the camera hold the HUD's MANIFEST line, RORY lit and his manifest standing behind him; a clean punch stepped
# through the sim and its echo 0.3 s later, the figure pulsing; 30 s of fight time on, the Comedown's line and toast, the figure gone, RORY
# dimmed; 10 s more, himself. Exit 0 = every step did what the keys and the Manifest say.
var main_node: Node
var f := 0
var fails: Array = []
var echo_d := 0.0

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

func _quiet(s) -> void:
	s.hooks_enabled = false; s.coach_on = false; s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}; s.neutral_on = false

func _run(s, n: int) -> void:
	# fight time stepped through the sim with nobody pressing anything, his corner quiet, the scene's events consumed
	_quiet(s)
	for i in n:
		if s.mode != "FIGHT" and s.mode != "EIGHT": break
		s.step({})
	main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	match f:
		4: _check("R1 RORY with his Arc 2 flag: the Manifest his highest tier, no MANIFEST line, no figure", s.pname() == "RORY" and s.transform_tier("RORY") == "manifest" and not main_node.hud.text.contains("MANIFEST ") and main_node.manifest_fig == null, "")
		5: s.tension = 100.0; _hold_h()
		7: _press_y()
		12:
			_release_h()
			_check("H + Y with the bar full: the SURGE casts the Manifest - the whole bar gone, the toast with his manifest and its meter, the camera hold", s.tform.get("tier", "") == "manifest" and s.tension == 0.0 and s.freeze_t > 0 and main_node.hud.text.contains("SPIRIT MANIFESTATION  RORY - the whole bar (100)  - RORY's manifest, its own meter 50"), "hold %d ticks left" % s.freeze_t)
			_run(s, s.freeze_t + 120)
		15:
			var pm: StandardMaterial3D = main_node.player.get_meta("mat")
			var fig: Node3D = main_node.manifest_fig
			var behind: bool = fig != null and fig.position.distance_to(main_node.boss.position) > main_node.player.position.distance_to(main_node.boss.position)
			# the clock reads 29.0 s, or a tenth less when the scene's own real-time loop ran a few ticks between frames (a loaded machine)
			var rx := RegEx.new(); rx.compile("MANIFEST (29\\.0|28\\.9|28\\.8)s \\| RORY's manifest \\| meter 50/50 \\| echo \\+30% at 0\\.3s \\| damage x1\\.4")
			_check("after the hold: the HUD's MANIFEST line, RORY lit, his manifest standing behind him", rx.search(main_node.hud.text) != null and pm.emission_enabled and behind, s.zone_line())
			# a clean punch: the boss still, his read cancelled, the punch landed, then 0.3 s of fight time for the echo
			_quiet(s); s.P["pos"] = Vector2(0.0, 0.8); s.B["pos"] = Vector2(0.0, -0.8); s.P["busy_t"] = 0; s.P["cmd"] = {}
			s.step({"punch": "R_STRAIGHT"})
			# his read cancelled whole, as the smoke's throw_clean does (the dodge planned for later too) and his guard down
			s.B["dodge"] = ""; s.B["dodge_t"] = 0; s.B["dodge_at"] = 0; s.B["dodge_plan"] = []; s.B["blocking"] = false; s.B["block_t"] = 0; s.B["guard_t"] = 0
			var n := 0
			while (s.P["cmd"].size() > 0 or s.P["pending"].size() > 0) and n < 400: s.step({}); n += 1
			while s.freeze_t > 0: s.step({})
			for e in s.events:
				if str(e["kind"]) == "hit" and str(e["on"]) == "B": echo_d = float(e["dmg"])
			_run(s, TNBSim_ms(300))
		16:
			var fm: StandardMaterial3D = main_node.manifest_fig.get_meta("mat") if main_node.manifest_fig else null
			_check("a clean punch and 0.3 s on: the manifest's echo shown, the figure pulsing", main_node.echoes_seen == 1 and fm != null and fm.emission_energy_multiplier > 2.0, "punch %.2f, echoes %d" % [echo_d, main_node.echoes_seen])
			if s.tform.size() > 0: _run(s, int(s.tform["t"]))
		20:
			var pm2: StandardMaterial3D = main_node.player.get_meta("mat")
			_check("30 s of fight time on: the Comedown's line, its toast, the manifest gone, RORY dimmed and unlit", s.tform.is_empty() and main_node.hud.text.contains(">>> COMEDOWN ") and main_node.hud.text.contains("COMEDOWN  RORY - 10s at 85%") and main_node.manifest_fig == null and not pm2.emission_enabled, s.zone_line())
			if s.comedown.size() > 0: _run(s, int(s.comedown["t"]))
		24:
			_check("10 s on: himself again, no line", s.comedown.is_empty() and not main_node.hud.text.contains("COMEDOWN") and not main_node.hud.text.contains("MANIFEST "), "")
		27:
			print("MANIFEST DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 6 - fails.size(), 6])
			quit(0 if fails.is_empty() else 1)
	return false

func TNBSim_ms(v: float) -> int:
	return main_node.sim.ms(v)

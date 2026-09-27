extends SceneTree
# TRUE NORTH BOXING - the Manifest Clash on the real scene, headless (PAC-086).
#   godot --headless --path engine/greybox -s tools/drive_clash.gd -- boss=19 "btransform=manifest@composure<80" level=RORY:20 flag=story:provincials_semifinal,story:manifest:RORY
# Loads the real scene against Moira MacIsaac with the greybox aid's TRANSFORM line on her page (her Manifest at 80 % composure; Vasile's own
# line untouched) and RORY's Manifest unlocked. Her composure under 80 %: she gathers, then ENEMY MANIFEST - the toast, her figure behind
# her. H + Y (the keyboard's SURGE) with the bar topped up: RORY's Manifest; after the hold the fight stops - MANIFEST CLASH, the toast, the
# mode line, the cue line, both figures up. The five exchanges played on the keys in their windows (SPACE on hers, J on his): CLASH WON 5 of
# 5 - her manifest suppressed into ENEMY COMEDOWN, her figure gone, RORY's manifest still up, five weatherings, the fight clock where it was.
# Exit 0 = every step did what the keys and the Clash say.
var main_node: Node
var f := 0
var fails: Array = []
var phase := ""
var pressed := -1
var clock0 := 0
var clock1 := 0
var held := false

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _key(code: Key, down: bool, held_: bool) -> void:
	# held: the Input singleton's state, as a held key is (it lands on the next frame); else an event the scene reads
	var k := InputEventKey.new(); k.keycode = code; k.pressed = down
	if held_: Input.parse_input_event(k)
	else: root.push_input(k)

func _quiet(s) -> void:
	s.hooks_enabled = false; s.coach_on = false; s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}; s.neutral_on = false

func _fight(s, n: int) -> void:
	# fight time stepped through the sim with nobody pressing anything, her state left as it is, the scene's events consumed
	for i in n:
		if s.mode != "FIGHT": break
		s.step({})
	main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	if phase == "clash":
		# the exchanges on the keys: inside each cue's window, SPACE (held, an edge) on hers, J on his; SPACE let go once hers is past
		if s.mode == "CLASH":
			var i: int = int(s.mclash["i"])
			if held and i != pressed: _key(KEY_SPACE, false, true); held = false
			if i < s.mclash["cues"].size() and i != pressed and int(s.mclash["t"]) >= int(s.mclash["cues"][i]) - 12:
				pressed = i
				if str(s.mclash["kinds"][i]) == "defend": _key(KEY_SPACE, true, true); held = true
				else: _key(KEY_J, true, false); _key(KEY_J, false, false)
		else:
			if held: _key(KEY_SPACE, false, true); held = false
			clock1 = s.clock_t; main_node._consume_events(); phase = "after"; f = 100
		if f > 20000: _check("the Clash ended", false, "never"); phase = "after"; f = 100
		return false
	match f:
		4:
			_quiet(s)
			var tf: Dictionary = s.pattern.get("transform", {})
			_check("R1 RORY (his Manifest unlocked) against Moira MacIsaac: the aid's TRANSFORM line on her page (the Manifest at composure<80, the 1000 ms floor), Vasile's own untouched", s.pname() == "RORY" and s.transform_tier("RORY") == "manifest" and s.boss_name == "moira_macisaac" and str(tf.get("tier", "")) == "manifest" and bool(tf.get("aid", false)) and int(tf["tell"]["ms"]) == 1000 and str(main_node.content["patterns"]["ioan_vasile"]["transform"]["tier"]) == "zone" and not bool(main_node.content["patterns"]["ioan_vasile"]["transform"].get("aid", false)), JSON.stringify(tf))
			s.B["comp"] = s.B["comp_max"] * 0.79; s.step({}); main_node._consume_events()
			_fight(s, int(s.btsurge.get("t", 0))); _quiet(s)
		6:
			var fig: Node3D = main_node.bmanifest_fig
			var behind: bool = fig != null and fig.position.distance_to(main_node.player.position) > main_node.boss.position.distance_to(main_node.player.position)
			_check("under 80 %: she gathers, then ENEMY MANIFEST - the toast, the hold, her figure behind her", str(s.btform.get("tier", "")) == "manifest" and hud.contains("ENEMY MANIFEST  moira_macisaac - 30s  - moira_macisaac's manifest") and behind, s.bzone_line())
			_fight(s, s.freeze_t + 30); s.tension = 100.0; _key(KEY_H, true, true)
		8: _key(KEY_Y, true, false)
		12:
			_key(KEY_H, false, true)
			_check("H + Y with the bar full: RORY's Manifest - the whole bar, the camera hold", str(s.tform.get("tier", "")) == "manifest" and s.tension == 0.0 and s.freeze_t > 0, "hold %d" % s.freeze_t)
			_fight(s, s.freeze_t + 5)
		14:
			_check("after the hold the fight stops: MANIFEST CLASH - the toast, the mode line, the cue line, both figures up", s.mode == "CLASH" and hud.contains("MANIFEST CLASH  RORY's manifest against moira_macisaac's manifest - 5 exchanges: block or slip on the enemy's, punch on yours") and hud.contains(">>> MANIFEST CLASH - the fight waits") and hud.contains("MANIFEST CLASH 1/5 | BLOCK or SLIP in ") and main_node.manifest_fig != null and main_node.bmanifest_fig != null, s.bzone_line())
			clock0 = s.clock_t; phase = "clash"
		103:
			_check("the five exchanges on the keys in their windows: CLASH WON 5 of 5 - her manifest suppressed into ENEMY COMEDOWN, her figure gone, RORY's manifest still up, five weatherings, the fight clock where it was", s.mode == "FIGHT" and hud.contains("CLASH WON  5 of 5 - your manifest suppresses the enemy's   ENEMY COMEDOWN  moira_macisaac - 10s at 85% - YOUR WINDOW - suppressed in the Clash (weathered 5)") and hud.contains(">>> ENEMY COMEDOWN ") and s.btform.is_empty() and s.bcomedown.size() > 0 and main_node.bmanifest_fig == null and main_node.manifest_fig != null and str(s.tform.get("tier", "")) == "manifest" and main_node.weathered_seen == 5 and absi(clock1 - clock0) <= 3, "%s | clock %d -> %d | %s" % [s.bzone_line(), clock0, clock1, JSON.stringify(main_node.clashes_seen)])
		106:
			print("MANIFEST CLASH DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 5 - fails.size(), 5])
			quit(0 if fails.is_empty() else 1)
	return false

extends SceneTree
# TRUE NORTH BOXING - the enemy's transformation on the real scene, headless (PAC-086).
#   godot --headless --path engine/greybox -s tools/drive_bzone.gd -- boss=16
# Loads the real scene against Ioan Vasile (his TRANSFORM line compiled on his page). His composure taken under 50 %: GATHERING - his line
# on the HUD and in the toast, the swell, the glow starting, his guard up; 1.5 s of fight time on, the camera hold and ENEMY ZONE's toast,
# his bar emptied, the boss lit in his element; the HUD's ENEMY ZONE clock; E (the keyboard's slip) as his straight comes: WEATHERED -
# 1 s off, the damage halved, the toast; run to its end unanswered and never down: ENEMY COMEDOWN's toast with STOOD IN THE STORM beside
# it, the HUD's window line, the boss unlit and dimmed, the feat on the ledger; 10 s on, the window shut and his colour back.
# Exit 0 = every step did what the keys and his line say.
var main_node: Node
var f := 0
var fails: Array = []
var lum0 := 0.0
var col_back := false

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

func _fight(s, n: int) -> void:
	# fight time stepped through the sim with nobody pressing anything, his state left as it is, the scene's events consumed
	for i in n:
		if s.mode != "FIGHT": break
		s.step({})
	main_node._consume_events()

func _bmat() -> StandardMaterial3D:
	return main_node.boss.get_meta("mat")

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_quiet(s); lum0 = _bmat().albedo_color.get_luminance()
			_check("R1 RORY against Ioan Vasile: his TRANSFORM line on his page (the Zone at composure<50, a 1.5 s tell), no enemy line on the HUD, the boss unlit", s.pname() == "RORY" and s.boss_name == "ioan_vasile" and str(s.pattern.get("transform", {}).get("tier", "")) == "zone" and int(s.pattern["transform"]["tell"]["ms"]) == 1500 and not hud.contains("GATHERING") and not hud.contains("ENEMY ") and not _bmat().emission_enabled, JSON.stringify(s.pattern.get("transform", {})))
			s.B["comp"] = s.B["comp_max"] * 0.49; s.step({}); main_node._consume_events()
		6:
			var rx := RegEx.new(); rx.compile("GATHERING 1\\.[0-5]s \\| VEY: he has stopped breathing out loud")
			_check("under 50 %: he gathers - the HUD's GATHERING line with his line, the toast, the glow starting, his guard up, no attack", rx.search(hud) != null and hud.contains("GATHERING  ioan_vasile - VEY: he has stopped breathing out loud - that is his Zone coming. Weather it.") and _bmat().emission_enabled and s.bstate == "SURGE" and int(s.B["guard_t"]) > 0, s.bzone_line())
			_fight(s, int(s.btsurge.get("t", 0)))
			_quiet(s)
		8:
			_check("1.5 s of fight time on: the camera hold, ENEMY ZONE's toast, his bar emptied, the boss lit in his element", str(s.btform.get("tier", "")) == "zone" and s.freeze_t > 0 and s.btension == 0.0 and hud.contains("ENEMY ZONE  ioan_vasile - 20s - weather it: a perfect block or a slip takes 1s off and halves the damage") and _bmat().emission_enabled, "hold %d ticks left" % s.freeze_t)
			_fight(s, s.freeze_t + 60)
		10:
			var rx2 := RegEx.new(); rx2.compile("ENEMY ZONE 19\\.[2-5]s \\| weathered 0 \\(-0\\.0s\\)")
			_check("after the hold: the HUD's ENEMY ZONE line on fight time, nothing weathered yet", rx2.search(hud) != null and s.freeze_t == 0, s.bzone_line())
			# Launch a real threatened exchange; an out-of-range legacy hit
			# call cannot award weathering merely because a dodge flag is set.
			s.P["pos"] = Vector2(0,0.75); s.B["pos"] = Vector2(0,-0.75)
			for fighter in [s.P,s.B]: fighter.erase("body_control"); fighter.erase("boxing")
			_key(KEY_C,true,false); _key(KEY_SPACE,true,false)
			for i in 30: s.step(main_node._intent())
			s._boss_act({"kind":"punch","row":"R_STRAIGHT","mult":1.0,"body":false}); s.btimer = 1<<30
			_key(KEY_D,true,false)
		12:
			for i in 90:
				s.step(main_node._intent()); main_node._consume_events()
				if s.B["pending"].is_empty(): break
			var slipping: bool = Vector2(s.P["body_control"]["axis"]).x > 0.5
			_key(KEY_D,false,false); _key(KEY_C,false,false); _key(KEY_SPACE,false,false)
			if not slipping: fails.append("the slip was not live when his straight came")
		14:
			var rx3 := RegEx.new(); rx3.compile("\\| weathered 1 \\(-1\\.0s\\) \\| damage to you halved")
			_check("continuous slip evades the committed straight: WEATHERED - 1 s off his Zone, the toast, the HUD's line", int(s.btform.get("weathered", 0)) == 1 and hud.contains("WEATHERED  -1.0s") and hud.contains("- the damage to you halved") and rx3.search(hud) != null and main_node.weathered_seen == 1, s.bzone_line())
			_quiet(s); _fight(s, int(s.btform.get("t", 0)) + 5)
		16:
			var ft: Dictionary = s.rewards.get("feats", {}).get("stood_in_the_storm", {})
			_check("run to its end unanswered and never down: ENEMY COMEDOWN's toast with STOOD IN THE STORM beside it, the HUD's window line, the boss unlit and dimmed, the feat on the ledger", s.btform.is_empty() and s.bcomedown.size() > 0 and hud.contains("ENEMY COMEDOWN  ioan_vasile - 10s at 85% - YOUR WINDOW (weathered 1)") and hud.contains("STOOD IN THE STORM  RORY weathered ioan_vasile's transformation unanswered (x1)") and hud.contains(">>> ENEMY COMEDOWN ") and not _bmat().emission_enabled and _bmat().albedo_color.get_luminance() < lum0 - 0.01 and int(ft.get("count", 0)) == 1, "%s | %s" % [s.bzone_line(), JSON.stringify(ft)])
			_fight(s, int(s.bcomedown.get("t", 0)) + 2); _quiet(s)
			col_back = _bmat().albedo_color.is_equal_approx(main_node._base_color("B"))                    # read as the window shuts (his phase 2 may swap his kit, and his element with it)
		18:
			_check("10 s on: the window shut - no enemy line, the boss's colour back", s.bcomedown.is_empty() and not hud.contains(">>> ENEMY ") and not hud.contains("GATHERING") and col_back, "")
		21:
			print("ENEMY TRANSFORMATION DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 7 - fails.size(), 7])
			quit(0 if fails.is_empty() else 1)
	return false

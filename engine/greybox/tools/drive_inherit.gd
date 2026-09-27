extends SceneTree
# TRUE NORTH BOXING - Inheritance on the real scene, headless (PAC-084).
#   godot --headless --path engine/greybox -s tools/drive_inherit.gd -- format=sanctioned kizuna=RORY+SAM:150
# Loads the real scene: the sanctioned eight, RORY out first and Sworn with SAM (the command line's seed), SAM dressed. H + Y (the keyboard's
# SURGE) with the bar topped up casts Inheritance: the toast names House Tagaq and SAM; after the camera hold the HUD's INHERITANCE line,
# SAM's ghost-frame over RORY and SAM at the apron; H + I (LB + a hook: ARC) arms SAM's Sorry Eh from the inherited meter, the team bar
# untouched; 25 s of fight time on the Comedown's line and toast with RORY's dialect scrambled, the figures gone; 10 s more, himself.
# Exit 0 = every step did what the keys and the Inheritance say.
var main_node: Node
var f := 0
var fails: Array = []
var bar0 := 0.0
var m_cost := 0.0

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

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	match f:
		4:
			_quiet(s)
			_check("R1 RORY Sworn with SAM: Inheritance his highest tier, SAM of House Tagaq his source, no line, no figure", s.pname() == "RORY" and s.transform_tier("RORY") == "inheritance" and str(s.inherit_source("RORY").get("source", "")) == "SAM" and not main_node.hud.text.contains("INHERITANCE ") and main_node.inherit_fig == null, JSON.stringify(s.inherit_sources("RORY")))
		5: s.tension = 100.0; _key(KEY_H, true, true)
		7: _key(KEY_Y, true, false)
		12:
			_key(KEY_H, false, true)
			_check("H + Y with the bar full: the SURGE casts Inheritance - the whole bar gone, the toast naming House Tagaq and SAM, the camera hold", s.tform.get("tier", "") == "inheritance" and s.tension == 0.0 and s.freeze_t > 0 and main_node.hud.text.contains("INHERITANCE  RORY - the whole bar (100)  - House Tagaq from SAM (Sworn)"), "hold %d ticks left" % s.freeze_t)
			_run(s, s.freeze_t + 120)
		15:
			var rx := RegEx.new(); rx.compile("INHERITANCE (24\\.0|23\\.9|23\\.8)s \\| House Tagaq from SAM \\(Sworn\\) \\| Never Twice \\| meter 50/50 \\| Sorry Eh, Still Water \\| the enemy misreads you")
			var gf: Node3D = main_node.inherit_fig; var af: Node3D = main_node.apron_fig
			var over: bool = gf != null and gf.position.distance_to(main_node.player.position) < 0.01
			var apron: bool = af != null and absf(absf(af.position.x) - (s.RING_HALF + 0.6)) < 0.01
			_check("after the hold: the HUD's INHERITANCE line, SAM's ghost-frame over RORY, SAM at the apron", rx.search(main_node.hud.text) != null and over and apron, s.zone_line())
			_quiet(s); s.P["busy_t"] = 0; s.P["cmd"] = {}; bar0 = s.tension; m_cost = s.hiss_cost(s.library["Sorry Eh"])
			_key(KEY_H, true, true)
		17: _key(KEY_I, true, false)
		21:
			_key(KEY_H, false, true)
			var armed: bool = s.cast.size() > 0 and str(s.cast["move"].get("name", "")) == "Sorry Eh" and str(s.cast["move"].get("inherited_from", "")) == "SAM"
			var paid: bool = absf(float(s.tform.get("meter", 0.0)) - (50.0 - m_cost)) < 0.01 and s.tension == bar0
			_check("H + I (LB + ARC): SAM's Sorry Eh armed from the inherited meter, the team bar untouched, the HUD's meter down", (armed or main_node.fx_counts.get("cast", 0) > 0) and paid and main_node.hud.text.contains("| meter %d/50 |" % int(50.0 - m_cost)), "meter %.1f, bar %.1f" % [float(s.tform.get("meter", 0.0)), s.tension])
			if s.cast.size() > 0: _run(s, int(s.cast["t"]) + 60)
			if s.tform.size() > 0: _run(s, int(s.tform["t"]))
		25:
			var pm: StandardMaterial3D = main_node.player.get_meta("mat")
			_check("25 s of fight time on: the Comedown's line and toast with RORY's own dialect scrambled, the figures gone, RORY unlit", s.tform.is_empty() and main_node.hud.text.contains(">>> COMEDOWN ") and main_node.hud.text.contains("| own dialect scrambled ") and main_node.hud.text.contains("COMEDOWN  RORY - 10s at 85%, own dialect scrambled 10s") and main_node.inherit_fig == null and main_node.apron_fig == null and not pm.emission_enabled, s.zone_line())
			if s.comedown.size() > 0: _run(s, maxi(int(s.comedown["t"]), int(s.comedown.get("scramble_t", 0))))
		29:
			_check("10 s on: himself again, no line", s.comedown.is_empty() and not main_node.hud.text.contains("COMEDOWN") and not main_node.hud.text.contains("INHERITANCE "), "")
		32:
			print("INHERITANCE DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 6 - fails.size(), 6])
			quit(0 if fails.is_empty() else 1)
	return false

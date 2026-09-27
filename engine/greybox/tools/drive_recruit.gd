extends SceneTree
# TRUE NORTH BOXING - the recruits' keys driven on the real scene, headless (PAC-075).
#   godot --headless --path engine/greybox -s tools/drive_recruit.gd -- boss=1
# Loads the real scene against Yuri's squad, has Millbrook win the dual on segments (the sim's own segment end, no fight), then presses
# P before any approach (refused: nobody is ready), L (the conditions surface on the HUD), P (the ready join: YURI and SAM), and L again (nobody left).
# PAC-076: the join puts their strings up - the String Wall on the HUD (SAM's students, CHOIR approached through him) and in the toast.
# PAC-077: they arrive UNSANCTIONED - the HOUSES lines show each house's blessing line clause by clause and the two members' standing.
# PAC-078: before the win, the matchup card names Yuri's house trait (Load-Bearing).
# Exit 0 = every step did what the keys say.
var main_node: Node
var f := 0
var fails: Array = []

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _key(k: int) -> void:
	var ev := InputEventKey.new(); ev.keycode = k; ev.pressed = true
	root.push_input(ev)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _win(s) -> void:
	s.hooks_enabled = false; s.coach_on = false
	for i in s.segments():
		s.mode = "FIGHT"; s.eight = {}; s.ep_p += 4; s._end_segment("drive")
		if s.mode == "CARD": s.step({"corner": 1})
		if s.mode == "CORNER": s.step({"corner": 1})

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	match f:
		4: _check("the matchup card names the house trait in play: Yuri's Load-Bearing (PAC-078)", s.mode == "FIGHT" and main_node.hud.text.contains("TRAITS: yuri_kowalchuk Load-Bearing"), "")
		5: _win(s); main_node._consume_events()
		8: _check("the dual won flags the squad", s.mode == "OVER" and s.recruits_open() == ["yuri_kowalchuk", "jean_guy_moreau", "sam_tagaq", "ada_okafor"] and main_node.hud.text.contains(">>> RECRUITS"), str(s.recruits_open()))
		10: _key(KEY_P)
		14: _check("P before an approach recruits nobody", s.stable.size() == 4 and main_node.feed.text == "nobody is ready", main_node.feed.text)
		16: _key(KEY_L)
		20: _check("L surfaces the conditions on the HUD", s.recruit_state("yuri_kowalchuk") == "approached" and main_node.hud.text.contains("BEAT_IN(dual[segment]) 1/1 ok") and main_node.hud.text.contains(">> READY"), "")
		22: _key(KEY_P)
		26: _check("P recruits the ready: YURI and SAM (each beaten in his segment) join, ADA waits on her bond and her quest, JEAN-GUY on Q-MOREAU", s.recruit_state("yuri_kowalchuk") == "joined" and s.recruit_state("sam_tagaq") == "joined" and s.recruit_state("ada_okafor") == "approached" and s.recruit_state("jean_guy_moreau") == "approached" and s.stable.size() == 6 and main_node.hud.text.contains("JOINS THE STABLE (6 cards)"), str(s.stable.map(func(x): return x["name"])))
		27: _check("their strings go up: the String Wall on the HUD (SAM's junior a lead, CHOIR approached through him, both houses) and in the toast", main_node.hud.text.contains(">>> STRING WALL  (8 of 43 cards up)") and main_node.hud.text.contains("CHOIR [approached <- SAM]") and main_node.hud.text.contains("THE JUNIOR [lead <- SAM]") and main_node.hud.text.contains("HOUSE KOWALCHUK [unblessed <- YURI]") and main_node.hud.text.contains("STRING WALL  SAM -> THE JUNIOR, CHOIR, HOUSE TAGAQ") and s.recruit_state("hc9_choir") == "approached", "")
		28:
			_check("they arrive UNSANCTIONED: the HOUSES lines on the HUD - Kowalchuk's line with the segment won against Yuri met and the patriarch's witness to come, Tagaq's waiting on Sam's bond", s.house_status("YURI") == "UNSANCTIONED" and s.house_status("SAM") == "UNSANCTIONED" and main_node.hud.text.contains(">>> HOUSES") and main_node.hud.text.contains("KOWALCHUK [unblessed] BEAT_IN(dual[segment]) 1/1 ok AND WITNESS(patriarch attends a home dual) 0/1  | YURI UNSANCTIONED") and main_node.hud.text.contains("TAGAQ [unblessed] BOND(Sam, 3) 0/3 AND WITNESS(win a dual without your crowd-heat actives) 0/1  | SAM UNSANCTIONED"), "")
			_key(KEY_L)
		32: _check("L again: nobody left to approach", main_node.feed.text == "nobody to approach", main_node.feed.text)
		35:
			print("RECRUIT DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 8 - fails.size(), 8])
			quit(0 if fails.is_empty() else 1)
	return false

extends SceneTree
# TRUE NORTH BOXING - hybrid research on the real scene, headless (PAC-087).
#   godot --headless --path engine/greybox -s tools/drive_forge.gd -- format=sanctioned kizuna=YURI+MARTA:150 purse=spirits:40,beans:30 facility=wall:3 board=YURI,MARTA,RORY,PRIYA,SAM
# (since PAC-089 the Forge is hosted at The Wall's T3 - NP_10 s7 - so the command line seeds the tier)
# Loads the real scene: the sanctioned five sealed YURI, MARTA, RORY, PRIYA, SAM, YURI and MARTA Sworn (the command line's seeds), the
# ledger's purse 40 Spirits and 30 Beans. No FORGE lines while the dual is on. Millbrook wins the dual on segments (the sim's own segment
# end, no fight); on the DUAL OVER screen the FORGE lines name YURI & MARTA's hybrid and its price; F forges it - the toast, the registry
# line, the purse down. F5, the next dual: R1 YURI carries no hybrid line; R2 MARTA, relayed from YURI - the matchup card's HYBRID line;
# H + ; (LB + the keyboard's hookercut: HAYMAKER) with the bar full casts Grain & Snow - the toast, YURI's afterimage in both elements;
# resolved, it hits and the registry counts its debut. Exit 0 = every step did what the keys and the Forge say.
var main_node: Node
var f := 0
var fails: Array = []
var comp0 := 0.0
var cost := 0.0

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
			_check("R1 YURI of the sealed five, YURI & MARTA Sworn, the purse seeded; no FORGE lines while the dual is on", s.pname() == "YURI" and s.kizuna_level("YURI", "MARTA") == 5 and int(s.rewards.get("spirits", 0)) == 40 and int(s.rewards.get("beans", 0)) == 30 and not hud.contains(">>> FORGE") and s.hybrid_registry().is_empty(), "")
			s.hooks_enabled = false; s.coach_on = false
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		8:
			var sp: int = int(s.rewards.get("spirits", 0))
			_check("the dual won: DUAL OVER, the FORGE lines - YURI & MARTA's Grain & Snow and its price, the purse on the screen", s.mode == "OVER" and hud.contains(">>> FORGE  [F] the first pair ready  (Spirits %d, Beans 30)" % sp) and hud.contains("YURI & MARTA -> Grain & Snow: [F] 40 Spirits, 30 Beans"), "Spirits %d" % sp)
			_key(KEY_F, true, false)
		12:
			var ok_reg: bool = s.hybrid_registry().size() == 1 and str(s.hybrid_registry()[0]["name"]) == "Grain & Snow"
			_check("F forges it: the toast, the registry line 1 of 8, 40 Spirits and 30 Beans off the ledger", ok_reg and hud.contains("FORGED  GRAIN & SNOW - YURI & MARTA (House Kowalchuk x House Tremblay): 40 Spirits, 30 Beans - hybrid 1 of 8") and hud.contains("forged 1 of 8: Grain & Snow (MARTA & YURI)") and int(s.rewards.get("beans", 0)) == 0 and main_node.forged_seen == ["Grain & Snow (MARTA&YURI)"], "")
			_key(KEY_F5, true, false)
		16:
			_quiet(s)
			_check("F5, the next dual: R1 YURI - his partner has not fought, no HYBRID line", s.mode == "FIGHT" and s.pname() == "YURI" and s.hybrid_move().is_empty() and not hud.contains("HYBRID:"), "")
			_seg_won(s); main_node._consume_events()
		19:
			_quiet(s)
			cost = s.hiss_cost(s.hybrid_move())                                                          # 50, the element edge's x0.9 where MARTA's Frost beats his element (NP_06 s2.1)
			_check("R2 MARTA, relayed from YURI: the matchup card's HYBRID line, priced", s.pname() == "MARTA" and hud.contains("HYBRID: Grain & Snow (LB + HAYMAKER, %d) - relayed from YURI - YURI's afterimage joins, x1.25" % int(cost)), s.hybrid_line())
			s.tension = 100.0; s.P["busy_t"] = 0; s.P["cmd"] = {}; comp0 = float(s.B["comp"]); _key(KEY_H, true, true)
		21: _key(KEY_SEMICOLON, true, false)
		25:
			_key(KEY_H, false, true)
			var armed: bool = s.cast.size() > 0 and str(s.cast["move"].get("name", "")) == "Grain & Snow" and str(s.cast["move"].get("hybrid_live", "")) == "relayed"
			var g: Node3D = main_node.ghost
			var tint_ok := false
			if g != null:
				var gm: StandardMaterial3D = g.get_meta("mat")
				tint_ok = gm.emission_enabled and gm.emission.is_equal_approx(main_node.ELEMENT_TINT["FROST"].lerp(main_node.ELEMENT_TINT["GRANITE"], 0.5))
			_check("H + ; (LB + HAYMAKER) with the bar full: Grain & Snow armed relayed - the toast, YURI's afterimage in both elements, its price off the bar", (armed or main_node.hybrid_casts.size() > 0) and hud.contains("HYBRID  GRAIN & SNOW  MARTA - relayed from YURI: the afterimage joins, x1.25") and tint_ok and absf(s.tension - (100.0 - cost)) < 0.001, "%s, tint %s, bar %.1f" % [JSON.stringify(main_node.hybrid_casts), str(tint_ok), s.tension])
			_quiet(s)
			var n := 0
			while s.cast.size() > 0 and n < 600: s.step({}); n += 1
			main_node._consume_events()
		28:
			var rec: Dictionary = s.hybrid_of_pair("YURI", "MARTA")
			_check("resolved: it hits, and the registry counts its first cast in a dual (its debut)", float(s.B["comp"]) < comp0 and int(rec.get("casts", 0)) == 1 and int(rec.get("debut_day", 0)) >= 1 and main_node.fx_counts.get("hybrid_debut", 0) == 1, "composure %.1f -> %.1f" % [comp0, float(s.B["comp"])])
		31:
			print("FORGE DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 7 - fails.size(), 7])
			quit(0 if fails.is_empty() else 1)
	return false

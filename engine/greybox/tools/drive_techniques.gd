extends SceneTree
# TRUE NORTH BOXING - techniques and the slots on the real scene, headless (PAC-091).
#   godot --headless --path engine/greybox -s tools/drive_techniques.gd -- level=RORY:15,PRIYA:5 purse=hbp:1000 flag=story:regionals,quest:coach_questline tapes=Black Ice:1 facility=bags:1
# Loads the real scene with the ledger the command line seeds (RORY at 15: two technique slots and the T0 slot; PRIYA at 5; 1,000 HBP; the
# Regionals open the shop's second shelf; the coach questline; a Black Ice tape; Bags & Mitts at T1 for the training slots). RORY walks
# out with no kit. Millbrook wins the dual on segments (the sim's own segment end, no fight); on DUAL OVER the TECHNIQUES lines name
# RORY's own move, his T0 slot, his slots and kit, the shop's next buy, the lesson open and the tape. [ buys the shop's pick into his
# kit; ] takes Whitlock's Timberfall; ' spends the Black Ice tape into his T0 slot; [.] then / re-teaches PRIYA RORY's bought move in a
# training slot; - and = put it down and carry it again. F5, the next dual: the matchup card's KIT line, and H + K (LB + the straight,
# PISTON) casts Black Ice from his kit - his own Aurora Borealis Breaker is a HAYMAKER.
# Exit 0 = every step did what the keys and the TECHNIQUES lines say.
var main_node: Node
var f := 0
var fails: Array = []
var hbp0 := 0
var pick := ""
var cost := 0.0

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
			_check("the bell: RORY walks out with no kit, no KIT line, no TECHNIQUES lines in the fight", s.pname() == "RORY" and not s.P.has("kit") and not hud.contains("KIT: RORY") and not hud.contains(">>> TECHNIQUES"), "")
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		8:
			hbp0 = int(s.rewards.get("hbp", 0)); pick = s.buy_best("RORY")
			_check("the dual won: DUAL OVER, the TECHNIQUES lines - RORY's own move, the T0 slot open, 0 of 2 slots, the shop's pick, Timberfall's lesson, the tape", s.mode == "OVER" and hud.contains(">>> TECHNIQUES  [ buy  ] lesson  ' tape  / re-teach  = carry  - put down  (HBP %d)" % hbp0) and hud.contains("RORY L15: own Aurora Borealis Breaker; T0 open; slots 0 of 2; kit -") and hud.contains("[ buy: %s (t2, 400 HBP)" % pick) and hud.contains("] lesson: Timberfall from WHITLOCK") and hud.contains("' tape: {\"Black Ice\":1}"), "HBP %d, the pick %s" % [hbp0, pick])
			_key(KEY_BRACKETLEFT)
		12:
			_check("[ buys it: 400 HBP off the ledger, learned from the shop, straight into his kit - the toast", s.learned("RORY").get(pick, "") == "shop" and s.kit_moves("RORY") == [pick] and int(s.rewards.get("hbp", 0)) == hbp0 - 400 and hud.contains("LEARNED  RORY - %s (T1 " % pick) and hud.contains("from the shop") and hud.contains("- in the kit (%s)" % pick), JSON.stringify(s.learned("RORY")))
			_key(KEY_BRACKETRIGHT)
		16:
			_check("] takes Whitlock's Timberfall (the coach questline) - free, the second slot filled", s.learned("RORY").get("Timberfall", "") == "master:WHITLOCK" and s.kit_moves("RORY") == [pick, "Timberfall"] and int(s.rewards.get("hbp", 0)) == hbp0 - 400 and hud.contains("LEARNED  RORY - Timberfall (T1 RISE) from WHITLOCK"), JSON.stringify(s.kit_moves("RORY")))
			_key(KEY_APOSTROPHE)
		20:
			_check("' spends the Black Ice tape into his T0 slot - the tape gone, the line's kit three", s.learned("RORY").get("Black Ice", "") == "tape" and s.kit_moves("RORY") == [pick, "Timberfall", "Black Ice"] and s.tapes().is_empty() and hud.contains("RORY L15: own Aurora Borealis Breaker; T0 Black Ice; slots 2 of 2; kit %s, Timberfall, Black Ice" % pick), JSON.stringify(s.tapes()))
			_key(KEY_PERIOD)
		22: _key(KEY_SLASH)
		26:
			_check("[.] then / re-teaches PRIYA RORY's %s in a training slot (1 of 3) - RORY keeps it" % pick, s.learned("PRIYA").get(pick, "") == "taught:RORY" and s.learned("RORY").has(pick) and s.kit_moves("PRIYA") == [pick] and s.training_used() == 1 and hud.contains("LEARNED  PRIYA - %s (T1 " % pick) and hud.contains("from a re-teach by RORY") and main_node.fx_counts.get("retaught", 0) == 1, JSON.stringify(s.learned("PRIYA")))
			_key(KEY_MINUS)
		28:
			_check("- puts it down: PRIYA's kit empty, still learned", s.kit_moves("PRIYA").is_empty() and s.learned("PRIYA").has(pick) and hud.contains("THE KIT  PRIYA puts %s down (still learned)" % pick), "")
			_key(KEY_EQUAL)
		30:
			_check("= carries it again: PRIYA's kit, the toast", s.kit_moves("PRIYA") == [pick] and hud.contains("THE KIT  PRIYA carries %s - in the kit (%s)" % [pick, pick]), "")
			_key(KEY_F5)
		34:
			_quiet(s)
			_check("F5, the next dual: RORY walks out with his kit - the matchup card's KIT line", s.mode == "FIGHT" and s.pname() == "RORY" and s.P.get("kit", []) == [pick, "Timberfall", "Black Ice"] and hud.contains("KIT: RORY - %s (LB + %s), Timberfall (LB + RISE), Black Ice (LB + PISTON)" % [pick, str(s.library[pick]["family"])]), JSON.stringify(s.P.get("kit", [])))
			s.tension = 100.0; s.P["busy_t"] = 0; s.P["cmd"] = {}; s.freeze_t = 0; cost = s.hiss_cost(s.library["Black Ice"]); _key(KEY_H, true, true)
		36: _key(KEY_K)
		40:
			_key(KEY_H, false, true)
			var mv := str(s.cast["move"].get("name", "")) if s.cast.size() > 0 else ""
			_check("H + K (LB + the straight, PISTON) casts Black Ice from his kit - its price off the bar", (mv == "Black Ice" or main_node.kit_casts.has("RORY Black Ice")) and absf(s.tension - (100.0 - cost)) < 0.001, "%s, bar %.1f (%.1f), kit casts %s" % [mv, s.tension, cost, JSON.stringify(main_node.kit_casts)])
		42:
			print("TECHNIQUES DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 10 - fails.size(), 10])
			quit(0 if fails.is_empty() else 1)
	return false

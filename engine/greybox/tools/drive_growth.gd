extends SceneTree
# TRUE NORTH BOXING - the fighter's growth on the real scene, headless (PAC-090).
#   godot --headless --path engine/greybox -s tools/drive_growth.gd -- level=RORY:10,PRIYA:10 purse=spirits:40,beans:20 beans=PWR:6 facility=film:2 growth=RORY:trial:spar_won
# Loads the real scene with the ledger the command line seeds (RORY and PRIYA at level 10, 20 untyped Beans and 6 PWR in the jar, the
# Film Room at T2, RORY's spar won). RORY walks out on his card. Millbrook wins the dual on segments (the sim's own segment end, no
# fight); on DUAL OVER the GROWTH lines name each card's level, rarity, cap, Board Points and the node the aid would take. N takes it
# (the craft lobe's first +2), N again Tight Guard; Z raises PWR on the PWR Beans; X ascends RORY to Circuit (10 Spirits, the trial met);
# Shift+N respecs at the Film Room (every point back) and N, N take the road to Tight Guard again. F5, the next dual: RORY walks out on
# the grown PWR with Tight Guard on him (the matchup card's PASSIVES line). Won again, [.] and [M]: PRIYA's mirror spar - PRIYA out against her own card.
# Exit 0 = every step did what the keys and the GROWTH lines say.
var main_node: Node
var f := 0
var fails: Array = []
var sp0 := 0

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _key(code: Key, shift: bool = false) -> void:
	var k := InputEventKey.new(); k.keycode = code; k.pressed = true; k.shift_pressed = shift
	root.push_input(k)

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
			_check("the bell: RORY walks out on his card's stats, no passives on him, no GROWTH lines in the fight", s.pname() == "RORY" and s.P["stats"] == s._club_card("RORY")["stats"] and not s.P.has("passives") and not hud.contains(">>> GROWTH"), JSON.stringify(s.P["stats"]))
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		8:
			sp0 = int(s.rewards.get("spirits", 0))
			_check("the dual won: DUAL OVER, the GROWTH lines - the jar by type, RORY's level, rarity, cap, points and the aid's next node", s.mode == "OVER" and hud.contains(">>> GROWTH  [N] a node  [Shift+N] respec  [Z] raise  [X] ascend  [M] the mirror  [.] next  (the jar: PWR 6, 20 untyped; Spirits %d)" % sp0) and hud.contains("> RORY L10 Club (T1, cap 70): board 0 of 20 pts, 0 nodes - next [N] +2 PWR; raises none; Circuit: 10 Spirits + win a spar (done)"), "Spirits %d" % sp0)
			_key(KEY_N)
		10: _key(KEY_N)
		14:
			_check("N, N: the craft lobe's +2 PWR, then Tight Guard - the toast, 4 of 20 points spent, the passive on the line", s.passives_of("RORY") == ["tight_guard"] and hud.contains("THE BOARD  RORY takes Tight Guard (craft, 3 pts; 16 of 20 free)") and hud.contains("> RORY L10 Club (T1, cap 70): board 4 of 20 pts, 2 nodes - Tight Guard"), JSON.stringify(s._grow("RORY")))
			_key(KEY_Z)
		18:
			_check("Z raises PWR on the PWR Beans: +1 -> 48 for 5 (5 PWR, 0 untyped; the next 6), the jar PWR 1", int(s.grown_stats(s._club_card("RORY"))["PWR"]) == 48 and hud.contains("THE JAR  RORY +1 PWR -> 48 for 5 Beans (5 PWR, 0 untyped; the next 6)") and s.jar_text() == "PWR 1, 20 untyped", s.jar_text())
			_key(KEY_X)
		22:
			_check("X ascends RORY to Circuit: 10 Spirits off, the cap to 80, a second accessory slot, a 420 stat total (PAC-096)", s.rarity_of("RORY") == 2 and int(s.rewards.get("spirits", 0)) == sp0 - 10 and hud.contains("ASCENDED  RORY -> CIRCUIT (tier 2): 10 Spirits - growth to 80, 2 accessory slots, a 420 stat total at least") and hud.contains("> RORY L10 Circuit (T2, cap 80)"), "Spirits %d" % int(s.rewards.get("spirits", 0)))
			_key(KEY_N, true)
		26:
			_check("Shift+N respecs at the Film Room (T2): 2 nodes, 4 Board Points back, the board bare", s._grow("RORY")["board"] == [] and hud.contains("RESPEC  RORY at the Film Room - 2 nodes, 4 Board Points back") and s.passives_of("RORY") == [], "")
			_key(KEY_N)
		28: _key(KEY_N)
		32: _key(KEY_F5)
		36:
			var cpw := int(s.rarity_base("RORY", s._club_card("RORY")["stats"])["PWR"])                     # PAC-096: Circuit's 420 lifts his own 384 (PWR 45 -> 52)
			_check("F5, the next dual: RORY walks out on the grown PWR (Circuit's %d +2 +1) with Tight Guard on him - the matchup card's PASSIVES line" % cpw, s.mode == "FIGHT" and s.pname() == "RORY" and cpw == 52 and int(s.P["stats"]["PWR"]) == cpw + 3 and s.P.get("passives", []) == ["tight_guard"] and hud.contains("PASSIVES: RORY - Tight Guard"), JSON.stringify([int(s.P["stats"]["PWR"]), s.P.get("passives", [])]))
			_quiet(s)
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		40: _key(KEY_PERIOD)
		42: _key(KEY_M)
		46:
			_check("[.] then [M]: PRIYA's mirror - a spar, PRIYA out against her own card (generic, her stats)", s.bout.get("kind", "") == "spar" and s.pname() == "PRIYA" and s.boss_label == "PRIYA'S MIRROR" and bool(s.bout["card"].get("generic", false)) and s.B["stats"]["RFX"] == s.P["stats"]["RFX"] and main_node.feed.text.begins_with("THE MIRROR - PRIYA against PRIYA'S MIRROR"), "%s %s %s %s | %s" % [str(s.bout.get("kind", "")), s.pname(), s.boss_label, str(s.bout.get("card", {}).get("generic", false)), main_node.feed.text])
		48:
			print("GROWTH DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 8 - fails.size(), 8])
			quit(0 if fails.is_empty() else 1)
	return false

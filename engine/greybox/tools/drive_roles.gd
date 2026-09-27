extends SceneTree
# TRUE NORTH BOXING - the stable roles on the real scene, headless (PAC-099, NP_08 s1).
#   godot --headless --path engine/greybox -s tools/drive_roles.gd -- purse=prestige:70 flag=story:regionals,story:nationals facility=bags:1
# Loads the real scene with 70 Prestige, the circuit's flags (the machine's generics at tier 3) and Bags & Mitts T1. Millbrook wins the dual on
# segments; DUAL OVER's ROLES lines show an empty bench, and 7 is refused on it. ` seven times feeds the machine seven leads; the days turn to
# the open mat's and Shift+` signs all seven free. 7 eight times: the aid sets the bench - a training partner, a scout for every district
# nobody covers, a cornerman-in-training for the one twice drawn - and the eighth is refused, the whole bench working. T trains RORY at the
# mitts and the training partner goes along unnamed, +2 SPD (70 to his 50); a day turns and the scouts' five districts pay 5 Prestige. F5,
# the next dual won: the cornerman-in-training is a staff use at its end. Shift+7 sends him back to the ring.
# Exit 0 = every step did what the keys and the ROLES lines say.
var main_node: Node
var f := 0
var fails: Array = []
var done := 0
var bench: Array = []

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	done += 1
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

func _win(s) -> void:
	_quiet(s)
	for i in s.segments(): _seg_won(s)
	main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_win(s)
		8:
			_check("the dual won: DUAL OVER's ROLES lines - the bench empty, nothing paid", s.mode == "OVER" and hud.contains(">>> ROLES  7 assign  Shift+7 back to the ring  (day 1)") and hud.contains("THE BENCH: 0 (training 0, scouting 0 districts, in the corner 0) - the roles have paid 0 Prestige, 0 Beans, 0 staff uses"), "stable %d" % s.stable.size())
			_key(KEY_7)
		12:
			_check("7 on an empty bench: refused", main_node.feed.text == "THE ROLES - nobody on the bench without a role (the bench 0)", main_node.feed.text)
			for i in 7: _key(KEY_QUOTELEFT)
		16:
			while not s.open_mat_day(): s.new_day()                                                   # the overworld's days turn to the open mat's
			for i in 7: _key(KEY_QUOTELEFT, true)
		20:
			for c in s.stable:
				if not s._is_dressed(str(c["name"])): bench.append(str(c["name"]))
			_check("` seven times, Shift+` seven on the open-mat day: seven tier-3 generics on the bench, every one a fighter", s.stable.size() == 11 and bench.size() == 7 and s.open_mat().size() == 0 and bench.all(func(nm): return s.stable_role(nm) == "FIGHTER" and int(s._stable_card(nm).get("tier", 0)) == 3) and hud.contains("THE BENCH: 7 (training 0"), JSON.stringify(bench))
			for i in 8: _key(KEY_7)
		24:
			var roles: Array = bench.map(func(nm): return s.stable_role(nm))
			var ds: Array = bench.map(func(nm): return s.home_district(nm))
			var want: Array = []
			var seen: Array = []
			for i in bench.size():
				if i == 0: want.append("TRAINING")
				elif not (ds[i] in seen): want.append("SCOUT"); seen.append(ds[i])
				else: want.append("CORNER_TRAINEE")
			_check("7 eight times: the aid's roles - a training partner, a scout for each district nobody covers, the corner for the one twice drawn; the eighth refused", roles == want and roles.count("CORNER_TRAINEE") >= 1 and main_node.feed.text == "THE ROLES - nobody on the bench without a role (the bench 7)" and hud.contains("THE BENCH: 7 (training 1, scouting %d districts, in the corner %d)" % [roles.count("SCOUT"), roles.count("CORNER_TRAINEE")]) and hud.contains("%s - training partner - PWR 70 at best" % bench[0]), "%s %s" % [JSON.stringify(roles), JSON.stringify(ds)])
			_key(KEY_T)
		28:
			_check("T: RORY at the mitts, the training partner along unnamed - +2 SPD (70 to his 50), 7 Beans", hud.contains("TRAINING  RORY - Mitts, grade 0.75: 7 Beans") and hud.contains("%s the training partner +2 SPD" % bench[0]) and int(s.rewards["roles"]["paid"]["beans"]) == 2, "Beans %d" % int(s.rewards.get("beans", 0)))
			s.new_day(); main_node._consume_events()
		32:
			var nd: int = s.scout_districts().size()
			_check("a day turns: the scouts' districts pay a Prestige each - THE SCOUTS toast", nd == 5 and int(s.rewards["prestige"]) == nd and hud.contains("THE SCOUTS  day %d - +%d Prestige from" % [int(s.rewards["day"]), nd]) and hud.contains("the roles have paid %d Prestige, 2 Beans, 0 staff uses" % nd), "%d districts, Prestige %d" % [nd, int(s.rewards["prestige"])])
			_key(KEY_F5)
		36:
			_win(s)
		40:
			var tr: String = str(s.role_holders("CORNER_TRAINEE")[0]) if s.role_holders("CORNER_TRAINEE").size() > 0 else ""
			_check("F5, the next dual won: the cornerman-in-training a staff use at its end", s.mode == "OVER" and tr != "" and int(s.rewards["roles"]["paid"]["uses"]) == 1 and hud.contains("the roles have paid 5 Prestige, 2 Beans, 1 staff uses") and s.role_text(tr).begins_with("cornerman-in-training - next at"), "%s, staff %s" % [tr, JSON.stringify(s.rewards.get("staff", {}))])
			_key(KEY_7, true)
		44:
			var last: String = bench[bench.size() - 1]
			_check("Shift+7: the last set back to the ring - the toast, the bench line", s.stable_role(last) == "FIGHTER" and hud.contains("ROLE  %s - on the bench" % last) and hud.contains("in the corner 0)"), last)
		46:
			var green: bool = fails.is_empty() and done == 8
			print("ROLES DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 8])
			quit(0 if green else 1)
	return false

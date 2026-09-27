extends SceneTree
# TRUE NORTH BOXING - accessories and gear on the real scene, headless (PAC-094).
#   godot --headless --path engine/greybox -s tools/drive_gear.gd -- purse=hbp:600 flag=story:regionals gear=tape_wraps
# Loads the real scene with the ledger the command line seeds (600 HBP, the Regionals flag - its prize robe in the locker and the gear
# shop's second shelf open - and a roll of Tape Wraps). Millbrook wins the dual on segments (the sim's own segment end, no fight); on
# DUAL OVER the GEAR lines name what RORY wears in his one Club slot, the locker and the shop's next. , puts the best free piece on
# (the Regionals Robe) - the figure wears it; , again is refused on the slot; Shift+, takes it off; \ buys the shop's pick in HBP and ,
# wears it. F5, the next dual: the matchup card's GEAR line, the piece's passive on him and on the figure.
# Exit 0 = every step did what the keys and the GEAR lines say.
var main_node: Node
var f := 0
var fails: Array = []
var done := 0
var hbp0 := 0
var pick := ""

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

func _worn_kinds() -> Array:
	# the pieces the player's figure wears, as [kind, colour]
	var out: Array = []
	for ch in main_node.player.get_children():
		if ch.has_meta("gear") and not ch.is_queued_for_deletion(): out.append([str(ch.get_meta("kind")), (ch.get_meta("color") as Color).to_html(false)])
	return out

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_quiet(s)
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		8:
			hbp0 = int(s.rewards.get("hbp", 0)); pick = s.gear_buy_best("RORY")
			_check("the dual won: DUAL OVER's GEAR lines - RORY's one Club slot empty, the locker (the Regionals' prize, the tape), the shop's pick", s.mode == "OVER" and hud.contains(">>> GEAR  \\ buy  , wear  Shift+, take off  (HBP %d)" % hbp0) and hud.contains("RORY (Club, 1 slot): wears nothing") and hud.contains(", wear: Regionals Robe (personal Tension contribution +2%)   the locker: Regionals Robe, Tape Wraps") and hud.contains("\\ buy: %s (" % s.gear_text(pick)), "HBP %d, the pick %s" % [hbp0, pick])
			_key(KEY_COMMA)
		12:
			_check(", puts the best free piece on: the Regionals Robe - the toast, and the figure wears it (the robe's teal)", s.gear_worn("RORY") == ["regionals_robe"] and hud.contains("GEAR  RORY wears Regionals Robe (personal Tension contribution +2%)") and _worn_kinds() == [["robe", "2a9d8f"]], JSON.stringify(_worn_kinds()))
			_key(KEY_COMMA)
		16:
			_check(", again: refused on the slot - Circuit opens the next", s.gear_worn("RORY") == ["regionals_robe"] and main_node.feed.text == "GEAR - RORY's accessory slots are full (1 of 1) - Circuit opens the next", main_node.feed.text)
			_key(KEY_COMMA, true)
		20:
			_check("Shift+, takes it off - back in the locker, off the figure", s.gear_worn("RORY").is_empty() and hud.contains("GEAR  RORY takes off Regionals Robe - back in the locker") and _worn_kinds().is_empty(), JSON.stringify(_worn_kinds()))
			_key(KEY_BACKSLASH)
		24:
			_check("\\ buys the shop's pick in HBP - into the locker", int(s.gear_owned().get(pick, 0)) == 1 and int(s.rewards.get("hbp", 0)) == hbp0 - int(s.gear_item(pick)["hbp"]) and hud.contains("GEAR  bought %s for %d HBP" % [s.gear_text(pick), int(s.gear_item(pick)["hbp"])]), "HBP %d -> %d" % [hbp0, int(s.rewards.get("hbp", 0))])
			_key(KEY_COMMA)
		28:
			var w: Array = s.gear_worn("RORY")
			_check(", wears the best free piece (%s) - on the figure in its colour" % str(w), w.size() == 1 and _worn_kinds() == [[str(s.gear_item(str(w[0]))["kind"]), str(s.gear_item(str(w[0]))["color"]).substr(1)]], JSON.stringify(_worn_kinds()))
			_key(KEY_F5)
		32:
			var w2: Array = s.gear_worn("RORY")
			var kd: Dictionary = s.GEAR["kinds"][str(s.gear_item(str(w2[0]))["kind"])]
			var want := 1.0 + float(int(kd["dir"])) * float(int(s.gear_item(str(w2[0]))["pct"])) / 100.0
			_check("F5, the next dual: RORY walks out in it - the matchup card's GEAR line, its passive on him, the figure dressed", s.mode == "FIGHT" and s.pname() == "RORY" and s.P.get("gear", []) == w2 and absf(float(s.P["gear_fx"].get(str(kd["key"]), 0.0)) - want) < 0.0001 and hud.contains("GEAR: RORY - %s" % s.gear_text(str(w2[0]))) and _worn_kinds().size() == 1, "%s %s" % [JSON.stringify(s.P.get("gear_fx", {})), JSON.stringify(_worn_kinds())])
		34:
			var green: bool = fails.is_empty() and done == 7
			print("GEAR DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 7])
			quit(0 if green else 1)
	return false

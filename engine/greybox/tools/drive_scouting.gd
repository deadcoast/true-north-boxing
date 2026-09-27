extends SceneTree
# TRUE NORTH BOXING - the scouting machine and the open mat on the real scene, headless (PAC-098).
#   godot --headless --path engine/greybox -s tools/drive_scouting.gd -- purse=prestige:100
# Loads the real scene with 100 Prestige on the ledger. Millbrook wins the dual on segments (the sim's own segment end, no fight); on
# DUAL OVER the SCOUTING lines show the machine (no pulls, its rare leads) and the open mat (nobody waiting). ` feeds the machine a pull
# (10 Prestige): a lead on the open mat, the LEAD toast; eight more; the tenth is rare - a named recruit turns approachable, the RARE
# LEAD toast, the RECRUITS lines name him. ` on nothing is refused; Shift+` off an open-mat day is refused on the priority; on the 7th
# day Shift+` signs the open mat's first free - the toast, the stable one card more. F5, the next dual: the signed generic on the bench.
# Exit 0 = every step did what the keys and the SCOUTING lines say.
var main_node: Node
var f := 0
var fails: Array = []
var done := 0
var first := ""
var rare := ""

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
			_check("the dual won: DUAL OVER's SCOUTING lines - the machine unfed, its rare leads, the open mat empty", s.mode == "OVER" and hud.contains(">>> SCOUTING  ` pull  Shift+` sign  (Prestige 100, stable %d)" % s.stable.size()) and hud.contains("THE MACHINE: 0 pulls (10 Prestige a pull, every 10th rare; %d rare leads left) - no leads yet" % s.scout_rares().size()) and hud.contains("THE OPEN MAT (every 7th day, priority 10 Prestige): nobody waiting"), "rares %d, stable %d" % [s.scout_rares().size(), s.stable.size()])
			_key(KEY_QUOTELEFT)
		12:
			first = str(s.open_mat()[0]["name"]) if s.open_mat().size() > 0 else ""
			_check("` pulls: 10 Prestige for a lead - a generic waits on the open mat, the LEAD toast names him", int(s.rewards["prestige"]) == 90 and s.open_mat().size() == 1 and hud.contains("LEAD  %s (" % first) and hud.contains("- on the open mat"), first)
			for i in 8: _key(KEY_QUOTELEFT)
		16:
			_check("eight pulls more: nine leads, nine on the open mat, 10 Prestige left", int(s.rewards["scouting"]["pulls"]) == 9 and s.open_mat().size() == 9 and int(s.rewards["prestige"]) == 10, "pulls %d, open mat %d" % [int(s.rewards["scouting"]["pulls"]), s.open_mat().size()])
			_key(KEY_QUOTELEFT)
		20:
			var lead: Dictionary = s.rewards["scouting"]["leads"][9]
			rare = str(lead.get("id", ""))
			_check("the tenth pull is rare: %s turns approachable - the RARE LEAD toast, the RECRUITS lines name him" % str(lead.get("label", "")), bool(lead.get("rare", false)) and s.recruit_state(rare) == "approachable" and hud.contains("RARE LEAD  %s" % str(lead.get("label", ""))) and hud.contains(">>> RECRUITS"), rare)
			_key(KEY_QUOTELEFT)
		24:
			_check("` on nothing: refused, naming the price", main_node.feed.text == "THE MACHINE - a pull costs 10 Prestige (the ledger holds 0)", main_node.feed.text)
			_key(KEY_QUOTELEFT, true)
		28:
			_check("Shift+` off an open-mat day: refused on the priority", main_node.feed.text == "THE OPEN MAT - the open mat is every 7th day (day %d) - its priority costs 10 Prestige (the ledger holds 0)" % int(s.rewards.get("day", 1)), main_node.feed.text)
			while not s.open_mat_day(): s.new_day()                                                   # the overworld's days turn to the open mat's
			_key(KEY_QUOTELEFT, true)
		32:
			_check("the 7th day: Shift+` signs the open mat's first free - the toast, the stable one card more", s._stable_card(first).size() > 0 and bool(s._stable_card(first).get("generic", false)) and hud.contains("THE OPEN MAT  %s signs - the stable holds %d" % [first, s.stable.size()]) and s.open_mat().size() == 8, "%s, stable %d" % [first, s.stable.size()])
			_key(KEY_F5)
		36:
			_check("F5, the next dual: the signed generic on the bench, the stable kept", s.mode == "FIGHT" and s._stable_card(first).size() > 0 and not (first in s.dressed.map(func(c): return str(c["name"]))), "stable %d" % s.stable.size())
		38:
			var green: bool = fails.is_empty() and done == 8
			print("SCOUTING DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 8])
			quit(0 if green else 1)
	return false

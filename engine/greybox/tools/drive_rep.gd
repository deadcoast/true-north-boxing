extends SceneTree
# TRUE NORTH BOXING - district rep on the real scene, headless (PAC-101, NP_02 s2.1, NP_08 s2.2 / s2.4).
#   godot --headless --path engine/greybox -s tools/drive_rep.gd -- boss=7 scrap=SCR-01 district=rink
# Loads the real scene on a scrap against Carter Okafor placed in the Rink District. The head names the district and its rep. Won, the
# rink is +1 (the REP toast, BOUT OVER's DISTRICT REP line). Carter, approachable, is approached (L): BEAT_IN(scrap)x3 AND
# REP(rink_district, 3) read off the ledger. Two more won (F5): the rink at 3 pays its milestone (+1 Prestige) and Carter would join. F5
# and BACKSPACE mid-scrap: fled, the rink -1 (the FLED toast). BACKSPACE after it: refused, the scrap is over.
# Exit 0 = every step did what the keys and the lines say.
var main_node: Node
var f := 0
var fails: Array = []
var done := 0

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

func _win(s) -> void:
	# the scrap's objective met (the sim's own verdict path), the events to the scene
	s.obj["met"] = true; s._end_bout(); main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_check("the scrap placed in the Rink District: the head names it and its rep", s.bout.get("kind", "") == "scrap" and str(s.bout.get("district", "")) == "rink" and hud.contains("in RINK (rep 0) [BACKSPACE flee]"), str(s.bout.get("label", "")))
			_win(s)
		8:
			_check("won: the rink +1 - the REP toast, BOUT OVER's DISTRICT REP line", s.rep_of("rink") == 1 and hud.contains("REP  RINK 1 (+1, a scrap won)") and hud.contains("DISTRICT REP (milestones 3 +1 Prestige, 10 +1 Prestige, 25 +2 Prestige): MILLBROOK 0 (next 3), RINK 1 (next 3)"), "rep %d" % s.rep_of("rink"))
			s.rewards["recruit"]["carter_okafor"] = {"state": "approachable", "witnessed": 0, "day": 1}
			_key(KEY_L)
		12:
			_check("L: Carter approached - REP(rink_district, 3) read off the ledger", s.recruit_state("carter_okafor") == "approached" and hud.contains("REP(rink_district, 3) 1/3"), JSON.stringify(s.recruit_lines()))
			_key(KEY_F5)
		16:
			_win(s); _key(KEY_F5)
		20:
			_win(s)
		24:
			_check("three won: the rink at 3 pays its milestone (+1 Prestige) and Carter would join", s.rep_of("rink") == 3 and int(s.rewards["prestige"]) == 7 and "rink 3 +1P" in main_node.rep_seen and hud.contains("RINK 3 (next 10)") and hud.contains("REP(rink_district, 3) 3/3 ok") and hud.contains(">> READY"), "Prestige %d" % int(s.rewards["prestige"]))
			_key(KEY_F5)
		30:
			_key(KEY_BACKSPACE)
		34:
			_check("BACKSPACE mid-scrap: fled - the rink -1, the FLED toast, the bout over unpaid", s.mode == "OVER" and s.rep_of("rink") == 2 and int(s.rewards["prestige"]) == 7 and hud.contains("FLED  the scrap in RINK - rep -1") and hud.contains("RINK 2 (next 10)"), "rep %d" % s.rep_of("rink"))
			_key(KEY_BACKSPACE)
		38:
			_check("BACKSPACE after it: refused, the scrap is over", main_node.feed.text == "FLEE - the scrap is over", main_node.feed.text)
		40:
			var green: bool = fails.is_empty() and done == 6
			print("REP DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 6])
			quit(0 if green else 1)
	return false

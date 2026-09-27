extends SceneTree
# TRUE NORTH BOXING - the vendor tiers on the real scene, headless (PAC-103, NP_02 s4).
#   godot --headless --path engine/greybox -s tools/drive_vendors.gd -- boss=7 scrap=SCR-01 district=downtown rep=downtown:9 purse=hbp:1500 level=RORY:15
# Loads the real scene on a scrap placed on the Downtown Strip, its rep at 9 and no story flag: the shops' t2 shelves are shut. Won,
# DOWNTOWN is 10 - the REP toast names both t2 shelves opened, BOUT OVER's SHOPS lines read them open by the rep. \ buys the gear shop's
# pick off t2, [ the technique shop's. F5 and BACKSPACE mid-scrap: fled, DOWNTOWN 9 - the FLED toast names the shelves closed, the SHOPS
# lines what they want; what was bought stays. \ again: the pick comes off t1. F5, won: 10 again and the shelves open again.
# Exit 0 = every step did what the keys and the lines say.
var main_node: Node
var f := 0
var fails: Array = []
var done := 0
const N := 7

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

func _last(prefix: String) -> String:
	var hits: Array = main_node.vendor_seen.filter(func(x): return str(x).begins_with(prefix))
	return str(hits[hits.size() - 1]) if hits.size() > 0 else ""

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_check("the scrap on the Downtown Strip at rep 9, no story flag: the head names it, both t2 shelves shut", s.bout.get("kind", "") == "scrap" and str(s.bout.get("district", "")) == "downtown" and hud.contains("in DOWNTOWN (rep 9) [BACKSPACE flee]") and s.shelves_open() == ["techniques:t1", "gear:t1"], JSON.stringify(s.shelves_open()))
			_win(s)
		8:
			_check("won: DOWNTOWN 10 - the REP toast names the shelves opened, BOUT OVER's SHOPS lines read them open by the rep", s.rep_of("downtown") == 10 and hud.contains("REP  DOWNTOWN 10 (+1, a scrap won)") and hud.contains("- opens the technique shop's t2 shelf, the gear shop's t2 shelf") and hud.contains(">>> THE TECHNIQUE SHOP (DOWNTOWN, rep 10): t1 open, t2 open (DOWNTOWN rep 10), t3 at the Provincials or rep 25 (10/25)") and hud.contains(">>> THE GEAR SHOP (DOWNTOWN, rep 10): t1 open, t2 open (DOWNTOWN rep 10)"), JSON.stringify(main_node.vendor_seen))
			_key(KEY_BACKSLASH)
		12:
			_check("\\ : the gear shop's pick off the t2 shelf the rep opened", _last("bought gear").ends_with("(t2, rep)") and hud.contains("GEAR  bought"), _last("bought gear"))
			_key(KEY_BRACKETLEFT)
		16:
			var mv := _last("bought RORY").trim_prefix("bought RORY ").split(" (")[0]
			_check("[ : the technique shop's pick off t2, learned and in the kit", _last("bought RORY").ends_with("(t2, rep)") and s.learned("RORY").has(mv) and s.shop_tier_of(mv) == "t2" and hud.contains(mv), _last("bought RORY"))
			_key(KEY_F5)
		24:
			_key(KEY_BACKSPACE)
		28:
			var kept: bool = s.gear_owned().keys().any(func(id): return str(s.gear_item(str(id)).get("shelf", "")) == "t2") and s.learned("RORY").keys().any(func(mv): return s.shop_tier_of(str(mv)) == "t2")
			_check("BACKSPACE mid-scrap: fled, DOWNTOWN 9 - the FLED toast names the shelves closed, the SHOPS lines what they want, the bought kept", s.mode == "OVER" and s.rep_of("downtown") == 9 and hud.contains("FLED  the scrap in DOWNTOWN - rep -1  - closes the technique shop's t2 shelf, the gear shop's t2 shelf") and hud.contains("t2 at the Regionals or rep 10 (9/10)") and kept, JSON.stringify(s.shelves_open()))
			_key(KEY_BACKSLASH)
		32:
			_check("\\ again: the gear shop's pick off t1 now", _last("bought gear").ends_with("(t1, found)"), _last("bought gear") + " - " + main_node.feed.text)
			_key(KEY_F5)
		36:
			_win(s)
		40:
			_check("F5, won: DOWNTOWN 10 again - the shelves open again", s.rep_of("downtown") == 10 and hud.contains("- opens the technique shop's t2 shelf, the gear shop's t2 shelf") and s.shelves_open() == ["techniques:t1", "techniques:t2", "gear:t1", "gear:t2"], JSON.stringify(main_node.vendor_seen))
		44:
			var green: bool = fails.is_empty() and done == N
			print("VENDORS DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), N])
			quit(0 if green else 1)
	return false

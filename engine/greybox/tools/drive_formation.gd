extends SceneTree
# TRUE NORTH BOXING - the formation screen driven by its keys, headless (PAC-073).
#   godot --headless --path engine/greybox -s tools/drive_formation.gd -- formation
# Loads the real scene with `-- formation`, presses 2 (Ambush), 5 (the card order), 4 (Relay Ladder) before the bell,
# ENTER (the bell), TAB (the board on the HUD), then 1 after the bell (nothing: the corner's swap is the reorder).
# PAC-079: before the 4, two cards are pinned on the Gym Wall, the whiteboard shows the wall's suggestion, and 6 seals it.
# PAC-080: RORY and PRIYA are a Duo (Kizuna 90, seeded on the ledger at frame 3): the whiteboard names the Duo relay each order holds.
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

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	match f:
		3: s.rewards["kizuna"]["PRIYA|RORY"] = 90
		5: _check("before the bell the sim waits", s.tick == 0 and main_node.formation_open and main_node.hud.text.contains(">>> FORMATION"), "tick %d, board %s" % [s.tick, str(s.sealed_p)])
		10: _key(KEY_2)
		15: _check("2 seals Ambush", s.sealed_p == ["PRIYA", "RORY", "MARCUS"] and str(s.board.get("archetype", "")) == "AMBUSH" and s.tick == 0, str(s.sealed_p))
		20: _key(KEY_5)
		25: _check("5 seals the card order", s.sealed_p == ["RORY", "PRIYA", "MARCUS"] and s.tick == 0, str(s.sealed_p))
		26: _check("the whiteboard names the card order's Duo relay (PAC-080)", main_node.hud.text.contains("DUO RELAYS: R1 RORY -> R2 PRIYA (Whiteout)"), "")
		27: s.pin("PRIYA", 1, 2); s.pin("MARCUS", 1, 1)
		29: _check("the whiteboard shows the Gym Wall's suggestion from the cards as pinned (PAC-079)", main_node.hud.text.contains("THE GYM WALL SUGGESTS (6): R1 RORY  R2 MARCUS  R3 PRIYA"), "")
		30: _key(KEY_6)
		33: _check("6 seals the Gym Wall's suggestion (PAC-079)", s.sealed_p == ["RORY", "MARCUS", "PRIYA"] and str(s.board.get("archetype", "")) == "GYM_WALL" and s.tick == 0 and main_node.hud.text.contains("YOUR BOARD [The Gym Wall]"), str(s.sealed_p))
		34: _check("the Gym Wall's order holds no Duo relay (PAC-080)", not main_node.hud.text.contains("DUO RELAYS"), "")
		35: _key(KEY_4)
		38: _check("4 seals the Relay Ladder", s.sealed_p == ["MARCUS", "RORY", "PRIYA"] and str(s.board.get("archetype", "")) == "RELAY_LADDER", str(s.sealed_p))
		39: _check("the Relay Ladder's R2 -> R3 is the Duo relay (PAC-080)", main_node.hud.text.contains("DUO RELAYS: R2 RORY -> R3 PRIYA (Whiteout)"), "")
		42: _key(KEY_ENTER)
		62: _check("ENTER rings the bell", not main_node.formation_open and s.tick > 0 and s.lineup[0]["name"] == "MARCUS", "tick %d, R1 %s" % [s.tick, str(s.lineup[0]["name"])]); _key(KEY_TAB)
		67: _check("TAB shows the whiteboard in the dual", main_node.hud.text.contains("THEIR PROJECTION") and main_node.hud.text.contains("YOUR BOARD [Relay Ladder] SEALED") and not main_node.hud.text.contains("THE GYM WALL SUGGESTS"), ""); _key(KEY_1)
		72: _check("after the bell 1 seals nothing", s.sealed_p == ["MARCUS", "RORY", "PRIYA"], str(s.sealed_p))
		77:
			print("FORMATION DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 12 - fails.size(), 12])
			quit(0 if fails.is_empty() else 1)
	return false

extends SceneTree
# TRUE NORTH BOXING - the club facilities on the real scene, headless (PAC-089).
#   godot --headless --path engine/greybox -s tools/drive_facilities.gd -- purse=hbp:3000,spirits:150 flag=story:charter_saved,quest:gym_funding,story:nationals
# Loads the real scene with the ledger's purse and the three story gates seeded (the command line's). The Old Gym as found: no entrance at
# the bell. Millbrook wins the dual on segments (the sim's own segment end, no fight); on the DUAL OVER screen THE OLD GYM's lines name each
# track's next tier and its price, the training slots and the Scout Book's shelf. 1 renovates Bags & Mitts - the toast, the ledger down, the
# photograph on the Gym Wall; T trains a slot (Mitts, the best game open) - the Beans in the jar; 5, 4 and 3 renovate Front of House, The
# Wall (two card columns more) and the Film Room (the shelf at 12); F5, the next dual: the club walks out to its music sting.
# Exit 0 = every step did what the keys and the Old Gym say.
var main_node: Node
var f := 0
var fails: Array = []
var hbp0 := 0

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	if not ok: fails.append(label)

func _key(code: Key) -> void:
	var k := InputEventKey.new(); k.keycode = code; k.pressed = true
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
			_check("the Old Gym as found: every track at T0, no entrance at the bell, no Old Gym lines in the fight", s.facility_tiers().values().filter(func(x): return int(x) != 0).is_empty() and main_node.entrances_seen == 0 and not hud.contains(">>> THE OLD GYM"), JSON.stringify(s.facility_tiers()))
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		8:
			hbp0 = int(s.rewards.get("hbp", 0))
			_check("the dual won: DUAL OVER, THE OLD GYM's lines - each track's next tier and price, the training slots, the shelf", s.mode == "OVER" and hud.contains(">>> THE OLD GYM  [1-5] renovate  [T] train  (HBP %d, Spirits %d, Beans 0)" % [hbp0, int(s.rewards.get("spirits", 0))]) and hud.contains("[1] Bags & Mitts T0 -> T1 (the bags rehung: Mitts and the Heavy Bag open): 150 HBP, 5 Spirits") and hud.contains("TRAINING [T] 0 of 3 slots used today (day 1): Roadwork open") and hud.contains("Scout Book 3 of 6 pages"), "HBP %d" % hbp0)
			_key(KEY_1)
		12:
			var photo: bool = s.gym_wall["decos"].filter(func(d): return str(d["kind"]) == "renovation").size() == 1
			_check("1 renovates Bags & Mitts: the toast, T1, 150 HBP and 5 Spirits off the ledger, the photograph on the Gym Wall", s.fac_tier("bags_mitts") == 1 and int(s.rewards.get("hbp", 0)) == hbp0 - 150 and hud.contains("RENOVATED  BAGS & MITTS T1 - the bags rehung: Mitts and the Heavy Bag open (150 HBP, 5 Spirits)") and photo and hud.contains("[1] Bags & Mitts T1 -> T2"), "")
			_key(KEY_T)
		16:
			_check("T trains a slot: Mitts (the best game open), grade 0.75, 5 Beans in the jar - the toast and the training line", int(s.rewards.get("beans", 0)) == 5 and hud.contains("TRAINING  RORY - Mitts, grade 0.75: 5 Beans (slot 1 of 3; the jar 5)") and hud.contains("TRAINING [T] 1 of 3 slots used today (day 1): Roadwork, Mitts, Heavy Bag open"), "Beans %d" % int(s.rewards.get("beans", 0)))
			_key(KEY_5)
		18: _key(KEY_4)
		20: _key(KEY_3)
		24:
			_check("5, 4, 3: Front of House T1, The Wall T1 (two card columns more on the Gym Wall), the Film Room T1 (the shelf at 12)", s.fac_tier("front_of_house") == 1 and s.fac_tier("the_wall") == 1 and s.fac_tier("film_room") == 1 and s._gw_grid().x == 10 and s.book_pages() == 12 and hud.contains("Scout Book 3 of 12 pages") and main_node.renovations_seen.size() == 4, JSON.stringify(main_node.renovations_seen))
			_key(KEY_F5)
		28:
			_check("F5, the next dual: MILLBROOK walks out to its music sting - the entrance toast at the bell", s.mode == "FIGHT" and main_node.entrances_seen == 1 and hud.contains("ENTRANCE  MILLBROOK walks out - music sting"), "")
		30:
			print("FACILITIES DRIVE :: %s (%d/%d)" % ["GREEN" if fails.is_empty() else "RED", 6 - fails.size(), 6])
			quit(0 if fails.is_empty() else 1)
	return false

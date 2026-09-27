extends SceneTree
# TRUE NORTH BOXING - the locker room on the real scene, headless (PAC-100, NP_08 s4).
#   godot --headless --path engine/greybox -s tools/drive_locker.gd -- purse=prestige:60
# Loads the real scene with 60 Prestige. Millbrook wins the dual on segments; DUAL OVER's LOCKER ROOM lines browse the four by House and show
# RORY's comparison card, and 0 on RORY is refused (the story's own). ` three times and Shift+` three times put three generics on the bench
# (the priority paid). 8 four times browses by slot-role; 9 moves the card to the bench's second; 0 releases it - the RELEASED toast, a
# grudge, the stable one fewer - and Shift+0 takes it back as it was. 0 again releases the bench's first; three days turn and the release
# stands - the GONE toast, the card on the open mat with its grudge - and Shift+0 is refused. F5: the next dual, the release still standing.
# Exit 0 = every step did what the keys and the LOCKER ROOM lines say.
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
			_check("the dual won: DUAL OVER's LOCKER ROOM lines - the four by House, RORY's comparison card, the story's own", s.mode == "OVER" and hud.contains(">>> LOCKER ROOM  8 browse  9 next card  0 release  Shift+0 take back") and hud.contains("THE LOCKER ROOM (4 of 100) by house - houseless: RORY, PRIYA, MARCUS, JUNE") and hud.contains("THE CARD  RORY - houseless, BOXERPUNCHER, FROST, MILLBROOK; dressed") and hud.contains("(RORY is the story's own - the club began with RORY)"), "stable %d" % s.stable.size())
			_key(KEY_0)
		12:
			_check("0 on RORY: refused, the story's own", main_node.feed.text == "THE LOCKER ROOM - RORY is the story's own - the club began with RORY", main_node.feed.text)
			for i in 3: _key(KEY_QUOTELEFT)
			for i in 3: _key(KEY_QUOTELEFT, true)
		16:
			_check("` three times, Shift+` three times: three generics on the bench, the priority paid", s.stable.size() == 7 and int(s.rewards["prestige"]) == 0 and hud.contains("THE LOCKER ROOM (7 of 100)"), "stable %d, Prestige %d" % [s.stable.size(), int(s.rewards["prestige"])])
			for i in 4: _key(KEY_8)
			_key(KEY_9)
		20:
			var b2: String = str(s.stable[5]["name"])
			_check("8 four times: by slot-role; 9: the bench's second on the comparison card", hud.contains("by role - dressed: RORY, PRIYA, MARCUS, JUNE | on the bench: %s, %s, %s" % [str(s.stable[4]["name"]), b2, str(s.stable[6]["name"])]) and hud.contains("THE CARD  %s - " % b2) and main_node.locker_focus == b2, b2)
			_key(KEY_0)
		24:
			var gone: Array = s.rewards.get("locker", {}).get("pending", {}).keys()
			_check("0: released - the RELEASED toast, a grudge, the stable one fewer, the RELEASED line", gone.size() == 1 and s.stable.size() == 6 and hud.contains("RELEASED  %s - a grudge, no bond left behind; take the card back until day 4 (the stable 6)" % str(gone[0])) and hud.contains("RELEASED: %s (day 1, grudge; take back until day 4)" % str(gone[0])), JSON.stringify(gone))
			_key(KEY_0, true)
		28:
			_check("Shift+0: taken back as it was - the TAKEN BACK toast, the stable 7, nothing waiting", s.stable.size() == 7 and s.rewards["locker"]["pending"].is_empty() and hud.contains("TAKEN BACK  ") and hud.contains("back in the stable as before (7)"), "stable %d" % s.stable.size())
			_key(KEY_0)
		32:
			var g1: Array = s.rewards["locker"]["pending"].keys()
			_check("0 again: the bench's first released", g1.size() == 1 and s.stable.size() == 6, JSON.stringify(g1))
			for i in 3: s.new_day()
			main_node._consume_events()
		36:
			var om: Array = s.open_mat().map(func(c): return "%s:%s" % [str(c["name"]), str(c.get("released", ""))])
			_check("three days turn: the release stands - the GONE toast, the card on the open mat with its grudge", s.rewards["locker"]["pending"].is_empty() and om.size() == 1 and str(om[0]).ends_with(":grudge") and hud.contains("GONE  ") and hud.contains("on the open mat, with a grudge") and hud.contains("released: grudge"), JSON.stringify(om))
			_key(KEY_0, true)
		40:
			_check("Shift+0 after the third day: refused, nobody waiting", main_node.feed.text == "THE LOCKER ROOM - nobody is waiting on a release", main_node.feed.text)
			_key(KEY_F5)
		44:
			_check("F5, the next dual: the release still standing, the stable 6", s.mode == "FIGHT" and s.stable.size() == 6 and s.rewards["locker"]["memory"].size() == 1, "stable %d" % s.stable.size())
		46:
			var green: bool = fails.is_empty() and done == 10
			print("LOCKER DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 10])
			quit(0 if green else 1)
	return false

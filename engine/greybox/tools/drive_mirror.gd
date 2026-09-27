extends SceneTree
# TRUE NORTH BOXING - the mirror spar on the real scene, headless (PAC-093).
#   godot --headless --path engine/greybox -s tools/drive_mirror.gd -- habits=RORY:L_STRAIGHT+L_STRAIGHT+R_STRAIGHT*8,RORY:L_HOOK+R_HOOK*5,RORY:counter=R_HOOK*6/6
# Loads the real scene with the tracker's record the command line seeds (RORY: JAB > JAB > R_STR thrown and read 8 times, L_HOOK > R_HOOK 5,
# his R_HOOK into all six counter windows his defense opened). Millbrook wins the dual on segments (the sim's own segment end, no fight);
# DUAL OVER's HABITS line shows RORY's record and the copy it makes. [M]: RORY against RORY'S MIRROR - the matchup card's MIRROR line,
# its strings his sequences, its tracker already reading them. J, J (landed, his read cancelled as the smoke's throw_clean does), then K:
# the copy reads the R_STR at 3, slips it, and answers with RORY's own R_HOOK (the YOUR COUNTER toast). The spar won on EP at the bell: the
# Legend's trial (the mirror beaten), no Pattern Intel, and the record grown by the spar's punches. [M] again: back to the dual.
# Exit 0 = every step did what the keys and the lines say.
var main_node: Node
var f := 0
var fails: Array = []
var pi0 := {}
var n_before := 0
var boss0 := ""
var whiffs0 := 0
var rd := ""
var jabs := 0
var done := 0

func _init() -> void:
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)

func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s]  %s  %s" % [" OK " if ok else "FAIL", label, detail])
	done += 1
	if not ok: fails.append(label)

func _key(code: Key, down: bool = true) -> void:
	var k := InputEventKey.new(); k.keycode = code; k.pressed = down
	root.push_input(k)

func _quiet(s) -> void:
	s.hooks_enabled = false; s.coach_on = false; s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}; s.neutral_on = false

func _seg_won(s) -> void:
	# a segment ended with Millbrook ahead on EP (the sim's own segment end, no fight), the card and the corner sent on
	s.mode = "FIGHT"; s.eight = {}; s.ep_p += 4; s._end_segment("drive")
	if s.mode == "CARD": s.step({"corner": 1})
	if s.mode == "CORNER": s.step({"corner": 1})

func _land(s, cancel: bool) -> void:
	# the punch the key threw, run to its end (his read cancelled when asked, as the smoke's throw_clean does)
	var n := 0
	while (s.P["pending"].size() > 0 or s.P["cmd"].size() > 0) and n < 200:
		if cancel: s.B["dodge"] = ""; s.B["dodge_t"] = 0; s.B["dodge_plan"] = []; s.B["dodge_at"] = 0; s.B["blocking"] = false; s.B["guard_t"] = 0
		s.step({}); n += 1
	main_node._consume_events()

func _process(_d: float) -> bool:
	f += 1
	var s = main_node.sim
	var hud: String = main_node.hud.text
	match f:
		4:
			_quiet(s); boss0 = str(s.boss_names[s._first_boss])
			for i in s.segments(): _seg_won(s)
			main_node._consume_events()
		8:
			_check("the dual won: DUAL OVER's HABITS line - RORY's record and the copy it makes", s.mode == "OVER" and hud.contains(">>> HABITS  [M] the mirror  (the tracker's record)") and hud.contains("RORY: 34 punches, 0 feints - JAB 47%, R_STR 24%, L_HOOK 15%; the copy throws HABIT JAB > JAB > R_STR, HABIT L_HOOK > R_HOOK; counters with R_HOOK (100%)"), "")
			pi0 = s.pi.duplicate(true); n_before = int(s.habits_of("RORY")["punches"])
			_key(KEY_M)
		12:
			_check("[M]: RORY against RORY'S MIRROR - the matchup card's MIRROR line", s.bout.get("kind", "") == "spar" and s.pname() == "RORY" and s.boss_label == "RORY'S MIRROR" and hud.contains("MIRROR: RORY'S MIRROR learned from 34 punches - throws HABIT JAB > JAB > R_STR (71%), HABIT L_HOOK > R_HOOK (29%); reads JAB > JAB > R_STR (3), L_HOOK > R_HOOK (3) from the bell; counters with your R_HOOK (100%)"), s.boss_label)
			_check("its strings are his sequences, its tracker already reading them at 3", s.pattern["strings"].keys().map(func(k): return s.pattern["strings"][k]["actions"]) == [["JAB", "JAB", "R_STR"], ["L_HOOK", "R_HOOK"]] and s.flags.get("L_STRAIGHT,L_STRAIGHT,R_STRAIGHT", [0])[0] == 3, JSON.stringify(s.flags))
			_quiet(s); s.P["pos"] = Vector2(0, 0.6); s.B["pos"] = Vector2(0, -0.6); s.freeze_t = 0; s.P["busy_t"] = 0; s.P["cmd"] = {}
			_key(KEY_J)
		13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40:
			# each key's punch taken as soon as the scene hands it to the sim: J and J landed (his read cancelled), then K left to his read
			if s.P["pending"].is_empty() and s.P["cmd"].is_empty(): return false
			jabs += 1
			if jabs < 3:
				_land(s, true); s.P["busy_t"] = 0
				if jabs == 2: whiffs0 = int(main_node.fx_counts.get("whiff", 0)); _key(KEY_K)
				else: _key(KEY_J)
				return false
			var n := 0
			while s.P["pending"].is_empty() and s.P["cmd"].size() > 0 and n < 20: s.step({}); n += 1
			rd = str(s.P["pending"].get("read", "")) if s.P["pending"].size() > 0 else "?"
			_land(s, false)
			_check("K after J, J: his read on JAB > JAB > R_STR at 3 - he slips it, you miss", rd == "dodge" and int(main_node.fx_counts.get("whiff", 0)) == whiffs0 + 1, "read %s, whiffs %d -> %d" % [rd, whiffs0, int(main_node.fx_counts.get("whiff", 0))])
			_check("...and he answers with your R_HOOK (counters 1)", main_node.mirror_counters == 1 and s.bqueue.size() > 0 and str(s.bqueue[0]["row"]) == "R_HOOK", "%d, %s" % [main_node.mirror_counters, JSON.stringify(s.bqueue.slice(0, 1))])
			f = 44
		41: _check("the keys' punches reached the sim (J, J, K)", false, "%d of 3" % jabs); f = 44
		46:
			_check("the YOUR COUNTER toast on the HUD", hud.contains("YOUR COUNTER  RORY'S MIRROR answers the miss with your R_HOOK"), "")
			_quiet(s); s.ep_p += 6; s.clock_t = 2
		54:
			var tr: Dictionary = s._grow("RORY").get("trials", {})
			_check("won on EP at the bell: the Legend's trial met (the mirror beaten), no Pattern Intel, the record grown by the spar's punches", s.mode == "OVER" and tr.has("mirror") and s.pi == pi0 and int(s.habits_of("RORY")["punches"]) == n_before + 3, "trials %s, PI the same %s, punches %d -> %d" % [JSON.stringify(tr.keys()), str(s.pi == pi0), n_before, int(s.habits_of("RORY")["punches"])])
			_key(KEY_M)
		58:
			_check("[M] again: back to the dual - RORY against the boss he left", s.bout.is_empty() and s.mode == "FIGHT" and s.pname() == "RORY" and s.boss_label == boss0, "%s vs %s (was %s)" % [s.pname(), s.boss_label, boss0])
		60:
			var green: bool = fails.is_empty() and done == 8
			print("MIRROR DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 8])
			quit(0 if green else 1)
	return false

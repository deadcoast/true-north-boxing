extends SceneTree
# TRUE NORTH BOXING - the anti-you on the real scene, headless (PAC-102, NP_12 s2).
#   godot --headless --path engine/greybox -s tools/drive_anti.gd -- boss=19
# Loads the real scene against Moira's squad. Millbrook wins the dual on segments: four of Moira's club flagged approachable. The arc turns
# (story:nationals, the overworld's story_mark): Director Vey's academy signs three of them - the ANTI-YOU toast, the RECRUITS lines
# naming the academy (Dex held, no pattern of its own to field). L approaches the one left; the three stay out of reach. The academy is
# fielded; F5: Moira and Remy fight R1 and R2 for it with the syntheses of the prodigies they displace (the matchup card's ACADEMY line),
# Vey in the corner. Millbrook wins it: the three come over, approachable, and L approaches them.
# Exit 0 = every step did what the lines say.
var main_node: Node
var f := 0
var fails: Array = []
var done := 0
var taken: Array = []

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
			_check("the dual won: four of Moira's club flagged approachable, the RECRUITS lines", s.mode == "OVER" and s.recruits_open().size() == 4 and hud.contains(">>> RECRUITS"), JSON.stringify(s.recruits_open()))
			s.story_mark("story:nationals"); main_node._consume_events()
		12:
			taken = s.academy_taken()
			var cards: Array = taken.map(func(x): return str(s._recruit_rec(str(x)).get("card", x)))
			_check("the arc turns: the academy signs three - the ANTI-YOU toast, the RECRUITS lines name it", taken.size() == 3 and hud.contains("THE ANTI-YOU  Toronto Ascendant Academy signs %s - rivals the club beat and left waiting (story:nationals)" % ", ".join(PackedStringArray(cards))) and hud.contains("signed by Toronto Ascendant Academy at story:nationals") and hud.contains("held, with no pattern of its own to field"), JSON.stringify(cards))
			_key(KEY_L)
		16:
			var left: Array = s.recruits_open()
			_check("L: the one left approached, the three out of reach", left.size() == 1 and s.recruit_state(str(left[0])) == "approached" and taken.all(func(x): return s.recruit_state(str(x)) == "academy"), JSON.stringify(left))
			s.field_academy(true)
			_key(KEY_F5)
		20:
			var fielded: Array = s.academy_fielded()
			_check("F5 with the academy fielded: its rivals fight R1 and R2 ahead of the prodigies, Vey in the corner, the matchup card's ACADEMY line", s.mode == "FIGHT" and s.blineup.slice(0, fielded.size()) == fielded and str(s.blineup[s.blineup.size() - 1]).begins_with("ASCENDANT") and str(s.coach.get("id", "")) == "ascendant_a" and main_node.matchup_text.contains("ACADEMY: %s carries 3 syntheses" % str(fielded[0])), JSON.stringify(s.blineup))
			_win(s)
		24:
			var cards2: Array = taken.map(func(x): return str(s._recruit_rec(str(x)).get("card", x)))
			_check("the academy beaten: the three come over, approachable", s.mode == "OVER" and s.academy_taken().is_empty() and taken.all(func(x): return s.recruit_state(str(x)) == "approachable") and ("came over %s" % ", ".join(PackedStringArray(cards2))) in main_node.anti_seen, JSON.stringify(main_node.anti_seen))
			_key(KEY_L)
		28:
			_check("L: approached - their conditions surface", taken.all(func(x): return s.recruit_state(str(x)) == "approached"), JSON.stringify(taken.map(func(x): return s.recruit_state(str(x)))))
		30:
			var green: bool = fails.is_empty() and done == 6
			print("ANTI-YOU DRIVE :: %s (%d/%d)" % ["GREEN" if green else "RED", done - fails.size(), 6])
			quit(0 if green else 1)
	return false

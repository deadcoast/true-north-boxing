extends RefCounted
const TNBSim := preload("res://sim/core.gd")
const TNBClock := preload("res://sim/clock.gd")
const TNBProfile := preload("res://sim/profile.gd")
const TNBSave := preload("res://sim/save.gd")
const TNBAssembler := preload("res://sim/assembler.gd")
const TNBExhibition := preload("res://sim/exhibition.gd")
const TNBAudit := preload("res://sim/audit.gd")
const TNBFaucets := preload("res://sim/faucets.gd")
# Executable proofs for NP_14 (C1-C7). Drives TNBSim directly: no Nodes, no
# frames, no wall clock. Every assertion names the claim it serves.
#   godot --headless --path engine/greybox -- smoke boss=N
#   godot --headless --path engine/greybox -- determinism
#   godot --headless --path engine/greybox -- geometry
# Exit code 0 = GREEN. Anything else = a claim in NP_14 is falsified.

var results: Array = []
var content: Dictionary

func _sr(name: String, ok: bool, detail: String = "") -> void:
	results.append([name, ok, detail])
	print("  [%s]  %-46s %s" % [" OK " if ok else "FAIL", name, detail])

func _verdict(label: String) -> int:
	var fails := 0
	for r in results:
		if not r[1]: fails += 1
	print("%s VERDICT :: %s (%d/%d)" % [label, "GREEN" if fails == 0 else "RED", results.size() - fails, results.size()])
	return 0 if fails == 0 else 1

func make_sim(boss_idx: int, seed_v: int, lineup: Array = TNBSim.LINEUP_MILLBROOK, fmt_id: String = "", ledger: Dictionary = {}, reward_ledger: Dictionary = {}, board_d: Dictionary = {}) -> TNBSim:
	if content.is_empty(): content = TNBSim.load_content()
	var s := TNBSim.new()
	s.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, seed_v, content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt_id, content.get("bouts", {}), content.get("scraps", {}),
		content.get("pattern_intel", {}), ledger, content.get("remixes", {}), content.get("economy", {}), reward_ledger, {}, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), board_d, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
	return s

func play_clinch(s: TNBSim, mode: String, want_reset: bool = false) -> void:
	# mode: sides (LS on the cue's side) | wrong (opposite side) | enter (button parity) | mash | none
	var n := 0
	while s.clinch.size() > 0 and n < 2000:
		var inp := {"body": want_reset}
		var i: int = s.clinch["i"]
		if i < s.clinch["cues"].size():
			var c: int = s.clinch["cues"][i]; var w: int = s.clinch["windows"][i]; var t: int = int(s.clinch["t"]) + 1
			var in_win := absi(t - c) <= w
			var side: String = s.clinch["sides"][i]
			match mode:
				"sides": if in_win: inp["move"] = Vector2(-1, 0) if side == "L" else Vector2(1, 0)
				"wrong": if in_win: inp["move"] = Vector2(1, 0) if side == "L" else Vector2(-1, 0)
				"enter": if in_win: inp["rise"] = true
				"mash": inp["move"] = Vector2(-1, 0) if (n / 10) % 2 == 0 else Vector2(1, 0)
		s.step(inp); n += 1

func resolve_cast(s: TNBSim, max_ticks: int = 600) -> void:
	var n := 0
	while s.cast.size() > 0 and n < max_ticks: s.step({}); n += 1

func with_move(boss_idx: int, seed_v: int, move: String) -> TNBSim:
	var lu: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu[0]["hissatsu"] = move
	var t := make_sim(boss_idx, seed_v, lu, "", {}, TNBSim.seed_levels({}, "RORY:5", content["economy"])); quiet(t); place(t, 1.4); t.tension = 100.0   # since PAC-091 at level 5: a T0 is castable from there (NP_05 s3)
	t.B["comp"] = t.B["comp_max"]; t.P["comp"] = t.P["comp_max"]
	return t

func cast_player(s: TNBSim) -> bool:
	# arm + the move's family motion (or the WALL hold), then run the cinematic to its resolve
	var mv: Dictionary = s.player_move()
	thaw(s); s.P["busy_t"] = 0; s.P["cmd"] = {}; s.events.clear()
	if str(mv["family"]) == "WALL":
		run_ticks(s, TNBSim.ms(400) + 1, {"lb": true, "block": true})
	else:
		s.step({"punch": TNBSim.FAMILY_ROW[str(mv["family"])], "lb": true})
	if s.cast.is_empty(): return false
	return true

func boss_desperation(s: TNBSim) -> bool:
	# push the boss under his desperation trigger and let one agent tick arm it (PAC-086: his authored transformation, which would come first, spent)
	if s.pattern.get("transform") is Dictionary and not s.btransformed.has(s.boss_name): s.btransformed[s.boss_name] = "spent"
	thaw(s); s.bstate = "IDLE"; s.btimer = 1 << 30; s.B["comp"] = s.B["comp_max"] * 0.15; s.bsurvival_used = true; s.events.clear()
	s.step({})
	return s.cast.size() > 0 and s.cast["who"] == "B"

func gauge_dmg(s: TNBSim) -> float:
	var total := 0.0
	for e in s.events:
		if e["kind"] == "gauge": total += float(e["dmg"])
	return total

func hit_dmg(s: TNBSim, on: String) -> float:
	var total := 0.0
	for e in s.events:
		if e["kind"] == "hit" and e["on"] == on: total += float(e["dmg"])
	return total

func next_segment(s: TNBSim) -> void:
	# card -> corner -> send
	if s.mode == "CARD": s.step({"corner": 1})
	if s.mode == "CORNER": s.step({"corner": 1})

func sensor_count(s: TNBSim, name: String) -> int:
	return count_events(s.events, "sensor", {"name": name})

func quiet(s: TNBSim) -> void:
	# sensors keep firing as events; bait/punish hooks stay silent; boss frozen; hitstop drained
	s.hooks_enabled = false; s.coach_on = false; freeze_boss(s); thaw(s); s.events.clear()

func run(mode: String, boss_idx: int) -> int:
	match mode:
		"smoke": return smoke(boss_idx)
		"determinism": return determinism()
		"geometry": return geometry()
		"audit": return audit()
		"faucets": return faucets()
	print("unknown test mode: " + mode)
	return 2

# ---------------------------------------------------------------- helpers ----
func freeze_boss(s: TNBSim) -> void:
	s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}
	s.neutral_on = false                     # a frozen boss keeps the shared approach and the 0.35 guard (PAC-071's gates turn his neutral game back on)
	s.clinch = {}; s.clinch_t = 0; s.hands_down_t = 0
	if s.P["busy_t"] > 60: s.P["busy_t"] = 0

func place(s: TNBSim, spacing: float = 1.6) -> void:
	s.P["pos"] = Vector2(0.0, spacing * 0.5); s.B["pos"] = Vector2(0.0, -spacing * 0.5)

func clear_defense(F: Dictionary) -> void:
	F["dodge"] = ""; F["dodge_t"] = 0; F["dodge_at"] = 0; F["dodge_plan"] = []
	F["blocking"] = false; F["block_t"] = 0

func run_ticks(s: TNBSim, n: int, inp: Dictionary = {}) -> void:
	for i in n: s.step(inp)

func thaw(s: TNBSim) -> void:
	while s.freeze_t > 0: s.step({})

func land(s: TNBSim, max_ticks: int = 400) -> void:
	# advance until the player's queued/pending punch resolves (boss frozen by caller)
	var n := 0
	while (s.P["cmd"].size() > 0 or s.P["pending"].size() > 0) and n < max_ticks:
		s.step({}); n += 1

func throw_clean(s: TNBSim, row: String, extra: Dictionary = {}) -> void:
	# throw with the boss's read cancelled: isolates the effect under test from the RNG
	var inp := extra.duplicate(); inp["punch"] = row
	thaw(s)
	s.P["busy_t"] = 0; s.P["cmd"] = {}
	s.step(inp)
	clear_defense(s.B)
	land(s)

func boss_lands(s: TNBSim, row: String, mult: float = 1.0, body: bool = false) -> void:
	s.bpending = {"row": row, "mult": mult, "body": body}
	s._land_boss_punch(mult)

func count_events(evs: Array, kind: String, filt: Dictionary = {}) -> int:
	var n := 0
	for e in evs:
		if e["kind"] != kind: continue
		var ok := true
		for k in filt:
			if not e.has(k) or e[k] != filt[k]: ok = false
		if ok: n += 1
	return n

# ------------------------------------------------------------------ SMOKE ----
func smoke(boss_idx: int) -> int:
	var s := make_sim(boss_idx, 12345)
	print("SMOKE :: TNBSim core, boss=%s" % TNBSim.BOSSES[boss_idx])
	var gauge_boss: bool = s.wall["B"].size() > 0 and float(s.wall["B"].get("pts", 0.0)) > 0.0
	if gauge_boss:
		print("  (wall-gauge anchor: the gauge is stripped for the generic stages and tested on its own below)")
		s.wall["B"] = {}
	if s.pattern.get("transform") is Dictionary:
		print("  (authored transformation: kept unrun for the generic stages, tested on its own in PAC-086's gates)")
		s.btransform_on = false
	_sr("tuning + 24 patterns loaded", s.T.size() > 0 and s.patterns.size() == 24 and s.pattern.size() > 0)
	var vc := s.verb_coverage(s.patterns)
	_sr("action VM executes every verb the compiler emits (24 patterns)", vc["unknown"].is_empty(),
		"%d verbs known%s" % [vc["known"].size(), "" if vc["unknown"].is_empty() else "  UNKNOWN: " + JSON.stringify(vc["unknown"])])
	var pc := s.phase_coverage(s.patterns)
	print("  phase-trigger vocabulary: %d forms executable, %d not yet: %s" % [pc["known"].size(), pc["unknown"].size(), JSON.stringify(pc["unknown"])])
	_sr("dual opens FIGHT / R1 RORY", s.mode == "FIGHT" and s.pname() == "RORY")

	# ---- C3: input buffer ----
	freeze_boss(s); place(s); thaw(s)
	s.step({"punch": "L_STRAIGHT"})
	_sr("C3 free fighter executes on the same tick", s.P["pending"].size() > 0 and s.P["busy_t"] > 0,
		"busy=%d" % s.P["busy_t"])
	clear_defense(s.B)
	while s.P["busy_t"] > 3: s.step({})
	s.step({"punch": "R_STRAIGHT"})                    # issued 3 ticks before recovery ends
	var queued: bool = s.P["cmd"].size() > 0
	s.step({}); s.step({})                             # recovery reaches 0 on this tick
	_sr("C3 punch issued 3 ticks early fires on recovery-end tick",
		queued and s.P["pending"].get("row", "") == "R_STRAIGHT" and s.P["cmd"].is_empty())
	clear_defense(s.B); land(s)
	thaw(s); s.P["busy_t"] = 8; s.P["cmd"] = {}
	var tok0: int = s.tokens.size()
	s.step({"punch": "L_HOOK"})                        # issued 8 ticks early: outside the 6-tick life
	run_ticks(s, 10)
	_sr("C3 punch issued 8 ticks early expires unexecuted",
		s.P["cmd"].is_empty() and s.P["pending"].is_empty() and s.tokens.size() == tok0)

	# ---- C2: geometry sanity (the full table is -- geometry) ----
	place(s, 1.6); clear_defense(s.B)
	_sr("C2 straight reaches a neutral head at 1.6m", s.resolve_geometry(s.P, s.B, "R_STRAIGHT", false) == "HIT")
	place(s, 2.3)
	_sr("C2 straight falls short at 2.3m", s.resolve_geometry(s.P, s.B, "R_STRAIGHT", false) == "MISS_REACH")

	# ---- C7: tracker flags defense only ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}
	for pu in s.pattern.get("punish", []): s.punish_cd[s._ev_key(str(pu["trigger"]))] = 1 << 30
	for i in 3: throw_clean(s, "L_STRAIGHT"); place(s)
	var w_before := JSON.stringify(s.pattern["select"]["weights"])
	var tells_before := ""
	for k in s.pattern["strings"]: tells_before += "%s:%d;" % [k, int(s.pattern["strings"][k]["tell"]["ms"])]
	freeze_boss(s)
	throw_clean(s, "L_STRAIGHT")                       # 4th jab: 2-gram count hits 3 -> flag
	var tier := s._flag_tier()
	_sr("tracker flags the repeated 2-gram", tier >= 1, "tier=%d" % tier)
	_sr("stamina drains on punches", s.P["stamina"] < 100.0, "%.1f" % s.P["stamina"])
	s.bstate = "IDLE"
	_sr("C7 flag raises the boss read probability", s.read_prob(tier, false, false, false) > s.read_prob(0, false, false, false),
		"%.2f -> %.2f" % [s.read_prob(0, false, false, false), s.read_prob(tier, false, false, false)])
	var tells_after := ""
	for k in s.pattern["strings"]: tells_after += "%s:%d;" % [k, int(s.pattern["strings"][k]["tell"]["ms"])]
	_sr("C7 boss offense byte-identical across the flag", JSON.stringify(s.pattern["select"]["weights"]) == w_before and tells_after == tells_before)
	_sr("C7 counter window lowers the read (fear is a number)", s.read_prob(0, true, false, false) < s.read_prob(0, false, false, false))

	# ---- interrupt (NP_04 s4: the pattern's INTERRUPT block says which strings break; a jab-class hit breaks them) ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}
	var brk_first := ""; var hold_first := ""
	for k in s.pattern["strings"]:
		if s._interruptible(str(k)) and brk_first == "": brk_first = str(k)
		if not s._interruptible(str(k)) and hold_first == "": hold_first = str(k)
	s.bstate = "TELL"; s.bstring = brk_first; s.btimer = 1 << 30
	var comp_before: float = s.B["comp"]
	throw_clean(s, "R_STRAIGHT")
	_sr("interrupt breaks the tell (%s, tagged INTERRUPT)" % brk_first, s.bstate != "TELL", "state=" + s.bstate)
	_sr("interrupt opens the flash window", s.P["flash_t"] > 0, "%d ticks" % s.P["flash_t"])
	_sr("interrupt pays tension", s.tension > 0.0, "%.1f" % s.tension)
	_sr("boss took damage", s.B["comp"] < comp_before)
	_sr("C5 hitstop is sim state (freeze ticks queued)", s.freeze_t > 0, "%d ticks" % s.freeze_t)
	var clk0: int = s.clock_t
	s.step({})
	_sr("C5 frozen tick advances no clock", s.clock_t == clk0)
	s.P["busy_t"] = 0; s.P["cmd"] = {}
	s.step({"punch": "L_HOOK"})                        # pressed during hitstop
	var buffered: bool = s.P["cmd"].size() > 0 or s.P["pending"].size() > 0
	thaw(s); s.step({})
	_sr("C3 a punch pressed during hitstop is buffered, not eaten", buffered and s.P["pending"].get("row", "") == "L_HOOK")
	clear_defense(s.B); land(s); s.P["flash_t"] = 0
	if hold_first != "":
		thaw(s); place(s); freeze_boss(s); s.bstate = "TELL"; s.bstring = hold_first; s.btimer = 1 << 30; s.events.clear()
		s.P["flash_t"] = 0; var ten0: float = s.tension; var comp_h: float = s.B["comp"]
		throw_clean(s, "R_STRAIGHT")
		_sr("a string the block does not tag (%s%s) takes the jab and keeps coming: no stagger, no flash window, no +5 - the hit still lands" % [hold_first, " [ARMORED]" if s._string_class(hold_first) == "ARMORED" else ""],
			s.bstate == "TELL" and count_events(s.events, "unbroken", {"string": hold_first}) == 1 and count_events(s.events, "interrupt") == 0 and s.P["flash_t"] == 0 and s.B["comp"] < comp_h and s.tension <= ten0 + 2.01)
	else:
		_sr("every string of this pattern is tagged INTERRUPT (authored all-breakable)", true)
	thaw(s); place(s); freeze_boss(s); s.bstate = "TELL"; s.bstring = brk_first; s.btimer = 1 << 30; s.events.clear(); s.P["flash_t"] = 0
	throw_clean(s, "R_HOOK")
	_sr("only a jab-class hit breaks a string: a hook in the tell lands and does not (NP_04 s4)", s.bstate == "TELL" and count_events(s.events, "unbroken", {"why": "not_a_jab"}) == 1 and count_events(s.events, "interrupt") == 0)
	thaw(s); freeze_boss(s); s.bstate = "IDLE"; clear_defense(s.B); land(s); s.P["flash_t"] = 0

	# ---- drops ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}
	s.B["trait"] = {}                                   # NP_01 s3's scoring, bare: a boss's house trait (Sam's Never Twice) is PAC-078's gate
	s.B["comp"] = 1.0
	var d0 := s.drops_p
	throw_clean(s, "R_UPPERCUT")
	_sr("DROP scored at composure<=0 (+1)", s.drops_p == d0 + 1 and s.score_p == 1, "%d-%d score %d-%d" % [s.drops_p, s.drops_b, s.score_p, s.score_b])
	_sr("post-drop composure resets to 50pct", absf(s.B["comp"] - s.B["comp_max"] * 0.5) < 1.0)
	thaw(s); place(s); s.B["comp"] = 1.0; s.P["flash_t"] = 60; s.tokens = []; s.flags = {}
	throw_clean(s, "R_STRAIGHT")
	_sr("FLASH DROP scores 2 (NP_01 s3)", s.drops_p == d0 + 2 and s.score_p == 3, "score %d-%d" % [s.score_p, s.score_b])
	thaw(s); place(s); s.B["comp"] = 1.0; s.P["flash_t"] = 0; s.tokens = []; s.flags = {}
	var seg0 := s.seg_idx
	throw_clean(s, "R_STRAIGHT")
	_sr("third drop = SEGMENT KO (+1 +3), segment ends (card), dual continues", s.B["drops"] == 3 and s.score_p == 7 and s.mode == "CARD" and s.seg_idx == seg0,
		"score %d-%d mode=%s" % [s.score_p, s.score_b, s.mode])
	next_segment(s)
	s.new_dual(); freeze_boss(s)
	s.freeze_t = 0
	place(s); clear_defense(s.P); s.P["comp"] = 0.5
	var t0 := s.tension
	boss_lands(s, "R_HOOKERCUT")
	_sr("player drop enters the standing-eight", s.mode == "EIGHT" and s.eight.has("beats_left"))
	var beats := 0
	for b in 3:
		var guard := 0
		while s.mode == "EIGHT" and s.eight["timer_t"] > s.eight["window_t"] and guard < 400:
			s.step({}); guard += 1
		if s.mode != "EIGHT": break
		s.step({"rise": true}); s.step({"rise": false}); beats += 1
	_sr("standing-eight: three rise beats on the count get up",
		s.mode == "FIGHT" and s.P["comp"] > 0.0 and s.P["no_regen_t"] > 0 and beats == 3,
		"comp=%.1f halt=%d ticks" % [s.P["comp"], s.P["no_regen_t"]])
	_sr("crowd surge pays tension on the rise", s.tension > t0, "%.1f -> %.1f" % [t0, s.tension])

	# ---- guard ----
	place(s); freeze_boss(s); s.P["comp"] = s.P["comp_max"]; s.freeze_t = 0
	s.P["guard"] = 1.0; s.P["guard_open_t"] = 0
	run_ticks(s, 30, {"block": true})                  # held past the 150ms perfect window
	boss_lands(s, "R_STRAIGHT")
	_sr("guard break opens the fighter", s.P["guard_open_t"] > 0, "%d ticks" % s.P["guard_open_t"])
	run_ticks(s, s.P["guard_open_t"] + 2)
	_sr("guard refills after the break", s.P["guard"] >= float(s.T["guard"]["break_refill"]) - 1.0, "%.1f" % s.P["guard"])
	place(s); s.P["counter_t"] = 0; s.P["guard"] = s.P["guard_max"]; s.freeze_t = 0
	s.step({"block": true})                            # pressed this tick: inside the perfect window
	boss_lands(s, "R_STRAIGHT")
	_sr("perfect block inside 150ms opens a counter window", s.P["counter_t"] > 0, "%d ticks" % s.P["counter_t"])

	# ---- hissatsu: the motion is the spellbook ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}; s.freeze_t = 0; thaw(s)
	s.tension = 100.0; s.B["comp"] = s.B["comp_max"]; s.P["counter_t"] = 0; s.events.clear()
	s.P["busy_t"] = 0; s.P["cmd"] = {}
	s.step({"punch": "R_HOOK", "lb": true})                 # wrong family for a HAYMAKER move: a normal hook
	var wrong_family: bool = s.cast.is_empty() and s.P["pending"].size() > 0 and s.tension == 100.0
	clear_defense(s.B); land(s); thaw(s)
	s.P["busy_t"] = 0; s.P["cmd"] = {}
	s.step({"punch": "R_HOOKERCUT", "lb": true})            # LB + haymaker flick = Aurora Borealis Breaker (T1, 35)
	var armed: bool = s.cast.size() > 0 and s.cast["who"] == "P" and str(s.cast["move"]["name"]) == "Aurora Borealis Breaker"
	_sr("hissatsu casts on LB + its family's motion; the wrong family throws the normal punch", wrong_family and armed)
	var t1_cost := 35.0 * (0.9 if s._beats("element", s.P["element"], s.B["element"]) else 1.0)
	_sr("hissatsu costs its tier's Tension (T1 = 35%s), never the whole bar" % (" x0.9, his element is beaten" if t1_cost < 35.0 else ""), absf(s.tension - (100.0 - t1_cost)) < 0.01, "%.1f left" % s.tension)
	_sr("the caster is locked for the cinematic windup (%d ticks)" % int(s.cast["total"]), s.P["busy_t"] >= int(s.cast["total"]))
	resolve_cast(s)
	_sr("ABB resolves from its record: x2.5 packet + ropes displacement + freeze state",
		count_events(s.events, "hit", {"hissatsu": true}) == 1 and count_events(s.events, "displace", {"toward": "ROPES"}) == 1 and s.states["B"].size() == 0 and s.states["P"].has("arena_freeze_vfx"))
	thaw(s); s.tension = 10.0; s.P["busy_t"] = 0; s.P["cmd"] = {}; s.events.clear()
	s.step({"punch": "R_HOOKERCUT", "lb": true})
	_sr("insufficient Tension: the motion executes as its normal punch (never a whiff-lockout)", s.cast.is_empty() and s.P["pending"].get("row", "") == "R_HOOKERCUT")
	clear_defense(s.B); land(s); s.freeze_t = 0

	# ---- boss agent live ----
	place(s); clear_defense(s.P); s.P["comp"] = s.P["comp_max"]; s.P["counter_t"] = 0
	s.bstate = "IDLE"; s.btimer = 1; s.events.clear()
	run_ticks(s, 480)
	var tells := count_events(s.events, "tell")
	var boss_actions := count_events(s.events, "boss_act")
	_sr("boss agent runs strings on its own (4s)", tells >= 1, "tells=%d state=%s string=%s" % [tells, s.bstate, s.bstring])
	_sr("action VM executes the selected strings", boss_actions >= 1, "actions=%d" % boss_actions)

	# ---- action VM semantics ----
	s.mode = "FIGHT"; s.eight = {}; s.P["comp"] = s.P["comp_max"]; s.P["drops"] = 0   # his VM is under test, not your chin: a live 4s may have put you down
	freeze_boss(s); thaw(s); place(s, 1.0); clear_defense(s.P); clear_defense(s.B)
	var walk := s.parse_action("WALK_STRING(2_hooks)")
	var mixed := s.parse_action("MIXED_STRING(4)")
	var herd := s.parse_action("HERD(50cm)")
	_sr("VM expands composite verbs (WALK_STRING 2_hooks -> 4 acts, MIXED_STRING(4) -> 4 punches, HERD(50cm) -> 0.5m)",
		walk.size() == 4 and mixed.size() == 4 and herd.size() == 1 and absf(float(herd[0]["dist"]) - 0.5) < 0.001)
	s.bqueue = []; s.bstate = "IDLE"; s.btimer = 1 << 30
	s._boss_act(s.parse_action("COUNTER_STATE(2s)")[0])
	var cs_armed: bool = s.B["counter_state_t"] > 0 and s.B["guard_t"] > 0
	s.P["busy_t"] = 0; s.P["cmd"] = {}; s.tokens = []; s.flags = {}
	s.step({"punch": "L_STRAIGHT"}); s.B["dodge_plan"] = []; s.B["dodge_at"] = 0; s.B["dodge"] = ""
	land(s)
	_sr("VM COUNTER_STATE: a punch into his guard is answered at once", cs_armed and s.bstate == "ACTING" and s.bqueue.size() >= 1 and s.bqueue[0]["kind"] == "punch",
		"state=%s queue=%d" % [s.bstate, s.bqueue.size()])
	freeze_boss(s); thaw(s); place(s, 1.0); s.P["pos"] = Vector2(2.0, 0.5); s.B["pos"] = Vector2(2.0, -0.5)
	var px0: float = s.P["pos"].x
	s._boss_act(s.parse_action("CLINCH_ATTEMPT")[0])
	var started: bool = s.clinch.size() > 0 and s.clinch["by"] == "B" and s.P["busy_t"] >= s.clinch_t
	run_ticks(s, s.clinch_t + 2)                      # no taps: he wins the scramble
	_sr("VM CLINCH_ATTEMPT starts a scramble; untapped, he wins and drags you ropeward", started and s.clinch.is_empty() and s.P["pos"].x > px0,
		"x %.2f -> %.2f" % [px0, s.P["pos"].x])
	# ---- sensors parsed from the pattern's own hooks ----
	freeze_boss(s); thaw(s); place(s); clear_defense(s.P); s.P["comp"] = s.P["comp_max"]; s.events.clear(); s.passive_t = 0
	var need := TNBSim.ms(float(s.sensors["passive_s"]) * 1000.0)
	var fired_at := -1
	for i in need * 2:
		s.step({})
		if fired_at < 0 and count_events(s.events, "sensor", {"name": "player_passive"}) > 0: fired_at = i + 1
		if fired_at > 0 or s.mode != "FIGHT": break
	_sr("sensor: player_passive fires at this boss's own threshold (%.0fs), never early" % float(s.sensors["passive_s"]),
		fired_at >= need, "fired after %d steps (threshold %d fight ticks)" % [fired_at, need])

	# ---- dual layer: card -> corner -> rotation ----
	s.coach_on = false                                            # the flow itself; the rival corner has its own stage (PAC-060)
	s.mode = "FIGHT"; s.eight = {}
	s.contributed = 30.0; s.tension = 42.0
	var ep_lead_now: bool = (s.ep_p - int(s.seg_score0[2])) > (s.ep_b - int(s.seg_score0[3]))   # NP_05 s2: the segment win pays +5 if you took it on EP
	s._end_segment("smoke-forced")
	_sr("segment end shows the 4s broadcast card first", s.mode == "CARD" and s.card_t == TNBSim.ms(4000) and count_events(s.events, "seg_card") >= 1)
	_sr("relay CHARGED at >=25 contributed (chain 1)", s.charged and s.relay_chain == 1)
	run_ticks(s, TNBSim.ms(4000) - 1)
	var still_card: bool = s.mode == "CARD"
	s.step({})
	_sr("the card times out into the CORNER (45s, 2 actions)", still_card and s.mode == "CORNER" and int(s.corner["t"]) == TNBSim.ms(45000) and int(s.corner["actions_left"]) == 2)
	s.step({"corner": 1})
	_sr("send: rotation loads the next fighter", s.pname() == "PRIYA", s.pname())
	_sr("tension persists across segments (+5 if the segment was won on EP)", s.tension == 42.0 + (5.0 if ep_lead_now else 0.0), "%.0f" % s.tension)
	var half_cost := 5.0 * (0.9 if s._beats("element", s.P["element"], s.B["element"]) else 1.0)
	_sr("CHARGED entrance: 10s surge (+10%% feet), first hissatsu half cost, T3 unlocked", s.P["charge_t"] > 0 and absf(s.hiss_cost(s.player_move()) - half_cost) < 0.01 and s.t3_unlocked and absf(s._speed_mult("P") - 1.1) < 0.001, "Marginalia T0 costs %.1f" % s.hiss_cost(s.player_move()))
	s.contributed = 0.0
	s._end_segment("smoke-forced"); s.step({"corner": 1})
	_sr("no relay under 25 contributed; an empty segment breaks the chain", not s.charged and s.relay_chain == 0)
	var ok_staff := s.corner_action({"kind": "staff", "id": "loosen_up"})
	s.step({"corner": 1})
	_sr("corner staff: Loosen Up sends MARCUS out at a 110 stamina cap", ok_staff and s.pname() == "MARCUS" and absf(s.P["stamina"] - 110.0) < 0.01, "%s stam=%.0f" % [s.pname(), s.P["stamina"]])
	s.score_p = 2; s.score_b = 1; s.ep_p = 40; s.ep_b = 22
	s._end_segment("smoke-forced")
	_sr("dual verdict on score after 3 segments", s.mode == "OVER" and "MILLBROOK WINS" in s.feed)
	s.new_dual()
	_sr("new dual resets to R1", s.mode == "FIGHT" and s.seg_idx == 0 and s.drops_p == 0)
	if gauge_boss: s.wall["B"] = {}

	# ---- zones ----
	var zc := s.zone(Vector2(0, 1.0)) == "CENTER" and s.zone(Vector2(2.0, 0)) == "MID" \
		and s.zone(Vector2(3.3, 0)) == "ROPES" and s.zone(Vector2(3.3, 3.3)) == "CORNER"
	_sr("zone classification (4 zones)", zc)
	freeze_boss(s); clear_defense(s.P); s.trapped_p = false
	s.P["comp"] = s.P["comp_max"]; s.P["pos"] = Vector2(0, 0.8); s.B["pos"] = Vector2(0, -0.8)
	boss_lands(s, "R_STRAIGHT")
	var d_center: float = s.P["comp_max"] - s.P["comp"]
	s.P["comp"] = s.P["comp_max"]; s.P["pos"] = Vector2(3.3, 3.3); s.B["pos"] = Vector2(3.3, 3.3) - Vector2(1, 1).normalized() * 1.6
	boss_lands(s, "R_STRAIGHT")
	var d_corner: float = s.P["comp_max"] - s.P["comp"]
	_sr("corner damage x1.5 vs center", absf(d_corner / maxf(0.01, d_center) - 1.5) < 0.05, "%.1f/%.1f" % [d_corner, d_center])

	# ---- trap ----
	s.P["pos"] = Vector2(3.3, 3.3); s.B["pos"] = Vector2(2.2, 2.2); s.trapped_p = true; s.P["comp"] = s.P["comp_max"]
	clear_defense(s.P); s._set_dodge(s.P, "SLIP", 1)
	boss_lands(s, "R_STRAIGHT")
	var base_w := TNBSim.ms(float(s.T["counter_windows_ms"]["slip"]["base"]))
	_sr("trapped slip window x1.4", s.P["counter_t"] == int(base_w * 1.4), "%d ticks" % s.P["counter_t"])
	clear_defense(s.P); s.P["counter_t"] = 0; s.trapped_p = false; s.pinned_p_t = 0

	# ---- herding ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}; s.freeze_t = 0
	var by0: float = s.B["pos"].y
	throw_clean(s, "L_STRAIGHT")
	_sr("landed punches herd him back", s.B["pos"].y < by0, "%.2f -> %.2f" % [by0, s.B["pos"].y])
	place(s); clear_defense(s.P); s.P["comp"] = s.P["comp_max"]
	var py0: float = s.P["pos"].y
	boss_lands(s, "R_STRAIGHT")
	_sr("his punches herd you back", s.P["pos"].y > py0, "%.2f -> %.2f" % [py0, s.P["pos"].y])

	# ---- C2 in play: dodges resolve by geometry, not by table ----
	place(s, 1.4); clear_defense(s.P); s.P["comp"] = s.P["comp_max"]; s.P["counter_t"] = 0     # 1.4m: inside every style's uppercut (a swarmer's is 1.575m)
	s._set_dodge(s.P, "SLIP", 1); boss_lands(s, "R_STRAIGHT")
	_sr("C2 slip evades the straight + opens a window", s.P["comp"] == s.P["comp_max"] and s.P["counter_t"] > 0)
	clear_defense(s.P); s.P["counter_t"] = 0
	s._set_dodge(s.P, "DUCK", 1); boss_lands(s, "R_UPPERCUT")
	_sr("C2 duck eats the uppercut", s.P["comp"] < s.P["comp_max"])
	clear_defense(s.P); s.P["comp"] = s.P["comp_max"]; s.trapped_p = true; s.pinned_p_t = 3200
	s._set_dodge(s.P, "WEAVE", 1); boss_lands(s, "R_HOOK")
	_sr("C2 weave-away evades the hook + escapes the trap", s.P["comp"] == s.P["comp_max"] and not s.trapped_p and s.pinned_p_t == 0)
	clear_defense(s.P); s.P["counter_t"] = 0

	# ---- counter teeth ----
	place(s); freeze_boss(s); thaw(s)
	s.P["busy_t"] = 0; s.P["cmd"] = {}; s.P["counter_t"] = 60
	s.step({"punch": "R_STRAIGHT"})
	_sr("counter window is consumed by the attempt", s.P["counter_t"] == 0 and s.P["pending"].get("counter", false))
	clear_defense(s.B); land(s)
	var landed := false
	s.B["comp"] = s.B["comp_max"]
	for i in 10:
		thaw(s); s.bstate = "TELL"; s.btimer = 1 << 30; place(s)
		s.P["busy_t"] = 0; s.P["cmd"] = {}; s.P["counter_t"] = 60; s.tokens = []; s.flags = {}
		s.step({"punch": "R_STRAIGHT"}); land(s)       # boss read left live: p_read = 0.05 * 0.25
		if s.B["comp"] < s.B["comp_max"]: landed = true; break
	_sr("counter lands through the fear-reduced read", landed)

	# ================= PAC-054: sensors fire at threshold, never early ==========
	# 1. tempo lock (Chiamaka): six equal punch intervals; five are not enough
	var t1 := make_sim(8, 7); quiet(t1); place(t1)
	var early_ok := true
	for i in 7:
		t1.P["busy_t"] = 0; t1.P["cmd"] = {}; thaw(t1)
		var target: int = t1.tick + (60 if i > 0 else 0)
		while t1.tick < target: t1.step({})
		t1.step({"punch": "L_STRAIGHT"}); clear_defense(t1.B)
		if i < 6 and sensor_count(t1, "player_locks_to_single_tempo") > 0: early_ok = false
	_sr("sensor locks_to_single_tempo: 6 equal intervals fire, 5 never", early_ok and sensor_count(t1, "player_locks_to_single_tempo") == 1)
	var t1b := make_sim(8, 7); quiet(t1b); place(t1b)
	for gap in [0, 60, 90, 60, 120, 60, 90]:
		t1b.P["busy_t"] = 0; t1b.P["cmd"] = {}; thaw(t1b)
		var target2: int = t1b.tick + gap
		while t1b.tick < target2: t1b.step({})
		t1b.step({"punch": "L_STRAIGHT"}); clear_defense(t1b.B)
	_sr("sensor locks_to_single_tempo: a varied cadence never fires", sensor_count(t1b, "player_locks_to_single_tempo") == 0)
	# 2. neutral reset attempt (Deshawn): a full second out past engagement, not leading
	var t2 := make_sim(10, 7); quiet(t2); t2.P["pos"] = Vector2(0, 1.5); t2.B["pos"] = Vector2(0, -1.5)
	run_ticks(t2, TNBSim.ms(1000) - 1, {"move": Vector2(0, 1)})
	var n_early := sensor_count(t2, "player_neutral_reset_attempt")
	t2.step({"move": Vector2(0, 1)})
	_sr("sensor neutral_reset_attempt: fires on the 120th tick out of range, not the 119th", n_early == 0 and sensor_count(t2, "player_neutral_reset_attempt") == 1)
	# 3. casting a Moreau native at Remy (library house_id vs pattern META house)
	var lu: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu[0]["hissatsu"] = "Fevrier"
	var t3 := make_sim(20, 7, lu); freeze_boss(t3); thaw(t3); place(t3); t3.events.clear()
	t3.tension = 100.0; t3.P["busy_t"] = 0; t3.P["cmd"] = {}
	t3.step({"punch": "R_HOOKERCUT", "lb": true})
	_sr("sensor casts_moreau_native: Fevrier at Remy fires and forces Ingot (S3)",
		sensor_count(t3, "player_casts_moreau_native") == 1 and t3.bstate == "TELL" and t3.bstring == "S3", "state=%s string=%s" % [t3.bstate, t3.bstring])
	var t3b := make_sim(20, 7); freeze_boss(t3b); thaw(t3b); place(t3b); t3b.events.clear()
	t3b.tension = 100.0; t3b.P["busy_t"] = 0; t3b.P["cmd"] = {}
	t3b.step({"punch": "R_HOOKERCUT", "lb": true})
	_sr("sensor casts_moreau_native: Aurora Borealis Breaker (no house) never fires", sensor_count(t3b, "player_casts_moreau_native") == 0 and t3b.bstate != "TELL")
	# 4. Marta drops her hands when you refuse to lead; a punch into it is the bait
	var t4 := make_sim(18, 7); thaw(t4); place(t4); t4.events.clear()
	t4.bstate = "IDLE"; t4.btimer = 1; t4.passive_t = TNBSim.ms(3000)
	var stance_seen := false; var guard := 0
	while not stance_seen and guard < 2400:
		t4.step({}); guard += 1
		if t4.hands_down_t > 0: stance_seen = true
	var no_fire_yet: bool = sensor_count(t4, "trap_stance_hands_down") == 0
	t4.P["busy_t"] = 0; t4.P["cmd"] = {}; thaw(t4)
	t4.step({"punch": "L_STRAIGHT"})
	_sr("sensor trap_stance_hands_down: she offers the stance idle; a punch into it forces Mirror (S1)",
		stance_seen and no_fire_yet and sensor_count(t4, "trap_stance_hands_down") == 1 and t4.bstring == "S1" and t4.bstate == "TELL",
		"stance after %d ticks, state=%s" % [guard, t4.bstate])
	var t4b := make_sim(18, 7); quiet(t4b); place(t4b); t4b.hands_down_t = 0
	t4b.P["busy_t"] = 0; t4b.P["cmd"] = {}; t4b.step({"punch": "L_STRAIGHT"})
	_sr("sensor trap_stance_hands_down: hands up, no bait", sensor_count(t4b, "trap_stance_hands_down") == 0)
	# 5. Tam's fake tells in phase 1; reacting to one is the bait
	var t5 := make_sim(22, 7); thaw(t5); place(t5); t5.events.clear(); t5.bstate = "IDLE"; t5.btimer = 1
	run_ticks(t5, TNBSim.ms(20000))
	var fakes := count_events(t5.events, "tell", {"fake": true})
	var t5b := make_sim(22, 7); thaw(t5b); place(t5b); t5b.events.clear()
	t5b.bstate = "FAKE"; t5b.bstring = "S1"; t5b.btimer = 200
	run_ticks(t5b, 30)
	var quiet_ok: bool = sensor_count(t5b, "player_reacts_to_fake_tell") == 0
	t5b.step({"dodge": "SLIP_L"})
	_sr("sensor reacts_to_fake_tell: phase-1 fakes exist (%d in 20s); ignoring one is safe; flinching forces S2" % fakes,
		fakes >= 1 and quiet_ok and sensor_count(t5b, "player_reacts_to_fake_tell") == 1 and t5b.bstate == "TELL" and t5b.bstring == "S2")
	var t5c := make_sim(22, 7); thaw(t5c); place(t5c); t5c.events.clear(); t5c.clock_t = TNBSim.ms(90000) - TNBSim.ms(31000); t5c.bstate = "IDLE"; t5c.btimer = 1   # clock>30: phase 2 arrives through the sim and runs its lines
	run_ticks(t5c, TNBSim.ms(20000))
	_sr("sensor reacts_to_fake_tell: phase 2 (clock>30s) retires the borrowed clothes - 'true_pattern_only' (0 fakes in 20s, S1 retired)", t5c.bphase == 2 and t5c.btrue_pattern and count_events(t5c.events, "tell", {"fake": true}) == 0 and not t5c._phase_ok("S1"))
	# 6. audio-assist reliance (Choir): three sub-300ms reactions WITH the assist on
	for assist in [true, false]:
		var t6 := make_sim(15, 7); quiet(t6); place(t6)
		var early6 := true
		for i in 3:
			t6._force_string("S1", 1.0, false)
			run_ticks(t6, 4, {"audio_assist": assist})
			t6.step({"audio_assist": assist, "dodge": "DUCK"})
			if i < 2 and sensor_count(t6, "player_audio_assist_reliance") > 0: early6 = false
			t6.bstate = "IDLE"; t6.btimer = 1 << 30
			run_ticks(t6, 40, {"audio_assist": assist})
		if assist:
			_sr("sensor audio_assist_reliance: fires on the 3rd fast reaction with the assist on, not the 2nd", early6 and sensor_count(t6, "player_audio_assist_reliance") == 1)
		else:
			_sr("sensor audio_assist_reliance: the same reactions without the assist never fire", sensor_count(t6, "player_audio_assist_reliance") == 0)
	# 7. clinch input spam (Alfie) + the referee's holding call
	var t7 := make_sim(5, 7); quiet(t7); place(t7, 1.0)
	var ep0: int = t7.ep_p
	t7.step({"clinch": true}); run_ticks(t7, 29); t7.step({"clinch": true}); run_ticks(t7, 29)
	var early7: bool = sensor_count(t7, "player_clinch_input_spam") == 0 and t7.ep_p == ep0
	t7.step({"clinch": true})
	_sr("sensor clinch_input_spam: third grab in 8s fires + referee holding call (-2 EP); two do not",
		early7 and sensor_count(t7, "player_clinch_input_spam") == 1 and t7.ep_p == ep0 - 2 and count_events(t7.events, "referee") == 1)
	# 8. sprint approach: 0.8m burst toward him, -4 stamina
	var t8 := make_sim(18, 7); quiet(t8); place(t8, 2.4)
	var st0: float = t8.P["stamina"]; var d8: float = t8.P["pos"].distance_to(t8.B["pos"])
	t8.step({"sprint": true})
	_sr("sensor sprint_approach: a sprint-step toward him fires; 0.8m closed, -4 stamina",
		sensor_count(t8, "player_sprint_approach") == 1 and absf((d8 - t8.P["pos"].distance_to(t8.B["pos"])) - 0.8) < 0.05 and absf(st0 - t8.P["stamina"]) > 3.9,
		"closed %.2fm" % (d8 - t8.P["pos"].distance_to(t8.B["pos"])))
	# 9. straight-line retreat: 1.2m of backing without an angle
	var t9 := make_sim(19, 7); quiet(t9); place(t9, 1.6)
	var fired_at_d := -1.0; var prev_d := 0.0
	for i in 400:
		prev_d = t9.retreat_d
		t9.step({"move": Vector2(0, 1)})
		if sensor_count(t9, "player_straight_line_retreat") > 0: fired_at_d = prev_d; break
	_sr("sensor straight_line_retreat: fires on the step that completes 1.2m, never before", fired_at_d >= 0.0 and fired_at_d < 1.2 and fired_at_d > 1.2 - 0.05, "%.3fm before the firing step" % fired_at_d)
	var t9b := make_sim(19, 7); quiet(t9b); place(t9b, 1.6)
	run_ticks(t9b, 300, {"move": Vector2(0.8, 0.6)})
	_sr("sensor straight_line_retreat: an angled retreat never fires", sensor_count(t9b, "player_straight_line_retreat") == 0)
	# 10. back-step chain (Deshawn): three sprint-steps away inside 4s
	var t10 := make_sim(10, 7); quiet(t10); place(t10, 1.2)
	for i in 3:
		t10.step({"sprint": true, "move": Vector2(0, 1)})
		if i < 2 and sensor_count(t10, "player_backstep_chain3") > 0: early_ok = false
		run_ticks(t10, 59)
		t10.P["pos"] = Vector2(0, 0.6); t10.B["pos"] = Vector2(0, -0.6)
	_sr("sensor backstep_chain3: the third back-step fires, the second does not", early_ok and sensor_count(t10, "player_backstep_chain3") == 1)
	# 11. rope backing (Cassidy): backing INTO the ropes vs sliding along into them
	var t11 := make_sim(0, 7); quiet(t11); t11.P["pos"] = Vector2(0, 2.8); t11.B["pos"] = Vector2(0, 1.2); t11.last_zone_p = "MID"
	run_ticks(t11, 60, {"move": Vector2(0, 1)})
	var t11b := make_sim(0, 7); quiet(t11b); t11b.P["pos"] = Vector2(1.6, 2.5); t11b.B["pos"] = Vector2(1.6, 0.9); t11b.last_zone_p = "MID"
	for i in 90:                                       # he stays square to you while you slide along the rope line
		t11b.B["pos"] = Vector2(t11b.P["pos"].x, 0.9)
		t11b.step({"move": Vector2(-1, 0)})
	_sr("sensor rope_backing: backing onto the ropes fires; sliding sideways onto them is only rope_touch",
		sensor_count(t11, "player_rope_backing") == 1 and sensor_count(t11, "player_rope_touch") == 1 and sensor_count(t11b, "player_rope_backing") == 0 and sensor_count(t11b, "player_rope_touch") == 1)
	# 12. referee ladder: Alfie banks exactly two warnings, never the third; warnings_banked==2 is his phase 2
	var t12 := make_sim(5, 7); quiet(t12); place(t12, 1.0)
	var ep_b0: int = t12.ep_b
	var w1 := 0; var w2 := 0; var w3 := 0
	for i in 3:
		place(t12, 1.0); t12._boss_act(t12.parse_action("CLINCH_ATTEMPT")[0])
		run_ticks(t12, t12.clinch_t + 2)
		if i == 0: w1 = t12.bwarnings
		if i == 1: w2 = t12.bwarnings
		if i == 2: w3 = t12.bwarnings
		t12.bstate = "IDLE"; t12.btimer = 1; t12.step({}); freeze_boss(t12)
	_sr("referee: Alfie banks warning 1 (free), warning 2 (-5 EP), and never a third", w1 == 1 and w2 == 2 and w3 == 2 and t12.ep_b == ep_b0 - 5, "warnings %d/%d/%d ep_b %d" % [w1, w2, w3, t12.ep_b])
	_sr("phase trigger warnings_banked==2 reached (dirty flirtation stops)", t12.bphase == 2, "phase=%d" % t12.bphase)
	var pc2 := t12.phase_coverage(t12.patterns)
	_sr("phase-trigger vocabulary fully executable (13/13 forms)", pc2["unknown"].is_empty(), "%d forms" % pc2["known"].size())
	# 13. the clinch scramble from the player's side: taps on the cue win position or a reset
	var t13 := make_sim(0, 7); quiet(t13); place(t13, 1.0)
	t13.step({"clinch": true})
	var began: bool = t13.clinch.size() > 0 and t13.clinch["by"] == "P"
	var cues: Array = t13.clinch["cues"].duplicate(); var wins: Array = t13.clinch["windows"].duplicate()
	var bx0: Vector2 = t13.B["pos"]
	play_clinch(t13, "sides")
	var won_pos: bool = count_events(t13.events, "clinch_end", {"winner": "P"}) == 1 and t13.B["pos"] != bx0
	var t13b := make_sim(0, 7); quiet(t13b); place(t13b, 1.0); t13b.P["stamina"] = 50.0
	t13b.step({"clinch": true}); play_clinch(t13b, "enter", true)
	var won_reset: bool = count_events(t13b.events, "clinch_end", {"winner": "P", "reset": true}) == 1 and t13b.P["stamina"] > 54.0
	_sr("clinch scramble: alternating taps on the cue win position (he is walked ropeward); ENTER parity + BODY wins a reset (+5 stamina)", began and won_pos and won_reset)
	var t13c := make_sim(0, 7); quiet(t13c); place(t13c, 1.0)
	t13c.step({"clinch": true}); play_clinch(t13c, "none")
	_sr("clinch scramble: no taps loses it (dragged ropeward)", count_events(t13c.events, "clinch_end", {"winner": "B"}) == 1)

	# ================= PAC-055: fouls both ways, the shrinking cue, the survival grab ==========
	# shrinking cue: intervals 0.8x each, windows 30% of the interval, floored by RFX; the last cue is RFX's
	var shrink_ok := true
	for k in range(1, cues.size()):
		var iv_prev: int = int(cues[k - 1]) - (int(cues[k - 2]) if k >= 2 else 0)
		var iv: int = int(cues[k]) - int(cues[k - 1])
		if iv >= iv_prev: shrink_ok = false
	var floor_rory := int(lerpf(float(TNBSim.ms(80)), float(TNBSim.ms(160)), 50.0 / 99.0))
	var floored := true
	for w in wins:
		if int(w) < floor_rory: floored = false
	_sr("clinch cue shrinks (%s ticks) and every window stays above the RFX floor (%d)" % [",".join(PackedStringArray(cues.map(func(x): return str(x)))), floor_rory], shrink_ok and floored and int(wins[-1]) == floor_rory,
		"windows " + ",".join(PackedStringArray(wins.map(func(x): return str(x)))))
	var lu2: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu2[0]["stats"]["RFX"] = 70
	var t14 := make_sim(0, 7, lu2); quiet(t14); place(t14, 1.0); t14.step({"clinch": true})
	_sr("RFX decides the last cue: RFX 70 gets a wider final window than RFX 50", int(t14.clinch["windows"][-1]) > int(wins[-1]), "%d vs %d ticks" % [int(t14.clinch["windows"][-1]), int(wins[-1])])
	var t15 := make_sim(0, 7); quiet(t15); place(t15, 1.0); t15.step({"clinch": true}); play_clinch(t15, "wrong")
	var t15b := make_sim(0, 7); quiet(t15b); place(t15b, 1.0); t15b.step({"clinch": true}); play_clinch(t15b, "mash")
	_sr("clinch: the wrong side spends the cue; mashing ahead of the cue locks it - both lose",
		count_events(t15.events, "clinch_miss", {"why": "wrong_side"}) >= 2 and count_events(t15.events, "clinch_end", {"winner": "B"}) == 1
		and count_events(t15b.events, "clinch_miss", {"why": "early"}) >= 1 and count_events(t15b.events, "clinch_end", {"winner": "B"}) == 1)
	# fouls by geometry: player side
	var f1 := make_sim(0, 7); quiet(f1); place(f1, 1.4)
	f1.P["busy_t"] = 0; f1.P["cmd"] = {}
	f1.step({"punch": "R_STRAIGHT", "body": true}); clear_defense(f1.B); f1.B["dodge"] = "LEAN"; f1.B["dodge_t"] = 999
	land(f1)
	var loss_foul := 0.0
	for e in f1.events:
		if e["kind"] == "hit": loss_foul = float(e["dmg"])
	var lowblow: bool = count_events(f1.events, "foul", {"who": "P", "foul": "low_blow"}) == 1 and f1.pwarnings == 1
	thaw(f1); place(f1, 1.4); clear_defense(f1.B); f1.events.clear()
	f1.P["busy_t"] = 0; f1.P["cmd"] = {}; f1.tokens = []; f1.flags = {}
	f1.step({"punch": "R_STRAIGHT", "body": true}); clear_defense(f1.B)
	land(f1)
	var loss_clean := 0.0
	for e in f1.events:
		if e["kind"] == "hit": loss_clean = float(e["dmg"])
	_sr("foul: a body punch into his lean-back is a LOW BLOW (half damage, warning 1, no EP); the same punch clean is not",
		lowblow and count_events(f1.events, "foul") == 0 and absf(loss_foul * 2.0 - loss_clean) < 0.01, "%.2f vs %.2f" % [loss_foul, loss_clean])
	thaw(f1); place(f1, 1.4); f1.events.clear(); f1.P["busy_t"] = 0; f1.P["cmd"] = {}; f1.tokens = []; f1.flags = {}
	f1.step({"punch": "R_STRAIGHT"}); clear_defense(f1.B); f1.B["dodge"] = "LEAN"; f1.B["dodge_t"] = 999; land(f1)
	_sr("foul: a head punch into the lean-back is legal", count_events(f1.events, "foul") == 0 and count_events(f1.events, "hit", {"on": "B"}) == 1)
	var f2 := make_sim(0, 7); quiet(f2); place(f2, 1.4)
	var results := {}
	for row in ["R_FLARED", "R_UPPERCUT", "R_STRAIGHT"]:
		thaw(f2); place(f2, 1.4); f2.events.clear(); f2.P["busy_t"] = 0; f2.P["cmd"] = {}; f2.tokens = []; f2.flags = {}; f2.pwarnings = 0
		f2.step({"punch": row}); clear_defense(f2.B); f2.B["dodge"] = "DUCK"; f2.B["dodge_t"] = 999; land(f2)
		results[row] = [count_events(f2.events, "hit", {"on": "B"}), count_events(f2.events, "foul", {"foul": "behind_the_head"})]
	_sr("foul: the overhand onto a ducked head is BEHIND THE HEAD; the uppercut lands clean; the straight misses",
		results["R_FLARED"] == [1, 1] and results["R_UPPERCUT"] == [1, 0] and results["R_STRAIGHT"] == [0, 0], JSON.stringify(results))
	# the ladder, player side: warning, -5 EP, DROP awarded to him
	var f3 := make_sim(0, 7); quiet(f3)
	var ep_p0: int = f3.ep_p; var sb0: int = f3.score_b; var pd0: int = f3.P["drops"]
	var rungs: Array = []
	for k in 3:
		thaw(f3); place(f3, 1.4); f3.P["busy_t"] = 0; f3.P["cmd"] = {}; f3.tokens = []; f3.flags = {}
		f3.step({"punch": "L_HOOK", "body": true}); clear_defense(f3.B); f3.B["dodge"] = "LEAN"; f3.B["dodge_t"] = 999; land(f3)
		rungs.append([f3.pwarnings, f3.ep_p - ep_p0, f3.score_b - sb0])
	_sr("referee ladder runs against the player: warning / -5 EP / DROP awarded (no knockdown counted, fight continues)",
		rungs == [[1, 0, 0], [2, -5, 0], [3, -5, 1]] and f3.P["drops"] == pd0 and f3.mode == "FIGHT", JSON.stringify(rungs))
	# boss side: clean fighters pull it, dirty ones foul until their cap then pull
	var f4 := make_sim(0, 7); quiet(f4); place(f4, 1.4); clear_defense(f4.P); f4.P["comp"] = f4.P["comp_max"]
	f4.P["dodge"] = "LEAN"; f4.P["dodge_t"] = 999
	boss_lands(f4, "R_HOOK", 1.0, true)
	var clean_pulled: bool = count_events(f4.events, "pulled") == 1 and f4.P["comp"] == f4.P["comp_max"] and f4.bwarnings == 0
	var f5 := make_sim(5, 7); quiet(f5); place(f5, 1.4); clear_defense(f5.P); f5.P["comp"] = f5.P["comp_max"]
	f5.P["dodge"] = "LEAN"; f5.P["dodge_t"] = 999
	boss_lands(f5, "R_HOOK", 1.0, true)
	var dirty_fouled: bool = count_events(f5.events, "foul", {"who": "B", "foul": "low_blow"}) == 1 and f5.bwarnings == 1 and f5.P["comp"] < f5.P["comp_max"]
	f5.bwarnings = 2; f5.events.clear(); f5.P["comp"] = f5.P["comp_max"]; place(f5, 1.4)
	boss_lands(f5, "R_HOOK", 1.0, true)
	var dirty_capped: bool = count_events(f5.events, "pulled") == 1 and f5.bwarnings == 2 and f5.P["comp"] == f5.P["comp_max"]
	_sr("foul: a clean boss pulls the body shot off your lean; Alfie takes the low blow until his cap, then pulls it", clean_pulled and dirty_fouled and dirty_capped)
	# survival grab: a wobbled boss grabs once per segment at 0-range
	var g1 := make_sim(0, 7); quiet(g1); place(g1, 1.0); g1.B["comp"] = g1.B["comp_max"] * 0.3; g1.bstate = "IDLE"
	g1.step({})
	var grabbed: bool = g1.clinch.size() > 0 and g1.clinch["by"] == "B" and count_events(g1.events, "survival_grab") == 1 and g1.bsurvival_used
	play_clinch(g1, "none")
	place(g1, 1.0); g1.B["comp"] = g1.B["comp_max"] * 0.3; g1.bstate = "IDLE"; g1.btimer = 1 << 30; g1.events.clear()
	run_ticks(g1, 30)
	var once: bool = g1.clinch.is_empty() and count_events(g1.events, "survival_grab") == 0
	g1.mode = "FIGHT"; g1._end_segment("smoke-forced"); next_segment(g1)
	_sr("survival grab: a wobbled boss grabs at 0-range, once per segment; the next segment re-arms it", grabbed and once and not g1.bsurvival_used)
	var g2 := make_sim(0, 7); quiet(g2); place(g2, 2.0); g2.B["comp"] = g2.B["comp_max"] * 0.3; g2.bstate = "IDLE"
	run_ticks(g2, 5)
	_sr("survival grab: never from outside 0-range", g2.clinch.is_empty() and count_events(g2.events, "survival_grab") == 0)
	# wobble: movement at 70% below 35% composure
	var wb := make_sim(0, 7); quiet(wb); place(wb, 1.6); var x0: float = wb.P["pos"].x
	run_ticks(wb, 20, {"move": Vector2(1, 0)}); var d_full: float = absf(wb.P["pos"].x - x0)
	place(wb, 1.6); wb.P["comp"] = wb.P["comp_max"] * 0.3; x0 = wb.P["pos"].x
	run_ticks(wb, 20, {"move": Vector2(1, 0)}); var d_wob: float = absf(wb.P["pos"].x - x0)
	_sr("wobble: below 35pct composure the feet move at 70pct", absf(d_wob / maxf(0.001, d_full) - 0.7) < 0.02, "%.3f/%.3f" % [d_wob, d_full])

	# ================= PAC-056: the hissatsu VM executes the library ==========
	var ec := s.effect_coverage(s.library)
	_sr("effect VM has a handler for every effect type / STATE / BUFF in the library (%d moves, %d sealed)" % [ec["moves"], ec["sealed"]],
		ec["unknown"].is_empty() and ec["moves"] == 87 and ec["sealed"] == 3, "" if ec["unknown"].is_empty() else JSON.stringify(ec["unknown"]))
	var desp_ok := 0; var desp_absent := 0; var desp_bad: Array = []
	for name in s.patterns:
		var d = s.patterns[name].get("desperation")
		if d == null or d.has("authored_absent"): desp_absent += 1
		elif s.library.has(str(d["move"])): desp_ok += 1
		else: desp_bad.append(name)
	_sr("every boss desperation resolves to a library record (%d cast by name, %d authored-absent)" % [desp_ok, desp_absent], desp_bad.is_empty() and desp_ok + desp_absent == 24, JSON.stringify(desp_bad))
	# interrupts: Yuri's Grain Elevator (RISE, 1500ms windup, window 700ms)
	var h1 := make_sim(1, 7); quiet(h1); place(h1, 1.4)
	var armed_b := boss_desperation(h1)
	var move_named: bool = armed_b and str(h1.cast["move"]["name"]) == "Grain Elevator" and int(h1.cast["total"]) == TNBSim.ms(1500)
	var ten0: float = h1.tension
	h1.P["busy_t"] = 0; h1.P["cmd"] = {}; h1.step({"punch": "L_STRAIGHT"}); clear_defense(h1.B); land(h1)   # jab lands ~20 ticks in: inside the window
	_sr("boss desperation casts BY NAME from the library; a jab inside the window breaks it (+5 Tension, flash window)",
		move_named and h1.cast.is_empty() and count_events(h1.events, "cast_interrupted") == 1 and h1.tension > ten0 and h1.P["flash_t"] > 0)
	var h2 := make_sim(1, 7); quiet(h2); place(h2, 1.4); boss_desperation(h2)
	var hm_h2: float = h2.hiss_mult("B")                  # the rings on his native: read while the cast knows its move
	run_ticks(h2, TNBSim.ms(700) + 5)                     # past the window
	var v_g0: float = h2.P["guard"]
	h2.P["busy_t"] = 0; h2.P["cmd"] = {}; h2.step({"punch": "L_STRAIGHT"}); clear_defense(h2.B); land(h2)
	var late_ok: bool = count_events(h2.events, "cast_interrupted") == 0
	resolve_cast(h2)
	_sr("after the window the cast is committed: it resolves (DMG x2.0 + SHRED 40 x%.2f rings on your guard)" % hm_h2, late_ok and count_events(h2.events, "hit", {"hissatsu": true}) == 1 and absf((v_g0 - h2.P["guard"]) - 40.0 * hm_h2) < 0.01, "guard %.1f -> %.1f" % [v_g0, h2.P["guard"]])
	var h3 := make_sim(1, 7); quiet(h3); place(h3, 1.4); boss_desperation(h3)
	h3.P["busy_t"] = 0; h3.P["cmd"] = {}; h3.step({"punch": "R_HOOK"}); clear_defense(h3.B); land(h3)
	_sr("only jab-class punches interrupt: a hook in the window does not", h3.cast.size() > 0 and count_events(h3.events, "cast_interrupted") == 0)
	# s9 at resolve: full / perfect slip 40% / block 60% + heavy shred
	var v_full := make_sim(1, 7); quiet(v_full); place(v_full, 1.4); boss_desperation(v_full); clear_defense(v_full.P); resolve_cast(v_full)
	var v_d_full := hit_dmg(v_full, "P")
	var slipd := make_sim(1, 7); quiet(slipd); place(slipd, 1.4); boss_desperation(slipd)
	run_ticks(slipd, int(slipd.cast["t"]) - 10); slipd.P["dodge"] = "SLIP"; slipd.P["dodge_dir"] = 1; slipd.P["dodge_t"] = 40; resolve_cast(slipd)
	var d_slip := hit_dmg(slipd, "P")
	var blk := make_sim(1, 7); quiet(blk); place(blk, 1.4); boss_desperation(blk)
	var hm_blk: float = blk.hiss_mult("B")
	run_ticks(blk, int(blk.cast["t"]) - 30); var gb0: float = blk.P["guard"]
	while blk.cast.size() > 0: blk.step({"block": true})
	var d_blk := hit_dmg(blk, "P")
	_sr("s9 resolve: full %.1f, perfect slip chips 40%% (%.1f), block takes 60%% + heavy shred (%.1f, guard -50%% on top of the move's own SHRED 40)" % [v_d_full, d_slip, d_blk],
		v_d_full > 0.0 and absf(d_slip - v_d_full * 0.4) < 0.05 and absf(d_blk - v_d_full * 0.6) < 0.05 and absf((gb0 - blk.P["guard"]) - (blk.P["guard_max"] * 0.5 + 40.0 * hm_blk)) < 1.0,
		"counter window after the slip: %d ticks" % slipd.P["counter_t"])
	# PISTON profile: slip full-evades, block 70% (Rush Hour, 5 hits)
	var rh := make_sim(10, 7); quiet(rh); place(rh, 1.4); boss_desperation(rh); clear_defense(rh.P); resolve_cast(rh)
	var rh_hits := count_events(rh.events, "hit", {"hissatsu": true})
	var rh2 := make_sim(10, 7); quiet(rh2); place(rh2, 1.4); boss_desperation(rh2)
	run_ticks(rh2, int(rh2.cast["t"]) - 10); rh2.P["dodge"] = "SLIP"; rh2.P["dodge_dir"] = 1; rh2.P["dodge_t"] = 40; resolve_cast(rh2)
	_sr("Rush Hour lands as 5 packets; the PISTON profile lets a perfect slip evade in full", rh_hits == 5 and hit_dmg(rh2, "P") == 0.0 and count_events(rh2.events, "hit", {"outcome": "evaded"}) == 5 and rh.states["P"].has("guard_regen_minus1"))
	# walls: Marta's Premiere Neige is not interruptible; it walls your punches for 5s; a T1 cast breaks it at cost parity
	var mw := make_sim(18, 7); quiet(mw); place(mw, 1.4); boss_desperation(mw)
	var not_int: bool = not bool(mw.cast["interruptible"])
	mw.P["busy_t"] = 0; mw.P["cmd"] = {}; mw.step({"punch": "L_STRAIGHT"}); clear_defense(mw.B); land(mw)
	var still_casting: bool = mw.cast.size() > 0
	resolve_cast(mw)
	var wall_up: bool = int(mw.wall["B"].get("timed_t", 0)) > 0 and mw.states["B"].has("auto_slip")
	thaw(mw); mw.P["busy_t"] = 0; mw.P["cmd"] = {}; mw.events.clear(); mw.tokens = []; mw.flags = {}
	mw.step({"punch": "R_HOOK"}); clear_defense(mw.B); land(mw)
	var v_walled: bool = count_events(mw.events, "walled") == 1 and hit_dmg(mw, "B") == 0.0
	mw.tension = 100.0; thaw(mw); mw.P["busy_t"] = 0; mw.P["cmd"] = {}; mw.events.clear()
	mw.step({"punch": "R_HOOKERCUT", "lb": true}); resolve_cast(mw)
	var v_broke: bool = count_events(mw.events, "wall_broken") == 1 and int(mw.wall["B"].get("timed_t", 0)) == 0 and hit_dmg(mw, "B") == 0.0
	_sr("WALL: not interruptible; your punches are walled; a T1 cast breaks it at cost parity (no damage either way)", not_int and still_casting and wall_up and v_walled and v_broke)
	# perfect WALL negates: the player raises Premiere Neige (LB + RT 400ms), then eats a T1 cast into it
	var pw := with_move(1, 7, "Premiere Neige")
	var cast_ok := cast_player(pw)
	resolve_cast(pw)
	var my_wall: bool = cast_ok and int(pw.wall["P"].get("timed_t", 0)) > 0 and pw.states["P"].has("auto_slip")
	pw.events.clear(); place(pw, 1.4); boss_lands(pw, "R_STRAIGHT")
	var walled_me: bool = count_events(pw.events, "walled", {"who": "P"}) == 1 and pw.P["comp"] == pw.P["comp_max"]
	boss_desperation(pw); resolve_cast(pw)
	_sr("perfect WALL: the LB+RT hold casts it; his punches are walled; his T1 cast is negated and breaks the wall",
		my_wall and walled_me and pw.P["comp"] == pw.P["comp_max"] and count_events(pw.events, "wall_broken", {"who": "P"}) == 1)
	# effects one by one
	var ho := make_sim(19, 7); quiet(ho); place(ho, 1.4); boss_desperation(ho); clear_defense(ho.P)   # Moira: Undertow, DISPLACE ROPES 1.5
	var h_py0: Vector2 = ho.P["pos"]; resolve_cast(ho)
	_sr("DISPLACE: Undertow throws you 1.5m toward the nearest rope", count_events(ho.events, "displace", {"toward": "ROPES"}) == 1 and ho.P["pos"].distance_to(h_py0) > 1.0, "%.2fm" % ho.P["pos"].distance_to(h_py0))
	var bu := make_sim(4, 7); quiet(bu); place(bu, 1.4); boss_desperation(bu); var hm_bu: float = bu.hiss_mult("B"); clear_defense(bu.P); var v_st0: float = bu.P["stamina"]; resolve_cast(bu)
	_sr("BURN: Heat Advisory burns 20 stamina x%.2f (Ada's own element and house on her native)" % hm_bu, absf((v_st0 - bu.P["stamina"]) - 20.0 * hm_bu) < 0.6, "%.1f" % (v_st0 - bu.P["stamina"]))
	var fs := with_move(0, 7, "First Snap"); cast_player(fs); resolve_cast(fs); thaw(fs)
	fs.P["pos"] = Vector2(0, 1.6); fs.B["pos"] = Vector2(0, -1.6); var bpos0: Vector2 = fs.B["pos"]
	run_ticks(fs, 20); var d_slow: float = fs.B["pos"].distance_to(bpos0)
	var fs2 := make_sim(0, 7); quiet(fs2); fs2.P["pos"] = Vector2(0, 1.6); fs2.B["pos"] = Vector2(0, -1.6); bpos0 = fs2.B["pos"]
	run_ticks(fs2, 20); var d_norm: float = fs2.B["pos"].distance_to(bpos0)
	_sr("STATE foot_freeze_slow: First Snap slows his feet to 60%", fs.states["B"].has("foot_freeze_slow") and absf(d_slow / maxf(0.001, d_norm) - 0.6) < 0.03, "%.3f/%.3f" % [d_slow, d_norm])
	var bi := with_move(0, 7, "Black Ice"); cast_player(bi); resolve_cast(bi)
	_sr("STATE tell_jam on him: Black Ice drops his read to 5% for 3s", bi.states["B"].has("tell_jam_audio") and absf(bi.read_prob(0, false, false, false) - 0.05) < 0.001)
	var ch := make_sim(8, 7); quiet(ch); place(ch, 1.4); boss_desperation(ch); clear_defense(ch.P); resolve_cast(ch)
	ch.events.clear(); ch._force_string("S1", 1.0, false)
	_sr("STATE tell_jam on you: after Harmattan his tells are emitted jammed (drawn blind)", ch.states["P"].has("tell_jam_visual") and count_events(ch.events, "tell", {"jammed": true}) == 1)
	var se := with_move(0, 7, "Sorry Eh"); cast_player(se); resolve_cast(se)
	var v_stance: bool = se.P["counter_state_t"] > 0
	se.events.clear(); place(se, 1.4); run_ticks(se, 30, {"block": true}); boss_lands(se, "R_STRAIGHT")
	_sr("STATE counter_stance: Sorry Eh arms you; his next punch into your guard opens a flash window", v_stance and se.P["flash_t"] > 0)
	var tm := make_sim(16, 7); quiet(tm); place(tm, 1.4); boss_desperation(tm); clear_defense(tm.P); resolve_cast(tm)     # Vasile: The Mean
	thaw(tm); tm.events.clear(); place(tm, 1.4); throw_clean(tm, "L_STRAIGHT"); var jab_d := hit_dmg(tm, "B")
	thaw(tm); tm.events.clear(); place(tm, 1.4); throw_clean(tm, "R_HOOKERCUT"); var hay_d := hit_dmg(tm, "B")
	_sr("STATE averages_incoming_damage: under The Mean your haymaker lands for the jab's average (%.1f vs %.1f)" % [hay_d, jab_d], tm.states["B"].has("averages_incoming_damage_over_duration") and absf(hay_d - jab_d) < 0.01)
	var lw := with_move(0, 7, "Long Winter"); cast_player(lw); resolve_cast(lw); thaw(lw); lw.P["busy_t"] = 0
	lw.P["stamina"] = 50.0; var v_s0: float = lw.P["stamina"]; run_ticks(lw, 120); var gain_buff: float = lw.P["stamina"] - v_s0
	var lw2 := make_sim(0, 7); quiet(lw2); lw2.P["stamina"] = 50.0; run_ticks(lw2, 120); var gain_norm: float = lw2.P["stamina"] - 50.0
	_sr("BUFF stamina_regen_x2: Long Winter doubles your stamina regen for 4s", lw.buffs["P"].has("stamina_regen_x2") and absf(gain_buff / maxf(0.001, gain_norm) - 2.0) < 0.05, "%.2f vs %.2f" % [gain_buff, gain_norm])
	var cr := with_move(0, 7, "Chinook Rush"); cast_player(cr); resolve_cast(cr); thaw(cr); cr.P["busy_t"] = 0
	var v_px0: Vector2 = cr.P["pos"]; run_ticks(cr, 20, {"move": Vector2(1, 0)}); var glide: float = cr.P["pos"].distance_to(v_px0)
	var cr2 := make_sim(0, 7); quiet(cr2); v_px0 = cr2.P["pos"]; run_ticks(cr2, 20, {"move": Vector2(1, 0)}); var h_walk: float = cr2.P["pos"].distance_to(v_px0)
	_sr("BUFF forward_glide: Chinook Rush moves you at 150% for 2s", cr.buffs["P"].has("forward_glide") and absf(glide / maxf(0.001, h_walk) - 1.5) < 0.05)
	var ps := with_move(0, 7, "Perfect Score"); cast_player(ps); var t_before: float = ps.tension; resolve_cast(ps)
	_sr("BUFF tension_plus_on_hit: Perfect Score pays +5 Tension when it lands", count_events(ps.events, "hit", {"hissatsu": true}) == 1 and absf((ps.tension - t_before) - 5.0) < 0.01)
	var fk := with_move(0, 7, "The Forks"); cast_player(fk); resolve_cast(fk)
	_sr("STATE two_hit_echo: The Forks lands twice", count_events(fk.events, "hit", {"hissatsu": true}) == 2)
	var tf := with_move(0, 7, "Timberfall"); cast_player(tf)
	run_ticks(tf, int(tf.cast["t"]) - 10); tf.B["dodge"] = "DUCK"; tf.B["dodge_t"] = 60; resolve_cast(tf)
	_sr("beats_duck_reads: a RISE into a ducking head lands full (the duck eats the uppercut by geometry, C2)", count_events(tf.events, "hit", {"outcome": "full"}) == 1)
	var ns := with_move(0, 7, "Relay: North Star")
	var v_locked: bool = not ns.castable(ns.player_move())
	ns.t3_unlocked = true; ns.relay_chain = 2
	var v_locked2: bool = not ns.castable(ns.player_move())                                             # PAC-081: CHARGED, but no FULL RELAY - North Star is the chain's (NP_05 s10)
	ns.relay_chain = 3; ns.full_relay = true
	cast_player(ns); resolve_cast(ns)
	var ns_d := hit_dmg(ns, "B")
	var v_expect := 15.0 * (45.0 / 50.0) * (1.6 + 0.8 * 3.0) * ns.hiss_mult("P")
	_sr("T3 needs the CHARGED unlock and North Star the FULL RELAY; it scales with the relay chain (base 1.6 + 0.8 x 3 links)", v_locked and v_locked2 and absf(ns_d - v_expect) < 0.05, "%.2f vs %.2f" % [ns_d, v_expect])
	var cc := make_sim(9, 7); quiet(cc); place(cc, 1.4); boss_desperation(cc)
	_sr("arm_only: the Commissioner arms [SEALED-SECRET] and casts The Commissioner's Due", count_events(cc.events, "cast", {"shown": "[SEALED-SECRET]", "move": "The Commissioner's Due"}) == 1)
	# ---- Wall Gauge (NP_05 s8): Sam Tagaq ----
	var sg := make_sim(3, 7); quiet(sg); place(sg, 1.4)
	var g_start: float = sg.wall["B"]["pts"]
	var v_c0: float = sg.B["comp"]
	for i in 3: throw_clean(sg, "L_STRAIGHT"); place(sg, 1.4)
	var jabs_zero: bool = float(sg.wall["B"]["pts"]) == g_start and sg.B["comp"] >= v_c0 - 0.01 and sensor_count(sg, "player_jab_spam_on_gauge") == 1
	sg.events.clear(); thaw(sg); sg.P["counter_t"] = 60; throw_clean(sg, "R_STRAIGHT"); place(sg, 1.4)
	var g_after_counter: float = sg.wall["B"]["pts"]; var counter_d := gauge_dmg(sg)
	sg.events.clear(); thaw(sg); throw_clean(sg, "R_HOOK", {"power": true}); place(sg, 1.4)
	var g_after_power: float = sg.wall["B"]["pts"]; var power_d := gauge_dmg(sg)
	sg.events.clear(); thaw(sg); throw_clean(sg, "R_HOOK", {"body": true}); place(sg, 1.4)
	var g_after_body: float = sg.wall["B"]["pts"]; var body_d := gauge_dmg(sg)
	var counter_full := 10.0 * 0.9 * 1.6; var power_full := 12.0 * 0.9 * 1.5; var body_full := 12.0 * 0.9 * 0.8
	_sr("gauge: jabs do 0 (and Sam's literacy hook fires); counters x1.0, power x0.8, body x0.6; his composure is shielded",
		jabs_zero and absf(counter_d - counter_full * 1.0) < 0.01 and absf(power_d - power_full * 0.8) < 0.01 and absf(body_d - body_full * 0.6) < 0.01
		and absf((g_start - g_after_body) - (counter_d + power_d + body_d)) < 0.01 and sg.B["comp"] >= v_c0 - 0.01, "%.0f -> %.1f -> %.1f -> %.1f" % [g_start, g_after_counter, g_after_power, g_after_body])
	sg.wall["B"]["pts"] = 1.0; sg.events.clear(); thaw(sg); sg.P["counter_t"] = 60; throw_clean(sg, "R_STRAIGHT"); place(sg, 1.4)
	var broke_g: bool = count_events(sg.events, "gauge_break") == 1 and int(sg.wall["B"]["open_t"]) > 0 and int(sg.wall["B"]["breaks"]) == 1
	sg.events.clear(); thaw(sg); var cc0: float = sg.B["comp"]; throw_clean(sg, "L_STRAIGHT"); var open_d := hit_dmg(sg, "B")
	var open_amp: bool = absf(open_d - 6.0 * 0.9 * 1.25) < 0.01 and sg.B["comp"] < cc0
	thaw(sg); run_ticks(sg, int(sg.wall["B"]["open_t"]) + 2)
	var reformed: bool = float(sg.wall["B"]["pts"]) == 60.0 and int(sg.wall["B"]["open_t"]) == 0
	sg.wall["B"]["pts"] = 1.0; thaw(sg); place(sg, 1.4); sg.P["counter_t"] = 60; throw_clean(sg, "R_STRAIGHT"); thaw(sg); run_ticks(sg, int(sg.wall["B"]["open_t"]) + 2)
	var reformed2: bool = float(sg.wall["B"]["pts"]) == 30.0
	sg.wall["B"]["pts"] = 1.0; thaw(sg); place(sg, 1.4); sg.P["counter_t"] = 60; sg.events.clear(); throw_clean(sg, "R_STRAIGHT"); thaw(sg); run_ticks(sg, int(sg.wall["B"]["open_t"]) + 2)
	var v_gone: bool = float(sg.wall["B"]["pts"]) == 0.0 and count_events(sg.events, "gauge_gone") == 1 and int(sg.wall["B"]["breaks"]) == 3
	_sr("gauge break: TRUE OPEN 8s at x1.25, reforms 60 then 30, three breaks end it for good", broke_g and open_amp and reformed and reformed2 and v_gone)
	var hg := make_sim(12, 7); quiet(hg); place(hg, 1.4)                                    # HC-0: migrant wall 60, leaves at 40
	var mig0: bool = float(hg.wall["B"]["pts"]) == 60.0
	hg.wall["B"]["pts"] = 41.0; thaw(hg); hg.P["counter_t"] = 60; hg.events.clear(); throw_clean(hg, "R_STRAIGHT")
	var v_left: bool = count_events(hg.events, "gauge_migrate") == 1 and hg.wall["B"].is_empty() and hg.wall_migrate > 0 and hg.wall_migrate <= 40
	hg.mode = "FIGHT"; hg._end_segment("smoke-forced"); next_segment(hg)
	_sr("migrant wall: HC-0's 60-pt wall leaves him at 40 and meets you again on the next boss", mig0 and v_left and float(hg.wall["B"].get("pts", 0.0)) > 0.0 and hg.wall_migrate == 0, "next boss wall %d" % int(hg.wall["B"].get("pts", 0.0)))

	# ================= PAC-057: feints (NP_03 s8) ==========
	var ft := make_sim(0, 7); quiet(ft); place(ft, 1.4)
	var edge: Dictionary = {}
	for k in [10, 11]:
		thaw(ft); place(ft, 1.4); ft.P["busy_t"] = 0; ft.P["cmd"] = {}; ft.events.clear(); ft.tokens = []; ft.flags = {}
		var fst0: float = ft.P["stamina"]
		ft.step({"punch": "R_HOOK"}); clear_defense(ft.B)
		run_ticks(ft, k - 1)
		ft.step({"punch_release": true}); clear_defense(ft.B); land(ft)
		edge[k] = [count_events(ft.events, "feint"), count_events(ft.events, "hit", {"on": "B"}), fst0 - ft.P["stamina"]]
	_sr("feint edge: a release at 80ms (10 ticks) cancels the hook for 1 stamina; at 11 ticks the hook goes",
		edge[10][0] == 1 and edge[10][1] == 0 and absf(float(edge[10][2]) - 1.0) < 0.2 and edge[11][0] == 0 and edge[11][1] == 1,
		"release@10 -> feints %d hits %d stamina %.2f; release@11 -> feints %d hits %d" % [edge[10][0], edge[10][1], edge[10][2], edge[11][0], edge[11][1]])
	var drew := 0; var dodged := 0; var drained := 0; var hits_on_feint := 0; var flinched := 0
	for i in 30:
		var fr := make_sim(0, 100 + i); quiet(fr); place(fr, 1.4)
		fr.P["busy_t"] = 0; fr.P["cmd"] = {}; fr.events.clear()
		fr.step({"punch": "R_HOOK"})
		run_ticks(fr, 5); var fg0: float = fr.B["guard"]
		fr.step({"punch_release": true})
		var fe: Dictionary = {}
		for e in fr.events:
			if e["kind"] == "feint": fe = e
		if fe.get("drawn", false):
			drew += 1
			if fg0 - fr.B["guard"] >= 0.99: drained += 1
			if fe["read"] == "guard" and fr.B["guard_t"] > 0: flinched += 1
			if fe["read"] == "dodge":
				run_ticks(fr, 25)
				if fr.B["dodge"] != "": dodged += 1
		run_ticks(fr, 60)
		hits_on_feint += count_events(fr.events, "hit", {"on": "B"})
	_sr("feint draws his read: %d/30 seeds bit (%d slipped at air, %d flinched a 400ms guard); every drawn feint drains 1 guard; nothing lands" % [drew, dodged, flinched],
		drew > 0 and dodged > 0 and flinched > 0 and drained == drew and hits_on_feint == 0)
	# spam cutoff: three identical feints in 10s and he stops reacting to that one; another row still works; 10s later it works again
	var fw := make_sim(0, 7); quiet(fw); place(fw, 1.4)
	var draws: Array = []
	var forced_feint := func(sim: TNBSim, row: String) -> bool:
		thaw(sim); place(sim, 1.4); sim.P["busy_t"] = 0; sim.P["cmd"] = {}; sim.events.clear()
		sim.step({"punch": row})
		sim.P["pending"]["read"] = "guard"; sim.B["blocking"] = true; sim.B["block_t"] = 999; sim.B["dodge_plan"] = []; sim.B["dodge_at"] = 0
		run_ticks(sim, 4); sim.step({"punch_release": true})
		var out := false
		for e in sim.events:
			if e["kind"] == "feint": out = bool(e["drawn"])
		run_ticks(sim, 60)
		return out
	for i in 5: draws.append(forced_feint.call(fw, "R_HOOK"))
	var other_row: bool = forced_feint.call(fw, "L_STRAIGHT")
	run_ticks(fw, TNBSim.ms(10000) + 5)
	var again: bool = forced_feint.call(fw, "R_HOOK")
	_sr("feint spam: the 4th identical feint in 10s draws nothing (he cancels the read), another row still draws, 10s later the first draws again",
		draws == [true, true, true, false, false] and other_row and again and fw.B["blocking"] == false, JSON.stringify(draws))
	var fc := make_sim(1, 7); quiet(fc); place(fc, 1.4); boss_desperation(fc)
	fc.P["busy_t"] = 0; fc.P["cmd"] = {}; fc.step({"punch": "L_STRAIGHT"}); run_ticks(fc, 4); fc.step({"punch_release": true})
	_sr("a feint never breaks a cast: only a landed jab does", count_events(fc.events, "feint") == 1 and fc.cast.size() > 0 and count_events(fc.events, "cast_interrupted") == 0)
	var fk2 := make_sim(0, 7); quiet(fk2); place(fk2, 1.4)
	for i in 4: forced_feint.call(fk2, "R_HOOK")
	_sr("feints are tracker tokens: four feinted hooks flag the F_R_HOOK 2-gram like punches would", fk2.tokens.size() >= 4 and str(fk2.tokens[-1]) == "F_R_HOOK" and fk2._flag_tier() >= 1, "tier=%d tokens=%s" % [fk2._flag_tier(), JSON.stringify(fk2.tokens.slice(-4))])
	var fh := make_sim(0, 7); quiet(fh); place(fh, 1.4)
	thaw(fh); fh.P["busy_t"] = 0; fh.P["cmd"] = {}; fh.events.clear(); fh.step({"punch": "R_HOOK"})
	fh.P["pending"]["read"] = "dodge"; var fby0: float = fh.B["pos"].y
	run_ticks(fh, 4); fh.step({"punch_release": true})
	_sr("a drawn feint herds him 10cm and fires the feint sensors (player_feint, player_feint_hook)",
		absf((fby0 - fh.B["pos"].y) - 0.1) < 0.02 and sensor_count(fh, "player_feint") == 1 and sensor_count(fh, "player_feint_hook") == 1, "%.2f -> %.2f" % [fby0, fh.B["pos"].y])

	# ================= PAC-058: the corner phase (NP_10 s4-s6) and the relay (NP_05 s6) ==========
	var to_corner := func(sim: TNBSim, contributed: float) -> void:
		sim.mode = "FIGHT"; sim.eight = {}; sim.contributed = contributed
		sim._end_segment("smoke-forced"); sim.step({"corner": 1})
	# timer + overrun: the corner runs out and the fighter comes out at 80% stamina
	var cn := make_sim(0, 7); quiet(cn); to_corner.call(cn, 0.0)
	run_ticks(cn, TNBSim.ms(45000) - 1)
	var still_corner: bool = cn.mode == "CORNER" and int(cn.corner["t"]) == 1
	cn.step({})
	_sr("corner timer: 45s runs out -> overrun, %s comes out at 80 stamina" % cn.pname(), still_corner and cn.mode == "FIGHT" and cn.seg_idx == 1 and absf(cn.P["stamina"] - 80.0) < 0.01, "stam=%.0f" % cn.P["stamina"])
	# action budget: two, not three; send ends it early with full stamina
	var cb := make_sim(0, 7); quiet(cb); to_corner.call(cb, 0.0); cb.tension = 60.0; cb.crowd_heat = 30.0   # since PAC-074 Raise the Roof converts crowd heat: the building at 30 first
	var a1 := cb.corner_action({"kind": "save_bar"})
	var a2 := cb.corner_action({"kind": "staff", "id": "raise_the_roof"})
	var a3 := cb.corner_action({"kind": "tactic", "id": "body_doctrine"})
	_sr("corner budget: two actions land, the third is refused; Raise the Roof converted 30 crowd heat into +8 Tension", a1 and a2 and not a3 and count_events(cb.events, "corner_refused", {"why": "no actions left"}) == 1 and absf(cb.tension - 68.0) < 0.01 and absf(cb.crowd_heat) < 0.01)
	cb.step({"corner": 1})
	_sr("send before the clock: the next fighter comes out at full stamina", cb.mode == "FIGHT" and absf(cb.P["stamina"] - 100.0) < 0.01)
	# swaps: the reserve or a not-yet-fought slot; first free, then 15 Tension; fought fighters and the upcoming slot itself are refused
	var cs := make_sim(0, 7); quiet(cs); to_corner.call(cs, 0.0); cs.tension = 20.0
	var opts: Dictionary = cs.corner_options()
	var s1 := cs.corner_action({"kind": "swap", "arg": "JUNE"})              # reserve in for PRIYA (free)
	var t_after_free: float = cs.tension
	var s2 := cs.corner_action({"kind": "swap", "arg": "MARCUS"})            # R3's fighter up to R2 (15 Tension)
	var t_after_paid: float = cs.tension
	cs.step({"corner": 1})
	var cs2 := make_sim(0, 7); quiet(cs2); to_corner.call(cs2, 0.0); cs2.tension = 5.0
	cs2.corner_action({"kind": "swap", "arg": "JUNE"})
	var s3 := cs2.corner_action({"kind": "swap", "arg": "MARCUS"})           # second swap, cannot afford
	var s4 := cs2.corner_action({"kind": "swap", "arg": "RORY"})             # already fought
	_sr("swap: reserve JUNE in (free), then MARCUS up (-15 Tension) -> R2 is MARCUS; a broke second swap and a fought fighter are refused",
		opts["swap"] == ["JUNE", "MARCUS"] and s1 and t_after_free == 20.0 and s2 and t_after_paid == 5.0 and cs.pname() == "MARCUS" and not s3 and not s4,
		"options %s -> R2 %s" % [JSON.stringify(opts["swap"]), cs.pname()])
	# tactic: Body Doctrine doubles body drain next segment; cooldown one corner; cost paid
	var ct := make_sim(0, 7); quiet(ct); to_corner.call(ct, 0.0); ct.tension = 30.0
	var c_t1 := ct.corner_action({"kind": "tactic", "id": "body_doctrine"})
	var t_paid: float = ct.tension
	ct.step({"corner": 1}); quiet(ct); place(ct, 1.4)
	var bst0: float = ct.B["stamina"]
	throw_clean(ct, "R_HOOK", {"body": true})
	var drain_doubled: bool = absf((bst0 - ct.B["stamina"]) - 12.0) < 0.3
	to_corner.call(ct, 0.0); ct.tension = 30.0
	var c_t2 := ct.corner_action({"kind": "tactic", "id": "body_doctrine"})
	var c_t3 := ct.corner_action({"kind": "tactic", "id": "open_season"})
	_sr("tactic: Body Doctrine (-10) doubles body drain next segment (%.1f); on cooldown the corner after, another tactic still goes" % (bst0 - ct.B["stamina"]),
		c_t1 and t_paid == 20.0 and ct.tactic_fx.has("body_drain_mult") and drain_doubled and not c_t2 and c_t3 and count_events(ct.events, "corner_refused") == 1)
	var cu := make_sim(0, 7); quiet(cu); to_corner.call(cu, 0.0); cu.tension = 5.0
	var c_t4 := cu.corner_action({"kind": "tactic", "id": "second_wind_call"})
	_sr("tactic: Second Wind Call needs 20 Tension - refused at 5", not c_t4 and count_events(cu.events, "corner_refused", {"action": "tactic"}) == 1)
	# super: Iron Resolve - no DROP for 30s next segment (wobbles instead); once per dual
	var ci := make_sim(0, 7); quiet(ci); to_corner.call(ci, 0.0)
	var u1 := ci.corner_action({"kind": "super"})
	ci.step({"corner": 1}); quiet(ci); place(ci, 1.4); clear_defense(ci.P)
	ci.P["comp"] = 0.5; boss_lands(ci, "R_HOOKERCUT")
	var held: bool = ci.mode == "FIGHT" and ci.P["drops"] == 0 and count_events(ci.events, "iron_resolve") == 1 and ci.P["comp"] == 1.0 and ci._wobbled(ci.P)
	thaw(ci); run_ticks(ci, TNBSim.ms(30000)); place(ci, 1.4); clear_defense(ci.P); ci.P["comp"] = 0.5; boss_lands(ci, "R_HOOKERCUT")
	var drops_after: bool = ci.mode == "EIGHT"
	to_corner.call(ci, 0.0)
	var u2 := ci.corner_action({"kind": "super"})
	_sr("super: Iron Resolve holds the fighter up for 30s (wobbled at 1 composure), then drops resume; the super is once per dual", u1 and held and drops_after and not u2)
	# save the bar: no casting next segment; +5 if the segment is won anyway
	var cv := make_sim(0, 7); quiet(cv); to_corner.call(cv, 0.0)
	cv.corner_action({"kind": "save_bar"}); cv.step({"corner": 1}); quiet(cv); place(cv, 1.4); cv.tension = 100.0
	cv.P["busy_t"] = 0; cv.P["cmd"] = {}; cv.step({"punch": "R_STRAIGHT", "lb": true})   # PRIYA's Marginalia is PISTON: LB + straight
	var locked: bool = cv.cast.is_empty() and cv.P["pending"].size() > 0 and cv.tension == 100.0
	clear_defense(cv.B); land(cv)
	cv.score_p += 1; cv.tension = 50.0
	cv.mode = "FIGHT"; cv._end_segment("smoke-forced")
	_sr("save the bar: the cast is refused next segment; winning it anyway banks +5 on top of the segment win's +5 (NP_05 s2)", locked and absf(cv.tension - 60.0) < 0.01, "%.0f" % cv.tension)
	# relay chain arithmetic (NP_05 s6): >=25 links, <10 breaks, a lost segment with >=10 keeps it; FULL RELAY at 3
	var c_cr := make_sim(0, 7); quiet(c_cr)
	var chain_log: Array = []
	for contributed in [30.0, 12.0, 26.0]:
		c_cr.mode = "FIGHT"; c_cr.contributed = contributed; c_cr.score_b += 1
		c_cr._end_segment("smoke-forced"); chain_log.append(c_cr.relay_chain)
		if c_cr.mode != "OVER": next_segment(c_cr)
	var c_cr2 := make_sim(0, 7); quiet(c_cr2)
	c_cr2.mode = "FIGHT"; c_cr2.contributed = 30.0; c_cr2._end_segment("smoke-forced"); next_segment(c_cr2)
	c_cr2.mode = "FIGHT"; c_cr2.contributed = 4.0; c_cr2._end_segment("smoke-forced")
	var broke_chain: bool = c_cr2.relay_chain == 0
	c_cr2.relay_chain = 2; c_cr2.mode = "FIGHT"; c_cr2.contributed = 30.0; c_cr2.seg_idx = 1; c_cr2._end_segment("smoke-forced")
	var full: bool = c_cr2.full_relay and c_cr2.relay_chain == 3
	c_cr2.P["charge_t"] = 0
	var t4_cost := c_cr2.hiss_cost({"tier": "T4", "tension_cost": 100, "name": "fake"})
	var t4_expect := 75.0 * (0.9 if c_cr2._beats("element", c_cr2.P["element"], c_cr2.B["element"]) else 1.0)
	_sr("relay chain: %s (30 links, a lost 12 keeps, 26 links); an empty 4 breaks it; three links = FULL RELAY, T4 costs 75%s" % [JSON.stringify(chain_log), " x0.9 (element edge)" if t4_expect < 75.0 else ""],
		chain_log == [1, 1, 2] and broke_chain and full and absf(t4_cost - t4_expect) < 0.01)
	# afterimage: a T3 cast in R2+ carries the previous fighter; FULL RELAY adds the element trail
	var ca := make_sim(0, 7); quiet(ca)                                                                # PAC-081: the relay opens its own T3 - PRIYA's card no longer needs to carry one
	ca.mode = "FIGHT"; ca.contributed = 30.0; ca._end_segment("smoke-forced"); next_segment(ca)
	quiet(ca); place(ca, 1.4); ca.tension = 100.0; ca.events.clear()
	ca.P["busy_t"] = 0; ca.P["cmd"] = {}; ca.step({"punch": "R_HOOKERCUT", "lb": true})
	var ghost := ""
	for e in ca.events:
		if e["kind"] == "cast": ghost = str(e["afterimage"])
	_sr("afterimage: PRIYA's T3 cast in R2 carries RORY as the spirit afterimage (the relay's Coast to Coast, opened by the CHARGED entrance)", ca.cast.size() > 0 and str(ca.cast["move"]["name"]) == "Relay: Coast to Coast" and ghost == "RORY")
	# the card carries the segment story
	var cc2 := make_sim(0, 7); quiet(cc2); cc2.mode = "FIGHT"; cc2.ep_p = 20; cc2.ep_b = 8; cc2.contributed = 12.0; cc2.events.clear()
	cc2._end_segment("clock")
	var card: Dictionary = {}
	for e in cc2.events:
		if e["kind"] == "seg_card": card = e
	_sr("segment-end card: EP totals, segment winner, Tension carried", card.get("ep_p", -1) == 20 and card.get("ep_b", -1) == 8 and card.get("won", false) and card.has("tension") and cc2.mode == "CARD")
	# ---- every remaining effect in tactics.v1.json lands on the next segment ----
	var equip := func(sim: TNBSim, special: Array, super_id: String, staff: Array) -> void:
		sim.TAC = sim.TAC.duplicate(true)                     # the content dictionary is shared; dress a copy
		sim.TAC["equipped"] = {"special": special, "super": super_id, "staff": staff}
	var first_tell := func(sim: TNBSim) -> Dictionary:        # let the frozen boss go and catch his first real tell
		sim.bstate = "IDLE"; sim.btimer = 1; sim.events.clear()
		var n := 0
		while n < 2400:
			sim.step({}); n += 1
			for e in sim.events:
				if e["kind"] == "tell" and not e.get("fake", false): return e
		return {}
	# High Guard Order: guard decay under a held block halved (control sim alongside)
	var hgo := make_sim(0, 7); quiet(hgo); to_corner.call(hgo, 0.0); equip.call(hgo, ["high_guard_order"], "iron_resolve", []); hgo.tension = 30.0
	var hgo_ok := hgo.corner_action({"kind": "tactic", "id": "high_guard_order"}); hgo.step({"corner": 1}); quiet(hgo); place(hgo, 1.4)
	var hgo_g0: float = hgo.P["guard"]; run_ticks(hgo, 240, {"block": true}); var drop_half: float = hgo_g0 - hgo.P["guard"]
	var hg0 := make_sim(0, 7); quiet(hg0); to_corner.call(hg0, 0.0); hg0.step({"corner": 1}); quiet(hg0); place(hg0, 1.4)
	var hgo_g1: float = hg0.P["guard"]; run_ticks(hg0, 240, {"block": true}); var drop_full: float = hgo_g1 - hg0.P["guard"]
	_sr("tactic: High Guard Order halves guard decay under a held block (%.2f vs %.2f over 2s)" % [drop_half, drop_full], hgo_ok and drop_full > 1.0 and absf(drop_half * 2.0 - drop_full) < 0.05)
	# Cut the Ring: sprint-steps free, a landed hook herds 0.4m instead of 0.2m
	var ctr := make_sim(0, 7); quiet(ctr); to_corner.call(ctr, 0.0); equip.call(ctr, ["cut_the_ring"], "iron_resolve", []); ctr.tension = 30.0
	var ctr_ok := ctr.corner_action({"kind": "tactic", "id": "cut_the_ring"}); ctr.step({"corner": 1}); quiet(ctr); place(ctr, 3.0)
	var ctr_st0: float = ctr.P["stamina"]; ctr.step({"sprint": true, "move": Vector2(0, -1)})
	var sprint_free: bool = count_events(ctr.events, "sprint") == 1 and absf(ctr.P["stamina"] - ctr_st0) < 0.01
	place(ctr, 1.4); var ctr_b0: Vector2 = ctr.B["pos"]; throw_clean(ctr, "R_HOOK")
	var herded: float = (ctr.B["pos"] - ctr_b0).length()
	thaw(hg0); place(hg0, 1.4); var hg0_b0: Vector2 = hg0.B["pos"]; throw_clean(hg0, "R_HOOK")
	var herded0: float = (hg0.B["pos"] - hg0_b0).length()
	_sr("tactic: Cut the Ring - the sprint-step costs nothing and a hook herds %.2fm instead of %.2fm" % [herded, herded0], ctr_ok and sprint_free and absf(herded0 - 0.1) < 0.02 and absf(herded - 2.0 * herded0) < 0.02)
	# Feint Storm: feints free, his punish hooks suppressed for 30s
	var fst := make_sim(0, 7); quiet(fst); to_corner.call(fst, 0.0); equip.call(fst, ["feint_storm"], "iron_resolve", []); fst.tension = 30.0
	var fst_ok := fst.corner_action({"kind": "tactic", "id": "feint_storm"}); fst.step({"corner": 1}); quiet(fst); place(fst, 1.4)
	var fst_sup0: int = fst.punish_suppress_t
	var fst_st0: float = fst.P["stamina"]; fst.P["busy_t"] = 0; fst.P["cmd"] = {}; fst.step({"punch": "R_HOOK"}); clear_defense(fst.B); run_ticks(fst, 4); fst.step({"punch_release": true})
	_sr("tactic: Feint Storm - the feint costs 0 and his punish hooks are off for 30s", fst_ok and fst_sup0 == TNBSim.ms(30000) and count_events(fst.events, "feint") == 1 and absf(fst.P["stamina"] - fst_st0) < 0.01, "suppress=%d stamina %.2f->%.2f" % [fst_sup0, fst_st0, fst.P["stamina"]])
	# Ice the Clock: 120 ticks cost the segment 150 while you lead on EP, 120 when you do not
	var ic := make_sim(0, 7); quiet(ic); to_corner.call(ic, 0.0); equip.call(ic, ["ice_the_clock"], "iron_resolve", []); ic.tension = 30.0
	var ic_ok := ic.corner_action({"kind": "tactic", "id": "ice_the_clock"}); ic.step({"corner": 1}); quiet(ic); place(ic, 1.4)
	ic.ep_p += 5; var ic_c0: int = ic.clock_t; run_ticks(ic, 120); var lead_drop: int = ic_c0 - ic.clock_t
	ic.ep_b += 10; var ic_c1: int = ic.clock_t; run_ticks(ic, 120); var trail_drop: int = ic_c1 - ic.clock_t
	_sr("tactic: Ice the Clock runs the clock at 1/0.8 while leading (%d ticks per 120) and normally when not (%d)" % [lead_drop, trail_drop], ic_ok and lead_drop == 150 and trail_drop == 120)
	# Read the Corner: his tells 25% longer
	var rdc := make_sim(0, 7); quiet(rdc); to_corner.call(rdc, 0.0); equip.call(rdc, ["read_the_corner"], "iron_resolve", []); rdc.tension = 30.0
	var rdc_ok := rdc.corner_action({"kind": "tactic", "id": "read_the_corner"}); rdc.step({"corner": 1}); quiet(rdc); place(rdc, 1.4)
	var rdc_tell: Dictionary = first_tell.call(rdc)
	var rdc_base: int = TNBSim.ms(float(rdc.pattern["strings"][str(rdc_tell.get("string", ""))]["tell"]["ms"])) if rdc_tell.size() > 0 else 0
	_sr("tactic: Read the Corner draws his tell longer (%s: %d -> %d ticks, x1.25)" % [rdc_tell.get("string", "?"), rdc_base, int(rdc_tell.get("ticks", 0))], rdc_ok and rdc_base > 0 and int(rdc_tell["ticks"]) == int(float(rdc_base) * 1.25))
	# Open Season: guard cap -20%, counter windows +100ms (a slip's 400ms window reads 500)
	var osn := make_sim(0, 7); quiet(osn); to_corner.call(osn, 0.0); equip.call(osn, ["open_season"], "iron_resolve", []); osn.tension = 30.0
	var osn_ok := osn.corner_action({"kind": "tactic", "id": "open_season"}); osn.step({"corner": 1}); quiet(osn); place(osn, 1.4)
	osn.P["dodge"] = "SLIP"; osn.P["dodge_t"] = 999; osn.P["dodge_dir"] = 1; boss_lands(osn, "R_STRAIGHT")
	var os_win := TNBSim.ms(500) + (TNBSim.ms(50) if osn._style_adv("P") else 0)
	_sr("tactic: Open Season - guard cap x0.8 (%.1f vs %.1f) and the slip window is 500ms%s (%d ticks)" % [osn.P["guard_max"], hg0.P["guard_max"], " + the triangle's 50" if os_win > TNBSim.ms(500) else "", osn.P["counter_t"]], osn_ok and absf(osn.P["guard_max"] - 0.8 * hg0.P["guard_max"]) < 0.01 and osn.P["counter_t"] == os_win)
	# Second Wind Call after an overrun corner: 80 + 40 caps at 100
	var sw := make_sim(0, 7); quiet(sw); to_corner.call(sw, 0.0); sw.tension = 30.0
	var sw_ok := sw.corner_action({"kind": "tactic", "id": "second_wind_call"}); run_ticks(sw, TNBSim.ms(45000))
	_sr("tactic: Second Wind Call (-20) tops an overrun fighter back up from 80 to 100", sw_ok and sw.mode == "FIGHT" and absf(sw.tension - 10.0) < 0.01 and absf(sw.P["stamina"] - 100.0) < 0.01, "stam=%.0f" % sw.P["stamina"])
	# supers in the data: Perfect Round doubles every Tension source; Switch-Up is the triangle lie (+10% EP, +50ms windows); Hostile Crowd is recorded
	var pr := make_sim(0, 7); quiet(pr); to_corner.call(pr, 0.0); equip.call(pr, [], "perfect_round", [])
	var pr_ok := pr.corner_action({"kind": "super"}); pr.step({"corner": 1}); pr.tension = 0.0; pr.contributed = 0.0; pr._earn_tension(10.0)
	_sr("super: The Perfect Round - 10 Tension earned lands as 20", pr_ok and absf(pr.tension - 20.0) < 0.01 and absf(pr.contributed - 20.0) < 0.01)
	var su := make_sim(0, 7); quiet(su); to_corner.call(su, 0.0); equip.call(su, [], "switch_up", [])
	var su_ok := su.corner_action({"kind": "super"}); su.step({"corner": 1}); quiet(su); place(su, 1.4)
	var su_ep0: int = su.ep_p
	for i in 10: place(su, 1.4); throw_clean(su, "L_STRAIGHT")
	var su_ep: int = su.ep_p - su_ep0
	thaw(su); place(su, 1.4); su.P["dodge"] = "SLIP"; su.P["dodge_t"] = 999; su.P["dodge_dir"] = 1; boss_lands(su, "R_STRAIGHT")
	_sr("super: Switch-Up - ten clean jabs score 22 EP (x1.1) and the slip window reads 450ms", su_ok and su_ep == 22 and su.P["counter_t"] == TNBSim.ms(450), "ep=%d window=%d" % [su_ep, su.P["counter_t"]])
	var hcw := make_sim(0, 7); quiet(hcw); to_corner.call(hcw, 0.0); equip.call(hcw, [], "hostile_crowd", [])
	var hcw_ok := hcw.corner_action({"kind": "super"}); hcw.step({"corner": 1})
	_sr("super: Hostile Crowd is recorded on the segment (enemy_corner_lock) - there is no enemy corner to lock yet", hcw_ok and hcw.tactic_fx.get("enemy_corner_lock", false) and count_events(hcw.events, "tactics_live") == 1)
	# staff in the data: Patch Job's charges run out; The Reveal names the next boss; Chalk Talk highlights his tells for 15s
	var pj := make_sim(0, 7); quiet(pj); to_corner.call(pj, 0.0)
	var pj1 := pj.corner_action({"kind": "staff", "id": "patch_job"}); var pj2 := pj.corner_action({"kind": "staff", "id": "patch_job"}); pj.step({"corner": 1})
	var pj_full: bool = pj.P["comp"] == pj.P["comp_max"]
	to_corner.call(pj, 0.0)
	var pj3 := pj.corner_action({"kind": "staff", "id": "patch_job"})
	_sr("staff: Patch Job spends its two charges (a fresh fighter has nothing to restore), the third is refused", pj1 and pj2 and pj_full and not pj3 and count_events(pj.events, "corner_refused", {"why": "Patch Job has no charges left"}) == 1)
	var rv := make_sim(0, 7); quiet(rv); to_corner.call(rv, 0.0); equip.call(rv, [], "iron_resolve", ["the_reveal"])
	var rv_ok := rv.corner_action({"kind": "staff", "id": "the_reveal"})
	_sr("staff: The Reveal names the next slot (%s)" % rv.boss_names[1], rv_ok and count_events(rv.events, "reveal", {"boss": rv.boss_names[1]}) == 1)
	var ck := make_sim(0, 7); quiet(ck); to_corner.call(ck, 0.0); equip.call(ck, [], "iron_resolve", ["chalk_talk"])
	var ck_ok := ck.corner_action({"kind": "staff", "id": "chalk_talk"}); ck.step({"corner": 1}); quiet(ck); place(ck, 1.4)
	var ck_t0: int = ck.tell_highlight_t
	var ck_tell: Dictionary = first_tell.call(ck)
	freeze_boss(ck); thaw(ck); run_ticks(ck, TNBSim.ms(15000))
	_sr("staff: Chalk Talk - 15s of tell highlight, the first tell carries it, then it is gone", ck_ok and ck_t0 == TNBSim.ms(15000) and ck_tell.get("highlight", false) and ck.tell_highlight_t == 0)

	# ================= PAC-059: the affinity rings (NP_06) ==========
	var ringed := func(boss_i: int, seed_v: int, style: String, element: String, house: String, move: String = "") -> TNBSim:
		var lu_q: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true)
		lu_q[0]["style"] = style; lu_q[0]["element"] = element; lu_q[0]["house"] = house
		if move != "": lu_q[0]["hissatsu"] = move
		var r_q := make_sim(boss_i, seed_v, lu_q); quiet(r_q); place(r_q, 1.4)
		return r_q
	var ten_jabs := func(sim: TNBSim) -> int:
		var e0_q: int = sim.ep_p
		for qi in 10: place(sim, 1.4); throw_clean(sim, "L_STRAIGHT")
		return sim.ep_p - e0_q
	var ten_boss_hits := func(sim: TNBSim) -> int:
		var e0_q: int = sim.ep_b
		for qi in 10:
			thaw(sim); place(sim, 1.4); clear_defense(sim.P); sim.P["comp"] = sim.P["comp_max"]; boss_lands(sim, "R_STRAIGHT")
		return sim.ep_b - e0_q
	var slip_window := func(sim: TNBSim) -> int:
		thaw(sim); place(sim, 1.4); sim.P["dodge"] = "SLIP"; sim.P["dodge_t"] = 999; sim.P["dodge_dir"] = 1; boss_lands(sim, "R_STRAIGHT")
		var w_q: int = sim.P["counter_t"]; clear_defense(sim.P); return w_q
	# every card and every pattern dresses to the ring keys; the matchup card fires at every segment load
	var dressed_ok := true; var neutral_elems := 0
	for qbn in TNBSim.BOSSES:
		var mt_q: Dictionary = content["patterns"][qbn].get("meta", {})
		var sk_q := TNBSim.style_key(str(mt_q.get("style", ""))); var ek_q := TNBSim.element_key(str(mt_q.get("element", ""))); var hk_q := TNBSim.house_key(str(mt_q.get("house", "")))
		if not (sk_q in ["SWARMER", "OUTBOXER", "SLUGGER", "BOXERPUNCHER"]) or not (ek_q in ["FROST", "GALE", "GRANITE", "TIMBER", "NONE"]) or hk_q == "": dressed_ok = false
		if ek_q == "NONE": neutral_elems += 1
	var mc := make_sim(0, 7)
	var mc_card := count_events(mc.events, "matchup") == 1 and mc.aff.has("line") and str(mc.aff["line"]) != ""
	mc.mode = "FIGHT"; mc.contributed = 0.0; mc._end_segment("smoke-forced"); next_segment(mc)
	_sr("rings: 24/24 patterns and 4/4 cards dress to style/element/house keys (%d authored-neutral elements: varies/rotating); the matchup card fires at every segment load" % neutral_elems,
		dressed_ok and mc_card and count_events(mc.events, "matchup") == 2 and TNBSim.house_key("reyes_origin_line") == "reyes" and TNBSim.house_key("petrov_root_system") == "petrov" and TNBSim.house_key("unknown") == "none")
	# RING 1: the triangle. Yuri is a SLUGGER: an OUT-BOXER card is advantaged, a SWARMER card is not, a BOXER-PUNCHER never is
	var r_ob: TNBSim = ringed.call(1, 7, "OUTBOXER", "NONE", "none")
	var ob_ep: int = ten_jabs.call(r_ob); var ob_win: int = slip_window.call(r_ob); var ob_bep: int = ten_boss_hits.call(r_ob)
	_sr("triangle: OUT-BOXER over SLUGGER - ten clean jabs score 22 EP, the slip window is 450ms; his ten score 20 (no debuff on him)",
		r_ob.aff["style_adv"] == "P" and ob_ep == 22 and ob_win == TNBSim.ms(450) and ob_bep == 20, "ep %d win %d his %d" % [ob_ep, ob_win, ob_bep])
	var r_sw: TNBSim = ringed.call(1, 7, "SWARMER", "NONE", "none")
	var sw_ep: int = ten_jabs.call(r_sw); var sw_win: int = slip_window.call(r_sw); var sw_bep: int = ten_boss_hits.call(r_sw)
	_sr("triangle: SLUGGER over SWARMER - his ten score 22; yours score 20 and your slip window stays 400ms (disadvantage is his edge, not your debuff)",
		r_sw.aff["style_adv"] == "B" and sw_bep == 22 and sw_ep == 20 and sw_win == TNBSim.ms(400), "ep %d win %d his %d" % [sw_ep, sw_win, sw_bep])
	var r_bp: TNBSim = ringed.call(1, 7, "BOXERPUNCHER", "NONE", "none")
	var bp_ep: int = ten_jabs.call(r_bp); var bp_bep: int = ten_boss_hits.call(r_bp)
	var r_mi: TNBSim = ringed.call(1, 7, "SLUGGER", "NONE", "none")
	var r_pu: TNBSim = ringed.call(3, 7, "BOXERPUNCHER", "NONE", "none")
	_sr("triangle: BOXER-PUNCHER is outside it (20/20 vs the slugger); a mirror is a mirror; two boxer-punchers are the purist's matchup",
		r_bp.aff["style_adv"] == "" and bp_ep == 20 and bp_bep == 20 and r_mi.aff["style_adv"] == "" and "mirror" in str(r_mi.aff["line"]) and "purist" in str(r_pu.aff["line"]))
	# Switch-Up (NP_10) is the lie: a SWARMER card counts as advantaged, but his truth stays; a true edge is not doubled
	var lu_sw: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu_sw[1]["style"] = "SWARMER"; lu_sw[1]["element"] = "NONE"
	var su_l := make_sim(0, 7, lu_sw); quiet(su_l); to_corner.call(su_l, 0.0); equip.call(su_l, [], "switch_up", [])
	su_l.corner_action({"kind": "super"}); su_l.step({"corner": 1}); quiet(su_l); place(su_l, 1.4)
	var lie_ep: int = ten_jabs.call(su_l); var lie_win: int = slip_window.call(su_l); var lie_bep: int = ten_boss_hits.call(su_l)
	var lu_tr: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu_tr[1]["element"] = "NONE"            # PRIYA is an OUT-BOXER: the truth vs Yuri
	var su_t := make_sim(0, 7, lu_tr); quiet(su_t); to_corner.call(su_t, 0.0); equip.call(su_t, [], "switch_up", [])
	su_t.corner_action({"kind": "super"}); su_t.step({"corner": 1}); quiet(su_t); place(su_t, 1.4)
	var true_ep: int = ten_jabs.call(su_t); var true_win: int = slip_window.call(su_t)
	_sr("Switch-Up: the lie makes a SWARMER count as advantaged vs Yuri (22 EP, 450ms) while his own edge stands (22); on a true edge it adds nothing (22, 450ms)",
		su_l.aff["style_adv"] == "B" and lie_ep == 22 and lie_win == TNBSim.ms(450) and lie_bep == 22 and su_t.aff["style_adv"] == "P" and true_ep == 22 and true_win == TNBSim.ms(450),
		"lie %d/%d his %d; truth %d/%d" % [lie_ep, lie_win, lie_bep, true_ep, true_win])
	# RING 2: the element. FROST over GALE: x1.10 on the hissatsu and -10% cost; the same-element spike x1.30 on top; the cap x1.5
	var e_fr: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "FROST", "none")      # Rory's Aurora Borealis Breaker is FROST; Vane is GALE
	var e_ga: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "GALE", "none")       # same move, off-element card: no spike, no edge
	var e_ti: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "TIMBER", "none")     # neutral pair
	var e_gr: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "GRANITE", "none")    # GALE beats GRANITE: his edge, no debuff on you
	_sr("element: FROST card + FROST move vs GALE = x1.43 (1.3 spike x 1.1 edge), cost 35 -> 31.5; GALE card = x1.0 at 35; TIMBER neutral x1.0; GRANITE (beaten) x1.0 at 35",
		absf(e_fr.hiss_mult("P") - 1.43) < 1e-6 and absf(e_fr.hiss_cost(e_fr.player_move()) - 31.5) < 0.01 and absf(e_ga.hiss_mult("P") - 1.0) < 1e-6 and absf(e_ga.hiss_cost(e_ga.player_move()) - 35.0) < 0.01
		and absf(e_ti.hiss_mult("P") - 1.0) < 1e-6 and e_gr.aff["element_adv"] == "B" and absf(e_gr.hiss_mult("P") - 1.0) < 1e-6 and absf(e_gr.hiss_cost(e_gr.player_move()) - 35.0) < 0.01)
	e_fr.tension = 100.0; e_ga.tension = 100.0
	cast_player(e_fr); clear_defense(e_fr.B); resolve_cast(e_fr); var d_fr := hit_dmg(e_fr, "B")
	cast_player(e_ga); clear_defense(e_ga.B); resolve_cast(e_ga); var d_ga := hit_dmg(e_ga, "B")
	_sr("element: the multiplier is real damage - the FROST card's Breaker lands %.1f vs the GALE card's %.1f (x1.43)" % [d_fr, d_ga], d_ga > 0.0 and absf(d_fr / d_ga - 1.43) < 0.01)
	var w_ga: TNBSim = ringed.call(18, 7, "BOXERPUNCHER", "GALE", "none")     # Marta is FROST: her Premiere Neige (5s) stands 6s against GALE
	boss_desperation(w_ga); resolve_cast(w_ga)
	var w_gr: TNBSim = ringed.call(18, 7, "BOXERPUNCHER", "GRANITE", "none")  # neutral: 5s
	boss_desperation(w_gr); resolve_cast(w_gr)
	var w_me: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "FROST", "none", "Premiere Neige")   # your own wall against the element you beat: +1s too
	w_me.tension = 100.0; cast_player(w_me); resolve_cast(w_me)
	_sr("element: the beaten side's walls stand +1s - Marta's Premiere Neige is 6s against a GALE card, 5s against GRANITE; your FROST wall is 6s against Vane's GALE",
		count_events(w_ga.events, "wall", {"seconds": 6.0}) == 1 and int(w_ga.wall["B"]["timed_t"]) > 0 and count_events(w_gr.events, "wall", {"seconds": 5.0}) == 1 and count_events(w_me.events, "wall", {"seconds": 6.0}) == 1)
	var c_cap: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "FROST", "tremblay", "Premiere Neige")   # spike x edge x native = 1.573 -> capped 1.5
	var c_nat: TNBSim = ringed.call(3, 7, "BOXERPUNCHER", "FROST", "tremblay", "Premiere Neige")   # vs Sam (FROST): spike x native = 1.43, the doc's own number
	var c_off: TNBSim = ringed.call(3, 7, "BOXERPUNCHER", "FROST", "moreau", "Premiere Neige")     # a Moreau throwing a Tremblay native: no home bonus
	_sr("house + cap: a Tremblay's Premiere Neige is x1.43 (spike x native) vs Sam and would be x1.573 vs Vane - clamped to the x1.5 cap; a Moreau throwing it gets no home bonus (x1.3)",
		absf(c_cap.hiss_mult("P") - 1.5) < 1e-6 and absf(c_nat.hiss_mult("P") - 1.43) < 1e-6 and absf(c_off.hiss_mult("P") - 1.3) < 1e-6)
	# RING 3: the feud. Moreau vs Tremblay is a FEUD edge; Kowalchuk vs Tremblay is not; a DEBT edge is not a feud; lineage qualifiers resolve to the house
	var f_yes: TNBSim = ringed.call(2, 7, "BOXERPUNCHER", "NONE", "tremblay")     # Jean-Guy Moreau: E05
	var f_no: TNBSim = ringed.call(1, 7, "BOXERPUNCHER", "NONE", "tremblay")      # Yuri Kowalchuk: no edge
	var f_line: TNBSim = ringed.call(17, 7, "BOXERPUNCHER", "NONE", "macisaac")   # Itzel: reyes_origin_line -> reyes, E02 with MacIsaac
	var f_debt: TNBSim = ringed.call(23, 7, "BOXERPUNCHER", "NONE", "okafor")     # Baro: petrov_root_system -> petrov, E04 is a DEBT
	f_yes.tension = 0.0; f_yes.contributed = 0.0; f_yes._earn_tension(10.0)
	f_no.tension = 0.0; f_no.contributed = 0.0; f_no._earn_tension(10.0)
	_sr("feud: House Tremblay vs House Moreau earns 12.5 for 10 (x1.25) and the card says so; vs Kowalchuk 10; MacIsaac vs a Reyes origin line is a feud; an Okafor DEBT to Petrov is not",
		f_yes.aff["feud"] and absf(f_yes.tension - 12.5) < 0.01 and "FEUD" in str(f_yes.aff["line"]) and not f_no.aff["feud"] and absf(f_no.tension - 10.0) < 0.01 and f_line.aff["feud"] and not f_debt.aff["feud"])
	# the style parameter packages (s1.2), each measured against the BOXER-PUNCHER control on the same seed
	var k_bp: TNBSim = ringed.call(0, 7, "BOXERPUNCHER", "NONE", "none")
	var k_sw: TNBSim = ringed.call(0, 7, "SWARMER", "NONE", "none")
	var k_ob: TNBSim = ringed.call(0, 7, "OUTBOXER", "NONE", "none")
	var k_sl: TNBSim = ringed.call(0, 7, "SLUGGER", "NONE", "none")
	# SWARMER: inside hooks/uppercuts -20% stamina, clinch windows +25%, herding +50%; reach -10%, guard capacity -10%
	var hook_cost := func(sim: TNBSim, spacing: float) -> float:
		thaw(sim); place(sim, spacing); sim.P["busy_t"] = 0; sim.P["cmd"] = {}; sim.P["stamina"] = 100.0; sim.P["pending"] = {}
		sim.step({"punch": "R_HOOK"}); var c_q: float = 100.0 - float(sim.P["stamina"]); clear_defense(sim.B); land(sim); return c_q
	var sw_in: float = hook_cost.call(k_sw, 1.2); var sw_out: float = hook_cost.call(k_sw, 1.6); var bp_in: float = hook_cost.call(k_bp, 1.2)
	k_sw._start_clinch("P"); k_bp._start_clinch("P")
	var sw_w: Array = k_sw.clinch["windows"].duplicate(); var bp_w: Array = k_bp.clinch["windows"].duplicate()
	k_sw.clinch = {}; k_sw.clinch_t = 0; k_bp.clinch = {}; k_bp.clinch_t = 0; k_sw.P["busy_t"] = 0; k_bp.P["busy_t"] = 0
	thaw(k_sw); place(k_sw, 1.4); var sw_b0: Vector2 = k_sw.B["pos"]; throw_clean(k_sw, "R_HOOK"); var sw_herd: float = (k_sw.B["pos"] - sw_b0).length()
	thaw(k_bp); place(k_bp, 1.4); var bp_b0: Vector2 = k_bp.B["pos"]; throw_clean(k_bp, "R_HOOK"); var bp_herd: float = (k_bp.B["pos"] - bp_b0).length()
	thaw(k_sw); thaw(k_bp); place(k_sw, 1.95); place(k_bp, 1.95); clear_defense(k_sw.B); clear_defense(k_bp.B)
	var sw_reach: String = k_sw.resolve_geometry(k_sw.P, k_sw.B, "R_STRAIGHT", false); var bp_reach: String = k_bp.resolve_geometry(k_bp.P, k_bp.B, "R_STRAIGHT", false)
	_sr("package SWARMER: hook %.1f inside (x0.8 of %.1f) and %.1f at range; clinch windows x1.25 (%s vs %s); herds %.2fm (x1.5); a 1.95m straight is out of reach (x0.9) where the control lands; guard cap x0.9" % [sw_in, bp_in, sw_out, JSON.stringify(sw_w), JSON.stringify(bp_w), sw_herd],
		absf(sw_in - bp_in * 0.8) < 0.15 and absf(sw_out - bp_in) < 0.15 and sw_w[0] == int(float(bp_w[0]) * 1.25) and sw_w[1] == int(float(bp_w[1]) * 1.25) and absf(sw_herd - 1.5 * bp_herd) < 0.01
		and sw_reach == "MISS_REACH" and bp_reach == "HIT" and absf(k_sw.P["guard_max"] - 0.9 * k_bp.P["guard_max"]) < 0.01)
	# OUT-BOXER: jab/straight range +12%, movement stamina -15%, back-step 85% vs 70%; power punches -10%, weave arc -10%
	thaw(k_ob); place(k_ob, 2.2); place(k_bp, 2.2); clear_defense(k_ob.B); clear_defense(k_bp.B)
	var ob_reach: String = k_ob.resolve_geometry(k_ob.P, k_ob.B, "R_STRAIGHT", false); var ob_hook: String = k_ob.resolve_geometry(k_ob.P, k_ob.B, "R_HOOK", false); var bp_reach2: String = k_bp.resolve_geometry(k_bp.P, k_bp.B, "R_STRAIGHT", false)
	place(k_ob, 3.0); k_ob.P["stamina"] = 100.0; k_ob.sprint_cd = 0; k_ob.P["busy_t"] = 0; k_ob.step({"sprint": true, "move": Vector2(0, -1)}); var ob_sprint: float = 100.0 - float(k_ob.P["stamina"])
	var backpedal := func(sim: TNBSim) -> float:
		thaw(sim); place(sim, 1.4); sim.P["busy_t"] = 0; var y0_q: float = sim.P["pos"].y
		run_ticks(sim, 60, {"move": Vector2(0, 1)}); return float(sim.P["pos"].y) - y0_q
	var ob_back: float = backpedal.call(k_ob); var bp_back: float = backpedal.call(k_bp)
	thaw(k_ob); place(k_ob, 1.4); k_ob.events.clear(); throw_clean(k_ob, "R_STRAIGHT", {"power": true}); var ob_pow := hit_dmg(k_ob, "B")
	thaw(k_bp); place(k_bp, 1.4); k_bp.events.clear(); throw_clean(k_bp, "R_STRAIGHT", {"power": true}); var bp_pow := hit_dmg(k_bp, "B")
	k_ob.P["dodge"] = "WEAVE"; k_ob.P["dodge_dir"] = 1; k_ob.P["dodge_t"] = 99; k_bp.P["dodge"] = "WEAVE"; k_bp.P["dodge_dir"] = 1; k_bp.P["dodge_t"] = 99
	var ob_lat: float = (k_ob._head_world(k_ob.P, k_ob.B)["p"] - k_ob.P["pos"]).length(); var bp_lat: float = (k_bp._head_world(k_bp.P, k_bp.B)["p"] - k_bp.P["pos"]).length()
	clear_defense(k_ob.P); clear_defense(k_bp.P)
	_sr("package OUT-BOXER: a 2.2m straight lands (x1.12) where the control and a hook miss; sprint-step costs %.1f (x0.85); back-step covers %.2fm vs %.2fm (85%% vs 70%%); power punch %.1f vs %.1f (x0.9); weave arc %.3f vs %.3f (x0.9)" % [ob_sprint, ob_back, bp_back, ob_pow, bp_pow, ob_lat, bp_lat],
		ob_reach == "HIT" and bp_reach2 == "MISS_REACH" and ob_hook == "MISS_REACH" and absf(ob_sprint - 3.4) < 0.15 and absf(ob_back / bp_back - 0.85 / 0.7) < 0.02 and absf(ob_pow / bp_pow - 0.9) < 0.01 and absf(ob_lat / bp_lat - 0.9) < 0.01)
	# SLUGGER: power/haymaker guard-shred +30%, composure pool +15%, ropes-zone damage +10%; hand speed -10% (startup x1.1), slip windows -15%
	var shred_on_block := func(sim: TNBSim) -> float:
		thaw(sim); place(sim, 1.4); sim.B["blocking"] = true; sim.B["guard_t"] = 999; sim.B["guard"] = sim.B["guard_max"]; sim.P["busy_t"] = 0; sim.P["cmd"] = {}
		sim.step({"punch": "R_STRAIGHT", "power": true}); sim.B["dodge"] = ""; sim.B["dodge_plan"] = []; sim.B["dodge_at"] = 0; sim.B["blocking"] = true; land(sim)
		var g_q: float = float(sim.B["guard_max"]) - float(sim.B["guard"]); sim.B["guard_t"] = 0; sim.B["blocking"] = false; return g_q
	var sl_shred: float = shred_on_block.call(k_sl); var bp_shred: float = shred_on_block.call(k_bp)
	var ropes_dmg := func(sim: TNBSim) -> float:
		thaw(sim); sim.P["pos"] = Vector2(0.0, -1.9); sim.B["pos"] = Vector2(0.0, -3.3); sim.events.clear(); throw_clean(sim, "R_STRAIGHT"); return hit_dmg(sim, "B")
	var sl_ropes: float = ropes_dmg.call(k_sl); var bp_ropes: float = ropes_dmg.call(k_bp)
	thaw(k_sl); place(k_sl, 1.4); k_sl.P["busy_t"] = 0; k_sl.P["cmd"] = {}; k_sl.step({"punch": "R_STRAIGHT"}); var sl_start: int = int(k_sl.P["pending"].get("startup", 0)); clear_defense(k_sl.B); land(k_sl)
	var sl_win: int = slip_window.call(k_sl)
	_sr("package SLUGGER: a blocked power straight shreds %.1f vs %.1f (x1.3); composure pool %.0f vs %.0f (x1.15); on the ropes %.1f vs %.1f (x1.1); straight startup %d ticks (x1.1 of %d); slip window %d ticks (x0.85)" % [sl_shred, bp_shred, k_sl.P["comp_max"], k_bp.P["comp_max"], sl_ropes, bp_ropes, sl_start, TNBSim.ms(220), sl_win],
		absf(sl_shred / bp_shred - 1.3) < 0.01 and absf(k_sl.P["comp_max"] / k_bp.P["comp_max"] - 1.15) < 1e-6 and absf(sl_ropes / bp_ropes - 1.1) < 0.01 and sl_start == TNBSim.ms(220.0 * 1.1) and sl_win == int(TNBSim.ms(400) * 0.85))
	# the boss wears his package too: Yuri's slugger chin and haymaker shred, Alfie's swarmer reach/herd/guard, Vane's out-boxer straights and softer haymaker, against Sam the boxer-puncher
	var b_sam := make_sim(3, 7); quiet(b_sam); var b_yu := make_sim(1, 7); quiet(b_yu); var b_al := make_sim(5, 7); quiet(b_al); var b_va := make_sim(0, 7); quiet(b_va)
	var boss_shred := func(sim: TNBSim) -> float:
		thaw(sim); place(sim, 1.4); sim.P["blocking"] = true; sim.P["block_t"] = 999; sim.P["guard"] = sim.P["guard_max"]; boss_lands(sim, "R_HOOKERCUT")
		var g_q: float = float(sim.P["guard_max"]) - float(sim.P["guard"]); sim.P["blocking"] = false; sim.P["block_t"] = 0; return g_q
	var yu_shred: float = boss_shred.call(b_yu); var sam_shred: float = boss_shred.call(b_sam)
	var boss_hit := func(sim: TNBSim, row: String) -> float:
		thaw(sim); place(sim, 1.4); clear_defense(sim.P); sim.P["comp"] = sim.P["comp_max"]; sim.events.clear(); boss_lands(sim, row); return hit_dmg(sim, "P")
	var va_hay: float = boss_hit.call(b_va, "R_HOOKERCUT"); var sam_hay: float = boss_hit.call(b_sam, "R_HOOKERCUT")
	thaw(b_al); place(b_al, 1.4); clear_defense(b_al.P); var al_p0: Vector2 = b_al.P["pos"]; boss_lands(b_al, "R_STRAIGHT"); var al_push: float = (b_al.P["pos"] - al_p0).length()
	thaw(b_sam); place(b_sam, 1.4); clear_defense(b_sam.P); var sam_p0: Vector2 = b_sam.P["pos"]; boss_lands(b_sam, "R_STRAIGHT"); var sam_push: float = (b_sam.P["pos"] - sam_p0).length()
	thaw(b_al); thaw(b_va); thaw(b_sam); place(b_al, 1.95); place(b_va, 2.2); place(b_sam, 2.2); clear_defense(b_al.P); clear_defense(b_va.P); clear_defense(b_sam.P)
	var al_reach: String = b_al.resolve_geometry(b_al.B, b_al.P, "R_STRAIGHT", false); var va_reach: String = b_va.resolve_geometry(b_va.B, b_va.P, "R_STRAIGHT", false); var sam_reach: String = b_sam.resolve_geometry(b_sam.B, b_sam.P, "R_STRAIGHT", false)
	_sr("boss packages: Yuri's chin %.0f vs Sam's %.0f (x1.15) and his haymaker shreds %.1f vs %.1f (x1.3); Alfie's guard %.1f vs %.1f (x0.9), his jab pushes %.2fm vs %.2fm (x1.5) and his 1.95m straight misses; Vane's 2.2m straight lands where Sam's misses and his haymaker is x0.9 (%.1f vs %.1f)" % [b_yu.B["comp_max"], b_sam.B["comp_max"], yu_shred, sam_shred, b_al.B["guard_max"], b_sam.B["guard_max"], al_push, sam_push, va_hay, sam_hay],
		absf(b_yu.B["comp_max"] / b_sam.B["comp_max"] - 1.15) < 1e-6 and absf(yu_shred / sam_shred - 1.3) < 0.01 and absf(b_al.B["guard_max"] / b_sam.B["guard_max"] - 0.9) < 1e-6 and absf(al_push / sam_push - 1.5) < 0.01
		and al_reach == "MISS_REACH" and va_reach == "HIT" and sam_reach == "MISS_REACH" and absf(va_hay / sam_hay - 0.9) < 0.01)

	# ================= PAC-060: the enemy coach (NP_10 s9) and the enemy's half of the economy (NP_05 s2) ==========
	var coached := func(boss_i: int, seed_v: int, lu_c: Array = TNBSim.LINEUP_MILLBROOK) -> TNBSim:
		var cs_ := make_sim(boss_i, seed_v, lu_c); quiet(cs_); cs_.coach_on = true; place(cs_, 1.4)
		return cs_
	var end_seg := func(sim: TNBSim, contributed_p: float = 0.0) -> void:     # -> the card; the rival corner resolves when the corner opens
		sim.mode = "FIGHT"; sim.eight = {}; sim.contributed = contributed_p
		sim._end_segment("smoke-forced")
	var coach_actions := func(sim: TNBSim) -> Array:
		for qe in sim.events:
			if qe["kind"] == "enemy_corner": return qe["actions"]
		return []
	# data + the sealed order: every boss opens qa dual with qa corner behind him; archetypes order the slots he controls
	var coach_ok := true; var r1_ok := true
	var tacs: Dictionary = {}
	for qt in content["tactics"].get("special", []): tacs[str(qt["id"])] = qt
	var boss_keys := ["body_drain_mult", "herd_mult", "clock_mult_leading"]
	for qb in TNBSim.BOSSES:
		var cq := make_sim(TNBSim.BOSSES.find(qb), 7)
		if cq.boss_name != qb or cq.blineup.size() != 3 or cq.breserves.size() != 1 or cq.blineup[0] != qb: r1_ok = false
		var rec: Dictionary = cq.coach
		if rec.is_empty() or not (str(rec.get("archetype", "")) in ["STANDARD", "AMBUSH", "WALL_FIRST", "RELAY_LADDER"]) or not (str(rec.get("super_trigger", "")) in content["coaches"]["triggers"]) or not content["coaches"]["tells"].has(str(rec.get("tell", ""))): coach_ok = false
		for tid in rec.get("library", []):
			if not tacs.has(str(tid)): coach_ok = false
			else:
				var consumed := false
				for qk in tacs[str(tid)]["effect"]:
					if qk in boss_keys: consumed = true
				if not consumed: coach_ok = false
	var o_std := make_sim(0, 7); var o_amb := make_sim(12, 7); var o_wall := make_sim(3, 7)
	_sr("coaches: 24/24 duals open with a corner record (archetype, trigger, tell, a library the boss side consumes); R1 stays the boss asked for; STANDARD %s / AMBUSH %s / WALL_FIRST %s" % [JSON.stringify(o_std.blineup), JSON.stringify(o_amb.blineup), JSON.stringify(o_wall.blineup)],
		coach_ok and r1_ok and o_std.blineup == ["cassidy_vane", "yuri_kowalchuk", "sam_tagaq"] and o_std.breserves == ["jean_guy_moreau"]
		and o_amb.blineup == ["hc0_surety", "hc7_echo", "hc4_cartographer"] and o_amb.breserves == ["hc9_choir"]
		and o_wall.blineup == ["sam_tagaq", "anders_vey", "alfie_crane"] and o_wall.breserves == ["ada_okafor"])
	# the Academy counter-picks: Cal comes up for Carter against qa slugger card; the Super is spent in corner 1; the swap was free; his lie scores
	var lu_ac: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu_ac[1]["style"] = "SLUGGER"; lu_ac[1]["element"] = "GRANITE"
	var ac: TNBSim = coached.call(6, 7, lu_ac); end_seg.call(ac); ac.events.clear(); ac.step({"corner": 1})    # the card -> the corner opens: his decisions
	var ac_acts: Array = coach_actions.call(ac)
	var ac_swap: bool = ac.blineup == ["anders_vey", "commissioner_cal", "carter_okafor"] and ac.breserves == ["chiamaka_okafor"] and ac.btension == 0.0 and ac.bswaps_used == 1
	var ac_tell: bool = count_events(ac.events, "coach_tell", {"tell": "counter_picks"}) == 1 and count_events(ac.events, "coach_action", {"action": "swap", "id": "commissioner_cal"}) == 1
	var ac_super: bool = ac.bsuper_used and count_events(ac.events, "coach_action", {"action": "super", "id": "switch_up"}) == 1
	ac.step({"corner": 1}); quiet(ac); ac.coach_on = true; place(ac, 1.4)
	var ac_bep: int = ten_boss_hits.call(ac)
	_sr("the Academy corner: %s - Cal swapped up for Carter (free) against your slugger card, Switch-Up burned in corner 1, and his lie scores 22 for ten" % JSON.stringify(ac_acts),
		ac_swap and ac_tell and ac_super and ac.boss_name == "commissioner_cal" and ac._style_adv("B") and ac_bep == 22, "ep %d" % ac_bep)
	# True North never swaps - even with the better card on the bench, and the tell says so; Iron Resolve the corner after qa drop conceded
	var lu_tn: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu_tn[1]["style"] = "OUTBOXER"; lu_tn[1]["element"] = "GRANITE"
	var tn: TNBSim = coached.call(3, 7, lu_tn); tn.P["comp"] = tn.P["comp_max"]; tn.B["comp"] = 0.5; tn._drop(false)
	end_seg.call(tn); tn.events.clear(); tn.step({"corner": 1})
	var tn_acts: Array = coach_actions.call(tn)
	var tn_hold: bool = tn.blineup == ["sam_tagaq", "anders_vey", "alfie_crane"] and count_events(tn.events, "coach_tell", {"tell": "never_swaps"}) == 1 and count_events(tn.events, "coach_action", {"action": "swap"}) == 0
	tn.step({"corner": 1}); quiet(tn); tn.coach_on = true; place(tn, 1.4); clear_defense(tn.B); tn.B["comp"] = 0.5; tn.bsurvival_used = true   # no survival grab: the wobble is the point
	var iron_t0: int = tn.bno_drop_t
	throw_clean(tn, "R_STRAIGHT")
	var tn_iron: bool = iron_t0 == TNBSim.ms(30000) and count_events(tn.events, "iron_resolve_b") == 1 and tn.B["drops"] == 0 and tn.mode == "FIGHT"
	var tn2: TNBSim = coached.call(3, 7); end_seg.call(tn2); tn2.events.clear(); tn2.step({"corner": 1})
	_sr("the True North corner: %s - never swaps (Ada was the better card; the tell fired), burns Iron Resolve the corner after a drop conceded (Vey wobbles at 1 instead of going down); no drop, no Super" % JSON.stringify(tn_acts),
		tn_hold and tn_iron and not tn2.bsuper_used and count_events(tn2.events, "coach_action", {"action": "super"}) == 0)
	# Grain Kings: the Super comes the corner after qa FLASH DROP conceded, not after qa plain one
	var gk: TNBSim = coached.call(1, 7); gk.B["comp"] = 0.5; gk._drop(false, true); end_seg.call(gk); gk.events.clear(); gk.step({"corner": 1})
	var gk2: TNBSim = coached.call(1, 7); gk2.B["comp"] = 0.5; gk2._drop(false); end_seg.call(gk2); gk2.events.clear(); gk2.step({"corner": 1})
	_sr("the Grain Kings corner burns Iron Resolve after conceding a FLASH DROP (tell fires) and sits on it after a plain DROP",
		gk.bsuper_used and count_events(gk.events, "coach_tell", {"tell": "burns_super_after_flash_drop"}) == 1 and not gk2.bsuper_used)
	# Ascendant B: the book says the first tactic goes in the corner before R3 - never before; Body Doctrine then doubles his body drain on you
	var ab: TNBSim = coached.call(0, 7); ab.btension = 30.0; ab.score_b = 5
	end_seg.call(ab); ab.events.clear(); ab.step({"corner": 1})
	var ab_c1: Array = coach_actions.call(ab)
	var ab_no_tactic_c1 := true
	for qa in ab_c1:
		if str(qa).begins_with("tactic:"): ab_no_tactic_c1 = false
	ab.step({"corner": 1}); ab.btension = 30.0; ab.score_b = 9; ab.ep_b += 10     # leading on score and on EP: the segment is his (+5, EP majority)
	end_seg.call(ab); ab.events.clear(); ab.step({"corner": 1})
	var ab_c2: Array = coach_actions.call(ab)
	var ab_tell: bool = count_events(ab.events, "coach_tell", {"tell": "book_tactic_r3"}) == 1 and "tactic:body_doctrine" in ab_c2 and absf(ab.btension - 25.0) < 0.01   # 30 + 5 for the segment he won - 10
	ab.step({"corner": 1}); quiet(ab); ab.coach_on = true; place(ab, 1.4); clear_defense(ab.P); ab.P["comp"] = ab.P["comp_max"]
	var ab_st0: float = ab.P["stamina"]; boss_lands(ab, "R_HOOK", 1.0, true)
	_sr("the Ascendant B corner: corner 1 %s (no tactic before R3, the tell), corner 2 %s - Body Doctrine paid 10 (30 + 5 for his segment win - 10 = %.0f) and his body hook drains %.0f" % [JSON.stringify(ab_c1), JSON.stringify(ab_c2), ab.btension, ab_st0 - ab.P["stamina"]],
		ab_no_tactic_c1 and ab_tell and ab.btactic_fx.get("body_drain_mult", 0.0) == 2.0 and absf((ab_st0 - ab.P["stamina"]) - 12.0) < 0.3)
	# Montreal ices the clock when he leads: Ice the Clock first from his library, Switch-Up on when_leading; his clock runs 1/0.8 while he leads on EP
	var mt_: TNBSim = coached.call(18, 7); mt_.btension = 30.0; mt_.score_b = 3
	end_seg.call(mt_); mt_.events.clear(); mt_.step({"corner": 1})
	var mt_acts: Array = coach_actions.call(mt_)
	var mt_tell: bool = count_events(mt_.events, "coach_tell", {"tell": "ices_the_clock_when_leading"}) == 1
	mt_.step({"corner": 1}); quiet(mt_); mt_.coach_on = true; place(mt_, 1.4)
	mt_.ep_b += 5; var mt_c0: int = mt_.clock_t; run_ticks(mt_, 120); var his_lead_drop: int = mt_c0 - mt_.clock_t
	mt_.ep_p += 10; var mt_c1: int = mt_.clock_t; run_ticks(mt_, 120); var your_lead_drop: int = mt_c1 - mt_.clock_t
	_sr("the Montréal corner: %s - ices the clock when ahead (tell), Switch-Up on when_leading; his segment clock runs %d per 120 while he leads on EP, %d when you do" % [JSON.stringify(mt_acts), his_lead_drop, your_lead_drop],
		"tactic:ice_the_clock" in mt_acts and "super:switch_up" in mt_acts and mt_tell and his_lead_drop == 150 and your_lead_drop == 120)
	# Hostile Crowd both ways: yours locks his next corner; the Hollow Circuit's (first corner, the tell) locks yours
	var hcp: TNBSim = coached.call(0, 7); equip.call(hcp, [], "hostile_crowd", []); end_seg.call(hcp); hcp.step({"corner": 1})
	var hcp_ok := hcp.corner_action({"kind": "super"}); hcp.step({"corner": 1}); quiet(hcp); hcp.coach_on = true
	end_seg.call(hcp); hcp.events.clear(); hcp.step({"corner": 1})
	var his_locked: bool = count_events(hcp.events, "coach_locked") == 1 and coach_actions.call(hcp).is_empty() and hcp.enemy_lock == 0
	var hce: TNBSim = coached.call(12, 7); end_seg.call(hce); hce.events.clear(); hce.step({"corner": 1})
	var hce_c1: Array = coach_actions.call(hce)
	hce.step({"corner": 1}); quiet(hce); hce.coach_on = true
	end_seg.call(hce); hce.events.clear(); hce.step({"corner": 1})
	var hce_refused := hce.corner_action({"kind": "save_bar"})
	var yours_locked: bool = int(hce.corner["actions_left"]) == 0 and count_events(hce.events, "corner_locked") == 1 and not hce_refused and count_events(hce.events, "corner_refused", {"why": "locked out by the crowd"}) == 1
	_sr("Hostile Crowd: yours locks his next corner (he takes nothing, the lock is spent); the Hollow Circuit's %s locks yours - 0 actions, refused as locked out (tell fired)" % JSON.stringify(hce_c1),
		hcp_ok and his_locked and "super:hostile_crowd" in hce_c1 and count_events(hce.events, "coach_tell", {"tell": "hostile_crowd_first_corner"}) == 0 and yours_locked)
	# The Reveal names his slot as it stands after his corner - the post-swap truth
	var rv2: TNBSim = coached.call(6, 7, lu_ac); equip.call(rv2, [], "iron_resolve", ["the_reveal"]); end_seg.call(rv2); rv2.step({"corner": 1}); rv2.events.clear()
	var rv2_ok := rv2.corner_action({"kind": "staff", "id": "the_reveal"})
	_sr("The Reveal names the post-swap slot: the Academy swapped Cal in, the reveal says Cal", rv2_ok and count_events(rv2.events, "reveal", {"boss": "commissioner_cal"}) == 1)
	# the enemy's half of the economy (NP_05 s2, both teams earn), and yours on the canonical table
	var eco: TNBSim = coached.call(1, 7); eco.btension = 0.0; clear_defense(eco.P); eco.P["comp"] = eco.P["comp_max"]
	boss_lands(eco, "R_STRAIGHT"); var his_center: float = eco.btension                          # both in CENTER at 1.4m: 0 + 2
	thaw(eco); eco.P["pos"] = Vector2(0.0, 2.6); eco.B["pos"] = Vector2(0.0, 1.2); eco.P["comp"] = eco.P["comp_max"]; eco.btension = 0.0
	boss_lands(eco, "R_STRAIGHT"); var his_plain: float = eco.btension                           # off-center clean hit: 0
	thaw(eco); eco.btension = 0.0; boss_lands(eco, "R_STRAIGHT", 1.3); var his_counter: float = eco.btension   # qa counter (mult > 1): 3
	thaw(eco); place(eco, 1.4); eco.btension = 0.0; eco.P["busy_t"] = 0; eco.P["cmd"] = {}; eco.step({"punch": "R_STRAIGHT"}); eco.B["dodge"] = "SLIP"; eco.B["dodge_dir"] = 1; eco.B["dodge_t"] = 999; eco.B["dodge_plan"] = []; eco.B["dodge_at"] = 0; land(eco)
	var his_slip: float = eco.btension                                                            # his read beat your straight: +2
	clear_defense(eco.B); thaw(eco); eco.btension = 0.0; eco.P["comp"] = 0.5; place(eco, 1.4); clear_defense(eco.P); boss_lands(eco, "R_STRAIGHT")
	var his_drop: float = eco.btension; eco.mode = "FIGHT"; eco.eight = {}                        # you went down: +10
	eco.btension = 40.0; boss_desperation(eco); var his_cast_cost: float = eco.btension              # Grain Elevator (35) paid from his bar
	eco.cast = {}; eco.bdesp_used = false; eco.bstate = "IDLE"; eco.btimer = 1 << 30; eco.B["busy_t"] = 0
	eco.btension = 0.0; var cast_anyway := boss_desperation(eco); var his_floor: float = eco.btension  # qa bar of 0 never blocks the authored beat
	eco.cast = {}; eco.bstate = "IDLE"; eco.btimer = 1 << 30
	eco.score_b += 1; eco.btension = 0.0; eco.bcontributed = 0.0; end_seg.call(eco); var his_seg_win: float = eco.btension   # his segment win: +5
	_sr("his bar: a clean hit in CENTER +2, off-center +0, a counter +3, his read that beat your punch +2, the CENTER hit that dropped you +12, his segment win +5; his desperation pays 35 from his bar and still goes at 0",
		his_center == 2.0 and his_plain == 0.0 and his_counter == 3.0 and his_slip == 2.0 and his_drop == 12.0 and his_cast_cost == 5.0 and cast_anyway and his_floor == 0.0 and his_seg_win == 5.0,
		"center %.0f plain %.0f counter %.0f slip %.0f drop %.0f cast %.0f floor %.0f win %.0f" % [his_center, his_plain, his_counter, his_slip, his_drop, his_cast_cost, his_floor, his_seg_win])
	var yc: TNBSim = coached.call(1, 7); yc.tension = 0.0; throw_clean(yc, "L_STRAIGHT"); var my_center: float = yc.tension
	thaw(yc); yc.P["pos"] = Vector2(0.0, 2.6); yc.B["pos"] = Vector2(0.0, 1.2); yc.tension = 0.0; throw_clean(yc, "L_STRAIGHT"); var my_plain: float = yc.tension
	thaw(yc); yc.P["pos"] = Vector2(0.0, 2.6); yc.B["pos"] = Vector2(0.0, 1.2); yc.tension = 0.0; yc.P["busy_t"] = 0; yc.P["cmd"] = {}; yc.P["counter_t"] = 60; yc.step({"punch": "R_STRAIGHT"}); clear_defense(yc.B); land(yc); var my_counter: float = yc.tension
	thaw(yc); yc.P["pos"] = Vector2(0.0, 2.6); yc.B["pos"] = Vector2(0.0, 1.2); yc.tension = 0.0; yc.P["busy_t"] = 0; yc.P["cmd"] = {}; yc.P["flash_t"] = 60; yc.step({"punch": "R_STRAIGHT"}); clear_defense(yc.B); land(yc); var my_flash: float = yc.tension
	thaw(yc); place(yc, 1.4); yc.tension = 0.0; yc.P["dodge"] = "SLIP"; yc.P["dodge_t"] = 999; yc.P["dodge_dir"] = 1; boss_lands(yc, "R_STRAIGHT"); var my_slip: float = yc.tension
	clear_defense(yc.P); thaw(yc); place(yc, 1.4); yc.tension = 0.0; yc.P["blocking"] = true; yc.P["block_t"] = 1; boss_lands(yc, "R_STRAIGHT"); var my_pb: float = yc.tension; yc.P["blocking"] = false; yc.P["block_t"] = 0
	_sr("your bar on the canonical table: clean hit in CENTER +2, off-center +0, counter +3, flash +5, slip +2, perfect block +2 (segment win +5 is gated above)",
		my_center == 2.0 and my_plain == 0.0 and my_counter == 3.0 and my_flash == 5.0 and my_slip == 2.0 and my_pb == 2.0,
		"center %.0f plain %.0f counter %.0f flash %.0f slip %.0f pb %.0f" % [my_center, my_plain, my_counter, my_flash, my_slip, my_pb])
	# the feud is qa geyser both ways; his Perfect Round doubles his sources; 25 banked sends his next fighter out CHARGED
	var fb: TNBSim = ringed.call(2, 7, "BOXERPUNCHER", "NONE", "tremblay"); fb.btension = 0.0; fb._earn_tension_b(10.0)
	var nm: TNBSim = coached.call(19, 7); nm.btension = 0.0; nm.score_p = 2
	end_seg.call(nm); nm.events.clear(); nm.step({"corner": 1}); var nm_acts: Array = coach_actions.call(nm)
	nm.step({"corner": 1}); nm.btension = 0.0; nm.bcontributed = 0.0; nm._earn_tension_b(10.0)
	var chg: TNBSim = coached.call(1, 7); chg.bcontributed = 30.0; end_seg.call(chg); next_segment(chg)
	_sr("feud: House Tremblay vs Moreau pays him 12.5 for 10 too; the Netmen corner trailing burns Perfect Round (%s) and his next segment earns 20 for 10; 30 banked sends his next fighter out CHARGED (10s, feet x1.1)" % JSON.stringify(nm_acts),
		absf(fb.btension - 12.5) < 0.01 and "super:perfect_round" in nm_acts and absf(nm.btension - 20.0) < 0.01 and chg.brelay_chain == 1 and int(chg.B["charge_t"]) == TNBSim.ms(10000) and absf(chg._speed_mult("B") - 1.1) < 0.001)

	# ================= PAC-061: dual formats (NP_01 s2 / s3.3 / s6 / s8) ==========
	var names_of := func(cards: Array) -> Array:
		var outn: Array = []
		for cdq in cards: outn.append(str(cdq["name"]) if cdq is Dictionary else str(cdq))
		return outn
	var seg_end := func(sim: TNBSim, ep_lead: int = 0) -> void:                # end the segment with an EP result, no fight
		sim.mode = "FIGHT"; sim.eight = {}
		if ep_lead > 0: sim.ep_p += ep_lead
		elif ep_lead < 0: sim.ep_b -= ep_lead
		sim._end_segment("smoke-forced")
	var l8: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true)
	var l3: Array = [TNBSim.LINEUP_MILLBROOK_8[0].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[2].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[3].duplicate(true)]   # RORY, PRIYA, MARCUS
	var l1: Array = [TNBSim.LINEUP_MILLBROOK_8[0].duplicate(true)]
	var f_san := make_sim(0, 7, l8, "sanctioned"); var f_min := make_sim(0, 7); var f_iron := make_sim(0, 7, l3, "iron"); var f_gau := make_sim(0, 7, l1, "gauntlet"); var f_bli := make_sim(0, 7, l8, "blind")
	_sr("formats: five records load; the sanctioned dual dresses 5 + 3 both sides (his STANDARD order %s, bench %s), the mini 3 + 1, the Iron dual repeats 3 across 5 slots both sides, the Gauntlet is one fighter five times vs five, blind is a sanctioned shape" % [JSON.stringify(f_san.blineup), JSON.stringify(f_san.breserves)],
		f_san.segments() == 5 and names_of.call(f_san.lineup) == ["RORY", "JUNE", "PRIYA", "MARCUS", "SAM"] and names_of.call(f_san.reserves) == ["DEX", "YURI", "MARTA"]
		and f_san.blineup == ["cassidy_vane", "carter_okafor", "ada_okafor", "sam_tagaq", "anders_vey"] and f_san.breserves == ["yuri_kowalchuk", "jean_guy_moreau", "alfie_crane"]
		and f_min.segments() == 3 and names_of.call(f_min.lineup) == ["RORY", "PRIYA", "MARCUS"] and names_of.call(f_min.reserves) == ["JUNE"] and f_min.blineup.size() == 3 and f_min.breserves.size() == 1
		and f_iron.segments() == 5 and names_of.call(f_iron.lineup) == ["RORY", "PRIYA", "MARCUS", "RORY", "PRIYA"] and f_iron.reserves.is_empty() and f_iron.blineup == ["cassidy_vane", "yuri_kowalchuk", "jean_guy_moreau", "cassidy_vane", "yuri_kowalchuk"] and f_iron.breserves.is_empty()
		and names_of.call(f_gau.lineup) == ["RORY", "RORY", "RORY", "RORY", "RORY"] and f_gau.blineup == ["cassidy_vane", "ada_okafor", "yuri_kowalchuk", "jean_guy_moreau", "sam_tagaq"] and f_gau.breserves.is_empty()
		and f_bli.segments() == 5 and f_bli.fmt.get("blind", false) and f_bli.lineup.size() == 5 and f_bli.reserves.size() == 3)
	# the sanctioned dual runs five segments; its corner offers three reserves and the not-yet-fought slots; the swap rules generalise
	var sn := make_sim(0, 7, l8, "sanctioned"); quiet(sn); sn.tension = 30.0
	seg_end.call(sn, 5); sn.step({"corner": 1})
	var sn_opts: Array = sn.corner_options()["swap"]
	var sn_s1 := sn.corner_action({"kind": "swap", "arg": "DEX"})             # a reserve for R2's JUNE: free
	var sn_s2 := sn.corner_action({"kind": "swap", "arg": "SAM"})             # R5's SAM up to R2 for DEX: 15 Tension
	var sn_after: Array = names_of.call(sn.lineup); var sn_res: Array = names_of.call(sn.reserves)
	sn.step({"corner": 1})
	var modes: Array = []
	for fi in 4:
		seg_end.call(sn, 5); modes.append(sn.mode)
		if sn.mode != "OVER": next_segment(sn)
	_sr("sanctioned: corner 1 offers %s; DEX in for JUNE (free) then SAM up for DEX (-15) -> %s, reserves %s; five segments end the dual (modes after R2..R5: %s)" % [JSON.stringify(sn_opts), JSON.stringify(sn_after), JSON.stringify(sn_res), JSON.stringify(modes)],
		sn_opts == ["DEX", "YURI", "MARTA", "PRIYA", "MARCUS", "SAM"] and sn_s1 and sn_s2 and sn_after == ["RORY", "SAM", "PRIYA", "MARCUS", "DEX"] and sn_res == ["JUNE", "YURI", "MARTA"] and absf(sn.tension - 15.0 - 5.0 * 5) < 0.01
		and modes == ["CARD", "CARD", "CARD", "OVER"] and sn.seg_wins_p == 5)
	# segment wins are EP majority (s3.2): a DROP is the score, the segment goes to whoever won the exchanges
	var ew := make_sim(1, 7); quiet(ew); ew.B["comp"] = 0.5; ew._drop(false); ew.btension = 0.0; ew.tension = 0.0
	seg_end.call(ew, -6)
	_sr("segment wins by EP majority: you scored the DROP (1-0) but lost the exchanges 0-6 - the segment and its +5 are his", ew.score_p == 1 and ew.seg_wins_b == 1 and ew.seg_wins_p == 0 and absf(ew.btension - 5.0) < 0.01 and ew.tension == 0.0)
	# the ladder (s3.3): score, then segment wins, then counter hits, then the Golden DROP
	var la := make_sim(0, 7); quiet(la)
	seg_end.call(la, 4); next_segment(la); seg_end.call(la, -4); next_segment(la); seg_end.call(la, 4)
	var lbq := make_sim(0, 7); quiet(lbq); lbq.counters_p = 3; lbq.counters_b = 1
	seg_end.call(lbq); next_segment(lbq); seg_end.call(lbq); next_segment(lbq); seg_end.call(lbq)
	_sr("ladder: equal score -> segment wins decide (%s); equal segments -> counter hits decide (%s)" % [str(la.feed), str(lbq.feed)],
		la.mode == "OVER" and "MILLBROOK WINS ON SEGMENTS" in str(la.feed) and lbq.mode == "OVER" and "MILLBROOK WINS ON COUNTERS" in str(lbq.feed))
	# all equal -> the Golden DROP: any dressed fighter, condition carried, no clock, first DROP wins
	var g6 := make_sim(0, 7); quiet(g6)
	g6.P["comp"] = 20.0; seg_end.call(g6); next_segment(g6)                                   # RORY leaves R1 at 20 composure
	g6.P["stamina"] = 40.0; g6.P["guard"] = 30.0; g6.P["comp"] = 30.0; seg_end.call(g6); next_segment(g6)   # PRIYA leaves R2 at 40 / 30 / 30
	g6.B["comp"] = 12.0; seg_end.call(g6)                                                    # MARCUS whole; Sam leaves R3 hurt
	var r6_card: bool = g6.mode == "CARD" and g6.r6 and count_events(g6.events, "seg_card", {"why": "GOLDEN DROP"}) == 1 and count_events(g6.events, "r6", {"default": "MARCUS"}) == 1
	g6.step({"corner": 1})
	var r6_opts: Array = g6.corner_options()["swap"]
	var r6_free: bool = int(g6.corner_options()["swap_cost"]) == 0
	var r6_pick := g6.corner_action({"kind": "swap", "arg": "PRIYA"})
	var his_pick: String = g6.blineup[3]
	g6.step({"corner": 1})
	var r6_fight: bool = g6.mode == "FIGHT" and g6.pname() == "PRIYA" and g6.clock_t > TNBSim.ms(3600000) and absf(g6.P["stamina"] - 55.0) < 0.01 and absf(g6.P["guard"] - 30.0) < 0.01 and absf(g6.P["comp"] - 30.0) < 0.01 and count_events(g6.events, "carried", {"who": "P", "name": "PRIYA"}) == 1
	quiet(g6); place(g6, 1.4); clear_defense(g6.B); g6.B["comp"] = 0.5; g6.bsurvival_used = true
	throw_clean(g6, "R_STRAIGHT")
	_sr("Golden DROP: three drawn segments tie the ladder -> the card names your freshest (MARCUS); the pick is free from anyone dressed (%s); PRIYA enters as she left R2 (30 guard, 30 composure; her 40 stamina +15 from the cutman on the stool since PAC-074 = 55), no clock; his pick was his freshest (%s); the first DROP ends it: %s" % [JSON.stringify(r6_opts), his_pick, str(g6.feed)],
		r6_card and r6_opts == ["RORY", "PRIYA", "JUNE"] and r6_pick and r6_free and r6_fight and his_pick == "yuri_kowalchuk" and g6.mode == "OVER" and "MILLBROOK WINS - GOLDEN DROP" in str(g6.feed))
	var g6b := make_sim(0, 7); quiet(g6b)
	seg_end.call(g6b); next_segment(g6b); seg_end.call(g6b); next_segment(g6b); seg_end.call(g6b); next_segment(g6b); next_segment(g6b)
	quiet(g6b); place(g6b, 1.4); clear_defense(g6b.P); g6b.P["comp"] = 0.5; boss_lands(g6b, "R_STRAIGHT")
	_sr("Golden DROP the other way: his first DROP ends it - %s" % str(g6b.feed), g6b.r6 and g6b.mode == "OVER" and "ASCENDANT WINS - GOLDEN DROP" in str(g6b.feed) and count_events(g6b.events, "dual_end", {"rung": "sudden_death"}) == 1)
	# the Iron dual: RORY fights R1 and R4; he comes back as he left, and the corner's restores finally have something to restore
	var ir := make_sim(0, 7, l3, "iron"); quiet(ir); ir.tension = 40.0
	ir.P["stamina"] = 40.0; ir.P["guard"] = 30.0; ir.P["comp"] = 20.0; ir.B["comp"] = 50.0
	seg_end.call(ir); next_segment(ir); seg_end.call(ir); next_segment(ir); seg_end.call(ir); ir.step({"corner": 1})   # the corner before R4
	var ir_opts: Array = ir.corner_options()["swap"]
	var ir_pj := ir.corner_action({"kind": "staff", "id": "patch_job"})
	var ir_sw := ir.corner_action({"kind": "tactic", "id": "second_wind_call"})
	ir.step({"corner": 1})
	var ir_ok: bool = ir.pname() == "RORY" and ir.boss_name == "cassidy_vane" and absf(ir.P["comp"] - 50.0) < 0.01 and absf(ir.P["stamina"] - 95.0) < 0.01 and absf(ir.P["guard"] - 30.0) < 0.01 and absf(ir.B["comp"] - 50.0) < 0.01
	var ir2 := make_sim(0, 7, l3, "iron"); quiet(ir2); ir2.P["stamina"] = 40.0
	seg_end.call(ir2); next_segment(ir2); seg_end.call(ir2); next_segment(ir2); seg_end.call(ir2); ir2.step({"corner": 1})
	ir2.corner_action({"kind": "staff", "id": "loosen_up"}); ir2.step({"corner": 1})
	_sr("Iron dual: the corner before R4 offers everyone else dressed (%s); Patch Job +30 and Second Wind +40 land on RORY's carried 20 / 40 with the cutman's +15 on the stool since PAC-074 (-> 50 composure, 95 stamina, guard 30 as left); Vane comes back at the 50 he left with; Loosen Up's 110 cap does not top up a carried 40 (+15: 55)" % JSON.stringify(ir_opts),
		ir_opts == ["PRIYA", "MARCUS"] and ir_pj and ir_sw and ir_ok and ir2.pname() == "RORY" and absf(ir2.P["stamina"] - 55.0) < 0.01 and absf(ir2.stamina_cap - 110.0) < 0.01)
	# the Gauntlet: one fighter, five segments, no one to swap in, condition carried the whole way
	var ga := make_sim(0, 7, l1, "gauntlet"); quiet(ga); ga.P["stamina"] = 50.0
	seg_end.call(ga); ga.step({"corner": 1})
	var ga_refused := ga.corner_action({"kind": "swap", "arg": "PRIYA"})
	ga.step({"corner": 1}); var ga_r2: float = ga.P["stamina"]
	ga.P["stamina"] = 30.0; seg_end.call(ga); next_segment(ga); var ga_r3: float = ga.P["stamina"]
	_sr("Gauntlet: the swap is refused (no one else is dressed); RORY carries 50 into R2 and 30 into R3 against a fresh boss each time, the cutman's +15 on top at each corner since PAC-074 (%.0f, %.0f)" % [ga_r2, ga_r3],
		not ga_refused and count_events(ga.events, "corner_refused", {"why": "PRIYA is not available (no one else is dressed)"}) == 1 and absf(ga_r2 - 65.0) < 0.01 and absf(ga_r3 - 45.0) < 0.01 and ga.pname() == "RORY" and ga.seg_idx == 2 and ga.boss_name == "yuri_kowalchuk")
	# the Blind dual: no reveals - The Reveal is refused and its charge kept, the corner names no slot, the matchup card still fires at the bell
	var bl := make_sim(0, 7, l8, "blind"); quiet(bl); equip.call(bl, [], "iron_resolve", ["the_reveal"]); seg_end.call(bl); bl.step({"corner": 1})
	var bl_rv := bl.corner_action({"kind": "staff", "id": "the_reveal"})
	var bl_open: bool = count_events(bl.events, "corner_open", {"boss": "?"}) == 1
	bl.events.clear(); bl.step({"corner": 1})
	_sr("Blind dual: The Reveal is refused (charge kept), the corner shows '?' for his slot, and the matchup card still names him at the bell",
		not bl_rv and count_events(bl.events, "reveal") == 0 and int(bl.staff_charges.get("the_reveal", 0)) == 1 and bl_open and count_events(bl.events, "matchup") == 1 and bl.mode == "FIGHT")

	# ================= PAC-062: manager mode (NP_10 s8) - the card plays without you ==========
	var auto_sim := func(boss_i: int, seed_v: int, style: String, frozen: bool) -> TNBSim:
		var lu_a: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu_a[0]["style"] = style
		var sa := make_sim(boss_i, seed_v, lu_a); sa.delegate_all = true; sa.new_dual()
		if frozen: quiet(sa); place(sa, 1.4)
		return sa
	var share := func(st: Dictionary, rows: Array) -> float:
		var nq := 0
		for rw in rows: nq += int(st["rows"].get(rw, 0))
		return float(nq) / maxf(1.0, float(st["punches"]))
	var mean_d := func(st: Dictionary) -> float: return float(st["dist_sum"]) / maxf(1.0, float(st["dist_n"]))
	# delegation is a corner call, free, per segment or for the rest of the dual; a delegated segment ignores your fight keys, never your corner keys
	var dg := make_sim(0, 7); quiet(dg); to_corner.call(dg, 0.0)
	var dg_left0: int = dg.corner["actions_left"]
	var dg_ok := dg.corner_action({"kind": "delegate"})
	var dg_free: bool = int(dg.corner["actions_left"]) == dg_left0 and dg.delegate_next and not dg.delegate_all
	dg.step({"corner": 1}); var dg_r2: bool = dg.delegated and count_events(dg.events, "delegated", {"who": "PRIYA"}) == 1
	quiet(dg); place(dg, 3.0); dg.events.clear(); dg.step({"punch": "R_STRAIGHT"})
	var dg_ignored: bool = dg.P["cmd"].is_empty() and dg.P["pending"].is_empty() and int(dg.auto_stats["punches"]) == 0
	to_corner.call(dg, 0.0); var dg_r3_hands: bool = false
	dg.corner_action({"kind": "delegate_all"}); dg.step({"corner": 1}); dg_r3_hands = dg.delegated and dg.delegate_all
	var dh := make_sim(0, 7); quiet(dh); dh.delegate_all = true; to_corner.call(dh, 0.0); dh.corner_action({"kind": "hands_on"}); dh.step({"corner": 1})
	_sr("delegation: a free corner call - 'delegate' hands PRIYA R2 (the card plays, your punch is ignored at the bell, the corner keys still open the corner), 'delegate_all' the rest, 'hands_on' takes it back",
		dg_ok and dg_free and dg_r2 and dg_ignored and dg_r3_hands and not dh.delegated and not dh.delegate_all)
	# AI segments earn 85%; a held bar is held by the profile too
	var d85 := make_sim(1, 7); quiet(d85); d85.delegate_all = true; d85.new_dual(); d85.tension = 0.0; d85._earn_tension(10.0)
	var dn := make_sim(1, 7); quiet(dn); dn.tension = 0.0; dn._earn_tension(10.0)
	var dsb: TNBSim = auto_sim.call(1, 7, "BOXERPUNCHER", true); dsb.save_bar = true; dsb.tension = 100.0; dsb.B["comp"] = 5.0
	run_ticks(dsb, TNBSim.ms(10000))
	var dcast: TNBSim = auto_sim.call(1, 7, "BOXERPUNCHER", true); dcast.tension = 100.0; dcast.B["comp"] = 5.0; dcast.B["guard_open_t"] = 1 << 20
	run_ticks(dcast, TNBSim.ms(10000))
	_sr("AI segments earn 85%% (10 -> 8.5; 10 hands-on); the profile casts into an open wobbled boss with a full bar (%d casts in 10s) and never spends a held bar (%d)" % [int(dcast.auto_stats["casts"]), int(dsb.auto_stats["casts"])],
		absf(d85.tension - 8.5) < 0.01 and absf(dn.tension - 10.0) < 0.01 and int(dcast.auto_stats["casts"]) >= 1 and count_events(dcast.events, "cast", {"who": "P"}) >= 1 and int(dsb.auto_stats["casts"]) == 0 and count_events(dsb.events, "cast", {"who": "P"}) == 0)
	# the archetypes hold their bands and throw their mixes (30s against a frozen Yuri, seed 7)
	var sw_a: TNBSim = auto_sim.call(1, 7, "SWARMER", true); run_ticks(sw_a, 3600); var sw_st: Dictionary = sw_a.auto_stats
	var ob_a: TNBSim = auto_sim.call(1, 7, "OUTBOXER", true); run_ticks(ob_a, 3600); var ob_st: Dictionary = ob_a.auto_stats
	var sl_a: TNBSim = auto_sim.call(1, 7, "SLUGGER", true); run_ticks(sl_a, 3600); var sl_st: Dictionary = sl_a.auto_stats
	var bp_a: TNBSim = auto_sim.call(1, 7, "BOXERPUNCHER", true); run_ticks(bp_a, 3600); var bp_st: Dictionary = bp_a.auto_stats
	var sw_hu: float = share.call(sw_st, ["L_HOOK", "R_HOOK", "R_UPPERCUT"]); var ob_str: float = share.call(ob_st, ["L_STRAIGHT", "R_STRAIGHT"]); var sl_hay: float = share.call(sl_st, ["R_HOOKERCUT"])
	var bp_max := 0.0
	for fam_rows in [["L_STRAIGHT", "R_STRAIGHT"], ["L_HOOK", "R_HOOK"], ["R_UPPERCUT"], ["R_HOOKERCUT"]]: bp_max = maxf(bp_max, share.call(bp_st, fam_rows))
	_sr("profile SWARMER: lives at %.2fm (the phone booth), %.0f%% hooks and uppercuts, %.0f%% to the body, %d punches, %d landed" % [mean_d.call(sw_st), sw_hu * 100.0, float(sw_st["body"]) / maxf(1.0, float(sw_st["punches"])) * 100.0, int(sw_st["punches"]), count_events(sw_a.events, "hit", {"on": "B"})],
		mean_d.call(sw_st) <= 1.35 and sw_hu >= 0.5 and float(sw_st["body"]) / maxf(1.0, float(sw_st["punches"])) >= 0.1 and int(sw_st["punches"]) >= 15 and count_events(sw_a.events, "hit", {"on": "B"}) >= 5)
	_sr("profile OUT-BOXER: holds %.2fm (jab range), %.0f%% straights, %d feints, %d punches, %d landed" % [mean_d.call(ob_st), ob_str * 100.0, int(ob_st["feints"]), int(ob_st["punches"]), count_events(ob_a.events, "hit", {"on": "B"})],
		mean_d.call(ob_st) >= 1.75 and ob_str >= 0.6 and int(ob_st["feints"]) >= 2 and int(ob_st["punches"]) >= 15 and count_events(ob_a.events, "hit", {"on": "B"}) >= 5)
	_sr("profile SLUGGER: %.2fm, %.0f%% power punches, %.0f%% haymakers, %d punches, %d landed" % [mean_d.call(sl_st), float(sl_st["power"]) / maxf(1.0, float(sl_st["punches"])) * 100.0, sl_hay * 100.0, int(sl_st["punches"]), count_events(sl_a.events, "hit", {"on": "B"})],
		mean_d.call(sl_st) >= 1.4 and mean_d.call(sl_st) <= 1.8 and float(sl_st["power"]) / maxf(1.0, float(sl_st["punches"])) >= 0.25 and sl_hay >= 0.15 and int(sl_st["punches"]) >= 15 and count_events(sl_a.events, "hit", {"on": "B"}) >= 5)
	_sr("profile BOXER-PUNCHER: %.2fm, no family over %.0f%%, %d punches, %d landed" % [mean_d.call(bp_st), bp_max * 100.0, int(bp_st["punches"]), count_events(bp_a.events, "hit", {"on": "B"})],
		mean_d.call(bp_st) >= 1.45 and mean_d.call(bp_st) <= 1.95 and bp_max <= 0.6 and int(bp_st["punches"]) >= 15 and count_events(bp_a.events, "hit", {"on": "B"}) >= 5)
	# against the live boss: it reads tells (jabs them, slips them, blocks them), lands, and its spacing keeps the archetypes' order
	# (since PAC-071 Yuri fights his own neutral game - the slow circle, the taunt every 8s - so two 30s fights per archetype, seeds 7 and 8:
	#  reads, hits and the spacing order in each fight; a jab landed in a tell counted across the two)
	var live: Dictionary = {}; var live_ok := true; var live_order := true; var live_intr: Array = []
	for lsd in [7, 8]:
		live = {}
		for sty in ["SWARMER", "OUTBOXER", "SLUGGER", "BOXERPUNCHER"]:
			var lv: TNBSim = auto_sim.call(1, lsd, sty, false); run_ticks(lv, 3600)
			live[sty] = {"d": mean_d.call(lv.auto_stats), "reads": int(lv.auto_stats["tell_jabs"]) + int(lv.auto_stats["dodges"]) + int(lv.auto_stats["blocks"]), "hits": count_events(lv.events, "hit", {"on": "B"}), "interrupts": count_events(lv.events, "interrupt") + count_events(lv.events, "unbroken", {"why": "not_breakable"})}
		for sty in live:
			if int(live[sty]["reads"]) < 5 or int(live[sty]["hits"]) < 5: live_ok = false
		if not (float(live["SWARMER"]["d"]) < float(live["SLUGGER"]["d"]) and float(live["SLUGGER"]["d"]) < float(live["OUTBOXER"]["d"])): live_order = false
		live_intr.append([int(live["SWARMER"]["interrupts"]), int(live["OUTBOXER"]["interrupts"]), int(live["SLUGGER"]["interrupts"]), int(live["BOXERPUNCHER"]["interrupts"])])
	for li in 4:
		if int(live_intr[0][li]) + int(live_intr[1][li]) < 1: live_ok = false
	_sr("profile vs a live Yuri on his neutral game, two 30s fights each: every archetype reads his tells and lands in both, and lands a jab in a tell (per fight %s); spacing swarmer %.2f < slugger %.2f < out-boxer %.2f (seed 8) and the same order at seed 7" % [JSON.stringify(live_intr), float(live["SWARMER"]["d"]), float(live["SLUGGER"]["d"]), float(live["OUTBOXER"]["d"])],
		live_ok and live_order)
	# the count and the scramble: it rises on the beat (HRT 99) and taps the cue (RFX 99)
	var ri: TNBSim = auto_sim.call(1, 7, "BOXERPUNCHER", true); clear_defense(ri.P); ri.P["comp"] = 0.5; boss_lands(ri, "R_HOOKERCUT")
	var ri_down: bool = ri.mode == "EIGHT"
	run_ticks(ri, TNBSim.ms(6000))
	var lu_rfx: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu_rfx[0]["stats"]["RFX"] = 99
	var cl := make_sim(1, 7, lu_rfx); cl.delegate_all = true; cl.new_dual(); quiet(cl); place(cl, 0.5); cl.events.clear()
	cl._start_clinch("B", 0.5, 2); run_ticks(cl, cl.clinch_t + 3)
	_sr("profile on the count: RORY (HRT 99) rises on every beat; in the scramble an RFX 99 card taps all four cues and wins the position (beats %d)" % count_events(cl.events, "clinch_beat"),
		ri_down and ri.mode == "FIGHT" and count_events(ri.events, "eight_beat") == 3 and count_events(cl.events, "clinch_beat") == 4 and cl.clinch.is_empty())

	# ================= PAC-063: scraps and spars (NP_02 z2) ==========
	var scrap := func(oid: String, boss_i: int = 1, param_s: String = "") -> TNBSim:
		var sc := make_sim(boss_i, 7); sc.start_scrap(oid, boss_i, param_s); quiet(sc); place(sc, 1.4); sc.P["comp"] = sc.P["comp_max"]; sc.bsurvival_used = true
		return sc
	var met := func(sim: TNBSim) -> bool: return sim.obj.size() > 0 and bool(sim.obj["met"])
	var failed := func(sim: TNBSim) -> bool: return sim.obj.size() > 0 and bool(sim.obj["failed"])
	var jab := func(sim: TNBSim, zrow: String = "L_STRAIGHT", extra: Dictionary = {}) -> void: thaw(sim); place(sim, 1.4); throw_clean(sim, zrow, extra); sim.step({})
	# the data and the rules of the size
	var forms: Dictionary = content["bouts"]["objective_forms"]
	var data_ok := true
	for o in content["scraps"]["objectives"]:
		if not forms.has(str(o["id"])) or not (str(forms[str(o["id"])].get("kind", "")) in ["count", "survive", "finisher", "constraint", "state", "first_blood", "ladder", "streak"]): data_ok = false
	var sr: TNBSim = scrap.call("SCR-01"); sr.tension = 0.0; sr._earn_tension(10.0)
	var s24_yuri := make_sim(1, 7); var s24_vane := make_sim(0, 7)
	var avail_ok: bool = s24_yuri.objective_available("SCR-24", 1) and not s24_vane.objective_available("SCR-24", 0) and not s24_vane.start_scrap("SCR-24", 0) and count_events(s24_vane.events, "bout_refused") == 1 and s24_vane.bout.is_empty()
	_sr("scrap rules: 24 objectives with a known form each; a 30s cap, no Tension (10 earned -> 0), no corner; SCR-24 needs a coached NPC - offered on Yuri, refused on Vane",
		data_ok and content["scraps"]["objectives"].size() == 24 and sr.bout["kind"] == "scrap" and sr.clock_t == TNBSim.ms(30000) and sr.tension == 0.0 and sr.coach.is_empty() and sr.mode == "FIGHT" and avail_ok)
	# the cap: judged on EP
	var cap_w: TNBSim = scrap.call("SCR-05"); cap_w.ep_p = 6; run_ticks(cap_w, TNBSim.ms(30000) + 1)
	var cap_l: TNBSim = scrap.call("SCR-05"); cap_l.ep_b = 6; run_ticks(cap_l, TNBSim.ms(30000) + 1)
	_sr("the cap: 30s without the objective is judged on EP - %s / %s" % [str(cap_w.feed), str(cap_l.feed)],
		cap_w.mode == "OVER" and count_events(cap_w.events, "bout_end", {"rung": "ep"}) == 1 and "SCRAP WON on EP" in str(cap_w.feed) and cap_l.mode == "OVER" and "SCRAP LOST on EP" in str(cap_l.feed))
	# count forms fire at their count, never early
	var z1: TNBSim = scrap.call("SCR-01"); jab.call(z1, "R_HOOK", {"body": true}); jab.call(z1, "R_HOOK", {"body": true}); var s1_early: bool = not met.call(z1) and int(z1.obj["count"]) == 2 and z1.mode == "FIGHT"
	jab.call(z1, "L_HOOK", {"body": true})
	var z4: TNBSim = scrap.call("SCR-04"); jab.call(z4); var s4_early: bool = not met.call(z4)
	thaw(z4); place(z4, 1.4); z4.P["busy_t"] = 0; z4.P["cmd"] = {}; z4.P["counter_t"] = 60; z4.step({"punch": "R_STRAIGHT"}); clear_defense(z4.B); land(z4); z4.step({})
	var s21: TNBSim = scrap.call("SCR-21")
	for zi in 3:
		thaw(s21); place(s21, 1.4); s21.P["busy_t"] = 0; s21.P["cmd"] = {}; s21.P["counter_t"] = 60; s21.step({"punch": "R_STRAIGHT"}); clear_defense(s21.B); land(s21); s21.step({})
	var z3: TNBSim = scrap.call("SCR-03"); thaw(z3); z3.P["pos"] = Vector2(0.0, 2.6); z3.B["pos"] = Vector2(0.0, 1.2); throw_clean(z3, "L_STRAIGHT"); z3.step({}); var s3_off: bool = not met.call(z3)
	jab.call(z3)
	_sr("count forms: SCR-01 three body shots (2 not enough, the third ends it WON), SCR-04 a counter (a plain hit is not), SCR-21 three counters, SCR-03 one CENTER exchange (an off-center hit is not)",
		s1_early and met.call(z1) and z1.mode == "OVER" and count_events(z1.events, "bout_end", {"rung": "objective"}) == 1 and s4_early and met.call(z4) and met.call(s21) and s3_off and met.call(z3))
	var s5: TNBSim = scrap.call("SCR-05"); var s5_n := 0
	while not met.call(s5) and s5_n < 40:
		thaw(s5); place(s5, 1.4); s5.B["blocking"] = true; s5.B["guard_t"] = 999; s5.P["busy_t"] = 0; s5.P["cmd"] = {}
		s5.step({"punch": "R_HOOKERCUT", "power": true}); s5.B["dodge"] = ""; s5.B["dodge_plan"] = []; s5.B["dodge_at"] = 0; s5.B["blocking"] = true; land(s5); s5.step({}); s5_n += 1
	var s13: TNBSim = scrap.call("SCR-13")
	for zi in 2:
		thaw(s13); place(s13, 1.4); s13.P["blocking"] = true; s13.P["block_t"] = 1; boss_lands(s13, "R_STRAIGHT"); s13.step({})
	var s13_first: bool = met.call(s13)
	var s14: TNBSim = scrap.call("SCR-14"); thaw(s14); place(s14, 0.5); s14._start_clinch("B", 0.5, 2); play_clinch(s14, "sides"); s14.step({})
	var s15: TNBSim = scrap.call("SCR-15"); jab.call(s15); var s15_near: bool = not met.call(s15)
	thaw(s15); place(s15, 2.15); throw_clean(s15, "R_STRAIGHT"); s15.step({})
	_sr("count forms: SCR-05 a guard break (%d power haymakers into his guard), SCR-13 two perfect blocks in a row, SCR-14 the scramble won, SCR-15 a stepping punch (from 2.15m the lunge makes the reach; from 1.4m it is not one)" % s5_n,
		met.call(s5) and s13_first and count_events(s13.events, "sensor", {"name": "player_perfect_block_streak2"}) == 1 and met.call(s14) and s15_near and met.call(s15))
	var z2: TNBSim = scrap.call("SCR-02")
	for zi in 2:
		thaw(z2); place(z2, 1.4); z2.P["dodge"] = "SLIP"; z2.P["dodge_t"] = 999; z2.P["dodge_dir"] = 1; boss_lands(z2, "R_STRAIGHT"); z2.step({})
		if zi == 0: clear_defense(z2.P)
	var s2_one: bool = int(z2.obj["count"]) == 2 or met.call(z2)
	var s2b: TNBSim = scrap.call("SCR-02"); thaw(s2b); place(s2b, 2.6); clear_defense(s2b.P); boss_lands(s2b, "R_STRAIGHT"); s2b.step({})   # a whiff from range is not a slip
	var s9: TNBSim = scrap.call("SCR-09"); var s17: TNBSim = scrap.call("SCR-17")
	var force_tell := func(sim: TNBSim, loud: bool) -> void:
		var sname := ""
		for zk in sim.pattern["strings"]:
			if (str(sim.pattern["strings"][zk].get("class", "normal")) != "normal") == loud and sim._interruptible(str(zk)) and sname == "": sname = str(zk)   # a string the block tags (NP_04 s4)
		thaw(sim); place(sim, 1.4); sim.bstate = "TELL"; sim.bstring = sname; sim.btimer = 1 << 30; sim.P["busy_t"] = 0; sim.P["cmd"] = {}
		sim.step({"punch": "L_STRAIGHT"}); clear_defense(sim.B); land(sim); sim.step({})
	var s9b: TNBSim = scrap.call("SCR-09", 23)                                       # Baro: the one roster SPECIAL tagged INTERRUPT (S3), and breakable normals
	force_tell.call(s9b, false); var s9_normal: bool = not met.call(s9b)
	force_tell.call(s9b, true)
	var s9_avail: bool = s9b.objective_available("SCR-09", 1) and s9b.objective_available("SCR-17", 23) and not s9b.objective_available("SCR-09", 18)   # Yuri's Elevator breaks in its window; Marta's Neige walls and her SPECIAL... she has none
	var s17b: TNBSim = scrap.call("SCR-17", 23)
	force_tell.call(s17b, false); var s17_wrong_order: bool = int(s17b.obj["ladder_i"]) == 0
	force_tell.call(s17b, true); var s17_half: bool = int(s17b.obj["ladder_i"]) == 1 and not met.call(s17b)
	force_tell.call(s17b, false)
	_sr("count forms: SCR-02 two misses drawn by slips (a whiff from range is not one), SCR-09 his special - Baro's S3 broken (a normal tell's is not; offered vs Yuri whose Elevator breaks in its window, refused vs Marta), SCR-17 the ladder Loud then Standard (Standard first does not count)",
		met.call(z2) and not met.call(s2b) and int(s2b.obj["count"]) == 0 and s9_normal and met.call(s9b) and s9_avail and s17_wrong_order and s17_half and met.call(s17b))
	# survive, state, first blood, streak, the corner escape, the House read, the coach shout
	var s6: TNBSim = scrap.call("SCR-06"); run_ticks(s6, TNBSim.ms(20000) - 1); var s6_early: bool = not met.call(s6) and s6.mode == "FIGHT"; s6.step({})
	var s6b: TNBSim = scrap.call("SCR-06"); clear_defense(s6b.P); s6b.P["comp"] = 0.5; boss_lands(s6b, "R_HOOKERCUT"); s6b.step({})
	var s10: TNBSim = scrap.call("SCR-10"); thaw(s10); s10.B["pos"] = Vector2(3.2, 3.2); s10.P["pos"] = Vector2(2.1, 2.1); run_ticks(s10, TNBSim.ms(3000) - 1); var s10_early: bool = not met.call(s10); s10.step({})
	var s12: TNBSim = scrap.call("SCR-12"); jab.call(s12)
	var s12b: TNBSim = scrap.call("SCR-12"); clear_defense(s12b.P); boss_lands(s12b, "R_STRAIGHT"); s12b.step({})
	var s18: TNBSim = scrap.call("SCR-18")
	for zi in 3: jab.call(s18)
	s18._ev("flag", {"gram": "test"}); s18.step({}); var s18_reset: bool = int(s18.obj["count"]) == 0
	for zrow in ["L_STRAIGHT", "R_HOOK", "R_UPPERCUT", "L_HOOK", "R_STRAIGHT"]: jab.call(s18, zrow)      # varied: three jabs in a row is a real flag
	var s16: TNBSim = scrap.call("SCR-16"); thaw(s16); s16.P["pos"] = Vector2(3.2, 3.2); s16.B["pos"] = Vector2(2.0, 2.0); s16.step({}); s16.step({"block": true}); s16.step({})
	s16.P["pos"] = Vector2(0.5, 0.5); s16.step({}); var s16_blocked: bool = not met.call(s16)
	s16.P["pos"] = Vector2(3.2, 3.2); s16.step({}); s16.step({}); s16.P["pos"] = Vector2(0.5, 0.5); s16.step({})
	var s20: TNBSim = scrap.call("SCR-20"); boss_desperation(s20); s20.P["busy_t"] = 0; s20.P["cmd"] = {}; s20.step({"punch": "L_STRAIGHT"}); clear_defense(s20.B); land(s20); s20.step({})
	var s20b: TNBSim = scrap.call("SCR-20", 1, "tremblay"); boss_desperation(s20b); s20b.P["busy_t"] = 0; s20b.P["cmd"] = {}; s20b.step({"punch": "L_STRAIGHT"}); clear_defense(s20b.B); land(s20b); s20b.step({})
	var s24 := make_sim(1, 7); s24.start_scrap("SCR-24", 1); s24.hooks_enabled = false; s24.coach_on = false; place(s24, 1.6); s24.bstate = "IDLE"; s24.btimer = 1
	var n24 := 0
	while int(s24.obj["count"]) < 1 and n24 < 3600 and s24.mode == "FIGHT": s24.step({}); n24 += 1
	var s24_seen: int = s24.obj["count"]
	if s24.mode == "FIGHT": s24._ev("tell", {"ticks": 60, "loud": false, "string": "S1", "shout": true}); s24.step({})
	_sr("SCR-06 survive 20s (met on the tick, not before; a DROP fails it), SCR-10 corner him 3s (not at 2.99), SCR-12 first blood both ways, SCR-18 five hits reset by a flag, SCR-16 the corner left unblocked (not after a block), SCR-20 the House read (Grain Elevator is Kowalchuk's: met for kowalchuk, not for tremblay), SCR-24 his coach shouts (%d heard live)" % s24_seen,
		s6_early and met.call(s6) and failed.call(s6b) and s10_early and met.call(s10) and met.call(s12) and failed.call(s12b) and s18_reset and met.call(s18) and s16_blocked and met.call(s16)
		and s20.obj["param"] == "kowalchuk" and met.call(s20) and not met.call(s20b) and s24_seen >= 1 and (met.call(s24) or s24.mode == "OVER"))
	# finishers and constraints
	var s7: TNBSim = scrap.call("SCR-07"); s7.B["comp"] = 0.5; jab.call(s7, "R_UPPERCUT")
	var s7b: TNBSim = scrap.call("SCR-07"); s7b.B["comp"] = 0.5; jab.call(s7b, "R_HOOK")
	var s22: TNBSim = scrap.call("SCR-22"); s22.B["comp"] = 0.5; jab.call(s22, "R_HOOK", {"body": true})
	var s22b: TNBSim = scrap.call("SCR-22"); s22b.B["comp"] = 0.5; jab.call(s22b, "R_HOOK")
	var s8: TNBSim = scrap.call("SCR-08")
	for zrw in ["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_HOOK", "R_UPPERCUT"]: jab.call(s8, zrw)
	var s8_five: bool = int(s8.obj["count"]) == 5 and not met.call(s8)
	jab.call(s8, "R_HOOKERCUT")
	var s8b: TNBSim = scrap.call("SCR-08"); jab.call(s8b, "L_STRAIGHT"); jab.call(s8b, "L_STRAIGHT")
	var s11: TNBSim = scrap.call("SCR-11"); s11.step({"block": true}); s11.step({})
	var s11b: TNBSim = scrap.call("SCR-11"); s11b.ep_p = 4; run_ticks(s11b, TNBSim.ms(30000) + 1)
	var s19: TNBSim = scrap.call("SCR-19"); jab.call(s19, "L_HOOK"); var s19_left: bool = not failed.call(s19); jab.call(s19, "R_STRAIGHT")
	var s23: TNBSim = scrap.call("SCR-23"); thaw(s23); s23.step({"move": Vector2(0, 1)}); s23.step({})
	var s23b: TNBSim = scrap.call("SCR-23"); thaw(s23b); s23b.step({"move": Vector2(0, -1)}); s23b.step({"move": Vector2(1, 0)}); s23b.step({})
	_sr("finishers: SCR-07 the drop off an uppercut (a hook fails it), SCR-22 off a body shot (a head shot fails it); constraints: SCR-08 six different punches (a repeat fails), SCR-11 a block press fails and the cap wins on EP, SCR-19 a right hand fails (left hands hold), SCR-23 a step back fails (forward and lateral hold)",
		met.call(s7) and failed.call(s7b) and met.call(s22) and failed.call(s22b) and s8_five and met.call(s8) and failed.call(s8b) and failed.call(s11) and s11.mode == "OVER" and s11b.mode == "OVER" and "SCRAP WON on EP" in str(s11b.feed) and s19_left and failed.call(s19) and failed.call(s23) and not failed.call(s23b))
	# the spar: one 90s segment, the personal meter at 50, transforms locked, lab flags, no corner
	var sp := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities({}, "ring:1", content["facilities"])); sp.start_spar(1, ["tell_highlight", "infinite_stamina"]); quiet(sp); place(sp, 1.4)   # since PAC-089 the lab flags are The Ring's T1
	sp._earn_tension(60.0); var sp_cap: float = sp.tension
	var t4_locked: bool = not sp.castable({"tier": "T4", "effect": [], "name": "x"}) and sp.castable({"tier": "T1", "effect": [], "name": "y"})
	sp.P["busy_t"] = 0; sp.P["cmd"] = {}; sp.step({"punch": "R_HOOKERCUT", "power": true}); clear_defense(sp.B); land(sp); sp.step({})
	var sp_stam: float = sp.P["stamina"]
	sp.bstate = "IDLE"; sp.btimer = 1; sp.events.clear(); run_ticks(sp, 600); var sp_hl: bool = count_events(sp.events, "tell", {"highlight": true}) >= 1 and count_events(sp.events, "tell", {"highlight": false}) == 0
	freeze_boss(sp); sp.ep_p = sp.ep_b + 3; run_ticks(sp, TNBSim.ms(90000) + 2)
	_sr("spar: the meter caps at 50 (60 earned -> %.0f), T4 is locked and T1 is not, infinite stamina holds 100 through a power haymaker (%.0f), tell-highlight outlines every tell, no corner, the 90s end is judged on drops then EP - %s" % [sp_cap, sp_stam, str(sp.feed)],
		sp.bout["kind"] == "spar" and sp.clock_t <= 0 and absf(sp_cap - 50.0) < 0.01 and t4_locked and absf(sp_stam - 100.0) < 0.01 and sp_hl and sp.coach.is_empty() and sp.mode == "OVER" and "SPAR: MILLBROOK WINS on EP" in str(sp.feed))
	# Ep1 by name, and the way back to the dual
	var e2 := make_sim(0, 7); var e2_ok := e2.start_ep1("scrap_2")
	var e2_card: bool = e2_ok and e2.boss_label == "MARCUS" and e2.boss_name == "yuri_kowalchuk" and e2.B["style"] == "SLUGGER" and absf(e2.B["comp_max"] - 65.0 * 2.0 * 1.15) < 0.01 and e2.obj["id"] == "SCR-06" and "MARCUS" in str(e2.bout["label"])
	var e1 := make_sim(0, 7); e1.start_ep1("scrap_1"); var e1_card: bool = e1.boss_label == "CHALLENGER" and e1.obj["id"] == "SCR-01" and e1.boss_name == "carter_okafor"
	var e3 := make_sim(0, 7); e3.start_ep1("scrap_3"); var e3_card: bool = e3.boss_label == "JUNE" and e3.B["style"] == "SWARMER" and e3.obj["id"] == "SCR-03"
	var pt := make_sim(0, 7); pt.start_ep1("priya_trial"); quiet(pt); place(pt, 1.4)
	var pt_card: bool = pt.bout["kind"] == "spar" and pt.boss_label == "PRIYA" and pt.B["style"] == "OUTBOXER" and int(pt.B["stats"]["RFX"]) == 70 and "tell_highlight" in pt.lab and pt.obj["kind"] == "segment_end"
	run_ticks(pt, TNBSim.ms(90000) + 2)
	var pt_end: bool = pt.mode == "OVER" and bool(pt.obj["met"]) and count_events(pt.events, "bout_end", {"met": true}) == 1
	pt.end_bout()
	_sr("Ep1 by name: SCRAP 1 vs the bike-rack CHALLENGER (SCR-01), SCRAP 2 vs MARCUS on a Slugger's strings (SCR-06, his chin from his card), SCRAP 3 vs JUNE (SCR-03), the PRIYA TRIAL as a tell-highlight spar met by going the distance; end_bout returns to the mini-dual",
		e1_card and e2_card and e3_card and pt_card and pt_end and pt.bout.is_empty() and pt.fmt.get("id", "") == "mini" and pt.mode == "FIGHT" and pt.segments() == 3 and pt.boss_name == "cassidy_vane")

	# ================= PAC-064: Pattern Intel (NP_02 z3) =============
	var pid: Dictionary = content["pattern_intel"]
	var pi_ledger := func(arg: String) -> Dictionary: return TNBSim.parse_pi_arg(arg, pid)
	var pi_win_scrap := func(sim: TNBSim, oid: String, bi: int) -> void: sim.start_scrap(oid, bi); sim.obj["met"] = true; sim.obj["why"] = "objective"; sim._end_bout()
	# the data, the dialect keys, the seed parser
	var pia := make_sim(1, 7)
	var pi_rungs_ok: bool = int(pid["rungs"]["scraps"]["1"]) == 3 and int(pid["rungs"]["scraps"]["2"]) == 6 and int(pid["rungs"]["spars"]["1"]) == 1 and int(pid["rungs"]["spars"]["2"]) == 3 and int(pid["rungs"]["segments"]["2"]) == 1
	var pi_habits_ok := true
	for pi_bn in TNBSim.BOSSES:
		if not pid["habits"].has(pia.dialect_of(str(pi_bn))): pi_habits_ok = false
	var pi_keys_ok: bool = pia.dialect_of("yuri_kowalchuk") == "kowalchuk" and pia.dialect_of("ada_okafor") == "okafor" and pia.dialect_of("cassidy_vane") == "cassidy_vane" and pia.dialect_of("hc7_echo") == "iron" \
		and pia.dialect_of("carter_okafor", content["bouts"]["ep1"]["scrap_1"]["card"]) == "school"
	var pi_seed: Dictionary = pi_ledger.call("kowalchuk:2,yuri_kowalchuk:3,okafor:1")
	var pi_seed_ok: bool = int(pi_seed["dialects"]["kowalchuk"]["scraps"]) == 6 and int(pi_seed["bosses"]["yuri_kowalchuk"]["beaten"]) == 1 and int(pi_seed["dialects"]["okafor"]["scraps"]) == 3
	_sr("PI data: the rungs as NP_02 s3's table (3 scraps or 1 spar -> 1; 6 / 3 / a dual segment -> 2), every dialect of the 24 with an authored habit; the dialect key is his House, his own id without one (Vane), the card's when it names one (the school); a fresh ledger is PI 0 vs %s; `-- pi=` seeds a ledger" % pia.bdialect,
		pi_rungs_ok and pi_habits_ok and pi_keys_ok and pia.pi_vs() == 0 and pia.pi.get("dialects", {}).is_empty() and pi_seed_ok)
	# the scrap track: won scraps at the count and not one short; a lost scrap pays nothing
	var pib := make_sim(1, 7)
	for pi_i in 2: pi_win_scrap.call(pib, "SCR-01", 1)
	var pi_two: bool = pib.pi_level("kowalchuk") == 0 and count_events(pib.events, "pi") == 0 and int(pib.pi["dialects"]["kowalchuk"]["scraps"]) == 2
	pi_win_scrap.call(pib, "SCR-01", 1)
	var pi_three: bool = pib.pi_level("kowalchuk") == 1 and count_events(pib.events, "pi", {"level": 1, "source": "scraps"}) == 1
	for pi_i in 2: pi_win_scrap.call(pib, "SCR-01", 1)
	var pi_five: bool = pib.pi_level("kowalchuk") == 1
	pi_win_scrap.call(pib, "SCR-01", 1)
	var pi_six: bool = pib.pi_level("kowalchuk") == 2 and count_events(pib.events, "pi", {"level": 2}) == 1
	pi_win_scrap.call(pib, "SCR-01", 1)
	var pi_seven: bool = pib.pi_level("kowalchuk") == 2 and count_events(pib.events, "pi") == 2
	var pic := make_sim(1, 7); pic.start_scrap("SCR-11", 1); pic.obj["failed"] = true; pic.obj["why"] = "you blocked"; pic._end_bout()
	var pi_lost: bool = pic.pi.get("dialects", {}).get("kowalchuk", {}).get("scraps", 0) == 0
	pic.start_scrap("SCR-05", 1); quiet(pic); place(pic, 1.4); pic.ep_b = 4; run_ticks(pic, TNBSim.ms(30000) + 1)
	var pi_cap_lost: bool = pic.mode == "OVER" and pic.pi.get("dialects", {}).get("kowalchuk", {}).get("scraps", 0) == 0
	pic.start_scrap("SCR-05", 1); quiet(pic); place(pic, 1.4); pic.ep_p = 4; run_ticks(pic, TNBSim.ms(30000) + 1)
	var pi_cap_won: bool = pic.mode == "OVER" and int(pic.pi.get("dialects", {}).get("kowalchuk", {}).get("scraps", 0)) == 1
	var pie: TNBSim = scrap.call("SCR-01")                                                # the real path: three body shots, the verdict, the count
	for pi_i in 3: jab.call(pie, "R_HOOK", {"body": true})
	var pi_real: bool = pie.mode == "OVER" and count_events(pie.events, "pi_count", {"dialect": "kowalchuk", "source": "scraps", "count": 1}) == 1
	_sr("the scrap track: two won scraps vs Kowalchuk leave PI 0, the third is PI 1, the sixth PI 2 (not the fifth), a seventh crosses nothing; a scrap lost on a constraint or at the cap pays nothing, one won at the cap on EP pays one; the real path (three body shots) counts one",
		pi_two and pi_three and pi_five and pi_six and pi_seven and pi_lost and pi_cap_lost and pi_cap_won and pi_real)
	# the spar track and the dual segment
	var pif := make_sim(1, 7)
	pif.start_spar(1); pif._end_bout()
	var pi_spar1: bool = pif.pi_level("kowalchuk") == 1 and count_events(pif.events, "pi", {"level": 1, "source": "spars"}) == 1
	pif.start_spar(1); pif._end_bout()
	var pi_spar2: bool = pif.pi_level("kowalchuk") == 1
	pif.start_spar(1); pif.P["drops"] = 3; pif._end_bout()                                 # counted out in the lab: the lesson still counts
	var pi_spar3: bool = pif.pi_level("kowalchuk") == 2 and count_events(pif.events, "pi", {"level": 2, "source": "spars"}) == 1
	var pig := make_sim(1, 7); quiet(pig); pig.ep_b = 6; pig._end_segment("clock")
	var pi_seg: bool = pig.pi_level("kowalchuk") == 2 and count_events(pig.events, "pi", {"level": 2, "was": 0, "source": "segments"}) == 1 and pig.pi.get("bosses", {}).get("yuri_kowalchuk", {}).get("beaten", 0) == 0
	_sr("the spar track: one spar to its end vs Kowalchuk is PI 1, the third PI 2 (a count-out still counts - the lab is the lesson); one dual segment fought and lost is PI 2 at once and marks nobody beaten",
		pi_spar1 and pi_spar2 and pi_spar3 and pi_seg)
	# the boss track: beaten once, his page
	var pih := make_sim(1, 7); quiet(pih); pih.ep_p = 6; pih._end_segment("clock")
	var pi_page: Dictionary = pih.scout_page("yuri_kowalchuk")
	var pi_beat: bool = int(pih.pi["bosses"]["yuri_kowalchuk"]["beaten"]) == 1 and pih.pi_boss("yuri_kowalchuk") == 3 and count_events(pih.events, "scout_book", {"boss": "yuri_kowalchuk"}) == 1 \
		and pi_page["tells"].size() == pih.patterns["yuri_kowalchuk"]["strings"].size() and "S1" in pi_page["strings"] and pi_page["phases"].size() >= 1 and pi_page["corner_tell"] != "" and pi_page["desperation"] != "" and pih.scout_page("moira_macisaac").is_empty()
	var pii := make_sim(1, 7); quiet(pii); pii.B["drops"] = 3; pii.ep_b = 6; pii._end_segment("SEGMENT KO")
	var pi_ko: bool = int(pii.pi["bosses"]["yuri_kowalchuk"]["beaten"]) == 1
	var pij := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("yuri_kowalchuk:3"))
	var pik := make_sim(19, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("yuri_kowalchuk:3"))
	_sr("the boss track: a segment won vs Yuri on EP marks him beaten - PI 3, his Scout Book page (his %d tells, strings, phase notes, the desperation, his corner's tell); his KO marks it too; Moira has no page and a ledger with Yuri beaten is PI 3 vs Yuri and PI 0 vs Moira" % pi_page.get("tells", []).size(),
		pi_beat and pi_ko and pij.pi_vs() == 3 and pik.pi_vs() == 0)
	# the effects: +10% on the tell against that dialect only, the cue, no wider at PI 3, no other window touched
	var pil := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:2")); quiet(pil); thaw(pil); pil.events.clear()
	var pil0 := make_sim(1, 7); quiet(pil0); thaw(pil0); pil0.events.clear()
	var pil1 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:1")); quiet(pil1); thaw(pil1); pil1.events.clear()
	var pil3 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("yuri_kowalchuk:3")); quiet(pil3); thaw(pil3); pil3.events.clear()
	var pim := make_sim(4, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:2")); quiet(pim); thaw(pim); pim.events.clear()   # Ada: an Okafor
	pil._force_string("S1", 1.0, false); pil0._force_string("S1", 1.0, false); pil1._force_string("S1", 1.0, false); pil3._force_string("S1", 1.0, false); pim._force_string("S1", 1.0, false)
	var pi_s1: int = TNBSim.ms(float(pil.pattern["strings"]["S1"]["tell"]["ms"]))
	var pi_a1: int = TNBSim.ms(float(pim.pattern["strings"]["S1"]["tell"]["ms"]))
	var pi_wider: bool = pil.btimer == int(pi_s1 * 1.1) and pil0.btimer == pi_s1 and pil1.btimer == pi_s1 and pil3.btimer == int(pi_s1 * 1.1) and pim.btimer == pi_a1
	var pi_cue: bool = count_events(pil.events, "tell", {"cue": true}) == 1 and count_events(pil0.events, "tell", {"cue": false}) == 1 and count_events(pil1.events, "tell", {"cue": false}) == 1 and count_events(pim.events, "tell", {"cue": false}) == 1
	var pi_windows: bool = pil3._window("slip") == pil0._window("slip") and pil3._window("flash") == pil0._window("flash") and pil3._window("perfect_block") == pil0._window("perfect_block") and pil3._window("duck") == pil0._window("duck") and absf(pil3._tell_mult() - 1.1) < 0.001
	var pin := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:2")); pin.hooks_enabled = false; pin.coach_on = false; place(pin, 1.6); pin.bstate = "IDLE"; pin.btimer = 1; pin.events.clear()
	var pi_nat := 0
	while count_events(pin.events, "tell") == 0 and pi_nat < 1200: pin.step({}); pi_nat += 1
	var pi_natural_ok := false
	for pi_e in pin.events:
		if pi_e["kind"] == "tell" and not pi_e.get("fake", false):
			pi_natural_ok = int(pi_e["ticks"]) == int(TNBSim.ms(float(pin.pattern["strings"][str(pi_e["string"])]["tell"]["ms"])) * 1.1) and bool(pi_e["cue"]); break
	_sr("PI 2 vs Kowalchuk: Yuri's S1 tell %d -> %d ticks (+10%%), his tell event carries the cue; PI 0 and PI 1 leave it at %d with no cue; Ada's (an Okafor) stays %d on the same ledger; PI 3 is no wider than PI 2; his own selected tell comes at +10%% too; the slip / duck / perfect-block / flash windows are untouched at PI 3" % [pi_s1, int(pi_s1 * 1.1), pi_s1, pi_a1],
		pi_wider and pi_cue and pi_windows and pi_natural_ok)
	# the commentary at PI 1, silent at PI 0; the emphasized line at PI 2; the fallback habit
	var pio1 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:1"))
	var pio0 := make_sim(1, 7)
	var pio2 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:2"))
	var pi_comm: bool = count_events(pio1.events, "commentary", {"dialect": "kowalchuk", "level": 1, "cue": false}) == 1 and count_events(pio0.events, "commentary") == 0 and count_events(pio2.events, "commentary", {"level": 2, "cue": true}) == 1
	var pi_text_ok := false
	for pi_e in pio1.events:
		if pi_e["kind"] == "commentary": pi_text_ok = str(pi_e["text"]) == str(pid["habits"]["kowalchuk"])
	var pi_fallback: String = pio0.pi_habit("nobody")
	_sr("the commentator calls the Kowalchuk habit before the segment at PI 1 (the authored line), says nothing at PI 0, and at PI 2 the line carries the cue; a dialect with no authored line falls back to his most-weighted tell's motif (%s)" % pi_fallback,
		pi_comm and pi_text_ok and pi_fallback.begins_with("Watch the") and "Nobody" in pi_fallback)
	# the profile reads more of a dialect it knows
	var pi_reads := func(ledger: Dictionary) -> int:
		var pi_ps := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", ledger); quiet(pi_ps); pi_ps.delegated = true; pi_ps.auto = TNBProfile.fresh_memory(); place(pi_ps, 1.6)
		var n := 0
		for pi_k in 300:
			pi_ps.tick += 1; pi_ps.bstate = "TELL"; pi_ps.bstring = "S1"; pi_ps.btimer = 60; pi_ps.tell_start_tick = pi_ps.tick; pi_ps.auto["plan"] = ""
			TNBProfile.intent(pi_ps, {})
			if str(pi_ps.auto["plan"]) != "": n += 1
		return n
	var pi_r0: int = pi_reads.call({}); var pi_r3: int = pi_reads.call(pi_ledger.call("yuri_kowalchuk:3")); var pi_r2: int = pi_reads.call(pi_ledger.call("kowalchuk:2"))
	var pip := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("yuri_kowalchuk:3"))
	_sr("the profile reads more of a dialect it knows: of 300 tells RORY (RFX 50) reads %d at PI 0, %d at PI 2, %d at PI 3 (read bonus %.2f at 3, 0 at 0)" % [pi_r0, pi_r2, pi_r3, pip.pi_read_bonus()],
		pi_r2 - pi_r0 >= 12 and pi_r3 - pi_r0 >= 30 and absf(pip.pi_read_bonus() - float(pid["profile_read_bonus"]["3"])) < 0.001 and absf(pia.pi_read_bonus()) < 0.001)
	# the ledger rides with the sim: Ep1's scrap 1 pays the school dialect, end_bout / new_dual keep it, and it hashes
	var piq := make_sim(0, 7); piq.start_ep1("scrap_1")
	var pi_school: bool = piq.bdialect == "school"
	piq.obj["met"] = true; piq._end_bout(); piq.end_bout(); piq.new_dual()
	var pi_kept: bool = int(piq.pi["dialects"]["school"]["scraps"]) == 1 and piq.bout.is_empty()
	var pir_a := make_sim(1, 99, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:2")); var pir_b := make_sim(1, 99, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("kowalchuk:2")); var pir_c := make_sim(1, 99)
	_sr("the ledger rides with the sim: SCRAP 1 vs the bike-rack CHALLENGER pays the school dialect, end_bout and new_dual keep it, and two sims differ in hash by the ledger alone",
		pi_school and pi_kept and pir_a.hash_state() == pir_b.hash_state() and pir_a.hash_state() != pir_c.hash_state())

	# ================= PAC-065: the opponent's mind games (NP_04 z4, z6) ======
	var rxs := make_sim(1, 7)
	var rx_cov: Dictionary = rxs.interrupt_coverage(content["patterns"])
	var rx_all_break := true; var rx_armored_hold := true; var rx_holds := 0; var rx_armored := 0
	for rx_n in rx_cov:
		if rx_cov[rx_n]["breaks"].is_empty(): rx_all_break = false
		rx_holds += rx_cov[rx_n]["holds"].size()
		for rx_h in rx_cov[rx_n]["holds"]:
			if "[ARMORED]" in str(rx_h): rx_armored += 1
	for rx_n in content["patterns"]:
		for rx_k in content["patterns"][rx_n]["strings"]:
			if str(content["patterns"][rx_n]["strings"][rx_k].get("class", "")) == "ARMORED" and (str(rx_k) in rx_cov[rx_n]["breaks"]): rx_armored_hold = false
	var rx_yuri_ok: bool = rx_cov["yuri_kowalchuk"]["breaks"] == ["S1"] and rx_cov["hc7_echo"]["holds"] == ["S1 [ARMORED]"] and rx_cov["hc7_echo"]["breaks"] == ["S2", "S3"] and rx_cov["hc4_cartographer"]["holds"].is_empty()
	var rx_vey := make_sim(6, 7); var rx_ada := make_sim(4, 7)
	var rx_chi := make_sim(8, 7)
	var rx_blocks_ok: bool = int(rx_vey._interrupt_block("P1S1")["stagger_ms"]) == 700 and int(rxs._interrupt_block("S1")["stagger_ms"]) == 800 and bool(rxs._interrupt_block("S1")["tension_bonus"]) and absf(float(rx_ada._interrupt_block("S1")["desync_s"]) - 3.0) < 0.001 and absf(float(rx_chi._interrupt_block("S2")["desync_s"]) - 1.5) < 0.001 and rxs._interrupt_block("S2").is_empty()
	var rx_special_ok: bool = rxs.special_breakable("yuri_kowalchuk") and rxs.special_breakable("yordanis_baro") and not rxs.special_breakable("marta_okonkwo_tremblay")
	_sr("the INTERRUPT block as data across the 24: every pattern has a breakable string, %d strings hold (%d of them ARMORED, none of those breaks), Yuri breaks on S1 alone, Echo's ARMORED S1 holds while S2 / S3 break, the Cartographer breaks on all five; the block's response parsed (Vey stagger 700, Yuri 800 + tension_bonus, Ada desync 3s, Chiamaka 1.5s); 'his special' breakable for Yuri (the Elevator) and Baro (S3), not Marta" % [rx_holds, rx_armored],
		rx_all_break and rx_armored_hold and rx_armored == 8 and rx_yuri_ok and rx_blocks_ok and rx_special_ok)
	# the stagger from the block, Ada's desync reward state
	quiet(rx_ada); place(rx_ada, 1.4); rx_ada.bstate = "TELL"; rx_ada.bstring = "S1"; rx_ada.btimer = 1 << 30; rx_ada.events.clear()
	throw_clean(rx_ada, "L_STRAIGHT")
	var rx_des_int: bool = count_events(rx_ada.events, "interrupt", {"string": "S1", "stagger": TNBSim.ms(800), "desync": true}) == 1 and count_events(rx_ada.events, "desync") == 1 and rx_ada.bstate == "IDLE" and absi(rx_ada.btimer - TNBSim.ms(3000)) <= 2 and rx_ada.bdesync_widen
	rx_ada.btimer = 1; rx_ada.events.clear(); rx_ada.P["flash_t"] = 0; thaw(rx_ada)
	var rx_wn := 0
	while count_events(rx_ada.events, "tell") == 0 and rx_wn < 600: rx_ada.step({}); rx_wn += 1
	var rx_widened := false
	for rx_e in rx_ada.events:
		if rx_e["kind"] == "tell": rx_widened = int(rx_e["ticks"]) == int(TNBSim.ms(float(rx_ada.pattern["strings"][str(rx_e["string"])]["tell"]["ms"])) * rx_ada._tell_mult()) + TNBSim.ms(100); break
	freeze_boss(rx_ada); thaw(rx_ada); rx_ada.apply_directive("desync 3s->2s"); place(rx_ada, 1.4); rx_ada.bstate = "TELL"; rx_ada.bstring = "S2"; rx_ada.btimer = 1 << 30; rx_ada.events.clear(); rx_ada.P["flash_t"] = 0
	throw_clean(rx_ada, "L_STRAIGHT")
	var rx_des2: bool = absi(rx_ada.btimer - TNBSim.ms(2000)) <= 2 and count_events(rx_ada.events, "interrupt", {"desync": true}) == 1
	quiet(rx_vey); place(rx_vey, 1.4); rx_vey.bstate = "TELL"; rx_vey.bstring = "P1S1"; rx_vey.btimer = 1 << 30; rx_vey.events.clear()
	throw_clean(rx_vey, "L_STRAIGHT")
	var rx_vey_st: bool = absi(rx_vey.btimer - TNBSim.ms(700)) <= 2 and count_events(rx_vey.events, "interrupt", {"stagger": TNBSim.ms(700), "desync": false}) == 1
	_sr("the block's response executes: Ada's S1 broken staggers 800ms and DESYNCs her 3s (she stalls the whole 3s, her next tell is +100ms wider); her phase-2 line 'desync 3s->2s' shortens the stall to 2s; Vey staggers 700",
		rx_des_int and rx_widened and rx_des2 and rx_vey_st)
	# phase directives execute
	var rx_ph := make_sim(1, 7); quiet(rx_ph); thaw(rx_ph); rx_ph.events.clear()
	rx_ph.B["comp"] = rx_ph.B["comp_max"] * 0.55; rx_ph.bstate = "IDLE"; rx_ph.btimer = 1 << 30; rx_ph.step({})
	var rx_ph_ok: bool = rx_ph.bphase == 2 and rx_ph.directives_done == ["speed x1.1", "tighten(S1, 500ms)", "add S3"] and rx_ph.directives_carried.is_empty() and int(rx_ph.pattern["strings"]["S1"]["tell"]["ms"]) == 500 and absf(float(rx_ph.bmods["speed"]) - 1.1) < 0.001 and rx_ph._phase_ok("S3") and count_events(rx_ph.events, "directive", {"executed": true}) == 3
	var rx_orig_ok: bool = int(content["patterns"]["yuri_kowalchuk"]["strings"]["S1"]["tell"]["ms"]) == 600 and "phase>=2" in content["patterns"]["yuri_kowalchuk"]["strings"]["S3"]["tags"]
	var rx_dcov: Dictionary = rxs.directive_coverage(content["patterns"])
	var rx_exec: Array = rx_dcov["executed"]; var rx_carr: Array = rx_dcov["carried"]
	var rx_kinds_ok: bool = "moira_macisaac: all_damage +10pct permanent" in rx_exec and "jean_guy_moreau: tighten_all_tells -60ms floor_respected" in rx_exec and "jean_guy_moreau: movement +10pct" in rx_exec and "tam_nguyen_roy: retire S1" in rx_exec and "hc9_choir: S1,S2 tell -50ms floor_respected" in rx_exec and "alfie_crane: w(S1)+=15" in rx_exec and "sam_tagaq: strength +5pct" in rx_exec and "itzel_reyes_ortega: all_body_damage +15pct" in rx_exec and "ada_okafor: desync 3s->2s" in rx_exec and "cassidy_vane: add S3" in rx_exec \
		and "anders_vey: kit_swap swarmer_gale" in rx_exec and "ada_okafor: metronome 800ms->650ms" in rx_exec and "tam_nguyen_roy: true_pattern_only" in rx_exec
	var rx_tam := make_sim(22, 7); quiet(rx_tam); thaw(rx_tam); rx_tam.clock_t = TNBSim.ms(90000) - TNBSim.ms(31000); rx_tam.bstate = "IDLE"; rx_tam.btimer = 1 << 30; rx_tam.step({})
	var rx_tam_ok: bool = rx_tam.bphase == 2 and not rx_tam._phase_ok("S1") and rx_tam._phase_ok("S2")
	var rx_mo := make_sim(2, 7); quiet(rx_mo); thaw(rx_mo); rx_mo.B["comp"] = rx_mo.B["comp_max"] * 0.5; rx_mo.bstate = "IDLE"; rx_mo.btimer = 1 << 30; rx_mo.step({})
	var rx_mo_ok: bool = rx_mo.bphase == 2 and int(rx_mo.pattern["strings"]["S1"]["tell"]["ms"]) == 420 and int(rx_mo.pattern["strings"]["S2"]["tell"]["ms"]) == 700 and int(rx_mo.pattern["strings"]["S3"]["tell"]["ms"]) == 1000 and absf(float(rx_mo.bmods["move"]) - 1.1) < 0.001 and absf(rx_mo._speed_mult("B") - 1.1) < 0.001
	_sr("phase directives execute through one executor: Yuri's phase 2 at 55%% (speed x1.1 -> his recoveries /1.1, tighten(S1, 500ms), add S3 selectable) with the original pattern untouched; Tam's 'retire S1' at clock>30; Moreau's 'tighten_all_tells -60ms' floors his SPECIAL at 700 and ARMORED at 1000 and 'movement +10pct' moves him; across the 24, %d directive lines execute and %d are carried" % [rx_exec.size(), rx_carr.size()],
		rx_ph_ok and rx_orig_ok and rx_kinds_ok and rx_exec.size() == 47 and rx_carr.is_empty() and rx_tam_ok and rx_mo_ok)
	# tighten floors
	var rx_fl := make_sim(4, 7); quiet(rx_fl)
	rx_fl.apply_directive("tighten(S1, 100ms)"); rx_fl.apply_directive("tighten(S3, 100ms)")
	var rx_fl_ok: bool = int(rx_fl.pattern["strings"]["S1"]["tell"]["ms"]) == 400 and int(rx_fl.pattern["strings"]["S3"]["tell"]["ms"]) == 700
	var rx_fl2 := make_sim(14, 7); quiet(rx_fl2); rx_fl2.apply_directive("tells -900ms floor_respected")
	var rx_fl2_ok: bool = int(rx_fl2.pattern["strings"]["S1"]["tell"]["ms"]) == 1000 and int(rx_fl2.pattern["strings"]["S2"]["tell"]["ms"]) == 400 and int(rx_fl2.pattern["strings"]["S3"]["tell"]["ms"]) == 400
	_sr("a tell is never set under its class floor (NP_04 s1): tighten(S1, 100ms) on Ada stops at 400, her SPECIAL S3 at 700; 'tells -900ms' on Echo leaves his ARMORED S1 at 1000 and the normals at 400", rx_fl_ok and rx_fl2_ok)
	# the remix layer: Yuri's rematch
	var rx_y := make_sim(1, 7)
	var rx_set_ok: bool = rx_y.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch") and not rx_y.set_remix("yuri_kowalchuk", "moira_macisaac.rematch") and not rx_y.set_remix("yuri_kowalchuk", "nope") and rx_y.remixes_of("yuri_kowalchuk") == ["yuri_kowalchuk.rematch"] and rx_y.remixes_of("hc0_surety").is_empty()
	rx_y.new_dual()
	var rx_f: Dictionary = rx_y.pattern["strings"]["S1"].get("feint", {})
	var rx_y_ok: bool = rx_y.bremix.get("id", "") == "yuri_kowalchuk.rematch" and rx_f.get("mode", "") == "delay" and absf(float(rx_f.get("ms", 0)) - 300.0) < 0.001 and absf(float(rx_f.get("pct", 0)) - 0.4) < 0.001 and int(rx_f.get("burn_after", 0)) == 3 \
		and int(rx_y.pattern["strings"]["S2"]["tell"]["ms"]) == 450 and rx_y.pattern["select"]["weights"] == {"S1": 40, "S2": 40, "S3": 20} and count_events(rx_y.events, "remix", {"id": "yuri_kowalchuk.rematch"}) == 1 and rx_y.bremix["notes"].size() == 4
	var rx_orig2: bool = not content["patterns"]["yuri_kowalchuk"]["strings"]["S1"].has("feint") and int(content["patterns"]["yuri_kowalchuk"]["strings"]["S2"]["tell"]["ms"]) == 500 and not rx_y.patterns["yuri_kowalchuk"]["strings"]["S1"].has("feint")
	rx_y.set_remix("yuri_kowalchuk", ""); rx_y.new_dual()
	var rx_back: bool = rx_y.bremix.is_empty() and not rx_y.pattern["strings"]["S1"].has("feint") and int(rx_y.pattern["strings"]["S2"]["tell"]["ms"]) == 500
	var rx_all_ok := true
	for rx_rid in rxs.REMIX["remixes"]:
		if not rxs.set_remix(str(rxs.REMIX["remixes"][rx_rid]["base"]), str(rx_rid)): rx_all_ok = false
	_sr("the remix as a layer: Yuri's rematch loads over a copy (S1 feints 300ms late at 40%, burns after 3; S2 tell 450; weights 40/40/20; four notes on the card) and the original in `patterns` is untouched; '' restores the original; a remix refuses another boss's base; every authored remix loads on its base",
		rx_set_ok and rx_y_ok and rx_orig2 and rx_back and rx_all_ok)
	# feint(Sx) delay: the tell plays, the shot is late; the tell still breaks
	var rx_fd := make_sim(1, 7); rx_fd.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); rx_fd.new_dual(); rx_fd.hooks_enabled = false; rx_fd.coach_on = false; place(rx_fd, 1.6)
	rx_fd.pattern["strings"]["S1"]["feint"]["pct"] = 1.0; rx_fd.pattern["select"]["weights"] = {"S1": 100, "S2": 0, "S3": 0}
	rx_fd.bstate = "IDLE"; rx_fd.btimer = 1; rx_fd.events.clear()
	var rx_n := 0
	while count_events(rx_fd.events, "tell") == 0 and rx_n < 600: rx_fd.step({}); rx_n += 1
	var rx_tell_var: bool = count_events(rx_fd.events, "tell", {"string": "S1", "variant": "delay"}) == 1
	rx_n = 0
	while rx_fd.bstate == "TELL" and rx_n < 600: rx_fd.step({}); rx_n += 1
	var rx_hold: bool = rx_fd.bstate == "HOLD" and rx_fd.btimer == TNBSim.ms(300) and count_events(rx_fd.events, "feint_b", {"string": "S1", "mode": "delay"}) == 1
	rx_n = 0
	while count_events(rx_fd.events, "boss_act") == 0 and rx_n < 600: rx_fd.step({}); rx_n += 1
	var rx_late: bool = rx_fd.bstate == "ACTING" and count_events(rx_fd.events, "boss_act", {"verb": "punch", "row": "R_HOOKERCUT"}) == 1 and rx_n >= TNBSim.ms(300) - 2
	var rx_fd0 := make_sim(1, 7); rx_fd0.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); rx_fd0.new_dual(); rx_fd0.hooks_enabled = false; rx_fd0.coach_on = false; place(rx_fd0, 1.6)
	rx_fd0.pattern["strings"]["S1"]["feint"]["pct"] = 0.0; rx_fd0.pattern["select"]["weights"] = {"S1": 100, "S2": 0, "S3": 0}; rx_fd0.bstate = "IDLE"; rx_fd0.btimer = 1; rx_fd0.events.clear()
	rx_n = 0
	while (rx_fd0.bstate != "ACTING") and rx_n < 600: rx_fd0.step({}); rx_n += 1
	var rx_straight: bool = count_events(rx_fd0.events, "tell", {"string": "S1", "variant": ""}) == 1 and count_events(rx_fd0.events, "feint_b") == 0
	var rx_fi := make_sim(1, 7); rx_fi.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); rx_fi.new_dual(); quiet(rx_fi); place(rx_fi, 1.4)
	rx_fi.bstate = "TELL"; rx_fi.bstring = "S1"; rx_fi.bfeint = "delay"; rx_fi.btimer = 1 << 30; rx_fi.events.clear()
	throw_clean(rx_fi, "L_STRAIGHT")
	var rx_fi_ok: bool = count_events(rx_fi.events, "interrupt", {"string": "S1"}) == 1 and rx_fi.bfeint == "" and rx_fi.bstate == "IDLE"
	_sr("feint(S1) delay on the remixed Yuri: the tell plays as S1's, then he HITCHES 300ms (%d ticks) before the haymaker comes; at 0%% the string comes straight off the tell; a jab in the feint's tell still breaks it (S1 is tagged)" % TNBSim.ms(300),
		rx_tell_var and rx_hold and rx_late and rx_straight and rx_fi_ok)
	# feint(Sx) cancel: Moira's haul releases into a hook
	var rx_mc := make_sim(19, 7); rx_mc.set_remix("moira_macisaac", "moira_macisaac.rematch"); rx_mc.new_dual(); rx_mc.hooks_enabled = false; rx_mc.coach_on = false; place(rx_mc, 1.6)
	rx_mc.pattern["strings"]["S2"]["feint"]["pct"] = 1.0; rx_mc.pattern["select"]["weights"] = {"S1": 0, "S2": 100, "S3": 0}; rx_mc.bstate = "IDLE"; rx_mc.btimer = 1; rx_mc.events.clear()
	rx_n = 0
	while count_events(rx_mc.events, "boss_act") == 0 and rx_n < 900: rx_mc.step({}); rx_n += 1
	var rx_mc_first := ""
	for rx_e in rx_mc.events:
		if rx_e["kind"] == "boss_act": rx_mc_first = str(rx_e.get("row", rx_e.get("verb", ""))); break
	var rx_mc_ok: bool = count_events(rx_mc.events, "tell", {"string": "S2", "variant": "cancel"}) == 1 and count_events(rx_mc.events, "feint_b", {"string": "S2", "mode": "cancel", "into": "S1"}) == 1 and rx_mc_first == "L_HOOK" and count_events(rx_mc.events, "boss_act", {"row": "R_FLARED"}) == 0
	_sr("feint(S2) cancel on the remixed Moira: the tell is the net-haul's, the hands are Left Hook's - the first act is S1's L_HOOK, never S2's overhand", rx_mc_ok)
	# burn: three interrupts of Freight and it only feints
	var rx_b := make_sim(1, 7); rx_b.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); rx_b.new_dual(); quiet(rx_b); place(rx_b, 1.4)
	rx_b.pattern["strings"]["S1"]["feint"]["pct"] = 0.0; rx_b.pattern["select"]["weights"] = {"S1": 100, "S2": 0, "S3": 0}
	var rx_pick_variant := func(sim: TNBSim) -> String:
		freeze_boss(sim); thaw(sim); place(sim, 1.6); sim.bstate = "IDLE"; sim.btimer = 1; sim.events.clear(); sim.P["flash_t"] = 0
		var rx_j := 0
		while count_events(sim.events, "tell") == 0 and rx_j < 600: sim.step({}); rx_j += 1
		for rx_e in sim.events:
			if rx_e["kind"] == "tell": return str(rx_e.get("variant", ""))
		return "no tell"
	for rx_i in 2:
		thaw(rx_b); place(rx_b, 1.4); rx_b.bstate = "TELL"; rx_b.bstring = "S1"; rx_b.btimer = 1 << 30; rx_b.P["flash_t"] = 0; throw_clean(rx_b, "L_STRAIGHT")
	var rx_two: String = rx_pick_variant.call(rx_b)
	thaw(rx_b); place(rx_b, 1.4); rx_b.bstate = "TELL"; rx_b.bstring = "S1"; rx_b.btimer = 1 << 30; rx_b.P["flash_t"] = 0; throw_clean(rx_b, "L_STRAIGHT")
	var rx_three: String = rx_pick_variant.call(rx_b)
	_sr("burn(S1, 3) - NP_04 s4: after two interrupts of Freight it still comes straight (%s), after the third it only feints (%s); the count is his segment's (%d)" % [rx_two, rx_three, int(rx_b.binterrupts.get("S1", 0))],
		rx_two == "" and rx_three == "delay" and int(rx_b.binterrupts.get("S1", 0)) == 3)
	# newstring / tighten (Carter), phase_shift (Moreau), phase_directives (Tam); the remix's own page
	var rx_c := make_sim(7, 7); rx_c.set_remix("carter_okafor", "carter_okafor.rematch"); rx_c.new_dual()
	var rx_c4: Array = rx_c.parse_action("CHECK_HOOK")
	var rx_c_ok: bool = rx_c.pattern["strings"].has("S4") and int(rx_c.pattern["strings"]["S4"]["tell"]["ms"]) == 450 and int(rx_c.pattern["select"]["weights"]["S4"]) == 25 and int(rx_c.pattern["strings"]["S2"]["tell"]["ms"]) == 420 and rx_c4.size() == 1 and rx_c4[0]["row"] == "L_HOOK" and rx_c.parse_action("STEP_BACK").size() == 1 and not rx_c._interruptible("S4")
	var rx_m := make_sim(2, 7); rx_m.set_remix("jean_guy_moreau", "jean_guy_moreau.rematch"); rx_m.new_dual(); quiet(rx_m); thaw(rx_m)
	var rx_m_trig: String = rx_m.pattern["phases"][0]["trigger"]
	rx_m.B["comp"] = rx_m.B["comp_max"] * 0.65; rx_m.bstate = "IDLE"; rx_m.btimer = 1 << 30; rx_m.step({})
	var rx_m0 := make_sim(2, 7); quiet(rx_m0); thaw(rx_m0); rx_m0.B["comp"] = rx_m0.B["comp_max"] * 0.65; rx_m0.bstate = "IDLE"; rx_m0.btimer = 1 << 30; rx_m0.step({})
	var rx_m_ok: bool = rx_m_trig == "composure<70" and rx_m.bphase == 2 and rx_m0.bphase == 1 and rx_m.pattern["strings"].has("S4") and int(rx_m.pattern["strings"]["S1"]["tell"]["ms"]) == 420
	var rx_t := make_sim(22, 7); rx_t.set_remix("tam_nguyen_roy", "tam_nguyen_roy.rematch"); rx_t.new_dual(); quiet(rx_t); thaw(rx_t); rx_t.clock_t = TNBSim.ms(90000) - TNBSim.ms(31000); rx_t.bstate = "IDLE"; rx_t.btimer = 1 << 30; rx_t.step({})
	var rx_t_ok: bool = rx_t.bphase == 2 and rx_t._phase_ok("S1") and rx_t.directives_done == ["true_pattern_only"] and rx_t.btrue_pattern and int(rx_t.pattern["select"]["weights"]["S1"]) == 40
	var rx_pg := make_sim(1, 7); rx_pg.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); rx_pg.new_dual(); quiet(rx_pg); rx_pg.ep_p = 6; rx_pg._end_segment("clock")
	var rx_page: Dictionary = rx_pg.scout_page("yuri_kowalchuk", "yuri_kowalchuk.rematch")
	var rx_pg_ok: bool = int(rx_pg.pi["bosses"]["yuri_kowalchuk"].get("remixes", {}).get("yuri_kowalchuk.rematch", 0)) == 1 and int(rx_pg.pi["bosses"]["yuri_kowalchuk"].get("beaten", 0)) == 0 and count_events(rx_pg.events, "scout_book", {"boss": "yuri_kowalchuk", "remix": "yuri_kowalchuk.rematch"}) == 1 \
		and rx_page.size() > 0 and rx_page["remix_notes"].size() == 4 and rx_pg.scout_page("yuri_kowalchuk").is_empty() and rx_pg.pi_boss("yuri_kowalchuk", "yuri_kowalchuk.rematch") == 3 and rx_pg.pi_boss("yuri_kowalchuk") == 0
	# the profile with the page: it never jabs a tell that does not break
	var rx_plans := func(ledger: Dictionary, sname: String) -> Dictionary:
		var rx_ps := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", ledger); quiet(rx_ps); rx_ps.delegated = true; rx_ps.auto = TNBProfile.fresh_memory(); place(rx_ps, 1.6)
		var out := {"jab": 0, "other": 0}
		for rx_k in 300:
			rx_ps.tick += 1; rx_ps.bstate = "TELL"; rx_ps.bstring = sname; rx_ps.btimer = 60; rx_ps.tell_start_tick = rx_ps.tick; rx_ps.auto["plan"] = ""
			TNBProfile.intent(rx_ps, {})
			if str(rx_ps.auto["plan"]) in ["jab", "jabbed"]: out["jab"] += 1
			elif str(rx_ps.auto["plan"]) != "": out["other"] += 1
		return out
	var rx_p0: Dictionary = rx_plans.call({}, "S2"); var rx_p3: Dictionary = rx_plans.call(pi_ledger.call("yuri_kowalchuk:3"), "S2"); var rx_p3b: Dictionary = rx_plans.call(pi_ledger.call("yuri_kowalchuk:3"), "S1")
	_sr("the profile with Yuri's page (PI 3) never jabs Coupling's tell (S2 does not break: %d jabs of 300, %d slips / blocks) where at PI 0 it wastes %d jabs on it; Freight's tell (S1 breaks) it still jabs (%d)" % [int(rx_p3["jab"]), int(rx_p3["other"]), int(rx_p0["jab"]), int(rx_p3b["jab"])],
		int(rx_p3["jab"]) == 0 and int(rx_p3["other"]) >= 100 and int(rx_p0["jab"]) >= 30 and int(rx_p3b["jab"]) >= 30)
	_sr("newstring / tighten on Carter (S4 'Tape Study' at 450ms, weight 25, its actions parse, not tagged breakable; S2 420), phase_shift on Moreau (phase 2 at composure<70 fires at 65%% where the original does not, and his new string rides in), phase_directives on Tam (phase 2 no longer retires S1); the remix beaten earns its own Scout Book page (%d notes) and the original keeps its own unearned" % rx_page.get("remix_notes", []).size(),
		rx_c_ok and rx_m_ok and rx_t_ok and rx_pg_ok)

	# ================= PAC-066: the phase scripts, all of them (NP_04 z7, NP_04A/B) ======
	# a boss at a phase: quiet, thawed, the trigger met, one boss step
	var q6_phase := func(bi: int, comp_pct: float, clock_s: float = -1.0) -> TNBSim:
		var q := make_sim(bi, 7); quiet(q); thaw(q); place(q, 1.6); q.events.clear()
		if comp_pct >= 0.0: q.B["comp"] = q.B["comp_max"] * comp_pct
		if clock_s >= 0.0: q.clock_t = TNBSim.ms(90000) - TNBSim.ms(clock_s * 1000.0)
		q.bstate = "IDLE"; q.btimer = 1 << 30; q.step({})
		return q
	# a string run to its RECOVER, quietly: returns the RECOVER's ticks
	var q6_recover := func(q: TNBSim, sname: String) -> int:
		freeze_boss(q); thaw(q); place(q, 1.6); q.P["blocking"] = true; q.P["block_t"] = 999
		q.bstate = "TELL"; q.bstring = sname; q.btimer = 1; q.bforce_opts = {}; q.bfeint = ""
		var q_n := 0
		while q.bstate != "RECOVER" and q_n < 1200: q.step({"block": true}); q_n += 1
		return q.btimer if q.bstate == "RECOVER" else -1
	# the bases from META and the coverage
	var q6a := make_sim(4, 7); var q6c := make_sim(8, 7); var q6e := make_sim(14, 7)
	var q6_dcov: Dictionary = q6a.directive_coverage(content["patterns"])
	var q6_rcov: Dictionary = q6a.reweight_coverage(content["patterns"])
	var q6_bases: bool = absf(float(q6a.bmods["metronome_ms"]) - 800.0) < 0.001 and q6c.bmods["tempos"] == [600.0, 900.0] and int(q6e.bmods["splice_every"]) == 2 and absf(float(q6e.bmods["splice_open_ms"]) - 500.0) < 0.001 and int(q6a.pattern["select"]["weights"].get("S3", -1)) == 0 and not q6a._select_weights().has("S3")
	_sr("the phase scripts, all of them: %d of %d authored directive lines execute and %d are carried; the META bases are read (Ada's metronome 800, Chiamaka's tempos 600 / 900, Echo's splice every 2nd string, 500ms open); the SELECT block's phase lines and 'punish_only' execute (%d) and %d others are carried (Ada's SwarmProtocol weight 0: never selected on her own)" % [q6_dcov["executed"].size(), q6_dcov["executed"].size() + q6_dcov["carried"].size(), q6_dcov["carried"].size(), q6_rcov["executed"].size(), q6_rcov["carried"].size()],
		q6_dcov["executed"].size() == 47 and q6_dcov["carried"].is_empty() and q6_bases and q6_rcov["executed"].size() == 9 and q6_rcov["carried"].size() == 6, JSON.stringify(q6_rcov["carried"]))
	# Ada: the beat itself - a fixed 800ms between strings, 650 in phase 2; Chiamaka: 600 / 900 alternating, 550 / 850 in phase 2
	var q6_ada := make_sim(4, 7); quiet(q6_ada)
	var q6_r1: int = q6_recover.call(q6_ada, "S1"); var q6_r2: int = q6_recover.call(q6_ada, "S2")
	var q6_ada2: TNBSim = q6_phase.call(4, 0.45)
	var q6_r3: int = q6_recover.call(q6_ada2, "S1")
	var q6_chi := make_sim(8, 7); quiet(q6_chi)
	var q6_t1: int = q6_recover.call(q6_chi, "S1"); var q6_t2: int = q6_recover.call(q6_chi, "S1"); var q6_t3: int = q6_recover.call(q6_chi, "S1")
	var q6_chi2: TNBSim = q6_phase.call(8, 0.45)
	var q6_t4: int = q6_recover.call(q6_chi2, "S1"); var q6_t5: int = q6_recover.call(q6_chi2, "S1")
	_sr("Ada attacks on the metronome: %d / %d ticks between strings (800ms, no roll), %d in phase 2 (650ms); Chiamaka's polyrhythm alternates %d / %d / %d ticks (600 / 900), %d / %d in phase 2 (550 / 850)" % [q6_r1, q6_r2, q6_r3, q6_t1, q6_t2, q6_t3, q6_t4, q6_t5],
		q6_r1 == TNBSim.ms(800) and q6_r2 == TNBSim.ms(800) and q6_ada2.bphase == 2 and q6_r3 == TNBSim.ms(650) and q6_t1 == TNBSim.ms(600) and q6_t2 == TNBSim.ms(900) and q6_t3 == TNBSim.ms(600) and q6_chi2.bphase == 2 and q6_t4 == TNBSim.ms(550) and q6_t5 == TNBSim.ms(850))
	# Vane's calls get hidden a tier; Cal's tells louden a tier, he answers Whitlock, and in phase 3 he drifts to the strings you read
	var q6_vane: TNBSim = q6_phase.call(0, 0.45)
	var q6_vane_ok: bool = q6_vane.bphase == 2 and int(q6_vane.pattern["strings"]["S1"]["tell"]["ms"]) == 550 and int(q6_vane.pattern["strings"]["S2"]["tell"]["ms"]) == 550 and int(q6_vane.pattern["strings"]["S3"]["tell"]["ms"]) == 450 and q6_vane._phase_ok("S3") and int(q6_vane.bmods["tier_shift"]) == -1
	var q6_cal: TNBSim = q6_phase.call(9, 0.55)
	var q6_cal_ok: bool = q6_cal.bphase == 2 and int(q6_cal.pattern["strings"]["S1"]["tell"]["ms"]) == 630 and int(q6_cal.pattern["strings"]["S3"]["tell"]["ms"]) == 850 and q6_cal.bdialogue == "corner" and count_events(q6_cal.events, "dialogue", {"which": "corner"}) == 1
	q6_cal.B["comp"] = q6_cal.B["comp_max"] * 0.25; q6_cal.bstate = "IDLE"; q6_cal.btimer = 1 << 30; q6_cal.step({})
	q6_cal.breads = {"S2": 4, "S1": 1}
	var q6_w3: Dictionary = q6_cal._select_weights()
	var q6_cal3: bool = q6_cal.bphase == 3 and str(q6_cal.bmods["select_drift"]).begins_with("recognition") and int(q6_w3["S2"]) == 35 + 25 and int(q6_w3["S1"]) == 45
	_sr("Vane's phase 2 hides the corner calls a tier (700 -> 550, 600 -> 450, S3 added); Cal's phase 2 loudens his a tier (480 -> 630, 700 -> 850) and opens the corner dialogue; his phase 3 drifts SELECT +25 toward the string you have read most (S2 read 4 times: 35 -> 60)",
		q6_vane_ok and q6_cal_ok and q6_cal3)
	# Alfie: the flirtation stops at two warnings banked - from then he pulls every foul
	var q6_alf := make_sim(5, 7); quiet(q6_alf); thaw(q6_alf); place(q6_alf, 1.4); clear_defense(q6_alf.P); q6_alf.P["comp"] = q6_alf.P["comp_max"]
	q6_alf.bwarnings = 2; q6_alf.bstate = "IDLE"; q6_alf.btimer = 1 << 30; q6_alf.step({}); q6_alf.events.clear()
	q6_alf.P["dodge"] = "LEAN"; q6_alf.P["dodge_t"] = 999; boss_lands(q6_alf, "R_HOOK", 1.0, true)
	var q6_alf_ok: bool = q6_alf.bphase == 2 and bool(q6_alf.bmods["pull_all"]) and count_events(q6_alf.events, "pulled", {"by": "B"}) == 1 and q6_alf.bwarnings == 2 and int(q6_alf.pattern["select"]["weights"]["S1"]) == 60
	_sr("Alfie at warnings_banked==2: 'dirty_flirtation_stops' - the next low blow is pulled, the count stays at two, and w(S1)+=15 lands (45 -> 60)", q6_alf_ok)
	# Vey: three kits, the rings turning live; Vasile: kits by the clock with a 700ms seam, and the finale's fundamentals
	var q6_vey: TNBSim = q6_phase.call(6, 0.65)
	var q6_vey2: bool = q6_vey.bphase == 2 and q6_vey.B["style"] == "SWARMER" and q6_vey.B["element"] == "GALE" and not q6_vey._phase_ok("P1S1") and not q6_vey._phase_ok("P1S2") and q6_vey._phase_ok("P2S1") and q6_vey._phase_ok("P2S2") and not q6_vey._phase_ok("P3S1") \
		and int(q6_vey.pattern["select"]["weights"]["P2S1"]) == 55 and int(q6_vey.pattern["select"]["weights"]["P2S2"]) == 45 and count_events(q6_vey.events, "kit_swap", {"phase": 2, "style": "SWARMER", "element": "GALE"}) == 1 and count_events(q6_vey.events, "matchup", {"swap": true}) == 1 \
		and absf(float(q6_vey.B["comp"]) / float(q6_vey.B["comp_max"]) - 0.65) < 0.01 and q6_vey.aff["b"][0] == "SWARMER"
	q6_vey.B["comp"] = q6_vey.B["comp_max"] * 0.35; q6_vey.bstate = "IDLE"; q6_vey.btimer = 1 << 30; q6_vey.step({})
	var q6_vey3: bool = q6_vey.bphase == 3 and q6_vey.B["style"] == "SLUGGER" and q6_vey.B["element"] == "GRANITE" and not q6_vey._phase_ok("P2S1") and q6_vey._phase_ok("P3S1") and q6_vey._phase_ok("P3S2") and int(q6_vey.pattern["select"]["weights"]["P3S1"]) == 60
	var q6_vas: TNBSim = q6_phase.call(16, -1.0, 31.0)
	var q6_vas2: bool = q6_vas.bphase == 2 and q6_vas.B["element"] == "GRANITE" and q6_vas.B["style"] == "BOXERPUNCHER" and q6_vas._phase_ok("G1") and q6_vas._phase_ok("G2") and not q6_vas._phase_ok("F1") and not q6_vas._phase_ok("A1") \
		and count_events(q6_vas.events, "neutral_reset", {"ms": 700.0}) == 1 and q6_vas.bstate == "IDLE" and absi(q6_vas.btimer - TNBSim.ms(700)) <= 1 and absf(q6_vas.P["pos"].distance_to(q6_vas.B["pos"]) - 1.8) < 0.05
	q6_vas.clock_t = TNBSim.ms(90000) - TNBSim.ms(61000); q6_vas.bstate = "IDLE"; q6_vas.btimer = 1 << 30; q6_vas.step({})
	var q6_vas3: bool = q6_vas.bphase == 3 and q6_vas.B["element"] == "GALE" and q6_vas._phase_ok("A1") and q6_vas._phase_ok("A2") and not q6_vas._phase_ok("G2") and count_events(q6_vas.events, "neutral_reset") == 2
	q6_vas.B["comp"] = q6_vas.B["comp_max"] * 0.09; q6_vas.bstate = "IDLE"; q6_vas.btimer = 1 << 30; q6_vas.step({})
	var q6_live: Array = q6_vas._select_weights().keys(); q6_live.sort()
	var q6_fin: bool = q6_vas.bphase == 4 and q6_vas.B["element"] == "NONE" and q6_live == ["F1", "F2"] and count_events(q6_vas.events, "fundamentals_only") == 1
	_sr("Vey's kits: at 70%% the Swarmer / Gale kit (P1 retired, P2 live at 55 / 45, a swap matchup card, condition kept as a fraction), at 40%% the Slugger / Granite kit; Vasile's clock kits: Granite at 30s with the 700ms neutral seam (both fighters reset to 1.8m, he idles the seam), Gale at 60s, and the finale under 10%% locks to F1 / F2 with no element",
		q6_vey2 and q6_vey3 and q6_vas2 and q6_vas3 and q6_fin)
	# the Cartographer: an erased house's dialect per phase; Echo: the splice shows every 2nd string, every 3rd in phase 2
	var q6_hc4: TNBSim = q6_phase.call(13, 0.65)
	var q6_hc4a: bool = q6_hc4.bphase == 2 and q6_hc4.bdialect == "erased_berube" and not q6_hc4._phase_ok("S1") and q6_hc4._phase_ok("S3") and q6_hc4._phase_ok("S4") and int(q6_hc4.pattern["select"]["weights"]["S3"]) == 50 and count_events(q6_hc4.events, "dialect_swap", {"dialect": "erased_berube"}) == 1
	q6_hc4.B["comp"] = q6_hc4.B["comp_max"] * 0.35; q6_hc4.bstate = "IDLE"; q6_hc4.btimer = 1 << 30; q6_hc4.step({})
	var q6_hc4b: bool = q6_hc4.bphase == 3 and q6_hc4.bdialect == "erased_oduya" and not q6_hc4._phase_ok("S3") and q6_hc4._phase_ok("S5") and int(q6_hc4.pattern["select"]["weights"]["S5"]) == 100
	var q6_echo := make_sim(14, 7); quiet(q6_echo)
	q6_recover.call(q6_echo, "S2"); var q6_open1: bool = count_events(q6_echo.events, "splice_open") == 0 and q6_echo.B["guard_open_t"] <= 0
	q6_recover.call(q6_echo, "S3"); var q6_open2: bool = count_events(q6_echo.events, "splice_open", {"after": 2}) == 1 and q6_echo.B["guard_open_t"] == TNBSim.ms(500)
	var q6_echo2: TNBSim = q6_phase.call(14, 0.45)
	q6_recover.call(q6_echo2, "S2"); q6_recover.call(q6_echo2, "S3"); var q6_open3: bool = count_events(q6_echo2.events, "splice_open") == 0
	q6_recover.call(q6_echo2, "S2"); var q6_open4: bool = count_events(q6_echo2.events, "splice_open", {"after": 3}) == 1
	_sr("the Cartographer at 70%% speaks erased Berube (S1 / S2 retired, S3 / S4 at 50 / 50, the dialect key turns), at 40%% erased Oduya (S5 at 100); Echo's machine splice: OPEN 500ms after his 2nd string and not his 1st, after every 3rd in phase 2",
		q6_hc4a and q6_hc4b and q6_open1 and q6_open2 and q6_open3 and q6_open4)
	# Carter's second body hook, Deshawn's fifth hit, Osei's longer Shell, Marta's greedy Mirror
	var q6_car: TNBSim = q6_phase.call(7, 0.45)
	var q6_car_ok: bool = q6_car.bphase == 2 and q6_car.pattern["strings"]["S2"]["actions"] == ["LATERAL_ARC", "LT_L_HOOK", "LT_R_HOOK"]
	var q6_des: TNBSim = q6_phase.call(10, 0.45)
	var q6_des_acts: Array = []
	for q6_a in q6_des.pattern["strings"]["S3"]["actions"]: q6_des_acts.append_array(q6_des.parse_action(str(q6_a)))
	var q6_des_ok: bool = q6_des.bphase == 2 and q6_des.pattern["strings"]["S3"]["actions"] == ["MIXED_STRING(5)"] and q6_des_acts.size() == 5
	var q6_ose := make_sim(11, 7); quiet(q6_ose)
	var q6_shell := func(q: TNBSim) -> int:
		freeze_boss(q); thaw(q); place(q, 1.6); q.bstate = "TELL"; q.bstring = "S1"; q.btimer = 1; q.bforce_opts = {}; q.bfeint = ""
		q.step({}); q.step({})
		for q_act in q.bqueue:
			if str(q_act["kind"]) == "counter_state": return int(q_act["t"])
		return int(q.B["counter_state_t"])
	var q6_sh0: int = q6_shell.call(q6_ose)
	var q6_ose2: TNBSim = q6_phase.call(11, 0.45)
	var q6_sh1: int = q6_shell.call(q6_ose2)
	var q6_mar := make_sim(18, 7); quiet(q6_mar)
	var q6_mi0: int = q6_shell.call(q6_mar)
	var q6_mar2: TNBSim = q6_phase.call(18, 0.5)
	var q6_mi1: int = q6_shell.call(q6_mar2)
	q6_mar2.bcooldown_until = {}
	var q6_w_before: bool = q6_mar2._select_weights().has("S1")
	freeze_boss(q6_mar2); thaw(q6_mar2); place(q6_mar2, 1.6); q6_mar2.pattern["select"]["weights"] = {"S1": 100, "S2": 0, "S3": 0}; q6_mar2.bstate = "IDLE"; q6_mar2.btimer = 1; q6_mar2.events.clear()
	var q6_n := 0
	while count_events(q6_mar2.events, "tell") == 0 and q6_n < 300: q6_mar2.step({}); q6_n += 1
	var q6_cd: bool = int(q6_mar2.bcooldown_until.get("S1", -1)) > q6_mar2.tick and int(q6_mar2.bcooldown_until["S1"]) - q6_mar2.tick <= TNBSim.ms(6000) and not q6_mar2._select_weights().has("S1")
	_sr("Carter's S2 gains its second body hook at 50%%; Deshawn's Pileup grows to five hits; Osei's Shell holds %.1fs then %.1fs in phase 2; Marta's Mirror holds %.1fs then %.1fs in phase 2 and cannot be picked again for 6s after a use (S1 off the SELECT while it cools)" % [q6_sh0 / 120.0, q6_sh1 / 120.0, q6_mi0 / 120.0, q6_mi1 / 120.0],
		q6_car_ok and q6_des_ok and q6_sh0 == TNBSim.ms(3000) and q6_ose2.bphase == 2 and q6_sh1 == TNBSim.ms(4000) and q6_mi0 == TNBSim.ms(2500) and q6_mar2.bphase == 2 and q6_mi1 == TNBSim.ms(3500) and q6_w_before and q6_cd)
	# Remy's shame, Sora's nothing, Baro's faster corrections, Tam's true pattern (through the sim), the seed for the whole set
	var q6_rem: TNBSim = q6_phase.call(20, 0.45)
	var q6_rem_ok: bool = q6_rem.bphase == 2 and q6_rem.bdialogue == "shame" and count_events(q6_rem.events, "dialogue", {"which": "shame"}) == 1 and int(q6_rem.pattern["select"]["weights"]["S3"]) == 30
	var q6_sor0 := make_sim(21, 7)
	var q6_sor: TNBSim = q6_phase.call(21, 0.45)
	var q6_sor_ok: bool = q6_sor.bphase == 2 and count_events(q6_sor.events, "no_changes") == 1 and count_events(q6_sor.events, "directive", {"executed": true}) == 1 and JSON.stringify(q6_sor.pattern["strings"]) == JSON.stringify(q6_sor0.pattern["strings"]) and q6_sor.pattern["select"]["weights"] == q6_sor0.pattern["select"]["weights"] and q6_sor.bmods == q6_sor0.bmods
	var q6_bar: TNBSim = q6_phase.call(23, 0.45)
	q6_bar.punish_cd = {}; q6_bar.hooks_enabled = true; q6_bar._fire_event("player_rope_touch")
	var q6_bar_ok: bool = q6_bar.bphase == 2 and absf(float(q6_bar.bmods["punish_cd_mult"]) - 0.5) < 0.001 and int(q6_bar.punish_cd.get("rope_touch", 0)) == TNBSim.ms(2000) and int(q6_bar.pattern["strings"]["S1"]["tell"]["ms"]) == 460
	var q6_bar0 := make_sim(23, 7); quiet(q6_bar0); thaw(q6_bar0); q6_bar0.punish_cd = {}; q6_bar0.hooks_enabled = true; q6_bar0._fire_event("player_rope_touch")
	var q6_bar0_ok: bool = int(q6_bar0.punish_cd.get("rope_touch", 0)) == TNBSim.ms(4000)
	_sr("Remy's phase 2 opens the shame dialogue and w(S3)+=10; Sora's 'no_changes_by_design' executes and changes nothing (strings, weights and modifiers identical); Baro's corrections come twice as often in phase 2 (a punish cooldown of %d ticks, %d before) with his tells -40ms" % [int(q6_bar.punish_cd.get("rope_touch", 0)), int(q6_bar0.punish_cd.get("rope_touch", 0))],
		q6_rem_ok and q6_sor_ok and q6_bar_ok and q6_bar0_ok)

	# ================= PAC-067: the pattern, all of it ======================
	var q7_cov: Dictionary = q6a.pattern_coverage(content["patterns"])
	var q7_cov_ok: bool = q7_cov["meta"]["carried"].is_empty() and q7_cov["select"]["carried"].is_empty() and q7_cov["directives"]["carried"].is_empty() and q7_cov["tags"]["carried"].is_empty() \
		and q7_cov["select"]["executed"].size() == 15 and q7_cov["directives"]["executed"].size() == 47 and q7_cov["meta"]["executed"].size() >= 100 and q7_cov["meta"]["presentational"].size() >= 8 and q7_cov["idle"]["carried"].is_empty()
	_sr("pattern_coverage over the 24: every META key executed (%d) or presentational (%d), every SELECT line executed (%d), every directive (%d), every tag; and since PAC-071 the IDLE lines too (%d carried)" % [q7_cov["meta"]["executed"].size(), q7_cov["meta"]["presentational"].size(), q7_cov["select"]["executed"].size(), q7_cov["directives"]["executed"].size(), q7_cov["idle"]["carried"].size()],
		q7_cov_ok, JSON.stringify(q7_cov["meta"]["carried"]) + JSON.stringify(q7_cov["select"]["carried"]) + JSON.stringify(q7_cov["tags"]["carried"]))
	# Yuri after a hit taken: Freight +20 for 6s; Moira and Alfie on the ropes: the rope string comes and comes heavier; Marta's patience line
	var q7_y := make_sim(1, 7); quiet(q7_y); place(q7_y, 1.4)
	var q7_w0: int = int(q7_y._select_weights().get("S1", 0))
	throw_clean(q7_y, "L_STRAIGHT")
	var q7_w1: int = int(q7_y._select_weights().get("S1", 0))
	run_ticks(q7_y, TNBSim.ms(6000) + 2)
	var q7_w2: int = int(q7_y._select_weights().get("S1", 0))
	var q7_mo := make_sim(19, 7); quiet(q7_mo); q7_mo.P["pos"] = Vector2(0.0, 0.3); q7_mo.B["pos"] = Vector2(0.0, -1.2)
	var q7_mo_c: Dictionary = q7_mo._select_weights()
	q7_mo.P["pos"] = Vector2(0.0, 3.3); q7_mo.B["pos"] = Vector2(0.0, 1.8)
	var q7_mo_r: Dictionary = q7_mo._select_weights()
	var q7_al := make_sim(5, 7); quiet(q7_al); q7_al.P["pos"] = Vector2(0.0, 3.3); q7_al.B["pos"] = Vector2(0.0, 1.8)
	var q7_al_r: Dictionary = q7_al._select_weights()
	q7_al.P["pos"] = Vector2(0.0, 0.3); q7_al.B["pos"] = Vector2(0.0, -1.2)
	var q7_al_c: Dictionary = q7_al._select_weights()
	var q7_ma := make_sim(18, 7); quiet(q7_ma); place(q7_ma, 1.6)
	var q7_ma0: int = int(q7_ma._select_weights().get("S2", 0)); q7_ma.passive_t = TNBSim.ms(8000)
	var q7_ma1: int = int(q7_ma._select_weights().get("S2", 0))
	_sr("the SELECT block's lines: Yuri's Freight goes %d -> %d after a hit taken and back to %d after 6s; Moira's Gaff is off the SELECT at centre and on it at %d on the ropes, Alfie's Sunday Best at %d on the ropes and off at centre; Marta's Frost Line %d -> %d once you refuse to lead for 8s" % [q7_w0, q7_w1, q7_w2, int(q7_mo_r.get("S3", 0)), int(q7_al_r.get("S3", 0)), q7_ma0, q7_ma1],
		q7_w0 == 50 and q7_w1 == 70 and q7_w2 == 50 and not q7_mo_c.has("S3") and int(q7_mo_r.get("S3", 0)) == 45 and int(q7_al_r.get("S3", 0)) == 45 and not q7_al_c.has("S3") and q7_ma0 == 45 and q7_ma1 == 75)
	# the clock lines and Alfie's herding
	var q7_ca := make_sim(7, 7); quiet(q7_ca)
	var q7_ca0: float = q7_ca._bspeed(); q7_ca.clock_t = TNBSim.ms(29000); var q7_ca1: float = q7_ca._bspeed()
	var q7_sa := make_sim(3, 7); quiet(q7_sa)
	var q7_sa0: float = q7_sa._bspeed(); q7_sa.clock_t = TNBSim.ms(90000) - TNBSim.ms(61000); var q7_sa1: float = q7_sa._bspeed()
	var q7_herd := func(bi: int) -> float:
		var q := make_sim(bi, 7); quiet(q); q.P["pos"] = Vector2(0.0, 0.45); q.B["pos"] = Vector2(0.0, -0.45)
		var y0: float = q.P["pos"].y
		q._boss_act({"kind": "move", "dir": "toward", "dist": 0.5, "guard": false})
		return q.P["pos"].y - y0
	var q7_h_alf: float = q7_herd.call(5); var q7_h_vane: float = q7_herd.call(0)
	_sr("the clock lines: Carter's speed x1.12 with under 30s left (%.2f -> %.2f), Sam's x1.1 past the minute (%.2f -> %.2f); Alfie's herding walks you back %.3fm on a 50cm step where Vane's walks you %.3fm (+75%%)" % [q7_ca0, q7_ca1, q7_sa0, q7_sa1, q7_h_alf, q7_h_vane],
		absf(q7_ca0 - 1.0) < 0.001 and absf(q7_ca1 - 1.12) < 0.001 and absf(q7_sa0 - 1.0) < 0.001 and absf(q7_sa1 - 1.1) < 0.001 and absf(q7_h_vane - 0.5) < 0.02 and absf(q7_h_alf - 0.875) < 0.02)
	# PI transfer (Vey), the extraction's half (Remy), the Cartographer's stripped PI and half-blank page
	var q7_v1 := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("okafor:2"))
	var q7_v1_ok: bool = q7_v1._transfer_dialect() == "tremblay" and q7_v1.pi_vs() == 0 and absf(q7_v1._tell_mult() - 1.0) < 0.001
	quiet(q7_v1); thaw(q7_v1); q7_v1.B["comp"] = q7_v1.B["comp_max"] * 0.65; q7_v1.bstate = "IDLE"; q7_v1.btimer = 1 << 30; q7_v1.step({})
	var q7_v2_ok: bool = q7_v1.bphase == 2 and q7_v1._transfer_dialect() == "okafor" and q7_v1.pi_vs() == 2 and absf(q7_v1.pi_effect_scale() - 0.5) < 0.001 and absf(q7_v1._tell_mult() - 1.05) < 0.001 and absf(q7_v1.pi_read_bonus() - 0.05) < 0.001 and q7_v1.pi_cue()
	q7_v1.B["comp"] = q7_v1.B["comp_max"] * 0.35; q7_v1.bstate = "IDLE"; q7_v1.btimer = 1 << 30; q7_v1.step({})
	var q7_v3_ok: bool = q7_v1.bphase == 3 and q7_v1._transfer_dialect() == "kowalchuk" and q7_v1.pi_vs() == 0
	var q7_vt := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("tremblay:2"))
	var q7_vp := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("petrov:2"))
	var q7_vt_ok: bool = q7_vt.pi_vs() == 2 and absf(q7_vt._tell_mult() - 1.05) < 0.001 and q7_vp.pi_vs() == 2 and absf(q7_vp._tell_mult() - 1.1) < 0.001 and absf(q7_vp.pi_effect_scale() - 1.0) < 0.001
	var q7_re := make_sim(20, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("moreau:2"))
	var q7_jg := make_sim(2, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("moreau:2"))
	var q7_re_ok: bool = q7_re.pi_vs() == 2 and absf(q7_re._tell_mult() - 1.05) < 0.001 and q7_jg.pi_vs() == 2 and absf(q7_jg._tell_mult() - 1.1) < 0.001
	var q7_hc := make_sim(13, 7, TNBSim.LINEUP_MILLBROOK, "", pi_ledger.call("hc4_cartographer:3"))
	var q7_hc0: bool = q7_hc.pi_vs() == 0 and not q7_hc.pi_cue() and absf(q7_hc._tell_mult() - 1.0) < 0.001 and count_events(q7_hc.events, "commentary") == 0
	var q7_hc2 := make_sim(13, 7); quiet(q7_hc2); q7_hc2.ep_p = 6; q7_hc2._end_segment("clock")
	var q7_pg: Dictionary = q7_hc2.scout_page("hc4_cartographer")
	var q7_hc_pg: bool = q7_pg.size() > 0 and bool(q7_pg["half_blank"]) and q7_pg["tells"].is_empty() and q7_pg["strings"].is_empty() and q7_pg["phases"].size() == 2
	_sr("PI transfer: against Vey's Out-Boxer / Frost kit a Tremblay ledger applies, against his Swarmer / Gale kit an Okafor one (PI 2 at half: the tell x1.05, the read bonus 0.05, the cue on), against his Slugger / Granite kit a Kowalchuk one; his own Petrov PI applies in full (x1.10); Remy's extraction half-transfers Moreau PI (x1.05) where Jean-Guy takes it whole (x1.10); the Cartographer strips PI (a PI 3 ledger reads 0) and his page is half-blank - phases and hooks, no tells, no string names",
		q7_v1_ok and q7_v2_ok and q7_v3_ok and q7_vt_ok and q7_re_ok and q7_hc0 and q7_hc_pg)
	# Deshawn's no idle weight, Reyes' body doctrine
	var q7_de := make_sim(10, 7); quiet(q7_de)
	var q7_de1: int = q6_recover.call(q7_de, "S1"); var q7_de2: int = q6_recover.call(q7_de, "S2")
	var q7_ry := make_sim(17, 7); quiet(q7_ry)
	for q7_i in 40: q6_recover.call(q7_ry, "S2")
	var q7_body: int = count_events(q7_ry.events, "boss_act", {"verb": "punch", "body": true}); var q7_head: int = count_events(q7_ry.events, "boss_act", {"verb": "punch", "body": false})
	var q7_va := make_sim(0, 7); quiet(q7_va)
	for q7_i in 20: q6_recover.call(q7_va, "S1")
	var q7_va_body: int = count_events(q7_va.events, "boss_act", {"verb": "punch", "body": true})
	_sr("Deshawn has no idle weight: %d / %d ticks between strings (150ms, no roll); Reyes' target split sends her elbow cross to the body %d of %d times (80 / 20 on a head verb) where Vane's jabs go to the body %d of 60 times" % [q7_de1, q7_de2, q7_body, q7_body + q7_head, q7_va_body],
		q7_de1 == TNBSim.ms(150) and q7_de2 == TNBSim.ms(150) and q7_body + q7_head == 40 and q7_body >= 26 and q7_va_body == 0)
	# Osei's stolen secret at 70% with the stumble; Baro's Graduacion only after Examen lands
	var q7_secret := func(power: float) -> Dictionary:
		var q := make_sim(11, 7); quiet(q); thaw(q); place(q, 1.2); clear_defense(q.P); q.P["comp"] = q.P["comp_max"]; q.P["stamina"] = 100.0
		q.bmods["secret_power"] = power
		q.B["comp"] = q.B["comp_max"] * 0.2; q.bstate = "IDLE"; q.btimer = 1 << 30; q.bsurvival_used = true; q.events.clear()
		var q_n := 0
		while count_events(q.events, "cast_done") == 0 and q_n < 1200: q.step({}); q_n += 1
		var dmg := 0.0
		for q_e in q.events:
			if q_e["kind"] == "hit" and q_e["on"] == "P" and q_e.get("hissatsu", false): dmg += float(q_e.get("dmg", 0.0))
		return {"dmg": dmg, "stumble": count_events(q.events, "stumble", {"power": power}), "open": int(q.B["guard_open_t"]), "cast": count_events(q.events, "cast", {"who": "B"})}
	var q7_s7: Dictionary = q7_secret.call(0.7); var q7_s10: Dictionary = q7_secret.call(1.0)
	var q7_ba := make_sim(23, 7); quiet(q7_ba); thaw(q7_ba); place(q7_ba, 1.4); q7_ba.bsurvival_used = true
	q7_ba.B["comp"] = q7_ba.B["comp_max"] * 0.2; q7_ba.bstate = "IDLE"; q7_ba.btimer = 1 << 30; q7_ba.events.clear(); q7_ba.step({})
	var q7_ba_held: bool = count_events(q7_ba.events, "cast", {"who": "B"}) == 0 and not q7_ba.bdesp_used and not q7_ba._desperation_allowed()
	clear_defense(q7_ba.P); q7_ba.P["blocking"] = false; q7_ba.P["block_t"] = 0
	freeze_boss(q7_ba); thaw(q7_ba); place(q7_ba, 1.3); q7_ba.bstate = "TELL"; q7_ba.bstring = "S3"; q7_ba.btimer = 1; q7_ba.bforce_opts = {}; q7_ba.bfeint = ""
	var q7_n := 0
	while int(q7_ba.blanded.get("S3", 0)) == 0 and q7_n < 900: q7_ba.step({}); q7_n += 1
	var q7_ba_landed: bool = int(q7_ba.blanded.get("S3", 0)) >= 1 and q7_ba._desperation_allowed()
	freeze_boss(q7_ba); thaw(q7_ba); q7_ba.B["comp"] = q7_ba.B["comp_max"] * 0.2; q7_ba.bstate = "IDLE"; q7_ba.btimer = 1 << 30; q7_ba.events.clear(); q7_ba.step({})
	var q7_ba_fires: bool = count_events(q7_ba.events, "cast", {"who": "B"}) == 1 and q7_ba.bdesp_used
	_sr("Osei's Deep Roots lands %.1f at 70%% against %.1f at full (%.2f) and she stumbles on the exit - OPEN %d ticks; Baro at 20%% holds Graduacion while Examen has not landed, casts it once it has" % [q7_s7["dmg"], q7_s10["dmg"], float(q7_s7["dmg"]) / maxf(0.1, float(q7_s10["dmg"])), int(q7_s7["open"])],
		int(q7_s7["cast"]) == 1 and int(q7_s10["cast"]) == 1 and float(q7_s10["dmg"]) > 0.0 and absf(float(q7_s7["dmg"]) / maxf(0.1, float(q7_s10["dmg"])) - 0.7) < 0.03 and int(q7_s7["stumble"]) == 1 and int(q7_s7["open"]) == TNBSim.ms(500) and q7_ba_held and q7_ba_landed and q7_ba_fires)
	# Cal's corner assist; Vasile's corner intel
	var q7_cal := make_sim(9, 7); q7_cal.hooks_enabled = false; q7_cal.coach_on = false; place(q7_cal, 1.6); q7_cal.bstate = "IDLE"; q7_cal.btimer = 1; q7_cal.events.clear()
	q7_n = 0
	while count_events(q7_cal.events, "tell") == 0 and q7_n < 600: q7_cal.step({}); q7_n += 1
	var q7_assist := ""
	for q7_e in q7_cal.events:
		if q7_e["kind"] == "tell": q7_assist = str(q7_e.get("assist", "")); break
	var q7_vs := make_sim(16, 7); quiet(q7_vs); thaw(q7_vs); q7_vs.events.clear()
	q7_vs.clock_t = TNBSim.ms(90000) - TNBSim.ms(27900); q7_vs.bstate = "IDLE"; q7_vs.btimer = 1 << 30; q7_vs.step({})
	var q7_vs_early: bool = count_events(q7_vs.events, "corner_call") == 0
	q7_vs.clock_t = TNBSim.ms(90000) - TNBSim.ms(28000); q7_vs.step({})
	var q7_vs_call: bool = count_events(q7_vs.events, "corner_call", {"phase": 2, "kit": "granite"}) == 1 and q7_vs.bphase == 1
	q7_vs.clock_t = TNBSim.ms(90000) - TNBSim.ms(58000); q7_vs.step({})
	var q7_vs_call2: bool = count_events(q7_vs.events, "corner_call", {"phase": 3, "kit": "gale"}) == 1 and count_events(q7_vs.events, "corner_call") == 2
	var q7_vy := make_sim(6, 7); quiet(q7_vy); thaw(q7_vy); q7_vy.events.clear(); q7_vy.B["comp"] = q7_vy.B["comp_max"] * 0.65; q7_vy.bstate = "IDLE"; q7_vy.btimer = 1 << 30; q7_vy.step({})
	_sr("Cal's corner assist: every tell of his is called by name (%s); Vasile's corner intel: Vey calls the Granite kit at 28s (not at 27.9), the Gale kit at 58s, two calls in all - and calls nothing for Vey's composure phases" % q7_assist,
		q7_assist.begins_with("Whitlock: ") and q7_vs_early and q7_vs_call and q7_vs_call2 and count_events(q7_vy.events, "corner_call") == 0)

	# ================= PAC-068: the reward economy (NP_11 z6, NP_02 z2/z4, NP_08 z2.4/z5) ======
	var q8_eco: Dictionary = content["economy"]
	var q8_hl := func(v: float) -> int: return int(round(v * float(q8_eco["xp"].get("pace", 1.0))))     # RORY / PRIYA / MARCUS / JUNE are houseless: +10% (NP_07 s5); since PAC-098 every payment x the pace
	# the data, the ledger's shape, the level curve
	var q8a := make_sim(1, 7)
	var q8_shape: bool = q8a.ECO.size() > 0 and q8a.rewards["xp"].is_empty() and int(q8a.rewards["spirits"]) == 0 and int(q8a.rewards["prestige"]) == 0 and int(q8a.rewards["hbp"]) == 0 and q8a.rewards["kizuna"].is_empty() and q8a.level_of("RORY") == 1
	q8a.rewards["xp"]["X"] = 4800; var q8_l10: int = q8a.level_of("X")
	q8a.rewards["xp"]["X"] = 119999; var q8_l49: int = q8a.level_of("X")
	q8a.rewards["xp"]["X"] = 120000; var q8_l50: int = q8a.level_of("X")
	q8a.rewards["xp"]["X"] = 400000; var q8_lcap: int = q8a.level_of("X")
	_sr("the economy as data: a fresh ledger is empty (level 1 at 0 XP); the level curve is NP_11 s2's quadratic-gentle (48 L^2): 4,800 XP -> level %d, 119,999 -> %d, 120,000 -> %d, 400,000 -> %d (cap 50)" % [q8_l10, q8_l49, q8_l50, q8_lcap],
		q8_shape and q8_l10 == 10 and q8_l49 == 49 and q8_l50 == 50 and q8_lcap == 50)
	# XP is continuous: the fight's events earn it, the segment's end credits it with the houseless +10%
	var q8b := make_sim(1, 7); quiet(q8b); place(q8b, 1.4)
	throw_clean(q8b, "L_STRAIGHT"); throw_clean(q8b, "L_STRAIGHT")
	var q8_two: int = q8b.seg_xp
	thaw(q8b); place(q8b, 1.4); q8b.P["busy_t"] = 0; q8b.P["cmd"] = {}; q8b.P["counter_t"] = 60; q8b.step({"punch": "R_STRAIGHT"}); clear_defense(q8b.B); land(q8b); q8b.step({})
	var q8_ctr: int = q8b.seg_xp
	thaw(q8b); place(q8b); q8b.B["comp"] = 1.0; throw_clean(q8b, "R_UPPERCUT")
	var q8_drop: int = q8b.seg_xp
	q8b.ep_p = 6; q8b._end_segment("clock")
	var q8_seg_xp: int = q8b.xp_of("RORY")
	var q8b2 := make_sim(1, 7); quiet(q8b2); place(q8b2, 1.4); throw_clean(q8b2, "L_STRAIGHT"); q8b2.ep_b = 6; q8b2._end_segment("clock")
	_sr("XP from the fight itself: two clean hits %d, a counter makes %d, a DROP scored %d; the segment won credits (%d + 25) x1.10 x the pace = %d to RORY (houseless +10%%) with an xp event; a segment lost credits the events alone (%d)" % [q8_two, q8_ctr, q8_drop, q8_drop, q8_seg_xp, q8b2.xp_of("RORY")],
		q8_two == 2 and q8_ctr == 4 and q8_drop == 15 and q8_seg_xp == q8_hl.call((15.0 + 25.0) * 1.1) and count_events(q8b.events, "xp", {"who": "RORY", "why": "R1"}) == 1 and q8b2.xp_of("RORY") == q8_hl.call(1.0 * 1.1) and q8b.seg_xp == 0)
	# the scrap pays: an XP trickle and Prestige by tier, the toast, the PI tick named when it rises
	var q8c := make_sim(1, 7)
	var q8_toasts: Array = []
	for q8_i in 3:
		q8c.start_scrap("SCR-01", 1); q8c.obj["met"] = true; q8c.obj["why"] = "objective"; q8c._end_bout()
		q8_toasts.append(str(q8c.last_toast.get("text", "")))
	var q8_tier1 := mini(int(q8_eco["prestige"]["cap"]), int(q8_eco["prestige"]["scrap_base"]) + int(q8_eco["prestige"]["per_tier"]) * int(q8c.SCRAPS["SCR-01"]["tier"]))
	var q8_scrap_ok: bool = q8c.xp_of("RORY") == 3 * q8_hl.call(15.0 * 1.1) and int(q8c.rewards["prestige"]) == 3 * q8_tier1 and q8_toasts[0] == "SCRAP: %d XP, +%d Prestige" % [q8_hl.call(15.0 * 1.1), q8_tier1] and q8_toasts[2].ends_with(", PI tick vs Kowalchuk") and not q8_toasts[1].ends_with("Kowalchuk") and count_events(q8c.events, "reward_toast", {"size": "scrap", "won": true}) == 3
	q8c.start_scrap("SCR-11", 1); q8c.obj["failed"] = true; q8c.obj["why"] = "you blocked"; q8c._end_bout()
	var q8_lost_ok: bool = q8c.xp_of("RORY") == 3 * q8_hl.call(15.0 * 1.1) + q8_hl.call(5.0 * 1.1) and int(q8c.rewards["prestige"]) == 3 * q8_tier1 and bool(q8c.last_toast["won"]) == false
	q8c.start_scrap("SCR-23", 1); q8c.obj["met"] = true; q8c._end_bout()
	var q8_tier3 := mini(int(q8_eco["prestige"]["cap"]), int(q8_eco["prestige"]["scrap_base"]) + int(q8_eco["prestige"]["per_tier"]) * int(q8c.SCRAPS["SCR-23"]["tier"]))
	var q8_t3_ok: bool = int(q8c.last_toast["prestige"]) == q8_tier3 and q8_tier3 == 3 and int(q8c.rewards["prestige"]) == 3 * q8_tier1 + q8_tier3
	_sr("the scrap pays: SCR-01 won three times - %d XP each and +%d Prestige (tier 1: NP_12A's '+2 Prestige'), the third toast naming the PI tick (%s); a scrap lost pays the trickle (%d) and no Prestige; a tier-3 objective pays +%d at the cap" % [q8_hl.call(15.0 * 1.1), q8_tier1, q8_toasts[2], q8_hl.call(5.0 * 1.1), q8_tier3],
		q8_scrap_ok and q8_lost_ok and q8_t3_ok)
	# the spar pays: full XP and Spirits; won adds the bonus and HBP; the tell-highlight lab halves the XP; a stablemate partner bonds, capped per day
	var q8d := make_sim(1, 7); q8d.start_spar(1); q8d.ep_b = 3; q8d._end_bout()
	var q8_spar_lost: bool = q8d.xp_of("RORY") == q8_hl.call(40.0 * 1.1) and int(q8d.rewards["spirits"]) == int(q8_eco["spirits"]["spar_fought"]) and int(q8d.rewards["hbp"]) == 0 and str(q8d.last_toast["text"]) == "SPAR: %d XP, %d Spirits, PI tick vs Kowalchuk" % [q8_hl.call(40.0 * 1.1), int(q8_eco["spirits"]["spar_fought"])]
	var q8e := make_sim(1, 7); q8e.start_spar(1); q8e.ep_p = 3; q8e._end_bout()
	var q8_spar_won: bool = q8e.xp_of("RORY") == q8_hl.call(60.0 * 1.1) and int(q8e.rewards["spirits"]) == int(q8_eco["spirits"]["spar_won"]) and int(q8e.rewards["hbp"]) == int(q8_eco["hbp"]["spar_won"])
	var q8f := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities({}, "ring:1", content["facilities"])); q8f.start_spar(1, ["tell_highlight"]); q8f.ep_b = 3; q8f._end_bout()   # since PAC-089 the lab is The Ring's T1
	var q8_lab: bool = q8f.xp_of("RORY") == q8_hl.call(40.0 * 1.1 * 0.5)
	var q8_mate := {"name": "PRIYA", "style": "OUTBOXER", "element": "GALE", "house": "none", "stablemate": true, "stats": {"PWR": 35, "SPD": 60, "CHN": 40, "RFX": 70, "BLK": 50, "STA": 55, "HRT": 60}}
	var q8g := make_sim(0, 7)
	var q8_kz: Array = []
	for q8_i in 6:
		q8g.start_spar(0, [], q8_mate); q8g.ep_b = 3; q8g._end_bout(); q8_kz.append(q8g.kizuna_pts("RORY", "PRIYA"))
	var q8_first_toast_kz: bool = ", RORY+PRIYA +3" in str(q8g.rewards["log"][0])
	q8g.new_day(); q8g.start_spar(0, [], q8_mate); q8g.ep_b = 3; q8g._end_bout()
	_sr("the spar pays: fought to the end %d XP and %d Spirits (the toast says so, and names the PI tick a first spar earns); won %d XP, %d Spirits, %d HBP; the tell-highlight lab pays half (%d); sparring a stablemate bonds +3 a time (%s) to the +15/day soft cap, and a new day pays again (%d)" % [q8_hl.call(40.0 * 1.1), int(q8_eco["spirits"]["spar_fought"]), q8_hl.call(60.0 * 1.1), int(q8_eco["spirits"]["spar_won"]), int(q8_eco["hbp"]["spar_won"]), q8_hl.call(40.0 * 1.1 * 0.5), JSON.stringify(q8_kz), q8g.kizuna_pts("RORY", "PRIYA")],
		q8_spar_lost and q8_spar_won and q8_lab and q8_kz == [3, 6, 9, 12, 15, 15] and q8_first_toast_kz and q8g.kizuna_pts("RORY", "PRIYA") == 18 and count_events(q8g.events, "kizuna_level", {"pair": "PRIYA|RORY", "level": 1, "name": "Gymmates"}) == 1)
	# the dual pays: the closing XP to each fighter, the reserves' 50%, Spirits, HBP, the adjacent slots' bonds
	var q8h := make_sim(1, 7); quiet(q8h)
	for q8_i in 3:
		q8h.ep_p += 6; q8h._end_segment("clock")
		if q8h.mode == "CARD": q8h.corner_pick(0)
		if q8h.mode == "CORNER": q8h.corner_pick(0)
	var q8_seg25: int = q8_hl.call(25.0 * 1.1); var q8_close: int = q8_hl.call(100.0 * 1.1)
	var q8_dual_total: int = 3 * q8_seg25 + 3 * q8_close
	var q8_dual_ok: bool = q8h.mode == "OVER" and q8h.xp_of("RORY") == q8_seg25 + q8_close and q8h.xp_of("PRIYA") == q8_seg25 + q8_close and q8h.xp_of("MARCUS") == q8_seg25 + q8_close \
		and q8h.xp_of("JUNE") == q8_hl.call(round(float(q8_dual_total) * 0.5 / float(q8_eco["xp"].get("pace", 1.0))) * 1.1) and int(q8h.rewards["spirits"]) == int(q8_eco["spirits"]["dual_won"]) and int(q8h.rewards["hbp"]) == int(q8_eco["hbp"]["dual_won"]) \
		and q8h.kizuna_pts("RORY", "PRIYA") == int(q8_eco["kizuna"]["adjacent_slots_win"]) and q8h.kizuna_pts("PRIYA", "MARCUS") == int(q8_eco["kizuna"]["adjacent_slots_win"]) and q8h.kizuna_pts("RORY", "MARCUS") == 0 \
		and count_events(q8h.events, "reward_toast", {"size": "dual", "won": true}) == 1 and str(q8h.last_toast["text"]).begins_with("DUAL: %d XP, %d Spirits, %d HBP, RORY+PRIYA +8, PRIYA+MARCUS +8" % [q8_dual_total, int(q8_eco["spirits"]["dual_won"]), int(q8_eco["hbp"]["dual_won"])])
	var q8i := make_sim(1, 7); quiet(q8i)
	for q8_i in 3:
		q8i.ep_b += 6; q8i._end_segment("clock")
		if q8i.mode == "CARD": q8i.corner_pick(0)
		if q8i.mode == "CORNER": q8i.corner_pick(0)
	var q8_lost_dual: bool = q8i.mode == "OVER" and q8i.xp_of("RORY") == q8_hl.call(40.0 * 1.1) and int(q8i.rewards["spirits"]) == int(q8_eco["spirits"]["dual_fought"]) and int(q8i.rewards["hbp"]) == 0 and q8i.kizuna_pts("RORY", "PRIYA") == int(q8_eco["kizuna"]["adjacent_slots"])
	_sr("the dual pays: three segments won then the verdict - each fighter %d per segment and %d at the close, JUNE on the bench 50%% of the dual's %d (%d), %d Spirits, %d HBP, the adjacent pairs RORY+PRIYA and PRIYA+MARCUS +8 each and RORY+MARCUS nothing; a dual lost pays %d at the close, %d Spirits, no HBP, the pairs +5" % [q8_seg25, q8_close, q8_dual_total, q8h.xp_of("JUNE"), int(q8_eco["spirits"]["dual_won"]), int(q8_eco["hbp"]["dual_won"]), q8_hl.call(40.0 * 1.1), int(q8_eco["spirits"]["dual_fought"])],
		q8_dual_ok and q8_lost_dual)
	# Kizuna levels and their effects in the fight: Corner Voices +2% with a Lv2 bond dressed, Adjacent Trust +5% and the CHARGED threshold 20 beside a Lv3 bond; ALLIED x1.25
	var q8j := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg("RORY+PRIYA:25"))
	var q8_lv2: bool = q8j.kizuna_level("RORY", "PRIYA") == 2 and absf(float(q8j.P["stats"]["PWR"]) - 45.0 * 1.02) < 0.001 and count_events(q8j.events, "kizuna_effect", {"who": "RORY", "stat_pct": 2.0}) == 1 and absf(q8j._charged_threshold() - 25.0) < 0.001
	var q8k := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg("RORY+PRIYA:50"))
	var q8_lv3: bool = q8k.kizuna_level("RORY", "PRIYA") == 3 and absf(float(q8k.P["stats"]["PWR"]) - 45.0 * 1.05) < 0.001 and absf(q8k._charged_threshold() - 20.0) < 0.001
	var q8l := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg("RORY+MARCUS:50"))
	var q8_notadj: bool = q8l.kizuna_level("RORY", "MARCUS") == 3 and absf(float(q8l.P["stats"]["PWR"]) - 45.0 * 1.02) < 0.001 and absf(q8l._charged_threshold() - 25.0) < 0.001
	var q8m := make_sim(1, 7)
	var q8_names: Array = []
	for q8_pts in [9, 10, 25, 50, 90, 150]:
		q8m.rewards["kizuna"] = {"A|B": q8_pts}; q8_names.append(q8m.kizuna_level("A", "B"))
	var q8_allied := [{"name": "K", "style": "SLUGGER", "element": "GRANITE", "house": "kowalchuk", "stats": {"PWR": 50, "SPD": 50, "CHN": 50, "RFX": 50, "BLK": 50, "STA": 50, "HRT": 50}},
		{"name": "W", "style": "SWARMER", "element": "FROST", "house": "whitecloud", "stats": {"PWR": 50, "SPD": 50, "CHN": 50, "RFX": 50, "BLK": 50, "STA": 50, "HRT": 50}},
		{"name": "N", "style": "OUTBOXER", "element": "GALE", "house": "none", "stats": {"PWR": 50, "SPD": 50, "CHN": 50, "RFX": 50, "BLK": 50, "STA": 50, "HRT": 50}}]
	var q8n := make_sim(1, 7, q8_allied); quiet(q8n)
	var q8_al: int = q8n._pay_kizuna("K", "W", 5, false, "test"); var q8_nal: int = q8n._pay_kizuna("K", "N", 5, false, "test")
	_sr("Kizuna: at 25 pts RORY & PRIYA are Corner Voices (Lv2) and RORY fights at +2%% stats with her dressed; at 50 Adjacent Trust (Lv3) - RORY in R1 beside PRIYA in R2 fights at +5%% and CHARGES at 20; RORY & MARCUS at Lv3 are not adjacent (R1 / R3): +2%% and 25; the levels by the thresholds %s; an ALLIED pair (Kowalchuk & Whitecloud) bonds x1.25 (%d for 5) where an unallied one takes %d" % [JSON.stringify(q8_names), q8_al, q8_nal],
		q8_lv2 and q8_lv3 and q8_notadj and q8_names == [0, 1, 2, 3, 4, 5] and q8_al == 6 and q8_nal == 5)
	# the level-up event; the ledger rides and hashes
	var q8o := make_sim(1, 7); q8o.rewards["xp"]["RORY"] = 4780; quiet(q8o); q8o.ep_p = 6; q8o._end_segment("clock")
	var q8_lu: bool = q8o.level_of("RORY") == 10 and count_events(q8o.events, "level_up", {"who": "RORY", "level": 10}) == 1
	var q8p := make_sim(1, 7); q8p.start_scrap("SCR-01", 1); q8p.obj["met"] = true; q8p._end_bout(); q8p.end_bout(); q8p.new_dual()
	var q8_kept: bool = q8p.xp_of("RORY") == q8_hl.call(15.0 * 1.1) and int(q8p.rewards["prestige"]) == q8_tier1
	var q8q := make_sim(1, 99, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg("RORY+PRIYA:25")); var q8r := make_sim(1, 99, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg("RORY+PRIYA:25")); var q8s := make_sim(1, 99)
	_sr("a segment's XP carries RORY from 4,780 past 4,800: level 10, a level_up event; the ledger rides through end_bout and new_dual, and two sims differ in hash by the reward ledger alone",
		q8_lu and q8_kept and q8q.hash_state() == q8r.hash_state() and q8q.hash_state() != q8s.hash_state())

	# ================= PAC-069: the save (NP_11 z9) - a SaveGame from the ledgers, a DualState of the dual in flight ======
	# the record: every schema key; the stable's cards with level / xp / bonds from the ledgers; the currencies; the Scout Book; the remixes; the sim untouched by the writing
	var q9a := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", TNBSim.parse_pi_arg("kowalchuk:2,yuri_kowalchuk:3", content["pattern_intel"]), TNBSim.parse_kizuna_arg("RORY+PRIYA:25"))
	q9a.rewards["xp"]["RORY"] = 4808; q9a.rewards["spirits"] = 5; q9a.rewards["prestige"] = 4; q9a.rewards["hbp"] = 20
	q9a.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch")
	var q9_h_before: int = q9a.hash_state()
	var q9_rec: Dictionary = TNBSave.to_save(q9a)
	var q9_missing: Array = []
	for q9_k in ["calendar", "story_flags", "stable", "staff", "club", "currencies", "scout_book", "string_wall", "gym_wall", "house_codex", "feud_graph_state", "hybrid_registry", "settings"]:
		if not q9_rec.has(q9_k): q9_missing.append(q9_k)
	var q9_rory: Dictionary = q9_rec["stable"][0]
	var q9_rec_ok: bool = q9_missing.is_empty() and str(q9_rec["schema"]) == TNBSave.SAVE_SCHEMA and q9_rec["stable"].size() == 4 and str(q9_rory["name"]) == "RORY" and int(q9_rory["level"]) == 10 and int(q9_rory["xp"]) == 4808 \
		and q9_rory["bonds"] == [{"fighter_id": "PRIYA", "kizuna": 25, "level": 2}] and q9_rory["house_id"] == null and q9_rory["technique_slots"] == ["Aurora Borealis Breaker"] and bool(q9_rec["stable"][3]["reserve"]) \
		and q9_rec["currencies"] == {"spirits": 5, "prestige": 4, "hbp": 20, "beans": 0} and q9_rec["scout_book"]["pi_map"] == q9a.pi and q9_rec["scout_book"]["pages"].size() == 1 and str(q9_rec["scout_book"]["pages"][0]["boss"]) == "yuri_kowalchuk" \
		and q9_rec["remixes"] == {"yuri_kowalchuk": "yuri_kowalchuk.rematch"} and str(q9_rec["settings"]["format"]) == "mini" and int(q9_rec["settings"]["boss"]) == 1 and int(q9_rec["calendar"]["day"]) == 1 and q9_rec["ledgers"]["rewards"] == q9a.rewards \
		and q9a.hash_state() == q9_h_before
	_sr("the SaveGame (NP_11 s9) from the ledgers: every schema key%s; RORY level %d at %d XP with bonds %s, JUNE a reserve; currencies %s; the Scout Book's pi_map is the PI ledger with %d page (%s); the remix set; format %s, boss %d, day %d; writing it leaves the sim's hash alone" % [(" (missing " + JSON.stringify(q9_missing) + ")") if q9_missing.size() > 0 else "", int(q9_rory["level"]), int(q9_rory["xp"]), JSON.stringify(q9_rory["bonds"]), JSON.stringify(q9_rec["currencies"]), q9_rec["scout_book"]["pages"].size(), str(q9_rec["scout_book"]["pages"][0]["boss"]) if q9_rec["scout_book"]["pages"].size() > 0 else "-", str(q9_rec["settings"]["format"]), int(q9_rec["settings"]["boss"]), int(q9_rec["calendar"]["day"])],
		q9_rec_ok)
	# the round trip: text -> read -> a sim built from it -> text again, byte-equal; the ledgers equal and typed; the remix live from the bell; a ledger-less sim differs
	var q9_text: String = TNBSave.write_text(q9a, false)
	var q9_rd: Dictionary = TNBSave.read_text(q9_text)
	var q9_b: Dictionary = TNBSave.build(content, q9_rd, 7)
	var q9b = q9_b["sim"]
	var q9_text2: String = TNBSave.write_text(q9b, false)
	var q9_rt_ok: bool = bool(q9_rd["ok"]) and q9_text2 == q9_text and q9b.pi == q9a.pi and q9b.rewards == q9a.rewards and q9b.remix_for == q9a.remix_for and q9b.dressed == q9a.dressed and str(q9b.fmt["id"]) == "mini" and q9b._first_boss == 1 \
		and q9b.level_of("RORY") == 10 and q9b.kizuna_level("RORY", "PRIYA") == 2 and str(q9b.bremix.get("id", "")) == "yuri_kowalchuk.rematch" and q9_b["restored"].is_empty() and q9_rd["dual"].is_empty() \
		and typeof(q9b.rewards["xp"]["RORY"]) == TYPE_INT and typeof(q9b.pi["dialects"]["kowalchuk"]["scraps"]) == TYPE_INT and typeof(q9b.dressed[0]["stats"]["PWR"]) == TYPE_INT and q9b.hash_state() != make_sim(1, 7).hash_state()
	_sr("the round trip: the text (%d bytes) read and built into a new sim writes back byte-equal; the PI and reward ledgers equal with their ints (a JSON float comes back the int it was); the four cards dressed; Yuri's rematch live from the bell; no dual beneath a save written between fights" % q9_text.length(),
		q9_rt_ok)
	# the ledgers through a real fight: three scraps won, a stablemate spar, a segment won (Yuri beaten, his page), a new day; saved, built, equal
	var q9c := make_sim(1, 7)
	for q9_i in 3:
		q9c.start_scrap("SCR-01", 1); q9c.obj["met"] = true; q9c.obj["why"] = "objective"; q9c._end_bout()
	q9c.start_spar(1, [], q8_mate); q9c.ep_p = 3; q9c._end_bout(); q9c.end_bout()
	quiet(q9c); q9c.ep_p = 6; q9c._end_segment("clock")
	q9c.new_day()
	var q9_rd3: Dictionary = TNBSave.read_text(TNBSave.write_text(q9c, false))
	var q9d = TNBSave.build(content, q9_rd3, 7)["sim"]
	var q9_rec3: Dictionary = TNBSave.to_save(q9d)
	var q9_fight_ok: bool = q9d.pi == q9c.pi and q9d.rewards == q9c.rewards and q9d.pi_level("kowalchuk") == q9c.pi_level("kowalchuk") and q9c.pi_level("kowalchuk") >= 1 and q9d.pi_boss("yuri_kowalchuk") == 3 and q9d.xp_of("RORY") == q9c.xp_of("RORY") and q9c.xp_of("RORY") > 0 \
		and q9d.kizuna_pts("RORY", "PRIYA") == 3 and int(q9d.rewards["day"]) == 2 and q9d.rewards["kizuna_day"].is_empty() and int(q9d.rewards["prestige"]) == 6 \
		and q9_rec3["scout_book"]["pages"].size() == 1 and q9_rec3["stable"][0]["bonds"] == [{"fighter_id": "PRIYA", "kizuna": 3, "level": 0}] and int(q9_rec3["calendar"]["day"]) == 2 and int(q9_rec3["currencies"]["prestige"]) == 6
	_sr("the ledgers through a fight: three scraps won, a stablemate spar, R1 won on EP (Yuri beaten), a new day - saved and built: PI %d vs Kowalchuk and Yuri's page, RORY %d XP, RORY+PRIYA %d, %d Prestige, day %d with the daily cap cleared" % [q9d.pi_level("kowalchuk"), q9d.xp_of("RORY"), q9d.kizuna_pts("RORY", "PRIYA"), int(q9d.rewards["prestige"]), int(q9d.rewards["day"])],
		q9_fight_ok)
	# the DualState: the scripted log to tick 3,000, a snapshot, a sim with nothing in common restored to it: the same hash; both continued 2,000 ticks, every hash the unbroken run's
	var q9_log: Array = build_log(5000, 4242)
	var q9A := make_sim(1, 12345); var q9_hA: Array = []
	var q9_stamp0: int = q9A.content_stamp()
	for q9_i in 5000:
		if q9_i % 100 == 0: q9_hA.append(q9A.hash_state())
		q9A.step(q9_log[q9_i])
	var q9B := make_sim(1, 12345)
	for q9_i in 3000: q9B.step(q9_log[q9_i])
	var q9_h_pre: int = q9B.hash_state()
	var q9_snap: Dictionary = q9B.snapshot()
	var q9_h3000: int = q9B.hash_state()
	var q9_dsB: Dictionary = q9B.dual_state()
	var q9C := make_sim(3, 999, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q9_res: Dictionary = q9C.restore(q9_snap)
	var q9_dsC: Dictionary = q9C.dual_state()
	var q9_hC: Array = []; var q9_hB: Array = []
	for q9_i in range(3000, 5000):
		if q9_i % 100 == 0: q9_hC.append(q9C.hash_state()); q9_hB.append(q9B.hash_state())
		q9C.step(q9_log[q9_i]); q9B.step(q9_log[q9_i])
	var q9_cont_ok: bool = bool(q9_res["ok"]) and bool(q9_res["same"]) and int(q9_res["hash"]) == q9_h3000 and q9_h3000 == q9_h_pre and q9_h3000 == q9_hA[30] and q9_hC == q9_hA.slice(30) and q9_hB == q9_hA.slice(30) and q9C.hash_state() == q9B.hash_state() and q9C.hash_state() == q9A.hash_state() \
		and q9C.tick == 5000 and str(q9C.fmt["id"]) == "mini" and q9C.dressed.size() == 4 and q9C.rng.state == q9B.rng.state
	_sr("the DualState: a snapshot at tick 3,000 (%d KB) restored into a sim built on another boss, seed, roster and format lands on the same hash (%s), the saved sim untouched; both run the log to 5,000 and every one of the %d hashes is the unbroken run's" % [str(q9_snap["state"]).length() / 1024, str(int(q9_res["hash"])), q9_hC.size()],
		q9_cont_ok)
	# the readable DualState fields are the sim's, and the restored sim reads the same
	var q9_fields_ok: bool = int(q9_snap["segment_idx"]) == int(q9_dsB["segment_idx"]) and int(q9_snap["clock_t"]) == int(q9_dsB["clock_t"]) and q9_snap["score"] == q9_dsB["score"] and q9_snap["tension"] == q9_dsB["tension"] and q9_snap["relay"] == q9_dsB["relay"] \
		and q9_snap["lineups"] == q9_dsB["lineups"] and q9_snap["corner_budget"] == q9_dsB["corner_budget"] and q9_snap["tactics_cooldowns"] == q9_dsB["tactics_cooldowns"] and q9_snap["supers_used"] == q9_dsB["supers_used"] and q9_snap["zone_states"] == q9_dsB["zone_states"] \
		and q9_snap["adaptation"] == q9_dsB["adaptation"] and q9_snap["crowd_heat"] == q9_dsB["crowd_heat"] and q9_snap["condition"] == q9_dsB["condition"] and q9_snap["injuries"] == [] and q9_dsC == q9_dsB and str(q9_snap["schema"]) == TNBSim.DUAL_SCHEMA and int(q9_snap["tick"]) == 3000 \
		and q9_dsB["lineups"]["sealed"] == ["RORY", "PRIYA", "MARCUS"] and q9_dsB["lineups"]["revealed"].size() == int(q9_dsB["segment_idx"]) and str(q9_dsB["opponent"]) != "" and q9_dsB["adaptation"]["window"] is Array and q9_dsB["adaptation"]["flags"] is Dictionary
	_sr("the DualState's fields read as NP_11 s9 names them - segment %d, clock %.1fs, score %s, tension %s, relay %s, lineups sealed / revealed %s / %s, the corner budget, cooldowns, supers, zones %s, the adaptation window and flags, crowd heat, condition - and the restored sim reads identically" % [int(q9_dsB["segment_idx"]), float(q9_dsB["clock_s"]), JSON.stringify([q9_dsB["score"]["drops_h"], q9_dsB["score"]["drops_a"]]), JSON.stringify([snappedf(float(q9_dsB["tension"]["home"]), 0.1), snappedf(float(q9_dsB["tension"]["away"]), 0.1)]), JSON.stringify(q9_dsB["relay"]), JSON.stringify(q9_dsB["lineups"]["sealed"]), JSON.stringify(q9_dsB["lineups"]["revealed"]), JSON.stringify(q9_dsB["zone_states"])],
		q9_fields_ok)
	# refusals, each naming why: an older SaveGame schema; a snapshot made under other content; one from another build of the sim; a blob that is not a state; an older DualState schema - and the sim they were refused into untouched
	var q9_old := q9_text.replace(TNBSave.SAVE_SCHEMA, "SaveGame/NP_11-s9/v0.9")
	var q9_rd_old: Dictionary = TNBSave.read_text(q9_old)
	var q9_snap_other: Dictionary = q9_snap.duplicate(true); q9_snap_other["content"] = 12345
	var q9_snap_build: Dictionary = q9_snap.duplicate(true); q9_snap_build["vars"] = 1
	var q9_snap_bad: Dictionary = q9_snap.duplicate(true); q9_snap_bad["state"] = Marshalls.raw_to_base64(var_to_bytes(5))
	var q9_snap_schema: Dictionary = q9_snap.duplicate(true); q9_snap_schema["schema"] = "DualState/NP_11-s9/v0.1"
	var q9E := make_sim(1, 5); var q9_hE: int = q9E.hash_state()
	var q9_r1: Dictionary = q9E.restore(q9_snap_other); var q9_r2: Dictionary = q9E.restore(q9_snap_build); var q9_r3: Dictionary = q9E.restore(q9_snap_bad); var q9_r4: Dictionary = q9E.restore(q9_snap_schema)
	var q9_refuse_ok: bool = not bool(q9_rd_old["ok"]) and "SaveGame/NP_11-s9/v0.9" in str(q9_rd_old["why"]) and TNBSave.SAVE_SCHEMA in str(q9_rd_old["why"]) \
		and not bool(q9_r1["ok"]) and "other content" in str(q9_r1["why"]) and not bool(q9_r2["ok"]) and "another build" in str(q9_r2["why"]) and not bool(q9_r3["ok"]) and "decode" in str(q9_r3["why"]) and not bool(q9_r4["ok"]) and "v0.1" in str(q9_r4["why"]) \
		and q9E.hash_state() == q9_hE and not bool(TNBSave.read({"schema": ""})["ok"]) and not bool(TNBSave.read([1, 2])["ok"])
	_sr("refused, naming why: a SaveGame at v0.9 ('%s'); a DualState under other content ('%s'), from another build, with a blob that is not a state, at v0.1; the sim they were refused into keeps its hash" % [str(q9_rd_old["why"]), str(q9_r1["why"])],
		q9_refuse_ok)
	# the content tables are not state: the stamp is the same after 5,000 ticks and for every sim loaded from the same data
	_sr("the content tables are not state: the content stamp (%d) is the same before and after 5,000 ticks of the log, and the same for every sim loaded from the data - a snapshot carries none of it and restores only under it" % q9_stamp0,
		q9_stamp0 == q9A.content_stamp() and q9A.content_stamp() == q9B.content_stamp() and q9A.content_stamp() == make_sim(0, 1).content_stamp())
	# the file: a dual in flight written to user://, read back, built and restored: the same hash, the log continued in step; a missing file refused
	var q9F := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg("RORY+PRIYA:50"))
	for q9_i in 2500: q9F.step(q9_log[q9_i])
	var q9_hF: int = q9F.hash_state()
	var q9_path := "user://tnb_test_save.json"
	var q9_wrote: bool = TNBSave.write_file(q9_path, q9F, true)
	var q9_kb: int = FileAccess.get_file_as_string(q9_path).length() / 1024 if FileAccess.file_exists(q9_path) else -1
	var q9_rdF: Dictionary = TNBSave.read_file(q9_path)
	var q9_G: Dictionary = TNBSave.build(content, q9_rdF, 1)
	var q9G = q9_G["sim"]
	for q9_i in range(2500, 3000): q9F.step(q9_log[q9_i]); q9G.step(q9_log[q9_i])
	var q9_file_ok: bool = q9_wrote and bool(q9_rdF["ok"]) and bool(q9_G["restored"].get("ok", false)) and bool(q9_G["restored"].get("same", false)) and int(q9_G["restored"].get("hash", 0)) == q9_hF and q9G.hash_state() == q9F.hash_state() and q9G.kizuna_level("RORY", "PRIYA") == 3 and q9G.tick == 3000 \
		and int(q9_rdF["dual"]["segment_idx"]) >= 1 and str(q9_rdF["dual"]["schema"]) == TNBSim.DUAL_SCHEMA and not bool(TNBSave.read_file("user://nothing_here.json")["ok"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(q9_path))
	_sr("the file: a dual in flight at tick 2,500 written to user:// (%d KB), read back, built and restored to hash %d, then run 500 more ticks in step with the sim that wrote it; the bond beneath it kept; a missing file refused" % [q9_kb, q9_hF],
		q9_file_ok)

	# ================= PAC-070: the generic opponent assembler (NP_04 z9) ======
	var q10_pc: Dictionary = content["pieces"]
	var q10_named_labels: Array = []; var q10_named_seqs: Array = []
	for q10_bn in TNBSim.BOSSES:
		for q10_k in content["patterns"][q10_bn]["strings"]:
			q10_named_labels.append(str(content["patterns"][q10_bn]["strings"][q10_k]["label"])); q10_named_seqs.append(JSON.stringify(content["patterns"][q10_bn]["strings"][q10_k]["actions"]))
	# the library: 63 pieces by Style x tier x dialect; every verb parses, every hook has a sensor key; no piece shares a label or an action sequence with a named boss's string; every roster House has a tell dialect
	var q10a := make_sim(1, 7)
	var q10_bad_verbs: Array = []; var q10_shared: Array = []; var q10_labels := {}; var q10_seqs := {}; var q10_per := {}
	for q10_p in q10_pc["strings"]:
		for q10_act in q10_p["actions"]:
			if q10a.parse_action(str(q10_act)).is_empty(): q10_bad_verbs.append(str(q10_act))
		if str(q10_p["label"]) in q10_named_labels or JSON.stringify(q10_p["actions"]) in q10_named_seqs: q10_shared.append(str(q10_p["label"]))
		q10_labels[str(q10_p["label"])] = true; q10_seqs[JSON.stringify(q10_p["actions"])] = true
		var q10_key := "%s:%d" % [str(q10_p["style"]), int(q10_p["tier"])]
		q10_per[q10_key] = int(q10_per.get(q10_key, 0)) + 1
	var q10_shape_ok := true
	for q10_st in ["SWARMER", "OUTBOXER", "SLUGGER", "BOXERPUNCHER"]:
		for q10_t in [1, 2, 3]:
			if int(q10_per.get("%s:%d" % [q10_st, q10_t], 0)) != 3: q10_shape_ok = false
	var q10_bad_hooks: Array = []; var q10_hooks_per := {}
	for q10_h in q10_pc["punish"]:
		if q10a._ev_key(str(q10_h["trigger"])) == "": q10_bad_hooks.append(str(q10_h["id"]))
		q10_hooks_per[str(q10_h["style"])] = int(q10_hooks_per.get(str(q10_h["style"]), 0)) + 1
	var q10_dialects_ok := true; var q10_missing_d: Array = []
	for q10_d in q10_pc["dialects"]:
		var q10_dr: Dictionary = q10_pc["dialects"][q10_d]
		if str(q10_dr.get("channel", "")) == "" or q10_dr.get("motifs", {}).get("normal", []).size() < 3 or q10_dr.get("motifs", {}).get("SPECIAL", []).size() < 1: q10_dialects_ok = false
	for q10_bn in TNBSim.BOSSES:
		var q10_hk := TNBSim.house_key(str(content["patterns"][q10_bn]["meta"].get("house", "none")))
		if q10_hk != "none" and q10_hk != "sealed" and not q10_pc["dialects"].has(q10_hk) and not (q10_hk in q10_missing_d): q10_missing_d.append(q10_hk)
	var q10_count: int = q10_pc["strings"].size() + q10_pc["punish"].size() + q10_pc["dialects"].size()
	_sr("the piece library (NP_04 s9): %d pieces - %d strings (3 per Style per tier), %d punish hooks (3 per Style), %d tell dialects (a channel, 3 motifs, a SPECIAL motif each; every roster House but the sealed one has one%s); every action verb parses, every hook's trigger keys a sensor; no piece shares a label or an action sequence with any of the 24 bosses' 79 strings%s" % [q10_count, q10_pc["strings"].size(), q10_pc["punish"].size(), q10_pc["dialects"].size(), (" - missing " + JSON.stringify(q10_missing_d)) if q10_missing_d.size() > 0 else "", (" - shared: " + JSON.stringify(q10_shared)) if q10_shared.size() > 0 else ""],
		q10_count == 63 and q10_shape_ok and q10_bad_verbs.is_empty() and q10_shared.is_empty() and q10_labels.size() == q10_pc["strings"].size() and q10_seqs.size() == q10_pc["strings"].size() and q10_bad_hooks.is_empty() and q10_hooks_per.size() == 4 and q10_dialects_ok and q10_missing_d.is_empty())
	# the rules, over 48 assemblies (4 Styles x 3 tiers x 4 dialects): 2 strings at tier 1 and 3 above, an opener first, the SPECIAL last at tier 3 and nowhere lower, no piece above the tier; one PUNISH with its placeholders resolved; every tell on the dialect's channel with one of its motifs; SELECT weights the Style's preset; the interrupt block by tier; no bait, phases, desperation or idle; every response known, everything executed under pattern_coverage()
	var q10_all := {}; var q10_rules_ok := true; var q10_why := ""
	var q10_piece_role := {}
	for q10_p in q10_pc["strings"]: q10_piece_role[str(q10_p["id"])] = str(q10_p["role"])
	for q10_st in ["SWARMER", "OUTBOXER", "SLUGGER", "BOXERPUNCHER"]:
		for q10_t in [1, 2, 3]:
			for q10_d in ["kowalchuk", "okafor", "tremblay", "gym"]:
				var q10_spec: Dictionary = q10a.generic_spec("G_%s_%d_%s" % [q10_st, q10_t, q10_d], q10_st, q10_d, q10_t, 11)
				var q10_pat: Dictionary = TNBAssembler.assemble(q10_pc, q10_spec)
				q10_all[str(q10_spec["name"])] = q10_pat
				var q10_n: int = q10_pat["strings"].size()
				var q10_ok: bool = q10_n == (2 if q10_t == 1 else 3) and q10_pat["punish"].size() == 1 and q10_pat["bait"].is_empty() and q10_pat["phases"].is_empty() and q10_pat["desperation"].is_empty() and q10_pat["idle"].is_empty() and bool(q10_pat["meta"]["generic"]) and str(q10_pat["meta"]["style"]) == q10_st and str(q10_pat["meta"]["dialect"]) == q10_d and int(q10_pat["meta"]["tier"]) == q10_t
				var q10_wl: Array = q10_pc["styles"][q10_st]["weights"][str(q10_n)]
				var q10_i := 0
				for q10_k in q10_pat["strings"]:
					var q10_s: Dictionary = q10_pat["strings"][q10_k]
					if str(q10_s["tell"]["channel"]) != str(q10_pc["dialects"][q10_d]["channel"]): q10_ok = false
					if not (str(q10_s["tell"]["motif"]) in q10_pc["dialects"][q10_d]["motifs"][str(q10_s["class"])]): q10_ok = false
					if int(q10_s["tier"]) > q10_t or (str(q10_s["class"]) == "SPECIAL" and q10_t < 3): q10_ok = false
					if int(q10_pat["select"]["weights"][q10_k]) != int(q10_wl[q10_i]): q10_ok = false
					if q10_i == 0 and str(q10_piece_role.get(str(q10_s["piece"]), "")) != "opener": q10_ok = false
					q10_i += 1
				if q10_t == 3 and str(q10_pat["strings"]["S3"]["class"]) != "SPECIAL": q10_ok = false
				var q10_brk: Array = q10_pat["interrupt"][0]["strings"] if q10_pat["interrupt"].size() > 0 else []
				if q10_brk != (["S1", "S2"] if q10_t <= 2 else ["S1"]): q10_ok = false
				if "{" in str(q10_pat["punish"][0]["response"]): q10_ok = false
				if not q10_ok and q10_why == "": q10_why = str(q10_spec["name"])
				q10_rules_ok = q10_rules_ok and q10_ok
	var q10_rc: Dictionary = q10a.response_coverage(q10_all)
	var q10_cov: Dictionary = q10a.pattern_coverage(q10_all)
	var q10_ic: Dictionary = q10a.interrupt_coverage(q10_all)
	var q10_ic_ok := true
	for q10_nm in q10_ic:
		if q10_ic[q10_nm]["breaks"] != q10_all[q10_nm]["interrupt"][0]["strings"]: q10_ic_ok = false
	_sr("the rules over %d assemblies (4 Styles x 3 tiers x 4 dialects): 2 strings at tier 1 and 3 above, an opener first, the SPECIAL last at tier 3 and never lower, no piece over the tier; one PUNISH resolved to the strings assembled (%d responses known, %d unknown); every tell on the dialect's channel with one of its motifs; the Style's preset weights; the interrupt block by tier (all normals / the first two / the opener); nothing carried under pattern_coverage (%d executed META keys, %d carried, %d idle)%s" % [q10_all.size(), int(q10_rc["known"]), q10_rc["unknown"].size(), q10_cov["meta"]["executed"].size(), q10_cov["meta"]["carried"].size() + q10_cov["select"]["carried"].size() + q10_cov["directives"]["carried"].size() + q10_cov["tags"]["carried"].size(), q10_cov["idle"]["carried"].size(), (" - first failure " + q10_why) if q10_why != "" else ""],
		q10_rules_ok and int(q10_rc["known"]) == q10_all.size() and q10_rc["unknown"].is_empty() and q10_cov["meta"]["carried"].is_empty() and q10_cov["select"]["carried"].is_empty() and q10_cov["directives"]["carried"].is_empty() and q10_cov["tags"]["carried"].is_empty() and q10_cov["idle"]["carried"].is_empty() and q10_ic_ok)
	# deterministic from the spec: the same spec twice is the same pattern; eight seeds are several assemblies; a spec without a seed takes its name's
	var q10_sA: Dictionary = q10a.generic_spec("Twin", "SLUGGER", "kowalchuk", 2, 99)
	var q10_pA: Dictionary = TNBAssembler.assemble(q10_pc, q10_sA); var q10_pB: Dictionary = TNBAssembler.assemble(q10_pc, q10_sA)
	var q10_sets := {}
	for q10_seed in range(1, 9):
		var q10_pS: Dictionary = TNBAssembler.assemble(q10_pc, q10a.generic_spec("Seeded", "SLUGGER", "kowalchuk", 2, q10_seed))
		q10_sets[JSON.stringify(q10_pS["meta"]["pieces"]) + JSON.stringify(q10_pS["punish"]) + JSON.stringify(q10_pS["strings"]["S1"]["tell"])] = true
	var q10_named: Dictionary = q10a.generic_spec("Rhubarb", "OUTBOXER", "tremblay", 3)
	var q10_named2: Dictionary = make_sim(3, 99).generic_spec("Rhubarb", "OUTBOXER", "tremblay", 3)
	_sr("deterministic from the spec: the same spec assembles byte-equal twice; eight seeds of one spec give %d distinct assemblies; a spec with no seed takes its name's hash (%d) and assembles the same in another sim" % [q10_sets.size(), int(q10_named["seed"])],
		JSON.stringify(q10_pA) == JSON.stringify(q10_pB) and q10_sets.size() >= 3 and int(q10_named["seed"]) == hash("Rhubarb") and int(q10_named2["seed"]) == int(q10_named["seed"]) and JSON.stringify(TNBAssembler.assemble(q10_pc, q10_named)) == JSON.stringify(TNBAssembler.assemble(q10_pc, q10_named2)))
	# the difficulty knob: tier 1 tells in the Loud band, tier 3 normals Subtle with the SPECIAL at its floor, every tell over its class floor across the 48; the stat block by tier
	var q10_t1: Dictionary = TNBAssembler.assemble(q10_pc, q10a.generic_spec("K1", "SWARMER", "okafor", 1, 5)); var q10_t3: Dictionary = TNBAssembler.assemble(q10_pc, q10a.generic_spec("K3", "SWARMER", "okafor", 3, 5))
	var q10_loud := true; var q10_subtle := true; var q10_floors := true; var q10_sp3 := 0
	for q10_k in q10_t1["strings"]:
		var q10_ms: int = q10_t1["strings"][q10_k]["tell"]["ms"]
		if q10_ms < 600 or q10_ms > 1200: q10_loud = false
	for q10_k in q10_t3["strings"]:
		var q10_ms: int = q10_t3["strings"][q10_k]["tell"]["ms"]
		if str(q10_t3["strings"][q10_k]["class"]) == "SPECIAL": q10_sp3 = q10_ms
		elif q10_ms < 400 or q10_ms > 500: q10_subtle = false
	for q10_nm in q10_all:
		for q10_k in q10_all[q10_nm]["strings"]:
			var q10_s2: Dictionary = q10_all[q10_nm]["strings"][q10_k]
			if int(q10_s2["tell"]["ms"]) < (700 if str(q10_s2["class"]) == "SPECIAL" else 400): q10_floors = false
	var q10_rules: Dictionary = q10_pc["rules"]
	_sr("the knob: tier 1's tells are Loud (%s), tier 3's normals Subtle (%s) with its SPECIAL at %d; tell_ms shifts 450 to 600 / 450 / 400 across the tiers and holds a SPECIAL at 700 under Subtle; every one of the 48 assemblies' tells clears its class floor; the stat block %d at tier 1, %d at tier 3 (a card's stats override)" % [JSON.stringify(q10_t1["strings"].values().map(func(x): return int(x["tell"]["ms"]))), JSON.stringify(q10_t3["strings"].values().map(func(x): return int(x["tell"]["ms"]))), q10_sp3, int(TNBAssembler.default_stats(q10_pc, 1)["PWR"]), int(TNBAssembler.default_stats(q10_pc, 3)["PWR"])],
		q10_loud and q10_subtle and q10_sp3 == 700 and q10_floors and TNBAssembler.tell_ms(q10_rules, 1, "normal", 450.0) == 600 and TNBAssembler.tell_ms(q10_rules, 2, "normal", 450.0) == 450 and TNBAssembler.tell_ms(q10_rules, 3, "normal", 450.0) == 400 and TNBAssembler.tell_ms(q10_rules, 3, "SPECIAL", 700.0) == 700 and int(TNBAssembler.default_stats(q10_pc, 1)["PWR"]) == 40 and int(TNBAssembler.default_stats(q10_pc, 3)["PWR"]) == 70)
	# the sim fights it: a spar against a generic card - he throws his own strings, his hook answers its trigger, his opener breaks to a jab; three scraps won pay the ledger and tick his House's dialect; SCR-09 is refused (no breakable special)
	var q10_card := {"name": "DOCKHAND", "style": "SLUGGER", "element": "GRANITE", "house": "kowalchuk", "generic": true, "tier": 2, "seed": 7, "stats": {"PWR": 55, "SPD": 45, "CHN": 55, "RFX": 45, "BLK": 50, "STA": 55, "HRT": 60}}
	var q10b := make_sim(0, 7); q10b.start_spar(0, [], q10_card)
	var q10_live: bool = str(q10b.bgeneric.get("name", "")) == "DOCKHAND" and bool(q10b.pattern["meta"]["generic"]) and q10b.boss_label == "DOCKHAND" and q10b.B["style"] == "SLUGGER" and q10b.bdialect == "kowalchuk" and q10b.pattern["strings"].size() == 3 and count_events(q10b.events, "generic", {"name": "DOCKHAND"}) == 1 and int(q10b.B["stats"]["PWR"]) == 55
	run_ticks(q10b, 2400, {"block": true})
	var q10_tells := 0; var q10_hits_p := 0
	for q10_e in q10b.events:
		if q10_e["kind"] == "tell" and str(q10_e.get("string", "")) in q10b.pattern["strings"]: q10_tells += 1
		elif q10_e["kind"] == "hit" and str(q10_e.get("on", "")) == "P": q10_hits_p += 1
	var q10c := make_sim(0, 7); q10c.start_spar(0, [], q10_card); quiet(q10c); q10c.hooks_enabled = true; thaw(q10c); q10c.punish_cd = {}; q10c.mode = "FIGHT"
	var q10_pu: Dictionary = q10c.pattern["punish"][0]; q10c._fire_event(str(q10_pu["trigger"]))
	var q10_plan: Dictionary = q10c._parse_response(str(q10_pu["response"]))
	var q10_answered: bool = (q10c.bstate == "TELL" and q10c.bstring == str(q10_plan["string"])) if str(q10_plan["kind"]) == "force" else q10c.bstate == "ACTING"
	freeze_boss(q10c); thaw(q10c); q10c.events.clear(); q10c.hooks_enabled = false
	q10c.P["flash_t"] = 0; q10c._force_string("S1", 1.0, false); place(q10c, 1.4); throw_clean(q10c, "L_STRAIGHT")
	var q10_broke: bool = count_events(q10c.events, "interrupt", {"string": "S1"}) == 1
	var q10d := make_sim(0, 7)
	for q10_i in 3:
		q10d.start_scrap("SCR-01", 0, "", q10_card); q10d.obj["met"] = true; q10d.obj["why"] = "objective"; q10d._end_bout()
	var q10_refused: bool = not q10d.start_scrap("SCR-09", 0, "", q10_card) and count_events(q10d.events, "bout_refused", {"objective": "SCR-09"}) == 1
	_sr("the sim fights a generic card (DOCKHAND, a tier-2 Slugger of the Kowalchuk dialect): the spar opens on his assembled strings (%s), he tells %d of them in 20s and lands %d; his hook (%s -> %s) answers its trigger; his opener breaks to a jab in its tell; three scraps won pay %d XP and tick Kowalchuk to PI %d; SCR-09 is refused against him (no breakable special)" % [JSON.stringify(q10b.pattern["strings"].keys()), q10_tells, q10_hits_p, str(q10_pu["trigger"]), str(q10_pu["response"]), q10d.xp_of("RORY"), q10d.pi_level("kowalchuk")],
		q10_live and q10_tells >= 3 and q10_answered and q10_broke and q10d.pi_level("kowalchuk") == 1 and q10d.xp_of("RORY") == 3 * int(round(15.0 * 1.1 * float(content["economy"]["xp"].get("pace", 1.0)))) and q10_refused)
	# Ep1 by card: MARCUS, JUNE and the CHALLENGER on strings of their own (the slot, club and index still the stand-in boss's), PRIYA's trial on hers; the same card is the same pattern in any sim
	var q10_yuri_labels: Array = []
	for q10_k in content["patterns"]["yuri_kowalchuk"]["strings"]: q10_yuri_labels.append(str(content["patterns"]["yuri_kowalchuk"]["strings"][q10_k]["label"]))
	var q10e := make_sim(0, 7); q10e.start_ep1("scrap_2")
	var q10_m_own := true
	for q10_k in q10e.pattern["strings"]:
		if str(q10e.pattern["strings"][q10_k]["label"]) in q10_yuri_labels: q10_m_own = false
	var q10_marcus_ok: bool = str(q10e.bgeneric.get("name", "")) == "MARCUS" and bool(q10e.pattern["meta"]["generic"]) and str(q10e.pattern["meta"]["style"]) == "SLUGGER" and int(q10e.pattern["meta"]["tier"]) == 1 and q10e.pattern["strings"].size() == 2 and q10_m_own and q10e.bdialect == "marcus" and q10e.boss_name == "yuri_kowalchuk" and absf(q10e.B["comp_max"] - 65.0 * 2.0 * 1.15) < 0.01 and int(q10e.B["stats"]["PWR"]) == 70
	var q10f := make_sim(0, 7); q10f.start_ep1("scrap_3")
	var q10_june_ok: bool = str(q10f.bgeneric.get("name", "")) == "JUNE" and str(q10f.pattern["meta"]["style"]) == "SWARMER" and q10f.pattern["strings"].size() == 2 and q10f.bdialect == "june" and str(q10f.pattern["strings"]["S1"]["tell"]["channel"]) == str(q10_pc["dialects"]["gym"]["channel"])
	var q10g := make_sim(0, 7); q10g.start_ep1("scrap_1")
	var q10_ch_ok: bool = str(q10g.bgeneric.get("name", "")) == "CHALLENGER" and q10g.bdialect == "school" and str(q10g.pattern["strings"]["S1"]["tell"]["motif"]) in q10_pc["dialects"]["school"]["motifs"]["normal"] and str(q10g.pattern["meta"]["dialect"]) == "school"
	var q10h := make_sim(0, 7); q10h.start_ep1("priya_trial")
	var q10_priya_ok: bool = str(q10h.bgeneric.get("name", "")) == "PRIYA" and str(q10h.pattern["meta"]["style"]) == "OUTBOXER" and int(q10h.pattern["meta"]["tier"]) == 2 and q10h.pattern["strings"].size() == 3 and q10h.bdialect == "priya" and int(q10h.B["stats"]["RFX"]) == 70 and "tell_highlight" in q10h.lab
	var q10_same_card: bool = JSON.stringify(TNBAssembler.assemble(q10_pc, q10e.bgeneric)) == JSON.stringify(TNBAssembler.assemble(q10_pc, make_sim(3, 99).spec_from_card(content["bouts"]["ep1"]["scrap_2"]["card"])))
	_sr("Ep1 by card: MARCUS fights on two Slugger strings of his own (%s - none of Yuri's), his chin from his card, the slot still Yuri's; JUNE on two Swarmer strings on the gym's channel, the CHALLENGER on the school's motifs (%s), PRIYA's trial on three Out-Boxer strings at tier 2; a card is the same pattern in any sim" % [JSON.stringify(q10e.pattern["strings"].values().map(func(x): return str(x["label"]))), str(q10g.pattern["strings"]["S1"]["tell"]["motif"])],
		q10_marcus_ok and q10_june_ok and q10_ch_ok and q10_priya_ok and q10_same_card)
	# a filler slot in a dual: R1 fought by an assembled generic, the named boss's slot borrowed; it ticks the dialect, earns no page, pays; R2 is a named boss again; two sims with the slot hash alike, another seed differs
	var q10i := make_sim(1, 7)
	var q10_spec_f: Dictionary = q10i.generic_spec("FILLER", "OUTBOXER", "tremblay", 2, 21, "Dock Filler")
	var q10_set: bool = q10i.set_generic_slot(0, q10_spec_f); q10i.events.clear(); q10i.new_dual()
	var q10_slot_ok: bool = q10_set and str(q10i.blineup[0]) == "FILLER" and q10i.boss_name == "FILLER" and q10i.boss_label == "Dock Filler" and str(q10i.bgeneric.get("name", "")) == "FILLER" and q10i.B["style"] == "OUTBOXER" and q10i.B["element"] == "FROST" and q10i.B["house"] == "tremblay" and q10i.bdialect == "tremblay" \
		and count_events(q10i.events, "generic", {"name": "FILLER"}) == 1 and count_events(q10i.events, "matchup") == 1 and q10i.boss_role("FILLER") == 1 and ("FILLER" in q10i.bdressed) and int(q10i.B["stats"]["PWR"]) == 55 and q10i.pattern["strings"].size() == 3
	quiet(q10i); q10i.ep_p = 6; q10i._end_segment("clock")
	var q10_after: bool = q10i.pi_level("tremblay") == 2 and q10i.pi["bosses"].is_empty() and q10i.xp_of("RORY") == int(round(25.0 * 1.1 * float(content["economy"]["xp"].get("pace", 1.0)))) and q10i.mode == "CARD"
	next_segment(q10i)
	var q10_r2: bool = (q10i.boss_name in TNBSim.BOSSES) and q10i.bgeneric.is_empty() and not bool(q10i.pattern["meta"].get("generic", false))
	var q10j := make_sim(1, 7); q10j.set_generic_slot(0, q10_spec_f); q10j.new_dual()
	var q10k := make_sim(1, 7); q10k.set_generic_slot(0, q10i.generic_spec("FILLER", "OUTBOXER", "tremblay", 2, 22, "Dock Filler")); q10k.new_dual()
	var q10j2 := make_sim(1, 7); q10j2.set_generic_slot(0, q10_spec_f); q10j2.new_dual()
	_sr("a filler slot: R1 is fought by 'Dock Filler', an assembled tier-2 Out-Boxer of the Tremblay dialect (FROST, House Tremblay, the matchup card read), Yuri's slot borrowed; R1 won ticks Tremblay to PI %d, books no page and pays %d XP; R2 is %s, a named boss; two sims with the slot hash alike and a seed apart differ" % [q10i.pi_level("tremblay"), q10i.xp_of("RORY"), q10i.boss_name],
		q10_slot_ok and q10_after and q10_r2 and q10j.hash_state() == q10j2.hash_state() and q10j.hash_state() != q10k.hash_state() and q10j.content_stamp() == make_sim(0, 1).content_stamp())
	# the save carries it: a dual with a filler snapshotted mid-fight and restored into another sim lands on the same hash with the generic's pattern, and continues in step
	var q10_log: Array = build_log(900, 8)
	for q10_i in 600: q10j.step(q10_log[q10_i])
	var q10_snap: Dictionary = q10j.snapshot()
	var q10l := make_sim(0, 3); var q10_r: Dictionary = q10l.restore(q10_snap)
	for q10_i in range(600, 900): q10j.step(q10_log[q10_i]); q10l.step(q10_log[q10_i])
	_sr("the save carries a filler: a dual with 'Dock Filler' in R1 snapshotted at tick 600 restores into another sim on the same hash, his assembled pattern with it (%s), and runs 300 more ticks in step" % JSON.stringify(q10l.gpatterns.keys()),
		bool(q10_r["ok"]) and bool(q10_r["same"]) and q10l.gpatterns.has("FILLER") and q10l.boss_name == "FILLER" and q10l.hash_state() == q10j.hash_state() and q10l.tick == 900)

	# ================= PAC-071: the IDLE lines as the boss's neutral game (NP_04 z2) ======
	var q11_nt: Dictionary = content["neutral"]
	var q11_idle := func(q11_bi: int, q11_d: float) -> TNBSim:
		var q11_t := make_sim(q11_bi, 7); quiet(q11_t); q11_t.neutral_on = true; q11_t.bstate = "IDLE"; q11_t.btimer = 1 << 30
		q11_t.P["pos"] = Vector2(0.0, q11_d * 0.5); q11_t.B["pos"] = Vector2(0.0, -q11_d * 0.5)
		return q11_t
	var q11_dist := func(q11_s: TNBSim) -> float: return q11_s.P["pos"].distance_to(q11_s.B["pos"])
	# the table and the coverage: 41 verbs for the 52 lines, nothing carried
	var q11_a: TNBSim = q11_idle.call(1, 1.9)
	var q11_cov: Dictionary = q11_a.pattern_coverage(content["patterns"])
	var q11_used := {}; var q11_unknown: Array = []; var q11_unauthored: Array = []
	for q11_bn in TNBSim.BOSSES:
		for q11_il in content["patterns"][q11_bn]["idle"]:
			var q11_vb := TNBSim.idle_verb(str(q11_il)); q11_used[q11_vb] = true
			if not q11_nt["verbs"].has(q11_vb): q11_unknown.append(q11_vb)
		if not bool(q11_a._neutral_profile(content["patterns"][q11_bn]).get("authored", false)): q11_unauthored.append(q11_bn)
	var q11_cats := {}
	for q11_vb in q11_nt["verbs"]: q11_cats[str(q11_nt["verbs"][q11_vb]["cat"])] = int(q11_cats.get(str(q11_nt["verbs"][q11_vb]["cat"]), 0)) + 1
	var q11_gen_prof: Dictionary = q11_a._neutral_profile(TNBAssembler.assemble(content["pieces"], q11_a.generic_spec("G", "SLUGGER", "kowalchuk", 2, 3)))
	var q11_lines: int = q11_cov["idle"]["executed"].size() + q11_cov["idle"]["presentational"].size() + q11_cov["idle"]["carried"].size()
	_sr("the neutral game as data (NP_04 s2 IDLE): %d verbs (%s) for the 24 bosses' %d IDLE lines - every verb used known, every table verb used; pattern_coverage: %d lines executed, %d presentational (%s), %d carried; every boss authors a move verb, a generic authors none (the shared approach)" % [q11_nt["verbs"].size(), JSON.stringify(q11_cats), q11_lines, q11_cov["idle"]["executed"].size(), q11_cov["idle"]["presentational"].size(), ", ".join(PackedStringArray(q11_cov["idle"]["presentational"])), q11_cov["idle"]["carried"].size()],
		q11_nt["verbs"].size() == 41 and q11_used.size() == 41 and q11_unknown.is_empty() and q11_lines == 52 and q11_cov["idle"]["executed"].size() == 49 and q11_cov["idle"]["presentational"].size() == 3 and q11_cov["idle"]["carried"].is_empty() \
		and q11_cov["meta"]["carried"].is_empty() and q11_cov["select"]["carried"].is_empty() and q11_cov["directives"]["carried"].is_empty() and q11_cov["tags"]["carried"].is_empty() and q11_unauthored.is_empty() and not bool(q11_gen_prof["authored"]))
	# how he closes: each walk at its own pace from 3.4m, each stopping at its own range; the shared approach for a frozen boss and for a generic; the lead
	var q11_close := func(q11_s: TNBSim, q11_n: int) -> float:
		var q11_d0: float = q11_s.P["pos"].distance_to(q11_s.B["pos"])
		for q11_i in q11_n: q11_s.step({})
		return (q11_d0 - q11_s.P["pos"].distance_to(q11_s.B["pos"])) / (float(q11_n) / 120.0)
	var q11_speeds := {2: 0.45, 20: 0.45, 19: 0.7, 3: 0.8, 17: 1.0, 11: 0.7, 12: 0.7, 5: 1.3, 10: 1.5, 14: 1.2, 15: 1.2}
	var q11_ranges := {2: 1.9, 20: 1.9, 3: 1.9, 17: 1.9, 11: 2.0, 12: 2.0, 5: 1.5, 10: 1.3, 14: 1.9, 15: 1.9}
	var q11_meas := {}; var q11_close_ok := true; var q11_stops := {}
	for q11_bi in q11_speeds:
		var q11_s: TNBSim = q11_idle.call(q11_bi, 3.4)
		var q11_v: float = q11_close.call(q11_s, 60)
		q11_meas[TNBSim.BOSSES[q11_bi]] = snappedf(q11_v, 0.01)
		if absf(q11_v - float(q11_speeds[q11_bi])) > 0.02: q11_close_ok = false
		if q11_ranges.has(q11_bi):
			for q11_i in 480: q11_s.step({})
			var q11_df: float = q11_dist.call(q11_s); q11_stops[TNBSim.BOSSES[q11_bi]] = snappedf(q11_df, 0.01)
			if q11_df > float(q11_ranges[q11_bi]) + 0.001 or q11_df < float(q11_ranges[q11_bi]) - 0.02: q11_close_ok = false
	var q11_off: TNBSim = q11_idle.call(2, 3.4); q11_off.neutral_on = false; var q11_off_v: float = q11_close.call(q11_off, 60)
	var q11_gs := make_sim(0, 7); q11_gs.start_spar(0, [], {"name": "DOCKHAND", "style": "SLUGGER", "house": "kowalchuk", "generic": true, "tier": 2, "seed": 7}); quiet(q11_gs); q11_gs.neutral_on = true; q11_gs.bstate = "IDLE"; q11_gs.btimer = 1 << 30
	q11_gs.P["pos"] = Vector2(0.0, 1.7); q11_gs.B["pos"] = Vector2(0.0, -1.7); var q11_gen_v: float = q11_close.call(q11_gs, 60)
	var q11_ch: TNBSim = q11_idle.call(15, 3.4); var q11_ec: TNBSim = q11_idle.call(14, 3.4)
	var q11_chx0: float = q11_ch.B["pos"].x; var q11_ecx0: float = q11_ec.B["pos"].x; var q11_px0: float = q11_ch.P["pos"].x
	for q11_i in 60: q11_ch.step({"move": Vector2(1, 0)}); q11_ec.step({"move": Vector2(1, 0)})
	var q11_chx: float = q11_ch.B["pos"].x - q11_chx0; var q11_ecx: float = q11_ec.B["pos"].x - q11_ecx0; var q11_px: float = q11_ch.P["pos"].x - q11_px0
	_sr("how he closes from 3.4m (m/s): %s, stopping at %s; Moreau's glacial walk with his neutral game frozen is the shared approach (%.2f), and so is a generic's (%.2f); against a player strafing %.3fm the Choir leads the step (%.3fm sideways in 0.5s) where the Echo walks at where you are (%.3fm)" % [JSON.stringify(q11_meas), JSON.stringify(q11_stops), q11_off_v, q11_gen_v, q11_px, q11_chx, q11_ecx],
		q11_close_ok and absf(q11_off_v - 1.2) < 0.02 and absf(q11_gen_v - 1.2) < 0.02 and absf(q11_px) > 0.2 and signf(q11_chx) == signf(q11_px) and signf(q11_ecx) == signf(q11_px) and absf(q11_chx) > absf(q11_ecx) * 1.3)
	# how he circles: the tangential speed at range and its direction; the reversals on a clock and after a string; who steps back out to his range and who does not
	var q11_tan := func(q11_s: TNBSim, q11_n: int) -> float:
		var q11_r: float = q11_s.P["pos"].distance_to(q11_s.B["pos"]); var q11_a0: float = (q11_s.B["pos"] - q11_s.P["pos"]).angle()
		for q11_i in q11_n: q11_s.step({})
		return wrapf((q11_s.B["pos"] - q11_s.P["pos"]).angle() - q11_a0, -PI, PI) * q11_r / (float(q11_n) / 120.0)
	var q11_yu: float = q11_tan.call(q11_idle.call(1, 1.9), 60); var q11_ca: float = q11_tan.call(q11_idle.call(7, 1.9), 60); var q11_ma: float = q11_tan.call(q11_idle.call(18, 2.1), 60)
	var q11_va_s: TNBSim = q11_idle.call(0, 2.1); var q11_va1: float = q11_tan.call(q11_va_s, 60); for q11_i in 250: q11_va_s.step({})
	var q11_va2: float = q11_tan.call(q11_va_s, 60)
	var q11_cg_s: TNBSim = q11_idle.call(13, 2.3); var q11_cg1: float = q11_tan.call(q11_cg_s, 60); for q11_i in 310: q11_cg_s.step({})
	var q11_cg2: float = q11_tan.call(q11_cg_s, 60)
	var q11_so_s: TNBSim = q11_idle.call(21, 1.9); var q11_so1: float = q11_tan.call(q11_so_s, 60); for q11_i in 430: q11_so_s.step({})
	var q11_so2: float = q11_tan.call(q11_so_s, 60)
	var q11_ba_s: TNBSim = q11_idle.call(23, 2.0); var q11_ba1: float = q11_tan.call(q11_ba_s, 60); q11_ba_s.bstrings_done = 1
	var q11_ba2: float = q11_tan.call(q11_ba_s, 60)
	var q11_mr: TNBSim = q11_idle.call(18, 1.6); for q11_i in 180: q11_mr.step({})
	var q11_yr: TNBSim = q11_idle.call(1, 1.6); for q11_i in 180: q11_yr.step({})
	var q11_near := func(q11_x: float, q11_want: float) -> bool: return absf(absf(q11_x) - q11_want) <= q11_want * 0.08
	_sr("how he circles at range (m/s, signed): Yuri %.2f one way, Carter %.2f the other; Marta %.2f at 2.1m; Vane %.2f then %.2f after 2.5s, the Cartographer %.2f then %.2f after 3s, Sora %.2f then %.2f after 4s, Baro %.2f then %.2f after a string; from 1.6m Marta steps back out to %.2fm, Yuri stays in at %.2fm" % [q11_yu, q11_ca, q11_ma, q11_va1, q11_va2, q11_cg1, q11_cg2, q11_so1, q11_so2, q11_ba1, q11_ba2, q11_dist.call(q11_mr), q11_dist.call(q11_yr)],
		q11_near.call(q11_yu, 0.5) and q11_near.call(q11_ca, 1.2) and signf(q11_yu) != signf(q11_ca) and q11_near.call(q11_ma, 0.8) and q11_near.call(q11_va1, 0.5) and q11_near.call(q11_va2, 0.5) and signf(q11_va1) != signf(q11_va2) \
		and q11_near.call(q11_cg1, 0.6) and signf(q11_cg1) != signf(q11_cg2) and q11_near.call(q11_so1, 0.7) and signf(q11_so1) != signf(q11_so2) and q11_near.call(q11_ba1, 0.6) and signf(q11_ba1) != signf(q11_ba2) \
		and q11_dist.call(q11_mr) >= 2.0 and absf(q11_dist.call(q11_yr) - 1.6) < 0.02)
	# the rhythms and the angle: Ada steps only in the first 200ms of each 800ms beat (650 in her phase 2), Chiamaka on both of her tempos; Tam comes in on a 35-degree angle and switches sides after 1.5s
	var q11_beats := func(q11_s: TNBSim, q11_n: int, q11_cyc: int, q11_on: Array) -> Array:      # [moved ticks, ticks that moved off the beat or stood on it]
		var q11_moved := 0; var q11_wrong := 0
		for q11_i in q11_n:
			var q11_bt: int = q11_s.bneutral_t; var q11_p0: Vector2 = q11_s.B["pos"]
			q11_s.step({})
			var q11_mv: bool = q11_s.B["pos"].distance_to(q11_p0) > 0.0001
			var q11_want := false
			for q11_w in q11_on:
				if q11_bt % q11_cyc >= int(q11_w[0]) and q11_bt % q11_cyc < int(q11_w[1]): q11_want = true
			if q11_mv: q11_moved += 1
			if q11_mv != q11_want: q11_wrong += 1
		return [q11_moved, q11_wrong]
	var q11_ad: TNBSim = q11_idle.call(4, 3.8); var q11_ad1: Array = q11_beats.call(q11_ad, 192, 96, [[0, 24]])
	var q11_ad2s: TNBSim = q11_idle.call(4, 3.8); q11_ad2s.bmods["metronome_ms"] = 650.0; var q11_ad2: Array = q11_beats.call(q11_ad2s, 156, 78, [[0, 24]])
	var q11_cm: TNBSim = q11_idle.call(8, 3.8); var q11_cm1: Array = q11_beats.call(q11_cm, 180, 180, [[0, 24], [72, 96]])
	var q11_tm: TNBSim = q11_idle.call(22, 3.6)
	var q11_ang := func(q11_s: TNBSim, q11_n: int) -> Array:      # [degrees off the line to him, speed m/s]
		var q11_p0: Vector2 = q11_s.B["pos"]; var q11_to: Vector2 = (q11_s.P["pos"] - q11_s.B["pos"]).normalized()
		for q11_i in q11_n: q11_s.step({})
		var q11_dv: Vector2 = q11_s.B["pos"] - q11_p0
		return [rad_to_deg(q11_to.angle_to(q11_dv)), q11_dv.length() / (float(q11_n) / 120.0)]
	var q11_tm1: Array = q11_ang.call(q11_tm, 24)
	var q11_tm_b: TNBSim = q11_idle.call(22, 3.6); q11_tm_b.bneutral_t = 180; var q11_tm2: Array = q11_ang.call(q11_tm_b, 24)
	_sr("the rhythms: Ada moves %d ticks of 192 - the first 200ms of each 800ms beat, %d off it; at 650ms %d of 156, %d off; Chiamaka %d of 180 on her 600 / 900 tempos, %d off; the angle: Tam comes in %.1f degrees off the line, then %.1f after 1.5s, at %.2f m/s (1.1 on his slow tempo, x0.7)" % [int(q11_ad1[0]), int(q11_ad1[1]), int(q11_ad2[0]), int(q11_ad2[1]), int(q11_cm1[0]), int(q11_cm1[1]), float(q11_tm1[0]), float(q11_tm2[0]), float(q11_tm1[1])],
		int(q11_ad1[0]) == 48 and int(q11_ad1[1]) == 0 and int(q11_ad2[0]) == 48 and int(q11_ad2[1]) == 0 and int(q11_cm1[0]) == 48 and int(q11_cm1[1]) == 0 \
		and absf(absf(float(q11_tm1[0])) - 35.0) < 3.0 and absf(absf(float(q11_tm2[0])) - 35.0) < 3.0 and signf(float(q11_tm1[0])) != signf(float(q11_tm2[0])) and absf(float(q11_tm1[1]) - 0.77) < 0.04)
	# the stances: Vasile holds his measured band both ways; Vey mirrors a strafing player; Cal takes the centre and comes no closer; Moira cuts the ring
	var q11_vi1: TNBSim = q11_idle.call(16, 1.4); for q11_i in 120: q11_vi1.step({})
	var q11_vi2: TNBSim = q11_idle.call(16, 2.6); for q11_i in 120: q11_vi2.step({})
	var q11_vi3: TNBSim = q11_idle.call(16, 1.85); var q11_vi3p: Vector2 = q11_vi3.B["pos"]; for q11_i in 120: q11_vi3.step({})
	var q11_vy: TNBSim = q11_idle.call(6, 1.9); var q11_vyb: float = q11_vy.B["pos"].x; var q11_vyp: float = q11_vy.P["pos"].x
	for q11_i in 60: q11_vy.step({"move": Vector2(1, 0)})
	var q11_vy_pdx: float = q11_vy.P["pos"].x - q11_vyp
	var q11_vy_ratio: float = (q11_vy.B["pos"].x - q11_vyb) / (q11_vy_pdx if absf(q11_vy_pdx) > 0.001 else 0.001)
	var q11_cl1: TNBSim = q11_idle.call(9, 2.15); q11_cl1.B["pos"] = Vector2.ZERO; q11_cl1.P["pos"] = Vector2(0.0, 2.15); for q11_i in 120: q11_cl1.step({})
	var q11_cl2: TNBSim = q11_idle.call(9, 3.0); q11_cl2.B["pos"] = Vector2.ZERO; q11_cl2.P["pos"] = Vector2(0.0, 3.0); for q11_i in 180: q11_cl2.step({})
	var q11_cl3: TNBSim = q11_idle.call(9, 2.0); q11_cl3.B["pos"] = Vector2(1.2, -1.2); q11_cl3.P["pos"] = Vector2(0.0, 1.5); for q11_i in 240: q11_cl3.step({})
	var q11_mo: TNBSim = q11_idle.call(19, 2.0); q11_mo.P["pos"] = Vector2(1.8, 0.0); q11_mo.B["pos"] = Vector2(-0.5, -1.6); for q11_i in 480: q11_mo.step({})
	var q11_mo_side: float = (q11_mo.B["pos"] - q11_mo.P["pos"]).dot(Vector2.ZERO - q11_mo.P["pos"])
	_sr("the stances: Vasile from 1.4m steps back to %.2f, from 2.6m in to %.2f, at 1.85m stands (%.4fm moved); Vey mirrors a strafing player %.2f to 1; Cal on the centre with you at 2.15m stands (%.2fm off it), with you at 3.0m comes to %.2f and no closer, off-centre goes back to it (%.2fm away); Moira from the side ends %.2fm from you on the centre side (%.2fm from the centre, you at 1.80)" % [q11_dist.call(q11_vi1), q11_dist.call(q11_vi2), q11_vi3.B["pos"].distance_to(q11_vi3p), q11_vy_ratio, q11_cl1.B["pos"].length(), q11_dist.call(q11_cl2), q11_cl3.B["pos"].length(), q11_dist.call(q11_mo), q11_mo.B["pos"].length()],
		q11_dist.call(q11_vi1) >= 1.69 and q11_dist.call(q11_vi1) <= 1.72 and absf(q11_dist.call(q11_vi2) - 2.1) < 0.02 and q11_vi3.B["pos"].distance_to(q11_vi3p) < 0.0001 and absf(q11_vy_pdx) > 0.2 and absf(q11_vy_ratio - 1.0) < 0.15 \
		and q11_cl1.B["pos"].length() < 0.001 and absf(q11_dist.call(q11_cl2) - 2.2) < 0.04 and q11_cl3.B["pos"].length() < 0.04 and q11_mo_side > 0.0 and absf(q11_dist.call(q11_mo) - 1.9) < 0.04 and q11_mo.B["pos"].length() < 0.15)
	# the guards: the rate each authored guard blocks an unread punch, head / body; halved when wobbled unless composed; Sam's up while he walks in; a live sample on Osei's shell
	var q11_g := func(q11_bi: int, q11_d: float, q11_body: bool, q11_wob: bool) -> float:
		var q11_s: TNBSim = q11_idle.call(q11_bi, q11_d)
		if q11_wob: q11_s.B["comp"] = q11_s.B["comp_max"] * 0.3
		return q11_s._idle_guard(q11_body)
	var q11_gv := {"guard_mid (Yuri)": [q11_g.call(1, 1.6, false, false), q11_g.call(1, 1.6, true, false)], "guard_high (Vane)": [q11_g.call(0, 1.6, false, false), q11_g.call(0, 1.6, true, false)], "guard_tight (Ada)": [q11_g.call(4, 1.6, false, false), q11_g.call(4, 1.6, true, false)],
		"guard_rough (Alfie)": [q11_g.call(5, 1.6, false, false), q11_g.call(5, 1.6, true, false)], "guard_perfect (Sora)": [q11_g.call(21, 1.6, false, false), q11_g.call(21, 1.6, true, false)], "guard_low_bait (Tam)": [q11_g.call(22, 1.6, false, false), q11_g.call(22, 1.6, true, false)],
		"guard_textbook (Baro)": [q11_g.call(23, 1.6, false, false), q11_g.call(23, 1.6, true, false)], "shell_stance (Osei)": [q11_g.call(11, 1.6, false, false), q11_g.call(11, 1.6, true, false)], "none (Vey)": [q11_g.call(6, 1.6, false, false), q11_g.call(6, 1.6, true, false)]}
	var q11_gexp := {"guard_mid (Yuri)": [0.35, 0.35], "guard_high (Vane)": [0.5, 0.15], "guard_tight (Ada)": [0.45, 0.45], "guard_rough (Alfie)": [0.25, 0.25], "guard_perfect (Sora)": [0.5, 0.5], "guard_low_bait (Tam)": [0.1, 0.6], "guard_textbook (Baro)": [0.4, 0.4], "shell_stance (Osei)": [0.6, 0.1], "none (Vey)": [0.35, 0.35]}
	var q11_g_ok := true
	for q11_k in q11_gexp:
		if absf(float(q11_gv[q11_k][0]) - float(q11_gexp[q11_k][0])) > 0.0001 or absf(float(q11_gv[q11_k][1]) - float(q11_gexp[q11_k][1])) > 0.0001: q11_g_ok = false
	var q11_wy: float = q11_g.call(1, 1.6, false, true); var q11_wc: float = q11_g.call(9, 1.6, false, true); var q11_ws: float = q11_g.call(12, 1.6, false, true)
	var q11_sa1: float = q11_g.call(3, 2.2, false, false); var q11_sa2: float = q11_g.call(3, 1.6, false, false)
	var q11_os_off: TNBSim = q11_idle.call(11, 1.6); q11_os_off.neutral_on = false
	var q11_os: TNBSim = q11_idle.call(11, 1.4)
	var q11_cnt := {"hg": 0, "hn": 0, "bg": 0, "bn": 0}
	for q11_i in 600:
		var q11_body: bool = q11_i % 2 == 1
		thaw(q11_os); q11_os.P["busy_t"] = 0; q11_os.P["cmd"] = {}; q11_os.P["pending"] = {}; q11_os.P["stamina"] = 100.0; q11_os.tokens = []; q11_os.flags = {}
		q11_os.P["pos"] = Vector2(0.0, 0.7); q11_os.B["pos"] = Vector2(0.0, -0.7); clear_defense(q11_os.B)
		q11_os.step({"punch": "L_STRAIGHT", "body": q11_body})
		var q11_rd := str(q11_os.P["pending"].get("read", ""))
		if q11_rd == "guard": q11_cnt["bg" if q11_body else "hg"] += 1
		elif q11_rd == "none": q11_cnt["bn" if q11_body else "hn"] += 1
		q11_os.P["pending"] = {}; clear_defense(q11_os.B)
	var q11_hf: float = float(q11_cnt["hg"]) / maxf(1.0, float(q11_cnt["hg"] + q11_cnt["hn"])); var q11_bf: float = float(q11_cnt["bg"]) / maxf(1.0, float(q11_cnt["bg"] + q11_cnt["bn"]))
	_sr("the guards (head / body): %s; wobbled, Yuri's halves to %.3f while Cal's (%.2f) and Surety's (%.2f) are composed; Sam walking in at 2.2m %.2f, in range %.2f; Osei with her neutral game frozen 0.35; live, Osei's shell turns %.0f%% of the unread head jabs and %.0f%% of the body jabs (%d / %d samples)" % [JSON.stringify(q11_gv), q11_wy, q11_wc, q11_ws, q11_sa1, q11_sa2, q11_hf * 100.0, q11_bf * 100.0, q11_cnt["hg"] + q11_cnt["hn"], q11_cnt["bg"] + q11_cnt["bn"]],
		q11_g_ok and absf(q11_wy - 0.175) < 0.0001 and absf(q11_wc - 0.35) < 0.0001 and absf(q11_ws - 0.35) < 0.0001 and absf(q11_sa1 - 0.8) < 0.0001 and absf(q11_sa2 - 0.35) < 0.0001 and absf(q11_os_off._idle_guard(false) - 0.35) < 0.0001 \
		and q11_hf > 0.5 and q11_hf < 0.7 and q11_bf < 0.2 and q11_cnt["hg"] + q11_cnt["hn"] >= 100 and q11_cnt["bg"] + q11_cnt["bn"] >= 100)
	# the clocks: Yuri taunts every 8s and Carter every 10s (the guard open, his read off, the next string held), Vane and Ada never; Tam's tempo flips every 6s and his gaps follow it
	var q11_taunts := func(q11_bi: int, q11_n: int) -> int:
		var q11_s: TNBSim = q11_idle.call(q11_bi, 1.9)
		for q11_i in q11_n: q11_s.step({})
		return count_events(q11_s.events, "taunt_b")
	var q11_yt: TNBSim = q11_idle.call(1, 1.4); var q11_first := -1
	for q11_i in 1200:
		q11_yt.step({})
		if q11_first < 0 and count_events(q11_yt.events, "taunt_b") == 1: q11_first = q11_yt.tick; break
	var q11_open: int = int(q11_yt.B["guard_open_t"]); var q11_rp: float = q11_yt.read_prob(0, false, false, false)
	q11_yt.events.clear(); q11_yt.P["pos"] = Vector2(0.0, 0.7); q11_yt.B["pos"] = Vector2(0.0, -0.7); throw_clean(q11_yt, "L_STRAIGHT")
	var q11_t_hit: int = count_events(q11_yt.events, "hit", {"on": "B"}); var q11_t_blk: int = count_events(q11_yt.events, "block", {"by": "B"})
	var q11_yd: TNBSim = q11_idle.call(1, 1.9); q11_yd.bneutral_t = TNBSim.ms(8000) - 1; q11_yd.bstate = "RECOVER"; q11_yd.btimer = 5; q11_yd.step({})
	var q11_tm_s: TNBSim = q11_idle.call(22, 1.9); var q11_tflips: Array = []
	var q11_tf_n := 0
	for q11_i in 3000:
		q11_tm_s.step({})
		var q11_tf_c: int = count_events(q11_tm_s.events, "tempo_shift")
		if q11_tf_c > q11_tf_n: q11_tf_n = q11_tf_c; q11_tflips.append(q11_tm_s.bneutral_t)
	var q11_tl := make_sim(22, 7); quiet(q11_tl); q11_tl.neutral_on = true; q11_tl.bstate = "RECOVER"; q11_tl.btimer = 1
	var q11_gaps := {"fast": [], "slow": []}
	for q11_i in 3600:
		var q11_st0: String = q11_tl.bstate
		q11_tl.step({"block": true})
		if q11_st0 == "ACTING" and q11_tl.bstate == "RECOVER": q11_gaps["fast" if q11_tl.btempo_fast else "slow"].append(q11_tl.btimer)
	var q11_gap_ok: bool = q11_gaps["fast"].size() >= 2 and q11_gaps["slow"].size() >= 2
	for q11_x in q11_gaps["fast"]:
		if int(q11_x) > 58: q11_gap_ok = false
	for q11_x in q11_gaps["slow"]:
		if int(q11_x) < 67: q11_gap_ok = false
	_sr("the clocks: in 25s Yuri taunts %d times and Carter %d, Vane none in 60s (%d), Ada none (%d); at Yuri's first (tick %d) his guard is open %d ticks and his read %.2f, and a jab lands (%d hit, %d blocked); a taunt in his recover holds the next string %d ticks; Tam's tempo flips at %s and his gaps between strings run %s fast and %s slow (ticks)" % [q11_taunts.call(1, 3000), q11_taunts.call(7, 3000), q11_taunts.call(0, 7200), q11_taunts.call(4, 3000), q11_first, q11_open, q11_rp, q11_t_hit, q11_t_blk, q11_yd.btimer, JSON.stringify(q11_tflips), JSON.stringify(q11_gaps["fast"]), JSON.stringify(q11_gaps["slow"])],
		q11_taunts.call(1, 3000) == 3 and q11_taunts.call(7, 3000) == 2 and q11_taunts.call(0, 7200) == 0 and q11_taunts.call(4, 3000) == 0 and q11_first == TNBSim.ms(8000) and q11_open >= TNBSim.ms(500) - 1 and absf(q11_rp - 0.05) < 0.0001 \
		and q11_t_hit == 1 and q11_t_blk == 0 and q11_yd.btimer >= TNBSim.ms(700) - 1 and q11_tflips == [720, 1440, 2160, 2880] and q11_gap_ok)
	# the flags only the presentation reads, and the reveal: Jean-Guy's and the Choir's feet silent, Marta's quiet while she arms; Reyes' bell (two with a Reyes dressed); Remy named in a blind dual where every other slot shows '?'
	var q11_jg: TNBSim = q11_idle.call(2, 1.6); q11_jg.step({}); var q11_chq: TNBSim = q11_idle.call(15, 1.6); q11_chq.step({}); var q11_yq: TNBSim = q11_idle.call(1, 1.6); q11_yq.step({})
	var q11_mq: TNBSim = q11_idle.call(18, 1.6); q11_mq.step({}); var q11_mq_idle: bool = q11_mq.bfootwork_audio
	q11_mq._force_string("S1", 1.0, false); q11_mq.step({}); var q11_mq_tell: bool = q11_mq.bfootwork_audio
	for q11_i in 240:
		q11_mq.step({})
		if q11_mq.bstate != "TELL" and q11_mq.bstate != "HOLD" and q11_mq.bstate != "FAKE": break
	q11_mq.step({}); var q11_mq_after: bool = q11_mq.bfootwork_audio
	var q11_re := make_sim(17, 7); var q11_lu_r: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q11_lu_r[3]["house"] = "reyes"; var q11_re2 := make_sim(17, 7, q11_lu_r)
	var q11_bl := make_sim(20, 7, TNBSim.LINEUP_MILLBROOK_8, "blind"); var q11_bl_others := true
	for q11_i in range(1, q11_bl.blineup.size()):
		if q11_bl.boss_slot_label(q11_i) != "?": q11_bl_others = false
	var q11_sn := make_sim(20, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q11_rv := make_sim(19, 7, TNBSim.LINEUP_MILLBROOK_8, "blind"); quiet(q11_rv); q11_rv.blineup[1] = "remy_moreau"; q11_rv._end_segment("clock"); q11_rv.corner_pick(0)
	var q11_hd := make_sim(19, 7, TNBSim.LINEUP_MILLBROOK_8, "blind"); quiet(q11_hd); q11_hd.blineup[1] = "yuri_kowalchuk"; q11_hd._end_segment("clock"); q11_hd.corner_pick(0)
	_sr("presentational flags and the reveal: footwork audio Jean-Guy %s, the Choir %s, Yuri %s; Marta %s idle, %s while she arms, %s after; Reyes rings her bell (%d, together %s) and two with a Reyes dressed (together %s), Yuri rings none; in a blind dual Remy's slot reads '%s' and the rest '?', a sanctioned dual names them all; the corner before a blind R2 names Remy ('%s') and hides Yuri ('%s')" % [q11_jg.bfootwork_audio, q11_chq.bfootwork_audio, q11_yq.bfootwork_audio, q11_mq_idle, q11_mq_tell, q11_mq_after, count_events(q11_re.events, "corner_bell"), count_events(q11_re.events, "corner_bell", {"together": true}) > 0, count_events(q11_re2.events, "corner_bell", {"together": true}) == 1, q11_bl.boss_slot_label(0), str(q11_rv.events.filter(func(q11_e): return q11_e["kind"] == "corner_open")[0]["boss"]) if count_events(q11_rv.events, "corner_open") > 0 else "-", str(q11_hd.events.filter(func(q11_e2): return q11_e2["kind"] == "corner_open")[0]["boss"]) if count_events(q11_hd.events, "corner_open") > 0 else "-"],
		not q11_jg.bfootwork_audio and not q11_chq.bfootwork_audio and q11_yq.bfootwork_audio and count_events(q11_jg.events, "footwork_audio", {"on": false}) == 1 and q11_mq_idle and not q11_mq_tell and q11_mq_after \
		and count_events(q11_re.events, "corner_bell", {"together": false}) == 1 and count_events(q11_re2.events, "corner_bell", {"together": true}) == 1 and count_events(make_sim(1, 7).events, "corner_bell") == 0 \
		and q11_bl.boss_slot_label(0) == "remy_moreau" and q11_bl_others and q11_bl.blineup.size() >= 3 and q11_sn.boss_slot_label(1) == str(q11_sn.blineup[1]) \
		and count_events(q11_rv.events, "corner_open", {"boss": "remy_moreau"}) == 1 and count_events(q11_hd.events, "corner_open", {"boss": "?"}) == 1)

	# ================= PAC-072: The Talk (NP_10 z4) ======
	var q12_tk: Dictionary = content["talk"]
	var q12_corner := func(q12_lu: Array, q12_kz: Dictionary, q12_fmt: String) -> TNBSim:
		var q12_s := make_sim(1, 7, q12_lu, q12_fmt, {}, q12_kz); quiet(q12_s); q12_s._end_segment("clock"); q12_s.corner_pick(0)
		return q12_s
	var q12_card := func(q12_nm: String) -> Dictionary:
		for q12_c in TNBSim.LINEUP_MILLBROOK_8:
			if str(q12_c["name"]) == q12_nm: return q12_c.duplicate(true)
		return {}
	# the data and the cards: three approaches, the stat, every Millbrook card read with its three lines; Priya's the doc's
	var q12_profiles := {}; var q12_dist := {}; var q12_lines_ok := true
	for q12_c in TNBSim.LINEUP_MILLBROOK_8:
		var q12_p := str(q12_c.get("talk", "")); q12_profiles[str(q12_c["name"])] = q12_p; q12_dist[q12_p] = int(q12_dist.get(q12_p, 0)) + 1
		for q12_o in q12_tk["order"]:
			if str(q12_tk["lines"].get(str(q12_c["name"]), {}).get(str(q12_o), "")) == "": q12_lines_ok = false
	var q12_mini_ok := true
	for q12_c in TNBSim.LINEUP_MILLBROOK:
		if str(q12_c.get("talk", "")) != str(q12_profiles.get(str(q12_c["name"]), "?")): q12_mini_ok = false
	_sr("The Talk as data (NP_10 s4): the approaches %s, +%d%% for a right read; the eight Millbrook cards each carry a profile (%s - %s) and three lines of their own; Priya's is the plan (NP_12A: the projection confirmed, never comfort)" % [JSON.stringify(q12_tk["order"]), int(q12_tk["stat_pct"]), JSON.stringify(q12_profiles), JSON.stringify(q12_dist)],
		q12_tk["order"] == ["plan", "fire", "arm"] and int(q12_tk["stat_pct"]) == 5 and q12_profiles.size() == 8 and q12_lines_ok and q12_mini_ok and str(q12_profiles["PRIYA"]) == "plan" and not q12_profiles.values().has(""))
	# the right read: Priya hears the plan - one action spent, no Tension, +5% on every stat for her segment and gone for the next
	var q12a: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, "")
	var q12_menu: Dictionary = q12a.corner_options()["talk"]; var q12_t0: float = q12a.tension
	var q12_ok_a: bool = q12a.corner_action({"kind": "talk", "option": "plan"})
	var q12_left: int = int(q12a.corner["actions_left"]); var q12_done: bool = bool(q12a.corner_options()["talk"]["done"])
	q12a.corner_pick(0)
	var q12_pw: float = float(q12a.P["stats"]["PWR"]); var q12_rf: float = float(q12a.P["stats"]["RFX"]); var q12_who2: String = q12a.pname()
	q12a._end_segment("clock"); q12a.corner_pick(0); q12a.corner_pick(0)
	var q12_m_pw: float = float(q12a.P["stats"]["PWR"]); var q12_who3: String = q12a.pname()
	_sr("the right read: the corner offers %s three lines (\"%s\" / \"%s\" / \"%s\"); the plan lands - one action spent (%d left), no Tension, the talk done for the corner; in R2 %s fights at PWR %.2f / RFX %.2f (35 / 70 x1.05) with a talk_effect event; in R3 %s is at %.0f, untouched" % [str(q12_menu["who"]), str(q12_menu["options"][0]["line"]), str(q12_menu["options"][1]["line"]), str(q12_menu["options"][2]["line"]), q12_left, q12_who2, q12_pw, q12_rf, q12_who3, q12_m_pw],
		str(q12_menu["who"]) == "PRIYA" and bool(q12_menu["readable"]) and q12_menu["hint"].is_empty() and not bool(q12_menu["done"]) and q12_ok_a and q12_left == 1 and q12_done and absf(q12a.tension - q12_t0) < 0.0001 \
		and count_events(q12a.events, "talk", {"who": "PRIYA", "option": "plan", "landed": true}) == 1 and q12_who2 == "PRIYA" and absf(q12_pw - 36.75) < 0.0001 and absf(q12_rf - 73.5) < 0.0001 \
		and count_events(q12a.events, "talk_effect", {"who": "PRIYA"}) == 1 and q12_who3 == "MARCUS" and absf(q12_m_pw - 70.0) < 0.0001)
	# the wrong read costs nothing: the arm around Priya - the action is spent, and once she is out the sim is the one that never talked, to the hash; every card has exactly one read that lands, its own
	var q12b: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, "")
	var q12_ok_b: bool = q12b.corner_action({"kind": "talk", "option": "arm"}); var q12_left_b: int = int(q12b.corner["actions_left"])
	q12b.corner_pick(0)
	var q12c: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); q12c.corner_pick(0)
	var q12_reads := {}; var q12_one_each := true
	for q12_nm in q12_profiles:
		var q12_land: Array = []
		for q12_o in q12_tk["order"]:
			var q12_t: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, "")
			q12_t.lineup[1] = q12_card.call(str(q12_nm))
			q12_t.corner_action({"kind": "talk", "option": str(q12_o)})
			if count_events(q12_t.events, "talk", {"landed": true}) == 1: q12_land.append(str(q12_o))
		q12_reads[q12_nm] = q12_land
		if q12_land != [str(q12_profiles[q12_nm])]: q12_one_each = false
	_sr("the wrong read costs nothing: the arm around Priya is heard (%s), the action spent (%d left), and once she is out the state hashes equal to the dual where nobody talked (PWR %.0f); each of the eight cards has one read that lands, its own: %s" % [str(count_events(q12b.events, "talk", {"landed": false}) == 1), q12_left_b, float(q12b.P["stats"]["PWR"]), JSON.stringify(q12_reads)],
		q12_ok_b and q12_left_b == 1 and count_events(q12b.events, "talk", {"who": "PRIYA", "option": "arm", "landed": false}) == 1 and absf(float(q12b.P["stats"]["PWR"]) - 35.0) < 0.0001 and count_events(q12b.events, "talk_effect") == 0 \
		and q12b.hash_state() == q12c.hash_state() and q12_one_each)
	# the refusals, each naming why and none spending an action: twice in one corner, no actions left, a locked corner, a card with no read, a talk that does not exist, a fight (and a scrap has no corner)
	var q12d: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); q12d.corner_action({"kind": "talk", "option": "fire"}); var q12_twice: bool = not q12d.corner_action({"kind": "talk", "option": "plan"}) and int(q12d.corner["actions_left"]) == 1
	var q12e: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); q12e.corner_action({"kind": "save_bar"}); q12e.corner_action({"kind": "staff", "id": str(q12e.corner_options()["staff"][0]["id"])})
	var q12_broke: bool = int(q12e.corner["actions_left"]) == 0 and not q12e.corner_action({"kind": "talk", "option": "plan"}) and count_events(q12e.events, "talk") == 0
	var q12f := make_sim(1, 7); quiet(q12f); q12f.player_lock = 1; q12f._end_segment("clock"); q12f.corner_pick(0)
	var q12_locked: bool = bool(q12f.corner.get("locked", false)) and not q12f.corner_action({"kind": "talk", "option": "plan"}) and count_events(q12f.events, "corner_refused", {"action": "talk", "why": "locked out by the crowd"}) == 1
	var q12_blank: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true)
	for q12_c in q12_blank: q12_c.erase("talk")
	var q12g: TNBSim = q12_corner.call(q12_blank, {}, "")
	var q12_noread: bool = not bool(q12g.corner_options()["talk"]["readable"]) and not q12g.corner_action({"kind": "talk", "option": "plan"}) and int(q12g.corner["actions_left"]) == 2
	var q12h: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); var q12_bogus: bool = not q12h.corner_action({"kind": "talk", "option": "shout"}) and int(q12h.corner["actions_left"]) == 2
	var q12i := make_sim(1, 7); var q12_fight: bool = not q12i.corner_action({"kind": "talk", "option": "plan"})
	var q12j := make_sim(1, 7); q12j.start_scrap("SCR-01", 1); var q12_scrap: bool = not q12j.corner_action({"kind": "talk", "option": "plan"}) and q12j.mode == "FIGHT"
	var q12_whys: Array = []
	for q12_e in q12d.events + q12g.events + q12h.events:
		if q12_e["kind"] == "corner_refused" and str(q12_e["action"]) == "talk": q12_whys.append(str(q12_e["why"]))
	_sr("refused, spending nothing: %s; and with no actions left, in a locked corner, in a fight, in a scrap (no corner)" % JSON.stringify(q12_whys),
		q12_twice and q12_broke and q12_locked and q12_noread and q12_bogus and q12_fight and q12_scrap and q12_whys.size() == 3)
	# the talk is to a fighter: said to Priya and then JUNE swapped in, JUNE goes out without it (talk_unheard); JUNE swapped in first, the talk is hers
	var q12k: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); q12k.corner_action({"kind": "talk", "option": "plan"}); q12k.corner_action({"kind": "swap", "arg": "JUNE"}); q12k.corner_pick(0)
	var q12_unheard: bool = q12k.pname() == "JUNE" and absf(float(q12k.P["stats"]["PWR"]) - 30.0) < 0.0001 and count_events(q12k.events, "talk_unheard", {"who": "PRIYA", "out": "JUNE"}) == 1 and count_events(q12k.events, "talk_effect") == 0
	var q12l: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); q12l.corner_action({"kind": "swap", "arg": "JUNE"})
	var q12_jmenu: String = str(q12l.corner_options()["talk"]["who"]); q12l.corner_action({"kind": "talk", "option": "fire"}); q12l.corner_pick(0)
	_sr("a talk is to a fighter: the plan said to Priya, then JUNE swapped in - JUNE fights at PWR %.0f and the talk goes unheard; JUNE swapped in first - the corner talks to %s, the fire lands, PWR %.2f" % [float(q12k.P["stats"]["PWR"]), q12_jmenu, float(q12l.P["stats"]["PWR"])],
		q12_unheard and q12_jmenu == "JUNE" and q12l.pname() == "JUNE" and absf(float(q12l.P["stats"]["PWR"]) - 31.5) < 0.0001 and count_events(q12l.events, "talk_effect", {"who": "JUNE"}) == 1)
	# bond levels reveal which talk lands: no bond, nothing; Gymmates rules one wrong option out; Corner Voices names it; the best bond among the dressed speaks; a bond with someone not dressed says nothing
	var q12m: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, TNBSim.parse_kizuna_arg("RORY+PRIYA:10"), "")
	var q12n: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, TNBSim.parse_kizuna_arg("RORY+PRIYA:25"), "")
	var q12o: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, TNBSim.parse_kizuna_arg("RORY+PRIYA:10,MARCUS+PRIYA:50"), "")
	var q12q: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, TNBSim.parse_kizuna_arg("SAM+PRIYA:90"), "")
	var q12_h1: Dictionary = q12m.corner_options()["talk"]["hint"]; var q12_h2: Dictionary = q12n.corner_options()["talk"]["hint"]; var q12_h3: Dictionary = q12o.corner_options()["talk"]["hint"]
	_sr("bond levels reveal the read: none without a bond (%s); RORY & PRIYA at Gymmates rule out %s; at Corner Voices name %s; with MARCUS at Adjacent Trust too, MARCUS speaks (Lv%d: %s); SAM at Duo but not dressed says nothing; the hint is an event when the corner opens" % [JSON.stringify(q12_menu["hint"]), str(q12_h1.get("option", "-")), str(q12_h2.get("option", "-")), int(q12_h3.get("level", 0)), str(q12_h3.get("option", "-"))],
		q12_h1.get("reveal", "") == "rule_out" and str(q12_h1["option"]) == "fire" and str(q12_h1["via"]) == "RORY" and int(q12_h1["level"]) == 1 \
		and q12_h2.get("reveal", "") == "name" and str(q12_h2["option"]) == "plan" and str(q12_h2["via"]) == "RORY" and q12_h3.get("reveal", "") == "name" and str(q12_h3["via"]) == "MARCUS" and int(q12_h3["level"]) == 3 \
		and q12q.corner_options()["talk"]["hint"].is_empty() and count_events(q12m.events, "talk_hint", {"reveal": "rule_out", "via": "RORY"}) == 1 and count_events(q12n.events, "talk_hint", {"reveal": "name", "option": "plan"}) == 1 \
		and count_events(q12a.events, "talk_hint") == 0 and count_events(q12q.events, "talk_hint") == 0)
	# the save carries it: each card's profile as NP_11 s9's personality.talk_profile, back onto the card; a corner saved after a right read restores into another sim and the +5% lands when she goes out
	var q12r: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK_8, {}, "sanctioned")
	var q12_rec: Dictionary = TNBSave.to_save(q12r)
	var q12_pers := {}
	for q12_f in q12_rec["stable"]: q12_pers[str(q12_f["name"])] = str(q12_f["personality"]["talk_profile"])
	var q12_rt = TNBSave.build(content, TNBSave.read_text(TNBSave.write_text(q12r, false)), 3)["sim"]
	var q12s: TNBSim = q12_corner.call(TNBSim.LINEUP_MILLBROOK, {}, ""); q12s.corner_action({"kind": "talk", "option": "plan"})
	var q12_snap: Dictionary = q12s.snapshot()
	var q12u := make_sim(5, 99); var q12_res: Dictionary = q12u.restore(q12_snap); q12u.corner_pick(0)
	_sr("the save carries the read: personality.talk_profile per card %s, back on the cards after a round trip; a corner saved after the plan to Priya restores into another sim (%s) and she goes out at PWR %.2f" % [JSON.stringify(q12_pers), str(q12_res.get("same", false)), float(q12u.P["stats"]["PWR"])],
		q12_pers == q12_profiles and q12_rt.dressed == q12r.dressed and str(q12_rt.dressed[2].get("talk", "")) == "plan" and bool(q12_res.get("ok", false)) and bool(q12_res.get("same", false)) \
		and q12u.pname() == "PRIYA" and absf(float(q12u.P["stats"]["PWR"]) - 36.75) < 0.0001 and count_events(q12u.events, "talk_effect", {"who": "PRIYA"}) == 1)

	# ================= PAC-073: the formation screen and the sealed order (NP_10 z2-3, NP_01 z7) ======
	var q13_fm: Dictionary = content["formation"]
	var q13_names := func(q13_arr: Array) -> Array:
		var q13_o: Array = []
		for q13_f in q13_arr: q13_o.append(str(q13_f["name"]) if q13_f is Dictionary else str(q13_f))
		return q13_o
	var q13_card8 := func(q13_nm: String) -> Dictionary:
		for q13_c in TNBSim.LINEUP_MILLBROOK_8:
			if str(q13_c["name"]) == q13_nm: return q13_c.duplicate(true)
		return {}
	# the data: the four named orders, the ace / anchor reads, the projection's sources, the scout stand-in, the Ep1 board; the decoy rate on the corners that run decoys
	var q13_rates := {}
	for q13_cid in content["coaches"]["coaches"]:
		var q13_cr: Dictionary = content["coaches"]["coaches"][q13_cid]
		if bool(q13_cr.get("decoys", false)) or q13_cr.has("decoy_rate"): q13_rates[q13_cid] = float(q13_cr.get("decoy_rate", -1.0))
	var q13_arch_ok := true; var q13_read := {}
	for q13_a in q13_fm["order"]:
		var q13_ar: Dictionary = q13_fm["archetypes"].get(str(q13_a), {})
		q13_read[q13_a] = int(q13_ar.get("readable_pct", -1))
		if str(q13_ar.get("label", "")) == "" or str(q13_ar.get("text", "")) == "" or int(q13_ar.get("readable_pct", -1)) < 0: q13_arch_ok = false
	_sr("the formation as data (NP_10 s2-3): the named orders %s, how readable each is %s; the ace read as %s, the anchor-class as %s; the tactician +%d, PI +%d a level, cap %d, silhouettes under %d; PRIYA scouts %s; the Ep1 board %s; the decoy rate on the corners that run decoys %s" % [JSON.stringify(q13_fm["order"]), JSON.stringify(q13_read), "+".join(PackedStringArray(q13_fm["ace"]["stats"])), "+".join(PackedStringArray(q13_fm["anchor"]["stats"])), int(content["staff"]["roles"]["Tactician"]["passive"]["projection_pct"]), int(q13_fm["projection"]["pi_pct_per_level"]), int(q13_fm["projection"]["cap_pct"]), int(q13_fm["projection"]["silhouette_below_pct"]), JSON.stringify(q13_fm["districts"][str(q13_fm["scouts"]["PRIYA"]["district"])]), JSON.stringify(q13_fm["boards"]["ep1"]["slots"]), JSON.stringify(q13_rates)],
		q13_fm["order"] == ["STANDARD", "AMBUSH", "WALL_FIRST", "RELAY_LADDER"] and q13_arch_ok and q13_fm["ace"]["stats"] == ["PWR", "SPD", "RFX"] and q13_fm["anchor"]["stats"] == ["CHN", "BLK", "STA"] and int(content["staff"]["roles"]["Tactician"]["passive"]["projection_pct"]) == 15 \
		and q13_fm["boards"]["ep1"]["slots"] == ["MARCUS", "PRIYA", "RORY"] and q13_fm["boards"]["ep1"]["reserves"] == ["JUNE"] and q13_rates == {"ascendant_a": 0.5, "hollow_circuit": 0.4} and "ascendant_b" in q13_fm["districts"]["toronto"])
	# the presets over the dressed: the ace and the anchor read from the cards, the four orders on the mini's three slots and the sanctioned dual's five
	var q13m := make_sim(0, 7)
	var q13s := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q13_pm := {}; var q13_ps := {}
	for q13_a in q13_fm["order"]: q13_pm[q13_a] = q13m.order_preset(str(q13_a))["slots"]; q13_ps[q13_a] = q13s.order_preset(str(q13_a))["slots"]
	var q13_hot: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true); q13_hot[0]["stats"]["PWR"] = 90
	var q13h := make_sim(1, 7, q13_hot, "sanctioned")
	var q13_hot_std: Array = q13h.order_preset("STANDARD")["slots"]
	var q13_kz := TNBSim.parse_kizuna_arg("RORY+SAM:50,SAM+MARCUS:50")
	var q13r := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, q13_kz)
	var q13_ladder: Array = q13r.order_preset("RELAY_LADDER")["slots"]
	var q13_adj := func(q13_sim: TNBSim, q13_sl: Array) -> int:
		var q13_n := 0
		for q13_i in range(1, q13_sl.size()):
			if q13_sim.kizuna_level(str(q13_sl[q13_i - 1]), str(q13_sl[q13_i])) >= 3: q13_n += 1
		return q13_n
	var q13_card_order: Array = ["RORY", "JUNE", "PRIYA", "MARCUS", "SAM"]
	_sr("the named orders as presets, the ace and the anchor read from the cards: the mini's (ace %s, anchor-class %s) %s; the sanctioned dual's (ace %s, anchor-class %s) %s; RORY at PWR 90 is the ace and Standard puts him at R4 %s; bonded RORY-SAM-MARCUS, the Relay Ladder chains them at R2-R3-R4 toward R5 %s (%d Adjacent Trust pairs beside each other, the card order %d)" % [q13m.order_preset("STANDARD")["ace"], q13m.order_preset("STANDARD")["anchor"], JSON.stringify(q13_pm), q13s.order_preset("STANDARD")["ace"], q13s.order_preset("STANDARD")["anchor"], JSON.stringify(q13_ps), JSON.stringify(q13_hot_std), JSON.stringify(q13_ladder), int(q13_adj.call(q13r, q13_ladder)), int(q13_adj.call(q13r, q13_card_order))],
		q13_pm["STANDARD"] == ["RORY", "MARCUS", "PRIYA"] and q13_pm["AMBUSH"] == ["PRIYA", "RORY", "MARCUS"] and q13_pm["WALL_FIRST"] == ["MARCUS", "RORY", "PRIYA"] and q13m.order_preset("AMBUSH")["reserves"] == ["JUNE"] \
		and q13_ps["STANDARD"] == ["RORY", "JUNE", "MARCUS", "PRIYA", "SAM"] and q13_ps["AMBUSH"] == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and q13_ps["WALL_FIRST"] == ["SAM", "RORY", "JUNE", "PRIYA", "MARCUS"] and q13s.order_preset("WALL_FIRST")["reserves"] == ["DEX", "YURI", "MARTA"] \
		and str(q13s.order_preset("STANDARD")["ace"]) == "PRIYA" and str(q13s.order_preset("STANDARD")["anchor"]) == "SAM" and q13_hot_std[3] == "RORY" and q13_ladder == ["JUNE", "RORY", "SAM", "MARCUS", "PRIYA"] \
		and int(q13_adj.call(q13r, q13_ladder)) == 2 and int(q13_adj.call(q13r, q13_card_order)) == 1)
	# the seal: the board the sim takes at setup is the order the dual fights - each segment sends the next slot - and the same board sealed from the formation screen before the bell is the same dual, to the hash
	var q13a := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "AMBUSH"})
	var q13_seal_ev: int = count_events(q13a.events, "board_sealed", {"archetype": "AMBUSH"}) + count_events(q13a.events, "sealed", {"archetype": "AMBUSH"})
	var q13b := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q13_sb: Dictionary = q13b.seal_board({"archetype": "AMBUSH"})
	var q13_same: bool = q13a.hash_state() == q13b.hash_state() and q13a.rng.state == q13b.rng.state
	var q13c0 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"slots": q13_card_order})
	var q13c1 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q13_walk := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "AMBUSH"}); quiet(q13_walk)
	var q13_out: Array = [q13_walk.pname()]
	for q13_i in 4:
		q13_walk._end_segment("clock"); q13_walk.corner_pick(0); q13_walk.corner_pick(0); q13_out.append(q13_walk.pname())
	_sr("the board sealed at setup (NP_01 s7): Ambush over the eight - R1..R5 %s, reserves %s, the seal on the events; the five go out in that order %s; the same board sealed from the formation screen before the bell is the same dual (%s, hash and RNG); a board of the card order hashes as no board at all (%s)" % [JSON.stringify(q13_names.call(q13a.lineup)), JSON.stringify(q13_names.call(q13a.reserves)), JSON.stringify(q13_out), str(q13_same), str(q13c0.hash_state() == q13c1.hash_state())],
		q13_names.call(q13a.lineup) == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and q13_names.call(q13a.reserves) == ["DEX", "YURI", "MARTA"] and q13a.sealed_p == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and q13_seal_ev == 2 \
		and q13_out == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and bool(q13_sb["ok"]) and q13_same and count_events(q13b.events, "board_sealed") == 1 and q13c0.hash_state() == q13c1.hash_state() and q13c0.board.size() > 0)
	# refused, naming why, nothing changed: after the bell; a card not dressed; a card twice; the wrong count; an order that does not exist; unknown or too many staff; reserves that are not the rest; a bad board at setup leaves the card order
	var q13_bell := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "AMBUSH"}); q13_bell.step({})
	var q13_h0: int = q13_bell.hash_state()
	var q13_rb: Dictionary = q13_bell.seal_board({"archetype": "STANDARD"})
	var q13_whys: Array = [str(q13_rb["why"])]
	var q13_bads: Array = [{"slots": ["RORY", "JUNE", "PRIYA", "MARCUS", "BOB"]}, {"slots": ["RORY", "RORY", "PRIYA", "MARCUS", "SAM"]}, {"slots": ["RORY", "JUNE", "PRIYA", "MARCUS"]}, {"archetype": "PHALANX"},
		{"archetype": "STANDARD", "staff": ["the_ghost"]}, {"archetype": "STANDARD", "staff": ["patch_job", "the_reveal", "raise_the_roof", "loosen_up"]}, {"archetype": "STANDARD", "reserves": ["DEX", "YURI", "RORY"]}, {"board": "ep9"}]
	var q13_untouched := true
	for q13_bd in q13_bads:
		var q13_t := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); var q13_th: int = q13_t.hash_state()
		var q13_r: Dictionary = q13_t.seal_board(q13_bd)
		q13_whys.append(str(q13_r["why"]))
		if bool(q13_r["ok"]) or q13_t.hash_state() != q13_th or q13_t.board.size() > 0: q13_untouched = false
	var q13_badset := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"slots": ["BOB"]})
	_sr("refused, naming why, nothing changed: %s; a bad board at setup leaves the card order (%s)" % [JSON.stringify(q13_whys), JSON.stringify(q13_names.call(q13_badset.lineup))],
		not bool(q13_rb["ok"]) and q13_bell.hash_state() == q13_h0 and str(q13_rb["why"]).begins_with("sealed at the bell") and q13_untouched and q13_whys.size() == 9 \
		and q13_names.call(q13_badset.lineup) == q13_card_order and q13_badset.board.is_empty() and count_events(q13_badset.events, "board_refused") == 1)
	# after the seal the corner is the reorder: DEX swapped into R2 goes out; the DualState keeps the seal and reveals who went out; a scrap still sends the first card and the dual after it is the board again; the save dresses the board back
	var q13k := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "AMBUSH"}); quiet(q13k); q13k._end_segment("clock"); q13k.corner_pick(0)
	q13k.corner_action({"kind": "swap", "arg": "DEX"}); q13k.corner_pick(0)
	var q13_ds: Dictionary = q13k.dual_state()
	var q13sc := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "AMBUSH"}); q13sc.start_scrap("SCR-01", 1)
	var q13_scrapper: String = q13sc.pname(); q13sc.end_bout()
	var q13_rec: Dictionary = TNBSave.to_save(q13a)
	var q13_st: Array = []; var q13_res_flags: Array = []
	for q13_f in q13_rec["stable"]:
		q13_st.append(str(q13_f["name"]))
		if bool(q13_f.get("reserve", false)): q13_res_flags.append(str(q13_f["name"]))
	var q13_ld = TNBSave.build(content, TNBSave.read_text(TNBSave.write_text(q13a, false)), 11)["sim"]
	_sr("after the seal the corner reorders: DEX swapped into R2 goes out (%s); the DualState's lineups sealed %s / revealed %s; a scrap still sends %s and the dual after it is the board again %s; the save writes the stable in the board's order %s (reserves %s) and a load dresses the same five %s" % [q13k.pname(), JSON.stringify(q13_ds["lineups"]["sealed"]), JSON.stringify(q13_ds["lineups"]["revealed"]), q13_scrapper, JSON.stringify(q13_names.call(q13sc.lineup)), JSON.stringify(q13_st), JSON.stringify(q13_res_flags), JSON.stringify(q13_names.call(q13_ld.lineup))],
		q13k.pname() == "DEX" and q13_ds["lineups"]["sealed"] == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and q13_ds["lineups"]["revealed"] == ["PRIYA", "DEX"] and str(q13_ds["lineups"]["board"]) == "AMBUSH" \
		and q13_scrapper == "RORY" and q13_names.call(q13sc.lineup) == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and q13_st == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM", "DEX", "YURI", "MARTA"] and q13_res_flags == ["DEX", "YURI", "MARTA"] \
		and q13_names.call(q13_ld.lineup) == ["PRIYA", "RORY", "JUNE", "MARCUS", "SAM"] and q13_names.call(q13_ld.reserves) == ["DEX", "YURI", "MARTA"])
	# Ep1 (NP_12A s5): Millbrook's four against Ascendant B - his corner reads Standard, Priya's binders on Toronto - "Ascendant's probable order at 70% confidence"; the Ep1 board from the data
	var q13e := make_sim(0, 7)
	var q13_pe: Dictionary = q13e.projection()
	var q13_ec: Array = []
	for q13_sl in q13_pe["slots"]: q13_ec.append(int(q13_sl["confidence"]))
	var q13_src: Array = []
	for q13_so in q13_pe["sources"]: q13_src.append("%s +%d" % [str(q13_so["what"]), int(q13_so["pct"])])
	var q13e1 := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, {"board": "ep1"})
	var q13_sealed_line := ""
	for q13_ev in q13e.events:
		if str(q13_ev["kind"]) == "feed" and str(q13_ev["text"]).begins_with("ORDERS SEALED"): q13_sealed_line = str(q13_ev["text"])
	_sr("Ep1's order-sealing tutorial reproduced: Millbrook's four vs %s - the order at %d%%, every slot %s, from %s; the Ep1 board from the data %s (reserve %s) is sealed and projects the same %d%%; the feed: \"%s\"" % [str(q13_pe["label"]), int(q13_pe["pct"]), JSON.stringify(q13_ec), " + ".join(PackedStringArray(q13_src)), JSON.stringify(q13e1.sealed_p), JSON.stringify(q13_names.call(q13e1.reserves)), int(q13e1.projection()["pct"]), q13_sealed_line],
		str(q13_pe["coach"]) == "ascendant_b" and int(q13_pe["pct"]) == 70 and q13_ec == [70, 70, 70] and q13_pe["sources"].size() == 2 and int(q13_pe["sources"][0]["pct"]) == 40 and str(q13_pe["sources"][1]["source"]) == "scout" and int(q13_pe["sources"][1]["pct"]) == 30 \
		and q13e1.sealed_p == ["MARCUS", "PRIYA", "RORY"] and q13_names.call(q13e1.reserves) == ["JUNE"] and str(q13e1.board["name"]) == "ep1" and int(q13e1.projection()["pct"]) == 70 and q13_sealed_line.ends_with("projected at 70%"))
	# each source moves the confidence by its own amount: his corner's archetype (a journeyman's Standard 40, the Grain Kings' Ambush 30 - silhouettes); Priya undressed -30; the tactician on the board +15 (and his Reveal in the corner); PI 2 on Yuri's dialect +10 on Yuri's slot only; the cap; a blind dual
	var q13_conf := func(q13_sim: TNBSim) -> Array:
		var q13_o: Array = []
		for q13_sl in q13_sim.projection()["slots"]: q13_o.append(int(q13_sl["confidence"]))
		return q13_o
	var q13j := make_sim(5, 7)
	var q13g := make_sim(1, 7)
	var q13_sil := true
	for q13_sl in q13g.projection()["slots"]:
		if not bool(q13_sl["silhouette"]) or str(q13_sl["name"]) != "": q13_sil = false
	var q13_nop: Array = []
	for q13_c in TNBSim.LINEUP_MILLBROOK:
		if str(q13_c["name"]) == "PRIYA": continue
		var q13_cc: Dictionary = q13_c.duplicate(true); q13_cc.erase("reserve"); q13_nop.append(q13_cc)
	var q13np := make_sim(0, 7, q13_nop)
	var q13t := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, {"archetype": "STANDARD", "staff": ["the_reveal", "patch_job", "raise_the_roof"]})
	var q13t_staff: Array = []; var q13_tconf: Array = q13_conf.call(q13t)
	quiet(q13t); q13t._end_segment("clock"); q13t.corner_pick(0)
	for q13_so in q13t.corner_options()["staff"]: q13t_staff.append(str(q13_so["id"]))
	var q13_after: Array = q13_conf.call(q13t); var q13_r1: Dictionary = q13t.projection()["slots"][0]; var q13_r2: Dictionary = q13t.projection()["slots"][1]
	var q13_rev: bool = q13t.corner_action({"kind": "staff", "id": "the_reveal"}) and count_events(q13t.events, "reveal") == 1
	var q13p := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", TNBSim.parse_pi_arg("kowalchuk:2", content.get("pattern_intel", {})))
	var q13cap := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", TNBSim.parse_pi_arg("cassidy_vane:3,yuri_kowalchuk:3,sam_tagaq:3", content.get("pattern_intel", {})), {}, {"archetype": "STANDARD", "staff": ["the_reveal"]})
	var q13bl := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "blind")
	var q13_blp: Dictionary = q13bl.projection()
	var q13_bl_ok: bool = bool(q13_blp["blind"]) and q13_blp["sources"].is_empty() and int(q13_blp["pct"]) == 0
	for q13_sl in q13_blp["slots"]:
		if not bool(q13_sl["silhouette"]) or int(q13_sl["confidence"]) != 0: q13_bl_ok = false
	_sr("each source moves the confidence by its own amount: a journeyman's Standard %s; the Grain Kings' Ambush %s, every slot a silhouette; Priya not dressed %s; the tactician on the board %s (and his Reveal in the corner: %s, %s; after R1 raised his PI the read sealed against stays %s, R1 revealed as %s, R2 not yet); PI 2 on Yuri's dialect %s (the order %d%%); three pages (PI 3) and the tactician, capped %s; the blind dual projects nothing (%s)" % [JSON.stringify(q13_conf.call(q13j)), JSON.stringify(q13_conf.call(q13g)), JSON.stringify(q13_conf.call(q13np)), JSON.stringify(q13_tconf), JSON.stringify(q13t_staff), str(q13_rev), JSON.stringify(q13_after), str(q13_r1["actual"]), JSON.stringify(q13_conf.call(q13p)), int(q13p.projection()["pct"]), JSON.stringify(q13_conf.call(q13cap)), str(q13_bl_ok)],
		q13_conf.call(q13j) == [40, 40, 40] and str(q13j.coach["id"]) == "journeyman" and q13_conf.call(q13g) == [30, 30, 30] and q13_sil and q13_conf.call(q13np) == [40, 40, 40] and q13_tconf == [85, 85, 85] and q13t_staff == ["patch_job", "the_reveal", "raise_the_roof"] and q13_rev and q13_after == q13_tconf and q13t.pi_vs() >= 1 \
		and bool(q13_r1["revealed"]) and str(q13_r1["actual"]) == "cassidy_vane" and not bool(q13_r2["revealed"]) and str(q13_r2["actual"]) == "" \
		and q13p.sealed_b[1] == "yuri_kowalchuk" and q13_conf.call(q13p) == [70, 80, 70] and int(q13p.projection()["pct"]) == 73 and q13_conf.call(q13cap) == [95, 95, 95] and q13_bl_ok and str(q13bl.feed) != "")
	# the percentage is honest: over 400 duals each, the projected names are right as often as the confidence says - at 70% (Ep1's) and at 40% (a journeyman's); a wrong slot always names one of his dressed, never twice; the seal's rolls never draw from the fight's RNG and do not move when your board is sealed
	var q13_cal := func(q13_sim: TNBSim, q13_n: int) -> Array:
		var q13_right := 0; var q13_all := 0; var q13_legal := true
		for q13_i in q13_n:
			q13_sim.new_dual()
			var q13_st0: int = q13_sim.rng.state
			var q13_pr: Dictionary = q13_sim.projection()
			if q13_sim.rng.state != q13_st0: q13_legal = false
			var q13_seen: Array = []
			for q13_sl in q13_pr["slots"]:
				q13_all += 1
				if bool(q13_sl["right"]): q13_right += 1
				if not (str(q13_sl["guess"]) in q13_sim.bdressed) or str(q13_sl["guess"]) in q13_seen: q13_legal = false
				q13_seen.append(str(q13_sl["guess"]))
		return [q13_right, q13_all, q13_legal]
	var q13_c70: Array = q13_cal.call(make_sim(0, 7), 400)
	var q13_c40: Array = q13_cal.call(make_sim(5, 7), 400)
	var q13_fix := make_sim(0, 9); var q13_p0: Dictionary = q13_fix.projection(); q13_fix.seal_board({"archetype": "AMBUSH"}); var q13_p1: Dictionary = q13_fix.projection()
	var q13_r70 := float(q13_c70[0]) / float(q13_c70[1]); var q13_r40 := float(q13_c40[0]) / float(q13_c40[1])
	_sr("the percentage is honest: at 70%% the projected names are right %d of %d (%.1f%%), at 40%% %d of %d (%.1f%%); every wrong name is one of his dressed and none is shown twice (%s); the fight's RNG is not drawn; your board sealed does not move his projection (%s)" % [int(q13_c70[0]), int(q13_c70[1]), 100.0 * q13_r70, int(q13_c40[0]), int(q13_c40[1]), 100.0 * q13_r40, str(bool(q13_c70[2]) and bool(q13_c40[2])), str(q13_p0["slots"] == q13_p1["slots"])],
		absf(q13_r70 - 0.70) <= 0.05 and absf(q13_r40 - 0.40) <= 0.05 and bool(q13_c70[2]) and bool(q13_c40[2]) and q13_p0["slots"] == q13_p1["slots"] and int(q13_c70[1]) == 1200)
	# the decoy seal (NP_10 s3): Director Vey's corner, decoy rate 0.5 - in the duals it runs one every name is shifted a slot and wrong while every percentage is as confident as the honest duals'; his sealed order is the one his archetype seals either way; a Lv1 tactician adds his 15 and is fooled, a Lv3 reads the decoy
	var q13v := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q13_dec := 0; var q13_dec_wrong := true; var q13_dec_conf := true; var q13_hon_r := 0; var q13_hon_n := 0; var q13_first := -1; var q13_same_seal := true
	for q13_i in 400:
		q13v.new_dual()
		var q13_pr: Dictionary = q13v.projection()
		if q13v.sealed_b != q13v.blineup: q13_same_seal = false
		if bool(q13_pr["decoy"]):
			q13_dec += 1
			if q13_first < 0: q13_first = q13v.seal_n
			for q13_j in q13_pr["slots"].size():
				var q13_sl: Dictionary = q13_pr["slots"][q13_j]
				if bool(q13_sl["right"]) or str(q13_sl["guess"]) != str(q13v.sealed_b[(q13_j + 1) % q13v.sealed_b.size()]): q13_dec_wrong = false
				if int(q13_sl["confidence"]) != 70 or bool(q13_sl["silhouette"]): q13_dec_conf = false
		else:
			for q13_sl in q13_pr["slots"]:
				q13_hon_n += 1
				if bool(q13_sl["right"]): q13_hon_r += 1
	var q13_keep: Dictionary = content
	content = q13_keep.duplicate(true); content["coaches"]["coaches"]["ascendant_a"]["decoys"] = false
	var q13nd := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	content = q13_keep
	var q13vd := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	for q13_i in q13_first: q13nd.new_dual(); q13vd.new_dual()
	var q13_t1 := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "STANDARD", "staff": ["the_reveal", "patch_job", "raise_the_roof"]})
	var q13_t3 := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, TNBSim.seed_staff(TNBSim.parse_kizuna_arg(""), "the_reveal:3", content["staff"]), {"archetype": "STANDARD", "staff": ["the_reveal", "patch_job", "raise_the_roof"]})   # since PAC-074 the Lv3 is earned: 8 uses on the ledger
	for q13_i in q13_first: q13_t1.new_dual(); q13_t3.new_dual()
	var q13_pt1: Dictionary = q13_t1.projection(); var q13_pt3: Dictionary = q13_t3.projection()
	var q13_t3_blank := true
	for q13_sl in q13_pt3["slots"]:
		if str(q13_sl["name"]) != "" or int(q13_sl["confidence"]) != 0 or not bool(q13_sl["decoy"]): q13_t3_blank = false
	var q13_dline := false
	for q13_ln in q13_t3.formation_lines():
		if str(q13_ln).contains("DECOY SEAL"): q13_dline = true
	_sr("the decoy seal: Vey's corner runs one in %d of 400 duals - there every projected name is shifted a slot and wrong (%s) at the honest 70%% (%s), while the honest duals are right %d of %d; the order he fights is the one he sealed in every dual (%s) and the dual with his decoys taken out is the same fight, to the hash (%s); a Lv1 tactician adds 15 (%d%%) and is fooled (%s), a Lv3 reads it - every slot a DECOY silhouette (%s)" % [q13_dec, str(q13_dec_wrong), str(q13_dec_conf), q13_hon_r, q13_hon_n, str(q13_same_seal), str(q13nd.hash_state() == q13vd.hash_state() and q13vd.bdecoy and not q13nd.bdecoy), int(q13_pt1["pct"]), str(bool(q13_pt1["decoy"]) and not bool(q13_pt1["detected"])), str(q13_t3_blank)],
		q13_dec >= 168 and q13_dec <= 232 and q13_dec_wrong and q13_dec_conf and absf(float(q13_hon_r) / float(maxi(1, q13_hon_n)) - 0.70) <= 0.05 and q13_same_seal and q13_first > 0 \
		and q13nd.hash_state() == q13vd.hash_state() and q13vd.bdecoy and not q13nd.bdecoy and int(q13_pt1["pct"]) == 85 and bool(q13_pt1["decoy"]) and not bool(q13_pt1["detected"]) and bool(q13_pt3["detected"]) and q13_t3_blank and q13_dline and int(q13_pt3["pct"]) == 0)
	# the overlay (NP_10 s2 / NP_06 s5): Ep1's board read against Ascendant B - MARCUS countered on both rings (NP_12A: "the matchup card says so pre-segment"), PRIYA ahead on both, RORY the purist's; the doc's worked example 2 (a Swarmer/Frost of Tremblay vs a Moreau Slugger: the fuel segment); the overlay is the segment's own matchup card, slot for slot
	var q13_mv: Dictionary = q13e1.pairing(q13e1._card_of("MARCUS"), "cassidy_vane")
	var q13_py: Dictionary = q13e1.pairing(q13e1._card_of("PRIYA"), "yuri_kowalchuk")
	var q13_rs: Dictionary = q13e1.pairing(q13e1._card_of("RORY"), "sam_tagaq")
	var q13_ex2: Dictionary = q13e1.pairing({"name": "EXAMPLE", "style": "SWARMER", "element": "FROST", "house": "tremblay"}, "remy_moreau")
	var q13_ov_ok := true; var q13_ov_n := 0
	for q13_o in q13e1.overlay():
		var q13_psl: Dictionary = q13e1.projection()["slots"][int(q13_o["slot"]) - 1]
		if bool(q13_o["unknown"]) != bool(q13_psl["silhouette"]): q13_ov_ok = false
		if not bool(q13_o["unknown"]):
			q13_ov_n += 1
			var q13_pp: Dictionary = q13e1.pairing(q13e1._card_of(str(q13_o["p_name"])), str(q13_psl["name"]))
			if str(q13_pp["line"]) != str(q13_o["line"]) or str(q13_pp["note"]) != str(q13_o["note"]) or int(q13_pp["ep_pct"]) != int(q13_o["ep_pct"]): q13_ov_ok = false
	var q13_all_unknown := true
	for q13_o in q13g.overlay():
		if not bool(q13_o["unknown"]): q13_all_unknown = false
	var q13_mc_ok := true; var q13_mc_n := 0; var q13_mc_feud := 0
	for q13_case in [[17, {"slots": ["DEX", "MARTA", "YURI", "SAM", "PRIYA"]}], [6, {"archetype": "WALL_FIRST"}]]:
		var q13w := make_sim(int(q13_case[0]), 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, q13_case[1]); quiet(q13w)
		for q13_i in 5:
			var q13_pw: Dictionary = q13w.pairing(q13w.lineup[q13w.seg_idx], q13w.boss_name)
			q13_mc_n += 1
			if bool(q13w.aff["feud"]): q13_mc_feud += 1
			for q13_k in ["style_adv", "element_adv", "feud", "line", "p", "b"]:
				if str(q13_pw[q13_k]) != str(q13w.aff[q13_k]): q13_mc_ok = false
			if q13_i < 4: q13w._end_segment("clock"); q13w.corner_pick(0); q13w.corner_pick(0)
	_sr("the overlay: MARCUS vs Vane - %s / %s, EP %d%%, hissatsu %d%%: \"%s\"; PRIYA vs Yuri - EP %+d%%: \"%s\"; RORY vs Sam: \"%s\"; worked example 2 - his %s, FEUD Tension +%d%%: \"%s\"; on the Ep1 board %d shown pairings read as pairing() does, silhouettes as unknown; the Grain Kings' board all unknown (%s); %d segments fought, the overlay's rings equal to the matchup card at each bell (%s, %d with a FEUD, Vey in his opening kit)" % [str(q13_mv["style_adv"]), str(q13_mv["element_adv"]), int(q13_mv["ep_pct"]), int(q13_mv["hiss_pct"]), str(q13_mv["note"]), int(q13_py["ep_pct"]), str(q13_py["note"]), str(q13_rs["note"]), "style" if str(q13_ex2["style_adv"]) == "B" else "?", int(q13_ex2["tension_pct"]), str(q13_ex2["note"]), q13_ov_n, str(q13_all_unknown), q13_mc_n, str(q13_mc_ok), q13_mc_feud],
		str(q13_mv["style_adv"]) == "B" and str(q13_mv["element_adv"]) == "B" and int(q13_mv["ep_pct"]) == -10 and int(q13_mv["hiss_pct"]) == -10 and str(q13_mv["note"]) == "Cassidy Vane eats sluggers for breakfast" \
		and str(q13_py["style_adv"]) == "P" and str(q13_py["element_adv"]) == "P" and int(q13_py["ep_pct"]) == 10 and str(q13_rs["note"]).begins_with("The purist's matchup") and str(q13_rs["style_adv"]) == "" \
		and str(q13_ex2["style_adv"]) == "B" and bool(q13_ex2["feud"]) and int(q13_ex2["tension_pct"]) == 25 and int(q13_ex2["ep_pct"]) == -10 and str(q13_ex2["note"]) == "Bad wind for us, but this segment will PRINT Tension" \
		and q13_ov_ok and q13_all_unknown and q13_mc_ok and q13_mc_n == 10 and q13_mc_feud >= 1)

	# ================= PAC-074: the staff system (NP_10 z6) and the crowd (NP_01 z1) ======
	var q14_st: Dictionary = content["staff"]
	var q14_led := func(q14_s: String) -> Dictionary: return TNBSim.seed_staff(TNBSim.parse_kizuna_arg(""), q14_s, q14_st)
	# the data: five roles each with a passive and a second at Lv3, a corps of ten each carrying his role's active from tactics.v1.json, the Professor the one rare, the levels, the crowd; the default three
	var q14_act := {}
	for q14_a in content["tactics"]["staff_active"]: q14_act[str(q14_a["id"])] = str(q14_a["role"])
	var q14_roles_ok := true; var q14_by_role := {}
	for q14_r in q14_st["roles"]:
		var q14_rr: Dictionary = q14_st["roles"][q14_r]
		if q14_rr.get("passive", {}).is_empty() or q14_rr.get("lv3", {}).is_empty() or str(q14_rr.get("passive_text", "")) == "" or str(q14_rr.get("lv3_text", "")) == "": q14_roles_ok = false
	var q14_corps_ok := true
	for q14_c in q14_st["corps"]:
		q14_by_role[str(q14_c["role"])] = int(q14_by_role.get(str(q14_c["role"]), 0)) + 1
		if str(q14_act.get(str(q14_c["active"]), "?")) != str(q14_c["role"]) or not q14_st["roles"].has(str(q14_c["role"])): q14_corps_ok = false
	var q14d := make_sim(0, 7)
	_sr("the staff as data (NP_10 s6): %d roles %s, each a passive and a second at Lv3; a corps of %d (cap %d) %s, each carrying his role's active; levels by use %s; the crowd %s, Raise the Roof converting %d; the default dressed three %s" % [q14_st["roles"].size(), JSON.stringify(q14_st["roles"].keys()), q14_st["corps"].size(), int(q14_st["corps_cap"]), JSON.stringify(q14_by_role), JSON.stringify(q14_st["levels"]), JSON.stringify(q14_st["crowd"]["sources"]), int(q14_st["crowd"]["converts"]["raise_the_roof"]["needs"]), JSON.stringify(q14d.staff_dressed())],
		q14_st["roles"].size() == 5 and q14_roles_ok and q14_st["corps"].size() == 10 and int(q14_st["corps_cap"]) == 10 and int(q14_st["dressed"]) == 3 and q14_corps_ok and int(q14_by_role.get("The Professor", 0)) == 1 and bool(q14_st["roles"]["The Professor"].get("rare", false)) \
		and int(q14_st["levels"]["2"]) == 3 and int(q14_st["levels"]["3"]) == 8 and q14_st["levels"].size() == 2 and q14d.staff_dressed() == ["sportsmed", "janitor", "retired_boxer"] and bool(q14_st["roles"]["Tactician"]["lv3"]["detect_decoys"]) and int(q14_st["roles"]["Hype"]["lv3"]["tension_start"]) == 10)
	# the board dresses the corps: by staffer or by the active he carries; two of a role pool their charges and are credited in turn; a board of staff alone keeps the card order; the refusals
	var q14b := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "STANDARD", "staff": ["old_cutman", "sportsmed", "the_reveal"]})
	quiet(q14b); to_corner.call(q14b, 0.0)
	var q14_menu: Array = q14b.corner_options()["staff"]
	var q14_pj: Dictionary = q14_menu[0] if q14_menu.size() > 0 else {}
	var q14_named: bool = q14b.corner_action({"kind": "staff", "id": "old_cutman"}); q14b.corner_action({"kind": "staff", "id": "patch_job"})
	var q14_after2 := [q14b.staff_uses("old_cutman"), q14b.staff_uses("sportsmed")]
	q14b.step({"corner": 1}); to_corner.call(q14b, 0.0)
	q14b.corner_action({"kind": "staff", "id": "patch_job"}); q14b.corner_action({"kind": "staff", "id": "patch_job"})
	var q14_after4 := [q14b.staff_uses("old_cutman"), q14b.staff_uses("sportsmed")]
	q14b.step({"corner": 1}); to_corner.call(q14b, 0.0)
	var q14_fifth: bool = q14b.corner_action({"kind": "staff", "id": "patch_job"})
	var q14_undressed: bool = q14b.corner_action({"kind": "staff", "id": "janitor"})
	var q14so := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"staff": ["professor", "physio", "janitor"]})
	var q14_whys: Array = []
	for q14_bd in [{"staff": ["professor", "professor"]}, {"staff": ["nobody"]}, {"staff": ["physio", "janitor", "professor", "sportsmed"]}, {"archetype": "STANDARD", "staff": ["janitor"], "staff_levels": {"janitor": 3}}]:
		var q14_t := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
		var q14_rr: Dictionary = q14_t.seal_board(q14_bd); q14_whys.append(str(q14_rr["why"]))
		if bool(q14_rr["ok"]): q14_whys.append("SEALED")
	_sr("the board dresses the corps: %s; Patch Job pooled at %d charges by %s; the named cutman and the pool (uses %s after two, %s after four), the fifth refused (%s), an undressed staffer refused (%s); a board of staff alone keeps the card order %s; refused: %s" % [JSON.stringify(q14b.staff_dressed()), int(q14_pj.get("charges", 0)), JSON.stringify(q14_pj.get("by", [])), JSON.stringify(q14_after2), JSON.stringify(q14_after4), str(q14_fifth), str(q14_undressed), JSON.stringify(q14so.sealed_p), JSON.stringify(q14_whys)],
		q14b.staff_dressed() == ["old_cutman", "sportsmed", "rival_cornerman"] and str(q14_pj.get("id", "")) == "patch_job" and int(q14_pj.get("charges", 0)) == 4 and q14_named and q14_after2 == [2, 0] and q14_after4 == [2, 2] and not q14_fifth and not q14_undressed \
		and q14so.staff_dressed() == ["professor", "physio", "janitor"] and q14so.sealed_p == ["RORY", "JUNE", "PRIYA", "MARCUS", "SAM"] \
		and q14_whys == ["the Professor is dressed twice", "no staff 'nobody'", "4 staff on a board of 3 staff slots", "a staffer's level is earned by use (the ledger), not declared on a board"])
	# levels by use: eight duals of the Reveal - Lv2 at the third, Lv3 at the eighth with its second passive named; the ledger carries it over new duals; earned, the Lv3 reads Vey's decoy (the same board at Lv1 is fooled)
	var q14l := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "STANDARD", "staff": ["the_reveal", "patch_job", "raise_the_roof"]})
	var q14_lv_ev: Array = []; var q14_lv_at: Array = []
	for q14_i in 8:
		q14l.new_dual(); quiet(q14l); to_corner.call(q14l, 0.0)
		q14l.corner_action({"kind": "staff", "id": "the_reveal"})
		for q14_e in q14l.events:
			if str(q14_e["kind"]) == "staff_level": q14_lv_ev.append("Lv%d at use %d%s" % [int(q14_e["level"]), q14l.staff_uses("rival_cornerman"), (" (" + str(q14_e["unlocked"]) + ")") if str(q14_e["unlocked"]) != "" else ""]); q14_lv_at.append(q14l.staff_uses("rival_cornerman"))
	var q14_found := false; var q14_read := false; var q14_n := 0
	var q14f := make_sim(6, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, {}, {"archetype": "STANDARD", "staff": ["the_reveal", "patch_job", "raise_the_roof"]})
	for q14_i in 30:
		q14l.new_dual(); q14f.new_dual()
		while q14f.seal_n < q14l.seal_n: q14f.new_dual()
		if q14l.bdecoy:
			q14_found = true; q14_n = q14l.seal_n
			q14_read = bool(q14l.projection()["detected"]) and bool(q14f.bdecoy) and not bool(q14f.projection()["detected"])
			break
	_sr("levels by use: eight duals of the Reveal - %s; the ledger holds %d uses and Lv%d across new duals; in dual %d Vey's corner runs a decoy: the earned Lv3 reads it (%s), the same board unearned is fooled" % [JSON.stringify(q14_lv_ev), q14l.staff_uses("rival_cornerman"), q14l.staff_level("rival_cornerman"), q14_n, str(q14_read)],
		q14_lv_at == [3, 8] and q14l.staff_uses("rival_cornerman") == 8 and q14l.staff_level("rival_cornerman") == 3 and q14_found and q14_read and q14f.staff_level("rival_cornerman") == 1)
	# the cutman (corner stamina +15; Lv3 composure +10): RORY back for R4 of an Iron dual at the 40 / 20 he left with - bare without a cutman, +15 with one, +30 with two, +15 / +10 at Lv3; a fresh fighter gets nothing
	var q14_ir := func(q14_bd: Dictionary, q14_lg: Dictionary) -> Array:
		var q14_s := make_sim(0, 7, l3, "iron", {}, q14_lg, q14_bd); quiet(q14_s)
		q14_s.P["stamina"] = 40.0; q14_s.P["comp"] = 20.0
		seg_end.call(q14_s); next_segment(q14_s)
		var q14_fresh: float = q14_s.P["stamina"]; var q14_fresh_ev := count_events(q14_s.events, "staff_passive", {"what": "corner_restore"})
		seg_end.call(q14_s); next_segment(q14_s); seg_end.call(q14_s); next_segment(q14_s)
		return [q14_s.pname(), snappedf(float(q14_s.P["stamina"]), 0.01), snappedf(float(q14_s.P["comp"]), 0.01), q14_fresh, q14_fresh_ev]
	var q14_bare: Array = q14_ir.call({"staff": ["physio", "janitor", "professor"]}, {})
	var q14_one: Array = q14_ir.call({}, {})
	var q14_two: Array = q14_ir.call({"staff": ["sportsmed", "old_cutman", "janitor"]}, {})
	var q14_three: Array = q14_ir.call({}, q14_led.call("sportsmed:3"))
	_sr("the cutman on the stool: RORY back for R4 of an Iron dual at the 40 stamina / 20 composure he left with - no cutman %s, the sports-med student %s, two cutmen %s, the student at Lv3 %s; PRIYA fresh in R2 at %.0f with no restore" % [JSON.stringify(q14_bare.slice(1, 3)), JSON.stringify(q14_one.slice(1, 3)), JSON.stringify(q14_two.slice(1, 3)), JSON.stringify(q14_three.slice(1, 3)), float(q14_one[3])],
		str(q14_bare[0]) == "RORY" and q14_bare.slice(1, 3) == [40.0, 20.0] and q14_one.slice(1, 3) == [55.0, 20.0] and q14_two.slice(1, 3) == [70.0, 20.0] and q14_three.slice(1, 3) == [55.0, 30.0] and float(q14_one[3]) == 100.0 and int(q14_one[4]) == 0)
	# the conditioning coach (team stamina regen +10%; Lv3: an overrun corner sends the fighter out at 90, not 80): two seconds of rest from 50 stamina - bare, one, three; the overrun at Lv1 and Lv3
	var q14_rest := func(q14_bd: Dictionary) -> float:
		var q14_s := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, q14_bd); quiet(q14_s); place(q14_s, 3.0); q14_s.P["stamina"] = 50.0
		run_ticks(q14_s, 240)
		return float(q14_s.P["stamina"]) - 50.0
	var q14_g0: float = q14_rest.call({"staff": ["sportsmed", "janitor", "professor"]})
	var q14_g1: float = q14_rest.call({"staff": ["sportsmed", "janitor", "retired_boxer"]})
	var q14_g3: float = q14_rest.call({"staff": ["retired_boxer", "physio", "track_coach"]})
	var q14_over := func(q14_lg: Dictionary) -> float:
		var q14_s := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q14_lg); quiet(q14_s); to_corner.call(q14_s, 0.0)
		run_ticks(q14_s, TNBSim.ms(45000) - 1); q14_s.step({})                                                # the overrun tick itself (as the PAC-058 timer gate)
		return float(q14_s.P["stamina"])
	var q14_o1: float = q14_over.call({}); var q14_o3: float = q14_over.call(q14_led.call("retired_boxer:3"))
	_sr("the conditioning coach: two seconds' rest from 50 stamina regains %.3f bare, %.3f with the retired boxer (x%.3f), %.3f with three coaches (x%.3f); an overrun corner sends the next fighter out at %.0f, at %.0f with the retired boxer at Lv3" % [q14_g0, q14_g1, q14_g1 / maxf(0.0001, q14_g0), q14_g3, q14_g3 / maxf(0.0001, q14_g0), q14_o1, q14_o3],
		q14_g0 > 0.0 and absf(q14_g1 / q14_g0 - 1.1) < 0.002 and absf(q14_g3 / q14_g0 - 1.3) < 0.002 and absf(q14_o1 - 80.0) < 0.01 and absf(q14_o3 - 90.0) < 0.01)
	# the crowd and the Hype: your own spectacle heats the building (+20% with the janitor), never his; Raise the Roof refused below 30 (charge and action kept), then 30 heat for +8 Tension; the janitor at Lv3 starts the dual at 10 Tension
	var q14_heat := func(q14_bd: Dictionary) -> Array:
		var q14_s := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, q14_bd); quiet(q14_s)
		var q14_o: Array = []
		for q14_ev in [["drop", {"who": "B"}], ["hit", {"on": "B", "flash": true, "counter": true}], ["hit", {"on": "B", "counter": true}], ["interrupt", {}], ["eight_up", {}], ["cast_resolve", {"who": "P"}], ["drop", {"who": "P"}], ["hit", {"on": "P", "counter": true}], ["cast_resolve", {"who": "B"}]]:
			var q14_h0: float = q14_s.crowd_heat; q14_s._ev(str(q14_ev[0]), q14_ev[1]); q14_o.append(snappedf(q14_s.crowd_heat - q14_h0, 0.01))
		return q14_o
	var q14_hb: Array = q14_heat.call({"staff": ["sportsmed", "physio", "professor"]})
	var q14_hh: Array = q14_heat.call({})
	var q14r := make_sim(0, 7); quiet(q14r); to_corner.call(q14r, 0.0); q14r.crowd_heat = 20.0
	var q14_t0: float = q14r.tension
	var q14_cold: bool = q14r.corner_action({"kind": "staff", "id": "raise_the_roof"})
	var q14_cold_kept: bool = int(q14r.corner["actions_left"]) == 2 and int(q14r.staff_charges["raise_the_roof"]) == 2 and count_events(q14r.events, "corner_refused", {"why": "the crowd isn't there yet - heat 20 of 30"}) == 1
	q14r.crowd_heat = 36.0
	var q14_hot: bool = q14r.corner_action({"kind": "staff", "id": "raise_the_roof"})
	var q14ts := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q14_led.call("janitor:3"))
	_sr("the crowd: drop / flash / counter / interrupt / up at eight / hissatsu heat the building %s bare, %s with the janitor (x1.2), and his spectacle nothing; Raise the Roof at 20 heat refused, charge and action kept (%s), at 36 it lands: +%.0f Tension, heat left %.0f; the janitor at Lv3 starts the dual at %.0f Tension (his %.0f), the Lv1 janitor at %.0f" % [JSON.stringify(q14_hb.slice(0, 6)), JSON.stringify(q14_hh.slice(0, 6)), str(q14_cold_kept), q14r.tension - q14_t0, q14r.crowd_heat, q14ts.tension, q14ts.btension, q14d.tension],
		q14_hb == [20.0, 10.0, 5.0, 6.0, 15.0, 8.0, 0.0, 0.0, 0.0] and q14_hh == [24.0, 12.0, 6.0, 7.2, 18.0, 9.6, 0.0, 0.0, 0.0] and not q14_cold and q14_cold_kept and q14_hot and absf(q14r.tension - q14_t0 - 8.0) < 0.01 and absf(q14r.crowd_heat - 6.0) < 0.01 \
		and absf(q14ts.tension - 10.0) < 0.01 and q14ts.btension == 0.0 and q14d.tension == 0.0 and count_events(q14ts.events, "staff_passive", {"what": "tension_start"}) == 1)
	# the Professor (PI gains x2 in duals; Lv3: in scraps and spars too) and the tactician's richer page, two tacticians on the projection
	var q14pa := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, {"staff": ["professor", "sportsmed", "janitor"]}); quiet(q14pa); q14pa._end_segment("clock")
	var q14pb := make_sim(1, 7); quiet(q14pb); q14pb._end_segment("clock")
	var q14ps1 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, {"staff": ["professor", "sportsmed", "janitor"]}); q14ps1.start_spar(1); q14ps1._end_bout()
	var q14ps3 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q14_led.call("professor:3"), {"staff": ["professor", "sportsmed", "janitor"]}); q14ps3.start_spar(1); q14ps3._end_bout()
	var q14_seg := func(q14_s: TNBSim, q14_src: String) -> int: return int(q14_s.pi["dialects"].get("kowalchuk", {}).get(q14_src, 0))
	var q14_page_led := TNBSim.parse_pi_arg("yuri_kowalchuk:3", content.get("pattern_intel", {}))
	var q14pg0 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", q14_page_led)
	var q14pg1 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", q14_page_led, {}, {"staff": ["the_reveal", "sportsmed", "janitor"]})
	var q14_pn: Dictionary = q14pg1.scout_page("yuri_kowalchuk").get("tactician", {})
	var q14tt := make_sim(5, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {}, {"staff": ["rival_cornerman", "tape_man", "janitor"]})
	var q14_tconf: Array = []
	for q14_sl in q14tt.projection()["slots"]: q14_tconf.append(int(q14_sl["confidence"]))
	_sr("the Professor: a dual segment vs Yuri counts %d on Kowalchuk (%d without him); a spar %d at Lv1, %d at Lv3; the tactician's richer page on Yuri %s (none without one: %s); two tacticians on a journeyman's board %s" % [q14_seg.call(q14pa, "segments"), q14_seg.call(q14pb, "segments"), q14_seg.call(q14ps1, "spars"), q14_seg.call(q14ps3, "spars"), JSON.stringify(q14_pn), JSON.stringify(q14pg0.scout_page("yuri_kowalchuk").get("tactician", {})), JSON.stringify(q14_tconf)],
		q14_seg.call(q14pa, "segments") == 2 and q14_seg.call(q14pb, "segments") == 1 and q14_seg.call(q14ps1, "spars") == 1 and q14_seg.call(q14ps3, "spars") == 2 \
		and str(q14_pn.get("order", "")) == "Ambush" and str(q14_pn.get("slot", "")) == "R4" and q14_pn.get("by", []) == ["the rival cornerman"] and q14pg0.scout_page("yuri_kowalchuk").get("tactician", {}).is_empty() and q14_tconf == [70, 70, 70])
	# the save writes the corps (NP_11 s9 Staff): ten records with level, uses, passives, the active and its charges, the dressed three in their slots; a load dresses them back with their levels; a default dual's save loads with no board sealed
	var q14sv := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q14_led.call("professor:3,the_reveal:2"), {"staff": ["professor", "old_cutman", "the_reveal"]})
	var q14_rec: Dictionary = TNBSave.to_save(q14sv)
	var q14_dr: Array = ["", "", ""]; var q14_prof: Dictionary = {}
	for q14_r in q14_rec["staff"]:
		if bool(q14_r["dressed"]): q14_dr[int(q14_r["dressed_slot"])] = "%s@%d Lv%d" % [str(q14_r["id"]), int(q14_r["dressed_slot"]), int(q14_r["level"])]
		if str(q14_r["id"]) == "professor": q14_prof = q14_r
	var q14ld = TNBSave.build(content, TNBSave.read_text(TNBSave.write_text(q14sv, false)), 5)["sim"]
	var q14ld0 = TNBSave.build(content, TNBSave.read_text(TNBSave.write_text(make_sim(1, 7), false)), 5)["sim"]
	_sr("the save writes the corps: %d Staff records, dressed %s, the Professor %s; a load dresses %s at Lv %d / %d / %d; a default dual's save loads with no board (%s)" % [q14_rec["staff"].size(), JSON.stringify(q14_dr), JSON.stringify({"passives": q14_prof.get("passives", []), "active": q14_prof.get("active", {}).get("id", ""), "uses": q14_prof.get("uses", 0)}), JSON.stringify(q14ld.staff_dressed()), q14ld.staff_level("professor"), q14ld.staff_level("old_cutman"), q14ld.staff_level("rival_cornerman"), JSON.stringify(q14ld0.staff_dressed())],
		q14_rec["staff"].size() == 10 and q14_dr == ["professor@0 Lv3", "old_cutman@1 Lv1", "rival_cornerman@2 Lv2"] and q14_prof.get("passives", []).size() == 2 and int(q14_prof.get("uses", 0)) == 8 and str(q14_prof.get("active", {}).get("id", "")) == "chalk_talk" \
		and q14ld.staff_dressed() == ["professor", "old_cutman", "rival_cornerman"] and q14ld.staff_level("professor") == 3 and q14ld.staff_level("rival_cornerman") == 2 and q14ld.sealed_p == ["RORY", "PRIYA", "MARCUS"] and q14ld0.board.is_empty() and q14ld0.staff_dressed() == ["sportsmed", "janitor", "retired_boxer"])

	# ================= PAC-075: recruitment (NP_08 z2) ======
	var q15_rc: Dictionary = content["recruits"]
	var q15_win := func(q15_s: TNBSim) -> void:                 # a dual won on segments (no fight): each segment's EP to Millbrook
		for q15_i in q15_s.segments():
			seg_end.call(q15_s, 4)
			if q15_s.mode != "OVER": next_segment(q15_s)
	var q15_lose := func(q15_s: TNBSim) -> void:
		for q15_i in q15_s.segments():
			seg_end.call(q15_s, -4)
			if q15_s.mode != "OVER": next_segment(q15_s)
	var q15_spar_win := func(q15_s: TNBSim, q15_bi: int) -> void: q15_s.start_spar(q15_bi); q15_s.ep_p = 10; q15_s._end_bout(); q15_s.end_bout()
	var q15_scrap_win := func(q15_s: TNBSim, q15_bi: int) -> void: q15_s.start_scrap("SCR-01", q15_bi); q15_s.obj["met"] = true; q15_s.obj["why"] = "objective"; q15_s._end_bout(); q15_s.end_bout()
	var q15_names := func(q15_arr: Array) -> Array: return q15_arr.map(func(x): return str(x["name"]) if x is Dictionary else str(x))
	# the data: all 24 bosses and Dex carry a record - a condition in NP_08 s2.2's grammar with its source, or the reason the docs close them; the forms split sim / overworld; the cards
	var q15a := make_sim(0, 7)
	var q15_conds := 0; var q15_nevers := 0; var q15_forms := {}; var q15_bad: Array = []; var q15_cards_ok := true; var q15_cardlog: Array = []
	for q15_nm in q15_rc["recruits"]:
		var q15_r: Dictionary = q15_rc["recruits"][q15_nm]
		if str(q15_r.get("source", "")) == "": q15_bad.append(str(q15_nm) + ": no source")
		if q15_r.has("never"): q15_nevers += 1; continue
		q15_conds += 1
		for q15_c in TNBSim.parse_condition(str(q15_r["condition"])):
			q15_forms[str(q15_c["form"])] = true
			if not q15_rc["grammar"].has(str(q15_c["form"])) or str(q15_c.get("style", "")) == "?": q15_bad.append("%s: %s" % [q15_nm, q15_c["text"]])
		var q15_cd: Dictionary = q15a.recruit_card(str(q15_nm))
		if not content["library"].has(str(q15_cd.get("hissatsu", ""))) or str(q15_cd.get("name", "")) != str(q15_r["card"]): q15_cards_ok = false
		if not bool(q15_r.get("from_lineup", false)):
			q15_cardlog.append("%s %s/%s/%s %d" % [str(q15_cd["name"]), str(q15_cd["style"]), str(q15_cd["element"]), str(q15_cd["house"]), int(q15_cd["stats"]["PWR"])])
			if str(q15_cd["style"]) != str(q15a.boss_rings(str(q15_nm))[0]) or int(q15_cd["stats"]["PWR"]) != 70 or q15_cd.has("reserve"): q15_cards_ok = false
	var q15_missing: Array = []
	for q15_b in TNBSim.BOSSES:
		if not q15_rc["recruits"].has(q15_b): q15_missing.append(q15_b)
	var q15_owner := {"sim": [], "overworld": []}
	for q15_f in q15_rc["grammar"]: q15_owner[str(q15_rc["grammar"][q15_f]["owner"])].append(str(q15_f))
	_sr("recruitment as data (NP_08 s2): %d records - %d conditions, %d closed by the docs (%s) - every boss covered (missing %s), every source cited; the grammar's %d forms, the sim reading %s, the overworld's flags %s; the conditions use %s; the new cards %s" % [q15_rc["recruits"].size(), q15_conds, q15_nevers, str(q15_rc["recruits"]["anders_vey"]["never"]), JSON.stringify(q15_missing), q15_rc["grammar"].size(), JSON.stringify(q15_owner["sim"]), JSON.stringify(q15_owner["overworld"]), JSON.stringify(q15_forms.keys()), JSON.stringify(q15_cardlog)],
		q15_rc["recruits"].size() == 25 and q15_conds == 13 and q15_nevers == 12 and q15_missing.is_empty() and q15_bad.is_empty() and q15_cards_ok and q15_owner["sim"].size() == 7 and q15_owner["overworld"].size() == 4, JSON.stringify(q15_bad))   # PAC-101: REP is the sim's (the district rep ledger)
	# a dual won flags the recruitable named fighters of the squad beaten (the docs' closed ones never; the cap of 4; a card already in the stable is his); a dual lost flags nobody; before the approach nothing of the condition shows
	# (PAC-076: JEAN-GUY recruitable in Arc 2 through Q-MOREAU, so Yuri's squad flags four and the eight's flags him with the Okafors; ANDERS is the closed example)
	var q15b := make_sim(1, 7); quiet(q15b); q15_win.call(q15b)
	var q15_open: Array = q15b.recruits_open()
	var q15_pre: Dictionary = q15b.recruit_view("ada_okafor")
	var q15l := make_sim(1, 7); quiet(q15l); q15_lose.call(q15l)
	var q15s8 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); quiet(q15s8); q15_win.call(q15s8)
	var q15m := make_sim(18, 7); quiet(q15m); q15_win.call(q15m)
	_sr("a dual won flags the squad's recruitables: vs %s %s -> %s; a dual lost %s; the sanctioned eight vs the same squad (SAM and YURI already in the stable: %s / %s) -> %s; vs %s -> %s (DEX surfacing with MOIRA, the cap of 4); before the approach Ada shows %s and no condition" % [JSON.stringify(q15b.bdressed), q15b.feed.left(40), JSON.stringify(q15_open), JSON.stringify(q15l.recruits_open()), q15s8.recruit_state("sam_tagaq"), q15s8.recruit_state("yuri_kowalchuk"), JSON.stringify(q15s8.recruits_open()), JSON.stringify(q15m.bdressed), JSON.stringify(q15m.recruits_open()), str(q15_pre.get("state", ""))],
		q15_open == ["yuri_kowalchuk", "jean_guy_moreau", "sam_tagaq", "ada_okafor"] and count_events(q15b.events, "recruit_approachable") == 1 and q15l.recruits_open().is_empty() \
		and q15s8.recruit_state("sam_tagaq") == "joined" and q15s8.recruit_state("yuri_kowalchuk") == "joined" and q15s8.recruits_open() == ["jean_guy_moreau", "ada_okafor", "carter_okafor"] and q15s8.recruit_state("anders_vey") == "never" \
		and q15m.recruits_open() == ["marta_okonkwo_tremblay", "moira_macisaac", "dex", "remy_moreau"] and str(q15_pre.get("state", "")) == "approachable" and q15_pre["clauses"].is_empty() and not q15_pre.has("condition"))
	# the approach: the condition surfaces whole, clause by clause with what you have (honest); refused for the unflagged, the closed, the approached; a met condition raises recruit_ready - and nobody joins on his own
	var q15_ay: Dictionary = q15b.approach("yuri_kowalchuk")
	var q15_aa: Dictionary = q15b.approach("ada_okafor")
	var q15_ref: Array = []
	for q15_nm in ["moira_macisaac", "anders_vey", "yuri_kowalchuk"]: q15_ref.append(str(q15b.approach(q15_nm)["why"]))
	var q15_ready: bool = count_events(q15b.events, "recruit_ready", {"name": "yuri_kowalchuk"}) == 1 and q15b.recruit_state("yuri_kowalchuk") == "approached" and q15b._stable_card("YURI").is_empty()
	var q15_adacl: Array = q15_aa["view"]["clauses"].map(func(c): return "%s %d/%d %s" % [str(c["text"]), int(c["have"]), int(c["need"]), str(c["owner"])])
	_sr("the approach: YURI's condition surfaces - %s; ADA's %s; refused: %s; YURI met raises recruit_ready and stays approached, not in the stable" % [JSON.stringify(q15_ay["view"]["clauses"].map(func(c): return "%s %d/%d %s" % [str(c["text"]), int(c["have"]), int(c["need"]), "met" if bool(c["met"]) else "unmet"])), JSON.stringify(q15_adacl), JSON.stringify(q15_ref)],
		bool(q15_ay["ok"]) and bool(q15_ay["view"]["met"]) and str(q15_ay["view"]["condition"]) == "BEAT_IN(dual[segment])" and q15_adacl == ["BOND(Carter, 4) 0/4 sim", "QUEST(okafor_table) 0/1 overworld"] and not bool(q15_aa["view"]["met"]) \
		and q15_ref == ["moira_macisaac is not approachable - beat his club in a dual first", "anders_vey: none - the anti-you until Arc 3 resolves him", "yuri_kowalchuk has been approached - his condition stands"] and q15_ready and count_events(q15b.events, "recruit_condition") == 2)
	# the recruit's answer: ADA refused naming what is unmet; YURI joins the stable - his Millbrook card, not dressed, a toast - and stays over new duals; dressed onto a board of the stable he fights R1; the board refuses a card not in the stable and a squad of the wrong size
	var q15_rada: Dictionary = q15b.recruit("ada_okafor")
	var q15_ry: Dictionary = q15b.recruit("yuri_kowalchuk")
	var q15_after: Array = q15_names.call(q15b.stable); var q15_dr: Array = q15_names.call(q15b.dressed)
	var q15_joined_ev: bool = count_events(q15b.events, "recruit_joined", {"card": "YURI"}) == 1 and count_events(q15b.events, "reward_toast", {"size": "recruit", "text": "YURI JOINS THE STABLE (5 cards)"}) == 1
	q15b.new_dual()
	var q15_sb: Dictionary = q15b.seal_board({"dress": ["RORY", "PRIYA", "MARCUS", "YURI"], "slots": ["YURI", "PRIYA", "RORY"]})
	var q15_bad1: Dictionary = q15b.seal_board({"dress": ["RORY", "PRIYA", "MARCUS", "BOB"], "slots": ["RORY", "PRIYA", "MARCUS"]})
	var q15_bad2: Dictionary = q15b.seal_board({"dress": ["RORY", "PRIYA", "YURI"], "slots": ["RORY", "PRIYA", "YURI"]})
	_sr("the recruit: ADA refused (%s); YURI joins (%s) - the stable %s, the dressed still %s, the toast YURI JOINS THE STABLE (5 cards); over a new dual the stable holds; a board dressing him from the stable seals (%s) and he fights R1 (%s, reserve %s); refused: %s / %s" % [str(q15_rada["why"]), str(q15_ry["ok"]), JSON.stringify(q15_after), JSON.stringify(q15_dr), str(q15_sb["ok"]), q15b.pname(), JSON.stringify(q15_names.call(q15b.reserves)), str(q15_bad1["why"]), str(q15_bad2["why"])],
		not bool(q15_rada["ok"]) and str(q15_rada["why"]) == "ada_okafor is not ready - BOND(Carter, 4) (0 of 4); QUEST(okafor_table) (0 of 1)" and bool(q15_ry["ok"]) and q15_after == ["RORY", "PRIYA", "MARCUS", "JUNE", "YURI"] and q15_dr == ["RORY", "PRIYA", "MARCUS", "JUNE"] \
		and q15_joined_ev and q15b.recruit_state("yuri_kowalchuk") == "joined" and bool(q15_sb["ok"]) and q15b.pname() == "YURI" and q15_names.call(q15b.reserves) == ["MARCUS"] and q15b.stable.size() == 5 \
		and str(q15_bad1["why"]) == "BOB is not in the stable" and str(q15_bad2["why"]) == "a squad of 3 for a dual that dresses 4" and float(q15b.P["stats"]["PWR"]) == 80.0)
	# the forms against their ledgers: BEAT_IN(spar) USING STYLE_PROOF(out-boxer) - a spar won by RORY does not count, by PRIYA it does - with QUEST and FEUD_RESOLVED from the story flags; BEAT_IN(scrap)x3 and REP(district, 3); PI_LEVEL; BOND through a recruited DEX; WITNESS; STAT_PROOF and STYLE_PROOF read off the stable and the wins; an unknown form never met
	var q15_mst := func(q15_lu: Array) -> TNBSim:
		var q15_s := make_sim(18, 7, q15_lu, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:tremblay_feud,feud_resolved:tremblay+coach_line,quest:building_five_dex,quest:macisaac_harbour")); quiet(q15_s); q15_win.call(q15_s)
		return q15_s
	var q15_pri: Array = [TNBSim.LINEUP_MILLBROOK[1].duplicate(true), TNBSim.LINEUP_MILLBROOK[0].duplicate(true), TNBSim.LINEUP_MILLBROOK[2].duplicate(true), TNBSim.LINEUP_MILLBROOK[3].duplicate(true)]
	var q15mr: TNBSim = q15_mst.call(TNBSim.LINEUP_MILLBROOK); q15_spar_win.call(q15mr, 18); q15mr.approach("marta_okonkwo_tremblay")
	var q15_mr_cl: Array = q15mr.recruit_view("marta_okonkwo_tremblay")["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	var q15mp: TNBSim = q15_mst.call(q15_pri); q15_spar_win.call(q15mp, 18); q15mp.approach("marta_okonkwo_tremblay")
	var q15_mp_ok: bool = bool(q15mp.recruit("marta_okonkwo_tremblay")["ok"])
	q15_scrap_win.call(q15mp, 19); q15mp.approach("dex"); var q15_dex: bool = bool(q15mp.recruit("dex")["ok"])   # his BEAT_IN(scrap) is against the Netmen (beat_as Moira)
	q15mp.approach("moira_macisaac"); var q15_mo0: Array = q15mp.recruit_view("moira_macisaac")["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	q15mp.rewards["kizuna"][TNBSim.pair_key("DEX", "RORY")] = 50
	var q15_mo_ok: bool = bool(q15mp.recruit("moira_macisaac")["ok"])
	var q15c := make_sim(7, 7); quiet(q15c); q15_win.call(q15c); q15c.approach("carter_okafor")
	q15_scrap_win.call(q15c, 7); q15_scrap_win.call(q15c, 7); q15c.rewards["story"]["rep:rink_district"] = 2
	var q15_c2: Array = q15c.recruit_view("carter_okafor")["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	q15_scrap_win.call(q15c, 7); q15c.rewards["story"]["rep:rink_district"] = 3
	var q15_c3: bool = bool(q15c.recruit("carter_okafor")["ok"])
	var q15t := make_sim(22, 7, TNBSim.LINEUP_MILLBROOK, "", TNBSim.parse_pi_arg("nguyen-roy:1", content.get("pattern_intel", {})), TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:vane_cut")); quiet(q15t); q15_win.call(q15t)
	q15t.approach("tam_nguyen_roy"); q15t.approach("cassidy_vane"); q15_spar_win.call(q15t, 22)
	var q15_t1: Array = q15t.recruit_view("tam_nguyen_roy")["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	var q15_v0: Array = q15t.recruit_view("cassidy_vane")["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	q15t.pi["dialects"]["nguyen-roy"]["scraps"] = 6
	q15t.new_dual(); quiet(q15t); q15_win.call(q15t)
	var q15_tv: bool = bool(q15t.recruit("tam_nguyen_roy")["ok"]) and bool(q15t.recruit("cassidy_vane")["ok"])
	var q15_sp: Array = [q15mp.condition_state("STAT_PROOF(PWR>=60)", "x")[0], q15mp.condition_state("STAT_PROOF(PWR>=90)", "x")[0], q15mp.condition_state("STYLE_PROOF(out-boxer)", "marta_okonkwo_tremblay")[0], q15mp.condition_state("TELEPATHY(anyone)", "x")[0], q15t.condition_state("PI_LEVEL(whitecloud, 2)", "x")[0]]
	_sr("the forms: MARTA's spar won by RORY %s, by PRIYA joins (%s); DEX (a scrap vs the Netmen + his quest) joins (%s) and MOIRA's BOND(Dex, 3) goes %s -> joins at Adjacent Trust (%s); CARTER's scrap x3 / REP 3 at two scraps and REP 2 %s, at three and 3 joins (%s); TAM's PI (the dual's segment against him took Nguyen-Roy to 2) and his spar %s, VANE's WITNESS %s -> a second dual won: both join (%s); PI_LEVEL(whitecloud, 2) %d/%d; STAT_PROOF PWR>=60 %d/%d, >=90 %d/%d, STYLE_PROOF(out-boxer) %d/%d, an unknown form %s" % [JSON.stringify(q15_mr_cl), str(q15_mp_ok), str(q15_dex), JSON.stringify(q15_mo0), str(q15_mo_ok), JSON.stringify(q15_c2), str(q15_c3), JSON.stringify(q15_t1), JSON.stringify(q15_v0), str(q15_tv), int(q15_sp[4]["have"]), int(q15_sp[4]["need"]), int(q15_sp[0]["have"]), int(q15_sp[0]["need"]), int(q15_sp[1]["have"]), int(q15_sp[1]["need"]), int(q15_sp[2]["have"]), int(q15_sp[2]["need"]), str(q15_sp[3]["met"])],
		q15_mr_cl == ["1/1", "1/1", "0/1"] and q15_mp_ok and q15_dex and q15_mo0 == ["0/3", "1/1"] and q15_mo_ok and q15_c2 == ["2/3", "2/3"] and q15_c3 and q15_t1 == ["2/2", "1/1"] and q15_v0 == ["1/1", "0/1"] and q15_tv and not bool(q15_sp[4]["met"]) and int(q15_sp[4]["need"]) == 2 \
		and bool(q15_sp[0]["met"]) and not bool(q15_sp[1]["met"]) and bool(q15_sp[2]["met"]) and not bool(q15_sp[3]["met"]) and str(q15_sp[3]["owner"]) == "?" and q15_names.call(q15mp.stable).has("MOIRA") and q15_names.call(q15c.stable).has("CARTER"))
	# the save: the stable beyond the dressed (YURI on the bench) as Fighter records flagged undressed, the recruit ledger and the story flags; a load dresses the four and keeps YURI in the stable, joined
	var q15v := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:okafor_table,rep:rink_district:2")); quiet(q15v); q15_win.call(q15v); q15v.approach("*"); q15v.recruit("*")
	var q15_rec: Dictionary = TNBSave.to_save(q15v)
	var q15_undr: Array = []
	for q15_f in q15_rec["stable"]:
		if not bool(q15_f.get("dressed", true)): q15_undr.append(str(q15_f["name"]))
	var q15ld = TNBSave.build(content, TNBSave.read_text(TNBSave.write_text(q15v, false)), 5)["sim"]
	_sr("the save: %d Fighter records, undressed %s, the recruit ledger %s, the story flags %s; a load dresses %s, the stable %s, YURI %s" % [q15_rec["stable"].size(), JSON.stringify(q15_undr), JSON.stringify(q15v.rewards["recruit"].keys()), JSON.stringify(q15_rec["story_flags"]), JSON.stringify(q15_names.call(q15ld.dressed)), JSON.stringify(q15_names.call(q15ld.stable)), q15ld.recruit_state("yuri_kowalchuk")],
		q15_rec["stable"].size() == 6 and q15_undr == ["YURI", "SAM"] and q15_rec["story_flags"] == {"quest:okafor_table": true, "rep:rink_district": 2} and q15_names.call(q15ld.dressed) == ["RORY", "PRIYA", "MARCUS", "JUNE"] \
		and q15_names.call(q15ld.stable) == ["RORY", "PRIYA", "MARCUS", "JUNE", "YURI", "SAM"] and q15ld.recruit_state("yuri_kowalchuk") == "joined" and q15ld.recruit_state("ada_okafor") == "approached")
	# every content table rides outside the snapshot and inside the content stamp (PAC-074's STAFF had ridden in the snapshot and out of the stamp; the table fixed here)
	var q15_tabs := ["T", "patterns", "library", "TAC", "AFF", "FEUDS", "COACHES", "FMT", "BOUTS", "SCRAPS", "PI", "REMIX", "ECO", "PIECES", "NEUTRAL", "TALK", "FORMATION", "STAFF", "RECRUITS", "STRINGS", "HOUSES", "GYMWALL", "TRANS", "HYB", "FAC", "GROW", "TECH", "ACAD", "GEAR"]   # PAC-090: 26 with the growth table; PAC-091: 27 with the techniques table; PAC-092: 28 with the academy; PAC-094: 29 with the gear
	var q15_in_snap: Array = []
	var q15_sv: Array = q15a.state_vars()
	for q15_tn in q15_tabs:
		if q15_tn in q15_sv: q15_in_snap.append(q15_tn)
	var q15_stamp0: int = q15a.content_stamp()
	var q15_keep_st: Dictionary = q15a.STAFF; q15a.STAFF = q15_keep_st.duplicate(true); q15a.STAFF["levels"]["3"] = 9
	var q15_stamp_st: int = q15a.content_stamp(); q15a.STAFF = q15_keep_st
	var q15_keep_rc: Dictionary = q15a.RECRUITS; q15a.RECRUITS = q15_keep_rc.duplicate(true); q15a.RECRUITS["card_tier"] = 2
	var q15_stamp_rc: int = q15a.content_stamp(); q15a.RECRUITS = q15_keep_rc
	_sr("every content table (%d) rides outside the snapshot (%s inside) and inside the stamp: a changed staff table or recruit table changes it (%s / %s), restored it is the same (%s)" % [q15_tabs.size(), JSON.stringify(q15_in_snap), str(q15_stamp_st != q15_stamp0), str(q15_stamp_rc != q15_stamp0), str(q15a.content_stamp() == q15_stamp0)],
		q15_in_snap.is_empty() and q15_stamp_st != q15_stamp0 and q15_stamp_rc != q15_stamp0 and q15a.content_stamp() == q15_stamp0)

	# ---- PAC-076: THE STRING WALL (NP_08 s2.3) ----
	# the data: six maps of the questlines' own people - fighters (recruit records), leads (named by the docs, no card), houses (the crest and
	# NP_07A's blessing line, every one on the feud graph); every string's ends on the wall and its kind known; a fighter's house string runs to
	# his own house; the BOND conditions the roster docs authored are strung (the first edges); a fresh club's wall is face down
	var q16_w: Dictionary = content["string_wall"]
	var q16_ids: Array = []; var q16_kinds := {"fighter": 0, "lead": 0, "house": 0}; var q16_bad: Array = []; var q16_links := 0
	var q16a := make_sim(0, 7)
	for q16_m in q16_w["maps"]:
		for q16_n in q16_m["nodes"]:
			q16_ids.append(str(q16_n["id"])); q16_kinds[str(q16_n["kind"])] = int(q16_kinds.get(str(q16_n["kind"]), 0)) + 1
			if str(q16_n["kind"]) == "fighter" and not q15_rc["recruits"].has(str(q16_n["id"])): q16_bad.append(str(q16_n["id"]) + ": no recruit record")
			if str(q16_n["kind"]) == "lead" and (str(q16_n.get("source", "")) == "" or str(q16_n.get("note", "")) == ""): q16_bad.append(str(q16_n["id"]) + ": no source")
			if str(q16_n["kind"]) == "house":
				var q16_on_graph := false
				for q16_e in content["feuds"]:
					if str(q16_e["a"]) == str(q16_n["house"]) or str(q16_e["b"]) == str(q16_n["house"]): q16_on_graph = true
				if not q16_on_graph or str(q16_n.get("source", "")) == "": q16_bad.append(str(q16_n["id"]) + ": not on the feud graph / no source")
				if q16_n.get("blessing") != null:
					for q16_c in TNBSim.parse_condition(str(q16_n["blessing"])):
						if not q15_rc["grammar"].has(str(q16_c["form"])): q16_bad.append(str(q16_n["id"]) + ": " + str(q16_c["text"]))
	for q16_m in q16_w["maps"]:
		for q16_l in q16_m["links"]:
			q16_links += 1
			if not (str(q16_l["a"]) in q16_ids and str(q16_l["b"]) in q16_ids) or not q16_w["link_kinds"].has(str(q16_l["kind"])): q16_bad.append(JSON.stringify(q16_l))
			elif str(q16_l["kind"]) == "house" and str(q16a.sw_node(str(q16_l["a"]))["kind"]) == "fighter":
				var q16_own := TNBSim.house_key(str(q16a.recruit_card(str(q16_l["a"]))["house"]))
				if q16_own != str(q16a.sw_node(str(q16_l["b"]))["house"]): q16_bad.append("%s's house is %s" % [str(q16_l["a"]), q16_own])
	var q16_bonds: Array = []; var q16_bond_ok := true
	for q16_rn in q15_rc["recruits"]:
		for q16_c in TNBSim.parse_condition(str(q15_rc["recruits"][q16_rn].get("condition", ""))):
			if str(q16_c["form"]) != "BOND": continue
			var q16_x := str(q16_c["args"][0]).to_upper(); var q16_xn := ""
			for q16_rn2 in q15_rc["recruits"]:
				if str(q15_rc["recruits"][q16_rn2].get("card", "")) == q16_x: q16_xn = str(q16_rn2)
			var q16_found := false
			for q16_m in q16_w["maps"]:
				for q16_l in q16_m["links"]:
					if str(q16_l.get("bond", "")) == str(q16_c["text"]) and ((str(q16_l["a"]) == q16_xn and str(q16_l["b"]) == str(q16_rn)) or (str(q16_l["b"]) == q16_xn and str(q16_l["a"]) == str(q16_rn))): q16_found = true
			q16_bonds.append("%s -> %s %s" % [q16_x, str(q15_rc["recruits"][q16_rn]["card"]), "strung" if q16_found else "NOT STRUNG"])
			if not q16_found: q16_bond_ok = false
	var q16_stamp0: int = q16a.content_stamp()
	var q16_keep: Dictionary = q16a.STRINGS; q16a.STRINGS = q16_keep.duplicate(true); q16a.STRINGS["chain_relations"] = ["ALLIED"]
	var q16_stamp1: int = q16a.content_stamp(); q16a.STRINGS = q16_keep
	_sr("the String Wall as data (NP_08 s2.3): %d maps, %d nodes (%s), %d strings; problems %s; the authored BOND conditions strung: %s; a changed wall table changes the content stamp (%s); a fresh club's wall %d of %d up, no lines" % [q16_w["maps"].size(), q16_ids.size(), JSON.stringify(q16_kinds), q16_links, JSON.stringify(q16_bad), JSON.stringify(q16_bonds), str(q16_stamp1 != q16_stamp0), int(q16a.string_wall()["known"]), int(q16a.string_wall()["total"])],
		q16_w["maps"].size() == 6 and q16_ids.size() >= 40 and q16_ids.size() == 43 and q16_kinds == {"fighter": 16, "lead": 14, "house": 13} and q16_links == 42 and q16_bad.is_empty() \
		and q16_bond_ok and q16_bonds.size() == 3 and q16_stamp1 != q16_stamp0 and int(q16a.string_wall()["known"]) == 0 and int(q16a.string_wall()["total"]) == 43 and q16a.string_wall_lines().is_empty())
	# family (either way): CARTER recruited turns up his sisters, his cousin and his house - ADA approached through the string (whom no squad
	# beaten fielded), her condition surfacing; NNEKA a lead (refused an approach: no card in the sim), CHIAMAKA closed; ADA signed through it adds
	# no string. The other way round: REMY recruited surfaces JEAN-GUY, E05 closes, he is READY and signs
	var q16c := make_sim(7, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "rep:rink_district:3,quest:okafor_table")); quiet(q16c); q15_win.call(q16c)
	q16c.approach("carter_okafor"); q15_scrap_win.call(q16c, 7); q15_scrap_win.call(q16c, 7); q15_scrap_win.call(q16c, 7)
	var q16_ada0 := q16c.recruit_state("ada_okafor")
	q16c.events.clear()
	var q16_cj: bool = bool(q16c.recruit("carter_okafor")["ok"])
	var q16_c_ev: Array = []
	for q16_e in q16c.events:
		if str(q16_e["kind"]) == "wall_revealed": q16_c_ev.append("%s -> %s" % [str(q16_e["from"]), ", ".join(PackedStringArray(q16_e["labels"]))])
	var q16_ada: Dictionary = q16c.recruit_view("ada_okafor")
	var q16_adacl: Array = q16_ada["clauses"].map(func(c): return "%s %d/%d" % [str(c["text"]), int(c["have"]), int(c["need"])])
	var q16_cond_ev: int = count_events(q16c.events, "recruit_condition", {"name": "ada_okafor", "via": "carter_okafor"})
	var q16_cst := {}
	for q16_id in ["ada_okafor", "nneka_okafor", "chiamaka_okafor", "house_okafor", "house_petrov"]: q16_cst[q16_id] = q16c.sw_state(q16_id)
	var q16_lines_ada: bool = false
	for q16_ln in q16c.recruit_lines():
		if str(q16_ln).begins_with("ADA (ada_okafor, via CARTER): BOND(Carter, 4) 0/4 AND QUEST(okafor_table) 1/1 ok"): q16_lines_ada = true
	var q16_nn: String = str(q16c.approach("nneka_okafor")["why"])
	q16c.rewards["kizuna"][TNBSim.pair_key("CARTER", "RORY")] = 90
	q16c.events.clear()
	var q16_aj: bool = bool(q16c.recruit("ada_okafor")["ok"])
	var q16_after_ada: int = count_events(q16c.events, "wall_revealed")
	var q16_ada_bless: Array = []                                                                        # PAC-077: her line is House Okafor's - the blessing lands with her, and its one new string runs to House Petrov (E04)
	for q16_e in q16c.events:
		if str(q16_e["kind"]) == "wall_revealed": q16_ada_bless.append("%s -> %s" % [str(q16_e["from"]), ", ".join(PackedStringArray(q16_e["labels"]))])
	var q16r := make_sim(19, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:cold_storage")); quiet(q16r); q15_win.call(q16r)
	var q16_jg0 := q16r.recruit_state("jean_guy_moreau")
	q16r.approach("remy_moreau"); var q16_rj: bool = bool(q16r.recruit("remy_moreau")["ok"])
	var q16_jg: Dictionary = q16r.recruit_view("jean_guy_moreau")
	var q16_jgcl: Array = q16_jg["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	var q16_jg_early: String = str(q16r.recruit("jean_guy_moreau")["why"])
	q16r.rewards["story"]["feud_resolved:moreau+tremblay"] = true; q16r._recruit_check()
	var q16_jg_ready: bool = count_events(q16r.events, "recruit_ready", {"name": "jean_guy_moreau"}) == 1
	var q16_jj: bool = bool(q16r.recruit("jean_guy_moreau")["ok"])
	_sr("family: ADA before %s; CARTER joins (%s) -> %s; ADA %s via %s, her condition %s (one recruit_condition by the string: %d), NNEKA %s, CHIAMAKA %s, House Okafor %s, House Petrov face down (%s); NNEKA's approach: %s; ADA signed through the string (%s) adds %d string (since C31 her line blesses House Okafor: %s). The other way: JEAN-GUY %s before, REMY joins (%s) -> JEAN-GUY %s via %s %s, refused while E05 is open (%s); E05 closed -> READY (%s), signs (%s), the stable %s" % [q16_ada0 if q16_ada0 != "" else "face down", str(q16_cj), JSON.stringify(q16_c_ev), str(q16_cst["ada_okafor"]), str(q16_ada.get("via", "")), JSON.stringify(q16_adacl), q16_cond_ev, str(q16_cst["nneka_okafor"]), str(q16_cst["chiamaka_okafor"]), str(q16_cst["house_okafor"]), str(q16_cst["house_petrov"] == ""), q16_nn, str(q16_aj), q16_after_ada, JSON.stringify(q16_ada_bless), q16_jg0 if q16_jg0 != "" else "face down", str(q16_rj), str(q16_jg["state"]), str(q16_jg.get("via", "")), JSON.stringify(q16_jgcl), q16_jg_early, str(q16_jg_ready), str(q16_jj), JSON.stringify(q15_names.call(q16r.stable))],
		q16_ada0 == "" and q16_cj and q16_c_ev == ["CARTER -> ADA, NNEKA OKAFOR, CHIAMAKA, HOUSE OKAFOR"] and q16_cst == {"ada_okafor": "approached", "nneka_okafor": "lead", "chiamaka_okafor": "never", "house_okafor": "unblessed", "house_petrov": ""} \
		and str(q16_ada.get("via", "")) == "carter_okafor" and q16_adacl == ["BOND(Carter, 4) 0/4", "QUEST(okafor_table) 1/1"] and q16_cond_ev == 1 and q16_lines_ada \
		and q16_nn == "NNEKA OKAFOR is a lead on the String Wall (staff: Hype) - no card in the sim; the overworld signs a lead" and q16_aj and q16_after_ada == 1 and q16_ada_bless == ["the Okafor blessing -> HOUSE PETROV"] and q15_names.call(q16c.stable).has("ADA") \
		and q16_jg0 == "" and q16_rj and str(q16_jg["state"]) == "approached" and str(q16_jg.get("via", "")) == "remy_moreau" and q16_jgcl == ["1/1", "0/1"] and q16_jg_early == "jean_guy_moreau is not ready - FEUD_RESOLVED(moreau, tremblay) (0 of 1)" \
		and q16_jg_ready and q16_jj and q15_names.call(q16r.stable).has("JEAN-GUY") and q16r.sw_state("house_moreau") == "blessed")   # C31: E05 closed and cold_storage are Moreau's line
	# master (one way): SAM recruited surfaces his students - THE JUNIOR (a lead: scout) and CHOIR (approached through the string, her
	# BOND(Sam, 4) and her quest surfacing) - and his house; a ledger with CHOIR signed and SAM not surfaces nobody from her string
	var q16s := make_sim(1, 7); quiet(q16s); q15_win.call(q16s); q16s.approach("sam_tagaq"); q16s.events.clear()
	var q16_sj: bool = bool(q16s.recruit("sam_tagaq")["ok"])
	var q16_s_ev: Array = []
	for q16_e in q16s.events:
		if str(q16_e["kind"]) == "wall_revealed": q16_s_ev.append("%s -> %s" % [str(q16_e["from"]), ", ".join(PackedStringArray(q16_e["labels"]))])
	var q16_ch: Dictionary = q16s.recruit_view("hc9_choir")
	var q16_chcl: Array = q16_ch["clauses"].map(func(c): return "%s %d/%d" % [str(c["text"]), int(c["have"]), int(c["need"])])
	var q16_led1 := TNBSim.parse_kizuna_arg(""); q16_led1["recruit"] = {"hc9_choir": {"state": "joined", "witnessed": 0, "day": 1}}
	var q16o := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q16_led1)
	_sr("master: SAM joins (%s) -> %s; CHOIR %s via %s, her condition %s; THE JUNIOR %s, House Tagaq %s, House Whitecloud face down (%s); one way - CHOIR signed, SAM not: the wall %d up (%s), the junior %s, SAM %s, no string (%d)" % [str(q16_sj), JSON.stringify(q16_s_ev), str(q16_ch["state"]), str(q16_ch.get("via", "")), JSON.stringify(q16_chcl), q16s.sw_state("tagaq_junior"), q16s.sw_state("house_tagaq"), str(q16s.sw_state("house_whitecloud") == ""), int(q16o.string_wall()["known"]), q16o.sw_state("hc9_choir"), q16o.sw_state("tagaq_junior") if q16o.sw_state("tagaq_junior") != "" else "face down", q16o.sw_state("sam_tagaq") if q16o.sw_state("sam_tagaq") != "" else "face down", q16o.rewards["string_wall"].size()],
		q16_sj and q16_s_ev == ["SAM -> THE JUNIOR, CHOIR, HOUSE TAGAQ"] and str(q16_ch["state"]) == "approached" and str(q16_ch.get("via", "")) == "sam_tagaq" and q16_chcl == ["BOND(Sam, 4) 0/4", "QUEST(choir_name) 0/1"] \
		and q16s.sw_state("tagaq_junior") == "lead" and q16s.sw_state("house_tagaq") == "unblessed" and q16s.sw_state("house_whitecloud") == "" \
		and int(q16o.string_wall()["known"]) == 1 and q16o.sw_state("hc9_choir") == "joined" and q16o.sw_state("tagaq_junior") == "" and q16o.sw_state("sam_tagaq") == "" and q16o.rewards["string_wall"].is_empty())
	# house: YURI recruited turns up his house, not the cousins (they come with the blessing); the Kowalchuk blessing turns up the house, YURI
	# (approached through it), the cousins and House Whitecloud (E03 ALLIED) - not its elder, and never House Reyes across E11's FEUD; the Moreau
	# blessing turns up both Moreaus and House Iron (E08 DEBT), whose crest - nobody left to bless - brings VERA IRON with her condition; not
	# House Tremblay across E05
	var q16y := make_sim(1, 7); quiet(q16y); q15_win.call(q16y); q16y.approach("yuri_kowalchuk"); q16y.recruit("yuri_kowalchuk")
	var q16k := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "blessing:kowalchuk"))
	var q16_k_ev: Array = []
	for q16_e in q16k.events:
		if str(q16_e["kind"]) == "wall_revealed": q16_k_ev.append("%s -> %s" % [str(q16_e["from"]), ", ".join(PackedStringArray(q16_e["labels"]))])
	var q16mo := make_sim(2, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "blessing:moreau"))
	var q16_m_ev: Array = []
	for q16_e in q16mo.events:
		if str(q16_e["kind"]) == "wall_revealed": q16_m_ev.append("%s -> %s" % [str(q16_e["from"]), ", ".join(PackedStringArray(q16_e["labels"]))])
	var q16_vera: Dictionary = {}
	for q16_nv in q16mo.string_wall()["maps"][4]["nodes"]:
		if str(q16_nv["id"]) == "vera_iron": q16_vera = q16_nv
	var q16_mlines: Array = q16mo.string_wall_lines()
	_sr("house: YURI joins -> House Kowalchuk %s, the cousins face down (%s); blessing:kowalchuk -> %s (YURI %s via %s, House Whitecloud %s, its elder face down %s, House Reyes face down %s); blessing:moreau -> %s (JEAN-GUY %s, REMY %s, VERA %s %s, House Tremblay face down %s); the lines %s" % [q16y.sw_state("house_kowalchuk"), str(q16y.sw_state("kowalchuk_cousins") == ""), JSON.stringify(q16_k_ev), q16k.recruit_state("yuri_kowalchuk"), str(q16k.rewards["recruit"].get("yuri_kowalchuk", {}).get("via", "")), q16k.sw_state("house_whitecloud"), str(q16k.sw_state("whitecloud_elder") == ""), str(q16k.sw_state("house_reyes") == ""), JSON.stringify(q16_m_ev), q16mo.recruit_state("jean_guy_moreau"), q16mo.recruit_state("remy_moreau"), str(q16_vera.get("state", "")), JSON.stringify(q16_vera.get("clauses", [])), str(q16mo.sw_state("house_tremblay") == ""), JSON.stringify(q16_mlines)],
		q16y.sw_state("house_kowalchuk") == "unblessed" and q16y.sw_state("kowalchuk_cousins") == "" \
		and q16_k_ev == ["the Kowalchuk blessing -> HOUSE KOWALCHUK, YURI, THE KOWALCHUK COUSINS, HOUSE WHITECLOUD"] and q16k.sw_state("house_kowalchuk") == "blessed" and q16k.recruit_state("yuri_kowalchuk") == "approached" \
		and str(q16k.rewards["recruit"]["yuri_kowalchuk"].get("via", "")) == "blessing:kowalchuk" and q16k.sw_state("kowalchuk_cousins") == "lead" and q16k.sw_state("house_whitecloud") == "unblessed" and q16k.sw_state("whitecloud_elder") == "" and q16k.sw_state("house_reyes") == "" \
		and q16_m_ev == ["the Moreau blessing -> HOUSE MOREAU, JEAN-GUY, REMY, HOUSE IRON", "HOUSE IRON -> VERA IRON"] and q16mo.recruit_state("jean_guy_moreau") == "approached" and q16mo.recruit_state("remy_moreau") == "approached" \
		and str(q16_vera.get("state", "")) == "lead" and q16_vera.get("clauses", []) == ["ITEM(iron_gym_stencil_bag) 0/1", "QUEST(estate_sale) 0/1"] and q16mo.sw_state("house_iron") == "no blessing" and q16mo.sw_state("house_tremblay") == "" \
		and q16_mlines.size() == 2 and str(q16_mlines[1]) == "HOUSES: HOUSE IRON = HOUSE MOREAU (DEBT)")
	# the wall is the recruit ledger's view and the save writes it (NP_11 s9 SaveGame.string_wall): the Carter chain's three chairs 5 of 5 with
	# their 9 strings (the BOND one named) and 5 leads (4 until C31: the Okafor blessing ADA brings adds House Petrov); the Moreau blessing's wall
	# written, read back by a load that turns no card, written again equal
	var q16_cw: Dictionary = q16c.string_wall()
	var q16_tc: Dictionary = q16_cw["maps"][0]
	var q16_bondstr: Array = q16_tc["strings"].filter(func(x): return x.has("bond")).map(func(x): return str(x["bond"]))
	var q16_sv: Dictionary = TNBSave.to_save(q16mo)
	var q16_txt: String = TNBSave.write_text(q16mo, false)
	var q16ml = TNBSave.build(content, TNBSave.read_text(q16_txt), 5)["sim"]
	var q16_ml_ev: int = count_events(q16ml.events, "wall_revealed")
	_sr("the ledger's view and the save: the three chairs %d/%d, %d strings, BOND strings %s, the leads %s, the line %s; the Moreau blessing's save - %d maps, %d cards up, %d leads; a load turns %d cards, its wall %s and the save text written again %s" % [int(q16_tc["known"]), int(q16_tc["total"]), q16_tc["strings"].size(), JSON.stringify(q16_bondstr), JSON.stringify(q16_cw["leads"].map(func(x): return "%s<-%s" % [str(x["id"]), str(x["via"])])), str(q16c.string_wall_lines()[0]), q16_sv["string_wall"]["maps"].size(), int(q16_sv["string_wall"]["known"]), q16_sv["string_wall"]["leads"].size(), q16_ml_ev, "equal" if JSON.stringify(q16ml.string_wall()) == JSON.stringify(q16mo.string_wall()) else "DIFFERENT", "byte-equal" if TNBSave.write_text(q16ml, false) == q16_txt else "DIFFERENT"],
		int(q16_tc["known"]) == 5 and int(q16_tc["total"]) == 5 and q16_tc["strings"].size() == 9 and q16_bondstr == ["BOND(Carter, 4)"] and q16_cw["leads"].size() == 5 \
		and str(q16c.string_wall_lines()[0]) == "THREE CHAIRS AT THE TABLE 5/5: CARTER [in the stable], ADA [in the stable <- CARTER], NNEKA OKAFOR [lead <- CARTER], CHIAMAKA [closed <- CARTER], HOUSE OKAFOR [blessed <- CARTER]" \
		and q16_sv["string_wall"] == q16mo.string_wall() and q16_sv["string_wall"]["maps"].size() == 6 and int(q16_sv["string_wall"]["known"]) == 5 and q16_sv["string_wall"]["leads"].size() == 5 \
		and q16_ml_ev == 0 and JSON.stringify(q16ml.string_wall()) == JSON.stringify(q16mo.string_wall()) and TNBSave.write_text(q16ml, false) == q16_txt)

	# ---- PAC-077: BLESSINGS AND THE LIVE GRAPH (NP_08 s3, NP_07 s5-6, NP_07A s1-2) ----
	var q17_ev := func(q17_s: TNBSim, q17_kind: String) -> Array:
		var q17_o: Array = []
		for q17_e in q17_s.events:
			if str(q17_e["kind"]) != q17_kind: continue
			match q17_kind:
				"wall_revealed": q17_o.append("%s -> %s" % [str(q17_e["from"]), ", ".join(PackedStringArray(q17_e["labels"]))])
				"blessing_granted": q17_o.append("%s %s %s" % [str(q17_e["house"]), str(q17_e["how"]), JSON.stringify(q17_e["sanctioned"])])
				"graph_mutated": q17_o.append("%s %s->%s" % [str(q17_e["edge"]), str(q17_e["from"]), str(q17_e["to"])])
				"graph_refused": q17_o.append("%s refused" % str(q17_e["edge"]))
				_: q17_o.append(JSON.stringify(q17_e))
		return q17_o
	var q17_cl := func(q17_s: TNBSim, q17_h: String) -> Array: return q17_s.house_clauses(q17_h).map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])
	# the data: fourteen houses, twelve blessing lines (Iron has none, the sealed house blesses itself), each the String Wall's own line and in the
	# grammar; natives read off the library (the SECRET excepted); the feud graph's twelve edges each with its flip or its hold, the refused
	# E11, the provisional E13; a fresh club's graph as authored and no house blessed; a changed house table changes the stamp
	var q17_hd: Dictionary = content["houses"]
	var q17_bad: Array = []; var q17_lines := 0; var q17_nat := {}
	var q17a := make_sim(0, 7)
	for q17_h in q17_hd["houses"]:
		var q17_r: Dictionary = q17_hd["houses"][q17_h]
		q17_nat[q17_h] = q17a.house_natives(str(q17_h)).size()
		if q17_r.get("blessing") == null: continue
		q17_lines += 1
		var q17_wn := q17a.sw_house_node(str(q17_h))
		if q17_wn == "" or str(q17a.sw_node(q17_wn).get("blessing", "")) != str(q17_r["blessing"]): q17_bad.append(str(q17_h) + ": not the wall's line")
		for q17_c in TNBSim.parse_condition(str(q17_r["blessing"])):
			if not q15_rc["grammar"].has(str(q17_c["form"])): q17_bad.append(str(q17_h) + ": " + str(q17_c["text"]))
	var q17_flip := {"on": 0, "held": 0, "refused": 0}
	for q17_e in content["feuds"]:
		var q17_f: Dictionary = q17_e.get("flip", {})
		if q17_f.has("held"): q17_flip["held"] += 1
		elif q17_f.has("refused"): q17_flip["refused"] += 1
		elif q17_f.get("on", []).size() > 0: q17_flip["on"] += 1
		else: q17_bad.append(str(q17_e["id"]) + ": no flip")
	var q17_st0: int = q17a.content_stamp()
	var q17_keep: Dictionary = q17a.HOUSES; q17a.HOUSES = q17_keep.duplicate(true); q17a.HOUSES["houses"]["iron"]["trait"] = "?"
	var q17_st1: int = q17a.content_stamp(); q17a.HOUSES = q17_keep
	_sr("houses as data (NP_07 s2, NP_07A): %d houses, %d blessing lines (Iron none, the sealed house its own), every line the String Wall's and in the grammar (%s); natives off the library %s; the feud graph's flips %s, provisional %s; a fresh club: %d edges mutated, %d houses blessed; a changed house table changes the stamp (%s)" % [q17_hd["houses"].size(), q17_lines, JSON.stringify(q17_bad), JSON.stringify(q17_nat), JSON.stringify(q17_flip), JSON.stringify(q17_hd.get("provisional_edges", []).map(func(x): return str(x["id"]))), q17a.rewards["graph"].size(), q17a.rewards["houses"].size(), str(q17_st1 != q17_st0)],
		q17_hd["houses"].size() == 14 and q17_lines == 12 and q17_bad.is_empty() and int(q17_nat["kowalchuk"]) == 2 and int(q17_nat["osei"]) == 2 and int(q17_nat["iron"]) == 0 and q17_flip == {"on": 6, "held": 5, "refused": 1} \
		and q17_hd.get("provisional_edges", []).size() == 1 and q17a.rewards["graph"].is_empty() and q17a.rewards["houses"].is_empty() and q17_st1 != q17_st0 and q17a.live_edges().size() == 12)
	# the patriarch attends (Kowalchuk): a dual won against Yuri's squad meets BEAT_IN(dual[segment]) against the house; YURI recruited arrives
	# UNSANCTIONED (natives locked) and his house's crest goes up; the next dual won is the home dual he watches - the line is met, the house
	# blesses the club, YURI is sanctioned with Grain Elevator and Full Load unlocked, and the blessing turns up the cousins and House Whitecloud
	var q17k := make_sim(1, 7); quiet(q17k); q15_win.call(q17k)
	var q17_k0: Array = q17_cl.call(q17k, "kowalchuk")
	q17k.approach("yuri_kowalchuk"); q17k.events.clear(); q17k.recruit("yuri_kowalchuk")
	var q17_kj: Array = q17k.events.filter(func(e): return str(e["kind"]) == "recruit_joined")
	var q17_ku := [q17k.house_status("YURI"), q17k.natives_unlocked("YURI").size(), q17k.house_state("kowalchuk"), q17k.sw_state("house_kowalchuk")]
	q17k.new_dual(); quiet(q17k); q17k.events.clear(); q15_win.call(q17k)
	var q17_kb: Array = q17_ev.call(q17k, "blessing_granted"); var q17_kw: Array = q17_ev.call(q17k, "wall_revealed")
	var q17_ks: int = count_events(q17k.events, "sanctioned", {"card": "YURI"})
	var q17_klines: Array = q17k.house_lines()
	var q17_kwall: Array = []                                                                            # the line on the String Wall's house card, clause by clause
	for q17_nv in q17k.string_wall()["maps"][3]["nodes"]:
		if str(q17_nv["id"]) == "house_kowalchuk": q17_kwall = q17_nv.get("blessing_clauses", [])
	_sr("the patriarch attends: after the first dual Kowalchuk's line %s; YURI joins %s, natives %d, the house %s, its crest %s; the next dual won -> %s (sanctioned %d), YURI %s with %s; the blessing turns up %s; House Tagaq (SAM only flagged) witnessed %d; the lines %s; the wall's crest card %s" % [JSON.stringify(q17_k0), str(q17_ku[0]), int(q17_ku[1]), str(q17_ku[2]), str(q17_ku[3]), JSON.stringify(q17_kb), q17_ks, q17k.house_status("YURI"), JSON.stringify(q17k.natives_unlocked("YURI")), JSON.stringify(q17_kw), int(q17k.rewards["houses"].get("tagaq", {}).get("witnessed", 0)), JSON.stringify(q17_klines), JSON.stringify(q17_kwall)],
		q17_k0 == ["1/1", "0/1"] and q17_kj.size() == 1 and str(q17_kj[0]["house_status"]) == "UNSANCTIONED" and q17_ku == ["UNSANCTIONED", 0, "unblessed", "unblessed"] \
		and q17_kb == ["kowalchuk met [\"YURI\"]"] and q17_ks == 1 and q17k.house_status("YURI") == "NATIVE" and q17k.natives_unlocked("YURI") == ["Grain Elevator", "Full Load"] \
		and q17_kw == ["the Kowalchuk blessing -> THE KOWALCHUK COUSINS, HOUSE WHITECLOUD"] and int(q17k.rewards["houses"].get("tagaq", {}).get("witnessed", 0)) == 0 and q17_klines.has("KOWALCHUK [blessed]  | YURI NATIVE") \
		and q17_kwall == ["BEAT_IN(dual[segment]) 2/1 ok", "WITNESS(patriarch attends a home dual) 1/1 ok"])
	# the quiet corner watches (Tagaq): SAM recruited UNSANCTIONED and at Adjacent Trust; a dual won with crowd heat converted is not the one Tagaq
	# asked for - one won without it is, and the house blesses the club: SAM sanctioned, Sorry Eh and Still Water unlocked
	var q17t := make_sim(1, 7); quiet(q17t); q15_win.call(q17t); q17t.approach("sam_tagaq"); q17t.recruit("sam_tagaq")
	var q17_tj := q17t.house_status("SAM")
	q17t.rewards["kizuna"][TNBSim.pair_key("SAM", "RORY")] = 50
	var q17_t0: Array = q17_cl.call(q17t, "tagaq")
	q17t.new_dual(); quiet(q17t); q17t.crowd_spent_dual = 30.0; q15_win.call(q17t)
	var q17_t1: Array = q17_cl.call(q17t, "tagaq"); var q17_tst1 := q17t.house_state("tagaq")
	q17t.new_dual(); quiet(q17t); q15_win.call(q17t)
	_sr("the quiet corner: SAM joins %s, Tagaq's line %s; a dual won with 30 heat converted -> %s (%s); one won without -> %s, SAM %s with %s" % [q17_tj, JSON.stringify(q17_t0), JSON.stringify(q17_t1), q17_tst1, q17t.house_state("tagaq"), q17t.house_status("SAM"), JSON.stringify(q17t.natives_unlocked("SAM"))],
		q17_tj == "UNSANCTIONED" and q17_t0 == ["3/3", "0/1"] and q17_t1 == ["3/3", "0/1"] and q17_tst1 == "unblessed" and q17t.house_state("tagaq") == "blessed" and q17t.house_status("SAM") == "NATIVE" and q17t.natives_unlocked("SAM") == ["Sorry Eh", "Still Water"])
	# the open ledger (Petrov): with its quest set, STYLE_PROOF asks a win over an Ascendant fighter by Petrov moves alone - a spar over Yuri by
	# System Jab (not Ascendant), over Vane with no cast, over Vane by System Jab and Grain Elevator do not count; over Vane by System Jab does,
	# and the house blesses: its crest, the patriarch, his three students, Anders and Baro, House Okafor (E04) and House Osei (E09) turn up
	var q17p := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:open_ledger")); quiet(q17p)
	var q17_pspar := func(q17_bi: int, q17_moves: Array) -> Array:
		q17p.start_spar(q17_bi)
		for q17_mv in q17_moves: q17p._start_cast("P", q17p.library[str(q17_mv)]); q17p.cast = {}
		q17p.ep_p = 10; q17p._end_bout(); q17p.end_bout()
		return q17_cl.call(q17p, "petrov")
	var q17_p1: Array = q17_pspar.call(1, ["System Jab"]); var q17_p2: Array = q17_pspar.call(0, []); var q17_p3: Array = q17_pspar.call(0, ["System Jab", "Grain Elevator"])
	var q17_pst := q17p.house_state("petrov")
	q17p.events.clear()
	var q17_p4: Array = q17_pspar.call(0, ["System Jab"])
	_sr("the open ledger: E13 %s at the quest; Petrov's line after a spar over Yuri by System Jab %s, over Vane with no cast %s, by System Jab and Grain Elevator %s (%s); over Vane by System Jab alone %s -> %s; the blessing turns up %s" % [JSON.stringify(q17p.graph_view()["graph"].filter(func(x): return x.has("added")).map(func(x): return "%s %s-%s" % [str(x["id"]), str(x["a"]), str(x["b"])])), JSON.stringify(q17_p1), JSON.stringify(q17_p2), JSON.stringify(q17_p3), q17_pst, JSON.stringify(q17_p4), JSON.stringify(q17_ev.call(q17p, "blessing_granted")), JSON.stringify(q17_ev.call(q17p, "wall_revealed"))],
		q17p.live_edges().size() == 13 and q17_p1 == ["1/1", "0/1"] and q17_p2 == ["1/1", "0/1"] and q17_p3 == ["1/1", "0/1"] and q17_pst == "unblessed" and q17_p4 == ["1/1", "1/1"] \
		and q17_ev.call(q17p, "blessing_granted") == ["petrov met []"] \
		and q17_ev.call(q17p, "wall_revealed") == ["the Petrov blessing -> HOUSE PETROV, COACH PETROV, A PETROV STUDENT (1 of 3), A PETROV STUDENT (2 of 3), A PETROV STUDENT (3 of 3), ANDERS, BARO, HOUSE OKAFOR, HOUSE OSEI"])
	# the Reyes code: blessed by the overworld's flag, La Campana thrown at a fighter above 40 stamina in a dual voids it - revoked, the flag still
	# set and the line never landing again; at 30 stamina it stands; broken before any blessing, the blessing can no longer land
	var q17r := make_sim(17, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "blessing:reyes")); quiet(q17r)
	var q17_r0 := q17r.house_state("reyes")
	q17r._start_cast("P", q17r.library["La Campana"]); q17r.cast = {}; q17r._recruit_check()
	var q17r2 := make_sim(17, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "blessing:reyes")); quiet(q17r2)
	q17r2.B["stamina"] = 30.0; q17r2._start_cast("P", q17r2.library["La Campana"]); q17r2.cast = {}
	var q17r3 := make_sim(17, 7); quiet(q17r3)
	q17r3._start_cast("P", q17r3.library["La Campana"]); q17r3.cast = {}; q17r3.rewards["story"]["blessing:reyes"] = true; q17r3._recruit_check()
	var q17_rv: Array = q17r.events.filter(func(e): return str(e["kind"]) == "blessing_revoked")
	_sr("the Reyes code: blessed by the flag (%s); La Campana at %s stamina -> %s (%s, the wall's crest %s); at 30 -> %s; broken before the blessing, the flag later -> %s" % [q17_r0, str(q17_rv[0]["stamina"]) if q17_rv.size() > 0 else "-", q17r.house_state("reyes"), str(q17_rv[0].get("code", "")) if q17_rv.size() > 0 else "", q17r.sw_state("house_reyes"), q17r2.house_state("reyes"), q17r3.house_state("reyes")],
		q17_r0 == "blessed" and q17_rv.size() == 1 and bool(q17_rv[0]["was_blessed"]) and str(q17_rv[0]["code"]) == "reyes_code" and q17r.house_state("reyes") == "revoked" and not q17r.house_blessed("reyes") \
		and q17r.sw_state("house_reyes") == "revoked" and q17r2.house_state("reyes") == "blessed" and q17r3.house_state("reyes") == "revoked" and not q17r3.house_blessed("reyes"))
	# around the family (Efua): her line is her house's (QUEST(osei_blessing) AND FEUD_RESOLVED(osei_internal)); approached early she is ready on
	# the drafted route (her segment won) and arrives UNSANCTIONED - Shell Game refused, her Deep Roots cast without the home bonus; the blessing
	# lands (the quest and the internal feud), she is sanctioned: Shell Game equipped and her signature back, Harvest Moon and a SECRET refused, and
	# her Deep Roots carries the +10% again
	var q17e := make_sim(11, 7); quiet(q17e); q15_win.call(q17e); q17e.approach("efua_osei")
	var q17_ev0: Dictionary = q17e.recruit_view("efua_osei")
	var q17_ready_ar: int = count_events(q17e.events, "recruit_ready", {"name": "efua_osei", "around": true})
	var q17_ej: bool = bool(q17e.recruit("efua_osei")["ok"])
	var q17_erec: Dictionary = TNBSave.fighter_record(q17e, q17e._stable_card("EFUA"))
	var q17_eq0: String = str(q17e.equip("EFUA", "Shell Game")["why"])
	q17e.new_dual(); var q17_eb: Dictionary = q17e.seal_board({"dress": ["EFUA", "PRIYA", "MARCUS", "JUNE"], "slots": ["EFUA", "PRIYA", "MARCUS"]}); quiet(q17e)
	var q17_mu: float = q17e.hiss_mult("P"); var q17_eu := str(q17e.P["house_status"])
	q15_win.call(q17e)
	q17e.rewards["story"]["quest:osei_blessing"] = true; q17e.rewards["story"]["feud_resolved:osei_internal"] = true; q17e._recruit_check()
	var q17_esanc: int = count_events(q17e.events, "sanctioned", {"card": "EFUA"})
	var q17_eq: Array = [q17e.equip("EFUA", "Shell Game"), q17e.equip("EFUA", "Harvest Moon"), q17e.equip("EFUA", "Through the Window"), q17e.equip("EFUA", "Deep Roots")]
	var q17y := make_sim(1, 7); quiet(q17y); q15_win.call(q17y); q17y.approach("yuri_kowalchuk"); q17y.recruit("yuri_kowalchuk"); q17y.rewards["story"]["blessing:kowalchuk"] = true; q17y._recruit_check()
	var q17_ysec: String = str(q17y.equip("YURI", "Harvest Moon")["why"])
	q17e.new_dual(); quiet(q17e)
	var q17_ms: float = q17e.hiss_mult("P")                                                              # the sealed board carries into the next dual: EFUA in R1
	_sr("around the family: her line %s, around %s (ready around: %d); joins (%s) %s, natives %s; Shell Game: %s; her Deep Roots x%.3f (%s); blessed (%s) -> sanctioned %d; equip %s; YURI's Harvest Moon: %s; her Deep Roots x%.3f (%s)" % [JSON.stringify(q17_ev0["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])), JSON.stringify(q17_ev0.get("around", []).map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])])), q17_ready_ar, str(q17_ej), str(q17_erec["house_status"]), JSON.stringify(q17_erec["natives"]), q17_eq0, q17_mu, q17_eu + " " + str(q17_eb["ok"]), q17e.house_state("osei"), q17_esanc, JSON.stringify(q17_eq.map(func(r): return "ok" if bool(r["ok"]) else str(r["why"]))), q17_ysec, q17_ms, str(q17e.P["house_status"])],
		q17_ev0["clauses"].map(func(c): return "%d/%d" % [int(c["have"]), int(c["need"])]) == ["0/1", "0/1"] and bool(q17_ev0.get("around_met", false)) and q17_ready_ar == 1 and q17_ej \
		and str(q17_erec["house_status"]) == "UNSANCTIONED" and q17_erec["natives"] == [] and q17_eq0 == "EFUA is UNSANCTIONED - House Osei has not blessed the club, the natives stay locked" and q17_eu == "UNSANCTIONED" \
		and q17e.house_state("osei") == "blessed" and q17_esanc == 1 and bool(q17_eb["ok"]) and bool(q17_eq[0]["ok"]) and str(q17_eq[1]["why"]) == "Harvest Moon is not a House Osei move - a card equips its own house's natives as its move (the rest of the library goes in the kit, NP_11 s8)" \
		and bool(q17_eq[2]["ok"]) and bool(q17_eq[3]["ok"]) and q17_ysec == "Harvest Moon is House Kowalchuk's SECRET - its gate event gives it, not the blessing" and str(q17e.P["house_status"]) == "NATIVE" and str(q17e.pname()) == "EFUA" \
		and absf(q17_ms - minf(1.5, q17_mu * 1.1)) < 0.0001 and q17_ms > q17_mu)
	# the live graph (NP_07A s1): E05 flips on its feud_resolved flag (either order) - the house ring's Tension feud between a Moreau and a Tremblay
	# ends and FEUD_RESOLVED reads the edge; E11 answers with the refusal and stays FEUD; E02 waits for both houses' final beats, then flips; E04
	# repaid on okafor_table - an Okafor and a Petrov bond x1.25; the Moreau blessing now reaches House Tremblay across the flipped E05
	var q17g := make_sim(0, 7); quiet(q17g)
	var q17_f0: bool = bool(q17g.rings("SLUGGER", "FROST", "moreau", "OUTBOXER", "FROST", "tremblay")["feud"])
	q17g.rewards["story"]["feud_resolved:tremblay+moreau"] = true; q17g.rewards["story"]["feud_resolved:kowalchuk+reyes"] = true; q17g.rewards["story"]["feud_resolved:reyes+macisaac"] = true; q17g._recruit_check()
	var q17_g1: Array = q17_ev.call(q17g, "graph_mutated") + q17_ev.call(q17g, "graph_refused")
	var q17_fr: Dictionary = q17g.condition_state("FEUD_RESOLVED(moreau, tremblay)", "x")[0]
	var q17_e02a := q17g.edge_relation(q17g._edge_between("reyes", "macisaac"))
	q17g.rewards["story"]["quest:the_bell"] = true; q17g.rewards["story"]["quest:macisaac_harbour"] = true; q17g._recruit_check()
	var q17_lu: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q17_lu[0]["house"] = "okafor"; q17_lu[1]["house"] = "petrov"
	var q17b := make_sim(1, 7, q17_lu); quiet(q17b)
	var q17_kz0: int = q17b._pay_kizuna("RORY", "PRIYA", 8, false, "test")
	q17b.rewards["story"]["quest:okafor_table"] = true; q17b._recruit_check()
	var q17_kz1: int = q17b._pay_kizuna("RORY", "PRIYA", 8, false, "test")
	var q17m := make_sim(2, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "blessing:moreau,feud_resolved:moreau+tremblay"))
	_sr("the live graph: Moreau vs Tremblay a feud before (%s), after %s; FEUD_RESOLVED(moreau, tremblay) %d/%d (%s); E02 on its flag alone %s, with both final beats %s; Kowalchuk vs Reyes still a feud (%s); an Okafor-Petrov pair's +8 -> %d, E04 repaid -> %d; the Moreau blessing with E05 flipped -> %s" % [str(q17_f0), JSON.stringify(q17_g1), int(q17_fr["have"]), int(q17_fr["need"]), str(q17_fr["note"]), q17_e02a, q17g.edge_relation(q17g._edge_between("reyes", "macisaac")), str(q17g.rings("SLUGGER", "GRANITE", "kowalchuk", "SLUGGER", "GRANITE", "reyes")["feud"]), q17_kz0, q17_kz1, JSON.stringify(q17_ev.call(q17m, "wall_revealed"))],
		q17_f0 and q17_g1 == ["E05 FEUD->ALLIED", "E11 refused"] and not bool(q17g.rings("SLUGGER", "FROST", "moreau", "OUTBOXER", "FROST", "tremblay")["feud"]) and bool(q17_fr["met"]) and str(q17_fr["note"]) == "E05 on the feud graph: ALLIED" \
		and q17_e02a == "FEUD" and q17g.edge_relation(q17g._edge_between("reyes", "macisaac")) == "ALLIED" and bool(q17g.rings("SLUGGER", "GRANITE", "kowalchuk", "SLUGGER", "GRANITE", "reyes")["feud"]) \
		and q17_kz0 == 8 and q17_kz1 == 10 and q17_ev.call(q17m, "wall_revealed") == ["the Moreau blessing -> HOUSE MOREAU, JEAN-GUY, REMY, HOUSE TREMBLAY, HOUSE IRON", "HOUSE IRON -> VERA IRON"])
	# the save (NP_11 s9): the house codex (the houses met, their lines, blessings and members), the feud graph as it stands, each Fighter's
	# house_status and unlocked natives - written from the ledgers, read back by a load that grants and flips nothing, written again byte-equal
	q17k.rewards["story"]["feud_resolved:moreau+tremblay"] = true; q17k._recruit_check()
	var q17_sv: Dictionary = TNBSave.to_save(q17k)
	var q17_txt: String = TNBSave.write_text(q17k, false)
	var q17kl = TNBSave.build(content, TNBSave.read_text(q17_txt), 5)["sim"]
	var q17_yrec: Dictionary = {}
	for q17_f in q17_sv["stable"]:
		if str(q17_f["name"]) == "YURI": q17_yrec = q17_f
	var q17_cx: Dictionary = q17_sv["house_codex"]
	_sr("the save: the codex %s (Kowalchuk %s by %s, members %s); the graph %d mutation(s) %s; YURI's record %s %s, RORY's %s; a load grants %d, flips %d, and the text written again %s" % [JSON.stringify(q17_cx.keys()), str(q17_cx.get("kowalchuk", {}).get("state", "")), str(q17_cx.get("kowalchuk", {}).get("how", "")), JSON.stringify(q17_cx.get("kowalchuk", {}).get("members", [])), int(q17_sv["feud_graph_state"]["mutations"]), JSON.stringify(q17_sv["feud_graph_state"]["graph"].filter(func(x): return x.has("was"))), str(q17_yrec.get("house_status", "")), JSON.stringify(q17_yrec.get("natives", [])), str(q17_sv["stable"][0].get("house_status")), count_events(q17kl.events, "blessing_granted"), count_events(q17kl.events, "graph_mutated"), "byte-equal" if TNBSave.write_text(q17kl, false) == q17_txt else "DIFFERENT"],
		q17_cx.has("kowalchuk") and q17_cx.has("whitecloud") and str(q17_cx["kowalchuk"]["state"]) == "blessed" and str(q17_cx["kowalchuk"]["how"]) == "met" and q17_cx["kowalchuk"]["members"] == [{"card": "YURI", "status": "NATIVE"}] \
		and int(q17_sv["feud_graph_state"]["mutations"]) == 1 and int(q17_sv["feud_graph_state"]["edges"]) == 12 and str(q17_yrec.get("house_status", "")) == "NATIVE" and q17_yrec.get("natives", []) == ["Grain Elevator", "Full Load"] \
		and q17_sv["stable"][0].get("house_status") == null and count_events(q17kl.events, "blessing_granted") == 0 and count_events(q17kl.events, "graph_mutated") == 0 and TNBSave.write_text(q17kl, false) == q17_txt)

	# ---- PAC-078: HOUSE TRAITS (NP_07 s3, s5) ----
	var q18_lu := func(q18_card: Dictionary) -> Array:
		var q18_c: Dictionary = q18_card.duplicate(true); q18_c.erase("reserve")
		return [q18_c, TNBSim.LINEUP_MILLBROOK[1].duplicate(true), TNBSim.LINEUP_MILLBROOK[2].duplicate(true), TNBSim.LINEUP_MILLBROOK[3].duplicate(true)]
	var q18_card := func(q18_name: String, q18_house: String, q18_extra: Dictionary = {}) -> Dictionary:
		var q18_c: Dictionary = TNBSim.LINEUP_MILLBROOK[0].duplicate(true); q18_c["name"] = q18_name; q18_c["house"] = q18_house
		for q18_k in q18_extra: q18_c[q18_k] = q18_extra[q18_k]
		return q18_c
	var q18a := make_sim(0, 7)
	# the data and who carries what: nine authored traits and three variants named, not run; across the 24 bosses a trait for blood only - Chiamaka's
	# root line and Itzel's origin line carry theirs, Anders (taken), Baro (a teaching root system), HC-7 (extracted) and Cal (sealed) none, the
	# Moreaus none (a variant); the Millbrook four carry theirs; a disowned heir none; the Moreau variant run as its base when executed
	var q18_td: Dictionary = content["houses"]["traits"]
	var q18_auth := 0; var q18_var := 0
	for q18_t in q18_td:
		if q18_td[q18_t].has("base"): q18_var += 1
		else: q18_auth += 1
	var q18_car := {}
	for q18_b in TNBSim.BOSSES:
		var q18_tr: Dictionary = q18a.trait_of_house(str(content["patterns"][q18_b].get("meta", {}).get("house", "none")))
		if q18_tr.size() > 0: q18_car[q18_b] = str(q18_tr["id"])
	var q18_mb := {}
	for q18_c in TNBSim.LINEUP_MILLBROOK_8:
		var q18_ct: Dictionary = q18a.card_trait(q18_c)
		if q18_ct.size() > 0: q18_mb[str(q18_c["name"])] = str(q18_ct["id"])
	var q18_dis: Dictionary = q18a.card_trait(q18_card.call("HEIR", "tagaq", {"disowned": true}))
	var q18_keep: Dictionary = q18a.HOUSES; q18a.HOUSES = q18_keep.duplicate(true); q18a.HOUSES["traits"]["load_bearing_variant"]["executed"] = true
	var q18_jg: Dictionary = q18a.trait_of_house("moreau"); q18a.HOUSES = q18_keep
	_sr("house traits as data (NP_07 s3): %d authored, %d variants named; the 24's carriers %s; the Millbrook eight %s; a disowned Tagaq heir %s; the Moreau variant executed runs %s" % [q18_auth, q18_var, JSON.stringify(q18_car), JSON.stringify(q18_mb), JSON.stringify(q18_dis), JSON.stringify(q18_jg)],
		q18_auth == 9 and q18_var == 3 and q18_car == {"yuri_kowalchuk": "load_bearing", "sam_tagaq": "never_twice", "ada_okafor": "harvest", "carter_okafor": "harvest", "chiamaka_okafor": "harvest", "efua_osei": "deep_roots", "itzel_reyes_ortega": "debt_of_honour", "marta_okonkwo_tremblay": "first_frost", "moira_macisaac": "tide_discipline", "tam_nguyen_roy": "open_door"} \
		and q18_mb == {"SAM": "never_twice", "DEX": "tide_discipline", "YURI": "load_bearing", "MARTA": "first_frost"} and q18_dis.is_empty() and str(q18_jg.get("id", "")) == "load_bearing" and str(q18_jg.get("trait", "")) == "load_bearing_variant")
	# Never Twice, both corners: SAM in your R1 dropped a second time in the segment wobbles instead and stays up; the third drop counts (once a
	# dual); Sam in his: the same, and a new dual gives it back
	var q18n := make_sim(0, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[4])); quiet(q18n)
	var q18_np: Array = []
	for q18_i in 3:
		q18n.mode = "FIGHT"; q18n.eight = {}; q18n._drop(true); q18_np.append(int(q18n.P["drops"]))
	var q18_nw := q18n._wobbled(q18n.P)
	var q18nb := make_sim(3, 7); quiet(q18nb)
	var q18_nb: Array = []
	for q18_i in 3: q18nb._drop(false); q18_nb.append(int(q18nb.B["drops"]))
	q18nb.new_dual(); quiet(q18nb); q18nb._drop(false); q18nb._drop(false)
	var q18_nb2 := int(q18nb.B["drops"])
	_sr("Never Twice: SAM's drops through three knockdowns %s (the second a wobble: %s, %d NEVER TWICE), Sam's %s, a new dual's second %d" % [JSON.stringify(q18_np), str(q18_nw), count_events(q18n.events, "trait", {"trait": "never_twice"}), JSON.stringify(q18_nb), q18_nb2],
		q18_np == [1, 1, 2] and q18_nw and count_events(q18n.events, "trait", {"trait": "never_twice", "who": "P"}) == 1 and q18_nb == [1, 1, 2] and q18_nb2 == 1 and int(q18n.score_b) == 2)
	# Deep Roots: EFUA's guard regenerates 50% faster while her side trails on drops, RORY's does not; recruited around her family she is
	# UNSANCTIONED and carries it still (NP_07 s5 takes the home bonus, not the trait)
	var q18_greg := func(q18_s: TNBSim, q18_trail: bool) -> float:
		q18_s.drops_p = 0; q18_s.drops_b = 1 if q18_trail else 0
		q18_s.P["guard"] = 10.0; q18_s.P["blocking"] = false; q18_s.step({})
		return float(q18_s.P["guard"]) - 10.0
	var q18d := make_sim(0, 7, q18_lu.call(q18a.recruit_card("efua_osei"))); quiet(q18d); freeze_boss(q18d); place(q18d)
	var q18_d0: float = q18_greg.call(q18d, false); var q18_d1: float = q18_greg.call(q18d, true)
	var q18dr := make_sim(0, 7); quiet(q18dr); freeze_boss(q18dr); place(q18dr)
	var q18_r0: float = q18_greg.call(q18dr, false); var q18_r1: float = q18_greg.call(q18dr, true)
	var q18du := make_sim(11, 7); quiet(q18du); q15_win.call(q18du); q18du.approach("efua_osei"); q18du.recruit("efua_osei")
	q18du.new_dual(); q18du.seal_board({"dress": ["EFUA", "PRIYA", "MARCUS", "JUNE"], "slots": ["EFUA", "PRIYA", "MARCUS"]})
	_sr("Deep Roots: EFUA's guard regen level %.4f, trailing on drops %.4f (x%.2f); RORY's %.4f / %.4f; EFUA recruited around her family %s carries %s" % [q18_d0, q18_d1, q18_d1 / q18_d0, q18_r0, q18_r1, str(q18du.P["house_status"]), str(q18du.P["trait"].get("name", "none"))],
		absf(q18_d1 / q18_d0 - 1.5) < 0.001 and absf(q18_r1 - q18_r0) < 0.00001 and str(q18du.P["house_status"]) == "UNSANCTIONED" and str(q18du.P["trait"].get("id", "")) == "deep_roots" and q18du.pname() == "EFUA")
	# the stats: Long Winter's +10% in the R4 slot and not in R1; Debt of Honour's +25% for Itzel against YURI (E11) and DEX (E02) and for a
	# Reyes card against Yuri, gone once the questlines flip E02; the last of a dead lineage doubles it (a Long Winter Iron in R4 at +20%)
	var q18_l8: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true); q18_l8[3]["house"] = "whitecloud"
	var q18w := make_sim(0, 7, q18_l8, "sanctioned"); quiet(q18w)
	var q18w1 := make_sim(0, 7, q18_lu.call(q18_l8[3]))                                                   # the same Whitecloud MARCUS in a mini dual's R1
	var q18_w1: float = float(q18w1.P["stats"]["PWR"])
	for q18_i in 3:
		seg_end.call(q18w, 4)
		if q18w.mode != "OVER": next_segment(q18w)
	var q18_w4: float = float(q18w.P["stats"]["PWR"]); var q18_w4n: String = q18w.pname()
	var q18i := make_sim(17, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[6])); var q18i0 := make_sim(17, 7)
	var q18ix := make_sim(17, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[5]))
	var q18iy := make_sim(17, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[5]), "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:the_bell,quest:macisaac_harbour,feud_resolved:reyes+macisaac"))
	var q18pr := make_sim(1, 7, q18_lu.call(q18_card.call("REYES", "reyes")))
	var q18_hk: Dictionary = content["houses"]; content["houses"] = q18_hk.duplicate(true); content["houses"]["houses"]["iron"]["trait_id"] = "long_winter"
	var q18_i8: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true); q18_i8[3]["house"] = "iron"
	var q18v := make_sim(0, 7, q18_i8, "sanctioned"); quiet(q18v)
	for q18_i in 3:
		seg_end.call(q18v, 4)
		if q18v.mode != "OVER": next_segment(q18v)
	content["houses"] = q18_hk
	_sr("the stats: MARCUS of Whitecloud PWR %.0f in R1, %.1f in R4 (%s); Itzel's PWR vs YURI %.0f, vs RORY %.0f, vs DEX %.0f, with E02 flipped %.0f; a Reyes card vs Yuri %.2f; an Iron MARCUS doubled in R4 %.0f" % [q18_w1, q18_w4, q18_w4n, float(q18i.B["stats"]["PWR"]), float(q18i0.B["stats"]["PWR"]), float(q18ix.B["stats"]["PWR"]), float(q18iy.B["stats"]["PWR"]), float(q18pr.P["stats"]["PWR"]), float(q18v.P["stats"]["PWR"])],
		q18_w1 == 70.0 and absf(q18_w4 - 77.0) < 0.001 and q18_w4n == "MARCUS" and absf(float(q18i.B["stats"]["PWR"]) - 75.0) < 0.001 and float(q18i0.B["stats"]["PWR"]) == 60.0 and absf(float(q18ix.B["stats"]["PWR"]) - 75.0) < 0.001 \
		and float(q18iy.B["stats"]["PWR"]) == 60.0 and absf(float(q18pr.P["stats"]["PWR"]) - 56.25) < 0.001 and absf(float(q18v.P["stats"]["PWR"]) - 84.0) < 0.001 and float(TNBSim.LINEUP_MILLBROOK_8[3]["stats"]["PWR"]) == 70.0)
	# First Frost and Harvest: MARTA's slip window 100 ms wider in the segment's opening 15 s and not after, RORY's the same throughout; ADA's clean
	# hit earns one more Tension than the same hit without her trait; Carter's the same on his side
	var q18f := make_sim(0, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[7])); quiet(q18f)
	var q18_f0: int = q18f._window("slip"); q18f.seg_tick0 -= TNBSim.ms(16000); var q18_f1: int = q18f._window("slip")
	var q18fr := make_sim(0, 7); quiet(q18fr)
	var q18_fr0: int = q18fr._window("slip"); q18fr.seg_tick0 -= TNBSim.ms(16000); var q18_fr1: int = q18fr._window("slip")
	var q18_hv := func(q18_on: bool) -> float:
		var q18_s := make_sim(0, 7, q18_lu.call(q18a.recruit_card("ada_okafor"))); quiet(q18_s); freeze_boss(q18_s); place(q18_s)
		if not q18_on: q18_s.P["trait"] = {}
		q18_s.B["comp"] = 200.0; var q18_t0: float = q18_s.tension
		throw_clean(q18_s, "R_STRAIGHT"); land(q18_s)
		return q18_s.tension - q18_t0
	var q18_hvb := func(q18_on: bool) -> float:
		var q18_s := make_sim(7, 7); quiet(q18_s); freeze_boss(q18_s); place(q18_s); clear_defense(q18_s.P)
		if not q18_on: q18_s.B["trait"] = {}
		var q18_t0: float = q18_s.btension
		boss_lands(q18_s, "R_HOOK")
		return q18_s.btension - q18_t0
	var q18_ha: float = q18_hv.call(true); var q18_hb: float = q18_hv.call(false); var q18_hc: float = q18_hvb.call(true); var q18_hd: float = q18_hvb.call(false)
	_sr("First Frost: MARTA's slip window %d ticks opening, %d after (RORY %d / %d); Harvest: ADA's clean hit +%.2f Tension (+%.2f without the trait), Carter's +%.2f (+%.2f)" % [q18_f0, q18_f1, q18_fr0, q18_fr1, q18_ha, q18_hb, q18_hc, q18_hd],
		q18_f0 - q18_f1 == TNBSim.ms(100) and q18_fr0 == q18_fr1 and absf(q18_ha - q18_hb - 1.0) < 0.001 and q18_hb > 0.0 and absf(q18_hc - q18_hd - 1.0) < 0.001)
	# Load-Bearing and Tide Discipline, both corners: 12 composure damage is 10 on the ropes or in the corner for Yuri and for YURI, 12 in the middle;
	# a lean's 5 stamina stops at 10 for Moira and for DEX, and goes to 7 for Vane
	var q18y := make_sim(1, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[6])); quiet(q18y)
	q18y.B["pos"] = Vector2(3.3, 0.0); var q18_yb1: float = q18y._comp_damage("B", 12.0, {})
	q18y.B["pos"] = Vector2(0.0, -0.8); var q18_yb0: float = q18y._comp_damage("B", 12.0, {})
	q18y.P["pos"] = Vector2(3.0, 3.0); var q18_yp1: float = q18y._comp_damage("P", 12.0, {})
	q18y.P["pos"] = Vector2(0.0, 0.8); var q18_yp0: float = q18y._comp_damage("P", 12.0, {})
	var q18t := make_sim(19, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[5])); quiet(q18t)
	q18t.B["stamina"] = 12.0; q18t.B["dodge_t"] = 0; q18t._set_dodge(q18t.B, "LEAN", 1)
	q18t.P["stamina"] = 12.0; q18t.P["dodge_t"] = 0; q18t._set_dodge(q18t.P, "LEAN", 1)
	var q18t0 := make_sim(0, 7); quiet(q18t0); q18t0.B["stamina"] = 12.0; q18t0.B["dodge_t"] = 0; q18t0._set_dodge(q18t0.B, "LEAN", 1)
	_sr("Load-Bearing: Yuri takes %.1f on the ropes, %.1f in the middle; YURI %.1f in the corner, %.1f in the middle; Tide Discipline: a lean at 12 stamina leaves Moira %.1f, DEX %.1f, Vane %.1f" % [q18_yb1, q18_yb0, q18_yp1, q18_yp0, float(q18t.B["stamina"]), float(q18t.P["stamina"]), float(q18t0.B["stamina"])],
		absf(q18_yb1 - 10.0) < 0.001 and q18_yb0 == 12.0 and absf(q18_yp1 - 10.0) < 0.001 and q18_yp0 == 12.0 and float(q18t.B["stamina"]) == 10.0 and float(q18t.P["stamina"]) == 10.0 and float(q18t0.B["stamina"]) == 7.0)
	# Open Door: TAM's bonds grow x1.5 (8 -> 12), a pair without him 8; with an ALLIED edge under it the larger of the two, never both (12, not 15);
	# an ALLIED pair without him x1.25 (10)
	var q18o := make_sim(0, 7, q18_lu.call(q18a.recruit_card("tam_nguyen_roy"))); quiet(q18o)
	var q18_o1: int = q18o._pay_kizuna("TAM", "PRIYA", 8, false, "test"); var q18_o0: int = q18o._pay_kizuna("PRIYA", "MARCUS", 8, false, "test")
	var q18_ol: Array = q18_lu.call(q18a.recruit_card("tam_nguyen_roy")); q18_ol[1]["house"] = "delacroix-cardinal"
	var q18o2 := make_sim(0, 7, q18_ol); quiet(q18o2); q18o2.rewards["graph"]["E07"] = {"from": "MARRIAGE", "to": "ALLIED", "day": 1, "on": ["test"]}
	var q18_o2: int = q18o2._pay_kizuna("TAM", "PRIYA", 8, false, "test")
	var q18_al: Array = q18_lu.call(q18_card.call("KOW", "kowalchuk")); q18_al[1]["house"] = "whitecloud"
	var q18o3 := make_sim(0, 7, q18_al); quiet(q18o3)
	var q18_o3: int = q18o3._pay_kizuna("KOW", "PRIYA", 8, false, "test")
	_sr("Open Door: TAM and PRIYA +%d for 8, PRIYA and MARCUS +%d; TAM and an ALLIED partner +%d; an ALLIED pair without him +%d" % [q18_o1, q18_o0, q18_o2, q18_o3],
		q18_o1 == 12 and q18_o0 == 8 and q18_o2 == 12 and q18_o3 == 10)
	# in play and on record: the segment names both corners' traits (YURI's Load-Bearing against Sam's Never Twice); the codex names a house's
	# trait live or why not (Moreau's variant); the Fighter record carries it
	var q18e := make_sim(3, 7, q18_lu.call(TNBSim.LINEUP_MILLBROOK_8[6]))
	var q18_te: Array = q18e.events.filter(func(e): return str(e["kind"]) == "traits")
	var q18_rec: Dictionary = TNBSave.fighter_record(q18e, q18e.lineup[0])
	var q18_cx: Dictionary = q17k.house_codex()
	_sr("in play: the traits at the bell %s; YURI's Fighter record carries %s, RORY's %s; the codex's Kowalchuk trait live %s, a Moreau house's %s" % [JSON.stringify(q18_te.map(func(e): return "%s / %s" % [str(e["p"].get("name", "")), str(e["b"].get("name", ""))])), str(q18_rec.get("trait")), str(TNBSave.fighter_record(q18e, q18e.lineup[1]).get("trait")), str(q18_cx.get("kowalchuk", {}).get("trait_live", "")), str(q18a.trait_of_house("moreau").size() > 0)],
		q18_te.size() == 1 and str(q18_te[0]["p"]["id"]) == "load_bearing" and str(q18_te[0]["b"]["id"]) == "never_twice" and str(q18_rec.get("trait")) == "Load-Bearing" and TNBSave.fighter_record(q18e, q18e.lineup[1]).get("trait") == null \
		and bool(q18_cx.get("kowalchuk", {}).get("trait_live", false)) and q18a.trait_of_house("moreau").is_empty())

	# ---- PAC-079: THE GYM WALL (NP_08 s7) ----
	var q19_cells := func(q19_s: TNBSim) -> Dictionary:
		var q19_o := {}
		for q19_c in q19_s.gym_wall_view()["layout"].get("cards", []): q19_o[str(q19_c["name"])] = [int(q19_c["x"]), int(q19_c["y"])]
		return q19_o
	var q19_kinds := func(q19_s: TNBSim) -> Array: return q19_s.gym_wall.get("decos", []).map(func(d): return str(d["kind"]))
	var q19_labels := func(q19_s: TNBSim) -> Array: return q19_s.gym_wall.get("decos", []).map(func(d): return str(d["label"]))
	var q19_order := func(q19_s: TNBSim) -> Array: return q19_s.lineup.map(func(f): return str(f["name"]))
	# the data and the default wall: an 8 x 4 wall of card cells, Whitlock's letter at the left of the top row (NP_12A scene 1), the club's cards
	# pinned from the cell beside it in the stable's order - the four along the top row, the eight wrapping to the second; nothing else hangs until
	# play puts it there; the table rides the content stamp
	var q19_gw: Dictionary = content["gym_wall"]
	var q19a := make_sim(0, 7)
	var q19a8 := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q19_v: Dictionary = q19a.gym_wall_view()
	var q19_st0: int = q19a.content_stamp()
	var q19_keep: Dictionary = q19a.GYMWALL; q19a.GYMWALL = q19_keep.duplicate(true); q19a.GYMWALL["grid"]["w"] = 9
	var q19_st1: int = q19a.content_stamp(); q19a.GYMWALL = q19_keep
	_sr("the Gym Wall as data (NP_08 s7): %s, %d x %d cells, decorations %s; the four pinned %s; the eight %s; hanging %s; a changed wall table changes the content stamp (%s), restored the same (%s)" % [str(q19_gw["schema"]), int(q19_v["layout"]["grid"][0]), int(q19_v["layout"]["grid"][1]), JSON.stringify(q19_gw["decorations"].keys()), JSON.stringify(q19_cells.call(q19a)), JSON.stringify(q19_cells.call(q19a8)), JSON.stringify(q19_v["decorations"].map(func(d): return "%s (%.1f, %.1f)" % [str(d["label"]), float(d["x"]), float(d["y"])])), str(q19_st1 != q19_st0), str(q19a.content_stamp() == q19_st0)],
		str(q19_gw["schema"]) == "GymWall/NP_08-s7/v1.0" and q19_v["layout"]["grid"] == [8, 4] and q19_gw["decorations"].keys() == ["poster", "stub", "polaroid", "graffiti", "renovation", "crest", "feat"] \
		and q19_cells.call(q19a) == {"RORY": [1, 0], "PRIYA": [2, 0], "MARCUS": [3, 0], "JUNE": [4, 0]} \
		and q19_cells.call(q19a8) == {"RORY": [1, 0], "JUNE": [2, 0], "PRIYA": [3, 0], "MARCUS": [4, 0], "SAM": [5, 0], "DEX": [6, 0], "YURI": [7, 0], "MARTA": [0, 1]} \
		and q19_v["decorations"].size() == 1 and str(q19_v["decorations"][0]["kind"]) == "letter" and float(q19_v["decorations"][0]["x"]) == 0.5 and q19_v["layout"]["unpinned"].is_empty() and q19_v["layout"]["lines"].is_empty() \
		and q19_st1 != q19_st0 and q19a.content_stamp() == q19_st0)
	# the player's hand: any stablemate's card to any free cell - refused for a card not in the stable, a cell off the wall, a cell taken (naming
	# whose); a decoration anywhere inside the wall - refused off it, or for one not hanging; each pin an event
	var q19_ref: Array = []
	for q19_p in [["BOB", 0, 3], ["RORY", 8, 0], ["RORY", 2, 0]]: q19_ref.append(str(q19a.pin(str(q19_p[0]), int(q19_p[1]), int(q19_p[2]))["why"]))
	var q19_ok1: bool = bool(q19a.pin("RORY", 0, 3)["ok"]); var q19_at1: Array = q19_cells.call(q19a)["RORY"]
	var q19_ok2: bool = bool(q19a.pin("RORY", 1, 0)["ok"])
	var q19_ar: Array = [str(q19a.arrange("letter", 9.0, 1.0)["why"]), str(q19a.arrange("poster-1", 1.0, 1.0)["why"])]
	var q19_ok3: bool = bool(q19a.arrange("letter", 7.5, 5.5)["ok"])
	_sr("the player's hand: refused %s; RORY pinned to %s and back (%s / %s); a decoration refused %s; the letter moved to (%.1f, %.1f) (%s); %d pins by hand, %d refusals as events" % [JSON.stringify(q19_ref), JSON.stringify(q19_at1), str(q19_ok1), str(q19_ok2), JSON.stringify(q19_ar), float(q19a.gym_wall["decos"][0]["x"]), float(q19a.gym_wall["decos"][0]["y"]), str(q19_ok3), count_events(q19a.events, "card_pinned", {"by": "hand"}), count_events(q19a.events, "pin_refused")],
		q19_ref == ["BOB is not in the stable", "(8, 0) is off the wall (8 x 4 cells)", "PRIYA's card is on (2, 0)"] and q19_ok1 and q19_at1 == [0, 3] and q19_ok2 and q19_cells.call(q19a)["RORY"] == [1, 0] \
		and q19_ar == ["(9.0, 1.0) is off the wall", "no decoration 'poster-1'"] and q19_ok3 and float(q19a.gym_wall["decos"][0]["x"]) == 7.5 and float(q19a.gym_wall["decos"][0]["y"]) == 5.5 \
		and count_events(q19a.events, "card_pinned", {"by": "hand"}) == 2 and count_events(q19a.events, "pin_refused") == 3)
	# NP_10 s2's suggestion (the formation screen's 6): the starters in the order that walks the wall the shortest way - MARCUS pinned under RORY and
	# PRIYA under him suggests R1 RORY, R2 MARCUS, R3 PRIYA (a walk of 2 cells); the pins alone move nothing (the card order fights until the player
	# seals the suggestion); sealed, it is the order; a board sealed otherwise stands whatever the wall says, and from the bell the whiteboard stops
	# suggesting; the sanctioned five walk the top row in card order, and with SAM pinned under RORY walk MARCUS-PRIYA-JUNE-RORY-SAM (4 cells: its
	# mirror ties and the card order breaks the tie)
	var q19b := make_sim(0, 7); quiet(q19b)
	q19b.pin("MARCUS", 1, 1); q19b.pin("PRIYA", 1, 2)
	var q19_sg: Dictionary = q19b.gym_wall_suggestion(); var q19_pre: Array = q19_order.call(q19b)
	var q19_wl: bool = q19b.formation_lines().has("THE GYM WALL SUGGESTS (6): R1 RORY  R2 MARCUS  R3 PRIYA")
	var q19_sb: Dictionary = q19b.seal_board({"archetype": "GYM_WALL"})
	var q19_post: Array = q19_order.call(q19b)
	var q19_bl: String = str(q19b.formation_lines()[0])
	var q19c := make_sim(0, 7); quiet(q19c); q19c.seal_board({"archetype": "AMBUSH"}); var q19_amb: Array = q19_order.call(q19c)
	q19c.pin("MARCUS", 1, 1); q19c.pin("PRIYA", 1, 2)
	var q19_amb2: Array = q19_order.call(q19c); var q19_csg: Array = q19c.gym_wall_suggestion()["slots"]
	q19c.step({}); q19c.pin("JUNE", 7, 3)
	var q19_bell_sg := false
	for q19_fln in q19c.formation_lines():
		if str(q19_fln).begins_with("THE GYM WALL SUGGESTS"): q19_bell_sg = true
	var q19s := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); quiet(q19s)
	var q19_s0: Dictionary = q19s.gym_wall_suggestion()
	q19s.pin("SAM", 1, 1); var q19_s1: Dictionary = q19s.gym_wall_suggestion()
	_sr("the wall's suggestion: %s (walk %.1f, reserves %s; %s); the pins alone leave %s; sealed (%s) %s - %s; Ambush sealed %s, the cards moved %s (the wall suggests %s), at the bell no suggestion (%s); the sanctioned five %s (walk %.1f), SAM under RORY %s (walk %.1f)" % [JSON.stringify(q19_sg["slots"]), float(q19_sg["walk"]), JSON.stringify(q19_sg["reserves"]), JSON.stringify(q19_sg["why"]), JSON.stringify(q19_pre), str(q19_sb["ok"]), JSON.stringify(q19_post), q19_bl.left(60), JSON.stringify(q19_amb), JSON.stringify(q19_amb2), JSON.stringify(q19_csg), str(not q19_bell_sg), JSON.stringify(q19_s0["slots"]), float(q19_s0["walk"]), JSON.stringify(q19_s1["slots"]), float(q19_s1["walk"])],
		q19_sg["slots"] == ["RORY", "MARCUS", "PRIYA"] and float(q19_sg["walk"]) == 2.0 and q19_sg["reserves"] == ["JUNE"] and q19_wl and q19_pre == ["RORY", "PRIYA", "MARCUS"] \
		and bool(q19_sb["ok"]) and q19_post == ["RORY", "MARCUS", "PRIYA"] and q19b.sealed_p == ["RORY", "MARCUS", "PRIYA"] and str(q19b.board.get("archetype", "")) == "GYM_WALL" and q19_bl.begins_with("YOUR BOARD [The Gym Wall]: R1 RORY  R2 MARCUS  R3 PRIYA") \
		and q19_amb2 == q19_amb and q19_csg == ["RORY", "MARCUS", "PRIYA"] and q19_amb != q19_csg and q19c.sealed_p == q19_amb and not q19_bell_sg \
		and q19_s0["slots"] == ["RORY", "JUNE", "PRIYA", "MARCUS", "SAM"] and float(q19_s0["walk"]) == 4.0 and q19_s1["slots"] == ["MARCUS", "PRIYA", "JUNE", "RORY", "SAM"] and float(q19_s1["walk"]) == 4.0 and q19_s1["reserves"] == ["DEX", "YURI", "MARTA"])
	# the Kizuna lines (NP_08 s7): a line for every pair of pinned cards with any Kizuna, filled toward the next level - RORY and PRIYA at 30 are
	# Corner Voices a fifth of the way to Adjacent Trust, JUNE and MARCUS at 5 half way to Gymmates - and gilded at Sworn (PRIYA and MARCUS at 150);
	# a pair with a card off the wall draws none; a wall of two cells hangs two cards and keeps the rest in the locker (the walk pays 100 a gap)
	var q19d := make_sim(0, 7); quiet(q19d)
	q19d.rewards["kizuna"][TNBSim.pair_key("RORY", "PRIYA")] = 30; q19d.rewards["kizuna"][TNBSim.pair_key("PRIYA", "MARCUS")] = 150
	q19d.rewards["kizuna"][TNBSim.pair_key("JUNE", "MARCUS")] = 5; q19d.rewards["kizuna"][TNBSim.pair_key("DEX", "RORY")] = 40
	var q19_ln: Array = q19d.gym_wall_view()["layout"]["lines"].map(func(l): return "%s-%s Lv%d %s %.2f%s" % [str(l["a"]), str(l["b"]), int(l["level"]), str(l["name"]), float(l["fill"]), " GILDED" if bool(l["gilded"]) else ""])
	var q19_lt: String = ""
	for q19_x in q19d.gym_wall_lines():
		if str(q19_x).begins_with("LINES: "): q19_lt = str(q19_x)
	var q19_kc: Dictionary = content["gym_wall"]; content["gym_wall"] = q19_kc.duplicate(true); content["gym_wall"]["grid"]["w"] = 2; content["gym_wall"]["grid"]["h"] = 1
	var q19f := make_sim(0, 7)
	content["gym_wall"] = q19_kc
	var q19_fl: Array = []
	for q19_x in q19f.gym_wall_lines():
		if str(q19_x).begins_with("IN THE LOCKER"): q19_fl.append(str(q19_x))
	_sr("the Kizuna lines: %s (%s); a wall of 2 cells hangs %s, the locker %s (%s), %d wall_full; its suggestion %s (walk %.0f)" % [JSON.stringify(q19_ln), q19_lt, JSON.stringify(q19_cells.call(q19f)), JSON.stringify(q19f.gym_wall["unpinned"]), JSON.stringify(q19_fl), count_events(q19f.events, "wall_full"), JSON.stringify(q19f.gym_wall_suggestion()["slots"]), float(q19f.gym_wall_suggestion()["walk"])],
		q19_ln == ["RORY-PRIYA Lv2 Corner Voices 0.20", "PRIYA-MARCUS Lv5 Sworn 1.00 GILDED", "MARCUS-JUNE Lv0  0.50"] and q19_lt == "LINES: RORY-PRIYA Corner Voices 20%, PRIYA-MARCUS Sworn GILDED, MARCUS-JUNE 50%" \
		and q19_cells.call(q19f) == {"RORY": [1, 0], "PRIYA": [0, 0]} and q19f.gym_wall["unpinned"] == ["MARCUS", "JUNE"] and q19_fl == ["IN THE LOCKER (no cell free): MARCUS, JUNE"] and count_events(q19f.events, "wall_full") == 2 \
		and q19f.gym_wall_suggestion()["slots"] == ["RORY", "PRIYA", "MARCUS"] and float(q19f.gym_wall_suggestion()["walk"]) == 101.0)
	# decorations from play (NP_08 s7): a dual won hangs a fight poster and - the first time against that club - a ticket stub; a second dual against
	# the club, lost, hangs neither; a first dual against another club, lost, its stub alone; every Kizuna level crossed hangs the bond scene's
	# polaroid (as many polaroids as levels the ledger's pairs hold); a recruit's wraps signed on the wall, and his card beside the stablemate whose
	# string brought him (ADA's beside CARTER's, CARTER pinned down the wall); each unlock an event
	var q19e := make_sim(1, 7); quiet(q19e); q15_win.call(q19e)
	var q19_e1: Array = q19_labels.call(q19e).filter(func(x): return not str(x).contains(" & "))
	q19e.new_dual(); quiet(q19e); q15_lose.call(q19e)
	var q19_e2: Array = q19_kinds.call(q19e)
	var q19_lvs := 0
	for q19_pk in q19e.rewards["kizuna"]: q19_lvs += q19e.kizuna_level(str(q19_pk).split("|")[0], str(q19_pk).split("|")[1])
	var q19_pl0: int = q19_e2.count("polaroid")
	var q19_kz0: int = q19e.kizuna_pts("JUNE", "RORY")
	q19e._pay_kizuna("RORY", "JUNE", 10 - q19_kz0 if q19_kz0 < 10 else 1, false, "test")
	var q19_last: String = str(q19_labels.call(q19e)[-1])
	var q19f3 := make_sim(3, 7); quiet(q19f3); q15_lose.call(q19f3)
	var q19g := make_sim(7, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "rep:rink_district:3,quest:okafor_table")); quiet(q19g); q15_win.call(q19g)
	q19g.approach("carter_okafor"); q15_scrap_win.call(q19g, 7); q15_scrap_win.call(q19g, 7); q15_scrap_win.call(q19g, 7)
	var q19_cj: bool = bool(q19g.recruit("carter_okafor")["ok"]); var q19_cat: Array = q19_cells.call(q19g).get("CARTER", [])
	q19g.pin("CARTER", 5, 2); q19g.rewards["kizuna"][TNBSim.pair_key("CARTER", "RORY")] = 90
	q19g.events.clear()
	var q19_aj: bool = bool(q19g.recruit("ada_okafor")["ok"])
	_sr("decorations from play: a dual won vs Yuri's squad hangs %s; lost to them next %s (%d polaroids for %d levels held); a bond crossing a level hangs '%s'; a first dual lost vs Sam's squad %s; CARTER signs at %s (%s), pinned to (5, 2), ADA signs (%s) at %s beside him - the wall %s, %d unlocked" % [JSON.stringify(q19_e1), JSON.stringify(q19_e2), q19_pl0, q19_lvs, q19_last, JSON.stringify(q19_labels.call(q19f3)), JSON.stringify(q19_cat), str(q19_cj), str(q19_aj), JSON.stringify(q19_cells.call(q19g).get("ADA", [])), JSON.stringify(q19_labels.call(q19g).filter(func(x): return not str(x).contains(" & "))), count_events(q19g.events, "decoration_unlocked")],
		q19_e1.size() == 3 and str(q19_e1[1]).begins_with("MILLBROOK vs ") and q19_e2.count("poster") == 1 and q19_e2.count("stub") == 1 and q19_pl0 == q19_lvs and q19_last == "JUNE & RORY - Gymmates" \
		and q19_kinds.call(q19f3) == ["letter", "stub"] and q19_cj and q19_cat == [5, 0] and q19_aj and q19_cells.call(q19g).get("ADA", []) == [5, 1] and q19_kinds.call(q19g).count("graffiti") == 2 \
		and str(q19_labels.call(q19g)[-1]) == "ADA's wraps" and count_events(q19g.events, "decoration_unlocked", {"deco": "graffiti"}) == 1 \
		and q19_e1[1] == "MILLBROOK vs Prairie Grain Kings - Yuri Kowalchuk" and q19_e1[2] == "Prairie Grain Kings" and q19_labels.call(q19f3)[1] == "True North Club" and q19_labels.call(q19g)[2] == "Carter Okafor's squad")
	# zero stats (NP_08 s7: "kept sacred from optimization"): the same dual stepped 1,200 ticks twice - on the wall as it came, and with three cards
	# moved, the letter rehung and three decorations more - hashes identically at every step, the fighters' stats and the ledger the same; the hash
	# does not move when the wall does (only a board sealed from its suggestion moves a fight)
	var q19_run := func(q19_s: TNBSim) -> Array:
		var q19_h: Array = []
		for q19_i in 1200:
			q19_s.step({})
			if q19_i % 60 == 0: q19_h.append(q19_s.hash_state())
		return q19_h
	var q19z0 := make_sim(1, 7); var q19z1 := make_sim(1, 7)
	var q19_hz: int = q19z1.hash_state()
	q19z1.pin("JUNE", 7, 3); q19z1.pin("RORY", 0, 2); q19z1.pin("MARCUS", 5, 1); q19z1.arrange("letter", 4.0, 5.0)
	for q19_k in ["poster", "stub", "graffiti"]: q19z1._gw_deco(q19_k, "a test %s" % q19_k)
	var q19_hz1: int = q19z1.hash_state()
	var q19_h0: Array = q19_run.call(q19z0); var q19_h1: Array = q19_run.call(q19z1)
	_sr("zero stats: a wall rearranged and decorated (%d decorations, the cards %s) leaves the hash where it was (%s) and the same 1,200 ticks hash identically (%d of %d), the stats and the ledger the same" % [q19z1.gym_wall["decos"].size(), JSON.stringify(q19_cells.call(q19z1)), str(q19_hz1 == q19_hz), q19_h1.size(), q19_h0.size()],
		q19_hz1 == q19_hz and q19_h0 == q19_h1 and q19_h0.size() == 20 and q19z0.P["stats"] == q19z1.P["stats"] and q19z0.B["stats"] == q19z1.B["stats"] and q19z0.rewards == q19z1.rewards and q19_cells.call(q19z0) != q19_cells.call(q19z1) and q19z1.gym_wall["decos"].size() == 4)
	# the save (NP_11 s9 SaveGame.gym_wall {layout, decorations}): the wall of the Okafor signings written - the cards on their cells, the lines,
	# the decorations with their places and days; a load hangs the same wall and the text written again is byte-equal; a save written before the
	# wall (no gym_wall) loads the club's cards in order and the bench after them
	q19g.arrange("letter", 6.0, 5.0)
	var q19_sv: Dictionary = TNBSave.to_save(q19g)
	var q19_txt: String = TNBSave.write_text(q19g, false)
	var q19gl = TNBSave.build(content, TNBSave.read_text(q19_txt), 5)["sim"]
	var q19_old: Dictionary = JSON.parse_string(q19_txt); q19_old.erase("gym_wall")
	var q19go = TNBSave.build(content, TNBSave.read(q19_old), 5)["sim"]
	_sr("the save: gym_wall %s - %d cards, %d lines, %d decorations (%s); a load hangs the same wall (%s) and the text written again %s; a save without the wall loads %s" % [JSON.stringify(q19_sv["gym_wall"].keys()), q19_sv["gym_wall"]["layout"]["cards"].size(), q19_sv["gym_wall"]["layout"]["lines"].size(), q19_sv["gym_wall"]["decorations"].size(), JSON.stringify(q19_sv["gym_wall"]["decorations"].map(func(d): return str(d["kind"]))), str(q19gl.gym_wall_view() == q19g.gym_wall_view()), "byte-equal" if TNBSave.write_text(q19gl, false) == q19_txt else "DIFFERENT", JSON.stringify(q19_cells.call(q19go))],
		q19_sv["gym_wall"].keys() == ["layout", "decorations"] and q19_sv["gym_wall"]["layout"]["cards"].size() == 6 and q19_sv["gym_wall"]["layout"]["lines"].size() >= 1 and q19gl.gym_wall_view() == q19g.gym_wall_view() \
		and TNBSave.write_text(q19gl, false) == q19_txt and q19_cells.call(q19gl)["ADA"] == [5, 1] and float(q19gl.gym_wall["decos"][0]["x"]) == 6.0 \
		and q19_cells.call(q19go) == {"RORY": [1, 0], "PRIYA": [2, 0], "MARCUS": [3, 0], "JUNE": [4, 0], "CARTER": [5, 0], "ADA": [6, 0]})

	# ---- PAC-080: THE DUO (NP_08 s5.2 Lv4, NP_05 s7) ----
	var q20_mk := func(q20_k: String, q20_board: Dictionary = {}) -> TNBSim:
		var q20_s := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_levels(TNBSim.parse_kizuna_arg(q20_k), "PRIYA:5", content["economy"]), q20_board); quiet(q20_s)   # since PAC-091 PRIYA at level 5: her Marginalia (a T0) is castable from there
		return q20_s
	var q20_next := func(q20_s: TNBSim) -> void:                 # the segment ended on EP, the corner sends the next fighter
		seg_end.call(q20_s, 4); next_segment(q20_s)
	var q20_feed := func(q20_s: TNBSim, q20_pre: String) -> String:
		for q20_e in q20_s.events:
			if str(q20_e["kind"]) == "feed" and str(q20_e["text"]).begins_with(q20_pre): return str(q20_e["text"])
		return ""
	var q20_arm := func(q20_s: TNBSim, q20_t: float, q20_row: String = "R_HOOKERCUT") -> String:
		# the fighter out at q20_t Tension presses LB + the row: the move armed, or "punch"
		freeze_boss(q20_s); thaw(q20_s); place(q20_s, 1.4); clear_defense(q20_s.B)
		q20_s.tension = q20_t; q20_s.P["busy_t"] = 0; q20_s.P["cmd"] = {}; q20_s.events.clear()
		q20_s.step({"punch": q20_row, "lb": true})
		return str(q20_s.cast["move"]["name"]) if q20_s.cast.size() > 0 else ("punch" if count_events(q20_s.events, "punch") + (1 if q20_s.P["pending"].size() > 0 else 0) > 0 else "nothing")
	# the data: the relay T3s carry their Duo variants (Coast to Coast five named pairs, Aurora Chain one), North Star none (the chain's move),
	# the festival duos their 2v2 input rule; Lv4 carries duo_t3; a pair's named T3 - its name, base, family, VFX and effect entries - for a
	# named pair, for two FROST cards unnamed (Aurora Chain's, named by the rule) and for a pair sharing nothing (Coast to Coast's)
	var q20_lib: Dictionary = content["library"]
	var q20a := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q20_dv := {}
	for q20_n in q20_lib:
		var q20_d = q20_lib[q20_n].get("duo_variant")
		if q20_d != null: q20_dv[str(q20_n)] = q20_d.get("pairs", {}).size() if q20_d is Dictionary else str(q20_d)
	var q20_rec := func(q20_a: String, q20_b: String) -> String:
		var q20_m: Dictionary = q20a.duo_move_for(q20_a, q20_b)
		if q20_m.is_empty(): return "none"
		return "%s / %s / %s %s / %s / %s" % [str(q20_m["name"]), str(q20_m["duo_of"]), str(q20_m["tier"]), str(q20_m["family"]), str(q20_m["vfx_set"]), "+".join(PackedStringArray(q20_m["effect"].map(func(e): return str(e["type"]) + (":" + str(e["params"]["name"]) if e["params"].has("name") else ""))))]
	var q20_r: Array = [q20_rec.call("RORY", "PRIYA"), q20_rec.call("RORY", "JUNE"), q20_rec.call("RORY", "SAM"), q20_rec.call("MARCUS", "SAM"), q20_rec.call("RORY", "RORY")]
	_sr("the Duo as data (NP_08 s5.2 Lv4, NP_05 s7): the variants %s; Lv%d carries it; the named T3s %s" % [JSON.stringify(q20_dv), q20a.duo_level(), JSON.stringify(q20_r)],
		q20_dv == {"Relay: Coast to Coast": 5, "Relay: Aurora Chain": 1, "Double Overtime": "sync_500ms", "Two-Hand Winter": "sync_500ms"} and q20a.duo_level() == 4 \
		and q20_r == ["Whiteout / Relay: Coast to Coast / T3 HAYMAKER / vfx_duo_any / DMG+DISPLACE+STATE:afterimage_partner", "Freeze-Up / Relay: Aurora Chain / T3 ARC / vfx_duo_frost / DMG+STATE:arena_freeze_vfx+STATE:afterimage_partner",
			"Aurora Chain - RORY & SAM / Relay: Aurora Chain / T3 ARC / vfx_duo_frost / DMG+STATE:arena_freeze_vfx+STATE:afterimage_partner", "Coast to Coast - MARCUS & SAM / Relay: Coast to Coast / T3 HAYMAKER / vfx_duo_any / DMG+DISPLACE+STATE:afterimage_partner", "none"])
	# the level and the relay: RORY and PRIYA at 89 (Adjacent Trust) - R2 PRIYA carries nothing; at 90 (Duo) Whiteout is live for her,
	# on the feed and in its event, R1 having had none (nobody before him); at 150 (Sworn) still; R3 MARCUS after PRIYA none. A swap sending
	# JUNE out after RORY (a Duo too) makes Freeze-Up hers; a board sending PRIYA first makes Whiteout RORY's (the pair's T3 either way);
	# RORY and MARCUS at 150 across PRIYA relay nothing
	var q20b89: TNBSim = q20_mk.call("RORY+PRIYA:89"); q20_next.call(q20b89)
	var q20b90: TNBSim = q20_mk.call("RORY+PRIYA:90"); var q20_r1: int = q20b90.duo.size(); q20_next.call(q20b90)
	var q20_d90: Dictionary = q20b90.duo.duplicate(); var q20_f90: String = q20_feed.call(q20b90, "DUO :: ")
	var q20_e90: Array = q20b90.events.filter(func(e): return str(e["kind"]) == "duo")
	var q20b150: TNBSim = q20_mk.call("RORY+PRIYA:150"); q20_next.call(q20b150)
	var q20b3: TNBSim = q20_mk.call("RORY+PRIYA:90"); q20_next.call(q20b3); q20_next.call(q20b3)
	var q20sw: TNBSim = q20_mk.call("RORY+PRIYA:90,RORY+JUNE:90"); seg_end.call(q20sw, 4); q20sw.corner_pick(0); var q20_swok: bool = q20sw.corner_action({"kind": "swap", "arg": "JUNE"}); q20sw.corner_pick(0)
	var q20rv: TNBSim = q20_mk.call("RORY+PRIYA:90", {"slots": ["PRIYA", "RORY", "MARCUS"]}); q20_next.call(q20rv)
	var q20na: TNBSim = q20_mk.call("RORY+MARCUS:150"); q20_next.call(q20na); var q20_na2: int = q20na.duo.size(); q20_next.call(q20na)
	_sr("the Duo's relay: at 89 R2 PRIYA %s; at 90 R1 %s, R2 %s (%s; %d event, '%s'); at 150 Lv%d %s; R3 MARCUS %s; JUNE swapped in after RORY (%s) %s; PRIYA sent first, R2 RORY %s from %s; RORY and MARCUS at 150 across PRIYA %d / %d" % [JSON.stringify(q20b89.duo), "none" if q20_r1 == 0 else "SOME", q20b90.pname(), str(q20_d90.get("move", {}).get("name", "")), q20_e90.size(), q20_f90, int(q20b150.duo.get("level", 0)), str(q20b150.duo_move().get("name", "")), JSON.stringify(q20b3.duo), str(q20_swok), str(q20sw.duo_move().get("name", "")), str(q20rv.duo_move().get("name", "")), str(q20rv.duo.get("partner", "")), q20_na2, q20na.duo.size()],
		q20b89.duo.is_empty() and q20b89.pname() == "PRIYA" and q20_r1 == 0 and q20b90.pname() == "PRIYA" and str(q20_d90.get("move", {}).get("name", "")) == "Whiteout" and str(q20_d90.get("partner", "")) == "RORY" and int(q20_d90.get("level", 0)) == 4 \
		and q20_e90.size() == 1 and str(q20_e90[0]["move"]) == "Whiteout" and str(q20_e90[0]["level_name"]) == "Duo" and q20_f90 == "DUO :: RORY -> PRIYA (Lv4 Duo): WHITEOUT is live - LB + HAYMAKER, a T3 at 45 Tension, RORY's afterimage joining (Relay: Coast to Coast)" and absf(float(q20_e90[0]["cost"]) - 45.0) < 0.001 \
		and int(q20b150.duo.get("level", 0)) == 5 and str(q20b150.duo_move().get("name", "")) == "Whiteout" and q20b3.pname() == "MARCUS" and q20b3.duo.is_empty() \
		and q20_swok and q20sw.pname() == "JUNE" and str(q20sw.duo_move().get("name", "")) == "Freeze-Up" and q20rv.pname() == "RORY" and str(q20rv.duo_move().get("name", "")) == "Whiteout" and str(q20rv.duo.get("partner", "")) == "PRIYA" \
		and q20_na2 == 0 and q20na.duo.is_empty() and q20na.pname() == "MARCUS")
	# the cast: LB + HAYMAKER at 60 arms Whiteout for PRIYA - a T3 with no CHARGED relay (the bond unlocks it), RORY's afterimage, the pair and its
	# VFX on the cast, 50 off the bar; at 89 the same press is a plain punch (her own Marginalia is PISTON). For RORY after PRIYA the motion is
	# his own Aurora Borealis Breaker's too: at 60 Whiteout answers it, at 40 his T1, at 20 a punch; CHARGED, the first cast at half: 30 is enough
	var q20_c90: String = q20_arm.call(q20b90, 60.0); var q20_cev: Dictionary = {}
	for q20_e in q20b90.events:
		if str(q20_e["kind"]) == "cast": q20_cev = q20_e
	var q20_left: float = q20b90.tension; var q20_t3u: bool = q20b90.t3_unlocked; var q20_arms: String = q20_feed.call(q20b90, "PRIYA ARMS")
	var q20_c89: String = q20_arm.call(q20b89, 60.0)
	var q20_prec: Array = []
	for q20_t in [60.0, 40.0, 20.0]:
		var q20_p: TNBSim = q20_mk.call("RORY+PRIYA:90", {"slots": ["PRIYA", "RORY", "MARCUS"]}); q20_next.call(q20_p)
		q20_prec.append(q20_arm.call(q20_p, q20_t))
	var q20ch: TNBSim = q20_mk.call("RORY+PRIYA:90"); q20_next.call(q20ch); q20ch.P["charge_t"] = TNBSim.ms(5000)
	var q20_cch: String = q20_arm.call(q20ch, 30.0)
	_sr("the Duo's cast: PRIYA at 60 arms %s (CHARGED %s, afterimage %s, pair %s, %s), %.0f left - '%s'; at 89 %s; RORY after PRIYA at 60 / 40 / 20: %s; CHARGED at 30 %s (%.1f left)" % [q20_c90, str(q20_t3u), str(q20_cev.get("afterimage", "")), str(q20_cev.get("duo", "")), str(q20_cev.get("vfx", "")), q20_left, q20_arms, q20_c89, JSON.stringify(q20_prec), q20_cch, q20ch.tension],
		q20_c90 == "Whiteout" and not q20_t3u and str(q20_cev.get("afterimage", "")) == "RORY" and str(q20_cev.get("duo", "")) == "PRIYA|RORY" and str(q20_cev.get("vfx", "")) == "vfx_duo_any" and str(q20_cev.get("tier", "")) == "T3" \
		and absf(q20_left - (60.0 - q20b90.hiss_cost(q20b90.duo_move()) - 0.0)) < 0.001 and q20_arms.begins_with("PRIYA ARMS WHITEOUT (T3 HAYMAKER, ") and q20_arms.ends_with(" - DUO: RORY's afterimage joins (Relay: Coast to Coast)") \
		and q20_c89 == "punch" and q20_prec == ["Whiteout", "Aurora Borealis Breaker", "punch"] and q20_cch == "Whiteout" and q20ch.tension < 30.0 and q20ch.tension > 0.0)
	# the effect: Whiteout resolved against the same Coast to Coast cast from a card that carries it (CHARGED, the same PRIYA, the same spot) -
	# the same damage and the same push to the ropes; the variant adds the partner's afterimage state (3 s) and its name and VFX, nothing else
	var q20_res := func(q20_s: TNBSim) -> Array:
		var q20_b0: float = float(q20_s.B["comp"])
		resolve_cast(q20_s)
		return [snappedf(q20_b0 - float(q20_s.B["comp"]), 0.0001), q20_s.B["pos"], q20_s.states["P"].has("afterimage_partner"), count_events(q20_s.events, "displace")]
	var q20x: TNBSim = q20_mk.call("RORY+PRIYA:90"); q20_next.call(q20x); var q20_xn: String = q20_arm.call(q20x, 100.0); var q20_xr: Array = q20_res.call(q20x)
	var q20_lb: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q20_lb[1]["hissatsu"] = "Relay: Coast to Coast"
	var q20y := make_sim(0, 7, q20_lb, "", {}, TNBSim.parse_kizuna_arg("RORY+PRIYA:89")); quiet(q20y); q20_next.call(q20y); q20y.t3_unlocked = true
	var q20_yn: String = q20_arm.call(q20y, 100.0); var q20_yr: Array = q20_res.call(q20y)
	_sr("the Duo's effect: %s %s against %s %s - the same damage and push, the afterimage state %s / %s" % [q20_xn, JSON.stringify([q20_xr[0], q20_xr[1]]), q20_yn, JSON.stringify([q20_yr[0], q20_yr[1]]), str(q20_xr[2]), str(q20_yr[2])],
		q20_xn == "Whiteout" and q20_yn == "Relay: Coast to Coast" and float(q20_xr[0]) > 0.0 and q20_xr[0] == q20_yr[0] and q20_xr[1] == q20_yr[1] and int(q20_xr[3]) == 1 and int(q20_yr[3]) == 1 and bool(q20_xr[2]) and not bool(q20_yr[2]))
	# the card plays it: delegated, PRIYA in R2 with the bar full casts Whiteout first (the profile takes a live Duo T3 while it can pay it);
	# at 89 she casts her own Marginalia; the whiteboard lists the Duo relays an order holds (the card order R1 RORY -> R2 PRIYA; sealed
	# Ambush, PRIYA first, R1 PRIYA -> R2 RORY); a DualState taken in R2 restores the live Duo on the same hash
	var q20_auto := func(q20_k: String) -> String:
		var q20_s: TNBSim = q20_mk.call(q20_k); q20_s.delegate_all = true; q20_next.call(q20_s)
		thaw(q20_s); place(q20_s, 1.5); q20_s.tension = 100.0; q20_s.events.clear()
		for q20_i in 1200:
			q20_s.step({})
			for q20_e in q20_s.events:
				if str(q20_e["kind"]) == "cast" and str(q20_e["who"]) == "P": return str(q20_e["move"])
			q20_s.events.clear()
		return "none"
	var q20_a90: String = q20_auto.call("RORY+PRIYA:90"); var q20_a89: String = q20_auto.call("RORY+PRIYA:89")
	var q20w: TNBSim = q20_mk.call("RORY+PRIYA:90")
	var q20_wl0: String = ""
	for q20_ln in q20w.formation_lines():
		if str(q20_ln).begins_with("DUO RELAYS: "): q20_wl0 = str(q20_ln)
	q20w.seal_board({"archetype": "AMBUSH"})
	var q20_wl1: String = ""
	for q20_ln in q20w.formation_lines():
		if str(q20_ln).begins_with("DUO RELAYS: "): q20_wl1 = str(q20_ln)
	var q20_snap: Dictionary = q20b150.snapshot(); var q20rs := make_sim(3, 99); var q20_rsok: Dictionary = q20rs.restore(q20_snap)
	_sr("the Duo delegated: PRIYA's first cast %s (at 89 %s); the whiteboard '%s', Ambush sealed %s '%s'; a DualState in R2 restores %s (%s) on the same hash (%s)" % [q20_a90, q20_a89, q20_wl0, JSON.stringify(q20w.sealed_p), q20_wl1, str(q20rs.duo_move().get("name", "")), str(q20_rsok.get("ok", false)), str(q20rs.hash_state() == q20b150.hash_state())],
		q20_a90 == "Whiteout" and q20_a89 == "Marginalia" and q20_wl0 == "DUO RELAYS: R1 RORY -> R2 PRIYA (Whiteout)" and q20w.sealed_p == ["PRIYA", "RORY", "MARCUS"] and q20_wl1 == "DUO RELAYS: R1 PRIYA -> R2 RORY (Whiteout)" \
		and bool(q20_rsok.get("ok", false)) and str(q20rs.duo_move().get("name", "")) == "Whiteout" and q20rs.hash_state() == q20b150.hash_state())

	# ---- PAC-081: THE RELAY'S OWN T3 (NP_05 s6-s7) ----
	var q21_charge := func(q21_s: TNBSim) -> void:              # the segment ends CHARGED (30 contributed, won on EP), the corner sends the next fighter
		q21_s.mode = "FIGHT"; q21_s.eight = {}; q21_s.contributed = 30.0; q21_s.ep_p += 4; q21_s._end_segment("smoke-forced"); next_segment(q21_s)
	var q21_names := func(q21_s: TNBSim) -> Array: return q21_s.relay_moves().map(func(m): return str(m["name"]))
	# the data and the opening: the library's relay sources (tactics' relay_t3_opens and full_relay_t3_opens); R2 PRIYA, out CHARGED, has Coast
	# to Coast and Aurora Chain opened - her card carries neither - on the feed and as an event with RORY's afterimage; not CHARGED, nothing;
	# the sanctioned chain: R3 at two links the same two, R4 at three (FULL RELAY) North Star too
	var q21_src := {}
	for q21_n in content["library"]:
		var q21_sc := str(content["library"][q21_n]["source"])
		if q21_sc in content["tactics"]["corner"]["relay_t3_opens"] or q21_sc in content["tactics"]["corner"]["full_relay_t3_opens"]:
			if not q21_src.has(q21_sc): q21_src[q21_sc] = []
			q21_src[q21_sc].append(str(q21_n))
	var q21a: TNBSim = q20_mk.call(""); q21_charge.call(q21a)
	var q21_ev: Array = q21a.events.filter(func(e): return str(e["kind"]) == "relay_open")
	var q21_fd: String = q20_feed.call(q21a, "RELAY :: ")
	var q21n: TNBSim = q20_mk.call(""); q20_next.call(q21n)
	var q21f := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); quiet(q21f)
	q21_charge.call(q21f); q21_charge.call(q21f); var q21_r3: Array = q21_names.call(q21f); var q21_c3: int = q21f.relay_chain
	q21_charge.call(q21f); var q21_r4: Array = q21_names.call(q21f)
	_sr("the relay's own T3 as data (NP_05 s6): the sources %s; R2 %s out CHARGED (card %s) opens %s (%d event, families %s, afterimage %s; '%s'); not CHARGED %s; sanctioned R3 at %d links %s, R4 %s at %d links (FULL RELAY %s) %s" % [JSON.stringify(q21_src), q21a.pname(), str(q21a.lineup[1]["hissatsu"]), JSON.stringify(q21_names.call(q21a)), q21_ev.size(), JSON.stringify(q21_ev[0]["families"]) if q21_ev.size() > 0 else "-", str(q21_ev[0]["afterimage"]) if q21_ev.size() > 0 else "-", q21_fd, JSON.stringify(q21_names.call(q21n)), q21_c3, JSON.stringify(q21_r3), q21f.pname(), q21f.relay_chain, str(q21f.full_relay), JSON.stringify(q21_r4)],
		q21_src == {"full_relay_exclusive": ["Relay: North Star"], "relay:charged": ["Relay: Coast to Coast", "Relay: Aurora Chain"]} and q21a.pname() == "PRIYA" and str(q21a.lineup[1]["hissatsu"]) == "Marginalia" \
		and q21_names.call(q21a) == ["Relay: Coast to Coast", "Relay: Aurora Chain"] and q21_ev.size() == 1 and q21_ev[0]["families"] == ["HAYMAKER", "ARC"] and str(q21_ev[0]["afterimage"]) == "RORY" \
		and q21_fd.begins_with("RELAY :: PRIYA opens Relay: Coast to Coast (LB + HAYMAKER, ") and q21_fd.ends_with(") - RORY's afterimage joins") and q21_fd.contains("Relay: Aurora Chain (LB + ARC, ") \
		and q21_names.call(q21n).is_empty() and count_events(q21n.events, "relay_open") == 0 and q21_c3 == 2 and q21_r3 == ["Relay: Coast to Coast", "Relay: Aurora Chain"] \
		and q21f.relay_chain == 3 and q21f.full_relay and q21_r4 == ["Relay: North Star", "Relay: Coast to Coast", "Relay: Aurora Chain"])
	# the motion: CHARGED PRIYA's LB + HAYMAKER casts Coast to Coast (RORY's afterimage), LB + ARC Aurora Chain, LB + PISTON her own Marginalia,
	# LB + RISE a punch (North Star waits for a FULL RELAY); not CHARGED, LB + HAYMAKER a punch. RORY out CHARGED after PRIYA, whose own
	# Aurora Borealis Breaker shares the haymaker: at 30 the T3 answers, at 20 his T1, at 10 a punch. On the FULL RELAY, R4 MARCUS's LB + RISE
	# casts North Star, and a fourth link puts 4.8 in it against 4.0 - its damage in that ratio
	var q21_one := func(q21_k: String, q21_board: Dictionary, q21_t: float, q21_row: String, q21_chg: bool = true) -> String:
		var q21_s: TNBSim = q20_mk.call(q21_k, q21_board)
		if q21_chg: q21_charge.call(q21_s)
		else: q20_next.call(q21_s)
		return q20_arm.call(q21_s, q21_t, q21_row)
	var q21_m: Array = []
	for q21_row in ["R_HOOKERCUT", "R_HOOK", "R_STRAIGHT", "R_UPPERCUT"]: q21_m.append(q21_one.call("", {}, 60.0, q21_row))
	var q21_nc: String = q21_one.call("", {}, 60.0, "R_HOOKERCUT", false)
	var q21_rv: Array = []
	for q21_t in [30.0, 20.0, 10.0]: q21_rv.append(q21_one.call("", {"slots": ["PRIYA", "RORY", "MARCUS"]}, q21_t, "R_HOOKERCUT"))
	var q21_gh: TNBSim = q20_mk.call(""); q21_charge.call(q21_gh); q20_arm.call(q21_gh, 60.0, "R_HOOKERCUT")
	var q21_ghost := ""
	for q21_e in q21_gh.events:
		if str(q21_e["kind"]) == "cast": q21_ghost = str(q21_e["afterimage"])
	var q21_ns := func(q21_links: int) -> Array:
		var q21_s := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); quiet(q21_s)
		for q21_i in 3: q21_charge.call(q21_s)
		q21_s.relay_chain = q21_links; q21_s.wall["B"] = {}                                              # his wall gauge set aside: the composure takes the packet (the gauge is C10's)
		var q21_nm: String = q20_arm.call(q21_s, 100.0, "R_UPPERCUT")
		var q21_b0: float = float(q21_s.B["comp"]); resolve_cast(q21_s)
		return [q21_nm, q21_b0 - float(q21_s.B["comp"]), q21_s.pname()]
	var q21_n3: Array = q21_ns.call(3); var q21_n4: Array = q21_ns.call(4)
	_sr("the relay's T3 by the motion: CHARGED PRIYA's HAYMAKER / ARC / PISTON / RISE at 60 %s (the afterimage %s); not CHARGED HAYMAKER %s; RORY CHARGED after PRIYA at 30 / 20 / 10 %s; FULL RELAY R4 %s's RISE %s, %.3f composure at 3 links, %.3f at 4 (x%.3f; his gauge set aside)" % [JSON.stringify(q21_m), q21_ghost, q21_nc, JSON.stringify(q21_rv), str(q21_n3[2]), str(q21_n3[0]), float(q21_n3[1]), float(q21_n4[1]), float(q21_n4[1]) / maxf(0.001, float(q21_n3[1]))],
		q21_m == ["Relay: Coast to Coast", "Relay: Aurora Chain", "Marginalia", "punch"] and q21_ghost == "RORY" and q21_nc == "punch" and q21_rv == ["Relay: Coast to Coast", "Aurora Borealis Breaker", "punch"] \
		and str(q21_n3[0]) == "Relay: North Star" and str(q21_n4[0]) == "Relay: North Star" and float(q21_n3[1]) > 0.0 and absf(float(q21_n4[1]) / float(q21_n3[1]) - 1.2) < 0.001)
	# the Duo over its base, and a stolen CHARGED: PRIYA out CHARGED at Duo with RORY - the relay opens Whiteout in Coast to Coast's place and
	# Aurora Chain beside it; Borrowed Blood's steal closes the relay (ARC a punch) and leaves the bond's Whiteout; stolen without a Duo, nothing
	var q21d: TNBSim = q20_mk.call("RORY+PRIYA:90"); q21_charge.call(q21d); var q21_dn: Array = q21_names.call(q21d)
	var q21_dh: String = q21_one.call("RORY+PRIYA:90", {}, 60.0, "R_HOOKERCUT"); var q21_da: String = q21_one.call("RORY+PRIYA:90", {}, 60.0, "R_HOOK")
	var q21_steal := func(q21_k: String, q21_row: String) -> Array:
		var q21_s: TNBSim = q20_mk.call(q21_k); q21_charge.call(q21_s)
		q21_s._fx_state("B", "steals_charged_state", 0.0)
		return [q21_s.t3_unlocked, q21_names.call(q21_s).size(), q20_arm.call(q21_s, 60.0, q21_row)]
	var q21_s1: Array = q21_steal.call("RORY+PRIYA:90", "R_HOOK"); var q21_s2: Array = q21_steal.call("RORY+PRIYA:90", "R_HOOKERCUT"); var q21_s3: Array = q21_steal.call("", "R_HOOKERCUT")
	_sr("the Duo over its base, and a stolen CHARGED: at Duo the relay opens %s, HAYMAKER %s, ARC %s; stolen (T3 unlocked %s, %d open) ARC %s, HAYMAKER %s; stolen without a Duo HAYMAKER %s" % [JSON.stringify(q21_dn), q21_dh, q21_da, str(q21_s1[0]), int(q21_s1[1]), str(q21_s1[2]), str(q21_s2[2]), str(q21_s3[2])],
		q21_dn == ["Whiteout", "Relay: Aurora Chain"] and q21_dh == "Whiteout" and q21_da == "Relay: Aurora Chain" and not bool(q21_s1[0]) and int(q21_s1[1]) == 0 and str(q21_s1[2]) == "punch" and str(q21_s2[2]) == "Whiteout" and str(q21_s3[2]) == "punch")
	# manager mode and on record: the profile's T3 - PRIYA (GALE) Coast to Coast (2.6 against Aurora Chain's 2.2), RORY (FROST) Aurora Chain (2.2 x
	# the element's 1.3), R4 MARCUS on the FULL RELAY North Star (4.0), at Duo Whiteout, not CHARGED none; delegated, PRIYA's first cast out
	# CHARGED is Coast to Coast; the whiteboard during the segment names what the relay opens; a DualState taken there restores it on the same hash
	var q21_pk := func(q21_s: TNBSim) -> String:
		q21_s.tension = 100.0
		return str(q21_s.t3_pick().get("name", "none"))
	var q21p1: TNBSim = q20_mk.call(""); q21_charge.call(q21p1)
	var q21p2: TNBSim = q20_mk.call("", {"slots": ["PRIYA", "RORY", "MARCUS"]}); q21_charge.call(q21p2)
	var q21p3 := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); quiet(q21p3)
	for q21_i in 3: q21_charge.call(q21p3)
	var q21p4: TNBSim = q20_mk.call("RORY+PRIYA:90"); q21_charge.call(q21p4)
	var q21p5: TNBSim = q20_mk.call(""); q20_next.call(q21p5)
	var q21_pks: Array = [q21_pk.call(q21p1), q21_pk.call(q21p2), q21_pk.call(q21p3), q21_pk.call(q21p4), q21_pk.call(q21p5)]
	var q21au: TNBSim = q20_mk.call(""); q21au.delegate_all = true; q21_charge.call(q21au)
	thaw(q21au); place(q21au, 1.5); q21au.tension = 100.0; q21au.events.clear()
	var q21_first := "none"
	for q21_i in 1200:
		q21au.step({})
		for q21_e in q21au.events:
			if str(q21_e["kind"]) == "cast" and str(q21_e["who"]) == "P" and q21_first == "none": q21_first = str(q21_e["move"])
		q21au.events.clear()
		if q21_first != "none": break
	var q21_wb := ""
	for q21_ln in q21p1.formation_lines():
		if str(q21_ln).begins_with("RELAY OPENS"): q21_wb = str(q21_ln)
	var q21_snap: Dictionary = q21p3.snapshot(); var q21rs := make_sim(5, 99); var q21_rok: Dictionary = q21rs.restore(q21_snap)
	_sr("the relay's T3 in manager mode and on record: the profile's picks %s; delegated, PRIYA's first cast %s; the whiteboard '%s'; a DualState on the FULL RELAY restores %s (%s) on the same hash (%s)" % [JSON.stringify(q21_pks), q21_first, q21_wb, JSON.stringify(q21_names.call(q21rs)), str(q21_rok.get("ok", false)), str(q21rs.hash_state() == q21p3.hash_state())],
		q21_pks == ["Relay: Coast to Coast", "Relay: Aurora Chain", "Relay: North Star", "Whiteout", "none"] and q21_first == "Relay: Coast to Coast" \
		and q21_wb.begins_with("RELAY OPENS (R2 PRIYA, chain 1): Relay: Coast to Coast (LB + HAYMAKER, ") and bool(q21_rok.get("ok", false)) and q21_names.call(q21rs) == ["Relay: North Star", "Relay: Coast to Coast", "Relay: Aurora Chain"] and q21rs.hash_state() == q21p3.hash_state())

	# ---- PAC-082: IN THE ZONE (NP_09 s1, s3) ----
	var q22_led := func(q22_lv: String, q22_flag: bool) -> Dictionary:
		var q22_l := TNBSim.seed_levels(TNBSim.parse_kizuna_arg(""), q22_lv, content["economy"])
		return TNBSim.seed_story(q22_l, "story:provincials_semifinal") if q22_flag else q22_l
	var q22_mk := func(q22_lv: String = "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", q22_flag: bool = true, q22_boss: int = 0, q22_fmt: String = "", q22_lu: Array = TNBSim.LINEUP_MILLBROOK) -> TNBSim:
		var q22_s := make_sim(q22_boss, 7, q22_lu, q22_fmt, {}, q22_led.call(q22_lv, q22_flag)); quiet(q22_s)
		return q22_s
	var q22_in := func(q22_s: TNBSim) -> void:                   # the SURGE, then the camera hold waited out
		q22_s.tension = 100.0; q22_s.step({"surge": true}); thaw(q22_s)
	# the data and the unlock: NP_09 s1's shared rules and s3's Zone as the table has them, the higher tiers named and not run (none since C39 runs Awakening), the table in
	# the content stamp; RORY at level 19 with the Provincials' flag, at 20 without it, at 20 with it: only the last unlocks the Zone
	var q22_td: Dictionary = content["transformations"]
	var q22_zone: Dictionary = q22_td["tiers"]["zone"]
	var q22_nr: Array = []
	for q22_k in q22_td["tiers"]:
		if not bool(q22_td["tiers"][q22_k]["executed"]): q22_nr.append(str(q22_td["tiers"][q22_k]["name"]))
	var q22a: TNBSim = q22_mk.call("RORY:19"); var q22b: TNBSim = q22_mk.call("RORY:20", false); var q22c: TNBSim = q22_mk.call("RORY:20")
	var q22_why: Array = [q22a.transform_why("RORY"), q22b.transform_why("RORY")]
	var q22_st0: int = q22c.content_stamp(); var q22_keep: Dictionary = q22c.TRANS; q22c.TRANS = q22_keep.duplicate(true); q22c.TRANS["shared"]["cost"] = 90
	var q22_st1: int = q22c.content_stamp(); q22c.TRANS = q22_keep
	_sr("the Zone as data (NP_09 s1, s3): %s - the whole bar %d (FULL RELAY %d), the cinematic %d ms, %d per fighter per dual, the Comedown %ds at %d%%; the Zone %ds, %s; unlocked at level %d + %s; named, not run %s; the stamp moves with it (%s); RORY at 19 '%s', at 20 without the flag '%s', at 20 with it %s" % [str(q22_td["schema"]), int(q22_td["shared"]["cost"]), int(content["tactics"]["corner"]["full_relay_t4_cost"]), int(q22_td["shared"]["cinematic_ms"]), int(q22_td["shared"]["per_fighter_per_dual"]), int(q22_td["shared"]["comedown"]["seconds"]), int(q22_td["shared"]["comedown"]["stat_pct"]), int(q22_zone["duration_s"]), JSON.stringify(q22_zone["effects"]), int(q22_zone["unlock"]["level"]), str(q22_zone["unlock"]["flag"]), JSON.stringify(q22_nr), str(q22_st1 != q22_st0), q22_why[0], q22_why[1], q22c.transform_tier("RORY")],
		str(q22_td["schema"]) == "Transformations/NP_09/v1.0" and int(q22_td["shared"]["cost"]) == 100 and int(q22_td["shared"]["cinematic_ms"]) == 2500 and int(q22_td["shared"]["comedown"]["seconds"]) == 10 and int(q22_td["shared"]["comedown"]["stat_pct"]) == 85 \
		and float(q22_zone["effects"]["time_scale"]) == 0.75 and int(q22_zone["effects"]["auto_slip_every_s"]) == 3 and bool(q22_zone["effects"]["stamina_frozen"]) and int(q22_zone["effects"]["counter_window_plus_ms"]) == 200 and int(q22_zone["effects"]["punch_speed_pct"]) == 15 and int(q22_zone["duration_s"]) == 20 and q22_nr == [] \
		and q22_st1 != q22_st0 and q22c.content_stamp() == q22_st0 and q22_why[0] == "RORY is level 19 - the Zone opens at 20" and q22_why[1] == "the Zone is taught at the Provincials semifinal (story:provincials_semifinal)" and q22c.transform_tier("RORY") == "zone" and q22c.transform_why("RORY") == "the bar is at 0 - a transformation takes the whole bar (100)")
	# the SURGE: at 99 refused; at 100 the whole bar goes and the camera hold begins - 300 ticks the world waits out (his timers do not move,
	# nothing interrupts it), the Zone's 20 s counted from its end; the FULL RELAY's price is 75 and the bar still empties (80 -> 0); a second
	# SURGE the same dual refused, after the Zone as well; a new dual gives it back; a spar never
	var q22d: TNBSim = q22_mk.call(); q22d.tension = 99.0; var q22_r99: Dictionary = q22d.transform()
	q22d.tension = 100.0; q22d.btimer = 5000; var q22_bt0: int = q22d.btimer; var q22_t0: int = q22d.tick
	var q22_rs: Dictionary = q22d.transform(); var q22_fz: int = q22d.freeze_t; var q22_zt: int = int(q22d.tform["t"]); var q22_bar: float = q22d.tension
	var q22_fd: String = ""
	for q22_e in q22d.events:
		if str(q22_e["kind"]) == "feed" and str(q22_e["text"]).begins_with("IN THE ZONE :: "): q22_fd = str(q22_e["text"])
	run_ticks(q22d, q22_fz, {"punch": "L_STRAIGHT"})
	var q22_hold: Array = [q22d.btimer == q22_bt0, int(q22d.tform["t"]) == q22_zt, q22d.freeze_t, int(q22d.tform["t0"]) == q22_t0 + q22_fz]
	var q22fr := make_sim(0, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, q22_led.call("RORY:20,JUNE:20,PRIYA:20,MARCUS:20,SAM:20", true)); quiet(q22fr)
	for q22_i in 3: q21_charge.call(q22fr)
	q22fr.tension = 80.0; var q22_rf: Dictionary = q22fr.transform(); var q22_fbar: float = q22fr.tension
	var q22_again: String = q22d.transform_why("RORY")
	run_ticks(q22d, TNBSim.ms(31000)); var q22_after: String = q22d.transform_why("RORY")
	q22d.new_dual(); quiet(q22d); var q22_nd: String = q22d.transform_why("RORY")
	var q22sp: TNBSim = q22_mk.call(); q22sp.start_spar(0); q22sp.tension = 100.0; var q22_spw: String = q22sp.transform_why(q22sp.pname())
	_sr("the SURGE: at 99 '%s'; at 100 %s, the bar %.0f, the camera hold %d ticks - his timers %s, the Zone's clock %s, the Zone from tick %s (%s); '%s'; the FULL RELAY %s for %.0f, the bar %.0f; again '%s'; after the Zone '%s'; a new dual '%s'; a spar '%s'" % [str(q22_r99["why"]), str(q22_rs["ok"]), q22_bar, q22_fz, "held" if q22_hold[0] else "MOVED", "held" if q22_hold[1] else "MOVED", str(q22_hold[3]), "the hold done" if int(q22_hold[2]) == 0 else "STILL", q22_fd, str(q22_rf.get("ok", false)), float(q22_rf.get("cost", 0)), q22_fbar, q22_again, q22_after, q22_nd, q22_spw],
		not bool(q22_r99["ok"]) and str(q22_r99["why"]) == "the bar is at 99 - a transformation takes the whole bar (100)" and bool(q22_rs["ok"]) and q22_bar == 0.0 and q22_fz == TNBSim.ms(2500) and bool(q22_hold[0]) and bool(q22_hold[1]) and int(q22_hold[2]) == 0 and bool(q22_hold[3]) \
		and q22_fd.begins_with("IN THE ZONE :: RORY - the whole bar (100 of 100); 20s: the world at x0.75, the first punch every 3s slipped, stamina frozen at ") \
		and bool(q22_rf.get("ok", false)) and float(q22_rf.get("cost", 0)) == 75.0 and q22_fbar == 0.0 and q22fr.full_relay \
		and q22_again == "RORY is already in the Zone" and q22_after == "RORY has transformed this dual (NP_09 s1: one per fighter per dual)" and q22_nd == "the bar is at 0 - a transformation takes the whole bar (100)" and q22_spw == "no transformation in a spar")
	# the effects, each against the same sim without the Zone: his timers at x0.75 (300 of 400 ticks); the first punch of each 3 s slipped
	# (the second in the window lands; 3 s on, slipped again); stamina frozen through punches and rest; every counter window +200 ms; a punch's
	# startup and recovery / 1.15
	var q22_pair := func() -> Array:
		var q22_z: TNBSim = q22_mk.call(); q22_in.call(q22_z)
		var q22_c: TNBSim = q22_mk.call(); q22_c.tension = 100.0
		return [q22_z, q22_c]
	var q22_p1: Array = q22_pair.call()
	var q22_bts: Array = []
	for q22_s in q22_p1:
		q22_s.bstate = "IDLE"; q22_s.btimer = 100000; var q22_b0: int = q22_s.btimer
		run_ticks(q22_s, 400); q22_bts.append(q22_b0 - q22_s.btimer)
	var q22_p2: Array = q22_pair.call()
	var q22_sl: Array = []
	for q22_s in q22_p2:
		place(q22_s); var q22_seq: Array = []
		for q22_i in 3:
			q22_s.events.clear(); var q22_c0: float = float(q22_s.P["comp"])
			clear_defense(q22_s.P); boss_lands(q22_s, "R_HOOK")
			q22_seq.append("slip" if count_events(q22_s.events, "evade", {"why": "ZONE_SLIP"}) > 0 else ("hit" if float(q22_s.P["comp"]) < q22_c0 else "?"))
			if q22_i == 1: run_ticks(q22_s, TNBSim.ms(3000))
		q22_sl.append(q22_seq)
	var q22_z3: TNBSim = q22_mk.call(); q22_z3.P["stamina"] = 60.0; q22_in.call(q22_z3)              # at 60 (the SURGE's own tick rests it to 60.04), where rest would lift it: frozen means neither way
	var q22_c3: TNBSim = q22_mk.call(); q22_c3.P["stamina"] = 60.0; q22_c3.tension = 100.0
	var q22_sm: Array = []
	for q22_s in [q22_z3, q22_c3]:
		var q22_s0: float = float(q22_s.P["stamina"])
		for q22_i in 4: throw_clean(q22_s, "R_HOOKERCUT", {"power": true})
		var q22_s1: float = float(q22_s.P["stamina"]); run_ticks(q22_s, 240)
		q22_sm.append([snappedf(q22_s0, 0.01), snappedf(q22_s1, 0.01), snappedf(float(q22_s.P["stamina"]), 0.01)])
	var q22_p4: Array = q22_pair.call()
	var q22_wn: Array = [q22_p4[0]._window("slip") - q22_p4[1]._window("slip"), q22_p4[0]._window("perfect_block") - q22_p4[1]._window("perfect_block")]
	var q22_sp: Array = []
	for q22_s in q22_p4:
		thaw(q22_s); q22_s.P["busy_t"] = 0; q22_s.P["cmd"] = {}; q22_s.step({"punch": "R_STRAIGHT"})
		q22_sp.append([int(q22_s.P["pending"].get("startup", 0)), int(q22_s.P["busy_t"])])
	var q22_rowd: Dictionary = content["tuning"]["punch_matrix"]["R_STRAIGHT"]; var q22_pm: float = float(q22_p4[1].P["pkg"].get("startup_mult", 1.0))
	_sr("the Zone's effects against the same sim without it: his timers %d / %d ticks of 400; the punches %s; stamina %s; counter windows +%d / +%d ticks; R_STRAIGHT startup / busy %s" % [int(q22_bts[0]), int(q22_bts[1]), JSON.stringify(q22_sl), JSON.stringify(q22_sm), int(q22_wn[0]), int(q22_wn[1]), JSON.stringify(q22_sp)],
		int(q22_bts[0]) == 300 and int(q22_bts[1]) == 400 and q22_sl[0] == ["slip", "hit", "slip"] and q22_sl[1] == ["hit", "hit", "hit"] \
		and absf(float(q22_sm[0][0]) - 60.0) < 0.1 and float(q22_sm[0][1]) == float(q22_sm[0][0]) and float(q22_sm[0][2]) == float(q22_sm[0][0]) and float(q22_sm[1][1]) < float(q22_sm[1][0]) and float(q22_sm[1][2]) > float(q22_sm[1][1]) \
		and int(q22_wn[0]) == TNBSim.ms(200) and int(q22_wn[1]) == TNBSim.ms(200) \
		and int(q22_sp[0][0]) == TNBSim.ms(float(q22_rowd["startup_ms"]) * 1.0 * q22_pm * (1.0 / 1.15)) and int(q22_sp[1][0]) == TNBSim.ms(float(q22_rowd["startup_ms"]) * 1.0 * q22_pm) and int(q22_sp[0][1]) < int(q22_sp[1][1]))
	# the end and the Comedown: 20 s of fight time after the hold, the Zone ends into the Comedown - every stat at 85 %, stamina moving again -
	# and 10 s later he is back to himself; the events in that order; a segment that ends mid-Zone ends it (the next fighter comes out fresh)
	var q22e: TNBSim = q22_mk.call(); q22_in.call(q22e); q22e.events.clear()
	var q22_pwr0: float = float(q22e.P["stats"]["PWR"])
	run_ticks(q22e, TNBSim.ms(20000) - 1); var q22_still: bool = q22e.tform.size() > 0
	run_ticks(q22e, 1); var q22_cd: bool = q22e.comedown.size() > 0 and q22e.tform.is_empty(); var q22_pwr1: float = float(q22e.P["stats"]["PWR"])
	var q22_line: String = q22e.zone_line()
	var q22_se0: float = float(q22e.P["stamina"]); throw_clean(q22e, "R_HOOKERCUT", {"power": true}); var q22_se1: float = float(q22e.P["stamina"])
	run_ticks(q22e, TNBSim.ms(10000)); var q22_pwr2: float = float(q22e.P["stats"]["PWR"])
	var q22_ord: Array = q22e.events.filter(func(e): return str(e["kind"]) in ["zone_end", "comedown_end"]).map(func(e): return str(e["kind"]))
	var q22g: TNBSim = q22_mk.call(); q22_in.call(q22g); seg_end.call(q22g, 4); next_segment(q22g)
	_sr("the end: at 19.99 s in the Zone %s; at 20 s the Comedown (%s): PWR %.1f -> %.2f, '%s', stamina %.2f -> %.2f; 10 s on PWR %.1f; the events %s; a segment ended mid-Zone: R2 %s, Zone %s, Comedown %s" % [str(q22_still), str(q22_cd), q22_pwr0, q22_pwr1, q22_line, q22_se0, q22_se1, q22_pwr2, JSON.stringify(q22_ord), q22g.pname(), JSON.stringify(q22g.tform), JSON.stringify(q22g.comedown)],
		q22_still and q22_cd and absf(q22_pwr1 - q22_pwr0 * 0.85) < 0.001 and q22_line.begins_with("COMEDOWN 10.0s (85%)") and q22_se1 < q22_se0 and q22_pwr2 == q22_pwr0 and q22_ord == ["zone_end", "comedown_end"] \
		and q22g.pname() == "PRIYA" and q22g.tform.is_empty() and q22g.comedown.is_empty())
	# the manager and the record: a delegated fighter with the Zone unlocked and a full bar never surges on his own (1,200 ticks), and the
	# manager's SURGE passes through delegation; the HUD's Zone line; a DualState mid-Zone restores it on the same hash, the one-per-dual record
	# with it; RORY's Zone used, PRIYA's in R2 still hers
	var q22h: TNBSim = q22_mk.call(); q22h.delegate_all = true; q22h.new_dual(); quiet(q22h); q22h.tension = 100.0
	run_ticks(q22h, 1200); var q22_self: int = count_events(q22h.events, "zone"); q22h.tension = 100.0; q22h.cast = {}; q22h.step({"surge": true})
	var q22_pass: bool = q22h.tform.size() > 0
	var q22i: TNBSim = q22_mk.call(); q22_in.call(q22i); run_ticks(q22i, 500); var q22_zl: String = q22i.zone_line()
	var q22_h0: int = q22i.hash_state(); var q22_sn: Dictionary = q22i.snapshot(); var q22j := make_sim(4, 99); var q22_ro: Dictionary = q22j.restore(q22_sn)
	seg_end.call(q22i, 4); next_segment(q22i); q22i.tension = 100.0; var q22_r2: String = q22i.transform_why(q22i.pname())
	_sr("the Zone and the manager, on record: delegated with a full bar %d SURGEs of his own, the manager's passes through (%s); the HUD '%s'; a DualState mid-Zone restores (%s) %s on the same hash (%s), the record %s; R2 %s '%s'" % [q22_self, str(q22_pass), q22_zl, str(q22_ro.get("ok", false)), q22j.zone_line(), str(q22j.hash_state() == q22_h0), JSON.stringify(q22j.transformed), q22i.pname(), q22_r2],
		q22_self == 0 and q22_pass and q22_zl.begins_with("IN THE ZONE 15.8s | stamina frozen ") and bool(q22_ro.get("ok", false)) and q22j.zone_line() == q22_zl and q22j.hash_state() == q22_h0 and q22j.transformed == {"RORY": "zone"} \
		and q22i.pname() == "PRIYA" and q22_r2 == "")
	# ---- PAC-083: SPIRIT MANIFESTATION (NP_09 s4) ----
	var q23_led := func(q23_lv: String, q23_fl: String) -> Dictionary:
		return TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(""), q23_lv, content["economy"]), q23_fl)
	var q23_lug: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true)                  # a generic stablemate out first: RORY's card as GENERIC, a Gale fighter
	q23_lug[0]["name"] = "GENERIC"; q23_lug[0]["generic"] = true; q23_lug[0]["element"] = "GALE"
	var q23_mk := func(q23_lv: String = "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", q23_fl: String = "story:provincials_semifinal,story:manifest:RORY", q23_lu: Array = TNBSim.LINEUP_MILLBROOK) -> TNBSim:
		var q23_s := make_sim(0, 7, q23_lu, "", {}, q23_led.call(q23_lv, q23_fl)); quiet(q23_s); q23_s.wall["B"] = {}
		return q23_s
	var q23_in := func(q23_s: TNBSim) -> void:                   # the SURGE, then the camera hold waited out
		q23_s.tension = 100.0; q23_s.step({"surge": true}); thaw(q23_s)
	var q23_feed := func(q23_s: TNBSim, q23_pre: String) -> String:
		var q23_f := ""
		for q23_e in q23_s.events:
			if str(q23_e["kind"]) == "feed" and str(q23_e["text"]).begins_with(q23_pre): q23_f = str(q23_e["text"])
		return q23_f
	# the data and the unlock: NP_09 s4's Manifest as the table has it (30 s; x1.4, the 50-point meter, the echo at 0.3 s for 30 %, displacement
	# x2; the shared Comedown; the Clash named - run since PAC-086, C40), the higher tiers named and not run (none since C39), an element-generic manifest per element; the unlock
	# by the card - a named character by his own Arc 2 flag alone, a generic stablemate by level 35 and his Zone mastery flag, never the other's
	var q23_td: Dictionary = content["transformations"]; var q23_m: Dictionary = q23_td["tiers"]["manifest"]
	var q23_nr: Array = []
	for q23_k in q23_td["tiers"]:
		if not bool(q23_td["tiers"][q23_k]["executed"]): q23_nr.append(str(q23_td["tiers"][q23_k]["name"]))
	var q23_gm: Array = []
	for q23_el in ["FROST", "GALE", "GRANITE", "TIMBER"]: q23_gm.append(str(q23_m["manifests"]["generic"][q23_el]["name"]))
	var q23_u: Array = [q23_mk.call("RORY:20", "story:provincials_semifinal").transform_tier("RORY"), q23_mk.call().transform_tier("RORY"),
		q23_mk.call("RORY:1", "story:manifest:RORY").transform_tier("RORY"), q23_mk.call("RORY:35", "story:provincials_semifinal,mastery:zone:RORY").transform_tier("RORY"),
		q23_mk.call("GENERIC:35", "story:provincials_semifinal,mastery:zone:GENERIC", q23_lug).transform_tier("GENERIC"), q23_mk.call("GENERIC:34", "story:provincials_semifinal,mastery:zone:GENERIC", q23_lug).transform_tier("GENERIC"),
		q23_mk.call("GENERIC:35", "story:provincials_semifinal", q23_lug).transform_tier("GENERIC"), q23_mk.call("GENERIC:35", "story:provincials_semifinal,story:manifest:GENERIC", q23_lug).transform_tier("GENERIC")]
	var q23_mo: Array = [q23_mk.call().manifest_of("RORY"), q23_mk.call("GENERIC:35", "mastery:zone:GENERIC", q23_lug).manifest_of("GENERIC")]
	_sr("the Manifest as data (NP_09 s4): tier %d, %ds, %s; the Comedown the shared one (%s); unlocked %s / %s; the Clash executed %s (%ds at x%.1f); named, not run %s; generic manifests %s; the tier chosen - RORY with the Zone only %s, with his Arc 2 flag %s, with the flag alone at level 1 %s, at 35 with a Zone mastery flag %s; GENERIC at 35 + mastery %s, at 34 %s, without mastery %s, with a named flag %s; the figures %s / %s" % ([int(q23_m["tier"]), int(q23_m["duration_s"]), JSON.stringify(q23_m["effects"]), JSON.stringify(q23_m["comedown"].keys()), JSON.stringify(q23_m["unlock"]["named"]), JSON.stringify(q23_m["unlock"]["generic"]), str(q23_m["clash"]["executed"]), int(q23_m["clash"]["seconds"]), float(q23_m["clash"]["time_scale"]), JSON.stringify(q23_nr), JSON.stringify(q23_gm)] + q23_u + [str(q23_mo[0]["name"]), str(q23_mo[1]["name"])]),
		bool(q23_m["executed"]) and int(q23_m["tier"]) == 3 and int(q23_m["duration_s"]) == 30 and float(q23_m["effects"]["damage_mult"]) == 1.4 and int(q23_m["effects"]["manifest_meter"]) == 50 and float(q23_m["effects"]["echo_delay_s"]) == 0.3 and int(q23_m["effects"]["echo_pct"]) == 30 and float(q23_m["effects"]["displace_mult"]) == 2.0 \
		and not q23_m["comedown"].has("seconds") and not q23_m["comedown"].has("stat_pct") and str(q23_m["unlock"]["named"]["flag"]) == "story:manifest:{name}" and int(q23_m["unlock"]["generic"]["level"]) == 35 and str(q23_m["unlock"]["generic"]["flag"]) == "mastery:zone:{name}" \
		and bool(q23_m["clash"]["executed"]) and int(q23_m["clash"]["seconds"]) == 5 and float(q23_m["clash"]["time_scale"]) == 0.5 and q23_nr == [] and q23_gm == ["the Frost manifest", "the Gale manifest", "the Granite manifest", "the Timber manifest"] \
		and q23_u == ["zone", "manifest", "manifest", "zone", "manifest", "zone", "zone", "zone"] and str(q23_mo[0]["name"]) == "RORY's manifest" and not bool(q23_mo[0]["generic"]) and str(q23_mo[1]["name"]) == "the Gale manifest" and bool(q23_mo[1]["generic"]))
	# the SURGE casts the highest tier unlocked: the whole bar, the same 2.5 s hold, 30 s of the Manifest with its own 50-point meter; one
	# transformation per fighter per dual whatever the tier (the Zone refused after the Manifest); a new dual gives it back
	var q23d: TNBSim = q23_mk.call(); q23d.tension = 100.0
	var q23_rs: Dictionary = q23d.transform(); var q23_fd: String = q23_feed.call(q23d, "SPIRIT MANIFESTATION :: ")
	var q23_s0: Array = [q23d.tension, str(q23d.tform.get("tier", "")), float(q23d.tform.get("meter", 0.0)), int(q23d.tform.get("t", 0)), q23d.freeze_t, JSON.stringify(q23d.transformed)]
	thaw(q23d); var q23_again: String = q23d.transform_why("RORY")
	run_ticks(q23d, TNBSim.ms(41000)); var q23_after: String = q23d.transform_why("RORY"); var q23_tt: String = q23d.transform_tier("RORY")
	q23d.new_dual(); quiet(q23d); var q23_nd: String = q23d.transform_why("RORY")
	_sr("the SURGE with the Manifest unlocked: %s - the bar %.0f, %s, meter %.0f, %d ticks, the hold %d, the record %s; '%s'; again '%s'; after it (his tier still %s, the Zone unlocked beneath it) '%s'; a new dual '%s'" % [str(q23_rs.get("tier", "")), float(q23_s0[0]), str(q23_s0[1]), float(q23_s0[2]), int(q23_s0[3]), int(q23_s0[4]), str(q23_s0[5]), q23_fd, q23_again, q23_tt, q23_after, q23_nd],
		bool(q23_rs["ok"]) and str(q23_rs["tier"]) == "manifest" and float(q23_s0[0]) == 0.0 and str(q23_s0[1]) == "manifest" and float(q23_s0[2]) == 50.0 and int(q23_s0[3]) == TNBSim.ms(30000) and int(q23_s0[4]) == TNBSim.ms(2500) and str(q23_s0[5]) == "{\"RORY\":\"manifest\"}" \
		and q23_fd == "SPIRIT MANIFESTATION :: RORY - the whole bar (100 of 100); 30s: RORY's manifest - all damage x1.40, hissatsu from its own 50-point meter, every clean punch echoed at 0.3s for +30%, displacement x2" \
		and q23_again == "RORY is already manifested" and q23_tt == "manifest" and q23_after == "RORY has transformed this dual (NP_09 s1: one per fighter per dual)" and q23_nd == "the bar is at 0 - a transformation takes the whole bar (100)")
	# the effects, each against the same sim without the Manifest: a clean punch x1.4 and its echo 0.3 s of fight time later (not at 0.29) for
	# 30 % of it - none without; a blocked punch no echo; a drop cancels one in flight; the hissatsu's damage x1.4 and its DISPLACE metres x2,
	# with no echo (a hissatsu is not a punch)
	var q23_pair := func() -> Array:
		var q23_z: TNBSim = q23_mk.call(); q23_in.call(q23_z)
		var q23_c: TNBSim = q23_mk.call(); q23_c.tension = 100.0
		return [q23_z, q23_c]
	var q23_p1: Array = q23_pair.call(); var q23_pd: Array = []
	for q23_s in q23_p1:
		place(q23_s); q23_s.events.clear()
		throw_clean(q23_s, "R_STRAIGHT"); var q23_h: float = hit_dmg(q23_s, "B")
		thaw(q23_s); q23_s.events.clear(); run_ticks(q23_s, TNBSim.ms(300) - 1); var q23_early: int = count_events(q23_s.events, "echo")
		var q23_bc: float = float(q23_s.B["comp"]); run_ticks(q23_s, 1)
		var q23_ed: float = 0.0
		for q23_e in q23_s.events:
			if str(q23_e["kind"]) == "echo": q23_ed += float(q23_e["dmg"])
		q23_pd.append([snappedf(q23_h, 0.0001), q23_early, count_events(q23_s.events, "echo"), snappedf(q23_ed, 0.0001), q23_bc > float(q23_s.B["comp"])])
	var q23z: TNBSim = q23_p1[0]; thaw(q23z); q23z.P["busy_t"] = 0; q23z.P["cmd"] = {}; q23z.events.clear()
	q23z.step({"punch": "R_STRAIGHT"}); clear_defense(q23z.B); q23z.B["blocking"] = true; q23z.B["guard_t"] = TNBSim.ms(2000); land(q23z); q23z.B["guard_t"] = 0
	var q23_blk: int = count_events(q23z.events, "block"); var q23_bq: int = q23z.tform["echoes"].size()
	q23z.B["blocking"] = false; throw_clean(q23z, "R_STRAIGHT"); var q23_fl: int = q23z.tform["echoes"].size(); q23z._drop(true); var q23_dr: int = q23z.tform["echoes"].size()
	var q23_p2: Array = q23_pair.call(); var q23_hs: Array = []
	for q23_s in q23_p2:
		place(q23_s, 1.4); q23_s.tension = 40.0; var q23_m0: float = q23_s.purse()
		var q23_ok: bool = cast_player(q23_s); resolve_cast(q23_s)
		var q23_dp: float = 0.0
		for q23_e in q23_s.events:
			if str(q23_e["kind"]) == "displace": q23_dp = float(q23_e["m"])
		run_ticks(q23_s, TNBSim.ms(400))
		q23_hs.append([q23_ok, snappedf(hit_dmg(q23_s, "B"), 0.0001), snappedf(q23_dp, 0.0001), snappedf(q23_m0 - q23_s.purse(), 0.01), snappedf(q23_s.tension, 0.01), count_events(q23_s.events, "echo")])
	_sr("the Manifest's effects against the same sim without it: R_STRAIGHT %s (hit, echoes by 0.29 s, at 0.3 s, the echo, his composure down); blocked %d, echoes queued %d; one in flight %d, after a drop %d; the hissatsu %s (cast, damage, DISPLACE m, paid, the team bar, echoes)" % [JSON.stringify(q23_pd), q23_blk, q23_bq, q23_fl, q23_dr, JSON.stringify(q23_hs)],
		absf(float(q23_pd[0][0]) - 1.4 * float(q23_pd[1][0])) < 0.001 and float(q23_pd[1][0]) > 0.0 and int(q23_pd[0][1]) == 0 and int(q23_pd[0][2]) == 1 and absf(float(q23_pd[0][3]) - 0.3 * float(q23_pd[0][0])) < 0.001 and bool(q23_pd[0][4]) and int(q23_pd[1][2]) == 0 \
		and q23_blk == 1 and q23_bq == 0 and q23_fl == 1 and q23_dr == 0 \
		and bool(q23_hs[0][0]) and bool(q23_hs[1][0]) and float(q23_hs[1][1]) > 0.0 and absf(float(q23_hs[0][1]) - 1.4 * float(q23_hs[1][1])) < 0.001 and float(q23_hs[1][2]) > 0.0 and absf(float(q23_hs[0][2]) - 2.0 * float(q23_hs[1][2])) < 0.0001 and int(q23_hs[0][5]) == 0)
	# the private meter against the team bar: the Manifest's cast paid from the meter (50 -> 50 - the price), the team bar at 40 untouched and SAVE
	# THE BAR not holding it; the control's from the team bar; with the meter short of the price the motion throws its punch though the team bar
	# holds 100; a cast broken in the window gives the half back to the meter; when the Manifest ends its meter goes with it
	var q23_mc: Array = []
	for q23_s in q23_p2: q23_mc.append(float(q23_s.hiss_cost(q23_s.player_move())))
	var q23f: TNBSim = q23_mk.call(); q23_in.call(q23f); place(q23f, 1.4); q23f.tension = 100.0; q23f.save_bar = true
	var q23_c1: bool = cast_player(q23f); var q23_arm: String = q23_feed.call(q23f, "RORY ARMS"); resolve_cast(q23f); thaw(q23f)
	var q23_f1: Array = [snappedf(float(q23f.tform["meter"]), 0.01), q23f.tension]
	q23f.P["busy_t"] = 0; q23f.P["cmd"] = {}; var q23_c2: bool = cast_player(q23f); var q23_pn: int = count_events(q23f.events, "punch")
	var q23g: TNBSim = q23_mk.call(); q23g.tension = 100.0; q23g.save_bar = true; place(q23g, 1.4); var q23_c3: bool = cast_player(q23g)
	var q23k: TNBSim = q23_mk.call(); q23_in.call(q23k); place(q23k, 1.4); q23k.tension = 20.0; cast_player(q23k)
	var q23_k0: float = float(q23k.tform["meter"]); var q23_ib: bool = q23k._interrupt_cast("B"); var q23_k1: float = float(q23k.tform["meter"]); var q23_kt: float = q23k.tension
	run_ticks(q23k, TNBSim.ms(31000)); var q23_gone: Array = [q23k.tform.has("meter"), q23k.purse() == q23k.tension]
	_sr("the manifest meter against the team bar: the price %.1f; with the team bar at 100 and held the Manifest casts %s ('%s') -> meter, bar %s; the meter short: cast %s, the punch thrown %d; the control held %s; broken in the window %s: the meter %.2f -> %.2f; after it %s" % [q23_mc[0], str(q23_c1), q23_arm, JSON.stringify(q23_f1), str(q23_c2), q23_pn, str(q23_c3), str(q23_ib), q23_k0, q23_k1, JSON.stringify(q23_gone)],
		absf(float(q23_hs[0][3]) - q23_mc[0]) < 0.01 and float(q23_hs[0][4]) == 40.0 and absf(float(q23_hs[1][3]) - q23_mc[1]) < 0.01 and absf(float(q23_hs[1][4]) - (40.0 - q23_mc[1])) < 0.01 \
		and q23_c1 and q23_arm.contains("from the manifest's meter, %d left" % int(50.0 - q23_mc[0])) and absf(float(q23_f1[0]) - (50.0 - q23_mc[0])) < 0.01 and float(q23_f1[1]) == 100.0 \
		and not q23_c2 and q23_pn == 1 and not q23_c3 and q23_ib and absf(q23_k1 - (q23_k0 + 0.5 * q23_mc[0])) < 0.01 and q23_kt == 20.0 and not bool(q23_gone[0]) and bool(q23_gone[1]))
	# the end and the Comedown: the HUD's MANIFEST line; 30 s of fight time after the hold the Manifest ends into NP_09 s1's Comedown - every
	# stat at 85 % - and 10 s later he is himself; the events in that order; the manager: a delegated fighter never SURGEs on his own, the
	# manager's SURGE manifests him and the card spends the meter; a DualState with an echo in flight restores on the same hash and the echo
	# lands the same in both
	var q23e: TNBSim = q23_mk.call(); q23_in.call(q23e); q23e.events.clear()
	var q23_pw0: float = float(q23e.P["stats"]["PWR"]); var q23_zl: String = q23e.zone_line()
	run_ticks(q23e, TNBSim.ms(30000) - 1); var q23_still: bool = q23e.tform.size() > 0
	run_ticks(q23e, 1); var q23_cd: bool = q23e.comedown.size() > 0 and q23e.tform.is_empty(); var q23_pw1: float = float(q23e.P["stats"]["PWR"])
	var q23_endf: String = q23_feed.call(q23e, "THE MANIFEST ENDS"); var q23_cl: String = q23e.zone_line()
	run_ticks(q23e, TNBSim.ms(10000)); var q23_pw2: float = float(q23e.P["stats"]["PWR"])
	var q23_ord: Array = q23e.events.filter(func(e): return str(e["kind"]) in ["zone_end", "comedown_end"]).map(func(e): return str(e["kind"]) + ((" " + str(e["tier"])) if e.has("tier") else ""))
	var q23h: TNBSim = q23_mk.call(); q23h.delegate_all = true; q23h.new_dual(); quiet(q23h); q23h.wall["B"] = {}; q23h.tension = 100.0
	run_ticks(q23h, 1200); var q23_self: int = count_events(q23h.events, "zone"); q23h.tension = 100.0; q23h.cast = {}; q23h.step({"surge": true})
	var q23_pass: String = str(q23h.tform.get("tier", "")); q23h.events.clear(); run_ticks(q23h, 1800)
	var q23_mcast: int = q23h.events.filter(func(e): return str(e["kind"]) == "feed" and str(e["text"]).contains("from the manifest's meter")).size()
	var q23i: TNBSim = q23_mk.call(); q23_in.call(q23i); place(q23i); throw_clean(q23i, "R_STRAIGHT"); thaw(q23i)
	var q23_fly: int = q23i.tform["echoes"].size(); var q23_h0: int = q23i.hash_state(); var q23_sn: Dictionary = q23i.snapshot()
	var q23j := make_sim(4, 99); var q23_ro: Dictionary = q23j.restore(q23_sn); var q23_rh: bool = q23j.hash_state() == q23_h0
	q23i.events.clear(); q23j.events.clear(); run_ticks(q23i, 60); run_ticks(q23j, 60)
	_sr("the end, the manager, the record: '%s'; at 29.99 s %s, at 30 s the Comedown %s (PWR %.1f -> %.2f, '%s', '%s'), 10 s on PWR %.1f, %s; delegated %d SURGEs of his own, the manager's -> %s, the card's casts from the meter %d; a DualState with %d echo in flight restores %s on the same hash %s, the echo lands %d / %d, hashes %s" % [q23_zl, str(q23_still), str(q23_cd), q23_pw0, q23_pw1, q23_endf, q23_cl, q23_pw2, JSON.stringify(q23_ord), q23_self, q23_pass, q23_mcast, q23_fly, str(q23_ro.get("ok", false)), str(q23_rh), count_events(q23i.events, "echo"), count_events(q23j.events, "echo"), str(q23i.hash_state() == q23j.hash_state())],
		q23_zl == "MANIFEST 30.0s | RORY's manifest | meter 50/50 | echo +30% at 0.3s | damage x1.4" and q23_still and q23_cd and absf(q23_pw1 - q23_pw0 * 0.85) < 0.001 and q23_endf == "THE MANIFEST ENDS - RORY's manifest leaves him (50 of its meter unspent); 10s at 85%" and q23_cl.begins_with("COMEDOWN 10.0s (85%)") \
		and q23_pw2 == q23_pw0 and q23_ord == ["zone_end manifest", "comedown_end"] and q23_self == 0 and q23_pass == "manifest" and q23_mcast >= 1 \
		and q23_fly == 1 and bool(q23_ro.get("ok", false)) and q23_rh and count_events(q23i.events, "echo") == 1 and count_events(q23j.events, "echo") == 1 and q23i.hash_state() == q23j.hash_state())
	# ---- PAC-084: INHERITANCE (NP_09 s5) ----
	var q24_led := func(q24_kz: String, q24_lv: String, q24_fl: String) -> Dictionary:
		return TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(q24_kz), q24_lv, content["economy"]), q24_fl)
	var q24_mk := func(q24_kz: String = "RORY+SAM:150", q24_lv: String = "", q24_fl: String = "", q24_lu: Array = TNBSim.LINEUP_MILLBROOK_8, q24_fmt: String = "sanctioned", q24_boss: int = 0) -> TNBSim:
		var q24_s := make_sim(q24_boss, 7, q24_lu, q24_fmt, {}, q24_led.call(q24_kz, q24_lv, q24_fl)); quiet(q24_s); q24_s.wall["B"] = {}
		return q24_s
	var q24_in := func(q24_s: TNBSim) -> void:                   # the SURGE, then the camera hold waited out
		q24_s.tension = 100.0; q24_s.step({"surge": true}); thaw(q24_s)
	var q24_srcs := func(q24_s: TNBSim, q24_n: String) -> Array:
		return q24_s.inherit_sources(q24_n).map(func(x): return "%s:%s:%s" % [str(x["kind"]), str(x["source"]), str(x["house"])])
	var q24_lus: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true); q24_lus[5]["house"] = "tagaq"              # DEX as a Tagaq: SAM's own house
	var q24_lur: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true); q24_lur[5]["house"] = "reyes"              # DEX as a Reyes (no Reyes stablemate exists): a stat trait's source
	var q24_lu8d: Array = TNBSim.LINEUP_MILLBROOK_8.duplicate(true); q24_lu8d[7]["house2"] = "okafor"          # MARTA marked dual-house (NP_04: "dual-house character"; her second house is the gate's pick)
	var q24_lud: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q24_lud[0] = q24_lu8d[7].duplicate(true); q24_lud[0].erase("reserve")   # MARTA out first in a mini dual
	var q24_legacy := func(q24_s: TNBSim) -> void:                # the content lane's slot filled for the gate: the departed coach, House Whitecloud
		q24_s.TRANS = q24_s.TRANS.duplicate(true); q24_s.TRANS["tiers"]["inheritance"]["legacy_sources"]["departed_coach"]["house"] = "whitecloud"; q24_s.TRANS["tiers"]["inheritance"]["legacy_sources"]["departed_coach"]["name"] = "THE OLD COACH"
	# the data and the sources: NP_09 s5's Inheritance as the table has it (25 s; the trait, the natives from a 50-point meter, the dialect worn;
	# the Comedown's scrambled dialect 10 s; the second house at 75; the order legacy, Sworn, second house; the departed coach's slot empty),
	# Sworn as the economy's Lv5, Awakening alone named and not run (none since C39); who he can inherit from - at Duo nobody, at Sworn SAM, the deepest bond
	# first, never a houseless card or his own house, a legacy only when its house is written and its flag set, a dual-house card's second house
	var q24_td: Dictionary = content["transformations"]; var q24_t: Dictionary = q24_td["tiers"]["inheritance"]
	var q24_nr: Array = []
	for q24_k in q24_td["tiers"]:
		if not bool(q24_td["tiers"][q24_k]["executed"]): q24_nr.append(str(q24_td["tiers"][q24_k]["name"]))
	var q24a: TNBSim = q24_mk.call("RORY+SAM:149"); var q24b: TNBSim = q24_mk.call(); var q24c: TNBSim = q24_mk.call("RORY+SAM:150,RORY+YURI:200,RORY+JUNE:300")
	var q24d: TNBSim = q24_mk.call("SAM+DEX:150", "", "", q24_lus)
	var q24e: TNBSim = q24_mk.call("RORY+SAM:150", "", "legacy:departed_coach"); var q24_e0: Array = q24_srcs.call(q24e, "RORY"); q24_legacy.call(q24e)
	var q24f: TNBSim = q24_mk.call("", "", "", q24_lud, ""); var q24g: TNBSim = q24_mk.call("MARTA+SAM:150", "", "", q24_lu8d)
	var q24_u: Array = [q24_srcs.call(q24a, "RORY"), q24a.transform_tier("RORY"), q24_srcs.call(q24b, "RORY"), q24b.transform_tier("RORY"), q24_srcs.call(q24c, "RORY"), q24_srcs.call(q24d, "SAM"), q24_srcs.call(q24d, "DEX"),
		q24_e0, q24_srcs.call(q24e, "RORY"), q24_srcs.call(q24f, "MARTA"), q24f.transform_cost("MARTA"), q24b.transform_cost("RORY"), q24_srcs.call(q24g, "MARTA")]
	_sr("Inheritance as data (NP_09 s5): tier %d, %ds, %s; the Comedown %s; unlocked %s; the second house at %d, the order %s; the departed coach's house %s; Sworn the economy's Lv%d; named, not run %s; the sources - at 149 %s (%s), at 150 %s (%s), three bonds %s, a Tagaq with a Tagaq %s / %s, the legacy's flag set with no house %s and with one %s, a dual-house MARTA %s at %s (RORY %s), with SAM Sworn too %s" % ([int(q24_t["tier"]), int(q24_t["duration_s"]), JSON.stringify(q24_t["effects"]), JSON.stringify(q24_t["comedown"].keys()), JSON.stringify(q24_t["unlock"]["inherit"]), int(q24_t["unlock"]["second_house_cost"]), JSON.stringify(q24_t["unlock"]["source_order"]), str(q24_t["legacy_sources"]["departed_coach"]["house"]), q24b.inherit_level(), JSON.stringify(q24_nr)] + q24_u.map(func(x): return JSON.stringify(x) if x is Array else str(x))),
		bool(q24_t["executed"]) and int(q24_t["tier"]) == 4 and int(q24_t["duration_s"]) == 25 and bool(q24_t["effects"]["inherit_trait"]) and int(q24_t["effects"]["private_meter"]) == 50 and str(q24_t["effects"]["meter_pays"]) == "inherited" and bool(q24_t["effects"]["misread"]) and bool(q24_t["effects"]["own_stats"]) \
		and int(q24_t["comedown"]["dialect_scrambled_s"]) == 10 and not q24_t["comedown"].has("seconds") and int(q24_t["unlock"]["second_house_cost"]) == 75 and q24_t["unlock"]["source_order"] == ["legacy", "sworn", "second_house"] and q24_t["legacy_sources"]["departed_coach"]["house"] == null \
		and q24b.inherit_level() == 5 and bool(content["economy"]["kizuna"]["effects"]["5"]["inheritance"]) and q24_nr == [] \
		and q24_u[0] == [] and str(q24_u[1]) == "" and q24_u[2] == ["sworn:SAM:tagaq"] and str(q24_u[3]) == "inheritance" and q24_u[4] == ["sworn:YURI:kowalchuk", "sworn:SAM:tagaq"] and q24_u[5] == [] and q24_u[6] == [] \
		and q24_u[7] == ["sworn:SAM:tagaq"] and q24_u[8] == ["legacy:THE OLD COACH:whitecloud", "sworn:SAM:tagaq"] and q24_u[9] == ["second_house:MARTA:okafor"] and float(q24_u[10]) == 75.0 and float(q24_u[11]) == 100.0 and q24_u[12] == ["sworn:SAM:tagaq", "second_house:MARTA:okafor"])
	# the SURGE: Inheritance over the Manifest over the Zone - the whole bar, the same hold, SAM's Never Twice beside RORY's none, SAM's natives (the
	# move he carries first), a 50-point meter; the dual-house MARTA at 74 refused and at 80 for 75 (the bar still empties); the legacy's gift in
	# older footage (no one at the apron); once per dual
	var q24h: TNBSim = q24_mk.call("RORY+SAM:150", "RORY:20", "story:provincials_semifinal,story:manifest:RORY"); q24h.tension = 100.0
	var q24_ht: String = q24h.transform_tier("RORY"); var q24_rs: Dictionary = q24h.transform(); var q24_fd: String = q23_feed.call(q24h, "INHERITANCE :: ")
	var q24_zev: Dictionary = {}
	for q24_ev in q24h.events:
		if str(q24_ev["kind"]) == "zone": q24_zev = q24_ev
	var q24_s0: Array = [q24h.tension, float(q24h.tform.get("meter", 0.0)), str(q24h.tform.get("meter_pays", "")), str(q24h.P.get("trait_inh", {}).get("id", "")), q24h.P["trait"].size(), q24h.freeze_t, JSON.stringify(q24h.transformed)]
	thaw(q24h); var q24_again: String = q24h.transform_why("RORY")
	var q24m: TNBSim = q24_mk.call("", "", "", q24_lud, ""); q24m.tension = 74.0; var q24_r74: Dictionary = q24m.transform(); q24m.tension = 80.0; var q24_r80: Dictionary = q24m.transform()
	var q24_md: Array = [q24m.tension, str(q24m.tform.get("inherit", {}).get("kind", "")), JSON.stringify(q24m.tform.get("inherit", {}).get("natives", [])), q24m._tx(q24m.P, "first_frost"), q24m._tx(q24m.P, "harvest")]
	var q24_mfd: String = q23_feed.call(q24m, "INHERITANCE :: ")
	var q24l: TNBSim = q24_mk.call("RORY+SAM:150", "", "legacy:departed_coach"); q24_legacy.call(q24l); q24l.tension = 100.0; q24l.transform()
	var q24_li: Dictionary = q24l.tform.get("inherit", {})
	_sr("the SURGE with a source: %s over the Manifest and the Zone -> %s; the bar %.0f, meter %.0f paying '%s', the trait %s (his own %d), the hold %d, the record %s; the event %s from %s (%s, %s, dressed %s); '%s'; again '%s'; MARTA's second house at 74 '%s', at 80 %s for %.0f -> %s; '%s'; the legacy %s %s %s (%s), dressed %s" % [q24_ht, str(q24_rs.get("tier", "")), float(q24_s0[0]), float(q24_s0[1]), str(q24_s0[2]), str(q24_s0[3]), int(q24_s0[4]), int(q24_s0[5]), str(q24_s0[6]), str(q24_zev.get("house", "")), str(q24_zev.get("source", "")), str(q24_zev.get("trait", "")), JSON.stringify(q24_zev.get("natives", [])), str(q24_zev.get("dressed", "")), q24_fd, q24_again, str(q24_r74.get("why", "")), str(q24_r80.get("ok", false)), float(q24_r80.get("cost", 0)), JSON.stringify(q24_md), q24_mfd, str(q24_li.get("kind", "")), str(q24_li.get("source", "")), str(q24_li.get("house", "")), JSON.stringify(q24_li.get("natives", [])), str(q24_li.get("dressed", ""))],
		q24_ht == "inheritance" and bool(q24_rs["ok"]) and float(q24_s0[0]) == 0.0 and float(q24_s0[1]) == 50.0 and str(q24_s0[2]) == "inherited" and str(q24_s0[3]) == "never_twice" and int(q24_s0[4]) == 0 and int(q24_s0[5]) == TNBSim.ms(2500) and str(q24_s0[6]) == "{\"RORY\":\"inheritance\"}" \
		and str(q24_zev.get("source", "")) == "SAM" and str(q24_zev.get("house", "")) == "tagaq" and str(q24_zev.get("trait", "")) == "Never Twice" and q24_zev.get("natives", []) == ["Sorry Eh", "Still Water"] and bool(q24_zev.get("dressed", false)) \
		and q24_fd == "INHERITANCE :: RORY - the whole bar (100 of 100); 25s: House Tagaq from SAM (Sworn) - the trait Never Twice, the natives Sorry Eh / Still Water from a 50-point meter, the Tagaq dialect worn (the enemy misreads RORY); RORY's own stats" \
		and q24_again == "RORY is already inheriting" and str(q24_r74.get("why", "")) == "the bar is at 74 - a transformation takes the whole bar (75)" and bool(q24_r80.get("ok", false)) and float(q24_r80.get("cost", 0)) == 75.0 \
		and float(q24_md[0]) == 0.0 and str(q24_md[1]) == "second_house" and str(q24_md[2]) == "[\"Pressure Cooker\",\"Heat Advisory\"]" and int(q24_md[3]) == 1 and int(q24_md[4]) == 1 and q24_mfd.begins_with("INHERITANCE :: MARTA - the whole bar (75 of 80); 25s: House Okafor - MARTA's second house - the trait Harvest, the natives Pressure Cooker / Heat Advisory from a 50-point meter") \
		and str(q24_li.get("kind", "")) == "legacy" and str(q24_li.get("source", "")) == "THE OLD COACH" and str(q24_li.get("house", "")) == "whitecloud" and q24_li.get("natives", []) == ["Long Winter", "First Light"] and not bool(q24_li.get("dressed", true)))
	# the effects, each against the same sim without the Inheritance: SAM's Never Twice turns RORY's second drop into a wobble; LB + ARC casts
	# SAM's Sorry Eh from the meter (50 -> 18.5) with the team bar at 40 untouched - nothing without; RORY's own Aurora still pays the team bar;
	# MARTA's Premiere Neige on the WALL motion from the meter; a Reyes source's Debt of Honour against Yuri's Kowalchuk (E11) scales RORY's
	# stats while he wears it and gives them back; over 24 straights every read he makes is a misread - no dodge - where the control dodges
	var q24_pair := func(q24_kz: String = "RORY+SAM:150", q24_lu: Array = TNBSim.LINEUP_MILLBROOK_8, q24_boss: int = 0) -> Array:
		var q24_z: TNBSim = q24_mk.call(q24_kz, "", "", q24_lu, "sanctioned", q24_boss); q24_in.call(q24_z)
		var q24_c: TNBSim = q24_mk.call(q24_kz, "", "", q24_lu, "sanctioned", q24_boss); q24_c.tension = 100.0
		return [q24_z, q24_c]
	var q24_p1: Array = q24_pair.call(); var q24_nt: Array = []
	for q24_s in q24_p1:
		q24_s.P["drops"] = 1; q24_s.events.clear(); q24_s._drop(true); q24_nt.append([q24_s.mode, int(q24_s.P["drops"]), count_events(q24_s.events, "trait", {"trait": "never_twice"})])
	var q24_p2: Array = q24_pair.call(); var q24_cs: Array = []
	for q24_s in q24_p2:
		place(q24_s, 1.4); q24_s.tension = 40.0; var q24_m0: float = float(q24_s.tform.get("meter", 0.0))
		thaw(q24_s); q24_s.P["busy_t"] = 0; q24_s.P["cmd"] = {}; q24_s.events.clear(); q24_s.step({"punch": "R_HOOK", "lb": true})
		var q24_cm: String = str(q24_s.cast.get("move", {}).get("name", "")) + ("<-" + str(q24_s.cast["move"]["inherited_from"]) if q24_s.cast.get("move", {}).has("inherited_from") else "")
		var q24_arm: String = q23_feed.call(q24_s, "RORY ARMS")
		resolve_cast(q24_s); thaw(q24_s); var q24_after1: Array = [snappedf(float(q24_s.tform.get("meter", 0.0)), 0.01), q24_s.tension]
		q24_s.P["busy_t"] = 0; q24_s.P["cmd"] = {}; q24_s.step({"punch": "R_HOOKERCUT", "lb": true}); var q24_cm2: String = str(q24_s.cast.get("move", {}).get("name", ""))
		resolve_cast(q24_s); thaw(q24_s)
		q24_cs.append([q24_cm, q24_arm, q24_m0, q24_after1, q24_cm2, snappedf(float(q24_s.tform.get("meter", 0.0)), 0.01), snappedf(q24_s.tension, 0.01)])
	var q24w: TNBSim = q24_mk.call("RORY+MARTA:150"); q24_in.call(q24w); place(q24w, 1.4); q24w.P["busy_t"] = 0; q24w.events.clear()
	run_ticks(q24w, TNBSim.ms(400) + 1, {"lb": true, "block": true})
	var q24_wc: String = str(q24w.cast.get("move", {}).get("name", "")); var q24_wm: float = float(q24w.tform.get("meter", 0.0)); var q24_wp: float = q24w.hiss_cost(q24w.library["Premiere Neige"])
	var q24_p4: Array = q24_pair.call("RORY+DEX:150", q24_lur, 1); var q24_ds: Array = []
	for q24_s in q24_p4: q24_ds.append(float(q24_s.P["stats"]["PWR"]))
	run_ticks(q24_p4[0], TNBSim.ms(25000)); var q24_dsd: float = float(q24_p4[0].P["stats"]["PWR"]); var q24_dsn: float = float(q24_p4[0].comedown.get("stats", {}).get("PWR", 0.0))
	var q24_dmx: float = float(content["houses"]["traits"]["debt_of_honour"]["stats_mult"])
	var q24_p5: Array = q24_pair.call(); var q24_rd: Array = []
	for q24_s in q24_p5:
		place(q24_s); var q24_tally := {"misread": 0, "dodge": 0, "guard": 0, "none": 0}
		for q24_i in 24:
			thaw(q24_s); q24_s.B["comp"] = q24_s.B["comp_max"]; q24_s.P["busy_t"] = 0; q24_s.P["cmd"] = {}
			q24_s.step({"punch": "R_STRAIGHT"})
			var q24_r: String = str(q24_s.P.get("pending", {}).get("read", "none"))
			q24_tally[q24_r] = int(q24_tally.get(q24_r, 0)) + 1
			land(q24_s); run_ticks(q24_s, 30)
		q24_rd.append([q24_tally, count_events(q24_s.events, "misread")])
	_sr("Inheritance's effects against the same sim without it: a second drop %s; LB + ARC %s ('%s'; meter %.0f -> %s), then LB + HAYMAKER %s -> meter %.2f, bar %.2f; the WALL motion %s from the meter (%.1f left, the price %.1f); PWR %.1f against %.1f (Debt of Honour x%.2f), at its end %.2f (the Comedown's %.1f kept); reads over 24 straights %s" % [JSON.stringify(q24_nt), JSON.stringify([q24_cs[0][0], q24_cs[1][0]]), str(q24_cs[0][1]), float(q24_cs[0][2]), JSON.stringify(q24_cs[0][3]), str(q24_cs[0][4]), float(q24_cs[0][5]), float(q24_cs[0][6]), q24_wc, q24_wm, q24_wp, float(q24_ds[0]), float(q24_ds[1]), q24_dmx, q24_dsd, q24_dsn, JSON.stringify(q24_rd)],
		str(q24_nt[0][0]) == "FIGHT" and int(q24_nt[0][1]) == 1 and int(q24_nt[0][2]) == 1 and str(q24_nt[1][0]) == "EIGHT" and int(q24_nt[1][2]) == 0 \
		and str(q24_cs[0][0]) == "Sorry Eh<-SAM" and str(q24_cs[0][1]).contains("from the inherited meter, 18 left") and float(q24_cs[0][2]) == 50.0 and float(q24_cs[0][3][0]) == 18.5 and float(q24_cs[0][3][1]) == 40.0 \
		and str(q24_cs[0][4]) == "Aurora Borealis Breaker" and float(q24_cs[0][5]) == 18.5 and float(q24_cs[0][6]) == 8.5 and str(q24_cs[1][0]) == "" \
		and q24_wc == "Premiere Neige" and absf(q24_wm - (50.0 - q24_wp)) < 0.01 \
		and absf(float(q24_ds[0]) - minf(99.0, float(q24_ds[1]) * q24_dmx)) < 0.01 and float(q24_ds[0]) > float(q24_ds[1]) and absf(q24_dsn - float(q24_ds[1])) < 0.01 and absf(q24_dsd - float(q24_ds[1]) * 0.85) < 0.01 \
		and int(q24_rd[0][0]["misread"]) >= 1 and int(q24_rd[0][0]["dodge"]) == 0 and int(q24_rd[0][1]) == int(q24_rd[0][0]["misread"]) and int(q24_rd[1][0]["dodge"]) >= 1 and int(q24_rd[1][0]["misread"]) == 0)
	# the end and the Comedown: the HUD's INHERITANCE line; 25 s of fight time after the hold SAM's style leaves - no trait of his, every stat at
	# 85 %, his own dialect scrambled 10 s: a feint he sells draws nothing (a Zone's Comedown sells it); 10 s on he is himself and the feint draws
	var q24e2: TNBSim = q24_mk.call(); q24_in.call(q24e2); q24e2.events.clear(); var q24_pw0: float = float(q24e2.P["stats"]["PWR"]); var q24_zl: String = q24e2.zone_line()
	run_ticks(q24e2, TNBSim.ms(25000) - 1); var q24_still: bool = q24e2.tform.size() > 0 and q24e2._tx(q24e2.P, "never_twice") == 1
	run_ticks(q24e2, 1); var q24_cd: Array = [q24e2.tform.is_empty(), q24e2.comedown.size() > 0, q24e2._tx(q24e2.P, "never_twice"), snappedf(float(q24e2.P["stats"]["PWR"]), 0.01), int(q24e2.comedown.get("scramble_t", 0))]
	var q24_endf: String = q23_feed.call(q24e2, "THE INHERITANCE ENDS"); var q24_cl: String = q24e2.zone_line(); var q24_ze: int = count_events(q24e2.events, "zone_end", {"tier": "inheritance", "scramble_s": 10.0})
	var q24_f1: bool = forced_feint.call(q24e2, "R_HOOK"); var q24_fs: int = count_events(q24e2.events, "feint", {"scrambled": true})
	var q24z: TNBSim = q24_mk.call("", "RORY:20", "story:provincials_semifinal"); q24_in.call(q24z); run_ticks(q24z, TNBSim.ms(20000))
	var q24_zc: bool = q24z.comedown.size() > 0; var q24_f2: bool = forced_feint.call(q24z, "R_HOOK")
	run_ticks(q24e2, TNBSim.ms(10000)); var q24_back: Array = [q24e2.comedown.is_empty(), float(q24e2.P["stats"]["PWR"]) == q24_pw0, count_events(q24e2.events, "comedown_end")]; var q24_f3: bool = forced_feint.call(q24e2, "L_HOOK")
	_sr("the end: '%s'; at 24.99 s %s; at 25 s %s ('%s', '%s'); a feint in his Comedown drawn %s (%d scrambled), in a Zone's Comedown (%s) %s; 10 s on %s, the feint %s; zone_end %d" % [q24_zl, str(q24_still), JSON.stringify(q24_cd), q24_endf, q24_cl, str(q24_f1), q24_fs, str(q24_zc), str(q24_f2), JSON.stringify(q24_back), str(q24_f3), q24_ze],
		q24_zl == "INHERITANCE 25.0s | House Tagaq from SAM (Sworn) | Never Twice | meter 50/50 | Sorry Eh, Still Water | the enemy misreads you" and q24_still \
		and bool(q24_cd[0]) and bool(q24_cd[1]) and int(q24_cd[2]) == 0 and absf(float(q24_cd[3]) - q24_pw0 * 0.85) < 0.01 and int(q24_cd[4]) == TNBSim.ms(10000) \
		and q24_endf == "THE INHERITANCE ENDS - SAM's House Tagaq style leaves RORY (50 of the meter unspent); 10s at 85%, RORY's own dialect scrambled 10s" and q24_cl == "COMEDOWN 10.0s (85%) | own dialect scrambled 10.0s" \
		and not q24_f1 and q24_fs == 1 and q24_zc and q24_f2 and bool(q24_back[0]) and bool(q24_back[1]) and int(q24_back[2]) == 1 and q24_f3 and q24_ze == 1)
	# the manager and the record: delegated with a source and a full bar he never SURGEs on his own; the manager's SURGE makes him inherit and the
	# card casts SAM's natives from the meter; a DualState mid-Inheritance restores the source's trait, the meter and the record on the same
	# hash and the two run on to the same hash; R2 JUNE comes out with none of it
	var q24k: TNBSim = q24_mk.call(); q24k.delegate_all = true; q24k.new_dual(); quiet(q24k); q24k.wall["B"] = {}; q24k.tension = 100.0
	run_ticks(q24k, 1200); var q24_self: int = count_events(q24k.events, "zone"); q24k.tension = 100.0; q24k.cast = {}; q24k.step({"surge": true})
	var q24_pass: String = str(q24k.tform.get("tier", "")); q24k.events.clear(); run_ticks(q24k, 1800)
	var q24_mcast: int = q24k.events.filter(func(e): return str(e["kind"]) == "feed" and str(e["text"]).contains("from the inherited meter")).size()
	var q24i: TNBSim = q24_mk.call(); q24_in.call(q24i); run_ticks(q24i, 600)
	var q24_h0: int = q24i.hash_state(); var q24_sn: Dictionary = q24i.snapshot(); var q24j := make_sim(4, 99); var q24_ro: Dictionary = q24j.restore(q24_sn)
	var q24_rh: bool = q24j.hash_state() == q24_h0; var q24_rt: String = str(q24j.P.get("trait_inh", {}).get("id", "")); var q24_rl: String = q24j.zone_line()
	run_ticks(q24i, TNBSim.ms(25000)); run_ticks(q24j, TNBSim.ms(25000)); var q24_same: bool = q24i.hash_state() == q24j.hash_state() and q24i.comedown.size() > 0
	var q24n: TNBSim = q24_mk.call(); q24_in.call(q24n); seg_end.call(q24n, 4); next_segment(q24n)
	_sr("Inheritance and the manager, on record: delegated %d SURGEs of his own, the manager's -> %s, the card's casts from the inherited meter %d; a DualState mid-Inheritance restores %s on the same hash %s (the trait %s, '%s'), both %s at its end; R2 %s: %s, trait %s" % [q24_self, q24_pass, q24_mcast, str(q24_ro.get("ok", false)), str(q24_rh), q24_rt, q24_rl, "the same" if q24_same else "APART", q24n.pname(), JSON.stringify(q24n.tform), JSON.stringify(q24n.P.get("trait_inh", {}))],
		q24_self == 0 and q24_pass == "inheritance" and q24_mcast >= 1 and bool(q24_ro.get("ok", false)) and q24_rh and q24_rt == "never_twice" and q24_rl.begins_with("INHERITANCE 20.0s | House Tagaq from SAM (Sworn)") and q24_same \
		and q24n.pname() == "JUNE" and q24n.tform.is_empty() and q24n.P.get("trait_inh", {}).is_empty())
	# ---- PAC-085: AWAKENING (NP_09 s6) ----
	var q25_led := func(q25_kz: String, q25_lv: String, q25_f: String) -> Dictionary:
		return TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(q25_kz), q25_lv, content["economy"]), q25_f)
	var q25_mk := func(q25_f: String = "story:provincials_semifinal,secret:RORY,story:trial:RORY,story:sealed_house_resolved", q25_form: String = "", q25_kz: String = "", q25_lu: Array = TNBSim.LINEUP_MILLBROOK, q25_fmt: String = "", q25_lv: String = "RORY:20,PRIYA:20,MARCUS:20,JUNE:20,SAM:20,MARTA:20") -> TNBSim:
		var q25_l: Array = q25_lu.duplicate(true)
		if q25_form != "": q25_l[0]["awakening_form"] = q25_form
		var q25_s := make_sim(0, 7, q25_l, q25_fmt, {}, q25_led.call(q25_kz, q25_lv, q25_f)); quiet(q25_s); q25_s.wall["B"] = {}
		return q25_s
	var q25_in := func(q25_s: TNBSim) -> void:                   # the SURGE, then the camera hold waited out
		q25_s.tension = 100.0; q25_s.step({"surge": true}); thaw(q25_s)
	var q25_fl := "story:provincials_semifinal,secret:RORY,story:trial:RORY,story:sealed_house_resolved"
	var q25_mfl := q25_fl + ",story:manifest:RORY"
	# the data and the gate: NP_09 s6's Awakening as the table has it (40 s; a prior tier at 75 %, the caps x1.75, a drop +15, the hybrid slot;
	# the stacking rules), every tier now run; the gate per character - his house's SECRET learned and his Arc 3 trial, the protagonist's sealed
	# house as well, and a prior tier to stack; the tier it stacks - his choice when he has it, else his highest prior tier
	var q25_td: Dictionary = content["transformations"]; var q25_t: Dictionary = q25_td["tiers"]["awakening"]
	var q25_nr: Array = []
	for q25_k in q25_td["tiers"]:
		if not bool(q25_td["tiers"][q25_k]["executed"]): q25_nr.append(str(q25_td["tiers"][q25_k]["name"]))
	var q25_g: Array = [q25_mk.call("story:provincials_semifinal").transform_tier("RORY"), q25_mk.call("story:provincials_semifinal,secret:RORY,story:trial:RORY").transform_tier("RORY"),
		q25_mk.call().transform_tier("RORY"), q25_mk.call().awaken_form("RORY"), q25_mk.call("story:provincials_semifinal,secret:PRIYA,story:trial:PRIYA").transform_tier("PRIYA"),
		q25_mk.call("secret:PRIYA,story:trial:PRIYA", "", "", TNBSim.LINEUP_MILLBROOK, "", "").transform_tier("PRIYA"), q25_mk.call(q25_mfl).awaken_form("RORY"),
		q25_mk.call(q25_mfl, "", "RORY+SAM:150", TNBSim.LINEUP_MILLBROOK_8, "sanctioned").awaken_form("RORY"), q25_mk.call(q25_mfl, "zone").awaken_form("RORY"), q25_mk.call(q25_fl, "manifest").awaken_form("RORY")]
	_sr("Awakening as data (NP_09 s6): tier %d, %ds, %s, %d stacking rules; the Comedown %s; the gate %s, the protagonist %s %s; named, not run %s; RORY with the Zone only %s, with his SECRET and trial %s, with the sealed house too %s stacking %s; PRIYA with hers %s, with nothing to stack '%s'; with the Manifest %s, Sworn with SAM %s, his choice the Zone %s, his choice the Manifest he lacks %s" % ([int(q25_t["tier"]), int(q25_t["duration_s"]), JSON.stringify(q25_t["effects"]), q25_t["stack_rules"].size() - 1, JSON.stringify(q25_t["comedown"].keys()), JSON.stringify(q25_t["unlock"]["flags"]), str(q25_t["unlock"]["protagonist"]["card"]), JSON.stringify(q25_t["unlock"]["protagonist"]["flags"]), JSON.stringify(q25_nr)] + q25_g),
		bool(q25_t["executed"]) and int(q25_t["tier"]) == 5 and int(q25_t["duration_s"]) == 40 and int(q25_t["effects"]["stack_pct"]) == 75 and float(q25_t["effects"]["ring_cap"]) == 1.75 and int(q25_t["effects"]["drop_refund"]) == 15 and int(q25_t["effects"]["hybrid_slot"]) == 1 \
		and str(q25_t["stack_rules"]["time_scale"]) == "mult" and str(q25_t["stack_rules"]["auto_slip_every_s"]) == "period" and str(q25_t["stack_rules"]["stamina_frozen"]) == "fraction" and str(q25_t["stack_rules"]["echo_delay_s"]) == "keep" \
		and not q25_t["comedown"].has("seconds") and q25_t["unlock"]["flags"] == ["secret:{name}", "story:trial:{name}"] and str(q25_t["unlock"]["protagonist"]["card"]) == "RORY" and q25_t["unlock"]["protagonist"]["flags"] == ["story:sealed_house_resolved"] and q25_nr == [] \
		and q25_g == ["zone", "zone", "awakening", "zone", "awakening", "", "manifest", "inheritance", "zone", "zone"])
	# the SURGE and the choice: RORY Awakened stacks his Manifest at 75 % (x1.3, a 37.5-point meter, +22.5 %, x1.75) with the caps at x1.75 and
	# the refund, for the whole bar and the same hold, once per dual; between duals his card chooses - his SURGE the Zone, his Awakening's form -
	# refused in the fight, refused a form that is not a prior tier or a tier he lacks; the save carries both; the next dual's SURGE is the Zone
	var q25d: TNBSim = q25_mk.call(q25_mfl); q25d.tension = 100.0
	var q25_rs: Dictionary = q25d.transform(); var q25_fd: String = q23_feed.call(q25d, "AWAKENING :: ")
	var q25_fx: Dictionary = q25d._zone_fx()
	var q25_s0: Array = [q25d.tension, str(q25d.tform.get("form", "")), int(q25d.tform.get("t", 0)), q25d.freeze_t, JSON.stringify(q25d.transformed), float(q25d.tform.get("meter", 0.0))]
	thaw(q25d); var q25_again: String = q25d.transform_why("RORY")
	var q25c: TNBSim = q25_mk.call(q25_mfl); var q25_ch0: String = str(q25c.choose_surge("RORY", "tier", "zone")["why"])
	q15_win.call(q25c)
	var q25_ch: Array = [q25c.choose_surge("RORY", "tier", "zone"), q25c.choose_surge("RORY", "form", "awakening"), q25c.choose_surge("PRIYA", "tier", "manifest"), q25c.choose_surge("RORY", "form", "manifest")]
	var q25_tt1: String = q25c.transform_tier("RORY"); var q25_sl1: String = q25c.surge_line("RORY"); var q25_af: String = q25c.awaken_form("RORY")
	var q25_rec: Dictionary = TNBSave.fighter_record(q25c, q25c._stable_card("RORY")); var q25_bk: Dictionary = TNBSave.card_of(q25_rec)
	q25c.choose_surge("RORY", "tier", ""); var q25_tt0: String = q25c.transform_tier("RORY"); var q25_sl0: String = q25c.surge_line("RORY"); q25c.choose_surge("RORY", "tier", "zone")
	q25c.new_dual(); quiet(q25c); q25c.tension = 100.0; q25c.transform(); var q25_tt2: String = str(q25c.tform.get("tier", ""))
	_sr("the SURGE Awakened: %s %s - the bar %.0f, %s, %d ticks, the hold %d, the record %s, the meter %.1f; the effects %s; '%s'; again '%s'; the choice in the fight '%s'; between duals %s; his SURGE %s ('%s'), his form %s; the save %s / %s; back to his highest %s ('%s'); the next dual's SURGE %s" % [str(q25_rs.get("ok", false)), str(q25_rs.get("tier", "")), float(q25_s0[0]), str(q25_s0[1]), int(q25_s0[2]), int(q25_s0[3]), str(q25_s0[4]), float(q25_s0[5]), JSON.stringify(q25_fx), q25_fd, q25_again, q25_ch0, JSON.stringify(q25_ch.map(func(x): return str(x["why"]) if not bool(x["ok"]) else "ok")), q25_tt1, q25_sl1, q25_af, str(q25_rec.get("surge_tier", "")), str(q25_bk.get("awakening_form", "")), q25_tt0, q25_sl0, q25_tt2],
		bool(q25_rs["ok"]) and str(q25_rs["tier"]) == "awakening" and float(q25_s0[0]) == 0.0 and str(q25_s0[1]) == "manifest" and int(q25_s0[2]) == TNBSim.ms(40000) and int(q25_s0[3]) == TNBSim.ms(2500) and str(q25_s0[4]) == "{\"RORY\":\"awakening\"}" and float(q25_s0[5]) == 37.5 \
		and absf(float(q25_fx["damage_mult"]) - 1.3) < 0.0001 and float(q25_fx["echo_pct"]) == 22.5 and float(q25_fx["displace_mult"]) == 1.75 and float(q25_fx["echo_delay_s"]) == 0.3 and float(q25_fx["ring_cap"]) == 1.75 and float(q25_fx["drop_refund"]) == 15.0 \
		and q25_fd == "AWAKENING :: RORY - the whole bar (100 of 100); 40s: Spirit Manifestation at 75% (RORY's manifest - damage x1.3, hissatsu from a 37.5-point meter, clean punches echoed +22.5%, displacement x1.75); the rings' caps x1.75; every drop scored +15 Tension back; the hybrid slot open on nothing" \
		and q25_again == "RORY is already awakened" and q25_ch0 == "between duals only" and bool(q25_ch[0]["ok"]) and str(q25_ch[1]["why"]) == "an Awakening stacks a prior tier - the Zone, the Manifest or Inheritance" and str(q25_ch[2]["why"]) == "PRIYA has not unlocked Spirit Manifestation" and bool(q25_ch[3]["ok"]) \
		and q25_tt1 == "zone" and q25_sl1 == "SURGE: In the Zone (100) - his choice" and q25_af == "manifest" and str(q25_rec.get("surge_tier", "")) == "zone" and str(q25_bk.get("awakening_form", "")) == "manifest" \
		and q25_tt0 == "awakening" and q25_sl0 == "SURGE: Awakening (100) - Manifest-Awakening at 75%" and q25_tt2 == "zone")
	# the effects at 75 %, each against the tier at full strength and the same sim without either: a straight x1.3 (the Manifest x1.4) and its
	# echo at 22.5 %; the Zone's world x0.8125 (325 of 400 ticks), a slip every 4 s (slip, hit, 3 s on hit, 1 s more slip), stamina a quarter as
	# mobile, the windows +150 ms; the Inheritance's reads three in four misread; the caps: MARTA's native Miroir d'Hiver in her element against
	# a beaten one x1.573 (x1.5 capped without); a drop scored +15 Tension back
	var q25_mw: Array = [q25_mk.call(q25_mfl), q25_mk.call("story:provincials_semifinal,story:manifest:RORY"), q25_mk.call(q25_mfl)]
	q25_in.call(q25_mw[0]); q25_in.call(q25_mw[1]); q25_mw[2].tension = 100.0
	var q25_hd: Array = []
	for q25_s in q25_mw:
		place(q25_s); q25_s.events.clear(); throw_clean(q25_s, "R_STRAIGHT"); var q25_h: float = hit_dmg(q25_s, "B")
		thaw(q25_s); q25_s.events.clear(); run_ticks(q25_s, TNBSim.ms(300))
		var q25_ed := 0.0
		for q25_e in q25_s.events:
			if str(q25_e["kind"]) == "echo": q25_ed += float(q25_e["dmg"])
		q25_hd.append([snappedf(q25_h, 0.0001), snappedf(q25_ed, 0.0001)])
	var q25_zp := func() -> Array:
		var q25_z: TNBSim = q25_mk.call(q25_fl); q25_in.call(q25_z)
		var q25_c: TNBSim = q25_mk.call(q25_fl); q25_c.tension = 100.0
		return [q25_z, q25_c]
	var q25_z1: Array = q25_zp.call(); var q25_bt: Array = []
	for q25_s in q25_z1:
		q25_s.bstate = "IDLE"; q25_s.btimer = 100000; var q25_b0: int = q25_s.btimer
		run_ticks(q25_s, 400); q25_bt.append(q25_b0 - q25_s.btimer)
	var q25_z2: Array = q25_zp.call(); var q25_sl: Array = []
	for q25_s in q25_z2:
		place(q25_s); var q25_seq: Array = []
		for q25_i in 4:
			q25_s.events.clear(); var q25_c0: float = float(q25_s.P["comp"])
			clear_defense(q25_s.P); boss_lands(q25_s, "R_HOOK")
			q25_seq.append("slip" if count_events(q25_s.events, "evade", {"why": "ZONE_SLIP"}) > 0 else ("hit" if float(q25_s.P["comp"]) < q25_c0 else "?"))
			if q25_i == 1: run_ticks(q25_s, TNBSim.ms(3000))
			if q25_i == 2: run_ticks(q25_s, TNBSim.ms(1000))
		q25_sl.append(q25_seq)
	var q25_z3: Array = q25_zp.call(); var q25_sm: Array = []
	for q25_s in q25_z3:
		q25_s.P["stamina"] = 60.0
		if q25_s.tform.size() > 0: q25_s.tform["stam"] = 60.0
		for q25_i in 4: throw_clean(q25_s, "R_HOOKERCUT", {"power": true})
		q25_sm.append(60.0 - float(q25_s.P["stamina"]))
	var q25_wn: int = q25_z3[0]._window("slip") - q25_z3[1]._window("slip")
	var q25_ip: Array = [q25_mk.call(q25_mfl, "", "RORY+SAM:150", TNBSim.LINEUP_MILLBROOK_8, "sanctioned"), q25_mk.call(q25_mfl, "", "RORY+SAM:150", TNBSim.LINEUP_MILLBROOK_8, "sanctioned")]
	q25_in.call(q25_ip[0]); q25_ip[1].tension = 100.0; var q25_rd: Array = []
	for q25_s in q25_ip:
		place(q25_s); var q25_tally := {"misread": 0, "dodge": 0, "guard": 0, "none": 0}
		for q25_i in 24:
			thaw(q25_s); q25_s.B["comp"] = q25_s.B["comp_max"]; q25_s.P["busy_t"] = 0; q25_s.P["cmd"] = {}
			q25_s.step({"punch": "R_STRAIGHT"})
			var q25_r: String = str(q25_s.P.get("pending", {}).get("read", "none"))
			q25_tally[q25_r] = int(q25_tally.get(q25_r, 0)) + 1
			land(q25_s); run_ticks(q25_s, 30)
		q25_rd.append(q25_tally)
	var q25_lum: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q25_lum[0] = TNBSim.LINEUP_MILLBROOK_8[7].duplicate(true); q25_lum[0].erase("reserve")   # MARTA out first: Miroir d'Hiver, FROST, House Tremblay
	var q25_mafl := "story:provincials_semifinal,secret:MARTA,story:trial:MARTA"
	var q25_cp: Array = [q25_mk.call(q25_mafl, "", "", q25_lum), q25_mk.call(q25_mafl, "", "", q25_lum)]
	q25_in.call(q25_cp[0]); q25_cp[1].tension = 100.0
	var q25_hm: Array = [snappedf(q25_cp[0].hiss_mult("P"), 0.0001), snappedf(q25_cp[1].hiss_mult("P"), 0.0001), q25_cp[0].transform_tier("MARTA")]
	var q25_dp: Array = q25_zp.call(); var q25_rf: Array = []
	for q25_s in q25_dp:
		q25_s.tension = 0.0; q25_s.events.clear(); q25_s._drop(false); q25_rf.append([q25_s.tension, count_events(q25_s.events, "refund")])
	_sr("Awakening's effects at 75 %%, against full strength and without: a straight (Manifest-Awakening, the Manifest, neither) %s; his timers %d / %d of 400; four punches at him %s; stamina spent on four power hookercuts %.2f / %.2f; the slip window +%d ticks; reads over 24 straights %s; MARTA's Miroir d'Hiver x%.4f Awakened (%s) against x%.4f; a drop scored %s" % [JSON.stringify(q25_hd), int(q25_bt[0]), int(q25_bt[1]), JSON.stringify(q25_sl), float(q25_sm[0]), float(q25_sm[1]), q25_wn, JSON.stringify(q25_rd), float(q25_hm[0]), str(q25_hm[2]), float(q25_hm[1]), JSON.stringify(q25_rf)],
		absf(float(q25_hd[0][0]) - 1.3 * float(q25_hd[2][0])) < 0.001 and absf(float(q25_hd[1][0]) - 1.4 * float(q25_hd[2][0])) < 0.001 and absf(float(q25_hd[0][1]) - 0.225 * float(q25_hd[0][0])) < 0.001 and float(q25_hd[2][1]) == 0.0 \
		and int(q25_bt[0]) == 325 and int(q25_bt[1]) == 400 and q25_sl[0] == ["slip", "hit", "hit", "slip"] and q25_sl[1] == ["hit", "hit", "hit", "hit"] \
		and float(q25_sm[1]) > 0.0 and float(q25_sm[0]) > 0.0 and float(q25_sm[0]) / float(q25_sm[1]) > 0.2 and float(q25_sm[0]) / float(q25_sm[1]) < 0.3 and q25_wn == TNBSim.ms(150) \
		and int(q25_rd[0]["misread"]) > int(q25_rd[0]["dodge"]) and int(q25_rd[0]["dodge"]) > 0 and int(q25_rd[1]["misread"]) == 0 and int(q25_rd[1]["dodge"]) > 0 \
		and absf(float(q25_hm[0]) - 1.3 * 1.1 * 1.1) < 0.0001 and float(q25_hm[1]) == 1.5 and str(q25_hm[2]) == "awakening" \
		and float(q25_rf[0][0]) == float(q25_rf[1][0]) + 15.0 and int(q25_rf[0][1]) == 1 and int(q25_rf[1][1]) == 0)
	# the end: the AWAKENED line; 40 s of fight time after the hold RORY comes down from his Inheritance-Awakening - SAM's trait gone, every stat at
	# 85 %, no scrambled dialect (that rider is Inheritance's own), a drop in the Comedown no refund; 10 s on he is himself
	var q25e: TNBSim = q25_mk.call(q25_fl, "", "RORY+SAM:150", TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); q25_in.call(q25e); q25e.events.clear()
	var q25_pw0: float = float(q25e.P["stats"]["PWR"]); var q25_zl: String = q25e.zone_line()
	run_ticks(q25e, TNBSim.ms(40000) - 1); var q25_still: bool = q25e.tform.size() > 0 and q25e._tx(q25e.P, "never_twice") == 0.75
	run_ticks(q25e, 1); var q25_cd: Array = [q25e.tform.is_empty(), q25e.comedown.size() > 0, q25e._tx(q25e.P, "never_twice"), snappedf(float(q25e.P["stats"]["PWR"]), 0.01), int(q25e.comedown.get("scramble_t", 0))]
	var q25_endf: String = q23_feed.call(q25e, "THE AWAKENING ENDS"); var q25_cl: String = q25e.zone_line()
	q25e.tension = 0.0; q25e._drop(false); var q25_cdr: Array = [q25e.tension, count_events(q25e.events, "refund")]
	run_ticks(q25e, TNBSim.ms(10000)); var q25_back: Array = [q25e.comedown.is_empty(), float(q25e.P["stats"]["PWR"]) == q25_pw0, count_events(q25e.events, "comedown_end")]
	_sr("the end: '%s'; at 39.99 s %s; at 40 s %s ('%s', '%s'); a drop in the Comedown %s; 10 s on %s" % [q25_zl, str(q25_still), JSON.stringify(q25_cd), q25_endf, q25_cl, JSON.stringify(q25_cdr), JSON.stringify(q25_back)],
		q25_zl == "AWAKENED 40.0s | Inheritance-Awakening at 75% | ring caps x1.75 | a drop +15 | House Tagaq from SAM (Sworn) | Never Twice | meter 37/37 | Sorry Eh, Still Water | the enemy misreads you (75%)" and q25_still \
		and bool(q25_cd[0]) and bool(q25_cd[1]) and float(q25_cd[2]) == 0.0 and absf(float(q25_cd[3]) - q25_pw0 * 0.85) < 0.01 and int(q25_cd[4]) == 0 \
		and q25_endf == "THE AWAKENING ENDS - RORY comes down from the Inheritance-Awakening: 10s at 85%" and q25_cl == "COMEDOWN 10.0s (85%)" \
		and float(q25_cdr[0]) == 10.0 and int(q25_cdr[1]) == 0 and bool(q25_back[0]) and bool(q25_back[1]) and int(q25_back[2]) == 1)
	# the manager and the record: delegated with the gate met and a full bar he never SURGEs on his own; the manager's SURGE Awakens him; a DualState
	# mid-Awakening restores the stacked effects on the same hash and the two run on to the same hash; R2 PRIYA comes out with none of it
	var q25h: TNBSim = q25_mk.call(q25_mfl); q25h.delegate_all = true; q25h.new_dual(); quiet(q25h); q25h.wall["B"] = {}; q25h.tension = 100.0
	run_ticks(q25h, 1200); var q25_self: int = count_events(q25h.events, "zone"); q25h.tension = 100.0; q25h.cast = {}; q25h.step({"surge": true})
	var q25_pass: String = "%s %s" % [str(q25h.tform.get("tier", "")), str(q25h.tform.get("form", ""))]
	var q25i: TNBSim = q25_mk.call(q25_mfl); q25_in.call(q25i); run_ticks(q25i, 600)
	var q25_h0: int = q25i.hash_state(); var q25_sn: Dictionary = q25i.snapshot(); var q25j := make_sim(4, 99); var q25_ro: Dictionary = q25j.restore(q25_sn)
	var q25_rh: bool = q25j.hash_state() == q25_h0; var q25_rl: String = q25j.zone_line()
	run_ticks(q25i, TNBSim.ms(40000)); run_ticks(q25j, TNBSim.ms(40000)); var q25_same: bool = q25i.hash_state() == q25j.hash_state() and q25i.comedown.size() > 0
	var q25n: TNBSim = q25_mk.call(q25_mfl); q25_in.call(q25n); seg_end.call(q25n, 4); next_segment(q25n)
	_sr("Awakening and the manager, on record: delegated %d SURGEs of his own, the manager's -> %s; a DualState mid-Awakening restores %s on the same hash %s ('%s'), both %s at its end; R2 %s: %s" % [q25_self, q25_pass, str(q25_ro.get("ok", false)), str(q25_rh), q25_rl, "the same" if q25_same else "APART", q25n.pname(), JSON.stringify(q25n.tform)],
		q25_self == 0 and q25_pass == "awakening manifest" and bool(q25_ro.get("ok", false)) and q25_rh and q25_rl.begins_with("AWAKENED 35.0s | Manifest-Awakening at 75% | ring caps x1.75 | a drop +15 | RORY's manifest | meter 37/37") and q25_same \
		and q25n.pname() == "PRIYA" and q25n.tform.is_empty())

	# ---- PAC-086: THE ENEMY'S TRANSFORMATIONS (NP_09 s1, s4, s7) ----
	var q26_led := TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(""), "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", content["economy"]), "story:provincials_semifinal,story:manifest:RORY")
	var q26_mk := func(q26_bi: int, q26_tf: Dictionary = {}, q26_strip: bool = false) -> TNBSim:       # a boss, quiet; a TRANSFORM line injected, or his own stripped
		var q26_s := make_sim(q26_bi, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q26_led); quiet(q26_s); q26_s.wall["B"] = {}
		if q26_tf.size() > 0: q26_s.pattern["transform"] = q26_tf.duplicate(true)
		if q26_strip: q26_s.pattern.erase("transform")
		return q26_s
	var q26_go := func(q26_s: TNBSim, q26_pct: float) -> TNBSim:                                     # his composure under the trigger, the gathering run out, the hold waited, him frozen again
		q26_s.B["comp"] = q26_s.B["comp_max"] * q26_pct; q26_s.step({})
		var q26_n := 0
		while q26_s.btsurge.size() > 0 and q26_n < 2000: q26_s.step({}); q26_n += 1
		thaw(q26_s); freeze_boss(q26_s); q26_s.events.clear()
		return q26_s
	var q26_mf := {"trigger": "composure<80", "tier": "manifest", "manifest": "the test manifest", "tell": {"motif": "gather", "ms": 1000}, "line": "VEY: he is gathering."}
	# the data, Vasile's line and the gathering: NP_09 s1's enemy transforms as the table has them (the Zone and the Manifest castable by a boss,
	# the tell at the ARMORED floor, once per boss per dual; the Clash run - 5 exchanges in 5 s at x0.5, 180 ms windows, 3 to win, the card 60 %;
	# the weathering - 1 s a perfect-defense action, his damage halved, the feat); the roster's one authored line compiled; at 51 % composure
	# nothing, at 49 % he gathers 1.5 s behind his guard with his line - the player jabbing into it draws no answer and no attack - then the
	# shared hold, his bar emptied, his Zone; once a dual: under the trigger again nothing, the next dual he gathers again
	var q26_td: Dictionary = content["transformations"]; var q26_bt: Dictionary = q26_td["boss"]; var q26_cl: Dictionary = q26_td["tiers"]["manifest"]["clash"]; var q26_we: Dictionary = q26_td["shared"]["weathering"]
	var q26_auth: Array = []
	for q26_b in content["patterns"]:
		if content["patterns"][q26_b].get("transform") is Dictionary: q26_auth.append(str(q26_b))
	var q26_vt: Dictionary = content["patterns"]["ioan_vasile"]["transform"]
	var q26a: TNBSim = q26_mk.call(16); q26a.hooks_enabled = true; q26a.btension = 60.0
	q26a.B["comp"] = q26a.B["comp_max"] * 0.51; q26a.step({}); var q26_51: Array = [q26a.btsurge.size(), q26a.bstate]
	q26a.B["comp"] = q26a.B["comp_max"] * 0.49; q26a.events.clear(); q26a.step({})
	var q26_g0: Array = [int(q26a.btsurge.get("t", 0)), q26a.bstate, int(q26a.B["guard_t"]), count_events(q26a.events, "boss_transform_tell"), q26a.bzone_line()]
	var q26_tl: Dictionary = {}
	for q26_e in q26a.events:
		if str(q26_e["kind"]) == "boss_transform_tell": q26_tl = q26_e
	var q26_gn := 0; var q26_held := true; var q26_jabs := 0
	while q26a.btsurge.size() > 0 and q26_gn < 1000:
		var q26_in := {}
		if q26_gn % 30 == 0: q26a.P["busy_t"] = 0; q26a.P["cmd"] = {}; q26_in = {"punch": "L_STRAIGHT"}; q26_jabs += 1
		q26a.step(q26_in); q26_gn += 1
		if q26a.btsurge.size() > 0 and q26a.bstate != "SURGE": q26_held = false
	var q26_hold: Array = [q26a.freeze_t, q26a.btension, str(q26a.btform.get("tier", "")), int(q26a.btform.get("t", 0)), count_events(q26a.events, "boss_zone"), count_events(q26a.events, "tell"), count_events(q26a.events, "sensor")]
	thaw(q26a); freeze_boss(q26a); var q26_zl: String = q26a.bzone_line()
	run_ticks(q26a, TNBSim.ms(31000)); var q26_off: Array = [q26a.btform.size(), q26a.bcomedown.size()]
	q26a.B["comp"] = q26a.B["comp_max"] * 0.3; q26a.step({}); var q26_twice: int = q26a.btsurge.size()
	q26a.new_dual(); quiet(q26a); q26a.B["comp"] = q26a.B["comp_max"] * 0.49; q26a.step({}); var q26_next: int = int(q26a.btsurge.get("t", 0))
	_sr("his transformation as data and on the page (NP_09 s1): castable %s, the tell floor %d ms, %d per boss per dual; the Clash %s; the weathering %s; authored %s: %s; at 51%% %s; at 49%% %s, the tell %s '%s'; %d ticks of gathering under %d jabs, his state held %s, %d answers, %d sensors; then %s ('%s'); 31 s on %s; under the trigger again %d; the next dual %d" % [JSON.stringify(q26_bt["tiers"]), int(q26_bt["tell_floor_ms"]), int(q26_bt["per_boss_per_dual"]), JSON.stringify(q26_cl), JSON.stringify(q26_we.keys()), JSON.stringify(q26_auth), JSON.stringify(q26_vt), JSON.stringify(q26_51), JSON.stringify(q26_g0), str(q26_tl.get("motif", "")), str(q26_tl.get("line", "")), q26_gn, q26_jabs, str(q26_held), int(q26_hold[5]), int(q26_hold[6]), JSON.stringify(q26_hold), q26_zl, JSON.stringify(q26_off), q26_twice, q26_next],
		q26_bt["tiers"] == ["zone", "manifest"] and int(q26_bt["tell_floor_ms"]) == 1000 and int(q26_bt["per_boss_per_dual"]) == 1 \
		and bool(q26_cl["executed"]) and int(q26_cl["exchanges"]) == 5 and int(q26_cl["window_ms"]) == 180 and int(q26_cl["to_win"]) == 3 and int(q26_cl["delegated_hit_pct"]) == 60 and int(q26_cl["seconds"]) == 5 and float(q26_cl["time_scale"]) == 0.5 \
		and q26_we["actions"] == ["perfect_block", "slip", "clash_exchange"] and int(q26_we["shave_s"]) == 1 and float(q26_we["damage_mult"]) == 0.5 and str(q26_we["feat"]) == "stood_in_the_storm" \
		and q26_auth == ["ioan_vasile"] and str(q26_vt["trigger"]) == "composure<50" and str(q26_vt["tier"]) == "zone" and str(q26_vt["tell"]["motif"]) == "breath_held" and int(q26_vt["tell"]["ms"]) == 1500 \
		and q26_51 == [0, "IDLE"] and q26_g0 == [180, "SURGE", 180, 1, "GATHERING 1.5s | VEY: he has stopped breathing out loud - that is his Zone coming. Weather it."] and str(q26_tl.get("line", "")) == str(q26_vt["line"]) and str(q26_tl.get("motif", "")) == "breath_held" \
		and q26_gn >= 180 and q26_held and q26_jabs >= 6 and int(q26_hold[5]) == 0 and int(q26_hold[6]) > 0 \
		and int(q26_hold[0]) == TNBSim.ms(2500) and float(q26_hold[1]) == 0.0 and str(q26_hold[2]) == "zone" and int(q26_hold[3]) == TNBSim.ms(20000) and int(q26_hold[4]) == 1 and q26_zl == "ENEMY ZONE 20.0s | weathered 0 (-0.0s)" \
		and q26_off == [0, 0] and q26_twice == 0 and q26_next == TNBSim.ms(1500))
	# his Zone against the same boss with his line stripped: his timers at 1/0.75 outside his tells (533 of 400 ticks), his tells at the floor
	# (400), his acting +15 % on top (613); the player's punches at him - the first of every 3 s slipped (a slip, a hit, 3 s on a slip, a hit);
	# his stamina frozen; 20 s on his Comedown - every stat at 85 % for 10 s, the HUD's window line, nothing weathered so no feat - then himself
	var q26_rt: Array = []
	for q26_st in ["IDLE", "TELL", "ACTING"]:
		var q26_pr: Array = [q26_go.call(q26_mk.call(16), 0.49), q26_mk.call(16, {}, true)]
		q26_pr[1].B["comp"] = q26_pr[1].B["comp_max"] * 0.49
		var q26_r: Array = []
		for q26_s in q26_pr:
			q26_s.bstate = q26_st; q26_s.btimer = 100000; q26_s.bqueue = []; var q26_b0: int = q26_s.btimer
			run_ticks(q26_s, 400); q26_r.append(q26_b0 - q26_s.btimer)
		q26_rt.append(q26_r)
	var q26_sl: Array = []
	var q26_slp: Array = [q26_go.call(q26_mk.call(16), 0.49), q26_mk.call(16, {}, true)]
	q26_slp[1].B["comp"] = q26_slp[1].B["comp_max"] * 0.49
	for q26_s in q26_slp:
		place(q26_s); var q26_seq: Array = []
		for q26_i in 4:
			q26_s.events.clear(); var q26_c0: float = float(q26_s.B["comp"])
			throw_clean(q26_s, "R_STRAIGHT")
			q26_seq.append("slip" if count_events(q26_s.events, "evade", {"why": "ZONE_SLIP", "by": "B"}) > 0 else ("hit" if float(q26_s.B["comp"]) < q26_c0 else "?"))
			if q26_i == 1: run_ticks(q26_s, TNBSim.ms(3000))
			thaw(q26_s)
		q26_sl.append(q26_seq)
	var q26_sm: Array = []
	for q26_s in [q26_go.call(q26_mk.call(16), 0.49), q26_mk.call(16, {}, true)]:
		var q26_s0: float = float(q26_s.B["stamina"]); q26_s.B["stamina"] = q26_s0 - 30.0; q26_s.step({}); q26_sm.append(snappedf(float(q26_s.B["stamina"]) - q26_s0, 0.01))
	var q26c: TNBSim = q26_go.call(q26_mk.call(16), 0.49); var q26_st0: Dictionary = q26c.B["stats"].duplicate()
	var q26_cn := 0
	while q26c.btform.size() > 0 and q26_cn < 5000: q26c.step({}); q26_cn += 1
	var q26_ze: Dictionary = {}
	for q26_e in q26c.events:
		if str(q26_e["kind"]) == "boss_zone_end": q26_ze = q26_e
	var q26_cd: Array = [int(q26c.bcomedown.get("t", 0)), snappedf(float(q26c.B["stats"]["PWR"]), 0.01), snappedf(float(q26c.B["stats"]["SPD"]), 0.01), q26c.bzone_line(), bool(q26_ze.get("stood", true)), count_events(q26c.events, "feat"), q23_feed.call(q26c, "THE ENEMY'S ZONE ENDS")]
	var q26_cf := 0; var q26_cg := 0
	while q26c.bcomedown.size() > 0 and q26_cg < 5000:
		if q26c.freeze_t == 0: q26_cf += 1
		q26c.step({}); q26_cg += 1
	var q26_cb: Array = [q26_cf, q26c.B["stats"] == q26_st0, count_events(q26c.events, "boss_comedown_end"), q26c.bzone_line()]
	_sr("his Zone against his line stripped: his timers (idle, in a tell, acting) %s of 400; four punches at him %s; his stamina after -30 %s; after %d ticks his Comedown %s; %d fight ticks on (hitstop aside) %s" % [JSON.stringify(q26_rt), JSON.stringify(q26_sl), JSON.stringify(q26_sm), q26_cn, JSON.stringify(q26_cd), int(q26_cb[0]), JSON.stringify(q26_cb)],
		q26_rt == [[533, 400], [400, 400], [613, 400]] and q26_sl[0] == ["slip", "hit", "slip", "hit"] and q26_sl[1] == ["hit", "hit", "hit", "hit"] and float(q26_sm[0]) == 0.0 and float(q26_sm[1]) < -29.0 \
		and int(q26_cd[0]) == TNBSim.ms(10000) and absf(float(q26_cd[1]) - float(q26_st0["PWR"]) * 0.85) < 0.01 and absf(float(q26_cd[2]) - float(q26_st0["SPD"]) * 0.85) < 0.01 and str(q26_cd[3]) == "ENEMY COMEDOWN 10.0s (85%) - your window" \
		and not bool(q26_cd[4]) and int(q26_cd[5]) == 0 and str(q26_cd[6]).begins_with("THE ENEMY'S ZONE ENDS - ioan_vasile comes down: 10s at 85% - YOUR WINDOW (weathered 0") \
		and int(q26_cb[0]) == TNBSim.ms(10000) and bool(q26_cb[1]) and int(q26_cb[2]) == 1 and str(q26_cb[3]) == "")
	# his Manifest, authored on Moira MacIsaac at 80 % for the test (the aid's shape): the HUD's line, no meter of his; a clean hook x1.4 and its
	# echo on the player at 0.3 s for 30 %, against her without the line; her desperation Undertow's damage x1.4 and its displacement x2; a drop
	# of the player's clears his queued echoes; a line naming a tier bosses cannot cast (the Awakening) never gathers
	var q26m: TNBSim = q26_go.call(q26_mk.call(19, q26_mf), 0.79); var q26_mc: TNBSim = q26_mk.call(19); q26_mc.B["comp"] = q26_mc.B["comp_max"] * 0.79
	var q26_ml: String = q26m.bzone_line(); var q26_mm: bool = q26m.btform.has("meter")
	var q26_hd: Array = []
	for q26_s in [q26m, q26_mc]:
		place(q26_s); clear_defense(q26_s.P); q26_s.events.clear(); var q26_c0: float = float(q26_s.P["comp"]); boss_lands(q26_s, "R_HOOK"); var q26_d0: float = q26_c0 - float(q26_s.P["comp"])
		thaw(q26_s); q26_s.events.clear(); run_ticks(q26_s, TNBSim.ms(300))
		var q26_ed := 0.0; var q26_on := ""
		for q26_e in q26_s.events:
			if str(q26_e["kind"]) == "echo": q26_ed += float(q26_e["dmg"]); q26_on = str(q26_e["on"])
		q26_hd.append([snappedf(q26_d0, 0.001), snappedf(q26_ed, 0.001), q26_on])
	var q26_dp: Array = []
	for q26_s in [q26_go.call(q26_mk.call(19, q26_mf), 0.79), q26_mk.call(19)]:
		q26_s.P["pos"] = Vector2(0, 0.6); q26_s.B["pos"] = Vector2(0, -0.6); var q26_c0: float = float(q26_s.P["comp"])
		var q26_ok: bool = boss_desperation(q26_s)
		var q26_n := 0
		while q26_s.cast.size() > 0 and q26_n < 600: clear_defense(q26_s.P); q26_s.P["blocking"] = false; q26_s.step({}); q26_n += 1
		var q26_m := 0.0
		for q26_e in q26_s.events:
			if str(q26_e["kind"]) == "displace" and str(q26_e["who"]) == "B": q26_m = float(q26_e["m"])
		q26_dp.append([q26_ok, q26_m, snappedf(q26_c0 - float(q26_s.P["comp"]), 0.01)])
	var q26_dr: TNBSim = q26_go.call(q26_mk.call(19, q26_mf), 0.79); place(q26_dr); clear_defense(q26_dr.P); boss_lands(q26_dr, "R_HOOK"); var q26_q0: int = q26_dr.btform["echoes"].size()
	q26_dr._drop(true); var q26_q1: Array = [q26_dr.btform["echoes"].size(), bool(q26_dr.btform["dropped"])]
	var q26_aw: TNBSim = q26_mk.call(19, {"trigger": "composure<80", "tier": "awakening", "tell": {"motif": "gather", "ms": 1000}, "line": "x"}); q26_aw.B["comp"] = q26_aw.B["comp_max"] * 0.5; run_ticks(q26_aw, 10)
	_sr("his Manifest (Moira, the test's line): '%s', his meter %s; a clean hook and its echo %s against %s; the Undertow (cast, displacement, damage) %s against %s; a drop with %d echo queued -> %s; a line naming the Awakening: %d gathering" % [q26_ml, str(q26_mm), JSON.stringify(q26_hd[0]), JSON.stringify(q26_hd[1]), JSON.stringify(q26_dp[0]), JSON.stringify(q26_dp[1]), q26_q0, JSON.stringify(q26_q1), q26_aw.btsurge.size() + q26_aw.btform.size()],
		q26_ml == "ENEMY MANIFEST 30.0s | weathered 0 (-0.0s) | the test manifest" and not q26_mm and absf(float(q26_hd[0][0]) - 1.4 * float(q26_hd[1][0])) < 0.01 and absf(float(q26_hd[0][1]) - 0.3 * float(q26_hd[0][0])) < 0.01 and str(q26_hd[0][2]) == "P" and float(q26_hd[1][1]) == 0.0 \
		and bool(q26_dp[0][0]) and bool(q26_dp[1][0]) and float(q26_dp[1][1]) > 0.0 and absf(float(q26_dp[0][1]) - 2.0 * float(q26_dp[1][1])) < 0.001 and absf(float(q26_dp[0][2]) - 1.4 * float(q26_dp[1][2])) < 0.05 \
		and q26_q0 == 1 and q26_q1 == [0, true] and q26_aw.btsurge.size() == 0 and q26_aw.btform.size() == 0)
	# the Clash (NP_09 s4): RORY SURGEs his Manifest into hers - after the hold the fight stops for five exchanges in 5 s, hers first, each
	# window 360 ms (180 at x0.5) either side of its cue; the fight clock and both manifests' clocks wait. Perfect: 5 of 5, hers suppressed into
	# her Comedown, five weatherings, no feat (he answered). None: 5 missed, his own manifest into his Comedown. Early: 5 lost. The window's far
	# edge and a slip count: 3 of 5 wins it, 2 of 5 loses it. The card: presses only on the cue, six in ten, the pad ignored - never early
	var q26_cx := func(q26_plan: Array, q26_dl: bool = false) -> Dictionary:
		var q26_k: TNBSim = q26_go.call(q26_mk.call(19, q26_mf), 0.79); q26_k.tension = 100.0; q26_k.step({"surge": true})
		var q26_n := 0
		while q26_k.mode != "CLASH" and q26_n < 1000: q26_k.step({}); q26_n += 1
		var q26_o := {"after": q26_n, "line": q26_k.bzone_line(), "cues": q26_k.mclash.get("cues", []).duplicate(), "kinds": q26_k.mclash.get("kinds", []).duplicate(), "window": int(q26_k.mclash.get("window", 0)), "clock0": q26_k.clock_t, "bt0": int(q26_k.btform.get("t", 0)), "pt0": int(q26_k.tform.get("t", 0))}
		if q26_dl: q26_k.delegated = true
		q26_k.events.clear(); q26_n = 0
		while q26_k.mode == "CLASH" and q26_n < 2000:
			var q26_in := {}
			var q26_i: int = int(q26_k.mclash["i"])
			if q26_dl: q26_in = {"punch": "L_STRAIGHT", "block": q26_n % 2 == 0}
			elif q26_i < q26_k.mclash["cues"].size():
				var q26_cue: int = int(q26_k.mclash["cues"][q26_i]); var q26_nt: int = int(q26_k.mclash["t"]) + 1; var q26_w: int = int(q26_k.mclash["window"])
				var q26_p: String = str(q26_plan[q26_i])
				if (q26_p == "perfect" and q26_nt == q26_cue) or (q26_p == "early" and q26_nt == q26_cue - q26_w - 1) or (q26_p == "edge" and q26_nt == q26_cue + q26_w):
					q26_in = {"punch": "L_STRAIGHT"} if str(q26_k.mclash["kinds"][q26_i]) == "attack" else ({"dodge": "SLIP_L"} if q26_i == 2 else {"block": true})
			q26_k.step(q26_in); q26_n += 1
		var q26_res: Array = []; var q26_win := ""; var q26_sup := false
		for q26_e in q26_k.events:
			if str(q26_e["kind"]) == "clash_exchange": q26_res.append(str(q26_e["result"]))
			if str(q26_e["kind"]) == "clash_end": q26_win = str(q26_e["winner"])
			if str(q26_e["kind"]) == "boss_zone_end": q26_sup = bool(q26_e["suppressed"])
		q26_o.merge({"res": q26_res, "ticks": q26_n, "clock1": q26_k.clock_t, "bt1": int(q26_k.btform.get("t", -1)), "pt1": int(q26_k.tform.get("t", -1)), "winner": q26_win, "suppressed": q26_sup, "weather": count_events(q26_k.events, "weather"), "feat": count_events(q26_k.events, "feat"), "mode": q26_k.mode})
		q26_k.step({}); q26_o.merge({"mine": str(q26_k.tform.get("tier", "")), "my_cd": q26_k.comedown.size() > 0, "his_cd": q26_k.bcomedown.size() > 0, "his_line": q26_k.bzone_line()})
		return q26_o
	var q26_P: Dictionary = q26_cx.call(["perfect", "perfect", "perfect", "perfect", "perfect"]); var q26_N: Dictionary = q26_cx.call(["none", "none", "none", "none", "none"])
	var q26_E: Dictionary = q26_cx.call(["early", "early", "early", "early", "early"]); var q26_3: Dictionary = q26_cx.call(["edge", "none", "perfect", "none", "edge"])
	var q26_2: Dictionary = q26_cx.call(["perfect", "perfect", "none", "none", "none"]); var q26_D: Dictionary = q26_cx.call([], true)
	var q26_dw: int = q26_D["res"].filter(func(x): return x == "won").size()
	_sr("the Clash: %d ticks after his SURGE, '%s', cues %s %s, window %d; perfect %s -> %s, the clock %d/%d, his %d -> %d, mine %d -> %d, suppressed %s, weathered %d, feats %d, then '%s'; none %s -> %s, mine %s (Comedown %s), his %d -> %d; early %s -> %s; the edge and a slip %s -> %s; two %s -> %s; the card %s (%d won)" % [int(q26_P["after"]), str(q26_P["line"]), JSON.stringify(q26_P["cues"]), JSON.stringify(q26_P["kinds"]), int(q26_P["window"]), JSON.stringify(q26_P["res"]), str(q26_P["winner"]), int(q26_P["clock0"]), int(q26_P["clock1"]), int(q26_P["bt0"]), int(q26_P["bt1"]), int(q26_P["pt0"]), int(q26_P["pt1"]), str(q26_P["suppressed"]), int(q26_P["weather"]), int(q26_P["feat"]), str(q26_P["his_line"]),
		JSON.stringify(q26_N["res"]), str(q26_N["winner"]), str(q26_N["mine"]), str(q26_N["my_cd"]), int(q26_N["bt0"]), int(q26_N["bt1"]), JSON.stringify(q26_E["res"]), str(q26_E["winner"]), JSON.stringify(q26_3["res"]), str(q26_3["winner"]), JSON.stringify(q26_2["res"]), str(q26_2["winner"]), JSON.stringify(q26_D["res"]), q26_dw],
		int(q26_P["after"]) == TNBSim.ms(2500) + 1 and str(q26_P["line"]) == "MANIFEST CLASH 1/5 | BLOCK or SLIP in 0.50s | won 0 lost 0" and q26_P["cues"] == [60, 180, 300, 420, 540] and q26_P["kinds"] == ["defend", "attack", "defend", "attack", "defend"] and int(q26_P["window"]) == TNBSim.ms(360) \
		and q26_P["res"] == ["won", "won", "won", "won", "won"] and str(q26_P["winner"]) == "P" and int(q26_P["clock0"]) == int(q26_P["clock1"]) and int(q26_P["bt1"]) == -1 and int(q26_P["pt1"]) == int(q26_P["pt0"]) and bool(q26_P["suppressed"]) and int(q26_P["weather"]) == 5 and int(q26_P["feat"]) == 0 \
		and str(q26_P["mode"]) == "FIGHT" and str(q26_P["mine"]) == "manifest" and bool(q26_P["his_cd"]) and str(q26_P["his_line"]) == "ENEMY COMEDOWN 10.0s (85%) - your window" \
		and q26_N["res"] == ["missed", "missed", "missed", "missed", "missed"] and str(q26_N["winner"]) == "B" and str(q26_N["mine"]) == "" and bool(q26_N["my_cd"]) and int(q26_N["bt1"]) == int(q26_N["bt0"]) and int(q26_N["clock0"]) == int(q26_N["clock1"]) \
		and q26_E["res"] == ["early", "early", "early", "early", "early"] and str(q26_E["winner"]) == "B" and q26_3["res"] == ["won", "missed", "won", "missed", "won"] and str(q26_3["winner"]) == "P" and q26_2["res"] == ["won", "won", "missed", "missed", "missed"] and str(q26_2["winner"]) == "B" \
		and q26_D["res"].size() == 5 and not "early" in q26_D["res"] and q26_dw >= 1 and q26_dw <= 4)
	# the weathering (NP_09 s7) against Vasile's Zone: his clean hook the same as without his line; a perfect block 1 s off it and his damage
	# halved after (the HUD says so); a slip another second; run to its end unanswered and never down - Stood in the Storm on the ledger, its
	# feed line; SURGEing into it answers it (no feat); knocked down in it and up on the count, no feat; a DualState mid-Zone restores on the
	# same hash with his side readable, both run to the feat alike; the feat survives the save
	var q26w: TNBSim = q26_go.call(q26_mk.call(16), 0.49); var q26_wc: TNBSim = q26_mk.call(16, {}, true)
	var q26_wd: Array = []
	for q26_s in [q26w, q26_wc]:
		place(q26_s); clear_defense(q26_s.P); var q26_c0: float = float(q26_s.P["comp"]); boss_lands(q26_s, "R_HOOK"); q26_wd.append(snappedf(q26_c0 - float(q26_s.P["comp"]), 0.001)); thaw(q26_s)
	var q26_w0: int = int(q26w.btform["t"]); q26w.events.clear()
	q26w.P["blocking"] = true; q26w.P["block_t"] = 1; q26w.P["guard_open_t"] = 0; boss_lands(q26w, "R_HOOK")
	var q26_pb: Array = [count_events(q26w.events, "perfect_block"), count_events(q26w.events, "weather", {"why": "perfect_block"}), q26_w0 - int(q26w.btform["t"]), q26w.bzone_line()]
	thaw(q26w); clear_defense(q26w.P); q26w.P["blocking"] = false; var q26_c1: float = float(q26w.P["comp"]); boss_lands(q26w, "R_HOOK"); var q26_hf: float = snappedf(q26_c1 - float(q26w.P["comp"]), 0.001)
	thaw(q26w); q26w.events.clear(); clear_defense(q26w.P); q26w.P["dodge"] = "SLIP"; q26w.P["dodge_t"] = 30; q26w.P["dodge_dir"] = 1; var q26_t1: int = int(q26w.btform["t"]); boss_lands(q26w, "R_HOOK")
	var q26_sp: Array = [count_events(q26w.events, "weather", {"why": "slip"}), q26_t1 - int(q26w.btform["t"]), int(q26w.btform["weathered"])]
	thaw(q26w); clear_defense(q26w.P); q26w.events.clear()
	var q26_wn := 0
	while q26w.btform.size() > 0 and q26_wn < 5000: q26w.step({}); q26_wn += 1
	var q26_ft: Dictionary = {}; var q26_we2: Dictionary = {}
	for q26_e in q26w.events:
		if str(q26_e["kind"]) == "feat": q26_ft = q26_e
		if str(q26_e["kind"]) == "boss_zone_end": q26_we2 = q26_e
	var q26_led2: Dictionary = q26w.rewards.get("feats", {}).get("stood_in_the_storm", {}).duplicate(); var q26_ffd: String = q23_feed.call(q26w, "STOOD IN THE STORM")
	var q26an: TNBSim = q26_go.call(q26_mk.call(16), 0.49); place(q26an); q26an.tension = 100.0; q26an.step({"surge": true}); thaw(q26an); freeze_boss(q26an)
	q26an.P["blocking"] = true; q26an.P["block_t"] = 1; q26an.P["guard_open_t"] = 0; boss_lands(q26an, "R_HOOK"); thaw(q26an); clear_defense(q26an.P); q26an.P["blocking"] = false
	var q26_an0: Array = [str(q26an.tform.get("tier", "")), bool(q26an.btform["answered"]), int(q26an.btform["weathered"])]
	var q26_an_n := 0
	while q26an.btform.size() > 0 and q26_an_n < 8000: q26an.step({}); q26_an_n += 1
	var q26_an: Array = q26_an0 + [count_events(q26an.events, "feat"), q26an.rewards.get("feats", {}).size()]
	var q26dn: TNBSim = q26_go.call(q26_mk.call(16), 0.49); place(q26dn); q26dn.P["blocking"] = true; q26dn.P["block_t"] = 1; q26dn.P["guard_open_t"] = 0; boss_lands(q26dn, "R_HOOK"); thaw(q26dn)
	clear_defense(q26dn.P); q26dn.P["blocking"] = false; q26dn.P["comp"] = 0.5; boss_lands(q26dn, "R_HOOKERCUT"); var q26_dn0: Array = [q26dn.mode, bool(q26dn.btform.get("dropped", false))]
	for q26_b in 3:
		var q26_gd := 0
		while q26dn.mode == "EIGHT" and q26dn.eight["timer_t"] > q26dn.eight["window_t"] and q26_gd < 400: q26dn.step({}); q26_gd += 1
		if q26dn.mode != "EIGHT": break
		q26dn.step({"rise": true}); q26dn.step({"rise": false})
	freeze_boss(q26dn); var q26_dn1: String = q26dn.mode
	var q26_dn_n := 0
	while q26dn.btform.size() > 0 and q26_dn_n < 8000: q26dn.step({}); q26_dn_n += 1
	var q26_dn: Array = q26_dn0 + [q26_dn1, count_events(q26dn.events, "feat"), q26dn.rewards.get("feats", {}).size()]
	var q26s: TNBSim = q26_go.call(q26_mk.call(16), 0.49); place(q26s); q26s.P["blocking"] = true; q26s.P["block_t"] = 1; q26s.P["guard_open_t"] = 0; boss_lands(q26s, "R_HOOK"); thaw(q26s); clear_defense(q26s.P); q26s.P["blocking"] = false
	run_ticks(q26s, 600)
	var q26_sh: int = q26s.hash_state(); var q26_sn: Dictionary = q26s.snapshot(); var q26r := make_sim(4, 99); var q26_ro: Dictionary = q26r.restore(q26_sn)
	var q26_rs: Array = [bool(q26_ro.get("ok", false)), q26r.hash_state() == q26_sh, q26r.bzone_line(), JSON.stringify(q26r.dual_state()["transform_log"]["away"])]
	run_ticks(q26s, TNBSim.ms(20000)); run_ticks(q26r, TNBSim.ms(20000))
	var q26_same: bool = q26s.hash_state() == q26r.hash_state() and int(q26s.rewards.get("feats", {}).get("stood_in_the_storm", {}).get("count", 0)) == 1 and int(q26r.rewards.get("feats", {}).get("stood_in_the_storm", {}).get("count", 0)) == 1
	var q26_sv: Dictionary = TNBSave.build(content, TNBSave.read_text(TNBSave.write_text(q26s, true)), 31337); var q26_svf: Dictionary = q26_sv["sim"].rewards.get("feats", {})
	_sr("weathering his Zone: his clean hook %s (without his line %s); a perfect block %s; his hook after %.3f; a slip %s; %d ticks on %s, the feat %s, the ledger %s, '%s'; answered %s; knocked down %s; the DualState %s, both at the end %s; saved and loaded %s" % [str(q26_wd[0]), str(q26_wd[1]), JSON.stringify(q26_pb), q26_hf, JSON.stringify(q26_sp), q26_wn, JSON.stringify([q26_we2.get("weathered", -1), q26_we2.get("stood", false)]), str(q26_ft.get("name", "")), JSON.stringify(q26_led2), q26_ffd, JSON.stringify(q26_an), JSON.stringify(q26_dn), JSON.stringify(q26_rs), "the same" if q26_same else "APART", JSON.stringify(q26_svf)],
		float(q26_wd[0]) == float(q26_wd[1]) and float(q26_wd[0]) > 0.0 and q26_pb == [1, 1, TNBSim.ms(1000), "ENEMY ZONE 19.0s | weathered 1 (-1.0s) | damage to you halved"] and absf(q26_hf - 0.5 * float(q26_wd[0])) < 0.002 \
		and q26_sp == [1, TNBSim.ms(1000), 2] and int(q26_we2.get("weathered", 0)) == 2 and bool(q26_we2.get("stood", false)) and str(q26_ft.get("name", "")) == "Stood in the Storm" and str(q26_ft.get("against", "")) == "ioan_vasile" \
		and int(q26_led2.get("count", 0)) == 1 and str(q26_led2.get("last", "")) == "ioan_vasile" and q26_ffd == "STOOD IN THE STORM - RORY weathered ioan_vasile's transformation without answering" \
		and str(q26_an[0]) == "manifest" and bool(q26_an[1]) and int(q26_an[2]) == 1 and int(q26_an[3]) == 0 and int(q26_an[4]) == 0 \
		and str(q26_dn[0]) == "EIGHT" and bool(q26_dn[1]) and str(q26_dn[2]) == "FIGHT" and int(q26_dn[3]) == 0 and int(q26_dn[4]) == 0 \
		and bool(q26_rs[0]) and bool(q26_rs[1]) and str(q26_rs[2]).begins_with("ENEMY ZONE 14.0s | weathered 1 (-1.0s) | damage to you halved") and str(q26_rs[3]).contains("\"tier\":\"zone\"") and str(q26_rs[3]).contains("\"weathered\":1") \
		and q26_same and int(q26_svf.get("stood_in_the_storm", {}).get("count", 0)) == 1)

	# ---- PAC-087: CROSS-HOUSE HYBRID RESEARCH (NP_08 s6) ----
	var q27_led := func(q27_kz: String, q27_pu: String = "spirits:60,beans:40", q27_fl: String = "", q27_lv: String = "") -> Dictionary:   # since PAC-089 the Forge is hosted at The Wall's T3
		return TNBSim.seed_facilities(TNBSim.seed_purse(TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(q27_kz), q27_lv, content["economy"]), q27_fl), q27_pu), "wall:3", content["facilities"])
	var q27_mk := func(q27_kz: String, q27_slots: Array = ["YURI", "MARTA", "SAM", "RORY", "PRIYA"], q27_pu: String = "spirits:60,beans:40", q27_fl: String = "", q27_lv: String = "") -> TNBSim:
		var q27_s := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8.duplicate(true), "sanctioned", {}, q27_led.call(q27_kz, q27_pu, q27_fl, q27_lv), {"slots": q27_slots}); quiet(q27_s); q27_s.wall["B"] = {}
		return q27_s
	var q27_nx := func(q27_s: TNBSim) -> void:                        # the segment ended with no fight; the next fighter out
		seg_end.call(q27_s, 0); next_segment(q27_s); quiet(q27_s); q27_s.wall["B"] = {}
	var q27_card := func(q27_nm: String, q27_house: String, q27_el: String, q27_hiss: String) -> Dictionary:   # a stand-in card (MARTA's stats) of a house the club has no fighter of
		var q27_c: Dictionary = TNBSim.LINEUP_MILLBROOK_8[7].duplicate(true); q27_c["name"] = q27_nm; q27_c["house"] = q27_house; q27_c["element"] = q27_el; q27_c["hissatsu"] = q27_hiss; q27_c.erase("reserve")
		return q27_c
	# the data and the requirement: NP_08 s6 as the table has it (40 Spirits and 30 Beans, between duals, eight a save, E07's early half-price
	# Forge, the composer's rules, x1.25 relayed, a motif per house), Sworn carrying "hybrid", the library's two authored hybrids; the pair each
	# refused for its own reason - not in the club, himself, no house, one house, no native learned, the bond short, the purse short, during a
	# fight - and YURI & MARTA at Sworn with a purse: nothing in the way
	var q27_t: Dictionary = content["hybrids"]
	var q27_ex: Array = []
	for q27_n in content["library"]:
		if str(content["library"][q27_n].get("source", "")) == "hybrid:forge": q27_ex.append("%s %s" % [q27_n, JSON.stringify(content["library"][q27_n]["hybrid_parents"])])
	var q27a: TNBSim = q27_mk.call("YURI+MARTA:150,SAM+YURI:90,DEX+MARTA:150")
	q27a.stable.append(q27_card.call("IRONSIDE", "iron", "GRANITE", "Chinook Rush")); q27a.stable.append(q27_card.call("YURI2", "kowalchuk", "GRANITE", "Full Load"))
	var q27_w: Array = [q27a.forge_why("NOBODY", "YURI"), q27a.forge_why("YURI", "YURI"), q27a.forge_why("RORY", "YURI"), q27a.forge_why("YURI", "YURI2"), q27a.forge_why("IRONSIDE", "YURI"), q27a.forge_why("SAM", "YURI"), q27a.forge_why("YURI", "MARTA")]
	var q27_ln: Array = [q27a.learned_natives("YURI"), q27a.learned_natives("MARTA"), q27a.learned_natives("IRONSIDE"), q27_mk.call("", ["YURI", "MARTA", "SAM", "RORY", "PRIYA"], "", "secret:YURI").learned_natives("YURI")]
	var q27_poor: TNBSim = q27_mk.call("YURI+MARTA:150", ["YURI", "MARTA", "SAM", "RORY", "PRIYA"], "spirits:39,beans:40")
	var q27_late: TNBSim = q27_mk.call("YURI+MARTA:150"); q27_late.step({})
	var q27_w2: Array = [q27_poor.forge_why("YURI", "MARTA"), q27_late.forge_why("YURI", "MARTA"), q27_late.forge("YURI", "MARTA")["why"]]
	_sr("hybrid research as data (NP_08 s6): the Forge %s, ceiling %d, discounts %s, the composer's floor %.1f +%.1f, seconds cap %d, cinematic %d+%d, x%.2f relayed, %d motifs; Sworn's %s (Lv%d); authored %s; learned %s; refused %s; a short purse '%s', in the fight '%s' / '%s'" % [JSON.stringify([q27_t["forge"]["spirits"], q27_t["forge"]["beans"]]), int(q27_t["ceiling"]), JSON.stringify(q27_t["discounts"].map(func(d): return [d["edge"], d["flag"], d["pct"], d["early_level"]])), float(q27_t["compose"]["dmg_floor"]), float(q27_t["compose"]["dmg_over_parent"]), int(q27_t["compose"]["tag_seconds_cap"]), int(q27_t["compose"]["cinematic_base_ms"]), int(q27_t["compose"]["cinematic_per_tag_ms"]), float(q27_t["cast"]["relayed_dmg_mult"]), q27_t["motifs"].size() - 1, JSON.stringify(content["economy"]["kizuna"]["effects"]["5"].keys()), q27a.hybrid_level(), JSON.stringify(q27_ex), JSON.stringify(q27_ln), JSON.stringify(q27_w), q27_w2[0], q27_w2[1], q27_w2[2]],
		int(q27_t["forge"]["spirits"]) == 40 and int(q27_t["forge"]["beans"]) == 30 and int(q27_t["ceiling"]) == 8 and str(q27_t["discounts"][0]["edge"]) == "E07" and str(q27_t["discounts"][0]["flag"]) == "quest:third_bridge" and int(q27_t["discounts"][0]["pct"]) == 50 and int(q27_t["discounts"][0]["early_level"]) == 4 \
		and float(q27_t["cast"]["relayed_dmg_mult"]) == 1.25 and q27_t["motifs"].size() - 1 == 13 and bool(content["economy"]["kizuna"]["effects"]["5"]["hybrid"]) and q27a.hybrid_level() == 5 \
		and q27_ex == ["Two Rivers [\"nguyen-roy\",\"delacroix-cardinal\"]", "Grain & Snow [\"kowalchuk\",\"tremblay\"]"] \
		and q27_ln == [["Grain Elevator", "Full Load"], ["Premiere Neige", "Miroir d'Hiver"], [], ["Grain Elevator", "Full Load", "Harvest Moon"]] \
		and q27_w == ["NOBODY is not in the club", "a hybrid takes two fighters", "RORY carries no house (a hybrid crosses two houses)", "YURI and YURI2 are both House Kowalchuk (a hybrid crosses two houses)", "IRONSIDE knows no native of House Iron", "SAM & YURI are at Lv4 Duo (90) - the Forge opens at Lv5 Sworn", ""] \
		and q27_w2 == ["the Forge costs 40 Spirits and 30 Beans (the ledger holds 39 and 40)", "the Forge is between duals", "the Forge is between duals"])
	# the Forge: YURI & MARTA (Kowalchuk x Tremblay) get the library's Grain & Snow, the ledger 60/40 -> 20/10, the registry 1 of 8; the
	# composer run on the same pair rebuilds it field for field (the family and damage of Full Load +0.1, Grain Elevator's shred, Premiere
	# Neige's auto-slip at 2 s, 2300 ms), its name the motifs' "Grain & Snow"; a second Kowalchuk x Tremblay pair composes its own under the
	# pair's names; DEX & MARTA "Tide & Snow"; SAM & YURI would be "Grain & Silence"; across E07 with Q-NGUYEN-ROY done, TAM and a
	# Delacroix-Cardinal card forge Two Rivers at Duo for half, refused at Duo without the flag and at Adjacent Trust with it; the save
	# carries the registry and the Beans, a load writes it back byte-equal and the pair has forged
	var q27_c0: Dictionary = q27a.compose_hybrid("YURI", "MARTA"); var q27_gs: Dictionary = TNBSim._whole(content["library"]["Grain & Snow"])
	var q27_diff: Array = []
	for q27_k in ["tier", "family", "element", "tension_cost", "startup_cinematic_ms", "effect", "counter_profile", "hybrid_parents", "camera_script_id", "vfx_set", "source"]:
		if JSON.stringify(q27_c0[q27_k]) != JSON.stringify(q27_gs[q27_k]): q27_diff.append(q27_k)
	q27a.events.clear()
	var q27_f1: Dictionary = q27a.forge("YURI", "MARTA"); var q27_fd: String = q23_feed.call(q27a, "THE FORGE :: ")
	var q27_p1: Array = [int(q27a.rewards["spirits"]), int(q27a.rewards["beans"]), count_events(q27a.events, "forge")]
	q27a.rewards["spirits"] = 200; q27a.rewards["beans"] = 200; q27a.rewards["kizuna"][TNBSim.pair_key("MARTA", "YURI2")] = 150
	var q27_f2: Dictionary = q27a.forge("YURI2", "MARTA"); var q27_f3: Dictionary = q27a.forge("DEX", "MARTA"); var q27_sy: Dictionary = q27a.compose_hybrid("SAM", "YURI")
	var q27_reg: Array = q27a.hybrid_registry().map(func(h): return "%s %s %s %s" % [str(h["id"]), str(h["name"]), str(h["pair"]), "authored" if bool(h["authored"]) else "composed"])
	var q27e: TNBSim = q27_mk.call("", ["YURI", "MARTA", "SAM", "RORY", "PRIYA"], "spirits:60,beans:40", "quest:third_bridge")
	q27e.stable.append(q27e.recruit_card("tam_nguyen_roy")); q27e.stable.append(q27_card.call("DC_STANDIN", "delacroix-cardinal", "GALE", "River Read"))
	var q27_e07: Array = []
	for q27_pts in [90, 50]:
		q27e.rewards["kizuna"][TNBSim.pair_key("TAM", "DC_STANDIN")] = q27_pts; q27_e07.append(q27e.forge_why("TAM", "DC_STANDIN"))
	var q27_e07n: TNBSim = q27_mk.call("TAM+DC_STANDIN:90"); q27_e07n.stable.append(q27_e07n.recruit_card("tam_nguyen_roy")); q27_e07n.stable.append(q27_card.call("DC_STANDIN", "delacroix-cardinal", "GALE", "River Read"))
	q27_e07.append(q27_e07n.forge_why("TAM", "DC_STANDIN"))
	q27e.rewards["kizuna"][TNBSim.pair_key("TAM", "DC_STANDIN")] = 90; q27e.events.clear()
	var q27_f4: Dictionary = q27e.forge("TAM", "DC_STANDIN"); var q27_fd4: String = q23_feed.call(q27e, "THE FORGE :: ")
	var q27sv: TNBSim = q27_mk.call("YURI+MARTA:150,DEX+MARTA:150", ["YURI", "MARTA", "SAM", "RORY", "PRIYA"], "spirits:100,beans:100"); q27sv.forge("YURI", "MARTA"); q27sv.forge("DEX", "MARTA")   # the club's own cards (a stand-in pins no wall)
	var q27_sv: Dictionary = TNBSave.to_save(q27sv); var q27_tx: String = TNBSave.write_text(q27sv, false)
	var q27al = TNBSave.build(content, TNBSave.read_text(q27_tx), 5)["sim"]
	var q27_rt: Array = [q27_sv["hybrid_registry"].size(), int(q27_sv["currencies"]["beans"]), TNBSave.write_text(q27al, false) == q27_tx, JSON.stringify(q27al.hybrid_registry()) == JSON.stringify(q27sv.hybrid_registry()), q27al.forge_why("YURI", "MARTA")]
	_sr("the Forge: %s -> %s ('%s'), the ledger %s; the composer on the same pair differs in %s, named '%s'; then %s / %s, SAM & YURI would be %s %s %s; the registry %s; across E07 %s, then '%s' (%s); the save %s" % [str(q27_f1["ok"]), str(q27_f1.get("name", "")), q27_fd, JSON.stringify(q27_p1), JSON.stringify(q27_diff), str(q27_c0["name"]), str(q27_f2.get("name", q27_f2["why"])), str(q27_f3.get("name", q27_f3["why"])), str(q27_sy["name"]), str(q27_sy["family"]), JSON.stringify(q27_sy["effect"]), JSON.stringify(q27_reg), JSON.stringify(q27_e07), q27_fd4, str(q27_f4.get("name", q27_f4["why"])), JSON.stringify(q27_rt)],
		bool(q27_f1["ok"]) and str(q27_f1["name"]) == "Grain & Snow" and bool(q27_f1["authored"]) and q27_p1 == [20, 10, 1] and q27_diff.is_empty() and str(q27_c0["name"]) == "Grain & Snow - MARTA & YURI" \
		and q27_fd == "THE FORGE :: YURI & MARTA (House Kowalchuk x House Tremblay, Lv5 Sworn) forge GRAIN & SNOW - a T3 HAYMAKER of both: DMG x2.5, guard shred 40, auto slip 2s; 40 Spirits, 30 Beans (the ledger 20 / 10); hybrid 1 of 8" \
		and str(q27_f2["name"]) == "Grain & Snow - MARTA & YURI2" and str(q27_f3["name"]) == "Tide & Snow" and str(q27_sy["name"]) == "Grain & Silence" and str(q27_sy["family"]) == "HAYMAKER" \
		and JSON.stringify(q27_sy["effect"]) == "[{\"params\":{\"composure_bypass_pct\":0,\"mult\":2.5},\"type\":\"DMG\"},{\"params\":{\"guard\":40},\"type\":\"SHRED\"},{\"params\":{\"name\":\"counter_stance\",\"seconds\":2},\"type\":\"STATE\"}]" \
		and q27_reg == ["HIS-074 Grain & Snow MARTA|YURI authored", "HYB-02 Grain & Snow - MARTA & YURI2 MARTA|YURI2 composed", "HYB-03 Tide & Snow DEX|MARTA composed"] \
		and q27_e07 == ["", "TAM & DC_STANDIN are at Lv3 Adjacent Trust (50) - the Forge opens at Lv4 Duo", "TAM & DC_STANDIN are at Lv4 Duo (90) - the Forge opens at Lv5 Sworn"] \
		and str(q27_f4.get("name", "")) == "Two Rivers" and q27_fd4.contains("(House Nguyen-Roy x House Delacroix-Cardinal, Lv4 Duo, E07 MARRIAGE)") and q27_fd4.contains("20 Spirits, 15 Beans (E07 MARRIAGE, -50%) (the ledger 40 / 25)") \
		and q27_rt == [2, 40, true, true, "YURI & MARTA have forged Grain & Snow"])
	# the cast: YURI R1, MARTA R2 - R1 nothing (no partner before him), CHARGED the hybrid at x1; R2 MARTA relayed from YURI: the event, the
	# matchup card's line, x1.25 and YURI's afterimage; LB + HAYMAKER casts it before the pair's own Duo T3 (live on the same motion), the
	# cast's event and feed, the debut; its hit x1.25 the same hybrid cast from the same state with her partner not before her (CHARGED, x1), the same shred and slip; R3 SAM
	# nothing; MARTA out first and YURI second, relayed the other way; MARTA across a slot, nothing
	var q27c: TNBSim = q27_mk.call("YURI+MARTA:150"); q27c.forge("YURI", "MARTA")
	var q27_r1: Array = [q27c.hybrid_move().size()]
	q27c.t3_unlocked = true; var q27_ch: Dictionary = q27c.hybrid_move(); q27_r1.append_array([str(q27_ch.get("hybrid_live", "")), float(q27_ch["effect"][0]["params"]["mult"]), q27c.hybrid_line()]); q27c.t3_unlocked = false
	q27c.events.clear(); seg_end.call(q27c, 0); next_segment(q27c)
	var q27_hev: Dictionary = {}
	for q27_e in q27c.events:
		if str(q27_e["kind"]) == "hybrid": q27_hev = q27_e
	quiet(q27c); q27c.wall["B"] = {}
	var q27_hm: Dictionary = q27c.hybrid_move()
	var q27_r2: Array = [q27c.pname(), str(q27_hev.get("live", "")), str(q27_hev.get("partner", "")), q27c.hybrid_line(), float(q27_hm["effect"][0]["params"]["mult"]), JSON.stringify(q27_hm["effect"][-1]), str(q27c.duo_move().get("family", ""))]
	place(q27c, 1.4); q27c.tension = 100.0; q27c.B["comp"] = q27c.B["comp_max"]; q27c.B["guard"] = q27c.B["guard_max"]; q27c.P["busy_t"] = 0; q27c.P["cmd"] = {}
	var q27_snap: Dictionary = q27c.snapshot(); q27c.events.clear()
	q27c.step({"punch": "R_HOOKERCUT", "lb": true})
	var q27_cev: Dictionary = {}
	for q27_e in q27c.events:
		if str(q27_e["kind"]) == "cast": q27_cev = q27_e
	var q27_cfd: String = q23_feed.call(q27c, "MARTA ARMS")
	var q27_deb: int = count_events(q27c.events, "hybrid_debut")
	var q27_g0: float = float(q27c.B["guard"]); var q27_k0: float = float(q27c.B["comp"]); resolve_cast(q27c)
	var q27_hit: Array = [snappedf(q27_k0 - float(q27c.B["comp"]), 0.0001), snappedf(q27_g0 - float(q27c.B["guard"]), 0.0001), int(q27c.states["P"].get("auto_slip", 0)) > 0]
	var q27cp := make_sim(4, 99); q27cp.restore(q27_snap); q27cp.lineup[q27cp.seg_idx - 1]["name"] = "SAM"; q27cp.t3_unlocked = true; q27cp.events.clear()   # the same state, the partner not before her: CHARGED, x1
	q27cp.step({"punch": "R_HOOKERCUT", "lb": true}); var q27_pn: String = "%s %s" % [str(q27cp.cast.get("move", {}).get("name", "")), str(q27cp.cast.get("move", {}).get("hybrid_live", ""))]
	var q27_pg0: float = float(q27cp.B["guard"]); var q27_pk0: float = float(q27cp.B["comp"]); resolve_cast(q27cp)
	var q27_plain: Array = [snappedf(q27_pk0 - float(q27cp.B["comp"]), 0.0001), snappedf(q27_pg0 - float(q27cp.B["guard"]), 0.0001)]
	var q27_reg2: Dictionary = q27c.hybrid_of_pair("YURI", "MARTA")
	q27_nx.call(q27c); var q27_r3: Array = [q27c.pname(), q27c.hybrid_move().size()]
	var q27d: TNBSim = q27_mk.call("YURI+MARTA:150", ["MARTA", "YURI", "SAM", "RORY", "PRIYA"]); q27d.forge("YURI", "MARTA"); q27_nx.call(q27d)
	var q27_rv: Array = [q27d.pname(), str(q27d.hybrid_move().get("hybrid_live", "")), str(q27d.hybrid_move().get("hybrid_partner", ""))]
	var q27x: TNBSim = q27_mk.call("YURI+MARTA:150", ["YURI", "SAM", "MARTA", "RORY", "PRIYA"]); q27x.forge("YURI", "MARTA"); q27_nx.call(q27x); q27_nx.call(q27x)
	var q27_rx: Array = [q27x.pname(), q27x.hybrid_move().size()]
	_sr("the cast: R1 %s; R2 %s; the cast %s ('%s'), %d debut, the registry %s; its hit %s against %s (%s) unrelayed; R3 %s; the other way %s; across a slot %s" % [JSON.stringify(q27_r1), JSON.stringify(q27_r2), JSON.stringify([q27_cev.get("move", ""), q27_cev.get("hybrid", ""), q27_cev.get("hybrid_live", ""), q27_cev.get("afterimage", ""), q27_cev.get("hybrid_elements", [])]), q27_cfd, q27_deb, JSON.stringify([q27_reg2.get("casts", 0), q27_reg2.get("debut_day", 0)]), JSON.stringify(q27_hit), JSON.stringify(q27_plain), q27_pn, JSON.stringify(q27_r3), JSON.stringify(q27_rv), JSON.stringify(q27_rx)],
		q27_r1 == [0, "charged", 2.5, "HYBRID: Grain & Snow (LB + HAYMAKER, 50) - the CHARGED relay opens it"] \
		and q27_r2 == ["MARTA", "relayed", "YURI", "HYBRID: Grain & Snow (LB + HAYMAKER, 50) - relayed from YURI - YURI's afterimage joins, x1.25", 3.125, "{\"params\":{\"name\":\"afterimage_partner\",\"seconds\":3},\"type\":\"STATE\"}", "HAYMAKER"] \
		and str(q27_cev.get("move", "")) == "Grain & Snow" and str(q27_cev.get("hybrid", "")) == "MARTA|YURI" and str(q27_cev.get("hybrid_live", "")) == "relayed" and str(q27_cev.get("afterimage", "")) == "YURI" and q27_cev.get("hybrid_elements", []) == ["FROST", "GRANITE"] \
		and q27_cfd == "MARTA ARMS GRAIN & SNOW (T3 HAYMAKER, 50 Tension) - HYBRID of MARTA & YURI: relayed from YURI - YURI's afterimage joins, x1.25" and q27_deb == 1 and int(q27_reg2.get("casts", 0)) == 1 and int(q27_reg2.get("debut_day", 0)) == 1 \
		and q27_pn == "Grain & Snow charged" and float(q27_plain[0]) > 0.0 and absf(float(q27_hit[0]) - 1.25 * float(q27_plain[0])) < 0.001 and float(q27_hit[1]) == float(q27_plain[1]) and float(q27_hit[1]) > 0.0 and bool(q27_hit[2]) \
		and q27_r3 == ["SAM", 0] and q27_rv == ["YURI", "relayed", "MARTA"] and q27_rx == ["MARTA", 0])
	# the Awakening's slot and the card's choice: MARTA forged twice (Grain & Snow with YURI, Silence & Snow with SAM: Sorry Eh's ARC and
	# counter-stance, Premiere Neige's auto-slip); her slot her first forged, then her choice between duals - refused a hybrid not hers, refused
	# in the fight; out first she has none live; Awakened, the feed names the slot, its event, Silence & Snow live at x1 on LB + ARC; 40 s on,
	# none; the save carries her choice; the CHARGED relay opens her choice too
	var q27s: TNBSim = q27_mk.call("YURI+MARTA:150,SAM+MARTA:150", ["MARTA", "SAM", "YURI", "RORY", "PRIYA"], "spirits:100,beans:100", "story:provincials_semifinal,secret:MARTA,story:trial:MARTA", "MARTA:20")
	var q27_sf: Array = [q27s.forge("YURI", "MARTA")["name"], q27s.forge("SAM", "MARTA")["name"], JSON.stringify(q27s.hybrid_of_pair("SAM", "MARTA")["move"]["effect"]), str(q27s.hybrid_of_pair("SAM", "MARTA")["move"]["family"]), q27s._hyb_slot_text("MARTA")]
	var q27_sc: Array = [str(q27s.choose_hybrid("MARTA", "Tide & Snow")["why"]), bool(q27s.choose_hybrid("MARTA", "Silence & Snow")["ok"]), q27s._hyb_slot_text("MARTA")]
	var q27_scr: Dictionary = TNBSave.fighter_record(q27s, q27s._stable_card("MARTA"))
	q27s.step({}); q27_sc.append(str(q27s.choose_hybrid("MARTA", "")["why"]))
	var q27_s0: int = q27s.hybrid_move().size()
	q27s.t3_unlocked = true; var q27_scg: String = str(q27s.hybrid_move().get("name", "")); q27s.t3_unlocked = false
	q27s.tension = 100.0; q27s.events.clear(); q27s.step({"surge": true}); thaw(q27s); freeze_boss(q27s)
	var q27_af: String = q23_feed.call(q27s, "AWAKENING :: MARTA")
	var q27_aev: int = count_events(q27s.events, "hybrid", {"live": "awakened"})
	var q27_am: Dictionary = q27s.hybrid_move()
	place(q27s, 1.4); q27s.tension = 100.0; q27s.P["busy_t"] = 0; q27s.P["cmd"] = {}; q27s.step({"punch": "R_HOOK", "lb": true})
	var q27_ac: String = str(q27s.cast.get("move", {}).get("name", "")); var q27_al: String = str(q27s.cast.get("move", {}).get("hybrid_live", ""))
	resolve_cast(q27s); run_ticks(q27s, TNBSim.ms(40000))
	var q27_aend: Array = [q27s.tform.is_empty(), q27s.hybrid_move().size()]
	_sr("the Awakening's slot and the choice: forged %s; the choice %s; the record's slot '%s'; out first %d live, CHARGED %s; Awakened '%s', %d slot event, %s %s x%.2f, LB + ARC %s (%s); 40 s on %s" % [JSON.stringify(q27_sf), JSON.stringify(q27_sc), str(q27_scr.get("hybrid_slot", "")), q27_s0, q27_scg, q27_af, q27_aev, str(q27_am.get("name", "")), str(q27_am.get("hybrid_live", "")), float(q27_am["effect"][0]["params"]["mult"]) if q27_am.size() > 0 else 0.0, q27_ac, q27_al, JSON.stringify(q27_aend)],
		q27_sf[0] == "Grain & Snow" and q27_sf[1] == "Silence & Snow" and str(q27_sf[3]) == "ARC" and str(q27_sf[2]) == "[{\"params\":{\"composure_bypass_pct\":0,\"mult\":2.4},\"type\":\"DMG\"},{\"params\":{\"name\":\"counter_stance\",\"seconds\":2},\"type\":\"STATE\"},{\"params\":{\"name\":\"auto_slip\",\"seconds\":2},\"type\":\"STATE\"}]" \
		and str(q27_sf[4]) == "the hybrid slot holds Grain & Snow" and q27_sc == ["MARTA has no hybrid Tide & Snow", true, "the hybrid slot holds Silence & Snow", "between duals only"] and str(q27_scr.get("hybrid_slot", "")) == "Silence & Snow" \
		and q27_s0 == 0 and q27_scg == "Silence & Snow" and q27_af.ends_with("every drop scored +15 Tension back; the hybrid slot holds Silence & Snow") and q27_aev == 1 \
		and str(q27_am.get("name", "")) == "Silence & Snow" and str(q27_am.get("hybrid_live", "")) == "awakened" and float(q27_am["effect"][0]["params"]["mult"]) == 2.4 and q27_ac == "Silence & Snow" and q27_al == "awakened" and q27_aend == [true, 0])
	# the manager and the record: delegated in R2, the profile's T3 is the hybrid and it casts it; the Forge's "*" takes the first pair of the
	# club it can (SAM & YURI before YURI & MARTA in the stable's order); its lines between duals; at eight hybrids the ceiling refuses; a
	# DualState in R2 with the hybrid live restores on the same hash and reads the same line
	var q27m: TNBSim = q27_mk.call("YURI+MARTA:150"); q27m.forge("YURI", "MARTA"); q27m.delegate_all = true; q27_nx.call(q27m); q27m.delegated = true; q27m.neutral_on = false
	q27m.tension = 100.0; var q27_pick: String = str(q27m.t3_pick().get("name", "")); place(q27m, 1.4); q27m.events.clear()
	var q27_mc := ""
	for q27_i in 1500:
		q27m.step({})
		if q27m.cast.size() > 0 and str(q27m.cast["who"]) == "P": q27_mc = str(q27m.cast["move"].get("name", "")); break
	var q27st: TNBSim = q27_mk.call("YURI+MARTA:150,SAM+YURI:150"); var q27_fl0: Array = q27st.forge_lines()
	var q27_star: Dictionary = q27st.forge("*"); var q27_fl1: Array = q27st.forge_lines()
	for q27_i in 7: q27st.rewards["hybrids"]["X%d|Y%d" % [q27_i, q27_i]] = {"pair": "X%d|Y%d" % [q27_i, q27_i], "name": "stand-in %d" % q27_i, "move": {}}
	var q27_cap: Array = [q27st.forge_why("YURI", "MARTA"), str(q27st.forge("*")["why"])]
	var q27ds: TNBSim = q27_mk.call("YURI+MARTA:150"); q27ds.forge("YURI", "MARTA"); q27_nx.call(q27ds); run_ticks(q27ds, 300)
	var q27_dh: int = q27ds.hash_state(); var q27dr := make_sim(4, 99); var q27_dro: Dictionary = q27dr.restore(q27ds.snapshot())
	var q27_drs: Array = [bool(q27_dro.get("ok", false)), q27dr.hash_state() == q27_dh, q27dr.hybrid_line() == q27ds.hybrid_line(), q27dr.hybrid_line()]
	_sr("the manager and the record: the profile's T3 %s, its cast %s; the Forge's lines %s, '*' %s, then %s; at eight %s; a DualState in R2 %s" % [q27_pick, q27_mc, JSON.stringify(q27_fl0), str(q27_star.get("name", q27_star["why"])), JSON.stringify(q27_fl1), JSON.stringify(q27_cap), JSON.stringify(q27_drs)],
		q27_pick == "Grain & Snow" and q27_mc == "Grain & Snow" \
		and q27_fl0 == ["SAM & YURI -> Grain & Silence: [F] 40 Spirits, 30 Beans", "YURI & MARTA -> Grain & Snow: [F] 40 Spirits, 30 Beans"] and str(q27_star.get("name", "")) == "Grain & Silence" \
		and q27_fl1 == ["forged 1 of 8: Grain & Silence (SAM & YURI)", "YURI & MARTA -> Grain & Snow: the Forge costs 40 Spirits and 30 Beans (the ledger holds 20 and 10)"] \
		and q27_cap == ["the Forge's ceiling is reached (8 of 8 hybrids)", "no pair of the club can forge - the Forge's ceiling is reached (8 of 8 hybrids)"] \
		and bool(q27_drs[0]) and bool(q27_drs[1]) and bool(q27_drs[2]) and str(q27_drs[3]).begins_with("HYBRID: Grain & Snow"))

	# ---- PAC-088: THE EXHIBITION 2v2 (NP_01 s8, NP_05 s7) ----
	if content.is_empty(): content = TNBSim.load_content()
	var q28_mk := func(q28_kz: String, q28_ai: bool = true, q28_mgr: bool = false) -> Object:   # RORY (pair A, vs Yuri) and PRIYA (pair B, vs Moreau), both bosses frozen, 1.6 m apart
		var q28_x = TNBExhibition.new()
		q28_x.partner_ai = q28_ai
		q28_x.setup(content, [TNBSim.LINEUP_MILLBROOK[0], TNBSim.LINEUP_MILLBROOK[1]], 1, 7, TNBSim.parse_kizuna_arg(q28_kz), {}, "exhibition_2v2", q28_mgr)
		for q28_s in [q28_x.a, q28_x.b]: quiet(q28_s); place(q28_s, 1.6); q28_s.wall["B"] = {}
		q28_x.events.clear()
		return q28_x
	var q28_ev := func(q28_evs: Array, q28_k: String) -> Array:
		var q28_o: Array = []
		for q28_e in q28_evs:
			if str(q28_e["kind"]) == q28_k: q28_o.append(q28_e)
		return q28_o
	var q28_res := func(q28_x) -> void:                              # both casts through
		var q28_n := 0
		while (q28_x.a.cast.size() > 0 or q28_x.b.cast.size() > 0) and q28_n < 600: q28_x.step_pair({"block": false}, {}); q28_n += 1
	# the format and the setup: NP_01 s8 as the table has it (one segment, two dressed a side, simultaneous, NP_05 s7's 500 ms, the partner's
	# 250, no Golden DROP) and Lv4 Duo carrying "exhibition_duo"; the pad plays RORY against Yuri, PRIYA plays hers against Moreau on her
	# profile; each engagement holds the pair (his fighter first, the partner beside him - no reserves); one ledger (the same dictionaries);
	# the bond read in the ring - Adjacent Trust at Lv3 lifts both 5 % and takes 5 off the CHARGED threshold; the duo sync waits on Lv4; the
	# rotation formats untouched (the mini-dual still three slots), and F9 never cycles into the exhibition
	var q28_f: Dictionary = content["formats"]["formats"].get("exhibition_2v2", {})
	var q28a = q28_mk.call("RORY+PRIYA:50")
	var q28_rory: Dictionary = TNBSim.LINEUP_MILLBROOK[0]; var q28_pri: Dictionary = TNBSim.LINEUP_MILLBROOK[1]
	var q28_at: bool = absf(float(q28a.a.P["stats"]["PWR"]) - float(q28_rory["stats"]["PWR"]) * 1.05) < 0.001 and absf(float(q28a.b.P["stats"]["PWR"]) - float(q28_pri["stats"]["PWR"]) * 1.05) < 0.001
	var q28_mini := make_sim(1, 7)
	_sr("the Exhibition 2v2 as data and as set up: %s; the pad %s vs %s (%s), the partner %s vs %s (%s); lineups %s / %s; Adjacent Trust %s, CHARGED at %d; %s" % [JSON.stringify(q28_f), q28a.a.pname(), q28a.a.boss_name, "hands" if not q28a.a.delegated else "profile", q28a.b.pname(), q28a.b.boss_name, "profile" if q28a.b.delegated else "hands", JSON.stringify(q28a.a.lineup.map(func(c): return str(c["name"]))), JSON.stringify(q28a.b.lineup.map(func(c): return str(c["name"]))), str(q28_at), int(q28a.a._charged_threshold()), q28a.duo_line()],
		int(q28_f.get("segments", 0)) == 1 and int(q28_f.get("dressed", 0)) == 2 and int(q28_f.get("enemy_dressed", 0)) == 2 and bool(q28_f.get("simultaneous", false)) and int(q28_f.get("sync_ms", 0)) == 500 and int(q28_f.get("partner_answer_ms", 0)) == 250 and not bool(q28_f.get("sudden_death", true)) \
		and bool(content["economy"]["kizuna"]["effects"]["4"].get("exhibition_duo", false)) and q28a.level_need() == 4 \
		and q28a.a.pname() == "RORY" and q28a.a.boss_name == TNBSim.BOSSES[1] and not q28a.a.delegated and q28a.b.pname() == "PRIYA" and q28a.b.boss_name == TNBSim.BOSSES[2] and q28a.b.delegated \
		and q28a.a.lineup.map(func(c): return str(c["name"])) == ["RORY", "PRIYA"] and q28a.b.lineup.map(func(c): return str(c["name"])) == ["PRIYA", "RORY"] and q28a.a.reserves.is_empty() and q28a.a.segments() == 1 \
		and is_same(q28a.a.rewards, q28a.b.rewards) and is_same(q28a.a.pi, q28a.b.pi) and q28_at and int(q28a.a._charged_threshold()) == 20 \
		and q28a.duo_line() == "DUO SYNC: RORY & PRIYA Lv3 - it opens at Lv4" and q28a.eligible("RISE") == "RORY & PRIYA are Lv3 - the duo sync needs Lv4 Duo" \
		and q28_mini.segments() == 3 and q28_mini.lineup.size() == 3)
	# one bar, one bell, one ledger: RORY earns 10 and PRIYA 5 in their own engagements - the team's bar is 55 in both after the tick; the
	# enemy's 10 lands on the enemy's one bar; RORY frozen in his own hitstop for 10 ticks, the ring clock runs on PRIYA's and both read it;
	# XP paid in one engagement is the other's too (houseless +10 %)
	var q28b = q28_mk.call("", false)
	q28b.set_team(40.0); q28b.a._earn_tension(10.0); q28b.b._earn_tension(5.0); q28b.a._earn_tension_b(10.0); q28b.step_pair({}, {})
	var q28_bar: Array = [q28b.team, q28b.a.tension, q28b.b.tension, q28b.bteam, q28b.b.btension]
	var q28_c0: int = q28b.a.clock_t; q28b.a.freeze_t = 30
	for q28_i in 10: q28b.step_pair({}, {})
	var q28_clk: Array = [q28_c0 - q28b.a.clock_t, q28_c0 - q28b.b.clock_t, q28b.a.freeze_t]
	q28b.a._pay_xp("RORY", 12, "test")
	_sr("one bar, one bell, one ledger: the team's bar %s (40 + 10 + 5, both engagements), the enemy's %s; RORY in hitstop 10 ticks - the ring clock ran %s; RORY's XP read in PRIYA's engagement %d" % [JSON.stringify(q28_bar.slice(0, 3)), JSON.stringify(q28_bar.slice(3)), JSON.stringify(q28_clk), q28b.b.xp_of("RORY")],
		absf(float(q28_bar[0]) - 55.0) < 0.001 and float(q28_bar[1]) == float(q28_bar[0]) and float(q28_bar[2]) == float(q28_bar[0]) and absf(float(q28_bar[3]) - 10.0) < 0.001 and float(q28_bar[4]) == float(q28_bar[3]) \
		and int(q28_clk[0]) == 10 and int(q28_clk[1]) == 10 and int(q28_clk[2]) == 20 and q28b.b.xp_of("RORY") == int(round(12.0 * q28b.a._xp_mods("RORY") * float(content["economy"]["xp"].get("pace", 1.0)))) and q28b.b.xp_of("RORY") == q28b.a.xp_of("RORY"))
	# the duo sync (NP_05 s7): at Duo, both hands - RORY's LB + uppercut opens the window (the flick held, nothing thrown, both bars held);
	# PRIYA's same motion 400 ms on casts Double Overtime in both engagements, 50 off the bar once, each half carrying 25; it lands on both
	# opponents. At 600 ms: the window shut at 500 ms, RORY's flick thrown as his own (an uppercut - his move is no RISE), nothing spent, and
	# PRIYA's late motion opens her own window, which shuts in turn. The other way: PRIYA calls, RORY's left uppercut answers at 200 ms.
	# PRIYA on her profile answers at 250 ms. At Adjacent Trust (89) the
	# motion is RORY's own at once
	var q28c = q28_mk.call("RORY+PRIYA:90", false); q28c.set_team(100.0)
	q28c.step_pair({"lb": true, "punch": "R_UPPERCUT"}, {})
	var q28_open: Array = [str(q28c.window.get("fam", "")), str(q28c.window.get("move", "")), q28c.a.cast.is_empty(), count_events(q28c.a.events, "punch"), q28c.a.bar_hold and q28c.b.bar_hold]
	for q28_i in 47: q28c.step_pair({}, {})
	q28c.step_pair({}, {"lb": true, "punch": "R_UPPERCUT"})
	var q28_dc: Array = q28_ev.call(q28c.events, "duo_cast")
	var q28_both: Array = [str(q28c.a.cast.get("move", {}).get("name", "")), str(q28c.b.cast.get("move", {}).get("name", "")), str(q28c.a.cast.get("move", {}).get("duo_sync", "")), float(q28c.a.cast.get("cost", 0.0)), float(q28c.b.cast.get("cost", 0.0)), q28c.team, q28c.a.tension, q28c.b.tension]
	var q28_ca: float = float(q28c.a.B["comp"]); var q28_cb: float = float(q28c.b.B["comp"])
	q28_res.call(q28c)
	var q28_hit: Array = [q28_ca - float(q28c.a.B["comp"]), q28_cb - float(q28c.b.B["comp"]), count_events(q28c.a.events, "hit", {"move": "Double Overtime"}), count_events(q28c.b.events, "hit", {"move": "Double Overtime"})]
	var q28d = q28_mk.call("RORY+PRIYA:90", false); q28d.set_team(100.0)
	q28d.step_pair({"lb": true, "punch": "R_UPPERCUT"}, {})
	for q28_i in 71: q28d.step_pair({}, {})
	q28d.step_pair({}, {"lb": true, "punch": "R_UPPERCUT"})
	var q28_late_w: String = str(q28d.window.get("first", ""))
	for q28_i in 80: q28d.step_pair({}, {})
	var q28_miss: Array = q28_ev.call(q28d.events, "duo_missed")
	var q28_rp: Array = q28_ev.call(q28d.a.events, "punch")
	var q28h = q28_mk.call("RORY+PRIYA:90", false); q28h.set_team(100.0)                                   # the other way: PRIYA calls, RORY answers 200 ms on
	q28h.step_pair({}, {"lb": true, "punch": "R_UPPERCUT"})
	for q28_i in 23: q28h.step_pair({}, {})
	q28h.step_pair({"lb": true, "punch": "L_UPPERCUT"}, {})
	var q28_ow: Array = q28_ev.call(q28h.events, "duo_cast")
	var q28e = q28_mk.call("RORY+PRIYA:90"); q28e.set_team(100.0)
	q28e.step({"lb": true, "punch": "R_UPPERCUT"})
	for q28_i in 40: q28e.step({})
	var q28_ai: Array = q28_ev.call(q28e.events, "duo_cast")
	var q28g = q28_mk.call("RORY+PRIYA:89"); q28g.set_team(100.0)
	q28g.step({"lb": true, "punch": "R_UPPERCUT"})
	var q28_lv3: Array = [q28g.window.is_empty(), count_events(q28g.a.events, "punch", {"row": "R_UPPERCUT"}), q28g.events.size()]
	_sr("the duo sync: RORY's motion %s; PRIYA's at 400 ms %s -> %s, the bar %s; it lands %s; at 600 ms %s (RORY's flick thrown %s), her late window '%s'; the other way %s; on her profile %s; at Adjacent Trust %s" % [JSON.stringify(q28_open), JSON.stringify(q28_dc), JSON.stringify(q28_both.slice(0, 5)), JSON.stringify(q28_both.slice(5)), JSON.stringify(q28_hit), JSON.stringify(q28_miss.map(func(m): return "%s t%d" % [str(m["why"]), int(m["t"])])), JSON.stringify(q28_rp.map(func(p): return "%s@%d" % [str(p["row"]), int(p["tick"])])), q28_late_w, JSON.stringify(q28_ow), JSON.stringify(q28_ai), JSON.stringify(q28_lv3)],
		str(q28_open[0]) == "RISE" and str(q28_open[1]) == "Double Overtime" and bool(q28_open[2]) and int(q28_open[3]) == 0 and bool(q28_open[4]) \
		and q28_dc.size() == 1 and str(q28_dc[0]["by"]) == "hands" and int(q28_dc[0]["ms"]) == 400 and str(q28_dc[0]["move"]) == "Double Overtime" \
		and str(q28_both[0]) == "Double Overtime" and str(q28_both[1]) == "Double Overtime" and str(q28_both[2]) == "PRIYA|RORY" and float(q28_both[3]) == 25.0 and float(q28_both[4]) == 25.0 \
		and absf(float(q28_both[5]) - 50.0) < 0.001 and float(q28_both[6]) == float(q28_both[5]) and float(q28_both[7]) == float(q28_both[5]) \
		and float(q28_hit[0]) > 0.0 and float(q28_hit[1]) > 0.0 and int(q28_hit[2]) == 1 and int(q28_hit[3]) == 1 \
		and q28_miss.size() == 2 and str(q28_miss[0]["why"]) == "PRIYA never answered inside 500 ms" and str(q28_miss[1]["why"]) == "RORY never answered inside 500 ms" and q28_ev.call(q28d.events, "duo_cast").is_empty() \
		and q28_rp.size() >= 1 and str(q28_rp[0]["row"]) == "R_UPPERCUT" and int(q28_rp[0]["tick"]) == 62 and q28_late_w == "B" and absf(q28d.team - 100.0) < 0.001 \
		and q28_ow.size() == 1 and str(q28_ow[0]["first"]) == "B" and str(q28_ow[0]["by"]) == "hands" and int(q28_ow[0]["ms"]) == 200 \
		and q28_ai.size() == 1 and str(q28_ai[0]["by"]) == "ai" and int(q28_ai[0]["ms"]) == 250 \
		and bool(q28_lv3[0]) and int(q28_lv3[1]) == 1 and int(q28_lv3[2]) == 0)
	# Two-Hand Winter, "the only shared gauge in the game": RORY holds LB + block 400 ms - the hold the coordinator's (his own wall motion never
	# counts past a tick), the window opens; PRIYA's profile answers; both cast it, the bar pays once; resolved, ONE wall dictionary behind both - owned by
	# the pair that raised it first; a body hook on PRIYA chips the gauge RORY stands behind, her composure untouched; broken from RORY's side,
	# its TRUE OPEN runs once a tick (its owner's clock, not twice); RORY's pair KO'd, PRIYA's runs it
	var q28w = q28_mk.call("RORY+PRIYA:90"); q28w.set_team(100.0)
	for q28_i in 48: q28w.step({"lb": true, "block": true})
	var q28_wo: Array = [str(q28w.window.get("fam", "")), int(q28w.a.lb_block_t), q28w.a.cast.is_empty()]
	for q28_i in 40: q28w.step({"lb": true, "block": true})
	var q28_wc: Array = q28_ev.call(q28w.events, "duo_cast")
	var q28_wcast: Array = [str(q28w.a.cast.get("move", {}).get("name", "")), str(q28w.b.cast.get("move", {}).get("name", "")), q28w.team]
	q28_res.call(q28w)
	var q28_ww: Dictionary = q28w.a.wall["P"]
	var q28_wl: Array = [is_same(q28_ww, q28w.b.wall["P"]), str(q28_ww.get("shared", "")), float(q28_ww.get("pts", 0.0)), q28_ev.call(q28w.events, "duo_wall_linked").size()]
	clear_defense(q28w.b.P); place(q28w.b, 1.4); var q28_pc: float = float(q28w.b.P["comp"])
	boss_lands(q28w.b, "R_HOOK", 1.0, true)
	var q28_chip: Array = [float(q28_wl[2]) - float(q28w.a.wall["P"].get("pts", 0.0)), float(q28w.b.P["comp"]) == q28_pc]
	q28w.a.wall["P"]["pts"] = 1.0; clear_defense(q28w.a.P); place(q28w.a, 1.4)
	boss_lands(q28w.a, "R_HOOK", 1.0, true); q28w.a.freeze_t = 0; q28w.b.freeze_t = 0
	var q28_open_t: int = int(q28w.b.wall["P"].get("open_t", 0))
	for q28_i in 10: q28w.step({})
	var q28_brk: Array = [q28_open_t, q28_open_t - int(q28w.b.wall["P"].get("open_t", 0)), int(q28w.a.wall["P"].get("breaks", 0))]
	var q28_ot1: int = int(q28w.b.wall["P"].get("open_t", 0))
	q28w.a._segment_ko(false, "three knockdowns"); q28w.step({}); q28w.b.freeze_t = 0
	for q28_i in 10: q28w.step({})
	q28_brk.append(str(q28w.b.wall["P"].get("shared", ""))); q28_brk.append(q28_ot1 - int(q28w.b.wall["P"].get("open_t", 0)))
	_sr("Two-Hand Winter: the hold %s; %s -> %s; the gauge %s; a body hook on PRIYA chips %.2f off it (her composure untouched %s); broken from RORY's side %s" % [JSON.stringify(q28_wo), JSON.stringify(q28_wc), JSON.stringify(q28_wcast), JSON.stringify(q28_wl), float(q28_chip[0]), str(q28_chip[1]), JSON.stringify(q28_brk)],
		str(q28_wo[0]) == "WALL" and int(q28_wo[1]) <= 1 and bool(q28_wo[2]) and q28_wc.size() == 1 and str(q28_wc[0]["move"]) == "Two-Hand Winter" and str(q28_wc[0]["by"]) == "ai" \
		and str(q28_wcast[0]) == "Two-Hand Winter" and str(q28_wcast[1]) == "Two-Hand Winter" and absf(float(q28_wcast[2]) - 50.0) < 0.001 \
		and bool(q28_wl[0]) and str(q28_wl[1]) == "A" and float(q28_wl[2]) >= 30.0 and int(q28_wl[3]) == 1 and float(q28_chip[0]) > 0.0 and bool(q28_chip[1]) \
		and int(q28_brk[0]) == TNBSim.ms(8000) and int(q28_brk[1]) == 10 and int(q28_brk[2]) == 1 and str(q28_brk[3]) == "B" and int(q28_brk[4]) >= 10 and int(q28_brk[4]) <= 11)
	# the verdict and the pay: PRIYA's pair KO'd - it stands at 0-3 while RORY fights on under the ring clock; a DualState of the whole
	# exhibition mid-flight restores on the same hash (the ledger one again) and runs on identically; RORY's pair ends on the bell: the ladder
	# on the sums (0-3: ASCENDANT) and ONE pay (one toast, the pair's Kizuna +5 once, 5 Spirits once, the closing 40 (+10 % houseless) to both); F5 again, the
	# ledger carried. The pad: \ hands it to PRIYA (RORY to his profile); her pair KO'd hands it back. The manager's seat: both on their
	# profiles, the bar at 95 - they call Double Overtime
	var q28v = q28_mk.call("RORY+PRIYA:90", false)
	q28v.b._segment_ko(false, "three knockdowns"); q28v.step_pair({}, {})
	var q28_ko: Array = [q28v.b.mode, q28v.a.mode, q28v.over, q28_ev.call(q28v.b.events, "engagement_end").size()]
	var q28_snap: Dictionary = q28v.snapshot()
	for q28_i in 120: q28v.step_pair({}, {})
	var q28_h1: int = q28v.hash_state()
	var q28_ro: Dictionary = q28v.restore(q28_snap)
	var q28_rl: bool = is_same(q28v.a.rewards, q28v.b.rewards)
	for q28_i in 120: q28v.step_pair({}, {})
	var q28_rs: Array = [bool(q28_ro.get("ok", false)), bool(q28_ro.get("same", false)), q28_rl, q28v.hash_state() == q28_h1]
	var q28_xp0: Array = [q28v.a.xp_of("RORY"), q28v.a.xp_of("PRIYA")]
	q28v.a.clock_t = 2
	for q28_i in 4: q28v.step_pair({}, {})
	var q28_pay: Array = [q28v.over, str(q28v.verdict.get("verdict", "")), str(q28v.verdict.get("rung", "")), count_events(q28v.a.events, "reward_toast"), count_events(q28v.b.events, "reward_toast"), int(q28v.a.rewards["kizuna"].get("PRIYA|RORY", 0)), int(q28v.a.rewards["spirits"]), q28v.a.xp_of("RORY") - int(q28_xp0[0]), q28v.a.xp_of("PRIYA") - int(q28_xp0[1])]
	q28v.step_pair({"restart": true}, {})
	var q28_again: Array = [q28v.over, q28v.a.mode, q28v.b.mode, is_same(q28v.a.rewards, q28v.b.rewards), int(q28v.b.rewards["kizuna"].get("PRIYA|RORY", 0))]
	var q28s = q28_mk.call("RORY+PRIYA:90"); q28s.swap_control()
	var q28_sw: Array = [q28s.ctrl, q28s.ctrl_sim().pname(), q28s.a.delegated, q28s.b.delegated]
	q28s.b._segment_ko(false, "counted out"); q28s.step({})
	var q28_hand: Array = [q28s.ctrl, q28s.a.delegated, q28_ev.call(q28s.events, "control").size()]
	var q28m = q28_mk.call("RORY+PRIYA:90", true, true); q28m.set_team(95.0); q28m.step({})
	var q28_mg: Array = q28_ev.call(q28m.events, "duo_cast")
	_sr("the verdict and the pay: PRIYA's pair KO'd %s; the DualState %s; on the bell %s; again %s; the pad %s, handed back %s; the manager's seat %s" % [JSON.stringify(q28_ko), JSON.stringify(q28_rs), JSON.stringify(q28_pay), JSON.stringify(q28_again), JSON.stringify(q28_sw), JSON.stringify(q28_hand), JSON.stringify(q28_mg)],
		str(q28_ko[0]) == "OVER" and str(q28_ko[1]) == "FIGHT" and not bool(q28_ko[2]) and int(q28_ko[3]) == 1 \
		and bool(q28_rs[0]) and bool(q28_rs[1]) and bool(q28_rs[2]) and bool(q28_rs[3]) \
		and bool(q28_pay[0]) and str(q28_pay[1]) == "ASCENDANT WINS THE EXHIBITION" and str(q28_pay[2]) == "score" and int(q28_pay[3]) == 1 and int(q28_pay[4]) == 0 \
		and int(q28_pay[5]) == 90 + int(content["economy"]["kizuna"]["adjacent_slots"]) and int(q28_pay[6]) == int(content["economy"]["spirits"]["dual_fought"]) \
		and int(q28_pay[7]) >= int(q28_pay[8]) and int(q28_pay[8]) == int(round(float(content["economy"]["xp"]["dual_lost"]) * q28v.a._xp_mods("PRIYA") * float(content["economy"]["xp"].get("pace", 1.0)))) \
		and not bool(q28_again[0]) and str(q28_again[1]) == "FIGHT" and str(q28_again[2]) == "FIGHT" and bool(q28_again[3]) and int(q28_again[4]) == int(q28_pay[5]) \
		and str(q28_sw[0]) == "B" and str(q28_sw[1]) == "PRIYA" and bool(q28_sw[2]) and not bool(q28_sw[3]) \
		and str(q28_hand[0]) == "A" and not bool(q28_hand[1]) and int(q28_hand[2]) == 2 \
		and q28_mg.size() == 1 and str(q28_mg[0]["by"]) == "manager" and str(q28_mg[0]["move"]) == "Double Overtime")

	# ---- PAC-089: CLUB FACILITIES (NP_10 s7) ----
	var q29_fac: Dictionary = content["facilities"]
	var q29_led := func(q29_f: String, q29_pu: String = "", q29_fl: String = "", q29_kz: String = "") -> Dictionary:
		return TNBSim.seed_facilities(TNBSim.seed_purse(TNBSim.seed_story(TNBSim.parse_kizuna_arg(q29_kz), q29_fl), q29_pu), q29_f, q29_fac)
	var q29_mk := func(q29_f: String, q29_pu: String = "", q29_fl: String = "", q29_kz: String = "", q29_boss: int = 1, q29_pi: Dictionary = {}) -> TNBSim:
		return make_sim(q29_boss, 7, TNBSim.LINEUP_MILLBROOK, "", q29_pi, q29_led.call(q29_f, q29_pu, q29_fl, q29_kz))
	var q29_ev := func(q29_evs: Array, q29_k: String) -> Array:
		var q29_o: Array = []
		for q29_e in q29_evs:
			if str(q29_e["kind"]) == q29_k: q29_o.append(q29_e)
		return q29_o
	var q29_all := "story:charter_saved,quest:gym_funding,story:nationals"
	# the table and the renovation: NP_10 s7's five tracks, each T1 -> T3 at one price and story gate a tier, the club at T0 everywhere; a
	# renovation refused for each reason - the story's gate, the price, the bell rung, the top, no such track - and paid: the ledger down,
	# the tier up, its event and the photograph on the Gym Wall; "*" the first ready; the save's Club.facility_tiers, written back byte-equal
	var q29a : TNBSim = q29_mk.call("")
	var q29_t: Array = [q29_fac.get("order", []), int(q29_fac.get("start_tier", -1)), [int(q29_fac["tiers"]["1"]["hbp"]), int(q29_fac["tiers"]["1"]["spirits"]), str(q29_fac["tiers"]["1"]["story"])], [int(q29_fac["tiers"]["2"]["hbp"]), int(q29_fac["tiers"]["2"]["spirits"]), str(q29_fac["tiers"]["2"]["story"])], [int(q29_fac["tiers"]["3"]["hbp"]), int(q29_fac["tiers"]["3"]["spirits"]), str(q29_fac["tiers"]["3"]["story"])], q29a.facility_tiers()]
	var q29_r: Array = [q29a.renovate_why("bags_mitts")]
	var q29b : TNBSim = q29_mk.call("", "", q29_all); q29_r.append(q29b.renovate_why("bags_mitts"))
	var q29c : TNBSim = q29_mk.call("", "hbp:2000,spirits:100", q29_all); q29c.events.clear()
	var q29_ok: Dictionary = q29c.renovate("bags")
	var q29_paid: Array = [bool(q29_ok["ok"]), q29c.fac_tier("bags_mitts"), int(q29c.rewards["hbp"]), int(q29c.rewards["spirits"]), q29_ev.call(q29c.events, "renovated").size(), q29c.gym_wall["decos"].filter(func(d): return str(d["kind"]) == "renovation").map(func(d): return str(d["label"]))]
	q29c.renovate("bags"); q29c.renovate("bags"); q29_r.append(q29c.renovate_why("bags_mitts")); q29_r.append(str(q29c.renovate("nowhere")["why"]))
	var q29_star: Dictionary = q29c.renovate("*")
	var q29d : TNBSim = q29_mk.call("", "hbp:1000,spirits:50", q29_all); q29d.step({}); q29_r.append(q29d.renovate_why("the_ring"))
	var q29_sv: Dictionary = TNBSave.to_save(q29c)
	var q29_back = TNBSave.build(content, TNBSave.read(JSON.parse_string(JSON.stringify(q29_sv))), 99)["sim"]
	var q29_save: Array = [q29_sv["club"].get("facility_tiers", {}), q29_back.facility_tiers() == q29c.facility_tiers(), JSON.stringify(TNBSave.to_save(q29_back)) == JSON.stringify(q29_sv)]
	_sr("club facilities as data (NP_10 s7): %s; refused %s; paid %s; '*' %s; the save %s" % [JSON.stringify(q29_t), JSON.stringify(q29_r), JSON.stringify(q29_paid), JSON.stringify(q29_star), JSON.stringify(q29_save)],
		q29_t[0] == ["bags_mitts", "the_ring", "film_room", "the_wall", "front_of_house"] and int(q29_t[1]) == 0 and q29_t[2] == [150, 5, "story:charter_saved"] and q29_t[3] == [400, 15, "quest:gym_funding"] and q29_t[4] == [800, 30, "story:nationals"] \
		and q29_t[5] == {"bags_mitts": 0, "the_ring": 0, "film_room": 0, "the_wall": 0, "front_of_house": 0} \
		and str(q29_r[0]) == "Bags & Mitts T1 waits on the story - the charter saved (NP_12 s4 beat 2: the Survival Dual) (story:charter_saved)" and str(q29_r[1]) == "Bags & Mitts T1 costs 150 HBP and 5 Spirits (the ledger holds 0 and 0)" \
		and bool(q29_paid[0]) and int(q29_paid[1]) == 1 and int(q29_paid[2]) == 1850 and int(q29_paid[3]) == 95 and int(q29_paid[4]) == 1 and q29_paid[5] == ["Bags & Mitts T1 - the bags rehung: Mitts and the Heavy Bag open"] \
		and str(q29_r[2]) == "Bags & Mitts is at T3, the top" and str(q29_r[3]) == "no facility 'nowhere'" and str(q29_r[4]) == "the renovations are between duals" \
		and str(q29_star.get("track", "")) == "the_ring" and int(q29_star.get("tier", 0)) == 1 \
		and q29_save[0] == {"bags_mitts": 3, "the_ring": 1, "film_room": 0, "the_wall": 0, "front_of_house": 0} and bool(q29_save[1]) and bool(q29_save[2]))
	# Bags & Mitts (NP_11 s7): as found, Roadwork (grade 0.5: 4 Beans) and nothing of the gym's - Mitts refused, Net Haul waiting on the
	# harbour's quest (then 8 at grade 1); three slots a day, the fourth refused, a new day open again; Roadwork with PRIYA along bonds +3;
	# at T2 the Slip Bag at x1.25 (grade 0.5: 8) and Mitts 6; at T3 Shadow Rounds refused with an empty Scout Book, and with Yuri's page
	# 15 Beans against his ghost; two of them fill the jar the Forge spends (with The Wall at T3): YURI & MARTA forge on trained Beans
	var q29g : TNBSim = q29_mk.call("")
	var q29_b0: Array = [int(q29g.train("roadwork", "RORY", 0.5)["beans"]), str(q29g.train("mitts", "RORY", 0.5)["why"]), str(q29g.train("net_haul", "RORY", 1.0)["why"])]
	var q29h : TNBSim = q29_mk.call("", "", "quest:macisaac_harbour"); q29_b0.append(int(q29h.train("net_haul", "PRIYA", 1.0).get("beans", 0)))
	q29h.train("roadwork", "RORY", 0.0, "PRIYA"); q29h.train("roadwork", "MARCUS", 0.0)
	var q29_day: Array = [str(q29h.train("roadwork", "JUNE", 0.0)["why"]), int(q29h.rewards["kizuna"].get("PRIYA|RORY", 0)), int(q29h.rewards["beans"])]
	q29h.new_day(); q29_day.append(bool(q29h.train("roadwork", "JUNE", 0.0)["ok"]))
	var q29i : TNBSim = q29_mk.call("bags:2")
	var q29_b2: Array = [int(q29i.train("slip_bag", "RORY", 0.5)["beans"]), int(q29i.train("mitts", "RORY", 0.5)["beans"]), str(q29i.train("shadow_rounds", "RORY", 1.0)["why"])]
	var q29_8: Array = []
	for q29_c in TNBSim.LINEUP_MILLBROOK_8: var q29_cc: Dictionary = q29_c.duplicate(true); q29_cc.erase("reserve"); q29_8.append(q29_cc)
	var q29j := make_sim(1, 7, q29_8, "", TNBSim.parse_pi_arg("yuri_kowalchuk:3", content["pattern_intel"]), q29_led.call("bags:3,wall:3", "spirits:40", "", "YURI+MARTA:150")); q29j.events.clear()
	var q29_b3: Array = [str(q29j.forge_why("YURI", "MARTA")), str(q29j.train("shadow_rounds", "RORY", 1.0).get("beans", 0)), str(q29_ev.call(q29j.events, "training")[0].get("pattern", "")), int(q29j.train("shadow_rounds", "PRIYA", 1.0).get("beans", 0))]
	var q29_fg: Dictionary = q29j.forge("YURI", "MARTA")
	q29_b3.append(bool(q29_fg["ok"])); q29_b3.append(int(q29j.rewards["beans"]))
	_sr("Bags & Mitts: as found %s, the harbour %d; the day %s; at T2 %s; at T3 %s (the Forge on trained Beans, the jar after)" % [JSON.stringify(q29_b0.slice(0, 3)), int(q29_b0[3]), JSON.stringify(q29_day), JSON.stringify(q29_b2), JSON.stringify(q29_b3)],
		int(q29_b0[0]) == 4 and str(q29_b0[1]) == "Mitts needs Bags & Mitts T1 (the gym's is T0)" and str(q29_b0[2]) == "Net Haul opens with quest:macisaac_harbour" and int(q29_b0[3]) == 8 \
		and str(q29_day[0]) == "the day's 3 training slots are used (day 1)" and int(q29_day[1]) == 3 and int(q29_day[2]) == 14 and bool(q29_day[3]) \
		and int(q29_b2[0]) == 8 and int(q29_b2[1]) == 6 and str(q29_b2[2]) == "Shadow Rounds needs Bags & Mitts T3 (the gym's is T2)" \
		and str(q29_b3[0]) == "the Forge costs 40 Spirits and 30 Beans (the ledger holds 40 and 0)" and str(q29_b3[1]) == "15" and str(q29_b3[2]) == "yuri_kowalchuk" and int(q29_b3[3]) == 15 and bool(q29_b3[4]) and int(q29_b3[5]) == 0)
	# The Ring: as found the lab flags you choose are off (the spar runs without them, the refusal named) while the Priya trial keeps its
	# authored one; at T1 they run; the ranked spar board refused at T2, open at T3 (RANKED SPAR); the Exhibition 2v2 at home refused at
	# T1 (the festival instead, named), hosted at T2 - both engagements at home
	var q29k : TNBSim = q29_mk.call(""); q29k.events.clear(); q29k.start_spar(1, ["tell_highlight", "infinite_stamina"])
	var q29_lab: Array = [q29k.bout.get("flags", []), str(q29_ev.call(q29k.events, "lab_refused")[0].get("why", "")) if q29_ev.call(q29k.events, "lab_refused").size() > 0 else ""]
	var q29l : TNBSim = q29_mk.call(""); q29l.start_ep1("priya_trial"); q29_lab.append(q29l.bout.get("flags", []))
	var q29m : TNBSim = q29_mk.call("ring:1"); q29m.start_spar(1, ["tell_highlight", "infinite_stamina"]); q29_lab.append(q29m.bout.get("flags", []))
	var q29n : TNBSim = q29_mk.call("ring:2"); q29n.events.clear(); var q29_rk: Array = [q29n.start_spar(1, [], {}, "", "", {"venue": "ranked"}), str(q29_ev.call(q29n.events, "spar_refused")[0].get("why", "")) if q29_ev.call(q29n.events, "spar_refused").size() > 0 else ""]
	var q29o : TNBSim = q29_mk.call("ring:3"); q29_rk.append(q29o.start_spar(1, [], {}, "", "", {"venue": "ranked"})); q29_rk.append(str(q29o.bout.get("label", ""))); q29_rk.append(str(q29o.bout.get("venue", "")))
	var q29_ex: Array = []
	for q29_rt in ["ring:1", "ring:2"]:
		var q29_x = TNBExhibition.new()
		q29_x.setup(content, [TNBSim.LINEUP_MILLBROOK[0], TNBSim.LINEUP_MILLBROOK[1]], 1, 7, q29_led.call(q29_rt), {}, "exhibition_2v2", false, "home")
		var q29_hr: Array = q29_ev.call(q29_x.events, "hosting_refused")
		q29_ex.append([q29_x.venue, q29_x.a.host, q29_x.b.host, str(q29_hr[0]["why"]) if q29_hr.size() > 0 else "", str(q29_x.lines()[0]).substr(0, 26)])
	_sr("The Ring: the lab as found %s, the Priya trial %s, at T1 %s; the ranked board %s; the exhibition at home %s" % [JSON.stringify(q29_lab.slice(0, 2)), JSON.stringify(q29_lab[2]), JSON.stringify(q29_lab[3]), JSON.stringify(q29_rk), JSON.stringify(q29_ex)],
		q29_lab[0] == [] and str(q29_lab[1]) == "the lab flags are The Ring's (T1) - the gym's ring is at T0" and q29_lab[2] == ["tell_highlight"] and q29_lab[3] == ["tell_highlight", "infinite_stamina"] \
		and not bool(q29_rk[0]) and str(q29_rk[1]) == "the ranked spar board is The Ring's (T3) - the gym's ring is at T2" and bool(q29_rk[2]) and str(q29_rk[3]) == "RANKED SPAR" and str(q29_rk[4]) == "ranked" \
		and q29_ex[0] == ["festival", false, false, "the Exhibition 2v2 is hosted at The Ring (T2) - the gym's ring is at T1: the festival's boardwalk instead", "EXHIBITION 2v2 (festival) "] \
		and q29_ex[1] == ["home", true, true, "", "EXHIBITION 2v2 (at home)  "])
	# Film Room: as found the Scout Book's shelf holds 6 pages - the seventh boss beaten waits (his PI 3 and his page with it, the save's 6
	# pages), and the Film Room's T1 shelves it; a seeded ledger of eight pages shelves six; the grind at T2 (PI 1 from 2 scraps, PI 2
	# from 4, 2 spars) against T1's 3; the tape: Vey's corner's decoy read on sight at T3 once it has been run on the club - not before,
	# not at T2 - and the dual's end puts it on the tape
	var q29p : TNBSim = q29_mk.call("", "hbp:500,spirits:20", q29_all); q29p.events.clear()
	for q29_i in 7: q29p._pi_beaten(TNBSim.BOSSES[q29_i])
	var q29_bk: Array = [q29p.pi.get("book", []).size(), q29p.pi.get("waiting", []).duplicate(), q29p.pi_boss(TNBSim.BOSSES[6]), q29p.pi_boss(TNBSim.BOSSES[0]), q29p.scout_page(TNBSim.BOSSES[6]).is_empty(), q29_ev.call(q29p.events, "page_waiting").size(), TNBSave.to_save(q29p)["scout_book"]["pages"].size()]
	q29p.renovate("film")
	q29_bk.append_array([q29p.pi_boss(TNBSim.BOSSES[6]), q29_ev.call(q29p.events, "page_shelved").size(), q29p.book_pages()])
	var q29q : TNBSim = q29_mk.call("", "", "", "", 1, TNBSim.parse_pi_arg(",".join(PackedStringArray(TNBSim.BOSSES.slice(0, 8).map(func(b): return "%s:3" % b))), content["pattern_intel"]))
	q29_bk.append([q29q.pi["book"].size(), q29q.pi["waiting"].size()])
	var q29_gr: Array = []
	for q29_ft in ["film:1", "film:2"]:
		var q29_gs : TNBSim = q29_mk.call(q29_ft)
		for q29_i in 2: q29_gs._pi_tick("scraps", "kowalchuk")
		var q29_l2 := q29_gs.pi_level("kowalchuk")
		for q29_i in 2: q29_gs._pi_tick("scraps", "kowalchuk")
		var q29_l4 := q29_gs.pi_level("kowalchuk")
		for q29_i in 2: q29_gs._pi_tick("spars", "tremblay")
		q29_gr.append([q29_l2, q29_l4, q29_gs.pi_level("tremblay")])
	var q29_tp: Array = []
	for q29_ft2 in ["film:3", "film:2"]:
		var q29_ts : TNBSim = q29_mk.call(q29_ft2, "", "", "", 6); q29_ts.bdecoy = true
		var q29_p0: Dictionary = q29_ts._projection_live()
		q29_ts.score_p = 1; q29_ts._end_dual()
		var q29_p1: Dictionary = q29_ts._projection_live()
		q29_tp.append([bool(q29_p0["detected"]), int(q29_ts.rewards.get("tape", {}).get(str(q29_ts.coach.get("id", "")), 0)), bool(q29_p1["detected"]), q29_p1["sources"].filter(func(x): return str(x["source"]) == "tape").size()])
	_sr("Film Room: the shelf %s; a seeded eight %s; the grind at T1 / T2 %s; the tape at T3 / T2 %s" % [JSON.stringify(q29_bk.slice(0, 10)), JSON.stringify(q29_bk[10]), JSON.stringify(q29_gr), JSON.stringify(q29_tp)],
		int(q29_bk[0]) == 6 and q29_bk[1] == [TNBSim.BOSSES[6]] and int(q29_bk[2]) == 0 and int(q29_bk[3]) == 3 and bool(q29_bk[4]) and int(q29_bk[5]) == 1 and int(q29_bk[6]) == 6 \
		and int(q29_bk[7]) == 3 and int(q29_bk[8]) == 1 and int(q29_bk[9]) == 12 and q29_bk[10] == [6, 2] \
		and q29_gr[0] == [0, 1, 1] and q29_gr[1] == [1, 2, 2] \
		and q29_tp[0] == [false, 1, true, 1] and q29_tp[1] == [false, 1, false, 0])
	# The Wall and Front of House: a stable of 34 cards on the 8 x 4 wall leaves 2 unpinned; The Wall's T1 hangs them in its new columns;
	# at T1 a blessed house's crest and a feat go up nowhere, T2's honours set hangs both (once - a second feat of the kind adds none); the
	# Forge refused at T2. The entrance at the bell: none as found, the sting at T1, the three pieces and the Reyes bell at T3; a hosted
	# dual's crowd from the bell at T2 (20; away 0; at T1 0); a hosted dual pays 5 Prestige at T3 (the toast says so; away none)
	var q29_34: Array = []
	for q29_i in 34:
		var q29_c34: Dictionary = TNBSim.LINEUP_MILLBROOK[q29_i % 3].duplicate(true); q29_c34["name"] = "C%02d" % q29_i; q29_c34.erase("reserve"); q29_34.append(q29_c34)
	var q29w := make_sim(1, 7, q29_34, "", {}, q29_led.call("", "hbp:2000,spirits:100", q29_all + ",blessing:moreau")); q29w.events.clear()
	var q29_wl: Array = [q29w.gym_wall["unpinned"].duplicate(), q29w._gw_grid().x]
	q29w.renovate("wall")
	q29_wl.append_array([q29w.gym_wall["unpinned"].size(), q29w._gw_grid().x, q29w.gym_wall["cards"].get("C33", [])])
	q29w._feat("stood_in_the_storm", "ioan_vasile")
	var q29_hon := func(q29_s: TNBSim) -> Array: return q29_s.gym_wall["decos"].filter(func(d): return str(d["kind"]) in ["crest", "feat"]).map(func(d): return str(d["label"]))
	q29_wl.append(q29_hon.call(q29w))
	q29w.renovate("wall"); q29_wl.append(q29_hon.call(q29w))
	q29w._feat("stood_in_the_storm", "ioan_vasile"); q29_wl.append(q29_hon.call(q29w).size())
	var q29f2 := make_sim(1, 7, q29_8, "", {}, q29_led.call("wall:2", "spirits:40,beans:30", "", "YURI+MARTA:150")); q29_wl.append(q29f2.forge_why("YURI", "MARTA"))
	var q29_en: Array = []
	for q29_ef in [["", ""], ["foh:1", ""], ["foh:3", "quest:the_bell"]]:
		var q29_es : TNBSim = q29_mk.call(str(q29_ef[0]), "", str(q29_ef[1]))
		var q29_ee: Array = q29_ev.call(q29_es.events, "entrance")
		q29_en.append(q29_ee[0]["set"] if q29_ee.size() > 0 else [])
	var q29_cr: Array = []
	for q29_cf in [["foh:2", true], ["foh:2", false], ["foh:1", true]]:
		var q29_cs : TNBSim = q29_mk.call(str(q29_cf[0])); q29_cs.set_host(bool(q29_cf[1])); q29_cr.append(q29_cs.crowd_heat)
	var q29_pr: Array = []
	for q29_pf in [true, false]:
		var q29_ps : TNBSim = q29_mk.call("foh:3"); q29_ps.set_host(q29_pf); q29_ps.score_p = 1; q29_ps._end_dual()
		q29_pr.append([int(q29_ps.rewards["prestige"]), str(q29_ps.last_toast.get("text", "")).ends_with(", +5 Prestige (hosted)")])
	_sr("The Wall and Front of House: the wall %s; the Forge at T2 '%s'; the entrance %s; a hosted crowd %s; the hosted Prestige %s" % [JSON.stringify(q29_wl.slice(0, 8)), str(q29_wl[8]), JSON.stringify(q29_en), JSON.stringify(q29_cr), JSON.stringify(q29_pr)],
		q29_wl[0] == ["C32", "C33"] and int(q29_wl[1]) == 8 and int(q29_wl[2]) == 0 and int(q29_wl[3]) == 10 and q29_wl[4] == [9, 0] and q29_wl[5] == [] \
		and q29_wl[6] == ["House Moreau's crest", "Stood in the Storm - ioan_vasile"] and int(q29_wl[7]) == 2 and str(q29_wl[8]) == "the Forge is hosted at The Wall (T3) - the gym's wall is at T2" \
		and q29_en[0] == [] and q29_en[1] == ["music sting"] and q29_en[2] == ["music sting", "banner", "crowd chant", "La Campana (NP_07A: the Reyes bell at your entrances)"] \
		and q29_cr == [20.0, 0.0, 0.0] and q29_pr[0] == [5, true] and q29_pr[1] == [0, false])

	# ---- PAC-090: THE FIGHTER'S GROWTH (NP_11 s3, s4, s6, s7) ----
	var q30_g: Dictionary = content["growth"]
	var q30_mk := func(q30_lv: String, q30_extra: Dictionary = {}, q30_fac: String = "", q30_pu: String = "", q30_gr: String = "", q30_bn: String = "") -> TNBSim:
		var q30_l: Dictionary = TNBSim.seed_beans(TNBSim.seed_growth(TNBSim.seed_facilities(TNBSim.seed_purse(TNBSim.seed_levels({}, q30_lv, content["economy"]), q30_pu), q30_fac, content["facilities"]), q30_gr), q30_bn)
		for q30_k in q30_extra: q30_l[q30_k] = q30_extra[q30_k]
		var q30_s := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q30_l)
		q30_s.mode = "OVER"
		return q30_s
	# the boards as data: four layouts of 60 hex nodes (spine 8, Body 24, Craft 14, Spirit 14), each node reachable from the stance; the 9
	# live passives of a 40 pool, the craft ones split by style, the spirit ones on every board, the socket the Boxer-Puncher's alone; the
	# named nodes (2 authored per Millbrook card, the rule's 2 for a recruit's); points 2 a level; a node refused for each reason (not
	# touching, the points, the bell rung) and taken (the event, the points); a stat node at the cap adds nothing past it; the soft cap
	# (70+ double, single after the breaker); respec at the Film Room's T2 only; the socket's rules, and Iron Jaw in it
	var q30_lay: Array = []
	for q30_st in q30_g["layouts"]:
		var q30_L: Dictionary = q30_g["layouts"][q30_st]
		var q30_cnt := {}
		var q30_by := {}
		for q30_n in q30_L["nodes"]:
			q30_cnt[str(q30_n["lobe"])] = int(q30_cnt.get(str(q30_n["lobe"]), 0)) + 1; q30_by[str(q30_n["id"])] = q30_n
		var q30_seen := {"root": true}; var q30_q: Array = ["root"]
		while q30_q.size() > 0:
			var q30_x: String = q30_q.pop_back()
			for q30_ln in q30_by[q30_x]["links"]:
				if not q30_seen.has(str(q30_ln)): q30_seen[str(q30_ln)] = true; q30_q.append(str(q30_ln))
		var q30_ps: Array = q30_L["nodes"].filter(func(q30_n2): return str(q30_n2["kind"]) == "passive").map(func(q30_n3): return str(q30_n3["passive"]))
		q30_lay.append([str(q30_st), q30_L["nodes"].size(), q30_cnt, q30_seen.size(), q30_ps, bool(q30_L["socket"])])
	var q30a : TNBSim = q30_mk.call("RORY:10,PRIYA:10,MARCUS:10")
	var q30_nm: Array = [q30a.growth_nodes("RORY").size(), str(q30a.growth_nodes("RORY")["n1"]["label"]), q30a._named_nodes(q30a.recruit_card("ioan_vasile")).map(func(q30_n4): return "%s+%d" % [str(q30_n4["stat"]), int(q30_n4["v"])]), q30a.gpoints("RORY"), q30a.gpoints("JUNE")]
	var q30_rf: Array = [q30a.node_why("RORY", "b3_PWR"), str(q30a.take_node("RORY", "c1")["ok"]), q30a.take_node("RORY", "c3")["ok"], q30a.gpoints_free("RORY"), q30a.passives_of("RORY"), count_events(q30a.events, "node_taken")]
	var q30j : TNBSim = q30_mk.call("")
	q30j.take_node("JUNE", "sp1"); q30_rf.append(q30j.node_why("JUNE", "sp2"))
	var q30f : TNBSim = q30_mk.call("RORY:10"); q30f.mode = "FIGHT"; q30f.step({}); q30_rf.append(q30f.node_why("RORY", "c1"))
	q30a.take_node("RORY", "s1"); q30_rf.append([int(q30a.grown_stats(q30a._club_card("RORY"))["HRT"]), q30a.node_cost("RORY", "s1")])
	var q30m : TNBSim = q30_mk.call("MARCUS:10", {}, "", "", "MARCUS:rarity:2")
	var q30_sc: Array = [q30m.node_cost("MARCUS", "sp1"), q30m.node_cost("MARCUS", "b2_PWR")]
	for q30_id in ["b2_PWR", "b3_PWR", "b5_PWR", "br_PWR"]: q30_sc.append(q30m.take_node("MARCUS", q30_id)["cost"])
	q30_sc.append_array([q30m.node_cost("MARCUS", "sp1"), int(q30m.grown_stats(q30m._club_card("MARCUS"))["PWR"]), q30m.gpoints_free("MARCUS")])
	var q30r1 : TNBSim = q30_mk.call("RORY:10", {}, "film:1"); q30r1.take_node("RORY", "c1")
	var q30r2 : TNBSim = q30_mk.call("RORY:10", {}, "film:2")
	for q30_id2 in ["sp1", "sp2", "sp3", "sp4", "sp5", "sp6", "sp7"]: q30r2.take_node("RORY", q30_id2)
	var q30_so: Array = [q30r1.respec_why("RORY"), q30r2.socket_why("PRIYA", "iron_jaw"), q30r1.socket_why("RORY", "iron_jaw"), q30r2.socket_why("RORY", "tight_guard"), q30r2.socket_why("RORY", "sparkplug"), q30r2.socket("RORY", "iron_jaw")["ok"], q30r2.passives_of("RORY")]
	var q30_sp0: int = q30r2.gpoints_free("RORY")
	q30_so.append_array([q30r2.respec("RORY")["points"], q30r2.gpoints_free("RORY") - q30_sp0, q30r2.passives_of("RORY"), str(q30r2._grow("RORY")["socket"]), count_events(q30r2.events, "respec")])
	_sr("the ability boards (NP_11 s3): %s; RORY's board %d nodes (%s), a recruit's %s; points %d / %d; %s; the soft cap %s; the socket and respec %s" % [JSON.stringify(q30_lay.map(func(q30_y): return [q30_y[0], q30_y[1], q30_y[3], q30_y[4]])), int(q30_nm[0]), str(q30_nm[1]), JSON.stringify(q30_nm[2]), int(q30_nm[3]), int(q30_nm[4]), JSON.stringify(q30_rf), JSON.stringify(q30_sc), JSON.stringify(q30_so)],
		q30_lay.size() == 4 and q30_lay.filter(func(q30_y2): return int(q30_y2[1]) == 61 and int(q30_y2[3]) == 61 and q30_y2[2] == {"spine": 8, "body": 24, "craft": 14, "spirit": 15}).size() == 4 \
		and q30_lay.map(func(q30_y3): return q30_y3[5]) == [false, false, false, true] and q30_lay[0][4] == ["ring_cutter", "second_gear", "iron_jaw", "sparkplug", "cheap_trick", "closer", "wallflower"] and q30_lay[3][4] == ["tight_guard", "snap", "sparkplug", "cheap_trick", "closer", "wallflower"] \
		and q30_g["passives"].keys() == ["tight_guard", "snap", "ring_cutter", "iron_jaw", "second_gear", "sparkplug", "cheap_trick", "closer", "wallflower"] and int(q30_g["pool_size"]) == 40 \
		and int(q30_nm[0]) == 63 and str(q30_nm[1]) == "Borealis Wind-up (RORY's own)" and q30_nm[2] == ["PWR+3", "SPD+3"] and int(q30_nm[3]) == 20 and int(q30_nm[4]) == 2 \
		and str(q30_rf[0]) == "+3 PWR does not touch a node RORY has taken" and str(q30_rf[1]) == "true" and bool(q30_rf[2]) and int(q30_rf[3]) == 16 and q30_rf[4] == ["tight_guard"] and int(q30_rf[5]) == 2 \
		and str(q30_rf[6]) == "+2 STA costs 1 Board Points - JUNE has 0 of 2 free (level 1)" and str(q30_rf[7]) == "the board is worked between duals" and q30_rf[8] == [99, 2] \
		and q30_sc == [2, 2, 2, 4, 6, 2, 1, 80, 6] \
		and str(q30_so[0]) == "the respec is the Film Room's (T2) - the gym's is at T1" and str(q30_so[1]) == "the off-style socket is the Boxer-Puncher's (PRIYA's board is the Out-Boxer's)" and str(q30_so[2]) == "RORY has not taken the socket node yet" \
		and str(q30_so[3]) == "Tight Guard is on RORY's own board - the socket is for an off-style one" and str(q30_so[4]) == "Sparkplug is a Spirit passive - the socket takes a craft one" and bool(q30_so[5]) and q30_so[6] == ["iron_jaw"] \
		and int(q30_so[7]) == 11 and int(q30_so[8]) == 11 and q30_so[9] == [] and str(q30_so[10]) == "" and int(q30_so[11]) == 1)
	# each live passive against the same sim without it: RORY walks out with the node on his board (Craft: Tight Guard c3, Snap c10; the
	# socket's Ring Cutter, Iron Jaw, Second Gear; Spirit: Sparkplug s3, Cheap Trick s6, Closer s10, Wallflower s13) and nothing else
	var q30_ps_mk := func(q30_pid: String) -> TNBSim:
		var q30_nd := {"tight_guard": "c3", "snap": "c10", "sparkplug": "s3", "cheap_trick": "s6", "closer": "s10", "wallflower": "s13"}
		var q30_rec := {"board": [str(q30_nd.get(q30_pid, "sp7"))], "spent": 3, "socket": "" if q30_nd.has(q30_pid) else q30_pid, "raises": {}, "rarity": 1, "trials": {}}
		var q30_s2 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, {"growth": {"RORY": q30_rec}} if q30_pid != "" else {})
		quiet(q30_s2); place(q30_s2, 1.4); clear_defense(q30_s2.B); q30_s2.B["guard_t"] = 0
		return q30_s2
	var q30_hit := func(q30_s3: TNBSim, q30_row: String) -> Array:
		q30_s3.P["pending"] = {"row": q30_row, "t": 0, "startup": 0, "mods": [], "hissatsu": false, "counter": false, "flash": false, "stamina_cost": 0.0, "read": "none", "stepping": false}
		var q30_c0: float = q30_s3.B["comp"]; var q30_p0: Vector2 = q30_s3.B["pos"]
		q30_s3._land_player_punch()
		return [q30_c0 - float(q30_s3.B["comp"]), q30_s3.B["pos"].distance_to(q30_p0)]
	var q30_pv := {}
	for q30_pid2 in ["", "tight_guard", "snap", "ring_cutter", "iron_jaw", "second_gear", "sparkplug", "cheap_trick", "closer", "wallflower"]:
		var q30_w : TNBSim = q30_ps_mk.call(q30_pid2)
		var q30_on: Array = q30_w.P.get("passives", [])
		var q30_v: Array = [q30_on]
		var q30_g0: float = q30_w.P["guard"]                                                                  # Tight Guard: 60 ticks held
		for q30_i in 60: q30_w.step({"block": true})
		q30_v.append(q30_g0 - float(q30_w.P["guard"]))
		var q30_h: TNBSim = q30_ps_mk.call(q30_pid2); q30_v.append(q30_hit.call(q30_h, "L_STRAIGHT"))      # Snap, Ring Cutter: a jab's damage and push
		var q30_ij: TNBSim = q30_ps_mk.call(q30_pid2)                                                       # Iron Jaw: out of the wobble from 20 %
		q30_ij.P["comp"] = float(q30_ij.P["comp_max"]) * 0.20; q30_ij.P["no_regen_t"] = 0
		var q30_t := 0
		while q30_ij._wobbled(q30_ij.P) and q30_t < 2000: q30_ij.step({}); q30_t += 1
		q30_v.append(q30_t)
		var q30_sg: TNBSim = q30_ps_mk.call(q30_pid2); q30_sg.P["stamina"] = 30.0                            # Second Gear: the 15-40 row, and a jab at 30 stamina
		q30_v.append([float(q30_sg._gassed(q30_sg.P)["dmg"]), float(q30_sg._gassed(q30_sg.P)["foot_speed"]), q30_hit.call(q30_sg, "L_STRAIGHT")[0]])
		q30_sg.P["stamina"] = 50.0; q30_v[-1].append(float(q30_sg._gassed(q30_sg.P)["dmg"])); q30_sg.P["stamina"] = 10.0; q30_v[-1].append(float(q30_sg._gassed(q30_sg.P)["dmg"]))
		var q30_tn: TNBSim = q30_ps_mk.call(q30_pid2); var q30_te: Array = [q30_tn.tension, q30_tn.contributed]; q30_tn._earn_tension(10.0); q30_v.append([q30_tn.tension - float(q30_te[0]), q30_tn.contributed - float(q30_te[1])])   # Sparkplug
		var q30_ct: TNBSim = q30_ps_mk.call(q30_pid2); var q30_t0: Dictionary = q30_ct.library["First Snap"]           # Cheap Trick: a T0's price, paid
		q30_ct.tension = 10.0; var q30_cc: float = q30_ct.hiss_cost(q30_t0); q30_ct._start_cast("P", q30_t0); q30_v.append([q30_cc, q30_ct.tension])
		var q30_cl: TNBSim = q30_ps_mk.call(q30_pid2); var q30_th: float = q30_cl._charged_threshold()        # Closer: 22 contributed at the segment's end
		q30_cl.mode = "FIGHT"; q30_cl.contributed = 22.0; q30_cl._end_segment("drive"); q30_v.append([q30_th, q30_cl.charged])
		var q30_wf: TNBSim = q30_ps_mk.call(q30_pid2); q30_wf.tension = 100.0                                 # Wallflower: Palisade (T2: a 4 s wall, a 4 s buff); Shield Wall's points wall
		q30_wf._start_cast("P", q30_wf.library["Palisade"]); q30_wf._resolve_cast()
		var q30_w1: Array = [int(q30_wf.wall["P"].get("timed_t", 0)), int(q30_wf.buffs["P"].get("guard_regen_x2", {}).get("t", 0))]
		q30_wf.wall["P"] = {}; q30_wf.tension = 100.0; q30_wf._start_cast("P", q30_wf.library["Shield Wall"]); q30_wf._resolve_cast()
		q30_w1.append(int(q30_wf.wall["P"].get("timed_t", 0))); q30_v.append(q30_w1)
		q30_pv[q30_pid2 if q30_pid2 != "" else "none"] = q30_v
	var q30_n: Array = q30_pv["none"]
	var q30_ok := func(q30_k: String, q30_ix: int) -> Array: return [q30_n[q30_ix], q30_pv[q30_k][q30_ix]]
	var q30_live: Array = [q30_ok.call("tight_guard", 1), [q30_n[2][0], q30_pv["snap"][2][0]], [q30_n[2][1], q30_pv["ring_cutter"][2][1]], q30_ok.call("iron_jaw", 3), q30_ok.call("second_gear", 4), q30_ok.call("sparkplug", 5), q30_ok.call("cheap_trick", 6), q30_ok.call("closer", 7), q30_ok.call("wallflower", 8)]
	var q30_quiet := true                                                                                     # each passive moves its own number and no other
	var q30_own := {"tight_guard": [1], "snap": [2, 4], "ring_cutter": [2], "iron_jaw": [3], "second_gear": [4], "sparkplug": [5], "cheap_trick": [6], "closer": [7], "wallflower": [8]}
	for q30_k2 in q30_own:
		for q30_ix2 in range(1, 9):
			if not (q30_ix2 in q30_own[q30_k2]) and JSON.stringify(q30_pv[q30_k2][q30_ix2]) != JSON.stringify(q30_n[q30_ix2]): q30_quiet = false
	var q30_onok := true
	for q30_k3 in q30_own:
		if q30_pv[q30_k3][0] != [q30_k3]: q30_onok = false
	_sr("each live passive against the same sim without it: Tight Guard's guard lost %s, Snap's jab %s, Ring Cutter's push %s, Iron Jaw's wobble ticks %s, Second Gear %s, Sparkplug %s, Cheap Trick %s, Closer %s, Wallflower %s; each on RORY at the bell %s, and nothing else moved %s" % [JSON.stringify(q30_live[0]), JSON.stringify(q30_live[1]), JSON.stringify(q30_live[2]), JSON.stringify(q30_live[3]), JSON.stringify(q30_live[4]), JSON.stringify(q30_live[5]), JSON.stringify(q30_live[6]), JSON.stringify(q30_live[7]), JSON.stringify(q30_live[8]), str(q30_onok), str(q30_quiet)],
		q30_onok and q30_quiet and q30_n[0] == [] and float(q30_live[0][0]) > 0.0 and absf(float(q30_live[0][1]) / float(q30_live[0][0]) - 0.8) < 0.001 \
		and float(q30_live[1][0]) > 0.0 and absf(float(q30_live[1][1]) / float(q30_live[1][0]) - 1.3) < 0.001 and float(q30_live[2][0]) > 0.0 and absf(float(q30_live[2][1]) / float(q30_live[2][0]) - 1.25) < 0.001 \
		and int(q30_live[3][0]) > 100 and absf(float(q30_live[3][1]) / float(q30_live[3][0]) - 0.7) < 0.01 \
		and absf(float(q30_live[4][0][0]) - 0.75) < 0.0001 and absf(float(q30_live[4][0][1]) - 0.7) < 0.0001 and absf(float(q30_live[4][1][0]) - 0.875) < 0.0001 and absf(float(q30_live[4][1][1]) - 0.85) < 0.0001 \
		and absf(float(q30_live[4][1][2]) / float(q30_live[4][0][2]) - 0.875 / 0.75) < 0.001 and q30_live[4][0].slice(3) == q30_live[4][1].slice(3) and absf(float(q30_live[4][0][3]) - 0.9) < 0.0001 and absf(float(q30_live[4][0][4]) - 0.55) < 0.0001 \
		and absf(float(q30_live[5][0][0]) - 10.0) < 0.001 and absf(float(q30_live[5][1][0]) - 11.5) < 0.001 and absf(float(q30_live[5][1][1]) - 11.5) < 0.001 \
		and absf(float(q30_live[6][1][0]) / float(q30_live[6][0][0]) - 0.8) < 0.001 and absf(float(q30_live[6][1][1]) - (10.0 - float(q30_live[6][1][0]))) < 0.001 and absf(float(q30_live[6][0][1]) - (10.0 - float(q30_live[6][0][0]))) < 0.001 \
		and q30_live[7] == [[25.0, false], [20.0, true]] \
		and int(q30_live[8][1][0]) - int(q30_live[8][0][0]) == TNBSim.ms(1000) and int(q30_live[8][0][1]) == TNBSim.ms(4000) and int(q30_live[8][1][1]) == TNBSim.ms(5000) and int(q30_live[8][0][2]) == 0 and int(q30_live[8][1][2]) == 0)
	# typed Beans and the raises: Mitts pays SPD, the Heavy Bag with PRIYA along PWR and a quarter RFX (her best), Shadow Rounds untyped;
	# +1 = 5 Beans then 6, the stat's own first and the untyped after, another stat's never; the cap refuses; the Forge's spend takes the
	# untyped then the typed in the stats' order; refused in a fight; the raise walks out at the next bell
	var q30b : TNBSim = q30_mk.call("", {}, "bags:3", "", "", "")
	var q30_tb: Array = []
	for q30_tr in [["mitts", ""], ["heavy_bag", "PRIYA"]]:
		var q30_res: Dictionary = q30b.train(str(q30_tr[0]), "RORY", 0.5, str(q30_tr[1]))
		q30_tb.append([int(q30_res["beans"]), q30b.events.filter(func(q30_e): return str(q30_e["kind"]) == "training")[-1]["typed"]])
	q30b.rewards["story"]["quest:macisaac_harbour"] = true
	q30b.pi["book"] = ["yuri_kowalchuk"]
	var q30_sh: Dictionary = q30b.train("shadow_rounds", "MARCUS", 0.0)
	q30_tb.append([int(q30_sh.get("beans", 0)), q30b.events.filter(func(q30_e2): return str(q30_e2["kind"]) == "training")[-1]["typed"], q30b.jar_text(), int(q30b.rewards["beans"])])
	var q30_ra: Array = [q30b.raise_cost("RORY", "SPD"), q30b.raise_stat("RORY", "SPD")["ok"], q30b.jar_text(), q30b.raise_cost("RORY", "SPD"), q30b.raise_stat("RORY", "SPD")["ok"], q30b.jar_text(), q30b.raise_why("RORY", "SPD"), q30b.raise_why("RORY", "BLK")]
	var q30c : TNBSim = q30_mk.call("", {}, "", "beans:30", "", "SPD:4")
	q30_ra.append_array([q30c.raise_why("MARCUS", "PWR"), q30c.raise_stat("PRIYA", "BLK")["ok"], q30c.raise_stat("PRIYA", "BLK")["ok"], q30c.raise_stat("PRIYA", "BLK")["ok"], q30c.raise_stat("PRIYA", "BLK")["ok"], q30c.raise_why("PRIYA", "BLK"), q30c.raise_why("PRIYA", "RFX"), q30c.jar_text()])
	var q30d : TNBSim = q30_mk.call("", {}, "", "beans:6", "", "PWR:5,SPD:5")
	q30d.rewards["beans"] = int(q30d.rewards["beans"]) - 9; q30d._beans_settle(); q30_ra.append(q30d.jar_text())
	var q30e : TNBSim = q30_mk.call("", {}, "", "beans:12"); q30e.raise_stat("RORY", "PWR"); q30e.raise_stat("RORY", "PWR")
	q30e.new_dual(); q30_ra.append_array([int(q30e.P["stats"]["PWR"]), int(TNBSim.LINEUP_MILLBROOK[0]["stats"]["PWR"]), int(q30e.dressed[0]["stats"]["PWR"])])
	q30e.step({}); q30_ra.append(q30e.raise_why("RORY", "PWR"))
	_sr("typed Beans and the raises (NP_11 s6, s7): the slots %s; RORY's raises %s; PRIYA's %s; the Forge's cut %s; at the bell %s; in the fight '%s'" % [JSON.stringify(q30_tb), JSON.stringify(q30_ra.slice(0, 8)), JSON.stringify(q30_ra.slice(8, 16)), str(q30_ra[16]), JSON.stringify(q30_ra.slice(17, 20)), str(q30_ra[20])],
		q30_tb[0] == [8, {"SPD": 8}] and q30_tb[1] == [8, {"PWR": 6, "RFX": 2}] and int(q30_tb[2][0]) == 9 and q30_tb[2][1] == {} and str(q30_tb[2][2]) == "PWR 6, SPD 8, RFX 2, 9 untyped" and int(q30_tb[2][3]) == 25 \
		and q30_ra.slice(0, 8) == [5, true, "PWR 6, SPD 3, RFX 2, 9 untyped", 6, true, "PWR 6, RFX 2, 6 untyped", "+1 SPD costs 7 Beans - the jar holds 0 SPD and 6 untyped", ""] \
		and str(q30_ra[8]) == "MARCUS's PWR stands at 70 - the Club cap is 70" and q30_ra.slice(9, 13) == [true, true, true, true] and str(q30_ra[13]) == "+1 BLK costs 9 Beans - the jar holds 0 BLK and 4 untyped" and str(q30_ra[14]) == "PRIYA's RFX stands at 70 - the Club cap is 70" and str(q30_ra[15]) == "SPD 4, 4 untyped" \
		and str(q30_ra[16]) == "PWR 2, SPD 5, 0 untyped" and q30_ra.slice(17, 20) == [47, 45, 45] and str(q30_ra[20]) == "the raises are between duals")
	# rarity (NP_11 s4): refused on the trial, then on the Spirits; Circuit for 10 (the cap 70 -> 80, a second accessory slot); the trials
	# earned in play - a spar won, a transform weathered (Stood in the Storm), his mirror beaten (the mirror spar sends him out against his
	# own card, grown and generic); National for 25, Legend for 60 and the top; a generic's Awakening flag at the Legend's tier, a named
	# card's from the start - the Awakening's own gate reads it
	var q30h : TNBSim = q30_mk.call("RORY:10", {}, "", "spirits:5")
	var q30_as: Array = [q30h.ascend_why("RORY")]
	q30h._trial_mark("RORY", "spar_won"); q30_as.append(q30h.ascend_why("RORY")); q30h.rewards["spirits"] = 200
	q30_as.append_array([q30h.ascend("RORY")["ok"], int(q30h.rewards["spirits"]), q30h.rarity_cap("RORY"), q30h.accessory_slots("RORY"), q30h.ascend_why("RORY")])
	var q30sp : TNBSim = q30_mk.call(""); q30sp.start_spar(1); q30sp.score_p = 1; q30sp._end_bout()
	q30_as.append(q30sp._grow("RORY").get("trials", {}).keys())
	var q30st : TNBSim = q30_mk.call(""); q30st.mode = "FIGHT"
	q30st.btform = {"who": "ioan_vasile", "tier": "zone", "answered": false, "dropped": false, "weathered": 2, "shaved": 60, "t": 0}
	q30st._boss_tform_end(false); q30_as.append(q30st._grow("RORY").get("trials", {}).keys())
	var q30mi : TNBSim = q30_mk.call("PRIYA:10", {}, "", "", "PRIYA:raise:SPD:2")
	var q30_mok: bool = q30mi.start_mirror("PRIYA")
	q30_as.append_array([q30_mok, q30mi.pname(), q30mi.boss_label, bool(q30mi.bout["card"]["generic"]), int(q30mi.B["stats"]["SPD"]), int(q30mi.P["stats"]["SPD"]), q30mi.bgeneric.size() > 0])
	q30mi.score_p = 1; q30mi._end_bout(); q30_as.append(q30mi._grow("PRIYA")["trials"].keys())
	q30h._trial_mark("RORY", "storm"); q30_as.append_array([q30h.ascend("RORY")["ok"], q30h.rarity_cap("RORY"), q30h.ascend_why("RORY")])
	q30h._trial_mark("RORY", "mirror"); q30_as.append_array([q30h.ascend("RORY")["ok"], int(q30h.rewards["spirits"]), q30h.rarity_cap("RORY"), q30h.accessory_slots("RORY"), q30h.ascend_why("RORY"), count_events(q30h.events, "ascended")])
	var q30_gc: Dictionary = TNBSim.LINEUP_MILLBROOK[3].duplicate(true); q30_gc["name"] = "GEN"; q30_gc["generic"] = true
	var q30aw : TNBSim = make_sim(1, 7, [TNBSim.LINEUP_MILLBROOK[0], q30_gc], "", {}, TNBSim.seed_story(TNBSim.seed_growth({}, "GEN:rarity:3"), "secret:GEN,story:trial:GEN,secret:RORY,story:trial:RORY,story:sealed_house_resolved"))
	q30_as.append_array([q30aw.awaken_eligible("GEN"), q30aw._awaken_gate("GEN"), q30aw.awaken_eligible("RORY"), q30aw._awaken_gate("RORY")])
	q30aw.rewards["growth"]["GEN"]["rarity"] = 4; q30_as.append_array([q30aw.awaken_eligible("GEN"), q30aw._awaken_gate("GEN")])
	_sr("rarity ascension (NP_11 s4): %s; the trials in play %s; the mirror %s -> %s; National and Legend %s; the Awakening flag %s" % [JSON.stringify(q30_as.slice(0, 7)), JSON.stringify(q30_as.slice(7, 9)), JSON.stringify(q30_as.slice(9, 16)), JSON.stringify(q30_as[16]), JSON.stringify(q30_as.slice(17, 26)), JSON.stringify(q30_as.slice(26))],
		str(q30_as[0]) == "RORY's trial for Circuit waits - win a spar" and str(q30_as[1]) == "Circuit costs 10 Spirits (the ledger holds 5)" and bool(q30_as[2]) and int(q30_as[3]) == 190 and int(q30_as[4]) == 80 and int(q30_as[5]) == 2 \
		and str(q30_as[6]) == "RORY's trial for National waits - weather a transform (Stood in the Storm)" and q30_as[7] == ["spar_won"] and q30_as[8] == ["storm"] \
		and bool(q30_as[9]) and str(q30_as[10]) == "PRIYA" and str(q30_as[11]) == "PRIYA'S MIRROR" and bool(q30_as[12]) and int(q30_as[13]) == 62 and int(q30_as[14]) == 62 and bool(q30_as[15]) and q30_as[16] == ["spar_won", "mirror"] \
		and bool(q30_as[17]) and int(q30_as[18]) == 90 and str(q30_as[19]) == "RORY's trial for Legend waits - beat the mirror in a spar" and bool(q30_as[20]) and int(q30_as[21]) == 105 and int(q30_as[22]) == 99 and int(q30_as[23]) == 3 \
		and str(q30_as[24]) == "RORY is a Legend (tier 4), the top" and int(q30_as[25]) == 3 \
		and q30_as.slice(26) == [false, false, true, true, true, true])
	# the save: each Fighter's rarity, board (layout, nodes taken, points free, the socket), raises, grown stats, passives and Awakening flag
	# from the ledger; written, read, built and written again byte-equal; the built sim's card walks out on the same grown stats and passives
	var q30v : TNBSim = q30_mk.call("RORY:10,PRIYA:6", {}, "film:2", "beans:20,spirits:40", "RORY:trial:spar_won", "RFX:5")
	for q30_id3 in ["sp1", "sp2", "sp3", "sp4", "sp5", "sp6", "sp7", "c1"]: q30v.take_node("RORY", q30_id3)
	q30v.socket("RORY", "second_gear"); q30v.ascend("RORY"); q30v.raise_stat("PRIYA", "SPD"); q30v.take_node("PRIYA", "*")
	var q30_sv: Dictionary = TNBSave.to_save(q30v)
	var q30_rr: Dictionary = q30_sv["stable"][0]; var q30_pr: Dictionary = q30_sv["stable"][1]
	var q30_tx: String = TNBSave.write_text(q30v, false)
	var q30_bl: Dictionary = TNBSave.build(content, TNBSave.read_text(q30_tx), 7)
	var q30vl: TNBSim = q30_bl["sim"]
	_sr("the save's Fighter.board (NP_11 s9): RORY %s; PRIYA %s; written back %s; the load walks out on %s with %s" % [JSON.stringify([q30_rr["rarity"], q30_rr["board"], q30_rr["passives"], q30_rr["awakening_flag"], q30_rr["accessory_slots"]]), JSON.stringify([q30_pr["rarity"], q30_pr["board"], q30_pr["raises"], q30_pr["stats_grown"]["SPD"]]), "byte-equal" if TNBSave.write_text(q30vl, false) == q30_tx else "DIFFERENT", JSON.stringify(q30vl.P["stats"]), JSON.stringify(q30vl.P.get("passives", []))],
		int(q30_rr["rarity"]) == 2 and q30_rr["board"] == {"layout_id": "BOXERPUNCHER", "nodes_taken": ["sp1", "sp2", "sp3", "sp4", "sp5", "sp6", "sp7", "c1"], "points_free": 8, "socket": "second_gear"} and q30_rr["passives"] == ["second_gear"] \
		and bool(q30_rr["awakening_flag"]) and int(q30_rr["accessory_slots"]) == 2 and int(q30_rr["stats_grown"]["PWR"]) == 59 and int(q30_rr["stats"]["PWR"]) == 45 \
		and int(q30_pr["rarity"]) == 1 and q30_pr["raises"] == {"SPD": 1} and q30_pr["board"]["layout_id"] == "OUTBOXER" and q30_pr["board"]["nodes_taken"].size() == 1 and int(q30_pr["stats_grown"]["SPD"]) == 61 \
		and TNBSave.write_text(q30vl, false) == q30_tx and q30vl.P["stats"] == q30v.grown_stats(q30v._club_card("RORY")) and q30vl.P.get("passives", []) == ["second_gear"] and q30vl.grown_stats(q30vl._club_card("PRIYA")) == q30v.grown_stats(q30v._club_card("PRIYA")))


	# ---- PAC-091: TECHNIQUES AND THE SLOTS (NP_11 s2, s8) ----
	var q31_t: Dictionary = content["techniques"]
	var q31_mk := func(q31_lv: String, q31_pu: String = "", q31_fl: String = "", q31_ln: String = "", q31_tp: String = "", q31_lu: Array = TNBSim.LINEUP_MILLBROOK, q31_fac: String = "bags:1", q31_kz: String = "") -> TNBSim:
		var q31_l: Dictionary = TNBSim.seed_facilities(TNBSim.seed_tapes(TNBSim.seed_learned(TNBSim.seed_story(TNBSim.seed_purse(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(q31_kz), q31_lv, content["economy"]), q31_pu), q31_fl), q31_ln), q31_tp), q31_fac, content["facilities"])
		var q31_s := make_sim(1, 7, q31_lu, "", {}, q31_l)
		q31_s.mode = "OVER"
		return q31_s
	# the slots: a technique slot at 5 / 15 / 25 / 35 / 45, the T0 slot at 5 (one T0: a card's own T0 is it); refused for each reason - full,
	# the T0 before 5, a second T0, a move cast by its own rule, one the club cannot learn, one not learned, the card's own, the bell rung;
	# his house's native beside a full kit (YURI, NATIVE: Full Load; Grain Elevator is his own move); a seeded kit past his slots walks out
	# cut to them; put down and taken up again
	var q31a : TNBSim = q31_mk.call("RORY:15,PRIYA:5,MARCUS:4,JUNE:1", "", "", "RORY:Snowblind+Landslide+Updraft,PRIYA:Root Bind+Updraft")
	q31a._tq()["learned"]["MARCUS"] = {"Sapling": "seed"}; q31a._tq()["learned"]["PRIYA"]["Cornerstone"] = "seed"
	var q31_sl: Array = [q31_t["slot_levels"], int(q31_t["t0_level"]), 0]
	var q31_lvs: Array = []
	for q31_lv3 in [1, 4, 5, 14, 15, 45, 50]:
		var q31_x : TNBSim = q31_mk.call("RORY:%d" % q31_lv3); q31_lvs.append(q31_x.tech_slots("RORY"))
	q31_sl.append(q31_lvs)
	q31_sl.append_array([q31a.kit_moves("RORY"), q31a.kit_moves("PRIYA"), q31a.kit_moves("MARCUS")])
	q31_sl.append_array([q31a.kit_why("RORY", "Updraft"), q31a.kit_why("MARCUS", "Sapling"), q31a.kit_why("PRIYA", "Cornerstone"), q31a.kit_why("RORY", "Relay: North Star"), q31a.kit_why("RORY", "Rush Hour"), q31a.kit_why("RORY", "Root Bind"), q31a.kit_why("RORY", "Aurora Borealis Breaker")])
	q31a.kit_unequip("RORY", "Snowblind"); q31_sl.append(q31a.kit_moves("RORY")); q31a.kit_equip("RORY", "Updraft"); q31_sl.append(q31a.kit_moves("RORY"))
	var q31f : TNBSim = q31_mk.call("RORY:15", "", "", "RORY:Snowblind"); q31f.mode = "FIGHT"; q31f.step({}); q31_sl.append(q31f.kit_why("RORY", "Snowblind"))
	var q31y : TNBSim = q31_mk.call("YURI:5", "", "blessing:kowalchuk", "YURI:Snowblind+Landslide", "", TNBSim.LINEUP_MILLBROOK_8)
	q31y.kit_equip("YURI", "*"); var q31_yn: Array = q31y.learned_natives("YURI")
	for q31_n in q31_yn: q31y.kit_equip("YURI", str(q31_n))
	q31_sl.append_array([q31_yn.filter(func(q31_n3): return str(q31_n3) != "Grain Elevator"), q31y.kit_moves("YURI")])
	_sr("the technique slots (NP_11 s2, NP_05 s3): %s at level; the kits %s; refused %s; down and up %s; in the fight '%s'; YURI's natives %s beside %s" % [JSON.stringify(q31_sl[3]), JSON.stringify(q31_sl.slice(4, 7)), JSON.stringify(q31_sl.slice(7, 14)), JSON.stringify(q31_sl.slice(14, 16)), str(q31_sl[16]), JSON.stringify(q31_sl[17]), JSON.stringify(q31_sl[18])],
		q31_sl[0].map(func(q31_v): return int(q31_v)) == [5, 15, 25, 35, 45] and int(q31_sl[1]) == 5 and q31_sl[3] == [0, 0, 1, 1, 2, 5, 5] \
		and q31_sl[4] == ["Snowblind", "Landslide"] and q31_sl[5] == ["Root Bind"] and q31_sl[6] == [] \
		and str(q31_sl[7]) == "RORY's technique slots are full (2 of 2) - level 25 opens the next" and str(q31_sl[8]) == "the T0 slot opens at level 5 - MARCUS is level 4" \
		and str(q31_sl[9]) == "PRIYA carries a T0 already (Marginalia) - one T0, the identity move (NP_05 s3)" and str(q31_sl[10]) == "Relay: North Star is cast by its own rule - the FULL RELAY's (C35)" \
		and str(q31_sl[11]) == "Rush Hour is not the club's to learn - a worlds boss's desperation - no recruitment authored" and str(q31_sl[12]) == "RORY has not learned Root Bind" \
		and str(q31_sl[13]) == "RORY carries Aurora Borealis Breaker already (the card's own move)" and q31_sl[14] == ["Landslide"] and q31_sl[15] == ["Landslide", "Updraft"] \
		and str(q31_sl[16]) == "the kit is set between duals" and q31_sl[17] == ["Full Load"] and q31_sl[18] == ["Snowblind", "Full Load"])
	# the shop and the tapes: the shelves by circuit progress (t1 as found, t2 the Regionals, t3 the Provincials); refused on the shelf, the
	# price, a native, a move not sold, one known; bought: the HBP down, "shop", straight into the kit; the quest's tape arrives with its flag
	# once, the found one seeded; a tape spent on use; none left refused
	var q31b : TNBSim = q31_mk.call("RORY:15", "hbp:500")
	var q31_sh: Array = []
	for q31_tr in ["t1", "t2", "t3"]: q31_sh.append(q31b.shop_list().filter(func(q31_r): return str(q31_r["tier"]) == q31_tr).map(func(q31_r2): return str(q31_r2["move"])))
	q31_sh.append_array([q31b.buy_why("RORY", "Snowblind"), q31b.buy_why("RORY", "Grain Elevator"), q31b.buy_why("RORY", "Thunder Bay")])
	var q31b2 : TNBSim = q31_mk.call("RORY:15", "hbp:500", "story:regionals")
	q31_sh.append_array([q31b2.buy("RORY", "Snowblind")["ok"], int(q31b2.rewards["hbp"]), q31b2.learned("RORY"), q31b2.kit_moves("RORY"), q31b2.buy_why("RORY", "Landslide"), q31b2.buy_why("RORY", "Snowblind"), q31b2.buy_why("RORY", "Pressure Cooker")])
	var q31c : TNBSim = q31_mk.call("RORY:15,MARCUS:15", "", "quest:harbour", "", "Black Ice:1")
	var q31_tp: Array = [q31c.tapes().duplicate(), count_events(q31c.events, "tape_found"), q31c._tapes_sync()]
	q31_tp.append_array([q31c.use_tape("RORY", "Portage")["ok"], q31c.learned("RORY"), q31c.kit_moves("RORY"), q31c.tape_why("MARCUS", "Portage"), q31c.use_tape("MARCUS", "Black Ice")["ok"], q31c.kit_moves("MARCUS"), q31c.tapes()])
	var q31c2 : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q31c.rewards); q31_tp.append([q31c2.tapes(), count_events(q31c2.events, "tape_found")])
	_sr("the HBP shop and the fight tapes (NP_11 s8): the shelves %s; refused %s; bought %s; the tapes %s; used %s; the saved ledger again %s" % [JSON.stringify(q31_sh.slice(0, 3)), JSON.stringify(q31_sh.slice(3, 6)), JSON.stringify(q31_sh.slice(6)), JSON.stringify(q31_tp.slice(0, 3)), JSON.stringify(q31_tp.slice(3, 10)), JSON.stringify(q31_tp[10])],
		q31_sh[0] == ["First Snap", "Cornerstone", "Gust Step", "Sapling"] and q31_sh[1] == ["Chinook Rush", "Snowblind", "Landslide", "Root Bind", "Updraft"] and q31_sh[2] == ["Thunder Bay", "White Squall", "Overtime"] \
		and str(q31_sh[3]) == "the shop's t2 shelf opens with the Regionals (NP_12 s4 beat 4) (story:regionals) or DOWNTOWN rep 10 (0 now)" and str(q31_sh[4]) == "Grain Elevator is not in the HBP shop" and str(q31_sh[5]) == "the shop's t3 shelf opens with the Provincials (beat 6) (story:provincials_semifinal) or DOWNTOWN rep 25 (0 now)" \
		and bool(q31_sh[6]) and int(q31_sh[7]) == 100 and q31_sh[8] == {"Snowblind": "shop"} and q31_sh[9] == ["Snowblind"] and str(q31_sh[10]) == "Landslide costs 400 HBP (the ledger holds 100)" and str(q31_sh[11]) == "RORY knows Snowblind already" \
		and str(q31_sh[12]) == "Pressure Cooker is not in the HBP shop" \
		and q31_tp[0] == {"Black Ice": 1, "Portage": 1} and int(q31_tp[1]) == 1 and int(q31_tp[2]) == 0 \
		and bool(q31_tp[3]) and q31_tp[4] == {"Portage": "tape"} and q31_tp[5] == ["Portage"] and str(q31_tp[6]) == "the club holds no tape of Portage" and bool(q31_tp[7]) and q31_tp[8] == ["Black Ice"] and q31_tp[9] == {} \
		and q31_tp[10] == [{}, 0])
	# the masters: Whitlock's Eight Count Answer waits on the learner's first survived standing-eight - dropped, up at eight, then taught;
	# Timberfall on the coach questline; the conditioning coach's Roadwork while one is dressed (refused on a board without one); DEX's
	# Prodigal at a Close Friend's bond; CARTER not in the stable, then his Empty Net on SPD 60 (RORY refused, JUNE taught); CASSIDY's
	# Freelance in Arc 3; a master's lesson is free
	var q31d : TNBSim = q31_mk.call("RORY:15,JUNE:15", "hbp:0", "quest:coach_questline")
	var q31_ms: Array = [q31d.lesson_why("WHITLOCK", "RORY", "Eight Count Answer")]
	q31d.new_dual(); freeze_boss(q31d); q31d.freeze_t = 0; place(q31d); clear_defense(q31d.P); q31d.P["comp"] = 0.5; boss_lands(q31d, "R_HOOKERCUT")
	for q31_b in 3:
		var q31_g := 0
		while q31d.mode == "EIGHT" and q31d.eight["timer_t"] > q31d.eight["window_t"] and q31_g < 400: q31d.step({}); q31_g += 1
		if q31d.mode != "EIGHT": break
		q31d.step({"rise": true}); q31d.step({"rise": false})
	q31_ms.append([q31d.mode, count_events(q31d.events, "eight_survived")])
	q31d.mode = "OVER"
	q31_ms.append_array([q31d.lesson("WHITLOCK", "RORY", "Eight Count Answer")["ok"], q31d.lesson("WHITLOCK", "RORY", "Timberfall")["ok"], q31d.learned("RORY"), int(q31d.rewards["hbp"]), q31d.lesson_why("WHITLOCK", "JUNE", "Eight Count Answer")])
	var q31e : TNBSim = q31_mk.call("RORY:15"); q31_ms.append_array([q31e.lesson_why("WHITLOCK", "RORY", "Timberfall"), q31e.lesson_why("CONDITIONING", "RORY", "Roadwork")])
	var q31e2 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_levels({}, "RORY:15", content["economy"]), {"staff": ["janitor", "professor", "tape_man"]}); q31e2.mode = "OVER"
	q31_ms.append(q31e2.lesson_why("CONDITIONING", "RORY", "Roadwork"))
	var q31g : TNBSim = q31_mk.call("RORY:15,DEX:15", "", "", "", "", TNBSim.LINEUP_MILLBROOK_8, "bags:1", "RORY+DEX:24")
	q31_ms.append_array([q31g.lesson_why("DEX", "RORY", "Prodigal"), q31g.lesson_why("CARTER", "RORY", "Empty Net"), q31g.lesson_why("CASSIDY", "RORY", "Freelance"), q31g.lesson_why("DEX", "DEX", "Prodigal")])
	q31g.rewards["kizuna"][TNBSim.pair_key("RORY", "DEX")] = 60
	q31_ms.append(q31g.lesson("DEX", "RORY", "Prodigal")["ok"])
	var q31_cl: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q31_cl.append(q31g.recruit_card("carter_okafor"))
	var q31h : TNBSim = q31_mk.call("RORY:15,JUNE:15", "", "", "", "", q31_cl)
	q31_ms.append_array([q31h.lesson_why("CARTER", "RORY", "Empty Net"), q31h.lesson("CARTER", "JUNE", "Empty Net")["ok"], q31h.learned("JUNE")])
	_sr("the masters (NP_11 s8): Whitlock before the eight '%s', the eight %s, then %s; refused %s; DEX, CARTER, CASSIDY %s; taught %s; CARTER in the stable %s" % [str(q31_ms[0]), JSON.stringify(q31_ms[1]), JSON.stringify(q31_ms.slice(2, 7)), JSON.stringify(q31_ms.slice(7, 10)), JSON.stringify(q31_ms.slice(10, 14)), str(q31_ms[14]), JSON.stringify(q31_ms.slice(15))],
		str(q31_ms[0]) == "Whitlock's Eight Count Answer: RORY has not survived a standing-eight yet" and q31_ms[1] == ["FIGHT", 1] and bool(q31_ms[2]) and bool(q31_ms[3]) \
		and q31_ms[4] == {"Eight Count Answer": "master:WHITLOCK", "Timberfall": "master:WHITLOCK"} and int(q31_ms[5]) == 0 and str(q31_ms[6]) == "Whitlock's Eight Count Answer: JUNE has not survived a standing-eight yet" \
		and str(q31_ms[7]) == "Whitlock's Timberfall: it waits on quest:coach_questline" and str(q31_ms[8]) == "" and str(q31_ms[9]) == "the conditioning coach teaches while one is dressed - no Conditioning coach on the staff" \
		and str(q31_ms[10]) == "DEX's Prodigal: DEX teaches it at Kizuna Lv2 - DEX & RORY are at Lv1" and str(q31_ms[11]) == "CARTER is not in the stable" and str(q31_ms[12]) == "CASSIDY is not in the stable" \
		and str(q31_ms[13]) == "DEX is the master - a lesson needs another learner" and bool(q31_ms[14]) \
		and str(q31_ms[15]) == "CARTER's Empty Net: it wants SPD 60 - RORY has 50" and bool(q31_ms[16]) and q31_ms[17] == {"Empty Net": "master:CARTER"})
	# the re-teach: RORY's bought Snowblind passed to PRIYA in a training slot (the day's count up one, RORY keeping it, "taught:RORY"), then
	# MARCUS, then JUNE; the fourth refused on the day's slots; a card's own move and a native not re-taught; himself; one he knows
	var q31r : TNBSim = q31_mk.call("RORY:15,PRIYA:15,MARCUS:15,JUNE:15", "", "", "RORY:Snowblind")
	var q31_rt: Array = [q31r.training_used(), q31r.reteach("RORY", "PRIYA", "Snowblind")["ok"], q31r.training_used(), q31r.learned("PRIYA"), q31r.learned("RORY"), q31r.kit_moves("PRIYA")]
	q31_rt.append_array([q31r.reteach("*", "MARCUS", "*")["ok"], q31r.reteach("PRIYA", "JUNE", "Snowblind")["ok"], q31r.training_used()])
	var q31r2 : TNBSim = q31_mk.call("RORY:15,PRIYA:15,MARCUS:15,JUNE:15", "", "", "RORY:Snowblind+Landslide+Updraft")
	for q31_i in 3: q31r2.reteach("RORY", "PRIYA", ["Snowblind", "Landslide", "Updraft"][q31_i])
	q31_rt.append_array([q31r2.reteach_why("RORY", "MARCUS", "Snowblind"), q31r2.reteach_why("MARCUS", "RORY", "Chinook Rush"), q31r2.reteach_why("RORY", "RORY", "Snowblind"), q31r2.reteach_why("RORY", "PRIYA", "Snowblind"), count_events(q31r2.events, "retaught")])
	_sr("the re-teach (NP_11 s8): %s; the fourth and the refusals %s" % [JSON.stringify(q31_rt.slice(0, 9)), JSON.stringify(q31_rt.slice(9))],
		int(q31_rt[0]) == 0 and bool(q31_rt[1]) and int(q31_rt[2]) == 1 and q31_rt[3] == {"Snowblind": "taught:RORY"} and q31_rt[4] == {"Snowblind": "seed"} and q31_rt[5] == ["Snowblind"] \
		and bool(q31_rt[6]) and bool(q31_rt[7]) and int(q31_rt[8]) == 3 \
		and str(q31_rt[9]) == "the day's 3 training slots are used (day 1)" and str(q31_rt[10]) == "MARCUS has not learned Chinook Rush to pass on (a card's own move and its natives are not re-taught)" \
		and str(q31_rt[11]) == "RORY is the teacher - the re-teach needs another stablemate" and str(q31_rt[12]) == "PRIYA knows Snowblind already" and int(q31_rt[13]) == 3)
	# the kit in the fight: RORY's LB + PISTON casts his kit's Snowblind (a punch without it), LB + HAYMAKER his own Aurora Borealis Breaker
	# still; PRIYA at level 1 throws a punch where her Marginalia goes at 5; delegated with his own move shut (a relay T3 out of CHARGED),
	# RORY's profile casts his kit's Snowblind and without the kit casts nothing; the save's Fighter records - technique_slots (the card's own, then the kit), native_slots, signature_t0, the slots open,
	# what each learned - written, read, built and written again byte-equal, the built RORY walking out with the same kit
	var q31_arm := func(q31_s: TNBSim, q31_row: String) -> String:
		q31_s.new_dual(); quiet(q31_s); place(q31_s, 1.4); thaw(q31_s); q31_s.tension = 100.0; q31_s.P["busy_t"] = 0; q31_s.P["cmd"] = {}; q31_s.events.clear()
		q31_s.step({"punch": q31_row, "lb": true})
		return str(q31_s.cast["move"]["name"]) if q31_s.cast.size() > 0 else "punch"
	var q31_k: Array = [q31_arm.call(q31_mk.call("RORY:15", "", "", "RORY:Snowblind"), "L_STRAIGHT"), q31_arm.call(q31_mk.call("RORY:15"), "L_STRAIGHT"), q31_arm.call(q31_mk.call("RORY:15", "", "", "RORY:Snowblind"), "R_HOOKERCUT")]
	var q31_pl: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); var q31_pr: Array = [q31_pl[1], q31_pl[0], q31_pl[2], q31_pl[3]]
	q31_k.append_array([q31_arm.call(q31_mk.call("", "", "", "", "", q31_pr), "L_STRAIGHT"), q31_arm.call(q31_mk.call("PRIYA:5", "", "", "", "", q31_pr), "L_STRAIGHT")])
	var q31_rl: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); q31_rl[0]["hissatsu"] = "Relay: Coast to Coast"      # his own move shut (a relay T3, out of CHARGED)
	var q31_ai := func(q31_ln2: String) -> String:
		var q31_s2: TNBSim = q31_mk.call("RORY:15", "", "", q31_ln2, "", q31_rl); q31_s2.delegate_all = true; q31_s2.new_dual()
		thaw(q31_s2); place(q31_s2, 1.5); q31_s2.tension = 100.0; q31_s2.events.clear()
		for q31_j in 2400:
			q31_s2.step({})
			for q31_e in q31_s2.events:
				if str(q31_e["kind"]) == "cast" and str(q31_e["who"]) == "P": return str(q31_e["move"])
			q31_s2.events.clear()
		return "none"
	q31_k.append_array([q31_ai.call("RORY:Snowblind"), q31_ai.call("")])
	var q31v : TNBSim = q31_mk.call("RORY:15,PRIYA:5,YURI:5", "", "blessing:kowalchuk", "RORY:Snowblind+Cornerstone,YURI:Updraft", "", TNBSim.LINEUP_MILLBROOK_8)
	for q31_n2 in q31v.learned_natives("YURI"): q31v.kit_equip("YURI", str(q31_n2))
	var q31_sv: Dictionary = TNBSave.to_save(q31v)
	var q31_recs := {}
	for q31_rc in q31_sv["stable"]: q31_recs[str(q31_rc["name"])] = q31_rc
	var q31_tx: String = TNBSave.write_text(q31v, false)
	var q31vl: TNBSim = TNBSave.build(content, TNBSave.read_text(q31_tx), 7)["sim"]
	var q31_rr: Dictionary = q31_recs["RORY"]; var q31_pp: Dictionary = q31_recs["PRIYA"]; var q31_yy: Dictionary = q31_recs["YURI"]
	_sr("the kit in the fight and the save (NP_11 s9): LB + PISTON %s / without %s, LB + HAYMAKER %s; PRIYA at 1 %s, at 5 %s; RORY's profile with his own move shut %s / without the kit %s; RORY's record %s, PRIYA's %s, YURI's %s; written back %s, the built RORY's kit %s" % [q31_k[0], q31_k[1], q31_k[2], q31_k[3], q31_k[4], q31_k[5], q31_k[6], JSON.stringify([q31_rr["technique_slots"], q31_rr["signature_t0"], q31_rr["slots_open"], q31_rr["learned"]]), JSON.stringify([q31_pp["technique_slots"], q31_pp["signature_t0"], q31_pp["slots_open"]]), JSON.stringify([q31_yy["technique_slots"], q31_yy["native_slots"]]), "byte-equal" if TNBSave.write_text(q31vl, false) == q31_tx else "DIFFERENT", JSON.stringify(q31vl.P.get("kit", []))],
		q31_k.slice(0, 5) == ["Snowblind", "punch", "Aurora Borealis Breaker", "punch", "Marginalia"] and str(q31_k[5]) == "Snowblind" and str(q31_k[6]) == "none" \
		and q31_rr["technique_slots"] == ["Aurora Borealis Breaker", "Snowblind"] and str(q31_rr["signature_t0"]) == "Cornerstone" and int(q31_rr["slots_open"]) == 2 and q31_rr["learned"] == {"Snowblind": "seed", "Cornerstone": "seed"} \
		and q31_pp["technique_slots"] == ["Marginalia"] and str(q31_pp["signature_t0"]) == "Marginalia" and int(q31_pp["slots_open"]) == 1 \
		and q31_yy["technique_slots"] == ["Grain Elevator", "Updraft"] and q31_yy["native_slots"].size() >= 1 \
		and TNBSave.write_text(q31vl, false) == q31_tx and q31vl.P.get("kit", []) == ["Snowblind", "Cornerstone"])


	# ---- PAC-092: THE ACADEMY'S SYNTHESES (NP_07 s10, Arc 3's thesis) ----
	var q32_ac: Dictionary = content["academy"]
	var q32_lu: Array = []
	for q32_nm in ["YURI", "MARTA", "RORY", "PRIYA"]:
		for q32_c in TNBSim.LINEUP_MILLBROOK_8:
			if str(q32_c["name"]) == q32_nm:
				var q32_cc: Dictionary = q32_c.duplicate(true); q32_cc.erase("reserve"); q32_lu.append(q32_cc)
	q32_lu[3]["reserve"] = true
	var q32_mk := func(q32_forge: bool, q32_seed: int = 7) -> TNBSim:
		var q32_s := make_sim(1, q32_seed, q32_lu, "", {}, TNBSim.seed_facilities(TNBSim.seed_purse(TNBSim.parse_kizuna_arg("YURI+MARTA:150"), "spirits:40,beans:30"), "wall:3", content["facilities"]))
		if q32_forge: q32_s.forge("YURI", "MARTA")
		q32_s.field_academy(true); q32_s.new_dual()
		return q32_s
	# the academy as data: the club, Director Vey's corner, the price-down (x0.85) and three a prodigy; five prodigies, fifteen house pairs,
	# every house with natives in two or more; a prodigy's card - a generic on his house's dialect with the house left out, tier 3, his pairs
	var q32_pairs := {}; var q32_hs := {}
	for q32_p in q32_ac["prodigies"]:
		for q32_sp in q32_p["syntheses"]:
			var q32_k: Array = [str(q32_sp[0]), str(q32_sp[1])]; q32_k.sort(); q32_pairs["%s|%s" % q32_k] = true
			for q32_h in q32_k: q32_hs[q32_h] = int(q32_hs.get(q32_h, 0)) + 1
	var q32_nat := {}
	for q32_mn in content["library"]:
		var q32_m: Dictionary = content["library"][q32_mn]
		if q32_m.get("house_id") != null and str(q32_m["house_id"]) != "sealed" and not bool(q32_m.get("secret", false)): q32_nat[str(q32_m["house_id"])] = true
	var q32a : TNBSim = q32_mk.call(false)
	var q32_sp0: Dictionary = q32a.prodigy_spec(0); var q32_sp5: Dictionary = q32a.prodigy_spec(5)
	var q32_d: Array = [str(q32_ac["club"]), str(q32_ac["coach"]), float(q32_ac["synthesis"]["dmg_mult"]), int(q32_ac["synthesis"]["per_fighter"]), q32_ac["prodigies"].map(func(q32_x): return [str(q32_x["name"]), str(q32_x["style"]), str(q32_x["dialect"]), q32_x["syntheses"].size()]), q32_pairs.size(), q32_hs.size(), q32_nat.size(), q32_hs.values().filter(func(q32_v): return int(q32_v) < 2).size()]
	q32_d.append([str(q32_sp0["name"]), str(q32_sp0["style"]), str(q32_sp0["dialect"]), str(q32_sp0["element"]), str(q32_sp0["house"]), int(q32_sp0["tier"]), q32_sp0["synth"].size(), str(q32_sp5["name"])])
	_sr("the academy as data (NP_07 s10): %s; %d house pairs over %d houses (of %d with natives, %d in fewer than two); a prodigy's card %s" % [JSON.stringify(q32_d.slice(0, 5)), int(q32_d[5]), int(q32_d[6]), int(q32_d[7]), int(q32_d[8]), JSON.stringify(q32_d[9])],
		str(q32_d[0]) == "Toronto Ascendant Academy" and str(q32_d[1]) == "ascendant_a" and absf(float(q32_d[2]) - 0.85) < 0.0001 and int(q32_d[3]) == 3 and q32_d[4].size() == 5 and q32_d[4].filter(func(q32_y): return int(q32_y[3]) == 3).size() == 5 \
		and int(q32_d[5]) == 15 and int(q32_d[6]) == 12 and int(q32_d[7]) == 12 and int(q32_d[8]) == 0 \
		and q32_d[9] == ["ASCENDANT 1", "SWARMER", "okafor", "GALE", "none", 3, 3, "ASCENDANT 1"])
	# the composer's industrial rule: Kowalchuk x Tremblay synthesized against the club's Grain & Snow of the same houses - the same family
	# and tags, the damage 2.5 x0.85 = 2.13; the composer's own reading of the library's natives (2.5) priced down; its record (T3 at 50, the
	# academy's source and VFX, no pair, no afterimage state, interruptible in its windup); breadth - fifteen distinct across the squad
	# against the Forge's ceiling of eight, every one under the T3 floor a forged hybrid starts at
	var q32_sy: Dictionary = q32a.synthesize("tremblay", "kowalchuk")
	var q32_gs: Dictionary = content["library"]["Grain & Snow"]
	var q32_pt: Dictionary = q32a._compose_parts([["kowalchuk", q32a.house_natives("kowalchuk")], ["tremblay", q32a.house_natives("tremblay")]])
	var q32_all: Array = []
	for q32_i in 5:
		for q32_pp in q32a.prodigy_spec(q32_i)["synth"]: q32_all.append(q32a.synthesize(str(q32_pp[0]), str(q32_pp[1])))
	var q32_names := {}
	for q32_m2 in q32_all: q32_names[str(q32_m2["name"])] = true
	var q32_pw: Array = q32_all.map(func(q32_m3): return q32a._synth_power(q32_m3))
	var q32_ai := false
	for q32_e in q32_sy["effect"]:
		if str(q32_e["type"]) == "STATE" and str(q32_e["params"]["name"]).begins_with("afterimage"): q32_ai = true
	var q32_c1: Array = [str(q32_sy["name"]), str(q32_sy["family"]), str(q32_gs["family"]), q32a._synth_power(q32_sy), q32a._synth_power(q32_gs), float(q32_pt["dmg"]), TNBSim._whole(q32_sy["effect"].slice(1)) == TNBSim._whole(q32_gs["effect"].slice(1)), str(q32_sy["tier"]), int(q32_sy["tension_cost"]), str(q32_sy["source"]), str(q32_sy["vfx_set"]), q32_sy.has("hybrid_of"), q32_ai, bool(q32_sy["counter_profile"]["interruptible"]), int(q32_sy["counter_profile"]["window_ms"])]
	_sr("the synthesis (NP_07 s10: slightly weaker per move, overwhelming in breadth): %s; the squad's %d syntheses (%d distinct, the Forge's ceiling %d), x%s to x%s" % [JSON.stringify(q32_c1), q32_all.size(), q32_names.size(), int(content["hybrids"]["ceiling"]), TNBSim._n(q32_pw.min()), TNBSim._n(q32_pw.max())],
		q32_c1.slice(0, 3) == ["Synthesis Grain-Snow", "HAYMAKER", "HAYMAKER"] and absf(float(q32_c1[3]) - 2.13) < 0.0001 and absf(float(q32_c1[4]) - 2.5) < 0.0001 and absf(float(q32_c1[5]) - 2.5) < 0.0001 and bool(q32_c1[6]) \
		and q32_c1.slice(7) == ["T3", 50, "synthesis:academy", "vfx_synth", false, false, true, 700] \
		and q32_all.size() == 15 and q32_names.size() == 15 and int(content["hybrids"]["ceiling"]) == 8 and float(q32_pw.max()) < float(content["hybrids"]["compose"]["dmg_floor"]))
	# the enemy's rule: at his decision point with 60 in his bar and within reach, ASCENDANT 1 casts his first synthesis (the bar 60 -> 10),
	# the next time his second (the rotation); with 40 nothing; out of reach nothing; a jab in the windup breaks it (his bar spent)
	var q32_go := func(q32_s2: TNBSim, q32_bar: float, q32_d2: float) -> String:
		quiet(q32_s2); place(q32_s2, q32_d2); clear_defense(q32_s2.P); q32_s2.cast = {}
		q32_s2.btension = q32_bar; q32_s2.bstate = "IDLE"; q32_s2.btimer = 1
		q32_s2.step({})
		return str(q32_s2.cast["move"]["name"]) if q32_s2.cast.size() > 0 and str(q32_s2.cast["who"]) == "B" else "none"
	var q32b : TNBSim = q32_mk.call(false)
	var q32_rt: Array = [q32_go.call(q32b, 60.0, 1.2), q32b.btension]
	resolve_cast(q32b)
	q32_rt.append_array([q32_go.call(q32b, 60.0, 1.2), q32_go.call(q32b, 40.0, 1.2), q32_go.call(q32b, 60.0, 3.5), int(q32b.B.get("synth_casts", 0))])
	var q32c : TNBSim = q32_mk.call(false)
	q32_go.call(q32c, 60.0, 1.2); q32c.events.clear()
	throw_clean(q32c, "L_STRAIGHT")
	q32_rt.append_array([count_events(q32c.events, "cast_interrupted", {"who": "B"}), q32c.cast.is_empty(), q32c.btension])
	var q32_s0: Array = q32b.B["synth"].map(func(q32_m4): return str(q32_m4["name"]))
	_sr("the academy's cast rule: %s, the bar after %s; then %s; at 40 %s; out of reach %s; %d syntheses cast; a jab in the windup %s" % [str(q32_rt[0]), TNBSim._n(float(q32_rt[1])), str(q32_rt[2]), str(q32_rt[3]), str(q32_rt[4]), int(q32_rt[5]), JSON.stringify(q32_rt.slice(6))],
		str(q32_rt[0]) == str(q32_s0[0]) and absf(float(q32_rt[1]) - 10.0) < 0.001 and str(q32_rt[2]) == str(q32_s0[1]) and str(q32_rt[3]) == "none" and str(q32_rt[4]) == "none" and int(q32_rt[5]) == 2 \
		and int(q32_rt[6]) == 1 and bool(q32_rt[7]) and absf(float(q32_rt[8]) - 10.0) < 0.001)
	# the matchup: the academy fielded - ASCENDANT 1, 2, 3 against the club, Director Vey's corner; the ACADEMY line; the THESIS line sets the
	# club's forged Grain & Snow (YURI & MARTA) against his best synthesis - R1 YURI (x3.13 relayed), R2 MARTA relayed now with YURI's
	# afterimage, her live hybrid x3.13 against his x2.04; refused mid-dual; off between duals, Yuri's squad and his corner again
	var q32d : TNBSim = q32_mk.call(true)
	var q32_mt: Array = [q32d.blineup, str(q32d.coach.get("id", "")), q32d.academy_line(), q32d.thesis_line()]
	var q32_dr: Array = q32d.bdressed.duplicate(); q32_dr.sort(); var q32_bn: Array = q32d.breserves.duplicate()
	q32d.mode = "FIGHT"; q32d.eight = {}; q32d.ep_p += 4; q32d._end_segment("drive")
	if q32d.mode == "CARD": q32d.step({"corner": 1})
	if q32d.mode == "CORNER": q32d.step({"corner": 1})
	q32_mt.append_array([q32d.pname(), q32d.boss_label, q32d.thesis_line(), q32d._synth_power(q32d.hybrid_move())])
	q32d.step({}); q32_mt.append(str(q32d.field_academy(false)["why"]))
	q32d.mode = "OVER"; q32_mt.append(bool(q32d.field_academy(false)["ok"])); q32d.new_dual(); q32_mt.append_array([q32d.blineup[0], str(q32d.coach.get("id", "")), q32d.B.has("synth"), q32d.thesis_line()])
	_sr("the matchup (NP_07 s10's melting-pot argument): %s; dressed %s, the bench %s; R2 %s vs %s: '%s' (her hybrid x%s); mid-dual '%s'; off %s" % [JSON.stringify(q32_mt.slice(0, 4)), JSON.stringify(q32_dr), JSON.stringify(q32_bn), str(q32_mt[4]), str(q32_mt[5]), str(q32_mt[6]), TNBSim._n(float(q32_mt[7])), str(q32_mt[8]), JSON.stringify(q32_mt.slice(9))],
		q32_mt[0] == ["ASCENDANT 1", "ASCENDANT 2", "ASCENDANT 3"] and str(q32_mt[1]) == "ascendant_a" and q32_dr == ["ASCENDANT 1", "ASCENDANT 2", "ASCENDANT 3"] and q32_bn.is_empty() \
		and str(q32_mt[2]) == "ACADEMY: ASCENDANT 1 carries 3 syntheses - Synthesis Tide-Heat (LB + HAYMAKER, x2.04), Synthesis Heat-Bell (LB + ARC, x2.04), Synthesis Heat-Light (LB + ARC, x2.04) - no bond, no afterimage, no history" \
		and str(q32_mt[3]) == "THESIS: your forged Grain & Snow (MARTA & YURI) x2.5 (x3.13 relayed) against his best synthesis Synthesis Tide-Heat x2.04" \
		and str(q32_mt[4]) == "MARTA" and str(q32_mt[5]) == "ASCENDANT 2" and str(q32_mt[6]) == "THESIS: your forged Grain & Snow (MARTA & YURI) x2.5 - relayed now, x3.13 with YURI's afterimage against his best synthesis Synthesis Bridge-Snow x2.04" and absf(float(q32_mt[7]) - 3.125) < 0.0001 \
		and str(q32_mt[8]) == "the squad is set between duals" and bool(q32_mt[9]) and str(q32_mt[10]) == "yuri_kowalchuk" and str(q32_mt[11]) == "grain_kings" and not bool(q32_mt[12]) and str(q32_mt[13]) == "")
	# the save: fielded between duals, the settings name the academy; written, read, built and written again byte-equal, the built sim's
	# squad the academy's; a DualState taken after ASCENDANT 1's first synthesis restores into a sim built otherwise on the same hash, his
	# rotation where it was
	var q32e : TNBSim = q32_mk.call(true); q32e.mode = "OVER"
	var q32_tx: String = TNBSave.write_text(q32e, false)
	var q32el: TNBSim = TNBSave.build(content, TNBSave.read_text(q32_tx), 7)["sim"]
	var q32f : TNBSim = q32_mk.call(false); q32_go.call(q32f, 60.0, 1.2); resolve_cast(q32f); for q32_j in 30: q32f.step({})
	var q32_sn: Dictionary = q32f.snapshot(); var q32_hf: int = q32f.hash_state()
	var q32g := make_sim(3, 999, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q32_rs: Dictionary = q32g.restore(q32_sn)
	_sr("the save: settings %s, written back %s, the built squad %s (%s); the DualState after a synthesis restored %s on the same hash (%s), his rotation at %d" % [JSON.stringify(TNBSave.to_save(q32e)["settings"]), "byte-equal" if TNBSave.write_text(q32el, false) == q32_tx else "DIFFERENT", JSON.stringify(q32el.blineup), str(q32el.coach.get("id", "")), str(q32_rs.get("ok", false)), str(q32g.hash_state() == q32_hf), int(q32g.B.get("synth_i", -1))],
		bool(TNBSave.to_save(q32e)["settings"].get("academy", false)) and TNBSave.write_text(q32el, false) == q32_tx and q32el.academy_on and q32el.blineup == ["ASCENDANT 1", "ASCENDANT 2", "ASCENDANT 3"] and str(q32el.coach.get("id", "")) == "ascendant_a" \
		and bool(q32_rs.get("ok", false)) and q32g.hash_state() == q32_hf and int(q32g.B.get("synth_i", -1)) == 1 and q32g.academy_on)


	# ---- PAC-093: THE MIRROR SPAR (NP_02 s2.2: the adaptation tracker turned into content) ----
	var q33_mr: Dictionary = content["bouts"]["spar"]["mirror"]
	var q33_led := func(q33_h: String, q33_fac: String = "ring:1") -> Dictionary:
		return TNBSim.seed_facilities(TNBSim.seed_habits({}, q33_h), q33_fac, content["facilities"])
	var q33_hab := "RORY:L_STRAIGHT+L_STRAIGHT+R_STRAIGHT*8,RORY:L_HOOK+R_HOOK*5,RORY:counter=R_HOOK*4/6"
	# the record: the tracker's tokens kept for the fighter out - the punches by row, a feint apart, every two- and three-token sequence,
	# the ones it read (its flag at the third), a counter window his slip opened and the punch thrown into it; the segment's tracker
	# cleared at the next bell, the record kept; the next fighter's under his own name
	var q33a : TNBSim = make_sim(1, 7); quiet(q33a); place(q33a, 1.2)
	for q33_i in 3:
		for q33_r in ["L_STRAIGHT", "L_STRAIGHT", "R_STRAIGHT"]: throw_clean(q33a, q33_r)
	thaw(q33a); q33a.P["busy_t"] = 0; q33a.P["cmd"] = {}
	q33a.step({"punch": "L_HOOK"}); q33a.step({"punch_release": true}); land(q33a)
	clear_defense(q33a.P); q33a.P["dodge"] = "SLIP"; q33a.P["dodge_t"] = 30; q33a.P["busy_t"] = 0
	var q33_c0 := int(q33a.habits_of("RORY").get("chances", 0))
	q33a.B["pos"] = Vector2(0.0, -2.4); boss_lands(q33a, "R_STRAIGHT"); clear_defense(q33a.P); q33a.B["pos"] = Vector2(0.0, -0.6)
	var q33_cw: int = int(q33a.P["counter_t"])
	throw_clean(q33a, "R_HOOK")
	var q33_ha: Dictionary = q33a.habits_of("RORY").duplicate(true)
	var q33_tk0: int = q33a.tokens.size(); var q33_tkl: Array = q33a.tokens.duplicate()
	q33a.mode = "FIGHT"; q33a.eight = {}; q33a.ep_p += 4; q33a._end_segment("drive"); next_segment(q33a); quiet(q33a); place(q33a, 1.2)
	throw_clean(q33a, "R_UPPERCUT")
	var q33_r1: Array = [int(q33_ha["punches"]), int(q33_ha["feints"]), q33_ha["rows"], int(q33_ha["grams"].get("L_STRAIGHT,L_STRAIGHT,R_STRAIGHT", 0)), int(q33_ha["grams"].get("L_STRAIGHT,L_STRAIGHT", 0)), int(q33_ha["grams"].get("R_STRAIGHT,L_STRAIGHT,L_STRAIGHT", 0)), q33_ha["reads"].keys(), int(q33_ha["chances"]) - q33_c0, q33_cw > 0, q33_ha["counters"]]
	q33_r1.append([q33_ha["grams"].has("R_STRAIGHT,F_L_HOOK"), q33_ha["grams"].has("R_STRAIGHT,L_HOOK"), q33_ha["grams"].has("F_L_HOOK,R_HOOK"), q33_tkl.has("L_HOOK")])
	q33_r1.append_array([q33_tk0, q33a.tokens.size(), q33a.pname(), int(q33a.habits_of(q33a.pname()).get("punches", 0)), int(q33a.habits_of("RORY").get("punches", 0))])
	_sr("the record (the tracker's, kept): %s; the feint kept once, as the tracker keeps it (the sequences through it; its start taken back, the tracker's too) %s; the tracker %d tokens -> %d at the next bell, %s's own record %d, RORY's still %d" % [JSON.stringify(q33_r1.slice(0, 10)), JSON.stringify(q33_r1[10]), int(q33_r1[11]), int(q33_r1[12]), str(q33_r1[13]), int(q33_r1[14]), int(q33_r1[15])],
		int(q33_r1[0]) == 10 and int(q33_r1[1]) == 1 and q33_r1[2] == {"L_STRAIGHT": 6, "R_STRAIGHT": 3, "R_HOOK": 1} and int(q33_r1[3]) == 3 and int(q33_r1[4]) == 3 and int(q33_r1[5]) == 2 \
		and q33_r1[6].has("L_STRAIGHT,L_STRAIGHT,R_STRAIGHT") and not q33_r1[6].has("R_STRAIGHT,L_STRAIGHT,L_STRAIGHT") and int(q33_r1[7]) == 1 and bool(q33_r1[8]) and q33_r1[9] == {"R_HOOK": 1} and q33_r1[10] == [true, false, true, false] \
		and int(q33_r1[11]) > 0 and int(q33_r1[12]) == 1 and str(q33_r1[13]) != "RORY" and int(q33_r1[14]) == 1 and int(q33_r1[15]) == 10)
	# the copy: his most-thrown sequences as its strings (thrown x length; one inside a string taken skipped; under the tracker's count
	# none), their shares of the Style's preset as its SELECT, normal class on the channel at the tier's loudness, the Style's punish on
	# them; its reads by his reads, his counter at his rate; the same record the same pattern in another sim, another record another copy;
	# every action a verb the VM runs (the lead hookercut and overhand, a feint's pause); no record, the Style's strings as C44's mirror
	var q33b : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab + ",RORY:L_STRAIGHT+L_STRAIGHT*5,RORY:R_UPPERCUT+R_HOOK*2"))
	var q33_cp: Dictionary = q33b.habit_copy("RORY")
	var q33_mc: Dictionary = q33b.mirror_card("RORY")
	var q33_pt: Dictionary = TNBAssembler.assemble(q33b.PIECES, q33b.spec_from_card(q33_mc))
	var q33c : TNBSim = make_sim(3, 99, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab + ",RORY:L_STRAIGHT+L_STRAIGHT*5,RORY:R_UPPERCUT+R_HOOK*2"))
	var q33_pt2: Dictionary = TNBAssembler.assemble(q33c.PIECES, q33c.spec_from_card(q33c.mirror_card("RORY")))
	var q33_h3 := "RORY:L_HOOK+R_HOOK*12,RORY:F_L_STRAIGHT+L_HOOKERCUT+L_FLARED*4,RORY:R_UPPERCUT+L_HOOK*3"
	var q33d : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_h3))
	var q33_pt3: Dictionary = TNBAssembler.assemble(q33d.PIECES, q33d.spec_from_card(q33d.mirror_card("RORY")))
	var q33d2 : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_growth(q33_led.call(q33_h3), "RORY:rarity:2"))
	var q33_pt4: Dictionary = TNBAssembler.assemble(q33d2.PIECES, q33d2.spec_from_card(q33d2.mirror_card("RORY")))
	var q33_vb: Array = []
	for q33_k in q33_pt3["strings"]:
		for q33_a in q33_pt3["strings"][q33_k]["actions"]: q33_vb.append([str(q33_a), q33d.parse_action(str(q33_a)).map(func(q33_x): return str(q33_x.get("row", q33_x["kind"])))])
	var q33e : TNBSim = make_sim(1, 7)
	var q33_ec: Dictionary = q33e.mirror_card("RORY")
	var q33_ep: Dictionary = TNBAssembler.assemble(q33e.PIECES, q33e.spec_from_card(q33_ec))
	var q33_c44: Dictionary = q33_ec.duplicate(true); q33_c44.erase("mirror_of"); q33_c44.erase("learned_from")
	var q33_cov: Dictionary = q33b.pattern_coverage({"RORY'S MIRROR": q33_pt})
	var q33_st: Array = q33_pt["strings"].keys().map(func(q33_k2): return [str(q33_k2), str(q33_pt["strings"][q33_k2]["label"]), q33_pt["strings"][q33_k2]["actions"], str(q33_pt["strings"][q33_k2]["class"]), int(q33_pt["strings"][q33_k2]["tell"]["ms"]), str(q33_pt["strings"][q33_k2]["tell"]["channel"])])
	_sr("the copy (NP_02 s2.2): %s, SELECT %s, punish %s, interrupt %s; reads %s, counter %s; in another sim %s; another record %s -> %s, at Circuit (tier 2) %s; no record: %s, its strings the Style's %s; coverage carried %d" % [JSON.stringify(q33_st), JSON.stringify(q33_pt["select"]["weights"]), JSON.stringify(q33_pt["punish"].map(func(q33_p): return [q33_p["trigger"], q33_p["response"]])), JSON.stringify(q33_pt["interrupt"]), JSON.stringify(q33_mc.get("mirror_reads", [])), JSON.stringify(q33_mc.get("mirror_counter", [])),
		"byte-equal" if JSON.stringify(q33_pt2) == JSON.stringify(q33_pt) else "DIFFERENT", JSON.stringify(q33_pt3["strings"].keys().map(func(q33_k3): return str(q33_pt3["strings"][q33_k3]["label"]))), JSON.stringify(q33_vb), JSON.stringify(q33_pt4["strings"].keys().map(func(q33_k8): return str(q33_pt4["strings"][q33_k8]["label"]))), JSON.stringify(q33_c44.keys()), JSON.stringify(q33_ep["strings"].keys().map(func(q33_k4): return str(q33_ep["strings"][q33_k4].get("piece", "")))), q33_cov["meta"]["carried"].size()],
		q33_cp["strings"].size() == 2 and q33_st == [["S1", "HABIT JAB > JAB > R_STR", ["JAB", "JAB", "R_STR"], "normal", 600, "visual-body"], ["S2", "HABIT L_HOOK > R_HOOK", ["L_HOOK", "R_HOOK"], "normal", 600, "visual-body"]] \
		and q33_pt["select"]["weights"] == {"S1": 71, "S2": 29} and str(q33_pt["punish"][0]["response"]).ends_with("S1") and q33_pt["interrupt"][0]["strings"] == ["S1", "S2"] \
		and q33_mc.get("mirror_reads", []) == [["L_STRAIGHT,L_STRAIGHT,R_STRAIGHT", 3], ["L_HOOK,R_HOOK", 3], ["L_STRAIGHT,L_STRAIGHT", 3]] and q33_mc.get("mirror_counter", []) == ["R_HOOK", 0.67] \
		and JSON.stringify(q33_pt2) == JSON.stringify(q33_pt) and str(q33_pt3["strings"]["S1"]["label"]) == "HABIT L_HOOK > R_HOOK" and str(q33_pt3["strings"]["S2"]["label"]) == "HABIT feint JAB > L_HAY > L_OVERHAND" \
		and q33_vb.slice(2) == [["DELAY(200)", ["wait"]], ["L_HAY", ["L_HOOKERCUT"]], ["L_OVERHAND", ["L_FLARED"]]] and q33_pt3["strings"].size() == 2 \
		and q33_pt4["strings"].keys().map(func(q33_k9): return str(q33_pt4["strings"][q33_k9]["label"])) == ["HABIT L_HOOK > R_HOOK", "HABIT feint JAB > L_HAY > L_OVERHAND", "HABIT R_UPC > L_HOOK"] \
		and not q33_ec.has("habits") and not q33_ec.has("mirror_reads") and not q33_ec.has("mirror_counter") and int(q33_ec["learned_from"]) == 0 and q33_c44.keys().size() == q33e.mirror_card("PRIYA").keys().size() - 2 \
		and q33_ep["strings"].keys().filter(func(q33_k5): return str(q33_ep["strings"][q33_k5].get("piece", "")) == "habit").is_empty() and q33_cov["meta"]["carried"].is_empty())
	# the lab's flag and the bell: refused below The Ring's T1 (a plain spar against Yuri); at T1 RORY against RORY'S MIRROR - the
	# copy's strings, its tracker already reading his sequences at 3, his counter armed; the matchup card's MIRROR line
	var q33f : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab, ""))
	var q33_f0: Array = [q33f.start_spar(1, ["mirror"]), q33f.boss_label, q33f.bout.get("flags", []), count_events(q33f.events, "lab_refused")]
	var q33g : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab))
	q33g.events.clear()
	var q33_g0: Array = [q33g.start_spar(1, ["mirror"]), q33g.pname(), q33g.boss_label, str(q33g.bout["label"]), q33g.bout["flags"], q33g.pattern["strings"].keys().map(func(q33_k6): return str(q33g.pattern["strings"][q33_k6]["label"])), q33g.flags.duplicate(true), str(q33g.B["mirror"]["counter"]), float(q33g.B["mirror"]["counter_p"]), count_events(q33g.events, "mirror"), q33g.mirror_line()]
	_sr("the lab's flag and the bell: at T0 %s; at T1 %s" % [JSON.stringify(q33_f0), JSON.stringify(q33_g0)],
		bool(q33_f0[0]) and str(q33_f0[1]) == "yuri_kowalchuk" and q33_f0[2].is_empty() and int(q33_f0[3]) == 1 \
		and bool(q33_g0[0]) and str(q33_g0[1]) == "RORY" and str(q33_g0[2]) == "RORY'S MIRROR" and str(q33_g0[3]) == "MIRROR SPAR - RORY" and q33_g0[4] == ["mirror"] and q33_g0[5] == ["HABIT JAB > JAB > R_STR", "HABIT L_HOOK > R_HOOK"] \
		and q33_g0[6] == {"L_STRAIGHT,L_STRAIGHT,R_STRAIGHT": [3, 0], "L_HOOK,R_HOOK": [3, 0]} and str(q33_g0[7]) == "R_HOOK" and absf(float(q33_g0[8]) - 0.67) < 0.001 and int(q33_g0[9]) == 1 \
		and str(q33_g0[10]) == "MIRROR: RORY'S MIRROR learned from 34 punches - throws HABIT JAB > JAB > R_STR (71%), HABIT L_HOOK > R_HOOK (29%); reads JAB > JAB > R_STR (3), L_HOOK > R_HOOK (3) from the bell; counters with your R_HOOK (67%)")
	# his read and his answer (C7, D3): with JAB > JAB > R_STR thrown, the tracker already at 3 - his read 3.5 times an unread sequence's;
	# his offense byte-identical; the reads fade in 24 s unrepeated like any read; his read makes a jab miss and he answers with R_HOOK
	# (at the rate 1 always, at 0 never)
	var q33h : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab))
	q33h.start_spar(1, ["mirror"]); quiet(q33h); place(q33h, 1.2)
	var q33_off0 := JSON.stringify([q33h.pattern["strings"], q33h.pattern["select"]])
	for q33_r2 in ["L_STRAIGHT", "L_STRAIGHT", "R_STRAIGHT"]: throw_clean(q33h, q33_r2)
	var q33_rh := [q33h._flag_tier(), q33h.read_prob(q33h._flag_tier(), false, false, false)]
	throw_clean(q33h, "L_UPPERCUT")
	q33_rh.append_array([q33h._flag_tier(), q33h.read_prob(q33h._flag_tier(), false, false, false), JSON.stringify([q33h.pattern["strings"], q33h.pattern["select"]]) == q33_off0])
	for q33_j in TNBSim.ms(24100): q33h.step({})
	q33_rh.append(q33h.flags.has("L_HOOK,R_HOOK"))
	var q33_ans := func(q33_rate: float) -> Array:
		var q33_s : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab))
		q33_s.start_spar(1, ["mirror"]); quiet(q33_s); place(q33_s, 1.2); q33_s.B["mirror"]["counter_p"] = q33_rate
		q33_s.flags["L_STRAIGHT,L_STRAIGHT"] = [3, 0]
		throw_clean(q33_s, "L_STRAIGHT"); thaw(q33_s); q33_s.events.clear(); q33_s.P["busy_t"] = 0; q33_s.P["cmd"] = {}
		q33_s.step({"punch": "L_STRAIGHT"}); land(q33_s)
		var q33_q: Array = q33_s.bqueue.duplicate(true)
		return [count_events(q33_s.events, "whiff", {"by": "P"}), count_events(q33_s.events, "mirror_counter"), q33_q.slice(0, 1).map(func(q33_x2): return [str(q33_x2["row"]), float(q33_x2["mult"])]), q33_s.bstate]
	var q33_a1: Array = q33_ans.call(1.0); var q33_a0: Array = q33_ans.call(0.0)
	_sr("his read and his answer (C7's read, defense only): on his sequence tier %d, read %s; unread tier %d, read %s; offense byte-identical %s; the reads after 24 s unrepeated %s; your counter at the rate 1 %s, at 0 %s" % [int(q33_rh[0]), TNBSim._n(float(q33_rh[1])), int(q33_rh[2]), TNBSim._n(float(q33_rh[3])), str(q33_rh[4]), "held" if bool(q33_rh[5]) else "gone", JSON.stringify(q33_a1), JSON.stringify(q33_a0)],
		int(q33_rh[0]) == 3 and int(q33_rh[2]) == 0 and absf(float(q33_rh[1]) - 1.05) < 0.001 and absf(float(q33_rh[3]) - 0.3) < 0.001 and bool(q33_rh[4]) and not bool(q33_rh[5]) \
		and int(q33_a1[0]) == 1 and int(q33_a1[1]) == 1 and q33_a1[2] == [["R_HOOK", 1.3]] and int(q33_a0[0]) == 1 and int(q33_a0[1]) == 0 and str(q33_a0[3]) != "ACTING")
	# the spar's end and the save: won, the Legend's trial marked (C44's mirror) and no Pattern Intel (a plain spar ticks it); the record
	# learning in the mirror spar too; the record written back byte-equal; a DualState after the bell restored into a sim built otherwise
	# on the same hash, the copy's strings and its reads in it; the aid - a mirror spar for the first card with a record, then back; a
	# mirror spar with an objective judged as any spar's (C17: reach the segment's end)
	var q33i : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab))
	q33i.start_spar(1, ["mirror"]); quiet(q33i); place(q33i, 1.2); throw_clean(q33i, "R_HOOK")
	var q33_pi0: Dictionary = q33i.pi.duplicate(true)
	q33i.score_p = 1; q33i._end_bout()
	var q33j : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab)); q33j.start_spar(1, []); q33j.score_p = 1; q33j._end_bout()
	var q33_en: Array = [q33i._grow("RORY").get("trials", {}).keys(), q33i.pi == q33_pi0, q33j.pi.get("spars", {}).size() > 0 or q33j.pi != make_sim(1, 7).pi, int(q33i.habits_of("RORY")["punches"])]
	q33i.end_bout(); q33i.mode = "OVER"
	var q33_tx: String = TNBSave.write_text(q33i, false)
	var q33_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q33_tx), 7)["sim"]
	var q33k : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab)); q33k.start_spar(1, ["mirror"]); for q33_j2 in 240: q33k.step({})
	var q33_sn: Dictionary = q33k.snapshot(); var q33_hk: int = q33k.hash_state()
	var q33l := make_sim(3, 999, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var q33_rs: Dictionary = q33l.restore(q33_sn)
	q33_en.append_array(["byte-equal" if TNBSave.write_text(q33_bl, false) == q33_tx else "DIFFERENT", q33_bl.habits_of("RORY") == q33i.habits_of("RORY"), bool(q33_rs.get("ok", false)), q33l.hash_state() == q33_hk, q33l.pattern["strings"].keys().map(func(q33_k7): return str(q33l.pattern["strings"][q33_k7]["label"])), q33l.flags.keys().size() == q33k.flags.keys().size()])
	var q33m : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab + ",PRIYA:R_STRAIGHT+L_HOOK*4")); q33m.mode = "OVER"
	var q33_ai: Array = [q33m.mirror_aid("*"), q33m.boss_label]; q33m.mode = "OVER"
	q33_ai.append_array([q33m.mirror_aid("*"), q33m.bout.is_empty(), q33m.mode]); q33m.mode = "OVER"
	q33_ai.append_array([q33m.mirror_aid("*"), q33m.boss_label])
	var q33n : TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q33_led.call(q33_hab)); q33n.start_spar(1, ["mirror"], {}, "SEGMENT_END"); quiet(q33n)
	q33n.ep_p += 2; q33n.clock_t = 3; for q33_j3 in 6: q33n.step({})
	var q33_ob: Array = [q33n.boss_label, q33n.mode, bool(q33n.obj.get("met", false)), count_events(q33n.events, "bout_end", {"objective": "SEGMENT_END", "met": true})]
	_sr("the spar's end, the save and the aid: trials %s, no PI %s (a plain spar's ticks %s), the record learning in it (%d punches); written back %s, the record %s; the DualState %s on the same hash %s, the copy %s, its reads %s; the aid %s; with the objective %s" % [JSON.stringify(q33_en[0]), str(q33_en[1]), str(q33_en[2]), int(q33_en[3]), str(q33_en[4]), "the same" if bool(q33_en[5]) else "DIFFERENT", str(q33_en[6]), str(q33_en[7]), JSON.stringify(q33_en[8]), "restored" if bool(q33_en[9]) else "LOST", JSON.stringify(q33_ai), JSON.stringify(q33_ob)],
		q33_en[0] == ["spar_won", "mirror"] and bool(q33_en[1]) and bool(q33_en[2]) and int(q33_en[3]) == 35 and str(q33_en[4]) == "byte-equal" and bool(q33_en[5]) and bool(q33_en[6]) and bool(q33_en[7]) and q33_en[8] == ["HABIT JAB > JAB > R_STR", "HABIT L_HOOK > R_HOOK"] and bool(q33_en[9]) \
		and bool(q33_ai[0]) and str(q33_ai[1]) == "RORY'S MIRROR" and bool(q33_ai[2]) and bool(q33_ai[3]) and str(q33_ai[4]) == "FIGHT" and bool(q33_ai[5]) and str(q33_ai[6]) == "PRIYA'S MIRROR" \
		and str(q33_ob[0]) == "RORY'S MIRROR" and str(q33_ob[1]) == "OVER" and bool(q33_ob[2]) and int(q33_ob[3]) == 1)

	# ---- PAC-094: ACCESSORIES & GEAR (NP_11 s5) ----
	var q34_gd: Dictionary = content["gear"]
	var q34_mk := func(q34_g: String, q34_lu: Array = TNBSim.LINEUP_MILLBROOK, q34_extra: String = "", q34_fl: String = "", q34_pu: String = "") -> TNBSim:
		var q34_l: Dictionary = TNBSim.seed_gear(TNBSim.seed_purse(TNBSim.seed_story(TNBSim.seed_growth({}, q34_extra), q34_fl), q34_pu), q34_g)
		var q34_s := make_sim(1, 7, q34_lu, "", {}, q34_l)
		q34_s.mode = "OVER"
		return q34_s
	# the table: four kinds, each piece's passive its kind's on a board passive's own key, never over the cap (3%) - so the strongest
	# piece of a kind sits under the board's passive on that key, and one piece a kind means a full kit never puts more than the cap on
	# any key; the sources counted; a house's gift by rule (its colours, the piece by its style); the pieces named with their effect
	var q34a : TNBSim = q34_mk.call("")
	var q34_src := {}; var q34_top := {}; var q34_over: Array = []
	for q34_id in q34_gd["items"]:
		var q34_it: Dictionary = q34_gd["items"][q34_id]
		q34_src[str(q34_it["source"])] = int(q34_src.get(str(q34_it["source"]), 0)) + 1
		q34_top[str(q34_it["kind"])] = maxi(int(q34_top.get(str(q34_it["kind"]), 0)), int(q34_it["pct"]))
		if int(q34_it["pct"]) > int(q34_gd["cap_pct"]): q34_over.append(str(q34_id))
	var q34_vs: Array = []
	for q34_k in q34_gd["kinds"]:
		var q34_kd: Dictionary = q34_gd["kinds"][q34_k]
		var q34_bp: float = absf(float(content["growth"]["passives"][str(q34_kd["passive"])][str(q34_kd["passive_key"])]) - 1.0) * 100.0
		q34_vs.append([str(q34_k), str(q34_kd["key"]), str(q34_kd["passive"]), int(q34_top.get(str(q34_k), 0)), snappedf(q34_bp, 0.01)])
	var q34_gifts: Array = ["tremblay", "okafor", "kowalchuk", "tagaq"].map(func(q34_h): return q34a.gear_text("gift:" + str(q34_h)))
	var q34_tx: Array = [q34a.gear_text("pro_gloves"), q34a.gear_text("gel_wraps"), q34a.gear_text("custom_guard"), q34a.gear_text("satin_robe"), q34a.gear_text("gym_robe")]
	_sr("the gear as data (NP_11 s5): cap %d%%, %s; the kinds against their boards %s; over the cap %s; the house gifts %d by rule %s; %s" % [int(q34_gd["cap_pct"]), JSON.stringify(q34_src), JSON.stringify(q34_vs), JSON.stringify(q34_over), q34_gd["house_styles"].size(), JSON.stringify(q34_gifts), JSON.stringify(q34_tx)],
		int(q34_gd["cap_pct"]) == 3 and q34_src == {"shop": 10, "prize": 3, "festival": 3, "signature": 2} and q34_over.is_empty() and q34_gd["house_styles"].size() == 12 \
		and q34_vs.filter(func(q34_v): return float(q34_v[3]) >= float(q34_v[4]) or int(q34_v[3]) > int(q34_gd["cap_pct"])).is_empty() and q34_vs.size() == 4 \
		and q34_vs.map(func(q34_v2): return [q34_v2[0], q34_v2[1], q34_v2[2]]) == [["gloves", "jab_dmg", "snap"], ["wraps", "guard_decay", "tight_guard"], ["mouthguard", "wobble_time", "iron_jaw"], ["robe", "tension_earn", "sparkplug"]] \
		and q34_gifts == ["Tremblay colours - gloves (jab damage +2%)", "Okafor colours - wraps (guard decay while holding -2%)", "Kowalchuk colours - mouthguard (wobble duration -2%)", "Tagaq colours - robe (personal Tension contribution +2%)"] \
		and q34_tx == ["Pro Gloves (jab damage +3%)", "Gel Wraps (guard decay while holding -2%)", "Custom Guard (wobble duration -3%)", "Satin Robe (personal Tension contribution +2%)", "Gym Robe (cosmetic)"])
	# the slots and the rules: 1 / 2 / 3 / 3 by rarity; a piece the club does not hold; the slots full; one of each kind; a signature piece
	# on another card; every copy worn; mid-dual; taken off and worn by another; a seeded kit cut to the slots at the bell
	var q34b : TNBSim = q34_mk.call("tape_wraps,gym_robe", TNBSim.LINEUP_MILLBROOK_8)
	var q34_sl: Array = []
	for q34_r in [1, 2, 3, 4]:
		var q34_rs : TNBSim = q34_mk.call("", TNBSim.LINEUP_MILLBROOK, "RORY:rarity:%d" % q34_r); q34_sl.append(q34_rs.accessory_slots("RORY"))
	var q34_w: Array = [q34b.gear_why("RORY", "pro_gloves"), q34b.wear("RORY", "tape_wraps")["ok"], q34b.gear_why("RORY", "gym_robe"), q34b.gear_why("RORY", "grain_sack_wraps"), q34b.gear_why("JUNE", "tape_wraps"), q34b.wear("YURI", "grain_sack_wraps")["ok"]]
	var q34c : TNBSim = q34_mk.call("tape_wraps,gel_wraps,gym_robe", TNBSim.LINEUP_MILLBROOK, "RORY:rarity:2"); q34c.wear("RORY", "tape_wraps")
	q34_w.append_array([q34c.gear_why("RORY", "gel_wraps"), q34c.wear("RORY", "gym_robe")["ok"], q34c.gear_worn("RORY")])
	q34c.mode = "FIGHT"; q34c.step({}); q34_w.append(q34c.gear_why("PRIYA", "gel_wraps")); q34c.mode = "OVER"
	q34_w.append_array([q34c.take_off("RORY", "*")["ok"], q34c.gear_worn("RORY"), q34c.wear("PRIYA", "gym_robe")["ok"], q34c.gear_worn("PRIYA")])
	var q34d : TNBSim = q34_mk.call("RORY:tape_wraps,RORY:gym_robe"); q34d.new_dual()
	q34_w.append_array([q34d.P.get("gear", []), q34d.gear_fx("RORY")])
	_sr("the slots and the rules (NP_11 s4-s5): slots by rarity %s; %s" % [JSON.stringify(q34_sl), JSON.stringify(q34_w)],
		q34_sl == [1, 2, 3, 3] and str(q34_w[0]) == "the club holds no Pro Gloves" and bool(q34_w[1]) and str(q34_w[2]) == "RORY's accessory slots are full (1 of 1) - Circuit opens the next" \
		and str(q34_w[3]) == "Grain-Sack Wraps is YURI's - signature gear, his alone" and str(q34_w[4]) == "the club's Tape Wraps are all worn (1 of 1)" and bool(q34_w[5]) \
		and str(q34_w[6]) == "RORY wears wraps already (Tape Wraps)" and bool(q34_w[7]) and q34_w[8] == ["tape_wraps", "gym_robe"] and str(q34_w[9]) == "the gear is set between duals" \
		and bool(q34_w[10]) and q34_w[11] == ["tape_wraps"] and bool(q34_w[12]) and q34_w[13] == ["gym_robe"] and q34_w[14] == ["tape_wraps"] and absf(float(q34_w[15].get("guard_decay", 0.0)) - 0.99) < 0.0001)
	# the sources: the shop's t1 bought in HBP (a second copy a second piece), t2 before the Regionals, the purse short, a prize and a
	# signature not sold; the circuit's prizes in the locker with their flags (announced once), a signature with its owner in the club
	# (Efua's with her questline too), a blessed house's colours; the festival's prize for an Exhibition 2v2 won on the boardwalk - not
	# at home, not lost - the next each time, none past the last
	var q34e : TNBSim = q34_mk.call("", TNBSim.LINEUP_MILLBROOK, "", "", "hbp:300")
	var q34_so: Array = [q34e.buy_gear("tape_wraps")["ok"], int(q34e.rewards["hbp"]), q34e.buy_gear("tape_wraps")["ok"], int(q34e.gear_owned().get("tape_wraps", 0)), q34e.gear_buy_why("leather_gloves"), q34e.gear_from("tape_wraps")]
	q34e.rewards["hbp"] = 50; q34_so.append_array([q34e.gear_buy_why("club_gloves"), q34e.gear_buy_why("regionals_robe"), q34e.gear_buy_why("grain_sack_wraps")])
	var q34_ef: Dictionary = TNBSim.LINEUP_MILLBROOK[3].duplicate(true); q34_ef["name"] = "EFUA"; q34_ef["house"] = "osei"
	var q34f : TNBSim = q34_mk.call("", TNBSim.LINEUP_MILLBROOK_8, "", "story:regionals,story:nationals,blessing:tremblay")
	var q34_n0: int = count_events(q34f.events, "gear_won"); q34f.events.clear(); q34f.new_dual(); q34f.new_dual()
	var q34g : TNBSim = q34_mk.call("", [TNBSim.LINEUP_MILLBROOK[0], q34_ef]); var q34h : TNBSim = q34_mk.call("", [TNBSim.LINEUP_MILLBROOK[0], q34_ef], "", "quest:osei_blessing")
	q34_so.append_array([q34f.gear_owned().keys(), q34_n0, count_events(q34f.events, "gear_won"), q34f.gear_from("regionals_robe"), q34f.gear_from("gift:tremblay"), q34g.gear_owned().keys(), q34h.gear_owned().keys()])
	var q34_fx := func(q34_ven: String, q34_win: bool) -> Array:
		var q34_x = TNBExhibition.new()
		q34_x.setup(content, [TNBSim.LINEUP_MILLBROOK[0], TNBSim.LINEUP_MILLBROOK[1]], 1, 7, TNBSim.seed_facilities({}, "ring:2", content["facilities"]), {}, "exhibition_2v2", false, q34_ven)
		if q34_win: q34_x.a.score_p = 1
		else: q34_x.a.score_b = 1
		q34_x._end()
		return [q34_x.venue, q34_x.a.gear_owned().keys()]
	var q34_fe: Array = [q34_fx.call("festival", true), q34_fx.call("festival", false), q34_fx.call("home", true)]
	var q34_fl: Array = [q34a.gear_festival(), q34a.gear_festival(), q34a.gear_festival(), q34a.gear_festival()]
	_sr("the sources: the shop %s; the story's %s (announced %d then %d); a signature without and with its questline %s / %s; the festival %s, in turn %s" % [JSON.stringify(q34_so.slice(0, 9)), JSON.stringify(q34_so.slice(9, 10) + q34_so.slice(12, 14)), int(q34_so[10]), int(q34_so[11]), JSON.stringify(q34_so[14]), JSON.stringify(q34_so[15]), JSON.stringify(q34_fe), JSON.stringify(q34_fl)],
		bool(q34_so[0]) and int(q34_so[1]) == 220 and bool(q34_so[2]) and int(q34_so[3]) == 2 and str(q34_so[4]) == "the gear shop's t2 shelf opens with the Regionals (story:regionals) or DOWNTOWN rep 10 (0 now)" and str(q34_so[5]) == "the gear shop (t1, 80 HBP)" \
		and str(q34_so[6]) == "Club Gloves costs 60 HBP (the ledger holds 50)" and str(q34_so[7]) == "Regionals Robe is not sold - a circuit prize" and str(q34_so[8]) == "Grain-Sack Wraps is not sold - signature gear, never sold" \
		and q34_so[9] == ["grain_sack_wraps", "nationals_guard", "regionals_robe", "gift:tremblay"] and int(q34_so[10]) == 4 and int(q34_so[11]) == 0 \
		and str(q34_so[12]) == "the circuit's prize (story:regionals)" and str(q34_so[13]) == "House Tremblay's gift, its blessing given (NP_07 s4)" and q34_so[14] == [] and q34_so[15] == ["mothers_wraps"] \
		and q34_fe == [["festival", ["boardwalk_robe"]], ["festival", []], ["home", []]] and q34_fl == ["boardwalk_robe", "festival_wraps", "summer_gloves", ""])
	# the effect at the bell, each kind against the same sim without it (RORY at Club, one piece): Pro Gloves a jab x1.03, Gel Wraps the
	# guard lost holding x0.98, Custom Guard out of the wobble sooner (x0.97), Satin Robe the Tension earned x1.02 - each its own number
	# and no other; with Snap on his board too the jab x1.3 x1.03 (the board's outweighs the piece's); the matchup card's GEAR line;
	# his opponent untouched
	var q34_pm := func(q34_g2: String, q34_grow: Dictionary = {}) -> TNBSim:
		var q34_l2: Dictionary = TNBSim.seed_gear(q34_grow.duplicate(true), q34_g2)
		var q34_s2 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q34_l2)
		quiet(q34_s2); place(q34_s2, 1.4); clear_defense(q34_s2.B); q34_s2.B["guard_t"] = 0
		return q34_s2
	var q34_meas := func(q34_g3: String, q34_grow2: Dictionary = {}) -> Array:
		var q34_v: Array = []
		var q34_h: TNBSim = q34_pm.call(q34_g3, q34_grow2)
		q34_h.P["pending"] = {"row": "L_STRAIGHT", "t": 0, "startup": 0, "mods": [], "hissatsu": false, "counter": false, "flash": false, "stamina_cost": 0.0, "read": "none", "stepping": false}
		var q34_c0: float = q34_h.B["comp"]; q34_h._land_player_punch(); q34_v.append(q34_c0 - float(q34_h.B["comp"]))
		var q34_g: TNBSim = q34_pm.call(q34_g3, q34_grow2); var q34_g0: float = q34_g.P["guard"]
		for q34_i in 60: q34_g.step({"block": true})
		q34_v.append(q34_g0 - float(q34_g.P["guard"]))
		var q34_j: TNBSim = q34_pm.call(q34_g3, q34_grow2); q34_j.P["comp"] = float(q34_j.P["comp_max"]) * 0.20; q34_j.P["no_regen_t"] = 0
		var q34_t := 0
		while q34_j._wobbled(q34_j.P) and q34_t < 3000: q34_j.step({}); q34_t += 1
		q34_v.append(q34_t)
		var q34_tn: TNBSim = q34_pm.call(q34_g3, q34_grow2); var q34_te: float = q34_tn.contributed; q34_tn._earn_tension(10.0); q34_v.append(q34_tn.contributed - q34_te)
		q34_v.append([q34_h.gear_line(), q34_h.B.has("gear_fx")])
		return q34_v
	var q34_n: Array = q34_meas.call("")
	var q34_m := {"gloves": q34_meas.call("RORY:pro_gloves"), "wraps": q34_meas.call("RORY:gel_wraps"), "mouthguard": q34_meas.call("RORY:custom_guard"), "robe": q34_meas.call("RORY:satin_robe")}
	var q34_own := {"gloves": 0, "wraps": 1, "mouthguard": 2, "robe": 3}
	var q34_quiet := true
	for q34_k2 in q34_own:
		for q34_ix in 4:
			if q34_ix != int(q34_own[q34_k2]) and JSON.stringify(q34_m[q34_k2][q34_ix]) != JSON.stringify(q34_n[q34_ix]): q34_quiet = false
	var q34_sn: Array = q34_meas.call("RORY:pro_gloves", {"growth": {"RORY": {"board": ["c10"], "spent": 3, "socket": "", "raises": {}, "rarity": 1, "trials": {}}}})
	var q34_ra: Array = [float(q34_m["gloves"][0]) / float(q34_n[0]), float(q34_m["wraps"][1]) / float(q34_n[1]), float(q34_m["mouthguard"][2]) / float(q34_n[2]), float(q34_m["robe"][3]) / float(q34_n[3]), float(q34_sn[0]) / float(q34_n[0])]
	_sr("the gear at the bell, each kind against no gear: the jab x%s, the guard lost x%s, the wobble's ticks %d -> %d (x%s), the Tension x%s - each its own number %s; with Snap on the board x%s; %s; his opponent %s" % [TNBSim._n(q34_ra[0]), TNBSim._n(q34_ra[1]), int(q34_n[2]), int(q34_m["mouthguard"][2]), TNBSim._n(q34_ra[2]), TNBSim._n(q34_ra[3]), str(q34_quiet), TNBSim._n(q34_ra[4]), JSON.stringify(q34_m.values().map(func(q34_x2): return q34_x2[4][0])), "untouched" if not bool(q34_m["gloves"][4][1]) else "WEARING IT"],
		q34_quiet and absf(q34_ra[0] - 1.03) < 0.0001 and absf(q34_ra[1] - 0.98) < 0.0001 and int(q34_m["mouthguard"][2]) < int(q34_n[2]) and absf(q34_ra[2] - 0.97) < 0.01 and absf(q34_ra[3] - 1.02) < 0.0001 and absf(q34_ra[4] - 1.339) < 0.0001 \
		and q34_m.values().map(func(q34_x3): return q34_x3[4][0]) == ["GEAR: RORY - Pro Gloves (jab damage +3%)", "GEAR: RORY - Gel Wraps (guard decay while holding -2%)", "GEAR: RORY - Custom Guard (wobble duration -3%)", "GEAR: RORY - Satin Robe (personal Tension contribution +2%)"] \
		and not bool(q34_m["gloves"][4][1]) and str(q34_n[4][0]) == "")
	# the save and the aid: each Fighter record's gear (NP_11 s9: [item_id, ...3]), the locker written back byte-equal with the story's
	# pieces derived again, the built RORY walking out in the same; a DualState in flight restored on the same hash; the aid - what fits
	# from the locker first (the Regionals Robe on RORY), then the shop's pick for a card with a slot open
	var q34i : TNBSim = q34_mk.call("tape_wraps,RORY:leather_gloves", TNBSim.LINEUP_MILLBROOK_8, "RORY:rarity:2", "story:regionals")
	q34i.wear("RORY", "regionals_robe"); q34i.wear("YURI", "grain_sack_wraps")
	var q34_fr: Array = TNBSave.to_save(q34i)["stable"].filter(func(q34_f): return str(q34_f["name"]) in ["RORY", "YURI", "JUNE"]).map(func(q34_f2): return [str(q34_f2["name"]), q34_f2.get("gear", null)])
	var q34_st: String = TNBSave.write_text(q34i, false)
	var q34_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q34_st), 7)["sim"]
	q34_bl.new_dual()
	var q34j : TNBSim = q34_mk.call("RORY:pro_gloves"); q34j.new_dual(); for q34_j2 in 240: q34j.step({})
	var q34_snp: Dictionary = q34j.snapshot(); var q34_hj: int = q34j.hash_state()
	var q34k := make_sim(3, 999, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); var q34_rs2: Dictionary = q34k.restore(q34_snp)
	var q34l : TNBSim = q34_mk.call("", TNBSim.LINEUP_MILLBROOK, "", "story:regionals", "hbp:600")
	var q34_ai: int = q34l.gear_aid("*")
	_sr("the save and the aid: the Fighter records %s; written back %s, the built RORY at the bell %s; the DualState %s on the same hash %s; the aid %d steps, worn %s, HBP %d" % [JSON.stringify(q34_fr), "byte-equal" if TNBSave.write_text(q34_bl, false) == q34_st else "DIFFERENT", JSON.stringify(q34_bl.P.get("gear", [])), str(q34_rs2.get("ok", false)), str(q34k.hash_state() == q34_hj), q34_ai, JSON.stringify(["RORY", "PRIYA", "MARCUS", "JUNE"].map(func(q34_nm): return q34l.gear_worn(q34_nm))), int(q34l.rewards["hbp"])],
		q34_fr == [["RORY", ["leather_gloves", "regionals_robe"]], ["JUNE", []], ["YURI", ["grain_sack_wraps"]]] and TNBSave.write_text(q34_bl, false) == q34_st and q34_bl.P.get("gear", []) == ["leather_gloves", "regionals_robe"] \
		and bool(q34_rs2.get("ok", false)) and q34k.hash_state() == q34_hj and q34k.P.get("gear", []) == ["pro_gloves"] \
		and q34l.gear_worn("RORY") == ["regionals_robe"] and q34l.gear_worn("PRIYA").size() == 1 and q34l.gear_worn("MARCUS").size() == 1 and int(q34l.rewards["hbp"]) < 600)

	# ---- PAC-095: THE OBSOLESCENCE AUDIT (NP_11 s10) ----
	var q35_A: Dictionary = content["audit"]
	var q35_s0: TNBSim = TNBAudit.mk(content, 1, 7, TNBSim.LINEUP_MILLBROOK, {})
	# the audit as data: the three earliest-recruitable by NP_12 s4's order (Ep1's Priya, Building five's Dex, the Regionals pool's Yuri),
	# the reference the recruit table's arc 2-3 recruits, the endgame the arc-3 patterns at level 35, the budget, the bar
	var q35_rt: Dictionary = content["recruits"]["recruits"]
	var q35_cards: Array = q35_A["earliest"].map(func(q35_e): return TNBAudit.card_of(q35_s0, str(q35_e["card"]), str(q35_e.get("recruit", ""))))
	var q35_d: Array = [q35_A["earliest"].map(func(q35_e2): return str(q35_e2["card"])), q35_A["earliest"].map(func(q35_e3): return int(q35_rt.get(str(q35_e3.get("recruit", "")), {}).get("arc", 0))), q35_A["reference"]["recruits"], q35_A["reference"]["recruits"].map(func(q35_r): return int(q35_rt[str(q35_r)]["arc"])),
		TNBAudit.endgame_bosses(content, str(q35_A["endgame"]["arc"])), int(q35_A["endgame"]["level"]), [int(q35_A["budget"]["spirits"]), int(q35_A["budget"]["beans"]), int(q35_A["budget"]["hbp"])], float(q35_A["criteria"]["win_rate"]),
		q35_cards.map(func(q35_c): return [str(q35_c["name"]), str(q35_c["style"]), str(q35_c["house"])])]
	_sr("the audit as data (NP_11 s10): %s" % JSON.stringify(q35_d),
		q35_d[0] == ["PRIYA", "DEX", "YURI"] and q35_d[1] == [0, 1, 1] and q35_d[2] == ["cassidy_vane", "remy_moreau", "jean_guy_moreau", "hc9_choir"] and q35_d[3].filter(func(q35_a): return int(q35_a) < 2).is_empty() \
		and q35_d[4] == ["alfie_crane", "chiamaka_okafor", "deshawn_vaughn", "ioan_vasile", "itzel_reyes_ortega", "sora_kannagi", "yordanis_baro"] and int(q35_d[5]) == 35 and q35_d[6] == [110, 140, 1700] and absf(float(q35_d[7]) - 0.5) < 0.0001 \
		and q35_d[8] == [["PRIYA", "OUTBOXER", "none"], ["DEX", "SLUGGER", "macisaac"], ["YURI", "SLUGGER", "kowalchuk"]])
	# a build on live systems only: the endgame's XP on his own curve (the no-name's +10%), the three trials by their own paths and the
	# three ascensions paid, every Board Point but one spent on the aid's picks, the jar spent on the lowest stat, a kit where every move
	# answers, the gear's three slots; a purse short of the Legend's 60 stops the build at tier 3 and says so. Since PAC-096 every slot
	# is filled (the board's wall the fourth) and neither build falls short
	var q35_yb: Dictionary = TNBAudit.build(content, q35_A, q35_cards[2])
	var q35_pb: Dictionary = TNBAudit.build(content, q35_A, q35_cards[0])
	var q35_A2: Dictionary = q35_A.duplicate(true); q35_A2["budget"]["spirits"] = 50
	var q35_sb: Dictionary = TNBAudit.build(content, q35_A2, q35_cards[2])
	var q35_bl := func(q35_b: Dictionary) -> Array: return [str(q35_b["name"]), int(q35_b["xp"]), int(q35_b["level"]), int(q35_b["rarity"]), int(q35_b["points"]) - int(q35_b["points_left"]), int(q35_b["points"]), q35_b["passives"].size(), int(q35_b["raises"]), int(q35_b["left"]["beans"]), q35_b["kit"], q35_b["dead"], int(q35_b["used"]), int(q35_b["slots"]), str(q35_b["t0"]), q35_b["gear"].size(), q35_b["fails"].keys()]
	var q35_by: Array = q35_bl.call(q35_yb); var q35_bp: Array = q35_bl.call(q35_pb)
	_sr("a build on live systems only: %s; %s; on 50 Spirits %s" % [JSON.stringify(q35_by), JSON.stringify(q35_bp), JSON.stringify([int(q35_sb["rarity"]), str(q35_sb["fails"].get("tier4", ""))])],
		int(q35_by[1]) == 58800 and int(q35_by[2]) == 35 and int(q35_bp[1]) == 64680 and int(q35_bp[2]) == 36 and int(q35_by[3]) == 4 and int(q35_bp[3]) == 4 \
		and int(q35_by[5]) - int(q35_by[4]) <= 1 and int(q35_bp[5]) - int(q35_bp[4]) <= 1 and int(q35_by[6]) >= 3 and int(q35_bp[6]) >= 3 and int(q35_by[7]) > 0 and int(q35_by[8]) < 5 \
		and q35_by[10] == [] and q35_bp[10] == [] and int(q35_by[11]) == 4 and int(q35_by[12]) == 4 and int(q35_bp[11]) == 4 and str(q35_by[13]) != "" and str(q35_bp[13]) == "Marginalia" and int(q35_by[14]) == 3 and q35_by[15] == [] and q35_bp[15] == [] \
		and int(q35_sb["rarity"]) == 3 and str(q35_sb["fails"].get("tier4", "")).begins_with("Legend costs 60 Spirits"))
	# the kit's rule made explicit (C45's cast order): a move answers at some bar only when every move ahead of it on its family - his own
	# first, then the kit's - costs more: Updraft behind YURI's own Grain Elevator (RISE, 35 each) never answers; Snowblind behind PRIYA's
	# own Marginalia (PISTON, 10) never answers; First Snap (10) behind Snowblind (35) does, Snowblind behind First Snap does not; the
	# builder's kits hold no such move, each of its moves on a family of its own
	var q35_kr := func(q35_nm: String, q35_lv: int, q35_kit: String) -> Array:
		var q35_l: Dictionary = TNBSim.seed_learned(TNBSim.seed_levels({}, "%s:%d" % [q35_nm, q35_lv], content["economy"]), "%s:%s" % [q35_nm, q35_kit])
		var q35_s := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "", {}, q35_l)
		return [q35_s.kit_moves(q35_nm), q35_s.kit_unreachable(q35_nm)]
	var q35_k: Array = [q35_kr.call("YURI", 20, "Updraft"), q35_kr.call("PRIYA", 20, "Snowblind"), q35_kr.call("YURI", 20, "Snowblind+First Snap"), q35_kr.call("YURI", 20, "First Snap+Snowblind")]
	var q35_fam := func(q35_b2: Dictionary) -> bool:
		var q35_fs: Array = [q35_b2["own_family"]]
		for q35_mv in q35_b2["kit"]:
			if str(content["library"][str(q35_mv)]["tier"]) != "T0":
				if str(content["library"][str(q35_mv)]["family"]) in q35_fs: return false
				q35_fs.append(str(content["library"][str(q35_mv)]["family"]))
		return true
	_sr("the kit's rule and the builder: %s; the builder's kits %s / %s, each move a family of its own %s" % [JSON.stringify(q35_k), JSON.stringify(q35_yb["kit_steps"]), JSON.stringify(q35_pb["kit_steps"]), str(q35_fam.call(q35_yb) and q35_fam.call(q35_pb))],
		q35_k[0] == [["Updraft"], ["Updraft"]] and q35_k[1] == [["Snowblind"], ["Snowblind"]] and q35_k[2] == [["Snowblind", "First Snap"], []] and q35_k[3] == [["First Snap", "Snowblind"], ["Snowblind"]] \
		and bool(q35_fam.call(q35_yb)) and bool(q35_fam.call(q35_pb)) and q35_yb["kit_steps"].size() == 5 and q35_pb["kit_steps"].size() == 4)
	# the fight: the built card against an endgame boss in a spar on the profile, the sim's own verdict; twice alike, another seed another
	var q35_f1: Dictionary = TNBAudit.fight(content, q35_yb, "alfie_crane", 11, 12000)
	var q35_f2: Dictionary = TNBAudit.fight(content, q35_yb, "alfie_crane", 11, 12000)
	var q35_f3: Dictionary = TNBAudit.fight(content, q35_yb, "alfie_crane", 22, 12000)
	_sr("the fight: %s; again %s; another seed %s" % [JSON.stringify(q35_f1), "the same" if JSON.stringify(q35_f2) == JSON.stringify(q35_f1) else "DIFFERENT", "another" if int(q35_f3["hash"]) != int(q35_f1["hash"]) else "THE SAME"],
		JSON.stringify(q35_f2) == JSON.stringify(q35_f1) and int(q35_f3["hash"]) != int(q35_f1["hash"]) and int(q35_f1["ticks"]) < 12000 and bool(q35_f1["won"]) == (int(q35_f1["score"][0]) > int(q35_f1["score"][1]) or (int(q35_f1["score"][0]) == int(q35_f1["score"][1]) and int(q35_f1["ep"][0]) > int(q35_f1["ep"][1]))))
	# the verdict names the system, not the fighter (one boss, one seed, one reference). Since PAC-096 each shortfall is made by taking
	# its fix out: a bar nobody reaches puts PRIYA's on the fight itself (her total within 10% of the reference's), and on growth with
	# the rarity totals taken out (over 10% under); a purse short of the Legend on rarity; the board's walls taken out on techniques;
	# with the bar at 0 the machinery says VIABLE
	var q35_mini := func(q35_mod: Callable, q35_cx: Dictionary) -> Dictionary:
		var q35_Ax: Dictionary = q35_A.duplicate(true); q35_Ax["reference"]["recruits"] = ["cassidy_vane"]; q35_mod.call(q35_Ax)
		return TNBAudit.run(q35_cx, q35_Ax, {"fighters": ["PRIYA"], "bosses": ["alfie_crane"], "seeds": [11]})
	var q35_nt: Dictionary = content.duplicate(); q35_nt["growth"] = content["growth"].duplicate(true); q35_nt["growth"]["rarity"].erase("totals")
	var q35_nw: Dictionary = content.duplicate(); q35_nw["techniques"] = content["techniques"].duplicate(true); q35_nw["techniques"]["masters"].erase("BOARD")
	var q35_bar1 := func(q35_x): q35_x["criteria"]["win_rate"] = 1.01
	var q35_bar0 := func(q35_x0): q35_x0["criteria"]["win_rate"] = 0.0
	var q35_sp50 := func(q35_x3): q35_x3["budget"]["spirits"] = 50
	var q35_v1: Dictionary = q35_mini.call(q35_bar1, content)
	var q35_v2: Dictionary = q35_mini.call(q35_bar1, q35_nt)
	var q35_v3: Dictionary = q35_mini.call(q35_sp50, content)
	var q35_v4: Dictionary = q35_mini.call(q35_bar0, q35_nw)
	var q35_v5: Dictionary = q35_mini.call(q35_bar0, content)
	var q35_vs: Array = [q35_v1, q35_v2, q35_v3, q35_v4, q35_v5].map(func(q35_v): return [int(q35_v["viable"]), q35_v["early"][0]["systems"]])
	var q35_ln: Array = TNBAudit.lines(q35_v1)
	_sr("the verdict names the system: %s; the report %s" % [JSON.stringify(q35_vs), JSON.stringify(q35_ln)],
		q35_vs[0] == [0, ["the fight itself (tuning, PAC-052's lane)"]] and q35_vs[1] == [0, ["growth - the board and the raises (NP_11 s3, s6)"]] \
		and q35_vs[2] == [0, ["rarity (NP_11 s4)"]] and q35_vs[3] == [0, ["techniques (NP_11 s2, s8)"]] and q35_vs[4] == [1, []] \
		and q35_ln.size() == 2 and str(q35_ln[0]).begins_with("AUDIT :: PRIYA") and str(q35_ln[0]).contains("NOT VIABLE") and str(q35_ln[1]).begins_with("  reference CASSIDY"))

	# ---- PAC-096: WHAT THE AUDIT NAMED, FIXED (NP_11 s1 and NP_05 s3) ----
	var q36_g: Dictionary = content["growth"]; var q36_t: Dictionary = content["techniques"]
	# the fixes as data: NP_11 s1's stat totals by rarity (Circuit 420; National and Legend 490, the late recruits' card at 70 a stat);
	# NP_05 s3's defensive board - the Anchor Wall on every layout's Spirit lobe beside Wallflower, the board teaching the three board
	# walls (NP_05 s10's anchor board's Shield Wall, Windbreak, Palisade: T2 WALL at 25) behind it, a T2 in a slot wanting it
	var q36_aw: Array = []; var q36_lk := true
	for q36_ly in q36_g["layouts"]:
		for q36_n in q36_g["layouts"][q36_ly]["nodes"]:
			if str(q36_n["kind"]) == "wall": q36_aw.append([str(q36_ly), str(q36_n["id"]), str(q36_n["lobe"]), int(q36_n["cost"]), str(q36_n["label"]), q36_n["links"]])
			if str(q36_n["id"]) in ["s13", "s14"] and not ("s15" in q36_n["links"]): q36_lk = false
	var q36_tt: Dictionary = q36_g["rarity"].get("totals", {})
	var q36_tv: Array = [int(q36_tt.get("2", 0)), int(q36_tt.get("3", 0)), int(q36_tt.get("4", 0))]
	var q36_bd: Array = q36_t["masters"]["BOARD"]["teaches"].map(func(q36_e): return [str(q36_e["move"]), str(q36_e["gate"].get("node", ""))])
	var q36_s0: TNBSim = make_sim(1, 7)
	var q36_cl: Array = ["Shield Wall", "Windbreak", "Palisade"].map(func(q36_m): return [q36_s0.tech_class(q36_m), str(content["library"][q36_m]["tier"]), str(content["library"][q36_m]["family"]), int(content["library"][q36_m]["tension_cost"])])
	_sr("the fixes as data (NP_11 s1, NP_05 s3): totals %s; %s; the board teaches %s; the walls %s; a T2 wants the %s node; board:anchor %s" % [JSON.stringify(q36_tv), JSON.stringify(q36_aw.map(func(q36_a): return q36_a[0] + ":" + q36_a[1])), JSON.stringify(q36_bd), JSON.stringify(q36_cl), str(q36_t["t2_board"]["node"]), "shut" if q36_t["not_learnable"].has("board:anchor") else "open"],
		q36_tv == [420, 490, 490] and q36_aw.size() == 4 and q36_aw.filter(func(q36_a2): return q36_a2[1] == "s15" and q36_a2[2] == "spirit" and int(q36_a2[3]) == 3 and q36_a2[4] == "Anchor Wall" and q36_a2[5] == ["s13", "s14"]).size() == 4 and q36_lk \
		and q36_bd == [["Shield Wall", "wall"], ["Windbreak", "wall"], ["Palisade", "wall"]] and q36_cl == [["slot", "T2", "WALL", 25], ["slot", "T2", "WALL", 25], ["slot", "T2", "WALL", 25]] \
		and str(q36_t["t2_board"]["node"]) == "wall" and not q36_t["not_learnable"].has("board:anchor"))
	# stat totals by rarity: PRIYA (370 of her own) stands as dressed at Club, totals 420 at Circuit and 490 at National and Legend -
	# scaled in proportion, so RFX stays her best and PWR her least, no stat under her own; National's cap (90) turns RFX's share to her
	# lowest; SAM (475) stands at Circuit and lifts at National; RORY's own HRT 99 stands over Circuit's cap; a late recruit (CASSIDY,
	# 490) never moves; a raise counts on top of the total; with the totals taken out PRIYA's Legend is her own 370 again
	var q36_sum := func(q36_d: Dictionary) -> int:
		var q36_x := 0
		for q36_k in q36_d: q36_x += int(q36_d[q36_k])
		return q36_x
	var q36_gs := func(q36_nm: String, q36_gr: String, q36_lu: Array) -> Dictionary:
		var q36_s: TNBSim = make_sim(1, 7, q36_lu, "", {}, TNBSim.seed_growth({}, q36_gr))
		return q36_s.grown_stats(q36_s._club_card(q36_nm))
	var q36_own: Dictionary = TNBSim.LINEUP_MILLBROOK[1]["stats"]
	var q36_p: Array = [1, 2, 3, 4].map(func(q36_r): return q36_gs.call("PRIYA", "PRIYA:rarity:%d" % q36_r, TNBSim.LINEUP_MILLBROOK))
	var q36_shape := func(q36_d2: Dictionary) -> bool:
		for q36_k2 in q36_own:
			if int(q36_d2[q36_k2]) < int(q36_own[q36_k2]) or int(q36_d2[q36_k2]) > int(q36_d2["RFX"]) or int(q36_d2[q36_k2]) < int(q36_d2["PWR"]): return false
		return true
	var q36_cv: Dictionary = q36_s0.recruit_card("cassidy_vane")
	var q36_sam: Array = [q36_gs.call("SAM", "SAM:rarity:2", TNBSim.LINEUP_MILLBROOK_8), q36_gs.call("SAM", "SAM:rarity:3", TNBSim.LINEUP_MILLBROOK_8)]
	var q36_ro: Dictionary = q36_gs.call("RORY", "RORY:rarity:2", TNBSim.LINEUP_MILLBROOK)
	var q36_ca: Dictionary = q36_gs.call("CASSIDY", "CASSIDY:rarity:4", [TNBSim.LINEUP_MILLBROOK[0], q36_cv])
	var q36_pr: Dictionary = q36_gs.call("PRIYA", "PRIYA:rarity:4,PRIYA:raise:PWR:3", TNBSim.LINEUP_MILLBROOK)
	var q36_ns: TNBSim = make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_growth({}, "PRIYA:rarity:4"))
	q36_ns.GROW = q36_ns.GROW.duplicate(true); q36_ns.GROW["rarity"].erase("totals")
	var q36_rt: Array = [q36_p.map(func(q36_d3): return q36_sum.call(q36_d3)), q36_p[0] == q36_own, q36_p.map(func(q36_d4): return q36_shape.call(q36_d4)), [int(q36_p[2]["RFX"]), int(q36_p[3]["RFX"])],
		q36_sam.map(func(q36_d5): return q36_sum.call(q36_d5)), [int(q36_ro["HRT"]), q36_sum.call(q36_ro)], [q36_sum.call(q36_ca), q36_ca == q36_cv["stats"]], [q36_sum.call(q36_pr), int(q36_pr["PWR"]) - int(q36_p[3]["PWR"])], q36_sum.call(q36_ns.grown_stats(q36_ns._club_card("PRIYA")))]
	_sr("stat totals by rarity (NP_11 s1): PRIYA %s, as dressed at Club %s, her shape kept %s, RFX at National and Legend %s; SAM %s; RORY %s; CASSIDY %s; a raise on top %s; the totals taken out %d; PRIYA's Legend %s" % [JSON.stringify(q36_rt[0]), str(q36_rt[1]), JSON.stringify(q36_rt[2]), JSON.stringify(q36_rt[3]), JSON.stringify(q36_rt[4]), JSON.stringify(q36_rt[5]), JSON.stringify(q36_rt[6]), JSON.stringify(q36_rt[7]), int(q36_rt[8]), JSON.stringify(q36_p[3])],
		q36_rt[0] == [370, 420, 490, 490] and bool(q36_rt[1]) and q36_rt[2] == [true, true, true, true] and int(q36_rt[3][0]) == 90 and int(q36_rt[3][1]) > 90 \
		and q36_rt[4] == [475, 490] and q36_rt[5] == [99, 420] and q36_rt[6] == [490, true] and q36_rt[7] == [493, 3] and int(q36_rt[8]) == 370)
	# the defensive board: at level 35 a T2 wall is refused without it (the lesson, any source, the node out of reach); the aid's picks
	# walk the board to the Anchor Wall; the board's three walls open as lessons; Windbreak learned (free, the node the price) into a
	# slot where it answers the WALL motion; at the bell LB + guard held 400 ms raises it (its 3 s, +1 for the Wallflower the aid took on
	# the way, +1 against Yuri's GRANITE, the element GALE beats - NP_06 s2.1); RORY, without the Anchor Wall, is
	# refused the re-teach; a respec takes the wall off the board and out of the kit, still learned
	var q36_mk := func(q36_lv: String, q36_lu: Array) -> TNBSim:
		var q36_l: Dictionary = TNBSim.seed_facilities(TNBSim.seed_levels({}, q36_lv, content["economy"]), "film:2", content["facilities"])
		var q36_s2 := make_sim(1, 7, q36_lu, "", {}, q36_l)
		q36_s2.mode = "OVER"
		return q36_s2
	var q36_pl: Array = [TNBSim.LINEUP_MILLBROOK[1], TNBSim.LINEUP_MILLBROOK[0], TNBSim.LINEUP_MILLBROOK[2], TNBSim.LINEUP_MILLBROOK[3]]
	var q36_to_wall := func(q36_s3: TNBSim, q36_nm2: String) -> int:
		var q36_c := 0
		while not q36_s3.wall_open(q36_nm2) and q36_c < 80 and bool(q36_s3.take_node(q36_nm2, "*")["ok"]): q36_c += 1
		return q36_c
	var q36_a: TNBSim = q36_mk.call("PRIYA:35,RORY:35", q36_pl)
	var q36_db: Array = [q36_a.lesson_why("BOARD", "PRIYA", "Windbreak"), q36_a._learn_why("PRIYA", "Shield Wall"), q36_a.node_why("PRIYA", "s15")]
	var q36_n2: int = q36_to_wall.call(q36_a, "PRIYA")
	q36_db.append_array([q36_a.wall_open("PRIYA"), q36_n2, q36_a.lessons_open("PRIYA").filter(func(q36_lo): return str(q36_lo[0]) == "BOARD").map(func(q36_lo2): return str(q36_lo2[1]))])
	var q36_lr: Dictionary = q36_a.lesson("BOARD", "PRIYA", "Windbreak")
	q36_db.append_array([bool(q36_lr["ok"]), str(q36_a.learned("PRIYA").get("Windbreak", "")), q36_a.kit_moves("PRIYA"), q36_a.kit_unreachable("PRIYA"), q36_a.reteach_why("PRIYA", "RORY", "Windbreak")])
	var q36_r: TNBSim = q36_mk.call("PRIYA:35", q36_pl)
	q36_to_wall.call(q36_r, "PRIYA"); q36_r.lesson("BOARD", "PRIYA", "Palisade")
	var q36_rk: Array = q36_r.kit_moves("PRIYA")
	q36_r.respec("PRIYA")
	q36_db.append_array([q36_rk, q36_r.kit_moves("PRIYA"), q36_r.learned("PRIYA").has("Palisade"), q36_r.kit_why("PRIYA", "Palisade")])
	q36_a.new_dual(); quiet(q36_a); place(q36_a, 1.4); thaw(q36_a); q36_a.tension = 100.0; q36_a.P["busy_t"] = 0; q36_a.P["cmd"] = {}; q36_a.events.clear()
	var q36_wm: String = str(q36_a.wall_move().get("name", ""))
	run_ticks(q36_a, TNBSim.ms(400) + 1, {"lb": true, "block": true})
	var q36_cast: String = str(q36_a.cast["move"]["name"]) if q36_a.cast.size() > 0 else "none"
	var q36_we: Array = []
	for q36_i in 400:
		if q36_a.cast.is_empty(): break
		q36_a.step({})
	for q36_ev in q36_a.events:
		if str(q36_ev["kind"]) == "wall" and str(q36_ev.get("who", "")) == "P": q36_we.append([float(q36_ev["points"]), float(q36_ev["seconds"])])
	q36_db.append_array([q36_a.pname(), q36_wm, q36_cast, q36_we])
	_sr("the defensive board (NP_05 s3): %s" % JSON.stringify(q36_db),
		str(q36_db[0]) == "a T2 wall wants a defensive board - PRIYA has not taken the Anchor Wall (NP_05 s3)" and str(q36_db[1]) == str(q36_db[0]) and str(q36_db[2]) == "Anchor Wall does not touch a node PRIYA has taken" \
		and bool(q36_db[3]) and int(q36_db[4]) > 0 and int(q36_db[4]) < 80 and q36_db[5] == ["Shield Wall", "Windbreak", "Palisade"] and bool(q36_db[6]) and str(q36_db[7]) == "master:BOARD" and "Windbreak" in q36_db[8] and q36_db[9] == [] \
		and str(q36_db[10]) == "a T2 wall wants a defensive board - RORY has not taken the Anchor Wall (NP_05 s3)" and "Palisade" in q36_db[11] and not ("Palisade" in q36_db[12]) and bool(q36_db[13]) \
		and str(q36_db[14]) == "a T2 wall wants a defensive board - PRIYA has not taken the Anchor Wall (NP_05 s3)" and str(q36_db[15]) == "PRIYA" and str(q36_db[16]) == "Windbreak" and str(q36_db[17]) == "Windbreak" and q36_we.size() >= 1 and "wallflower" in q36_a.passives_of("PRIYA") and absf(float(q36_we[0][1]) - 5.0) < 0.001)
	# the aid and the builder: the aid wants the Anchor Wall only when his slots outnumber the families his own move leaves free - not at
	# level 25 (three slots), at 35 (four); below that its picks are the board's without the wall, node for node (RORY at level 20); the
	# audit's PRIYA carries a WALL in the fourth slot, every move answering, and falls short nowhere; with the board's walls taken out
	# her fourth slot stays empty and the kit is named again
	var q36_nw: Dictionary = content.duplicate(); q36_nw["growth"] = content["growth"].duplicate(true)
	for q36_ly2 in q36_nw["growth"]["layouts"]:
		var q36_lay: Dictionary = q36_nw["growth"]["layouts"][q36_ly2]
		q36_lay["nodes"] = q36_lay["nodes"].filter(func(q36_n3): return str(q36_n3["kind"]) != "wall")
		for q36_n4 in q36_lay["nodes"]: q36_n4["links"] = q36_n4["links"].filter(func(q36_l2): return str(q36_l2) != "s15")
	var q36_seq := func(q36_cx: Dictionary) -> Array:
		var q36_s4: TNBSim = TNBAudit.mk(q36_cx, 1, 7, TNBSim.LINEUP_MILLBROOK, TNBSim.seed_levels({}, "RORY:20", content["economy"]))
		q36_s4.mode = "OVER"
		var q36_ids: Array = []
		while q36_ids.size() < 60 and q36_s4.node_best("RORY") != "":
			var q36_id: String = q36_s4.node_best("RORY")
			if not bool(q36_s4.take_node("RORY", "*")["ok"]): break
			q36_ids.append(q36_id)
		return q36_ids
	var q36_sq: Array = [q36_seq.call(content), q36_seq.call(q36_nw)]
	var q36_ww: Array = [q36_mk.call("PRIYA:25", q36_pl).wall_wanted("PRIYA"), q36_mk.call("PRIYA:35", q36_pl).wall_wanted("PRIYA"), q36_mk.call("RORY:35", q36_pl).wall_wanted("RORY")]
	var q36_pw: Array = q35_pb["kit"].filter(func(q36_m2): return str(content["library"][str(q36_m2)]["family"]) == "WALL")
	var q36_nb: Dictionary = TNBAudit.build(q35_nw, q35_A, q35_cards[0])
	_sr("the aid and the builder: wanted at 25 / 35 %s; RORY's picks at 20 with and without the wall %s (%d nodes); PRIYA's kit %s, the wall %s, short %s; without the board's walls %d of %d, short %s" % [JSON.stringify(q36_ww), "the same" if q36_sq[0] == q36_sq[1] else "DIFFERENT", q36_sq[0].size(), JSON.stringify(q35_pb["kit"]), JSON.stringify(q36_pw), JSON.stringify(q35_pb["fails"].keys()), int(q36_nb["used"]), int(q36_nb["slots"]), JSON.stringify(q36_nb["fails"].keys())],
		q36_ww == [false, true, true] and q36_sq[0] == q36_sq[1] and q36_sq[0].size() > 5 and not ("s15" in q36_sq[0]) and q36_pw.size() == 1 and q35_pb["dead"] == [] and int(q35_pb["used"]) == 4 and q35_pb["fails"].is_empty() \
		and int(q36_nb["used"]) == 3 and int(q36_nb["slots"]) == 4 and q36_nb["fails"].keys() == ["kit"])
	# the fight the fixes turn: the audit's PRIYA against Chiamaka Okafor (seed 22 since PAC-098's jar of 140 moved her build) wins; built with
	# the totals taken out she loses; the
	# reduced verdict on that fight says VIABLE, and names growth without the totals
	var q36_f1: Dictionary = TNBAudit.fight(content, q35_pb, "chiamaka_okafor", 22, 12000)
	var q36_ntb: Dictionary = TNBAudit.build(q35_nt, q35_A, q35_cards[0])
	var q36_f2: Dictionary = TNBAudit.fight(q35_nt, q36_ntb, "chiamaka_okafor", 22, 12000)
	var q36_Ar: Dictionary = q35_A.duplicate(true); q36_Ar["reference"]["recruits"] = ["cassidy_vane"]
	var q36_v1: Dictionary = TNBAudit.run(content, q36_Ar, {"fighters": ["PRIYA"], "bosses": ["chiamaka_okafor"], "seeds": [22]})
	var q36_v2: Dictionary = TNBAudit.run(q35_nt, q36_Ar, {"fighters": ["PRIYA"], "bosses": ["chiamaka_okafor"], "seeds": [22]})
	_sr("the fight the fixes turn: PRIYA (total %d) vs Chiamaka (seed 22) %s; the totals taken out (total %d) %s; the verdict %s / %s" % [int(q35_pb["total"]), JSON.stringify([q36_f1["won"], q36_f1["score"], q36_f1["ep"]]), int(q36_ntb["total"]), JSON.stringify([q36_f2["won"], q36_f2["score"], q36_f2["ep"]]), JSON.stringify([int(q36_v1["viable"]), q36_v1["early"][0]["systems"]]), JSON.stringify([int(q36_v2["viable"]), q36_v2["early"][0]["systems"]])],
		bool(q36_f1["won"]) and not bool(q36_f2["won"]) and int(q35_pb["total"]) > int(q36_ntb["total"]) and int(q36_v1["viable"]) == 1 and int(q36_v2["viable"]) == 0 and q36_v2["early"][0]["systems"] == ["growth - the board and the raises (NP_11 s3, s6)"])

	# ---- PAC-097: THE FAUCET/SINK AUDIT (NP_11 s6) ----
	var q37_F: Dictionary = content["faucets"]
	# the audit as data: the 70% target and its band, NP_02 s5's cadence and session shape, the results, the three phases to Arc 3's
	# start (Arc 1's 24 episodes, NP_12 s8, split at the Regionals; Arc 2 at Arc 1's length) with their formats and authored losses, the
	# protagonist's level by Arc 3, the squad wanted, NP_11 s6's typical/session, the five systems a miss names
	var q37_ph: Array = q37_F["phases"].map(func(q37_p): return [str(q37_p["id"]), int(q37_p["episodes"]), str(q37_p["format"]), int(q37_p["lost"])])
	var q37_ep := 0
	for q37_p2 in q37_F["phases"]: q37_ep += int(q37_p2["episodes"])
	var q37_d: Array = [float(q37_F["target"]["share"]), float(q37_F["target"]["band"]), int(q37_F["pace"]["minutes_per_story_dual"]), int(q37_F["pace"]["session_minutes"]), [float(q37_F["pace"]["session"]["scraps"]), float(q37_F["pace"]["session"]["spars"]), float(q37_F["pace"]["session"]["training_slots"])],
		q37_ph, q37_ep, TNBFaucets.sessions_of(q37_F, q37_ep), str(q37_F["pace"]["protagonist"]), int(q37_F["pace"]["level_by_arc3"]), int(q37_F["desired"]["squad"]), int(q37_F["desired"]["forges"]), q37_F["systems"].keys()]
	_sr("the faucet audit as data (NP_11 s6): %s" % JSON.stringify(q37_d),
		absf(float(q37_d[0]) - 0.7) < 0.0001 and absf(float(q37_d[1]) - 0.15) < 0.0001 and int(q37_d[2]) == 75 and int(q37_d[3]) == 45 and q37_d[4] == [5.0, 1.5, 1.0] \
		and q37_ph == [["arc1_club", 6, "mini", 1], ["arc1_circuit", 18, "sanctioned", 1], ["arc2", 24, "blind", 2]] and int(q37_ep) == 48 and absf(float(q37_d[7]) - 80.0) < 0.0001 \
		and str(q37_d[8]) == "RORY" and int(q37_d[9]) == 35 and int(q37_d[10]) == 8 and int(q37_d[11]) == 1 and q37_d[12] == ["xp", "spirits", "hbp", "prestige", "beans"])
	# a segment's own XP on the sim's one rule: event_xp pays a clean hit 1, a counter 2, a flash 3, a drop he takes 10, and nothing for a
	# hissatsu, a foul, a hit on your fighter or your own drop; the first segment a delegated dual pays (the audit's PRIYA out first against
	# Alfie Crane, RORY after her) pays its fighter exactly that segment's events' sum (+25 won) at the XP rate (houseless, x1.1); the
	# sample measures a won spar's XP the same way
	var q37_s := make_sim(1, 7)
	var q37_ex: Array = [q37_s.event_xp("hit", {"on": "B"}), q37_s.event_xp("hit", {"on": "B", "counter": true}), q37_s.event_xp("hit", {"on": "B", "flash": true}), q37_s.event_xp("drop", {"who": "B"}),
		q37_s.event_xp("hit", {"on": "B", "hissatsu": true}), q37_s.event_xp("hit", {"on": "B", "foul": true}), q37_s.event_xp("hit", {"on": "P"}), q37_s.event_xp("drop", {"who": "P"})]
	var q37_dl: TNBSim = TNBAudit.mk(content, TNBSim.BOSSES.find("alfie_crane"), 7, q35_pb["lineup"], q35_pb["ledger"]); q37_dl.delegate_all = true; q37_dl.new_dual(); q37_dl.events.clear()
	var q37_k := 0; var q37_run := 0; var q37_sum := 0; var q37_paid := -1; var q37_won := false; var q37_seg := ""; var q37_seen := false
	while q37_paid < 0 and q37_k < 60000 and q37_dl.mode != "OVER":
		q37_dl.step({}); q37_k += 1
		for q37_e in q37_dl.events:
			if str(q37_e["kind"]) == "seg_end": q37_seen = true; q37_won = bool(q37_e.get("won", false)); q37_sum = q37_run; q37_run = 0
			elif str(q37_e["kind"]) == "xp" and str(q37_e.get("why", "")).begins_with("R") and q37_paid < 0: q37_paid = int(q37_e["xp"]); q37_seg = str(q37_e["why"]) + " " + str(q37_e["who"])
			else: q37_run += q37_dl.event_xp(str(q37_e["kind"]), q37_e)
		q37_dl.events.clear()
	var q37_pace := float(content["economy"]["xp"].get("pace", 1.0))
	var q37_want := int(round(float(q37_sum + (25 if q37_won else 0)) * 1.1 * q37_pace))
	var q37_sm: Dictionary = TNBFaucets.sample(content, q37_F, q35_A, {"fighters": ["PRIYA"], "bosses": ["alfie_crane"], "seeds": [11]})
	var q37_f0: Dictionary = q37_sm["fights"][0]
	_sr("a segment's own XP (the sim's event_xp): %s; %s of a delegated dual paid %d for events worth %d%s (x1.1 x the pace -> %d); the sample %s -> won %d, lost %d (%s)" % [JSON.stringify(q37_ex), q37_seg, q37_paid, q37_sum, " +25 won" if q37_won else "", q37_want, JSON.stringify([q37_f0["fighter"], q37_f0["boss"], q37_f0["won"], q37_f0["xp"], q37_f0["events"]]), int(q37_sm["won"]), int(q37_sm["lost"]), str(q37_sm["note"])],
		q37_ex == [1, 2, 3, 10, 0, 0, 0, 0] and q37_seen and q37_sum > 0 and q37_paid == q37_want and bool(q37_f0["won"]) and int(q37_f0["xp"]) > 0 and int(q37_sm["won"]) == int(q37_f0["xp"]) and int(q37_sm["lost"]) == int(q37_sm["won"]) and str(q37_sm["note"]).begins_with("no lost fight"))
	# the faucet through the sim's own paths: Arc 1's first phase (6 duals, 10 sessions) paid with a segment worth 40 won and 10 lost is
	# the economy table's arithmetic to the unit - Spirits, HBP and Prestige by result (since PAC-098 the story beats and quest steps
	# too; since PAC-101 its districts' rep milestones), RORY's XP each payment at x1.1 and the pace, the Mitts at the median grade (5 Beans a slot); the ledger carried into the next
	# phase; every phase at 48 episodes, 80 sessions
	var q37_E: Dictionary = content["economy"]
	var q37_f1: Dictionary = TNBFaucets.faucet(content, q37_F, {"won": 40, "lost": 10}, {"phases": [q37_F["phases"][0]]})
	var q37_r: Dictionary = q37_f1["phases"][0]
	var q37_x := func(q37_b: int) -> int: return int(round(float(q37_b) * 1.1 * q37_pace))
	var q37_wd := int(q37_r["won"]); var q37_ld := int(q37_r["duals"]) - q37_wd
	var q37_rep := func(q37_ph: Dictionary) -> int:                                                       # PAC-101: the phase's scraps won in its districts in turn, each district's milestones reached
		var q37_ds: Array = q37_ph.get("districts", []); var q37_pp := 0
		for q37_di in q37_ds.size():
			var q37_w := 0
			for q37_si in int(q37_ph["scraps_won"]):
				if q37_si % q37_ds.size() == q37_di: q37_w += 1
			for q37_m in q37_E.get("rep", {}).get("milestones", []):
				if int(q37_m[0]) <= q37_w: q37_pp += int(q37_m[1])
		return q37_pp
	var q37_exp := {"spirits": q37_wd * int(q37_E["spirits"]["dual_won"]) + q37_ld * int(q37_E["spirits"]["dual_fought"]) + int(q37_r["spars_won"]) * int(q37_E["spirits"]["spar_won"]) + (int(q37_r["spars"]) - int(q37_r["spars_won"])) * int(q37_E["spirits"]["spar_fought"]),
		"hbp": q37_wd * int(q37_E["hbp"]["dual_won"]) + int(q37_r["spars_won"]) * int(q37_E["hbp"]["spar_won"]) + int(q37_r["beats"]) * int(q37_E["hbp"].get("story", 0)) + int(q37_r["quests"]) * int(q37_E["hbp"].get("quest", 0)),
		"prestige": int(q37_r["scraps_won"]) * mini(int(q37_E["prestige"]["cap"]), int(q37_E["prestige"]["scrap_base"]) + int(q37_E["prestige"]["per_tier"]) * 2) + q37_rep.call(q37_r),
		"xp": q37_wd * (int(q37_x.call(40 + 25)) + int(q37_x.call(100))) + q37_ld * (int(q37_x.call(40 + 25)) + int(q37_x.call(40))) + int(q37_r["scraps_won"]) * int(q37_x.call(15)) + (int(q37_r["scraps"]) - int(q37_r["scraps_won"])) * int(q37_x.call(5)) + int(q37_r["spars_won"]) * int(q37_x.call(60)) + (int(q37_r["spars"]) - int(q37_r["spars_won"])) * int(q37_x.call(40)),
		"beans": int(q37_r["slots"]) * 5}
	var q37_all: Dictionary = TNBFaucets.faucet(content, q37_F, {"won": 40, "lost": 10})
	_sr("the faucet through the sim's own paths: %s - %d duals (%d won), %d scraps (%d won), %d spars (%d won), %d slots (%s); paid %s, the table's arithmetic %s; L%d; all three phases %s" % [str(q37_r["id"]), int(q37_r["duals"]), q37_wd, int(q37_r["scraps"]), int(q37_r["scraps_won"]), int(q37_r["spars"]), int(q37_r["spars_won"]), int(q37_r["slots"]), str(q37_r["game"]), JSON.stringify(q37_f1["paid"]), JSON.stringify(q37_exp), int(q37_f1["level"]), JSON.stringify([q37_all["counts"]["episodes"], q37_all["counts"]["sessions"], q37_all["phases"].map(func(q37_z): return int(q37_z["level"]))])],
		int(q37_r["duals"]) == 6 and q37_wd == 5 and absf(float(q37_r["sessions"]) - 10.0) < 0.0001 and int(q37_r["scraps"]) == 50 and int(q37_r["spars"]) == 15 and int(q37_r["slots"]) == 10 and int(q37_r["beats"]) == 10 and int(q37_r["quests"]) == 10 \
		and int(q37_f1["paid"]["spirits"]) == int(q37_exp["spirits"]) and int(q37_f1["paid"]["hbp"]) == int(q37_exp["hbp"]) and int(q37_f1["paid"]["prestige"]) == int(q37_exp["prestige"]) and int(q37_f1["paid"]["xp"]) == int(q37_exp["xp"]) and int(q37_f1["paid"]["beans"]) == int(q37_exp["beans"]) \
		and int(q37_all["counts"]["episodes"]) == 48 and absf(float(q37_all["counts"]["sessions"]) - 80.0) < 0.0001 and int(q37_all["phases"][2]["level"]) > int(q37_all["phases"][0]["level"]))
	# the sinks priced from the live tables: the five tracks to T3 (5 x 1,350 HBP, 5 x 50 Spirits), a Forge (40 Spirits, 30 Beans); the
	# audit's PRIYA priced off her ledger - the ascensions 10 + 25 + 60, her raises at their prices (the Beans she spent, nothing else
	# pays Beans), her kit's shop moves at their shelf; budget less what is left would read her Spirits short by her trials' two spars'
	# pay; since PAC-098 Prestige is wanted at the scouting machine - every rare lead it holds at the club's start, at the pity's pulls
	var q37_sk: Dictionary = TNBFaucets.sinks(content, q37_F, q35_A, [q35_pb])
	var q37_sp: Dictionary = q37_sk["spends"][0]
	var q37_kh := 0
	for q37_mv in q37_sp["kit"]: q37_kh += int(content["techniques"]["shop"]["tiers"][q37_s.shop_tier_of(str(q37_mv))]["hbp"])
	_sr("the sinks priced from the live tables: the gym %s, the Forge %s; PRIYA %s (budget less left: Spirits %d, Beans %d); the squad of %d wants %s" % [JSON.stringify(q37_sk["facilities"]), JSON.stringify(q37_sk["forge"]), JSON.stringify(q37_sp), int(q35_A["budget"]["spirits"]) - int(q35_pb["left"]["spirits"]), int(q35_A["budget"]["beans"]) - int(q35_pb["left"]["beans"]), int(q37_sk["squad"]), JSON.stringify(q37_sk["want"])],
		int(q37_sk["facilities"]["hbp"]) == 6750 and int(q37_sk["facilities"]["spirits"]) == 250 and q37_sk["forge"] == {"spirits": 40, "beans": 30} and int(q37_sp["spirits"]) == 95 \
		and int(q37_sp["beans"]) == int(q35_A["budget"]["beans"]) - int(q35_pb["left"]["beans"]) and int(q37_sp["kit_hbp"]) == q37_kh and q37_sp["kit"].size() > 0 and int(q35_A["budget"]["spirits"]) - int(q35_pb["left"]["spirits"]) == 95 - 2 * int(q37_E["spirits"]["spar_won"]) \
		and int(q37_sk["want"]["spirits"]) == 8 * 95 + 250 + 40 and int(q37_sk["want"]["hbp"]) == 8 * int(q37_sp["hbp"]) + 6750 and int(q37_sk["want"]["prestige"]) == int(q37_sk["scout"]["rares"]) * 10 * 10 and int(q37_sk["scout"]["rares"]) == 14)
	# the verdict names the currency: on the sample above the fixed economy (PAC-098) is GREEN; the economy as PAC-097 found it - no pace,
	# a spar's 3 / 5 Spirits, no story or quest HBP, no scouting machine, the audit's jar at 100 - is RED and names all five (XP short of
	# level 35, Spirits over the band, HBP under it and under the obsolescence budget, Beans over it, Prestige with no live sink); with every
	# bar opened (the band to 100%, the level's band to 99, NP_11 s6's bands to anything, a sinkless Prestige allowed, the obsolescence
	# budget and level cut to what the faucet pays) the machinery says GREEN
	var q37_v0: Dictionary = TNBFaucets.run(content, q37_F, q35_A, {"sample_given": q37_sm})
	var q37_old: Dictionary = content.duplicate(); q37_old["economy"] = content["economy"].duplicate(true)
	q37_old["economy"]["xp"].erase("pace"); q37_old["economy"]["spirits"]["spar_fought"] = 3; q37_old["economy"]["spirits"]["spar_won"] = 5
	q37_old["economy"]["hbp"].erase("story"); q37_old["economy"]["hbp"].erase("quest"); q37_old["economy"].erase("scouting"); q37_old["economy"]["prestige"].erase("pull")
	var q37_Aold: Dictionary = q35_A.duplicate(true); q37_Aold["budget"]["spirits"] = 95; q37_Aold["budget"]["beans"] = 100; q37_Aold["budget"]["hbp"] = 3000
	var q37_sm_old: Dictionary = q37_sm.duplicate(); q37_sm_old["builds"] = [TNBAudit.build(q37_old, q37_Aold, q35_cards[0])]
	var q37_v1: Dictionary = TNBFaucets.run(q37_old, q37_F, q37_Aold, {"sample_given": q37_sm_old})
	var q37_Fo: Dictionary = q37_F.duplicate(true); q37_Fo["target"]["band"] = 1.0; q37_Fo["pace"]["level_band"] = 99
	for q37_bk in q37_Fo["baselines"]:
		if q37_Fo["baselines"][q37_bk] is Array: q37_Fo["baselines"][q37_bk] = [0, 1000000]
	var q37_Ao: Dictionary = q37_Aold.duplicate(true); q37_Ao["budget"]["hbp"] = 1000; q37_Ao["endgame"]["level"] = 20
	var q37_v2: Dictionary = TNBFaucets.run(q37_old, q37_Fo, q37_Ao, {"sample_given": q37_sm_old, "sinkless_ok": true})
	var q37_ln: Array = TNBFaucets.lines(q37_v1, q37_F)
	_sr("the verdict names the currency: the fixed economy %s %s; as PAC-097 found it %s -> %s; every bar opened %s; the report %d lines" % ["GREEN" if bool(q37_v0["green"]) else "RED", JSON.stringify(q37_v0["fails"].keys()), JSON.stringify(q37_v1["fails"].keys()), "GREEN" if bool(q37_v1["green"]) else "RED", "GREEN" if bool(q37_v2["green"]) else "RED " + JSON.stringify(q37_v2["fails"]), q37_ln.size()],
		bool(q37_v0["green"]) and not bool(q37_v1["green"]) and q37_v1["fails"].keys().size() == 5 and q37_v1["systems"].size() == 5 and str(q37_v1["fails"]["xp"]).contains("level") and str(q37_v1["fails"]["prestige"]).contains("no live sink") \
		and str(q37_v1["fails"]["hbp"]).contains("the obsolescence audit's") and bool(q37_v2["green"]) and q37_v2["fails"].is_empty() and q37_ln.size() >= 11 and str(q37_ln[0]).begins_with("FAUCETS :: NP_11 s6"))

	# ---- PAC-098: WHAT THE FAUCET AUDIT NAMED, FIXED (NP_11 s2, s6; NP_02 s4; NP_08 s2.4) ----
	var q38_E: Dictionary = content["economy"]
	# the fixes as data: XP's pace (2.7, every payment); a spar's Spirits 2 either way, a dual's 5 / 8 (NP_11 s6's 3-8 a session); a story
	# beat's HBP 50 and a quest step's 30; the machine's pull 10 and its pity 10; the open mat every 7th day, its priority 10, the stable's
	# 100; the obsolescence budget now the faucet's share - Spirits, Beans and HBP paid by Arc 3, over the eight, at the 70% target, rounded
	var q38_fp: Dictionary = TNBFaucets.faucet(content, q37_F, {"won": 43, "lost": 43})["paid"]
	var q38_der: Array = [int(round(float(q38_fp["spirits"]) / 8.0 / 0.7 / 10.0)) * 10, int(round(float(q38_fp["beans"]) / 8.0 / 0.7 / 10.0)) * 10, int(round(float(q38_fp["hbp"]) / 8.0 / 0.7 / 100.0)) * 100]
	var q38_d: Array = [float(q38_E["xp"]["pace"]), [int(q38_E["spirits"]["spar_fought"]), int(q38_E["spirits"]["spar_won"]), int(q38_E["spirits"]["dual_fought"]), int(q38_E["spirits"]["dual_won"])], [int(q38_E["hbp"]["story"]), int(q38_E["hbp"]["quest"])],
		[int(q38_E["prestige"]["pull"]), int(q38_E["prestige"]["pity"])], [int(q38_E["scouting"]["open_mat_every"]), int(q38_E["scouting"]["priority"]), int(q38_E["scouting"]["stable_cap"]), q38_E["scouting"]["districts"].size()],
		[int(q35_A["budget"]["spirits"]), int(q35_A["budget"]["beans"]), int(q35_A["budget"]["hbp"])], [int(q38_fp["spirits"]), int(q38_fp["beans"]), int(q38_fp["hbp"])], q38_der]
	_sr("the fixes as data (NP_11 s2, s6; NP_08 s2.4): %s" % JSON.stringify(q38_d),
		absf(float(q38_d[0]) - 2.7) < 0.0001 and q38_d[1] == [2, 2, 5, 8] and q38_d[2] == [50, 30] and q38_d[3] == [10, 10] and q38_d[4] == [7, 10, 100, 7] and q38_d[5] == [110, 140, 1700] and q38_d[5] == q38_der)
	# XP's pace: a scrap won pays RORY (houseless) 15 x 1.1 x 2.7 = 45 and SAM (a Tagaq) 15 x 2.7 = 41; the dual's reserve takes half the
	# dual's total at the pace once (the total is paid at the pace already); the faucet's captain stands at level 35 by Arc 3 and at 21 with
	# the pace taken out
	var q38_a := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8); q38_a.start_scrap("SCR-01", 1); q38_a.obj["met"] = true; q38_a._end_bout()
	var q38_sam := make_sim(1, 7, [TNBSim.LINEUP_MILLBROOK_8[4]] + TNBSim.LINEUP_MILLBROOK_8.slice(0, 4)); q38_sam.start_scrap("SCR-01", 1); q38_sam.obj["met"] = true; q38_sam._end_bout()
	var q38_h := make_sim(1, 7); quiet(q38_h)
	for q38_i in 3:
		q38_h.ep_p += 6; q38_h._end_segment("clock")
		if q38_h.mode == "CARD": q38_h.corner_pick(0)
		if q38_h.mode == "CORNER": q38_h.corner_pick(0)
	var q38_tot: int = q38_h.xp_of("RORY") + q38_h.xp_of("PRIYA") + q38_h.xp_of("MARCUS")
	var q38_np: Dictionary = content.duplicate(); q38_np["economy"] = content["economy"].duplicate(true); q38_np["economy"]["xp"].erase("pace")
	var q38_lv: Array = [TNBFaucets.faucet(content, q37_F, {"won": 43, "lost": 43})["level"], TNBFaucets.faucet(q38_np, q37_F, {"won": 43, "lost": 43})["level"]]
	_sr("XP's pace: a scrap won pays RORY %d and SAM %d; three segments won - the dual's total %d, JUNE on the bench %d (half at the pace once, x1.1); the faucet's captain at Arc 3 level %d, without the pace %d" % [q38_a.xp_of("RORY"), q38_sam.xp_of("SAM"), q38_tot, q38_h.xp_of("JUNE"), int(q38_lv[0]), int(q38_lv[1])],
		q38_a.xp_of("RORY") == 45 and q38_sam.xp_of("SAM") == 41 and absi(q38_h.xp_of("JUNE") - int(round(float(q38_tot) * 0.5 * 1.1))) <= 2 and int(q38_lv[0]) >= 33 and int(q38_lv[0]) <= 37 and int(q38_lv[1]) < 33)
	# the story's pay (NP_02 s4, NP_11 s6): story_mark lands a flag and pays - a quest step 30 HBP, a story beat 50, a blessing nothing; the
	# same flag again is refused; Remy, approached, waits on QUEST(cold_storage) and is ready the moment the quest lands through it; a seeded
	# flag (-- flag=) pays nothing
	var q38_st := make_sim(1, 7); q38_st.mode = "OVER"
	var q38_sp: Array = [q38_st.story_mark("quest:harbour")["hbp"], q38_st.story_mark("story:regionals")["hbp"], q38_st.story_mark("blessing:tremblay")["hbp"], q38_st.story_mark("quest:harbour")["ok"], int(q38_st.rewards["hbp"]), q38_st._flag_set("blessing:tremblay")]
	var q38_rm := make_sim(1, 7); q38_rm.mode = "OVER"; q38_rm.rewards["recruit"]["remy_moreau"] = {"state": "approachable", "witnessed": 0, "day": 1}; q38_rm.approach("remy_moreau")
	var q38_rw: Array = [bool(q38_rm.recruit_view("remy_moreau")["met"])]
	q38_rm.story_mark("quest:cold_storage")
	q38_rw.append_array([bool(q38_rm.recruit_view("remy_moreau")["met"]), count_events(q38_rm.events, "recruit_ready", {"name": "remy_moreau"}), bool(q38_rm.recruit("remy_moreau")["ok"])])
	var q38_seed := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story({}, "quest:harbour"))
	_sr("the story's pay: quest, story beat, blessing %s, again refused %s, the ledger %d HBP, the blessing on it %s; Remy met before / after quest:cold_storage %s; a seeded flag pays %d" % [JSON.stringify(q38_sp.slice(0, 3)), str(not bool(q38_sp[3])), int(q38_sp[4]), str(q38_sp[5]), JSON.stringify(q38_rw), int(q38_seed.rewards["hbp"])],
		q38_sp.slice(0, 3) == [30, 50, 0] and not bool(q38_sp[3]) and int(q38_sp[4]) == 80 and bool(q38_sp[5]) and q38_rw == [false, true, 1, true] and int(q38_seed.rewards["hbp"]) == 0)
	# the scouting machine and the open mat (NP_08 s2.4, NP_11 s6): no pull without 10 Prestige; on 100, nine pulls point at generics on
	# the open mat and the tenth is rare - a named recruit nobody had flagged turns approachable, the lead his; the eleventh refused; off an
	# open-mat day a signing costs the priority (refused on nothing, signed on 10), on the 7th day free; the signed generic in the stable
	# and back from a save; the machine's rare pool at the start 14 (the table's 13 and Vera Iron), and with every recruit flagged the
	# rare lead turns Vera face up on the String Wall
	var q38_m := make_sim(1, 7); q38_m.mode = "OVER"
	var q38_mr: Array = [q38_m.scout_why(), q38_m.scout_rares().size()]
	q38_m.rewards["prestige"] = 100
	var q38_leads: Array = []
	for q38_i in 10: q38_leads.append(q38_m.scout_pull()["lead"])
	var q38_rare: Dictionary = q38_leads[9]
	q38_mr.append_array([q38_leads.slice(0, 9).filter(func(q38_l): return not bool(q38_l["rare"])).size(), q38_m.open_mat().size(), bool(q38_rare["rare"]), q38_m.recruit_state(str(q38_rare["id"])), int(q38_m.rewards["recruit"][str(q38_rare["id"])].get("lead", 0)), q38_m.scout_pull()["ok"]])
	var q38_g0: String = str(q38_m.open_mat()[0]["name"])
	q38_mr.append_array([q38_m.open_mat_day(), q38_m.sign_why(0)])
	q38_m.rewards["prestige"] = 10
	var q38_sg: Dictionary = q38_m.sign_generic(0)
	var q38_card: Dictionary = q38_m._stable_card(q38_g0)
	for q38_d2 in 6: q38_m.new_day()
	var q38_sg2: Dictionary = q38_m.sign_generic(0)
	q38_mr.append_array([bool(q38_sg["ok"]), int(q38_sg["priority"]), int(q38_m.rewards["prestige"]), bool(q38_card.get("generic", false)), q38_m.open_mat_day(), bool(q38_sg2["ok"]), int(q38_sg2["priority"])])
	var q38_tx: String = TNBSave.write_text(q38_m, false)
	var q38_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q38_tx), 7)["sim"]
	q38_mr.append_array([q38_bl._stable_card(q38_g0).size() > 0, bool(q38_bl._stable_card(q38_g0).get("generic", false)), TNBSave.write_text(q38_bl, false) == q38_tx])
	var q38_v := make_sim(1, 7); q38_v.mode = "OVER"; q38_v.rewards["prestige"] = 100
	for q38_rn in q38_v.RECRUITS["recruits"]:
		if not q38_v.RECRUITS["recruits"][q38_rn].has("never"): q38_v.rewards["recruit"][str(q38_rn)] = {"state": "approachable", "witnessed": 0, "day": 1}
	for q38_i2 in 10: q38_v.scout_pull()
	q38_mr.append_array([q38_v.scout_rares().size(), q38_v.rewards["string_wall"].has("vera_iron")])
	_sr("the scouting machine and the open mat: %s" % JSON.stringify(q38_mr),
		str(q38_mr[0]) == "a pull costs 10 Prestige (the ledger holds 0)" and int(q38_mr[1]) == 14 and int(q38_mr[2]) == 9 and int(q38_mr[3]) == 9 and bool(q38_mr[4]) and str(q38_mr[5]) == "approachable" and int(q38_mr[6]) == 10 and not bool(q38_mr[7]) \
		and not bool(q38_mr[8]) and str(q38_mr[9]).begins_with("the open mat is every 7th day") and bool(q38_mr[10]) and int(q38_mr[11]) == 10 and int(q38_mr[12]) == 0 and bool(q38_mr[13]) and bool(q38_mr[14]) and bool(q38_mr[15]) and int(q38_mr[16]) == 0 \
		and bool(q38_mr[17]) and bool(q38_mr[18]) and bool(q38_mr[19]) and int(q38_mr[20]) == 0 and bool(q38_mr[21]))
	# each fix against its absence: on the sample above the fixed economy is GREEN; take one fix out and the audit names exactly its
	# currency - the pace (XP), a spar's 3 / 5 Spirits back (Spirits), the story's and the quests' HBP (HBP), the machine (Prestige), the
	# jar back at 100 (Beans)
	var q38_var := func(q38_mod: Callable, q38_bud: int) -> Array:
		var q38_c: Dictionary = content.duplicate(); q38_c["economy"] = content["economy"].duplicate(true); q38_mod.call(q38_c["economy"])
		var q38_Ax: Dictionary = q35_A.duplicate(true)
		var q38_smx: Dictionary = q37_sm
		if q38_bud > 0:
			q38_Ax["budget"]["beans"] = q38_bud; q38_smx = q37_sm.duplicate(); q38_smx["builds"] = [TNBAudit.build(q38_c, q38_Ax, q35_cards[0])]
		var q38_r: Dictionary = TNBFaucets.run(q38_c, q37_F, q38_Ax, {"sample_given": q38_smx})
		return q38_r["fails"].keys()
	var q38_none := func(q38_e0: Dictionary): pass
	var q38_nopace := func(q38_e1: Dictionary): q38_e1["xp"].erase("pace")
	var q38_oldsp := func(q38_e2: Dictionary): q38_e2["spirits"]["spar_fought"] = 3; q38_e2["spirits"]["spar_won"] = 5
	var q38_nostory := func(q38_e3: Dictionary): q38_e3["hbp"].erase("story"); q38_e3["hbp"].erase("quest")
	var q38_nomachine := func(q38_e4: Dictionary): q38_e4.erase("scouting")
	var q38_fx: Array = [q38_var.call(q38_none, 0), q38_var.call(q38_nopace, 0), q38_var.call(q38_oldsp, 0), q38_var.call(q38_nostory, 0), q38_var.call(q38_nomachine, 0), q38_var.call(q38_none, 100)]
	_sr("each fix against its absence: fixed %s; the pace out %s; the old spar Spirits %s; the story's HBP out %s; the machine out %s; the jar at 100 %s" % [JSON.stringify(q38_fx[0]), JSON.stringify(q38_fx[1]), JSON.stringify(q38_fx[2]), JSON.stringify(q38_fx[3]), JSON.stringify(q38_fx[4]), JSON.stringify(q38_fx[5])],
		q38_fx[0] == [] and "xp" in q38_fx[1] and q38_fx[2] == ["spirits"] and "hbp" in q38_fx[3] and q38_fx[4] == ["prestige"] and q38_fx[5] == ["beans"])

	# ---- PAC-099: THE STABLE ROLES (NP_08 s1; NP_11 s9 Fighter.stable_role / home_district) ----
	var q39_R: Dictionary = content["economy"]["roles"]
	# the roles as data: NP_11 s9's four; a training partner's Bean for every 10 points he leads by, 3 at most; a scout's district 1 Prestige
	# a day and 20 on the projection; a trainee one use a dual; the homes - the Millbrook eight by the table (the houseless Millbrook
	# Secondary, a House card his House's root on the circuit's districts), a generic from the machine his own district; every card FIGHTER
	var q39_hm := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8); q39_hm.mode = "OVER"; q39_hm.rewards["prestige"] = 20
	var q39_gl: Dictionary = q39_hm.scout_pull()["lead"]; q39_hm.sign_generic(0)
	var q39_homes: Array = TNBSim.LINEUP_MILLBROOK_8.map(func(q39_c): return q39_hm.home_district(str(q39_c["name"])))
	var q39_d: Array = [TNBSim.ROLE_IDS, [int(q39_R["training"]["per"]), int(q39_R["training"]["cap"])], [int(q39_R["scout"]["prestige"]), int(q39_R["scout"]["projection_pct"])], int(q39_R["corner"]["uses"]), q39_R["home"]["houses"].size(), q39_homes,
		[str(q39_gl["district"]), q39_hm.home_district(str(q39_gl["label"]))], q39_hm.stable.map(func(q39_c2): return q39_hm.stable_role(str(q39_c2["name"])))]
	_sr("the roles as data (NP_08 s1, NP_11 s9): %s" % JSON.stringify(q39_d),
		q39_d[0] == ["FIGHTER", "TRAINING", "SCOUT", "CORNER_TRAINEE"] and q39_d[1] == [10, 3] and q39_d[2] == [1, 20] and int(q39_d[3]) == 1 and int(q39_d[4]) == 12 \
		and q39_homes == ["school", "school", "school", "school", "north", "maritimes", "prairies", "montreal"] and str(q39_d[6][0]) != "" and str(q39_d[6][0]) == str(q39_d[6][1]) and q39_d[7].size() == 9 and q39_d[7].count("FIGHTER") == 9)
	# the mini's four dressed and a bench of four: YURI (House Kowalchuk - the prairies), three generics of the tier given (HILL 1, RINK 2, HILL 3)
	var q39_mk := func(q39_tier: int, q39_over: bool) -> TNBSim:
		var q39_s := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities({}, "bags_mitts:1", content["facilities"]))
		if q39_over: q39_s.mode = "OVER"
		q39_s.stable.append(TNBSim.LINEUP_MILLBROOK_8[6].duplicate(true))
		for q39_dn in [["HILL 1", "hill"], ["RINK 2", "rink"], ["HILL 3", "hill"]]:
			var q39_sp: Dictionary = q39_s.generic_spec(str(q39_dn[0]), "BOXERPUNCHER", "", q39_tier)
			q39_s.stable.append({"name": str(q39_dn[0]), "hissatsu": "", "talk": "", "style": str(q39_sp["style"]), "element": str(q39_sp["element"]), "house": str(q39_sp["house"]), "generic": true, "tier": q39_tier, "stats": q39_sp["stats"].duplicate(), "district": str(q39_dn[1])})
		for q39_pn in ["YURI", "HILL 1", "RINK 2", "HILL 3"]: q39_s._gw_pin_new(q39_pn, "")                   # on the Gym Wall, as a card that joins is
		return q39_s
	var q39_last := func(q39_s2: TNBSim, q39_k: String) -> Dictionary:
		for q39_j in range(q39_s2.events.size() - 1, -1, -1):
			if str(q39_s2.events[q39_j]["kind"]) == q39_k: return q39_s2.events[q39_j]
		return {}
	# a role is set between duals on a stable card not dressed - the dressed, a role unknown, a card not in the stable refused; the aid's
	# picks down the bench: a training partner first, a scout for each district nobody covers, then the corner; a working bench refused, the
	# same role twice refused; Shift+7's back to the ring; mid-fight refused
	var q39_a: TNBSim = q39_mk.call(1, true)
	var q39_ref: Array = [q39_a.assign_role("RORY", "SCOUT")["why"], q39_a.assign_role("YURI", "MANAGER")["why"], q39_a.assign_role("NOBODY", "SCOUT")["why"]]
	var q39_pk: Array = []
	for q39_i in 4:
		var q39_ar: Dictionary = q39_a.assign_role("*")
		q39_pk.append("%s:%s" % [str(q39_ar.get("name", "")), str(q39_ar.get("role", ""))])
	q39_ref.append_array([q39_a.assign_role("*")["why"], q39_a.assign_role("YURI", "TRAINING")["why"]])
	var q39_bk: Dictionary = q39_a.role_back()
	var q39_f := make_sim(1, 7); q39_f.stable.append(TNBSim.LINEUP_MILLBROOK_8[6].duplicate(true))
	for q39_i2 in 5: q39_f.step({})
	q39_ref.append(q39_f.assign_role("YURI", "SCOUT")["why"])
	_sr("the roles set: refused %s; the aid's picks %s; back to the ring %s (%s)" % [JSON.stringify(q39_ref), JSON.stringify(q39_pk), str(q39_bk.get("name", "")), q39_a.stable_role("HILL 3")],
		q39_ref == ["RORY is dressed - a role is worked from the bench", "no role 'MANAGER' (FIGHTER / TRAINING / SCOUT / CORNER_TRAINEE)", "NOBODY is not in the stable", "nobody on the bench without a role (the bench 4)", "YURI is already training partner", "roles are set between duals"] \
		and q39_pk == ["YURI:TRAINING", "HILL 1:SCOUT", "RINK 2:SCOUT", "HILL 3:CORNER_TRAINEE"] and bool(q39_bk["ok"]) and str(q39_bk["name"]) == "HILL 3" and q39_a.stable_role("HILL 3") == "FIGHTER" and count_events(q39_a.events, "role_set") == 5)
	# the training partner against its absence (JUNE at the heavy bag, grade 0.5: 5 Beans, PWR): YURI the partner (PWR 80 to her 30, the lead
	# capped at 3) goes along unnamed, +3 PWR; no role, 5; YURI named along without the role, 5 (the quarter's flavour, PWR either way); at the
	# mitts (SPD - YURI 40 to her 75) nobody goes along; YURI dressed, his role waits; a tier-1 generic (40 to her 30) +1
	var q39_tr := func(q39_role: String, q39_game: String, q39_named: String, q39_dress: bool) -> Array:
		var q39_s4: TNBSim = q39_mk.call(1, true)
		if q39_role != "": q39_s4.assign_role(q39_role, "TRAINING")
		if q39_dress: q39_s4.dressed.append(q39_s4._stable_card("YURI").duplicate(true))
		var q39_r: Dictionary = q39_s4.train(q39_game, "JUNE", 0.5, q39_named)
		var q39_e: Dictionary = q39_last.call(q39_s4, "training")
		return [int(q39_r["beans"]), str(q39_r["partner"]), int(q39_r["bonus"]), q39_e.get("typed", {}), int(q39_s4.rewards.get("roles", {}).get("paid", {}).get("beans", 0))]
	var q39_trs: Array = [q39_tr.call("YURI", "heavy_bag", "", false), q39_tr.call("", "heavy_bag", "", false), q39_tr.call("", "heavy_bag", "YURI", false), q39_tr.call("YURI", "mitts", "", false), q39_tr.call("YURI", "heavy_bag", "", true), q39_tr.call("HILL 1", "heavy_bag", "", false)]
	_sr("the training partner against its absence (JUNE, the heavy bag): YURI the partner %s; no role %s; YURI named without the role %s; at the mitts %s; YURI dressed %s; a tier-1 generic %s" % [JSON.stringify(q39_trs[0]), JSON.stringify(q39_trs[1]), JSON.stringify(q39_trs[2]), JSON.stringify(q39_trs[3]), JSON.stringify(q39_trs[4]), JSON.stringify(q39_trs[5])],
		q39_trs[0] == [8, "YURI", 3, {"PWR": 8}, 3] and q39_trs[1] == [5, "", 0, {"PWR": 5}, 0] and q39_trs[2] == [5, "YURI", 0, {"PWR": 5}, 0] and int(q39_trs[3][2]) == 0 and str(q39_trs[3][1]) == "" and q39_trs[4] == [5, "", 0, {"PWR": 5}, 0] and q39_trs[5] == [6, "HILL 1", 1, {"PWR": 6}, 1])
	# the scout against its absence: a day turns - no scouts 0; HILL 1 +1; HILL 3 beside him still +1 (the district once); RINK 2 +2; YURI +3;
	# YURI dressed (his role waits) +2. On the projection against the Grain Kings (the prairies): YURI scouting reads their order at +20 on
	# every slot; HILL 1's district is no circuit's, nothing
	var q39_sc: TNBSim = q39_mk.call(1, true)
	var q39_day := func(q39_s5: TNBSim) -> int:
		var q39_p0 := int(q39_s5.rewards["prestige"]); q39_s5.new_day(); return int(q39_s5.rewards["prestige"]) - q39_p0
	var q39_scd: Array = [q39_day.call(q39_sc)]
	for q39_nm in ["HILL 1", "HILL 3", "RINK 2", "YURI"]:
		q39_sc.assign_role(str(q39_nm), "SCOUT"); q39_scd.append(q39_day.call(q39_sc))
	q39_sc.dressed.append(q39_sc._stable_card("YURI").duplicate(true)); q39_scd.append(q39_day.call(q39_sc))
	var q39_ev: Dictionary = q39_last.call(q39_sc, "scouted")
	var q39_pj: TNBSim = q39_mk.call(1, false)
	var q39_conf := func(q39_pr: Dictionary) -> Array: return q39_pr.get("slots", []).map(func(q39_sl): return int(q39_sl["confidence"]))
	var q39_pr0: Dictionary = q39_pj.projection()
	q39_pj.assign_role("HILL 1", "SCOUT")
	var q39_pr1: Dictionary = q39_pj.projection()
	q39_pj.assign_role("YURI", "SCOUT")
	var q39_pr2: Dictionary = q39_pj.projection()
	var q39_scs: Array = q39_pr2["sources"].filter(func(q39_so): return str(q39_so["source"]) == "scout")
	_sr("the scout against its absence: a day's Prestige %s (the last day %s, the ledger's roles paid %d); vs %s the order %s, HILL 1 scouting %s, YURI scouting %s - \"%s\"" % [JSON.stringify(q39_scd), JSON.stringify(q39_ev.get("districts", [])), int(q39_sc.rewards["roles"]["paid"]["prestige"]), str(q39_pr0.get("coach", "")), JSON.stringify(q39_conf.call(q39_pr0)), JSON.stringify(q39_conf.call(q39_pr1)), JSON.stringify(q39_conf.call(q39_pr2)), str(q39_scs[0]["what"]) if q39_scs.size() > 0 else "-"],
		q39_scd == [0, 1, 1, 2, 3, 2] and q39_ev.get("districts", []) == ["hill", "rink"] and int(q39_sc.rewards["roles"]["paid"]["prestige"]) == 9 and str(q39_pr0.get("coach", "")) == "grain_kings" and q39_conf.call(q39_pr1) == q39_conf.call(q39_pr0) \
		and q39_scs.size() == 1 and int(q39_scs[0]["pct"]) == 20 and str(q39_scs[0]["what"]) == "YURI scouting prairies (the stable role)" and q39_conf.call(q39_pr0).size() > 0 and range(q39_conf.call(q39_pr0).size()).all(func(q39_k2): return int(q39_conf.call(q39_pr2)[q39_k2]) == mini(95, int(q39_conf.call(q39_pr0)[q39_k2]) + 20)))
	# the cornerman-in-training against its absence: a dual's end with no trainee feeds nobody; RINK 2 and HILL 3 in the corner feed the two
	# dressed staffers with the fewest uses one each; with the dressed three at Lv3 they feed the corps' next; one at 2 uses reaches Lv2 on a
	# trainee's use; a trainee dressed waits
	var q39_cn: TNBSim = q39_mk.call(1, true)
	var q39_sd: Array = q39_cn.staff_dressed()
	var q39_uses := func(q39_s6: TNBSim, q39_ids: Array) -> Array: return q39_ids.map(func(q39_x): return q39_s6.staff_uses(str(q39_x)))
	var q39_cu: Array = [q39_uses.call(q39_cn, q39_sd)]
	q39_cn._pay_dual(true); q39_cu.append(q39_uses.call(q39_cn, q39_sd))
	q39_cn.assign_role("RINK 2", "CORNER_TRAINEE"); q39_cn.assign_role("HILL 3", "CORNER_TRAINEE")
	q39_cn._pay_dual(true); q39_cu.append(q39_uses.call(q39_cn, q39_sd))
	for q39_x2 in q39_sd: q39_cn.rewards["staff"][str(q39_x2)] = 8
	q39_cn._pay_dual(true)
	var q39_corps: Array = q39_cn.STAFF["corps"].map(func(q39_c3): return str(q39_c3["id"])).filter(func(q39_x3): return not (q39_x3 in q39_sd) and q39_cn.staff_uses(str(q39_x3)) > 0)
	var q39_lv := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities({}, "bags_mitts:1", content["facilities"])); q39_lv.mode = "OVER"
	q39_lv.stable.append(TNBSim.LINEUP_MILLBROOK_8[6].duplicate(true)); q39_lv.assign_role("YURI", "CORNER_TRAINEE")
	for q39_x4 in q39_lv.staff_dressed(): q39_lv.rewards["staff"][str(q39_x4)] = 2
	q39_lv._pay_dual(true)
	var q39_lve: Dictionary = q39_last.call(q39_lv, "staff_level")
	q39_lv.dressed.append(q39_lv._stable_card("YURI").duplicate(true)); var q39_lv0: int = int(q39_lv.rewards["roles"]["paid"]["uses"]); q39_lv._pay_dual(true)
	_sr("the cornerman-in-training against its absence: the dressed three's uses %s; the corps' next fed %s; a use to Lv2 %s; dressed, the uses %d -> %d" % [JSON.stringify(q39_cu), JSON.stringify(q39_corps), JSON.stringify([str(q39_lve.get("who", "")), int(q39_lve.get("level", 0))]), q39_lv0, int(q39_lv.rewards["roles"]["paid"]["uses"])],
		q39_sd.size() == 3 and q39_cu[0] == [0, 0, 0] and q39_cu[1] == [0, 0, 0] and q39_cu[2] == [1, 1, 0] and q39_corps.size() == 2 and int(q39_cn.rewards["roles"]["paid"]["uses"]) == 4 \
		and str(q39_lve.get("who", "")) == str(q39_lv.staff_dressed()[0]) and int(q39_lve.get("level", 0)) == 2 and q39_lv0 == 1 and int(q39_lv.rewards["roles"]["paid"]["uses"]) == 1)
	# the save: the roles ride the reward ledger; each Fighter record carries his stable_role and home_district (a generic his own district,
	# read back); a load holds the roles and writes back byte-equal
	var q39_v: TNBSim = q39_mk.call(1, true)
	q39_v.assign_role("YURI", "TRAINING"); q39_v.assign_role("HILL 1", "SCOUT"); q39_v.assign_role("RINK 2", "CORNER_TRAINEE")
	var q39_tx: String = TNBSave.write_text(q39_v, false)
	var q39_recs: Dictionary = {}
	for q39_fr in TNBSave.to_save(q39_v)["stable"]: q39_recs[str(q39_fr["name"])] = [str(q39_fr["stable_role"]), str(q39_fr.get("home_district", "")), bool(q39_fr.get("dressed", true))]
	var q39_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q39_tx), 7)["sim"]
	var q39_back: Array = [q39_bl.stable_role("YURI"), q39_bl.stable_role("HILL 1"), q39_bl.stable_role("RINK 2"), q39_bl.stable_role("HILL 3"), q39_bl.home_district("HILL 1"), q39_bl.home_district("RINK 2"), TNBSave.write_text(q39_bl, false) == q39_tx]
	_sr("the roles in the save: the records %s; loaded %s" % [JSON.stringify(q39_recs), JSON.stringify(q39_back)],
		q39_recs.get("YURI", []) == ["TRAINING", "prairies", false] and q39_recs.get("HILL 1", []) == ["SCOUT", "hill", false] and q39_recs.get("RINK 2", []) == ["CORNER_TRAINEE", "rink", false] and q39_recs.get("RORY", []) == ["FIGHTER", "school", true] \
		and q39_back == ["TRAINING", "SCOUT", "CORNER_TRAINEE", "FIGHTER", "hill", "rink", true])
	# the faucet's bench against its absence: from the circuit three tier-1 generics (the club phase's pulls) work the roles - the scout's
	# district pays Prestige every day, the partner adds nothing to RORY (40 at every stat is no lead on his), the trainee a use a dual; the
	# Prestige share re-read, the verdict GREEN both ways, nothing else paid differently
	var q39_F0: Dictionary = q37_F.duplicate(true); q39_F0["pace"].erase("bench")
	var q39_r1: Dictionary = TNBFaucets.run(content, q37_F, q35_A, {"sample_given": q37_sm})
	var q39_r0: Dictionary = TNBFaucets.run(content, q39_F0, q35_A, {"sample_given": q37_sm})
	var q39_p1: Dictionary = q39_r1["faucet"]["paid"]; var q39_p0: Dictionary = q39_r0["faucet"]["paid"]
	_sr("the faucet's bench against its absence: %s from %s paid %s; Prestige %d vs %d without (the share %d%% vs %d%%), the rest %s; the verdict %s / %s" % [JSON.stringify(q39_r1["faucet"]["bench"].map(func(q39_b): return "%s:%s:T%d" % [str(q39_b["name"]), str(q39_b["role"]), int(q39_b["tier"])])), str(q39_r1["faucet"]["bench_from"]), JSON.stringify(q39_r1["faucet"]["roles_paid"]), int(q39_p1["prestige"]), int(q39_p0["prestige"]), int(round(100.0 * float(q39_r1["share"]["prestige"]))), int(round(100.0 * float(q39_r0["share"]["prestige"]))), "the same" if ["xp", "spirits", "hbp", "beans"].all(func(q39_c4): return int(q39_p1[q39_c4]) == int(q39_p0[q39_c4])) else "DIFFERENT", JSON.stringify(q39_r1["fails"].keys()), JSON.stringify(q39_r0["fails"].keys())],
		q39_r1["faucet"]["bench"].size() == 3 and str(q39_r1["faucet"]["bench_from"]) == "arc1_circuit" and int(q39_r1["faucet"]["roles_paid"]["prestige"]) > 0 and int(q39_r1["faucet"]["roles_paid"]["beans"]) == 0 and int(q39_r1["faucet"]["roles_paid"]["uses"]) == 42 \
		and int(q39_p1["prestige"]) == int(q39_p0["prestige"]) + int(q39_r1["faucet"]["roles_paid"]["prestige"]) and ["xp", "spirits", "hbp", "beans"].all(func(q39_c5): return int(q39_p1[q39_c5]) == int(q39_p0[q39_c5])) and q39_r1["fails"].is_empty() and q39_r0["fails"].is_empty() and q39_r0["faucet"]["bench"].is_empty())

	# ---- PAC-100: THE LOCKER ROOM (NP_08 s4) - the release, three days to take it back, the grudge / warmth flag, the browse ----
	var q40_L: Dictionary = content["economy"]["locker"]
	# the release against its absence (q39's bench: the mini's four dressed, YURI and three generics): HILL 1 - a scout, in the club's tape
	# wraps, 500 XP on the ledger - let go: the stable one fewer, the role cleared, the wraps back in the locker, the card off the Gym Wall,
	# the XP kept under the name, a grudge (no bond left behind). Refused: the story's four, a card not in the stable, a dressed card (SAM on
	# the sanctioned dual), a card with no road back, mid-fight
	var q40_a: TNBSim = q39_mk.call(1, true)
	q40_a.assign_role("HILL 1", "SCOUT"); q40_a.rewards["xp"]["HILL 1"] = 500
	q40_a.rewards["gear"] = {"owned": {"tape_wraps": 1}, "worn": {"HILL 1": ["tape_wraps"]}, "from": {}, "festival": 0}
	var q40_x0: Array = [q40_a.stable.size(), q40_a.gear_free("tape_wraps"), q40_a.gym_wall["cards"].has("HILL 1"), q40_a.stable_role("HILL 1")]
	var q40_r: Dictionary = q40_a.release("HILL 1")
	var q40_x1: Array = [q40_a.stable.size(), q40_a.gear_free("tape_wraps"), q40_a.gym_wall["cards"].has("HILL 1"), q40_a.stable_role("HILL 1"), q40_a.xp_of("HILL 1"), str(q40_r.get("flag", "")), int(q40_r.get("until", 0))]
	var q40_sn := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); q40_sn.mode = "OVER"
	q40_a.stable.append({"name": "WALK-ON", "hissatsu": "", "talk": "", "style": "SLUGGER", "element": "GRANITE", "house": "none", "stats": {"PWR": 50, "SPD": 50, "CHN": 50, "RFX": 50, "BLK": 50, "STA": 50, "HRT": 50}})
	var q40_f := make_sim(1, 7); q40_f.stable.append(TNBSim.LINEUP_MILLBROOK_8[6].duplicate(true))
	for q40_i in 5: q40_f.step({})
	var q40_ref: Array = [q40_a.release("RORY")["why"], q40_a.release("JUNE")["why"], q40_a.release("NOBODY")["why"], q40_sn.release("SAM")["why"], q40_a.release("WALK-ON")["why"], q40_f.release("YURI")["why"]]
	_sr("the release against its absence: HILL 1 [stable, the wraps free, on the wall, role] %s -> %s (XP %d kept, %s, take back until day %d); refused %s" % [JSON.stringify(q40_x0), JSON.stringify(q40_x1.slice(0, 4)), int(q40_x1[4]), str(q40_x1[5]), int(q40_x1[6]), JSON.stringify(q40_ref)],
		[int(q40_L["undo_days"]), q40_L["keep"], int(q40_L["warm_level"]), q40_L["browse"].size()] == [3, ["RORY", "PRIYA", "MARCUS", "JUNE"], 1, 5] and q40_x0 == [8, 0, true, "SCOUT"] and q40_x1.slice(0, 4) == [7, 1, false, "FIGHTER"] and int(q40_x1[4]) == 500 and str(q40_x1[5]) == "grudge" and int(q40_x1[6]) == 4 \
		and q40_ref == ["RORY is the story's own - the club began with RORY", "JUNE is the story's own - the club began with JUNE", "NOBODY is not in the stable", "SAM is dressed - release a card from the bench", "WALK-ON has no road back (no recruit record, not a generic)", "the locker room is visited between duals"])
	# three days to take it back: HILL 1 released on day 1 and taken back on day 3 - the card, the role, the wraps and the wall as before, no
	# memory kept; released again on day 3, the third day after (day 6) settles it - taken back refused, HILL 1 on the open mat with the grudge
	var q40_u: TNBSim = q39_mk.call(1, true)
	q40_u.assign_role("HILL 1", "SCOUT"); q40_u.rewards["gear"] = {"owned": {"tape_wraps": 1}, "worn": {"HILL 1": ["tape_wraps"]}, "from": {}, "festival": 0}
	var q40_c0: Dictionary = q40_u._stable_card("HILL 1").duplicate(true)
	q40_u.release("HILL 1"); q40_u.new_day(); q40_u.new_day()
	var q40_tb: Dictionary = q40_u.take_back("*")
	var q40_ub: Array = [bool(q40_tb["ok"]), int(q40_u.rewards["day"]), q40_u._stable_card("HILL 1") == q40_c0, q40_u.stable_role("HILL 1"), q40_u.gear_free("tape_wraps"), q40_u.gym_wall["cards"].has("HILL 1"), q40_u.memory_of("HILL 1").is_empty(), q40_u.stable.size()]
	q40_u.release("HILL 1")
	var q40_days: Array = []
	for q40_d in 3:
		q40_days.append(q40_u.rewards["locker"]["pending"].has("HILL 1")); q40_u.new_day()
	var q40_om: Array = q40_u.open_mat().map(func(q40_c): return "%s:%s" % [str(q40_c["name"]), str(q40_c.get("released", ""))])
	_sr("three days to take it back: taken back on day 3 %s; released again on day 3, waiting on days 3-5 %s, settled on day %d - taken back %s; the open mat %s; remembered %s" % [JSON.stringify(q40_ub), JSON.stringify(q40_days), int(q40_u.rewards["day"]), str(q40_u.take_back("HILL 1")["why"]), JSON.stringify(q40_om), JSON.stringify(q40_u.memory_of("HILL 1"))],
		q40_ub == [true, 3, true, "SCOUT", 0, true, true, 8] and q40_days == [true, true, true] and int(q40_u.rewards["day"]) == 6 and q40_u.rewards["locker"]["pending"].is_empty() and q40_om == ["HILL 1:grudge"] \
		and str(q40_u.memory_of("HILL 1").get("flag", "")) == "grudge" and int(q40_u.memory_of("HILL 1").get("times", 0)) == 1 and not bool(q40_u.take_back("HILL 1")["ok"]))
	# the road back and the flag (NP_08 s4: "return to their district, remain re-recruitable, and remember"): YURI released with no bond
	# (a grudge) is back in the prairies approachable - his condition (a segment won against his club) and a spar won against him since;
	# the spar won, he joins as he left.
	# YURI with a Lv1 bond to RORY (warmth) answers the approach at once. A generic with a bond (HILL 3 to RORY) signs back free off an
	# open-mat day; HILL 1 (a grudge) costs the priority even on an open-mat day
	var q40_ry := func(q40_bond: bool) -> TNBSim:
		var q40_s: TNBSim = q39_mk.call(1, true)
		if q40_bond: q40_s.rewards["kizuna"][TNBSim.pair_key("RORY", "YURI")] = 12
		q40_s._stable_card("YURI")["surge_tier"] = "T2"
		q40_s.release("YURI")
		for q40_d2 in 3: q40_s.new_day()
		return q40_s
	var q40_g: TNBSim = q40_ry.call(false)
	var q40_gy: Array = [q40_g.recruit_state("yuri_kowalchuk"), str(q40_g.rewards["recruit"]["yuri_kowalchuk"]["released"]["flag"]), "yuri_kowalchuk" in q40_g.scout_rares()]
	q40_g._beat("segment", "yuri_kowalchuk")                                                                # his condition (BEAT_IN(dual[segment])): a segment won against his club
	q40_g.approach("yuri_kowalchuk")
	var q40_gv: Dictionary = q40_g.recruit_view("yuri_kowalchuk")
	q40_gy.append_array([bool(q40_gv["met"]), q40_gv["clauses"].map(func(q40_cl): return "%s %d/%d" % [str(q40_cl["form"]), int(q40_cl["have"]), int(q40_cl["need"])]), str(q40_g.recruit("yuri_kowalchuk")["why"]).begins_with("yuri_kowalchuk is not ready")])
	q40_g._beat("spar", "yuri_kowalchuk")
	q40_gy.append_array([bool(q40_g.recruit_view("yuri_kowalchuk")["met"]), bool(q40_g.recruit("yuri_kowalchuk")["ok"]), str(q40_g._stable_card("YURI").get("surge_tier", "")), str(q40_g.rewards["recruit"]["yuri_kowalchuk"].get("returned", {}).get("flag", "")), q40_g.card_view("YURI").contains("released once, came back with grudge")])
	var q40_w: TNBSim = q40_ry.call(true)
	q40_w.approach("yuri_kowalchuk")
	var q40_wv: Dictionary = q40_w.recruit_view("yuri_kowalchuk")
	var q40_wy: Array = [str(q40_w.rewards["recruit"]["yuri_kowalchuk"]["released"]["bond"]), bool(q40_wv["met"]), q40_wv["clauses"].map(func(q40_cl2): return str(q40_cl2["form"])), bool(q40_w.recruit("yuri_kowalchuk")["ok"])]
	var q40_o: TNBSim = q39_mk.call(1, true)
	q40_o.rewards["kizuna"][TNBSim.pair_key("HILL 3", "RORY")] = 12
	q40_o.release("HILL 3"); q40_o.release("HILL 1")
	for q40_d3 in 3: q40_o.new_day()
	var q40_ow: Dictionary = q40_o.sign_generic(0)
	while not q40_o.open_mat_day(): q40_o.new_day()
	var q40_oy: Array = [bool(q40_ow["ok"]), int(q40_ow["priority"]), int(q40_o.rewards["day"]), q40_o.sign_why(0)]
	q40_o.rewards["prestige"] = 10
	var q40_og: Dictionary = q40_o.sign_generic(0)
	q40_oy.append_array([bool(q40_og["ok"]), int(q40_og["priority"]), q40_o._stable_card("HILL 1").has("released")])
	_sr("the road back and the flag: YURI with a grudge %s; with warmth %s; the open mat - HILL 3 warm, HILL 1 a grudge %s" % [JSON.stringify(q40_gy), JSON.stringify(q40_wy), JSON.stringify(q40_oy)],
		q40_gy == ["approachable", "grudge", false, false, ["BEAT_IN 1/1", "GRUDGE 0/1"], true, true, true, "T2", "grudge", true] and q40_wy == ["RORY", true, ["WARMTH"], true] \
		and q40_oy == [true, 0, 7, "HILL 1 left with a grudge - signing back costs the priority, 10 Prestige (the ledger holds 0)", true, 10, false])
	# NP_08 s1's cap given its valve: a stable of 100 - the open mat and a recruit refused; a bench card released, the open mat signs
	var q40_cp: TNBSim = q39_mk.call(1, true)
	var q40_n := 0
	while q40_cp.stable.size() < 100:
		q40_n += 1; q40_cp.stable.append({"name": "FILL %d" % q40_n, "hissatsu": "", "talk": "", "style": "SLUGGER", "element": "GRANITE", "house": "none", "generic": true, "tier": 1, "stats": {"PWR": 40, "SPD": 40, "CHN": 40, "RFX": 40, "BLK": 40, "STA": 40, "HRT": 40}, "district": "centre"})
	q40_cp.rewards["prestige"] = 20; q40_cp.scout_pull()
	q40_cp.rewards["recruit"]["sam_tagaq"] = {"state": "approached", "witnessed": 0, "day": 1}
	var q40_cap: Array = [q40_cp.stable.size(), q40_cp.sign_why(0), str(q40_cp.recruit("sam_tagaq")["why"])]
	q40_cp.release("*")
	var q40_cs: Dictionary = q40_cp.sign_generic(0)
	_sr("the cap given its valve: at %d the open mat refused \"%s\", a recruit refused \"%s\"; one released, the open mat signs %s (the stable %d)" % [int(q40_cap[0]), str(q40_cap[1]), str(q40_cap[2]), str(bool(q40_cs["ok"])), q40_cp.stable.size()],
		int(q40_cap[0]) == 100 and str(q40_cap[1]) == "the stable holds 100 - NP_08 s1's cap" and str(q40_cap[2]) == "the stable holds 100 - NP_08 s1's cap (the locker room releases a card)" and bool(q40_cs["ok"]) and q40_cp.stable.size() == 100)
	# the browse and the comparison card (NP_08 s4): the stable by House, Style, Element, the bond web and slot-role; YURI's card - his House,
	# Style, Element, home and role, his grown stats, kit, trait, dialect and bonds
	var q40_b: TNBSim = q39_mk.call(1, true)
	q40_b.assign_role("YURI", "TRAINING"); q40_b.rewards["kizuna"][TNBSim.pair_key("RORY", "YURI")] = 12
	var q40_bw: Array = ["house", "style", "element", "bond", "role"].map(func(q40_by): return q40_b.locker_browse(str(q40_by)))
	var q40_cv: String = q40_b.card_view("YURI")
	_sr("the browse and the comparison card: %s; \"%s\"" % [JSON.stringify(q40_bw), q40_cv],
		q40_bw[0] == ["houseless: RORY, PRIYA, MARCUS, JUNE, HILL 1, RINK 2, HILL 3", "House Kowalchuk: YURI"] and q40_bw[4] == ["dressed: RORY, PRIYA, MARCUS, JUNE", "training partner: YURI", "on the bench: HILL 1, RINK 2, HILL 3"] and q40_bw[3].has("1 bond: RORY, YURI") and q40_bw[1].size() >= 2 and q40_bw[2].size() >= 2 \
		and q40_cv.begins_with("YURI - House Kowalchuk, SLUGGER, GRANITE, PRAIRIES; training partner") and q40_cv.contains("PWR 80") and q40_cv.contains("trait Load-Bearing") and q40_cv.contains("dialect kowalchuk") and q40_cv.contains("bonds RORY Lv1") and q40_cv.contains("| kit "))
	# the locker in the save: a release waiting (HILL 1) and a memory (YURI, released with a grudge and back) ride the reward ledger; the Fighter
	# record carries the memory; a load takes HILL 1 back and writes back byte-equal
	var q40_v: TNBSim = q40_g
	q40_v.release("HILL 1")
	var q40_tx: String = TNBSave.write_text(q40_v, false)
	var q40_yr: Dictionary = {}
	for q40_fr in TNBSave.to_save(q40_v)["stable"]:
		if str(q40_fr["name"]) == "YURI": q40_yr = q40_fr.get("memory", {})
	var q40_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q40_tx), 7)["sim"]
	var q40_back: Array = [TNBSave.write_text(q40_bl, false) == q40_tx, q40_bl.rewards["locker"]["pending"].keys(), bool(q40_bl.take_back("HILL 1")["ok"]), q40_bl._stable_card("HILL 1").size() > 0, str(q40_bl.memory_of("YURI").get("flag", ""))]
	_sr("the locker in the save: YURI's record remembers %s; loaded %s" % [JSON.stringify(q40_yr), JSON.stringify(q40_back)],
		str(q40_yr.get("flag", "")) == "grudge" and int(q40_yr.get("times", 0)) == 1 and q40_back == [true, ["HILL 1"], true, true, "grudge"])

	# ---- PAC-101: DISTRICT REP (NP_02 s2.1 / s4; NP_08 s2.2 / s2.4) ----
	var q41_R: Dictionary = content["economy"]["rep"]
	var q41_won := func(q41_s: TNBSim, q41_obj: String, q41_boss: int, q41_d: String) -> void:
		q41_s.start_scrap(q41_obj, q41_boss, "", {}, "", q41_d); q41_s.obj["met"] = true; q41_s._end_bout()
	# the rep as data: a scrap won +1, a flee -1, the milestones 3 / 10 / 25 paying 1 / 1 / 2 Prestige, the docs' district names by alias,
	# REP() the sim's (the recruit grammar). A scrap won in the Rink District raises its rep; the third pays the milestone once - 3 scraps
	# of tier 1 pay 6 Prestige and the milestone 1; placed nowhere, 6 and no rep; a scrap lost moves nothing; a flee back to 2 and a win to 3
	# again pays no second milestone
	var q41_a := make_sim(7, 7)
	for q41_i in 3: q41_won.call(q41_a, "SCR-01", 7, "rink")
	var q41_n := make_sim(7, 7)
	for q41_i2 in 3: q41_won.call(q41_n, "SCR-01", 7, "")
	var q41_l := make_sim(7, 7); q41_l.start_scrap("SCR-01", 7, "", {}, "", "rink"); q41_l.obj["failed"] = true; q41_l._end_bout()
	var q41_ra: Array = [q41_a.rep_of("rink"), q41_a.rep_of("rink_district"), int(q41_a.rewards["prestige"]), int(q41_a.rewards["rep"]["paid"]), count_events(q41_a.events, "rep", {"milestones": [3]}), q41_n.rewards.has("rep"), int(q41_n.rewards["prestige"]), q41_l.rep_of("rink")]
	q41_a.start_scrap("SCR-01", 7, "", {}, "", "rink"); for q41_t in 3: q41_a.step({})
	q41_a.flee(); q41_won.call(q41_a, "SCR-01", 7, "rink")
	q41_ra.append_array([q41_a.rep_of("rink"), int(q41_a.rewards["rep"]["paid"]), int(q41_a.rewards["rep"]["best"]["rink"])])
	_sr("district rep: the table %s; three scrap wins in the Rink District [rep, by alias, Prestige, milestones paid, the milestone's event, placed nowhere a ledger, its Prestige, a scrap lost] %s; fled to 2 and won again [rep, paid, best] %s" % [JSON.stringify([int(q41_R["scrap_won"]), int(q41_R["flee"]), q41_R["milestones"], q41_a.rep_key("the_hill"), str(content["recruits"]["grammar"]["REP"]["owner"])]), JSON.stringify(q41_ra.slice(0, 8)), JSON.stringify(q41_ra.slice(8))],
		int(q41_R["scrap_won"]) == 1 and int(q41_R["flee"]) == 1 and q41_R["milestones"].map(func(q41_m): return [int(q41_m[0]), int(q41_m[1])]) == [[3, 1], [10, 1], [25, 2]] and q41_a.rep_key("the_hill") == "hill" and str(content["recruits"]["grammar"]["REP"]["owner"]) == "sim" \
		and q41_ra.slice(0, 8) == [3, 3, 7, 1, 1, false, 6, 0] and q41_ra.slice(8) == [3, 1, 3])
	# the flee (NP_02 s2.1: "allowed pre-engagement freely; mid-scrap flee costs small district rep (-1)"): before the first exchange free -
	# the scrap over, nothing paid, no PI; after it, on the step's input, the rink -1 (4 of 5 seeded); at 0 it stays 0; a spar and a dual are
	# fought out
	var q41_seed := {"rep": {"of": {"rink": 5}, "best": {"rink": 5}, "paid": 0}}
	var q41_f0 := make_sim(7, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q41_seed.duplicate(true)); q41_f0.start_scrap("SCR-01", 7, "", {}, "", "rink")
	var q41_x0: int = q41_f0.xp_of("RORY")
	var q41_fr0: Dictionary = q41_f0.flee()
	var q41_fa: Array = [bool(q41_fr0["ok"]), bool(q41_fr0["engaged"]), q41_f0.rep_of("rink"), q41_f0.mode, q41_f0.xp_of("RORY") - q41_x0, int(q41_f0.rewards["prestige"]), count_events(q41_f0.events, "bout_end", {"rung": "fled"}), count_events(q41_f0.events, "pi_count")]
	var q41_f1 := make_sim(7, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q41_seed.duplicate(true)); q41_f1.start_scrap("SCR-01", 7, "", {}, "", "rink")
	for q41_t2 in 30: q41_f1.step({})
	q41_f1.step({"flee": true})
	q41_fa.append_array([q41_f1.mode, q41_f1.rep_of("rink"), count_events(q41_f1.events, "fled", {"engaged": true, "rep": -1})])
	var q41_f2 := make_sim(7, 7); q41_f2.start_scrap("SCR-01", 7, "", {}, "", "rink")
	for q41_t3 in 30: q41_f2.step({})
	q41_f2.flee()
	var q41_sp := make_sim(1, 7); q41_sp.start_spar(1)
	var q41_du := make_sim(1, 7)
	q41_fa.append_array([q41_f2.rep_of("rink"), q41_f2.rewards.get("rep", {}).get("of", {}).get("rink", -1), str(q41_sp.flee()["why"]), str(q41_du.flee()["why"]), str(q41_f2.flee()["why"])])
	_sr("the flee: before the first exchange %s; after it %s; at 0 %s; refused %s" % [JSON.stringify(q41_fa.slice(0, 8)), JSON.stringify(q41_fa.slice(8, 11)), JSON.stringify(q41_fa.slice(11, 13)), JSON.stringify(q41_fa.slice(13))],
		q41_fa.slice(0, 8) == [true, false, 5, "OVER", 0, 0, 1, 0] and q41_fa.slice(8, 11) == ["OVER", 4, 1] and q41_fa.slice(11, 13) == [0, 0] \
		and q41_fa.slice(13) == ["only a scrap is fled (NP_02 s2.1) - a spar or a dual is fought out", "only a scrap is fled (NP_02 s2.1) - a spar or a dual is fought out", "the scrap is over"])
	# REP() read off the ledger (NP_08 s2.2): Carter Okafor (BEAT_IN(scrap)x3 AND REP(rink_district, 3)) approached - three scraps won
	# against him placed nowhere meet the first clause and not the second; three in the Rink District meet both and he would join; a seeded
	# rep flag still counts; the Whitecloud blessing's REP(the_hill, 3) reads the Hill's rep
	var q41_c := make_sim(7, 7); q41_c.mode = "OVER"
	q41_c.rewards["recruit"]["carter_okafor"] = {"state": "approachable", "witnessed": 0, "day": 1}; q41_c.approach("carter_okafor")
	for q41_i3 in 3: q41_won.call(q41_c, "SCR-01", 7, "")
	var q41_cv0: Array = q41_c.recruit_view("carter_okafor")["clauses"].map(func(q41_cl): return "%s %d/%d" % [str(q41_cl["form"]), int(q41_cl["have"]), int(q41_cl["need"])])
	for q41_i4 in 3: q41_won.call(q41_c, "SCR-01", 7, "rink")
	var q41_cv1: Dictionary = q41_c.recruit_view("carter_okafor")
	var q41_cs := make_sim(7, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story({}, "rep:rink_district:3"))
	var q41_hill := make_sim(7, 7)
	var q41_h0: bool = bool(q41_hill.condition_state("REP(the_hill, 3)", "house:whitecloud")[0]["met"])
	for q41_i5 in 3: q41_won.call(q41_hill, "SCR-01", 7, "hill")
	_sr("REP() on the ledger: Carter placed nowhere %s; in the Rink District %s (ready %s); a seeded flag %s; the Hill for the Whitecloud blessing %s -> %s" % [JSON.stringify(q41_cv0), JSON.stringify(q41_cv1["clauses"].map(func(q41_cl2): return "%s %d/%d" % [str(q41_cl2["form"]), int(q41_cl2["have"]), int(q41_cl2["need"])])), str(bool(q41_cv1["met"])), str(bool(q41_cs.condition_state("REP(rink_district, 3)", "carter_okafor")[0]["met"])), str(q41_h0), str(bool(q41_hill.condition_state("REP(the_hill, 3)", "house:whitecloud")[0]["met"]))],
		q41_cv0 == ["BEAT_IN 3/3", "REP 0/3"] and bool(q41_cv1["met"]) and count_events(q41_c.events, "recruit_ready", {"name": "carter_okafor"}) == 1 and bool(q41_cs.condition_state("REP(rink_district, 3)", "carter_okafor")[0]["met"]) \
		and not q41_h0 and bool(q41_hill.condition_state("REP(the_hill, 3)", "house:whitecloud")[0]["met"]))
	# the rep in the save: the ledger rides the SaveGame and writes back byte-equal; a scrap in flight in the Rink District restores to the
	# same hash with its district, and a flee after the load costs the rink its point
	var q41_v := make_sim(7, 7)
	for q41_i6 in 3: q41_won.call(q41_v, "SCR-01", 7, "rink")
	q41_v.start_scrap("SCR-01", 7, "", {}, "", "rink")
	for q41_t4 in 20: q41_v.step({})
	var q41_tx: String = TNBSave.write_text(q41_v, true)
	var q41_bl: Dictionary = TNBSave.build(content, TNBSave.read_text(q41_tx), 99)
	var q41_bs: TNBSim = q41_bl["sim"]
	var q41_sv: Array = [q41_bs.rep_of("rink"), q41_bs.hash_state() == q41_v.hash_state(), str(q41_bs.bout.get("district", "")), TNBSave.write_text(q41_bs, true) == q41_tx]
	q41_bs.flee()
	q41_sv.append(q41_bs.rep_of("rink"))
	_sr("the rep in the save: loaded [rep, the hash, the scrap's district, byte-equal] %s; fled after the load, the rink %d" % [JSON.stringify(q41_sv.slice(0, 4)), int(q41_sv[4])],
		q41_sv == [3, true, "rink", true, 2])
	# the faucet's districts against their absence: each phase's scraps in its districts in turn - the rep by Arc 3, the milestones' Prestige;
	# without the districts no rep and 20 Prestige less; the verdict GREEN both ways, nothing else paid differently
	var q41_F0: Dictionary = q37_F.duplicate(true)
	for q41_ph in q41_F0["phases"]: q41_ph.erase("districts")
	var q41_r1: Dictionary = TNBFaucets.run(content, q37_F, q35_A, {"sample_given": q37_sm})
	var q41_r0: Dictionary = TNBFaucets.run(content, q41_F0, q35_A, {"sample_given": q37_sm})
	var q41_p1: Dictionary = q41_r1["faucet"]["paid"]; var q41_p0: Dictionary = q41_r0["faucet"]["paid"]
	_sr("the faucet's districts against their absence: the rep by Arc 3 %s, the milestones %d Prestige; Prestige %d vs %d without (the share %d%% vs %d%%, a session %.1f vs %.1f), the rest %s; the verdict %s / %s" % [JSON.stringify(q41_r1["faucet"]["rep"]), int(q41_r1["faucet"]["rep_prestige"]), int(q41_p1["prestige"]), int(q41_p0["prestige"]), int(round(100.0 * float(q41_r1["share"]["prestige"]))), int(round(100.0 * float(q41_r0["share"]["prestige"]))), float(q41_r1["per_session"]["prestige"]), float(q41_r0["per_session"]["prestige"]), "the same" if ["xp", "spirits", "hbp", "beans"].all(func(q41_c1): return int(q41_p1[q41_c1]) == int(q41_p0[q41_c1])) else "DIFFERENT", JSON.stringify(q41_r1["fails"].keys()), JSON.stringify(q41_r0["fails"].keys())],
		q41_r1["faucet"]["rep"].size() == 6 and int(q41_r1["faucet"]["rep_prestige"]) > 0 and int(q41_p1["prestige"]) == int(q41_p0["prestige"]) + int(q41_r1["faucet"]["rep_prestige"]) and q41_r0["faucet"]["rep"].is_empty() \
		and ["xp", "spirits", "hbp", "beans"].all(func(q41_c2): return int(q41_p1[q41_c2]) == int(q41_p0[q41_c2])) and q41_r1["fails"].is_empty() and q41_r0["fails"].is_empty())

	# ---- PAC-102: THE ANTI-YOU (NP_12 s2) - the academy signs the club's beaten rivals between arcs ----
	var q42_A: Dictionary = content["academy"]["recruiting"]
	var q42_card := func(q42_s: TNBSim, q42_rn: String) -> String: return str(q42_s._recruit_rec(q42_rn).get("card", q42_rn))
	# the recruiting against its absence: Yuri's squad beaten flags four; one approached. A story beat that turns no arc signs nobody; the
	# Nationals (Arc 1's end) and the academy signs three of the four in the order met - out of the club's reach (the approach refused, no
	# rare lead of the machine's), the fourth left; the turn again is refused, nobody more. A seeded Nationals flag (the ledger as it stood)
	# signs nobody; without the table's recruiting nobody
	var q42_a := make_sim(1, 7); quiet(q42_a); q15_win.call(q42_a)
	var q42_fl: Array = q42_a.academy_left_behind()
	q42_a.approach(str(q42_fl[1]))
	q42_a.story_mark("story:regionals")
	var q42_n0: int = q42_a.academy_taken().size()
	q42_a.story_mark("story:nationals")
	var q42_tk: Array = q42_a.academy_taken()
	var q42_twice: bool = bool(q42_a.story_mark("story:nationals")["ok"])
	var q42_st: Array = q42_fl.map(func(q42_x): return q42_a.recruit_state(str(q42_x)))
	var q42_ref: String = str(q42_a.approach(str(q42_tk[0]))["why"])
	var q42_rares: bool = q42_tk.any(func(q42_x2): return str(q42_x2) in q42_a.scout_rares())
	var q42_sd := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_story({}, "story:nationals")); quiet(q42_sd); q15_win.call(q42_sd)
	var q42_nc: Dictionary = content.duplicate(); q42_nc["academy"] = content["academy"].duplicate(true); q42_nc["academy"].erase("recruiting")
	var q42_na := TNBSim.new()
	q42_na.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, TNBSim.LINEUP_MILLBROOK, 1, 7, content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), "", content.get("bouts", {}), content.get("scraps", {}),
		content.get("pattern_intel", {}), {}, content.get("remixes", {}), content.get("economy", {}), {}, {}, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), {}, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), q42_nc["academy"], content.get("gear", {}))
	quiet(q42_na); q15_win.call(q42_na); q42_na.story_mark("story:nationals")
	_sr("the anti-you against its absence: the turns %s, %d a turn; Yuri's squad beaten flags %s; a beat that turns no arc signs %d; the Nationals signs %s (states %s); again %s; the approach \"%s\"; a rare lead %s; seeded %d; without the table %d" % [JSON.stringify(q42_A["turns"]), int(q42_A["per_turn"]), JSON.stringify(q42_fl), q42_n0, JSON.stringify(q42_tk.map(func(q42_x3): return q42_card.call(q42_a, str(q42_x3)))), JSON.stringify(q42_st), "refused" if not q42_twice else "SIGNED AGAIN", q42_ref, str(q42_rares), q42_sd.academy_taken().size(), q42_na.academy_taken().size()],
		q42_A["turns"] == ["story:nationals", "story:hollow_circuit"] and int(q42_A["per_turn"]) == 3 and q42_fl.size() == 4 and q42_n0 == 0 and q42_tk == q42_fl.slice(0, 3) and q42_st == ["academy", "academy", "academy", "approachable"] and not q42_twice \
		and q42_ref == "%s signed with Toronto Ascendant Academy at story:nationals - beat the academy first" % str(q42_tk[0]) and not q42_rares and q42_sd.academy_taken().is_empty() and q42_na.academy_taken().is_empty() and count_events(q42_a.events, "academy_signs") == 1)
	# a released rival (PAC-100) is the academy's too: YURI let go from the bench with a grudge, back in the prairies, signed at the turn - the
	# RECRUITS and String Wall lines name the academy and the release
	var q42_r: TNBSim = q39_mk.call(1, true)
	q42_r.release("YURI")
	for q42_d in 3: q42_r.new_day()
	q42_r.story_mark("story:nationals")
	var q42_rl: Array = q42_r.recruit_lines()
	_sr("a released rival at the academy: taken %s; the RECRUITS line \"%s\"; the String Wall %s" % [JSON.stringify(q42_r.academy_taken()), str(q42_rl[0]) if q42_rl.size() > 0 else "-", q42_r.sw_state("yuri_kowalchuk")],
		q42_r.academy_taken() == ["yuri_kowalchuk"] and q42_rl.size() >= 1 and str(q42_rl[0]) == "YURI (yuri_kowalchuk): signed by Toronto Ascendant Academy at story:nationals (day 4) - released by the club with a grudge - beat the academy and the rival comes over" \
		and q42_r.sw_state("yuri_kowalchuk") in ["academy", ""])
	# the academy's squad with the rivals it signed: fielded, the three fight R1-R3 on their own patterns ahead of the prodigies (the mini's
	# three slots all theirs; a sanctioned dual's R4 and R5 the prodigies), Vey in the corner, each with the syntheses of the prodigy it
	# displaces (C46)
	var q42_s5 := make_sim(1, 7, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); quiet(q42_s5); q15_win.call(q42_s5); q42_s5.story_mark("story:nationals"); q42_s5.field_academy(true); q42_s5.new_dual()
	q42_a.field_academy(true); q42_a.new_dual()
	var q42_sq: Array = q42_a.blineup.duplicate()
	var q42_k0: Array = q42_a.B.get("synth", []).map(func(q42_m): return str(q42_m["name"]))
	var q42_p0: Array = q42_a.prodigy_spec(0)["synth"].map(func(q42_pr): return str(q42_a.synthesize(str(q42_pr[0]), str(q42_pr[1]))["name"]))
	_sr("the academy's squad with the rivals it signed: %s (a sanctioned dual %s), Vey's corner %s; R1 %s carries %s (ASCENDANT 1's %s); R2's kit is ASCENDANT 2's %s" % [JSON.stringify(q42_sq), JSON.stringify(q42_s5.blineup), str(q42_a.coach.get("id", "")), q42_a.boss_name, JSON.stringify(q42_k0), JSON.stringify(q42_p0), str(q42_a.academy_kit(str(q42_tk[1])) == q42_a.prodigy_spec(1)["synth"])],
		q42_sq.slice(0, 3) == q42_tk and q42_sq.size() == 3 and q42_s5.blineup.size() == 5 and q42_s5.blineup.slice(0, 3) == q42_s5.academy_taken() and q42_s5.blineup.slice(3) == ["ASCENDANT 4", "ASCENDANT 5"] and str(q42_a.coach.get("id", "")) == "ascendant_a" and q42_a.boss_name == str(q42_tk[0]) and q42_k0 == q42_p0 and q42_k0.size() == 3 and q42_a.academy_kit(str(q42_tk[1])) == q42_a.prodigy_spec(1)["synth"] and q42_a.bdressed.size() >= 3)
	# the academy beaten: lost, it keeps them; won, every rival it holds comes over - approachable, the turn remembered; YURI's grudge still
	# asks its spar on the approach
	var q42_l := make_sim(1, 7); quiet(q42_l); q15_win.call(q42_l); q42_l.story_mark("story:nationals"); q42_l.field_academy(true); q42_l.new_dual(); quiet(q42_l); q15_lose.call(q42_l)
	quiet(q42_a); q15_win.call(q42_a)
	var q42_came: Array = q42_tk.map(func(q42_x4): return q42_a.recruit_state(str(q42_x4)))
	q42_r.field_academy(true); q42_r.new_dual(); quiet(q42_r); q15_win.call(q42_r)
	q42_r.approach("yuri_kowalchuk")
	var q42_yv: Array = q42_r.recruit_view("yuri_kowalchuk")["clauses"].map(func(q42_cl): return str(q42_cl["form"]))
	_sr("the academy beaten: lost, it holds %s; won, %s come over %s (the turn remembered %s); YURI's approach %s" % [JSON.stringify(q42_l.academy_taken().map(func(q42_x5): return q42_card.call(q42_l, str(q42_x5)))), JSON.stringify(q42_tk.map(func(q42_x6): return q42_card.call(q42_a, str(q42_x6)))), JSON.stringify(q42_came), str(q42_a.rewards["recruit"][str(q42_tk[0])].get("academy", {}).get("turn", "")), JSON.stringify(q42_yv)],
		q42_l.academy_taken().size() == 3 and q42_a.academy_taken().is_empty() and q42_came == ["approachable", "approachable", "approachable"] and str(q42_a.rewards["recruit"][str(q42_tk[0])].get("academy", {}).get("turn", "")) == "story:nationals" \
		and count_events(q42_a.events, "academy_beaten") == 1 and "GRUDGE" in q42_yv)
	# the academy in the save: its signings ride the reward ledger; a load holds them, refuses their approach and writes back byte-equal
	var q42_v := make_sim(1, 7); quiet(q42_v); q15_win.call(q42_v); q42_v.story_mark("story:nationals")
	var q42_tx: String = TNBSave.write_text(q42_v, false)
	var q42_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q42_tx), 7)["sim"]
	var q42_bk: Array = [q42_bl.academy_taken() == q42_v.academy_taken(), q42_bl.recruit_state(str(q42_v.academy_taken()[0])), TNBSave.write_text(q42_bl, false) == q42_tx, bool(q42_bl.approach(str(q42_v.academy_taken()[0]))["ok"])]
	_sr("the academy in the save: loaded %s" % JSON.stringify(q42_bk), q42_bk == [true, "academy", true, false])

	# ---- PAC-103: VENDOR TIERS (NP_02 s4) - the shops' shelves by the Downtown Strip's rep ----
	var q43_T: Dictionary = content["techniques"]["shop"]; var q43_G: Dictionary = content["gear"]["shop"]
	var q43_mk := func(q43_rp: String, q43_fl: String = "", q43_hb: int = 1500) -> TNBSim:
		var q43_l: Dictionary = TNBSim.seed_rep(TNBSim.seed_story(TNBSim.seed_levels({"hbp": q43_hb}, "RORY:15", content["economy"]), q43_fl), q43_rp, content["economy"])
		var q43_s := make_sim(7, 7, TNBSim.LINEUP_MILLBROOK, "", {}, q43_l); q43_s.mode = "OVER"
		return q43_s
	var q43_lastrep := func(q43_s: TNBSim) -> Dictionary:
		var q43_e: Array = q43_s.events.filter(func(q43_x): return str(q43_x["kind"]) == "rep")
		return q43_e[q43_e.size() - 1] if q43_e.size() > 0 else {}
	# the tiers against their absence: both shops on the Downtown Strip, t2 at rep 10 and t3 at 25. At DOWNTOWN 9 with no story flag only
	# the t1 shelves stand open and a t2 refusal names the rep; a scrap won downtown makes 10 - both t2 shelves open by the rep, named on the
	# rep's event, t3 still shut. The Rink District's 30 opens nothing; with the tables' rep gone DOWNTOWN's 30 opens nothing; a seeded rep
	# flag counts as REP() counts it; the Regionals open t2 by the flag at DOWNTOWN 0; -- rep= reads the docs' district names by alias
	var q43_a: TNBSim = q43_mk.call("downtown:9")
	var q43_ab: Array = [q43_a.shelves_open(), q43_a.gear_buy_why("leather_gloves")]
	q41_won.call(q43_a, "SCR-01", 7, "downtown")
	var q43_ae: Dictionary = q43_lastrep.call(q43_a)
	q43_ab.append_array([q43_a.rep_of("downtown"), q43_a.shelf_open_by("techniques", "t2"), q43_a.shelf_open_by("gear", "t2"), q43_a.shelf_open_by("techniques", "t3"), q43_ae.get("shelves", [])])
	var q43_r: TNBSim = q43_mk.call("rink:30")
	var q43_n: TNBSim = q43_mk.call("downtown:30")
	q43_n.TECH = q43_n.TECH.duplicate(true); q43_n.GEAR = q43_n.GEAR.duplicate(true)
	for q43_t in ["t2", "t3"]: q43_n.TECH["shop"]["tiers"][q43_t].erase("rep"); q43_n.GEAR["shop"]["tiers"][q43_t].erase("rep")
	var q43_f: TNBSim = q43_mk.call("", "rep:downtown:10")
	var q43_g: TNBSim = q43_mk.call("", "story:regionals")
	q43_ab.append_array([q43_r.shelves_open(), q43_n.shelves_open(), q43_f.shelf_open_by("gear", "t2"), q43_g.shelf_open_by("techniques", "t2"), q43_g.shelf_open_by("techniques", "t3"), TNBSim.seed_rep({}, "downtown_strip:9,rink_district:3", content["economy"])["rep"]["of"]])
	_sr("the vendor tiers against their absence: the tables %s; at DOWNTOWN 9 %s; a scrap won downtown [rep, t2, gear t2, t3, the rep's shelves] %s; the rink's 30 %s; without the rep %s; a seeded flag %s; the Regionals [t2, t3] %s; -- rep= by alias %s" % [JSON.stringify([str(q43_T["district"]), int(q43_T["tiers"]["t2"]["rep"]), int(q43_T["tiers"]["t3"]["rep"]), str(q43_G["district"]), int(q43_G["tiers"]["t2"]["rep"]), int(q43_G["tiers"]["t3"]["rep"])]), JSON.stringify(q43_ab.slice(0, 2)), JSON.stringify(q43_ab.slice(2, 7)), JSON.stringify(q43_ab[7]), JSON.stringify(q43_ab[8]), str(q43_ab[9]), JSON.stringify(q43_ab.slice(10, 12)), JSON.stringify(q43_ab[12])],
		[str(q43_T["district"]), int(q43_T["tiers"]["t2"]["rep"]), int(q43_T["tiers"]["t3"]["rep"]), str(q43_G["district"]), int(q43_G["tiers"]["t2"]["rep"]), int(q43_G["tiers"]["t3"]["rep"])] == ["downtown", 10, 25, "downtown", 10, 25] \
		and q43_ab[0] == ["techniques:t1", "gear:t1"] and str(q43_ab[1]) == "the gear shop's t2 shelf opens with the Regionals (story:regionals) or DOWNTOWN rep 10 (9 now)" \
		and q43_ab.slice(2, 7) == [10, "rep", "rep", "closed", ["the technique shop's t2 shelf", "the gear shop's t2 shelf"]] and q43_ab[7] == ["techniques:t1", "gear:t1"] and q43_ab[8] == ["techniques:t1", "gear:t1"] \
		and str(q43_ab[9]) == "rep" and q43_ab.slice(10, 12) == ["flag", "closed"] and q43_ab[12] == {"downtown": 9, "rink": 3})
	# a shelf opened on the ledger's rep and closed below it: at DOWNTOWN 10 RORY buys Snowblind off the t2 shelf and the club Leather Gloves;
	# a downtown scrap fled after the first exchange drops the rep to 9 - both t2 shelves close, named on the flee's event; Gel Wraps refused
	# naming the rep; what was bought stays bought; a scrap won brings 10 back and the shelves open again
	var q43_b: TNBSim = q43_mk.call("downtown:10")
	var q43_bb: Array = [bool(q43_b.buy("RORY", "Snowblind")["ok"]), bool(q43_b.buy_gear("leather_gloves")["ok"]), int(q43_b.rewards["hbp"])]
	q43_b.start_scrap("SCR-01", 7, "", {}, "", "downtown")
	for q43_t2 in 30: q43_b.step({})
	q43_b.flee()
	var q43_fe: Array = q43_b.events.filter(func(q43_x): return str(q43_x["kind"]) == "fled")
	q43_bb.append_array([q43_b.rep_of("downtown"), q43_fe[q43_fe.size() - 1].get("closed", []) if q43_fe.size() > 0 else [], q43_b.shelves_open(), q43_b.gear_buy_why("gel_wraps"), "Snowblind" in q43_b.learned("RORY"), int(q43_b.gear_owned().get("leather_gloves", 0))])
	q41_won.call(q43_b, "SCR-01", 7, "downtown")
	q43_bb.append_array([q43_b.rep_of("downtown"), q43_lastrep.call(q43_b).get("shelves", []).size(), q43_b.gear_buy_why("gel_wraps")])
	_sr("a shelf opened on the rep and closed below it: at DOWNTOWN 10 [Snowblind, Leather Gloves, HBP] %s; fled [rep, closed, open, Gel Wraps, kept, kept] %s; won again %s" % [JSON.stringify(q43_bb.slice(0, 3)), JSON.stringify(q43_bb.slice(3, 9)), JSON.stringify(q43_bb.slice(9))],
		q43_bb.slice(0, 3) == [true, true, 850] and q43_bb.slice(3, 9) == [9, ["the technique shop's t2 shelf", "the gear shop's t2 shelf"], ["techniques:t1", "gear:t1"], "the gear shop's t2 shelf opens with the Regionals (story:regionals) or DOWNTOWN rep 10 (9 now)", true, 1] \
		and q43_bb.slice(9) == [10, 2, ""])
	# the shops' lines and the aid: DUAL OVER's lines name how each shelf stands and what a closed one wants - at DOWNTOWN 9 after the
	# Regionals, and at 25 with no story; the aid's gear off a shelf the rep opened (t3 at 25) and, without the rep, off t1
	var q43_l9: TNBSim = q43_mk.call("downtown:9", "story:regionals"); var q43_l25: TNBSim = q43_mk.call("downtown:25")
	var q43_c: TNBSim = q43_mk.call("downtown:25", "", 3000); var q43_c0: TNBSim = q43_mk.call("", "", 3000)
	q43_c.gear_aid("RORY"); q43_c0.gear_aid("RORY")
	var q43_sh := func(q43_s: TNBSim) -> Array: return q43_s.gear_owned().keys().filter(func(q43_id): return str(q43_s.gear_item(str(q43_id)).get("source", "")) == "shop").map(func(q43_id2): return str(q43_s.gear_item(str(q43_id2))["shelf"]))
	var q43_cl: Array = [q43_sh.call(q43_c), q43_sh.call(q43_c0), q43_c.buy_best("RORY"), q43_c.shop_tier_of(q43_c.buy_best("RORY"))]
	_sr("the shops' lines: at DOWNTOWN 9 after the Regionals %s; at 25 %s; the aid's gear off the rep's shelves %s, without %s; the technique shop's pick %s" % [JSON.stringify(q43_l9.vendor_lines()), JSON.stringify(q43_l25.vendor_lines()), JSON.stringify(q43_cl[0]), JSON.stringify(q43_cl[1]), JSON.stringify(q43_cl.slice(2))],
		q43_l9.vendor_lines() == ["THE TECHNIQUE SHOP (DOWNTOWN, rep 9): t1 open, t2 open (the Regionals), t3 at the Provincials or rep 25 (9/25)", "THE GEAR SHOP (DOWNTOWN, rep 9): t1 open, t2 open (the Regionals), t3 at the Provincials or rep 25 (9/25)"] \
		and q43_l25.vendor_lines() == ["THE TECHNIQUE SHOP (DOWNTOWN, rep 25): t1 open, t2 open (DOWNTOWN rep 10), t3 open (DOWNTOWN rep 25)", "THE GEAR SHOP (DOWNTOWN, rep 25): t1 open, t2 open (DOWNTOWN rep 10), t3 open (DOWNTOWN rep 25)"] \
		and q43_cl[0].size() > 0 and q43_cl[0].has("t3") and q43_cl[1].size() > 0 and q43_cl[1].all(func(q43_x): return str(q43_x) == "t1") and str(q43_cl[3]) == "t3")
	# the tiers in the save: DOWNTOWN 10 rides the ledger; the load reads both t2 shelves open by the rep and writes back byte-equal
	var q43_v: TNBSim = q43_mk.call("downtown:10")
	var q43_tx: String = TNBSave.write_text(q43_v, false)
	var q43_bl: TNBSim = TNBSave.build(content, TNBSave.read_text(q43_tx), 7)["sim"]; q43_bl.mode = "OVER"
	var q43_sv: Array = [q43_bl.shelves_open() == q43_v.shelves_open(), q43_bl.shelf_open_by("gear", "t2"), q43_bl.gear_buy_why("leather_gloves"), TNBSave.write_text(q43_bl, false) == q43_tx]
	_sr("the tiers in the save: loaded %s" % JSON.stringify(q43_sv), q43_sv == [true, "rep", "", true])
	# the faucet's vendor tiers: at story pace each shelf opens by its flag in the circuit (DOWNTOWN scrapped only in Arc 2) - none ahead
	# by the rep; a player who scraps the Strip through the club phase opens both t2 shelves there by the rep, and nothing is paid differently
	var q43_F1: Dictionary = q37_F.duplicate(true); q43_F1["phases"][0]["districts"] = ["downtown"]
	var q43_r1: Dictionary = TNBFaucets.run(content, q43_F1, q35_A, {"sample_given": q37_sm})
	var q43_v0: Dictionary = q41_r1["faucet"]["vendors"]; var q43_v1: Dictionary = q43_r1["faucet"]["vendors"]
	var q43_ln: Array = TNBFaucets.lines(q41_r1, q37_F).filter(func(q43_x): return str(q43_x).contains("the vendor tiers"))
	_sr("the faucet's vendor tiers: at story pace %s (DOWNTOWN %s by phase); the Strip scrapped in the club phase %s (DOWNTOWN %s); the paid alike %s" % [JSON.stringify(q43_v0), JSON.stringify(q41_r1["faucet"]["vendor_rep"]), JSON.stringify(q43_v1), JSON.stringify(q43_r1["faucet"]["vendor_rep"]), str(["xp", "spirits", "hbp", "beans"].all(func(q43_c2): return int(q43_r1["faucet"]["paid"][q43_c2]) == int(q41_r1["faucet"]["paid"][q43_c2])))],
		q43_v0.keys() == ["techniques:t2", "techniques:t3", "gear:t2", "gear:t3"] and q43_v0.values().all(func(q43_x): return str(q43_x["by"]) == "flag" and str(q43_x["phase"]) == "arc1_circuit") \
		and str(q43_v1["techniques:t2"]["by"]) == "rep" and str(q43_v1["techniques:t2"]["phase"]) == "arc1_club" and str(q43_v1["gear:t2"]["by"]) == "rep" \
		and ["xp", "spirits", "hbp", "beans"].all(func(q43_c3): return int(q43_r1["faucet"]["paid"][q43_c3]) == int(q41_r1["faucet"]["paid"][q43_c3])) and q43_ln.size() == 1 and str(q43_ln[0]).contains("by rep ahead of the story: none"))

	# ---- PUNISH / BAIT from pattern data ----
	var rc := s.response_coverage(s.patterns)
	_sr("punish-response grammar resolves for every hook (24 patterns)", rc["unknown"].is_empty(),
		"%d responses%s" % [rc["known"], "" if rc["unknown"].is_empty() else "  UNKNOWN: " + JSON.stringify(rc["unknown"])])
	freeze_boss(s); thaw(s); s.punish_cd = {}; s.mode = "FIGHT"
	var pu: Dictionary = s.pattern["punish"][0]
	var plan := s._parse_response(str(pu["response"]))
	var w_pre := JSON.stringify(s.pattern["select"]["weights"])
	s._fire_event(str(pu["trigger"]))
	var answered := false; var detail := ""
	match plan["kind"]:
		"force":
			var full_t := TNBSim.ms(float(s.pattern["strings"][plan["string"]]["tell"]["ms"]))
			answered = s.bstate == "TELL" and s.bstring == plan["string"] and s.btimer < int(full_t * s._tell_mult()) \
				and s.btimer == maxi(1, int(full_t * float(plan["scale"]) * s._tell_mult()))          # PI 2 vs his dialect (earned in the flow above) widens the tell x1.1
			detail = "%s -> %s tell %d/%d ticks (x%.2f, PI %d tell x%.2f)" % [pu["trigger"], s.bstring, s.btimer, full_t, float(plan["scale"]), s.pi_vs(), s._tell_mult()]
		"actions":
			answered = s.bstate == "ACTING" and s.bqueue.size() >= 1
			detail = "%s -> %d immediate actions" % [pu["trigger"], s.bqueue.size()]
		"swap":
			answered = s.swap_restore.size() > 0 and JSON.stringify(s.pattern["select"]["weights"]) != w_pre
			detail = "%s -> weights swapped for %.0fs" % [pu["trigger"], float(plan["swap"][2])]
		"reweight":
			answered = JSON.stringify(s.pattern["select"]["weights"]) != w_pre
			detail = "%s -> reweighted" % pu["trigger"]
		"locked":
			answered = s.bstate == "IDLE"
			detail = "%s -> %s is phase-locked; nothing fires in phase %d" % [pu["trigger"], plan["locked"], s.bphase]
	_sr("punish hook executes its response (%s)" % plan["kind"], answered, detail)
	_sr("a punished string never comes slower than its full tell", plan["kind"] != "force" or float(plan["scale"]) <= 1.0)
	freeze_boss(s); s.punish_cd = {}
	var baited := false; var bait_full := false
	for b in s.pattern.get("bait", []):
		if b.has("trigger") and b.has("force"):
			s._fire_event(str(b["trigger"]))
			baited = s.bstate == "TELL" and s.bstring == b["force"]
			bait_full = baited and s.btimer == maxi(1, int(TNBSim.ms(float(s.pattern["strings"][s.bstring]["tell"]["ms"])) * 1.0 * s._tell_mult()))
			break
		elif b.has("authored_absent"):
			baited = true; bait_full = true
			break
	_sr("bait hook answers (or authored-absent)", baited)
	_sr("baited string comes at full tell", bait_full)
	return _verdict("SMOKE")

# ------------------------------------------------------------ DETERMINISM ----
func audit() -> int:
	# NP_11 s10's obsolescence audit, the milestone's gate (PAC-095): the three earliest-recruitable fighters built for the current endgame
	# with live systems only and fought against its bosses; exit 0 when all three are viable, else 1 naming the failing systems
	if content.is_empty(): content = TNBSim.load_content()
	var A: Dictionary = content["audit"]
	print("AUDIT :: NP_11 s10 - the earliest three built for the arc-%s endgame (level %d, %d Spirits / %d Beans / %d HBP), fought against %s" % [str(A["endgame"]["arc"]), int(A["endgame"]["level"]), int(A["budget"]["spirits"]), int(A["budget"]["beans"]), int(A["budget"]["hbp"]), JSON.stringify(TNBAudit.endgame_bosses(content, str(A["endgame"]["arc"])))])
	var rep: Dictionary = TNBAudit.run(content, A)
	for ln in TNBAudit.lines(rep): print(ln)
	var sys := {}
	for b in rep["early"]:
		for sn in b["systems"]: sys[str(sn)] = true
	print("AUDIT VERDICT :: %s (%d of %d viable)%s" % ["GREEN" if int(rep["viable"]) == int(rep["of"]) else "RED", int(rep["viable"]), int(rep["of"]), (" - the failing systems: " + ", ".join(PackedStringArray(sys.keys()))) if sys.size() > 0 else ""])
	return 0 if int(rep["viable"]) == int(rep["of"]) else 1

func faucets() -> int:
	# NP_11 s6's faucet/sink audit (PAC-097): a story-pace playthrough to Arc 3's start paid by the sim's own reward paths, the sinks a
	# story-pace player wants priced from the live tables; exit 0 when every currency meets its target, else 1 naming the ones that miss
	if content.is_empty(): content = TNBSim.load_content()
	var F: Dictionary = content["faucets"]
	var rep: Dictionary = TNBFaucets.run(content, F, content["audit"])
	for ln in TNBFaucets.lines(rep, F): print(ln)
	print("FAUCETS VERDICT :: %s%s" % ["GREEN" if bool(rep["green"]) else "RED", (" - the failing currencies: " + "; ".join(PackedStringArray(rep["systems"]))) if rep["systems"].size() > 0 else ""])
	return 0 if bool(rep["green"]) else 1

func build_log(n: int, seed_v: int) -> Array:
	# a scripted input log: state-free, so three runs see identical intent
	var r := RandomNumberGenerator.new(); r.seed = seed_v
	var out: Array = []
	var mv := Vector2.ZERO; var block := false; var lb := false
	const ROWS := ["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_HOOK", "R_UPPERCUT", "L_UPPERCUT", "R_HOOKERCUT", "R_FLARED", "L_FLARED", "L_HOOKERCUT"]
	const DODGES := ["SLIP_L", "SLIP_R", "DUCK", "LEAN", "WEAVE_L", "WEAVE_R"]
	for i in n:
		if i % 60 == 0: mv = Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1)).limit_length(1.0) if r.randf() < 0.7 else Vector2.ZERO
		if i % 45 == 0: block = r.randf() < 0.55
		if i % 200 == 0: lb = r.randf() < 0.25
		var inp := {"move": mv, "block": block, "lb": lb, "rise": (i % 20) < 10, "corner": 1 if i % 40 == 0 else 0, "restart": true}
		if r.randf() < 0.025: inp["punch"] = ROWS[r.randi_range(0, ROWS.size() - 1)]
		if r.randf() < 0.03: inp["dodge"] = DODGES[r.randi_range(0, DODGES.size() - 1)]
		if r.randf() < 0.05: inp["power"] = true
		if r.randf() < 0.05: inp["body"] = true
		if r.randf() < 0.002: inp["taunt"] = true
		if r.randf() < 0.003: inp["sprint"] = true
		if r.randf() < 0.02: inp["punch_release"] = true
		if i % 7 == 3:
			const ACTS := [{"kind": "save_bar"}, {"kind": "super"}, {"kind": "tactic", "id": "body_doctrine"}, {"kind": "tactic", "id": "open_season"},
				{"kind": "staff", "id": "raise_the_roof"}, {"kind": "staff", "id": "loosen_up"}, {"kind": "swap", "arg": "JUNE"}]
			inp["corner_action"] = ACTS[r.randi_range(0, ACTS.size() - 1)]
		if r.randf() < 0.0006: inp["clinch"] = true
		out.append(inp)
	return out

func run_log(s: TNBSim, log_: Array, every: int) -> Array:
	var hashes: Array = []
	for i in log_.size():
		s.step(log_[i])
		if i % every == 0: hashes.append(s.hash_state())
	return hashes

func run_log_jittered(s: TNBSim, log_: Array, every: int, seed_v: int) -> Array:
	# the game loop: frames of 7-40ms fed through TNBClock; ticks pulled from the log
	var r := RandomNumberGenerator.new(); r.seed = seed_v
	var clk := TNBClock.new()
	var hashes: Array = []
	var i := 0
	while i < log_.size():
		var n := clk.advance(r.randf_range(0.007, 0.040))
		for k in n:
			if i >= log_.size(): break
			s.step(log_[i])
			if i % every == 0: hashes.append(s.hash_state())
			i += 1
	return hashes

func determinism() -> int:
	print("DETERMINISM :: C1/C5 - three runs of one input log, hashes every 60 ticks")
	const N := 24000
	var log_ := build_log(N, 778)          # 778 since PAC-065: under the interrupt block (only tagged strings break, jab-class only) seed 777 stopped dropping anyone
	var a := make_sim(1, 12345); a.events.clear()
	var ha := run_log(a, log_, 60)
	var cov := {"hit_B": 0, "hit_P": 0, "counter": 0, "flash": 0, "drop": 0, "eight": 0, "seg_end": 0, "tell": 0, "evade": 0, "block": 0, "interrupt": 0, "clinch": 0, "sprint": 0, "sensor": 0, "foul": 0, "pulled": 0, "survival_grab": 0, "cast_P": 0, "cast_B": 0, "cast_hit": 0, "cast_interrupted": 0, "feint": 0, "feint_drawn": 0, "corner_action": 0, "seg_card": 0, "matchup": 0, "matchup_adv": 0, "enemy_corner": 0, "coach_action": 0, "tension_b": 0}
	for e in a.events:
		match e["kind"]:
			"hit":
				if e["on"] == "B": cov["hit_B"] += 1
				else: cov["hit_P"] += 1
				if e.get("counter", false): cov["counter"] += 1
				if e.get("flash", false): cov["flash"] += 1
			"drop": cov["drop"] += 1
			"eight_beat": cov["eight"] += 1
			"seg_end": cov["seg_end"] += 1
			"tell": cov["tell"] += 1
			"evade": cov["evade"] += 1
			"block": cov["block"] += 1
			"interrupt": cov["interrupt"] += 1
			"clinch": cov["clinch"] += 1
			"sprint": cov["sprint"] += 1
			"sensor": cov["sensor"] += 1
			"foul": cov["foul"] += 1
			"pulled": cov["pulled"] += 1
			"survival_grab": cov["survival_grab"] += 1
			"cast":
				if e["who"] == "P": cov["cast_P"] += 1
				else: cov["cast_B"] += 1
			"cast_interrupted": cov["cast_interrupted"] += 1
			"feint":
				cov["feint"] += 1
				if e["drawn"]: cov["feint_drawn"] += 1
			"corner_action": cov["corner_action"] += 1
			"seg_card": cov["seg_card"] += 1
			"matchup":
				cov["matchup"] += 1
				if str(e["style_adv"]) != "" or str(e["element_adv"]) != "": cov["matchup_adv"] += 1
			"enemy_corner": cov["enemy_corner"] += 1
			"coach_action": cov["coach_action"] += 1
	for e in a.events:
		if e["kind"] == "hit" and e.get("hissatsu", false): cov["cast_hit"] += 1
	var duals := 0
	for e in a.events:
		if e["kind"] == "dual_end": duals += 1
	print("  coverage: " + JSON.stringify(cov) + "  duals completed=%d  final mode=%s seg=%d drops %d-%d" % [duals, a.mode, a.seg_idx, a.drops_p, a.drops_b])
	_sr("log exercises both offenses", cov["hit_B"] > 0 and cov["hit_P"] > 0)
	_sr("log exercises hitstop + slow-time (C5 paths)", cov["counter"] > 0 and cov["interrupt"] > 0)
	_sr("log exercises drops / standing-eight / segment end", cov["drop"] > 0 and cov["eight"] > 0 and cov["seg_end"] > 0)
	_sr("log exercises geometric evasion + guard", cov["evade"] > 0 and cov["block"] > 0)
	_sr("log exercises clinch scrambles, sprint-steps and sensors", cov["clinch"] > 0 and cov["sprint"] > 0 and cov["sensor"] > 0)
	_sr("log exercises the referee (fouls or pulled punches) and the survival grab", (cov["foul"] > 0 or cov["pulled"] > 0) and cov["survival_grab"] > 0)
	_sr("log exercises hissatsu casts from the library (player and boss) and their resolve", cov["cast_P"] > 0 and cov["cast_B"] > 0 and cov["cast_hit"] > 0)
	_sr("log exercises feints, some of them drawing his read", cov["feint"] > 0 and cov["feint_drawn"] > 0)
	_sr("log exercises the segment card and corner actions", cov["seg_card"] > 0 and cov["corner_action"] > 0)
	_sr("log passes matchup cards with a ring live (the triangle or the element) and hashes the rings' state", cov["matchup"] >= 2 and cov["matchup_adv"] > 0)
	_sr("log runs the rival corner (it resolves at every corner) and the enemy bar earns; his actions hash with everything else", cov["enemy_corner"] >= 1 and cov["coach_action"] >= 1 and a.btension > 0.0, "rival corners %d, his actions %d, his bar %.1f" % [cov["enemy_corner"], cov["coach_action"], a.btension])
	var b := make_sim(1, 12345)
	var hb := run_log(b, log_, 60)
	var same_ab := ha.size() == hb.size() and ha.size() > 0
	var first_diff := -1
	if same_ab:
		for i in ha.size():
			if ha[i] != hb[i]: same_ab = false; first_diff = i; break
	_sr("C1 replay of the log reproduces every state hash (run B == run A)", same_ab,
		"%d hashes" % ha.size() if same_ab else "diverged at hash %d (tick %d)" % [first_diff, first_diff * 60])
	var c := make_sim(1, 12345)
	var hc := run_log_jittered(c, log_, 60, 4242)
	var same_ac := ha.size() == hc.size()
	first_diff = -1
	if same_ac:
		for i in ha.size():
			if ha[i] != hc[i]: same_ac = false; first_diff = i; break
	_sr("C1 jittered 7-40ms frame loop reproduces every state hash (run C == run A)", same_ac,
		"%d hashes" % hc.size() if same_ac else "diverged at hash %d (tick %d)" % [first_diff, first_diff * 60])
	var d := make_sim(1, 54321)
	var hd := run_log(d, log_, 60)
	var differs := hd.size() != ha.size()
	if not differs:
		for i in ha.size():
			if ha[i] != hd[i]: differs = true; break
	_sr("a different seed produces a different trajectory (hash is not degenerate)", differs)
	# the sanctioned format: five segments (and the ladder's Golden DROP if it comes to that) through one log, twice
	const N5 := 66000
	var log5 := build_log(N5, 4242)
	var f5a := make_sim(0, 999, TNBSim.LINEUP_MILLBROOK_8, "sanctioned"); f5a.events.clear()
	var h5a := run_log(f5a, log5, 600)
	var seg_ends := 0; var verdicts := 0; var r6s := 0
	for e5 in f5a.events:
		match e5["kind"]:
			"seg_end": seg_ends += 1
			"dual_end": verdicts += 1
			"r6": r6s += 1
	var f5b := make_sim(0, 999, TNBSim.LINEUP_MILLBROOK_8, "sanctioned")
	var h5b := run_log(f5b, log5, 600)
	_sr("sanctioned-format log (%d ticks) runs five segments to a verdict (segment ends %d, verdicts %d, Golden DROPs %d) and hashes identically twice" % [N5, seg_ends, verdicts, r6s], seg_ends >= 4 and verdicts >= 1 and h5a == h5b and h5a.size() > 0, "%d hashes" % h5a.size())
	# manager mode: the whole dual delegated, the log stripped of every fight key - the profile fights, the corners are the log's
	var log_auto: Array = []
	for e_in in log_:
		var keep := {}
		for k in ["corner", "corner_action", "restart"]:
			if e_in.has(k): keep[k] = e_in[k]
		log_auto.append(keep)
	var da := make_sim(1, 12345); da.delegate_all = true; da.new_dual(); da.events.clear()
	var hda := run_log(da, log_auto, 60)
	var hits_auto := 0; var segs_auto := 0
	for e_a in da.events:
		if e_a["kind"] == "hit" and e_a["on"] == "B": hits_auto += 1
		if e_a["kind"] == "seg_end": segs_auto += 1
	var db := make_sim(1, 12345); db.delegate_all = true; db.new_dual()
	var hdb := run_log(db, log_auto, 60)
	_sr("a delegated dual on a fight-key-less log: the profile lands %d and the corners still turn (%d segment ends); every hash identical twice" % [hits_auto, segs_auto], hits_auto >= 5 and segs_auto >= 1 and hda == hdb and hda.size() > 0, "%d hashes" % hda.size())
	var xp_paid := 0
	for xk in da.rewards["xp"]: xp_paid += int(da.rewards["xp"][xk])
	_sr("the reward ledger rides the same log: %d XP paid across %d fighters, %d Spirits, %d Kizuna pairs, the toasts %s - identical between the two runs" % [xp_paid, da.rewards["xp"].size(), int(da.rewards["spirits"]), da.rewards["kizuna"].size(), JSON.stringify(da.rewards["log"])],
		xp_paid > 0 and da.rewards["xp"].size() >= 1 and da.rewards == db.rewards)
	# PAC-081: the relay's own T3 on the same delegated log vs Yuri's squad - whoever enters CHARGED has the relay's T3s opened and the profile
	# casts one, the previous fighter's afterimage joining; identical twice (above) and different from the same log with the relay's T3s closed
	# (the tactics table's relay sources emptied: the build before PAC-081, where only a card carrying a T3 could use the unlock)
	var ro_open: Array = []; var ro_cast: Array = []
	for ro_e in da.events:
		if str(ro_e["kind"]) == "relay_open": ro_open.append("R%d %s: %s" % [int(ro_e["seg"]), str(ro_e["who"]), ", ".join(PackedStringArray(ro_e["moves"]))])
		if str(ro_e["kind"]) == "cast" and str(ro_e["who"]) == "P" and str(ro_e["tier"]) == "T3": ro_cast.append("%s (afterimage %s)" % [str(ro_e["move"]), str(ro_e["afterimage"])])
	var ro_keep: Dictionary = content["tactics"]; content["tactics"] = ro_keep.duplicate(true)
	content["tactics"]["corner"]["relay_t3_opens"] = []; content["tactics"]["corner"]["full_relay_t3_opens"] = []
	var roc := make_sim(1, 12345); roc.delegate_all = true; roc.new_dual()
	var hroc := run_log(roc, log_auto, 60)
	content["tactics"] = ro_keep
	_sr("the relay's own T3 on the delegated log vs Yuri's squad: opened %s, cast %s; every hash identical twice and different from the same log with the relay's T3s closed (%d opened there)" % [JSON.stringify(ro_open), JSON.stringify(ro_cast), count_events(roc.events, "relay_open")],
		ro_open.size() >= 1 and ro_cast.size() >= 1 and hda == hdb and hda.size() > 0 and hda != hroc and count_events(roc.events, "relay_open") == 0, "%d hashes" % hda.size())
	# PAC-082: In the Zone on the scripted log vs Yuri's squad - the four at level 20 with the Provincials' flag; at tick 3,000 the bar is topped up
	# and RORY SURGEs: the camera hold, 20 s in the Zone, the Comedown; identical twice and different from the same log with the bar topped up
	# and no SURGE
	var zn_led := TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(""), "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", content["economy"]), "story:provincials_semifinal")
	var zn_run := func(zn_surge: bool) -> Array:
		var zn_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, zn_led)
		var zn_h: Array = []
		for zn_i in log_.size():
			var zn_in: Dictionary = log_[zn_i]
			if zn_i == 3000:
				zn_s.tension = 100.0
				if zn_surge: zn_in = zn_in.duplicate(); zn_in["surge"] = true
			zn_s.step(zn_in)
			if zn_i % 60 == 0: zn_h.append(zn_s.hash_state())
		return [zn_s, zn_h]
	var zna: Array = zn_run.call(true); var znb: Array = zn_run.call(true); var znc: Array = zn_run.call(false)
	var zn_seq: Array = []
	for zn_e in zna[0].events:
		if str(zn_e["kind"]) in ["zone", "zone_end", "comedown_end", "transform_refused"]: zn_seq.append("%s %s @%d" % [str(zn_e["kind"]), str(zn_e.get("who", "")), int(zn_e.get("tick", 0))])
		if str(zn_e["kind"]) == "evade" and str(zn_e.get("why", "")) == "ZONE_SLIP": zn_seq.append("slip @%d" % int(zn_e.get("tick", 0)))
	_sr("In the Zone on the scripted log vs Yuri's squad: %s; every hash identical twice and different from the same log without the SURGE (%d Zones there)" % [JSON.stringify(zn_seq), count_events(znc[0].events, "zone")],
		zn_seq.size() >= 3 and str(zn_seq[0]).begins_with("zone RORY @3001") and zn_seq.filter(func(x): return str(x).begins_with("zone_end")).size() == 1 and zna[1] == znb[1] and zna[1].size() > 0 and zna[1] != znc[1] and count_events(znc[0].events, "zone") == 0, "%d hashes" % zna[1].size())
	# PAC-083: Spirit Manifestation on the same log - RORY with his Arc 2 flag as well: the same SURGE at tick 3,000 casts the Manifest (30 s of
	# x1.4, the echoes, the meter), then the Comedown; identical twice and different from the Zone's run above
	var mf_led := TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(""), "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", content["economy"]), "story:provincials_semifinal,story:manifest:RORY")
	var mf_run := func() -> Array:
		var mf_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, mf_led)
		var mf_h: Array = []
		for mf_i in log_.size():
			var mf_in: Dictionary = log_[mf_i]
			if mf_i == 3000:
				mf_s.tension = 100.0; mf_in = mf_in.duplicate(); mf_in["surge"] = true
			mf_s.step(mf_in)
			if mf_i % 60 == 0: mf_h.append(mf_s.hash_state())
		return [mf_s, mf_h]
	var mfa: Array = mf_run.call(); var mfb: Array = mf_run.call()
	var mf_seq: Array = []; var mf_ech := 0; var mf_mc := 0
	for mf_e in mfa[0].events:
		if str(mf_e["kind"]) in ["zone", "zone_end", "comedown_end"]: mf_seq.append("%s %s %s @%d" % [str(mf_e["kind"]), str(mf_e.get("who", "")), str(mf_e.get("tier", "")), int(mf_e.get("tick", 0))])
		if str(mf_e["kind"]) == "echo" and float(mf_e["dmg"]) > 0.0: mf_ech += 1
		if str(mf_e["kind"]) == "feed" and str(mf_e["text"]).contains("from the manifest's meter"): mf_mc += 1
	_sr("Spirit Manifestation on the scripted log vs Yuri's squad: %s, %d echoes landed, %d casts from the meter; every hash identical twice and different from the Zone's run" % [JSON.stringify(mf_seq), mf_ech, mf_mc],
		mf_seq.size() >= 2 and str(mf_seq[0]).begins_with("zone RORY manifest @3001") and mf_seq.filter(func(x): return str(x).begins_with("zone_end")).size() == 1 and mf_ech >= 1 and mfa[1] == mfb[1] and mfa[1].size() > 0 and mfa[1] != zna[1], "%d hashes" % mfa[1].size())
	# PAC-084: Inheritance on the same log - SAM in the club (undressed, the stable's) and Sworn with RORY: the same SURGE at tick 3,000 takes
	# SAM's House Tagaq style (Never Twice, his natives from the meter, the misreads), then the Comedown with RORY's dialect scrambled;
	# identical twice and different from the Zone's run
	var ih_led := TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg("RORY+SAM:150"), "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", content["economy"]), "story:provincials_semifinal")
	var ih_run := func() -> Array:
		var ih_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, ih_led)
		ih_s.stable.append(TNBSim.LINEUP_MILLBROOK_8[4].duplicate(true))
		var ih_h: Array = []
		for ih_i in log_.size():
			var ih_in: Dictionary = log_[ih_i]
			if ih_i == 3000:
				ih_s.tension = 100.0; ih_in = ih_in.duplicate(); ih_in["surge"] = true
			ih_s.step(ih_in)
			if ih_i % 60 == 0: ih_h.append(ih_s.hash_state())
		return [ih_s, ih_h]
	var iha: Array = ih_run.call(); var ihb: Array = ih_run.call()
	var ih_seq: Array = []; var ih_mis := 0; var ih_mc := 0
	for ih_e in iha[0].events:
		if str(ih_e["kind"]) in ["zone", "zone_end", "comedown_end"]: ih_seq.append("%s %s %s%s @%d" % [str(ih_e["kind"]), str(ih_e.get("who", "")), str(ih_e.get("tier", "")), (" <- " + str(ih_e["source"])) if str(ih_e.get("source", "")) != "" else "", int(ih_e.get("tick", 0))])
		if str(ih_e["kind"]) == "misread": ih_mis += 1
		if str(ih_e["kind"]) == "feed" and str(ih_e["text"]).contains("from the inherited meter"): ih_mc += 1
	_sr("Inheritance on the scripted log vs Yuri's squad: %s, %d misreads, %d casts from the meter; every hash identical twice and different from the Zone's run" % [JSON.stringify(ih_seq), ih_mis, ih_mc],
		ih_seq.size() >= 2 and str(ih_seq[0]).begins_with("zone RORY inheritance <- SAM @3001") and ih_seq.filter(func(x): return str(x).begins_with("zone_end")).size() == 1 and ih_mis >= 1 and iha[1] == ihb[1] and iha[1].size() > 0 and iha[1] != zna[1], "%d hashes" % iha[1].size())
	# PAC-085: Awakening on the same log - RORY's SECRET, his Arc 3 trial and the sealed house resolved beside the Zone's flag: the same SURGE at
	# tick 3,000 Awakens him with the Zone stacked at 75 % (the world x0.8125, a slip every 4 s, stamina three-quarters frozen), the caps x1.75,
	# a drop he scores +15 back; identical twice and different from the Zone's run
	var aw_led := TNBSim.seed_story(TNBSim.seed_levels(TNBSim.parse_kizuna_arg(""), "RORY:20,PRIYA:20,MARCUS:20,JUNE:20", content["economy"]), "story:provincials_semifinal,secret:RORY,story:trial:RORY,story:sealed_house_resolved")
	var aw_run := func() -> Array:
		var aw_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, aw_led)
		var aw_h: Array = []
		for aw_i in log_.size():
			var aw_in: Dictionary = log_[aw_i]
			if aw_i == 3000:
				aw_s.tension = 100.0; aw_in = aw_in.duplicate(); aw_in["surge"] = true
			aw_s.step(aw_in)
			if aw_i % 60 == 0: aw_h.append(aw_s.hash_state())
		return [aw_s, aw_h]
	var awa: Array = aw_run.call(); var awb: Array = aw_run.call()
	var aw_seq: Array = []; var aw_sl := 0; var aw_rf := 0
	for aw_e in awa[0].events:
		if str(aw_e["kind"]) in ["zone", "zone_end", "comedown_end"]: aw_seq.append("%s %s %s%s @%d" % [str(aw_e["kind"]), str(aw_e.get("who", "")), str(aw_e.get("tier", "")), (" (" + str(aw_e["form"]) + ")") if str(aw_e.get("form", "")) != "" else "", int(aw_e.get("tick", 0))])
		if str(aw_e["kind"]) == "evade" and str(aw_e.get("why", "")) == "ZONE_SLIP": aw_sl += 1
		if str(aw_e["kind"]) == "refund": aw_rf += 1
	_sr("Awakening on the scripted log vs Yuri's squad: %s, %d slips, %d refunds; every hash identical twice and different from the Zone's run" % [JSON.stringify(aw_seq), aw_sl, aw_rf],
		aw_seq.size() >= 2 and str(aw_seq[0]).begins_with("zone RORY awakening (zone) @3001") and aw_seq.filter(func(x): return str(x).begins_with("zone_end")).size() == 1 and aw_sl >= 1 and awa[1] == awb[1] and awa[1].size() > 0 and awa[1] != zna[1], "%d hashes" % awa[1].size())
	# PAC-086: the enemy's transformation on the same log vs Ioan Vasile - his own line, compiled: under 50 % composure he gathers 1.5 s behind
	# his guard with his line, then his Zone; the log's blocks and slips weather it; unanswered and never down, Stood in the Storm; his Comedown,
	# then himself; identical twice and different from the same log with his line stripped
	var bz_run := func(bz_strip: bool) -> Array:
		var bz_s := make_sim(16, 12345)
		var bz_h: Array = []
		for bz_i in log_.size():
			if bz_strip and bz_s.pattern.has("transform"): bz_s.pattern.erase("transform")
			bz_s.step(log_[bz_i])
			if bz_i % 60 == 0: bz_h.append(bz_s.hash_state())
		return [bz_s, bz_h]
	var bza: Array = bz_run.call(false); var bzb: Array = bz_run.call(false); var bzc: Array = bz_run.call(true)
	var bz_seq: Array = []; var bz_w := 0
	for bz_e in bza[0].events:
		if str(bz_e["kind"]) in ["boss_transform_tell", "boss_zone", "boss_zone_end", "feat", "boss_comedown_end"]: bz_seq.append("%s %s%s @%d" % [str(bz_e["kind"]), str(bz_e.get("who", bz_e.get("name", ""))), (" stood" if bool(bz_e.get("stood", false)) else "") if str(bz_e["kind"]) == "boss_zone_end" else ((" " + str(bz_e["tier"])) if bz_e.has("tier") else ""), int(bz_e.get("tick", 0))])
		if str(bz_e["kind"]) == "weather": bz_w += 1
	_sr("his Zone on the scripted log vs Ioan Vasile: %s, weathered %d; every hash identical twice and different from the log with his line stripped (%d there)" % [JSON.stringify(bz_seq), bz_w, count_events(bzc[0].events, "boss_zone")],
		bz_seq.size() == 5 and str(bz_seq[0]).begins_with("boss_transform_tell ioan_vasile zone @") and str(bz_seq[1]).begins_with("boss_zone ioan_vasile zone @") and str(bz_seq[2]).begins_with("boss_zone_end ioan_vasile stood @") and str(bz_seq[3]).begins_with("feat Stood in the Storm @") and str(bz_seq[4]).begins_with("boss_comedown_end ioan_vasile @") \
		and bz_w >= 1 and bza[1] == bzb[1] and bza[1].size() > 0 and bza[1] != bzc[1] and count_events(bzc[0].events, "boss_zone") == 0 and count_events(bzc[0].events, "boss_transform_tell") == 0, "%d hashes" % bza[1].size())
	# the save (NP_11 s9): the mini log broken at tick 12,000 by a save to text and a load into a new sim continues to the unbroken run's hashes
	var sv1 := make_sim(1, 12345)
	for i in 12000: sv1.step(log_[i])
	var sv_text: String = TNBSave.write_text(sv1, true)
	var sv_rd: Dictionary = TNBSave.read_text(sv_text)
	var sv_built: Dictionary = TNBSave.build(content, sv_rd, 31337)
	var sv2 = sv_built["sim"]
	var hsv: Array = []
	for i in range(12000, N):
		sv2.step(log_[i])
		if i % 60 == 0: hsv.append(sv2.hash_state())
	_sr("the log broken at tick 12,000 by a save (%d KB of text: the SaveGame, the DualState beneath it) and a load into a sim seeded otherwise continues to the unbroken run's hashes (%d of %d, tick %d)" % [sv_text.length() / 1024, hsv.size(), ha.size(), sv2.tick],
		bool(sv_rd["ok"]) and bool(sv_built["restored"].get("ok", false)) and hsv == ha.slice(200) and hsv.size() == 200 and sv2.hash_state() == a.hash_state())
	# the generic opponent assembler (NP_04 s9): the delegated dual with an assembled filler in R1 - his strings told, his hook, the dialect ticked - hashes identically twice and differs from the named run
	var ga := make_sim(1, 12345); ga.set_generic_slot(0, ga.generic_spec("FILLER", "SLUGGER", "kowalchuk", 3, 4242, "the Filler")); ga.delegate_all = true; ga.new_dual(); ga.events.clear()
	var hga := run_log(ga, log_auto, 60)
	var g_tells := 0; var g_hooks := 0; var g_special := 0
	for e_g in ga.events:
		if e_g["kind"] == "tell" and str(e_g.get("string", "")) != "": g_tells += 1
		elif e_g["kind"] == "sensor": g_hooks += 1
		if e_g["kind"] == "tell" and str(e_g.get("string", "")) == "S3": g_special += 1
	var gb := make_sim(1, 12345); gb.set_generic_slot(0, gb.generic_spec("FILLER", "SLUGGER", "kowalchuk", 3, 4242, "the Filler")); gb.delegate_all = true; gb.new_dual()
	var hgb := run_log(gb, log_auto, 60)
	_sr("the delegated dual with an assembled tier-3 Slugger filler in R1 (%s): %d tells of his own strings (%d of the SPECIAL), %d sensors, Kowalchuk ticked to PI %d; every hash identical twice and different from the named run" % [JSON.stringify(ga.gpatterns["FILLER"]["meta"]["pieces"]), g_tells, g_special, g_hooks, ga.pi_level("kowalchuk")],
		g_tells >= 5 and ga.pi_level("kowalchuk") >= 1 and hga == hgb and hga.size() > 0 and hga != hda, "%d hashes" % hga.size())
	# the neutral game (NP_04 s2 IDLE): the delegated dual vs Carter - his fast circle, his taunt every 10s, the rest of his lineup's own lines - hashed twice
	var na := make_sim(7, 12345); na.delegate_all = true; na.new_dual(); na.events.clear()
	var hna := run_log(na, log_auto, 60)
	var n_taunts := count_events(na.events, "taunt_b"); var n_foot := count_events(na.events, "footwork_audio"); var n_tempo := count_events(na.events, "tempo_shift")
	var nb := make_sim(7, 12345); nb.delegate_all = true; nb.new_dual()
	var hnb := run_log(nb, log_auto, 60)
	var nc := make_sim(7, 12345); nc.delegate_all = true; nc.new_dual(); nc.neutral_on = false
	var hnc := run_log(nc, log_auto, 60)
	_sr("the delegated dual vs Carter's lineup on their neutral games (%s): %d taunts, %d footwork flags, %d tempo shifts; every hash identical twice and different from the same dual with the neutral game frozen" % [JSON.stringify(na.blineup), n_taunts, n_foot, n_tempo],
		n_taunts >= 1 and hna == hnb and hna.size() > 0 and hna != hnc, "%d hashes" % hna.size())
	# The Talk (NP_10 s4): the delegated dual's corners with a talk in the log - Whitlock's reads land and miss, hashed twice; the log without one never talks (the profile has no mouth)
	var log_talk: Array = []
	var talk_opts := ["plan", "fire", "arm"]
	for ti in log_auto.size():
		var te: Dictionary = log_auto[ti].duplicate()
		if ti % 7 == 5: te["corner_action"] = {"kind": "talk", "option": talk_opts[(ti / 7) % 3]}
		log_talk.append(te)
	var tka := make_sim(1, 12345); tka.delegate_all = true; tka.new_dual(); tka.events.clear()
	var htka := run_log(tka, log_talk, 60)
	var tkb := make_sim(1, 12345); tkb.delegate_all = true; tkb.new_dual()
	var htkb := run_log(tkb, log_talk, 60)
	var t_talks := count_events(tka.events, "talk"); var t_land := count_events(tka.events, "talk", {"landed": true}); var t_eff := count_events(tka.events, "talk_effect")
	_sr("the delegated dual with talks in its corners: %d talks, %d landed, %d +5%% segments; every hash identical twice and different from the same log without them, which talks %d times" % [t_talks, t_land, t_eff, count_events(da.events, "talk")],
		t_talks >= 1 and htka == htkb and htka.size() > 0 and htka != hda and count_events(da.events, "talk") == 0, "%d hashes" % htka.size())
	# PAC-073: the delegated dual on a sealed board - the Relay Ladder over the eight (bonded RORY-SAM-MARCUS), the Reveal dressed at Lv3, against Vey's corner
	# (he runs decoys): identical twice, different from the same log on the card order; the projection and the seal identical in both runs
	var fb_kz := TNBSim.parse_kizuna_arg("RORY+SAM:50,SAM+MARCUS:50")
	var fb_board := {"archetype": "RELAY_LADDER", "staff": ["the_reveal", "patch_job", "raise_the_roof"]}
	fb_kz = TNBSim.seed_staff(fb_kz, "the_reveal:3", content["staff"])                                   # since PAC-074 the tactician's Lv3 is his ledger's (8 uses), not the board's
	var fba := make_sim(6, 12345, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, fb_kz, fb_board); fba.delegate_all = true; fba.new_dual()
	var fb_pa: Dictionary = fba.projection(); var fb_sa: Array = fba.sealed_p.duplicate()
	var hfba := run_log(fba, log_auto, 60)
	var fbb := make_sim(6, 12345, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, fb_kz, fb_board); fbb.delegate_all = true; fbb.new_dual()
	var fb_pb: Dictionary = fbb.projection()
	var hfbb := run_log(fbb, log_auto, 60)
	var fbc := make_sim(6, 12345, TNBSim.LINEUP_MILLBROOK_8, "sanctioned", {}, fb_kz); fbc.delegate_all = true; fbc.new_dual()
	var hfbc := run_log(fbc, log_auto, 60)
	var fb_at := count_events(fba.events, "kizuna_effect", {"stat_pct": 5.0}); var fb_atc := count_events(fbc.events, "kizuna_effect", {"stat_pct": 5.0})
	var fb_out: Array = []
	for fb_e in fba.events:
		if str(fb_e["kind"]) == "delegated": fb_out.append(str(fb_e["who"]))
	_sr("the delegated dual on a sealed board: the Relay Ladder %s with the Reveal at Lv3 vs Vey's corner - out in that order %s, %d Adjacent Trust segments (the card order's %d), %d seals on the log; every hash identical twice and different from the same log on the card order; the projection identical in both runs (decoy %s, read by the tactician %s, order at %d%%)" % [JSON.stringify(fb_sa), JSON.stringify(fb_out.slice(0, 5)), fb_at, fb_atc, count_events(fba.events, "sealed"), str(fb_pa["decoy"]), str(fb_pa["detected"]), int(fb_pa["pct"])],
		fb_sa == ["JUNE", "RORY", "SAM", "MARCUS", "PRIYA"] and hfba == hfbb and hfba.size() > 0 and hfba != hfbc and fb_pa == fb_pb and fb_out.size() >= 2 and fb_out[0] == "JUNE" and fb_out[1] == "RORY" and fb_at >= 1, "%d hashes" % hfba.size())
	# PAC-074: the delegated dual with a staffed corner vs Yuri - the janitor at Lv3 (the dual starts at 10 Tension), the ring announcer, the Professor:
	# the building heats from the fight's own spectacle (x1.4 with two hypes), the log's Raise the Roof calls convert it or are refused cold, the Professor
	# doubles the PI the segments earn; identical twice, different from the default corner
	var sf_led := TNBSim.seed_staff(TNBSim.parse_kizuna_arg(""), "janitor:3", content["staff"])
	var sf_board := {"staff": ["janitor", "ring_announcer", "professor"]}
	var sfa := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, sf_led, sf_board); sfa.delegate_all = true; sfa.new_dual()
	var sf_t0: float = sfa.tension
	var hsfa := run_log(sfa, log_auto, 60)
	var sfb := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, sf_led, sf_board); sfb.delegate_all = true; sfb.new_dual()
	var hsfb := run_log(sfb, log_auto, 60)
	var sf_gain := 0; var sf_conv := 0; var sf_peak := 0.0
	for sf_e in sfa.events:
		if str(sf_e["kind"]) == "crowd":
			if sf_e.has("src"): sf_gain += 1
			if sf_e.has("spent"): sf_conv += 1
			sf_peak = maxf(sf_peak, float(sf_e.get("heat", 0.0)) + float(sf_e.get("spent", 0.0)))
	var sf_cold := count_events(sfa.events, "corner_refused", {"action": "staff"})
	var sf_pi := int(sfa.pi["dialects"].get("kowalchuk", {}).get("segments", 0)); var da_pi := int(da.pi["dialects"].get("kowalchuk", {}).get("segments", 0))
	var sf_n := count_events(sfa.events, "pi_count", {"dialect": "kowalchuk", "source": "segments"}); var da_n := count_events(da.events, "pi_count", {"dialect": "kowalchuk", "source": "segments"})   # PAC-078: per segment, since Yuri's Load-Bearing moves the fight itself
	_sr("the delegated dual with a staffed corner vs Yuri: the janitor at Lv3 starts it at %.0f Tension; the building heats %d times (peak %.0f), %d Raise the Roof conversions and %d staff calls refused; the Professor's segments count %d on Kowalchuk over %d segment ends (the default corner's %d over %d); every hash identical twice and different from the default corner" % [sf_t0, sf_gain, sf_peak, sf_conv, sf_cold, sf_pi, sf_n, da_pi, da_n],
		absf(sf_t0 - 10.0) < 0.01 and sf_gain >= 1 and hsfa == hsfb and hsfa.size() > 0 and hsfa != hda and sf_n >= 1 and da_n >= 1 and sf_pi == 2 * sf_n and da_pi == da_n, "%d hashes" % hsfa.size())
	# PAC-075: recruitment on the log - the delegated mini log against Moira's squad (the log wins that dual on segments) with every tick between duals
	# approaching the flagged and recruiting the ready, the overworld's quest:cold_storage seeded (PAC-076: Q-MOREAU's quest id; PAC-075 wrote
	# q_moreau): the win flags four, the approach surfaces four conditions, Remy's (QUEST(cold_storage)) is met and he joins - and since PAC-076
	# his string surfaces JEAN-GUY, approached, waiting on E05; identical twice and different from the same log without the approach
	var log_rec: Array = []
	for rq_i in log_auto.size():
		var rq_e: Dictionary = log_auto[rq_i].duplicate(); rq_e["approach"] = "*"; rq_e["recruit"] = "*"; log_rec.append(rq_e)
	var rq_led := TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:cold_storage")
	var rqa := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, rq_led); rqa.delegate_all = true; rqa.new_dual()
	var hrqa := run_log(rqa, log_rec, 60)
	var rqb := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, rq_led); rqb.delegate_all = true; rqb.new_dual()
	var hrqb := run_log(rqb, log_rec, 60)
	var rqc := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, rq_led); rqc.delegate_all = true; rqc.new_dual()
	var hrqc := run_log(rqc, log_auto, 60)
	var rq_verdicts: Array = []
	for rq_e2 in rqa.events:
		if str(rq_e2["kind"]) == "dual_end": rq_verdicts.append(str(rq_e2["verdict"]))
	var rq_states := {}
	for rq_n in rqa.rewards["recruit"]: rq_states[rq_n] = rqa.recruit_state(str(rq_n))
	var rq_flag := count_events(rqa.events, "recruit_approachable"); var rq_cond := count_events(rqa.events, "recruit_condition"); var rq_join := count_events(rqa.events, "recruit_joined")
	_sr("recruitment on the delegated log vs Moira's squad: %s; %d flagging, %d conditions surfaced, %d joined - the stable %s, the states %s (without the approach: %s); every hash identical twice and different from the log without the approach" % [JSON.stringify(rq_verdicts), rq_flag, rq_cond, rq_join, JSON.stringify(rqa.stable.map(func(x): return str(x["name"]))), JSON.stringify(rq_states), JSON.stringify(rqc.recruits_open())],
		rq_verdicts.size() >= 1 and str(rq_verdicts[0]).begins_with("MILLBROOK") and rq_flag >= 1 and rq_cond >= 1 and rq_join >= 1 and rqa.recruit_state("remy_moreau") == "joined" and rqc.recruit_state("remy_moreau") == "approachable" \
		and hrqa == hrqb and hrqa.size() > 0 and hrqa != hrqc and rqa.rewards["recruit"] == rqb.rewards["recruit"], "%d hashes" % hrqa.size())
	# PAC-076: the String Wall on the log - the log above (quest:cold_storage, E05 open) puts one string up: REMY signed turns up JEAN-GUY and his
	# house, and JEAN-GUY waits on E05. PAC-077: with E05 closed too (feud_resolved:moreau+tremblay), E05 flips before the bell, Moreau's line is
	# met and the house blesses the club - JEAN-GUY and REMY come up through the blessing, with House Tremblay across the flipped edge and House
	# Iron with Vera, and the dual's tick signs both; identical twice, and different from the log with E05 open
	var rq_strings: Array = []
	for rq_e3 in rqa.events:
		if str(rq_e3["kind"]) == "wall_revealed": rq_strings.append("%s -> %s" % [str(rq_e3["from"]), ", ".join(PackedStringArray(rq_e3["labels"]))])
	var sw_led := TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "quest:cold_storage,feud_resolved:moreau+tremblay")
	var swa := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, sw_led); swa.delegate_all = true; swa.new_dual()
	var hswa := run_log(swa, log_rec, 60)
	var swb := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, sw_led); swb.delegate_all = true; swb.new_dual()
	var hswb := run_log(swb, log_rec, 60)
	var sw_strings: Array = []; var sw_order: Array = []
	for sw_e in swa.events:
		if str(sw_e["kind"]) == "wall_revealed": sw_strings.append("%s -> %s" % [str(sw_e["from"]), ", ".join(PackedStringArray(sw_e["labels"]))])
		if str(sw_e["kind"]) == "recruit_joined": sw_order.append(str(sw_e["card"]))
	sw_order.sort()
	_sr("the String Wall on the delegated log vs Moira's squad: E05 open, the strings %s and JEAN-GUY %s; E05 closed, the strings %s, joined %s (JEAN-GUY via %s, the Moreau house %s); every hash identical twice and different from the log with E05 open" % [JSON.stringify(rq_strings), rqa.recruit_state("jean_guy_moreau"), JSON.stringify(sw_strings), JSON.stringify(sw_order), str(swa.rewards["recruit"].get("jean_guy_moreau", {}).get("via", "")), swa.house_state("moreau")],
		rq_strings == ["REMY -> JEAN-GUY, HOUSE MOREAU"] and rqa.recruit_state("jean_guy_moreau") == "approached" and str(rqa.rewards["recruit"]["jean_guy_moreau"].get("via", "")) == "remy_moreau" \
		and sw_strings == ["the Moreau blessing -> HOUSE MOREAU, JEAN-GUY, REMY, HOUSE TREMBLAY, HOUSE IRON", "HOUSE IRON -> VERA IRON"] and sw_order == ["JEAN-GUY", "REMY"] and swa.house_state("moreau") == "blessed" \
		and hswa == hswb and hswa.size() > 0 and hswa != hrqa and swa.rewards["string_wall"] == swb.rewards["string_wall"] and swa.rewards["recruit"] == swb.rewards["recruit"], "%d hashes" % hswa.size())
	# PAC-077: a blessing granted on the log - a ledger from an earlier session (YURI signed, a segment won against him; his card on the bench):
	# House Kowalchuk's crest is up from the bell, the log's dual against Moira's squad is the home dual the patriarch attends, the line is met at
	# the dual's end - the house blesses the club, YURI is sanctioned, the cousins and House Whitecloud come up; identical twice, and different
	# from the same log on a ledger without YURI's signing, where the crest is down and nobody watches
	var bk_led := TNBSim.seed_story(TNBSim.parse_kizuna_arg(""), "")
	bk_led["beaten"] = {"yuri_kowalchuk": {"scrap": 0, "spar": 0, "segment": 1, "dual": 1, "styles": {"segment:BOXERPUNCHER": 1}, "house": "kowalchuk"}}
	var bk_led_c := bk_led.duplicate(true)
	bk_led["recruit"] = {"yuri_kowalchuk": {"state": "joined", "witnessed": 0, "day": 1}}
	var bk_yuri: Dictionary = TNBSim.LINEUP_MILLBROOK_8[6].duplicate(true); bk_yuri.erase("reserve")
	var bka := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, bk_led); bka.stable.append(bk_yuri.duplicate(true)); bka.delegate_all = true; bka.new_dual()
	var hbka := run_log(bka, log_rec, 60)
	var bkb := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, bk_led); bkb.stable.append(bk_yuri.duplicate(true)); bkb.delegate_all = true; bkb.new_dual()
	var hbkb := run_log(bkb, log_rec, 60)
	var bkc := make_sim(19, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, bk_led_c); bkc.stable.append(bk_yuri.duplicate(true)); bkc.delegate_all = true; bkc.new_dual()
	var hbkc := run_log(bkc, log_rec, 60)
	var bk_bless: Array = []; var bk_wall: Array = []; var bk_tick := -1; var bk_end := -1
	for bk_e in bka.events:
		if str(bk_e["kind"]) == "blessing_granted": bk_bless.append("%s %s %s" % [str(bk_e["house"]), str(bk_e["how"]), JSON.stringify(bk_e["sanctioned"])]); bk_tick = int(bk_e.get("tick", -1))
		if str(bk_e["kind"]) == "wall_revealed": bk_wall.append("%s -> %s" % [str(bk_e["from"]), ", ".join(PackedStringArray(bk_e["labels"]))])
		if str(bk_e["kind"]) == "dual_end" and bk_end < 0: bk_end = int(bk_e.get("tick", -1))
	_sr("a blessing on the delegated log vs Moira's squad: the crest up from the bell (at the end: %s), the witness %d; granted %s (at the dual's end: %s), YURI %s with %s; the wall %s; without YURI's signing the crest %s and %d blessings; every hash identical twice and different from it" % [bka.sw_state("house_kowalchuk"), int(bka.rewards["houses"].get("kowalchuk", {}).get("witnessed", 0)), JSON.stringify(bk_bless), str(bk_tick == bk_end and bk_tick >= 0), bka.house_status("YURI"), JSON.stringify(bka.natives_unlocked("YURI")), JSON.stringify(bk_wall), bkc.sw_state("house_kowalchuk") if bkc.sw_state("house_kowalchuk") != "" else "down", count_events(bkc.events, "blessing_granted")],
		bk_bless == ["kowalchuk met [\"YURI\"]"] and bk_tick == bk_end and bk_tick >= 0 and bka.house_status("YURI") == "NATIVE" and bka.natives_unlocked("YURI") == ["Grain Elevator", "Full Load"] \
		and bk_wall == ["YURI -> HOUSE KOWALCHUK", "the Kowalchuk blessing -> THE KOWALCHUK COUSINS, HOUSE WHITECLOUD"] and bkc.sw_state("house_kowalchuk") == "" and count_events(bkc.events, "blessing_granted") == 0 \
		and hbka == hbkb and hbka.size() > 0 and hbka != hbkc and bka.rewards["houses"] == bkb.rewards["houses"], "%d hashes" % hbka.size())
	# PAC-078: house traits on both corners on the delegated log - YURI (Load-Bearing), SAM (Never Twice) and MARTA (First Frost) out, DEX
	# (Tide Discipline) in reserve, against Carter's squad (Carter's and Chiamaka's Harvest): identical twice, and different from the same log on a
	# house table with every trait taken out, where no segment names one
	var tr_lu: Array = [TNBSim.LINEUP_MILLBROOK_8[6].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[4].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[7].duplicate(true), TNBSim.LINEUP_MILLBROOK_8[5].duplicate(true)]
	tr_lu[0].erase("reserve"); tr_lu[2].erase("reserve")
	var tra := make_sim(7, 12345, tr_lu); tra.delegate_all = true; tra.new_dual()
	var htra := run_log(tra, log_auto, 60)
	var trb := make_sim(7, 12345, tr_lu); trb.delegate_all = true; trb.new_dual()
	var htrb := run_log(trb, log_auto, 60)
	var tr_keep: Dictionary = content["houses"]; content["houses"] = tr_keep.duplicate(true)
	for tr_h in content["houses"]["houses"]: content["houses"]["houses"][tr_h]["trait_id"] = null
	var trc := make_sim(7, 12345, tr_lu); trc.delegate_all = true; trc.new_dual()
	var htrc := run_log(trc, log_auto, 60)
	content["houses"] = tr_keep
	var tr_seen: Array = []; var tr_both := 0
	for tr_e in tra.events:
		if str(tr_e["kind"]) != "traits": continue
		tr_seen.append("%s / %s" % [str(tr_e["p"].get("name", "-")), str(tr_e["b"].get("name", "-"))])
		if tr_e["p"].size() > 0 and tr_e["b"].size() > 0: tr_both += 1
	_sr("house traits on the delegated log vs Carter's squad: the segments' traits %s (%d with both corners), %d Never Twice wobbles; without traits %d named; every hash identical twice and different from the traitless log" % [JSON.stringify(tr_seen), tr_both, count_events(tra.events, "trait", {"trait": "never_twice"}), count_events(trc.events, "traits")],
		tr_both >= 1 and htra == htrb and htra.size() > 0 and htra != htrc and count_events(trc.events, "traits") == 0, "%d hashes" % htra.size())
	# PAC-079: a wall-suggested board on the delegated log vs Yuri's squad - MARCUS pinned under RORY and PRIYA under him, the Gym Wall's suggestion
	# sealed (R1 RORY, R2 MARCUS, R3 PRIYA): identical twice and different from the card order's run; the same order sealed by hand hashes the same
	# (the wall adds nothing but the order), and the wall rearranged and decorated through the run hashes the same (zero stats)
	var gw_run := func(gw_deco: bool) -> Array:
		var gw_s := make_sim(1, 12345); gw_s.pin("MARCUS", 1, 1); gw_s.pin("PRIYA", 1, 2); gw_s.seal_board({"archetype": "GYM_WALL"}); gw_s.delegate_all = true; gw_s.new_dual()
		if gw_deco:
			gw_s.pin("JUNE", 6, 3); gw_s.arrange("letter", 3.0, 5.5)
			for gw_k in ["poster", "polaroid", "graffiti"]: gw_s._gw_deco(gw_k, "a test %s" % gw_k)
		return [gw_s, run_log(gw_s, log_auto, 60)]
	# PAC-080: a Duo relay on the delegated log vs Yuri's squad - RORY and PRIYA at Duo (90): R2 PRIYA carries Whiteout and the profile casts it
	# when the bar allows; identical twice and different from the same log at Adjacent Trust (89), whose stats are the same and where no Duo is live
	var duo_run := func(duo_k: String) -> Array:
		var duo_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.parse_kizuna_arg(duo_k)); duo_s.delegate_all = true; duo_s.new_dual()
		return [duo_s, run_log(duo_s, log_auto, 60)]
	var dua: Array = duo_run.call("RORY+PRIYA:90"); var dub: Array = duo_run.call("RORY+PRIYA:90"); var duc: Array = duo_run.call("RORY+PRIYA:89")
	var du_live: Array = []; var du_cast: Array = []; var du_cast_c: Array = []
	for du_e in dua[0].events:
		if str(du_e["kind"]) == "duo": du_live.append("R%d %s" % [int(du_e.get("seg", 0)), str(du_e["move"])])
		if str(du_e["kind"]) == "cast" and str(du_e["who"]) == "P": du_cast.append("%s%s" % [str(du_e["move"]), " (afterimage %s)" % str(du_e["afterimage"]) if str(du_e.get("afterimage", "")) != "" else ""])
	for du_e2 in duc[0].events:
		if str(du_e2["kind"]) == "cast" and str(du_e2["who"]) == "P": du_cast_c.append(str(du_e2["move"]))
	_sr("a Duo relay on the delegated log vs Yuri's squad: the Duo live %s, the casts %s (at Adjacent Trust %s); every hash identical twice and different from the Adjacent Trust run" % [JSON.stringify(du_live), JSON.stringify(du_cast), JSON.stringify(du_cast_c)],
		du_live.size() >= 1 and du_cast.has("Whiteout (afterimage RORY)") and not du_cast_c.has("Whiteout") and dua[1] == dub[1] and dua[1].size() > 0 and dua[1] != duc[1], "%d hashes" % dua[1].size())
	# PAC-087: a hybrid on the delegated log vs Yuri's squad - YURI and MARTA Sworn, forged (Grain & Snow), out R1 and R2; the bar topped up
	# at tick 3,100 in her segment and the profile casts the pair's hybrid relayed; identical twice and different from the same log unforged,
	# where the pair's Duo T3 answers the same motion
	var hy_lu: Array = []
	for hy_nm in ["YURI", "MARTA", "RORY", "PRIYA"]:
		for hy_c in TNBSim.LINEUP_MILLBROOK_8:
			if str(hy_c["name"]) == hy_nm:
				var hy_cc: Dictionary = hy_c.duplicate(true); hy_cc.erase("reserve"); hy_lu.append(hy_cc)
	hy_lu[3]["reserve"] = true
	var hy_run := func(hy_forge: bool) -> Array:
		var hy_s := make_sim(1, 12345, hy_lu, "", {}, TNBSim.seed_facilities(TNBSim.seed_purse(TNBSim.parse_kizuna_arg("YURI+MARTA:150"), "spirits:40,beans:30"), "wall:3", content["facilities"]))   # since PAC-089 the Forge is The Wall's T3
		if hy_forge: hy_s.forge("YURI", "MARTA")
		hy_s.delegate_all = true; hy_s.new_dual(); hy_s.events.clear()
		var hy_h: Array = []
		for hy_i in log_auto.size():
			if hy_i == 3100: hy_s.tension = 100.0
			hy_s.step(log_auto[hy_i])
			if hy_i % 60 == 0: hy_h.append(hy_s.hash_state())
		return [hy_s, hy_h]
	var hya: Array = hy_run.call(true); var hyb: Array = hy_run.call(true); var hyc: Array = hy_run.call(false)
	var hy_seq: Array = []; var hy_cc2: Array = []
	for hy_e in hya[0].events:
		if str(hy_e["kind"]) == "hybrid": hy_seq.append("live %s %s R%d" % [str(hy_e["move"]), str(hy_e["live"]), int(hy_e["seg"])])
		if str(hy_e["kind"]) == "cast" and str(hy_e["who"]) == "P": hy_seq.append("cast %s%s" % [str(hy_e["move"]), (" (" + str(hy_e["hybrid_live"]) + ", afterimage " + str(hy_e["afterimage"]) + ")") if str(hy_e.get("hybrid", "")) != "" else ""])
		if str(hy_e["kind"]) == "hybrid_debut": hy_seq.append("debut %s" % str(hy_e["name"]))
	for hy_e2 in hyc[0].events:
		if str(hy_e2["kind"]) == "cast" and str(hy_e2["who"]) == "P": hy_cc2.append(str(hy_e2["move"]))
	_sr("a hybrid on the delegated log vs Yuri's squad: %s; unforged the casts %s; every hash identical twice and different from the unforged run" % [JSON.stringify(hy_seq.slice(0, 6)), JSON.stringify(hy_cc2.slice(0, 4))],
		hy_seq.has("live Grain & Snow relayed R2") and hy_seq.has("cast Grain & Snow (relayed, afterimage YURI)") and hy_seq.filter(func(x): return str(x).begins_with("debut")).size() == 1 and not hy_cc2.has("Grain & Snow") and hy_cc2.has("Coast to Coast - MARTA & YURI") \
		and hya[1] == hyb[1] and hya[1].size() > 0 and hya[1] != hyc[1], "%d hashes" % hya[1].size())
	# PAC-088: the Exhibition 2v2 on the delegated log - RORY and PRIYA at Duo (90) against Yuri and Moreau, both on their profiles (the
	# manager's seat), the bar topped up at tick 600: the profiles call Double Overtime, both halves cast at once; the exhibition runs to its
	# verdict; every hash (both engagements and the coordinator) identical twice and different from the same log at Adjacent Trust (50),
	# where no duo is live and the profiles spend the bar as their own
	var ex_run := func(ex_k: String) -> Array:
		var ex_x = TNBExhibition.new()
		ex_x.setup(content, [TNBSim.LINEUP_MILLBROOK[0], TNBSim.LINEUP_MILLBROOK[1]], 1, 12345, TNBSim.parse_kizuna_arg(ex_k), {}, "exhibition_2v2", true)
		var ex_h: Array = []
		for ex_i in log_auto.size():
			if ex_x.over: break
			if ex_i == 600: ex_x.set_team(100.0)
			ex_x.step(log_auto[ex_i])
			if ex_i % 60 == 0: ex_h.append(ex_x.hash_state())
		return [ex_x, ex_h]
	var exa: Array = ex_run.call("RORY+PRIYA:90"); var exb: Array = ex_run.call("RORY+PRIYA:90"); var exc: Array = ex_run.call("RORY+PRIYA:50")
	var ex_seq: Array = []; var ex_c: Array = []
	for ex_e in exa[0].events:
		if str(ex_e["kind"]) == "duo_cast": ex_seq.append("%s by %s" % [str(ex_e["move"]), str(ex_e["by"])])
	for ex_tg in ["A", "B"]:
		for ex_e2 in exa[0].e(ex_tg).events:
			if str(ex_e2["kind"]) == "cast" and str(ex_e2["who"]) == "P" and str(ex_e2.get("duo_sync", "")) != "": ex_seq.append("%s %s" % [ex_tg, str(ex_e2["move"])])
		for ex_e3 in exc[0].e(ex_tg).events:
			if str(ex_e3["kind"]) == "cast" and str(ex_e3["who"]) == "P": ex_c.append("%s %s" % [ex_tg, str(ex_e3["move"])])
	_sr("the Exhibition 2v2 on the delegated log (the manager's seat) vs Yuri and Moreau: %s, then %s; at Adjacent Trust the casts %s, %s; every hash identical twice and different from the Adjacent Trust run" % [JSON.stringify(ex_seq), str(exa[0].verdict.get("verdict", "")), JSON.stringify(ex_c.slice(0, 4)), str(exc[0].verdict.get("verdict", ""))],
		ex_seq.has("Double Overtime by manager") and ex_seq.has("A Double Overtime") and ex_seq.has("B Double Overtime") and not ex_c.has("A Double Overtime") and not ex_c.has("B Double Overtime") \
		and exa[0].over and exa[1] == exb[1] and exa[1].size() > 0 and exa[1] != exc[1], "%d hashes" % exa[1].size())
	# PAC-089: a hosted dual on the delegated log vs Yuri's squad with every facility at T3: the entrance at each bell (the sting, the banner,
	# the chant), the crowd at 20 from the bell, 5 Prestige from each hosted dual's end; identical twice and different from the same log
	# away, where the entrance still walks out and neither the crowd's base nor the Prestige is paid
	var fa_run := func(fa_host: bool) -> Array:
		var fa_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities({}, "bags:3,ring:3,film:3,wall:3,foh:3", content["facilities"]))
		fa_s.delegate_all = true; fa_s.host = fa_host; fa_s.events.clear(); fa_s.new_dual()
		return [fa_s, run_log(fa_s, log_auto, 60)]
	var faa: Array = fa_run.call(true); var fab: Array = fa_run.call(true); var fac_: Array = fa_run.call(false)
	var fa_sum := func(fa_s: TNBSim) -> Array:
		var fa_en := 0; var fa_cr := 0; var fa_pr: Array = []
		for fa_e in fa_s.events:
			if str(fa_e["kind"]) == "entrance" and fa_e["set"] == ["music sting", "banner", "crowd chant"]: fa_en += 1
			if str(fa_e["kind"]) == "crowd" and bool(fa_e.get("base", false)) and float(fa_e["heat"]) == 20.0: fa_cr += 1
			if str(fa_e["kind"]) == "reward_toast" and str(fa_e.get("size", "")) == "dual": fa_pr.append(int(fa_e.get("prestige", 0)))
		return [fa_en, fa_cr, fa_pr]
	var fa_h: Array = fa_sum.call(faa[0]); var fa_a: Array = fa_sum.call(fac_[0])
	_sr("a hosted dual on the delegated log vs Yuri's squad, every facility at T3: entrances %d, the crowd from 20 at %d bells, the duals' hosted Prestige %s; away: entrances %d, %d, %s; every hash identical twice and different from the away run" % [int(fa_h[0]), int(fa_h[1]), JSON.stringify(fa_h[2]), int(fa_a[0]), int(fa_a[1]), JSON.stringify(fa_a[2])],
		int(fa_h[0]) >= 1 and int(fa_h[1]) >= 1 and fa_h[2].size() >= 1 and fa_h[2].filter(func(x): return int(x) == 5).size() == fa_h[2].size() and int(fa_a[0]) == int(fa_h[0]) and int(fa_a[1]) == 0 and fa_a[2].filter(func(x): return int(x) != 0).is_empty() \
		and faa[1] == fab[1] and faa[1].size() > 0 and faa[1] != fac_[1], "%d hashes" % faa[1].size())
	# PAC-090: the fighters' growth on the delegated log vs Yuri's squad - boards taken before the bell (the aid's picks: passives first)
	# and between every dual (the log's "grow"), raises on typed Beans, an ascension on a trial met; identical twice, and different from
	# the same log and ledger with no growth
	var gr_log: Array = []; var gr_plain: Array = []                                                        # the log twice over: the first dual's end, the aid, the second dual
	for gr_r in 2:
		for gr_x in log_auto:
			var gr_y: Dictionary = gr_x.duplicate(); gr_y["grow"] = "*"; gr_log.append(gr_y); gr_plain.append(gr_x)
	var gr_run := func(gr_on: bool) -> Array:
		var gr_led: Dictionary = TNBSim.seed_beans(TNBSim.seed_growth(TNBSim.seed_purse(TNBSim.seed_levels({}, "RORY:12,PRIYA:12,MARCUS:12,JUNE:12", content["economy"]), "spirits:60,beans:40"), "RORY:trial:spar_won,MARCUS:trial:spar_won"), "PWR:10,RFX:10")
		var gr_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, gr_led)
		var gr_pre := 0
		if gr_on:
			for gr_i in 6: gr_pre += gr_s.grow_aid("*")
		gr_s.delegate_all = true; gr_s.events.clear(); gr_s.new_dual()
		return [gr_s, run_log(gr_s, gr_log if gr_on else gr_plain, 120), gr_pre]
	var gra: Array = gr_run.call(true); var grb: Array = gr_run.call(true); var grc: Array = gr_run.call(false)
	var gr_sum := func(gr_s2: TNBSim) -> Array:
		var gr_p := {}
		for gr_c in gr_s2.dressed: gr_p[str(gr_c["name"])] = gr_s2.passives_of(str(gr_c["name"]))
		return [count_events(gr_s2.events, "node_taken"), count_events(gr_s2.events, "stat_raised"), count_events(gr_s2.events, "ascended"), count_events(gr_s2.events, "dual_end"), gr_p, gr_s2.rarity_of("RORY")]
	var gr_a: Array = gr_sum.call(gra[0]); var gr_c2: Array = gr_sum.call(grc[0])
	_sr("the fighters' growth on the delegated log vs Yuri's squad: %d steps before the bell; after %d dual(s) the aid's %d nodes, %d raises, %d ascensions (RORY at T%d), the passives %s; none without it (%s); every hash identical twice and different from the run without growth" % [int(gra[2]), int(gr_a[3]), int(gr_a[0]), int(gr_a[1]), int(gr_a[2]), int(gr_a[5]), JSON.stringify(gr_a[4]), JSON.stringify(gr_c2.slice(0, 3))],
		int(gra[2]) > 0 and int(gr_a[0]) > 0 and int(gr_a[3]) >= 1 and gr_a[4]["RORY"].size() > 0 and gr_c2.slice(0, 3) == [0, 0, 0] \
		and gra[1] == grb[1] and gra[1].size() > 0 and gra[1] != grc[1], "%d hashes" % gra[1].size())
	# PAC-091: a taught kit on the scripted log vs Yuri's squad - RORY at 15 with Snowblind and Root Bind in his slots and Cornerstone in his
	# T0 slot, MARCUS at 5 with Updraft; the log's LB + motions cast them where his own move has another family or the bar cannot pay it, and
	# between duals the aid teaches (a lesson, a tape, the shop, a re-teach); identical twice, and different from the same log with no kits
	var tq_log: Array = []
	for tq_x in log_:
		var tq_y: Dictionary = tq_x.duplicate(); tq_y["teach"] = "*"; tq_log.append(tq_y)
	var tq_run := func(tq_on: bool) -> Array:
		var tq_led: Dictionary = TNBSim.seed_levels({}, "RORY:15,PRIYA:5,MARCUS:5,JUNE:5", content["economy"])
		if tq_on: tq_led = TNBSim.seed_tapes(TNBSim.seed_learned(TNBSim.seed_story(TNBSim.seed_purse(tq_led, "hbp:1500"), "story:regionals"), "RORY:Snowblind+Root Bind+Cornerstone,MARCUS:Updraft"), "Black Ice:1")
		var tq_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities(tq_led, "bags:1", content["facilities"]))
		tq_s.events.clear(); tq_s.new_dual()
		return [tq_s, run_log(tq_s, tq_log if tq_on else log_, 60)]
	var tqa: Array = tq_run.call(true); var tqb: Array = tq_run.call(true); var tqc: Array = tq_run.call(false)
	var tq_sum := func(tq_s2: TNBSim) -> Array:
		var tq_c := {}
		for tq_e in tq_s2.events:
			if str(tq_e["kind"]) == "cast" and str(tq_e["who"]) == "P" and str(tq_e["move"]) in ["Snowblind", "Root Bind", "Cornerstone", "Updraft", "Black Ice"]: tq_c[str(tq_e["move"])] = int(tq_c.get(str(tq_e["move"]), 0)) + 1
		return [tq_c, count_events(tq_s2.events, "learned"), count_events(tq_s2.events, "dual_end")]
	var tq_a: Array = tq_sum.call(tqa[0]); var tq_c2: Array = tq_sum.call(tqc[0])
	_sr("a taught kit on the scripted log vs Yuri's squad: the kit's casts %s, %d learned between %d dual(s); without the kits %s; every hash identical twice and different from the run without them" % [JSON.stringify(tq_a[0]), int(tq_a[1]), int(tq_a[2]), JSON.stringify(tq_c2.slice(0, 2))],
		tq_a[0].size() >= 1 and tq_c2[0].is_empty() and int(tq_c2[1]) == 0 and tqa[1] == tqb[1] and tqa[1].size() > 0 and tqa[1] != tqc[1], "%d hashes" % tqa[1].size())
	# PAC-092: the academy fielded on the delegated log - the prodigies in every enemy segment, Director Vey's corner, their syntheses cast
	# from their bars when they pay, the log restarting duals; identical twice, and different from the same log against Yuri's squad
	var ac_run := func(ac_on: bool) -> Array:
		var ac_s := make_sim(1, 12345)
		if ac_on: ac_s.field_academy(true)
		ac_s.delegate_all = true; ac_s.events.clear(); ac_s.new_dual()
		return [ac_s, run_log(ac_s, log_auto, 60)]
	var aca: Array = ac_run.call(true); var acb: Array = ac_run.call(true); var acc: Array = ac_run.call(false)
	var ac_sum := func(ac_s2: TNBSim) -> Array:
		var ac_n: Array = []; var ac_opp := {}; var ac_sw: Array = []
		for ac_e in ac_s2.events:
			if str(ac_e["kind"]) == "synthesis": ac_n.append("%s %s" % [str(ac_e["who"]), str(ac_e["move"])])
			if str(ac_e["kind"]) == "academy": ac_opp[str(ac_e["who"])] = true
			if str(ac_e["kind"]) == "coach_action" and str(ac_e.get("action", "")) == "swap": ac_sw.append(str(ac_e["id"]))
		return [ac_n, ac_opp.keys(), count_events(ac_s2.events, "dual_end"), str(ac_s2.coach.get("id", "")), ac_sw, ac_s2.blineup.duplicate() + ac_s2.breserves.duplicate()]
	var ac_a: Array = ac_sum.call(aca[0]); var ac_c: Array = ac_sum.call(acc[0])
	_sr("the academy on the delegated log: %d dual(s) against %s (%s's corner, his swaps %s, the squad at the end %s), the syntheses cast %s; against Yuri's squad none (%s); every hash identical twice and different from it" % [int(ac_a[2]), JSON.stringify(ac_a[1]), str(ac_a[3]), JSON.stringify(ac_a[4]), JSON.stringify(ac_a[5]), JSON.stringify(ac_a[0]), str(ac_c[3])],
		ac_a[0].size() >= 1 and ac_a[1].size() >= 3 and str(ac_a[3]) == "ascendant_a" and (ac_a[4] + ac_a[5]).filter(func(ac_x): return not str(ac_x).begins_with("ASCENDANT ")).is_empty() and ac_c[0].is_empty() and str(ac_c[3]) == "grain_kings" and aca[1] == acb[1] and aca[1].size() > 0 and aca[1] != acc[1], "%d hashes" % aca[1].size())
	# PAC-093: the mirror on the delegated log - the dual against Yuri's squad records how each card fights; between duals the aid spars
	# the next card's mirror (the lab's flag, The Ring at T1) on that record and goes back; identical twice, and different from the same
	# log without the aid
	var mi_log: Array = log_auto.map(func(mi_e): return (mi_e as Dictionary).merged({"mirror": "*"}))
	var mi_run := func(mi_on: bool) -> Array:
		var mi_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities({}, "ring:1", content["facilities"]))
		mi_s.delegate_all = true; mi_s.events.clear(); mi_s.new_dual()
		return [mi_s, run_log(mi_s, mi_log if mi_on else log_auto, 60)]
	var mia: Array = mi_run.call(true); var mib: Array = mi_run.call(true); var mic: Array = mi_run.call(false)
	var mi_sum := func(mi_s2: TNBSim) -> Array:
		var mi_m: Array = []
		for mi_e2 in mi_s2.events:
			if str(mi_e2["kind"]) == "mirror": mi_m.append("%s: %s" % [str(mi_e2["of"]), ", ".join(PackedStringArray(mi_e2["habits"]))])
		return [mi_m, count_events(mi_s2.events, "mirror_counter"), count_events(mi_s2.events, "dual_end"), count_events(mi_s2.events, "bout_end"), mi_s2.rewards.get("habits", {}).keys(), int(mi_s2.habits_of("RORY").get("punches", 0))]
	var mi_a: Array = mi_sum.call(mia[0]); var mi_c: Array = mi_sum.call(mic[0])
	_sr("the mirror on the delegated log: %d dual(s) recorded %s (RORY %d punches), then the mirrors %s (%d counters of yours thrown back, %d spar(s) ended); without the aid none; every hash identical twice and different from it" % [int(mi_a[2]), JSON.stringify(mi_a[4]), int(mi_a[5]), JSON.stringify(mi_a[0]), int(mi_a[1]), int(mi_a[3])],
		mi_a[0].size() >= 1 and str(mi_a[0][0]).contains("HABIT") and int(mi_a[2]) >= 1 and int(mi_a[5]) > 0 and mi_c[0].is_empty() and mia[1] == mib[1] and mia[1].size() > 0 and mia[1] != mic[1], "%d hashes" % mia[1].size())
	# PAC-094: gear on the delegated log against Yuri's squad - a purse and the Regionals' flag; the aid dresses each card before the bell
	# (the Regionals Robe from the locker, the shop's pick for the rest) and again between duals (the log's gear); identical twice, and
	# different from the same log and ledger undressed
	var gz_log: Array = log_auto.map(func(gz_e): return (gz_e as Dictionary).merged({"gear": "*"}))
	var gz_run := func(gz_on: bool) -> Array:
		var gz_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_purse(TNBSim.seed_story({}, "story:regionals"), "hbp:900"))
		if gz_on: gz_s.gear_aid("*")
		gz_s.delegate_all = true; gz_s.events.clear(); gz_s.new_dual()
		return [gz_s, run_log(gz_s, gz_log if gz_on else log_auto, 60)]
	var gza: Array = gz_run.call(true); var gzb: Array = gz_run.call(true); var gzc: Array = gz_run.call(false)
	var gz_sum := func(gz_s2: TNBSim) -> Array:
		var gz_w := {}
		for gz_c in gz_s2.stable:
			if gz_s2.gear_worn(str(gz_c["name"])).size() > 0: gz_w[str(gz_c["name"])] = gz_s2.gear_worn(str(gz_c["name"]))
		return [gz_w, count_events(gz_s2.events, "dual_end"), int(gz_s2.rewards["hbp"]), gz_s2.gear_owned()]
	var gz_a: Array = gz_sum.call(gza[0]); var gz_c2: Array = gz_sum.call(gzc[0])
	_sr("gear on the delegated log vs Yuri's squad: %d dual(s) worn %s (HBP left %d, the locker %s); undressed %s; every hash identical twice and different from the undressed run" % [int(gz_a[1]), JSON.stringify(gz_a[0]), int(gz_a[2]), JSON.stringify(gz_a[3]), JSON.stringify(gz_c2[0])],
		gz_a[0].size() >= 3 and gz_a[0].get("RORY", []) == ["regionals_robe"] and gz_c2[0].is_empty() and gza[1] == gzb[1] and gza[1].size() > 0 and gza[1] != gzc[1], "%d hashes" % gza[1].size())
	# PAC-095: the obsolescence audit, reduced (DEX against two endgame bosses, one seed): built and fought twice alike to the last number
	# and every spar's hash, and a seed apart different
	var au_run := func(au_seed: int) -> Array:
		var au_rep: Dictionary = TNBAudit.run(content, content["audit"], {"fighters": ["DEX"], "bosses": ["alfie_crane", "ioan_vasile"], "seeds": [au_seed], "reference": false})
		var au_b: Dictionary = au_rep["early"][0]
		return [JSON.stringify([au_b["level"], au_b["rarity"], au_b["total"], au_b["stats"], au_b["kit"], au_b["gear"], au_b["left"], au_b["fails"]]), au_b["fights"].map(func(au_f): return [au_f["boss"], au_f["won"], au_f["score"], au_f["ep"], au_f["hash"]])]
	var aua: Array = au_run.call(11); var aub: Array = au_run.call(11); var auc: Array = au_run.call(22)
	_sr("the obsolescence audit, reduced: DEX built %s; fought %s; again %s; a seed apart %s" % [str(aua[0]).substr(0, 160), JSON.stringify(aua[1].map(func(au_x): return [au_x[0], au_x[1], au_x[2]])), "identical" if aua == aub else "DIFFERENT", "different" if aua[1] != auc[1] else "THE SAME"],
		aua == aub and aua[1] != auc[1] and aua[0] == auc[0] and aua[1].size() == 2, "%d spars" % aua[1].size())
	# PAC-096: the audit's fixes on the log (PRIYA against Chiamaka Okafor, one seed): built and fought twice alike to the last number and
	# the spar's hash, and different from the same build with the rarity totals taken out
	var fx_nt: Dictionary = content.duplicate(); fx_nt["growth"] = content["growth"].duplicate(true); fx_nt["growth"]["rarity"].erase("totals")
	var fx_run := func(fx_c: Dictionary) -> Array:
		var fx_rep: Dictionary = TNBAudit.run(fx_c, content["audit"], {"fighters": ["PRIYA"], "bosses": ["chiamaka_okafor"], "seeds": [11], "reference": false})
		var fx_b: Dictionary = fx_rep["early"][0]
		return [JSON.stringify([fx_b["level"], fx_b["rarity"], fx_b["total"], fx_b["stats"], fx_b["kit"], fx_b["gear"], fx_b["left"], fx_b["fails"].keys()]), fx_b["fights"].map(func(fx_f): return [fx_f["boss"], fx_f["won"], fx_f["score"], fx_f["ep"], fx_f["hash"]])]
	var fxa: Array = fx_run.call(content); var fxb: Array = fx_run.call(content); var fxc: Array = fx_run.call(fx_nt)
	_sr("the audit's fixes on the log: PRIYA built %s; fought %s; again %s; without the totals %s" % [str(fxa[0]).substr(0, 160), JSON.stringify(fxa[1].map(func(fx_x): return [fx_x[0], fx_x[1], fx_x[2]])), "identical" if fxa == fxb else "DIFFERENT", "different" if fxa[1] != fxc[1] and fxa[0] != fxc[0] else "THE SAME"],
		fxa == fxb and fxa[1] != fxc[1] and fxa[0] != fxc[0] and fxa[1].size() == 1, "%d spar" % fxa[1].size())
	# PAC-097: the faucet/sink audit, reduced (its sample one spar - the audit's PRIYA against Alfie Crane - and Arc 1's first phase):
	# measured, paid and judged twice alike to the last number and the spar's hash; a phase one episode longer pays differently
	var fs_F: Dictionary = content["faucets"]
	var fs_run := func(fs_eps: int) -> Array:
		var fs_Fx: Dictionary = fs_F.duplicate(true); fs_Fx["phases"] = [fs_Fx["phases"][0]]; fs_Fx["phases"][0]["episodes"] = fs_eps
		var fs_rep: Dictionary = TNBFaucets.run(content, fs_Fx, content["audit"], {"sample": {"fighters": ["PRIYA"], "bosses": ["alfie_crane"], "seeds": [11]}})
		return [JSON.stringify([fs_rep["faucet"]["paid"], fs_rep["faucet"]["counts"], fs_rep["sinks"]["want"], fs_rep["fails"].keys(), fs_rep["share"]]), fs_rep["sample"]["fights"].map(func(fs_f): return [fs_f["boss"], fs_f["won"], fs_f["xp"], fs_f["hash"]]), int(fs_rep["faucet"]["hash"])]
	var fsa: Array = fs_run.call(6); var fsb: Array = fs_run.call(6); var fsc: Array = fs_run.call(7)
	_sr("the faucet/sink audit, reduced: the sample %s; Arc 1's first phase paid %s; again %s; a phase one episode longer %s" % [JSON.stringify(fsa[1].map(func(fs_x): return [fs_x[0], fs_x[1], fs_x[2]])), str(fsa[0]).substr(0, 140), "identical" if fsa == fsb else "DIFFERENT", "different" if fsa[0] != fsc[0] and fsa[2] != fsc[2] else "THE SAME"],
		fsa == fsb and fsa[0] != fsc[0] and fsa[2] != fsc[2] and fsa[1] == fsc[1] and fsa[1].size() == 1, "%d spar" % fsa[1].size())
	# PAC-098: the scouting machine on the delegated log - between duals the aid feeds the machine on the Prestige the club holds and
	# signs the open mat's first; identical twice, and different from the same log without the machine
	var sc_log: Array = log_auto.map(func(sc_e): return (sc_e as Dictionary).merged({"scout": 12, "sign": "*"}))
	var sc_run := func(sc_on: bool) -> Array:
		var sc_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_purse({}, "prestige:130"))
		sc_s.delegate_all = true; sc_s.events.clear(); sc_s.new_dual()
		return [sc_s, run_log(sc_s, sc_log if sc_on else log_auto, 60)]
	var sca: Array = sc_run.call(true); var scb: Array = sc_run.call(true); var scc: Array = sc_run.call(false)
	var sc_q: Dictionary = sca[0].rewards.get("scouting", {})
	_sr("the scouting machine on the delegated log vs Yuri's squad: %d pulls (%d rare: %s), %d signed from the open mat (the stable %d), Prestige left %d; without the machine none; every hash identical twice and different from it" % [int(sc_q.get("pulls", 0)), sc_q.get("leads", []).filter(func(sc_l): return bool(sc_l["rare"])).size(), JSON.stringify(sc_q.get("leads", []).filter(func(sc_l2): return bool(sc_l2["rare"])).map(func(sc_l3): return str(sc_l3["label"]))), count_events(sca[0].events, "signed"), sca[0].stable.size(), int(sca[0].rewards["prestige"])],
		int(sc_q.get("pulls", 0)) >= 10 and count_events(sca[0].events, "signed") >= 1 and scc[0].rewards.get("scouting", {}).is_empty() and sca[1] == scb[1] and sca[1].size() > 0 and sca[1] != scc[1], "%d hashes" % sca[1].size())
	# PAC-099: the stable roles on the delegated log - between duals the aid trains a slot, pulls three, signs them off the open mat (the
	# priority) and turns a day; with the roles it also sets the bench to work: identical twice, and different from the same log without
	var rl_log: Array = log_auto.map(func(rl_e0): return (rl_e0 as Dictionary).merged({"scout": 3, "sign": 3, "train": 0.5, "day": 1}))
	var rl_run := func(rl_on: bool) -> Array:
		var rl_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_facilities(TNBSim.seed_purse({}, "prestige:130"), "bags_mitts:1", content["facilities"]))
		rl_s.delegate_all = true; rl_s.events.clear(); rl_s.new_dual()
		return [rl_s, run_log(rl_s, rl_log.map(func(rl_e): return (rl_e as Dictionary).merged({"role": 3})) if rl_on else rl_log, 60)]
	var rla: Array = rl_run.call(true); var rlb: Array = rl_run.call(true); var rlc: Array = rl_run.call(false)
	var rl_q: Dictionary = rla[0].rewards.get("roles", {})
	_sr("the stable roles on the delegated log vs Yuri's squad: %d signed, the bench set %s, the roles paid %s by day %d; without the roles none set; every hash identical twice and different from it" % [count_events(rla[0].events, "signed"), JSON.stringify(rl_q.get("of", {})), JSON.stringify(rl_q.get("paid", {})), int(rla[0].rewards.get("day", 1))],
		count_events(rla[0].events, "role_set") >= 3 and rl_q.get("of", {}).size() == count_events(rla[0].events, "role_set") and int(rl_q.get("paid", {}).get("prestige", 0)) > 0 and rlc[0].rewards.get("roles", {}).is_empty() and count_events(rlc[0].events, "signed") >= 3 \
		and rla[1] == rlb[1] and rla[1].size() > 0 and rla[1] != rlc[1], "%d hashes" % rla[1].size())
	# PAC-100: the locker room on the delegated log - between duals the aid pulls three, signs them and turns a day; with the locker it also
	# releases the bench's last each visit: identical twice, and different from the same log without the releases
	var lk_log: Array = log_auto.map(func(lk_e0): return (lk_e0 as Dictionary).merged({"scout": 3, "sign": 3, "day": 1}))
	var lk_run := func(lk_on: bool) -> Array:
		var lk_s := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, TNBSim.seed_purse({}, "prestige:130"))
		lk_s.delegate_all = true; lk_s.events.clear(); lk_s.new_dual()
		return [lk_s, run_log(lk_s, lk_log.map(func(lk_e): return (lk_e as Dictionary).merged({"release": 1})) if lk_on else lk_log, 60)]
	var lka: Array = lk_run.call(true); var lkb: Array = lk_run.call(true); var lkc: Array = lk_run.call(false)
	var lk_q: Dictionary = lka[0].rewards.get("locker", {})
	_sr("the locker room on the delegated log vs Yuri's squad: %d signed, %d released (%s), waiting %s by day %d, the stable %d against %d without; every hash identical twice and different from it" % [count_events(lka[0].events, "signed"), count_events(lka[0].events, "released"), JSON.stringify(lk_q.get("memory", {}).keys()), JSON.stringify(lk_q.get("pending", {}).keys()), int(lka[0].rewards.get("day", 1)), lka[0].stable.size(), lkc[0].stable.size()],
		count_events(lka[0].events, "released") >= 1 and lka[0].stable.size() < lkc[0].stable.size() and lkc[0].rewards.get("locker", {}).is_empty() and lka[1] == lkb[1] and lka[1].size() > 0 and lka[1] != lkc[1], "%d hashes" % lka[1].size())
	var gwa: Array = gw_run.call(false); var gwb: Array = gw_run.call(false); var gwd: Array = gw_run.call(true)
	var gwh := make_sim(1, 12345); gwh.seal_board({"slots": ["RORY", "MARCUS", "PRIYA"]}); gwh.delegate_all = true; gwh.new_dual()
	var hgwh := run_log(gwh, log_auto, 60)
	var gw_out: Array = []
	for gw_e in gwa[0].events:
		if str(gw_e["kind"]) == "delegated": gw_out.append(str(gw_e["who"]))
	_sr("the Gym Wall's board on the delegated log vs Yuri's squad: sealed %s (%s), out on the log %s (%d swaps from the log's corner), the wall at the log's end %s; every hash identical twice and different from the card order's run; the same order sealed by hand, and the wall rearranged and decorated, hash the same" % [JSON.stringify(gwa[0].sealed_p), str(gwa[0].board.get("archetype", "")), JSON.stringify(gw_out.slice(0, 3)), count_events(gwa[0].events, "corner_action", {"action": "swap"}), JSON.stringify(gwa[0].gym_wall["decos"].map(func(d): return str(d["label"])))],
		gwa[0].sealed_p == ["RORY", "MARCUS", "PRIYA"] and str(gwa[0].board.get("archetype", "")) == "GYM_WALL" and gwa[1] == gwb[1] and gwa[1].size() > 0 and gwa[1] != hda and hgwh == gwa[1] and gwd[1] == gwa[1] and gwd[0].gym_wall["decos"].size() == gwa[0].gym_wall["decos"].size() + 3, "%d hashes" % gwa[1].size())
	# a scrap on the profile: the objective judged from events, twice, identically
	var sc_a := make_sim(1, 2024); sc_a.start_scrap("SCR-06", 1); sc_a.delegate_all = true; sc_a.new_dual(); sc_a.events.clear()
	var hsa: Array = []
	for i in 3700:
		sc_a.step({})
		if i % 50 == 0: hsa.append(sc_a.hash_state())
	var sc_b := make_sim(1, 2024); sc_b.start_scrap("SCR-06", 1); sc_b.delegate_all = true; sc_b.new_dual()
	var hsb: Array = []
	for i in 3700:
		sc_b.step({})
		if i % 50 == 0: hsb.append(sc_b.hash_state())
	# PAC-102: the anti-you on the delegated log vs Moira's squad (the win flags four) - between duals the aid approaches the flagged, the arc turns (story:nationals) and the
	# academy is fielded with its signings for the duals after: identical twice, and different from the same log without the arc's turn
	var ay_log: Array = log_auto.map(func(ay_e0): return (ay_e0 as Dictionary).merged({"approach": "*", "academy": true}))
	var ay_run := func(ay_on: bool) -> Array:
		var ay_s := make_sim(19, 12345)                                                                    # Moira's squad: the log wins that dual on segments (PAC-075)
		ay_s.delegate_all = true; ay_s.events.clear(); ay_s.new_dual()
		return [ay_s, run_log(ay_s, ay_log.map(func(ay_e): return (ay_e as Dictionary).merged({"story": "story:nationals"})) if ay_on else ay_log, 60)]
	var aya: Array = ay_run.call(true); var ayb: Array = ay_run.call(true); var ayc: Array = ay_run.call(false)
	_sr("the anti-you on the delegated log vs Moira's squad: the academy signed %s at the Nationals and fielded them %s; without the arc's turn nobody signed, the academy unfielded; every hash identical twice and different from it" % [JSON.stringify(aya[0].rewards.get("academy", {}).get("order", [])), str(aya[0].academy_on)],
		count_events(aya[0].events, "academy_signs") == 1 and aya[0].rewards.get("academy", {}).get("order", []).size() >= 1 and ayc[0].rewards.get("academy", {}).is_empty() and not ayc[0].academy_on and aya[1] == ayb[1] and aya[1].size() > 0 and aya[1] != ayc[1], "%d hashes" % aya[1].size())
	# PAC-101: district rep on the log - a scrap the profile wins against the live Yuri (SCR-15), in the Rink District with 5 on the
	# ledger: won, the rink 6; fled at its 600th tick, the rink 4; placed nowhere, 5 - each twice alike to the hash, the three different
	var rp_run := func(rp_d: String, rp_flee: bool) -> Array:
		var rp_s := make_sim(1, 2024, TNBSim.LINEUP_MILLBROOK, "", {}, {"rep": {"of": {"rink": 5}, "best": {"rink": 5}, "paid": 0}})
		rp_s.start_scrap("SCR-15", 1, "", {}, "", rp_d); rp_s.delegate_all = true; rp_s.new_dual()
		var rp_h: Array = []
		for rp_i in 3700:
			rp_s.step({"flee": true} if rp_flee and rp_i == 600 else {})
			if rp_i % 50 == 0: rp_h.append(rp_s.hash_state())
		return [rp_s.rep_of("rink"), rp_h, rp_s.mode]
	var rpa: Array = rp_run.call("rink", false); var rpb: Array = rp_run.call("rink", false); var rpf: Array = rp_run.call("rink", true); var rpf2: Array = rp_run.call("rink", true); var rpn: Array = rp_run.call("", false)
	_sr("district rep on the log: SCR-15 on the profile in the Rink District - won, the rink %d; fled at tick 600, %d; placed nowhere, %d; each twice alike, the three different" % [int(rpa[0]), int(rpf[0]), int(rpn[0])],
		int(rpa[0]) == 6 and int(rpf[0]) == 4 and int(rpn[0]) == 5 and rpa[1] == rpb[1] and rpf[1] == rpf2[1] and rpa[1] != rpf[1] and rpa[1] != rpn[1] and rpa[1].size() > 0, "%d hashes" % rpa[1].size())
	# PAC-103: the vendor tiers on the log - SCR-15 on the profile with DOWNTOWN at 9 and 600 HBP; won downtown, the rep's 10 opens the t2
	# shelves and the aid's gear between bouts comes off them; placed in the rink, the aid buys off t1. Each twice alike, the two different
	var vd_run := func(vd_d: String) -> Array:
		var vd_s := make_sim(1, 2024, TNBSim.LINEUP_MILLBROOK, "", {}, {"hbp": 600, "rep": {"of": {"downtown": 9}, "best": {"downtown": 9}, "paid": 0}})
		vd_s.start_scrap("SCR-15", 1, "", {}, "", vd_d); vd_s.delegate_all = true; vd_s.new_dual()
		var vd_h: Array = []
		for vd_i in 3700:
			vd_s.step({"gear": "*"} if vd_s.mode == "OVER" else {})
			if vd_i % 50 == 0: vd_h.append(vd_s.hash_state())
		var vd_sh: Array = vd_s.gear_owned().keys().filter(func(vd_id): return str(vd_s.gear_item(str(vd_id)).get("source", "")) == "shop").map(func(vd_id2): return "%s:%s" % [str(vd_id2), str(vd_s.gear_item(str(vd_id2))["shelf"])])
		return [vd_s.rep_of("downtown"), vd_sh, vd_h, int(vd_s.rewards.get("hbp", 0))]
	var vda: Array = vd_run.call("downtown"); var vdb: Array = vd_run.call("downtown"); var vdr: Array = vd_run.call("rink"); var vdr2: Array = vd_run.call("rink")
	_sr("the vendor tiers on the log: SCR-15 won downtown - DOWNTOWN %d, the aid's gear %s (%d HBP left); in the rink %s; each twice alike, the two different" % [int(vda[0]), JSON.stringify(vda[1]), int(vda[3]), JSON.stringify(vdr[1])],
		int(vda[0]) == 10 and vda[1].size() > 0 and vda[1].any(func(vd_x): return str(vd_x).ends_with(":t2")) and vdr[1].size() > 0 and vdr[1].all(func(vd_y): return str(vd_y).ends_with(":t1")) and vda[2] == vdb[2] and vdr[2] == vdr2[2] and vda[2] != vdr[2] and vda[2].size() > 0, "%d hashes" % vda[2].size())
	_sr("a scrap (survive 20s) on the profile against the live Yuri ends %s and hashes identically twice" % ("met" if bool(sc_a.obj.get("met", false)) else ("failed: " + str(sc_a.obj.get("why", ""))) if bool(sc_a.obj.get("failed", false)) else "at the cap"), sc_a.mode == "OVER" and hsa == hsb and hsa.size() > 0, "%d hashes" % hsa.size())
	# Pattern Intel live: the delegated dual again with PI 2 vs Kowalchuk (his tells +10%, the profile reading more) and the ledger ticking as segments end
	var pi_seed: Dictionary = TNBSim.parse_pi_arg("kowalchuk:2", content.get("pattern_intel", {}))
	var pa := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", pi_seed); pa.delegate_all = true; pa.new_dual(); pa.events.clear()
	var hpa := run_log(pa, log_auto, 60)
	var pi_ticks := 0; var pi_cues := 0; var pi_comm := 0
	for e_p in pa.events:
		if e_p["kind"] == "pi_count": pi_ticks += 1
		elif e_p["kind"] == "tell" and bool(e_p.get("cue", false)): pi_cues += 1
		elif e_p["kind"] == "commentary": pi_comm += 1
	var pb := make_sim(1, 12345, TNBSim.LINEUP_MILLBROOK, "", pi_seed); pb.delegate_all = true; pb.new_dual()
	var hpb := run_log(pb, log_auto, 60)
	_sr("the delegated dual with a PI 2 ledger vs Kowalchuk: %d emphasized tells, %d commentary calls, the ledger ticked %d times as segments ended (now %s); every hash identical twice and different from the ledger-less run" % [pi_cues, pi_comm, pi_ticks, JSON.stringify(pa.pi.get("bosses", {}))],
		pi_cues >= 1 and pi_comm >= 1 and pi_ticks >= 1 and hpa == hpb and hpa.size() > 0 and hpa != hda, "%d hashes" % hpa.size())
	# the rematch remix live (NP_04 s6): the same mini log against the remixed Yuri - his feints and his unbreakable strings in the log, hashes identical twice, different from the original
	var ra := make_sim(1, 12345); ra.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); ra.new_dual(); ra.events.clear()
	var hra := run_log(ra, log_, 60)
	var rx_feints := 0; var rx_unbroken := 0; var rx_holds := 0
	for e_r in ra.events:
		if e_r["kind"] == "feint_b": rx_feints += 1
		elif e_r["kind"] == "unbroken": rx_unbroken += 1
		elif e_r["kind"] == "tell" and str(e_r.get("variant", "")) != "": rx_holds += 1
	var rb := make_sim(1, 12345); rb.set_remix("yuri_kowalchuk", "yuri_kowalchuk.rematch"); rb.new_dual()
	var hrb := run_log(rb, log_, 60)
	_sr("the log against the remixed Yuri: %d feint variants told, %d of them carried through (the hitch), %d hits taken in a tell that does not break; every hash identical twice and different from the original's run" % [rx_holds, rx_feints, rx_unbroken],
		rx_holds >= 1 and rx_feints >= 1 and rx_unbroken >= 1 and hra == hrb and hra.size() > 0 and hra != ha, "%d hashes" % hra.size())
	# the phase scripts live (NP_04B): Vasile's clock kits through a delegated dual - hashes identical twice. Since PAC-071 his measured stance is live:
	# in this log it knocks RORY out at 63.5s, the 60s turn's clock stopped twice by counts, so the live run proves one turn and its seam, and the same log
	# with his neutral game frozen (the pre-PAC-071 path) proves both. Since PAC-086 his authored Zone stays unrun on these four runs: the gate watches
	# his clock kits, bit for bit as before; his Zone on a log is its own gate above
	var q_kit := func(q_sim: TNBSim) -> Array:
		var q_sw := 0; var q_se := 0; var q_di := 0
		for e_v in q_sim.events:
			if e_v["kind"] == "kit_swap": q_sw += 1
			elif e_v["kind"] == "neutral_reset": q_se += 1
			elif e_v["kind"] == "directive" and bool(e_v.get("executed", false)): q_di += 1
		return [q_sw, q_se, q_di]
	var vs_corner := {"staff": ["sportsmed", "janitor", "rival_cornerman"]}                          # since PAC-074: a corner with no conditioning coach, so RORY's R1 is the pre-PAC-074 fight bit for bit (the gate watches his clock, not our corner)
	var va := make_sim(16, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, {}, vs_corner); va.delegate_all = true; va.btransform_on = false; va.new_dual(); va.events.clear()
	var hva := run_log(va, log_auto, 60)
	var vb := make_sim(16, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, {}, vs_corner); vb.delegate_all = true; vb.btransform_on = false; vb.new_dual()
	var hvb := run_log(vb, log_auto, 60)
	var vf := make_sim(16, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, {}, vs_corner); vf.delegate_all = true; vf.btransform_on = false; vf.new_dual(); vf.neutral_on = false; vf.events.clear()
	var hvf := run_log(vf, log_auto, 60)
	var vg := make_sim(16, 12345, TNBSim.LINEUP_MILLBROOK, "", {}, {}, vs_corner); vg.delegate_all = true; vg.btransform_on = false; vg.new_dual(); vg.neutral_on = false
	var hvg := run_log(vg, log_auto, 60)
	var q_live: Array = q_kit.call(va); var q_frz: Array = q_kit.call(vf)
	var q_ko := ""
	for e_v in va.events:
		if e_v["kind"] == "seg_end" and q_ko == "": q_ko = "%s at %.1fs" % [str(e_v.get("why", "")), float(int(e_v["tick"])) / 120.0]
	_sr("the delegated dual vs Vasile on his neutral game: his clock kits turn %d times with %d seams and %d phase lines before R1 ends (%s); with his neutral game frozen the same log turns %d times with %d seams and %d lines; each run's hashes identical twice" % [int(q_live[0]), int(q_live[1]), int(q_live[2]), q_ko, int(q_frz[0]), int(q_frz[1]), int(q_frz[2])],
		int(q_live[0]) >= 1 and int(q_live[1]) >= 1 and int(q_live[2]) >= 2 and int(q_frz[0]) >= 2 and int(q_frz[1]) >= 2 and int(q_frz[2]) >= 4 and hva == hvb and hvf == hvg and hva.size() > 0 and hva != hvf, "%d hashes" % hva.size())
	# PI transfer live (NP_04A s8): the delegated dual vs Vey with the three copied houses at PI 2 - the commentary and the half-width cue arrive with each kit; hashes identical twice
	var tr_seed: Dictionary = TNBSim.parse_pi_arg("tremblay:2,okafor:2,kowalchuk:2", content.get("pattern_intel", {}))
	var ta := make_sim(6, 12345, TNBSim.LINEUP_MILLBROOK, "", tr_seed); ta.delegate_all = true; ta.new_dual(); ta.events.clear()
	var hta := run_log(ta, log_auto, 60)
	var tr_comm := 0; var tr_cues := 0; var tr_swaps := 0
	for e_t in ta.events:
		if e_t["kind"] == "commentary": tr_comm += 1
		elif e_t["kind"] == "tell" and bool(e_t.get("cue", false)): tr_cues += 1
		elif e_t["kind"] == "kit_swap": tr_swaps += 1
	var tb := make_sim(6, 12345, TNBSim.LINEUP_MILLBROOK, "", tr_seed); tb.delegate_all = true; tb.new_dual()
	var htb := run_log(tb, log_auto, 60)
	_sr("the delegated dual vs Vey with Tremblay / Okafor / Kowalchuk PI at 2: %d commentary calls, %d cued tells, %d kit turns; every hash identical twice" % [tr_comm, tr_cues, tr_swaps],
		tr_comm >= 1 and tr_cues >= 1 and hta == htb and hta.size() > 0, "%d hashes" % hta.size())
	return _verdict("DETERMINISM")

# --------------------------------------------------------------- GEOMETRY ----
const FAMS := ["STRAIGHT", "FLARED", "HOOK", "HOOKERCUT", "UPPERCUT"]
# dodge label -> [kind, dir relative to the ATTACKING hand: +1 = into it, -1 = away]
const DODGES := {"none": ["", 0], "slip-away": ["SLIP", -1], "slip-into": ["SLIP", 1], "duck": ["DUCK", 1],
	"lean": ["LEAN", 1], "weave-into": ["WEAVE", 1], "weave-away": ["WEAVE", -1]}
# the boxing consensus (NP_14 C2) as a table; H = hit, . = miss. Inside spacing 1.55m.
const EXPECT_INSIDE := {
	"none":       ["H", "H", "H", "H", "H"],
	"slip-away":  [".", ".", ".", ".", "."],
	"slip-into":  [".", ".", "H", "H", "."],
	"duck":       [".", "H", ".", ".", "H"],
	"lean":       ["H", "H", "H", "H", "."],
	"weave-into": [".", ".", ".", "H", "."],
	"weave-away": [".", ".", ".", ".", "."],
}
# at range (1.80m) the lean-back beats everything; neutral still eats all but the uppercut
const EXPECT_RANGE := {"none": ["H", "H", "H", "H", "."], "lean": [".", ".", ".", ".", "."]}

func cell(s: TNBSim, A: Dictionary, D: Dictionary, spacing: float, hand: String, fam: String, dodge: String, body: bool = false) -> String:
	A["pos"] = Vector2(0, 0); D["pos"] = Vector2(0, spacing)
	clear_defense(D)
	var dd: Array = DODGES[dodge]
	if dd[0] != "":
		# "into" the attacking hand: for a right hand the head moves to the DEFENDER's left (dir -1)
		var dir: int = dd[1] * (-1 if hand == "R" else 1)
		D["dodge"] = dd[0]; D["dodge_dir"] = dir; D["dodge_t"] = 10
	var r := s.resolve_geometry(A, D, hand + "_" + fam, body)
	return "H" if r == "HIT" else "."

func geometry() -> int:
	print("GEOMETRY :: C2/C6 - emergent dodge table vs boxing consensus, both fighters, both hands")
	var s := make_sim(0, 1)
	s.P["pkg"] = {}; s.B["pkg"] = {}     # the table is the bare geometry; the style packages (NP_06 s1.2) scale reach and the weave and are gated in the smoke
	var bad := 0
	for direction in [["boss->player", s.B, s.P], ["player->boss", s.P, s.B]]:
		for hand in ["R", "L"]:
			print("  %s  %s hand  inside 1.55m        STR FLA HOK HKC UPC" % [direction[0], hand])
			for dodge in EXPECT_INSIDE:
				var row := ""; var ok := true
				for i in FAMS.size():
					var got := cell(s, direction[1], direction[2], 1.55, hand, FAMS[i], dodge)
					row += "  " + got + " "
					if got != EXPECT_INSIDE[dodge][i]: ok = false; bad += 1
				print("     %-12s %s %s" % [dodge, row, "" if ok else "   <-- MISMATCH"])
			for dodge in EXPECT_RANGE:
				var row := ""; var ok := true
				for i in FAMS.size():
					var got := cell(s, direction[1], direction[2], 1.80, hand, FAMS[i], dodge)
					row += "  " + got + " "
					if got != EXPECT_RANGE[dodge][i]: ok = false; bad += 1
				print("     %-12s %s %s" % [dodge + "@1.80", row, "" if ok else "   <-- MISMATCH"])
	_sr("C2 emergent table matches the boxing consensus (35 + 10 cells)", bad == 0, "%d mismatches" % bad)
	_sr("C6 identical table in both directions and for both hands", bad == 0)
	# body shots: the slip barely moves the torso; the duck does not lower it
	var body_ok := cell(s, s.P, s.B, 1.55, "R", "STRAIGHT", "slip-away", true) == "H" \
		and cell(s, s.P, s.B, 1.55, "R", "HOOK", "duck", true) == "H" \
		and cell(s, s.P, s.B, 1.80, "R", "STRAIGHT", "lean", true) == "."
	_sr("C2 body shots land through slips and ducks; only distance answers them", body_ok)
	# the boss's read chooses a geometrically valid evasion for every head punch
	var read_bad := 0
	for row in ["L_STRAIGHT", "R_STRAIGHT", "L_FLARED", "R_FLARED", "L_HOOK", "R_HOOK", "L_HOOKERCUT", "R_HOOKERCUT", "L_UPPERCUT", "R_UPPERCUT"]:
		for k in 40:
			var cd := s._correct_dodge_for(row, false)
			s.P["pos"] = Vector2(0, 0); s.B["pos"] = Vector2(0, 1.55)
			clear_defense(s.B); s.B["dodge"] = cd[0]; s.B["dodge_dir"] = cd[1]; s.B["dodge_t"] = 10
			if s.resolve_geometry(s.P, s.B, row, false) == "HIT": read_bad += 1
	_sr("C6 every boss read is a geometrically valid evasion (10 rows x 40 draws)", read_bad == 0, "%d reads would eat the punch" % read_bad)
	# scheduled read: the dodge is live on the impact tick for every startup
	var timing_bad := 0
	for row in ["L_STRAIGHT", "R_HOOK", "R_UPPERCUT", "R_HOOKERCUT"]:
		var t := make_sim(0, 99)
		freeze_boss(t); place(t, 1.6)
		t.P["busy_t"] = 0; t.P["cmd"] = {}
		t.step({"punch": row})
		t.B["dodge_plan"] = ["SLIP", 1]; t.B["dodge_at"] = maxi(1, t.P["pending"]["t"] - 15); t.B["blocking"] = false
		while t.P["pending"].size() > 0 and t.B["dodge_at"] > 0: t.step({})
		var live_at_impact := true
		while t.P["pending"].size() > 0:
			if t.B["dodge"] == "": live_at_impact = false
			t.step({})
		if not live_at_impact: timing_bad += 1
	_sr("C6 a scheduled read is live on the impact tick (jab..haymaker startups)", timing_bad == 0)
	return _verdict("GEOMETRY")

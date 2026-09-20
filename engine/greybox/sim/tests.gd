extends RefCounted
const TNBSim := preload("res://sim/core.gd")
const TNBClock := preload("res://sim/clock.gd")
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

func make_sim(boss_idx: int, seed_v: int, lineup: Array = TNBSim.LINEUP_MILLBROOK) -> TNBSim:
	if content.is_empty(): content = TNBSim.load_content()
	var s := TNBSim.new()
	s.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, seed_v, content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []))
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
	var t := make_sim(boss_idx, seed_v, lu); quiet(t); place(t, 1.4); t.tension = 100.0
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
	# push the boss under his desperation trigger and let one agent tick arm it
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
	s.hooks_enabled = false; freeze_boss(s); thaw(s); s.events.clear()

func run(mode: String, boss_idx: int) -> int:
	match mode:
		"smoke": return smoke(boss_idx)
		"determinism": return determinism()
		"geometry": return geometry()
	print("unknown test mode: " + mode)
	return 2

# ---------------------------------------------------------------- helpers ----
func freeze_boss(s: TNBSim) -> void:
	s.bstate = "IDLE"; s.btimer = 1 << 30; s.bqueue = []; s.bpending = {}
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

	# ---- interrupt ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}
	s.bstate = "TELL"; s.bstring = s.pattern["strings"].keys()[0]; s.btimer = 1 << 30
	var comp_before: float = s.B["comp"]
	throw_clean(s, "R_STRAIGHT")
	_sr("interrupt breaks the tell", s.bstate != "TELL", "state=" + s.bstate)
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

	# ---- drops ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}
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
	s.mode = "FIGHT"; s.eight = {}
	s.contributed = 30.0; s.tension = 42.0
	s._end_segment("smoke-forced")
	_sr("segment end shows the 4s broadcast card first", s.mode == "CARD" and s.card_t == TNBSim.ms(4000) and count_events(s.events, "seg_card") >= 1)
	_sr("relay CHARGED at >=25 contributed (chain 1)", s.charged and s.relay_chain == 1)
	run_ticks(s, TNBSim.ms(4000) - 1)
	var still_card: bool = s.mode == "CARD"
	s.step({})
	_sr("the card times out into the CORNER (45s, 2 actions)", still_card and s.mode == "CORNER" and int(s.corner["t"]) == TNBSim.ms(45000) and int(s.corner["actions_left"]) == 2)
	s.step({"corner": 1})
	_sr("send: rotation loads the next fighter", s.pname() == "PRIYA", s.pname())
	_sr("tension persists across segments", s.tension == 42.0, "%.0f" % s.tension)
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
	var t5c := make_sim(22, 7); thaw(t5c); place(t5c); t5c.events.clear(); t5c.bphase = 2; t5c.bstate = "IDLE"; t5c.btimer = 1
	run_ticks(t5c, TNBSim.ms(20000))
	_sr("sensor reacts_to_fake_tell: phase 2 retires the borrowed clothes (0 fakes in 20s)", count_events(t5c.events, "tell", {"fake": true}) == 0)
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
	cast_player(ns); resolve_cast(ns)
	var ns_d := hit_dmg(ns, "B")
	var v_expect := 15.0 * (45.0 / 50.0) * (1.6 + 0.8 * 2.0) * ns.hiss_mult("P")
	_sr("T3 needs the CHARGED unlock; North Star scales with the relay chain (base 1.6 + 0.8 x 2 links)", v_locked and absf(ns_d - v_expect) < 0.05, "%.2f vs %.2f" % [ns_d, v_expect])
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
	var cb := make_sim(0, 7); quiet(cb); to_corner.call(cb, 0.0); cb.tension = 60.0
	var a1 := cb.corner_action({"kind": "save_bar"})
	var a2 := cb.corner_action({"kind": "staff", "id": "raise_the_roof"})
	var a3 := cb.corner_action({"kind": "tactic", "id": "body_doctrine"})
	_sr("corner budget: two actions land, the third is refused; Raise the Roof paid +8 Tension", a1 and a2 and not a3 and count_events(cb.events, "corner_refused", {"why": "no actions left"}) == 1 and absf(cb.tension - 68.0) < 0.01)
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
	_sr("save the bar: the cast is refused next segment; winning it anyway banks +5", locked and absf(cv.tension - 55.0) < 0.01, "%.0f" % cv.tension)
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
	var lu3: Array = TNBSim.LINEUP_MILLBROOK.duplicate(true); lu3[1]["hissatsu"] = "Relay: North Star"
	var ca := make_sim(0, 7, lu3); quiet(ca)
	ca.mode = "FIGHT"; ca.contributed = 30.0; ca._end_segment("smoke-forced"); next_segment(ca)
	quiet(ca); place(ca, 1.4); ca.tension = 100.0; ca.events.clear()
	ca.P["busy_t"] = 0; ca.P["cmd"] = {}; ca.step({"punch": "R_UPPERCUT", "lb": true})
	var ghost := ""
	for e in ca.events:
		if e["kind"] == "cast": ghost = str(e["afterimage"])
	_sr("afterimage: PRIYA's T3 cast in R2 carries RORY as the spirit afterimage (T3 unlocked by the CHARGED entrance)", ca.cast.size() > 0 and ghost == "RORY")
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
			answered = s.bstate == "TELL" and s.bstring == plan["string"] and s.btimer < full_t \
				and s.btimer == maxi(1, int(full_t * float(plan["scale"])))
			detail = "%s -> %s tell %d/%d ticks (x%.2f)" % [pu["trigger"], s.bstring, s.btimer, full_t, float(plan["scale"])]
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
			bait_full = baited and s.btimer == TNBSim.ms(float(s.pattern["strings"][s.bstring]["tell"]["ms"]))
			break
		elif b.has("authored_absent"):
			baited = true; bait_full = true
			break
	_sr("bait hook answers (or authored-absent)", baited)
	_sr("baited string comes at full tell", bait_full)
	return _verdict("SMOKE")

# ------------------------------------------------------------ DETERMINISM ----
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
	var log_ := build_log(N, 777)
	var a := make_sim(1, 12345); a.events.clear()
	var ha := run_log(a, log_, 60)
	var cov := {"hit_B": 0, "hit_P": 0, "counter": 0, "flash": 0, "drop": 0, "eight": 0, "seg_end": 0, "tell": 0, "evade": 0, "block": 0, "interrupt": 0, "clinch": 0, "sprint": 0, "sensor": 0, "foul": 0, "pulled": 0, "survival_grab": 0, "cast_P": 0, "cast_B": 0, "cast_hit": 0, "cast_interrupted": 0, "feint": 0, "feint_drawn": 0, "corner_action": 0, "seg_card": 0, "matchup": 0, "matchup_adv": 0}
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

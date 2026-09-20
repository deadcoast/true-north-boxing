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
	s.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, seed_v, content.get("library", {}))
	return s

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
	_sr("third drop = SEGMENT KO (+1 +3), segment ends, dual continues", s.B["drops"] == 3 and s.score_p == 7 and s.mode == "CORNER" and s.seg_idx == seg0,
		"score %d-%d mode=%s" % [s.score_p, s.score_b, s.mode])
	s.step({"corner": 1})
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

	# ---- hissatsu ----
	place(s); freeze_boss(s); s.tokens = []; s.flags = {}; s.freeze_t = 0
	s.tension = 100.0; s.B["comp"] = s.B["comp_max"]; s.P["counter_t"] = 0
	var dpre := s.drops_p
	thaw(s); s.P["busy_t"] = 0; s.P["cmd"] = {}
	s.step({"punch": "R_HOOKERCUT", "lb": true})
	var was_hiss: bool = s.P["pending"].get("hissatsu", false)
	clear_defense(s.B); land(s)
	var expect := 10.0 if s.drops_p > dpre else 0.0
	_sr("hissatsu arms at 100 tension (LB + haymaker)", was_hiss)
	_sr("hissatsu bar = cast zero + drop bonus only", s.tension == expect, "%.0f (expected %.0f)" % [s.tension, expect])
	s.freeze_t = 0

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

	# ---- dual layer ----
	s.mode = "FIGHT"; s.eight = {}
	s.contributed = 30.0; s.tension = 42.0
	s._end_segment("smoke-forced")
	_sr("segment end enters CORNER", s.mode == "CORNER")
	_sr("relay CHARGED at >=25 contributed", s.charged)
	s.step({"corner": 1})
	_sr("rotation loads the next fighter", s.pname() == "PRIYA", s.pname())
	_sr("tension persists across segments", s.tension == 42.0, "%.0f" % s.tension)
	_sr("CHARGED entrance: surge + hissatsu at 50", s.P["charge_t"] > 0 and s.hiss_threshold == 50.0)
	s.contributed = 0.0
	s._end_segment("smoke-forced")
	_sr("no relay under 25 contributed", not s.charged)
	s.step({"corner": 2})
	_sr("seg3 loads MARCUS (rested)", s.pname() == "MARCUS" and s.P["stamina"] > 100.0, "%s stam=%.0f" % [s.pname(), s.P["stamina"]])
	s.score_p = 2; s.score_b = 1; s.ep_p = 40; s.ep_b = 22
	s._end_segment("smoke-forced")
	_sr("dual verdict on score after 3 segments", s.mode == "OVER" and "MILLBROOK WINS" in s.feed)
	s.new_dual()
	_sr("new dual resets to R1", s.mode == "FIGHT" and s.seg_idx == 0 and s.drops_p == 0)

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
	place(s); clear_defense(s.P); s.P["comp"] = s.P["comp_max"]; s.P["counter_t"] = 0
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
	var bx0: Vector2 = t13.B["pos"]
	while t13.clinch.size() > 0:
		if absi(int(t13.clinch["timer_t"])) <= int(t13.clinch["window_t"]) and not t13.clinch["rise_prev"]:
			t13.step({"rise": true})
		else:
			t13.step({"rise": false})
	var won_pos: bool = count_events(t13.events, "clinch_end", {"winner": "P"}) == 1 and t13.B["pos"] != bx0
	var t13b := make_sim(0, 7); quiet(t13b); place(t13b, 1.0); t13b.P["stamina"] = 50.0
	t13b.step({"clinch": true})
	while t13b.clinch.size() > 0:
		var on_cue: bool = absi(int(t13b.clinch["timer_t"])) <= int(t13b.clinch["window_t"]) and not t13b.clinch["rise_prev"]
		t13b.step({"rise": on_cue, "body": true})
	var won_reset: bool = count_events(t13b.events, "clinch_end", {"winner": "P", "reset": true}) == 1 and t13b.P["stamina"] > 54.0
	_sr("clinch scramble: beats on the RFX cue win position (he is walked ropeward) or a reset (+5 stamina)", began and won_pos and won_reset)
	var t13c := make_sim(0, 7); quiet(t13c); place(t13c, 1.0)
	t13c.step({"clinch": true}); run_ticks(t13c, t13c.clinch_t + 2)
	_sr("clinch scramble: no taps loses it (dragged ropeward)", count_events(t13c.events, "clinch_end", {"winner": "B"}) == 1)

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
		var inp := {"move": mv, "block": block, "lb": lb, "rise": (i % 20) < 10, "corner": 1 + (i % 2), "restart": true}
		if r.randf() < 0.025: inp["punch"] = ROWS[r.randi_range(0, ROWS.size() - 1)]
		if r.randf() < 0.03: inp["dodge"] = DODGES[r.randi_range(0, DODGES.size() - 1)]
		if r.randf() < 0.05: inp["power"] = true
		if r.randf() < 0.05: inp["body"] = true
		if r.randf() < 0.002: inp["taunt"] = true
		if r.randf() < 0.003: inp["sprint"] = true
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
	var cov := {"hit_B": 0, "hit_P": 0, "counter": 0, "flash": 0, "drop": 0, "eight": 0, "seg_end": 0, "tell": 0, "evade": 0, "block": 0, "interrupt": 0, "clinch": 0, "sprint": 0, "sensor": 0}
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
	var duals := 0
	for e in a.events:
		if e["kind"] == "dual_end": duals += 1
	print("  coverage: " + JSON.stringify(cov) + "  duals completed=%d  final mode=%s seg=%d drops %d-%d" % [duals, a.mode, a.seg_idx, a.drops_p, a.drops_b])
	_sr("log exercises both offenses", cov["hit_B"] > 0 and cov["hit_P"] > 0)
	_sr("log exercises hitstop + slow-time (C5 paths)", cov["counter"] > 0 and cov["interrupt"] > 0)
	_sr("log exercises drops / standing-eight / segment end", cov["drop"] > 0 and cov["eight"] > 0 and cov["seg_end"] > 0)
	_sr("log exercises geometric evasion + guard", cov["evade"] > 0 and cov["block"] > 0)
	_sr("log exercises clinch scrambles, sprint-steps and sensors", cov["clinch"] > 0 and cov["sprint"] > 0 and cov["sensor"] > 0)
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

extends RefCounted
# Loaded by preload("res://sim/exhibition.gd") - no class_name (the sim's rule: headless runs never touch the editor's class cache).
# TNBExhibition - NP_01 s8's Exhibition 2v2: two fighters per side in the ring at once, one segment - festival content, the only
# simultaneous format, the duo hissatsu showcase (NP_05 s7: "true simultaneous duo moves - both players input the motion within 500 ms").
# PAC-088. The sim (core.gd) is one fighter against one boss everywhere - P and B - and C6 keeps one resolution function; a four-body
# sim would mean re-plumbing every rule in it. So the exhibition runs TWO engagements in lockstep, one per pair - A (the first card
# against the boss asked for) and B (his partner against the enemy's second) - each a whole TNBSim on the exhibition_2v2 format, and
# this coordinator owns what the pairs share:
#   - the ledger (one reward ledger, one Pattern Intel ledger: the same dictionaries in both);
#   - the bars (NP_05 s1: one meter per team - each tick the two engagements' changes are summed into the team's bar and written back;
#     the enemy's the same; the building's crowd heat the same);
#   - the ring clock (the one bell: it runs while either pair fights - a pair in its own hitstop or count is carried with it);
#   - the duo sync (NP_05 s7): the library's festival moves (duo_variant "sync_<sync_ms>ms") by family - LB + the uppercut flick
#     (RISE: Double Overtime), LB + block held 400 ms (WALL: Two-Hand Winter). The first motion opens a window of the format's sync_ms;
#     the second fighter's same motion inside it casts the move in BOTH engagements (the bar pays once; each half carries half the
#     price for an interrupt's refund); an AI partner answers at partner_answer_ms; unanswered, the held motion executes as it would
#     have (the flick, or the fighter's own WALL). Live from the pair's Kizuna level whose effect carries "exhibition_duo" (Lv4 Duo);
#   - Two-Hand Winter's gauge: "the only shared gauge in the game" - one wall dictionary linked into both engagements' P side, its
#     clocks run by the pair that raised it;
#   - the verdict: when both engagements are over (the clock, or a KO - a pair KO'd is finished, the other fights on), NP_01 s3.3's
#     ladder on the pairs' sums - score, segment wins, counter hits - and a tie is a DRAW (no Golden DROP in a festival); it pays
#     once, as a dual (NP_11 s6): both fighters' closing XP, the reserves' none, Spirits and HBP once, the pair's adjacent Kizuna once.
# One pad: the pad plays one engagement (ctrl), the partner plays on his profile (NP_10 s8) unless partner_ai is off (a second pair of
# hands - step_pair's second input); manager mode delegates both, and the profiles call the duo at the format's manager_duo_bar.
const TNBSim := preload("res://sim/core.gd")

var a: TNBSim
var b: TNBSim
var fmt: Dictionary = {}
var ctrl := "A"                     # the engagement the pad plays
var partner_ai := true              # the other plays on his profile; false = a second pair of hands (step_pair's other input)
var manager := false                # both delegated (-- auto / -- demo): the profiles call the duo
var team := 0.0                     # the team bar, shared (NP_05 s1)
var bteam := 0.0                    # the enemy's
var heat := 0.0                     # the building (NP_01 s1)
var window: Dictionary = {}         # the duo sync window: {first, fam, t, held, move}
var hold_t := {"A": 0, "B": 0}      # LB + block held toward a duo wall, per pair
var inject := {"A": {}, "B": {}}    # a held motion released unanswered: the next tick's input for that pair
var thrown := {"A": false, "B": false}   # this tick's duo motions: thrown, not an arm feint (applied after the step - an LB rising this tick resets the sim's own)
var duo_n := 0
var linked := ""                    # the duo wall linked into both engagements (its sync id)
var over := false
var verdict: Dictionary = {}
var events: Array = []
var tick := 0
var venue := "festival"             # PAC-089: where it is fought - the festival's boardwalk, or hosted at the club's gym (The Ring's tier, NP_10 s7)

func setup(content: Dictionary, pair: Array, first_boss: int, seed_v: int, reward_ledger: Dictionary = {}, pi_ledger: Dictionary = {}, fmt_id: String = "exhibition_2v2", manager_on: bool = false, venue_ask: String = "festival") -> void:
	manager = manager_on
	venue = "festival"
	var refused := ""
	if venue_ask == "home":                                                                              # PAC-089: NP_10 s7 - The Ring's tier hosts it at home
		var rt: Dictionary = content.get("facilities", {}).get("tracks", {}).get("the_ring", {})
		var need := int(rt.get("host_tier", 0)); var have := int(reward_ledger.get("facilities", {}).get("the_ring", int(content.get("facilities", {}).get("start_tier", 0))))
		if content.get("facilities", {}).is_empty() or have >= need: venue = "home"
		else: refused = "the Exhibition 2v2 is hosted at The Ring (T%d) - the gym's ring is at T%d: the festival's boardwalk instead" % [need, have]
	var c1: Dictionary = pair[0].duplicate(true); var c2: Dictionary = pair[1].duplicate(true)
	c1.erase("reserve"); c2.erase("reserve")
	a = _mk(content, [c1, c2], first_boss, seed_v, fmt_id, reward_ledger, pi_ledger, "A")
	b = _mk(content, [c2, c1], (first_boss + 1) % TNBSim.BOSSES.size(), seed_v + 1, fmt_id, reward_ledger, pi_ledger, "B")
	b.rewards = a.rewards; b.pi = a.pi                                                                   # one ledger: the same dictionaries
	fmt = a.fmt
	_bars_from(a)
	if refused != "": _ev("hosting_refused", {"why": refused}); a._say("EXHIBITION - " + refused)
	_ev("exhibition", {"label": str(fmt.get("label", "")), "a": [a.pname(), a.boss_name], "b": [b.pname(), b.boss_name], "pair": pair_key(), "level": pair_level(), "duo": duo_ready(), "venue": venue})
	var ln := "EXHIBITION 2v2 %s :: %s vs %s  |  %s vs %s  - one ring, one bell, one bar%s" % ["AT HOME" if venue == "home" else "AT THE FESTIVAL", a.pname(), a.boss_label, b.pname(), b.boss_label, ("  - DUO SYNC live (Lv%d): " % pair_level()) + duo_hint() if duo_ready() else ""]
	a._say(ln); b._say(ln)

func _mk(content: Dictionary, lu: Array, first: int, seed_v: int, fmt_id: String, rl: Dictionary, pl: Dictionary, tag: String) -> TNBSim:
	var s := TNBSim.new()
	s.exhibit = tag; s.delegate_all = _ai(tag); s.host = venue == "home"
	s.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lu, first, seed_v, content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt_id, content.get("bouts", {}), content.get("scraps", {}),
		content.get("pattern_intel", {}), pl, content.get("remixes", {}), content.get("economy", {}), rl, {}, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), {}, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
	return s

func _bars_from(s: TNBSim) -> void:
	team = s.tension; bteam = s.btension; heat = s.crowd_heat
	for x in [a, b]: x.tension = team; x.btension = bteam; x.crowd_heat = heat

# ---- who is who ----
func e(tag: String) -> TNBSim: return a if tag == "A" else b
func other(tag: String) -> String: return "B" if tag == "A" else "A"
func ctrl_sim() -> TNBSim: return e(ctrl)
func _ai(tag: String) -> bool: return manager or (tag != ctrl and partner_ai)
func pair_key() -> String: return TNBSim.pair_key(a.pname(), b.pname())
func pair_level() -> int: return a.kizuna_level(a.pname(), b.pname())
func sync_ms() -> int: return int(fmt.get("sync_ms", 500))
func answer_ms() -> int: return int(fmt.get("partner_answer_ms", 250))

func level_need() -> int:
	# the Kizuna level whose effect carries "exhibition_duo" (economy.v1.json: Lv4 Duo, NP_08 s5.2)
	var fx: Dictionary = a.ECO.get("kizuna", {}).get("effects", {})
	for k in fx:
		if bool(fx[k].get("exhibition_duo", false)): return int(k)
	return 0

func sync_move(fam: String) -> Dictionary:
	# the library's festival move of this family: duo_variant "sync_<sync_ms>ms" (Double Overtime on RISE, Two-Hand Winter on WALL)
	var tag := "sync_%dms" % sync_ms()
	var names: Array = a.library.keys(); names.sort()
	for nm in names:
		var m: Dictionary = a.library[nm]
		if str(m.get("duo_variant", "")) == tag and str(m["family"]) == fam: return m
	return {}

func duo_ready() -> bool: return level_need() > 0 and pair_level() >= level_need()

func duo_hint() -> String:
	var parts: Array = []
	for fam in ["RISE", "WALL"]:
		var m := sync_move(fam)
		if m.size() > 0: parts.append("%s = %s (%d)" % [{"RISE": "LB + uppercut", "WALL": "LB + RT held"}[fam], str(m["name"]).to_upper(), int(m["tension_cost"])])
	return ", ".join(PackedStringArray(parts)) + " - both inside %d ms" % sync_ms()

func _rec(mv: Dictionary, tag: String) -> Dictionary:
	var m: Dictionary = mv.duplicate(true)
	m["duo_sync"] = pair_key(); m["sync_partner"] = e(other(tag)).pname()
	return m

func eligible(fam: String) -> String:
	# "" when the pair can sync this family's move now; else why not
	var need := level_need()
	if need <= 0: return "no exhibition duo in the economy"
	if pair_level() < need: return "%s & %s are Lv%d - the duo sync needs Lv%d %s" % [a.pname(), b.pname(), pair_level(), need, str(a.ECO["kizuna"]["names"][need - 1])]
	var mv := sync_move(fam)
	if mv.is_empty(): return "no festival move on %s" % fam
	for s in [a, b]:
		if s.mode != "FIGHT": return "%s is not fighting (%s)" % [s.pname(), s.mode]
		if s.cast.size() > 0: return "%s's pair has a cast in flight" % s.pname()
		if s.clinch.size() > 0: return "%s is tied up in a clinch" % s.pname()
	if team < a.hiss_cost(_rec(mv, "A")) or a.save_bar: return "the bar is short (%d of %d)" % [int(team), int(a.hiss_cost(_rec(mv, "A")))]
	return ""

# ---- the tick ----
func step(inp: Dictionary) -> void:
	# the pad plays ctrl; the other pair's input is its profile's (or nothing)
	if ctrl == "A": step_pair(inp, {})
	else: step_pair({}, inp)

func step_pair(ia: Dictionary, ib: Dictionary) -> void:
	tick += 1
	if over:                                                                                             # between exhibitions: the ledger's owner takes the overworld's keys
		var oi: Dictionary = ia if ctrl == "A" else ib
		if oi.get("restart", false): restart(); return
		a.step(oi); return
	if manager and window.is_empty(): _manager_call()
	var ins := {"A": ia.duplicate(), "B": ib.duplicate()}
	for tg in ["A", "B"]:
		if not e(tg).delegated: ins[tg] = _sync_input(tg, ins[tg])
		if inject[tg].size() > 0:
			for k in inject[tg]: ins[tg][k] = inject[tg][k]
			inject[tg] = {}
	_holds()
	for tg in ["A", "B"]:
		if e(tg).mode != "OVER": e(tg).step(ins[tg])
		if thrown[tg]: e(tg).threw_since_arm = true; thrown[tg] = false
	_reconcile()
	_link_wall()
	_window_tick()
	thrown = {"A": false, "B": false}
	_check_end()

func _sync_input(tg: String, ci: Dictionary) -> Dictionary:
	# NP_05 s7: the duo motions of a hands-on pair - the first opens the window, the other's same motion inside it casts the move
	var s := e(tg)
	var row := str(ci.get("punch", ""))
	var lb := bool(ci.get("lb", false))
	var rise := lb and row != "" and s._family_row_matches("RISE", row)
	var wall_m := lb and bool(ci.get("block", false))
	var open_other := window.size() > 0 and str(window["first"]) != tg
	if open_other and rise and str(window["fam"]) == "RISE":
		ci.erase("punch"); thrown[tg] = true                                                            # the flick is the answer - thrown, not an arm feint
		_fire(str(window["first"]), "RISE", "hands", int(window["t"])); return ci
	if wall_m and ((open_other and str(window["fam"]) == "WALL") or (window.is_empty() and eligible("WALL") == "") or (window.size() > 0 and str(window["first"]) == tg and str(window["fam"]) == "WALL")):
		s.lb_block_t = 0                                                                                 # the hold is the coordinator's while a duo wall is possible (his own never reaches 400 ms)
		hold_t[tg] = int(hold_t[tg]) + 1
		if int(hold_t[tg]) == TNBSim.ms(400):
			if open_other: _fire(str(window["first"]), "WALL", "hands", int(window["t"]))
			elif window.is_empty(): _open(tg, "WALL", {"wall": true})
		return ci
	hold_t[tg] = 0
	if rise and window.is_empty() and eligible("RISE") == "":
		_open(tg, "RISE", {"punch": row, "lb": true, "power": bool(ci.get("power", false)), "body": bool(ci.get("body", false))})
		ci.erase("punch"); thrown[tg] = true                                                            # the call is a throw: LB stays up, no arm feint
	return ci

func _holds() -> void:
	# the bar is the pair's call: both hold it while a window is open; a fighter on his profile holds it at the call's bar while the duo
	# can be made (his own hissatsu waits - the pad's call, or the profiles' in manager mode)
	var call := duo_ready() and a.mode == "FIGHT" and b.mode == "FIGHT" and team >= float(fmt.get("manager_duo_bar", 90))
	for tg in ["A", "B"]: e(tg).bar_hold = window.size() > 0 or (call and e(tg).delegated)

func _open(tg: String, fam: String, held: Dictionary) -> void:
	var mv := sync_move(fam)
	window = {"first": tg, "fam": fam, "t": 0, "held": held, "move": str(mv["name"])}
	_ev("duo_sync", {"state": "open", "first": tg, "who": e(tg).pname(), "partner": e(other(tg)).pname(), "move": str(mv["name"]), "fam": fam, "ms": sync_ms(), "ai": e(other(tg)).delegated})
	var ln := "DUO SYNC - %s calls %s: %s has %d ms%s" % [e(tg).pname(), str(mv["name"]).to_upper(), e(other(tg)).pname(), sync_ms(), " (on his profile: he answers at %d)" % answer_ms() if e(other(tg)).delegated else ""]
	a._say(ln); b._say(ln)

func _window_tick() -> void:
	if window.is_empty(): return
	window["t"] = int(window["t"]) + 1
	var second := other(str(window["first"]))
	if e(second).delegated and int(window["t"]) >= TNBSim.ms(float(answer_ms())):
		_fire(str(window["first"]), str(window["fam"]), "ai", int(window["t"])); return
	if int(window["t"]) > TNBSim.ms(float(sync_ms())): _miss("%s never answered inside %d ms" % [e(second).pname(), sync_ms()])

func _fire(first: String, fam: String, by: String, t: int) -> void:
	# both engagements cast the pair's move at once: the bar pays once, each half carries half the price (an interrupt refunds its half's half)
	var why := eligible(fam)
	if why != "":
		if window.size() > 0: _miss(why)
		return
	var mv := sync_move(fam)
	var cost := e(first).hiss_cost(_rec(mv, first))
	duo_n += 1
	var sid := "%s#%d" % [pair_key(), duo_n]
	window = {}; hold_t = {"A": 0, "B": 0}
	team = maxf(0.0, team - cost)
	for tg in ["A", "B"]:
		var s := e(tg)
		var m := _rec(mv, tg); m["duo_sync_id"] = sid
		s._start_cast("P", m); s.threw_since_arm = true; thrown[tg] = true
		s.cast["cost"] = cost * 0.5
		s.tension = team
	_ev("duo_cast", {"move": str(mv["name"]), "fam": fam, "pair": pair_key(), "first": first, "by": by, "ms": int(round(float(t) * 1000.0 / TNBSim.TICK_HZ)), "cost": cost, "id": sid, "bar": team})
	var ln := "DUO SYNC %s :: %s & %s together%s - %d off the bar once (%d)" % [str(mv["name"]).to_upper(), a.pname(), b.pname(), {"hands": " (answered in %d ms)" % int(round(float(t) * 1000.0 / TNBSim.TICK_HZ)), "ai": " (%s answered on his profile)" % e(other(first)).pname(), "manager": " (the profiles call it)"}.get(by, ""), int(cost), int(team)]
	a._say(ln); b._say(ln)

func _miss(why: String) -> void:
	# unanswered: the held motion executes as it would have - the flick next tick, or his own WALL now
	var first := str(window["first"]); var fam := str(window["fam"]); var held: Dictionary = window["held"]
	_ev("duo_missed", {"first": first, "who": e(first).pname(), "fam": fam, "move": str(window["move"]), "why": why, "t": int(window["t"])})
	window = {}
	var ln := "DUO SYNC MISSED - %s; %s's motion goes as his own" % [why, e(first).pname()]
	a._say(ln); b._say(ln)
	for tg in ["A", "B"]: e(tg).bar_hold = false
	if fam == "RISE": inject[first] = held
	elif e(first).mode == "FIGHT": e(first).wall_motion()

func _manager_call() -> void:
	# both delegated: the profiles call the duo at the format's bar - Two-Hand Winter when either of the pair is below half his composure,
	# else Double Overtime once both are inside its reach (the uppercut's, +0.3 as a cast reaches, +0.25 of the windup's lunge)
	if team < float(fmt.get("manager_duo_bar", 90)): return
	var hurt := false; var near := true
	var reach := float(TNBSim.GEO[a._punch_family(str(TNBSim.FAMILY_ROW["RISE"]))]["reach"]) + 0.55
	for s in [a, b]:
		if float(s.P["comp"]) < float(s.P["comp_max"]) * 0.5: hurt = true
		if s.P["pos"].distance_to(s.B["pos"]) > reach: near = false
	var fam := "WALL" if hurt else "RISE"
	if fam == "RISE" and not near: return
	if eligible(fam) == "": _fire(ctrl, fam, "manager", 0)

func _reconcile() -> void:
	# one team bar, one enemy bar, one building: each engagement's change since the last tick, summed; one ring clock
	var da := a.tension - team; var db := b.tension - team
	team = clampf(team + da + db, 0.0, 100.0)
	var ea := a.btension - bteam; var eb := b.btension - bteam
	bteam = clampf(bteam + ea + eb, 0.0, 100.0)
	var ha := a.crowd_heat - heat; var hb := b.crowd_heat - heat
	heat = clampf(heat + ha + hb, 0.0, 100.0)
	var ring := 1 << 30
	for s in [a, b]:
		s.tension = team; s.btension = bteam; s.crowd_heat = heat
		if s.mode != "OVER": ring = mini(ring, s.clock_t)
	for s in [a, b]:
		if s.mode != "OVER": s.clock_t = ring

func _link_wall() -> void:
	# Two-Hand Winter: the first half raised links its gauge into the other engagement - one dictionary, two fighters behind it
	for tg in ["A", "B"]:
		var w: Dictionary = e(tg).wall["P"]
		var sid := str(w.get("duo", ""))
		if sid != "" and sid != linked:
			w["shared"] = tg; e(other(tg)).wall["P"] = w; linked = sid
			_ev("duo_wall_linked", {"id": sid, "owner": tg, "pts": float(w.get("pts", 0.0))})
	var ww: Dictionary = a.wall["P"]
	if ww.has("shared") and is_same(ww, b.wall["P"]) and e(str(ww["shared"])).mode == "OVER" and e(other(str(ww["shared"]))).mode != "OVER":
		ww["shared"] = other(str(ww["shared"]))                                                      # its pair finished: the other runs its clocks

func _check_end() -> void:
	if over: return
	if a.mode == "OVER" and b.mode == "OVER": _end(); return
	if not manager and e(ctrl).mode == "OVER" and e(other(ctrl)).mode != "OVER":
		swap_control()                                                                                   # your pair is finished: the pad takes the one still fighting

func score() -> Array: return [a.score_p + b.score_p, a.score_b + b.score_b]

func _end() -> void:
	# NP_01 s3.3 on the pairs' sums: score, segment wins, counter hits; a tie is a DRAW (no Golden DROP at a festival). Pays once, as a dual
	over = true; window = {}; hold_t = {"A": 0, "B": 0}; inject = {"A": {}, "B": {}}
	var sc := score()
	var sw := [a.seg_wins_p + b.seg_wins_p, a.seg_wins_b + b.seg_wins_b]
	var co := [a.counters_p + b.counters_p, a.counters_b + b.counters_b]
	var v := "THE EXHIBITION IS A DRAW"; var rung := "draw"
	if int(sc[0]) != int(sc[1]): v = ("MILLBROOK" if int(sc[0]) > int(sc[1]) else "ASCENDANT") + " WINS THE EXHIBITION"; rung = "score"
	elif int(sw[0]) != int(sw[1]): v = ("MILLBROOK" if int(sw[0]) > int(sw[1]) else "ASCENDANT") + " WINS THE EXHIBITION ON SEGMENTS"; rung = "segment_wins"
	elif int(co[0]) != int(co[1]): v = ("MILLBROOK" if int(co[0]) > int(co[1]) else "ASCENDANT") + " WINS THE EXHIBITION ON COUNTERS"; rung = "counter_hits"
	var won := v.begins_with("MILLBROOK")
	verdict = {"verdict": v, "rung": rung, "score": sc, "seg_wins": sw, "counters": co, "pairs": [[a.pname(), a.boss_name, a.score_p, a.score_b], [b.pname(), b.boss_name, b.score_p, b.score_b]], "duos": duo_n}
	_ev("exhibition_end", verdict)
	a.dual_xp += b.dual_xp; b.dual_xp = 0                                                               # the toast counts both pairs' fight XP
	a._pay_dual(won); a._recruit_after_dual(won); a._gw_dual(won)
	if won and venue == "festival": a.gear_festival()                                                   # PAC-094: NP_11 s5 - the festival's prize (one ledger: both pairs share it)
	var ln := "EXHIBITION OVER :: %s   SCORE %d-%d (%s %d-%d, %s %d-%d)   segments %d-%d   counters %d-%d" % [str(verdict["verdict"]), int(sc[0]), int(sc[1]), a.pname(), a.score_p, a.score_b, b.pname(), b.score_p, b.score_b, int(sw[0]), int(sw[1]), int(co[0]), int(co[1])]
	a._say(ln); b._say(ln)

func restart() -> void:
	# F5: the exhibition again - the same pair, the same enemy, the ledger carried
	over = false; verdict = {}; window = {}; hold_t = {"A": 0, "B": 0}; inject = {"A": {}, "B": {}}; linked = ""; duo_n = 0
	for tg in ["A", "B"]: e(tg).delegate_all = _ai(tg); e(tg).new_dual()
	b.rewards = a.rewards; b.pi = a.pi
	_bars_from(a)
	_ev("exhibition", {"label": str(fmt.get("label", "")), "a": [a.pname(), a.boss_name], "b": [b.pname(), b.boss_name], "pair": pair_key(), "level": pair_level(), "duo": duo_ready()})

func swap_control() -> void:
	# \ : the pad takes the other pair; the one it leaves plays on his profile
	ctrl = other(ctrl); hold_t = {"A": 0, "B": 0}
	_flags()
	_ev("control", {"ctrl": ctrl, "who": e(ctrl).pname(), "partner": e(other(ctrl)).pname(), "manager": manager})

func set_manager(on: bool) -> void:
	manager = on; _flags()
	_ev("control", {"ctrl": ctrl, "who": e(ctrl).pname(), "partner": e(other(ctrl)).pname(), "manager": manager})

func set_partner_ai(on: bool) -> void:
	partner_ai = on; _flags()

func _flags() -> void:
	for tg in ["A", "B"]: e(tg).delegate_all = _ai(tg); e(tg).delegated = _ai(tg)

func set_team(v: float) -> void:
	team = clampf(v, 0.0, 100.0); a.tension = team; b.tension = team

func _ev(kind: String, d: Dictionary = {}) -> void:
	var x := d.duplicate(); x["kind"] = kind; x["tick"] = tick
	events.append(x)

# ---- the state ----
func hash_state() -> int:
	return [a.hash_state(), b.hash_state(), ctrl, partner_ai, manager, team, bteam, heat, window, hold_t, inject, duo_n, linked, over, str(verdict.get("verdict", "")), tick, venue].hash()

func snapshot() -> Dictionary:
	# both engagements' DualStates and the coordinator's own fields; the ledger and the duo wall relink on the way back
	var co := {"venue": venue, "ctrl": ctrl, "partner_ai": partner_ai, "manager": manager, "team": team, "bteam": bteam, "heat": heat, "window": window.duplicate(true), "hold_t": hold_t.duplicate(), "inject": inject.duplicate(true), "duo_n": duo_n, "linked": linked, "over": over, "verdict": verdict.duplicate(true), "tick": tick}
	return {"schema": "Exhibition/NP_01-s8/v1", "a": a.snapshot(), "b": b.snapshot(), "coord": Marshalls.raw_to_base64(var_to_bytes(co)), "hash": hash_state()}

func restore(snap: Dictionary) -> Dictionary:
	if str(snap.get("schema", "")) != "Exhibition/NP_01-s8/v1": return {"ok": false, "why": "not an exhibition snapshot"}
	var ra: Dictionary = a.restore(snap["a"]); var rb: Dictionary = b.restore(snap["b"])
	if not bool(ra["ok"]) or not bool(rb["ok"]): return {"ok": false, "why": str(ra["why"]) + str(rb["why"])}
	var co = bytes_to_var(Marshalls.base64_to_raw(str(snap.get("coord", ""))))
	if not co is Dictionary: return {"ok": false, "why": "the coordinator's blob does not decode"}
	venue = str(co.get("venue", "festival")); ctrl = str(co["ctrl"]); partner_ai = bool(co["partner_ai"]); manager = bool(co["manager"]); team = float(co["team"]); bteam = float(co["bteam"]); heat = float(co["heat"])
	window = co["window"]; hold_t = co["hold_t"]; inject = co["inject"]; duo_n = int(co["duo_n"]); linked = str(co["linked"]); over = bool(co["over"]); verdict = co["verdict"]; tick = int(co["tick"])
	b.rewards = a.rewards; b.pi = a.pi
	var wa: Dictionary = a.wall["P"]; var wb: Dictionary = b.wall["P"]
	if linked != "" and str(wa.get("duo", "")) == linked and str(wb.get("duo", "")) == linked and str(wa.get("shared", "")) != "":
		if str(wa["shared"]) == "A": b.wall["P"] = wa
		else: a.wall["P"] = wb
	return {"ok": true, "why": "", "same": hash_state() == int(snap.get("hash", 0))}

# ---- what the HUD reads ----
func lines() -> Array:
	var out: Array = []
	var sc := score()
	out.append("EXHIBITION 2v2 (%s)   ring clock %s   TEAM SCORE %d-%d   bar %d   theirs %d   [\\] swap - you play %s%s" % ["festival" if venue == "festival" else "at home", "%5.1f" % (float(maxi(0, ctrl_sim().clock_t)) / TNBSim.TICK_HZ), int(sc[0]), int(sc[1]), int(team), int(bteam), e(ctrl).pname(), "  (MANAGER: both on their profiles)" if manager else ""])
	for tg in ["A", "B"]:
		var s := e(tg)
		out.append("   PAIR %s  %s vs %s   score %d-%d  EP %d-%d  chin %d/%d vs %d/%d   %s%s" % [tg, s.pname(), s.boss_label, s.score_p, s.score_b, s.ep_p, s.ep_b, int(s.P["comp"]), int(s.P["comp_max"]), int(s.B["comp"]), int(s.B["comp_max"]), s.mode, "  (you)" if tg == ctrl and not manager else ("  (profile)" if s.delegated else "  (hands)")])
	out.append("   " + duo_line())
	return out

func duo_line() -> String:
	if window.size() > 0:
		return "DUO SYNC WINDOW  %s called %s - %.2fs left for %s" % [e(str(window["first"])).pname(), str(window["move"]).to_upper(), maxf(0.0, float(TNBSim.ms(float(sync_ms())) - int(window["t"])) / TNBSim.TICK_HZ), e(other(str(window["first"]))).pname()]
	if not duo_ready(): return "DUO SYNC: %s & %s Lv%d - it opens at Lv%d" % [a.pname(), b.pname(), pair_level(), level_need()]
	var why := eligible("RISE")
	return "DUO SYNC (Lv%d): %s%s" % [pair_level(), duo_hint(), "" if why == "" else "  [not now: %s]" % why]

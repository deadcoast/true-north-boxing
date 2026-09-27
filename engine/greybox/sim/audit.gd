extends RefCounted
# Loaded by preload("res://sim/audit.gd") - no class_name (headless runs must not depend on the editor's class cache).
# TRUE NORTH BOXING - the obsolescence audit (NP_11 s10, PAC-095).
# "Per milestone, take the three earliest-recruitable fighters and build them for the current endgame using live systems only. If any
# cannot reach viability (tier 4, competitive board, coherent technique kit), the failing system - not the fighter - gets fixed."
# Each fighter is built in a sim of his own through the verbs a player has, each refusing when its rule is unmet: the endgame's XP with
# his own XP curve; the three trials marked by their own code paths (a spar won, a transform weathered, the mirror beaten) and each
# ascension paid in Spirits; the board by the aid's picks until the points run out; the raises on his lowest stat until the jar runs
# out; a kit from the live sources (the shop's open shelves, the masters' open lessons) chosen so every move answers a motion; the gear
# the locker and the shop fit. Then he fights the endgame's bosses in spars on the profile. The late recruits, built the same way, are
# the reference. A fighter who falls short names the system that failed him, with the numbers.
const TNBSim := preload("res://sim/core.gd")

static func mk(content: Dictionary, boss_idx: int, seed_v: int, lineup: Array, reward_ledger: Dictionary) -> TNBSim:
	var s := TNBSim.new()
	s.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, seed_v, content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), "", content.get("bouts", {}), content.get("scraps", {}),
		content.get("pattern_intel", {}), {}, content.get("remixes", {}), content.get("economy", {}), reward_ledger, {}, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), {}, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
	return s

static func endgame_bosses(content: Dictionary, arc: String) -> Array:
	# the current endgame's bosses: the patterns of the audit's arc, in the roster's order
	var out: Array = []
	for b in TNBSim.BOSSES:
		if str(content["patterns"].get(b, {}).get("meta", {}).get("arc", "")) == arc: out.append(str(b))
	return out

static func card_of(s: TNBSim, name: String, recruit_key: String) -> Dictionary:
	# a Millbrook card the greybox carries, else the recruit table's card (C29)
	for c in TNBSim.LINEUP_MILLBROOK_8 + TNBSim.LINEUP_MILLBROOK:
		if str(c["name"]) == name:
			var cc: Dictionary = c.duplicate(true); cc.erase("reserve"); return cc
	return s.recruit_card(recruit_key) if recruit_key != "" else {}

static func _answers(s: TNBSim, nm: String, mv: String) -> bool:
	# would this move answer a motion if it joined the kit last: every move ahead of it on its family (his own, then the kit's) costs more
	var m: Dictionary = s.library[mv]
	var c := float(m["tension_cost"])
	var own := str(s._club_card(nm).get("hissatsu", ""))
	if s.library.has(own) and str(s.library[own]["family"]) == str(m["family"]) and (str(s.library[own]["tier"]) != "T0" or s.t0_open(nm)) and float(s.library[own]["tension_cost"]) <= c: return false
	for k in s.kit_moves(nm):
		if str(s.library.get(str(k), {}).get("family", "")) == str(m["family"]) and float(s.library[str(k)]["tension_cost"]) <= c: return false
	return true

static func _fam_used(s: TNBSim, nm: String, fam: String) -> bool:
	var own := str(s._club_card(nm).get("hissatsu", ""))
	if s.library.has(own) and str(s.library[own]["family"]) == fam: return true
	for k in s.kit_moves(nm):
		if str(s.library.get(str(k), {}).get("family", "")) == fam: return true
	return false

static func learnable_families(s: TNBSim, nm: String) -> Array:
	# the motion families the live sources teach him now: the shop's open shelves he can afford, the masters' open lessons, what he knows
	var fams := {}
	for r in s.shop_list():
		if bool(r["open"]) and s.tech_class(str(r["move"])) in ["t0", "slot"]: fams[str(s.library[str(r["move"])]["family"])] = true
	for lo in s.lessons_open(nm): fams[str(s.library[str(lo[1])]["family"])] = true
	for mv in s.known(nm):
		if s.library.has(str(mv)) and s.tech_class(str(mv)) in ["t0", "slot"]: fams[str(s.library[str(mv)]["family"])] = true
	var out: Array = fams.keys(); out.sort()
	return out

static func build_kit(s: TNBSim, nm: String) -> Array:
	# a coherent kit from the live sources: each free room (the T0 slot, the technique slots) takes the learnable move that answers a
	# motion - a family he has nothing on first, then the higher tier, then the cheaper, then the name - bought at the shop or taken
	# from a master's open lesson (learned, it goes straight into the kit)
	var got: Array = []
	var tr := {"T0": 1, "T1": 2, "T2": 3}
	for guard in 16:
		var room: Dictionary = s._kit_room(nm)
		var need_t0: bool = s.t0_open(nm) and str(room["t0"]) == ""
		var need_slot: bool = int(room["used"]) < int(room["slots"])
		if not need_t0 and not need_slot: break
		var cs: Array = []
		for r in s.shop_list():
			if s.buy_why(nm, str(r["move"])) == "": cs.append([str(r["move"]), "shop", int(r["hbp"])])
		for lo in s.lessons_open(nm): cs.append([str(lo[1]), str(lo[0]), 0])
		var best: Array = []; var bk: Array = []
		for c in cs:
			var mv := str(c[0]); var cls := s.tech_class(mv)
			if not ((cls == "t0" and need_t0) or (cls == "slot" and need_slot)) or mv in s.known(nm) or not _answers(s, nm, mv): continue
			var k := [0 if _fam_used(s, nm, str(s.library[mv]["family"])) else 1, int(tr.get(str(s.library[mv]["tier"]), 0)), -int(c[2])]
			if best.is_empty() or k > bk or (k == bk and mv < str(best[0])): best = c; bk = k
		if best.is_empty(): break
		var ok: bool = bool(s.buy(nm, str(best[0]))["ok"]) if str(best[1]) == "shop" else bool(s.lesson(str(best[1]), nm, str(best[0]))["ok"])
		if not ok: break
		got.append("%s (%s, %s %s)" % [str(best[0]), str(best[1]), str(s.library[str(best[0])]["tier"]), str(s.library[str(best[0])]["family"])])
	return got

static func build(content: Dictionary, A: Dictionary, card: Dictionary) -> Dictionary:
	# one fighter built for the endgame with live systems only; what it cost, what it made, and what refused
	var nm := str(card["name"])
	var lu: Array = [card]
	for c in TNBSim.LINEUP_MILLBROOK:
		if str(c["name"]) != nm and lu.size() < 4: lu.append(c)
	var eco: Dictionary = content.get("economy", {})
	var lvl := int(A["endgame"]["level"])
	var houseless: bool = TNBSim.house_key(str(card.get("house", "none"))) == "none"
	var mods := 1.0 + (float(eco.get("xp", {}).get("houseless_pct", 10)) / 100.0 if houseless else 0.0)   # NP_07 s5: the no-name's curve
	var xp := int(float(eco.get("xp", {}).get("curve_k", 48)) * float(lvl * lvl) * mods)
	var bd: Dictionary = A["budget"]
	var led: Dictionary = TNBSim.seed_story(TNBSim.seed_purse({"xp": {nm: xp}}, "spirits:%d,beans:%d,hbp:%d" % [int(bd["spirits"]), int(bd["beans"]), int(bd["hbp"])]), ",".join(PackedStringArray(bd.get("flags", []))))
	var s := mk(content, 1, 7, lu, led)
	s.mode = "OVER"
	var fails := {}
	# rarity: each trial by its own code path, each ascension paid
	var trials: Array = []
	for step in ["spar_won", "storm", "mirror"]:
		match step:
			"spar_won":
				s.start_spar(1, [], {}, "", "", {"fighter": nm}); s.score_p = 1; s._end_bout(); s.end_bout()
			"storm":
				s.mode = "FIGHT"; s.btform = {"who": "ioan_vasile", "tier": "zone", "answered": false, "dropped": false, "weathered": 2, "shaved": 60, "t": 0}; s._boss_tform_end(false)
			"mirror":
				s.start_mirror(nm); s.score_p = 1; s._end_bout(); s.end_bout()
		s.mode = "OVER"
		var ar: Dictionary = s.ascend(nm)
		trials.append(step)
		if not bool(ar["ok"]) and not fails.has("tier4"): fails["tier4"] = str(ar["why"])
	# the board: the aid's picks until the points run out
	var nodes := 0
	while s.node_best(nm) != "" and nodes < 200 and bool(s.take_node(nm, "*")["ok"]): nodes += 1
	# the raises: his lowest stat, until the jar runs out
	var raises := 0
	while raises < 400:
		var gs0: Dictionary = s.grown_stats(s._club_card(nm)); var lo := ""; var lv := 1 << 20
		for k in s.GROW.get("stats", []):
			if s.raise_why(nm, str(k)) == "" and int(gs0[str(k)]) < lv: lv = int(gs0[str(k)]); lo = str(k)
		if lo == "" or not bool(s.raise_stat(nm, lo)["ok"]): break
		raises += 1
	# the kit, then the gear
	var kit_steps := build_kit(s, nm)
	s.gear_aid(nm)
	var room: Dictionary = s._kit_room(nm)
	var gs: Dictionary = s.grown_stats(s._club_card(nm))
	var tot := 0
	for k in gs: tot += int(gs[k])
	var cr: Dictionary = A["criteria"]
	var b := {"name": nm, "house": str(card.get("house", "none")), "style": str(card.get("style", "")), "level": s.level_of(nm), "rarity": s.rarity_of(nm), "xp": xp,
		"points": s.gpoints(nm), "points_left": s.gpoints_free(nm), "nodes": nodes, "passives": s.passives_of(nm), "raises": raises, "stats": gs, "total": tot,
		"kit": s.kit_moves(nm), "kit_steps": kit_steps, "dead": s.kit_unreachable(nm), "slots": int(room["slots"]), "used": int(room["used"]), "t0": str(room["t0"]),
		"families": learnable_families(s, nm), "own_family": str(s.library.get(str(card.get("hissatsu", "")), {}).get("family", "")),
		"gear": s.gear_worn(nm), "gear_slots": s.accessory_slots(nm), "left": {"spirits": int(s.rewards.get("spirits", 0)), "beans": int(s.rewards.get("beans", 0)), "hbp": int(s.rewards.get("hbp", 0))},
		"ledger": s.rewards.duplicate(true), "lineup": lu, "fails": fails}
	if int(b["rarity"]) < 4 and not fails.has("tier4"): fails["tier4"] = "%s stands at tier %d" % [nm, int(b["rarity"])]
	if int(b["points_left"]) > int(cr.get("points_left_max", 1)) or b["passives"].size() < int(cr.get("passives_min", 3)):
		fails["board"] = "%d Board Points left unspent (of %d), %d passives" % [int(b["points_left"]), int(b["points"]), b["passives"].size()]
	var t0_ok: bool = str(b["t0"]) != "" or not s.t0_open(nm)
	if int(b["used"]) < int(b["slots"]) or not t0_ok or b["dead"].size() > 0:
		var free_f: Array = b["families"].filter(func(x): return str(x) != str(b["own_family"]))
		fails["kit"] = "%d of %d technique slots%s answer a motion - the live sources teach %s, the card's own move on %s: %d famil%s for the slots%s" % [int(b["used"]), int(b["slots"]), " and the T0" if t0_ok else " (the T0 slot empty)", "/".join(PackedStringArray(b["families"])), str(b["own_family"]) if str(b["own_family"]) != "" else "none", free_f.size(), "y" if free_f.size() == 1 else "ies", (" - %s never answer%s" % [", ".join(PackedStringArray(b["dead"])), "s" if b["dead"].size() == 1 else ""]) if b["dead"].size() > 0 else ""]
	return b

static func fight(content: Dictionary, b: Dictionary, boss: String, seed_v: int, ticks_max: int) -> Dictionary:
	# one spar against an endgame boss, the built card on the profile; the sim's own verdict
	var bi := TNBSim.BOSSES.find(boss)
	var f := mk(content, bi, seed_v, b["lineup"], b["ledger"])
	f.delegate_all = true; f.events.clear()
	f.start_spar(bi, [], {}, "", "", {"fighter": str(b["name"])})
	var k := 0
	while f.mode != "OVER" and k < ticks_max: f.step({}); k += 1
	var won := false
	for e in f.events:
		if str(e["kind"]) == "bout_end": won = bool(e.get("won", false))
	return {"boss": boss, "seed": seed_v, "won": won, "score": [f.score_p, f.score_b], "ep": [f.ep_p, f.ep_b], "ticks": k, "hash": f.hash_state()}

static func _median(xs: Array) -> float:
	if xs.is_empty(): return 0.0
	var a := xs.duplicate(); a.sort()
	return float(a[a.size() / 2]) if a.size() % 2 == 1 else (float(a[a.size() / 2 - 1]) + float(a[a.size() / 2])) / 2.0

static func run(content: Dictionary, A: Dictionary, opts: Dictionary = {}) -> Dictionary:
	# the audit: the earliest three and the reference built and fought; each earliest judged, the failing system named
	var s0 := mk(content, 1, 7, TNBSim.LINEUP_MILLBROOK, {})
	var cr: Dictionary = A["criteria"]
	var bosses: Array = opts.get("bosses", endgame_bosses(content, str(A["endgame"]["arc"])))
	var seeds: Array = opts.get("seeds", cr.get("seeds", [11]))
	var tmax := int(cr.get("spar_ticks_max", 12000))
	var fight_all := func(b: Dictionary) -> Dictionary:
		var rs: Array = []; var w := 0
		for bn in bosses:
			for sd in seeds:
				var r := fight(content, b, str(bn), int(sd), tmax); rs.append(r)
				if bool(r["won"]): w += 1
		return {"fights": rs, "won": w, "n": rs.size(), "rate": float(w) / float(maxi(1, rs.size()))}
	var early: Array = []
	for e in A["earliest"]:
		if opts.has("fighters") and not (str(e["card"]) in opts["fighters"]): continue
		var b := build(content, A, card_of(s0, str(e["card"]), str(e.get("recruit", ""))))
		b["source"] = str(e.get("source", "")); b.merge(fight_all.call(b)); early.append(b)
	var refs: Array = []
	if bool(opts.get("reference", true)):
		for rk in A["reference"]["recruits"]:
			var rb := build(content, A, card_of(s0, "", str(rk)))
			rb.merge(fight_all.call(rb)); refs.append(rb)
	var ref := {"rate": _median(refs.map(func(x): return float(x["rate"]))), "total": _median(refs.map(func(x): return int(x["total"]))), "stats": {}}
	for k in s0.GROW.get("stats", []): ref["stats"][str(k)] = _median(refs.map(func(x): return int(x["stats"][str(k)])))
	var sysn: Dictionary = A["systems"]
	var viable := 0
	for b in early:
		var fl: Dictionary = b["fails"]
		var sy := {}
		for fk in fl: sy[fk] = str(sysn.get(fk, fk))
		if float(b["rate"]) < float(cr.get("win_rate", 0.5)):
			var gap := 0.0 if float(ref["total"]) <= 0.0 else (float(ref["total"]) - float(b["total"])) / float(ref["total"]) * 100.0
			var defs: Array = []
			for k in ref["stats"]: defs.append([float(ref["stats"][k]) - float(b["stats"][k]), str(k)])
			defs.sort(); defs.reverse()
			var worst: Array = defs.slice(0, 2).map(func(d): return "%s %d against %d" % [str(d[1]), int(b["stats"][str(d[1])]), int(ref["stats"][str(d[1])])])
			var why := "%d of %d segments won against the endgame's bosses (%d%%, the bar %d%%)" % [int(b["won"]), int(b["n"]), int(round(100.0 * float(b["rate"]))), int(round(100.0 * float(cr.get("win_rate", 0.5))))]
			if refs.size() > 0 and gap > float(cr.get("stat_gap_pct", 10)):
				fl["fights"] = "%s - %s: %s; the card's total %d, %d%% under the late recruits' %d" % [why, str(sysn["fights_growth"]), ", ".join(PackedStringArray(worst)), int(b["total"]), int(round(gap)), int(ref["total"])]
				sy["fights"] = str(sysn["fights_growth"])
			else:
				fl["fights"] = "%s - %s" % [why, str(sysn["fights_other"])]
				sy["fights"] = str(sysn["fights_other"])
		b["viable"] = fl.is_empty()
		b["systems"] = sy.values()
		if bool(b["viable"]): viable += 1
	return {"early": early, "refs": refs, "ref": ref, "bosses": bosses, "seeds": seeds, "viable": viable, "of": early.size()}

static func lines(rep: Dictionary) -> Array:
	# the report: each earliest fighter's build and verdict, then the reference
	var out: Array = []
	for b in rep["early"]:
		out.append("AUDIT :: %s (%s) - L%d, tier %d; board %d of %d points, %d passives; kit %d of %d slots + T0 %s, %s; gear %d of %d; the endgame %d of %d (%d%%) - %s" % [str(b["name"]), str(b["source"]).get_slice(":", 0), int(b["level"]), int(b["rarity"]), int(b["points"]) - int(b["points_left"]), int(b["points"]), b["passives"].size(), int(b["used"]), int(b["slots"]), str(b["t0"]) if str(b["t0"]) != "" else "-", "every move answers" if b["dead"].is_empty() else "%s never answer" % ", ".join(PackedStringArray(b["dead"])), b["gear"].size(), int(b["gear_slots"]), int(b["won"]), int(b["n"]), int(round(100.0 * float(b["rate"]))),
			"VIABLE" if bool(b["viable"]) else "NOT VIABLE: " + "; ".join(PackedStringArray(b["fails"].values()))])
	for r in rep["refs"]:
		out.append("  reference %s - tier %d, total %d, kit %d of %d slots%s, the endgame %d of %d (%d%%)" % [str(r["name"]), int(r["rarity"]), int(r["total"]), int(r["used"]), int(r["slots"]), " (%s)" % str(r["fails"]["kit"]).get_slice(" - ", 1) if r["fails"].has("kit") else "", int(r["won"]), int(r["n"]), int(round(100.0 * float(r["rate"])))])
	return out

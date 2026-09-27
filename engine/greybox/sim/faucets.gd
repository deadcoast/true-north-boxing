extends RefCounted
# Loaded by preload("res://sim/faucets.gd") - no class_name (headless runs must not depend on the editor's class cache).
# TRUE NORTH BOXING - the faucet/sink audit (NP_11 s6, PAC-097).
# "Faucet/sink audit runs per milestone (NP_13 s6): target - a story-pace player affords 70% of desired sinks; completionists find
# Prestige/Beans the long tails."
# The faucet is a story-pace playthrough to Arc 3's start (data/faucets.v1.json): NP_12's Arc 1 and Arc 2 in episodes, one story
# dual an episode, NP_02 s5's session shape between, the gym at the tiers the story opens - every fight paid by the sim's own reward
# paths with its result given (pay_segment and _pay_dual for a dual, _pay_bout for a scrap or a spar, train for a training slot).
# A segment's own XP (its hits, counters, flashes and drops, by the sim's event_xp) is measured from played fights: the obsolescence
# audit's builds against its endgame. The sinks are priced from the live tables: the squad built as the obsolescence audit builds
# (its ledger's spend), every facility track to T3, the Forge. The verdict names each currency that misses, with its numbers.
const TNBSim := preload("res://sim/core.gd")
const TNBAudit := preload("res://sim/audit.gd")
const CURRENCIES := ["spirits", "hbp", "beans", "prestige"]

static func _median(xs: Array) -> float:
	if xs.is_empty(): return 0.0
	var a := xs.duplicate(); a.sort()
	return float(a[a.size() / 2]) if a.size() % 2 == 1 else (float(a[a.size() / 2 - 1]) + float(a[a.size() / 2])) / 2.0

static func _c(v: float) -> String:
	# a whole number with thousands commas
	var n := int(round(v)); var neg := n < 0; var t := str(absi(n)); var out := ""
	while t.length() > 3:
		out = "," + t.substr(t.length() - 3) + out; t = t.substr(0, t.length() - 3)
	return ("-" if neg else "") + t + out

static func sessions_of(F: Dictionary, episodes: int) -> float:
	# NP_02 s5: a story dual an episode at its cadence, 45-minute sessions
	var p: Dictionary = F["pace"]
	return float(episodes) * float(p["minutes_per_story_dual"]) / float(p["session_minutes"])

static func mk(content: Dictionary, fmt: String, lineup: Array, ledger: Dictionary, boss_idx: int = 1, seed_v: int = 7) -> TNBSim:
	var s := TNBSim.new()
	s.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, lineup, boss_idx, seed_v, content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), fmt, content.get("bouts", {}), content.get("scraps", {}),
		content.get("pattern_intel", {}), {}, content.get("remixes", {}), content.get("economy", {}), ledger, {}, content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), {}, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
	return s

# ---- a segment's own XP, measured ----
static func fight_xp(content: Dictionary, b: Dictionary, boss: String, seed_v: int, ticks_max: int) -> Dictionary:
	# one spar of a built card against a boss on the profile: the XP its events earn by the sim's own rule, and the sim's verdict
	var bi := TNBSim.BOSSES.find(boss)
	var f := TNBAudit.mk(content, bi, seed_v, b["lineup"], b["ledger"])
	f.delegate_all = true; f.events.clear()
	f.start_spar(bi, [], {}, "", "", {"fighter": str(b["name"])})
	var k := 0
	while f.mode != "OVER" and k < ticks_max: f.step({}); k += 1
	var x := 0; var won := false; var n := {"hit": 0, "drop": 0}
	for ev in f.events:
		var ex := f.event_xp(str(ev["kind"]), ev)
		x += ex
		if ex > 0: n[str(ev["kind"])] = int(n.get(str(ev["kind"]), 0)) + 1
		if str(ev["kind"]) == "bout_end": won = bool(ev.get("won", false))
	return {"boss": boss, "seed": seed_v, "won": won, "xp": x, "events": n, "hash": f.hash_state(), "ticks": k}

static func sample(content: Dictionary, F: Dictionary, A: Dictionary, opts: Dictionary = {}) -> Dictionary:
	# the obsolescence audit's builds of the sample's fighters, each fought against the sample's bosses: the median XP of a won segment
	# and of a lost one (a side the sample never saw takes the other's median, and says so)
	var sm: Dictionary = F["sample"]
	var fighters: Array = opts.get("fighters", sm["fighters"]); var bosses: Array = opts.get("bosses", sm["bosses"]); var seeds: Array = opts.get("seeds", sm["seeds"])
	var tmax := int(A.get("criteria", {}).get("spar_ticks_max", 12000))
	var s0 := TNBAudit.mk(content, 1, 7, TNBSim.LINEUP_MILLBROOK, {})
	var builds: Array = []; var fights: Array = []; var wx: Array = []; var lx: Array = []
	for e in A["earliest"]:
		if not (str(e["card"]) in fighters): continue
		var b := TNBAudit.build(content, A, TNBAudit.card_of(s0, str(e["card"]), str(e.get("recruit", ""))))
		builds.append(b)
		for bn in bosses:
			for sd in seeds:
				var r := fight_xp(content, b, str(bn), int(sd), tmax)
				r["fighter"] = str(b["name"]); fights.append(r)
				(wx if bool(r["won"]) else lx).append(int(r["xp"]))
	var won := _median(wx) if wx.size() > 0 else _median(lx)
	var lost := _median(lx) if lx.size() > 0 else _median(wx)
	return {"won": int(round(won)), "lost": int(round(lost)), "n_won": wx.size(), "n_lost": lx.size(), "fights": fights, "builds": builds,
		"note": "" if wx.size() > 0 and lx.size() > 0 else ("no lost fight in the sample: the won median stands in" if lx.is_empty() else "no won fight in the sample: the lost median stands in")}

# ---- the faucet: a story-pace playthrough, paid by the sim's paths ----
static func pay_dual(s: TNBSim, won: bool, hosted: bool, seg: Dictionary, res: Dictionary) -> void:
	# a story dual with its result given: each segment through pay_segment (its own XP measured, the segment won or not - the first k
	# in slot order), then the dual's own pay (_pay_dual: the closing XP, the reserves' half, Spirits, HBP, the hosted Prestige)
	var n := s.segments()
	var k := int(round(float(n) * float(res["segments_won_in_a_win"] if won else res["segments_won_in_a_loss"])))
	s.dual_xp = 0; s.host = hosted
	for i in n:
		s.seg_idx = i
		s.pay_segment(i < k, int(seg["won"]) if i < k else int(seg["lost"]))
	s.seg_idx = 0
	s._pay_dual(won)
	s.host = false

static func pay_bout(s: TNBSim, kind: String, objective: String, won: bool, district: String = "") -> void:
	# a scrap or a spar with its result given, through _pay_bout (the captain's, R1's card); PAC-101: a scrap in its district (the rep)
	s.bout = {"kind": kind, "objective": objective, "card": {}}
	if district != "": s.bout["district"] = district
	s._pay_bout(won, false)
	s.bout = {}

static func scrap_objective(s: TNBSim, tier: int) -> String:
	# the first objective of the tier (its Prestige is the tier's)
	for id in s.SCRAPS:
		if int(s.SCRAPS[id].get("tier", 1)) == tier: return str(id)
	return ""

static func _ledger_sum(r: Dictionary, hero: String) -> Dictionary:
	return {"xp": int(r.get("xp", {}).get(hero, 0)), "spirits": int(r.get("spirits", 0)), "hbp": int(r.get("hbp", 0)), "prestige": int(r.get("prestige", 0)), "beans": int(r.get("beans", 0))}

static func faucet(content: Dictionary, F: Dictionary, seg: Dictionary, opts: Dictionary = {}) -> Dictionary:
	# the phases in order, one sim each (its format and squad), the reward ledger carried from phase to phase; nothing is spent
	var p: Dictionary = F["pace"]; var res: Dictionary = p["results"]; var sess: Dictionary = p["session"]
	var hero := str(p["protagonist"])
	var led := {}
	var rows: Array = []
	var tot := {"episodes": 0, "duals": 0, "won": 0, "sessions": 0.0, "scraps": 0, "spars": 0, "slots": 0, "hosted": 0, "beats": 0, "quests": 0}
	var s: TNBSim = null
	var bn: Dictionary = p.get("bench", {}); var bench: Array = []; var seated := false                   # PAC-099: NP_08 s1's roles on a story-pace bench
	var vend := {}; var vrep := {}                                                                       # PAC-103: each shelf's first phase open and its key; the shops' rep by phase
	for ph in opts.get("phases", F["phases"]):
		if not seated and bn.size() > 0 and str(ph["id"]) == str(bn.get("from", "")):
			seated = true
			var btier: int = s._scout_tier() if s != null else 1                                         # signed from what the phase before's pulls threw off
			for bi in bn.get("roles", []).size():
				var br: Array = bn["roles"][bi]
				var bnm := "%s %d" % [str(content.get("economy", {}).get("scouting", {}).get("districts", {}).get(str(br[1]), str(br[1]).to_upper())), bi + 1]
				var bsp: Dictionary = (s if s != null else mk(content, "", TNBSim.LINEUP_MILLBROOK, led)).generic_spec(bnm, "BOXERPUNCHER", "", btier)
				bench.append({"card": {"name": bnm, "hissatsu": "", "talk": "", "style": str(bsp["style"]), "element": str(bsp["element"]), "house": str(bsp["house"]), "generic": true, "tier": btier, "stats": bsp["stats"].duplicate(), "district": str(br[1])}, "role": str(br[0])})
		var fmt := str(ph["format"])
		var lu: Array = TNBSim.LINEUP_MILLBROOK if fmt == "mini" else TNBSim.LINEUP_MILLBROOK_8
		var fl: Array = ph.get("flags", [])
		led = TNBSim.seed_story(led, ",".join(PackedStringArray(fl)))
		var fac: Array = []
		for t in ph.get("facilities", {}): fac.append("%s:%d" % [str(t), int(ph["facilities"][t])])
		led = TNBSim.seed_facilities(led, ",".join(PackedStringArray(fac)), content.get("facilities", {}))
		s = mk(content, "" if fmt == "mini" else fmt, lu, led)
		s.mode = "OVER"
		for bc in bench:                                                                                 # the bench kept from phase to phase, each to his role (the ledger carries the roles)
			s.stable.append(bc["card"].duplicate(true))
			if s.stable_role(str(bc["card"]["name"])) != str(bc["role"]): s.assign_role(str(bc["card"]["name"]), str(bc["role"]))
		var rp0: Dictionary = s.rewards.get("roles", {}).get("paid", {}).duplicate()
		if bool(ph.get("book", false)) and s.pi.get("book", []).is_empty(): s.pi["book"] = [str(TNBSim.BOSSES[1])]   # a story-pace Scout Book holds a page by then
		var before := _ledger_sum(s.rewards, hero)
		var eps := int(ph["episodes"])
		var ss := sessions_of(F, eps)
		var n_scr := int(round(ss * float(sess["scraps"]))); var n_spar := int(round(ss * float(sess["spars"]))); var n_slot := int(round(ss * float(sess["training_slots"])))
		var n_host := int(round(float(eps) * float(ph.get("hosted", 0.0))))
		for i in eps: pay_dual(s, i >= int(ph.get("lost", 0)), i < n_host, seg, res)    # the lost first, the hosted first: no pay reads the order
		var obj := scrap_objective(s, int(ph.get("scrap_tier", 1)))
		var w_scr := int(round(float(n_scr) * float(res["scrap_win"]))); var w_spar := int(round(float(n_spar) * float(res["spar_win"])))
		var dists: Array = ph.get("districts", [])
		var rep0 := int(s.rewards.get("rep", {}).get("paid", 0))
		for i in n_scr: pay_bout(s, "scrap", obj, i < w_scr, str(dists[i % dists.size()]) if dists.size() > 0 else "")   # PAC-101: round the phase's districts
		var rep_paid := int(s.rewards.get("rep", {}).get("paid", 0)) - rep0
		for i in n_spar: pay_bout(s, "spar", "", i < w_spar)
		var n_beat := int(round(ss * float(sess.get("story_beats", 0)))); var n_quest := int(round(ss * float(sess.get("quest_steps", 0))))
		for i in n_beat: s.story_mark("story:beat:%s:%d" % [str(ph["id"]), i + 1])                 # PAC-098: NP_02 s5's story beat a session, through the sim's story_mark
		for i in n_quest: s.story_mark("quest:step:%s:%d" % [str(ph["id"]), i + 1])                # ...and its recruitment step, read as a quest step (NP_02 s4: quests pay HBP)
		var game := ""; var slots_run := 0
		for i in n_slot:
			if s.training_used() >= int(s._training().get("slots_per_day", 3)): s.new_day()
			var tr: Dictionary = s.train("*", hero, float(res["training_grade"]))
			if bool(tr.get("ok", false)): slots_run += 1; game = str(tr.get("game", game))
		s.new_day()
		for vs in TNBSim.VENDOR_SHOPS:                                                                    # PAC-103: NP_02 s4's vendor tiers at the phase's end - the story's flag or the district's rep
			if str(s.vendor_shop(vs).get("district", "")) == "": continue
			vrep[str(ph["id"])] = s.vendor_rep(vs)
			for vt in s.vendor_shop(vs).get("order", []):
				var vby := s.shelf_open_by(vs, str(vt))
				if not vend.has("%s:%s" % [vs, vt]) and vby in ["flag", "rep"]: vend["%s:%s" % [vs, vt]] = {"by": vby, "phase": str(ph["id"])}
		var after := _ledger_sum(s.rewards, hero)
		var d := {}
		for k in after: d[k] = int(after[k]) - int(before[k])
		var rp1: Dictionary = s.rewards.get("roles", {}).get("paid", {})
		var rpd := {}
		for rk in ["prestige", "beans", "uses"]: rpd[rk] = int(rp1.get(rk, 0)) - int(rp0.get(rk, 0))
		rows.append({"id": str(ph["id"]), "text": str(ph.get("text", "")), "episodes": eps, "sessions": ss, "format": fmt, "duals": eps, "won": eps - int(ph.get("lost", 0)), "hosted": n_host,
			"scraps": n_scr, "scraps_won": w_scr, "spars": n_spar, "spars_won": w_spar, "beats": n_beat, "quests": n_quest, "slots": slots_run, "game": s.training_best(hero), "earned": d, "level": s.level_of(hero), "roles": rpd,
			"districts": dists, "rep": s.rewards.get("rep", {}).get("of", {}).duplicate(), "rep_prestige": rep_paid})
		tot["episodes"] = int(tot["episodes"]) + eps; tot["duals"] = int(tot["duals"]) + eps; tot["won"] = int(tot["won"]) + eps - int(ph.get("lost", 0)); tot["sessions"] = float(tot["sessions"]) + ss
		tot["scraps"] = int(tot["scraps"]) + n_scr; tot["spars"] = int(tot["spars"]) + n_spar; tot["slots"] = int(tot["slots"]) + slots_run; tot["hosted"] = int(tot["hosted"]) + n_host
		tot["beats"] = int(tot["beats"]) + n_beat; tot["quests"] = int(tot["quests"]) + n_quest
		led = s.rewards.duplicate(true)
	var paid := _ledger_sum(led, hero)
	var bview: Array = bench.map(func(bc): return {"name": str(bc["card"]["name"]), "role": str(bc["role"]), "district": str(bc["card"]["district"]), "tier": int(bc["card"]["tier"])})
	return {"phases": rows, "counts": tot, "paid": paid, "hero": hero, "level": s.level_of(hero) if s != null else 1, "ledger": led, "hash": s.hash_state() if s != null else 0,
		"bench": bview, "bench_from": str(bn.get("from", "")) if seated else "", "roles_paid": led.get("roles", {}).get("paid", {"prestige": 0, "beans": 0, "uses": 0}).duplicate(),
		"rep": led.get("rep", {}).get("of", {}).duplicate(), "rep_prestige": rows.reduce(func(acc, r): return acc + int(r.get("rep_prestige", 0)), 0),
		"vendors": vend, "vendor_rep": vrep, "vendor_district": str(s.vendor_shop("techniques").get("district", s.vendor_shop("gear").get("district", ""))) if s != null else ""}

# ---- the sinks a story-pace player wants by Arc 3, priced from the live tables ----
static func spend_of(content: Dictionary, b: Dictionary) -> Dictionary:
	# what one obsolescence build bought, priced from the live tables off its ledger (not budget less what is left: its trials' spars
	# pay into the ledger as it builds): the ascensions climbed (the rarity's Spirits), the raises bought (their Beans, each at its
	# price then), the kit the shop sold (its shelf's HBP; a lesson and the board's wall are free), the gear the shop sold (its HBP)
	var nm := str(b["name"]); var led: Dictionary = b["ledger"]
	var s := TNBAudit.mk(content, 1, 7, b["lineup"], led)
	var g: Dictionary = led.get("growth", {}).get(nm, {})
	var sp := 0
	for t in range(2, int(g.get("rarity", 1)) + 1): sp += int(s.GROW.get("rarity", {}).get("spirits", {}).get(str(t), 0))
	var be := 0
	var rz: Dictionary = s.GROW.get("raises", {})
	for st in g.get("raises", {}):
		for i in int(g["raises"][st]): be += int(rz.get("base", 5)) + int(rz.get("step", 1)) * i
	var kit_h := 0; var bought: Array = []
	var lr: Dictionary = led.get("techniques", {}).get("learned", {}).get(nm, {})
	for mv in lr:
		if str(lr[mv]) == "shop":
			kit_h += int(s.TECH["shop"]["tiers"][s.shop_tier_of(str(mv))].get("hbp", 0)); bought.append(str(mv))
	var gear_h := 0; var pieces: Array = []
	var ow: Dictionary = led.get("gear", {}).get("owned", {})
	for id in ow:
		var it: Dictionary = s.gear_item(str(id))
		if str(it.get("source", "")) == "shop": gear_h += int(it.get("hbp", 0)) * int(ow[id]); pieces.append(str(id))
	return {"name": nm, "spirits": sp, "beans": be, "hbp": kit_h + gear_h, "kit_hbp": kit_h, "gear_hbp": gear_h, "kit": bought, "gear": pieces}

static func sinks(content: Dictionary, F: Dictionary, A: Dictionary, builds: Array) -> Dictionary:
	var spends: Array = builds.map(func(b): return spend_of(content, b))
	var per := {}
	for c in ["spirits", "beans", "hbp"]:
		per[c] = int(round(_median(spends.map(func(x): return int(x[c])))))
	var squad := int(F["desired"]["squad"])
	var fd: Dictionary = content.get("facilities", {})
	var tracks := int(fd.get("order", []).size())
	var fac := {"hbp": 0, "spirits": 0}
	for t in range(1, int(fd.get("max_tier", 3)) + 1):
		var td: Dictionary = fd.get("tiers", {}).get(str(t), {})
		fac["hbp"] = int(fac["hbp"]) + int(td.get("hbp", 0)) * tracks; fac["spirits"] = int(fac["spirits"]) + int(td.get("spirits", 0)) * tracks
	var fg: Dictionary = content.get("hybrids", {}).get("forge", {})
	var nf := int(F["desired"].get("forges", 0))
	var forge := {"spirits": int(fg.get("spirits", 0)) * nf, "beans": int(fg.get("beans", 0)) * nf}
	# PAC-098: the scouting machine (NP_08 s2.4) - every rare-tier lead it holds at the club's start, at the pity's pulls, at NP_11 s6's price
	var s0 := mk(content, "", TNBSim.LINEUP_MILLBROOK, {})
	var pull := int(s0.ECO.get("prestige", {}).get("pull", 0)); var pity := int(s0.ECO.get("prestige", {}).get("pity", 10))
	var rares: Array = s0.scout_rares() if pull > 0 and not s0.ECO.get("scouting", {}).is_empty() else []
	var scout := {"rares": rares.size(), "pity": pity, "pull": pull, "prestige": rares.size() * pity * pull}
	var want := {"spirits": int(per["spirits"]) * squad + int(fac["spirits"]) + int(forge["spirits"]), "hbp": int(per["hbp"]) * squad + int(fac["hbp"]), "beans": int(per["beans"]) * squad + int(forge["beans"]), "prestige": int(scout["prestige"])}
	return {"per_fighter": per, "spends": spends, "squad": squad, "facilities": fac, "tracks": tracks, "forge": forge, "forges": nf, "scout": scout, "want": want, "builds": builds.map(func(b2): return str(b2["name"]))}

# ---- the audit ----
static func run(content: Dictionary, F: Dictionary, A: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var smp: Dictionary = opts.get("sample_given", {}) if opts.has("sample_given") else sample(content, F, A, opts.get("sample", {}))
	var fc := faucet(content, F, smp, opts)
	var sk := sinks(content, F, A, smp["builds"])
	var tg: Dictionary = F["target"]; var p: Dictionary = F["pace"]; var bl: Dictionary = F["baselines"]
	var lo := float(tg["share"]) - float(tg["band"]); var hi := float(tg["share"]) + float(tg["band"])
	var fails := {}
	var share := {}
	for c in (["spirits", "hbp", "beans", "prestige"] if int(sk["want"]["prestige"]) > 0 else ["spirits", "hbp", "beans"]):
		share[c] = float(fc["paid"][c]) / float(maxi(1, int(sk["want"][c])))
		if float(share[c]) < lo or float(share[c]) > hi:
			fails[c] = "%s pays %s of the %s wanted by Arc 3 - %d%% against the %d%% target (%d-%d%%)" % [c.capitalize() if c != "hbp" else "HBP", _c(float(fc["paid"][c])), _c(float(sk["want"][c])), int(round(100.0 * float(share[c]))), int(round(100.0 * float(tg["share"]))), int(round(100.0 * lo)), int(round(100.0 * hi))]
	if int(sk["want"]["prestige"]) <= 0 and int(fc["paid"]["prestige"]) > 0 and not bool(opts.get("sinkless_ok", false)):
		fails["prestige"] = "Prestige pays %s by Arc 3 into no live sink - %s" % [_c(float(fc["paid"]["prestige"])), ", ".join(PackedStringArray(F.get("prestige_sinks_doc", [])))]
	# the session's pay against NP_11 s6's typical/session
	var ss := float(fc["counts"]["sessions"])
	var per_s := {"spirits": float(fc["paid"]["spirits"]) / ss, "hbp": float(fc["paid"]["hbp"]) / ss, "prestige": float(fc["paid"]["prestige"]) / ss, "beans_per_slot": float(fc["paid"]["beans"]) / float(maxi(1, int(fc["counts"]["slots"])))}
	var base_out := {}
	for k in per_s:
		var band: Array = bl.get(k, [0, 1 << 30])
		if float(per_s[k]) < float(band[0]) or float(per_s[k]) > float(band[1]): base_out[k] = "%.1f a %s against %d-%d" % [float(per_s[k]), "slot" if k == "beans_per_slot" else "session", int(band[0]), int(band[1])]
	for k in base_out:
		var c2 := "beans" if k == "beans_per_slot" else str(k)
		fails[c2] = (str(fails[c2]) + "; " if fails.has(c2) else "") + "%s %s (NP_11 s6's typical)" % [c2.capitalize() if c2 != "hbp" else "HBP", str(base_out[k])]
	# the protagonist's level against NP_11 s2's Arc 3
	var want_l := int(p["level_by_arc3"]); var lv := int(fc["level"])
	var xp_need := int(float(content["economy"]["xp"].get("curve_k", 48)) * float(want_l * want_l))
	if absi(lv - want_l) > int(p.get("level_band", 2)):
		fails["xp"] = "%s reaches level %d by Arc 3 (%s XP) - NP_11 s2's ~%d wants %s" % [str(fc["hero"]), lv, _c(float(fc["paid"]["xp"])), want_l, _c(float(xp_need))]
	# the obsolescence audit's budget against the faucet: its earliest three each funded, at its level
	var bd: Dictionary = A["budget"]; var n3 := int(A["earliest"].size())
	var budget := {}
	for c3 in ["spirits", "beans", "hbp"]:
		budget[c3] = {"need": int(bd[c3]) * n3, "paid": int(fc["paid"][c3]), "ok": int(bd[c3]) * n3 <= int(fc["paid"][c3])}
		if not bool(budget[c3]["ok"]):
			fails[c3] = (str(fails[c3]) + "; " if fails.has(c3) else "") + "the obsolescence audit's %s %s a fighter for its %d is %s, the faucet %s" % [_c(float(bd[c3])), c3 if c3 != "hbp" else "HBP", n3, _c(float(budget[c3]["need"])), _c(float(budget[c3]["paid"]))]
	budget["level"] = {"need": int(A["endgame"]["level"]), "paid": lv, "ok": lv >= int(A["endgame"]["level"])}
	if not bool(budget["level"]["ok"]):
		fails["xp"] = (str(fails["xp"]) + "; " if fails.has("xp") else "") + "the obsolescence audit builds at level %d" % int(A["endgame"]["level"])
	var sysn: Dictionary = F["systems"]
	var names: Array = []
	for c4 in ["xp", "spirits", "hbp", "beans", "prestige"]:
		if fails.has(c4): names.append(str(sysn.get(c4, c4)))
	return {"sample": smp, "faucet": fc, "sinks": sk, "share": share, "per_session": per_s, "budget": budget, "fails": fails, "systems": names, "green": fails.is_empty()}

static func lines(rep: Dictionary, F: Dictionary) -> Array:
	# the report, one line a finding, laid out for the milestone's log
	var out: Array = []
	var fc: Dictionary = rep["faucet"]; var sk: Dictionary = rep["sinks"]; var smp: Dictionary = rep["sample"]; var ct: Dictionary = fc["counts"]
	var tg: Dictionary = F["target"]; var bl: Dictionary = F["baselines"]
	out.append("FAUCETS :: NP_11 s6 - a story-pace playthrough to Arc 3's start: %d story duals (%d won, %d hosted), %s sessions of %d min - %d scraps, %d spars, %d training slots, %d story beats, %d quest steps" % [int(ct["duals"]), int(ct["won"]), int(ct["hosted"]), _c(float(ct["sessions"])), int(F["pace"]["session_minutes"]), int(ct["scraps"]), int(ct["spars"]), int(ct["slots"]), int(ct.get("beats", 0)), int(ct.get("quests", 0))])
	out.append("FAUCETS :: a segment's own XP, measured - won %d, lost %d (%d fights of the obsolescence audit's builds: %d won, %d lost%s)" % [int(smp["won"]), int(smp["lost"]), smp["fights"].size(), int(smp["n_won"]), int(smp["n_lost"]), ("; " + str(smp["note"])) if str(smp["note"]) != "" else ""])
	for r in fc["phases"]:
		var e: Dictionary = r["earned"]
		out.append("  %-12s %2d episodes, %s sessions (%s): %s +%s XP (L%d), Spirits +%s, HBP +%s, Prestige +%s, Beans +%s (%s)" % [str(r["id"]), int(r["episodes"]), _c(float(r["sessions"])), str(r["format"]), str(fc["hero"]), _c(float(e["xp"])), int(r["level"]), _c(float(e["spirits"])), _c(float(e["hbp"])), _c(float(e["prestige"])), _c(float(e["beans"])), str(r["game"])])
	if fc.get("bench", []).size() > 0:                                                                      # PAC-099: NP_08 s1's roles on the story-pace bench
		var rpp: Dictionary = fc["roles_paid"]
		out.append("FAUCETS :: the bench from %s (NP_08 s1's roles: %s) - the roles paid Prestige %d, Beans %d (to %s), staff uses %d" % [str(fc["bench_from"]), ", ".join(PackedStringArray(fc["bench"].map(func(b): return "%s %s (T%d, %s)" % [str(b["name"]), str(TNBSim.ROLE_LABELS.get(str(b["role"]), b["role"])), int(b["tier"]), str(b["district"])]))), int(rpp.get("prestige", 0)), int(rpp.get("beans", 0)), str(fc["hero"]), int(rpp.get("uses", 0))])
	if fc.get("rep", {}).size() > 0:                                                                        # PAC-101: the district rep the scraps raised, its milestones' Prestige
		out.append("FAUCETS :: district rep by Arc 3 (the scraps' districts by phase) - %s; the milestones paid Prestige %d" % [", ".join(PackedStringArray(fc["rep"].keys().map(func(k): return "%s %d" % [str(k), int(fc["rep"][k])]))), int(fc["rep_prestige"])])
	if fc.get("vendor_rep", {}).size() > 0:                                                                 # PAC-103: NP_02 s4's vendor tiers - each shelf's key at story pace
		var vk: Array = fc["vendors"].keys()                                                               # in the shops' order, each shop's shelves in order
		var ahead: Array = vk.filter(func(k): return str(fc["vendors"][k]["by"]) == "rep").map(func(k): return str(k).replace(":", " "))
		var vph: Array = fc["vendor_rep"].keys()
		out.append("FAUCETS :: the vendor tiers (NP_02 s4; the shops' district %s at rep %s by phase) - %s; by rep ahead of the story: %s" % [str(fc["vendor_district"]).to_upper(), "/".join(PackedStringArray(vph.map(func(k): return str(fc["vendor_rep"][k])))),
			", ".join(PackedStringArray(vk.map(func(k): return "%s by its %s (%s)" % [str(k).replace(":", " "), "flag" if str(fc["vendors"][k]["by"]) == "flag" else "rep", str(fc["vendors"][k]["phase"])]))),
			("%s - the HBP sinks open before their story beats" % ", ".join(PackedStringArray(ahead))) if ahead.size() > 0 else "none - the HBP sinks open with the story, as before"])
	var pd: Dictionary = fc["paid"]
	out.append("FAUCETS :: paid by Arc 3 - Spirits %s, HBP %s, Beans %s, Prestige %s; %s at level %d (%s XP)" % [_c(float(pd["spirits"])), _c(float(pd["hbp"])), _c(float(pd["beans"])), _c(float(pd["prestige"])), str(fc["hero"]), int(fc["level"]), _c(float(pd["xp"]))])
	var pf: Dictionary = sk["per_fighter"]; var w: Dictionary = sk["want"]
	out.append("FAUCETS :: wanted by Arc 3 - Spirits %s (%d x %s, the gym %s, %d Forge %s), HBP %s (%d x %s, the gym %s), Beans %s (%d x %s, the Forge %s), Prestige %s" % [_c(float(w["spirits"])), int(sk["squad"]), _c(float(pf["spirits"])), _c(float(sk["facilities"]["spirits"])), int(sk["forges"]), _c(float(sk["forge"]["spirits"])),
		_c(float(w["hbp"])), int(sk["squad"]), _c(float(pf["hbp"])), _c(float(sk["facilities"]["hbp"])), _c(float(w["beans"])), int(sk["squad"]), _c(float(pf["beans"])), _c(float(sk["forge"]["beans"])), ("%s (the machine's %d rare leads x %d pulls x %d)" % [_c(float(w["prestige"])), int(sk["scout"]["rares"]), int(sk["scout"]["pity"]), int(sk["scout"]["pull"])]) if int(w["prestige"]) > 0 else "no live sink"])
	for sp in sk["spends"]:
		out.append("  %-12s built as the obsolescence audit builds: Spirits %d (the ascensions), Beans %d (the raises), HBP %s (the kit %s: %s; the gear %s: %s)" % [str(sp["name"]), int(sp["spirits"]), int(sp["beans"]), _c(float(sp["hbp"])), _c(float(sp["kit_hbp"])), ", ".join(PackedStringArray(sp["kit"])) if sp["kit"].size() > 0 else "-", _c(float(sp["gear_hbp"])), ", ".join(PackedStringArray(sp["gear"])) if sp["gear"].size() > 0 else "-"])
	var sh: Dictionary = rep["share"]
	out.append("FAUCETS :: the shares - Spirits %d%%, HBP %d%%, Beans %d%%, Prestige %s (the target %d%%, %d-%d)" % [int(round(100.0 * float(sh["spirits"]))), int(round(100.0 * float(sh["hbp"]))), int(round(100.0 * float(sh["beans"]))), ("%d%%" % int(round(100.0 * float(sh["prestige"])))) if sh.has("prestige") else "-", int(round(100.0 * float(tg["share"]))), int(round(100.0 * (float(tg["share"]) - float(tg["band"])))), int(round(100.0 * (float(tg["share"]) + float(tg["band"]))))])
	var ps: Dictionary = rep["per_session"]
	out.append("FAUCETS :: a session pays - Spirits %.1f (%d-%d), HBP %.1f (%d-%d), Prestige %.1f (%d-%d), Beans a slot %.1f (%d-%d)" % [float(ps["spirits"]), int(bl["spirits"][0]), int(bl["spirits"][1]), float(ps["hbp"]), int(bl["hbp"][0]), int(bl["hbp"][1]), float(ps["prestige"]), int(bl["prestige"][0]), int(bl["prestige"][1]), float(ps["beans_per_slot"]), int(bl["beans_per_slot"][0]), int(bl["beans_per_slot"][1])])
	var bg: Dictionary = rep["budget"]
	out.append("FAUCETS :: the obsolescence budget, its three funded - Spirits %s of %s, Beans %s of %s, HBP %s of %s; level %d of L%d" % [_c(float(bg["spirits"]["need"])), _c(float(bg["spirits"]["paid"])), _c(float(bg["beans"]["need"])), _c(float(bg["beans"]["paid"])), _c(float(bg["hbp"]["need"])), _c(float(bg["hbp"]["paid"])), int(bg["level"]["need"]), int(bg["level"]["paid"])])
	for c in ["xp", "spirits", "hbp", "beans", "prestige"]:
		if rep["fails"].has(c): out.append("  %-9s %s" % [c.to_upper(), str(rep["fails"][c])])
	return out

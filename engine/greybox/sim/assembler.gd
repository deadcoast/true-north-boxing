extends RefCounted
# Loaded by preload("res://sim/assembler.gd") - no class_name (headless runs must not depend on the editor's class cache); preloads nothing.
# TRUE NORTH BOXING - the generic opponent assembler (NP_04 s9).
# A non-named opponent (a scrap's card, a spar's mockup, a dual's filler slot) is assembled from the pattern-piece library
# (data/pattern_pieces.v1.json): 2-3 strings from the Style's pool at or under the tier (an opener first; at tier 3 the
# Style's SPECIAL as the last), one PUNISH hook, every tell on the dialect's channel with its motifs, SELECT weights from the
# Style's preset, the interrupt block by tier, tells shifted into the tier's band and floored by class. The result is the
# compiled pattern shape the sim executes (meta, strings, select, interrupt, punish; bait, phases, desperation and idle empty).
# Deterministic from the spec: the same name, style, dialect, tier and seed assemble the same pattern every time.

static func assemble(pieces: Dictionary, spec: Dictionary) -> Dictionary:
	if pieces.is_empty() or not pieces.has("strings"): return {}
	var rules: Dictionary = pieces.get("rules", {})
	var style := str(spec.get("style", "BOXERPUNCHER"))
	var tier := clampi(int(spec.get("tier", 1)), 1, 3)
	var dialect := str(spec.get("dialect", rules.get("default_dialect", "gym")))
	var tell_d := dialect if pieces.get("dialects", {}).has(dialect) else str(rules.get("default_dialect", "gym"))
	var drec: Dictionary = pieces.get("dialects", {}).get(tell_d, {})
	var rng := RandomNumberGenerator.new(); rng.seed = int(spec.get("seed", 0))
	var n := int(rules.get("strings_by_tier", {}).get(str(tier), 2))
	# the pools: the Style's openers and others at or under the tier; the Style's SPECIAL at the tier it belongs to
	var openers: Array = []; var others: Array = []; var special := {}
	for p in pieces["strings"]:
		if str(p["style"]) != style or int(p["tier"]) > tier: continue
		if str(p["class"]) == "SPECIAL":
			if int(p["tier"]) == tier and tier >= int(rules.get("special_at_tier", 3)): special = p
			continue
		if str(p["role"]) == "opener": openers.append(p)
		else: others.append(p)
	var picked: Array = []
	if openers.size() > 0: picked.append(openers[rng.randi_range(0, openers.size() - 1)])
	var pool: Array = others.duplicate()
	for o in openers:
		if picked.is_empty() or str(o["id"]) != str(picked[0]["id"]): pool.append(o)
	var want := n - (1 if special.size() > 0 else 0)
	while picked.size() < want and pool.size() > 0:
		var i := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[i]); pool.remove_at(i)
	if special.size() > 0: picked.append(special)
	# PAC-093: a mirror's habits (NP_02 s2.2) - the fighter's own most-thrown sequences take the first slots, normal class on the
	# dialect's channel at the tier's loudness; the pieces fill what his record cannot, in their drawn order (the SPECIAL last, so
	# the first to go). With no habits nothing below changes: the same draws, the same pattern.
	var habits: Array = spec.get("habits", [])
	var hk := mini(habits.size(), n)
	if hk > 0: picked = picked.slice(0, n - hk)
	# the strings: the pieces dressed in the dialect's tells at the tier's loudness
	var strings := {}; var names: Array = []; var used: Array = []; var ids: Array = []
	for i in hk:
		var h: Dictionary = habits[i]
		var hname := "S%d" % (i + 1); names.append(hname); ids.append("habit:" + str(h.get("seq", "")))
		var hmotifs: Array = drec.get("motifs", {}).get("normal", ["tell"])
		var hmotif := _pick_motif(hmotifs, used, rng); used.append(hmotif)
		strings[hname] = {"label": str(h.get("label", "HABIT")), "tags": [], "tell": {"motif": hmotif, "ms": tell_ms(rules, tier, "normal", float(h.get("tell_ms", 450))), "channel": str(drec.get("channel", "visual-body"))},
			"class": "normal", "actions": h.get("actions", []).duplicate(), "piece": "habit", "tier": tier}
	for j in picked.size():
		var i := j + hk
		var p: Dictionary = picked[j]
		var sname := "S%d" % (i + 1); names.append(sname); ids.append(str(p["id"]))
		var cls := str(p["class"])
		var motifs: Array = drec.get("motifs", {}).get(cls, drec.get("motifs", {}).get("normal", ["tell"]))
		var motif := _pick_motif(motifs, used, rng); used.append(motif)
		strings[sname] = {"label": str(p["label"]), "tags": ["SPECIAL"] if cls == "SPECIAL" else [], "tell": {"motif": motif, "ms": tell_ms(rules, tier, cls, float(p["tell_ms"])), "channel": str(drec.get("channel", "visual-body"))},
			"class": cls, "actions": p["actions"].duplicate(), "piece": str(p["id"]), "tier": int(p["tier"])}
	# SELECT: the Style's preset for this many strings
	var wl: Array = pieces.get("styles", {}).get(style, {}).get("weights", {}).get(str(names.size()), [])
	var weights := {}
	for i in names.size(): weights[names[i]] = int(wl[i]) if i < wl.size() else 15
	if hk > 0:                                               # PAC-093: the habits share the preset's first hk weights by how much of his offense each is
		var share := 0; var tot := 0.0
		for i in hk: share += int(weights[names[i]]); tot += float(habits[i].get("n", 1))
		var left := share
		for i in hk:
			var w := maxi(1, int(round(float(share) * float(habits[i].get("n", 1)) / maxf(1.0, tot)))) if i < hk - 1 else maxi(1, left)
			weights[names[i]] = w; left -= w
	# INTERRUPT: by tier - every normal string at tier 1, the first two at tier 2, the opener alone at tier 3
	var rule := str(rules.get("interrupt_by_tier", {}).get(str(tier), "opener"))
	var brk: Array = []
	for i in names.size():
		if str(strings[names[i]]["class"]) != "normal": continue
		if rule == "all_normal" or (rule == "first_two" and i < 2) or (rule == "opener" and i == 0): brk.append(names[i])
	# PUNISH: one hook from the Style's pool at or under the tier, its placeholders resolved to the strings assembled
	var hooks: Array = []
	for h in pieces.get("punish", []):
		if str(h["style"]) == style and int(h["tier"]) <= tier: hooks.append(h)
	var punish: Array = []
	if hooks.size() > 0:
		var h: Dictionary = hooks[rng.randi_range(0, hooks.size() - 1)]
		punish.append({"trigger": str(h["trigger"]), "response": resolve(str(h["response"]), names), "piece": str(h["id"])})
	var meta := {"style": style, "element": str(spec.get("element", drec.get("element", "NONE"))), "house": str(spec.get("house", drec.get("house", "none"))), "slot": str(rules.get("slot", "R1")),
		"generic": true, "tier": tier, "dialect": dialect, "seed": int(spec.get("seed", 0)), "pieces": ids, "label": str(spec.get("label", spec.get("name", "")))}
	return {"file": "assembled", "id": "generic:" + str(spec.get("name", "")), "meta": meta, "idle": [], "strings": strings, "select": {"weights": weights, "reweights": []},
		"interrupt": [{"strings": brk, "response": str(rules.get("interrupt_response", "stagger(800)"))}] if brk.size() > 0 else [], "bait": [], "punish": punish, "phases": [], "desperation": {}}

static func tell_ms(rules: Dictionary, tier: int, cls: String, base: float) -> int:
	# the piece's Standard-band tell shifted into the tier's band (Loud / Standard / Subtle), never under its class floor (NP_04 s1, s3)
	var tt: Dictionary = rules.get("tell_tiers", {}).get(str(tier), {"band": [450, 700], "shift": 0})
	var band: Array = tt.get("band", [450, 700])
	var v := clampf(base + float(tt.get("shift", 0)), float(band[0]), float(band[1]))
	return int(maxf(v, float(rules.get("class_floors_ms", {}).get(cls, 400))))

static func resolve(resp: String, names: Array) -> String:
	if names.is_empty(): return resp
	var second: String = names[1] if names.size() > 1 else names[0]
	var third: String = names[2] if names.size() > 2 else names[names.size() - 1]
	return resp.replace("{lead}", str(names[0])).replace("{second}", second).replace("{third}", third)

static func _pick_motif(motifs: Array, used: Array, rng: RandomNumberGenerator) -> String:
	var fresh: Array = []
	for m in motifs:
		if not (str(m) in used): fresh.append(str(m))
	var from: Array = fresh if fresh.size() > 0 else motifs
	if from.is_empty(): return "tell"
	return str(from[rng.randi_range(0, from.size() - 1)])

static func default_stats(pieces: Dictionary, tier: int) -> Dictionary:
	var v := int(pieces.get("rules", {}).get("stats_by_tier", {}).get(str(clampi(tier, 1, 3)), 50))
	return {"PWR": v, "SPD": v, "CHN": v, "RFX": v, "BLK": v, "STA": v, "HRT": v}

static func describe(pat: Dictionary) -> String:
	# one line for the feed: what was assembled
	if pat.is_empty(): return ""
	var m: Dictionary = pat.get("meta", {})
	var parts: Array = []
	for k in pat.get("strings", {}):
		var s: Dictionary = pat["strings"][k]
		parts.append("%s %s (%s %dms%s)" % [str(k), str(s["label"]), str(s["tell"]["motif"]), int(s["tell"]["ms"]), ", SPECIAL" if str(s["class"]) == "SPECIAL" else ""])
	var pu: Array = pat.get("punish", [])
	return "GENERIC %s: %s / %s / %s dialect, tier %d :: %s :: punishes %s" % [str(m.get("label", "")), str(m.get("style", "")), str(m.get("element", "")), str(m.get("dialect", "")).capitalize(), int(m.get("tier", 1)), " | ".join(PackedStringArray(parts)), (str(pu[0]["trigger"]) + " -> " + str(pu[0]["response"])) if pu.size() > 0 else "nothing"]

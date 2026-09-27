extends RefCounted
# Loaded by preload("res://sim/save.gd") - no class_name (headless runs must not depend on the editor's class cache).
# TRUE NORTH BOXING - the save (NP_11 s9).
# A SaveGame is written from the sim's own ledgers and nothing else: the stable's cards with level / xp / bonds (the reward
# ledger), the currencies, the Scout Book (the PI ledger and the pages it has earned), the rematch remixes set, the ledger's
# day. The overworld's fields (story flags, staff, the walls, the codex) are carried under the schema's names; since PAC-087 the
# hybrid registry is the Forge's (the ledger keeps it) and the Beans are the ledger's; since PAC-089 Club.facility_tiers is the ledger's
# renovations and the Scout Book's pages are the ones on its shelf; since PAC-090 each Fighter carries his rarity, his board (layout, nodes
# taken, points free, the socket), his raises and his grown stats - views of the ledger's growth, which a load reads back; since PAC-091 his
# technique_slots (his own move, then the kit's), native_slots, signature_t0, the slots his level opens and what he learned, from where;
# since PAC-092 the settings name the academy when it is fielded; since PAC-093 the ledger carries the tracker's record; since PAC-094 each
# Fighter's gear (what he wears, a view of the ledger's locker); since PAC-099 his stable_role (the ledger's) and home_district; since PAC-100 his memory of a release (the ledger's locker keeps the releases waiting on their three days). When a fight is in flight a DualState (core.gd snapshot()) rides beneath it, and a load
# restores it to the same state hash. Numbers cross JSON as floats and come back as the ints the ledgers hold.
const TNBSim := preload("res://sim/core.gd")
const SAVE_SCHEMA := "SaveGame/NP_11-s9/v1.0"
const SAVE_VERSION := 1
const CARD_KEYS := ["name", "hissatsu", "style", "element", "house", "stats", "reserve", "signature", "surge_tier", "awakening_form", "hybrid_slot", "generic", "district"]   # what the sim reads from a card (PAC-077: the signature move behind an equipped native; PAC-085: the SURGE's choices; PAC-087: the hybrid his slot opens; PAC-090: a generic's card - his Awakening flag is the Legend's; PAC-099: a generic's home district)

static func fighter_record(sim, card: Dictionary) -> Dictionary:
	# NP_11 s9 Fighter, the fields the sim knows: the card as dressed, the level and xp from the ledger, the bonds from the pairs
	var nm := str(card.get("name", ""))
	var bonds: Array = []
	var keys: Array = sim.rewards.get("kizuna", {}).keys(); keys.sort()
	for key in keys:
		var ab: PackedStringArray = str(key).split("|")
		if ab.size() != 2 or not ab.has(nm): continue
		var other := str(ab[1]) if str(ab[0]) == nm else str(ab[0])
		bonds.append({"fighter_id": other, "kizuna": int(sim.rewards["kizuna"][key]), "level": sim.kizuna_level(nm, other)})
	var house := str(card.get("house", "none"))
	var rec := {"id": nm.to_lower(), "name": nm, "house_id": null if TNBSim.house_key(house) == "none" else house, "style": str(card.get("style", "")), "element": str(card.get("element", "")),
		"stats": card.get("stats", {}).duplicate(true), "level": sim.level_of(nm), "xp": sim.xp_of(nm), "technique_slots": [str(card.get("hissatsu", ""))], "bonds": bonds,
		"stable_role": sim.stable_role(nm), "hissatsu": str(card.get("hissatsu", "")), "house": house, "personality": {"talk_profile": str(card.get("talk", "")), "bark_set": ""}}   # PAC-099: the ledger's role (NP_08 s1)
	if not sim.ECO.get("roles", {}).is_empty(): rec["home_district"] = sim.home_district(nm)             # PAC-099: NP_11 s9 Fighter.home_district
	if card.has("district"): rec["district"] = str(card["district"])                                     # ...a generic's own, the card's (a load reads it back)
	if sim.has_method("memory_of") and sim.memory_of(nm).size() > 0: rec["memory"] = sim.memory_of(nm).duplicate()   # PAC-100: NP_08 s4 - a release remembered (a view of the ledger's locker)
	if card.has("reserve"): rec["reserve"] = bool(card["reserve"])
	var hs: String = sim.house_status(nm)
	rec["house_status"] = null if hs == "" else hs                                                       # PAC-077: NP_11 s9 Fighter.house_status - NATIVE / UNSANCTIONED
	rec["natives"] = sim.natives_unlocked(nm)                                                             # PAC-077: the house natives he may equip (read from the ledger, never stored)
	var tr: Dictionary = sim.card_trait(card)
	rec["trait"] = null if tr.is_empty() else str(tr["name"])                                             # PAC-078: the house trait he carries (NP_07 s3), read from the house table
	if card.has("signature"): rec["signature"] = str(card["signature"])
	for ck in ["surge_tier", "awakening_form", "hybrid_slot"]:                                            # PAC-085: the tier his SURGE casts, the tier his Awakening stacks (PAC-087: the hybrid his slot opens) - chosen between duals
		if card.has(ck): rec[ck] = str(card[ck])
	if bool(card.get("generic", false)): rec["generic"] = true
	if not sim.GROW.is_empty():                                                                           # PAC-090: NP_11 s9 Fighter.rarity / board / awakening_flag - views of the ledger's growth (a load reads the ledger)
		var g: Dictionary = sim._grow(nm)
		rec["rarity"] = sim.rarity_of(nm)
		rec["board"] = {"layout_id": sim.growth_layout(nm), "nodes_taken": g.get("board", []).duplicate(), "points_free": sim.gpoints_free(nm), "socket": str(g.get("socket", "")) if str(g.get("socket", "")) != "" else null}
		rec["raises"] = g.get("raises", {}).duplicate()
		rec["stats_grown"] = sim.grown_stats(card).duplicate()
		rec["passives"] = sim.passives_of(nm)
		rec["awakening_flag"] = sim.awaken_eligible(nm)
		rec["accessory_slots"] = sim.accessory_slots(nm)
	if not sim.GEAR.is_empty(): rec["gear"] = sim.gear_worn(nm)                                          # PAC-094: NP_11 s9 Fighter.gear [item_id, ...3] - a view of the ledger's locker
	if not sim.TECH.is_empty():                                                                           # PAC-091: NP_11 s9 Fighter.technique_slots / native_slots / signature_t0 - views of the ledger's techniques
		var kit: Array = sim.kit_moves(nm)
		var own := str(card.get("hissatsu", ""))
		var t0: Variant = null
		if sim.library.has(own) and str(sim.library[own]["tier"]) == "T0": t0 = own
		var ts: Array = [own]; var ns: Array = []
		for mv in kit:
			match sim.tech_class(str(mv)):
				"native": ns.append(str(mv))
				"t0": t0 = str(mv)
				_: ts.append(str(mv))
		rec["technique_slots"] = ts
		rec["native_slots"] = ns
		rec["signature_t0"] = t0
		rec["slots_open"] = sim.tech_slots(nm)
		rec["learned"] = sim.learned(nm).duplicate()
	rec["dressed"] = true                                                                                 # PAC-075: false for a stable card not dressed (to_save marks the bench)
	return rec

static func card_of(rec: Dictionary) -> Dictionary:
	# a Fighter record back to the card the sim dresses
	var c := {}
	for k in CARD_KEYS:
		if rec.has(k): c[k] = _intify(rec[k])
	var tp := str(rec.get("personality", {}).get("talk_profile", "")) if rec.get("personality") is Dictionary else ""
	if tp != "": c["talk"] = tp                                                                           # NP_11 s9 Fighter.personality.talk_profile -> the card's "talk" (PAC-072)
	return c

static func to_save(sim) -> Dictionary:
	# the SaveGame record, from the ledgers; deterministic (sorted where the ledgers' order is not meaningful) so a load writes it back byte-equal
	var stable: Array = []
	for f in sim.board_cards(): stable.append(fighter_record(sim, f))                                   # the sealed board's order and reserves (PAC-073); the card order when none is sealed
	var dn: Array = sim.dressed.map(func(x): return str(x["name"]))
	for f in sim.stable:                                                                                 # PAC-075: the rest of the stable, not dressed (a recruit on the bench)
		if not (str(f["name"]) in dn):
			var fr := fighter_record(sim, f); fr["dressed"] = false; stable.append(fr)
	var pages: Array = []
	var beaten: Array = sim.pi.get("bosses", {}).keys(); beaten.sort()
	for nm in beaten:
		var rec: Dictionary = sim.pi["bosses"][nm]
		if int(rec.get("beaten", 0)) > 0 and sim.shelved(str(nm)): pages.append(sim.scout_page(str(nm)))           # PAC-089: the pages on the shelf (a page waiting for the Film Room is the ledger's, not the book's)
		var rids: Array = rec.get("remixes", {}).keys(); rids.sort()
		for rid in rids:
			if int(rec["remixes"][rid]) > 0 and sim.shelved(TNBSim.page_key(str(nm), str(rid))): pages.append(sim.scout_page(str(nm), str(rid)))
	var roster: Array = []
	for f in stable: roster.append(str(f["name"]))
	return {"schema": SAVE_SCHEMA, "version": SAVE_VERSION,
		"calendar": {"day": int(sim.rewards.get("day", 1))},
		"story_flags": sim.rewards.get("story", {}).duplicate(true),
		"stable": stable,
		"staff": _staff_records(sim),
		"club": {"name": "MILLBROOK", "roster": roster, "facility_tiers": sim.facility_tiers()},              # PAC-089: NP_11 s9 Club.facility_tiers (the ledger holds them)
		"currencies": {"spirits": int(sim.rewards.get("spirits", 0)), "prestige": int(sim.rewards.get("prestige", 0)), "hbp": int(sim.rewards.get("hbp", 0)), "beans": int(sim.rewards.get("beans", 0))},   # PAC-087: the Beans the Forge spends
		"scout_book": {"pi_map": sim.pi.duplicate(true), "pages": pages},
		"string_wall": sim.string_wall(),                                                              # PAC-076: the wall as the ledger's view (the ledger holds it; a load recomputes it)
		"gym_wall": sim.gym_wall_view(),                                                               # PAC-079: the cards on their cells, the lines, the decorations
		"house_codex": sim.house_codex(),                                                              # PAC-077: the houses met, their lines and blessings
		"feud_graph_state": sim.graph_view(),                                                          # PAC-077: the graph as it stands (the ledger holds the flips)
		"hybrid_registry": sim.hybrid_registry(),                                                      # PAC-087: the Forge's records (the ledger holds them)
		"settings": _settings(sim),
		"remixes": sim.remix_for.duplicate(true),
		"ledgers": {"rewards": sim.rewards.duplicate(true)}}

static func _settings(sim) -> Dictionary:
	# the dual's setting: the format, the boss asked for, the assist; since PAC-092 the academy when it is fielded
	var st := {"format": str(sim.fmt.get("id", "mini")), "boss": int(sim._first_boss), "audio_assist": bool(sim.audio_assist)}
	if bool(sim.academy_on): st["academy"] = true
	return st

static func _staff_records(sim) -> Array:
	# NP_11 s9 Staff: the whole corps from the staff table and the ledger (level, uses), the dressed three flagged in their order (PAC-074)
	var out: Array = []
	for c in sim.STAFF.get("corps", []): out.append(sim.staff_record(str(c["id"])))
	return out

static func read(d) -> Dictionary:
	# a SaveGame record -> what a sim is built from; refuses another schema, naming it
	if not d is Dictionary: return {"ok": false, "why": "not a save record"}
	var schema := str(d.get("schema", ""))
	if schema != SAVE_SCHEMA: return {"ok": false, "why": "schema %s is not readable (this build writes %s)" % [schema if schema != "" else "(none)", SAVE_SCHEMA]}
	var settings: Dictionary = d.get("settings", {})
	var out := {"ok": true, "why": "", "version": int(d.get("version", 0)),
		"pi": _intify(d.get("scout_book", {}).get("pi_map", {})), "rewards": _intify(d.get("ledgers", {}).get("rewards", {})),
		"remix_for": d.get("remixes", {}).duplicate(true), "cards": [], "format": str(settings.get("format", "")), "boss": int(settings.get("boss", 0)),
		"audio_assist": bool(settings.get("audio_assist", false)), "academy": bool(settings.get("academy", false)), "day": int(d.get("calendar", {}).get("day", 1)), "dual": d.get("dual", {}), "staff_dressed": _dressed_of(d.get("staff", []))}
	out["gym_wall"] = _intify(d.get("gym_wall", {})) if d.get("gym_wall", {}) is Dictionary else {}      # Restore integer decoration tiers after JSON, like the other ledgers.
	out["bench"] = []
	for rec in d.get("stable", []):
		if rec is Dictionary: out["cards" if bool(rec.get("dressed", true)) else "bench"].append(card_of(rec))
	return out

static func _dressed_of(recs) -> Array:
	# the staff records flagged dressed, in their slot order
	var slots := {}
	if recs is Array:
		for r in recs:
			if r is Dictionary and bool(r.get("dressed", false)): slots[int(r.get("dressed_slot", 0))] = str(r.get("id", ""))
	var ks: Array = slots.keys(); ks.sort()
	var out: Array = []
	for k in ks: out.append(slots[k])
	return out

static func build(content: Dictionary, rd: Dictionary, seed_v: int) -> Dictionary:
	# a sim from a read save: the ledgers and the remixes from the bell, the stable's cards dressed, the format and the boss the save names;
	# a DualState beneath it is restored (its verdict returned)
	var sim = TNBSim.new()
	var cards: Array = rd.get("cards", [])
	sim.setup(content["tuning"], content["patterns"], TNBSim.BOSSES, cards if cards.size() > 0 else TNBSim.LINEUP_MILLBROOK, clampi(int(rd.get("boss", 0)), 0, TNBSim.BOSSES.size() - 1), seed_v,
		content.get("library", {}), content.get("tactics", {}), content.get("affinity", {}), content.get("feuds", []), content.get("coaches", {}), content.get("formats", {}), str(rd.get("format", "")),
		content.get("bouts", {}), content.get("scraps", {}), content.get("pattern_intel", {}), rd.get("pi", {}), content.get("remixes", {}), content.get("economy", {}), rd.get("rewards", {}), rd.get("remix_for", {}), content.get("pieces", {}), content.get("neutral", {}), content.get("talk", {}), content.get("formation", {}), content.get("staff", {}), content.get("recruits", {}), content.get("string_wall", {}), content.get("houses", {}), content.get("gym_wall", {}), content.get("transformations", {}), content.get("hybrids", {}), {}, content.get("facilities", {}), content.get("growth", {}), content.get("techniques", {}), content.get("academy", {}), content.get("gear", {}))
	if bool(rd.get("academy", false)):                                                                 # PAC-092: the academy fielded, as it was
		sim.field_academy(true); sim.new_dual()
	for bc in rd.get("bench", []): sim.stable.append(bc)                                                # PAC-075: the stable beyond the dressed (recruits not dressed) comes back too
	sim.gym_wall_restore(rd.get("gym_wall", {}))                                                        # PAC-079: the wall as it hung
	sim.audio_assist = bool(rd.get("audio_assist", false))
	var sd: Array = rd.get("staff_dressed", [])
	if sd.size() > 0 and sd != sim.staff_dressed():                                                     # PAC-074: the staff the save dressed, on a board of the stable's starters
		sim.seal_board({"slots": sim.sealed_p.slice(0, sim.board_k()), "staff": sd})
	var restored := {}
	var dual = rd.get("dual", {})
	if dual is Dictionary and dual.size() > 0: restored = sim.restore(dual)
	return {"sim": sim, "restored": restored}

static func write_text(sim, with_dual: bool = true) -> String:
	var d := to_save(sim)
	if with_dual and str(sim.mode) != "OVER": d["dual"] = sim.snapshot()
	return JSON.stringify(d, "  ", true, true)

static func read_text(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if parsed == null: return {"ok": false, "why": "not JSON"}
	return read(parsed)

static func write_file(path: String, sim, with_dual: bool = true) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(write_text(sim, with_dual)); f.close()
	return true

static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "why": "no file at %s" % path}
	return read_text(FileAccess.get_file_as_string(path))

static func _intify(v):
	# JSON hands every number back as a float; the ledgers hold counts, so a whole float is the int it was
	if v is float: return int(v) if v == floor(v) and absf(v) < 9.0e15 else v
	if v is Dictionary:
		var o := {}
		for k in v: o[k] = _intify(v[k])
		return o
	if v is Array:
		var o: Array = []
		for x in v: o.append(_intify(x))
		return o
	return v

static func summary(sim) -> String:
	# one line for the feed: what the save holds
	var xp: Array = []
	var names: Array = sim.rewards.get("xp", {}).keys(); names.sort()
	for nm in names: xp.append("%s L%d %d" % [str(nm), sim.level_of(str(nm)), sim.xp_of(str(nm))])
	var beaten := 0
	for nm in sim.pi.get("bosses", {}):
		if int(sim.pi["bosses"][nm].get("beaten", 0)) > 0: beaten += 1
	return "day %d, %s, %d Spirits / %d Prestige / %d HBP, %d bonds, PI on %d dialects, %d pages%s" % [int(sim.rewards.get("day", 1)), ", ".join(PackedStringArray(xp)) if xp.size() > 0 else "no XP yet", int(sim.rewards.get("spirits", 0)), int(sim.rewards.get("prestige", 0)), int(sim.rewards.get("hbp", 0)), sim.rewards.get("kizuna", {}).size(), sim.pi.get("dialects", {}).size(), beaten, (", %s in flight at R%d %.1fs" % [str(sim.bout.get("kind", "dual")) if sim.bout.size() > 0 else "a dual", sim.seg_idx + 1, float(sim.clock_t) / float(TNBSim.TICK_HZ)]) if str(sim.mode) != "OVER" else ""]

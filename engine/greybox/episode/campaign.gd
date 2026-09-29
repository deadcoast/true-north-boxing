extends RefCounted
## NP-12A / frozen VS_SCOPE. Episode state lives in the same saved reward ledger.
## Scene transitions never manufacture a hit, a segment win or a paid upgrade.
const Sim := preload("res://sim/core.gd")
const Save := preload("res://sim/save.gd")
const DATA_PATH := "res://episode/letter.v1.json"
const SCHEMA := "TheLetter/1"

static func state(sim) -> Dictionary:
	return sim.rewards.get("episode", {})

static func fresh(content: Dictionary, language: String, seed_value: int):
	var card: Dictionary = Sim.LINEUP_MILLBROOK[0].duplicate(true)
	card["name"] = "1976"; card["stats"] = {"PWR": 95, "SPD": 95, "CHN": 95, "RFX": 95, "BLK": 95, "STA": 95, "HRT": 99}
	var sim = Save.build(content, {"cards": [card], "format": "gauntlet", "rewards": {}}, seed_value)["sim"]
	sim.rewards["episode"] = {"schema": SCHEMA, "phase": "archive", "language": language, "dialogue": "archive", "line": 0, "position": [0.0, 6.0], "flags": {}, "fight": "", "visits": [], "metrics": {"played_seconds": 0.0, "world_seconds": 0.0, "training": [], "bouts": []}}
	return sim

static func archive(sim) -> void:
	var spec: Dictionary = sim.generic_spec("lakehead_1976", "SLUGGER", "gym", 1, 1976, "LAKEHEAD · 1976")
	sim.set_generic_slot(0, spec)
	for string in sim.gpatterns["lakehead_1976"]["strings"].values():
		string["class"] = "loud"; string["tell"]["ms"] = maxi(900, int(string["tell"]["ms"]))
		# Slugger pieces alone contain only arcs. The authored confidence lesson
		# leads those assembled combinations with a jab so a slip is teachable.
		string["actions"].push_front("JAB")
	sim.fmt["segments"] = 1; sim.fmt["dressed"] = 1; sim.fmt["enemy_dressed"] = 1; sim.fmt["sudden_death"] = false
	sim.new_dual(); sim.tension = 80.0; sim.score_p = 4; sim.score_b = 4
	state(sim)["fight"] = "archive"; state(sim)["phase"] = "fight"; state(sim)["lesson"] = 0
	state(sim).erase("slipped"); state(sim).erase("abb_tick")

static func present(content: Dictionary, old):
	var ep: Dictionary = state(old).duplicate(true)
	var card: Dictionary = Sim.LINEUP_MILLBROOK[0].duplicate(true)
	card["stats"] = {"PWR": 28, "SPD": 30, "CHN": 28, "RFX": 30, "BLK": 28, "STA": 30, "HRT": 99}
	var sim = Save.build(content, {"cards": [card], "format": "gauntlet", "rewards": {}}, old.rng.seed)["sim"]
	ep["phase"] = "shadow"; ep["fight"] = ""; ep["dialogue"] = "present"; ep["line"] = 0
	ep["flags"]["archive"] = true; sim.rewards["episode"] = ep
	return sim

static func has(sim, flag: String) -> bool:
	return bool(state(sim).get("flags", {}).get(flag, false))

static func mark(sim, flag: String) -> void:
	state(sim)["flags"][flag] = true
	sim.story_mark("episode:" + flag)

static func join(sim, name: String) -> bool:
	var gates := {"PRIYA": "priya_trial", "MARCUS": "scrap_2", "JUNE": "scrap_3"}
	if not gates.has(name) or not has(sim, gates[name]): return false
	if not sim._stable_card(name).is_empty(): return true
	for source in Sim.LINEUP_MILLBROOK:
		if str(source["name"]) != name: continue
		var card: Dictionary = source.duplicate(true); card.erase("reserve")
		sim.stable.append(card); mark(sim, "joined_" + name)
		sim._gw_pin_new(name, "RORY"); return true
	return false

static func ready(sim) -> bool:
	return ["letter", "scrap_1", "joined_PRIYA", "joined_MARCUS", "joined_JUNE"].all(func(k): return has(sim, k))

static func prepare(content: Dictionary, old):
	if not ready(old): return null
	var record: Dictionary = Save.read(Save.to_save(old))
	var squad: Array = []
	for name in ["MARCUS", "PRIYA", "RORY", "JUNE"]:
		var card: Dictionary = old._stable_card(name).duplicate(true)
		card["reserve"] = name == "JUNE"; squad.append(card)
	record["cards"] = squad; record["bench"] = old.stable.filter(func(c): return not str(c["name"]) in ["MARCUS", "PRIYA", "RORY", "JUNE"])
	record["format"] = "mini"; record["boss"] = Sim.BOSSES.find("cassidy_vane"); record["dual"] = {}
	var sim = Save.build(content, record, old.rng.seed)["sim"]
	var ep: Dictionary = state(sim); ep["fight"] = "survival"; ep["phase"] = "board"
	ep.erase("vane_intro")
	ep["dialogue"] = ""; ep["line"] = 0
	var first: Dictionary = sim.generic_spec("ascendant_seed", "OUTBOXER", "cassidy_vane", 1, 1976, "ASCENDANT · SEEDED OUT-BOXER")
	var second: Dictionary = sim.generic_spec("ascendant_r2", "SLUGGER", "cassidy_vane", 1, 2026, "ASCENDANT · R2")
	sim.set_generic_slot(0, first); sim.set_generic_slot(1, second)
	# A deterministic third-exchange right lead is the fact Priya discovered on tape.
	var pattern: Dictionary = sim.gpatterns["ascendant_r2"]
	pattern["punish"] = [] # The signed tape cycle owns every opener in this story slot.
	var ids: Array = pattern["strings"].keys()
	if not ids.is_empty():
		var right: Dictionary = pattern["strings"][ids[0]].duplicate(true)
		right["actions"] = ["R_STR"]
		pattern["strings"]["TAPE_RIGHT"] = right
		pattern["select"]["cycle"] = [ids[0], ids[mini(1, ids.size() - 1)], "TAPE_RIGHT"]
	# Vane remains her complete compiled pattern; the two filler slots use the assembler.
	sim.new_dual(); sim.seal_board({"slots": ["MARCUS", "PRIYA", "RORY"], "staff": sim.staff_dressed()})
	return sim

static func result(sim, event: Dictionary) -> Dictionary:
	var ep := state(sim)
	if ep.is_empty() or ep.get("fight", "") == "": return {}
	var fight := str(ep["fight"])
	if fight == "archive": return {}
	if not event.get("kind") in ["bout_end", "dual_end"]: return {}
	var win: bool = str(event.get("verdict", "")).begins_with("SCRAP WON")
	if fight == "mockup": win = bool(event.get("won", false))
	if fight == "priya_trial": win = true # NP-12A: either result; the trial was actually fought.
	if fight == "survival": win = sim.seg_wins_p >= 2
	ep["metrics"]["bouts"].append({"fight": fight, "verdict": event.get("verdict", ""), "segment_wins": sim.seg_wins_p, "won": win, "tick": sim.tick})
	ep["fight"] = ""; ep["phase"] = "world"
	if win:
		mark(sim, fight)
		if fight == "survival": sim.story_mark("story:charter_saved"); ep["phase"] = "tag"
	return {"fight": fight, "won": win}

static func validate(ep) -> String:
	if not ep is Dictionary or ep.get("schema", "") != SCHEMA: return "Unknown episode save"
	if not ep.get("phase", "") in ["archive", "shadow", "world", "fight", "board", "tag", "complete"]: return "Unknown episode scene"
	if not ep.get("flags") is Dictionary or not ep.get("position") is Array or ep["position"].size() != 2: return "Incomplete episode save"
	if not ep.get("language", "") in ["en", "fr_CA"]: return "Unknown episode language"
	for value in ep["position"]:
		if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)) > 100: return "Invalid episode position"
	for value in ep["flags"].values():
		if not value is bool: return "Invalid episode flag"
	var scenes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))["scenes"]
	var dialogue: String = str(ep.get("dialogue", ""))
	if dialogue != "" and not scenes.has(dialogue): return "Unknown episode dialogue"
	if not (ep.get("line") is int or ep.get("line") is float): return "Invalid dialogue position"
	if int(ep["line"]) < 0 or (dialogue != "" and int(ep["line"]) >= scenes[dialogue].size()): return "Invalid dialogue position"
	if not ep.get("fight", "") in ["", "archive", "scrap_1", "scrap_2", "scrap_3", "priya_trial", "mockup", "survival"]: return "Unknown episode fight"
	if not ep.get("metrics") is Dictionary: return "Missing episode metrics"
	for key in ["bouts", "training"]:
		if not ep["metrics"].get(key) is Array: return "Invalid episode metrics"
	for bout in ep["metrics"]["bouts"]:
		if not bout is Dictionary or not bout.get("fight") is String or not bout.get("won") is bool: return "Invalid bout record"
		var wins = bout.get("segment_wins")
		if not (wins is int or wins is float) or not is_finite(float(wins)) or float(wins) < 0: return "Invalid segment record"
	for drill in ep["metrics"]["training"]:
		if not drill is Dictionary or not drill.get("game") is String: return "Invalid training record"
	for key in ["counters", "interrupts", "first_drop_seconds", "combat_seconds", "gassed_seconds"]:
		var value = ep["metrics"].get(key, 0)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0: return "Invalid combat metric"
	for key in ["segments", "r2_tells", "r2_cycles"]:
		if ep["metrics"].has(key) and not ep["metrics"][key] is Array: return "Invalid combat history"
	for cycle in ep["metrics"].get("r2_cycles", []):
		if not cycle is Array: return "Invalid opponent cycle"
	if not ep.get("visits", []) is Array: return "Invalid district history"
	if not ep.get("pending_events", []) is Array: return "Invalid episode event queue"
	for event in ep.get("pending_events", []):
		if not event is Dictionary or not event.get("kind") is String: return "Invalid episode event"
	for key in ["played_seconds", "world_seconds"]:
		var value = ep["metrics"].get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0: return "Invalid episode clock"
	if ep.has("training"):
		var drill = ep["training"]
		if not drill is Dictionary or not drill.get("game", "") in ["shadow", "mitts", "roadwork"]: return "Invalid coaching drill"
		for key in ["t", "score", "beats", "accepted", "index"]:
			var value = drill.get(key)
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0: return "Invalid coaching progress"
		if not drill.get("intro") is bool or not drill.get("hit") is bool or not drill.get("sequence") is Array or drill["sequence"].size() != 6: return "Incomplete coaching drill"
		for row in drill["sequence"]:
			if not row in ["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_HOOK", "L_UPPERCUT", "R_UPPERCUT"]: return "Invalid coaching combination"
	for pair in [["joined_PRIYA", "priya_trial"], ["joined_MARCUS", "scrap_2"], ["joined_JUNE", "scrap_3"]]:
		if ep["flags"].get(pair[0], false) and not ep["flags"].get(pair[1], false): return "Recruitment evidence missing"
	if ep["flags"].get("survival", false):
		var qualified := false
		for bout in ep["metrics"]["bouts"]:
			if bout is Dictionary and bout.get("fight") == "survival" and int(bout.get("segment_wins", 0)) >= 2 and bout.get("won", false): qualified = true
		if not qualified: return "Charter result missing"
	if ep["phase"] in ["tag", "complete"] and not ep["flags"].get("survival", false): return "Charter not earned"
	return ""

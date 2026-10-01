extends RefCounted
## Learned mechanical domains, independent of archetype, stats and powers.
## These tuning values realize the supplied stance; they are not measurements.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sim/boxing_techniques.v1.json"))

static func equip(fighter: Dictionary, card: Dictionary) -> Array:
	var provided = card.get("boxing_training",catalog["fighter_defaults"].get(str(card.get("name","")).to_upper(),{}))
	if not provided is Dictionary: return ["Boxing training requires explicit compatible domains."]
	var request: Dictionary = provided.duplicate(true)
	var errors := []
	if card.has("stance") and not card["stance"] in ["orthodox","southpaw"]: errors.append("Unknown stance; select orthodox or southpaw.")
	var guard = request.get("guard","")
	if not guard is String or (guard != "" and not catalog["guards"].has(guard)): errors.append("Select one known guard; incompatible guards cannot be averaged.")
	var learned = request.get("learned",{})
	if not learned is Dictionary: errors.append("Learned techniques require a proficiency map.")
	else:
		for skill in learned:
			if not skill in ["compact_rising","rangy_rising"] or not (learned[skill] is float or learned[skill] is int) or not is_finite(float(learned[skill])) or float(learned[skill]) < 0 or float(learned[skill]) > 1:
				errors.append("Invalid learned technique or proficiency: " + str(skill))
	var signatures = request.get("signatures",[])
	if not signatures is Array: errors.append("Signatures require a list of learned compositions.")
	else:
		for signature in signatures:
			if not signature in ["northern_rising","northern_ladder","rising_exit"]: errors.append("Unknown signature: " + str(signature))
	if not errors.is_empty(): return errors # Preserve the last valid equipment.
	fighter["boxing_training"] = {"version":int(catalog["version"]),"guard":guard,"learned":learned,"signatures":signatures}
	if card.has("stance") and card["stance"] in ["orthodox","southpaw"]: fighter["stance"] = card["stance"]
	return errors

static func guard_profile(fighter: Dictionary) -> Dictionary:
	return catalog["guards"].get(str(fighter.get("boxing_training",{}).get("guard","")),{})

static func route(fighter: Dictionary, other: Dictionary, row: String, mods: Array) -> Dictionary:
	if not "UPPER" in row and not "HOOKERCUT" in row: return {}
	var distance := Vector2(fighter["pos"]).distance_to(other["pos"])
	var lead := row.begins_with("R_") if fighter.get("stance","orthodox") == "southpaw" else row.begins_with("L_")
	var kind := "shovel" if "BODY" in mods else ("rangy" if distance > 1.65 else ("probe" if lead and distance > 1.45 and not "POWER" in mods else "compact"))
	var authored: Dictionary = catalog["routes"][kind]
	var proficiency := float(fighter.get("boxing_training",{}).get("learned",{}).get(authored["skill"],0))
	if proficiency <= 0: return {} # The ordinary shared uppercut remains available.
	var selected := authored.duplicate()
	selected.merge({"id":kind,"lead":lead,"proficiency":proficiency})
	# Training improves preparation/return economy, never bone length or hit chance.
	selected["drop"] *= lerpf(1.18,1.0,proficiency)
	selected["startup"] *= lerpf(1.10,1.0,proficiency)
	selected["recovery"] *= lerpf(1.12,1.0,proficiency)
	selected["effort"] *= lerpf(1.10,1.0,proficiency)
	return selected

static func observe(fighter: Dictionary) -> Array:
	# Recognize player/AI compositions after real simulation events. This never
	# injects a punch, moves a root, grants damage or changes contact results.
	var boxing: Dictionary = fighter.get("boxing",{})
	var learned: Array = fighter.get("boxing_training",{}).get("signatures",[])
	if learned.is_empty() or boxing.is_empty(): return []
	var now := int(boxing["clock"])
	var flow: Dictionary = boxing.get("technique_flow",{"seen":0,"windows":{},"completed":[]})
	boxing["technique_flow"] = flow
	var windows: Dictionary = flow["windows"]
	var action: Dictionary = boxing.get("action",{})
	var staggered: bool = action.get("phase","") == "recovery" and int(fighter.get("busy_t",0)) > int(action["recovery_ticks"])-int(action["return_t"])+1
	if action.get("phase","") == "cancelled" or int(fighter.get("guard_open_t",0)) > 0 or staggered:
		windows.clear()
	for key in windows.keys():
		if now > int(windows[key]["until"]): windows.erase(key)
	var result: Dictionary = boxing.get("contact",{})
	var completed := []
	if int(result.get("attack_id",0)) > int(flow["seen"]):
		flow["seen"] = result["attack_id"]
		var selected: Dictionary = action.get("technique",{})
		var kind := str(selected.get("id",""))
		if result.get("kind") != "hit": windows.clear()
		else:
			if kind == "compact" and bool(selected.get("lead",false)) and "northern_ladder" in learned:
				windows["northern_ladder"] = {"until":now+100,"origin":fighter["pos"]}
			elif kind == "compact" and not bool(selected.get("lead",true)) and windows.has("northern_ladder"):
				completed.append("northern_ladder"); windows.erase("northern_ladder")
			elif windows.has("northern_ladder"): windows.erase("northern_ladder")
			if kind == "rangy" and bool(action.get("rising_counter",false)) and "northern_rising" in learned:
				windows["northern_rising"] = {"until":now+120,"origin":fighter["pos"],"forward":action["forward"]}
			if kind in ["compact","shovel"] and "rising_exit" in learned:
				windows["rising_exit"] = {"until":now+120,"origin":fighter["pos"],"forward":action["forward"],"travel":false}
	# A completed/shortened/blocked step is judged by displacement, not input.
	for key in ["northern_rising","rising_exit"]:
		if not windows.has(key): continue
		var window: Dictionary = windows[key]
		var delta: Vector2 = fighter["pos"] - Vector2(window["origin"])
		var forward := Vector2(window["forward"].x,window["forward"].z)
		var outward := delta.dot(forward) < -0.08
		var diagonal := absf(delta.cross(forward)) > 0.08
		var step: Dictionary = fighter.get("body_control",{}).get("step",{})
		if outward and diagonal and float(step.get("travel",0)) > 0.12:
			if key == "northern_rising": completed.append(key); windows.erase(key)
			else: window["travel"] = true
		if key == "rising_exit" and bool(window.get("travel",false)) and not step.is_empty() and action.get("phase","") == "flight" and (str(action.get("row","")).ends_with("STRAIGHT") or str(action.get("row","")).ends_with("HOOK")):
			completed.append(key); windows.erase(key)
	for key in completed:
		flow["completed"].append({"id":key,"tick":now})
		if flow["completed"].size() > 12: flow["completed"].pop_front()
	return completed

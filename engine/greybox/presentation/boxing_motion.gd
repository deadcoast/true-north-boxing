extends RefCounted
## Boxing pose solver. Inputs come from the fixed combat clock, never render delta.
## The channels decompose the user's connected pivot/core/shoulder/arm sequence;
## they are implementation stages, not a claim of biomechanical validation.
const STANCES := {
	"BOXERPUNCHER": {"width": 0.19, "lead": 0.19, "crouch": 0.025, "guard": 0.0, "coil": 1.0},
	"OUTBOXER": {"width": 0.17, "lead": 0.25, "crouch": 0.0, "guard": 0.08, "coil": 0.85},
	"SWARMER": {"width": 0.21, "lead": 0.16, "crouch": 0.07, "guard": -0.03, "coil": 1.1},
	"SLUGGER": {"width": 0.24, "lead": 0.22, "crouch": 0.035, "guard": -0.015, "coil": 1.15}}
var last_tick := -1
var feet: Array = []
var step := {}
var next_foot := 0
var guard := 0.0
var previous_origin := Vector3.ZERO

static func ramp(value: float) -> float:
	var x := clampf(value, 0, 1)
	return x * x * (3 - 2 * x)

static func chain(row: String, progress: float, recovery: float, coil := 1.0) -> Dictionary:
	var active := 0.0 if row == "" else 1.0
	var retract := 1.0 - ramp(recovery)
	var side := -1.0 if row.begins_with("L_") else 1.0
	var hook := "HOOK" in row; var upper := "UPPER" in row or "HOOKERCUT" in row
	var rotation := 0.20 if row == "L_STRAIGHT" else (0.80 if hook else 0.52)
	var load := sin(clampf(progress, 0, 1) * PI) * (0.32 if hook or upper else 0.13)
	# Staggered onset: pressure/pivot, hips, ribcage, scapula, then delivery.
	# All channels recover continuously and reach neutral at recovery == 1.
	return {"plant": active * ramp(progress / 0.45) * retract,
		"drive": active * (ramp((progress - 0.03) / 0.55) - load) * retract,
		"hips": active * side * (rotation * ramp((progress - 0.07) / 0.65) - load) * retract * coil,
		"core": active * side * (rotation * 0.38 * ramp((progress - 0.13) / 0.68) - load * 0.4) * retract * coil,
		"shoulder": active * ramp((progress - 0.20) / 0.66) * retract,
		"upper_arm": active * ramp((progress - 0.24) / 0.76) * retract,
		"forearm": active * ramp((progress - 0.38) / 0.62) * retract,
		"fist": active * ramp((progress - 0.66) / 0.34) * retract,
		"load": active * load * retract, "side": side, "upper": upper, "hook": hook}

static func elbow(shoulder: Vector3, wrist: Vector3, bend: Vector3, curved_delivery := 0.0) -> Vector3:
	var axis := wrist - shoulder
	var normal := bend - axis.normalized() * bend.dot(axis.normalized())
	if normal.length_squared() < 0.001: normal = Vector3.UP.cross(axis).normalized()
	# Keep the elbow's plane stable as the arm straightens. No flipped IK pole.
	var bow := maxf(0.015, 0.25 * (1.0 - clampf(axis.length() / 1.5, 0, 1)))
	# Hooks and uppercuts deliver with a bent elbow. Using the straight's
	# extension here makes every family straighten into the same contact pose.
	bow = lerpf(bow, axis.length() * 0.5, clampf(curved_delivery, 0, 1))
	return (shoulder + wrist) * 0.5 + normal.normalized() * bow

func footwork(origin: Vector3, forward: Vector3, right: Vector3, tick: int, stance: Dictionary) -> Array:
	var wanted: Array = []
	for i in 2:
		wanted.append(origin + right * (-1 if i == 0 else 1) * float(stance["width"]) + forward * (1 if i == 0 else -1) * float(stance["lead"]))
	if feet.is_empty() or origin.distance_to(previous_origin) > 0.7 or tick < last_tick:
		feet = wanted.duplicate(); step.clear(); next_foot = 0
	if tick != last_tick:
		if step.is_empty():
			var i := next_foot
			if (feet[i] as Vector3).distance_to(wanted[i]) > 0.22 or (feet[1 - i] as Vector3).distance_to(wanted[1 - i]) > 0.38:
				if (feet[1 - i] as Vector3).distance_to(wanted[1 - i]) > 0.38: i = 1 - i
				var velocity := (origin - previous_origin) * 120.0 / maxf(1, tick - last_tick)
				step = {"index": i, "from": feet[i], "to": wanted[i] + velocity.limit_length(2.5) * 0.07, "at": tick}
		if not step.is_empty():
			var t := clampf(float(tick - int(step["at"])) / 18, 0, 1)
			feet[int(step["index"])] = (step["from"] as Vector3).lerp(step["to"], ramp(t)) + Vector3.UP * sin(PI * t) * 0.065
			if t >= 1: next_foot = 1 - int(step["index"]); step.clear()
		previous_origin = origin
	return [feet[0] - origin, feet[1] - origin]

func sample(fighter: Dictionary, other: Dictionary, tick: int, attack: Dictionary, head_offset: Vector3) -> Dictionary:
	var style: Dictionary = STANCES.get(str(fighter.get("style", "")), STANCES["BOXERPUNCHER"])
	var at: Vector2 = fighter["pos"]; var delta: Vector2 = other["pos"] - at
	var forward := Vector3(delta.x, 0, delta.y).normalized()
	if forward.length_squared() < 0.1: forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var origin := Vector3(at.x, 0, at.y)
	var dt := maxi(0, tick - last_tick) if last_tick >= 0 else 1
	var block := bool(fighter.get("blocking", false)) or int(fighter.get("guard_t", 0)) > 0
	guard = move_toward(guard, 1.0 if block else 0.0, float(dt) / 6)
	var row := str(attack.get("row", ""))
	var progress := float(attack.get("progress", 0)); var recovery := float(attack.get("recovery", 0))
	var motion := chain(row, progress, recovery, float(style["coil"]))
	var preload_weight := float(attack.get("preload", 0)) * (1.0 - ramp(progress))
	motion["hips"] -= float(motion["side"]) * preload_weight * 0.20
	motion["core"] -= float(motion["side"]) * preload_weight * 0.12
	motion["load"] += preload_weight * 0.22
	var base_turn := -0.22
	var hips_turn := base_turn + float(motion["hips"])
	var chest_turn := hips_turn + float(motion["core"])
	var crouch := float(style["crouch"]) + maxf(0, -head_offset.y) * 0.60
	var spring := float(motion["load"]) * (0.20 if motion["upper"] else 0.06)
	var drive := forward * float(motion["drive"]) * 0.10
	var pelvis := Vector3.UP * (0.79 - crouch - spring) + head_offset * Vector3(0.30, 0, 0.30) + drive
	var chest := pelvis + Vector3.UP * 0.39 + head_offset * Vector3(0.48, 0.25, 0.48)
	var soles := footwork(origin, forward, right, tick, style)
	var shoulders: Array = []; var elbows: Array = []; var wrists: Array = []; var twists: Array = []; var forearm_twists: Array = []; var knees: Array = []; var pivots: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var active := row.begins_with("L_") if i == 0 else row.begins_with("R_")
		var shoulder := chest + (right * side * 0.255 + Vector3.UP * 0.11).rotated(Vector3.UP, chest_turn)
		if active: shoulder += forward * float(motion["shoulder"]) * 0.12 + Vector3.UP * float(motion["shoulder"]) * 0.035
		var neutral: Vector3 = shoulder + right * side * 0.025 + forward * (0.21 + (float(style["guard"]) if i == 0 else 0.0)) + Vector3.UP * 0.08
		var covered := head_offset + Vector3.UP * 1.57 + right * side * 0.20 + forward * 0.17
		var hand: Vector3 = neutral.lerp(covered, ramp(guard))
		var twist := 0.0; var pronation := 0.0
		if active:
			var e := float(motion["upper_arm"])
			var target := forward * float(attack.get("reach", 1.3)) + Vector3.UP * (1.1 if attack.get("body", false) else float(attack.get("head_height", 1.55)))
			var curve := right * side * (0.62 if motion["hook"] else 0.03)
			if motion["upper"]: curve.y = -0.5
			elif "FLARED" in row: curve.y = 0.42
			hand += -forward * float(motion["load"]) * 0.50
			hand = hand.lerp(target, e) + curve * sin(e * PI)
			var turnover := side * (0.15 if motion["upper"] else PI * 0.5)
			pronation = turnover * 0.70 * float(motion["forearm"])
			twist = pronation + turnover * 0.30 * float(motion["fist"])
		var bend := right * side * (0.75 if motion["hook"] and active else 0.25) - Vector3.UP * (0.6 if motion["upper"] else 0.2) if motion["hook"] and active else right * side * 0.25 - Vector3.UP
		var curved := float(motion["upper_arm"]) if active and (motion["hook"] or motion["upper"]) else 0.0
		shoulders.append(shoulder); elbows.append(elbow(shoulder, hand, bend, curved)); wrists.append(hand); twists.append(twist); forearm_twists.append(pronation)
		var foot_turn := -side * 0.08
		if active: foot_turn += side * float(motion["plant"]) * (0.75 if motion["hook"] else 0.48)
		pivots.append(foot_turn)
		var hip := pelvis + (right * side * 0.14).rotated(Vector3.UP, hips_turn)
		knees.append(elbow(hip, soles[i] + Vector3.UP * 0.09, forward * 1.2 + right * side * 0.1))
	last_tick = tick
	return {"pelvis": pelvis, "chest": chest, "hips_turn": hips_turn, "chest_turn": chest_turn, "shoulders": shoulders,
		"elbows": elbows, "wrists": wrists, "twists": twists, "forearm_twists": forearm_twists, "feet": soles, "pivots": pivots, "knees": knees, "chain": motion, "guard": guard}

extends RefCounted
## Boxing pose solver. Inputs come from the fixed combat clock, never render delta.
## The channels decompose the user's connected pivot/core/shoulder/arm sequence;
## they are implementation stages, not a claim of biomechanical validation.
const Space := preload("res://presentation/rig_space.gd")
const BodyControl := preload("res://sim/body_control.gd")
const UPPER_ARM := 0.38
const FOREARM := 0.36
const THIGH := 0.43
const SHIN := 0.42
const STANCES := {
	# NP_06: neutral flex, mobile straight punching, compact pressure, loaded
	# power. These shape normalized motion, never the sim's time or stat edits.
	"BOXERPUNCHER": {"width": 0.19, "lead": 0.19, "crouch": 0.025, "guard": 0.0, "coil": 1.0, "turn": -0.22, "balance": 0.50, "step_ticks": 16.0, "lift": 0.055, "delivery": 0.0, "return": 1.15, "arc": 1.0, "cover": 0.0, "shoulder": 0.255, "bulk": 1.0},
	"OUTBOXER": {"width": 0.17, "lead": 0.25, "crouch": 0.0, "guard": 0.10, "coil": 0.85, "turn": -0.38, "balance": 0.43, "step_ticks": 14.0, "lift": 0.045, "delivery": -0.12, "return": 1.30, "arc": 0.85, "cover": 0.12, "shoulder": 0.245, "bulk": 0.94},
	"SWARMER": {"width": 0.21, "lead": 0.16, "crouch": 0.07, "guard": -0.03, "coil": 1.1, "turn": -0.10, "balance": 0.56, "step_ticks": 12.0, "lift": 0.035, "delivery": -0.06, "return": 1.40, "arc": 0.78, "cover": 0.38, "shoulder": 0.255, "bulk": 1.04},
	"SLUGGER": {"width": 0.24, "lead": 0.22, "crouch": 0.035, "guard": -0.015, "coil": 1.15, "turn": -0.28, "balance": 0.46, "step_ticks": 18.0, "lift": 0.05, "delivery": 0.10, "return": 1.05, "arc": 1.12, "cover": 0.18, "shoulder": 0.275, "bulk": 1.10}}

static func style_profile(fighter: Dictionary) -> Dictionary:
	var profile: Dictionary = STANCES.get(str(fighter.get("style", "")), STANCES["BOXERPUNCHER"]).duplicate()
	# NP_04 s8 supplies build descriptions, not anthropometric measurements.
	# Express breadth through the girdle and limbs. Head/body hit surfaces and
	# bone lengths remain the same combat contract for every build.
	match str(fighter.get("motion_identity", "")).to_upper().replace(" ", "_").replace("-", "_"):
		"YURI", "YURI_KOWALCHUK": profile.merge({"shoulder": 0.31, "bulk": 1.28, "width": 0.26}, true)
		"SAM", "SAM_TAGAQ": profile.merge({"shoulder": 0.29, "bulk": 1.18, "width": 0.23, "cover": 0.55}, true)
		"MARTA", "MARTA_OKONKWO_TREMBLAY": profile["cover"] = 0.48
	return profile
var last_tick := -1
var feet: Array = []
var step := {}
var guard := 0.0
var guard_level := 0.0
var previous_origin := Vector3.ZERO
var foot_yaw: Array = []
var lead_weight := 0.5
var support_shift := Vector3.ZERO
var elbow_tick := -1
var elbow_history: Array = []
var elbow_prior: Array = []
var knee_history: Array = []
var knee_prior: Array = []
var inside_extent := 1.0
var travel_ticks := 0

# Native simulation retains the solver's history as plain typed save data.
func state() -> Dictionary:
	var out := {}
	for key in ["last_tick", "feet", "step", "guard", "guard_level", "previous_origin", "foot_yaw", "lead_weight", "support_shift", "elbow_tick", "elbow_history", "elbow_prior", "knee_history", "knee_prior", "inside_extent", "travel_ticks"]:
		out[key] = get(key)
	return out.duplicate(true)

func restore_state(saved: Dictionary) -> void:
	for key in saved: set(key, saved[key])

static func ramp(value: float) -> float:
	var x := clampf(value, 0, 1)
	return x * x * (3 - 2 * x)

static func chain(row: String, progress: float, recovery: float, coil := 1.0, mods: Array = [], delivery_bias := 0.0, return_rate := 1.15) -> Dictionary:
	var active := 0.0 if row == "" else 1.0
	var retract := 1.0 - ramp(recovery)
	var side := -1.0 if row.begins_with("L_") else 1.0
	var hook := "HOOK" in row; var upper := "UPPER" in row or "HOOKERCUT" in row
	var power := 1.0 if "POWER" in mods else 0.0
	var haymaker := 1.0 if "HAYMAKER" in mods else 0.0
	var strength := 1.0 + power * 0.16 + haymaker * 0.28
	var rotation := (0.20 if row == "L_STRAIGHT" else (0.80 if hook else 0.52)) * strength
	var load := sin(clampf(progress, 0, 1) * PI) * ((0.32 if hook or upper else 0.13) + power * 0.16 + haymaker * 0.30)
	# A haymaker spends more of its already-authored startup loading the rear
	# side, then releases. Native contact may intercept this path before its end.
	var shaped := clampf(progress - delivery_bias * sin(progress * PI), 0, 1)
	var delivery := clampf((shaped - haymaker * 0.16) / (1.0 - haymaker * 0.16), 0, 1)
	var arm_return := 1.0 - ramp(recovery * return_rate)
	# Staggered onset: pressure/pivot, hips, ribcage, scapula, then delivery.
	# All channels recover continuously and reach neutral at recovery == 1.
	return {"plant": active * ramp(progress / 0.45) * retract,
		"drive": active * (ramp((progress - 0.03) / 0.55) - load) * retract,
		"hips": active * side * (rotation * ramp((progress - 0.07) / 0.65) - load) * retract * coil,
		"core": active * side * (rotation * 0.38 * ramp((progress - 0.13) / 0.68) - load * 0.4) * retract * coil,
		"shoulder": active * ramp((delivery - 0.20) / 0.66) * retract,
		"upper_arm": active * ramp((delivery - 0.24) / 0.76) * arm_return,
		"forearm": active * ramp((delivery - 0.38) / 0.62) * arm_return,
		"fist": active * ramp((delivery - 0.66) / 0.34) * arm_return,
		"load": active * load * retract, "side": side, "upper": upper, "hook": hook, "strength": strength}

static func joint(start: Vector3, end: Vector3, pole: Vector3, first: float, second: float) -> Dictionary:
	var axis := end - start
	var direction := axis.normalized() if axis.length_squared() > 0.000001 else Vector3.FORWARD
	var distance := clampf(axis.length(), absf(first - second) + 0.0001, first + second - 0.0001)
	var normal := pole - direction * pole.dot(direction)
	if normal.length_squared() < 0.000001:
		normal = direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0, first * first - along * along))
	return {"joint": start + direction * along + normal.normalized() * height, "end": start + direction * distance}

static func contact_goal(shoulder: Vector3, desired: Vector3, target: Vector3, radius: float, hit: bool) -> Vector3:
	var length := UPPER_ARM + FOREARM - 0.0002
	var goal := shoulder + (desired - shoulder).limit_length(length)
	var axis := target - shoulder
	var distance := axis.length()
	if hit and desired.distance_to(shoulder) > length and distance < length + radius:
		# Intersect the fixed arm's reach sphere with the target surface. Select
		# the point nearest the authored delivery path on that contact circle.
		var direction := axis / distance
		var along := (length * length - radius * radius + distance * distance) / (2.0 * distance)
		var center := shoulder + direction * along
		var pole := desired - center; pole -= direction * pole.dot(direction)
		if pole.length_squared() < 0.000001: pole = Vector3.UP.cross(direction)
		goal = center + pole.normalized() * sqrt(maxf(0, length * length - along * along))
	elif not hit and goal.distance_to(target) < radius:
		# An unreachable miss path may intersect the target when clamped.
		# Stop on the near side of that surface, with visible clearance.
		var direction := (goal - shoulder).normalized()
		var projected := axis.dot(direction)
		var near := projected - sqrt(maxf(0, radius * radius - axis.length_squared() + projected * projected))
		goal = shoulder + direction * maxf(0.03, near - 0.005)
	return goal

static func constrain(rig: Dictionary) -> Dictionary:
	# Poses are constrained at sampling, reaction and interpolation boundaries.
	# Remove our previous correction first so those calls cannot accumulate
	# chest lean or pelvis lowering. Authored/reaction edits remain intact.
	var prior_lean: Vector3 = rig.get("delivery_lean", Vector3.ZERO)
	var prior_lower := float(rig.get("support_lower", 0.0))
	rig["pelvis"].y += prior_lower
	rig["chest"] += Vector3.UP * prior_lower - prior_lean
	for i in 2:
		rig["hip_joints"][i].y += prior_lower
		rig["shoulders"][i] += Vector3.UP * prior_lower - prior_lean
	# Reconstruct the heel around the planted forefoot after interpolation;
	# lerping ankle positions independently cuts across the pivot's arc.
	var forward: Vector3 = rig["forward"].normalized()
	for i in 2:
		rig["ankles"][i] = rig["feet"][i] + Vector3.UP * 0.095 - forward.rotated(Vector3.UP, float(rig["pivots"][i])) * 0.08
	# Keep planted ankles reachable by lowering the pelvis, never lengthening
	# a thigh/shin or moving a planted boot to satisfy IK.
	var lower := 0.0
	for i in 2:
		var delta: Vector3 = rig["hip_joints"][i] - rig["ankles"][i]
		var available := sqrt(maxf(0.0001, pow(THIGH + SHIN - 0.0001, 2) - delta.x * delta.x - delta.z * delta.z))
		lower = maxf(lower, delta.y - available)
	if lower > 0:
		rig["pelvis"].y -= lower; rig["chest"].y -= lower
		for i in 2:
			rig["hip_joints"][i].y -= lower; rig["shoulders"][i].y -= lower
	rig["support_lower"] = lower
	# Called AFTER every pose blend, including render interpolation. Endpoints
	# and poles blend; independently interpolated cylinder transforms do not.
	# A long step-in transfers the chest above its base. When the target surface
	# lies outside arm reach, move the connected shoulder girdle; never bones.
	var lean := Vector3.ZERO
	var continuous_delivery := float(rig.get("continuous_delivery", 0.0)) > 0.5
	for i in 2:
		if not continuous_delivery and float(rig["contact_hits"][i]) < 0.5: continue
		# With continuous delivery, the requested path drives the shoulder.
		# Crossing a hit-region boundary cannot suddenly enable chest travel.
		var goal: Vector3 = rig["delivery_targets"][i] if continuous_delivery else rig["contact_centers"][i]
		var delta: Vector3 = goal - rig["shoulders"][i]
		var reach := UPPER_ARM + FOREARM - 0.002 + (0.0 if continuous_delivery else float(rig["contact_radii"][i]))
		var horizontal := Vector3(delta.x, 0, delta.z)
		var available := sqrt(maxf(0.001, reach * reach - delta.y * delta.y))
		var needed := maxf(0, horizontal.length() - available) * float(rig["contact_weights"][i])
		if needed > lean.length(): lean = horizontal.normalized() * needed
	rig["chest"] += lean
	for i in 2: rig["shoulders"][i] += lean
	rig["delivery_lean"] = lean
	for i in 2:
		var desired: Vector3 = rig["delivery_targets"][i]
		# Solve the requested arm pose continuously. The old hit/miss branch
		# manufactured a different wrist endpoint before a punch had resolved.
		var delivery := desired if continuous_delivery else contact_goal(rig["shoulders"][i], desired, rig["contact_centers"][i], float(rig["contact_radii"][i]), float(rig["contact_hits"][i]) >= 0.5)
		var hand: Vector3 = rig["hand_goals"][i] + (delivery - desired) * float(rig["contact_weights"][i])
		var pole: Vector3 = rig["arm_poles"][i]
		if float(rig.get("knee_stability", 0)) > 0:
			# Contact lean can move the shoulder after the preliminary pole was
			# chosen. Reproject history about the final shoulder and wrist, as for
			# planted knees, so close inside punches cannot flip the elbow plane.
			var axis: Vector3 = (hand - rig["shoulders"][i]).normalized()
			var prior: Vector3 = rig["support_elbows"][i] - rig["shoulders"][i]
			prior -= axis * prior.dot(axis)
			var wanted := pole - axis * pole.dot(axis)
			if prior.length_squared() > 0.000001 and wanted.length_squared() > 0.000001:
				pole = prior.normalized().slerp(wanted.normalized(), minf(0.4, 0.18 / maxf(prior.angle_to(wanted), 0.0001)))
		var arm := joint(rig["shoulders"][i], hand, pole, UPPER_ARM, FOREARM)
		if float(rig["arm_stability"][i]) > 0:
			# Carry the covered elbow along the upper-arm sphere through root
			# travel. Solve the forearm from it, rather than flipping IK branches.
			var shoulder: Vector3 = rig["shoulders"][i]
			var supported: Vector3 = shoulder + (rig["support_elbows"][i] - shoulder).normalized() * UPPER_ARM
			var direction := ((arm["joint"] as Vector3).lerp(supported, 0.65 * float(rig["arm_stability"][i])) - shoulder).normalized()
			arm["joint"] = shoulder + direction * UPPER_ARM
			arm["end"] = arm["joint"] + (hand - arm["joint"]).normalized() * FOREARM
		rig["elbows"][i] = arm["joint"]; rig["wrists"][i] = arm["end"]
		var knee_pole: Vector3 = rig["leg_poles"][i]
		if float(rig.get("knee_stability", 0)) > 0:
			# Use the final lowered hip, after contact/leg constraints. Projecting
			# about the unconstrained hip can select the opposite knee branch.
			var axis: Vector3 = (rig["ankles"][i] - rig["hip_joints"][i]).normalized()
			var prior: Vector3 = rig["support_knees"][i] - rig["hip_joints"][i]
			prior -= axis * prior.dot(axis)
			var wanted := knee_pole - axis * knee_pole.dot(axis)
			if prior.length_squared() > 0.000001 and wanted.length_squared() > 0.000001:
				knee_pole = prior.normalized().slerp(wanted.normalized(), minf(0.4, 0.18 / maxf(prior.angle_to(wanted), 0.0001)))
		var leg := joint(rig["hip_joints"][i], rig["ankles"][i], knee_pole, THIGH, SHIN)
		rig["knees"][i] = leg["joint"]
		# Pelvis is lowered to keep both planted ankles reachable before solving.
		rig["ankles"][i] = leg["end"]
	return rig

func footwork(origin: Vector3, forward: Vector3, right: Vector3, tick: int, stance: Dictionary, turns: Array = [], balance := 0.5, advance := 0.0, plant_hand := -1) -> Array:
	var wanted: Array = []
	for i in 2:
		wanted.append(origin + right * (-1 if i == 0 else 1) * float(stance["width"]) + forward * (1 if i == 0 else -1) * float(stance["lead"]))
		if i == 0: wanted[i] += forward * advance
	if feet.is_empty() or origin.distance_to(previous_origin) > 0.7 or tick < last_tick:
		feet = wanted.duplicate(); step.clear()
		foot_yaw = [atan2(forward.x, forward.z) + 0.08, atan2(forward.x, forward.z) - 0.08]
		lead_weight = 0.5; support_shift = Vector3.ZERO; previous_origin = origin
		travel_ticks = 0
	if tick != last_tick:
		var dt := maxi(1, tick - last_tick) if last_tick >= 0 else 1
		var velocity := ((origin - previous_origin) * 120.0 / dt).limit_length(3.0)
		var moving := velocity.length() > 0.05
		travel_ticks = travel_ticks + dt if moving else 0
		if step.is_empty():
			var errors := [(feet[0] as Vector3).distance_to(wanted[0]), (feet[1] as Vector3).distance_to(wanted[1])]
			# Open in the travel direction; then gather the trailing foot. A new
			# direction is judged against the actual stance, not an alternating timer.
			var i := 0 if (wanted[0] - wanted[1]).dot(velocity) >= 0 else 1
			if absf(float(errors[0]) - float(errors[1])) > 0.06 or not moving: i = 0 if errors[0] > errors[1] else 1
			# A punch's single-tick lunge is weight transfer, not walking. Keep
			# its driving foot down; the other foot can gather. Continuous root
			# travel releases this hold, so moving attacks never anchor a leg
			# behind the boxer. Already-airborne steps finish without snapping.
			if i == plant_hand and travel_ticks <= 1: i = 1 - i
			if float(errors[i]) > (0.025 if moving else 0.09):
				step = {"index": i, "from": feet[i], "to": wanted[i], "at": tick, "duration": float(stance.get("step_ticks", 16.0))}
		if not step.is_empty():
			var i := int(step["index"])
			var age := float(tick - int(step["at"]))
			# Three ticks of pressure transfer precede toe-off. The airborne foot
			# can redirect toward a stop/reversal; its planted partner never slides.
			var t := clampf((age - 3.0) / (float(step["duration"]) - 3.0), 0, 1)
			var target: Vector3 = wanted[i] + velocity * 0.055
			var side := -1.0 if i == 0 else 1.0
			var spacing: Vector3 = target - feet[1 - i]
			target += right * side * maxf(0, float(stance["width"]) * 1.25 - spacing.dot(right) * side)
			spacing = target - feet[1 - i]
			target -= forward * side * maxf(0, float(stance["lead"]) * 0.45 + spacing.dot(forward) * side)
			step["to"] = (step["to"] as Vector3).move_toward(target, 0.06 * dt)
			feet[i] = (step["from"] as Vector3).lerp(step["to"], ramp(t)) + Vector3.UP * sin(PI * t) * float(stance.get("lift", 0.055))
			var load := ramp(age / 3.0) * (1.0 - ramp((t - 0.72) / 0.28))
			lead_weight = lerpf(balance, 0.82 if i == 1 else 0.18, load)
			if t >= 1: step.clear()
		else: lead_weight = move_toward(lead_weight, balance, float(dt) / 12)
		for i in 2:
			var desired := atan2(forward.x, forward.z) + (float(turns[i]) if turns.size() == 2 else (0.08 if i == 0 else -0.08))
			foot_yaw[i] = float(foot_yaw[i]) + clampf(wrapf(desired - float(foot_yaw[i]), -PI, PI), -0.10 * dt, 0.10 * dt)
		var center: Vector3 = (feet[1] as Vector3).lerp(feet[0], lead_weight) - origin
		center.y = 0
		support_shift = support_shift.move_toward(center.limit_length(0.12), 0.018 * dt)
		previous_origin = origin
	return [feet[0] - origin, feet[1] - origin]

func sample(fighter: Dictionary, other: Dictionary, tick: int, attack: Dictionary, head_offset: Vector3) -> Dictionary:
	var style := style_profile(fighter)
	var at: Vector2 = fighter["pos"]; var delta: Vector2 = BodyControl.forward(fighter, other)
	var forward := Vector3(delta.x, 0, delta.y).normalized()
	if attack.has("forward"): forward = attack["forward"]
	if forward.length_squared() < 0.1: forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var origin := Space.ground(at)
	if tick != elbow_tick:
		elbow_prior = elbow_history.duplicate(); elbow_tick = tick
		knee_prior = knee_history.duplicate()
	var dt := maxi(0, tick - last_tick) if last_tick >= 0 else 1
	var block := bool(fighter.get("blocking", false)) or int(fighter.get("guard_t", 0)) > 0
	guard = move_toward(guard, 1.0 if block else 0.0, float(dt) / 6)
	guard_level = move_toward(guard_level,1.0 if fighter.get("guard_body",false) else 0.0,float(dt)/10.0)
	var row := str(attack.get("row", ""))
	var progress := float(attack.get("progress", 0)); var recovery := float(attack.get("recovery", 0))
	var mods: Array = attack.get("mods", [])
	var motion := chain(row, progress, recovery, float(style["coil"]), mods, float(style["delivery"]), float(style["return"]))
	# Inside hooks/rising punches shorten their body arc. A full outside swing
	# in the phone booth would drive the shoulder past the glove and reverse
	# the elbow axis. Contact time and target stay authoritative.
	var center: Vector3 = attack.get("target_center", forward * 1.0)
	var compact := clampf((Vector2(center.x, center.z).length() - 0.35) / 0.35, 0.40, 1.0)
	inside_extent = compact if last_tick < 0 else move_toward(inside_extent, compact, float(dt) * 0.035)
	compact = inside_extent if motion["hook"] or motion["upper"] else 1.0
	motion["hips"] *= compact; motion["core"] *= compact; motion["load"] *= compact
	var preload_weight := float(attack.get("preload", 0)) * (1.0 - ramp(progress))
	motion["hips"] -= float(motion["side"]) * preload_weight * 0.20
	motion["core"] -= float(motion["side"]) * preload_weight * 0.12
	motion["load"] += preload_weight * 0.22
	var turns := [0.08, -0.08]
	if row != "": turns[0 if row.begins_with("L_") else 1] += float(motion["side"]) * float(motion["plant"]) * (0.75 if motion["hook"] else 0.48) * float(motion["strength"])
	var balance := clampf(float(style["balance"]) - head_offset.dot(right) * 1.1 + head_offset.dot(forward) * 0.9, 0.2, 0.8)
	balance = clampf(balance + float(motion["drive"]) * (0.13 if row.begins_with("R_") else 0.06) - float(motion["load"]) * 0.12, 0.2, 0.8)
	# Gather around the delivered weight without lifting the working pivot.
	# Stepping punches and sustained locomotion can change that support; an
	# ordinary punch releases its base only as recovery unloads the drive.
	var plant_hand := (0 if row.begins_with("L_") else 1) if row != "" and recovery < 0.5 and not "STEPPING" in mods else -1
	var advance := maxf(0, float(motion["drive"])) * 0.13
	var soles: Array
	var body_state: Dictionary = fighter.get("body_control", {})
	if body_state.has("feet"):
		# The simulation owns support in the continuous foundation controller.
		# Sampling or dropping render frames cannot take a foot off the floor.
		soles = []
		foot_yaw = []
		for i in 2:
			soles.append(Space.ground(body_state["feet"][i]) - origin + Vector3.UP * float(body_state["foot_lift"][i]))
			foot_yaw.append(PI * 0.5 - float(body_state["foot_yaw"][i]))
		lead_weight = float(body_state["weight_lead"])
		support_shift = Vector3(soles[1]).lerp(soles[0], lead_weight).limit_length(0.12)
		support_shift.y = 0
	else:
		soles = footwork(origin, forward, right, tick, style, turns, balance, advance, plant_hand)
	var foot_turns := [wrapf(float(foot_yaw[0]) - atan2(forward.x, forward.z), -PI, PI), wrapf(float(foot_yaw[1]) - atan2(forward.x, forward.z), -PI, PI)]
	# The punch chain already contains its foot-driven hip rotation. Add only
	# the planted foot's lag behind that requested angle, not a second punch turn.
	var support_turn := lerpf(float(foot_turns[1]) - float(turns[1]), float(foot_turns[0]) - float(turns[0]), lead_weight)
	var base_turn := float(style["turn"])
	var hips_turn := base_turn + support_turn * 0.25 + float(motion["hips"])
	var chest_turn := hips_turn + float(motion["core"])
	var crouch := float(style["crouch"]) + maxf(0, -head_offset.y) * 0.60
	var spring := float(motion["load"]) * (0.20 if motion["upper"] else 0.06)
	var drive := forward * float(motion["drive"]) * 0.06
	var pelvis := Vector3.UP * (0.79 - crouch - spring) + head_offset * Vector3(0.30, 0, 0.30) + drive + support_shift
	var chest := pelvis + Vector3.UP * 0.39 + head_offset * Vector3(0.48, 0.25, 0.48)
	var delivery_targets := []; var contact_centers := []; var contact_radii := []; var contact_hits := []; var contact_weights := []
	var support_elbows := []; var arm_stability := []
	var arm_poles: Array = []; var leg_poles: Array = []; var hip_joints: Array = []; var ankles: Array = []
	var shoulders: Array = []; var elbows: Array = []; var wrists: Array = []; var twists: Array = []; var forearm_twists: Array = []; var knees: Array = []; var pivots: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var active := row.begins_with("L_") if i == 0 else row.begins_with("R_")
		var shoulder := chest + (right * side * float(style["shoulder"]) + Vector3.UP * 0.11).rotated(Vector3.UP, chest_turn)
		if active: shoulder += forward * float(motion["shoulder"]) * (0.07 if "STRAIGHT" in row or "FLARED" in row else 0.12 * compact) + Vector3.UP * float(motion["shoulder"]) * 0.035
		var neutral: Vector3 = shoulder + right * side * 0.025 + forward * (0.21 + (float(style["guard"]) if i == 0 else 0.0)) + Vector3.UP * 0.08
		var covered := head_offset + Vector3.UP * lerpf(1.57,1.15,guard_level) + right * side * 0.20 + forward * 0.17
		# A punch exits the sim's block immediately, but its glove leaves the
		# covered position continuously. The other glove protects the chin as
		# the working shoulder rolls; this is pose only, never free sim blocking.
		var cover := maxf(guard, float(style["cover"]))
		if active and "BLOCK_PUNCH" in mods: cover = maxf(cover, float(attack.get("guard_start", 1.0)) * (1.0 - ramp(progress / 0.4)) * (1.0 - ramp(recovery)))
		if not active and row != "": cover = maxf(cover, float(motion["shoulder"]))
		var hand: Vector3 = neutral.lerp(covered, ramp(cover))
		var home := hand
		# Marta's authored hands-down invitation is not a blocking state. Blend
		# into/out of it on the same active clock, including hitstop.
		hand -= Vector3.UP * 0.24 * float(fighter.get("motion_offer", 0)) * (1.0 - guard)
		var twist := deg_to_rad(15.0) * float(fighter.get("motion_gear", 0)) if i == 0 else 0.0
		var pronation := 0.0
		if active:
			var e := float(motion["upper_arm"])
			var target: Vector3 = attack.get("target", forward * 0.65 + Vector3.UP * 1.55)
			var curve := right * side * (0.62 if motion["hook"] else 0.03)
			if motion["upper"]: curve.y = -0.5
			elif "FLARED" in row: curve.y = 0.42
			# Recovery folds the elbow toward the ribs, instead of playing the
			# outgoing hook/uppercut arc backwards. Every arc closes at contact.
			curve *= compact * float(style["arc"]) * (1.0 + (0.18 if "POWER" in mods else 0.0) + (0.32 if "HAYMAKER" in mods else 0.0)) * (1.0 - ramp(recovery * 2.0))
			hand += -forward * float(motion["load"]) * 0.50
			hand = hand.lerp(target, e) + curve * sin(e * PI)
			if "STRAIGHT" in row and fighter.get("continuous_delivery",false):
				# Establish the committed lane before extending. A diagonal from
				# a resting low glove to the far chin drives every straight into
				# the opponent's resting hand instead of delivering along its aim.
				var align_lane := ramp((progress-0.08)/0.48) * (1.0-ramp(recovery*float(style["return"])))
				hand.y = lerpf(hand.y,target.y,align_lane)
				hand += right * (target-hand).dot(right) * align_lane
			# A loaded glove folds in front of the shoulder. Passing through the
			# shoulder reverses the IK axis and flips a deeply bent elbow.
			var load_clearance := 0.18 * (1.0-ramp(progress/0.55)) * (1.0-ramp(recovery))
			if load_clearance > 0 and fighter.get("continuous_delivery",false): hand += forward * maxf(0,load_clearance-(hand-shoulder).dot(forward))
			if motion["upper"] and not "BODY" in mods:
				# A rising head route stays in front of the chest until it rises
				# into the head lane. Do not score a head-intent uppercut by sending
				# its early delivery through the torso volume first.
				hand -= forward * 0.20 * sin(e * PI) * (1.0 - ramp(recovery))
			if motion["upper"] or recovery > 0:
				# Rising punches sweep in front of the chest. A lateral/downward
				# arc alone can route the wrist through the advancing shoulder,
				# collapsing the elbow axis. Clearance vanishes at exact contact.
				var returning := 1.0 if motion["upper"] else ramp(recovery * 6.0)
				var outside_clearance := maxf(0, 0.32 * sqrt(maxf(0, sin(e * PI))) * returning - (hand - shoulder).dot(forward)) * (1.0 - ramp((e - 0.9) / 0.1))
				var inside_clearance := maxf(0, 0.26 * maxf(0, sin(e * PI)) * returning - (hand - shoulder).dot(forward)) * sin(e * PI)
				hand += forward * lerpf(inside_clearance, outside_clearance, ramp((compact - 0.4) / 0.6))
			var turnover := side * (0.15 if motion["upper"] else PI * 0.5)
			pronation = turnover * 0.70 * float(motion["forearm"])
			twist = pronation + turnover * 0.30 * float(motion["fist"])
			if attack.has("return_from"):
				hand = Vector3(attack["return_from"]).lerp(home, ramp(recovery * float(style["return"])))
		if attack.has("start_wrists") and not attack.has("return_from"):
			hand = Vector3(attack["start_wrists"][i]).lerp(hand,float(attack.get("launch_blend",1)))
		var bend := right * side * 0.25 - Vector3.UP
		if motion["hook"] and active:
			var delivery_pole := right * side * 0.75 - Vector3.UP * (0.6 if motion["upper"] else 0.2)
			bend = bend.lerp(delivery_pole, float(motion["upper_arm"]))
		delivery_targets.append(attack.get("target", hand)); contact_centers.append(attack.get("target_center", hand))
		contact_radii.append(float(attack.get("target_radius", 0.32))); contact_hits.append(1.0 if attack.get("contact_hit", false) else 0.0)
		contact_weights.append(float(motion["upper_arm"]) if active else 0.0)
		if not elbow_prior.is_empty():
			var prior: Vector3 = elbow_prior[i] - origin - shoulder
			var axis := (hand - shoulder).normalized()
			prior -= axis * prior.dot(axis)
			var wanted := bend - axis * bend.dot(axis)
			if prior.length_squared() > 0.000001 and wanted.length_squared() > 0.000001:
				# A hookercut can pass close to the arm axis while weight changes
				# sides. Bound plane rotation instead of flipping the elbow branch.
				var angle := prior.angle_to(wanted)
				var blend := minf(0.4 if active else 0.05, 0.18 / maxf(angle, 0.0001))
				bend = prior.normalized().slerp(wanted.normalized(), blend)
		support_elbows.append(elbow_prior[i] - origin if not elbow_prior.is_empty() else shoulder)
		arm_stability.append(1.0 if not active and not elbow_prior.is_empty() else 0.0)
		arm_poles.append(bend)
		shoulders.append(shoulder); elbows.append(Vector3.ZERO); wrists.append(hand); twists.append(twist); forearm_twists.append(pronation)
		var foot_turn := float(foot_turns[i])
		pivots.append(foot_turn)
		var hip := pelvis + (right * side * 0.14).rotated(Vector3.UP, hips_turn)
		hip_joints.append(hip); ankles.append(soles[i] + Vector3.UP * 0.095 - forward.rotated(Vector3.UP, foot_turn) * 0.08)
		var knee_pole := forward.rotated(Vector3.UP, foot_turn) * 1.2 + right * side * 0.1
		leg_poles.append(knee_pole); knees.append(Vector3.ZERO)
	last_tick = tick
	var supported_knees := [knee_prior[0] - origin, knee_prior[1] - origin] if not knee_prior.is_empty() else hip_joints.duplicate()
	var result := constrain({"continuous_delivery": 1.0 if fighter.get("continuous_delivery", body_state.has("feet")) else 0.0, "knee_stability": 0.0 if knee_prior.is_empty() else 1.0, "support_knees": supported_knees, "support_elbows": support_elbows, "arm_stability": arm_stability, "hand_goals": wrists.duplicate(), "delivery_targets": delivery_targets, "contact_centers": contact_centers, "contact_radii": contact_radii, "contact_hits": contact_hits, "contact_weights": contact_weights, "arm_poles": arm_poles, "leg_poles": leg_poles, "hip_joints": hip_joints, "ankles": ankles, "forward": forward, "head": head_offset + Vector3.UP * 1.55, "pelvis": pelvis, "chest": chest, "hips_turn": hips_turn, "chest_turn": chest_turn, "shoulders": shoulders,
		"elbows": elbows, "wrists": wrists, "twists": twists, "forearm_twists": forearm_twists, "feet": soles, "pivots": pivots, "knees": knees, "chain": motion, "guard": guard, "lead_weight": lead_weight, "support_shift": support_shift})

	elbow_history = [origin + result["elbows"][0], origin + result["elbows"][1]]
	knee_history = [origin + result["knees"][0], origin + result["knees"][1]]
	return result

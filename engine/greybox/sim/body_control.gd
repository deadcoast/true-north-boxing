extends RefCounted
## Fixed-tick pocket/body mechanics. World ground uses the sim's tactical metres;
## vertical offsets use model metres, matching the existing rig-space contract.
## Constants are provisional game tuning, not measurements of human biomechanics.
const VERSION := 1
const DEADZONE := 0.18
const RESPONSE_PER_S := 28.0
const MAX_AXIS_SPEED := 8.0
const SLIP_M := 0.46
const DIP_M := 0.48
const DIP_FORWARD_M := 0.08
const PULL_M := 0.43
const PULL_LOWER_M := 0.08
const STEP_M := 0.48
const STEP_SECONDS := 0.24
const STEP_RECOVERY_SECONDS := 0.14
const STEP_BUFFER_SECONDS := 0.12
const STEP_COST := 3.0
const MIN_SEPARATION := 0.72
const GROUND_SCALE := 0.65

static func _smooth(value: float) -> float:
	var t := clampf(value, 0, 1)
	return t * t * (3 - 2 * t)

static func _support(fighter: Dictionary, dt: float) -> void:
	var state: Dictionary = fighter["body_control"]
	var facing: Vector2 = state["facing"]
	var right := Vector2(-facing.y, facing.x)
	var origin: Vector2 = fighter["pos"]
	var width := 0.19 / GROUND_SCALE
	var stagger := 0.19 / GROUND_SCALE
	var lead := 1.0 if str(fighter.get("stance", "orthodox")) != "southpaw" else -1.0
	var wanted := [origin - right * width + facing * stagger * lead, origin + right * width - facing * stagger * lead]
	if not state.has("feet"):
		state["feet"] = wanted.duplicate(); state["foot_lift"] = [0.0, 0.0]
		state["planted"] = [true, true]; state["gait"] = {}
		state["weight_lead"] = 0.5; state["foot_yaw"] = [facing.angle(), facing.angle()]
	var gait: Dictionary = state["gait"]
	var feet: Array = state["feet"]
	var moving: bool = not state["step"].is_empty()
	if gait.is_empty():
		var error0 := Vector2(feet[0]).distance_to(wanted[0])
		var error1 := Vector2(feet[1]).distance_to(wanted[1])
		if maxf(error0, error1) > (0.025 if moving else 0.09):
			# Equal placement errors must choose a stance role. Always choosing
			# the right foot made mirrored angle recoveries load opposite legs.
			var index := (0 if lead > 0 else 1) if absf(error0-error1)<0.00001 else (0 if error0 > error1 else 1)
			if moving and absf(error0 - error1) < 0.025:
				var opening := Vector2(state["step"]["direction"]).dot(wanted[0] - wanted[1])
				index = (0 if lead > 0 else 1) if absf(opening)<0.00001 else (0 if opening > 0 else 1)
			var punch: Dictionary = fighter.get("pending", {})
			if not punch.is_empty() and not "STEPPING" in punch.get("mods", []):
				var driving := 0 if str(punch["row"]).begins_with("L_") else 1
				if index == driving: index = 1 - index
			var start_weight := float(state["weight_lead"])
			var load_seconds := maxf(0.025,absf(start_weight-(0.12 if index==0 else 0.88))/6.0)
			gait = {"index": index, "from": feet[index], "to": wanted[index], "elapsed": 0.0, "duration": load_seconds+0.135, "load_seconds": load_seconds, "start_weight": start_weight}
			state["gait"] = gait
	var body_axis: Vector2 = state["axis"]
	# The saved weight field indexes the anatomical left foot. A dip transfers
	# toward the lead foot, which is the right foot for a southpaw.
	var balanced := clampf(0.5 - body_axis.x * 0.18 + body_axis.y * 0.08 * lead, 0.25, 0.75)
	# The previous fixed-tick pose supplies the load already in the body. Feed
	# it into the planted support, rather than drawing a trunk rotation above
	# feet which never pivot or receive that weight. No root displacement here.
	var boxing: Dictionary = fighter.get("boxing",{})
	var action: Dictionary = boxing.get("action",{})
	var chain: Dictionary = boxing.get("rig",{}).get("chain",{})
	var driving := -1 if action.is_empty() else (0 if str(action["row"]).begins_with("L_") else 1)
	var punch_drive := float(chain.get("drive",0))
	var punch_load := float(chain.get("load",0))
	if driving >= 0:
		balanced = clampf(balanced + (1 if driving == 1 else -1) * (punch_drive * 0.12 - punch_load * 0.10),0.25,0.75)
	if not gait.is_empty():
		var index: int = gait["index"]
		gait["elapsed"] += dt
		var age := float(gait["elapsed"])
		# Load the stationary leg before lifting. Only the airborne foot can
		# retarget; the support foot remains exactly fixed in world space.
		var load_seconds := float(gait.get("load_seconds",0.025))
		var phase := clampf((age - load_seconds) / (float(gait["duration"]) - load_seconds), 0, 1)
		var destination: Vector2 = Vector2(gait["to"]).move_toward(wanted[index], dt * 3.0)
		var side := -1.0 if index == 0 else 1.0
		var separation := destination - Vector2(feet[1 - index])
		destination += right * side * maxf(0, width - separation.dot(right) * side)
		gait["to"] = destination
		feet[index] = Vector2(gait["from"]).lerp(destination, _smooth(phase))
		state["foot_lift"][index] = sin(phase * PI) * 0.045
		state["planted"][index] = phase <= 0 or phase >= 1
		# Keep weight over the planted leg until the other sole lands. The old
		# last-20%-of-flight blend loaded an airborne foot and moved the pelvis
		# over five centimetres in one tick. Grounded recovery below owns the
		# return, at its normal bounded speed. A new gather starts from the
		# existing load rather than assuming the body is already balanced.
		state["weight_lead"] = lerpf(float(gait.get("start_weight",balanced)), 0.12 if index == 0 else 0.88, _smooth(age / load_seconds))
		if phase >= 1:
			state["foot_lift"][index] = 0.0; state["planted"][index] = true; state["gait"] = {}
	else:
		state["weight_lead"] = move_toward(float(state["weight_lead"]), balanced, dt * 4.0)
	for index in 2:
		var pivot := 0.0
		if index == driving and bool(state["planted"][index]):
			pivot = (1 if index == 0 else -1) * float(chain.get("plant",0)) * (0.65 if bool(chain.get("hook",false)) else 0.38)
		state["foot_yaw"][index] = rotate_toward(float(state["foot_yaw"][index]), facing.angle()+pivot, dt * 4.0)
	# Support is available from stance/weight, rather than an animation flag.
	state["support"] = (1.0 if state["gait"].is_empty() else 0.72) * (1 - body_axis.length() * 0.15)

static func radial(raw: Vector2, deadzone := DEADZONE) -> Vector2:
	if not raw.is_finite(): return Vector2.ZERO
	var radius := raw.length()
	if radius <= deadzone: return Vector2.ZERO
	return raw / radius * clampf((radius - deadzone) / (1.0 - deadzone), 0.0, 1.0)

static func forward(fighter: Dictionary, other: Dictionary) -> Vector2:
	var delta: Vector2 = other["pos"] - fighter["pos"]
	var fallback := delta.normalized() if delta.length_squared() > 0.000001 else Vector2(0, -1)
	return fighter.get("body_control", {}).get("facing", fallback)

static func offsets(fighter: Dictionary) -> Dictionary:
	var axis: Vector2 = fighter.get("body_control", {}).get("axis", Vector2.ZERO)
	var dip := maxf(0, axis.y)
	var pull := maxf(0, -axis.y)
	# One continuous surface, with distinct forward compression and rearward pull.
	var head := Vector3(axis.x * SLIP_M, -dip * DIP_M - pull * PULL_LOWER_M,
		dip * DIP_FORWARD_M - pull * PULL_M)
	var torso := Vector3(head.x * 0.4, head.y, head.z)
	return {"head": head, "torso": torso}

static func defense_axis(kind: String, side: int, phase: float) -> Vector2:
	# An authored AI decision produces intent, not a second displacement applied
	# directly to the head. The ordinary response/support/effort solver follows it.
	match kind:
		"SLIP": return Vector2(float(side)*0.35/SLIP_M,0)
		"DUCK": return Vector2(0,0.40/DIP_M)
		"LEAN": return Vector2(0,-0.30/PULL_M)
		"WEAVE": return Vector2(float(side)*cos(phase*PI)*0.40/SLIP_M,sin(phase*PI)*0.25/DIP_M).limit_length(1.0)
	return Vector2.ZERO

static func advance(fighter: Dictionary, other: Dictionary, axis: Vector2,
		step_request: Vector2, dt: float, can_step: bool, ring_half: float, step_distance := STEP_M) -> Dictionary:
	var toward: Vector2 = other["pos"] - fighter["pos"]
	var state: Dictionary = fighter.get("body_control", {})
	if state.is_empty():
		state = {"version": VERSION, "axis": Vector2.ZERO, "velocity": Vector2.ZERO,
			"facing": toward.normalized() if toward.length_squared() > 0.000001 else Vector2(0, -1),
			"step": {}, "queued": {}, "recovery": 0.0, "effort": 0.0, "support": 1.0}
		fighter["body_control"] = state
	if dt <= 0:
		_support(fighter,0.0)
		return {}
	# Facing is actor-owned and bounded; camera tracking cannot rotate this state.
	if toward.length_squared() > 0.000001:
		var facing: Vector2 = state["facing"]
		state["facing"] = Vector2.from_angle(rotate_toward(facing.angle(), toward.angle(), deg_to_rad(180) * dt))
	var effort_scale := lerpf(0.72, 1.0, clampf(float(fighter["stamina"]) / 40.0, 0, 1))
	var old: Vector2 = state["axis"]
	var desired := axis.limit_length(1.0) * effort_scale if axis.is_finite() else Vector2.ZERO
	if not state["step"].is_empty(): desired *= 0.35
	# Exponential response with a speed bound: prompt, no eight-way states, stable
	# at the fixed clock. Reversals preserve the current pose instead of resetting.
	var next := old.move_toward(old.lerp(desired, 1.0 - exp(-RESPONSE_PER_S * dt)), MAX_AXIS_SPEED * dt)
	state["axis"] = next; state["velocity"] = (next - old) / maxf(dt, 0.000001)
	var body_cost := (next - old).length() * 0.30 + next.length_squared() * dt * 0.35
	fighter["stamina"] = maxf(0.0, float(fighter["stamina"]) - body_cost)
	state["effort"] = float(state["effort"]) + body_cost
	state["recovery"] = maxf(0, float(state["recovery"]) - dt)
	var outcome := {}
	if step_request.is_finite() and step_request.length() > 0.01:
		state["queued"] = {"direction": step_request.normalized(), "remaining": STEP_BUFFER_SECONDS,"distance":clampf(step_distance,0.01,STEP_M)}
		outcome = {"outcome": "buffered", "reason": "action_or_support"}
	if not state["queued"].is_empty():
		if can_step and state["step"].is_empty() and state.get("gait", {}).is_empty() and float(state["recovery"]) <= 0:
			if float(fighter["stamina"]) < STEP_COST:
				outcome = {"outcome": "rejected", "reason": "effort"}; state["queued"] = {}
			else:
				var local: Vector2 = state["queued"]["direction"]
				var facing: Vector2 = state["facing"]
				var right := Vector2(-facing.y, facing.x)
				var direction := right * local.x + facing * local.y
				var duration := STEP_SECONDS / lerpf(0.8, 1.15, float(fighter["stats"]["SPD"]) / 99.0) / effort_scale
				state["step"] = {"direction": direction, "elapsed": 0.0, "duration": duration, "travel": 0.0,"distance":state["queued"].get("distance",STEP_M)}
				state["queued"] = {}; fighter["stamina"] -= STEP_COST
				outcome = {"outcome": "accepted", "reason": "supported_step", "direction": local}
		else:
			state["queued"]["remaining"] -= dt
			if float(state["queued"]["remaining"]) <= 0:
				state["queued"] = {}; outcome = {"outcome": "rejected", "reason": "expired"}
	if not state["step"].is_empty():
		var step: Dictionary = state["step"]
		var before_t := clampf(float(step["elapsed"]) / float(step["duration"]), 0, 1)
		step["elapsed"] = minf(float(step["duration"]), float(step["elapsed"]) + dt)
		var after_t := clampf(float(step["elapsed"]) / float(step["duration"]), 0, 1)
		var amount := (after_t * after_t * (3 - 2 * after_t) - before_t * before_t * (3 - 2 * before_t)) * float(step.get("distance",STEP_M))
		var before: Vector2 = fighter["pos"]
		var candidate: Vector2 = before + Vector2(step["direction"]) * amount
		candidate = candidate.clamp(Vector2(-ring_half, -ring_half), Vector2(ring_half, ring_half))
		# Stop the mover at the opponent's space; do not drag the other fighter.
		var separation: Vector2 = candidate - other["pos"]
		if separation.length() < MIN_SEPARATION and separation.length() < before.distance_to(other["pos"]):
			candidate = before
		fighter["pos"] = candidate
		step["travel"] += before.distance_to(candidate)
		if after_t >= 1:
			outcome = {"outcome": "completed", "reason": "shortened" if float(step["travel"]) < float(step.get("distance",STEP_M)) - 0.005 else "landed", "travel": step["travel"]}
			state["step"] = {}; state["recovery"] = STEP_RECOVERY_SECONDS
	_support(fighter, dt)
	return outcome

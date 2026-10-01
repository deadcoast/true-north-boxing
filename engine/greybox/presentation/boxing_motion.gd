extends RefCounted
## Boxing pose solver. Inputs come from the fixed combat clock, never render delta.
## The channels decompose the user's connected pivot/core/shoulder/arm sequence;
## they are implementation stages, not a claim of biomechanical validation.
const Space := preload("res://presentation/rig_space.gd")
const BodyControl := preload("res://sim/body_control.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
const UPPER_ARM := 0.38
const FOREARM := 0.36
const THIGH := 0.43
const SHIN := 0.42
# Model-space anatomy and pose limits. The neck has fixed length; the head
# rotates about its base instead of floating at an independent world target.
const NECK_LENGTH := 0.15
const HEAD_SOCKET := 0.12
const NECK_BEND := deg_to_rad(25.0)
const DELIVERY_LEAN_LIMIT := 0.18
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
	var learned := Techniques.guard_profile(fighter)
	if not learned.is_empty():
		profile["turn"] = float(learned["turn"])
		profile["cover"] = 0.0
	# Profiles describe lead/rear roles. Anatomy arrays remain left/right;
	# mirror the whole base, including the ordinary guard, before solving it.
	if fighter.get("stance","orthodox") == "southpaw":
		profile["turn"] = -float(profile["turn"])
		profile["lead"] = -float(profile["lead"])
		profile["balance"] = 1.0-float(profile["balance"])
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
var support_origin := Vector3.ZERO
var support_origin_set := false
var elbow_tick := -1
var elbow_history: Array = []
var elbow_prior: Array = []
var knee_history: Array = []
var knee_prior: Array = []
var inside_extent := 1.0
var travel_ticks := 0
var head_angles := Vector3.ZERO

# Native simulation retains the solver's history as plain typed save data.
func state() -> Dictionary:
	var out := {}
	for key in ["last_tick", "feet", "step", "guard", "guard_level", "previous_origin", "foot_yaw", "lead_weight", "support_shift", "support_origin", "support_origin_set", "elbow_tick", "elbow_history", "elbow_prior", "knee_history", "knee_prior", "inside_extent", "travel_ticks", "head_angles"]:
		out[key] = get(key)
	return out.duplicate(true)

func restore_state(saved: Dictionary) -> void:
	for key in saved: set(key, saved[key])

static func ramp(value: float) -> float:
	var x := clampf(value, 0, 1)
	return x * x * (3 - 2 * x)

static func _remaining_return(at: float, total: float, elapsed: float, rate := 1.0) -> float:
	var start := ramp(at / maxf(1,total) * rate)
	if start >= 1.0-0.00001:return 1.0
	return clampf((ramp((at+elapsed) / maxf(1,total) * rate)-start) / maxf(0.00001,1.0-start),0,1)

static func _handoff(attack: Dictionary) -> float:
	if attack.has("start_return"):
		var returning: Dictionary=attack["start_return"]
		return _remaining_return(returning["at"],returning["total"],attack.get("elapsed",0))
	return ramp(float(attack.get("elapsed",0)) / maxf(1,float(attack.get("startup",1))*0.38))

static func chain(row: String, progress: float, recovery: float, coil := 1.0, mods: Array = [], delivery_bias := 0.0, return_rate := 1.15, lead_hand := 0) -> Dictionary:
	var active := 0.0 if row == "" else 1.0
	var retract := 1.0 - ramp(recovery)
	var side := -1.0 if row.begins_with("L_") else 1.0
	var hook := "HOOK" in row; var upper := "UPPER" in row or "HOOKERCUT" in row
	var power := 1.0 if "POWER" in mods else 0.0
	var haymaker := 1.0 if "HAYMAKER" in mods else 0.0
	var strength := 1.0 + power * 0.16 + haymaker * 0.28
	var lead_straight := row == ("L_STRAIGHT" if lead_hand == 0 else "R_STRAIGHT")
	var rotation := (0.20 if lead_straight else (0.80 if hook else 0.52)) * strength
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
		var reach_deficit := maxf(0, horizontal.length() - available)
		# Cap the available trunk contribution before applying its phase.
		# Capping afterward made a distant target accelerate the chest into
		# the limit in a few ticks even though that target was unreachable.
		if continuous_delivery:reach_deficit=minf(reach_deficit,DELIVERY_LEAN_LIMIT)
		var needed := reach_deficit * float(rig["contact_weights"][i])
		if needed > lean.length(): lean = horizontal.normalized() * needed
	if rig.has("carry_lean"): lean = Vector3(rig["carry_lean"]).lerp(lean,float(rig["transfer"]))
	if continuous_delivery:
		# Bounded trunk contribution supplies reach. The attached head travels
		# with it; an already overstretched neck cannot grant extra reach.
		lean = lean.limit_length(DELIVERY_LEAN_LIMIT)
	rig["chest"] += lean
	for i in 2: rig["shoulders"][i] += lean
	rig["delivery_lean"] = lean
	_attach_head(rig)
	for i in 2:
		var guard_shift:=Vector3.ZERO
		if continuous_delivery and rig.has("guard_reference"):
			var collar: Vector3=(rig["shoulders"][0]+rig["shoulders"][1])*0.5
			var anchor: Vector3=Vector3(rig["head"]).lerp(collar,float(rig["guard_body_weights"][i]))
			guard_shift=anchor-Vector3(rig["guard_reference"][i])
		var desired: Vector3 = rig["delivery_targets"][i]
		# Solve the requested arm pose continuously. The old hit/miss branch
		# manufactured a different wrist endpoint before a punch had resolved.
		var delivery := desired if continuous_delivery else contact_goal(rig["shoulders"][i], desired, rig["contact_centers"][i], float(rig["contact_radii"][i]), float(rig["contact_hits"][i]) >= 0.5)
		var hand: Vector3 = rig["hand_goals"][i] + (delivery - desired) * float(rig["contact_weights"][i])
		# Carry the unsettled part of a shoulder-relative return through the
		# final body solve; its settled part uses the guard anchor below.
		hand += (lean-Vector3.UP*lower)*float(rig.get("return_weights",[0.0,0.0])[i])
		if continuous_delivery:
			# Plan the trajectory toward reachable extension before solving IK.
			# Lerp toward an unreachable point used to hit the length clamp midway
			# through delivery, snapping the elbow straight while the clock ran on.
			var reachable: Vector3=rig["shoulders"][i]+(desired-Vector3(rig["shoulders"][i])).limit_length(UPPER_ARM+FOREARM-0.002)
			hand+=(reachable-desired)*float(rig.get("delivery_weights",[0.0,0.0])[i])
		if rig.has("guard_weights"):hand+=guard_shift*float(rig["guard_weights"][i])
		var guard_home: Vector3=rig.get("guard_homes",rig.get("hand_homes",rig["hand_goals"]))[i]
		if continuous_delivery:
			if rig.has("guard_homes"):guard_home+=guard_shift
			# Impact may consume the spare routing margin at the struck glove.
			# Its future guard home still uses normal clearance; changing that
			# reference at contact falsely shortens the opposite hand's return.
			var home_rig:=rig
			if float(rig.get("clearance_margin",0.003))<0.003:
				home_rig=rig.duplicate();home_rig["clearance_margin"]=0.003
			guard_home=_self_clear_hand(home_rig,guard_home,i)
			# The home must fit the whole folded arm, not only the glove. A
			# skull-clear wrist can still leave its forearm through the ribs;
			# using that impossible home as the return limit forces a late jump.
			guard_home=_clear_arm(home_rig,guard_home,rig["arm_poles"][i],i)["end"]
		var return_reach := float(rig.get("return_reach",[0.0,0.0])[i])
		if continuous_delivery and return_reach > 0:
			# A returning glove may follow the world's recovery path only while
			# its arm can keep folding. Bound reach in the final shoulder frame,
			# accounting for a live guard change before enforcing that envelope.
			if rig.has("guard_homes"):return_reach=maxf(return_reach,guard_home.distance_to(rig["shoulders"][i]))
			hand=rig["shoulders"][i]+(hand-Vector3(rig["shoulders"][i])).limit_length(return_reach)
		if continuous_delivery: hand = _self_clear_hand(rig,hand,i,return_reach,guard_home)
		var pole: Vector3 = rig["arm_poles"][i]
		if float(rig.get("knee_stability", 0)) > 0 and float(rig.get("return_planes",[0.0,0.0])[i]) < 0.5:
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
		if continuous_delivery: arm = _clear_arm(rig,hand,pole,i,return_reach,guard_home)
		if not continuous_delivery and float(rig["arm_stability"][i]) > 0:
			# Carry the covered elbow along the upper-arm sphere through root
			# travel. Solve the forearm from it, rather than flipping IK branches.
			var shoulder: Vector3 = rig["shoulders"][i]
			var supported: Vector3 = shoulder + (rig["support_elbows"][i] - shoulder).normalized() * UPPER_ARM
			var direction := ((arm["joint"] as Vector3).lerp(supported, 0.65 * float(rig["arm_stability"][i])) - shoulder).normalized()
			arm["joint"] = shoulder + direction * UPPER_ARM
			arm["end"] = arm["joint"] + (hand - arm["joint"]).normalized() * FOREARM
		if continuous_delivery:
			# A covered elbow's historical plane may pull the solved wrist back
			# through the skull. Re-solve that arm from the reachable clear goal.
			for correction in 4:
				var clear := _self_clear_hand(rig,arm["end"],i,return_reach,guard_home)
				if clear.distance_squared_to(arm["end"])<=0.00000001:break
				arm = _clear_arm(rig,clear,pole,i,return_reach,guard_home)
			if rig.has("hand_homes"):rig["hand_homes"][i]=guard_home
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
	return _attach_head(rig)

static func _self_clear_hand(rig: Dictionary, hand: Vector3, index: int, max_reach := 0.0, home := Vector3.INF) -> Vector3:
	for iteration in 3:
		# A wrist folded onto its shoulder makes the elbow's circle singular.
		# Retain a real folded forearm instead of crossing that branch point.
		var shoulder: Vector3=rig["shoulders"][index]
		var delta:=hand-shoulder
		if delta.length()<0.18:
			var direction:=delta.normalized() if delta.length_squared()>0.000001 else Vector3(rig["forward"])
			hand=shoulder+direction*0.18
		hand = _head_clear_hand(rig,hand,index,max_reach)
		var correction := _torso_clearance(rig,hand,Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003)),index)
		if correction.length_squared()<0.00000001:break
		# The protective/return lane stays in front and on this arm's side.
		# Nearest-surface projection flips between the chest cap and its side
		# as a low guard crosses the rim, producing a large wrist teleport.
		var forward: Vector3=rig["forward"]
		var outward:=forward.cross(Vector3.UP)*(-1.0 if index==0 else 1.0)
		var direction:=(forward+outward*0.35).normalized()
		var low:=0.0;var high:=0.8
		if max_reach>0 and home.is_finite():
			# Recover toward the known feasible guarding arm. A fixed outward
			# ray can have no nearby exit once bounded by the shoulder sphere,
			# making a glove beside its home drop around the bottom of the head.
			direction=home-hand
			high=1.0
			for step in range(1,17):
				high=step/16.0
				var probe:=_head_clear_hand(rig,hand+direction*high,index,max_reach)
				if _torso_clearance(rig,probe,Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003)),index).length_squared()<=0.0000000001:break
				low=high
		for search in 14:
			var middle:=(low+high)*0.5
			var probe:=_head_clear_hand(rig,hand+direction*middle,index,max_reach) if max_reach>0 else hand+direction*middle
			if _torso_clearance(rig,probe,Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003)),index).length_squared()>0.0000000001:low=middle
			else:high=middle
		hand=_head_clear_hand(rig,hand+direction*high,index,max_reach) if max_reach>0 else hand+direction*high
	return hand

static func _torso_clearance(rig: Dictionary, point: Vector3, radius: float, index: int) -> Vector3:
	# The same finite torso used by contact and the visible body. Sphere
	# clearance includes the rim, without adding capsule caps above the collar.
	var top: Vector3=(rig["shoulders"][0]+rig["shoulders"][1])*0.5
	var bottom: Vector3=rig["pelvis"]+Vector3.UP*0.04
	var up: Vector3=(top-bottom).normalized()
	var height := (point-bottom).dot(up)
	var radial := point-bottom-up*height
	var side_gap := radial.length()-Space.BODY_RADIUS
	var cap_gap := maxf(-height,height-bottom.distance_to(top))
	var direction := radial.normalized()
	if direction.length_squared()<0.000001:
		direction=Vector3(rig["forward"])+Vector3(rig["forward"]).cross(Vector3.UP)*(-0.5 if index==0 else 0.5)
		direction=(direction-up*direction.dot(up)).normalized()
	if side_gap<=0 and cap_gap<=0:
		if cap_gap>side_gap:return up*(-1.0 if height<bottom.distance_to(top)*0.5 else 1.0)*(radius-cap_gap)
		return direction*(radius-side_gap)
	var nearest := bottom+up*clampf(height,0,bottom.distance_to(top))+direction*minf(radial.length(),Space.BODY_RADIUS)
	var delta := point-nearest
	return delta.normalized()*maxf(0,radius-delta.length())

static func _arm_gap(rig: Dictionary, arm: Dictionary, index: int) -> float:
	var elbow: Vector3=arm["joint"];var wrist: Vector3=arm["end"]
	var nearest:=Geometry3D.get_closest_point_to_segment(rig["head"],elbow,wrist)
	var gap:=nearest.distance_to(rig["head"])-Space.HEAD_RADIUS-0.085
	gap=minf(gap,wrist.distance_to(rig["head"])-Space.HEAD_RADIUS-Space.GLOVE_RADIUS-float(rig.get("clearance_margin",0.003)))
	gap=minf(gap,-_torso_clearance(rig,wrist,Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003)),index).length())
	for n in 9:
		var correction:=_torso_clearance(rig,elbow.lerp(wrist,n/8.0),0.088,index)
		gap=minf(gap,-correction.length())
	return gap

static func _clear_arm(rig: Dictionary, hand: Vector3, pole: Vector3, index: int, max_reach := 0.0, home := Vector3.INF) -> Dictionary:
	var arm:=_clear_elbow(rig,hand,pole,index)
	if _arm_gap(rig,arm,index)>=-0.00001:return arm
	# A deeply rotated rear shoulder may have no clear elbow plane for the
	# requested covering hand. Fold that hand back around its own side until
	# the whole forearm fits, instead of reaching through the ribcage.
	var forward: Vector3=rig["forward"]
	var outward:=forward.cross(Vector3.UP)*(-1.0 if index==0 else 1.0)
	var route:=outward-forward*0.5
	for n in range(1,9):
		var candidate:=_clear_elbow(rig,_self_clear_hand(rig,hand+route*(n*0.04),index,max_reach,home),pole,index)
		if _arm_gap(rig,candidate,index)>=-0.00001:
			var low:=(n-1)*0.04;var high:=n*0.04
			for refinement in 6:
				var middle:=(low+high)*0.5
				var probe:=_clear_elbow(rig,_self_clear_hand(rig,hand+route*middle,index,max_reach,home),pole,index)
				if _arm_gap(rig,probe,index)>=-0.00001:high=middle;candidate=probe
				else:low=middle
			return candidate
	return arm

static func _clear_elbow(rig: Dictionary, hand: Vector3, pole: Vector3, index: int) -> Dictionary:
	var shoulder: Vector3=rig["shoulders"][index]
	var arm:=joint(shoulder,hand,pole,UPPER_ARM,FOREARM)
	if _arm_gap(rig,arm,index)>=-0.00001:return arm
	# Elbow rotation cannot fix a wrist that the reach sphere pulled into the
	# fighter. Let the outer solve find a reachable, clear folded hand first.
	if Vector3(arm["end"]).distance_to(rig["head"])<Space.HEAD_RADIUS+Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003))-0.0001 or _torso_clearance(rig,arm["end"],Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003)),index).length()>0.00001:return arm
	# Preserve the wrist and both bone lengths. Search the elbow's actual
	# circle for the nearest clear plane, then refine its boundary. Most poses
	# use the original plane; this search is only for obstructed forearms.
	var axis: Vector3=(arm["end"]-shoulder).normalized()
	var best:=arm;var best_gap:=_arm_gap(rig,arm,index)
	# Stay on the current elbow branch. A far-side solution may be clear but
	# would flip the arm around its axis in a single tick. If this nearby arc
	# cannot fit, the outer solver folds the hand around the body's side.
	for n in range(1,5):
		for sign in [-1.0,1.0]:
			var angle: float=float(n)*PI/24.0*float(sign)
			var candidate:=joint(shoulder,hand,pole.rotated(axis,angle),UPPER_ARM,FOREARM)
			var gap:=_arm_gap(rig,candidate,index)
			if gap>best_gap:best=candidate;best_gap=gap
			if gap>=-0.00001:
				var low:=float(n-1)*PI/24.0;var high:=float(n)*PI/24.0
				for refine in 7:
					var middle:=(low+high)*0.5
					var probe:=joint(shoulder,hand,pole.rotated(axis,middle*sign),UPPER_ARM,FOREARM)
					if _arm_gap(rig,probe,index)>=-0.00001:high=middle;candidate=probe
					else:low=middle
				return candidate
	return best

static func _head_clear_hand(rig: Dictionary, hand: Vector3, index: int, max_reach := 0.0) -> Vector3:
	# The fighter's own skull is an obstacle during loading, delivery and
	# return. Route around its anatomical side, never through its centre.
	# This changes no opponent target and cannot follow an opponent's dodge.
	var forward: Vector3=Vector3(rig["forward"]).normalized()
	var outside:=forward.cross(Vector3.UP)*(-1.0 if index==0 else 1.0)
	var shoulder: Vector3=rig["shoulders"][index]
	if max_reach>0:hand=shoulder+(hand-shoulder).limit_length(max_reach)
	var delta:=hand-Vector3(rig["head"])
	# Small clearance also covers sub-tick contact correction against the
	# moving head. Preserve a covering glove in front of the face: projecting
	# only sideways opens the central lane even while high guard is held.
	var radius:=Space.HEAD_RADIUS+Space.GLOVE_RADIUS+float(rig.get("clearance_margin",0.003))
	var penetration:=maxf(0,radius-delta.length())
	if penetration<=0:return hand
	# The anatomical bias vanishes at the boundary, avoiding a sideways pop
	# as the fist clears the skull. It selects an outside/front route if a
	# requested loading or return path passes close to the exact centre.
	# Favour the front launch lane. A strong lateral bias throws a centring
	# straight sideways; branching at the head plane creates a discontinuity.
	var route:=delta+(outside*0.15+forward)*penetration
	var direction:=route.normalized() if route.length_squared()>0.000001 else outside
	var clear:=Vector3(rig["head"])+direction*radius
	if max_reach<=0 or clear.distance_to(shoulder)<=max_reach:return clear
	# Project onto the intersection of the shoulder's return envelope and
	# the skull's clearance sphere. Sequential projections undo one another:
	# clearing the head used to extend a hand that was already returning.
	var axis: Vector3=rig["head"]-shoulder
	var distance:=axis.length()
	if distance<0.000001 or distance+max_reach<radius:return clear
	axis/=distance
	var along:=(max_reach*max_reach-radius*radius+distance*distance)/(2.0*distance)
	var center:=shoulder+axis*along
	var lane:=clear-center;lane-=axis*lane.dot(axis)
	if lane.length_squared()<0.000001:
		lane=outside+forward;lane-=axis*lane.dot(axis)
	if lane.length_squared()<0.000001:lane=Vector3.UP.cross(axis)
	return center+lane.normalized()*sqrt(maxf(0,max_reach*max_reach-along*along))

static func _attach_head(rig: Dictionary) -> Dictionary:
	if float(rig.get("continuous_delivery",0)) <= 0.5: return rig
	var collar: Vector3 = (rig["shoulders"][0]+rig["shoulders"][1])*0.5
	var spine: Vector3 = (collar-Vector3(rig["pelvis"])).normalized()
	var up: Vector3 = Vector3(rig.get("head_up",Vector3.UP)).normalized()
	if rig.has("head_forward"):
		var frame := Basis.looking_at(Vector3(rig["head_forward"]).normalized(),up,true)
		up = frame.y; rig["head_up"] = up; rig["head_forward"] = frame.z
	# Keep the intended body/head action as a goal, not the result of the last
	# constraint pass. Repeated interpolation/contact solves are idempotent.
	var goal: Vector3 = rig.get("head_goal",rig["head"])
	var neck := goal-up*HEAD_SOCKET-collar
	neck = neck.normalized() if neck.length_squared()>0.000001 else spine
	var angle := spine.angle_to(neck)
	if angle > NECK_BEND: neck = spine.slerp(neck,NECK_BEND/angle).normalized()
	rig["neck_base"] = collar
	rig["neck_top"] = collar+neck*NECK_LENGTH
	rig["head"] = rig["neck_top"]+up*HEAD_SOCKET
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
	# Loading a combination starts at its actual body facing and turns toward
	# the committed direction. During return, regather around
	# the support body's live facing so a pocket exit cannot snap the torso
	# and both covering hands when the action expires.
	if attack.has("forward"):
		var committed: Vector3 = attack["forward"]
		if attack.has("start_forward"):
			committed = Vector3(attack["start_forward"]).slerp(committed, _handoff(attack))
		forward = committed.slerp(forward, ramp(float(attack.get("recovery", 0))))
	if forward.length_squared() < 0.1: forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var origin := Space.ground(at)
	if tick != elbow_tick:
		elbow_prior = elbow_history.duplicate(); elbow_tick = tick
		knee_prior = knee_history.duplicate()
	var dt := maxi(0, tick - last_tick) if last_tick >= 0 else 1
	var block := (bool(fighter.get("blocking", false)) or int(fighter.get("guard_t", 0)) > 0) and int(fighter.get("guard_open_t",0)) <= 0
	guard = move_toward(guard, 1.0 if block else 0.0, float(dt) / 6)
	guard_level = move_toward(guard_level,1.0 if fighter.get("guard_body",false) else 0.0,float(dt)/10.0)
	var row := str(attack.get("row", ""))
	var progress := float(attack.get("progress", 0)); var recovery := float(attack.get("recovery", 0))
	var mods: Array = attack.get("mods", [])
	var lead_hand := 1 if fighter.get("stance","orthodox") == "southpaw" else 0
	var stance_sign := 1.0 if lead_hand == 0 else -1.0
	var motion := chain(row, progress, recovery, float(style["coil"]), mods, float(style["delivery"]), float(style["return"]),lead_hand)
	var curved_delivery: bool=motion["hook"] or motion["upper"] or "FLARED" in row
	var technique: Dictionary = attack.get("technique",{})
	if not technique.is_empty(): motion["load"] *= float(technique["load"])
	var learned_guard := Techniques.guard_profile(fighter)
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
	# Keep the previous punch's recovery clock through a combination. A new
	# short loading window must not accelerate the old torso and hand return.
	var transfer := _handoff(attack)
	if attack.has("start_chain"):
		for channel in ["plant","drive","hips","core","load"]:
			motion[channel] = lerpf(float(attack["start_chain"][channel]),float(motion[channel]),transfer)
	var turns := [0.08, -0.08]
	if row != "": turns[0 if row.begins_with("L_") else 1] += float(motion["side"]) * float(motion["plant"]) * (0.75 if motion["hook"] else 0.48) * float(motion["strength"])
	var balance := clampf(float(style["balance"]) - head_offset.dot(right) * 1.1 + head_offset.dot(forward) * 0.9 * stance_sign, 0.2, 0.8)
	var lead_punch := row.begins_with("L_" if lead_hand == 0 else "R_")
	balance = clampf(balance + (float(motion["drive"]) * (0.06 if lead_punch else 0.13) - float(motion["load"]) * 0.12) * stance_sign, 0.2, 0.8)
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
		var wanted_support := Vector3(soles[1]).lerp(soles[0], lead_weight).limit_length(0.12)
		wanted_support.y = 0
		# Weight changes are targets for the supported pelvis, not permission
		# to teleport it between legs. Transport the preceding support point in
		# world space, then move it at a bounded rate on this same fixed clock.
		# Feet still lift/land at their existing times; body input stays prompt.
		if support_origin_set:
			support_shift=(support_shift+support_origin-origin).move_toward(wanted_support,float(dt)*0.020)
		else:support_shift=wanted_support
		support_origin=origin;support_origin_set=true
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
	if attack.has("start_spring"): spring = lerpf(float(attack["start_spring"]),spring,transfer)
	var drive := forward * float(motion["drive"]) * 0.06
	var impact_head := Vector3.ZERO; var impact_trunk := Vector3.ZERO; var impact_angles := Vector3.ZERO
	for impact in fighter.get("boxing",{}).get("impacts",[]):
		var age := float(impact["age"])/9.0
		var pulse := age*exp(1.0-age)*float(impact["strength"])
		var direction: Vector3 = impact["direction"]
		var lateral := direction.dot(right); var backward := -direction.dot(forward)
		if impact["guarded"]:
			impact_trunk += direction*0.022*pulse
			impact_head += direction*0.009*pulse
		elif impact["target"] == "head":
			impact_head += direction*0.11*pulse
			impact_trunk += direction*0.035*pulse
			impact_angles += Vector3(-backward*0.34-direction.y*0.15,lateral*0.42,-lateral*0.24)*pulse
		else:
			impact_trunk += (direction*0.055-Vector3.UP*0.045)*pulse
			impact_head += (direction*0.025-Vector3.UP*0.035)*pulse
			impact_angles.x += 0.22*pulse
	impact_head=impact_head.limit_length(0.14); impact_trunk=impact_trunk.limit_length(0.08)
	var pelvis := Vector3.UP * (0.79 - crouch - spring) + head_offset * Vector3(0.30, 0, 0.30) + drive + support_shift
	var chest := pelvis + Vector3.UP * 0.39 + head_offset * Vector3(0.48, 0.25, 0.48) + impact_trunk
	var delivery_targets := []; var contact_centers := []; var contact_radii := []; var contact_hits := []; var contact_weights := [];var delivery_weights:=[]
	var support_elbows := []; var arm_stability := []; var hand_homes := []; var shoulder_offsets := []
	var guard_weights:=[];var guard_body_weights:=[];var guard_reference:=[]
	var arm_poles: Array = []; var leg_poles: Array = []; var hip_joints: Array = []; var ankles: Array = []
	var shoulders: Array = []; var elbows: Array = []; var wrists: Array = []; var twists: Array = []; var forearm_twists: Array = []; var knees: Array = []; var pivots: Array = []
	var return_weights := [0.0,0.0]
	var return_planes := [0.0,0.0]
	var return_reach := [0.0,0.0]
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var active := row.begins_with("L_") if i == 0 else row.begins_with("R_")
		var shoulder := chest + (right * side * float(style["shoulder"]) + Vector3.UP * 0.11).rotated(Vector3.UP, chest_turn)
		var shoulder_offset := Vector3.ZERO
		if active: shoulder_offset = forward * float(motion["shoulder"]) * (0.07 if "STRAIGHT" in row or "FLARED" in row else 0.12 * compact) + Vector3.UP * float(motion["shoulder"]) * 0.035
		if attack.has("start_shoulders"):
			var release := transfer
			if not active and attack.has("returning"):
				var returning: Dictionary=attack["returning"]
				release = _remaining_return(returning["at"],returning["total"],attack.get("elapsed",0),returning["rate"]) if returning.has("at") else ramp(float(attack.get("elapsed",0))/int(returning["duration"]))
			shoulder_offset = Vector3(attack["start_shoulders"][i]).lerp(shoulder_offset,release)
		shoulder_offsets.append(shoulder_offset); shoulder += shoulder_offset
		var neutral: Vector3 = shoulder + right * side * 0.025 + forward * (0.21 + (float(style["guard"]) if i == lead_hand else 0.0)) + Vector3.UP * 0.08
		if not learned_guard.is_empty():
			var role := "lead" if i == lead_hand else "rear"
			neutral = head_offset + right*side*float(learned_guard[role+"_side"]) + forward*float(learned_guard[role+"_forward"]) + Vector3.UP*(float(learned_guard[role+"_height"])-spring)
		# Cover in front of the face, with room for the full glove and skull.
		# The previous 0.17m high guard embedded the gloves in the head; merely
		# spreading those hands sideways left a clean straight through the gap.
		var low_forward:=0.34 if fighter.get("continuous_delivery",false) else 0.17
		# Body cover belongs to the rotating ribcage. Keeping a low glove in
		# the facing frame while a hook turns the chest sends its other forearm
		# across the torso and forces an abrupt elbow detour. High cover stays
		# with the head; lower cover follows the chest continuously.
		var cover_turn:=chest_turn*guard_level if fighter.get("continuous_delivery",false) else 0.0
		var cover_offset:=right*side*lerpf(0.20,0.16,guard_level)+forward*lerpf(0.29,low_forward,guard_level)
		var covered := head_offset + Vector3.UP * lerpf(1.57,1.15,guard_level) + cover_offset.rotated(Vector3.UP,cover_turn)
		# Held high/low guard stays with the covering hand as the working hand
		# leaves it. The committed trajectory below owns the attacking glove;
		# actual arm position determines whether either hand can brace contact.
		# Resting cover is the beginning of the guard stroke, not a threshold
		# the input must exceed. max(guard, resting_cover) stalls a raised home
		# for several ticks, then compresses its movement into the end of the
		# guard clock. Travel from that home immediately on the same clock.
		var cover := lerpf(float(style["cover"]),1.0,guard) if fighter.get("continuous_delivery",false) else maxf(guard,float(style["cover"]))
		if active and "BLOCK_PUNCH" in mods: cover = maxf(cover, float(attack.get("guard_start", 1.0)) * (1.0 - ramp(progress / 0.4)) * (1.0 - ramp(recovery)))
		if not active and row != "": cover = maxf(cover, float(motion["shoulder"]))
		var hand: Vector3 = neutral.lerp(covered, ramp(cover))
		if fighter.get("continuous_delivery",false):
			# Raise cover around the shoulder, keeping the folded arm's reach.
			# A straight chord between low neutral and high cover can pass close
			# to the shoulder and whip the elbow around an almost folded axis.
			var from_arm:=neutral-shoulder;var to_arm:=covered-shoulder
			if from_arm.length_squared()>0.000001 and to_arm.length_squared()>0.000001:
				hand=shoulder+from_arm.normalized().slerp(to_arm.normalized(),ramp(cover))*lerpf(from_arm.length(),to_arm.length(),ramp(cover))
		var home := hand
		hand_homes.append(home)
		var anchor_body := guard_level*ramp(cover)
		guard_body_weights.append(anchor_body)
		guard_reference.append(head_offset+Vector3.UP*lerpf(1.55,1.29,anchor_body))
		var anchor_weight:=1.0
		# Marta's authored hands-down invitation is not a blocking state. Blend
		# into/out of it on the same active clock, including hitstop.
		hand -= Vector3.UP * 0.24 * float(fighter.get("motion_offer", 0)) * (1.0 - guard)
		var twist := deg_to_rad(15.0) * float(fighter.get("motion_gear", 0)) * stance_sign if i == lead_hand else 0.0
		var pronation := 0.0
		if active:
			var e := float(motion["upper_arm"])
			anchor_weight=1.0-e
			var target: Vector3 = attack.get("target", forward * 0.65 + Vector3.UP * 1.55)
			var curve := right * side * (0.62 if motion["hook"] else 0.03)
			if motion["upper"]: curve.y = -float(technique.get("drop",0.5))
			elif "FLARED" in row: curve.y = 0.42
			# Recovery folds the elbow toward the ribs, instead of playing the
			# outgoing hook/uppercut arc backwards. Every arc closes at contact.
			curve *= compact * float(style["arc"]) * (1.0 + (0.18 if "POWER" in mods else 0.0) + (0.32 if "HAYMAKER" in mods else 0.0)) * (1.0 - ramp(recovery * 2.0))
			if fighter.get("continuous_delivery",false) and attack.has("start_arms"):
				hand = shoulder + Vector3(attack["start_arms"][i])
				# This arm is already shoulder-relative; applying the live guard's
				# head/rib anchor again would steer it when the other hand lowers.
				anchor_weight = 0.0
			hand += -forward * float(motion["load"]) * (0.22 if not technique.is_empty() else 0.50)
			var load_clearance := 0.18 * (1.0-ramp(e/0.55)) * (1.0-ramp(recovery))
			if curved_delivery and fighter.get("continuous_delivery",false):
				# The arc controls direction, not extra arm length. Interpolate
				# directions through the outside/rising control point on a sphere;
				# normalizing a Cartesian curve can pass through zero and flip.
				var from_arm:=hand-shoulder
				# The source direction must remain defined even while the live
				# guard crosses shoulder height. This is a curve control point,
				# not a clearance imposed on the delivered glove.
				from_arm+=forward*maxf(0,0.18-from_arm.dot(forward))
				var to_arm:=(target-shoulder).limit_length(UPPER_ARM+FOREARM-0.002)
				var control:=(from_arm+to_arm)*0.5+curve
				control+=forward*maxf(0,0.18-control.dot(forward))
				var first:=from_arm.normalized().slerp(control.normalized(),e)
				var last:=control.normalized().slerp(to_arm.normalized(),e)
				hand=shoulder+first.slerp(last,e)*lerpf(from_arm.length(),to_arm.length(),e)
			else: hand = hand.lerp(target, e) + curve * sin(e * PI)
			if not technique.is_empty() and str(technique["id"]) in ["compact","probe","shovel"]:
				# Fold toward the committed inside lane before extending upward.
				# The aim was fixed at launch; this cannot steer around a later guard.
				hand += right*(target-hand).dot(right)*ramp((progress-0.08)/0.40)*(1.0-ramp(recovery))
			if "STRAIGHT" in row and fighter.get("continuous_delivery",false):
				# Establish the committed lane before extending. A diagonal from
				# a resting low glove to the far chin drives every straight into
				# the opponent's resting hand instead of delivering along its aim.
				# A body straight changes level during its load, before the arm
				# extends. From an actual high launch hand, late alignment sweeps
				# down through the opponent's high forearm instead of the body lane.
				var align_lane := (ramp(progress/0.24) if "BODY" in mods else ramp((progress-0.08)/0.48)) * (1.0-ramp(recovery*float(style["return"])))
				hand.y = lerpf(hand.y,target.y,align_lane)
				hand += right * (target-hand).dot(right) * align_lane
			# A loaded glove folds in front of the shoulder. Passing through the
			# shoulder reverses the IK axis and flips a deeply bent elbow.
			# The arm can still be loading well into the overall punch clock.
			# Release shoulder clearance as that arm actually extends, not while
			# a delayed hook is still coiled beside the shoulder's IK singularity.
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
				anchor_weight=ramp(recovery*float(style["return"]))
				hand = Vector3(attack["return_from"]).lerp(home,anchor_weight)
				# Fold along this hand's outside lane before it reaches the head.
				# A straight return can enter the skull and force a late IK detour.
				hand += right * side * 0.12 * sin(PI * anchor_weight)
		if attack.has("start_wrists") and not attack.has("return_from"):
			hand = Vector3(attack["start_wrists"][i]).lerp(hand,float(attack.get("launch_blend",1)))
			anchor_weight*=float(attack.get("launch_blend",1))
		var returning: Dictionary = attack.get("returning",{})
		var folded := 0.0
		if not returning.is_empty() and i == int(returning["hand"]) and not active:
			folded = _remaining_return(returning["at"],returning["total"],attack.get("elapsed",0),returning["rate"]) if returning.has("at") else ramp(float(attack.get("elapsed",0))/int(returning["duration"]))
			# Continue the existing recovery path toward the moving guard. Its
			# retained clock prevents a stalled glove as the shoulder withdraws;
			# adding the full shoulder retreat again would double that motion.
			# Older saved handoffs retain their shoulder-relative fallback.
			var legacy_arm: bool=returning.has("arm") and not returning.has("at")
			var return_start: Vector3 = shoulder+Vector3(returning["arm"]) if legacy_arm else Vector3(returning["from"])-origin
			if legacy_arm:return_weights[i]=1.0-folded
			elif returning.has("arm"):return_reach[i]=Vector3(returning["arm"]).length()
			hand = return_start.lerp(home,folded)
			# A nearly settled opposite hand must not restart a full outside
			# return loop just because the next punch has begun. Scale clearance
			# to the actual return still owed at the handover.
			var return_arc := float(returning.get("arc",minf(0.12,(Vector3(returning["from"])-origin).distance_to(home)*0.25)))
			hand += right * side * return_arc * sin(PI * folded)
			anchor_weight=folded
			twist = lerpf(float(returning["twist"]),twist,folded)
			pronation = lerpf(float(returning["pronation"]),pronation,folded)
		var bend := right * side * 0.25 - Vector3.UP
		if motion["hook"] and active:
			var delivery_pole := right * side * 0.75 - Vector3.UP * (0.6 if motion["upper"] else 0.2)
			bend = bend.lerp(delivery_pole, float(motion["upper_arm"]))
		if not returning.is_empty() and i == int(returning["hand"]) and returning.has("elbow") and not active:
			# Fold toward the guarding plane throughout return. Retaining an
			# inward contact plane until the glove is home causes a late detour.
			var axis := (hand-shoulder).normalized()
			var from: Vector3=returning["elbow"]
			from-=axis*from.dot(axis)
			var to:=bend-axis*bend.dot(axis)
			if from.length_squared()>0.000001 and to.length_squared()>0.000001:
				# The glove may already be home while the torso/elbow still unload.
				# Continue that body's phase instead of snapping to the final plane.
				bend=from.normalized().slerp(to.normalized(),transfer)
				return_planes[i]=1.0
		delivery_targets.append(attack.get("target", hand)); contact_centers.append(attack.get("target_center", hand))
		contact_radii.append(float(attack.get("target_radius", 0.32))); contact_hits.append(1.0 if attack.get("contact_hit", false) else 0.0)
		contact_weights.append(float(motion["upper_arm"]) if active else 0.0)
		var delivery_weight:=float(motion["upper_arm"]) if active and not curved_delivery and not attack.has("return_from") else 0.0
		if attack.has("start_wrists"):delivery_weight*=float(attack.get("launch_blend",1.0))
		delivery_weights.append(delivery_weight)
		if not elbow_prior.is_empty() and return_planes[i]<0.5:
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
		guard_weights.append(anchor_weight)
		shoulders.append(shoulder); elbows.append(Vector3.ZERO); wrists.append(hand); twists.append(twist); forearm_twists.append(pronation)
		var foot_turn := float(foot_turns[i])
		pivots.append(foot_turn)
		var hip := pelvis + (right * side * 0.14).rotated(Vector3.UP, hips_turn)
		hip_joints.append(hip); ankles.append(soles[i] + Vector3.UP * 0.095 - forward.rotated(Vector3.UP, foot_turn) * 0.08)
		var knee_pole := forward.rotated(Vector3.UP, foot_turn) * 1.2 + right * side * 0.1
		leg_poles.append(knee_pole); knees.append(Vector3.ZERO)
	var supported_knees := [knee_prior[0] - origin, knee_prior[1] - origin] if not knee_prior.is_empty() else hip_joints.duplicate()
	# Loading a punch lowers the head with the spine while keeping the chin
	# behind the shoulder's forward drive. This is the
	# simulation-owned pose used by head contact, not a cosmetic camera bob.
	var punch_head := -Vector3.UP*spring + drive*0.45 + right*float(motion["hips"])*0.035 if fighter.get("continuous_delivery", body_state.has("feet")) else Vector3.ZERO
	punch_head += impact_head
	# The referee count owns a connected kneel/rise, on the same saved pose as
	# contact. Keep both boots planted; lower and sit the pelvis back before IK.
	# These are provisional pose distances, not biological measurements.
	var count_weight := clampf(float(fighter.get("boxing",{}).get("count_weight",0)),0,1)
	if count_weight > 0:
		var count_shift := (-Vector3.UP*maxf(0,pelvis.y-0.39)-forward*0.15)*count_weight
		pelvis += count_shift; chest += count_shift; punch_head += count_shift
		for i in 2:
			hip_joints[i] += count_shift; shoulders[i] += count_shift
			wrists[i] += count_shift; hand_homes[i] += count_shift
			delivery_targets[i] += count_shift; contact_centers[i] += count_shift
			support_elbows[i] += count_shift
		# Release the standing knee plane gradually so the back knee can fold.
		for i in 2: supported_knees[i] = Vector3(supported_knees[i]).lerp(hip_joints[i]+forward*0.2-Vector3.UP*0.3,count_weight)
	var carry_lean: Vector3 = attack.get("start_lean",Vector3.ZERO)
	var result := constrain({"return_reach":return_reach,"return_planes":return_planes,"return_weights":return_weights,"carry_lean":carry_lean,"transfer":transfer if attack.has("start_lean") else 1.0,"spring":spring,"shoulder_offsets":shoulder_offsets,"continuous_delivery": 1.0 if fighter.get("continuous_delivery", body_state.has("feet")) else 0.0, "knee_stability": 0.0 if knee_prior.is_empty() else 1.0, "support_knees": supported_knees, "support_elbows": support_elbows, "arm_stability": arm_stability, "hand_goals": wrists.duplicate(), "delivery_targets": delivery_targets, "contact_centers": contact_centers, "contact_radii": contact_radii, "contact_hits": contact_hits, "contact_weights": contact_weights, "arm_poles": arm_poles, "leg_poles": leg_poles, "hip_joints": hip_joints, "ankles": ankles, "forward": forward, "head_goal": head_offset + Vector3.UP * 1.55 + punch_head, "head": head_offset + Vector3.UP * 1.55 + punch_head, "pelvis": pelvis, "chest": chest, "hips_turn": hips_turn, "chest_turn": chest_turn, "shoulders": shoulders,
		"elbows": elbows, "wrists": wrists, "twists": twists, "forearm_twists": forearm_twists, "feet": soles, "pivots": pivots, "knees": knees, "chain": motion, "guard": guard, "lead_weight": lead_weight, "support_shift": support_shift})

	result["guard_level"]=guard_level
	result["guard_weights"]=guard_weights;result["guard_body_weights"]=guard_body_weights;result["guard_reference"]=guard_reference
	result["delivery_weights"]=delivery_weights
	result["guard_homes"]=hand_homes.duplicate();result["hand_homes"]=hand_homes
	# Head orientation follows the actual trunk, with neck counter-rotation to
	# retain vision. It never rotates the root, steers a punch or moves a target
	# independently of this shared fixed-tick pose.
	var collar: Vector3 = (result["shoulders"][0]+result["shoulders"][1])*0.5
	var spine: Vector3 = (collar-Vector3(result["pelvis"])).normalized()
	var focus := Space.ground(other["pos"])+Vector3(other.get("boxing",{}).get("rig",{}).get("head",Vector3.UP*1.55))-Vector3.UP*0.05
	var gaze := focus-(origin+Vector3(result["head"]))
	var heading := atan2(gaze.dot(right),gaze.dot(forward))
	var desired := Vector3(0.10+atan2(spine.dot(forward),spine.y)*0.4-atan2(gaze.y,Vector2(gaze.x,gaze.z).length())*0.65,
		clampf(heading,-0.65,0.65)-float(motion["core"])*0.08,
		-atan2(spine.dot(right),spine.y)*0.65-float(motion["hips"])*0.16)+impact_angles
	desired.x=clampf(desired.x,-0.45,0.50);desired.y=clampf(desired.y,-0.75,0.75);desired.z=clampf(desired.z,-0.45,0.45)
	head_angles=desired if last_tick<0 else head_angles.move_toward(desired,float(dt)*0.045)
	var head_frame := Basis(right,Vector3.UP,forward)*Basis(Vector3.UP,head_angles.y)*Basis(Vector3.RIGHT,head_angles.x)*Basis(Vector3.BACK,head_angles.z)
	result["head_forward"]=head_frame.z;result["head_up"]=head_frame.y
	result["head_angles"]=head_angles;result["impact_head"]=impact_head
	# Head orientation moves its socket. Solve hand clearance against that
	# final attached head, so both collision and rendering see the same route.
	result=constrain(result)
	if not learned_guard.is_empty():
		for i in 2:
			var axis := (Vector3(result["wrists"][i])-Vector3(result["elbows"][i])).normalized()
			var thumb := Quaternion(Vector3.FORWARD,axis) * Vector3(0.10 if i == 0 else -0.10,-0.065,0)
			var up := Vector3.UP-axis*axis.dot(Vector3.UP)
			var rest := thumb.signed_angle_to(up,axis) if up.length_squared() > 0.0001 else 0.0
			var active := row.begins_with("L_") if i == 0 else row.begins_with("R_")
			result["twists"][i] = lerp_angle(rest,float(result["twists"][i]),float(motion["upper_arm"]) if active else 0.0)
	elbow_history = [origin + result["elbows"][0], origin + result["elbows"][1]]
	last_tick=tick
	knee_history = [origin + result["knees"][0], origin + result["knees"][1]]
	return result

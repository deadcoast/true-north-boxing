extends RefCounted
## Fixed-tick boxing pose and moving-volume contact. Positions use RigSpace's
## world units; all persistent state is typed data inside the fighter snapshot.
const Motion := preload("res://presentation/boxing_motion.gd")
const Space := preload("res://presentation/rig_space.gd")
const EPS := 0.00001

static func begin(fighter: Dictionary, other: Dictionary, row: String, mods: Array, startup: int, recovery: int, target: Vector3, reach: float) -> void:
	var state: Dictionary = fighter.get("boxing", {})
	var origin := Space.ground(fighter["pos"])
	var forward := (Space.ground(other["pos"]) - origin).normalized()
	if forward.length_squared() < 0.1: forward = Vector3.FORWARD
	var offset := target - origin
	var horizontal := Vector3(offset.x, 0, offset.z)
	var radius := Space.BODY_RADIUS if "BODY" in mods else Space.HEAD_RADIUS
	# Commit the aim once. Range comes from anatomy and actual root travel;
	# subsequent opponent movement cannot rewrite this endpoint or facing.
	var distance := minf(horizontal.length(), reach * Space.GROUND_SCALE)
	var endpoint := horizontal.normalized() * maxf(0.08, distance - radius - Space.GLOVE_RADIUS + 0.05)
	endpoint.y = offset.y
	var prepared: Dictionary = state.get("preparation", {})
	var matches: bool = prepared.get("row", "") == row
	state["serial"] = int(state.get("serial", 0)) + 1
	state["action"] = {"id":state["serial"], "row":row, "mods":mods.duplicate(), "body":"BODY" in mods,
		"startup":startup, "recovery_ticks":maxi(1,recovery), "return_t":0, "phase":"flight", "progress":0.0,
		"start_progress":float(prepared.get("progress",0)) if matches else 0.0,
		"preload":float(prepared.get("preload",0)) if matches else 0.0,
		"target":endpoint, "target_center":offset, "forward":forward,
		"guard_start":float(fighter.get("pending",{}).get("guard_start",0)), "would_hit":false,
		"reference":other.get("boxing",{}).get("volumes",[]).duplicate(true), "defender_origin":other["pos"]}
	state["preparation"] = {}
	if state.has("rig"): state["action"]["start_wrists"] = state["rig"]["wrists"].duplicate()
	fighter["boxing"] = state
	fighter["pending"]["trajectory"] = true

static func sample(fighter: Dictionary, other: Dictionary, head: Dictionary, ticks: int, preparation: Dictionary = {}) -> void:
	var state: Dictionary = fighter.get("boxing", {})
	state["clock"] = int(state.get("clock",0)) + ticks
	var action: Dictionary = state.get("action",{})
	var attack := {}
	if action.is_empty() and preparation.is_empty() and not state.get("preparation",{}).is_empty():
		action = state["preparation"].duplicate(true)
		action.merge({"phase":"cancelled","return_t":0,"recovery_ticks":12,"return_from":state["rig"]["wrists"][0 if str(action["row"]).begins_with("L_") else 1]})
		state["action"] = action; state["preparation"] = {}
	if not action.is_empty():
		if action["phase"] == "flight" and fighter.get("pending",{}).is_empty():
			action["phase"] = "cancelled"; action["return_t"] = 0
			action["recovery_ticks"] = mini(int(action["recovery_ticks"]),maxi(1,int(fighter["busy_t"])))
			if state.has("rig"): action["return_from"] = state["rig"]["wrists"][0 if str(action["row"]).begins_with("L_") else 1]
		if action["phase"] == "flight":
			var elapsed := 1.0 - float(fighter["pending"]["t"]) / maxi(1,int(action["startup"]))
			action["progress"] = lerpf(float(action["start_progress"]),1.0,clampf(elapsed,0,1))
		else:
			action["return_t"] += ticks
			if int(action["return_t"]) >= int(action["recovery_ticks"]): action = {}; state["action"] = {}
		if not action.is_empty():
			attack = action.duplicate(true)
			attack["recovery"] = float(action["return_t"]) / int(action["recovery_ticks"])
			attack["launch_blend"] = Motion.ramp((float(action["progress"]) - float(action.get("start_progress",0))) / 0.2)
			attack["preload"] *= 1.0 - Motion.ramp(float(action["progress"]))
	if action.is_empty() and not preparation.is_empty():
		preparation = preparation.duplicate(true)
		var prior: Dictionary = state.get("preparation",{})
		var same: bool = prior.get("row","") == preparation["row"]
		preparation["progress"] = move_toward(float(prior.get("progress",0)) if same else 0,float(preparation["progress"]),ticks*0.025)
		preparation["preload"] = move_toward(float(prior.get("preload",0)) if same else 0,float(preparation["preload"]),ticks*0.08)
		state["preparation"] = preparation.duplicate(true); attack = preparation.duplicate(true)
	elif action.is_empty(): state["preparation"] = {}
	var solver := Motion.new()
	solver.restore_state(state.get("solver",{}))
	var physical := fighter.duplicate()
	physical["continuous_delivery"] = true
	var head_offset := Space.ground(Vector2(head["p"]) - Vector2(fighter["pos"])) + Vector3.UP * (float(head["h"]) - 1.55)
	var rig := solver.sample(physical,other,int(state["clock"]),attack,head_offset)
	state["solver"] = solver.state()
	state["origin"] = Space.ground(fighter["pos"])
	state["rig"] = rig; state["presentation"] = attack
	var current := volumes(fighter,rig)
	state["previous"] = state.get("volumes",current).duplicate(true)
	state["volumes"] = current
	fighter["boxing"] = state

static func volumes(fighter: Dictionary, rig: Dictionary) -> Array:
	var origin := Space.ground(fighter["pos"])
	var head: Vector3 = rig["head"]
	var forward: Vector3 = rig["forward"]; var right := forward.cross(Vector3.UP)
	var torso := forward * head.dot(forward) + right * head.dot(right) * 0.4
	var height := 1.10 + minf(0,head.y - 1.55)
	var collar: Vector3 = (rig["shoulders"][0] + rig["shoulders"][1]) * 0.5
	var top := torso + Vector3.UP * minf(head.y - Space.HEAD_RADIUS - 0.025,maxf(height + 0.02,collar.y - 0.06))
	var bottom := torso + Vector3.UP * minf(height - 0.02,maxf(height - 0.16,float(rig["pelvis"].y) + 0.02))
	var out := [{"part":"head","kind":"hit","target":"head","a":origin+head,"b":origin+head,"r":Space.HEAD_RADIUS},
		{"part":"body","kind":"hit","target":"body","a":origin+bottom,"b":origin+top,"r":Space.BODY_RADIUS}]
	var attack: Dictionary = fighter.get("boxing",{}).get("action",{})
	var working := -1 if attack.is_empty() else (0 if str(attack["row"]).begins_with("L_") else 1)
	for i in 2:
		# Hands remain physical when the guard button is released. An unbraced
		# interception deflects; a properly covered arm absorbs guard damage.
		var braced: bool = int(fighter.get("guard_open_t",0)) <= 0 and (float(rig["guard"]) > 0.5 or (working >= 0 and i != working and float(rig["chain"]["shoulder"]) > 0.4))
		if working == i and attack.get("phase","") == "flight": braced = false
		var kind := "guard" if braced else "deflect"
		var target := "body" if float(rig["wrists"][i].y) < float(head.y) - 0.3 else "head"
		out.append({"part":"glove%d"%i,"kind":kind,"target":target,"a":origin+rig["wrists"][i],"b":origin+rig["wrists"][i],"r":Space.GLOVE_RADIUS})
		out.append({"part":"forearm%d"%i,"kind":kind,"target":target,"a":origin+rig["elbows"][i],"b":origin+rig["wrists"][i],"r":0.075})
	return out

static func moving_capsule(p0: Vector3, p1: Vector3, a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3, radius: float, flat_radius := -1.0) -> float:
	# Exact relative sphere sweep handles tangency without slow asymptotic
	# convergence. Guard/head spheres can both move in this interval.
	if flat_radius < 0 and a0 == b0 and a1 == b1:
		var delta := p0-a0; var velocity := (p1-p0)-(a1-a0)
		var c := delta.length_squared()-radius*radius
		if c <= 0: return 0
		var a := velocity.length_squared(); var b := delta.dot(velocity)
		var discriminant := b*b-a*c
		if a <= EPS*EPS or discriminant < -EPS*a: return -1
		var first := (-b-sqrt(maxf(0,discriminant)))/a
		return first if first >= 0 and first <= 1 else -1
	# Conservative advancement: distance to the moving segment is Lipschitz
	# bounded by point speed + the larger endpoint speed. No sample can jump
	# over a contact, including a moving guard which crosses between ticks.
	var speed := p0.distance_to(p1) + maxf(a0.distance_to(a1),b0.distance_to(b1))
	var t := 0.0
	for iteration in 128:
		var p := p0.lerp(p1,t); var a := a0.lerp(a1,t); var b := b0.lerp(b1,t)
		var ab := b-a
		var nearest := a + ab * clampf((p-a).dot(ab) / maxf(EPS*EPS,ab.length_squared()),0,1)
		var gap := p.distance_to(nearest) - radius
		if flat_radius > 0:
			# The torso proxy has flat top/bottom, matching the finite torso
			# rather than extending a spherical cap into the head target.
			var center := (a+b)*0.5
			var d := Vector2(Vector2(p.x-center.x,p.z-center.z).length()-flat_radius,absf(p.y-center.y)-absf(b.y-a.y)*0.5)
			gap = Vector2(maxf(d.x,0),maxf(d.y,0)).length() + minf(maxf(d.x,d.y),0) - (radius-flat_radius)
		if gap <= EPS: return t
		if speed <= EPS: return -1.0
		var advance := gap / speed
		if t + advance > 1.0: return -1.0
		t += advance
	return -1.0

static func sweep(p0: Vector3, p1: Vector3, previous: Array, current: Array, defense := true) -> Dictionary:
	var first := {}
	for i in current.size():
		var now: Dictionary = current[i]
		if not defense and now["kind"] != "hit": continue
		var before: Dictionary = previous[i] if previous.size() == current.size() else now
		var t := moving_capsule(p0,p1,before["a"],before["b"],now["a"],now["b"],Space.GLOVE_RADIUS + float(now["r"]),float(now["r"]) if now["part"]=="body" else -1.0)
		if t < 0: continue
		# Defensive surfaces win exact surface ties; otherwise true time of
		# contact, not a global guard flag, chooses what was touched first.
		if first.is_empty() or t < float(first["time"]) - EPS or (absf(t-float(first["time"])) <= EPS and now["kind"] != "hit"):
			first = {"time":t,"point":p0.lerp(p1,t),"kind":now["kind"],"target":now["target"],"part":now["part"]}
	return first

static func contact(fighter: Dictionary, other: Dictionary) -> Dictionary:
	var state: Dictionary = fighter.get("boxing",{})
	var action: Dictionary = state.get("action",{})
	if action.is_empty() or action["phase"] != "flight" or float(action["progress"]) < 0.3: return {}
	var index := 2 if str(action["row"]).begins_with("L_") else 4
	var from: Vector3 = state["previous"][index]["a"]
	var to: Vector3 = state["volumes"][index]["a"]
	var defender: Dictionary = other["boxing"]
	if not sweep(from,to,action["reference"],action["reference"],false).is_empty(): action["would_hit"] = true
	var hit := sweep(from,to,defender["previous"],defender["volumes"])
	if hit.is_empty() and int(fighter["pending"]["t"]) <= 0:
		var moved := Vector3(defender["volumes"][0]["a"]).distance_to(Vector3(action["reference"][0]["a"])) if not action["reference"].is_empty() else 0.0
		hit = {"kind":"miss","target":"body" if action["body"] else "head","time":1.0,"point":to,"part":"none","evaded":bool(action["would_hit"]) and moved > 0.04,"root_evaded":Vector2(other["pos"]).distance_to(action["defender_origin"]) > 0.04}
	if not hit.is_empty(): hit.merge({"attack_id":action["id"],"row":action["row"],"progress":action["progress"]})
	return hit

static func finish(fighter: Dictionary, contact_result: Dictionary) -> void:
	var state: Dictionary = fighter["boxing"]; var action: Dictionary = state["action"]
	action["phase"] = "recovery"; action["return_t"] = 0
	var hand := 0 if str(action["row"]).begins_with("L_") else 1
	var rig: Dictionary = state["rig"]
	var point: Vector3 = contact_result["point"] - Vector3(state["origin"])
	var arm := Motion.joint(rig["shoulders"][hand],point,rig["arm_poles"][hand],Motion.UPPER_ARM,Motion.FOREARM)
	rig["wrists"][hand] = arm["end"]; rig["elbows"][hand] = arm["joint"]; rig["hand_goals"][hand] = arm["end"]
	action["return_from"] = arm["end"]
	state["volumes"] = volumes(fighter,rig)
	state["solver"]["elbow_history"][hand] = Vector3(state["origin"]) + arm["joint"]
	state["contact"] = contact_result.duplicate(true)

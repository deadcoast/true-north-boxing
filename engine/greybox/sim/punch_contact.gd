extends RefCounted
## Fixed-tick boxing pose and moving-volume contact. Positions use RigSpace's
## world units; all persistent state is typed data inside the fighter snapshot.
const Motion := preload("res://presentation/boxing_motion.gd")
const Space := preload("res://presentation/rig_space.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
const EPS := 0.00001

static func transition(fighter: Dictionary, row: String) -> Dictionary:
	var state: Dictionary = fighter.get("boxing", {})
	var action: Dictionary = state.get("action", {})
	if not fighter.get("pending", {}).is_empty(): return {"allowed":false,"reason":"committed"}
	if action.is_empty(): return {"allowed":int(fighter.get("busy_t",0)) <= 0,"reason":"ready" if int(fighter.get("busy_t",0)) <= 0 else "interrupted"}
	if action.get("phase","") != "recovery": return {"allowed":false,"reason":"interrupted"}
	if int(fighter.get("busy_t",0)) > int(action["recovery_ticks"])-int(action["return_t"])+1:
		return {"allowed":false,"reason":"interrupted"}
	var rig: Dictionary = state["rig"]
	if row == "EXIT":
		var settled: bool = float(fighter.get("body_control",{}).get("support",1)) >= 0.70
		var folded := true
		for i in 2:
			folded = folded and Vector3(rig["wrists"][i]).distance_to(rig.get("hand_homes",rig["wrists"])[i]) < 0.28
		var ready: bool = float(action["return_t"])/int(action["recovery_ticks"]) >= 0.45 and absf(float(rig["chain"]["hips"])) < 0.45
		return {"allowed":settled and folded and ready,"reason":"recovering_exit"}
	var hand := 0 if row.begins_with("L_") else 1
	var previous_hand := 0 if str(action["row"]).begins_with("L_") else 1
	var same := hand == previous_hand
	var support := float(fighter.get("body_control",{}).get("support",1))
	if support < 0.70: return {"allowed":false,"reason":"foot_support"}
	var fatigue := clampf((30.0-float(fighter.get("stamina",100)))/30.0,0,1)
	var recovery := float(action["return_t"]) / int(action["recovery_ticks"])
	# A returning opposite hand can cover while the next side takes the load.
	# Reusing the same arm requires that arm to fold back into its launch space.
	var hand_distance: float = Vector3(rig["wrists"][hand]).distance_to(rig.get("hand_homes",rig["wrists"])[hand])
	var clearance := 0.20 if same else 0.28
	if hand_distance > clearance: return {"allowed":false,"reason":"hand_return"}
	var required := (0.52 if same else 0.20) + fatigue * 0.18
	# Deeply committed rotation must unload before reversing direction, and
	# before the same side can load again. This is shared by every punch family.
	if absf(float(rig["chain"]["hips"])) > (0.42 if same else 0.72): return {"allowed":false,"reason":"body_rotation"}
	return {"allowed":recovery >= required,"reason":"same_hand_reload" if same else "weight_transfer","recovery":recovery}

static func begin(fighter: Dictionary, other: Dictionary, row: String, mods: Array, startup: int, recovery: int, target: Vector3, reach: float) -> void:
	var state: Dictionary = fighter.get("boxing", {})
	var preceding: Dictionary = state.get("action",{}).duplicate(true)
	var origin := Space.ground(fighter["pos"])
	var forward := (Space.ground(other["pos"]) - origin).normalized()
	if forward.length_squared() < 0.1: forward = Vector3.FORWARD
	var offset := target - origin
	var horizontal := Vector3(offset.x, 0, offset.z)
	var radius := Space.BODY_RADIUS if "BODY" in mods else Space.HEAD_RADIUS
	var technique := Techniques.route(fighter,other,row,mods)
	if not technique.is_empty():
		reach = float(technique["reach"])
		var onset := maxi(1,roundi(startup*float(technique["startup"])))
		fighter["busy_t"] += onset-startup
		startup = onset; fighter["pending"]["startup"] = onset; fighter["pending"]["t"] = onset
		var adjusted := maxi(1,roundi(recovery*float(technique["recovery"])))
		fighter["busy_t"] += adjusted-recovery
		recovery = adjusted
		if fighter["pending"].has("recovery"): fighter["pending"]["recovery"] = adjusted
		var cost := float(fighter["pending"].get("stamina_cost",0))
		fighter["pending"]["stamina_cost"] = cost*float(technique["effort"])
	# Commit the aim once. Range comes from anatomy and actual root travel;
	# subsequent opponent movement cannot rewrite this endpoint or facing.
	var distance := minf(horizontal.length(), reach * Space.GROUND_SCALE)
	var endpoint := horizontal.normalized() * maxf(0.08, distance - radius - Space.GLOVE_RADIUS + 0.05)
	endpoint.y = offset.y
	var prepared: Dictionary = state.get("preparation", {})
	var evasion: Dictionary = state.get("evasion",{})
	var evade_axis: Vector2 = evasion.get("axis",Vector2.ZERO)
	var outside := evade_axis.x * (1 if str(evasion.get("row","")).begins_with("L_") else -1) > 0.2
	var rising_counter := not evasion.is_empty() and int(state.get("clock",0))-int(evasion["clock"]) <= 40 and "STRAIGHT" in str(evasion["row"]) and (evade_axis.y < -0.2 or outside)
	var matches: bool = prepared.get("row", "") == row
	state["serial"] = int(state.get("serial", 0)) + 1
	state["action"] = {"id":state["serial"], "row":row, "mods":mods.duplicate(), "body":"BODY" in mods,
		"startup":startup, "recovery_ticks":maxi(1,recovery), "return_t":0, "age":0, "phase":"flight", "progress":0.0,
		"start_progress":float(prepared.get("progress",0)) if matches else 0.0,
		"preload":float(prepared.get("preload",0)) if matches else 0.0,
		"target":endpoint, "target_center":offset, "forward":forward,
		"technique":technique,
		"rising_counter":rising_counter,
		"guard_start":float(fighter.get("pending",{}).get("guard_start",0)), "would_hit":false,
		"reference":other.get("boxing",{}).get("volumes",[]).duplicate(true), "defender_origin":other["pos"]}
	state["preparation"] = {}
	if state.has("rig"): state["action"]["start_wrists"] = state["rig"]["wrists"].duplicate()
	if not preceding.is_empty() and preceding.get("phase","") == "recovery" and state.has("rig"):
		state["action"]["start_chain"] = state["rig"]["chain"].duplicate()
		state["action"]["start_shoulders"] = state["rig"].get("shoulder_offsets",[Vector3.ZERO,Vector3.ZERO]).duplicate()
		state["action"]["start_spring"] = state["rig"].get("spring",0.0)
		state["action"]["start_lean"] = state["rig"].get("delivery_lean",Vector3.ZERO)
		var old_hand := 0 if str(preceding["row"]).begins_with("L_") else 1
		if old_hand != (0 if row.begins_with("L_") else 1):
			state["action"]["returning"] = {"hand":old_hand,"from":origin+state["rig"]["wrists"][old_hand],
				"twist":state["rig"]["twists"][old_hand],"pronation":state["rig"]["forearm_twists"][old_hand],
				"duration":maxi(1,int(preceding["recovery_ticks"])-int(preceding["return_t"]))}
	fighter["boxing"] = state
	state.erase("evasion") # The earned opening is spent by this deliberate attempt.
	fighter["pending"]["trajectory"] = true

static func sample(fighter: Dictionary, other: Dictionary, head: Dictionary, ticks: int, preparation: Dictionary = {}) -> void:
	var state: Dictionary = fighter.get("boxing", {})
	state["clock"] = int(state.get("clock",0)) + ticks
	var impacts: Array = state.get("impacts",[])
	for impact in impacts: impact["age"] = int(impact["age"]) + ticks
	state["impacts"] = impacts.filter(func(impact): return int(impact["age"]) < 72)
	var action: Dictionary = state.get("action",{})
	var attack := {}
	if action.is_empty() and preparation.is_empty() and not state.get("preparation",{}).is_empty():
		action = state["preparation"].duplicate(true)
		action.merge({"phase":"cancelled","return_t":0,"recovery_ticks":12,"return_from":state["rig"]["wrists"][0 if str(action["row"]).begins_with("L_") else 1]})
		state["action"] = action; state["preparation"] = {}
	if not action.is_empty():
		action["age"] = int(action.get("age",0)) + ticks
		if action["phase"] == "flight" and fighter.get("pending",{}).is_empty():
			state.get("technique_flow",{}).get("windows",{}).clear()
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
			attack["elapsed"] = int(action["age"])
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
	state["previous_rig"] = state.get("rig",rig).duplicate(true)
	state["previous_origin"] = state.get("origin",Space.ground(fighter["pos"]))
	state["origin"] = Space.ground(fighter["pos"])
	state["rig"] = rig; state["presentation"] = attack
	var current := volumes(fighter,rig)
	state["previous"] = state.get("volumes",current).duplicate(true)
	state["volumes"] = current
	fighter["boxing"] = state

static func volumes(fighter: Dictionary, rig: Dictionary) -> Array:
	var origin := Space.ground(fighter["pos"])
	var head: Vector3 = rig["head"]
	var collar: Vector3 = (rig["shoulders"][0] + rig["shoulders"][1]) * 0.5
	var top := collar
	var bottom: Vector3 = rig["pelvis"] + Vector3.UP * 0.04
	var out := [{"part":"head","kind":"hit","target":"head","a":origin+head,"b":origin+head,"r":Space.HEAD_RADIUS},
		{"part":"body","kind":"hit","target":"body","a":origin+bottom,"b":origin+top,"r":Space.BODY_RADIUS}]
	var attack: Dictionary = fighter.get("boxing",{}).get("action",{})
	var working := -1 if attack.is_empty() else (0 if str(attack["row"]).begins_with("L_") else 1)
	for i in 2:
		# Hands remain physical when the guard button is released. An unbraced
		# interception deflects; a properly covered arm absorbs guard damage.
		var braced: bool = int(fighter.get("guard_open_t",0)) <= 0 and (float(rig["guard"]) > 0.5 or (working >= 0 and i != working and float(rig["chain"]["shoulder"]) > 0.4))
		if working == i and attack.get("phase","") == "flight": braced = false
		# Neither the recovering punch nor a previous hand still returning in
		# a combination is a braced guard merely because the button is held.
		if Vector3(rig["wrists"][i]).distance_to(rig.get("hand_homes",rig["wrists"])[i]) > 0.20: braced = false
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
	if flat_radius > 0:
		# A rotating flat cylinder also sweeps its rim. Endpoint speed alone
		# bounds a capsule but can skip the rim of the finite torso cylinder.
		var axis0 := b0-a0; var axis_delta := (b1-a1)-axis0
		var nearest_t := clampf(-axis0.dot(axis_delta)/maxf(EPS*EPS,axis_delta.length_squared()),0,1)
		var minimum_length := maxf(EPS,(axis0+axis_delta*nearest_t).length())
		speed += flat_radius * axis_delta.length() / minimum_length
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
			var axis := ab.normalized() if ab.length_squared() > EPS*EPS else Vector3.UP
			var local := p-center; var along := local.dot(axis)
			var d := Vector2((local-axis*along).length()-flat_radius,absf(along)-ab.length()*0.5)
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
	# A rising punch loads downward before delivery. The loading hand is not
	# a downward scoring strike: the old universal 30% gate hit a low guard
	# while the uppercut was still being prepared. Use its actual upward path.
	var rising: bool="UPPERCUT" in str(action["row"]) or "HOOKERCUT" in str(action["row"])
	if rising and int(fighter["pending"]["t"])>0 and to.y<=from.y:return {}
	# Raising a straight from a low home is preparation too. Its delivery
	# faces down the committed lane; lifting past a nearby glove is not a jab.
	if "STRAIGHT" in str(action["row"]) and int(fighter["pending"]["t"])>0 and (to-from).normalized().dot(action["forward"])<0.5:return {}
	var defender: Dictionary = other["boxing"]
	if not sweep(from,to,action["reference"],action["reference"],false).is_empty(): action["would_hit"] = true
	var hit := sweep(from,to,defender["previous"],defender["volumes"])
	if hit.is_empty() and int(fighter["pending"]["t"]) <= 0:
		var moved := Vector3(defender["volumes"][0]["a"]).distance_to(Vector3(action["reference"][0]["a"])) if not action["reference"].is_empty() else 0.0
		hit = {"kind":"miss","target":"body" if action["body"] else "head","time":1.0,"point":to,"part":"none","evaded":bool(action["would_hit"]) and moved > 0.04,"root_evaded":Vector2(other["pos"]).distance_to(action["defender_origin"]) > 0.04}
		if hit["evaded"]:
			defender["evasion"] = {"clock":defender["clock"],"axis":other.get("body_control",{}).get("axis",Vector2.ZERO),"row":action["row"]}
	if not hit.is_empty(): hit.merge({"attack_id":action["id"],"row":action["row"],"progress":action["progress"],"direction":(to-from).normalized() if to.distance_squared_to(from)>0.000001 else action["forward"],"technique":action.get("technique",{}).get("id","")})
	return hit

static func react(fighter: Dictionary, result: Dictionary, damage: float) -> void:
	# Queue the adjudicated impact, never a separate presentation hit test.
	# These bounded game response amplitudes are not measured physical forces.
	if result.is_empty() or result.get("kind","") not in ["hit","guard"] or damage <= 0: return
	var state: Dictionary = fighter.get("boxing",{})
	if state.is_empty(): return
	var impacts: Array = state.get("impacts",[])
	impacts.append({"age":0,"direction":Vector3(result.get("direction",Vector3.ZERO)).normalized(),"target":result["target"],"guarded":result["kind"]=="guard","strength":clampf(damage/18.0,0.12,1.0)})
	if impacts.size()>3: impacts.pop_front()
	state["impacts"]=impacts

static func finish(fighter: Dictionary, contact_result: Dictionary) -> void:
	var state: Dictionary = fighter["boxing"]; var action: Dictionary = state["action"]
	action["phase"] = "recovery"; action["return_t"] = 0
	# Contact starts the actual return; unused outgoing flight is not a second
	# cooldown after a glove has already stopped on its first physical surface.
	var natural_wait := int(action["recovery_ticks"]) + maxi(0,int(fighter.get("pending",{}).get("t",0)))
	# The launch tick decrements pending after setting busy; subsequent ticks
	# decrement both. Preserve that one-tick offset when recognizing the clock.
	if int(fighter["busy_t"]) <= natural_wait + 1: fighter["busy_t"] = int(action["recovery_ticks"])
	var hand := 0 if str(action["row"]).begins_with("L_") else 1
	var rig: Dictionary = state["rig"].duplicate(true)
	# CCD stops the hand partway through this tick. Stop its connected body
	# at that same instant: using the end-of-tick chest can push it through
	# the impact glove and force the clearance solver off the struck surface.
	if contact_result["kind"]!="miss" and state.has("previous_rig"):
		var previous: Dictionary=state["previous_rig"]
		var shift: Vector3=Vector3(state["previous_origin"])-Vector3(state["origin"])
		var fraction:=float(contact_result["time"])
		var points:=["pelvis","chest","head","head_goal","shoulders","hip_joints","ankles","feet","knees","elbows","wrists","hand_goals","delivery_targets","contact_centers","support_elbows","support_knees","guard_reference","guard_homes","hand_homes"]
		for channel in rig:
			if not previous.has(channel):continue
			var offset:=shift if channel in points else Vector3.ZERO
			if rig[channel] is Vector3:rig[channel]=(Vector3(previous[channel])+offset).lerp(rig[channel],fraction)
			elif rig[channel] is float:rig[channel]=lerpf(previous[channel],rig[channel],fraction)
			elif rig[channel] is Array:
				for i in rig[channel].size():
					rig[channel][i]=lerp(previous[channel][i]+offset,rig[channel][i],fraction) if rig[channel][i] is Vector3 else lerp(previous[channel][i],rig[channel][i],fraction)
	# The normal routing margin is spare clearance, not extra anatomy. At a
	# swept impact keep real surfaces separated without pushing the glove
	# away merely to restore that spare margin.
	rig["clearance_margin"]=0.0001
	var point: Vector3 = contact_result["point"] - Vector3(state["origin"])
	# Contact corrects the glove to the swept surface; it must retain the
	# already constrained elbow plane. The authored pole predates the final
	# body/IK correction and reusing it causes an unrelated impact pose pop.
	var contact_pole: Vector3 = rig["elbows"][hand]-rig["shoulders"][hand]
	var arm := Motion.joint(rig["shoulders"][hand],point,contact_pole,Motion.UPPER_ARM,Motion.FOREARM)
	rig["wrists"][hand] = arm["end"]; rig["elbows"][hand] = arm["joint"]; rig["hand_goals"][hand] = arm["end"]
	# This endpoint is already in the final body frame. Interpolation must
	# not add the moving guard anchor to the contact-corrected glove again.
	if rig.has("guard_weights"):rig["guard_weights"][hand]=0.0
	rig["arm_poles"][hand]=arm["joint"]-rig["shoulders"][hand]
	rig["support_elbows"][hand]=arm["joint"]
	# The impact endpoint must pass the same self-clearance solve as the next
	# render frame. Save its final elbow plane so interpolation cannot choose
	# another bend after the simulation has already adjudicated the contact.
	rig=Motion.constrain(rig);state["rig"]=rig
	action["return_from"] = rig["wrists"][hand]
	state["volumes"] = volumes(fighter,rig)
	state["solver"]["elbow_history"][hand] = Vector3(state["origin"]) + rig["elbows"][hand]
	state["contact"] = contact_result.duplicate(true)

extends RefCounted
## Presentation only. Every pose reads the sim; no RNG, combat timers or rules are changed.
const Sim := preload("res://sim/core.gd")
const Space := preload("res://presentation/rig_space.gd")
const BoxingMotion := preload("res://presentation/boxing_motion.gd")
const CHASE := 1.8
const HEAD_CLEARANCE := 0.6
const FOV := 55.0
const WINDUP_ALPHA := 0.4
const SILHOUETTE := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 tint : source_color;
uniform vec4 clear_window;
uniform vec3 aura;
uniform bool foreground_only = false;
uniform vec3 clear_origin;
uniform vec3 clear_normal;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 edge = min(SCREEN_UV - clear_window.xy, clear_window.zw - SCREEN_UV);
    float inside = smoothstep(0.0, 0.025, min(edge.x, edge.y));
    if (foreground_only) { inside *= step(0.0, dot(world_position - clear_origin, clear_normal)); }
    ALBEDO = tint.rgb;
    EMISSION = aura;
    ALPHA = tint.a * mix(1.0, 0.08, inside);
    ROUGHNESS = 0.85;
}"""
var orbit := Vector3.ZERO
var last_tick := -1
var strikes := {}
var frozen_ticks := 0
var clock_sim = null
var reactions := {}
var clock_tick := -1
var motion_solvers := {}
var attacks := {}
var tell_clock := {}
var hold_ticks := 1
var offers := {}
var travels := {}
var before_positions := {}

func _sync_clock(sim) -> void:
	if clock_sim != sim or sim.tick < clock_tick:
		clock_sim = sim; frozen_ticks = 0; strikes.clear(); reactions.clear()
		motion_solvers.clear()
		attacks.clear(); tell_clock.clear(); offers.clear(); travels.clear(); before_positions.clear(); hold_ticks = 1
	clock_tick = sim.tick

func bump(root: Node3D, amount: float, sim) -> void:
	root.set_meta("bump", {"tick": sim.tick - frozen_ticks, "amount": amount, "sim": sim.get_instance_id()})

func before_step(sim) -> void:
	_sync_clock(sim)
	# tick counts input opportunities through hitstop; animation counts fight time.
	if sim.freeze_t > 0 or sim.mode != "FIGHT": frozen_ticks += 1
	before_positions = {"P": sim.P["pos"], "B": sim.B["pos"]}

func capture(root: Node3D, fighter: Dictionary, other: Dictionary, sim, who: String) -> void:
	_sync_clock(sim)
	pose(root, fighter, other, sim, who)
	root.set_meta("previous_rig", root.get_meta("kinematics").duplicate(true))
	root.set_meta("previous_sim", sim.get_instance_id())

static func _part(parent: Node3D, mesh: PrimitiveMesh, material: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	mesh.material = material; node.mesh = mesh; node.position = at; parent.add_child(node)
	return node

static func make_fighter(parent: Node3D, color: Color, at: Vector3) -> Node3D:
	var root := Node3D.new(); parent.add_child(root); root.position = at
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.85
	var torso := CylinderMesh.new(); torso.top_radius = Space.BODY_RADIUS; torso.bottom_radius = Space.BODY_RADIUS; torso.height = 0.57; torso.radial_segments = 16
	var body := _part(root, torso, mat, Vector3(0, 1.04, 0)); body.scale.z = 0.70
	root.set_meta("mesh", body); root.set_meta("mat", mat)
	var shorts_mat := mat.duplicate() as StandardMaterial3D; shorts_mat.albedo_color = color.darkened(0.45)
	var hips := BoxMesh.new(); hips.size = Vector3(0.39, 0.23, 0.29)
	root.set_meta("hips", _part(root, hips, shorts_mat, Vector3(0, 0.77, 0)))
	var abdomen := CylinderMesh.new(); abdomen.top_radius = Space.BODY_RADIUS; abdomen.bottom_radius = 0.19; abdomen.height = 1.0
	root.set_meta("abdomen", _part(root, abdomen, mat, Vector3.ZERO))
	var hmat := mat.duplicate() as StandardMaterial3D; hmat.albedo_color = color.lightened(0.35)
	var ball := SphereMesh.new(); ball.radius = 0.18; ball.height = 0.36
	root.set_meta("head", _part(root, ball, hmat, Vector3(0, Sim.HEAD_H, 0)))
	var neck := CylinderMesh.new(); neck.top_radius = 0.085; neck.bottom_radius = 0.10; neck.height = 1
	root.set_meta("neck", _part(root, neck, hmat, Vector3(0, 1.4, 0)))
	var joints := []
	var clavicles := []
	var gloves := []; var arms := []; var uppers := []; var legs := []; var thighs := []; var boots := []
	var glove_mat := mat.duplicate() as StandardMaterial3D; glove_mat.albedo_color = color.lightened(0.16)
	for side in [-1.0, 1.0]:
		var collar := CylinderMesh.new(); collar.top_radius = 0.085; collar.bottom_radius = 0.085; collar.height = 1.0
		clavicles.append(_part(root, collar, mat, Vector3.ZERO))
		var glove := SphereMesh.new(); glove.radius = 0.14; glove.height = 0.28
		gloves.append(_part(root, glove, glove_mat, Vector3(side * 0.36, 1.35, -0.25)))
		gloves[-1].scale = Vector3.ONE
		var thumb := SphereMesh.new(); thumb.radius = 0.065; thumb.height = 0.16
		_part(gloves[-1], thumb, glove_mat, Vector3(-side * 0.10, -0.065, 0))
		var arm := CylinderMesh.new(); arm.top_radius = 0.075; arm.bottom_radius = 0.085; arm.height = 1.0
		var limb := _part(root, arm, glove_mat, Vector3(side * 0.32, 1.3, -0.125))
		var vector := Vector3(side * 0.08, 0.1, -0.25)
		limb.quaternion = Quaternion(Vector3.UP, vector.normalized()); limb.scale.y = vector.length()
		arms.append(limb)
		var upper := CylinderMesh.new(); upper.top_radius = 0.078; upper.bottom_radius = 0.115; upper.height = 1.0
		uppers.append(_part(root, upper, mat, Vector3(side * 0.27, 1.15, 0)))
		var leg := CylinderMesh.new(); leg.top_radius = 0.065; leg.bottom_radius = 0.095; leg.height = 1.0
		legs.append(_part(root, leg, mat, Vector3(side * 0.16, 0.30, 0)))
		var thigh := CylinderMesh.new(); thigh.top_radius = 0.09; thigh.bottom_radius = 0.12; thigh.height = 1.0
		thighs.append(_part(root, thigh, shorts_mat, Vector3(side * 0.16, 0.61, 0)))
		var boot := BoxMesh.new(); boot.size = Vector3(0.16, 0.13, 0.32)
		boots.append(_part(root, boot, shorts_mat, Vector3(side * 0.19, 0.065, 0)))
		for radius in [0.105, 0.084, 0.095]:
			var joint_mesh := SphereMesh.new(); joint_mesh.radius = radius; joint_mesh.height = radius * 2
			joints.append(_part(root, joint_mesh, mat, Vector3.ZERO))
	root.set_meta("joints", joints)
	root.set_meta("clavicles", clavicles)
	root.set_meta("gloves", gloves); root.set_meta("arms", arms); root.set_meta("legs", legs)
	root.set_meta("upper_arms", uppers); root.set_meta("thighs", thighs); root.set_meta("boots", boots)
	root.set_meta("glove_mat", glove_mat)
	return root

static func _link(mesh: Node3D, start: Vector3, end: Vector3) -> void:
	var vector := end - start
	mesh.position = (start + end) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, vector.normalized())
	mesh.scale = Vector3(1, maxf(0.01, vector.length()), 1)

func observe(event: Dictionary, tick: int) -> void:
	# Boss punches resolve on their VM tick. Hold the contact pose through hitstop,
	# then retract on sim time. Player contact uses the same path after startup.
	if event.get("kind") == "boss_act" and event.get("verb") == "move" and clock_sim != null:
		# VM travel is an authored instantaneous tactical edit. Carry that edit
		# through a planted step visually, without changing its outcome/timer.
		for who in ["P", "B"]:
			var fighter: Dictionary = clock_sim.P if who == "P" else clock_sim.B
			var delta: Vector2 = fighter["pos"] - before_positions.get(who, fighter["pos"])
			if delta.length_squared() > 0.000001:
				var remaining := _travel(who, clock_sim)
				travels[who] = {"tick": tick - frozen_ticks, "sim_tick": tick, "prior": remaining, "offset": remaining - delta}
				before_positions[who] = fighter["pos"]
	elif event.get("kind") == "boss_act" and event.get("verb") == "punch":
		var gap := int(clock_sim.btimer) if clock_sim != null and not clock_sim.bqueue.is_empty() else 48
		strikes["B"] = {"tick": tick - frozen_ticks, "row": event["row"], "body": event.get("body", false), "retract": clampi(gap / 2, 4, 24), "gap": gap}
	elif event.get("kind") == "punch":
		# The initiating sim step also consumes the first startup tick.
		var remaining := 24
		if clock_sim != null: remaining = maxi(4, int(clock_sim.P["busy_t"]) - int(clock_sim.P.get("pending", {}).get("t", 0)))
		strikes["P"] = {"tick": tick - frozen_ticks + maxi(0, int(event.get("startup", 0)) - 1), "row": event["row"], "body": "BODY" in event.get("mods", []), "mods": event.get("mods", []).duplicate(), "range_bonus": float(clock_sim.P.get("pending", {}).get("range_bonus", 0)), "retract": remaining}
	elif event.get("kind") == "hit":
		reactions[str(event["on"])] = {"tick": tick - frozen_ticks, "weight": clampf(float(event.get("dmg", 6)) / 30, 0.15, 1.0), "body": event.get("body", false), "displacement": event.get("displacement", Vector2.ZERO), "sim_tick": tick}
	elif event.get("kind") == "feint":
		_cancel("P", tick - frozen_ticks, maxi(1, int(clock_sim.P["busy_t"])))
	elif event.get("kind") == "interrupt":
		_cancel("B", tick - frozen_ticks, mini(24, maxi(1, int(event.get("stagger", 24)))))
	elif event.get("kind") == "tell":
		tell_clock = {"at": tick - frozen_ticks, "ticks": event.get("ticks", 1), "string": event.get("string", "")}
	elif event.get("kind") == "feint_b" and event.get("mode") == "delay":
		hold_ticks = maxi(1, int(clock_sim.btimer))
	elif event.get("kind") == "recover" and float(attacks.get("B", {}).get("preload", 0)) > 0:
		# A fake tell has no punch/contact event. Release its coil instead of
		# dropping the loaded torso to neutral in a single frame.
		_cancel("B", tick - frozen_ticks, mini(24, maxi(1, int(clock_sim.btimer))))
	elif event.get("kind") in ["drop", "matchup", "bout_end"]:
		strikes.clear(); attacks.clear(); tell_clock.clear()

func _cancel(who: String, tick: int, duration: int) -> void:
	var attack: Dictionary = attacks.get(who, {}).duplicate(true)
	strikes.erase(who)
	if attack.is_empty(): return
	strikes[who] = {"tick": tick, "retract": duration, "cancelled": attack}

static func tell_row(sim) -> String:
	return str(_tell_attack(sim, sim.bstring).get("row", ""))

static func _tell_attack(sim, name: String) -> Dictionary:
	var string: Dictionary = sim.pattern.get("strings", {}).get(name, {})
	for action in string.get("actions", []):
		var verb := str(action).split("(")[0].split(" ")[0]
		# A counter stance/clinch arms first; its later punch has its own VM
		# delivery. Showing contact at the end of the tell invents a first hit.
		if verb in ["COUNTER_STATE", "COUNTER_ON_BLOCK", "CLINCH_ATTEMPT"]: return {}
		if Sim.PUNCH_VERBS.has(verb): return {"row": str(Sim.PUNCH_VERBS[verb]), "body": verb.begins_with("LT_")}
		if verb in ["BODY_SERIES", "WALK_STRING"]: return {"row": "L_HOOK", "body": verb == "BODY_SERIES"}
		# The VM chooses MIXED_STRING's hand later. Do not resolve it early or
		# consume the sim RNG while rendering: show a two-handed coil instead.
		if verb == "MIXED_STRING": return {}
	return {}

static func _blend_rig(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	# Blend both hands and their body chain during a redirected feint. The
	# replacement punch still reaches its pose on the unchanged VM contact tick.
	var out := to.duplicate(true)
	for channel in to:
		if to[channel] is Vector3 or to[channel] is float:
			out[channel] = lerp(from[channel], to[channel], weight)
		elif to[channel] is Array:
			for i in to[channel].size(): out[channel][i] = lerp(from[channel][i], to[channel][i], weight)
	return out

func _travel(who: String, sim, previous := false) -> Vector2:
	var travel: Dictionary = travels.get(who, {})
	if travel.is_empty(): return Vector2.ZERO
	if previous and sim.tick == int(travel["sim_tick"]): return travel["prior"]
	var age: int = sim.tick - frozen_ticks - int(travel["tick"])
	if previous and sim.freeze_t <= 0: age = maxi(0, age - 1)
	return (travel["offset"] as Vector2) * (1.0 - BoxingMotion.ramp(float(age) / 12.0))

func displacement(who: String, sim, previous := false) -> Vector2:
	var hit: Dictionary = reactions.get(who, {})
	var travel := _travel(who, sim, previous)
	if hit.is_empty() or (previous and sim.tick == int(hit.get("sim_tick", -1))): return travel
	var age: int = sim.tick - frozen_ticks - int(hit["tick"])
	if previous and sim.freeze_t <= 0: age = maxi(0, age - 1)
	# Freeze contact before the already-resolved push. Release the visible
	# recoil over 12 active ticks; simulation herding/scoring remain unchanged.
	return travel - (hit.get("displacement", Vector2.ZERO) as Vector2) * (1.0 - BoxingMotion.ramp(float(age) / 12.0))

func position(from: Vector2, to: Vector2, who: String, sim, alpha: float) -> Vector2:
	_sync_clock(sim)
	return (from + displacement(who, sim, true)).lerp(to + displacement(who, sim), alpha)

func pose(root: Node3D, fighter: Dictionary, other: Dictionary, sim, who: String, alpha := 1.0) -> void:
	_sync_clock(sim)
	fighter = fighter.duplicate(); other = other.duplicate()
	var physical_fighter := fighter.duplicate(); var physical_other := other.duplicate()
	# Hit events carry the post-resolution shove. Eligibility on the contact
	# frame belongs to the pre-shove positions, as does the frozen impact pose.
	for pair in [[who, physical_fighter], ["B" if who == "P" else "P", physical_other]]:
		var hit: Dictionary = reactions.get(pair[0], {})
		if int(hit.get("tick", -1)) == sim.tick - frozen_ticks: pair[1]["pos"] -= hit.get("displacement", Vector2.ZERO)
	fighter["motion_identity"] = sim.pname() if who == "P" else sim.boss_label if not sim.bout.is_empty() or not sim.bgeneric.is_empty() else sim.boss_name
	var profile := BoxingMotion.style_profile(fighter)
	var identity := str(fighter["motion_identity"]) + ":" + str(fighter.get("style", ""))
	if root.get_meta("motion_identity", "") != identity:
		motion_solvers[who] = BoxingMotion.new(); root.remove_meta("previous_sim")
		root.set_meta("motion_identity", identity); offers.erase(who)
	var active_tick: int = sim.tick - frozen_ticks
	var offer: Dictionary = offers.get(who, {"tick": active_tick, "weight": 0.0})
	var motif := str(sim.pattern.get("strings", {}).get(sim.bstring, {}).get("tell", {}).get("motif", ""))
	var gear_tell: bool = who == "B" and sim.bstate in ["TELL", "HOLD"] and motif.begins_with("glove_micro_turn")
	offer["gear"] = move_toward(float(offer.get("gear", 0)), 1.0 if gear_tell else 0.0, maxi(0, active_tick - int(offer["tick"])) / 12.0)
	offer["weight"] = move_toward(float(offer["weight"]), 1.0 if who == "B" and sim.hands_down_t > 0 else 0.0, maxi(0, active_tick - int(offer["tick"])) / 12.0)
	offer["tick"] = active_tick; offers[who] = offer; fighter["motion_offer"] = offer["weight"]
	fighter["motion_gear"] = offer["gear"]
	fighter["pos"] += displacement(who, sim); other["pos"] += displacement("B" if who == "P" else "P", sim)
	var fwd2: Vector2 = (other["pos"] - fighter["pos"]).normalized()
	if fwd2.length_squared() < 0.1: fwd2 = Vector2(0, -1)
	var forward := Vector3(fwd2.x, 0, fwd2.y)
	var head: MeshInstance3D = root.get_meta("head")
	var body: MeshInstance3D = root.get_meta("mesh")
	var geometric_head: Dictionary = sim._head_world(fighter, other)
	var displacement: Vector2 = geometric_head["p"] - fighter["pos"]
	var offset := Space.ground(displacement); var height: float = geometric_head["h"]
	var dodge := str(fighter.get("dodge", ""))
	head.position = offset + Vector3.UP * height
	body.scale = Vector3(1, lerpf(1, 0.92, Sim.dodge_weight(fighter)) if dodge in ["DUCK", "WEAVE"] else 1.0, 0.70)
	body.rotation.y = atan2(forward.x, forward.z)
	var row := ""; var load := 0.0; var extension := 0.0; var body_target := false
	var punch_progress := 0.0; var recovery := 0.0
	var mods: Array = []
	var redirect := {}; var redirect_weight := 0.0; var redirect_progress := 0.0
	var strike: Dictionary = strikes.get(who, {})
	var strike_age: int = sim.tick - frozen_ticks - int(strike.get("tick", -1000))
	var retract_ticks := int(strike.get("retract", 24))
	var windup: bool = who == "B" and sim.bstate in ["TELL", "FAKE", "HOLD", "CAST", "SURGE"]
	if strike.has("cancelled") and strike_age >= 0 and strike_age < retract_ticks:
		var cancelled: Dictionary = strike["cancelled"]
		row = str(cancelled.get("row", "")); body_target = bool(cancelled.get("body", false))
		mods = cancelled.get("mods", [])
		punch_progress = float(cancelled.get("progress", 0))
		recovery = lerpf(float(cancelled.get("recovery", 0)), 1.0, float(strike_age) / retract_ticks)
		load = float(cancelled.get("preload", 0)) * (1.0 - BoxingMotion.ramp(float(strike_age) / retract_ticks))
		redirect = cancelled.get("redirect", {}); redirect_weight = float(cancelled.get("redirect_weight", 0))
		redirect_progress = float(cancelled.get("redirect_progress", 0))
		extension = pow(punch_progress, 3) * (1.0 - BoxingMotion.ramp(recovery))
	elif who == "B" and not strike.has("cancelled") and strike_age >= 0 and strike_age < retract_ticks:
		# Contact owns the hand before the next VM action winds up. Split a short
		# string gap into retraction and delivery, retaining both authored beats.
		row = str(strike["row"]); body_target = bool(strike["body"])
		punch_progress = 1.0; recovery = float(strike_age) / retract_ticks
		extension = 1.0 - BoxingMotion.ramp(recovery)
	elif windup:
		var told := _tell_attack(sim, sim.bstring)
		row = str(told.get("row", "")); body_target = bool(told.get("body", false))
		var tell: Dictionary = sim.pattern.get("strings", {}).get(sim.bstring, {}).get("tell", {})
		var ms := float(tell.get("ms", 700))
		var tier := 1.0 if ms >= 600 else (0.75 if ms >= 450 else 0.55)
		if sim.pi_cue(): tier *= 1.15
		if tell_clock.get("string", "") != sim.bstring:
			tell_clock = {"at": sim.tick - frozen_ticks, "ticks": sim.btimer, "string": sim.bstring}
		load = tier * BoxingMotion.ramp(float(sim.tick - frozen_ticks - int(tell_clock.get("at", 0))) / maxf(1, Sim.ms(ms * 0.4)))
		if sim.bfeint == "cancel":
			redirect = told
			redirect_progress = 0.22 * load / maxf(tier, 0.01)
			var into := str(sim.pattern["strings"][sim.bstring].get("feint", {}).get("into", ""))
			var replacement := _tell_attack(sim, into)
			if not replacement.is_empty():
				row = str(replacement["row"]); body_target = bool(replacement["body"])
		if row != "" and sim.bstate in ["TELL", "HOLD"]:
			var swing := Sim.ms(float(sim.T["punch_matrix"][row]["startup_ms"]))
			if sim.bstate == "HOLD":
				punch_progress = lerpf(0.22, 1.0, clampf(1.0 - float(sim.btimer) / mini(swing, hold_ticks), 0, 1))
			elif sim.bfeint == "delay":
				punch_progress = 0.22 * BoxingMotion.ramp(1.0 - float(sim.btimer) / maxi(1, int(tell_clock.get("ticks", swing))))
			else: punch_progress = clampf(1.0 - float(sim.btimer) / swing, 0, 1)
			redirect_weight = BoxingMotion.ramp(punch_progress)
			extension = pow(punch_progress, 3)
	elif who == "B" and sim.bstate == "ACTING" and not sim.bqueue.is_empty() and sim.bqueue[0].get("kind") == "punch" and sim.btimer <= 18:
		row = str(sim.bqueue[0]["row"]); body_target = bool(sim.bqueue[0].get("body", false))
		var delivery := mini(18, maxi(1, int(strike.get("gap", 36)) - retract_ticks))
		var progress := clampf(1.0 - float(sim.btimer) / delivery, 0, 1)
		punch_progress = progress
		load = sin(progress * PI) * 0.65; extension = pow(progress, 3)
	elif who == "P" and not fighter.get("pending", {}).is_empty():
		var pending: Dictionary = fighter["pending"]
		row = str(pending["row"]); body_target = "BODY" in pending["mods"]
		mods = pending["mods"]
		var progress := 1.0 - float(pending["t"]) / maxf(1, float(pending["startup"]))
		punch_progress = progress
		load = sin(progress * PI) * (1.2 if "HAYMAKER" in pending["mods"] else 0.5)
		extension = pow(progress, 3)
	elif strikes.has(who):
		if who == "P" and not strike.has("cancelled") and strike_age >= 0 and strike_age < retract_ticks:
			row = str(strike["row"]); body_target = bool(strike["body"])
			mods = strike.get("mods", [])
			punch_progress = 1.0; recovery = clampf(float(strike_age - 3) / maxi(1, retract_ticks - 3), 0, 1)
			extension = 1.0 - BoxingMotion.ramp(recovery)
	var reaction := 0.0
	if reactions.has(who):
		var hit: Dictionary = reactions[who]
		var age := float(sim.tick - frozen_ticks - int(hit["tick"]))
		reaction = float(hit["weight"]) * maxf(0, 1.0 - age / 28.0)
	var range_bonus := float(fighter.get("pending", {}).get("range_bonus", strike.get("range_bonus", 0)))
	var region := sim.contact_region(fighter, other, row if row != "" else "L_STRAIGHT", body_target, range_bonus) as Dictionary
	var physical_region: Dictionary = sim.contact_region(physical_fighter, physical_other, row if row != "" else "L_STRAIGHT", body_target, range_bonus)
	# Travel compensation changes the drawn separation, never hit eligibility.
	# Reach the drawn surface for a real hit; leave clearance for a real miss.
	region["result"] = physical_region["result"]
	if region["result"] == "HIT": region["reach"] = maxf(float(region["reach"]), float(region["d"]))
	elif region["result"] == "MISS_REACH": region["reach"] = minf(float(region["reach"]), float(region["d"]) - 0.02)
	var target := Space.contact(region)
	if not motion_solvers.has(who): motion_solvers[who] = BoxingMotion.new()
	var attack := {"row": row, "progress": punch_progress, "recovery": recovery, "body": body_target, "mods": mods.duplicate(), "target": target, "range_bonus": range_bonus, "preload": load if windup or strike.has("cancelled") else 0.0, "redirect": redirect, "redirect_weight": redirect_weight, "redirect_progress": redirect_progress}
	attack["target_center"] = Space.ground(region["target"] - fighter["pos"]) + Vector3.UP * float(region["h"])
	attack["target_radius"] = Space.GLOVE_RADIUS + (Space.BODY_RADIUS if body_target else Space.HEAD_RADIUS)
	attack["contact_hit"] = region["result"] == "HIT"
	attacks[who] = attack
	var rig: Dictionary = motion_solvers[who].sample(fighter, other, sim.tick - frozen_ticks, attack, offset + Vector3.UP * (height - Sim.HEAD_H))
	if not redirect.is_empty():
		var false_attack := attack.duplicate(); false_attack.merge(redirect, true)
		false_attack["progress"] = redirect_progress
		false_attack["target"] = Space.contact(sim.contact_region(fighter, other, str(false_attack["row"]), bool(false_attack["body"]), range_bonus))
		var false_rig: Dictionary = motion_solvers[who].sample(fighter, other, sim.tick - frozen_ticks, false_attack, offset + Vector3.UP * (height - Sim.HEAD_H))
		rig = _blend_rig(false_rig, rig, redirect_weight)
	# Preserve hit/feint/taunt/drop impulses on the connected rig. Compress
	# hips and ribcage before solving limbs; a detached torso bob is invalid.
	var impulse: Dictionary = root.get_meta("bump", {})
	if impulse.get("sim", -1) == sim.get_instance_id():
		var age: int = sim.tick - frozen_ticks - int(impulse["tick"])
		var compression := float(impulse["amount"]) * maxf(0, 1.0 - float(age) / 14.0) if age >= 0 else 0.0
		rig["pelvis"].y -= compression; rig["chest"].y -= compression * 0.5
		for i in 2:
			rig["hip_joints"][i].y -= compression; rig["shoulders"][i].y -= compression * 0.5
		if sim.mode != "FIGHT": rig["head"].y -= compression * 0.5
	# Apply torso reactions to the connected shoulder girdle, before IK.
	var reaction_offset := -forward * reaction * 0.06
	rig["chest"] += reaction_offset
	for i in 2: rig["shoulders"][i] += reaction_offset
	root.set_meta("kinematics", BoxingMotion.constrain(rig.duplicate(true)))
	if alpha < 1.0 and root.get_meta("previous_sim", -1) == sim.get_instance_id():
		rig = _blend_rig(root.get_meta("previous_rig"), rig, alpha)
	rig = BoxingMotion.constrain(rig)
	root.set_meta("render_kinematics", rig); root.set_meta("contact_region", region); root.set_meta("contact_target", target)
	head.position = rig["head"]
	forward = (rig["forward"] as Vector3).normalized()
	var facing := atan2(forward.x, forward.z)
	var collar: Vector3 = (rig["shoulders"][0] + rig["shoulders"][1]) * 0.5
	# Same 40% lateral / full retreat path as the body contact region, sampled
	# from the interpolated head so the skin and aim point travel together.
	var right := forward.cross(Vector3.UP)
	var torso_origin := forward * head.position.dot(forward) + right * head.position.dot(right) * 0.4
	var body_height := 1.10 + minf(0, head.position.y - Sim.HEAD_H)
	var torso_top := torso_origin + Vector3.UP * minf(float(head.position.y) - Space.HEAD_RADIUS - 0.025, maxf(body_height + 0.02, collar.y - 0.06))
	var torso_bottom := torso_origin + Vector3.UP * minf(body_height - 0.02, maxf(body_height - 0.16, float(rig["pelvis"].y) + 0.02))
	_link(root.get_meta("abdomen"), rig["pelvis"], torso_bottom)
	_link(body, torso_bottom, torso_top)
	body.scale.y /= 0.57
	body.rotate_object_local(Vector3.UP, facing + float(rig["chest_turn"]))
	_link(root.get_meta("neck"), torso_top, head.position - Vector3.UP * 0.12)
	for i in 2: _link(root.get_meta("clavicles")[i], torso_top, rig["shoulders"][i])
	var hips: Node3D = root.get_meta("hips")
	hips.position = rig["pelvis"]; hips.rotation.y = facing + float(rig["hips_turn"])
	hips.scale = Vector3(float(profile["bulk"]), 1, 1)
	var gloves: Array = root.get_meta("gloves"); var arms: Array = root.get_meta("arms")
	var uppers: Array = root.get_meta("upper_arms"); var thighs: Array = root.get_meta("thighs")
	var legs: Array = root.get_meta("legs"); var boots: Array = root.get_meta("boots")
	var glove_color: Color = (root.get_meta("mat") as StandardMaterial3D).albedo_color.lightened(0.16)
	for index in 2:
		var shoulder: Vector3 = rig["shoulders"][index]; var elbow: Vector3 = rig["elbows"][index]
		root.get_meta("joints")[index * 3].position = shoulder
		root.get_meta("joints")[index * 3 + 1].position = elbow
		root.get_meta("joints")[index * 3 + 2].position = rig["knees"][index]
		var hand: Vector3 = rig["wrists"][index]
		gloves[index].position = hand
		gloves[index].quaternion = Quaternion(Vector3.FORWARD, (hand - elbow).normalized()) * Quaternion(Vector3.FORWARD, float(rig["twists"][index]))
		_link(uppers[index], shoulder, elbow); _link(arms[index], elbow, hand)
		for limb in [uppers[index], arms[index]]:
			limb.scale.x = float(profile["bulk"]); limb.scale.z = float(profile["bulk"])
		arms[index].rotate_object_local(Vector3.UP, float(rig["forearm_twists"][index]))
		var hip: Vector3 = rig["hip_joints"][index]
		var knee: Vector3 = rig["knees"][index]
		# The forefoot stays planted while the heel turns around it.
		boots[index].position = rig["ankles"][index] - Vector3.UP * 0.03
		boots[index].rotation.y = facing + float(rig["pivots"][index])
		_link(thighs[index], hip, knee); _link(legs[index], knee, boots[index].position + Vector3.UP * 0.03)
		for limb in [thighs[index], legs[index]]:
			limb.scale.x = float(profile["bulk"]); limb.scale.z = float(profile["bulk"])
	for child in root.get_children():
		if not child.has_meta("gear"): continue
		var kind := str(child.get_meta("kind"))
		if kind in ["gloves", "wraps"]:
			if not child.has_meta("hand_index"): child.set_meta("hand_index", 0 if child.position.x < 0 else 1)
			child.position = gloves[int(child.get_meta("hand_index"))].position
			if kind == "wraps": child.position.y -= 0.13
			else: glove_color = child.get_meta("color")
		elif kind == "mouthguard": child.position = head.position + forward * 0.17 - Vector3.UP * 0.08
	# Player silhouette stays translucent in neutral too: visibility cannot wait
	# until the opponent has already begun its cue. Active hands remain opaque.
	if who == "P":
		for material in [root.get_meta("mat"), head.mesh.material]:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = WINDUP_ALPHA
		var hands: StandardMaterial3D = root.get_meta("glove_mat")
		hands.albedo_color = glove_color
		hands.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hands.albedo_color.a = 1.0 if row != "" else WINDUP_ALPHA
	elif windup or sim.tick < int(root.get_meta("cue_until", 0)):
		var hands: StandardMaterial3D = root.get_meta("glove_mat")
		hands.albedo_color = Color(1.0, 0.75, 0.32).lightened(0.25 if sim.pi_cue() else 0.0)
	else:
		var hands: StandardMaterial3D = root.get_meta("glove_mat")
		hands.albedo_color = glove_color
	root.set_meta("pose_row", row); root.set_meta("windup", windup)
	root.set_meta("extension", extension)

func frame(camera: Camera3D, player: Node3D, opponent: Node3D, tick: int, boundaries: Array = []) -> void:
	var wanted := (player.position - opponent.position).normalized()
	if wanted.length_squared() < 0.1: wanted = Vector3(0, 0, 1)
	if orbit == Vector3.ZERO or tick < last_tick: orbit = wanted
	# Presentation cap; the art-bible's relative motion-salience acceptance is
	# still PAC-003. Sim ticks make this independent of render frame frequency.
	var elapsed := maxf(0, float(tick - last_tick) / Sim.TICK_HZ) if last_tick >= 0 else 0.0
	var angle := atan2(orbit.x, orbit.z)
	angle = rotate_toward(angle, atan2(wanted.x, wanted.z), deg_to_rad(70.0) * elapsed)
	orbit = Vector3(sin(angle), 0, cos(angle)); last_tick = tick
	var chase := maxf(CHASE, 2.8 - player.position.distance_to(opponent.position))
	camera.position = player.position + orbit * chase + Vector3.UP * (Sim.HEAD_H + HEAD_CLEARANCE)
	# At close contact a stale orbit can cross the opponent: use the current
	# chase direction for safety. Ordinary circling stays rate-limited.
	if camera.position.distance_to(opponent.position + Vector3.UP) < 1.9:
		orbit = wanted; camera.position = player.position + orbit * chase + Vector3.UP * (Sim.HEAD_H + HEAD_CLEARANCE)
	camera.look_at(opponent.position + Vector3.UP)
	# D2: clear a soft window through the player's silhouette over the enemy.
	# Arms remain full opacity when punching; they are the action being shown.
	var size := camera.get_viewport().get_visible_rect().size
	var top := camera.unproject_position(opponent.position + Vector3.UP * 1.95)
	var bottom := camera.unproject_position(opponent.position)
	var half_width := absf(bottom.y - top.y) * 0.36
	var window := Vector4((top.x - half_width) / size.x, top.y / size.y, (top.x + half_width) / size.x, bottom.y / size.y)
	var parts: Array = [player.get_meta("mesh"), player.get_meta("head")]
	parts.append_array(player.get_meta("legs"))
	parts.append_array(player.get_meta("joints")); parts.append_array(player.get_meta("clavicles"))
	parts.append_array(player.get_meta("thighs")); parts.append(player.get_meta("hips"))
	parts.append(player.get_meta("neck")); parts.append(player.get_meta("abdomen"))
	for child in player.get_children():
		if child.has_meta("kind") and str(child.get_meta("kind")) == "robe": parts.append(child)
	_clear_window(parts, window, WINDUP_ALPHA)
	# The fixed chase may sit outside the ropes at a corner. Clear only the
	# foreground boundaries over the opponent; keep the far side of the ring.
	# Per-fragment depth: a long rope's center can be behind the opponent while
	# its near end crosses the camera. Object-center classification is insufficient.
	_clear_window(boundaries, window, 1.0, true, opponent.position, camera.position - opponent.position)

func _clear_window(parts: Array, window: Vector4, alpha: float, foreground_only := false, origin := Vector3.ZERO, normal := Vector3.ZERO) -> void:
	for part in parts:
		if part.material_override == null:
			var shader := Shader.new(); shader.code = SILHOUETTE
			var material := ShaderMaterial.new(); material.shader = shader; part.material_override = material
		var tint: Color = part.mesh.material.albedo_color; tint.a = alpha
		part.material_override.set_shader_parameter("tint", tint)
		part.material_override.set_shader_parameter("clear_window", window)
		var source: StandardMaterial3D = part.mesh.material
		var aura := Vector3(source.emission.r, source.emission.g, source.emission.b) * source.emission_energy_multiplier if source.emission_enabled else Vector3.ZERO
		part.material_override.set_shader_parameter("aura", aura)
		part.material_override.set_shader_parameter("foreground_only", foreground_only)
		part.material_override.set_shader_parameter("clear_origin", origin)
		part.material_override.set_shader_parameter("clear_normal", normal)

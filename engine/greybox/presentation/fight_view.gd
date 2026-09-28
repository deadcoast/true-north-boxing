extends RefCounted
## Presentation only. Every pose reads the sim; no RNG, combat timers or rules are changed.
const Sim := preload("res://sim/core.gd")
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

func _sync_clock(sim) -> void:
	if clock_sim != sim or sim.tick < clock_tick:
		clock_sim = sim; frozen_ticks = 0; strikes.clear(); reactions.clear()
		motion_solvers.clear()
	clock_tick = sim.tick

func bump(root: Node3D, amount: float, sim) -> void:
	root.set_meta("bump", {"tick": sim.tick - frozen_ticks, "amount": amount, "sim": sim.get_instance_id()})

func before_step(sim) -> void:
	_sync_clock(sim)
	# tick counts input opportunities through hitstop; animation counts fight time.
	if sim.freeze_t > 0 or sim.mode != "FIGHT": frozen_ticks += 1

func capture(root: Node3D, fighter: Dictionary, other: Dictionary, sim, who: String) -> void:
	_sync_clock(sim)
	pose(root, fighter, other, sim, who)
	var snapshot := {}
	for part in root.get_children():
		if part is Node3D: snapshot[part.get_instance_id()] = part.transform
	root.set_meta("previous_pose", snapshot)

static func _part(parent: Node3D, mesh: PrimitiveMesh, material: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	mesh.material = material; node.mesh = mesh; node.position = at; parent.add_child(node)
	return node

static func make_fighter(parent: Node3D, color: Color, at: Vector3) -> Node3D:
	var root := Node3D.new(); parent.add_child(root); root.position = at
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.85
	var torso := CylinderMesh.new(); torso.top_radius = 0.29; torso.bottom_radius = 0.19; torso.height = 0.57; torso.radial_segments = 16
	var body := _part(root, torso, mat, Vector3(0, 1.04, 0)); body.scale.z = 0.70
	root.set_meta("mesh", body); root.set_meta("mat", mat)
	var shorts_mat := mat.duplicate() as StandardMaterial3D; shorts_mat.albedo_color = color.darkened(0.45)
	var hips := BoxMesh.new(); hips.size = Vector3(0.39, 0.23, 0.29)
	root.set_meta("hips", _part(root, hips, shorts_mat, Vector3(0, 0.77, 0)))
	var hmat := mat.duplicate() as StandardMaterial3D; hmat.albedo_color = color.lightened(0.35)
	var ball := SphereMesh.new(); ball.radius = 0.18; ball.height = 0.36
	root.set_meta("head", _part(root, ball, hmat, Vector3(0, Sim.HEAD_H, 0)))
	var neck := CylinderMesh.new(); neck.top_radius = 0.085; neck.bottom_radius = 0.10; neck.height = 1
	root.set_meta("neck", _part(root, neck, hmat, Vector3(0, 1.4, 0)))
	var gloves := []; var arms := []; var uppers := []; var legs := []; var thighs := []; var boots := []
	var glove_mat := mat.duplicate() as StandardMaterial3D; glove_mat.albedo_color = color.lightened(0.16)
	for side in [-1.0, 1.0]:
		var glove := SphereMesh.new(); glove.radius = 0.14; glove.height = 0.28
		gloves.append(_part(root, glove, glove_mat, Vector3(side * 0.36, 1.35, -0.25)))
		gloves[-1].scale = Vector3(0.85, 1, 1.15)
		var thumb := SphereMesh.new(); thumb.radius = 0.065; thumb.height = 0.16
		_part(gloves[-1], thumb, glove_mat, Vector3(-side * 0.10, -0.065, 0))
		var arm := CylinderMesh.new(); arm.top_radius = 0.075; arm.bottom_radius = 0.085; arm.height = 1.0
		var limb := _part(root, arm, glove_mat, Vector3(side * 0.32, 1.3, -0.125))
		var vector := Vector3(side * 0.08, 0.1, -0.25)
		limb.quaternion = Quaternion(Vector3.UP, vector.normalized()); limb.scale.y = vector.length()
		arms.append(limb)
		var upper := CylinderMesh.new(); upper.top_radius = 0.115; upper.bottom_radius = 0.078; upper.height = 1.0
		uppers.append(_part(root, upper, mat, Vector3(side * 0.27, 1.15, 0)))
		var leg := CylinderMesh.new(); leg.top_radius = 0.095; leg.bottom_radius = 0.065; leg.height = 1.0
		legs.append(_part(root, leg, mat, Vector3(side * 0.16, 0.30, 0)))
		var thigh := CylinderMesh.new(); thigh.top_radius = 0.12; thigh.bottom_radius = 0.09; thigh.height = 1.0
		thighs.append(_part(root, thigh, shorts_mat, Vector3(side * 0.16, 0.61, 0)))
		var boot := BoxMesh.new(); boot.size = Vector3(0.16, 0.13, 0.32)
		boots.append(_part(root, boot, shorts_mat, Vector3(side * 0.19, 0.065, 0)))
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
	if event.get("kind") == "boss_act" and event.get("verb") == "punch":
		var gap := int(clock_sim.btimer) if clock_sim != null and not clock_sim.bqueue.is_empty() else 48
		strikes["B"] = {"tick": tick - frozen_ticks, "row": event["row"], "body": event.get("body", false), "retract": clampi(gap / 2, 4, 24), "gap": gap}
	elif event.get("kind") == "punch":
		# The initiating sim step also consumes the first startup tick.
		var remaining := 24
		if clock_sim != null: remaining = maxi(4, int(clock_sim.P["busy_t"]) - int(clock_sim.P.get("pending", {}).get("t", 0)))
		strikes["P"] = {"tick": tick - frozen_ticks + maxi(0, int(event.get("startup", 0)) - 1), "row": event["row"], "body": "BODY" in event.get("mods", []), "retract": remaining}
	elif event.get("kind") == "hit":
		reactions[str(event["on"])] = {"tick": tick - frozen_ticks, "weight": clampf(float(event.get("dmg", 6)) / 30, 0.15, 1.0), "body": event.get("body", false)}
	elif event.get("kind") in ["feint", "drop", "matchup", "bout_end"]:
		strikes.clear()

static func tell_row(sim) -> String:
	var string: Dictionary = sim.pattern.get("strings", {}).get(sim.bstring, {})
	for action in string.get("actions", []):
		var verb := str(action).split("(")[0].split(" ")[0]
		if Sim.PUNCH_VERBS.has(verb): return str(Sim.PUNCH_VERBS[verb])
		if verb in ["BODY_SERIES", "WALK_STRING"]: return "L_HOOK"
		# The VM chooses MIXED_STRING's hand later. Do not resolve it early or
		# consume the sim RNG while rendering: show a two-handed coil instead.
		if verb == "MIXED_STRING": return ""
	return ""

func pose(root: Node3D, fighter: Dictionary, other: Dictionary, sim, who: String, alpha := 1.0) -> void:
	_sync_clock(sim)
	var fwd2: Vector2 = (other["pos"] - fighter["pos"]).normalized()
	if fwd2.length_squared() < 0.1: fwd2 = Vector2(0, -1)
	var forward := Vector3(fwd2.x, 0, fwd2.y)
	var right := Vector3(-fwd2.y, 0, fwd2.x)
	var head: MeshInstance3D = root.get_meta("head")
	var body: MeshInstance3D = root.get_meta("mesh")
	var geometric_head: Dictionary = sim._head_world(fighter, other)
	var displacement: Vector2 = geometric_head["p"] - fighter["pos"]
	var offset := Vector3(displacement.x, 0, displacement.y); var height: float = geometric_head["h"]
	var dodge := str(fighter.get("dodge", ""))
	head.position = offset + Vector3.UP * height
	body.scale = Vector3(1, lerpf(1, 0.92, Sim.dodge_weight(fighter)) if dodge in ["DUCK", "WEAVE"] else 1.0, 0.70)
	body.rotation.y = atan2(forward.x, forward.z)
	var row := ""; var load := 0.0; var extension := 0.0; var body_target := false
	var punch_progress := 0.0; var recovery := 0.0
	var strike: Dictionary = strikes.get(who, {})
	var strike_age: int = sim.tick - frozen_ticks - int(strike.get("tick", -1000))
	var retract_ticks := int(strike.get("retract", 24))
	var windup: bool = who == "B" and sim.bstate in ["TELL", "FAKE", "HOLD", "CAST", "SURGE"]
	if who == "B" and strike_age >= 0 and strike_age < retract_ticks:
		# Contact owns the hand before the next VM action winds up. Split a short
		# string gap into retraction and delivery, retaining both authored beats.
		row = str(strike["row"]); body_target = bool(strike["body"])
		punch_progress = 1.0; recovery = float(strike_age) / retract_ticks
		extension = 1.0 - BoxingMotion.ramp(recovery)
	elif windup:
		row = tell_row(sim)
		var tell: Dictionary = sim.pattern.get("strings", {}).get(sim.bstring, {}).get("tell", {})
		var ms := float(tell.get("ms", 700))
		var tier := 1.0 if ms >= 600 else (0.75 if ms >= 450 else 0.55)
		if sim.pi_cue(): tier *= 1.15
		load = tier * BoxingMotion.ramp(float(sim.tick - sim.tell_start_tick) / maxf(1, Sim.ms(ms * 0.4)))
		if row != "" and sim.bstate == "TELL":
			var swing := Sim.ms(float(sim.T["punch_matrix"][row]["startup_ms"]))
			punch_progress = clampf(1.0 - float(sim.btimer) / swing, 0, 1)
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
		var progress := 1.0 - float(pending["t"]) / maxf(1, float(pending["startup"]))
		punch_progress = progress
		load = sin(progress * PI) * (1.2 if "HAYMAKER" in pending["mods"] else 0.5)
		extension = pow(progress, 3)
	elif strikes.has(who):
		if who == "P" and strike_age >= 0 and strike_age < retract_ticks:
			row = str(strike["row"]); body_target = bool(strike["body"])
			punch_progress = 1.0; recovery = clampf(float(strike_age - 3) / maxi(1, retract_ticks - 3), 0, 1)
			extension = 1.0 - BoxingMotion.ramp(recovery)
	var reaction := 0.0
	if reactions.has(who):
		var hit: Dictionary = reactions[who]
		var age := float(sim.tick - frozen_ticks - int(hit["tick"]))
		reaction = float(hit["weight"]) * maxf(0, 1.0 - age / 28.0)
	var reach := 1.4
	for family in Sim.GEO:
		if row.ends_with(family):
			reach = float(Sim.GEO[family]["reach"]) * float(fighter.get("pkg", {}).get("reach_mult", 1.0))
			if family == "STRAIGHT": reach *= float(fighter.get("pkg", {}).get("straight_reach_mult", 1.0))
	reach = minf(reach, maxf(0.3, (other["pos"] as Vector2).distance_to(fighter["pos"]) - 0.18))
	if not motion_solvers.has(who): motion_solvers[who] = BoxingMotion.new()
	var rig: Dictionary = motion_solvers[who].sample(fighter, other, sim.tick - frozen_ticks,
		{"row": row, "progress": punch_progress, "recovery": recovery, "body": body_target, "reach": reach, "head_height": Sim.HEAD_H, "preload": load if windup else 0.0}, offset + Vector3.UP * (height - Sim.HEAD_H))
	root.set_meta("kinematics", rig)
	var facing := atan2(forward.x, forward.z)
	body.rotation = Vector3(0, facing + float(rig["chest_turn"]), reaction * 0.10)
	body.position = ((rig["chest"] as Vector3) + rig["pelvis"]) * 0.5 - forward * reaction * 0.12
	_link(root.get_meta("neck"), rig["chest"] + Vector3.UP * 0.10, head.position - Vector3.UP * 0.12)
	var impulse: Dictionary = root.get_meta("bump", {})
	if impulse.get("sim", -1) == sim.get_instance_id():
		var age: int = sim.tick - frozen_ticks - int(impulse["tick"])
		if age >= 0: body.position.y -= float(impulse["amount"]) * maxf(0, 1.0 - float(age) / 14)
	var hips: Node3D = root.get_meta("hips")
	hips.position = rig["pelvis"]; hips.rotation.y = facing + float(rig["hips_turn"])
	var gloves: Array = root.get_meta("gloves"); var arms: Array = root.get_meta("arms")
	var uppers: Array = root.get_meta("upper_arms"); var thighs: Array = root.get_meta("thighs")
	var legs: Array = root.get_meta("legs"); var boots: Array = root.get_meta("boots")
	var glove_color: Color = (root.get_meta("mat") as StandardMaterial3D).albedo_color.lightened(0.16)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var shoulder: Vector3 = rig["shoulders"][index]; var elbow: Vector3 = rig["elbows"][index]
		var hand: Vector3 = rig["wrists"][index]
		gloves[index].position = hand
		gloves[index].quaternion = Quaternion(Vector3.FORWARD, (hand - elbow).normalized()) * Quaternion(Vector3.FORWARD, float(rig["twists"][index]))
		_link(uppers[index], shoulder, elbow); _link(arms[index], elbow, hand)
		arms[index].rotate_object_local(Vector3.UP, float(rig["forearm_twists"][index]))
		var hip: Vector3 = rig["pelvis"] + (right * side * 0.14).rotated(Vector3.UP, float(rig["hips_turn"]))
		var knee: Vector3 = rig["knees"][index]; var sole: Vector3 = rig["feet"][index]
		# The forefoot stays planted while the heel turns around it.
		var foot_forward := forward.rotated(Vector3.UP, float(rig["pivots"][index]))
		boots[index].position = sole + Vector3.UP * 0.065 - foot_forward * 0.08
		boots[index].rotation.y = facing + float(rig["pivots"][index])
		_link(thighs[index], hip, knee); _link(legs[index], knee, boots[index].position + Vector3.UP * 0.03)
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
	# Interpolate the last two fixed-tick poses, not the last two render frames.
	# The result and input timing stay independent of 30/60/144 Hz rendering.
	var snapshot: Dictionary = root.get_meta("previous_pose", {})
	if alpha < 1.0:
		for part in root.get_children():
			if part is Node3D and snapshot.has(part.get_instance_id()):
				part.transform = (snapshot[part.get_instance_id()] as Transform3D).interpolate_with(part.transform, alpha)

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
	camera.position = player.position + orbit * CHASE + Vector3.UP * (Sim.HEAD_H + HEAD_CLEARANCE)
	# At close contact a stale orbit can cross the opponent: use the current
	# chase direction for safety. Ordinary circling stays rate-limited.
	if camera.position.distance_to(opponent.position + Vector3.UP) < 1.9:
		orbit = wanted; camera.position = player.position + orbit * CHASE + Vector3.UP * (Sim.HEAD_H + HEAD_CLEARANCE)
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
	parts.append_array(player.get_meta("thighs")); parts.append(player.get_meta("hips"))
	parts.append(player.get_meta("neck"))
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

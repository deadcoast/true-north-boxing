extends RefCounted
## Presentation only. Every pose reads the sim; no RNG, combat timers or rules are changed.
const Sim := preload("res://sim/core.gd")
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

static func _part(parent: Node3D, mesh: PrimitiveMesh, material: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	mesh.material = material; node.mesh = mesh; node.position = at; parent.add_child(node)
	return node

static func make_fighter(parent: Node3D, color: Color, at: Vector3) -> Node3D:
	var root := Node3D.new(); parent.add_child(root); root.position = at
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.85
	var torso := CapsuleMesh.new(); torso.radius = 0.29; torso.height = 0.86
	var body := _part(root, torso, mat, Vector3(0, 0.9, 0))
	root.set_meta("mesh", body); root.set_meta("mat", mat)
	var hmat := mat.duplicate() as StandardMaterial3D; hmat.albedo_color = color.lightened(0.35)
	var ball := SphereMesh.new(); ball.radius = 0.18; ball.height = 0.36
	root.set_meta("head", _part(root, ball, hmat, Vector3(0, Sim.HEAD_H, 0)))
	var gloves := []; var arms := []; var legs := []
	var glove_mat := mat.duplicate() as StandardMaterial3D; glove_mat.albedo_color = color.lightened(0.16)
	for side in [-1.0, 1.0]:
		var glove := SphereMesh.new(); glove.radius = 0.14; glove.height = 0.28
		gloves.append(_part(root, glove, glove_mat, Vector3(side * 0.36, 1.35, -0.25)))
		var arm := CylinderMesh.new(); arm.top_radius = 0.075; arm.bottom_radius = 0.085; arm.height = 1.0
		var limb := _part(root, arm, glove_mat, Vector3(side * 0.32, 1.3, -0.125))
		var vector := Vector3(side * 0.08, 0.1, -0.25)
		limb.quaternion = Quaternion(Vector3.UP, vector.normalized()); limb.scale.y = vector.length()
		arms.append(limb)
		var leg := CapsuleMesh.new(); leg.radius = 0.105; leg.height = 0.7
		legs.append(_part(root, leg, mat, Vector3(side * 0.16, 0.35, 0)))
	root.set_meta("gloves", gloves); root.set_meta("arms", arms); root.set_meta("legs", legs)
	root.set_meta("glove_mat", glove_mat)
	return root

func observe(event: Dictionary, tick: int) -> void:
	# Boss punches resolve on their VM tick. Hold the contact pose through hitstop,
	# then retract on sim time. Player contact uses the same path after startup.
	if event.get("kind") == "boss_act" and event.get("verb") == "punch":
		strikes["B"] = {"tick": tick, "row": event["row"], "body": event.get("body", false)}
	elif event.get("kind") == "punch":
		strikes["P"] = {"tick": tick + int(event.get("startup", 0)), "row": event["row"], "body": "BODY" in event.get("mods", [])}
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

func pose(root: Node3D, fighter: Dictionary, other: Dictionary, sim, who: String) -> void:
	var fwd2: Vector2 = (other["pos"] - fighter["pos"]).normalized()
	if fwd2.length_squared() < 0.1: fwd2 = Vector2(0, -1)
	var forward := Vector3(fwd2.x, 0, fwd2.y)
	var right := Vector3(-fwd2.y, 0, fwd2.x)
	var head: MeshInstance3D = root.get_meta("head")
	var body: MeshInstance3D = root.get_meta("mesh")
	var offset := Vector3.ZERO; var height := Sim.HEAD_H
	var dodge := str(fighter.get("dodge", ""))
	if Sim.DODGE.has(dodge):
		var d: Dictionary = Sim.DODGE[dodge]
		# Match the simulation's lateral convention exactly.
		offset = -right * float(d["lat"]) * float(fighter["dodge_dir"]) - forward * float(d["back"])
		height = float(d["h"])
	head.position = offset + Vector3.UP * height
	body.scale = Vector3(1, 0.75 if dodge in ["DUCK", "WEAVE"] else 1.0, 1)
	body.rotation.y = atan2(forward.x, forward.z)
	var row := ""; var load := 0.0; var extension := 0.0; var body_target := false
	var windup: bool = who == "B" and sim.bstate in ["TELL", "FAKE", "HOLD", "CAST", "SURGE"]
	if windup:
		row = tell_row(sim)
		var tell: Dictionary = sim.pattern.get("strings", {}).get(sim.bstring, {}).get("tell", {})
		var ms := float(tell.get("ms", 700))
		var tier := 1.0 if ms >= 600 else (0.75 if ms >= 450 else 0.55)
		if sim.pi_cue(): tier *= 1.15
		load = tier * (0.65 + 0.35 * clampf(float(sim.tick - sim.tell_start_tick) / maxf(1, Sim.ms(ms)), 0, 1))
	elif who == "P" and not fighter.get("pending", {}).is_empty():
		var pending: Dictionary = fighter["pending"]
		row = str(pending["row"]); body_target = "BODY" in pending["mods"]
		var progress := 1.0 - float(pending["t"]) / maxf(1, float(pending["startup"]))
		load = sin(progress * PI) * (1.2 if "HAYMAKER" in pending["mods"] else 0.5)
		extension = pow(progress, 3)
	elif strikes.has(who):
		var strike: Dictionary = strikes[who]; var age: int = sim.tick - int(strike["tick"])
		if age >= 0 and age < 24:
			row = str(strike["row"]); body_target = bool(strike["body"])
			extension = 1.0 - clampf(float(age - 6) / 18.0, 0, 1)
	var gloves: Array = root.get_meta("gloves"); var arms: Array = root.get_meta("arms")
	var glove_color: Color = (root.get_meta("mat") as StandardMaterial3D).albedo_color.lightened(0.16)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var shoulder := right * side * 0.28 + Vector3.UP * (1.25 + (height - Sim.HEAD_H) * 0.7) + offset * 0.6
		var hand := shoulder + right * side * 0.08 + forward * 0.22 + Vector3.UP * 0.12
		if fighter.get("blocking", false) or int(fighter.get("guard_t", 0)) > 0:
			hand = head.position + right * side * 0.2 + forward * 0.19 - Vector3.UP * 0.05
		var active: bool = row.begins_with("L_") if index == 0 else row.begins_with("R_")
		active = active or (windup and row == "")
		if active:
			hand += right * side * load * 0.25 - forward * load * 0.26
			if "UPPER" in row or "HOOKERCUT" in row: hand.y -= load * 0.3
			elif "FLARED" in row: hand.y += load * 0.15
			var target := forward * minf(1.1, (other["pos"] as Vector2).distance_to(fighter["pos"])) + Vector3.UP * (1.0 if body_target else Sim.HEAD_H)
			if "HOOK" in row: target += right * side * sin(extension * PI) * 0.45
			hand = hand.lerp(target, extension)
		gloves[index].position = hand
		var vector: Vector3 = hand - shoulder
		arms[index].position = (hand + shoulder) * 0.5
		arms[index].quaternion = Quaternion(Vector3.UP, vector.normalized())
		arms[index].scale = Vector3(1, maxf(0.01, vector.length()), 1)
	var legs: Array = root.get_meta("legs")
	for index in 2:
		legs[index].position = right * (-0.17 if index == 0 else 0.17) + forward * (-0.09 if index == 0 else 0.09) + Vector3.UP * 0.35
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

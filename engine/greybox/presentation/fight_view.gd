extends RefCounted
## Presentation only. Every pose reads the sim; no RNG, combat timers or rules are changed.
const Sim := preload("res://sim/core.gd")
const Space := preload("res://presentation/rig_space.gd")
const BoxingMotion := preload("res://presentation/boxing_motion.gd")
const FighterVisuals := preload("res://presentation/fighter_visuals.gd")
const CHASE := 1.8
const HEAD_CLEARANCE := 1.04
const FOV := 55.0
const WINDUP_ALPHA := 0.4
const PLAYER_DEPTH := """shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;
void fragment() { ALBEDO = vec3(0.0); ALPHA = 0.0; }
"""
const SILHOUETTE := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 tint : source_color;
uniform vec4 clear_window;
uniform float window_alpha = 0.08;
uniform vec3 aura;
uniform bool foreground_only = false;
uniform vec3 clear_origin;
uniform vec3 clear_normal;
uniform bool opponent_mask = false;
uniform vec3 opponent_min;
uniform vec3 opponent_max;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 edge = min(SCREEN_UV - clear_window.xy, clear_window.zw - SCREEN_UV);
    float inside = smoothstep(0.0, 0.025, min(edge.x, edge.y));
    if (opponent_mask) {
        float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
        #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
        vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
        #else
        vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
        #endif
        vec4 scene = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
        vec3 opaque = scene.xyz / scene.w;
        // Depth is copied after opaque geometry, before the transparent player.
        // Reveal the actual opponent surface, not a ghost inside a rectangle.
        inside = all(greaterThanEqual(opaque, opponent_min)) && all(lessThanEqual(opaque, opponent_max)) ? 1.0 : 0.0;
    }
    if (foreground_only) { inside *= step(0.0, dot(world_position - clear_origin, clear_normal)); }
    ALBEDO = tint.rgb;
    EMISSION = aura;
    ALPHA = mix(tint.a, window_alpha, inside);
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
var preparations := {}
var player_depth: ShaderMaterial
# Retained for older diagnostic drivers; gameplay always uses the chase rig.
var observer_view := true
var inspection_view := false
var inspection_label: Label

func _sync_clock(sim) -> void:
	if clock_sim != sim or sim.tick < clock_tick:
		clock_sim = sim; frozen_ticks = 0; strikes.clear(); reactions.clear()
		motion_solvers.clear()
		attacks.clear(); tell_clock.clear(); offers.clear(); travels.clear(); before_positions.clear(); preparations.clear(); hold_ticks = 1
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
	var direction := vector.normalized()
	var axis := Vector3.UP.cross(direction)
	# The from/to quaternion snaps very small tilts to identity. Preserve those
	# tilts so a connected mesh continues to meet its actual joint endpoints.
	mesh.quaternion = Quaternion(axis.normalized(), atan2(axis.length(), direction.y)) if axis.length_squared() > 0.000000000001 else (Quaternion.IDENTITY if direction.y >= 0 else Quaternion(Vector3.RIGHT, PI))
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
		preparations.erase("B")
		var gap := int(clock_sim.btimer) if clock_sim != null and not clock_sim.bqueue.is_empty() else 48
		strikes["B"] = {"tick": tick - frozen_ticks, "row": event["row"], "body": event.get("body", false), "retract": int(event.get("recovery", clampi(gap / 2, 4, 24))), "gap": gap}
	elif event.get("kind") == "punch":
		# The initiating sim step also consumes the first startup tick.
		var remaining := 24
		if clock_sim != null: remaining = maxi(4, int(clock_sim.P["busy_t"]) - int(clock_sim.P.get("pending", {}).get("t", 0)))
		strikes["P"] = {"tick": tick - frozen_ticks + maxi(0, int(event.get("startup", 0)) - 1), "row": event["row"], "body": "BODY" in event.get("mods", []), "mods": event.get("mods", []).duplicate(), "range_bonus": float(clock_sim.P.get("pending", {}).get("range_bonus", 0)), "retract": remaining}
		strikes["P"]["guard_start"] = event.get("guard_start", 1.0)
	elif event.get("kind") == "hit":
		reactions[str(event["on"])] = {"tick": tick - frozen_ticks, "weight": clampf(float(event.get("dmg", 6)) / 30, 0.15, 1.0), "body": event.get("body", false), "displacement": event.get("displacement", Vector2.ZERO), "sim_tick": tick}
	elif event.get("kind") == "feint":
		_cancel("P", tick - frozen_ticks, maxi(1, int(clock_sim.P["busy_t"])))
	elif event.get("kind") == "interrupt":
		_cancel("B", tick - frozen_ticks, mini(24, maxi(1, int(event.get("stagger", 24)))))
		preparations.erase("B")
	elif event.get("kind") == "tell":
		tell_clock = {"at": tick - frozen_ticks, "ticks": event.get("ticks", 1), "string": event.get("string", "")}
	elif event.get("kind") == "feint_b" and event.get("mode") == "delay":
		hold_ticks = maxi(1, int(clock_sim.btimer))
	elif event.get("kind") == "recover" and float(attacks.get("B", {}).get("preload", 0)) > 0:
		# A fake tell has no punch/contact event. Release its coil instead of
		# dropping the loaded torso to neutral in a single frame.
		_cancel("B", tick - frozen_ticks, mini(24, maxi(1, int(clock_sim.btimer))))
		preparations.erase("B")
	elif event.get("kind") in ["drop", "matchup", "bout_end"]:
		strikes.clear(); attacks.clear(); tell_clock.clear(); preparations.clear()

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
		if not from.has(channel): continue # Older saved rigs predate articulated heads.
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
	var fighter: Dictionary = sim.P if who == "P" else sim.B
	if fighter.has("boxing"): return Vector2.ZERO
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
	# Both boxers in a native body-control exchange use continuous delivery;
	# the opponent's older action VM cannot reintroduce a hit/miss pose switch.
	fighter["continuous_delivery"] = sim.P.has("body_control") or sim.B.has("body_control")
	var physical_fighter := fighter.duplicate(); var physical_other := other.duplicate()
	# Hit events carry the post-resolution shove. Eligibility on the contact
	# frame belongs to the pre-shove positions, as does the frozen impact pose.
	for pair in [[who, physical_fighter], ["B" if who == "P" else "P", physical_other]]:
		var hit: Dictionary = reactions.get(pair[0], {})
		if int(hit.get("tick", -1)) == sim.tick - frozen_ticks: pair[1]["pos"] -= hit.get("displacement", Vector2.ZERO)
	fighter["motion_identity"] = sim.pname() if who == "P" else sim.boss_label if not sim.bout.is_empty() or not sim.bgeneric.is_empty() else sim.boss_name
	FighterVisuals.apply(root, str(fighter["motion_identity"]))
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
	elif not fighter.get("pending", {}).is_empty():
		var pending: Dictionary = fighter["pending"]
		row = str(pending["row"]); body_target = "BODY" in pending["mods"]
		mods = pending["mods"]
		var progress := 1.0 - float(pending["t"]) / maxf(1, float(pending["startup"]))
		punch_progress = lerpf(0.22, 1.0, progress) if who == "B" else progress
		load = sin(punch_progress * PI) * (1.2 if "HAYMAKER" in pending["mods"] else 0.5)
		if who == "B": load = float(preparations.get("B", {}).get("load", 0.0)) * (1.0 - BoxingMotion.ramp(progress))
		extension = pow(punch_progress, 3)
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
			if sim.P.has("body_control"): punch_progress = minf(punch_progress, 0.22)
			redirect_weight = BoxingMotion.ramp(punch_progress)
			extension = pow(punch_progress, 3)
		if who == "B" and sim.P.has("body_control") and row != "":
			preparations["B"] = {"row":row, "body":body_target, "load":load, "progress":punch_progress}
	elif who == "B" and sim.P.has("body_control") and sim.bstate == "ACTING" and preparations.has("B"):
		var prepared: Dictionary = preparations["B"]
		row = str(prepared["row"]); body_target = bool(prepared["body"])
		load = float(prepared["load"]); punch_progress = float(prepared["progress"])
		extension = pow(punch_progress, 3)
	elif who == "B" and not sim.P.has("body_control") and sim.bstate == "ACTING" and not sim.bqueue.is_empty() and sim.bqueue[0].get("kind") == "punch" and sim.btimer <= 18:
		row = str(sim.bqueue[0]["row"]); body_target = bool(sim.bqueue[0].get("body", false))
		var delivery := mini(18, maxi(1, int(strike.get("gap", 36)) - retract_ticks))
		var progress := clampf(1.0 - float(sim.btimer) / delivery, 0, 1)
		punch_progress = progress
		load = sin(progress * PI) * 0.65; extension = pow(progress, 3)
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
	attack["guard_start"] = fighter.get("pending", {}).get("guard_start", strike.get("guard_start", 1.0))
	if who == "B" and preparations.has("B"): attack["preload"] = load
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
	var canonical: Dictionary = physical_fighter.get("boxing", {})
	var physical_pose := canonical.has("rig")
	if physical_pose:
		# Native hands, targets and defensive surfaces share the saved fixed-tick
		# pose. Presentation must never retarget a committed hand or apply a
		# separate reaction offset to a colliding limb.
		rig = canonical["rig"].duplicate(true)
		attack = canonical.get("presentation",{}).duplicate(true)
		row = str(attack.get("row",""))
		punch_progress = float(attack.get("progress",0)); recovery = float(attack.get("recovery",0))
		extension = pow(punch_progress,3) * (1.0 - BoxingMotion.ramp(recovery))
		attacks[who] = attack
		target = attack.get("target",Vector3.ZERO)
	root.set_meta("kinematics", rig.duplicate(true) if physical_pose else BoxingMotion.constrain(rig.duplicate(true)))
	if alpha < 1.0 and root.get_meta("previous_sim", -1) == sim.get_instance_id():
		rig = _blend_rig(root.get_meta("previous_rig"), rig, alpha)
	if not physical_pose or alpha < 1.0: rig = BoxingMotion.constrain(rig)
	root.set_meta("render_kinematics", rig); root.set_meta("contact_region", region); root.set_meta("contact_target", target)
	head.position = rig["head"]
	forward = (rig["forward"] as Vector3).normalized()
	var facing := atan2(forward.x, forward.z)
	# Faces look down -Z; the boxing torso and boots face +Z. Keep the eyes on
	# the opponent through slips and weaving without adding a second pose clock.
	var head_frame := Basis.looking_at(rig.get("head_forward",forward),rig.get("head_up",Vector3.UP),true)
	head.basis = head_frame * (Basis(Vector3.UP,PI) if root.get_meta("cast_key", "") != "" else Basis.IDENTITY)
	var collar: Vector3 = (rig["shoulders"][0] + rig["shoulders"][1]) * 0.5
	# One connected trunk spans the hips and shoulder girdle. Its collision
	# surface uses these same anchors; do not hold a second torso under the head
	# and stretch the shirt across to a separately moving chest.
	var torso_top := collar
	var torso_bottom: Vector3 = rig["pelvis"] + Vector3.UP * 0.04
	_link(root.get_meta("abdomen"), rig["pelvis"], torso_bottom)
	_link(body, torso_bottom, torso_top)
	body.scale.y /= 0.57
	body.rotate_object_local(Vector3.UP, facing + float(rig["chest_turn"]))
	FighterVisuals.torso_pose(root, Vector3.ZERO, Vector3.ZERO)
	_link(root.get_meta("neck"), collar, head.position - head_frame.y * 0.12)
	for i in 2: _link(root.get_meta("clavicles")[i], collar, rig["shoulders"][i])
	var hips: Node3D = root.get_meta("hips")
	hips.position = rig["pelvis"]; hips.rotation.y = facing + float(rig["hips_turn"])
	hips.scale = Vector3(float(profile["bulk"]), 1, 1)
	var gloves: Array = root.get_meta("gloves"); var arms: Array = root.get_meta("arms")
	var uppers: Array = root.get_meta("upper_arms"); var thighs: Array = root.get_meta("thighs")
	var legs: Array = root.get_meta("legs"); var boots: Array = root.get_meta("boots")
	var glove_color: Color = root.get_meta("cast_glove_color") if root.get_meta("cast_key", "") != "" else (root.get_meta("mat") as StandardMaterial3D).albedo_color.lightened(0.16)
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
		elif kind == "mouthguard": child.position = head.position + head_frame*Vector3(0,-0.08,0.17); child.basis=head_frame
	# Source materials stay opaque. The camera applies state-aware clearance
	# per anatomical group, so shared skin cannot fade the working arm.
	if who == "P":
		for material in [root.get_meta("mat"), head.mesh.material]:
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			material.albedo_color.a = 1.0
		var hands: StandardMaterial3D = root.get_meta("glove_mat")
		hands.albedo_color = glove_color
		hands.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		hands.albedo_color.a = 1.0
	elif windup or sim.tick < int(root.get_meta("cue_until", 0)):
		var hands: StandardMaterial3D = root.get_meta("glove_mat")
		hands.albedo_color = Color(1.0, 0.75, 0.32).lightened(0.25 if sim.pi_cue() else 0.0)
	else:
		var hands: StandardMaterial3D = root.get_meta("glove_mat")
		hands.albedo_color = glove_color
	root.set_meta("pose_row", row); root.set_meta("windup", windup)
	root.set_meta("extension", extension)

func frame(camera: Camera3D, player: Node3D, opponent: Node3D, tick: int, boundaries: Array = []) -> void:
	player.get_meta("head").visible = true
	player.get_meta("neck").visible = true
	if is_instance_valid(inspection_label): inspection_label.visible = inspection_view
	if inspection_view:
		_inspection_frame(camera, player, opponent, tick, boundaries)
		return
	var tuning: Dictionary = clock_sim.T.get("camera", {}) if clock_sim != null else {}
	var chase_base := float(tuning.get("chase_behind_m", CHASE))
	var clearance := float(tuning.get("above_head_m", HEAD_CLEARANCE))
	var windup_alpha := float(tuning.get("windup_alpha_pct", WINDUP_ALPHA * 100.0)) / 100.0
	camera.fov = float(tuning.get("fov_deg", FOV))
	camera.near = 0.05
	var wanted := (player.position - opponent.position).normalized()
	if wanted.length_squared() < 0.1: wanted = Vector3(0, 0, 1)
	if orbit == Vector3.ZERO or tick < last_tick: orbit = wanted
	# Presentation cap; the art-bible's relative motion-salience acceptance is
	# still PAC-003. Sim ticks make this independent of render frame frequency.
	var elapsed := maxf(0, float(tick - last_tick) / Sim.TICK_HZ) if last_tick >= 0 else 0.0
	var angle := atan2(orbit.x, orbit.z)
	angle = rotate_toward(angle, atan2(wanted.x, wanted.z), deg_to_rad(70.0) * elapsed)
	orbit = Vector3(sin(angle), 0, cos(angle)); last_tick = tick
	# first.md permits off-center staging: stay behind/above the same physical
	# fighter, with the opponent facing the screen. Never move or scale a body
	# to make its image fit. The original 0.6m elevation put the player's head
	# over the opponent's head instead of the documented small lower silhouette.
	var shoulder := Vector3(orbit.z, 0, -orbit.x) * float(tuning.get("shoulder_offset_m", 0.9))
	camera.position = player.position + orbit * chase_base + shoulder + Vector3.UP * (Sim.HEAD_H + clearance)
	var look := opponent.position - camera.position; look.y = 0
	look = look.normalized()
	var pitch := deg_to_rad(float(tuning.get("pitch_deg", 12.0)))
	camera.look_at(camera.position + look * cos(pitch) - Vector3.UP * sin(pitch))
	# Keep the entire opponent in frame at inside range. Fit a standing envelope,
	# not the animated head, so ducks/pulls remain visible and do not pump zoom.
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var tangent := tan(deg_to_rad(camera.fov * 0.5))
	for height in [-0.08, 1.95]:
		for side in [-0.60, 0.60]:
			for reach in [-0.40, 0.40]:
				var point := camera.to_local(opponent.position + Vector3.UP * height + camera.global_basis.x * side + orbit * reach)
				var depth := maxf(0.1, -point.z)
				tangent = maxf(tangent, maxf(absf(point.y), absf(point.x) / aspect) / (depth * 0.96))
	camera.fov = rad_to_deg(2.0 * atan(tangent))
	# D2: clear a soft window through the player's silhouette over the enemy.
	# Arms remain full opacity when punching; they are the action being shown.
	var size := camera.get_viewport().get_visible_rect().size
	var top := camera.unproject_position(opponent.position + Vector3.UP * 1.95)
	var bottom := camera.unproject_position(opponent.position)
	var half_width := absf(bottom.y - top.y) * 0.36
	var window := Vector4((top.x - half_width) / size.x, top.y / size.y, (top.x + half_width) / size.x, bottom.y / size.y)
	_player_visibility(player, window, windup_alpha, bool(opponent.get_meta("windup", false)), _visible_bounds(opponent))
	# The fixed chase may sit outside the ropes at a corner. Clear only the
	# foreground boundaries over the opponent; keep the far side of the ring.
	# Per-fragment depth: a long rope's center can be behind the opponent while
	# its near end crosses the camera. Object-center classification is insufficient.
	_clear_window(boundaries, window, 1.0, true, opponent.position, camera.position - opponent.position)

func _inspection_frame(camera: Camera3D, player: Node3D, opponent: Node3D, tick: int, boundaries: Array) -> void:
	if not is_instance_valid(inspection_label):
		inspection_label = Label.new(); camera.get_viewport().add_child(inspection_label)
		inspection_label.text = "DIAGNOSTIC SIDE VIEW - NOT THE GAMEPLAY CAMERA"
		inspection_label.position = Vector2(24, 148)
		inspection_label.add_theme_color_override("font_color", Color(1, 0.75, 0.3))
		inspection_label.z_index = 100
	inspection_label.visible = true
	var forward := (opponent.position - player.position).normalized()
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	var center := (player.position + opponent.position) * 0.5
	camera.position = center + side * 3.4 - forward * 0.9 + Vector3.UP * 1.8
	camera.near = 0.035; camera.fov = 62.0
	camera.look_at(center + Vector3.UP * 0.90); last_tick = tick
	for actor in [player, opponent]:
		for part in actor.get_children() + actor.get_meta("cast_parts", []):
			if part is MeshInstance3D: part.material_override = null
	# Foreground ropes are cleared, never the boxer being inspected.
	_clear_window(boundaries, Vector4(0, 0, 1, 1), 1.0, true, center, camera.position - center)

func _player_visibility(player: Node3D, window: Vector4, windup_alpha: float, windup: bool, opponent_bounds: AABB) -> void:
	var groups := {"body": [], "head": [], "left": [], "right": []}
	for field in FighterVisuals.ANCHORS:
		var value = player.get_meta(field)
		var anchors: Array = value if value is Array else [value]
		for i in anchors.size():
			var group := _visibility_group(field, i)
			if anchors[i].layers != 0: groups[group].append(anchors[i])
			for child in anchors[i].get_children():
				if child is MeshInstance3D and child.layers != 0: groups[group].append(child)
	for child in player.get_children():
		if child.has_meta("kind"):
			var kind := str(child.get_meta("kind"))
			if kind == "robe": groups["body"].append(child)
			elif kind in ["gloves", "wraps"]: groups["left" if int(child.get_meta("hand_index", 0)) == 0 else "right"].append(child)
	var row := str(player.get_meta("pose_row", ""))
	for group in groups:
		var working: bool = (group == "left" and row.begins_with("L_")) or (group == "right" and row.begins_with("R_"))
		var alpha := windup_alpha if windup and group != "head" and not working else 1.0
		# Keep the player legible outside the opponent: below shoulders is 40%
		# during tells, head stays solid, and the striking chain stays opaque.
		# The actual opponent pixels take precedence over the idle silhouette.
		_clear_window(groups[group], window, alpha, false, Vector3.ZERO, Vector3.ZERO, 1.0 if working else 0.0, true, opponent_bounds)

func _visible_bounds(actor: Node3D) -> AABB:
	var bounds := AABB(); var started := false
	for part in actor.get_children() + actor.get_meta("cast_parts", []):
		if not part is MeshInstance3D or part.layers == 0 or not part.is_visible_in_tree(): continue
		var box: AABB = part.global_transform * _skin_bounds(part)
		bounds = bounds.merge(box) if started else box; started = true
	bounds = bounds.grow(0.01)
	# The skin AABB can extend a few millimetres below the canvas. Do not
	# classify the opaque ring floor as the opponent and cut away our legs.
	var top := bounds.end
	bounds.position.y = maxf(bounds.position.y, actor.global_position.y + 0.015)
	bounds.size = top - bounds.position
	return bounds

static func _skin_bounds(part: MeshInstance3D) -> AABB:
	# ArrayMesh's culling box includes the full inactive blend shapes. The
	# old torso morphs extend one metre and must not enlarge a readability mask.
	if part.get_blend_shape_count() == 0: return part.get_aabb()
	var weights := PackedFloat32Array()
	for i in part.get_blend_shape_count(): weights.append(part.get_blend_shape_value(i))
	var cached: Dictionary = part.get_meta("read_bounds", {})
	if cached.get("mesh") == part.mesh and cached.get("weights") == weights: return cached["box"]
	var base: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vertices := base.duplicate()
	var morphs: Array = part.mesh.surface_get_blend_shape_arrays(0)
	for i in weights.size():
		if is_zero_approx(weights[i]): continue
		var morph: PackedVector3Array = morphs[i][Mesh.ARRAY_VERTEX]
		for j in vertices.size():
			vertices[j] += (morph[j] - base[j] if part.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else morph[j]) * weights[i]
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: bounds = bounds.expand(vertex)
	part.set_meta("read_bounds", {"mesh":part.mesh,"weights":weights,"box":bounds})
	return bounds

static func _visibility_group(field: String, index: int) -> String:
	if field == "head": return "head"
	if field in ["gloves", "arms", "upper_arms", "clavicles"]: return "left" if index == 0 else "right"
	if field == "joints" and index % 3 < 2: return "left" if index < 3 else "right"
	return "body"

func _clear_window(parts: Array, window: Vector4, alpha: float, foreground_only := false, origin := Vector3.ZERO, normal := Vector3.ZERO, window_alpha := 0.08, self_depth := false, opponent_bounds := AABB()) -> void:
	# Every surface with the same source material receives the same window.
	# Share its shader and update uniforms once, rather than repeating six
	# render-server writes for every eyelid, seam and limb on every frame.
	var materials := {}; var used := {}
	for part in parts:
		var source: StandardMaterial3D = part.get_surface_override_material(0) if part.get_surface_override_material(0) != null else part.mesh.surface_get_material(0)
		if materials.has(source):
			if part.material_override != materials[source]: part.material_override = materials[source]
			continue
		if not part.material_override is ShaderMaterial or used.has(part.material_override):
			var shader := Shader.new(); shader.code = SILHOUETTE
			var material := ShaderMaterial.new(); material.shader = shader; part.material_override = material
			if self_depth:
				# The opaque world/opponent has already rendered. Establish the
				# nearest player surface without changing that color, then blend
				# only that surface. Sorting whole limbs cannot solve intersecting
				# torso, face and kit geometry. next_pass obeys material priority,
				# so every depth draw precedes every player color draw.
				if player_depth == null:
					var depth_shader := Shader.new(); depth_shader.code = PLAYER_DEPTH
					player_depth = ShaderMaterial.new(); player_depth.shader = depth_shader
					player_depth.render_priority = -1
				material.next_pass = player_depth
		materials[source] = part.material_override; used[part.material_override] = true
		var tint: Color = source.albedo_color; tint.a = alpha
		part.material_override.set_shader_parameter("tint", tint)
		part.material_override.set_shader_parameter("clear_window", window)
		part.material_override.set_shader_parameter("window_alpha", window_alpha)
		var aura := Vector3(source.emission.r, source.emission.g, source.emission.b) * source.emission_energy_multiplier if source.emission_enabled else Vector3.ZERO
		part.material_override.set_shader_parameter("aura", aura)
		part.material_override.set_shader_parameter("foreground_only", foreground_only)
		part.material_override.set_shader_parameter("clear_origin", origin)
		part.material_override.set_shader_parameter("clear_normal", normal)
		part.material_override.set_shader_parameter("opponent_mask", opponent_bounds.has_volume())
		part.material_override.set_shader_parameter("opponent_min", opponent_bounds.position)
		part.material_override.set_shader_parameter("opponent_max", opponent_bounds.end)

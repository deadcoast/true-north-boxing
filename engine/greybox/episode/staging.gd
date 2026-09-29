extends Node
## Authored screen action over the live episode. No simulation, rewards or saves
## are advanced here. PCM and film noise have a private seed, never the sim RNG.
const View := preload("res://presentation/fight_view.gd")
var director
var film: ColorRect
var material: ShaderMaterial
var ambience: AudioStreamPlayer
var foley: AudioStreamPlayer
var sounds := {}
var props: Node3D
var paper: MeshInstance3D
var stamp: MeshInstance3D
var observer: Node3D
var apron: MeshInstance3D
var shot := ""
var elapsed := 0.0
var length := 0.0
var origins := {}
var visited := {}
var sound_hole := false
var sound_hole_seconds := 0.0
var archive_camera := Transform3D.IDENTITY
var archive_position := Vector3.ZERO
var archive_rotation := 0.0

func setup(owner) -> void:
	director = owner
	film = ColorRect.new(); film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	director.surface.add_child(film); director.surface.move_child(film, 0)
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float clock = 0.0;
uniform float damage = 0.0;
float grain(vec2 p) { return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void fragment() {
  vec2 pixel = floor(UV / SCREEN_PIXEL_SIZE);
  float noise = grain(pixel + floor(clock * 24.0));
  float edge = max(abs(UV.x - 0.5) * 2.0, abs(UV.y - 0.5) * 2.0);
  float burn = smoothstep(1.05 - damage * 1.25, 1.1 - damage * 1.05, edge + noise * 0.07);
  float scan = mod(pixel.y, 3.0) < 1.0 ? 0.026 : 0.0;
  COLOR = vec4(mix(vec3(0.26,0.19,0.10), vec3(0.025,0.018,0.012), burn),
               min(1.0, noise * 0.065 + scan + burn * damage));
}"""
	material = ShaderMaterial.new(); material.shader = shader; film.material = material; film.hide()
	props = Node3D.new(); director.world.add_child(props)
	paper = _box(Vector3(0.5, 0.012, 0.34), Color("eee5c9"))
	# Two visible language columns, letterhead and an imperfect coffee ring.
	for i in 10:
		var line := _box(Vector3(0.19, 0.002, 0.005), Color("717366"))
		line.reparent(paper); line.position = Vector3(-0.12 if i < 5 else 0.12, 0.008, -0.1 + (i % 5) * 0.035)
	var crest := _box(Vector3(0.09, 0.002, 0.026), Color("954f45")); crest.reparent(paper); crest.position = Vector3(0, 0.009, -0.135)
	var ring := TorusMesh.new(); ring.inner_radius = 0.042; ring.outer_radius = 0.048; ring.rings = 20; ring.ring_segments = 6
	var stain := StandardMaterial3D.new(); stain.albedo_color = Color("b99b72")
	View._part(paper, ring, stain, Vector3(0.13, 0.01, 0.07))
	stamp = _box(Vector3(0.13, 0.18, 0.10), Color("733d2d"))
	apron = _box(Vector3(1.7, 0.78, 0.8), Color("324a59"))
	observer = View.make_fighter(props, Color("536061"), Vector3.ZERO)
	director.world._identity(observer, "OBSERVER")
	props.hide()
	ambience = AudioStreamPlayer.new(); add_child(ambience); ambience.volume_db = -27
	foley = AudioStreamPlayer.new(); add_child(foley); foley.volume_db = -17
	for id in ["room", "crowd", "paper", "stamp", "pin"]: sounds[id] = _sound(id)

func _box(size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = colour; mat.roughness = 0.95
	return View._part(props, mesh, mat, Vector3.ZERO)

func _sound(id: String) -> AudioStreamWAV:
	var loop: bool = id in ["room", "crowd"]
	var duration := 3.0 if loop else 0.28
	var count := int(22050 * duration); var bytes := PackedByteArray(); bytes.resize(count * 2)
	var random := RandomNumberGenerator.new(); random.seed = 204
	var filtered := 0.0
	for i in count:
		var t := float(i) / 22050.0
		filtered = lerpf(filtered, random.randf_range(-1, 1), 0.02 if loop else 0.30)
		var envelope := 1.0 if loop else minf(1, t * 100) * exp(-t * (18 if id == "paper" else 35))
		var wave := filtered * (1.6 if id == "crowd" else 0.65)
		if id == "room": wave += sin(TAU * 60 * t) * 0.06
		if id == "crowd": wave *= 0.7 + sin(TAU * t / 3.0) * 0.3
		if id == "stamp": wave += sin(TAU * 110 * t) * 0.5
		# Fade loop seams without consuming or reseeding game randomness.
		if loop: envelope *= minf(1, minf(t, duration - t) * 40)
		bytes.encode_s16(i * 2, int(clampf(wave * envelope, -1, 1) * 22000))
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050; stream.data = bytes
	if loop: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = count
	return stream

func _ambient(id: String) -> void:
	if ambience.stream == sounds[id] and ambience.playing: return
	ambience.stream = sounds[id]; ambience.play()

func _play(id: String) -> void:
	foley.stream = sounds[id]; foley.play()

func _place(person: Node3D, at: Vector3, facing: float) -> void:
	if not origins.has(person): origins[person] = {"transform":person.transform, "visible":person.visible}
	person.position = at; person.rotation.y = facing; person.show()

func _hand(person: Node3D, target: Vector3, right := true) -> void:
	var side := 1 if right else 0
	var shoulder := Vector3(0.25 if right else -0.25, 1.31, 0)
	var elbow := shoulder.lerp(target, 0.5) + Vector3(0.10 if right else -0.10, -0.13, 0.08)
	View._link(person.get_meta("upper_arms")[side], shoulder, elbow)
	View._link(person.get_meta("arms")[side], elbow, target)
	person.get_meta("gloves")[side].position = target
	person.get_meta("joints")[side * 3 + 1].position = elbow

func _camera(at: Vector3, target: Vector3, fov := 44.0) -> void:
	var camera: Camera3D = director.world.camera
	camera.position = at; camera.fov = fov; camera.look_at(target); camera.make_current()

func clear() -> void:
	for person in origins:
		if is_instance_valid(person): person.transform = origins[person]["transform"]; person.visible = origins[person]["visible"]
	origins.clear(); props.hide(); shot = ""; elapsed = 0; length = 0
	film.hide(); ambience.stream_paused = false; sound_hole = false
	director.world.camera.fov = 48
	if director.world.cards.has_node("charter"): director.world.cards.get_node("charter").show()
	for child in director.world.cards.get_children():
		if child is Label3D: child.show()

func begin(id: String, index := 0) -> float:
	clear(); shot = id + ":" + str(index); visited[shot] = true
	var world = director.world
	var coach: Node3D = world.cast["WHITLOCK"]
	if id == "archive":
		world.stage("archive"); film.show(); _ambient("crowd")
		for bar in director.bars: bar.show()
		_camera(Vector3(4, 3.3, 7), Vector3(0, 1, 0), 45)
		if index == 1:
			# Hold the same image and mute the tape for exactly one second.
			sound_hole = true; sound_hole_seconds = 0; ambience.stream_paused = true; length = 1
	elif id == "freeze":
		film.show(); _ambient("crowd"); length = 2
		var player: Node3D = director.scene.player
		archive_position = player.position; archive_rotation = player.rotation.y
		_hand(player, Vector3(0.32, 2.05, -0.07))
		_camera(player.position + Vector3(2.7, 2.4, 4.1), player.position + Vector3(0, 1.55, 0), 40)
		archive_camera = world.camera.global_transform
	elif id == "present":
		world.stage("world"); _ambient("room")
		length = 1.6
		if archive_camera == Transform3D.IDENTITY:
			archive_position = world.actor.position
			_camera(archive_position + Vector3(2.7, 2.4, 4.1), archive_position + Vector3(0, 1.55, 0), 40)
			archive_camera = world.camera.global_transform
		_place(world.actor, archive_position, archive_rotation)
		_hand(world.actor, Vector3(0.32, 2.05, -0.07))
		world.camera.global_transform = archive_camera; world.camera.fov = 40; world.camera.make_current()
	elif id == "letter":
		_ambient("room"); props.show(); stamp.hide(); observer.hide(); paper.show()
		apron.show(); apron.position = Vector3(-0.7, 0.40, 2.5)
		_place(coach, Vector3(-1.5, 0, 2.8), -PI * 0.5); _place(world.actor, Vector3(0, 0, 2.7), PI * 0.5)
		paper.position = Vector3(-1, 1.05, 2.8)
		_camera(Vector3(2.6, 2.7, 6.6), Vector3(-0.75, 1.1, 2.8))
		if index in [3, 4]:
			coach.hide(); world.actor.hide()
			_camera(Vector3(-0.8 if index == 3 else -0.4, 2.4, 3.55), Vector3(-0.7, 0.80, 2.5), 35)
			length = 1.5
		elif index == 11:
			_place(coach, Vector3(-5.8, 0, -4.45), 0)
			_camera(Vector3(-3.6, 2.3, -1.8), Vector3(-5.5, 1.6, -5))
			length = 2.1
		elif index == 0: length = 1.1
	elif id == "tag":
		world.stage("tag"); _ambient("room"); props.show(); paper.show(); stamp.visible = index < 2; observer.visible = index < 2
		apron.visible = index < 2; apron.position = Vector3(-2.1, 0.40, 1.6)
		world.vey.visible = index == 2
		if world.cards.has_node("charter"): world.cards.get_node("charter").visible = index > 2
		paper.position = Vector3(-2.1, 0.82, 1.6)
		if index < 2:
			_place(observer, Vector3(-2.1, 0, 2.15), 0)
			_camera(Vector3(0, 2.3, 4), Vector3(-2, 1.1, 1.8)); length = 1.6 if index == 0 else 0
		elif index == 2:
			_place(world.vey, Vector3(2.4, 0, 7.6), 0)
			_camera(Vector3(-0.5, 2.5, 4.7), Vector3(2.4, 1.2, 7.6)); length = 6.0
		else:
			paper.hide(); _camera(Vector3(-1.4, 2.6, -0.6), Vector3(-5.1, 1.5, -4.8))
	# Navigation labels do not belong in authored close-ups.
	for child in world.get_children():
		if child is Label3D: child.hide()
	for child in world.cards.get_children():
		if child is Label3D: child.hide()
	return length

func frame(delta: float) -> void:
	if not director.active: film.hide(); ambience.stop(); foley.stop(); return
	var previous := elapsed; elapsed += delta
	var archive: bool = director._ep().get("fight", "") == "archive" and director.state in ["fight", "freeze"] or shot.begins_with("archive:")
	film.visible = archive
	material.set_shader_parameter("clock", 0.0 if sound_hole else elapsed)
	material.set_shader_parameter("damage", clampf((elapsed - 0.7) / 1.3, 0, 1) if shot == "freeze:0" else 0.0)
	if director.episode_environment != null:
		var environment: Environment = director.episode_environment.environment
		environment.background_color = Color("182530") if archive else Color("7897a6")
		environment.ambient_light_energy = 0.45 if archive else 0.65
	if sound_hole:
		sound_hole_seconds = minf(1, elapsed)
		if elapsed >= 1: sound_hole = false; ambience.stream_paused = false
	elif director.state == "fight": _ambient("crowd" if archive or director._ep().get("fight") == "survival" else "room")
	if director.state not in ["dialogue", "freeze"]: return
	var world = director.world
	var coach: Node3D = world.cast["WHITLOCK"]
	if shot.begins_with("letter:"):
		var index := int(shot.get_slice(":", 1))
		if index == 11:
			paper.position = Vector3(-5.7, 1, -4.6).lerp(Vector3(-6.1, 1.7, -5.18), smoothstep(0, 1.6, elapsed))
			paper.rotation.x = lerpf(0, PI * 0.5, smoothstep(0, 1.6, elapsed))
			_hand(coach, coach.to_local(paper.global_position))
			if previous < 1.6 and elapsed >= 1.6: _play("pin")
		elif index in [3, 4]:
			paper.position = Vector3(-1, 1.05, 2.8).lerp(Vector3(-0.7, 0.80, 2.5), smoothstep(0, 1, elapsed))
			paper.rotation.x = 0; _hand(coach, coach.to_local(paper.global_position))
			if previous < 0.65 and elapsed >= 0.65: _play("paper")
		else: paper.rotation.x = 0; _hand(coach, coach.to_local(paper.global_position))
	elif shot == "tag:0" or shot == "tag:1":
		paper.rotation.x = 0
		stamp.position = paper.position + Vector3(0, 0.10 + absf(clampf(elapsed - 0.6, -0.6, 0.6)) * 0.55, 0)
		_hand(observer, observer.to_local(stamp.global_position))
		if previous < 0.6 and elapsed >= 0.6: _play("stamp")
	elif shot == "tag:2":
		if elapsed < 2.5:
			world.vey.position.z = 7.6 + maxf(0, elapsed - 1.5) * 2.0
			world.vey.visible = elapsed < 2.3; paper.hide()
		else:
			_camera(Vector3(-2.0, 2.7, -0.8), Vector3(-5.5, 1.5, -5))
			_place(world.squad[1], Vector3(-6.6, 0, -3.3), 0)
			_place(world.squad[2], Vector3(-6.1, 0, -2.8), 0)
			var priya: Node3D = world.squad[0]
			_place(priya, Vector3(-4.6, 0, -4.4), 0)
			paper.show(); paper.rotation.x = PI * 0.5
			paper.position = Vector3(-4.5, 1.1, -4.8).lerp(Vector3(-4.7, 1.6, -5.18), smoothstep(2.5, 4.1, elapsed))
			_hand(priya, priya.to_local(paper.global_position))
			if previous < 4.1 and elapsed >= 4.1: _play("pin")

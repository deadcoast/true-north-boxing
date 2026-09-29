extends Node3D
## Small world-space exhalations. Presentation time only, no simulation RNG.
var puffs: Array[MeshInstance3D] = []
var ages: Array[float] = []
var directions: Array[Vector3] = []
var clock := 0.0
var next_exhale := 0.0
var cursor := 0
var emitted := 0

func setup() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([Color(0.85, 0.92, 0.96, 0.8), Color(0.85, 0.92, 0.96, 0.35), Color(0.85, 0.92, 0.96, 0)])
	var texture := GradientTexture2D.new(); texture.gradient = gradient; texture.width = 64; texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL; texture.fill_from = Vector2(0.5, 0.5); texture.fill_to = Vector2(0.5, 0)
	for i in 12:
		var mesh := QuadMesh.new(); mesh.size = Vector2(0.32, 0.22)
		var mat := StandardMaterial3D.new(); mat.albedo_texture = texture
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var puff := MeshInstance3D.new(); puff.mesh = mesh; puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff); puff.hide(); puffs.append(puff); ages.append(2.0); directions.append(Vector3.ZERO)

func clear() -> void:
	clock = 0; next_exhale = 0; cursor = 0
	for i in puffs.size(): puffs[i].hide(); ages[i] = 2.0

func frame(delta: float, actor: Node3D, enabled: bool, working: bool) -> void:
	if not enabled: clear(); return
	clock += delta
	if clock >= next_exhale:
		next_exhale = clock + (1.7 if working else 3.1)
		var head: Node3D = actor.get_meta("head")
		var forward := -head.global_basis.z.normalized()
		for j in 3:
			var i := cursor % puffs.size(); cursor += 1
			puffs[i].global_position = head.to_global(Vector3(0, -0.055, -0.20)) + forward * j * 0.035
			directions[i] = forward * (0.55 + j * 0.10) + Vector3(0.025 * (j - 1), 0.12, 0)
			ages[i] = -j * 0.08; emitted += 1
	for i in puffs.size():
		ages[i] += delta
		var age := ages[i]
		puffs[i].visible = age >= 0 and age < 1.2
		if not puffs[i].visible: continue
		puffs[i].global_position += directions[i] * delta
		puffs[i].scale = Vector3.ONE * (0.45 + age * 1.5)
		(puffs[i].material_override as StandardMaterial3D).albedo_color.a = smoothstep(0, 0.10, age) * (1.0 - smoothstep(0.25, 1.2, age))

extends Node3D
## Four contiguous, traversable districts in the frozen vertical slice.
## Walking and collision live here; combat remains on the shared 120 Hz sim.
const View := preload("res://presentation/fight_view.gd")
var data: Dictionary
var language := "en"
var actor: Node3D
var camera: Camera3D
var squad: Array[Node3D] = []
var targets := {}
var labels := {}
var solids: Array[Rect2] = []
var gait := 0.0
var velocity := Vector2.ZERO
var nearest := ""
var district := "gym"
var visited: Array = []
var cast := {}
var cards: Node3D
var signposts: Array[Label3D] = []
var spectators: Node3D
var vey: Node3D
var binders: Node3D

func setup(content: Dictionary, lang: String) -> void:
	data = content; language = lang
	_box(Vector3(94, 0.3, 98), Vector3(0, -0.22, 5), Color("c2d3d9"))
	_box(Vector3(14, 0.04, 76), Vector3(0, -0.025, 9), Color("526675"))
	_box(Vector3(74, 0.04, 10), Vector3(0, -0.015, -14), Color("526675"))
	for place in data["places"]:
		var p := Vector2(float(place["at"][0]), float(place["at"][1]))
		_building(p, Color(place["colour"]), str(place[lang]), place["id"] == "gym", place["id"] == "harbour")
		for x in [-8.5, 8.5]: _lamp(Vector3(p.x + x, 0, p.y + 8))
	_dress_town()
	# Harbour: pilings, ice, mooring rope and a boarding platform.
	_box(Vector3(94, 0.12, 16), Vector3(0, -0.2, 48), Color("254956"))
	_box(Vector3(11, 0.3, 10), Vector3(0, 0, 44), Color("736858"))
	for x in [-5, 5]:
		for z in [41, 45, 48]: _box(Vector3(0.25, 1.2, 0.25), Vector3(x, 0.55, z), Color("584f47"))
	for i in 16:
		var x := -43.0 + i * 5.5
		_box(Vector3(2.5, 0.06, 1.8), Vector3(x, -0.1, 44 + (i % 3) * 2), Color("a9cbd3"))
	# Posted boundaries belong to the next chapters; never invisible exits.
	for gate in [{"p": Vector3(-43, 0, -14), "en":"DOWNTOWN / ANNEX\nRoutes reopen after the charter decision", "fr":"CENTRE-VILLE / ANNEXE\nRoutes fermées jusqu’à la décision"}, {"p":Vector3(43, 0, -14), "en":"RINK / INDUSTRIAL / HILLS\nSeason routes closed", "fr":"ARÉNA / INDUSTRIEL / COLLINES\nRoutes de saison fermées"}]:
		_box(Vector3(0.3, 1.2, 10), gate["p"] + Vector3.UP * 0.6, Color("b27a3c"), true)
		_label(gate["en"] if lang == "en" else gate["fr"], gate["p"] + Vector3(0, 2.8, 0), 25)
	for object in data["objects"]:
		var at := Vector3(float(object["at"][0]), 0, float(object["at"][1]))
		targets[object["id"]] = at
		labels[object["id"]] = _label(str(object[lang]), at + Vector3(0, 2.35, 0), 30)
		if object.has("person"):
			var colour := Color("4f869b")
			if object["person"] == "MARCUS": colour = Color("a8744f")
			if object["person"] == "JUNE": colour = Color("83b4bc")
			var person := View.make_fighter(self, colour, at)
			_identity(person, str(object["person"]))
			person.set_meta("phase", float(cast.size())); cast[object["person"]] = person
			if object["person"] == "MARCUS": person.scale = Vector3(1.18, 1.12, 1.18)
		elif object["id"] == "letter":
			_box(Vector3(1.2, 1.2, 0.4), at + Vector3.UP * 0.6, Color("9b896b"))
			_box(Vector3(0.8, 0.7, 0.04), at + Vector3(0, 1, 0.23), Color("e2ddc2"))
		elif object["id"] in ["wall", "board", "film", "locker"]: pass # Dressed furniture below.
		else:
			_box(Vector3(0.8, 0.25, 0.8), at + Vector3.UP * 0.12, Color("bc965a"))
	# School bike racks and the library's three binders.
	for i in 4:
		_box(Vector3(0.06, 0.8, 1.1), Vector3(-27 + i * 0.7, 0.4, -20.5), Color("2b404d"))
	for i in 3: _box(Vector3(0.2, 0.4, 0.35), Vector3(-33.5 + i * 0.25, 0.95, -26), Color("947054"))
	cards = Node3D.new(); add_child(cards)
	spectators = Node3D.new(); add_child(spectators)
	for i in 40:
		var at := Vector3(-6.3 if i % 2 == 0 else 6.3, 0, -5.5 + (i / 2) * 0.55)
		var coat := BoxMesh.new(); coat.size = Vector3(0.38, 0.85, 0.33)
		var material := StandardMaterial3D.new(); material.albedo_color = [Color("504a47"), Color("616c72"), Color("69716a"), Color("80694c")][i % 4]
		View._part(spectators, coat, material, at + Vector3.UP * 0.8)
		var head := SphereMesh.new(); head.radius = 0.16; head.height = 0.32
		var skin := StandardMaterial3D.new(); skin.albedo_color = Color("b99d85")
		View._part(spectators, head, skin, at + Vector3.UP * 1.45)
	spectators.hide()
	vey = View.make_fighter(self, Color("272d36"), Vector3(2.4, 0, 7.6)); _identity(vey, "VEY"); _pose(vey, 0, 0); vey.hide()
	var long_coat := BoxMesh.new(); long_coat.size = Vector3(0.48, 0.7, 0.36)
	var coat_material := StandardMaterial3D.new(); coat_material.albedo_color = Color("272d36")
	View._part(vey, long_coat, coat_material, Vector3(0, 0.65, 0))
	actor = View.make_fighter(self, Color("d6b06f"), Vector3(0, 0, 6))
	_identity(actor, "RORY")
	for i in 3:
		var member := View.make_fighter(self, [Color("73a4b7"), Color("a8744f"), Color("92b8b9")][i], actor.position)
		member.visible = false; squad.append(member)
		_identity(member, ["PRIYA", "MARCUS", "JUNE"][i])
	camera = Camera3D.new(); add_child(camera); camera.fov = 48; camera.far = 180
	frame(1.0, true)

func _identity(person: Node3D, name: String) -> void:
	if View.FighterVisuals.apply(person, name, true):
		_pose(person, 0, 0)
		return
	var head: Node3D = person.get_meta("head")
	var hair := SphereMesh.new(); hair.radius = 0.18; hair.height = 0.2
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("dad5c4") if name == "WHITLOCK" else Color("302a2a")
	View._part(head, hair, mat, Vector3(0, 0.13, 0.015))
	if name == "WHITLOCK":
		var parka := StandardMaterial3D.new(); parka.albedo_color = Color("374b46"); parka.roughness = 0.95
		var suit := StandardMaterial3D.new(); suit.albedo_color = Color("292e39")
		var coat := BoxMesh.new(); coat.size = Vector3(0.54, 0.72, 0.40)
		View._part(person.get_meta("mesh"), coat, parka, Vector3(0, -0.05, 0.035))
		var jacket := BoxMesh.new(); jacket.size = Vector3(0.21, 0.42, 0.025)
		View._part(person.get_meta("mesh"), jacket, suit, Vector3(0, 0.04, -0.18))
	var skin: StandardMaterial3D = head.mesh.material.duplicate(); skin.albedo_color = {"PRIYA":Color("ac7e62"), "MARCUS":Color("be8e70"), "JUNE":Color("e0bfa0"), "RORY":Color("d4aa88")}.get(name, Color("c7b09b"))
	head.mesh = head.mesh.duplicate(); head.mesh.material = skin
	var eye := SphereMesh.new(); eye.radius = 0.017; eye.height = 0.034
	for side in [-1, 1]: View._part(head, eye, mat, Vector3(side * 0.07, 0.015, -0.163))
	if name == "PRIYA":
		var glasses := BoxMesh.new(); glasses.size = Vector3(0.31, 0.022, 0.028)
		View._part(head, glasses, mat, Vector3(0, 0.035, -0.175))
	_pose(person, 0, 0)

func _dress_town() -> void:
	# A winter campus with visible routes: no texture downloads or runtime assets.
	var random := RandomNumberGenerator.new(); random.seed = 1976
	for x in [-39.0, -17.0, 17.0, 39.0]:
		for z in [2.0, 16.0, 34.0]:
			_box(Vector3(0.32, 2.5, 0.32), Vector3(x, 1.25, z), Color("655444"))
			for crown in 3:
				var cone := CylinderMesh.new(); cone.top_radius = 0; cone.bottom_radius = 1.7 - crown * 0.35; cone.height = 2.5
				var material := StandardMaterial3D.new(); material.albedo_color = Color("47696c").lightened(crown * 0.04)
				View._part(self, cone, material, Vector3(x, 2.7 + crown * 1.0, z))
				var snow := cone.duplicate() as CylinderMesh; snow.height = 0.9; snow.bottom_radius *= 0.55
				var white := StandardMaterial3D.new(); white.albedo_color = Color("d8e8eb")
				View._part(self, snow, white, Vector3(x, 3.5 + crown * 1.0, z))
	for i in 90:
		var x := random.randf_range(-46, 46); var z := random.randf_range(-38, 52)
		if absf(x) < 9 or absf(z + 14) < 6: continue
		var pile := SphereMesh.new(); pile.radius = random.randf_range(0.45, 1.2); pile.height = pile.radius * 2
		var material := StandardMaterial3D.new(); material.albedo_color = Color("dfebec")
		var drift := View._part(self, pile, material, Vector3(x, -0.12, z)); drift.scale.y = 0.25
	# Painted lane dashes and boot-cleared paths; four districts share this route.
	for z in range(10, 24, 4): _box(Vector3(0.10, 0.016, 1.5), Vector3(0, 0.014, z), Color("bec0ad"))
	for x in range(-36, 37, 4): _box(Vector3(1.5, 0.016, 0.10), Vector3(x, 0.014, -14), Color("bec0ad"))
	for place in data["places"]:
		var c := Vector3(place["at"][0], 0, place["at"][1])
		# Narrow floorboards and a municipal crest distinguish the cutaway interiors.
		for i in 18: _box(Vector3(14, 0.012, 0.024), c + Vector3(0, 0.023, -7.5 + i * 0.85), Color("526469") if place["id"] != "gym" else Color("544a40"))
		for i in 8:
			_box(Vector3(0.05, 0.9, 0.35), c + Vector3(-6.5 + i * 0.4, 0.45, -7.5), Color("80705a"))
		var emblem := _label("M\n1961" if place["id"] == "gym" else "MILLBROOK", c + Vector3(0, 2.2, -7.68), 44)
		emblem.billboard = BaseMaterial3D.BILLBOARD_DISABLED; emblem.pixel_size = 0.017
	# Gym furniture is shaped as its function, not anonymous interaction cubes.
	# The worn training canvas stays in the room between bouts; the competition
	# ropes are fitted by the shared arena when the sanctioned segment begins.
	_box(Vector3(7.4, 0.016, 7.4), Vector3(0, 0.04, 0), Color("364e5b"))
	for side in [-1, 1]:
		_box(Vector3(7.1, 0.012, 0.035), Vector3(0, 0.055, side * 3.5), Color("b9b19a"))
		_box(Vector3(0.035, 0.012, 7.1), Vector3(side * 3.5, 0.055, 0), Color("b9b19a"))
	for z in [-1.8, -0.4]:
		var bag := CylinderMesh.new(); bag.top_radius = 0.27; bag.bottom_radius = 0.27; bag.height = 1.0
		var leather := StandardMaterial3D.new(); leather.albedo_color = Color("8b4437")
		View._part(self, bag, leather, Vector3(-6.5, 1.3, z)); _box(Vector3(0.04, 1.2, 0.04), Vector3(-6.5, 2.4, z), Color("383d40"))
	_box(Vector3(1.6, 0.12, 0.8), Vector3(5, 0.8, 4), Color("a18964"))
	binders = Node3D.new(); add_child(binders); binders.hide()
	for i in 3:
		var binder := _box(Vector3(0.22, 0.42, 0.34), Vector3(4.6 + i * 0.26, 1.03, 4), [Color("446a7e"), Color("aa744e"), Color("638276")][i])
		binder.reparent(binders)
	for i in 4:
		_box(Vector3(0.65, 1.9, 0.6), Vector3(4.1 + i * 0.7, 0.95, -5.4), Color("708289"))
		_box(Vector3(0.035, 0.18, 0.06), Vector3(4.3 + i * 0.7, 1.15, -5.06), Color("c4b887"))
	_box(Vector3(3.1, 1.8, 0.15), Vector3(-5, 1.3, -5.3), Color("655642"))
	_box(Vector3(2.6, 1.5, 0.13), Vector3(0, 1.55, -5.4), Color("c4d2cc"))
	for i in 3:
		_box(Vector3(2.3, 0.025, 0.02), Vector3(0, 1.15 + i * 0.36, -5.32), Color("556b70"))
	# School: library shelves and study carrel. Community: open mat and bags.
	for i in 3:
		_box(Vector3(0.35, 2, 3), Vector3(-36.5 + i * 2.8, 1, -29.5), Color("967552"))
		for row in 4: _box(Vector3(0.4, 0.08, 3), Vector3(-36.5 + i * 2.8, 0.25 + row * 0.48, -29.5), Color("cab386"))
	_box(Vector3(2.2, 0.13, 1.2), Vector3(-34, 0.8, -26), Color("997c57"))
	_box(Vector3(9, 0.08, 5), Vector3(30, 0.05, -24), Color("446570"))
	for x in [-1, 1]: _box(Vector3(0.06, 0.012, 5), Vector3(30 + x * 4.2, 0.095, -24), Color("c1c8bd"))

func _box(size: Vector3, at: Vector3, colour: Color, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = colour; mat.roughness = 0.96
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = mat; node.position = at; add_child(node)
	if solid: solids.append(Rect2(Vector2(at.x - size.x * 0.5, at.z - size.z * 0.5) - Vector2.ONE * 0.32, Vector2(size.x, size.z) + Vector2.ONE * 0.64))
	return node

func _label(value: String, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new(); label.text = value; label.position = at; label.font_size = font_size
	label.pixel_size = 0.010; label.outline_size = 8; label.modulate = Color("f5ead3")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = false
	add_child(label); return label

func _building(at: Vector2, colour: Color, title: String, gym: bool, entrance_north := false) -> void:
	var c := Vector3(at.x, 0, at.y)
	var facing := -1.0 if entrance_north else 1.0
	_box(Vector3(15, 0.1, 16), c - Vector3.UP * 0.04, Color("786b5c") if gym else Color("7c8b8e"))
	_box(Vector3(15, 4, 0.5), c + Vector3(0, 2, -8 * facing), colour, true)
	for side in [-1, 1]:
		_box(Vector3(0.5, 3, 16), c + Vector3(side * 7.5, 1.5, 0), colour, true)
		_box(Vector3(4.5, 1.0, 0.5), c + Vector3(side * 5.25, 0.5, 8 * facing), colour, true)
		for z in [-5, 0, 5]: _box(Vector3(0.08, 1.25, 1.6), c + Vector3(side * 7.2, 2, z), Color("e4bc70"))
	_box(Vector3(15.3, 0.2, 0.8), c + Vector3(0, 4.05, -8 * facing), Color("d6e2e5"))
	_label(title, c + Vector3(0, 3.3, -7.65 * facing), 34)
	for i in 3:
		_box(Vector3(3, 0.16, 0.6), c + Vector3(-3.6 + i * 3.6, 0.5, -6.4), Color("473f38"))

func _lamp(at: Vector3) -> void:
	_box(Vector3(0.12, 4, 0.12), at + Vector3.UP * 2, Color("364954"))
	_box(Vector3(0.6, 0.25, 0.6), at + Vector3.UP * 4, Color("f2cc88"))

func restore(at: Array) -> void:
	velocity = Vector2.ZERO
	actor.position = Vector3(clampf(float(at[0]), -41, 41), 0, clampf(float(at[1]), -33, 47))
	for i in squad.size(): squad[i].position = actor.position + Vector3((i - 1) * 0.75, 0, 1.3 + absf(i - 1) * 0.4)
	frame(1.0, true)

func point() -> Array: return [actor.position.x, actor.position.z]

func stage(id: String) -> void:
	spectators.visible = id in ["archive", "survival"]
	vey.visible = id == "tag"
	# In-world signs must never cover a tell, fighter or the match score.
	for child in get_children():
		if child is Label3D: child.visible = id in ["world", "tag"]
	if cards != null: cards.visible = id in ["world", "tag"]
	if id == "tag":
		actor.position = Vector3(-1, 0, -1.5)
		for i in squad.size(): squad[i].position = Vector3(-5.8 + i * 1.0, 0, -3.5)
		for person in squad: _pose(person, 0, 0)
		camera.position = Vector3(7, 7, 12); camera.look_at(Vector3(-2, 1, -1))

func sync(sim) -> void:
	var names := ["PRIYA", "MARCUS", "JUNE"]
	for i in 3:
		squad[i].visible = not sim._stable_card(names[i]).is_empty()
		if cast.has(names[i]): cast[names[i]].visible = not squad[i].visible
	for child in cards.get_children(): cards.remove_child(child); child.queue_free()
	var flags: Dictionary = sim.rewards.get("episode", {}).get("flags", {})
	binders.visible = flags.get("joined_PRIYA", false)
	if not flags.get("letter", false): return
	var letter := _box(Vector3(0.55, 0.8, 0.04), Vector3(-6.1, 1.7, -5.18), Color("ece2bd")); letter.reparent(cards); letter.name = "letter"
	_wall_paper(letter, "MILLBROOK", "TWO SEGMENT VICTORIES\nDEUX SEGMENTS GAGNÉS")
	for i in sim.stable.size():
		var card := _box(Vector3(0.4, 0.6, 0.06), Vector3(-5.65 + i * 0.42, 1.35, -4.7), Color("e2c78e"))
		card.reparent(cards); card.name = "card_" + str(sim.stable[i]["name"])
		_wall_paper(card, str(sim.stable[i]["name"]), "MILLBROOK")
		var label := _label(str(sim.stable[i]["name"]), card.position + Vector3(0, 0.5, 0), 17); label.reparent(cards)
	if sim.rewards.get("episode", {}).get("flags", {}).get("survival", false):
		var carbon := _box(Vector3(0.55, 0.8, 0.04), Vector3(-4.7, 1.6, -5.18), Color("a8c8e1")); carbon.reparent(cards); carbon.name = "charter"
		_wall_paper(carbon, "CARBON / DOUBLE", "CHARTER STANDS\nCHARTE MAINTENUE")

func _wall_paper(face: MeshInstance3D, title: String, footer: String) -> void:
	# Printed content stays on the paper during close-ups; floating navigation
	# labels can be hidden without turning the earned wall into blank blocks.
	var size: Vector3 = face.mesh.size
	for item in [[title, 0.20, 0.0015], [footer, -0.20, 0.0011]]:
		var ink := Label3D.new(); ink.text = item[0]; ink.font_size = 24
		ink.pixel_size = item[2]; ink.position = Vector3(0, item[1], size.z * 0.5 + 0.004)
		ink.modulate = Color("293d47"); ink.outline_size = 0; ink.no_depth_test = false
		face.add_child(ink)
	var material := StandardMaterial3D.new(); material.albedo_color = Color("717366")
	for i in 6:
		var stroke := BoxMesh.new(); stroke.size = Vector3(size.x * (0.73 if i % 3 != 2 else 0.52), 0.006, 0.002)
		View._part(face, stroke, material, Vector3(-size.x * 0.04, 0.10 - i * 0.036, size.z * 0.5 + 0.003))

func _clear(at: Vector2) -> bool:
	if at.x < -41 or at.x > 41 or at.y < -33 or at.y > 47: return false
	for rect in solids:
		if rect.has_point(at): return false
	return true

func walk(direction: Vector2, jog: bool, delta: float) -> void:
	velocity = velocity.move_toward(direction.limit_length() * (6.0 if jog else 3.6), delta * 22)
	var old := Vector2(actor.position.x, actor.position.z)
	var next := old + velocity * delta
	if not _clear(Vector2(next.x, old.y)): next.x = old.x
	if not _clear(Vector2(next.x, next.y)): next.y = old.y
	actor.position = Vector3(next.x, 0, next.y)
	var distance := old.distance_to(next); gait += distance * 2.5
	if distance > 0.001: actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-velocity.x, -velocity.y), minf(1, delta * 14))
	_pose(actor, gait, minf(1, distance / maxf(delta * 3.6, 0.001)))
	var last := actor.position
	for i in 3:
		var member := squad[i]
		if not member.visible: continue
		var gap := member.position.distance_to(last)
		var previous := member.position
		if gap > 1.3:
			var target := member.position.move_toward(last, minf(gap - 1.3, delta * 6.5))
			if _clear(Vector2(target.x, target.z)): member.position = target
			elif gap > 8: member.position = actor.position
			member.rotation.y = lerp_angle(member.rotation.y, atan2(member.position.x - last.x, member.position.z - last.z), minf(1, delta * 10))
		_pose(member, gait - i * 0.8, minf(1, previous.distance_to(member.position) / maxf(delta * 3.6, 0.001)))
		last = member.position
	for person in cast.values(): _pose(person, gait + float(person.get_meta("phase")), 0)
	nearest = ""; var best := 2.6
	for id in targets:
		var d: float = actor.position.distance_to(targets[id])
		if d < best: nearest = id; best = d
	for id in labels:
		labels[id].modulate = Color("ffe0a0") if id == nearest else Color("dce4e6")
		labels[id].visible = actor.position.distance_to(targets[id]) < 12
	var place_distance := INF
	for place in data["places"]:
		var d := next.distance_to(Vector2(place["at"][0], place["at"][1]))
		if d < place_distance: district = place["id"]; place_distance = d
	if not district in visited: visited.append(district)
	frame(delta)

func _pose(person: Node3D, phase: float, strength: float) -> void:
	# Shadowboxing hands this same rig back to exploration; reset the combat
	# face orientation when the actor resumes facing with its world root.
	person.get_meta("head").rotation = Vector3.ZERO
	if person.get_meta("cast_key", "") != "":
		person.get_meta("mesh").rotation = Vector3(0, PI, 0)
		person.get_meta("mesh").scale = Vector3(1, 1, .70)
		person.get_meta("hips").rotation = Vector3(0, PI, 0)
		for boot in person.get_meta("boots"): boot.rotation = Vector3(0, PI, 0)
	# Walking gait uses this cast's articulated hips, knees, ankles and shoulders.
	# Combat fighters continue to use BoxingMotion and its planted support solver.
	var bob := absf(sin(phase)) * 0.035 * strength
	person.get_meta("head").position = Vector3(0, 1.63 + bob, 0)
	person.get_meta("hips").position = Vector3(0, 0.77 + bob, 0)
	person.get_meta("mesh").position = Vector3(0, 1.1 + bob, 0)
	View._link(person.get_meta("abdomen"), Vector3(0, 0.78, 0), Vector3(0, 1.03 + bob, 0))
	View._link(person.get_meta("neck"), Vector3(0, 1.36 + bob, 0), Vector3(0, 1.52 + bob, 0))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var swing := sin(phase + i * PI) * strength
		var hip := Vector3(side * 0.16, 0.78 + bob, 0)
		var knee := Vector3(side * 0.17, 0.4 + maxf(0, swing) * 0.10, swing * 0.14)
		var foot := Vector3(side * 0.18, 0.065 + maxf(0, swing) * 0.13, swing * 0.35)
		person.get_meta("boots")[i].position = foot
		View._link(person.get_meta("thighs")[i], hip, knee); View._link(person.get_meta("legs")[i], knee, foot)
		var shoulder := Vector3(side * 0.25, 1.31 + bob, 0)
		var elbow := Vector3(side * 0.29, 1.0 + bob, -swing * 0.12)
		var hand := Vector3(side * 0.3, 0.84 + bob, -0.12 - swing * 0.22)
		View._link(person.get_meta("clavicles")[i], Vector3(0, 1.3 + bob, 0), shoulder)
		View._link(person.get_meta("upper_arms")[i], shoulder, elbow); View._link(person.get_meta("arms")[i], elbow, hand)
		person.get_meta("gloves")[i].position = hand
		if person.get_meta("cast_key", "") != "":
			person.get_meta("gloves")[i].quaternion = Quaternion(Vector3.FORWARD, (hand - elbow).normalized())
		person.get_meta("joints")[i * 3].position = shoulder
		person.get_meta("joints")[i * 3 + 1].position = elbow
		person.get_meta("joints")[i * 3 + 2].position = knee

func frame(delta: float, immediate := false) -> void:
	var target := actor.position + Vector3(0, 9.5, 12)
	camera.position = target if immediate else camera.position.lerp(target, 1 - exp(-6 * delta))
	camera.look_at(actor.position + Vector3(0, 0.8, -2))

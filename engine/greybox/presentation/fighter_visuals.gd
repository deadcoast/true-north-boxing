extends RefCounted
## Authored sectional meshes ride the existing boxing joints. No animation clock,
## RNG, hit volume or new combat pose: feet -> hips -> ribs -> shoulders -> fist
## all retain the planted, constrained, interpolated motion from FightView.
static var catalog: Dictionary = {}
static var shapes: Dictionary = {}
const ANCHORS := ["mesh", "head", "hips", "abdomen", "neck", "gloves", "arms", "upper_arms", "legs", "thighs", "boots", "joints", "clavicles"]

class CastSurface extends MeshInstance3D:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE: mesh = null

static func identity(name: String) -> String:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/fighter_cast.v1.json"))["fighters"]
	var upper := name.to_upper()
	for key in catalog:
		for alias in catalog[key]["aliases"]:
			if upper == str(alias).to_upper() or upper.begins_with(str(alias).to_upper() + " "): return key
	return ""

static func apply(root: Node3D, name: String, world := false) -> bool:
	var key := identity(name)
	var signature := key + (":world" if world else ":fight")
	if root.get_meta("visual_identity", "") == signature:
		if key != "": _aura(root)
		return key != ""
	# Shared fight nodes are reused by the board, reserve swaps and archive.
	# Restore the original rig on unknown identities instead of leaking a cast skin.
	for part in root.get_meta("cast_parts", []):
		# Detach the render base before releasing its instance-only materials.
		part.mesh = null; part.free()
	root.set_meta("cast_parts", []); root.set_meta("cast_body", [])
	var anchors: Array = []
	for field in ANCHORS:
		var value = root.get_meta(field)
		if value is Array: anchors.append_array(value)
		else: anchors.append(value)
	for anchor in anchors:
		anchor.layers = 1 if key == "" else 0
		for child in anchor.get_children():
			if child is MeshInstance3D: child.layers = anchor.layers
	if not root.has_meta("original_kit"):
		root.set_meta("original_kit", (root.get_meta("mat") as StandardMaterial3D).albedo_color)
	root.set_meta("visual_identity", signature); root.set_meta("cast_key", key)
	if key == "":
		root.get_meta("mat").albedo_color = root.get_meta("original_kit")
		root.get_meta("head").rotation = Vector3.ZERO
		return false
	var p: Dictionary = catalog[key]
	var skin := _material(p["skin"], 0.82)
	var kit := _material(p["kit"]); var shorts := _material(p["shorts"])
	var trim := _material(p["trim"]); var hair := _material(p["hair"])
	var boot_mat := _material(p["shorts"], 0.7)
	root.set_meta("cast_materials", [skin,kit,shorts,boot_mat])
	var hands: StandardMaterial3D = root.get_meta("glove_mat")
	hands.albedo_color = Color(p["gloves"]); hands.roughness = 0.52
	root.set_meta("cast_glove_color", Color(p["gloves"]))
	var bulk := float(p["bulk"])
	# Deltoid/pectoral breadth tapers into the waist; these are shaped surfaces,
	# not enlarged collision cylinders. +Z is the chest side of the torso anchor.
	# The central striking surface retains the shared .21 m body radius.
	# Build differences belong in the shoulder girdle and limbs, not a shirt
	# that makes an unchanged physical body punch visibly stop in empty air.
	_surface(root, "mesh", _loft("torso:" + key, [[-.285,.165,.16],[-.23,.195,.20],[-.17,.21,.21],[.13,.21,.21],[.22,.24*bulk,.21],[.26,.23*bulk,.16],[.285,.145,.10]]), kit)
	_surface(root, "abdomen", _loft("waist:" + key, [[-.5,.174,.124],[0,.172,.128],[.5,.169,.129]], bulk), kit)
	_surface(root, "hips", _loft("trunks:" + key, [[-.13,.214,.15],[-.08,.219,.16],[.06,.198,.147],[.13,.183,.13]], bulk), shorts)
	_surface(root, "hips", _loft("belt:" + key, [[.065,.199,.15],[.13,.186,.133]], bulk), trim)
	_surface(root, "neck", _loft("neck", [[-.5,.085,.078],[0,.079,.075],[.5,.079,.078]]), skin)
	# Singlet binding, club mark and sewn back number turn with the ribcage.
	for side in [-1.0, 1.0]:
		_detail(root, "mesh", _box(Vector3(.022,.18,.025)), trim, Vector3(side*.145,.11,.162))
	_crest(root, p, trim)
	var jaw := float(p["jaw"])
	var face := _loft("face:" + key, [[-.18,.046*jaw,.062],[-.145,.096*jaw,.106],[-.075,.132*jaw,.141],[.02,.146,.152],[.095,.143,.14],[.155,.10,.103],[.175,.025,.03]])
	_surface(root, "head", face, skin)
	_face(root, p, skin, hair, trim, world)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_surface(root, "upper_arms", _loft("upper:" + key, [[-.54,.059,.061],[-.36,.096,.099],[-.08,.087,.091],[.25,.069,.075],[.52,.061,.064]], bulk), skin, i)
		_surface(root, "arms", _loft("forearm:" + key, [[-.52,.059,.063],[-.25,.075,.071],[.08,.063,.065],[.38,.048,.048],[.54,.042,.043]], bulk), skin, i)
		_surface(root, "thighs", _loft("thigh:" + key, [[-.55,.097,.108],[-.24,.107,.11],[.13,.09,.095],[.52,.071,.074]], bulk), skin, i)
		_surface(root, "thighs", _loft("short-leg:" + key, [[-.55,.119,.128],[-.30,.127,.137],[.12,.115,.126]], bulk), shorts, i)
		_surface(root, "thighs", _loft("hem:" + key, [[.07,.116,.127],[.13,.116,.127]], bulk), trim, i)
		_surface(root, "legs", _loft("calf:" + key, [[-.52,.07,.072],[-.18,.082,.086],[.1,.072,.07],[.5,.049,.05]], bulk), skin, i)
		# Rounded shoulder, elbow and patella connect tapering muscle sections.
		for j in 3:
			var radius: float = [.098,.063,.072][j] * bulk
			_surface(root, "joints", _ellipsoid(Vector3(radius,radius*.9,radius)), skin, i*3+j)
		_surface(root, "clavicles", _loft("shoulder:" + key, [[-.5,.06,.06],[.0,.08,.073],[.5,.079,.08]], bulk), kit, i)
		# Toe is +Z on the pivoted boot; soles sit below the foot anchor.
		_surface(root, "boots", _loft("boot", [[-.063,.081,.149,.04],[.015,.086,.153,.04],[.055,.075,.132,.03],[.075,.061,.072,0],[.23,.059,.062,0]]), boot_mat, i)
		_surface(root, "boots", _loft("sole", [[-.068,.084,.15],[-.039,.087,.155]], 1, .04), trim, i)
		for lace in 4:
			_detail(root, "boots", _box(Vector3(.084,.012,.012)), trim, Vector3(0,.088+lace*.032,.042), i)
		# Knuckle pouch, folded thumb, cuff and seam follow fist turnover exactly.
		_surface(root, "gloves", _ellipsoid(Vector3(.128,.132,.144)), hands, i, false)
		_detail(root, "gloves", _ellipsoid(Vector3(.049,.074,.065)), hands, Vector3(-side*.095,-.065,.015), i, false)
		var cuff := _surface(root, "gloves", _loft("cuff", [[-.052,.074,.067],[.052,.078,.072]]), hands, i, false)
		cuff.rotation.x = PI*.5; cuff.position.z = .115
		_detail(root, "gloves", _box(Vector3(.079,.018,.014)), trim, Vector3(0,.09,.105), i, false)
	return true

static func _aura(root: Node3D) -> void:
	var source: StandardMaterial3D = root.get_meta("mat")
	for material in root.get_meta("cast_materials", []):
		material.emission_enabled = source.emission_enabled
		material.emission = source.emission; material.emission_energy_multiplier = source.emission_energy_multiplier

static func _material(color: String, roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(color); mat.roughness = roughness
	return mat

static func _surface(root: Node3D, field: String, shape: Mesh, material: StandardMaterial3D, index := -1, body := true) -> MeshInstance3D:
	var parent = root.get_meta(field) if index < 0 else root.get_meta(field)[index]
	var node := CastSurface.new(); node.mesh = shape; node.set_surface_override_material(0, material)
	# Visibility follows anatomy, including details sharing a skin/kit material.
	# A working arm must remain one visible chain from clavicle to glove.
	node.set_meta("rig_anchor", field); node.set_meta("rig_index", index)
	parent.add_child(node); root.get_meta("cast_parts").append(node)
	if body: root.get_meta("cast_body").append(node)
	return node

static func _detail(root: Node3D, field: String, shape: Mesh, material: StandardMaterial3D, at: Vector3, index := -1, body := true) -> MeshInstance3D:
	var node := _surface(root, field, shape, material, index, body); node.position = at; return node

static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new(); mesh.size = size; mesh.material = _material("ffffff"); return mesh

static func _ellipsoid(size: Vector3) -> ArrayMesh:
	var rings := []
	for j in 9:
		var angle := PI * float(j) / 8
		rings.append([-cos(angle)*size.y, maxf(.001,sin(angle)*size.x), maxf(.001,sin(angle)*size.z)])
	return _loft("oval:" + str(size), rings)

static func _loft(key: String, rings: Array, width := 1.0, shift := 0.0) -> ArrayMesh:
	if shapes.has(key): return shapes[key]
	var vertices := PackedVector3Array(); var indices := PackedInt32Array()
	const SIDES := 16
	for ring in rings:
		for i in SIDES:
			var angle := TAU * float(i) / SIDES
			vertices.append(Vector3(sin(angle)*float(ring[1])*width, ring[0], cos(angle)*float(ring[2]) + (float(ring[3]) if ring.size() > 3 else shift)))
	for j in rings.size()-1:
		for i in SIDES:
			var a := j*SIDES+i; var b := j*SIDES+(i+1)%SIDES
			indices.append_array([a,a+SIDES,b,b,a+SIDES,b+SIDES])
	for end in [0, rings.size()-1]:
		var center := vertices.size(); vertices.append(Vector3(0,rings[end][0],float(rings[end][3]) if rings[end].size() > 3 else shift))
		for i in SIDES:
			var a: int = end*SIDES+i; var b: int = end*SIDES+(i+1)%SIDES
			indices.append_array([center,a,b] if end == 0 else [center,b,a])
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new(); surface.create_from(mesh, 0); surface.generate_normals()
	var result := surface.commit(); result.surface_set_material(0, _material("ffffff")); shapes[key] = result; return result

static func _face(root: Node3D, p: Dictionary, skin: StandardMaterial3D, hair: StandardMaterial3D, trim: StandardMaterial3D, world: bool) -> void:
	var dark := _material("30262a"); var eye_white := _material("ded6c5")
	# Small recessed eyes, brows, nose bridge, lips and ears read from the fight
	# camera without an oversized mascot head or extra attack anticipation.
	for side in [-1.0,1.0]:
		_detail(root,"head",_ellipsoid(Vector3(.025,.010,.008)),eye_white,Vector3(side*.061,.025,-.142))
		_detail(root,"head",_ellipsoid(Vector3(.009,.011,.005)),dark,Vector3(side*.059,.025,-.15))
		var brow := _detail(root,"head",_box(Vector3(.048,.012,.009)),hair,Vector3(side*.063,.048,-.14)); brow.rotation.z = side*.11
		_detail(root,"head",_ellipsoid(Vector3(.026,.048,.024)),skin,Vector3(side*.143,-.011,.003))
	_detail(root,"head",_ellipsoid(Vector3(.025,.052,.031)),skin,Vector3(0,-.009,-.147))
	_detail(root,"head",_ellipsoid(Vector3(.035,.009,.009)),_material(Color(p["skin"]).darkened(.34).to_html()),Vector3(0,-.087,-.131))
	var cut := str(p["haircut"])
	var cap := _loft("hair:"+cut, [[.065,.142,.131],[.13,.141,.131],[.188 if cut in ["swept","fade"] else .174,.095,.10],[.204 if cut == "swept" else .18,.012,.015]])
	_detail(root,"head",cap,hair,Vector3(0,0,.013))
	if cut == "swept":
		for i in 3:
			var tuft := _detail(root,"head",_ellipsoid(Vector3(.036,.035,.065)),hair,Vector3(-.07+i*.046,.167,-.055+i*.018)); tuft.rotation.z = -.4
	if cut in ["bun","knot","braid"]:
		_detail(root,"head",_ellipsoid(Vector3(.061,.065,.06)),hair,Vector3(0,.12 if cut != "knot" else .20,.129))
		if cut == "braid":
			for i in 4: _detail(root,"head",_ellipsoid(Vector3(.029-i*.003,.033,.03)),hair,Vector3(.011*sin(i*PI*.5),.08-i*.047,.15))
	if world and root.get_meta("cast_key") == "PRIYA":
		for side in [-1.0,1.0]:
			for y in [.007,.05]: _detail(root,"head",_box(Vector3(.081,.009,.011)),dark,Vector3(side*.057,y,-.154))
			for x in [.015,.099]: _detail(root,"head",_box(Vector3(.009,.047,.011)),dark,Vector3(side*x,.029,-.154))
		_detail(root,"head",_box(Vector3(.031,.009,.014)),dark,Vector3(0,.032,-.155))

static func _crest(root: Node3D, p: Dictionary, trim: StandardMaterial3D) -> void:
	# North arrow and academy chevrons are modeled in source, legible in motion.
	var mark := _detail(root,"mesh",_box(Vector3(.012,.094,.018)),trim,Vector3(-.085,.075,.196))
	mark.rotation.z = -.42 if p["crest"] == "academy" else 0.0
	for side in [-1.0,1.0]:
		mark = _detail(root,"mesh",_box(Vector3(.012,.048,.018)),trim,Vector3(-.085+side*.013,.106,.20)); mark.rotation.z = side*.6
	for i in int(p["number"]):
		_detail(root,"mesh",_box(Vector3(.018,.11,.014)),trim,Vector3((i-(int(p["number"])-1)*.5)*.035,.035,-.21))

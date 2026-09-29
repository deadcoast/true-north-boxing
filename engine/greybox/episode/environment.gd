extends Node3D
## Authored episode dressing. No sim RNG, rewards, clocks or collision mutations.
## Existing cutaway walls and clear routes remain the navigation authority.
const View := preload("res://presentation/fight_view.gd")
const Support := preload("res://episode/supporting_cast.gd")
const V := preload("res://presentation/fighter_visuals.gd")
var world: Node3D
var venue: Node3D
var chairs: Array[Node3D] = []
var crew: Array[Node3D] = []
var bulbs: Array[MeshInstance3D] = []
var signs: Array[Label3D] = []
var room_light: OmniLight3D
var clock := 0.0
var stage_id := "world"
var materials := {}

func setup(owner: Node3D) -> void:
	world = owner; name = "AuthoredEnvironment"
	_gym(); _library(); _community(); _harbour(); _venue()
	stage("world")

func _mat(hex: String, metal := false) -> StandardMaterial3D:
	var key := hex + str(metal)
	if not materials.has(key):
		var material := StandardMaterial3D.new(); material.albedo_color = Color(hex)
		material.roughness = .86 if not metal else .48; material.metallic = .45 if metal else 0.0
		materials[key] = material
	return materials[key]

func _box(parent: Node3D, at: Vector3, size: Vector3, hex: String, metal := false) -> MeshInstance3D:
	var shape := BoxMesh.new(); shape.size = size
	return View._part(parent,shape,_mat(hex,metal),at)

func _cast_mesh(parent: Node3D, mesh: Mesh, hex: String, at: Vector3) -> void:
	var part := V.CastSurface.new(); part.mesh = mesh; part.set_surface_override_material(0,_mat(hex)); part.position = at; parent.add_child(part)

func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, hex: String) -> MeshInstance3D:
	var shape := CylinderMesh.new(); shape.top_radius = radius; shape.bottom_radius = radius; shape.height = 1; shape.radial_segments = 8
	var part := View._part(parent,shape,_mat(hex,true),Vector3.ZERO); View._link(part,a,b); return part

func _print(parent: Node3D, at: Vector3, en: String, fr: String, scale: float, ink := "d8d1b9") -> Label3D:
	var label := Label3D.new(); label.text = fr if world.language == "fr_CA" else en
	label.set_meta("en",en); label.set_meta("fr_CA",fr)
	label.position = at; label.font_size = 32; label.pixel_size = scale; label.outline_size = 0
	label.modulate = Color(ink); label.no_depth_test = false; parent.add_child(label); signs.append(label); return label

func _floor(at: Vector3, size: Vector3, tone: String, wood: bool) -> void:
	var node := _box(self,at,size,tone)
	var shader := Shader.new(); shader.code = """shader_type spatial;
uniform vec4 tone : source_color;
uniform bool wood;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p=local_point.xz;
 float grain=mix(hash(floor(p*vec2(48.0,16.0))),.5,clamp(length(fwidth(p))*24.0,0.0,1.0));
 float board=floor(p.y*2.2);
 float seam=smoothstep(0.015,0.025+fwidth(p.y)*2.2,fract(p.y*2.2));
 float ends=smoothstep(0.012,0.018+fwidth(p.x)*.26,fract(p.x*.26+hash(vec2(board,2.0))));
 float pattern=wood ? mix(0.38,0.83+hash(vec2(board,1.0))*.19,seam*ends) : .9+grain*.1;
 ALBEDO=tone.rgb*pattern*(.94+grain*.08); ROUGHNESS=.92;
}"""
	var material := ShaderMaterial.new(); material.shader = shader; material.set_shader_parameter("tone",Color(tone)); material.set_shader_parameter("wood",wood); node.material_override = material

func _gym() -> void:
	_floor(Vector3(0,.034,0),Vector3(14.4,.008,15.6),"86725c",true)
	# Worn two-tone plaster, skirting and radiators stay against existing walls.
	_box(self,Vector3(0,1.05,-7.72),Vector3(14.5,2.0,.04),"435957")
	_box(self,Vector3(0,3.0,-7.72),Vector3(14.5,1.7,.04),"a49f89")
	for side in [-1,1]:
		_box(self,Vector3(side*7.2,.65,0),Vector3(.04,1.25,15.5),"435957")
		_box(self,Vector3(side*7.14,.12,0),Vector3(.08,.18,15.5),"302f2e")
		for z in [-5,0,5]:
			# Glazed panes, mullions and deep sill replace the glowing flat squares.
			_box(self,Vector3(side*7.13,2,z),Vector3(.03,1.2,1.55),"9aacaa")
			for dz in [-.81,0,.81]: _box(self,Vector3(side*7.08,2,z+dz),Vector3(.06,1.35,.055),"39494c")
			_box(self,Vector3(side*7.07,2,z),Vector3(.07,.05,1.7),"39494c")
			_box(self,Vector3(side*7.04,1.35,z),Vector3(.24,.09,1.8),"9d9c89")
		for rib in 12: _box(self,Vector3(side*6.96,.54,-4.9+rib*.11),Vector3(.22,.67,.065),"7e8076",true)
	for x in [-4.8,0,4.8]:
		for z in [-3.5,3.5]:
			_rod(self,Vector3(x,3.55,z),Vector3(x,3.93,z),.018,"303b40")
			var shade := CylinderMesh.new(); shade.top_radius = .10; shade.bottom_radius = .33; shade.height = .17
			View._part(self,shade,_mat("3c4d50",true),Vector3(x,3.51,z))
			bulbs.append(_box(self,Vector3(x,3.415,z),Vector3(.26,.025,.26),"5e6463"))
	var live := _mat("ead6a0").duplicate() as StandardMaterial3D; live.emission_enabled = true; live.emission = Color("e5bd76"); live.emission_energy_multiplier = .8
	bulbs[2].material_override = live
	room_light = OmniLight3D.new(); room_light.position = bulbs[2].position-Vector3.UP*.15
	room_light.light_color = Color("ffe0ab"); room_light.light_energy = .35; room_light.omni_range = 7; room_light.shadow_enabled = true; add_child(room_light)
	# The old flip board is distinct from the mutable club planning board.
	_box(self,Vector3(4.9,2.88,-7.63),Vector3(3.1,1.18,.14),"333e42")
	_print(self,Vector3(4.9,3.24,-7.54),"MILLBROOK  ·  1976","MILLBROOK  ·  1976",.0025)
	for i in 2:
		_box(self,Vector3(4.25+i*1.3,2.81,-7.53),Vector3(1.1,.62,.045),"c6b993")
		_print(self,Vector3(4.25+i*1.3,2.81,-7.50),"5" if i == 0 else "4","5" if i == 0 else "4",.011,"343a3c")
		_box(self,Vector3(4.25+i*1.3,2.81,-7.47),Vector3(1.12,.014,.015),"5d6157")
	_print(self,Vector3(-3,3,-7.67),"MILLBROOK\nMEMORIAL","MILLBROOK\nMEMORIAL",.008,"374b50")
	for x in [4.1,4.8,5.5,6.2]:
		for row in 5: _box(self,Vector3(x,1.60-row*.085,-5.085),Vector3(.39,.022,.015),"354952")
	for x in [-4.8,-2.4,-1.2,1.2,2.4,4.8]: _box(self,Vector3(x,.26,-6.4),Vector3(.08,.48,.44),"343b3b",true)
	for z in [-1.8,-.4]:
		for dx in [-.15,.15]: _rod(self,Vector3(-6.5+dx,1.8,z),Vector3(-6.5,2.3,z),.012,"818a86")
		_box(self,Vector3(-6.5,1.44,z+.268),Vector3(.27,.14,.012),"c2ac7a")
	# Training corner: stool, bucket and towel, all outside the live canvas.
	_chair(self,Vector3(-5.3,0,1.4),-.2)
	var bucket := CylinderMesh.new(); bucket.top_radius = .17; bucket.bottom_radius = .13; bucket.height = .3
	View._part(self,bucket,_mat("8c9899",true),Vector3(-5.75,.15,1.5))
	_box(self,Vector3(-5.3,.52,1.25),Vector3(.32,.035,.6),"d1c7ac")
	for x in [4.3,5.7]:
		for z in [3.7,4.3]: _rod(self,Vector3(x,.05,z),Vector3(x,.74,z),.025,"555f5f")
	_box(self,Vector3(5,.88,4),Vector3(.8,.01,.55),"d5ceb4")
	_print(self,Vector3(5,1.45,4.4),"ASCENDANT B","ASCENDANT B",.0019).rotation.x = -PI*.5

func _library() -> void:
	_floor(Vector3(-30,.034,-24),Vector3(14.3,.008,15.5),"8b9185",false)
	for i in 3:
		for row in 4:
			for book in 10:
				var h := .27 + float((book*7+row*3+i)%5)*.025
				_box(self,Vector3(-36.5+i*2.8,.31+row*.48+h*.5,-30.78+book*.255),Vector3(.31,h,.18),["627b76","a08860","884e40","405969","c3b99d"][(book+row+i)%5])
	# Carrel sides, task lamp, chair, three distinct binders and tablet.
	for x in [-35.08,-32.92]:
		_box(self,Vector3(x,.48,-26),Vector3(.065,.72,1.1),"756044")
		_box(self,Vector3(x,1.07,-26),Vector3(.065,.43,1.1),"a49171")
	_box(self,Vector3(-34,1.07,-26.58),Vector3(2.2,.43,.06),"a49171")
	_chair(self,Vector3(-35.4,0,-24.9),-.25)
	for i in 3:
		_box(self,Vector3(-34.8+i*.25,1.08,-26.15),Vector3(.21,.42,.36),["446a7e","aa744e","638276"][i])
		_box(self,Vector3(-34.8+i*.25,1.12,-25.96),Vector3(.13,.13,.012),"d8d2b7")
	var tablet := _box(self,Vector3(-33.5,.89,-25.92),Vector3(.50,.035,.34),"29373d"); tablet.rotation.x = -.25
	_box(tablet,Vector3(0,.022,0),Vector3(.44,.009,.27),"5e969c")
	_rod(self,Vector3(-34.85,.88,-26.30),Vector3(-34.85,1.35,-26.30),.018,"485656")
	_box(self,Vector3(-34.72,1.35,-26.28),Vector3(.38,.06,.23),"7d846e")
	_box(self,Vector3(-30,2.8,-31.69),Vector3(5.7,.70,.04),"c2b58c")
	_print(self,Vector3(-30,2.8,-31.65),"LIBRARY  /  STUDY","BIBLIOTHÈQUE  /  ÉTUDE",.004,"354b52")

func _community() -> void:
	_floor(Vector3(30,.034,-24),Vector3(14.3,.008,15.5),"73938c",false)
	for x in [24.8,35.2]:
		var bag := CylinderMesh.new(); bag.top_radius = .26; bag.bottom_radius = .29; bag.height = 1.05
		View._part(self,bag,_mat("8b4a3d"),Vector3(x,1.45,-27.7))
		_rod(self,Vector3(x,1.98,-27.7),Vector3(x,3.1,-27.7),.016,"505e5b")
		_box(self,Vector3(x,3.1,-27.7),Vector3(.12,.12,1.5),"425856",true)
	_box(self,Vector3(30,2.75,-31.68),Vector3(6,.9,.05),"d1c79f")
	_print(self,Vector3(30,2.75,-31.64),"OPEN MAT\nALL STYLES · ALL LEVELS","ENTRAÎNEMENT LIBRE\nTOUS STYLES · TOUS NIVEAUX",.0035,"355955")
	for i in 4: _box(self,Vector3(34+i*.45,.27,-30.3),Vector3(.32,.5,.4),["8c9e91","b59a68"][i%2])

func _harbour() -> void:
	_floor(Vector3(0,.157,44),Vector3(10.8,.012,9.8),"786d59",true)
	for side in [-1,1]:
		for z in [41,45,48]:
			for h in [.55,.95]: _rod(self,Vector3(side*5,h,z),Vector3(side*5,h,minf(z+4,48)),.022,"b4a17c") if z < 48 else null
		for z in [41,45]:
			var rope := TorusMesh.new(); rope.inner_radius = .29; rope.outer_radius = .37; rope.rings = 24; rope.ring_segments = 6
			View._part(self,rope,_mat("a4936f"),Vector3(side*4.5,.21,z))
	for i in 4:
		_box(self,Vector3(-5.8+i*.78,.43,38),Vector3(.68,.76,.75),"746953")
		for edge in [-.28,.28]: _box(self,Vector3(-5.8+i*.78+edge,.43,38.39),Vector3(.05,.74,.025),"3c5558",true)
	_box(self,Vector3(0,2.8,39.68),Vector3(5,.9,.05),"d6d3b8")
	_print(self,Vector3(0,2.8,39.64),"HARBOURLINE\nWINTER SERVICE","HARBOURLINE\nSERVICE D’HIVER",.004,"304c5a").rotation.y = PI
	for x in [-6,6]:
		_rod(self,Vector3(x,0,36),Vector3(x,3.8,36),.08,"4d686f")
		_box(self,Vector3(x,3.65,36),Vector3(.70,.15,1.3),"758e8e")

func _chair(parent: Node3D, at: Vector3, facing: float) -> Node3D:
	var chair := Node3D.new(); parent.add_child(chair); chair.position = at; chair.rotation.y = facing
	_box(chair,Vector3(0,.45,0),Vector3(.48,.055,.43),"716f60")
	_box(chair,Vector3(0,.78,.20),Vector3(.48,.27,.045),"716f60")
	for x in [-.21,.21]:
		_rod(chair,Vector3(x,.04,-.23),Vector3(x,.93,.20),.018,"84918c")
		_rod(chair,Vector3(x,.04,.24),Vector3(x,.49,-.20),.018,"84918c")
	return chair

func _venue() -> void:
	venue = Node3D.new(); venue.name = "SurvivalVenue"; add_child(venue)
	# Forty seated local spectators, arranged behind the ring's camera corridor.
	# Shared low-detail meshes/materials keep this crowd cheaper than hero rigs.
	world.spectators = Node3D.new(); world.spectators.name = "SeatedAudience"; add_child(world.spectators)
	for i in 40:
		var side := -1.0 if i < 20 else 1.0
		var at := Vector3(side*(5.8+float((i%20)/10)*.65),0,-4.5+(i%10)*.85)
		var facing := side*PI*.5
		chairs.append(_chair(venue,at,facing))
		var spectator := Node3D.new(); world.spectators.add_child(spectator); spectator.position = at; spectator.rotation.y = facing
		var coat: String = ["504a47","536a70","657566","84694b","6b5357"][i%5]
		var skin: String = ["b79175","caa987","8e6957","dcc2a4"][i%4]
		_cast_mesh(spectator,V._loft("audience-coat",[[.45,.19,.14],[.8,.22,.16],[1.04,.23,.14],[1.09,.11,.07]]),coat,Vector3.ZERO)
		_cast_mesh(spectator,V._ellipsoid(Vector3(.13,.17,.13)),skin,Vector3(0,1.26,0))
		_cast_mesh(spectator,V._loft("audience-hat",[[.0,.134,.134],[.12,.11,.11],[.16,.01,.01]]),coat,Vector3(0,1.28,0))
		for x in [-.15,.15]:
			_rod(spectator,Vector3(x,.47,0),Vector3(x,.41,-.35),.085,"354047")
			_rod(spectator,Vector3(x,.41,-.35),Vector3(x,.07,-.42),.065,"354047")
			_box(spectator,Vector3(x,.065,-.47),Vector3(.15,.10,.26),"29353d")
			_rod(spectator,Vector3(x*1.5,.97,0),Vector3(x*1.6,.68,-.15),.063,coat)
			_rod(spectator,Vector3(x*1.6,.68,-.15),Vector3(x,.64,-.34),.05,coat)
			_cast_mesh(spectator,V._ellipsoid(Vector3(.05,.04,.06)),skin,Vector3(x,.64,-.35))
	# Official and broadcast pair on the far apron. Nothing enters the canvas.
	for entry in [["OBSERVER",Vector3(-4.7,0,-5.65)],["GORD",Vector3(.7,0,-5.8)],["DANIELLE",Vector3(1.8,0,-5.8)]]:
		var person := View.make_fighter(venue,Color.WHITE,entry[1]); Support.apply(person,entry[0]); person.rotation.y = PI; Support.seated(person,0); crew.append(person)
		_chair(venue,entry[1],PI)
	_box(venue,Vector3(1.25,.70,-5.13),Vector3(2.4,.09,.65),"655d4b")
	for x in [.25,2.25]: _box(venue,Vector3(x,.35,-5.13),Vector3(.055,.7,.5),"3b5056",true)
	for x in [.7,1.8]: _box(venue,Vector3(x,.77,-5.1),Vector3(.35,.015,.25),"d4cdb6")
	var clip := _box(crew[0],Vector3(0,.71,-.38),Vector3(.33,.025,.42),"b1a17d"); clip.rotation.x = -.3
	_box(clip,Vector3(0,.02,0),Vector3(.29,.007,.36),"ded8bf")
	_box(clip,Vector3(0,.029,-.14),Vector3(.14,.012,.04),"677a7d",true)
	var watch := CylinderMesh.new(); watch.top_radius = .047; watch.bottom_radius = .047; watch.height = .018
	View._part(crew[0],watch,_mat("c7c7b5",true),Vector3(.19,.72,-.35))
	for side in [-1,1]:
		var at := Vector3(side*4.7,0,-3.8)
		for leg in 3:
			var angle := leg*TAU/3
			_rod(venue,at+Vector3(sin(angle)*.38,.03,cos(angle)*.38),at+Vector3.UP*1.40,.022,"323e46")
		var cam := _box(venue,at+Vector3.UP*1.51,Vector3(.27,.23,.48),"293943"); cam.rotation.y = side*.6
		_box(cam,Vector3(0,0,.3),Vector3(.18,.18,.18),"151e26")

func stage(id: String) -> void:
	stage_id = id; venue.visible = id in ["archive","survival","tag"]
	world.spectators.visible = id in ["archive","survival"]
	for person in crew: person.visible = id == "survival"
	# Post-dual chairs really are half-stacked; the archive has no modern cameras.
	for child in venue.get_children():
		if child not in chairs and child not in crew: child.visible = id != "archive"
	for i in chairs.size():
		var side := -1.0 if i < 20 else 1.0
		chairs[i].position = Vector3(side*(5.8+float((i%20)/10)*.65),0,-4.5+(i%10)*.85)
		if id == "tag" and i%2 == 0: chairs[i].position = Vector3(side*6.6,.11*float((i%20)/2),-4.8)
	room_light.light_energy = .65 if id in ["archive","survival"] else .35
	for label in signs: label.text = str(label.get_meta(world.language))

func frame(delta: float) -> void:
	clock += delta
	if stage_id == "survival":
		for i in crew.size(): Support.seated(crew[i],clock+float(i)*2)

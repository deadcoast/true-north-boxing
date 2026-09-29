extends RefCounted
## Civilian clothing follows the same articulated anchors as the world cast.
## Colours/faces are implementation art; only roles and wardrobe are authored.
const V := preload("res://presentation/fighter_visuals.gd")
const View := preload("res://presentation/fight_view.gd")
const PROFILES := {
	"WHITLOCK": ["c7b09b", "d6d2c5", "374b46", "292e39", "b8a582", "crop"],
	"VEY": ["cba78d", "4b4341", "272e3c", "272936", "9ca3a0", "swept"],
	"OBSERVER": ["a47a62", "343039", "535f63", "343b46", "d1c8a6", "crop"],
	"GORD": ["d3ab8a", "827769", "725745", "323b46", "d7caaa", "swept"],
	"DANIELLE": ["bb896f", "32292c", "476673", "303b49", "e3c9a3", "bun"]
}

static func apply(person: Node3D, name: String) -> bool:
	if not PROFILES.has(name): return false
	if person.get_meta("support_key", "") == name: return true
	var p: Array = PROFILES[name]
	person.set_meta("cast_parts", []); person.set_meta("cast_body", [])
	person.set_meta("support_key", name); person.set_meta("cast_key", name)
	for key in V.ANCHORS:
		var anchors = person.get_meta(key)
		for anchor in anchors if anchors is Array else [anchors]: anchor.layers = 0
	var skin := V._material(p[0]); var coat := V._material(p[2]); var trousers := V._material(p[3]); var trim := V._material(p[4])
	var dark := V._material("252c33")
	# The torso's +Z chest becomes world -Z in harbourline._pose.
	V._surface(person, "mesh", V._loft("civil-torso", [[-.32,.22,.19],[-.12,.23,.20],[.19,.27,.21],[.30,.19,.12]]), coat)
	V._surface(person, "hips", V._loft("civil-hips", [[-.14,.22,.17],[.14,.20,.15]]), trousers)
	V._surface(person, "abdomen", V._loft("civil-waist", [[-.5,.21,.15],[.5,.21,.15]]), coat)
	V._surface(person, "neck", V._loft("civil-neck", [[-.5,.08,.075],[.5,.08,.075]]), skin)
	V._surface(person, "head", V._loft("civil-head", [[-.18,.05,.06],[-.13,.105,.112],[-.02,.143,.147],[.09,.14,.14],[.17,.04,.04]]), skin)
	V._face(person, {"skin":p[0], "haircut":p[5]}, skin, V._material(p[1]), trim, false)
	# Open parka, lapels and shirt remain visible in the letter close-up.
	V._detail(person,"mesh",V._box(Vector3(.19,.44,.022)),trousers,Vector3(0,.015,.207))
	V._detail(person,"mesh",V._box(Vector3(.095,.17,.027)),trim,Vector3(0,.18,.222))
	for side in [-1.0,1.0]:
		var lapel := V._detail(person,"mesh",V._box(Vector3(.058,.25,.035)),coat,Vector3(side*.09,.11,.227)); lapel.rotation.z = side*.25
		V._detail(person,"mesh",V._box(Vector3(.095,.065,.023)),coat,Vector3(side*.15,-.16,.196))
	for y in [-.20,-.08,.04]: V._detail(person,"mesh",V._ellipsoid(Vector3(.014,.014,.01)),trim,Vector3(.03,y,.236))
	if name == "WHITLOCK":
		for side in [-1.0,1.0]:
			V._detail(person,"head",V._box(Vector3(.055,.006,.005)),trim,Vector3(side*.079,-.018,-.146))
	if name == "VEY":
		V._surface(person,"hips",V._loft("vey-coat-tail", [[-.40,.26,.195],[.12,.23,.185]]),coat)
	if name == "OBSERVER":
		V._detail(person,"mesh",V._box(Vector3(.07,.11,.012)),trim,Vector3(-.13,.08,.222))
	if name in ["GORD","DANIELLE"]:
		var headset := TorusMesh.new(); headset.inner_radius = .168; headset.outer_radius = .18; headset.rings = 24; headset.ring_segments = 6
		var band := V._detail(person,"head",headset,dark,Vector3(0,.03,0)); band.rotation.x = PI*.5
		for side in [-1.0,1.0]: V._detail(person,"head",V._ellipsoid(Vector3(.036,.055,.046)),dark,Vector3(side*.155,0,0))
		V._detail(person,"head",V._box(Vector3(.016,.016,.13)),dark,Vector3(.13,-.065,-.09))
	for i in 2:
		V._surface(person,"clavicles",V._loft("civil-clavicle",[[-.5,.10,.09],[.5,.10,.09]]),coat,i)
		V._surface(person,"upper_arms",V._loft("civil-sleeve",[[-.55,.10,.10],[.1,.085,.085],[.55,.075,.075]]),coat,i)
		V._surface(person,"arms",V._loft("civil-cuff",[[-.55,.078,.078],[.55,.058,.058]]),coat,i)
		V._surface(person,"thighs",V._loft("civil-thigh",[[-.55,.115,.12],[.55,.085,.09]]),trousers,i)
		V._surface(person,"legs",V._loft("civil-calf",[[-.55,.09,.095],[.55,.065,.065]]),trousers,i)
		V._surface(person,"boots",V._loft("civil-shoe",[[-.06,.084,.15,.04],[.04,.085,.15,.04],[.10,.06,.065,0]]),dark,i)
		# Bare palm, curled fingers and separate thumb, not a boxing glove.
		V._surface(person,"gloves",V._ellipsoid(Vector3(.062,.075,.032)),skin,i)
		for finger in 4: V._detail(person,"gloves",V._ellipsoid(Vector3(.012,.045,.015)),skin,Vector3(-.042+finger*.027,-.075,-.005),i)
		V._detail(person,"gloves",V._ellipsoid(Vector3(.022,.045,.025)),skin,Vector3(.066 if i == 0 else -.066,-.01,.01),i)
	return true

static func seated(person: Node3D, phase: float) -> void:
	# Ringside listening pose. Presentation time is supplied by the paused director.
	person.get_meta("head").position = Vector3(0,1.25,0)
	person.get_meta("head").rotation.y = sin(phase*.27)*.10
	person.get_meta("mesh").position = Vector3(0,.83,0); person.get_meta("mesh").rotation.y = PI
	person.get_meta("hips").position = Vector3(0,.47,0)
	View._link(person.get_meta("abdomen"),Vector3(0,.48,0),Vector3(0,.70,0))
	View._link(person.get_meta("neck"),Vector3(0,1.09,0),Vector3(0,1.14,0))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := Vector3(side*.25,1.04,0)
		var elbow := Vector3(side*.28,.77,-.12)
		var hand := Vector3(side*.19,.69,-.35)
		View._link(person.get_meta("clavicles")[i],Vector3(0,1.04,0),shoulder)
		View._link(person.get_meta("upper_arms")[i],shoulder,elbow); View._link(person.get_meta("arms")[i],elbow,hand)
		person.get_meta("gloves")[i].position = hand
		View._link(person.get_meta("thighs")[i],Vector3(side*.16,.49,0),Vector3(side*.19,.43,-.38))
		View._link(person.get_meta("legs")[i],Vector3(side*.19,.43,-.38),Vector3(side*.19,.065,-.45))
		person.get_meta("boots")[i].position = Vector3(side*.19,.065,-.45); person.get_meta("boots")[i].rotation.y = PI

extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_fighter_visuals.gd -- episode
## Cast/mesh integration fixtures. Full earned journey lives in drive_episode;
## sustained native input and mechanical animation live in drive_readiness.
const Visuals := preload("res://presentation/fighter_visuals.gd")
const View := preload("res://presentation/fight_view.gd")
const Tests := preload("res://sim/tests.gd")
const Sim := preload("res://sim/core.gd")
const Campaign := preload("res://episode/campaign.gd")
const Space := preload("res://presentation/rig_space.gd")
var scene: Node
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var performance: Array = []
var surface_samples: Array = []
var tests := Tests.new()

func _initialize() -> void: _run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])

func _capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	await process_frame; await RenderingServer.frame_post_draw
	var path := "user://cast-"+label+".png"
	_check("rendered " + label, root.get_texture().get_image().save_png(path) == OK); captures.append(path)

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = down; root.push_input(event)

func _measure() -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	var frames: Array = []; var cpu: Array = []
	for frame in 210:
		var started := Time.get_ticks_usec(); scene._process(1.0/60)
		var elapsed := (Time.get_ticks_usec()-started)/1000.0
		await process_frame; await RenderingServer.frame_post_draw
		if frame >= 30:
			frames.append((Time.get_ticks_usec()-started)/1000.0); cpu.append(elapsed)
	frames.sort(); cpu.sort()
	performance.append({"scene":"rory-cassidy-native-models","frames":180,"render_interval_ms_p95":frames[171],"main_process_ms_p95":cpu[171],"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"method":"Controlled native scene, 30 warm-up frames and 180 measured render frames; 1/60 simulation step per frame. Workstation render throughput, not physical latency or minimum-spec qualification."})

func _body_surface(actor: Node3D, defender: Dictionary, attacker: Dictionary, label: String) -> void:
	var region: Dictionary = scene.sim.contact_region(attacker,defender,"L_STRAIGHT",true)
	var center := actor.global_position + Space.ground(region["target"]-defender["pos"]) + Vector3.UP*float(region["h"])
	var torso: MeshInstance3D = actor.get_meta("cast_parts")[0]
	var faces: PackedVector3Array = torso.mesh.get_faces()
	var error := 0.0; var found := 0
	for angle in 8:
		var ray := center + Vector3(sin(angle*PI/4),0,cos(angle*PI/4))*.5
		var radius := -1.0
		for vertex in range(0,faces.size(),3):
			var hit = Geometry3D.segment_intersects_triangle(ray,center,torso.to_global(faces[vertex]),torso.to_global(faces[vertex+1]),torso.to_global(faces[vertex+2]))
			if hit != null: radius = maxf(radius,(hit as Vector3).distance_to(center))
		if radius >= 0: found += 1; error = maxf(error,absf(radius-Space.BODY_RADIUS))
	surface_samples.append({"pose":label,"rays":found,"worst_surface_error_m":error})
	_check("rendered torso meets physical striking region " + label,found == 8 and error < .025)

func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	scene.club_flow.set_process(false); await process_frame
	_check("automated audio is silent", AudioServer.get_driver_name() == "Dummy" and AudioServer.is_bus_mute(0))
	var ep: Node = scene.episode
	ep.new_episode("en"); ep._world(); scene._process(1.0/60)
	_check("world Rory has authored body", ep.world.actor.get_meta("cast_key") == "RORY")
	for member in ep.world.squad:
		_check("world squad uses cast appearance", member.get_meta("cast_key", "") in ["PRIYA","MARCUS","JUNE"])
	await _capture("gym")
	# A mesh review lineup uses production geometry and the world's resting pose.
	# This isolated composition is explicitly separate from combat captures below.
	var gallery := Node3D.new(); scene.add_child(gallery)
	var names := ["RORY","PRIYA","MARCUS","JUNE","cassidy_vane","ASCENDANT · SEEDED OUT-BOXER","ASCENDANT · R2"]
	for i in names.size():
		var fighter := View.make_fighter(gallery,Color.WHITE,Vector3((i-3)*1.05,0,0))
		_check("cast resolves " + names[i], Visuals.apply(fighter,names[i],true))
		ep.world._pose(fighter,0,0)
		_check("legacy collision proxies hidden " + names[i], fighter.get_meta("head").layers == 0 and fighter.get_meta("mesh").layers == 0)
		_check("authored surfaces share moving anchors " + names[i], fighter.get_meta("cast_parts").size() > 60 and fighter.get_meta("cast_parts").all(func(p): return p.get_parent() != fighter and p.mesh.get_surface_count() == 1))
		var arrays: Array = fighter.get_meta("cast_parts")[0].mesh.surface_get_arrays(0)
		var rightmost := 0
		for vertex in arrays[Mesh.ARRAY_VERTEX].size():
			if arrays[Mesh.ARRAY_VERTEX][vertex].x > arrays[Mesh.ARRAY_VERTEX][rightmost].x: rightmost = vertex
		_check("torso faces outward " + names[i], arrays[Mesh.ARRAY_NORMAL][rightmost].x > .5)
		var count: int = fighter.get_meta("cast_parts").size()
		Visuals.apply(fighter,names[i],true)
		_check("unchanged identity retains mesh instances " + names[i], fighter.get_meta("cast_parts").size() == count)
	# Place lineup in the existing lit ring, without overlays hiding its feet.
	ep.world.hide(); ep.hide(); scene.player.hide(); scene.boss.hide()
	scene.get_meta("arena").show()
	for child in scene.get_children():
		if child is CanvasLayer: child.hide()
	scene.cam.current = true; scene.cam.position = Vector3(0,2.9,-7.5); scene.cam.look_at(Vector3(0,1,0))
	await _capture("lineup")
	for i in names.size():
		var fighter: Node3D = gallery.get_child(i)
		scene.cam.position = fighter.position + Vector3(-.65,1.68,-1.85); scene.cam.look_at(fighter.position + Vector3(0,1.24,0))
		await _capture("portrait-"+str(i))
	gallery.queue_free(); await process_frame
	for child in scene.get_children():
		if child is CanvasLayer and child != ep and child != scene.club_flow: child.show()
	ep.active = false; scene.player.show(); scene.boss.show(); scene.set_practice(false)
	for index in 4:
		var cards: Array = Sim.LINEUP_MILLBROOK.duplicate(true)
		var first: Dictionary = cards.pop_at(index); first.erase("reserve"); cards.push_front(first)
		scene.sim = tests.make_sim(0,731,cards); tests.quiet(scene.sim); tests.place(scene.sim,1.4)
		scene.clock.acc = 0; scene.combat_input.clear(); scene.fight_view.clock_sim = null
		scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
		scene._render(1); scene.fight_hud.dismiss_entry(); scene._hud()
		var before: int = scene.sim.hash_state()
		for alpha in [0.0,.25,.5,.75,1.0]: scene._render(alpha)
		_check("rendering cannot change combat " + str(first["name"]), scene.sim.hash_state() == before)
		_check("native roster selects player model " + str(first["name"]), scene.player.get_meta("cast_key") == Visuals.identity(first["name"]))
		_check("native pattern selects Cassidy", scene.boss.get_meta("cast_key") == "CASSIDY")
		_body_surface(scene.player,scene.sim.P,scene.sim.B,str(first["name"])+"-neutral")
		_body_surface(scene.boss,scene.sim.B,scene.sim.P,"cassidy-"+str(index))
		_check("head faces opponent", (-scene.boss.get_meta("head").basis.z).dot((scene.player.position-scene.boss.position).normalized()) > .99)
		_check("all player body details respect clear window", scene.player.get_meta("cast_body").all(func(p): return p.material_override is ShaderMaterial and is_equal_approx(p.material_override.get_shader_parameter("tint").a,.4)))
		var colors_match := true
		for part in scene.player.get_meta("cast_body"):
			var tint: Color = part.material_override.get_shader_parameter("tint")
			var source: Color = part.get_surface_override_material(0).albedo_color
			colors_match = colors_match and Vector3(tint.r,tint.g,tint.b).is_equal_approx(Vector3(source.r,source.g,source.b))
		_check("visibility keeps every skin hair and kit color",colors_match)
		var start: Transform3D = scene.player.get_meta("gloves")[1].transform
		_key(KEY_K,true)
		for tick in 10: scene._process(1.0/60)
		_check("native right hand animates attached model", scene.player.get_meta("gloves")[1].transform != start and scene.player.get_meta("cast_parts").all(func(p): return p.global_transform.origin.is_finite()))
		_body_surface(scene.player,scene.sim.P,scene.sim.B,str(first["name"])+"-punch")
		await _capture("fight-"+str(first["name"]))
		_key(KEY_K,false)
		for tick in 24: scene._process(1.0/60)
		_key(KEY_V,true)
		for tick in 9: scene._process(1.0/60)
		_body_surface(scene.player,scene.sim.P,scene.sim.B,str(first["name"])+"-duck")
		await _capture("duck-"+str(first["name"]))
		_key(KEY_V,false)
		for tick in 24: scene._process(1.0/60)
		if index == 0: await _measure()
	# Real generic-slot identities must replace Cassidy on the shared enemy node.
	for pair in [["ascendant_seed","OUTBOXER","ASCENDANT · SEEDED OUT-BOXER","ASCENDANT_SEED"],["ascendant_r2","SLUGGER","ASCENDANT · R2","ASCENDANT_R2"]]:
		var spec: Dictionary = scene.sim.generic_spec(pair[0],pair[1],"cassidy_vane",1,1976,pair[2])
		scene.sim.set_generic_slot(0,spec); scene.sim.new_dual(); scene._render(1)
		_check("generic segment replaces opponent geometry " + pair[0], scene.boss.get_meta("cast_key") == pair[3])
		_body_surface(scene.boss,scene.sim.B,scene.sim.P,pair[0])
		await _capture(pair[0])
	Visuals.apply(scene.boss,"YURI")
	_check("other roster restores original rig", scene.boss.get_meta("cast_parts").is_empty() and scene.boss.get_meta("head").layers == 1)
	ep.active = true; ep.new_episode("en"); scene.sim = Campaign.present(scene.content,scene.sim)
	ep._ep()["dialogue"] = ""; ep._training("shadow",true); ep.transition_t = 0
	for tick in 30: scene._process(1.0/60)
	_check("shadow keeps Rory appearance", ep.world.actor.get_meta("cast_key") == scene.player.get_meta("cast_key") and scene.player.get_meta("cast_key") == "RORY")
	_check("shadow copies animated head to world actor", ep.world.actor.get_meta("head").transform.is_equal_approx(scene.player.get_meta("head").transform))
	ep._world(); scene._process(1.0/60)
	_check("world resets face after boxing handoff", ep.world.actor.get_meta("head").rotation.is_equal_approx(Vector3.ZERO))
	_check("Master remains muted", AudioServer.is_bus_mute(0))
	var file := FileAccess.open("user://fighter-visuals.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"performance":performance,"surface_samples":surface_samples,"scope":"Original source-native cast meshes; native input in controlled fight fixtures, real roster/generic-slot resolution, world/shadow continuity and opponent visibility. Not final art direction or boxing-feel acceptance."},"  ")); file.close()
	print("FIGHTER VISUALS ",checks," checks; ",failures.size()," failures")
	print("DRIVE :: GREEN" if failures.is_empty() else "DRIVE :: RED")
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

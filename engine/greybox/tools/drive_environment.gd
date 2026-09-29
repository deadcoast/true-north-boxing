extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_environment.gd -- episode
## Presentation fixtures and native traversal. drive_episode earns progression.
const Campaign := preload("res://episode/campaign.gd")
const Tests := preload("res://sim/tests.gd")
var scene: Node
var ep: Node
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var performance: Array = []
var keys := {}

func _initialize() -> void: _run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])

func _held(wanted: Array) -> void:
	for key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SHIFT]:
		var down: bool = key in wanted
		if bool(keys.get(key,false)) == down: continue
		keys[key] = down
		var event := InputEventKey.new(); event.keycode = key; event.pressed = down; root.push_input(event)

func _walk(to: Vector2) -> void:
	for i in 1600:
		var delta: Vector2 = to-Vector2(ep.world.actor.position.x,ep.world.actor.position.z)
		if delta.length() < .18: break
		var wanted := [KEY_SHIFT]
		if absf(delta.x) > .10: wanted.append(KEY_D if delta.x > 0 else KEY_A)
		if absf(delta.y) > .10: wanted.append(KEY_S if delta.y > 0 else KEY_W)
		_held(wanted); scene._process(1.0/60)
	_held([])
	for i in 12: scene._process(1.0/60)
	_check("native walk reaches " + str(to),Vector2(ep.world.actor.position.x,ep.world.actor.position.z).distance_to(to) < .5)

func _capture(label: String) -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	await process_frame; await RenderingServer.frame_post_draw
	var path := "user://environment-"+label+".png"
	_check("rendered " + label,root.get_texture().get_image().save_png(path) == OK); captures.append(path)

func _measure() -> void:
	if not "capture" in OS.get_cmdline_user_args(): return
	var samples: Array = []; var work: Array = []
	for i in 210:
		var start := Time.get_ticks_usec(); scene._process(1.0/60)
		var cpu := (Time.get_ticks_usec()-start)/1000.0
		await process_frame; await RenderingServer.frame_post_draw
		if i >= 30: samples.append((Time.get_ticks_usec()-start)/1000.0); work.append(cpu)
	samples.sort(); work.sort()
	performance.append({"scene":"survival-with-seated-audience-and-crew","frames":180,"render_interval_ms_p95":samples[171],"main_process_ms_p95":work[171],"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"method":"Quiet combat fixture, 30 warmup frames and 180 measured real render intervals. Not human feel, minimum-spec or physical latency acceptance."})

func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false); scene.club_flow.set_process(false)
	ep = scene.episode; await process_frame
	_check("automated audio remains silent",AudioServer.get_driver_name() == "Dummy" and AudioServer.is_bus_mute(0))
	ep.new_episode("en"); scene.sim = Campaign.present(scene.content,scene.sim); ep._world(); ep.transition_t = 0
	await _capture("gym")
	for name in ["WHITLOCK"]:
		var person: Node3D = ep.world.cast[name]
		_check("civilian hides every original primitive " + name,person.get_meta("mesh").layers == 0 and person.get_meta("gloves")[0].layers == 0)
		_check("civilian geometry follows moving anchors " + name,person.get_meta("cast_parts").all(func(p): return p.get_parent() != person and p.global_transform.origin.is_finite()))
	var art: Node = ep.world.dressing
	_check("cold gym has six fixtures and one emissive bulb",art.bulbs.size() == 6 and art.bulbs.filter(func(b): return b.material_override != null and b.material_override.emission_enabled).size() == 1)
	var before: int = scene.sim.hash_state()
	for i in 60: art.frame(1.0/60)
	_check("dressing cannot advance simulation",scene.sim.hash_state() == before)
	# Existing roads and front entrances; no teleport during this traversal.
	for point in [Vector2(0,10),Vector2(11,10),Vector2(11,-14),Vector2(-30,-14),Vector2(-30,-24),Vector2(-34,-24)]: await _walk(point)
	_check("library can be approached and interacted with",ep.world.nearest == "priya")
	await _capture("library")
	for point in [Vector2(-30,-24),Vector2(-30,-14),Vector2(30,-14),Vector2(30,-22)]: await _walk(point)
	await _capture("community")
	for point in [Vector2(30,-14),Vector2(11,-14),Vector2(11,18),Vector2(0,18),Vector2(0,32),Vector2(4,34)]: await _walk(point)
	_check("harbour departures remain reachable",ep.world.nearest == "transit")
	await _capture("harbour")
	# Independently composed views of physical dressing, not progression evidence.
	for shot in [["library-detail",Vector3(-31.8,2.7,-22.7),Vector3(-34,1,-26)],["harbour-deck",Vector3(10,7,53),Vector3(0,.5,43)]]:
		ep.world.camera.position = shot[1]; ep.world.camera.look_at(shot[2]); await _capture(shot[0])
	ep.world.stage("survival")
	_check("forty seated people and forty chairs",ep.world.spectators.get_child_count() == 40 and art.chairs.size() == 40)
	_check("all three ringside roles are present",art.crew.size() == 3 and art.crew.all(func(p): return p.is_visible_in_tree()))
	ep.world.camera.position = Vector3(9,7,11); ep.world.camera.look_at(Vector3(0,1,0)); await _capture("survival-venue")
	ep.world.camera.position = Vector3(-1,2.3,-2.8); ep.world.camera.look_at(Vector3(1.2,1,-5.7)); await _capture("broadcast-crew")
	ep.world.stage("archive")
	_check("archive hides modern ringside roles",art.crew.all(func(p): return not p.is_visible_in_tree()))
	ep.world.stage("tag")
	_check("later venue removes crowd and stacks half the chairs",not ep.world.spectators.visible and art.chairs.filter(func(c): return c.position.y > 0).size() == 18)
	ep.world.stage("world")
	_check("world restores empty gym and hides venue",not art.venue.visible and not ep.world.spectators.visible)
	for language in ["en","fr_CA"]:
		ep.world.language = language; art.stage("world")
		_check("physical sign language " + language,art.signs.all(func(s): return s.text == str(s.get_meta(language))))
	# Sustained native combat with the actual venue behind it.
	ep.active = false; ep.world.position = Vector3.ZERO; ep.world.stage("survival")
	ep.world.actor.hide(); ep.panel.hide(); ep.quest.hide(); ep.hint.hide()
	for p in ep.world.cast.values(): p.hide()
	var tests := Tests.new(); scene.sim = tests.make_sim(0,204); tests.quiet(scene.sim); tests.place(scene.sim,1.4)
	scene.fight_view.clock_sim = null; scene.clock.acc = 0; scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.player.show(); scene.boss.show(); scene.get_meta("arena").show(); scene.cam.make_current(); scene.fight_hud.show(); scene.begin_fight(false)
	scene._render(1); scene._hud(); await _capture("survival-fight"); await _measure()
	var file := FileAccess.open("user://environment-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"performance":performance,"boundary":"Presentation fixtures and native traversal; drive_episode independently earns the episode. Full-demo and boxing-feel acceptance remain open."},"  "))
	print("ENVIRONMENT %d checks; %d failures" % [checks,failures.size()]); print("DRIVE :: " + ("GREEN" if failures.is_empty() else "RED")); quit(0 if failures.is_empty() else 1)

extends SceneTree
## Head/neck coordination must exist in the shared collision pose and renderer.
const Tests := preload("res://sim/tests.gd")
const Space := preload("res://presentation/rig_space.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var samples := []
var scene: Node
var emitted := []
var frames := 0

func _initialize() -> void: run.call_deferred()
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s"%["PASS" if ok else "FAIL",label])

func fresh(distance := 1.5):
	var s=tests.make_sim(0,281)
	tests.quiet(s); tests.place(s,distance)
	s.bstate="ACTING";s.bqueue=[];s.btimer=100000
	s.P["boxing_training"]={};s.B["boxing_training"]={}
	s.step({"body_axis":Vector2.ZERO});s.events.clear()
	return s

func tick(s, intent := {}) -> void:
	s.events.clear(); s.step({"body_axis":Vector2.ZERO}.merged(intent,true))
	emitted=s.events.duplicate(true)
	scene.sim=s;scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"]
	scene._consume_events();scene._render(1)

func head_forward(actor: Node3D) -> Vector3:
	return -actor.get_meta("head").basis.z.normalized()

func run() -> void:
	root.size=Vector2i(1280,720)
	if "capture" in OS.get_cmdline_user_args(): RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	await process_frame;await process_frame;scene.controls_menu.close();scene.fight_hud.entry.hide()
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for who in ["P","B"]:
			for kind in ["SLIP","DUCK","LEAN","WEAVE"]:
				var s=fresh();var fighter: Dictionary=s.P if who=="P" else s.B
				fighter["style"]=style
				var actor: Node3D=scene.player if who=="P" else scene.boss
				tick(s)
				var before: Vector3=actor.get_meta("head").basis.y.normalized()
				var start: Vector3=fighter["boxing"]["rig"]["head"]
				s._set_dodge(fighter,kind,1)
				var rotation:=0.0;var travel:=0.0;var agrees:=true;var neck:=0.0
				for i in 95:
					tick(s)
					var rig: Dictionary=fighter["boxing"]["rig"]
					rotation=maxf(rotation,before.angle_to(actor.get_meta("head").basis.y.normalized()))
					travel=maxf(travel,start.distance_to(rig["head"]))
					var world: Vector3=Space.ground(fighter["pos"])+Vector3(rig["head"])
					var queried: Dictionary=s._head_world(fighter,s.B if who=="P" else s.P)
					agrees=agrees and actor.get_meta("head").position.distance_to(rig["head"])<0.00001 and world.distance_to(fighter["boxing"]["volumes"][0]["a"])<0.00001 and world.distance_to(Space.ground(queried["p"])+Vector3.UP*float(queried["h"]))<0.00001
					neck=maxf(neck,(Vector3(rig["head"])-Vector3(rig["head_up"])*0.12-(rig["shoulders"][0]+rig["shoulders"][1])*0.5).length())
				var label: String=style+" "+who+" "+kind
				check(label+" rotates the head with body defense",rotation>deg_to_rad(4))
				check(label+" actually displaces its head target",travel>0.10)
				check(label+" shares rendered, queried and colliding head",agrees)
				check(label+" keeps the neck at its fixed anatomical length",absf(neck-0.15)<0.001)
				samples.append({"case":label,"rotation_degrees":rad_to_deg(rotation),"travel_m":travel,"neck_span_m":neck})
	for who in ["P","B"]:
		var s=fresh();var defender: Dictionary=s.B if who=="P" else s.P
		defender["guard_body"]=true;defender["guard_t"]=500
		for i in 35:tick(s,{"block":true,"body":true} if who=="B" else {})
		if who=="P":tick(s,{"punch":"R_STRAIGHT"})
		else:s.btimer=s._boss_act({"kind":"punch","row":"R_STRAIGHT","mult":1.0,"body":false})
		var landed:=false;var reacted:=false;var peak:=0.0;var origin:=Vector3.ZERO
		for i in 150:
			tick(s,{"block":true,"body":true} if who=="B" else {})
			for e in emitted:
				if e.get("kind")=="hit" and e.get("on")==("B" if who=="P" else "P"):
					landed=true;origin=defender["boxing"]["rig"]["head"]
			if landed:peak=maxf(peak,origin.distance_to(defender["boxing"]["rig"]["head"]))
			reacted=reacted or not defender["boxing"].get("impacts",[]).is_empty()
		check(who+" clean head contact creates a physical head reaction",landed and reacted and peak>0.025)
		check(who+" head reaction recovers without a permanent offset",defender["boxing"].get("impacts",[]).is_empty())
		samples.append({"case":who+" clean head hit","landed":landed,"peak_head_reaction_m":peak})
	for who in ["P","B"]:
		for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_HOOK","L_UPPERCUT","R_UPPERCUT"]:
			var s=fresh(2.5);var fighter: Dictionary=s.P if who=="P" else s.B
			tick(s)
			var start: Vector3=fighter["boxing"]["rig"]["head"]
			var up: Vector3=fighter["boxing"]["rig"].get("head_up",Vector3.UP)
			if who=="P":tick(s,{"punch":row})
			else:s.btimer=s._boss_act({"kind":"punch","row":row,"mult":1.0,"body":false})
			var distance:=0.0;var angle:=0.0
			for i in 140:
				tick(s)
				distance=maxf(distance,start.distance_to(fighter["boxing"]["rig"]["head"]))
				angle=maxf(angle,up.angle_to(fighter["boxing"]["rig"].get("head_up",Vector3.UP)))
			check(who+" "+row+" carries the head through its punch instead of pinning it",distance>0.01 and angle>deg_to_rad(0.5))
	# Capture a genuine impact with reaction and an active recovery, then prove
	# the next poses/events survive save/restore and variable render sampling.
	var saved=fresh();saved.B["guard_body"]=true;saved.B["guard_t"]=500
	for i in 35:tick(saved)
	tick(saved,{"punch":"R_STRAIGHT"})
	for i in 90:
		tick(saved)
		if not saved.B["boxing"].get("impacts",[]).is_empty():break
	for i in 4:tick(saved)
	var restored=fresh();var recovered: Dictionary=restored.restore(saved.snapshot())
	var same: bool=recovered.get("ok",false) and saved.hash_state()==restored.hash_state()
	for i in 120:
		saved.events.clear();restored.events.clear()
		saved.step({"body_axis":Vector2(0.4,0.2)});restored.step({"body_axis":Vector2(0.4,0.2)})
		same=same and saved.hash_state()==restored.hash_state() and var_to_bytes(saved.events)==var_to_bytes(restored.events)
	check("mid-impact save restores head coordination and subsequent contacts exactly",same)
	var freeze=fresh();freeze._set_dodge(freeze.P,"WEAVE",1)
	for i in 12:tick(freeze)
	var frozen: Dictionary=freeze.P["boxing"].duplicate(true);freeze.freeze_t=12
	for i in 12:tick(freeze)
	check("hitstop freezes the complete head pose and response clock",var_to_bytes(freeze.P["boxing"])==var_to_bytes(frozen))
	var amplitudes := {}
	for mode in ["head","guard","body","miss"]:
		var s=fresh(2.5 if mode=="miss" else 1.5)
		s.B["guard_body"]=mode=="head";s.B["guard_t"]=500
		for i in 35:tick(s)
		tick(s,{"punch":"R_STRAIGHT","body":mode=="body"})
		var peak:=0.0;var resolved: Dictionary={}
		for i in 140:
			tick(s)
			for event in emitted:
				if event.get("kind")=="boxing_contact" and event.get("by")=="P":resolved=event["contact"]
			peak=maxf(peak,Vector3(s.B["boxing"]["rig"].get("impact_head",Vector3.ZERO)).length())
		amplitudes[mode]=peak
		check(mode+" reaction is backed by its actual contact",resolved.get("kind")==("guard" if mode=="guard" else ("miss" if mode=="miss" else "hit")) and resolved.get("target")==("body" if mode=="body" else "head"))
	check("clean head impact exceeds guard/body response and misses add no recoil",amplitudes["head"]>amplitudes["body"] and amplitudes["body"]>amplitudes["guard"] and amplitudes["miss"]==0.0)
	samples.append({"case":"graded actual contacts","head_displacements_m":amplitudes})
	# The renderer may resample orientation at any rate without touching the
	# saved pose. Both anatomical stances use the same bounded neck response.
	for stance in ["orthodox","southpaw"]:
		var s=fresh();s.P["stance"]=stance;s.P.erase("boxing");s.P.erase("body_control")
		for i in 35:tick(s,{"body_axis":Vector2(0.7,0.5),"block":true})
		var hash_before: int=s.hash_state();var matches:=true
		for i in 31:
			scene._render(float(i)/30.0)
			for actor in [scene.player,scene.boss]:
				var rig: Dictionary=actor.get_meta("render_kinematics")
				matches=matches and head_forward(actor).dot(Vector3(rig["head_forward"]).normalized())>0.999 and actor.get_meta("head").basis.y.normalized().dot(Vector3(rig["head_up"]).normalized())>0.999
		check(stance+" rendered head follows the saved orientation at every interpolation fraction",matches and s.hash_state()==hash_before)
	if "capture" in OS.get_cmdline_user_args():await visuals()
	var file=FileAccess.open("user://head-motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"));file.close()
	print("HEAD MOTION VERDICT :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func visuals() -> void:
	DirAccess.make_dir_recursive_absolute("user://head-film")
	Engine.max_fps=60
	var captions := ["SLIP LEFT / RIGHT","DIP / PULL","CONTINUOUS WEAVE","HEAD CONTACT / RECOVERY"]
	for scenario in 4:
		var s=fresh(1.5);scene.fight_view.clock_sim=null
		Techniques.equip(s.P,{"name":"RORY"})
		if scenario==3:s.B["guard_body"]=true;s.B["guard_t"]=500
		for i in 360:
			if scene.controls_menu.opened:scene.controls_menu.close()
			var intent := {}
			if scenario<3:
				var kind: String=["SLIP","DUCK","WEAVE"][scenario]
				if scenario==1 and i>=180:kind="LEAN"
				if i in [20,180]:s._set_dodge(s.B,kind,1 if i==20 else -1)
				if i%180>15 and i%180<85:
					intent["body_axis"]=Vector2(-0.7 if i<180 else 0.7,0.5 if scenario>0 else 0.0)
				intent["block"]=true
			else:
				if i in [50,220]:intent["punch"]="R_STRAIGHT"
			tick(s,intent);scene._hud();scene.fight_view.inspection_view=false
			if i%2==1:
				await process_frame
				if scene.controls_menu.opened:scene.controls_menu.close()
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png("user://head-film/frame-%04d.png"%frames);frames+=1
			if i==45:
				root.get_texture().get_image().save_png("user://head-case-%d.png"%scenario)
		check("rendered "+captions[scenario],frames==(scenario+1)*180)

extends SceneTree
## Anatomical attachment checks must reject a head left behind a moving torso.
const Tests := preload("res://sim/tests.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
const Space := preload("res://presentation/rig_space.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
const Contact := preload("res://sim/punch_contact.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var samples := []
var worst := {}
var closest_glove := {"clearance_m":1.0}
var scene: Node

func _initialize() -> void: run.call_deferred()
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok:failures.append(label)
	print("[%s] %s"%["PASS" if ok else "FAIL",label])

func fresh(style: String, stance: String, learned: bool):
	var s=tests.make_sim(0,617)
	tests.quiet(s);tests.place(s,1.7)
	s.bstate="ACTING";s.btimer=100000;s.bqueue=[]
	for f in [s.P,s.B]:
		f["style"]=style;f["stance"]=stance;f["boxing_training"]={}
		if learned:Techniques.equip(f,{"name":"RORY"})
	for i in 20:s.step({"body_axis":Vector2.ZERO})
	s.events.clear();return s

func measure(s,who: String,label: String,peak: Dictionary) -> void:
	var f: Dictionary=s.P if who=="P" else s.B
	var rig: Dictionary=f["boxing"]["rig"]
	var collar: Vector3=(rig["shoulders"][0]+rig["shoulders"][1])*0.5
	var socket: Vector3=rig["head"]-rig["head_up"]*0.12
	var neck:=socket-collar
	var spine: Vector3=(collar-rig["pelvis"]).normalized()
	var length_error:=absf(neck.length()-0.15)
	peak["neck_length_error_m"]=maxf(peak.get("neck_length_error_m",0),length_error)
	peak["neck_length_m"]=maxf(peak.get("neck_length_m",0),neck.length())
	peak["neck_angle_degrees"]=maxf(peak.get("neck_angle_degrees",0),rad_to_deg(neck.angle_to(spine)))
	peak["head_behind_collar_m"]=maxf(peak.get("head_behind_collar_m",0),-(Vector3(rig["head"])-collar).dot(rig["forward"]))
	var head: Dictionary=s._head_world(f,s.B if who=="P" else s.P)
	var world:=Space.ground(f["pos"])+Vector3(rig["head"])
	peak["contact_error_m"]=maxf(peak.get("contact_error_m",0),world.distance_to(f["boxing"]["volumes"][0]["a"]))
	peak["query_error_m"]=maxf(peak.get("query_error_m",0),world.distance_to(Space.ground(head["p"])+Vector3.UP*float(head["h"])))
	for hand in 2:
		var clearance: float=Vector3(rig["head"]).distance_to(rig["wrists"][hand])
		peak["min_head_glove_m"]=minf(peak.get("min_head_glove_m",1),clearance)
		if clearance<float(closest_glove["clearance_m"]):
			closest_glove={"case":label,"who":who,"hand":hand,"clearance_m":clearance,"snapshot":s.snapshot()}
	if neck.length()>float(worst.get("neck_length_m",0)):
		worst={"case":label,"who":who,"neck_length_m":neck.length(),"snapshot":s.snapshot()}

func exercise(style: String,stance: String,learned: bool,who: String) -> void:
	var label:="%s %s learned=%s %s"%[style,stance,learned,who]
	var peak:={}
	var s=fresh(style,stance,learned)
	for i in 220:
		var axis:=Vector2.from_angle(float(i)/220.0*TAU)
		if who=="B":s._set_dodge(s.B,"WEAVE" if i>100 else "LEAN",1)
		s.step({"body_axis":axis if who=="P" else Vector2.ZERO})
		measure(s,who,label+" body disk",peak)
	for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_HOOK","L_UPPERCUT","R_UPPERCUT","L_HOOKERCUT","R_HOOKERCUT","L_FLARED","R_FLARED"]:
		for body in [false,true]:
			s=fresh(style,stance,learned)
			if who=="P":s.step({"body_axis":Vector2(0.4,0.5),"punch":row,"body":body,"power":true})
			else:s._boss_act({"kind":"punch","row":row,"body":body,"mult":1.0})
			for i in 120:
				s.step({"body_axis":Vector2(0.4,0.5) if who=="P" and i<60 else Vector2.ZERO})
				measure(s,who,label+" "+row+" body="+str(body),peak)
	check(label+" keeps a fixed neck rather than stretching toward a detached head",peak["neck_length_error_m"]<0.001)
	check(label+" keeps the neck within its bend relative to the spine",peak["neck_angle_degrees"]<=25.1)
	check(label+" keeps head query and collision on that attached pose",peak["contact_error_m"]<0.0001 and peak["query_error_m"]<0.0001)
	check(label+" routes its own gloves outside its skull",peak["min_head_glove_m"]>=0.319)
	samples.append({"case":label,"peak":peak})

func open_scene() -> void:
	root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	await process_frame;await process_frame
	scene.controls_menu.close();scene.fight_hud.entry.hide()

func show_worst() -> void:
	await open_scene()
	var s=fresh("BOXERPUNCHER","orthodox",false)
	check("worst pose restores for visible inspection",s.restore(worst["snapshot"]).get("same",false))
	if "resolve-saved" in OS.get_cmdline_user_args():
		# Same saved tick, body goals, hands, camera and orientation as BEFORE.
		# Only rerun the repaired anatomical constraint and its hit volumes.
		for f in [s.P,s.B]:
			f["boxing"]["rig"]=Motion.constrain(f["boxing"]["rig"])
			f["boxing"]["volumes"]=Contact.volumes(f,f["boxing"]["rig"])
	scene.sim=s;scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"]
	scene._consume_events();scene._render(1);scene._hud()
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("user://head-attachment-chase.png")
	scene.fight_view.inspection_view=true;scene._render(1)
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("user://head-attachment-side.png")
	scene.queue_free();await process_frame

func rendered_motion() -> void:
	await open_scene()
	var record: bool="film" in OS.get_cmdline_user_args()
	if record:DirAccess.make_dir_recursive_absolute("user://motion-film")
	var frame:=0
	var captions:=["Ordinary orthodox: slip / dip / pull", "Northern Rising southpaw: body control", "Orthodox: jab / cross / hook / uppercut", "Southpaw: head contact and recovery"]
	for scenario in 4:
		var s=fresh("BOXERPUNCHER","southpaw" if scenario%2==1 else "orthodox",scenario==1)
		scene.fight_view.clock_sim=null
		scene.sim=s;scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"];scene._render(1)
		if scenario==3:s.B["guard_body"]=true;s.B["guard_t"]=500
		var attached:=true;var stable:=true;var read_only:=true;var maximum_jump:=0.0
		var supported:=true;var facing:=true;var clear_gloves:=true
		var previous: Array=[]
		var previous_poses: Array=[]
		var previous_support: Array=[]
		var worst_jump:={}
		for i in 360:
			var intent:={"body_axis":Vector2.ZERO}
			if scenario<2:
				var stage:=i/90
				var amount:=sin(float(i%90)/90.0*PI)
				intent["body_axis"]=[Vector2(-0.9,0),Vector2(0.9,0),Vector2(0,-0.9),Vector2(0,0.9)][stage]*amount
				intent["block"]=true
				if i%90==15:s._set_dodge(s.B,["SLIP","SLIP","DUCK","LEAN"][stage],-1 if stage==0 else 1)
			elif scenario==2:
				if i%90==15:intent["punch"]=["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_UPPERCUT"][i/90]
				intent["block"]=true
				if i in [110,200]:s._set_dodge(s.B,"SLIP",1)
			else:
				if i in [20,185]:intent["punch"]="R_STRAIGHT"
			scene.fight_view.capture(scene.player,s.P,s.B,s,"P")
			scene.fight_view.capture(scene.boss,s.B,s.P,s,"B")
			scene.fight_view.before_step(s)
			scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"]
			s.events.clear();s.step(intent)
			scene._consume_events();scene._render(1);scene._hud()
			var hash_before: int=s.hash_state()
			var heads: Array=[]
			for f in [s.P,s.B]:
				var rig: Dictionary=f["boxing"]["rig"]
				var support: Dictionary=f["body_control"]
				for foot in 2:
					if float(support["foot_lift"][foot])>0.001:
						supported=supported and (float(support["weight_lead"])<=0.121 if foot==0 else float(support["weight_lead"])>=0.879)
				heads.append(Space.ground(f["pos"])+Vector3(rig["head"]))
				var repeated:=rig.duplicate(true)
				for pass_index in 8:repeated=Motion.constrain(repeated)
				stable=stable and Vector3(repeated["head"]).distance_to(rig["head"])<0.00001
			if not previous.is_empty():
				for actor in 2:
					var jump: float=heads[actor].distance_to(previous[actor])
					if jump>maximum_jump:
						maximum_jump=jump
						var f: Dictionary=[s.P,s.B][actor]
						worst_jump={"tick":i,"who":"P" if actor==0 else "B","before":previous_poses[actor],"after":f["boxing"]["rig"].duplicate(true),"support_before":previous_support[actor],"support_after":f["body_control"].duplicate(true),"events":s.events.duplicate(true),"action":f["boxing"].get("action",{}).duplicate(true)}
			previous=heads
			previous_poses=[s.P["boxing"]["rig"].duplicate(true),s.B["boxing"]["rig"].duplicate(true)]
			previous_support=[s.P["body_control"].duplicate(true),s.B["body_control"].duplicate(true)]
			for alpha in [0.0,0.25,0.5,0.75,1.0]:
				scene._render(alpha)
				for actor in [scene.player,scene.boss]:
					var rig: Dictionary=actor.get_meta("render_kinematics")
					var collar: Vector3=(rig["shoulders"][0]+rig["shoulders"][1])*0.5
					var socket: Vector3=actor.get_meta("head").position-actor.get_meta("head").basis.y.normalized()*0.12
					var neck:=socket-collar
					attached=attached and absf(neck.length()-0.15)<0.001 and neck.angle_to((collar-Vector3(rig["pelvis"])).normalized())<=deg_to_rad(25.1)
					for hand in 2:clear_gloves=clear_gloves and Vector3(rig["wrists"][hand]).distance_to(rig["head"])>=0.319
					var other: Node3D=scene.boss if actor==scene.player else scene.player
					var focus: Vector3=other.position+other.get_meta("head").position-actor.position-actor.get_meta("head").position
					facing=facing and (-actor.get_meta("head").basis.z.normalized()).dot(focus.normalized())>0.7
			read_only=read_only and s.hash_state()==hash_before
			if record and i%2==1:
				scene.fight_hud.cue.text=captions[scenario]
				# Production chase camera first, explicitly labelled diagnostic
				# side view second. Both are exactly the same simulation frame.
				for side in [false,true]:
					scene.fight_view.inspection_view=side;scene._render(1)
					await process_frame
					# Desktop focus-loss intentionally opens controls in the game.
					# This scripted capture must not publish an obscured playfield.
					if scene.controls_menu.opened:scene.controls_menu.close()
					RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png("user://motion-film/%s-%04d.png"%["side" if side else "chase",frame])
				frame+=1
		check(captions[scenario]+" keeps rendered neck attached throughout interpolation",attached)
		check(captions[scenario]+" does not drift after repeated pose constraints",stable)
		check(captions[scenario]+" rendering cannot alter combat",read_only)
		check(captions[scenario]+" has no discontinuous head jumps",maximum_jump<0.045)
		check(captions[scenario]+" keeps load off the airborne foot",supported)
		check(captions[scenario]+" keeps the visible face directed toward the opponent",facing)
		check(captions[scenario]+" keeps its gloves outside its head between fixed ticks",clear_gloves)
		samples.append({"case":captions[scenario],"max_head_step_m":maximum_jump,"worst_jump":worst_jump})
	scene.queue_free();await process_frame

func run() -> void:
	if "worst-only" in OS.get_cmdline_user_args():
		worst=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BOXING_WORST")))
		await show_worst();quit();return
	if "render-only" in OS.get_cmdline_user_args():
		await rendered_motion()
		FileAccess.open("user://rendered-motion.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"))
		quit(0 if failures.is_empty() else 1);return
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for stance in ["orthodox","southpaw"]:
			for learned in [false,true]:
				for who in ["P","B"]:exercise(style,stance,learned,who)
	if "capture" in OS.get_cmdline_user_args():await show_worst()
	var saved: Dictionary=worst.duplicate(true);saved.erase("snapshot")
	FileAccess.open("user://head-attachment-worst.json",FileAccess.WRITE).store_string(JSON.stringify(worst))
	FileAccess.open("user://head-glove-closest.json",FileAccess.WRITE).store_string(JSON.stringify(closest_glove))
	FileAccess.open("user://head-attachment.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":checks-failures.size(),"failures":failures,"samples":samples,"worst":saved,"foundation":"NOT_ACCEPTED"},"\t"))
	print("HEAD ATTACHMENT %d/%d"%[checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

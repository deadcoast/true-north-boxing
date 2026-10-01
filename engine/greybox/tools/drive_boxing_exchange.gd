extends SceneTree
## Sustained native exchanges. Measures the actual shared collision/render rig.
const Tests := preload("res://sim/tests.gd")
const Space := preload("res://presentation/rig_space.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
const Contact := preload("res://sim/punch_contact.gd")
var tests := Tests.new()
var samples := []
var worst := {}
var checks := 0
var failures := []

func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok:failures.append(label)
	print("[%s] %s"%["PASS" if ok else "FAIL",label])

func _initialize() -> void: run.call_deferred()

func cylinder_gap(point: Vector3, bottom: Vector3, top: Vector3) -> float:
	var axis := top-bottom
	var up := axis.normalized()
	var relative := point-(bottom+top)*0.5
	var height := relative.dot(up)
	var d := Vector2((relative-up*height).length()-Space.BODY_RADIUS,absf(height)-axis.length()*0.5)
	return Vector2(maxf(d.x,0),maxf(d.y,0)).length()+minf(maxf(d.x,d.y),0)

func record(s, label: String, who: String, key: String, value: float, peak: Dictionary, detail := {}) -> void:
	peak[key]=maxf(peak.get(key,0),value)
	if value > float(worst.get(key,{}).get("value",0)):
		worst[key]={"case":label,"who":who,"tick":s.tick,"value":value,"detail":detail,"snapshot":s.snapshot()}

func measure(s, label: String, who: String, peak: Dictionary, prior: Dictionary) -> void:
	var f: Dictionary=s.P if who=="P" else s.B
	if not f.has("boxing"):return
	var rig: Dictionary=f["boxing"]["rig"]
	if not f["boxing"].get("preparation",{}).is_empty():
		var supported: Vector2=f["body_control"]["facing"]
		record(s,label,who,"preparation_facing_error_rad",Vector3(supported.x,0,supported.y).angle_to(rig["forward"]),peak)
	var action: Dictionary=f["boxing"].get("action",{})
	var returning: Dictionary=action.get("returning",{})
	if not returning.is_empty() and action.has("start_arms") and int(action.get("age",0))<int(returning["duration"]):
		var hand:=int(returning["hand"])
		var initial: Vector3=returning.get("arm",action["start_arms"][hand])
		var home: Vector3=rig.get("hand_homes",rig["wrists"])[hand]
		var allowed:=maxf(initial.length(),home.distance_to(rig["shoulders"][hand]))
		record(s,label,who,"opposite_return_excess_reach_m",Vector3(rig["wrists"][hand]).distance_to(rig["shoulders"][hand])-allowed,peak,{"hand":hand})
	var top: Vector3=(rig["shoulders"][0]+rig["shoulders"][1])*0.5
	var bottom: Vector3=rig["pelvis"]+Vector3.UP*0.04
	for hand in 2:
		var elbow: Vector3=rig["elbows"][hand];var wrist: Vector3=rig["wrists"][hand]
		var bone_error:=maxf(absf(elbow.distance_to(rig["shoulders"][hand])-Motion.UPPER_ARM),absf(wrist.distance_to(elbow)-Motion.FOREARM))
		bone_error=maxf(bone_error,absf(Vector3(rig["knees"][hand]).distance_to(rig["hip_joints"][hand])-Motion.THIGH))
		bone_error=maxf(bone_error,absf(Vector3(rig["ankles"][hand]).distance_to(rig["knees"][hand])-Motion.SHIN))
		record(s,label,who,"bone_length_error_m",bone_error,peak,{"hand":hand})
		var nearest:=Geometry3D.get_closest_point_to_segment(rig["head"],elbow,wrist)
		record(s,label,who,"forearm_head_penetration_m",Space.HEAD_RADIUS+0.085-nearest.distance_to(rig["head"]),peak,{"hand":hand})
		record(s,label,who,"glove_torso_penetration_m",Space.GLOVE_RADIUS-cylinder_gap(wrist,bottom,top),peak,{"hand":hand})
		var penetration:=0.0
		for n in 17:penetration=maxf(penetration,0.085-cylinder_gap(elbow.lerp(wrist,n/16.0),bottom,top))
		record(s,label,who,"forearm_torso_penetration_m",penetration,peak,{"hand":hand})
	if prior.has(who):
		var last: Dictionary=prior[who]
		record(s,label,who,"facing_step_rad",Vector3(last["forward"]).angle_to(rig["forward"]),peak)
		record(s,label,who,"guard_phase_step",absf(float(rig["guard"])-float(last["guard"])),peak)
		if rig.has("guard_level") and last.has("guard_level"):
			record(s,label,who,"guard_level_step",absf(float(rig["guard_level"])-float(last["guard_level"])),peak)
		for key in ["head","pelvis"]:
			record(s,label,who,key+"_step_m",Vector3(rig[key]).distance_to(last[key]),peak,{"before":last,"after":rig})
			record(s,label,who,"world_"+key+"_step_m",(Space.ground(f["pos"])+Vector3(rig[key])).distance_to(Vector3(last["_origin"])+Vector3(last[key])),peak,{"before":last,"after":rig})
		for key in ["elbows","wrists","knees"]:
			for hand in 2:record(s,label,who,key+"_step_m",Vector3(rig[key][hand]).distance_to(last[key][hand]),peak,{"hand":hand,"before":last,"after":rig})
	var own_contacts: Array=s.events.filter(func(event):return event.get("kind")=="boxing_contact" and event.get("by")==who and event["contact"]["kind"]!="miss")
	# Include every resolved impact, where sub-tick interpolation and hand
	# correction previously moved the opposite arm between physics and view.
	if s.tick%16==0 or not own_contacts.is_empty():
		var repeated:=Motion.constrain(rig.duplicate(true))
		for key in ["elbows","wrists"]:
			for hand in 2:record(s,label,who,"repeat_"+key+"_drift_m",Vector3(repeated[key][hand]).distance_to(rig[key][hand]),peak,{"hand":hand})
	prior[who]=rig.duplicate(true);prior[who]["_origin"]=Space.ground(f["pos"]);prior[who]["_support"]=f["body_control"].duplicate(true)
	for event in own_contacts:
		var hand:=0 if str(event["contact"]["row"]).begins_with("L_") else 1
		var point: Vector3=Space.ground(f["pos"])+Vector3(rig["wrists"][hand])
		record(s,label,who,"contact_endpoint_error_m",point.distance_to(event["contact"]["point"]),peak,{"hand":hand,"contact":event["contact"]})

func command(tick: int, s) -> Dictionary:
	var cycle:=tick%360
	var axis:=Vector2.ZERO
	if cycle<105:axis=Vector2(sin(cycle/105.0*TAU)*0.65,-sin(cycle/105.0*PI)*0.65)
	var input:={"body_axis":axis,"block":cycle>=150 and cycle<300,"body":cycle>=210 and cycle<270}
	var rows:=["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_UPPERCUT","L_UPPERCUT","R_HOOK"]
	if cycle>=110 and cycle<278 and (cycle-110)%28==0:input["punch"]=rows[(cycle-110)/28]
	if cycle==310:
		var distance: float=Vector2(s.P["pos"]).distance_to(s.B["pos"])
		input["pocket_step"]=Vector2(0.55,-0.7) if distance>1.65 else Vector2(-0.55,0.65)
	if s.mode=="EIGHT":input["rise"]=tick%2==0
	if s.mode in ["CARD","CORNER"]:input["corner"]=1
	return input

func film() -> void:
	root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	await process_frame;await process_frame
	scene.controls_menu.close();scene.fight_hud.entry.hide()
	var s=tests.make_sim(0,719);tests.place(s,1.5)
	var start_tick:=0;var duration:=2880;var stride:=4
	if "saved-film" in OS.get_cmdline_user_args():
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BOXING_CHECKPOINT")))
		check("exchange checkpoint restores exactly",s.restore(saved["snapshot"]).get("same",false))
		if not failures.is_empty():scene.queue_free();return
		start_tick=int(saved["input_tick"]);duration=180;stride=1
	scene.sim=s;scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"];scene._render(1)
	DirAccess.make_dir_recursive_absolute("user://exchange-film")
	var peak:={};var prior:={};var exact:=true;var frame:=0
	for tick in range(start_tick,start_tick+duration):
		scene.fight_view.capture(scene.player,s.P,s.B,s,"P");scene.fight_view.capture(scene.boss,s.B,s.P,s,"B")
		scene.fight_view.before_step(s);scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"]
		s.events.clear();s.step(command(tick,s))
		if s.mode=="FIGHT":
			for who in ["P","B"]:measure(s,"production exchange",who,peak,prior)
		else:prior.clear()
		scene._consume_events();scene._render(1);scene._hud()
		if (tick-start_tick)%stride==0:
			var hash_before: int=s.hash_state()
			for side in [false,true]:
				scene.fight_view.inspection_view=side;scene._render(1)
				await process_frame;scene.controls_menu.close();RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png("user://exchange-film/%s-%04d.png"%["inspection" if side else "chase",frame])
			frame+=1;exact=exact and hash_before==s.hash_state()
	FileAccess.open("user://film.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":frame,"simulation_seconds":duration/120.0,"fps":120/stride,"start_input_tick":start_tick,"render_read_only":exact,"peak":peak},"\t"))
	for key in worst:FileAccess.open("user://worst-"+key+".json",FileAccess.WRITE).store_string(JSON.stringify(worst[key],"\t"))
	scene.queue_free();await process_frame

func run() -> void:
	if "film" in OS.get_cmdline_user_args() or "saved-film" in OS.get_cmdline_user_args():await film();quit(0 if failures.is_empty() else 1);return
	if "replay" in OS.get_cmdline_user_args():
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BOXING_CHECKPOINT")))
		var s=tests.make_sim(0,719)
		check("trajectory checkpoint restores exactly",s.restore(saved["snapshot"]).get("same",false))
		if not failures.is_empty():quit(1);return
		var peak:={};var prior:={};var timeline:=[]
		for tick in range(int(saved["input_tick"]),int(saved["input_tick"])+180):
			s.events.clear();s.step(command(tick,s))
			var frame:={"tick":s.tick,"events":s.events.duplicate(true)}
			for who in ["P","B"]:
				measure(s,"shared checkpoint",who,peak,prior)
				var f: Dictionary=s.P if who=="P" else s.B
				frame[who]={"action":f["boxing"].get("action",{}).duplicate(true),"preparation":f["boxing"].get("preparation",{}).duplicate(true),"presentation":f["boxing"].get("presentation",{}).duplicate(true),"rig":f["boxing"]["rig"].duplicate(true)}
			timeline.append(frame)
		FileAccess.open("user://replay.json",FileAccess.WRITE).store_string(JSON.stringify({"peak":peak,"timeline":timeline},"\t"))
		for key in worst:FileAccess.open("user://worst-"+key+".json",FileAccess.WRITE).store_string(JSON.stringify(worst[key],"\t"))
		# Limits belong to the saved regression fixture, never gameplay tuning.
		for key in saved.get("limits",{}):
			if not peak.has(key):
				print("[UNSAMPLED] saved trajectory ",key);continue
			check("saved trajectory "+key,float(peak[key])<=float(saved["limits"][key]))
		print("TRAJECTORY REPLAY ",JSON.stringify(peak));quit(0 if failures.is_empty() else 1);return
	if "repose" in OS.get_cmdline_user_args():
		# Re-evaluate a saved flight pose without advancing its clock or input.
		# This isolates pose changes from a fight's diverging contact outcomes.
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BOXING_WORST")))
		var s=tests.make_sim(0,719)
		check("saved hook restores exactly",s.restore(saved["snapshot"]).get("same",false))
		var f: Dictionary=s.P if saved["who"]=="P" else s.B
		var other: Dictionary=s.B if saved["who"]=="P" else s.P
		var state: Dictionary=f["boxing"]
		check("saved pose is in flight",state["action"].get("phase")=="flight")
		if not failures.is_empty():quit(1);return
		var old_rig: Dictionary=state["rig"].duplicate(true)
		var solver:=Motion.new();solver.restore_state(state["solver"])
		var physical:=f.duplicate();physical["continuous_delivery"]=true
		var head: Dictionary=s._head_world(f,other,false)
		var offset:=Space.ground(Vector2(head["p"])-Vector2(f["pos"]))+Vector3.UP*(float(head["h"])-1.55)
		var rig:=solver.sample(physical,other,state["clock"],state["presentation"],offset)
		var hand: int=saved["detail"]["hand"]
		var previous: Dictionary=state["previous_rig"]
		var comparison:={"tick":s.tick,"clock":state["clock"],"row":state["action"]["row"],"progress":state["action"]["progress"],
			"before_elbow_step_m":Vector3(old_rig["elbows"][hand]).distance_to(previous["elbows"][hand]),
			"after_elbow_step_m":Vector3(rig["elbows"][hand]).distance_to(previous["elbows"][hand]),
			"head_change_m":Vector3(rig["head"]).distance_to(old_rig["head"])}
		state["rig"]=rig;state["solver"]=solver.state();state["volumes"]=Contact.volumes(f,rig)
		saved["snapshot"]=s.snapshot();saved["comparison"]=comparison
		FileAccess.open("user://reposed.json",FileAccess.WRITE).store_string(JSON.stringify(saved,"\t"))
		print("SAME CLOCK HOOK ",JSON.stringify(comparison));quit();return
	if "contact-probe" in OS.get_cmdline_user_args():
		for distance in [1.2,1.5,1.8]:
			for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_HOOK","L_UPPERCUT","R_UPPERCUT"]:
				for scenario in ["body","clash"]:
					var s=tests.make_sim(0,781);tests.quiet(s);tests.place(s,distance)
					s.bstate="ACTING";s.bqueue=[];s.btimer=100000
					s.P["boxing_training"]={};s.B["guard_body"]=true;s.B["guard_t"]=100 if scenario=="clash" else 0
					for tick in 30:s.step({"body_axis":Vector2.ZERO,"block":true,"body":scenario=="clash"})
					s.events.clear();s.btimer=s._boss_act({"kind":"punch","row":row,"mult":1.0,"body":scenario=="body"})
					s.step({"body_axis":Vector2.ZERO,"punch":row} if scenario=="clash" else {"body_axis":Vector2.ZERO,"block":true})
					var events: Array=s.events.duplicate(true)
					for tick in 150:
						s.events.clear();s.step({"body_axis":Vector2.ZERO,"block":scenario=="body","body":scenario=="clash"});events.append_array(s.events)
					var contacts:=events.filter(func(e):return e.get("kind")=="boxing_contact")
					print("CONTACT PROBE ",distance," ",row," ",scenario," ",JSON.stringify(contacts))
		quit();return
	if "guard-probe" in OS.get_cmdline_user_args():
		for learned in [false,true]:
			var s=tests.make_sim(0,719);tests.quiet(s);tests.place(s,1.8)
			s.P["boxing_training"]={}
			if learned:Techniques.equip(s.P,{"name":"RORY"})
			for tick in 20:s.step({"body_axis":Vector2.ZERO})
			var r: Dictionary=s.P["boxing"]["rig"]
			print("GUARD ",learned," ",JSON.stringify({"head":r["head"],"wrists":r["wrists"],"shoulders":r["shoulders"],"elbows":r["elbows"],"jaw_gap":Vector3(r["wrists"][1]).distance_to(r["head"])-0.32,"advance":(Vector3(r["wrists"][0])-Vector3(r["wrists"][1])).dot(r["forward"])}))
		quit();return
	if "inspect" in OS.get_cmdline_user_args():
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BOXING_WORST")))
		var s=tests.make_sim(0,719);s.restore(saved["snapshot"])
		var f: Dictionary=s.P if saved["who"]=="P" else s.B
		var rig: Dictionary=f["boxing"]["rig"]
		var fields:={}
		for key in ["head","pelvis","chest","shoulders","wrists","elbows","hand_goals","arm_poles","arm_stability","support_elbows"]:fields[key]=rig[key]
		print(JSON.stringify({"who":saved["who"],"tick":saved["tick"],"action":f["boxing"]["action"],"body":f["body_control"],"rig":fields}));quit();return
	var checkpoint_style:=OS.get_environment("BOXING_STYLE") if OS.has_environment("BOXING_STYLE") else "SLUGGER"
	var checkpoint_learned:=OS.get_environment("BOXING_LEARNED")!="false"
	var checkpoint_tick:=int(OS.get_environment("BOXING_TICK")) if OS.has_environment("BOXING_TICK") else 2390
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for learned in [false,true]:
			if "checkpoint" in OS.get_cmdline_user_args() and (style!=checkpoint_style or learned!=checkpoint_learned):continue
			if "trace" in OS.get_cmdline_user_args() and (style!="OUTBOXER" or not learned):continue
			var s=tests.make_sim(0,719)
			tests.place(s,1.5)
			for f in [s.P,s.B]:
				f["style"]=style;f["stance"]="southpaw" if learned else "orthodox";f["boxing_training"]={}
				if learned:Techniques.equip(f,{"name":"RORY"})
			var peak:={};var prior:={};var contacts:={};var modes:={};var timings:=[]
			var label:="%s learned=%s"%[style,learned]
			for tick in (1200 if "trace" in OS.get_cmdline_user_args() else 10800):
				if "checkpoint" in OS.get_cmdline_user_args() and s.tick>=checkpoint_tick:
					FileAccess.open("user://checkpoint.json",FileAccess.WRITE).store_string(JSON.stringify({"input_tick":tick,"snapshot":s.snapshot()},"\t"))
					print("SAVED HOOK CHECKPOINT ",s.tick," input ",tick);quit();return
				s.events.clear()
				var started:=Time.get_ticks_usec();s.step(command(tick,s));timings.append(Time.get_ticks_usec()-started)
				modes[s.mode]=int(modes.get(s.mode,0))+1
				if s.mode=="FIGHT":
					for who in ["P","B"]:measure(s,label,who,peak,prior)
				else:prior.clear()
				for e in s.events:
					if e.get("kind")=="boxing_contact":
						var kind:=str(e["by"])+" "+str(e["contact"]["kind"])
						contacts[kind]=int(contacts.get(kind,0))+1
				if s.mode in ["RESULT","END","COMPLETE"]:break
			timings.sort()
			var result:={"case":label,"peak":peak,"contacts":contacts,"modes":modes,"step_p95_us":timings[int(timings.size()*0.95)]}
			samples.append(result);print(JSON.stringify(result))
			for key in ["forearm_head_penetration_m","forearm_torso_penetration_m","glove_torso_penetration_m","bone_length_error_m","contact_endpoint_error_m","repeat_elbows_drift_m","repeat_wrists_drift_m"]:
				check(label+" "+key+" stays below 1 mm",float(peak.get(key,0))<0.001)
			check(label+" guard stroke never skips more than one active tick",peak.has("guard_phase_step") and float(peak["guard_phase_step"])<=1.0/6.0+0.00001)
			check(label+" guard height never skips more than one active tick",peak.has("guard_level_step") and float(peak["guard_level_step"])<=0.10001)
			check(label+" preparation follows supported body facing",peak.has("preparation_facing_error_rad") and float(peak["preparation_facing_error_rad"])<0.0001)
			check(label+" exercises both fighters against active AI",modes.get("FIGHT",0)>600 and contacts.keys().any(func(k):return k.begins_with("P ")) and contacts.keys().any(func(k):return k.begins_with("B ")))
	for key in worst:FileAccess.open("user://worst-"+key+".json",FileAccess.WRITE).store_string(JSON.stringify(worst[key],"\t"))
	FileAccess.open("user://exchange.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
	print("EXCHANGE GEOMETRY CHECKS %d/%d; foundation acceptance remains open"%[checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

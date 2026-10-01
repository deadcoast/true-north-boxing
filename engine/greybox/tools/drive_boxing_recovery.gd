extends SceneTree
## Native count, cancellation and round-lifecycle regression. Not foundation acceptance.
const Tests := preload("res://sim/tests.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
const Contact := preload("res://sim/punch_contact.gd")
const Feedback := preload("res://presentation/fight_feedback.gd")
const Clock := preload("res://sim/clock.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var samples := []
var scene: Node

func _initialize() -> void: run.call_deferred()
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])

func fresh(stance := "orthodox"):
	var s=tests.make_sim(0,719)
	tests.quiet(s);tests.place(s,1.5)
	s.bstate="ACTING";s.bqueue=[];s.btimer=100000
	for f in [s.P,s.B]:
		f["stance"]=stance;f["house"]="none";f["stats"]["HRT"]=99
	for i in 20:s.step({"body_axis":Vector2.ZERO})
	s.events.clear()
	return s

func beat(s) -> Dictionary:
	return {"body_axis":Vector2.ZERO,"rise":s.mode=="EIGHT" and int(s.eight.get("timer_t",999))==1}

func count_case(who: String, stance: String) -> void:
	var s=fresh(stance)
	var f: Dictionary=s.P if who=="P" else s.B
	s.step({"body_axis":Vector2(0.5,0.3),"punch":"R_STRAIGHT"})
	s._boss_act({"kind":"punch","row":"L_STRAIGHT","body":false,"mult":1.0})
	s.P["cmd"]={"row":"L_HOOK","mods":[],"expire_t":18,"lb":false,"toward":false}
	s.P["frozen_step"]={"direction":Vector2.LEFT,"remaining":0.12}
	s.bqueue=[{"kind":"punch","row":"R_HOOK","body":false,"mult":1.0}]
	var clock: int=s.clock_t
	var roots:=[s.P["pos"],s.B["pos"]]
	f["comp"]=0
	s._drop(who=="P")
	var label:="%s %s count"%[stance,who]
	check(label+" pauses the bout for either fighter",s.mode=="EIGHT")
	check(label+" cancels pending and buffered offense on both sides",s.P["pending"].is_empty() and s.B["pending"].is_empty() and s.P["cmd"].is_empty() and s.bqueue.is_empty())
	check(label+" defers composure reset until the count is survived",f["comp"]<=0)
	var saved:={};var copy=null;var exact:=true;var has_pose:=true;var clocks_held:=true
	var minimum_head:=2.0;var minimum_knee:=2.0;var peak_joint:=0.0;var old:={};var elapsed:=0
	var contacts:=0;var risen:=false
	var prompts:=true;var bone_error:=0.0
	s.events.clear()
	while s.mode=="EIGHT" and elapsed<1200:
		var intent:=beat(s)
		s.step(intent)
		if s.mode=="EIGHT":prompts=prompts and Feedback.timing_state(s).is_empty()==(who=="B" or s.eight.get("phase","")=="rise")
		if copy!=null:
			copy.step(intent);exact=exact and copy.hash_state()==s.hash_state()
		if elapsed==65:
			saved=s.snapshot();copy=fresh(stance)
			exact=exact and bool(copy.restore(saved).get("same",false))
		clocks_held=clocks_held and s.clock_t==clock
		has_pose=has_pose and s.P.get("boxing",{}).has("rig") and s.B.get("boxing",{}).has("rig")
		if has_pose:
			var rig: Dictionary=f["boxing"]["rig"]
			minimum_head=minf(minimum_head,rig["head"].y)
			minimum_knee=minf(minimum_knee,minf(rig["knees"][0].y,rig["knees"][1].y))
			for j in 2:
				bone_error=maxf(bone_error,absf(Vector3(rig["shoulders"][j]).distance_to(rig["elbows"][j])-Motion.UPPER_ARM))
				bone_error=maxf(bone_error,absf(Vector3(rig["elbows"][j]).distance_to(rig["wrists"][j])-Motion.FOREARM))
				bone_error=maxf(bone_error,absf(Vector3(rig["hip_joints"][j]).distance_to(rig["knees"][j])-Motion.THIGH))
				bone_error=maxf(bone_error,absf(Vector3(rig["knees"][j]).distance_to(rig["ankles"][j])-Motion.SHIN))
			if not old.is_empty():
				for k in ["head","pelvis","chest"]:peak_joint=maxf(peak_joint,Vector3(rig[k]).distance_to(old[k]))
				for k in ["wrists","elbows","knees","feet"]:
					for j in 2:peak_joint=maxf(peak_joint,Vector3(rig[k][j]).distance_to(old[k][j]))
			old=rig.duplicate(true)
		for e in s.events:
			if e.get("kind")=="boxing_contact":contacts+=1
			if e.get("kind")=="eight_up":risen=true
		s.events.clear();elapsed+=1
	check(label+" retains a saved connected pose throughout",has_pose and elapsed>0)
	check(label+" visibly lowers to a knee without penetrating the floor",minimum_head<1.20 and minimum_knee<0.15 and minimum_knee>=0.095)
	check(label+" has bounded joint motion",has_pose and elapsed>0 and peak_joint<0.07)
	check(label+" restores exactly midway through recovery",not saved.is_empty() and exact)
	check(label+" holds the round clock and roots",clocks_held and roots==[s.P["pos"],s.B["pos"]])
	check(label+" contains no late contact",contacts==0)
	check(label+" preserves arm and leg lengths",bone_error<0.001 and has_pose)
	check(label+" prompts only a player who can still rise",prompts and elapsed>0)
	check(label+" completes a visible rise before combat",risen and s.mode=="FIGHT" and elapsed>430)
	check(label+" restores half composure with ten-second vulnerability",is_equal_approx(float(f["comp"]),float(f["comp_max"])*0.5) and int(f["no_regen_t"])==1200)
	check(label+" discards pre-count steps",not s.P.has("frozen_step") and s.P.get("body_control",{}).get("step",{}).is_empty())
	if s.mode=="FIGHT":
		s.bstate="ACTING";s.btimer=100000;s.events.clear()
		for i in 60:s.step({"body_axis":Vector2.ZERO})
		check(label+" resumes without buffered punches or movement",s.events.all(func(e):return e.get("kind") not in ["punch","boxing_contact"]) and roots==[s.P["pos"],s.B["pos"]])
		check(label+" cannot recover composure during vulnerability",is_equal_approx(float(f["comp"]),float(f["comp_max"])*0.5))
	samples.append({"case":label,"ticks":elapsed,"minimum_head_m":minimum_head,"minimum_knee_m":minimum_knee,"peak_joint_step_m":peak_joint})

func lifecycle_cases() -> void:
	for who in ["P","B"]:
		var s=fresh()
		var f: Dictionary=s.P if who=="P" else s.B
		f["comp"]=0;s._drop(who=="P")
		if who=="B":s.B["stats"]["HRT"]=0 # Seeded low-HRT failure case, not authored character tuning.
		var elapsed:=0
		while s.mode=="EIGHT" and elapsed<900:s.step({});elapsed+=1
		check(who+" failed count ends the segment",s.mode in ["CARD","OVER"])
		check(who+" count-out awards KO to the opposing side",s.events.any(func(e):return e.get("kind")=="segment_ko" and e.get("by")==("B" if who=="P" else "P")))
		check(who+" failed count leaves no active or buffered punch",s.P["pending"].is_empty() and s.B["pending"].is_empty() and s.P["cmd"].is_empty() and s.bqueue.is_empty())
		check(who+" counted-out fighter stays down on the result",f.get("boxing",{}).get("rig",{}).get("head",Vector3.UP*2).y<1.20)
		s=fresh();f=s.P if who=="P" else s.B
		f["drops"]=2;f["comp"]=0;s._drop(who=="P")
		check(who+" third drop goes straight to the segment result",s.mode in ["CARD","OVER"] and s.eight.is_empty())
		for i in 100:s.step({})
		check(who+" third-drop knockout finishes falling on the result",f.get("boxing",{}).get("rig",{}).get("head",Vector3.UP*2).y<1.20)
		if s.mode=="CARD":
			s.step({"corner":1});check(who+" result opens existing corner",s.mode=="CORNER")
			s.step({"corner":1});s.step({"body_axis":Vector2.ZERO})
			check(who+" next segment starts with fresh boxing and no count pose",s.mode=="FIGHT" and s.P["drops"]==0 and s.B["drops"]==0 and not s.P.get("boxing",{}).has("count_weight") and not s.B.get("boxing",{}).has("count_weight"))

func effort_cases() -> void:
	for who in ["P","B"]:
		var a=fresh();var b=fresh()
		var tired: Dictionary=a.P if who=="P" else a.B
		var fresh_fighter: Dictionary=b.P if who=="P" else b.B
		tired["stamina"]=5
		if who=="P":
			a.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"});b.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"})
		else:
			a._boss_act({"kind":"punch","row":"R_STRAIGHT","body":false,"mult":1.0});b._boss_act({"kind":"punch","row":"R_STRAIGHT","body":false,"mult":1.0})
		check(who+" tired delivery is slower without changing its committed target",tired["pending"]["startup"]>fresh_fighter["pending"]["startup"] and tired["boxing"]["action"]["target"]==fresh_fighter["boxing"]["action"]["target"])
		for i in 300:a.step({"body_axis":Vector2.ZERO})
		check(who+" recovers effort at rest without negative stamina",float(tired["stamina"])>5 and float(tired["stamina"])<=100)

func rate_cases() -> void:
	for who in ["P","B"]:
		var hashes:=[]
		for hz in [30,60,144]:
			var s=fresh();var f: Dictionary=s.P if who=="P" else s.B
			f["comp"]=0;s._drop(who=="P")
			var clock:=Clock.new()
			for frame in hz*4:
				for tick in clock.advance(1.0/hz):s.step(beat(s))
			hashes.append(s.hash_state())
		check(who+" count and rise are identical at 30/60/144 render partitions",hashes[0]==hashes[1] and hashes[1]==hashes[2])

func contact_drop(who: String):
	var s=fresh()
	var target: Dictionary=s.P if who=="P" else s.B
	target["comp"]=0.1;target["no_regen_t"]=10000
	target["guard_body"]=true;target["guard_t"]=500
	for i in 20:s.step({"body_axis":Vector2.ZERO,"block":who=="P","body":true})
	if who=="P":s._boss_act({"kind":"punch","row":"R_STRAIGHT","body":false,"mult":1.0})
	else:s.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"})
	return s

func contact_cases() -> void:
	for who in ["P","B"]:
		var s=contact_drop(who)
		for i in 90:
			if s.mode!="FIGHT":break
			s.step({"body_axis":Vector2.ZERO,"block":who=="P","body":true})
		check(who+" native swept punch causes a real drop",s.mode=="EIGHT" and s.events.any(func(e):return e.get("kind")=="boxing_contact" and e["contact"]["kind"]=="hit"))
		check(who+" real drop is scored once",s.events.filter(func(e):return e.get("kind")=="drop").size()==1)
		samples.append({"case":"real contact "+who,"mode":s.mode,"events":s.events.filter(func(e):return e.get("kind") in ["boxing_contact","drop"])})

func round_case(stance: String) -> void:
	var s=fresh(stance)
	s.bstate="IDLE";s.btimer=0;s.neutral_on=true;s.delegated=true
	var clock: int=s.clock_t;var elapsed:=0;var low:=100.0;var contacts:=0;var counts:=0;var finite:=true
	while s.mode in ["FIGHT","EIGHT"] and elapsed<clock*3:
		s.step({"body_axis":Vector2.ZERO})
		for f in [s.P,s.B]:
			low=minf(low,float(f["stamina"]))
			finite=finite and is_finite(float(f["stamina"])) and float(f["stamina"])>=0 and float(f["stamina"])<=100
		for e in s.events:
			if e.get("kind")=="boxing_contact":contacts+=1
			if e.get("kind")=="drop":counts+=1
		s.events.clear();elapsed+=1
	check(stance+" sustained native segment reaches its result",s.mode in ["CARD","OVER"])
	check(stance+" full segment produces physical exchanges and fatigue",contacts>20 and low<40 and finite)
	samples.append({"case":stance+" full segment","round_clock_ticks":clock,"elapsed_ticks":elapsed,"remaining_ticks":s.clock_t,"mode":s.mode,"contacts":contacts,"drops":counts,"minimum_stamina":low})

func render_tick(s,intent: Dictionary) -> void:
	scene.sim=s
	scene.fight_view.capture(scene.player,s.P,s.B,s,"P");scene.fight_view.capture(scene.boss,s.B,s.P,s,"B")
	scene.fight_view.before_step(s);scene.prev_p=s.P["pos"];scene.prev_b=s.B["pos"]
	s.step(intent);scene._consume_events();scene._render(1);scene._hud()

func film() -> void:
	root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	await process_frame;await process_frame
	scene.controls_menu.close();scene.fight_hud.entry.hide();scene.combat_input.reset_bindings()
	DirAccess.make_dir_recursive_absolute("user://recovery-film")
	var frame:=0
	for scenario in 3:
		if "ko-film" in OS.get_cmdline_user_args() and scenario!=2:continue
		var who: String="P" if scenario==1 else "B"
		var s=fresh()
		var f: Dictionary=s.P if who=="P" else s.B
		f["comp"]=0.1;f["no_regen_t"]=10000;f["guard_body"]=true;f["guard_t"]=500
		if scenario==2:f["drops"]=2
		scene.fight_view.clock_sim=null
		var saw_fall:=false;var exposed_fall:=true
		for i in (480 if scenario==2 else 900):
			if scene.controls_menu.opened:scene.controls_menu.close()
			var intent:=beat(s)
			if s.mode=="FIGHT":intent.merge({"block":who=="P","body":true})
			if i==80:
				if who=="P":s._boss_act({"kind":"punch","row":"R_STRAIGHT","body":false,"mult":1.0})
				else:intent["punch"]="R_STRAIGHT";intent["body"]=false
			render_tick(s,intent)
			if scenario==2 and s.mode=="CARD" and int(s.P.get("boxing",{}).get("count_age",100))<90:
				saw_fall=true;exposed_fall=exposed_fall and not scene.fight_hud.details.visible
			if i%2==1:
				await process_frame;RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png("user://recovery-film/frame-%04d.png"%frame);frame+=1
			if i in [210,565,710]:
				scene.fight_view.inspection_view=true;scene._render(1)
				scene.fight_hud.details.hide() # Isolated, labelled anatomical inspection.
				await process_frame;RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png("user://recovery-%d-%s-%d.png"%[scenario,who,i])
				scene.fight_view.inspection_view=false;scene._render(1)
		check(who+" filmed real contact and "+("knockout" if scenario==2 else "successful recovery"),f["drops"]==(3 if scenario==2 else 1) and s.mode==("CARD" if scenario==2 else "FIGHT"))
		if scenario==2:check("result panel waits until the knockout fall finishes",saw_fall and exposed_fall and scene.fight_hud.details.visible and scene.fight_hud.cue.text=="SEGMENT OVER")
	scene.queue_free();await process_frame

func run() -> void:
	for stance in ["orthodox","southpaw"]:
		for who in ["P","B"]:count_case(who,stance)
	lifecycle_cases();contact_cases();effort_cases();rate_cases()
	if "rounds" in OS.get_cmdline_user_args():
		for stance in ["orthodox","southpaw"]:round_case(stance)
	if "capture" in OS.get_cmdline_user_args():await film()
	var report:={"checks":checks,"passed":checks-failures.size(),"failures":failures,"samples":samples,"foundation":"NOT_ACCEPTED"}
	FileAccess.open("user://boxing-recovery.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BOXING RECOVERY %d/%d"%[checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Reflection is a physical invariant, not a promise of identical character stats.
## The comparison swaps authored left/right tuning as well as stance and intent.
const Tests := preload("res://sim/tests.gd")
const Space := preload("res://presentation/rig_space.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
const Contact := preload("res://sim/punch_contact.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var samples := []

func _initialize() -> void: run.call_deferred()
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])

func opposite(row: String) -> String:
	return ("R_" if row.begins_with("L_") else "L_")+row.substr(2)

func fresh(style: String, learned: bool, mirrored: bool, distance := 1.5):
	var s=tests.make_sim(0,613)
	tests.quiet(s);tests.place(s,distance)
	s.bstate="ACTING";s.bqueue=[];s.btimer=100000
	s.T=s.T.duplicate(true)
	if mirrored:
		var authored: Dictionary=s.T["punch_matrix"].duplicate(true)
		for row in authored: s.T["punch_matrix"][row]=authored[opposite(row)]
	for fighter in [s.P,s.B]:
		fighter["style"]=style;fighter["stance"]="southpaw" if mirrored else "orthodox"
		fighter["boxing_training"]={}
		if learned: Techniques.equip(fighter,{"name":"RORY"})
		fighter.erase("boxing");fighter.erase("body_control")
	for i in 20: s.step({"body_axis":Vector2.ZERO})
	s.events.clear()
	return s

func reflected(point: Vector3) -> Vector3: return Vector3(-point.x,point.y,point.z)

func compare(a: Dictionary, b: Dictionary, peak: Dictionary) -> void:
	var ar: Dictionary=a["boxing"]["rig"];var br: Dictionary=b["boxing"]["rig"]
	for key in ["pelvis","chest","head","head_forward","head_up"]:
		peak[key]=maxf(peak.get(key,0),reflected(ar[key]).distance_to(br[key]))
	for key in ["shoulders","elbows","wrists","feet","knees"]:
		for i in 2: peak[key]=maxf(peak.get(key,0),reflected(ar[key][i]).distance_to(br[key][1-i]))
	peak["weight"]=maxf(peak.get("weight",0),absf(float(a["body_control"]["weight_lead"])+float(b["body_control"]["weight_lead"])-1))
	peak["effort"]=maxf(peak.get("effort",0),absf(float(a["stamina"])-float(b["stamina"])))

func resolved(events: Array) -> Array:
	var out:=[]
	for e in events:
		if e.get("kind")=="boxing_contact": out.append([e["by"],e["contact"]["kind"],e["contact"]["target"],e["tick"]])
	return out

func guard_strokes() -> void:
	# Observe physical hand travel from each existing resting guard. A block
	# request must start moving those hands before the guard clock runs out.
	for profile in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER","SAM","MARTA"]:
		for learned in [false,true]:
			for mirrored in [false,true]:
				var s=fresh(profile if profile not in ["SAM","MARTA"] else "BOXERPUNCHER",learned,mirrored)
				if profile in ["SAM","MARTA"]:
					# The simulation owns motion_identity and refreshes it from
					# the selected card. Exercise that actual identity boundary.
					s.lineup=s.lineup.duplicate(true);s.lineup[s.seg_idx]["name"]=profile
				for i in 30:s.step({"body_axis":Vector2.ZERO})
				if profile in ["SAM","MARTA"]:check(profile+" guard fixture uses its actual named identity",s.P["motion_identity"]==profile)
				var start: Array=s.P["boxing"]["rig"]["wrists"].duplicate()
				var hands:=[]
				for i in 12:
					s.step({"body_axis":Vector2.ZERO,"block":true})
					hands.append(s.P["boxing"]["rig"]["wrists"].duplicate())
				var immediate:=true;var settled:=true
				for hand in 2:
					var travel: float=Vector3(start[hand]).distance_to(hands[5][hand])
					immediate=immediate and Vector3(start[hand]).distance_to(hands[0][hand])>maxf(0.001,travel*0.01)
					settled=settled and Vector3(hands[5][hand]).distance_to(hands[11][hand])<0.001
				var label:="%s learned=%s mirrored=%s guard stroke"%[profile,learned,mirrored]
				check(label+" moves both physical hands on its first tick",immediate)
				check(label+" reaches cover within the original six ticks",settled)
				var returns:=[]
				for i in 12:
					s.step({"body_axis":Vector2.ZERO})
					returns.append(s.P["boxing"]["rig"]["wrists"].duplicate())
				var released:=true;var home:=true
				for hand in 2:
					var travel: float=Vector3(start[hand]).distance_to(hands[11][hand])
					released=released and Vector3(hands[11][hand]).distance_to(returns[0][hand])>maxf(0.001,travel*0.01)
					home=home and Vector3(returns[5][hand]).distance_to(start[hand])<0.001
				check(label+" responds physically to release on its first tick",released)
				check(label+" returns to its own resting cover in six ticks",home)
				samples.append({"case":label,"start":start,"hands":hands,"returns":returns})

func curved_routes() -> void:
	# A curved punch may open for range, but delivery must not run into
	# the fully straight IK stop halfway through its swing.
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for learned in [false,true]:
			for mirrored in [false,true]:
				for distance in [1.1,1.5,2.0]:
					for row in ["L_HOOK","R_HOOK","L_HOOKERCUT","R_HOOKERCUT","L_UPPERCUT","R_UPPERCUT","L_FLARED","R_FLARED"]:
						for body in [false,true]:
							var s=fresh(style,learned,mirrored,distance)
							var hand:=0 if row.begins_with("L_") else 1
							var angle:=0.0;var bone_error:=0.0;var count:=0
							for tick in 90:
								s.step({"body_axis":Vector2.ZERO,"punch":row,"body":body} if tick==0 else {"body_axis":Vector2.ZERO})
								var action: Dictionary=s.P["boxing"].get("action",{})
								if action.get("phase")=="flight" and float(action["progress"])>0.25:
									var rig: Dictionary=s.P["boxing"]["rig"]
									var upper: Vector3=rig["shoulders"][hand]-rig["elbows"][hand]
									var fore: Vector3=rig["wrists"][hand]-rig["elbows"][hand]
									angle=maxf(angle,rad_to_deg(upper.angle_to(fore)))
									bone_error=maxf(bone_error,maxf(absf(upper.length()-Contact.Motion.UPPER_ARM),absf(fore.length()-Contact.Motion.FOREARM)))
									count+=1
							var label:="%s learned=%s mirrored=%s %s body=%s distance=%s"%[style,learned,mirrored,row,body,distance]
							check(label+" keeps a bent arm through its curved route",count>0 and angle<175.0)
							check(label+" preserves arm lengths throughout that route",count>0 and bone_error<0.001)
							samples.append({"case":label,"max_elbow_angle_deg":angle,"bone_error_m":bone_error,"flight_samples":count})

func committed_paths() -> void:
	# A guard-height switch must move the covering hand without replacing
	# the start of the already committed working-hand path. Compare both
	# physical trajectories at range, so opponent contact cannot confound it.
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for learned in [false,true]:
			for mirrored in [false,true]:
				for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_HOOK","L_HOOKERCUT","R_HOOKERCUT","L_UPPERCUT","R_UPPERCUT","L_FLARED","R_FLARED"]:
					var held=fresh(style,learned,mirrored,3.0);var switched=fresh(style,learned,mirrored,3.0)
					for s in [held,switched]:
						for i in 30:s.step({"body_axis":Vector2.ZERO,"block":true})
						s.step({"body_axis":Vector2.ZERO,"block":true,"punch":row})
					var hand:=0 if row.begins_with("L_") else 1
					var working:=0.0;var covering:=0.0;var switched_ticks:=0
					for tick in 60:
						var action: Dictionary=held.P["boxing"].get("action",{})
						if action.get("phase")!="flight":break
						var change: bool=float(action["progress"])>=0.40
						held.step({"body_axis":Vector2.ZERO,"block":true})
						switched.step({"body_axis":Vector2.ZERO,"block":true,"body":change})
						if held.P["boxing"].get("action",{}).get("phase")!="flight":break
						var a: Dictionary=held.P["boxing"]["rig"];var b: Dictionary=switched.P["boxing"]["rig"]
						working=maxf(working,Vector3(a["wrists"][hand]).distance_to(b["wrists"][hand]))
						covering=maxf(covering,Vector3(a["wrists"][1-hand]).distance_to(b["wrists"][1-hand]))
						if change:switched_ticks+=1
					var label:="%s learned=%s mirrored=%s %s guard switch"%[style,learned,mirrored,row]
					check(label+" preserves the committed working-hand trajectory",switched_ticks>=10 and working<0.003)
					check(label+" still moves the covering hand",covering>0.05)
					samples.append({"case":label,"working_difference_m":working,"covering_difference_m":covering,"switch_ticks":switched_ticks})

func preparation_handoffs() -> void:
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for learned in [false,true]:
			for mirrored in [false,true]:
				for verb in ["JAB","R_STR","L_HOOK","R_HOOK","L_UPC","R_UPC","LT_L_HOOK","LT_R_HOOK","LT_R_UPC"]:
					var s=fresh(style,learned,mirrored,1.65)
					s.pattern=s.pattern.duplicate(true)
					s.pattern["strings"]["handoff_fixture"]={"actions":[verb],"tell":{"ms":700}}
					s.bstring="handoff_fixture";s.bstate="TELL";s.btimer=8
					for tick in 30:s._boxing_tick(1)
					var prepared: Dictionary=s.B["boxing"]["preparation"].duplicate(true)
					var before: Dictionary=s.B["boxing"]["rig"].duplicate(true)
					var instruction: Dictionary=s.parse_action(verb)[0]
					s.bstate="ACTING";s.btimer=s._boss_act(instruction)
					# Evaluate the commitment boundary at the identical pose clock.
					# It must not invent an extra loading stroke or switch aim lanes.
					Contact.sample(s.B,s.P,s._head_world(s.B,s.P,false),0)
					var action: Dictionary=s.B["boxing"]["action"]
					var after: Dictionary=s.B["boxing"]["rig"]
					var hand:=0 if str(action["row"]).begins_with("L_") else 1
					var label:="prepared %s learned=%s mirrored=%s %s"%[style,learned,mirrored,verb]
					var aim_error:=Vector3(prepared["target"]).distance_to(action["target"])
					var load_error:=absf(float(before["chain"]["load"])-float(after["chain"]["load"]))
					var wrist_error:=Vector3(before["wrists"][hand]).distance_to(after["wrists"][hand])
					check(label+" retains its preparation progress",absf(float(action["progress"])-float(prepared["progress"]))<0.00001)
					check(label+" commits the prepared physical lane",aim_error<0.002)
					check(label+" keeps the loaded body continuous",load_error<0.0001)
					check(label+" keeps the loaded glove continuous",wrist_error<0.01)
					samples.append({"case":label,"aim_error_m":aim_error,"load_error":load_error,"wrist_error_m":wrist_error})

func run() -> void:
	if "preparation-only" in OS.get_cmdline_user_args():
		preparation_handoffs()
		FileAccess.open("user://preparation-handoffs.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
		print("PREPARATION HANDOFFS :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1);return
	if "commitment-only" in OS.get_cmdline_user_args():
		committed_paths()
		FileAccess.open("user://committed-paths.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
		print("COMMITTED PATHS :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1);return
	if not "curves-only" in OS.get_cmdline_user_args():guard_strokes()
	if "guard-only" in OS.get_cmdline_user_args():
		FileAccess.open("user://guard-strokes.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
		print("GUARD STROKES :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1);return
	curved_routes()
	if "curves-only" in OS.get_cmdline_user_args():
		FileAccess.open("user://curved-routes.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
		print("CURVED ROUTES :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1);return
	committed_paths()
	for style in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
		for learned in [false,true]:
			var a=fresh(style,learned,false);var b=fresh(style,learned,true);var peak:={}
			for tick in 180:
				var axis:=Vector2.ZERO if tick<20 else Vector2.from_angle(float(tick-20)/160*TAU)*0.8
				a.step({"body_axis":axis,"block":tick>90});b.step({"body_axis":Vector2(-axis.x,axis.y),"block":tick>90})
				compare(a.P,b.P,peak);compare(a.B,b.B,peak)
			var label:="%s learned=%s body/guard disk"%[style,learned]
			check(label+" reflects the whole supported body",peak.values().all(func(v):return v<0.003))
			samples.append({"case":label,"peak_error":peak})
	for learned in [false,true]:
		for who in ["P","B"]:
			for row in ["L_STRAIGHT","R_STRAIGHT","L_FLARED","R_FLARED","L_HOOK","R_HOOK","L_HOOKERCUT","R_HOOKERCUT","L_UPPERCUT","R_UPPERCUT"]:
				for body in [false,true]:
					var a=fresh("BOXERPUNCHER",learned,false);var b=fresh("BOXERPUNCHER",learned,true);var peak:={};var ea:=[];var eb:=[]
					var contact_pose_error:=0.0;var contact_samples:=0
					if who=="B":
						a.btimer=a._boss_act({"kind":"punch","row":row,"mult":1.0,"body":body})
						b.btimer=b._boss_act({"kind":"punch","row":opposite(row),"mult":1.0,"body":body})
					for tick in 120:
						# Isolate this request and its full physical return. The story
						# VM's next authored string is not a mirrored input sequence.
						a.btimer=100000;b.btimer=100000
						var ai:={"body_axis":Vector2.ZERO};var bi:=ai.duplicate()
						if tick==0 and who=="P":
							ai.merge({"punch":row,"body":body});bi.merge({"punch":opposite(row),"body":body})
						a.events.clear();b.events.clear();a.step(ai);b.step(bi)
						ea.append_array(a.events);eb.append_array(b.events)
						compare(a.P,b.P,peak);compare(a.B,b.B,peak)
						for s in [a,b]:
							var fighter: Dictionary=s.P if who=="P" else s.B
							var action: Dictionary=fighter["boxing"].get("action",{})
							if action.get("phase","")=="flight":
								# Stopping at the glove's current point requires no
								# correction. Contact must not choose a new elbow plane.
								var probe: Dictionary=fighter.duplicate(true)
								var hand:=0 if str(action["row"]).begins_with("L_") else 1
								var rig: Dictionary=fighter["boxing"]["rig"]
								var stop_contact:={"kind":"hit","time":1.0,"point":Space.ground(fighter["pos"])+rig["wrists"][hand]}
								Contact.finish(probe,stop_contact)
								# A partial finish used to throw on missing kind/time,
								# leaving the old rig untouched and falsely passing.
								if probe["boxing"].get("contact",{})!=stop_contact:contact_pose_error=INF
								for arm in 2:
									contact_pose_error=maxf(contact_pose_error,Vector3(probe["boxing"]["rig"]["elbows"][arm]).distance_to(rig["elbows"][arm]))
								contact_samples+=1
					var label:="%s %s body=%s learned=%s"%[who,row,body,learned]
					check(label+" preserves mirrored anatomy and support",peak.values().all(func(v):return v<0.003))
					check(label+" preserves actual contact and timing",resolved(ea)==resolved(eb) and resolved(ea).size()==1)
					check(label+" contact preserves the existing elbow plane",contact_samples>0 and contact_pose_error<0.001)
					samples.append({"case":label,"peak_error":peak,"orthodox":resolved(ea),"southpaw":resolved(eb),"contact_pose_error_m":contact_pose_error,"contact_samples":contact_samples})
	for who in ["P","B"]:
		for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(0.7,-0.7),Vector2(-0.7,0.7)]:
			var a=fresh("BOXERPUNCHER",true,false,2.0);var b=fresh("BOXERPUNCHER",true,true,2.0);var peak:={}
			var root_error:=0.0
			var start: Vector2=a.P["pos"] if who=="P" else a.B["pos"]
			for tick in 135:
				var ai:={"body_axis":Vector2.ZERO,"block":true};var bi:=ai.duplicate()
				if tick==4:
					if who=="P": ai["pocket_step"]=axis;bi["pocket_step"]=Vector2(-axis.x,axis.y)
					else:
						a._boxing_queue_step(Vector2(-axis.x,axis.y),0.48);b._boxing_queue_step(Vector2(axis.x,axis.y),0.48)
				a.step(ai);b.step(bi);compare(a.P,b.P,peak);compare(a.B,b.B,peak)
				root_error=maxf(root_error,reflected(Space.ground(a.P["pos"])).distance_to(Space.ground(b.P["pos"])))
				root_error=maxf(root_error,reflected(Space.ground(a.B["pos"])).distance_to(Space.ground(b.B["pos"])))
			var label:="%s supported step %s"%[who,axis]
			var finish: Vector2=a.P["pos"] if who=="P" else a.B["pos"]
			check(label+" actually moves through the native step input",start.distance_to(finish)>0.40)
			check(label+" mirrors landing, loaded leg and facing",peak.values().all(func(v):return v<0.003) and root_error<0.003)
			samples.append({"case":label,"peak_error":peak,"root_error":root_error})
	for sequence in [["L_STRAIGHT","R_STRAIGHT","L_HOOK"],["L_STRAIGHT","L_STRAIGHT","R_UPPERCUT"],["L_UPPERCUT","R_UPPERCUT","L_HOOK"]]:
		var a=fresh("BOXERPUNCHER",true,false,1.3);var b=fresh("BOXERPUNCHER",true,true,1.3);var peak:={};var ea:=[];var eb:=[]
		var restored=null;var exact:=true
		var divergence:={}
		for tick in 185:
			var axis:=Vector2(0.5,0.3) if tick<12 else Vector2.ZERO
			var ai:={"body_axis":axis,"block":true};var bi:={"body_axis":Vector2(-axis.x,axis.y),"block":true}
			for n in 3:
				if tick==16+n*20: ai["punch"]=sequence[n];bi["punch"]=opposite(sequence[n])
			if tick==105: ai["pocket_step"]=Vector2(-0.7,-0.7);bi["pocket_step"]=Vector2(0.7,-0.7)
			a.events.clear();b.events.clear();a.step(ai);b.step(bi)
			ea.append_array(a.events);eb.append_array(b.events);compare(a.P,b.P,peak);compare(a.B,b.B,peak)
			if divergence.is_empty() and not peak.values().all(func(v):return v<0.003):
				divergence={"tick":tick,"orthodox_P":a.P.duplicate(true),"southpaw_P":b.P.duplicate(true),"orthodox_B":a.B.duplicate(true),"southpaw_B":b.B.duplicate(true)}
			if restored!=null:
				restored.events.clear();restored.step(bi)
				exact=exact and restored.hash_state()==b.hash_state() and restored.events==b.events
			if tick==45:
				restored=fresh("BOXERPUNCHER",true,true,1.3);restored.restore(b.snapshot())
		var label:="guarded combination %s"%[sequence]
		check(label+" mirrors its recovery and exit",peak.values().all(func(v):return v<0.003) and resolved(ea)==resolved(eb))
		check(label+" restores an in-flight southpaw exchange exactly",exact)
		samples.append({"case":label,"peak_error":peak,"orthodox":resolved(ea),"southpaw":resolved(eb),"restore_exact":exact,"first_divergence":divergence})
	preparation_handoffs()
	var file:=FileAccess.open("user://stance-coherence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"));file.close()
	print("STANCE COHERENCE VERDICT :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

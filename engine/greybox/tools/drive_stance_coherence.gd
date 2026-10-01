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

func run() -> void:
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
								Contact.finish(probe,{"point":Space.ground(fighter["pos"])+rig["wrists"][hand]})
								contact_pose_error=maxf(contact_pose_error,Vector3(probe["boxing"]["rig"]["elbows"][hand]).distance_to(rig["elbows"][hand]))
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
	var file:=FileAccess.open("user://stance-coherence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"));file.close()
	print("STANCE COHERENCE VERDICT :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

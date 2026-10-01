extends SceneTree
## Player and opponent must use the same physical control path in the real core.
const Tests := preload("res://sim/tests.gd")
const Body := preload("res://sim/body_control.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var samples := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("[%s] %s"%["PASS" if ok else "FAIL",label])

func fresh(distance := 1.6):
	var s=tests.make_sim(0,471)
	tests.quiet(s); tests.place(s,distance)
	s.bstate="ACTING"; s.bqueue=[]; s.btimer=100000
	# Keep the tactical opponent still while an isolated movement is measured.
	# Its body, feet, resources and collision continue through the real step.
	s.neutral_on=true
	s.bidle.merge({"authored":true,"kind":"hold","range_m":1.6,"band_m":10.0,"cut_ring":false,"retreat_mps":0.0,"tell_mps":0.0,"taunt_s":0.0,"tempo_s":0.0},true)
	s.step({"body_axis":Vector2.ZERO}); s.events.clear()
	return s

func ticks(s, count: int, intent := {}) -> Array:
	var events := []
	for i in count:
		s.events.clear(); s.step({"body_axis":Vector2.ZERO}.merged(intent,true)); events.append_array(s.events.duplicate(true))
	return events

func run() -> void:
	for kind in ["SLIP","DUCK","LEAN","WEAVE"]:
		for side in [-1,1]:
			var s=fresh(); var origin: Vector2=s.B["pos"]
			s._set_dodge(s.P,kind,side); s._set_dodge(s.B,kind,side)
			var peak := 0.0; var weight := 0.0; var exact := true; var torso_exact := true; var symmetry := true
			var minimum_x := 0.0; var maximum_x := 0.0
			for i in 110:
				ticks(s,1)
				var body: Dictionary=s.B["body_control"]
				peak=maxf(peak,Vector2(body["axis"]).length()); weight=maxf(weight,absf(float(body["weight_lead"])-0.5))
				minimum_x=minf(minimum_x,float(body["axis"].x)); maximum_x=maxf(maximum_x,float(body["axis"].x))
				var offset: Vector3=Body.offsets(s.B)["head"]
				var f: Vector2=Body.forward(s.B,s.P); var r:=Vector2(-f.y,f.x)
				var head: Dictionary=s._head_world(s.B,s.P)
				exact=exact and Vector2(head["p"]).distance_to(s.B["pos"]+r*offset.x+f*offset.z)<0.00001 and absf(float(head["h"])-(1.55+offset.y))<0.00001
				var torso: Vector3=Body.offsets(s.B)["torso"]
				var region: Dictionary=s.contact_region(s.P,s.B,"L_STRAIGHT",true)
				torso_exact=torso_exact and Vector2(region["target"]).distance_to(s.B["pos"]+r*torso.x+f*torso.z)<0.00001
				symmetry=symmetry and Vector2(body["axis"]).distance_to(s.P["body_control"]["axis"])<0.00001
			check("%s %d moves the opponent through continuous body/support/effort"%[kind,side],peak>0.4 and weight>0.015 and float(s.B["body_control"]["effort"])>0.1)
			check("%s %d adds no separate head displacement"%[kind,side],exact)
			check("%s %d adds no separate torso displacement to range queries"%[kind,side],torso_exact)
			check("%s %d player and opponent obey the same control response"%[kind,side],symmetry)
			check("%s %d returns to neutral without moving the feet/root"%[kind,side],s.B["pos"].distance_to(origin)<0.00001 and Vector2(s.B["body_control"]["axis"]).length()<0.001)
			if kind=="WEAVE":check("weave crosses the continuous dip arc side=%d"%side,minimum_x < -0.20 and maximum_x > 0.20)
			samples.append({"kind":kind,"side":side,"peak_axis":peak,"weight_shift":weight,"effort":s.B["body_control"]["effort"]})
	var s=fresh(); var origin: Vector2=s.P["pos"]
	ticks(s,60,{"move":Vector2(1,-1),"sprint":true})
	check("legacy movement cannot add free travel to a native fighter",s.P["pos"].distance_to(origin)<0.00001)
	s=fresh(); s._set_dodge(s.P,"SLIP",-1); ticks(s,12,{"body_axis":Vector2.RIGHT})
	check("live player intent takes precedence over an authored defensive request",s.P["body_control"]["axis"].x>0.5)
	for direction in ["toward","away","lateral","center"]:
		s=fresh(); origin=s.B["pos"]
		var stamina: float=s.B["stamina"]
		s.btimer=s._boss_act({"kind":"move","dir":direction,"dist":2.0,"guard":true})
		check(direction+" reserves step and recovery in the opponent action clock",s.btimer==s.ms(1000.0*(Body.STEP_SECONDS+Body.STEP_RECOVERY_SECONDS)))
		check(direction+" request cannot teleport the opponent",s.B["pos"]==origin and not s.B["boxing"].has("travel"))
		var events:=ticks(s,1)
		check(direction+" commits through the shared step and pays effort",not s.B["body_control"]["step"].is_empty() and stamina-float(s.B["stamina"])>2.8)
		var peak: float=s.B["pos"].distance_to(origin);var jumped:=0.0;var prior: Vector2=s.B["pos"]
		var grounded:=true
		for i in 80:
			events.append_array(ticks(s,1));peak=maxf(peak,s.B["pos"].distance_to(origin));jumped=maxf(jumped,s.B["pos"].distance_to(prior));prior=s.B["pos"]
			grounded=grounded and s.B["body_control"]["planted"].any(func(x):return x)
		check(direction+" is bounded and regathers support",peak>0.35 and peak<=Body.STEP_M+0.001 and jumped<0.04 and grounded and s.B["body_control"]["step"].is_empty() and s.B["body_control"]["gait"].is_empty())
		print("STEP %s peak=%.5f max_tick=%.5f grounded=%s body=%s"%[direction,peak,jumped,grounded,s.B["body_control"]])
		check(direction+" reports its actual footwork outcome",events.any(func(e):return e.get("kind")=="footwork" and e.get("who")=="B" and e.get("outcome")=="completed"))
	s=fresh(0.75);origin=s.P["pos"];var boss_origin: Vector2=s.B["pos"]
	s.btimer=s._boss_act({"kind":"move","dir":"toward","dist":2.0,"guard":false});ticks(s,80)
	check("crowding shortens the opponent step without dragging the player",s.B["pos"].distance_to(boss_origin)<0.04 and s.P["pos"].distance_to(origin)<0.00001)
	s=fresh();s.B["stamina"]=0.0;boss_origin=s.B["pos"]
	s.btimer=s._boss_act({"kind":"move","dir":"lateral","dist":0.48,"guard":false});var refused:=ticks(s,8)
	check("exhausted opponent cannot borrow a free step",s.B["pos"].distance_to(boss_origin)<0.00001 and refused.any(func(e):return e.get("who")=="B" and e.get("reason")=="effort"))
	s=fresh();s._boxing_queue_step(Vector2.RIGHT,0.20)
	s._boxing_tick(0)
	check("zero opponent clock does not consume its queued intent",s.B["boxing"].has("footwork_request") and s.B["body_control"]["step"].is_empty())
	ticks(s,8);var restored=fresh();restored.restore(s.snapshot());var same:=true
	for i in 110:
		ticks(s,1);ticks(restored,1);same=same and s.hash_state()==restored.hash_state() and var_to_bytes(s.events)==var_to_bytes(restored.events)
	check("mid-step save restores both intent and physical travel exactly",same)
	for distance in [0.20,2.0]:
		s=fresh();boss_origin=s.B["pos"]
		s.B["boxing"]["travel"]={"from":boss_origin-Vector2.RIGHT,"to":boss_origin+Vector2.RIGHT*distance,"t":8,"duration":30}
		ticks(s,80)
		check("old move snapshot migrates only remaining bounded travel %.2f"%distance,not s.B["boxing"].has("travel") and absf(s.B["pos"].distance_to(boss_origin)-minf(distance,Body.STEP_M))<0.001)
	s=fresh();s._boxing_queue_step((s.P["pos"]-s.B["pos"]).normalized(),0.48);ticks(s,8)
	boss_origin=s.B["pos"]
	s._boss_act({"kind":"punch","row":"L_STRAIGHT","body":false,"mult":1.0})
	check("opponent step-punch uses the same entry modifier without a second lunge",s.B["pending"]["stepping"] and "STEPPING" in s.B["pending"]["mods"] and s.B["pos"]==boss_origin)
	var expected: int=s.ms(float(s.T["punch_matrix"]["L_STRAIGHT"]["startup_ms"])*float(s.B["pkg"].get("startup_mult",1.0))*float(s.T["modifiers"]["STEPPING"]["telegraph_mult"])/float(s._gassed(s.B)["hand_speed"]))
	check("opponent entry pays the shared step-punch telegraph",s.B["pending"]["startup"]==expected)
	for interruption in ["clinch","count"]:
		s=fresh();s._boxing_queue_step(Vector2.RIGHT,0.48);ticks(s,8);s._boxing_queue_step(Vector2.RIGHT,0.48)
		if interruption=="clinch":s._start_clinch("B")
		else:s._drop(true)
		ticks(s,1)
		check(interruption+" clears opponent queued footwork and physical travel",not s.B.has("body_control") and not s.B.has("boxing"))
		s.mode="FIGHT";s.clinch={};s.clinch_t=0;boss_origin=s.B["pos"];ticks(s,60)
		check(interruption+" cannot resume stale travel after the break",s.B["pos"]==boss_origin)
	s=fresh(2.8);s.neutral_on=false;s.bstate="IDLE";var distances:=[];var steps:=0;var still_ticks:=0;var previous: Vector2=s.B["pos"]
	for i in 300:
		for e in ticks(s,1):
			if e.get("who")=="B" and e.get("outcome")=="completed":distances.append(e["travel"]);steps+=1
		if s.B["pos"].distance_to(previous)<0.00001:still_ticks+=1
		previous=s.B["pos"]
	check("normal opponent approach is discrete supported steps with recovery",steps>=2 and still_ticks>30 and distances.all(func(d):return d<=Body.STEP_M+0.001) and s.B["pos"].distance_to(s.P["pos"])<2.0)
	print("APPROACH steps=%d stationary_ticks=%d range=%.5f travel=%s"%[steps,still_ticks,s.B["pos"].distance_to(s.P["pos"]),distances])
	s=fresh(1.94);s.neutral_on=false;s.bstate="IDLE";boss_origin=s.B["pos"]
	var near_range:=ticks(s,300)
	check("opponent holds its range band without paying for centimetre shuffles",s.B["pos"]==boss_origin and not near_range.any(func(e):return e.get("kind")=="footwork" and e.get("who")=="B"))
	for style in ["OUTBOXER","SWARMER","SLUGGER","BOXERPUNCHER"]:
		s=fresh(2.8);s.bstate="IDLE";s.P["style"]=style;s.delegated=true
		origin=s.P["pos"];var delegated_steps:=[];var continuous:=true;var prior: Vector2=s.P["pos"]
		for i in 480:
			for e in ticks(s,1):
				if e.get("kind")=="footwork" and e.get("who","")!="B" and e.get("outcome")=="completed":delegated_steps.append(e["travel"])
			continuous=continuous and s.P["pos"].distance_to(prior)<0.04;prior=s.P["pos"]
		check(style+" delegated native fighter closes range with bounded physical steps",s.P["pos"].distance_to(origin)>0.5 and delegated_steps.size()>=2 and delegated_steps.all(func(d):return d<=Body.STEP_M+0.001) and continuous)
		var replay=fresh();replay.restore(s.snapshot());var deterministic:=true
		for i in 90:
			ticks(s,1);ticks(replay,1);deterministic=deterministic and s.hash_state()==replay.hash_state() and var_to_bytes(s.events)==var_to_bytes(replay.events)
		check(style+" delegated native movement restores its tactical and physical state",deterministic)
	s=fresh(1.0);s.delegated=true;s.P["stats"]["RFX"]=99;s._start_clinch("B");var clinch_events:=ticks(s,400)
	check("delegated native clinch still delivers the profile's directional cue taps",clinch_events.any(func(e):return e.get("kind")=="clinch_beat"))
	var legacy=tests.make_sim(0,471);tests.quiet(legacy);legacy._set_dodge(legacy.B,"DUCK",1)
	legacy.B["dodge_t"]=15
	check("legacy playback retains its original categorical defense geometry",not legacy.B.has("body_control") and float(legacy._head_world(legacy.B,legacy.P)["h"])<1.20)
	var file:=FileAccess.open("user://shared-control.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"));file.close()
	print("SHARED CONTROL VERDICT :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

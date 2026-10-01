extends SceneTree
## Shared learned techniques exercised through the existing combat core.
const Tests := preload("res://sim/tests.gd")
const Techniques := preload("res://sim/boxing_techniques.gd")
const Contact := preload("res://sim/punch_contact.gd")
const Motion := preload("res://presentation/boxing_motion.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var observations := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])

func fresh(distance := 1.4):
	var s = tests.make_sim(0,719)
	tests.quiet(s); tests.place(s,distance)
	s.bstate = "ACTING"; s.bqueue = []; s.btimer = 100000
	s.step({"body_axis":Vector2.ZERO})
	s.events.clear()
	return s

func ticks(s, count: int, intent := {}) -> Array:
	var events := []
	for i in count:
		s.events.clear(); s.step({"body_axis":Vector2.ZERO}.merged(intent,true)); events.append_array(s.events.duplicate(true))
	return events

func run() -> void:
	var s = fresh()
	check("normal starter match equips learned techniques independently of archetype",s.P["boxing_training"]["guard"] == "rising_guard" and s.P["style"] == "BOXERPUNCHER")
	var stats: Dictionary = s.P["stats"].duplicate()
	var equipped: Dictionary = s.P["boxing_training"].duplicate(true)
	check("conflicting guards are rejected while retaining valid equipment",not Techniques.equip(s.P,{"boxing_training":{"guard":["rising_guard","other"]}}).is_empty() and s.P["boxing_training"] == equipped)
	check("technique equipment does not rewrite progression stats",s.P["stats"] == stats)
	check("malformed training fails without replacing the valid build",not Techniques.equip(s.P,{"boxing_training":"invalid"}).is_empty() and s.P["boxing_training"] == equipped)
	for stance in ["orthodox","southpaw"]:
		for archetype in ["BOXERPUNCHER","OUTBOXER","SWARMER","SLUGGER"]:
			s = fresh(1.8)
			s.P["style"] = archetype; s.P["stance"] = stance
			s.P.erase("boxing"); s.P.erase("body_control"); ticks(s,20)
			var rig: Dictionary = s.P["boxing"]["rig"]
			var lead := 0 if stance == "orthodox" else 1
			var rear := 1-lead
			var lead_w: Vector3 = rig["wrists"][lead]; var rear_w: Vector3 = rig["wrists"][rear]
			# Skull + glove radii total 0.32m. The old <0.29m centre-distance
			# assertion required an intersection to qualify as a rear jaw guard.
			var jaw_gap := rear_w.distance_to(rig["head"])-0.32
			var jaw_height := rear_w.y-Vector3(rig["head"]).y
			check("%s %s raised bent lead forearm and clear rear jaw guard"%[stance,archetype],lead_w.y-Vector3(rig["elbows"][lead]).y > 0.16 and (lead_w-rear_w).dot(rig["forward"]) > 0.13 and jaw_gap>=-0.001 and jaw_gap<0.03 and jaw_height>-0.20 and jaw_height<0.03 and lead_w.distance_to(rig["shoulders"][lead]) < 0.62)
			var exact := true
			for hand in 2:
				exact = exact and absf(Vector3(rig["shoulders"][hand]).distance_to(rig["elbows"][hand])-Motion.UPPER_ARM) < 0.001 and absf(Vector3(rig["elbows"][hand]).distance_to(rig["wrists"][hand])-Motion.FOREARM) < 0.001
			check("%s %s retains fixed arm bones"%[stance,archetype],exact)
	for distance in [1.05,1.35,1.8,3.0]:
		for row in ["L_UPPERCUT","R_UPPERCUT"]:
			s = fresh(distance)
			s.step({"body_axis":Vector2.ZERO,"punch":row})
			var action: Dictionary = s.P["boxing"]["action"].duplicate(true)
			var hand := 0 if row.begins_with("L_") else 1
			var start: Vector3 = s.P["boxing"]["rig"]["wrists"][hand]
			var low := start.y; var far := 0.0; var bones := true
			var events: Array = s.events.duplicate(true)
			for i in 140:
				events.append_array(ticks(s,1))
				var rig: Dictionary = s.P["boxing"]["rig"]
				low = minf(low,Vector3(rig["wrists"][hand]).y)
				far = maxf(far,(Vector3(rig["wrists"][hand])-start).dot(action["forward"]))
				bones = bones and absf(Vector3(rig["shoulders"][hand]).distance_to(rig["elbows"][hand])-Motion.UPPER_ARM)<0.001 and absf(Vector3(rig["elbows"][hand]).distance_to(rig["wrists"][hand])-Motion.FOREARM)<0.001
			var results := events.filter(func(e):return e.get("kind")=="boxing_contact" and e.get("by")=="P")
			check("%s at %.2f selects one committed rising route"%[row,distance],not action["technique"].is_empty() and results.size()==1)
			check("%s at %.2f does not stretch either arm bone"%[row,distance],bones)
			if distance < 1.20: check(row+" compact preparation stays near its defensive home",start.y-low<0.24)
			if distance > 2.5: check(row+" exposed long miss does not home or auto-step",results[0]["contact"]["kind"]=="miss" and s.P["pos"].distance_to(Vector2(0,distance/2))<0.001)
			observations.append({"row":row,"distance":distance,"route":action["technique"],"drop":start.y-low,"forward_travel":far,"contact":results})
	for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_HOOK"]:
		s=fresh(); s.step({"body_axis":Vector2.ZERO,"punch":row})
		check(row+" remains its own complete shared punch family",s.P["boxing"]["action"]["row"] == row and s.P["boxing"]["action"]["technique"].is_empty())
	s=fresh(1.05); s.step({"body_axis":Vector2.ZERO,"punch":"R_UPPERCUT","body":true})
	check("body modifier chooses a supported shovel route",s.P["boxing"]["action"]["technique"]["id"]=="shovel")
	s=fresh(1.8); Techniques.equip(s.B,{"boxing_training":equipped})
	s.btimer=s._boss_act({"kind":"punch","row":"R_UPPERCUT","body":false,"mult":1.0})
	check("opponent equips and uses the identical learned rising resolver",s.B["boxing"]["action"]["technique"]["id"]=="rangy")
	var saved: Dictionary=s.snapshot(); var restored=fresh(); restored.restore(saved)
	var identical := true
	for i in 130:
		ticks(s,1); ticks(restored,1)
		identical = identical and s.hash_state()==restored.hash_state() and var_to_bytes(s.events)==var_to_bytes(restored.events)
	check("equipped techniques and committed recovery restore exactly",identical)
	for proficiency in [0.2,1.0]:
		s=fresh(1.8)
		var training := equipped.duplicate(true); training["learned"]["rangy_rising"]=proficiency
		Techniques.equip(s.P,{"boxing_training":training})
		s.step({"body_axis":Vector2.ZERO,"punch":"R_UPPERCUT"})
		check("proficiency %.1f always accepts the same deliberate uppercut"%proficiency,s.P["boxing"]["action"]["row"]=="R_UPPERCUT")
		observations.append({"proficiency":proficiency,"route":s.P["boxing"]["action"]["technique"]})
	var novice: Dictionary=observations[-2]["route"]; var expert: Dictionary=observations[-1]["route"]
	check("training reduces preparation effort and recovery without increasing reach",novice["drop"]>expert["drop"] and novice["effort"]>expert["effort"] and novice["recovery"]>expert["recovery"] and novice["reach"]==expert["reach"])
	s=fresh(1.35)
	var effort_before: float=s.P["stamina"]
	s.step({"body_axis":Vector2.ZERO,"punch":"L_UPPERCUT"})
	var charged: float=s.P["pending"]["stamina_cost"]
	check("compact effort economy is charged once even at full stamina",absf(effort_before-float(s.P["stamina"])-charged)<0.05 and charged<float(s.T["punch_matrix"]["L_UPPERCUT"]["stamina"]))
	s._feint()
	check("feint refunds the actual learned-route cost and retains its own effort",absf(effort_before-float(s.P["stamina"])-float(s.T["feint"]["stamina"]))<0.05)
	for low in [false,true]:
		s=fresh(1.5); ticks(s,30,{"block":true,"body":low})
		s.btimer=s._boss_act({"kind":"punch","row":"R_STRAIGHT","body":true,"mult":1.0})
		var exchange:=ticks(s,100,{"block":true,"body":low})
		var contact:=exchange.filter(func(e):return e.get("kind")=="boxing_contact" and e.get("by")=="B")
		check("raised guard body counterplay low=%s"%low,contact.size()==1 and contact[0]["contact"]["kind"]==("guard" if low else "hit") and contact[0]["contact"]["target"]=="body")
	# An uppercut and diagonal exit alone are not a read-and-counter signature.
	s=fresh(1.8); s.P["boxing"]["evasion"]={"clock":-100,"axis":Vector2.UP,"row":"R_STRAIGHT"}
	s.step({"body_axis":Vector2.ZERO,"punch":"L_UPPERCUT"})
	check("an expired evasion cannot manufacture Northern Rising",not s.P["boxing"]["action"]["rising_counter"])
	s=fresh(1.8)
	s.btimer=s._boss_act({"kind":"punch","row":"L_STRAIGHT","body":true,"mult":1.0})
	ticks(s,8)
	s.step({"body_axis":Vector2.ZERO,"punch":"R_UPPERCUT","power":true})
	var interrupted:=ticks(s,120)
	check("an incoming body jab interrupts a committed long rising punch",interrupted.any(func(e):return e.get("kind")=="punch_interrupted" and e.get("who")=="P") and not interrupted.any(func(e):return e.get("kind")=="hit" and e.get("on")=="B"))
	observations.append({"counterplay":"jab interrupts long rise","events":interrupted.filter(func(e):return e.get("kind") in ["boxing_contact","punch_interrupted","hit"])})
	await signature_checks()
	if "capture" in OS.get_cmdline_user_args(): await render_review()
	var report := FileAccess.open("user://northern-rising.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); report.close()
	print("NORTHERN RISING VERDICT :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func signature_checks() -> void:
	for stance in ["orthodox","southpaw"]: signature_stance(stance)

func signature_stance(stance: String) -> void:
	var lead_row := "L_UPPERCUT" if stance=="orthodox" else "R_UPPERCUT"
	var rear_row := "R_UPPERCUT" if stance=="orthodox" else "L_UPPERCUT"
	var exit_row := "L_STRAIGHT" if stance=="orthodox" else "R_STRAIGHT"
	for mode in ["ladder","exit","counter","blocked","low_guard","wall","stagger"]:
		var s=fresh(1.8 if mode=="counter" else 1.35)
		s.P["stance"]=stance; s.P.erase("boxing"); s.P.erase("body_control")
		s.B["stance"]=stance;s.B.erase("boxing");s.B.erase("body_control")
		if mode=="wall":
			s.P["pos"]+=Vector2(3.5,2.825); s.B["pos"]+=Vector2(3.5,2.825)
			s.P.erase("boxing"); s.P.erase("body_control"); s.B.erase("boxing"); s.B.erase("body_control")
		var events := []
		# A correctly placed low guard can obstruct the early rising lane.
		# Retain that negative case; the positive sequence uses the existing
		# hands-down invitation to create a real opening without hiding surfaces.
		s.B["guard_body"] = mode=="low_guard";s.B["guard_t"]=500 if mode in ["blocked","low_guard"] else 0
		if mode not in ["blocked","low_guard"]:s.hands_down_t=500
		ticks(s,30)
		if mode=="counter":
			s.btimer=s._boss_act({"kind":"punch","row":"R_STRAIGHT" if stance=="orthodox" else "L_STRAIGHT","body":false,"mult":1.0})
			events.append_array(ticks(s,50,{"body_axis":Vector2(0,-1)}))
			events.append_array(ticks(s,8))
		s.step({"body_axis":Vector2.ZERO,"punch":lead_row}); events.append_array(s.events.duplicate(true))
		var launched := false
		for i in 150:
			tests.clear_defense(s.B)
			s.B["guard_body"] = mode=="low_guard";s.B["guard_t"]=500 if mode in ["blocked","low_guard"] else 0
			# Scripted passive partner holds the same visible invitation through
			# the exchange. The production AI normally withdraws it on a punch.
			if mode not in ["blocked","low_guard"]:s.hands_down_t=500
			var intent := {}
			if mode=="stagger" and not s.P["boxing"].get("technique_flow",{}).get("windows",{}).is_empty(): s.P["busy_t"]=100
			if mode in ["ladder","blocked","stagger"] and not launched and Contact.transition(s.P,rear_row)["allowed"]:
				intent["punch"]=rear_row; launched=true
			elif mode in ["exit","counter","wall"] and not launched and Contact.transition(s.P,"EXIT")["allowed"]:
				intent["pocket_step"]=Vector2(1,-1).normalized(); launched=true
			if mode in ["exit","wall"] and not s.P.get("body_control",{}).get("step",{}).is_empty() and float(s.P["body_control"]["step"]["travel"])>.13 and Contact.transition(s.P,exit_row)["allowed"]: intent["punch"]=exit_row
			events.append_array(ticks(s,1,intent))
		observations.append({"signature_case":mode,"stance":stance,"events":events.filter(func(e):return e.get("kind") in ["boxing_contact","boxing_signature","punch","pocket_step"]),"flow":s.P["boxing"].get("technique_flow",{})})
		var recognized := events.filter(func(e):return e.get("kind")=="boxing_signature")
		if mode in ["blocked","low_guard","wall","stagger"]: check(stance+" "+mode+" prevents completing a signature",recognized.is_empty())
		else: check(stance+" actual inputs compose "+mode,not recognized.is_empty())

func render_review() -> void:
	root.size = Vector2i(1280,720)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame; await process_frame
	scene.controls_menu.close(); scene.fight_hud.entry.hide()
	for stance in ["orthodox","southpaw"]:
		for variant in ["guard","compact","rangy"]:
			var s=fresh(1.35 if variant=="compact" else 1.8)
			s.P["stance"]=stance; s.P.erase("boxing"); s.P.erase("body_control")
			s.B["guard_body"]=true; s.B["guard_t"]=500
			var maximum := -1.0; var saved := {}
			for i in 100:
				tests.clear_defense(s.B); s.B["guard_t"]=500
				var intent := {}
				if i==25 and variant!="guard": intent["punch"]="L_UPPERCUT" if stance=="orthodox" else "R_UPPERCUT"
				ticks(s,1,intent)
				var rig: Dictionary=s.P["boxing"]["rig"]
				var hand := 0 if stance=="orthodox" else 1
				var amount := Vector3(rig["wrists"][hand]).distance_to(rig["hand_homes"][hand])
				if amount>maximum: maximum=amount; saved=s.snapshot()
			s.restore(saved); scene.sim=s; scene.prev_p=s.P["pos"]; scene.prev_b=s.B["pos"]
			scene.fight_view.clock_sim=null
			for diagnostic in [false,true]:
				scene.fight_view.inspection_view=diagnostic; scene._render(1); scene._hud()
				await process_frame; RenderingServer.force_draw(false)
				var path := "user://northern-%s-%s-%s.png"%[stance,variant,"diagnostic" if diagnostic else "chase"]
				check("rendered "+path,root.get_texture().get_image().save_png(path)==OK)
	scene.queue_free(); await process_frame

extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_punch_contact.gd -- welcome
## Focused physical-contact proofs plus actual production-scene rendering.
const Tests := preload("res://sim/tests.gd")
const Contact := preload("res://sim/punch_contact.gd")
const Space := preload("res://presentation/rig_space.gd")
var tests := Tests.new()
var checks := 0
var failures := []
var samples := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])

func fresh(distance := 1.5):
	var s = tests.make_sim(0,781)
	tests.quiet(s); tests.place(s,distance)
	s.bstate = "ACTING"; s.bqueue = []; s.btimer = 100000
	s.step({"body_axis":Vector2.ZERO})
	s.events.clear()
	return s

func strokes(s, n: int, intent := {}) -> Array:
	var events := []
	for i in n:
		s.events.clear(); s.step({"body_axis":Vector2.ZERO}.merged(intent,true)); events.append_array(s.events.duplicate(true))
	return events

func run() -> void:
	if "exchanges-only" in OS.get_cmdline_user_args():
		exchanges()
		print("EXCHANGES :: %s (%d/%d)"%["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1);return
	guard_continuity()
	if "guard-only" in OS.get_cmdline_user_args():
		var report := FileAccess.open("user://guard-continuity.json",FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t")); report.close()
		print("GUARD VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1); return
	continuations()
	if "continuations-only" in OS.get_cmdline_user_args():
		var report := FileAccess.open("user://continuations.json",FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t")); report.close()
		print("CONTINUATION VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
		quit(0 if failures.is_empty() else 1); return
	var mixed = fresh()
	mixed.pattern = mixed.pattern.duplicate(true)
	mixed.pattern["strings"]["contact_fixture"] = {"actions":["MIXED_STRING(3)"],"tell":{"ms":700}}
	mixed.bstring = "contact_fixture"; mixed.bstate = "TELL"
	var rng_before: int = mixed.rng.state
	for i in 40: mixed._boxing_tick(1)
	check("posing an unresolved mixed tell never consumes tactical RNG",mixed.rng.state == rng_before and mixed.B["boxing"]["preparation"].is_empty())
	var t := Contact.moving_capsule(Vector3(-2,0,0),Vector3(2,0,0),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,0.1)
	check("fast glove crosses a thin target between endpoints",absf(t - 0.475) < 0.0001)
	t = Contact.moving_capsule(Vector3.ZERO,Vector3.ZERO,Vector3(-2,-1,0),Vector3(-2,1,0),Vector3(2,-1,0),Vector3(2,1,0),0.1)
	check("moving forearm crosses a stationary glove between ticks",absf(t - 0.475) < 0.0001)
	check("separated parallel sweeps remain misses",Contact.moving_capsule(Vector3(-2,1,0),Vector3(2,1,0),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,0.1) < 0)
	check("sphere tangency remains a contact",absf(Contact.moving_capsule(Vector3(-2,0.1,0),Vector3(2,0.1,0),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,0.1)-0.5) < 0.0001)
	var surfaces := [{"part":"head","kind":"hit","target":"head","a":Vector3(1,0,0),"b":Vector3(1,0,0),"r":0.18},{"part":"glove0","kind":"guard","target":"head","a":Vector3.ZERO,"b":Vector3.ZERO,"r":0.14}]
	var result := Contact.sweep(Vector3(-2,0,0),Vector3(2,0,0),surfaces,surfaces)
	check("earlier glove interception wins over head behind it",result.get("part") == "glove0")
	var families := ["L_STRAIGHT","R_STRAIGHT","L_FLARED","R_FLARED","L_HOOK","R_HOOK","L_HOOKERCUT","R_HOOKERCUT","L_UPPERCUT","R_UPPERCUT"]
	for row in families:
		for options in [{},{"body":true},{"power":true},{"haymaker":true},{"block":true}]:
			var s = fresh()
			s.step({"body_axis":Vector2.ZERO,"punch":row}.merged(options,true))
			var committed: Dictionary = s.P.get("boxing",{}).get("action",{}).duplicate(true)
			var events: Array = s.events.duplicate(true); events.append_array(strokes(s,160))
			var hits: Array = events.filter(func(e): return e.get("kind") == "boxing_contact" and e.get("by") == "P")
			var name := "%s %s" % [row,str(options)]
			check(name+" commits and resolves exactly once",not committed.is_empty() and hits.size() == 1)
			var expected := []
			for key in options:
				if key != "block": expected.append({"body":"BODY","power":"POWER","haymaker":"HAYMAKER"}[key])
			check(name+" preserves the requested modifier",committed.get("mods",[]) == expected)
			if not hits.is_empty(): samples.append({"case":name,"contact":hits[0]["contact"]})
	for row in families:
		for body in [false,true]:
			var opponent = fresh()
			opponent.btimer = opponent._boss_act({"kind":"punch","row":row,"mult":1.0,"body":body})
			var events: Array = strokes(opponent,160)
			var hits: Array = events.filter(func(e):return e.get("kind")=="boxing_contact" and e.get("by")=="B")
			check("opponent %s body=%s resolves once"%[row,body],hits.size()==1)
			if not hits.is_empty(): samples.append({"case":"opponent %s body=%s"%[row,body],"contact":hits[0]["contact"]})
	for low in [false,true]:
		for body in [false,true]:
			var guarded = fresh()
			var intent := {"block":true,"body":low}
			strokes(guarded,30,intent)
			guarded.btimer = guarded._boss_act({"kind":"punch","row":"R_STRAIGHT","mult":1.0,"body":body})
			var events: Array = strokes(guarded,150,intent)
			var hits: Array = events.filter(func(e):return e.get("kind")=="boxing_contact" and e.get("by")=="B")
			check("guard height %s target %s has one physical result"%[low,body],hits.size()==1)
			if not hits.is_empty():
				check("guard covers its height and leaves the other lane open low=%s target_body=%s"%[low,body],hits[0]["contact"]["kind"] == ("guard" if low == body else "hit"))
				samples.append({"case":"guard low=%s target_body=%s"%[low,body],"contact":hits[0]["contact"]})
	exchanges()
	# Move the opponent after commitment. The original path must stay fixed,
	# and a target which leaves it must not be hit by an aim update.
	var s = fresh(1.8)
	s.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"})
	var aim: Vector3 = s.P["boxing"]["action"]["target"]
	var forward: Vector3 = s.P["boxing"]["action"]["forward"]
	s.B["pos"].x += 1.0
	# This fixture relocates the entire target instantly, including its planted
	# feet and supported body. Moving only the root leaves the physical torso
	# at the old support point until it can catch up.
	s.B.erase("body_control");s.B.erase("boxing")
	var unchanged := true; var outcomes := []
	for i in 150:
		s.events.clear(); s.step({"body_axis":Vector2.ZERO})
		var action: Dictionary = s.P["boxing"].get("action",{})
		if not action.is_empty(): unchanged = unchanged and action["target"] == aim and action["forward"] == forward
		outcomes.append_array(s.events.filter(func(e):return e.get("kind") == "boxing_contact" and e.get("by") == "P"))
	check("late target travel cannot steer the committed path",unchanged)
	check("target leaving the path produces one real miss",outcomes.size()==1 and outcomes[0]["contact"]["kind"]=="miss")
	var reference := {}
	for angle in [0.0,PI*0.5,PI,0.7]:
		var transformed = fresh()
		var translation := Vector2(0.5,-0.3) if angle != 0 else Vector2.ZERO
		for fighter in [transformed.P,transformed.B]:
			fighter.erase("boxing"); fighter.erase("body_control")
			fighter["pos"] = Vector2(fighter["pos"]).rotated(angle)+translation
		transformed.step({"body_axis":Vector2.ZERO})
		transformed.step({"body_axis":Vector2.ZERO,"punch":"R_HOOK"})
		var events: Array = transformed.events.duplicate(true); events.append_array(strokes(transformed,140))
		var contacts: Array = events.filter(func(e):return e.get("kind")=="boxing_contact" and e.get("by")=="P")
		if angle == 0: reference = contacts[0]
		var contact: Dictionary = contacts[0]["contact"] if contacts.size()==1 else {}
		var point: Vector3 = reference["contact"]["point"]
		var ground := Vector2(point.x,point.z).rotated(angle)+translation*Space.GROUND_SCALE
		var expected := Vector3(ground.x,point.y,ground.y)
		check("rotated translated encounter preserves physical contact angle=%.2f"%angle,contacts.size()==1 and contact.get("kind")==reference["contact"]["kind"] and contact.get("target")==reference["contact"]["target"] and contacts[0]["tick"]==reference["tick"] and Vector3(contact.get("point",Vector3.INF)).distance_to(expected)<0.001)
	# Save while both the motion history and committed strike are active.
	s = fresh(); s.step({"body_axis":Vector2.ZERO,"punch":"L_UPPERCUT"})
	strokes(s,12)
	var restored = fresh(); var restored_result: Dictionary = restored.restore(s.snapshot())
	var exact: bool = restored_result.get("ok",false) and restored.hash_state()==s.hash_state()
	for i in 160:
		s.events.clear(); restored.events.clear()
		s.step({"body_axis":Vector2(0.2,0)}); restored.step({"body_axis":Vector2(0.2,0)})
		exact = exact and s.hash_state()==restored.hash_state() and var_to_bytes(s.events)==var_to_bytes(restored.events)
	check("mid-punch restore reproduces pose, contacts and recovery exactly",exact)
	# The normal scene must draw the actual fixed-tick glove positions.
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame; scene.controls_menu.close(); scene.fight_hud.entry.hide()
	scene.sim = fresh(); var correspondence := true; var pure := true; var connected_torso := true
	for i in 150:
		scene.sim.step({"body_axis":Vector2.ZERO,"punch":"L_HOOK"} if i==0 else {"body_axis":Vector2.ZERO})
		scene._consume_events(); var before: int = scene.sim.hash_state(); scene._render(1.0)
		pure = pure and before == scene.sim.hash_state()
		for pair in [[scene.player,scene.sim.P],[scene.boss,scene.sim.B]]:
			var torso: Node3D = pair[0].get_meta("mesh")
			var surface: Dictionary = pair[1]["boxing"]["volumes"][1]
			if connected_torso and ((torso.global_transform * Vector3(0,-0.285,0)).distance_to(surface["a"]) > 0.0001 or (torso.global_transform * Vector3(0,0.285,0)).distance_to(surface["b"]) > 0.0001):
				print("TORSO DIVERGENCE tick=",scene.sim.tick," root=",pair[0].position," origin=",pair[1]["boxing"]["origin"]," bottom=",torso.global_transform*Vector3(0,-0.285,0)," expected=",surface["a"]," top=",torso.global_transform*Vector3(0,0.285,0)," expected=",surface["b"])
			connected_torso = connected_torso and (torso.global_transform * Vector3(0,-0.285,0)).distance_to(surface["a"]) < 0.0001 and (torso.global_transform * Vector3(0,0.285,0)).distance_to(surface["b"]) < 0.0001
			for hand in 2:
				var actual: Vector3 = pair[0].position + pair[0].get_meta("gloves")[hand].position
				var physical: Vector3 = pair[1]["boxing"]["origin"] + pair[1]["boxing"]["rig"]["wrists"][hand]
				correspondence = correspondence and actual.distance_to(physical) < 0.000001
	check("production rendering draws the simulation-owned gloves",correspondence)
	check("visible torso endpoints stay attached to the physical body volume",connected_torso)
	check("rendering cannot change committed contact state",pure)
	var f := FileAccess.open("user://punch-contact.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t")); f.close()
	print("PUNCH CONTACT VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func guard_continuity() -> void:
	# These are real native input/pose/contact ticks, including release and
	# re-press. A punch must not synthesize either of those guard input edges.
	for stance in ["orthodox","southpaw"]:
		for low in [false,true]:
			for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_HOOK","L_FLARED","R_FLARED","L_HOOKERCUT","R_HOOKERCUT","L_UPPERCUT","R_UPPERCUT"]:
				var s = fresh(2.5)
				s.P["stance"] = stance
				s.P.erase("boxing"); s.P.erase("body_control")
				var intent := {"block":true,"body":low,"body_axis":Vector2(0.3,-0.2)}
				strokes(s,50,intent)
				var prior: int = s.P["block_t"]
				s.step(intent.merged({"punch":row},true))
				var committed: Dictionary = s.P["boxing"]["action"].duplicate(true)
				var continuous := bool(s.P["blocking"]) and int(s.P["block_t"]) >= prior
				var opposite_braced := true; var extended_unbraced := true; var flight := false; var extended_return := false
				var active := 0 if row.begins_with("L_") else 1
				var label := "%s low=%s %s"%[stance,low,row]
				for i in 170:
					prior = int(s.P["block_t"]); strokes(s,1,intent)
					continuous = continuous and bool(s.P["blocking"]) and int(s.P["block_t"]) >= prior
					var action: Dictionary = s.P["boxing"].get("action",{})
					var rig: Dictionary = s.P["boxing"]["rig"]
					if action.get("phase","") == "flight":
						flight = true
						for volume in s.P["boxing"]["volumes"]:
							if volume["part"] == "glove%d"%(1-active): opposite_braced = opposite_braced and volume["kind"] == "guard" and volume["target"] == ("body" if low else "head")
					if not action.is_empty() and Vector3(rig["wrists"][active]).distance_to(rig["hand_homes"][active]) > 0.20:
						extended_return = extended_return or action.get("phase","") == "recovery"
						for volume in s.P["boxing"]["volumes"]:
							if volume["part"] == "glove%d"%active: extended_unbraced = extended_unbraced and volume["kind"] != "guard"
				check(label+" held guard and its original timing survive the whole punch",continuous and flight)
				check(label+" other hand retains requested guard height during body movement",opposite_braced and Vector2(s.P["body_control"]["axis"]).length()>0.1)
				check(label+" extended working arm cannot brace until it returns",extended_unbraced and extended_return)
				check(label+" guard does not repurpose the punch modifier",not "BLOCK_PUNCH" in committed.get("mods",[]))
				strokes(s,1,{"body":low}); check(label+" actual release clears timing",s.P["block_t"] == 0)
				strokes(s,1,intent); check(label+" actual re-press starts timing once",s.P["block_t"] == 1)
				samples.append({"case":label,"startup":committed.get("startup",0),"continuous_guard":continuous,"offhand_braced":opposite_braced,"extended_unbraced":extended_unbraced})
	for low in [false,true]:
		for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_UPPERCUT"]:
			var opponent = fresh(2.5)
			opponent.B["guard_t"] = 1000; opponent.B["guard_body"] = low
			strokes(opponent,40)
			opponent.btimer = opponent._boss_act({"kind":"punch","row":row,"mult":1.0,"body":low})
			var braced := true; var flight := false
			for i in 100:
				strokes(opponent,1)
				if opponent.B["boxing"]["action"].get("phase","") == "flight":
					flight = true
					for volume in opponent.B["boxing"]["volumes"]:
						if volume["part"] == ("glove1" if row.begins_with("L_") else "glove0"): braced = braced and volume["kind"] == "guard" and volume["target"] == ("body" if low else "head")
			check("opponent %s low=%s retains its authored guard while punching"%[row,low],braced and flight and opponent.B["guard_t"]>0)
	for low in [false,true]:
		var held = fresh(); var released = fresh()
		strokes(held,40,{"block":true,"body":low}); strokes(released,40,{"body":low})
		held.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT","block":true,"body":low})
		released.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT","body":low})
		check("held guard adds no artificial startup delay low=%s"%low,held.P["pending"]["startup"] == released.P["pending"]["startup"])
	# The catch has to occur in a real interception, following a real press.
	for late_press in [false,true]:
		var timed = fresh()
		strokes(timed,60,{"block":true})
		timed.btimer = timed._boss_act({"kind":"punch","row":"R_STRAIGHT","mult":1.0,"body":false})
		if late_press: strokes(timed,1)
		var events := strokes(timed,120,{"block":true})
		var contacts := events.filter(func(e): return e.get("kind")=="boxing_contact" and e.get("by")=="B")
		check("real interception respects actual press timing fresh=%s"%late_press,contacts.size()==1 and contacts[0]["contact"]["kind"]=="guard" and tests.count_events(events,"perfect_block")==int(late_press))
		check("blocking does not score an untouched clean head hit fresh=%s"%late_press,tests.count_events(events,"hit",{"on":"P"})==0)
		for event in events:
			if event.get("kind")=="boxing_contact": samples.append({"case":"timed catch %s"%late_press,"contact":event["contact"]})
	var opened = fresh(2.5)
	strokes(opened,50,{"block":true}); opened.P["guard_open_t"] = 8
	strokes(opened,10,{"block":true})
	check("a forced opening cannot restart an already held guard clock",opened.P["block_t"]==60 and opened.P["blocking"])
	var switch_height = fresh(2.5)
	strokes(switch_height,40,{"block":true})
	switch_height.step({"body_axis":Vector2.ZERO,"block":true,"punch":"R_UPPERCUT"})
	var target: Vector3 = switch_height.P["boxing"]["action"]["target"]
	strokes(switch_height,12,{"block":true,"body":true,"body_axis":Vector2(-0.3,0.2)})
	var hand: Dictionary = switch_height.P["boxing"]["volumes"][2]
	check("guard height can change mid-punch without retargeting the committed strike",hand["kind"]=="guard" and hand["target"]=="body" and switch_height.P["boxing"]["action"]["target"]==target)

func continuations() -> void:
	for row in ["L_STRAIGHT","R_STRAIGHT","L_HOOK","R_UPPERCUT"]:
		var support = fresh(1.8)
		var feet: Array = support.P["body_control"]["feet"].duplicate()
		var yaw: Array = support.P["body_control"]["foot_yaw"].duplicate()
		support.step({"body_axis":Vector2.ZERO,"punch":row})
		var pivot := 0.0; var transfer := 0.0; var planted := true
		for i in 100:
			strokes(support,1)
			var body: Dictionary = support.P["body_control"]
			for hand in 2:
				planted = planted and Vector2(body["feet"][hand]).distance_to(feet[hand]) < 0.00001
				pivot = maxf(pivot,absf(angle_difference(float(yaw[hand]),float(body["foot_yaw"][hand]))))
			transfer = maxf(transfer,absf(float(body["weight_lead"])-0.5))
		check(row+" transfers load through a planted pivot without root or foot sliding",planted and pivot > 0.10 and transfer > 0.035)
	var pairs := [["L_STRAIGHT","R_STRAIGHT"],["R_STRAIGHT","L_HOOK"],["L_HOOK","R_UPPERCUT"],
		["R_UPPERCUT","L_HOOKERCUT"],["L_HOOKERCUT","R_FLARED"],["R_FLARED","L_UPPERCUT"],
		["L_STRAIGHT","L_STRAIGHT"],["R_STRAIGHT","R_HOOK"],["L_HOOK","L_UPPERCUT"],
		["R_UPPERCUT","R_HOOKERCUT"],["L_HOOKERCUT","L_FLARED"],["R_FLARED","R_STRAIGHT"]]
	for pair in pairs:
		var s = fresh(1.6)
		s.step({"body_axis":Vector2.ZERO,"punch":pair[0]})
		var same: bool = str(pair[0]).begins_with("L_") == str(pair[1]).begins_with("L_")
		var requested := false; var delivered := false; var before_idle := false
		var jump := 0.0; var event_count := 0; var remaining := 0; var return_seen := false
		for i in 170:
			tests.clear_defense(s.B); s.B["guard_t"] = 0
			var intent := {"body_axis":Vector2.ZERO}
			var action: Dictionary = s.P["boxing"].get("action",{})
			if not requested and action.get("phase","") == "recovery" and float(action["return_t"])/int(action["recovery_ticks"]) >= (0.70 if same else 0.34):
				intent["punch"] = pair[1]; requested = true
			var prior: Dictionary = s.P["boxing"]["rig"].duplicate(true)
			remaining = int(s.P["busy_t"])
			s.events.clear(); s.step(intent)
			for event in s.events:
				if event.get("kind","") == "punch":
					event_count += 1; delivered = true; before_idle = remaining > 1
					var rig: Dictionary = s.P["boxing"]["rig"]
					for field in ["wrists","shoulders","elbows"]:
						for hand in 2:
							var distance := Vector3(prior[field][hand]).distance_to(rig[field][hand])
							if distance >= 0.08: print("TRANSFER JUMP ",pair," ",field,hand," distance=",distance," from=",prior[field][hand]," to=",rig[field][hand])
							jump = maxf(jump,distance)
					jump = maxf(jump,Vector3(prior["pelvis"]).distance_to(rig["pelvis"]))
					return_seen = s.P["boxing"]["action"].has("returning") or same
			if delivered and s.P["boxing"].get("action",{}).is_empty(): break
		var label := "%s -> %s" % pair
		check(label+" starts one fresh follow-up before idle",requested and delivered and before_idle and event_count == 1)
		check(label+" transfers the connected pose and retains the returning hand",jump < 0.08 and return_seen)
		samples.append({"case":label,"launch_joint_jump_m":jump,"before_idle":before_idle})
	var queued = fresh()
	queued.step({"body_axis":Vector2.ZERO,"punch":"R_HOOK"})
	queued.step({"body_axis":Vector2.ZERO,"punch":"L_STRAIGHT"})
	var replaced: Array = strokes(queued,1,{"punch":"L_UPPERCUT"})
	var expired: Array = strokes(queued,8)
	check("one fresh input replaces the older follow-up",replaced.any(func(e):return e.get("outcome","")=="replaced" and e.get("row","")=="L_STRAIGHT"))
	check("an early intent expires instead of firing after commitment",queued.P["cmd"].is_empty() and expired.any(func(e):return e.get("outcome","")=="expired") and not expired.any(func(e):return e.get("kind","")=="punch"))
	var state = fresh()
	state.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"})
	for i in 100:
		strokes(state,1)
		var action: Dictionary = state.P["boxing"].get("action",{})
		if action.get("phase","") == "recovery" and float(action["return_t"])/int(action["recovery_ticks"]) >= 0.30: break
	var available: Dictionary = Contact.transition(state.P,"L_STRAIGHT")
	var recovery_wait: int = state.P["busy_t"]
	state.P["busy_t"] += 60
	check("a separate stagger lock cannot be skipped by recovery",not Contact.transition(state.P,"L_STRAIGHT")["allowed"])
	state.P["busy_t"] = recovery_wait
	state.P["stamina"] = 0
	check("exhaustion delays the same physical continuation",available["allowed"] and not Contact.transition(state.P,"L_STRAIGHT")["allowed"])
	state.P["stamina"] = 100; state.P["body_control"]["support"] = 0.60
	check("an unsettled support foot prevents early continuation",not Contact.transition(state.P,"L_STRAIGHT")["allowed"])
	state.P["body_control"]["support"] = 1
	state.P["boxing"]["action"]["phase"] = "cancelled"
	check("an interrupted stroke cannot become an early continuation",not Contact.transition(state.P,"L_STRAIGHT")["allowed"])
	var exit_step = fresh(1.8)
	exit_step.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"})
	var exit_started := false; var covered := false; var idle_remaining := 0
	for i in 110:
		var intent := {"body_axis":Vector2.ZERO,"block":true}
		var action: Dictionary = exit_step.P["boxing"].get("action",{})
		if not exit_started and action.get("phase","") == "recovery" and float(action["return_t"])/int(action["recovery_ticks"]) >= 0.65:
			intent["pocket_step"] = Vector2(0.5,-1); idle_remaining = int(exit_step.P["busy_t"])
		var events: Array = strokes(exit_step,1,intent)
		if events.any(func(e):return e.get("kind","")=="footwork" and e.get("outcome","")=="accepted"): exit_started = true
		covered = covered or (exit_started and float(exit_step.P["boxing"]["rig"]["guard"]) > 0.5 and bool(exit_step.P["blocking"]))
	check("a recovering hand can cover an actual diagonal exit before idle",exit_started and covered and idle_remaining > 1)
	# The actual authored-opponent queue uses the same gate; an explicit pause
	# remains a pause rather than disappearing into the faster hand transition.
	for pause in [false,true]:
		var opponent = fresh(1.8)
		opponent.btimer = opponent._boss_act({"kind":"punch","row":"L_STRAIGHT","mult":1.0,"body":false})
		var wait_until: int = opponent.tick + opponent.btimer
		opponent.bqueue = [{"kind":"punch","row":"R_STRAIGHT","mult":1.0,"body":false}]
		if pause: opponent.B["boxing"]["sequence_wait"] = false
		var started := -1; var snapshot := {}
		for i in 110:
			var events: Array = strokes(opponent,1,{"body_axis":Vector2.RIGHT})
			if events.any(func(e):return e.get("kind","")=="boss_windup" and e.get("row","")=="R_STRAIGHT"):
				started = opponent.tick; snapshot = opponent.snapshot(); break
		check("opponent preserves explicit pause" if pause else "opponent transfers into the next hand before idle",started >= wait_until if pause else started > 0 and started < wait_until)
		if not pause and not snapshot.is_empty():
			var restored = fresh(); restored.restore(snapshot); var exact := true
			for i in 100:
				opponent.events.clear(); restored.events.clear()
				opponent.step({"body_axis":Vector2.RIGHT}); restored.step({"body_axis":Vector2.RIGHT})
				exact = exact and opponent.hash_state()==restored.hash_state() and var_to_bytes(opponent.events)==var_to_bytes(restored.events)
			check("restored overlapping hand return replays identically",exact)

func exchanges() -> void:
	for scenario in ["interrupt_opponent","interrupt_player","clash","covered_trade","trade"]:
		var exchange = fresh(1.8 if scenario=="trade" else 1.5)
		# This symmetric baseline compares ordinary punch paths/timing. Learned
		# compact routes intentionally change both; cover those exchanges in
		# drive_northern_rising rather than silently redefining this regression.
		exchange.P["boxing_training"] = {}
		exchange.B["guard_body"] = true; exchange.B["guard_t"] = 100
		strokes(exchange,30,{"block":true,"body":true})
		for name in exchange.pattern["strings"]:
			if exchange._interruptible(name): exchange.bstring = name; break
		# The repaired low guard can now intercept a loading uppercut. Two
		# rear straights cross the working gloves, testing an actual clash.
		var player_row := "R_STRAIGHT" if scenario in ["interrupt_opponent","clash"] else (("L_HOOK" if scenario=="trade" else "R_HOOK") if scenario in ["trade","covered_trade"] else "R_UPPERCUT")
		var boss_row := "L_STRAIGHT" if scenario=="interrupt_player" else ("R_HOOK" if scenario in ["trade","covered_trade"] else ("R_STRAIGHT" if scenario=="clash" else "R_UPPERCUT"))
		# Preserve the covered head/head attempt; test two clean hits through
		# distinct head/body lanes without exempting either hand from collision.
		exchange.btimer = exchange._boss_act({"kind":"punch","row":boss_row,"mult":1.0,"body":false})
		exchange.step({"body_axis":Vector2.ZERO,"punch":player_row,"body":scenario=="trade"})
		var events: Array = exchange.events.duplicate(true); events.append_array(strokes(exchange,160,{"body":true}))
		var contacts: Array = events.filter(func(e):return e.get("kind")=="boxing_contact")
		var hits: Array = events.filter(func(e):return e.get("kind")=="hit")
		if scenario == "interrupt_opponent":
			check("clean jab interrupts opponent startup without a phantom reply",tests.count_events(events,"interrupt")>0 and contacts.size()==1 and contacts[0]["by"]=="P")
		elif scenario == "interrupt_player":
			check("clean opponent jab interrupts player startup without a phantom reply",tests.count_events(events,"punch_interrupted",{"who":"P"})>0 and contacts.size()==1 and contacts[0]["by"]=="B")
		elif scenario == "clash":
			check("crossing attacking gloves physically deflect both punches",contacts.size()==2 and contacts[0]["contact"]["kind"]=="deflect" and contacts[1]["contact"]["kind"]=="deflect" and hits.is_empty())
			check("glove deflections cannot damage untouched head or body",tests.count_events(events,"deflect")==2 and exchange.P["comp"]==exchange.P["comp_max"] and exchange.B["comp"]==exchange.B["comp_max"])
		elif scenario == "covered_trade":
			check("covered rear hooks meet the real lead gloves without clean damage",contacts.size()==2 and contacts[0]["by"]=="B" and contacts[0]["contact"]["kind"]=="deflect" and contacts[0]["contact"]["part"]=="glove0" and contacts[1]["contact"]["kind"]=="guard" and contacts[1]["contact"]["part"]=="glove0" and hits.is_empty())
		else:
			check("committed head and body hooks trade through their available lanes",contacts.size()==2 and tests.count_events(hits,"hit",{"on":"P"})==1 and tests.count_events(hits,"hit",{"on":"B"})==1)
		samples.append({"case":scenario,"contacts":contacts,"hits":hits})

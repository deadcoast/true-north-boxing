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
			for key in options: expected.append({"body":"BODY","power":"POWER","haymaker":"HAYMAKER","block":"BLOCK_PUNCH"}[key])
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
	for scenario in ["interrupt_opponent","interrupt_player","clash","trade"]:
		var exchange = fresh()
		exchange.B["guard_body"] = true; exchange.B["guard_t"] = 100
		strokes(exchange,30,{"block":true,"body":true})
		for name in exchange.pattern["strings"]:
			if exchange._interruptible(name): exchange.bstring = name; break
		var player_row := "R_STRAIGHT" if scenario=="interrupt_opponent" else ("R_HOOK" if scenario=="trade" else "R_UPPERCUT")
		var boss_row := "L_STRAIGHT" if scenario=="interrupt_player" else ("R_HOOK" if scenario=="trade" else "R_UPPERCUT")
		exchange.btimer = exchange._boss_act({"kind":"punch","row":boss_row,"mult":1.0,"body":false})
		exchange.step({"body_axis":Vector2.ZERO,"punch":player_row})
		var events: Array = exchange.events.duplicate(true); events.append_array(strokes(exchange,160,{"body":true}))
		var contacts: Array = events.filter(func(e):return e.get("kind")=="boxing_contact")
		var hits: Array = events.filter(func(e):return e.get("kind")=="hit")
		print("EXCHANGE ",scenario," contacts=",contacts," hits=",hits)
		if scenario == "interrupt_opponent":
			check("clean jab interrupts opponent startup without a phantom reply",tests.count_events(events,"interrupt")>0 and contacts.size()==1 and contacts[0]["by"]=="P")
		elif scenario == "interrupt_player":
			check("clean opponent jab interrupts player startup without a phantom reply",tests.count_events(events,"punch_interrupted",{"who":"P"})>0 and contacts.size()==1 and contacts[0]["by"]=="B")
		elif scenario == "clash":
			check("crossing attacking gloves physically deflect both punches",contacts.size()==2 and contacts[0]["contact"]["kind"]=="deflect" and contacts[1]["contact"]["kind"]=="deflect" and hits.is_empty())
		else:
			check("two committed hooks can trade clean hits",contacts.size()==2 and tests.count_events(hits,"hit",{"on":"P"})==1 and tests.count_events(hits,"hit",{"on":"B"})==1)
		samples.append({"case":scenario,"contacts":contacts,"hits":hits})
	# Move the opponent after commitment. The original path must stay fixed,
	# and a target which leaves it must not be hit by an aim update.
	var s = fresh(1.8)
	s.step({"body_axis":Vector2.ZERO,"punch":"R_STRAIGHT"})
	var aim: Vector3 = s.P["boxing"]["action"]["target"]
	var forward: Vector3 = s.P["boxing"]["action"]["forward"]
	s.B["pos"].x += 1.0
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
	scene.sim = fresh(); var correspondence := true; var pure := true
	for i in 150:
		scene.sim.step({"body_axis":Vector2.ZERO,"punch":"L_HOOK"} if i==0 else {"body_axis":Vector2.ZERO})
		scene._consume_events(); var before: int = scene.sim.hash_state(); scene._render(1.0)
		pure = pure and before == scene.sim.hash_state()
		for pair in [[scene.player,scene.sim.P],[scene.boss,scene.sim.B]]:
			for hand in 2:
				var actual: Vector3 = pair[0].position + pair[0].get_meta("gloves")[hand].position
				var physical: Vector3 = pair[1]["boxing"]["origin"] + pair[1]["boxing"]["rig"]["wrists"][hand]
				correspondence = correspondence and actual.distance_to(physical) < 0.000001
	check("production rendering draws the simulation-owned gloves",correspondence)
	check("rendering cannot change committed contact state",pure)
	var f := FileAccess.open("user://punch-contact.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t")); f.close()
	print("PUNCH CONTACT VERDICT :: %s (%d/%d)" % ["GREEN" if failures.is_empty() else "RED",checks-failures.size(),checks])
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

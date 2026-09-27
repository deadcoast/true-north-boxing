# TNBObjectives - the scrap's micro-objective, judged from the sim's own events (NP_02 s2.1).
# Pure and static: the sim hands each new event to on_event() and calls check() once per tick;
# the objective record says met / failed / progress. Forms come from data/bouts.v1.json
# (objective_forms) and the prompts from data/scrap_objectives.v1.json. A constraint form
# fails the moment it is broken and wins at the cap on EP; every other form wins when met.
extends RefCounted

static func fresh(id: String, form: Dictionary, prompt: String, param: String) -> Dictionary:
	return {"id": id, "form": form, "prompt": prompt, "param": param, "kind": str(form.get("kind", "count")),
		"count": 0, "need": int(form.get("need", 1)), "met": false, "failed": false, "why": "", "available": true,
		"streak": 0, "ladder_i": 0, "last_row": "", "last_hit": {}, "in_corner": false, "blocked_in_corner": false, "was_corner": false}

static func describe(obj: Dictionary) -> String:
	if obj.is_empty(): return ""
	var p := str(obj["prompt"]).replace("{dialect}", str(obj["param"]).capitalize())
	match str(obj["kind"]):
		"count", "streak": return "%s  [%d/%d]" % [p, int(obj["count"]), int(obj["need"])]
		"ladder": return "%s  [%d/%d]" % [p, int(obj["ladder_i"]), obj["form"]["events"].size()]
		"constraint":
			if str(obj["form"].get("rule", "")) == "no_repeat_punch": return "%s  [%d/%d]" % [p, int(obj["count"]), int(obj["need"])]
			return p + ("  [broken]" if obj["failed"] else "  [holding]")
	return p

static func translate(sim, ev: Dictionary) -> Array:
	# a sim event -> zero or more objective events
	var out: Array = []
	match str(ev["kind"]):
		"hit":
			if str(ev.get("on", "")) == "B" and not bool(ev.get("foul", false)) and not bool(ev.get("hissatsu", false)):
				out.append("hit")
				if bool(ev.get("body", false)): out.append("body_hit")
				if bool(ev.get("counter", false)) or bool(ev.get("flash", false)): out.append("counter_hit")
				if bool(ev.get("center", false)): out.append("center_hit")
				if bool(ev.get("stepping", false)): out.append("stepping_hit")
		"evade":
			if str(ev.get("by", "")) == "P" and str(ev.get("dodge", "")) != "": out.append("made_miss")
		"guard_break":
			if str(ev.get("who", "")) == "B": out.append("guard_break")
		"interrupt":
			# NP_04 s4: a Loud (SPECIAL-class) string broken is his special; so is his hissatsu cast broken in its window
			if bool(ev.get("loud", false)): out.append("interrupt_loud"); out.append("interrupt_special")
			else: out.append("interrupt_normal")
		"sensor":
			if str(ev.get("name", "")) == "player_perfect_block_streak2": out.append("perfect_block_pair")
		"clinch_end":
			if str(ev.get("winner", "")) == "P": out.append("clinch_won")
		"cast_interrupted":
			if str(ev.get("who", "")) == "B" and str(ev.get("by", "")) == "P":
				out.append("cast_interrupted:" + sim.move_house(str(ev.get("move", ""))))
				out.append("interrupt_special"); out.append("interrupt_loud")
		"tell":
			if bool(ev.get("shout", false)): out.append("coach_shout")
		"flag": out.append("flag")
		"punch": out.append("punch:" + str(ev.get("row", "")))
		"block_press": out.append("block_press")
		"backstep": out.append("backstep")
		"drop":
			out.append("drop_b" if str(ev.get("who", "")) == "B" else "drop_p")
	return out

static func on_event(sim, obj: Dictionary, ev: Dictionary) -> void:
	if obj.is_empty() or obj["met"] or obj["failed"]: return
	var form: Dictionary = obj["form"]
	var kind := str(obj["kind"])
	if str(ev["kind"]) == "hit" and str(ev.get("on", "")) == "B": obj["last_hit"] = ev
	for oe in translate(sim, ev):
		var name := str(oe)
		match kind:
			"count":
				var want := str(form.get("event", ""))
				if want == "native_cast_interrupted":
					if name == "cast_interrupted:" + str(obj["param"]) and str(obj["param"]) != "": obj["count"] += 1
				elif name == want: obj["count"] += 1
				if int(obj["count"]) >= int(obj["need"]): obj["met"] = true; obj["why"] = "objective"
			"streak":
				if name == str(form.get("reset_on", "flag")): obj["count"] = 0
				elif name == str(form.get("event", "hit")): obj["count"] += 1
				if int(obj["count"]) >= int(obj["need"]): obj["met"] = true; obj["why"] = "objective"
			"ladder":
				var seq: Array = form.get("events", [])
				if int(obj["ladder_i"]) < seq.size() and name == str(seq[int(obj["ladder_i"])]):
					obj["ladder_i"] = int(obj["ladder_i"]) + 1
					if int(obj["ladder_i"]) >= seq.size(): obj["met"] = true; obj["why"] = "objective"
			"finisher":
				if name == "drop_b":
					var lh: Dictionary = obj["last_hit"]
					var ok := false
					if form.has("family"): ok = lh.size() > 0 and sim._punch_family(str(lh.get("row", ""))) == str(form["family"])
					elif bool(form.get("body", false)): ok = lh.size() > 0 and bool(lh.get("body", false))
					if ok: obj["met"] = true; obj["why"] = "objective"
					else: obj["failed"] = true; obj["why"] = "the finisher was the wrong punch"
			"first_blood":
				if name == "hit": obj["met"] = true; obj["why"] = "first blood"
			"constraint":
				var rule := str(form.get("rule", ""))
				match rule:
					"no_repeat_punch":
						if name.begins_with("punch:"):
							var row := name.substr(6)
							if row == str(obj["last_row"]): obj["failed"] = true; obj["why"] = "the same punch twice"
							else: obj["count"] += 1; obj["last_row"] = row
							if int(obj["count"]) >= int(obj["need"]) and not obj["failed"]: obj["met"] = true; obj["why"] = "objective"
					"no_block":
						if name == "block_press": obj["failed"] = true; obj["why"] = "you blocked"
					"left_hands_only":
						if name.begins_with("punch:R_"): obj["failed"] = true; obj["why"] = "a right hand"
					"no_backstep":
						if name == "backstep": obj["failed"] = true; obj["why"] = "you stepped back"
		if kind == "first_blood" and name == "drop_p": obj["failed"] = true; obj["why"] = "he drew first blood"
		if kind == "survive" and name == "drop_p": obj["failed"] = true; obj["why"] = "you went down"
		if kind == "segment_end" and name == "drop_p" and int(sim.P["drops"]) >= 3: obj["failed"] = true; obj["why"] = "counted out"
	# first blood the other way: his clean hit lands first
	if kind == "first_blood" and str(ev["kind"]) == "hit" and str(ev.get("on", "")) == "P" and not obj["met"]:
		obj["failed"] = true; obj["why"] = "he landed first"

static func check(sim, obj: Dictionary) -> void:
	# the per-tick forms: time survived, a state reached, the corner left unblocked
	if obj.is_empty() or obj["met"] or obj["failed"]: return
	var form: Dictionary = obj["form"]
	match str(obj["kind"]):
		"survive":
			var elapsed_s: float = float(sim.bout_cap_t - sim.clock_t) / float(sim.TICK_HZ)
			if elapsed_s >= float(form.get("seconds", 20)): obj["met"] = true; obj["why"] = "survived"
		"state":
			if bool(sim.get(str(form.get("flag", "trapped_b")))): obj["met"] = true; obj["why"] = "objective"
		"count":
			if str(form.get("event", "")) == "corner_escape_unblocked":
				var zp: String = sim.zone(sim.P["pos"])
				var cornered: bool = zp == "CORNER"
				if cornered and not obj["in_corner"]: obj["in_corner"] = true; obj["blocked_in_corner"] = false
				if cornered and bool(sim.P["blocking"]): obj["blocked_in_corner"] = true
				if not cornered and obj["in_corner"]:
					obj["in_corner"] = false
					if zp != "ROPES" and not obj["blocked_in_corner"]: obj["count"] += 1
				if int(obj["count"]) >= int(obj["need"]): obj["met"] = true; obj["why"] = "objective"

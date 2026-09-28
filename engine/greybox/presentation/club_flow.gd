extends CanvasLayer
## NP-02/08/10: one club, one set of ledgers, and the same hands in every bout.
## All purchases, recruitment, rewards and formation validation remain in TNBSim.
const Save := preload("res://sim/save.gd")
var scene: Node
var enabled := false
var page := "Bouts"
var surface: Control
var body: VBoxContainer
var status: Label
var heading: Label
var nav: HBoxContainer
var scroll: ScrollContainer
var buttons := {}
var selected := "RORY"
var order: Array = []
var result_text := ""
var reward_text := ""
var last_mode := ""
var training := {}
var training_bar: ProgressBar
var training_label: Label

func setup(owner_scene: Node) -> void:
	scene = owner_scene; layer = 8
	surface = Control.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = scene.fight_hud._panel(surface)
	panel.anchor_left = 0.04; panel.anchor_right = 0.96; panel.anchor_top = 0.04; panel.anchor_bottom = 0.96
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 12); panel.add_child(column)
	heading = scene.fight_hud._label("THE OLD GYM", 28, column)
	nav = HBoxContainer.new(); column.add_child(nav)
	for tab in ["Bouts", "Stable", "Recruit", "Formation", "Training", "Scout Book"]:
		scene.fight_hud._button(tab, nav, func(): page = tab; rebuild())
	scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10); scroll.add_child(body)
	status = scene.fight_hud._label("", 15, column); status.autowrap_mode = TextServer.AUTOWRAP_WORD
	var footer := HBoxContainer.new(); column.add_child(footer)
	scene.fight_hud._button("Save club", footer, save_club)
	scene.fight_hud._button("Continue saved game", footer, load_club)
	scene.fight_hud._button("Controls", footer, func(): scene.controls_menu.open())
	scene.fight_hud._button("Return to ring", footer, close)
	hide()

func pauses_fight() -> bool:
	return visible and page != "Corner"

func open() -> void:
	enabled = true; scene.clock.acc = 0; scene.combat_input.clear(true)
	scene.fight_hud.dismiss_entry(); show(); rebuild()
	scene.fight_hud.surface.hide()

func close() -> void:
	if not training.is_empty(): return
	hide(); scene.clock.acc = 0; scene.combat_input.clear(true)
	scene.fight_hud.surface.show()
	var focused := get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func _text(value: String, size := 17) -> Label:
	var label: Label = scene.fight_hud._label(value, size, body)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label

func _button(id: String, label: String, action: Callable, why := "") -> Button:
	var button: Button = scene.fight_hud._button(label, body, action)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.disabled = why != ""; button.tooltip_text = why if why != "" else label; buttons[id] = button
	if why != "": _text(why, 14)
	return button

func _action(action: Callable) -> void:
	var result = action.call()
	scene._consume_events()
	status.text = str(result.get("why", "")) if result is Dictionary and not result.get("ok", true) else scene.feed.text
	rebuild(false)

func rebuild(focus := true) -> void:
	if not training.is_empty(): return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	buttons.clear()
	var s = scene.sim
	var in_bout: bool = s.bell_rung() and s.mode != "OVER" and not scene.practice_dummy
	var bout_gate := "Finish the current bout, or return to the ring" if in_bout else ""
	heading.text = "YOUR CORNER" if page == "Corner" else "THE OLD GYM  /  " + page.to_upper()
	nav.visible = page != "Corner"
	_text("Day %d    %d Prestige    %d HBP    %d Spirits    %d Beans" % [s.rewards.get("day", 1), s.rewards.get("prestige", 0), s.rewards.get("hbp", 0), s.rewards.get("spirits", 0), s.rewards.get("beans", 0)], 15)
	match page:
		"Bouts":
			if result_text != "": _text(result_text, 23)
			if reward_text != "": _text(reward_text)
			_text("Same hands. Different stakes. Scraps teach a read; spars let you explore it; your team carries it into a dual.")
			for id in s.BOUTS.get("ep1", {}):
				var rec: Dictionary = s.BOUTS["ep1"][id]
				var objective := str(s.SCRAPS.get(str(rec["objective"]), {}).get("prompt", "Reach the end of the segment"))
				_button("bout:" + id, str(rec["label"]).capitalize() + "  —  " + objective, func(): start_bout(id), bout_gate)
			_button("spar", "Spar your current opponent · 90 seconds", func(): start_spar(), bout_gate)
			_button("dual", "Prepare the team for a dual", prepare_dual, bout_gate)
			_button("practice", "Practice your hands with a stationary partner", func(): close(); scene.begin_fight(true), bout_gate)
		"Stable":
			for card in s.stable:
				var name := str(card["name"])
				_button("fighter:" + name, "%s · level %d · %s" % [name, s.level_of(name), card.get("style", "")], func(): selected = name; rebuild())
			_text(s.card_view(selected))
			_text("ABILITY BOARD · %d points available" % s.gpoints_free(selected), 21)
			for id in s.growth_nodes(selected):
				var node: Dictionary = s.growth_nodes(selected)[id]
				_button("node:" + id, "%s · %d points" % [node["label"], s.node_cost(selected, id)], func(): _action(func(): return s.take_node(selected, id)), s.node_why(selected, id))
		"Recruit":
			_button("scout", "Scout a new lead", func(): _action(s.scout_pull), s.scout_why())
			for i in s.open_mat().size():
				var card: Dictionary = s.open_mat()[i]
				_button("sign:%d" % i, "Sign %s · %s" % [card["name"], card["style"]], func(): _action(func(): return s.sign_generic(i)), s.sign_why(i))
			for name in s.recruits_open():
				var view: Dictionary = s.recruit_view(str(name))
				_text(str(name).replace("_", " ").capitalize() + " · " + str(view.get("state", "")), 21)
				for clause in view.get("clauses", []): _text(str(clause.get("text", "")) + (" · met" if clause.get("met", false) else " · still needed"), 15)
				_button("approach:" + name, "Approach " + str(name), func(): _action(func(): return s.approach(name)))
				_button("recruit:" + name, "Invite " + str(name) + " to the club", func(): _action(func(): return s.recruit(name)), "Meet the visible conditions first" if not view.get("met", false) else "")
			if s.open_mat().is_empty() and s.recruits_open().is_empty(): _text("Fight and scout to meet people. Winning a dual opens approaches to its rivals.")
		"Formation":
			if order.is_empty(): order = s.sealed_p.slice(0, s.board_k())
			_text("Set the order before the bell. Tension and relationships carry through the card.")
			for i in order.size():
				_text("R%d   %s" % [i + 1, order[i]], 22)
				if i > 0: _button("order:%d" % i, "Move " + str(order[i]) + " earlier", func(): var previous = order[i - 1]; order[i - 1] = order[i]; order[i] = previous; rebuild())
			for line in s.formation_lines(): _text(str(line), 15)
			_button("seal", "Seal order and ring the bell", start_dual, "Finish this bout first" if s.bell_rung() or not s.bout.is_empty() else "")
		"Training":
			_text(s.training_line(), 21)
			_button("roadwork", "Run the Hill with " + selected + " · rhythm and pacing", start_roadwork, s.train_why("roadwork", selected))
			_button("rest", "Rest until tomorrow · refresh daily training", func(): _action(s.new_day), "Rest after the bout" if s.bell_rung() and s.mode != "OVER" else "")
			for track in s.FAC.get("order", []):
				var label := str(s.FAC["tracks"][track]["label"])
				_button("renovate:" + track, "Renovate " + label + " · tier %d → %d" % [s.fac_tier(track), s.fac_tier(track) + 1], func(): _action(func(): return s.renovate(track)), s.renovate_why(track))
		"Scout Book":
			_text("Reconnaissance changes the fight. Three scraps in a dialect teach its habit; more experience sharpens its tells.")
			for dialect in s.pi.get("dialects", {}): _text("%s · Pattern Intel %d" % [str(dialect).capitalize(), s.pi_level(dialect)], 21)
			for page_id in s.pi.get("book", []):
				var parts := str(page_id).split("#")
				var report: Dictionary = s.scout_page(parts[0], parts[1] if parts.size() > 1 else "")
				_text(str(page_id).replace("_", " ").capitalize(), 22)
				for tell in report.get("tells", []): _text("%s · %s · %d ms · %s" % [tell["string"], tell["class"], tell["tell_ms"], tell["motif"]])
				for line in report.get("phases", []) + report.get("hooks", []): _text(str(line), 15)
				_text(str(report.get("corner_tell", "")))
			if s.pi.get("dialects", {}).is_empty(): _text("Your first scrap starts the book.")
		"Corner": _corner()
	if focus:
		scroll.scroll_vertical = 0
		for button in buttons.values():
			if not button.disabled: button.grab_focus(); break

func start_bout(id: String) -> void:
	if scene.sim.bell_rung() and scene.sim.mode != "OVER" and not scene.practice_dummy: return
	scene.set_practice(false)
	if not scene.sim.start_ep1(id): status.text = "This bout is unavailable."; return
	result_text = ""; reward_text = ""; _enter_ring()

func start_spar() -> void:
	if scene.sim.bell_rung() and scene.sim.mode != "OVER" and not scene.practice_dummy: return
	scene.set_practice(false)
	if scene.sim.start_spar(scene.sim._first_boss): result_text = ""; reward_text = ""; _enter_ring()

func prepare_dual() -> void:
	if scene.sim.bell_rung() and scene.sim.mode != "OVER" and not scene.practice_dummy: return
	scene.set_practice(false)
	scene.sim.end_bout(); scene.sim.new_dual(); scene._consume_events()
	order = scene.sim.sealed_p.slice(0, scene.sim.board_k()); page = "Formation"; rebuild()

func start_dual() -> void:
	var result: Dictionary = scene.sim.seal_board({"slots": order})
	if not result["ok"]: status.text = str(result["why"]); return
	result_text = ""; reward_text = ""; _enter_ring()

func _enter_ring() -> void:
	status.text = ""
	scene._consume_events(); scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.fight_view.orbit = Vector3.ZERO; scene.fight_view.clock_sim = null
	scene.formation_open = false; scene.show_formation = false
	last_mode = scene.sim.mode; close(); scene.begin_fight(false)

func observe(event: Dictionary) -> void:
	if event.get("kind") in ["bout_end", "dual_end"]: result_text = str(event.get("verdict", "Bout complete"))
	if event.get("kind") == "reward_toast": reward_text = str(event.get("text", ""))

func track() -> void:
	if not enabled: return
	var mode := str(scene.sim.mode)
	if mode != last_mode:
		last_mode = mode
		if mode == "OVER": page = "Bouts"; open()
		elif mode == "CORNER": page = "Corner"; open()
		elif mode == "FIGHT" and page == "Corner": close(); page = "Bouts"
	if visible and page == "Corner": heading.text = "YOUR CORNER   %ds   ·   %d actions left" % [int(ceil(float(scene.sim.corner.get("t", 0)) / 120)), int(scene.sim.corner.get("actions_left", 0))]

func _corner() -> void:
	var s = scene.sim; var options: Dictionary = s.corner_options()
	_button("send", "Send the next fighter", func(): scene.q_corner = 1; close())
	var spent := "No actions left" if int(options["actions_left"]) <= 0 else ""
	for name in options["swap"]: _button("swap:" + name, "Swap in %s · %d Tension" % [name, options["swap_cost"]], func(): _action(func(): return s.corner_action({"kind": "swap", "arg": name})), spent)
	for kind in ["tactic", "super", "staff"]:
		for option in options[kind]:
			var label := str(option["name"]) + " · " + str(option["text"])
			var why := spent
			if kind == "tactic":
				label += " · %d Tension" % int(option["cost"])
				if bool(option["cooldown"]): why = "Used in the previous corner"
				elif s.tension < float(option["cost"]): why = "Not enough Tension"
			elif kind == "super" and bool(option["used"]): why = "Already used this dual"
			elif kind == "staff":
				label += " · %d charges" % int(option["charges"])
				if int(option["charges"]) <= 0: why = "No charges left"
				elif int(option["heat"]) < int(option["needs"]): why = "Needs %d Crowd Heat" % int(option["needs"])
			_button(kind + ":" + str(option["id"]), label, func(): _action(func(): return s.corner_action({"kind": kind, "id": option["id"]})), why)
	for option in options.get("talk", {}).get("options", []):
		_button("talk:" + str(option["option"]), "The Talk · " + str(option["line"]), func(): _action(func(): return s.corner_action({"kind": "talk", "option": option["option"]})), spent)
	_button("save_bar", "Save the bar for the next fighter", func(): _action(func(): return s.corner_action({"kind": "save_bar"})), spent)

func save_club() -> void:
	if not training.is_empty(): return
	# Keep a rollback save. Validate the new record before replacing the last one.
	var path: String = scene.SAVE_PATH; var pending := path + ".pending"
	if not Save.write_file(pending, scene.sim) or not Save.read_file(pending).get("ok", false): status.text = "Save failed; the previous save is intact."; return
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(path, path + ".bak") != OK: status.text = "Could not preserve the previous save."; return
	if DirAccess.rename_absolute(pending, path) != OK:
		DirAccess.rename_absolute(path + ".bak", path); status.text = "Save failed; restored the previous save."; return
	status.text = "Club saved · " + Save.summary(scene.sim)

func load_club() -> void:
	if not training.is_empty(): return
	if not scene._load_save(scene.SAVE_PATH): status.text = scene.feed.text; return
	result_text = ""; reward_text = ""; order = []; page = "Bouts"
	scene.clock.acc = 0; scene.combat_input.clear(true)
	status.text = "Saved club restored. Return to the ring to continue your bout." if scene.sim.bell_rung() and scene.sim.mode != "OVER" else "Saved club restored."
	rebuild()

func start_roadwork() -> void:
	if scene.sim.train_why("roadwork", selected) != "": return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	_text("THE HILL · ROADWORK", 26)
	_text("Keep your steps in rhythm. Tap when the pacing bar reaches the middle; rushing costs rhythm. Twelve steps, then back to the gym.")
	training_bar = ProgressBar.new(); training_bar.max_value = 1; training_bar.show_percentage = false; training_bar.custom_minimum_size.y = 36; body.add_child(training_bar)
	training_label = _text("", 22)
	var button := _button("step", "Step · Space / Enter", training_step); button.grab_focus()
	training = {"time": 0.0, "next": 0.8, "step": 0, "score": 0.0, "tapped": false, "who": selected}

func training_step() -> void:
	if training.is_empty(): return
	if training["tapped"]: training["score"] = maxf(0, float(training["score"]) - 0.1); return
	training["tapped"] = true
	var error := absf(float(training["time"]) - float(training["next"]))
	training["score"] = float(training["score"]) + maxf(0, 1.0 - error / 0.24)

func _process(delta: float) -> void:
	if training.is_empty() or scene.controls_menu.opened: return
	training["time"] = float(training["time"]) + minf(delta, 0.1)
	var remaining := float(training["next"]) - float(training["time"])
	training_bar.value = clampf(0.5 - remaining / 1.6, 0, 1)
	training_label.text = "Step %d / 12 · %s" % [int(training["step"]) + 1, "NOW" if absf(remaining) < 0.16 else "Find the rhythm"]
	if remaining < -0.3:
		training["step"] += 1; training["next"] = float(training["next"]) + 0.8; training["tapped"] = false
		if int(training["step"]) >= 12:
			var grade := float(training["score"]) / 12; var who := str(training["who"]); training.clear()
			_action(func(): return scene.sim.train("roadwork", who, grade))

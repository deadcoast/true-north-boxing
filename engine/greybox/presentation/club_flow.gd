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
var nav: HFlowContainer
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
var navigation := {}
var footer_buttons := {}
var stable_section := "Card"
var partner := ""
var slot_pick := -1
var opponent_pick := ""
var lab_flags: Array = []
var focus_before_controls: Control
var action_busy := false

func setup(owner_scene: Node) -> void:
	scene = owner_scene; layer = 8
	surface = Control.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = scene.fight_hud._panel(surface)
	panel.anchor_left = 0.04; panel.anchor_right = 0.96; panel.anchor_top = 0.04; panel.anchor_bottom = 0.96
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 12); panel.add_child(column)
	heading = scene.fight_hud._label("THE OLD GYM", 28, column)
	nav = HFlowContainer.new(); column.add_child(nav)
	for tab in ["Bouts", "Stable", "Recruit", "Formation", "Training", "Scout Book"]:
		navigation[tab] = scene.fight_hud._button(tab, nav, func(): _page(tab))
	scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10); scroll.add_child(body)
	status = scene.fight_hud._label("", 15, column); status.autowrap_mode = TextServer.AUTOWRAP_WORD
	var footer := HFlowContainer.new(); column.add_child(footer)
	footer_buttons["save"] = scene.fight_hud._button("Save club", footer, save_club)
	footer_buttons["load"] = scene.fight_hud._button("Continue saved game", footer, load_club)
	footer_buttons["rollback"] = scene.fight_hud._button("Restore previous save", footer, func(): _load_club_path(scene.SAVE_PATH + ".bak"))
	footer_buttons["rollback"].hide()
	footer_buttons["controls"] = scene.fight_hud._button("Controls", footer, func(): scene.controls_menu.open())
	footer_buttons["return"] = scene.fight_hud._button("Return to ring", footer, close)
	scene.controls_menu.closed.connect(func():
		if visible:
			if is_instance_valid(focus_before_controls) and focus_before_controls.is_visible_in_tree(): focus_before_controls.grab_focus()
			else: _restore_focus(""))
	hide()

func pauses_fight() -> bool:
	return visible and page != "Corner"

func open() -> void:
	enabled = true; scene.clock.acc = 0; scene.combat_input.clear(true)
	scene.q_punch = ""; scene.q_dodge = ""; scene.q_action = {}; scene.q_corner = 0
	scene.fight_hud.dismiss_entry(); show(); rebuild()
	scene.fight_hud.surface.hide()

func close() -> void:
	if not training.is_empty(): return
	if visible and scene.sim.mode == "OVER": status.text = "Choose your next bout to return to the ring."; return
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
	if action_busy: return
	action_busy = true
	var focus_id := _focus_id()
	var result = action.call()
	scene._consume_events()
	status.text = str(result.get("why", "")) if result is Dictionary and not result.get("ok", true) else scene.feed.text
	rebuild(false)
	_restore_focus(focus_id)
	action_busy = false

func _page(next: String) -> void:
	if not training.is_empty(): return
	page = next; slot_pick = -1; status.text = ""; rebuild()

func _focus_id() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	for id in buttons:
		if buttons[id] == focused: return id
	return ""

func _restore_focus(id: String) -> void:
	if buttons.has(id) and not buttons[id].disabled: _focus_button(buttons[id]); return
	if buttons.has(id):
		var ids: Array = buttons.keys(); var at: int = ids.find(id)
		for offset in ids.size():
			var next = buttons[ids[(at + offset) % ids.size()]]
			if not next.disabled: _focus_button(next); return
	for button in buttons.values():
		if not button.disabled: _focus_button(button); return
	if navigation.has(page): navigation[page].grab_focus()

func _focus_button(button: Button) -> void:
	button.grab_focus()
	# Containers settle their new children's sizes at the next frame. Follow
	# the resulting rectangle, not the temporary zero-sized rebuild position.
	await get_tree().process_frame
	if is_instance_valid(button) and body.is_ancestor_of(button) and button.has_focus(): scroll.ensure_control_visible(button)

func _between() -> bool:
	return not scene.sim.bell_rung() or scene.sim.mode == "OVER" or scene.practice_dummy

func _training_lock() -> void:
	for button in navigation.values(): button.disabled = not training.is_empty()
	for id in footer_buttons: footer_buttons[id].disabled = not training.is_empty() and id != "controls"
	footer_buttons["return"].disabled = not training.is_empty() or scene.sim.mode == "OVER"

func rebuild(focus := true) -> void:
	if not training.is_empty(): return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	buttons.clear()
	var s = scene.sim
	if s._stable_card(selected).is_empty(): selected = str(s.stable[0]["name"])
	_training_lock()
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
			_text("TEACHING BOUTS", 21)
			for id in s.BOUTS.get("ep1", {}):
				var rec: Dictionary = s.BOUTS["ep1"][id]
				var objective := str(s.SCRAPS.get(str(rec["objective"]), {}).get("prompt", "Reach the end of the segment"))
				_button("bout:" + id, str(rec["label"]).capitalize(), func(): start_bout(id), bout_gate)
				_text(objective, 15)
			_text("SPARRING · " + selected, 21)
			_button("choose_fighter", "Choose your fighter in the stable", func(): _page("Stable"))
			_spar_choices(bout_gate)
			_button("dual", "Prepare the team for a dual", prepare_dual, bout_gate)
			_button("practice", "Practice your hands with a stationary partner", func(): close(); scene.begin_fight(true), bout_gate)
		"Stable":
			for card in s.stable:
				var name := str(card["name"])
				_button("fighter:" + name, ("✓ " if name == selected else "") + "%s · level %d · %s" % [name, s.level_of(name), card.get("style", "")], func(): selected = name; partner = "" if partner == name else partner; rebuild(false); _restore_focus("fighter:" + name))
			_text(s.card_view(selected))
			_button("use_fighter", "Spar as " + selected, func(): _page("Bouts"), bout_gate)
			for section in ["Card", "Ability board", "Bean jar", "Roles"]:
				_button("section:" + section, ("• " if section == stable_section else "") + section, func(): stable_section = section; rebuild())
			_stable_details()
		"Recruit":
			_text("Leads point to fighters. Their conditions and the open-mat price decide who joins.")
			_button("scout", "Scout a new lead · %d Prestige" % int(s.ECO.get("prestige", {}).get("pull", 10)), func(): _action(s.scout_pull), s.scout_why())
			_text("Open mat today · signing is free" if s.open_mat_day() else "Priority signing · %d Prestige, or rest until an open-mat day" % int(s._scouting().get("priority", 10)), 15)
			for i in s.open_mat().size():
				var card: Dictionary = s.open_mat()[i]
				_button("sign:%d" % i, "Sign %s · %s" % [card["name"], card["style"]], func(): _action(func(): return s.sign_generic(i)), s.sign_why(i))
			for name in s.recruits_open():
				var view: Dictionary = s.recruit_view(str(name))
				_text(str(name).replace("_", " ").capitalize() + " · " + str(view.get("state", "")), 21)
				for clause in view.get("clauses", []): _text(str(clause.get("text", "")) + (" · met" if clause.get("met", false) else " · still needed"), 15)
				_button("approach:" + name, "Approach " + str(name), func(): _action(func(): return s.approach(name)), bout_gate if bout_gate != "" else ("Conditions already revealed" if view.get("state") == "approached" else ""))
				_button("recruit:" + name, "Invite " + str(name) + " to the club", func(): _action(func(): return s.recruit(name)), bout_gate if bout_gate != "" else ("Meet the visible conditions first" if not view.get("met", false) and not view.get("around_met", false) else ""))
			if s.open_mat().is_empty() and s.recruits_open().is_empty(): _text("Fight and scout to meet people. Winning a dual opens approaches to its rivals.")
		"Formation":
			_formation()
		"Training":
			_text("TRAINING · %d / %d daily slots used · Beans ×%.2f" % [s.training_used(), s.FAC["tracks"]["bags_mitts"]["training"]["slots_per_day"], s.training_mult()], 21)
			_text("Training with " + selected + (" · partner " + partner if partner != "" else " · club training partner when available"))
			for card in s.stable:
				var name := str(card["name"])
				if name != selected: _button("partner:" + name, ("✓ " if partner == name else "") + "Run alongside " + name, func(): partner = "" if partner == name else name; rebuild(), bout_gate)
			_button("roadwork", "Run the Hill with " + selected + " · rhythm and pacing", start_roadwork, s.train_why("roadwork", selected, partner))
			_button("rest", "Rest until tomorrow · refresh daily training", func(): _action(func(): s.new_day(); scene.feed.text = "Day %d · training slots refreshed." % s.rewards["day"]), "Rest after the bout" if s.bell_rung() and s.mode != "OVER" else "")
			for track in s.FAC.get("order", []):
				var label := str(s.FAC["tracks"][track]["label"])
				var next_tier: int = s.fac_tier(track) + 1
				var cost: Dictionary = s.FAC.get("tiers", {}).get(str(next_tier), {})
				_button("renovate:" + track, "Renovate " + label + " · tier %d → %d" % [s.fac_tier(track), next_tier], func(): _action(func(): return s.renovate(track)), s.renovate_why(track))
				if not cost.is_empty(): _text("%d HBP + %d Spirits · %s" % [cost["hbp"], cost["spirits"], s.FAC["tracks"][track].get("effects", {}).get(str(next_tier), "")], 15)
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
		_restore_focus("")

func _spar_choices(gate: String) -> void:
	var s = scene.sim
	var known: Array = [s.boss_names[s._first_boss]]
	for name in s.boss_names:
		if (s.pi.get("bosses", {}).has(name) or s.recruit_state(name) != "" or s.rewards.get("beaten", {}).has(name)) and not name in known: known.append(name)
	var choices: Array = known.duplicate()
	for card in s.stable:
		if str(card["name"]) != selected: choices.append(str(card["name"]))
	if not opponent_pick in choices: opponent_pick = str(choices[0])
	for name in choices:
		_button("opponent:" + name, ("✓ " if opponent_pick == name else "") + "Spar against " + str(name).replace("_", " ").capitalize(), func(): opponent_pick = name; rebuild(), gate)
	_button("spar", "Ring the sparring bell · " + selected + " vs " + opponent_pick.replace("_", " ").capitalize(), start_spar, gate)
	var lab_gate := gate if gate != "" else ("Renovate The Ring to tier %d to open sparring modifiers." % int(s.FAC["tracks"]["the_ring"]["lab_tier"]) if not s.fac_open("the_ring", "lab_tier") else "")
	for flag in ["tell_highlight", "infinite_stamina", "mirror"]:
		var label: String = {"tell_highlight": "Highlight tells · half XP", "infinite_stamina": "Unlimited stamina · combo lab", "mirror": "Mirror spar · face your own habits"}[flag]
		_button("lab:" + flag, ("✓ " if flag in lab_flags else "") + label, func():
			if flag in lab_flags: lab_flags.erase(flag)
			else: lab_flags.append(flag)
			rebuild(), lab_gate)

func _stable_details() -> void:
	var s = scene.sim
	match stable_section:
		"Card":
			_text(s.growth_line(selected))
			_text(s.role_text(selected))
			for card in s.stable:
				var name := str(card["name"])
				if name != selected: _text("%s · bond level %d · %d Kizuna" % [name, s.kizuna_level(selected, name), s.kizuna_pts(selected, name)], 15)
		"Ability board":
			_text("ABILITY BOARD · %d points available" % s.gpoints_free(selected), 21)
			for id in s.growth_nodes(selected):
				var node: Dictionary = s.growth_nodes(selected)[id]
				_button("node:" + id, "%s · %d points" % [node["label"], s.node_cost(selected, id)], func(): _action(func(): return s.take_node(selected, id)), s.node_why(selected, id))
			_button("respec", "Reset ability board · free with Film Room tier 2", func(): _action(func(): return s.respec(selected)), s.respec_why(selected))
		"Bean jar":
			_text(s.jar_text())
			for stat in s.GROW.get("stats", []):
				_button("raise:" + stat, "+1 %s for %s · %d Beans" % [stat, selected, s.raise_cost(selected, stat)], func(): _action(func(): return s.raise_stat(selected, stat)), s.raise_why(selected, stat))
			var spirit_cost: int = s.GROW.get("rarity", {}).get("spirits", {}).get(str(s.rarity_of(selected) + 1), 0)
			_button("ascend", "Ascend " + selected + " · %d Spirits after the trial" % spirit_cost, func(): _action(func(): return s.ascend(selected)), s.ascend_why(selected))
		"Roles":
			_text(s.role_text(selected))
			for role in s.ROLE_IDS:
				_button("role:" + role, "Assign " + selected + " · " + s.role_label(role), func(): _action(func(): return s.assign_role(selected, role)), s.role_why(selected, role))

func _formation() -> void:
	var s = scene.sim
	var ready: bool = not s.bell_rung() and s.bout.is_empty()
	if not ready:
		_text("The order is sealed once the bell rings. Return to the bout; swaps belong to your corner.")
		_button("prepare", "Prepare the next dual", prepare_dual, "Finish the current bout first" if not _between() else "")
	order = s.sealed_p.slice(0, s.board_k())
	var cards: Array = s.board_cards()
	_text("YOUR BOARD · %d starters + %d reserves" % [order.size(), cards.size() - order.size()], 21)
	_text("Choose a position to dress a stablemate. Changes are saved on your board before the bell.")
	for i in cards.size():
		var name := str(cards[i]["name"])
		_button("slot:%d" % i, ("R%d" % (i + 1) if i < order.size() else "Reserve %d" % (i - order.size() + 1)) + " · " + name, func(): slot_pick = i; rebuild(), "Sealed at the bell" if not ready else "")
		if i > 0 and i < order.size(): _button("order:%d" % i, "Move " + name + " earlier", func(): _swap_slots(i, i - 1), "Sealed at the bell" if not ready else "")
	if slot_pick >= 0 and ready:
		_text("DRESS POSITION %d" % (slot_pick + 1), 21)
		for card in s.stable:
			var name := str(card["name"])
			_button("dress:" + name, "Choose " + name + " · " + str(card.get("style", "")), func(): _dress(name))
	if ready:
		for archetype in s.FORMATION.get("order", []):
			_button("preset:" + archetype, "Use " + str(s.FORMATION["archetypes"][archetype]["label"]) + " order", func(): _commit_board({"archetype": archetype, "staff": s.staff_dressed()}))
	_text("CORNER STAFF · choose up to %d" % int(s.STAFF.get("dressed", 3)), 21)
	for rec in s.STAFF.get("corps", []):
		var id := str(rec["id"])
		_button("staff:" + id, ("✓ " if id in s.staff_dressed() else "") + s.staff_name(id), func(): _staff(id), "Sealed at the bell" if not ready else "")
	_text("THEIR PROJECTION", 21)
	for line in s.formation_lines(): _text(str(line), 15)
	_button("seal", "Seal order and ring the bell", start_dual, "Prepare a new dual after this bout" if not ready else "")

func _commit_board(change: Dictionary) -> void:
	_action(func(): return scene.sim.seal_board(change))

func _swap_slots(a: int, b: int) -> void:
	var wanted: Array = scene.sim.board_cards().map(func(c): return str(c["name"]))
	var old = wanted[a]; wanted[a] = wanted[b]; wanted[b] = old
	_commit_board({"dress": wanted, "slots": wanted.slice(0, scene.sim.board_k()), "staff": scene.sim.staff_dressed()})

func _dress(name: String) -> void:
	var wanted: Array = scene.sim.board_cards().map(func(c): return str(c["name"]))
	if slot_pick < 0 or slot_pick >= wanted.size(): return
	if name in wanted:
		var before: int = wanted.find(name); wanted[before] = wanted[slot_pick]
	wanted[slot_pick] = name; slot_pick = -1
	_commit_board({"dress": wanted, "slots": wanted.slice(0, scene.sim.board_k()), "staff": scene.sim.staff_dressed()})

func _staff(id: String) -> void:
	var wanted: Array = scene.sim.staff_dressed().duplicate()
	if id in wanted: wanted.erase(id)
	else: wanted.append(id)
	_commit_board({"slots": order, "staff": wanted})

func start_bout(id: String) -> void:
	if scene.sim.bell_rung() and scene.sim.mode != "OVER" and not scene.practice_dummy: return
	scene.set_practice(false)
	if not scene.sim.start_ep1(id): status.text = "This bout is unavailable."; return
	result_text = ""; reward_text = ""; _enter_ring()

func start_spar() -> void:
	if scene.sim.bell_rung() and scene.sim.mode != "OVER" and not scene.practice_dummy: return
	scene.set_practice(false)
	var s = scene.sim
	var card: Dictionary = s._stable_card(opponent_pick).duplicate(true)
	var boss_index: int = s.boss_names.find(opponent_pick)
	if not card.is_empty():
		card["generic"] = true; card["stablemate"] = true; card["tier"] = s.rarity_of(opponent_pick)
		boss_index = s.boss_names.find(str(s.BOUTS["stand_in"].get(str(card["style"]), "")))
	if boss_index < 0: boss_index = s._first_boss
	if s.start_spar(boss_index, lab_flags, card, "", "", {"fighter": selected}): result_text = ""; reward_text = ""; _enter_ring()

func prepare_dual() -> void:
	if scene.sim.bell_rung() and scene.sim.mode != "OVER" and not scene.practice_dummy: return
	scene.set_practice(false)
	scene.sim.end_bout(); scene.sim.new_dual(); scene._consume_events()
	order = scene.sim.sealed_p.slice(0, scene.sim.board_k()); page = "Formation"; rebuild()

func start_dual() -> void:
	var result: Dictionary = scene.sim.seal_board({"slots": order, "staff": scene.sim.staff_dressed()})
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
	_load_club_path(scene.SAVE_PATH)

func _load_club_path(path: String) -> void:
	if not training.is_empty(): return
	if not scene._load_save(path):
		status.text = "Could not restore this save. Your current club is intact. " + scene.feed.text
		footer_buttons["rollback"].visible = FileAccess.file_exists(scene.SAVE_PATH + ".bak")
		return
	footer_buttons["rollback"].hide()
	scene.set_practice(false); scene.controls_menu.practice.set_pressed_no_signal(false)
	scene.fight_view.clock_sim = null; scene.fight_view.orbit = Vector3.ZERO
	result_text = "Saved bout complete" if scene.sim.mode == "OVER" else ""
	var rewards: Array = scene.sim.rewards.get("log", [])
	reward_text = str(rewards.back()) if not rewards.is_empty() else ""
	order = []; page = "Corner" if scene.sim.mode == "CORNER" else "Bouts"; last_mode = scene.sim.mode
	scene.clock.acc = 0; scene.combat_input.clear(true)
	status.text = "Saved club restored. Return to the ring to continue your bout." if scene.sim.bell_rung() and scene.sim.mode != "OVER" else "Saved club restored."
	rebuild()

func start_roadwork() -> void:
	if scene.sim.train_why("roadwork", selected, partner) != "": return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	buttons.clear()
	_text("THE HILL · ROADWORK", 26)
	_text("Keep your steps in rhythm. Tap when the pacing bar reaches the middle; rushing costs rhythm. Twelve steps, then back to the gym.")
	training_bar = ProgressBar.new(); training_bar.max_value = 1; training_bar.show_percentage = false; training_bar.custom_minimum_size.y = 36; body.add_child(training_bar)
	training_label = _text("", 22)
	var button := _button("step", "Step · Space / Enter", training_step); button.grab_focus()
	training = {"time": 0.0, "next": 0.8, "step": 0, "score": 0.0, "tapped": false, "who": selected, "partner": partner}
	_training_lock()

func training_step() -> void:
	if training.is_empty(): return
	if training["tapped"]: training["score"] = maxf(0, float(training["score"]) - 0.1); return
	training["tapped"] = true
	var error := absf(float(training["time"]) - float(training["next"]))
	training["score"] = float(training["score"]) + maxf(0, 1.0 - error / 0.24)

func _process(delta: float) -> void:
	if visible and not scene.controls_menu.opened: focus_before_controls = get_viewport().gui_get_focus_owner()
	if training.is_empty() or scene.controls_menu.opened: return
	training["time"] = float(training["time"]) + minf(delta, 0.1)
	var remaining := float(training["next"]) - float(training["time"])
	training_bar.value = clampf(0.5 - remaining / 1.6, 0, 1)
	training_label.text = "Step %d / 12 · %s" % [int(training["step"]) + 1, "NOW" if absf(remaining) < 0.16 else "Find the rhythm"]
	if remaining < -0.3:
		training["step"] += 1; training["next"] = float(training["next"]) + 0.8; training["tapped"] = false
		if int(training["step"]) >= 12:
			var grade := float(training["score"]) / 12; var who := str(training["who"]); var with := str(training["partner"]); training.clear()
			_action(func(): return scene.sim.train("roadwork", who, grade, with))

extends CanvasLayer
## Fight information at the edges; the opponent owns the middle of the screen.
## NP-03/04 own behavior. Native Godot Theme owns controls and focus styling.
const INK := Color("111a2b")
const ICE := Color("89c9fa")
const RED := Color("f49a88")
const GOLD := Color("ffd486")
var owner_scene: Node
var surface: Control
var entry: PanelContainer
var start_button: Button
var practice_button: Button
var controls_button: Button
var details: PanelContainer
var detail_scroll: ScrollContainer
var detail_button: Button
var meters := {}
var names := {}
var score: Label
var cue: Label
var message: Label
var hint: Label
var entry_title: Label
var entry_text: Label
var show_details := false
var auto_details := false

func _label(text: String, size: int, parent: Node) -> Label:
	var label := Label.new(); label.text = text; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size); parent.add_child(label)
	return label

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new(); parent.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = INK
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 14; style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 42
	parent.add_child(button); button.pressed.connect(action)
	return button

func setup(scene: Node) -> void:
	owner_scene = scene; layer = 5
	surface = Control.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for who in ["P", "B"]:
		var panel := _panel(surface)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.anchor_left = 0.02 if who == "P" else 0.70; panel.anchor_right = 0.30 if who == "P" else 0.98
		panel.offset_top = 16
		var column := VBoxContainer.new(); column.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(column)
		names[who] = _label("", 20, column)
		for stat in ["Composure", "Stamina", "Guard"]:
			var line := HBoxContainer.new(); line.mouse_filter = Control.MOUSE_FILTER_IGNORE; column.add_child(line)
			var title := _label(stat, 13, line); title.custom_minimum_size.x = 78
			var bar := ProgressBar.new(); bar.show_percentage = false; bar.custom_minimum_size.y = 10
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fill := StyleBoxFlat.new(); fill.bg_color = (ICE if who == "P" else RED) if stat == "Composure" else (GOLD if stat == "Stamina" else Color("bec9db"))
			var back := StyleBoxFlat.new(); back.bg_color = Color("303c50")
			bar.add_theme_stylebox_override("fill", fill); bar.add_theme_stylebox_override("background", back)
			line.add_child(bar); meters[who + stat] = bar
	score = _label("", 24, surface); score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.anchor_left = 0.31; score.anchor_right = 0.69; score.offset_top = 22
	var lower := _panel(surface); lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.anchor_top = 1; lower.anchor_bottom = 1; lower.anchor_right = 1; lower.offset_top = -112
	var bottom := VBoxContainer.new(); bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE; lower.add_child(bottom)
	cue = _label("", 21, bottom); cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cue.add_theme_color_override("font_color", GOLD)
	message = _label("", 14, bottom); message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var actions := HBoxContainer.new(); actions.mouse_filter = Control.MOUSE_FILTER_IGNORE; bottom.add_child(actions)
	hint = _label("", 14, actions); hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_button = _button("Details  Ctrl+F1", actions, func(): show_details = not show_details)
	detail_button.custom_minimum_size.y = 28
	var pause := _button("Controls / pause  Esc", actions, func(): owner_scene.controls_menu.open())
	pause.custom_minimum_size.y = 28
	details = _panel(surface); details.anchor_left = 0.02; details.anchor_right = 0.98
	details.anchor_top = 0.23; details.anchor_bottom = 0.80; details.hide()
	detail_scroll = ScrollContainer.new(); details.add_child(detail_scroll)
	# Keep the complete existing diagnostic/progression surface, now scrollable.
	owner_scene.hud.reparent(detail_scroll); owner_scene.hud.position = Vector2.ZERO
	owner_scene.hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_scene.hud.add_theme_font_size_override("font_size", 15)
	owner_scene.feed.hide()
	var center := CenterContainer.new(); surface.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry = _panel(center); entry.custom_minimum_size.x = 480
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 12); entry.add_child(column)
	entry_title = _label("BEFORE THE BELL", 28, column)
	entry_text = _label("", 18, column); entry_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	start_button = _button("Fight", column, func(): owner_scene.begin_fight(false))
	practice_button = _button("Practice with a stationary opponent", column, func(): owner_scene.begin_fight(true))
	controls_button = _button("Controls and remapping", column, func(): owner_scene.controls_menu.open())
	var buttons := [start_button, practice_button, controls_button]
	for i in buttons.size():
		buttons[i].focus_next = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_previous = buttons[i].get_path_to(buttons[(i + buttons.size() - 1) % buttons.size()])
		buttons[i].focus_neighbor_bottom = buttons[i].focus_next
		buttons[i].focus_neighbor_top = buttons[i].focus_previous
	entry.hide()

func _binding(action: String) -> String:
	var events := InputMap.action_get_events("tnb_" + action)
	return events[0].as_text() if not events.is_empty() else "Unbound"

func show_entry() -> void:
	entry_text.text = "%s vs %s\n\nRead the wind-up. Defend, then counter.\n%s jab  /  %s block  /  %s, %s slip\nHold a punch to commit. Quick taps feint.\n\nThe clock waits for Fight or Practice." % [owner_scene.sim.pname().capitalize(), owner_scene.sim.boss_label.replace("_", " ").capitalize(), _binding("L_STRAIGHT"), _binding("block"), _binding("slip_left"), _binding("slip_right")]
	entry.show(); start_button.grab_focus()

func dismiss_entry() -> void:
	entry.hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func update(sim, practice: bool, feed_text: String) -> void:
	for who in ["P", "B"]:
		var f: Dictionary = sim.P if who == "P" else sim.B
		names[who].text = (sim.pname() if who == "P" else sim.boss_label).replace("_", " ").to_upper()
		names[who].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for stat in ["Composure", "Stamina", "Guard"]:
			var key: String = {"Composure": "comp", "Stamina": "stamina", "Guard": "guard"}[stat]
			meters[who + stat].max_value = 100 if stat == "Stamina" else f[key + "_max"]
			meters[who + stat].value = f[key]
	score.text = "%d   :   %d\n%s" % [sim.score_p, sim.score_b, "PRACTICE" if practice else "R%d   %02d:%02d" % [sim.seg_idx + 1, int(ceil(sim.clock_t / 120.0)) / 60, int(ceil(sim.clock_t / 120.0)) % 60]]
	message.text = feed_text.replace("\n", "  ")
	hint.text = "Tension %d / 100   |   %s" % [sim.tension, "Stationary opponent • Esc to leave practice" if practice else "Watch • defend • counter"]
	cue.text = "Find your distance" if not practice else "Try your punches • hold a key to commit; tap to feint"
	if sim.bstate in ["TELL", "FAKE", "HOLD"] and not practice:
		var tell: Dictionary = sim.pattern.get("strings", {}).get(sim.bstring, {}).get("tell", {})
		cue.text = str(tell.get("motif", "wind-up")).replace("_", " ").to_upper()
	elif int(sim.P["counter_t"]) > 0: cue.text = "COUNTER WINDOW"
	elif sim.bstate == "STAGGER": cue.text = "INTERRUPTED • Follow up"
	elif float(sim.P["stamina"]) < 15: cue.text = "GASSED • Make space and recover"
	if sim.mode == "EIGHT": cue.text = "STANDING EIGHT • Enter / A on the beat • %d to go" % int(sim.eight.get("beats_left", 0))
	elif sim.mode == "CLASH": cue.text = "CLASH • Block or slip their exchange; punch on yours"
	elif sim.mode == "OVER": cue.text = "BOUT OVER • F5 to fight again"
	elif sim.mode == "CORNER": cue.text = "YOUR CORNER • Choose two actions, then send your fighter"
	var want_details: bool = sim.mode in ["CORNER", "CARD", "OVER"] or owner_scene.formation_open or owner_scene.show_formation
	if want_details != auto_details: show_details = want_details
	auto_details = want_details
	details.visible = show_details and not entry.visible
	detail_button.text = ("Hide details" if details.visible else "Details") + "  Ctrl+F1"

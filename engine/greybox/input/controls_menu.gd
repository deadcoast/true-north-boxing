extends CanvasLayer
## In-game controls: remapping is available without editing a file.

signal closed
signal practice_changed(enabled: bool)
var adapter: RefCounted
var panel: PanelContainer
var status: Label
var rows: GridContainer
var waiting := ""
var waiting_button: Button
var opened := false
var preset_choice: OptionButton
var practice: CheckButton

func setup(input_adapter: RefCounted) -> void:
	adapter = input_adapter
	layer = 20
	panel = PanelContainer.new(); add_child(panel)
	var surface := StyleBoxFlat.new(); surface.bg_color = Color(0.075, 0.085, 0.105, 1.0)
	surface.content_margin_left = 18; surface.content_margin_right = 18
	surface.content_margin_top = 14; surface.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", surface)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24; panel.offset_right = -24
	panel.offset_top = 24; panel.offset_bottom = -24
	var box := VBoxContainer.new(); panel.add_child(box)
	box.add_theme_constant_override("separation", 10)
	var title := Label.new(); title.text = "TWO HANDS  /  CONTROLS"; title.add_theme_font_size_override("font_size", 24); box.add_child(title)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.text = "Mouse: hold left button and flick.  Alt + punch: charged haymaker.\nChords: Back selects left hand; A / B / X / Y / D-pad Up select the punch.\nHold D-pad Down to wind up. All presets use the same combat rules."
	box.add_child(description)
	var preset := OptionButton.new(); preset_choice = preset; preset.add_item("Stick flicks + keyboard / mouse"); preset.add_item("Accessible button chords + keyboard / mouse")
	preset.select(1 if adapter.preset == "chords" else 0); box.add_child(preset)
	preset.item_selected.connect(func(i): adapter.preset = "chords" if i == 1 else "flick"; adapter.clear(); _save())
	practice = CheckButton.new(); practice.text = "Practice against a stationary dummy"; box.add_child(practice)
	practice.toggled.connect(func(on): practice_changed.emit(on))
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(0, 120); scroll.follow_focus = true; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	rows = GridContainer.new(); rows.columns = 2; rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(rows)
	_build_rows()
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD; status.text = "Select a binding, then press its replacement. Escape cancels."; box.add_child(status)
	var buttons := HBoxContainer.new(); box.add_child(buttons)
	var reset := Button.new(); reset.text = "Restore defaults"; buttons.add_child(reset)
	reset.pressed.connect(func(): adapter.reset_bindings(); waiting = ""; _build_rows(); _save())
	var resume := Button.new(); resume.text = "Return to ring"; buttons.add_child(resume); resume.pressed.connect(close)
	panel.hide()

func _build_rows() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	for action in adapter.actions:
		var label := Label.new(); label.text = ("Hissatsu arm" if action == "lb" else str(action).replace("L_", "Left ").replace("R_", "Right ").replace("_", " ").capitalize()); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rows.add_child(label)
		var button := Button.new(); button.text = _binding_text(action); button.custom_minimum_size.x = 330; rows.add_child(button)
		button.pressed.connect(_begin_bind.bind(action, button))

func _binding_text(action: String) -> String:
	var labels := PackedStringArray()
	for event in InputMap.action_get_events(adapter.PREFIX + action): labels.append(event.as_text())
	return " / ".join(labels)

func _begin_bind(action: String, button: Button) -> void:
	waiting = action; waiting_button = button
	status.text = "Press a key, mouse button, or controller input for " + action.replace("_", " ") + "."

func _save() -> void:
	var result: Error = adapter.save_settings()
	status.text = "Controls saved." if result == OK else "Could not save controls: " + error_string(result)

func open() -> void:
	adapter.clear(true); opened = true; panel.show(); preset_choice.grab_focus()

func close() -> void:
	waiting = ""; adapter.clear(true); opened = false; panel.hide(); closed.emit()

func _input(event: InputEvent) -> void:
	if not opened: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if waiting != "": waiting = ""; status.text = "Binding cancelled."
		else: close()
		get_viewport().set_input_as_handled(); return
	if waiting == "": return
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.8: return
	elif not event.is_pressed() or event.is_echo(): return
	if adapter.rebind(waiting, event):
		waiting_button.text = _binding_text(waiting); waiting = ""; _save()
		get_viewport().set_input_as_handled()

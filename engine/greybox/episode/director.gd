extends CanvasLayer
## NP-12A: one saved episode over the existing sim, not a second combat engine.
const Campaign := preload("res://episode/campaign.gd")
const World := preload("res://episode/harbourline.gd")
const Save := preload("res://sim/save.gd")
const Locale := preload("res://episode/locale.gd")
const Staging := preload("res://episode/staging.gd")
const Broadcast := preload("res://episode/broadcast.gd")
const RigSpace := preload("res://presentation/rig_space.gd")
const SAVE_PATH := "user://tnb_episode.json"
var scene: Node
var sandbox_sim
var world: Node3D
var data: Dictionary
var language := "en"
var active := true
var state := "title"
var surface: Control
var panel: PanelContainer
var panel_frame: MarginContainer
var column: VBoxContainer
var heading: Label
var body: Label
var quest: Label
var hint: Label
var buttons := {}
var keys := {}
var pending: Array[Dictionary] = []
var status := ""
var pause_from := "world"
var training := {}
var training_bar: ProgressBar
var last_mode := ""
var seconds := 0.0
var autosave_t := 0.0
var transition_t := 0.0
var transition_from := Transform3D.IDENTITY
var transition_target := ""
var transition_camera: Camera3D
var transition_to := Transform3D.IDENTITY
var vignette: ColorRect
var bars: Array[ColorRect] = []
var freeze_t := 0.0
var episode_environment: WorldEnvironment
var sandbox_environment: Environment
var staging: Node
var broadcast: Node
var archive_drop := {}
var handoff_t := -1.0
var handoff_camera := Transform3D.IDENTITY
var handoff_fov := 40.0
var handoff_rotation := Quaternion.IDENTITY
var handoff_parts: Array = []

func text(en: String, fr: String) -> String: return fr if language == "fr_CA" else en

func setup(owner_scene: Node) -> void:
	scene = owner_scene; sandbox_sim = scene.sim; layer = 9
	data = JSON.parse_string(FileAccess.get_file_as_string(Campaign.DATA_PATH))
	world = World.new(); scene.add_child(world); world.setup(data, language)
	transition_camera = Camera3D.new(); scene.add_child(transition_camera)
	for child in scene.get_children():
		if child is WorldEnvironment:
			episode_environment = child; sandbox_environment = child.environment
			var environment := Environment.new(); environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("7897a6")
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color("adbec9"); environment.ambient_light_energy = 0.65
			environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			child.environment = environment
	surface = Control.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest = _label(surface, "", 19); quest.position = Vector2(26, 22); quest.size = Vector2(700, 100)
	quest.add_theme_color_override("font_shadow_color", Color("112632")); quest.add_theme_constant_override("shadow_outline_size", 8)
	hint = _label(surface, "", 17); hint.anchor_top = 1; hint.anchor_bottom = 1; hint.anchor_right = 1; hint.offset_left = 26; hint.offset_top = -76; hint.offset_right = -26
	hint.add_theme_color_override("font_shadow_color", Color("112632")); hint.add_theme_constant_override("shadow_outline_size", 8)
	var center := MarginContainer.new(); surface.add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 48); center.add_theme_constant_override("margin_right", 48)
	center.add_theme_constant_override("margin_top", 126); center.add_theme_constant_override("margin_bottom", 98)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_frame = center
	panel = PanelContainer.new(); center.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("15232bf5"); style.border_color = Color("c3a36a"); style.border_width_top = 3
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: style.set_content_margin(side, 22)
	panel.add_theme_stylebox_override("panel", style)
	var theme := Theme.new(); theme.default_font_size = 18
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = {"normal":Color("2c4048"), "hover":Color("415a60"), "pressed":Color("5c6b66"), "disabled":Color("26343a"), "focus":Color(0,0,0,0)}[kind]
		button_style.content_margin_left = 16; button_style.content_margin_right = 16; button_style.content_margin_top = 10; button_style.content_margin_bottom = 10
		if kind == "focus": button_style.set_border_width_all(2); button_style.border_color = Color("e3be7c")
		theme.set_stylebox(kind, "Button", button_style)
	panel.theme = theme
	var scroll := ScrollContainer.new(); panel.add_child(scroll); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column = VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation", 13); scroll.add_child(column)
	for side in 2:
		var bar := ColorRect.new(); bar.color = Color(0.03, 0.025, 0.018); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0 if side == 0 else 0.875; bar.anchor_right = 0.125 if side == 0 else 1; bar.anchor_bottom = 1
		surface.add_child(bar); bar.hide(); bars.append(bar)
	vignette = ColorRect.new(); vignette.color = Color(0.9, 0.95, 1, 0); vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(vignette); vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	staging = Staging.new(); add_child(staging); staging.setup(self)
	broadcast = Broadcast.new(); add_child(broadcast); broadcast.setup(self)
	_title()
	scene.controls_menu.closed.connect(func():
		keys.clear()
		if active and panel.visible:
			for button in buttons.values():
				if is_instance_valid(button) and not button.disabled: _focus_button.call_deferred(button); break)

func _label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new(); label.text = value; label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("eee8d7")); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(label); return label

func _page(title: String, copy := "") -> void:
	keys.clear(); scene.combat_input.clear(true); panel.show(); buttons.clear()
	for child in column.get_children(): column.remove_child(child); child.queue_free()
	heading = _label(column, title, 30); body = _label(column, copy, 21)
	body.visible = copy != ""
	for bar in bars: bar.hide()
	quest.visible = false; hint.text = text("Enter / A · choose     Esc · controls and pause", "Entrée / A · choisir     Échap · commandes et pause")
	panel_frame.anchor_left = 0.12 if state == "title" else 0
	panel_frame.anchor_right = 0.88 if state == "title" else 1
	panel_frame.anchor_top = 0.52 if state == "dialogue" else 0
	panel_frame.anchor_bottom = 1
	panel_frame.add_theme_constant_override("margin_top", 18 if state == "dialogue" else 88)
	panel_frame.add_theme_constant_override("margin_bottom", 88)

func _button(id: String, value: String, action: Callable, why := "") -> Button:
	var button := Button.new(); button.text = value if why == "" else value + "   ·   " + why
	button.custom_minimum_size.y = 44; button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.disabled = why != ""; column.add_child(button); buttons[id] = button
	button.pressed.connect(action)
	if buttons.size() == 1 and not button.disabled: _focus_button.call_deferred(button)
	return button

func _focus_button(button) -> void:
	# Loading/replacing a page can remove its default button before deferred
	# focus runs. Never focus a detached or already discarded page.
	if is_instance_valid(button) and button.is_inside_tree() and not button.is_queued_for_deletion() and button.is_visible_in_tree() and not button.disabled:
		button.grab_focus()

func _title() -> void:
	if broadcast != null: broadcast.clear()
	if staging != null: staging.clear()
	state = "title"; _show_world()
	_page("TRUE NORTH BOXING", text("EPISODE 1 — THE LETTER\nMillbrook. Five days. Four dressed. Two segment victories to keep the charter.", "ÉPISODE 1 — LA LETTRE\nMillbrook. Cinq jours. Quatre en tenue. Deux segments gagnés pour sauver la charte."))
	_button("new", text("Begin The Letter", "Commencer La Lettre"), func(): new_episode(language))
	_button("continue", text("Continue episode", "Continuer l’épisode"), load_episode, "" if FileAccess.file_exists(SAVE_PATH) else text("No episode saved", "Aucune sauvegarde"))
	if FileAccess.file_exists(SAVE_PATH + ".bak"): _button("backup", text("Recover previous episode save", "Récupérer la sauvegarde précédente"), func(): _load_episode_path(SAVE_PATH + ".bak"))
	_button("language", "English / Français (Canada)", func(): language = "fr_CA" if language == "en" else "en"; _language(); _title())
	_button("sandbox", text("Club sandbox · existing club save", "Club libre · sauvegarde du club"), _sandbox)
	if status != "": _label(column, status, 16)

func _language() -> void:
	if broadcast != null: broadcast.clear()
	Locale.use(language)
	world.language = language
	for object in data["objects"]: world.labels[object["id"]].text = object[language]
	# District signs are localized as well as the interaction prompts.
	for child in world.get_children():
		if not child is Label3D: continue
		for place in data["places"]:
			if child.text in [place["en"], place["fr_CA"]]: child.text = place[language]

func _sandbox() -> void:
	broadcast.clear()
	staging.clear(); staging.ambience.stop(); staging.foley.stop()
	Locale.use("en")
	scene.sim = sandbox_sim; scene.controls_menu.practice.disabled = false
	if episode_environment != null: episode_environment.environment = sandbox_environment
	active = false; hide(); world.hide(); scene.cam.make_current(); scene.get_meta("arena").show(); scene.player.show(); scene.boss.show()
	scene.fight_hud.show(); scene.club_flow.enabled = true; scene.club_flow.open()

func new_episode(lang: String) -> void:
	if FileAccess.file_exists(SAVE_PATH) and DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".previous") != OK:
		status = text("Could not preserve the previous episode. New episode was not started.", "Impossible de conserver l’épisode précédent. Nouvelle partie annulée."); _title(); return
	scene.set_practice(false); training = {}; pending.clear(); archive_drop.clear()
	language = lang; _language(); scene.sim = Campaign.fresh(scene.content, language, 1976)
	broadcast.reset()
	handoff_t = -1; handoff_parts.clear()
	scene.controls_menu.practice.disabled = true
	scene.club_flow.enabled = false; scene.club_flow.close(); scene.fight_hud.dismiss_entry()
	world.restore([0.0, 6.0]); world.sync(scene.sim); _dialogue("archive")

func _ep() -> Dictionary: return Campaign.state(scene.sim)

func _dialogue(id: String, resume := false) -> void:
	state = "dialogue"; _ep()["dialogue"] = id
	if not resume: _ep()["line"] = 0
	var lines: Array = data["scenes"][id]
	var index := clampi(int(_ep()["line"]), 0, lines.size() - 1)
	_ep()["line"] = index
	_page(str(lines[index][0]), str(lines[index][2 if language == "fr_CA" else 1]))
	_label(column, "%02d / %02d" % [index + 1, lines.size()], 14)
	_button("next", text("Continue", "Continuer"), next_line)
	freeze_t = staging.begin(id, index)
	broadcast.dialogue(id, index)
	if freeze_t > 0:
		buttons["next"].disabled = true
		panel.hide(); hint.text = ""
	if id == "archive" and index == 1:
		# The missing name is a timed one-second absence, never another name.
		buttons["next"].disabled = true; freeze_t = 1.0
		panel.hide()
	if id == "tag":
		if index == 2: panel.hide(); buttons["next"].disabled = true
	save_episode()

func next_line() -> void:
	if state != "dialogue" or freeze_t > 0: return
	broadcast.finish_dialogue()
	var id := str(_ep()["dialogue"]); _ep()["line"] = int(_ep()["line"]) + 1
	if int(_ep()["line"]) < data["scenes"][id].size(): _dialogue(id, true); return
	_ep()["dialogue"] = ""; _ep()["line"] = 0
	match id:
		"archive": Campaign.archive(scene.sim); _fight()
		"present": _shadow_handoff()
		"letter": Campaign.mark(scene.sim, "letter"); _world()
		"priya": _start_bout("priya_trial")
		"priya_join": Campaign.join(scene.sim, "PRIYA"); _world()
		"marcus_join": Campaign.join(scene.sim, "MARCUS"); _world()
		"june_join": Campaign.join(scene.sim, "JUNE"); _world()
		"binders": Campaign.mark(scene.sim, "binders"); _world()
		"survival": _board()
		"vane": _fight(false)
		"tag": _closing_wall()
		_: _world()
	save_episode()

func _show_world() -> void:
	if staging != null: staging.clear()
	var returning: bool = scene.cam.current and world.position != Vector3.ZERO
	var from: Transform3D = scene.cam.global_transform
	from.origin -= world.position
	world.position = Vector3.ZERO; world.actor.show()
	world.stage("world")
	for name in world.cast: world.cast[name].visible = scene.sim._stable_card(name).is_empty()
	world.show(); world.camera.make_current(); scene.get_meta("arena").hide(); scene.player.hide(); scene.boss.hide()
	scene.fight_hud.hide(); scene.formation_open = false
	if returning: _swing(from, world.camera.global_transform, "world")

func _swing(from: Transform3D, to: Transform3D, target: String) -> void:
	transition_t = 0.65; transition_from = from; transition_to = to; transition_target = target
	transition_camera.global_transform = from; transition_camera.fov = 50; transition_camera.make_current()
	keys.clear(); scene.combat_input.clear(true)

func _world() -> void:
	broadcast.clear()
	state = "world"; _ep()["phase"] = "world"; _ep()["dialogue"] = ""; _ep()["fight"] = ""
	training = {}; panel.hide(); quest.show(); _show_world(); world.sync(scene.sim)
	_ep().erase("training")
	scene.set_practice(false); scene.club_flow.close(); keys.clear(); scene.combat_input.clear(true)
	for bar in bars: bar.hide()
	world.position = Vector3.ZERO; world.restore(_ep()["position"]); save_episode()
	world.stage("world")
	_world_caption()

func _world_caption() -> void:
	quest.position = Vector2(26, 22); quest.size.x = minf(750, get_viewport().get_visible_rect().size.x - 52)
	var district_name := str(world.district).to_upper()
	for place in data["places"]:
		if place["id"] == world.district: district_name = place[language]
	quest.text = "HARBOURLINE · " + district_name + "\n" + _objective()
	hint.text = text("WASD / LS · walk   Shift · jog   E / A · interact   Tab / Start · journal", "WASD / SG · marcher   Maj · courir   E / A · interagir   Tab / Start · carnet")
	if world.nearest != "": hint.text += "\n[E / A] " + str(world.labels[world.nearest].text)

func _objective() -> String:
	if not Campaign.has(scene.sim, "letter"): return text("Finish the morning round. Read Whitlock’s letter.", "Termine la ronde du matin. Lis la lettre de Whitlock.")
	if not Campaign.has(scene.sim, "joined_PRIYA"): return text("Four dressed by Saturday · Find Priya at the school library.\nBike racks: land three body shots.", "Quatre en tenue samedi · Trouve Priya à la bibliothèque.\nPrès des vélos : place trois coups au corps.")
	if not Campaign.ready(scene.sim): return text("Community Centre · Marcus: survive 20 seconds. June: win a centre exchange.\nComplete the body-shot lesson at the school bike racks.", "Centre communautaire · Marcus : tiens 20 secondes. June : gagne un échange au centre.\nTermine la leçon au corps près des vélos.")
	return text("Four dressed · Read Priya’s binders, train, then seal Saturday’s order at the gym.\nTwo real segment victories keep the charter.", "Quatre en tenue · Lis les cartables, entraîne-toi, puis scelle l’ordre au gymnase.\nDeux segments gagnés sauvent la charte.")

func handle(event: InputEvent) -> bool:
	if not active: return false
	if transition_t > 0: return true
	if event is InputEventKey:
		keys[event.keycode] = event.pressed
		if event.pressed and not event.echo:
			if state == "world" and event.keycode == KEY_E: interact(); return true
			if event.keycode == KEY_F10: save_episode(); return true
			if event.keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F9, KEY_F11, KEY_F12]: return true
			if event.keycode == KEY_R:
				var rebound := false
				for action in scene.combat_input.actions: rebound = rebound or event.is_action("tnb_" + action)
				if not rebound: return true
			if state in ["world", "fight"] and event.keycode == KEY_TAB: _pause(); return true
			if state == "training" and training.get("game") == "roadwork" and event.keycode == KEY_ENTER: training_tap(); return true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A and state == "world": interact(); return true
		if event.button_index == JOY_BUTTON_START and state in ["world", "fight"]: _pause(); return true
		if event.button_index == JOY_BUTTON_A and state == "training" and training.get("game") == "roadwork": training_tap(); return true
	# Story owns menu and travel input. Combat keys go unchanged to CombatInput.
	return state not in ["fight", "training"] or (state == "training" and training.get("game") == "roadwork")

func interact() -> void:
	if state != "world" or world.nearest == "": return
	_ep()["position"] = world.point()
	var id: String = world.nearest
	match id:
		"letter": _dialogue("letter")
		"priya":
			if Campaign.has(scene.sim, "joined_PRIYA"): _info(text("Priya is with your squad.", "Priya fait partie de l’équipe."))
			else: _dialogue("priya")
		"scrap_1", "scrap_2", "scrap_3": _bout_prompt(id)
		"wall": _wall()
		"locker": _locker()
		"film": _film()
		"board":
			if Campaign.ready(scene.sim): _dialogue("survival")
			else: _info(_objective())
		"mitts", "shadow", "roadwork": _training_prompt(id)
		"transit": _info(text("Harbourline · season routes\nAnnex, Downtown, Rink, Industrial and Hills routes reopen as the season advances. Today’s route stays in Millbrook.\nRoadwork begins beside the wharf.", "Harbourline · routes de saison\nL’Annexe, le centre-ville, l’aréna, le secteur industriel et les collines ouvrent avec la saison. Aujourd’hui, on reste à Millbrook.\nLa course commence près du quai."))

func _info(copy: String) -> void:
	state = "inspect"; _page(text("MILLBROOK · CLUB", "MILLBROOK · LE CLUB"), copy)
	_button("back", text("Back to Harbourline", "Retour à Harbourline"), _world)

func _pause() -> void:
	if state in ["world", "fight"]: pause_from = state
	state = "inspect"; _page(text("THE LETTER · PAUSED", "LA LETTRE · PAUSE"), status)
	_button("back", text("Resume", "Reprendre"), func():
		if pause_from == "fight": _fight(false)
		else: _world())
	_button("save", text("Save episode", "Sauvegarder"), func(): save_episode(); _pause())
	_button("load", text("Load episode", "Charger l’épisode"), load_episode)
	_button("language", "English / Français (Canada)", func(): language = "fr_CA" if language == "en" else "en"; _ep()["language"] = language; _language(); _pause())
	_button("title", text("Title screen", "Écran titre"), func(): save_episode(); _title())

func _bout_prompt(id: String) -> void:
	state = "inspect"
	var copy := {"scrap_1":text("Three body shots · Hold C / LT while punching.\nAn avoidable challenger, not an ambush. The shared scrap judge decides the result.", "Trois coups au corps · Maintiens C / LT en frappant.\nUn défi volontaire. L’objectif décide du résultat."), "scrap_2":text("Marcus Halloran · Survive 20 seconds.\nRead the loud tell. Block, slip and keep your feet under you. Win to recruit Marcus.", "Marcus Halloran · Tiens 20 secondes.\nLis le signal, bloque, esquive et garde tes appuis. Réussis pour recruter Marcus."), "scrap_3":text("June Park · Win one exchange in centre ring.\nA fast Swarmer. Meet her at the centre; land clean to recruit her.", "June Park · Gagne un échange au centre.\nElle presse vite. Rejoins-la au centre et place un coup net pour la recruter.")}
	_page(text("GLOVE UP?", "ON MET LES GANTS?"), copy[id])
	_button("glove_up", text("Glove up", "Mettre les gants"), func(): _start_bout(id))
	_button("back", text("Keep walking", "Continuer à marcher"), _world)

func _start_bout(id: String) -> void:
	if not scene.sim.bout.is_empty(): scene.sim.end_bout()
	if not scene.sim.start_ep1(id): _info(text("This bout could not start.", "Impossible de lancer le combat.")); return
	_ep()["fight"] = id; _ep()["phase"] = "fight"; _ep()["dialogue"] = ""
	_fight()

func _fight(reset := true) -> void:
	staging.clear()
	var entering: bool = world.visible and not scene.cam.current
	var centre := Vector3.ZERO
	match _ep().get("fight", ""):
		"scrap_1": centre = Vector3(-26, 0, -13)
		"priya_trial": centre = Vector3(-30, 0, -24)
		"scrap_2", "scrap_3": centre = Vector3(30, 0, -24)
	world.position = -centre; world.show(); world.actor.hide()
	world.stage(str(_ep().get("fight", "")))
	for person in world.cast.values(): person.hide()
	for member in world.squad: member.hide()
	for label in world.labels.values(): label.hide()
	var from: Transform3D = world.camera.global_transform
	state = "fight"; panel.hide(); quest.show()
	scene.get_meta("arena").show(); scene.player.show(); scene.boss.show(); scene.cam.make_current(); scene.fight_hud.show()
	scene.club_flow.enabled = false; scene.club_flow.close(); scene.formation_open = false
	if reset:
		scene.clock.acc = 0; scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
		scene.fight_view.clock_sim = null; scene.fight_view.orbit = Vector3.ZERO
		scene.begin_fight(false); scene._consume_events()
	_ep()["phase"] = "fight"; last_mode = scene.sim.mode
	quest.position.y = 170; quest.size.x = 520
	for bar in bars: bar.visible = _ep().get("fight") == "archive"
	scene._render(1.0); scene._hud(); _fight_caption()
	if entering: _swing(from, scene.cam.global_transform, "fight")
	save_episode()

func _board() -> void:
	scene.sim = Campaign.prepare(scene.content, scene.sim)
	if scene.sim == null: push_error("Episode roster gate failed"); return
	state = "board"; _show_world()
	_page(text("SATURDAY · THE WHITEBOARD", "SAMEDI · LE TABLEAU"), text("R1  MARCUS · bank 25 Tension against the Out-Boxer\nR2  PRIYA · the right lead on exchange three\nR3  RORY · Cassidy Vane\nRESERVE  JUNE\n\nTwo segment victories. No result is guaranteed. Your corner gets two actions; Priya wants the plan confirmed.", "R1  MARCUS · accumule 25 de tension face au styliste\nR2  PRIYA · la droite au troisième échange\nR3  RORY · Cassidy Vane\nRÉSERVE  JUNE\n\nDeux segments gagnés. Rien n’est garanti. Deux actions au coin; Priya veut qu’on confirme le plan."))
	var projection: Dictionary = scene.sim.projection()
	_label(column, text("Binder projection", "Projection du cartable") + " · %d%%" % int(projection.get("pct", 0)), 19)
	_button("bell", text("Seal this order · ring the bell", "Sceller cet ordre · sonner la cloche"), _fight)
	_button("back", text("More preparation", "Poursuivre la préparation"), _world)
	save_episode()

func _wall() -> void:
	var copy := text("Whitlock’s letter · TWO SEGMENT VICTORIES\n", "La lettre de Whitlock · DEUX SEGMENTS GAGNÉS\n")
	for card in scene.sim.stable:
		copy += str(card["name"]) + "  ·  " + str(card.get("style", "")) + "\n"
		for other in scene.sim.stable:
			if str(other["name"]) > str(card["name"]): copy += "   %s ↔ %s   Kizuna %d   Lv%d\n" % [card["name"], other["name"], scene.sim.kizuna_pts(card["name"], other["name"]), scene.sim.kizuna_level(card["name"], other["name"])]
	if Campaign.has(scene.sim, "survival"): copy += text("\nCarbon copy · CHARTER STANDS", "\nDouble carbone · CHARTE MAINTENUE")
	_info(copy)

func _locker(selected := "RORY") -> void:
	state = "inspect"
	var copy := text("Level %d · %d XP · %d Board Points\nBeans: %d · Prestige: %d", "Niveau %d · %d XP · %d points de progression\nHaricots : %d · Prestige : %d") % [scene.sim.level_of(selected), scene.sim.xp_of(selected), scene.sim.gpoints_free(selected), scene.sim.rewards.get("beans", 0), scene.sim.rewards.get("prestige", 0)]
	var stats: Dictionary = scene.sim.grown_stats(scene.sim._stable_card(selected))
	copy += "\n" + "   ".join(PackedStringArray(stats.keys().map(func(k): return str(k) + " " + str(stats[k]))))
	_page(text("THE LOCKER · ", "LE VESTIAIRE · ") + selected, copy)
	for card in scene.sim.stable:
		var name := str(card["name"])
		if name != selected: _button("card:" + name, name, func(): _locker(name))
	var count := 0
	for id in scene.sim.growth_nodes(selected):
		if id == "root": continue
		if count >= 6: break
		count += 1
		var node: Dictionary = scene.sim.growth_nodes(selected)[id]
		_button("node:" + id, "%s · %d %s" % [node["label"], scene.sim.node_cost(selected, id), text("points", "points")], func(): scene.sim.take_node(selected, id); save_episode(); _locker(selected), Locale.node_reason(scene.sim, selected, id, language == "fr_CA"))
	for stat in ["PWR", "SPD", "STA", "RFX"]:
		_button("raise:" + stat, "+1 %s · %d %s" % [stat, scene.sim.raise_cost(selected, stat), text("Beans", "haricots")], func(): scene.sim.raise_stat(selected, stat); save_episode(); _locker(selected), Locale.raise_reason(scene.sim, selected, stat, language == "fr_CA"))
	_button("back", text("Back to the gym", "Retour au gymnase"), _world)

func _film() -> void:
	if not Campaign.has(scene.sim, "joined_PRIYA"): _info(text("The Scout Book shelf is empty. Find someone smarter than us.", "Le carnet est vide. Trouve quelqu’un de plus brillant que nous.")); return
	if not Campaign.has(scene.sim, "binders"): _dialogue("binders"); return
	state = "inspect"; _page(text("PRIYA’S BINDERS", "LES CARTABLES DE PRIYA"), text("VANE · listens to the tablet. Sequences. NUMBERED.\nR2 · leads right on the third exchange.\nMockup spars teach the same dialect; completing them earns Pattern Intel.", "VANE · écoute la tablette. Séquences NUMÉROTÉES.\nR2 · part de la droite au troisième échange.\nLes combats préparatoires enseignent le dialecte et rapportent du renseignement."))
	_label(column, "VANE · PI %d" % scene.sim.pi_level("cassidy_vane"), 22)
	for i in 3:
		_button("mockup:" + str(i), text("Sequence mockup ", "Séquence préparatoire ") + str(i + 1), func(): _mockup(i))
	_button("back", text("Back to the gym", "Retour au gymnase"), _world)

func _mockup(index: int) -> void:
	if not scene.sim.bout.is_empty(): scene.sim.end_bout()
	var spec: Dictionary = scene.sim.generic_spec("MOCKUP", ["OUTBOXER", "SLUGGER", "BOXERPUNCHER"][index], "cassidy_vane", 1, 300 + index, "PRIYA · VANE " + str(index + 1))
	var card: Dictionary = spec.duplicate(true); card["generic"] = true
	if scene.sim.start_spar(0, ["tell_highlight"], card, "SEGMENT_END", "PRIYA · VANE", {"authored":true}):
		# NP-12A explicitly asks for mockups OF Ascendant sequences. An unknown
		# generic dialect otherwise falls back to gym visual tells. Rehearse one
		# real code at a time, with its own actions and interrupt rule; generic
		# opponents elsewhere still use the piece library, not named-boss strings.
		var authored: Dictionary = scene.sim.patterns["cassidy_vane"]
		var string: String = ["S1", "S2", "S3"][index]
		var drill: Dictionary = authored.duplicate(true)
		drill["strings"] = {string: authored["strings"][string].duplicate(true)}
		drill["strings"][string]["tags"] = []
		drill["select"] = {"weights": {string: 100}, "reweights": []}
		drill["interrupt"] = [{"strings": [string], "response": "stagger(800)"}] if index != 1 else []
		for section in ["phases", "punish", "bait"]: drill[section] = []
		scene.sim.pattern = drill; scene.sim.gpatterns["MOCKUP"] = drill.duplicate(true)
		_ep()["fight"] = "mockup"; _fight()

func _training_prompt(game: String) -> void:
	state = "inspect"
	var names := {"shadow":text("SHADOW ROUNDS", "BOXE DANS LE VIDE"), "mitts":text("MITTS", "PATTES D’OURS"), "roadwork":text("ROADWORK", "COURSE")}
	_page(names[game], text("Practice the rhythm with your own inputs. The introductory shadow and mitt sessions are coaching drills. Paid facility training keeps its upgrade requirements and three slots per day.", "Travaille le rythme avec tes propres commandes. Les introductions à la boxe dans le vide et aux pattes d’ours sont des leçons. Les séances rémunérées gardent leurs conditions d’amélioration et leurs trois créneaux par jour."))
	_button("train", text("Start coaching drill", "Commencer la leçon"), func(): _training(game, false))
	_button("back", text("Back", "Retour"), _world)

func _shadow_handoff() -> void:
	# The raised glove and camera continue into the existing responsive boxing
	# rig. Blend presentation only; no simulated punch or lesson credit is given.
	var at: Vector3 = world.actor.global_position
	handoff_camera = world.camera.global_transform; handoff_fov = world.camera.fov
	handoff_rotation = world.actor.quaternion
	handoff_parts.clear()
	for key in ["head", "mesh", "hips", "neck", "abdomen", "gloves", "arms", "legs", "upper_arms", "thighs", "boots", "joints", "clavicles"]:
		var from = world.actor.get_meta(key); var to = scene.player.get_meta(key)
		if from is Array:
			for i in from.size(): handoff_parts.append({"node":to[i], "from":from[i].transform})
		else: handoff_parts.append({"node":to, "from":from.transform})
	_training("shadow", true)
	transition_t = 0; handoff_t = 0
	scene.sim.P["pos"] = Vector2(at.x, at.z) / RigSpace.GROUND_SCALE
	scene.sim.B["pos"] = scene.sim.P["pos"] + Vector2(0, -3)
	scene.prev_p = scene.sim.P["pos"]; scene.prev_b = scene.sim.B["pos"]
	scene.cam.make_current(); scene._render(1.0)
	save_episode()

func finish_frame() -> void:
	if not active or state != "training" or training.get("game") != "shadow": return
	if handoff_t >= 0:
		var pose_weight := smoothstep(0.0, 0.22, handoff_t)
		scene.player.quaternion = handoff_rotation.slerp(scene.player.quaternion, pose_weight)
		for part in handoff_parts:
			var node: Node3D = part["node"]
			node.transform = (part["from"] as Transform3D).interpolate_with(node.transform, pose_weight)
	# Keep Rory's world identity throughout. His visible rig follows the real
	# combat pose; the opponent-visibility silhouette has no purpose in shadowwork.
	scene.player.hide(); world.actor.show()
	world.actor.global_transform = scene.player.global_transform
	for key in ["head", "mesh", "hips", "neck", "abdomen", "gloves", "arms", "legs", "upper_arms", "thighs", "boots", "joints", "clavicles"]:
		var from = scene.player.get_meta(key); var to = world.actor.get_meta(key)
		if from is Array:
			for i in from.size(): to[i].transform = from[i].transform
		else: to.transform = from.transform
	scene.cam.global_position = scene.player.global_position + Vector3(3.5, 2.4, 4.5)
	scene.cam.look_at(scene.player.global_position + Vector3.UP)
	scene.cam.fov = 55
	if handoff_t >= 0:
		var camera_weight := smoothstep(0.0, 0.65, handoff_t)
		scene.cam.global_transform = handoff_camera.interpolate_with(scene.cam.global_transform, camera_weight)
		scene.cam.fov = lerpf(handoff_fov, 55, camera_weight)

func _training(game: String, intro: bool, restored := {}) -> void:
	training = restored if not restored.is_empty() else {"game":game, "intro":intro, "t":0.0, "score":0.0, "beats":0, "hit":false, "accepted":0, "sequence":["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_HOOK", "L_UPPERCUT", "R_UPPERCUT"], "index":0}
	_ep()["training"] = training; _ep()["phase"] = "shadow" if intro else "world"
	if game == "roadwork":
		state = "training"; _page(text("HARBOUR ROADWORK", "COURSE DU QUAI"), "")
		_button("step", text("Step · Enter / A", "Foulée · Entrée / A"), training_tap)
		training_bar = ProgressBar.new(); training_bar.custom_minimum_size.y = 24; training_bar.show_percentage = false
		column.add_child(training_bar); column.move_child(training_bar, 2)
		_label(column, text("Target: 50% · keep the stride centred", "Cible : 50 % · garde la foulée au centre"), 18)
		_button("cancel", text("Stop training", "Arrêter"), _world)
	else:
		# A completed scrap is OVER. A coaching round starts its own unscored
		# practice bout instead of leaving punch input dead in that verdict state.
		if restored.is_empty():
			if not scene.sim.bout.is_empty(): scene.sim.end_bout()
			scene.sim.start_spar(0, [], {}, "", "COACHING", {"fighter":"RORY", "authored":true})
		_fight(restored.is_empty()); state = "training"; _ep()["fight"] = ""; scene.set_practice(true)
		scene.boss.visible = game == "mitts"
		if restored.is_empty(): scene.sim.P["pos"] = Vector2(0, 0.8); scene.sim.B["pos"] = Vector2(0, -0.8)
		quest.text = ""; hint.text = ""
		if game == "shadow":
			scene.get_meta("arena").hide(); scene.fight_hud.hide()
			quest.position = Vector2(26, 30)
	save_episode()

func training_tap() -> void:
	if state != "training" or training.get("game") != "roadwork" or training["hit"]: return
	var phase := fmod(float(training["t"]), 1.0)
	training["score"] += maxf(0, 1 - absf(phase - 0.5) / 0.3); training["hit"] = true

func _finish_training() -> void:
	var game := str(training["game"]); var intro: bool = training["intro"]
	var grade := clampf(float(training["score"]) / 12.0, 0, 1)
	if game != "roadwork": grade = clampf(float(training["accepted"]) / 12.0, 0, 1)
	if game == "mitts": grade = clampf(float(training["score"]) / 12.0, 0, 1)
	_ep()["metrics"]["training"].append({"game":game, "grade":grade, "seconds":training["t"], "intro":intro})
	var paid := false
	var id := "shadow_rounds" if game == "shadow" else game
	_ep()["phase"] = "world"; _ep()["fight"] = ""
	if not intro and scene.sim.train_why(id, "RORY") == "": paid = bool(scene.sim.train(id, "RORY", grade).get("ok", false))
	scene.set_practice(false); scene.sim.end_bout(); _ep().erase("training"); training = {}
	if intro:
		Campaign.mark(scene.sim, "shadow"); _show_world(); _dialogue("letter")
	else:
		_world(); _info(text("Session complete", "Séance terminée") + " · %d%%\n" % int(grade * 100) + text("Training rewards booked." if paid else "Coaching practice recorded. No paid facility reward was available.", "Récompenses inscrites." if paid else "Leçon enregistrée. Aucune récompense de séance payée n’était disponible."))
	save_episode()

func observe(event: Dictionary) -> void:
	if not active or _ep().is_empty(): return
	pending.append(event.duplicate(true))

func _event(event: Dictionary) -> void:
	var kind := str(event.get("kind", "")); var fight := str(_ep().get("fight", ""))
	broadcast.observe(event, fight)
	staging.observe(event)
	if fight != "":
		var metrics: Dictionary = _ep()["metrics"]
		if kind == "hit" and event.get("on") == "B" and event.get("counter", false): metrics["counters"] = int(metrics.get("counters", 0)) + 1
		if kind == "interrupt": metrics["interrupts"] = int(metrics.get("interrupts", 0)) + 1
		if kind == "drop" and not metrics.has("first_drop_seconds"): metrics["first_drop_seconds"] = metrics["played_seconds"]
		if kind == "matchup" and fight == "survival" and scene.sim.seg_idx == 1:
			if not metrics.has("r2_cycles"): metrics["r2_cycles"] = []
			metrics["r2_cycles"].append([])
	if state == "training" and training.get("game") in ["shadow", "mitts"] and kind == "punch":
		var desired: String = training["sequence"][int(training["index"]) % 6]
		if str(event.get("row", "")) == desired:
			if training["game"] == "shadow":
				training["index"] = int(training["index"]) + 1; training["accepted"] = int(training["accepted"]) + 1
			elif not training["hit"] and absf(fmod(float(training["t"]), 1.3) - 0.75) <= 0.3:
				training["score"] += 1.0 - absf(fmod(float(training["t"]), 1.3) - 0.75) / 0.6
				training["accepted"] = int(training["accepted"]) + 1; training["hit"] = true
	if fight == "archive":
		var lesson := int(_ep().get("lesson", 0))
		if lesson == 1 and kind == "evade" and event.get("by") == "P" and event.get("dodge") == "SLIP": _ep()["slipped"] = true
		if lesson == 0 and kind == "hit" and event.get("on") == "B" and event.get("row", "") == "L_STRAIGHT": _ep()["lesson"] = 1
		elif lesson == 1 and kind == "hit" and event.get("on") == "B" and event.get("counter", false) and _ep().get("slipped", false): _ep()["lesson"] = 2
		elif lesson == 2 and kind == "perfect_block": _ep()["lesson"] = 3
		elif lesson >= 3 and kind == "cast_resolve" and event.get("who") == "P" and event.get("move") == "Aurora Borealis Breaker":
			_ep()["lesson"] = 4; _ep()["abb_tick"] = int(event["tick"])
		if kind == "drop" and event.get("who") == "B" and int(_ep().get("lesson", 0)) >= 4 and int(event["tick"]) == int(_ep().get("abb_tick", -1)):
			archive_drop = event.duplicate(true)
			state = "freeze"; freeze_t = staging.begin("freeze")
			quest.text = "MILLBROOK 5 — LAKEHEAD 4\n21 · 02 · 1976"
		elif kind == "dual_end" and state != "freeze":
			state = "inspect"; _page(text("THE TAPE · TRY THE SEQUENCE AGAIN", "LA BANDE · REPRENDS LA SÉQUENCE"), text("Jab → slip-counter → perfect block → Aurora Borealis Breaker.\nThe next scene follows the real sequence, including the knockdown.", "Jab → esquive-contre → blocage parfait → Aurora Borealis Breaker.\nLa scène suivante attend la vraie séquence, y compris la mise au tapis."))
			_button("retry", text("Rewind the tape", "Rembobiner"), func(): Campaign.archive(scene.sim); _fight())
		return
	if kind in ["bout_end", "dual_end"] and fight != "":
		var result := Campaign.result(scene.sim, event)
		if result.is_empty(): return
		_show_world(); world.sync(scene.sim)
		if fight == "priya_trial": _dialogue("priya_join")
		elif fight == "scrap_2" and result["won"]: _dialogue("marcus_join")
		elif fight == "scrap_3" and result["won"]: _dialogue("june_join")
		elif fight == "survival" and result["won"]: _dialogue("tag")
		else:
			var verdict := str(event.get("verdict", "")) if language == "en" else ("Objectif réussi" if result["won"] else "Objectif non réussi") + " · EP %d — %d" % [scene.sim.ep_p, scene.sim.ep_b]
			_world(); _info((text("Lesson complete.", "Leçon réussie.") if result["won"] else text("The result stands. Prepare and try again.", "Le résultat compte. Prépare-toi et réessaie.")) + "\n" + verdict)
			if fight == "survival": _button("retry_survival", text("Prepare the Survival Dual again", "Repréparer le duel de survie"), func(): _dialogue("survival"))
		save_episode()
	if fight == "survival" and kind == "matchup" and scene.sim.seg_idx == 2 and not _ep().get("vane_intro", false):
		_ep()["vane_intro"] = true; _dialogue("vane")
	if fight == "survival" and kind == "seg_card":
		if not _ep()["metrics"].has("segments"): _ep()["metrics"]["segments"] = []
		_ep()["metrics"]["segments"].append(event.duplicate(true))
	if fight == "survival" and kind == "tell" and scene.sim.seg_idx == 1:
		if not _ep()["metrics"].has("r2_tells"): _ep()["metrics"]["r2_tells"] = []
		_ep()["metrics"]["r2_tells"].append(str(event.get("string", "")))
		if not _ep()["metrics"].get("r2_cycles", []).is_empty(): _ep()["metrics"]["r2_cycles"][-1].append(str(event.get("string", "")))

func _corner() -> void:
	state = "corner"; _page(text("WHITLOCK · YOUR CORNER", "WHITLOCK · TON COIN"), text("Two actions. Keep the bar for the next fighter. Priya wants a plan; Rory wants the fire.", "Deux actions. Garde la réserve pour le prochain. Priya veut un plan; Rory veut du feu."))
	var options: Dictionary = scene.sim.corner_options()
	if scene.sim.seg_idx == 0 and not _ep()["metrics"].get("segments", []).is_empty() and not _ep()["metrics"]["segments"][-1].get("won", false):
		_label(column, "DANIELLE · Il perd le segment. Il ne perd pas la soirée — regardez la jauge.", 19)
	if scene.sim.seg_idx == 1: _label(column, text("PRIYA · Third exchange. It was right there. Eleven viewings and it was right there.", "PRIYA · Le troisième échange. Juste là. Onze visionnements, et c’était juste là."), 19)
	if not _ep()["metrics"].get("segments", []).is_empty():
		var card: Dictionary = _ep()["metrics"]["segments"][-1]
		_label(column, text("Banked this segment: %d · ", "Réserve de ce segment : %d · ") % int(card.get("banked", 0)) + (text("CHARGED relay ready · +10% entrance surge for 10 seconds", "Relais CHARGÉ prêt · poussée d’entrée de +10 % pendant 10 secondes") if card.get("charged", false) else text("25 banked prepares the CHARGED relay", "25 en réserve prépare le relais CHARGÉ")), 18)
	_label(column, "%d %s · %.0f Tension" % [options["actions_left"], text("actions remaining", "actions restantes"), scene.sim.tension], 22)
	if scene.sim.corner.get("locked", false): _label(column, text("The opposing crowd effect has locked this corner. Send your fighter; the ledger has not spent any actions.", "L’effet de la foule adverse verrouille ce coin. Envoie ton boxeur; aucune action n’a été dépensée."), 18)
	for choice in ["plan", "fire", "arm"]:
		var name: String = {"plan":text("Confirm the plan", "Confirmer le plan"), "fire":text("Light the fire", "Allumer le feu"), "arm":text("Arm around the shoulder", "Une main sur l’épaule")}[choice]
		_button("talk:" + choice, text("The Talk · ", "La causerie · ") + name, func(): scene.sim.corner_action({"kind":"talk", "option":choice}); _corner(); save_episode(), "" if int(options["actions_left"]) > 0 else text("No actions left", "Plus d’actions"))
	for tactic in options["tactic"]:
		if not tactic["id"] in ["body_doctrine", "open_season"]: continue
		var why := ""
		if int(options["actions_left"]) <= 0: why = text("No actions left", "Plus d’actions")
		elif tactic["cooldown"]: why = text("Used last corner", "Utilisé au coin précédent")
		elif scene.sim.tension < float(tactic["cost"]): why = text("Not enough Tension", "Tension insuffisante")
		var label: String = tactic["name"] + " · " + tactic["text"] if language == "en" else ("Doctrine au corps · double la perte d’endurance adverse" if tactic["id"] == "body_doctrine" else "Saison ouverte · contres +100 ms, garde −20 %")
		_button("tactic:" + tactic["id"], label + " · %d T" % tactic["cost"], func(): scene.sim.corner_action({"kind":"tactic", "id":tactic["id"]}); _corner(); save_episode(), why)
	_button("bank", text("Save the bar", "Conserver la réserve"), func(): scene.sim.corner_action({"kind":"save_bar"}); _corner(); save_episode(), "" if int(options["actions_left"]) > 0 else text("No actions left", "Plus d’actions"))
	_button("send", text("Send the next fighter", "Envoyer le prochain boxeur"), func(): scene.q_corner = 1; _fight(false))

func _closing_wall() -> void:
	if not Campaign.has(scene.sim, "survival"): return
	transition_t = 0
	state = "outro"; _ep()["closing_wall"] = true; _ep()["phase"] = "tag"
	_ep()["dialogue"] = ""; panel.hide(); quest.hide(); hint.text = ""; broadcast.clear()
	freeze_t = staging.begin("wall_close"); save_episode()

func _end_card() -> void:
	state = "complete"; _show_world(); world.sync(scene.sim)
	_ep().erase("closing_wall"); _ep()["phase"] = "complete"
	staging.begin("end_card")
	_page(text("EPISODE 1 — THE LETTER", "ÉPISODE 1 — LA LETTRE"), text("CHARTER STANDS\nA letter. A carbon copy. Four cards. A lot of empty board.\n\nNext season leads: ranked spars at the Annex, Regionals registration, scrap objectives 4–9.", "CHARTE MAINTENUE\nUne lettre. Un double carbone. Quatre fiches. Beaucoup de place sur le mur.\n\nPistes de saison : combats classés à l’Annexe, inscription aux régionales, objectifs de défi 4–9."))
	_button("return", text("Return to Millbrook", "Retourner à Millbrook"), _world)
	_button("title", text("Title screen", "Écran titre"), _title)
	save_episode()

func advance(delta: float) -> bool:
	if not active: return false
	if handoff_t >= 0:
		handoff_t += delta
		if handoff_t >= 0.65 or state != "training": handoff_t = -1; handoff_parts.clear()
	# Presentation has its own clock; pausing or opening controls never consumes
	# a shot, a name-sized audio hole or the live simulation underneath it.
	if not scene.controls_menu.opened: staging.frame(delta)
	if state == "title": return true
	if transition_t > 0:
		transition_t = maxf(0, transition_t - delta)
		var weight := smoothstep(0.0, 1.0, 1.0 - transition_t / 0.65)
		transition_camera.global_transform = transition_from.interpolate_with(transition_to, weight)
		if transition_t == 0:
			if transition_target == "fight": scene.cam.make_current()
			else: world.camera.make_current()
		return true
	seconds += delta
	_ep()["metrics"]["played_seconds"] = float(_ep()["metrics"]["played_seconds"]) + delta
	var events := pending.duplicate(); pending.clear()
	for event in events: _event(event)
	if freeze_t > 0:
		freeze_t = maxf(0, freeze_t - delta)
		if freeze_t == 0:
			if state == "dialogue" and buttons.has("next"):
				buttons["next"].disabled = false
				panel.show(); hint.text = text("Enter / A · continue", "Entrée / A · continuer")
				if _ep()["dialogue"] == "present" or (_ep()["dialogue"] == "archive" and int(_ep()["line"]) == 1) or (_ep()["dialogue"] == "tag" and int(_ep()["line"]) == 2):
					vignette.color.a = 0; next_line()
			elif state == "freeze":
				vignette.color.a = 0; scene.sim = Campaign.present(scene.content, scene.sim); _show_world(); _dialogue("present")
			elif state == "outro": _end_card()
	if state == "world":
		var move := Vector2(float(keys.get(KEY_D, false)) - float(keys.get(KEY_A, false)), float(keys.get(KEY_S, false)) - float(keys.get(KEY_W, false)))
		var devices := Input.get_connected_joypads()
		if not devices.is_empty():
			var stick := Vector2(Input.get_joy_axis(devices[0], JOY_AXIS_LEFT_X), Input.get_joy_axis(devices[0], JOY_AXIS_LEFT_Y))
			if stick.length() > 0.18: move = stick
		world.walk(move, bool(keys.get(KEY_SHIFT, false)), delta)
		_ep()["position"] = world.point(); _ep()["visits"] = world.visited.duplicate()
		_ep()["metrics"]["world_seconds"] = float(_ep()["metrics"]["world_seconds"]) + delta
		_world_caption()
		autosave_t += delta
		if autosave_t >= 15: autosave_t = 0; save_episode()
		return true
	if state == "training":
		training["t"] = float(training["t"]) + delta
		if training["game"] == "roadwork":
			var beat := int(float(training["t"]))
			if beat > int(training["beats"]): training["beats"] = beat; training["hit"] = false
			body.text = text("Keep a steady stride. Tap when the bar reaches the middle.", "Garde une foulée régulière. Appuie quand la jauge atteint le centre.") + "\n%d / 12" % mini(12, beat + 1)
			training_bar.value = fmod(float(training["t"]), 1.0) * 100
			world.walk(Vector2(sin(float(training["t"]) * 0.2), 0.3), true, delta)
			if beat >= 12: _finish_training()
			return true
		if training["game"] == "mitts":
			var beat := int(float(training["t"]) / 1.3)
			if beat != int(training["index"]): training["index"] = beat; training["hit"] = false
		quest.text = text("COACHING · ", "LEÇON · ") + (text("SHADOW ROUNDS", "BOXE DANS LE VIDE") if training["game"] == "shadow" else text("MITTS", "PATTES D’OURS")) + "\n%d / 12   %s" % [training["accepted"], Locale.punch(training["sequence"][int(training["index"]) % 6], language == "fr_CA")]
		quest.text += "\n" + (text("HIT NOW", "MAINTENANT") if training["game"] == "mitts" and absf(fmod(float(training["t"]), 1.3) - 0.75) <= 0.3 else text("Set your feet. Flow into the next hand.", "Pose tes appuis. Enchaîne avec l’autre main."))
		hint.text = text("J · left straight   K · right straight   U/I · hooks   Y/O · uppercuts", "J · direct gauche   K · direct droit   U/I · crochets   Y/O · uppercuts")
		if (training["game"] == "shadow" and int(training["accepted"]) >= 12 and float(training["t"]) >= 30) or (training["game"] == "mitts" and float(training["t"]) >= 15.6): _finish_training(); return true
		return false
	if state == "fight":
		if scene.sim.mode == "FIGHT":
			var metrics: Dictionary = _ep()["metrics"]
			metrics["combat_seconds"] = float(metrics.get("combat_seconds", 0)) + delta
			if scene.sim.P["stamina"] < 15: metrics["gassed_seconds"] = float(metrics.get("gassed_seconds", 0)) + delta
		if scene.sim.mode == "CORNER" and last_mode != "CORNER": last_mode = "CORNER"; _corner(); return true
		last_mode = scene.sim.mode
		_fight_caption()
		return false
	return true

func _fight_caption() -> void:
	var fight := str(_ep().get("fight", ""))
	if fight == "archive":
			var goals := [text("Land a left jab · J / left flick", "Place un jab gauche · J / geste gauche"), text("Slip, then counter · Q/E then J/K", "Esquive puis contre · Q/E, puis J/K"), text("Perfect block · Space just before impact", "Blocage parfait · Espace juste avant l’impact"), text("Fill Tension · H + Alt-held punch / LB + HAYMAKER", "Remplis la tension · H + coup avec Alt / LB + HAYMAKER"), text("Finish the exchange · land ABB for the DROP", "Termine l’échange · ABB pour la mise au tapis")]
			quest.text = "21 · 02 · 1976   R5\n" + goals[mini(4, int(_ep().get("lesson", 0)))]
	elif fight == "survival":
			quest.text = text("CHARTER · ", "CHARTE · ") + "%d / 2\n" % scene.sim.seg_wins_p + [text("MARCUS · bank 25 Tension", "MARCUS · accumule 25 de tension"), text("PRIYA · third exchange leads right", "PRIYA · troisième échange : droite"), text("RORY · interrupt Vane’s Sequence 1", "RORY · interromps la séquence 1 de Vane")][mini(2, scene.sim.seg_idx)]
	else: quest.text = text("THE LETTER · ", "LA LETTRE · ") + fight.to_upper()
	hint.text = ""
	quest.position.x = get_viewport().get_visible_rect().size.x * 0.14 if fight == "archive" else 26.0
	quest.size.x = minf(520, get_viewport().get_visible_rect().size.x * 0.65)

func refresh_hud() -> void:
	if not active: return
	Locale.hud(scene, language == "fr_CA", _ep().get("fight", "") == "archive", status)

func save_episode() -> bool:
	if _ep().is_empty(): return false
	_ep()["language"] = language
	# Simulation events are consumed by the director on the next render update.
	# A save between the final bell and that update must carry the earned result.
	_ep()["pending_events"] = pending.duplicate(true)
	# The earned DROP owns the archive transition. A snapshot during the held
	# glove replays that actual event, instead of trapping Continue in a spent bout.
	if state == "freeze" and not archive_drop.is_empty(): _ep()["pending_events"].append(archive_drop.duplicate(true))
	if not training.is_empty(): _ep()["training"] = training.duplicate(true)
	var payload := Save.write_text(scene.sim)
	var check: Dictionary = Save.read_text(payload)
	if not bool(check.get("ok", false)): status = text("Save validation failed", "Échec de validation"); return false
	var temporary := SAVE_PATH + ".tmp"; var backup := SAVE_PATH + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: status = text("Could not write the episode save", "Impossible d’écrire la sauvegarde"); return false
	file.store_string(payload); file.close()
	if FileAccess.get_file_as_string(temporary) != payload: return false
	if FileAccess.file_exists(SAVE_PATH):
		var previous := Save.read_file(SAVE_PATH)
		# Recovery must never replace the known-good backup with corrupt primary data.
		if not previous.get("ok", false) or Campaign.validate(previous.get("rewards", {}).get("episode", {})) != "": backup = SAVE_PATH + ".rejected"
		if DirAccess.copy_absolute(SAVE_PATH, backup) != OK: status = text("Could not preserve the previous save", "Impossible de conserver la sauvegarde précédente"); return false
	if DirAccess.rename_absolute(temporary, SAVE_PATH) != OK: status = text("Could not replace the episode save", "Impossible de remplacer la sauvegarde"); return false
	status = text("Episode saved", "Épisode sauvegardé"); return true

func load_episode() -> void:
	_load_episode_path(SAVE_PATH)

func _load_episode_path(path: String) -> void:
	var rd := Save.read_file(path)
	if not rd.get("ok", false): status = text("The episode save could not be read. Recover the previous save below.", "La sauvegarde est illisible. Récupère la version précédente ci-dessous."); _title(); return
	var ep = rd.get("rewards", {}).get("episode", {})
	var why := Campaign.validate(ep)
	if why != "": status = why; _title(); return
	var built := Save.build(scene.content, rd, 1976)
	if not rd.get("dual", {}).is_empty() and not built["restored"].get("ok", false): status = str(built["restored"]); _title(); return
	scene.sim = built["sim"]; scene.club_flow.enabled = false; scene.club_flow.close()
	# The typed in-flight snapshot is authoritative. Reusing the JSON summary
	# here reorders event dictionaries/converts numbers; the autosave in _fight
	# would then replace the exact pending-event state and change its hash.
	ep = Campaign.state(scene.sim)
	scene.fight_feedback.sync_audio(true)
	broadcast.reset(true)
	scene.controls_menu.practice.disabled = true
	language = ep["language"]; _language(); world.restore(ep["position"]); world.visited = ep.get("visits", []).duplicate(); world.sync(scene.sim)
	training = {}; pending.assign(ep.get("pending_events", [])); freeze_t = 0
	handoff_t = -1; handoff_parts.clear()
	if ep.get("closing_wall", false): _show_world(); _closing_wall()
	elif ep.get("dialogue", "") != "": _show_world(); _dialogue(ep["dialogue"], true)
	elif ep.get("training", {}).size() > 0:
		var saved: Dictionary = ep["training"].duplicate(true); _training(saved["game"], saved["intro"], saved)
	elif ep["phase"] == "board": _board()
	elif ep["phase"] == "complete": _end_card()
	elif ep["phase"] == "tag": _show_world(); _dialogue("tag")
	elif ep["phase"] == "fight":
		_fight(false)
		if scene.sim.mode == "CORNER": _corner()
	else: _world()

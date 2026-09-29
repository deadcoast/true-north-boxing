extends Node
## Authored broadcast is presentation only. No simulation writes or speech service.
var director: Node
var voice: AudioStreamPlayer
var caption: Label
var catalog := {}
var streams := {}
var owner_sim
var seen := {}
var current := ""
var dialogue_key := ""
var starts := 0
var held := false

func setup(owner_director: Node) -> void:
	director = owner_director
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://audio/broadcast/manifest.json"))["cues"]
	voice = AudioStreamPlayer.new(); add_child(voice); voice.volume_db = -5
	voice.finished.connect(_finished)
	for key in catalog:
		for language in ["en", "fr_CA"]:
			streams[key + ":" + language] = AudioStreamWAV.load_from_file(catalog[key]["clips"][language]["file"])
	caption = Label.new(); director.surface.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	caption.offset_left = 26; caption.offset_right = -26; caption.offset_top = 112
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", Color("eee8d7"))
	caption.add_theme_color_override("font_outline_color", Color("112632"))
	caption.add_theme_constant_override("outline_size", 8)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; caption.hide()
	reset()

func clear() -> void:
	voice.stop(); voice.stream_paused = false; caption.hide()
	if director.state == "fight": director.quest.position.y = 170
	current = ""; dialogue_key = ""; held = false

func reset(restored := false) -> void:
	clear(); owner_sim = director.scene.sim; seen.clear()
	# Loading a resolved card/corner never re-announces its result. Pending
	# unconsumed events still enter through the director's authoritative queue.
	if restored and owner_sim.mode in ["CARD", "CORNER"]: seen["marcus_loss"] = true

func dialogue(id: String, index: int) -> void:
	if owner_sim != director.scene.sim: reset()
	# The earned final knockdown can finish over the immediate victory shot.
	if id == "tag" and index == 0 and current == "vane_down": return
	clear()
	var key := {"archive:0":"archive_open", "archive:2":"archive_believes", "survival:0":"survival_stakes", "survival:1":"survival_charter"}.get("%s:%d" % [id, index], "") as String
	if key == "": return
	dialogue_key = "%s:%d" % [id, index]
	_start(key, false)

func finish_dialogue() -> void:
	if dialogue_key != "": clear()

func observe(event: Dictionary, fight: String) -> void:
	if owner_sim != director.scene.sim: reset()
	if fight != "survival": return
	var key := ""
	if event.get("kind") == "seg_card" and int(event.get("seg", 0)) == 1 and event.has("won") and not event["won"]:
		key = "marcus_loss"
	elif event.get("kind") == "drop" and event.get("who") == "B" and owner_sim.seg_idx == 2 and owner_sim.boss_name == "cassidy_vane":
		key = "vane_down"
	if key == "" or seen.has(key): return
	seen[key] = true; clear(); _start(key, true)

func _start(key: String, live_caption: bool) -> void:
	current = key
	var clip: Dictionary = catalog[key]["clips"][director.language]
	voice.stream = streams[key + ":" + director.language]; voice.play(); starts += 1
	caption.text = str(catalog[key]["speaker"]) + "\n" + str(clip["text"])
	caption.visible = live_caption

func sync(paused: bool) -> void:
	if owner_sim != director.scene.sim: reset()
	if not director.active or director.state in ["title", "world", "complete", "training", "board"]:
		clear(); return
	if current == "": return
	var sim = director.scene.sim
	var critical: bool = director.state == "fight" and (sim.mode in ["EIGHT", "CLINCH", "CLASH"] or sim.bstate in ["TELL", "FAKE", "HOLD"] or director.scene.fight_feedback.corner_calls.voice.playing or director.scene.fight_feedback.interrupt_active(sim) or int(sim.P["counter_t"]) > 0)
	# Pause the utterance rather than burying words under actionable combat
	# cues. The matching caption yields too; neither reveals a jammed tell.
	held = paused or critical or director.staging.sound_hole
	voice.stream_paused = held
	caption.visible = dialogue_key == "" and not held and director.state != "corner"
	if director.state == "fight": director.quest.position.y = 220 if caption.visible else 170
	# A completed R1 call must never drift into Priya's next entrance.
	if current == "marcus_loss" and sim.seg_idx != 0: clear()

func _finished() -> void:
	var advance_archive: bool = dialogue_key.begins_with("archive:") and director.state == "dialogue" and dialogue_key == "%s:%d" % [director._ep().get("dialogue", ""), int(director._ep().get("line", -1))]
	clear()
	if advance_archive: director.next_line()

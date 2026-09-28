extends Control
## Shared combat feedback. Reads authoritative timers; never predicts a result.
## Procedural PCM is a functional sound layer, independent of simulation RNG.
const RATE := 22050
var scene: Node
var voices: Array[AudioStreamPlayer] = []
var sounds := {}
var voice_index := 0
var timing := {}
var played := {}
var tell_until := 0
var impact_tick := -1000
var impact_on := "B"
var impact_heavy := false

func setup(owner_scene: Node) -> void:
	scene = owner_scene; mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 8:
		var voice := AudioStreamPlayer.new(); add_child(voice); voices.append(voice)
	for kind in ["jab", "heavy", "block", "counter", "tell", "beat", "bell", "air"]:
		sounds[kind] = _sound(kind)

func _sound(kind: String) -> AudioStreamWAV:
	var tone: bool = kind in ["tell", "beat", "bell", "counter"]
	var duration := 0.30 if tone else 0.16
	var frequency: float = {"jab": 130.0, "heavy": 65.0, "block": 240.0, "counter": 420.0, "tell": 740.0, "beat": 600.0, "bell": 880.0, "air": 500.0}[kind]
	var data := PackedByteArray(); data.resize(int(RATE * duration) * 2)
	var noise := RandomNumberGenerator.new(); noise.seed = 704
	var filtered := 0.0
	for i in data.size() / 2:
		var t := float(i) / RATE
		var envelope := minf(1, t / 0.004) * exp(-t * (16 if tone else 35))
		filtered = lerpf(filtered, noise.randf_range(-1, 1), 0.6 if kind == "jab" else 0.2)
		var wave := sin(TAU * frequency * t) + sin(TAU * frequency * 2.71 * t) * 0.24 if tone else filtered + sin(TAU * frequency * t) * 0.45
		data.encode_s16(i * 2, int(clampf(wave * envelope * 0.48, -1, 1) * 32767))
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE; stream.data = data
	return stream

func play(kind: String, priority := false) -> void:
	if not sounds.has(kind): return
	played[kind] = int(played.get(kind, 0)) + 1
	if priority:
		tell_until = Time.get_ticks_msec() + 250
		for voice in voices: voice.volume_db = -22
	var voice := voices[voice_index]; voice_index = (voice_index + 1) % voices.size()
	voice.stream = sounds[kind]
	voice.volume_db = -8 if priority else (-22 if Time.get_ticks_msec() < tell_until else -12)
	voice.play()

func observe(event: Dictionary, tick: int) -> void:
	match str(event.get("kind", "")):
		"tell": play("tell", true)
		"hit":
			impact_tick = tick; impact_on = str(event["on"])
			impact_heavy = bool(event.get("counter", false)) or bool(event.get("flash", false))
			play("counter" if impact_heavy else ("jab" if str(event.get("row", "")).ends_with("STRAIGHT") else "heavy"))
		"block", "perfect_block": play("block")
		"punch": play("air")
		"clinch_cue", "eight_beat": play("beat", true)
		"matchup", "bout_end", "drop": play("bell", true)

static func timing_state(sim) -> Dictionary:
	if sim.mode == "EIGHT" and not sim.eight.is_empty():
		var remaining := float(sim.eight["timer_t"])
		return {"phase": clampf(remaining / 144.0, -0.3, 1), "open": absf(remaining) <= float(sim.eight["window_t"]), "locked": bool(sim.eight["rise_prev"]), "label": "RISE", "count": "%d beats to stand" % int(sim.eight["beats_left"])}
	if not sim.clinch.is_empty():
		var c: Dictionary = sim.clinch; var i := int(c["i"])
		if i < c["cues"].size():
			var start: float = 0 if i == 0 else float(c["cues"][i - 1])
			var remaining := float(c["cues"][i]) - float(c["t"])
			return {"phase": clampf(remaining / maxf(1, float(c["cues"][i]) - start), -0.3, 1), "open": absf(remaining) <= float(c["windows"][i]), "locked": bool(c["hit"]) or bool(c["early"]), "label": "LEFT" if c["sides"][i] == "L" else "RIGHT", "count": "%d / %d clean beats" % [int(c["beats"]), int(c["need"])]}
	return {}

func update_state(sim) -> void:
	timing = timing_state(sim)
	visible = not scene.fight_hud.entry.visible and not (scene.club_flow != null and scene.club_flow.visible)
	queue_redraw()

func _draw() -> void:
	if scene == null: return
	if not timing.is_empty():
		var at := Vector2(size.x * 0.5, size.y * 0.63)
		var ready: bool = timing["open"] and not timing["locked"]
		var color := Color("ffd486") if ready else Color("a8bad2")
		draw_circle(at, 71, Color(0.035, 0.055, 0.08, 0.93))
		draw_arc(at, 44, 0, TAU, 72, Color("89c9fa"), 5, true)
		draw_arc(at, 44 + float(timing["phase"]) * 24, 0, TAU, 72, color, 3, true)
		var font := ThemeDB.fallback_font
		var label := "RELEASE" if timing["locked"] else ("TAP" if ready else str(timing["label"]))
		draw_string(font, at + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
		var caption := str(timing["count"])
		draw_string(font, at + Vector2(-font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 91), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var elapsed: int = scene.sim.tick - impact_tick
	if elapsed >= 0 and elapsed < 18 and timing.is_empty():
		var fighter: Node3D = scene.boss if impact_on == "B" else scene.player
		var at: Vector2 = scene.cam.unproject_position(fighter.position + Vector3.UP * 1.25)
		var color := Color(1, 0.81, 0.5, 1.0 - float(elapsed) / 18)
		for i in 6:
			var direction := Vector2.from_angle(TAU * i / 6)
			draw_line(at + direction * 14, at + direction * (28 if impact_heavy else 21), color, 2, true)

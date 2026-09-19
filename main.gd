extends Node2D
# Northpaw latency harness (PAC-002B). Two modes, TAB to switch:
#   LATENCY: flick the right stick freely; software-path latency distribution.
#   DISCRIM: follow the prompted sector; 10-sector accuracy over 200 prompts.
# White square flashes on punch-start for external 240fps camera measurement.
# Quit (ESC) writes user://latency_log.csv.

const FLICK_ON := 0.6          # magnitude threshold, matches game detection
const FLICK_OFF := 0.25        # re-arm threshold
const SECTORS := [             # NP_03 s2.1 matrix, 5 per hand
	"L_UPPERCUT","L_HOOKERCUT","L_HOOK","L_FLARED","L_STRAIGHT",
	"R_STRAIGHT","R_FLARED","R_HOOK","R_HOOKERCUT","R_UPPERCUT"]

var mode := "LATENCY"
var armed := true
var t_detect_us := 0
var samples: Array[float] = []          # ms, poll-detect -> end of apply+draw request
var log_rows: Array[String] = []
var prompt_idx := -1
var discrim_hits := 0
var discrim_total := 0
var flash_frames := 0
var hud: Label
var flash: ColorRect
var prompt_lbl: Label

func _ready() -> void:
	var font_size := 20
	hud = Label.new()
	hud.position = Vector2(24, 24)
	hud.add_theme_font_size_override("font_size", font_size)
	add_child(hud)
	prompt_lbl = Label.new()
	prompt_lbl.position = Vector2(24, 320)
	prompt_lbl.add_theme_font_size_override("font_size", 48)
	add_child(prompt_lbl)
	flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(160, 160)
	flash.position = Vector2(1080, 40)
	flash.visible = false
	add_child(flash)
	_next_prompt()

func _sector(v: Vector2) -> int:
	# angle in screen space: v.x right+, v.y down+. Up = -y.
	var ang := rad_to_deg(atan2(-v.y, v.x))   # 0 = right, 90 = up
	# Right hand: ang in (-90, 90]; five 36-degree sectors from down(-90) to up(90).
	# Left hand mirrored.
	if ang > 90.0 or ang <= -90.0:
		var la := 180.0 - ang if ang > 0.0 else -180.0 - ang   # mirror to right-half range
		return clampi(int(floor((la + 90.0) / 36.0)), 0, 4)    # 0=L_UPPERCUT(down) .. 4=L_STRAIGHT(up)
	return 5 + (4 - clampi(int(floor((ang + 90.0) / 36.0)), 0, 4))  # down->R_UPPERCUT(9), up->R_STRAIGHT(5)

const FAST_CROSS_MS := 150   # slow excursions past threshold are not flicks (codex repro fix)
const CAPTURE_FRAMES := 2    # classify at peak vector, not first-crossing (staggered-axes fix)

var t_below_off_us := 0
var capture_left := 0
var capture_best := Vector2.ZERO

func _poll_stick() -> Vector2:
	# poll EVERY connected pad, take the strongest right-stick vector
	# (codex repro: harness read device 0 only; Razer pads sat at devices 1-2)
	var best := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var v := Vector2(
			Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
		if v.length() > best.length():
			best = v
	return best

func _process(_dt: float) -> void:
	var v := _poll_stick()
	var mag := v.length()

	if mag <= FLICK_OFF:
		t_below_off_us = Time.get_ticks_usec()

	if capture_left > 0:
		capture_left -= 1
		if mag > capture_best.length():
			capture_best = v
		if capture_left == 0:
			_on_punch(_sector(capture_best))
	elif armed and mag >= FLICK_ON:
		# fast-crossing gate: threshold must be reached within FAST_CROSS_MS of leaving rest
		if (Time.get_ticks_usec() - t_below_off_us) / 1000.0 <= FAST_CROSS_MS:
			armed = false
			t_detect_us = Time.get_ticks_usec()
			capture_left = CAPTURE_FRAMES
			capture_best = v
		else:
			armed = false   # slow excursion: consume without a punch, re-arm at rest
	elif not armed and mag <= FLICK_OFF:
		armed = true

	if flash_frames > 0:
		flash_frames -= 1
		flash.visible = flash_frames > 0

	_draw_hud()

func _on_punch(sec: int) -> void:
	# "punch-state apply": the work the game does at punch start, then measure
	# to the end of this frame's draw request via a deferred timestamp.
	flash.visible = true
	flash_frames = 3
	var name: String = SECTORS[sec]
	if mode == "DISCRIM" and prompt_idx >= 0:
		discrim_total += 1
		if sec == prompt_idx:
			discrim_hits += 1
		log_rows.append("DISCRIM,%s,%s,%d" % [SECTORS[prompt_idx], name, int(sec == prompt_idx)])
		_next_prompt()
	# measure after this frame's drawing is requested
	RenderingServer.frame_post_draw.connect(_after_draw.bind(name), CONNECT_ONE_SHOT)

func _after_draw(name: String) -> void:
	var ms := float(Time.get_ticks_usec() - t_detect_us) / 1000.0
	samples.append(ms)
	if samples.size() > 500:
		samples.pop_front()
	log_rows.append("LATENCY,%s,%.2f" % [name, ms])

func _next_prompt() -> void:
	prompt_idx = randi() % SECTORS.size()

func _pct(p: float) -> float:
	if samples.is_empty():
		return 0.0
	var s := samples.duplicate()
	s.sort()
	return s[clampi(int(floor(p * float(s.size()))), 0, s.size() - 1)]

func _draw_hud() -> void:
	var pads := Input.get_connected_joypads()
	var pad_ok := pads.size() > 0
	var lines := [
		"NORTHPAW LATENCY HARNESS :: PAC-002B      mode: %s   [TAB switch, ESC quit+save]" % mode,
		"pads: %s" % (str(pads) if pad_ok else "NONE - connect a controller"),
		"",
		"software-path latency  (poll-detect -> apply -> present request)",
		"  samples %4d   p50 %6.2f ms   p95 %6.2f ms   p99 %6.2f ms" %
			[samples.size(), _pct(0.50), _pct(0.95), _pct(0.99)],
		"  PASS bar: p95 <= 50 ms   ->  %s" %
			("PASS" if samples.size() >= 30 and _pct(0.95) <= 50.0 else ("need >=30 samples" if samples.size() < 30 else "FAIL")),
		"",
		"discrimination  %d/%d  (%.1f%%)   PASS bar: >=99%% over 200" %
			[discrim_hits, discrim_total, 100.0 * discrim_hits / maxf(1.0, float(discrim_total))],
		"",
		"white square = punch-start flash (film pad+screen at 240fps for full-chain)",
	]
	hud.text = "\n".join(lines)
	prompt_lbl.text = ("FLICK: " + SECTORS[prompt_idx]) if mode == "DISCRIM" else ""

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_TAB:
			mode = "DISCRIM" if mode == "LATENCY" else "LATENCY"
			discrim_hits = 0
			discrim_total = 0
		elif e.keycode == KEY_ESCAPE:
			_save_and_quit()

func _save_and_quit() -> void:
	var f := FileAccess.open("user://latency_log.csv", FileAccess.WRITE)
	if f:
		f.store_line("kind,a,b,c")
		for r in log_rows:
			f.store_line(r)
		f.store_line("SUMMARY,p50,%.2f," % _pct(0.50))
		f.store_line("SUMMARY,p95,%.2f," % _pct(0.95))
		f.store_line("SUMMARY,p99,%.2f," % _pct(0.99))
	get_tree().quit()

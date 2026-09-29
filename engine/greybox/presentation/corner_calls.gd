extends RefCounted
## Offline audio-channel tells. Motifs, not local S1/S2 indexes, name the code.
const CODES := {"corner_call_S1": 1, "corner_call_S4": 4, "corner_call_S7": 7}
var voice: AudioStreamPlayer
var streams := {}
var owner_sim
var last_tick := -1
var last_key := ""
var active_string := ""
var starts := 0

func setup(parent: Node) -> void:
	voice = AudioStreamPlayer.new(); parent.add_child(voice)
	for language in ["en", "fr"]:
		for code in [1, 4, 7]:
			var key := "%s_%d" % [language, code]
			streams[key] = AudioStreamWAV.load_from_file("res://audio/corner_calls/" + key + ".wav")

static func code_for(sim, string: String) -> int:
	var motif: String = sim.pattern.get("strings", {}).get(string, {}).get("tell", {}).get("motif", "")
	return int(CODES.get(motif, 0))

static func caption(sim, french: bool) -> String:
	if code_for(sim, sim.bstring) == 0: return ""
	# A caption is the accessible equivalent of the audio channel, so a jam
	# cannot reveal a code through text while hiding that same code in speech.
	if sim.states["P"].has("tell_jam_audio"):
		return "APPEL BROUILLÉ" if french else "CORNER CALL MASKED"
	return ("COIN · « SÉQUENCE %d ! »" if french else "CORNER · “SEQUENCE %d!”") % code_for(sim, sim.bstring)

func stop() -> void:
	voice.stop(); voice.stream_paused = false; active_string = ""

func sync(sim, paused: bool) -> void:
	if owner_sim != sim or sim.tick < last_tick:
		stop(); owner_sim = sim; last_key = ""
	last_tick = sim.tick
	if sim.mode != "FIGHT" or sim.bstate not in ["TELL", "FAKE", "HOLD"] or sim.bstring != active_string or sim.states["P"].has("tell_jam_audio"):
		stop()
	voice.stream_paused = paused

func observe(sim, event: Dictionary) -> bool:
	sync(sim, false)
	var kind: String = event.get("kind", "")
	if kind in ["interrupt", "drop", "bout_end", "matchup"]:
		stop(); return false
	if kind not in ["tell", "fake"]: return false
	var code := code_for(sim, str(event.get("string", "")))
	if code == 0:
		stop(); return false
	if sim.states["P"].has("tell_jam_audio") or sim.mode != "FIGHT" or sim.bstate not in ["TELL", "FAKE", "HOLD"]:
		stop(); return true
	var key := "%d:%s:%s" % [sim.tick, kind, str(event.get("string", ""))]
	if key == last_key: return true
	stop()
	last_key = key; active_string = str(event["string"])
	var language := "fr" if TranslationServer.get_locale().begins_with("fr") else "en"
	voice.stream = streams["%s_%d" % [language, code]]
	# One volume tier = 6dB. Legacy in-flight saves lack this key; retain their
	# exact clocks and read their old tier field without mutating the snapshot.
	var tier: int = sim.bmods.get("corner_call_tier", sim.bmods.get("tier_shift", 0))
	voice.volume_db = -8.0 + clampi(tier, -2, 0) * 6.0
	voice.play(); starts += 1
	return true

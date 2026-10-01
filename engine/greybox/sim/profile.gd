# TNBProfile - the fighter who plays without you (NP_10 s8, manager mode).
# Pure: it reads the sim and returns one intent dictionary per tick - the same dictionary the
# pad produces - and rolls on the sim's own RNG, so a delegated segment hashes like any other.
# The card's style archetype sets the range and the mix (NP_06 s1.2), its stats set how well it
# reads (RFX), rises (HRT) and taps (RFX); it reads his tells, his casts and the scramble cue the
# way a fighter would. Pattern Intel (NP_02 s3) lifts its read of a dialect it knows: the sim's
# pi_read_bonus() (data) is added to the read roll - "your recon makes your AI teammates smarter" -
# and with his page in hand (PI 3) it never jabs a string the pattern does not tag breakable.
extends RefCounted

# preferred distance band by style: the swarmer's phone booth, the out-boxer's jab range, the slugger's mid
const RANGE := {"SWARMER": [0.95, 1.3], "OUTBOXER": [1.85, 2.15], "SLUGGER": [1.45, 1.75], "BOXERPUNCHER": [1.5, 1.9]}
# how often an idle fighter in range throws (per tick) and what he throws
const AGGRO := {"SWARMER": 0.06, "OUTBOXER": 0.03, "SLUGGER": 0.035, "BOXERPUNCHER": 0.04}
const MIX := {   # row weights: straights, hooks, uppercuts, overhand/haymaker
	"SWARMER":      {"L_STRAIGHT": 1, "R_STRAIGHT": 1, "L_HOOK": 3, "R_HOOK": 3, "R_UPPERCUT": 3, "R_HOOKERCUT": 1},
	"OUTBOXER":     {"L_STRAIGHT": 5, "R_STRAIGHT": 4, "L_HOOK": 1, "R_HOOK": 1, "R_UPPERCUT": 0, "R_HOOKERCUT": 0},
	"SLUGGER":      {"L_STRAIGHT": 1, "R_STRAIGHT": 2, "L_HOOK": 2, "R_HOOK": 3, "R_UPPERCUT": 1, "R_HOOKERCUT": 3},
	"BOXERPUNCHER": {"L_STRAIGHT": 3, "R_STRAIGHT": 3, "L_HOOK": 2, "R_HOOK": 2, "R_UPPERCUT": 1, "R_HOOKERCUT": 1}}
const BODY_PCT := {"SWARMER": 0.35, "OUTBOXER": 0.12, "SLUGGER": 0.25, "BOXERPUNCHER": 0.15}
const POWER_PCT := {"SWARMER": 0.08, "OUTBOXER": 0.05, "SLUGGER": 0.45, "BOXERPUNCHER": 0.2}
const FEINT_PCT := {"SWARMER": 0.06, "OUTBOXER": 0.25, "SLUGGER": 0.04, "BOXERPUNCHER": 0.15}
const INTERRUPT_PREF := {"SWARMER": 0.5, "OUTBOXER": 0.6, "SLUGGER": 0.35, "BOXERPUNCHER": 0.55}   # read a tell: jab it vs move
const BLOCK_PREF := {"SWARMER": 0.4, "OUTBOXER": 0.3, "SLUGGER": 0.6, "BOXERPUNCHER": 0.5}         # move vs block when not jabbing
const COUNTER_ROW := {"SWARMER": "R_UPPERCUT", "OUTBOXER": "R_STRAIGHT", "SLUGGER": "R_HOOK", "BOXERPUNCHER": "R_HOOK"}

static func fresh_memory() -> Dictionary:
	return {"drift": 1, "drift_t": 0, "tell_tick": -1, "plan": "", "plan_at": 0, "feint_release": -1, "resting": false,
		"last_grab": -100000, "last_sprint": -100000, "beat_done": -1, "combo": "", "combo_t": 0, "cue_done": -1}

static func intent(s, ext: Dictionary) -> Dictionary:
	# ext: the outside world's intent - the corner keys pass through untouched (the player keeps the corners)
	var inp := {}
	for k in ["corner", "corner_action", "restart", "audio_assist", "surge"]:   # PAC-082: the SURGE is the manager's call, never the card's
		if ext.has(k): inp[k] = ext[k]
	var m: Dictionary = s.auto
	var P: Dictionary = s.P; var B: Dictionary = s.B
	var style := str(P.get("style", "BOXERPUNCHER"))
	var rfx := float(P["stats"]["RFX"]) / 99.0
	var hrt := float(P["stats"]["HRT"]) / 99.0
	# ---- the count: rise on the beat, as often as the heart allows ----
	if s.mode == "EIGHT":
		var e: Dictionary = s.eight
		if e.get("who","P") != "P" or e.get("phase","count") == "rise": return inp
		var beat_id: int = int(e.get("beats_left", 0))
		if absi(int(e["timer_t"])) <= int(e["window_t"]) / 2 and int(m["beat_done"]) != beat_id:
			m["beat_done"] = beat_id
			if s.rng.randf() < 0.55 + 0.45 * hrt: inp["rise"] = true
		return inp
	if s.mode != "FIGHT": return inp
	var d: float = P["pos"].distance_to(B["pos"])
	var band: Array = RANGE.get(style, RANGE["BOXERPUNCHER"])
	var idle: bool = int(P["busy_t"]) <= 0 and P["cmd"].is_empty() and P["pending"].is_empty() and int(P["dodge_t"]) <= 0 and s.cast.is_empty()
	# ---- the scramble: tap the cue's side, as clean as the reflexes allow ----
	if s.clinch.size() > 0:
		var c: Dictionary = s.clinch
		var i: int = c["i"]
		if i < c["cues"].size():
			var cue: int = c["cues"][i]; var w: int = c["windows"][i]; var t: int = c["t"]
			if t >= cue - w / 3 and int(m["cue_done"]) != i:
				m["cue_done"] = i
				if s.rng.randf() < 0.45 + 0.55 * rfx: inp["move"] = Vector2(-1.0 if c["sides"][i] == "L" else 1.0, 0.0)
		if int(c["t"]) >= int(c["end"]) - 1 and style == "SWARMER" and float(P["stamina"]) < 60.0: inp["body"] = true   # take the reset when winded
		return inp
	# ---- a feint that was pressed last time: let go inside the 80ms ----
	if int(m["feint_release"]) >= 0:
		if s.tick >= int(m["feint_release"]): inp["punch_release"] = true; m["feint_release"] = -1
		return inp
	# ---- resting: gassed fighters back off, block and breathe ----
	if float(P["stamina"]) < 18.0: m["resting"] = true
	elif float(P["stamina"]) > 38.0: m["resting"] = false
	# ---- his tell: read it once, then jab it, slip it or block it ----
	var tell: bool = s.bstate == "TELL" or s.bstate == "FAKE"
	if tell and int(m["tell_tick"]) != s.tell_start_tick:
		m["tell_tick"] = s.tell_start_tick
		var loud: bool = false
		if s.bstring != "" and s.pattern["strings"].has(s.bstring): loud = str(s.pattern["strings"][s.bstring].get("class", "normal")) != "normal"
		var p_read := 0.3 + 0.5 * rfx + (0.15 if loud else 0.0) + float(s.pi_read_bonus())
		if s.rng.randf() < p_read:
			var roll: float = s.rng.randf()
			var knows_it_holds: bool = s.pi_vs() >= 3 and not s._interruptible(s.bstring)          # the page in hand (PI 3): it never jabs a string that does not break (NP_04 s4)
			if roll < float(INTERRUPT_PREF[style]) and d <= 2.0 and int(s.btimer) > 30 and idle and not knows_it_holds: m["plan"] = "jab"
			elif s.rng.randf() < float(BLOCK_PREF[style]): m["plan"] = "block"
			else: m["plan"] = "dodge"
			m["plan_at"] = s.tick
		else: m["plan"] = ""
	if not tell and str(m["plan"]) != "" and s.bstate != "ACTING": m["plan"] = ""
	# mid-string with no plan: the cheap answer is the guard (chip beats clean), by the style's taste for it
	if s.bstate == "ACTING" and str(m["plan"]) == "" and idle and d < 2.0 and int(s.btimer) <= 6:
		m["plan"] = "block" if s.rng.randf() < float(BLOCK_PREF[style]) + 0.2 else "none"
	# ---- his cast: break it in the window, or brace at the resolve ----
	if s.cast.size() > 0 and str(s.cast["who"]) == "B":
		var elapsed: int = int(s.cast["total"]) - int(s.cast["t"])
		if bool(s.cast["interruptible"]) and elapsed <= int(s.cast["window_t"]) and d <= 2.0 and idle and s.rng.randf() < 0.25 + 0.5 * rfx:
			inp["punch"] = "L_STRAIGHT"; inp["move"] = Vector2(0, -0.6); return inp
		if int(s.cast["t"]) <= 14: inp["block"] = true
		var mvw: Dictionary = s.wall_move()                                      # PAC-084: an inherited WALL native first
		if not mvw.is_empty() and str(mvw["family"]) == "WALL" and s.can_pay(mvw) and int(s.cast["t"]) > 50 and int(s.cast["t"]) < 110:
			inp["lb"] = true; inp["block"] = true; return inp        # raise the wall to take it
		return inp
	# ---- the plan against the string ----
	if str(m["plan"]) == "jab" and idle and tell:
		inp["punch"] = "L_STRAIGHT"; inp["move"] = Vector2(0, -0.5) if d > 1.9 else Vector2.ZERO; m["plan"] = "jabbed"; return inp
	if str(m["plan"]) == "block" and (tell and int(s.btimer) <= 18 or s.bstate == "ACTING"):
		inp["block"] = true
		if s.bstate == "ACTING" and int(P["block_t"]) > 45: m["plan"] = ""
		return inp
	if str(m["plan"]) == "none" and s.bstate != "ACTING": m["plan"] = ""
	if str(m["plan"]) == "dodge" and tell and int(s.btimer) <= 22 and int(P["dodge_t"]) <= 0:
		inp["dodge"] = dodge_for(s, style); m["plan"] = "dodged"; return inp
	# ---- windows: hit him while he is open ----
	if (int(P["counter_t"]) > 0 or int(P["flash_t"]) > 0) and idle and d <= 2.05:
		inp["punch"] = COUNTER_ROW[style]
		if style == "SLUGGER" and s.rng.randf() < 0.6: inp["power"] = true
		inp["move"] = Vector2(0, -0.4) if d > 1.6 else Vector2.ZERO
		return inp
	# ---- the hissatsu, when the bar and the moment allow ----
	var mv: Dictionary = s.kit_pick()                                                     # PAC-091: his own move, else his kit's first he can cast
	var t3v: Dictionary = s.t3_pick()                                                     # PAC-080/081: a live Duo T3 first, else the relay's strongest, while the bar can pay it
	if not t3v.is_empty(): mv = t3v
	else:
		var ihv: Dictionary = s.inherit_pick()                                            # PAC-084: an inherited native, the strongest the meter can pay
		if not ihv.is_empty(): mv = ihv
	if idle and not mv.is_empty() and str(mv["family"]) != "WALL" and s.castable(mv) and s.can_pay(mv):
		var opening: bool = int(B["guard_open_t"]) > 0 or s._wobbled(B) or int(P["flash_t"]) > 0 or s.tension >= 90.0 or s._meter_pays(mv)   # PAC-083/084: a private meter leaves with its transformation - spend it
		if opening and d <= 1.9 and s.rng.randf() < 0.35:
			inp["punch"] = s.FAMILY_ROW[str(mv["family"])]; inp["lb"] = true; return inp
	# ---- movement: hold the band, cut angles, back off when winded ----
	var lo: float = band[0]; var hi: float = band[1]
	if m["resting"]: lo += 0.6; hi += 0.6
	var mvv := Vector2.ZERO
	m["drift_t"] = int(m["drift_t"]) + 1
	if int(m["drift_t"]) > 70 + s.rng.randi_range(0, 40): m["drift_t"] = 0; m["drift"] = -int(m["drift"])
	if d > hi: mvv.y = -1.0
	elif d < lo: mvv.y = 1.0
	else: mvv.x = float(m["drift"]) * (0.7 if style == "OUTBOXER" else 0.45)
	if s.zone(P["pos"]) == "ROPES" or s.zone(P["pos"]) == "CORNER":               # off the ropes: angle out, not straight back
		mvv.x = float(m["drift"]) * 0.9; mvv.y = -0.3
	if m["resting"]: inp["block"] = d < 1.6
	inp["move"] = mvv
	# sprint-steps: the out-boxer breaks off a rush, the swarmer closes a gap
	if s.tick - int(m["last_sprint"]) > 360 and int(s.sprint_cd) <= 0:
		if style == "OUTBOXER" and s.bstate == "ACTING" and d < 1.5: inp["sprint"] = true; inp["move"] = Vector2(0, 1.0); m["last_sprint"] = s.tick
		elif style == "SWARMER" and d > 2.3 and not m["resting"]: inp["sprint"] = true; inp["move"] = Vector2(0, -1.0); m["last_sprint"] = s.tick
	# the swarmer's grab: a wobbled or gassed boss at 0-range, never so often the referee sees holding
	if style == "SWARMER" and d < 0.7 and idle and (s._wobbled(B) or float(B["stamina"]) < 40.0) and s.tick - int(m["last_grab"]) > 1200:
		inp["clinch"] = true; m["last_grab"] = s.tick; return inp
	# ---- offence: in range, idle, not resting ----
	if m["resting"] or not idle or d > hi + 0.15: return inp
	var guarded: bool = B["blocking"] or int(B["guard_t"]) > 0
	var aggro: float = float(AGGRO[style]) * (0.6 if guarded else 1.0)
	if str(m["combo"]) != "" and s.tick - int(m["combo_t"]) < 80: aggro = 1.0       # the second half of a one-two
	if s.rng.randf() >= aggro: return inp
	var flagged: bool = s.flags.size() > 0
	var row := ""
	if str(m["combo"]) != "": row = str(m["combo"]); m["combo"] = ""
	else: row = pick_row(s, style)
	if flagged and s.rng.randf() < 0.5: row = "L_STRAIGHT" if s.rng.randf() < 0.5 else "R_HOOK"   # the tracker flagged the rhythm: change it
	# a feint draws his read instead of throwing into it
	var feint_p: float = float(FEINT_PCT[style]) * (2.0 if guarded else 1.0)
	if s.rng.randf() < feint_p:
		inp["punch"] = row; m["feint_release"] = s.tick + 4; return inp
	inp["punch"] = row
	if s.rng.randf() < float(BODY_PCT[style]) * (1.6 if guarded else 1.0): inp["body"] = true
	elif s.rng.randf() < float(POWER_PCT[style]): inp["power"] = true
	if row == "L_STRAIGHT" and s.rng.randf() < 0.5: m["combo"] = "R_STRAIGHT"; m["combo_t"] = s.tick
	return inp

static func pick_row(s, style: String) -> String:
	var mix: Dictionary = MIX.get(style, MIX["BOXERPUNCHER"])
	var total := 0
	for k in mix: total += int(mix[k])
	var roll: int = s.rng.randi_range(0, maxi(1, total) - 1)
	for k in mix:
		roll -= int(mix[k])
		if roll < 0: return str(k)
	return "L_STRAIGHT"

static func dodge_for(s, style: String) -> String:
	# the geometric answer to the string's first punch (C2): slips beat straights and the overhand,
	# ducks beat straights and hooks, weaves beat hooks, lean-back beats the uppercut and body work at range
	var row := "R_STRAIGHT"; var body := false
	if s.bstring != "" and s.pattern["strings"].has(s.bstring):
		var acts: Array = s.pattern["strings"][s.bstring].get("actions", [])
		for a in acts:
			var parsed: Array = s.parse_action(str(a))
			if parsed.size() > 0 and str(parsed[0].get("kind", "")) == "punch":
				row = str(parsed[0]["row"]); body = bool(parsed[0].get("body", false)); break
	var fam: String = s._punch_family(row)
	var away := "_L" if row.begins_with("R_") else "_R"        # away from the hand
	if body: return "LEAN"
	match fam:
		"STRAIGHT": return ("SLIP" + away) if (style == "OUTBOXER" or s.rng.randf() < 0.5) else "DUCK"
		"HOOK": return "WEAVE" + away if style == "SWARMER" else "DUCK"
		"UPPERCUT": return "LEAN" if s.rng.randf() < 0.6 else ("SLIP" + away)
		"HOOKERCUT", "FLARED": return "SLIP" + away
	return "SLIP" + away

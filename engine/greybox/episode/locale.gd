extends RefCounted
const CornerCalls := preload("res://presentation/corner_calls.gd")
## Episode-local Canadian French. Static native controls translate through Godot;
## values and dynamic fight states are formatted from their authoritative fields.
const FR := {
	"Composure":"Sang-froid", "Stamina":"Endurance", "Guard":"Garde",
	"Controls / pause  Esc":"Commandes / pause  Échap",
	"TWO HANDS  /  CONTROLS":"DEUX MAINS  /  COMMANDES",
	"Mouse: hold left button and flick.  Alt + punch: charged haymaker.\nChords: Back selects left hand; A / B / X / Y / D-pad Up select the punch.\nHold D-pad Down to wind up. All presets use the same combat rules.":"Souris : maintiens le bouton gauche et fais un geste. Alt + coup : grand coup armé.\nCombinaisons : Back choisit la main gauche; A / B / X / Y / croix Haut choisissent le coup.\nMaintiens croix Bas pour armer. Les règles de combat restent les mêmes.",
	"Stick flicks + keyboard / mouse":"Gestes au stick + clavier / souris",
	"Accessible button chords + keyboard / mouse":"Combinaisons de boutons + clavier / souris",
	"Practice against a stationary dummy":"S’entraîner contre un mannequin immobile",
	"Select a binding, then press its replacement. Escape cancels.":"Choisis une commande, puis sa nouvelle touche. Échap annule.",
	"Restore defaults":"Rétablir les commandes", "Return to ring":"Reprendre", "Controls saved.":"Commandes sauvegardées.", "Binding cancelled.":"Modification annulée.",
	"Left Straight":"Direct gauche", "Right Straight":"Direct droit", "Left Flared":"Débordement gauche", "Right Flared":"Débordement droit",
	"Left Hook":"Crochet gauche", "Right Hook":"Crochet droit", "Left Hookercut":"Crochet remontant gauche", "Right Hookercut":"Crochet remontant droit",
	"Left Uppercut":"Uppercut gauche", "Right Uppercut":"Uppercut droit",
	"Block":"Bloquer", "Body":"Corps", "Power":"Puissance", "Hissatsu arm":"Armer le hissatsu", "Windup":"Armer", "Rise":"Se relever",
	"Taunt":"Provoquer", "Sprint":"Pas rapide", "Clinch":"Accrochage", "Slip left":"Esquive gauche", "Slip right":"Esquive droite", "Weave":"Rouler", "Lean":"Retrait", "Duck":"Baisser la tête",
	"RELEASE":"RELÂCHE", "TAP":"APPUIE", "RISE":"DEBOUT", "LEFT":"GAUCHE", "RIGHT":"DROITE",
	"%d beats to stand":"%d temps pour se relever", "%d / %d clean beats":"%d / %d temps réussis"
}
static var installed := false

static func use(language: String) -> void:
	if not installed:
		var translation := Translation.new(); translation.locale = "fr_CA"
		for original in FR: translation.add_message(original, FR[original])
		TranslationServer.add_translation(translation); installed = true
	TranslationServer.set_locale(language)

static func punch(row: String, french: bool) -> String:
	var names := {"L_STRAIGHT":["Left jab · J", "Jab gauche · J"], "R_STRAIGHT":["Right straight · K", "Direct droit · K"], "L_HOOK":["Left hook · U", "Crochet gauche · U"], "R_HOOK":["Right hook · I", "Crochet droit · I"], "L_UPPERCUT":["Left uppercut · Y", "Uppercut gauche · Y"], "R_UPPERCUT":["Right uppercut · O", "Uppercut droit · O"]}
	return str(names.get(row, [row, row])[1 if french else 0])

static func hud(scene, french: bool, archive: bool, status: String) -> void:
	var hud = scene.fight_hud; var sim = scene.sim
	hud.club_button.hide(); hud.detail_button.hide(); hud.details.hide()
	hud.score.add_theme_color_override("font_outline_color", Color("102330"))
	hud.score.add_theme_constant_override("outline_size", 6)
	var width: float = scene.get_viewport().get_visible_rect().size.x
	hud.surface.offset_left = width * 0.125 if archive else 0
	hud.surface.offset_right = -width * 0.125 if archive else 0
	if archive: hud.score.text = "%d : %d\nR5  %02d:%02d" % [sim.score_p, sim.score_b, int(ceil(sim.clock_t / 120.0)) / 60, int(ceil(sim.clock_t / 120.0)) % 60]
	if not french: return
	hud.hint.text = "Tension %d / 100   ·   Observer · défendre · contrer" % sim.tension
	hud.message.text = status if status != "" else "EP  %d — %d   ·   Renseignements %d" % [sim.ep_p, sim.ep_b, sim.pi_level(sim.bdialect)]
	hud.cue.text = "Trouve ta distance"
	if scene.practice_dummy: hud.cue.text = "Travaille l’enchaînement · tiens pour frapper, tapote pour feinter"
	elif sim.bstate in ["TELL", "FAKE", "HOLD"]:
		var motif: String = sim.pattern.get("strings", {}).get(sim.bstring, {}).get("tell", {}).get("motif", "")
		var motifs := {"chin_dip":"MENTON BAISSÉ", "glove_tap":"GANTS TAPÉS", "shoulder_roll":"ÉPAULE QUI ROULE", "weight_load":"CHARGE SUR L’APPUI", "heel_turn":"TALON QUI TOURNE"}
		hud.cue.text = motifs.get(motif, "LIS LE SIGNAL · " + str(sim.bstring))
		var call := CornerCalls.caption(sim, true)
		if call != "": hud.cue.text = call
	elif scene.fight_feedback.interrupt_active(sim): hud.cue.text = "INTERROMPU · ENCHAÎNE"
	elif sim.P["counter_t"] > 0: hud.cue.text = "FENÊTRE DE CONTRE"
	elif sim.P["stamina"] < 15: hud.cue.text = "ÉPUISÉ · PRENDS DE L’ESPACE"
	if sim.mode == "EIGHT": hud.cue.text = "COMPTE DE HUIT · Entrée / A sur le temps · %d à réussir" % int(sim.eight.get("beats_left", 0))
	elif sim.mode == "CLASH": hud.cue.text = "ÉCHANGE · bloque ou esquive, puis frappe à ton tour"
	elif sim.mode == "CORNER": hud.cue.text = "TON COIN · deux actions, puis le prochain boxeur"
	elif sim.mode == "OVER": hud.cue.text = "COMBAT TERMINÉ"

static func node_reason(sim, name: String, id: String, french: bool) -> String:
	var why: String = sim.node_why(name, id)
	if not french or why == "": return why
	if id in sim.taken(name): return "Déjà acquis"
	if sim.node_cost(name, id) > sim.gpoints_free(name): return "%d points requis · %d disponibles" % [sim.node_cost(name, id), sim.gpoints_free(name)]
	return "Acquiers d’abord une case voisine : " + ", ".join(PackedStringArray(sim.growth_nodes(name)[id]["links"]))

static func raise_reason(sim, name: String, stat: String, french: bool) -> String:
	var why: String = sim.raise_why(name, stat)
	if not french or why == "": return why
	var value: int = sim.grown_stats(sim._stable_card(name)).get(stat, 0)
	if value >= sim.rarity_cap(name): return "Plafond atteint : %d" % sim.rarity_cap(name)
	return "%d haricots requis · %d disponibles" % [sim.raise_cost(name, stat), int(sim.beans_typed().get(stat, 0)) + sim.beans_untyped()]

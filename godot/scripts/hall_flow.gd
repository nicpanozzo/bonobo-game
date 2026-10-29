# Sala d'attesa 3D lato main.gd: le scelte che non hanno bisogno della scena (chi chiede la sala,
# in che fase entra il welcome, i testi dei punti e del ritorno in sala), così si provano nei test.
# Il server decide tutto: qui si legge solo quello che manda.
extends RefCounted


# Un valore dell'indirizzo o della scelta della lobby: "1", "true", true valgono sì; "0", "false", "" no
static func truthy(v: Variant) -> bool:
	if v is bool:
		return v
	var s := str(v).strip_edges().to_lower()
	return s != "" and s != "0" and s != "false" and s != "no"


# La sala la chiede solo chi entra da una partita vera: palestra, tutorial e sfide hanno le loro stanze.
# hall in params vale per una sola entrata (main.gd lo rimette a ogni _join), gym invece resta: non si guarda
static func wants_hall(params: Dictionary) -> bool:
	if truthy(params.get("tutorial", false)):
		return false
	if params.get("challenge") is Dictionary and not (params.challenge as Dictionary).is_empty():
		return false
	return truthy(params.get("hall", false))


# "hall" se la stanza è nella sala d'attesa; i server di prima non mandano phase: si gioca e basta
static func phase_of(welcome: Dictionary) -> String:
	return "hall" if str(welcome.get("phase", "match")) == "hall" else "match"


# L'evento stage come un welcome: id e stanza dall'ultimo welcome, arena e regole nuove
static func stage_welcome(welcome: Dictionary, stage: Dictionary) -> Dictionary:
	var out := welcome.duplicate()
	for k in ["stageId", "rules", "stage"]:
		if stage.has(k):
			out[k] = stage[k]
	if not out.has("rules") or not (out.rules is Dictionary):
		out.rules = {"mode": "ffa", "stocks": 3}
	if not out.has("id"):
		out.id = ""
	if not out.has("room"):
		out.room = ""
	return out


static func my_rating(changes: Array, my_id: String) -> Dictionary:
	for c in changes:
		if c is Dictionary and str(c.get("id", "")) == my_id and my_id != "":
			return c
	return {}


static func delta_text(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	if delta < 0:
		return "%d" % delta # il meno c'è già
	return "±0"


# L'avviso per me a fine partita: "Gorilla · 1163 punti (+18)"
static func rating_toast(c: Dictionary) -> String:
	var text := "%s · %d punti (%s)" % [str(c.get("tier", "")), int(c.get("rating", 0)), delta_text(int(c.get("delta", 0)))]
	if c.get("rank") != null and int(c.get("rank", 0)) > 0:
		text += " · %d° in classifica" % int(c.rank)
	return text


# Sotto i pulsanti di fine partita, nelle stanze con la sala: quanto manca al ritorno automatico
static func return_note(ms_left: int) -> String:
	var s := ceili(maxi(ms_left, 0) / 1000.0)
	if s <= 0:
		return "Si torna in sala..."
	return "Se nessuno chiede la rivincita, si torna in sala da soli tra %d s" % s

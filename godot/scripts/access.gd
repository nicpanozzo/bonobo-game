# Accessibilità (E14, opzioni → Accessibilità): palette per daltonici, meno scossa e lampi, testo più grande.
# Valori statici perché li leggono disegni e menu ovunque (world_view, hud, UI); main.gd li aggiorna
# con apply() quando cambiano le preferenze. Il server non ne sa niente: manda sempre i colori di COLORS.
class_name Access
extends RefCounted

const TEXT_SCALES := [1.0, 1.25, 1.5]
const TEXT_NAMES := ["100%", "125%", "150%"]

static var text_scale := 1.0
static var calm := false # meno scossa e lampi: la telecamera non trema e lo schermo non lampeggia
static var _remap := {} # colore mandato dal server -> colore per daltonici; vuoto con la palette normale


static func apply(game: Dictionary, access: Dictionary) -> void:
	text_scale = TEXT_SCALES[clampi(int(access.text_size), 0, TEXT_SCALES.size() - 1)]
	calm = access.calm
	_remap = palette_map(game) if access.colorblind else {}


# COLORS[i] -> COLORS_COLORBLIND[i], e lo stesso per i colori delle squadre (palette.test.ts controlla
# che un colore presente in due tabelle finisca uguale in entrambe)
static func palette_map(game: Dictionary) -> Dictionary:
	var map := {}
	var pairs := [[game.colors, game.colorsColorblind]]
	for t in ["1", "2"]:
		pairs.append([game.teamColors[t], game.teamColorsColorblind[t]])
	for pair in pairs:
		for i in pair[0].size():
			map[int(pair[0][i])] = int(pair[1][i])
	return map


# Il colore di un giocatore (p.color dello snapshot) come lo vede chi gioca
static func color(n: Variant) -> Color:
	var c := int(n)
	return Color.hex((int(_remap.get(c, c)) << 8) | 0xff)


# Il colore principale di una squadra (bandierine, punteggio)
static func team_color(game: Dictionary, team: int) -> Color:
	return color(game.teamColors[str(team)][0])


# Una dimensione del testo con la scala scelta
static func px(size: float) -> int:
	return roundi(size * text_scale)

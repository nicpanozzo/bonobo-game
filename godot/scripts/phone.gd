# Modalità telefono: sul cellulare lo schermo da 1280x720 del gioco diventerebbe grande la metà,
# con scritte e pulsanti illeggibili. Qui il gioco si disegna come su uno schermo alto PHONE_HEIGHT,
# così menu, HUD e lottatori crescono tutti insieme, e si allarga fino ai bordi del telefono
# (niente bande nere ai lati dei telefoni lunghi). La partita si inquadra uguale: ci pensa main.gd.
class_name Phone
extends RefCounted

const DESIGN := Vector2i(1280, 720) # lo schermo per cui sono disegnati i menu (project.godot)
const PHONE_HEIGHT := 480 # altezza dello schermo del gioco sul telefono: tutto 1,5 volte più grande
# Opzioni → Touch → Schermo, indice salvato in Settings.touch.screen
const AUTO := 0
const PHONE := 1
const COMPUTER := 2
const SCREEN_NAMES := ["Automatico", "Telefono", "Computer"]

static var active := false # il gioco è in modalità telefono


# Un telefono o un tablet: il browser lo dice (web_android, web_ios), le app native pure
static func is_mobile_device() -> bool:
	for f in ["web_android", "web_ios", "android", "ios"]:
		if OS.has_feature(f):
			return true
	return false


static func wanted(choice: int) -> bool:
	if choice == PHONE:
		return true
	if choice == COMPUTER:
		return false
	return is_mobile_device()


# Mette o toglie la modalità telefono alla finestra del gioco
static func apply(window: Window, choice: int) -> void:
	active = wanted(choice)
	if active:
		window.content_scale_size = Vector2i(roundi(PHONE_HEIGHT * float(DESIGN.x) / DESIGN.y), PHONE_HEIGHT)
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		window.content_scale_size = DESIGN
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# Quanti pixel dello schermo del gioco per un pixel dello schermo da 720 della partita
# (1 sul computer, 480/720 sul telefono), e quanto mondo si vede alla telecamera 1
static func view_scale(visible: Vector2, world_height: float) -> float:
	return visible.y / world_height if visible.y > 0.0 else 1.0

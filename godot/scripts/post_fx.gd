# Post-processing dell'arena: un filtro su tutta la scena disegnata da world_view, sotto l'HUD e i menu, che fa
# sembrare dello stesso mondo sprite fatti in modi diversi. Ogni arena ha i suoi colori (GRADES), un bagliore
# leggero sulle parti chiare (suprema, scintille, neon), la vignetta ai bordi e un filo di grana.
# Nelle arene col giorno che passa (#288) di notte i colori vanno verso il blu e le luci brillano di più.
# Solo grafica: si spegne dalle opzioni (Video → Luce e colori dell'arena), e con "meno scossa e lampi" niente grana.
extends Node

# gain: moltiplica i colori; lift: il colore verso cui schiariscono le ombre; sat e contrast: 1 = come sono;
# bloom: quanto brillano le parti chiare; vignette: quanto si scuriscono i bordi
const BASE := {"gain": Color(1.0, 1.0, 1.0), "lift": Color(0.0, 0.0, 0.0), "sat": 1.05, "contrast": 1.04, "bloom": 0.25, "vignette": 0.3}
const GRADES := {
	"palco": {"gain": Color(1.04, 1.0, 0.96), "lift": Color(0.02, 0.0, 0.035), "sat": 1.08, "contrast": 1.06, "bloom": 0.5, "vignette": 0.38},
	"isole": {"gain": Color(1.03, 1.01, 0.95), "lift": Color(0.0, 0.012, 0.025), "sat": 1.1, "contrast": 1.04, "bloom": 0.22, "vignette": 0.24},
	"fabbrica": {"gain": Color(0.96, 1.0, 1.04), "lift": Color(0.0, 0.02, 0.035), "sat": 0.94, "contrast": 1.08, "bloom": 0.3, "vignette": 0.4},
	"palestra": {"gain": Color(1.02, 1.0, 0.97), "lift": Color(0.01, 0.01, 0.01), "sat": 1.05, "contrast": 1.04, "bloom": 0.2, "vignette": 0.26},
	"padova": {"gain": Color(1.03, 1.0, 0.95), "lift": Color(0.01, 0.005, 0.0), "sat": 1.06, "contrast": 1.04, "bloom": 0.22, "vignette": 0.28},
	"padova-palazzo": {"gain": Color(1.05, 0.99, 0.92), "lift": Color(0.02, 0.01, 0.0), "sat": 1.04, "contrast": 1.05, "bloom": 0.3, "vignette": 0.4},
	"musica": {"gain": Color(1.0, 0.96, 1.05), "lift": Color(0.03, 0.0, 0.045), "sat": 1.15, "contrast": 1.08, "bloom": 0.3, "vignette": 0.42},
	"bologna": {"gain": Color(1.06, 0.99, 0.92), "lift": Color(0.02, 0.01, 0.0), "sat": 1.05, "contrast": 1.05, "bloom": 0.3, "vignette": 0.34},
}
const NIGHT_GAIN := Color(0.9, 0.95, 1.08) # di notte i colori vanno verso il blu della luna
const NIGHT_BLOOM := 0.18 # e lampioni e finestre brillano di più
const GRAIN := 0.03 # ampiezza della grana, sui colori da 0 a 1

var world: Node2D # world_view.gd: l'arena e la luce del sole di questo frame
var enabled := true:
	set(on):
		enabled = on
		if _rect != null:
			_rect.visible = on

var _rect: ColorRect
var _copy: BackBufferCopy
var _mat: ShaderMaterial


func _ready() -> void:
	# Lo schermo si copia qui: gli shader dell'arena che lo leggono prima (bong, negativo) lo lascerebbero vecchio
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post.gdshader")
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = enabled
	add_child(_rect)


func _process(_delta: float) -> void:
	if not enabled or world == null:
		return
	var g := grade(str(world.stage.get("id", "")), world.sun_light())
	_mat.set_shader_parameter("gain", Vector3(g.gain.r, g.gain.g, g.gain.b))
	_mat.set_shader_parameter("lift", Vector3(g.lift.r, g.lift.g, g.lift.b))
	_mat.set_shader_parameter("saturation", g.sat)
	_mat.set_shader_parameter("contrast", g.contrast)
	_mat.set_shader_parameter("bloom", g.bloom)
	_mat.set_shader_parameter("vignette", g.vignette)
	_mat.set_shader_parameter("grain", 0.0 if Access.calm else GRAIN)
	# Sui telefoni e nel browser il bagliore legge lo schermo una volta sola invece di cinque
	_mat.set_shader_parameter("light_bloom", Phone.active or OS.has_feature("web"))
	var size := _rect.size
	_mat.set_shader_parameter("aspect", size.x / size.y if size.y > 0.0 else 16.0 / 9.0)
	_mat.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0)


# I colori di un'arena in questo momento: quelli suoi (o BASE), spostati verso la notte quando c'è la luna.
# sun: SunLight.light() del frame, vuoto nelle arene senza ciclo del giorno
static func grade(stage_id: String, sun: Dictionary) -> Dictionary:
	var g: Dictionary = GRADES.get(stage_id, BASE).duplicate()
	if sun.is_empty() or sun.get("sun", true):
		return g
	# Come le ombre (sun_light.gd): all'orizzonte sfuma, così alba e tramonto non scattano
	var night := clampf(float(sun.get("elev", 0.0)) * 3.0, 0.0, 1.0)
	var gain: Color = g.gain
	g.gain = gain.lerp(gain * NIGHT_GAIN, night)
	g.sat = lerpf(float(g.sat), float(g.sat) * 0.9, night)
	g.bloom = float(g.bloom) + NIGHT_BLOOM * night
	return g

# Il lottatore a pezzi in tempo reale (#403, #404): invece del fotogramma cotto in una striscia PNG si montano i
# pezzi del rig (tools/rig/) sulle ossa e si calcola la posa a ogni frame. Legge <rig>/godot.json scritto da
# export:godot. Solo disegno: i tempi dei colpi arrivano dallo snapshot e dai numeri del server.
# Le pose vengono dalle CHIAVI (poche pose per stato, con la curva d'arrivo) o, per gli stati che non ne hanno, dai
# fotogrammi cotti mescolati. I conti sono quelli di tools/rig/scheletro.py: gradi rispetto al riposo, positivo = orario.
extends RefCounted

const FighterPose := preload("res://scripts/fighter_pose.gd")
# Le curve d'arrivo a una chiave, uguali a ease() di tools/rig/animazioni_nonnagina.py
const EASES := ["lin", "in", "out", "io", "snap", "back", "hold"]

var scale := 0.5 # i pezzi sono disegnati a 2x, come le strisce
var parents := PackedInt32Array() # per ogni osso l'indice del genitore (-1 la radice); i genitori vengono prima
var heads := PackedVector2Array() # dove sta la testa di ogni osso a riposo, in pixel a 2x dai piedi
var names := {} # nome dell'osso -> indice
var layers := [] # { bone, texture, rect, pin }, già in ordine di disegno (inchiostro compreso)
var animations := {} # stato -> Array di PackedFloat32Array: [radice x, radice y, gradi di ogni osso]
var keys := {} # stato -> { phase, ms, loop, spec, t: PackedFloat32Array, e: PackedInt32Array, p: Array di pose }
var pin_grip := Vector2.ZERO # dove la mano stringe il mattarello, a riposo: lo smear lo allunga da lì
var pin_axis := Vector2.DOWN # la direzione del mattarello a riposo


# Il rig di <path>, o null se il file o un pezzo manca: chi lo usa torna alle strisce
static func open(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return null
	var rig: RefCounted = (load("res://scripts/rig_view.gd") as GDScript).new()
	rig.scale = float(data.get("scale", 0.5))
	for b in data.bones:
		rig.names[str(b.name)] = rig.parents.size()
		rig.parents.append(int(b.parent))
		rig.heads.append(Vector2(float(b.head[0]), float(b.head[1])))
	for l in data.pieces:
		var tex := _piece_texture("res://data/" + str(l.image))
		if tex == null:
			return null
		var size: Vector2 = tex.get_size()
		rig.layers.append({"bone": int(l.bone), "texture": tex, "rect": Rect2(Vector2(float(l.x), float(l.y)), size), "pin": str(l.get("name", "")) == "pin"})
	for state in data.animations:
		var frames := []
		for f in data.animations[state]:
			frames.append(PackedFloat32Array(f))
		rig.animations[state] = frames
	for state in data.get("keys", {}):
		var k: Dictionary = data.keys[state]
		var poses := []
		for p in k.p:
			poses.append(PackedFloat32Array(p))
		var eases := PackedInt32Array()
		for e in k.e:
			eases.append(maxi(0, EASES.find(str(e))))
		rig.keys[state] = {"phase": str(k.time) == "phase", "ms": float(k.ms), "loop": bool(k.loop), "spec": k.spec,
			"t": PackedFloat32Array(k.t), "e": eases, "p": poses}
	if rig.names.has("hand_R") and rig.names.has("fingers_R"):
		rig.pin_grip = rig.heads[rig.names.fingers_R]
		rig.pin_axis = (rig.pin_grip - rig.heads[rig.names.hand_R]).normalized()
	return rig


# Il pezzo con le mipmap: rimpicciolito dalla telecamera non sfarfalla (come _sprite_texture in world_view.gd)
static func _piece_texture(path: String) -> Texture2D:
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_compressed():
		return tex
	img.generate_mipmaps()
	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = ImageTexture.create_from_image(img)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return canvas


func has_state(state: String) -> bool:
	return keys.has(state) or animations.has(state)


# La curva d'arrivo: da 0 a 1 mentre u va da 0 a 1 (back supera 1 e torna)
static func curve(code: int, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	match code:
		1: return u * u * u # in: parte piano
		2: return 1.0 - pow(1.0 - u, 3.0) # out: arriva piano
		3: return u * u * (3.0 - 2.0 * u) # io
		4: return pow(u, 4.0) # snap: tiene la carica e scatta
		5: # back: supera la posa e ci torna
			var c := 1.70158
			return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)
		6: return 1.0 if u >= 1.0 else 0.0 # hold
	return u


# Il tempo di un attacco in fasi: 0-1 avvio (startupMs), 1-2 hitbox accesa (activeMs), 2-3 recupero fino a cooldownMs
static func phase(ms: float, spec: Dictionary) -> float:
	var s := float(spec.get("startupMs", 0))
	var a := float(spec.get("activeMs", 0))
	var total := maxf(float(spec.get("cooldownMs", 0)), s + a)
	if ms < s:
		return ms / s
	if ms < s + a:
		return 1.0 + (ms - s) / a
	return minf(3.0, 2.0 + (ms - s - a) / maxf(1.0, total - s - a))


# La posa dello stato dopo elapsed_ms. attack: i numeri dell'attacco in corso ({} se non c'è); a: la riga dello stato
# in game.json, per i fotogrammi cotti di chi non ha chiavi
func pose_at(state: String, elapsed_ms: float, attack: Dictionary, a: Dictionary) -> PackedFloat32Array:
	if not keys.has(state):
		return pose(state, FighterPose.rig_frame(a, elapsed_ms, attack), bool(a.get("loop", false)))
	var k: Dictionary = keys[state]
	var t := elapsed_ms
	if k.phase:
		t = phase(elapsed_ms, attack if attack.has("startupMs") else k.spec)
	elif k.loop:
		t = fposmod(elapsed_ms, k.ms)
	return sample(state, t)


# Le chiavi di uno stato al tempo t (fasi o ms): le due vicine mescolate con la curva di quella d'arrivo
func sample(state: String, t: float) -> PackedFloat32Array:
	var k: Dictionary = keys[state]
	var ts: PackedFloat32Array = k.t
	var n := ts.size()
	if t <= ts[0] and not k.loop:
		return k.p[0]
	for i in n - 1:
		if t < ts[i + 1]:
			var span := ts[i + 1] - ts[i]
			return blend(k.p[i], k.p[i + 1], curve(k.e[i + 1], (t - ts[i]) / span if span > 0.0 else 1.0))
	if k.loop: # dopo l'ultima chiave si torna alla prima
		return blend(k.p[n - 1], k.p[0], curve(k.e[0], (t - ts[n - 1]) / maxf(0.001, float(k.ms) - ts[n - 1] + ts[0])))
	return k.p[n - 1]


# Due pose mescolate (w può uscire da 0..1 con la curva back). Gli angoli vanno per la strada più corta
static func blend(a: PackedFloat32Array, b: PackedFloat32Array, w: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for k in out.size():
		var d := b[k] - a[k]
		out[k] = a[k] + (wrapf(d, -180.0, 180.0) if k >= 2 else d) * w
	return out


# La posa a un fotogramma frazionario dei fotogrammi cotti (#403): le due vicine mescolate. Nei cicli si torna alla prima
func pose(state: String, frame: float, loop: bool) -> PackedFloat32Array:
	var frames: Array = animations[state]
	var n := frames.size()
	var i := clampi(int(floor(frame)), 0, n - 1)
	var b: PackedFloat32Array = frames[(i + 1) % n if loop else mini(i + 1, n - 1)]
	return blend(frames[i], b, clampf(frame - float(i), 0.0, 1.0))


# Quanto è girato un osso nel mondo rispetto al riposo, in gradi: i suoi scarti più quelli dei genitori
func turn_of(p: PackedFloat32Array, bone: String) -> float:
	var i: int = names.get(bone, -1)
	var out := 0.0
	while i >= 0:
		out += p[2 + i]
		i = parents[i]
	return out


# Aggiunge gradi a un osso, se il rig ce l'ha
func add(p: PackedFloat32Array, bone: String, degrees: float) -> void:
	if names.has(bone):
		p[2 + int(names[bone])] += degrees


# Per ogni osso la trasformazione che porta un punto del disegno a riposo dove sta nella posa (matrici() di scheletro.py)
func bone_transforms(p: PackedFloat32Array) -> Array[Transform2D]:
	var out: Array[Transform2D] = []
	var world := PackedVector2Array()
	var turn := PackedFloat32Array() # rotazione accumulata rispetto al riposo
	for i in parents.size():
		var delta := deg_to_rad(p[2 + i])
		var head := heads[i] + Vector2(p[0], p[1])
		var rot := delta
		var q := parents[i]
		if q >= 0: # la testa segue il genitore, ruotata con lui
			head = world[q] + (heads[i] - heads[q]).rotated(turn[q])
			rot = turn[q] + delta
		world.append(head)
		turn.append(rot)
		out.append(Transform2D(rot, head - heads[i].rotated(rot)))
	return out


# Lo smear del mattarello (#404): lo allunga lungo il suo asse, dalla presa, di stretch (0.3 = 30% più lungo)
func pin_stretch(stretch: float) -> Transform2D:
	var u := pin_axis
	var x := Vector2(1.0 + stretch * u.x * u.x, stretch * u.x * u.y)
	var y := Vector2(stretch * u.x * u.y, 1.0 + stretch * u.y * u.y)
	return Transform2D(x, y, pin_grip - (x * pin_grip.x + y * pin_grip.y))


# Disegna la posa su canvas. base: dove stanno i piedi, già girato dalla parte in cui guarda (y in giù)
func draw(canvas: CanvasItem, base: Transform2D, p: PackedFloat32Array, modulate := Color.WHITE, stretch := 0.0) -> void:
	var bones := bone_transforms(p)
	var k := base * Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2.ZERO)
	var smear := pin_stretch(stretch) if stretch > 0.0 else Transform2D.IDENTITY
	for l in layers:
		canvas.draw_set_transform_matrix(k * bones[l.bone] * (smear if l.pin else Transform2D.IDENTITY))
		canvas.draw_texture_rect(l.texture, l.rect, false, modulate)
	canvas.draw_set_transform(Vector2.ZERO)

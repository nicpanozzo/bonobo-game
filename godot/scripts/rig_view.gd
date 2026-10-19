# Prova del lottatore a pezzi in tempo reale (#403): invece del fotogramma cotto in una striscia PNG si montano i
# pezzi del rig (tools/rig/) sulle ossa e si interpola la posa tra un fotogramma e l'altro, così il movimento è
# fluido a qualsiasi frame rate. Legge <rig>/godot.json scritto da export:godot. Solo disegno: i tempi dei colpi
# arrivano da FighterPose.rig_frame(), cioè dallo snapshot e dai numeri del server.
# I conti sono quelli di tools/rig/scheletro.py: gradi rispetto al riposo, positivo = orario, y in giù.
extends RefCounted

var scale := 0.5 # i pezzi sono disegnati a 2x, come le strisce
var parents := PackedInt32Array() # per ogni osso l'indice del genitore (-1 la radice); i genitori vengono prima
var heads := PackedVector2Array() # dove sta la testa di ogni osso a riposo, in pixel a 2x dai piedi
var layers := [] # { bone, texture, rect }, già in ordine di disegno (inchiostro compreso)
var animations := {} # stato -> Array di PackedFloat32Array: [radice x, radice y, gradi di ogni osso]


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
		rig.parents.append(int(b.parent))
		rig.heads.append(Vector2(float(b.head[0]), float(b.head[1])))
	for l in data.pieces:
		var tex := _piece_texture("res://data/" + str(l.image))
		if tex == null:
			return null
		var size: Vector2 = tex.get_size()
		rig.layers.append({"bone": int(l.bone), "texture": tex, "rect": Rect2(Vector2(float(l.x), float(l.y)), size)})
	for state in data.animations:
		var frames := []
		for f in data.animations[state]:
			frames.append(PackedFloat32Array(f))
		rig.animations[state] = frames
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
	return animations.has(state)


# La posa a un fotogramma frazionario: le due vicine mescolate. Nei cicli dopo l'ultima si torna alla prima.
# Gli angoli vanno per la strada più corta, così un osso non fa il giro lungo
func pose(state: String, frame: float, loop: bool) -> PackedFloat32Array:
	var frames: Array = animations[state]
	var n := frames.size()
	var i := clampi(int(floor(frame)), 0, n - 1)
	var t := clampf(frame - float(i), 0.0, 1.0)
	var a: PackedFloat32Array = frames[i]
	var b: PackedFloat32Array = frames[(i + 1) % n if loop else mini(i + 1, n - 1)]
	var out := a.duplicate()
	for k in out.size():
		var d := b[k] - a[k]
		out[k] = a[k] + (wrapf(d, -180.0, 180.0) if k >= 2 else d) * t
	return out


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


# Disegna il lottatore su canvas. base: dove stanno i piedi, già girato dalla parte in cui guarda (y in giù)
func draw(canvas: CanvasItem, base: Transform2D, state: String, frame: float, loop: bool, modulate := Color.WHITE) -> void:
	var bones := bone_transforms(pose(state, frame, loop))
	var k := base * Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2.ZERO)
	for l in layers:
		canvas.draw_set_transform_matrix(k * bones[l.bone])
		canvas.draw_texture_rect(l.texture, l.rect, false, modulate)
	canvas.draw_set_transform(Vector2.ZERO)

# Prova di #196: un lottatore animato in tempo reale con Skeleton2D invece che con lo spritesheet.
# Costruisce lo scheletro e i pezzi da rig.json (lo stesso file che usa Blender, #195) e le animazioni da
# animazioni.json (chiavi di rotazione delle ossa, come le scrive tools/blender/esporta_animazioni.py).
# È un prototipo fuori dal gioco: il gioco non lo usa finché il gruppo non decide.
class_name CostruisciScheletro
extends RefCounted

const INK_Z_BEHIND := -100.0 # i contorni "comuni" vanno dietro a tutto: una sola sagoma, niente giunture


# Restituisce un Node2D con dentro Skeleton2D (ossa e pezzi) e un AnimationPlayer con le animazioni.
# dir: la cartella con rig.json, animazioni.json e pezzi/
static func costruisci(dir: String) -> Node2D:
	var rig: Dictionary = _json(dir + "/rig.json")
	var anims: Dictionary = _json(dir + "/animazioni.json")
	var figure := Node2D.new()
	figure.name = String(rig.character)
	figure.scale = Vector2.ONE * float(rig.get("scale", 1.0)) # disegnato a 2x
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	figure.add_child(skeleton)

	# Ossa: a riposo, ognuna nel sistema del padre. Gli angoli vengono da testa -> coda
	var info := {} # nome -> { node, head, angle }
	for b in rig.bones:
		var head := Vector2(b.head[0], b.head[1])
		var tail := Vector2(b.tail[0], b.tail[1])
		var angle := (tail - head).angle()
		var bone := Bone2D.new()
		bone.name = String(b.name)
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(head.distance_to(tail))
		bone.set_bone_angle(0.0)
		var parent_node: Node = skeleton
		var parent_head := Vector2.ZERO
		var parent_angle := 0.0
		if b.parent != null and info.has(String(b.parent)):
			var p: Dictionary = info[String(b.parent)]
			parent_node = p.node
			parent_head = p.head
			parent_angle = p.angle
		bone.position = (head - parent_head).rotated(-parent_angle)
		bone.rotation = angle - parent_angle
		bone.rest = bone.transform
		parent_node.add_child(bone)
		info[String(b.name)] = {"node": bone, "head": head, "angle": angle}

	# Pezzi: ogni PNG appeso al suo osso, nella posizione del disegno a riposo. Il contorno in un secondo
	# sprite: subito dietro al pezzo (contorno proprio) o dietro a tutto (sagoma unica)
	for p in rig.pieces:
		var b: Dictionary = info[String(p.bone)]
		var at := Vector2(p.x, p.y)
		var local := Transform2D(-float(b.angle), (at - b.head).rotated(-float(b.angle)))
		for layer in ["ink", "image"]:
			if not p.has(layer):
				continue
			var spr := Sprite2D.new()
			spr.name = String(p.name) + ("_ink" if layer == "ink" else "")
			spr.texture = load(dir + "/" + String(p[layer]))
			spr.centered = false
			spr.transform = local
			spr.z_as_relative = false
			var z: float = float(p.inkZ) if layer == "ink" else float(p.z)
			spr.z_index = roundi(z * 2.0)
			b.node.add_child(spr)

	# Effetti: il fumo della canna parte dalla coda del suo osso
	for e in rig.get("effects", []):
		if String(e.type) == "smoke" and info.has(String(e.bone)):
			var bone: Bone2D = info[String(e.bone)].node
			var smoke: Node2D = preload("res://prototipi/scheletro/fumo.gd").new()
			smoke.name = "Fumo"
			smoke.tip = Vector2(bone.get_length(), 0) if String(e.get("at", "tail")) == "tail" else Vector2.ZERO
			bone.add_child(smoke)

	figure.add_child(_player(anims, info))
	return figure


# Le animazioni: una traccia di rotazione per osso (riposo + chiave) e la posizione della radice.
# Interpolazione cubica: tra una chiave e l'altra Godot calcola la posa a ogni frame dello schermo
static func _player(anims: Dictionary, info: Dictionary) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	for anim_name in anims.animations:
		var a: Dictionary = anims.animations[anim_name]
		var anim := Animation.new()
		anim.length = float(a.length)
		anim.loop_mode = Animation.LOOP_LINEAR if a.get("loop", false) else Animation.LOOP_NONE
		for bone_name in a.tracks:
			if not info.has(bone_name):
				continue
			var bone: Bone2D = info[bone_name].node
			var tr: Dictionary = a.tracks[bone_name]
			if tr.has("rot"):
				var i := anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(i, NodePath(_path(bone) + ":rotation"))
				anim.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC)
				for k in tr.rot:
					anim.track_insert_key(i, float(k[0]), bone.rest.get_rotation() + deg_to_rad(float(k[1])))
			if tr.has("pos"):
				var j := anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(j, NodePath(_path(bone) + ":position"))
				anim.track_set_interpolation_type(j, Animation.INTERPOLATION_CUBIC)
				for k in tr.pos:
					anim.track_insert_key(j, float(k[0]), bone.rest.get_origin() + Vector2(float(k[1]), float(k[2])))
		lib.add_animation(String(anim_name), anim)
	player.add_animation_library("", lib)
	return player


# Percorso dell'osso visto dalla figura (il nodo radice dell'AnimationPlayer è il suo genitore)
static func _path(bone: Node) -> String:
	var parts: Array[String] = []
	var n: Node = bone
	while n != null and not (n is Skeleton2D):
		parts.push_front(String(n.name))
		n = n.get_parent()
	return "Skeleton2D/" + "/".join(parts)


static func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Manca " + path)
		return {}
	return JSON.parse_string(f.get_as_text())

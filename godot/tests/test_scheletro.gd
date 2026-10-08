# Prova dello scheletro in Godot (#196): si costruisce da rig.json e animazioni.json senza errori
extends RefCounted

var runner

const DIR := "res://prototipi/scheletro/bonobot"


func test_ossa_pezzi_e_animazioni() -> void:
	var fig := CostruisciScheletro.costruisci(DIR)
	var skeleton: Skeleton2D = fig.get_node("Skeleton2D")
	var bones := 0
	var sprites := 0
	var stack: Array[Node] = [skeleton]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Bone2D:
			bones += 1
		elif n is Sprite2D:
			sprites += 1
			runner.check((n as Sprite2D).texture != null, "texture di " + n.name)
		stack.append_array(n.get_children())
	runner.check(bones == 43, "43 ossa (35 che deformano e 8 controlli), trovate %d" % bones)
	runner.check(sprites >= 30, "almeno un pezzo per osso, trovati %d" % sprites)
	var player: AnimationPlayer = fig.get_node("AnimationPlayer")
	for a in ["idle", "walk", "light", "heavy", "dash"]:
		runner.check(player.has_animation(a), "animazione " + a)
	fig.free()


func test_le_tracce_puntano_a_ossa_vere() -> void:
	var fig := CostruisciScheletro.costruisci(DIR)
	var player: AnimationPlayer = fig.get_node("AnimationPlayer")
	var anim := player.get_animation("dash")
	for i in anim.get_track_count():
		var path := anim.track_get_path(i)
		var node := fig.get_node_or_null(NodePath(path.get_concatenated_names()))
		runner.check(node is Bone2D, "traccia %s" % path)
	fig.free()

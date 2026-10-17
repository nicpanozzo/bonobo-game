# Icona dell'app (assets/icon): finestra, favicon web e app Mac la prendono da config/icon
extends RefCounted

var runner


func test_icona_del_progetto_si_carica() -> void:
	var path: String = ProjectSettings.get_setting("application/config/icon", "")
	runner.check(path == "res://assets/icon/icon.png", "config/icon: %s" % path)
	var tex := load(path) as Texture2D
	runner.check(tex != null and tex.get_width() >= 256, "icona caricata: %s" % tex)

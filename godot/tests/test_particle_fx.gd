# Effetti a particelle (particle_fx.gd, #470 passo 1)
extends RefCounted

var runner

const ParticleFx := preload("res://scripts/particle_fx.gd")
const ParticleView := preload("res://scripts/particle_view.gd")


# Senza attrito né gravità la particella va dritta; la scala del banco raddoppia lo spostamento
func test_moto_rettilineo_e_scala() -> void:
	var p := {"x": 100.0, "y": 50.0, "vx": 10.0, "vy": -4.0, "drag": 0.0}
	var at := ParticleFx.at(p, 2.0)
	runner.check(absf(at.x - (100.0 + 20.0 * ParticleFx.SCALE)) < 0.1, "x avanza di vx·t scalato (%.2f)" % at.x)
	runner.check(absf(at.y - (50.0 - 8.0 * ParticleFx.SCALE)) < 0.1, "y sale di vy·t scalato (%.2f)" % at.y)
	runner.check(ParticleFx.at(p, 0.0) == Vector2(100, 50), "all'inizio sta dove nasce")


# L'attrito ferma la particella: dopo tanto tempo si sposta di v0/d e basta
func test_attrito_ferma() -> void:
	var p := {"x": 0.0, "y": 0.0, "vx": 100.0, "vy": 0.0, "drag": 5.0}
	var far := ParticleFx.at(p, 10.0).x
	runner.check(absf(far - 100.0 / 5.0 * ParticleFx.SCALE) < 0.1, "si ferma a v0/d (%.2f)" % far)
	runner.check(ParticleFx.at(p, 0.2).x > ParticleFx.at(p, 0.1).x, "intanto continua ad avanzare")


# La gravità positiva fa ricadere, quella negativa (fumo) fa salire anche partendo fermi
func test_gravita() -> void:
	var grit := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": -100.0, "drag": 0.8, "gy": 420.0}
	runner.check(ParticleFx.at(grit, 0.1).y < 0.0, "il sassolino prima sale")
	runner.check(ParticleFx.at(grit, 1.0).y > 0.0, "poi ricade sotto il punto di partenza")
	var smoke := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "drag": 2.0, "gy": -45.0}
	runner.check(ParticleFx.at(smoke, 1.0).y < -1.0, "il fumo sale da solo")


# Il campione: cresce, sfuma, finisce; fuori dalla vita è vuoto
func test_campione_cresce_e_sparisce() -> void:
	var p := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "drag": 1.0, "s0": 3.0, "s1": 12.0, "life": 0.5, "ramp": ["dust"]}
	runner.check(ParticleFx.sample(p, -0.01).is_empty(), "prima di nascere non c'è")
	runner.check(ParticleFx.sample(p, 0.5).is_empty(), "a fine vita non c'è più")
	var early := ParticleFx.sample(p, 0.05)
	var late := ParticleFx.sample(p, 0.4)
	runner.check(float(late.size) > float(early.size), "si allarga (%.1f → %.1f)" % [early.size, late.size])
	runner.check(float(late.alpha) < 0.6, "verso la fine sfuma (%.2f)" % late.alpha)
	runner.check(early.tone0 == "dust" and float(early.f) == 0.0, "un tono solo, niente dissolvenza tra toni")


# La rampa dell'esplosione va dal bianco al fumo scuro
func test_rampa_del_fuoco() -> void:
	var p := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "s0": 5.0, "s1": 10.0, "life": 1.0, "ramp": ParticleFx.FIRE_RAMP}
	runner.check(ParticleFx.sample(p, 0.01).tone0 == "core", "nasce bianca")
	runner.check(ParticleFx.sample(p, 0.5).tone0 == "orange", "a metà arancio")
	runner.check(ParticleFx.sample(p, 0.99).tone0 == "red" and float(ParticleFx.sample(p, 0.99).f) > 0.9, "finisce nel fumo scuro")


# Stessa chiave, stessa polvere; il pesante ha più sbuffi, va più lontano e ha il pennacchio
func test_polvere() -> void:
	var a := ParticleFx.dust_burst(7, 300, 500)
	var b := ParticleFx.dust_burst(7, 300, 500)
	runner.check(str(a) == str(b), "stessa chiave, stesse particelle")
	var heavy := ParticleFx.dust_burst(7, 300, 500, 2.2)
	runner.check(heavy.size() > a.size(), "il pesante ha più particelle (%d contro %d)" % [heavy.size(), a.size()])
	runner.check(ParticleFx.span(heavy) > ParticleFx.span(a), "e dura di più")
	var left := 0
	var right := 0
	for p in a:
		if p.get("kind", "tex") == "tex":
			if float(p.vx) < 0:
				left += 1
			else:
				right += 1
	runner.check(left > 0 and right > 0, "la polvere va da tutte e due le parti")
	for p in ParticleFx.dust_burst(9, 300, 500, 1.0, -1):
		runner.check(float(p.vx) < 0, "con side = -1 va tutta a sinistra")
	var grits := a.filter(func(p): return p.get("kind", "") == "grit")
	runner.check(not grits.is_empty() and float(grits[0].floor) == 500.0, "sassolini che rimbalzano sul terreno dei piedi")


# L'impatto: più danno, più scintille; le scintille vanno dalla parte del colpo; il KO fa il fumo arancio
func test_impatto() -> void:
	var light := ParticleFx.impact_burst(1, 0, 0, 5, false, false, 1.0)
	var heavy := ParticleFx.impact_burst(1, 0, 0, 13, true, false, 1.0)
	var ko := ParticleFx.impact_burst(1, 0, 0, 18, true, true, -1.0)
	var sparks := func(l: Array) -> Array: return l.filter(func(p): return p.get("kind", "") == "spark")
	runner.check((sparks.call(heavy) as Array).size() > (sparks.call(light) as Array).size(), "il pesante ha più scintille")
	runner.check(light.size() == (sparks.call(light) as Array).size(), "il leggero non fa fumo")
	var ahead := 0
	for p in sparks.call(ko):
		if float(p.vx) < 0:
			ahead += 1
	runner.check(ahead > (sparks.call(ko) as Array).size() * 0.7, "le scintille del KO verso sinistra schizzano soprattutto a sinistra (%d)" % ahead)
	var smoke := ko.filter(func(p): return p.get("kind", "tex") == "tex")
	runner.check(not smoke.is_empty() and smoke[0].ramp[0] == "orange", "il KO lascia fumo arancio")


# La stella scatta oltre 1 e si ritira, e a fine vita non c'è
func test_stella() -> void:
	runner.check(ParticleFx.star_scale(0.15) > 1.0, "scatto iniziale")
	runner.check(ParticleFx.star_scale(0.9) < ParticleFx.star_scale(0.3), "poi si ritira")
	runner.check(ParticleFx.star_scale(1.0) == 0.0 and ParticleFx.star_scale(-0.1) == 0.0, "fuori dalla vita è zero")
	var pts := ParticleFx.star_points(Vector2(10, 10), 20.0, 9, 0.42, 3, 0.55)
	runner.check(pts.size() == 18, "9 punte, 18 punti")


# Fuoco ed esplosione (pronti per la fase 4): ci sono, e il fuoco ha sempre la sua lingua di fiamma
func test_fuoco_ed_esplosione() -> void:
	for i in 20:
		var step := ParticleFx.fire_step(i, 0, 0)
		runner.check(step[0].get("shape", "") == "flame", "ogni passo ha una fiamma (%d)" % i)
	var boom := ParticleFx.explosion_burst(5, 400, 480, 520)
	runner.check(boom.size() > 60, "l'esplosione è ricca (%d particelle)" % boom.size())
	runner.check(boom.any(func(p): return p.get("kind", "") == "grit" and float(p.floor) == 520.0), "schegge che ricadono a terra")


# Il tetto: oltre max_particles spariscono i gruppi più vecchi
func test_tetto_delle_particelle() -> void:
	var view: Node2D = ParticleView.new()
	view.max_particles = 40
	for i in 10:
		view.add(ParticleFx.dust_burst(i, 0, 0))
	runner.check(view.particle_count() <= 40 + 17, "resta vicino al tetto (%d)" % view.particle_count())
	view.clear()
	runner.check(view.particle_count() == 0, "clear svuota")
	view.free()


# La colonna del KO (#470 passo 2a): va verso il centro, ha il colore di chi esce, e il nucleo chiaro si somma alla luce
func test_colonna_del_ko() -> void:
	var dir := Vector2(-0.92, 0.39).normalized()
	var col := Color("3498db")
	var list := ParticleFx.ko_column(4, 1280, 120, dir, col)
	var along := 0
	var tinted := 0
	var tex := 0
	for p in list:
		if Vector2(float(p.vx), float(p.vy)).normalized().dot(dir) > 0.9:
			along += 1
		if p.get("kind", "tex") == "tex":
			tex += 1
			if (p.ramp as Array).has("tint") and p.tint == col:
				tinted += 1
	runner.check(along >= list.size() * 0.9, "la colonna entra verso il centro (%d su %d)" % [along, list.size()])
	runner.check(tinted >= 60, "le lingue hanno il colore di chi esce (%d)" % tinted)
	runner.check(list.any(func(p): return p.get("add", false)), "c'è il nucleo che si somma alla luce")
	var s := ParticleFx.sample(list[0], float(list[0].life) * 0.5)
	runner.check(not s.is_empty() and s.tone0 == "tint", "a metà vita si vede il colore del giocatore")


# Lo sbuffo della nuvoletta: solo sbuffi colorati, niente sassolini
func test_sbuffo_della_nuvoletta() -> void:
	var col := Color("e74c3c")
	var list := ParticleFx.cloud_puff(2, 400, 520, col)
	runner.check(not list.is_empty(), "c'è lo sbuffo")
	runner.check(list.all(func(p): return p.get("kind", "tex") == "tex" and p.ramp[0] == "tint"), "solo sbuffi del colore del giocatore")


# Vapore a danno alto (#470 passo 3): niente sotto la soglia, più fitto e più grosso salendo
func test_vapore() -> void:
	runner.check(ParticleFx.heat(40, 60, 150) == 0.0, "sotto il 60% niente vapore")
	runner.check(ParticleFx.heat(150, 60, 150) == 1.0 and ParticleFx.heat(300, 60, 150) == 1.0, "dal 150% al massimo")
	runner.check(ParticleFx.steam_every_ms(1.0) < ParticleFx.steam_every_ms(0.1), "più scotta, più è fitto")
	var low := ParticleFx.steam_puff(3, 0, 0, 0.1)
	var high := ParticleFx.steam_puff(3, 0, 0, 1.0)
	runner.check(float(high.s1) > float(low.s1) and float(high.alpha) > float(low.alpha), "più scotta, più è grosso e visibile")
	runner.check(ParticleFx.at(high, 1.0).y < 0.0, "il vapore sale")


# Lo sbuffo di un oggetto che compare: solo aria, niente sassolini, non cade
func test_sbuffo_degli_oggetti() -> void:
	var list := ParticleFx.item_puff(5, 300, 200)
	runner.check(not list.is_empty() and list.all(func(p): return p.get("kind", "tex") == "tex" and p.ramp[0] == "air" and float(p.gy) == 0.0), "solo sbuffi d'aria che non cadono")

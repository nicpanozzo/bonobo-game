# I vetri accesi della notte (#288) a pezzi: le immagini delle luci sono grandi come gli strati ma quasi vuote, e
# disegnarle intere costava tre passate su tutto lo schermo appena faceva buio (Bologna rallentava a fine partita, #433).
# Al caricamento si tengono solo le celle con almeno un pixel acceso, unite in strisce per riga; a ogni frame si
# disegnano quelle dentro l'inquadratura, tutte dalla stessa texture, così Godot le manda in una sola chiamata.
extends RefCounted

const CELL_PX := 48 # lato di una cella, in pixel dell'immagine
const MARGIN_PX := 2 # una cella vuota accanto a un vetro acceso si tiene: il filtro lineare sbava di un pixel


# Le strisce accese di un'immagine: [[alto, basso, [Rect2 in pixel, ...]], ...] per riga di celle, dall'alto
static func runs(img: Image) -> Array:
	var out: Array = []
	var size := img.get_size()
	for y in range(0, size.y, CELL_PX):
		var h := mini(CELL_PX, size.y - y)
		var row: Array = []
		var start := -1
		for x in range(0, size.x + CELL_PX, CELL_PX):
			var lit := x < size.x and _lit(img, Rect2i(x, y, mini(CELL_PX, size.x - x), h))
			if lit and start < 0:
				start = x
			elif not lit and start >= 0:
				row.append(Rect2(start, y, mini(x, size.x) - start, h))
				start = -1
		if not row.is_empty():
			out.append([float(y), float(y + h), row])
	return out


static func _lit(img: Image, cell: Rect2i) -> bool:
	var grown := cell.grow(MARGIN_PX).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return not img.get_region(grown).is_invisible()


# Disegna le strisce dentro view: dst è dove andrebbe l'immagine intera, come in draw_texture_rect
static func draw(ci: CanvasItem, tex: Texture2D, rows: Array, dst: Rect2, view: Rect2, modulate: Color) -> void:
	var parts := visible(tex.get_size(), rows, dst, view)
	for i in range(0, parts.size(), 2):
		ci.draw_texture_rect_region(tex, parts[i], parts[i + 1], modulate)


# Le strisce dentro view, a coppie: dove vanno sullo schermo e il pezzo dell'immagine
static func visible(tex_size: Vector2, rows: Array, dst: Rect2, view: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not dst.intersects(view):
		return out
	var k := dst.size / tex_size
	for row in rows:
		var top: float = dst.position.y + float(row[0]) * k.y
		var bottom: float = dst.position.y + float(row[1]) * k.y
		if bottom < view.position.y or top > view.end.y:
			continue
		for r: Rect2 in row[2]:
			var left := dst.position.x + r.position.x * k.x
			var right := left + r.size.x * k.x
			if right < view.position.x or left > view.end.x:
				continue
			out.append(Rect2(left, top, right - left, bottom - top))
			out.append(r)
	return out

// Il velo dietro i menu sopra il gioco (UI.overlay): inchiostro trasparente con un retino diagonale
// leggero, così pausa e opzioni sembrano una pagina di fumetto appoggiata sopra la partita.
shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.06, 0.035, 0.1, 1.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float line_px = 9.0; // passo del tratteggio

void fragment() {
	vec2 p = UV * rect_size;
	float hatch = step(0.72, fract((p.x - p.y) / line_px)); // righe sottili a 45 gradi
	float a = COLOR.a; // l'opacità la decide il ColorRect (pause_menu la anima)
	float v = distance(UV, vec2(0.5));
	COLOR = vec4(ink.rgb, clamp(a * (1.0 + hatch * 0.14 + 0.4 * smoothstep(0.3, 0.8, v)), 0.0, 1.0));
}

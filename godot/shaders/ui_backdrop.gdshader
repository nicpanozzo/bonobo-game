// Fondo dei menu (ui.gd, UI.backdrop): viola notte a strisce diagonali che scorrono piano,
// retino a punti negli angoli e bordi più scuri. Costa poco anche sul telefono: niente texture, solo conti.
shader_type canvas_item;

uniform vec4 base : source_color = vec4(0.11, 0.07, 0.19, 1.0);
uniform vec4 stripe : source_color = vec4(0.135, 0.09, 0.23, 1.0);
uniform vec4 dots : source_color = vec4(1.0, 0.79, 0.16, 0.10);
uniform vec2 rect_size = vec2(1280.0, 720.0); // pixel del ColorRect: le strisce restano larghe uguale su ogni schermo
uniform float stripe_px = 56.0; // larghezza di una coppia di strisce
uniform float speed = 10.0; // pixel al secondo; 0 = ferme (opzione "calma")
uniform float dot_px = 16.0; // passo del retino

void fragment() {
	vec2 p = UV * rect_size;
	float s = step(0.5, fract((p.x + p.y * 0.55 - TIME * speed) / stripe_px));
	vec3 c = mix(base.rgb, stripe.rgb, s);
	// Retino ruotato di 45 gradi: i punti crescono verso l'angolo in basso a sinistra e in alto a destra
	vec2 q = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * p / dot_px;
	float d = length(fract(q) - 0.5);
	vec2 uv = UV;
	float k = max(smoothstep(0.55, 0.0, distance(uv, vec2(0.0, 1.0))), smoothstep(0.5, 0.0, distance(uv, vec2(1.0, 0.0))));
	float dot = 1.0 - smoothstep(k * 0.5 - 0.06, k * 0.5, d);
	c = mix(c, dots.rgb, dot * dots.a * step(0.02, k));
	// Bordi più scuri, così il centro (dove stanno i menu) è il punto più chiaro
	float v = distance(uv, vec2(0.5, 0.45));
	c *= 1.0 - 0.45 * smoothstep(0.35, 0.85, v);
	COLOR = vec4(c, base.a);
}

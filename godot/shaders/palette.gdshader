// Colori alternativi dei lottatori (E11 passo C): due giocatori con lo stesso personaggio si distinguono.
// world_view.gd disegna tutto con questo materiale; uno sprite da ricolorare arriva con il rosso del
// modulate oltre 1 (2 + spostamento della tinta, da 0 a 1), che nessun altro disegno usa.
// I pixel quasi grigi (contorni, bianchi, neri) restano com'erano.
shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	if (tint.r > 1.5) {
		vec4 tex = texture(TEXTURE, UV);
		vec3 hsv = rgb2hsv(tex.rgb);
		if (hsv.y > 0.2) {
			hsv.x = fract(hsv.x + tint.r - 2.0);
		}
		COLOR = vec4(hsv2rgb(hsv), tex.a * tint.a);
	}
}

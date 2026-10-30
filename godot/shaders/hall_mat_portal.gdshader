// Portale di un'arena: un arco (rettangolo col tetto tondo) che mostra l'anteprima dell'arena come vista
// attraverso un velo d'energia che gira. Al bordo l'immagine si torce in un vortice e il colore del
// portale brucia come una fiamma fredda; con hover verso 1 (qualcuno davanti) il velo si apre e
// l'anteprima si vede nitida. Va su un QuadMesh verticale (HallMaterials.portal_mesh), aspect = w / h.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform sampler2D preview : source_color, filter_linear_mipmap, repeat_disable;
uniform float has_preview = 1.0;
uniform vec3 color : source_color = vec3(0.55, 0.3, 1.0);
uniform vec3 color_2 : source_color = vec3(1.0, 0.8, 0.25);
uniform float aspect = 0.62; // larghezza / altezza del quad
uniform float preview_aspect = 1.7778; // larghezza / altezza dell'anteprima: si ritaglia per riempire l'arco
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float intensity = 1.6;
uniform float motion = 1.0;

// distanza (negativa dentro) dall'arco: rettangolo in basso, semicerchio in alto; p in unità di larghezza
float arch_sd(vec2 p, float w, float h) {
	float r = w * 0.5;
	float body = max(abs(p.x) - r, -p.y);
	float top = length(p - vec2(0.0, h - r)) - r;
	return p.y > h - r ? top : body;
}

void fragment() {
	float t = TIME * motion;
	// coordinate col fondo dell'arco a y = 0, in unità di larghezza
	vec2 p = vec2((UV.x - 0.5), (1.0 - UV.y) / aspect);
	float h = 1.0 / aspect;
	float m = 0.06; // margine per l'alone
	float sd = arch_sd(p, 1.0 - m * 2.0, h - m);
	float aa = fwidth(sd) * 1.2;

	// vortice: ruota i punti attorno al centro dell'arco, di più vicino al bordo
	vec2 center = vec2(0.0, h * 0.48);
	vec2 d = p - center;
	float edge_k = smoothstep(-0.16, 0.0, sd);
	edge_k *= edge_k;
	float veil = mix(1.0, 0.25, hover);
	float swirl = edge_k * veil * (0.9 + 0.3 * sin(t * 0.7) + 0.2 * sin(t * 0.3 + length(d) * 3.0));
	float cs = cos(swirl);
	float sn = sin(swirl);
	vec2 dr = mat2(vec2(cs, sn), vec2(-sn, cs)) * d;
	// zoom che respira, come se l'arena fosse lì dietro
	float zoom = 1.0 - 0.04 * sin(t * 0.5) * veil;
	vec2 puv = (dr * zoom + center) * vec2(1.0, aspect);
	puv = vec2(puv.x + 0.5, 1.0 - puv.y);
	// ondulazione leggera
	puv += vec2(sin(puv.y * 14.0 + t * 1.3), cos(puv.x * 12.0 - t * 1.1)) * 0.006 * veil;
	float fit = aspect / preview_aspect;
	if (fit < 1.0) {
		puv.x = 0.5 + (puv.x - 0.5) * fit;
	} else {
		puv.y = 0.5 + (puv.y - 0.5) / fit;
	}
	vec3 img;
	if (has_preview > 0.5) {
		img = texture(preview, clamp(puv, 0.002, 0.998)).rgb;
	} else {
		float g = hall_fbm(puv * 4.0 + t * 0.1, 3.0);
		img = mix(HALL_NAVY * 3.0, color * 0.6, g);
	}

	// velo: strisce di energia che girano a spirale sopra l'immagine
	float a = atan(d.y, d.x);
	float rad = length(d);
	float spiral = sin(a * 3.0 + rad * 18.0 - t * 2.4);
	float n = hall_fbm(vec2(a * 2.0 + t * 0.4, rad * 6.0 - t * 0.8), 2.0);
	float streaks = smoothstep(0.55, 1.0, spiral * 0.5 + 0.5 + (n - 0.5) * 0.8) * edge_k;
	vec3 energy = mix(color, color_2, smoothstep(0.3, 0.8, n));
	img = mix(img, img * 0.6 + energy * 0.22, veil * 0.12 + edge_k * 0.6 * veil);
	img += energy * streaks * 0.7 * intensity * veil;

	// bordo che brucia: fiamme fredde che salgono lungo il contorno
	float flame_n = hall_fbm(vec2(p.x * 8.0 + sd * 3.0, p.y * 5.0 - t * 1.6), 3.0);
	float flame = exp(-abs(sd) * 70.0) * 1.4 + exp(-max(sd, 0.0) * 22.0) * step(0.0, sd) * flame_n * 1.2;
	vec3 hot = mix(color, vec3(1.0), 0.6);
	vec3 rim_col = mix(color, hot, exp(-abs(sd) * 120.0));
	rim_col = mix(rim_col, color_2, smoothstep(0.6, 0.85, flame_n) * 0.5);

	float inside = 1.0 - smoothstep(-aa, aa, sd);
	vec3 col = img * inside + rim_col * flame * intensity;
	float outside_glow = exp(-max(sd, 0.0) * 30.0) * (1.0 - inside);
	ALBEDO = col;
	ALPHA = clamp(inside + outside_glow * (0.4 + flame_n * 0.8), 0.0, 1.0) * smoothstep(m, m * 0.5, sd);
}

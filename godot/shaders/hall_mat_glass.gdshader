// Vetro del tabellone: lastra trasparente con un velo azzurro, i riflessi della sala che salgono di taglio,
// lo spessore che brilla sui bordi e (markings = 1) le righe bianche: il bordo e il rettangolo sopra il
// ferro, in proporzione al tabellone vero (1,80 x 1,05 m). Va su un QuadMesh, non su un BoxMesh.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.7, 0.85, 1.0);
uniform vec3 line_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float markings = 1.0;
uniform float opacity = 0.16;
uniform float motion = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// contorno di un rettangolo (lo..hi in UV) con lo spessore w per asse
float rect_line(vec2 uv, vec2 lo, vec2 hi, vec2 w) {
	vec2 d = (abs(uv - (lo + hi) * 0.5) - (hi - lo) * 0.5) / w;
	return 1.0 - smoothstep(0.7, 1.3, abs(max(d.x, d.y)));
}

void fragment() {
	float t = TIME * motion;
	vec2 uv = UV;
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float F = hall_fresnel(n_w * sign(dot(n_w, V) + 1e-4), V, 0.06);
	vec3 R = reflect(-V, n_w * sign(dot(n_w, V) + 1e-4));
	vec3 env = hall_env(normalize(R), t);
	// riflesso diagonale fisso, come una finestra
	float glare = smoothstep(0.05, 0.0, abs(uv.x * 0.7 + uv.y - 0.55)) * 0.35 + smoothstep(0.015, 0.0, abs(uv.x * 0.7 + uv.y - 0.7)) * 0.5;
	vec2 e = min(uv, 1.0 - uv);
	float edge = 1.0 - smoothstep(0.0, 0.025, min(e.x, e.y));
	float lines = 0.0;
	if (markings > 0.5) {
		vec2 w = vec2(0.05 / 1.8, 0.05 / 1.05) * 0.5;
		lines = rect_line(uv, vec2(0.03, 0.04), vec2(0.97, 0.96), w);
		// rettangolo sopra il ferro: 59 x 45 cm, il lato basso all'altezza del ferro
		lines = max(lines, rect_line(uv, vec2(0.336, 0.43), vec2(0.664, 0.857), w));
	}
	vec3 col = tint * 0.08 + env * (F * 1.5 + 0.1) + vec3(glare) * 0.4 + tint * edge * 0.8;
	col = mix(col, line_color * 1.2, lines);
	ALBEDO = col;
	ALPHA = clamp(opacity + F * 0.6 + glare * 0.3 + edge * 0.6 + lines, 0.0, 1.0);
}

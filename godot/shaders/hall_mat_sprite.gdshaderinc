// Corpo dello shader dei lottatori 2D (hall_mat_sprite e hall_mat_sprite_nearest): cambia solo il filtro
// della texture, che deve stare nella dichiarazione dell'uniform. Prima di includerlo: #define SPRITE_FILTER.
#include "res://shaders/hall_mat_common.gdshaderinc"

uniform sampler2D sprite_tex : source_color, SPRITE_FILTER, repeat_disable;
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0); // u0, v0, larghezza, altezza del fotogramma nella texture
uniform float flip_h = 0.0; // 1 = guarda a sinistra
uniform float pad = 0.06; // quota del quad per lato fuori dal fotogramma: spazio per contorno e alone
uniform float billboard = 1.0; // 1 = gira attorno a Y verso la telecamera
uniform vec3 outline_color : source_color = vec3(1.0, 0.84, 0.18); // colore del giocatore
uniform float outline_px = 3.0; // spessore del contorno, in texel della texture
uniform float outline_alpha = 0.95;
uniform float glow_alpha = 0.35; // alone morbido fuori dal contorno
uniform vec3 rim_color : source_color = vec3(1.0, 0.85, 0.55);
uniform float rim = 0.8; // luce di taglio sul bordo interno
uniform vec2 rim_dir = vec2(-0.6, -0.8); // da dove arriva la luce di taglio (x a destra, y in basso)
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0); // per intonare il disegno alla luce della sala
uniform float brightness = 1.0;
uniform float flash = 0.0; // 0..1 lampo bianco (selezionato, colpo)
uniform float gild = 0.0; // 0..1 statuetta d'oro
uniform float motion = 1.0;

void vertex() {
	if (billboard > 0.5) {
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
		vec3 fwd = cross(right, up);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

float alpha_at(vec2 f) {
	if (f.x < 0.0 || f.y < 0.0 || f.x > 1.0 || f.y > 1.0) {
		return 0.0;
	}
	return texture(sprite_tex, frame_rect.xy + f * frame_rect.zw).a;
}

void fragment() {
	float t = TIME * motion;
	vec2 uv = UV;
	if (flip_h > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec2 f = (uv - pad) / (1.0 - 2.0 * pad);
	vec4 tex = vec4(0.0);
	if (f.x >= 0.0 && f.y >= 0.0 && f.x <= 1.0 && f.y <= 1.0) {
		tex = texture(sprite_tex, frame_rect.xy + f * frame_rect.zw);
	}
	// un texel in coordinate del fotogramma
	vec2 texel = 1.0 / (vec2(textureSize(sprite_tex, 0)) * frame_rect.zw);
	vec2 o = texel * outline_px;
	float l = alpha_at(f + vec2(-o.x, 0.0));
	float r = alpha_at(f + vec2(o.x, 0.0));
	float u = alpha_at(f + vec2(0.0, -o.y));
	float d = alpha_at(f + vec2(0.0, o.y));
	float d1 = alpha_at(f + o * vec2(0.7, 0.7));
	float d2 = alpha_at(f + o * vec2(-0.7, 0.7));
	float d3 = alpha_at(f + o * vec2(0.7, -0.7));
	float d4 = alpha_at(f + o * vec2(-0.7, -0.7));
	float near_max = max(max(max(l, r), max(u, d)), max(max(d1, d2), max(d3, d4)));
	float near_min = min(min(min(l, r), min(u, d)), min(min(d1, d2), min(d3, d4)));
	// alone largo: quattro letture a distanza tripla
	vec2 o3 = o * 3.0;
	float far_max = max(max(alpha_at(f + vec2(-o3.x, 0.0)), alpha_at(f + vec2(o3.x, 0.0))), max(alpha_at(f + vec2(0.0, -o3.y)), alpha_at(f + vec2(0.0, o3.y))));

	vec3 col = tex.rgb * tint * brightness;
	if (gild > 0.0) {
		float lum = dot(tex.rgb, vec3(0.3, 0.55, 0.15));
		vec3 gold = mix(vec3(0.22, 0.1, 0.03), vec3(1.0, 0.72, 0.28), smoothstep(0.05, 0.7, lum));
		gold = mix(gold, vec3(1.0, 0.95, 0.75), smoothstep(0.7, 1.0, lum));
		float sweep = exp(-pow((fract(f.x * 0.6 + f.y * 0.4 - t * 0.12) - 0.5) * 16.0, 2.0));
		gold += vec3(1.0, 0.9, 0.6) * sweep * 0.7;
		col = mix(col, gold, gild);
	}
	// luce di taglio: i pixel pieni vicino al bordo dalla parte della luce
	vec2 grad = vec2(r - l, d - u);
	float edge = tex.a * (1.0 - near_min);
	float facing_light = clamp(dot(-normalize(grad + 1e-5), normalize(rim_dir)), 0.0, 1.0);
	col += mix(rim_color, outline_color, 0.35) * edge * facing_light * rim;
	col = mix(col, vec3(1.0), flash);

	float a_out = (1.0 - tex.a) * near_max * outline_alpha;
	float a_glow = (1.0 - tex.a) * (1.0 - near_max) * far_max * glow_alpha;
	vec3 oc = mix(outline_color, vec3(1.0), 0.15);
	vec3 final_col = col * tex.a + oc * a_out * 1.3 + outline_color * a_glow * 1.2;
	float alpha = tex.a + a_out + a_glow;
	if (alpha < 0.01) {
		discard;
	}
	ALBEDO = final_col / max(alpha, 1e-3);
	ALPHA = clamp(alpha, 0.0, 1.0);
}

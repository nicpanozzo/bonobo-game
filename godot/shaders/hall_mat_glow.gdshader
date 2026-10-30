// Bagliore additivo: un alone morbido che fa da bloom finto (in Compatibility il glow è caro sui telefoni)
// dietro neon, statue, trono; o, con on_floor = 1, una pozza di luce stesa sul pavimento sotto un faro.
// Va su un QuadMesh (billboard = 1 lo gira sempre verso la telecamera) o un PlaneMesh orizzontale.
// streak = 1: il riflesso allungato di una luce sul pavimento lucido (portali, schermi, neon), un PlaneMesh
// che parte dall'origine e si gira da solo verso la telecamera (HallMaterials.floor_reflection).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.78, 0.3);
uniform float intensity = 0.8;
uniform float falloff = 1.6; // più alto = alone più stretto
uniform float billboard = 1.0; // 1 = sempre rivolto alla telecamera
uniform float shimmer = 0.15; // tremolio lento, come luce che passa nel fumo
uniform float on_floor = 0.0; // 1 = pozza di luce: un anello più chiaro sul bordo, come un faro vero
uniform float streak = 0.0; // 1 = riflesso allungato verso la telecamera
uniform float motion = 1.0;

void vertex() {
	if (streak > 0.5) {
		// gira il piano attorno a Y così la scia punta sempre verso chi guarda
		vec3 origin = MODEL_MATRIX[3].xyz;
		vec2 d = (INV_VIEW_MATRIX[3].xyz - origin).xz;
		d = length(d) > 1e-4 ? normalize(d) : vec2(0.0, 1.0);
		vec3 z_axis = vec3(d.x, 0.0, d.y) * length(MODEL_MATRIX[2].xyz);
		vec3 x_axis = vec3(d.y, 0.0, -d.x) * length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x_axis, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(z_axis, 0.0), vec4(origin, 1.0));
	} else if (billboard > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	float t = TIME * motion;
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float g = pow(clamp(1.0 - r, 0.0, 1.0), falloff);
	if (on_floor > 0.5) {
		g = g * 0.7 + smoothstep(0.62, 0.8, r) * smoothstep(0.98, 0.82, r) * 0.35;
	}
	if (streak > 0.5) {
		// stretto ai lati, sfuma allontanandosi dall'oggetto, con le increspature del riflesso
		float across = exp(-pow(c.x * 2.0, 2.0) * 2.5 * falloff);
		float along = pow(1.0 - UV.y, 0.9) * smoothstep(0.0, 0.04, UV.y);
		float ripple = 0.8 + 0.2 * sin(UV.y * 50.0 + hall_noise(vec2(c.x * 6.0, UV.y * 8.0 - t * 0.3)) * 4.0);
		g = across * along * ripple * (1.0 + 1.5 * exp(-UV.y * 10.0));
	}
	float n = hall_noise(c * 3.0 + vec2(t * 0.15, -t * 0.1));
	g *= 1.0 - shimmer + shimmer * 2.0 * n;
	ALBEDO = color * g * intensity;
}

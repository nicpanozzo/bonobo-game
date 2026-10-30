// Ombra a macchia sotto lottatori, statue e oggetti: un ovale scuro sfumato steso a terra, che in
// Compatibility costa molto meno delle ombre vere e tiene gli sprite 2D attaccati al pavimento.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.65;
uniform vec3 color : source_color = vec3(0.0, 0.0, 0.02);

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float a = pow(clamp(1.0 - r, 0.0, 1.0), 1.6);
	ALBEDO = color;
	ALPHA = a * strength;
}

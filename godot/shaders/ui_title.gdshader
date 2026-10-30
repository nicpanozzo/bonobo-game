// Fondo del titolo (title_backdrop.gd): raggi alla "sunburst" che girano piano attorno al logo,
// un alone caldo dietro il logo e un retino a punti che cresce verso i bordi, come una locandina stampata.
shader_type canvas_item;

uniform vec4 base : source_color = vec4(0.11, 0.07, 0.19, 1.0);
uniform vec4 ray : source_color = vec4(0.16, 0.10, 0.27, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.45, 0.35, 0.22);
uniform vec4 dots : source_color = vec4(0.05, 0.03, 0.08, 0.55);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 center = vec2(0.5, 0.3); // da dove partono i raggi, in parti dello schermo
uniform float spin = 0.025; // giri al secondo dei raggi; 0 = fermi (opzione "calma")
uniform float rays = 16.0;
uniform float dot_px = 13.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 d = p - center * rect_size;
	float r = length(d);
	float a = atan(d.y, d.x) / 6.2831853 + TIME * spin;
	float stripe = step(0.5, fract(a * rays));
	vec3 c = mix(base.rgb, ray.rgb, stripe * smoothstep(1500.0, 60.0, r));
	c += glow.rgb * glow.a * smoothstep(560.0, 0.0, r);
	// Retino: i punti crescono allontanandosi dal centro
	vec2 q = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * p / dot_px;
	float cell = length(fract(q) - 0.5);
	float size = clamp((r - 260.0) / 900.0, 0.0, 0.62);
	float dot = 1.0 - smoothstep(size * 0.5 - 0.05, size * 0.5, cell);
	c = mix(c, dots.rgb, dot * dots.a * step(0.01, size));
	float v = distance(UV, vec2(0.5, 0.42));
	c *= 1.0 - 0.5 * smoothstep(0.4, 0.95, v);
	COLOR = vec4(c, 1.0);
}

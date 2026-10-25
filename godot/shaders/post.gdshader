// Post-processing dell'arena (post_fx.gd): un passaggio solo su tutta la scena, sotto l'HUD, che lega sprite
// fatti in modi diversi (video, disegni a codice, GIF). In ordine: bagliore leggero delle parti chiare,
// colori dell'arena (gain moltiplica, lift schiarisce le ombre verso un colore), saturazione, contrasto,
// vignetta ai bordi e un filo di grana che cambia 24 volte al secondo
shader_type canvas_item;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform vec3 gain = vec3(1.0);
uniform vec3 lift = vec3(0.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float bloom = 0.0; // quanto bagliore si aggiunge
uniform float threshold = 0.82; // da che luminosità una parte comincia a brillare
uniform bool light_bloom = false; // telefoni e browser: una lettura sola invece di cinque
uniform float vignette = 0.0;
uniform float grain = 0.0;
uniform float aspect = 1.7778;
uniform float t = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen, uv).rgb;
	if (bloom > 0.0) {
		// Cinque letture su un livello piccolo della mipmap: costa come un quinto di un blur vero
		vec2 o = vec2(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y) * 10.0;
		vec3 b;
		if (light_bloom) {
			b = textureLod(screen, uv, 3.5).rgb;
		} else {
			b = textureLod(screen, uv, 3.0).rgb * 0.4;
			b += textureLod(screen, uv + vec2(o.x, o.y), 3.5).rgb * 0.15;
			b += textureLod(screen, uv + vec2(-o.x, o.y), 3.5).rgb * 0.15;
			b += textureLod(screen, uv + vec2(o.x, -o.y), 3.5).rgb * 0.15;
			b += textureLod(screen, uv + vec2(-o.x, -o.y), 3.5).rgb * 0.15;
		}
		c += max(b - threshold, 0.0) / (1.0 - threshold) * bloom; // solo quello che supera la soglia: i bianchi grandi non diventano lattiginosi
	}
	c = c * gain + lift * (1.0 - c);
	c = mix(vec3(luma(c)), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	vec2 d = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	c *= 1.0 - vignette * smoothstep(0.42, 1.05, length(d));
	if (grain > 0.0) {
		float n = fract(sin(dot(FRAGCOORD.xy + floor(t * 24.0) * vec2(17.0, 31.0), vec2(12.9898, 78.233))) * 43758.5453);
		c += (n - 0.5) * grain;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

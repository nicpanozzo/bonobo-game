// Il colpo che chiude la partita (#470 passo 2b): per un attimo la scena va in negativo, come nei manga.
// amount va da 0 (scena normale) a 1 (tutta invertita): sagome scure su fondo chiaro, un po' calde, con linee rosse
// che puntano al colpo (center, in coordinate dello schermo da 0 a 1)
shader_type canvas_item;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec2 center = vec2(0.5);
uniform float t = 0.0;
uniform float aspect = 1.7778;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 inv = vec3(1.0) - c;
	float grey = dot(inv, vec3(0.3, 0.59, 0.11));
	vec3 neg = mix(inv, vec3(grey) * vec3(1.0, 0.96, 0.9), 0.35);
	// linee verso il colpo: settori a caso, che cambiano a scatti, solo lontano dal centro
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float sector = floor((atan(d.y, d.x) + 3.14159) / 6.28318 * 72.0);
	float spoke = step(0.82, hash(sector + floor(t * 14.0) * 7.0));
	float r = length(d);
	spoke *= smoothstep(0.1, 0.22, r);
	neg = mix(neg, vec3(0.84, 0.27, 0.17), spoke * 0.65);
	COLOR = vec4(mix(c, neg, amount), 1.0);
}

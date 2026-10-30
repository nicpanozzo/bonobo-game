// Lottatore 2D nella sala 3D: billboard che resta dritto (gira solo attorno a Y), senza luci (i disegni
// hanno già le loro ombre), con un contorno e un alone nel colore del giocatore e una luce di taglio sul
// bordo della sagoma, così il personaggio si stacca dal fondo scuro. gild = 1 lo trasforma in una
// statuetta d'oro (piedistalli, trono). Un fotogramma si sceglie con frame_rect (UV della texture).
shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, shadows_disabled;

#define SPRITE_FILTER filter_linear
#include "res://shaders/hall_mat_sprite.gdshaderinc"

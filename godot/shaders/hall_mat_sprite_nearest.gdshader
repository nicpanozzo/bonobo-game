// Lottatore 2D in pixel art (orsoblu): come hall_mat_sprite, ma coi pixel netti.
shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, shadows_disabled;

#define SPRITE_FILTER filter_nearest
#include "res://shaders/hall_mat_sprite.gdshaderinc"

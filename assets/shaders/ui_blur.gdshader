shader_type canvas_item;
// Blurred, tinted copy of the game behind a menu.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.02, 0.04, 0.14, 0.55);

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(scene, tint.rgb, tint.a), 1.0);
}

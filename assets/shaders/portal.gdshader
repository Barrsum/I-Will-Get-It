shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Swirling portal surface for a flat disc (UV centre = portal centre).

uniform vec4 color_a : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.9, 0.2, 1.0, 1.0);
uniform float intensity = 1.6;
uniform float opening : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 12.0 - TIME * 4.0) * 0.5 + 0.5;
	float rings = sin(r * 22.0 - TIME * 6.0) * 0.5 + 0.5;
	float mask = (1.0 - smoothstep(0.85 * opening, 1.0 * opening, r)) * step(0.001, opening);
	vec3 col = mix(color_a.rgb, color_b.rgb, swirl) * (0.35 + 0.65 * rings);
	col += vec3(1.0) * pow(1.0 - clamp(r, 0.0, 1.0), 6.0);  // Bright core.
	ALBEDO = col * intensity * mask;
	ALPHA = mask;
}

shader_type spatial;
// World-space prototype grid for blockout geometry: 1 m minor lines, 4 m major lines.
// Colour per object via instance uniform, so every block shares one material.

instance uniform vec4 tint : source_color = vec4(0.7, 0.72, 0.78, 1.0);
uniform float line_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid(vec2 p, float cell, float width) {
	vec2 q = p / cell;
	vec2 d = abs(fract(q - 0.5) - 0.5) / fwidth(q);
	return 1.0 - clamp(min(d.x, d.y) - width, 0.0, 1.0);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float lines = max(grid(uv, 1.0, 0.4) * 0.5, grid(uv, 4.0, 1.0));
	ALBEDO = mix(tint.rgb, tint.rgb * 0.55, lines * line_strength * 2.0);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}

shader_type spatial;
// Toy-block look for platformer tiles: flat colour, soft bevelled cell edges, optional brick
// pattern. Cells are aligned to world space, so merged runs of blocks still read as tiles.

uniform vec4 base_color : source_color = vec4(0.6, 0.4, 0.22, 1.0);
uniform vec4 edge_color : source_color = vec4(0.35, 0.2, 0.1, 1.0);
uniform float cell_size = 1.5;
uniform float edge_width : hint_range(0.0, 0.3) = 0.06;
uniform bool brick_pattern = false;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float edge_mask(vec2 p, float width) {
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f);
	float e = min(d.x, d.y);
	return 1.0 - smoothstep(width * 0.5, width, e);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	uv /= cell_size;
	float edges = edge_mask(uv, edge_width);
	if (brick_pattern) {
		// Two brick rows per cell, offset every other row.
		vec2 b = uv * vec2(2.0, 4.0);
		b.x += step(1.0, mod(b.y, 2.0)) * 0.5;
		edges = max(edges, edge_mask(b, edge_width * 2.2) * 0.9);
	}
	ALBEDO = mix(base_color.rgb, edge_color.rgb, edges);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.35;
}

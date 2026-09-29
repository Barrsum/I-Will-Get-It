shader_type spatial;
// Stylised city facade: wall colour with a world-aligned grid of windows (some lit), a darker
// shopfront band at street level, and a lighter cornice line at the top edge.

uniform vec4 wall_color : source_color = vec4(0.85, 0.55, 0.4, 1.0);
uniform vec4 window_color : source_color = vec4(0.16, 0.2, 0.32, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform float floor_height = 3.2;
uniform float bay_width = 2.6;
uniform float ground_floor = 4.0;
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec3 albedo = wall_color.rgb;
	vec3 emission = vec3(0.0);
	if (n.y < 0.5) {
		float u = n.x > n.z ? world_pos.z : world_pos.x;
		float v = world_pos.y;
		if (v < ground_floor) {
			// Shopfront: dark glass band with a light frame.
			float frame = step(ground_floor - 0.35, v) + step(v, 0.4);
			albedo = mix(window_color.rgb * 0.8, wall_color.rgb * 0.7, clamp(frame, 0.0, 1.0));
		} else {
			vec2 cell = vec2(u / bay_width, (v - ground_floor) / floor_height);
			vec2 f = fract(cell);
			bool is_window = f.x > 0.22 && f.x < 0.78 && f.y > 0.2 && f.y < 0.78;
			if (is_window) {
				bool lit = hash(floor(cell)) < lit_fraction;
				albedo = lit ? lit_color.rgb : window_color.rgb;
				emission = lit ? lit_color.rgb * 0.9 : vec3(0.0);
			} else if (f.y < 0.2 && f.y > 0.12 && f.x > 0.18 && f.x < 0.82) {
				albedo = wall_color.rgb * 1.15;  // Sill.
			}
		}
	} else {
		albedo = wall_color.rgb * 0.6;  // Roof.
	}
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 0.8;
}

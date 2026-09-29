shader_type spatial;
// Daylight futuristic tower: light composite panels, continuous ribbon windows of blue glass
// (with a fake sky-reflection gradient), thin mullions, and a coloured accent band every few
// floors. World-aligned, so any box becomes a building.

uniform vec4 wall_color : source_color = vec4(0.88, 0.9, 0.92, 1.0);
uniform vec4 glass_color : source_color = vec4(0.32, 0.5, 0.66, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.8, 0.86, 0.92, 1.0);
uniform vec4 accent_color : source_color = vec4(0.2, 0.7, 0.8, 1.0);
uniform float floor_height = 3.4;
uniform float bay_width = 2.4;
uniform float accent_every = 5.0;
uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec3 albedo = wall_color.rgb;
	float rough = 0.6;
	float metal = 0.1;
	if (n.y < 0.5) {
		float u = n.x > n.z ? world_pos.z : world_pos.x;
		float v = world_pos.y;
		float fy = fract(v / floor_height);
		float fx = fract(u / bay_width + seed * 0.37);
		if (v < 4.5) {
			// Lobby: tall glass with a dark frame.
			albedo = (fx < 0.04) ? wall_color.rgb * 0.5 : glass_color.rgb * 0.8;
			rough = 0.15;
		} else if (fy > 0.3 && fy < 0.86) {
			if (fx < 0.035) {
				albedo = wall_color.rgb * 0.75;  // Mullion.
			} else {
				// Glass: brighter toward the top of each band, like a reflected sky.
				albedo = mix(glass_color.rgb, sky_tint.rgb, smoothstep(0.3, 0.86, fy) * 0.55);
				rough = 0.08;
				metal = 0.35;
			}
		} else if (fy < 0.08) {
			albedo = wall_color.rgb * 0.82;  // Floor slab line.
		}
		float band = fract(v / (floor_height * accent_every));
		if (v > 4.5 && band < 0.05) {
			albedo = accent_color.rgb;
			rough = 0.4;
		}
	} else {
		albedo = wall_color.rgb * 0.7;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
}

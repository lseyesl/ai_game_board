shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float wave_speed : hint_range(0.1, 3.0) = 1.0;
uniform float wave_amplitude : hint_range(0.05, 1.0) = 0.3;
uniform vec3 sun_direction = vec3(0.5, 0.8, 0.3);
uniform vec3 sea_center = vec3(0.0, 0.0, 0.0);

varying float wave_height;
varying vec3 world_position;


float calc_wave_height(vec3 wp, float t) {
	float speed = wave_speed;
	float amp = wave_amplitude;

	// Layer 1: large rolling waves
	float h1 = sin(wp.x * 0.05 + t * speed * 0.8)
			 * cos(wp.z * 0.04 + t * speed * 0.6)
			 * amp;

	// Layer 2: medium cross-waves
	float h2 = sin(wp.x * 0.15 + t * speed * 1.2)
			 * sin(wp.z * 0.12 + t * speed * 0.9)
			 * amp * 0.4;

	// Layer 3: small ripples
	float h3 = sin(wp.x * 0.4 + wp.z * 0.3 + t * speed * 2.0)
			 * amp * 0.1;

	return h1 + h2 + h3;
}


void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;

	wave_height = calc_wave_height(world_pos, t);
	world_position = world_pos;

	VERTEX.y += wave_height;
}


void fragment() {
	float t = TIME;
	vec3 wp = world_position;

	// Analytical normal via finite differences
	float eps = 0.1;
	float hx = calc_wave_height(wp + vec3(eps, 0.0, 0.0), t);
	float hz = calc_wave_height(wp + vec3(0.0, 0.0, eps), t);
	vec3 perturbed_local = normalize(vec3(wave_height - hx, eps, wave_height - hz));

	// Transform to world space (approximate — works for uniform scale + rotation)
	mat3 model_mat = mat3(MODEL_MATRIX);
	vec3 perturbed_normal_world = normalize(model_mat * perturbed_local);
	NORMAL = perturbed_normal_world;

	// Depth color gradient — high wave = lagoon/aqua, low = saturated blue.
	vec3 shallow_color = vec3(0.267, 0.827, 0.843); // animated aqua
	vec3 mid_color     = vec3(0.102, 0.596, 0.737); // clear cyan-blue
	vec3 deep_color    = vec3(0.071, 0.298, 0.529); // rich cartoon ocean
	float depth_factor = smoothstep(-wave_amplitude, wave_amplitude, wave_height);
	vec3 base_color = mix(deep_color, mid_color, depth_factor);

	// Animated aqua bands carry most of the stylization without washing the sea white.
	float aqua_band = smoothstep(0.64, 0.82, sin(wp.x * 0.09 + wp.z * 0.055 + t * wave_speed * 0.75) * 0.5 + 0.5);
	base_color = mix(base_color, shallow_color, aqua_band * 0.22 * depth_factor);

	float teal_ribbon = smoothstep(0.48, 0.54, sin(wp.x * 0.18 - wp.z * 0.07 + t * wave_speed * 1.4) * 0.5 + 0.5);
	base_color += vec3(0.0, 0.11, 0.13) * teal_ribbon * 0.12;

	// Narrow Blinn-Phong glints: bright accents, not broad white patches.
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 half_vec = normalize(normalize(sun_direction) + view_dir);
	float spec = pow(max(dot(perturbed_normal_world, half_vec), 0.0), 128.0);
	float narrow_glint = smoothstep(0.78, 0.94, spec);

	// Short animated foam lines sit on wave crests for an anime-water feel.
	float crest_mask = smoothstep(0.18, 0.30, wave_height);
	float line_wave = sin(wp.x * 0.42 + wp.z * 0.18 + t * wave_speed * 2.8) * 0.5 + 0.5;
	float broken_line = smoothstep(0.86, 0.96, line_wave);
	float foam_line = crest_mask * broken_line;

	base_color += vec3(0.82, 0.98, 1.0) * narrow_glint * 0.22;
	base_color += vec3(0.72, 0.96, 1.0) * foam_line * 0.18;

	// Edge alpha fade — PlaneMesh is 220x420 and follows sea_center.
	vec3 local_wp = wp - sea_center;
	float dist_x = abs(local_wp.x) / 110.0;
	float dist_z = abs(local_wp.z) / 210.0;
	float edge = max(dist_x, dist_z);
	float alpha = 1.0 - smoothstep(0.8, 1.0, edge);

	ALBEDO = base_color;
	ALPHA = alpha;
	ROUGHNESS = 0.4;
	METALLIC = 0.1;
}

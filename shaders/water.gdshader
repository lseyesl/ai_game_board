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

	// Depth color gradient — high wave = shallow/light, low = deep/dark
	vec3 shallow_color = vec3(0.494, 0.784, 0.890); // #7EC8E3
	vec3 deep_color    = vec3(0.227, 0.486, 0.647); // #3A7CA5
	float depth_factor = smoothstep(-wave_amplitude, wave_amplitude, wave_height);
	vec3 base_color = mix(deep_color, shallow_color, depth_factor);

	// Hard-edge Blinn-Phong specular (cartoon style)
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 half_vec = normalize(normalize(sun_direction) + view_dir);
	float spec = pow(max(dot(perturbed_normal_world, half_vec), 0.0), 64.0);
	float spec_cartoon = step(0.5, spec); // crisp edge for stylized look
	base_color += vec3(1.0) * spec_cartoon * 0.6;

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

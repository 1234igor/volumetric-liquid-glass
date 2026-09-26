shader_type canvas_item;
render_mode unshaded;

// A full-frame dielectric volume renderer. Geometry is an analytic signed
// distance field, so every pixel has both an entry and an exit interface.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 screen_pixel_size = vec2(0.0004166667, 0.000625);
uniform vec2 viewport_size = vec2(1200.0, 800.0);
uniform int object_type = 0; // 0 panel, 1 orb, 2 torus, 3 cluster
uniform float camera_yaw = 0.65;
uniform float camera_pitch = -0.18;
uniform float camera_distance = 5.4;
uniform float field_of_view = 42.0;
uniform float is_clear = 0.0;
uniform float is_tinted = 0.0;
uniform float warmth = 0.75;
uniform float interaction_energy = 0.0;
uniform float phase = 0.0;

const int ENTRY_STEPS = 72;
const int EXIT_STEPS = 56;
const float HIT_EPSILON = 0.0016;
const float FAR_DISTANCE = 14.0;

float volume_bound_radius() {
	if (object_type == 0) {
		return 2.50;
	}
	if (object_type == 1) {
		return 1.25;
	}
	if (object_type == 2) {
		return 1.60;
	}
	return 2.00;
}

float bound_entry(vec3 origin, vec3 direction) {
	float projection = dot(origin, direction);
	float radius = volume_bound_radius();
	float discriminant = projection * projection - (dot(origin, origin) - radius * radius);
	if (discriminant < 0.0) {
		return -1.0;
	}
	return max(-projection - sqrt(discriminant), 0.0);
}

float sd_round_box(vec3 point, vec3 half_size, float radius) {
	vec3 q = abs(point) - half_size + vec3(radius);
	return length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0) - radius;
}

float sd_torus(vec3 point, vec2 radii) {
	vec2 q = vec2(length(point.xz) - radii.x, point.y);
	return length(q) - radii.y;
}

float smooth_union(float first, float second, float radius) {
	float h = clamp(0.5 + 0.5 * (second - first) / radius, 0.0, 1.0);
	return mix(second, first, h) - radius * h * (1.0 - h);
}

float volume_sdf(vec3 point) {
	if (object_type == 0) {
		return sd_round_box(point, vec3(2.20, 0.48, 0.25), 0.22);
	}
	if (object_type == 1) {
		float orb = length(point) - 1.18;
		float dimple = length(point - vec3(0.38, 0.42, 0.82)) - 0.34;
		return max(orb, -dimple);
	}
	if (object_type == 2) {
		return sd_torus(point, vec2(1.13, 0.38));
	}
	float first = length(point - vec3(-0.72, 0.05, 0.08)) - 0.82;
	float second = length(point - vec3(0.58, 0.28, -0.12)) - 0.93;
	float third = sd_round_box(point - vec3(0.10, -0.62, 0.28), vec3(0.78, 0.46, 0.58), 0.34);
	return smooth_union(smooth_union(first, second, 0.42), third, 0.34);
}

vec3 volume_normal(vec3 point) {
	const float epsilon = 0.0015;
	return normalize(vec3(
		volume_sdf(point + vec3(epsilon, 0.0, 0.0)) - volume_sdf(point - vec3(epsilon, 0.0, 0.0)),
		volume_sdf(point + vec3(0.0, epsilon, 0.0)) - volume_sdf(point - vec3(0.0, epsilon, 0.0)),
		volume_sdf(point + vec3(0.0, 0.0, epsilon)) - volume_sdf(point - vec3(0.0, 0.0, epsilon))
	));
}

// x = entry distance (-1 on miss), y = closest SDF approach for antialiasing.
vec2 trace_entry(vec3 origin, vec3 direction) {
	float travel = bound_entry(origin, direction);
	if (travel < 0.0) {
		return vec2(-1.0, 100.0);
	}
	float closest = 100.0;
	for (int step = 0; step < ENTRY_STEPS; step++) {
		float distance = volume_sdf(origin + direction * travel);
		closest = min(closest, abs(distance));
		if (distance < HIT_EPSILON) {
			return vec2(travel, closest);
		}
		travel += max(distance * 0.78, 0.007);
		if (travel > FAR_DISTANCE) {
			break;
		}
	}
	return vec2(-1.0, closest);
}

float trace_exit(vec3 origin, vec3 direction) {
	float travel = 0.008;
	for (int step = 0; step < EXIT_STEPS; step++) {
		float distance = volume_sdf(origin + direction * travel);
		if (distance > HIT_EPSILON && travel > 0.018) {
			return travel;
		}
		travel += max(abs(distance) * 0.72, 0.005);
		if (travel > 7.0) {
			break;
		}
	}
	return -1.0;
}

vec2 project_to_screen(
		vec3 point,
		vec3 camera_position,
		vec3 camera_right,
		vec3 camera_up,
		vec3 camera_forward,
		float tangent_half_fov,
		float aspect
) {
	vec3 relative = point - camera_position;
	float depth = max(dot(relative, camera_forward), 0.001);
	float x = dot(relative, camera_right) / (depth * tangent_half_fov * aspect);
	float y = dot(relative, camera_up) / (depth * tangent_half_fov);
	return vec2(0.5 + x * 0.5, 0.5 - y * 0.5);
}

vec2 background_uv(
		vec3 origin,
		vec3 direction,
		vec3 camera_position,
		vec3 camera_right,
		vec3 camera_up,
		vec3 camera_forward,
		float tangent_half_fov,
		float aspect
) {
	// The background is conceptually behind the analytic volume. Keeping that
	// plane close produces Apple's calm center transmission while the two real
	// dielectric interfaces still drive edge refraction.
	float plane_depth = 6.2;
	float denominator = max(dot(direction, camera_forward), 0.025);
	float travel = (plane_depth - dot(origin - camera_position, camera_forward)) / denominator;
	return project_to_screen(
		origin + direction * max(travel, 0.0),
		camera_position,
		camera_right,
		camera_up,
		camera_forward,
		tangent_half_fov,
		aspect
	);
}

float fresnel_schlick(float cosine, float ior) {
	float f0 = (ior - 1.0) / (ior + 1.0);
	f0 *= f0;
	return f0 + (1.0 - f0) * pow(1.0 - clamp(cosine, 0.0, 1.0), 5.0);
}

vec3 safe_refract(vec3 incident, vec3 normal, float eta) {
	vec3 result = refract(incident, normal, eta);
	return length(result) < 0.001 ? reflect(incident, normal) : normalize(result);
}

vec3 tinted_transform(vec3 color) {
	if (is_tinted < 0.5) {
		return color;
	}
	// The canonical 2D branch uses the native fitted color matrix. A volume
	// needs a transmissive dye instead: the background must remain legible as
	// optical thickness increases through the body.
	vec3 dyed = color * vec3(1.12, 0.54, 0.60) + vec3(0.055, 0.004, 0.006);
	return mix(color, dyed, mix(0.78, 0.60, is_clear));
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	centered.y = -centered.y;
	float aspect = viewport_size.x / viewport_size.y;
	float tangent_half_fov = tan(field_of_view * PI / 360.0);
	vec3 camera_position = vec3(
		sin(camera_yaw) * cos(camera_pitch),
		sin(camera_pitch),
		cos(camera_yaw) * cos(camera_pitch)
	) * camera_distance;
	vec3 camera_forward = normalize(-camera_position);
	vec3 camera_right = normalize(cross(camera_forward, vec3(0.0, 1.0, 0.0)));
	vec3 camera_up = normalize(cross(camera_right, camera_forward));
	vec3 ray_direction = normalize(
		camera_forward
		+ camera_right * centered.x * aspect * tangent_half_fov
		+ camera_up * centered.y * tangent_half_fov
	);

	vec2 entry = trace_entry(camera_position, ray_direction);
	if (entry.x < 0.0) {
		// A second, shorter sphere trace gives the volume a soft screen-space
		// elevation shadow without flattening its actual silhouette.
		vec2 shadow_ndc = centered - vec2(-0.022, -0.035);
		vec3 shadow_ray = normalize(
			camera_forward
			+ camera_right * shadow_ndc.x * aspect * tangent_half_fov
			+ camera_up * shadow_ndc.y * tangent_half_fov
		);
		vec2 shadow_hit = trace_entry(camera_position, shadow_ray);
		float shadow_alpha = shadow_hit.x >= 0.0 ? 0.15 : 0.0;
		COLOR = vec4(0.0, 0.0, 0.0, shadow_alpha);
	} else {
		vec3 entry_point = camera_position + ray_direction * entry.x;
		vec3 entry_normal = volume_normal(entry_point);
		float ior = mix(1.49, 1.515, is_clear);
		vec3 inside_direction = safe_refract(ray_direction, entry_normal, 1.0 / ior);
		float exit_distance = trace_exit(entry_point - entry_normal * 0.006, inside_direction);
		if (exit_distance < 0.0) {
			exit_distance = 0.12;
		}
		vec3 exit_point = entry_point - entry_normal * 0.006 + inside_direction * exit_distance;
		vec3 exit_normal = volume_normal(exit_point);
		float thickness = max(length(exit_point - entry_point), 0.01);

		vec3 inside_red = safe_refract(ray_direction, entry_normal, 1.0 / (ior - 0.0030));
		vec3 inside_blue = safe_refract(ray_direction, entry_normal, 1.0 / (ior + 0.0035));
		vec3 outgoing_red = safe_refract(inside_red, -exit_normal, ior - 0.0030);
		vec3 outgoing_green = safe_refract(inside_direction, -exit_normal, ior);
		vec3 outgoing_blue = safe_refract(inside_blue, -exit_normal, ior + 0.0035);
		vec2 uv_red = clamp(background_uv(exit_point, outgoing_red, camera_position, camera_right, camera_up, camera_forward, tangent_half_fov, aspect), vec2(0.001), vec2(0.999));
		vec2 uv_green = clamp(background_uv(exit_point, outgoing_green, camera_position, camera_right, camera_up, camera_forward, tangent_half_fov, aspect), vec2(0.001), vec2(0.999));
		vec2 uv_blue = clamp(background_uv(exit_point, outgoing_blue, camera_position, camera_right, camera_up, camera_forward, tangent_half_fov, aspect), vec2(0.001), vec2(0.999));
		uv_red = mix(uv_green, uv_red, 0.48);
		uv_blue = mix(uv_green, uv_blue, 0.48);
		float diffusion_lod = mix(2.4, 0.0, is_clear);
		vec3 refracted = vec3(
			textureLod(screen_texture, uv_red, diffusion_lod).r,
			textureLod(screen_texture, uv_green, diffusion_lod).g,
			textureLod(screen_texture, uv_blue, diffusion_lod).b
		);
		vec3 undistorted = textureLod(screen_texture, SCREEN_UV, diffusion_lod).rgb;
		float facing = max(dot(-ray_direction, entry_normal), 0.0);
		float fresnel = fresnel_schlick(facing, ior);
		float optical_mix = mix(0.42, 0.62, is_clear) + fresnel * 0.22;
		refracted = mix(undistorted, refracted, clamp(optical_mix, 0.0, 0.84));

		vec3 body_color = is_tinted > 0.5
			? vec3(1.0, 0.08, 0.12)
			: vec3(1.0, 1.0 - 0.07 * warmth, 1.0 - 0.17 * warmth);
		vec3 absorption = is_tinted > 0.5
			? vec3(0.018, 0.72, 0.58)
			: mix(vec3(0.034, 0.052, 0.084), vec3(0.010, 0.016, 0.026), is_clear);
		vec3 transmittance = exp(-absorption * thickness);
		float scatter_strength = mix(0.14, 0.018, is_clear);
		vec3 color = refracted * transmittance
			+ body_color * (vec3(1.0) - transmittance) * scatter_strength;

		vec2 screen_normal = vec2(dot(entry_normal, camera_right), -dot(entry_normal, camera_up));
		vec2 reflection_uv = clamp(SCREEN_UV + screen_normal * (0.018 + fresnel * 0.035), vec2(0.001), vec2(0.999));
		vec3 reflection = textureLod(screen_texture, reflection_uv, 1.6).rgb;
		color = mix(color, reflection * 1.04, fresnel * mix(0.36, 0.54, is_clear));

		vec3 light_direction = normalize(vec3(-0.45, 0.72, 0.58));
		vec3 half_vector = normalize(light_direction - ray_direction);
		float specular = pow(max(dot(entry_normal, half_vector), 0.0), mix(72.0, 150.0, is_clear));
		float exit_caustic = pow(max(dot(-exit_normal, light_direction), 0.0), 5.0);
		float internal_band = 0.5 + 0.5 * sin(thickness * 12.0 + entry_point.x * 2.1 - entry_point.y * 1.8 + phase);
		float caustic = exit_caustic * internal_band * (1.0 - dot(transmittance, vec3(0.3333)));
		color += vec3(1.0, 0.97, 0.92) * (specular * (0.24 + fresnel * 0.9) + caustic * 0.28);
		color = tinted_transform(color);
		float interaction_glow = interaction_energy * (0.045 + fresnel * 0.16);
		color = mix(color, vec3(1.0), interaction_glow);

		COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
	}
}

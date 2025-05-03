shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.1, 0.3, 0.8);
uniform vec3 sky_horizon_color : source_color = vec3(0.6, 0.7, 0.9);
uniform float horizon_blend : hint_range(0.0, 1.0, 0.1) = 0.1;

void sky() {
	float t = clamp(EYEDIR.y / horizon_blend, -1.0, 1.0) * 0.5 + 0.5;
	COLOR = mix(sky_horizon_color, sky_top_color, t);
}
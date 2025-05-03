shader_type spatial;

uniform sampler2D noise_texture;
uniform sampler2D noise_texture2;
uniform vec4 lava_color1 : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform vec4 lava_color2 : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform vec4 lava_color3 : source_color = vec4(0.8, 0.1, 0.0, 1.0);
uniform float flow_speed : hint_range(0.1, 5.0) = 0.5;
uniform float secondary_flow_speed : hint_range(0.1, 2.0) = 0.2;
uniform float noise_scale : hint_range(0.5, 5.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.3;
uniform float emission_strength : hint_range(1.0, 15.0) = 5.0;
uniform float bubble_speed : hint_range(0.1, 3.0) = 0.8;
uniform float bubble_threshold : hint_range(0.5, 0.95) = 0.75;
uniform float bubble_size : hint_range(0.01, 0.2) = 0.05;
uniform float parallax_scale : hint_range(0.0, 1.0) = 0.1;
uniform float parallax_depth : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Get view direction in tangent space for parallax
    vec3 view_dir = normalize(INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
    vec2 parallax_offset = view_dir.xy * parallax_scale * parallax_depth;
    
    // Create distortion effect for more chaotic flow
    vec2 distortion_uv = (UV + parallax_offset) * noise_scale;
    distortion_uv.x -= TIME * secondary_flow_speed * 0.2;
    float distortion = texture(noise_texture2, distortion_uv).r * 2.0 - 1.0;

    // Apply distortion and parallax to main UV
    vec2 uv = UV + parallax_offset;
    uv.y -= TIME * flow_speed * 0.1;
    uv.x += distortion * distortion_strength;

    // Sample main noise for lava pattern
    float noise = texture(noise_texture, uv).r;

    // Create bubbling effect with parallax
    vec2 bubble_uv = (UV + parallax_offset * 1.5) * 3.0;
    bubble_uv.y -= TIME * bubble_speed;
    float bubble_noise = texture(noise_texture, bubble_uv).r;
    float bubbles = step(bubble_threshold, bubble_noise) * step(distance(fract(bubble_uv * 2.0), vec2(0.5)), bubble_size);

    // Create color gradient with three colors
    vec4 lava;
    if (noise < 0.4) {
        lava = mix(lava_color3, lava_color1, noise * 2.5);
    } else {
        lava = mix(lava_color1, lava_color2, (noise - 0.4) * 1.67);
    }

    // Add bubbles to lava color
    lava = mix(lava, vec4(1.0, 0.9, 0.6, 1.0), bubbles * 0.6);

    // Apply the colors
    ALBEDO = lava.rgb;

    // Add emission with variation based on noise
    EMISSION = lava.rgb * emission_strength * (0.8 + 0.4 * noise);

    // Add roughness variation
    ROUGHNESS = 0.3 + 0.2 * noise - 0.2 * bubbles;

    // Add slight metallic property to bubbles
    METALLIC = bubbles * 0.2;
}

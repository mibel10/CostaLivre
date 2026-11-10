shader_type spatial;

uniform bool extreme_surface = false;
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float a = sin(world_pos.x * 1.4 + TIME * 0.8 + sin(world_pos.z * 0.2));
    float b = sin(world_pos.z * 2.1 - TIME * 0.6 + a);
    vec2 slopes = vec2(a, b) * 0.08;
    ALBEDO = mix(vec3(0.025, 0.11, 0.14), vec3(0.08, 0.23, 0.25), a * 0.18 + 0.25);
    METALLIC = 0.35;
    ROUGHNESS = 0.18;
    if (extreme_surface) {
        vec2 surface = world_pos.xz;
        float ripple_a = sin(dot(surface, vec2(4.3, 2.7)) + TIME * 1.8 + a);
        float ripple_b = sin(dot(surface, vec2(-3.4, 5.1)) - TIME * 1.2 + b);
        float fine_detail = 1.0 - smoothstep(35.0, 150.0, length(VERTEX));
        slopes = slopes * 0.63 + vec2(ripple_a, ripple_b) * 0.035 * fine_detail;
        vec3 wave_normal = normalize((VIEW_MATRIX * vec4(slopes.x, 1.0, slopes.y, 0.0)).xyz);
        float fresnel = pow(1.0 - max(dot(wave_normal, VIEW), 0.0), 5.0);
        vec3 deep_water = mix(vec3(0.019, 0.09, 0.105), vec3(0.04, 0.21, 0.19), a * 0.24 + 0.35);
        ALBEDO = mix(deep_water, vec3(0.22, 0.36, 0.43), fresnel * 0.48);
        METALLIC = 0.5;
        ROUGHNESS = mix(0.15, 0.27, 1.0 - fine_detail);
    }
    NORMAL = normalize((VIEW_MATRIX * vec4(slopes.x, 1.0, slopes.y, 0.0)).xyz);
}

shader_type spatial;
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float a = sin(world_pos.x * 1.4 + TIME * 0.8 + sin(world_pos.z * 0.2));
    float b = sin(world_pos.z * 2.1 - TIME * 0.6 + a);
    NORMAL = normalize((VIEW_MATRIX * vec4(a * 0.08, 1.0, b * 0.08, 0.0)).xyz);
    ALBEDO = mix(vec3(0.025, 0.11, 0.14), vec3(0.08, 0.23, 0.25), a * 0.18 + 0.25);
    METALLIC = 0.35;
    ROUGHNESS = 0.18;
}

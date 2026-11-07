shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
void fragment() {
    vec3 image = texture(screen_texture, SCREEN_UV).rgb;
    float grey = dot(image, vec3(0.299, 0.587, 0.114));
    float vignette = smoothstep(0.2, 0.8, distance(UV, vec2(0.5)));
    COLOR = vec4(mix(image, vec3(grey) * vec3(0.7, 0.67, 0.65), strength) * (1.0 - vignette * strength * 0.7), 1.0);
}

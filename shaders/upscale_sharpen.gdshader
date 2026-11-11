shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec3 center = texture(screen_texture, SCREEN_UV).rgb;
	vec3 neighbors = texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb;
	neighbors += texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)).rgb;
	neighbors += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb;
	neighbors += texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)).rgb;
	vec3 sharpened = center + (center - neighbors * 0.25) * strength;
	COLOR = vec4(clamp(sharpened, vec3(0.0), vec3(1.0)), 1.0);
}

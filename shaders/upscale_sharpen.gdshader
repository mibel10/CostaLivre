shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec3 center = texture(screen_texture, SCREEN_UV).rgb;
	vec3 left = texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)).rgb;
	vec3 right = texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb;
	vec3 up = texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)).rgb;
	vec3 down = texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb;
	vec3 low = min(center, min(min(left, right), min(up, down)));
	vec3 high = max(center, max(max(left, right), max(up, down)));
	vec3 average = (left + right + up + down) * 0.25;
	float contrast = max(high.r - low.r, max(high.g - low.g, high.b - low.b));
	float edge_strength = strength * (1.0 - smoothstep(0.2, 0.7, contrast));
	vec3 sharpened = center + (center - average) * edge_strength;
	COLOR = vec4(clamp(sharpened, low, high), 1.0);
}

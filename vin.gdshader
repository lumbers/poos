shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv * vec2(1.0, 1.4));
	float vignette = smoothstep(0.25, 0.65, dist);
	COLOR = vec4(0.05, 0.0, 0.15, vignette * 0.15);
}
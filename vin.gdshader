shader_type canvas_item;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    float vignette = smoothstep(0.3, 0.7, dist);
    COLOR = vec4(0.0, 0.0, 0.0, vignette * 0.75);
}
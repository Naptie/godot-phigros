shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec3 darkened_color = texture_color.rgb * (1.0 - darkness);
    COLOR = vec4(darkened_color, texture_color.a);
}
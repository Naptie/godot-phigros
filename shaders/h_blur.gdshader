shader_type canvas_item;

uniform int kernel_size : hint_range(1, 160) = 5;
uniform float sigma : hint_range(0.1, 50.0) = 2.0;

float gaussian(int x, float sigmaa) {
    return exp(-float(x*x) / (2.0 * sigmaa * sigmaa));
}

void fragment() {
    vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
    vec2 uv = UV;
    vec3 color = vec3(0.0);
    float weight_sum = 0.0;

    for (int i = -kernel_size; i <= kernel_size; i++) {
        float weight = gaussian(i, sigma);
        vec2 offset = vec2(0.0, float(i)) / tex_size;
        color += texture(TEXTURE, uv + offset).rgb * weight;
        weight_sum += weight;
    }

    COLOR.rgb = color / weight_sum;
}

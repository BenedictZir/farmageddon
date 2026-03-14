shader_type canvas_item;

////////////////////////////////////
// OUTLINE UNIFORMS
////////////////////////////////////
uniform vec4 color : source_color = vec4(1.0);
uniform float width : hint_range(0, 10) = 1.0;
uniform int pattern : hint_range(0, 2) = 0;
uniform bool inside = false;
uniform bool add_margins = true;

////////////////////////////////////
// FLOATING SINE UNIFORMS
////////////////////////////////////
group_uniforms Sine;
uniform bool do_abs = false;
uniform bool do_quantize = false;
uniform float quantize_to : hint_range(0, 2, 0.1) = 1.0;
uniform vec2 sine_amplitude = vec2(1.0, 0.0);
uniform vec2 sine_speed = vec2(1.0, 0.0);

////////////////////////////////////
// VERTEX FUNCTION
////////////////////////////////////
void vertex() {
    // --- Floating motion first ---
    vec2 s = sin(TIME * sine_speed);
    if (do_abs) {
        s = abs(s);
    }
    vec2 float_offset = s * sine_amplitude;

    if (do_quantize) {
        float_offset = round(float_offset / quantize_to) * quantize_to;
    }

    VERTEX += float_offset;

    // --- Outline margin expansion ---
    if (add_margins) {
        VERTEX += (UV * 2.0 - 1.0) * width;
    }
}

////////////////////////////////////
// HELPER
////////////////////////////////////
bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, sampler2D texture) {
    for (float i = -ceil(width); i <= ceil(width); i++) {
        float x = abs(i) > width ? width * sign(i) : i;
        float offset;

        if (pattern == 0) {
            offset = width - abs(x);
        } else if (pattern == 1) {
            offset = floor(sqrt(pow(width + 0.5, 2.0) - x * x));
        } else if (pattern == 2) {
            offset = width;
        }

        for (float j = -ceil(offset); j <= ceil(offset); j++) {
            float y = abs(j) > offset ? offset * sign(j) : j;
            vec2 xy = uv + texture_pixel_size * vec2(x, y);

            if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(texture, xy).a <= 0.0) == inside) {
                return true;
            }
        }
    }

    return false;
}

////////////////////////////////////
// FRAGMENT
////////////////////////////////////
void fragment() {
    vec2 uv = UV;

    if (add_margins) {
        vec2 texture_pixel_size = vec2(1.0) /
        (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(width * 2.0));

        uv = (uv - texture_pixel_size * width) *
        TEXTURE_PIXEL_SIZE / texture_pixel_size;

        if (uv != clamp(uv, vec2(0.0), vec2(1.0))) {
            COLOR.a = 0.0;
        } else {
            COLOR = texture(TEXTURE, uv);
        }
    } else {
        COLOR = texture(TEXTURE, uv);
    }

    if ((COLOR.a > 0.0) == inside && hasContraryNeighbour(uv, TEXTURE_PIXEL_SIZE, TEXTURE)) {
        COLOR.rgb = inside ? mix(COLOR.rgb, color.rgb, color.a) : color.rgb;
        COLOR.a += (1.0 - COLOR.a) * color.a;
    }
}

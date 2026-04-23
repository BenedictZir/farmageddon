shader_type canvas_item;

// Spotlight overlay — darkens everything except a highlighted area.
// Supports rectangle and ellipse shapes, soft edges, and pixel coordinates.

uniform vec2 spotlight_center = vec2(0.5, 0.5);
uniform vec2 spotlight_size = vec2(0.0, 0.0);
uniform float edge_softness : hint_range(0.0, 0.5) = 0.03;
uniform float darkness : hint_range(0.0, 1.0) = 0.85;
uniform float shape : hint_range(0.0, 1.0) = 0.0; // 0 = rect, 1 = ellipse
uniform float corner_radius : hint_range(0.0, 0.5) = 0.02;
uniform vec2 screen_size = vec2(640.0, 360.0);
uniform bool use_pixels = true;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 uv = UV;
	vec2 center_uv;
	vec2 size_uv;

	if (use_pixels) {
		center_uv = spotlight_center / screen_size;
		size_uv = spotlight_size / screen_size;
	} else {
		center_uv = spotlight_center;
		size_uv = spotlight_size;
	}

	vec2 half_size = size_uv * 0.5;
	vec2 p = uv - center_uv;

	// Aspect correction for ellipse
	vec2 aspect = vec2(screen_size.x / screen_size.y, 1.0);

	float dist;
	if (shape > 0.5) {
		// Ellipse
		vec2 scaled_p = p * aspect;
		vec2 scaled_half = half_size * aspect;
		float ellipse_dist = length(scaled_p / max(scaled_half, vec2(0.0001))) - 1.0;
		float pixel_scale = length(scaled_half);
		dist = ellipse_dist * pixel_scale;
	} else {
		// Rounded rectangle
		vec2 scaled_p = p * aspect;
		vec2 scaled_half = half_size * aspect;
		float radius_px = corner_radius * min(scaled_half.x, scaled_half.y);
		dist = rounded_box_sdf(scaled_p, scaled_half, radius_px);
	}

	// Soft edge
	float softness = max(edge_softness, 0.001);
	float mask = smoothstep(-softness, softness, dist);

	COLOR = vec4(0.0, 0.0, 0.0, darkness * mask);
}

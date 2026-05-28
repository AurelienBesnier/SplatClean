shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque;

uniform float point_size : hint_range(0.0, 200.0, 0.1) = 10.0;
varying vec4 instance_color;

void vertex() {
    // Assign the base pixel size
    POINT_SIZE = point_size;
	// Get the instance's color
	instance_color = COLOR;
}

void fragment() {
    // Calculating distance from the center (0.5, 0.5) creates a perfect circle
    vec2 center_dist = POINT_COORD - vec2(0.5);
    if (dot(center_dist, center_dist) > 0.25) {
        discard;
    }
    
 	ALBEDO = instance_color.rgb;
    ALPHA = instance_color.a;
}
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float shininess = 0.24;

void fragment() {
	vec3 camera_dir = vec3(0.0, 0.0, 1.0);
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	if (!FRONT_FACING) {
		view_normal = -view_normal;
	}
	
	float diffuse = max(dot(view_normal, camera_dir), 0.0);
	float specular = pow(max(dot(view_normal, camera_dir), 0.0), shininess);
	vec3 final_color = (albedo.rgb * diffuse) + vec3(specular * 0.4);
	
	ALBEDO = final_color;
}
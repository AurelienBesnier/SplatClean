shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

varying vec2 v_conic;
varying vec3 v_color;
varying float v_opacity;

void vertex() {
	mat4 inst_matrix = MODEL_MATRIX;
	vec3 world_pos = inst_matrix[3].xyz;
	
	// Reconstruct the scaling matrix
	vec3 scale = vec3(length(inst_matrix[0].xyz), length(inst_matrix[1].xyz), length(inst_matrix[2].xyz));
	mat3 R = mat3(normalize(inst_matrix[0].xyz), normalize(inst_matrix[1].xyz), normalize(inst_matrix[2].xyz));
	mat3 S = mat3(vec3(scale.x, 0.0, 0.0), vec3(0.0, scale.y, 0.0), vec3(0.0, 0.0, scale.z));
	mat3 M = R * S;

	// Covariance matrix: Sigma = M * M^T
	mat3 sigma = M * transpose(M);

	vec4 cam_pos = VIEW_MATRIX * vec4(world_pos, 1.0);
	
	// Check if the splat in front of camera
	if (cam_pos.z < 0.0) {
		// Project 3D Covariance to 2D Screen Space
		float focal = PROJECTION_MATRIX[1][1] * (0.5 * VIEWPORT_SIZE.y); 
		float limx = 1.3 * VIEWPORT_SIZE.x / focal;
		float limy = 1.3 * VIEWPORT_SIZE.y / focal;
		float txtz = cam_pos.x / cam_pos.z;
		float tytz = cam_pos.y / cam_pos.z;
		
		txtz = clamp(txtz, -limx, limx) * cam_pos.z;
		tytz = clamp(tytz, -limy, limy) * cam_pos.z;

		// Jacobian matrix
		mat3 J = mat3(
			vec3(focal / cam_pos.z, 0.0, -(focal * txtz) / (cam_pos.z * cam_pos.z)),
			vec3(0.0, focal / cam_pos.z, -(focal * tytz) / (cam_pos.z * cam_pos.z)),
			vec3(0.0, 0.0, 0.0)
		);

		mat3 W = mat3(VIEW_MATRIX);
		mat3 T = J * W;
		mat3 cov2D = T * sigma * transpose(T);

		// Low-pass filter to handle tiny splats
		cov2D[0][0] += 0.3;
		cov2D[1][1] += 0.3;

		// Invert 2D Covariance to get the Ellipsoid Conic
		float det = cov2D[0][0] * cov2D[1][1] - cov2D[0][1] * cov2D[0][1];
		
		if (det != 0.0) {
			float det_inv = 1.0 / det;
			vec3 conic = vec3(cov2D[1][1] * det_inv, -cov2D[0][1] * det_inv, cov2D[0][0] * det_inv);

			// Find bounding box of the screen-space ellipse
			float mid = 0.5 * (cov2D[0][0] + cov2D[1][1]);
			float lambda1 = mid + sqrt(max(0.1, mid * mid - det));
			float lambda2 = mid - sqrt(max(0.1, mid * mid - det));
			float radius = ceil(3.0 * sqrt(max(lambda1, lambda2)));
			
			// Convert radius from screen pixels back to NDC / View Space offset
			vec2 screen_offset = VERTEX.xy * radius; 
			vec4 clip_pos = PROJECTION_MATRIX * cam_pos;
			clip_pos.xy += (screen_offset / VIEWPORT_SIZE) * clip_pos.w * 2.0;

			// Output projection
			POSITION = clip_pos;

			// Pass variables to fragment shader
			v_conic = conic.xy;
			v_conic.y = conic.y;
			v_color = COLOR.rgb;
			v_opacity = COLOR.a;
			UV = screen_offset; 
		} else {
			// Collapse geometry if determinant is zero
			VERTEX = vec3(0.0);
		}
	} else {
		// Collapse geometry if behind camera
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// Reconstruct exact distance based on the Projected Ellipse Conic
	float d = -0.5 * (v_conic.x * UV.x * UV.x + 2.0 * v_conic.y * UV.x * UV.y + v_conic.y * UV.y * UV.y);
	
	if (d > 0.0) {
		discard;
	}
	
	float alpha = exp(d) * v_opacity;
	if (alpha < 0.05) {
		discard;
	}

	ALBEDO = v_color;
	ALPHA = alpha;
}
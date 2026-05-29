shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

varying vec3 v_conic;
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
	
	float near_plane_limit = -0.1; 
	
	// Check if the splat in front of camera
	if (cam_pos.z < near_plane_limit) {
		float abs_z = abs(cam_pos.z);
		
		float focal_x = PROJECTION_MATRIX[0][0] * (0.5 * VIEWPORT_SIZE.x);
		float focal_y = PROJECTION_MATRIX[1][1] * (0.5 * VIEWPORT_SIZE.y); 
		
		float txtz = cam_pos.x / abs_z;
		float tytz = cam_pos.y / abs_z;

		// Jacobian matrix
		mat3 J = mat3(
			vec3(focal_x / abs_z, 0.0, 0.0),
			vec3(0.0, focal_y / abs_z, 0.0),
			vec3(-(focal_x * txtz) / abs_z, -(focal_y * tytz) / abs_z, 0.0)
		);

		mat3 W = mat3(VIEW_MATRIX);
		mat3 T = J * W;
		mat3 cov2D = T * sigma * transpose(T);

		// Low-pass filter to handle tiny splats
		cov2D[0][0] += 0.3;
		cov2D[1][1] += 0.3;

		// Invert 2D Covariance to get the Ellipsoid Conic
		float det = cov2D[0][0] * cov2D[1][1] - cov2D[0][1] * cov2D[0][1];
		
		if (det > 0.0001) {
			float det_inv = 1.0 / det;
			vec3 conic = vec3(cov2D[1][1] * det_inv, -cov2D[0][1] * det_inv, cov2D[0][0] * det_inv);

			// Find bounding box of the screen-space ellipse
			float mid = 0.5 * (cov2D[0][0] + cov2D[1][1]);
			float term = sqrt(max(0.1, mid * mid - det));
			float lambda1 = mid + term;
			float lambda2 = mid - term;
			
			float radius = ceil(3.0 * sqrt(max(lambda1, lambda2)));
			radius = min(radius, max(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y)); 
			
			// Convert radius from screen pixels back to NDC / View Space offset
			vec2 screen_offset = VERTEX.xy * radius; 
			vec4 clip_pos = PROJECTION_MATRIX * cam_pos;
			
			clip_pos.xy += (screen_offset / VIEWPORT_SIZE) * clip_pos.w * 2.0;

			POSITION = clip_pos;

			// Pass variables to fragment shader
			v_conic = conic; 
			v_color = COLOR.rgb;
			v_opacity = COLOR.a;
			UV = screen_offset; 
		} else {
			POSITION = vec4(0.0);
		}
	} else {
		// Instantly throw away vertices that bypass the near plane
		POSITION = vec4(0.0);
	}
}

void fragment() {
	// --- TWEAK PARAMETERS ---
	// Increase density to make the splat core thicker/more opaque (e.g., 1.5 to 3.0)
	float density_multiplier = 1.5; 
	// Drop the falloff power slightly if you want the edges to be less blurry (e.g., 0.5 to 0.8)
	float falloff_sharpness = 1.0; 
	// ------------------------
	// Reconstruct the 2D Gaussian ellipse distance matrix
	float d = -0.5 * (v_conic.x * UV.x * UV.x + 2.0 * v_conic.y * UV.x * UV.y + v_conic.z * UV.y * UV.y);
	
	if (d > 0.0) {
		discard;
	}
	
	// Apply the sharpness adjustment to the mathematical falloff
	float gaussian_falloff = exp(d * falloff_sharpness);
	
	// Multiply by opacity and density multiplier, then clamp to standard 0.0-1.0 range
	float alpha = clamp(gaussian_falloff * v_opacity * density_multiplier, 0.0, 1.0);
	
	// Lower cutoff allows softer edges to stay visible, higher cuts off early
	if (alpha < 0.2) {
		discard;
	}

	ALBEDO = v_color;
	ALPHA = alpha;
}
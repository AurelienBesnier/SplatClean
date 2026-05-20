shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform vec4 wire_color : source_color = vec4(0.0, 1.0, 0.0, 1.0); 
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 0.1); // Semi-transparent black
uniform float wire_width : hint_range(1.0, 4.0) = 1.0;

varying vec3 v_barycentric;

void vertex() {
    int index = VERTEX_ID % 3;
    if (index == 0) v_barycentric = vec3(1.0, 0.0, 0.0);
    else if (index == 1) v_barycentric = vec3(0.0, 1.0, 0.0);
    else v_barycentric = vec3(0.0, 0.0, 1.0);
}

void fragment() {
    vec3 d = fwidth(v_barycentric);
    vec3 a3 = smoothstep(vec3(0.0), d * wire_width, v_barycentric);
    float edge_factor = min(min(a3.x, a3.y), a3.z);
    vec4 final_color = mix(wire_color, base_color, edge_factor);
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}
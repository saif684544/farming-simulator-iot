shader_type spatial;

// Irrigation pipe. When `flow` > 0, glowing pulses travel along the pipe axis
// (local +Y of the cylinder) to visualise water flow.
uniform vec3 pipe_color : source_color = vec3(0.13, 0.32, 0.52);
uniform vec3 flow_color : source_color = vec3(0.25, 0.75, 1.0);
uniform float flow : hint_range(0.0, 1.0) = 0.0;
uniform float flow_speed = 1.6;

varying float axis_pos;

void vertex() {
	axis_pos = VERTEX.y;
}

void fragment() {
	float stripe = smoothstep(0.55, 0.8, fract(axis_pos * 1.1 - TIME * flow_speed));
	ALBEDO = mix(pipe_color, flow_color * 0.6, stripe * flow * 0.5);
	METALLIC = 0.55;
	ROUGHNESS = 0.32;
	EMISSION = flow_color * stripe * flow * 1.8;
}

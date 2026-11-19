shader_type spatial;
render_mode cull_disabled;

// Wind-swayed grass blades for MultiMesh clumps. UV.y = 0 at the root, 1 at the tip.
uniform vec3 base_color : source_color = vec3(0.22, 0.32, 0.11);
uniform vec3 tip_color : source_color = vec3(0.42, 0.54, 0.20);
uniform vec3 dry_color : source_color = vec3(0.60, 0.58, 0.30);
uniform float sway = 0.12;

varying float blade_h;
varying vec3 world_pos;

void vertex() {
	blade_h = UV.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h2 = blade_h * blade_h;
	float w = sin(TIME * 1.8 + world_pos.x * 0.35 + world_pos.z * 0.25) + 0.5 * sin(TIME * 3.1 + world_pos.x * 0.9);
	VERTEX.x += w * sway * h2;
	VERTEX.z += cos(TIME * 1.4 + world_pos.z * 0.3) * sway * 0.5 * h2;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float patch = sin(world_pos.x * 0.13) * sin(world_pos.z * 0.11) * 0.5 + 0.5;
	vec3 tip = mix(tip_color, dry_color, patch * 0.4);
	ALBEDO = mix(base_color, tip, blade_h);
	// Both faces lit like an upward-facing surface (avoids black back faces).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.82;
	SPECULAR = 0.2;
}

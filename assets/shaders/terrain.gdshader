shader_type spatial;

// Terrain: vertex colours carry the base biome tint, a tiling noise texture adds
// world-space breakup so the large mesh never looks flat-shaded.
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.045;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, world_pos.xz * detail_scale).r;
	float n2 = texture(noise_tex, world_pos.xz * detail_scale * 5.7 + vec2(0.37, 0.71)).r;
	vec3 c = COLOR.rgb * (0.72 + 0.42 * n) * (0.88 + 0.24 * n2);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.22;
}

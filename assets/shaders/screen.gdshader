shader_type spatial;
render_mode unshaded;

// Animated "dashboard" display used on the IoT control station monitors.
uniform vec3 bg : source_color = vec3(0.02, 0.06, 0.11);
uniform vec3 accent : source_color = vec3(0.10, 0.62, 1.0);
uniform vec3 accent2 : source_color = vec3(0.24, 0.86, 0.52);
uniform float brightness = 1.0;

void fragment() {
	vec2 uv = UV;
	vec3 c = bg;
	// header strip
	c = mix(c, accent * 0.55, step(uv.y, 0.12));
	// grid lines
	vec2 g = abs(fract(uv * vec2(10.0, 6.0)) - 0.5);
	c += accent * 0.05 * step(0.47, max(g.x, g.y));
	// animated bar chart on the left half
	if (uv.x < 0.55 && uv.y > 0.2) {
		float col = floor(uv.x * 14.0);
		float h = 0.3 + 0.35 * fract(sin(col * 12.9898) * 43758.5) + 0.12 * sin(TIME * 0.9 + col);
		float inbar = step(1.0 - uv.y, h * 0.75) * step(0.2, fract(uv.x * 14.0));
		c = mix(c, accent, inbar * 0.85);
	}
	// sine "sensor trace" on the right half
	if (uv.x > 0.6 && uv.y > 0.2) {
		float w = 0.6 + 0.15 * sin(uv.x * 25.0 + TIME * 2.0) + 0.05 * sin(uv.x * 63.0 - TIME * 3.0);
		c += accent2 * smoothstep(0.02, 0.0, abs(uv.y - w));
	}
	ALBEDO = c * brightness;
}

shader_type sky;

// Lightweight gradient sky with sun/moon disc and night stars.
// Driven entirely by uniforms from DayNightController so it works on the
// Compatibility renderer (PC, mobile and web).
uniform vec3 top_color : source_color = vec3(0.22, 0.45, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.25, 0.27, 0.25);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float sun_size = 0.9995;
uniform float sun_glow = 0.35;
uniform float star_intensity = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	float y = EYEDIR.y;
	vec3 col;
	if (y > 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(y, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, pow(clamp(-y * 3.0, 0.0, 1.0), 0.5));
	}
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		float disc = smoothstep(sun_size, sun_size + 0.0003, d);
		float glow = pow(max(d, 0.0), 64.0) * sun_glow + pow(max(d, 0.0), 6.0) * sun_glow * 0.25;
		col += sun_color * (disc * 6.0 + glow);
	}
	if (!AT_CUBEMAP_PASS && star_intensity > 0.0 && y > 0.0) {
		vec3 cell = floor(EYEDIR * 260.0);
		float s = hash(cell);
		float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + s * 50.0);
		col += vec3(step(0.9965, s) * star_intensity * twinkle * smoothstep(0.0, 0.25, y));
	}
	COLOR = col;
}

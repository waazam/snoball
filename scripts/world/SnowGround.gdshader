// Arena snow ground (ART_DIRECTION.md 6a/7): albedo comes straight from
// Terrain.gd's baked vertex colors (lit snow / blue shadow / alpenglow),
// plus a sparse, twinkling hash-cell sparkle near the camera - the cold
// "glitter" fresh snow has at dusk. No screen reads, web-export safe.
shader_type spatial;

uniform float sparkle_density : hint_range(0.0, 0.1) = 0.02;
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.3;

varying vec3 wpos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	vec2 cell = floor(wpos.xz * 12.0);
	float h = hash21(cell);
	float glint = step(1.0 - sparkle_density, h);
	float twinkle = 0.5 + 0.5 * sin(TIME * 2.5 + h * 87.0);
	float near_fade = clamp(1.0 - length(wpos.xz - CAMERA_POSITION_WORLD.xz) * 0.025, 0.0, 1.0);
	EMISSION = vec3(0.85, 0.92, 1.0) * glint * twinkle * near_fade * sparkle_strength;
}

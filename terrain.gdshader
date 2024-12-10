shader_type spatial;

uniform float min_height;
uniform float max_height;

varying vec3 pos;

void vertex() {
	pos = VERTEX;
}

void fragment() {
	float height_percent = smoothstep(min_height, max_height, pos.y);
	ALBEDO = height_percent * vec3(1.0);
}

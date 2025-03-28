shader_type spatial;

uniform sampler2D _a;
uniform sampler2D heightmap;
uniform float height_ratio = 0.3;

void vertex() {
	// Called for every vertex the material is visible on.
	float height = texture(heightmap, UV).r;
	VERTEX.y += height * height_ratio;
}

void fragment() {
	ALBEDO = texture(_a, UV*5.0).rgb;
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

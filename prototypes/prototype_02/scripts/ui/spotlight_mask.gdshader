shader_type canvas_item;
render_mode unshaded;
uniform vec2 focus;
uniform vec2 radii;
uniform float strength;
uniform vec4 dim_color : source_color;
uniform float far_distance;
uniform float feather_size;

void vertex() {
	vec2 direction = VERTEX / far_distance;
	vec2 radius = UV.x < 0.5 ? radii : (UV.x < 1.5 ? radii + vec2(feather_size) : vec2(far_distance));
	VERTEX = focus + direction * radius;
}

void fragment() {
	COLOR = vec4(dim_color.rgb, dim_color.a * strength * COLOR.a);
}

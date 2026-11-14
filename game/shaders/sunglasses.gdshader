shader_type canvas_item;
// Wild-type "sunglasses": removes bug-to-background contrast (information), so brightness cannot undo it.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float handicap : hint_range(0.0, 1.0) = 0.6;
uniform vec3 dim_grey = vec3(0.30, 0.34, 0.27);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma), handicap * 0.6);
	c = mix(c, dim_grey, handicap);
	COLOR = vec4(c, 1.0);
}

shader_type spatial;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float model_height = 2.;
uniform float dissolve_start : hint_range(.0, 1.) = .0;
uniform float dissolve_length : hint_range(.0, 1.) = 1.;
uniform float gradient_bias : hint_range(.1, 5.) = 1.;
varying float vert_height;

void vertex() 
{
	vert_height = (VERTEX.y + (model_height / 2.)) / model_height;
}

void fragment() 
{
	float gradient_height = vert_height - dissolve_start;
	gradient_height *= 1. / (dissolve_length);
	gradient_height = clamp(pow(gradient_height, gradient_bias), 0., 1.);
	
	ALBEDO = vec3(0.0,0.0,0.0);
	ALPHA = mix(1.,.9,gradient_height);
}
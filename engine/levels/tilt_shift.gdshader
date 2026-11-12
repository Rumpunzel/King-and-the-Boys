// Tilt-shift: blurs the top and bottom of the screen and keeps a band through its middle sharp, like a photo of a miniature.
// Unlike depth of field it goes by screen height, so tall things near the focus (arches over the player) stay sharp
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Middle of the sharp band (the camera centres on the player's figure), as a share of the screen's height from the top
uniform float focus_center : hint_range(0.0, 1.0) = 0.5;
// Half the height of the sharp band
uniform float focus_size : hint_range(0.0, 0.5) = 0.2;
// How far beyond the band the blur takes to reach its full strength
uniform float blur_falloff : hint_range(0.01, 0.5) = 0.3;
// The full blur, as a mipmap level of the screen
uniform float max_blur : hint_range(0.0, 6.0) = 2.5;

void fragment() {
	float away = abs(SCREEN_UV.y - focus_center);
	float blur = smoothstep(focus_size, focus_size + blur_falloff, away);
	COLOR = textureLod(screen_texture, SCREEN_UV, blur * max_blur);
}

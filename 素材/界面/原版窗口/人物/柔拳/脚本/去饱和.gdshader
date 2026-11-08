shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.0; // 0.0=全灰，1.0=原色

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(gray), color.rgb, saturation);
	COLOR = color;
}
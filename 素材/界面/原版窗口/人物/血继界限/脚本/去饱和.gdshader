// 去饱和（灰度）滤镜 —— 血继界限页专用副本
// 与「柔拳」目录下的同名 shader 功能一致，独立一份是为了避免 UID 冲突。
shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.0; // 0.0=全灰，1.0=原色

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(gray), color.rgb, saturation);
	COLOR = color;
}
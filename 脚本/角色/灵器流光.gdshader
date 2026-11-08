shader_type canvas_item;
render_mode blend_add;

// 斜向流光：原版是 `lingQiSweep`（-38° 的渐变矩形）**被人物剪影遮罩**。
// 这里直接在当前帧的人物贴图上算光带 ⇒ 等效于"只留在人物身上"。
// 速度/区间照 `updateLingQiEffectMotion`：每毫秒 0.06px，
// minX = -带宽 - 宽*0.25，maxX = 宽 + 带宽*0.65；带宽 = max(10, 宽*0.42)。
uniform float phase = 0.0;      // 0..1，GDScript 按上面的区间归一化后推进
uniform vec2 sprite_size = vec2(100.0, 100.0);
uniform float strength = 0.38;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 p = UV * sprite_size;
	// 屏幕坐标下的 -38°：沿 (cos38, sin38) 方向推进。
	float along = p.x * 0.78801075 + p.y * 0.61566148;
	float band = max(10.0, sprite_size.x * 0.42);
	float start = -band - sprite_size.x * 0.25 + phase * (sprite_size.x + band * 1.65);
	float t = clamp((along - start) / band, 0.0, 1.0);
	// 原版渐变 [白 0, #FFF7CC 0.92, #FFC1AB 0.58, #FF8F00 0]。
	vec3 color = mix(vec3(1.0, 0.972, 0.8), vec3(1.0, 0.56, 0.0), t);
	float edge = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.65, 1.0, t));
	COLOR = vec4(color, base.a * edge * strength);
}

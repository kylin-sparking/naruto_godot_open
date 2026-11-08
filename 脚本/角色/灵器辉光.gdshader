shader_type canvas_item;
render_mode blend_add;

// 外发辉光：原版 `GlowFilter ×2 + BlurFilter`（`CharacterSprite.updateLingQiEffectMotion`
// 里那两枚 16763858 / 16746632 的 GlowFilter）。这里用 3×3 采样做柔光，
// 颜色取暖橙白，透明度与半径由 GDScript 按 `0.12 + cos*0.26` / `18+sin*10` 喂进来。
uniform float blur_radius = 2.0;
uniform float glow_alpha = 0.28;
uniform vec3 glow_color = vec3(1.0, 0.86, 0.72);

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_radius;
	float a = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			a += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a;
		}
	}
	a /= 9.0;
	COLOR = vec4(glow_color, a * glow_alpha);
}

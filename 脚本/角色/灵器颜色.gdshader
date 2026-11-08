shader_type canvas_item;

// 十拳剑灵器外观的 ColorTransform。原版 `CharacterSprite.getLingQiColorTransform`：
//   new ColorTransform(redMul, greenMul, blueMul, 1, redOffset, greenOffset, blueOffset, 0)
// ⇒ 乘 + 加，offset 是 -255..255 的整数（这里由 GDScript 先除 255）。
// alpha 不看颜色表的 alphaMul（原版第 4 参硬写 1）；基色 alpha 0.7 来自
// `reanderLingQi` 的 `ciAfterImage.alpha = 0.7`，呼吸明暗再在外部乘 modulate.a。
uniform vec3 tint_mul = vec3(1.0);
uniform vec3 tint_add = vec3(0.0);
uniform float base_alpha = 0.7;

void fragment() {
	// ⚠ 这里**不能再 `texture()` 一遍再整个替换 COLOR**：Godot 4 的 canvas_item
	// 在进入 fragment 时 COLOR 已经是「贴图 × 顶点色（含 modulate/self_modulate）」。
	// 覆盖它会把 GDScript 设的 self_modulate.a（原版 0.7 / 呼吸 0.54..0.74）丢掉，
	// 须佐那套大图就变成不透明地盖住人物 —— 实测现象就是「人物被换成了须佐能乎」。
	// 只把颜色变换折进 rgb，alpha 保持输入值，再乘 base_alpha（当前为 1）。
	COLOR.rgb = clamp(COLOR.rgb * tint_mul + tint_add, vec3(0.0), vec3(1.0));
	COLOR.a *= base_alpha;
}

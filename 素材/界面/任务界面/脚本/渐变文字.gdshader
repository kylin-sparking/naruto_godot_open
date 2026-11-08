shader_type canvas_item;

// 原版 GradientTextField（任务追踪栏的两个页签文字）= 一个竖向渐变矩形被文字裁出来：
//   _colors = [0xFDF570, 0xFF9C43]，_ratios = [0,255]，_alphas = [1,1]
//   createGradientBox(宽 54, 高 textHeight+4=19, PI/2)   → 自上而下的线性渐变
//   _display.mask = textField                            → 只有笔画里有颜色
//   filters = MButton3.getGlowFilter()                   → 黑色外发光（工程里用 outline_size 近似）
//
// Godot 没有「渐变遮罩文字」，但 Label/Button 的 canvas_item 着色器能拿到每个像素：
// 正文像素进来时 COLOR.rgb 是字体色（这里设成白），描边像素进来时是描边色（黑）。
// 于是按亮度就能把两者分开 —— 渐变只染正文，黑描边保持纯黑。
//
// gray_amount = MButton3.updateState() 在 STATE_DISABLED 时推的 StyleUtil.getGrayFilter()。
// 原版 QuestTrackerWindow.setCurrentBtn() 是**把选中的那一页 enabled=false**，
// 所以「当前页」看到的是灰化后的渐变，而不是 selectedUpSkin 的 #ECEC4C→#B3B333
// （那对颜色在本窗口里从没被显示过 —— _selected 全程是 false）。
//
// 悬停 +30/255、按下 -40/255 是 StyleUtil.skinFilters 的加亮，
// 用 CanvasItem.self_modulate 的等比缩放近似（1.117 / 0.843），
// 乘法还有个好处：黑描边不会被一起提亮。
//
// 注：GDScript 允许中文标识符，GLSL 编译器不允许 —— 这个文件里的标识符必须保持 ASCII。
//
// ⚠ fragment() 里的 VERTEX 是**变换之后**的位置（≈ 视口坐标），不是控件局部坐标。
// 实测（开发工具/量页签渐变.gd）：同一个 19px 渐变带贴在 y=3 的按钮上还有渐变，
// 贴在 y=200 的按钮上就整片顶到末端色 —— 因为 VERTEX.y=203 早就被 clamp 成 1。
// 小地图面板的页签全局 y≈177，所以之前渲出来的是一整片 #FF9C43（原版是黄→橙的渐变）。
// 原版的渐变盒是 createGradientBox(宽, textHeight+4, PI/2)（GradientTextField.as:178/193），
// 锚在皮肤自己的 (0,0) → 必须用**顶点阶段的局部 y**，故下面在 vertex() 里取出来传进 varying。

uniform vec4 top_color : source_color = vec4(0.99216, 0.96078, 0.43922, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.61176, 0.26275, 1.0);
uniform float gradient_height : hint_range(1.0, 200.0) = 19.0;
uniform float gray_amount : hint_range(0.0, 1.0) = 0.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	// 黑（outline_size 那一路）不参与渐变染色
	float is_fill = step(0.25, max(max(COLOR.r, COLOR.g), COLOR.b));
	vec3 grad = mix(top_color.rgb, bottom_color.rgb, clamp(local_y / gradient_height, 0.0, 1.0));
	vec3 c = mix(COLOR.rgb, clamp(grad, 0.0, 1.0), is_fill);
	float lum = dot(c, vec3(0.3086, 0.6094, 0.082));
	COLOR = vec4(mix(c, vec3(lum), gray_amount), COLOR.a);
}

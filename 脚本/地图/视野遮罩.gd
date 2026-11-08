extends CanvasLayer
## 蜡烛视野遮罩 —— 原始实现在 `World.tickCandleEffect():445-470` + `MapCandleEffect.as`。
##
## 原版只在 `API.map.data.id == 403000000`（命运的抉择）时建一个 `MapCandleEffect`，
## 每帧拿 `player.localToGlobal(new Point())` 当圆心、`y - 60` 当抬高（`World.as:461`），
## 然后 `updateEffect()` 在同一份 `graphics` 里画两笔：
##   ① `beginFill(0)` + `drawRect(0,0,STAGE_WIDTH,SCREEN_HEIGHT)` + `drawCircle(cx,cy,250)`
##      —— 整舞台一块黑，**挖掉** r=250 的圆洞（两块子路径反向绕，圆内填充为 0）；
##   ② 同一个圆心上 `beginGradientFill(RADIAL, [0,0,0,0], [0,0.8,0.9,1], [0,60,70,80], 平移矩阵)`
##      + `drawCircle(cx,cy,250)` —— 圆心全透、往外压黑。
##
## ⚠ 渐变**比值**是 Flash 的 0..255 标度、渐变框是**单位矩阵**（`createGradientBox` 的
##   分母 1638.4 ⇒ 单位矩阵下框宽 1638.4、径向半径 819.2）。所以第一笔的 r=250 与
##   渐变的 `80/255` 落在 `819.2×80/255 = 257.0` —— **几乎正好在圆洞边上收满黑**，
##   这就是作者挑 60/70/80 这三个比值的原因（不是 r=60/70/80 像素）。按像素直读会把
##   可见圈压成 80px 的针孔，整张图黑到看不见路。
##   逐段线性与 `beginGradientFill` 的插值同口径：0→192.75 走 0→0.8、192.75→224.88 走
##   0.8→0.9、224.88→257.0 走 0.9→1.0，再往外一律 1.0。
##
## 端口用一层屏幕空间的 `ColorRect` + 一段 canvas 着色器复刻（逐段线性）。层级 12：
## 天气 10 之上、HUD 20 之下，与原版"`addChild` 到 World 末尾 ⇒ 盖住地图和角色、盖不住 HUD"一致。
## ⚠ 着色器里的标识符**必须是 ASCII**（GLSL 不认 `圆心`），中文只许出现在 GDScript 这一侧。
##
## 由 `地图根节点._挂视野遮罩()` 按地图号用代码建（174 张烘焙场景里没有这个节点）。

const 层级 := 12
## `World.tickCandleEffect():461` 的 `y - 60`。
const 圆心抬高 := 60.0
## `MapCandleEffect.RANGE_WIDTH`：圆洞半径（也是渐变圆的半径）。
const 原版半径 := 250.0
## Flash 单位矩阵下径向渐变的半径（`createGradientBox` 把 width 除以 1638.4 ⇒ 框宽 1638.4）。
const 渐变半径 := 819.2
## `beginGradientFill` 的 `ratios = [0,60,70,80]` / 255，折算成像素半径。
const 比值 := [0.0, 60.0 / 255.0, 70.0 / 255.0, 80.0 / 255.0]
## `alphas = [0,0.8,0.9,1]`。
const 透明度 := [0.0, 0.8, 0.9, 1.0]
## 三档渐变的像素半径（供着色器 uniform 与门逐条钉）。
static func 渐停(档: int) -> float:
	return 渐变半径 * float(比值[档])

const 着色器 := """
shader_type canvas_item;

uniform vec2 center = vec2(0.0);
uniform float stop1 = 192.7529;
uniform float stop2 = 224.8784;
uniform float stop3 = 257.0031;

void fragment() {
	float d = distance(FRAGCOORD.xy, center);
	float alpha = 1.0;
	if (d <= stop1) {
		alpha = 0.8 * d / stop1;
	} else if (d <= stop2) {
		alpha = mix(0.8, 0.9, (d - stop1) / (stop2 - stop1));
	} else if (d <= stop3) {
		alpha = mix(0.9, 1.0, (d - stop2) / (stop3 - stop2));
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""

var _遮罩: ColorRect
var _材质: ShaderMaterial

func _ready() -> void:
	layer = 层级
	_材质 = ShaderMaterial.new()
	var 片 := Shader.new()
	片.code = 着色器
	_材质.shader = 片
	_材质.set_shader_parameter("stop1", 渐停(1))
	_材质.set_shader_parameter("stop2", 渐停(2))
	_材质.set_shader_parameter("stop3", 渐停(3))
	_遮罩 = ColorRect.new()
	_遮罩.name = "屏幕遮罩"
	_遮罩.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_遮罩.set_anchors_preset(Control.PRESET_FULL_RECT)
	_遮罩.material = _材质
	add_child(_遮罩)

func _process(_delta: float) -> void:
	var 玩家 := get_tree().get_first_node_in_group("player") as Node2D
	if 玩家 == null:
		return
	var 屏幕 := 玩家.get_global_transform_with_canvas().origin
	_材质.set_shader_parameter("center", Vector2(屏幕.x, 屏幕.y - 圆心抬高))

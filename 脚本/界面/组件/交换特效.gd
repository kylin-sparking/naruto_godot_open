extends Control
## 变身卡交换演出里那层**程序化特效**（原版 `UIMain2.as:2014-2073` 的 `_swapEffectLayer`）。
##
## ⚠️ **这不是 SWF 动画，是代码画的** —— `drawLightning`（`:2014-2032`）在两点之间按
## `t = i / 段数` 插值、每段叠 `(Math.random()-0.5)` 的横向 `±抖动*0.3` / 纵向 `±抖动*2`，
## 外层 `onSwapAnimTick` 在进度 `p < 0.85` 时叠 **5 道**闪电 + A/B 两点上 r=52 / r=60 的两对脉动圆。
##
## ⚠️ 因为用 `randf()` ⇒ **逐像素对照在原理上不成立**，只能结构验证（层里有件、按进度画/停）。
## 画布原点：挂在场景的 `特效层`（它在 AS3 原点 (0,0) 上）⇒ 直接用 AS3 的绝对坐标 (150,230)/(320,230)。

var 进度 := 0.0


func _process(_delta: float) -> void:
	queue_redraw()			# 原版每个 tick 也重画一遍（`:2048` 先 clear）


func _draw() -> void:
	if 进度 >= 0.85:
		return
	# 五道闪电：参数逐条照 `:2055-2059`（段数 / 抖动 / 色 / α / 线宽）
	折线(Vector2(150, 230), Vector2(320, 230), 12, 18, Color(16777215), 0.95, 3.0)
	折线(Vector2(150, 230), Vector2(320, 230), 14, 24, Color(16307455), 0.85, 2.0)
	折线(Vector2(150, 230), Vector2(320, 230), 16, 30, Color(13395711), 0.75, 1.5)
	折线(Vector2(150, 230), Vector2(320, 230), 18, 36, Color(10040319), 0.6, 1.5)
	折线(Vector2(150, 230), Vector2(320, 230), 12, 22, Color(16777215), 0.85, 2.0)
	# 两对脉动圆（`:2060-2063`）：α 随 `sin(p*π*8)` 起伏
	var 波 := sin(进度 * PI * 8.0)
	圈(Vector2(150, 230), 52.0, Color(13395711), 0.5 + 0.4 * 波, 2.0)
	圈(Vector2(320, 230), 52.0, Color(13395711), 0.5 + 0.4 * 波, 2.0)
	var 波2 := sin(进度 * PI * 8.0 + PI / 2.0)
	圈(Vector2(150, 230), 60.0, Color(10040319), 0.4 + 0.3 * 波2, 1.0)
	圈(Vector2(320, 230), 60.0, Color(10040319), 0.4 + 0.3 * 波2, 1.0)


## = `drawLightning`（`:2014-2032`）逐行等价。
func 折线(起: Vector2, 止: Vector2, 段数: int, 抖动: float, 色: Color, 透明: float, 线宽: float) -> void:
	var 点 := PackedVector2Array()
	点.append(起)
	for i in range(1, 段数):
		var t := float(i) / float(段数)
		点.append(Vector2(
				起.x + (止.x - 起.x) * t + (randf() - 0.5) * 抖动 * 0.3,
				起.y + (止.y - 起.y) * t + (randf() - 0.5) * 抖动 * 2.0))
	点.append(止)
	draw_polyline(点, Color(色.r, 色.g, 色.b, 透明), 线宽)


func 圈(心: Vector2, 半径: float, 色: Color, 透明: float, 线宽: float) -> void:
	draw_arc(心, 半径, 0.0, TAU, 64, Color(色.r, 色.g, 色.b, 透明), 线宽)

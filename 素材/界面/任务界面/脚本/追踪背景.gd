extends Control

## 原版 QuestTrackerWindow.drawTrackerBg()（QuestTrackerWindow.as:405-418）逐行照搬：
##
##   graphics.beginGradientFill(LINEAR, [4801347,4801347], [0.8,0], [0,255],
##                              createGradientBox(width,height,PI/2,0,0), REFLECT)
##   graphics.drawRoundRect(0,0,width,height,10)
##
## 两个坑：
##  1. Flash 的 drawRoundRect 第 3 参是**椭圆直径**，不是半径 → 圆角半径 = 5。
##  2. 两端同色（#494343），只有 alpha 从 0.8 渐变到 0，方向 PI/2 = 自上而下。
##     REFLECT 在这里不起作用：渐变盒正好铺满整块，取不到盒外。
##
## Godot 没有「带 alpha 渐变的圆角矩形」这一条绘制指令，用一条逐行多边形带表示：
## 每一行按圆角方程算左右内缩，两个顶点分别着色 → 顶点色插值就是线性渐变，一次 draw_polygon。

const 底色 := Color8(0x49, 0x43, 0x43)
const 顶端透明度 := 0.8
const 圆角直径 := 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 1.0:
		return
	var r := 圆角直径 * 0.5
	var 左边: Array[Vector2] = []
	var 右边: Array[Vector2] = []
	var 色: Array[Color] = []
	var y := 0.5
	while y < h:
		var 内 := _内缩(y, h, r)
		左边.append(Vector2(内, y))
		右边.append(Vector2(w - 内, y))
		色.append(Color(底色.r, 底色.g, 底色.b, 顶端透明度 * (1.0 - y / h)))
		y += 1.0
	# 轮廓 = 左边自上而下 + 右边自下而上。每行左右两点同一条扫描线、同一个颜色，
	# 于是顶点色插值只剩纵向分量 = 原版那条 LINEAR + PI/2 的 alpha 渐变。
	var 点 := PackedVector2Array()
	var 彩 := PackedColorArray()
	for k in 左边.size():
		点.append(左边[k])
		彩.append(色[k])
	var i := 右边.size() - 1
	while i >= 0:
		点.append(右边[i])
		彩.append(色[i])
		i -= 1
	draw_polygon(点, 彩)

## 圆角矩形在第 y 行处的左右内缩量（Flash 的圆角是 1/4 圆弧）
func _内缩(y: float, h: float, r: float) -> float:
	var dy := 0.0
	if y < r:
		dy = r - y
	elif y > h - r:
		dy = y - (h - r)
	else:
		return 0.0
	var v := r * r - dy * dy
	if v <= 0.0:
		return r
	return r - sqrt(v)

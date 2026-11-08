extends Control
## 音量条上的圆形滑块 —— 原版是 `graphics.drawCircle(0, 25, 7)` 画的实心圆（SCW:301-304），
## 不是皮肤，所以这里照字面自绘，不另找图。圆心落在本控件中心 ⇒ 摆放时把框写成 (−7, 18, 14, 14)。

@export var 半径 := 7.0:
	set(v):
		半径 = v
		queue_redraw()
@export var 颜色 := Color(1, 0.8, 0, 1):
	set(v):
		颜色 = v
		queue_redraw()


func _draw() -> void:
	draw_circle(size * 0.5, 半径, 颜色)

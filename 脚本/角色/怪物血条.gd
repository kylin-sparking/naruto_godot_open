extends Node2D

## 原版怪物血条 `CommonHpBar.as:11-52` 逐像素照搬：
##   54×11；1px 黑外框 + 1px 白圈 + 1px 黑内圈，里面纯绿 `0x36DF2D` 的 48×5 填充。
## 原版**没有**按血量变色、也没有百分比文字 —— 之前那版（黄/红分段 + 54×10 + 常显）是自造的。
##
## 位置和出现时机不在这里，在 `战斗角色`：`x = -27`、`y = -origin.y - 11 - 2`、
## 只在收到血量包时出现、10 秒自动隐藏（`Monster.as:818-843`）。

const 宽 := 54.0
const 高 := 11.0
const 描边黑 := Color(0.0, 0.0, 0.0, 1.0)
const 描边白 := Color(1.0, 1.0, 1.0, 1.0)
## 3595565 == 0x36DF2D
const 填充色 := Color(54.0 / 255.0, 223.0 / 255.0, 45.0 / 255.0, 1.0)

var _比例 := 1.0

func set_比例(value: float) -> void:
	var 新 := clampf(value, 0.0, 1.0)
	if is_equal_approx(新, _比例):
		return
	_比例 = 新
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 宽, 高), 描边黑)
	draw_rect(Rect2(1.0, 1.0, 宽 - 2.0, 高 - 2.0), 描边白)
	draw_rect(Rect2(2.0, 2.0, 宽 - 4.0, 高 - 4.0), 描边黑)
	if _比例 > 0.0:
		draw_rect(Rect2(3.0, 3.0, _比例 * (宽 - 6.0), 高 - 6.0), 填充色)

extends Control

## 忍术树的连接线层。**逐条画**，不在运行时 new 控件。
##
## 为什么用 `_draw` 而不是一堆 TextureRect：项目约定「固定控件必须是场景里的节点，
## 页面脚本不许 `TextureRect.new()`」（`测试/功能入口回归测试.gd` 会逐条查源码）。
## 连接线的条数随页签变（4~14 条），又要在切换时整批换掉，
## 用 `_draw` + 一份数据最省事，也不破坏那条约定。
##
## 绘制的数据由 `忍术窗口._渲染连接线` 备好后调 `设置连接线`：
## 每项 `{纹理: Texture2D, 位置: Vector2, 尺寸: Vector2}`，
## 纹理已经按"指向的格子学没学"选好了原色（橙）或灰度版。

var _条目: Array = []


func 设置连接线(条目: Array) -> void:
	_条目 = 条目
	queue_redraw()


func _draw() -> void:
	for 项 in _条目:
		var 纹理: Texture2D = 项.get("纹理")
		if 纹理 == null:
			continue
		draw_texture_rect(纹理, Rect2(项.get("位置", Vector2.ZERO), 项.get("尺寸", 纹理.get_size())),
			false, Color.WHITE)

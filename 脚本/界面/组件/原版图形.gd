extends Control

## 原版用 `graphics` **直接画**的两种形状（不是库里的皮肤图，所以没有 PNG 可取）：
##   · 圆角矩形框 = `ExchageShopWindowCell.drawBorder()`（`ExchageShopWindowCell.as:144-151`）
##     `lineStyle(1, 0x474747)` + `beginFill(0x201E22, 0.35)` + `drawRoundRect(0,0,130,200,6,6)`
##   · 圆点 ⓘ = `createInfoIcon()`（`:250-262`）
##     `lineStyle(1, 0xFFFFFF, 0.85)` + `beginFill(0x336699)` + `drawCircle(7,7,7)`
##
## ⚠ 为什么不走 `StyleBoxFlat`：`测试/UI资源回归测试.gd:110` 钉死「界面脚本不许重新引入手绘
##   StyleBoxFlat」（样式只能来自 `原版皮肤表.gd` / `原版主题.tres`），而这两样**在原版就不是样式、
##   是运行时矢量绘制** ⇒ 用 `_draw()` 才是同一件事的等价物。
## ⚠ 未收口：Godot 的 2D 绘制**没有圆角矩形原语** ⇒ 框目前是直角（原版 6px 圆角）。
##   要收口只能二选一：给 `原版主题.tres` 增一枚生成的圆角样式，或导一张九宫格皮 ——
##   两者都比"差 6px 圆角"更贵，先如实记着。

enum 型 { 格框, 圆点 }

## 只有 `圆点` 用得到；`格框` 的描边/填充色按 AS3 字面写死在 `_draw()` 里。
var 形状: int = 型.格框


func _draw() -> void:
	if 形状 == 型.圆点:
		draw_circle(Vector2(7.0, 7.0), 7.0, Color(0x33 / 255.0, 0x66 / 255.0, 0x99 / 255.0, 1.0))
		draw_arc(Vector2(7.0, 7.0), 7.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 1.0)
		return
	var 面 := Rect2(Vector2.ZERO, size)
	draw_rect(面, Color(0x20 / 255.0, 0x1E / 255.0, 0x22 / 255.0, 0.35), true)
	draw_rect(面, Color(0x47 / 255.0, 0x47 / 255.0, 0x47 / 255.0, 1.0), false, 1.0)

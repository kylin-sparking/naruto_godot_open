extends Control
## 原版 `com/mxw/common/ui/GeneralInternalLoading`（全文 100 行）的等价件 —— 变身卡交换演出用。
##
## 结构照 `initUI`：一个容器 `_loadingContainer` 摆在 **(-90,-10)**，里面三件
##   · 底 `GeneralLoadingBg_Skin`（182×20；`asset/effect.swf` 符号 **45** → 位图 43）
##   · 填充 `GeneralLoading_Skin`（182×20；符号 **48** → 位图 46）——**被一块 mask 裁**
##   · 文字：TextField 宽 140、`x = 20`、`y = -10`，**12px、绿 `#00FF00`、居中**
## 进度：`percent` setter 把 mask 画成 `0,0 → 20 + 140*percent/100, 20`（`:59`）
## ⇒ 底左端 **20px 是装饰端帽**，**填充从第 20px 起、可用宽 140**。
##
## Godot 没有图层 mask ⇒ 等价成「一个 `clip_contents = true` 的裁窗口，宽度随进度长」。
##
## ⚠️ 引用存在**实例属性**上，不用 `set_meta` —— **meta 键只许 ASCII，中文键会被静默拒掉**
## （本工程已在 `变身卡互换窗` 里记过这条，§3.143 又踩了一次）。

const 底图 := "res://素材/界面/原版窗口/通用控件/GeneralLoadingBg.png"
const 填图 := "res://素材/界面/原版窗口/通用控件/GeneralLoading.png"

const 端帽宽 := 20.0			# `:59` 的 `20 + ...`
const 可用宽 := 140.0			# `:59` 的 `140 * percent / 100`
const 条高 := 20.0

var 裁窗: Control
var 文字: Label


## 建一件（含全部子件），**不挂树**。
static func 新建() -> Control:
	var 本 := new()					# 本脚本 extends Control ⇒ 直接得到带脚本的 Control
	本.name = "通用进度条"
	本.size = Vector2(182.0, 条高)
	本.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 底 := TextureRect.new()
	底.name = "底"
	底.texture = load(底图) as Texture2D
	底.position = Vector2.ZERO
	底.size = Vector2(182.0, 条高)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	本.add_child(底)
	var 裁 := Control.new()
	裁.name = "裁窗"
	裁.position = Vector2.ZERO
	裁.size = Vector2(端帽宽, 条高)
	裁.clip_contents = true			# ← 替原版那块 mask
	裁.mouse_filter = Control.MOUSE_FILTER_IGNORE
	本.add_child(裁)
	本.裁窗 = 裁
	var 填 := TextureRect.new()
	填.name = "填"
	填.texture = load(填图) as Texture2D
	填.position = Vector2.ZERO
	填.size = Vector2(182.0, 条高)
	填.mouse_filter = Control.MOUSE_FILTER_IGNORE
	裁.add_child(填)
	var 字 := Label.new()
	字.name = "文字"
	字.position = Vector2(端帽宽, -10.0)		# `_tf.x = 20; _tf.y = -10`（容器自身在 (-90,-10)）
	字.size = Vector2(可用宽, 条高)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.add_theme_color_override("font_color", Color(0, 1, 0))	# `:88` color = 65280
	字.add_theme_font_size_override("font_size", 12)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	本.add_child(字)
	本.文字 = 字
	return 本


## 摆到原版那个位置再挂进宿主（原版 `_swapLoadingBar.x = 210; y = param1 - 20`，
## 而它内部容器再偏 (-90,-10) ⇒ 条的**左上角**落在 AS3 `(120, param1 - 30)`）。
static func 弹出(宿主: Control, 位置: Vector2, 文案: String) -> Control:
	var 本 := 新建()
	本.position = 位置
	(本.文字 as Label).text = 文案
	宿主.add_child(本)
	return 本


## `percent` setter：clamp 0..100，再把裁窗宽度改成 `20 + 140 * p / 100`。
func 设百分比(百分比: int) -> void:
	var p := clampi(百分比, 0, 100)
	if 裁窗 != null and is_instance_valid(裁窗):
		裁窗.size = Vector2(端帽宽 + 可用宽 * float(p) / 100.0, 条高)

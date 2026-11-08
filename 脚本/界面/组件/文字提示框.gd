extends Control

## 原版 `MToolTipText`（`com/mxw/uifl/base/controls/tips/MToolTipText.as`）。
## 意志页三处悬浮提示都走它：导师费用（`TeacherCell:74-75`）、召唤次数
## （`TeacherCell:111-112`）、打开背包（`TeacherPanel:139`）。
##
## 版式全是代码算的（提示框只有 `ToolTip_background` 这一张底图，没有布局），逐条出处：
##   MToolTip.as:14        PADDING    = 8
##   MToolTipText.as:13    MAX_WIDTH  = 354
##   :80-81                tf.x = tf.y = 7
##   :71-73                TextFormat(size 12, leading 5, COMMON_FONT=宋体)
##   :82-89                multiline + wordWrap，先按 354 折行
##   :90                   tf.width  = textWidth  + 6
##   :91                   tf.height = textHeight + 4
##   :61-62                back.width  = tf.width  + PADDING*2 − 5
##                         back.height = tf.height + PADDING*2 − (n>1 ? 3 : 7)
##   :29-30                `back = new ToolTip_background()` 后**只设 width/height**
##                         ⇒ 符号 699 在 SWF 里没有 scale9Grid，整张非等比拉伸
##                         （与 `物品提示框.gd` 同一张图、同一种拉伸）
##   MToolTip.as:136-141   定位 = 鼠标 +(10,20)，再钳进舞台；比舞台高就整体缩放
##   MToolTip.as:104       container 挂 MOUSE_MOVE ⇒ 提示框一路跟鼠标
##
## ⚠️ 两套行度量必须换算（见 skill `flash-text-area-geometry-port`）：
##   Flash 宋体 12px 行盒 = 15，行距 = 15 + leading(5) = 20；
##   Godot 这套 `素材/界面/原版字体.tres`(SimSun) 量得 `get_height(12) = 13`（实测），
##   所以 `line_separation` 要填 `leading + 2 = 7` 才是 20 的行距。
##   盒高同理：Godot 内容高 = 13n+7(n−1) = 20n−7，比 Flash 的 textHeight(20n−5) 少 2
##   ⇒ 下面 `行盒差` 就是补这 2px，补完 `底高` 与原版**逐像素同值**（n=1→28、n=2→52）。
##
## ⚠️ Flash 的 `textWidth` 含 TextField 左右各 2px 内槽 ⇒ 墨迹宽 = textWidth − 4，
##   本文件按 `墨迹内槽 = 4` 还原，最终 `底宽 = 墨迹宽 + 21`。

const 内边距 := 8.0
const 最大宽 := 354.0
const 文字偏移 := 7.0
const 行距 := 5.0			# TextFormat.leading
const 行盒差 := 2.0			# Flash 行盒 15 − Godot SimSun 行盒 13
const 墨迹内槽 := 4.0			# Flash textWidth = 墨迹宽 + 2×2

@onready var _底: TextureRect = $底
@onready var _文字: RichTextLabel = $文字

## 舞台尺寸（原版 `Config.STAGE_WIDTH/HEIGHT`）。背包那边沿用 960×560。
var _舞台 := Vector2(960.0, 560.0)
## 最近一次鼠标位置（**页面局部**）——由 `_input` 里的移动事件更新，见下面两段注释。
var _鼠标点 := Vector2()


## `文本` 必须是**已经翻成 BBCode** 的串（`功能窗口.文案转BBCode`）——
## 原版这里喂的是 `htmlText`，`<font color>`/`<br>` 与 Godot 的 `[color]`/`\n` 不通用。
func 设置(文本: String, 舞台尺寸 := Vector2()) -> void:
	if 舞台尺寸 != Vector2():
		_舞台 = 舞台尺寸
	_文字.text = 文本
	_排版()


## `MToolTipText.setValue` + `draw`：折行量尺寸 → 定文字盒 → 定底 → 定自身尺寸。
func _排版() -> void:
	var 字号 := _文字.get_theme_font_size("normal_font_size")
	var 字体 := _文字.get_theme_font("normal_font")
	var 单行 := 字体.get_height(字号)
	# 颜色标签不吃宽度，按解析后的纯文本量（与 物品提示框 同一套量法）
	var 量 := 字体.get_multiline_string_size(
			_文字.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, 最大宽, 字号)
	var 行数 := 1 if 单行 <= 0.0 else maxi(1, int(round(量.y / 单行)))
	var 内容高 := 量.y + (行距 + 行盒差) * float(行数 - 1)
	var 文字盒宽 := minf(最大宽, 量.x + 墨迹内槽) + 6.0
	var 文字盒高 := 内容高 + 行盒差 + 4.0
	_文字.position = Vector2(文字偏移, 文字偏移)
	_文字.size = Vector2(文字盒宽, 文字盒高)
	var 框 := Vector2(文字盒宽 + 内边距 * 2.0 - 5.0,
			文字盒高 + 内边距 * 2.0 - (3.0 if 行数 > 1 else 7.0))
	_底.size = 框
	size = 框


## 原版 `MToolTip.setLocation`：贴在鼠标右下、钳进舞台、比舞台高就整体缩放。
func 贴到鼠标(鼠标位置: Vector2, 舞台尺寸: Vector2) -> void:
	scale = Vector2.ONE
	if size.y > 舞台尺寸.y - 8.0:
		var 比 := (舞台尺寸.y - 8.0) / size.y
		scale = Vector2(比, 比)
	var 位置 := 鼠标位置 + Vector2(10.0, 20.0)
	位置.x = clampf(位置.x, 0.0, maxf(0.0, 舞台尺寸.x - size.x * scale.x))
	位置.y = clampf(位置.y, 0.0, maxf(0.0, 舞台尺寸.y - size.y * scale.y))
	position = 位置


## 原版 `MToolTip.as:104` 给 container（=stage）挂 MOUSE_MOVE，`:77-83 __onMouseMove →
## setLocation` —— 是**事件驱动**，不是每帧轮询。
## ⚠️ 别写成 `_process` + `get_local_mouse_position()`：那两个函数读的是**操作系统真实光标**，
##   `push_input` / `parse_input_event` 合成的移动事件都不更新它
##   （2026-09-28 探针实测：推 (120,120) 后 `get_global_mouse_position()` 仍是 (-64,513)）
##   ⇒ 离线量具里提示框永远停在旧位置，跟随根本验不出来。所以这里用**事件自带坐标**。
## 事件坐标是视口全局的，`position` 是宿主的局部 ⇒ 先减宿主原点（`_宿主原点()`）再定位。
func _input(事件: InputEvent) -> void:
	if 事件 is not InputEventMouseMotion:
		return
	var 原点: Variant = _宿主原点()
	if not (原点 is Vector2):
		return
	_鼠标点 = (事件 as InputEventMouseMotion).global_position - (原点 as Vector2)
	if visible:
		贴到鼠标(_鼠标点, _舞台矩形())


## 提示框**宿主**的全局原点（父节点是窗口页 Control ⇒ 页面全局位置；父节点是 CanvasLayer ⇒ (0,0)）。
## 认不出宿主就返回 `null`，两条自定位路径一起罢工 —— 这正是 2026-10-21 用户报的
## 「精华框的说明显示在左上角」：`技能面板` 的根是 CanvasLayer，提示框 `add_child` 到它身上后
## 以前只认 Control 的这段直接 return，于是停在 `贴到鼠标((0,0))` 算出的 (10,20)。
## 原版没有这个坑：`MToolTip.as:94-98` 没给 container 时兜到 `PopUpMananger.stage`，`:103` 再
## `_container.addChild(this)`，`:136-137` 用 `container.mouseX/Y` 定位 ⇒ **提示框的局部系恒等于舞台系**。
## 本工程 CanvasLayer（技能面板 layer=100）没有 offset/rotation/scale，局部系与舞台系重合 ⇒ 原点 (0,0)。
func _宿主原点() -> Variant:
	var 主 := get_parent()
	if 主 is Control:
		return (主 as Control).get_global_position()
	if 主 is CanvasLayer:
		return Vector2.ZERO
	return null


## 舞台矩形换算到**宿主局部**：原版 `setLocation:138-141` 钳的是 stage 坐标，
## 而本节点的 `position` 是宿主局部 ⇒ 直接拿舞台尺寸来钳会少钳掉一个宿主原点
## （实测提示框会探出画布下沿 37px）。窗口被拖动时这个差每帧重算，不会失效。
func _舞台矩形() -> Vector2:
	var 原点: Variant = _宿主原点()
	if not (原点 is Vector2):
		return _舞台
	return (_舞台 - (原点 as Vector2)).max(Vector2.ZERO)


## 浮出来的**那一帧**就贴在鼠标右下 —— 原版 `showTip():100` 先 `setLocation()` 再 `addChild`。
## Godot 侧同一次 `push_input` 里 `_input` 段跑在 pick 段**之前**，所以触发本次悬停的那条
## motion 已经存进 `_鼠标点`；不接这条通知的话，指针绝对静止时提示框会先在 (0,0) 亮一帧。
func _notification(什么: int) -> void:
	if 什么 == NOTIFICATION_VISIBILITY_CHANGED and visible:
		贴到鼠标(_鼠标点, _舞台矩形())

extends Control

## 原版 `MToolTipTextWithTitle`（`com/mxw/uifl/base/controls/tips/MToolTipTextWithTitle.as`）——
## **Buff 格**的悬停提示（`BuffCell.updateFamilyData:136-140`、`setData:274-278`、
## `updateToolTip:168-175` 用的都是它）。
##
## 版式（逐条对着 AS3 抄，别凭感觉改）：
##   :16        MAX_WIDTH = 236（固定宽，不像 MToolTipText 按文字缩宽）
##   :62-63     title/content 文本框 x=7；title y=12、height=20、**居中**、橙色 #ff6600、加粗
##   :64        content y=35，白、size 12、leading 5、wordWrap/multiline、黑 glow
##   :83-89     content.height = textHeight + 5；
##              back.width  = MAX_WIDTH + PADDING*2 − 5 = 247
##              back.height = 20 + content.height + PADDING*2 + 10 − 4
##   定位/跟随/钳制继承 `MToolTip`（同 `文字提示框.gd` 的注释：鼠标 +(10,20)，钳进舞台）。
##
## 行盒换算与 `文字提示框.gd` 同一份：Flash 宋体 12px 行盒 15 = Godot SimSun 13 + 2，
## 所以 `line_separation = leading + 2 = 7`；文字盒高多补 2 才等于原版 textHeight。

const 富文本 := preload("res://脚本/界面/富文本.gd")

const 最大宽 := 236.0
const 内边距 := 8.0
const 标题高 := 20.0
const 标题偏移 := Vector2(7.0, 12.0)
const 文字偏移 := Vector2(7.0, 35.0)
const 行距 := 5.0
const 行盒差 := 2.0

@onready var _底: TextureRect = $底
@onready var _标题: RichTextLabel = $标题
@onready var _文字: RichTextLabel = $文

var _舞台 := Vector2(960.0, 560.0)
var _鼠标点 := Vector2()


## `标题` 是纯文本（原版 titleTextField.htmlText 只包了一层橙色粗体）；
## `描述` 可以带原版 HTML（`<font color>` / `<br/>`），这里过唯一一份转换。
## `标题色`：Buff 的原版 `MToolTipTextWithTitle:62` 是 #ff6600；轮回技能的原版
## `MToolTipLunHuiYanSkill:120-127`（`_loc4_.color = 16776960`）是 **#ffff00** ⇒ 给那个页传 "ffff00"。
func 设置(标题: String, 描述: String, 舞台尺寸 := Vector2(), 标题色 := "ff6600") -> void:
	if 舞台尺寸 != Vector2():
		_舞台 = 舞台尺寸
	_标题.text = "[center][color=#%s][b]%s[/b][/color][/center]" % [标题色, 标题]
	_文字.text = 富文本.译文为BBCode(描述)
	_排版()


func _排版() -> void:
	_标题.position = 标题偏移
	_标题.size = Vector2(最大宽, 标题高)
	var 字号 := _文字.get_theme_font_size("normal_font_size")
	var 字体 := _文字.get_theme_font("normal_font")
	var 单行 := 字体.get_height(字号)
	var 量 := 字体.get_multiline_string_size(
			_文字.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, 最大宽, 字号)
	var 行数 := 1 if 单行 <= 0.0 else maxi(1, int(round(量.y / 单行)))
	var 内容高 := 量.y + (行距 + 行盒差) * float(行数 - 1)
	var 文字盒高 := 内容高 + 行盒差 + 5.0
	_文字.position = 文字偏移
	_文字.size = Vector2(最大宽, 文字盒高)
	var 框 := Vector2(最大宽 + 内边距 * 2.0 - 5.0,
			标题高 + 文字盒高 + 内边距 * 2.0 + 10.0 - 4.0)
	_底.size = 框
	size = 框


## `MToolTip.setLocation`：鼠标 +(10,20)、钳进舞台、比舞台高就整体缩放。
func 贴到鼠标(鼠标位置: Vector2, 舞台尺寸: Vector2) -> void:
	scale = Vector2.ONE
	if size.y > 舞台尺寸.y - 8.0:
		var 比 := (舞台尺寸.y - 8.0) / size.y
		scale = Vector2(比, 比)
	var 位置 := 鼠标位置 + Vector2(10.0, 20.0)
	位置.x = clampf(位置.x, 0.0, maxf(0.0, 舞台尺寸.x - size.x * scale.x))
	位置.y = clampf(位置.y, 0.0, maxf(0.0, 舞台尺寸.y - size.y * scale.y))
	position = 位置


## 用事件自带坐标（OS 光标在 `push_input` 合成事件下不更新，见 `文字提示框.gd`）。
func _input(事件: InputEvent) -> void:
	if 事件 is not InputEventMouseMotion:
		return
	var 主 := get_parent() as Control
	if 主 == null:
		return
	_鼠标点 = (事件 as InputEventMouseMotion).global_position - 主.get_global_position()
	if visible:
		贴到鼠标(_鼠标点, _舞台矩形())


func _舞台矩形() -> Vector2:
	var 主 := get_parent() as Control
	if 主 == null:
		return _舞台
	return (_舞台 - 主.get_global_position()).max(Vector2.ZERO)


func 收起() -> void:
	visible = false


func _notification(什么: int) -> void:
	if 什么 == NOTIFICATION_VISIBILITY_CHANGED and visible:
		贴到鼠标(_鼠标点, _舞台矩形())

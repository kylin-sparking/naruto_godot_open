extends Control

## 原版 `MToolTipText` 的对位组件（`uifl/base/controls/tips/MToolTipText.as`）：
##   · `MAX_WIDTH = 354`；文本框 x=y=7、`textColor` 白、字号 12、`leading=5`、
##     `wordWrap/multiline`、`filters = BaseUtil.getGlowFilter()`（黑色 blur2 ⇒ 本工程描边 2）；
##   · `setValue()`：`tf.htmlText = BaseUtil.formatStr(值)` —— **喂的就是带 `<font>/<br/>` 的 HTML**，
##     这里过 `富文本.译文为BBCode` 同一层；
##   · `draw()`：`tf.width = textWidth+6`、`tf.height = textHeight+4`；
##     底 `width = tf.width + 16 - 5`、`height = tf.height + 16 - (多行?3:7)`（PADDING=8×2 在内）；
##   · 定位 `MToolTip.setLocation`：鼠标 +(10,20)，再钳进舞台。
## 谁在用：人物页套装四灯的悬停（`seriesEquipTooltips`，`EquipPane.as:942`）。

const 富文本 := preload("res://脚本/界面/富文本.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 最大文本宽 := 354.0
const 文本偏移 := Vector2(7.0, 7.0)
const 底边距补量 := 11.0        # PADDING*2 - 5
const 底高多行扣 := 3.0
const 底高单行扣 := 7.0

@onready var _底: NinePatchRect = $底
@onready var _文: RichTextLabel = $文

var _已测量 := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_文.add_theme_font_size_override("normal_font_size", 12)
	_文.add_theme_color_override("default_color", Color.WHITE)
	# 原版 `tf.defaultTextFormat.leading = 5`
	_文.add_theme_constant_override("line_separation", 5)
	# 原版 `filters = BaseUtil.getGlowFilter()` = 黑色 blur2 ⇒ 描边取规则值（同值同源）。
	_文.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_文.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)

## `html` 用原版语言模板拼出来的串（带 `<font>`/`<br/>`）；`鼠标位置` 是**本节点父级**的局部坐标。
func 显示提示(html: String, 鼠标位置: Vector2) -> void:
	if html.is_empty():
		收起()
		return
	_文.text = 富文本.译文为BBCode(html)
	# 自然宽：按 354 上限排版后取最宽一行（原版 `tf.textWidth + 6` 语义）。
	# 度量走 **`Text` 文本段类**（4.7 有；`-script` 的解析器不认这个类名，所以反射实例化），
	# 量的是剥掉 BBCode 标记后的**纯文本**。万一引擎没有这个类：退化为固定 354 宽
	# —— 提示仍完整，只是不 hug 短行（**不能**因此报错或撑破版）。
	var 文宽 := 最大文本宽 + 6.0
	if ClassDB.class_exists("Text"):
		var 段 = ClassDB.instantiate("Text")
		段.font = _文.get_theme_font("normal_font")
		段.font_size = 12
		段.width = 最大文本宽
		段.text = _剥标记(_文.text)
		段.layout()
		var 最宽 := 0.0
		for i in 段.get_line_count():
			最宽 = maxf(最宽, 段.get_line_width(i))
		文宽 = minf(最宽 + 6.0, 最大文本宽 + 6.0)
	_文.custom_minimum_size = Vector2(文宽, 0.0)
	_文.reset_size()
	var 多行 := _文.get_line_count() > 1
	var 文高: float = _文.size.y
	文高 += 4.0                       # 原版 tf.height = textHeight + 4
	_底.size = Vector2(文宽 + 底边距补量, 文高 + 16.0 - (底高多行扣 if 多行 else 底高单行扣))
	_文.position = 文本偏移
	size = _底.size
	custom_minimum_size = size
	visible = true
	# 贴鼠标 + 钳舞台（`MToolTip.setLocation`）
	var 视口 := get_viewport()
	var 舞台: Vector2 = 视口.get_visible_rect().size if 视口 != null else size
	position = Vector2(
		clampf(鼠标位置.x + 10.0, 0.0, maxf(0.0, 舞台.x - size.x)),
		clampf(鼠标位置.y + 20.0, 0.0, maxf(0.0, 舞台.y - size.y)))

func 收起() -> void:
	visible = false


## BBCode 标记整体是"方括号包一段"（原版模板里不会出现裸方括号文本）。手扫剥除——
## ⚠️ 别拿正则串抄近路：`"["`前单放一个反斜杠是非法转义（parse error），必须双写。
static func _剥标记(文: String) -> String:
	var 出 := ""
	var 在标记内 := false
	for i in 文.length():
		var c := 文[i]
		if c == "[":
			在标记内 = true
		elif c == "]":
			在标记内 = false
		elif not 在标记内:
			出 += c
	return 出

extends Control
## 一行原版复选项（`指示框` + `标记` + `文本` + `点击区域`）自己的交互态。
##
## 真值：原版这一族是 `MCheckBoxF` → `MCheckBox` → **`MButton3`**（`MCheckBox.as:6`），
## 皮只有「未选 / 选中」两张，**悬停与按下不是新图，是运行时给当前可见那张皮挂加性色矩阵**
## （`StyleUtil.as:7-12` up 0 / over +30 / down −40；`StyleUtil.as:43-47` `getLightFilter` =
## 单位矩阵第 5 列 R/G/B 各加 d，逐通道 clamp、alpha 行 `0,0,0,1,0` 不动 alpha；
## 挂载点 `MButton3.as:341-345` 只给 `_selected ? selectedUpSkin : upSkin` 那一个 DisplayObject）。
## Godot 没有「运行期给贴图加色矩阵、且只加一个子件」这条挂法（`material` 会被子节点继承、
## 连文字一起变亮就不是原版的了）⇒ 按工程既有口径**预烘派生皮**、换态=换 `texture`
## （`开发工具/生成复选框态图.py`，公式与底栏十钮/页签同一份 `开发工具/派生钮态.py`）。
##
## 三条刻意「不做 / 必须做」：
##  * **不换文字颜色**。本窗那 25 枚的文本色是 `GuaJiSettingWindow.as:719-731` 的
##    `createCheckBox(..., 2003199)` 走 `MButton3.as:444-451` 那个 `textColor` 设器给的，
##    而它把 up/over/down/disabled **四档写成同一个数** ⇒ 原版悬停、按下时文字一动不动。
##    照 `_textColors` 的默认四档（#FCF49C/#FFFFC3/#ACADB2/#939393）去换色就是自己加戏。
##  * **不用 `texture_hover` / `button_pressed`**。`MButton3.as:103-108` 松手回的是 **STATE_UP**
##    而不是 OVER ⇒ 不移出鼠标就不会再亮；挂 `texture_hover` 会松手仍亮着（假的第四态）。
##    那颗 `点击区域` 是 `flat=true`，实测（10-19 变异实测 C 档）**flat 的 Button 连主题的
##    `hover`/`pressed` 皮也不画** —— 所以"移过来什么反应都没有"不是被主题的皮盖住，而是
##    这一族以前**根本没有状态机**。也正因为它不画皮，整行的反馈只能来自方框那两张皮；
##    谁要是把 `flat` 去掉，主题的 `按钮.png` 就会整行铺过来 —— 那条由像素门
##    `开发工具/出勾态对照图.py` 的「文字区一个像素都不许变」抓住（变异实测 E 档实测会红）。
##  * **重新可用要退回常态**。`MButton3.as:461-470` `set enabled(true)` 把 `_state` 钉回
##    STATE_UP ⇒ VIP 闸放开那一刻哪怕鼠标还压在勾上也不该继续亮。

## ⚠ 取的时候一律 `str(后缀[档])`：数组元素是 Variant，
## `var 路 := 根 + 后缀[档] + ".png"` 会 parse 失败
## （`Cannot infer the type of "路" variable because the value doesn't have a set type`）；
## 而 `const 后缀: Array[String] := [...]` 这一式在这个引擎版本上直接
## `Expected initializer after constant name` ⇒ 常量不写类型，转字符串放在用的一侧。
const 后缀 := ["", "_悬停", "_按下", "_灰"]

var _钮: Button = null
var _皮: Array = []
var 主干: Array = []
var _态 := 0
var _禁用档 := false


func _ready() -> void:
	_钮 = get_node_or_null("点击区域") as Button
	var 框 := get_node_or_null("指示框") as TextureRect
	var 记 := get_node_or_null("标记") as TextureRect
	if _钮 == null or 框 == null or 记 == null:
		return
	_皮 = [框, 记]
	## 主干必须在**任何一次换皮之前**抄下来，而且要**去掉 `.png`**：换过之后再读
	## `texture.resource_path` 拿到的是派生皮那条路，下一档就会拼出
	## `复选框未选_悬停_按下.png` 这种东西（拼出来的路 `ResourceLoader.exists` 为假 ⇒
	## 又回落成上一档，看着像"态坏了"）。
	主干 = []
	for 件 in _皮:
		var 图: Texture2D = (件 as TextureRect).texture
		主干.append(str(图.resource_path).trim_suffix(".png") if 图 != null else "")
	_钮.mouse_entered.connect(_设态.bind(1))
	_钮.mouse_exited.connect(_设态.bind(0))
	_钮.button_down.connect(_设态.bind(2))
	_钮.button_up.connect(_设态.bind(0))
	刷态()


func _设态(态: int) -> void:
	_态 = 态
	刷态()


## 两张皮都刷：哪一张盖在上面由 `标记.visible`（勾没勾）决定，但**两张都得是同一档**，
## 否则「悬停时点一下打勾」会把上一档的皮亮着留在下面。
func 刷态() -> void:
	if _钮 == null or _皮.is_empty():
		return
	var 是禁用 := _钮.disabled
	if _禁用档 and not 是禁用:
		_态 = 0
	_禁用档 = 是禁用
	var 档: int = 3 if 是禁用 else _态
	for 序 in _皮.size():
		var 根: String = 主干[序]		# ⚠ 别写 `String(主干[序])`：GDScript 4 没有 String 构造器
		if 根.is_empty():
			continue
		var 路: String = 根 + str(后缀[档]) + ".png"
		if not ResourceLoader.exists(路):
			路 = 根 + ".png"		# 缺派生皮 ⇒ 回落常态，不许停在上一档的皮上
		var 新 := load(路) as Texture2D
		if 新 != null:
			(_皮[序] as TextureRect).texture = 新

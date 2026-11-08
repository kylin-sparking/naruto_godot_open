extends BaseButton
## 原版「一张常态皮 + 运行时 `getLightFilter(±30/−40)`」这一族在 Godot 侧的**唯一**实现。
##
## 属于这一族的（`extends MButton3`、只有一张 upSkin，悬停/按下不是新图而是滤镜）：
##  `MWindowCloseBtnF`（每一扇原版窗右上角那颗 X，symbol7）、`MPlusBtnF`（symbol600）、
##  `MMinusBtnF`（symbol604）、`MCheckBoxF`（挂机页那 27 枚勾）。
## 真值：`StyleUtil.as:7-12` up 0 / over **+30** / down **−40**；`StyleUtil.as:43-47` 加性、
## 逐通道 clamp、alpha 行 `0,0,0,1,0` 不动 alpha；`MButton3.as:103-108` 松手回 **STATE_UP**；
## `MButton3.init()` `:135` 手型光标。
##
## 两条「不许」（写死在这里，别再往回改）：
##  * **不用 `texture_hover` / 主题的 hover 档做效果**：Godot 松手后只要鼠标还悬着就停在 hover，
##    而原版松手立刻回 UP（鼠标不挪开就不该再亮）。本脚本把主题四档都指到**同一个** StyleBox
##    再自己换它的贴图 ⇒ hover 档画不出第二个形状，状态机说了算。
##  * **不用 `modulate` / shader**：modulate 是乘性（(100,60,20)×#fff4d8 = (100,57,17)），
##    原版是加性 clamp（(130,90,50)）；material 还会被子节点继承、连文字一起变亮。
## ⇒ 只能**换皮**，派生皮由 `开发工具/生成通用控件态图.py` 按 `开发工具/派生钮态.py` 预烘，
##    与常态皮**同目录同名加后缀**（`关闭按钮_悬停.png`）。
##
## 用法两种，都不需要宿主再写状态机：
##  ① `.tscn` 里给那颗钮挂本脚本（编辑器/生成器写 `script = ExtResource("<三态>")`）；
##  ② 代码里建的钮：`钮.set_script(三态)` **再**设皮 **再** `add_child`。
## 手型光标不进这里 —— 它是"烘在场景里、能被编辑器看见"的东西（各窗自己设或生成器烘）。

## ⚠ 常量不写类型（`const X: Array[String] := [...]` 在这个引擎版本上直接 parse 失败），
## 用的时候 `str(后缀[档])`：数组元素是 Variant，不标 ⇒ `var 路 := 根 + 后缀[i] + ".png"` 推断不出类型。
const 后缀 := ["", "_悬停", "_按下", "_灰"]

const 形纹理 := 1
const 形图标 := 2
const 形样式盒 := 3

var _主干 := ""
var _形态 := 0
var _盒: StyleBoxTexture = null
var _态 := 0
var _禁用档 := false
## ⚠ 一律走这个变量而不是 `self`：GDScript 把 `self` 的静态类型收成"本脚本"，
## `self is TextureButton` / `self as Button` 会当场 parse 失败
## （`Expression is of type "…原版三态钮.gd" so it can't be of type "TextureButton"`）。
var _钮: BaseButton = null


func _ready() -> void:
	_钮 = self
	var 根 := _取常态()
	if 根.is_empty():
		## 查不到常态皮 ⇒ **什么都不接**。不许在没抄到主干的情况下去换皮：
		## 那样第一档就会把 `res://…/_悬停.png` 这种半截路拼出来，回落逻辑再把皮刷没。
		return
	_主干 = 根.trim_suffix(".png")
	_钮.mouse_entered.connect(_设态.bind(1))
	_钮.mouse_exited.connect(_设态.bind(0))
	_钮.button_down.connect(_设态.bind(2))
	_钮.button_up.connect(_设态.bind(0))
	刷()


## 抄常态皮主干，顺便认形态。样式盒那一族在这里把四档并成**同一个实例私有的** StyleBox，
## 之后 `刷()` 只要换这一个对象的 texture 就等于换档 —— 不并的话主题会自己画 hover，
## 与状态机各画各的（松手仍亮那一族）。
func _取常态() -> String:
	if _钮 is TextureButton and (_钮 as TextureButton).texture_normal != null:
		_形态 = 形纹理
		return str((_钮 as TextureButton).texture_normal.resource_path)
	if _钮 is Button and (_钮 as Button).icon != null:
		_形态 = 形图标
		return str((_钮 as Button).icon.resource_path)
	if _钮 is Button:
		var 初 := (_钮 as Button).get_theme_stylebox("normal")
		if 初 is StyleBoxTexture and (初 as StyleBoxTexture).texture != null:
			_形态 = 形样式盒
			_盒 = (初 as StyleBoxTexture).duplicate() as StyleBoxTexture
			for 槽 in ["normal", "hover", "pressed", "focus", "disabled"]:
				(_钮 as Button).add_theme_stylebox_override(槽, _盒)
			return str((_盒.texture as Texture2D).resource_path)
	return ""


func 刷() -> void:
	if _形态 == 0:
		return
	var 是禁用 := _钮.disabled
	## `MButton3.as:467-470`：`set enabled(true)` 把 `_state` **钉回 STATE_UP** —— 重新可用那一刻
	## 哪怕鼠标还压在上面也不回悬停档（要等下一次 rollOver）。不跟着做就会"闸一放开这颗就一直亮着"。
	if _禁用档 and not 是禁用:
		_态 = 0
	_禁用档 = 是禁用
	var 图 := _取图(3 if 是禁用 else _态)
	if 图 == null:
		return
	match _形态:
		形纹理:
			(_钮 as TextureButton).texture_normal = 图
		形图标:
			(_钮 as Button).icon = 图
		形样式盒:
			_盒.texture = 图


func _取图(档: int) -> Texture2D:
	var 路: String = _主干 + str(后缀[档]) + ".png"
	if not ResourceLoader.exists(路):
		路 = _主干 + ".png"		# 缺派生皮 ⇒ 回落常态，不许停在上一档的皮上
	return load(路) as Texture2D


func _设态(态: int) -> void:
	_态 = 态
	刷()

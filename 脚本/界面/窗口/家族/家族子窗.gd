extends Control

## 家族子窗共用控制器（场景由 `开发工具/生成家族子窗.py` 按 SPEC 生成，期望值与场景同源）。
## 只做美术与交互：按钮三态 + 勾选 + 动作交回宿主 `_show_guild_action`；数据/协议一律走既有钩子。
## 真值：`game-client/真值/窗口/家族.md` §2.2–§2.16。
##
## 三态口径 = `MButton3.as:329-346`：常态原皮、悬停 +30、按下 −40、禁用推灰度矩阵，
## 每张档由生成器预烘成 `<皮>_悬停/_按下/_灰.png`（TextureButton 没有九宫格，不能整拉），
## 皮的主干名写在节点的 `metadata/skin`（完整 res:// 路径去掉 .png）；没写 skin 的钮（关钮、
## 分页四小件）在原版是两帧符号、不是 MButton3 滤镜族 ⇒ 不做亮度切换。
##
## 文字**换色**是同一族状态机的另一半（`MButton3.as:520-527` `updateTextState()` 把
## `_textColors[_state]` 写进 `tf`），档位与亮度档一一对应：
## `MButton3.as:69-74` `_textColors` = up 16577692 / over 16777155 / down 11316658 /
## disabled 9671571（`MButtonF`、`MPage*BtnF` 都不覆盖这张表）。
## ⚠ 以前这一格写的是「禁用 #939393、其余全白」—— 白是谁都没写过的值。
const 态后缀 := ["", "_悬停", "_按下", "_灰"]
const 态字色 := [Color(0.9882352941176471, 0.9568627450980393, 0.611764705882353),		# #FCF49C
		Color(1.0, 1.0, 0.7647058823529411),		# #FFFFC3
		Color(0.6745098039215687, 0.6784313725490196, 0.6980392156862745),		# #ACADB2
		Color(0.5764705882352941, 0.5764705882352941, 0.5764705882352941)]		# #939393
const 勾皮 := ["res://素材/界面/原版窗口/通用控件/复选框未选.png",
			  "res://素材/界面/原版窗口/通用控件/复选框选中.png"]
@export var 窗名 := ""
var _宿主: Node
var _钮们: Array = []
## 装配那一刻的 `texture_normal` = 这颗钮的**常态底片**。派生目录里不一定有 `<主干>.png`
## （翻页箭头就是：只有 `_悬停/_按下/_灰`，常态仍是通用控件那张共享原图）⇒
## 回落到"自己记住的那张"，而不是"这一档没图就什么都不做"（那样禁用皮会赖在钮上）。
var _常态 := {}


## 运行期改了 `disabled` 之后要从外面叫一次：Godot 不会为 disabled 变化发任何信号，
## 而这一族的禁用档是**换皮**换来的，不重画就会把上一档（悬停/按下）留在钮上。
func 重画钮态() -> void:
	for 钮 in _钮们:
		if is_instance_valid(钮):
			_设态(钮 as TextureButton, 0)


## ⚠️ 第二参数 `窗名值` 是**修 bug 加的**，不是摆设：
##    `窗名` 靠场景里 `窗名 = "家族成员窗"` 那一行注入，而它在部分窗上**没被 Godot 认成
##    脚本属性**（读出来是空串）⇒ `_发动作` 拼出的是 `":退出家族"` 这种**没有窗名前缀**的
##    动作串，开窗表查不到 ⇒ 玩家点了按钮**一声不响**（2026-10-05 用户报的「无法退出家族」、
##    「家族旗帜无法设置」都是这一条）。所以开窗那一刻由壳把窗名**显式写进来**，
##    不再赌场景序列化。
## 窗名由壳在开窗前塞进 meta（`家族子窗壳.切换`）—— **不走第二参数**，因为
## `家族列表窗.gd` 有自己的 `装配(宿主)`（单参数）且自己按场景路径算窗名，
## 多传一个参数会让它的 `装配` 直接报 "Expected 1 argument(s)"。
## meta 键必须是 **ASCII**：中文键在这个工程里会被静默丢掉（`set_meta("档")` 那次）。
const 窗名键 := "guild_subwindow_name"

func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	# ⚠️ `get_meta` 返回 Variant ⇒ `:=` 会被推定成 Variant，而工程把这条警告当错误处理
	#    （脚本直接判解析失败，症状是"所有子窗按钮集体失灵"）。显式标注类型。
	var 值: Variant = get_meta(窗名键, "")
	var 名: String = str(值) if 值 != null else ""
	if not 名.is_empty():
		窗名 = 名
	_钮们 = []
	_常态 = {}
	_绑(get_children())


func _绑(子们: Array) -> void:
	for 子 in 子们:
		if 子 is TextureButton:
			var 钮 := 子 as TextureButton
			钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if 钮.has_meta("skin"):
				钮.mouse_entered.connect(_设态.bind(钮, 1))
				钮.mouse_exited.connect(_设态.bind(钮, 0))
				钮.button_down.connect(_设态.bind(钮, 2))
				钮.button_up.connect(_设态.bind(钮, 0))		# `MButton3.as:103-108` 松手回 STATE_UP
				_钮们.append(钮)
				_常态[钮] = 钮.texture_normal
				_设态(钮, 0)
			钮.pressed.connect(_发动作.bind(String(钮.get_meta("act")) if 钮.has_meta("act") else String(钮.name)))
		elif 子 is Control and 子.get_node_or_null("框") is TextureRect:
			var 勾 := 子 as Control
			勾.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			勾.gui_input.connect(_翻复选.bind(勾))
		elif 子 is Control:
			_绑(子.get_children())		# 分页容器里那四颗


func _发动作(名: String) -> void:
	if _宿主 != null and _宿主.has_method("_show_guild_action"):
		# 兜底：`窗名` 万一还是空的（场景属性没注入、或被别处改了），退回节点名 ——
		# 本套窗的场景根节点名**恰好等于窗名**，两者一致时动作串才对得上开窗表。
		# ⚠️ 三元的两个分支一个是 String、一个是 StringName ⇒ 推断成 Variant，工程把
		#    "Variant 推断"当错误处理（会直接把脚本判成解析失败）。显式标成 String。
		var 前缀: String = 窗名 if not 窗名.is_empty() else String(name)
		_宿主.call("_show_guild_action", "%s:%s" % [前缀, 名])


func _设态(钮: TextureButton, 态: int) -> void:
	var 档: int = 3 if 钮.disabled else 态
	var 皮: String = String(钮.get_meta("skin")) + 态后缀[档] + ".png"
	var 字 := 钮.get_node_or_null("Label") as Label
	## 字色**先换、不被皮的缺失挡住**：禁用档的 #939393 是 ColorMatrix 之外的独立一档，
	## 而分页箭头这类主干图本身不在派生目录里（`_灰` 有、常态没有）⇒ 以前一 return 就连字色一起漏掉。
	if 字 != null:
		字.add_theme_color_override("font_color", 态字色[档])
	if not ResourceLoader.exists(皮):
		## 常态这一档回落到**装配时记住的那张**（见 `_常态`）；其余档缺图就什么都不做。
		if 档 == 0 and _常态.has(钮):
			钮.texture_normal = _常态[钮] as Texture2D
		return				# 没有这张档就别把贴图清空（清空=白框，比不换更糟）
	钮.texture_normal = load(皮) as Texture2D


## 勾选。⚠️ **形参顺序必须是 `(事件, 勾)`**，不能写成 `(勾, 事件)`：
##    `Callable.bind()` 的参数是**追加在信号自身参数之后**的，`gui_input` 先发事件，
##    所以连出来实际调用的是 `(事件, 勾)`。写成 `(勾, 事件)` 会报
##    `Cannot convert argument 1 from Object to Object.` 然后**什么都不发生** ——
##    家族这一套子窗的复选框（说明窗的「下次跳过」、令牌窗的勾选…）一直是坏的，
##    2026-10-07 做说明窗落盘时才被抓出来（门：`测试/家族旗帜说明回归测试.gd`）。
##    `家族列表窗.gd` 里那份同名函数是同一个错，一并改过。
func _翻复选(事件: InputEvent, 勾: Control) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var 框 := 勾.get_node("框") as TextureRect
		var 上 := String(框.texture.resource_path) == 勾皮[1]
		框.texture = load(勾皮[0 if 上 else 1]) as Texture2D
		_发动作(String(勾.get_meta("act")) if 勾.has_meta("act") else String(勾.name))
		get_viewport().set_input_as_handled()

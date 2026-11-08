extends Control
## 创建角色窗（原版独立素材包 MainCreateChar.swf，`CreateCharWindow3.as` 425 行）。
##
## 逐件真值与算式在 `真值/窗口/创建角色.md`；几何由 `开发工具/生成创建角色场景.py` 烘进场景，
## 本文件只做**行为**：四格换皮选中 / 随机 / 名字校验判序 / 提交体 / 悬停说明 / 弹框 / 转圈。
##
## ⚠ 三处最容易做错、都被实机打回过的形状，钉在这里：
##   ① 选中态是**换皮**不是染色（`CharBox2.as:103-108`）：selected 时 upSkin 隐、downSkin 显；
##      而且选中后**悬停不再变亮**（`overHanfler` 第一句就 `if(!_selected)`）。
##   ② 随机不是只随机名字（`randomChar():199-225`）：先按分布换一格，**再**要一个名字。
##   ③ 提交体 face/hair 一律 0（`enterGame():355-376`）：外观由服务端定，不是客户端挑。

var 尺寸表: Dictionary = _读尺寸表()


## ⚠ `preload()` 一个 .json 拿到的是 **JSON 资源对象**、不是字典，
## 直接 `["件"]` 会 parse 失败 ⇒ 只能 `FileAccess` 读文本再 `JSON.parse_string`。
static func _读尺寸表() -> Dictionary:
	var 解 = JSON.parse_string(FileAccess.get_file_as_string(
			"res://数据/界面/创建角色_尺寸.json"))
	return 解 if 解 is Dictionary else {}

## 原版枚举（`CreateCharWindow3.as:28-40`）
const 男 := 1
const 女 := 2
## 校验三档常数（`:22-26`）
const 名字最长 := 12
const 名字最短 := 2
const 名字最宽 := 76.0

## 逐字文案（`en_US$createChar_properties.as`，一个字的差别都算错）
const 提示名 := "请输入角色名"
const 提示太长 := "你输入的角色名太长，请重新输入！"
const 提示空 := "角色名不能为空"
const 提示非法 := "角色名不能以数位开头或含有非法字元"
const 提示超长 := "角色名长度不能大于12"
const 提示超短 := "角色名长度不能小于2"
const 确定 := "确定"
## 四条职业描述（原版带 <br/>，Godot 走 BBCode 换行）
const 描述 = [
	"以宇智波家为代表的火遁术，可使用火系忍术对敌人造成巨大伤害。\n基本武器：忍杖\n流派忍术：火遁•烈焰斩、火遁•凤仙花之术、火遁•火龙炎弹",
	"水孕育出的元素精华水遁，利用无所不在的水分子释放出伤害巨大的忍术。\n基本武器：吹矢\n流派忍术：水遁•水之刃、水遁•水龙弹、水遁•大瀑布术",
	"以风属性查克拉为基质的风遁术，将有如刀刃一般的查克拉，把敌人撕裂切碎。\n基本武器：扇子\n流派忍术：风遁•螺旋丸、风遁•真空玉、风遁•风杀阵",
	"雷属性查克拉释放出的雷遁术，以能量巨大的雷系忍术给敌人带来致命创伤。\n基本武器：太刀\n流派忍术：雷遁•雷切、雷遁•雷球术、雷遁•千鸟流",
]

@onready var _窗口: Control = $窗口
@onready var _名标签: Label = $窗口/名标签
@onready var _输入: LineEdit = $窗口/角色名输入
@onready var _随机: Button = $窗口/随机钮
@onready var _进入: TextureButton = $窗口/进入游戏
@onready var _背景: TextureRect = $背景
@onready var _转圈: TextureRect = $窗口/提交转圈

var _格: Array = []
var _格信息 := {}
var _当前: Dictionary = {}
var _用户输入过 := false
var _后端: Node
var _弹框: Control
var 回车关 := false		# 只在场的那一扇吃回车
var _提示: Control
var _正则 := RegEx.new()

signal 建好角了(角色号: int)


func _ready() -> void:
	## 原版 `CreateCharWindow3.resize()`（`:187-197`）：`_bg` 拉满舞台、窗在**背景里**居中
	## （`_window.x = (bg.width − window.width)/2`）。本工程把根做成「铺满视口」，
	## 居中交给场景里 `窗口` 的 0.5 锚点 ⇒ 挂在哪个层都正居中。
	## 以前根只有 249×410、位置由上一层随手放 ⇒ 用户看到的「创建角色窗偏右下」（10-10 报）。
	## ⚠ 必须用 set_anchors_and_offsets_preset：只设锚点、偏移还是场景里的 0,0,249,410 ⇒ 尺寸不变（实测踩过）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 原版 `resize():186-196`：`_bg` 拉满**舞台**、`_window` 在舞台上居中。
	# 场景根是 Control 时锚点不生效（它没有父节点可参照）⇒ 运行期自己撑满视口；
	# `窗口` 那层已经是 center 锚点，根一撑满整窗就自动居中（以前贴左上角就是这个没做）。
	anchor_right = 1.0
	anchor_bottom = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_背景.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 原版 /^(?!\d)[a-zA-Z0-9一-龥_]{1,}$/ —— 改写成**等价且不带反斜杠**的形式：
	# 首字符取自"字母/汉字/下划线"，其后才允许数字。工程里往 .gd 写带 \ 的正则被吞过一层。
	_正则.compile("^[a-zA-Z一-龥_][a-zA-Z0-9一-龥_]*$")
	_格 = [$窗口/职业格1, $窗口/职业格2, $窗口/职业格3, $窗口/职业格4]
	for i in _格.size():
		var 钮: TextureButton = _格[i]
		# ⚠ 不能用 set_meta：Godot 4 的 metadata 键要求合法标识符，
		#    中文键报 `Invalid metadata identifier` 且**静默存不进去**（值拿回来是 null）。
		#    四格信息改存控制器侧字典，键 = 节点 instance_id。
		var 定: Dictionary = 尺寸表["件"][钮.name]
		_格信息[钮.get_instance_id()] = {
			"job": int(定["job"]), "gender": int(定["gender"]),
			"skins": [定["未选"], 定["悬停"], 定["选中"]], "sfx": 定["音"]}
		钮.mouse_entered.connect(_格悬停.bind(钮))
		钮.mouse_exited.connect(_格离开.bind(钮))
		钮.gui_input.connect(_格点击.bind(钮))
	_输入.text_changed.connect(_名字变了)
	_输入.max_length = 名字最长
	_随机.pressed.connect(_点随机)
	_进入.gui_input.connect(_点进入)
	_后端 = get_node_or_null("/root/BackendConnection")
	if _后端 != null:
		if not _后端.char_name_generated.is_connected(_收到随机名):
			_后端.char_name_generated.connect(_收到随机名)
		if not _后端.character_created.is_connected(_收到建角):
			_后端.character_created.connect(_收到建角)
	# 原版 `addEventListener(Event.ADDED_TO_STAGE, randomChar)`（`:82`）⇒ **一开窗就先选一格 + 要名字**
	随机选格()
	_点随机()


## 原版 `randomChar():199-225`：`r = Math.random()*100`，
## `r>=70`→格3(风女)、`r>=40`→格2(水女)、`r>=20`→格4(雷男)、否则格1(火男)。
## 注意**分布不是均匀四选一**，照抄阈值，别"优化"成 randi()%4。
func 随机选格() -> void:
	var r := randf() * 100.0
	var 序 := 0
	if r >= 70.0:
		序 = 2
	elif r >= 40.0:
		序 = 1
	elif r >= 20.0:
		序 = 3
	_选中(_格[序] as TextureButton)


func _选中(钮: TextureButton) -> void:
	if not _当前.is_empty():
		_设皮(_当前["钮"] as TextureButton, false)
	var 信: Dictionary = _格信息[钮.get_instance_id()]
	_当前 = {"钮": 钮, "job": int(信["job"]), "gender": int(信["gender"])}
	_设皮(钮, true)


## `CharBox2.as:103-108` selected 换皮 + `:56-66` 悬停只在**未选中**时生效。
## ⇒ 选中那枚把 hover 皮也指回"选中"，鼠标划过不会跳回常态（原版就是这个形状）。
func _设皮(钮: TextureButton, 选中: bool) -> void:
	var 皮: Array = _格信息[钮.get_instance_id()]["skins"]
	var 根 := "res://素材/界面/原版窗口/创建角色/"
	if 选中:
		钮.texture_normal = load(根 + str(皮[2]))
		钮.texture_hover = load(根 + str(皮[2]))
	else:
		钮.texture_normal = load(根 + str(皮[0]))
		钮.texture_hover = load(根 + str(皮[1]))


func _格悬停(钮: TextureButton) -> void:
	# 对象比对象：直接比引用。以前绕了一层 int(节点) ⇒ `Nonexistent int constructor`，
# 悬停函数从这一行就死掉（连提示都浮不出来）。
	if _当前.get("钮", null) == 钮:
		return
	_起提示(描述[_格.find(钮)])


func _格离开(_钮: TextureButton) -> void:
	_灭提示()


func _格点击(ev: InputEvent, 钮: TextureButton) -> void:
	if not (ev is InputEventMouseButton):
		return
	var 键 := ev as InputEventMouseButton
	if 键.button_index != MOUSE_BUTTON_LEFT or not 键.pressed:
		return
	_选中(钮)
	# 原版 `clickCharHandler:378-404`：没手动打过字 ⇒ 换格要**顺带再要一个名字**
	if not _用户输入过:
		_点随机()
	_播(钮)


func _播(钮: TextureButton) -> void:
	var 名 := str(_格信息[钮.get_instance_id()]["sfx"])
	var 路 := "res://素材/界面/原版窗口/创建角色/%s.mp3" % 名
	if not ResourceLoader.exists(路):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(路)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _点随机() -> void:
	if _当前.is_empty():
		return
	if _后端 != null:
		_后端.request_generate_char_name(int(_当前["gender"]))


func _收到随机名(名字: String) -> void:
	if 名字.is_empty():
		return
	_输入.text = 名字
	# 原版 `setName()` 只写 text，**不**把 _userInput 置真 ⇒ 之后点格子还会再随机换名


func _名字变了(新值: String) -> void:
	_用户输入过 = true
	# 原版 `__inputNameHandler:406-412`：只有"宽度超 76"这一条是**边打字边弹**的
	if _字宽(新值) > 名字最宽:
		_弹(提示太长)


func _字宽(文: String) -> float:
	if 文.is_empty():
		return 0.0
	var 字 := get_theme_font("font")
	return 字.get_string_size(文, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12.0).x


## 原版 `enterGameHandler` → `createCharFail():145-184`。**判序就是顺序**，别重排：
## ① 宽度超 76 ② 空 ③（泰服才走，本工程跳过）④ 正则 ⑤ 长度 >12 ⑥ 长度 <2。
## 红字弹框那两支的色是 `16711680` = #FF0000。
func _点进入(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var 键 := ev as InputEventMouseButton
	if 键.button_index != MOUSE_BUTTON_LEFT:
		return
	if 键.pressed:
		_转圈.visible = false		# 原版 mouseDownHandler:121-124
		return
	_转圈.visible = true			# 原版 mouseUpHandler:123-127
	var 文 := _输入.text.strip_edges()
	if _字宽(文) > 名字最宽:
		_弹(提示太长)
		return
	if 文 == "":
		_弹(提示空)
		return
	if _正则.search(文) == null:
		_弹(提示非法, true)
		return
	if 文.length() > 名字最长:
		_弹(提示超长, true)
		return
	if 文.length() < 名字最短:
		_弹(提示超短, true)
		return
	if _当前.is_empty():
		_弹("先选一个流派")
		return
	if _后端 == null:
		_弹("没连上服务端，建不了角")
		return
	if not bool(_后端.create_character(文, int(_当前["job"]), int(_当前["gender"]))):
		_弹("创角请求发送失败")


## 原版 `handleAddNewCharacterEntryPacket` → 选角 → 进图。本工程：拿到 `jylx:17` 就
## 直接把新角色选中，后面 `jylx:11` 的入口票由 `后端连接` 现有那条链走完。
func _收到建角(角色: Dictionary) -> void:
	var 号 := int(角色.get("id", 0))
	if 号 <= 0 or _后端 == null:
		return
	后端忙 = false
	_后端.select_character(号)
	建好角了.emit(号)


var 后端忙 := false


# ============================ 悬停说明（CreatCharToolTip.as）============================
## 底 = `CToolTip_background`（九宫格 L11 T9 R10.5 B6.5）；
## 文字 (5,5) 白 12px，`tf=(textWidth+6)×(textHeight+6)`、`bg=tf+10`；跟鼠标 (+10,+20)。

func _起提示(文: String) -> void:
	if _提示 == null:
		_提示 = _造提示()
	_提示.visible = true
	var 标: Label = _提示.get_node("文本")
	标.text = 文
	await get_tree().process_frame
	var 字 := 标.get_theme_font("font").get_string_size(
			文, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12.0)
	var 宽 := ceilf(字.x) + 6.0 + 10.0
	var 高 := ceilf(字.y) + 6.0 + 10.0
	标.size = Vector2(ceilf(字.x) + 6.0, ceilf(字.y) + 6.0)
	_提示.size = Vector2(宽, 高)
	(_提示.get_node("底") as Panel).size = Vector2(宽, 高)
	_跟鼠标()


func _灭提示() -> void:
	if _提示 != null:
		_提示.visible = false


func _跟鼠标() -> void:
	if _提示 == null or not _提示.visible:
		return
	_提示.global_position = get_viewport().get_mouse_position() + Vector2(10.0, 20.0)


func _造提示() -> Control:
	var 层 := Control.new()
	层.name = "创角悬停提示"
	层.z_index = 200
	层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(层)
	var 底 := Panel.new()
	底.name = "底"
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 箱 := StyleBoxTexture.new()
	箱.texture = load("res://素材/界面/原版窗口/创建角色/悬停提示底.png")
	var 边: Dictionary = _边距("悬停提示底", 110)
	箱.texture_margin_left = 边["左"]
	箱.texture_margin_top = 边["上"]
	箱.texture_margin_right = 边["右"]
	箱.texture_margin_bottom = 边["下"]
	箱.content_margin_left = 0.0
	箱.content_margin_top = 0.0
	箱.content_margin_right = 0.0
	箱.content_margin_bottom = 0.0
	底.add_theme_stylebox_override("panel", 箱)
	层.add_child(底)
	var 标 := Label.new()
	标.name = "文本"
	标.position = Vector2(5.0, 5.0)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	层.add_child(标)
	return 层


func _边距(皮名: String, 符号: int) -> Dictionary:
	for 键 in 尺寸表["件"]:
		var v = 尺寸表["件"][键]
		if v is Dictionary and str((v as Dictionary).get("皮", "")) == 皮名:
			return v as Dictionary
	return {"左": 11.0, "上": 9.0, "右": 10.5, "下": 6.5}


# ============================ 弹框（Dialog.as:124-183）============================
## 302 宽（`CDilog_bgSkin` 九宫格 L28 T33.5 R30 B33.5）、内容底 `CYellow_background` 于 (6,6)、
## 文本盒 267 宽 x=14 y=14 居中 12px、`高 = textHeight + 8`、`面板高 = 内容高 + 50`、
## 确定钮居中 `y = 面板高 − 钮高 − 5 − 8`、遮罩黑 0.3、整窗 `round((舞台 − 窗) >> 1)` 居中、回车关。

## 原版 `Dialog.as:202-208`：`keyCode == 13 → destroy()`。
## ⚠ 回车这条**只能挂在 `_unhandled_key_input` 上**：本轮无头实测
##    `push_input(KEY_ENTER)` 打到 grab_focus 过的 Button 上**不会**触发 ui_accept
##    （焦点确实在钮上、`gui_input` 也收不到），但节点的 unhandled 收得到。
##    挂 `遮罩.gui_input` 那一版是死代码 —— 门里"回车没关框"就是这么抓出来的。
func _unhandled_key_input(事件: InputEvent) -> void:
	if not 回车关:
		return
	var 键 := 事件 as InputEventKey
	if 键 == null or not 键.pressed or 键.keycode != KEY_ENTER:
		return
	_关弹框()


func _关弹框() -> void:
	回车关 = false
	if _弹框 != null and is_instance_valid(_弹框):
		_弹框.queue_free()
	_弹框 = null
	_弹框 = null
	if is_instance_valid(_输入):
		_输入.grab_focus()	# 原版关框后回到输入框接着打


func _弹(文: String, 红字 := false) -> void:
	if _弹框 != null and is_instance_valid(_弹框):
		_弹框.queue_free()
	var 舞台 := get_viewport().get_visible_rect().size
	var 遮罩 := Control.new()
	遮罩.name = "创角弹框"
	遮罩.z_index = 300
	遮罩.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(遮罩)
	_弹框 = 遮罩
	遮罩.set_anchors_preset(Control.PRESET_FULL_RECT)
	var 黑 := ColorRect.new()
	黑.color = Color(0, 0, 0, 0.3)
	黑.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黑.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩.add_child(黑)

	var 字宽 := 267.0
	var 字体: Font = get_theme_font("font")
	var 行数 := 1
	for 段 in 文.split("\n"):
		行数 += int(maxf(0.0, ceilf(字体.get_string_size(
				段, HORIZONTAL_ALIGNMENT_LEFT, 字宽, 12.0).x / 字宽) - 1.0))
	var 文本高 := ceilf(字体.get_string_size(
			文, HORIZONTAL_ALIGNMENT_LEFT, 字宽, 12.0).y) * maxi(1, 文.split("\n").size())
	var 内容高 := 文本高 + 8.0
	var 面板高 := 14.0 + 内容高 + 50.0

	var 板 := Panel.new()
	板.name = "板"
	板.size = Vector2(302.0, 面板高)
	板.position = Vector2(roundf((舞台.x - 302.0) * 0.5), roundf((舞台.y - 面板高) * 0.5))
	var 箱 := StyleBoxTexture.new()
	箱.texture = load("res://素材/界面/原版窗口/创建角色/弹框底.png")
	var 边 := _边距("弹框底", 86)
	箱.texture_margin_left = 边["左"]
	箱.texture_margin_top = 边["上"]
	箱.texture_margin_right = 边["右"]
	箱.texture_margin_bottom = 边["下"]
	板.add_theme_stylebox_override("panel", 箱)
	遮罩.add_child(板)

	var 内 := Panel.new()
	内.name = "内容底"
	内.position = Vector2(6.0, 6.0)
	内.size = Vector2(283.0, 内容高)
	内.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 内箱 := StyleBoxTexture.new()
	内箱.texture = load("res://素材/界面/原版窗口/创建角色/弹框黄底.png")
	var 内边 := _边距("弹框黄底", 89)
	内箱.texture_margin_left = 内边["左"]
	内箱.texture_margin_top = 内边["上"]
	内箱.texture_margin_right = 内边["右"]
	内箱.texture_margin_bottom = 内边["下"]
	内.add_theme_stylebox_override("panel", 内箱)
	板.add_child(内)

	var 标 := Label.new()
	标.name = "文本"
	标.position = Vector2(14.0, 14.0)
	标.size = Vector2(字宽, 内容高)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", Color(1, 0, 0, 1) if 红字 else Color(1, 1, 1, 1))
	标.text = 文
	板.add_child(标)

	var 钮 := Button.new()
	钮.name = "确定"
	钮.text = 确定
	钮.add_theme_font_size_override("font_size", 12)
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	板.add_child(钮)
	await get_tree().process_frame
	var 钮宽 := 确定.length() * 12.0 + 10.0
	钮.size = Vector2(钮宽, 22.0)
	钮.position = Vector2(roundf((302.0 - 钮宽) * 0.5), 面板高 - 22.0 - 13.0)
	# ⚠ 必须抢焦点：`gui_input` 的键盘事件只发给**焦点持有者**，不抢焦点的话下面那条
	#    回车关框永远不响（信号连了、门绿着、功能没有 —— 本轮实测就是这么抓出来的）。
	#    原版 `Dialog.as:255` 的 `stageFocusRect = false` 也正是"弹框会拿焦点"的痕迹。
	钮.focus_mode = Control.FOCUS_ALL
	钮.grab_focus()
	钮.pressed.connect(_关弹框)
	回车关 = true

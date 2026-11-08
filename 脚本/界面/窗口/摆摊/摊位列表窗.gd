extends RefCounted
## 摊位列表窗（原版 `StallListWindow`）控制器。逐件真值 = `真值/窗口/摊位列表.md`。
##
## 链路（照 `ItemWindow2.as:1547` → `UIMain2.as:4568-4576` → `StallListWindow.init():152-156`）：
##   背包底部「摊位列表」⇒ `窗口管理.打开或收起("摊位列表")` ⇒ `open_page` ⇒ **发 `1296:0:0:11`**；
##   回帧 `1296:0:<总数>:<行表>` ⇒ `后端连接.stall_list_received` ⇒ `窗口管理._on_stall_list`
##   ⇒ **只有这扇窗在台上**才灌（`StallDataManager.as:88-94` 就一句 `if (stallListWindow)`）。
## ⚠ 回帧那一路**不许走 `open_page`**：那条里含「重新请求第 0 页」，发↔回会成环（工程既有口径）。
##
## 逐页状态全放**宿主的具名变量**上（`功能窗口._摊位列表走` 等），不用 `set_meta` ——
## Godot 4 的 metadata 键要求合法标识符，中文键会**静默存不进去**（工程已栽过）。
## 页本体**代码现搭、不烘场景**：整页是一张「列表皮肤 + 表头 + 翻页条」的纯几何表
## （`CommonListSkin2` 那五条纹本身就是按 `int(行数/2)` 算出来现摆的），
## 行又每帧全换 ⇒ 烘进 `.tscn` 只会让真值表和场景各存一份同一串数字。
## 同一个形状的既有先例 = `摊位行.gd`（行内 13 件全代码搭，矩形表就是唯一事实来源）。

const 行脚本 := preload("res://脚本/界面/窗口/摆摊/摊位列表行.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")

## `StallListWindow.as:42` `_pageSize = 11`（`loadPage:175-178` 用它算 `startIndex/endIndex`）。
const 每页 := 11
const 列表区高 := 240.0		# `:247` `_list.height = 240`；11 行 × 22 = 242 ⇒ **最后一行天生被裁 2px**（原版量出来的，照抄）
const 行高 := 22.0			# `:249` `_list.rowHeight = 22`

const 皮_底板 := "res://素材/界面/原版窗口/通用控件/子面板.png"			# MPane_background 253×212，九宫格 [8,7,7,7]
const 皮_顶线 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"		# LineHPicF 252×2，`extends Sprite` ⇒ 九宫格必须全 0
const 皮_条纹 := "res://素材/界面/原版窗口/通用控件/列表分隔.png"			# ListSeparator_background 304×24，[12,12,0,0]
const 皮_竖线 := "res://素材/界面/原版窗口/通用控件/竖向分隔线.png"		# TableSeparatorLineF 2×20
const 皮_输入框 := "res://素材/界面/原版窗口/通用控件/输入框.png"			# MTextInput_background 125×21
const 皮_下拉 := "res://素材/界面/原版窗口/通用控件/下拉框.png"			# MComboBox 皮 116×21
const 皮_箭头 := "res://素材/界面/原版窗口/通用控件/下拉箭头.png"			# 13×8
const 皮_菜单底 := "res://素材/界面/原版窗口/通用控件/菜单底.png"			# MPopupMenu_background（与 `家族列表窗._弹下拉` 同一套）
const 皮_菜单项 := "res://素材/界面/原版窗口/通用控件/菜单按钮.png"		# MPopupMenuButtonF
const 皮_页钮 := "res://素材/界面/原版窗口/通用控件/%s.png"				# 首页/上一页/下一页/末页
const 钮字色 := Color(0.988235, 0.956863, 0.611765, 1)	# MButton3._textColors[up] = #fcf49c

## 六枚列头（`LangUtil.get("STALL_LIST_WINDOW_LIST_TITLE").split(",")`，语言表 `:1628`）。
const 列头 := ["摊位号", "摊位名称", "出售人", "等级", "物品数量", "宠物数量"]
## 快速搜索那三项：`StallListWindow.as:29-38` 的 `label` + `data` 一对一对抄。
## ⚠ **顺序与 data 都不是 0/1/2 递增**：第 1 项「按物品名称」的 data 是 **1**、第 2 项「按摊位名称」才是 0；
## 而 `_quickKey` 初值 = 1（`:44`）⇒ 默认选中的就是第一项。服务端 `_stall_matches_search` 认的也是这套号。
const 搜索项 := [["按物品名称", 1], ["按摊位名称", 0], ["按宠物名称", 2]]	# :2578 / :2600 / :2919

## 逐件矩形（**页坐标** = AS3 外框坐标 − (0,29)；`数据/界面/窗口尺寸.json` 的 `整框: true` 那一支）。
## 每条算式的出处都写在 `真值/窗口/摊位列表.md` §②③，这里只留结果。
const 窗件 := {
	"底板": [13.0, 14.0, 448.0, 269.0],		# `:220-222` `_contentBg(8,38,458,310) ± BORDER_GAP(5)`
	"顶线": [16.0, 39.0, 442.0, 2.0],		# `CommonListSkin2.as:20-24` skin-local (3,25) w=448−6
	"列头1": [15.0, 17.0, 48.0, 20.0],		# `:225-227` x = 底板x+2、y = 48−2
	"列头2": [65.0, 17.0, 116.0, 20.0],
	"列头3": [183.0, 17.0, 94.0, 20.0],
	"列头4": [279.0, 17.0, 44.0, 20.0],
	"列头5": [325.0, 17.0, 66.0, 20.0],
	"列头6": [393.0, 17.0, 66.0, 20.0],
	"列分隔1": [63.0, 19.0, 2.0, 20.0],		# `:200-204` x = 列头x + 列头w、y = 48（**第六列后面没有竖线**）
	"列分隔2": [181.0, 19.0, 2.0, 20.0],
	"列分隔3": [277.0, 19.0, 2.0, 20.0],
	"列分隔4": [323.0, 19.0, 2.0, 20.0],
	"列分隔5": [391.0, 19.0, 2.0, 20.0],
	"列表": [16.0, 40.0, 442.0, 240.0],		# `:243-247` x = 底板x+3、y = 48+21、w = 底板w−6
	"快速搜索": [13.0, 286.0, 88.0, 20.0],	# `:253-258` y = 列表底 + 6 = 315、w 设成 88、右对齐
	"下拉": [101.0, 286.0, 105.0, 20.0],	# `:259-263` x = 快速搜索x+w
	"关键字": [221.0, 286.0, 50.0, 20.0],	# `:265-268` x = 下拉x+w+15
	"输入框": [271.0, 288.0, 125.0, 21.0],	# `:269-271` x = 关键字x+50、y = 那一行 + 2
	"搜索钮": [401.0, 286.0, 37.0, 22.0],	# `:273-274` x = 输入框x+w+5、宽 = btn_width_two
	"总数": [15.0, 321.0, 60.0, 20.0],		# `:275-277` x=15、y = 378−28
	"刷新钮": [80.0, 322.0, 37.0, 22.0],		# `:278-279` x = 总数x+w+5、y = 378−5−22
	"首页": [127.0, 324.0, 18.0, 13.0],		# `:280` x = 刷新x+w+10、y = 刷新y+2
	"上一页": [155.0, 324.0, 15.0, 13.0],
	"页码": [170.0, 321.0, 50.0, 20.0],		# `:282-284` x = 上一页x+w、y 跟「总数」那一行
	"下一页": [220.0, 324.0, 15.0, 13.0],	# `:285` x = 上一页x+w+50（**不是 15+2**）
	"末页": [245.0, 324.0, 18.0, 13.0],
	"查看摊位": [273.0, 322.0, 61.0, 22.0],	# `:287-288` x = 末页x+w+10、宽 = btn_width_four
	"查看信息": [344.0, 322.0, 61.0, 22.0],
	"载入中": [167.0, 150.0, 140.0, 20.0],	# `:291-292` ((474−140)/2, (378−20)/2)
}
## 五条斑马纹：skin-local y = 25+2+20 = 47，步长 = 24+20 = 44，条数 = `int(11/2)` = **5**
## （`CommonListSkin2.as:25-37`）。底板 skin 原点页坐标 (13,14)、条纹 x = 原点x+3 ⇒ 16。
const 条纹 := [[16.0, 61.0], [16.0, 105.0], [16.0, 149.0], [16.0, 193.0], [16.0, 237.0]]


## 开一扇新窗的状态。`词` = 已提交的搜索词（`= ""` 时走 `requestStallList`，见 `UI.as:800-808`），
## `快序` = 下拉的**序号**（不是 data），`请页` = 发出去那一页、`页` = 回帧落地那一页
## （原版 `_requestPageIndex` / `_currentPage` 两个字段，`setPageData:357` 才把前者交给后者）。
static func 空态() -> Dictionary:
	return {"总": 0, "行": [], "页": 0, "请页": 0, "快序": 0, "词": "", "载": false, "选": -1}


static func 渲染(宿主: Node) -> Control:
	var 页 := Control.new()
	页.name = "原版摊位列表内容"
	页.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.size = Vector2(474.0, 349.0)
	宿主._content.add_child(页)
	宿主._摊位列表页 = 页
	_搭(页)
	_接线(页, 宿主)
	## 页整个重建 ⇒ 下拉显示要跟着**宿主上那份**（`_摊位列表快序`）复活，不然翻一页就把玩家
	## 选过的类目画回「按物品名称」（原版 `selectedItem` 活在同一只控件上，压根不重建）。
	(页.get_node("下拉/文字") as Label).text = String(搜索项[int(宿主._摊位列表快序)][0])
	同步行(宿主)
	刷新态(宿主)
	return 页


## 同一实例再来一次（翻页回帧、买完之后的 `1296:1:` 之类都不关这条）。
static func 重灌(宿主: Node) -> void:
	var 页 = 宿主._摊位列表页
	## ⚠ `queue_free()` 之后节点**还在**（`is_instance_valid` 仍真）到帧末才真删 ⇒
	## 判"这页还能不能用"必须看它**还挂在 `_content` 下**，只判 valid 会把行建到一个待删的旧页上。
	if 页 == null or not is_instance_valid(页) or (页 as Control).get_parent() != 宿主._content:
		渲染(宿主)
		return
	同步行(宿主)
	刷新态(宿主)


## ── 建件 ────────────────────────────────────────────────────────────────────

static func _搭(页: Control) -> void:
	_九宫(页, "底板", 皮_底板, [8, 7, 7, 7])
	_图片(页, "顶线", 皮_顶线)
	for i in 条纹.size():
		_九宫(页, "条纹%d" % (i + 1), 皮_条纹, [12, 12, 0, 0], 条纹[i])
	for i in 6:
		_文字(页, "列头%d" % (i + 1), 列头[i], Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 5:
		_图片(页, "列分隔%d" % (i + 1), 皮_竖线)
	_列表区(页)
	_文字(页, "快速搜索", "快速搜索：", Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)	# 语言表 :486
	_文字(页, "关键字", "关键字：", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)		# :100
	_下拉(页)
	var 框 := LineEdit.new()
	框.name = "输入框"
	框.position = Vector2(窗件["输入框"][0], 窗件["输入框"][1])
	框.size = Vector2(窗件["输入框"][2], 窗件["输入框"][3])
	框.editable = true
	框.max_length = 20			# `MTextInput2` 那枚输入框的 maxChars（原版 20，见 背包/商城搜索框同口径）
	框.add_theme_font_size_override("font_size", 12)
	页.add_child(框)
	_钮(页, "搜索钮", "搜索", 37.0)			# :3329 / :1299 / :938 / :3005
	_文字(页, "总数", "总数：", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)	# :817（数字由 `setPageData` 接在后面）
	_钮(页, "刷新钮", "刷新", 37.0)
	_页钮(页, "首页")
	_页钮(页, "上一页")
	_文字(页, "页码", "", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_页钮(页, "下一页")
	_页钮(页, "末页")
	_钮(页, "查看摊位", "查看摊位", 61.0)
	_钮(页, "查看信息", "查看信息", 61.0)
	var 载 := _文字(页, "载入中", "正在载入资料，请稍候...", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)	# :3259
	载.visible = false		# `:295` 建出来就是 hidden，只有 `showProgress()` 才叫得出来


static func _列表区(页: Control) -> void:
	var 区 := Control.new()
	区.name = "列表"
	区.position = Vector2(窗件["列表"][0], 窗件["列表"][1])
	区.size = Vector2(窗件["列表"][2], 窗件["列表"][3])
	区.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## `clip_contents` 复现原版那一刀：`verticalScrollPolicy = "off"`（`:252`）⇒ 超出的行**看不见**，
	## 而 11 行 × 22 = 242 比 240 多 2px ⇒ 第 11 行的下沿天生被裁掉 2 像素（原版的数，不是我们摆错）。
	区.clip_contents = true
	页.add_child(区)


static func _下拉(页: Control) -> void:
	var 尺: Array = 窗件["下拉"]
	var 钮 := TextureButton.new()
	钮.name = "下拉"
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.texture_normal = load(皮_下拉) as Texture2D
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.position = Vector2(尺[0], 尺[1])
	钮.size = Vector2(尺[2], 尺[3])
	页.add_child(钮)
	var 字 := Label.new()
	字.name = "文字"
	字.position = Vector2(6.0, 2.0)
	字.size = Vector2(尺[2] - 22.0, 16.0)
	字.add_theme_font_size_override("font_size", 12)	# `MComboBox.as:17` `_inputTextFormat` 12 号
	字.add_theme_color_override("font_color", Color.WHITE)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.clip_text = true
	字.text_overrun_behavior = 0
	钮.add_child(字)
	var 箭 := TextureRect.new()
	箭.name = "箭头"
	箭.texture = load(皮_箭头) as Texture2D
	箭.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	箭.stretch_mode = TextureRect.STRETCH_KEEP
	箭.mouse_filter = Control.MOUSE_FILTER_IGNORE
	箭.position = Vector2(尺[2] - 15.0, 6.0)
	箭.size = Vector2(13.0, 8.0)
	钮.add_child(箭)
	字.text = 搜索项[0][0]


static func _钮(页: Control, 名: String, 文: String, 宽: float) -> void:
	var 尺: Array = 窗件[名]
	var 钮 := Button.new()
	钮.name = 名
	钮.text = 文
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.add_theme_font_size_override("font_size", 12)
	钮.add_theme_color_override("font_color", 钮字色)
	## `custom_minimum_size` 必须给到**这一档的宽**：`configure_standard_button` 默认钉的是
	## MButtonF 原生 57×22，37/61 那两档不设就会被顶回 57 宽（原版靠 `MButton3.width` 直接改皮）。
	钮.custom_minimum_size = Vector2(宽, 22.0)
	钮.position = Vector2(尺[0], 尺[1])
	钮.size = Vector2(宽, 22.0)
	页.add_child(钮)


static func _页钮(页: Control, 名: String) -> void:
	var 尺: Array = 窗件[名]
	var 钮 := TextureButton.new()
	钮.name = 名
	钮.texture_normal = load(皮_页钮 % 名) as Texture2D
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.position = Vector2(尺[0], 尺[1])
	钮.size = Vector2(尺[2], 尺[3])
	页.add_child(钮)


static func _文字(页: Control, 名: String, 文: String, 色: Color, 对齐: int) -> Label:
	var 尺: Array = 窗件[名]
	var 字 := Label.new()
	字.name = 名
	字.position = Vector2(尺[0], 尺[1])
	字.size = Vector2(尺[2], 尺[3])
	字.text = 文
	字.add_theme_font_size_override("font_size", 12)	# `cretateLabel():366-378` `_loc4_.size = 12`
	字.add_theme_color_override("font_color", 色)
	字.horizontal_alignment = 对齐
	字.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	字.clip_text = true
	字.text_overrun_behavior = 0
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.add_child(字)
	return 字


static func _图片(页: Control, 名: String, 皮: String) -> TextureRect:
	var 尺: Array = 窗件[名]
	var 面 := TextureRect.new()
	面.name = 名
	面.texture = load(皮) as Texture2D
	面.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	面.stretch_mode = TextureRect.STRETCH_SCALE
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面.position = Vector2(尺[0], 尺[1])
	面.size = Vector2(尺[2], 尺[3])
	页.add_child(面)
	return 面


## `边` 的顺序 = [左, 右, 上, 下]（跟 `原版皮肤表.gd` 的 九宫格 表一致）。
## ⚠ `patch_margin_*` 是 **int** 属性：收到 float 会报 `Invalid assignment ... value of type 'float'`，
## 而且那一句话后面的整条建件都中止（本工程栽过）。
static func _九宫(页: Control, 名: String, 皮: String, 边: Array, 位 := []) -> NinePatchRect:
	var 尺: Array = 窗件[名] if 位.is_empty() else 位
	var 面 := NinePatchRect.new()
	面.name = 名
	面.texture = load(皮) as Texture2D
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面.position = Vector2(float(尺[0]), float(尺[1]))
	面.size = Vector2(442.0, 24.0) if 位.size() == 2 else Vector2(float(尺[2]), float(尺[3]))
	面.patch_margin_left = int(边[0])
	面.patch_margin_right = int(边[1])
	面.patch_margin_top = int(边[2])
	面.patch_margin_bottom = int(边[3])
	页.add_child(面)
	return 面


## ── 接线 ────────────────────────────────────────────────────────────────────

static func _接线(页: Control, 宿主: Node) -> void:
	(页.get_node("搜索钮") as Button).pressed.connect(_点搜索.bind(宿主))
	(页.get_node("刷新钮") as Button).pressed.connect(_点刷新.bind(宿主))
	(页.get_node("首页") as TextureButton).pressed.connect(func(): 请求页(宿主, 0))
	(页.get_node("上一页") as TextureButton).pressed.connect(
			func(): 请求页(宿主, int(宿主._摊位列表走["页"]) - 1))
	(页.get_node("下一页") as TextureButton).pressed.connect(
			func(): 请求页(宿主, int(宿主._摊位列表走["页"]) + 1))
	(页.get_node("末页") as TextureButton).pressed.connect(
			func(): 请求页(宿主, 总页数(宿主._摊位列表走) - 1))
	(页.get_node("查看摊位") as Button).pressed.connect(func(): _看摊(宿主, 选中项(宿主)))
	(页.get_node("查看信息") as Button).pressed.connect(func(): _查信息(宿主, 选中项(宿主)))
	(页.get_node("下拉") as TextureButton).pressed.connect(func(): _弹下拉(宿主))


## ── 数据 → 画面 ─────────────────────────────────────────────────────────────

static func 总页数(走: Dictionary) -> int:
	## `setPageData:360` `_totalPage = Math.ceil(total / 11)` —— **没有 `max(1,…)`**：
	## 一条摊都没有时 `_totalPage = 0`，于是「页码」那一格**根本不写**（`:131` 的 `if (_totalPage > 0)`），
	## 而 下/末 因为 `0 < -1` 不成立而灰着。照抄这两条呆账。
	return int(ceilf(float(int(走.get("总", 0))) / float(每页)))


## 按当前那一页重建行（原版 `setPageData:362` 整表换 `dataProvider` ⇒ 选中也一并没了）。
static func 同步行(宿主: Node) -> void:
	var 页 := 宿主._摊位列表页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	var 走: Dictionary = 宿主._摊位列表走
	var 区 := 页.get_node("列表") as Control
	for 旧 in 区.get_children():
		区.remove_child(旧)
		旧.queue_free()
	var 列表: Array = 走.get("行", []) as Array
	var 留: Array = []
	for 序 in 列表.size():
		var 件 := 行脚本.new()
		件.name = "行%d" % 序
		件.填(列表[序] as Dictionary, 序, int(走.get("页", 0)))
		## 用 lambda **按值捕获**，不用 `.bind`：`被点击`/`被双击` 自己各带一个参数，
		## 而 `Callable.bind()` 是把绑定参数追加在信号参数**之后** ⇒ 三个参数砸进两参函数，
		## 表现就是"点了没反应"（`摊位窗._填行` 那条注释是同一件事）。
		件.被点击.connect(func(_项: Dictionary) -> void: 选中(宿主, 序))
		件.被双击.connect(func(项: Dictionary) -> void: _看摊(宿主, 项))	# `:250` ITEM_DOUBLE_CLICK → viewStallHandler
		件.position = Vector2(0.0, float(序) * 行高)
		区.add_child(件)
		留.append(件)
	宿主._摊位列表行们 = 留
	## 换 dataProvider ⇒ 选中清零（原版这里**没有**一句 `selectedIndex = 0`，
	## 与 `摊位窗._填行:170` 那条「重置到第 0 行」是**两种行为**，别并成一条）。
	走["选"] = -1


## `updateButtonState():109-135` + `showProgress():303-312` + `setPageData:356-359`。
static func 刷新态(宿主: Node) -> void:
	var 页 := 宿主._摊位列表页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	var 走: Dictionary = 宿主._摊位列表走
	var 载 := bool(走.get("载", false))
	var 页码 := int(走.get("页", 0))
	var 总页 := 总页数(走)
	(页.get_node("总数") as Label).text = "总数：%d" % int(走.get("总", 0))
	## 载入中 ⇒ 首/上/下/末/刷新/搜索 六枚一起灰（`showProgress` 点名的就是这六枚），
	## 而**「查看摊位」「查看信息」不在名单里** —— 原版等回帧的时候这两颗照旧能点
	## （点了走 `selectedItem`，而选中项还是上一页那一条，所以它真会发出请求）。
	var 首尾可点 := 页码 > 0
	var 后向可点 := 页码 < 总页 - 1
	for 名 in ["首页", "上一页"]:
		_禁用(宿主, 页.get_node(名), 载 or not 首尾可点)
	for 名 in ["下一页", "末页"]:
		_禁用(宿主, 页.get_node(名), 载 or not 后向可点)
	_禁用(宿主, 页.get_node("刷新钮"), 载)
	_禁用(宿主, 页.get_node("搜索钮"), 载)
	(页.get_node("载入中") as Label).visible = 载
	## 输入框与下拉**不在禁用名单里**（原版 `showProgress` 没碰它们）⇒ 载着也能改词、换类。
	## ⚠ 这里**不重写**下拉的文字：原版 `_searchBox` 显示的是 `selectedItem`，它只跟着**玩家点的**走，
	## 一帧回表都不碰它（`refreshHandler:387` 把 `_quickKey` 塞回 1 也没动显示 ⇒
	## 刷完「显示按摊位名称、实际按物品」这两件事是**分开的**，见 `_点刷新`）。
	if 总页 > 0:
		(页.get_node("页码") as Label).text = "%d / %d" % [页码 + 1, 总页]
	_同步选中(宿主)


static func _同步选中(宿主: Node) -> void:
	var 列表: Array = 宿主._摊位列表行们
	var 序 := int(宿主._摊位列表走.get("选", -1))
	for i in 列表.size():
		var 件 = 列表[i]
		if is_instance_valid(件):
			(件 as Control).设选中(i == 序)


static func _禁用(宿主: Node, 件: Control, 是: bool) -> void:
	if 件 is TextureButton:
		(件 as TextureButton).disabled = 是
	elif 件 is Button:
		(件 as Button).disabled = 是
	## 禁用态 = **同一张图套灰度**。原版八枚钮全是 `MButton3`（`UIWindow.createButton():314` 的返回类型），
	## `showProgress:306-311` 点名的六枚走的都是 `MButton3.updateState():329-339` 的
	## `StyleUtil.getGrayFilter()` —— 不是换一张素材、也不是压暗。所以 `Button` 与 `TextureButton`
	## 两支都要套同一枚材质，别只给翻页那四枚。
	件.material = 宿主.禁用灰度材质() if 是 else null


## ── 请求 / 回帧 ─────────────────────────────────────────────────────────────

## 翻到第 `页`（0 基）：`loadPage():169-181` 干的三件事 = `showProgress()` + 记 `_requestPageIndex`
## + 发一跳。搜索词空 ⇒ `UI.as:800-805` 分流成 `requestStallList`，非空 ⇒ `requestStallSearch`。
static func 请求页(宿主: Node, 页: int) -> void:
	var 走: Dictionary = 宿主._摊位列表走
	走["请页"] = maxi(0, 页)
	走["载"] = true
	关下拉(宿主)
	## 先画（「载入中」要立刻出来，六枚钮要立刻灰）—— `_refresh_current()` 是 deferred，
	## 但发包是同步的：**先改状态再刷新**，回帧再快也不会先画出一张没载入的页。
	同步行(宿主)
	刷新态(宿主)
	var 后 = 宿主._backend
	if 后 == null:
		走["载"] = false
		宿主._show_hint("摊位列表：未连接服务端")
		return
	var 起 := int(走["请页"]) * 每页
	var 词 := String(走.get("词", ""))
	var 成 := false
	if 词 == "":
		成 = 后.request_stall_list(起, 起 + 每页)
	else:
		成 = 后.request_stall_search(int(搜索项[int(走.get("快序", 0))][1]), 词, 起, 起 + 每页)
	if not 成:
		## 发不出去就别把「载入中」挂着等一个永远不来的回帧（原版的 `showProgress` 也撑不住：
		## 它没有超时，但那一跳永远发不出去）。
		走["载"] = false
		宿主._show_hint("摊位列表请求发送失败")
		刷新态(宿主)


## 回帧落地（`窗口管理._on_stall_list` ⇒ `功能窗口.灌摊位列表` 调进来）。
static func 灌入(宿主: Node, 总: int, 行表: Array) -> void:
	var 走: Dictionary = 宿主._摊位列表走
	走["载"] = false
	走["页"] = int(走.get("请页", 0))		# `setPageData:357`：请求页号到这一刻才变成当前页号
	走["总"] = 总
	走["行"] = 行表
	重灌(宿主)


## 关窗 = 原版 `destroyUIWindow`（实例被销毁，下次开窗 `init()` 重新从第 0 页来，
## 关键字框与类目也回到建窗时的样子）。本工程的窗实例**只藏不删** ⇒ 状态在这里清干净，
## 否则下次开窗画的是上一页、框里还留着上次的词。
## ⚠ `open_page` 也走这一条（原版每次 `init` 都是**一只新窗**，等价于"先清再拉第 0 页"）。
static func 复位(宿主: Node) -> void:
	宿主._摊位列表走 = 空态()
	宿主._摊位列表行们 = []
	宿主._摊位列表快序 = 0
	关下拉(宿主)
	var 页 = 宿主._摊位列表页
	if 页 == null or not is_instance_valid(页):
		return
	var 框 := (页 as Control).get_node("输入框") as LineEdit
	框.text = ""
	var 示 := (页 as Control).get_node("下拉/文字") as Label
	示.text = String(搜索项[0][0])


## ── 交互 ────────────────────────────────────────────────────────────────────

static func 选中(宿主: Node, 序: int) -> void:
	宿主._摊位列表走["选"] = 序
	_同步选中(宿主)


static func 选中项(宿主: Node) -> Dictionary:
	var 列表: Array = 宿主._摊位列表行们
	var 序 := int(宿主._摊位列表走.get("选", -1))
	if 序 < 0 or 序 >= 列表.size():
		return {}
	var 件 = 列表[序]
	return (件 as Control).项 if is_instance_valid(件) else {}


static func _看摊(宿主: Node, 行: Dictionary) -> void:
	if 行.is_empty():
		return		# `viewStallHandler:346-352` 第一句就是 `if (_list.selectedItem)`
	var 后 = 宿主._backend
	if 后 == null or not bool(后.get("in_game")):
		宿主._show_hint("查看摊位需要在线")
		return
	if not 后.request_stall_open(int(行.get("payer_id", 0))):
		宿主._show_hint("查看摊位发送失败")
	## 开窗的是回帧 `1296:1:`（`窗口管理._on_stall_state`）⇒ 这里不 `打开("随身摊位")`。


## `viewUserInfoHandler():137-150`：**摊主是自己** ⇒ 开自己的人物窗，**不发包**；
## 别人 ⇒ `clickCharacter(号)`（`:674-677` = `requestCharFullInfo`，本工程 = `头像面板._目标查资料()`，
## 只发 `94:4`；**开窗的是回帧 `58:4`** ⇒ `窗口管理._on_other_char_info`，这里不碰）。
static func _查信息(宿主: Node, 行: Dictionary) -> void:
	if 行.is_empty():
		return
	var 号 := int(行.get("payer_id", 0))
	var 后 = 宿主._backend
	if 后 != null and 号 == int(后.get("character_id")):
		var 管理: Node = 宿主.get_parent()
		if 管理 != null and 管理.has_method("打开"):
			管理.call("打开", "人物")
		return
	if 后 == null or not bool(后.get("in_game")):
		宿主._show_hint("查看信息需要在线")
		return
	if not 后.request_character_info(号):
		宿主._show_hint("查看信息发送失败")


## `searchHandler():97-107`：**空词只弹一句、不发帧、不改状态**；非空才把下拉的 data 与词
## 一起提交，然后 `loadPage(0)`。⚠ 弹的是 `MDialog.showMessageDialog` ⇒ 走 `确认弹.弹消息`，
## 不是窗口状态行（原版那是模态弹窗，玩家点确定才关）。
static func _点搜索(宿主: Node) -> void:
	var 页 := 宿主._摊位列表页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	## ⚠ 判的是**原样等于空串**，不是 `strip_edges()` 之后等空 —— 原版 `:99` 就一句
	## `if (_keyInput.text == "")`。玩家只敲空格照样算"有词"，那一跳由 `request_stall_search`
	## 里的清洗（剔掉分号与空白后为空 ⇒ 返回 false）落回「发送失败」，不是落回这句弹窗。
	var 词 := (页.get_node("输入框") as LineEdit).text
	if 词 == "":
		## 原版 `MDialog.showMessageDialog` ⇒ **一只「确定」，点它只有关窗**，没有后续动作
		## （不是状态行 —— 那是模态弹，玩家不点就一直挡在那儿）。
		确认弹.弹消息(宿主._overlay, "请输入关键字！", func(_码: int) -> void: pass)		# 语言表 :1313
		return
	var 走: Dictionary = 宿主._摊位列表走
	走["快序"] = int(宿主._摊位列表快序)
	走["词"] = 词
	请求页(宿主, 0)


## `refreshHandler():385-390`：`_quickKey = 1`、`_searchKey = ""`，然后**重载当前页**。
## ⚠ 输入框里的字与下拉的选择**都不清**（原版两句 clear 都没有）⇒ 词留在框里但这次搜的是全表。
static func _点刷新(宿主: Node) -> void:
	var 走: Dictionary = 宿主._摊位列表走
	走["快序"] = 0
	走["词"] = ""
	请求页(宿主, int(走.get("页", 0)))


## ── 快速搜索下拉（`MComboBox` 的移植形状 = `家族列表窗._弹下拉` 那一套）────────
## ⚠ 只换 `_quickKey`，**不发请求** —— 原版 `quickSearchHandler():158-162` 全文没有一行
## `addEventListener` 把它挂上去（`:250` 只挂 `ITEM_DOUBLE_CLICK`，`:328` 只挂各钮的 CLICK），
## 也就是**换个类目本身什么都不做**，生效的是下一次点「搜索」。这条照抄，别自作主张加自动查询。

static func _弹下拉(宿主: Node) -> void:
	关下拉(宿主)
	var 页 := 宿主._摊位列表页 as Control
	var 锚 := 页.get_node("下拉") as TextureButton
	var 底 := Panel.new()
	底.name = "摊位列表下拉"
	var 皮 := StyleBoxTexture.new()
	皮.texture = load(皮_菜单底) as Texture2D
	for i in 4:
		皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][i], [5.75, 4.75, 9.75, 11.0][i])
	底.add_theme_stylebox_override("panel", 皮)
	底.mouse_filter = Control.MOUSE_FILTER_STOP
	## ⚠ **必须提层**：`遮罩/主窗口` 一家在树里排在前面，但页里那些 `STOP` 的底图/内容面板
	## 命中顺序比"后加的兄弟节点"更靠得住的是 z —— 不提层时点第三项会打在页上、**静默没反应**
	## （本工程口径：点了没反应＝坏了）。50 = `功能窗口.gd:5730` 那套「压在面板与页签之上」的弹出层数。
	底.z_index = 50
	## 挂到**宿主的遮罩**上，不挂在页里：页每轮回帧整个重建，挂在页里会被连手清掉。
	宿主._overlay.add_child(底)
	var 顶 := 3.0
	for i in 搜索项.size():
		var 项 := Button.new()
		项.name = "项%d" % i
		项.text = String(搜索项[i][0])
		项.flat = true
		项.focus_mode = Control.FOCUS_NONE
		项.add_theme_font_size_override("font_size", 12)
		项.add_theme_color_override("font_color", Color(0.988235, 0.956863, 0.611765, 1))
		项.position = Vector2(3.0, 顶)
		项.size = Vector2(锚.size.x - 6.0, 19.0)
		var 项皮 := StyleBoxTexture.new()
		项皮.texture = load(皮_菜单项) as Texture2D
		for j in 4:
			项皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][j], [2.25, 2.0, 2.5, 2.5][j])
		for 态 in ["normal", "hover", "pressed"]:
			项.add_theme_stylebox_override(态, 项皮)
		项.pressed.connect(_选类.bind(宿主, i))
		底.add_child(项)
		顶 += 19.0 + 3.0
	底.size = Vector2(锚.size.x + 4.0, 顶 + 3.0)
	底.global_position = Vector2(锚.global_position.x, 锚.global_position.y + 锚.size.y + 2.0)
	宿主._摊位列表下拉 = 底


## 选中的是**序号**；`data` 存到宿主上，点搜索时才 take（`_quickKey = _searchBox.selectedItem.data`）。
static func _选类(宿主: Node, 序: int) -> void:
	宿主._摊位列表快序 = 序
	var 页 := 宿主._摊位列表页 as Control
	if 页 != null and is_instance_valid(页):
		(页.get_node("下拉/文字") as Label).text = String(搜索项[序][0])
	关下拉(宿主)


static func 关下拉(宿主: Node) -> void:
	var 盘 = 宿主._摊位列表下拉
	if 盘 != null and is_instance_valid(盘):
		盘.queue_free()
	宿主._摊位列表下拉 = null

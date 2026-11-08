extends Control

## 任务面板 —— 原版 MQuestionWindow / MQuestionInfoPanel 的 1:1 还原。
##
## 真值出处（不许凭截图猜）：
##   com/mxw/uifl/controls/MQuestionWindow.as       窗口与子件几何、页签、按钮
##   com/mxw/uifl/controls/MQuestionInfoPanel.as    右侧上下两块文本的**拼装顺序**
##   com/mxw/uifl/quest/QuestDataManager.as         树条目文字（getQuestNameString）
##   com/mxw/uifl/quest/data/QuestInfoData.as       指标符 require / 奖励 encourage
##   en_US$message_properties.as                    全部文案与内嵌 <font color>
##   UIConfig.as:890/892/926/928                    BORDER_GAP / CONTENT_GAP / UI_BLUE / UI_ORANGE
##
## 文本一律走 原版富文本.gd 转 BBCode，颜色逐项对齐，不要在这里自己写死颜色。

const 富文本 := preload("res://素材/界面/任务界面/脚本/原版富文本.gd")
## 描边数值一律从皮肤表读 —— 它是**会漂的规则值**（09-26 是 3、09-27 改成 2，
## 见 `开发记录（本地）` §3.52.3(d)）。这里原先硬写 3，规则一改就跟主题对不上。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

# ==================== 文案真值 ====================
# 全部逐字照抄 en_US$message_properties.as，含内嵌 <font color>，不要改写。
const 文案 := {
	"QUEST_NAME": "<font color='#ff9100'>任务名称</font><br/>　　",
	"QUEST_DESCRIPTION": "<font color='#ff9100'>任务描述</font><br/>　　",
	"QUEST_TRACK": "<font color='#ff9100'>任务追踪</font>",
	"HANDIN_NPC_QUEST": "<font color='#ff9100'>交任务NPC</font><br/>",
	"MEET_NPC_QUEST": "<font color='#ff9100'>接任务NPC</font><br/>",
	"QUEST_HORTATION": "<font color='#ff9100'>任务奖励</font>",
	"QUEST_XUNZHAO": "寻找：",
	"QUEST_SHAGUAI": "杀怪：",
	"QUEST_SHOWJI": "收集：",
	"QUEST_PUHUO": "捕获：",
	"QUEST_ZHAODAO": "找到",
	"QUEST_WEIZHAODAO": "未找到",
	"QUEST_WEIJIE": "（未接）",
	"QUEST_JINXINGZHONG": "（进行中）",
	"QUEST_KEJIAO": "（可交）",
	"QUEST_ZHUXIANRENWU": "主线任务",
	"QUEST_ZHIXIANRENWU": "支线任务",
	"CHARACTOR_EXP": "经验值",
	"CHARACTOR_GOLD_COIN": "金币",
	"CHARACTOR_BREATH": "精华",
	"QUEST_BTN_GIVE_UP": "放弃",
	"QUEST_BTN_ACCEPT_QUEST": "接任务",
	"QUEST_BTN_TRACK": "在主操作介面同时显示任务追踪介面",
	"QUEST_ACCEPTED_QUEST_PROMPT": "当前没有正在进行的任务！",
	"QUEST_UNACCEPT_QUEST_PROMPT": "当前没有可以开始的任务！",
}

# 原版 QuestInfoData 的任务类型（info.type）→ 分组名
const 类型分组 := {"trunk": "QUEST_ZHUXIANRENWU", "branch": "QUEST_ZHIXIANRENWU"}

# 原版 QuestStatus：0=未接 1=已接 2=已完成（见 com/mxw/data/enums/QuestStatus.as）
const 状态_未接 := 0
const 状态_已接 := 1
const 状态_已完成 := 2

# 页签序号，对应 QuestDataManager.TAB_ACCEPTED / TAB_NOT_ACCEPTED
const 页_当前 := 0
const 页_可接 := 1

## ── 奖励道具那一排（原版 `SimpleItemCell`）──────────────────────────
## 几何真值 `MQuestionInfoPanel.as:176-200`：
##   起 x = 24（`_loc5_ = 24`）、起 y = `下文本.y + 下文本.height + 2`（**文本高**，不是面板高）
##   每格 `+= 宽 + 5`；**先加后判** —— 加完比 `_questionDescPanel.width`，超了才换行
##   （换行把 x 放回 24、y `+= 高 + 5`）。
## 格本体与 周试炼任务窗 那排同源：格底 40×40、图标居中取整、数量 (0,20) 40×20 右对齐。
const 格皮 := "res://素材/界面/原版窗口/通用控件/物品格.png"
const 格边 := 40.0
const 格距 := 5.0
const 奖励起x := 24.0
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

var _表: Dictionary = {}
var _定义表: Dictionary = {}
var _当前页 := 页_当前
var _选中id := ""

@onready var _页签当前: Button = $页签_当前任务
@onready var _页签可接: Button = $页签_可接任务
@onready var _列表内容: VBoxContainer = $任务列表/列表内容
@onready var _详情: Control = $详情
@onready var _上文本: RichTextLabel = $详情/上文本
@onready var _下文本: RichTextLabel = $详情/下文本
@onready var _下底: Panel = $详情/下底
@onready var _复选: Control = $追踪复选项
@onready var _操作按钮: Button = $放弃按钮


func _ready() -> void:
	_表 = 富文本.建表()
	_定义表 = _读任务定义()
	# 页签文案同样是语言表真值
	_页签当前.text = "当前任务"
	_页签可接.text = "可接任务"
	_页签当前.pressed.connect(_切换页.bind(页_当前))
	_页签可接.pressed.connect(_切换页.bind(页_可接))
	_操作按钮.pressed.connect(_操作按钮点击)
	var 会话 := _取会话()
	if 会话 != null:
		if 会话.has_signal("quests_changed"):
			会话.quests_changed.connect(_on_quests_changed)
			if 会话.has_signal("quest_changed"):
				会话.quest_changed.connect(_on_quest_changed)
	_复选文本设置()
	_绑定复选项()
	_绑定链接()
	_操作按钮皮肤()
	刷新()


func _读任务定义() -> Dictionary:
	if not FileAccess.file_exists("res://数据/任务.json"):
		return {}
	var f := FileAccess.open("res://数据/任务.json", FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


func _取会话() -> Node:
	return get_node_or_null("/root/GameSession")


## 原版 `_questBtn = new MButtonF()`（MQuestionWindow.as:234）：皮是 **MButton_up（符号 18，
## 57×22）** 这一族，与本工程默认 Button 的 `按钮.png` 不是同一张（实测 RGB 最大差 84、
## alpha 最大差 118 —— `按钮.png` 上还带九宫格拼接的竖缝）。三档 = 原皮 / +30 / −40
## （`StyleUtil.skinFilters`），派生图在 `素材/界面/专用控件/任务放弃钮*`。
const 操作钮皮 := [
	"res://素材/界面/专用控件/任务放弃钮.png",
	"res://素材/界面/专用控件/任务放弃钮_悬停.png",
	"res://素材/界面/专用控件/任务放弃钮_按下.png",
]


func _操作按钮皮肤() -> void:
	var 槽 := ["normal", "hover", "pressed"]
	for i in 3:
		if not ResourceLoader.exists(操作钮皮[i]):
			continue
		var sb := StyleBoxTexture.new()
		sb.texture = load(操作钮皮[i]) as Texture2D
		# 九宫格只认皮肤表那一份（`按钮` = [7,7,7,7]，`原版皮肤表.gd:138`）
		var 边: Array = 皮肤表.九宫格.get(皮肤表.按钮, [7.0, 7.0, 7.0, 7.0])
		sb.texture_margin_left = float(边[0])
		sb.texture_margin_top = float(边[1])
		sb.texture_margin_right = float(边[2])
		sb.texture_margin_bottom = float(边[3])
		## ⚠ `StyleBoxTexture` 的 content_margin 缺省跟着九宫格边距走（7×2），会把按钮的
		## **最小尺寸**顶成 文字宽+14 / 文字高+14 —— 原版 `MButton3.measure()` 只给 宽=文字+6、高=皮高 22。
		## 结果：位置按 524−宽−5 算、实际尺寸被撑大 ⇒ 右缘 527 > 窗口 524（实测越界 +3、高 27）。
		## 文字居中绘制不依赖它，置 0 让显式 size 生效。
		sb.content_margin_left = 0.0
		sb.content_margin_top = 0.0
		sb.content_margin_right = 0.0
		sb.content_margin_bottom = 0.0
		_操作按钮.add_theme_stylebox_override(槽[i], sb)
	_操作按钮.add_theme_color_override("font_color", Color(皮肤表.按钮色))
	_操作按钮.add_theme_color_override("font_hover_color", Color(皮肤表.按钮色悬停))
	_操作按钮.add_theme_color_override("font_pressed_color", Color(皮肤表.按钮色按下))
	_操作按钮.add_theme_color_override("font_hover_pressed_color", Color(皮肤表.按钮色按下))
	_操作按钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_描边(_操作按钮)


func _复选文本设置() -> void:
	# 原版 MQuestionWindow.as:240 → _checkBox.text = CN.QUEST_BTN_TRACK
	# 文字色取自截图实测 #ff9100（MCheckBoxF 元件内文字）
	var 文本 := _复选.get_node_or_null("文本") as Label
	if 文本 != null:
		文本.text = String(文案["QUEST_BTN_TRACK"])
		文本.add_theme_color_override("font_color", Color("#ff9100"))
		文本.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		文本.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		文本.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
		# 原版 MCheckBox.measure（`_width = upSkin.x + upSkin.width + tf.width + 2`、高 = upSkin.height）
		# ⇒ 这一行是 **19 + 文字宽 + 2 ≈ 225 宽、19 高**。共用组件按短文案做成了 181×24，
		# 这里必须按实测文字宽撑开：否则右半截文字落在「点击区域」外，点字不勾。
		var 字宽 := 文本.get_theme_font("font").get_string_size(
			文本.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var 宽 := 19.0 + 2.0 + 字宽
		文本.position = Vector2(22.0, 1.0)
		文本.size = Vector2(宽 - 22.0, 19.0)
		var 点 := _复选.get_node_or_null("点击区域") as Control
		if 点 != null:
			点.size = Vector2(宽, 24.0)
		_复选.custom_minimum_size = Vector2(宽, 24.0)
		_复选.size = Vector2(宽, 24.0)
	文本 = null


# ==================== 数据 ====================

## 运行时任务列表（当前任务 / 可接任务）
func _取列表() -> Array:
	var 会话 := _取会话()
	if 会话 == null:
		return []
	var 属性 := "accepted_quests" if _当前页 == 页_当前 else "available_quests"
	var 源: Variant = 会话.get(属性)
	return 源 if 源 is Array else []


## 把「运行时条目」与本工程的 数据/任务.json「静态定义」合并。
## 运行时只提供 id / 进度 / completed，文案与几何一律取静态定义（原版真值）。
func _合并(运行时: Dictionary) -> Dictionary:
	var id := String(运行时.get("id", ""))
	var 定: Dictionary = _定义表.get(id, {})
	var 会话 := _取会话()
	if 会话 != null:
		定 = 会话.合并任务定义(运行时, 定)
	var 出 := 运行时.duplicate(true)
	## 在线条目里逐目标的进度叫 `目标进度`（`444` 折成 `kind/key/curr/count`，
	## 见 `后端连接._解目标数据`），而 `_指标符` 照原版 `finishedNum` 的口径读
	## `"进度": {键: 当前}`（键 = 物品号/怪号/NPC 模板号）。以前两边没接上 ⇒
	## 杀怪/收集永远 (0/总)、NPC 永远「未找到」（2026-10-26 用户截图那条）。
	出["进度"] = _进度表(运行时)
	if 定.is_empty():
		return 出
	var info: Dictionary = 定.get("info", {})
	出["定义"] = 定
	出["名称"] = String(info.get("name", 运行时.get("name", "")))
	出["类型"] = String(info.get("type", "branch"))
	var desc: Dictionary = info.get("desc", {})
	出["描述"] = desc
	出["act"] = 定.get("act", {})
	出["check"] = 定.get("check", {})
	出["npc"] = 定.get("npc", {})
	# 接取等级：原版 check["0"].lvmin（QuestInfoData.requestLevel）
	var c0: Dictionary = 定.get("check", {}).get("0", {})
	出["等级"] = int(c0.get("lvmin", 运行时.get("request_level", 0)))
	出["状态"] = 状态_已完成 if bool(运行时.get("completed", false)) else (
		状态_已接 if _当前页 == 页_当前 else 状态_未接
	)
	return 出


## 运行时逐目标进度 → 原版 `进度` 字典（键 = 目标号，值 = 当前数）。
## 离线条目可能已经带 `进度`（本地推进那一套）⇒ 有就原样用；在线条目只有 `目标进度`。
static func _进度表(运行时: Dictionary) -> Dictionary:
	var 旧: Variant = 运行时.get("进度", {})
	if 旧 is Dictionary and not (旧 as Dictionary).is_empty():
		return (旧 as Dictionary).duplicate(true)
	var 表 := {}
	var 列: Variant = 运行时.get("目标进度", [])
	if 列 is Array:
		for 项 in (列 as Array):
			if 项 is Dictionary:
				表[String((项 as Dictionary).get("key", ""))] = int((项 as Dictionary).get("curr", 0))
	return 表


func _全部合并() -> Array:
	var 出: Array = []
	for q in _取列表():
		if q is Dictionary:
			出.append(_合并(q))
	出.sort_custom(func(a, b): return int(a.get("等级", 0)) < int(b.get("等级", 0)))
	return 出


func _定义(id: String) -> Dictionary:
	return _定义表.get(id, {})


# ==================== 刷新 ====================

func 刷新() -> void:
	var 列表 := _全部合并()
	if _选中id.is_empty() or _找(列表, _选中id).is_empty():
		## 默认选中**显示顺序上的第一条**（主线 → 支线 → 其它），不是等级最低那条。
		## 以前取 `列表[0]`，而 `_全部合并` 是按等级升序排的 ⇒ 日环（20 级）排第一，
		## 窗口一打开高亮和详情都落在 daily 行上，而列表显示顺序却是主线在最上面
		## （用户 2026-10-26 截图：开窗就是「日环式任务」，点主线像被跳到别处）。
		_选中id = _首个显示任务(列表)
	_重建列表(列表)
	_刷新详情(_找(列表, _选中id))


## 显示顺序上的第一条叶子（`_重建列表` 的组顺序：trunk → branch → 其它）。
func _首个显示任务(列表: Array) -> String:
	for 类 in ["trunk", "branch", "daily", "weekly", "monthly", "loop", "huodong", "mixin", "banghui"]:
		for q in 列表:
			var 条: Dictionary = q as Dictionary
			if String(条.get("类型", "branch")) == 类:
				return String(条.get("id", ""))
	return String((列表[0] as Dictionary).get("id", "")) if not 列表.is_empty() else ""


func _找(列表: Array, id: String) -> Dictionary:
	for q in 列表:
		if String(q.get("id", "")) == id:
			return q
	return {}


## 原版 MQuestionWindow.drawTreeNow：分支 label = category.name + "（" + count + "）"
## 叶子 label = QuestDataManager.getQuestNameString → "[等级]名称（状态）"（带颜色）
func _重建列表(列表: Array) -> void:
	# ⚠️ 必须**先 remove_child 再 queue_free**：queue_free 是延迟的，旧节点还在树上，
	# 新建的同名子节点会被 Godot 自动改名（分组_主线 → 分组_主线2），折叠就找不到了。
	for c in _列表内容.get_children():
		_列表内容.remove_child(c)
		c.queue_free()
	# 按类型分组（原版 getPlaces 按 category.order 排序；trunk 在前）
	var 分组 := {}
	for q in 列表:
		var t := String(q.get("类型", "branch"))
		if not 分组.has(t):
			分组[t] = []
		分组[t].append(q)
	var 顺序 := ["trunk", "branch"]
	for t in 分组.keys():
		if not 顺序.has(t):
			顺序.append(t)
	for t in 顺序:
		if not 分组.has(t):
			continue
		var 组: Array = 分组[t]		# 原版 drawTreeNow：每个 category 是一个分支节点，子条目挂在分支下。
		# 用容器装起来，折叠时直接隐藏容器里的子行即可。
		var 容器 := VBoxContainer.new()
		容器.name = "分组_" + _组短名(t)
		容器.add_theme_constant_override("separation", 0)
		_列表内容.add_child(容器)
		容器.add_child(_做组头(_分组名(t) + "（" + str(组.size()) + "）", 容器))
		for q in 组:
			容器.add_child(_做任务行(q))
	_刷新空提示(列表.is_empty())


## 原版 MQuestionWindow.drawTreeNow 的空态（`:550-566`）：一条**居中的提示**压在树区上：
##   x = frontBackground.x + CONTENT_GAP = 13、宽 = frontBackground.width − 16 = 498；
##   y = (tree.height − textHeight − 6)/2 + tree.y；粗体 14、UIConfig.UI_BLUE(#1E90FF)、带辉光。
## 文案两档：当前任务页「当前没有正在进行的任务！」/ 可接页「当前没有可以开始的任务！」。
var _空提示: Label


func _刷新空提示(空: bool) -> void:
	if not 空:
		if _空提示 != null:
			_空提示.visible = false
		return
	if _空提示 == null:
		_空提示 = Label.new()
		_空提示.name = "空提示"
		_空提示.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_空提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_空提示.add_theme_font_size_override("font_size", 14)
		_空提示.add_theme_color_override("font_color", Color("#1e90ff"))
		var 变 := FontVariation.new()
		## 取**已在树上的**正文所用的那份主题字体 —— 新建的 Label 还没进树，get_theme_font 会拿到引擎默认字体。
		变.base_font = _上文本.get_theme_font("normal_font")
		变.variation_embolden = 0.7
		_空提示.add_theme_font_override("font", 变)
		_描边(_空提示)
		add_child(_空提示)
	_空提示.text = String(文案["QUEST_UNACCEPT_QUEST_PROMPT"]
			if _当前页 == 页_可接 else 文案["QUEST_ACCEPTED_QUEST_PROMPT"])
	_空提示.position = Vector2(13.0, (288.0 - 20.0 - 6.0) / 2.0 + 36.0)
	_空提示.size = Vector2(498.0, 20.0)
	_空提示.visible = true


func _组短名(t: String) -> String:
	return "主线" if t == "trunk" else ("支线" if t == "branch" else t)


func _分组名(t: String) -> String:
	# 原版分组名来自 category.name，trunk/branch 分别对应主线/支线
	return String(文案.get(String(类型分组.get(t, "")), t))


## 用户 2026-09-26 指定的行素材（与场景里预置的节点用同一套，保证编辑器与游戏一致）
const 父行底贴图 := "res://素材/界面/专用控件/任务条背景.png"
const 折叠减贴图 := "res://素材/界面/原版窗口/通用控件/减少按钮.png"
const 折叠加贴图 := "res://素材/界面/原版窗口/通用控件/增加按钮.png"
## 原版 QuestionTreeItemRenderer：
##   分支行 `_textField.x = 图标x2 + 图标宽18 + CONTENT_GAP8 = 28`、标签 y=1；
##   叶子行 `_textField.x = 16`、`_label.width = owner.width − x − 24 = 170`、标签 y=0；
##   行底 `_background.width = owner.width − 20 = 190`，分支高 24 @ y=−1、叶子高 20 @ y=0。
##   owner = Tree.width = treeSkin.width − 8 = 210（MQuestionWindow.as:226）。
const 行文字X := 28.0
const 叶文字X := 16.0
const 叶文字宽 := 170.0
const 行底宽 := 190.0
const 叶底高 := 20.0
const 行选中底贴图 := "res://素材/界面/原版窗口/通用控件/选中条1.png"


func _做任务行(q: Dictionary) -> Control:
	# 原版 QuestionTreeItemRenderer.listData 的叶子分支（:76-93）：
	#   未选底 = BlankSkinF（1×1 全透明）；选中底 = MSelected_background1(705)
	#   拉到 190×20 贴行顶；文字 x=16、白/蓝/绿按状态、黑描边、手型。
	#   ⚠ 以前整行四态都铺 `菜单按钮亮` ⇒ 没选中的行也像按下的钮（原版只有选中那一行有底）。
	var 行 := Control.new()
	行.custom_minimum_size = Vector2(0, 24)
	行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if String(q.get("id", "")) == _选中id and ResourceLoader.exists(行选中底贴图):
		var 底 := TextureRect.new()
		底.name = "选中底"
		底.texture = load(行选中底贴图) as Texture2D
		底.position = Vector2.ZERO
		底.size = Vector2(行底宽, 叶底高)
		底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		底.stretch_mode = TextureRect.STRETCH_SCALE
		底.mouse_filter = Control.MOUSE_FILTER_IGNORE
		行.add_child(底)
	var 字 := Button.new()
	字.name = "文字"
	字.text = _任务名文本(q)
	字.alignment = HORIZONTAL_ALIGNMENT_LEFT
	字.focus_mode = Control.FOCUS_NONE
	字.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var 色 := 状态色(int(q.get("状态", 状态_未接)))
	## 文字盒 = 整行去掉左 16 / 下 4 ⇒ 高 20，与原版 `_textField.y = 0`、`height = 20` 一致
	var 空 := StyleBoxEmpty.new()
	空.content_margin_left = 叶文字X
	空.content_margin_right = 24
	空.content_margin_top = 0
	空.content_margin_bottom = 4
	for 态 in ["normal", "hover", "pressed", "disabled", "focus"]:
		字.add_theme_stylebox_override(态, 空)
	字.add_theme_color_override("font_color", 色)
	字.add_theme_color_override("font_hover_color", 色)
	字.add_theme_color_override("font_pressed_color", 色)
	_描边(字)
	字.add_theme_font_size_override("font_size", 12)
	字.pressed.connect(_选任务.bind(String(q.get("id", ""))))
	行.add_child(字)
	字.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return 行


func _样式(贴图路径: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	if ResourceLoader.exists(贴图路径):
		sb.texture = load(贴图路径) as Texture2D
	return sb


func _贴图钮(贴图路径: String, 位: Vector2, 尺寸: Vector2) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists(贴图路径):
		t.texture = load(贴图路径) as Texture2D
	t.position = 位
	t.size = 尺寸
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _描边(c: Control) -> void:
	# 工程硬规则：所有文字黑描边 3、阴影关掉（用户 2026-09-25）
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	c.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)


func 状态色(状态: int) -> Color:
	# QuestDataManager.getQuestNameString：未接→#1e90ff 已接→#ffffff 已交→#00ff00
	match 状态:
		状态_未接:
			return Color("#1e90ff")
		状态_已完成:
			return Color("#00ff00")
		_:
			return Color("#ffffff")


## 原版 QuestDataManager.getQuestNameString
func _任务名文本(q: Dictionary) -> String:
	return "[%d]%s%s" % [int(q.get("等级", 0)), String(q.get("名称", "")), _状态后缀(int(q.get("状态", 0)))]


func _状态后缀(状态: int) -> String:
	match 状态:
		状态_未接:
			return String(文案["QUEST_WEIJIE"])
		状态_已完成:
			return String(文案["QUEST_KEJIAO"])
		_:
			return String(文案["QUEST_JINXINGZHONG"])


func _切换页(页: int) -> void:
	if _当前页 == 页:
		_页签当前.button_pressed = _当前页 == 页_当前
		_页签可接.button_pressed = _当前页 == 页_可接
		return
	_当前页 = 页
	_页签当前.button_pressed = _当前页 == 页_当前
	_页签可接.button_pressed = _当前页 == 页_可接
	_选中id = ""
	刷新()


func _选任务(id: String) -> void:
	_选中id = id
	刷新()
	# 原版「可接任务」页把操作按钮**隐藏**（`MQuestionWindow.updateQuestButton:326-340`），
	# 靠点条目 `MovePlayerToNpc` 走到发任务 NPC 跟前再接 —— 这一跳就是"点击任务自动寻路"。
	# 同图真寻路（共用 HUD 上那段），跨图由 HUD 明确报"还没接"，不在这里假装。
	if _当前页 != 页_可接:
		return
	for 条 in _全部合并():
		var 行: Dictionary = 条 as Dictionary
		if String(行.get("id", "")) != id:
			continue
		var 发 := int((行.get("npc", {}) as Dictionary).get("0", 0))
		if 发 <= 0:
			return
		var HUD := get_tree().get_first_node_in_group("game_hud")
		if HUD != null and HUD.has_method("前往NPC"):
			HUD.call("前往NPC", 发)
		return


func _on_quests_changed(_接受: Array, _可接: Array) -> void:
	刷新()


func _on_quest_changed(_q: Dictionary) -> void:
	刷新()


# ==================== 详情文本 ====================

func _刷新详情(q: Dictionary) -> void:
	_当前任务 = q
	if q.is_empty():
		_上文本.text = ""
		_下文本.text = ""
		_操作按钮.visible = false
		_清奖励格()
		return
	_重绘详情()
	_操作按钮.text = String(文案["QUEST_BTN_ACCEPT_QUEST"] if _当前页 == 页_可接 else 文案["QUEST_BTN_GIVE_UP"])
	## 原版 MButton3.measure：`宽度 = tf.width + 6`（isScale9Grid）、位置
	## `x = 524 − 宽 − 5`（MQuestionWindow.as:338）、高 = 皮高 22 ⇒ 「放弃」是 30×22，「接任务」54×22。
	## 不按文字重算是把整条 57 宽的天然皮直接摆上（多出 27px，右边贴不到边距）。
	var 字宽 := _操作按钮.get_theme_font("font").get_string_size(
			_操作按钮.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var 宽 := 字宽 + 6.0
	_操作按钮.size = Vector2(宽, 22.0)
	_操作按钮.position = Vector2(524.0 - 宽 - 5.0, 340.0)
	_操作按钮.visible = true


## 重画两段富文本。**悬停链接变化时必须重画** —— Godot 的 RichTextLabel 没有
## 逐链接的 hover 颜色，只能把悬停的那处重新染成红色再整体写回。
## 奖励那一排格子的 y 挂在**正文实际排出来的高度**下面 ⇒ 排格子必须等这一帧
## 文本布局算完，所以走 `call_deferred`（同帧读 `get_content_height()` 会拿到旧值）。
func _重绘详情() -> void:
	if _当前任务.is_empty():
		return
	# 命名空间隔开上下半：两段各自有"@0"，否则会互相染色
	_上文本.text = 富文本.转换(_上半(_当前任务), _表, _悬停链接, _按下链接, "上")
	_下文本.text = 富文本.转换(_下半(_当前任务), _表, _悬停链接, _按下链接, "下")
	_排奖励格.call_deferred()


## 原版 MQuestionInfoPanel.drawView 上半：
##   <font color='#ffffff'> + QUEST_NAME + 名字 + <br/> + QUEST_DESCRIPTION + desc[状态] + </font>
func _上半(q: Dictionary) -> String:
	var s := "<font color='#ffffff'>"
	s += String(文案["QUEST_NAME"])
	s += String(q.get("名称", "")) + "<br/>"
	s += String(文案["QUEST_DESCRIPTION"])
	s += _描述(q)
	return s + "</font>"


## MQuestionInfoPanel：_loc2_ = [descNotAccepted, descAccepted, descCompleted][status]
func _描述(q: Dictionary) -> String:
	var d: Variant = q.get("描述", {})
	if not (d is Dictionary):
		return String(q.get("description", ""))
	match int(q.get("状态", 0)):
		状态_已完成:
			return String(d.get("2", ""))
		状态_已接:
			return String(d.get("1", ""))
		_:
			return String(d.get("0", ""))


## 原版 MQuestionInfoPanel.drawView 下半：
##   当前任务页： QUEST_TRACK + <br/>　　+ insertZhiBiaoFu(require) + <br/>
##                HANDIN_NPC_QUEST + "　　<font color='#1e90ff'><a …>名字</a></font><br/>"
##                QUEST_HORTATION + "<br/>　　" + 奖励
##   可接任务页： MEET_NPC_QUEST + "　　<font color='#1e90ff'>…</font><br/>"
func _下半(q: Dictionary) -> String:
	var s := "<font color='#ffffff'>"
	if _当前页 == 页_当前:
		var 指标 := _指标符(q)
		if not 指标.is_empty():
			s += String(文案["QUEST_TRACK"]) + "<br/>　　" + _换行缩进(指标) + "<br/>"
		# 原版 MQuestionInfoPanel:140 —— 这行也是链接：
		#   "　　<font color='#1e90ff'><a href=\"event:npc" + endNpcId + "\">" + 名字 + "</a></font><br/>"
		s += String(文案["HANDIN_NPC_QUEST"])
		s += "　　" + _蓝名链接(int(q.get("npc", {}).get("1", 0))) + "<br/>"
	else:
		# 原版 MQuestionInfoPanel:145 —— 接任务NPC 同样是链接
		s += String(文案["MEET_NPC_QUEST"])
		s += "　　" + _蓝名链接(int(q.get("npc", {}).get("0", 0))) + "<br/>"
	## 奖励这一段在原版是 **if/else 之外**（`:147`）⇒ 已接页与可接页**都要挂**。
	## 门槛是「有文字奖励 **或** 有奖励道具」：1009 那种只给装备、不给经验金币的任务，
	## 以前整行标题都不出现，只剩格子没名字。
	var 奖励 := _奖励(q)
	if not 奖励.is_empty() or _奖励物品(q).size() > 0:
		s += String(文案["QUEST_HORTATION"])
		if not 奖励.is_empty():
			s += "<br/>　　" + _换行缩进(奖励)
	return s + "</font>"


## 蓝名链接：<font color='#1e90ff'><a href='event:npc<id>'>[地图]名字</a></font>
## 悬停时由 原版富文本._套悬停色 统一改红
func _蓝名链接(npc_id: int) -> String:
	return "<font color='#1e90ff'><a href='event:npc%d'>%s</a></font>" % [npc_id, _npc全名(npc_id)]


## 原版 MQuestionInfoPanel.insertZhiBiaoFu：把 \n 换成 \n　　，并去掉结尾的 \n
func _换行缩进(文本: String) -> String:
	var s := 文本
	if s.ends_with("\n"):
		s = s.substr(0, s.length() - 1)
	return s.replace("\n", "\n　　")


## 原版 QuestInfoData.setItemRequire 的三段模板，逐句照抄。
## 返回行间以 \n 分隔，末尾带一个 \n（与 AS3 的 "\n" 结尾一致）。
static func _指标符(q: Dictionary) -> String:
	var check: Dictionary = q.get("check", {})
	var 阶段: Dictionary = check.get("1", {})
	if 阶段.is_empty():
		阶段 = check.get("0", {})
	var 进度: Dictionary = q.get("进度", {})
	var s := ""
	# 物品： QUEST_SHOWJI + 绿名 + 红/绿(已完成/总数)
	for 分组名 in ["item", "items"]:
		for it in _列(阶段.get(分组名, [])):
			## ⚠ `String(数字)` 在 GDScript 里**没有这个构造**（运行期直接 `Invalid call`，
			##   整段 `_下半` 就断在这里 ⇒ 选了杀怪/收集类任务，右侧详情还留着上一条的文字）。
			##   而 `str(浮点)` 又会给出 "1000001.0"（JSON 把数字解成 float）⇒ 必须走 int 再 str。
			var iid := str(int(it.get("id", 0)))
			var 总 := int(it.get("count", 1))
			var 已 := int(进度.get(iid, 0))
			s += String(文案["QUEST_SHOWJI"]) + _绿(富文本.物品名(iid)) + _计数(已, 总) + "\n"
	# 怪物： QUEST_SHAGUAI
	for 分组名 in ["mob", "mobs"]:
		for m in _列(阶段.get(分组名, [])):
			var mid := str(int(m.get("id", 0)))	# 同上：`String(数字)` 无效
			var 总2 := int(m.get("count", 1))
			var 已2 := int(进度.get(mid, 0))
			var 怪链接 := "<font color='#00ff00'><a href='event:mob%d:%d'>%s</a></font>" % [int(m.get("map", 0)), int(mid), 富文本.怪物名(mid)]
			s += String(文案["QUEST_SHAGUAI"]) + 怪链接 + _计数(已2, 总2) + "\n"
	# NPC： QUEST_XUNZHAO + 绿名（带链接）+ （找到 / 未找到）
	for 分组名 in ["npc", "npcs"]:
		for n in _列(阶段.get(分组名, [])):
			var nid := int(n.get("id", 0))
			var 已3 := int(进度.get(str(nid), 0))
			var 总3 := int(n.get("count", 1))
			var 完成 := 已3 >= 总3
			s += String(文案["QUEST_XUNZHAO"])
			s += "<font color='#00ff00'><a href='event:npc" + str(nid) + "'>" + _npc全名(nid) + "</a></font>"
			s += "<font color='" + ("#00ff00'>(" if 完成 else "#ff0000'>(") + String(文案["QUEST_ZHAODAO"] if 完成 else 文案["QUEST_WEIZHAODAO"]) + ")</font>\n"
	return s


static func _列(v: Variant) -> Array:
	if v is Array:
		return v
	if v is Dictionary:
		# AMF3 的数组反序列化成 {"0":…,"1":…}
		var 出: Array = []
		for k in v.keys():
			出.append(v[k])
		return 出
	return []


static func _绿(文本: String) -> String:
	return "<font color='#00ff00'>" + 文本 + "</font>"


## 原版用 COLOR_COUNT_ABSENCE(#ff0000) / COLOR_COUNT_ENOUGH(#00ff00) 包住 "(已/总)"
static func _计数(已: int, 总: int) -> String:
	var 色 := "#00ff00" if 已 >= 总 else "#ff0000"
	return "<font color='" + 色 + "'>(" + str(已) + "/" + str(总) + ")</font>"


## 原版 QuestInfoData.getEncourage：act["1"].exp / money / zq，逐项一行 "名称：值"
static func _奖励(q: Dictionary) -> String:
	var act: Dictionary = q.get("act", {})
	var a: Dictionary = act.get("1", {})
	var 行: Array = []
	if a.has("exp"):
		行.append(String(文案["CHARACTOR_EXP"]) + "：" + str(int(a["exp"])))
	if a.has("money"):
		行.append(String(文案["CHARACTOR_GOLD_COIN"]) + "：" + str(int(a["money"])))
	if a.has("zq"):
		行.append(String(文案["CHARACTOR_BREATH"]) + "：" + str(int(a["zq"])))
	return "\n　　".join(行)


## 原版 `QuestInfoData.getEncourage:271-292` 里那两份 `encourageItems`：
## **先 item 后 equip**（顺序就是 AS3 里那两段 for each 的顺序），每条
## `没写 job 这个键 ⇒ 不限职业`；写了 job 就必须等于玩家职业。
## 服务端 `fake_flash_server.py:56646` 的 `reward.job in (0, 职业)` 是同一条口径。
func _奖励物品(条: Dictionary) -> Array:
	var 段 = 条.get("act")
	if not (段 is Dictionary):
		return []
	var 二 = (段 as Dictionary).get("1")
	if not (二 is Dictionary):
		return []
	var a: Dictionary = 二
	var 职 := _玩家职业()
	var 出: Array = []
	for 组 in ["item", "equip"]:
		for it in _列(a.get(组, [])):
			if it.has("job") and int(it.get("job", 0)) != 0 and int(it["job"]) != 职:
				continue
			出.append({"id": int(it.get("id", 0)), "count": int(it.get("count", 1))})
	return 出


func _玩家职业() -> int:
	var 会 := _取会话()
	if 会 == null:
		return 0
	return int((会.get("player_stats") as Dictionary).get("job", 0))


func _清奖励格() -> void:
	## ⚠ **先 remove_child 再 queue_free**（本文件 `_重建列表` 那条老坑的第二次）：
	##   queue_free 是延迟到帧尾的，旧格还挂在树上 ⇒ 紧接着 add_child 的同名新格会被
	##   Godot 自动改名成 `@TextureRect@10`，下一次清理按名字就找不到它了（越攒越多）。
	for 子 in _详情.get_children():
		if String(子.name).begins_with("奖励格") or String(子.name).begins_with("物品提示_任务奖励"):
			_详情.remove_child(子)
			子.queue_free()


## 原版 `MQuestionInfoPanel.drawView:176-200`：起 x = 24、
## 起 y = `下文本.y + 文本高 + 2`（**文本实际排出来的高**，不是面板高），
## 每格 `+= 40 + 5`，**先加后判** —— 加完比 `_questionDescPanel.width`（本工程 = `下底` 的宽）
## 超了才换行，换行把 x 放回 24、y `+= 40 + 5`。
func _排奖励格() -> void:
	_清奖励格()
	if _当前任务.is_empty():
		return
	var 物 := _奖励物品(_当前任务)
	if 物.is_empty():
		return
	var x := 奖励起x
	var y := _下文本.position.y + float(_下文本.get_content_height()) + 2.0
	for i in 物.size():
		var 项: Dictionary = 物[i]
		var 格 := _奖励格(int(项["id"]), int(项["count"]), i)
		格.position = Vector2(x, y)
		_详情.add_child(格)
		x += 格边 + 格距
		if x > _下底.size.x:
			x = 奖励起x
			y += 格边 + 格距


## `SimpleItemCell`（`DailyQuestWindow.as:240` 那一族）：格底 40×40、图标居中取整
## （`SimpleItemCell.as:164-165`）、数量在 (0,20) 40×20 **右对齐**（`:136-144`）。
func _奖励格(号: int, 量: int, 序: int) -> Control:
	var 格 := TextureRect.new()
	格.name = "奖励格%d" % (序 + 1)
	格.texture = load(格皮) as Texture2D
	格.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	格.stretch_mode = TextureRect.STRETCH_SCALE
	格.size = Vector2(格边, 格边)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var 路 := 游戏数据.item_icon_path(号)
	if 路 != "" and ResourceLoader.exists(路):
		var 图 := TextureRect.new()
		图.name = "图标"
		图.texture = load(路) as Texture2D
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var 寸: Vector2 = 图.texture.get_size()
		图.position = Vector2(roundf((格边 - 寸.x) / 2.0), roundf((格边 - 寸.y) / 2.0))
		图.size = 寸
		格.add_child(图)
	var 标 := Label.new()
	标.name = "数量"
	标.text = str(量)
	标.position = Vector2(0.0, 20.0)
	标.size = Vector2(40.0, 20.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	标.add_theme_font_size_override("font_size", 12)
	标.add_theme_color_override("font_color", Color(1, 1, 1))
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(标)
	_接格提示(格, 号, 序)
	return 格


## 悬停出物品说明 —— 与 周试炼任务窗 那排同一套（原版 `SimpleItemCell` 自带 MToolTip）。
func _接格提示(格: Control, 号: int, 序: int) -> void:
	var 节点名 := "物品提示_任务奖励%d" % (序 + 1)
	格.mouse_entered.connect(func() -> void:
		var 框 := _详情.get_node_or_null(节点名) as Control
		if 框 == null:
			框 = 物品提示场景.instantiate() as Control
			框.name = 节点名
			框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_详情.add_child(框)
		var 会 := _取会话()
		var 级 := 0
		var 存 := 0
		if 会 != null:
			级 = int((会.get("player_stats") as Dictionary).get("level", 0))
			for 项 in (会.get("inventory") as Array):
				if int((项 as Dictionary).get("id", 0)) == 号:
					存 += int((项 as Dictionary).get("quantity", 0))
		框.设置(str(号), 存, 级, 游戏数据.item(号))
		框.visible = true
		框.贴到鼠标(_详情.get_local_mouse_position(), get_viewport().get_visible_rect().size))
	格.mouse_exited.connect(func() -> void:
		var 框 := _详情.get_node_or_null(节点名) as CanvasItem
		if 框 != null:
			框.visible = false)


## StringTool.getNpcNameWidthMapName → "[" + 地图名 + "]" + NPC名
static func _npc全名(id: int) -> String:
	return 富文本.NPC全名(str(id))


# ==================== 交互 ====================

# ==================== 链接交互（原版 <a href='event:...'>） ====================
# 原版 StructuredText.setStyle()：
#   a:link   → 下划线
#   a:hover  → 下划线 + #FF0000
#   a:active → 下划线 + #B19B50
# 所以面板上**所有**链接（描述的绿名、追踪的绿名、交任务/接任务NPC 的蓝名）
# 悬停都应变红，并且可点击。

var _当前任务: Dictionary = {}
var _悬停链接 := ""
var _按下链接 := ""


func _绑定链接() -> void:
	for 标 in [_上文本, _下文本]:
		if 标 == null:
			continue
		标.meta_hover_started.connect(_链接悬停)
		标.meta_hover_ended.connect(_链接离开)
		标.meta_clicked.connect(_链接点击)
		# 原版 a:active = #B19B50：只有"悬停在该段上并按住左键"时生效。
		# RichTextLabel 没有逐链接的 pressed 信号，只能自己收 gui_input 记按键态。
		标.gui_input.connect(_链接按键.bind(标))


func _链接按键(ev: InputEvent, _标: RichTextLabel) -> void:
	var e := ev as InputEventMouseButton
	if e == null or _悬停链接.is_empty():
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	# 按下 → 当前悬停的那一段显示 a:active 色；松开 → 回到 a:hover 色
	var 新 := _悬停链接 if e.pressed else ""
	if 新 == _按下链接:
		return
	_按下链接 = 新
	_重绘详情()


func _链接悬停(url: String) -> void:
	var u := String(url)
	if _悬停链接 == u:
		return
	_悬停链接 = u
	_设手型(true)
	_重绘详情()


func _链接离开(_url: String) -> void:
	if _悬停链接.is_empty():
		return
	_悬停链接 = ""
	_按下链接 = ""
	_设手型(false)
	_重绘详情()


func _设手型(开: bool) -> void:
	var 形 := Control.CURSOR_POINTING_HAND if 开 else Control.CURSOR_ARROW
	for 标 in [_上文本, _下文本]:
		if 标 != null:
			标.mouse_default_cursor_shape = 形


func _链接点击(url: String) -> void:
	# meta 回传的是 _编号链接 加过 "@序号" 的 token，先还原成原版 url
	var u := 富文本.解链接(String(url))
	var id := _取数字段(u)
	if u.begins_with("event:npc"):
		_点NPC(int(id))
	elif u.begins_with("event:mob"):
		## 新格式 `event:mob<图>:<怪号>`（与追踪栏同一个链接口径）；旧格式只有怪号时退化为提示。
		var 段 := u.substr("event:mob".length()).split(":")
		if 段.size() >= 2:
			var 图 := int(段[0])
			var 怪 := int(段[1])
			var HUD := get_tree().get_first_node_in_group("game_hud")
			if HUD != null and HUD.has_method("走向怪"):
				HUD.call("走向怪", 图, 怪)
				return
		_提示("目标：%s" % 富文本.怪物名(id))
	elif u.begins_with("event:map"):
		_提示("地图：%s" % 富文本.地图名(id))
	elif u.begins_with("event:item") or u.begins_with("item"):
		_提示("物品：%s" % 富文本.物品名(id))
	else:
		_提示(u)


func _取数字段(s: String) -> String:
	var 出 := ""
	for i in s.length():
		var c := s[i]
		if c >= "0" and c <= "9":
			出 += c
		elif not 出.is_empty():
			break
	return 出


## 原版点 NPC 链接 = API.characterHandler.MovePlayerToNpc(npcId)。
## 本机没有"自动寻路到指定 NPC"的接口，所以：当前地图上有这个 NPC 就开对话，
## 不在本图就给出可见提示（不假装已经走过去）。
func _点NPC(npc_id: int) -> void:
	var 键 := "%08d" % npc_id
	var 实 := _找地图实体()
	if 实 != null:
		var 表: Variant = 实.get("_entities")
		if 表 is Array:
			for e in 表:
				if e == null or not is_instance_valid(e):
					continue
				if String(e.get("kind")) != "n":
					continue
				var 实体id := String(e.get("entity_id"))
				if 实体id == 键 or 实体id == str(npc_id):
					实.call("_open_dialog", 实体id)
					return
			_提示("该 NPC 不在此地图：%s" % 富文本.NPC全名(str(npc_id)))
			return
	_提示("前往：%s" % 富文本.NPC全名(str(npc_id)))


func _找地图实体() -> Node:
	var 根: Node = get_tree().current_scene
	if 根 == null:
		根 = get_tree().root
	for n in 根.find_children("*", "", true, false):
		var sc: Variant = n.get_script()
		if sc != null and String(sc.resource_path).ends_with("地图实体.gd"):
			return n
	return null


func _提示(文本: String) -> void:
	var 会话 := _取会话()
	if 会话 != null and 会话.has_signal("notification_requested"):
		会话.emit_signal("notification_requested", 文本)


# ==================== 折叠（原版 BranchButton） ====================

func _做组头(文本: String, 组容器: Control) -> Control:
	# 原版 QuestionTreeItemRenderer 的分支行（:49-75）：BranchBgSkinF 拉到 190×24 且 y=−1
	# （上沿压住上一行 1px）；BranchButton 18×18 在 (2,2)；文字 x=28、y=1、高 20、橙字。
	var 头 := Control.new()
	头.name = "组头"
	头.custom_minimum_size = Vector2(0, 24)
	头.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 底 := TextureRect.new()
	底.name = "底板"
	if ResourceLoader.exists(父行底贴图):
		底.texture = load(父行底贴图) as Texture2D
	底.position = Vector2(0, -1)
	底.size = Vector2(行底宽, 24)
	底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	底.stretch_mode = TextureRect.STRETCH_SCALE
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	头.add_child(底)
	var 钮 := Button.new()
	钮.name = "折叠钮"
	钮.focus_mode = Control.FOCUS_NONE
	钮.position = Vector2(2, 2)
	钮.size = Vector2(18, 18)
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.tooltip_text = 文本
	_设折叠图标(钮, false)
	钮.pressed.connect(_切换折叠.bind(组容器, 钮))
	头.add_child(钮)
	var 标 := Label.new()
	标.name = "文本"
	标.text = 文本
	标.position = Vector2(行文字X, 1)
	标.size = Vector2(叶文字宽, 叶底高)
	标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_描边(标)
	标.add_theme_color_override("font_color", Color("#ff9100"))
	标.add_theme_font_size_override("font_size", 12)
	头.add_child(标)
	return 头


## 展开态图标 = 减少按钮(−)，收起态 = 增加按钮(＋)
func _设折叠图标(钮: Button, 收起: bool) -> void:
	var sb := _样式(折叠加贴图 if 收起 else 折叠减贴图)
	钮.add_theme_stylebox_override("normal", sb)
	钮.add_theme_stylebox_override("hover", sb)
	钮.add_theme_stylebox_override("pressed", sb)


func _切换折叠(组容器: Control, 钮: Button) -> void:
	if 组容器.get_child_count() <= 1:
		return
	var 当前可见 := (组容器.get_child(1) as Control).visible
	for i in range(1, 组容器.get_child_count()):
		var c := 组容器.get_child(i) as Control
		if c != null:
			c.visible = not 当前可见
	_设折叠图标(钮, 当前可见)


# ==================== 复选项（原版 MCheckBox） ====================

func _绑定复选项() -> void:
	var 标记 := _复选.get_node_or_null("标记") as CanvasItem
	var 会话 := _取会话()
	var 开 := true
	if 会话 != null:
		var 设置: Variant = 会话.get("game_settings")
		if 设置 is Dictionary:
			开 = bool(设置.get("show_quest_tracker", true))
	if 标记 != null:
		标记.visible = 开
	var 点击 := _复选.get_node_or_null("点击区域") as Button
	if 点击 == null:
		return
	点击.tooltip_text = String(文案["QUEST_BTN_TRACK"])
	点击.pressed.connect(_切换追踪)


## 原版 MQuestionWindow.__onTrackBtnClick → 存 isShowQuestTrackWindow，同时开关主界面的任务追踪面板。
## ⚠️ 这里**不能**用 会话.update_setting()：它会 emit settings_changed，
##    而 功能窗口.gd:231 把这个信号接到了 _refresh_current → _render_page，
##    于是整个任务页被重建（表现为"点一下窗口闪没"）。所以直接改字典。
func _切换追踪() -> void:
	var 标记 := _复选.get_node_or_null("标记") as CanvasItem
	var 新 := true
	if 标记 != null:
		新 = not 标记.visible
		标记.visible = 新
	var 会话 := _取会话()
	if 会话 != null:
		var 设置: Variant = 会话.get("game_settings")
		if 设置 is Dictionary:
			设置["show_quest_tracker"] = 新
	_开关追踪面板(新)


## 主界面右下那条「任务追踪」条的显隐（原版 isShowQuestTrackWindow 的消费者）
func _开关追踪面板(开: bool) -> void:
	for n in get_tree().get_nodes_in_group("quest_tracker"):
		if n is CanvasItem:
			(n as CanvasItem).visible = 开
	var 根: Node = get_tree().current_scene
	if 根 == null:
		return
	for n in 根.find_children("*", "", true, false):
		if String(n.name).contains("任务追踪"):
			if n is CanvasItem:
				(n as CanvasItem).visible = 开


## 按钮动作接的是**本移植会话上的真方法名**（`GameSession.accept_quest` /
## `claim_quest_reward`，见 `脚本/单例/游戏会话.gd:744/757`）。
##
## ⚠️ 这里原先写的是 `_accept_quest` / `_claim_quest` —— 那是**功能窗口**上的私有方法名，
##    `GameSession` 上没有，`has_method` 全部为假 ⇒ 按钮点下去**什么都不发生**。
##    按 `会话.has_method(...)` 逐个探测会静默吃掉这类笔误，所以直接调、让它报错。
##
## 按钮动作**照原版的字面**接（`MQuestionWindow.clickQuestBtnHandler:266-291`）：
##   「当前任务」页 → **放弃**（`QuestActionType.FORFEIT_QUEST = 3`）
##   「可接任务」页 → **接任务**（`START_QUEST = 1`）
##
## ⚠️ 2026-09-27 改过一次口径：上一轮这里接的是「当前页=领奖、可接页=接任务」，
##    与按钮上写着的「放弃」对不上。**原版没有"在窗口里直接领奖"这条路** ——
##    奖励是站在交付 NPC 旁交任务时（`COMPLETE_QUEST = 2`）由服务端发的，
##    所以那个口径是错的，已收口。`游戏会话.claim_quest_reward()` 仍保留，
##    在线时会发 COMPLETE，但窗口上不再用它。
##
## ⚠️ 原版在「可接任务」页还把按钮**隐藏**（`updateQuestButton:326-340`：
##    先 `visible=false`，只有 ACCEPTED 分支置 true），靠点任务条目 `MovePlayerToNpc` 走过去接。
##    这条要等「走过 NPC」那套寻路接上才能照做（见交接文档的活跃度/寻路待办），
##    暂按"按钮可见、点了发 START"处理 —— 服务端会校验是否站在起始 NPC 旁。
func _操作按钮点击() -> void:
	var 会话 := _取会话()
	if 会话 == null or _选中id.is_empty():
		return
	if _当前页 == 页_可接:
		会话.accept_quest(_选中id)
	else:
		会话.forfeit_quest(_选中id)

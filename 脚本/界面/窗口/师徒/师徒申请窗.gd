extends Control
## 师徒申请窗 —— 原版 `com/mxw/uifl/controls/mentoring/AgreestToturWindow`（全文 147 行）。
## 逐件真值 = `真值/窗口/师徒推荐窗.md` §④。
##
## 三条最容易做歪的地方（都对着 AS3 行号）：
## 1. 它**不是带标题的 MWindow**：`init():90-92` 把 `background` 整个换成 `MDilog_bgSkin`(184)
##    ⇒ 没有标题栏、没有关闭叉，整窗就是那张对话框皮。**别垫宿主外壳**（宿主会再画一层框）。
## 2. 宽是**算出来的**、高**恒 128**：`dolayout():120-122` 三级递推
##    `文宽 = textWidth + 6` ⇒ `黄底宽 = 文宽 + 20` ⇒ `窗宽 = 黄底宽 + 20`；
##    `:91` 的 `height = 128` 后面没人改 ⇒ 名字长短只影响宽度。写死 302 = 名字一长就把字切掉。
## 3. 那句话里**只有名字可点**（`setData:78` 的 `<a href="event:档|角色号">` 只裹住 `%1`），
##    点了 = `clickCharacter(charId)` ⇒ 上行 `94:0:<号>`（看别人的人物窗），**不是**同意/收徒。

## 关掉时喊一声，让 `窗口管理` 把排队的下一封放出来（原版按 charId 同屏摆好几扇，
## 本工程一扇轮流 = 真值表 §⑧ 登记过的偏离，不是漏做）。
signal 关掉了

## 两档（`:18-20` `TYPE_PRENTICE = 1` / `TYPE_TEACHER = 2`），与下行 4/5 是同一套编号。
const 档拜师 := 1		# 下行 `77:4:<号>:<名>`：对面来拜**我**为师 ⇒ 确定 `77:7`、取消 `77:5`
const 档收徒 := 2		# 下行 `77:5:<号>:<名>`：对面来收**我**为徒 ⇒ 确定 `77:8`、取消 `77:6`

const 边 := 6.0			# `:95-96` `_bg2.x = _bg2.y = 6`
const 黄底高 := 80.0		# `:97-98`
const 窗高 := 128.0		# `:91` `background.height`
const 文字高 := 20.0		# `:101` `_tf.height = 20`（钉死，不随文案行数变）
const 钮宽 := 37.0		# `UIConfig.as:964 btn_width_two`；`isScale9Grid = false` ⇒ 就是这张皮的天然宽
const 钮高 := 22.0
const 钮顶距 := 5.0		# `:126` `y = _bg2.y + _bg2.height + 5`
const 文字补宽 := 6.0		# `:120` `_tf.width = textWidth + 6`
const 底补宽 := 20.0		# `:121-122` 黄底 = 文宽 + 20、窗宽 = 黄底宽 + 20
const 字号 := 12

## 文案 = `AGREESTTOUR_WINDOW_NOTICE1/2`（`原版数据.语言(键)` 现查，2.2.3优化版 message 包）。
## 原文里 `%1` = 来的人名，`</a>` 已经在串里 ⇒ 名字那一段是链接，后面那句是白字。
const 后缀 := {档拜师: "想拜你为师，是否同意？", 档收徒: "想收你为徒，是否同意？"}
const 确定文字 := "确定"		# `COMMON_OK`
const 取消文字 := "取消"		# `COMMON_CANCEL`
const 名色 := Color("00ff00")	# `setData:78` 外层 `<font color="#00ff00">`（链接文字就跟着它）
const 句色 := Color("ffffff")	# 里层 `<font color="#ffffff">`
## 排版表的键 → 场景里的节点名（`.tscn` 的节点名一律 `get_node` 全名，别靠下标）。
const 节点名 := {"底": "底", "黄底": "黄底", "文": "文", "确定": "确定钮", "取消": "取消钮"}

@onready var _底: NinePatchRect = $底
@onready var _黄底: NinePatchRect = $黄底
@onready var _文: RichTextLabel = $文
@onready var _确定: Button = $确定钮
@onready var _取消: Button = $取消钮

var _档 := 0
var _号 := 0
## 离线门注入口（同 `窗口管理.出帧后端` 那一套）：填了就用它发帧，运行期恒 null。
var 后端覆盖: Node = null


func _ready() -> void:
	_确定.pressed.connect(_点确定)
	_取消.pressed.connect(_点取消)
	## `[url]` 的默认色是主题蓝 ⇒ 会盖掉原版那身绿。链接色钉回 `#00ff00`
	## （原版 htmlText 里 `<a>` 没带 `color=` 属性 ⇒ 它跟着外层 `<font>` 走）。
	_文.add_theme_color_override("default_color", 句色)
	_文.add_theme_color_override("link_color", 名色)
	_文.meta_clicked.connect(_点名字)
	visible = false


## 纯文本（拿去量宽用，与 BBCode 一一对应：名字 + 那句尾巴）。
static func 正文(档: int, 名: String) -> String:
	return 名 + String(后缀.get(档, ""))


## BBCode 版：`[url=档|号][u]名[/u]` + 白字那句。
## ⚠ `[u]` 包在 `[url]` 里（原版是 `<a href=…><u>%1</u></a>`），别反过来 ——
##   反过来 Godot 的下划线会连后半句一起画。
static func 富文本(档: int, 号: int, 名: String) -> String:
	return "[color=#00ff00][url=%d|%d][u]%s[/u][/url][color=#ffffff]%s[/color][/color]" % [
			档, 号, 名, String(后缀.get(档, ""))]


## `dolayout():120-126` 的三级递推，原样搬过来。`量宽` = 正文的**像素宽**（不含那 +6）。
static func 排版(量宽: float) -> Dictionary:
	var 文宽 := 量宽 + 文字补宽
	var 黄宽 := 文宽 + 底补宽
	var 窗宽 := 黄宽 + 底补宽
	var 格 := (黄宽 - 2.0 * 钮宽) / 3.0
	return {
		"底": Rect2(0.0, 0.0, 窗宽, 窗高),
		"黄底": Rect2(边, 边, 黄宽, 黄底高),
		"文": Rect2(边 + (黄宽 - 文宽) / 2.0, 边 + (黄底高 - 文字高) / 2.0, 文宽, 文字高),
		"确定": Rect2(边 + 格, 边 + 黄底高 + 钮顶距, 钮宽, 钮高),
		"取消": Rect2(边 + 格 + 钮宽 + 格, 边 + 黄底高 + 钮顶距, 钮宽, 钮高),
	}


## 填一扇 + 按原文算出来的宽度摆好。`号`/`名` 来自下行 `77:4`/`77:5` 那两段。
func 填(档: int, 号: int, 名: String) -> void:
	_档 = 档
	_号 = 号
	_文.text = 富文本(档, 号, 名)
	var 字体 := _文.get_theme_font("normal_font")
	var 量 := 字体.get_string_size(正文(档, 名), HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
	var 盒 := 排版(ceilf(量))
	for 键 in 节点名:
		var 件 := get_node(节点名[键]) as Control
		var 框: Rect2 = 盒[键]
		件.position = 框.position
		件.size = 框.size
	size = (盒["底"] as Rect2).size
	## 每次算完宽都要**重新回正中**（`ShituListManage.setLocationCenter():52-72`：
	## `x = (舞台宽 − 窗宽)/2`、`y = (舞台高 − 128)/2`）。不居中就会一直贴在 (0,0)。
	var 台 := get_viewport_rect().size
	position = Vector2(roundi((台.x - size.x) / 2.0), roundi((台.y - 窗高) / 2.0))
	_确定.text = 确定文字
	_取消.text = 取消文字
	visible = true


func _后端() -> Node:
	return 后端覆盖 if 后端覆盖 != null else get_node_or_null("/root/BackendConnection")


func _点确定() -> void:
	var 后 := _后端()
	var 成 := 后 != null and bool(后.call("request_tutor_accept", _档, _号))
	收起()
	if not 成:
		var 会 := get_node_or_null("/root/GameSession")
		if 会 != null:
			会.emit_signal("notification_requested", "处理师徒申请需要在线")


func _点取消() -> void:
	var 后 := _后端()
	if 后 != null:
		后.call("request_tutor_refuse", _档, _号)
	收起()


## `onLink():40-54` 两档都是 `API.ui.clickCharacter(charId)`；
## `UI.as:674-677` 那一行就是 `Client.requestCharFullInfo(id)` ⇒ 上行 **`94:0:<号>`**
## （⚠ **不是 94:4** —— 4 是"选中"那一发，只换顶栏血蓝、不开窗。这两个字节只差一位，
##   10-15 就因为记混绕了一圈，判据要钉的是 `request_char_full_info`）。
func _点名字(链接: Variant) -> void:
	var 段 := String(链接).split("|")
	if 段.size() < 2 or not 段[1].is_valid_int():
		return
	var 后 := _后端()
	if 后 != null and bool(后.get("in_game")):
		后.call("request_char_full_info", int(段[1]))


func 收起() -> void:
	if not visible:
		return
	visible = false
	关掉了.emit()


## 门与宿主用它拿"这一扇现在是谁"。
func 现在() -> Dictionary:
	return {"档": _档, "号": _号, "开着": visible}

extends RefCounted

## 鹿丸「卡片套册收集」= 原版 `guwan/GuwanshoujiWindow`（534×384，控制器由 `功能窗口` 挂页）。
##
## 版式（底板 / 两块面板 / 标签 / 两枚钮 / 进度条 / 树框 / 五枚卡格）**全在**
## `场景/界面/窗口/卡片套册/卡片套册窗.tscn`，那是 `开发工具/原版服务窗.py 生成 卡片套册`
## 从 `数据/界面/原版服务窗_SPEC.json` 产出的 ⇒ **别手改 .tscn**（下次生成会吃掉，
## 且 `测试/原版服务窗回归测试.gd` 会红在逐件比对上）。本文件只补原版运行期的那几件事：
##   ① 左列那棵 `Tree`（`GuwanshoujiWindow.as:125-133` 建、`:360-401 setTreeData` 填）——
##      **枝行整行可点**（`:140-160 treeItemClickHandler` 换展开 + 清空右列 + 两钮置灰）、
##      **叶行整行可点**（同一函数选叶 → 填右列）；
##   ② 选中一枚叶 → 右列 `infoPanel` 填 套卡名 / 加成句 / 五行（卡名·已提交/需要·掉落怪）/
##      五枚卡格图标 + 背包角标 / 收集进度条（`GuwanshoujiInfoPanel.as:203-292`）；
##   ③ `掉落怪物` 那一列是 `StructuredText` 的**可点链接**（`GuwanshoujiInfoPanelCell.as:51`
##      的 `#oc<mob>-<map>l#` → `StructuredText.as:808-818` 换成
##      `#00FF00` + `<a href='event:mob…'>`，`:714-728` `a:hover` 换 `#FF0000` 且下划线，
##      `:429-467 __onClickLink` 的 `case "mob"` → `UI.as:769-775 MovePlayerToMap(map,mob)`）；
##   ④ 两枚钮都走服务端（`GuwanshoujiWindowEvent.COMMITITEM` / `GAIN`，`:323-335`）⇒
##      **本工程一条协议都没接**，只照原版回一句状态行（口径同 忍具兑换 / 精英副本）。
##      例外：`提交卡片` 在**背包里没有该套卡**时原版根本不发帧（`:313-317` 直接
##      `addNotice(未满足收集条件)` 就 return）⇒ 这一支是纯客户端行为，照搬。
##
## 树行的坐标口径（`itemRenderer/QuestionTreeItemRenderer.as` 逐条）：
##   枝：`_icon`(BranchButton 18×18) x=2 y=2（:64 / :127），文字 x = 2+18+CONTENT_GAP(8) = 28、
##       色 `UIConfig.UI_ORANGE` #ff9100（:51），底 = BranchBgSkinF 宽 `owner.width-20` 高 24 y=−1
##       （:116 / :125-127），行高 24（`Tree.rowHeight = 24`，窗口 :130）；
##   叶：**没有图标**（:71-73 先 removeChild 再 `_icon = null`），文字 x = 16（:84）、
##       底 = `MSelected_background1`（:87）/ `BlankSkinF`（:91），底与文字高 20（:119-121）；
##   两者文字宽 = `owner.width - x - 24`（:115）。
##
## ⚠ 叶的**文字色不是白色**：`:78` 那个 `color = 16777215` 只是 `MLabel` 的底色，
##   真正上色的是 `:94` `htmlText = _listData.label`，而 label 整串就带着色标签 ——
##   `en_US$message_properties.as:172` `GUWAN_SHOUJI_WEIWAN_CHENG` =
##   `<font color="#1e90ff">%1</font><font color="#ff0000">(未完成)</font>`（已完成那支 :1457 是 `#00ff00`）。
##   首版按白色做 ⇒ 被用户打回「全是死的、颜色也不对」。
##
## ⚠ 三列文本（卡名/数量/掉落怪）在原版是**两个 `MLabel.htmlText` + 一个 `StructuredText`**
##   （`GuwanshoujiInfoPanelCell.as:27-56`），全部支持逐字混色 ⇒ Godot 侧一律 `RichTextLabel` + BBCode，
##   不许再用「整条一个色的 Label」近似。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")

const 卡片表路径 := "res://数据/卡片.json"

const 枝背景 := "res://素材/界面/专用控件/枝背景.png"
const 选中条 := "res://素材/界面/原版窗口/通用控件/选中条1.png"

## `BranchButton` = `symbol660`，里面**同时**放着 `upSkin`=chid 599（⊕）与
## `selectedUpSkin`=chid 603（⊖）（`MainLib.xml` 的 `spriteId="660"` 块，两条 `PlaceObject2Tag`）。
## ⇒ 直接导 660 拿到的是**两张重叠**的合成图，一加悬停滤镜会把另一张一起提亮，
##   所以这里按两张真皮各取三档（`StyleUtil.skinFilters` up 0 / over +30 / down −40 预烘）。
##   渲染器 `:65-72` 用 `selected = (nodeState == OPEN_NODE)` 换组 ⇒ 合=⊕、开=⊖。
const 展开钮皮 := {
	"合": ["res://素材/界面/专用控件/展开钮.png",
		"res://素材/界面/专用控件/展开钮_悬停.png",
		"res://素材/界面/专用控件/展开钮_按下.png"],
	"开": ["res://素材/界面/专用控件/展开钮_选中.png",
		"res://素材/界面/专用控件/展开钮_选中_悬停.png",
		"res://素材/界面/专用控件/展开钮_选中_按下.png"],
}

const 橙 := Color(1.0, 0x91 / 255.0, 0.0)			# UIConfig.as:928 UI_ORANGE（枝行文字）
const 白字 := Color(1, 1, 1)					# 渲染器 :78（叶行底色，实际字色在 BBCode 里）
const 绿 := Color(0, 1.0, 0)					# UI_GREEN / `StructuredText.COLOR_MONSTER` #00FF00
const 红 := Color(1.0, 0, 0)					# 不够数的 已提交 / `a:hover` #FF0000
const 黄 := Color(1.0, 1.0, 0.0)					# UI_YELLOW（套卡名、加成句、背包数量）
const 名蓝 := Color(0x1e / 255.0, 0x90 / 255.0, 1.0)		# 叶行套卡名那截 #1e90ff

## 语言表逐字（`en_US$message_properties.as`，HTML 版式已在 SPEC/这里翻成 BBCode）
const 级收集 := "级收集"							# :1655 GUWAN_SHOUJI_SHOUJI
const 叶未完成 := "[color=#1e90ff]%1[/color][color=#ff0000](未完成)"	# :172 GUWAN_SHOUJI_WEIWAN_CHENG
const 叶已完成 := "[color=#1e90ff]%1[/color][color=#00ff00](已完成)"	# :1457 GUWAN_SHOUJI_YIWAN_CHENG
const 加成句 := "奖励：你将可获得%1个潜能点的永久加成(系统随机分配)"			# :439 GUWAN_SHOUJI_PREMIUM
const 背包数量头 := "背包中的数量："						# :1525 GUWAN_SHOUJI_PACK_COUNT
const 钮提示 := "自动将背包中的卡片进行提交，提交后将会为你记录卡片收集进度。（若所提交的卡片已提交数=需求数量则不会为你重复提交该卡片）"	# :2751 REFER_KAPIAN_BTN_TIP
const 未满足 := "未满足收集条件"						# :2859 WEIMANZU_CONDITION
const 已收集完 := "你已收集完成！"						# :966 WANCHENG
## ⚠️ 这一对常量原来写的是"本工程未接（待点头）" —— **假缺口**（§3.120）：
## 后端早就有 `request_card_commit` / `request_card_claim`（`CARD_ACTION 1392` 动作 2/3），
## 服务端 `handle_card_action` 的 2/3 就是"提交卡片 / 领取属性点"，传承窗口那边一直在用。
## 留着这两个常量当"离线那口话"（离线确实不模拟），在线走真请求。
const 离线结算 := "提交/领取要在服务端结算（离线不模拟）"


const 枝高 := 24.0
const 叶高 := 20.0


## 宿主 = `功能窗口`（要 `_content` / `_status` / `_背包数量()` / `_session`）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 树框 := 页.get_node("树") as ScrollContainer
	var 列 := 树框.get_node("树_内容") as Control
	var 表 := _读表()
	var 态 := {"展开": {}, "选中": "", "页": 页, "列": 列, "树框": 树框, "宿主": 宿主,
			"表": 表, "钮": {}, "怪": {}, "完成": {}}
	接钮(页, 宿主, 态)
	if 表.is_empty():
		宿主._show_hint("内部错误：读不到 %s ⇒ 树与右列都会是空的" % 卡片表路径)
		return 页
	# 开屏先查一次**级别帧**（原版 `GuwanshoujiWindow` 开屏就 `requestCard_level`），
	# 并挂一次性刷新：回帧（level/node 两种都推 `card_state_received`）⇒ 宿主重画本页。
	if 宿主._backend != null and bool(宿主._backend.in_game):
		宿主._backend.request_card_level(int(表.keys()[0]))
		if not 宿主.has_meta("card_album_wired"):
			宿主.set_meta("card_album_wired", true)		# meta 键必须 ASCII
			宿主._backend.card_state_received.connect(func(_状: Dictionary): 宿主._refresh_current())
	建树(态)
	# 原版开屏：`selectedIndex=0` → 展开第一枝 → 选第一枚叶（`:390-397`）⇒ 右列一开就有内容
	var 层 := _号序(表)[0]
	var 号 := _号序(表[层] as Dictionary)[0]
	选中叶(态, "%s_%s" % [层, 号])
	return 页


static func _读表() -> Dictionary:
	if not FileAccess.file_exists(卡片表路径):
		return {}
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(卡片表路径))
	return 解 if typeof(解) == TYPE_DICTIONARY else {}


## 键一律翻成 String 再按数值序排：`JSON.parse_string` 把数字键解成字符串、数字值解成 float，
## 返回 `Array[String]` 让调用处的 `:=` 能推断类型（否则 `var 层 := _号序(表)[0]` 直接解析失败）。
static func _号序(体: Dictionary) -> Array[String]:
	var 出: Array[String] = []
	for k in 体.keys():
		出.append(str(k))
	出.sort_custom(func(a, b): return int(a) < int(b))
	return 出


## ── 树 ──────────────────────────────────────────────────────────────────────

static func 建树(态: Dictionary) -> void:
	var 列 := 态["列"] as Control
	var 树框 := 态["树框"] as ScrollContainer
	var 表 := 态["表"] as Dictionary
	var 区宽: float = 树框.size.x
	# ⚠ 两个宽不是一回事，混用会把文字截短：
	#   · `版式宽` = AS3 里 `_listData.owner.width`（= `Tree.width = 171`，窗口 :126）——
	#     渲染器所有 `owner.width − x`、`owner.width − 20` 公式都按它算；Flash 的滚动条是
	#     **画在行之上**的，不缩行宽，所以「宇智波家族套卡(未完成)」这种长行放得下（末字到 147 < 156）。
	#   · `内容宽` = 区宽 − 实测条宽 —— 只用于 `列` 的**最小宽**（`ScrollContainer` 的最小宽含条宽，
	#     写区宽会把条整条挤出框外，见 2026-10-04 那条打回），行本身的可视范围也到这儿为止。
	var 条宽: float = maxf(0.0, 树框.get_v_scroll_bar().get_combined_minimum_size().x)
	var 内容宽: float = maxf(1.0, 区宽 - 条宽)
	态["版式宽"] = 区宽
	列.custom_minimum_size.x = 内容宽
	var 首层 := _号序(表)[0]
	for 层 in _号序(表):
		(态["展开"] as Dictionary)[层] = (str(层) == str(首层))	# 第一枝默认展开（原版 :393-397）
		var 枝 := Control.new()
		枝.name = "枝_%s" % 层
		枝.mouse_filter = Control.MOUSE_FILTER_STOP
		枝.size = Vector2(内容宽, 枝高)
		列.add_child(枝)
		var 底 := TextureRect.new()
		底.name = "底"
		底.texture = load(枝背景)
		底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		底.stretch_mode = TextureRect.STRETCH_SCALE
		底.mouse_filter = Control.MOUSE_FILTER_IGNORE
		底.position = Vector2(0.0, -1.0)				# 渲染器 :127 `_background.y = -1`
		底.size = Vector2(区宽 - 20.0, 枝高)			# :116 `owner.width - 20`
		枝.add_child(底)
		var 钮 := TextureButton.new()
		钮.name = "展开钮"
		钮.ignore_texture_size = true
		钮.stretch_mode = TextureButton.STRETCH_KEEP
		钮.position = Vector2(2.0, 2.0)				# :64 / :127
		枝.add_child(钮)
		接三态(态, 钮, [展开钮皮["合"], 展开钮皮["开"]])
		var 字 := Label.new()					# 枝行单色 ⇒ Label 就够（叶行两色才要 BBCode）
		字.name = "标签"
		字.position = Vector2(2.0 + 18.0 + 8.0, 1.0)		# :73 x = icon.x + icon.width + CONTENT_GAP
		字.size = Vector2(maxf(1.0, 区宽 - 28.0 - 24.0), 18.0)	# :115 文字宽 = owner.width − x − 24
		字.add_theme_color_override("font_color", 橙)
		字.add_theme_font_size_override("font_size", 12)
		字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		字.clip_text = true
		字.text = "%s%s" % [层, 级收集]
		枝.add_child(字)
		钮.pressed.connect(点枝.bind(态, 层))
		枝.gui_input.connect(点行.bind(态, "枝_%s" % str(层)))
		for 号 in _号序(表[层] as Dictionary):
			var 套: Dictionary = (表[层] as Dictionary)[号]
			var 叶 := Control.new()
			叶.name = "叶_%s_%s" % [层, 号]
			叶.mouse_filter = Control.MOUSE_FILTER_STOP
			叶.size = Vector2(内容宽, 叶高)
			列.add_child(叶)
			var 字2 := RichTextLabel.new()
			字2.name = "标签"
			字2.position = Vector2(16.0, 0.0)			# :84 叶文字 x=16
			字2.size = Vector2(maxf(1.0, 区宽 - 16.0 - 24.0), 叶高)
			字2.bbcode_enabled = true
			字2.scroll_active = false
			字2.autowrap_mode = TextServer.AUTOWRAP_OFF
			字2.add_theme_color_override("default_color", 白字)
			字2.add_theme_font_size_override("normal_font_size", 12)
			字2.add_theme_constant_override("margin_top", 2)	# 与 Label 在 20 高行里同一水平
			字2.mouse_filter = Control.MOUSE_FILTER_IGNORE	# 点击归整行（原版 renderer 自己吃鼠标）
			# 叶尾巴「(未完成)/(已完成)」看服务端 `CARD_ACTION 0` 那一帧的 finish 位
			# （原版 `GuwanshoujiTreeItem` 收的同一个标志）；离线没帧 ⇒ 一律未完成。
			字2.text = _叶文案(态, 层, 号, String(套.get("name", "")))
			叶.add_child(字2)
			叶.gui_input.connect(点行.bind(态, "%s_%s" % [层, 号]))
	排一遍(态)


## `gui_input` 的**事件是第一个参数**，`bind()` 的都排在后面 —— 首版写成
## `connect(选中.bind(列, 态, 键))` 配 `func 选中(列, 态, 键, 事 = null)`，
## 于是 InputEvent 落进了 `列`、整棵树每次点击在第一行就 return ⇒ 用户看到的「全是死的」。
static func 点行(事: InputEvent, 态: Dictionary, 键: String) -> void:
	var 按 := 事 as InputEventMouseButton
	if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if 键.begins_with("枝_"):
		点枝(态, 键.substr(2))
	else:
		选中叶(态, 键)


## 枝行 = 原版 `treeItemClickHandler` 的 BranchNode 分支（`:145-160`）：
## 清空右列 + 两钮置灰 + 开合这一枝。
static func 点枝(态: Dictionary, 层: Variant) -> void:
	var 展开: Dictionary = 态["展开"]
	展开[层] = not bool(展开[层])
	态["选中"] = ""
	清选中底(态["列"] as Control)		# Tree 把选中位挪到枝上 ⇒ 原叶的 `MSelected_background1` 回 `BlankSkinF`
	清右列(态)
	设钮可用(态, false, false)
	排一遍(态)


static func 排一遍(态: Dictionary) -> void:
	var 列 := 态["列"] as Control
	var 树框 := 态["树框"] as ScrollContainer
	var 展开: Dictionary = 态["展开"]
	var y := 0.0
	for 子 in 列.get_children():
		var 名 := String(子.name)
		var 显 := true
		if 名.begins_with("叶_"):
			显 = bool(展开.get(名.split("_")[1], false))
		elif 名.begins_with("枝_"):
			var 钮 := (子 as Control).get_node_or_null("展开钮") as TextureButton
			if 钮 != null:
				设钮组(态, 钮, 0 if not bool(展开.get(名.substr(2), false)) else 1)
		子.visible = 显
		if 显:
			子.position = Vector2(0.0, y)
			y += 子.size.y
	var 高: float = maxf(树框.size.y, y)
	列.custom_minimum_size = Vector2(列.custom_minimum_size.x, 高)
	列.size = Vector2(列.custom_minimum_size.x, 高)


static func 清选中底(列: Control) -> void:
	for 兄弟 in 列.get_children():
		if not String(兄弟.name).begins_with("叶_"):
			continue
		var 老 := (兄弟 as Control).get_node_or_null("选中底")
		while 老 != null:
			兄弟.remove_child(老)
			老.queue_free()
			老 = (兄弟 as Control).get_node_or_null("选中底")


## 点叶：清掉旧选中底 → 给这一行铺 `MSelected_background1`（原版 `addChildAt(…,0)` ⇒ 压在文字之下）
## → 填右列。`_finish` 是服务端 NODEINFO 回帧里的字段，离线没有 ⇒ 一律 false（叶字保持「未完成」）。
static func 选中叶(态: Dictionary, 键: String) -> void:
	var 列 := 态["列"] as Control
	var 叶 := 列.get_node_or_null("叶_%s" % 键) as Control
	if 叶 == null:
		return
	清选中底(列)
	var 底 := TextureRect.new()
	底.name = "选中底"
	底.texture = load(选中条)
	底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	底.stretch_mode = TextureRect.STRETCH_SCALE
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	底.size = Vector2(float(态.get("版式宽", 列.size.x)) - 20.0, 19.0)	# :116 底宽（owner.width − 20）；
	# MSelected_background1 原生 189×19
	叶.add_child(底)
	叶.move_child(底, 0)
	(态["展开"] as Dictionary)[键.split("_")[0]] = true
	排一遍(态)
	态["选中"] = 键
	填右列(态, 键)
	# `setBtnEnabled()`（`:258-269`）：btn1 恒可用；btn2 只在 `finish && !gained` 时可用
	设钮可用(态, true, _可领(态, 键))
	# 选中就**查这一套的服务器记录**（原版 `requestCard_nodeInfo`）——回帧推 NODEINFO ⇒ 宿主重画
	var 宿主 := 态["宿主"] as Node
	var 段 := 键.split("_")
	if 宿主._backend != null and bool(宿主._backend.in_game) and 段.size() >= 2 			and 段[0].is_valid_int() and 段[1].is_valid_int():
		宿主._backend.request_card_node(int(段[0]), int(段[1]))


## ── 右列 ────────────────────────────────────────────────────────────────────

static func 填右列(态: Dictionary, 键: String) -> void:
	var 页 := 态["页"] as Control
	var 宿主 := 态["宿主"] as Node
	var 表 := 态["表"] as Dictionary
	# ⚠ 生成器给嵌套件起的节点名带父前缀（`面板_套卡名`），但它**挂在 面板 下** ⇒ 路径是
	#   `面板/面板_套卡名`。首版按 `页.get_node("面板_套卡名")` 取 ⇒ `Node not found` 之后
	#   整个函数中途死掉，症状正是"框架在、右列五行全空"。
	var 面板 := 页.get_node("面板") as Control
	var 段 := 键.split("_")
	var 套: Dictionary = ((表[段[0]] as Dictionary) as Dictionary)[段[1]]
	var items: Dictionary = 套.get("items", {})
	var 序 := _号序(items)
	(面板.get_node("面板_套卡名") as Label).text = String(套.get("name", ""))
	# 原版 `CN.replaceString(GUWAN_SHOUJI_PREMIUM, data.gainAp)` ⇒ %1 换成 gainAp
	(面板.get_node("面板_加成说明") as Label).text = 加成句.replace("%1", str(int(套.get("gainAp", 0))))
	var 需总 := 0
	var 可提交 := false
	for i in 5:
		var 行 := 面板.get_node("行%d" % (i + 1)) as Control
		var 格 := 面板.get_node("卡格%d" % (i + 1)) as Control
		if i >= 序.size():
			行.visible = false
			格.visible = false
			continue
		行.visible = true
		格.visible = true
		var 料: Dictionary = items[序[i]]
		var 号: int = int(料.get("id", 0))
		var 需: int = int(料.get("count", 0))
		需总 += 需
		# `getCurCount()` 查的是服务端回帧的**已提交**数（`CardNodeItemInfo.count`）——
		# 在线时取 NODEINFO 那一帧（`authoritative_card`，键 `submitted`）；离线没有 ⇒ 0
		var 已: int = _已提交(态, 键, 号)
		var 背包: int = int(宿主._背包数量(号))
		if 背包 > 0:
			可提交 = true
		var 够 := 已 >= 需 and 需 > 0
		var 名件 := 行.get_node("行%d_卡名" % (i + 1)) as RichTextLabel
		var 数件 := 行.get_node("行%d_数量" % (i + 1)) as RichTextLabel
		var 掉件 := 行.get_node("行%d_掉落怪" % (i + 1)) as RichTextLabel
		# `GuwanshoujiInfoPanelCell.as:37` `itemName.htmlText = getItemString(id)`，
		# 底色 `UI_GREEN`（:27）⇒ 整串绿；名字串本身不带色标（已核 `数据/物品.json`）。
		名件.text = "[color=#00ff00]%s[/color]" % 游戏数据.item_name(号)
		# :38-45 够数两截都绿；不够数 = `#ff0000` 已提交 + `#ffffff` 需要（**逐字混色**，不是近似）
		数件.text = "[color=%s]%d[/color][color=%s]/%d[/color]" % [
				"#00ff00" if 够 else "#ff0000", 已, "#00ff00" if 够 else "#ffffff", 需]
		# `StructuredText`：`#oc<mob>-<map>l#` → `COLOR_MONSTER`(#00FF00) + `<a href='event:mob…'>`，
		# `a:link` 带下划线、`a:hover` 变 #FF0000。列宽 94 = `UIConfig.btn_width_seven`（:54）。
		掉件.text = "[url=mob%d-%d][u]%s[/u][/url]" % [
				int(料.get("mob", 0)), int(料.get("map", 0)),
				游戏数据.monster_name(int(料.get("mob", 0)))]
		掉件.add_theme_color_override("default_color", 绿)
		(态["怪"] as Dictionary)[掉件] = true
		if not (掉件.has_meta("link_hooked")):		# ⚠ meta 键**只许 ASCII 标识符**：
			# 中文键会被 Godot 4 拒掉并刷 `Invalid metadata identifier`，值**静默存不进去**
			# ⇒ `has_meta` 永远 false ⇒ 每次换选中枚都给同一件多接一条 `meta_clicked`（点一下响三下）。
			掉件.set_meta("link_hooked", true)
			掉件.meta_clicked.connect(点怪.bind(态))
			# ⚠ 悬停换色**不用 `meta_hover_started`**：实测本工程的合成/常规鼠标运动下它一次都没发过
			#   （`测试/卡片套册交互回归测试.gd` 里数出来 started=0，而同一个件的 `meta_clicked` 是好的），
			#   拿它当唯一通路 = 静默没有悬停态。改成自己量：`gui_input` 收到移动 ⇒ 鼠标在**字宽之内**
			#   就亮红（原版 `StructuredText.as:731-780` 也是按 `getCharIndexAtPoint` 落在有 url 的字上才换色，
			#   空白处不亮），`mouse_exited` ⇒ 回绿。
			掉件.gui_input.connect(怪移动.bind(掉件))
			掉件.mouse_exited.connect(怪悬停.bind(掉件, false))
		_格内容(格, 号, 背包, 宿主, 页)
	# 收集进度：`setData(currentBar, totalBar)`（`GuwanshoujiInfoPanel.as:112-122`），
	# `currentBar` 累加的也是服务端回帧的已提交数 ⇒ 离线恒 0；条里那一行 `0/52` 是
	# `MBar.as:163` `tf.text = cur + "/" + total`（**条自己带字**，别当成旁边的 Label）。
	var 条 := 面板.get_node("面板_收集进度") as Control
	var 填充 := 条.get_node("裁剪/填充") as TextureRect
	var 内宽: float = maxf(0.0, 条.size.x - 6.0)
	var 比 := 0.0			# 离线 `currentBar` 恒 0 ⇒ 条永远是空
	填充.position.x = -3.0 - float(int(内宽 * (1.0 - 比)))
	(条.get_node("值") as Label).text = "0/%d" % 需总
	(面板.get_node("面板_背包数量") as Label).text = 背包数量头	# 原版这行**从不更新**，就是个标题
	态["可提交"] = 可提交


## `KapianItemCell`：`MGrid_background`(40×40) 是**格底**、图标 `addChild` 进格（`:24-27`、`:72-76`）、
## 角标 tf 在格内 (1,24) 37×16 左对齐、`setCount(p)` = `p>0 ? p : ""`（`:28-44`、`:67-70`）。
## 三件都已烘进 `.tscn`（编辑器与运行期同一张脸），这里只按当前套卡换纹理/文字。
static func _格内容(格: Control, 号: int, 背包: int, 宿主: Node, 页: Control) -> void:
	# ⚠ 生成器给格的内挂件起的名字是**带父前缀**的 `卡格1_图标` / `卡格1_数量`
	#   （`节点名(名)` 把路径里的 `/` 换成 `_`），按 `图标` 取会拿到 null ⇒ 换选中枚时
	#   五格图标**一动不动**，而开屏那一态因为烘的就是它，肉眼看不出来。
	var 前 := String(格.name)
	var 图 := 格.get_node_or_null(前 + "_图标") as TextureRect
	var 数 := 格.get_node_or_null(前 + "_数量") as Label
	var 路 := 游戏数据.item_icon_path(号)
	if 图 != null:
		if 路 == "" or not ResourceLoader.exists(路):
			图.visible = false
		else:
			图.texture = load(路)
			var 寸: Vector2 = 图.texture.get_size()
			图.position = Vector2(roundf((格.size.x - 寸.x) / 2.0), roundf((格.size.y - 寸.y) / 2.0))
			图.size = 寸
			图.visible = true
	if 数 != null:
		数.text = str(背包) if 背包 > 0 else ""
	# 悬停出物品提示（`KapianItemCell.as:90 buttonMode=true` + `:96` ENTER_FRAME → `showToolTip()`）
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not 格.has_meta("cell_hooked"):		# 同上：ASCII 键，见 :335 那条注释
		格.set_meta("cell_hooked", true)
		var 节点名 := "物品提示_" + String(格.name)
		格.mouse_entered.connect(_格悬停.bind(页, 节点名, 号, 宿主))
		格.mouse_exited.connect(_格离开.bind(页, 节点名))


static func _格悬停(页: Control, 节点名: String, 号: int, 宿主: Node) -> void:
	var 框 := 页.get_node_or_null(节点名) as Control
	if 框 == null:
		框 = 物品提示场景.instantiate() as Control
		框.name = 节点名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)
	var 等级 := 0
	if 宿主._session != null:
		等级 = int((宿主._session as Node).player_stats.get("level", 0))
	框.设置(str(号), int(宿主._背包数量(号)), 等级, 游戏数据.item(号))
	框.visible = true
	框.贴到鼠标(页.get_local_mouse_position(), 宿主._舞台尺寸())


static func _格离开(页: Control, 节点名: String) -> void:
	var 框 := 页.get_node_or_null(节点名) as CanvasItem
	if 框 != null:
		框.visible = false


## 原版 `destory()`（`GuwanshoujiInfoPanel.as:104-110`）：名字/加成隐藏、五行与五格隐藏并清数据、
## `currentBar = totalBar = 0` 后重画条（⇒ 条里是 `0/0`）。三列表头与「背包中的数量：」标题**不隐藏**。
static func 清右列(态: Dictionary) -> void:
	var 面板 := (态["页"] as Control).get_node("面板") as Control
	(面板.get_node("面板_套卡名") as Label).text = ""
	(面板.get_node("面板_加成说明") as Label).text = ""
	for i in 5:
		(面板.get_node("行%d" % (i + 1)) as Control).visible = false
		(面板.get_node("卡格%d" % (i + 1)) as Control).visible = false
	var 条 := 面板.get_node("面板_收集进度") as Control
	(条.get_node("裁剪/填充") as TextureRect).position.x = -3.0 - float(int(maxf(0.0, 条.size.x - 6.0)))
	(条.get_node("值") as Label).text = "0/0"


## `StructuredText.as:714-728` + `:731-780`：悬停那截变 `#FF0000` 并加下划线，移开回 `#00FF00`。
## 下划线原版是 `a:link` 就带着（`setStyle` :718）⇒ BBCode 里已经写了 `[u]`，换色只动 `default_color`。
static func 怪悬停(件: RichTextLabel, 悬: bool) -> void:
	件.add_theme_color_override("default_color", 红 if 悬 else 绿)
	件.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if 悬 else Control.CURSOR_ARROW


## Flash 的 `getCharIndexAtPoint` 只有落在**有 url 的字**上才算悬停 ⇒ 按字宽判，不按整格宽判
## （那一列 94 宽、字约 60 宽，右边空白悬上去原版不亮）。
static func 怪移动(事: InputEvent, 件: RichTextLabel) -> void:
	var 移 := 事 as InputEventMouseMotion
	if 移 == null:
		return
	var 字宽: float = maxf(1.0, 件.get_content_width())
	怪悬停(件, 移.position.x <= 字宽 and 移.position.y < 件.size.y)


## 点「掉落怪物」那一列的名字（原版 `UI.as:769-775` 的 `case 2`）：
##   `guajiHandler.isStart = false`（**停挂机**）→ `targetHandler.toAttackAnemy = false`
##   → `lockAutoMobId/lockAutoMapId = 这只怪 / 这张图` → `characterHandler.MovePlayerToMob(mapId, mobId)`。
## 本工程对应：`会话.request_hang(false)` 停挂机 + `玩家.开始自动接近(实体)`
## （`玩家.gd:323`，就是"点怪那条自己走过去打的一次性命令"，与 `地图实体._on_monster_input` 同一出口）。
## ⚠️ **跨图那条（原版先 `MovePlayerToMap`）没接** —— 不在本图时只提示，别假装走得到。
static func 点怪(链: Variant, 态: Dictionary) -> void:
	var u := String(链)                      # 链形状 `mob<怪号>-<图号>`（本文件上面那段 url 拼的）
	if not u.begins_with("mob"):
		return
	var 分 := u.substr(3).split("-")
	if 分.size() < 2:
		return
	var 怪号 := int(分[0])
	var 宿主 := 态["宿主"] as Node
	if 宿主 == null:
		return
	var 会话: Variant = 宿主.get("_session")
	if 会话 != null and bool((会话.get("hang_state") as Dictionary).get("active", false)):
		会话.call("request_hang", false)          # 原版 `guajiHandler.isStart = false`
	var 场景 := 宿主.get_tree().current_scene
	var 生怪根 := 场景.get_node_or_null("LifeRoot") if 场景 != null else null
	if 生怪根 == null:
		宿主._show_hint("点掉落怪：找不到世界（不在图里？）")
		return
	for 实体 in 生怪根.get("_entities") as Array:
		var 谁 := 实体 as Node2D
		if 谁 == null or str(谁.get("kind")) != "m":
			continue
		if int(str(谁.get("entity_id"))) == 怪号:
			var 玩 := 场景.get_node_or_null("Player")
			if 玩 != null and 玩.has_method("开始自动接近"):
				玩.call("开始自动接近", 谁)
				return
	宿主._show_hint("点掉落怪：本图没有这只怪（跨图寻路没接）")


## ── 两枚钮 ──────────────────────────────────────────────────────────────────

## 提交 / 领取（原版 `GuwanshoujiWindowEvent.COMMITITEM` / `GAIN`，服务端 `handle_card_action` 动作 2/3）。
## 键 `级别_节点` 的两段就是协议要的 `level` / `nodeId`（`数据/卡片.json` 的顶层键=级别、二层键=节点）。
static func _发卡牌请求(宿主: Node, 态: Dictionary, 动作: String) -> void:
	var 段 := String(态.get("选中", "")).split("_")
	if 段.size() < 2 or not 段[0].is_valid_int() or not 段[1].is_valid_int():
		宿主._show_hint("内部错误：选中的套卡键不是 `级别_节点`（%s）" % String(态.get("选中", "")))
		return
	var 后端 = 宿主._backend
	if 后端 == null or not bool(后端.in_game):
		宿主._show_hint(离线结算)
		return
	var 级 := int(段[0])
	var 点 := int(段[1])
	var 成 := bool(后端.request_card_commit(级, 点)) if 动作 == "commit" else bool(后端.request_card_claim(级, 点))
	if not 成:
		宿主._show_hint("请求发送失败，请检查原版服务器连接")
		# 成功不回话：服务端会推 NODEINFO（`_send_card_node_info`）⇒ 宿主那边接了刷新（见 渲染）


## 服务端那一帧（`authoritative_card`）只有在"就是这一套"时才算数。
static func _节点状态(态: Dictionary, 键: String) -> Dictionary:
	var 宿主 := 态.get("宿主") as Node
	if 宿主 == null or 宿主._backend == null:
		return {}
	var 状: Dictionary = 宿主._backend.authoritative_card
	var 段 := 键.split("_")
	if 状.is_empty() or 段.size() < 2 or not 段[1].is_valid_int():
		return {}
	if int(状.get("level", -1)) != int(段[0]) or int(状.get("node_id", -1)) != int(段[1]):
		return {}
	return 状


## 这一套里某张卡**已提交**几件（取不到就是 0 = 离线/还没回帧）。
static func _已提交(态: Dictionary, 键: String, 卡号: int) -> int:
	var 状 := _节点状态(态, 键)
	for 项 in 状.get("items", []) as Array:
		if int((项 as Dictionary).get("item_id", 0)) == 卡号:
			return int((项 as Dictionary).get("submitted", 0))
	return 0


## 领取钮能不能点：`finish && !gained`（原版 `setBtnEnabled():258-269`）。
static func _可领(态: Dictionary, 键: String) -> bool:
	var 状 := _节点状态(态, 键)
	return bool(状.get("committed", false)) and not bool(状.get("claimed", false))


## 叶尾巴的「(未完成)/(已完成)」：看**级别帧**（动作 0）里那一套的 finish 位。
static func _叶文案(态: Dictionary, 层: Variant, 号: Variant, 套名: String) -> String:
	var 宿主 := 态.get("宿主") as Node
	if 宿主 != null and 宿主._backend != null:
		var 状: Dictionary = 宿主._backend.authoritative_card
		if int(状.get("level", -1)) == int(层):
			for 点 in 状.get("nodes", []) as Array:
				if int((点 as Dictionary).get("node_id", -1)) == int(号):
					if bool((点 as Dictionary).get("committed", false)):
						return 叶已完成.replace("%1", 套名)
					break
	return 叶未完成.replace("%1", 套名)


static func 设钮可用(态: Dictionary, 提: bool, 领: bool) -> void:
	var 页 := 态["页"] as Control
	(页.get_node("提交钮") as Button).disabled = not 提
	(页.get_node("领取钮") as Button).disabled = not 领


static func 接钮(页: Control, 宿主: Node, 态: Dictionary) -> void:
	var 提 := 页.get_node("提交钮") as Button
	var 领 := 页.get_node("领取钮") as Button
	提.pressed.connect(func():
		if not bool(态.get("可提交", false)):
			宿主._show_hint(未满足)		# `:313-317` 纯客户端分支，不发帧
		elif bool(态.get("完成", {}).get(str(态["选中"]), false)):
			宿主._show_hint(已收集完)		# `:318-322`
		else:
			_发卡牌请求(宿主, 态, "commit"))
	领.pressed.connect(func(): _发卡牌请求(宿主, 态, "claim"))
	# `:101` 只有 btn1 挂 tooltip（btn2 没有）
	var 框 := 文字提示场景.instantiate() as Control
	框.name = "文字提示_提交钮"
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.add_child(框)
	框.设置(确认弹.文案转BBCode(钮提示), 宿主._舞台尺寸())
	框.visible = false
	提.mouse_entered.connect(func(): 框.visible = true)
	提.mouse_exited.connect(func(): 框.visible = false)


## ── MButton3 三档换皮（口径同 skill `flash-mbutton3-state-skins`）───────────────
## **不用 `texture_hover` / `texture_pressed`**：Godot 松手后只要还悬着会回到 hover，
## 而原版松手回 STATE_UP（`MButton3.as:103-108`）⇒ 只换 `texture_normal`。

static func 接三态(态: Dictionary, 钮: Control, 组表: Array) -> void:
	(态["钮"] as Dictionary)[钮] = {"组表": 组表, "组": 0, "态": 0}
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.mouse_entered.connect(设钮态.bind(态, 钮, 1))
	钮.mouse_exited.connect(设钮态.bind(态, 钮, 0))
	钮.button_down.connect(设钮态.bind(态, 钮, 2))
	钮.button_up.connect(设钮态.bind(态, 钮, 0))
	画钮(态, 钮)


static func 设钮态(态: Dictionary, 钮: Control, 新态: int) -> void:
	var 记: Dictionary = (态["钮"] as Dictionary).get(钮, {})
	if 记.is_empty():
		return
	记["态"] = 新态
	画钮(态, 钮)


static func 设钮组(态: Dictionary, 钮: Control, 组: int) -> void:
	var 记: Dictionary = (态["钮"] as Dictionary).get(钮, {})
	if 记.is_empty() or int(记["组"]) == 组:
		return
	记["组"] = 组
	画钮(态, 钮)


static func 画钮(态: Dictionary, 钮: Control) -> void:
	var 记: Dictionary = (态["钮"] as Dictionary).get(钮, {})
	if 记.is_empty():
		return
	var 组表: Array = 记["组表"]
	var 皮: Array = 组表[int(记["组"])]
	var 图 := 钮 as TextureButton
	图.texture_normal = load(String(皮[int(记["态"])]))

extends RefCounted
## 家族贡献窗内容页的填充（原版 `FamillyGongXianWindow`，`FGW.as`，`super(610,408,true)`）。
##
## 这一窗原来是**纯 UI**：另一位开发者按截图搭好了 `家族贡献窗.tscn`（说明 §5.2 明说
## 「贡献窗的行渲染器未移植 ⇒ 空列表态」），数据借道 `家族列表填充._填成员窗(…, 贡献榜=true)`
## 只画了 9 列行。本文件补上这一窗**独有**的四样，并把行渲染挪进来：
##   ① 族贡库存 5 格       ← `setData` 的 `_itemCells`（`FGW.as:141-165,355-363`）
##   ② 「族贡金币存量」     ← `_moneyInput`（`:354`，只读 `:182`）
##   ③ 「个人当前剩余贡值」 ← `_leftMoney`（`:307-310,365`，只读 `:249`）
##   ④ 分页 / 每页条数 / 列头排序（`PageComponent` + `MComboBox` + `SanJiaoLabel`）
##
## 数据来源（全是工程里已有的权威解析，不新造）：
##   * 5 格库存 ← `BackendConnection.authoritative_guild["materials"]` —— action 5 的
##     fields[3]，服务端 `_send_family_contribution` 按 `_family_contribution_item_ids()`
##     那五种书逐项下发；格子顺序 ← `游戏数据.family_contribution_books()`（同一份表的排序版）
##   * 族贡金币存量 ← `authoritative_guild["fund"]` —— action 5 的 fields[2]
##     ⚠️ 原版这一格是 `contri.money`（族贡仓库里的金币），而本机服务端**只有一个**家族
##        资金字段（`family.fund`）⇒ 拿它显示，不另造一个数（§0.0 第一原则）。
##   * 剩余贡值 ← `会话.guild["contribution"]` —— action 20（`游戏会话._on_backend_guild_state`）
##   * 贡献榜 9 列 ← `会话.guild["contribution_list"]` —— action 5 的 **11 字段行**
##     （前端拆表后成员窗用 action 6；旧包只送一份时回落到 `member_list`）
##     （id/名/级/职务/书籍/金币/周书籍/周金币/线/总贡献/周贡献）
##
## 交互走宿主回环：场景根是通用 `家族子窗.gd`，**所有** TextureButton（含没皮肤的分页四钮）
## 都会把 `家族贡献窗:<钮名>` 扔回 `功能窗口._show_guild_action`，那边再分发到本文件的
## `翻页` / `选每页` / `弹每页下拉`。列头是 Label，直接在本文件里接 `gui_input`。

const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")
const 家族列表填充 := preload("res://脚本/界面/窗口/家族/家族列表填充.gd")
const 家族职务 := preload("res://脚本/界面/窗口/家族/家族职务.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 行高：`FGW.as:218` list.rowHeight = 23
const 行高 := 23.0
## 每页条数：`UIConfig.fenYeSelection` 的 data（`FGW.as:240`，与 `FL.as:73-133` 同源）
const 每页选项 := [10, 30, 50, 100]
const 每页文案 := ["10项", "30项", "50项", "100项"]
## 9 列列名 = `FGW.as:30` 的 `LABEL_STRINGS`（顺序即场景 `列贡献0..8` 的顺序）
const 列名 := ["玩家名字", "等级", "族中职务", "家族书籍", "金币", "总贡献", "周贡书籍", "周贡金币", "周贡献"]
## 列名 → 排序键 = `FGW.as:32` 的 `SORT_FIELDS`（同序）
const 排序键 := ["name", "level", "rank", "books", "gold", "contribution",
	"week_books", "week_gold", "weekly_contribution"]
## 默认排序列：`FGW.as:60` `_sortField = "name"`（开窗即按名字排）
const 默认排序列 := "玩家名字"
## 行文字色：`FamillyGongXianItemRenderer.createItem`（`:73-105`）—— 名字
## `UIConfig.UI_BLUE`(2003199 = 0x1E90FF)、其余 `UI_WHITE`(16777215)。
## 职务列走 `家族职务.职务色`（原版那格是 htmlText，颜色是渲染的一部分）。
const 名列色 := Color("#1e90ff")
const 文字色 := Color.WHITE
## 排序三角：`SanJiaoLabel` 在文字右侧放一颗 `SanJiaoButton`（`SanJiaoLabel.as:50-56`，y=6）。
## 本工程没有那颗符号的导出图，列表窗是拿 `下拉箭头.png` 顶着的（`家族列表窗.tscn` 的
## `表头/三角*`）—— 这里同源复用，只在当前排序列亮。
const 三角皮 := "res://素材/界面/原版窗口/通用控件/下拉箭头.png"
const 三角尺寸 := Vector2(13.0, 8.0)
## `SanJiaoLabel.setText`：label.width = 列宽 − 钮宽 − 2 ⇒ 文字区让出 15px
const 三角留宽 := 15.0
## 「每页」下拉用 `家族列表窗._弹下拉` 同一套皮（`MPopupMenu_background`/`MPopupMenuButtonF`）
const 菜单底皮 := "res://素材/界面/原版窗口/通用控件/菜单底.png"
const 菜单项皮 := "res://素材/界面/原版窗口/通用控件/菜单按钮.png"
const 下拉项高 := 19.0
const 下拉边 := 3.0
const 下拉宽 := 60.0			# `FGW.as:239` comboBox.width = 60
const 下拉名 := "每页弹层"


static func 填(页: Control, 宿主: Node) -> void:
	# ⚠️⚠️ **只填自己这扇窗**：`家族子窗壳.切换` 开**每一扇**子窗都会把七个填充器全跑一遍，
	#    这里原先没按页名挡 ⇒ 开「成员管理窗/查询玩家/列表窗…」时本文件也跟着跑，
	#    把贡献榜的行**灌进别人的 `列表`**（列贡献0..8 在那几扇窗里不存在 ⇒ 全部按
	#    兜底 {x:0,w:100} 落位、再减容器 x ⇒ 9 列全叠在 x=-10 一团，且按名字重排、
	#    名字染成贡献窗的 UI_BLUE）—— 用户 2026-10-15 截图报的「成员管理界面不对」
	#    就是它：成员窗自己的行先被 `家族列表填充` 画好，随即被这份整页覆盖。
	#    旗帜/令牌/商城/升级/创建五个填充器都有页名守卫，这里补上同款。
	if 页 == null or 宿主 == null or String(页.name) != "家族贡献窗":
		return
	var 会话 := _会话(宿主)
	# 数据是异步到的：开窗时挂一次 `social_changed` 重填（会话收到家族帧后会发它）。
	# ⚠️ meta 键必须 ASCII（中文键会被静默丢掉，§API 陷阱 三）；也顺便防重复挂。
	if 会话 != null and 会话.has_signal("social_changed") and not 页.has_meta("gx_hooked"):
		页.set_meta("gx_hooked", true)
		家族页回调.挂(页, 会话.social_changed, func() -> void: 填(页, 宿主))
	_接列头(页, 宿主)
	_接滚动(页)
	# 开窗即拉一次贡献榜（原版 `FM.as:579-581`：`requestBanghuiQueryBanghuiContribution`
	# + `initView`）。手上还没有成员表才发 —— 用 meta 挡重复：不然每次 social_changed
	# 重填都会再发一发（`家族列表填充._填成员窗` 同一招）。
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 成员: Array = 家族.get("contribution_list", []) as Array
	if 成员.is_empty() and bool(家族.get("joined", false)) and not 页.has_meta("gx_asked"):
		var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
		if 后端 != null:
			页.set_meta("gx_asked", true)
			后端.request_guild_members(int(家族.get("id", 0)))
	_刷新(页, 宿主)


static func _刷新(页: Control, 宿主: Node) -> void:
	if 页 == null:
		return
	var 会话 := _会话(宿主)
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 后端: Node = 宿主.get_node_or_null("/root/BackendConnection") if 宿主 != null else null
	_填存量(页, 后端)
	_填库存(页, 后端)
	_填剩贡(页, 家族)
	_重算(页, 宿主)
	_同步三角(页)


## 「族贡金币存量」：原版 `FGW.as:354` `_moneyInput.text = contri.money`，且 `:182`
## `enableInput = false` ⇒ 场景里那颗 LineEdit 也要置成不可编辑。
static func _填存量(页: Control, 后端: Node) -> void:
	var 框 := 页.get_node_or_null("输入存量") as LineEdit
	if 框 == null:
		return
	框.editable = false
	var 资金 := 0
	if 后端 != null:
		资金 = int((后端.get("authoritative_guild") as Dictionary).get("fund", 0))
	框.text = str(资金)


## 族贡库存 5 格：原版 `FGW.as:355-363` —— `contri.items` 有几项就填几格，每格
## `itemData`（图标居中）+ `label`（件数）。件数那条 Label 的几何照
## `SimpleItemCell.as:136-144` 的 countLabel：白字、40×20、落在 (0,20)、右对齐。
## ⚠️ 服务端 `_send_family_contribution` 的 item_stock **恒含全部五种书**（按
##    `_family_contribution_item_ids()` 逐项生成，件数可能是 0）⇒ 五格永远有图标，
##    件数为 0 时显示 "0"（原版 `label = count + ""` 也是这样，不为 0 才显示反而失真）。
static func _填库存(页: Control, 后端: Node) -> void:
	var 库存: Dictionary = {}
	if 后端 != null:
		库存 = (后端.get("authoritative_guild") as Dictionary).get("materials", {}) as Dictionary
	var 书们 := 游戏数据.family_contribution_books()
	for i in 5:
		var 格 := 页.get_node_or_null("格%d" % i) as Control
		if 格 == null:
			continue
		var 号 := int(书们[i]) if i < 书们.size() else 0
		var 件数 := int(库存.get(号, 0)) if 号 > 0 else 0
		var 图 := 格.get_node_or_null("图标") as TextureRect
		if 图 == null:
			图 = _建图标()
			格.add_child(图)
		图.texture = 游戏数据.item_icon(号) if 号 > 0 else null
		var 字 := 格.get_node_or_null("数量") as Label
		if 字 == null:
			字 = _建数量()
			格.add_child(字)
		字.text = str(件数) if 号 > 0 else ""


## 「个人当前剩余贡值」：原版 `FGW.as:307-310` `setGongXianLeafValue` ←
## `FamillyManager.gongXianLeafValue`（action 20 的 contriValue，`FM.as:1009-1019`），
## 只读框（`:249` `enableInput = false`）。
static func _填剩贡(页: Control, 家族: Dictionary) -> void:
	var 框 := 页.get_node_or_null("输入剩贡") as LineEdit
	if 框 == null:
		return
	框.editable = false
	框.text = str(int(家族.get("contribution", 0)))


## 原版 `updateList()`（`FGW.as:76-85`）：排序 → 分页 → 取当前页。
static func _重算(页: Control, 宿主: Node) -> void:
	var 表 := _成员(宿主)
	_排序(页, 表)
	var 总 := _总页数(页, 表)
	页.set_meta("gx_page", clampi(int(页.get_meta("gx_page", 1)), 1, 总))
	var 每页 := int(每页选项[_每页序(页)])
	var 页号 := int(页.get_meta("gx_page", 1))
	_渲染(页, 表.slice((页号 - 1) * 每页, mini(表.size(), 页号 * 每页)))
	_同步分页(页, 总)


static func _成员(宿主: Node) -> Array:
	var 会话 := _会话(宿主)
	if 会话 == null:
		return []
	var 家族: Dictionary = 会话.guild as Dictionary
	# 贡献榜专用表（`1552:5` 的 11 字段行）。旧后端把两套行都塞进 `member_list`，
	# 所以这里保留回落 —— 单机/旧包只送一份时贡献窗照样有内容。
	var 表: Array = 家族.get("contribution_list", []) as Array
	return (表 if not 表.is_empty() else 家族.get("member_list", []) as Array).duplicate()


## 列头排序（原版 `applySort`，`FGW.as:312-337`）。
## ⚠️ 方向是**按字段写死**的：名字 `Array.CASEINSENSITIVE`（升序）、职务 `sortOn("rank")`
##    （升序，1=族长排最前），其余全带 `DESCENDING`（降序）。
##    `_isDesending` 那个字段在 `applySort` 里**根本没被读**（`:58` 声明、`:434` 赋值，
##    没有任何读取点）—— 是原版的死代码，别照抄"再点一次反向"。
static func _排序(页: Control, 表: Array) -> void:
	var 列 := String(页.get_meta("gx_sort_col", 默认排序列))
	var 键 := "name"
	if 列名.has(列):
		键 = String(排序键[列名.find(列)])
	match 键:
		"name":
			表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
				return String(甲.get("name", "")).to_lower() < String(乙.get("name", "")).to_lower())
		"rank":
			表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
				return int(甲.get("rank", 1)) < int(乙.get("rank", 1)))
		_:
			表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
				return int(甲.get(键, 0)) > int(乙.get(键, 0)))


static func _总页数(页: Control, 表: Array) -> int:
	var 每页 := int(每页选项[_每页序(页)])
	return maxi(1, int(ceilf(float(表.size()) / float(每页))))


static func _每页序(页: Control) -> int:
	return clampi(int(页.get_meta("gx_per_idx", 0)), 0, 每页选项.size() - 1)


## 只把当前页那一段渲染成行（原版 `updateCurrentPage`，`FGW.as:111-114`：整表换 dataProvider）。
## 列位从场景表头节点量一次存进 meta（`gx_cols`）—— 表头的 size.x 后来被 `_接列头`
## 让给排序三角了，行渲染不能再拿它当列宽。
## ⚠️ 行 Label 的 x 要**减掉容器的原点**：表头量的是页坐标，行画在 `列表` 容器里。
##    不减就是整体右移一个容器 x（成员窗/贡献窗原来都错着位，2026-10-14 一并修）。
static func _渲染(页: Control, 页行: Array) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	页.set_meta("gx_offset", 0.0)		# 换页/重排 ⇒ 滚回顶上
	for 子 in 容器.get_children():
		容器.remove_child(子)
		子.queue_free()
	if 页行.is_empty():
		_空提示(容器)
		return
	var 列位: Array = 页.get_meta("gx_cols", [])
	var 起 := 容器.position.x
	for i in 页行.size():
		var 记: Dictionary = 页行[i]
		var 行 := Control.new()
		行.name = "行%d" % (i + 1)
		行.size = Vector2(容器.size.x, 行高)
		行.position = Vector2(0.0, i * 行高)
		行.mouse_filter = Control.MOUSE_FILTER_IGNORE
		容器.add_child(行)
		for c in 列位.size():
			var 字 := Label.new()
			字.name = "列%d" % c
			字.position = Vector2(float(列位[c]["x"]) - 起, 2.0)
			字.size = Vector2(float(列位[c]["w"]), 19.0)
			字.text = _列值(c, 记)
			字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# `CommonItemRenderer.cretateLabel` 是裸 TextField + size 12 ⇒ 字号 12
			字.add_theme_font_size_override("font_size", 12)
			字.add_theme_color_override("font_color", _列色(c, 记))
			行.add_child(字)


## 9 列取数。字段名对齐 action 5 的 **11 字段行**（见 `后端连接._handle_guild_text`
## action 5 的注释）：parts[4] 书籍 / [5] 金币 / [6] 周书籍 / [7] 周金币 / [9] 总贡献 /
## [10] 周贡献。原版这里是 `contri.items` 求和（`FamillyGongXianItemRenderer.as:40-62`）
## —— 服务端已经按这个口径逐项算好下发，直接取即可。
static func _列值(c: int, 记: Dictionary) -> String:
	match c:
		0: return String(记.get("name", "-"))
		1: return str(int(记.get("level", 0)))
		2: return 家族职务.职务名(int(记.get("rank", 1)))
		3: return str(int(记.get("books", 0)))
		4: return str(int(记.get("gold", 0)))
		5: return str(int(记.get("contribution", 0)))
		6: return str(int(记.get("week_books", 0)))
		7: return str(int(记.get("week_gold", 0)))
		8: return str(int(记.get("weekly_contribution", 0)))
	return "-"


static func _列色(c: int, 记: Dictionary) -> Color:
	if c == 0:
		return 名列色
	if c == 2:
		return 家族职务.职务色(int(记.get("rank", 1)))
	return 文字色


## 空列表态。原版是空 `DataProvider`（什么都不画）；本工程各列表窗都有居中提示
## （`家族列表填充._空提示` 同款），跟成员窗口径一致。
static func _空提示(容器: Control) -> void:
	var 提示 := Label.new()
	提示.name = "空提示"
	提示.size = Vector2(容器.size.x, 行高)
	提示.text = "暂无贡献记录"
	提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	提示.add_theme_color_override("font_color", Color("#a9957f"))
	容器.add_child(提示)


## 页码 + 四钮禁用态 + 「每页」触发器文字。禁用判据照 `家族列表窗._同步分页`；
## 原版 `PageComponent.__onArrowBtnClick` 也是先钳制再跳页。
static func _同步分页(页: Control, 总: int) -> void:
	var 页号 := int(页.get_meta("gx_page", 1))
	var 页码 := 页.get_node_or_null("分页分页/页码") as Label
	if 页码 != null:
		页码.text = "%d/%d" % [页号, 总]
	for 对 in [["首页", 1], ["上一页", 页号 - 1], ["下一页", 页号 + 1], ["末页", 总]]:
		var 钮 := 页.get_node_or_null("分页分页/" + String(对[0])) as TextureButton
		if 钮 != null:
			钮.disabled = int(对[1]) == 页号 or int(对[1]) < 1 or int(对[1]) > 总
	# 触发器上那行文字 = 原版 MComboBox 的 selectedLabel
	var 下拉 := 页.get_node_or_null("下拉页/文字") as Label
	if 下拉 != null:
		下拉.text = String(每页文案[_每页序(页)])


## 分页四钮（原版 `PageComponent` 四个箭头 + `PageEvent.SET_PAGE`，`FGW.as:230-234,302-305`；
## 钳制抄 `PageComponent.__onArrowBtnClick`：上一页不低于 1、下一页不高于总页数）。
static func 翻页(页: Control, 宿主: Node, 目标: String) -> void:
	if 页 == null:
		return
	var 总 := _总页数(页, _成员(宿主))
	var 现 := clampi(int(页.get_meta("gx_page", 1)), 1, 总)
	match 目标:
		"首页": 页.set_meta("gx_page", 1)
		"上一页": 页.set_meta("gx_page", maxi(1, 现 - 1))
		"下一页": 页.set_meta("gx_page", mini(总, 现 + 1))
		"末页": 页.set_meta("gx_page", 总)
		_: return
	_刷新(页, 宿主)


## 每页条数（原版 `MComboBox` + `Event.CHANGE` → `yeBoxChangeHandler`，
## `FGW.as:105-109,238-244`）。`applyFenYe` → `PageComponent.reset` 会把 currentPage
## 打回 1（`PageComponent.as` 的 reset）⇒ 这里同步回第 1 页。
static func 选每页(页: Control, 宿主: Node, 序: int) -> void:
	if 页 == null:
		return
	页.set_meta("gx_per_idx", clampi(序, 0, 每页选项.size() - 1))
	页.set_meta("gx_page", 1)
	_刷新(页, 宿主)


## 列头排序（原版 `clickSanJiaoLabelHandler`，`FGW.as:431-437`）。
static func 排序列(页: Control, 宿主: Node, 列: String) -> void:
	if 页 == null or not 列名.has(列):
		return
	页.set_meta("gx_sort_col", 列)
	页.set_meta("gx_page", 1)
	_刷新(页, 宿主)


## 「每页」下拉。原版是 `MComboBox`（`FGW.as:238-244`），工程里没有通用下拉组件，
## 照 `家族列表窗._弹下拉` 现搭（同一套菜单皮、同一种"点别处收起"的手感）。
## ⚠️ 弹层挂在**内容页自己**上：这一页不像列表窗那样被 `列表窗口` 裁着，压住整页就够
##    （列表窗那边必须挂到窗根，原因见它 `_弹下拉` 的注释）。
static func 弹每页下拉(页: Control, 宿主: Node) -> void:
	if 页 == null:
		return
	if 页.get_node_or_null(下拉名) != null:		# 开着 ⇒ 再点一次收起
		_关下拉(页)
		return
	var 锚 := 页.get_node_or_null("下拉页") as Control
	if 锚 == null:
		return
	_关下拉(页)
	# 遮罩：整页一张接点击的透明层。点它（= 点到菜单以外）就收起 —— 原版 MComboBox
	# 失焦即收。用遮罩而不是页自己的 `gui_input`：页上还排着一堆 IGNORE 的子节点会透传。
	var 罩 := Control.new()
	罩.name = 下拉名
	罩.set_anchors_preset(Control.PRESET_FULL_RECT)
	罩.mouse_filter = Control.MOUSE_FILTER_STOP
	页.add_child(罩)
	var 宽 := 下拉宽
	for 文 in 每页文案:
		宽 = maxf(宽, _字宽(String(文)) + 6.0)
	var 菜单 := Panel.new()
	菜单.name = "菜单"
	菜单.mouse_filter = Control.MOUSE_FILTER_STOP
	var 底皮 := StyleBoxTexture.new()
	底皮.texture = load(菜单底皮) as Texture2D
	底皮.texture_margin_left = 5.75
	底皮.texture_margin_top = 4.75
	底皮.texture_margin_right = 9.75
	底皮.texture_margin_bottom = 11.0
	菜单.add_theme_stylebox_override("panel", 底皮)
	罩.add_child(菜单)
	var 项皮 := StyleBoxTexture.new()
	项皮.texture = load(菜单项皮) as Texture2D
	项皮.texture_margin_left = 2.25
	项皮.texture_margin_top = 2.0
	项皮.texture_margin_right = 2.5
	项皮.texture_margin_bottom = 2.5
	var 顶 := 下拉边
	for i in 每页文案.size():
		var 项 := Button.new()
		项.name = "项%d" % i
		项.text = String(每页文案[i])
		项.flat = true
		项.focus_mode = Control.FOCUS_NONE
		项.add_theme_font_size_override("font_size", 12)
		# 当前选中的那项用白字（原版 MComboBox 高亮的也是选中那条）
		项.add_theme_color_override("font_color", Color.WHITE if i == _每页序(页) else Color("#FCF49C"))
		for 态 in ["normal", "hover", "pressed"]:
			项.add_theme_stylebox_override(态, 项皮)
		项.position = Vector2(下拉边, 顶)
		项.size = Vector2(宽 - 下拉边 * 2.0, 下拉项高)
		# ⚠️ 用 `bind` 显式带序号，不靠 lambda 捕循环变量（`家族列表窗._弹下拉` 同）
		项.pressed.connect(_选下拉项.bind(页, 宿主, i))
		菜单.add_child(项)
		顶 += 下拉项高 + 下拉边
	菜单.size = Vector2(宽, 顶)
	# 下方放不下就往上开（真下拉都这么干）：这一页的锚在 y=309，下面只剩 61px，装不下 4 项
	var 落 := 锚.position.y + 锚.size.y + 2.0
	if 落 + 顶 > 页.size.y:
		落 = 锚.position.y - 顶 - 2.0
	菜单.position = Vector2(minf(锚.position.x, 页.size.x - 宽), maxf(0.0, 落))
	罩.gui_input.connect(_点罩.bind(页))


## ⚠️ 形参就是全部实参：`pressed` 信号没有参数，`bind` 加的几个就是几个。
static func _选下拉项(页: Control, 宿主: Node, 序: int) -> void:
	_关下拉(页)
	选每页(页, 宿主, 序)


## 点到菜单外 ⇒ 收起。菜单自己是 STOP 的 Panel + Button，点到它不会透传到罩，
## 所以能走到这里就说明点在菜单外。
static func _点罩(事件: InputEvent, 页: Control) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_关下拉(页)


static func _关下拉(页: Control) -> void:
	if 页 == null:
		return
	var 罩 := 页.get_node_or_null(下拉名) as Control
	if 罩 != null and is_instance_valid(罩):
		页.remove_child(罩)
		罩.queue_free()


## 列头接线（原版 `SanJiaoLabel`：文字 + 右侧一颗可点的排序三角，`SanJiaoLabel.as:50-56`）。
## 场景里那九格是 `Label`（原版是可点的 `SanJiaoLabel`）⇒ 运行时把 `mouse_filter` 打开、
## 按 `setText` 的口径把文字区让出 `三角留宽`，再在右侧补一颗三角。
static func _接列头(页: Control, 宿主: Node) -> void:
	if 页.has_meta("gx_head_hooked"):
		return
	页.set_meta("gx_head_hooked", true)
	# 表头几何在这里量一次就存进 meta：下面让宽之后表头自己的 size.x 就变了
	var 列位 := 家族列表填充._列位(页, "列贡献", 列名.size())
	页.set_meta("gx_cols", 列位)
	for i in 列名.size():
		var 头 := 页.get_node_or_null("列贡献%d" % i) as Label
		if 头 == null:
			continue
		头.mouse_filter = Control.MOUSE_FILTER_STOP
		头.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		头.size = Vector2(float(列位[i]["w"]) - 三角留宽, 头.size.y)
		var 三 := TextureRect.new()
		三.name = "排序三角%d" % i
		三.texture = load(三角皮) as Texture2D
		三.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		三.stretch_mode = TextureRect.STRETCH_KEEP
		三.size = 三角尺寸
		三.position = Vector2(float(列位[i]["w"]) - 三角尺寸.x - 1.0, 6.0)
		三.mouse_filter = Control.MOUSE_FILTER_IGNORE
		三.visible = String(列名[i]) == String(页.get_meta("gx_sort_col", 默认排序列))
		头.add_child(三)
		# ⚠️ 形参顺序必须是 `(事件, 页, 宿主, 列)`：`Callable.bind()` 的参数追加在信号参数
		#    之后，`gui_input` 先发事件 —— 反过来写会报错然后**静默什么都不做**（本工程老坑）。
		头.gui_input.connect(_点列头.bind(页, 宿主, String(列名[i])))


## 列头点击（原版 `clickSanJiaoLabelHandler`，`FGW.as:431-437`）。
## ⚠️ 再点同一列**不换向**：`_isDesending` 在 `applySort` 里根本没被读（见 `_排序` 的注释）。
static func _点列头(事件: InputEvent, 页: Control, 宿主: Node, 列: String) -> void:
	var 按 := 事件 as InputEventMouseButton
	if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if String(页.get_meta("gx_sort_col", 默认排序列)) == 列:
		return
	排序列(页, 宿主, 列)
	页.get_viewport().set_input_as_handled()


## 排序三角只亮在当前排序列（`SanJiaoLabel.selected` 的对应物）。
static func _同步三角(页: Control) -> void:
	for i in 列名.size():
		var 三 := 页.get_node_or_null("列贡献%d/排序三角%d" % [i, i]) as TextureRect
		if 三 != null:
			三.visible = String(列名[i]) == String(页.get_meta("gx_sort_col", 默认排序列))


## 列表滚轮。原版 `_list` 是 `fl.controls.List`（滚动容器）：每页默认 10 条，而这一页的
## 列表区只有 160px 高（`FGW.as:222`）= 6.96 行 ⇒ 第 7 行往后必须能滚（原版也没有
## 可见滚动条， Flash List 的竖条是 AUTO 策略、内容不超就不出现）。
## ⚠️ 容器要自己开 `mouse_filter`：场景里它是 IGNORE（2），不收输入。
static func _接滚动(页: Control) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null or 容器.has_meta("gx_scroll_hooked"):
		return
	容器.set_meta("gx_scroll_hooked", true)
	容器.mouse_filter = Control.MOUSE_FILTER_STOP
	容器.gui_input.connect(_滚轮.bind(页))


## ⚠️ 形参顺序 `(事件, 页)`：`Callable.bind()` 的参数追加在信号参数之后。
static func _滚轮(事件: InputEvent, 页: Control) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if 按.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_滚(页, -12.0 if 按.button_index == MOUSE_BUTTON_WHEEL_UP else 12.0)
		页.get_viewport().set_input_as_handled()


static func _滚(页: Control, 像素: float) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	var 行们 := 容器.get_children()
	if 行们.is_empty():
		return
	# 空提示那一行也算一个子节点，但它不参与滚动（上限算出来是负的 ⇒ 钳到 0）
	var 上限 := maxf(0.0, 行们.size() * 行高 - 容器.size.y)
	var 偏 := clampf(float(页.get_meta("gx_offset", 0.0)) + 像素, 0.0, 上限)
	页.set_meta("gx_offset", 偏)
	for i in 行们.size():
		(行们[i] as Control).position.y = i * 行高 - 偏


## 格子里的图标/件数，几何照 `SimpleItemCell`：图标居中（`setIcon`：
## `x = (宽−图宽)/2`）、件数白字右对齐落在 (0,20)（countLabel）。
static func _建图标() -> TextureRect:
	var 图 := TextureRect.new()
	图.name = "图标"
	图.position = Vector2(4.0, 4.0)
	图.size = Vector2(32.0, 32.0)
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_SCALE
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 图


static func _建数量() -> Label:
	var 字 := Label.new()
	字.name = "数量"
	字.position = Vector2(0.0, 20.0)
	字.size = Vector2(40.0, 20.0)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", Color.WHITE)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return 字


## 下拉宽度用的字宽估算（中文 12px、其余 6px，与 `家族列表窗._字宽`/`好友菜单` 同一套）。
static func _字宽(文: String) -> float:
	var 尺 := 0.0
	for i in 文.length():
		尺 += 12.0 if 文.unicode_at(i) > 0x2E80 else 6.0
	return 尺


static func _会话(宿主: Node) -> Node:
	return 宿主.get("_session") if 宿主 != null else null

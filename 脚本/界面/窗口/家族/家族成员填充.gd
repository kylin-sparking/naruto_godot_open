extends RefCounted
## 家族成员管理窗内容页的填充（原版 `FamillyMembersWindow`，`FMEM.as`，`super(634,332)`）。
##
## 这一窗原来是**纯 UI**：另一位开发者按截图搭好了 `家族成员窗.tscn`（说明 §5.2 明说
## 「成员/贡献/旗帜/搜索的行渲染器未移植 ⇒ 空列表态」），行由 `家族列表填充._填成员窗`
## 借了一手 —— 但那份是"只读快照"：没有选中、没有行菜单、没有排序/筛选/分页，
## 也不分族长/副族长，开除/任命/禅让/弹劾全都没有入口（用户 2026-11 报的
## 「家族成员管理没实装」）。本文件按 AS3 逐行补齐：
##   ① 9 列成员行 + 选中/悬停底（`FamillyMemberItemRender.as`）
##   ② 列头排序（`SanJiaoLabel`，`:158-190,415-417`；最后一列**不可点**）
##   ③ 「显示」筛选：所有 / 线上 / 离线（`:74-106`）
##   ④ 分页 + 每页条数（`PageComponent` + `MComboBox`，`:117-130,207-213,329-334`）
##   ⑤ 行菜单（`FamillyMemberItemRender.as:47-66` → `FamillyManager.cickMenuItemHandler`）
##   ⑥ 按钮/复选框的启用态（`update`，`:369-385`；`checkBox.visible = isManager`，`:405`）
##
## 数据来源（工程里已有的权威解析，不新造）：
##   * 成员行 ← `会话.guild["member_list"]` —— `1552:6` 的 **17 字段行**
##     （`后端连接._handle_guild_text` action 6：id/名/级/职务/职业/脸/性别/0/总贡献/
##      周贡献/线/昵称/忍术/八门/成就/声望/本周BOSS）
##   * 族长判定 ← `authoritative_guild["leader_id"]`（`1552:15` 的 fields[6]）
##     == 自己的 `backend.character_id`（原版 `FM.as:455-461` 的 `isManager` 同口径）
##   * 职务 ← 成员行里的 `rank`（服务端 `family.ranks`；1/2/3/4/5/9999）
##
## ⚠️ **自动同意复选框是本工程的有意偏离**：原版 `checkBoxChangeHandler`（`:383-388`）
##    只写本地 `CharacterConfig.banghuiAutoAcceptMember` 再 `synch()`，**不发协议**；
##    本工程改成了服务端权威（`request_guild_auto_accept` → `1552:20`），
##    状态由 `1552:15` 回带（服务端 `_send_family_info` 追加的第 8 个字段）。
##    理由：多人服务端本来就存 `family.autoAccept` 并据此自动批申请，只写本地配置
##    就是"看着勾上了、服务端该拦还是拦"。详见 `后端连接.request_guild_auto_accept`。
##
## 交互一律交回宿主（`功能窗口._家族成员菜单动作` / `_show_guild_action`）：
## 这一页只做美术与本地状态（分页/排序/筛选/选中），协议不在这里发。

const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")
const 家族列表填充 := preload("res://脚本/界面/窗口/家族/家族列表填充.gd")
const 家族职务 := preload("res://脚本/界面/窗口/家族/家族职务.gd")
const 好友菜单 := preload("res://脚本/界面/窗口/好友/好友菜单.gd")

## `FamillyMemberItemRender.as:29-31`：`super(599,23)`；行高同 `FMEM.as:208` rowHeight=23
const 行高 := 23.0
const 行宽 := 599.0
## 选中/悬停底 = `MSelected_background1`（符号 705）九宫格，与家族列表窗同一份真值
const 行选中底皮 := "res://素材/界面/原版窗口/家族/行选中底.png"
const 选中底边 := {"左": 7.0, "上": 5.35, "右": 7.9, "下": 5.75}
## 9 列 = `FMEM.as:23` 的 `LABEL_STRINGS`（顺序即场景 `列成员0..8`）
const 列名 := ["成员名称", "等级", "职务", "忍术层数", "八门进度", "成就进度", "战场声望", "本周BOSS", "本族贡献"]
## 列名 → 排序键 = `FMEM.as:25` 的 `SORT_FIELDS`（同序；最后一列原版就**没挂**排序回调）
const 排序键 := ["name", "level", "rank", "skill", "mai", "chengJiu", "shengWang", "boss", "share"]
## 默认排序列：`FMEM.as:27` `_sortField = "name"`（名字升序、忽略大小写）
const 默认排序列 := "成员名称"
## 可排序列数：`:186` 最后一列传 `param6 = false` ⇒ 没有 `SanJiaoLabel` 的三角/点击
const 可排序列数 := 8
## 每页条数：`UIConfig.fenYeSelection`（`FMEM.as:209`）
const 每页选项 := [10, 30, 50, 100]
const 每页文案 := ["10项", "30项", "50项", "100项"]
## 「显示」筛选：`FMEM.as:398` 的 `_memberSelectBox.selectedIndex = 0`；文案取 `FAMILLY_MEMBERS_ALL/ONLINE/OFFLINE`
const 筛选文案 := ["所有", "线上", "离线"]
const 筛选键 := ["all", "online", "offline"]
## 行文字色（`FamillyMemberItemRender.as:96-105`）：名绿 / 离线 0xCCCCCC / BOSS 红，
## 职务列是 `getRankName` 的 htmlText ⇒ 走 `家族职务.职务色`，其余白
const 名列在线色 := Color("#00ff00")
const 名列离线色 := Color("#cccccc")
const 本周boss红 := Color("#ff0000")
const 行白 := Color.WHITE
## 排序三角：`SanJiaoLabel` 在文字右侧放一颗 `SanJiaoButton`（`SanJiaoLabel.as:50-56`）。
## 与贡献窗/列表窗同一张顶替皮（工程里没导出那颗符号）。
const 三角皮 := "res://素材/界面/原版窗口/通用控件/下拉箭头.png"
const 三角尺寸 := Vector2(13.0, 8.0)
const 三角留宽 := 15.0
## 下拉皮（`MComboBox` 的列表 = `MPopupMenu_background`/`MPopupMenuButtonF`）
const 菜单底皮 := "res://素材/界面/原版窗口/通用控件/菜单底.png"
const 菜单项皮 := "res://素材/界面/原版窗口/通用控件/菜单按钮.png"
const 下拉项高 := 19.0
const 下拉边 := 3.0
const 下拉宽 := 60.0			# `FMEM.as:208` comboBox.width = 60
const 弹层名 := "成员弹层"
## 行菜单（`FM.as:36-45` 的项表；`""` = 分隔线）
const 菜单_查看 := "查看资料"
const 菜单_好友 := "加为好友"
const 菜单_禅让 := "禅让族长"
const 菜单_弹劾 := "弹劾族长"
const 菜单_任命 := ["任命副族长", "任命长老", "任命顾问", "任命精英", "任命族员"]
const 任命职级 := [2, 3, 4, 5, 9999]
## 自动同意复选框皮（`家族子窗.勾皮` 同一对）
const 勾皮 := ["res://素材/界面/原版窗口/通用控件/复选框未选.png",
			  "res://素材/界面/原版窗口/通用控件/复选框选中.png"]
## 空列表提示色（各家族列表窗同款）
const 空提示色 := Color("#a9957f")


static func 填(页: Control, 宿主: Node) -> void:
	# ⚠️ 只填自己这扇窗：`家族子窗壳.切换` 开每一扇子窗都会把七个填充器全跑一遍。
	if 页 == null or 宿主 == null or String(页.name) != "家族成员窗":
		return
	var 会话 := _会话(宿主)
	# 异步数据：开窗挂一次 `social_changed` 重填。meta 键必须 ASCII。
	if 会话 != null and 会话.has_signal("social_changed") and not 页.has_meta("mg_hooked"):
		页.set_meta("mg_hooked", true)
		家族页回调.挂(页, 会话.social_changed, func() -> void: 填(页, 宿主))
	_接列头(页, 宿主)
	_接滚动(页)
	_接行菜单(页, 宿主)
	# 开窗即拉一次成员表（原版 `FM.as:604` `requestBanghuiQueryBanghuiMemberList`
	# → `1552:105`）。只有手上还没有成员行才发，用 meta 挡重复。
	var 家族: Dictionary = (会话.guild if 会话 != null else {}) as Dictionary
	var 成员: Array = 家族.get("member_list", []) as Array
	if 成员.is_empty() and bool(家族.get("joined", false)) and not 页.has_meta("mg_asked"):
		var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
		if 后端 != null:
			页.set_meta("mg_asked", true)
			后端.request_guild_members(int(家族.get("id", 0)), true)
	刷新(页, 宿主)


static func 刷新(页: Control, 宿主: Node) -> void:
	if 页 == null:
		return
	_同步钮态(页, 宿主)
	_同步勾选(页, 宿主)
	_重算(页, 宿主)
	_同步三角(页)


## 当前选中的那一行（没选中/已翻页 ⇒ 空字典）。宿主「开除出族」读它 ——
## 对应原版 `fireMemberHandler`（`FMEM.as:362-368`）读 `list.selectedItem.id/name`。
static func 选中成员(页: Control) -> Dictionary:
	if 页 == null:
		return {}
	var 序: int = int(页.get_meta("mg_selected", -1))
	var 行们: Array = 页.get_meta("mg_page_rows", []) as Array
	if 序 < 0 or 序 >= 行们.size():
		return {}
	return 行们[序] as Dictionary


## 族长判定 = 原版 `FamillyManager.isManager`（`FM.as:455-461`：leaderId == 自己）。
static func 是族长(宿主: Node) -> bool:
	var 后 := _后端(宿主)
	if 后 == null:
		return false
	var 我 := int(后.get("character_id"))
	if 我 <= 0:
		return false
	var 长 := int(_族(宿主).get("leader_id", 0))
	if 长 > 0:
		return 长 == 我
	# 旧包没有 `1552:15` 的族长字段：退回成员行（自己 rank 1 即族长）
	return 我的职务(宿主) == 1


## 自己的职务（没在成员表里 ⇒ 0；旧包没有 rank 的成员行按族员 9999）。
static func 我的职务(宿主: Node) -> int:
	var 后 := _后端(宿主)
	if 后 == null:
		return 0
	var 我 := int(后.get("character_id"))
	if 我 <= 0:
		return 0
	for 条 in _族(宿主).get("member_list", []) as Array:
		if int((条 as Dictionary).get("character_id", 0)) == 我:
			return int((条 as Dictionary).get("rank", 9999))
	return 0


## 自动同意的权威值（服务端 `1552:15` 第 8 字段；没回带时按关）。
static func 自动同意(宿主: Node) -> bool:
	return bool(_族(宿主).get("auto_accept", false))


## 行菜单弹层（原版 `FM.showMenu`，`FM.as:1276`：在点击点弹出）。
## 调用方：本页 `_点行`。菜单只发信号，动作交回宿主 `_家族成员菜单动作`。
static func _接行菜单(页: Control, 宿主: Node) -> void:
	if 页.get_node_or_null("行菜单") != null:
		return
	var 菜 := 好友菜单.new() as Control
	菜.name = "行菜单"
	页.add_child(菜)
	# 信号先带 (文本, 项)，bind 的参数追加在后面 ⇒ (文本, 项, 页, 宿主)
	菜.项点击.connect(_菜单项.bind(页, 宿主))


static func _菜单项(文本: String, 项: Dictionary, 页: Control, 宿主: Node) -> void:
	if is_instance_valid(页) and 宿主 != null and 宿主.has_method("_家族成员菜单动作"):
		宿主.call("_家族成员菜单动作", 文本, 项)


## 行菜单项表（`FamillyMemberItemRender.clickHandler:47-66`）：
##   * 族长（isManager）→ `famillyManagerMenuNames`（任命五项 + 禅让，`FM.as:36-45`）
##   * 非族长看的是族长那一行 → 成员菜单 + ["", 弹劾族长(红)]
##   * 其余 → `famillyMemberMenuNames`（查看资料/加为好友）
static func _菜单表(宿主: Node, 项: Dictionary) -> Array:
	var 表: Array = []
	if 是族长(宿主):
		var 红 := Color("#ff0000")
		表.append(菜单_查看)
		表.append(菜单_好友)
		表.append("")
		表.append_array(菜单_任命)
		表.append("")
		表.append({"name": 菜单_禅让, "color": 红})
	elif int(项.get("character_id", 0)) == int(_族(宿主).get("leader_id", -1)):
		表.append(菜单_查看)
		表.append(菜单_好友)
		表.append("")
		表.append({"name": 菜单_弹劾, "color": Color("#ff0000")})
	else:
		表.append(菜单_查看)
		表.append(菜单_好友)
	return 表


## 原版 `updateList()`（`FMEM.as:132-138`）：筛选 → 排序 → 分页 → 取当前页。
static func _重算(页: Control, 宿主: Node) -> void:
	var 表 := _筛选(页, _成员(宿主))
	_排序(页, 表)
	var 总 := _总页数(页, 表)
	var 页号: int = clampi(int(页.get_meta("mg_page", 1)), 1, 总)
	页.set_meta("mg_page", 页号)
	var 每页: int = int(每页选项[_每页序(页)])
	_渲染(页, 宿主, 表.slice((页号 - 1) * 每页, mini(表.size(), 页号 * 每页)))
	_同步分页(页, 总)


static func _成员(宿主: Node) -> Array:
	var 族 := _族(宿主)
	return (族.get("member_list", []) as Array).duplicate()


## 筛选（原版 `applyFilter`，`FMEM.as:74-106`）：0 所有 / 1 `channelId > -1` / 2 `< 0`。
## ⚠️ 没有 `channel_id` 键的旧行按在线算（服务端 `1552:6` 恒给，摘要行才没有）。
static func _筛选(页: Control, 表: Array) -> Array:
	var 序: int = clampi(int(页.get_meta("mg_filter", 0)), 0, 筛选键.size() - 1)
	if 序 == 0:
		return 表
	var 出: Array = []
	for 记 in 表:
		var 线 := int((记 as Dictionary).get("channel_id", 0))
		if (序 == 1 and 线 >= 0) or (序 == 2 and 线 < 0):
			出.append(记)
	return 出


## 列头排序（原版 `applySort`，`FMEM.as:294-325`）：
## 名字升序忽略大小写、职务升序（1=族长最前）、其余数值降序。
## ⚠️ `_isDesending` 在 `applySort` 里**根本没被读**（`:59` 声明、`:416` 赋值）——原版死代码。
static func _排序(页: Control, 表: Array) -> void:
	var 列 := String(页.get_meta("mg_sort_col", 默认排序列))
	var 键 := "name"
	if 列名.has(列):
		键 = String(排序键[列名.find(列)])
	match 键:
		"name":
			表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
				return String(甲.get("name", "")).to_lower() < String(乙.get("name", "")).to_lower())
		"rank":
			表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
				return int(甲.get("rank", 9999)) < int(乙.get("rank", 9999)))
		_:
			# 排序键是 AS3 的字段名，成员行里是后端解出来的同名键（skillValue/maiValue/…）
			var 读键 := _读键(键)
			表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
				return int(甲.get(读键, 0)) > int(乙.get(读键, 0)))


## AS3 排序键 → 成员行里的键。`share` 没挂排序，不会走到这里。
static func _读键(键: String) -> String:
	match 键:
		"skill": return "skillValue"
		"mai": return "maiValue"
		"chengJiu": return "chengjiuValue"
		"shengWang": return "shengwangValue"
		"boss": return "bossValue"
		"share": return "contriValue"
	return 键


static func _总页数(页: Control, 表: Array) -> int:
	var 每页: int = int(每页选项[_每页序(页)])
	return maxi(1, int(ceilf(float(表.size()) / float(每页))))


static func _每页序(页: Control) -> int:
	return clampi(int(页.get_meta("mg_per_idx", 0)), 0, 每页选项.size() - 1)


## 渲染当前页（原版 `updateCurrentPage`，`FMEM.as:276-282` 整表换 dataProvider）。
## 列位从表头量一次存进 meta（`mg_cols`）—— `_接列头` 之后表头自己的 size.x 已让给三角。
static func _渲染(页: Control, 宿主: Node, 页行: Array) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	页.set_meta("mg_page_rows", 页行)
	页.set_meta("mg_selected", -1)
	页.set_meta("mg_offset", 0.0)		# 换页/重排/筛选 ⇒ 滚回顶上
	for 子 in 容器.get_children():
		容器.remove_child(子)
		子.queue_free()
	if 页行.is_empty():
		_空提示(容器)
		return
	var 列位: Array = 页.get_meta("mg_cols", [])
	var 起 := 容器.position.x
	for i in 页行.size():
		var 记: Dictionary = 页行[i] as Dictionary
		var 行 := Control.new()
		行.name = "行%d" % (i + 1)
		行.size = Vector2(行宽, 行高)
		行.position = Vector2(0.0, i * 行高)
		# ⚠️ 必须 STOP：IGNORE 收不到 mouse_entered/gui_input ⇒ 行选不中、菜单弹不出
		行.mouse_filter = Control.MOUSE_FILTER_STOP
		# meta 键必须 ASCII（中文键会被 set_meta 静默拒掉）
		行.set_meta("row_index", i)
		行.tooltip_text = _提示(记)
		容器.add_child(行)
		var 底 := NinePatchRect.new()
		底.name = "选中底"
		底.texture = load(行选中底皮) as Texture2D
		底.size = Vector2(行宽, 行高)
		底.patch_margin_left = float(选中底边["左"])
		底.patch_margin_top = float(选中底边["上"])
		底.patch_margin_right = float(选中底边["右"])
		底.patch_margin_bottom = float(选中底边["下"])
		底.mouse_filter = Control.MOUSE_FILTER_IGNORE
		底.visible = false
		行.add_child(底)
		行.mouse_entered.connect(_悬停.bind(页, 行, true))
		行.mouse_exited.connect(_悬停.bind(页, 行, false))
		# ⚠️ 形参顺序必须是 (事件, 页, 宿主, 序)：bind 的参数追加在信号参数之后
		行.gui_input.connect(_点行.bind(页, 宿主, i))
		for c in 列位.size():
			var 字 := Label.new()
			字.name = "列%d" % c
			字.position = Vector2(float(列位[c]["x"]) - 起, 2.0)
			字.size = Vector2(float(列位[c]["w"]), 19.0)
			字.text = _列值(c, 记)
			字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			字.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# `CommonItemRenderer.cretateLabel` 是裸 TextField + size 12
			字.add_theme_font_size_override("font_size", 12)
			字.add_theme_color_override("font_color", _列色(c, 记))
			行.add_child(字)


## 9 列取数。字段名对齐 `1552:6` 的 17 字段行（见 `后端连接._handle_guild_text` action 6）。
static func _列值(c: int, 记: Dictionary) -> String:
	match c:
		0: return String(记.get("name", "-"))
		1: return str(int(记.get("level", 0)))
		2: return 家族职务.职务名(int(记.get("rank", 9999)))
		3: return str(int(记.get("skillValue", 0)))
		4: return str(int(记.get("maiValue", 0)))
		5: return str(int(记.get("chengjiuValue", 0)))
		6: return str(int(记.get("shengwangValue", 0)))
		7: return str(int(记.get("bossValue", 0)))
		8: return str(int(记.get("contriValue", 0)))
	return "-"


static func _列色(c: int, 记: Dictionary) -> Color:
	match c:
		0:
			return 名列在线色 if int(记.get("channel_id", 0)) >= 0 else 名列离线色
		2:
			return 家族职务.职务色(int(记.get("rank", 9999)))
		7:
			return 本周boss红
	return 行白


## 行提示：在线 `"[<线>线]<名>"`（`FamillyMemberItemRender.as:80-84`）。
## 离线那一支原版显示 `logoutTime`（最后离线时间），服务端**没下发**任何登出时间
## ⇒ 不编（§0.0 第一原则），留空。
static func _提示(记: Dictionary) -> String:
	var 线 := int(记.get("channel_id", 0))
	if 线 < 0:
		return ""
	return "[%d线]%s" % [线, String(记.get("name", ""))]


static func _空提示(容器: Control) -> void:
	var 提示 := Label.new()
	提示.name = "空提示"
	提示.size = Vector2(容器.size.x, 行高)
	提示.text = "暂无成员"
	提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	提示.add_theme_color_override("font_color", 空提示色)
	容器.add_child(提示)


## `mouse_entered`/`mouse_exited` 信号没有参数，bind 加的三个就是全部实参 ⇒ (页, 行, 进)。
static func _悬停(页: Control, 行: Control, 进: bool) -> void:
	if not is_instance_valid(行) or not is_instance_valid(页):
		return
	var 序: int = int(行.get_meta("row_index", -1))
	页.set_meta("mg_hover", 序 if 进 else -1)
	_画选中底(行, 进 or 序 == int(页.get_meta("mg_selected", -1)))


static func _画选中底(行: Control, 亮: bool) -> void:
	var 底 := 行.get_node_or_null("选中底") as NinePatchRect
	if 底 != null:
		底.visible = 亮


## 点行：先选中（原版 `CommonItemRenderer.clickHandler` 的 `selected`），再按鼠标点弹菜单
## （`FamillyManager.showMenu(stagePoint,…)`，`FM.as:1276`）。
static func _点行(事件: InputEvent, 页: Control, 宿主: Node, 序: int) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	_选中(页, 序)
	var 行们: Array = 页.get_meta("mg_page_rows", []) as Array
	if 序 < 0 or 序 >= 行们.size():
		return
	var 菜 := 页.get_node_or_null("行菜单") as Control
	if 菜 != null:
		菜.call("弹出项", _菜单表(宿主, 行们[序] as Dictionary), 按.global_position,
			行们[序] as Dictionary)
	页.get_viewport().set_input_as_handled()


static func _选中(页: Control, 序: int) -> void:
	页.set_meta("mg_selected", 序)
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return
	var 悬停: int = int(页.get_meta("mg_hover", -1))
	for 子 in 容器.get_children():
		if not (子 is Control):
			continue
		var 行 := 子 as Control
		var 序i: int = int(行.get_meta("row_index", -1))
		if 序i < 0:
			continue
		_画选中底(行, 序i == 序 or 序i == 悬停)


## 页码 + 四钮禁用态 + 两个下拉的触发器文字（原版 `PageComponent` / `MComboBox`）。
static func _同步分页(页: Control, 总: int) -> void:
	var 页号: int = int(页.get_meta("mg_page", 1))
	var 页码 := 页.get_node_or_null("分页分页/页码") as Label
	if 页码 != null:
		页码.text = "%d/%d" % [页号, 总]
	for 对 in [["首页", 1], ["上一页", 页号 - 1], ["下一页", 页号 + 1], ["末页", 总]]:
		var 钮 := 页.get_node_or_null("分页分页/" + String(对[0])) as TextureButton
		if 钮 != null:
			钮.disabled = int(对[1]) == 页号 or int(对[1]) < 1 or int(对[1]) > 总
	var 每页字 := 页.get_node_or_null("下拉页/文字") as Label
	if 每页字 != null:
		每页字.text = String(每页文案[_每页序(页)])
	var 筛字 := 页.get_node_or_null("下拉成员/文字") as Label
	if 筛字 != null:
		筛字.text = String(筛选文案[clampi(int(页.get_meta("mg_filter", 0)), 0, 筛选文案.size() - 1)])


## 按钮/复选框启用态（原版 `update`，`FMEM.as:369-385`）：
##   解散 = 族长；退出 = 非族长；添加成员/开除出族 = 族长或副族长（rank 2）。
## `checkBox.visible = isManager`（`:405`）。
static func _同步钮态(页: Control, 宿主: Node) -> void:
	var 管 := 是族长(宿主)
	var 副 := 我的职务(宿主) == 2
	var 态 := {
		"钮添加成员": 管 or 副,
		"钮开除出族": 管 or 副,
		"钮解散家族": 管,
		"钮退出家族": not 管,
	}
	for 名 in 态:
		var 钮 := 页.get_node_or_null(String(名)) as TextureButton
		if 钮 != null:
			钮.disabled = not bool(态[名])
	# 禁用态是换皮换来的（`MButton3` 族），`disabled` 变化不会发信号 ⇒ 必须重画
	if 页.has_method("重画钮态"):
		页.call("重画钮态")


static func _同步勾选(页: Control, 宿主: Node) -> void:
	var 勾 := 页.get_node_or_null("复选自动同意") as Control
	if 勾 == null:
		return
	勾.visible = 是族长(宿主)
	var 框 := 勾.get_node_or_null("框") as TextureRect
	if 框 != null:
		框.texture = load(勾皮[1 if 自动同意(宿主) else 0]) as Texture2D


## 分页四钮（原版 `PageComponent` + `PageEvent.SET_PAGE`，`FMEM.as:330-334`）。
static func 翻页(页: Control, 宿主: Node, 目标: String) -> void:
	if 页 == null:
		return
	var 总 := _总页数(页, _筛选(页, _成员(宿主)))
	var 现: int = clampi(int(页.get_meta("mg_page", 1)), 1, 总)
	match 目标:
		"首页": 页.set_meta("mg_page", 1)
		"上一页": 页.set_meta("mg_page", maxi(1, 现 - 1))
		"下一页": 页.set_meta("mg_page", mini(总, 现 + 1))
		"末页": 页.set_meta("mg_page", 总)
		_: return
	刷新(页, 宿主)


## 每页条数（`FMEM.as:329-334`：`PageComponent.reset` 把 currentPage 打回 1）。
static func 选每页(页: Control, 宿主: Node, 序: int) -> void:
	if 页 == null:
		return
	页.set_meta("mg_per_idx", clampi(序, 0, 每页选项.size() - 1))
	页.set_meta("mg_page", 1)
	刷新(页, 宿主)


## 「显示」筛选（`memberSelectionChangeHandler`，`FMEM.as:108-113`：筛选后分页重置）。
static func 选筛选(页: Control, 宿主: Node, 序: int) -> void:
	if 页 == null:
		return
	页.set_meta("mg_filter", clampi(序, 0, 筛选键.size() - 1))
	页.set_meta("mg_page", 1)
	刷新(页, 宿主)


## 列头排序（原版 `clickSanJiaoLabelHandler`，`FMEM.as:415-417`：只重排、不换向）。
static func 排序列(页: Control, 宿主: Node, 列: String) -> void:
	if 页 == null or not 列名.has(列):
		return
	页.set_meta("mg_sort_col", 列)
	页.set_meta("mg_page", 1)
	刷新(页, 宿主)


## 两个下拉：`哪个` = "页" / "成员"（场景里两枚触发器的 `metadata/act`）。
static func 弹下拉(页: Control, 宿主: Node, 哪个: String) -> void:
	if 页 == null:
		return
	if 页.get_node_or_null(弹层名) != null:		# 开着 ⇒ 再点一次收起
		_关下拉(页)
		return
	var 锚名 := "下拉页" if 哪个 == "页" else "下拉成员"
	var 锚 := 页.get_node_or_null(锚名) as Control
	if 锚 == null:
		return
	var 选项: Array = 每页文案 if 哪个 == "页" else 筛选文案
	_关下拉(页)
	# 遮罩整页一层：点菜单外就收起（原版 MComboBox 失焦即收）
	var 罩 := Control.new()
	罩.name = 弹层名
	罩.set_anchors_preset(Control.PRESET_FULL_RECT)
	罩.mouse_filter = Control.MOUSE_FILTER_STOP
	页.add_child(罩)
	var 宽 := 下拉宽
	for 文 in 选项:
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
	var 现序 := _每页序(页) if 哪个 == "页" else int(页.get_meta("mg_filter", 0))
	var 顶 := 下拉边
	for i in 选项.size():
		var 项 := Button.new()
		项.name = "项%d" % i
		项.text = String(选项[i])
		项.flat = true
		项.focus_mode = Control.FOCUS_NONE
		项.add_theme_font_size_override("font_size", 12)
		项.add_theme_color_override("font_color", Color.WHITE if i == 现序 else Color("#FCF49C"))
		for 态 in ["normal", "hover", "pressed"]:
			项.add_theme_stylebox_override(态, 项皮)
		项.position = Vector2(下拉边, 顶)
		项.size = Vector2(宽 - 下拉边 * 2.0, 下拉项高)
		# 用 bind 显式带序号（不靠 lambda 捕循环变量）
		项.pressed.connect(_选下拉项.bind(页, 宿主, 哪个, i))
		菜单.add_child(项)
		顶 += 下拉项高 + 下拉边
	菜单.size = Vector2(宽, 顶)
	# 下方放不下就往上开（锚在 y=275，页高 332 ⇒ 4 项装不下）
	var 落 := 锚.position.y + 锚.size.y + 2.0
	if 落 + 顶 > 页.size.y:
		落 = 锚.position.y - 顶 - 2.0
	菜单.position = Vector2(minf(锚.position.x, 页.size.x - 宽), maxf(0.0, 落))
	罩.gui_input.connect(_点罩.bind(页))


## `pressed` 信号没有参数，bind 加了四个 ⇒ 形参就是这四个。
static func _选下拉项(页: Control, 宿主: Node, 哪个: String, 序: int) -> void:
	_关下拉(页)
	if 哪个 == "页":
		选每页(页, 宿主, 序)
	else:
		选筛选(页, 宿主, 序)


static func _点罩(事件: InputEvent, 页: Control) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_关下拉(页)


static func _关下拉(页: Control) -> void:
	if 页 == null:
		return
	var 罩 := 页.get_node_or_null(弹层名) as Control
	if 罩 != null and is_instance_valid(罩):
		页.remove_child(罩)
		罩.queue_free()


## 列头接线（原版 `createSanJiaoLable`，`FMEM.as:158-190`）：九格 Label 变成可点 +
## 右侧一颗排序三角；**最后一列不接**（`:186` 的 `param6 = false`）。
static func _接列头(页: Control, 宿主: Node) -> void:
	if 页.has_meta("mg_head_hooked"):
		return
	页.set_meta("mg_head_hooked", true)
	var 列位 := 家族列表填充._列位(页, "列成员", 列名.size())
	页.set_meta("mg_cols", 列位)
	for i in 列名.size():
		var 头 := 页.get_node_or_null("列成员%d" % i) as Label
		if 头 == null or i >= 可排序列数:
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
		三.visible = String(列名[i]) == String(页.get_meta("mg_sort_col", 默认排序列))
		头.add_child(三)
		# ⚠️ 形参顺序 (事件, 页, 宿主, 列)：bind 的参数追加在信号参数之后
		头.gui_input.connect(_点列头.bind(页, 宿主, String(列名[i])))


static func _点列头(事件: InputEvent, 页: Control, 宿主: Node, 列: String) -> void:
	var 按 := 事件 as InputEventMouseButton
	if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if String(页.get_meta("mg_sort_col", 默认排序列)) == 列:
		return
	排序列(页, 宿主, 列)
	页.get_viewport().set_input_as_handled()


static func _同步三角(页: Control) -> void:
	for i in 可排序列数:
		var 三 := 页.get_node_or_null("列成员%d/排序三角%d" % [i, i]) as TextureRect
		if 三 != null:
			三.visible = String(列名[i]) == String(页.get_meta("mg_sort_col", 默认排序列))


## 列表滚轮。`FMEM.as:208` 的 list 是滚动容器；本页列表区 235px ≈ 10.2 行 ⇒
## 每页 30/50/100 时必须能滚（原版没有可见滚动条，Flash List 的竖条是 AUTO）。
static func _接滚动(页: Control) -> void:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null or 容器.has_meta("mg_scroll_hooked"):
		return
	容器.set_meta("mg_scroll_hooked", true)
	容器.mouse_filter = Control.MOUSE_FILTER_STOP
	容器.gui_input.connect(_滚轮.bind(页))


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
	var 上限 := maxf(0.0, 行们.size() * 行高 - 容器.size.y)
	var 偏 := clampf(float(页.get_meta("mg_offset", 0.0)) + 像素, 0.0, 上限)
	页.set_meta("mg_offset", 偏)
	for i in 行们.size():
		(行们[i] as Control).position.y = i * 行高 - 偏


## 下拉宽度用的字宽估算（与 `家族列表窗._字宽`/`好友菜单` 同一套）。
static func _字宽(文: String) -> float:
	var 尺 := 0.0
	for i in 文.length():
		尺 += 12.0 if 文.unicode_at(i) > 0x2E80 else 6.0
	return 尺


static func _族(宿主: Node) -> Dictionary:
	var 会话 := _会话(宿主)
	if 会话 == null:
		return {}
	return 会话.guild as Dictionary


static func _后端(宿主: Node) -> Node:
	return 宿主.get_node_or_null("/root/BackendConnection") if 宿主 != null else null


static func _会话(宿主: Node) -> Node:
	return 宿主.get("_session") if 宿主 != null else null

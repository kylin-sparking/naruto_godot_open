extends RefCounted

## 格子的**悬停提示框接线**——背包 / 仓库 / 人物装备格**共用这一份**。
##
## 真值：原版 `MToolTipItem` 挂在格子的 MOUSE_OVER 上（立刻弹），并按 ItemData 子类分发
## （`MToolTipItem.as:73-109`：`EqpData` → `MToolTipZhuangBei`、其余 → `MToolTipDefault`）。
## 我们对应两套组件：`装备提示框` / `物品提示框`（页面里的固定节点，只填内容与摆位）。
##
## ⚠️ 2026-10-01 之前这段在 `背包窗口._接提示框` 与 `仓库窗口._接提示框` 里**各复制了一份**
##    （约 30 行、逻辑逐字相同）。人物装备格要接第三份时不再复制 —— 抽到这儿，三处同源。
##    两边保留各自的原名做一行转发，调用点没动。
##
## 与两份复制体的唯一语义差别：**两个节点都可以缺**——
##   · 人物页只有 `装备提示框`（装备格里永远是装备）；
##   · 缺的那个不再当"整条接线不成立"的理由（复制版要求 `物品提示框` 必须在，
##     那是背包/仓库两个都用得到的场景才成立的假设）。
##
## 2026-10-24 §3.259 新增第五个参数 `比穿戴件`：右侧再挂一列**身上正穿的那件**
## （标题带 `(已装备)`）。**这个开关不能写死在 helper 里** —— 原版按格子类分流，
## 背包有、仓库没有：
##   · `ItemWindowCell.as:314`（背包）、`ShopWindowCell.as:164`（NPC 商店）⇒ **有**；
##   · `StorageWindowCell.as:220`（仓库）、`TradeWindowCell.as:82`（交易）、
##     `KunChongCell.as:122`、`BiguanLingfuCell.as:160`、`KapianItemCell.as:107`、
##     `SimpleItemCell.as:220`（打造材料格）⇒ 三参调用，**没有**；
##   · `EquipmentWindowCell.as:226-232` / `EqpPetWindowCell.as:28-32` ⇒ 只在 `!_isMyself`
##     （看别人的装备格）时才有 —— 自己跟自己比没有意义。
## 全工程唯一取"对比件"的口径：`DataCenter.as:1684-1696 getEquipedItemById(configId)`
## = 按 id 求槽位 → **该槽位当前穿的那件**（不是同 id 的那件）。槽位空 ⇒ 原版 `param2` 为
## null ⇒ `createEqpTip:1564` 那一支整个不进 ⇒ 只有一列。

const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
## 对比列不在任何场景里烘着：原版是悬停时现建（`createEqpTip` 每次 new 一个 Sprite），
## 所以这里也**第一次真要用才复制一份**挂在页面上。
const 装备提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 对比列节点名 := "装备提示框对比"
## 提示框必须压在所有窗口之上：原版 `MToolTip.as:98-103` 把提示挂到 `PopUpMananger.stage`
## （整屏最上层），跟窗口的 z 序无关。页内弹窗用 `z_index = 100`（昆虫强化弹窗、
## `人物窗口._接昆虫弹窗:3078`）⇒ 提示框停在默认 0 时会被整个盖住（2026-10-31 用户报修②）。
## 只抬到 101：比那一档高一层就够，不跟创建角色窗(200)/确认遮罩(300)那类整屏层抢。
const 提顶层 := 101

## 2026-10-20：#6 装备打造页的格子是 `TextureRect`（`ItemCaiLiaoBox` 的 `itemCell` / `ItemDropBox`），
## 不是 Button ⇒ 参数放宽到 Control（用到的只有 `tooltip_text` 与两个 `mouse_*` 信号，Control 都有）。
static func 接线(窗口, 页面: Control, 格子: Control, 物品: Dictionary, 比穿戴件 := false) -> void:
	var 提示框 := 页面.get_node_or_null("物品提示框") as Control
	var 装备框 := 页面.get_node_or_null("装备提示框") as Control
	# 原生 tooltip 一律让位给原版那套提示框。
	格子.tooltip_text = ""
	for 连接 in 格子.mouse_entered.get_connections():
		格子.mouse_entered.disconnect(连接["callable"])
	for 连接 in 格子.mouse_exited.get_connections():
		格子.mouse_exited.disconnect(连接["callable"])
	if 物品.is_empty():
		# 空格子：悬停时把两套都收掉（复制版只收一套；两个节点都可能在页上）。
		格子.mouse_entered.connect(func() -> void:
			if 提示框 != null: 提示框.visible = false
			if 装备框 != null: 装备框.visible = false
			_收起对比列(页面))
		return
	var 是装备 := 装备部位表.位置(String(物品.get("id", ""))) != 0
	var 用 := 装备框 if (是装备 and 装备框 != null) else 提示框
	if 用 == null:
		return
	用.z_index = 提顶层		# 见 `提顶层`：页内弹窗(z=100)不能把详情框盖住
	格子.mouse_entered.connect(func() -> void:
		var 另 := (提示框 if 用 == 装备框 else 装备框) as Control
		if 另 != null:
			另.visible = false
		var 等级 := int(窗口._session.player_stats.get("level", 0))
		if 用 == 装备框:
			用.call("设置", String(物品.get("id", "")), 等级,
				int(窗口._session.player_stats.get("job", 0)), 物品)
		else:
			用.call("设置", String(物品.get("id", "")), int(物品.get("quantity", 1)), 等级, 物品)
		用.visible = true
		# ⚠️ 两个都得**显式标类型**：`get_parent()` / `窗口`（无类型形参）返回的是 Node/Variant，
		#    `:=` 推不出来会直接 Parse Error（"value doesn't have a set type"）。
		var 鼠标: Vector2 = 用.get_parent().get_local_mouse_position()
		var 舞台: Vector2 = 窗口._舞台尺寸()
		# 右列填不成（没开开关 / 槽位空 / 不是装备框）时**必须**回落到单列摆位，
		# 不能把旧的对比列留在屏上 —— `_填对比列` 内部负责收它。
		var 右列 := _填对比列(窗口, 页面, 用 == 装备框, 物品, 比穿戴件, 等级)
		if 右列 != null:
			用.call("贴成一对", 鼠标, 舞台, 右列)
		else:
			用.call("贴到鼠标", 鼠标, 舞台))
	格子.mouse_exited.connect(func() -> void:
		用.visible = false
		_收起对比列(页面))


## 算出并填好右侧那一列；**返回 null 表示这次只有一列**（同时把可能残留的旧列收掉）。
static func _填对比列(窗口, 页面: Control, 是装备框: bool, 物品: Dictionary,
		比穿戴件: bool, 等级: int) -> Control:
	var 穿戴: Dictionary = {}
	if 比穿戴件 and 是装备框:
		var 槽位 := 装备部位表.位置(String(物品.get("id", "")))
		if 槽位 != 0:
			var 身上: Variant = (窗口._session.equipped_items as Dictionary).get(槽位, {})
			if typeof(身上) == TYPE_DICTIONARY:
				穿戴 = 身上
	var 现有 := 页面.get_node_or_null(对比列节点名) as Control
	if 穿戴.is_empty():
		if 现有 != null:
			现有.visible = false
		return null
	var 框 := 现有
	if 框 == null:
		框 = 装备提示框场景.instantiate()
		框.name = 对比列节点名
		页面.add_child(框)
	框.call("设置", String(穿戴.get("id", "")), 等级,
		int(窗口._session.player_stats.get("job", 0)), 穿戴, -1, false, true)
	框.visible = true
	return 框


static func _收起对比列(页面: Control) -> void:
	var 框 := 页面.get_node_or_null(对比列节点名) as Control
	if 框 != null:
		框.visible = false

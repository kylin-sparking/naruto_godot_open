extends RefCounted

## 原版随身仓库窗口（`StorageWindow2`）的渲染与交互。
##
## 版式真值全部来自 `com/mxw/uifl/controls/StorageWindow2.as`。
## ⚠ **坐标系 2026-10-05 改了**：下面列的数都是 **AS3 窗口局部坐标**（0,0 = 外框左上角），
##   而场景里烘的是**页面局部 = 窗口 − 29** —— 因为尺寸表 NPC仓库 那条现在是 `整框: true`
##   且**删掉了 `原点: [0,0]`**。原先靠 `原点` 让容器铺满外框，结果 `功能窗口.gd:644` 的
##   `has("原点")` 优先于 `整框` ⇒ 10-04 抬过 −29 的整页又被顶回 (0,0)、比原版高 29px；
##   而 `分页` 下那 10 枚孙件当年漏抬、恰好等于 AS3，两道错抵消 ⇒ 门一直绿（没人看出来）。
##   对表时**先减 29 再看 .tscn**，别拿 AS3 的 46/281/339 直接比场景值。
##
## 关键 AS3 出处（详见 开发记录（本地） §3.10.7）
##   :110   super(275, 394)
##   :150   标题 = 「仓库」+ "(" + 已用 + "/" + totalCell + ")"
##   :138   内层底 MYellow_background @ (6,39) 263×349
##   :144   格区底 MPane_background @ (11,65) 253×212
##   :514   页签 x = 17+i*25+3、**y = 46**（背包是 45）、宽 25
##   :549   格位 x = 40*(i%6)+1*(i%6)+4、y = 40*(i/6)+1*(i/6)+4
##   :157   整理仓库 @ (16,281) 61×22
##   :164   批量存取 @ (203,281) 61×22
##   :170   存钱 @ (112,339) 37×22；:177 取钱 @ (216,339) 37×22
##   :190   分隔线 @ (11,307) 252×2
##   :264   物品菜单**只有两项** [移动, 销毁]
##
## ⚠️ 与背包窗口的差异（别照抄背包的）：页签 y 是 **46**（不是 45）；底部是
## 「整理仓库/批量存取/存钱/取钱」四键 + 金币区；**没有**三货币行、没有右列三键。

const 仓库场景 := preload("res://场景/界面/窗口/NPC仓库/NPC仓库窗口.tscn")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 数字格式 := preload("res://脚本/界面/数字格式.gd")
const 扩容需求 := preload("res://脚本/界面/扩容需求.gd")

const 每页格数 := 30
const 每页格数浮点 := 30.0
const 页签名 := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
const 色_金额 := Color("fff000")     ## 16773120
## 金币数值字号 = 背包 `货币字号`（14，同样是用户要求的有意偏离，原版 `getLabel` 默认 12）。
## 行标题「仓库中金币」仍 12，与背包「游戏金币」一致。
const 货币字号 := 14
## 标题「仓库」二字字号 = 背包 `标题字号`（14）—— 用户 2026-10-25：
## 「仓库、占位数/总，你照着背包 占位数/总改不就行了」。
const 标题字号 := 14
## 标题尾巴「(已用/总)」字号 = 背包 `格子数字号`（16）。
## ⚠️ 必须走 `设置标题` 的**尾文本**参数，不能用一整条标题文本：尾文本挂的是
## 裸 `FontFile`（单色点阵），整条标题走的是标题变体 `FontVariation` 合成加粗，
## ASCII 没有 EBLC 点阵 ⇒ 数字/括号被抹成一圈灰，就是用户说的「不清晰」（§3.281/§3.286）。
const 格子数字号 := 16
const 格数回退 := 96
## 仓库物品菜单原版**只有两项**（`StorageWindow2.as:264`），不是按物品类型的那 20 套（菜单由**左键单击**格子弹出）。
const 仓库菜单 := ["移动", "销毁"]
const 双击间隔毫秒 := 300
## `StorageWindow2.as:666-680` 的连点保护
const 整理冷却毫秒 := 1000

## 同 `背包窗口.gd`：页码存窗口上（`功能窗口._仓库页`），重建时不复位。
static func _取页(窗口) -> int:
	return int(窗口._仓库页)

static func _设页(窗口, 值: int) -> void:
	窗口._仓库页 = 值
static var _上次点击物品 := ""
static var _上次点击时刻 := 0
static var _上次整理时刻 := 0
## 菜单动作（销毁）要知道"刚才点的是哪一格"——单击弹菜单时记下来。
static var _当前物品 := {}
static var _当前槽位 := 0


static func 渲染(窗口) -> void:
	var 会话 = 窗口._session
	var 页面 := 窗口._instantiate_page(仓库场景) as Control
	var 总格数 := _仓库总格数(会话)
	# 「已用」数**占格数**不是数组长度 —— 同 `背包窗口.gd:66-68` 那条（稳定格位制下
	# `storage` 里全是 {} 洞，`size()` 会把洞算进件数，标题凭空虚高）。
	窗口.设置标题("仓库", 标题字号,
			"(%d/%d)" % [会话._占用数(会话.storage), 总格数], 格子数字号)

	_渲染页签(窗口, 页面, 总格数)
	_渲染格子(窗口, 页面, 会话)
	_渲染金币(窗口, 页面, 会话)
	_渲染按钮(窗口, 页面, 会话)
	var 菜单 := 页面.get_node_or_null("物品菜单")
	if 菜单 != null:
		菜单.connect("选择了", func(项名: String): _执行菜单项(窗口, 页面, 项名))
	var 扩容 := 页面.get_node_or_null("扩容窗口")
	if 扩容 != null:
		扩容.connect("确认扩充", func(_归属: String):
			var 后端 = 窗口._backend
			if 后端 == null or not 后端.has_method("request_cash_storage_capacity"):
				窗口._show_hint("扩充：未连接服务端")
			elif not 后端.request_cash_storage_capacity():   # CS_REQ_STORAGE_EXTEND = 1085
				窗口._show_hint("扩充请求发送失败")
			# 发成功不提示：格数等回帧重绘（同背包那条）。
		)
		扩容.connect("请求购买", func(密卷id: String) -> void: 窗口.请求商城商品(密卷id))
	var 销毁 := 页面.get_node_or_null("销毁窗口")
	if 销毁 != null:
		# 仓库这条销毁走 `STORAGE(59) action 6`（`DestroyWindow.as:65-68`）——
		# 与背包那条（`ITEM_MOVE`）不是同一个 opCode，别混。
		销毁.connect("确认销毁", func(_归属: String, 槽位: int, _物品id: String, _件数: int):
			var 后端 = 窗口._backend
			if 后端 == null or not 后端.has_method("request_storage_remove_item"):
				窗口._show_hint("销毁：未连接服务端")
			elif not 后端.request_storage_remove_item(槽位):
				窗口._show_hint("销毁请求发送失败")
			# 发成功不提示：原版 `DestroyWindow.as:65-68`  dispatch 完直接 `onCloseBtnClick`，
			# 一句 addNotice 都没有，格子等回帧清空。
		)


## `DataCenter.storageSlots`（服务端 `storageSlotLimit` 下发）。取不到按回退值。
static func _仓库总格数(会话) -> int:
	var 值 := int(会话.get("storage_capacity") if 会话.get("storage_capacity") != null else 0)
	return 值 if 值 > 0 else 格数回退


static func _渲染页签(窗口, 页面: Control, 总格数: int) -> void:
	var 页数 := int(ceilf(总格数 / 每页格数浮点))
	页数 = clampi(页数, 1, 页签名.size())
	for 序号 in 页签名.size():
		var 分页 := 页面.get_node("分页/第%d页" % (序号 + 1)) as Button
		窗口._apply_tab_skin(分页)
		分页.text = 页签名[序号]
		分页.visible = 序号 < 页数
		# ⚠️ 高亮跟**当前页**，不写死 0：这一页每次回帧重建都跑这里，写死 0 会把玩家
		#    翻到的第 3 页高亮顶回「一」，而下面 `_渲染格子` 读的仍是 `_取页(窗口)` ⇒
		#    格子里是第三页的货、页签亮着第一页（同 `背包窗口._刷新页签选中`，
		#    也同 2026-10-01「装备拖到人物面板后背包自动返回第一页」那条病根）。
		分页.disabled = 序号 == _取页(窗口)
		分页.pressed.connect(_切页.bind(窗口, 页面, 序号))
	var 扩充 := 页面.get_node("分页/扩充") as Button
	窗口._apply_tab_skin(扩充)
	扩充.position.x = 20.0 + 25.0 * 页数
	扩充.visible = 页数 < 9
	扩充.pressed.connect(_开扩容窗.bind(窗口, 页面, 总格数, 页数))


## 打开「格数扩展」窗（原版 `EnlargeWindow`，仓库那条 `_isItemWindow = 1` → 发 1085）。
## 需求表与背包同源（`Etc.CangKuKuoZhan`，取值相同）。
static func _开扩容窗(窗口, 页面: Control, 总格数: int, 页数: int) -> void:
	var 窗 := 页面.get_node_or_null("扩容窗口") as Control
	if 窗 == null:
		return
	var 需求 := 扩容需求.取需求("仓库", 页数)
	窗.call("打开", "仓库", 页数, 需求["需要数量"], 需求["密卷id"],
		扩容需求.拥有数(窗口._session, 需求["密卷id"]))
	# 物品格 = 原版 `ItemWindowCell`（`EnlargeWindow.as:239`，悬停 `:309-314` 挂 MToolTipItem）
	窗口._接打造提示(页面, 窗.get_node_or_null("物品格") as Control,
			int(需求["密卷id"]), 扩容需求.拥有数(窗口._session, 需求["密卷id"]))


static func _切页(窗口, 页面: Control, 序号: int) -> void:
	if 序号 == _取页(窗口):
		return
	_设页(窗口, 序号)
	for i in 页签名.size():
		var 分页 := 页面.get_node("分页/第%d页" % (i + 1)) as Button
		if 分页.visible:
			分页.disabled = i == _取页(窗口)
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 != null:
		菜单.call("收起")
	_渲染格子(窗口, 页面, 窗口._session)


static func _渲染格子(窗口, 页面: Control, 会话) -> void:
	var 仓库: Array = 会话.storage
	var 起点 := _取页(窗口) * 每页格数
	var 容器 := 页面.get_node("格子容器") as Control
	for 序号 in 每页格数:
		var 格子 := 容器.get_node("物品格_%d" % 序号) as Button
		var 数量 := 格子.get_node("数量") as Label
		格子.icon = null
		格子.disabled = true
		格子.theme_type_variation = 皮肤表.变体_物品格按钮
		格子.focus_mode = Control.FOCUS_NONE
		数量.text = ""
		# 字号 14 = **与背包一致**（用户 2026-10-25：「堆叠数量，包括下方金币格式当然也要跟背包一致」）。
		# 仓库格和背包格共用同一个 `物品格.tscn` / `ItemWindowCell`；背包 §3.283 已是 14，
		# 仓库这里同步 14（位置、右对齐、白字、描边本来就同源）。
		# ⚠️ 别改 `物品格.tscn` 的默认 12：礼包详情/福袋/自选礼包等页共用，用户没要求动那些。
		窗口._configure_label(数量, 14, Color.WHITE)
		格子.物品id = ""
		# 同背包：仓库格用的也是 `ItemWindowCell`，装备照样带资质框/流光。
		格子.call("清空品质覆盖层")
		_接拖拽(窗口, 格子, 起点 + 序号 + 1)
		_接提示框(窗口, 页面, 格子, {})
		var 下标 := 起点 + 序号
		if 下标 >= 仓库.size():
			continue
		var 物品: Dictionary = 仓库[下标]
		格子.物品id = String(物品.get("id", ""))
		格子.disabled = false
		var 图标路径 := String(物品.get("icon", ""))
		if ResourceLoader.exists(图标路径):
			格子.icon = load(图标路径) as Texture2D
		格子.call("设置品质", 物品, true)
		var 件数 := int(物品.get("quantity", 1))
		数量.text = str(件数) if 件数 > 1 else ""
		格子.pressed.connect(_点格子.bind(窗口, 页面, 格子, 物品))
		_接提示框(窗口, 页面, 格子, 物品)


## 单击弹菜单（原版 `StorageWindow2.as:264` 只有 [移动, 销毁]）；
## **双击 = 取出**（原版 `onItemDoubleClick` 的 `isSaveOrTakeItem/canDoubleClickSave`
## 分支 → `StorageWindowEvent.ITEM_SAVE`）。没有拖拽之前，这是原版自己就有的快速存取路径。
static func _点格子(窗口, 页面: Control, 格子: Button, 物品: Dictionary) -> void:
	var 本刻 := Time.get_ticks_msec()
	var 同一件 := String(物品.get("id", "")) == _上次点击物品 and 本刻 - _上次点击时刻 <= 双击间隔毫秒
	_上次点击物品 = String(物品.get("id", ""))
	_上次点击时刻 = 本刻
	if 同一件:
		_上次点击时刻 = 0
		var 收 := 页面.get_node_or_null("物品菜单") as Control
		if 收 != null:
			收.call("收起")
		窗口._withdraw_item(int(格子.槽位号), 1)
		return
	if 窗口.批量存取模式:
		# 批量存取开着时单击 = 直接取出（原版 `isSaveOrTakeItem` 走的就是这条）
		窗口._withdraw_item(int(格子.槽位号), -1)
		return
	_当前物品 = 物品
	_当前槽位 = 格子.槽位号
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 == null:
		return
	菜单.call("弹出", 仓库菜单,
		Vector2(格子.position.x + 31.0, 格子.position.y + 85.0),
		窗口._舞台尺寸())


static func _执行菜单项(窗口, 页面: Control, 项名: String) -> void:
	match 项名:
		"移动":
			窗口._show_hint("移动：直接拖拽格子即可（同容器内换位；跨容器即存取）")
		"销毁":
			var 销毁窗 := 页面.get_node_or_null("销毁窗口") as Control
			if 销毁窗 != null and not _当前物品.is_empty():
				var 图标: Texture2D = null
				var 路径 := String(_当前物品.get("icon", ""))
				if ResourceLoader.exists(路径):
					图标 = load(路径) as Texture2D
				销毁窗.call("打开", String(_当前物品.get("id", "")),
					String(_当前物品.get("name", "")), 图标,
					int(_当前物品.get("quantity", 1)), "仓库", _当前槽位)
		_:
			# 走到这里 = 仓库菜单冒出一项**分派表没写**的（不是"故意不做"，是漏）。
			窗口._show_hint("%s：还没接 —— 仓库菜单这一项没有分派" % 项名)
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 != null:
		菜单.call("收起")


## 拖拽：所有格子都开（空格子要能当落点），归属 "仓库"、槽位号 1 基。
## 落下分三种：仓库内移动 / 取回背包 / 存入仓库 —— 与背包那边同一套判断。
static func _接拖拽(窗口, 格子: Button, 槽位号: int) -> void:
	格子.格子归属 = "仓库"
	格子.槽位号 = 槽位号
	格子.可拖拽 = true
	for 连接 in 格子.拖放.get_connections():
		格子.拖放.disconnect(连接["callable"])
	格子.拖放.connect(_处理拖放.bind(窗口))


static func _处理拖放(来源格: Button, 目标格: Button, 物品id: String, 窗口) -> void:
	var 源归属: String = 来源格.格子归属
	var 目标归属: String = 目标格.格子归属
	if 源归属 == 目标归属:
		if 源归属 != "仓库":
			return
		var 后端 = 窗口._backend
		if 后端 != null and 后端.has_method("request_item_move"):
			后端.request_item_move(0, 来源格.槽位号, 目标格.槽位号, 0)
		return
	if 源归属 == "仓库" and 目标归属 == "背包":
		窗口._withdraw_item(int(来源格.槽位号), -1)
	elif 源归属 == "背包" and 目标归属 == "仓库":
		窗口._deposit_item(int(来源格.槽位号), -1)


static func _接提示框(窗口, 页面: Control, 格子: Button, 物品: Dictionary) -> void:
	var 提示框 := 页面.get_node_or_null("物品提示框") as Control
	if 提示框 == null:
		return
	格子.tooltip_text = ""
	for 连接 in 格子.mouse_entered.get_connections():
		格子.mouse_entered.disconnect(连接["callable"])
	for 连接 in 格子.mouse_exited.get_connections():
		格子.mouse_exited.disconnect(连接["callable"])
	if 物品.is_empty():
		格子.mouse_entered.connect(func(): 提示框.visible = false)
		return
	# 装备与普通物品**走两套 tooltip**（原版 `MToolTipItem.setValue:73-109` 按子类分发）。
	var 装备框 := 页面.get_node_or_null("装备提示框") as Control
	var 用 := 装备框 if (装备部位表.位置(String(物品.get("id", ""))) != 0 and 装备框 != null) else 提示框
	格子.mouse_entered.connect(func():
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
		用.call("贴到鼠标", 用.get_parent().get_local_mouse_position(), 窗口._舞台尺寸())
	)
	格子.mouse_exited.connect(func(): 用.visible = false)


## 金币区：`moneyTf` 是 `BaseUtil.formatNumber` 的千分位（`:543-547`）。
## 容量 `cellCountTf` 原版创建时 `visible = false`（`:199-202`），格数走标题，所以这里不显示。
static func _渲染金币(窗口, 页面: Control, 会话) -> void:
	窗口._configure_label(页面.get_node("仓库中金币") as Label, 12, 色_金额)
	窗口._configure_label(页面.get_node("批量存取提示") as Label, 12, 色_金额)
	var 金额 := 页面.get_node("仓库金币数") as Label
	金额.text = 数字格式.千分位(int(会话.storage_gold))
	# 用户 2026-10-25：「下方金币格式也要跟背包一致」⇒ 数值 14 号、金色，千分位沿用
	# `BaseUtil.formatNumber`（本来就有）。标题仍 12，与背包行标题一致。
	窗口._configure_label(金额, 货币字号, 色_金额)
	(页面.get_node("容量") as Label).visible = false


static func _渲染按钮(窗口, 页面: Control, 会话) -> void:
	var 整理 := 页面.get_node("整理仓库") as Button
	窗口._configure_standard_button(整理)
	整理.pressed.connect(func():
		# `StorageWindow2.as:666-680`：1000ms 连点保护，过快点提示 CLICK_TOO_FAST。
		var 本刻 := Time.get_ticks_msec()
		if 本刻 - _上次整理时刻 < 整理冷却毫秒:
			窗口._show_hint("你点击的太快啦！")
			return
		_上次整理时刻 = 本刻
		var 后端 = 窗口._backend
		if 后端 == null or not 后端.has_method("request_item_sort"):
			窗口._show_hint("整理仓库：未连接服务端")
		elif not 后端.request_item_sort(1):   # type 1 = 仓库
			窗口._show_hint("整理仓库请求发送失败")
		# 发成功不提示（原版 `onClickClearBtn` 只在连点过快时 addNotice）。
	)
	var 批量 := 页面.get_node("批量存取") as Button
	窗口._configure_standard_button(批量)
	批量.toggle_mode = true
	批量.button_pressed = bool(窗口.批量存取模式)
	批量.pressed.connect(func():
		窗口.批量存取模式 = 批量.button_pressed
		# 原版切光标模式 `CursorManager.showCursorUI("StorageTakeCursorF")`（`:746-763`）。
		# 客户端没有光标换装，改成"单击即存取"并在状态栏说明 —— 语义与原版一致。
		窗口._show_hint("批量存取已开启：单击物品即可存取" if 窗口.批量存取模式 else "批量存取已关闭")
	)
	# 存钱/取钱：原版弹 `SaveAndTakeMoneyWindow`（`StorageWindow2.as:472-483`）。
	# 上限按原版取：**存钱 = 身上金币、取钱 = 仓库金币**。
	var 金额窗 := 页面.get_node_or_null("存取金额窗口") as Control
	if 金额窗 != null:
		金额窗.connect("确认存取", func(是存入: bool, 金额: int):
			if 是存入:
				会话.deposit_storage_gold(金额)
			else:
				会话.withdraw_storage_gold(金额)
		)
	var 存钱 := 页面.get_node("存钱") as Button
	窗口._configure_standard_button(存钱)
	存钱.custom_minimum_size = Vector2(37.0, 22.0)
	存钱.pressed.connect(func():
		if 金额窗 != null:
			金额窗.call("打开", true, int(会话.player_stats.get("gold", 0)))
	)
	var 取钱 := 页面.get_node("取钱") as Button
	窗口._configure_standard_button(取钱)
	取钱.custom_minimum_size = Vector2(37.0, 22.0)
	取钱.pressed.connect(func():
		if 金额窗 != null:
			金额窗.call("打开", false, int(会话.storage_gold))
	)

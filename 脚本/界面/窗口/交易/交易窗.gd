extends RefCounted
## 交易窗（原版 `TradeWindow2`）控制器。逐件真值 = `真值/窗口/交易与邀请托盘.md`。
##
## 这扇窗**不是点开的，是服务端推帧推出来的**：双方任一接受邀请 ⇒ 服务端给两边各发
## 一条 `335:22`（`fake_flash_server.py:23826-23835`）⇒ `后端连接.trade_started`
## ⇒ `窗口管理._on_trade_started` 开这一页。所以本页没有"请求开窗"的上行，
## 只有交互产生的 14/15/13/9/16/10 六条。
##
## 三条最容易自造的：
## 1. **槽位号语义**：下行 `335:4/5/6/10/21` 的第 2 段 `0 = 我这侧 / 1 = 对方`
##    （`Client.as:1683-1697` 等四条都是 `param1 == 0 ⇒ my…`）。别按"谁发的"反推。
## 2. 交易钮只在**两块红遮罩都显**时才 enable（`setTradeBtnEnabled:131-137`）；
##    我自己点锁定只点亮我这半（`:445`），对方那半要等 `335:7`。
## 3. `取消` 与 `关闭钮` 是同一条上行（`119:10`），而服务端会向**双方**发 `335:9:0`
##    ⇒ 关窗由下行驱动，不在点击处直接 close（否则对面那扇关不掉）。

const 数字格式 := preload("res://脚本/界面/数字格式.gd")
## 交易档选宠窗（`SuiShenPet`）。只取 `设上架可用`；不反向 preload 本脚本，无环。
const 附身宠物窗 := preload("res://脚本/界面/窗口/附身宠物窗.gd")

## 「物品上架」模式（原版 `UIConfig.isShangjiaItem`，`TradeWindow2.as:334-350`）。
## 原版靠它把「点背包里的一件」变成「放进交易」，判定在 `ItemWindow2.as:458-465`；
## 本工程那个判定点在 `背包窗口._选中格子`，两边都读这一个静态位（原版也是全局一份）。
static var 上架模式 := false

## 每格的东西挂在宿主的具名变量上（**不用 set_meta**：中文键在 Godot 4 里静默存不进去）。
const 侧名表 := ["my", "other"]


## 我这侧第一个空格（1..5），满 5 格返回 0。
## 原版「上架模式点背包」发的是 `dst=0`（`ItemWindow2.as:462`），本机服务端只认 1..5
## （`:23873`）⇒ 由客户端算出真实槽号再发，差异已登记在真值 §⑩ 那条 ⚠ 下。
static func 我空格(宿主: Node) -> int:
	var 后 = 宿主._backend
	if 后 == null:
		return 0
	return int(后.call("交易空格"))


## 建页 + 接线。`态` = `后端连接.authoritative_trade`。
static func 渲染(宿主: Node, 场景: PackedScene, 态: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	宿主._交易页 = 页
	上架模式 = false
	_接格子(宿主, 页)
	for 连 in [
		["物品上架钮", _点上架.bind(宿主)],
		["输入金币钮", _点输金币.bind(宿主)],
		["输入元宝钮", _点输元宝.bind(宿主)],
		["宠物列表钮", _点宠物列表.bind(宿主)],
		["锁定物品钮", _点锁定.bind(宿主)],
		["交易钮", _点交易.bind(宿主)],
		["取消钮", _点取消.bind(宿主)],
	]:
		var 钮 := 页.get_node(连[0]) as Button
		钮.pressed.connect(连[1])
	# 「我的物品」那四个字是静态文案（`TRADEWINDOW_MYNAME`），场景里已烘；
	# 「对方名」是运行期数据（`setOtherData:359`）。
	(页.get_node("对方名") as Label).text = String(态.get("other_name", ""))
	_交易金额窗(宿主).确认存取.connect(func(是金币: bool, 金额: int) -> void:
		_出金额(宿主, 是金币, 金额))
	_灌(宿主, 页, 态)
	return 页


## 同一扇窗被后续帧重新灌（快照每变一次重放一整轮，`_broadcast_trade_snapshot`）。
static func 重灌(宿主: Node, 场景: PackedScene, 态: Dictionary) -> void:
	var 页 = 宿主._交易页
	## ⚠ 必须判**还挂在 _content 下**：`queue_free()` 之后 `is_instance_valid` 仍为真到帧末。
	if 页 == null or not is_instance_valid(页) or (页 as Control).get_parent() != 宿主._content:
		渲染(宿主, 场景, 态)
		return
	(页.get_node("对方名") as Label).text = String(态.get("other_name", ""))
	_灌(宿主, 页, 态)


## 把状态画到页上。逐条对应原版的 setter：
## 物品 = `setMyItemData/setOtherItemData`（按 position 定格）+ `clearSlot*`；
## 金额 = `setCoin/setYuanbao`（`:210-221`、`:321-332`，都过 `formatNumber`）；
## 遮罩 = `onLockedBtn`/`lockTrade`；交易钮 = `setTradeBtnEnabled`。
static func _灌(宿主: Node, 页: Control, 态: Dictionary) -> void:
	for 侧 in range(2):
		var 表名 := "%s_items" % 侧名表[侧]
		var 格名 := "我的格" if 侧 == 0 else "对方格"
		var 格表: Dictionary = 态.get(表名, {})
		for 槽 in range(1, 6):
			var 件 := 页.get_node("%s%d" % [格名, 槽]) as Control
			件.填(格表.get(槽, {}))
		var 宠 := 态.get("%s_pet" % 侧名表[侧], {}) as Dictionary
		(页.get_node("我的宠物格" if 侧 == 0 else "对方宠物格") as Control).call("填", 宠)
	(页.get_node("我的金币值") as Label).text = 数字格式.千分位(int(态.get("my_money", 0)))
	(页.get_node("对方金币值") as Label).text = 数字格式.千分位(int(态.get("other_money", 0)))
	(页.get_node("我的元宝值") as Label).text = 数字格式.千分位(int(态.get("my_cash", 0)))
	(页.get_node("对方元宝值") as Label).text = 数字格式.千分位(int(态.get("other_cash", 0)))
	(页.get_node("我的遮罩") as Control).visible = bool(态.get("my_locked", false))
	(页.get_node("对方遮罩") as Control).visible = bool(态.get("other_locked", false))
	_设钮态(宿主, 页)
	_同步选宠钮(宿主)


## 钮的三种态：初始 disable（上架/锁定）→ 收到 `335:22` 后 enable（`setOtherData:354`）
## → 我锁定后 disable（`onLockedBtn:446`）。交易钮两块遮罩都亮才 enable（`:131-137`）。
static func _设钮态(宿主: Node, 页: Control) -> void:
	var 我锁 := bool((宿主._交易态() as Dictionary).get("my_locked", false))
	var 他锁 := bool((宿主._交易态() as Dictionary).get("other_locked", false))
	(页.get_node("锁定物品钮") as Button).disabled = 我锁
	(页.get_node("物品上架钮") as Button).disabled = 我锁
	(页.get_node("物品上架钮") as Button).button_pressed = 上架模式 and not 我锁
	## ⚠ 「输入金币/输入元宝」两颗**不跟着 disable** —— 原版 `onLockedBtn:446` 只关
	## `lockedBtn` 与 `shangjiaBtn`。锁完再去开金额窗，服务端那侧 `:23851,23861` 会直接 return
	## （`if character_id in trade.locked`）⇒ 界面上照旧可点、帧照发，但改不动出价。
	(页.get_node("交易钮") as Button).disabled = not (我锁 and 他锁)


static func _交易金额窗(宿主: Node) -> Control:
	return (宿主._交易页 as Control).get_node("交易金额窗") as Control


## 只有我这侧的 5 格是落点（`setMouseEvent:566-571` 只给 `myCellArr` 挂了 `MSPRITE_UP`）。
static func _接格子(宿主: Node, 页: Control) -> void:
	for 槽 in range(1, 6):
		var 件 := 页.get_node("我的格%d" % 槽) as Control
		var 格: Button = 件.格
		件.交易槽 = 槽
		格.格子归属 = "交易"
		格.槽位号 = 槽
		## ⚠ 只接不吐：原版交易格**从来不建拖拽代理**（`MCell` 里没有 `createDragDataProxy`），
		## 把东西从交易格拖回背包那条路是死的（见真值 §⑫「取回物品」）。
		格.可拖拽 = false
		for 连 in 件.落到.get_connections():
			件.落到.disconnect(连["callable"])
		件.落到.connect(func(_槽: int, 载荷: Dictionary) -> void: _放物(宿主, 槽, 载荷))
	for 槽 in range(1, 6):
		var 件 := 页.get_node("对方格%d" % 槽) as Control
		件.交易槽 = 槽
		(件.格 as Button).格子归属 = ""		# 空归属 = `_can_drop_data` 直接挡掉


## 放下 = `119:14:<背包槽>:<交易槽>`。三道闸照原版：
## ① 来源必须是背包（`onItemUp:399` 判 `dragSource == ITEM_WINDOW`）；
## ② 落点格必须**空着**（`!param1.target.getCellValue()`，`:399`）—— 原版不许叠格；
## ③ 物品必须可交易（`:403-409`，不可交易只出提示、不发帧）。
static func _放物(宿主: Node, 交易槽: int, 载荷: Dictionary) -> void:
	var 来源 = 载荷.get("来源格")
	if 来源 == null or not is_instance_valid(来源):
		return
	if String((来源 as Button).格子归属) != "背包":
		return
	var 页 := 宿主._交易页 as Control
	var 目标 := 页.get_node("我的格%d" % 交易槽) as Control
	if not 目标.是空的():
		return
	var 后 = 宿主._backend
	if 后 == null:
		宿主._show_hint("交易需要连接服务端")
		return
	var 背包槽 := int((来源 as Button).槽位号)
	var 件 := _源物品(后, 背包槽)
	if not bool(件.get("can_trade", true)):
		宿主._show_hint("该物品不能交易")		# CN.IS_NOT_ITEM_TRADE
		return
	后.call("request_trade_put_item", 背包槽, 交易槽)


## 按背包槽在镜像里找回那件（拖放载荷只带 id，同 id 可能有好几件 ⇒ 必须按槽取）。
static func _源物品(后: Node, 背包槽: int) -> Dictionary:
	for 件 in (后.get("authoritative_inventory") as Array):
		if int((件 as Dictionary).get("slot_index", -1)) == 背包槽:
			return 件 as Dictionary
	return {}


## 「物品上架」= 开关一个模式（原版 `onShangjia:334-350` 换光标 + `isShangjiaItem`）。
## 本工程没有光标换装 ⇒ 用钮的 toggle 态 + 状态行话说表达（与仓库存取的「批量存取」同一口径）。
static func _点上架(宿主: Node) -> void:
	上架模式 = not 上架模式
	_设钮态(宿主, 宿主._交易页 as Control)
	宿主._show_hint("点背包里的物品即可放入交易" if 上架模式 else "已退出上架模式")


## 输入金币 / 输入元宝 ⇒ 金额子窗（复用仓库存取那只，`交易档 = true` 换文案与币图）。
## 上限 = **身上余额**（`:311` cocoNuts / `:429` cashMoney）。
static func _点输金币(宿主: Node) -> void:
	_交易金额窗(宿主).call("打开", true, _余额(宿主, "money"), true)


static func _点输元宝(宿主: Node) -> void:
	_交易金额窗(宿主).call("打开", false, _余额(宿主, "cash"), true)


static func _余额(宿主: Node, 键: String) -> int:
	var 后 = 宿主._backend
	if 后 == null:
		return 0
	var 状: Dictionary = 后.get("authoritative_stats") as Dictionary
	return int(状.get(键, 0))


## 金额子窗回来的数 ⇒ `119:15:<金币>` / `119:13:<元宝>`。
## 原版是 `COIN_NUMBER` / `YUANBAO_NUMBER` 两档（`SaveCoinOrBeanWindow.onClickOkBtn`），
## `>= 0` 才发；上限已经在子窗里钳过（组件的 `_限制输入`）。
static func _出金额(宿主: Node, 是金币: bool, 金额: int) -> void:
	var 后 = 宿主._backend
	if 后 == null:
		宿主._show_hint("交易需要连接服务端")
		return
	后.call("request_trade_offer_cash" if not 是金币 else "request_trade_offer_money", 金额)


## 锁定我这堆（`onLockedBtn:443-455`）：先点亮自己那半遮罩、disable 两颗钮、退上架模式，
## 再发 `119:9`。对面那半要等服务端 `335:7`。
static func _点锁定(宿主: Node) -> void:
	var 页 := 宿主._交易页 as Control
	(页.get_node("我的遮罩") as Control).visible = true
	上架模式 = false
	_设钮态(宿主, 页)
	(页.get_node("锁定物品钮") as Button).disabled = true
	(页.get_node("物品上架钮") as Button).disabled = true
	var 后 = 宿主._backend
	if 后 != null:
		后.call("request_trade_lock")
		宿主._show_hint("已锁定，等待对方确认")


## 「交易」= 确认成交（`onTradeBtn:294-300`）：发 `119:16` + 立刻 disable 自己 +
## 出那句「物品已进入交易状态，请等待对方确认」。真正的成功/失败由 `335:8/9` 说。
static func _点交易(宿主: Node) -> void:
	var 后 = 宿主._backend
	if 后 == null:
		return
	(宿主._交易页.get_node("交易钮") as Button).disabled = true
	后.call("request_trade_confirm")
	宿主._show_hint("物品已进入交易状态，请等待对方确认")


## 「取消」与关闭钮是同一条（`:316-319` → `:123-129`）：发 `119:10`，
## **不在这儿关窗** —— 服务端给双方发 `335:9:0`，由 `_on_trade_closed` 统一关。
static func _点取消(宿主: Node) -> void:
	var 后 = 宿主._backend
	上架模式 = false
	if 后 != null:
		后.call("request_trade_exit")


## 「宠物列表」（`:589-592` → `setSuiShenPetWindow()`）：开/收交易档 `SuiShenPet`
## （`UIMain2.as:4745-4758`：`reverseDisplay` 开关 + 贴交易窗左侧 + 每次 `setData()`）。
## 原版位置恒为 `tradeWindow.x - width`（`:4754`），本工程由 `窗口管理.摆到旁边` 兜底夹进视口。
static func _点宠物列表(宿主: Node) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		return
	var 窗: Node = 管理.call("取或建窗口", "附身宠物")
	if bool(窗.call("已打开")):
		窗.call("close")
		return
	窗.set("_附身用途", "交易")
	窗.set("_附身选中", 0)
	管理.call("打开", "附身宠物")
	管理.call("摆到旁边", "附身宠物", "交易")
	_同步选宠钮(宿主)


## 锁定后选宠窗的「上架」跟着灰（`TradeWindow2.as:449 setShangjiaBtnEnbled(false)`），
## 每次快照重画时按同一份 `my_locked` 对齐（`:357` 开新交易时再放开）。
static func _同步选宠钮(宿主: Node) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 窗 = 管理.call("取窗口", "附身宠物")
	if 窗 == null or not bool(窗.call("已打开")):
		return
	if str(窗.get("_附身用途")) != "交易":
		return
	附身宠物窗.设上架可用(窗, not bool((宿主._交易态() as Dictionary).get("my_locked", false)))

extends SceneTree

## 商城购买窗回归门（2026-10-11）：**1079（商品详情）回包 ⇒ 弹购买窗** 这条链。
##
## 病根：`功能窗口.请求商城商品`（「扩容窗 / 仓库窗」那枚「购买」走的）把 1086 发出去了、
## 服务端回了 1079、`后端连接` 也 `cash_item_info_received.emit()` 了 ——
## **全工程一次都没人听** ⇒ 玩家点「购买」只看到一句"商城详情窗还没接这条路"。
##
## 原版真值（三处互证）：`CashShopProcessor.handleCashItemInfo:159-176` →
## `Client.onCashItemInfo:7787-7791` → `UIMain2.addBuyWindow:2906-2913`：
## `requestCashMoney()` 之后**新建一枚独立的 `BUY_EQP_WINDOW`**（`this.createWindow(UIConfig.BUY_EQP_WINDOW_F)`）、
## `centerWindow` 居中、`setData(item)` —— **不开商城页**。
## 发这个事件的有 `EnlargeWindow.onClickBuy:169-174` / `FubenLingWindow.as:209` /
## `ChangeNameWindow.as:305` / `EquipManager.as:99` / `ItemCaiLiaoBox.as:51`，都只带一个物品 id。
##
## 盯八件（都是"跑起来才看得见"的）：
##   ① **空商品不许弹**（回包解码失败时 `后端连接` 直接 return，但真收到空 dict 也得挡住）；
##   ② 真商品 ⇒ 弹窗、`visible`、商品名/单价按 `now_price` 不是 `price`（`:218` 那条取价口径）；
##   ③ 连发两件 ⇒ 遮罩上**只有一枚**（复用，不叠）；
##   ④ 关闭 ⇒ `功能窗口._商城购买商品` 清空（下次开窗不带上一件）；
##   ⑤ 离线点「购买」⇒ 走 `_通知` 给说法、且 1079 没来**不许**弹窗；
##   ⑥ 两枚钱包勾选**进报文**（#17）：礼金品默认券 ⇒ 首字段 1，非礼金品只能元宝 ⇒ 首字段 0；
##   ⑦ **窗开着时宿主整页重建 ⇒ 玩家填的数量与勾的货币不许被冲回默认**（2026-10-18 实机报修
##      「购买方式 / 购买数量点不动」），并且重建期间**不许**重发 `request_cash_money`；
##      同一条还要钉**换商品时该重开**（守卫不能把正常换购也吞掉）。
##   ⑧ **商城里不许有「充值」按键**（2026-10-18 用户明确要求删掉，**有意偏离原版**）：
##      页面上 `货币栏/充值` 与购买窗里 `充值` 都不许在、两颗都不许被接线；「购买」单独居中；
##      2026-11-01 用户又要求把「充值提示」那条**文案**（`1RMB = 10元宝`）一起删掉，
##      并把翻页条从原版的 x=283（压着荣誉积分框）挪进它让出的 (454,386)。
##
## ⚠ 四条口径：
##   · 开场钉 `root.size`（无头视口是 64×64；本门虽不 push 鼠标，但居中算式读它）；
##   · 本门走 `call_deferred` ⇒ 宿主的 `_ready` 才跑得起来
##     （`SceneTree._initialize()` 阶段 `root` 还没进树，`_ready` 不执行 —— §3.124.4）；
##   · **不碰真链路**：信号是直接 `emit` 的（`requestCashMoney` 那条后端会自己判离线），
##     ⑥ 那两条购买把 `_backend` 换成 `记包后端`（只记参数、不发包），跑完换回去。
##
## 运行：`Godot --headless --path . --script res://测试/商城购买窗回归测试.gd`

const 窗场景 := "res://场景/界面/功能窗口.tscn"

## ⑧ 场景**文本**层比对用的串（节点名的引号是 ASCII，别写成「」）。
## `node name="充值"` 带尾引号 ⇒ 不会误命中 `node name="充值提示"`。
## 2026-11-01 起 `充值提示` 也不许再烘（用户要求删），另有一条独立 tripwire 钉它。
const 烘充值节点 := 'node name="充值"'
const 烘充值按钮 := 'node name="充值按钮"'


## ⑥ 用的**只记参数、不发包**的假后端（离线时真 `后端连接` 一律 return false，
## 拿不到报文）。`功能窗口._成交商城` 的兜底支调
## `request_cash_shop_buy(sn, 数量, 商店类型)` —— 第三参就是原版 `shopType`（钱包选择器）。
class 记包后端 extends Node:
	var 记录: Array = []
	var 钱数 := 0

	func request_cash_shop_buy(sn: int, 数量: int, 商店类型 := 0) -> bool:
		记录.append([sn, 数量, 商店类型])
		return true

	func request_cash_money() -> bool:
		钱数 += 1
		return true

var 红数 := 0
var _秒 := 0.0


## ⚠️ 看门狗：`_跑` 体里出运行时错误时脚本会当场断、**永不 quit** ⇒ 无头进程挂死两分钟，
## 而且红数不涨（"崩而不红"，§3.113）。本轮反向对照就踩到过（空指针那一下）。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("商城购买窗回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = (load(窗场景) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame

	var 后端 := root.get_node_or_null("BackendConnection")
	var 遮罩 := 场.get("_overlay") as Control
	if 后端 == null or 遮罩 == null:
		_记(false, "依赖不齐：后端=%s 遮罩=%s" % [后端, 遮罩])
		_finish()
		return
	if not 后端.has_signal("cash_item_info_received"):
		_记(false, "后端没有 cash_item_info_received 信号")
		_finish()
		return

	# ① 空商品：不许弹
	后端.cash_item_info_received.emit({})
	await process_frame
	_记(_取窗(遮罩) == null, "收到空商品也弹了购买窗")

	# ⑤ 统一出口 `功能窗口.请求商城商品` 的失败支：**离线不许静默**（点了得有人看见说法），
	#    而且没发出去就**不许**弹窗（弹了等于假装买到了）。这条要在 ② 之前跑 —— ② 之后
	#    遮罩上就有一枚（关掉也还在，只是 visible=false）。
	var 通知记录: Array[String] = []
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		会话.notification_requested.connect(func(文: String) -> void: 通知记录.append(文))
	场.call("请求商城商品", "16000031")
	await process_frame
	_记(通知记录.size() == 1 and 通知记录[0].contains("购买"),
			"离线点「购买」没给说法（应走 `_通知` 说一句），实测 %s" % str(通知记录))
	_记(_取窗(遮罩) == null, "离线（1079 根本没来）却弹出了购买窗")
	if 会话 != null:
		for 连 in 会话.notification_requested.get_connections():
			会话.notification_requested.disconnect(连["callable"])

	# ② 真商品
	后端.cash_item_info_received.emit({
		"id": "16000056", "sn": 4242, "name": "幸运符",
		"price": 100, "now_price": 80, "description": "本门用的假商品",
	})
	await process_frame
	var 窗 := _取窗(遮罩)
	_记(窗 != null, "收到 1079 商品详情后没弹购买窗（原版 Client.onCashItemInfo → addBuyWindow）")
	if 窗 == null:
		_finish()
		return
	_记(窗.visible, "购买窗弹出来了但 visible=false")
	_记((窗.get_node("商品名") as Label).text == "幸运符",
			"商品名 = %s ≠ 幸运符" % (窗.get_node("商品名") as Label).text)
	# `打开` 里 `_现价 = now_price else price`（`:218`）—— 80 是现价、100 是原价，取错就露馅
	_记((窗.get_node("商品单价") as Label).text == "80",
			"单价 = %s ≠ now_price 80（取了 price 就是 100）" % (窗.get_node("商品单价") as Label).text)
	var 成交: Callable = 场.get("_成交商城")
	_记(窗.确认购买.is_connected(成交), "购买窗的「确认购买」没接到 功能窗口._成交商城")
	_记(窗.关闭了.is_connected(场.get("_商城购买窗关了")), "购买窗的「关闭了」没接")

	# ②b 整舞台遮罩（原版 `CashShopWindow2.as:450` `centerWindow(buyEqpWindow, **true**)` ⇒
	#     `showWindow` 画一片 STAGE 大小、`beginFill(bgColor=0, bgAlpha=**0.3**)` 的遮罩，
	#     窗挂在它**上面**）—— 老账里"popUpMananger 全屏遮罩（居中弹只做了居中）"就是这条。
	var 挡 := 遮罩.get_node_or_null("购买窗遮罩") as ColorRect
	_记(挡 != null, "购买窗没有整舞台遮罩（原版 centerWindow 的 modal=true）")
	if 挡 != null:
		_记(挡.visible, "购买窗遮罩存在但 visible=false")
		_记(is_equal_approx(挡.color.a, 0.3) and 挡.color.r == 0.0 and 挡.color.g == 0.0 and 挡.color.b == 0.0,
				"遮罩色该是 黑 alpha 0.3（原版 centerWindow 默认），实测 %s" % str(挡.color))
		_记(挡.get_index() < 窗.get_index(), "遮罩该压在购买窗**下面**（原版窗挂在遮罩上面）")
		# ②c **模态形状**（用户 2026-10-22 报修 10「点一下就下降到最下面」）：
		#     `功能窗口.模态弹罩住` 认的是 `z_index >= 100` + STOP，`_input` 靠它决定"这一点不提任何窗"。
		#     遮罩 z_index 留 0 ⇒ 认不出来 ⇒ 购买窗被别的窗的 layer 压下去（行为腿在
		#     `窗口行为契约体检` 的庚组，这里先钉形状，免得有人把 z_index 改回默认还"看着没事"）。
		_记(挡.z_index >= 100,
				"②c 购买窗遮罩 z_index = %d < 100 ⇒ `模态弹罩住` 认不出这层模态（报修 10 的成因）" % 挡.z_index)
		_记(窗.z_index > 挡.z_index,
				"②c 购买窗 z_index(%d) 没压在遮罩 z_index(%d) 之上 ⇒ 黑 α0.3 会盖着窗"
						% [窗.z_index, 挡.z_index])

	# ── 0.2 购买窗可自由拖动（用户 2026-11-01 要求）────────────────────────────
	# 原版 `BuyEqpWindow.as:279` 构造里 `startDragY = -1`（MWindow 的拖动区被关掉），
	# 这扇窗拖不动；本工程按用户要求**有意偏离**：只认顶部 29px（`MWindow.as:229`）内的左键，
	# 并夹在舞台矩形内。
	_记(窗.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"0.2 购买窗根节点 mouse_filter=IGNORE ⇒ 顶部拖动区收不到 gui_input")
	var 原位 := 窗.global_position
	var 按下 := InputEventMouseButton.new()
	按下.button_index = MOUSE_BUTTON_LEFT
	按下.pressed = true
	按下.position = Vector2(100.0, 10.0)                  # 顶部 29px 内
	按下.global_position = 原位 + 按下.position
	窗.gui_input.emit(按下)
	var 移动 := InputEventMouseMotion.new()
	移动.position = Vector2(140.0, 40.0)
	移动.global_position = 按下.global_position + Vector2(40.0, 30.0)
	窗.gui_input.emit(移动)
	await process_frame
	_记(窗.global_position.is_equal_approx(原位 + Vector2(40.0, 30.0)),
			"0.2 拖顶部 29px 没把购买窗挪走：%s → %s（期望 +40,+30）"
				% [str(原位), str(窗.global_position)])
	# 拖出舞台 ⇒ 钳在舞台边（不然窗能被拖到屏幕外、再也点不回来）
	var 移动2 := InputEventMouseMotion.new()
	移动2.global_position = Vector2(5000.0, 5000.0)
	窗.gui_input.emit(移动2)
	await process_frame
	var 舞台 := 窗.get_viewport().get_visible_rect().size
	_记(窗.global_position.x <= 舞台.x - 窗.size.x + 0.5
			and 窗.global_position.y <= 舞台.y - 窗.size.y + 0.5,
			"0.2 拖动没夹在舞台内：窗 %s 越界（舞台 %s，窗尺 %s）"
				% [str(窗.global_position), str(舞台), str(窗.size)])
	var 抬起 := InputEventMouseButton.new()
	抬起.button_index = MOUSE_BUTTON_LEFT
	抬起.pressed = false
	抬起.global_position = Vector2(5000.0, 5000.0)
	窗.gui_input.emit(抬起)
	# 标题下方按下 ⇒ 不许拖（拖动区只有顶部 29px；否则窗内任何点击都会把窗拽走）
	var 原位2 := 窗.global_position
	var 按下2 := InputEventMouseButton.new()
	按下2.button_index = MOUSE_BUTTON_LEFT
	按下2.pressed = true
	按下2.position = Vector2(100.0, 60.0)
	按下2.global_position = 原位2 + 按下2.position
	窗.gui_input.emit(按下2)
	var 移动3 := InputEventMouseMotion.new()
	移动3.global_position = 按下2.global_position + Vector2(60.0, 60.0)
	窗.gui_input.emit(移动3)
	await process_frame
	_记(窗.global_position.is_equal_approx(原位2),
			"0.2 在标题下方按下也把窗拖走了（拖动区该只认顶部 29px）")
	窗.gui_input.emit(抬起)

	# ③ 连发两件：复用同一枚，不叠
	后端.cash_item_info_received.emit({
		"id": "11000102", "sn": 9, "name": "另一件", "price": 5,
	})
	await process_frame
	var 枚 := 0
	for 子 in 遮罩.get_children():
		if String(子.name).begins_with("商城购买窗"):
			枚 += 1
	_记(枚 == 1, "连发两条商品详情后遮罩上有 %d 枚购买窗（应复用成 1 枚）" % 枚)

	# ④ 关掉 ⇒ 记着的商品要清
	窗.call("隐藏")
	await process_frame
	_记((场.get("_商城购买商品") as Dictionary).is_empty(),
			"关窗后 _商城购买商品 没清空：%s" % 场.get("_商城购买商品"))
	# ⚠️ 用 ②b 那枚 `挡` 来判，**不要**这里重新 `get_node_or_null` 再 `.visible` ——
	#    遮罩不存在时那就是空指针，脚本当场断、**崩而不红**（§3.113 那条；本轮反向对照实测挂死过一次）。
	_记(挡 != null and not 挡.visible, "关窗后整舞台遮罩该一起撤掉")

	# ⑥ 两枚勾选**真的进报文**（2026-10-17 巡检 #17）：
	#   `BuyEqpWindow.as:353` `shopType = this.ybCheckBox.selected ? 0 : 1` →
	#   `UI.as:1453` `Client.requestShopping(shopType, sn, quantity)` —— 首字段是**钱包选择器**
	#   （0 元宝 / 1 点券，同自动买那段 `WaiGuaHandler.as:229/233`）。
	#   修之前 `_成交商城` 收了第三参又丢掉 ⇒ 无论勾哪枚都发 0，「点券」白勾。
	# ⚠️ 用**记不着的 sn**（货架里没这两行）：`_成交商城` 先按 sn 查 `_session.shop_catalog`，
	#    命中就走 `_buy_item`（按物品 id 的离线支）而**根本不碰后端** ⇒ 断言会假绿/假红。
	# ⚠️ 排在 ④ **之后**：这里按「购买」会真把窗关掉，插在 ④ 前面会让 ④ 变成空判。
	var 记包 := 记包后端.new()
	场.set("_backend", 记包)
	后端.cash_item_info_received.emit({
		"id": "16000004", "sn": 42421, "name": "扩充密卷", "price": 10, "is_li_jin": true,
	})
	await process_frame
	var 礼金窗 := _取窗(遮罩)
	if 礼金窗 == null:
		_记(false, "⑥ 礼金品没弹出购买窗")
	else:
		# `setData` `:218-222`：`isLiJin` ⇒ 券勾选**可见**且**默认选中**
		_记((礼金窗.get_node("券勾选") as CheckBox).visible, "⑥ 礼金品没显示「点券」勾选（:218 只有 isLiJin 才可见）")
		_记((礼金窗.get_node("券勾选") as CheckBox).button_pressed, "⑥ 礼金品没**默认**选中点券（:220 ljCheckBox.selected = true）")
		# `:226` 那句 `ybCheckBox.enabled = false` 在 **else**（非礼金）分支里 ⇒ 礼金品的元宝勾选仍可用
		_记(not (礼金窗.get_node("元宝勾选") as CheckBox).disabled, "⑥ 礼金品的元宝勾选该仍可用（置灰只给非礼金品）")
		_记((礼金窗.get_node("余额标签") as Label).text == "你帐号中还有点券：",
				"⑥ 余额行文案没跟着券走（`setBuyInfo` 的 `%1`）")
		(礼金窗.get_node("购买") as Button).pressed.emit()
		await process_frame
		_记(记包.记录.size() == 1 and int(记包.记录[0][2]) == 1,
				"⑥ 勾着点券购买，报文首字段该是 1，实测 %s" % str(记包.记录))

	# ⑥b 非礼金品：元宝勾选**置灰**、券勾选**不显示**（`:226-227` ⇒ 玩家点不到券，只能走元宝），
	#     余额行照旧按**元宝**写（`setData` 的 else 分支是会调 `setBuyInfo(CN.COIN,false)` 的；
	#     `_选货币` 那个守卫只拦用户点击、**必须放行初始化** —— 撞过「你帐号中还有元宝：」整行空着）。
	#     顺带钉住「关掉之后再收一条商品详情 ⇒ 能重新开出来」（§3.49.4 那条打开态）。
	后端.cash_item_info_received.emit({
		"id": "16000056", "sn": 42422, "name": "非礼金品", "price": 100,
	})
	await process_frame
	var 元宝窗 := _取窗(遮罩)
	if 元宝窗 == null:
		_记(false, "⑥b 关过窗之后再收商品详情没重新弹窗")
	else:
		_记(元宝窗.visible, "⑥b 重新弹窗但 visible=false")
		_记(not (元宝窗.get_node("券勾选") as CheckBox).visible, "⑥b 非礼金品不该显示券勾选（:227）")
		_记((元宝窗.get_node("元宝勾选") as CheckBox).disabled, "⑥b 非礼金品的元宝勾选该置灰（:226 `ybCheckBox.enabled = false`）")
		_记((元宝窗.get_node("余额标签") as Label).text == "你帐号中还有元宝：",
				"⑥b 非礼金品的余额行没按元宝初始化")
		(元宝窗.get_node("购买") as Button).pressed.emit()
		await process_frame
		_记(记包.记录.size() == 2 and int(记包.记录[1][2]) == 0,
				"⑥b 非礼金品购买报文首字段该是 0，实测 %s" % str(记包.记录))
	场.set("_backend", 后端)
	记包.free()		# 没进树，得自己释放（不然收尾报 ObjectDB leaked）

	# ── ⑦ 窗开着时宿主整页重建 ⇒ 不许把玩家刚填的东西冲掉（2026-10-18 实机报修）───
	#   病根：`_render_shop()` 末尾原来写的是「按窗口上记着的商品**再开一次**购买窗」，
	#   而 `商城购买窗.打开()` 头几句就是 `_数量.text = "1"`、按 `is_li_jin` 重设两枚勾选、
	#   宿主那边还顺手再发一发 `request_cash_money`。`_refresh_current` 挂了十几个信号
	#   （血量/背包/社交…实机里几乎每帧来一条）⇒ 玩家看到的是"填了又弹回去、点哪儿都没用"。
	#   修完这条路只补余额数字（`刷新商城购买窗余额` ⇒ `商城购买窗.刷新余额`）。
	# ⚠️ 先把宿主切到**商城页**：`刷新商城购买窗余额` 是 `_render_shop()` 里调的，
	#    停在别的页就等于这条腿什么都没测（购买窗挂在 `_overlay` 上、本来就不随页重建消失）。
	场.call("open_page", "商城")
	await process_frame
	var 计钱 := 记包后端.new()
	场.set("_backend", 计钱)
	# ── ⑨ `_荣誉积分` 取后端那张表**不许**写 `get(...) as Dictionary`。桩后端没有
	#    `authoritative_muye_battle` 这个属性 ⇒ `null as Dictionary` 抛 `Invalid cast`，
	#    而抛点在 `_渲染商城货币栏` 的**中间**（写积分那一句），后面那句 tooltip 就静默没跑
	#    （§3.245：这条是全量日志 grep `SCRIPT ERROR` 才逮到的，本门原来只判按键在不在 ⇒ 照绿）。
	#    ⚠ 这条**只能做源码 tripwire**，行为腿判不动：`call()` 一个被抛错打断的函数，
	#      拿到的是**声明返回类型的默认值**（`-> int` ⇒ 0），与"正常返回 0"一模一样
	#      （`开发工具/_probe_call抛错返回值.gd` 实测，本轮 cp 变异两刀都从这儿空绿过去）。
	#    ⚠ 也不许改成"看窗上 Label"：这页是复制出来的，`.tscn` 烘的 text 就是 "0"，
	#      tooltip 还带着上一次真后端写过的那句 ⇒ 同样是空判。
	var 社交源 := _读文本("res://脚本/界面/窗口/社交窗口.gd")
	_记(社交源.contains('var 战斗: Variant = 后.get("authoritative_muye_battle")')
			and not 社交源.contains('后.get("authoritative_muye_battle") as Dictionary'),
			"⑨ `_荣誉积分` 又用回 `后.get(...) as Dictionary`（源文本里查到的）：桩后端缺该属性时"
			+ "抛 Invalid cast、抛点在货币栏刷新中间，后面 tooltip 那句静默没跑（§3.245）")
	后端.cash_item_info_received.emit({
		"id": "16000004", "sn": 42423, "name": "扩充密卷", "price": 10, "is_li_jin": true,
	})
	await process_frame
	var 买窗 := _取窗(遮罩)
	if 买窗 == null:
		_记(false, "⑦ 商城页上没弹出购买窗，重建那条判据做不了")
	else:
		var 数量 := 买窗.get_node("数量") as LineEdit
		数量.text = "5"
		# 礼金品默认勾**点券**（`:220`），玩家把购买方式改回元宝 ⇒ 走 `pressed`，
		# 只有真点击才调 `_选货币`（直接置 `button_pressed` 不会，等于没模拟到玩家那一下）
		(买窗.get_node("元宝勾选") as CheckBox).pressed.emit()
		_记(数量.text == "5" and not bool(买窗.get("_用点券")),
				"⑦ 前置没做好：数量=%s 用点券=%s（后面测的是「改完之后再来一条状态帧」）" % [数量.text, str(买窗.get("_用点券"))])
		计钱.钱数 = 0
		场.call("_refresh_current")		# 一条状态帧就够 —— 实机里几乎每帧来一条
		await process_frame
		await process_frame
		_记(买窗.visible, "⑦ 页面重建把购买窗弄没了（玩家正看着它填东西）")
		_记(数量.text == "5",
				"⑦ 重建后数量被冲回「%s」（原版没有「重建就重开购买窗」这回事，玩家刚填的数没了）" % 数量.text)
		_记(not bool(买窗.get("_用点券")), "⑦ 重建后购买方式被勾回点券（玩家刚改的没了）")
		_记((买窗.get_node("总价") as Label).text == "50",
				"⑦ 重建后总价 = %s ≠ 5×10=50（程序赋值不发 text_changed，总价只能靠重建后那一次刷新算出来）"
					% (买窗.get_node("总价") as Label).text)
		_记(计钱.钱数 == 0, "⑦ 页面重建重发了 %d 发 request_cash_money（每来一条状态帧查一次钱包）" % 计钱.钱数)

		# ⑦a2 **但余额那一行还得跟着刷** —— 「不重开」不能顺手改成「什么都不做」：
		#      钱包回帧改了 `player_stats`，窗上的「账号余额」要跟着变（`setBuyInfo` 那半边）。
		if 会话 != null:
			var 统计: Dictionary = 会话.get("player_stats")
			统计["cash"] = 777
			场.call("_refresh_current")
			await process_frame
			await process_frame
			_记((买窗.get_node("账号余额") as Label).text == "777",
					"⑦a2 钱包变了、重建后窗上余额没跟着刷（「只补余额」那半边被删成什么都不做）：实测 %s"
						% (买窗.get_node("账号余额") as Label).text)

		# ⑦b 换**另一件**商品 ⇒ 必须重开（数量回 1、发一发查余额）：守卫不能把正常换购也吞掉
		后端.cash_item_info_received.emit({
			"id": "16000056", "sn": 42424, "name": "另一件", "price": 7,
		})
		await process_frame
		_记(数量.text == "1", "⑦b 换成另一件商品后数量没回 1（同商品守卫过头，换购被吞）")
		_记(计钱.钱数 == 1, "⑦b 换购该重发 1 发 request_cash_money，实测 %d" % 计钱.钱数)

		# ⑦c 同一件商品**再收一条 1079** ⇒ 只补余额：数量不许动、不许多发查钱包
		数量.text = "3"
		后端.cash_item_info_received.emit({
			"id": "16000056", "sn": 42424, "name": "另一件", "price": 7,
		})
		await process_frame
		_记(数量.text == "3", "⑦c 重复收到同一件商品的详情把数量冲回了「%s」" % 数量.text)
		_记(计钱.钱数 == 1, "⑦c 同一件商品重复回包又不该重发 request_cash_money，实测 %d" % 计钱.钱数)

		# ── ⑧ 商城里不许有「充值」按键（2026-10-18 用户明确要求删掉，**有意偏离原版**）───
		#   原版有两颗：`CashMoneyPane.as:73-77` 商城底部 payBtn @(530,-4)、
		#   `BuyEqpWindow.newBtn():158-159` 购买窗里与「购买」并排的那颗，都跳 `Config.ChargeUrl`。
		#   本工程没有充值渠道 ⇒ 两颗删掉、「购买」单独居中。
		#   ⚠️ 这条门**不是钉原版**，是钉"别哪天照 AS3 把它补回来"（合并/回归最容易干这事）。
		var 内容 := 场.get("_content") as Control
		# ⚠️ `_content` 是**页面容器**，商城页本体是它的孩子 `原版商城窗口内容`
		#    （实测 `子=["原版商城窗口内容"]`）。直接 `内容.get_node_or_null("货币栏/充值")`
		#    永远返回 null ⇒ "不许有充值"那条会**空判假绿**（§3.113 那条老坑的又一个形状）。
		var 页 := (内容.get_node_or_null("原版商城窗口内容") as Control) if 内容 != null else null
		if 页 == null:
			_记(false, "⑧ 商城页本体没找到（`_content` 里不是「原版商城窗口内容」）—— 前两条会空转")
		_记(页 == null or 页.get_node_or_null("货币栏/充值") == null,
				"⑧ 商城页 `货币栏` 下又长出「充值」按键（用户明确要求删，属有意偏离原版）")
		_记(页 == null or 页.get_node_or_null("货币栏/充值提示") == null,
				"⑧ 商城页 `货币栏` 下又长出「1RMB = 10元宝」提示（用户 2026-11-01 要求删，属有意偏离原版）")
		# 2026-11-01 用户报「右下角翻页按键跟荣誉积分的文字和数值框重叠了，可以把翻页移到右侧
		# （刚好是删除的 1RMB=10元宝文字的位置）」⇒ 分页条从原版 x=283 挪到 454，y 仍是 386。
		# 原版 x 公式见 `CashShopWindow2.as:278-282`；重叠是原版自带（`hideRongYuShop` 零调用点），
		# 本工程按用户要求主动避开 —— 有意偏离，别照 AS3 改回 283。
		var 条 := (页.get_node_or_null("分页条") as Control) if 页 != null else null
		_记(条 != null, "⑧ 商城页找不到 `分页条`（下面三条会空转）")
		if 条 != null:
			_记(is_equal_approx(条.position.x, 454.0) and is_equal_approx(条.position.y, 386.0),
					"⑧ 翻页条没在右侧空位：position=%s（该是 (454, 386)，即删掉的「1RMB = 10元宝」位）"
						% str(条.position))
			var 积分底 := 页.get_node_or_null("荣誉积分底") as Control
			var 积分标 := 页.get_node_or_null("荣誉积分标签") as Control
			var 积分右 := -1.0
			if 积分底 != null:
				积分右 = maxf(积分右, 积分底.position.x + 积分底.size.x)
			if 积分标 != null:
				积分右 = maxf(积分右, 积分标.position.x + 积分标.size.x)
			_记(积分右 >= 0.0 and 条.position.x >= 积分右,
					"⑧ 翻页条还压着荣誉积分（翻页左缘 %s < 积分右缘 %s）—— 用户报的就是这个重叠"
						% [str(条.position.x), str(积分右)])
			_记(is_equal_approx(条.size.x, 124.0) and is_equal_approx(条.size.y, 20.0),
					"⑧ 翻页条尺寸被改过：%s（PageComponent 合宽 124、高 20）" % str(条.size))
		_记(买窗.get_node_or_null("充值") == null, "⑧ 购买窗里还有「充值」节点")
		var 买 := 买窗.get_node("购买") as Button
		_记(is_equal_approx(买.position.x, (买窗.size.x - 买.size.x) * 0.5),
				"⑧ 「购买」没在窗里居中：x=%s，居中该是 %s（旁边那颗删了要按**按钮自身宽**居中）"
					% [str(买.position.x), str((买窗.size.x - 买.size.x) * 0.5)])
		_记(买.position.x >= 0.0 and 买.position.x + 买.size.x <= 买窗.size.x,
				"⑧ 「购买」跑到窗外面去了（x=%s 宽=%s 窗宽=%s）"
					% [str(买.position.x), str(买.size.x), str(买窗.size.x)])
		# 删了旁边那颗，**剩下这颗必须照旧能用**：点一下仍走 `_成交商城` 发报文
		var 记录前 := 计钱.记录.size()
		买.pressed.emit()
		await process_frame
		_记(计钱.记录.size() == 记录前 + 1,
				"⑧ 删掉「充值」之后「购买」点下去不发报文了（记录 %d → %d）" % [记录前, 计钱.记录.size()])
		# 场景**文本**层的 tripwire：只拆接线、节点还烘在 .tscn 里 = 窗上摆一枚点不动的假充值钮。
		# 反向对照里"删掉 `社交窗口` 那三行接线、节点留着"这一刀，**只有**这两条会红。
		var 商城场景 := _读文本("res://场景/界面/窗口/商城/商城窗口.tscn")
		var 买窗场景 := _读文本("res://场景/界面/组件/商城购买窗.tscn")
		var 福利场景 := _读文本("res://场景/界面/窗口/福利/福利窗口.tscn")
		if 商城场景.is_empty() or 买窗场景.is_empty() or 福利场景.is_empty():
			_记(false, "⑧ 场景文件读不到（下面三条会空转）")
		_记(not 商城场景.contains(烘充值节点) and not 买窗场景.contains(烘充值节点),
				"⑧ .tscn 里还烘着充值按钮节点（半删：节点在、线没了 ⇒ 玩家看见一枚点不动的充值钮）")
		_记(not 商城场景.contains("充值按钮.png"),
				"⑧ 商城窗口.tscn 还引用充值皮肤「充值按钮.png」（按钮删了，ext_resource 也该一起退）")
		_记(not 商城场景.contains('node name="充值提示"'),
				"⑧ .tscn 里还烘着「1RMB = 10元宝」文案节点（用户 2026-11-01 要求删）")
		# 边界改过一轮：2026-10-28 用户点头把**福利窗**那枚充值按钮也一起拆了
		#   （「首充礼包和新服有礼两个子面板，去掉需要充值的功能逻辑和信息」⇒ 改名首日礼包）。
		#   原来这条钉的是"别越界删福利窗的"，现在钉的是反面：**福利窗也不许再出现充值节点/皮肤**。
		#   登记见 真值/窗口/开心有礼.md ④ ＋ 编年史 §3.304。
		_记(not 福利场景.contains(烘充值按钮) and not 福利场景.contains("充值按钮.png"),
				"⑧ 福利窗还留着充值按钮节点或充值皮肤（这页已经改成首日礼包，不该再挂充值入口）")
	场.set("_backend", 后端)
	计钱.free()

	# ── ⑩ 提示行**要自收**（用户 2026-10-22 报修 9「商店购买东西、宝石合成…会有灰色字体一直挂在
	#    面板上方，不消失，除非关闭面板」）────────────────────────────────────────
	#   真值：原版那口反馈根本不是窗内的常驻标签，而是 `MessageTipPane` 的黄色飘字 ——
	#   `MessageTipPane.as:80-97` `showMessage` 里 `TweenLite.to(tf, 5, {y:-60, alpha:0,
	#   onComplete:remove})`：5 秒升 60 像素并淡到全透明再摘掉（攒过 `MAX_LINES=10` 还挤掉最旧一行）。
	#   这边把反馈复用在窗内那枚灰色 `后端状态` 标签上、又没搬补间 ⇒ 写完**常驻**。
	#   修法按同一个 5 秒收（`提示自收秒`）；下面四条里**第三条**专防"连点两下被上一发提前收掉"。
	var 态 := 场.get("_status") as Label
	var 自收秒 := float((场.get_script() as GDScript).get_script_constant_map().get("提示自收秒", 0.0))
	_记(自收秒 > 0.0, "⑩ 读不到 `提示自收秒` 常量 ⇒ 后面三条全按 0 秒空转（假绿）")
	场.call("_show_hint", "本门用的假提示")
	_记(态 != null and 态.text == "本门用的假提示" and 态.visible,
			"⑩ 刚写完提示就该显形（老口径只断 .text 是假绿：那枚标签在场景里 visible=false）")
	await create_timer(自收秒 * 0.6).timeout
	场.call("_show_hint", "第二句")
	await create_timer(自收秒 * 0.6).timeout
	# 此刻第一句排的那发**已经到期**（1.2 倍 > 1.0 倍）⇒ 它不许把第二句提前收掉
	_记(态 != null and 态.text == "第二句" and 态.visible,
			"⑩ 连点两下时上一发的自收把这一发提前收了（实测「%s」visible=%s）"
					% [态.text if 态 != null else "<无 _status>",
						str(态.visible if 态 != null else false)])
	await create_timer(自收秒 * 0.6).timeout
	_记(态 != null and 态.text == "" and not 态.visible,
			"⑩ 过了 %f 秒灰字还挂在面板上 = 用户报修 9（实测「%s」visible=%s）"
					% [自收秒, 态.text if 态 != null else "<无 _status>",
						str(态.visible if 态 != null else false)])
	# 关窗那半句「除非关闭面板」：这行字钉在**窗内**（原版飘字挂全局容器），
	# 而本工程窗只藏不删 ⇒ 不清的话下次开窗把上次那句重新显形。
	场.call("_show_hint", "关窗前那句")
	场.call("close")
	_记(态 != null and 态.text == "" and not 态.visible,
			"⑩ 关窗没清提示行（下次开窗会带着上一句出来，实测「%s」visible=%s）"
					% [态.text if 态 != null else "<无 _status>",
						str(态.visible if 态 != null else false)])

	_finish()


## 遮罩上那枚购买窗。按**前缀**找：叠了两枚时 Godot 会把后一枚改名 `@Control@N`。
func _取窗(遮罩: Control) -> Control:
	for 子 in 遮罩.get_children():
		if String(子.name).begins_with("商城购买窗"):
			return 子 as Control
	return null


## ⑧ 读场景源文本（`.tscn` 是纯文本，`instantiate` 之后的树看不到"删干净没有"）。
## 读不到返回空串，由调用处**显式记一条红**，免得三条判据一起空转成假绿。
func _读文本(路径: String) -> String:
	var 文 := FileAccess.open(路径, FileAccess.READ)
	if 文 == null:
		return ""
	return 文.get_as_text()


func _finish() -> void:
	if 红数 == 0:
		print("商城购买窗回归测试：通过（空商品不弹 / 离线请求失败不弹且给说法 / "
				+ "真商品弹且取现价 / 连发复用一枚 / 关窗清记 / 钱包勾选进报文 / "
				+ "重建不冲掉数量与勾选、不重发查钱包 / 商城里没有充值按键 / "
				+ "遮罩长成模态形状且窗压遮罩之上 / 顶部可拖动且夹在舞台内 / "
				+ "灰提示字 5 秒自收、关窗清行）")
		quit(0)
	else:
		print("商城购买窗回归测试：失败 %d 项" % 红数)
		quit(1)

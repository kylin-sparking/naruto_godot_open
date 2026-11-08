extends SceneTree
## 神秘商店窗（原版 `MysteryWindow` + `MysteryCell`）离线门。
## 逐件参照值手抄自 `真值/窗口/神秘商店.md` 与 `2.2.3/.../controls/mystery/*.as`，**不从被测场景反查**。
##
## 覆盖：① 324 入帧（写**新**那本账、绝不碰 NPC 商店那本）+ 空货架 `-` / 半条 / 缺列三种坏帧各自的出口
## ② 消费者：那一帧到本端 ⇒ 窗自己开 + 背包一起开、顶边平齐、背包左沿 = 神秘右沿 + 1
## ③ 逐件矩形（页根 / 两块底板 / 十二格原点 / 格内十件 / 底部四件）+ 九宫格边距读回
## ④ 十二格只填前 N 条、其余**空着不冒充**；名称 / 价格（`yb` 不是 `meso`）/ 币种三选一 / 已购买绿字
## ⑤ 点一格买：够 ⇒ 弹确认后「确定」才发 `7:<item_id>`、「取消」一帧不发
## ⑥ 两支 `<=`：余额**正好等于价** ⇒ 一句拒绝、连弹都不出（改成 `<` 这条会红）
## ⑦ moneyType==2 ⇒ 原版 #1009 那条呆账：什么都不许发生
## ⑧ 刷新：`cash<=50` 不发；「今日不再提示」勾选流（取消不改标志、勾上 ⇒ 下次直接发 8）
## ⑨ 重灌：格换了、表没被重起、文案不被立刻重绘、`剩` 跟最新帧
## ⑩ 秒表（真秒驱动）：关窗清状态 ⇒ 头一秒 `00:00:00`、走到 0 还站一秒才出「已刷新」、迟到的 324 不复活
## ⑪ 小时从 3600 里除（21600 过一拍 ⇒ `05:59:59`）
## ⑫ 尺寸表那条 + `伴随背包` + 不在 `居中弹`。
##
## 跑法：`Godot --headless --path . --script res://测试/神秘商店窗回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")
const 窗脚本 := preload("res://脚本/界面/窗口/神秘商店/神秘商店窗.gd")

## 五条货架：元宝 100 / 点券 50 / 元宝 20（**已购买**）/ 点券 300 / **双币** 80。
## 物品号是**挑过的**：客户端表里查不到名字时 `item_name` 会退回成 id 串，那样"名称对上了"就成了自证，
## 所以下面五个都必须是表里真有名有图的（10000001 熊皮 / 02010010 轻藤兽铠 / 03000001 拉面（小）
## / 10000002 裂开的蛇皮 / 10000003 神秘木盒 —— 其中 2010010、3000001 线上是个数 ⇒ 顺带钉住补零那一步）。
const 帧 := "324:21597:10000001&5&100&0&200000&0@2010010&1&50&1&0&0@3000001&3&20&0&0&1@10000002&2&300&1&0&0@10000003&1&80&2&0&0:100"
const 期号 := ["10000001", "02010010", "03000001", "10000002", "10000003"]
const 期名 := ["熊皮", "轻藤兽铠", "拉面（小）", "裂开的蛇皮", "神秘木盒"]
const 期价 := ["100", "50", "已购买", "300", "80"]		# 页上**显示**的那一句
const 期yb := [100, 50, 20, 300, 80]						# 线里 `yb` 那一段
const 期币 := [0, 1, 0, 1, 2]

## §③ 页局部（= AS3 外框坐标 − 29，`数据/界面/窗口尺寸.json` 的 `整框: true` 那一支）
const 窗件 := {
	"内容底": [8.0, 9.0, 259.0, 326.0],		# `_contentBg`：275−16 × 394−68；y = 38−29
	"大底板": [13.0, 14.0, 249.0, 316.0],	# `MysteryWindow.as:63-66` `_contentBg ± BORDER_GAP(5)`
	"倒计时": [8.0, 338.0, 128.0, 25.0],	# `:89-93` x = `_contentBg.x`、y = `_height−27` = 367、label 128×25
	"花费": [136.0, 338.0, 55.0, 20.0],		# `:98-99` x = `_timeLabel.x + _timeLabel.width`
	"币标": [191.0, 341.0, 19.0, 13.0],		# `:101-107` x = `_refMoneyLabel.x + width`、y = +3
	"币标/币标元宝": [0.0, 0.0, 19.0, 13.0],		# `MIconGoldYuanBaoF`
	## ⚠ 这一枚**没有券**：`:102-103` 造了 `CN.QUAN_ICON`、把 x 摆到 10，却一次 `addChild` 都没调
	## ⇒ Flash 的 `Sprite.width` 只数真挂上去的孩子 ⇒ 容器宽 = 元宝的 19，不是 MysteryCell 那个 29。
	## 原版这一排本来就只亮一枚元宝（刷新永远收元宝）。照抄，别"顺手补全"。
	"刷新钮": [218.0, 338.0, 37.0, 22.0],	# `:109-112` x = `币标.x + 19 + 8`、y = `币标.y − 3`、宽 = btn_width_two
}
const 格内件 := {
	"格底": [0.0, 0.0, 120.0, 50.0],		# `MysteryCell.as:41-42`
	"物品格": [4.0, 5.0, 40.0, 40.0],		# `:45-46` x = `paneSkin.x+4`、y = `(50−40)/2`
	"物品格/图标": [3.0, 3.0, 34.0, 34.0],	# 与 `场景/界面/组件/物品格.tscn` 同一枚内衬
	"名称": [44.0, 4.0, 70.0, 20.0],		# `:49-51` x = `物品格.x+width`、y = `paneSkin.y+4`
	"元宝图": [46.0, 27.0, 19.0, 13.0],		# `:63-65` x = `物品格.x+width+2`、y = 27
	"券图": [46.0, 27.0, 19.0, 13.0],		# `:67-69` 同位
	"双币": [46.0, 27.0, 29.0, 13.0],		# `:54-61` 容器（两枚并排 ⇒ 宽按 10+19 = **29** 算）
	"双币/双币元宝": [0.0, 0.0, 19.0, 13.0],
	"双币/双币券": [10.0, 0.0, 19.0, 13.0],		# `:56` `_loc1_.x = 10`
	"价格": [75.0, 25.0, 45.0, 20.0],		# `:72-75` x = `46 + 29`、y = `27−2` ⇒ **不是 76/27**
}

var 通过 := 0
var 失败 := 0
var 跑完了 := false


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


## 按名字找页。`_render_page` 是 `remove_child` + `queue_free`，摘得很利索；
## 这层 `is_queued_for_deletion` 只是防"同一帧里新旧两页都在"那种情况拿错旧的。
func _找页(窗: Node, 名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String(子.name) == 名 and not 子.is_queued_for_deletion():
			return 子 as Control
	return null


func _找弹(窗: Node, 型: String) -> Control:
	var 台 := 窗.get("_overlay") as Control
	if 台 == null:
		return null
	for 子 in 台.get_children():
		if 子.has_meta("mdialog") and String(子.get_meta("mdialog")) == 型 \
				and not 子.is_queued_for_deletion():
			return 子 as Control
	return null


func _喂(原文: String) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_text", 原文)


## 真鼠标点某个件。无头三条硬口径：钉视口、先挪鼠标、坐标走 `get_global_rect()`。
func _点在(件: Control) -> void:
	var 屏: Vector2 = 件.get_global_rect().position + Vector2(
			min(10.0, 件.size.x * 0.5), min(10.0, 件.size.y * 0.5))
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	root.push_input(移)
	await process_frame
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	root.push_input(按)
	await process_frame
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	root.push_input(放)
	await process_frame
	await process_frame
	await process_frame


## 点确认弹底下的那枚钮。**弹不在就直接判红**，不许"没弹就跳过"（那是把判据悄悄吃掉）。
func _点弹钮(弹: Control, 件名: String) -> void:
	if 弹 == null:
		_判(false, "确认弹不在 ⇒ 点不到「%s」" % 件名)
		return
	var 件 := 弹.get_node_or_null("主体/" + 件名) as Button
	if 件 == null:
		_判(false, "确认弹里没有「%s」" % 件名)
		return
	await _点在(件)


## 每扇已开窗的 CanvasLayer 层号（按 `_顺序` 走一遍）。
## 弹层挂在**各窗自己的** `遮罩` 里 ⇒ 隔壁那扇窗一旦排到它上面，弹就既被画压住也点不着。
## 腿⑬拿它钉「点弹层不许把隔壁窗提起来」。
func _层号(管理: Node) -> Dictionary:
	var 出: Dictionary = {}
	var 们: Dictionary = 管理.get("_窗口们") as Dictionary
	for 名 in 管理.get("_顺序"):
		var 窗 = 们.get(名)
		if 窗 != null:
			出[名] = int(窗.layer)
	return 出


## 等真秒（秒表那两条腿判的是 `Timer.wait_time = 1.0` 真的会 tick，不是手工调私有函数）。
## 1.2s 而不是 1.0s：留余量给无头那一侧的帧抖动，别让"到点"卡在等待结束之后。
func _等秒(秒: float) -> void:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		await process_frame


func _未完就退(窗: Node, 名: String) -> bool:
	if 窗 == null:
		_判(false, "%s 没开出来 ⇒ 后面的判据无从跑起" % 名)
		跑完了 = true
		print("神秘商店窗离线门：通过 %d，红 %d" % [通过, 失败])
		return true
	return false


## 假后端：只管**出帧**那半边（入帧走真后端）。字段名一律和真后端里那个同名，
## 别在这里覆写 `get()`（Godot 会当成覆写 `Object.get` ⇒ 整脚本 parse 失败）。
class 假后 extends Node:
	var authoritative_mystery_shop: Dictionary = {}
	var 发过: Array = []

	func request_secret_shop_open() -> bool:
		发过.append(["开"])
		return true

	func request_secret_shop_buy(号: int) -> bool:
		发过.append(["买", 号])
		return true

	func request_secret_shop_refresh() -> bool:
		发过.append(["刷新"])
		return true


func _跑() -> void:
	print("神秘商店窗离线门开始")
	await process_frame
	var 后 = root.get_node("BackendConnection")
	var 会 = root.get_node_or_null("GameSession")
	_判(会 != null, "门跑之前 `GameSession` 这个 autoload 必须在（余额那两条判据靠它）")
	后.set("in_game", false)
	后.set("authoritative_mystery_shop", {})
	后.set("authoritative_npc_shop", {"哨兵": 1})
	root.size = Vector2i(960, 560)
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame

	# ── ① 入帧：324 走自己那本账 ─────────────────────────────────────────────
	# ⚠ 闭包**按值捕获**局部量 ⇒ 计数得塞进数组，不然这条腿永远是零覆盖的假绿。
	var npc响 := []
	后.connect("npc_shop_received", func(_x): npc响.append(1))
	_喂(帧)
	var 状: Dictionary = 后.get("authoritative_mystery_shop") as Dictionary
	var 货: Array = 状.get("items", []) as Array
	_判(货.size() == 5, "货架五条全解出来（实得 %d）" % 货.size())
	_判(int(状.get("remaining_seconds", -1)) == 21597 and int(状.get("discount_percent", -1)) == 100,
			"剩余秒 = 21597、折扣 = 100（实得 %s/%s）" % [状.get("remaining_seconds"), 状.get("discount_percent")])
	_判(npc响.is_empty(), "324 **不许**再动 `npc_shop_received`（实响 %d 次）" % npc响.size())
	var npc账: Dictionary = 后.get("authoritative_npc_shop") as Dictionary
	_判(npc账.size() == 1 and npc账.has("哨兵"),
			"324 **不许**再写 `authoritative_npc_shop`（实得 %s）—— 根因就在这：上一版把 NPC 货架整片盖掉了" % [
				npc账.keys()])
	for i in 货.size():
		var 项: Dictionary = 货[i] as Dictionary
		_判(String(项.get("id", "")) == 期号[i] and int(项.get("cash_price", -1)) == 期yb[i]
				and int(项.get("money_type", -1)) == 期币[i] and int(项.get("quantity", -1)) == [5, 1, 3, 2, 1][i],
				"第 %d 条 id/价/币种/数量 = %s/%s/%s/%s，实得 %s/%s/%s/%s" % [i,
					期号[i], 期yb[i], 期币[i], [5, 1, 3, 2, 1][i],
					项.get("id"), 项.get("cash_price"), 项.get("money_type"), 项.get("quantity")])
	_判(bool((货[2] as Dictionary).get("purchased", false))
			and not bool((货[0] as Dictionary).get("purchased", true)),
			"hasBought 解成布尔：第 3 条买过、第 1 条没买")
	_判(int((货[0] as Dictionary).get("price", -1)) == 200000,
			"`meso` 那一段原样进档（页上显示的是 `yb`，见 §④）")
	# 空货架那一条服务端发 `-`（`fake_flash_server.py:55607-55611`）
	后.set("authoritative_mystery_shop", {})
	_喂("324:21600:-:100")
	var 空: Dictionary = 后.get("authoritative_mystery_shop") as Dictionary
	_判((空.get("items", []) as Array).is_empty() and int(空.get("remaining_seconds", -1)) == 21600,
			"空货架 `-` ⇒ 零条、剩余秒照收（实得 %s 条 / %s 秒）" % [
				(空.get("items", []) as Array).size(), 空.get("remaining_seconds")])
	# 半条（少一段）⇒ 整条丢，不许留半张货架
	后.set("authoritative_mystery_shop", {})
	_喂("324:60:10000001&5&100&0&200000&0")
	_判((后.get("authoritative_mystery_shop") as Dictionary).is_empty(),
			"三段以下的半条 ⇒ 整条丢（实得 %s）" % [(后.get("authoritative_mystery_shop") as Dictionary).keys()])
	# 某一条少一列 ⇒ **只丢那一条**，其余照收（不许拿残列凑出一条假货）
	后.set("authoritative_mystery_shop", {})
	_喂(帧.replace("2010010&1&50&1&0&0", "2010010&1&50&1&0"))
	var 残: Array = (后.get("authoritative_mystery_shop") as Dictionary).get("items", []) as Array
	_判(残.size() == 4 and String((残[0] as Dictionary).get("id", "")) == "10000001",
			"缺列的那一条被跳过、剩下 4 条照收（实得 %d 条，首条 %s）" % [残.size(),
				(残[0] as Dictionary).get("id") if 残.size() > 0 else "无"])

	# ── ② 消费者：那一帧到本端 ⇒ 窗自己开 ─────────────────────────────────────
	后.set("authoritative_mystery_shop", {})
	_喂(帧)
	for i in 3:
		await process_frame
	var 窗: Node = 管理._窗口们.get("神秘商店")
	if _未完就退(窗, "神秘商店窗"):
		return
	_判(_开着(窗), "喂 324 那帧 ⇒ 神秘商店窗自己开出来了（`窗口管理._on_mystery_shop` 接对了）")
	var 包: Node = 管理._窗口们.get("背包")
	_判(包 != null and _开着(包), "背包被一起叫出来（原版 `centerTwoWindow(MYSTERY_WINDOW, ITEM_WINDOW2_F)`）")
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	var 包窗: Control = null
	if 包 != null:
		包窗 = 包.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 != null and 包窗 != null:
		# 2026-10-31：背包 556 高 ⇒ 主窗按自己高度居中、背包夹进 560 屏内（y = 4）、顶边不再平齐
		# （有意偏离，见 `窗口管理.成对摆位`）。offset 相对视口中心：主 = floor((560-394)/2) - 280、包 = 4 - 280。
		_判(absf(主窗.offset_top - (floorf((560.0 - 394.0) * 0.5) - 280.0)) < 0.51
				and absf(包窗.offset_top - (4.0 - 280.0)) < 0.51,
				"主窗按自己高度居中、背包夹进屏内（实得 %.1f / %.1f）" % [主窗.offset_top, 包窗.offset_top])
		_判(absf(包窗.offset_left - (主窗.offset_right + 1.0)) < 0.51,
				"背包左沿 = 神秘右沿 + 1px（实得 %.1f / %.1f）" % [主窗.offset_right, 包窗.offset_left])
	else:
		_判(false, "两窗的 `遮罩/主窗口` 拿不到 ⇒ 成对摆位无从判")
	var 页 := _找页(窗, "原版神秘商店内容")
	if _未完就退(页, "页本体"):
		return

	# ── ③ 逐件矩形 ─────────────────────────────────────────────────────────────
	_判(absf(页.size.x - 275.0) < 0.51 and absf(页.size.y - 365.0) < 0.51,
			"页 = 275×365（整框 394 − 标题 29），实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 窗件:
		var 件: Control = 页.get_node_or_null(名) as Control
		_判(件 != null and _近(_矩形(件), 窗件[名]),
				"%s = (%s)，实得 (%s)" % [名, 窗件[名], _矩形(件) if 件 != null else "没建"])
	var 底 := 页.get_node_or_null("内容底") as NinePatchRect
	_判(底 != null and 底.patch_margin_left == 11 and 底.patch_margin_right == 10
			and 底.patch_margin_top == 10 and 底.patch_margin_bottom == 11,
			"内容底（`MYellow_background`）九宫格边距**生效** = 11/10/10/11（实得 %s）" % (
				"%d/%d/%d/%d" % [底.patch_margin_left, 底.patch_margin_right,
					底.patch_margin_top, 底.patch_margin_bottom] if 底 != null else "没建"))
	var 板 := 页.get_node_or_null("大底板") as NinePatchRect
	_判(板 != null and 板.patch_margin_left == 8 and 板.patch_margin_right == 7
			and 板.patch_margin_top == 7 and 板.patch_margin_bottom == 7,
			"大底板（`MPane_background`）九宫格边距**生效** = 8/7/7/7（实得 %s）" % (
				"%d/%d/%d/%d" % [板.patch_margin_left, 板.patch_margin_right,
					板.patch_margin_top, 板.patch_margin_bottom] if 板 != null else "没建"))
	_判((页.get_node("刷新钮") as Button).text == "刷新",
			"钮文字 = DEFFOR_DESINATION_REFURBISH，实得「%s」" % (页.get_node("刷新钮") as Button).text)
	## 十二格原点：`MysteryWindow.as:73-74` x = `c*120 + pane.x + 5` ⇒ 18 / 138；
	## y(外框) = `r*(50+1) + pane.y + 5` ⇒ 48 + 51r ⇒ 页 y = 19 + 51r。**第一版量成 13 起步过。**
	for 序 in 12:
		var 格子: Control = 页.get_node_or_null("格%d" % 序) as Control
		var 期 := [18.0 + 120.0 * float(序 % 2), 19.0 + 51.0 * float(int(序 / 2.0)), 120.0, 50.0]
		_判(格子 != null and _近(_矩形(格子), 期),
				"格%d = (%s)，实得 (%s)" % [序, 期, _矩形(格子) if 格子 != null else "没建"])
	## 格内十件只量三格（首行两枚 + 最后一枚）：十二格是同一份烘出来的，逐格量 120 条只是刷数。
	for 序 in [0, 1, 11]:
		var 格子 := 页.get_node("格%d" % 序) as Control
		for 名 in 格内件:
			var 件: Control = 格子.get_node_or_null(名) as Control
			_判(件 != null and _近(_矩形(件), 格内件[名]),
					"格%d/%s = (%s)，实得 (%s)" % [序, 名, 格内件[名],
						_矩形(件) if 件 != null else "没建"])

	# ── ④ 十二格只填前五条 ────────────────────────────────────────────────────
	for 序 in 5:
		var 格子 := 页.get_node("格%d" % 序) as Control
		_判((格子.get_node("名称") as Label).text == 期名[序],
				"格%d 名称 = 「%s」，实得「%s」" % [序, 期名[序], (格子.get_node("名称") as Label).text])
		_判((格子.get_node("价格") as Label).text == 期价[序],
				"格%d 价格 = 「%s」（显示 `yb`、不是 `meso`），实得「%s」" % [序, 期价[序],
					(格子.get_node("价格") as Label).text])
		_判((格子.get_node("物品格/图标") as TextureRect).visible
				and (格子.get_node("物品格/图标") as TextureRect).texture != null,
				"格%d 图标挂上了" % 序)
		var 元 := (格子.get_node("元宝图") as CanvasItem).visible
		var 券 := (格子.get_node("券图") as CanvasItem).visible
		var 双 := (格子.get_node("双币") as CanvasItem).visible
		_判((期币[序] == 0 and 元 and not 券 and not 双) or (期币[序] == 1 and 券 and not 元 and not 双)
				or (期币[序] == 2 and 双 and not 元 and not 券),
				"格%d 币种 %d ⇒ 三选一显示（实得 元宝=%s 券=%s 双=%s）" % [序, 期币[序], 元, 券, 双])
	_判((页.get_node("格2/价格") as Label).get_theme_color("font_color") == Color(0, 1, 0),
			"已购买那格染 `UI_GREEN`（`setSelled:91`），实得 %s" % (
				(页.get_node("格2/价格") as Label).get_theme_color("font_color")))
	_判((页.get_node("格0/价格") as Label).get_theme_color("font_color") == Color(1, 1, 1),
			"没买过的那格是 `UI_WHITE`（`setData:115` 每轮复位 ⇒ 颜色不许粘）")
	for 序 in range(5, 12):
		var 格子 := 页.get_node("格%d" % 序) as Control
		_判((格子.get_node("名称") as Label).text == "" and (格子.get_node("价格") as Label).text == ""
				and not (格子.get_node("物品格/图标") as CanvasItem).visible
				and not (格子.get_node("元宝图") as CanvasItem).visible
				and not (格子.get_node("券图") as CanvasItem).visible
				and not (格子.get_node("双币") as CanvasItem).visible,
				"第 6..12 格**空着不冒充**（原版压根没对它们 `setData`）")
	_判((页.get_node("花费") as RichTextLabel).get_parsed_text().contains("50"),
			"花费那句填的是 `refMoney` = 50（实得「%s」）" % (页.get_node("花费") as RichTextLabel).get_parsed_text())

	# ── ⑤⑥⑦⑧ 出帧这半边换假后端 ─────────────────────────────────────────────
	var 假 := 假后.new()
	假.authoritative_mystery_shop = 状
	root.add_child(假)
	窗.set("_backend", 假)
	var 计: Dictionary = 会.get("player_stats")
	计["cash"] = 5000
	计["cash_bind"] = 5000

	# ⑤ 够 ⇒ 弹确认，点确定才发 7（载荷 = **item_id**、不是格子下标）
	# ⚠ 这枚「取消」落在屏幕正中，而**成对摆位时背包那扇窗的矩形也盖住同一个点** ⇒
	#   它顺带钉住 `窗口管理._input` 的例外：模态弹罩着的时候一票都不许提。
	#   提了就把弹画压到背包之下、这一记点实际打在背包的一格上（取消/确定双双点不动）。
	await _点在(页.get_node("格0/物品格") as Button)
	var 弹 := _找弹(窗, "message")
	_判(弹 != null and (弹.get_node("主体/正文") as RichTextLabel).get_parsed_text()
			.contains("该物品100元宝,你确定购买吗？"),
			"点一格 ⇒ 弹 MYSTERY_SURE_BUY_YB_TIP（实得「%s」）" % (
				(弹.get_node("主体/正文") as RichTextLabel).get_parsed_text() if 弹 != null else "没弹"))
	await _点弹钮(弹, "取消")
	for i in 2:
		await process_frame
	_判(假.发过.is_empty(), "点「取消」一帧都不发（实发 %s）" % str(假.发过))
	_判(_找弹(窗, "message") == null, "点取消后确认弹收掉了")
	_判(int(_层号(管理).get("神秘商店", -1)) > int(_层号(管理).get("背包", 9999)),
			"点弹上的钮**没把背包提起来**（层号实得 %s）—— 原版弹挂 `PopUpMananger.stage`，点它不动窗层级"
			% str(_层号(管理)))
	await _点在(页.get_node("格0/物品格") as Button)
	弹 = _找弹(窗, "message")
	await _点弹钮(弹, "确定")
	for i in 4:
		await process_frame
	_判(假.发过.size() == 1 and 假.发过[0] == ["买", 10000001],
			"点确定 ⇒ 发 `7:<item_id=10000001>`（实发 %s）" % str(假.发过))
	# 点券那一格走另一句文案
	假.发过.clear()
	await _点在(页.get_node("格1/物品格") as Button)
	弹 = _找弹(窗, "message")
	_判(弹 != null and (弹.get_node("主体/正文") as RichTextLabel).get_parsed_text()
			.contains("该物品50点券,你确定购买吗？"),
			"点券那格弹的是 DQ 那句（实得「%s」）" % (
				(弹.get_node("主体/正文") as RichTextLabel).get_parsed_text() if 弹 != null else "没弹"))
	await _点弹钮(弹, "确定")
	for i in 4:
		await process_frame
	_判(假.发过 == [["买", 2010010]], "点券那格发的也是 item_id（实发 %s）" % str(假.发过))

	# ⑥ 两支 `<=`：余额**正好等于价** ⇒ 拒绝、连弹都不出
	假.发过.clear()
	计["cash"] = 100
	await _点在(页.get_node("格0/物品格") as Button)
	_判(假.发过.is_empty() and _找弹(窗, "message") == null,
			"元宝正好 100、价也 100 ⇒ 判的是 `<=` 不是 `<`：不发也不弹（实发 %s）" % str(假.发过))
	_判((窗.get("_status") as Label).text == "很抱歉，你的元宝不足！",
			"元宝不足那句 = SORRY_DEFICIENCY_COIN（实得「%s」）" % (窗.get("_status") as Label).text)
	计["cash_bind"] = 50
	await _点在(页.get_node("格1/物品格") as Button)
	_判(假.发过.is_empty() and _找弹(窗, "message") == null,
			"点券正好 50 ⇒ 同样拒（实发 %s）" % str(假.发过))
	_判((窗.get("_status") as Label).text == "很抱歉，你的点券不够",
			"点券不足那句 = RIHUAN_DIANQUAN_BUGOU（实得「%s」）" % (窗.get("_status") as Label).text)

	# ⑦ moneyType==2 ⇒ 原版 #1009 那条呆账：`buyItem` 只判 0/1，`_loc4_` 留 null 进
	#    `CN.replaceString` ⇒ 抛错 ⇒ 弹不出也发不出。这边照抄：什么都不许发生。
	计["cash"] = 5000
	计["cash_bind"] = 5000
	await _点在(页.get_node("格4/物品格") as Button)
	_判(假.发过.is_empty() and _找弹(窗, "message") == null,
			"双币那一档**什么都不发生**（原版的呆账，照抄不修；实发 %s）" % str(假.发过))
	# 空格子：点下去也不许有事（`MysteryCell.buyItemHandler:82` 的 `data == null` 那层闸）
	await _点在(页.get_node("格7/物品格") as Button)
	_判(假.发过.is_empty() and _找弹(窗, "message") == null, "空格子点一下 ⇒ 不发也不弹")

	# ⑧ 刷新
	窗脚本.再弹刷新确认 = true
	计["cash"] = 50
	await _点在(页.get_node("刷新钮") as Button)
	_判(假.发过.is_empty() and _找弹(窗, "checkbox") == null,
			"元宝正好 50（= `refMoney`）⇒ 不发也不弹（`refItemHandler:142` 判的是 `<=`）")
	_判((窗.get("_status") as Label).text == "很抱歉，你的元宝不足！",
			"刷新余额不足走同一句（实得「%s」）" % (窗.get("_status") as Label).text)
	计["cash"] = 51
	await _点在(页.get_node("刷新钮") as Button)
	var 勾弹 := _找弹(窗, "checkbox")
	_判(勾弹 != null, "元宝够 ⇒ 先弹带勾选的确认（MYSTERY_REF_ITEM_TIP）")
	_判(勾弹 != null and (勾弹.get_node("主体/勾选") as CheckBox).text == "今日不再提示",
			"勾选文案 = YIZHI_ZHAO_HUAN_NPC_DILOG_CHECK_TEXT（实得「%s」）" % (
				(勾弹.get_node("主体/勾选") as CheckBox).text if 勾弹 != null else "没弹"))
	_判(勾弹 != null and not (勾弹.get_node("主体/勾选") as CheckBox).button_pressed,
			"勾选初值 = false（`showCheckBoxDialog` 第二参传的 false）")
	await _点弹钮(勾弹, "取消")
	for i in 2:
		await process_frame
	_判(假.发过.is_empty() and 窗脚本.再弹刷新确认,
			"点取消 ⇒ 不发、且**不改** `showSureRefWindow`（`sureRefItem:74-77` 那支 return）")
	await _点在(页.get_node("刷新钮") as Button)
	勾弹 = _找弹(窗, "checkbox")
	_判(勾弹 != null, "取消过一次 ⇒ 下次照样弹（标志没被改）")
	await _点弹钮(勾弹, "确定")
	for i in 4:
		await process_frame
	_判(假.发过 == [["刷新"]], "不勾就确定 ⇒ 只发 8（NPC_SHOP 动作 8，不带载荷）")
	_判(窗脚本.再弹刷新确认, "没勾 ⇒ `showSureRefWindow = !false = true`（`:78`）")
	await _点在(页.get_node("刷新钮") as Button)
	for i in 4:
		await process_frame
	# ⚠ 这一下**不该多发**：`refItem:52-54` 标志还 true ⇒ 只把确认弹再摆一次，
	#    请求要等 `sureRefItem` 里点确定才走（`发过` 该停在上面那一笔）。
	_判(假.发过 == [["刷新"]] and _找弹(窗, "checkbox") != null,
			"标志还是 true ⇒ 这一次照样**只弹不发**（实发 %s）" % str(假.发过))
	# 这一回**勾上**再确定 ⇒ 之后不再弹
	await _点弹钮(_找弹(窗, "checkbox"), "勾选")
	勾弹 = _找弹(窗, "checkbox")
	_判(勾弹 != null and (勾弹.get_node("主体/勾选") as CheckBox).button_pressed,
			"真鼠标点一下 ⇒ 勾选被置上（不然「下次不弹」那条腿是自证）")
	await _点弹钮(勾弹, "确定")
	for i in 4:
		await process_frame
	_判(not 窗脚本.再弹刷新确认, "勾了「今日不再提示」⇒ `showSureRefWindow = false`")
	假.发过.clear()
	await _点在(页.get_node("刷新钮") as Button)
	for i in 4:
		await process_frame
	_判(假.发过 == [["刷新"]] and _找弹(窗, "checkbox") == null,
			"再点 ⇒ 直接发 8、不再弹（`refItem:56-59` 那一支）")
	窗脚本.再弹刷新确认 = true		# 脚本级静态量：别把这条会话状态漏给下一腿/下一扇门
	假.queue_free()
	窗.set("_backend", 后)		# 出帧腿跑完，换回真后端（下面的重灌/秒表腿读的是真账）

	# ── ⑨ 重灌：格换了、表没被重起、文案不被立刻重绘 ──────────────────────────
	var 表: Timer = 窗.get_node_or_null(窗脚本.秒表名) as Timer
	_判(表 != null and absf(表.wait_time - 1.0) < 0.001,
			"秒表挂在**宿主**上、`wait_time = 1.0`（原版 `new Timer(1000)`）")
	(页.get_node("倒计时") as Label).text = "哨兵"
	窗.set("_神秘商店走", {"剩": 9999, "文": "哨兵", "跑完": false})
	_喂("324:1234:3000001&3&20&0&0&0@10000001&5&100&0&200000&0:100")
	# ⚠ 开窗 → `open_page` → `_render_page` 一路是**同步**的 ⇒ 这里一个帧都不等，
	#   免得那一秒一拍的表在等待里把 `剩` 减掉一格，把判据糊成 1233/1234 那种碰运气。
	var 页新 := _找页(窗, "原版神秘商店内容")
	_判(页新 != null, "重灌后页还在")
	if 页新 != null:
		_判((页新.get_node("格0/名称") as Label).text == "拉面（小）",
				"换货换到格上了（第 0 格现在是拉面，实得「%s」）" % (页新.get_node("格0/名称") as Label).text)
		_判((页新.get_node("格1/价格") as Label).text == "100", "第 1 格跟着换成 100")
		_判((页新.get_node("格5/名称") as Label).text == "", "第 6 格跟着清空（不许留上一帧的货）")
		_判((页新.get_node("倒计时") as Label).text == "哨兵",
				"重灌**不许**把文案立刻改掉（`set passTime:96-103` 只换数字、不出字）—— 实得「%s」" % (
					页新.get_node("倒计时") as Label).text)
	var 走新: Dictionary = 窗.get("_神秘商店走")
	_判(int(走新.get("剩", 0)) == 1234, "`剩` 跟最新那一帧（实得 %s）" % 走新.get("剩"))
	var 表新: Timer = 窗.get_node_or_null(窗脚本.秒表名) as Timer
	_判(表新 != null and 表新 == 表, "秒表**没被重建**（同一实例）")
	_判(页新 != 页,
			"如实记一笔：本工程页确实每次重建（原版窗已存在时不换实例）⇒ 守的是那张表与那本文案，不是页实例")

	# ── ⑩ 秒表走完（真秒驱动）────────────────────────────────────────────────
	窗.call("close")
	var 走: Dictionary = 窗.get("_神秘商店走")
	_判(走 is Dictionary and 走.is_empty(),
			"关窗 = 原版 `destroy()`：秒表状态整本清掉（实得 %s）" % [走.keys()])
	_喂("324:2:10000001&5&100&0&200000&0:100")
	页 = _找页(窗, "原版神秘商店内容")
	var 秒表 := 页.get_node("倒计时") as Label
	_判(秒表.text == "刷新倒计时：00:00:00",
			"开窗头一秒读的是 `initUI`（`CommonPassTimer:137`）那句全 00，真数要等第一次 tick；实得「%s」" % 秒表.text)
	await _等秒(1.2)
	_判(秒表.text == "刷新倒计时：00:00:01", "第一次 tick ⇒ 剩 1 秒，实得「%s」" % 秒表.text)
	await _等秒(1.2)
	_判(秒表.text == "刷新倒计时：00:00:00", "走到 0 那一秒文案还停在 00:00:00（00 站整一秒），实得「%s」" % 秒表.text)
	await _等秒(1.2)
	_判(秒表.text == "已刷新",
			"减到 0 之后的**下一次** tick 才停表出「已刷新」（`daoJiShi:83-87` 先判后减），实得「%s」" % 秒表.text)
	表 = 窗.get_node_or_null(窗脚本.秒表名) as Timer
	_判(表 != null and 表.is_stopped(), "出「已刷新」时表已经 stop")
	_喂("324:21600:10000001&5&100&0&200000&0:100")
	页 = _找页(窗, "原版神秘商店内容")
	_判((页.get_node("倒计时") as Label).text == "已刷新",
			"迟到的一帧不许把「已刷新」冲回数字（原版那扇没再 `start()`），实得「%s」" % (
				页.get_node("倒计时") as Label).text)
	var 表2: Timer = 窗.get_node_or_null(窗脚本.秒表名) as Timer
	_判(表2 == 表 and 表2 != null and 表2.is_stopped(), "也不许把表叫活")
	_判(int((窗.get("_神秘商店走") as Dictionary).get("剩", 0)) == 21600,
			"`剩` 那一格照样跟着最新帧走（只是没人再数它）")

	# ── ⑪ 小时从 3600 里除 ────────────────────────────────────────────────────
	窗.call("close")
	_喂("324:21600:10000001&5&100&0&200000&0:100")
	页 = _找页(窗, "原版神秘商店内容")
	await _等秒(1.2)
	_判((页.get_node("倒计时") as Label).text == "刷新倒计时：05:59:59",
			"21600 过一拍 ⇒ `05:59:59`（`_passTime / 3600`；写成 60 进制会是 6:00:00 之流），实得「%s」" % (
				页.get_node("倒计时") as Label).text)

	# ── ⑫ 尺寸表 + 伴随背包 + 居中弹 ──────────────────────────────────────────
	var 表文: Dictionary = JSON.parse_string(去BOM(FileAccess.get_file_as_string(尺寸表路径))) as Dictionary
	_判(表文.has("神秘商店") and int(表文["神秘商店"]["宽"]) == 275 and int(表文["神秘商店"]["高"]) == 394
			and bool(表文["神秘商店"]["整框"]) and bool(表文["神秘商店"]["内容底"])
			and String(表文["神秘商店"]["标题"]) == "神秘商店",
			"尺寸表「神秘商店」= 275×394、整框、内容底、标题「神秘商店」")
	_判(管理脚本.伴随背包.has("神秘商店"), "`伴随背包` 登记了神秘商店（§④-3 那对）")
	_判(not 管理脚本.居中弹.has("神秘商店"), "神秘商店**不进** `居中弹`（原版它是可拖的普通窗）")
	跑完了 = true
	print("神秘商店窗离线门：通过 %d，红 %d" % [通过, 失败])


static func 去BOM(文: String) -> String:
	return 文.trim_prefix("﻿")

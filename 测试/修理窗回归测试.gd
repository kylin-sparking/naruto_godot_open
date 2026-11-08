extends SceneTree

## 装备修理窗回归门（2026-10-17，巡检 #19）。
##
## 病根：商店页那枚「修理」`mendBtn` **不弹窗、直接发包**，而且发的是
## `request_npc_shop_recharge(第一件受损装备的格位)` = `NPC_SHOP` 子命令 **2** ——
## `PacketCreator.as:576 getNPCShopRechargeItemRequestPacket` 是**商品补货**
## （`UI.as:2241 onShopRechargeItems`），跟修理没关系（旧的状态行文案 `1:"修理成功"`
## 也是同一条误会的产物，`ShopConfirmInfo.RECHARGE_SUCCESS` 是补货成功）。
##
## 原版真值：`ShopWindow2.as:153-156 onClickMendBtn` → `UIMain2.as:3952 showMendEtcWindow()`
## → `MendEtcWindow`（295×250，`setData():65-84` 对**身上每一件**装备累加
##   `(maxEndure - endure) × getEtcXiuliPrice(stage)[0|1]`，
##   `StringTool.as:510-518` 那一对 = `naijiu.repair.stageN.normalPrice / specialPrice`）
## → `onClickXiuliBtn:44-63`（那一档合计为 0 ⇒ 只 `addNotice(CN.BUXUYAO_XIULI)`，**不发也不关窗**）
## → `UI.as:1687` → `Client.requestRepairEquip(repairType)`
## → `ItemChangeProcessor.as:249-255` = `ITEM_CHANGE(1040) 7 + writeInt(修理方式)`。
## **一个格位都不带** ⇒ 一条请求修身上**全部**装备。
##
## 盯八件：
##   ① 点「修理」⇒ **弹窗**、且**一发都不发**（旧写法正好是反的）；
##   ② 版式 295×250、标题与四段文案逐字对语言表；
##   ③ 两栏费用是**真值**：小太刀(stage1) 缺 10 + 鬼丸刀(stage3) 缺 5 ⇒ 70 / 210
##      （`1×10+12×5` / `3×10+36×5`，价出自 `数据/装备打造.json`）；
##   ④ 玉链 `max_endure = -1` **不进账**（只有它"破"着 ⇒ 两栏都是 0）；
##   ⑤ 点「普通修理」⇒ 只发一条 `request_repair_equip(0)`、窗关、遮罩撤；
##   ⑥ 重开点「特殊修理」⇒ `request_repair_equip(1)`（两次合计仍是两条，重开不重复接线）；
##   ⑦ 满耐久 ⇒ 合计 0 ⇒ 点普通**不发、窗还开着**、状态行给「不需要修理」；
##   ⑧ 离线（`in_game=false`）⇒ 不发、不假装成功。
##
## ⚠ 三条口径：
##   · 开场钉 `root.size`（无头视口 64×64，居中算式读它）；
##   · 本门走 `call_deferred` ⇒ 宿主 `_ready` 才跑得起来（§3.124.4）；
##   · 假后端**必须带 `in_game`**，并且**同时**装着 `request_npc_shop_recharge`：
##     少了这个，真代码退回旧写法时是 `Invalid call` 崩掉（"崩而不红"，§3.113），
##     有了它本门才会红在第 ①/⑤ 条上。
##
## 运行：`Godot --headless --path . --script res://测试/修理窗回归测试.gd`
##
## 反向对照（全绿一遍后逐条改坏，每条都**必须红**，改完 `cmp` 回原样）：
##   · R1 `_成交修理` 退回 `request_npc_shop_recharge(类型)` ⇒ 红在 ⑤⑥（"recharge" 被抓出来，
##     没崩成 Invalid call —— 这就是假后端要同时装着那条方法的原因）；
##   · R2 `_修理价目` 的特殊栏改用 normalPrice ⇒ 红在 ③（两栏都 70）；
##   · R3 删掉 `_点修理` 的合计 0 闸门 ⇒ 红在 ⑦（发出去了、窗关了、状态行还报"已发送"）；
##   · R4 特殊按钮绑到 `类型普通` ⇒ 红在 ⑥（两条都是 0）；
##   · R5 `打开()` 之后把窗 `visible = false` ⇒ 红在 ①/⑤/⑦ 三条（证明这些腿不是空判）。

const 窗场景 := "res://场景/界面/功能窗口.tscn"

const 小太刀 := "01010013"	# stage1：normalPrice 1 / specialPrice 3
const 鬼丸刀 := "01010033"	# stage3：normalPrice 12 / specialPrice 36
const 玉链 := "01200010"	# max_endure -1 ⇒ 永远不进账


## 只记参数、不发包的假后端。两条都装着：旧写法（补货包）也要能被抓出来。
class 记包后端 extends Node:
	var 记录: Array = []
	var in_game := true

	func request_repair_equip(方式: int) -> bool:
		记录.append(["repair", 方式])
		return true

	func request_npc_shop_recharge(格位: int) -> bool:
		记录.append(["recharge", 格位])
		return true

var 红数 := 0
var _秒 := 0.0
var _会话: Dictionary = {}


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("修理窗回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	call_deferred("_跑")


## 往会话镜像里塞"身上穿了什么"（`equipped_items` 的键就是位置 int，同 2051 那份）。
func _穿(会话: Variant, 位置: int, 物品id: String, 当前: int, 上限: int) -> void:
	(会话.equipped_items as Dictionary)[位置] = {
		"id": 物品id, "endure": 当前, "max_endure": 上限, "slot_index": 位置,
	}


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = (load(窗场景) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame
	场.call("open_page", "NPC商店")
	await process_frame

	var 遮罩层 := 场.get("_overlay") as Control
	var 页 := 场.get("_content") as Control
	var 会话: Variant = 场.get("_session")
	if 遮罩层 == null or 页 == null or 会话 == null:
		_记(false, "依赖不齐：遮罩层=%s 商店页=%s 会话=%s" % [遮罩层, 页, 会话])
		_finish()
		return
	var 按钮 := 页.find_child("修理", true, false) as Button
	if 按钮 == null:
		_记(false, "商店页没有「修理」按钮（`ShopWindow2.as` 的 mendBtn）")
		_finish()
		return

	var 记包 := 记包后端.new()
	记包.name = "记包后端"
	场.set("_backend", 记包)
	_穿(会话, -1, 小太刀, 140, 150)		# 缺 10
	_穿(会话, -3, 鬼丸刀, 205, 210)		# 缺 5
	_穿(会话, -20, 玉链, 0, -1)			# 没耐久这回事

	# ① 点按钮 ⇒ 弹窗、一发都不发
	按钮.pressed.emit()
	await process_frame
	var 弹窗 := _取窗(遮罩层)
	_记(弹窗 != null, "点「修理」没弹出 MendEtcWindow（原版先弹窗报价，不是直接发包）")
	if 弹窗 == null:
		场.set("_backend", null)
		记包.free()
		_finish()
		return
	_记(弹窗.visible, "修理窗弹出来了但 visible=false")
	_记(记包.记录.is_empty(), "点按钮就直接发包了（实测 %s）—— 原版这一段只弹窗" % str(记包.记录))

	# ② 版式与文案
	_记(弹窗.size == Vector2(295, 250), "窗尺寸 %s ≠ 295x250（`super(295,250)`）" % str(弹窗.size))
	_记((弹窗.get_node("标题") as Label).text == "装备修理",
			"标题 ≠ `MENDETC_WINDOW_TITLE`（:448「装备修理」）")
	var 说明 := 弹窗.get_node("说明") as RichTextLabel
	_记(说明.text.contains("我将修理你身上和宠物上的全部装备")
			and 说明.text.contains("有不需要现在修理的装备，请提前脱下"),
			"窗头文案缺句（`MENDETC_WINDOW_SAY` :599）")
	_记((弹窗.get_node("普通说明") as RichTextLabel).text.contains("减少装备的耐久度上限")
			and (弹窗.get_node("特殊说明") as RichTextLabel).text.contains("不会减少耐久度上限"),
			"普通/特殊两条说明缺句（:3245 / :1222 —— 这两条就是两档的差别）")
	_记((弹窗.get_node("修理方式") as Label).text == "请问你需要那种修理方式？",
			"「修理方式」那行没对 `XIULI_FANGSHI` :2807")
	_记((弹窗.get_node("普通按钮") as Button).text == "普通修理"
			and (弹窗.get_node("特殊按钮") as Button).text == "特殊修理",
			"两枚按钮文案没对 `POTONG_XIULI_BTN` :262 / `TESHU_XIULI_BTN` :457")
	var 挡 := 遮罩层.get_node_or_null("购买窗遮罩") as ColorRect
	_记(挡 != null and 挡.visible, "缺一整舞台遮罩")
	if 挡 != null:
		_记(挡.get_index() < 弹窗.get_index(), "遮罩该压在修理窗**下面**")

	# ③④ 两栏是真算出来的：70 / 210，玉链不进账
	var 普通栏 := 弹窗.get_node("普通数值") as Label
	var 特殊栏 := 弹窗.get_node("特殊数值") as Label
	_记(普通栏.text == "70",
			"普通合计 %s ≠ 70（10×normalPrice1 + 5×normalPrice12）" % 普通栏.text)
	_记(特殊栏.text == "210",
			"特殊合计 %s ≠ 210（10×specialPrice3 + 5×specialPrice36）" % 特殊栏.text)
	var 价: Array = 场.call("_修理价目")
	_记(int(价[0]) == 70 and int(价[1]) == 210,
			"`_修理价目()` 直接算的不是 [70,210]，实测 %s（玉链 max_endure=-1 必须不进账）" % str(价))

	# ⑤ 点普通 ⇒ 一条 `request_repair_equip(0)`、窗关、遮罩撤
	(弹窗.get_node("普通按钮") as Button).pressed.emit()
	await process_frame
	_记(记包.记录.size() == 1 and String(记包.记录[0][0]) == "repair" and int(记包.记录[0][1]) == 0,
			"点「普通修理」发的不是 request_repair_equip(0)，实测 %s" % str(记包.记录))
	_记(not 弹窗.visible, "点完普通修理窗还开着")
	_记(挡 != null and not 挡.visible, "关窗后整舞台遮罩没撤")

	# ⑥ 重开点特殊 ⇒ (1)；重开不重复接线（两次合计两条）
	按钮.pressed.emit()
	await process_frame
	(弹窗.get_node("特殊按钮") as Button).pressed.emit()
	await process_frame
	_记(记包.记录.size() == 2 and String(记包.记录[1][0]) == "repair" and int(记包.记录[1][1]) == 1,
			"点「特殊修理」发的不是 request_repair_equip(1)，实测 %s" % str(记包.记录))

	# ⑦ 满耐久 ⇒ 合计 0 ⇒ 不发、窗还开着、状态行给说法
	(会话.equipped_items as Dictionary).clear()
	_穿(会话, -1, 小太刀, 150, 150)
	_穿(会话, -20, 玉链, 0, -1)
	按钮.pressed.emit()
	await process_frame
	_记((弹窗.get_node("普通数值") as Label).text == "0"
			and (弹窗.get_node("特殊数值") as Label).text == "0",
			"装备都满耐久时两栏该是 0，实测 %s / %s"
			% [(弹窗.get_node("普通数值") as Label).text, (弹窗.get_node("特殊数值") as Label).text])
	(弹窗.get_node("普通按钮") as Button).pressed.emit()
	await process_frame
	_记(记包.记录.size() == 2, "不需要修理还是发出去了（原版 `int(text)==0` 就 return）")
	_记(弹窗.visible, "点了「不需要修理」那一下把窗关了（原版只 addNotice，不关窗）")
	var 状态 := 场.get("_status") as Label
	_记(状态 != null and 状态.text.contains("不需要修理"),
			"合计为 0 时没给说法（状态行实测 %s）" % (状态.text if 状态 != null else "<无 _status>"))
	(弹窗.get_node("关闭") as Button).pressed.emit()
	await process_frame

	# ⑧ 离线 ⇒ 不发、不假装成功
	var 离线 := 记包后端.new()
	离线.in_game = false
	场.set("_backend", 离线)
	_穿(会话, -1, 小太刀, 140, 150)
	按钮.pressed.emit()
	await process_frame
	(弹窗.get_node("普通按钮") as Button).pressed.emit()
	await process_frame
	_记(离线.记录.is_empty(), "离线（in_game=false）还把修理发出去了")
	_记(状态 != null and 状态.text.contains("服务端"),
			"离线点修理没给说法（状态行实测 %s）" % (状态.text if 状态 != null else "<无 _status>"))

	(会话.equipped_items as Dictionary).clear()
	场.set("_backend", null)
	记包.free()
	离线.free()
	_finish()


## 遮罩上那枚修理窗。按**前缀**找：叠了两枚时 Godot 会把后一枚改名 `@Control@N`。
func _取窗(遮罩层: Control) -> Control:
	for 子 in 遮罩层.get_children():
		if String(子.name).begins_with("修理窗"):
			return 子 as Control
	return null


func _finish() -> void:
	if 红数 == 0:
		print("修理窗回归测试：通过（点修理只弹窗不发包 / 295x250 版式与文案 / "
				+ "两栏按 naijiu.repair 真算 70:210 / 玉链不进账 / 普通发 7:0 特殊发 7:1 / "
				+ "合计 0 不发也不关窗 / 离线不假装）")
		quit(0)
	else:
		print("修理窗回归测试：失败 %d 项" % 红数)
		quit(1)

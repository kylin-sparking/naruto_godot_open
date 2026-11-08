extends SceneTree

## 装备修理**真实事务**回归门（2026-10-17 巡检 #19 的在线那一半）。
##
## 病根（离线门照不到的那一半）：商店页那枚「修理」发的是 `NPC_SHOP` 子命令 **2**
## —— `PacketCreator.as:576 getNPCShopRechargeItemRequestPacket` 是**商品补货**，一条装备都修不到。
## 真值在 `ItemChangeProcessor.requestRepairEquip:249-255`：`ITEM_CHANGE(1040) writeByte(7)
## + writeInt(repairType)`，后面那一个 int 是**修理方式**（0 普通 / 1 特殊），**不是格位**
## ⇒ 一条就把**身上全部**装备修好。夹具那一边原来把首字段当格位去查背包（`_forge_repair`），
## 既不分 0/1、也不算 `specialPrice`，所以"报文发对了"也照样修不到东西 —— 只有真服务端照得到。
##
## 四步矩阵（每步只动一个变量，红在哪一句就指得清是谁坏了）：
##
##   步 1  卸下 -4/-5 那两件破损件 ⇒ 让它们**带着破损留在背包**（给步 4 留料，顺带钉
##         "耐久是跟着实例走的，穿/卸不修理"）
##   步 2  **普通(0)** ⇒ 金币**恰好 -70** = `01010013` 缺 10 × stage1 `normalPrice 1`
##                     + `01030033` 缺 5 × stage3 `normalPrice 12`；-1/-3 耐久回满；
##                     **背包里那两件破损的不许被修**（服务端扫的是 `-199 <= slot < 0` 那份清单，
##                     与 `_send_equipped_info:17474-17486` 下发给客户端的同一个键）
##   步 3  身上已经没有破损件 ⇒ 再发一次 ⇒ 金币**一分不动**
##         （`MendEtcWindow.onClickXiuliBtn:44-63` 合计为 0 那一支：连包都不该起作用）
##   步 4  重新穿上 -4/-5 ⇒ **特殊(1)** ⇒ 金币**恰好 -360** = 8 × 36 + 2 × 36
##         （读的是 `specialPrice` 那一列；把它和普通列搞混 ⇒ 144，当场红）
##         已满耐久的 -1/-3 **不进账**（防"每件收一个底价"那种写法）
##
## ⚠ 种子：`--items` **整张换掉**默认背包，`--wear-damage` 负责把装备**穿上并扣掉耐久** ——
##   `--items` 发出来的是"满耐久躺在包里"，而修理算的是**身上**那一份，不预置就没有可修对象。
##   四件故意挑**四个不同的槽**（-1/-3/-4/-5，`definition.position`）：同族 `01010033` 和
##   `01010013` 都落在 -1，夹具会顶掉前一件 ⇒ "一次修全部"就没有第二件可数了。
##   前置不齐门自己会红并说清"是夹具没穿上/没扣耐久"，不许静默放行。
##
## 客户端那一头的**预览合计**（`功能窗口._修理价目` 读同一张 `naijiu.repair`）由离线门
## `测试/修理窗回归测试.gd` 钉；这条钉的是"服务端真收多少钱、真修哪几件"。
##
## 反向对照（2026-10-17 跑了五条，每条都红、跑完逐条 `cp` 还原并 `cmp` 核对字节）：见文件尾。
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 修理`

const 小太刀 := "01010013"	# stage1 / 槽 -1 / 上限 150 ⇒ 缺 10 ⇒ 普通 10×1
const 忍服 := "01030033"		# stage3 / 槽 -3 / 上限 210 ⇒ 缺 5 ⇒ 普通 5×12、特殊 5×36
const 甲件 := "01040033"		# stage3 / 槽 -4 / 上限 210 ⇒ 缺 8（留给步 4）
const 乙件 := "01050033"		# stage3 / 槽 -5 / 上限 210 ⇒ 缺 2（留给步 4）

const 普通合计 := 10 * 1 + 5 * 12		# 70
const 特殊合计 := 8 * 36 + 2 * 36		# 360

var 判数 := 0
var _失败: Array[String] = []
var _原端口 := -1
var 会话引用: Node = null


func _查(成立: bool, 说明: String) -> void:
	判数 += 1
	if not 成立:
		_失败.append(说明)


## 前置塌了（连不上 / 夹具没喂料）就当场停：后面每一步都建立在它上面，
## 继续跑只会把同一个原因刷成十条红。
func _停(话: String) -> void:
	_还原端口()
	printerr("汇：判 %d 条 / 红 %d 条（修理真实事务：中断）" % [判数, _失败.size() + 1])
	for 条 in _失败:
		printerr("  红 - " + 条)
	printerr("  红 - " + 话)
	quit(1)


func _等待(条件: Callable, 毫秒: int = 6000) -> bool:
	for _轮 in range(毫秒 / 50):
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


## 身上那一格：`[当前, 上限]`；格子空着返回 `[-1, -1]`。
func _耐久(后端: Node, 槽: int) -> Array:
	var 条: Variant = (后端.authoritative_equipment as Dictionary).get(槽, {})
	if not (条 is Dictionary) or (条 as Dictionary).is_empty():
		return [-1, -1]
	return [int((条 as Dictionary).get("endure", -1)), int((条 as Dictionary).get("max_endure", -1))]


## 背包里那一件：`[当前, 上限]`；没有这件返回 `[-1, -1]`。
func _背包耐久(后端: Node, 物品号: String) -> Array:
	for 条 in (后端.authoritative_inventory as Array):
		if int(String((条 as Dictionary).get("id", "0"))) == int(物品号):
			return [int((条 as Dictionary).get("endure", -1)),
					int((条 as Dictionary).get("max_endure", -1))]
	return [-1, -1]


func _金币(后端: Node) -> int:
	return int(后端.authoritative_stats.get("gold", -1))


func _满了(后端: Node, 槽: int) -> bool:
	var 值 := _耐久(后端, 槽)
	return 值[0] >= 0 and 值[0] == 值[1]


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_停("缺单例（BackendConnection / GameSession）")
		return
	# ⚠️ 客户端只认 `game_settings.backend_port`（缺省 18684 会连到用户自己那台），
	#    夹具只把端口号放进环境变量 ⇒ 必须自己写回去，否则测的不是这台夹具（§3.180 口径）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18712
	会话引用 = 会话
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	后端.call("sync_character")
	if not await _等待(
			func(): return bool(后端.get("in_game")) and (后端.authoritative_inventory as Array).size() > 0,
			15000):
		_停("进不了真实后端：%s - %s" % [后端.get("status"), 后端.get("detail")])
		return
	if not await _等待(func(): return _金币(后端) >= 0, 3000):
		_停("服务端没把金币推下来（这条门全靠金币差额认账）")
		return

	# ── 前置：夹具到底"穿上并扣了耐久"没有 ──
	# 镜像里的耐久是 2051 `EQUIPPED_INFO` 那份；扣不到就是 `--wear-damage` 没生效或 `--items` 漏了这件。
	var 期望 := {1: [140, 150], 3: [205, 210], 4: [202, 210], 5: [208, 210]}
	for 号 in [1, 3, 4, 5]:
		var 槽: int = -号
		if not await _等待(func() -> bool: return _耐久(后端, 槽) == 期望[号], 8000):
			_停(("槽 %d 不是夹具该造的 %s（实得 %s）—— 查 `--wear-damage` 与 `--items`，"
					+ "别当成客户端坏了") % [槽, str(期望[号]), str(_耐久(后端, 槽))])
			return

	# ── 步 1：卸下 -4/-5 两件破损件 ⇒ 带着破损回到背包 ──
	# ⚠️ **一件等一件**：`unequip_item` 的空格是客户端当场从镜像里挑的，两发连着发会挑到
	#    **同一个空格** ⇒ 服务端第二发看成"和那件甲交换"，而甲的位置是 -4 不是 -5
	#    （`_can_equip:47914-47921`）⇒ 整条**静默拒掉**，实测 10-17 就是乙件根本没下来。
	for 号 in [4, 5]:
		var 槽: int = -号
		var 件号 := (甲件 if 号 == 4 else 乙件)
		var 应剩: Array = ([202, 210] if 号 == 4 else [208, 210])
		会话.call("unequip_item", 槽)
		if not await _等待(func(): return _背包耐久(后端, 件号) == 应剩 and not (后端.authoritative_equipment as Dictionary).has(槽)):
			_停("步 1：卸下槽 %d 的 %s 后，背包里不是 %s（实得 %s）、身上还剩 %s"
					% [槽, 件号, str(应剩), str(_背包耐久(后端, 件号)), str(_耐久(后端, 槽))])
			return

	# ── 步 2：普通(0) 修**身上**那两件 ⇒ 恰好 70，且不动背包里的破损件 ──
	var 金一 := _金币(后端)
	if not bool(后端.call("request_repair_equip", 0)):
		_停("步 2：普通修理的请求没发出去（客户端这一头就没走）")
		return
	if not await _等待(func(): return _满了(后端, -1) and _满了(后端, -3) and _金币(后端) == 金一 - 普通合计):
		_查(_满了(后端, -1), "步 2：普通修理没把槽 -1（01010013）修满，实得 %s" % str(_耐久(后端, -1)))
		_查(_满了(后端, -3), "步 2：普通修理没把槽 -3（01030033）修满，实得 %s" % str(_耐久(后端, -3)))
		_查(_金币(后端) == 金一 - 普通合计,
				("步 2：普通修理收的钱不是 70（10×stage1 normalPrice 1 + 5×stage3 normalPrice 12），"
				+ "实得 %d（金前 %d）—— 只修第一件/把方式当格位/读了 specialPrice 都会是这个红")
				% [金一 - _金币(后端), 金一])
	# 服务端真改了耐久会回 `32:11` ⇒ 先给它一拍，再认"背包里那两件没被动过"。
	await create_timer(1.0).timeout
	_查(_背包耐久(后端, 甲件) == [202, 210] and _背包耐久(后端, 乙件) == [208, 210],
			("步 2 反向：背包里那两件破损的被修理吃掉了（甲 %s / 乙 %s）—— "
			+ "服务端该只扫身上那份清单（`-199 <= slot < 0`）")
			% [str(_背包耐久(后端, 甲件)), str(_背包耐久(后端, 乙件))])

	# ── 步 3：身上没有破损件了 ⇒ 再发一次 ⇒ 一分不收 ──
	# `MendEtcWindow` 合计 0 那一支在服务端对应 `_repair_all_equipped` 的空清单 return。
	var 金二 := _金币(后端)
	if not bool(后端.call("request_repair_equip", 0)):
		_停("步 3：空身上的修理请求发不出去")
		return
	await create_timer(1.0).timeout
	_查(_金币(后端) == 金二,
			"步 3：身上没有破损装备还收了钱（金前 %d，现 %d）—— 满耐久的件该整个跳过"
			% [金二, _金币(后端)])

	# ── 步 4：重新穿上那两件 ⇒ 特殊(1) ⇒ 恰好 360（读的是 specialPrice 那一列）──
	for 号 in [4, 5]:
		var 槽: int = -号
		var 件号 := (甲件 if 号 == 4 else 乙件)
		var 应剩: Array = ([202, 210] if 号 == 4 else [208, 210])
		if not bool(会话.call("equip_item", 件号)):
			_停("步 4：equip_item(%s) 没发出去（客户端这一头就没走，背包镜像 %s）"
					% [件号, str(_背包耐久(后端, 件号))])
			return
		# 一件等一件（同 步 1 那口径：客户端挑格读的是还没刷新的镜像）。
		if not await _等待(func(): return _耐久(后端, 槽) == 应剩):
			_停(("步 4：穿上 %s 后槽 %d 不是 %s（实得 %s）—— 穿/卸不该顺手修理，"
					+ "否则下面那一步就没料了") % [件号, 槽, str(应剩), str(_耐久(后端, 槽))])
			return
	var 金三 := _金币(后端)
	if not bool(后端.call("request_repair_equip", 1)):
		_停("步 4：特殊修理的请求没发出去")
		return
	if not await _等待(func(): return _满了(后端, -4) and _满了(后端, -5) and _金币(后端) == 金三 - 特殊合计):
		_查(_满了(后端, -4), "步 4：特殊修理没把槽 -4 修满，实得 %s" % str(_耐久(后端, -4)))
		_查(_满了(后端, -5), "步 4：特殊修理没把槽 -5 修满，实得 %s" % str(_耐久(后端, -5)))
		_查(_金币(后端) == 金三 - 特殊合计,
				("步 4：特殊修理收的钱不是 360（8×stage3 specialPrice 36 + 2×36），实得 %d（金前 %d）"
				+ "—— 修理方式没读到 / 两列价拿错一列，都是这一句红")
				% [金三 - _金币(后端), 金三])

	# ── 终局：四件全满，且已满的 -1/-3 没在步 4 被二次收费 ──
	for 槽 in [-1, -3, -4, -5]:
		_查(_满了(后端, 槽), "终局：槽 %d 还是破的（%s）" % [槽, str(_耐久(后端, 槽))])

	for 条 in _失败:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（修理真实事务：%s）"
			% [判数, _失败.size(), "通过" if _失败.is_empty() else "失败"])
	_还原端口()
	后端.call("disconnect_backend")
	quit(0 if _失败.is_empty() else 1)


## 借来的端口要还回去（红也一样还），否则用户明天开的客户端会连到 18712 上。
func _还原端口() -> void:
	if 会话引用 == null or _原端口 < 0:
		return
	var 设置: Dictionary = 会话引用.get("game_settings")
	设置["backend_port"] = _原端口


## 反向对照（2026-10-17 五条全红过；跑法 = 改一处 → 跑本门 → `cp` 还原 → `cmp` 核对字节）：
##   R1 `_repair_all_equipped` 里 `field` 写死 `normalPrice`（忽略修理方式）
##      ⇒ 步 4「收的钱不是 360，实得 120」，其余全绿（金币那一步单独照得到，正是要的效果）。
##   R2 扫描循环末尾加 `break`（只修第一件受损 —— #19 的另一半病根）
##      ⇒ 12 判 6 红：步 2 两件各一条 + 步 3/步 4/终局连带。
##   R3 把 `(max_endure - endure) * price` 改成 `max_endure * price`（不看当前耐久）
##      ⇒ 步 2「实得 2670」、步 4「实得 15120」。
##   R3b 去掉 `endure >= max_endure` 那道跳过、每件只收一个底价 `price`
##      ⇒ 步 2「实得 13」+ 步 3「身上没有破损装备还收了钱」+ 步 4「实得 111」。
##      （步 3 只有这一支会红：R1/R2/R3 都动不到它 ⇒ 用它证明步 3 不是空判。）
##   R4 客户端退回 `request_npc_shop_recharge`（NPC_SHOP 子命令 2 = 商品补货，#19 的原样）
##      ⇒ 10 条红、金币**一分没动** —— 玩家当时看到的就是"点了没反应"。
##   R5（门自己那一支）步 1 两发 `unequip_item` 之间不 `await`
##      ⇒ 客户端两发挑到**同一个空格**，服务端第二发当成"和那件甲交换"、`_can_equip` 拒掉
##      ⇒ 门红在步 1（第一版就是这么红的，代码里留了 ⚠️ 注释）。

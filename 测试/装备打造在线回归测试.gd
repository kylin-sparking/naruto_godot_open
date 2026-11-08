extends SceneTree

## 装备打造：**真服务端**端到端验证。
##
## 为什么单独一条：打造这条链路在 2026-09-22 之前**一条断言都没有**，
## 而且中途还出过"执行按钮变成死按钮、点了没反应"这种**用例全绿也发现不了**的问题
## （用例只查界面结构，不查"按钮接没接线、接了之后发不发协议"）。
## 所以这里钉的是**协议真的走通了**：
##
##   ① 武器穿上身（复用 `装备部位` 那条链路）
##   ② 发 `request_strength(武器槽, 0)` —— 强化到 **+1**
##      `EquipSystem.strength.level1` 的 `prob` 是 **100%**，所以这一步是**确定性的**
##      （level2 起就 90/80/… 了，别拿它们做断言）
##   ③ 服务端回包后 `authoritative_equipment[武器].strengthen` 必须变成 1
##
## 运行（由 开发工具/跑在线用例.ps1 拉起，端口 18684）：
##   PowerShell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 装备打造

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")

## 夹具预置在背包里的武器：01010013（**job=300 的那一档**，夹具角色就是 300；
## 武器 id 末位=职业，用错职业会被服务端 `_can_equip` 拒掉）。
const 测试武器 := 1010013

## 精炼验证用的那件：夹具把它预置成 **10 星紫装**（`本地服务端夹具.py` 的
## `seed_forge_ready_weapon`），所以精炼这条路的前置（≥11 星）从"百炼"那一步就能接上。
## 单独一件，不动 `测试武器`（那条链路硬断言它初始 0 星）。
const 精炼武器 := 1010023

var _main
## 收到过的打造结果回包，键是 `kind`（`forge_additive` / `forge_strength`），值是结果码。
## 服务端 `ForgeResult`：**0 = 失败 / 1 = 成功**。
var _打造回包: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = BACKEND_SCRIPT.new()
	_main.name = "EquipForgeOnlineMain"
	root.add_child(_main)
	_main.connect_backend(
		OS.get_environment("NW_ACCOUNT") if OS.has_environment("NW_ACCOUNT") else "a33047518511@gmail.com",
		OS.get_environment("NW_PASSWORD") if OS.has_environment("NW_PASSWORD") else "123456",
		false,
	)
	if not await _wait_until(func(): return _main.authenticated, 10000):
		_fail("真实后端连接未完成登录")
		return
	if not _main.select_character(int(OS.get_environment("NW_CHARACTER_ID")) if OS.has_environment("NW_CHARACTER_ID") else 1):
		_fail("角色无法选择")
		return
	if not await _wait_until(func(): return _main.in_game, 10000):
		_fail("角色无法进入游戏")
		return
	if not await _wait_until(func(): return not _main.authoritative_inventory.is_empty(), 5000):
		_fail("服务端未下发背包快照")
		return
	_main.item_change_result_received.connect(_收到打造回包)

	# ① 先把武器穿上（打造只能作用于**身上**的装备）
	var 武器槽 := 装备部位.位置(str(测试武器))
	if 武器槽 != 装备部位.武器:
		_fail("装备部位.位置(%d) 应解析为武器槽，实际 %d" % [测试武器, 武器槽])
		return
	if not await _wait_until(func(): return _格位(_main.authoritative_inventory, 测试武器) > 0, 8000):
		_fail("夹具背包里没找到 %d（见 本地服务端夹具.py 的 MAIN_ITEMS）" % 测试武器)
		return
	_main.request_item_move(0, _格位(_main.authoritative_inventory, 测试武器), 武器槽, 0)
	if not await _wait_until(func(): return _main.authoritative_equipment.has(武器槽), 5000):
		_fail("武器没能穿上，后面的强化无从谈起")
		return
	var 强化前 := int((_main.authoritative_equipment[武器槽] as Dictionary).get("strengthen", -1))
	if 强化前 != 0:
		_fail("夹具的武器强化等级应初始为 0，实际 %d" % 强化前)
		return

	# ② 强化到 +1（level1 的 prob = 100%，确定性）
	if not _wait_until_sync(func(): return _拥有数(_main.authoritative_inventory, 16000016) > 0, 5000):
		_fail("夹具背包里没有强化灵珠 16000016（见 MAIN_ITEMS）")
		return
	var 珠前 := _拥有数(_main.authoritative_inventory, 16000016)
	if not _main.request_strength(武器槽, 0):
		_fail("request_strength 没能发出（打造协议没接上？）")
		return

	# ③ 等回包把强化等级刷成 1
	if not await _wait_until(func(): return int(_装备(_main, 武器槽).get("strengthen", 0)) >= 1, 8000):
		# 材料扣没扣，能把问题一分为二：
		#   扣了 → 服务端**跑过**打造、只是回包没把强化等级带回来（客户端侧）
		#   没扣 → 请求**压根没进去**（服务端没认出这件装备，或那道闸把它挡了）
		var 珠后 := _拥有数(_main.authoritative_inventory, 16000016)
		_fail("强化后等级没刷上去（当前 strengthen=%d）。强化灵珠 %d → %d（%s）"
			% [int(_装备(_main, 武器槽).get("strengthen", 0)), 珠前, 珠后,
				"服务端跑过打造，问题在回包" if 珠后 < 珠前 else "服务端没跑打造，请求没进去"])
		return

	# 顺带核一件事：`strength_value` 应按 `addRatio` 算出来
	# （`_forge_strength_level`：`round(base_attr_value * addRatio / 100)`，level1 的 addRatio = 13）
	var 穿上: Dictionary = _装备(_main, 武器槽)
	var 值 := int(穿上.get("strength_value", -1))
	var 基础 := int(穿上.get("base_attr_value", 0))
	if 基础 > 0 and 值 != int(round(float(基础) * 13.0 / 100.0)):
		_fail("强化 +1 的 strength_value 应为 round(%d*13/100)=%d，实际 %d"
			% [基础, int(round(float(基础) * 13.0 / 100.0)), 值])
		return

	# ④ 精炼：**真跑通**「百炼 10→11」→「提升附加属性」并核效果。
	#
	#    夹具的长太刀(`精炼武器`)预置成 **10 星紫装**（`seed_forge_ready_weapon`），
	#    所以这里从**百炼**那一步开始 —— 从 0 星强化到 10 星要几十次带概率的重试
	#    （8/9/10 级只有 35/30/25%），那是**夹具**该干的事，不该塞进用例。
	#
	#    ⚠️ 两发都带概率（百炼 25% / 精炼 25%，2026-11-01 用户把成功率提到 25%），
	#    所以只能"重试 + 设上限"，而且**重试次数每次都不一样** —— 别指望可复现：
	#    服务端 RNG 确实是 `random.Random(character.character_id)`（按角色 id 定种子），
	#    但**同一个 `self.random` 还被后台 tick、刷怪等一起消耗**，所以调用序列的位置不固定。
	#    实测：同一份夹具两次跑，百炼分别试了 **16 次 / 26 次**，精炼 10 次 / 3 次。
	#    → 断言钉的是**结果**（11 星 / 每次涨 1~3 / strength_value 的公式），**不是次数**。
	#
	#    为什么非跑成功不可：这两个动作号属于"**号对不上就静默无响应**"那一类错，
	#    只发一次、只看"有没有回包"，证明不了效果真的落到了装备上（§3.12.2）。
	if not await _wait_until(func(): return _格位(_main.authoritative_inventory, 精炼武器) > 0, 8000):
		_fail("夹具背包里没找到 %d 长太刀（见 本地服务端夹具.py 的 seed_forge_ready_weapon）" % 精炼武器)
		return
	# 先脱下小太刀腾出武器槽，再把长太刀穿上（两件不能抢同一个槽）
	_main.request_item_move(0, 武器槽, _空格位(_main.authoritative_inventory), 0)
	if not await _wait_until(func(): return not _main.authoritative_equipment.has(武器槽), 5000):
		_fail("小太刀没能从武器槽脱下来，长太刀穿不上去")
		return
	_main.request_item_move(0, _格位(_main.authoritative_inventory, 精炼武器), 武器槽, 0)
	if not await _wait_until(func(): return int(_装备(_main, 武器槽).get("strengthen", -1)) == 10, 5000):
		_fail("长太刀没穿上、或夹具的 10 星预置没生效（当前 strengthen=%d）"
			% int(_装备(_main, 武器槽).get("strengthen", -1)))
		return

	# —— 百炼：10 星 → 11 星（`EquipSystem.strength.level11`，精炼锤 ×1 / 25%）——
	var 十星: Dictionary = _装备(_main, 武器槽)
	var 百炼前值 := int(十星.get("strength_value", 0))
	var 百炼次数 := 0
	while int(_装备(_main, 武器槽).get("strengthen", 0)) < 11:
		百炼次数 += 1
		if 百炼次数 > 98:
			_fail("百炼试了 98 次还没上 11 星（精炼锤耗尽？堆叠上限就是 99）")
			return
		if await _发打造("forge_strength", 武器槽) < 0:
			_fail("百炼（动作 21）第 %d 次没等到回包 —— 动作号对不上？（见 EquipBaiLianPanel.sureToRequest）" % 百炼次数)
			return
	var 十一星: Dictionary = _装备(_main, 武器槽)
	if int(十一星.get("strengthen", -1)) != 11:
		_fail("百炼后强化等级应是 11，实际 %d" % int(十一星.get("strengthen", -1)))
		return
	# 百炼的 `strength_value` 按 `level11.addRatio`（365）算 —— 和强化同一条公式
	var 基础十一 := int(十一星.get("base_attr_value", 0))
	if 基础十一 > 0 and int(十一星.get("strength_value", -1)) != int(round(基础十一 * 365.0 / 100.0)):
		_fail("百炼后 strength_value 应为 round(%d*365/100)=%d，实际 %d"
			% [基础十一, int(round(基础十一 * 365.0 / 100.0)), int(十一星.get("strength_value", -1))])
		return

	# —— 精炼·提升附加属性（`EquipSystem.forgeAdditive`，精炼锤 ×1 / 25%）——
	# 成功时 `forge_additive_ratio` 加 1~3：`roll >= 90 → 3`、`>= 60 → 2`、否则 1。
	# 一直炼到累计 ≥ 3，把"每成功一次涨多少"这条轨迹也走出来（这就是精炼的**效果**）。
	var 精炼次数 := 0
	var 轨迹: Array[String] = ["0"]
	var 上一次 := 0
	while 上一次 < 3:
		精炼次数 += 1
		if 精炼次数 > 60:
			_fail("精炼试了 60 次，附加比例才 %d（要从 0 涨到 3）" % 上一次)
			return
		if await _发打造("forge_additive", 武器槽) < 0:
			_fail("精炼（动作 22）第 %d 次没等到回包 —— 动作号对不上？（见 EquipBaiLianPanel.sureToRequest）" % 精炼次数)
			return
		var 当前 := int(_装备(_main, 武器槽).get("forge_additive_ratio", 0))
		if 当前 != 上一次:
			if 当前 - 上一次 < 1 or 当前 - 上一次 > 3:
				_fail("精炼成功一次应涨 1..3，实际涨了 %d" % (当前 - 上一次))
				return
			轨迹.append(str(当前))
			上一次 = 当前
	var 附加比例 := 上一次

	print("装备打造在线回归测试：通过（武器槽 %d；强化 0→%d；strength_value=%d；"
		% [武器槽, int(穿上.get("strengthen", 0)), 值])
	print("  · 百炼 10→%d 星，试了 %d 次（25%%），strength_value %d→%d"
		% [int(十一星.get("strengthen", 0)), 百炼次数,
			百炼前值, int(十一星.get("strength_value", 0))])
	print("  · 精炼·提升附加属性 试了 %d 次（25%%），附加比例 %s）"
		% [精炼次数, " → ".join(轨迹)])
	_main.disconnect_backend()
	quit(0)


## 发一发打造请求并等它那一条回包。返回结果码（0 失败 / 1 成功）；没发出去或没回包返回 -1。
## （`forge_additive` = 精炼·提升附加属性，动作 22；`forge_strength` = 百炼，动作 21。）
func _发打造(种类: String, 槽: int) -> int:
	_打造回包.erase(种类)
	var 已发 := false
	if 种类 == "forge_additive":
		已发 = _main.request_forge_additive(槽)
	else:
		已发 = _main.request_forge_strength(槽)
	if not 已发:
		return -1
	if not await _wait_until(func(): return _打造回包.has(种类), 8000):
		return -1
	return int(_打造回包[种类])


## 背包里第一个空位（脱下装备时要有地方放）。
func _空格位(物品表: Array) -> int:
	var 占用 := {}
	for 物品 in 物品表:
		if 物品 is Dictionary:
			占用[int(物品.get("slot_index", -1))] = true
	var 序号 := 0
	while 占用.has(序号):
		序号 += 1
	return 序号


## `item_change_result_received(opcode, result)` 的收口 —— 只留打造那两类。
func _收到打造回包(_opcode: int, 结果: Dictionary) -> void:
	var 种类 := String(结果.get("kind", ""))
	if 种类 in ["forge_additive", "forge_strength"]:
		_打造回包[种类] = int(结果.get("result", -1))


func _装备(后端, 槽: int) -> Dictionary:
	var 条: Variant = 后端.authoritative_equipment.get(槽, {})
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


func _格位(物品表: Array, 物品编号: int) -> int:
	for 物品 in 物品表:
		if 物品 is Dictionary and int(物品.get("id", 0)) == 物品编号:
			return int(物品.get("slot_index", 0))
	return 0


func _拥有数(物品表: Array, 物品编号: int) -> int:
	var 数 := 0
	for 物品 in 物品表:
		if 物品 is Dictionary and int(物品.get("id", 0)) == 物品编号:
			数 += int(物品.get("quantity", 0))
	return 数


func _wait_until_sync(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		OS.delay_msec(20)
	return bool(predicate.call())


func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())


func _fail(message: String) -> void:
	push_error("装备打造在线回归测试：失败 - %s" % message)
	if _main != null:
		_main.disconnect_backend()
	quit(1)

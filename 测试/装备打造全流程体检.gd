extends SceneTree

## **装备打造全流程体检** —— 从一件**白板**开始，把七个功能挨个跑一遍，
## 逐个报出"这一发到底改了什么字段 / 还是压根没动"。
##
## 和 `装备打造在线回归测试.gd` 的分工：
##   * 那条钉的是**协议通不通**（动作号对不对、回包来不来）；
##   * 这条是**体检**——先把每一页"实际做了什么"逐行打出来（这是它的主要价值：
##     "点了没反应"最难发现），**再**对已经定下来的语义下断言。
##
## 退出码：字段逐行报告不判死；但**语义断言**（②只换类型/条数品级不动、③只换数值类型不动）
## 红了就退出 1 —— 那几条是用户 2026-09-23 明确口径，不能悄悄回退。
##
## 前置是服务端各 handler 里的硬条件（都核过 `fake_flash_server.py`）：
##   强化   `_forge_strength_level`  `next_level <= 10`
##   百炼   `_forge_level_eleven`    `strength_level == 10`
##   精炼·附加 `_forge_additive`     `strength_level >= 11`
##   洗附加数值 `_forge_wash_plus_attributes` **`plus_attributes` 非空**
##   进阶   `_forge_stage_up`        下一阶有配置、且 `next_item_id` 有效
##   天生   `_forge_born_attribute`  `born[<部位>]` 有配置
##   刻印   `_forge_carve`           `carve.req.stage<阶>` 有配置
##
## 运行（由 开发工具/跑在线用例.ps1 拉起）：
##   PowerShell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 打造体检

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")

## 白板：01010013 小太刀（job 300、0 星、无附加属性）。
const 白板 := 1010013
## 夹具预置的"已打造"长太刀（10 星 / 带附加属性），③b 用它跑完整流程。
const 精炼武器 := 1010023

var _main
var _打造回包: Dictionary = {}
## 语义断言的失败项（逐行报告不判死，这几条判死）。
var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = BACKEND_SCRIPT.new()
	_main.name = "ForgePhysicalMain"
	root.add_child(_main)
	_main.connect_backend(
		OS.get_environment("NW_ACCOUNT") if OS.has_environment("NW_ACCOUNT") else "a33047518511@gmail.com",
		OS.get_environment("NW_PASSWORD") if OS.has_environment("NW_PASSWORD") else "123456",
		false,
	)
	if not await _等(func(): return _main.authenticated, 10000):
		_停("登录没完成")
		return
	if not _main.select_character(1):
		_停("选角失败")
		return
	if not await _等(func(): return _main.in_game, 10000):
		_停("进不了游戏")
		return
	if not await _等(func(): return not _main.authoritative_inventory.is_empty(), 5000):
		_停("没收到背包快照")
		return
	_main.item_change_result_received.connect(_收回包)

	var 槽 := 装备部位.位置(str(白板))
	if not await _等(func(): return _格位(_main.authoritative_inventory, 白板) > 0, 8000):
		_停("背包里没有白板 %d" % 白板)
		return
	_main.request_item_move(0, _格位(_main.authoritative_inventory, 白板), 槽, 0)
	if not await _等(func(): return _main.authoritative_equipment.has(槽), 5000):
		_停("白板没穿上")
		return

	print("")
	print("════ 装备打造全流程体检（白板 %d，武器槽 %d）════" % [白板, 槽])
	print("起始：", _一行(_快照(槽)))

	await _强化到十星(槽)
	await _洗附加属性(槽)
	await _洗附加数值(槽)
	await _进阶(槽)
	await _天生(槽)
	await _刻印(槽)
	await _百炼与精炼(槽)
	# ⚠️ ③b 会**把身上那件换掉**（要用带附加属性的长太刀），所以只能放在**全程跑完之后** ——
	# 第一版插在中间，结果 ④~⑧ 全跑到长太刀上去了（④ 甚至一次没试就"没变"）。
	await _洗练体检(槽)

	print("")
	if _失败.is_empty():
		print("════ 体检结束：语义断言全过 ════")
		_main.disconnect_backend()
		quit(0)
	else:
		for 项 in _失败:
			push_error("装备打造全流程体检：失败 - %s" % 项)
		_main.disconnect_backend()
		quit(1)


# ── 每一步 ──────────────────────────────────────────

func _强化到十星(槽: int) -> void:
	# 0→10 级。level1 是 100%，往后越来越低，所以只能"重试到成功"。
	var 前 := _快照(槽)
	var 次数 := 0
	while int(_装备(槽).get("strengthen", 0)) < 10:
		次数 += 1
		if 次数 > 400:
			_报("① 强化(动作 5)", 次数, 前, _快照(槽), "试了 400 次还没到 10 星，放弃")
			return
		if not _main.request_strength(槽, 0):
			_报("① 强化(动作 5)", 次数, 前, _快照(槽), "请求发不出去")
			return
		if not await _等到强化变(槽, int(_装备(槽).get("strengthen", 0)) + 1, 3000):
			pass   # 失败也是正常结果（材料已经扣了），继续试
	_报("① 强化(动作 5)", 次数, 前, _快照(槽), "")


func _洗附加属性(槽: int) -> void:
	# 客户端 tab1「洗附加属性」→ `request_change_aptitude` → 动作 **1**。
	var 前 := _快照(槽)
	var 发了: bool = _main.request_change_aptitude(槽, 0)
	if not 发了:
		_报("② 洗附加属性(动作 1)", 0, 前, _快照(槽), "请求发不出去")
		return
	await _等几帧(30)
	_报("② 洗附加属性(动作 1)", 1, 前, _快照(槽), "")


func _洗附加数值(槽: int) -> void:
	# tab2「洗附加数值」→ `request_wash_plus_value` → 动作 **2**。
	#
	# ⚠️ 这一发**本来就不该动装备**：服务端 `_forge_wash_plus_attributes` 是**预览** ——
	# 命中（写死的 70%）就把新词条塞进 `pending_plus_attributes`，装备本身一点不动
	# （`_finish_forge(item, changes, False)`）。真正落盘要走动作 **19**（保存/取消）。
	# 所以这一步要看的是**回包**，不是装备字段；拿装备字段当判据会误判成"功能坏了"。
	var 前 := _快照(槽)
	_打造回包.erase("wash_plus_value")
	if not _main.request_wash_plus_value(槽, 0):
		_报("③ 洗附加数值(动作 2)", 0, 前, _快照(槽), "请求发不出去")
		return
	if not await _等(func(): return _打造回包.has("wash_plus_value"), 6000):
		print("③ 洗附加数值(动作 2)                **没等到回包**")
		return
	var 果: Dictionary = _打造回包["wash_plus_value"]
	print("③ 洗附加数值(动作 2)                回包 result=%s、预览 %d 条（装备字段**本就不该变**）"
		% [果.get("result", "?"), (果.get("plus_attributes", []) as Array).size()])


## ②③ 洗练两页的**语义**体检 —— 必须跑在**有附加属性的装备**上。
##
## 为什么非换一件不可：白板没有附加属性，② 服务端直接回一句"该装备没有可洗练的附加属性"、
## ③ 连回包都不发 —— 两页的**语义**（改类型还是改数值）在白板上根本验不到。
## 所以这里换夹具预置的那件（**6 条**附加属性 —— 照真实紫装，数值取上下限中值，
## 不写满：服务端对 `旧值 >= 上限` 的条目原样返回，写满就永远验不出变化）。
##
## 用户口径（2026-09-23）：
##   ② 洗附加属性：**不改品级、不改条数**，只重掷**类型**，数值跟着随机刷新
##   ③ 洗附加数值：**只重掷数值**，类型不变
func _洗练体检(槽: int) -> void:
	# ⚠️ 要挑**带附加属性的那件**：④ 进阶已经把白板本身也变成了 1010023，
	# 背包里会有两件同号 —— 按 id 找会挑错（第一版就挑到了刚脱下来的那件空壳）。
	var 目标位 := _格位带附加()
	if 目标位 < 0:
		print("②③ 洗练体检                          跳过：背包里没有带附加属性的 %d" % 精炼武器)
		return
	_main.request_item_move(0, 槽, _空格位(), 0)
	await _等(func(): return not _main.authoritative_equipment.has(槽), 4000)
	_main.request_item_move(0, 目标位, 槽, 0)
	if not await _等(func(): return int(_装备(槽).get("id", 0)) == 精炼武器, 5000):
		print("②③ 洗练体检                          跳过：长太刀没穿上")
		return
	if (_装备(槽).get("plus_attributes", []) as Array).is_empty():
		print("②③ 洗练体检                          跳过：夹具没给它附加属性")
		return

	# ── ② 洗附加属性：只换**类型**，条数/品级都不许动 ──
	# 紫色档 70%、每次 4 颗重生灵珠，所以要重试。
	var 前类型 := _类型表(槽)
	var 前数值 := _数值表(槽)
	var 前品级 := int(_装备(槽).get("aptitude", 0))
	var 试 := 0
	while str(_类型表(槽)) == str(前类型) and str(_数值表(槽)) == str(前数值):
		试 += 1
		if 试 > 20:
			break
		_main.request_change_aptitude(槽, 0)
		await _等几帧(20)
	var 后类型 := _类型表(槽)
	var 后数值 := _数值表(槽)
	var 后品级 := int(_装备(槽).get("aptitude", 0))
	print("② 洗附加属性(动作 1)                 试 %2d 次  条数 %d→%d / 品级 %d→%d"
		% [试, 前类型.size(), 后类型.size(), 前品级, 后品级])
	print("     类型 %s → %s" % [前类型, 后类型])
	print("     数值 %s → %s" % [前数值, 后数值])
	_查(后类型.size() == 前类型.size(), "② 不该改附加属性**条数**（%d→%d）" % [前类型.size(), 后类型.size()])
	_查(后品级 == 前品级, "② 不该改**品级**（%d→%d）" % [前品级, 后品级])
	_查(str(后类型) != str(前类型), "② 应该重掷**类型**，实际没变：%s" % str(后类型))

	# ── ③ 洗附加数值：只换**数值**，类型一个都不许动 ──
	前类型 = _类型表(槽)
	前数值 = _数值表(槽)
	_打造回包.erase("wash_plus_value")
	_main.request_wash_plus_value(槽, 0)
	if not await _等(func(): return _打造回包.has("wash_plus_value"), 6000):
		print("③ 洗附加数值(动作 2)                 **预览没回包**")
		return
	var 果: Dictionary = _打造回包["wash_plus_value"]
	# 预览里"保存后应该长成什么"（服务端回包就是这组数值）。
	var 预览: Array = []
	for 条 in (果.get("plus_attributes", []) as Array):
		if 条 is Dictionary:
			预览.append(int((条 as Dictionary).get("attribute_value", -1)))
	_main.request_select_plus_value(槽, true)      # 保存
	# 保存后服务端会回 `MODIFY_INVENTORY_ITEM(flag 11)`，客户端再落到 GameSession；
	# 面板/提示框读的正是那份镜像，所以等它同步完再断言。
	await _等(func(): return str(_会话数值(槽)) == str(预览), 6000)
	var 后类型2 := _类型表(槽)
	var 后数值2 := _数值表(槽)
	var 会数值 := _会话数值(槽)
	print("③ 洗附加数值(动作 2)                 预览 result=%s  类型 %s → %s"
		% [果.get("result", "?"), 前类型, 后类型2])
	print("     数值 %s → 预览 %s → 装备 %s / 会话 %s" % [前数值, 预览, 后数值2, 会数值])
	# ⚠️ 类型**必须一字不差** —— 这正是"洗数值"和"洗属性"的分界，也是最容易改坏的一条。
	_查(str(后类型2) == str(前类型), "③ 不该改**类型**（%s→%s）" % [前类型, 后类型2])
	# 保存必须**真的落盘**（用户 2026-11-01 报"附加数值没有改变 ⇒ 怀疑没实装"，根因是夹具
	# 把附加属性写满到了上限、服务端对满值原样返回）。
	_查(str(后数值2) == str(预览), "③ 保存后装备数值应等于预览（%s vs %s）" % [后数值2, 预览])
	_查(str(会数值) == str(预览), "③ GameSession 装备镜像应同步到预览（%s vs %s）" % [会数值, 预览])
	_查(str(后数值2) != str(前数值), "③ 洗练后数值应有变化（前 %s / 后 %s）" % [前数值, 后数值2])


## 附加属性的**类型**列表（属性 id）。
func _类型表(槽: int) -> Array:
	var 出: Array = []
	for 条 in (_装备(槽).get("plus_attributes", []) as Array):
		if 条 is Dictionary:
			出.append(int((条 as Dictionary).get("attribute_type", 0)))
	return 出


## 附加属性的**数值**列表。
func _数值表(槽: int) -> Array:
	var 出: Array = []
	for 条 in (_装备(槽).get("plus_attributes", []) as Array):
		if 条 is Dictionary:
			出.append(int((条 as Dictionary).get("attribute_value", 0)))
	return 出


## `GameSession.equipped_items`（功能窗口/提示框真正读的那份镜像）里某槽的数值列表。
## ⚠️ 和后端 `authoritative_equipment` 是**两份**：只验后端会在"服务端改了、界面不刷"时假绿。
func _会话数值(槽: int) -> Array:
	var 会 := root.get_node_or_null("GameSession")
	if 会 == null:
		return []
	var 件: Variant = (会.equipped_items as Dictionary).get(槽, {})
	if typeof(件) != TYPE_DICTIONARY:
		return []
	var 出: Array = []
	for 条 in ((件 as Dictionary).get("plus_attributes", []) as Array):
		if 条 is Dictionary:
			出.append(int((条 as Dictionary).get("attribute_value", -1)))
	return 出


func _进阶(槽: int) -> void:
	# tab3「进阶」→ `request_stage_up` → 动作 **3**（prob 60%，要重试）。
	var 前 := _快照(槽)
	var 次数 := 0
	while int(_装备(槽).get("id", 0)) == 白板:
		次数 += 1
		if 次数 > 40:
			break
		if not _main.request_stage_up(槽, 0, false, false):
			break
		await _等几帧(20)
	_报("④ 进阶(动作 3)", 次数, 前, _快照(槽), "")


func _天生(槽: int) -> void:
	# tab4「天生」→ `request_wash_born` → 动作 **4**（prob 25%，要重试）。
	var 前 := _快照(槽)
	var 次数 := 0
	while int(_装备(槽).get("born_attr_value", 0)) == 0:
		次数 += 1
		if 次数 > 40:
			break
		if not _main.request_wash_born(槽):
			break
		await _等几帧(20)
	_报("⑤ 天生(动作 4)", 次数, 前, _快照(槽), "")


func _刻印(槽: int) -> void:
	# tab5「刻印」→ `request_carve` → 动作 **16**（服务端写死成功）。
	var 前 := _快照(槽)
	var 发了: bool = _main.request_carve(槽, true)
	await _等几帧(30)
	_报("⑥ 刻印(动作 16)", 1 if 发了 else 0, 前, _快照(槽), "" if 发了 else "请求发不出去")


func _百炼与精炼(槽: int) -> void:
	# tab6「精炼」两项：**提升强化星级** = 百炼（动作 21，要先 10 星）；
	#                 **提升附加属性** = 精炼（动作 22，要先 ≥11 星）。
	var 前 := _快照(槽)
	var 百炼 := 0
	while int(_装备(槽).get("strengthen", 0)) < 11:
		百炼 += 1
		if 百炼 > 98:
			break
		if not _main.request_forge_strength(槽):
			break
		await _等几帧(20)
	_报("⑦ 精炼·提升强化星级(动作 21)", 百炼, 前, _快照(槽), "")

	前 = _快照(槽)
	var 精炼 := 0
	while int(_装备(槽).get("forge_additive_ratio", 0)) == 0:
		精炼 += 1
		if 精炼 > 60:
			break
		if not _main.request_forge_additive(槽):
			break
		await _等几帧(20)
	_报("⑧ 精炼·提升附加属性(动作 22)", 精炼, 前, _快照(槽), "")


# ── 报账 ────────────────────────────────────────────

## 打印一行体检结论：这一步试了几次、哪些字段动了、没动的话标红。
func _报(名称: String, 次数: int, 前: Dictionary, 后: Dictionary, 备注: String) -> void:
	var 变: Array[String] = []
	for 键 in 前:
		if str(前[键]) != str(后[键]):
			变.append("%s %s→%s" % [键, 前[键], 后[键]])
	var 尾巴 := "  ⚠️ " + 备注 if not 备注.is_empty() else ""
	if 变.is_empty():
		print("%-32s 试 %2d 次   **一点没变**%s" % [名称, 次数, 尾巴])
	else:
		print("%-32s 试 %2d 次   %s%s" % [名称, 次数, " / ".join(变), 尾巴])


func _快照(槽: int) -> Dictionary:
	var 件 := _装备(槽)
	return {
		"id": int(件.get("id", 0)),
		"阶": int(件.get("stage", 0)),
		"星级": int(件.get("strengthen", 0)),
		"强化值": int(件.get("strength_value", 0)),
		"基础值": int(件.get("base_attr_value", 0)),
		"天生值": int(件.get("born_attr_value", 0)),
		"资质": int(件.get("aptitude", 0)),
		"附加条数": (件.get("plus_attributes", []) as Array).size(),
		"秘印": int(件.get("carve_id", 0)),
		"秘印值": int(件.get("carve_value", 0)),
		"精炼比例": int(件.get("forge_additive_ratio", 0)),
	}


func _一行(快照: Dictionary) -> String:
	var 段: Array[String] = []
	for 键 in 快照:
		段.append("%s=%s" % [键, 快照[键]])
	return " ".join(段)


# ── 小工具 ──────────────────────────────────────────

func _装备(槽: int) -> Dictionary:
	var 条: Variant = _main.authoritative_equipment.get(槽, {})
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 背包里那件**带附加属性**的长太刀所在的格位（找不到回 -1）。
## 按 id + `plus_attributes` 非空一起判 —— 白板进阶之后也会变成同一个 id。
func _格位带附加() -> int:
	for 物品 in _main.authoritative_inventory:
		if not (物品 is Dictionary):
			continue
		var d := 物品 as Dictionary
		if int(d.get("id", 0)) == 精炼武器 and not (d.get("plus_attributes", []) as Array).is_empty():
			return int(d.get("slot_index", 0))
	return -1


## 背包里第一个空位（换装备时要腾地方）。
func _空格位() -> int:
	var 占用 := {}
	for 物品 in _main.authoritative_inventory:
		if 物品 is Dictionary:
			占用[int(物品.get("slot_index", -1))] = true
	var 序号 := 0
	while 占用.has(序号):
		序号 += 1
	return 序号


func _格位(物品表: Array, 物品编号: int) -> int:
	for 物品 in 物品表:
		if 物品 is Dictionary and int(物品.get("id", 0)) == 物品编号:
			return int(物品.get("slot_index", 0))
	return 0


## 等强化等级变成 `目标`（成功）；超时说明这一发失败了。
func _等到强化变(槽: int, 目标: int, 毫秒: int) -> bool:
	return await _等(func(): return int(_装备(槽).get("strengthen", -1)) >= 目标, 毫秒)


func _等几帧(帧数: int) -> void:
	for _序号 in 帧数:
		await process_frame


func _收回包(_opcode: int, 结果: Dictionary) -> void:
	# 存**整份**回包：洗附加数值那一步要看 `plus_attributes` 预览内容，不只是 result。
	_打造回包[String(结果.get("kind", ""))] = 结果


func _等(条件: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while not 条件.call() and Time.get_ticks_msec() < 截止:
		await create_timer(0.03).timeout
	return bool(条件.call())


func _查(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)


func _停(原因: String) -> void:
	push_error("装备打造全流程体检：中断 - %s" % 原因)
	if _main != null:
		_main.disconnect_backend()
	quit(1)

extends SceneTree

## 堆叠上限回归门（2026-10-21，用户报修 1.2「商城买东西，输入数量超过堆叠上限只结算 99 件 ——
## 这条行为没问题，但**希望把能堆叠的道具数量如果是 99、999 的都改成 9999**」）。
##
## 先记原版真值（**一个字都没改数据**，偏离只落在代码里）：
##   · 一摞能装多少 = GameData 的 `info.slotMax`（AS3 `ItemData.as:248`
##     `maxCount = ObjectAccessor.getFromObject(wzBigObject,["info","slotMax"])`），
##     本工程导出成 `数据/物品.json` 的 `stack_max`（`开发工具/生成数据扩展.py:169`）。
##   · 原版拿它当**合并堆叠**的闸：`DataCenter.as:1159` `quantity + param3 <= maxCount`。
##   · 原版购买弹窗的数量上限**不是**堆叠上限：`BuyEqpWindow.as:249` `maxCount = Math.floor(balance/price)`
##     （`:467-469` 超了就按它夹），NPC 商店那页同理（`UI.as:2039` `maxCount = buyCount`）。
##   · 报文装得下：NPC 商店帧第 5 字段是 `readUnsignedShort`（`ShopItem.as:11/39`），
##     服务端同口径 `NATIVE_ITEM_QUANTITY_MAX = 0xFFFF` ⇒ 9999 不越 wire 类型。
##   · `数据/物品.json` 的 stack_max 全表分布：**1→775 条、99→1380 条、999→83 条、5000→2 条、9999→459 条**。
##
## 修法 = 一条**登记过的有意偏离**：作者值 **99 / 999 → 9999**，1 与 5000 原样。两头各一个闸口，必须同表：
##   · 服务端 `fake_flash_server.py:2075 _item_stack_limit`（GM 发放、商城/NPC 商店结算、堆叠合并全走它）
##     + 两处 NPC 商店帧序列化（`55476`/`55518` 附近）改发**有效上限**而不是 authored；
##   · 夹具 `开发工具/本地服务端夹具.py grant_items` 的分批**必须同一个函数**，
##     拿 authored `stack_max` 分批会比服务端更保守（作者值 99 切成 101 发）；
##   · 客户端 `游戏数据.堆叠上限()`（离线发放物品用它）＋ `后端连接.request_cash_shop_buy`
##     的报文硬闸从 `clampi(…, 1, 999)` 抬到 9999 —— 原来这发 999 是本工程自加的，原版没有。
##
## 盯六条：
##   ① 客户端映射：五档 authored 各一个真 id（99 / 999 / 5000 / 9999 / 1）+ 查不到的 id。
##      ⇒ 99 和 999 抬到 9999；**1 与 5000 不许动**（抬了就是把不可叠的东西也抬了）。
##   ② **数据侧反证**：`数据/物品.json` 里那几个 id 的 authored `stack_max` 仍是 99/999/5000/1 ——
##      偏离必须在代码，不许"顺手"把导出表改掉（改掉就再也对不回原版）。
##   ③ 离线发放行为腿：`_离线发放物品("10000001", 300)` ⇒ **只占 1 格、数量 300**
##      （旧口径 99 会切成 4 格）。这条真跑代码，不读注释。
##   ④ 报文腿（替身只记不发）：买 5000 ⇒ 报文尾数就是 5000；买 70000 ⇒ 夹到 9999；买 0 ⇒ 夹到 1。
##      旧口径 `clampi(…,1,999)` 会让第一条报 999 ⇒ 当场红。
##   ⑤ 服务端口径钉：`STACK_LIMIT_RAISE_TO = {99: 9999, 999: 9999}` 字面在、`_item_stack_limit`
##      确实 `return STACK_LIMIT_RAISE_TO.get(authored_limit, authored_limit)`、两条购买结算仍是
##      `min(quantity, _item_stack_limit(item_id))`（**只结算、不多扣钱**那条行为就是它）、
##      NPC 商店两处帧字段用 `_item_stack_limit(`。万一哪天服务端改成"1084 那种"别的口径，这条先红。
##   ⑥ 夹具口径钉：`grant_items` 里必须是 `server._item_stack_limit(`（点号＋括号，防"只在注释里提到"
##      和 `has_method` 那种自证假绿），且**不许**再用 `definition.stack_max` 取分批值。
##
## ⚠ 三条口径：
##   · ⑦ 是**两头同表**的对照腿：客户端 const 与服务端字面必须一模一样（各 2 条、99/999→9999）。
##   · 替身照 `测试/商城开窗发包回归测试.gd` 的用法：继承真后端、只记不发（同 `后端协议回归测试.gd:55`）。
##   · 有**跑完了哨兵**；门自己 `quit(0/1)`。
##
## 运行：`Godot --headless --path . --script res://测试/堆叠上限回归测试.gd`

const 会话脚本 := "res://脚本/单例/游戏会话.gd"
const 后端脚本 := "res://脚本/单例/后端连接.gd"
const 服务端夹具 := "res://服务端/runtime/tools/fake_flash_server.py"
const 起服脚本 := "res://开发工具/本地服务端夹具.py"
const 物品表 := "res://数据/物品.json"
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 码购买 := 1081

## authored → 期望"有效上限"。id 全是从 `数据/物品.json` 里挑的**真货**（腿② 会把 authored 反证一遍）。
const 样本 := [
	["10000001", 99, 9999],		# 熊皮（任务物品）
	["11000353", 999, 9999],	# 8888点券（礼包）
	["15004001", 5000, 5000],	# 生命灵药 —— **不在抬升表里**
	["13000000", 9999, 9999],	# 红色宝石（1级）
	["10000010", 1, 1],			# 宠物蛋一类，authored=1 ⇒ **不许抬**
]

var _通过 := 0
var _失败: Array[String] = []
var _跑完了 := false


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


func _判(对: bool, 明: String, 反: String = "") -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append("%s%s" % [明, "" if 反.is_empty() else " ⇒ " + 反])


func _行数(路径: String) -> String:
	return FileAccess.get_file_as_string(路径)


## 抬升表两头各读一遍：客户端是 GDScript const，服务端是 Python 字面。
func _服务端口径() -> Dictionary:
	var 出 := {"表在": false, "用了": false, "结算": 0, "帧字段": 0}
	var 文 := _行数(服务端夹具)
	if 文.contains("STACK_LIMIT_RAISE_TO = {99: 9999, 999: 9999}"):
		出["表在"] = true
	if 文.contains("return STACK_LIMIT_RAISE_TO.get(authored_limit, authored_limit)"):
		出["用了"] = true
	for 行 in 文.split("\n"):
		var 条 := String(行).strip_edges()
		if 条.begins_with("#"):
			continue
		if 条.contains("min(quantity, _item_stack_limit(item_id))"):
			出["结算"] = int(出["结算"]) + 1
		# NPC 商店两帧：一帧是 f-string 内插，一帧是 if/else 的 else 支（跨行，所以两种字面都要认）
		if 条.contains("#{_item_stack_limit(item_id)}#") or 条 == "else _item_stack_limit(item_id)":
			出["帧字段"] = int(出["帧字段"]) + 1
	return 出


func _跑() -> void:
	var 真后端 := root.get_node_or_null("BackendConnection")
	if 真后端 == null:
		_失败.append("拿不到 BackendConnection 单例")
		_收尾()
		return

	# ① 客户端映射（行为：直接调函数）
	for 档 in 样本:
		var id := String(档[0])
		var 期望 := int(档[2])
		var 实得 := 游戏数据.堆叠上限(id)
		_判(实得 == 期望,
			"① authored=%d 的 %s ⇒ 有效上限应是 %d，实得 %d" % [int(档[1]), id, 期望, 实得])
	_判(游戏数据.堆叠上限("99999999") == 9999,
		"① 目录里查不到的 id ⇒ 保守取 9999，实得 %d" % 游戏数据.堆叠上限("99999999"))
	_判(游戏数据.堆叠上限抬升表.size() == 2
			and int(游戏数据.堆叠上限抬升表.get(99, 0)) == 9999
			and int(游戏数据.堆叠上限抬升表.get(999, 0)) == 9999
			and not 游戏数据.堆叠上限抬升表.has(1)
			and not 游戏数据.堆叠上限抬升表.has(5000),
		"⑦ 客户端抬升表恰好两条（99/999→9999），1 与 5000 不在表里，实得 %s"
			% [str(游戏数据.堆叠上限抬升表)])

	# ② 数据侧反证：导出表**没被**顺手改掉
	var 表文 := _行数(物品表)
	var 解析 = JSON.parse_string(表文)
	if typeof(解析) != TYPE_DICTIONARY:
		_失败.append("② `数据/物品.json` 解析不出字典 ⇒ 数据腿全废")
	else:
		for 档 in 样本:
			var id2 := String(档[0])
			var 行: Dictionary = (解析 as Dictionary).get(id2, {}) as Dictionary
			var authored := int(行.get("stack_max", -1))
			_判(authored == int(档[1]),
				"② %s 的 authored stack_max 必须还是原版 %d（偏离只落代码、不改表），实得 %d"
					% [id2, int(档[1]), authored])

	# ③ 离线发放行为腿（旧口径 99 ⇒ 300 会切成 4 格）
	var 会话 = (load(会话脚本) as GDScript).new()
	会话.inventory.clear()
	var 发成了 := bool(会话.call("_离线发放物品", "10000001", 300))
	var 占格 := 0
	var 总数 := 0
	for 条 in 会话.inventory:
		var d := 条 as Dictionary
		if d.is_empty():
			continue
		if String(d.get("id", "")) == "10000001":
			占格 += 1
			总数 += int(d.get("quantity", 0))
	_判(发成了 and 占格 == 1 and 总数 == 300,
		"③ 离线发 300 只熊皮 ⇒ 应占 **1 格**、数量 300，实得 发=%s 格=%d 数=%d（旧口径按 99 切会占 4 格）"
			% [str(发成了), 占格, 总数])
	# 反向对照：不可叠的那档（authored=1）抬了的话，这里会一格装下 3 件
	会话.inventory.clear()
	var 发装备 := bool(会话.call("_离线发放物品", "15003013", 3))
	var 特殊格 := 0
	for 条 in 会话.inventory:
		var d2 := 条 as Dictionary
		if not d2.is_empty() and String(d2.get("id", "")) == "15003013":
			特殊格 += 1
	_判(发装备 and int(游戏数据.堆叠上限("15003013")) == 1,
		"③ authored=1 的 15003013 上限必须仍是 1（发 3 件实占 %d 格）⇒ 别把不可叠的也抬了" % 特殊格)
	会话.free()

	# ④ 报文腿：摘掉真 autoload、换"只记不发"的替身
	root.remove_child(真后端)
	var 假 = 测试后端.new()
	假.name = "BackendConnection"
	root.add_child(假)
	假.sent_requests.clear()
	_判(bool(假.request_cash_shop_buy(1234, 5000, 0)), "④ 买 5000 的请求入口返回 true")
	var 条1: Dictionary = 假.sent_requests[0] as Dictionary
	_判(int(条1.get("opcode", 0)) == 码购买
			and String(条1.get("content", "")) == "0:1234:5000",
		"④ 数量 5000 要**原样进报文**（旧口径夹成 999），实得 %s" % [str(条1)])
	假.sent_requests.clear()
	假.request_cash_shop_buy(1234, 70000, 1)
	var 条2: Dictionary = 假.sent_requests[0] as Dictionary
	_判(String(条2.get("content", "")) == "1:1234:9999",
		"④ 超过 9999 仍要夹住（wire 是 unsigned short，但游戏口径是 9999），实得 %s" % [str(条2)])
	假.sent_requests.clear()
	假.request_cash_shop_buy(1234, 0, 0)
	var 条3: Dictionary = 假.sent_requests[0] as Dictionary
	_判(String(条3.get("content", "")) == "0:1234:1",
		"④ 数量 0 要夹成 1，实得 %s" % [str(条3)])
	假.free()
	root.add_child(真后端)

	# ⑤ 服务端口径钉（改的是那份文件，这里防"哪天又改回去/改成别口径"）
	var 服务端 := _服务端口径()
	_判(bool(服务端["表在"]), "⑤ 服务端抬升表字面 `STACK_LIMIT_RAISE_TO = {99: 9999, 999: 9999}` 要在")
	_判(bool(服务端["用了"]),
		"⑤ `_item_stack_limit` 要**真的用**那张表（return STACK_LIMIT_RAISE_TO.get(…)）")
	_判(int(服务端["结算"]) == 2,
		"⑤ 商城两条购买结算（NPC 商店 / 现金商城）都要仍夹 `min(quantity, _item_stack_limit(item_id))`"
			+ "—— 用户认可的那句「超上限只结算 N 件、未多扣货币」就是它，实得 %d 处"
			% int(服务端["结算"]))
	_判(int(服务端["帧字段"]) == 2,
		"⑤ NPC 商店那两帧的第 5 字段（原版 `ShopItem.slotMax = readUnsignedShort`）要发**有效上限**，实得 %d 处"
			% int(服务端["帧字段"]))
	_判(_行数(服务端夹具).contains("NATIVE_ITEM_QUANTITY_MAX = 0xFFFF"),
		"⑤ wire 上限仍是 0xFFFF（9999 落在 unsigned short 内）")

	# ⑥ 夹具口径钉：分批必须跟服务端同一个函数
	var 起服文 := _行数(起服脚本)
	var 分批对 := false
	var 用脏值 := false
	for 行 in 起服文.split("\n"):
		var 条 := String(行).strip_edges()
		if 条.begins_with("#") or 条.begins_with('"') or 条.contains("上限**必须取"):
			continue
		if 条.contains("server._item_stack_limit("):
			分批对 = true
		if 条.contains('getattr(definition, "stack_max"'):
			用脏值 = true
	_判(分批对, "⑥ 夹具 `grant_items` 的分批值要取 `server._item_stack_limit(`（带括号的那次调用）")
	_判(not 用脏值, "⑥ 夹具不许再用 `definition.stack_max` 当分批值（比服务端保守 ⇒ 101 发或整条发失败）")

	_跑完了 = true
	_收尾()


func _收尾() -> void:
	if not _跑完了:
		_失败.append("门没跑到底（中途报错退出）⇒ 上面每条判式都还没量到")
	for 条 in _失败:
		print("失败 - ", 条)
	print("堆叠上限回归测试：通过 %d，红 %d" % [_通过, _失败.size()])
	quit(0 if _失败.is_empty() else 1)

extends SceneTree

## 装备部位模型：端到端（真服务端）验证。
##
## 为什么单独一条：装备位在 2026-09-21 之前是"客户端自己编的中文名键"，
## 与协议（`UpdateEquipSlotInfo.position` 是 readInt）对不上，也没有任何用例盯着它。
## 这条用例只钉三件事：
##   ① 服务端下来的装备快照，键必须是 **位置 int**，且认得出原版的负值槽；
##   ② 穿上一件真装备后，`equipped_items` 的键正好是 `装备部位.位置(id)` 算出来的那个数；
##   ③ 脱下来之后那个槽要真的空掉。
##
## 运行（由 开发工具/跑在线用例.ps1 拉起，端口 18684）：
##   PowerShell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 装备部位

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")

## 夹具预置在背包里的武器：01010013（**job=300 的那一档**，夹具角色就是 300；
## 武器 id 末位=职业，用错职业会被服务端 `_can_equip` 拒掉。见 本地服务端夹具.py 的 MAIN_ITEMS）
const 测试武器 := 1010013

var _main

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_main = BACKEND_SCRIPT.new()
	_main.name = "EquipPartsOnlineMain"
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

	# ① 快照的键必须是 int，且不能出现中文名键
	for 键 in _main.authoritative_equipment:
		if not (键 is int or 键 is float):
			_fail("装备快照的键不是位置 int：%s（%s）" % [键, typeof(键)])
			return
		if str(键) == "" or not str(int(键)).lstrip("-").is_valid_int():
			_fail("装备快照出现非数字键：%s" % 键)
			return
		if int(键) >= 0:
			_fail("角色装备槽不该出现非负键：%d" % int(键))
			return

	# ② 穿上武器
	var 武器槽 := 装备部位.位置(str(测试武器))
	if 武器槽 != 装备部位.武器:
		_fail("装备部位.位置(%d) 应解析为武器槽，实际 %d" % [测试武器, 武器槽])
		return
	# 背包快照是**分块**下来的（100000 那条按 `_inventory_chunks` 攒齐才生效），
	# 所以不能只等"背包非空"，要等**这件武器真的在表里**再动手，否则拿到的格位是 0。
	if not await _wait_until(func(): return _格位(_main.authoritative_inventory, 测试武器) > 0, 8000):
		_fail("夹具背包里没找到 %d（见 本地服务端夹具.py 的 MAIN_ITEMS）" % 测试武器)
		return
	var 源格 := _格位(_main.authoritative_inventory, 测试武器)
	_main.request_item_move(0, 源格, 武器槽, 0)
	if not await _wait_until(func(): return _main.authoritative_equipment.has(武器槽), 5000):
		_fail("穿上后回包未落到键 %d（人物装备槽）" % 武器槽)
		return
	var 穿上 := _main.authoritative_equipment[武器槽] as Dictionary
	if int(穿上.get("id", 0)) != 测试武器:
		_fail("键 %d 上的物品不是刚穿的 %d，而是 %s" % [武器槽, 测试武器, 穿上.get("id", "?")])
		return
	if String(穿上.get("slot", "")) != 装备部位.显示名(武器槽):
		_fail("装备槽名与显示表不一致：%s ≠ %s" % [穿上.get("slot", ""), 装备部位.显示名(武器槽)])
		return
	# 顺手把"穿着武器"这一刻的会话状态落盘，给 `开发工具/截窗口页.gd --快照=`
	# 复现"装着装备的人物面板"用。设了环境变量才写，平时跑用例不产生副作用。
	var 快照路径 := OS.get_environment("NW_EQUIP_SNAPSHOT_OUT")
	if not 快照路径.is_empty():
		_导出快照(快照路径)

	# ③ 脱下来
	var 空格 := 0
	for 序号 in range(1, 97):
		var 占 := false
		for 物品 in _main.authoritative_inventory:
			if int((物品 as Dictionary).get("slot_index", 0)) == 序号:
				占 = true
				break
		if not 占:
			空格 = 序号
			break
	if 空格 <= 0:
		_fail("背包没有空格可以卸下")
		return
	_main.request_item_move(0, 武器槽, 空格, 0)
	if not await _wait_until(func(): return not _main.authoritative_equipment.has(武器槽), 5000):
		_fail("卸下后键 %d 仍在装备快照里" % 武器槽)
		return

	print("装备部位在线回归测试：通过（快照键=位置 int；穿上落到武器槽 %d；脱下后槽空）" % 武器槽)
	_main.disconnect_backend()
	quit(0)

## 把**穿上之后**的会话装备状态原样落成 JSON（键为位置、值为服务端下发的物品字典）。
func _导出快照(路径: String) -> void:
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		return
	DirAccess.make_dir_recursive_absolute(路径.get_base_dir())
	var 文件 := FileAccess.open(路径, FileAccess.WRITE)
	文件.store_string(JSON.stringify(会话.equipped_items, "  "))
	文件.close()
	print("装备部位在线回归测试：快照已导出 %s" % 路径)

func _格位(物品表: Array, 物品编号: int) -> int:
	for 物品 in 物品表:
		if 物品 is Dictionary and int(物品.get("id", 0)) == 物品编号:
			return int(物品.get("slot_index", 0))
	return 0

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _fail(message: String) -> void:
	push_error("装备部位在线回归测试：失败 - %s" % message)
	if _main != null:
		_main.disconnect_backend()
	quit(1)

extends SceneTree

const MAP_ENTITIES := preload("res://脚本/地图/地图实体.gd")
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

var _login_statuses: Array[int] = []
var _character_list_received := false
var _combat_response_object_ids := {}
var _伤害事件: Array[Dictionary] = []   # monster_damaged 的 (damage, critical) 捕获
var _monster_spawn_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var session := root.get_node_or_null("GameSession")
	if backend == null or session == null:
		_fail("缺少后端连接或游戏会话单例")
		return
	backend.login_status_received.connect(func(value: int): _login_statuses.append(value))
	backend.character_list_received.connect(func(_characters: Array, _maximum: int): _character_list_received = true)
	backend.monster_damaged.connect(func(object_id: int, _damage: int, _critical: bool, _受击: bool, _自己: bool, _活着: bool): _combat_response_object_ids[object_id] = true)
	# 同一条信号再抓一份**带 bsk 的明细**（在线暴击红字用；两处连的是同一个信号，互不影响）。
	backend.monster_damaged.connect(func(_object_id: int, damage: int, critical: bool, _受击: bool, _自己: bool, _活着: bool):
		_伤害事件.append({"damage": damage, "critical": critical}))
	backend.monster_hp_changed.connect(func(object_id: int, _hp: int): _combat_response_object_ids[object_id] = true)
	backend.monster_killed.connect(func(object_id: int, _animation: int): _combat_response_object_ids[object_id] = true)
	backend.monster_spawned.connect(func(_state: Dictionary): _monster_spawn_count += 1)

	backend.sync_character()
	var deadline := Time.get_ticks_msec() + 10000
	while not backend.in_game and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout

	if not backend.in_game:
		_fail("未能进入原版后端游戏会话：%s - %s" % [backend.status, backend.detail])
		return
	if int(backend.character_id) <= 0:
		_fail("服务器没有返回有效角色 ID")
		return
	if _login_statuses.is_empty() or _login_statuses[0] != 0:
		_fail("现有账号应走 LOGIN_STATUS=0，实际为 %s" % [_login_statuses])
		return
	if not _character_list_received or backend.characters.is_empty():
		_fail("服务器角色列表未通过 BuildCharacterListPacket 返回")
		return
	if String(session.player_stats.get("name", "")).is_empty():
		_fail("服务器角色名称未同步")
		return
	if int(session.player_stats.get("level", 0)) <= 0:
		_fail("服务器角色等级未同步")
		return
	if int(session.player_stats.get("max_hp", 0)) <= 0:
		_fail("服务器角色生命属性未同步")
		return
	if String(session.current_map_id).is_empty():
		_fail("服务器地图编号未同步")
		return
	var required_stats := [
		"level", "job", "hp", "mp", "apAtk", "apDef", "apDex", "apPhy",
		"maxHp", "maxMp", "attack", "defense", "critical", "dodge",
		"attack_speed", "move_speed", "zq", "remainingAp", "remainingSp",
		"exp", "fame", "gold",
	]
	deadline = Time.get_ticks_msec() + 5000
	while (not _has_all_stats(backend.authoritative_stats, required_stats) or backend.authoritative_skills.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	for field in required_stats:
		if not backend.authoritative_stats.has(field):
			_fail("服务器权威属性未返回：%s" % field)
			return
	if backend.authoritative_skills.is_empty():
		_fail("服务器没有返回已学习忍术")
		return
	backend.authoritative_pets.clear()
	if not backend.request_pet_list():
		_fail("宠物列表请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while backend.authoritative_pets.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if backend.authoritative_pets.is_empty():
		_fail("服务器没有通过 173:0 返回宠物快照")
		return
	var pet: Dictionary = backend.authoritative_pets[0]
	var pet_unique_id := int(pet.get("unique_id", 0))
	var original_pet_name := String(pet.get("name", ""))
	var original_pet_position := int(pet.get("position", 1))
	if pet_unique_id <= 0 or (pet.get("skills", []) as Array).is_empty():
		_fail("服务端宠物快照缺少唯一 ID 或技能字段")
		return
	if not backend.request_pet_attack_out(pet_unique_id):
		_fail("宠物攻击出战请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while int(_find_pet(backend.authoritative_pets, pet_unique_id).get("position", -1)) != 125 and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if int(_find_pet(backend.authoritative_pets, pet_unique_id).get("position", -1)) != 125:
		_fail("服务器没有通过 173:4/173:0 确认宠物攻击出战")
		return
	if not backend.request_pet_rename(pet_unique_id, "PetProbe"):
		_fail("宠物改名请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while String(_find_pet(backend.authoritative_pets, pet_unique_id).get("name", "")) != "PetProbe" and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if String(_find_pet(backend.authoritative_pets, pet_unique_id).get("name", "")) != "PetProbe":
		_fail("服务器没有通过 173:11 确认宠物改名")
		return
	backend.request_pet_rename(pet_unique_id, original_pet_name)
	if original_pet_position == 0:
		backend.request_pet_call_out(pet_unique_id)
	elif original_pet_position == 125:
		backend.request_pet_attack_out(pet_unique_id)
	else:
		backend.request_pet_attack_back(pet_unique_id)
	deadline = Time.get_ticks_msec() + 3000
	while (String(_find_pet(backend.authoritative_pets, pet_unique_id).get("name", "")) != original_pet_name or int(_find_pet(backend.authoritative_pets, pet_unique_id).get("position", -1)) != original_pet_position) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if String(_find_pet(backend.authoritative_pets, pet_unique_id).get("name", "")) != original_pet_name or int(_find_pet(backend.authoritative_pets, pet_unique_id).get("position", -1)) != original_pet_position:
		_fail("宠物可逆联调结束后名称或出战位置未恢复")
		return
	var original_map_id := int(backend.authoritative_map_id)
	var original_position: Vector2 = backend.authoritative_position
	if backend.map_monsters.is_empty():
		var monster_spawn := _first_life_entry(String(session.current_map_id), "m")
		if monster_spawn.is_empty():
			if not backend.request_map_change(101010000, 553, 487):
				_fail("当前地图无怪物，且无法切换到终结谷浅滩联调 238")
				return
			deadline = Time.get_ticks_msec() + 5000
			while int(backend.authoritative_map_id) != 101010000 and Time.get_ticks_msec() < deadline:
				await create_timer(0.05).timeout
			monster_spawn = _first_life_entry("101010000", "m")
			if monster_spawn.is_empty():
				_fail("终结谷浅滩没有可用于 238 联调的怪物")
				return
		if not backend.send_movement(Vector2(float(monster_spawn.x), float(monster_spawn.y)), 1):
			_fail("无法移动到原版怪物坐标以触发 238")
			return
		deadline = Time.get_ticks_msec() + 5000
		while backend.map_monsters.is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
	if backend.map_monsters.is_empty():
		_fail("移动到原版怪物坐标后，服务器仍未通过 238 下发怪物")
		return
	var life_root := MAP_ENTITIES.new()
	root.add_child(life_root)
	await process_frame
	var expected_life_count: int = backend.map_npcs.size()
	for state in backend.map_monsters.values():
		if int(state.get("map_id", 0)) == int(session.current_map_id):
			expected_life_count += 1
	if not bool(life_root.get("_server_authoritative")):
		life_root.free()
		_fail("在线地图实体没有启用服务端权威模式")
		return
	if (life_root.get("_entities") as Array).size() != expected_life_count:
		var actual_life_count: int = (life_root.get("_entities") as Array).size()
		life_root.free()
		_fail("在线地图混入 life 离线实体：服务端=%d，场景=%d" % [expected_life_count, actual_life_count])
		return
	life_root.free()
	var monster: Dictionary = backend.map_monsters.values()[0]
	var attacked_object_id := int(monster.object_id)
	_combat_response_object_ids.clear()
	if not backend.request_basic_attack(attacked_object_id, Vector2(float(monster.x), float(monster.y)), 1):
		_fail("普攻 40 未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 4000
	while not _combat_response_object_ids.has(attacked_object_id) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not _combat_response_object_ids.has(attacked_object_id):
		_fail("服务器没有通过 243/252/239 返回本次攻击目标的战斗结算")
		return

	# —— 在线暴击红字（2026-10-03 打通，见 §3.87）——
	# 真值：出手结算走 **184**（原版 `AttackInfo`/`MobDamage`：每段 `obj&alive&damage*bsk`，
	# `MobDamageItem(damage, bsk)` 的第二位就是暴击位，`applySkillHitMob` 拿它画红字）；
	# 243 只有 `(mobId, damage)` 两 int、恒白字。我们以前**根本没接 184** → 在线普攻连数字都没有。
	# 夹具 `seed_combat_stats` 把主角色敏捷点到 1000 ⇒ 暴击率被原版上限夹到 50%/刀；
	# 默认 ap=0 时 `_roll_combat_rate(0)` 永远不爆 —— 不种这个，下面的"见过暴击"永远等不到。
	# 打最多 24 刀（服务端对**完全相同报文**有短窗去重，方向来回换着发），要同时见过
	# bsk=1 和 bsk=0 各至少一次 —— 只见 0 = 红字链路根本没通；只见 1 = 没测到非暴击分支。
	var 见过暴击 := false
	var 见过平击 := false
	var 刀数 := 0
	while 刀数 < 24 and not (见过暴击 and 见过平击):
		var 活的: Array = backend.map_monsters.values()
		if 活的.is_empty():
			break
		var 目标: Dictionary = 活的[刀数 % 活的.size()]
		var 目标号 := int(目标.get("object_id", 0))
		if 目标号 <= 0:
			break
		_伤害事件.clear()
		backend.request_basic_attack(目标号,
				Vector2(float(目标.get("x", 0)), float(目标.get("y", 0))),
				1 if 刀数 % 2 == 0 else -1)
		刀数 += 1
		var 止 := Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < 止 and _伤害事件.is_empty():
			await create_timer(0.05).timeout
		for 事 in _伤害事件:
			if bool(事.get("critical", false)):
				见过暴击 = true
			elif int(事.get("damage", 0)) > 0:
				见过平击 = true
		await create_timer(0.4).timeout
	if not 见过暴击:
		_fail("在线暴击红字：24 刀内没见过 bsk=1 —— 184 的 `damage*bsk` 没解出暴击，" +
				"或夹具没跑 seed_combat_stats（敏捷 1000 ⇒ 50%/刀，全不爆的概率约 6e-8）")
		return
	if not 见过平击:
		_fail("在线暴击红字：只见过 bsk=1、一次平击都没见到 —— 没测到非暴击那条分支（打了 %d 刀）" % 刀数)
		return
	print("在线暴击红字：√ 184 的 damage*bsk 端到端见过 1 和 0（打了 %d 刀）" % 刀数)
	if original_position != Vector2.ZERO:
		backend.send_movement(original_position, 1)
	var npc_object_id := 0
	if not backend.map_npcs.is_empty():
		npc_object_id = int((backend.map_npcs.values()[0] as Dictionary).get("object_id", 0))
	else:
		npc_object_id = int(_first_life_entry(String(session.current_map_id), "n").get("object_id", 0))
	if npc_object_id <= 0:
		_fail("原版地图数据没有可用于 NPC 对话联调的 NPC")
		return
	if not backend.request_npc_dialog(npc_object_id):
		_fail("NPC 对话请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while backend.last_npc_dialog.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if backend.last_npc_dialog.is_empty():
		_fail("服务器没有返回 NPC 对话")
		return
	backend.authoritative_npc_shop.clear()
	backend.last_npc_dialog.clear()
	var merchant := _find_npc_by_template(backend.map_npcs, [2, 3, 4, 7, 8, 10, 14, 15, 24, 25, 26, 31, 58])
	if merchant.is_empty():
		_fail("当前地图没有服务器下发的商人 NPC 实体")
		return
	if not backend.request_npc_dialog(int(merchant.get("object_id", 0))):
		_fail("武器商人对话请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while backend.last_npc_dialog.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if backend.last_npc_dialog.is_empty() or not backend.request_npc_menu_action(1):
		_fail("NPC 商店菜单请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 1200
	while (backend.authoritative_npc_shop.get("items", []) as Array).is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if (backend.authoritative_npc_shop.get("items", []) as Array).is_empty():
		## 商人那一支按 NPC 模板号找，图上没有带店的商人时 326 永远不来 —— 不是链路坏。
		## ⚠ 这里以前的兜底是「发 324，然后**再等 `authoritative_npc_shop`**」，
		## 它之所以能过，全因为神秘商店那一帧当年挤写进了 NPC 商店的账（§3.222 拆开了）。
		## 现在两支各等各的：**324 到货只证明 324 这条通，不冒充 NPC 商店目录**。
		backend.authoritative_mystery_shop.clear()
		backend.request_secret_shop_open()
		deadline = Time.get_ticks_msec() + 3000
		while (backend.authoritative_mystery_shop.get("items", []) as Array).is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
	var 商店件数 := (backend.authoritative_npc_shop.get("items", []) as Array).size()
	var 神秘件数 := (backend.authoritative_mystery_shop.get("items", []) as Array).size()
	if 商店件数 + 神秘件数 == 0:
		_fail("服务器既没通过 326 返回 NPC 商店目录、也没通过 324 返回神秘商店货架；最后对话=%s" % [backend.last_npc_dialog])
		return
	backend.authoritative_storage_capacity = 0
	backend.last_npc_dialog.clear()
	var storage_keeper := _find_npc_by_template(backend.map_npcs, [13])
	if storage_keeper.is_empty():
		if not backend.request_map_change(100000000, 3943, 818):
			_fail("无法切换到木叶村联调仓库管理员")
			return
		deadline = Time.get_ticks_msec() + 5000
		while int(backend.authoritative_map_id) != 100000000 and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		deadline = Time.get_ticks_msec() + 3000
		while _find_npc_by_template(backend.map_npcs, [13]).is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		storage_keeper = _find_npc_by_template(backend.map_npcs, [13])
		if storage_keeper.is_empty():
			_fail("木叶村没有服务器下发的仓库管理员 NPC 实体")
			return
	if not backend.request_npc_dialog(int(storage_keeper.get("object_id", 0))):
		_fail("仓库管理员对话请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while backend.last_npc_dialog.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if backend.last_npc_dialog.is_empty() or not backend.request_npc_menu_action(2):
		_fail("NPC 仓库菜单请求未发送到服务器")
		return
	deadline = Time.get_ticks_msec() + 3000
	while int(backend.authoritative_storage_capacity) <= 0 and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if int(backend.authoritative_storage_capacity) <= 0:
		_fail("服务器没有通过 330 返回仓库快照")
		return
	var bag_item := _first_positive_slot_item(backend.authoritative_inventory)
	if not bag_item.is_empty():
		var transfer_item_id := String(bag_item.get("id", ""))
		var total_before := _total_item_quantity(backend.authoritative_inventory, backend.authoritative_storage, transfer_item_id)
		var storage_before := _item_quantity(backend.authoritative_storage, transfer_item_id)
		if not backend.request_storage_store_item(int(bag_item.get("slot_index", 0)), 1):
			_fail("仓库存入物品请求未发送到服务器")
			return
		deadline = Time.get_ticks_msec() + 3000
		while _item_quantity(backend.authoritative_storage, transfer_item_id) <= storage_before and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if _item_quantity(backend.authoritative_storage, transfer_item_id) <= storage_before:
			_fail("服务器没有通过 330:4 返回仓库存入结果")
			return
		var stored_item := _find_item(backend.authoritative_storage, transfer_item_id)
		var stored_slot := int(stored_item.get("slot_index", 0))
		var move_slot := _first_free_storage_slot(backend.authoritative_storage, int(backend.authoritative_storage_capacity))
		if move_slot > 0 and move_slot != stored_slot:
			if not backend.request_storage_move(stored_slot, move_slot):
				_fail("仓库换位请求未发送到服务器")
				return
			deadline = Time.get_ticks_msec() + 3000
			while _find_item_at_slot(backend.authoritative_storage, move_slot).is_empty() and Time.get_ticks_msec() < deadline:
				await create_timer(0.05).timeout
			if _find_item_at_slot(backend.authoritative_storage, move_slot).is_empty():
				_fail("服务器没有通过 330:6 返回仓库换位结果")
				return
			stored_slot = move_slot
		if not backend.request_storage_take_item(stored_slot, 1):
			_fail("仓库取回物品请求未发送到服务器")
			return
		deadline = Time.get_ticks_msec() + 3000
		while _item_quantity(backend.authoritative_storage, transfer_item_id) >= storage_before + 1 and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if _total_item_quantity(backend.authoritative_inventory, backend.authoritative_storage, transfer_item_id) != total_before:
			_fail("仓库存取物品后总数量不守恒")
			return
	var original_player_gold := int(backend.authoritative_stats.get("gold", 0))
	var original_storage_gold := int(backend.authoritative_storage_gold)
	if original_player_gold > 0:
		if not backend.request_storage_store_gold(1):
			_fail("仓库存入金币请求未发送到服务器")
			return
		deadline = Time.get_ticks_msec() + 3000
		while int(backend.authoritative_storage_gold) != original_storage_gold + 1 and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if int(backend.authoritative_storage_gold) != original_storage_gold + 1:
			_fail("服务器没有通过 330:3 返回仓库金币更新")
			return
		if not backend.request_storage_take_gold(1):
			_fail("仓库取回金币请求未发送到服务器")
			return
		deadline = Time.get_ticks_msec() + 3000
		while int(backend.authoritative_storage_gold) != original_storage_gold and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if int(backend.authoritative_storage_gold) != original_storage_gold:
			_fail("仓库存取金币后余额未恢复")
			return
	backend.request_storage_close()
	if original_map_id > 0 and original_map_id != int(backend.authoritative_map_id):
		backend.request_map_change(original_map_id, roundi(original_position.x), roundi(original_position.y))
		deadline = Time.get_ticks_msec() + 5000
		while int(backend.authoritative_map_id) != original_map_id and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout

	print("后端接入回归测试：通过（角色=%s，等级=%d，角色ID=%d，地图=%s，权威属性=%d，技能=%d，宠物=%d，怪物生成包=%d，当前怪物=%d，NPC=%d，商店=%d，神秘商店=%d，仓库容量=%d，战斗结算=是）" % [
		session.player_stats.name,
		int(session.player_stats.level),
		int(backend.character_id),
		session.current_map_id,
		backend.authoritative_stats.size(),
		backend.authoritative_skills.size(),
		backend.authoritative_pets.size(),
		_monster_spawn_count,
		backend.map_monsters.size(),
		backend.map_npcs.size(),
		商店件数,
		神秘件数,
		int(backend.authoritative_storage_capacity),
	])
	backend.disconnect_backend()
	quit(0)

func _fail(message: String) -> void:
	push_error("后端接入回归测试：失败 - %s" % message)
	quit(1)

func _has_all_stats(stats: Dictionary, fields: Array) -> bool:
	for field in fields:
		if not stats.has(field):
			return false
	return true

func _find_npc_by_template(npcs: Dictionary, template_ids: Array) -> Dictionary:
	for state in npcs.values():
		if state is Dictionary and template_ids.has(int(state.get("npc_id", 0))):
			return state
	return {}

func _find_pet(pets: Array, unique_id: int) -> Dictionary:
	for pet in pets:
		if pet is Dictionary and int(pet.get("unique_id", 0)) == unique_id:
			return pet
	return {}

func _first_positive_slot_item(items: Array) -> Dictionary:
	for item in items:
		if item is Dictionary and int(item.get("slot_index", 0)) > 0 and int(item.get("quantity", 0)) > 0:
			return item
	return {}

func _find_item(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if item is Dictionary and String(item.get("id", "")) == item_id:
			return item
	return {}

func _find_item_at_slot(items: Array, slot: int) -> Dictionary:
	for item in items:
		if item is Dictionary and int(item.get("slot_index", 0)) == slot:
			return item
	return {}

func _item_quantity(items: Array, item_id: String) -> int:
	var total := 0
	for item in items:
		if item is Dictionary and String(item.get("id", "")) == item_id:
			total += int(item.get("quantity", 0))
	return total

func _total_item_quantity(bag: Array, storage: Array, item_id: String) -> int:
	return _item_quantity(bag, item_id) + _item_quantity(storage, item_id)

func _first_free_storage_slot(items: Array, capacity: int) -> int:
	for slot in range(1, capacity + 1):
		if _find_item_at_slot(items, slot).is_empty():
			return slot
	return 0

func _first_life_entry(map_id: String, kind: String) -> Dictionary:
	var file := FileAccess.open(MAP_RESOURCES.map_data_path(map_id), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	if not parsed is Dictionary:
		return {}
	var life = parsed.get("life", {})
	var entries: Array = life.values() if life is Dictionary else life if life is Array else []
	for entry in entries:
		if entry is Dictionary and String(entry.get("type", "")) == kind:
			return entry
	return {}

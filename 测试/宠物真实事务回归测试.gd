extends SceneTree

const PET_MAP_ID := 101040000
const EQUIPMENT_ITEM_ID := 2010010
## 尾兽残魂(九尾)。⚠️ 原先是 16010013 —— 那是**数据_扩展里的自造 id**，2.2.3 目录里没有，
## 用例因此在"未收到权威宠物或背包快照"那步永远红。真值出自 GameData
## `Pet.00000404.info.evolution`（服务端 `_fuse_pet_soul` 读的同一行）：
## `needItemId=16000178`、`needItemCnt=6000`、`needMoney=30000000`。
const FUSION_MATERIAL_ID := 16000178
const FUSION_MATERIAL_COUNT := 6000
## 兽铠 `2010010` 落在宠物的**第 1 槽**（`EquipmentPosition.as` 的 PetA = 正数 1，
## 客户端同一个值在 `脚本/单例/装备部位.gd` 的 `宠物一`）。**卸装**报文要的就是这个槽号。
const EQUIPMENT_PET_SLOT := 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少后端连接单例")
		return
	backend.sync_character()
	if not await _wait_until(func(): return backend.in_game, 10000):
		_fail("无法进入真实后端：%s - %s" % [backend.status, backend.detail])
		return
	if not await _wait_until(func(): return not backend.authoritative_pets.is_empty() and not _find_item(backend.authoritative_inventory, EQUIPMENT_ITEM_ID).is_empty() and _item_quantity(backend.authoritative_inventory, FUSION_MATERIAL_ID) == FUSION_MATERIAL_COUNT, 5000):
		_fail("未收到权威宠物或背包快照")
		return

	var pet: Dictionary = backend.authoritative_pets[0]
	var pet_id := int(pet.get("unique_id", 0))
	var equipment := _find_item(backend.authoritative_inventory, EQUIPMENT_ITEM_ID)
	if pet_id <= 0 or equipment.is_empty():
		_fail("数据库夹具宠物或兽铠没有进入权威快照")
		return
	var equipment_unique_id := int(equipment.get("unique_id", 0))
	if not backend.request_pet_put_equipment(pet_id, int(equipment.get("slot_index", 0))):
		_fail("宠物穿戴请求未发送")
		return
	if not await _wait_until(func(): return _pet_has_equipment(backend.authoritative_pets, pet_id, equipment_unique_id) and _find_unique_item(backend.authoritative_inventory, equipment_unique_id).is_empty(), 4000):
		_fail("穿戴后原物品实例未从背包转移到宠物槽")
		return
	if not backend.request_pet_take_off_equipment(pet_id, EQUIPMENT_PET_SLOT):
		_fail("宠物卸装请求未发送")
		return
	if not await _wait_until(func(): return not _pet_has_equipment(backend.authoritative_pets, pet_id, equipment_unique_id) and not _find_unique_item(backend.authoritative_inventory, equipment_unique_id).is_empty(), 4000):
		_fail("卸装后原物品实例未返回背包")
		return

	# —— 客户端那一刀：从**背包格**一路走到佩戴包（2026-10-18 巡检 #27）——
	# 上面两条只证明"服务端认 `PET_ACTION 15/16`"。客户端当时送的**根本不是这条**：
	# 兽铠也进 `useItem` → `request_item_move(0, 格, 1..5, 0)`，而服务端 `handle_item_move`
	# 只把 **destination < 0** 当装备位（`fake_flash_server.py:47534`），**正数 = 背包格**
	# ⇒ "给宠物穿"实际变成"把这一件和背包第 1..5 格对调"，一件也没穿上、背包还乱两格。
	# 这条从 `会话.use_inventory_slot(格)` 起发，验三层：**没附身就拒（一个包都不发）**、
	# 附身后**真把件穿到宠物身上**、**背包那一格真空了**。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_fail("缺少 GameSession 单例")
		return
	if not await _wait_until(func(): return not (会话.inventory as Array).is_empty(), 4000):
		_fail("会话的权威背包镜像没同步过来")
		return
	# 按**实例号**找格：上面那次卸装是服务端挑格落回的，格号不保证还是原来那一格。
	# （**声明成具体类型**再交给 `_wait_until`/`.call()` —— 赋给 `Callable` 形参会触发
	#   4.7 的 `Local func can only be used as a Callable` 解析错。）
	var 找格: Callable = func() -> int:
		for 序 in 会话.inventory.size():
			if int((会话.inventory[序] as Dictionary).get("unique_id", 0)) == equipment_unique_id:
				return 序 + 1
		return 0
	if 找格.call() == 0:
		_fail("权威背包镜像里没有那件兽铠（卸装没回到会话？）")
		return
	# 先把**附身位腾空**：夹具可能是上一次跑剩下的态，不腾就测不到"没附身"那一闸
	# （原版 `PetHandler.petPutOnEquip` 的 `FUSHEN_PROMPT_3`，语言表 :1895）。
	for 只 in 会话.pets:
		if bool((只 as Dictionary).get("attached", false)):
			backend.request_pet_call_back(int((只 as Dictionary).get("unique_id", 0)))
	if not await _wait_until(func(): return 会话.get_attached_pet().is_empty(), 4000):
		_fail("附身位清不干净，未附身那条没法测")
		return
	var 出声: Array[String] = []
	var 收集: Callable = func(文: String) -> void: 出声.append(文)
	会话.notification_requested.connect(收集)
	if bool(会话.call("use_inventory_slot", int(找格.call()))):
		_fail("未附身时从背包格佩戴不该返回成功")
	if 出声 != ["没有附身的通灵兽！"]:
		_fail("未附身该报 `PETHANDLER_FUSHEN_PROMPT_3:1895`，实测 %s" % str(出声))
	if _find_unique_item(backend.authoritative_inventory, equipment_unique_id).is_empty():
		_fail("未附身那一次把背包里的兽铠弄丢了（实例=%d 会话里的格=%d 宠物身上=%s）" % [
			equipment_unique_id, int(找格.call()),
			str(_实例号表(_find_pet(backend.authoritative_pets, pet_id).get("equipment", [])))])
	# 召出 = 原版"附身"（服务端 `_activate_pet(pet, PetPosition.ATTACHED)`，客户端 `attached` = position 0）
	if not backend.request_pet_call_out(pet_id):
		_fail("召出（附身）请求未发送")
	if not await _wait_until(func(): return not 会话.get_attached_pet().is_empty(), 4000):
		_fail("附身回帧没落到会话（`attached` = position 0）")
		return
	出声.clear()
	var 佩戴格 := int(找格.call())
	if 佩戴格 == 0 or not bool(会话.call("use_inventory_slot", 佩戴格)):
		_fail("附身后从背包格佩戴应成功，实测格=%d 出声=%s" % [佩戴格, str(出声)])
	if not await _wait_until(func(): return _穿戴到位(backend, pet_id, equipment_unique_id), 4000):
		_fail("客户端那条没把兽铠穿到宠物身上（或背包格没清）—— 就是 2026-10-18 修的包级损坏")
	if not 出声.is_empty():
		_fail("成功那条路径不该出声，实测 %s" % str(出声))
	# 收尾还原：卸下 + 收回，后面的融魂/捕捉腿拿到的还是原样的夹具。
	if not backend.request_pet_take_off_equipment(pet_id, EQUIPMENT_PET_SLOT):
		_fail("客户端佩戴后的卸装请求未发送")
	if not await _wait_until(func(): return _卸下归包(backend, pet_id, equipment_unique_id), 4000):
		_fail("客户端佩戴这条不可逆（卸不下来）")
	backend.request_pet_call_back(pet_id)
	if not await _wait_until(func(): return 会话.get_attached_pet().is_empty(), 4000):
		_fail("收尾没把附身位清回去")
		return
	会话.notification_requested.disconnect(收集)

	# —— ④ 服务端**真拒绝**腿（2026-10-18 巡检 #28）——
	# 上面那条「没有附身的通灵兽！」是**客户端本地**拦的（语言表 :1895 那句）。服务端自己拒的那些
	# 走的是 `CHAT_MESSAGE` 的 `MessagePosition.CHAR_NOTICE(512)`：夹具
	# `_put_on_pet_equipment:39036-39043` 对 `bag_slot <= 0` 或非装备格直接
	# `_send_system_chat("请放入通灵兽装备。")` ⇒ `_send_character_notice:40422-40439`
	# ⇒ `1536:1:512:请放入通灵兽装备。:系统:…`。这条一次钉三层：**服务端真发了这一位**、
	# **文本逐字是服务端的**（不是本地那份语言表）、**客户端把它送进了提示口子**
	# （`后端连接._handle_chat_text` ⇒ `notification_requested`）。
	# ⚠️ 服务端对同一句话有 1.5 秒**去重**（`:40301-40303`），所以这条只发一次、别改不成环发。
	var 拒帧: Array[Dictionary] = []
	var 拒提示: Array[String] = []
	var 收拒: Callable = func(件: Dictionary) -> void: 拒帧.append(件)
	var 收提示: Callable = func(文: String) -> void: 拒提示.append(文)
	backend.chat_received.connect(收拒)
	会话.notification_requested.connect(收提示)
	if not backend.request_pet_put_equipment(pet_id, 0):
		_fail("真拒绝腿：非法格（0 号）的穿戴请求没发出去")
	if not await _wait_until(func(): return 拒提示.has("请放入通灵兽装备。"), 4000):
		_fail("服务端那句拒绝没走到提示口子：chat 收到 %s / 提示收到 %s" % [str(拒帧), str(拒提示)])
	if 拒帧.is_empty():
		_fail("拒绝腿没观察到任何 chat 帧（`chat_received` 那份接线断了？）")
	var 那件: Dictionary = {}
	for 件 in 拒帧:
		if String((件 as Dictionary).get("message", "")) == "请放入通灵兽装备。":
			那件 = 件
	if 那件.is_empty():
		_fail("收到的 chat 帧里没有服务端那句拒绝：%s" % str(拒帧))
	elif int(那件.get("positions", 0)) != 512:
		_fail("服务端拒绝必须落在 CHAR_NOTICE(512)，实得 positions=%s" % str(那件.get("positions", 0)))
	backend.chat_received.disconnect(收拒)
	会话.notification_requested.disconnect(收提示)
	# 拒绝不该动任何账：那件兽铠还在背包、宠物身上还是空的
	if _find_unique_item(backend.authoritative_inventory, equipment_unique_id).is_empty():
		_fail("非法格那一次把背包里的兽铠弄丢了（实例=%d）" % equipment_unique_id)

	if _item_quantity(backend.authoritative_inventory, FUSION_MATERIAL_ID) != FUSION_MATERIAL_COUNT:
		_fail("尾兽残魂(九尾)夹具数量异常")
		return
	if not backend.request_pet_soul_fusion(pet_id, 8):
		_fail("宠物融魂请求未发送")
		return
	if not await _wait_until(func(): return int(_find_pet(backend.authoritative_pets, pet_id).get("item_id", 0)) == 404 and _pet_has_skill(backend.authoritative_pets, pet_id, 123) and _item_quantity(backend.authoritative_inventory, FUSION_MATERIAL_ID) == 0, 4000):
		_fail("融魂未原子更新形态、技能并扣除对应残魂")
		return

	var original_map_id := int(backend.authoritative_map_id)
	var original_pet_count: int = backend.authoritative_pets.size()
	if not backend.request_map_change(PET_MAP_ID, 665, 1132):
		_fail("无法进入通灵兽捕捉地图")
		return
	if not await _wait_until(func(): return int(backend.authoritative_map_id) == PET_MAP_ID, 6000):
		_fail("服务端未确认通灵兽地图切换")
		return
	backend.send_movement(Vector2(665, 1132), 1)
	if not await _wait_until(func(): return not _find_monster(backend.map_monsters, 4000000).is_empty(), 5000):
		_fail("原始地图的可捕捉通灵兽未通过 238 生成")
		return
	var monster := _find_monster(backend.map_monsters, 4000000)
	backend.send_movement(Vector2(float(monster.x), float(monster.y)), 1)
	await create_timer(0.5).timeout
	if not backend.request_pet_catch(int(monster.object_id)):
		_fail("捕捉请求未发送")
		return
	if not await _wait_until(func(): return backend.authoritative_pets.size() == original_pet_count + 1 and not backend.map_monsters.has(int(monster.object_id)), 5000):
		_fail("捕捉未原子创建宠物并移除地图怪物")
		return
	if _find_new_pet(backend.authoritative_pets, pet_id, 101).is_empty():
		_fail("捕捉结果没有生成对应宠物定义")
		return
	if original_map_id > 0:
		backend.request_map_change(original_map_id, 0, 0)
		await _wait_until(func(): return int(backend.authoritative_map_id) == original_map_id, 5000)
	print("宠物真实事务回归测试：通过（装备实例可逆、客户端背包格佩戴链真穿上、服务端真拒绝走 CHAR_NOTICE(512) 进提示、九尾融魂原子扣料、地图通灵兽真实捕捉）")
	backend.disconnect_backend()
	quit(0)

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _find_item(items: Array, item_id: int) -> Dictionary:
	for item in items:
		if item is Dictionary and int(item.get("id", 0)) == item_id:
			return item
	return {}

func _find_unique_item(items: Array, unique_id: int) -> Dictionary:
	for item in items:
		if item is Dictionary and int(item.get("unique_id", 0)) == unique_id:
			return item
	return {}

func _find_pet(pets: Array, unique_id: int) -> Dictionary:
	for pet in pets:
		if pet is Dictionary and int(pet.get("unique_id", 0)) == unique_id:
			return pet
	return {}

func _find_new_pet(pets: Array, original_id: int, item_id: int) -> Dictionary:
	for pet in pets:
		if pet is Dictionary and int(pet.get("unique_id", 0)) != original_id and int(pet.get("item_id", 0)) == item_id:
			return pet
	return {}

func _pet_has_equipment(pets: Array, unique_id: int, equipment_unique_id: int) -> bool:
	for item in _find_pet(pets, unique_id).get("equipment", []):
		if item is Dictionary and int(item.get("unique_id", 0)) == equipment_unique_id:
			return true
	return false

## 客户端那条佩戴链的**两半**：穿上 = 实例进了宠物槽**且**离开背包；卸下 = 反过来。
## 写成函数而不是把长判断塞进 `_wait_until` —— 单行 lambda 不能跨行。
func _穿戴到位(backend: Node, unique_id: int, 实例号: int) -> bool:
	var 穿上 := _pet_has_equipment(backend.authoritative_pets, unique_id, 实例号)
	var 离包 := _find_unique_item(backend.authoritative_inventory, 实例号).is_empty()
	return 穿上 and 离包

func _卸下归包(backend: Node, unique_id: int, 实例号: int) -> bool:
	var 脱下 := not _pet_has_equipment(backend.authoritative_pets, unique_id, 实例号)
	var 归包 := not _find_unique_item(backend.authoritative_inventory, 实例号).is_empty()
	return 脱下 and 归包

func _pet_has_skill(pets: Array, unique_id: int, skill_id: int) -> bool:
	for skill in _find_pet(pets, unique_id).get("skills", []):
		if skill is Dictionary and int(skill.get("id", 0)) == skill_id:
			return true
	return false

## 只在**诊断**用：把一份列表里的 `unique_id` 挑出来（空洞 `{}` 跳过）。
func _实例号表(items) -> Array:
	var 出: Array = []
	for 条 in items:
		if 条 is Dictionary and not (条 as Dictionary).is_empty():
			出.append(int((条 as Dictionary).get("unique_id", 0)))
	return 出

func _item_quantity(items: Array, item_id: int) -> int:
	var total := 0
	for item in items:
		if item is Dictionary and int(item.get("id", 0)) == item_id:
			total += int(item.get("quantity", 0))
	return total

func _find_monster(monsters: Dictionary, monster_id: int) -> Dictionary:
	for monster in monsters.values():
		if monster is Dictionary and int(monster.get("monster_id", 0)) == monster_id:
			return monster
	return {}

func _fail(message: String) -> void:
	push_error("宠物真实事务回归测试：失败 - %s" % message)
	quit(1)

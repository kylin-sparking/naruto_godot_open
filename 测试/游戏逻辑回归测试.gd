extends SceneTree

const TEST_SESSION := preload("res://测试/测试游戏会话.gd")
const TEST_ACTIVITY := preload("res://测试/测试活动服务.gd")
const BACKEND_CONNECTION := preload("res://脚本/单例/后端连接.gd")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := TEST_SESSION.new()
	root.add_child(session)
	await process_frame
	_check(BACKEND_CONNECTION.DEFAULT_PORT == 18684, "客户端默认连接一键端 Flash TCP 端口")
	_check(int(session.game_settings.backend_port) == 18684, "离线默认设置应使用一键端端口")
	session.game_settings["backend_port"] = 28523
	session.game_settings["backend_url"] = "http://127.0.0.1:8081"
	session.game_settings["backend_account"] = "naruto"
	session.game_settings["backend_password"] = "old-password"
	session.call("_migrate_backend_settings")
	_check(int(session.game_settings.backend_port) == 18684, "旧后端端口应迁移到一键端")
	_check(String(session.game_settings.backend_url) == "http://127.0.0.1:18680/ruffle.html", "旧网页入口应迁移到一键端")
	_check(String(session.game_settings.backend_account) == "a33047518511@gmail.com", "旧默认账号应迁移到一键端现有账号")
	_check(String(session.game_settings.backend_password) == "123456", "旧默认账号迁移后应使用新密码")

	var base_attack := int(session.player_stats.attack)
	_check(session.equip_item("01010011"), "新手武器应能装备")
	_check(int(session.player_stats.attack) > base_attack, "装备后攻击力应提升")

	# ---- 每一类槽位都要穿得上：**不能只验武器** ----
	# ⚠️ 2026-09-27 用户报"背包里的装备，除了武器都不能佩戴"。查证结果：装备位映射本身是好的
	#    （对着服务端 607 件装备逐件比过，0 处不符），**但这条用例当时只断言了上面那一件武器** ——
	#    非武器槽位一个都没验过，所以下面这类问题一直没人发现：
	#    `equip_item` 原来用 `category == "装备"` 判"是不是装备"，而 `数据/物品.json` 里
	#    **神器 / 灵器 / 魂戒** 三类的分类名不是"装备"（原版判据是
	#    `EquipmentPosition.getItemEquipPosition(id)` 认不认得出装备位）→ 这三类被静默拒掉，
	#    连提示都没有。把每一类都试一遍，这种"只做了一部分"的缺口就藏不住了。
	# 等级门槛：样品里最高的灵器要 60 级，临时抬到 100 再还原。
	var 原等级 := int(session.player_stats.get("level", 1))
	session.player_stats["level"] = 100
	var 各槽样品 := {
		"手套": "01020010", "衣服": "01030013", "护额": "01040013", "护腰": "01050013",
		"忍鞋": "01060013", "斗笠": "01070010", "项链": "01080010", "戒指": "01090010",
		"手环": "01100010", "忍包": "01110010", "斗篷": "01120010", "勾玉": "01200010",
		"变身": "01210001", "徽章": "01410001", "羁绊": "19010001", "神器剑": "17100001",
		"神器镜": "17200001", "灵器": "20100001",
	}
	for 槽名 in 各槽样品:
		var 样品id: String = 各槽样品[槽名]
		var 样品位: int = int(装备部位表.位置(样品id))
		if 样品位 == 0:
			_check(false, "%s 的样品 id %s 解析不出装备位（样品本身错了）" % [槽名, 样品id])
			continue
		session.inventory.append({
			"id": 样品id, "quantity": 1, "slot_index": 90 + session.inventory.size(),
			"category": String(load("res://脚本/单例/游戏数据.gd").item(int(样品id)).get("category", "装备")),
			"req_level": 1,
		})
		_check(session.equip_item(样品id), "%s（%s）应能装备" % [槽名, 样品id])
	session.player_stats["level"] = 原等级

	# ---- 菜单里的「佩戴」不能因为 id 写法不同而消失 ----
	# 背景（2026-09-27 用户报"装备不是非要拖到角色面板，本身还有一个佩戴选项"）：
	#   * **服务端下发的 id 是整数形态**（`str(int)` → `"1030013"`，七位），
	#     而 `数据/物品.json` 与离线样例是**八位补零**（`"01030013"`）；
	#   * `物品菜单.取菜单项` 按 `substr(0,2)` 取类型号 —— 七位那份取到 `"10"`
	#     （任务物品档），八位那份取到 `"01"`（装备-玩家档）。
	#   于是**在线时装备的菜单里根本没有「佩戴」**，离线反而正常，一直没人发现。
	#   判据：同一个 id 的两种写法必须给出**同一份**菜单，且装备那份必须有「佩戴」。
	var 菜单 := preload("res://脚本/界面/组件/物品菜单.gd")
	for 装备id in ["01010013", "01030013", "01040013", "01060013", "01120010", "01200010"]:
		var 八位项: Array = 菜单.取菜单项({"id": 装备id, "quantity": 1}, false)
		var 七位项: Array = 菜单.取菜单项({"id": str(int(装备id)), "quantity": 1}, false)
		_check(八位项 == 七位项, "%s 的菜单不该因 id 写法不同而变（八位 %s / 七位 %s）"
			% [装备id, 八位项, 七位项])
		_check(八位项.has("佩戴"), "%s 的菜单里应有「佩戴」" % 装备id)
	# ⚠️ 判据改了（§3.29.6）：**离线时这些服务端权威的操作一律被拒绝，且不得改动本地状态**。
	#    原来这里断言"离线也能强化、强化等级变 1" —— 那是在**钉住一套编的离线公式**
	#    （`cost = (等级+1)*100` + 100% 成功率，真值见 装备打造表.gd:33-35）。
	#    而且这些分支不是只有测试走得到：`_fail_connection()` 把 in_game 清成 false
	#    **却不换场景** —— 断线后玩家真能点到，点了就本地改属性。
	var 金币前 := int(session.player_stats.gold)
	var 强化前 := int(session.equipped_items[装备部位表.武器].get("strengthen", 0))
	_check(not session.strengthen_equipment(装备部位表.武器), "离线时强化应被拒绝")
	_check(int(session.player_stats.gold) == 金币前, "离线时强化不得扣本地金币")
	_check(int(session.equipped_items[装备部位表.武器].get("strengthen", 0)) == 强化前, "离线时强化不得改本地装备")

	var original_mp := int(session.player_stats.mp)
	_check(session.use_skill(0), "主动忍术应能施放")
	_check(int(session.player_stats.mp) < original_mp, "主动忍术应消耗查克拉")
	_check(not session.bind_skill_to_slot("0001001", 2), "被动忍术不应绑定快捷栏")
	_check(session.bind_skill_to_slot("1001001", 7), "主动忍术应能绑定到指定快捷格")
	session.call("_rebuild_skill_slots")
	_check(String(session.skill_slots[7].get("id", "")) == "1001001", "快捷栏重建后应保留原槽位")
	_check(String(session.skill_slots[0].get("id", "")).is_empty(), "同一忍术不应重复占用快捷格")
	# 学习要**背包里真有那本书**（2026-10-20 起照服务端 `_learn_skill`：按 `reqBook` 消耗，
	# 不再认离线示例目录 `skill_book_catalog` —— 真书对应的技能在那里一条都没有）。
	session.player_stats["level"] = maxi(int(session.player_stats.get("level", 1)), 11)
	session.inventory.append({"id": "06000016", "quantity": 1, "slot_index": 91})
	_check(session.learn_skill_from_book("1002001"), "应能通过技能书学习新忍术")
	_check(_has_skill(session.learned_skills, "1002001"), "技能书忍术应加入已学列表")
	var 书还在 := false
	for 物品 in session.inventory:
		if String(物品.get("id", "")).pad_zeros(8) == "06000016" and int(物品.get("quantity", 0)) > 0:
			书还在 = true
	_check(not 书还在, "学会忍术后技能书应被消耗")
	session.apply_backend_character({"name": "后端忍者", "level": 9, "maxHp": 222, "maxMp": 133, "vipLevel": 4})
	_check(session.player_stats.name == "后端忍者" and int(session.player_stats.level) == 9, "应同步后端角色基础字段")
	_check(int(session.player_stats.max_hp) == 222 and int(session.player_stats.max_mp) == 133, "应兼容后端驼峰字段")
	_check(int(session.hud_state.vip_level) == 4 and int(session.player_stats.vip) == 4, "VIP 等级应从后端角色状态同步到头像 HUD")
	session.apply_backend_item_effect("attribute_boost", {"item_id": 3000001, "remaining_seconds": 120, "total_seconds": 300})
	_check((session.hud_state.effects as Array).size() == 1, "后台限时物品效果应进入头像 HUD")
	session.apply_backend_item_effect("attribute_boost", {"item_id": 3000001, "remaining_seconds": 0, "total_seconds": 300})
	_check((session.hud_state.effects as Array).is_empty(), "后台限时物品效果结束后应从头像 HUD 移除")
	var map_npcs: Array[Dictionary] = session.get_map_npcs("101010000")
	_check(map_npcs.size() == 7, "终结谷浅滩应从原版 life 表取得 7 个 NPC")
	_check(String(map_npcs[0].get("name", "")) == "浅野爷爷", "地图 NPC 名称应从 NPC 数据表取得")

	# ⚠️ 这条要在**离线**路径上验：上面 `apply_backend_character` 已经把 `backend_authoritative`
	#    打开了，而**在线时人物属性只认服务端**（`游戏会话._recalculate_stats()` 直接返回，那边有依据）——
	#    本地这套公式是自造的离线模型，在线跑它会把服务端的 hp/mp/攻击整个盖掉
	#    （实测：服务端 mp=5633，界面上一直是 80/80）。所以先放掉权威标记，验离线那条。
	session.backend_authoritative = false
	var attack_without_pet := int(session.player_stats.attack)
	session.set_pet_deployed("00000101", true)
	_check(int(session.player_stats.attack) > attack_without_pet, "离线时宠物出战应提高人物战力")
	_check(String(session.get_deployed_pet().get("id", "")) == "00000101", "应能取得当前出战宠物")
	# ⚠️ 同上：离线时宠物培养**一律拒绝、不得动本地状态**（§3.29.6）。
	#    原来这里断言"资质丹能用于培养、攻击提升" —— 钉的是那套编的离线数值
	#    （`stage/attack/defense/max_faith` 各 +N）。
	#    「升级宠物技能」那条腿随 `upgrade_pet_skill` 一起删了：它把**技能 id** 塞进
	#    `PET_ACTION 8`，而服务端要的是技能书**物品 id**，生产代码零调用点（§3.384）。
	var pet_attack_before := int(session.get_deployed_pet().get("attack", 0))
	_check(not session.train_pet("00000101"), "离线时宠物培养应被拒绝")
	_check(int(session.get_deployed_pet().get("attack", 0)) == pet_attack_before, "离线时宠物培养不得改属性")

	## 档位一律按 `NpcQuestStatus.as:5-13` 的**整数**断（1 可接 / 2 可交 / 3 进行中），
	## 不再断字符 —— 原来这两条断的是 "!" / "?"，而"进行中"被画成叹号正是
	## `get_quest_marker()` 把枚举读反（写成「1 进行中 / 2 可接 / 3 可交」）带出来的错期望。
	## 原版"进行中"是**银灰问号**（`NPCQuestPopup.as:26-28` → `QuestIcon_1`），
	## 只有"可交"才是金色问号（`:30-32` → `QuestIcon_2`）。
	_check(int(session.npc_quest_status("00000001")) == 3,
			"接了任务、交谈还没完的 NPC 应是「进行中」档(3)，不是可接/可交")
	session.complete_npc_talk("00000001")
	_check(int(session.npc_quest_status("00000001")) == 2,
			"交谈目标完成后应升到「可交」档(2)")
	_check(session.claim_quest_reward("1003"), "初始交谈任务应能领取奖励")

	_check(session.accept_quest("1004"), "应能接受击杀任务")
	for _kill in range(3):
		session.progress_quest("守财鼠")
	var kill_quest := _find_quest(session.accepted_quests, "1004")
	_check(not kill_quest.is_empty() and bool(kill_quest.completed), "三次击杀应完成任务")
	_check(session.claim_quest_reward("1004"), "完成的任务应能领取奖励")
	_check(not _find_quest(session.available_quests, "1005").is_empty(), "领取主线奖励后应解锁后续任务")
	_check(session.accept_quest("1005"), "应能接受后续修炼任务")
	_check(session.accept_quest("2001"), "应能接受每日修炼任务")
	session.perform_training()
	_check(not bool(_find_quest(session.accepted_quests, "1005").get("completed", false)),
		"离线时修炼应被拒绝、不推进任务")
	# 任务推进改用**任务自己的接口**：`progress_quest` 是本地任务追踪（战斗/动作都会调它），
	# 不属于"离线自造奖励"，所以不受 §3.29.6 影响。
	session.progress_quest("修炼")
	_check(bool(_find_quest(session.accepted_quests, "1005").get("completed", false)), "progress_quest 应推进主线修炼任务")
	_check(session.claim_quest_reward("2001"), "完成的日常任务应能领取奖励")
	session.daily_quest_day -= 1
	session.call("_reset_daily_quests_if_needed")
	_check(not _find_quest(session.available_quests, "2001").is_empty(), "日常任务应在次日重置")

	_check(session.add_friend("测试忍者"), "应能添加好友")
	session.remove_friend("测试忍者")
	_check(not _has_friend(session.friends, "测试忍者"), "应能删除好友")
	session.create_team()
	_check(session.invite_team_member("队友甲"), "应能邀请队友")
	_check(session.team_members.size() == 2, "队伍人数应更新")
	session.leave_team()
	_check(session.team_members.is_empty(), "应能退出队伍")
	session.selected_npc_id = "00000002"
	_check(not session.get_selected_npc_shop().is_empty(), "武器商人应提供独立商品目录")
	_check(session.buy_npc_item("01010021"), "应能从 NPC 商店购买武器")
	var purchased_weapon := _find_inventory_item(session.inventory, "01010021")
	_check(not purchased_weapon.is_empty() and purchased_weapon.get("category") == "装备", "NPC 武器应按装备类型进入背包")
	_check(session.deposit_item("01010021"), "未装备物品应能存入仓库")
	_check(_find_inventory_item(session.inventory, "01010021").is_empty() and not _find_inventory_item(session.storage, "01010021").is_empty(), "存入后物品应移动到仓库")
	_check(session.withdraw_item("01010021"), "仓库物品应能取回")
	_check(session.sell_inventory_item("01010021"), "NPC 商店应能出售背包物品")
	var potion_before := int(_find_inventory_item(session.inventory, "03000001").get("quantity", 0))
	_check(session.deposit_item("03000001", 3), "可堆叠物品应能部分存入")
	_check(int(_find_inventory_item(session.inventory, "03000001").get("quantity", 0)) == potion_before - 3, "部分存入后背包数量应减少")
	_check(int(_find_inventory_item(session.storage, "03000001").get("quantity", 0)) == 3, "仓库应收到指定数量")
	_check(session.withdraw_item("03000001", 2), "仓库物品应能部分取回")
	_check(int(_find_inventory_item(session.storage, "03000001").get("quantity", 0)) == 1, "部分取回后仓库应保留余量")
	_check(session.sell_inventory_item("03000001", 2), "商店应能按指定数量出售")
	var gold_before_storage := int(session.player_stats.gold)
	_check(session.deposit_storage_gold(100), "仓库应能存入金币")
	_check(int(session.storage_gold) == 100 and int(session.player_stats.gold) == gold_before_storage - 100, "存入金币后余额应同步")
	_check(session.withdraw_storage_gold(40), "仓库应能取出金币")
	_check(int(session.storage_gold) == 60 and int(session.player_stats.gold) == gold_before_storage - 60, "取出金币后余额应同步")

	# 闭关收益同理：离线不再本地自算（原来是 `经验 = 分钟 × 2`，服务端是 `分钟 × 等级 × 50`）。
	session.last_retreat_claim_unix = int(Time.get_unix_time_from_system()) - 120
	_check(int(session.get_retreat_rewards().get("minutes", -1)) == 0, "离线时闭关收益应为空，不再本地自算")
	_check(not session.claim_retreat_reward(), "离线时领取闭关收益应被拒绝")

	session.update_setting("auto_combat", true)
	_check(bool(session.game_settings.auto_combat), "挂机开关应保存状态")

	var activity := TEST_ACTIVITY.new()
	root.add_child(activity)
	activity.set("_session", session)
	await process_frame
	# ⚠️ 这些原来断言"离线也能签到/领福利/兑换/挖矿/藏宝/首领/遗址" —— 那是在钉住
	#    `活动服务.gd` 里 7 条编的奖励数（签到 `20+连签×5`、挖矿 25/80、藏宝 100/200、
	#    首领 400/300、遗址 250/200 …）。现在改成断言**离线一律拒绝、且不动本地状态**。
	_check(not activity.check_in(), "离线时签到应被拒绝")
	_check(not activity.claim_daily_benefit(), "离线时领取每日福利应被拒绝")
	_check(not activity.redeem_code("NARUTO2026"), "离线时礼包兑换应被拒绝")
	_check(not activity.mine(), "离线时挖矿应被拒绝")
	_check(not activity.explore_treasure(), "离线时藏宝应被拒绝")
	_check(not activity.start_boss_challenge(), "离线时首领挑战应被拒绝")
	_check(not activity.start_ruins_challenge(), "离线时遗址探索应被拒绝")
	_check(int(activity.state.mining_attempts) == 3 and int(activity.state.treasure_scrolls) == 1,
		"离线时不得消耗每日次数（挖矿/藏宝次数应保持初值）")
	_check(int(activity.state.boss_attempts) == 1 and int(activity.state.ruins_attempts) == 1,
		"离线时不得消耗首领/遗址次数")
	# `cycle_pk_mode` 只是本地切换一个枚举、没有自造数值，仍然保留原行为。
	var old_mode := String(activity.state.pk_mode)
	_check(activity.cycle_pk_mode() != old_mode, "战斗状态应能循环切换")

	if _failures.is_empty():
		print("游戏逻辑回归测试：通过")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _find_quest(quests: Array, quest_id: String) -> Dictionary:
	for quest in quests:
		if String(quest.get("id", "")) == quest_id:
			return quest
	return {}

func _has_friend(friends: Array, player_name: String) -> bool:
	for friend in friends:
		if String(friend.get("name", "")) == player_name:
			return true
	return false

func _has_skill(skills: Array, skill_id: String) -> bool:
	for skill in skills:
		if String(skill.get("id", "")) == skill_id:
			return true
	return false

func _find_inventory_item(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if String(item.get("id", "")) == item_id:
			return item
	return {}

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

extends RefCounted

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

static func create() -> Dictionary:
	return {
		"player_stats": {
			"name": "木叶忍者", "level": 80, "job": 100,   # 职业名由 job 查 `脚本/单例/职业.gd`，不在这里写死
			"hp": 100, "max_hp": 100, "mp": 80, "max_mp": 80,
			"exp": 35, "max_exp": 100,
			"ap_atk": 5, "ap_def": 5, "ap_dex": 5, "ap_phy": 5,
			"remaining_ap": 5, "remaining_sp": 4,
			"attack": 25, "defense": 18, "critical": 5, "dodge": 3,
			# ⚠️ 这两个键**必须在**，哪怕离线不显示也要留 —— `服务端会话同步.应用人物` 是
			# `if 会话.player_stats.has(目标字段)`，**键不存在就直接把后端来的值丢掉**。
			# 少了它俩的后果：服务端明明发了（原版协议 20/21 号字段），面板上"攻击速度""移动速度"恒为 0。
			# 默认值照原版：`CharacterSprite._attackSpeed:int = 100`、`CharacterStats.sec_wlkSpeed = 100`。
			"attack_speed": 100, "move_speed": 100,
			"fame": 0, "vip": 0, "shengwang": 0, "gold": 50000,
			"cash": 100, "zq": 5000, "laba_count": 0,
			# 点券（原版 `DataCenter.bandMoney`）。⚠️ 键**必须在** —— `应用人物` 是
			# `if 会话.player_stats.has(目标字段)`，缺键就把服务端发来的值静默丢掉
			# （与上面 attack_speed/move_speed 同一条坑）。
			"cash_bind": 0,
			# 家族名（原版 `DataCenter.guildName`：`DataCenter.as:1455` 把它塞进人物面板那份数据，
			# `CharPane.as:228` 渲染成「家族：X」，没族时是 `-`）。⚠️ 键**必须在**：
			# 面板读的就是 `属性.get("family", "-")`，缺键 ⇒ 已有家族也永远显示 `-`（本轮用户报修）。
			# 写入方是 `后端连接._同步家族到人物属性`（收 `1552:1/15` 自族身份时）；空串 = 未入族。
			"family": "",
			# ⭐ 罪恶值（服务端 `StatType.CRIME = 33`）。**人物属性窗那一行读的就是它**
			# （原版 `DataCenter.as:1464` `_loc1_.fame = this.stats.crime`、`:2359` 同）——
			# 我们原来错读了 `fame`（字段 26），而服务端**从不发 26** ⇒ 那行永远是旧数。
			# 键**必须在**（同上面那条坑）：warp 包(`fields[29]`)与 stats 推(33) 都靠它落地。
			"crime": 0,
			# 服务端会发、原版 `DataCenter.as` 也逐个处理，但**本客户端暂无对应界面**的字段
			# （原版人物窗也不画这几条）。先建键收下，**不再静默丢弃**，等做界面时直接用：
			#   28=绑金（原版只记账+出公告）/ 35=暗器触发 / 41,42,43=反弹·减免·无视防御 /
			#   39,40=职业技能等级加成·世界技能等级加成。
			"money_bind": 0, "anqi_trigger": 0,
			"damage_reflect": 0, "damage_reduce": 0, "ignore_def": 0,
			"add_job_skill_level": 0, "add_world_skill_level": 0,
		},
		"active_quest": {
			"id": "1003", "name": "初醒", "type": "主线", "request_level": 1,
			"description": "与暗部忍者-追交谈", "target_npc": "00000001",
			"progress": 0, "required": 1, "completed": false,
			"reward_exp": 50, "reward_gold": 100, "next_quest": "1004",
		},
		"available_quests": [
			{
				"id": "1004", "name": "忍者的试炼", "type": "主线", "request_level": 1,
				"description": "击败 3 只守财鼠", "progress": 0, "required": 3,
				"completed": false, "reward_exp": 120, "reward_gold": 300,
				"giver_npc": "00000001", "target": "守财鼠", "next_quest": "1005",
			},
			{
				"id": "2001", "name": "每日修炼", "type": "日常", "request_level": 5,
				"description": "完成一次基础修炼", "progress": 0, "required": 1,
				"completed": false, "reward_exp": 80, "reward_gold": 150,
			},
		],
		"quest_chain": {
			"1004": {
				"id": "1004", "name": "忍者的试炼", "type": "主线", "request_level": 1,
				"description": "击败 3 只守财鼠", "progress": 0, "required": 3,
				"completed": false, "reward_exp": 120, "reward_gold": 300,
				"giver_npc": "00000001", "target": "守财鼠", "next_quest": "1005",
			},
			"1005": {
				"id": "1005", "name": "查克拉控制", "type": "主线", "request_level": 2,
				"description": "完成一次基础修炼", "progress": 0, "required": 1,
				"completed": false, "reward_exp": 160, "reward_gold": 350,
				"giver_npc": "00000001", "target": "修炼", "next_quest": "1006",
			},
			"1006": {
				"id": "1006", "name": "同伴的认可", "type": "主线", "request_level": 3,
				"description": "与琉亚交谈", "progress": 0, "required": 1,
				"completed": false, "reward_exp": 220, "reward_gold": 500,
				"giver_npc": "00000001", "target_npc": "00000009",
			},
		},
		"inventory": [
			_item("01010011", {"slot": "武器", "quantity": 1, "attack": 8, "defense": 0}),
			_item("01020010", {"slot": "护额", "quantity": 1, "attack": 0, "defense": 5}),
			_item("01030011", {"slot": "衣服", "quantity": 1, "attack": 0, "defense": 8}),
			_item("03000001", {"quantity": 10, "hp": 250}),
			_item("04000001", {"quantity": 10, "mp": 100}),
			_item("16000014", {"quantity": 3}),
		],
		## 图标一律走 `数据/技能素材索引.json` 的原版链路（`技能.json` 的 icon_class → 索引 →
		## `素材/技能/<组>/skill/<Swf名>_1_<类名>.png`），不再用 9-21 那批中文占位图。
		## name 覆盖全部删掉 —— `_skill()` 底层就是 `GAME_DATA.skill(id)`，真名从技能表透出
		## （0001001=查克拉强化 / 0001002=仙法·聚气 / 0001003=仙法·查克拉守护 / 0002000=吸血）。
		"learned_skills": [
			_skill("1001001", {"level": 1, "mp_cost": 12, "cooldown": 3.0, "power": 35, "icon": "res://素材/界面/技能/技能_1001001.png"}),
			_skill("0001001", {"name": "查克拉修炼", "level": 50, "mp_cost": 0, "cooldown": 5.0, "power": 0, "icon": "res://素材/技能/基础忍术/查克拉修炼.png"}),
			_skill("0001002", {"name": "攻击强化", "level": 50, "mp_cost": 0, "cooldown": 8.0, "power": 0, "icon": "res://素材/技能/基础忍术/攻击强化.png"}),
			_skill("0001003", {"name": "防御强化", "level": 1, "mp_cost": 0, "cooldown": 10.0, "power": 0, "icon": "res://素材/技能/基础忍术/防御强化.png"}),
			_skill("0002000", {"name": "吸血", "level": 1, "mp_cost": 11, "cooldown": 6.0, "power": 18, "icon": "res://素材/技能/基础忍术/吸血.png"}),
		],
		"skill_book_catalog": [
			_skill("1002001", {"level": 1, "price": 500, "icon": "res://素材/界面/技能/技能_1001001.png"}),
			_skill("1003001", {"level": 1, "price": 1200, "icon": "res://素材/技能/基础忍术/攻击强化.png"}),
		],
		# 离线示例宠改成**服务端 31 字段的形状**（潜力/悟性/技能 id 都取模板 101 真值：
		# 一阶忍犬 apt1 potential 80..112、默认技能 101 猛击、speed apt1 = 15/3）。
		# 旧键（attack/stage/icon）是**错位名/自造字段**，战斗汇总与 宠物伙伴 还在读，先双写。
		"pets": [{
			"id": "00000101", "item_id": 101, "face": 101, "unique_id": 900001,
			"name": "1阶忍犬", "level": 1, "stage": 1, "aptitude": 1, "savvy": 10,
			"blessing": 0, "experience": 0, "faith": 200, "max_faith": 200, "ling_zhu": 0,
			"potential_real_atk": 80, "potential_real_def": 80, "potential_real_dex": 80, "potential_real_str": 80,
			"potential_total_atk": 112, "potential_total_def": 112, "potential_total_dex": 112, "potential_total_str": 112,
			"attack": 18, "defense": 12, "dexterity": 0, "strength": 0,
			"max_attack": 0, "max_defense": 0, "max_dexterity": 0, "max_strength": 0,
			"position": 1, "deployed": false, "attached": false,
			"icon": "res://素材/宠物/忍犬/一阶忍犬.png",
			"equipment": [],
			"skills": [{"id": 101, "name": "猛击", "level": 1, "master_level": 0}],
		}],
		"friends": [
			{"name": "暗部忍者-追", "level": 12, "online": true, "intimacy": 10},
			{"name": "小悟", "level": 5, "online": false, "intimacy": 3},
		],
		"guild": {"joined": false, "name": "", "level": 0, "contribution": 0, "members": 0},
		"shop_catalog": [
			_item("03000001", {"currency": "gold", "category": "药品"}),
			_item("04000001", {"currency": "gold", "category": "药品"}),
			_item("16000014", {"currency": "gold", "category": "宠物"}),
		],
		"npc_shop_items": _npc_shop_items(),
		"game_settings": {
			"music_volume": 0.7, "sound_volume": 0.8,
			"mute_music": false, "mute_sound": false, "fullscreen": false,
			"auto_pickup": true, "show_names": true, "show_other_characters": true,
			"show_skill_effects": true, "show_aura_effects": true,
			"low_hp_effect": true, "screen_shake": false, ## 起步不抖：对齐原版 `SysCfg.as:30` `_forbidEarthQuake = true`（那枚「遮罩暴击震屏」画成勾着）。
			## 这一族别的键都是"正向能力"（`show_names` 等），只有 `screen_shake` 起步是 false —— 因为它对应的原版量是反义的。
			"show_quest_tracker": true, "show_team_hp": true,
			"allow_whisper": true, "allow_friend_requests": true,
			"allow_trade_requests": true, "allow_group_invites": true,
			"auto_combat": false, "auto_attack_enabled": true,
			"auto_hp": true, "auto_mp": true, "auto_ep": false,
			"auto_rest": true, "auto_pick_consumables": true,
			"auto_pick_materials": true, "auto_skills": true,
			"auto_pet_skills": true, "auto_avoid_boss": false,
			## ⚠ `auto_battle_range` 的单位是原版的**格**（0~99，默认 20），不是像素：
			## `GuajiHandler.as:557-561` 活动区边长 = 格 × 50 像素 ⇒ 半宽 = 格 × 25。
			## 换算只发生在 `玩家.gd:_挂机活动半径像素()` 一处，别再往这键里塞像素。
			## 下面三个阈值/时长默认值全部照 `GuaJiSettingInfoData.as:46/76/38` 与服务端
			## `default_character_config`（旧版这里写的 45/30 是自造的，原版根本没那两个数）。
			"auto_battle_range": 20, "auto_battle_minutes": 240,
			"auto_hp_value": 70, "auto_mp_value": 50, "auto_battle_unlimited": false,
			"auto_skill_id": 0, "auto_pet_skill_id": 101, "auto_pick_quest": true,
			"auto_revive_in_place": false,
			"backend_url": "http://127.0.0.1:18680/ruffle.html",
			"backend_host": "127.0.0.1", "backend_port": 18684,
			"backend_account": "a33047518511@gmail.com", "backend_password": "123456",
		},
	}

static func _item(item_id: String, overrides: Dictionary) -> Dictionary:
	var item: Dictionary = GAME_DATA.item(item_id).duplicate(true)
	item.merge(overrides, true)
	return item

static func _skill(skill_id: String, overrides: Dictionary) -> Dictionary:
	var skill: Dictionary = GAME_DATA.skill(skill_id).duplicate(true)
	if skill.has("damage"):
		skill["power"] = int(skill.damage)
	skill.merge(overrides, true)
	return skill

static func _npc_shop_items() -> Array[Dictionary]:
	return [
		_item("01010021", {"vendor": "武器", "currency": "gold", "slot": "武器", "attack": 15, "defense": 0}),
		_item("01010022", {"vendor": "武器", "currency": "gold", "slot": "武器", "attack": 24, "defense": 0}),
		_item("01020020", {"vendor": "装备", "currency": "gold", "slot": "护额", "attack": 0, "defense": 10}),
		_item("01030021", {"vendor": "装备", "currency": "gold", "slot": "衣服", "attack": 0, "defense": 16}),
		_item("01040001", {"vendor": "装备", "currency": "gold", "slot": "忍鞋", "attack": 0, "defense": 6}),
		_item("01050001", {"vendor": "饰品", "currency": "gold", "slot": "项链", "attack": 3, "defense": 4}),
		_item("01060001", {"vendor": "饰品", "currency": "gold", "slot": "戒指", "attack": 4, "defense": 3}),
		_item("03000001", {"vendor": "药品", "currency": "gold", "category": "药品", "hp": 250}),
		_item("04000001", {"vendor": "药品", "currency": "gold", "category": "药品", "mp": 100}),
		_item("16000014", {"vendor": "杂货", "currency": "gold"}),
	]

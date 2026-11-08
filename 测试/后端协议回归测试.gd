extends SceneTree

const TEST_BACKEND := preload("res://测试/测试后端连接.gd")
const MAP_ENTITIES_SCRIPT := preload("res://脚本/地图/地图实体.gd")
const ORIGINAL_SPRITE_SCRIPT := preload("res://脚本/角色/原始动画精灵.gd")
const CAPTURE_PATH := "res://测试/原版协议抓包.json"

## `_run` 里**应该**跑到底的校验函数名单。加一个 `_validate_*` 就要往这里补一个 ——
## 少了它，那个函数被静默截断时对账就发现不了（对账的意义见 `_跑完的` 的说明）。
const 校验项 := [
	"_validate_login_and_character_list", "_validate_entity_packets", "_validate_ambiguous_remove",
	"_validate_combat_packets", "_validate_hud_state_packets", "_validate_inventory_deltas",
	"_validate_item_change_results", "_validate_item_effect_results", "_validate_shop_and_storage",
	"_validate_cash_shop_packets", "_validate_guild_packets", "_validate_social_packets",
	"_validate_reward_packets", "_validate_legacy_packets", "_validate_pet_packets",
	"_validate_copy_and_hang_packets", "_validate_map_isolation", "_validate_pre_game_spawn_gate",
	"_validate_remote_appearance_assets", "_validate_outgoing_requests", "_validate_no_local_online_rewards",
]

var _failures: Array[String] = []
## 每个 `_validate_*` 跑到底时把**自己的名字**追加进来。
## ⚠️ 为什么需要它：运行期脚本错误（例如给字典点号取一个不存在的键）会**中断当前函数**，
##    后面的断言一条都不跑，而 `_failures` 仍是空的 —— 整套用例照样打印"通过"（**假绿**）。
##    2026-09-25 实测栽过：删掉一个处理函数后，三个校验函数被静默截断，测试全绿。
##    `_run` 末尾拿它跟 `校验项` 对账，少一个就红。
var _跑完的: Array[String] = []
var _signals := {}
var _item_change_results: Array[Dictionary] = []
var _item_effect_results: Array[Dictionary] = []
## `237` 的落地观测：`[{物品号, 剩余秒}]`，按收到顺序。
var _物品冷却帧: Array[Dictionary] = []
var _shop_snapshots: Array[Dictionary] = []
var _shop_codes: Array[int] = []
var _storage_snapshots: Array[Dictionary] = []
var _pet_snapshots: Array[Dictionary] = []
var _pet_actions: Array[Dictionary] = []
var _skill_hits: Array[Dictionary] = []
var _copy_states: Array[Dictionary] = []
var _hang_states: Array[Dictionary] = []
## 1283 回帧解出来的那份字典（`char_config_received` 的最后一发）。
var 挂配置: Dictionary = {}
var _cash_shop_snapshots: Array[Dictionary] = []
var _cash_shop_capacities: Array[int] = []
var _cash_item_infos: Array[Dictionary] = []
var _guild_states: Array[Dictionary] = []
var _friend_states: Array[Dictionary] = []
var _party_states: Array[Dictionary] = []
var _vip_levels: Array[int] = []
var _pk_modes: Array[Dictionary] = []
var _weather_types: Array[int] = []
var _buff_snapshots: Array[Array] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := TEST_BACKEND.new()
	root.add_child(backend)
	_connect_signals(backend)
	_validate_login_and_character_list(backend)
	_validate_entity_packets(backend)
	_validate_combat_packets(backend)
	_validate_hud_state_packets(backend)
	_validate_inventory_deltas(backend)
	_validate_item_change_results(backend)
	_validate_item_effect_results(backend)
	_validate_shop_and_storage(backend)
	_validate_cash_shop_packets(backend)
	_validate_guild_packets(backend)
	_validate_social_packets(backend)
	_validate_reward_packets(backend)
	_validate_legacy_packets(backend)
	_validate_pet_packets(backend)
	_validate_copy_and_hang_packets(backend)
	_validate_map_isolation(backend)
	_validate_pre_game_spawn_gate(backend)
	_validate_remote_appearance_assets()
	_validate_outgoing_requests(backend)
	_validate_no_local_online_rewards()
	# ⚠️ 对账：每个校验函数跑到底都会往 `_跑完的` 里追加自己的名字。
	#    少一个就说明它**中途被运行期错误中断**了 —— 那种情况下后面的断言一条都没跑，
	#    而 `_failures` 是空的，整套用例会**假绿**。这里把它变成一条明账。
	for 名字 in 校验项:
		if not _跑完的.has(名字):
			_failures.append("%s 没跑到底：中途被运行期错误中断，后面的断言全都没执行（看上面的 SCRIPT ERROR）" % 名字)
	backend.free()
	if _failures.is_empty():
		print("后端协议回归测试：通过（登录/选角、实体、战斗、背包、打造、物品效果、NPC商店、仓库、宠物、副本、挂机、商城、帮会、社交、礼包、兑换、福袋、排行、成就、活跃度、卡牌、宝箱、料理、打坐、结印、暗器）")
		print("汇：判 %d 条 / 红 0 条（后端协议回归测试：通过）" % _判定数)
		quit(0)
		return
	print("汇：判 %d 条 / 红 %d 条（后端协议回归测试：失败）" % [_判定数, _failures.size()])
	for failure in _failures:
		push_error(failure)
	quit(1)

func _connect_signals(backend: Node) -> void:
	for signal_name in [
		"login_status_received", "character_list_received", "player_spawned", "player_removed",
		"player_moved", "player_damaged", "monster_spawned", "monster_removed", "monster_killed", "monster_moved",
		"monster_attacked", "monster_damaged", "monster_skill_hit", "monster_hp_changed", "npc_spawned",
		"map_drop_spawned", "map_drop_removed", "item_change_result_received", "item_effect_received",
	]:
		_signals[signal_name] = 0
		backend.connect(signal_name, _count_signal.bind(signal_name))
	backend.item_change_result_received.connect(_capture_item_change_result)
	backend.item_effect_received.connect(_capture_item_effect)
	backend.物品冷却变更.connect(func(物品号: int, 剩余秒: int): _物品冷却帧.append({"id": 物品号, "s": 剩余秒}))
	backend.npc_shop_received.connect(_capture_shop)
	backend.shop_transaction_received.connect(_capture_shop_code)
	backend.storage_received.connect(_capture_storage)
	backend.pets_received.connect(_capture_pets)
	backend.pet_action_received.connect(_capture_pet_action)
	backend.monster_skill_hit.connect(_capture_skill_hit)
	backend.copy_state_received.connect(func(state: Dictionary): _copy_states.append(state.duplicate(true)))
	backend.hang_state_received.connect(func(state: Dictionary): _hang_states.append(state.duplicate(true)))
	## 1283 回帧（挂机配置）也要有接收口：没有这一条，`_validate_outgoing_requests` 里
	## 那两条"回帧按键表解出来"就无处可判 —— 只能判发出去的形状，解错顺序照样绿。
	backend.char_config_received.connect(func(配置: Dictionary): 挂配置 = 配置.duplicate(true))
	backend.cash_shop_received.connect(_capture_cash_shop)
	backend.cash_shop_capacity_received.connect(func(capacity: int): _cash_shop_capacities.append(capacity))
	backend.cash_item_info_received.connect(func(item: Dictionary): _cash_item_infos.append(item.duplicate(true)))
	backend.guild_state_received.connect(func(state: Dictionary): _guild_states.append(state.duplicate(true)))
	backend.friend_state_received.connect(func(state: Dictionary): _friend_states.append(state.duplicate(true)))
	backend.party_state_received.connect(func(state: Dictionary): _party_states.append(state.duplicate(true)))
	backend.vip_state_received.connect(func(level: int): _vip_levels.append(level))
	backend.pk_mode_received.connect(func(character_id: int, mode: int): _pk_modes.append({"character_id": character_id, "mode": mode}))
	backend.weather_received.connect(func(weather_type: int): _weather_types.append(weather_type))
	backend.buffs_received.connect(func(buffs: Array): _buff_snapshots.append(buffs.duplicate(true)))
	# monster_damaged 明细（obj/damage/bsk/受击动画 + 184 才给得出的"自己打出/打完还活着"），
	# 给 §3.87/§3.88 的出手解析、受击动画与**在线震屏·击飞两位**断言用。
	backend.monster_damaged.connect(func(object_id: int, damage: int, critical: bool, 受击动画: bool,
			自己打出: bool, 打完活着: bool):
		_last_damage_events.append({"object_id": object_id, "damage": damage,
				"critical": critical, "受击动画": 受击动画,
				"自己打出": 自己打出, "打完活着": 打完活着}))
	backend.player_damaged.connect(func(state: Dictionary): _玩家挨打帧.append(state.duplicate(true)))

var _last_damage_events: Array[Dictionary] = []
var _玩家挨打帧: Array[Dictionary] = []   # 194 整包（字段序见 真值/窗口/战斗表现.md §③B）

func _last_damage_clear() -> void:
	_last_damage_events.clear()

func _last_damage_count() -> int:
	return _last_damage_events.size()

func _last_damage_critical() -> bool:
	return not _last_damage_events.is_empty() and bool(_last_damage_events[0].critical)

func _last_damage_object() -> int:
	return int(_last_damage_events[0].object_id) if not _last_damage_events.is_empty() else 0

func _last_damage_value() -> int:
	return int(_last_damage_events[0].damage) if not _last_damage_events.is_empty() else -1

func _last_damage_critical_at(索引: int) -> bool:
	return 索引 < _last_damage_events.size() and bool(_last_damage_events[索引].critical)

func _last_damage_value_at(索引: int) -> int:
	return int(_last_damage_events[索引].damage) if 索引 < _last_damage_events.size() else -1

func _last_damage_object_at(索引: int) -> int:
	return int(_last_damage_events[索引].object_id) if 索引 < _last_damage_events.size() else 0

func _last_damage_受击() -> bool:
	return not _last_damage_events.is_empty() and bool(_last_damage_events[0].get("受击动画", false))

## 184 帧里 `isPlayer[1]==1 && characterId[2]==本人` ⇒ "这一发是我打出去的"（震屏判据）
func _last_damage_自己() -> bool:
	return not _last_damage_events.is_empty() and bool(_last_damage_events[0].get("自己打出", false))

## 184 帧 `objId&alive` 的 alive 位 ⇒ "这一包打完它还没死"（击飞判据取反）
func _last_damage_活着(索引: int = 0) -> bool:
	return 索引 < _last_damage_events.size() and bool(_last_damage_events[索引].get("打完活着", false))

func _last_damage_自己_at(索引: int) -> bool:
	return 索引 < _last_damage_events.size() and bool(_last_damage_events[索引].get("自己打出", false))

func _last_damage_dump() -> String:
	return str(_last_damage_events)

func _validate_hud_state_packets(backend: Node) -> void:
	_vip_levels.clear()
	_pk_modes.clear()
	_weather_types.clear()
	_buff_snapshots.clear()
	backend.character_id = 7001
	backend.call("_handle_bridge_text", "1818:2:50000:6")
	backend.call("_handle_bridge_text", "1570:8")
	backend.call("_handle_bridge_text", "1792:2:7001:4")
	backend.call("_handle_bridge_text", "35:7&1&8201&3&90000")
	_check(_vip_levels == [6] and int(backend.authoritative_vip_level) == 6, "1818 action=2 应解析后台 VIP 等级")
	_check(_weather_types == [8] and int(backend.authoritative_weather_type) == 8, "1570 应解析后台天气类型")
	_check(_pk_modes.size() == 1 and int(_pk_modes[0].mode) == 4 and int(backend.authoritative_pk_mode) == 4, "1792 action=2 应在服务端确认后更新本人 PK 模式")
	_check(_buff_snapshots.size() == 1 and _buff_snapshots[0].size() == 1, "35 应添加后台 Buff 到权威状态")
	_check(String(_buff_snapshots[0][0].name) == "攻击力翻倍" and not String(_buff_snapshots[0][0].icon).is_empty(), "35 应按后台技能编号解析 Buff 名称和图标")
	backend.call("_handle_bridge_text", "36:7")
	_check(_buff_snapshots.size() == 2 and _buff_snapshots[-1].is_empty(), "36 应取消后台 Buff")
	backend.sent_requests.clear()
	_check(backend.request_pk_mode(3), "PK 模式请求应允许原版家族模式")
	_check(backend.sent_requests.size() == 1 and int(backend.sent_requests[0].opcode) == 1792 and String(backend.sent_requests[0].content) == "0:3", "PK 模式切换必须发送 1792:0:mode")
	_跑完的.append("_validate_hud_state_packets")

func _validate_guild_packets(backend: Node) -> void:
	_guild_states.clear()
	backend.call("_handle_bridge_text", "1552:1:7:木叶之火:守护木叶:2:测试族长:0:0:1000:3:火之徽:2:测试族长&25&5&800&120@测试成员&18&1&90&20")
	_check(_guild_states.size() == 1 and bool(_guild_states[0].guild.joined), "1552 action=1 应解析已加入家族摘要")
	_check(String(_guild_states[0].guild.leader) == "测试族长" and (_guild_states[0].guild.member_list as Array).size() == 2, "家族摘要应保留服务端族长和成员")
	backend.call("_handle_bridge_text", "1552:3:1:10:1:7&1&木叶之火&测试族长&1234&3&2&50&0&0&2&火之徽")
	_check((_guild_states[-1].guilds as Array).size() == 1 and int(_guild_states[-1].total) == 1, "1552 action=3 应解析家族列表和总数")
	backend.call("_handle_bridge_text", "1552:5:890:-:1234&测试族长&25&5&800&120&1&0&0&0&0@1235&测试成员&18&1&90&20&-1&0&0&0&0")
	_check((_guild_states[-1].contributions as Array).size() == 2 and bool(_guild_states[-1].contributions[0].online), "1552 action=5 应解析贡献行与在线状态")
	backend.call("_handle_bridge_text", "2314:0:4:72000:1:40")
	backend.call("_handle_bridge_text", "2314:1:1800")
	backend.call("_handle_bridge_text", "2314:3:0")
	backend.call("_handle_bridge_text", "2314:2:20:250:2500:0:0:0")
	_check(int(_guild_states[-4].boss.day) == 4 and int(_guild_states[-4].boss.seconds) == 72000, "2314 action=0 应解析尾兽日程")
	_check(bool(_guild_states[-3].boss.active) and bool(_guild_states[-2].boss.completed), "2314 应解析尾兽进入和完成状态")
	_check(bool(_guild_states[-1].boss.claimed) and int(_guild_states[-1].boss.exp) == 2500, "2314 action=2 应解析一次性奖励")
	backend.call("_handle_bridge_text", "1552:1:0:-:-:0:-:0:0:0:0:-:0:-")
	_check(not bool(_guild_states[-1].guild.joined), "1552 空摘要应清空权威家族状态")
	_跑完的.append("_validate_guild_packets")

func _validate_social_packets(backend: Node) -> void:
	_friend_states.clear()
	_party_states.clear()
	var friend := "2001&0&10000003&0&100&25&好友甲&0&88&1000&1"
	var blocked := "2002&0&10000004&1&200&18&黑名单乙&0&0&900&-1"
	var request := "2003&0&10000005&0&300&12&申请丙&0&0&1100&-1"
	backend.call("_handle_bridge_text", "61:2:%s:-:%s:-:%s" % [friend, blocked, request])
	_check(_friend_states.size() == 1 and (_friend_states[0].friends as Array).size() == 1, "61 action=2 应解析服务端好友快照")
	_check(bool(_friend_states[0].friends[0].online) and String(_friend_states[0].blocked[0].name) == "黑名单乙", "好友快照应保留在线状态与黑名单")
	_check(int(_friend_states[0].requests[0].character_id) == 2003, "好友快照应解析待处理申请")
	backend.call("_handle_bridge_text", "61:5:%s" % request)
	_check(int(_friend_states[-1].request.character_id) == 2003, "61 action=5 应解析实时好友申请")

	# 字段序按服务端 _party_status_payload / _party_member_row：
	#   状态 = <mode>:<party_id>:<leader_id>:<队伍名>:<成员>[:<后缀>]
	#   成员 = character_id&name&job&level&-&(line_id-1)&map_id&face   （共 8 段）
	var leader := "3001&队长甲&30&100&-&0&101010000&1"
	var member := "3002&成员乙&22&200&-&0&101010000&-1"
	backend.call("_handle_bridge_text", "59:27:77:3001:木叶小队:%s@%s" % [leader, member])
	_check(_party_states.size() == 1 and bool(_party_states[0].party.joined), "59 action=27 应解析权威队伍摘要")
	_check((_party_states[0].party.members as Array).size() == 2 and bool(_party_states[0].party.members[0].leader), "队伍摘要应解析成员和队长")
	## ⚠ **这条帧原文里只有队伍号与邀请人名字两段**：服务端 `:23683-23684`
	## 发的是 `59:4:<party.party_id>:<self.character.name>`，原版 `PartyProcessor.as:52-66`
	## 读的也是 `readInt()` + `readUTF()` 两段 —— **队伍名与邀请人角色号都不在这一帧里**。
	## 以前这里喂的是自己拼的六段 `59:4:77:3001:队长甲:木叶小队`，于是
	## ① `inviter_name` 读到的其实是那个 3001（玩家名成了数字），② 判据又只比 `party_id`
	## ⇒ 字段序怎么写都不会红（10-17 用户报"邀请组队收不到"时补的这条明账）。
	backend.call("_handle_bridge_text", "59:4:77:队长甲")
	_check(int(_party_states[-1].invite.party_id) == 77, "59 action=4 应解析组队邀请")
	_check(String(_party_states[-1].invite.inviter_name) == "队长甲",
			"59 action=4 的邀请人名 = 第 4 段（三段位串里那位是**号**，名字只有这一个来源）")
	_check(int(_party_states[-1].invite.get("inviter_id", 0)) == 0
			and String(_party_states[-1].invite.get("party_name", "")) == "",
			"这一帧没有队伍号以外的身份与队名 ⇒ 客户端**不许拿名字硬凑**（实得 %s）" % str(_party_states[-1].invite))
	backend.call("_handle_bridge_text", "59:36:77&木叶小队&3001&队长甲&2&101010000")
	_check((_party_states[-1].nearby_parties as Array).size() == 1, "59 action=36 应解析附近队伍")
	## ⚠ 这条以前写成 `203:27:<队号>:<队名>:<队长>:<成员行>:-` —— 那是把 **59 的 action=27 形状**
	## 套到 203 上（旧判据自己造的假形状，还把假形状当成了真值）。服务端 203 实际发的是
	## `_party_member_stats_payload:23669-23675` = `203:<角色号>:<hp>:<maxhp>:<mp>:<maxmp>`，
	## **不是动作帧** ⇒ 203 已从 `_handle_party_text` 拆出来（正数那一半由
	## `测试/外来帧表现回归测试.gd` ㉕ 钉：血条比例 + `_队伍成员状态`）。这里把 27 那一支放回它真正的家 59。
	backend.call("_handle_bridge_text", "59:27:77:木叶小队:3001:%s@%s:-" % [leader, member])
	_check(int(_party_states[-1].opcode) == 59 and (_party_states[-1].party.members as Array).size() == 2,
			"59 action=27 才该走队伍成员行解析（实得 opcode=%s、成员 %d 人）" % [
			str(_party_states[-1].opcode), (_party_states[-1].party.members as Array).size()])
	backend.call("_handle_bridge_text", "59:12:77")
	_check(not bool(_party_states[-1].party.joined), "59 action=12 应清空已解散队伍")
	# 被踢（原版 `PartyProcessor.as:165` `UPDATE_PARTY_EXPEL` → `onPartyExpel`）：
	#   服务端只把这条发给**被踢者**，文本 = `13:<被踢角色id>:<名字>:<队伍id>:<队长id>:<队伍名>:-`
	#   ⇒ 客户端要按"我被移出队伍"清状态。⚠️ 2026-10-14 之前这一支没人认（被踢了队伍界面还挂着）。
	backend.call("_handle_bridge_text", "59:27:77:3001:木叶小队:%s@%s" % [leader, member])
	backend.call("_handle_bridge_text", "59:13:3002:成员乙:77:3001:木叶小队:-")
	# ⚠️ 一律 `.get`：点号取不存在的键会**抛错中断本函数**（红的是"这一腿被截断"、
	#    说不出坏在哪；本文件头那套 `_跑完的` 对账能兜住，但兜住的是"有东西坏了"）。
	var 被踢后: Dictionary = (_party_states[-1].get("party", {}) as Dictionary)
	_check(not bool(被踢后.get("joined", false))
			and (被踢后.get("members", []) as Array).is_empty()
			and int(_party_states[-1].get("expelled", 0)) == 3002,
			"59 action=13（被踢）应清空自己的队伍状态、并带上被踢者编号，实测 %s" % str(被踢后))
	# 队长改名（`UPDATE_PARTY_NAME:19` → `handleAction_UPDATE_PARTY_NAME`：`partyId + partyName`；
	#   服务端文本简化为 `19:<队伍名>`）
	# 有人离队（`UPDATE_PARTY_LEAVE:14`）：服务端文本 `14:<队伍id>:<队长id>:<队名>:-:<离队角色id>`，
	#   成员段是**写死的 `-`**（不是"没有成员"）⇒ 只按"这个 id 走了"删那一行。
	backend.call("_handle_bridge_text", "59:27:77:3001:木叶小队:%s@%s" % [leader, member])
	backend.call("_handle_bridge_text", "59:14:77:3001:木叶小队:-:3002")
	var 离队后: Dictionary = (_party_states[-1].get("party", {}) as Dictionary)
	_check((离队后.get("members", []) as Array).size() == 1
			and bool(离队后.get("joined", false)),
			"59 action=14（有人离队）该只删走的那一枚、队伍还在，实测 %s" % str(离队后))
	# 邀请失败两条：原版是硬写的中文提示（`Client.as:8669` / `:9621`）
	backend.call("_handle_bridge_text", "59:17")
	backend.call("_handle_bridge_text", "59:18")
	# ⚠️ 两条各是一条帧、各落一次 state ⇒ 分别取 [-2] 与 [-1]（第一版都读 [-1]，17 那条必然假红）
	_check(bool(_party_states[-2].get("party_full", false)),
			"59 action=17（队伍已满）该记一笔（原版弹「队伍已满」）")
	_check(bool(_party_states[-1].get("not_found_char", false)),
			"59 action=18（没找到该玩家）该记一笔（原版弹「没找到该玩家」）")
	backend.call("_handle_bridge_text", "59:27:77:3001:木叶小队:%s@%s" % [leader, member])
	backend.call("_handle_bridge_text", "59:19:新队名")
	var 改名后: Dictionary = (_party_states[-1].get("party", {}) as Dictionary)
	_check(String(改名后.get("name", "")) == "新队名",
			"59 action=19 应把队伍名更新成「新队名」，实测「%s」" % str(改名后.get("name", "")))
	_跑完的.append("_validate_social_packets")

func _validate_reward_packets(backend: Node) -> void:
	# ⚠️ 这一段原来喂的是 `1344:90:…` 与 `1344:91:…` —— 那是**我们自造的编号**。
	#    2026-09-27 查证：服务端 `handle_gift_query` 只认 1/2/11/12/21/31/32/41/42/43/51/62，
	#    **没有 90/91**；而客户端既发 90/91、又按 90/91 解 —— 整条线两头都错，
	#    所以在线时礼包状态恒为空（`奖励在线查询回归测试` 一直卡在 gift 那一格）。
	#    下面改为喂**服务端真发的五种帧**，形状逐条对 `_send_*` 的发送点。
	backend.call("_handle_bridge_text", "1344:1:2:3600:7200")
	_check(int((backend.authoritative_gifts.first as Dictionary).index) == 2, "1344:1 应解析首次登录礼包下标与倒计时")
	backend.call("_handle_bridge_text", "1344:2:7:1&2@2&1@3&0@4&0@5&0@6&0@7&0:3")
	var 周: Dictionary = backend.authoritative_gifts.weekly
	_check(int(周.days) == 3 and (周.states as Array).size() == 7 and int((周.states as Array)[1].state) == 1,
		"1344:2 应解析七天登录状态与已登录天数")
	backend.call("_handle_bridge_text", "1344:4:120:50:480:true")
	var 线: Dictionary = backend.authoritative_gifts.monthly
	_check(int(线.last_week_minutes) == 120 and int(线.week_minutes) == 480 and bool(线.gainable),
		"1344:4 应解析线上有礼四项（上周/本周分钟、奖励、可领）")
	backend.call("_handle_bridge_text", "1344:5:1:4")
	_check(bool((backend.authoritative_gifts.everyday as Dictionary).claimed)
		and int((backend.authoritative_gifts.everyday as Dictionary).accumulated) == 4,
		"1344:5 应解析每日签到的今日已领与累计天数")
	# 充值活动 `1814`：服务端在 AMF3 通道下发的是 `{"jylx":1814,"command":N,…}` 字典。
	# 四种命令各喂一条，逐条对 `_send_czhuodong_command` 的调用点。
	# ⚠️ 字段口径 2026-10-28 改过（用户：「去掉需要充值的功能逻辑」「累计充值元宝→累计击杀BOSS数」，
	#    登记 真值/窗口/开心有礼.md ④ ＋ 编年史 §3.304）：cmd 4 的桶名 `first_charge`→`first_day`、
	#    `chargeTotal` 退休；cmd 1 改用 `bossKills`；cmd 3 不再下发 `cashbindRemaining`。
	#    2026-10-31 用户再定：首日礼包 → **首杀礼包**，条件 = 击杀一只 BOSS ⇒ cmd 4 的桶名
	#    `first_day` → `first_kill`，payload 只剩 `{active, bossKills}`（`expired`/`firstDay` 退休）。
	backend.call("_handle_bridge_dictionary", {"jylx": 1814, "command": 4, "active": 0, "bossKills": 3})
	var 首杀: Dictionary = backend.authoritative_czhuodong.first_kill
	_check(int(首杀.active) == 0 and int(首杀.bossKills) == 3 and not 首杀.has("expired"),
		"1814 cmd 4 应解析首杀礼包的已领标志与当前 BOSS 击杀数（expired/firstDay 已退休）")
	_check(not backend.authoritative_czhuodong.has("first_charge")
		and not backend.authoritative_czhuodong.has("first_day"),
		"1814 cmd 4 不该再往旧桶名 first_charge / first_day 里写（旧桶名留着 = 页面读到的是空 dict，永远置灰）")
	backend.call("_handle_bridge_dictionary", {"jylx": 1814, "command": 1, "active": 1,
		"bossKills": 8, "statusTotal": [1, 0, 0], "statusEach": [1, 1, 0, 0],
		"detailTotal": [], "detailEach": [], "activities": {"0": {"id": 7}}})
	var 限: Dictionary = backend.authoritative_czhuodong.limit
	_check(int(限.bossKills) == 8 and (限.statusEach as Array).size() == 4 and 限.has("activities"),
		"1814 cmd 1 应解析限时大奖的累计击杀BOSS数、档位状态与活动奖励 activities")
	backend.call("_handle_bridge_dictionary", {"jylx": 1814, "command": 3,
		"detailEach": {"6000057": {"curr": 0, "count": 1}}, "detailRank": {"6000058": {"curr": 1, "count": 1}}})
	var 新: Dictionary = backend.authoritative_czhuodong.xinfu
	_check(int((新.detailEach as Dictionary).get("6000057", {}).get("count", 0)) == 1
		and not 新.has("cashbindRemaining"),
		"1814 cmd 3 应把免费档报成 count=1（count=0 会让原版点击规则只弹「未达到领取条件」、永远领不到），且不再有点券余额")
	backend.call("_handle_bridge_dictionary", {"jylx": 1814, "command": 2, "fc": {"info": {}}})
	_check((backend.authoritative_czhuodong.config as Dictionary).has("fc"),
		"1814 cmd 2 应解析充值活动配置表")
	# 任务列表（`444`）。形状逐条对服务端 `_send_original_started_quest_list` /
	# `_send_original_can_start_quest_list` 的**文本分支**。
	# ⚠️ 这一条以前是断的：444 只发了一个**没有消费者**的 `quest_received` 信号，
	#    于是任务窗口在线时读的仍是离线那套假任务。
	backend.call("_handle_bridge_text", "444:3:1003&1&0&1003_1+2+5!1003_2+0+3&0&-&0@1004&2&0&-&0&-&1")
	var 已接: Array = backend.authoritative_quests_started
	_check(已接.size() == 2, "444 action=3 应解析已接任务列表")
	_check(String(已接[0].id) == "1003" and int(已接[0].progress) == 2 and int(已接[0].required) == 8,
		"已接条目应把 `键+当前+需要` 折成 进度/需求（2+0 / 5+3）")
	_check(not bool(已接[0].completed) and bool(已接[1].completed),
		"状态 1=进行中、2=可交，应折成 completed")
	backend.call("_handle_bridge_text", "444:4:1005@1006")
	_check(backend.authoritative_quests_available.size() == 2
		and String(backend.authoritative_quests_available[1].id) == "1006",
		"444 action=4 应解析可接任务 id 列表")
	backend.call("_handle_bridge_text", "444:3:-")
	_check(backend.authoritative_quests_started.is_empty(), "444 action=3 的空列表应为 `-`（一个都没有）")
	var 进度帧: Array = []
	var 收 := func(info: Dictionary): 进度帧.append(info)
	backend.quest_progress_received.connect(收)
	backend.call("_handle_bridge_text", "444:2:1003:2:0:1003_1+5+5:0")
	_check(进度帧.size() == 1 and String(进度帧[0].get("id", "")) == "1003"
		and int(进度帧[0].get("status", 0)) == 2 and String(进度帧[0].get("data", "")) == "1003_1+5+5",
		"444 action=2 应发出 quest_progress_received（id / 状态 / 目标数据）")
	backend.quest_progress_received.disconnect(收)
	backend.call("_handle_bridge_text", "1820:0:1&0&0&0&10&2&1&4000001&5&1&200&0&0&5000001%2%1")
	_check(backend.authoritative_exchange.size() == 1 and int(backend.authoritative_exchange[0].need_gold) == 200, "1820 action=0 应解析 14 字段兑换模板")
	# 成就福袋回帧（#74）。真形状抄**门实际跑的那份服务端** `服务端/runtime/tools/fake_flash_server.py`
	# 的 `_send_fudai_state:31997-32015` 与 action 2 支 `:31927`：
	#   `1289:1:<state>:<gained 条目|->:<候选 @ 连接>:<类型>`
	#   `1289:2:<state>:<index>`
	# 条目内 `&` 分字段、条目间 `@` 分 ⇒ 整帧仍能按 `:` 切（原版 `FudaiProcessor` 读序一致）。
	# 旧版这里钉的是一条十段假格式（`round_id` / `selected_slot` / `claimed` 协议里根本没有），
	# 解析器还挂着 `fields.size() < 9: return` ⇒ 6 段和 4 段的真帧一条不落，在线永远开不了窗。§3.261
	backend.call("_handle_bridge_text", "1289:1:1:-:1&4000001&0&3&0&0&1&0&0&1@2&5000001&1&2&0&0&1&0&0&2:2")
	var 福袋: Dictionary = backend.authoritative_fudai
	_check(int(福袋.get("action", 0)) == 1 and int(福袋.get("state", 0)) == 1
		and int(福袋.get("type", 0)) == 2, "1289 action=1 应解析状态与福袋类型")
	_check((福袋.get("candidates", []) as Array).size() == 2
		and String((福袋.get("candidates", []) as Array)[0].get("id", "")) == "4000001",
		"1289 action=1 的候选段应按 @ 拆成条目")
	_check((福袋.get("gained", {}) as Dictionary).is_empty(),
		'1289 action=1 的 gained 段 "-" = 还没抽中，应解成空条目')
	backend.call("_handle_bridge_text", "1289:1:2:1&4000001&0&3&0&0&1&0&0&1:1&4000001&0&3&0&0&1&0&0&1@2&5000001&1&2&0&0&1&0&0&2:2")
	_check(String((backend.authoritative_fudai.get("gained", {}) as Dictionary).get("id", "")) == "4000001",
		"1289 action=1 已抽中时 gained 段应解成条目")
	backend.call("_handle_bridge_text", "1289:2:2:1")
	_check(int(backend.authoritative_fudai.get("action", 0)) == 2
		and int(backend.authoritative_fudai.get("state", 0)) == 2
		and int(backend.authoritative_fudai.get("index", -1)) == 1, "1289 action=2 应解析落点序号")
	backend.call("_handle_bridge_text", "1345:0:1:2:0:1&5&5&1@2&8&10&0")
	_check(backend.authoritative_achievements.size() == 2 and bool(backend.authoritative_achievements[0].gained), "1345 应解析成就进度和领取状态")
	# 排行榜（`1346` 本服榜）。三种 cmd 的**读序互不相同**，这里各喂一条真形状，
	# 形状抄服务端 `fake_flash_server.py:27515-27518 / 27717-27727` 的文本分支：
	# · cmd 1 = `1346:1:<tabId>:<true|false>:<rank>:<行@行|->`   （搜索结果，有忍界位）
	# · cmd 2 = `1346:2:<tabId>:<rank>:<行@行|->`               （隐藏榜，**没有** bool 那格）
	# · cmd 0 = `1346:0:<charId>:<cnt>:<menuId@menuId|->`        （头顶徽记，本工程只解不画，#87）
	# 旧版这里挂的是 `2329`（跨服**充值**榜，`SendOpCodes.GLOBLE_PAIHANG:326`）——
	# 跟这 23 个榜单不是一回事，服务端那条 1346 从来没被读过。§3.254。
	var 排行帧: Array = []
	var 收排行 := func(state: Dictionary): 排行帧.append(state)
	backend.ranking_state_received.connect(收排行)
	backend.call("_handle_bridge_text", "1346:1:2:false:0:1&7001&鸣人&0&88@1&7002&佐助&0&77")
	var 榜2: Dictionary = backend.authoritative_rankings.get(2, {})
	_check(int(榜2.get("rank", -999)) == 0 and (榜2.get("rows", []) as Array).size() == 2,
		"1346 cmd1 应解析榜单行（@ 连行）与服务端名次")
	_check(String((榜2.get("rows", []) as Array)[0].get("name", "")) == "鸣人", "1346 cmd1 行第 3 段是姓名")
	# ⚠ `value` 必须留**字符串**：原版 `rankNumText.text = param1.value` 直接印 Number，
	#   转 int/float 往返会把 `12.5` 变成 `12`（§3.253-D 的漂移口径）。
	_check(String((榜2.get("rows", []) as Array)[0].get("value", "")) == "88", "1346 cmd1 数值列应保留原样字符串")
	_check(not bool(榜2.get("江湖", true)), '1346 cmd1 的 bool 段 "false" ⇒ 江湖位为假（同点时服务端 bJiangHu 与客户端 renJieBang 名字是反的）')
	backend.call("_handle_bridge_text", "1346:1:0:true:0:-")
	var 榜0: Dictionary = backend.authoritative_rankings.get(0, {})
	_check((榜0.get("rows", []) as Array).is_empty(), '1346 cmd1 空表写 "-" ⇒ 行数 0（不是 1 条空行）')
	_check(bool(榜0.get("江湖", false)), "1346 cmd1 的 bool 段 \"true\" ⇒ 江湖位为真")
	backend.call("_handle_bridge_text", "1346:2:5:12:1&7001&鸣人&0&88")
	var 榜5: Dictionary = backend.authoritative_rankings.get(5, {})
	_check(int(榜5.get("rank", -999)) == 12 and (榜5.get("rows", []) as Array).size() == 1,
		"1346 cmd2 比 cmd1 少一格 bool，rank 紧跟 tabId")
	_check(bool(榜5.get("江湖", false)), "1346 cmd2 没有 bool 段 ⇒ 按原版缺省当忍界榜")
	backend.call("_handle_bridge_text", "1346:0:7001:2:0@3")
	_check(backend.authoritative_ranking_titles.get(7001, []) == [0, 3], "1346 cmd0 应解析头顶徽记的 menuId 列表")
	backend.call("_handle_bridge_text", "1346:0:7001:0:-")
	_check(backend.authoritative_ranking_titles.get(7001, []) == [], "1346 cmd0 cnt=0 / \"-\" ⇒ 空徽记列表")
	# cmd 0 那条**不**发列表信号（它喂的是头顶徽记，不是这个窗口的表）⇒ 只有 3 条。
	_check(排行帧.size() == 3, "每条 1346 列表回帧（cmd1/cmd2）都应发出 ranking_state_received")
	backend.ranking_state_received.disconnect(收排行)
	# 活跃度面板：服务端在 AMF3 通道下发的就是文本帧，照抄 `fake_flash_server.py:32502`。
	#   action0 面板 = `2326:0:15:<15 个任务次数，冒号连接>:<已领档位>:<总活跃分>`
	backend.call("_handle_bridge_text", "2326:0:15:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:-1:0")
	# ⚠️ 一律用 `.get(键, 哨兵)` 读，**不要**写 `活跃.points` 这种字典点号取键 ——
	#    取缺失键会抛 "Invalid access to property or key" 并**中断整个函数**，
	#    后面的断言全都不跑、`_failures` 还是空的，于是**假绿**（2026-09-25 实测栽过）。
	var 活跃: Dictionary = backend.authoritative_activity
	_check(int(活跃.get("points", -999)) == 0 and int(活跃.get("claimed_level", -999)) == -1, "2326 action0 应解析总活跃分与已领档位（初值 -1）")
	_check((活跃.get("task_counts", []) as Array).size() == 15, "2326 action0 应解析 15 项每日任务次数")
	#   action1 领取成功 = `2326:1:<新档位>`；失败 = `2326:1:<原档位>`（**没有独立成功布尔**，靠档位是否变大判断）
	backend.call("_handle_bridge_text", "2326:1:0")
	活跃 = backend.authoritative_activity
	_check(int(活跃.get("claimed_level", -999)) == 0 and bool(活跃.get("claim_success", false)), "2326 action1 档位变大应判为领取成功")
	backend.call("_handle_bridge_text", "2326:1:0")
	活跃 = backend.authoritative_activity
	_check(int(活跃.get("claimed_level", -999)) == 0 and not bool(活跃.get("claim_success", true)), "2326 action1 档位没变应判为领取失败")
	#   action2 单任务增量 = `2326:2:<槽位(1基)>:<累计次数>:<本次新增活跃分>`
	backend.call("_handle_bridge_text", "2326:2:3:1:10")
	活跃 = backend.authoritative_activity
	_check(int((活跃.get("task_counts", []) as Array)[2]) == 1, "2326 action2 应把次数写进对应槽位（槽位是 1 基）")
	_check(int(活跃.get("points", -999)) == 10, "2326 action2 应把新增活跃分累加上去")
	_跑完的.append("_validate_reward_packets")

func _validate_legacy_packets(backend: Node) -> void:
	backend.call("_handle_bridge_text", "1392:1:40:0:1:0:12100000&20&20@12100001&15&15:10:ok")
	_check(int(backend.authoritative_card.level) == 40 and int(backend.authoritative_card.node_id) == 0, "1392 应解析卡牌等级与节点")
	_check(bool(backend.authoritative_card.committed) and (backend.authoritative_card.items as Array).size() == 2 and int(backend.authoritative_card.gain_ap) == 10, "1392 应解析提交状态、材料进度和 AP 奖励")
	backend.call("_handle_bridge_text", "1826:0:10001:10001:1:0:0:ok")
	backend.call("_handle_bridge_text", "1826:3:10001:0&4000001&2&1&0@1&5000001&1&0&1:0:ok")
	_check(bool(backend.authoritative_chest.open) and (backend.authoritative_chest.items as Array).size() == 2, "1826 应合并宝箱开启状态与持久化候选")
	_check(bool(backend.authoritative_chest.items[1].claimed) and not bool(backend.authoritative_chest.completed), "1826 应解析单项领取与完成状态")
	backend.call("_handle_bridge_text", "1822:2:15003016:1:ok")
	_check(bool(backend.authoritative_buff_fusion.success) and int(backend.authoritative_buff_fusion.item_id) == 15003016, "1822 应解析料理合成发货结果")
	backend.call("_handle_bridge_text", "1288:2:2002:修炼伙伴")
	_check(int(backend.authoritative_heal.pending_inviter_id) == 2002 and String(backend.authoritative_heal.pending_inviter_name) == "修炼伙伴", "1288 应解析双修邀请人")
	## ⚠ 这一支自己钉死"我是几号"（**夹具的输入**，不是从被测代码反查的参照值）：
	## 原版 `HealHandler.as:250` 那一支第一行就是 `if(param3 == stats.id)` —— 讲别那具的帧整条丢掉。
	## 10-17 补上这道闸后，旧夹具那个 `2001` 被丢掉、下面三条全红（红得对：那本来就不是一帧发给我的）。
	backend.character_id = 7001
	backend.call("_handle_bridge_text", "1288:1:2:7001:2002")
	backend.call("_handle_bridge_text", "1288:1:2:2002:7001")
	_check(int(backend.authoritative_heal.state) == 2 and int(backend.authoritative_heal.partner_id) == 2002,
			"两条对调帧里只有「讲我这具」那条落地（服务端同意那一支真发两条，`:34884/:34889`）")
	backend.call("_handle_bridge_text", "1288:3:7")
	_check(int(backend.authoritative_heal.state) == 2 and int(backend.authoritative_heal.partner_id) == 2002 and int(backend.authoritative_heal.xinfa_id) == 7, "1288 应合并双修状态、伙伴与心法")
	# 2318 的两个下行动作**逐字照 `JieYinProcessor`**：0 = `stage,count`（**只有这两个**，
	# 原版两档消耗读客户端 Etc 表）、2 = `result,addCount`（result = **有没有升阶**，不是"加没加熟练度"）。
	backend.call("_handle_bridge_text", "2318:2:0:4")
	_check(not bool(backend.authoritative_jieyin.success) and int(backend.authoritative_jieyin.added) == 4,
		"2318:2 该按 `result,addCount` 存（result=0 是「这一跳没把阶段推上去」，不是失败）")
	backend.call("_handle_bridge_text", "2318:2:1:4")
	backend.call("_handle_bridge_text", "2318:0:7:12")
	_check(bool(backend.authoritative_jieyin.success) and int(backend.authoritative_jieyin.stage) == 7 \
			and int(backend.authoritative_jieyin.count) == 12, "2318 应合并结印升阶结果与权威进度")
	if backend.authoritative_jieyin.has("zq") or backend.authoritative_jieyin.has("need_zq"):
		_check(false, "2318:0 线上只有 stage/count ⇒ 不能再从这条帧里编出 zq/need_zq（原版那两档消耗读 Etc 表）")
	backend.call("_handle_bridge_text", "1817:3:1:false:ok")
	backend.call("_handle_bridge_text", "1817:0:2:1:0:true:0:5000:15020001:1:30000:0")
	_check(bool(backend.authoritative_anqi.success) and int(backend.authoritative_anqi.stage) == 2 and bool(backend.authoritative_anqi.open), "1817 应合并暗器操作结果与权威阶段")

	backend.sent_requests.clear()
	_check(backend.request_card_level(40) and backend.request_card_node(40, 0) and backend.request_card_commit(40, 0) and backend.request_card_claim(40, 0), "卡牌请求应可发送")
	_check(backend.request_chest_open(10001) and backend.request_chest_close(10001) and backend.request_chest_claim(10001, 2) and backend.request_chest_claim_all(10001), "宝箱请求应可发送")
	_check(backend.request_buff_fusion(3, 4), "料理合成请求应可发送")
	_check(backend.request_heal_start() and backend.request_double_heal_invite(2002) and backend.request_double_heal_accept(2002) and backend.request_double_heal_deny(2002) and backend.request_xinfa_change(7) and backend.request_heal_state() and backend.request_heal_stop(), "打坐、双修和心法请求应可发送")
	# 结印上行**只有一个动作**（byte 0 = `requestJieYin_EatUp`）；原版没有"请求状态"这一发，
	# 自动提升是客户端每 0.8 秒重发同一包，不是第二个 action。
	_check(backend.request_jieyin(), "结印提升请求应可发送")
	_check(backend.request_shuriken(0, true) and backend.request_shuriken(2, true) and backend.request_shuriken(1) and backend.request_anqi_state(), "暗器请求应可发送")
	var opcodes: Array[int] = []
	var contents: Array[String] = []
	for request in backend.sent_requests:
		opcodes.append(int(request.opcode))
		contents.append(String(request.content))
	_check(opcodes == [1392, 1392, 1392, 1392, 1826, 1826, 1826, 1826, 1822, 86, 86, 86, 86, 86, 86, 86, 2318, 1817, 1817, 1817, 1817], "传承系统请求必须使用原版 opcode")
	_check(contents == ["0:40", "1:40:0", "2:40:0", "3:40:0", "0:10001", "1:10001", "2:10001:2", "3:10001", "1:3:4", "1", "3:2002", "4:2002", "5:2002", "6:7", "8", "2", "0", "0:1", "2:1", "1", "3"], "传承系统请求应保持原版 action 与字段顺序")
	_跑完的.append("_validate_legacy_packets")

func _validate_login_and_character_list(backend: Node) -> void:
	backend.call("_handle_bridge_dictionary", {"jylx": 0, "loginStatus": 0})
	backend.call("_handle_bridge_dictionary", {"jylx": 0, "loginStatus": 1})
	_check(int(_signals.login_status_received) == 2, "LOGIN_STATUS 0/1 应分别分派")
	backend.call("_handle_bridge_text", "10:1:3:1234:测试角色:0:0:10000003:10000006:5:100:5:5:5:5:100:100:80:80:0:0:0:0:101010000:0:0:0:true:0:0:0:0")
	_check(int(_signals.character_list_received) == 1, "角色列表包应分派")
	_check(backend.characters.size() == 1 and int(backend.characters[0].id) == 1234, "角色列表快照应保存服务端角色")
	_跑完的.append("_validate_login_and_character_list")

func _validate_entity_packets(backend: Node) -> void:
	backend.call("_apply_map_state", 101010000, 120, 220, 100)
	backend.call("_handle_bridge_text", "162:9001:远程忍者:100:0:0:10000003:10000006:0:-:-:0:0:0:120:220:-1:0:0:12:0:0:0:-:-:-:0:0:0")
	_check(int(_signals.player_spawned) == 1 and backend.map_players.has(9001), "162 应生成远程玩家快照")
	_check(int(backend.map_players[9001].map_id) == 101010000 and int(backend.map_players[9001].face) == 10000003, "162 应记录当前地图和原版 face 外观")
	var samples := _packet_builder_samples()
	## ⚠ 夹具缺条目时**必须当场点名返回**：以前直接 samples[3] ⇒ `Out of bounds` 把整条
	## 校验打断，后面十几条断言一条都没跑，日志里只看到一串"没跑到底"，很难看出真凶是
	## 「抓包文件被别的工具覆盖了」（2026-10-09 我自己用 协议探针.py 覆盖过一次）。
	if samples.size() < 5:
		_check(false, "PacketBuilder 样本只有 %d 条（要 5 条）⇒ 抓包夹具被覆盖或损坏，本段校验跳过"
				% samples.size())
		return
	backend.call("_handle_bridge_text", samples[3])
	_check(int(_signals.player_moved) == 1 and int(backend.map_players[9001].x) == 140
			and int(backend.map_players[9001].y) == 230 and int(backend.map_players[9001].direction) == 1,
			"187 应按服务端的串读：[2]=角色编号、[5][6]=坐标、[7]=速度x（正=朝右）")
	## ⚠ `velocity_x` 这一格 2026-10-14 以前**根本没往 state / map_players 里放** ⇒
	## `地图实体` 收端拿到 0 ⇒ "两包之间按速度继续往前走"那条外推整段是死的 ⇒ 看别人永远
	## 欠几十毫秒（用户实机"延迟还是很大"）。以前三条断言只钉了 x/y/朝向，所以离线门一路绿。
	_check(int(backend.map_players[9001].velocity_x) == 40,
			"187 要把速度x 也解进 state（收端靠它外推，缺了这一格就是'只看得到一步一跳'）")
	backend.call("_handle_bridge_text", samples[4])
	_check(int(_signals.player_moved) == 2 and int(backend.map_players[9001].x) == 120
			and int(backend.map_players[9001].direction) == -1
			and int(backend.map_players[9001].velocity_x) == -60,
			"187 速度x 为负 ⇒ 朝左（这一格是服务端「文本→原版」翻译器同一位置拿去推朝向的那一段）")
	backend.call("_handle_bridge_text", samples[6])
	_check(int(_signals.player_moved) == 3 and int(backend.map_players[9001].x) == 160
			and int(backend.map_players[9001].direction) == 1
			and int(backend.map_players[9001].velocity_x) == 0,
			"187 速度x 没给（我们自己发的 `36:x:y:朝向` 只有三段，服务端在那格补 0）⇒ 按位移推朝向，与服务端维护自身 direction 同一条规则")
	backend.call("_handle_bridge_text", samples[0])
	_check(int(_signals.monster_spawned) == 1 and backend.map_monsters.has(7001), "238 应生成怪物快照")
	backend.call("_handle_bridge_text", samples[1])
	# ⚠️ 241 的真值：`[5][6]` 是**这一段的起点**、`[7][8]` 是**速度**、`[11]` 是 `moveId`（移动段编号），
	# **不是时长**。原版 `Client.onMoveMonster()` → `MonsterHandler.addMonsterMovement()` 把它当
	# "移动段"播，两段之间由客户端按速度积分（服务端只在移动段变化时才发下一帧）。
	# 我们原来把 `[11]` 当时长 → `max(1,0)` = 1 毫秒 → 补间 0.001 秒 → **怪瞬移**。
	_check(int(_signals.monster_moved) == 1
			and int(backend.map_monsters[7001].start_x) == 300
			and int(backend.map_monsters[7001].start_y) == 400
			and int(backend.map_monsters[7001].vx) == 100,
			"241 移动包应带起点与速度（终点由客户端按速度积分，[11] 是 moveId 不是时长）")
	backend.call("_handle_bridge_text", samples[2])
	_check(int(_signals.monster_moved) == 2
			and int(backend.map_monsters[7001].start_x) == 390
			and int(backend.map_monsters[7001].vx) == 0,
			"241 零速度包 = 停在服务端给的位置（速度 0 就不积分）")
	backend.call("_handle_bridge_text", "260:8001:2:500:600:450:550:-1:7")
	_check(int(_signals.npc_spawned) == 1 and backend.map_npcs.has(8001), "260 应生成 NPC 快照")
	backend.call("_handle_bridge_text", "163:9001")
	_check(int(_signals.player_removed) == 1 and not backend.map_players.has(9001), "163 应移除远程玩家快照")
	_validate_ambiguous_remove(backend)
	_跑完的.append("_validate_entity_packets")

func _validate_ambiguous_remove(backend: Node) -> void:
	var monster_packet := "238:1:7100:0:1001001:101010000:300:400:0:0:0:0:true:0:300:400:0:0:-:-:-:0:false:false:false:0:0"
	var player_packet := "162:7100:同号忍者:100:0:0:10000002:0:0:-:-:0:0:0:120:220:1:0:0:12:0:0:0:-:-:-:0:0:0"
	backend.call("_handle_bridge_text", monster_packet)
	backend.call("_handle_bridge_text", player_packet)
	backend.call("_handle_bridge_text", "163:7100")
	_check(not backend.map_players.has(7100) and backend.map_monsters.has(7100), "163 同号冲突应删除最近生成的玩家来源")
	backend.call("_handle_bridge_text", player_packet)
	backend.call("_handle_bridge_text", monster_packet)
	var removed_before := int(_signals.monster_removed)
	backend.call("_handle_bridge_text", "163:7100")
	_check(backend.map_players.has(7100) and not backend.map_monsters.has(7100) and int(_signals.monster_removed) == removed_before + 1, "163 同号冲突应删除最近生成的怪物来源")
	backend.call("_handle_bridge_text", "163:7100")
	_check(not backend.map_players.has(7100), "163 在只剩玩家来源时应删除玩家")
	_跑完的.append("_validate_ambiguous_remove")

func _validate_combat_packets(backend: Node) -> void:
	## ⭐ 自己钉本人 id：下面「这一发是不是我自己打出的」两位要拿它比，别借上一条用例留下的值
	## （`_check` 之前先喂对状态，否则"由自己打出"会因巧合而真假难辨）。
	backend.character_id = 7001
	backend.call("_handle_bridge_text", "241:1:7001:2:-1:0:1:390:400:1234:-:0")
	_check(int(_signals.monster_attacked) == 1, "241 cmd=1 应分派怪物攻击动画")
	backend.call("_handle_bridge_text", "194:1234:0:false:17:2:7001:0:0")
	_check(int(_signals.player_damaged) == 1, "194 应分派服务端人物受击")
	## ── 194 的**字段序**（以前只钉过"信号来过一次"，段错位照样绿）──
	## 服务端发法 `fake_flash_server.py:36966-36968`：
	## `194:<cid>:<skill>:<status_triggered 文本 true/false>:<damage>:<monsteridfrom>:<oid>:<int(critical)>:<fake>`
	## AS3 那头读出 8 个字段（`DamagePlayerInfo.as:29-39`），它第 7 个名字叫 `direction` —— 
	## 本机服务端在那个位置发的是**暴击位**，所以我们解成 `hit_flag`（`DamageHandler.as:92-96` 靠它写「致命」）。
	_玩家挨打帧.clear()
	backend.call("_handle_bridge_text", "194:1234:2001:false:123:5300152:7001:1:0")
	_check(_玩家挨打帧.size() == 1
			and int(_玩家挨打帧[0].get("character_id", -1)) == 1234
			and int(_玩家挨打帧[0].get("skill_id", -1)) == 2001
			and not bool(_玩家挨打帧[0].get("skill_trigger", true))
			and int(_玩家挨打帧[0].get("damage", -1)) == 123
			and int(_玩家挨打帧[0].get("monster_action", -1)) == 5300152
			and int(_玩家挨打帧[0].get("monster_object_id", -1)) == 7001
			and int(_玩家挨打帧[0].get("hit_flag", -1)) == 1
			and int(_玩家挨打帧[0].get("fake", -1)) == 0,
			"194 八段该各就各位（招号 2001 / 状态位 false / 伤害 123 / 出手动作 5300152 / oid 7001 / 暴击位 1）；"
			+ "实得 %s" % str(_玩家挨打帧))
	## 状态位是**文本** true/false，不是 0/1 —— 服务端写的是 `str(status_triggered).lower()`。
	## 判反了就等于：怪那发普通攻击被当成"状态生效" ⇒ 克制提示永远不飘。
	_玩家挨打帧.clear()
	backend.call("_handle_bridge_text", "194:1234:2001:true:123:5300152:7001:0:0")
	_check(_玩家挨打帧.size() == 1 and bool(_玩家挨打帧[0].get("skill_trigger", false))
			and int(_玩家挨打帧[0].get("hit_flag", -1)) == 0,
			"194 第 4 段 `true` ⇒ skill_trigger 该是真、第 8 段 0 ⇒ 暴击位该是 0；实得 %s" % str(_玩家挨打帧))
	## 段数不够（老服务端/噪声包）⇒ 整条丢掉，不拿默认值凑一个"半个真的状态"出来。
	_玩家挨打帧.clear()
	var 原来 := int(_signals.player_damaged)
	backend.call("_handle_bridge_text", "194:1234:2001:false:123")
	_check(_玩家挨打帧.is_empty() and int(_signals.player_damaged) == 原来,
			"194 不足 9 段该整条丢（不发信号、不凑默认值）；实得 %d 条" % _玩家挨打帧.size())
	backend.call("_handle_bridge_text", "243:7001:37")
	backend.call("_handle_bridge_text", "252:7001:72")
	_check(int(_signals.monster_damaged) == 1, "243 应分派服务端怪物伤害")
	_check(int(_signals.monster_hp_changed) == 1, "252 ShowMonsterHp 应分派服务端血量")
	# —— 出手结算 184（原版 AttackInfo/MobDamage，`obj&alive&damage*bsk`）——
	# 暴击红字在原版**不走 243**（243=`onDamageMonster(int,int)` 恒白字），走 184 的第二位
	# （`MobDamageItem(damage, bsk)` → `applySkillHitMob` 的 `MOB_HP_BSK` 红）。§3.87。
	_last_damage_clear()
	_skill_hits.clear()   # 下面 skill_id>0 会真的分派 skill_hit，别让后面"243 后再派发"那条断言吃到
	backend.call("_handle_bridge_text", "184:1:7001:0:100:1:1:false:1:0:11:1:8001&true&37*0")
	_check(_last_damage_count() == 1 and _last_damage_object() == 8001
			and _last_damage_value() == 37 and not _last_damage_critical(),
			"184 的 damage*bsk 应解析成普通伤害（实际 %s）" % _last_damage_dump())
	# §3.88.4：184 = 出手命中 → 该让怪播受击动画；243（下一条）= DoT 跳伤 → 不该播
	_check(_last_damage_受击(), "184 出手帧的 monster_damaged 该带『受击动画=要』")
	## ⭐ 在线震屏/击飞要的那两位**就是从这一帧来的**（用户 2026-10-11 报「暴击了但没有震动」，
	## 根因是离线腿接了、在线腿没接 ⇒ 这里先证明解码侧真的把 `isPlayer/characterId/alive` 三位读出来了，
	## 下游 `地图实体` 才有东西可用）。
	_check(_last_damage_自己(), "184 里 isPlayer=1 且 characterId=本人 ⇒ 该报『自己打出』（震屏条件的一半）")
	_check(_last_damage_活着(), "184 的 objId&alive 位 true 要原样传出去（打死了才击飞、没死才僵直）")
	_check(_skill_hits.is_empty(), "skillId=0 的 184（普攻）不该分派技能 hit（实际 %s）" % str(_skill_hits))
	_last_damage_clear()
	## 反向对照：`isPlayer=0`（怪打的）与 `characterId=别人` 两发都**不该**报"自己打出"。
	## 少了这两条，把 `由自己打出` 写死成 true 也能让上面那条绿（变异实测抓过这类"只搜字在不在"）。
	backend.call("_handle_bridge_text", "184:0:7001:0:100:1:1:false:1:0:11:1:8001&true&37*1")
	_check(not _last_damage_自己(), "isPlayer=0 的 184（怪出手）不该报『自己打出』，否则怪打自己也会震屏")
	_check(_last_damage_critical(), "isPlayer=0 不影响 bsk 位解析（照样是暴击数字）")
	_last_damage_clear()
	backend.call("_handle_bridge_text", "184:1:9999:0:100:1:1:false:1:0:11:1:8001&true&37*1")
	_check(not _last_damage_自己(), "characterId 不是本人的 184（别人打的）不该报『自己打出』")
	_last_damage_clear()
	backend.call("_handle_bridge_text", "184:1:7001:0:100:1:2:false:1:9029:11:1:8001&true&74*1@8002&false&10*0")
	_check(_last_damage_count() == 2 and _last_damage_critical_at(0)
			and not _last_damage_critical_at(1) and _last_damage_value_at(0) == 74
			and _last_damage_object_at(1) == 8002,
			"多目标 184 应逐条解析 obj/damage/bsk（实际 %s）" % _last_damage_dump())
	_check(_skill_hits.size() == 2 and int(_skill_hits[0].skill_id) == 9029
			and int(_skill_hits[0].object_id) == 8001 and int(_skill_hits[1].object_id) == 8002,
			"skillId>0 的 184 要按目标分派技能 hit（实际 %s）" % str(_skill_hits))
	## 逐目标的 alive 位：第一条"打完还活着"、第二条"打死了" ⇒ 击飞只会发生在第二条上
	_check(_last_damage_活着(0) and not _last_damage_活着(1),
			"多目标 184 的 alive 位要逐条分开传（第一条活、第二条死 ⇒ 只把第二条打飞，实际 %s）" % _last_damage_dump())
	_check(_last_damage_自己() and _last_damage_自己_at(1),
			"同一帧里两个目标都该继承『自己打出』（面积技打一片时每一只都要能震）")
	_skill_hits.clear()
	# 243 是 DoT/相位伤（原版两 int），**永远按非暴击解析**、别把伤害当出手。
	_last_damage_clear()
	backend.call("_handle_bridge_text", "243:7001:37")
	_check(_last_damage_count() == 1 and not _last_damage_critical(),
			"243 应解析成非暴击（原版 243 没有 bsk 位，实际 %s）" % _last_damage_dump())
	# §3.88.4：243 = DoT/相位跳伤，**不该**触发受击动画（否则中毒的怪每秒抽一下）
	_check(not _last_damage_受击(), "243 的 monster_damaged 该带『受击动画=不要』（原版 addMonsterDamage 只画数字）")
	## 243 帧体只有 `(mobId, damage)` 两个 int ⇒ **没有** bsk / alive / isPlayer 任何一位。
	## 所以"自己打出"必须报 false（DoT 不该震屏），"打完还活着"必须报 true
	## （宁可承认不知道，也不许猜"死了" ⇒ 猜了就会把没死的怪打飞）。
	_check(not _last_damage_自己(), "243 没有 isPlayer 位 ⇒ 不许报『自己打出』（中毒的怪不该每跳都震一下）")
	_check(_last_damage_活着(), "243 没有 alive 位 ⇒ 该保守报『还活着』（否则 DoT 会把怪凭空打飞）")
	_last_damage_clear()
	backend.call("_handle_bridge_text", "272:6001:false:3000001:false:0:1234:410:420:390:400:0:5")
	_check(int(_signals.map_drop_spawned) == 1 and backend.map_drops.has(6001), "272 DropItem 应生成掉落快照")
	_check(String(backend.map_drops[6001].item_name) == "拉面（小）", "掉落物名称应由原版物品表解析")
	backend.call("_handle_bridge_text", "273:2:6001:false:1234")
	_check(int(_signals.map_drop_removed) == 1 and not backend.map_drops.has(6001), "273 应移除掉落快照")
	var killed_before := int(_signals.monster_killed)
	backend.call("_handle_bridge_text", "239:7001:1")
	_check(int(_signals.monster_killed) == killed_before + 1 and not backend.map_monsters.has(7001), "239 KillMonster 应移除怪物快照")
	_跑完的.append("_validate_combat_packets")

func _validate_inventory_deltas(backend: Node) -> void:
	backend.authoritative_inventory.clear()
	backend.authoritative_equipment.clear()
	var ramen := "2&3000001&1&5&0&0&1&测试角色&0&5001"
	var weapon := "1&01010011&2&1&0&0&1&测试角色&0&5002&3&100&90&1&40&2&8&1*12!2*5&-1&0&10&1001*1*1*0*3&4&true!true&0&0&0&0&0"
	backend.call("_handle_bridge_text", "32:0:%s:0:1:1" % ramen)
	_check(backend.authoritative_inventory.size() == 1 and int(backend.authoritative_inventory[0].quantity) == 5, "32 flag=0 应新增背包物品")
	backend.call("_handle_bridge_text", "32:1:0:3000001:1:3:1:1")
	_check(int(backend.authoritative_inventory[0].quantity) == 3, "32 flag=1 应更新堆叠数量")
	backend.call("_handle_bridge_text", "32:0:%s:0:1:2" % weapon)
	_check(String(backend.authoritative_inventory[1].slot) == "武器" and int(backend.authoritative_inventory[1].equip_position) == -1, "装备模板应由物品编号恢复原版装备槽")
	_check(int(backend.authoritative_inventory[1].strengthen) == 4 and (backend.authoritative_inventory[1].inlays as Array).size() == 1, "装备条目应解析强化等级、镶嵌和附加属性")
	# 装备帧**尾部那四段**（原版 `CocoEquip.decode` 的 specialAttrList / specialLevel /
	# specialEffectType / afterimageFlag，文本桥 `_encode_item_payload` 补的）：
	# 解析出来必须能被**变身卡互换窗的特性栏**直接用掉 —— 这一条是端到端的对表，
	# 光各自绿没意义（上一版就是"窗读的名字"和"解析写的名字"两套、谁都不报错）。
	var 特性武 := weapon + "&4*30!5*40&2&2&1"		# 29 段之后再补 4 段 ⇒ 33 段
	backend.call("_handle_bridge_text", "32:0:%s:0:1:3" % 特性武)
	var 特性件: Dictionary = backend.authoritative_inventory[2]
	if 特性件.is_empty():
		_check(false, "33 段装备帧没进背包（段数不够被当老帧丢了？）")
	else:
		# ⚠️ 一律走 `.get`（点号取不存在的键会**抛错中断本函数** —— 那样红的是
		#    "这一腿被截断"、而不是这条断言本身，判据等于没写；本文件头那套 `_跑完的` 对账能兜住，
		#    但兜住的是"有东西坏了"，说不出坏在哪）。
		_check((特性件.get("special_attributes", []) as Array).size() == 2
				and int(特性件.get("special_level", 0)) == 2
				and int(特性件.get("special_effect_type", 0)) == 2
				and int(特性件.get("afterimage_flag", 0)) == 1,
				"装备帧尾部四段应解析成 special_attributes/special_level/special_effect_type/afterimage_flag，实测 %s"
				% str(特性件.get("special_attributes", null)))
		var 互换窗 := load("res://脚本/界面/窗口/变身卡互换窗.gd")
		var 特性文 := String(互换窗.特性文案(特性件))
		_check(特性文.contains("攻击：") and 特性文.contains("+30%")
				and 特性文.contains("防御：") and 特性文.contains("+40%")
				and 特性文.contains("传说特性") and 特性文.contains("2%概率提升10%防御5秒")
				and 特性文.contains("残影显现"),
				"解析出来的特性必须能直接喂给特性栏（端到端对表），实测「%s」" % 特性文)
	backend.call("_handle_bridge_text", "32:5:false:1:3")
	backend.call("_handle_bridge_text", "32:2:2:-1:0")
	_check(backend.authoritative_equipment.has(-1) and int(backend.authoritative_equipment[-1].slot_index) == -1, "32 flag=2 应把背包装备移动到人物装备槽")
	backend.call("_handle_bridge_text", "32:2:-1:2:0")
	_check(not backend.authoritative_equipment.has(-1) and int(backend.authoritative_inventory[1].slot_index) == 2, "32 flag=2 应支持卸下装备")
	backend.call("_handle_bridge_text", "32:4:1:2:2:1")
	_check(int(backend.authoritative_inventory[0].quantity) == 2 and int(backend.authoritative_inventory[1].quantity) == 1, "32 flag=4 应更新合并后的源/目标数量")
	backend.call("_handle_bridge_text", "32:5:false:1:2")
	_check(backend.authoritative_inventory.size() == 1, "32 flag=5 应清空指定格子")
	_跑完的.append("_validate_inventory_deltas")

func _validate_item_change_results(backend: Node) -> void:
	_item_change_results.clear()
	var signal_count_before := int(_signals.item_change_result_received)
	backend.call("_handle_bridge_text", "1042:1:12400002:2:0:12400001:1:2:12400001:1")
	backend.call("_handle_bridge_text", "1043:-1:12400001&1&3&0&12@12400002&2&4&1001&5")
	backend.call("_handle_bridge_text", "1819:-1:1:1&20@2&30")
	# ⚠️ 这两条的载荷**必须带槽位**（`<opcode>:<槽位>:<结果>`），和上面那条 2066 一样。
	# 原来这里写的是 `"2064:1"` / `"2065:0"` —— **载荷是手编的、少了槽位**，
	# 于是把"客户端把槽位当成结果读"这个 bug **钉成了期望值**，一直绿着。
	# 2026-09-23 靠在线用例（`装备打造在线回归测试` 的精炼段）才把它翻出来：
	# 真服务端发的是 `2065:-1:0`，客户端读成 result=-1（那是武器槽），界面显示"失败（-1）"。
	backend.call("_handle_bridge_text", "2064:-1:1")
	backend.call("_handle_bridge_text", "2065:-1:0")
	backend.call("_handle_bridge_text", "2066:-205:1")
	backend.call("_handle_bridge_text", "2317:2:13200002:1:13200001")
	_check(int(_signals.item_change_result_received) == signal_count_before + 7, "ItemChangeProcessor 的 7 个响应 opcode 应全部分派")
	_check(_item_change_results.size() == 7, "物品打造响应应输出结构化结果")
	_check(int(_item_change_results[0].success_item_id) == 12400002 and int(_item_change_results[0].left_count) == 2, "1042 应按原版顺序解析宝石合成结果")
	_check((_item_change_results[1].inlays as Array).size() == 2 and int(_item_change_results[1].inlays[1].skill_id) == 1001, "1043 应解析五字段镶嵌列表")
	_check((_item_change_results[2].plus_attributes as Array).size() == 2 and int(_item_change_results[2].plus_attributes[0].attribute_value) == 20, "1819 应解析附加属性预览")
	_check(String(_item_change_results[3].kind) == "forge_strength" and int(_item_change_results[3].equipment_position) == -1 and int(_item_change_results[3].result) == 1, "2064 应解析百炼强化的槽位与结果")
	_check(String(_item_change_results[4].kind) == "forge_additive" and int(_item_change_results[4].equipment_position) == -1 and int(_item_change_results[4].result) == 0, "2065 应解析百炼附加的槽位与结果")
	_check(int(_item_change_results[5].equipment_position) == -205 and int(_item_change_results[5].result) == 1, "2066 应解析昆虫强化槽位和结果")
	_check(int(_item_change_results[6].success_count) == 2 and int(_item_change_results[6].left_item_id) == 13200001, "2317 应解析徽章石合成结果")
	# 2081 / 2082（十拳剑炼制、人具开光）：原版 `LingEquipProcessor.handleLingEquipOperationResult:69-105`
	# 是一个 `switch(cmd)`，`RenJuProcessor:44-51` 同一形状 ⇒ 本工程把它们并进 ItemChange 那条分派。
	# 载荷 = `<动作>:<结果>[:<词条>]`，词条是 `类型&数值@…`，**空载用 `-`**（夹具 `_encode_ling_qi_attributes:52247`
	# 没词条时发的就是 `-`；`EquipmentAttribute.ATTACK = 4`）。
	backend.call("_handle_bridge_text", "2081:0:1")
	backend.call("_handle_bridge_text", "2081:1:1:4&1@4&1@4&1@4&1@4&1@4&1")
	backend.call("_handle_bridge_text", "2081:2:1:4&7")
	backend.call("_handle_bridge_text", "2081:1:0:-")
	backend.call("_handle_bridge_text", "2082:0:1")
	_check(_item_change_results.size() == 12, "2081/2082 的结果帧该一并走 ItemChange 分派（7 + 5）")
	# ⚠ 取法一律**越界安全**：反向对照（把两条 opcode 的分派摘掉）时这里只剩 7 条，
	#    直接下标 [7] 会让门**崩**在看门狗里、看不到红。
	var 灵开: Dictionary = _item_change_results[7] if _item_change_results.size() > 7 else {}
	_check(String(灵开.get("kind", "")) == "ling_qi_result" and int(灵开.get("action", -1)) == 0
			and int(灵开.get("result", -1)) == 1 and (灵开.get("plus_attributes", []) as Array).is_empty(),
			"2081 开光那支只有 动作/结果（`handleLingEquipKaiGuangResult` 只 readBoolean）")
	var 灵化: Dictionary = _item_change_results[8] if _item_change_results.size() > 8 else {}
	_check(int(灵化.get("action", -1)) == 1 and int(灵化.get("result", -1)) == 1
			and (灵化.get("plus_attributes", []) as Array).size() == 6
			and int((灵化.get("plus_attributes", []) as Array)[0].attribute_value) == 1,
			"2081 灵化带回 6 条附加（夹具 `_spiritualize_ling_qi:52291` 写的正是 6 行 [ATTACK,1]）")
	var 洗帧: Dictionary = _item_change_results[9] if _item_change_results.size() > 9 else {}
	var 洗条: Array = 洗帧.get("plus_attributes", []) as Array
	_check(int(洗帧.get("action", -1)) == 2 and 洗条.size() == 1 and int(洗条[0].attribute_value) == 7,
			"2081 洗炼带回新词条预览（`handleLingEquipWashUpResult` 的 plusAttrList）")
	var 败帧: Dictionary = _item_change_results[10] if _item_change_results.size() > 10 else {}
	_check((败帧.get("plus_attributes", []) as Array).is_empty() and int(败帧.get("result", -1)) == 0
			and not 败帧.is_empty(), "2081 失败帧的 `-` 该解成空词条表，不是 1 条脏行")
	var 人帧: Dictionary = _item_change_results[11] if _item_change_results.size() > 11 else {}
	_check(String(人帧.get("kind", "")) == "ren_ju_result"
			and int(人帧.get("action", -1)) == 0
			and int(人帧.get("result", -1)) == 1,
			"2082 人具开光结果帧该单独成 kind（原版两支管理器不同）")
	# 1352 秘笈合成（2026-10-03 接通）：text `1352:<cmd>:<0/1>`，cmd=0 + readBoolean
	# （原版 `AllInOneProcessor.handleCanJuan`）。失败**没有话术**、只有这一帧 0 —— 原版语义。
	var 秘笈结果: Array = []
	backend.can_juan_result_received.connect(func(s: bool): 秘笈结果.append(s))
	backend.call("_handle_bridge_text", "1352:0:1")
	backend.call("_handle_bridge_text", "1352:0:0")
	_check(秘笈结果.size() == 2 and bool(秘笈结果[0]) and not bool(秘笈结果[1]),
			"1352 结果帧双向解析（1=成功、0=失败）")
	backend.call("_handle_bridge_text", "1352:1:1")
	_check(秘笈结果.size() == 2, "1352 cmd≠0 的帧不当结果解析")
	_跑完的.append("_validate_item_change_results")

func _validate_item_effect_results(backend: Node) -> void:
	_item_effect_results.clear()
	var signal_count_before := int(_signals.item_effect_received)
	backend.call("_handle_bridge_text", "1292:3000001:30:60")
	backend.call("_handle_bridge_text", "1294:3010001:45:90")
	# 1293 双倍经验：服务端帧是 `1293:<type>:<rate>:<item_id>:<remaining>:<total>`
	# （`fake_flash_server.py:48968-48977` `_send_timed_item_effect` 的 shuangbei 支）。
	backend.call("_handle_bridge_text", "1293:1:2:3020001:120:600")
	# ⚠️ 这里原有 2324(stone_merge) 与 1295(item_misc) 两条 —— 那两个 opcode
	#    **服务端根本不存在**（`fake_flash_server.py` 全文 grep 零命中；宝石合成/物品杂项
	#    在服务端是别的编号）。所以客户端这两条从来接不到线，不是本轮删二进制路删坏的。
	#    已知缺陷，见 `开发记录（本地）` §3.27。
	_check(int(_signals.item_effect_received) == signal_count_before + 3, "ItemEffectProcessor 的三类在线状态应全部分派（1292 / 1293 / 1294）")
	_check(String(_item_effect_results[0].kind) == "auto_consume" and int(_item_effect_results[0].state.remaining_seconds) == 30, "1292 应解析自动消耗计时")
	_check(String(_item_effect_results[1].kind) == "attribute_boost" and int(_item_effect_results[1].state.total_seconds) == 90, "1294 应解析属性药计时")
	_check(String(_item_effect_results[2].kind) == "double_exp" and int(_item_effect_results[2].state.item_id) == 3020001 and int(_item_effect_results[2].state.rate) == 2, "1293 应解析双倍经验状态（含倍率与道具编号）")
	# —— 237 ITEM_COOLDOWN（2026-10-17 巡检 #20-C）——
	# 真值 `AllInOneProcessor.handleItemCooldownPacket:537-565`：秒>0 起冷、**秒<=0 是取消**。
	# 服务端拿"秒<=0"当**拒绝回执**用（满血满蓝 `:50540-50551`、五行封印 `:50336`、
	# 竞技场内 `:50344` 之后、共享药剂 CD `:50394`），客户端原来整条不接 ⇒ 全静默。
	_物品冷却帧.clear()
	backend.call("_handle_bridge_text", "237:3000001:0:5")
	_check(_物品冷却帧.size() == 1 and int(_物品冷却帧[0].id) == 3000001 and int(_物品冷却帧[0].s) == 5,
			"237 秒>0 应广播「开始冷却」并带剩余秒（原版 onItemCooldown 那一支）；实收 %s" % [ _物品冷却帧])
	_check(bool(backend.call("物品冷却中", 3000001)), "秒>0 之后本地该判这件在冷却（原版 SkillHandler.isItemCooling 那一头）")
	backend.call("_handle_bridge_text", "237:3000001:0:0")
	_check(_物品冷却帧.size() == 2 and int(_物品冷却帧[1].s) == 0,
			"秒<=0 应广播**取消**（原版 onItemCooldownCancel 那一支，不能和开始冷却走同一条）；实收 %s" % [_物品冷却帧])
	_check(not bool(backend.call("物品冷却中", 3000001)),
			"取消帧之后不许还判冷却中 —— 这条红的表现是"
			+ "「吃药被服务端拒了一次，之后这件药永远点不动」")
	backend.call("_handle_bridge_text", "237:3000002:0")
	_check(not bool(backend.call("物品冷却中", 3000002)),
			"字段不齐（只有两个）的 237 要**丢帧不崩**，也不许建半截状态")
	_check(not bool(backend.call("物品冷却中", 9999999)), "反向对照：没发过冷却的物品不该被判冷却中（否则这条腿是空转的）")
	_跑完的.append("_validate_item_effect_results")

func _validate_shop_and_storage(backend: Node) -> void:
	_shop_snapshots.clear()
	_shop_codes.clear()
	_storage_snapshots.clear()
	backend.call("_handle_bridge_text", "326:2:武器&1010021#500#0#500#1#1#false!3000001#20#0#20#99#2#false@药品&3010001#30#0#30#99#2#false")
	_check(_shop_snapshots.size() == 1 and int(_shop_snapshots[0].npc_id) == 2, "326 应解析 NPC 商店编号")
	_check((_shop_snapshots[0].tabs as Array).size() == 2 and (_shop_snapshots[0].items as Array).size() == 3, "326 应解析多分页商品列表")
	_check(String(_shop_snapshots[0].items[0].id) == "01010021" and int(_shop_snapshots[0].items[0].price) == 500, "商店装备编号应恢复八位格式和原版价格")
	# 服务端帧：`327:<确认码>`（`fake_flash_server.py:55700`）。
	backend.call("_handle_bridge_text", "327:0")
	_check(_shop_codes == [0], "327 应解析商店交易确认码")
	var ramen := "2&3000001&1&5&0&0&1&测试角色&0&6001"
	var weapon := "1&1010021&2&1&0&0&1&测试角色&0&6002&3&100&90&1&40&2&8&1*12&-1&0&0&-&4&true!true&0&0&0&0&0"
	backend.call("_handle_bridge_text", "330:1:2:30:800:2:%s@%s" % [ramen, weapon])
	_check(_storage_snapshots.size() == 1 and int(_storage_snapshots[0].gold) == 800 and int(_storage_snapshots[0].capacity) == 30, "330 action=1 应解析仓库快照、金币和容量")
	_check((_storage_snapshots[0].items as Array).size() == 2, "仓库快照应保留完整物品实例")
	backend.call("_handle_bridge_text", "330:4:2&3000001&1&7&0&0&1&测试角色&0&6001")
	_check(int(_storage_snapshots[-1].items[0].quantity) == 7, "330 action=4 应更新单个仓库格")
	backend.call("_handle_bridge_text", "330:5:2")
	_check((_storage_snapshots[-1].items as Array).size() == 1, "330 action=5 应清空仓库格")
	backend.call("_handle_bridge_text", "330:3:30:900")
	_check(int(_storage_snapshots[-1].gold) == 900, "330 action=3 应更新仓库金币")
	backend.call("_handle_bridge_text", "330:6:30:900:3000001&3&7&6001")
	_check(int(_storage_snapshots[-1].items[0].slot_index) == 3, "330 action=6 应按 ItemSortInfo 顺序刷新仓库槽位")
	_跑完的.append("_validate_shop_and_storage")

func _validate_pet_packets(backend: Node) -> void:
	_pet_snapshots.clear()
	_pet_actions.clear()
	# ⚠️ 整宠帧里的装备行**没有"物品类型"那一位**：服务端 `_encode_pet_equipment` 是
	#    `_encode_item_payload(item).split("&")[1:]`（原版 `CocoEquip.decode:248` 不读类型位），
	#    而且内层子表（plus_attributes/inlays/strength_info）的行分隔符会被换成 `+`/`*`
	#    —— 因为这一层的行分隔符就是 `!`/`@`，不换会串行。客户端解析器对应地补类型位。
	#    这段原来是按**旧解析口径**写的（带 "1#"、内层还用 "!"），2026-09-28 改正。
	var pet_armor := "02010010#1#1#0#0#1#测试角色#0#6003#3#100#90#1#40#2#8#1*12#-1#0#0#-#4#true*true#0#0#0#0#0"
	var encoded := "101&1&1&0&0&0&测试角色&0&9001&1234&一阶忍犬&2&0&0&0&1&3&20&80&18&12&8&10&100&100&100&100&101&%s&7001001#1#10&0" % pet_armor
	backend.call("_handle_bridge_text", "173:0:10:%s" % encoded)
	_check(_pet_snapshots.size() == 1 and int(_pet_snapshots[0].capacity) == 10, "173 action=0 应初始化宠物容量和列表")
	_check((_pet_snapshots[0].pets as Array).size() == 1 and int(_pet_snapshots[0].pets[0].unique_id) == 9001, "宠物快照应解析 CocoPet 31 字段")
	_check(int(_pet_snapshots[0].pets[0].attack) == 18 and int(_pet_snapshots[0].pets[0].skills[0].id) == 7001001, "宠物潜力和技能列表应按原版分隔符解析")
	var snapshot_equipment: Dictionary = _pet_snapshots[0].pets[0].equipment[0]
	_check(int(snapshot_equipment.id) == 2010010 and int(snapshot_equipment.equipment_slot) == 1, "宠物快照应解析完整装备实例及装备槽")
	_check(not String(snapshot_equipment.icon).is_empty() and FileAccess.file_exists(String(snapshot_equipment.icon)), "宠物快照装备应命中真实物品图标")
	backend.call("_handle_bridge_text", "173:4:1234:9001:101:一阶忍犬:100:200:0:0:101:125")
	_check(bool(_pet_snapshots[-1].pets[0].deployed), "173 action=4 攻击出战应更新宠物位置")
	backend.call("_handle_bridge_text", "173:6:1234:9001:1")
	_check(not bool(_pet_snapshots[-1].pets[0].deployed), "173 action=6 收回应清除出战状态")
	backend.call("_handle_bridge_text", "173:11:1234:9001:赤丸")
	_check(String(_pet_snapshots[-1].pets[0].name) == "赤丸", "173 action=11 应增量更新宠物名称")
	backend.call("_handle_bridge_text", "173:12:1234:9001:7001001:2:10")
	_check(int(_pet_snapshots[-1].pets[0].skills[0].level) == 2, "173 action=12 应增量更新宠物技能")
	var pet_claw := "1&02020010&2&1&0&0&1&测试角色&0&6004&3&100&90&1&40&2&8&1*12&-1&0&0&-&4&true!true&0&0&0&0&0"
	backend.call("_handle_bridge_text", "173:13:1234:9001:%s" % pet_claw)
	var equipment_after_put: Array = _pet_snapshots[-1].pets[0].equipment
	_check(equipment_after_put.size() == 2 and int(equipment_after_put[-1].id) == 2020010 and int(equipment_after_put[-1].equipment_slot) == 2, "173 action=13 应增量加入权威宠物装备")
	backend.call("_handle_bridge_text", "173:14:1234:9001:2")
	var equipment_after_take_off: Array = _pet_snapshots[-1].pets[0].equipment
	_check(equipment_after_take_off.size() == 1 and int(equipment_after_take_off[0].equipment_slot) == 1, "173 action=14 应按槽移除权威宠物装备")
	_check(_pet_actions.size() == 7, "173 宠物动作应逐个分派结构化结果")
	_跑完的.append("_validate_pet_packets")

func _validate_cash_shop_packets(backend: Node) -> void:
	_cash_shop_snapshots.clear()
	_cash_shop_capacities.clear()
	_cash_item_infos.clear()
	var ramen := "3000001&30&20&1&0&0&0&0&0&0&1&1&0&3000001&0&0"
	var potion := "3010001&45&45&0&1&100&200&1&20&3&0&0&0&3010001&7&0"
	backend.call("_handle_bridge_text", "1074:2:2:%s@%s" % [ramen, potion])
	_check(_cash_shop_snapshots.size() == 1 and String(_cash_shop_snapshots[0].source) == "category", "1074 应分派商城分类目录")
	var category_items: Array = _cash_shop_snapshots[0].items
	_check(category_items.size() == 2 and int(category_items[0].sn) == 3000001 and int(category_items[0].price) == 20, "1074 应按 CashItemInfo 的 16 字段顺序解析商品")
	_check(String(category_items[0].name) == "拉面（小）" and not String(category_items[0].icon).is_empty(), "商城商品应关联真实物品名称和图标")
	backend.call("_handle_bridge_text", "1075:1:1:%s" % potion)
	_check(_cash_shop_snapshots.size() == 2 and String(_cash_shop_snapshots[1].source) == "search" and int(_cash_shop_snapshots[1].total) == 1, "1075 应分派服务端搜索结果和总数")
	backend.call("_handle_bridge_text", "1079:%s" % ramen)
	_check(_cash_item_infos.size() == 1 and bool(_cash_item_infos[0].is_discount), "1079 应解析单个商城商品详情")
	backend.call("_handle_bridge_text", "1084:30")
	_check(_cash_shop_capacities == [30] and int(backend.authoritative_cash_shop_capacity) == 30, "1084 应保存商城分类容量")
	_跑完的.append("_validate_cash_shop_packets")

func _validate_copy_and_hang_packets(backend: Node) -> void:
	_copy_states.clear()
	_hang_states.clear()
	backend.call("_handle_bridge_text", "817:0:0&1@3&2:2")
	backend.call("_handle_bridge_text", "817:1:3:5")
	backend.call("_handle_bridge_text", "817:5:3:2:12:1234:8")
	backend.call("_handle_bridge_text", "817:8:3:16000037&3@16000015&1")
	backend.call("_handle_bridge_text", "817:9:3:1")
	_check(_copy_states.size() == 5, "817 的历史、进入、开始、完成和领奖分支应全部分派")
	_check(int((_copy_states[0].history as Dictionary).get(3, 0)) == 2 and int(_copy_states[0].total_count) == 2, "817:0 应按 copyId&count 解析历史")
	_check(int(_copy_states[1].pending_copy_id) == 3 and int(_copy_states[1].countdown) == 5, "817:1 应解析进入倒计时")
	_check(int(_copy_states[2].copy_id) == 3 and int(_copy_states[2].pass_time) == 12 and int(_copy_states[2].character_id) == 1234, "817:5 应解析单人副本状态")
	_check((_copy_states[3].rewards as Array).size() == 2 and int(_copy_states[3].rewards[0].quantity) == 3, "817:8 应按 itemId&count 解析完成奖励")
	_check(bool(_copy_states[4].success), "817:9 应解析领奖结果")
	backend.call("_handle_bridge_text", "1808:0:1:1000:101010000:120")
	backend.call("_handle_bridge_text", "1808:1:0:0:101010000:240")
	_check(_hang_states.size() == 2 and bool(_hang_states[0].active) and not bool(_hang_states[1].active), "1808 应解析服务端确认的挂机开停状态")
	_check(int(_hang_states[1].elapsed_seconds) == 240, "1808 应保留服务端累计挂机时间")
	_跑完的.append("_validate_copy_and_hang_packets")

func _validate_map_isolation(backend: Node) -> void:
	backend.call("_handle_bridge_text", "162:9201:旧地图玩家:100:0:0:1:0:0:-:-:0:0:0:120:220:1:0:0:12:0:0:0:-:-:-:0:0:0")
	backend.call("_handle_bridge_text", "238:1:7201:0:1001001:101010000:300:400:0:0:0:0:true:0:300:400:0:0:-:-:-:0:false:false:false:0:0")
	backend.call("_handle_bridge_text", "260:8201:2:500:600:450:550:-1:7")
	backend.call("_handle_bridge_text", "272:6201:false:3000001:false:0:1234:410:420:390:400:0:5")
	backend.call("_apply_map_state", 101020000, 10, 20, 100)
	_check(backend.map_players.is_empty() and backend.map_monsters.is_empty() and backend.map_npcs.is_empty() and backend.map_drops.is_empty(), "切换权威地图时应清空上一张地图的全部实体缓存")
	_跑完的.append("_validate_map_isolation")

func _validate_pre_game_spawn_gate(backend: Node) -> void:
	backend.in_game = false
	backend.call("_apply_map_state", 101010000, 0, 0, 100)
	var entities := MAP_ENTITIES_SCRIPT.new()
	entities.set("_backend", backend)
	entities.call("_on_server_player_spawned", {"character_id": 9301, "map_id": 101010000, "face": 1})
	_check((entities.get("_remote_players") as Dictionary).is_empty(), "进入游戏前收到 162 不应在场景生成自己的分身")
	entities.free()
	backend.in_game = true
	_跑完的.append("_validate_pre_game_spawn_gate")

func _validate_remote_appearance_assets() -> void:
	for face_id in [1, 2, 100, 103, 200, 203, 300, 303, 400, 403]:
		var sprite := ORIGINAL_SPRITE_SCRIPT.new()
		root.add_child(sprite)
		var model_id := str(face_id).pad_zeros(8)
		_check(sprite.configure("character", model_id, "stand") and sprite.sprite.texture != null, "原版远程角色模型 %s 应有可用动画贴图" % model_id)
		sprite.free()
	_跑完的.append("_validate_remote_appearance_assets")

func _validate_outgoing_requests(backend: Node) -> void:
	backend.sent_requests.clear()
	_check(backend.send_movement(Vector2(10, 20), 3, Vector2(-40, 0), -1), "移动请求应可发送（第 3 段是动作号：3=走）")
	## 段序照服务端 `handle_move()` 的读法（项目内那份 `fake_flash_server.py`）：
	## `36:<x>:<y>:<movement_action>:<速度x>:<速度y>:<movement_flag>:<朝向>`。
	## 以前这条钉的是 `36:10:20:-1`（把朝向塞进动作槽）⇒ 服务端夹成"站立"再广播回来，
	## 旁观者永远看不到走路帧（用户 10-14 报）。
	## 10-17 补第 8 段朝向：`_request_fields()` 剥掉 opcode 之后 fields[6] 就是朝向，
	## 服务端 `handle_move` 再把它塞进 187 的第 12 段 ⇒ 收端 `set_direction` 照它转身
	## （双修对坐时"他该朝左却朝右"就是缺这一格）。
	_check(int(backend.sent_requests[0].opcode) == 36
			and String(backend.sent_requests[0].content) == "36:10:20:3:-40:0:2:-1",
			"移动请求要用服务端认的 7 段形状（3=走、速度x=-40、2=落地、朝向-1），实得 %s"
			% String(backend.sent_requests[0].content))
	## 1282 玩家搜索：**包体形状只能在这里钉**（双修那扇门里的假后端只记参数、不拼串，
	## 不然就是"两边照抄同一份自造格式"⇒ 一起错也一起绿）。两条口径：
	## ① content **不重复带 opcode** —— `_send_bridge_request:5628` 只补时间戳，
	##    服务端 `_request_fields:57631` 是"开头正好等于本条 opcode 才剥"的读法，
	##    所以这一族跟 `OP_STORAGE`/`OP_PET_ACTION` 那一支一致（不带前缀）。
	## ② 原版 `Client.requestCharSearchInMap` = `writeInt(searchType); writeByte(2); writeShort(0)`
	##    ⇒ mode 2 那一支**没有第三个字段**；服务端 `handle_char_search:35004` 也是
	##    `fields[2] if len(fields) > 2 else ""` 的读法。以前用 `%s` 拼空名字 ⇒ 多发一个尾随冒号。
	backend.sent_requests.clear()
	_check(bool(backend.request_char_search("", 2, 4)), "双修选人（同屏可见）请求应可发送")
	_check(int(backend.sent_requests[0].opcode) == 1282
			and String(backend.sent_requests[0].content) == "4:2",
			"同屏搜索 = searchType:mode、不带尾随冒号，实得 %s" % String(backend.sent_requests[0].content))
	backend.sent_requests.clear()
	_check(bool(backend.request_char_search("木叶", 1, 4)), "按名字搜请求应可发送")
	_check(String(backend.sent_requests[0].content) == "4:1:木叶",
			"按名字搜 = searchType:mode:名字，实得 %s" % String(backend.sent_requests[0].content))
	## 1283 / 7779 / 1808 挂机三条（#272）。**形状错了服务端会静默什么都不做**：
	## `handle_char_config:17899` 是 `_strip_timestamp` 之后**整串当载荷** ——
	## 多发一个 `1283:` 头，查询不再等于 `"0"`、保存 `json.loads` 抛错 ⇒ 一条回帧都没有。
	backend.sent_requests.clear()
	_check(bool(backend.request_hang_config_query()), "1283 查询请求应可发送")
	_check(int(backend.sent_requests[0].opcode) == 1283
			and String(backend.sent_requests[0].content) == "0",
			"1283 查询的载荷就一个 0（不带 opcode），实得 %s" % String(backend.sent_requests[0].content))
	backend.sent_requests.clear()
	_check(bool(backend.request_hang_config_save({"autoReplyHp": true, "auotReplyHpValue": 70,
			"autoBattleRange": 20})), "1283 保存请求应可发送")
	var 存载荷 := String(backend.sent_requests[0].content)
	_check(int(backend.sent_requests[0].opcode) == 1283 and 存载荷.begins_with("{")
			and 存载荷.contains('"autoReplyHp":true') and 存载荷.contains('"auotReplyHpValue":70'),
			"1283 保存 = 整个 JSON 对象（原版字段名原样、含 auot* 错拼），实得 %s" % 存载荷)
	_check(not 存载荷.contains("keyData"),
			"保存载荷不带 keyData（服务端 17917-17934 拿它**整张替换**快捷键表）")
	backend.sent_requests.clear()
	_check(bool(backend.request_auto_sell_config(9, 120, 2, 6)), "7779 自动出售请求应可发送")
	_check(int(backend.sent_requests[0].opcode) == 7779
			and String(backend.sent_requests[0].content) == "9:120:2:6",
			"7779 = 掩码:等级:职业序号:品质 四个整数，实得 %s" % String(backend.sent_requests[0].content))
	backend.sent_requests.clear()
	_check(bool(backend.request_hang_start()) and bool(backend.request_hang_stop()),
			"1808 起/停请求应可发送")
	## ⚠ 这里**不用数组推导式**：`[String(一.content) for 一 in …]` 在 GDScript 4.7 的解析器里
	## 直接 `Expected closing "]"`（实测），而这一族断言只要少一条就是"1808 发错档"没人抓。
	var 起停串: Array[String] = []
	for 一 in backend.sent_requests:
		起停串.append(String(一.content))
	_check(起停串 == ["0", "1"],
			"1808 只有 0/1 两档（原版 requestGuaJi(0/1)；服务端 handle_hang_action:18329 也只认这两个），实得 %s"
			% str(起停串))
	## 1283 回帧 = `1283:` + 45 个 `CHAR_CONFIG_FIELDS` 值 + keyData + 13 个扩展值 = 60 段，
	## **段里没有键名** ⇒ 键表顺序一错位就会把布尔读成数字、把等级读成品质，而页面照样画得出来。
	挂配置.clear()
	var 段: Array[String] = ["1283"]
	for i in backend.挂机配置字段.size():
		段.append("true" if i == 8 else "33")	# 第 9 段 = autoReplyHp、第 29 段 = autoReplyHpValue
	段.append("1&2&3&4")						# keyData 占位
	for i in backend.挂机扩展字段.size():
		段.append("false")
	backend.call("_handle_bridge_text", "1283:" + ":".join(段))
	_check(bool(挂配置.get("autoReplyHp", false)) and int(挂配置.get("auotReplyHpValue", 0)) == 33,
			"1283 回帧按**服务端那份键表顺序**解出来了，实得 血=%s 值=%s"
			% [str(挂配置.get("autoReplyHp")), str(挂配置.get("auotReplyHpValue"))])
	_check(挂配置.size() == 45 + 13,
			"回帧字典 = 45 + 13 个键、keyData 那一格按位跳过，实得 %d 键" % 挂配置.size())
	backend.sent_requests.clear()
	_check(backend.request_basic_attack(7001, Vector2(10, 20), -1), "普攻请求应可发送")
	_check(backend.announce_skill_cast(1001001, 2, [7001, 7002], Vector2(10, 20), 1), "出手广播应可发送")
	_check(backend.request_skill_damage(1001001, 2, [7001, 7002], 1), "命中结算请求应可发送")
	backend.call("_handle_bridge_text", "243:7001:44")
	_check(_skill_hits.size() == 1 and int(_skill_hits[0].object_id) == 7001 and int(_skill_hits[0].skill_id) == 1001001 and int(_skill_hits[0].damage) == 44, "技能 hit 必须等待服务端 243 后再按目标分派")
	_check(backend.acknowledge_damage(7001, 17), "受击确认应可发送")
	_check(backend.request_pickup(6001), "拾取请求应可发送")
	_check(backend.request_use_item(1, 3000001), "使用物品请求应可发送")
	var opcodes: Array[int] = []
	for request in backend.sent_requests:
		opcodes.append(int(request.opcode))
	_check(opcodes == [40, 1328, 42, 44, 198, 69], "客户端请求顺序应为 40、1328、42、44、198、69，实际为 %s" % [opcodes])
	# 普攻改发服务端认的原版冒号命中包（目标必须在 index 12），不再是 JSON。
	var basic_fields := String(backend.sent_requests[0].content).split(":", true)
	_check(basic_fields.size() >= 14 and basic_fields[0] == "40" and int(basic_fields[13]) == 7001, "40 应携带服务端怪物 objectId（原版冒号命中包，目标在服务端 fields[12]＝原始第 13 段）")
	# ⚠️ 服务端 `_request_fields()` **先剥掉开头的 opcode 再编号**，所以这里的下标都比
	#    服务端文档里的多 1（服务端 fields[8]=技能id ↔ 这里 [9]；fields[13]=怪物 ↔ 这里 [14]）。
	#    判据抄的是服务端自己的写包器 `_player_attack_packet_body()`，不是我们这边的约定。
	var announcement_fields := String(backend.sent_requests[1].content).split(":", true)
	_check(announcement_fields.size() >= 15 and announcement_fields[0] == "1328"
			and int(announcement_fields[9]) == 1001001
			and String(announcement_fields[14]) == "7001@7002",
			"1328 应使用 BuildPlayerAttackPacket 的原版字段顺序，且带上全部目标")
	# 42 命中帧**不再是 JSON**：服务端 `_attack_skill_id()` 从（剥掉 opcode 后的）fields[9] 取技能 id、
	# `_attack_monster_target_ids()` 从 fields[12] 取目标，JSON 里的冒号会被切碎 → 整条被丢掉。
	# 所以现在和普攻同一张冒号字段表，只有 skillId/skillLevel/目标数不同。
	var skill_fields := String(backend.sent_requests[2].content).split(":", true)
	_check(skill_fields.size() >= 14 and skill_fields[0] == "42"
			and int(skill_fields[10]) == 1001001
			and String(skill_fields[13]) == "7001@7002",
			"42 命中帧应携带技能 id 与全部目标（冒号字段表，服务端 fields[9]/fields[12]）")
	_check(String(backend.sent_requests[5].content) == "1:3000001:-:false:::", "69 应使用 InventoryProcessor.requestUseItem 的 7 字段格式")
	backend.sent_requests.clear()
	## ⚠ **没有目标也要发得出 1328**（2026-10-14，用户实机"还是看不到别人释放技能特效"）：
	## 原版 `AbstractAttackSkill.hitTest()` 是一出手就 `requestPlayerAttackInfo(...)`（`:629`），
	## 前面那个 switch 连"没目标"那一档（`getSkillTarget()==2`，`:625`）都照样发 ——
	## 广播 = **出手动作 + 特效**，只有结算那条 42 才需要目标。
	## 2026-10-14 又把这俩拆成两个时刻：广播=按下这一拍（`announce_skill_cast`），
	## 结算=命中那一拍（`request_skill_damage`）；捆在一起压到命中帧 ⇒ 旁观者看投掷技晚几百毫秒。
	_check(backend.announce_skill_cast(4010, 1, [], Vector2(30, 40), -1, 12), "空目标出手也应发得出广播")
	var 空标 := String(backend.sent_requests[0].content).split(":", true)
	_check(int(backend.sent_requests[0].opcode) == 1328 and 空标.size() >= 15
			and String(空标[14]) == "-" and int(空标[9]) == 4010 and int(空标[6]) == 12
			and int(空标[11]) == 30 and int(空标[7]) == -1,
			"空目标那条要发得出 1328、目标槽写成 `-`、出手号与朝向照原样带上（实得第 15 段「%s」）"
					% String(空标[14]))
	_check(not backend.request_skill_damage(4010, 1, [], -1, 12), "空目标**不该发 42**")
	_check(backend.sent_requests.size() == 1,
			"空目标时场上只有那一条广播（实发 %d 条）" % backend.sent_requests.size())
	backend.sent_requests.clear()
	_check(backend.request_strength(-1, 0), "普通强化请求应可发送")
	_check(backend.request_stage_up(-1, 2, false, true), "装备进阶请求应可发送")
	_check(backend.request_forge_additive(-1), "附加属性精炼请求应可发送")
	_check(backend.request_strength_kunchong(-205, false, 0), "昆虫强化请求应可发送")
	_check(backend.sent_requests.size() == 4, "1040 命名动作包装应逐个发送")
	_check(String(backend.sent_requests[0].content) == "5:-1:0", "普通强化应使用 1040:5:equipSlot:luckyCount 字段顺序")
	# ⚠️ **布尔上线发 1/0，不发 "true"/"false"**（2026-10-17 巡检 #7）：
	#   原版 `ItemChangeProcessor.requestStrengthKunChong:223-227` / `requestStageUp:366-367`
	#   写的都是 `writeByte(bool ? 1 : 0)`；服务端 `_strengthen_kun_chong` 那一位用
	#   `self._safe_int(fields[2], 0) != 0` 读（`fake_flash_server.py:53632-53634`），
	#   `"true"` 进去只能退回默认 0 ⇒ 勾了镇灵石**等于没勾**（保底整条静默失效）。
	_check(String(backend.sent_requests[1].content) == "3:-1:2:0:1", "装备进阶的两个布尔该发 1/0")
	_check(String(backend.sent_requests[2].content) == "22:-1", "附加属性精炼应使用动作 22")
	_check(String(backend.sent_requests[3].content) == "25:-205:0:0", "昆虫强化应使用动作 25 的四字段格式")
	# 同一条**勾上镇灵石 + 3 张幸运符**那支：那一位必须是 `1`（服务端按 int 读，见上面注释）。
	_check(backend.request_strength_kunchong(-205, true, 3), "勾了镇灵石的昆虫强化请求应可发送")
	_check(String(backend.sent_requests[4].content) == "25:-205:1:3",
			"镇灵石那一位该发 1（发 \"true\" 服务端读成 0 ⇒ 保底静默失效），实得「%s」"
			% String(backend.sent_requests[4].content))
	# 巡检 #19：`requestRepairEquip`（`ItemChangeProcessor.as:249-255`）子命令 7 后面**只有一个** int，
	# 那是**修理方式**（0 普通 / 1 特殊），不是格位 ⇒ 服务端拿它一次修身上全部装备。
	_check(backend.request_repair_equip(0) and backend.request_repair_equip(1), "装备修理请求应可发送")
	_check(String(backend.sent_requests[5].content) == "7:0"
			and String(backend.sent_requests[6].content) == "7:1",
			"装备修理该发 1040:7:修理方式，实测「%s」「%s」"
			% [String(backend.sent_requests[5].content), String(backend.sent_requests[6].content)])
	backend.sent_requests.clear()
	_check(backend.request_zhenqidan_extract_packet(PackedByteArray([120, 156, 1])), "真气丹提取请求应可发送预编码 AMF3 载荷")
	_check(int(backend.sent_requests[0].opcode) == 1568 and String(backend.sent_requests[0].content) == "00010003789c01", "1568 应使用 action、压缩长度、AMF3 载荷的原版大端布局")
	backend.sent_requests.clear()
	_check(backend.request_npc_menu_action(1), "NPC 服务菜单请求应可发送")
	_check(backend.request_npc_shop_buy(1010021, 2), "NPC 商店购买请求应可发送")
	_check(backend.request_npc_shop_sell(4, 3000001, 3), "NPC 商店出售请求应可发送")
	_check(backend.request_storage_store_item(4, 3), "仓库存入请求应可发送")
	_check(backend.request_storage_take_item(2, 1), "仓库取出请求应可发送")
	_check(backend.request_storage_store_gold(100), "仓库存入金币请求应可发送")
	_check(backend.request_storage_take_gold(40), "仓库取出金币请求应可发送")
	_check(backend.request_storage_close(), "关闭仓库请求应可发送")
	_check(int(backend.sent_requests[0].opcode) == 57 and String(backend.sent_requests[0].content) == "2:1", "57 应使用 NPCTalkProcessor 的菜单命令和值字段")
	_check(String(backend.sent_requests[1].content) == "0:1010021:2" and String(backend.sent_requests[2].content) == "1:4:3000001:3", "58 应使用 NPCShopProcessor 原版买卖字段顺序")
	_check(String(backend.sent_requests[3].content) == "3:4:3" and String(backend.sent_requests[4].content) == "2:2:1", "59 应使用 StorageProcessor 原版存取物品字段顺序")
	_check(String(backend.sent_requests[5].content) == "4:100" and String(backend.sent_requests[6].content) == "5:40" and String(backend.sent_requests[7].content) == "8", "59 应使用原版存取金币和关闭动作")
	backend.sent_requests.clear()
	# 58 的 action 5 = **一键出售**：`PacketCreator.getNPCShopOnekeySellRequestPacket:102-111`
	# 是 `writeByte(5)` + **4 个 writeInt**（等级上限、星级上限、品质上限、目标位图）。
	# 旧签名只发 3 个、还把前两个当**格位区间** ⇒ 夹具把第 3 个读成品质上限 0 ⇒ 恒回 SHOP_ERROR
	# （巡检 #18；位图常量见 `QuickSaleWindow.as:18-22`：1装备|2残卷|4玉链，装备那一位恒带）。
	_check(backend.request_npc_shop_one_key_sell(20, 3, 1), "一键出售请求应可发送")
	_check(backend.request_npc_shop_one_key_sell(80, 5, 3, 7), "一键出售请求（带目标位图）应可发送")
	_check(String(backend.sent_requests[0].content) == "5:20:3:1:1"
			and String(backend.sent_requests[1].content) == "5:80:5:3:7",
			"一键出售该发五位（动作 + 等级/星/品质/位图），实测「%s」「%s」"
			% [String(backend.sent_requests[0].content), String(backend.sent_requests[1].content)])
	backend.sent_requests.clear()
	_check(backend.request_pet_call_out(9001), "宠物召出请求应可发送")
	_check(backend.request_pet_call_back(9001), "宠物收回请求应可发送")
	_check(backend.request_pet_rename(9001, "赤丸"), "宠物改名请求应可发送")
	_check(backend.request_pet_feed(9001, 16000014), "宠物喂养请求应可发送")
	_check(backend.request_pet_attack_out(9001), "宠物攻击出战请求应可发送")
	_check(backend.request_pet_put_equipment(9001, 6), "宠物装备穿戴请求应可发送")
	_check(backend.request_pet_take_off_equipment(9001, 2), "宠物装备卸下请求应可发送")
	_check(backend.request_pet_strength_potential(9001, 2, 4), "宠物潜力请求应可发送")
	_check(backend.request_pet_catch(7001), "宠物捕捉请求应可发送")
	_check(backend.request_pet_soul_fusion(9001, 8), "宠物融魂请求应可发送")
	var pet_contents: Array[String] = []
	for request in backend.sent_requests:
		_check(int(request.opcode) == 95, "宠物请求必须使用 PET_ACTION opcode 95")
		pet_contents.append(String(request.content))
	_check(pet_contents == ["1:9001", "2:9001", "3:9001:赤丸", "4:9001:16000014", "13:9001", "15:9001:6", "16:9001:2", "18:9001:2:4", "21:7001", "22:9001:8"], "95 应保持 PetProcessor 原版动作与字段顺序")

	## ── 聊天 1536：六个频道共用这一条组包，而且是少数几条**必须自带 opcode 前缀**的 ──────
	## 服务端 `handle_chat_message`（项目内 `fake_flash_server.py:39693-39709`）头两句是
	## `if not payload.startswith("1536:"): return` 与 `if len(fields) < 8: return`，
	## 而 `_send_bridge_request` **不补 opcode**（`readStr = content + ":" + 时间戳`）。
	## 2026-10-17 用户报"点私聊没反应"，量到的正是这两处：以前发
	## `"0:1:4:0:<号>:<话>:-:0:<名>"` ⇒ 头一句就被丢掉（**普通/队伍/家族/世界/喇叭一起死**，
	## 连服务端回给我自己那一份都没有）；就算补上 `1536:`，`tag` 与对象名之间**多写的那个 0**
	## 会让服务端按 `fields[5:-2]` 切出「话:-」—— 正文尾巴粘着 tag，对象名还挪了一位。
	## 段序真值 = 原版 `ChatMessage.encode`（`ChatMessage.as:43-54`）经服务端
	## `_original_request_text`（`:12629-12662`）重排出来的那一条；`positions` 发 **0** 是
	## 原版构造里的 `msgPositions = 0`（`:34`），显示位由服务端按频道映射（私聊 16 / 普通 8）。
	backend.sent_requests.clear()
	_check(backend.request_chat("今晚打老虎", 4, 1002, "社交同伴"), "私聊上行应可发送")
	_check(backend.request_chat("各位好", 3), "普通频道上行应可发送")
	_check(int(backend.sent_requests[0].opcode) == 1536
			and String(backend.sent_requests[0].content) == "1536:0:0:4:0:1002:今晚打老虎:-:社交同伴",
			"1536 私聊 = 前缀 + charType/positions/msgType/targetType/targetId/正文/tag/对象名 八段（实得「%s」）"
					% String(backend.sent_requests[0].content))
	_check(int(backend.sent_requests[1].opcode) == 1536
			and String(backend.sent_requests[1].content) == "1536:0:0:3:0:0:各位好:-:",
			"1536 普通 = 同一条形状、对象两段留空，positions 交服务端映射（实得「%s」）"
					% String(backend.sent_requests[1].content))
	backend.sent_requests.clear()
	_check(not backend.request_chat("   ", 3), "空正文不该发包")
	_check(backend.sent_requests.is_empty(), "被拦住的这条一条都没出门")

	## ── 目标信息条那排钮（原版 `DetailsWindow` 六颗 + 菜单）⇒ 这五发的形状 ──────────
	## ⚠ 这五条的**第一段就是原版的 action 字节**，不带 opcode 前缀：服务端 `_request_fields`
	## （项目内 `fake_flash_server.py:57538-57547`）只在 `fields[0] == str(opcode)` 时才剥头一段，
	## 所以 `"2:1001"` 交给 119 读到的正是 `action=2, target=1001`。
	## 反过来，写成 `"119:2:1001"` 会让它多剥一段 ⇒ 目标号掉进别的槽（187 段序偏一格就是同一个形状）。
	backend.sent_requests.clear()
	_check(backend.request_trade_invite(1001), "交易邀请应可发送")
	_check(backend.request_stall_open(1001), "看摊请求应可发送")
	_check(backend.request_tutor_apply(3, 1001), "拜师申请应可发送")
	_check(backend.request_tutor_apply(4, 1001), "收徒申请应可发送")
	_check(backend.request_character_info(1001), "查别人资料应可发送")
	_check(int(backend.sent_requests[0].opcode) == 119
			and String(backend.sent_requests[0].content) == "2:1001",
			"119 交易邀请 = action 2 + 角色号（服务端 handle_player_interaction 的 fields[0]/[1]）")
	_check(int(backend.sent_requests[1].opcode) == 1296
			and String(backend.sent_requests[1].content) == "2:1001",
			"1296 看摊 = action 2 + 摊主号（StallProcessor.as:262-268）")
	_check(int(backend.sent_requests[2].opcode) == 77
			and String(backend.sent_requests[2].content) == "3:1001",
			"77 拜师 = action 3 + 角色号（TutorProcessor.as:222-228）")
	_check(int(backend.sent_requests[3].opcode) == 77
			and String(backend.sent_requests[3].content) == "4:1001",
			"77 收徒 = action 4 + 角色号（TutorProcessor.as:246-252）")
	_check(int(backend.sent_requests[4].opcode) == 94
			and String(backend.sent_requests[4].content) == "4:1001",
			"94 查资料 = action 4 + 角色号（request_character_info 既有口径）")
	backend.sent_requests.clear()
	_check(not backend.request_trade_invite(0), "没选中玩家（角色号 0）时不该发出交易邀请")
	_check(not backend.request_stall_open(0) and not backend.request_tutor_apply(3, 0),
			"同理 0 号不该发看摊/师徒")
	_check(backend.sent_requests.is_empty(), "被拦住的这三条一条都没出门")
	backend.sent_requests.clear()
	_check(backend.request_copy_history(), "副本历史请求应可发送")
	_check(backend.request_copy_open(3), "副本进入请求应可发送")
	_check(backend.request_copy_confirm(true), "副本确认请求应可发送")
	_check(backend.request_copy_reward(3), "副本领奖请求应可发送")
	_check(backend.request_copy_finish_escort(), "护送完成请求应可发送")
	var copy_contents: Array[String] = []
	for request in backend.sent_requests:
		_check(int(request.opcode) == 819, "副本请求必须使用 COPY_ACTION opcode 819")
		copy_contents.append(String(request.content))
	_check(copy_contents == ["0", "1:3", "2:true", "3:3", "4"], "819 应保持 CopyProcessor 原版动作与字段顺序")
	backend.sent_requests.clear()
	_check(backend.request_hang_start() and backend.request_hang_stop(), "挂机开停请求应可发送")
	_check([int(backend.sent_requests[0].opcode), int(backend.sent_requests[1].opcode)] == [1808, 1808],
			"挂机请求必须使用 HANG_ACTION opcode 1808")
	## ⚠ 原来这里还有一条 `request_hang_state()` 发 `"2"`，并且把 `"0","1","2"` 三档一起钉成"原版"——
	## 那第三条**不是原版**：`Client.requestGuaJi` 只有 0/1，`handle_hang_action:18329` 遇到别的值
	## 整个忽略 ⇒ 永远没有回帧，而在线门 `副本挂机` 就照着这条假契约去等一个不来的信号。
	_check([String(backend.sent_requests[0].content), String(backend.sent_requests[1].content)] == ["0", "1"],
			"1808 只有 0/1 两档（没有第三条'查询'），实得 %s"
			% str([String(backend.sent_requests[0].content), String(backend.sent_requests[1].content)]))
	backend.sent_requests.clear()
	_check(backend.request_cash_money(), "点券查询请求应可发送")
	_check(backend.request_cash_shop_category(2, 0, 29), "商城分类请求应可发送")
	_check(backend.request_cash_shop_search("拉面", 1, 30, 59, 10, 100), "商城搜索请求应可发送")
	_check(backend.request_cash_shop_buy(3000001, 2), "商城购买请求应可发送")
	_check(backend.request_cash_shop_capacity(), "背包扩充请求应可发送（1084 是**扩充动作**、不是容量查询）")
	_check(backend.request_cash_item_info(3000001), "商城详情请求应可发送")
	var cash_opcodes: Array[int] = []
	var cash_contents: Array[String] = []
	for request in backend.sent_requests:
		cash_opcodes.append(int(request.opcode))
		cash_contents.append(String(request.content))
	_check(cash_opcodes == [431, 432, 1075, 1081, 1084, 1086], "商城请求必须使用原版 431/432/1075/1081/1084/1086 opcode")
	# 详情请求只发一个字段：服务端 handle_cash_item_info 取 fields[0] 当物品 id。
	_check(cash_contents == ["0", "0:2:0:29", "1:拉面:10:100:30:59", "0:3000001:2", "1", "3000001"], "商城请求应保持原版字段顺序")
	# 1081 的**首字段是钱包选择器**（2026-10-17 巡检 #17）：0 元宝 / 1 点券。
	# 出处三处互证：`BuyEqpWindow.as:353` `shopType = ybCheckBox.selected ? 0 : 1`、
	# `UI.as:1453` `requestShopping(shopType, sn, quantity)`（`AllInOneProcessor.as:2789` 三个 writeInt）、
	# 自动买那段 `WaiGuaHandler.as:229/233`。原来购买窗勾了「点券」也恒发 0 ⇒ 服务端按元宝扣。
	backend.sent_requests.clear()
	backend.request_cash_shop_buy(3000001, 2, 1)
	_check(String(backend.sent_requests[0].content) == "1:3000001:2",
			"点券购买的报文首字段该是 1，实测 %s" % backend.sent_requests[0].content)
	backend.request_cash_shop_buy(3000001, 2)
	_check(String(backend.sent_requests[1].content) == "0:3000001:2",
			"默认（元宝）购买的报文首字段该是 0，实测 %s" % backend.sent_requests[1].content)
	# ⚠️ 这里**只钉得到后端**：本门用的是 `测试/测试后端连接.gd` 那份替身，
	#    而 `游戏会话._online_backend()` 按 `/root/BackendConnection` + `in_game` 找真人单例 ⇒ 恒 null。
	#    会话那层的转发（`buy_shop_item` 第三参）由**在线门** `商城真实事务回归测试` 钉。
	backend.sent_requests.clear()
	_check(backend.request_guild_summary(), "家族摘要请求应可发送")
	_check(backend.request_guild_create("木叶之火"), "创建家族请求应可发送")
	_check(backend.request_guild_list(2, 10), "家族列表请求应可发送")
	_check(backend.request_guild_members(7), "家族成员请求应可发送")
	_check(backend.request_guild_leave(), "离开家族请求应可发送")
	_check(backend.request_guild_upgrade_flag(), "家徽升级请求应可发送")
	_check(backend.request_guild_boss_state() and backend.request_guild_boss_enter() and backend.request_guild_boss_claim(), "尾兽状态、进入和领奖请求应可发送")
	var guild_contents: Array[String] = []
	for request in backend.sent_requests:
		_check(int(request.opcode) == 1552, "家族请求必须使用 BANGHUI opcode 1552")
		guild_contents.append(String(request.content))
	# 家族列表参数顺序按服务端 action 101 的取用：fields[1]=每页条数、fields[2]=页码。
	_check(guild_contents == ["102:0", "1:0:木叶之火:木叶之火:团结协作，共同守护木叶。:0", "101:10:2", "104:7", "6", "10", "201", "203", "204"], "1552 应保持家族与尾兽动作字段顺序")
	backend.sent_requests.clear()
	_check(backend.request_friend_list() and backend.request_friend_add(2001) and backend.request_friend_accept(2001), "好友查询、申请和接受请求应可发送")
	_check(backend.request_friend_delete(2001) and backend.request_friend_block(2001) and backend.request_friend_unblock(2002), "好友删除、拉黑和解除请求应可发送")
	var friend_contents: Array[String] = []
	for request in backend.sent_requests:
		_check(int(request.opcode) == 127, "好友请求必须使用 FRIENDLIST opcode 127")
		friend_contents.append(String(request.content))
	# 加好友与拉黑都发**角色编号**（服务端 _handle_multiplayer_friend 取 _safe_int(fields[1])，
	# 原版 AS3 的 requestAddFriend(int) 同为编号）——传名字会被解析成 0 而被忽略。
	_check(friend_contents == ["0", "1:2001", "2:2001", "3:2001", "4:2001", "6:2002"], "127 应保持好友动作与目标字段顺序")
	backend.sent_requests.clear()
	_check(backend.request_party_state() and backend.request_party_create("木叶小队") and backend.request_party_invite("成员乙"), "队伍查询、创建和邀请请求应可发送")
	_check(backend.request_party_accept(77) and backend.request_party_change_leader(3002) and backend.request_party_leave(), "队伍接受、换队长和离开请求应可发送")
	_check(backend.request_party_disband() and backend.request_nearby_parties(), "队伍解散和附近队伍请求应可发送")
	var party_contents: Array[String] = []
	for request in backend.sent_requests:
		_check(int(request.opcode) == 120, "组队请求必须使用 PARTY opcode 120")
		party_contents.append(String(request.content))
	_check(party_contents == ["9", "1:木叶小队", "4:成员乙", "3:77", "6:3002", "2", "7", "10"], "120 应保持原版组队动作与目标字段顺序")
	backend.sent_requests.clear()
	_check(backend.request_gift_state() and backend.request_gift_claim("daily") and backend.request_gift_code("NARUTO2026"), "礼包查询、领取和兑换码请求应可发送")
	_check(backend.request_exchange_list() and backend.request_exchange(2), "兑换列表和执行请求应可发送")
	# 福袋只有开 / 开始 / 领三支（`FudaiProcessor:216-222 / 146-151 / 123-128`）。
	# 旧版多出的 `request_fudai_state()` 发 action 0 —— 原版没有这支，服务端 `handle_fudai`
	# 走到非 1/2/3 直接 return ⇒ 查询永无回帧；`request_fudai_select(2)` 那 `"1:2"` 也是把
	# 「背包格位」当成了「选第几件」：选哪件由服务端 `randrange(len(candidates))` 抽。§3.261
	_check(backend.request_fudai_open(3) and backend.request_fudai_start() and backend.request_fudai_gain(), "福袋开启、开始和领取请求应可发送")
	_check(backend.request_ranking(2) and backend.request_achievements(1) and backend.request_claim_achievement(1, 2), "排行和成就请求应可发送")
	_check(backend.request_activity_state() and backend.request_activity_claim(), "活跃度查询和领取应可发送")
	var reward_opcodes: Array[int] = []
	var reward_contents: Array[String] = []
	for request in backend.sent_requests:
		reward_opcodes.append(int(request.opcode))
		reward_contents.append(String(request.content))
	_check(reward_opcodes == [1344, 1344, 1344, 1344, 1344, 1344, 1344, 1820, 1820, 1286, 1286, 1286, 1346, 1345, 1345, 2326, 2326], "奖励系统请求必须使用原版 opcode")
	# `request_gift_state()` 发的是原版那五个查询 action（首次登录 2 / 周登录 12 / 线上 31 /
	# 每日签到 43 / 等级 21），不是自造的 `90`；领每日签到是 42（`requestGainEverydayGift`）。
	# 排行榜是**三段**：`byte 0` + `int tabId` + `byte 忍界位`（`Client.sendRequestPaiHangSearch`）⇒
	# `request_ranking(2)` 缺省忍界榜 = `0:2:1`。旧版这里钉的是 `2329` + `"0:2"`（跨服充值榜的号、
	# 少一段 bool），服务端把它当畸形帧直接丢 ⇒ 排行榜永远拿不到回帧。
	_check(reward_contents == ["2", "12", "31", "43", "21", "42", "41:NARUTO2026", "0", "2:2", "1:3", "2", "3", "0:2:1", "0:1:0:19:0", "4:1:2", "0", "1"], "奖励系统请求应保持原版 action 和字段顺序")
	backend.sent_requests.clear()
	# 忍界位 = `!renJieBtn.enabled`（`RankWindow2.changeTab:203-214`）⇒ 同级榜(p=1) 发 0。
	# 榜单号是 `Etc.PaiHangBang` 的 menuId（0..22），**不是**页签序号。
	_check(backend.request_ranking(0, false) and backend.request_ranking(22), "同级榜与末位榜请求应可发送")
	var 排行上行: Array[String] = []
	for request in backend.sent_requests:
		_check(int(request.opcode) == 1346, "排行榜请求必须用 PAI_HANG opcode 1346，不是跨服充值榜的 2329")
		排行上行.append(String(request.content))
	_check(排行上行 == ["0:0:0", "0:22:1"], "1346 应保持 `action:menuId:忍界位` 三段与顺序")
	backend.sent_requests.clear()
	_跑完的.append("_validate_outgoing_requests")

func _validate_no_local_online_rewards() -> void:
	var source := FileAccess.get_file_as_string("res://脚本/单例/游戏会话.gd")
	_check("grant_combat_reward" not in source, "在线战斗不得保留本地 grant_combat_reward 发奖")
	_跑完的.append("_validate_no_local_online_rewards")

func _packet_builder_samples() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAPTURE_PATH))
	if not parsed is Array:
		_check(false, "原版协议抓包样本应为数组")
		return []
	for entry in parsed:
		if entry is Dictionary and String(entry.get("step", "")) == "server_packet_builder_samples":
			return entry.get("received", []) as Array
	_check(false, "原版协议抓包中缺少 PacketBuilder 样本")
	return []

func _count_signal(_arg1 = null, _arg2 = null, _arg3 = null, _arg4 = null, _arg5 = null, _arg6 = null,
		_arg7 = null, _arg8 = null) -> void:
	# 信号名是 `.bind(signal_name)` 追加在**最后**的那个 String；信号实参可能也含 String
	# （如 item_effect_received(kind:String, …)），所以不能写死取第几个，**从右往左找第一个 String**。
	# 之前写死 `_arg4 if … else _arg3 …` 在 4 实参信号（monster_damaged 加了"受击动画"位）下
	# 会把 bool 实参当名字、或名字落到 _arg5 取不到 → 计数错乱。
	# ⚠ 形参个数必须 **≥ 全工程最宽的那条信号的实参数**（Godot 会在 emit 时报
	#   `Method expected N argument(s), but called with M` 而**静默丢计数**）：
	#   2026-10-11 `monster_damaged` 扩到 6 参（+bind=7）就打过 6 个形参的上限，
	#   表现是"243 应分派服务端怪物伤害"这类毫不相关的断言变红。留 8 格余量。
	var 所有 := [_arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7, _arg8]
	var signal_name := ""
	for i in range(所有.size() - 1, -1, -1):
		if 所有[i] is String:
			signal_name = String(所有[i])
			break
	if signal_name.is_empty():
		return
	_signals[signal_name] = int(_signals.get(signal_name, 0)) + 1

func _capture_item_change_result(_opcode: int, result: Dictionary) -> void:
	_item_change_results.append(result.duplicate(true))

func _capture_item_effect(kind: String, state: Dictionary) -> void:
	_item_effect_results.append({"kind": kind, "state": state.duplicate(true)})

func _capture_shop(shop: Dictionary) -> void:
	_shop_snapshots.append(shop.duplicate(true))

func _capture_shop_code(code: int) -> void:
	_shop_codes.append(code)

func _capture_storage(items: Array, gold: int, capacity: int) -> void:
	_storage_snapshots.append({"items": items.duplicate(true), "gold": gold, "capacity": capacity})

func _capture_pets(pets: Array, capacity: int) -> void:
	_pet_snapshots.append({"pets": pets.duplicate(true), "capacity": capacity})

func _capture_pet_action(action: int, result: Dictionary) -> void:
	_pet_actions.append({"action": action, "result": result.duplicate(true)})

func _capture_cash_shop(items: Array, total: int, source: String) -> void:
	_cash_shop_snapshots.append({"items": items.duplicate(true), "total": total, "source": source})

func _capture_skill_hit(object_id: int, skill_id: int, damage: int) -> void:
	_skill_hits.append({"object_id": object_id, "skill_id": skill_id, "damage": damage})

func _append_test_s32_be(data: PackedByteArray, value: int) -> void:
	for shift in [24, 16, 8, 0]:
		data.append((value >> shift) & 0xff)

var _判定数 := 0

func _check(condition: bool, message: String) -> void:
	_判定数 += 1
	if not condition:
		_failures.append(message)

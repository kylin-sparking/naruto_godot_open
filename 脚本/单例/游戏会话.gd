extends Node

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const OFFLINE_DATA := preload("res://脚本/单例/离线示例数据.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 服务端同步 := preload("res://脚本/单例/服务端会话同步.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
const 快捷键 := preload("res://脚本/单例/快捷键.gd")
const 等级经验表 := preload("res://脚本/单例/等级经验表.gd")
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")

signal player_stats_changed(stats: Dictionary)
signal quest_changed(quest: Dictionary)
signal skill_cooldown_changed(slot: int, remaining: float, duration: float)
signal notification_requested(message: String)
signal map_changed(map_id: String)
signal inventory_changed(items: Array)
signal storage_changed(items: Array)
signal npc_shop_changed(shop: Dictionary)
signal equipment_changed(equipment: Dictionary)
signal skills_changed(skills: Array)
signal quests_changed(accepted: Array, available: Array)
signal pets_changed(pets: Array)
## 首领（尾兽）刷新列表：在线时由 `后端连接.wang_list_received` 灌进来
## （每项 {index, mobId, mapId, alive, nextTime, …}）；离线恒空 ⇒ `首领窗口.gd` 全走静态表原态。
signal wang_list_changed(rows: Array)
## Boss 房门确认（`1349`）转发：服务端先不发 129，等这边回「进/不进」。
## 谁听谁弹框 —— 本工程归 `窗口管理`（服务端推帧开 UI 的那一族都在那儿）。
signal portal_panel_requested(request_id: int, message: String)
## 秘笈合成结果回帧（`1352:0:<0/1>` 转发）。原版只在 true 时刷新页面
## （`JiNengCompositeWindow.operationResultHandler:342-347`），失败不弹话。
signal can_juan_result(success: bool)
## 意志（Spirit）状态变了（任何 1823 回帧都发这一条；页面重渲染听它）。
signal spirit_state_changed
## 阅历变了（服务端 `1572:0:<progress>:<points>`）。**单独一条，不走 `spirit_state_changed`**：
## 原版 `YiZhiStudyWindow.updateYueLiAndYuanBao:221-225` 是就地改两个货币 Label，
## 不重建窗口。我们若走 `spirit_state_changed` ⇒ 学习页重建 ⇒ 重建又发一次
## `请求阅历状态()` ⇒ 服务端再回 1572 ⇒ **无限请求环 + 页面狂闪**（2026-10-19 设计时排掉）。
signal 阅历_变化(点数: int)
## 精英副本进入列表变了（1828/0 回帧驱动；`精英副本窗口.gd` 听它刷「x/y 次」与页签）。
signal hero_state_changed
signal social_changed()
## 头像面板那颗队长标该不该亮。原版是 `RelationShipHandler` 在**建队 :120 / 换队长 :56,60 /
## 离队·解散·被踢（`removeTroopHPPane:286`）**四处直接调 `charactorInfoPane.setTroopCaptainIcon()`；
## 这边的状态记在 `队伍窗.队长标应显`（队伍窗没开过也要记账），由队伍窗广播给常驻的 HUD。
signal 队长标_changed(应显: bool)
## 好友私聊又多了一条（`好友私聊记录` 落库之后发，参数 = 对端角色号）。
## 消费者：`好友私聊窗.gd`（开着且对端一致就重铺）。
signal 好友私聊追加(对端: int)
signal settings_changed(settings: Dictionary)
signal feature_requested(feature_name: String)
signal map_character_selected(info: Dictionary)
signal map_character_selection_cleared()
signal player_defeated()
signal cultivation_changed(kind: String, state: Dictionary)
signal item_effect_changed(kind: String, state: Dictionary)
signal copy_changed(state: Dictionary)
signal 活动倒计时_changed(rows: Array)
signal hang_changed(state: Dictionary)
## 1283 的角色配置回帧（服务端权威）。挂机设置页开着时靠它把 25 枚勾/6 个下拉/3 个输入刷成表上的值。
signal 挂机配置_changed(配置: Dictionary)
signal hud_state_changed(state: Dictionary)

const DEFAULT_MAP_ID := "101010000"
const MAP_SCENE_PATH := "res://场景/地图/地图场景.tscn"
const LEGACY_BACKEND_PORT := 28523
const PACKAGED_BACKEND_PORT := 18684
const LEGACY_BACKEND_URL := "http://127.0.0.1:8081/play.htm"
const LEGACY_BACKEND_ROOT_URL := "http://127.0.0.1:8081"
const PACKAGED_BACKEND_URL := "http://127.0.0.1:18680/ruffle.html"
const LEGACY_BACKEND_ACCOUNT := "naruto"
const PACKAGED_BACKEND_ACCOUNT := "a33047518511@gmail.com"
const PACKAGED_BACKEND_PASSWORD := "123456"

var current_map_id := DEFAULT_MAP_ID
## —— 跨图自动赶路的路线状态（2026-10-10 从 HUD 搬上来）——
## 为什么必须放这儿：`小地图面板` 是**长在地图场景里**的（`场景/地图/地图场景.tscn:48`），
## 而换图走的是整份场景释放 ⇒ HUD 连同它身上的路线一起被销毁，于是"到了第二张人就站住"。
## 原版这两件事本来就分开：路线挂在**活得比地图久**的角色/控制器上
## （`Character.setWalkPathFindParam` → `KeyController._aryMapJoint`，`KeyController.as:1112-1132`），
## UI 只是发起方。⇒ 状态在这里，HUD 每一张图重新接手跑。
## ⚠ 不存"哪一个玩家实例"：换图会重建玩家，把已释放的节点引用留在单例里就是悬垂引用；
##   新 HUD 接手时按"换了人"重新对取消计数即可（`小地图面板._process` 那一段）。
var 跨图在途 := false
var 跨图余程: Array = []			# 还没走的那几跳（`脚本/地图/跨图寻路.gd` 的路线）
var 跨图终点图 := 0
var 跨图终目标: Dictionary = {}		# 到了要做的事 {"类":"n"/"m","号":int,"说明":String}
var 跨图等到 := 0.0				# 到终点图等 NPC 刷出来的累计秒数（上限 15 秒）」
var pending_portal_name := ""
## 服务端换图时给的落点（WARP 帧里的 x/y）。非空时优先于 pending_portal_name，
## 因为在线模式下服务端才是换图的权威。
var pending_server_spawn: Variant = null
var backend_authoritative := false
var player_stats := {}
var active_quest := {}
var accepted_quests: Array[Dictionary] = []
var available_quests: Array[Dictionary] = []
var completed_quest_ids: Array[String] = []
var daily_quest_day := -1
var quest_chain := {}
var inventory: Array[Dictionary] = []
var storage: Array[Dictionary] = []
## 已装备物品：**键 = 装备位置(int)**，见 `脚本/单例/装备部位.gd`。
## 2026-09-21 起从"中文名当键"改成"位置当键"——原版协议里位置就是个 int
## （`UpdateEquipSlotInfo.position = readInt()`），中文名只是画 UI 时查一次的显示层。
## 原来那个 6 槽默认值里还有个不存在的名字「鞋子」（别处都叫「忍鞋」），已一并消失。
var equipped_items := {}
var learned_skills: Array[Dictionary] = []
## 临时忍术层数（勾玉/玉链的「忍术 +N 层」）。原版 `DataCenter.addedSkillLevelList`，
## 由 `SKILL_CHANGE_TMP(1813)` **整表替换**（`后端连接._decode_skill_change_tmp`）。
## 键 = 七位补零的技能号。**只影响显示**：伤害由服务端 `_effective_skill_level`
## 自己把勾玉/八门/灵气加成加上去（`fake_flash_server.py:49616`），客户端别重复加。
var skill_added_levels: Dictionary = {}
## 原版 `Job0.isWorldSkill`（`Job0.as:338-368`）那 18 条世界忍术：吃 `add_world_skill_level`。
const 世界忍术 := [3000, 3001, 3002, 3003, 3006, 3007, 2000, 2001, 2004, 2003, 2002,
	3004, 2010, 2011, 2014, 2013, 2012, 3005]
## 原版 `Job0.isJobSkill`（`Job0.as:293-299`）：六个被动 + 四职业各三条普攻 + 六条概率技。
const 职业忍术 := [1000, 1001, 1002, 1003, 1004, 1005,
	1001001, 1001002, 1001003, 2001001, 2001002, 2001003,
	3001001, 3001002, 3001003, 4001001, 4001002, 4001003,
	1002001, 1002002, 1002003, 1003001, 1003002, 1003003]
## 原版 `Job0.isCoupleSkill`（`Job0.as:371-374`）：夫妻技**不吃任何等级加成**。
const 情侣忍术 := [3301, 3302, 3303, 3304, 3305, 3306]
var skill_book_catalog: Array[Dictionary] = []
var pets: Array[Dictionary] = []
## 首领刷新列表（在线态）。离线恒空数组 ⇒ 首领页所有行按原态 `alive=true` 画（合并包的合法默认）。
var wang_list: Array = []
## ── 意志（Spirit，2026-10-03 接 `SPIRIT_ACTION 1823`）：全部**回帧驱动**，客户端零本地判断 ──
## 背包（slot>0）/穿戴（slot<0）行 = {id,color,slot,exp,level}（夹具 `_encode_spirit_inventory_item`
## 的 `id&color&slot&exp&level` 五列）；panel = 学习窗候选（cmd1 的 id 列表）。
var spirit_bag: Array = []
var spirit_equipped: Array = []
var spirit_panel: Array = []
var spirit_pack_limit: int = 5			# cmd6 第 1 参（初值 = 夹具 spirit_pack_limit=5）
var spirit_equip_limit: int = 1			# cmd6 第 2 参（初值 = 原版 `equipLimit=1` 只开第 1 格）
var spirit_npc_status: Array = []		# cmd0：5 位导师状态（0/1）
var spirit_special_count: int = 0		# cmd0：今日已召唤次数
var spirit_special_enabled: bool = true	# cmd0：还能不能召唤（次数未用完）
## cmd8 刚拾取清单：`[{id, pos}]`（服务端 `_pick_spirit_panel_items:22608-22665` 的
## `<itemid&pos>@...`）。**只给飞入动画用**（`playPickYiZhiEffect:115-146` 的起点），
## 面板/背包数据由紧跟其后的 cmd1/cmd2 帧负责 ⇒ 播放方用完要清空。
var spirit_picked: Array = []
## 阅历（意志学习货币）：服务端 `PVE_ACTION 1572` 的 `1572:0:<progress>:<points>`
## （`_send_pve_status:30856`）。points 就是 AS3 `YiZhiManager:95-103` 里花在
## 学习/合成上的那个 `pve_points`；progress 是百炼副本进度（百炼页用，这里只存不画）。
## ⚠️ 2026-10-19 之前这条线是断的：客户端没有 1572 处理器，UI 读的是
##    `player_stats.spirit_experience`——全工程只此两处读、没有任何地方写，
##    于是「阅历数值」恒 0、`_导师点击` 的「阅历不足」恒真、学习整个瘫痪。
var 阅历 := 0
var 阅历进度 := 0
## ── 精英副本（HERO_ACTION 1828，2026-10-04 接通）：回帧驱动，客户端零本地判断 ──
var hero_max_enter: int = 3				# 1828/0 第 2 段（夹具硬编码 3=每日上限）
var hero_entries: Dictionary = {}		# copyId(int) → 今日已进次数(int)
var hero_state_loaded: bool = false		# 收到过首帧 ⇒ 开窗捷径放页；没收到不硬开
var pet_capacity := 10
var team_members: Array[Dictionary] = []
var friends: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var recent_contacts: Array[Dictionary] = []
var blocked_players: Array[String] = []
## 黑名单的**行数据**（好友页「黑名单」页签要的是行字典，不是名字）。
## `blocked_players` 只有名字、且别处按名字判重（`clean in blocked_players`），不能改形状，
## 所以另存一份 —— 服务端那份本来就是行字典（`后端连接.authoritative_blocked`）。
var blocked_contacts: Array[Dictionary] = []
## 好友私聊记录（原版 `FriendChatManage._msgData`）：目标角色号(str) → 条目数组，
## 条目 = `{自己: bool, 名: String, 文: String, 时: int}`。
## 关窗不清（原版关窗只清显示，数据留在管理器里，再开 `update()` 重铺）；
## 一条都没有时关窗才清（`FriendChatWindow.onCloseBtnClick:249-258`）。
var 好友私聊记录: Dictionary = {}
## `ChatUtil.DEFAULT_SHOW_CHAT_COUNT` / `FriendChatWindow.addMsg:203-206` 的裁剪量
## （`30 * 0.1 = 3`，少于 1 按 1）。
const 私聊条数上限 := 30
const 私聊裁剪条数 := 3
var pending_social_requests: Array[Dictionary] = []
var selected_stall_owner := ""
var current_channel := 1
var guild := {}
var shop_catalog: Array[Dictionary] = []
var cash_shop_total := 0
var cash_shop_capacity := 0
var server_cash_shop_loaded := false
var cash_shop_loading := false
## `CashShopFactory.as:7-8`：SHOP_TYPE_CASH=0（元宝货架）、SHOP_TYPE_BAND=1（礼金货架）。
const 商城货架_元宝 := 0
const 商城货架_礼金 := 1
var npc_shop_items: Array[Dictionary] = []
## 服务端下发的商店分组 `[{name, items}]`。
## ⚠️ 原版的分页**就是**这个数组（`ShopWindow2.as:354` `for each(_loc3_ in this.data.groups)`，
## 名字直接当页签文字用），所以它不能再从 `items` 里按 `category` 反推 ——
## 以前 `apply_backend_npc_shop` 只存 `items`、把 `tabs` 丢了，渲染端只好硬编码三个页签。
var npc_shop_tabs: Array[Dictionary] = []
var selected_npc_id := ""
var game_settings := {}
var last_retreat_claim_unix := 0
var storage_gold := 0
var storage_capacity := 30
var server_npc_shop_loaded := false
## 服务端的已学忍术是否已经接管 `learned_skills`。
## ⚠️ 离线示例数据里**编**了两个技能（1001001 / 0002000）撑技能面板；在线时它们是假的 ——
## 不清掉的话 `_rebuild_skill_slots()` 会优先保留"表里还有的老槽位"，于是一放技能就发一个
## **这个角色根本没学过**的 id 出去，服务端回"这个技能还没有学习"，怪一点事没有
## （用户 2026-09-27 实机报的"按攻击技能不能对附近的怪物释放"就是这个）。
var server_skills_loaded := false
var cultivation_states := {}
## 系统消息：左侧那列活动倒计时，每项 {text, seconds, 基准毫秒}
var 活动倒计时: Array = []
var item_effect_states := {}
var copy_history := {}
var copy_total_count := 1
var copy_state := {"action": 0, "pending_copy_id": -1, "active_copy_id": -1, "completed_copy_id": -1, "rewards": []}
var hang_state := {"active": false, "started_at": 0, "map_id": 0, "elapsed_seconds": 0}
## 1283 的角色配置表（键 = 原版 `GuaJiSettingInfoData` 的字段名，含 `auot*` 那两处错拼）。
## 服务端才是这份的权威（`fake_flash_server.py:2594 default_character_config`），
## 客户端只缓存 + 把它翻译成下面 `game_settings` 里那几个本地键给自动战斗循环用。
var 挂机配置: Dictionary = {}
var hud_state := {"vip_level": 0, "pk_mode": 1, "weather_type": -1, "buffs": [], "effects": []}
var _hang_stop_requested := false

func _init() -> void:
	var defaults := OFFLINE_DATA.create()
	player_stats = defaults.player_stats.duplicate(true)
	active_quest = defaults.active_quest.duplicate(true)
	available_quests.assign(defaults.available_quests)
	quest_chain = defaults.quest_chain.duplicate(true)
	inventory.assign(defaults.inventory)
	learned_skills.assign(defaults.learned_skills)
	skill_book_catalog.assign(defaults.skill_book_catalog)
	pets.assign(defaults.pets)
	friends.assign(defaults.friends)
	guild = defaults.guild.duplicate(true)
	shop_catalog.assign(defaults.shop_catalog)
	npc_shop_items.assign(defaults.npc_shop_items)
	game_settings = defaults.game_settings.duplicate(true)

func _ready() -> void:
	accepted_quests = [active_quest]
	_load_local_state()
	# 快捷键必须在**进图之前**就绪：注册原先挂在 `功能窗口._ready()` 上，而窗口是懒建的，
	# 开局没开窗口之前 `jump` 这个 action 根本不存在（`玩家.gd` 每物理帧调它 → 每帧报错、
	# 跳跃失效），WASD 也只有 Godot 内建的方向键能用；玩家改过的键位同样要等开一次窗口才生效。
	# 真值表与注册逻辑见 `脚本/单例/快捷键.gd`。必须在 `_load_local_state()` 之后
	# （键位存在 `game_settings["keybind_*"]` 里，靠它读盘）。
	快捷键.确保默认()
	快捷键.应用已存(game_settings)
	_migrate_quest_state()
	_migrate_pet_state()
	_reset_daily_quests_if_needed()
	_rebuild_skill_slots()
	_recalculate_stats(false)
	# 罪状格跟着罪恶值走（原版 `PVPHandler.checkAddCrimeBuff` 在罪恶值变化时调用）。
	# 只在值真的变了才重算增益栏，避免每次血量跳动都扫一遍 buff 列表。
	_罪状值 = int(player_stats.get("crime", 0))
	player_stats_changed.connect(_on_player_stats_for_buffs)
	var backend := get_node_or_null("/root/BackendConnection")
	if backend != null:
		backend.cultivation_received.connect(_on_backend_cultivation)
		backend.copy_state_received.connect(_on_backend_copy_state)
		backend.hang_state_received.connect(_on_backend_hang_state)
		backend.char_config_received.connect(_on_backend_char_config)
		backend.guild_state_received.connect(_on_backend_guild_state)
		backend.friend_state_received.connect(_on_backend_friend_state)
		## 好友私聊要**关着窗也记账**（原版 `FriendChatManage` 是常驻单例）⇒ 挂在会话上，
		## 不挂在某一扇窗里；窗只负责显示。
		if backend.has_signal("chat_received"):
			backend.chat_received.connect(_on_backend_chat_for_log)
		backend.party_state_received.connect(_on_backend_party_state)
		backend.vip_state_received.connect(_on_backend_vip_state)
		backend.pk_mode_received.connect(_on_backend_pk_mode)
		backend.weather_received.connect(_on_backend_weather)
		backend.buffs_received.connect(_on_backend_buffs)
		if backend.has_signal("system_buff_received"):
			backend.system_buff_received.connect(_on_backend_system_buff)
		# 连斩/打坐的 buff 格（原版 HUD 有，本机服务端用各自业务帧驱动）。
		if backend.has_signal("lianzhan_stage_changed"):
			backend.lianzhan_stage_changed.connect(_on_backend_lianzhan_stage)
		if backend.has_signal("heal_state_received"):
			backend.heal_state_received.connect(_on_backend_heal_state)
		# 族徽加成要看"本图有没有本族的旗" ⇒ 旗数据变了就得重算增益栏。
		# ⚠️ **不要 `.unbind(1)`**：`_on_flag_for_emblem` 本来吃信号那一个参数，
		#    再 unbind 就成 0 参 ⇒ `Method expected 1 argument(s), but called with 0.`
		#    （连接成功、一触发就报错，功能静默失效 —— 本工程踩过两次）。
		if backend.has_signal("map_flag_changed"):
			backend.map_flag_changed.connect(_on_flag_for_emblem)
		if backend.has_signal("flag_list_received"):
			backend.flag_list_received.connect(_on_flag_for_emblem)
		backend.biguan_info_received.connect(_on_backend_biguan_info)
		backend.huodong_countdowns_received.connect(_on_backend_huodong_countdowns)
		backend.wang_list_received.connect(_on_backend_wang_list)
		backend.portal_panel_received.connect(func(id: int, msg: String): portal_panel_requested.emit(id, msg))
		backend.can_juan_result_received.connect(func(s: bool): can_juan_result.emit(s))
		backend.spirit_action_received.connect(_on_backend_spirit_action)
		# 阅历（意志学习货币）随 1572 状态帧下发（`_send_pve_status:30856`）。
		# 直接拆帧即可：这帧只在服务端推状态时来，不像 `guild_state_received` 那样
		# 是"给全图广播"（那条才需要置标志+帧末判，见 `_on_flag_for_emblem` 的注释）。
		backend.pve_status_received.connect(_on_backend_pve_status)
		backend.hero_action_received.connect(_on_backend_hero_action)
		# 任务列表（`444`）。⚠️ 接上之前，这条线是**断的** —— 后端只发了一个
		# `quest_received` 信号，而全项目一个消费者都没有，所以在线时任务窗口
		# 读的一直是离线那套假任务。
		backend.quest_list_received.connect(_on_backend_quest_list)
		backend.quest_progress_received.connect(_on_backend_quest_progress)

## ⭐ **离线默认残留检测器** —— 把"离线那一套漏进在线会话"从"只能靠人眼发现"变成可断言的东西。
##
## 为什么要它：离线/在线**共用同一套状态**，只靠 `backend_authoritative` 在**零散几处**切换行为。
## 哪一处没查标志、或查的时机不对，离线默认值就会**悄悄**进在线会话，**而且不报错**。
## 到 2026-09-27 为止，同一个形状已经栽过三次，**三次都是用户实机发现的，门禁一次都没拦住**：
##   · 点券键名没对齐 → 背包点券恒 0（§3.51.1）
##   · `learned_skills` 里离线编的 2 个技能漏进在线 → 发没学过的技能 id，服务端拒收（§3.56.13）
##   · `_recalculate_stats()` 的离线公式盖掉服务端属性 → 界面 mp 80/80，服务端 5633（§3.56.14）
##
## 返回可疑项列表，**空数组 = 干净**；在线用例拿它做断言（`测试/离线残留在线回归测试.gd`）。
## 判据是"服务端**已经给过**这一项，本地却还是离线那份" —— 服务端没给过的不算漏（那时本来就没得用）。
## 值相等判定 —— **不能直接比字符串**：离线默认 `vip = 0`、服务端发的是 `false`，
## 字面不同但同义，直接比会误报（守卫第一次跑就报了这一条）。布尔先归一到 0/1，
## 数字按数值比，其余才落到字符串。
static func _同值(甲, 乙) -> bool:
	if 甲 is bool or 乙 is bool:
		return int(bool(甲)) == int(bool(乙))
	var 甲文 := str(甲)
	var 乙文 := str(乙)
	if 甲文.is_valid_float() and 乙文.is_valid_float():
		return is_equal_approx(float(甲), float(乙))
	return 甲文 == 乙文

func 离线默认残留() -> Array[String]:
	var 残留: Array[String] = []
	var 后端 := get_node_or_null("/root/BackendConnection")
	if not backend_authoritative or 后端 == null:
		return 残留
	var 默认 := OFFLINE_DATA.create()

	# ① 人物属性：服务端推过这个键，本地却还是离线默认值
	var 权威属性: Dictionary = 后端.get("authoritative_stats")
	for 键 in 权威属性:
		if not player_stats.has(键):
			continue
		var 离线值 = 默认.player_stats.get(键, null)
		if 离线值 != null and _同值(player_stats[键], 离线值) and not _同值(权威属性[键], 离线值):
			残留.append("player_stats.%s 还是离线默认值 %s（服务端是 %s）" % [键, 离线值, 权威属性[键]])

	# ② 已学忍术：本地还留着离线**编造**的 id（服务端那套里没有它）
	var 权威技能: Dictionary = 后端.get("authoritative_skills")
	var 离线技能id := {}
	for 技能 in 默认.learned_skills:
		离线技能id[str((技能 as Dictionary).get("id", ""))] = true
	for 技能 in learned_skills:
		var 编号 := str((技能 as Dictionary).get("id", ""))
		if 离线技能id.has(编号) and not 权威技能.is_empty() and not 权威技能.has(int(编号)):
			残留.append("learned_skills 里还留着离线编的技能 %s（服务端没有这条）" % 编号)

	# ③ 整张表：服务端给过，本地却还是离线那份（逐表对照，加表就往这里加一行）
	for 项 in [["inventory", "authoritative_inventory"], ["pets", "authoritative_pets"],
			["npc_shop_items", "authoritative_npc_shop"]]:
		var 本地名: String = 项[0]
		var 权威名: String = 项[1]
		var 权威 = 后端.get(权威名)
		var 本地 = get(本地名)
		if 权威 is Array and not (权威 as Array).is_empty() and 本地 is Array and 本地 == 默认.get(本地名, []):
			残留.append("%s 还是离线那一份（服务端已给 %d 条）" % [本地名, (权威 as Array).size()])
	return 残留

func get_accepted_quests() -> Array[Dictionary]:
	return accepted_quests

func get_available_quests() -> Array[Dictionary]:
	return available_quests

var skill_slots: Array[Dictionary] = []
var skill_cooldowns := {}
var _daily_reset_timer := 0.0

func _process(delta: float) -> void:
	_daily_reset_timer -= delta
	if _daily_reset_timer <= 0.0:
		_daily_reset_timer = 60.0
		_reset_daily_quests_if_needed()
	var changed_slots: Array[int] = []
	for key in skill_cooldowns.keys():
		var remaining := maxf(0.0, float(skill_cooldowns[key]) - delta)
		skill_cooldowns[key] = remaining
		changed_slots.append(int(key))
		if remaining <= 0.0:
			skill_cooldowns.erase(key)
	for slot in changed_slots:
		var duration := float(skill_slots[slot].get("cooldown", 1.0)) if slot < skill_slots.size() else 1.0
		skill_cooldown_changed.emit(slot, get_skill_cooldown(slot), duration)
	_update_hang_timeout()

func get_map_name(map_id: String = current_map_id) -> String:
	return GAME_DATA.map_name(map_id)

func get_map_npcs(map_id: String = current_map_id) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for life in MAP_RESOURCES.life_entries(map_id, "n"):
		var npc_id := String(life.get("id", ""))
		var npc := get_npc_info(npc_id)
		npc["x"] = int(life.get("x", 0))
		npc["y"] = int(life.get("y", 0))
		result.append(npc)
	return result

func get_npc_info(npc_id: String) -> Dictionary:
	var result := GAME_DATA.npc(npc_id).duplicate(true)
	if result.is_empty():
		result = {"id": npc_id, "name": npc_id, "title": "", "dialogue": ""}
	return result

func select_map_character(info: Dictionary) -> void:
	map_character_selected.emit(info)

func clear_map_character_selection() -> void:
	map_character_selection_cleared.emit()

func get_npc_service(npc_id: String) -> String:
	var title := String(get_npc_info(npc_id).get("title", ""))
	if "商人" in title or "商店" in title:
		return "商店"
	if "仓库" in title:
		return "仓库"
	if "兑换" in title:
		return "兑换"
	if "副本" in title:
		return "副本"
	return ""

func open_npc_service(npc_id: String) -> void:
	if get_npc_service(npc_id).is_empty():
		return
	selected_npc_id = npc_id
	var service := get_npc_service(npc_id)
	var backend := _online_backend()
	match service:
		"商店":
			if backend != null:
				server_npc_shop_loaded = false
				backend.request_npc_menu_action(1)
			request_feature("NPC商店")
		"仓库":
			if backend != null:
				backend.request_npc_menu_action(2)
			request_feature("NPC仓库")
		"兑换": request_feature("兑换")
		"副本":
			if backend != null:
				backend.request_copy_history()
			request_feature("副本")

func get_selected_npc_shop() -> Array[Dictionary]:
	if backend_authoritative and server_npc_shop_loaded:
		return npc_shop_items
	var title := String(get_npc_info(selected_npc_id).get("title", ""))
	var vendor := ""
	if "武器" in title: vendor = "武器"
	elif "装备" in title: vendor = "装备"
	elif "药品" in title: vendor = "药品"
	elif "饰品" in title: vendor = "饰品"
	elif "杂货" in title: vendor = "杂货"
	var result: Array[Dictionary] = []
	for product in npc_shop_items:
		if String(product.get("vendor", "")) == vendor:
			result.append(product)
	return result

func get_mob_name(mob_id: String) -> String:
	return GAME_DATA.monster_name(mob_id)

## NPC 头顶的任务标记状态，返回**原版 `NpcQuestStatus` 的整数**（视图层按它取特效，别在这儿翻成字符）。
##
## ⚠ 枚举值一律以 `data/enums/NpcQuestStatus.as:5-13` 为准：
##   `NONE=0 / QUEST_CAN_START=1 / QUEST_CAN_COMPLETE=2 / QUEST_IN_PROGRESS=3`。
##   这里曾经写过「1 进行中 / 2 可接 / 3 可交」—— 把 2 和 3 说反了，于是**可交那档画成了叹号**
##   （原版可交是**金色问号**，只有可接才是叹号）。当时只有小地图那份本地推导是对的，
##   两处现在合并成这一条，同一个口径。
##
## **在线以服务端 `513 UPDATE_NPC_QUEST_STATUS` 为准** —— 它把护送/环任务/家族这些
## 客户端倒推不出来的来源一起算了优先级（`_send_npc_quest_status`）。
## 513 存的是 object_id，所以要经 `map_npcs` 反查模板号；没收到才退回本地倒推。
## ⚠ 下面几处比 npc 键一律 `str()` 不是 `String()`（理由见 `_quest_turn_in_npc`）：
## `String(整数)` 是无效调用，会让这条链**中途死掉**，头顶与小地图的标记一起没。
func npc_quest_status(npc_id: String) -> int:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 != null and bool(后端.get("authenticated")):
		var 状态表: Dictionary = 后端.get("npc_quest_status")
		var 本图: Dictionary = 后端.get("map_npcs")
		for 号 in 状态表:
			var 状: Dictionary = (本图.get(号, {}) as Dictionary)
			if 状.is_empty() or int(状.get("npc_id", -1)) != int(npc_id):
				continue
			return int(状态表[号])
	for quest in accepted_quests:
		if bool(quest.get("completed", false)) and _quest_turn_in_npc(quest) == npc_id:
			return 2
	for quest in accepted_quests:
		if not bool(quest.get("completed", false)) and str(quest.get("target_npc", "")) == npc_id:
			return 3
	for quest in available_quests:
		if str(quest.get("giver_npc", "")) == npc_id:
			return 1
	return 0

## 状态 → `数据/特效.json` 里的特效键。`NPCQuestPopup.as:15-36` 的三档一一对应；
## 0（NONE）没有标记 —— 返回空串，调用方据此不建节点。
static func 任务标记特效(状态: int) -> String:
	match 状态:
		1: return "QuestIcon_0"      # 可接：金色叹号
		2: return "QuestIcon_2"      # 可交：金色问号
		3: return "QuestIcon_1"      # 进行中：银灰问号
	return ""

## 原版 `BasicQuestInfoData.endNpcId` → `MessageTipPane2.as:412-415` 的
## `API.ui.qusetClickText(3, this._data.endNpcId)`：交付之后自动走去**交付 NPC**。
## 查不到返回空串 —— 调用方据此什么都不做，别拿接取 NPC 或 0 号去猜。
func 任务交付NPC(编号: int) -> String:
	for 条v in accepted_quests:
		var 条: Dictionary = 条v as Dictionary
		if int(str(条.get("id", 0))) != 编号:
			continue
		return _quest_turn_in_npc(条)
	return ""


## 旧字符接口只留给 `测试/游戏逻辑回归测试.gd` 那两条断言；新代码一律走 `npc_quest_status()`。
func get_quest_marker(npc_id: String) -> String:
	match npc_quest_status(npc_id):
		1: return "!"
		2: return "?"
		3: return "?"
	return ""

func get_npc_quest_info(npc_id: String) -> Dictionary:
	for quest in accepted_quests:
		if bool(quest.get("completed", false)) and _quest_turn_in_npc(quest) == npc_id:
			var completed := quest.duplicate(true)
			completed["npc_status"] = "已完成，可领取奖励"
			return completed
	for quest in accepted_quests:
		if not bool(quest.get("completed", false)) and str(quest.get("target_npc", "")) == npc_id:
			var active := quest.duplicate(true)
			active["npc_status"] = "进度：%d / %d" % [active.get("progress", 0), active.get("required", 1)]
			return active
	for quest in available_quests:
		if str(quest.get("giver_npc", "")) == npc_id:
			var available := quest.duplicate(true)
			available["npc_status"] = "可接取"
			return available
	return {}

func complete_npc_talk(npc_id: String) -> void:
	var changed := false
	for index in accepted_quests.size():
		var quest: Dictionary = accepted_quests[index]
		if str(quest.get("target_npc", "")) != npc_id or bool(quest.get("completed", false)):
			continue
		quest["progress"] = int(quest.get("required", 1))
		quest["completed"] = true
		quest["description"] = "返回任务面板领取奖励"
		accepted_quests[index] = quest
		changed = true
		notification_requested.emit("任务目标完成：%s" % quest.get("name", "任务"))
	if changed:
		_sync_active_quest()
		quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
		_save_local_state()

func damage_player(amount: int) -> void:
	player_stats["hp"] = maxi(0, int(player_stats.get("hp", 0)) - maxi(0, amount))
	player_stats_changed.emit(player_stats.duplicate(true))
	if int(player_stats.hp) <= 0:
		notification_requested.emit("你已被击败，返回当前地图出生点")
		player_defeated.emit()
		player_stats["hp"] = int(player_stats.get("max_hp", 100))
		player_stats["mp"] = int(player_stats.get("max_mp", 80))
		player_stats_changed.emit(player_stats.duplicate(true))

func heal_player(amount: int) -> void:
	player_stats["hp"] = mini(int(player_stats.get("max_hp", 100)), int(player_stats.get("hp", 0)) + maxi(0, amount))
	player_stats_changed.emit(player_stats.duplicate(true))

func use_skill(slot: int) -> bool:
	if slot < 0 or slot >= skill_slots.size() or get_skill_cooldown(slot) > 0.0:
		return false
	var skill := get_skill_in_slot(slot)
	if skill.is_empty() or not GAME_DATA.skill_is_active(skill.get("id", "")):
		return false
	# 原版 `AbstractSkill.isMpEnough():143-158` **两样都查**：查克拉 + 查克拉精华，
	# 缺哪个报哪个（`FIGHT_WARNING_SHORT_OF_MP` / `_OF_ZQ`）。
	# 我们原来只查 mp、而且查的是 `数据/技能.json` 里那个不分级的 `mp_cost`，
	# **完全不知道有"查克拉精华"这回事** → 放得出去、服务端拒收、玩家看不到原因。
	var 消耗 := GAME_DATA.skill_cost(skill.get("id", ""), int(skill.get("level", 1)))
	if int(player_stats.get("mp", 0)) < int(消耗.get("mp", 0)):
		notification_requested.emit("查克拉不足，不能使用这个忍术")
		return false
	if int(player_stats.get("zq", 0)) < int(消耗.get("zq", 0)):
		notification_requested.emit("查克拉精华不足，不能使用这个忍术")
		return false
	var mp_cost := int(消耗.get("mp", 0))
	if not backend_authoritative:
		player_stats["mp"] = int(player_stats.mp) - mp_cost
		player_stats_changed.emit(player_stats.duplicate(true))
	var duration := float(skill.get("cooldown", 1.0))
	skill_cooldowns[slot] = duration
	skill_cooldown_changed.emit(slot, duration, duration)
	return true

## 原版 `TargetHandler.defaultSkill`（`TargetHandler.as:128-147`）= **当前选中的忍术**。
## 放过一次之后，点怪就默认用它：`SkillExecute.moveToAttack():59+` 每一拍读
## `defaultSkill` + `curTarget` + `toAttackAnemy` 决定"走过去放它"。
## 原版存的也是**技能编号**（不是槽位），换格子之后选中态跟着编号走。
var 默认忍术 := 0


## 选中态变了 ⇒ 底栏那圈的流光要跟着搬家。原版不需要这个信号（它是"建格子时判一次"），
## 本工程选中态会在运行时被三处改（点快捷格、按技能键、TAB 切目标），所以给一条信号让 HUD 订阅。
signal 默认忍术_changed(编号: int)


## 选中哪一枚 = 记住它的编号。原版还会同步底栏高亮、挂机窗，并 `CharacterConfig.synch()` 落盘；
## 落盘这一半本轮没做（见 `真值/窗口/技能.md` 的欠项），所以这里只改内存。
func 设默认忍术(编号: int) -> void:
	if 默认忍术 == 编号:
		return
	默认忍术 = 编号
	默认忍术_changed.emit(编号)


## 默认忍术现在在哪个快捷键槽（不在栏里就 -1，表示"这一枚没绑键"）。
func 默认忍术槽() -> int:
	if 默认忍术 <= 0:
		return -1
	for slot in skill_slots.size():
		if int(String(skill_slots[slot].get("id", ""))) == 默认忍术:
			return slot
	return -1


func get_skill_in_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= skill_slots.size():
		return {}
	var skill_id := String(skill_slots[slot].get("id", ""))
	var index := _skill_index(skill_id)
	return learned_skills[index] if index >= 0 else {}


## 1813 到的表**整份替换**（原版 `DataCenter.setAddedSkillLevelList:566-578` 先清空再填）。
## 键统一成七位技能号，避免调用方塞 int 键时和 `learned_skills[i].id` 对不上。
func apply_added_skill_levels(表: Dictionary) -> void:
	var 归一 := {}
	for 键 in 表:
		归一[str(int(键)).pad_zeros(7)] = int(表[键])
	skill_added_levels = 归一
	# 忍术页/详情都是整页重建读 `learned_skills`，这里发一声让它重画。
	skills_changed.emit(learned_skills.duplicate(true))


## 原版 `DataCenter.getAddedSkillLevel`（`DataCenter.as:795-810`）：
## `addedSkillLevel + list[id]`，世界/职业技能再各加一条职业加成；夫妻技恒 0。
## `addedSkillLevel`（统计号 31）服务端从不发，本工程也没有那一列 ⇒ 省掉；
## 世界/职业两条落在 `player_stats` 的 `add_world_skill_level`/`add_job_skill_level`（服务端 39/40）。
func added_skill_level(skill_id: String) -> int:
	var 号 := int(skill_id)
	if 号 in 情侣忍术:
		return 0
	var 层 := int(skill_added_levels.get(skill_id, 0))
	if 号 in 世界忍术:
		层 += int(player_stats.get("add_world_skill_level", 0))
	elif 号 in 职业忍术:
		层 += int(player_stats.get("add_job_skill_level", 0))
	return 层


## 忍术层数合计 = 每门已学忍术的**基础层 + 加层**。忍术面板的「境界合计」和头顶那枚
## 境界图标必须走同一份口径，否则会出现「合计已到 450、境界还停上一档」
## （用户 2026-11-07 报）。原版 `DataCenter.getTotalSkillLevel:3047` 只数基础层，
## 玩家口径要含玉链/忍具/勾玉与八门加成，所以复制一份而不是照抄。
func total_skill_level() -> int:
	var 合计 := 0
	for 技能 in learned_skills:
		合计 += int((技能 as Dictionary).get("level", 0))
		合计 += added_skill_level(str((技能 as Dictionary).get("id", "")))
	return 合计

func get_skill_cooldown(slot: int) -> float:
	return float(skill_cooldowns.get(slot, 0.0))

func request_feature(feature_name: String) -> void:
	feature_requested.emit(feature_name)

func allocate_attribute(attribute: String) -> bool:
	if attribute not in ["ap_atk", "ap_def", "ap_dex", "ap_phy"]:
		return false
	var remaining := int(player_stats.get("remaining_ap", 0))
	if remaining <= 0:
		notification_requested.emit("没有可分配的属性点")
		return false
	var backend := _online_backend()
	if backend != null:
		var values: Array[int] = {"ap_atk": [1, 0, 0, 0], "ap_def": [0, 1, 0, 0], "ap_dex": [0, 0, 1, 0], "ap_phy": [0, 0, 0, 1]}[attribute]
		return backend.request_distribute_ap(values[0], values[1], values[2], values[3])
	player_stats[attribute] = int(player_stats.get(attribute, 0)) + 1
	player_stats["remaining_ap"] = remaining - 1
	_recalculate_stats()
	_save_local_state()
	return true

## 穿一件背包里的装备。`指定槽位`/`背包格` 只给**虫槽落点**用
## （`人物窗口._处理虫槽落点` —— 原版拖虫走 `requestMoveItem(背包格, -200..-203)`，
## 目的地由**落点格**定、不按 id 算）；其余调用点（双击/菜单佩戴/装备格拖放）
## 都不传 ⇒ 行为与改前完全一致。
func equip_item(item_id: String, 指定槽位: int = 0, 背包格: int = 0) -> bool:
	# 背包格 = 1 基格号（拖拽载荷里的 `槽位号`，原版的 `dragData.position`）。
	# 不传时按 id 反查第一件（原行为）。
	var index := (背包格 - 1) if 背包格 > 0 else _inventory_index(item_id)
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	# ⚠️ 判据是「**这个 id 认不认得出装备位**」，不是 `category == "装备"`。
	#    原版就这么判：`EquipPane.onItemUp` 用 `EquipmentPosition.getItemEquipPosition(id)`
	#    （`EquipmentPosition.as:71-142`），认得出才当装备。
	#    2026-09-27 用户报"背包里的装备，除了武器都不能佩戴" —— 查证结果：
	#    标准 12 槽与勾玉/变身/徽章本来就穿得上（映射表对着服务端 607 件装备逐件比过，0 处不符），
	#    但**神器（`category=神器`）/灵器（`灵器`）/魂戒（`魂戒`）**这三类在 `数据/物品.json` 里
	#    分类名不是"装备"，于是被这道门**静默拒掉**（`return false`，连提示都没有）。
	if int(item.get("equip_position", 0)) == 0 and not 装备部位.是装备(String(item.get("id", ""))):
		return false
	if int(player_stats.get("level", 1)) < int(item.get("req_level", 1)):
		notification_requested.emit("等级不足，无法装备")
		return false
	# 穿到哪一格**按物品 id 算**（照原版 `EquipmentPosition.getItemEquipPosition`），
	# 不看 id 之外的任何东西。原来那步"拿中文名反查位置"里 神器/神器附槽/灵器 三个值是错的，
	# 会把镶嵌/勾玉/徽章/忍具/魂戒六类装备穿到别的槽上。
	#
	# ⚠️ 这里**不能**退回 `item.get("equip_position", ...)`：离线商城里买来的装备走的是
	#    `_npc_shop_items`，那条路从没写过 equip_position；而在线时服务端给的位置是权威的，
	#    也不该被本地重算覆盖。所以只在物品自带位置时用它，否则一律按 id 算。
	var 位置 := int(item.get("equip_position", 0))
	if 位置 == 0:
		位置 = 装备部位.位置(item_id)
	if 指定槽位 != 0:
		位置 = 指定槽位
	if 位置 == 装备部位.昆虫包:
		# ⚠ 虫按 id 算出的落位是 `KunChongE(-205)`（`EquipmentPosition.as:130`），而原版
		#    服务端 `_can_equip` 只放行 `-200..-203` ⇒ **双击/菜单「佩戴」穿不上虫**
		#    （客户端照样发报文、服务端静默拒 —— 2.2.3 与运行时夹具同源）。离线镜像
		#    没有服务端兜底，这一闸挡住，免得把 `equipped_items[-205]` 写成幽灵键。
		#    穿虫**只有拖上虫槽**一条路（`昆虫放入格.gd`，原版 `cellMouseUpHandler:152-164`）。
		return false
	if 位置 == 0:
		return false
	var backend := _online_backend()
	if backend != null:
		# 格号 = 下标+1 是稳定格位制的不变量（在线镜像也按此落位），不再读字段兜 0。
		return backend.request_item_move(0, index + 1, 位置, 0)
	# ⚠️ 离线分支对齐服务端 `handle_item_move` 的**交换**语义
	# （`2.2.3/tools/fake_flash_server.py:47483-47491`：两边都 pop、互为回填，
	#   被顶下来的旧装备落回**新装备腾出的那一格**）。
	# 原来这段只写 `equipped_items[位置]`：背包里的件**没挪走**（一穿就复制），
	# 原穿着的件被直接覆盖**凭空蒸发** —— 2026-10-01 用户报"装备替换没有实装"即此。
	var 顶下的: Dictionary = (equipped_items.get(位置, {}) as Dictionary).duplicate(true)
	if 顶下的.is_empty():
		_清一格(inventory, index + 1)      # 留洞，别的件不动（稳定格位制）
	else:
		顶下的["slot_index"] = index + 1
		inventory[index] = 顶下的
	equipped_items[位置] = item.duplicate(true)
	inventory_changed.emit(inventory.duplicate(true))
	equipment_changed.emit(equipped_items.duplicate(true))
	_recalculate_stats()
	_save_local_state()
	return true

func unequip_item(位置: int) -> void:
	if not equipped_items.has(位置):
		return
	var 物品: Dictionary = equipped_items[位置]
	if 物品.is_empty():
		return        # 留键置空 = 已经是空的（判穿着看值不看 has，§3.76.2）
	var backend := _online_backend()
	if backend != null:
		# 原版在入口处**先判空格**（`EquipPane.unequip:311-327`：`getBagEmptyPositionById<=0`
		# ⇒ 只弹"背包已满"，**报文都不发**）。旧写法 `_first_free_inventory_slot()` 满了
		# 兜底回 96 —— 报文照发，服务端把 96 格那件**当交换对象**换到身上，比不发更糟。
		var 空格 := _first_free_inventory_slot()
		if 空格 == 0:
			notification_requested.emit("背包已满，无法卸下装备")
			return
		backend.request_item_move(0, 位置, 空格, 0)
		return
	# ⚠️ 离线分支照服务端：卸下的件要**回到背包空格**，满了**不卸**并提示
	#   "背包已满，无法卸下装备"（`fake_flash_server.py:47432-47448`）。
	#   原来只把 `equipped_items[位置]` 置空 —— 件直接蒸发，2026-10-01 用户报"卸下没有实装"即此。
	# 空格 = 第一个 `{}` 洞或尾后（稳定格位制，2026-10-01 B；`_放进空格` 顺带维护 slot_index）。
	var 放进格 := _放进空格(inventory, 物品, 背包总格数())
	if 放进格 <= 0:
		notification_requested.emit("背包已满，无法卸下装备")
		return
	equipped_items[位置] = {}
	inventory_changed.emit(inventory.duplicate(true))
	equipment_changed.emit(equipped_items.duplicate(true))
	_recalculate_stats()
	_save_local_state()


func strengthen_equipment(位置: int) -> bool:
	if not equipped_items.has(位置):
		return false
	var item: Dictionary = equipped_items[位置]
	if item.is_empty():
		notification_requested.emit("该部位尚未装备忍具")
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_strength(位置, 0)
	# ⚠️ 离线时**不再本地自造**。这里原来算的是 `cost = (等级 + 1) * 100` + 100% 成功率 ——
	#    真值见 `脚本/界面/装备打造表.gd:33-35`，那里白纸黑字写着这两条**都是错的**
	#    （金币恒为 0、材料是强化灵珠 16000016、成功率 100/90/80/…）。
	#    而且这不是"只有测试走得到"的分支：`后端连接._fail_connection()` 把 `in_game` 清成 false
	#    **却不换场景** —— 断线后玩家还站在图里，这些离线分支**真能点到**，
	#    点了就本地改属性、扣金币，服务端不知道（desync，甚至刷属性）。见 §3.29.6。
	_离线拒绝("强化装备")
	return false

## `全部` = 菜单里的「全部使用」（原版 `ItemWindow2.useAll`，`PacketCreator.as:396-404`
## 把它写成 USE_ITEM 报文的**第 4 段**——那**只有一个布尔槽**，服务端按物品种类解释：
##   · `info.useAll` 的礼包类 → 整摞吃（`fake_flash_server.py:50234-50246`）；
##   · 回复药剂 → 它是"自动喝药"标志，HP 不在阈值下**不消耗**只回取消包（`:50374-50398`）。
##   菜单本来也只对 `use_all==1` 的物品显示「全部使用」（`filtrateItemMenu :520`）。
## 离线模拟取保守口径：`全部` 且这件 `use_all==1` 才吃完整摞；其余（含药剂误传）等同使用 1 个。
## 客户端 `use_all` 列由 `开发工具/导出物品use_all.py` 从服务端 catalog 补齐（以前整列缺失，
## 这菜单项任何物品都不出）。
##
## ⚠️ **2026-10-02 离线这条重写**：以前离线只认 `item.hp/mp` 两个字段 —— 那是
## `离线示例数据` **手写种子**塞进去的（拉面 hp=250），真道具（`数据/物品.json` 的行）
## 根本没这两个键，于是"除了两颗演示药，消耗品离线用了等于没用"；
## 而礼包类（category≠"消耗品"）更在门口就被 `return false` 挡死。
## 现在离线读**使用效果列**（`use_type/hp_restore/mp_restore/money_reward/coupon_reward/contents`，
## 由 `开发工具/导出物品使用效果.py` 从服务端 catalog 补进表里 —— 和 use_all 那次同一路子）。
## 在线用不到这些列（发放是服务端的事，客户端只看回包：属性走 `_send_stats`、
## 点券走字段号 30、礼包内容走背包 ADD —— 见 `道具真实事务` 在线门的"点券金币礼包"段）。
## **只带 id** 的调用（快捷栏、自动吃药）才按 id 找第一摞；网格 UI 走 `use_inventory_slot`。
func use_inventory_item(item_id: String, 全部 := false) -> bool:
	return use_inventory_slot(_inventory_index(item_id) + 1, 全部)


## 吃**玩家点的那一格**（2026-10-17 巡检 #16）。
## 原来这里按 id 反查首摞 ⇒ 背包里同 id 两摞时，点第二摞吃的是第一摞。
## 同一条理由 2026-10-01 A/C 已经给**销毁**改过（`背包窗口.gd` ⑩），
## 「绑定」也是按 `_selected_inventory_格`（⑪）—— 使用/存取/出售一直漏着。
##
## ⚠️ **2026-10-17 巡检 #20-C**：在线那一头原来只有"分流装备 / 直接发包"两句，
## 原版 `UI.useItem:1294-1343` 那串**本地前置闸**一条都没有。服务端对其中几条是
## **静默 return**（死亡 `:50325`、等级不够 `:50333`），对满血满蓝只回一帧 237 取消
## （`:50540-50551`）⇒ 玩家看到的就是"双击血药，什么都没发生"，永远猜不到为什么。
## 下面这六条照原版逐条补回（**发包之前**判，和原版一样不消耗、不误清本地状态）。
## 返回 true = 这一件**不许发**（拒因已经自己播出去了）。
## 文案逐条抄原版（`en_US$message_properties.as:62/1752/1887/1972/1975/2581` + `ITEM_COOL_WARNING:1143`）。
func _使用前置拒(物品id: String, 后端 = null, 件: Dictionary = {}) -> bool:
	var 补零 := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	var 定义: Dictionary = GAME_DATA.item(补零)
	# ①② 等级 / 职业（原版 `isFitMe(FIT_LEV)`、`isFitMe(FIT_JOB)`，`UI.as:1298-1306`）。
	#    这两条服务端也判（`:50333` 等级），但服务端那条是**裸 return**，玩家什么都看不到。
	if int(定义.get("required_level", 0)) > int(player_stats.get("level", 1)):
		notification_requested.emit("你的等级不够，不能佩戴该物品!")
		return true
	var 需求职业 := int(定义.get("required_job", 0))
	if 需求职业 != 0 and 需求职业 != int(player_stats.get("job", 0)):
		notification_requested.emit("你的职业不适合佩戴该物品!")
		return true
	# ③ 冷却（原版 `SkillHandler.isItemCooling` → `ITEM_COOL_WARNING`，`UI.as:1316-1319`）。
	#    这里读的就是上面 237 那一份本地表；服务端那 0.5 秒的**共享** CD 客户端学不到，
	#    误点它会照旧收到一帧取消、静默不吃药（不会丢件，只是少一句提示）。
	var 物品号 := int(补零) if 补零.is_valid_int() else 0
	if 后端 != null and bool(后端.call("物品冷却中", 物品号)):
		notification_requested.emit("物品正在冷却，还不能使用")
		return true
	# ④⑤⑥ 回复类（`ItemType.isItemXiaoHao` = 类型 3/4/5：HP 药 / MP 药 / 活力药）的血蓝闸。
	#    ⚠️ 原版条件里还有 `hpR/mpR`（按百分比回的那族），表里**没有这两列**
	#    （`开发工具/导出物品使用效果.py` 只导 hp_restore/mp_restore）⇒ 这里按"固定值回复"判，
	#    比例药会漏判成"可以发"——服务端自己也会拒，不丢件，只是少一句提示。
	if int(补零.substr(0, 2) if 补零.length() >= 2 else "0") not in [3, 4, 5]:
		return false
	var 回血 := int(件.get("hp", 定义.get("hp_restore", 0)))
	var 回蓝 := int(件.get("mp", 定义.get("mp_restore", 0)))
	var 血 := int(player_stats.get("hp", 0))
	var 蓝 := int(player_stats.get("mp", 0))
	var 血满 := 血 >= int(player_stats.get("max_hp", 1))
	var 蓝满 := 蓝 >= int(player_stats.get("max_mp", 1))
	if 回血 > 0 and 血 <= 0:
		notification_requested.emit("死亡状态下不能使用物品")
		return true
	if 回血 > 0 and 回蓝 == 0 and 血满:
		notification_requested.emit("你的血值已经满了!")
		return true
	if 回血 == 0 and 回蓝 > 0 and 蓝满:
		notification_requested.emit("你的查克拉已经满了!")
		return true
	if 回血 > 0 and 回蓝 > 0 and 血满 and 蓝满:
		notification_requested.emit("你的血值和查克拉都是满的")
		return true
	return false


## `选择` = 自选礼包（`libao_select`）那一族带回来的 `{job, index}`（原版
## `ChoiceLibaoWindow.getSelectItemIndex:247-273`）。在线原样塞进 USE_ITEM 报文**第 3 段**
## （服务端 `_use_item_request_fields:49791-49813` 把以 `{` 开头的尾巴整段还原成一个 JSON 字段），
## 离线只发**选中的那一条**。不带它 ⇒ 在线被服务端拒、离线照同一条拒 —— 两端同判，
## 这是 2026-10-17 #20-A 那笔账的另一半（缺的是**选择窗**，不是选择校验）。
func use_inventory_slot(格位: int, 全部 := false, 选择: Dictionary = {}) -> bool:
	var item: Dictionary = _占用条(inventory, 格位)
	if item.is_empty():
		return false
	var index := 格位 - 1
	var item_id := String(item.get("id", ""))
	# 宠物装备先分叉（原版 `onItemDoubleClick:879-882` 在这里就 return 了，**永远不进 useItem**）。
	# 不分叉的后果见 `equip_pet_item_from_bag` 的注：宠物槽位置是正数 1..5，会被服务端当背包格号。
	if 装备部位.是宠物槽(装备部位.位置(item_id)):
		return equip_pet_item_from_bag(格位)
	# 「双击=使用」的分流同样看"是不是装备位"，不看分类名 —— 神器/灵器/魂戒
	# 在原版走的也是 `UI.useItem → requestEquipItem` 那条路（`UI.as:1346-1350`）。
	var 是装备 := int(item.get("equip_position", 0)) != 0 or 装备部位.是装备(item_id)
	var backend := _online_backend()
	if backend != null:
		if 是装备:
			return equip_item(item_id)
		if _使用前置拒(item_id, backend, item):
			return false
		return backend.request_use_item(index + 1, int(item_id), 全部, [], 选择)
	if 是装备:
		return equip_item(item_id)
	if int(item.get("quantity", 0)) <= 0:
		return false
	# 离线也走**同一串本地前置闸**（#20-C）。以前离线满血吃拉面照样扣一件
	# （`heal_player` 把 hp 钳在上限、件却没了），等级闸则是 `:50333` 那句静默 return 的仿版；
	# 两条现在都有原版的文案。
	if _使用前置拒(item_id, null, item):
		return false
	# —— 离线仿真。判据/文案逐条对 `handle_use_item`（`fake_flash_server.py:50323-`）。——
	var 定义: Dictionary = GAME_DATA.item(item_id)
	var 种类 := String(定义.get("use_type", "")).to_lower()
	# 技能书：服务端 `handle_use_item:50513-50530` 认出 `definition.skill_id > 0` 就转 `_learn_skill`
	# （消耗的就是点的这一摞书）。客户端物品表没有 `skill_id` 列，用 `技能文案.reqBook` 反查。
	if String(定义.get("category", "")) == "技能书" \
			or String(定义.get("source_category", "")) == "JiNengShu":
		var 对应忍术 := GAME_DATA.skill_id_for_book(item_id)
		if 对应忍术.is_empty():
			notification_requested.emit("%s是材料或任务物品，不能直接使用。"
				% String(定义.get("name", item_id)))
			return false
		return learn_skill_from_book(对应忍术)
	# `zidong` 灵药（生命/查克拉灵药、柠檬茶…）**不是瞬回药**：服务端走
	# `_use_auto_consume_item` 把它灌进"自动补给容量"，只回 `1292` 状态帧。
	# 以前离线因为表里有 hp_restore 就按普通血药**当场回血并扣件**，与在线行为不同
	# ⇒ 照 buff 族那条口径：明说要在服务端结算、**不扣件**（离线硬编就成自造）。
	if 种类 == "zidong":
		notification_requested.emit("「%s」的效果要在服务端结算（离线不模拟）"
			% String(定义.get("name", item_id)))
		return false
	# 种子手写的 hp/mp **优先**（两颗演示药与既有门都靠它）；真道具走表里的效果列。
	var 回血 := int(item.get("hp", 定义.get("hp_restore", 0)))
	var 回蓝 := int(item.get("mp", 定义.get("mp_restore", 0)))
	var 发金币 := int(定义.get("money_reward", 0))
	var 发点券 := int(定义.get("coupon_reward", 0))
	var 内容: Array = 定义.get("contents", [])
	# `preview == 1` 的 libao/libao_fufei：底部「金币/点券」两行是**礼包内含的奖励**
	# （窗的 can-open 判定只查等级与 `money.cash`，见 `SelectGiftWindow.showIcon:154-233`），
	# 唯一成本是 `libao_fufei` 的 `money.cash`（「礼包开启需要支付 N 元宝」）。
	# 奖励行按当前职业组重取（`contents` 是 job 0/300 扁平化后的旧列，会串职业）。
	var 预览配置 := GAME_DATA.礼包详情(item_id)
	var 是预览礼包 := not 预览配置.is_empty() \
			and String(预览配置.get("type", "")).to_lower() in ["libao", "libao_fufei"]
	var 扣元宝 := 0
	if 是预览礼包:
		if String(预览配置.get("type", "")).to_lower() == "libao_fufei":
			var 预览钱: Dictionary = 预览配置.get("money", {}) as Dictionary
			扣元宝 = absi(int(预览钱.get("cash", 0)))
		内容 = []
		for 行 in GAME_DATA.礼包详情物品(item_id, int(player_stats.get("job", 0))):
			内容.append([int(行.get("item_id", "0")), int(行.get("count", 1))])
	if 回血 <= 0 and 回蓝 <= 0 and 发金币 <= 0 and 发点券 <= 0 and 内容.is_empty():
		# 没有任何可仿的效果。两种拒因分开说，**都不许消耗**：
		#   · buff/修行/口粮族（use_type 非空：shuxing/shuangbei/zhenqi/xiaohao 的 hl/yueli 支…）
		#     的结算在服务端（定时器 + 属性百分比 + 1433 推包），离线硬编一份就是自造 → 明说；
		#   · 无 use_type 的（材料/任务件）→ 照服务端原话（`:50367`「%s是材料或任务物品，不能直接使用。」）。
		var 名 := String(定义.get("name", item_id))
		if String(定义.get("use_type", "")).is_empty():
			notification_requested.emit("%s是材料或任务物品，不能直接使用。" % 名)
		else:
			notification_requested.emit("「%s」的效果要在服务端结算（离线不模拟）" % 名)
		return false
	var 可全吃 := int(item.get("use_all", 定义.get("use_all", 0))) == 1
	var 次数 := int(item.get("quantity", 1)) if (全部 and 可全吃) else 1
	if 是预览礼包 and 扣元宝 * 次数 > int(player_stats.get("cash", 0)):
		notification_requested.emit("很抱歉，你的元宝不足！")
		return false
	# ⚠️ **`contents` 对三种 libao 不是"发这一整套"**（2026-10-17 巡检 #20-A）。
	#   表里那列是服务端 `_decode_gift_contents:8438-8454` 把 `parameters["items"]`
	#   的 job 0/300 两组**扁平化**出来的候选清单；结算在 `_use_authored_gift_item:49642-49790`：
	#     · `libao_select`（20 件）⇒ 只有**选中的那一条**会发，没带 selection 时回
	#       「请先在自选礼包中选择一件奖励。」并 `return 0` —— **礼包一件不扣**；
	#     · `libao_rand`（129 件）⇒ 每一件按 weight 抽**一条**（`:49687-49703`）；
	#     · `libao` / `libao_fufei` ⇒ 整套都发（落到 `:49704-49708` 的 ×次数）。
	#   原来离线不分 kinds、`for 行 in 内容` 全发 ⇒ 吃一个「勾玉可选礼包（81颗）」凭空得
	#   16 种×81 颗 —— 这不是"演示数据糙一点"，是刷物品。随机/自选离线都不硬编（同上面
	#   buff 族那条口径），拒因要说清且**不扣件**（照服务端那条 return 0）。
	if not 内容.is_empty() and (种类 == "libao_select" or 种类 == "libao_rand"):
		var 礼包名 := String(定义.get("name", item_id))
		if 种类 == "libao_rand":
			# 随机族**不认选择**（服务端 `libao_rand` 只在"带了 selection"时才当自选结算，
			# 而选择窗只对 `libao_select` 开）⇒ 按权重抽一条仍是服务端的事，离线不硬编。
			notification_requested.emit("「%s」的奖品是按权重随机抽一件，离线不模拟发放（要在服务端结算）。" % 礼包名)
			return false
		# 自选族：**只有选中的那一条会发**（服务端 `_use_authored_gift_item:49663-49686`
		# 收到合法 selection 后就 `rewards = [rewards[index]]`）。校验不合格的三条判据
		# 一起抄（见 `_自选礼包选中`），拒的时候回服务端那句原话、**一件不扣**（`:49679-49682`）。
		var 选中 := _自选礼包选中(item_id, 选择)
		if 选中.is_empty():
			if 选择.is_empty():
				notification_requested.emit(
						"「%s」要先选一件奖励，离线不模拟发放（要在服务端结算）。" % 礼包名)
			else:
				notification_requested.emit("请先在自选礼包中选择一件奖励。")
			return false
		# 内容换成"就这一条"，后面那段原子预发 + 回滚 + 扣件**一行不用改**。
		内容 = [[int(String(选中.get("item_id", "0"))), int(选中.get("count", 1))]]
		# ⚠️ 一次只吃**一枚**：原版这条链上没有 useAll（`ChoiceLibaoWindow.__onOkBtnClick:285`
		#    传的是 selection 不是数量），菜单也对礼包不显示「全部使用」。
		次数 = 1
	# ⚠️ **contents 先做原子预发、再扣礼包**（服务端 `_use_authored_gift_item:50216-50219`
	#   是先 `_has_inventory_capacity` 再 consume 的；放不下回「背包空间不足，无法打开礼包。」、
	#   礼包**一件不扣**）。这里拿整数组的副本试发，失败就整体回滚 ——
	#   离线仿真的"要么全成要么全不动"，别发一半。
	var 备份: Array[Dictionary] = []
	if not 内容.is_empty():
		for 条 in inventory:
			(备份 as Array).append((条 as Dictionary).duplicate(true))
		for 行 in 内容:
			# ⚠️ `行[0]` 是 **float**（JSON 数值进 GDScript 一律变 float，`String(float)` 没有构造器，
			# 直接 `String(行[0])` 会 "Invalid call. Nonexistent 'String' constructor"）——先 int 再 str。
			if not _离线发放物品(str(int(行[0])), int(行[1]) * 次数):
				inventory = 备份
				notification_requested.emit("背包空间不足，无法打开礼包。")
				return false
	for _吃 in 次数:
		if 回血 > 0:
			heal_player(回血)
		if 回蓝 > 0:
			player_stats["mp"] = mini(int(player_stats.get("max_mp", 1)), int(player_stats.get("mp", 0)) + 回蓝)
	if 发金币 > 0:
		player_stats["gold"] = int(player_stats.get("gold", 0)) + 发金币 * 次数
	if 发点券 > 0:
		# 与在线同一条落点：`player_stats.cash_bind`（背包"商城点券"行、商城点券栏都读它）。
		player_stats["cash_bind"] = int(player_stats.get("cash_bind", 0)) + 发点券 * 次数
	if 是预览礼包 and 扣元宝 > 0:
		player_stats["cash"] = int(player_stats.get("cash", 0)) - 扣元宝 * 次数
	if 发金币 > 0 or 发点券 > 0 or 扣元宝 > 0 or 回蓝 > 0:
		player_stats_changed.emit(player_stats.duplicate(true))
	item["quantity"] = int(item.quantity) - 次数
	if int(item.quantity) <= 0:
		_清一格(inventory, index + 1)      # 吃空只留洞，别的件**不许位移**（用户报②）
	else:
		inventory[index] = item
	inventory_changed.emit(inventory.duplicate(true))
	_save_local_state()
	return true


## 只读：格位（1 基）上那件的**副本** —— 给 UI 层取 id 判断用，**改它不生效**。
func 格位物品(格位: int) -> Dictionary:
	return (_占用条(inventory, 格位) as Dictionary).duplicate(true)


## 背包里这个号**一共**还剩几件 —— 原版 `DataCenter.isBagExistItem:3166-3182`：
## 遍历 `commonItems` 把同 id 的 `quantity` **加起来**（数的是件数，不是格数）。
## 福袋窗用它决定"领完这一只还抽不抽下一只"（`SuccessWindow.automatismStart:489-504`
## 与 `onClickTakeBtn:300-308` 两处都读它）。
func 背包同名件数(物品id: Variant) -> int:
	var 想找 := String(物品id)
	var 总 := 0
	for 条v in inventory:
		var 条: Dictionary = 条v as Dictionary
		if 条.is_empty():
			continue
		var 现有 := String(条.get("id", ""))
		if 现有 == 想找 or (现有.is_valid_int() and 想找.is_valid_int() and int(现有) == int(想找)):
			总 += int(条.get("quantity", 0))
	return 总


## 这一格上的东西是不是**福袋族**（原版 `ItemWindow2.as:957-964` 的
## `StringTool.isFuDaiLeiItemByID(curCellData.id)` 那一支 ⇒ `SuccessWindow`「成就福袋」）。
## 判据完全照 `StringTool.as:721-741`：遍历 `Box.fudai` 比 `itemid`，且 **15008005 硬排除**。
## ⚠️ 原版这一支在 `useItem` 里排在礼包两支（`:990-1017`）**之前**，而且直接 `return` ——
##    福袋永远只发 `USE_FUDAI`（= `requestFudaiOpen(背包格位)`，`FudaiProcessor.as:216-222`），
##    不走 USE_ITEM、也不经过 `use_inventory_slot`。所以这里必须在 `_use_item` 的第一位拦。
func 是福袋类(格位: int) -> bool:
	var 条: Dictionary = _占用条(inventory, 格位)
	if 条.is_empty():
		return false
	return GAME_DATA.福袋类型(String(条.get("id", ""))) > 0


## 这一格上的东西是不是**要先选一件**的自选礼包（原版 `ItemWindow2.as:990-1017` 那一支 ⇒
## `ChoiceLibaoWindow`）。UI 层用它决定"直接吃"还是"先开选择窗"。
## ⚠️ 还要求**候选非空**：表里查不到这件礼包（或全被服务端那两条脏行过滤掉了）时
##    开窗就是一片空格子，不如让 `use_inventory_slot` 按原来的路子拒掉、说清拒因。
func 是自选礼包(格位: int) -> bool:
	var 条: Dictionary = _占用条(inventory, 格位)
	if 条.is_empty():
		return false
	var 号 := String(条.get("id", ""))
	if String(GAME_DATA.item(号).get("use_type", "")).to_lower() != "libao_select":
		return false
	return not GAME_DATA.礼包候选(号, int(player_stats.get("job", 0))).is_empty()


## 这一格上的东西是不是**先弹详情**的礼包（原版 `ItemWindow2.as:990-1017` 的
## `isPreviewLibao && (type == "libao" || type == "libao_fufei")` 两支）。
## `数据/礼包详情.json` 只收 `preview == 1`，所以查到且类型不是自选族就成立。
## 等级不够也照原版开窗（窗里显示「很抱歉，你的等级不足！」）—— 这里不拦。
func 是详情礼包(格位: int) -> bool:
	var 条: Dictionary = _占用条(inventory, 格位)
	if 条.is_empty():
		return false
	var 号 := String(条.get("id", ""))
	var 详情 := GAME_DATA.礼包详情(号)
	if 详情.is_empty():
		return false
	var 类型 := String(详情.get("type", "")).to_lower()
	return 类型 == "libao" or 类型 == "libao_fufei"


## 这一格是不是**宠物技能替换**用的「神奇技能符」（原版 `ItemWindow2.as:1056` 的
## `type == "jineng"` 支：只认 `use_type`，不认物品号）。UI 层用它决定双击是否弹
## `PetSkillResetWindow`；服务端只对 15018001 走 `_use_pet_skill_symbol`。
func 是技能符(格位: int) -> bool:
	var 条: Dictionary = _占用条(inventory, 格位)
	if 条.is_empty():
		return false
	return String(GAME_DATA.item(String(条.get("id", ""))).get("use_type", "")).to_lower() == "jineng"


## 神奇技能符的结算包：`requestUseItem(position, itemId, {oldskill,newskill,petUid})`
## （`PetSkillResetWindow.as:89-93`）。服务端 `_use_pet_skill_symbol:40012-40080`
## 读的就是报文第 3 段那个 JSON；离线不模拟（要扣件 + 改宠物技能，属于服务端事务）。
func use_pet_skill_symbol(格位: int, 宠物uid: int, 旧技能: int, 新技能: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		_离线拒绝("使用神奇技能符")
		return false
	var 条: Dictionary = _占用条(inventory, 格位)
	if 条.is_empty():
		return false
	return backend.request_use_item(格位, int(str(条.get("id", "0"))), false, [],
			{"petUid": 宠物uid, "oldskill": 旧技能, "newskill": 新技能})


## 服务端 `_use_authored_gift_item:49661-49686` 那三条校验的镜像：
##   ① 职业组 ∈ {0, 本职业组}；② 下标在候选清单内；③ **那一行的 job 必须等于传进来的组**。
## 全过 ⇒ 返回选中的那条候选；任何一条不过 ⇒ 空字典（调用方回原话、**一件不扣**）。
## 清单来自 `游戏数据.礼包候选`，与选择窗**同一份序** —— 两处分开算下标就是这次修复
## 要防的那类错（窗上第 3 格领走第 4 条奖励）。
func _自选礼包选中(物品id: String, 选择: Dictionary) -> Dictionary:
	if 选择.is_empty():
		return {}
	var 职业 := int(player_stats.get("job", 0))
	var 组 := int(选择.get("job", -1))
	var 序 := int(选择.get("index", -1))
	if 组 not in [0, (maxi(0, 职业) / 100) * 100] or 序 < 0:
		return {}
	var 候: Array = GAME_DATA.礼包候选(物品id, 职业)
	if 序 >= 候.size():
		return {}
	var 项: Dictionary = 候[序] as Dictionary
	return 项 if int(项.get("job", -1)) == 组 else {}


## 离线发一件东西进背包（礼包 contents 用）。堆叠口径照服务端 `_add_inventory_item:47080-47096`：
## **装备/不能堆叠的每件一格**（`位置≠0`），可叠的先补进没满的同 id 摞、按 `stack_max` 封顶，
## 剩下的另起新格（**洞优先复用**，稳定格位制）。放不下返回 false（调用方负责回滚）。
## 上限走 `游戏数据.堆叠上限()`（99/999 抬到 9999 那条有意偏离），与服务端 `_item_stack_limit` 同口径。
func _离线发放物品(物品id: String, 数量: int) -> bool:
	var 定义: Dictionary = GAME_DATA.item(物品id)
	var 上限 := GAME_DATA.堆叠上限(物品id)
	var 不可叠 := 装备部位.位置(物品id) != 0
	var 待发 := 数量
	if not 不可叠:
		for 条 in inventory:
			if 待发 <= 0:
				break
			var d := 条 as Dictionary
			if d.is_empty() or String(d.get("id", "")) != 物品id:
				continue
			var 现有 := int(d.get("quantity", 1))
			if 现有 >= 上限:
				continue
			var 并进 := mini(上限 - 现有, 待发)
			d["quantity"] = 现有 + 并进
			待发 -= 并进
	while 待发 > 0:
		var 新建 := 1 if 不可叠 else mini(待发, 上限)
		var 单 := {
			"id": 物品id, "name": String(定义.get("name", 物品id)),
			"category": String(定义.get("category", "材料")),
			"quantity": 新建, "icon": String(定义.get("icon", "")),
		}
		if _放进空格(inventory, 单, 背包总格数()) <= 0:
			return false
		待发 -= 新建
	return true

## 销毁（菜单「销毁」→ DestroyWindow 确认 → 这条；原版 `ItemWindow2.destroyItem` 按
## **格位**发 `ITEM_MOVE kind=1`，从头到尾**没有**"身上穿着同 id 就先拒绝"这种检查 ——
## 我们原来那三处 `equipped id==id` 误报（销毁/出售/存入）会把"背包里这条项链"
## 因为"身上戴着另一条同 id 的"而拒销（2026-10-01 用户报①）。操作对象是一格，不是一件 id。
func discard_item(item_id: String, quantity := -1) -> bool:
	var index := _inventory_index(item_id)
	if index < 0:
		return false
	return discard_inventory_slot(index + 1, quantity)

## 按**格号**销毁（拖到空处的确认窗也走这条 —— 精确到那一格，同 id 两摞不会错杀）。
## `quantity<0` = 整摞（原版 `DestroyWindow.as:57-62` 的 dropCount=count 就是这个口径）。
func discard_inventory_slot(格: int, quantity := -1) -> bool:
	var item := _占用条(inventory, 格)
	if item.is_empty():
		return false
	var count := int(item.get("quantity", 1)) if quantity < 0 else mini(maxi(1, quantity), int(item.get("quantity", 1)))
	var backend := _online_backend()
	if backend != null:
		return backend.request_item_move(1, 格, 0, count)
	item["quantity"] = int(item.get("quantity", 1)) - count
	if int(item.quantity) <= 0:
		_清一格(inventory, 格)
	else:
		inventory[格 - 1] = item
	inventory_changed.emit(inventory.duplicate(true))
	_save_local_state()
	return true

## 按格号销毁**整摞**（C：拖到空处松手、值线之外的普通件不经确认直接销 ——
## 原版 UIMain2 透明层点击 → `ItemWindow2.destroyItem:633-678` 的直发分支）。
func drop_destroy_inventory_slot(格: int) -> bool:
	return discard_inventory_slot(格, -1)

## 按格号**绑定**一件（菜单「绑定」）。原版 `ItemWindow2.onClickPopupMenu:798`：
## `API.client.requestBindItem(curCellData.position)` —— **不发确认、不开窗**，
## 报文 `ITEM_CHANGE` 子命令 9（`ItemChangeProcessor.as:313-319`：byte 9 + int position）。
## 服务端 `handle_item_change` BIND（`fake_flash_server.py:53506-53519`）：
##   · `Etc.NeverBindItems` 名单里的件 → 系统聊天"该物品不能绑定。"、**什么都不改**；
##   · 已绑（can_trade false）→ `_bind_item_instance:47057` 静默、一个包都不发；
##   · 其余 → `can_trade=False`（**不可逆**），清格+同格重新下发 + "物品绑定成功。"。
## 在线只发包、镜像由回包驱动（回包里的 can_trade 靠 `后端连接._parse_item_entry` 读，
## 2026-10-02 前那条没读 —— 绑完客户端还当"可交易"，菜单去不掉「绑定」项）。
## 离线照服务端同一口径本地走（名单也读同一份导出表）。
func bind_inventory_slot(格: int) -> bool:
	var item := _占用条(inventory, 格)
	if item.is_empty():
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_bind_item(格)
	# ⚠️ 离线分支**判序照服务端**（`handle_item_change:53341` 的禁绑检查在
	# `_bind_item_instance:47057` 的已绑检查**之前**）：禁绑件哪怕已绑也回那句"不能绑定"，
	# 已绑的普通件才是静默 false（服务端一个包都不发）。
	if _在禁绑名单(String(item.get("id", ""))):
		notification_requested.emit("该物品不能绑定。")
		return false
	if not bool(item.get("can_trade", true)):
		return false
	item["can_trade"] = false
	inventory[格 - 1] = item
	inventory_changed.emit(inventory.duplicate(true))
	_save_local_state()
	notification_requested.emit("物品绑定成功。")
	return true

## 宝石**镶嵌**（镶嵌窗里把宝石拖进空孔 → 这条）。原版 `requestInlay(装备position, 宝石position)`
## = `ITEM_CHANGE` 子命令 1（服务端 `_inlay_equipment_stone:54233`：校验孔位/宝石类型/限属性 →
## 消耗 1 颗 → 装备 `inlays` 末尾追加 → 清格重发装备 + `EQUIP_INLAY_INFO`，穿着还 `_send_all_stats`）。
## ⚠️ **离线不模拟**：镶嵌的属性加成、可镶类型、孔位上限全在服务端 catalog（`get_stone_inlay`/
## `EquipSystem.inlay`），客户端表里没有；假装镶嵌会造出对不上服务端的 inlay 数据，比"点了没反应"更坏。
## → 离线返回 false，让镶嵌窗给"要在服务端结算"的诚实提示（同 §3.83.2 buff 族的口径）。
func inlay_stone(装备格: int, 宝石格: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	if _占用条(inventory, 装备格).is_empty() or _占用条(inventory, 宝石格).is_empty():
		return false
	return backend.request_inlay(装备格, 宝石格)

## 宝石**取出/摘除**（点镶嵌窗里已镶的孔）。原版 `requestUninlay(装备position, 孔号0基)`
## = 子命令 2（服务端 `_remove_equipment_stone:54290`：把那颗宝石退回背包、刷新孔与装备）。
## 同样**离线不模拟**（宝石要退回哪格、装备属性怎么变都由服务端算）。
## 勾玉**镶嵌**（`GouYuCarryWindow.inalyStoneHandler:245` `requestJadeInlay(_eqtData.position, 勾玉.position)`
## = `ITEM_CHANGE` 子命令 **13**）。与宝石那条（子命令 1）**不是同一条协议**，别复用。
func jade_inlay(装备格: int, 勾玉格: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	if _占用条(inventory, 装备格).is_empty() or _占用条(inventory, 勾玉格).is_empty():
		return false
	return backend.request_jade_inlay(装备格, 勾玉格)


## 勾玉**取出**（`GouYuCarryWindow.deleteStoneHandler:257-268` `requestJadeUninlay(_eqtData.position,
## 孔.position)` = 子命令 **14**）。同样**离线不模拟**（退回哪格、装备怎么变都由服务端算）。
func jade_uninlay(装备格: int, 孔号: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	if _占用条(inventory, 装备格).is_empty():
		return false
	return backend.request_jade_uninlay(装备格, 孔号)


func uninlay_stone(装备格: int, 孔号: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	if _占用条(inventory, 装备格).is_empty():
		return false
	return backend.request_uninlay(装备格, 孔号)

## 宝石**合成**（宝石工艺窗「宝石合成」页点「开始合成」）。原版
## `StoneCompositeWindow.composeStone:297-304` → `requestMergeStone(_itemData.position)`
## = `ITEM_CHANGE` 子命令 0（服务端 `fake_flash_server.py:54226 _merge_equipment_stone`：
## 一次请求**吃掉整摞里的 3 颗** → 按 `merge.level{目标级}.prob` 掷一次 → 成功加 1 颗 `inlay.next`）。
## ⚠️ **离线不模拟**，和 `inlay_stone` 同口径：这次事务的判定/掷骰/产物全在服务端算
## （满级「该宝石已达到最高等级。」/不足 3 颗「合成需要三个同等级宝石。」/背包满
## 「背包已满，无法合成宝石。」三句原话都在 :54078-54087），客户端自己扣 3 颗再掷骰，
## 一上线就会和服务端的镜像对不上。→ 离线返回 false，由窗口给"要在服务端结算"的诚实提示。
## 客户端侧的三道闸（满级/不足3/金币）在 `功能窗口._宝石工艺_开始合成` 里照原版 `submitToHandle` 判。
func merge_stone(宝石格: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	if _占用条(inventory, 宝石格).is_empty():
		return false
	return backend.request_merge_stone(宝石格)

## 宝石**幸运**合成（`ITEM_CHANGE` 子命令 **31**，2026-10-11 §3.100 实装）。
## `张数` = 幸运符用几张（0 = 不用）。掷骰与产物同样**只由服务端算**。
func merge_stone_lucky(宝石格: int, 张数: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	if _占用条(inventory, 宝石格).is_empty():
		return false
	return backend.request_merge_stone_lucky(宝石格, 张数)

## 秘笈合成（`CAN_JUAN_ACTION 1352`，2026-10-03 接通）。**离线返回 false**、由窗口给
## "要在服务端结算"（同 `merge_stone` 口径：掷骰/产物由服务端算，客户端不本地改）。
## 参数 = 主残卷在**背包的格号**（1 基）；发包要的是那一件的 `unique_id`
## （原版 `writeDouble(_itemData.uniqueId)`，夹具按 unique_id 找主件——**不是格号**）。
func 合成秘笈(残卷格: int, 幸运符张数: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	var 行 := _占用条(inventory, 残卷格)
	if 行.is_empty():
		return false
	var 唯一号 := int(行.get("unique_id", 0))
	if 唯一号 <= 0:
		return false
	return backend.request_can_juan_compose(唯一号, 幸运符张数)

## `Etc.NeverBindItems`（`数据/原版杂项.json` 同段导出；形状 `{"0": id, "1": id…}`，**值才是 id**）。
## 判据与服务端 `never_bind_item_ids()`（`fake_flash_server.py:7504-7514`）一致：取整、>0 才算。
static func _在禁绑名单(物品id: String) -> bool:
	var 号 := int(物品id) if 物品id.is_valid_int() else 0
	if 号 <= 0:
		return false
	for 值 in GAME_DATA.取表("原版杂项").get("NeverBindItems", {}).values():
		if int(值) == 号:
			return true
	return false

## 背包内**拖拽换位**（源/目标都是 1 基绝对格位，`背包窗口._处理拖放` 传格子槽位号）。
## 在线：只发 `ITEM_MOVE(0, 源, 目标, 0)`，**不动本地**——服务端回包（MOVE 标志）驱动刷新，
## 先本地改会和回包打架。离线照服务端的交换语义
## （`fake_flash_server.py:47483-47491`：两边互为回填）；稳定格位制下（2026-10-01 B）
## 目标是**空格或洞**都放得下，两边各归各号 —— 别的件一律不位移。
func move_inventory_items(源格: int, 目标格: int) -> bool:
	if 源格 == 目标格 or 源格 < 1 or 目标格 < 1 or 目标格 > 格容量:
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_item_move(0, 源格, 目标格, 0)
	var 源 := _占用条(inventory, 源格)
	if 源.is_empty():
		return false
	var 标 := _占用条(inventory, 目标格)
	while inventory.size() < 目标格:
		inventory.append({})
	inventory[目标格 - 1] = 源.duplicate(true)
	inventory[目标格 - 1]["slot_index"] = 目标格
	if 标.is_empty():
		_清一格(inventory, 源格)
	else:
		inventory[源格 - 1] = 标.duplicate(true)
		inventory[源格 - 1]["slot_index"] = 源格
	inventory_changed.emit(inventory.duplicate(true))
	_save_local_state()
	return true

## 拆分一摞（原版 `SplitWindow` → `ITEM_SPLIT(1332)` `position:count`，1 基格位）。
## 在线只发包、离线模拟：源摞减掉拆出数，**拆出的那摞进第一个空格**（稳定格位制：
## 中间的洞优先复用，没有洞才追加到尾）；满则拒并通知（借用最通用的"背包已满"，不发明措辞）。
func split_inventory_item(位置: int, 数量: int) -> bool:
	var backend := _online_backend()
	if backend != null:
		return backend.request_item_split(位置, 数量)
	var 条 := _占用条(inventory, 位置)
	if 条.is_empty():
		return false
	var 总件数 := int(条.get("quantity", 1))
	if 数量 <= 0 or 数量 >= 总件数:
		return false
	if _首空格(inventory, 背包总格数()) <= 0:
		notification_requested.emit("背包已满")
		return false
	条["quantity"] = 总件数 - 数量
	inventory[位置 - 1] = 条
	var 拆出: Dictionary = 条.duplicate(true)
	拆出["quantity"] = 数量
	_放进空格(inventory, 拆出, 背包总格数())
	inventory_changed.emit(inventory.duplicate(true))
	_save_local_state()
	return true

## **只带 id** 的调用按 id 找第一摞；网格 UI 走 `sell_inventory_slot`。
func sell_inventory_item(item_id: String, quantity := 1) -> bool:
	return sell_inventory_slot(_inventory_index(item_id) + 1, quantity)


## 卖**玩家在那一格选中的那一摞**（同 `use_inventory_slot`：同 id 两摞会卖错那一款）。
func sell_inventory_slot(格位: int, quantity := 1) -> bool:
	var item: Dictionary = _占用条(inventory, 格位)
	if item.is_empty():
		return false
	var index := 格位 - 1
	var item_id := String(item.get("id", ""))
	# （2026-10-01 A）原"身上有同 id 就拒卖"的误报检查已删 —— 卖的是背包那一格。
	var count := mini(maxi(1, quantity), int(item.get("quantity", 1)))
	var backend := _online_backend()
	if backend != null:
		return backend.request_npc_shop_sell(index + 1, int(item_id), count)
	# ⚠️ 离线单价照原版 `ShopWindow2.as:151-158`：`floor(price/3)`，且 price>0 时下限 1 ——
	#   与「买卖数量窗」显示的总价同一个算式。旧写法 `price/2` 是自造公式（§3.29.6 同族），
	#   弹窗报一个价、进账另一个数。
	var 原价 := int(item.get("price", 0))
	var 单价 := int(原价 / 3.0)
	if 原价 > 0:
		单价 = maxi(1, 单价)
	var income := 单价 * count
	item["quantity"] = int(item.get("quantity", 1)) - count
	if int(item.quantity) <= 0:
		_清一格(inventory, index + 1)
	else:
		inventory[index] = item
	player_stats["gold"] = int(player_stats.gold) + income
	player_stats_changed.emit(player_stats.duplicate(true))
	inventory_changed.emit(inventory.duplicate(true))
	notification_requested.emit("出售获得 %d 金币" % income)
	_save_local_state()
	return true

## **只带 id** 的调用按 id 找第一摞；网格 UI 走 `deposit_slot`。
func deposit_item(item_id: String, quantity := -1) -> bool:
	return deposit_slot(_inventory_index(item_id) + 1, quantity)


## 存**玩家拖/点的那一格**（同 `use_inventory_slot`：同 id 两摞会存错那一款）。
func deposit_slot(格位: int, quantity := -1) -> bool:
	var item: Dictionary = _占用条(inventory, 格位)
	if item.is_empty():
		return false
	var index := 格位 - 1
	# （2026-10-01 A）"身上有同 id 就拒存"的误报检查已删 —— 存的是背包那一格。
	var count := int(item.get("quantity", 1)) if quantity < 0 else mini(maxi(1, quantity), int(item.get("quantity", 1)))
	var backend := _online_backend()
	if backend != null:
		return backend.request_storage_store_item(index + 1, count)
	var moved := item.duplicate(true)
	moved["quantity"] = count
	# 先确认仓库放得下（同摞合并 或 有空格），**放不下就整件事不发生**——
	# 旧写法先扣背包再塞仓库，仓库满了会把件弄丢。
	if _item_index(storage, String(moved.get("id", ""))) < 0 and _首空格(storage) <= 0:
		notification_requested.emit("仓库已满")
		return false
	item["quantity"] = int(item.get("quantity", 1)) - count
	if int(item.quantity) <= 0:
		_清一格(inventory, index + 1)
	else:
		inventory[index] = item
	_merge_item(storage, moved)
	inventory_changed.emit(inventory.duplicate(true))
	storage_changed.emit(storage.duplicate(true))
	_save_local_state()
	return true

## **只带 id** 的调用按 id 找仓库里的第一摞；网格 UI 走 `withdraw_slot`。
func withdraw_item(item_id: String, quantity := -1) -> bool:
	return withdraw_slot(_item_index(storage, item_id) + 1, quantity)


## 取**玩家点/拖的那一格**（同 `deposit_slot`）。
func withdraw_slot(格位: int, quantity := -1) -> bool:
	var item: Dictionary = _占用条(storage, 格位)
	if item.is_empty():
		return false
	var index := 格位 - 1
	var count := int(item.get("quantity", 1)) if quantity < 0 else mini(maxi(1, quantity), int(item.get("quantity", 1)))
	var backend := _online_backend()
	if backend != null:
		return backend.request_storage_take_item(index + 1, count)
	var moved := item.duplicate(true)
	moved["quantity"] = count
	# 先确认背包放得下（同摞合并 或 有空格），放不下**整件事不发生**（防"扣了取不回"）。
	if _item_index(inventory, String(moved.get("id", ""))) < 0 and _首空格(inventory, 背包总格数()) <= 0:
		notification_requested.emit("背包已满")
		return false
	item["quantity"] = int(item.get("quantity", 1)) - count
	if int(item.quantity) <= 0:
		_清一格(storage, index + 1)
	else:
		storage[index] = item
	_merge_item(inventory, moved)
	inventory_changed.emit(inventory.duplicate(true))
	storage_changed.emit(storage.duplicate(true))
	_save_local_state()
	return true

## 提升一层忍术。原版客户端**不做本地判定**：`SkillUpgradeConditionPane.__upgrade`
## 只负责把按钮点灰并发 `SKILL_CHANGE(1330)` + `writeByte(2), writeInt(skillId)`
## （`SkillChangeProcessor.as:24-31`），条件由服务端查人物等级/金币/查克拉精华
## （`DataCenter.canUpgradeSkill:2145` 只是给那三行数字上色）。
##
## ⚠️ 2026-10-18 删掉两道自造闸门：
##   · `level >= max_level` —— `max_level` 是把协议的 `masterLevel`（**熟练度**）误当等级上限
##     存进来的（见 `服务端会话同步.应用技能`），熟练度默认 0 ⇒ 一点就"该忍术已达到最高等级"；
##   · `remaining_sp <= 0` —— **"忍术点"在原版界面上不存在**：语言表里没有这三个字，
##     `requestDistributeSp` 全客户端也没有一个调用点；原版的三种消耗是人物等级、
##     金币、查克拉精华（`zq`）。
func upgrade_skill(skill_id: String) -> bool:
	var index := _skill_index(skill_id)
	if index < 0:
		return false
	var backend := _online_backend()
	if backend != null:
		# 原版报文：`writeByte(2=UPGRADE), writeInt(skillId)`（`SkillChangeAction`）。
		return backend.request_skill_change(2, int(skill_id))
	var skill: Dictionary = learned_skills[index]
	var 下一层 := int(skill.get("level", 0)) + 1
	var 人物等级 := int(player_stats.get("level", 0))
	# 服务端 `_upgrade_skill` 的次序：人物等级 → 查克拉精华 → 金币。
	if 下一层 > 人物等级:
		notification_requested.emit("角色需要达到 %d 级才能升级这个技能。" % 下一层)
		return false
	var 需求 := GAME_DATA.skill_upgrade_req(下一层, int(skill_id))
	if 需求.size() < 3:
		return false
	var 需金币 := int(需求[1])
	# 界面上的精华 = 升级需求总量 − 当前熟练度（`SkillUpgradeConditionPane.as:93`）。
	var 需精华 := maxi(0, int(需求[2]) - int(skill.get("master_level", 0)))
	if int(player_stats.get("zq", 0)) < 需精华:
		notification_requested.emit("查克拉精华不足，还需要 %d点。" % 需精华)
		return false
	if int(player_stats.get("gold", 0)) < 需金币:
		notification_requested.emit("金币不足，无法升级技能。")
		return false
	player_stats["gold"] = int(player_stats.gold) - 需金币
	player_stats["zq"] = int(player_stats.zq) - 需精华
	skill["level"] = 下一层
	# 服务端升级成功会把熟练度清零，再推一份技能包。
	skill["master_level"] = 0
	learned_skills[index] = skill
	_rebuild_skill_slots()
	skills_changed.emit(learned_skills.duplicate(true))
	_recalculate_stats()
	_save_local_state()
	return true

## 用技能书学一门忍术（忍术详情区「学习」钮 / 背包双击技能书都走这里）。
##
## 原版判定**全在服务端**：`SkillStudyConditionPane.__learn` 只发 `SKILL_CHANGE(1330)`（action 0 +
## skillId，`SkillChangeProcessor.as:16-23`），服务端 `_learn_skill`（`fake_flash_server.py:50741`）
## 依次判「已学 → 等级 → 经脉/写轮眼等 open 条件 → 背包里的书」，每条失败各回一句系统聊天。
## 2026-11-08：离线分支把 open 条件补齐了（前置特别忍术 / 八门 / 写轮眼 / 轮回六道 / 族贡），
## 之前只判等级和书，离线档能学到在线档学不了的忍术。
##
## ⚠️ 2026-10-20 修（用户报「背包有技能书仍提示缺少/不能学习」）：
##   · **原来没有在线分支** —— 在线点「学习」连包都不发，`skill_book_catalog`
##     （离线示例数据里只有两条编的技能）里找不到就**静默 return false**，玩家点了毫无反应；
##   · 离线那段是自造的「扣金币学技能」，与真值（消耗技能书、不花金币）不符，已按服务端重写。
func learn_skill_from_book(skill_id: String) -> bool:
	var 编号 := String(skill_id).pad_zeros(7) if String(skill_id).is_valid_int() else String(skill_id)
	if _skill_index(编号) >= 0:
		notification_requested.emit("该忍术已经学会")
		return false
	var backend := _online_backend()
	if backend != null:
		# 原版报文：`writeByte(0=LEARN), writeInt(skillId)`（`SkillChangeAction`）。
		return bool(backend.request_skill_change(0, int(编号)))
	# —— 离线仿真，逐条照服务端 `_learn_skill` ——
	var 定义: Dictionary = GAME_DATA.skill(编号)
	if 定义.is_empty():
		notification_requested.emit("找不到该忍术")
		return false
	var 文案: Dictionary = GAME_DATA.skill_text(编号)
	var 需要等级 := int(文案.get("reqLevel", 0))
	if int(player_stats.get("level", 0)) < 需要等级:
		notification_requested.emit("需要达到 %d 级才能学习。" % 需要等级)
		return false
	# —— `info.open` 的前置条件，顺序照服务端 `_skill_requirement_error:52013-52061` ——
	# 2026-11-08 补：原来离线只判等级和书，八门/写轮眼/轮回六道/族贡全跳过 ⇒
	# 离线档能学到在线档学不了的忍术（同一本技能书两种结果）。
	var 编号整数 := int(编号)
	# 服务端 `_project_skill_prerequisite:43906`：多重影分身←影分身、飞雷神·标←飞雷神·瞬。
	var 前置真身 := int({9031: 9030, 9033: 9032}.get(编号整数, 0))
	if 前置真身 > 0 and _skill_index(str(前置真身).pad_zeros(7)) < 0:
		notification_requested.emit("请先学习前置特别忍术。")
		return false
	var 需经脉 := int(文案.get("reqMai", 0))
	if 需经脉 > 0:
		# `JingMaiSource.getThroughMaiNumber:210-249` 口径：当前脉已贯通门数 + listId*8。
		var 八门: Dictionary = cultivation_states.get("八门", {})
		var 脉 := int(八门.get("list_id", 0))
		var 门表: Dictionary = (GAME_DATA.取表("经脉").get(str(脉), {}) as Dictionary).get("mai", {})
		var 已开: Dictionary = 八门.get("exploded", {})
		var 贯通数 := 脉 * 8
		for 门id in 门表:
			var 穴表: Dictionary = (门表[门id] as Dictionary).get("pts", {})
			if not 穴表.is_empty() and int(已开.get(int(门id), 0)) == 穴表.size():
				贯通数 += 1
		if 贯通数 < 需经脉:
			notification_requested.emit("需要开通 %d 个八门穴位。" % 需经脉)
			return false
	var 需轮眼 := int(文案.get("reqXielunyan", 0))
	if 需轮眼 > 0:
		var 轮眼阶 := int((cultivation_states.get("写轮眼", {}) as Dictionary).get("stage", 0))
		if 轮眼阶 < 需轮眼:
			notification_requested.emit("需要写轮眼达到 %d 阶。" % 需轮眼)
			return false
	# 2020..2024 是轮回六道第 4..8 道的技能（服务端从 `LunHuiYan` 各阶 `skills` 反查；
	# 客户端没有这张表，号段与阶一一对应）。
	if 编号整数 >= 2020 and 编号整数 <= 2024:
		var 需道 := 编号整数 - 2016
		var 轮回阶 := int((cultivation_states.get("轮回六道", {}) as Dictionary).get("stage", 0))
		if 轮回阶 < 需道:
			notification_requested.emit("需要先解锁轮回六道的%s。" % ["人间道", "修罗道", "饿鬼道", "地狱道", "外道"][需道 - 4])
			return false
	var 需族贡 := int(文案.get("reqBangGong", 0))
	if 需族贡 > 0:
		# 没入家族按 0 算，与 `忍术窗口._家族贡献` / `GuildSource` 同口径。
		var 家族贡献 := int(guild.get("contribution", 0)) if bool(guild.get("joined", false)) else 0
		if 家族贡献 < 需族贡:
			notification_requested.emit("需要家族贡献 %d。" % 需族贡)
			return false
	var 书id := String(文案.get("reqBook", ""))
	if not 书id.is_empty():
		var 格 := _inventory_index(书id)
		if 格 < 0 or int(inventory[格].get("quantity", 0)) <= 0:
			notification_requested.emit("背包里没有学习这个技能所需的技能书。")
			return false
		var 书: Dictionary = inventory[格]
		书["quantity"] = int(书.get("quantity", 1)) - 1
		if int(书.quantity) <= 0:
			_清一格(inventory, 格 + 1)
		else:
			inventory[格] = 书
		inventory_changed.emit(inventory.duplicate(true))
	# 记录形状对齐 `服务端会话同步.应用技能`：定义 + level/master_level/power，图标跟着定义走。
	var 技能 := 定义.duplicate(true)
	技能.merge({
		"id": 编号,
		"name": GAME_DATA.skill_name(编号),
		"level": 1,
		"master_level": 0,
		"power": int(定义.get("damage", 0)),
	}, true)
	learned_skills.append(技能)
	_rebuild_skill_slots()
	skills_changed.emit(learned_skills.duplicate(true))
	_recalculate_stats()
	notification_requested.emit("成功学会忍术【%s】。" % String(技能.get("name", "忍术")))
	_save_local_state()
	return true

func deposit_storage_gold(amount: int) -> bool:
	var actual := clampi(amount, 0, int(player_stats.get("gold", 0)))
	if actual <= 0:
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_storage_store_gold(actual)
	player_stats["gold"] = int(player_stats.gold) - actual
	storage_gold += actual
	player_stats_changed.emit(player_stats.duplicate(true))
	storage_changed.emit(storage.duplicate(true))
	notification_requested.emit("存入 %d 金币" % actual)
	_save_local_state()
	return true

func withdraw_storage_gold(amount: int) -> bool:
	var actual := clampi(amount, 0, storage_gold)
	if actual <= 0:
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_storage_take_gold(actual)
	storage_gold -= actual
	player_stats["gold"] = int(player_stats.get("gold", 0)) + actual
	player_stats_changed.emit(player_stats.duplicate(true))
	storage_changed.emit(storage.duplicate(true))
	notification_requested.emit("取出 %d 金币" % actual)
	_save_local_state()
	return true

func bind_skill_to_slot(skill_id: String, slot: int) -> bool:
	var index := _skill_index(skill_id)
	if index < 0 or slot < 0 or slot >= 10:
		return false
	while skill_slots.size() <= slot:
		skill_slots.append({})
	var skill: Dictionary = learned_skills[index]
	# ⚠️ 判据是原版的 `info.type_attack` / `info.type_attr`，**不是 `damage > 0`** ——
	# 面积类技能的 damage 是负数（倍率），拿它当判据会把 3001003 这类误判成被动。
	if not GAME_DATA.skill_is_active(skill.get("id", "")):
		notification_requested.emit("被动忍术无需绑定快捷栏")
		return false
	for old_slot in skill_slots.size():
		if String(skill_slots[old_slot].get("id", "")) == skill_id:
			skill_slots[old_slot] = {}
	skill_slots[slot] = {
		"id": skill.id,
		"name": skill.name,
		"cooldown": float(skill.get("cooldown", 1.0)),
		"icon": String(skill.get("icon", "")),
	}
	skills_changed.emit(learned_skills.duplicate(true))
	_save_local_state()
	return true

## 取消某个快捷栏位的绑定。原版是把这个格子的值设成 `{"type": KEY_TYPE_NO}`
## （`ShortcutColumnPane.as:664` 的 `hasRepeatData` 分支、`removeSingleData()` 都走这套）——
## 也就是**同一个技能只占一格**那条规则的另一半：拖走/拖到空白处就把原格清空。
func unbind_skill_slot(slot: int) -> bool:
	if slot < 0 or slot >= skill_slots.size() or skill_slots[slot].is_empty():
		return false
	skill_slots[slot] = {}
	skill_cooldowns.erase(slot)
	skills_changed.emit(learned_skills.duplicate(true))
	skill_cooldown_changed.emit(slot, 0.0, 1.0)
	_save_local_state()
	return true

## 服务端任务列表到了（`444` 的 action 3/4）。
##
## ⚠️ 在线时这两个数组**只由服务端写**：帧里只有 id/状态/进度，名字/类型/等级/奖励
##    要拿 id 去 `数据/任务.json` 查 —— 那是任务窗口 `_合并()` 干的活（原版也是两处放）。
static func 合并任务定义(条: Dictionary, 静态: Dictionary) -> Dictionary:
	var 定 := 静态.duplicate(true)
	var 动态: Dictionary = 条.get("dynamic_data", {})
	if 动态.is_empty() or not str((定.get("info", {}) as Dictionary).get("type", "")) in ["daily", "weekly", "banghui", "mixin"]:
		return 定
	var 检: Dictionary = 定.get("check", {})
	检["1"] = 动态.get("check", {})
	定["check"] = 检
	var 奖: Dictionary = 定.get("act", {})
	奖["1"] = 动态.get("act", {})
	定["act"] = 奖
	定["actEx"] = 动态.get("actEx", {})
	var 人: Dictionary = 定.get("npc", {})
	if int(人.get("1", 0)) <= 0:
		人["1"] = int(动态.get("npc", 0))
	定["npc"] = 人
	return 定


func _on_backend_quest_list(accepted: Array, available: Array) -> void:
	accepted_quests.assign(accepted)
	available_quests.assign(available)
	_sync_active_quest()
	quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))


## 单条任务的进度刷新（`444` 的 action 1/2）。帧里是**某一条目标**的 `键+当前+需要`，
## 这里只更新该条的完成标志与原始数据 —— 列表上「（进行中）/（可交）」看的就是它。
##
## ⚠ **以前这里只把原始串塞进 `progress_data`，从来没解成数字** ⇒ 追踪栏那行
##    `击败：X（0/3）` 读的 `progress`/`required` 一直是**接任务那一刻** `444:3` 给的值，
##    杀多少怪都不动（用户 2026-10-10 实机报的"击杀怪物任务面板没有实时更新"）。
##    服务端其实每杀一只就发一条 `444:2`（`fake_flash_server.py:_advance_original_quest`
##    →`_send_original_quest_full_progress`），数字就在帧里，是本客户端没接。
##
## 两种帧的编码**不一样**，别混：
##   `444:2:<id>:<状态>:<类>:<键>&<当前>&<需要>@<键>&<当前>&<需要>:0`   同类的全部目标
##   `444:1:<id>:<序号>:<类>:<键>&<当前>&<需要>`                        单个目标
## 帧只带**它那一类**的目标 ⇒ 与别的类已有值**按键合并**，不能整表替换。
func _on_backend_quest_progress(info: Dictionary) -> void:
	var id := String(info.get("id", ""))
	if id.is_empty():
		return
	if int(info.get("loop_id", 0)) > 0 and _quest_index(accepted_quests, id) < 0:
		accepted_quests.append({"id": id})
	for index in accepted_quests.size():
		if String(accepted_quests[index].get("id", "")) != id:
			continue
		var 条: Dictionary = accepted_quests[index]
		if info.has("dynamic_data"):
			if int(条.get("loop_id", 0)) != int(info.get("loop_id", 0)) or (条.get("dynamic_data", {}) as Dictionary).get("check", {}) != (info["dynamic_data"] as Dictionary).get("check", {}):
				条["目标进度"] = []
			for 键 in ["loop_id", "finish_count", "dynamic_data", "cooldown_deadline", "turn_in_npc"]:
				if info.has(键):
					条[键] = info[键]
		if info.has("status"):
			条["flash_status"] = int(info["status"])
			条["completed"] = int(info["status"]) == 2   # 2 = 可交（`READY_TO_COMPLETE`）
		条["progress_data"] = String(info.get("data", ""))
		var 新目标: Array = _解进度帧(String(info.get("kind", "")), String(info.get("data", "")))
		if not 新目标.is_empty():
			条["目标进度"] = _并目标(条.get("目标进度", []) as Array, 新目标)
			var 当前 := 0
			var 需要 := 0
			for 项 in (条["目标进度"] as Array):
				当前 += int((项 as Dictionary).get("curr", 0))
				需要 += int((项 as Dictionary).get("count", 0))
			条["progress"] = 当前
			条["required"] = 需要
		accepted_quests[index] = 条
		_sync_active_quest()
		quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
		return


## `444:1/2` 的 data → `[{kind,key,curr,count}]`。`-` 与空串都表示"这条帧没有目标数字"。
func _解进度帧(类: String, 数据: String) -> Array:
	var 出: Array = []
	if 数据 == "" or 数据 == "-":
		return 出
	for 项 in 数据.split("@", false):
		var 三段 := String(项).split("&", true)
		if 三段.size() < 3:
			continue
		出.append({"kind": 类, "key": String(三段[0]),
				"curr": int(三段[1]), "count": int(三段[2])})
	return 出


## 按 `<类>:<键>` 合并两摞目标：新的覆盖旧的，旧里没被覆盖的**留着**
## （帧一次只带一种类，整表替换会把别的类清零）。
func _并目标(旧: Array, 新目标: Array) -> Array:
	var 索引 := {}
	var 出: Array = []
	for 项 in 旧:
		var d: Dictionary = 项 as Dictionary
		var k := "%s:%s" % [String(d.get("kind", "")), String(d.get("key", ""))]
		索引[k] = 出.size()
		出.append(d.duplicate(true))
	for 项 in 新目标:
		var d: Dictionary = 项 as Dictionary
		var k := "%s:%s" % [String(d.get("kind", "")), String(d.get("key", ""))]
		if 索引.has(k):
			出[int(索引[k])] = d.duplicate(true)
		else:
			索引[k] = 出.size()
			出.append(d.duplicate(true))
	return 出


func accept_quest(quest_id: String) -> bool:
	var backend := _online_backend()
	if backend != null:
		# 原版 `QuestActionType.START_QUEST = 1`。服务端 `handle_quest_action` 还要求
		# **站在起始 NPC 旁**，所以这里只把意图发出去；成没成看随后回来的任务列表。
		return backend.request_quest(1, int(quest_id))
	for index in available_quests.size():
		if String(available_quests[index].get("id", "")) != quest_id:
			continue
		var quest := available_quests[index].duplicate(true)
		available_quests.remove_at(index)
		accepted_quests.append(quest)
		_sync_active_quest()
		quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
		_save_local_state()
		return true
	return false

func claim_quest_reward(quest_id: String) -> bool:
	var backend := _online_backend()
	if backend != null:
		# 在线时"领奖"= 原版的**交任务**（`COMPLETE_QUEST = 2`）—— 原版没有"在窗口里直接领奖"
		# 这条路，奖励是站在交付 NPC 旁交任务时由服务端发的（`handle_quest_action` 会校验
		# `READY_TO_COMPLETE` 且 `活跃NPC == 该任务的交付NPC`）。发出去不满足条件时服务端不回应，
		# **不会**像离线那样本地加钱加经验。
		return backend.request_quest(2, int(quest_id))
	for index in accepted_quests.size():
		var quest: Dictionary = accepted_quests[index]
		if String(quest.get("id", "")) != quest_id or not bool(quest.get("completed", false)):
			continue
		player_stats["exp"] = int(player_stats.get("exp", 0)) + int(quest.get("reward_exp", 50))
		player_stats["gold"] = int(player_stats.get("gold", 0)) + int(quest.get("reward_gold", 100))
		accepted_quests.remove_at(index)
		if quest_id not in completed_quest_ids:
			completed_quest_ids.append(quest_id)
		_unlock_quest(String(quest.get("next_quest", "")))
		_sync_active_quest()
		_apply_level_ups()
		quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
		notification_requested.emit("已领取任务奖励：%s" % quest.get("name", "任务"))
		_save_local_state()
		return true
	return false


## 放弃任务。原版 `QuestActionType.FORFEIT_QUEST = 3`；服务端把该任务退回 `NOT_STARTED`
## 并重发两份任务列表，所以**在线时不要去动本地数组** —— 列表会由 `444` 推回来。
## 离线则按同一语义把任务退回"可接"。
func forfeit_quest(quest_id: String) -> bool:
	var backend := _online_backend()
	if backend != null:
		return backend.request_quest(3, int(quest_id))
	for index in accepted_quests.size():
		if String(accepted_quests[index].get("id", "")) != quest_id:
			continue
		var quest: Dictionary = accepted_quests[index]
		quest["progress"] = 0
		quest["completed"] = false
		accepted_quests.remove_at(index)
		available_quests.append(quest)
		_sync_active_quest()
		quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
		_save_local_state()
		return true
	return false


func progress_quest(target: String, amount := 1) -> void:
	var changed := false
	for index in accepted_quests.size():
		var quest: Dictionary = accepted_quests[index]
		if String(quest.get("target", "")) != target and not String(quest.get("description", "")).contains(target):
			continue
		quest["progress"] = mini(int(quest.get("required", 1)), int(quest.get("progress", 0)) + amount)
		quest["completed"] = int(quest.progress) >= int(quest.get("required", 1))
		accepted_quests[index] = quest
		changed = true
	if changed:
		_sync_active_quest()
		quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
		_save_local_state()

func set_pet_deployed(pet_id: String, deployed: bool) -> void:
	var backend := _online_backend()
	if backend != null:
		var pet := _pet_by_display_id(pet_id)
		if pet.is_empty():
			return
		var unique_id := int(pet.get("unique_id", 0))
		if deployed:
			backend.request_pet_attack_out(unique_id)
		else:
			backend.request_pet_attack_back(unique_id)
		return
	for index in pets.size():
		var pet: Dictionary = pets[index]
		pet["deployed"] = deployed and String(pet.get("id", "")) == pet_id
		pets[index] = pet
	pets_changed.emit(pets.duplicate(true))
	_recalculate_stats()
	_save_local_state()

func get_deployed_pet() -> Dictionary:
	for pet in pets:
		if bool(pet.get("deployed", false)):
			return pet
	return {}


## 地图上该显示哪一只通灵兽：**出战**优先（会自己打怪），没有出战的取**附身**那只。
## 原版的两种状态都会在地图上生成宠物 actor —— 服务端 `_send_pet_spawn()` 对
## `ATTACHED(0)` 与 `ATTACKING(125)` 都会发 SHOW/ATTACH 帧（`fake_flash_server.py`
## `_pet_spawn_payload`），两者的差别只是控制器：附身 = `FuShenPetController`（跟着主人走、
## 不打怪），出战 = `AttackPetController`（跟着走 + 自动出手）。所以这里两态都要取。
## 地图上该显示哪一只通灵兽：**两态各取一只** —— 出战优先（会自己打怪），附身那只
## 由 `get_attached_pet()` 另外取。原版两种状态都会在地图上生成宠物 actor：
## 服务端 `_send_pet_spawn()` 对 `ATTACHED(0)` 与 `ATTACKING(125)` 都会发 SHOW/ATTACH 帧
## （`fake_flash_server.py` `_pet_spawn_payload`），差别只是控制器：
## 附身 = `FuShenPetController`（跟着主人走、不打怪），出战 = `AttackPetController`（跟走 + 出手）。
## 而且服务端 `_normalize_active_pet_positions()` 允许"一只附身 + 一只出战"同时存在，
## 所以地图实体要按两态各建一个伙伴，不能只认 deployed（以前只认 deployed ⇒ 附身永不显示）。
func get_attached_pet() -> Dictionary:
	for pet in pets:
		if bool(pet.get("attached", false)):
			return pet
	return {}

func set_pet_attached(pet_id: String, attached: bool) -> void:
	var backend := _online_backend()
	if backend != null:
		var pet := _pet_by_display_id(pet_id)
		if pet.is_empty():
			return
		var unique_id := int(pet.get("unique_id", 0))
		if attached:
			backend.request_pet_call_out(unique_id)
		else:
			backend.request_pet_call_back(unique_id)
		return
	for index in pets.size():
		var pet: Dictionary = pets[index]
		pet["attached"] = attached and String(pet.get("id", "")) == pet_id
		pets[index] = pet
	pets_changed.emit(pets.duplicate(true))
	_recalculate_stats()
	_save_local_state()

func rename_pet(pet_id: String, pet_name: String) -> void:
	var backend := _online_backend()
	if backend != null:
		var pet := _pet_by_display_id(pet_id)
		if not pet.is_empty():
			# 原版 requestPetChangeName：≤12 字、服务端回 UPDATE_NAME(11) 帧再落显示
			backend.request_pet_rename(int(pet.get("unique_id", 0)), pet_name)
		return
	for index in pets.size():
		if String(pets[index].get("id", "")) == pet_id:
			var pet: Dictionary = pets[index]
			pet["name"] = pet_name.left(12)
			pets[index] = pet
			pets_changed.emit(pets.duplicate(true))
			_save_local_state()
			return

func release_pet(pet_id: String) -> void:
	var backend := _online_backend()
	if backend != null:
		var pet := _pet_by_display_id(pet_id)
		if not pet.is_empty():
			backend.request_pet_release(int(pet.get("unique_id", 0)))
		return
	for index in pets.size():
		if String(pets[index].get("id", "")) != pet_id:
			continue
		var pet_name := String(pets[index].get("name", "通灵兽"))
		pets.remove_at(index)
		pets_changed.emit(pets.duplicate(true))
		_recalculate_stats()
		notification_requested.emit("已放生 %s" % pet_name)
		_save_local_state()
		return

func feed_pet(pet_id: String) -> bool:
	var backend := _online_backend()
	if backend != null:
		var pet := _pet_by_display_id(pet_id)
		return not pet.is_empty() and backend.request_pet_feed(int(pet.get("unique_id", 0)), 16000014)
	# 离线不再本地自造（原来是 金币 −20、忠诚 +10）。见 `_离线拒绝` 的说明。
	_离线拒绝("喂养宠物")
	return false

func train_pet(pet_id: String) -> bool:
	var backend := _online_backend()
	if backend != null:
		var pet := _pet_by_display_id(pet_id)
		return not pet.is_empty() and backend.request_pet_rewash_aptitude(int(pet.get("unique_id", 0)), 0)
	# 离线不再本地自造（原来是 stage/attack/defense/max_faith 各加若干，并白扣一颗资质丹）。
	_离线拒绝("培养宠物")
	return false

## 背包里的**宠物装备**执行「宠物佩戴」——巡检 #27 逮到的一条发错包。
##
## 原版链：`ItemWindow2.onItemDoubleClick:879-882`（双击）与菜单 `MENU_CHONGWUPEIDAI:757`
## 都汇到 `ItemWindow2.petPutOnEquip:209-219` → `PetHandler.petPutOnEquip`，三跳：
##   ① 目标宠 = 列表里**附身中**的那只（`status == CocoPet.STATUS_SUMMON`；客户端镜像里
##      同一件事是 `attached`，`后端连接.gd:3943`）。没有 ⇒ `FUSHEN_PROMPT_3`（语言表 :1895）；
##   ② `pet.level < item.reqLevel` ⇒ `FUSHEN_PROMPT_4`（:1894）；
##   ③ 是宠物装备才发**宠物专用包** `requestPutOnEquip(uniqueId, 背包格位)`。
## ⚠️ 分流前这条被 `use_inventory_slot` 当成普通装备：`装备部位.位置` 给宠物槽的是**正数 1..5**
##    （`EquipmentPosition.as` 的 `PetA..PetE`），于是走 `request_item_move(0, 格, 1..5, 0)`；
##    而服务端只把 **dst<0** 当装备位（`fake_flash_server.py` 的 `handle_item_move:47534` 里那句
##    `if destination < 0 and not self._can_equip(...)`），正数当**背包格号**
##    ⇒ 点一次「宠物佩戴」= 把兽铠和背包第 N 格**互换**，谁也没穿上。
## 格位 = 1 基绝对格号（稳定格位制，与服务端口径同源），不读 `slot_index` 字段。
func equip_pet_item_from_bag(格位: int) -> bool:
	var item: Dictionary = _占用条(inventory, 格位)
	if item.is_empty():
		return false
	if not 装备部位.是宠物槽(装备部位.位置(String(item.get("id", "")))):
		return false
	var backend := _online_backend()
	if backend == null:
		_离线拒绝("给通灵兽佩戴装备")
		return false
	var 宠 := get_attached_pet()
	if 宠.is_empty():
		notification_requested.emit("没有附身的通灵兽！")
		return false
	if int(宠.get("level", 1)) < int(item.get("req_level", 0)):
		notification_requested.emit("很抱歉，通灵兽的等级不够！")
		return false
	return backend.request_pet_put_equipment(int(宠.get("unique_id", 0)), 格位)

func equip_pet_item(pet_id: String, equipment_slot: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	var pet := _pet_by_display_id(pet_id)
	if pet.is_empty() or equipment_slot < 1 or equipment_slot > 5:
		return false
	var expected_type := 200 + equipment_slot
	for item in inventory:
		var item_id := int(item.get("id", 0))
		if int(item_id / 10000) != expected_type:
			continue
		if int(item.get("req_level", 0)) > int(pet.get("level", 1)):
			continue
		return backend.request_pet_put_equipment(int(pet.get("unique_id", 0)), int(item.get("slot_index", 0)))
	notification_requested.emit("背包中没有该部位可穿戴的宠物装备")
	return false

## 拖拽穿宠物装备：**按拖来的那件物品 id 精确穿**，不"背包里随便找一件同部位的"。
##
## 为什么不复用 `equip_pet_item`（它按 `id/10000 == 200+部位` 找第一件）：
## 玩家背包里有两件不同兽铠时，那个会挑错。人物面板那条路早就按 id 走
## （`equip_item(物品id)`），宠物这条对齐它。
## ⚠️ 服务端 `_put_on_pet_equipment` 收的是**背包格位**，所以这里仍要回查 `slot_index`；
##    不拿拖拽载荷里背包格的"1 基绝对格位"顶替 —— 两者是不是同源没核过（§3.61 病根二）。
func equip_pet_item_by_id(pet_id: String, equipment_slot: int, 物品id: String) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	var pet := _pet_by_display_id(pet_id)
	if pet.is_empty() or equipment_slot < 1 or equipment_slot > 5:
		return false
	var 目标 := int(物品id)
	for item in inventory:
		var item_id := int(item.get("id", 0))
		if item_id != 目标:
			continue
		if item_id / 10000 != 200 + equipment_slot:
			break
		if int(item.get("req_level", 0)) > int(pet.get("level", 1)):
			break
		return backend.request_pet_put_equipment(int(pet.get("unique_id", 0)), int(item.get("slot_index", 0)))
	notification_requested.emit("这件装备不能穿在该部位")
	return false

func take_off_pet_item(pet_id: String, equipment_slot: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	var pet := _pet_by_display_id(pet_id)
	return not pet.is_empty() and backend.request_pet_take_off_equipment(int(pet.get("unique_id", 0)), equipment_slot)

func catch_nearest_pet() -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	var player_position: Vector2 = backend.authoritative_position
	var nearest_id := 0
	var nearest_distance := INF
	for object_id in backend.map_monsters:
		var state: Dictionary = backend.map_monsters[object_id]
		var definition := GAME_DATA.monster(String(state.get("monster_id", "")))
		var info: Dictionary = definition.get("info", {})
		if int(info.get("petLink", 0)) <= 0:
			continue
		var distance := player_position.distance_to(Vector2(float(state.get("x", 0)), float(state.get("y", 0))))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = int(object_id)
	if nearest_id <= 0:
		notification_requested.emit("附近没有可捕捉的通灵兽")
		return false
	return backend.request_pet_catch(nearest_id)

func fuse_pet_soul(pet_id: String, selection := 8) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	var pet := _pet_by_display_id(pet_id)
	return not pet.is_empty() and backend.request_pet_soul_fusion(int(pet.get("unique_id", 0)), selection)

func _migrate_pet_state() -> void:
	for index in pets.size():
		var pet: Dictionary = pets[index]
		if not pet.has("attached"):
			pet["attached"] = false
		# 旧存档的宠物是**自造字段**（attack/defense/stage/faith…），没有潜力四项与资质。
		# 面板/引擎现在按服务端口径读 `potential_real_*` 等，缺了就一路显示 0。
		# 补法用**服务端新捕宠的同一规则**（`_catch_pet`：potential 取模板下限），
		# 不是我们编的数。注意只在字段**缺失**时补，已有值不覆盖。
		if not pet.has("aptitude"):
			pet["aptitude"] = int(pet.get("stage", 1))
		# ⚠️ 老存档**只有显示 id（八位补零串），没有 item_id** —— 而驯养窗三页（进阶/提升/融魂）
		#    全靠 `item_id` 去查模板，缺了就是"消耗 0 / 上限 0 / 已达到最高阶"这种**静默错**。
		#    2026-09-29 提升页截图看出消耗全是 0 才发现。新存档两边都有，只在缺失时补。
		if not pet.has("item_id"):
			pet["item_id"] = int(pet.get("id", 0))
		var 模板: Dictionary = GAME_DATA.pet_template(int(pet.get("item_id", pet.get("id", 101))))
		var 档: Dictionary = (模板.get("info", {}) as Dictionary).get("potential", {}).get("values", {}).get("apt%d" % int(pet.get("aptitude", 1)), {})
		var 下限 := int(档.get("min", 0))
		for 键 in ["potential_real_atk", "potential_real_def", "potential_real_dex", "potential_real_str",
				"potential_total_atk", "potential_total_def", "potential_total_dex", "potential_total_str"]:
			if not pet.has(键):
				pet[键] = 下限
		for 键 in ["savvy", "experience", "ling_zhu", "blessing"]:
			if not pet.has(键):
				pet[键] = 0
		var 技能: Variant = pet.get("skills", null)
		# 旧存档里是**自造的 4 条假技能**（没有 id，新版技能格按 id 查宠物技能表）——
		# 认「没有 id」就把整组换成模板默认技能。
		if not (技能 is Array) or (技能 as Array).is_empty() or (技能 as Array).any(func(s): return s is Dictionary and not (s as Dictionary).has("id")):
			pet["skills"] = _default_pet_skills(pet)
		# 2026-10-29 用户规则：宠物等级不得超过人物等级，到当前上限即不再获取经验。
		# 在线由服务端 `_normalize_pet_levels` 收口；这里管离线档（`玩家数据.json`）。
		宠物数值.收口等级(pet, int(player_stats.get("level", 1)))
		pets[index] = pet

func _pet_by_display_id(pet_id: String) -> Dictionary:
	# ⚠️ 2026-10-17：`unique_id` 从 JSON 进来是 **float**（`910001.0`），而 `String(浮点)` 是
	# **无效调用**（"Invalid call 'String' constructor: 910001.0"）—— 它会让本函数在循环里当场
	# 中断、`set_pet_deployed` / `set_pet_attached` 的在线分支**静默失败**：附身/出战点了没反应、
	# 地图上永远不生成宠物伙伴（用户在实机上报的"附身、出战的宠物都没有显示"就是这条）。
	# 一律 int→str 比，再兼容 "910001.0" 这种显示串。
	var 键 := pet_id.strip_edges()
	if 键.is_empty():
		return {}
	for pet in pets:
		if str(pet.get("id", "")) == 键:
			return pet
		var uid := int(pet.get("unique_id", 0))
		if uid > 0 and str(uid) == 键:
			return pet
		if str(pet.get("unique_id", "")) == 键:
			return pet
	return {}

## 模板默认技能（GameData `Pet` 段 `skills.default`，与服务端 `_catch_pet` 同源）。
## 旧版这里返回**编造的 4 条**（利齿/护主/迅捷/潜能），已删。
func _default_pet_skills(pet: Dictionary) -> Array[Dictionary]:
	var 出: Array[Dictionary] = []
	var 模板: Dictionary = GAME_DATA.pet_template(int(pet.get("item_id", pet.get("id", 101))))
	var 默认: Variant = (模板.get("skills", {}) as Dictionary).get("default", {})
	if 默认 is Dictionary:
		var 键表: Array = (默认 as Dictionary).keys()
		键表.sort_custom(func(a, b): return int(a) < int(b))
		for 键 in 键表:
			var 项: Variant = (默认 as Dictionary)[键]
			if 项 is Dictionary and int((项 as Dictionary).get("skillid", 0)) > 0:
				出.append({"id": int((项 as Dictionary)["skillid"]), "level": 1, "master_level": 0})
	return 出

func add_friend(player_name: String) -> bool:
	var clean := player_name.strip_edges()
	if clean.is_empty() or clean == String(player_stats.get("name", "")):
		return false
	var backend := _online_backend()
	if backend != null:
		# 服务端加好友收的是角色编号，名字要先从同屏玩家解析（见 request_friend_add_by_name）。
		return backend.request_friend_add_by_name(clean)
	for friend in friends:
		if String(friend.get("name", "")) == clean:
			return false
	friends.append({"name": clean, "level": 1, "online": false, "intimacy": 0})
	social_changed.emit()
	_save_local_state()
	return true

func remove_friend(player_name: String) -> void:
	var backend := _online_backend()
	if backend != null:
		backend.request_friend_delete(player_name)
		return
	for index in range(friends.size() - 1, -1, -1):
		if String(friends[index].get("name", "")) == player_name:
			friends.remove_at(index)
	social_changed.emit()
	_save_local_state()

func block_player(player_name: String) -> bool:
	var clean := player_name.strip_edges()
	if clean.is_empty() or clean in blocked_players:
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_friend_block(clean)
	blocked_players.append(clean)
	remove_friend(clean)
	notification_requested.emit("已将 %s 加入黑名单" % clean)
	return true

func unblock_player(player_name: String) -> void:
	var backend := _online_backend()
	if backend != null:
		backend.request_friend_unblock(player_name)
		return
	blocked_players.erase(player_name)
	social_changed.emit()
	_save_local_state()

func create_team() -> void:
	var backend := _online_backend()
	if backend != null:
		backend.request_party_create("%s的小队" % String(player_stats.get("name", "忍者")))
		return
	if team_members.is_empty():
		team_members.append({"name": player_stats.get("name", "忍者"), "level": player_stats.get("level", 1), "leader": true})
	social_changed.emit()
	_save_local_state()

func invite_team_member(player_name: String) -> bool:
	var clean := player_name.strip_edges()
	if clean.is_empty():
		return false
	var backend := _online_backend()
	if backend != null:
		if team_members.is_empty():
			backend.request_party_create("%s的小队" % String(player_stats.get("name", "忍者")))
		return backend.request_party_invite(clean)
	if team_members.is_empty():
		create_team()
	if clean.is_empty() or team_members.size() >= 5:
		return false
	for member in team_members:
		if String(member.get("name", "")) == clean:
			return false
	team_members.append({"name": clean, "level": 1, "leader": false})
	social_changed.emit()
	_save_local_state()
	return true

func leave_team() -> void:
	var backend := _online_backend()
	if backend != null:
		backend.request_party_leave()
		return
	team_members.clear()
	social_changed.emit()
	_save_local_state()

func create_guild(guild_name: String) -> bool:
	var clean := guild_name.strip_edges()
	if clean.length() < 2:
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_guild_create(clean)
	if int(player_stats.get("gold", 0)) < 1000:
		return false
	player_stats["gold"] = int(player_stats.gold) - 1000
	guild = {"joined": true, "name": clean, "level": 1, "contribution": 0, "members": 1}
	player_stats_changed.emit(player_stats.duplicate(true))
	social_changed.emit()
	_save_local_state()
	return true

func leave_guild() -> void:
	var backend := _online_backend()
	if backend != null:
		backend.request_guild_leave()
		return
	guild = {"joined": false, "name": "", "level": 0, "contribution": 0, "members": 0}
	social_changed.emit()
	_save_local_state()

func create_social_request(request_type: String, player_name: String) -> bool:
	var clean := player_name.strip_edges()
	if clean.is_empty():
		return false
	pending_social_requests.append({"type": request_type, "player": clean, "created_at": int(Time.get_unix_time_from_system())})
	notification_requested.emit("已向 %s 发送%s请求" % [clean, request_type])
	social_changed.emit()
	_save_local_state()
	return true

func select_stall_owner(player_name: String) -> void:
	selected_stall_owner = player_name.strip_edges()
	notification_requested.emit("已选择 %s 的摊位" % selected_stall_owner)
	social_changed.emit()
	_save_local_state()

func set_channel(channel: int) -> void:
	current_channel = clampi(channel, 1, 3)
	notification_requested.emit("已切换至 %d 线" % current_channel)
	_save_local_state()

## `用点券` = 购买窗里选中的那枚钱包勾选。原版 `BuyEqpWindow.as:353`
## `shopType = ybCheckBox.selected ? 0 : 1` → `UI.as:1453 requestShopping(shopType, sn, quantity)`
## —— **报文第一个字段就是钱包选择器**（0 元宝 / 1 点券，同 `WaiGuaHandler.as:229/233` 自动买那段），
## 不是货架分类。原来这里把它丢了、恒发 0 ⇒ 勾了点券也按元宝扣。
func buy_shop_item(item_id: String, quantity := 1, 用点券 := false) -> bool:
	for product in shop_catalog:
		if String(product.get("id", "")) != item_id:
			continue
		var backend := _online_backend()
		if backend != null:
			return backend.request_cash_shop_buy(int(product.get("sn", product.get("item_id", item_id))), maxi(1, quantity), 1 if 用点券 else 0)
		return _purchase_product(product, quantity)
	return false

## 商城取货。
##
## ⚠️ 两条口径 2026-09-26 更正（此前都是自造的映射）：
## 1. **分类 id 就是页签下标**。`CashShopWindow2.as:149` `selectedSecondType = tabs.indexOf(页签)`，
##    这个值原样进 `REQUEST_ITEM_LIST.categoryId`（`:570`）→ 432 包第二个字段。
##    以前这里写死 `[-1,1,2,3,4]` 查表，等于只有 5 个分类、且编号跟原版对不上。
##    页签真值见 `数据/界面/商城分页.json`（8 个商品分类 + 1 个「荣誉类」面板页签）。
## 2. **搜索时第一个字段是货架类型（shopType），不是分类 id**。
##    `AllInOneProcessor.as:793` 把 `requestSearchGoods(shopType, name, priceBegin, priceEnd, begin, end)`
##    按这个顺序装包。原版 `selectedShopType` 只会是 0（元宝货架）或 1（礼金货架），
##    而礼金那条分支是死代码（见 商城窗口.tscn 的注释），所以搜索一律发 0。
##
## 页大小 20：原版 `requestData(0, 19)`（`CashShopWindow2.as:159`），翻页时
## `indexEnd = indexBegin + 20` 再按总数夹紧（`PageComponent.currentPage`，`:104-113`）。
func request_cash_shop(tab_index := 0, query := "", include_meta := false, index_begin := 0, index_end := 19) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	cash_shop_loading = true
	server_cash_shop_loaded = true
	shop_catalog.clear()
	social_changed.emit()
	var 关键词 := String(query).strip_edges()
	var 起 := maxi(0, index_begin)
	var 止 := maxi(起, index_end)
	var sent: bool
	if not 关键词.is_empty():
		sent = backend.request_cash_shop_search(关键词, 商城货架_元宝, 起, 止)
	else:
		sent = backend.request_cash_shop_category(tab_index, 起, 止)
	if include_meta:
		_request_cash_shop_metadata_later(backend)
	return sent

## 开商城只补**余额**（1073）那一条。
##
## ⚠️ **这里原来还有一发 `request_cash_shop_capacity()`（发 1084）—— 已删，别再写回来**：
##   1084 **不是"查背包容量"**，它是**「申请扩充背包」这个动作**（原版 `SendOpCodes.CS_REQ_CATEGORY_EXTEND`
##   = `ReceiveOpCodes.CS_UPDT_CATEGORY_CAPACITY` = 1084，收同一个号当"扩充结果推送"）。
##   服务端 `fake_flash_server.py:26118 handle_bag_capacity_extend` ⇒ `_extend_item_capacity(storage=False)`：
##   密卷不够 ⇒ 广播 `扩充背包需要%d个扩充密卷。`；**密卷够 ⇒ 当场扣掉、背包 +30 格并落盘**。
##   所以每进一次商城就等于**替玩家点一次「扩充背包」**——用户 2026-10-21 报的"进商城就提示
##   扩充背包需要 162 个扩充密卷"正是这条（162 = 第 5 页需求，见 `数据/界面/扩容需求.json`）。
##   原版 `CashShopWindow2.initWindow:241-246` 只把 `API.dataCenter.cashMoney/bandMoney` 的
##   **本地缓存**刷上界面，一句容量都不问；容量的正路是进图 `CHAR_INFO` 下发 +
##   玩家真点「确定」那次 1084 回包（`背包窗口._接扩容`）。
func _request_cash_shop_metadata_later(backend: Node) -> void:
	await get_tree().create_timer(0.1).timeout
	if backend != _online_backend():
		return
	backend.request_cash_money()

func buy_npc_item(item_id: String, quantity := 1) -> bool:
	var backend := _online_backend()
	if backend != null:
		return backend.request_npc_shop_buy(int(item_id), maxi(1, quantity))
	for product in get_selected_npc_shop():
		if String(product.get("id", "")) == item_id:
			return _purchase_product(product, quantity)
	return false

func _purchase_product(product: Dictionary, quantity: int) -> bool:
	var count := maxi(1, quantity)
	var total := int(product.get("price", 0)) * count
	var currency := String(product.get("currency", "gold"))
	if int(player_stats.get(currency, 0)) < total:
		notification_requested.emit("货币不足")
		return false
	# 先落货再扣钱：`_add_inventory_item` 满了会拒收（2026-10-01 稳定格位制），
	# 旧顺序是**先扣钱后塞包**，塞不下时钱货两失。
	if not _add_inventory_item(product, count):
		return false
	player_stats[currency] = int(player_stats.get(currency, 0)) - total
	player_stats_changed.emit(player_stats.duplicate(true))
	inventory_changed.emit(inventory.duplicate(true))
	notification_requested.emit("购买成功：%s" % product.get("name", "物品"))
	_save_local_state()
	return true

func update_setting(key: String, value: Variant) -> void:
	game_settings[key] = value
	settings_changed.emit(game_settings.duplicate(true))
	_save_local_state()

func apply_backend_character(payload: Dictionary) -> void:
	服务端同步.应用人物(self, payload)
	var vip_level := int(payload.get("vipLevel", payload.get("vip_level", payload.get("vip", hud_state.vip_level))))
	_on_backend_vip_state(vip_level)

func request_pk_mode(mode: int) -> bool:
	if mode < 1 or mode > 5:
		return false
	var backend := _online_backend()
	if backend != null:
		return backend.request_pk_mode(mode)
	hud_state["pk_mode"] = mode
	hud_state_changed.emit(hud_state.duplicate(true))
	return true

func _on_backend_vip_state(level: int) -> void:
	backend_authoritative = true
	hud_state["vip_level"] = maxi(0, level)
	player_stats["vip"] = int(hud_state.vip_level)
	hud_state_changed.emit(hud_state.duplicate(true))

func _on_backend_pk_mode(updated_character_id: int, mode: int) -> void:
	var backend := get_node_or_null("/root/BackendConnection")
	if backend == null or updated_character_id != int(backend.character_id):
		return
	backend_authoritative = true
	hud_state["pk_mode"] = clampi(mode, 1, 5)
	hud_state_changed.emit(hud_state.duplicate(true))

func _on_backend_weather(weather_type: int) -> void:
	backend_authoritative = true
	hud_state["weather_type"] = weather_type
	hud_state_changed.emit(hud_state.duplicate(true))

## 服务端下发的增益**原样留一份**；HUD 显示的是"它 + 客户端自造的族徽加成"。
## ⚠️ 为什么族徽要客户端自造：原版是服务端 `1815` 动作 **6**（`startFlagBuff`）推下来的
## （→ `SkillHandler.addFlagBuff`），而**本机服务端从不发这个动作**
## （`fake_flash_server` 里 `MAP_FLAG_ACTION` 只发动作 0 和 1）。
var _服务端增益: Array = []
## 1811 系统增益（原版 `SkillHandler.addSysBuff`）：type → 条目。服务端在活动时段发
## `0:<type>:<value>:<剩余秒>:<总秒>`，结束发 `1:<type>`。图标取 `Buff/System/<type>`
## （红封 +「活动」），skillId = 10000000+type（⇒ 图标居中，`BuffCell.as:257-261`）。
var _系统增益 := {}
## 连斩增益（服务端 `1291:2`）与打坐状态（`1288:1`）。两条在**原版 HUD 增益栏里各占一格**：
##   · 连斩：`LianzhanHandler.applyBuff:47-66`，图标/文案取 Buff/Lianzhan，剩余/总秒来自帧；
##   · 打坐：`HealHandler.addBuff:119-136`，单人 `Heal/0`、双修 `Heal/1`，有效期 int.MAX。
## 本机服务端不会为它们发 `GIVE_BUFF`（只发各自业务帧）⇒ 由客户端按帧**自造条目**，
## 与族徽那两条同一口径（见 `族徽加成条目` 的注释）。
var _连斩增益 := {}
var _打坐状态 := -1
## 上一次算进增益栏的罪恶值；只有它变了才重算（罪状格是客户端按阈值判的）。
var _罪状值 := -1


func _on_backend_buffs(buffs: Array) -> void:
	backend_authoritative = true
	_服务端增益 = buffs.duplicate(true)
	刷新增益显示()


func _on_flag_for_emblem(_随便) -> void:
	刷新增益显示()


## 1811 系统增益（`SystemBuffProcessor` → `Client.onSysBuff_showBuff/removeBuff`）：
## 动作 0 上/刷新、1 收掉。名字/说明取 `数据/状态图标.json` 的 `System/<type>` 行
## （Server 端的 value 不参与 HUD 显示，原版 `addSysBuff` 也没用它）。
func _on_backend_system_buff(动作: int, 类型: int, _值: float, 剩余秒: int, 总秒: int) -> void:
	if 动作 == 1 or 剩余秒 <= 0:
		if _系统增益.erase(类型):
			刷新增益显示()
		return
	_系统增益[类型] = {
		"剩余秒": 剩余秒,
		"总秒": maxi(总秒, 剩余秒),
		"到达毫秒": Time.get_ticks_msec(),
	}
	刷新增益显示()


## 系统增益条目（`SkillHandler.addSysBuff:816-841`）：图标 `Buff/System/<type>`、
## skillId = 10000000+type（`SYS_BUFF_BASE_ID`）、时长 = 帧里的秒数。
func _系统增益条目(类型: int) -> Dictionary:
	var 态 := _系统增益.get(类型, {}) as Dictionary
	if 态.is_empty():
		return {}
	var 行 := _状态图标行("System/%d" % 类型)
	if 行.is_empty():
		return {}
	var 剩余 := maxi(0, int(态.get("剩余秒", 0)))
	if 剩余 <= 0:
		return {}
	var 总 := maxi(剩余, int(态.get("总秒", 剩余)))
	return {
		"icon": String(行.get("贴图", "")),
		"name": String(行.get("名称", "")),
		"desc": String(行.get("说明", "")),
		"type": 0,
		"skill_id": 10000000 + 类型,
		"skill_level": 0,
		"remain_time": 剩余,
		"total_time": 总,
		"expires_at_msec": int(态.get("到达毫秒", Time.get_ticks_msec())) + 剩余 * 1000,
		"kind": "system",
	}


## 技能图标路径（`PicTool.getSkillPic` 的等价物）。连斩/打坐那两个格子的图标
## **不是** Buff 数据里那张：`LianzhanHandler:54` 取 `getSkillPic(900000n)`、
## `HealHandler:124` 取 `getSkillPic(9000101/9000102)`。
func _技能图(技能号: int, 兜底: String = "") -> String:
	var 行 := GAME_DATA.skill(技能号)
	var 图 := String(行.get("icon", ""))
	if 图.is_empty():
		return 兜底
	return 图


## `1291:2:<阶段>:<经验加成>:<剩余秒>:<总秒>:<角色号>`（`LianzhanHandler.onLianzhanStage`）。
## 只认自己的那一条；阶段 0 / 剩余 0 就是收掉格子。
func _on_backend_lianzhan_stage(阶段: int, _经验加成: int, 剩余秒: int, 总秒: int, 角色号: int) -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null or 角色号 != int(后端.get("character_id")):
		return
	if 阶段 <= 0 or 剩余秒 <= 0:
		_连斩增益 = {}
	else:
		_连斩增益 = {
			"stage": 阶段, "total": maxi(0, 总秒),
			"expires_at_msec": Time.get_ticks_msec() + 剩余秒 * 1000,
		}
	刷新增益显示()


## `1288:1:<state>:<character_id>:<partner_id>`（`HealHandler`）。
## state: 0 停 / 1 单人 / 2 双修；只认自己那条，否则会拿别人的打坐状态点亮自己的格子。
func _on_player_stats_for_buffs(stats: Dictionary) -> void:
	var 值 := int(stats.get("crime", 0))
	if 值 == _罪状值:
		return
	_罪状值 = 值
	刷新增益显示()


func _on_backend_heal_state(state: Dictionary) -> void:
	if int(state.get("action", 0)) != 1:
		return
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		return
	if int(state.get("character_id", 0)) != int(后端.get("character_id")):
		return
	var 值 := int(state.get("state", 0))
	var 新状态 := 值 if 值 in [1, 2] else -1
	if 新状态 == _打坐状态:
		return
	_打坐状态 = 新状态
	刷新增益显示()


## 家族族徽加成条目（不成条件就返回空字典）。
##
## 条件照原版 `addFlagBuff` 的第一句：`if(param1 != Map.getInstance().data.id) return;`
## ⇒ **只有站在"本族族旗所在的那张图"上才有这条加成**（文案也写着"您附近存在本族的家族旗帜"）。
## 文案取 `增益状态.json` 的 `flag[家徽等级]`，图标 = 家徽图（`PicTool.getJiaHuiPic(style)`）。
func 族徽加成条目() -> Dictionary:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null or not bool(guild.get("joined", false)):
		return {}
	var 旗: Dictionary = 后端.get("authoritative_map_flag") as Dictionary
	if 旗.is_empty() or int(旗.get("bang_id", 0)) != int(guild.get("id", -1)):
		return {}
	var 级 := maxi(1, int(guild.get("level", 1)))
	var 条 := GAME_DATA.族徽增益(级)
	if 条.is_empty():
		return {}
	return {
		"icon": _家徽图路(int(guild.get("flag_style", 0))),
		"name": String(条.get("buffName", "")),
		"desc": String(条.get("buffDesc", "")),
		"type": 0,
		"skill_id": 10000200 + int(旗.get("map_id", 0)) + 级,
		"skill_level": 级,
		"remain_time": 21000000001,
		"total_time": 21000000001,
	}


## 家族**永久**族徽条 —— 原版 `UIMain2.addFamilyFlagBuff`（`UIMain2.as:2747-2770`），
## 由 `Client.onBanghuiFlag`（= `1552:4` 广播，`BanghuiProcessor.as:264` 的 `case 4`）驱动。
## 与上面 `族徽加成条目`（`SkillHandler.addFlagBuff`，服务端 1815 动作 6）是**两条路**：
##   · **这一条：只要在族就有**（原版第一句就是 `if(param1.level > 0)`），
##     **没有"站在旗图"的条件** —— name = 家族名、desc = `getJiaHuiJiaChengString(级)`
##     （属性加成文案，原版结尾写着"（全地图生效）"）、有效期 `60*60*24*365` 秒、
##     `buffPanel.autoRemove = false`（不会自己消失）。
##   · 上面那条：站在本族族旗所在图才有，文案是经验/精华加成。
## 原版两条会**同时**出现在 buffPanel 里（skillId 分别是 0 与 `FLAG_BUFF_BASE_ID+图+级`）。
## ⚠️ 本机服务端只发 1552:4（`_refresh_family_identity`），不走 1815:6 ⇒ 两条都由客户端自造。
func 族徽永久条目() -> Dictionary:
	if not bool(guild.get("joined", false)):
		return {}
	var 纹 := _家徽图路(int(guild.get("flag_style", 0)))
	if 纹.is_empty():
		return {}                     # 没这张样式就宁可不显示（家徽图.gd 同原则）
	var 级 := maxi(1, int(guild.get("level", 1)))
	return {
		"icon": 纹,
		"name": String(guild.get("name", "")),
		"desc": GAME_DATA.家徽加成文案(级),
		"type": 1,                    # TYPE_FAMILY
		"skill_id": 0,                # 原版 addFamilyFlagBuff 写死 0
		"skill_level": 级,
		"remain_time": 31536000,      # 60*60*24*365，照原版
		"total_time": 31536000,
		"family_permanent": true,     # 标记"这是 addFamilyFlagBuff 那条"（原版 TYPE_FAMILY/skillId=0）
	}


func _状态图标行(键: String) -> Dictionary:
	return (GAME_DATA.取表("状态图标").get("表", {}) as Dictionary).get(键, {}) as Dictionary


## 连斩增益格（`LianzhanHandler.applyBuff:46-66`）：
## 文案取 `Buff/Lianzhan/<阶段*100>`，**图标是技能图** `getSkillPic(900000n)`（蓝剑），
## 不是 Buff 行那张刀光（两张 40×40 逐像素全不同）。
func _连斩增益条目() -> Dictionary:
	if _连斩增益.is_empty():
		return {}
	var 阶段 := int(_连斩增益.get("stage", 0))
	var 到期 := int(_连斩增益.get("expires_at_msec", 0))
	var 剩 := maxi(0, ceili(float(到期 - Time.get_ticks_msec()) / 1000.0))
	if 阶段 <= 0 or 剩 <= 0:
		return {}
	var 行 := _状态图标行("Lianzhan/%d" % (阶段 * 100))
	if 行.is_empty():
		return {}
	var 技能号 := 9000000 + 阶段
	return {
		"icon": _技能图(技能号, String(行.get("贴图", ""))),
		"name": String(行.get("名称", "")),
		"desc": String(行.get("说明", "")),
		"type": 0,
		"skill_id": 技能号,
		"skill_level": 阶段,
		"remain_time": 剩,
		"total_time": int(_连斩增益.get("total", 0)),
		"expires_at_msec": 到期,
		"kind": "lianzhan",
	}


## 打坐格（`HealHandler.addBuff:119-136`）：单人 skillId 9000101 / 双修 9000102，
## 图标 `getSkillPic`（与 Buff/Heal/0-1 逐像素同图）；原版有效期 int.MAX。
func _打坐增益条目() -> Dictionary:
	if _打坐状态 not in [1, 2]:
		return {}
	var 行 := _状态图标行("Heal/%d" % (_打坐状态 - 1))
	var 技能号 := 9000100 + _打坐状态
	var 图 := _技能图(技能号, String(行.get("贴图", "")))
	if 图.is_empty():
		return {}
	return {
		"icon": 图,
		"name": String(行.get("名称", "")),
		"desc": String(行.get("说明", "")),
		"type": 0,
		"skill_id": 技能号,
		"skill_level": 0,
		"remain_time": 2100000001,
		"total_time": 2100000001,
		"kind": "heal",
	}


## 罪状格（原版 `PVPHandler.checkAddCrimeBuff:740-800`）：
## 按 `player_stats.crime` 与 Buff/PK 的 `crimeC/B/A/S.begin` 判级（S>A>B>C），
## 图标取 `iconSkillId` 对应技能图（**不是** Buff 行自己的 icon —— 原版四行都没有 icon），
## 有效期 `21000000001`（原版写死的永久值）。
func _罪状增益条目() -> Dictionary:
	var 值 := int(player_stats.get("crime", 0))
	var 表: Dictionary = GAME_DATA.取表("PK状态").get("罪状", {}) as Dictionary
	var 选 := ""
	for 级 in ["S", "A", "B", "C"]:
		var 行 := 表.get(级, {}) as Dictionary
		if 行.is_empty():
			continue
		if 值 >= int(行.get("begin", 0)):
			选 = 级
			break
	if 选.is_empty():
		return {}
	var 行 := 表.get(选, {}) as Dictionary
	var 号 := int(行.get("icon_skill_id", 0))
	return {
		"icon": String(GAME_DATA.skill(号).get("icon", "")),
		"name": String(行.get("name", "")),
		"desc": String(行.get("desc", "")),
		"type": 0,
		"skill_id": 号,
		"skill_level": 0,
		"remain_time": 21000000001,
		"total_time": 21000000001,
		"kind": "crime",
	}


## 断线：服务端增益/连斩/打坐全收掉（族徽那两条仍按会话自己的工会状态重算）。
func 清空服务端增益() -> void:
	_服务端增益.clear()
	_系统增益.clear()
	_连斩增益 = {}
	_打坐状态 = -1
	刷新增益显示()


## 家徽图的资源路径；样式不存在（图没导出）时返回空串。
static func _家徽图路(样式: int) -> String:
	if 样式 <= 0:
		return ""
	var 路 := "%s家徽_%d.png" % ["res://素材/界面/原版窗口/家族/", 样式]
	return 路 if ResourceLoader.exists(路) else ""


func 刷新增益显示() -> void:
	var 列 := _服务端增益.duplicate(true)
	# 1811 系统双倍（原版两个「活动」图标）：按 type 升序，和原版到达序一致（0 先 1 后）。
	var 系统类: Array = _系统增益.keys()
	系统类.sort()
	for 类 in 系统类:
		var 系 := _系统增益条目(int(类))
		if not 系.is_empty():
			列.append(系)
	var 徽 := 族徽加成条目()
	if not 徽.is_empty():
		列.append(徽)
	# 永久族徽条（在族就有，见 `族徽永久条目` 的注释）—— 原版 `addFamilyFlagBuff`
	# 与 `addFlagBuff` 是两条独立的 buff，这里同样并列追加，不互相覆盖。
	var 久 := 族徽永久条目()
	if not 久.is_empty():
		列.append(久)
	# 连斩 / 打坐：原版 HUD 增益栏各占一格，但本机服务端不为它们发 GIVE_BUFF ⇒ 客户端自造。
	var 连 := _连斩增益条目()
	if not 连.is_empty():
		列.append(连)
	var 坐 := _打坐增益条目()
	if not 坐.is_empty():
		列.append(坐)
	var 罪 := _罪状增益条目()
	if not 罪.is_empty():
		列.append(罪)
	# ⚠️ 内容没变就别发信号：这个函数挂在"家族信息同步/地图同步"这些**每帧可能被调**的地方，
	#    无条件 emit 会让 HUD 增益栏一直重画。
	if 列 == (hud_state.get("buffs", []) as Array):
		return
	hud_state["buffs"] = 列
	hud_state_changed.emit(hud_state.duplicate(true))

func apply_backend_skill(skill_id: int, level: int, master_level: int) -> void:
	服务端同步.应用技能(self, skill_id, level, master_level)

func apply_backend_inventory(items: Array, equipment: Dictionary) -> void:
	服务端同步.应用背包(self, items, equipment)

func apply_backend_npc_shop(shop: Dictionary) -> void:
	backend_authoritative = true
	server_npc_shop_loaded = true
	selected_npc_id = str(int(shop.get("npc_id", 0)))
	npc_shop_items.assign((shop.get("items", []) as Array).duplicate(true))
	# ⚠️ `tabs` 要一起收下：原版的页签就是这个数组（见字段声明处的注释）。
	# 服务端没给（神秘商店那条路）时留空，渲染端会退回单组「全部」。
	npc_shop_tabs.assign((shop.get("tabs", []) as Array).duplicate(true))
	npc_shop_changed.emit(shop.duplicate(true))


## 服务端下发的商店分组；权威数据没到时给空数组（调用方自己兜底）。
func get_selected_npc_shop_tabs() -> Array:
	if backend_authoritative and server_npc_shop_loaded:
		return npc_shop_tabs
	return []

## 把"只有件、每件带 slot_index"的清单落成**带洞格位数组**（在线镜像→稳定格位制，
## 见 `_占用条` 那段；`服务端同步.应用背包` 走同一个函数）。
func 落位带洞(入: Array) -> Array[Dictionary]:
	var 出: Array[Dictionary] = []
	for 条 in 入:
		var 副本: Dictionary = (条 as Dictionary).duplicate(true)
		if 副本.is_empty():
			continue
		var 格 := int(副本.get("slot_index", 0))
		if 格 <= 0:
			格 = 出.size() + 1
			副本["slot_index"] = 格
		while 出.size() < 格:
			出.append({})
		出[格 - 1] = 副本
	_trim_尾洞(出)
	return 出

func apply_backend_storage(items: Array, gold: int, capacity: int) -> void:
	backend_authoritative = true
	storage.assign(落位带洞(items))
	storage_gold = gold
	storage_capacity = maxi(0, capacity)
	storage_changed.emit(storage.duplicate(true))

func apply_backend_pets(items: Array, capacity: int) -> void:
	backend_authoritative = true
	pet_capacity = maxi(0, capacity)
	pets.assign(items.duplicate(true))
	pets_changed.emit(pets.duplicate(true))
	_recalculate_stats()

func apply_backend_cash_shop(items: Array, total: int, _source: String) -> void:
	backend_authoritative = true
	server_cash_shop_loaded = true
	cash_shop_loading = false
	cash_shop_total = maxi(0, total)
	shop_catalog.assign(items.duplicate(true))
	social_changed.emit()

func _on_backend_guild_state(state: Dictionary) -> void:
	backend_authoritative = true
	if state.get("guild") is Dictionary:
		guild = (state.get("guild") as Dictionary).duplicate(true)
	if state.get("guilds") is Array:
		guild["guild_list"] = (state.get("guilds") as Array).duplicate(true)
		guild["guild_list_total"] = int(state.get("total", 0))
	if state.get("members") is Array:
		guild["member_list"] = (state.get("members") as Array).duplicate(true)
	# 贡献榜是**另一张表**（`1552:5`，11 字段行），原来是和成员表挤在同一个 `members` 键里
	# ⇒ 后到的帧会把先到的整份顶掉。后端现在分开送：5 → `contributions`、6 → `members`。
	if state.get("contributions") is Array:
		guild["contribution_list"] = (state.get("contributions") as Array).duplicate(true)
	if state.get("boss") is Dictionary:
		guild["boss"] = (state.get("boss") as Dictionary).duplicate(true)
	if int(state.get("action", -1)) == 4:
		guild["flag_name"] = String(state.get("flag_name", guild.get("flag_name", "")))
		guild["level"] = int(state.get("level", guild.get("level", 0)))
		guild["flag_style"] = int(state.get("flag_style", guild.get("flag_style", 0)))
	# `1552:20` 的族贡值 —— 捐完之后服务端补发的那一发（原版 `onGongXianChange`）。
	if state.has("contribution"):
		guild["contribution"] = int(state["contribution"])
	# 捐献结果（`1552:17`，原版 `FamillyManager.onGongXianLingPaiResult`，`FM.as:416-445`）：
	# 四种文案按「是不是金币 × 成没成功」分流。这一帧后端早就解进 state 了
	# （`donation_money`/`donation_ok`），但**没人消费** ⇒ 捐失败时界面一声不响，
	# 玩家以为捐上去了（2026-10-14 家族贡献那轮补上）。
	if state.has("donation_ok"):
		var 是金币 := bool(state.get("donation_money", false))
		var 成了 := bool(state.get("donation_ok", false))
		if 是金币:
			notification_requested.emit("贡献金币成功！" if 成了 else "贡献金币失败！")
		else:
			notification_requested.emit("贡献书籍成功！" if 成了 else "贡献书籍失败！")
	# `action == 4` 会改 level/flag_style ⇒ 家徽加成那条文案得跟着换。
	# （`刷新增益显示()` 自带"内容没变就不发信号"的去重，重复调不会让 HUD 重画）
	刷新增益显示()
	social_changed.emit()

## 好友私聊记录落库（原版 `FriendChatManage.addMsg/addMsgData`）。
## `自己` = 这条是不是我发的；`时` 为 0 时取当前时间。
## 超过 `私聊条数上限` 时按原版裁掉最旧 `私聊裁剪条数` 条（`FriendChatWindow.addMsg:203-206`）。
func 记录好友私聊(自己: bool, 号: int, 名: String, 文: String, 时: int = 0) -> void:
	if 号 <= 0 or 文.is_empty():
		return
	var 键 := str(号)
	var 条: Array = 好友私聊记录.get(键, [])
	条.append({"自己": 自己, "名": 名, "文": 文,
			"时": 时 if 时 > 0 else int(Time.get_unix_time_from_system())})
	if 条.size() > 私聊条数上限:
		条 = 条.slice(私聊裁剪条数)
	好友私聊记录[键] = 条
	好友私聊追加.emit(号)


func 取好友私聊(号: int) -> Array:
	var 条: Variant = 好友私聊记录.get(str(号), [])
	return (条 as Array).duplicate(true) if typeof(条) == TYPE_ARRAY else []


func 清好友私聊(号: int) -> void:
	好友私聊记录.erase(str(号))


## `61:7` 收信也在会话来记账：私聊窗关着时消息不能丢（原版由常驻的 `FriendChatManage` 收）。
## 只在 `type == 4`（私聊档）时记；别人在普通/队伍频道说的话不归这本账。
func _on_backend_chat_for_log(info: Dictionary) -> void:
	if int(info.get("type", 0)) != 4:
		return
	var 号 := int(info.get("character_id", 0))
	if 号 <= 0:
		return
	记录好友私聊(false, 号, String(info.get("name", "")), String(info.get("message", "")))


func _on_backend_friend_state(state: Dictionary) -> void:
	backend_authoritative = true
	if state.get("friends") is Array:
		friends.assign((state.get("friends") as Array).duplicate(true))
	if state.get("enemies") is Array:
		enemies.assign((state.get("enemies") as Array).duplicate(true))
	if state.get("recent") is Array:
		recent_contacts.assign((state.get("recent") as Array).duplicate(true))
	if state.get("blocked") is Array:
		blocked_players.clear()
		blocked_contacts.clear()
		for entry in state.get("blocked") as Array:
			blocked_players.append(String((entry as Dictionary).get("name", "")))
			blocked_contacts.append((entry as Dictionary).duplicate(true))
	if state.get("requests") is Array:
		for index in range(pending_social_requests.size() - 1, -1, -1):
			if String(pending_social_requests[index].get("type", "")) == "friend":
				pending_social_requests.remove_at(index)
		for entry in state.get("requests") as Array:
			var request := (entry as Dictionary).duplicate(true)
			request.merge({"type": "friend", "player": String(request.get("name", ""))}, true)
			pending_social_requests.append(request)
	social_changed.emit()

func _on_backend_party_state(state: Dictionary) -> void:
	backend_authoritative = true
	if state.get("party") is Dictionary:
		var party := state.get("party") as Dictionary
		team_members.assign((party.get("members", []) as Array).duplicate(true))
		for index in range(pending_social_requests.size() - 1, -1, -1):
			if String(pending_social_requests[index].get("type", "")) == "party":
				pending_social_requests.remove_at(index)
		for invite in party.get("invites", []) as Array:
			var request := (invite as Dictionary).duplicate(true)
			request.merge({"type": "party", "player": String(request.get("inviter_name", ""))}, true)
			pending_social_requests.append(request)
	social_changed.emit()

func accept_friend_request(character_id: int) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_friend_accept(character_id)

func reject_friend_request(character_id: int) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_friend_reject(character_id)

func accept_party_invite(party_id: int) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_party_accept(party_id)

## 拒绝组队邀请：转手就交给后端那发**原版形状**（`120:13:<队长名>`，见 `request_party_reject` 的注）。
func reject_party_invite(captain_name: String) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_party_reject(captain_name)

func _on_backend_cultivation(kind: String, state: Dictionary) -> void:
	服务端同步.应用修行(self, kind, state)

## 修行收益（原版的「修行设定与收益」/「领取修行收益」）——服务端 1286 帧。
## seconds=已修行秒数，exp_gain=可领经验，zq_gain=可领查克拉精华。
func _on_backend_biguan_info(seconds: int, exp_gain: int, zq_gain: int) -> void:
	服务端同步.应用修行(self, "修行收益", {
		"seconds": maxi(0, seconds),
		"exp_gain": maxi(0, exp_gain),
		"zq_gain": maxi(0, zq_gain),
	})

func 修行收益状态() -> Dictionary:
	return cultivation_states.get("修行收益", {})

## 首领刷新列表（`WANG_LIST 1351` 回帧）。夹具 `handle_wang_list` 把 11 条
## `wang_boss_entries` 逐条算好 `alive`（当前地图查在场怪、跨图查世界状态、onlyOneChannel 按线路）
## 与 `nextTime`（排期）再下发 ⇒ 这里只存 + 转信号，**不做任何本地判断**（口径归服务端）。
func _on_backend_wang_list(rows: Array) -> void:
	wang_list = rows.duplicate(true)
	wang_list_changed.emit(rows.duplicate(true))

## 请求首领列表（转发 `后端连接.request_wang_list`，空包）。离线返回 false。
func request_wang_list() -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	return backend.request_wang_list()

## 回 Boss 房门确认（转发 `后端连接.request_portal_panel`）。离线没有这一步（本来也没服务端换图）。
func request_portal_panel(request_id: int, accepted: bool) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	return backend.request_portal_panel(request_id, accepted)

## ── 意志（1823）拆帧：cmd ↔ 夹具 `handle_spirit_action` 一族的回帧逐字对齐 ──
## 单件行 = `id:color:slot:exp:level`（cmd2/4）；背包全表行 = `id&color&slot&exp&level`（cmd7）。
static func _spirit_单件(段: Array) -> Dictionary:
	if 段.size() < 5:
		return {}
	return {"id": int(段[0]), "color": String(段[1]), "slot": int(段[2]),
			"exp": int(段[3]), "level": int(段[4])}

static func _spirit_行(串: String) -> Dictionary:
	var 段 := 串.split("&")
	if 段.size() < 5:
		return {}
	return {"id": int(段[0]), "color": String(段[1]), "slot": int(段[2]),
			"exp": int(段[3]), "level": int(段[4])}

## `1572:0:<pve_progress>:<pve_points>`（服务端 `_send_pve_status:30856`）。
## 阅历 = 意志学习/合成的唯一货币（AS3 `YiZhiManager:95-103`）；学习成功后
## 服务端自己会重发 1572，所以这里**只管存**，不在这里推任何窗口。
## ⚠️ 只发 `阅历_变化`（就地刷标签），**不发** `spirit_state_changed`（重建学习页）——
##   理由见信号声明处：那条路会 重建→再请求→再回帧 成环。
func _on_backend_pve_status(进度: int, 点数: int) -> void:
	阅历进度 = 进度
	阅历 = 点数
	阅历_变化.emit(点数)

func _on_backend_spirit_action(命令号: int, 参数: Array) -> void:
	match 命令号:
		0:	# npc 状态：`0:0:<已召唤次数>:<可召唤>:<5×状态@>`（`_send_spirit_npc_status`）
			if 参数.size() >= 4:
				spirit_special_count = int(参数[1])
				spirit_special_enabled = String(参数[2]) == "true"
				spirit_npc_status = String(参数[3]).split("@")
		1:	# 学习窗候选 id 列表（`_send_spirit_panel_items`，空 = "-"）
			var 串 := String(参数[0]) if not 参数.is_empty() else ""
			spirit_panel = []
			if 串 != "" and 串 != "-":
				for s in 串.split("@"):
					spirit_panel.append(int(String(s)))
			_自动升级_面板帧()
		2, 4:	# 加单件/更新单件：同 slot 覆盖、否则按正负入 穿戴/背包
			var 件 := _spirit_单件(参数)
			if not 件.is_empty():
				件置入(件)
		3:	# 移除某 slot
			件移除(int(参数[0]) if not 参数.is_empty() else 0)
			_自动升级_移除帧()
		5:	# 移动：改 slot（源、目标都合法时服务端才发这帧）
			var 全部: Array = spirit_bag.duplicate(true) + spirit_equipped.duplicate(true)
			spirit_bag = []; spirit_equipped = []
			for 件 in 全部:
				if int((件 as Dictionary).get("slot", 0)) == int(参数[0]):
					(件 as Dictionary)["slot"] = int(参数[1])
				分件入表(件 as Dictionary)
		6:	# 上限两格（pack / equip）
			if 参数.size() >= 2:
				spirit_pack_limit = int(参数[0])
				spirit_equip_limit = int(参数[1])
		7:	# 整表覆盖：`true|false` + 行@行（"-" = 空表）
			var 是包 := String(参数[0]) == "true" if not 参数.is_empty() else true
			var 目标: Array = []
			var 串 := String(参数[1]) if 参数.size() >= 2 else "-"
			if 串 != "" and 串 != "-":
				for 行 in 串.split("@"):
					var 件 := _spirit_行(行)
					if not 件.is_empty():
						目标.append(件)
			if 是包:
				spirit_bag = 目标
			else:
				spirit_equipped = 目标
		8:	# 刚拾取清单：`8:<itemid&pos>@...`（`-` = 空；服务端 `_pick_spirit_panel_items:22608-22665`）。
			# 通知性帧（面板/背包数据由紧跟的 cmd1/cmd2 给），但**飞入动画要它**：
			# `playPickYiZhiEffect:115-146` 的起点就是这些格位。
			spirit_picked = []
			var 拾串 := String(参数[0]) if not 参数.is_empty() else ""
			if 拾串 != "" and 拾串 != "-":
				for 拾行 in 拾串.split("@"):
					var 段 := 拾行.split("&")
					if 段.size() >= 2:
						spirit_picked.append({"id": int(段[0]), "pos": int(段[1])})
			# ⚠️ 但**自动升级状态机要用它**：原版 `onSpirit_pickedList` 就是靠这帧 4→5（§3.103）。
			_自动升级_拾取帧()
	spirit_state_changed.emit()

##  cmd2/4 的落表（同 slot 覆盖、否则追加）。
func 件置入(件: Dictionary) -> void:
	var 表: Array = spirit_equipped if int(件.get("slot", 0)) < 0 else spirit_bag
	for i in 表.size():
		if int((表[i] as Dictionary).get("slot", 0)) == int(件.get("slot", -99)):
			表[i] = 件
			return
	表.append(件)

func 件移除(slot: int) -> void:
	for 表 in [spirit_bag, spirit_equipped]:
		for i in 表.size():
			if int((表[i] as Dictionary).get("slot", 0)) == slot:
				表.remove_at(i)
				return

func 分件入表(件: Dictionary) -> void:
	(spirit_equipped if int(件.get("slot", 0)) < 0 else spirit_bag).append(件)

## 意志力（原版 `YiZhiManager.caculateYiZhiLi:168-181` = **穿戴数组 Σ 每件 `rongHeExp`，最后 ÷ 30**）。
## 累加器是 Number、返回类型 `int` ⇒ 截断只发生一次（`int(总/30.0)`，不是逐件除）。
## 服务端从不下发这个数（`grep yiZhiLi 服务端/` 零命中）⇒ 客户端自己算，别去 player_stats 找。
func 意志力() -> int:
	var 总 := 0
	for 件 in spirit_equipped:
		总 += GAME_DATA.意志融经验(件 as Dictionary)
	return int(总 / 30.0)

## 单件对意志力的贡献 —— **唯一实现**在 `游戏数据.意志融经验()`（原版 `YiZhiData.rongHeExp:92-101`）。
## 这里只留一层转接给本页的既有调用点（`意志页回归测试` ④⑥ 直接量这枚函数）；
## ⚠️ 合并 `意志模块` 时这里曾抄出第二份公式，与 `游戏数据` 那份在灰帧上分叉（0 vs 0+exp），
##    已收回单源——公式改动只许发生在 `游戏数据.意志融经验()`。
func 融合经验(件: Dictionary, _档: Dictionary = {}) -> int:
	return GAME_DATA.意志融经验(件 as Dictionary)

## ── 12 个意志动作的语义封装（全走 `request_spirit_action`；离线一律 false，页面给诚实话）──
func _spirit(动作号: int, 参数: Array = []) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	return backend.request_spirit_action(动作号, 参数)

## 阅历状态（服务端 `1572:0`，`_send_pve_status:30856`）：学习页开着时要一次最新值。
## ⚠️ 开面板的 action0 **不顺手回 1572** ⇒ 首帧可能还没到，页面渲染后主动补要一次。
func 请求阅历状态() -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	return backend.request_pve_status()

func spirit_open() -> bool:
	return _spirit(0)
## 点亮特殊导师（召唤，消耗元宝；原版 `requestSpirit_lightSpecial`）
func spirit_summon(i: int) -> bool:
	return _spirit(1, [i])
## 向第 i 位导师学习（得一枚意志；原版 `requestSpirit_gainFromNpc`）
func spirit_gain_from_teacher(i: int) -> bool:
	return _spirit(2, [i])
func spirit_pick(pos: int) -> bool:
	return _spirit(3, [pos])
func spirit_pick_all() -> bool:
	return _spirit(4)
func spirit_sell(pos: int) -> bool:
	return _spirit(5, [pos])
func spirit_sell_all() -> bool:
	return _spirit(6)
func spirit_extend(target: int) -> bool:
	return _spirit(7, [target])
func spirit_merge_all() -> bool:
	return _spirit(8)
func spirit_feed(a: int, b: int) -> bool:
	return _spirit(9, [a, b])
## 格移动：to<0 = 穿戴位 -1..-8（黄不许穿/重名拒/等级不够拒——**全在服务端挡**，客户端不预判）
## ── 自动升级意志（原版 `YiZhiManager.startAutoUpgrade` 那套状态机，2026-10-11 §3.103 欠账②后半）──
## 500ms 定时驱动，状态：
##   0 → `spirit_open()`（动作 0）
##   1 → `spirit_gain_from_teacher(4)`（动作 2）→ 等**面板件帧**（cmd1）
##   2 → 面板件到：件数 ≥10 ⇒ 去 3；否则回 1（连 8 轮不涨 ⇒ 停，「意志商店暂无可学习的意志」）
##   3 → `spirit_pick_all()`（动作 4）→ 等**拾取清单帧**（cmd8）
##   4 → 拾取清单到 ⇒ 去 5
##   5 → 锁定槽那件在不在 / 满级没 / 找第一件可喂的 ⇒ `spirit_feed(目标, 可喂)`（动作 9）→ 6
##   6 → 等**移除帧**（cmd3）⇒ 回 5
## 常量逐条照 `YiZhiManager.as:30-38`；`意志满级 = 20` 同 `MAX_YIZHI_LEVEL:24`，
## 且与 `数据/意志.json` 的 `common.levelUp` 条数（20）吻合。
## ⚠️ 原版 `yiZhiPackDatas` 收的是 **slot > 0**（`:326` 的三元：`slot > 0 ? 背包 : 穿戴`）——
##    升级槽 0 在**穿戴**那侧。我们 `spirit_bag` 是 `slot >= 0`，槽 0 混在里面 ⇒
##    "背包空"那一支必须按 `slot > 0` 数，不能直接 `is_empty()`。
const 自动升级_间隔 := 0.5
const 自动升级_导师 := 4
const 自动升级_空转上限 := 8
const 自动升级_等待上限 := 8
const 自动升级_面板目标 := 10
const 意志满级 := 20

var 自动升级跑着 := false
## 「锁定意志」勾选框的状态（2026-10-24 §3.191）：**跨重渲持续**——自动升级每跳都触发
## 重渲、页面重建会把 CheckBox 打回场景默认未勾 ⇒ 钮跟着变灰（用户实机报「锁定意志在
## 自动升级开始后就没有被勾选了」）。原版 Flash 窗常驻、勾选天然持续，工程必须显式
## 记住并在渲染时回填（`set_pressed_no_signal`）。取消勾且跑着 ⇒ 停（原版
## `onLockCheckBoxClick:656-660`）。
var 自动升级锁定 := false
var 自动升级目标槽 := 0
var 自动升级提示 := ""          ## 停下来时给玩家看的那句（原版走 `addNotice`）
var _自动升级等回帧 := false
var _自动升级状态 := 0
var _自动升级空转 := 0
var _自动升级等待跳 := 0
var _自动升级面板计数 := 0
var _自动升级时钟: Timer = null


func 自动升级_开(槽: int) -> void:
	自动升级_停()
	自动升级目标槽 = 槽
	自动升级跑着 = true
	自动升级提示 = ""
	_自动升级等回帧 = false
	_自动升级状态 = 0
	_自动升级空转 = 0
	_自动升级等待跳 = 0
	_自动升级面板计数 = 0
	if _自动升级时钟 == null:
		_自动升级时钟 = Timer.new()
		_自动升级时钟.one_shot = false
		_自动升级时钟.wait_time = 自动升级_间隔
		_自动升级时钟.timeout.connect(_自动升级_跳)
		add_child(_自动升级时钟)
	# ⚠️⚠️ 2026-10-23 修（用户实机报「点了升级意志没反应」）：**必须 start**。
	#   旧实现只建钟不 start ⇒ 除了本函数末尾那一次同步跳（状态 0→1），之后再无 tick
	#   ⇒ 状态机永远停在 1、画面纹丝不动（用户视角就是"点了没反应"）。
	#   `_续跑` 只在收到回帧时才 start ⇒ 开局第一跳没回帧可等，钟就这么哑了。
	#   原版 `scheduleNextAutoUpgradeTick` 是 `reset() + start()`（`YiZhiManager:684-691`）。
	_自动升级时钟.start()
	_自动升级_跳()                     # 原版 `startAutoUpgrade` 也是先 schedule 再立刻 tick 一次


func 自动升级_停(理由: String = "") -> void:
	自动升级跑着 = false
	_自动升级等回帧 = false
	_自动升级状态 = 0
	if _自动升级时钟 != null:
		_自动升级时钟.stop()
	自动升级提示 = 理由


func _自动升级_跳() -> void:
	if not 自动升级跑着:
		return
	if _自动升级等回帧:
		# 原版 `AUTO_UPGRADE_MAX_WAIT_TICKS = 8` ⇒ 8 跳（≈4 秒）没等到帧就当异常停掉
		_自动升级等待跳 += 1
		if _自动升级等待跳 >= 自动升级_等待上限:
			自动升级_停("自动升级遇到异常，已停止")
			spirit_state_changed.emit()
		return
	match _自动升级状态:
		0:
			spirit_open()
			_自动升级状态 = 1
		1:
			_自动升级等回帧 = true
			_自动升级等待跳 = 0
			spirit_gain_from_teacher(自动升级_导师)
			_自动升级状态 = 2
		3:
			_自动升级面板计数 = 0
			_自动升级等回帧 = true
			_自动升级等待跳 = 0
			spirit_pick_all()
			_自动升级状态 = 4
		5:
			_自动升级_状态5()


## 状态 5：锁定槽那件还在不在 / 满级没 / 找第一件可喂的。逐条照 `onAutoUpgradeTick` 的 case 5。
func _自动升级_状态5() -> void:
	var 目标 := 意志找件(自动升级目标槽)
	if 目标.is_empty():
		自动升级_停("锁定意志不存在，自动升级已停止")
		spirit_state_changed.emit()
		return
	if int(目标.get("level", 0)) >= 意志满级:
		自动升级_停("意志已达满级，自动升级已停止")
		spirit_state_changed.emit()
		return
	var 可喂 := 意志找可喂()
	if not 可喂.is_empty():
		_自动升级等回帧 = true
		_自动升级等待跳 = 0
		spirit_feed(自动升级目标槽, int(可喂.get("slot", 0)))
		_自动升级状态 = 6
		return
	if 意志背包件数() == 0:
		if _自动升级空转 >= 自动升级_空转上限:
			自动升级_停("意志商店暂无可学习的意志，自动升级已停止")
			spirit_state_changed.emit()
		else:
			_自动升级空转 += 1
			_自动升级面板计数 = 0
			_自动升级状态 = 1
		return
	自动升级_停("背包中的意志无法再喂给当前锁定的意志，自动升级已停止")
	spirit_state_changed.emit()


## 某槽那件；没有回空。
func 意志找件(槽: int) -> Dictionary:
	for 表 in [spirit_bag, spirit_equipped]:
		for 件 in 表:
			if typeof(件) == TYPE_DICTIONARY and int((件 as Dictionary).get("slot", -999)) == 槽:
				return 件
	return {}


## 背包里（**slot > 0**）第一件能喂给锁定槽的 —— 唯一的口径条件：**黄不能喂黄**
## （原版 `findFirstFeedableSpirit:687-710`，就这一条 `if`）。
func 意志找可喂() -> Dictionary:
	var 目标 := 意志找件(自动升级目标槽)
	var 目标黄 := int(目标.get("color", 0)) == 意志黄颜色id
	for 件 in spirit_bag:
		if typeof(件) != TYPE_DICTIONARY:
			continue
		var 行 := 件 as Dictionary
		if int(行.get("slot", 0)) <= 0:
			continue
		if 目标黄 and int(行.get("color", 0)) == 意志黄颜色id:
			continue
		return 行
	return {}


func 意志背包件数() -> int:
	var 数 := 0
	for 件 in spirit_bag:
		if typeof(件) == TYPE_DICTIONARY and int((件 as Dictionary).get("slot", 0)) > 0:
			数 += 1
	return 数


## 状态 2 的回帧：面板件数涨没涨。逐条照 `onSpirit_panelItems`（`:118-147`）。
func _自动升级_面板帧() -> void:
	if not (自动升级跑着 and _自动升级状态 == 2 and _自动升级等回帧):
		return
	var 数 := spirit_panel.size()
	_自动升级等回帧 = false
	if 数 <= _自动升级面板计数:
		_自动升级空转 += 1
		if _自动升级空转 >= 自动升级_空转上限:
			自动升级_停("意志商店暂无可学习的意志，自动升级已停止")
			return
	else:
		_自动升级空转 = 0
	_自动升级面板计数 = 数
	_自动升级状态 = 3 if 数 >= 自动升级_面板目标 else 1
	_自动升级_续跑()


## 状态 4 的回帧（拾取清单，cmd8）⇒ 去 5。
func _自动升级_拾取帧() -> void:
	if not (自动升级跑着 and _自动升级状态 == 4 and _自动升级等回帧):
		return
	_自动升级等回帧 = false
	_自动升级状态 = 5
	_自动升级_续跑()


## 状态 6 的回帧（移除某 slot，cmd3）⇒ 回 5。
func _自动升级_移除帧() -> void:
	if not (自动升级跑着 and _自动升级状态 == 6 and _自动升级等回帧):
		return
	_自动升级等回帧 = false
	_自动升级状态 = 5
	_自动升级_续跑()


## `scheduleNextAutoUpgradeTick()` —— 把定时器 reset + start（下一跳在 `间隔` 之后）。
func _自动升级_续跑() -> void:
	if 自动升级跑着 and _自动升级时钟 != null:
		_自动升级时钟.start()


## "黄色"在本协议里是**数字 id**：`SpiritState.color` 是 int，服务端
## `SPIRIT_COLOR_IDS = {gray:1, green:2, blue:3, pueple:4, pink:5, **yellow:6**, red:7, lpink:8}`
## （`fake_flash_server.py:11162`，原文就是这个拼写），而 `_encode_spirit_inventory_item`
## 把 `{item.color}` 直接写进帧 ⇒ 客户端 `_spirit_行` 里 `color` 是 **"6" 这样的数字串**。
const 意志黄颜色id := 6


func spirit_move(from: int, to: int) -> bool:
	return _spirit(10, [from, to])
func spirit_learn_all() -> bool:
	return _spirit(11)

## 1828/0：`<maxEnter>:<tabId&copyId~cnt,copyId~cnt@…>`（`-`=空页集）。
## 页签的"存在性"跟着帧走（原版 `handleAction_enterList` 的 rows 数=页签数），
## 每格「今日 x/y 次」的 x 从 hero_entries 拿；y=hero_max_enter。
func _on_backend_hero_action(命令号: int, 参数: Array) -> void:
	if 命令号 != 0 or 参数.size() < 2:
		return
	hero_max_enter = int(参数[0])
	hero_entries = {}
	var 串 := String(参数[1])
	if 串 != "" and 串 != "-":
		for 页段 in 串.split("@"):
			var 分: PackedStringArray = String(页段).split("&", true, 1)
			if 分.size() < 2:
				continue
			for 项 in String(分[1]).split(","):
				var 对: PackedStringArray = String(项).split("~")
				if 对.size() == 2 and String(对[0]).is_valid_int():
					hero_entries[int(对[0])] = int(对[1])
	hero_state_loaded = true
	hero_state_changed.emit()

## 拉精英列表（离线 false）
func request_hero_info() -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	return backend.request_hero_info()

## 点格进本（原版三道校验在服端：等级/已在副本/今日次数；被拒走系统聊天帧）
func request_hero_enter(copy_id: int) -> bool:
	var backend := _online_backend()
	if backend == null:
		return false
	return backend.request_hero_enter(copy_id)

## 系统消息（左侧活动倒计时列）。服务端 1809:2 帧，每项 {text, seconds}。
## 原版那一列还带一份"距X还有 H: M: S"的实时递减显示，客户端按收到的基准秒数自己走秒。
func _on_backend_huodong_countdowns(rows: Array) -> void:
	活动倒计时.clear()
	var 基准 := Time.get_ticks_msec()
	for 行 in rows:
		if 行 is Dictionary:
			活动倒计时.append({
				"text": String(行.get("text", "")),
				"seconds": maxi(0, int(行.get("seconds", 0))),
				"基准毫秒": 基准,
			})
	活动倒计时_changed.emit(活动倒计时.duplicate(true))

func request_活动倒计时() -> bool:
	var b := _online_backend()
	return b != null and b.request_huodong_countdowns()

func request_修行收益查询() -> bool:
	var b := _online_backend()
	return b != null and b.request_biguan_query()

func request_修行收益领取(use_double: bool) -> bool:
	var b := _online_backend()
	return b != null and b.request_biguan_claim(use_double)

## 限时道具效果（属性药剂 / 双倍符 / 自动补给灵药）。
## ⚠️ 键用后端给的 `effect_key`（kind + itemId/type），**不是 kind**：
##    三种属性药剂、三种双倍符都能同时存在，按 kind 存会互相覆盖图标。
## `remaining_seconds` 是**收到帧那一刻**的剩余秒；HUD 用 `received_at_msec` 自己倒计时。
func apply_backend_item_effect(kind: String, state: Dictionary) -> void:
	backend_authoritative = true
	var key := String(state.get("effect_key", kind))
	if not state.has("remaining_seconds") or int(state.get("remaining_seconds", 0)) <= 0:
		item_effect_states.erase(key)
	else:
		var 存 := state.duplicate(true)
		存["kind"] = kind
		item_effect_states[key] = 存
	item_effect_changed.emit(kind, state.duplicate(true))
	var effects: Array[Dictionary] = []
	for effect_key in item_effect_states:
		var effect := (item_effect_states[effect_key] as Dictionary).duplicate(true)
		if not effect.has("remaining_seconds") or int(effect.get("remaining_seconds", 0)) <= 0:
			continue
		var item_id := int(effect.get("item_id", 0))
		var definition := GAME_DATA.item(item_id)
		effect["name"] = String(definition.get("name", _item_effect_name(String(effect.get("kind", "")))))
		effect["icon"] = String(definition.get("icon", GAME_DATA.item_icon_path(item_id)))
		# 原版 `BuffCell.updateItemToolTip` 的 desc = 道具描述 + 剩余/总时间。
		effect["desc"] = String(definition.get("description", ""))
		effects.append(effect)
	hud_state["effects"] = effects
	hud_state_changed.emit(hud_state.duplicate(true))


## 断线时清掉本局的限时效果（后端 `authoritative_item_effects` 已清，这里同步 HUD）。
func 清空限时效果() -> void:
	if item_effect_states.is_empty() and (hud_state.get("effects", []) as Array).is_empty():
		return
	item_effect_states.clear()
	hud_state["effects"] = []
	hud_state_changed.emit(hud_state.duplicate(true))

func _item_effect_name(kind: String) -> String:
	return String({
		"auto_consume": "自动补给",
		"double_exp": "双倍经验",
		"attribute_boost": "属性增益",
		"stone_merge": "宝石合成增益",
	}.get(kind, "限时状态"))

func _on_backend_copy_state(state: Dictionary) -> void:
	backend_authoritative = true
	var action := int(state.get("action", -1))
	match action:
		0:
			copy_history = (state.get("history", {}) as Dictionary).duplicate(true)
			copy_total_count = maxi(0, int(state.get("total_count", 1)))
		1:
			copy_state["pending_copy_id"] = int(state.get("pending_copy_id", -1))
			copy_state["countdown"] = int(state.get("countdown", 0))
		2, 5:
			copy_state["active_copy_id"] = int(state.get("copy_id", -1))
			copy_state["pending_copy_id"] = -1
			copy_state["started_at"] = int(Time.get_unix_time_from_system()) - int(state.get("pass_time", 0))
		6:
			copy_state["pending_copy_id"] = -1
		8:
			copy_state["completed_copy_id"] = int(state.get("copy_id", -1))
			copy_state["rewards"] = (state.get("rewards", []) as Array).duplicate(true)
			copy_state["active_copy_id"] = -1
			notification_requested.emit("副本挑战完成，奖励等待领取")
		9:
			if bool(state.get("success", false)):
				copy_state["completed_copy_id"] = -1
				copy_state["rewards"] = []
				notification_requested.emit("副本奖励领取成功")
		10:
			copy_state["active_copy_id"] = -1
	copy_state["action"] = action
	copy_changed.emit(copy_state.duplicate(true))

func _on_backend_hang_state(state: Dictionary) -> void:
	backend_authoritative = true
	hang_state = state.duplicate(true)
	_hang_stop_requested = false
	game_settings["auto_combat"] = bool(hang_state.get("active", false))
	settings_changed.emit(game_settings.duplicate(true))
	hang_changed.emit(hang_state.duplicate(true))


## 1283 回帧。服务端把 `CHAR_CONFIG_FIELDS`(45) + keyData(1) + 扩展(13) **按位置**发来，
## `_handle_char_config_text` 已经照同一条键表解成字典 ⇒ 这里只并进 `挂机配置` 再翻译给循环。
## 原版对应的是 `Client.as:7171 onCharConfig` → `GuajiHandler.setConfig()`。
func _on_backend_char_config(配置: Dictionary) -> void:
	for 键名 in 配置:
		挂机配置[键名] = 配置[键名]
	套用挂机配置(挂机配置)
	挂机配置_changed.emit(挂机配置.duplicate(true))


## 把原版字段翻译成自动战斗循环真正读的那几个本地键 ——
## **这一步就是"页面画得像"与"功能真的动"之间缺的那截**：以前这些勾只落
## `user://玩家设置.json`，服务端那份 1283 表从来没被写过、也没被读回来。
##
## ⚠ `auto_battle_range` 的**单位换了**（这是本轮唯一改到既有键语义的地方）：
## 以前当像素用并夹 100~2000；原版那一格是"格"
## （`GuajiHandler.as:557-561`：活动区边长 = 格数 × 50 像素，输入框上限 99 ⇒ 最大 4950），
## 换算系数 25 = 半宽像素/格。默认 20 格 → 半径 500 像素，与旧默认 520 几乎重合，
## 所以老存档不会有肉眼可见的变化；改的是"上限 99 不再是 2000"。
func 套用挂机配置(配置: Dictionary) -> void:
	if 配置.is_empty():
		return
	game_settings["auto_hp"] = bool(配置.get("autoReplyHp", true))
	game_settings["auto_mp"] = bool(配置.get("autoReplyMp", true))
	game_settings["auto_hp_value"] = clampi(int(配置.get("auotReplyHpValue", 70)), 1, 99)
	game_settings["auto_mp_value"] = clampi(int(配置.get("auotReplyMpValue", 50)), 1, 99)
	game_settings["auto_ep"] = bool(配置.get("autoUseEpDrug", false))
	game_settings["auto_rest"] = bool(配置.get("autoDaZuo", true))
	game_settings["auto_pickup"] = bool(配置.get("autoCollect", true))
	game_settings["auto_pick_quest"] = bool(配置.get("isCollectQuestion", true))
	# 原版四枚（任务品/药品/金币/材料/其他）→ 本地两件（消耗品/材料其他）是**合并**的：
	# 药品或金币任一勾上就算"拾取消耗品"，材料或其他任一勾上就算"拾取材料"。
	game_settings["auto_pick_consumables"] = bool(配置.get("isCollectDrug", true)) \
		or bool(配置.get("isCollectMoney", true))
	game_settings["auto_pick_materials"] = bool(配置.get("isCollectCaiLiao", true)) \
		or bool(配置.get("isCollectOthers", true))
	game_settings["auto_avoid_boss"] = bool(配置.get("autoAvoidBoss", false))
	var 招 := int(配置.get("autoSkillId", 0))
	if 招 <= 0:
		招 = 首个可放忍术id()		# 原版下拉默认停在第一项（`addToStageHandler:497`）
	game_settings["auto_skill_id"] = 招
	game_settings["auto_skills"] = 招 > 0
	game_settings["auto_pet_skill_id"] = int(配置.get("autoChongwuSkillId", -1))
	game_settings["auto_battle_range"] = clampi(int(配置.get("autoBattleRange", 20)), 0, 99)
	game_settings["auto_battle_minutes"] = clampi(int(配置.get("autoBattleTime", 240)), 0, 500)
	game_settings["auto_battle_unlimited"] = bool(配置.get("unlimitedAutoBattleTime", false))
	game_settings["auto_revive_in_place"] = bool(配置.get("autoReply", false))
	settings_changed.emit(game_settings.duplicate(true))


## 技能栏里第一个有招式的格 —— 对应原版 `getAttackSkills()` 数组的第 0 项。
func 首个可放忍术id() -> int:
	for 格 in skill_slots.size():
		var 技: Dictionary = get_skill_in_slot(格)
		if not 技.is_empty() and int(技.get("power", 0)) > 0:
			return int(技.get("id", 0))
	return 0


func 后端连接() -> Node:
	return get_node_or_null("/root/BackendConnection")


func request_hang_config_query() -> bool:
	var backend := 后端连接()
	return backend != null and backend.request_hang_config_query()


func request_hang_config_save(配置: Dictionary) -> bool:
	var backend := 后端连接()
	return backend != null and backend.request_hang_config_save(配置)


func request_auto_sell_config(掩码: int, 等级上限: int, 职业序号: int, 品质上限: int) -> bool:
	var backend := 后端连接()
	return backend != null and backend.request_auto_sell_config(掩码, 等级上限, 职业序号, 品质上限)

func request_copy_open(copy_id: int) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_copy_open(copy_id)

func request_copy_confirm(confirmed: bool) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_copy_confirm(confirmed)

func request_copy_reward(copy_id: int) -> bool:
	var backend := _online_backend()
	return backend != null and backend.request_copy_reward(copy_id)

## 那颗「开始 / 停止挂机」按下去就是调这里。⚠ **只翻本地状态 + 广播，一发协议都不发**：
## 原版 1808 的两发都在 `GuajiHandler` 手里（`:696` 开挂后第一拍发 `0`、`:1053` 停的那一刻发 `1`），
## UI 那侧只 `isStart = value`。本工程以前把上行也塞在这里、还只在**在线**那一支发
## —— 而 1808 **整族没有下行**（服务端 `handle_hang_action` 只记一下 `hang_active`，不回帧）⇒
## 在线时 `hang_state.active` 永远是假 ⇒ `挂机托管.在跑` 假 ⇒ 循环每一拍都在 `:660` 那句早退
## （**10-19 之前更糟：那一句在 `玩家._physics_process` 外面挡着，`_托管.拍()` 一次都不调**）⇒
## **线上点开始挂机，人一动不动**。
## 10-18 第一次跑「挂机循环在线腿」才照出来；离线门量不到，因为离线那一支本来就自己写状态。
## 两发上行现在搬去 `挂机托管._上行()`（在线直发后端，离线绕回这里留一份可数的广播）。
func request_hang(active: bool) -> bool:
	var now := int(Time.get_unix_time_from_system())
	if active:
		hang_state = {
			"action": 0,
			"active": true,
			"started_at": now,
			"map_id": int(current_map_id),
			"elapsed_seconds": 0,
		}
	else:
		hang_state["action"] = 1
		hang_state["elapsed_seconds"] = get_hang_elapsed_seconds()
		hang_state["active"] = false
		hang_state["started_at"] = 0
	_hang_stop_requested = false
	game_settings["auto_combat"] = active
	settings_changed.emit(game_settings.duplicate(true))
	hang_changed.emit(hang_state.duplicate(true))
	_save_local_state()
	return true

func get_hang_elapsed_seconds() -> int:
	var elapsed := maxi(0, int(hang_state.get("elapsed_seconds", 0)))
	if bool(hang_state.get("active", false)):
		var started_at := int(hang_state.get("started_at", 0))
		if started_at > 0:
			elapsed += maxi(0, int(Time.get_unix_time_from_system()) - started_at)
	return elapsed

func _update_hang_timeout() -> void:
	if not bool(hang_state.get("active", false)):
		_hang_stop_requested = false
		return
	# 原版「无限制时长」就是**永不自停**（`updateTimeInputState:696` 只把输入框锁掉、不清零，
	# 时长判断在 `GuajiHandler` 里按 `unlimitedAutoBattleTime` 短路）。
	if bool(game_settings.get("auto_battle_unlimited", false)):
		return
	var minutes := clampi(int(game_settings.get("auto_battle_minutes", 240)), 0, 500)
	if minutes <= 0 or get_hang_elapsed_seconds() < minutes * 60 or _hang_stop_requested:
		return
	_hang_stop_requested = true
	if request_hang(false):
		notification_requested.emit("挂机时间已到，正在停止挂机")
	else:
		_hang_stop_requested = false

func apply_backend_map_state(map_id: int, x: int, y: int, hp: int) -> void:
	var map_changed := str(map_id) != current_map_id
	服务端同步.应用地图(self, map_id, hp)
	刷新增益显示()		# 换图 ⇒ "本图有没有本族的旗"变了 ⇒ 族徽加成跟着进出
	if not map_changed:
		return
	# 服务端才是换图的权威：地图号变了就按它给的落点重载地图场景。
	# 原先这里只改 current_map_id 不换场景，于是"服务端换图了、画面还停在旧地图"，
	# 而实体又来自服务端——玩家会看到新地图形状配旧地图的 NPC/怪物。
	pending_server_spawn = Vector2(float(x), float(y))
	pending_portal_name = ""
	_reload_map_scene(str(map_id))


func _reload_map_scene(map_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	# 走带缓存的 `playable_scene`（见 `地图资源.gd` 的注释）：换图时旧场景会被释放，
	# 用 `change_scene_to_file` 回访同一张图要重新读盘 + 重新上传贴图，就是那一下卡顿。
	var packed := MAP_RESOURCES.playable_scene(map_id)
	if packed == null:
		push_error("GameSession: failed to reload map scene: %s" % MAP_RESOURCES.playable_scene_path(map_id))
		return
	var err := tree.change_scene_to_packed(packed)
	if err != OK:
		push_error("GameSession: failed to reload map scene: %s" % error_string(err))

func perform_training() -> void:
	# 离线不再本地发经验（原来是 +20 经验、查克拉回满）。见 `_离线拒绝` 的说明。
	_离线拒绝("修炼")

## ⚠️ `grant_reward()`（本地直接加经验/金币/物品）**已删**。
## 它是"离线本地发奖"的入口，唯一调用者是 `活动服务._grant()`，而后者服务的全是编的奖励数。
## 奖励一律以服务端回包为准（礼包/兑换/福袋/排行/成就/活跃度都有各自的权威通道）。
## 见 §3.29.6。

## 离线**不再本地算**闭关收益。
##
## 原来这里是 `经验 = 分钟 × 2`、`金币 = 分钟` —— 服务端口径是
## `经验 = 分钟 × 等级 × 50`、`精华 = 分钟 × 等级 ÷ 10`（`fake_flash_server.py:17841`），
## 差着一个等级系数，纯属两套数。
## 在线时收益由服务端推 `biguan_info_received`（`request_修行收益查询`），**不走这个函数**。
func get_retreat_rewards() -> Dictionary:
	_离线拒绝("查询闭关收益")
	return {"minutes": 0, "exp": 0, "gold": 0}

func claim_retreat_reward() -> bool:
	# 离线不再本地发奖（同上，且 `功能窗口._claim_retreat` 原来把它当在线请求失败时的兜底）。
	_离线拒绝("领取闭关收益")
	return false

func _inventory_index(item_id: String) -> int:
	return _item_index(inventory, item_id)

## 在 `items` 里按物品 id 找下标。
##
## ⚠️ **必须按数值比，不能按字符串比**：服务端下发的 id 是**整数**（`str(int)` → `"1030013"`），
## 而 `数据/物品.json` 与各处硬写的常量用的是**八位补零**写法（`"01030013"`）。
## 两者 `GAME_DATA.item()` 都查得到（那边两种写法都兜），但字符串相等是假的 ——
## 于是 `equip_item("01030013")` 会静默 `return false`（连提示都没有），
## 2026-09-27 排查"装备穿不上"时就先在这里绕了一圈。
func _item_index(items: Array, item_id: String) -> int:
	var 想找 := item_id.strip_edges()
	for index in items.size():
		if (items[index] as Dictionary).is_empty():
			continue            # 空格占位（见下面"稳定格位制"）
		var 现有 := String(items[index].get("id", ""))
		if 现有 == 想找:
			return index
		# 两种写法都是纯数字时才退化到数值比较；带字母的 id 只认字符串相等。
		if 现有.is_valid_int() and 想找.is_valid_int() and int(现有) == int(想找):
			return index
	return -1


## ═══ 稳定格位制（2026-10-01 背包轮 B，用户报②"使用道具、销毁道具后背包会自动整理"）═══
## 原版背包/仓库是**服务端按格号为键的 map**：中间那摞吃空/销毁，别的件**纹丝不动**。
## 旧的紧凑数组（`remove_at` 整体前移）才会"自动整理"；在线镜像靠 `slot_index` 本来稳定，
## 离线却位移 —— 两端行为不一致的那条正是用户看到的。
## 现在 `inventory`/`storage` 统一：**格号 = 下标+1，空格用 `{}` 原地占位**，
## 判据跟 `equipped_items` 同族（§3.76.2：**判占没占看值，不看长度/has**）。
## 尾随连续空格会被裁掉（`_trim_尾洞`）—— 不影响任何一件的位置，只为省存档。
## 不变量：元素的 `slot_index` 恒等于 下标+1（进出格都走下面这组函数维护）。
const 格容量 := 100        ## 原版 `DataCenter.commonSlots<=0` 的回退值；2026-10-31 起背包 100 格/页

## 格（1 基）上那件；越界/洞 = 空字典。
func _占用条(清单: Array, 格: int) -> Dictionary:
	if 格 < 1 or 格 > 清单.size():
		return {}
	return 清单[格 - 1] as Dictionary

## 已占格数（标题"背包(已用/总)"用它，**不再用 size()**。
func _占用数(清单: Array) -> int:
	var 数 := 0
	for 条 in 清单:
		if not (条 as Dictionary).is_empty():
			数 += 1
	return 数

## 第一个空格（1 基）；-1 = 满。
## ⚠ `上限` **必须传真实格数**（见 `背包总格数()`）：服务端 `bag_capacity` 本机是 90，
## 而 `inventory` 数组只有实际发下来的那些条 ⇒ 按常量 96 扫会把"尾后第 91 格"当成空格，
## 于是判"有空格"、发拾取、服务端按 90 判满而拒 ⇒ **地上的东西一直躺着、只有金币进得来**
## （金币不要格子，见 `挂机托管.该不该捡` 那条 `:501-507`）。2026-09-27 活跃度提示
## "背包空间不足"是同一个病的第一次（那次修的是显示侧 `背包窗口._背包总格数`）。
func _首空格(清单: Array, 上限: int = 格容量) -> int:
	for 格 in range(1, 上限 + 1):
		if _占用条(清单, 格).is_empty():
			return 格
	return -1

## 背包真实格数：服务端权威值 → `player_stats.common_slots` → AS3 兜底 96。
## 与 `背包窗口._背包总格数` 同一条链，两边不许各写一份。
func 背包总格数() -> int:
	var 后: Node = get_node_or_null("/root/BackendConnection")
	if 后 != null and int(后.get("authoritative_bag_capacity")) > 0:
		return int(后.get("authoritative_bag_capacity"))
	var 值 := int(player_stats.get("common_slots", 0))
	return 值 if 值 > 0 else 格容量

## 把 `条`（副本）放进第一个空格，slot_index 同步维护。返回格号；-1 = 满。
func _放进空格(清单: Array[Dictionary], 条: Dictionary, 上限: int = 格容量) -> int:
	var 格 := _首空格(清单, 上限)
	if 格 <= 0:
		return -1
	while 清单.size() < 格:
		清单.append({})
	var 副本: Dictionary = 条.duplicate(true)
	副本["slot_index"] = 格
	清单[格 - 1] = 副本
	return 格

## 清一格（变回空洞）+ 裁尾。格 1 基。
func _清一格(清单: Array[Dictionary], 格: int) -> void:
	if 格 < 1 or 格 > 清单.size():
		return
	清单[格 - 1] = {}
	_trim_尾洞(清单)

func _trim_尾洞(清单: Array) -> void:
	while not 清单.is_empty() and (清单[清单.size() - 1] as Dictionary).is_empty():
		清单.pop_back()

func _quest_index(quests: Array, quest_id: String) -> int:
	for index in quests.size():
		if String(quests[index].get("id", "")) == quest_id:
			return index
	return -1

func _quest_turn_in_npc(quest: Dictionary) -> String:
	## ⚠ 一律 `str()` 不用 `String()`：GDScript 的 `String(...)` **只接 String/StringName**，
	## 任务字典里只要有一枚 npc 键是数字，`String(2)` 就是
	## `Invalid call. Nonexistent 'String' constructor` —— 函数**中途死掉返回 null**，
	## 于是 `npc_quest_status()` 整个不认，头顶与小地图的任务标记一起消失（与 `点角色不崩`
	## 那一类同一个根；2026-10-09 由 小地图标记回归测试 的夹具当场撞出来）。
	## 真数据两边都是补零的串（`离线示例数据.gd` 的 "00000001" 对 `地图实体.gd:647` 的 entity_id），
	## 所以比的是串；数字形状只保证**不崩**，不保证比得上。
	return str(quest.get("turn_in_npc", quest.get("target_npc", quest.get("giver_npc", ""))))

func _unlock_quest(quest_id: String) -> void:
	if quest_id.is_empty() or quest_id in completed_quest_ids:
		return
	if _quest_index(accepted_quests, quest_id) >= 0 or _quest_index(available_quests, quest_id) >= 0:
		return
	var template: Dictionary = quest_chain.get(quest_id, {})
	if not template.is_empty():
		available_quests.append(template.duplicate(true))
		notification_requested.emit("解锁新任务：%s" % template.get("name", "任务"))

func _sync_active_quest() -> void:
	active_quest = {}
	for quest in accepted_quests:
		if String(quest.get("type", "")) == "主线":
			active_quest = quest.duplicate(true)
			break
	quest_changed.emit(active_quest.duplicate(true))

func _migrate_quest_state() -> void:
	for collection in [accepted_quests, available_quests]:
		for index in collection.size():
			var quest: Dictionary = collection[index]
			var template: Dictionary = quest_chain.get(String(quest.get("id", "")), {})
			for key in template:
				if not quest.has(key):
					quest[key] = template[key]
			collection[index] = quest
	_sync_active_quest()

## 叠进同 id 的那摞；不能叠就找空格放。**返回 false = 放不下**（调用方决定回滚/提示）。
func _merge_item(items: Array[Dictionary], item: Dictionary) -> bool:
	var index := _item_index(items, String(item.get("id", "")))
	# 装备**不叠堆**（每件是独立实例，有各自的强化/镶嵌）；判据同 `equip_item` ——
	# 看"是不是装备位"，不看分类名，否则神器/灵器/魂戒会被错误地叠成一堆。
	if index >= 0 and not 装备部位.是装备(String(item.get("id", ""))):
		items[index]["quantity"] = int(items[index].get("quantity", 0)) + int(item.get("quantity", 1))
		return true
	return _放进空格(items, item) > 0

func _skill_index(skill_id: String) -> int:
	for index in learned_skills.size():
		if String(learned_skills[index].get("id", "")) == skill_id:
			return index
	return -1

## 落一件（同摞合并 → 空格）。**返回 false = 背包已满**（通知已发，调用方回滚）。
func _add_inventory_item(product: Dictionary, quantity: int) -> bool:
	var index := _inventory_index(String(product.get("id", "")))
	if index >= 0:
		inventory[index]["quantity"] = int(inventory[index].get("quantity", 0)) + quantity
		return true
	var item := product.duplicate(true)
	item["quantity"] = quantity
	if not String(product.get("slot", "")).is_empty():
		item["category"] = "装备"
	elif String(product.get("category", "")) == "药品":
		item["category"] = "消耗品"
	else:
		item["category"] = "材料"
	# 稳定格位制：进第一个空格（洞也复用）；满了明确拒绝（原版服务端也是先判容量再落货）。
	if _放进空格(inventory, item, 背包总格数()) <= 0:
		notification_requested.emit("背包已满")
		return false
	return true

func _rebuild_skill_slots() -> void:
	var rebuilt: Array[Dictionary] = []
	for _slot in 10:
		rebuilt.append({})
	var assigned := 0
	for slot in range(mini(skill_slots.size(), 10)):
		var old_slot: Dictionary = skill_slots[slot]
		var index := _skill_index(String(old_slot.get("id", "")))
		if index < 0:
			continue
		var skill: Dictionary = learned_skills[index]
		if not GAME_DATA.skill_is_active(skill.get("id", "")):
			continue
		rebuilt[slot] = {"id": skill.id, "name": skill.name, "cooldown": skill.cooldown, "icon": skill.icon,
			"level": int(skill.get("level", 1))}
		assigned += 1
	if assigned == 0:
		var slot := 0
		for skill in learned_skills:
			if GAME_DATA.skill_is_active(skill.get("id", "")) and slot < rebuilt.size():
				rebuilt[slot] = {"id": skill.id, "name": skill.name, "cooldown": skill.cooldown, "icon": skill.icon,
					"level": int(skill.get("level", 1))}
				slot += 1
	skill_slots = rebuilt

func _reset_daily_quests_if_needed() -> void:
	var today := int(Time.get_unix_time_from_system()) / 86400
	if daily_quest_day == today:
		return
	daily_quest_day = today
	completed_quest_ids.erase("2001")
	var accepted_index := _quest_index(accepted_quests, "2001")
	if accepted_index >= 0:
		accepted_quests.remove_at(accepted_index)
	var available_index := _quest_index(available_quests, "2001")
	if available_index >= 0:
		available_quests.remove_at(available_index)
	available_quests.append({
		"id": "2001", "name": "每日修炼", "type": "日常", "request_level": 5,
		"description": "完成一次基础修炼", "progress": 0, "required": 1,
		"completed": false, "reward_exp": 80, "reward_gold": 150, "target": "修炼",
	})
	quests_changed.emit(accepted_quests.duplicate(true), available_quests.duplicate(true))
	_save_local_state()

func _recalculate_stats(emit_change := true) -> void:
	# ⚠️ **在线时一律不重算**。下面那套是**自造的离线公式**（`max_mp = 80 + ap_dex*6 + …`），
	# 它拿旧值把服务端的权威属性整个盖掉，还把当前 hp/mp **夹到那个假上限** ——
	# 实测：服务端 mp=5633，界面上一直是 80/80；max_hp/max_mp/attack/defense 同理。
	# 原版这些值只有一个来源：服务端 `DataCenter.updateByCharWarpInfo` 与 1073 统计包
	# （我们的落地处是 `服务端会话同步.应用人物()`）。在线装备/学技能之后服务端会再推一份，
	# 所以这里跳过不会让数值停在旧值上。
	if backend_authoritative:
		if emit_change:
			player_stats_changed.emit(player_stats.duplicate(true))
		return
	var equipment_attack := 0
	var equipment_defense := 0
	for slot in equipped_items:
		var item: Dictionary = equipped_items[slot]
		equipment_attack += int(item.get("attack", 0))
		equipment_defense += int(item.get("defense", 0))
	var passive_mp := 0
	var passive_attack := 0
	var passive_defense := 0
	for skill in learned_skills:
		match String(skill.get("id", "")):
			"0001001": passive_mp += int(skill.get("level", 1)) * 6
			"0001002": passive_attack += int(skill.get("level", 1)) * 4
			"0001003": passive_defense += int(skill.get("level", 1)) * 3
	var pet_attack := 0
	var pet_defense := 0
	for pet in pets:
		if bool(pet.get("deployed", false)):
			pet_attack += int(pet.get("attack", 0))
			pet_defense += int(pet.get("defense", 0))
	# 族徽属性加成（`数据/家族.json` 的 `flag[级].attr`：maxhp_rate / atk_rate / def_rate，
	# 都是百分比）。口径照服务端 `_family_flag_attr_rates`（`fake_flash_server.py:48091`）
	# + `_apply_independent_percentage_bonuses`：**各百分比先求和、再一次性乘**（不连乘），
	# 结果 `max(1, …)` 保底 1；服务端条件是"在族"，不要求站在旗图。
	# ⚠️ 在线时这些速率**服务端已经算进 player_stats**（`_unscaled_current_max_hp/attack/defence`），
	#    走的是上面的 `backend_authoritative` 早退；这条路只补"服务端没说话"时的离线显示。
	var 旗属性: Dictionary = {}
	if bool(guild.get("joined", false)):
		旗属性 = (GAME_DATA.family_flag_config(int(guild.get("level", 1))).get("attr", {}) as Dictionary)
	var 生命率 := int(旗属性.get("maxhp_rate", 0))
	var 攻率 := int(旗属性.get("atk_rate", 0))
	var 防率 := int(旗属性.get("def_rate", 0))
	player_stats["max_hp"] = maxi(1, roundi((100 + int(player_stats.get("ap_phy", 0)) * 10) * (100 + 生命率) / 100.0))
	player_stats["max_mp"] = 80 + int(player_stats.get("ap_dex", 0)) * 6 + passive_mp
	player_stats["attack"] = maxi(1, roundi((10 + int(player_stats.get("ap_atk", 0)) * 3 + equipment_attack + passive_attack + pet_attack) * (100 + 攻率) / 100.0))
	player_stats["defense"] = maxi(1, roundi((5 + int(player_stats.get("ap_def", 0)) * 2 + equipment_defense + passive_defense + pet_defense) * (100 + 防率) / 100.0))
	player_stats["critical"] = int(player_stats.get("ap_dex", 0))
	player_stats["dodge"] = int(player_stats.get("ap_dex", 0)) / 2
	player_stats["hp"] = mini(int(player_stats.get("hp", 0)), int(player_stats.max_hp))
	player_stats["mp"] = mini(int(player_stats.get("mp", 0)), int(player_stats.max_mp))
	# 经验条的分母：和在线那一路同一个来源（原版 `ExpTable[level]`，见 `服务端会话同步.应用人物`），
	# 别让离线示例数据那个 100 漏出来当分母。
	player_stats["max_exp"] = 等级经验表.本级所需(int(player_stats.get("level", 1)))
	if emit_change:
		player_stats_changed.emit(player_stats.duplicate(true))

func _apply_level_ups() -> void:
	# 分母一律查原版等级经验表（`DataCenter.as:2443` 就是 `ExpTable.getExpNeededForLevel(level)`）。
	# 原来这里写的是 `max_exp *= 1.25` —— 等比递增是**自造**的，原版没有任何一处这么算升级所需，
	# 后果除了和在线那一路对不上以外，还会让"升一级之后条子长短"和底栏差一截。
	while true:
		var 等级 := int(player_stats.get("level", 1))
		var 所需 := 等级经验表.本级所需(等级)
		if 所需 <= 0 or int(player_stats.get("exp", 0)) < 所需:
			break
		player_stats["exp"] = int(player_stats.exp) - 所需
		player_stats["level"] = 等级 + 1
		player_stats["remaining_ap"] = int(player_stats.get("remaining_ap", 0)) + 5
		player_stats["remaining_sp"] = int(player_stats.get("remaining_sp", 0)) + 1
		notification_requested.emit("等级提升至 %d 级" % int(player_stats.level))
	player_stats["max_exp"] = 等级经验表.本级所需(int(player_stats.get("level", 1)))
	_recalculate_stats()

func _save_local_state() -> void:
	if backend_authoritative:
		var settings_file := FileAccess.open("user://玩家设置.json", FileAccess.WRITE)
		if settings_file != null:
			settings_file.store_string(JSON.stringify({"game_settings": game_settings}, "\t", false))
		return
	var state := {
		"player_stats": player_stats,
		"inventory": inventory,
		"storage": storage,
		"equipped_items": equipped_items,
		"learned_skills": learned_skills,
		"skill_slots": skill_slots,
		"accepted_quests": accepted_quests,
		"available_quests": available_quests,
		"completed_quest_ids": completed_quest_ids,
		"daily_quest_day": daily_quest_day,
		"pets": pets,
		"team_members": team_members,
		"friends": friends,
		"blocked_players": blocked_players,
		"pending_social_requests": pending_social_requests,
		"selected_stall_owner": selected_stall_owner,
		"current_channel": current_channel,
		"guild": guild,
		"game_settings": game_settings,
		"last_retreat_claim_unix": last_retreat_claim_unix,
		"storage_gold": storage_gold,
	}
	var file := FileAccess.open("user://玩家数据.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "\t", false))

## 存档里那份数组**像不像"离线背包"**（§3.108）。
##
## 形状判据：`{}` 是"空洞"占位；**离线样例从第 0 格开始**，而**在线形状**
## （`服务端会话同步.gd:97` 的 `落位带洞()`）的件会落在**高格位** —— 实测 28..34。
## 后者被离线端 `assign` 回来，就出现"背包里只看得见末尾两件、消耗品一件都没有"
## （`格子悬停提示回归测试` 就是那么红的）。不收它，让离线样例原样活着。
##
## ⚠️ 顺便记一条查清的事（免得后人重走）：**在线时 `_save_local_state` 根本不写大存档** ——
## 它开头就 `if backend_authoritative: …只写玩家设置.json…; return`。所以这个"高格位"形状
## 不是在线写进来的，而是**某次留下之后被离线端「载入→原样写回」自续下来的**。
static func _像离线背包(表: Variant) -> bool:
	if 表 is not Array or (表 as Array).is_empty():
		return false
	var 首: Variant = (表 as Array)[0]
	return 首 is Dictionary and not (首 as Dictionary).is_empty()


func _load_local_state() -> void:
	var settings_override := {}
	var settings_file := FileAccess.open("user://玩家设置.json", FileAccess.READ)
	if settings_file != null:
		var settings_parsed = JSON.parse_string(settings_file.get_as_text())
		if settings_parsed is Dictionary:
			settings_override = settings_parsed.get("game_settings", {})
	var file := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	if file == null:
		game_settings.merge(settings_override, true)
		_migrate_backend_settings()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		game_settings.merge(settings_override, true)
		_migrate_backend_settings()
		return
	# ⚠️ 2026-10-11 §3.104（欠账⑦）**只回填当前模型里有的键** —— 原来是**无脑
	# `player_stats.merge(存档)`**，于是存档里躺着的旧键会把"代码里已经删掉的字段"重新塞回来。
	# 后果不是数值错，是**判据失真**：任何对 `player_stats` 的断言在"用过的客户端"上
	# **都不可伪证** —— §3.98.4 那次反向对照（把 `crime` 键删掉、门该红而没红）就是这么来的：
	# 删键这一半被存档又补了回去。判据与 `服务端会话同步.应用人物` 取同一条：**键不存在就别收**。
	# （存档仍照旧保存全部键；这里只是**回填时**按当前模型过滤，离线进度不受影响。）
	var 存着的统计: Variant = parsed.get("player_stats", {})
	if typeof(存着的统计) == TYPE_DICTIONARY:
		for 键 in (存着的统计 as Dictionary):
			if player_stats.has(键):
				player_stats[键] = (存着的统计 as Dictionary)[键]
	# ⚠️ 2026-10-11 §3.107（欠账⑦ 的另一半）：`inventory`/`storage` 在**在线**时会被
	# `落位带洞()` 整份换成**按槽位排、空洞是 `{}`** 的数组（`服务端会话同步.gd:97`）。
	# 那个形状**照样被存进存档** ⇒ 下一次（哪怕离线）载入时 `assign` 就把离线样例**整份替换成
	# 一堆空字典** ⇒ **背包看着是空的**（真事：`格子悬停提示回归测试` 报"找不到有物品的格子"，
	# 查下去存档里就是 `[{}, {}, …]` 33 个）。
	# 判据：**存档里一条真货都没有就不收**（保住离线样例）。代价如实说：玩家真把背包清空过，
	# 离线也会看到样例 —— 样例本来就是演示层，比"莫名空包"好。
	if _像离线背包(parsed.get("inventory", [])):
		inventory.assign(parsed["inventory"])
	if _像离线背包(parsed.get("storage", [])):
		storage.assign(parsed["storage"])
	equipped_items.clear()
	for 键 in (parsed.get("equipped_items", {}) as Dictionary):
		var 值 = parsed["equipped_items"][键]
		# 存档里的键恒为字符串（JSON 的锅，见 §3.9.5 第 6 条），存回来才是 int。
		# 2026-09-21 之前存的是中文名，`is_valid_int()` 会挡住 —— 老档里那几件装备**丢就丢了**：
		# 那时候的值本身有错位（灵器/神器/神器附槽三个是错的），迁过来只会把错值固化。
		if not String(键).is_valid_int():
			continue
		equipped_items[int(键)] = (值 as Dictionary).duplicate(true)
	learned_skills.assign(parsed.get("learned_skills", learned_skills))
	skill_slots.assign(parsed.get("skill_slots", []))
	accepted_quests.assign(parsed.get("accepted_quests", accepted_quests))
	available_quests.assign(parsed.get("available_quests", available_quests))
	completed_quest_ids.assign(parsed.get("completed_quest_ids", completed_quest_ids))
	daily_quest_day = int(parsed.get("daily_quest_day", daily_quest_day))
	pets.assign(parsed.get("pets", pets))
	team_members.assign(parsed.get("team_members", team_members))
	friends.assign(parsed.get("friends", friends))
	blocked_players.assign(parsed.get("blocked_players", blocked_players))
	pending_social_requests.assign(parsed.get("pending_social_requests", pending_social_requests))
	selected_stall_owner = String(parsed.get("selected_stall_owner", selected_stall_owner))
	current_channel = int(parsed.get("current_channel", current_channel))
	guild.merge(parsed.get("guild", {}), true)
	刷新增益显示()		# 家徽等级/样式变了 ⇒ 族徽加成那条文案要跟着换
	game_settings.merge(parsed.get("game_settings", {}), true)
	game_settings.merge(settings_override, true)
	_migrate_backend_settings()
	last_retreat_claim_unix = int(parsed.get("last_retreat_claim_unix", 0))
	storage_gold = int(parsed.get("storage_gold", 0))

func _migrate_backend_settings() -> void:
	var host := String(game_settings.get("backend_host", "127.0.0.1")).strip_edges()
	if host in ["", "127.0.0.1", "localhost"] and int(game_settings.get("backend_port", LEGACY_BACKEND_PORT)) == LEGACY_BACKEND_PORT:
		game_settings["backend_host"] = "127.0.0.1"
		game_settings["backend_port"] = PACKAGED_BACKEND_PORT
	var backend_url := String(game_settings.get("backend_url", LEGACY_BACKEND_URL)).strip_edges().trim_suffix("/")
	if backend_url in [LEGACY_BACKEND_URL, LEGACY_BACKEND_ROOT_URL]:
		game_settings["backend_url"] = PACKAGED_BACKEND_URL
	if String(game_settings.get("backend_account", LEGACY_BACKEND_ACCOUNT)).strip_edges() == LEGACY_BACKEND_ACCOUNT:
		game_settings["backend_account"] = PACKAGED_BACKEND_ACCOUNT
		game_settings["backend_password"] = PACKAGED_BACKEND_PASSWORD

## 我自己这具身体该用哪套动画（`face`）与性别 —— **全工程唯一取值口**：
## 在线以服务端角色包为准（`_handle_warp_character_text` 把 `face`/`gender` 折进
## `authoritative_stats`，且 `_apply_stats` 是**先 merge 再 emit** ⇒ 消费者拿得到新值）；
## 离线回落 `player_stats`（`离线示例数据` 没写过这两位 ⇒ 0/0，由 `角色造型` 兜底成男）。
## 谁在用：`玩家.gd`（身体）、`头像面板.gd`（左上角头像）、`功能窗口.gd` 的人物页（立绘）。
func 自身外观() -> Dictionary:
	var backend := _online_backend()
	if backend != null:
		var 权 = backend.get("authoritative_stats")
		if 权 is Dictionary and not (权 as Dictionary).is_empty():
			return {"face": int((权 as Dictionary).get("face", 0)),
					"gender": int((权 as Dictionary).get("gender", 0)),
					"lingFace": int((权 as Dictionary).get("lingFace", 0)),
					"lingQiColor": int((权 as Dictionary).get("lingQiColor", 0))}
	return {"face": int(player_stats.get("face", 0)), "gender": int(player_stats.get("gender", 0)),
			"lingFace": int(player_stats.get("lingFace", 0)),
			"lingQiColor": int(player_stats.get("lingQiColor", 0))}


func _online_backend() -> Node:
	# ⚠️ 无头门在 `SceneTree._initialize` 里直接调会话方法时，GameSession 还没挂进树；
	# 这时对 `/root/...` 绝对路径 `get_node_or_null` 会报
	# "Can't use get_node() with absolute paths from outside the active scene tree"。
	if not is_inside_tree():
		return null
	var backend := get_node_or_null("/root/BackendConnection")
	return backend if backend != null and bool(backend.in_game) else null


## 离线（未进入游戏会话）时，服务端权威的操作一律**拒绝并提示**。
##
## ⚠️ **不要再在这里写"本地兜底公式"** —— 那是把服务端规则手抄一份，只会过期：
##   * 强化那套 `(等级+1)*100` + 100% 成功率，`装备打造表.gd:33-35` 早就写了它是错的；
##   * 签到/福利/挖矿/藏宝/首领/遗址 的奖励数、闭关的 `分钟×2` 经验，全是编的。
##   而 `游戏逻辑回归测试` 又把那套编的钉住了 —— 改服务端规则测试不会红、改离线规则测试反而红，
##   **方向是反的**（§3.29.6 有完整清单）。
##
## ⚠️ 也别以为离线分支"只有测试走得到"：`后端连接._fail_connection()` 把 `in_game` 清成 false
##   **却不换场景** —— 断线后玩家还站在图里，这些分支**真能点到**，点了就本地改状态、服务端不知道。
func _离线拒绝(操作: String) -> void:
	notification_requested.emit("未连接服务器，「%s」不可用" % 操作)

## 在线卸下报文用的"第一个空格"（服务端的格位口径：1..96，`slot_index`）。
## ⚠️ **满了返回 0**，调用方据此拒发（原 `return 96` 的兜底会让报文把 96 格
## 那件当成交换对象 —— 2026-10-01 对照原版入口判满那条改掉的）。
func _first_free_inventory_slot() -> int:
	# 稳定格位制后就是"第一个洞/尾后"；满了回 0 的契约不变
	# （`unequip_item` 在线分支据此拒发报文）。
	#
	# ⚠ 上限必须是**真实格数**，不能吃 `_首空格` 的 96 默认值：玩档背包已扩到 180 格、
	#   前 96 格全满时，按 96 扫会判"满了" ⇒ 卸下/放东西一律弹"背包已满"，
	#   可服务端明明还有 84 个空格（2026-10-25 十拳剑卸不下来的实测根因）。
	return maxi(0, _首空格(inventory, 背包总格数()))

func 部位显示名(位置: int) -> String:
	return 装备部位.显示名(位置)

func request_map_change(target_map_id: String, target_portal_name: String) -> void:
	if target_map_id.is_empty() or target_map_id == "999999999":
		return
	var map_path := MAP_RESOURCES.map_data_path(target_map_id)
	if not FileAccess.file_exists(map_path):
		push_warning("GameSession: target map data missing: " + map_path)
		notification_requested.emit("目标地图数据尚未准备：%s" % target_map_id)
		return

	current_map_id = target_map_id
	pending_portal_name = target_portal_name
	pending_server_spawn = null
	map_changed.emit(current_map_id)
	_reload_map_scene(target_map_id)

func get_requested_spawn(map_id: String) -> Variant:
	# 在线时以服务端给的落点为准（WARP 帧的 x/y）。
	if pending_server_spawn != null and map_id == current_map_id:
		var server_spawn: Variant = pending_server_spawn
		pending_server_spawn = null
		pending_portal_name = ""
		return server_spawn
	if map_id != current_map_id or pending_portal_name.is_empty():
		return null
	var portal_name := pending_portal_name
	pending_portal_name = ""
	var map_path := MAP_RESOURCES.map_data_path(map_id)
	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	if text.begins_with("\ufeff"):
		text = text.substr(1)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var portals = data.get("portal", {})
	for key in portals:
		var portal: Dictionary = portals[key]
		if String(portal.get("pn", "")) == portal_name:
			return Vector2(float(portal.get("x", 0.0)), float(portal.get("y", 0.0)))
	return null

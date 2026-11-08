extends RefCounted

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
const 等级经验表 := preload("res://脚本/单例/等级经验表.gd")

## 已经警告过的「服务端给了、但 `player_stats` 里没有的键」—— **只为去重**。
## ⚠️ 下面那条 `if 会话.player_stats.has(目标字段)` 原来是**静默丢弃**的：
##    服务端发了一个客户端没建模的属性，客户端一声不吭地扔掉 —— 和"攻速/移速恒为 0"
##    是同一个病（那次是 `_handle_stats_text` 的表漏了字段号）。现在会警告一次。
static var _已警告键 := {}

## ⚠️ **不是属性的键，别警告。**
## `应用人物` 的入参**不只是一份属性表** —— `_handle_bridge_character` 把**整个角色包**
## 直接传了进来，里面有身份与外观字段，它们本来就该由别处处理（`character_received` 信号）。
## 不列这份白名单的话，每次进游戏都会刷 9 行无用警告（实测过）—— **又是"检查器喊狼来了"**。
##
## 注意 `crime` **不在**白名单里：它在服务端 `StatType` 里是 33（`fake_flash_server.py:1086`），
## 是**真属性**、只是客户端没建模 —— 那种才该警告。
const 非属性键 := [
	"id", "name", "gender", "face", "hair", "skinColor", "mapId", "charType",
	"lingFace", "lingQiColor",
]

static func 应用人物(会话, 数据: Dictionary) -> void:
	会话.backend_authoritative = true
	var 字段映射 := {
		"maxHp": "max_hp", "maxMp": "max_mp",
		"remainingAp": "remaining_ap", "remainingSp": "remaining_sp",
		"apAtk": "ap_atk", "apDef": "ap_def", "apDex": "ap_dex", "apPhy": "ap_phy",
		"vipLevel": "vip", "vip_level": "vip",
		# 点券。原版 `DataCenter.updateByCharWarpInfo`：`bandMoney = param1.cash_bind`
		# （`DataCenter.as:3151`）—— 和元宝同一个角色包，不是 1073。
		"cashBind": "cash_bind",
		# `crime` 本身同名（不用写），键在 `离线示例数据.player_stats` 里；
		# 下面几个是 2026-10-09 补收的"服务端在发、原版也处理、我们原来静默丢"的字段。
		# ⚠️ 这几条**暂无界面消费者**（原版人物窗也不画），收下是为了不丢数据。
		"moneyBind": "money_bind",
		"anqiTrigger": "anqi_trigger",
		"damageReflect": "damage_reflect", "damageReduce": "damage_reduce", "ignoreDef": "ignore_def",
		"addJobSkillLevel": "add_job_skill_level", "addWorldSkillLevel": "add_world_skill_level",
	}
	var 规范数据 := {}
	for 字段 in 数据:
		var 目标字段 := String(字段映射.get(字段, 字段))
		if 会话.player_stats.has(目标字段):
			规范数据[目标字段] = 数据[字段]
		elif not 非属性键.has(目标字段) and not _已警告键.has(目标字段):
			_已警告键[目标字段] = true
			push_warning("服务端发了属性「%s」，但 `player_stats` 里没有这个键 —— 这条会被静默丢掉。"
				% 目标字段 + "要接的话在 `离线示例数据` 的 player_stats 里补上键名。")
	# ⚠️ 这一句在**收集之后、赋值之前** —— 等于拿**旧值**重算一遍，紧接着又被下面那个赋值循环盖掉。
	#    目前没看出实害（服务端的权威值最后会落进去），但它是"算在错的时机"，属待查，别照它抄。见 §3.31.3。
	会话._recalculate_stats(false)
	for 字段 in 规范数据:
		会话.player_stats[字段] = 规范数据[字段]
	# ⭐ 经验条的**分母**在这一句补上，两根条（底栏 + 人物面板）都读 `player_stats.max_exp`。
	#   原版 `DataCenter.as:2443`（收到 `CocoStatType.EXP` 那一号时）与 `:1462`
	#   （`getDataForCharacterInfoWindow`）两处都现算 `ExpTable.getExpNeededForLevel(stats.level)`
	#   —— 服务端属性包**从来没有**发过"升级所需经验"，客户端不查表就没有分母。
	#   不补的实测后果：`max_exp` 停在离线示例数据那个 100，等级 7 时 exp=300 已经把条顶满、
	#   之后经验再怎么涨都恒为 1.0 ⇒ 玩家看到的正是"经验条不实时跟随经验显示"。
	#   等级用**刚赋完值**的这份（字段号 4 会随属性帧一起到），别用包外的旧值。
	会话.player_stats["max_exp"] = 等级经验表.本级所需(int(会话.player_stats.get("level", 1)))
	if 数据.has("mapId"):
		会话.current_map_id = str(int(数据.mapId))
	会话.player_stats_changed.emit(会话.player_stats.duplicate(true))

## `UPDATE_SKILLS` 的三段就是 `SkillInfo.decode` 的三个 int：**id / skillLevel / masterLevel**
## （`data/skill/SkillInfo.as:35-40`），第三段是**熟练度**，不是等级上限。
## ⚠️ 2026-10-18 修：原来把第三段当"最高等级"塞进 `max_level`，再拿 `level >= max_level`
## 当满级判据 —— 服务端熟练度默认 0 ⇒ 任何忍术一点「提升层数」都弹"该忍术已达到最高等级"。
static func 应用技能(会话, 技能编号: int, 等级: int, 熟练度: int) -> void:
	会话.backend_authoritative = true
	if 技能编号 < 0:
		return
	# ⚠️ 补零到 7 位：协议里是 `int`，"0009029" 收下来变成 9029，直接 `str()` 会**对不上技能表的键**
	# （表键全是 7 位）。见 `游戏数据.skill()` 上那段注释。
	var 编号文本 := str(技能编号).pad_zeros(7)
	# 服务端第一个技能到达 = 权威技能表接管：先把离线示例数据里那两个**编的**技能清掉，
	# 否则 `_rebuild_skill_slots()` 会一直留着它们（见 `server_skills_loaded` 的声明处）。
	if not 会话.server_skills_loaded:
		会话.server_skills_loaded = true
		会话.learned_skills.clear()
	var 序号: int = 会话._skill_index(编号文本)
	if 序号 >= 0:
		会话.learned_skills[序号]["level"] = 等级
		会话.learned_skills[序号]["master_level"] = 熟练度
	else:
		var 定义: Dictionary = 游戏数据.skill(技能编号).duplicate(true)
		定义.merge({
			"id": 编号文本,
			"name": 游戏数据.skill_name(技能编号),
			"level": 等级,
			"master_level": 熟练度,
			"power": int(定义.get("damage", 0)),
			# ⚠️ 这里原来写死 `"icon": ""`，把 `游戏数据.skill()` 刚解析好的图标**盖回空** ——
			# 于是所有**服务端同步来的**技能在技能面板和快捷键栏里都是没有图标的空框。
			# 图标本来就跟着定义走（`skill_icon_path(record)` 读 `icon_class`），不要覆盖。
		}, true)
		会话.learned_skills.append(定义)
	会话._rebuild_skill_slots()
	会话.skills_changed.emit(会话.learned_skills.duplicate(true))

static func 应用背包(会话, 物品: Array, 装备: Dictionary) -> void:
	会话.backend_authoritative = true
	# ⚠️ 不再 `assign` 原始紧凑清单 —— 服务端回包数组是"只含件"的紧凑列表，
	# 直接 assign 会把镜像里的**洞**抹掉：吃空中间一摞后别的件全部前移，
	# 玩家看到的正是"背包自动整理"（2026-10-01 用户报②）。按 slot_index 落洞，
	# 位置和服务端地图一致。
	会话.inventory.assign(会话.落位带洞(物品))
	# 装备字典的键就是**位置 int**（`后端连接.authoritative_equipment` 从协议直接收下来的），
	# 所以"遍历一份自己编的部位名清单去查"这件事本身是多余的 —— 直接收下即可。
	# 原来那份 24 项中文名清单（末 11 项是凭空的顺序）已删，见 `脚本/单例/装备部位.gd` 的说明。
	# ⭐ `equipment_changed` **只在装备表真变了才发**。原来是 `clear()`+重建完**无条件**发一发，
	#   于是**任何**背包 `MODIFY_INVENTORY_ITEM(32)` 子帧 —— 包括手里剑突破**失败**扣的那摞升阶材料 ——
	#   都捎带一发"装备变了"⇒ `功能窗口:493` 把这条接的是**裸 `_refresh_current`**（§3.264 那圈守卫
	#   只包了 player_stats / inventory / cultivation 三条）⇒ `_render_page` 整页重建 ⇒ 挂在屏幕弹窗层的
	#   突破瓶颈弹窗被 `手里剑页._exit_tree` 连坐 free（2026-10-28 用户报修「突破失败不要关面板」；
	#   §3.264 的门当时没红，是因为 F 腿直发会话信号、没走这条真链路 —— 见假绿教训"模拟≠生产帧"）。
	#   两份都是「位置 int → 件体」字典，Godot 4 的 `==` 对 Dictionary/Array **递归比内容**。
	var 装备变了: bool = 会话.equipped_items != 装备
	会话.equipped_items.clear()
	for 位置 in 装备:
		会话.equipped_items[int(位置)] = (装备[位置] as Dictionary).duplicate(true)
	会话.inventory_changed.emit(会话.inventory.duplicate(true))
	if 装备变了:
		会话.equipment_changed.emit(会话.equipped_items.duplicate(true))

static func 应用修行(会话, 类型: String, 状态: Dictionary) -> void:
	会话.backend_authoritative = true
	会话.cultivation_states[类型] = 状态.duplicate(true)
	会话.cultivation_changed.emit(类型, 状态.duplicate(true))

static func 应用地图(会话, 地图编号: int, 生命: int) -> void:
	会话.backend_authoritative = true
	会话.current_map_id = str(地图编号)
	会话.player_stats["hp"] = 生命
	会话.player_stats_changed.emit(会话.player_stats.duplicate(true))

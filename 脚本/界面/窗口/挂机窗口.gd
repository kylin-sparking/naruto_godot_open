extends RefCounted
## 挂机设置页（原版 `com/mxw/uifl/controls/guaji/GuaJiSettingWindow.as`，
## `super(664,492,true)` 在 `:166`，标题「智能托管打怪设置」`:167`）。
##
## ⚠ **这里不摆样式、不摆控件**：84 件全烘在 `场景/界面/窗口/挂机/挂机窗口.tscn`
## （由 `开发工具/生成挂机场景.py` 从 AS3 `createChildren()` 链式重算生成）。
## 本文件只做原版那三件事：`updateView`（`:197-247` 回填）、
## `startGuaJi`（`:501-558` 收集 → 发帧 → 关窗）、`stopGuaJi`（`:735-739` 只停，不发协议、不关窗）。
##
## 三条上行的真值（本机服务端都收）：
##   * `1283` 角色配置：查询 = 载荷 `0`，保存 = 载荷**整个 JSON**（不带 opcode、不带 action 位）。
##     服务端 `handle_char_config`（`fake_flash_server.py:17897`）先 `_strip_timestamp` 再判
##     `payload == "0"`，不是就 `json.loads(payload)` ⇒ 多发一个 `1283:` 头会让查询和保存**都静默失败**。
##     回帧 = 一条 1283（45 值 + keyData + 13 扩展值，按位置、无键名）。
##   * `7779` 自动出售：四个 int，第 1 个是位掩码 `enabled?1|ingredients?2|fragments?4|books?8`
##     （`:551`）。服务端 `handle_auto_sell_config:27093` 存表 + 提前下一轮巡检 +
##     **在聊天栏回一句**「自动出售已开启/已关闭」⇒ 这一下看得见。
##   * `1808` 起/停：`0` 起、`1` 停。**原版没有下行**（`stopGuaJi` 只派发本地事件），
##     服务端 `handle_hang_action:18326` 也只记 `hang_active` ⇒ 挂机状态是本地状态机，
##     等回帧 = 永远红（这条以前就写过一条假的 `"2"` 查询，已删）。
##
## 「自动出售」那 7 个值原版**不进 1283**，走 `LocalStorageInternal` 的 `nyaAutoSell`
## （`:601-622` 读 / `:624-636` 写）⇒ 这里对应 `user://挂机自动出售.json`。

const 页面场景 := preload("res://场景/界面/窗口/挂机/挂机窗口.tscn")
## 取技能名/宠物技能定义用它的 static 查法。**必须 preload 脚本、不许裸写 `GameData`**：
## 本文件全是 `static func`，静态函数里引用自动加载名是**编译时机**坑（10-18 那一轮
## 「页面画得出来但里面是空的」的根因，见 真值/窗口/挂机设置窗.md §⑭）。
const 数据表 := preload("res://脚本/单例/游戏数据.gd")
const 数据路 := "res://数据/界面/挂机窗口_期望.json"
const 本地出售路 := "user://挂机自动出售.json"		# AS3 `LocalStorageInternal.read("nyaAutoSell")`
## MButton3.as:69-74 `_textColors` 四档（up/over/down/disabled）。
const 态字色 := ["#fcf49c", "#ffffc3", "#acadb2", "#939393"]
## 等级下拉的 data 值（`CN.as:6011-6034` 的 `-1,20,40,60,80,100,120`）——
## 拾取等级与出售等级用的是**同一张表**，存进配置的是 data 而不是档位号。
const 等级值 := [-1, 20, 40, 60, 80, 100, 120]

static var _宿主
static var _页: Control
static var _数据: Dictionary = {}
static var _配: Dictionary = {}
static var _技能项: Array = []
static var _宠物技能项: Array = []
static var _连接中: Array[String] = []		# 防重复 connect：同一帧被调两次 渲染 时信号会叠
static var _会话连过 := false
static var _会话 = null


## ⚠ **这里不许裸写 `GameSession`**（autoload 名是编译期解析的，跟运行期有没有这个节点是两件事）。
## 实测：`窗口行为契约体检.gd` 里这条依赖链（门 → `功能窗口` → `系统窗口` → 本文件）编译时报
## `Compile Error: Identifier not found: GameSession` ⇒ 整链编译失败 ⇒ 调 `渲染` 变成
## `Nonexistent function` ⇒ 页面画空（那条门的 E1 红）。同一份代码在 `挂机窗回归测试.gd` 里不报
## ⇒ 坏在**编译时机**，不是版式。工程主流本来就是运行期取节点（`后端连接.gd`、`功能窗口.gd:364`），
## 跟着走就与编译时机无关。返回值故意不标类型：标了 `Node` 之后 `.skill_slots` 这类成员会在编译期被拒。
static func _会():
	if _会话 == null and _宿主 != null:
		_会话 = _宿主.get_node_or_null("/root/GameSession")
	return _会话


## 会话级信号只连**一次**（这两个是常驻连接，页面关掉后由被调方自己判 `_页` 是否还活着）。
## 为什么不连到"开窗/关窗"上：1283 回帧晚到半秒是常态，关窗时把连接断掉就等于"回帧永远不上屏"。
static func _连会话() -> void:
	if _会话连过:
		return
	var 会 = _会()
	if 会 == null:
		return			# 宿主还没进树（量具里先建页后入树）：下次渲染再连，不烧 `_会话连过`
	_会话连过 = true
	会.挂机配置_changed.connect(func(配置: Dictionary): 喂服务端配置(配置))
	会.hang_changed.connect(func(_状: Dictionary): _钮态刷新())
	## ⚠ 这页现在**不靠整页重建**刷新（重建就是「整页点不动」的根因，见 `功能窗口._flush_refresh`）
	## ⇒ 原来被重建顺带刷掉的事必须自己接上：招式候选（等级筛 + 出战宠）、宠物列表。
	## （第三件"VIP 闸"2026-10-25 随报修 5.1/5.2 整族删了，见 `_点自动出售装备` 下面那段注释。）
	会.player_stats_changed.connect(func(_状) -> void: _刷招式候选())
	会.skills_changed.connect(func(_状) -> void: _刷招式候选())
	会.pets_changed.connect(func(_状) -> void: _刷招式候选())


static var _候选指纹: Array = []


static func _刷招式候选() -> void:
	## 只在候选**真的变了**的时候重填那两格下拉：联网时 `player_stats_changed` 每秒几十发，
	## 无脑重填会把用户**正开着的那格下拉**打断（血/蓝/经验帧都会发这个信号）。
	_技能表刷新()
	var 新: Array = [_技能项.duplicate(true), _宠物技能项.duplicate(true)]
	if 新 == _候选指纹:
		return
	_候选指纹 = 新
	_填下拉()


## 件名 → 原版字段名（`GuaJiSettingInfoData.as:6-92`）。
## 注意 `auot*` 两处是**原版打错的拼写**，服务端 `CHAR_CONFIG_FIELDS` 照抄 ⇒ 一个字母都不能"顺手改对"。
const 勾表 := [
	["复选生命阈值", "autoReplyHp"], ["复选查克拉阈值", "autoReplyMp"],
	["复选体力符", "autoUseEpDrug"], ["复选精华符", "autoUseZhenQiDrug"],
	["复选通灵体力符", "autoUseChongWuEpDrug"], ["复选拾取总开关", "autoCollect"],
	["复选拾取任务品", "isCollectQuestion"], ["复选拾取药品", "isCollectDrug"],
	["复选拾取金币", "isCollectMoney"], ["复选拾取材料", "isCollectCaiLiao"],
	["复选拾取其他", "isCollectOthers"], ["复选自动出售装备", "autoSellPickedEquip"],
	["复选天之咒印", "autoWulinEffect"], ["复选地之咒印", "autoZhanYiEffect"],
	["复选掌仙术", "autoZhangXian"], ["复选创造再生", "autoZaiSheng"],
	["复选不离不弃", "autoShouhu"], ["复选自动升级技能", "autoUpgradeSkill"],
	["复选无限时长", "unlimitedAutoBattleTime"], ["复选回城打坐", "autoDaZuo"],
	["复选避开首领", "autoAvoidBoss"], ["复选原地复活", "autoReply"],
	["复选自动出售开", "autoSellEnabled"], ["复选出售食材", "autoSellIngredients"],
	["复选出售残卷", "autoSellFragments"], ["复选出售技能书", "autoSellBooks"],
]
const 档表 := [
	["下拉生命药品", "auotReplyHpType"], ["下拉查克拉药品", "auotReplyMpType"],
	["下拉拾取职业", "collectProfession"], ["下拉拾取等级", "collectLevelType"],
	["下拉拾取品质", "collectQuality"], ["下拉自动忍术", "autoSkillType"],
	["下拉自动宠物忍术", "autoChongWuSkillType"], ["下拉出售等级", "autoSellLevelIndex"],
	["下拉出售职业", "autoSellJobIndex"], ["下拉出售品质", "autoSellQualityIndex"],
]
const 值表 := [
	["输入生命阈值", "auotReplyHpValue"], ["输入查克拉阈值", "auotReplyMpValue"],
	["输入战斗范围", "autoBattleRange"], ["输入战斗时间", "autoBattleTime"],
]
## 「自动续用以下辅助忍术」这枚**没有对应的数据字段**：原版只拿它当五枚的小开关
## （`autoSkillHandler:249-252` / `clickCheckBoxHandler:446-456`），`startGuaJi` 不读它。
## 这里用一条本地键表示"五个全勾"，别当成协议字段发出去。
const 总续用键 := "_本地_五枚全勾"
const 五枚辅助 := ["autoWulinEffect", "autoZhanYiEffect", "autoZhangXian", "autoZaiSheng", "autoShouhu"]
## `GuaJiSettingInfoData.as` 的出厂默认（本机服务端 `default_character_config:2594` 与它逐条一致）。
const 默认 := {
	"autoReplyHp": true, "autoReplyMp": true, "auotReplyHpType": 0, "auotReplyMpType": 0,
	"auotReplyHpValue": 70, "auotReplyMpValue": 50,
	"autoUseEpDrug": false, "autoUseZhenQiDrug": false, "autoUseChongWuEpDrug": false,
	"autoCollect": true, "collectProfession": 0, "collectLevelType": 0, "collectQuality": 0,
	"collectLevel": -1, "isCollectQuestion": true, "isCollectDrug": true, "isCollectMoney": true,
	"isCollectCaiLiao": true, "isCollectOthers": true, "autoSellPickedEquip": false,
	"autoSkillType": 0, "autoSkillId": 0, "autoChongWuSkillType": 0, "autoChongwuSkillId": 101,
	"autoWulinEffect": true, "autoZhanYiEffect": true, "autoZhangXian": true,
	"autoZaiSheng": true, "autoShouhu": true, "autoUpgradeSkill": false,
	"autoBattleRange": 20, "autoBattleTime": 240, "unlimitedAutoBattleTime": false,
	"autoDaZuo": true, "autoAvoidBoss": false, "autoReply": false, "autoChongWuEat": true,
	"autoSellEnabled": false, "autoSellIngredients": false, "autoSellFragments": false,
	"autoSellBooks": false, "autoSellMaxLevel": 0, "autoSellJobIndex": 0, "autoSellMaxQuality": 0,
	"autoSellLevelIndex": 0, "autoSellQualityIndex": 0,
	总续用键: false,
}
## 1283 保存要发的键。最后三个（`autoSellPickedEquip / autoUpgradeSkill / unlimitedAutoBattleTime`）
## 不在服务端 `CHAR_CONFIG_FIELDS` 里 ⇒ **发了会被丢掉、回帧里也没有**（原版那三样本来也只存本地），
## 这里照 `CharacterConfig.as:211` 的快照一起发，是"记录"，不是"指望它回来"。
const 存字段 := [
	"autoReplyHp", "autoReplyMp", "auotReplyHpType", "auotReplyHpValue", "auotReplyMpType",
	"auotReplyMpValue", "autoUseEpDrug", "autoUseZhenQiDrug", "autoUseChongWuEpDrug",
	"autoCollect", "collectProfession", "collectLevelType", "collectQuality", "collectLevel",
	"isCollectQuestion", "isCollectDrug", "isCollectMoney", "isCollectCaiLiao", "isCollectOthers",
	"autoSkillType", "autoSkillId", "autoChongWuSkillType", "autoChongwuSkillId",
	"autoWulinEffect", "autoZhanYiEffect", "autoZhangXian", "autoZaiSheng", "autoShouhu",
	"autoUpgradeSkill", "autoBattleRange", "autoBattleTime", "unlimitedAutoBattleTime",
	"autoDaZuo", "autoAvoidBoss", "autoReply", "autoChongWuEat",
]


static func 渲染(宿主) -> void:
	_宿主 = 宿主
	_页 = 宿主._instantiate_page(页面场景)
	## 告诉宿主：**这页自己原地刷，别在数据帧来的时候把它拆掉重建**。
	## 重建的后果不是"闪一下"，是这页**什么都点不动** —— `BaseButton` 要按下与抬起落在同一个
	## 节点才发 `pressed`，而联网后状态帧每秒几十发、每发都排一次重建（用户 2026-10-19 实机报，
	## 取证与判据见 `开发工具/量挂机页命中.gd`）。键名必须 ASCII：Godot 4 的 metadata 键
	## 不接受中文标识符，写错了是**静默存不进去**（这条坑本工程踩过）。
	_页.set_meta("page_self_refresh", true)
	_连会话()
	if _数据.is_empty():
		读数据表()
	_候选指纹 = []		# 新建的页里两格下拉是空的 ⇒ 这一轮必须真填一次
	_刷招式候选()
	_接控件()
	_配 = _本地出售读()
	_填控件()
	_回算总续用()
	_更新时间输入()
	_钮态刷新()
	_请配置()


static func 读数据表() -> void:
	var f := FileAccess.open(数据路, FileAccess.READ)
	if f == null:
		push_error("读不到 %s ⇒ 下拉会是空的。先跑 开发工具/生成挂机场景.py" % 数据路)
		_数据 = {}
		return
	var 解: Variant = JSON.parse_string(f.get_as_text())
	_数据 = 解 if typeof(解) == TYPE_DICTIONARY else {}


## 原版 `addToStageHandler:492-493`：进舞台才 `getSkills()` / `getPetSkills()` 填那两个下拉。
##
## ⚠ 「人物自动使用」的候选**不是技能栏装了哪几招**（我第一版就是这么写的，被打回）：
## `DataCenter.getAttackSkills():1501-1546` 是一张**按职业写死的候选表**过一遍等级筛，
## 而且 `_loc2_ = [0]`（:1541）先塞了技能号 `0` = 普通攻击、这一条**不过筛恒在**。
## 名字一律走 `GameData.skill()`（= 原版 `StringTool.getSkillString:114-118`，
## 同一张 7 位补零的 `Skill` 表），不许再拿技能栏里的占位名。
const 招式候选 := {
	100: [1001001, 1001002, 1001003],		# Job100.Attack1~3（火遁流）
	200: [2001001, 2001002, 2001003],		# Job200（水遁流）
	300: [3001001, 3001002, 3001003],		# Job300（雷遁流）
	400: [4001001, 4001002, 4001003],		# Job400（风遁流）
	## `switch` 里**没有** NINJA_EARTH=500 这一档 ⇒ 土遁流只有下面 11 条通用招可挑。
}
## `Job0.Debuff1~5`(2000~2004) + `FamilyAcv1~4`(3110/3120/3130/3140) + 月读/天照(3204/3205)。
const 通用招式 := [2000, 2001, 2002, 2003, 2004, 3110, 3120, 3130, 3140, 3204, 3205]


## 原版 `DataCenter.getSkillLevel(id)`：在线以服务端 39/40 帧那张表为准，离线回落到本地已学表。
static func _技能等级(号: int) -> int:
	var 会 = _会()
	if 会 == null:
		return 0
	var 后端: Node = 会.get_node_or_null("/root/BackendConnection")
	if 后端 != null:
		var 权威: Variant = 后端.get("authoritative_skills")
		if typeof(权威) == TYPE_DICTIONARY and (权威 as Dictionary).has(号):
			return int(((权威 as Dictionary)[号] as Dictionary).get("level", 0))
	for 技 in 会.learned_skills:
		if int(str((技 as Dictionary).get("id", "0"))) == 号:
			return int((技 as Dictionary).get("level", 0))
	return 0


static func _技能表刷新() -> void:
	var 会 = _会()
	_技能项.clear()
	_技能项.append({"label": _招名(0), "data": 0})
	if 会 == null:
		return
	for 号 in (招式候选.get(int(会.player_stats.get("job", 0)), []) as Array):
		if _技能等级(int(号)) > 0:
			_技能项.append({"label": _招名(int(号)), "data": int(号)})
	for 号 in 通用招式:
		if _技能等级(号) > 0:
			_技能项.append({"label": _招名(号), "data": 号})
	## 「通灵自动使用」同理：`getPetAttackSkills():1549-1567` 只收**出战**那只（`status==2`
	## ⇔ 我们的 `deployed`，`后端连接.gd:4152`）的、`info.desc.skillType == 0`（主动）
	## 且 `info.client.forPlayer != 1`（不是给玩家用的）的技能。
	_宠物技能项.clear()
	for 宠 in 会.pets:
		if not bool((宠 as Dictionary).get("deployed", false)):
			continue
		for 技 in (宠.get("skills", []) as Array):
			var 号 := int((技 as Dictionary).get("id", 0))
			var 据: Dictionary = 数据表.pet_skill(号)
			var 档: Dictionary = 据.get("info", {}) as Dictionary
			var 述: Dictionary = 档.get("desc", {}) as Dictionary
			var 客: Dictionary = 档.get("client", {}) as Dictionary
			if int(述.get("skillType", -1)) != 0 or int(客.get("forPlayer", 0)) == 1:
				continue
			_宠物技能项.append({"label": _宠招名(号, 据), "data": 号})
	if _宠物技能项.is_empty():
		# `getPetSkills():652-658` 一条都没有时压一项 "-"（data=-1），下拉不至于空白
		_宠物技能项.append({"label": "-", "data": -1})


static func _招名(号: int) -> String:
	## ⚠ 名字**必须**取 GameData 顶层 `String` 段的 `Skill` 子表（本工程已导成 `数据/技能文案.json`，
	## 访问器 `skill_text()`）—— 原版这一格走的就是 `StringTool.getSkillString(id)`（`StringTool.as:114-119`）。
	## `数据/技能.json` 的 `name` 那一列是 `Skill` 段的**结构字段**，对职业技那几条是占位垃圾
	## （`3001001`="基本的攻击招式"、`3001002`="单体远程"、`3001003`="面积"），
	## 照着显示就成了"下拉里没有技能名"（用户 2026-10-19 实机报）。真名：雷遁·雷切 / 雷遁·雷球术。
	var 名 := String(数据表.skill_text(号).get("name", ""))
	if 名 == "":
		名 = String(数据表.skill(号).get("name", ""))
	return 名 if 名 != "" else "忍术%d" % 号


static func _宠招名(号: int, 条: Dictionary) -> String:
	## 原版 `StringTool.getPetSkillString:301-305` 查的是 `PetSkill` 子表，
	## 后端给的 `skills[].name` 是占位「宠物技能 %d」（`后端连接.gd:4174`）⇒ 表里有名就以表为准。
	var 名 := String(条.get("name", ""))
	return 名 if 名 != "" else "宠物技能 %d" % 号



static func _填下拉() -> void:
	for 项 in 档表:
		var 件 := _页.get_node(项[0]) as OptionButton
		if 件 == null:
			continue
		件.clear()
		var 表: Array = []
		match String(项[0]):
			"下拉自动忍术":
				表 = _技能项
			"下拉自动宠物忍术":
				表 = _宠物技能项
			_:
				for 文 in ((_数据.get(项[0], {}) as Dictionary).get("项", []) as Array):
					表.append({"label": String(文), "data": 0})
		for 序 in 表.size():
			件.add_item(String(表[序].label), 序)


static func _区(件名: String) -> Button:
	# 复选组件里的可点件是 `Button`（`BaseButton` 的子类，**不是** TextureButton）；
	# 写 `as TextureButton` 会静默拿到 null、信号一条接不上（10-18 双修那轮踩过）。
	return _页.get_node(件名 + "/点击区域") as Button


static func _接控件() -> void:
	_连接中.clear()
	## ⚠ 那两枚**有特殊行为**的勾（VIP 闸 / 锁时间）必须**只连一条**：
	## 既进通用循环（连 `_点勾`）又进专用循环（连 `_点自动出售装备` / `_点无限时长`）= 同一个
	## `pressed` 接两个处理，两个都翻一次状态 ⇒ 净零，看着像"点了没反应"。
	## （10-18 双修那轮的"两条闸互相顶掉"是同一族，这次顶在产品代码里。）
	var 专用 := ["复选自动出售装备", "复选无限时长"]
	for 项 in 勾表:
		if String(项[0]) in 专用:
			continue
		_连(项[0], _区(项[0]).pressed, _点勾.bind(项[1]))
	_连("复选自动出售装备", _区("复选自动出售装备").pressed, _点自动出售装备)
	_连("复选无限时长", _区("复选无限时长").pressed, _点无限时长)
	# 五枚辅助那五格**不需要再单独连一次**：上面的 勾表 循环已经连了 `_点勾`，
	# 而 `_点勾` 自己会调 `_回算总续用`（再连一遍 = 两条闸互相顶掉，10-18 双修那轮的坑）。
	_连("复选自动续用辅助", _区("复选自动续用辅助").pressed, _点总续用)
	for 项 in 值表:
		var 件 := _页.get_node(项[0]) as LineEdit
		_连(项[0], 件.text_changed, _输入变.bind(件, 项[1]))
	for 项 in 档表:
		var 件 := _页.get_node(项[0]) as OptionButton
		_连(项[0], 件.item_selected, _选档.bind(项[1]))
	for 名 in ["钮开始", "钮停止"]:
		var 钮 := _页.get_node(名) as TextureButton
		_连(名 + "悬", 钮.mouse_entered, _设三态.bind(钮, 1))
		_连(名 + "离", 钮.mouse_exited, _设三态.bind(钮, 0))
		_连(名 + "按", 钮.button_down, _设三态.bind(钮, 2))
		# `MButton3.as:103-108` 松手回 STATE_UP（不是 OVER）⇒ 不移出鼠标就不会再亮
		_连(名 + "抬", 钮.button_up, _设三态.bind(钮, 0))
	_连("开始", _钮开始().pressed, _开始)
	_连("停止", _钮停止().pressed, _停止)


static func _连(键名: String, 信号: Signal, 处理: Callable) -> void:
	if 键名 in _连接中:
		return
	_连接中.append(键名)
	信号.connect(处理)


static func _钮开始() -> TextureButton:
	return _页.get_node("钮开始") as TextureButton


static func _钮停止() -> TextureButton:
	return _页.get_node("钮停止") as TextureButton


static func _设三态(钮: TextureButton, 态: int) -> void:
	if not is_instance_valid(钮):
		return
	var 档: int = 3 if 钮.disabled else 态
	var 主干 := String(钮.get_meta("skin")) if 钮.has_meta("skin") else ""
	if not 主干.is_empty():
		var 路 := "%s%s.png" % [主干, ["", "_悬停", "_按下", "_灰"][档]]
		# 缺派生皮时**回落常态**，不许停在上一档的皮上（那会留下"松手还亮着"的假态）
		钮.texture_normal = load(路) as Texture2D if ResourceLoader.exists(路) \
			else load("%s.png" % 主干) as Texture2D
	var 字 := 钮.get_node_or_null("文字") as Label
	if 字 != null:
		字.add_theme_color_override("font_color", Color(态字色[档]))


static func _件名(字段: String) -> String:
	for 项 in 勾表:
		if 项[1] == 字段:
			return String(项[0])
	return ""


static func _档字段(件名: String) -> String:
	for 项 in 档表:
		if 项[0] == 件名:
			return String(项[1])
	return ""


static func _点勾(字段: String) -> void:
	_配[字段] = not bool(_配.get(字段, false))
	_显勾(字段)
	if 字段 in 五枚辅助:
		_回算总续用()	# `clickCheckBoxHandler:446-456`
		_钮态刷新()


static func _显勾(字段: String) -> void:
	var 件名 := _件名(字段)
	if 件名.is_empty():
		return
	var 件 := _页.get_node(件名) as Control
	(件.get_node("标记") as CanvasItem).visible = bool(_配.get(字段, false))


static func _点自动出售装备() -> void:
	# 原版 `autoSellClickHandler:458-466` 在 VIP 不够时会**强制取消勾选** + 一句提示，
	# 2026-10-25 按用户报修 5.1/5.2 删掉那道闸 ⇒ 这里只剩普通 toggling。
	_配["autoSellPickedEquip"] = not bool(_配.get("autoSellPickedEquip", false))
	_显勾("autoSellPickedEquip")


static func _点无限时长() -> void:
	_配["unlimitedAutoBattleTime"] = not bool(_配.get("unlimitedAutoBattleTime", false))
	_显勾("unlimitedAutoBattleTime")
	_更新时间输入()		# `unlimitedTimeClickHandler:468-471` → `updateTimeInputState:690-697`


static func _更新时间输入() -> void:
	# 原版只 `enableInput = !selected`，**不清零**（`:696`）⇒ 取消勾选后原来那个数还在。
	var 件 := _页.get_node("输入战斗时间") as LineEdit
	件.editable = not bool(_配.get("unlimitedAutoBattleTime", false))
	件.modulate = Color.WHITE if 件.editable else Color(0.55, 0.55, 0.55)


## 已删（2026-10-25 报修 5.1/5.2）：`_是VIP5()` / `_按VIP闸()` / `_勾禁用()` / `重刷VIP()`
## —— 原版 `GuaJiSettingWindow.as:705-717 updateAutoSellVipState` 在 `vipLevel < GUAJI_AUTO_SELL_EQUIP_LEVEL(=5)`
## 时把那枚勾禁用 + 文案补 "(VIP5)"，点击时 `:458-466` 再强取消 + 提示。**用户点名不要求任何 VIP 等级**，
## 整族没了 ⇒ 「复选自动出售装备」永远是可点、永远是原文案（场景烘的就是这两条），别照 AS3 补回。
## `_勾禁用` 曾是全页唯一下 `disabled` 的地方，它一没，`原版复选项.刷态()` 的禁用档改由
## `测试/挂机窗回归测试.gd` ⑮ 直接 `钮.disabled = true; 根.call("刷态")` 判（判据没丢）。


static func _回算总续用() -> void:
	# `clickCheckBoxHandler:446-456`：五枚**全勾**才点亮「自动续用以下辅助忍术」。
	var 全 := true
	for 字段 in 五枚辅助:
		if not bool(_配.get(字段, false)):
			全 = false
			break
	_配[总续用键] = 全
	_显总续用()


## `autoSkillHandler:249-252`：点这枚总开关 = 把五枚**一律**置成它的状态（不是"取反"）。
static func _点总续用() -> void:
	var 值 := not bool(_配.get(总续用键, false))
	_配[总续用键] = 值
	for 字段 in 五枚辅助:
		_配[字段] = 值
		_显勾(字段)
	_显总续用()


## ⚠ **信号自带的那一格参数排在 bind 的前面**：`text_changed(new_text)` / `item_selected(index)`
## 各带一个参数，所以这两个函数的第一个形参必须是它，`bind(...)` 的在后面。
## 写反了不会在接线时报错，是每次触发打一条
## `Error calling from signal 'text_changed' to callable: Method expected 2 argument(s), but called with 3`
## ⇒ 处理函数**一次都没跑**，页面上看着就是"改了上限没反应"（10-18 门里真打字才逮到）。
static func _选档(档号: int, 字段: String) -> void:
	var 件名 := ""
	for 项 in 档表:
		if 项[1] == 字段:
			件名 = String(项[0])
	var 件 := _页.get_node(件名) as OptionButton
	_配[字段] = maxi(0, 件.selected)
	if 字段 == "autoSkillType":
		_配["autoSkillId"] = int(_技能项[件.selected]["data"]) if 件.selected >= 0 and 件.selected < _技能项.size() else 0
	elif 字段 == "autoChongWuSkillType":
		_配["autoChongwuSkillId"] = int(_宠物技能项[件.selected]["data"]) if 件.selected >= 0 and 件.selected < _宠物技能项.size() else -1
	elif 字段 == "collectLevelType":
		_配["collectLevel"] = int(等级值[件.selected]) if 件.selected >= 0 and 件.selected < 等级值.size() else -1


static func _输入变(_新文: String, 件: LineEdit, 字段: String) -> void:
	# `createTextInput:181-193`：`restrict="0-9"` + CHANGE 时超上限就强填上限值。
	# 上限烘在场景的 `metadata/max` 上（编辑器里看得见），不在这里再抄一份。
	var 只数 := ""
	for i in 件.text.length():
		var c := 件.text[i]
		if c >= "0" and c <= "9":
			只数 += c
	var 上限 := int((_数据.get(件.name, {}) as Dictionary).get("上限", 99))
	if 只数.is_empty():
		_配[字段] = 0
		if 件.text != "":
			件.text = ""
		return
	if int(只数) > 上限:
		只数 = str(上限)
	if 只数 != 件.text:
		var 位 := 件.caret_column
		件.text = 只数
		件.caret_column = mini(位, 只数.length())
	_配[字段] = int(只数)


static func _显下拉(件名: String, 值: int) -> void:
	var 件 := _页.get_node(件名) as OptionButton
	件.selected = 值 if (值 >= 0 and 值 < 件.item_count) else -1


static func _填控件() -> void:
	for 项 in 勾表:
		_显勾(项[1])
	_显总续用()
	for 项 in 档表:
		_显下拉(项[0], int(_配.get(项[1], 0)))
	for 项 in 值表:
		(_页.get_node(项[0]) as LineEdit).text = str(int(_配.get(项[1], 0)))


static func _显总续用() -> void:
	((_页.get_node("复选自动续用辅助") as Control).get_node("标记") as CanvasItem).visible = \
		bool(_配.get(总续用键, false))


static func _本地出售读() -> Dictionary:
	var 出: Dictionary = 默认.duplicate(true)
	var f := FileAccess.open(本地出售路, FileAccess.READ)
	if f == null:
		return 出
	var 解: Variant = JSON.parse_string(f.get_as_text())
	if typeof(解) != TYPE_DICTIONARY:
		return 出
	var 表: Dictionary = 解
	for 键名 in ["autoSellEnabled", "autoSellIngredients", "autoSellFragments", "autoSellBooks"]:
		if 表.has(键名):
			出[键名] = bool(表[键名])
	for 键名 in ["autoSellMaxLevel", "autoSellJobIndex", "autoSellMaxQuality"]:
		if 表.has(键名):
			出[键名] = int(表[键名])
	# `loadAutoSellLocalConfig:612-614`：存的 maxLevel 要**按 data 反查档位**
	出["autoSellLevelIndex"] = _等级档(int(出.get("autoSellMaxLevel", 0)))
	出["autoSellQualityIndex"] = int(出.get("autoSellMaxQuality", 0))
	for 字段 in ["autoSellEnabled", "autoSellIngredients", "autoSellFragments", "autoSellBooks"]:
		出[字段] = bool(表.get(字段, 出[字段]))
	return 出


static func _本地出售写(配: Dictionary) -> void:
	# `saveAutoSellLocalConfig:624-636` 的七个键，一个不多一个不少。
	var 表 := {
		"enabled": bool(配.get("autoSellEnabled", false)),
		"ingredients": bool(配.get("autoSellIngredients", false)),
		"fragments": bool(配.get("autoSellFragments", false)),
		"books": bool(配.get("autoSellBooks", false)),
		"maxLevel": int(配.get("autoSellMaxLevel", 0)),
		"jobIndex": int(配.get("autoSellJobIndex", 0)),
		"maxQuality": int(配.get("autoSellMaxQuality", 0)),
	}
	var f := FileAccess.open(本地出售路, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(表))


static func _等级档(目标: int) -> int:
	# `getAutoSellLevelIndex:586-599`：找不到就回 0（= 全部等级）。
	for i in 等级值.size():
		if int(等级值[i]) == 目标:
			return i
	return 0


static func _收配置() -> Dictionary:
	# `startGuaJi:507-549` 的逐条读法；这里从控件现读，避免"改了文字没落表"。
	var 收: Dictionary = _配.duplicate(true)
	for 项 in 勾表:
		收[项[1]] = bool(_配.get(项[1], false))
	for 项 in 档表:
		var 件 := _页.get_node(项[0]) as OptionButton
		收[项[1]] = maxi(0, 件.selected)
	var 忍 := _页.get_node("下拉自动忍术") as OptionButton
	收["autoSkillId"] = int(_技能项[忍.selected]["data"]) if 忍.selected >= 0 and 忍.selected < _技能项.size() else 0
	var 兽 := _页.get_node("下拉自动宠物忍术") as OptionButton
	收["autoChongwuSkillId"] = int(_宠物技能项[兽.selected]["data"]) if 兽.selected >= 0 and 兽.selected < _宠物技能项.size() else -1
	var 级 := _页.get_node("下拉拾取等级") as OptionButton
	收["collectLevel"] = int(等级值[级.selected]) if 级.selected >= 0 and 级.selected < 等级值.size() else -1
	var 售级 := _页.get_node("下拉出售等级") as OptionButton
	收["autoSellMaxLevel"] = int(等级值[售级.selected]) if 售级.selected >= 0 and 售级.selected < 等级值.size() else 0
	var 售职 := _页.get_node("下拉出售职业") as OptionButton
	收["autoSellJobIndex"] = maxi(0, 售职.selected)
	var 售品 := _页.get_node("下拉出售品质") as OptionButton
	收["autoSellMaxQuality"] = maxi(0, 售品.selected)
	for 项 in 值表:
		var 件 := _页.get_node(项[0]) as LineEdit
		收[项[1]] = int(件.text) if 件.text.is_valid_int() else int(_配.get(项[1], 0))
	return 收


static func _开始() -> void:
	var 收 := _收配置()
	_配 = 收
	_本地出售写(收)
	# ① 7779：`:551` 那条位掩码算式一字不差
	var 掩码: int = (1 if bool(收.get("autoSellEnabled", false)) else 0) \
		| (2 if bool(收.get("autoSellIngredients", false)) else 0) \
		| (4 if bool(收.get("autoSellFragments", false)) else 0) \
		| (8 if bool(收.get("autoSellBooks", false)) else 0)
	# ② 1283 保存：载荷就是整个 JSON
	var 发 := {}
	for 键名 in 存字段:
		发[键名] = 收.get(键名, 默认.get(键名))
	_会().套用挂机配置(收)				# 本地循环立刻吃这套新值（这才叫"有反应"）
	var 发得出 := true
	if _会().后端连接() != null:
		发得出 = _会().request_hang_config_save(发) and _会().request_auto_sell_config(
			掩码, int(收.get("autoSellMaxLevel", 0)), int(收.get("autoSellJobIndex", 0)),
			int(收.get("autoSellMaxQuality", 0)))
	var 起了: bool = _会().request_hang(true)
	if 起了 and 发得出:
		_宿主._show_hint("已开始挂机")
		_宿主.close()		# `startGuaJi:557` 末尾 `onCloseBtnClick(null)` ⇒ 发完就收窗
	else:
		_宿主._show_hint("开始挂机没发出去：没连上服务端")
		_钮态刷新()


static func _停止() -> void:
	# `stopGuaJi:735-739` 只派发 STOP 事件：**不发协议、不关窗**
	_会().request_hang(false)
	_宿主._show_hint("已停止挂机")
	_钮态刷新()


static func _请配置() -> void:
	# 原版没有这一条（配置在 `CharacterConfig.getInstance()` 的本地单例里，进图时同步过）。
	# 本工程以前从没读过 1283 ⇒ 开窗主动查一次，回帧来了按服务端真值重刷；离线就保持本地值。
	_会().request_hang_config_query()


static func 喂服务端配置(配置: Dictionary) -> void:
	## `Client.as:7171 onCharConfig` → `guajiWindow.setData()` 那一跳。
	## 只有**这扇窗开着**才回填（原版窗没建就没这行）；页面不在就什么都不做。
	if _页 == null or not is_instance_valid(_页):
		return
	for 键名 in 配置:
		if 默认.has(键名):
			_配[键名] = 配置[键名]
	# 回帧给的是 data（等级）与档位号混着，等级那两档要按 data 反查，否则下拉会指到空行
	_配["collectLevelType"] = _等级档(int(配置.get("collectLevel", _配.get("collectLevel", -1)))) \
		if 配置.has("collectLevel") else int(_配.get("collectLevelType", 0))
	_配["autoSellLevelIndex"] = _等级档(int(_配.get("autoSellMaxLevel", 0)))
	_配["autoSellQualityIndex"] = int(_配.get("autoSellMaxQuality", 0))
	_填控件()
	_回算总续用()
	_更新时间输入()
	_钮态刷新()


static func _钮态刷新() -> void:
	重画钮态()
	_提示刷新()


## 门与外部用的公开口子：三态皮肤重算。
## ⚠ **两颗钮永远可点**：全份 `GuaJiSettingWindow.as` 里下过 `enabled` 的只有 `_autoSellCheckBox`
## （`:708`/`:714` 那道 VIP5 闸，2026-10-25 随报修 5.1/5.2 删），`_startBtn`/`_stopBtn`
## 从头到尾没有禁用档（grep `enabled` 只剩出售勾选那一处）。我上一轮自造了「挂着就禁开始、没挂就禁停止」，
## 结果没挂机时那枚「停止挂机」是灰的 —— 原版它是亮的（10-18 用户实机图）。
static func 重画钮态() -> void:
	if _页 == null or not is_instance_valid(_页):
		return
	_设三态(_钮开始(), 0)
	_设三态(_钮停止(), 0)


static func _提示刷新() -> void:
	# 原文案是 `CN.GUAJI_PROMPT`（「在地图任意空白处点击可中断挂机状态」），原版那枚 label 是静态的；
	# 挂机中在后面补一行"已跑几分钟"，让这页至少能看出状态（原版靠地图上的活动方框看）。
	var 件 := _页.get_node("标签提示") as Label
	var 原文 := String((_数据.get("标签提示", {}) as Dictionary).get("文", ""))
	## 原版这枚 label 是**静态**的（`CN.GUAJI_PROMPT`「在地图任意空白处点击可中断挂机状态」），
	## 不追"已挂机几分钟"。之前我在后面拼了「（已挂机 N 分钟）」，字变长顶出窗口右缘、
	## 还被截断（用户 10-18 实机图），已按原版改回静态。
	件.text = 原文

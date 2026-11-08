extends Node

const 资源解析 := preload("res://脚本/单例/资源解析.gd")

const DATA_FILES := {
	"怪物": "res://数据/怪物.json",
	"NPC": "res://数据/NPC.json",
	"物品": "res://数据/物品.json",
	"物品图标": "res://数据/物品图标索引.json",
	"技能": "res://数据/技能.json",
	"技能文案": "res://数据/技能文案.json",
	# 出手技能 -> 被打的人身上那条"克制提示"流水字。
	# 14 条；出处与导出见 开发工具/导出技能对手技.py 文件头（两处 AS3 行号都在里面）。
	"技能对手技": "res://数据/技能对手技.json",
	"技能升级需求表": "res://数据/技能升级需求表.json",
	"技能素材": "res://数据/技能素材索引.json",
	"地图名": "res://数据/地图名.json",
	"副本": "",
	# 活跃度（火影活跃度）的奖励档位。**原样**的 GameData 字段名，导出见 开发工具/导出活跃度奖励.py。
	"活跃度奖励": "res://数据/活跃度奖励.json",
	# 礼包整段（`Gift`）。六个福利子页里的档位门槛与奖励都取自它，导出见 开发工具/导出礼包配置.py。
	# ⚠️ 段名就是 `Gift`；里面的 `monthly/weekly/firstlogin/levelup/everyday/may7th/activates`
	#    全是 **GameData 原样字段名**，别改名（理由同上面的"活跃度奖励"）。
	"礼包": "res://数据/礼包.json",
	# ↓ 2026-09-26 补齐的原版分区（导出见 开发工具/导出游戏数据.mjs）。字段名**照原版**，
	#   理由同 装备打造表.gd：改名等于把同一份真值抄成两份，抄漏就静默错。
	"精华消耗": "res://数据/精华消耗.json",
	"装备基础属性": "res://数据/装备基础属性.json",
	"任务": "res://数据/任务.json",
	"增益状态": "res://数据/增益状态.json",
	# 罪状（叛忍等级）Buff 的阈值/文案/图标技能号，见 开发工具/导出PK状态.py。
	"PK状态": "res://数据/PK状态.json",
	# PK 的那几个数（pkLevel 45 / configLevel 40 / player2playerLevel 15 / 安全图 5 张 /
	# 打不了人时那 14 句原文），原版是 `PVPHandler.as:99-131` 读的 `Pvp/open` 段。
	# ⚠ 客户端与夹具服务端**都读这一份**，别再各自写死（以前服务端写死 45、客户端压根没读）。
	"PVP配置": "res://数据/PVP配置.json",
	"成就": "res://数据/成就.json",
	"活动": "res://数据/活动.json",
	"经脉": "res://数据/经脉.json",
	"意志": "res://数据/意志.json",
	# 意志图鉴（47 条）：name/desc/textColor/color/speed/icon 全在这儿，由
	# `开发工具/导出意志图鉴.py` 从 GameData 的 `Spirit.items` + `String.Spirit` 生成
	# （原版 `StringTool.getYiZhiString(id)` 读的就是 String.Spirit）。**别手改**。
	"意志图鉴": "res://数据/意志图鉴.json",
	# 意志界面文案（LangUtil 那一套，34 条）：`YIZHI_YIZHILI_LABEL` = 「当前意志：」
	# 就是人物面板意志格悬停提示的首行前缀（原版 `getYiZhiPropToopTioInfo:392-405`）。
	"意志界面文案": "res://数据/界面/意志_文案.json",
	"师徒": "res://数据/师徒.json",
	"VIP": "res://数据/VIP.json",
	"公告": "res://数据/公告.json",
	"宝箱": "res://数据/宝箱.json",
	"宝盒": "res://数据/宝盒.json",
	"卡片": "res://数据/卡片.json",
	"忍具": "res://数据/忍具.json",
	# 忍具那一族的 name / desc / detaildesc + **已直解**那两枚图标的落点。
	# 为什么单开一张：`物品.json` 的导出管线只并 15 个分组、`RenJu` 不在其中
	# （`开发工具/导出游戏数据.mjs:312-314`），于是 13 件忍具在客户端**没名、没图、没文案** ——
	# 兑换到手的八咫镜就是背包里一个空框、名字叫「65000001」（报修 14 / #81，§3.262）。
	# 原版从 GameData 的 `String/RenJu/<id>` 取（`RenJuData.as:31-36`）。口径见 开发工具/导出忍具文案.py。
	"忍具文案": "res://数据/忍具文案.json",
	"礼包奖励": "res://数据/礼包奖励.json",
	# 「火影有礼」详情窗（`SelectGiftWindow.as`）的 LiBao 预览配置。
	# 只收 `info.preview == 1` 的礼包；导出见 开发工具/导出礼包详情.py。
	"礼包详情": "res://数据/礼包详情.json",
	"原版杂项": "res://数据/原版杂项.json",
	# ↓ 装备系统的基础库（导出见 开发工具/导出装备品质.mjs、导出装备库.mjs）。
	#   前三张很小但每个提示框都要查，走常驻；装备库 316 KB 只在真要用时读。
	"装备品质": "res://数据/装备品质.json",
	"装备属性名": "res://数据/装备属性名.json",
	"装备文案": "res://数据/装备文案.json",
	"装备库": "res://数据/装备库.json",
	# A2：原版 Buff 状态图标（天气 / 系统双倍 / 结印 / 连战 …），导出见 开发工具/导出特效与图标.mjs。
	"状态图标": "res://数据/状态图标.json",
	# 物品的 `detaildesc` —— 商城商品行说明框里那行**绿字**（`CashItemCell.as:216-219`）。
	# 我们的 物品.json 只有 `desc`（= 本表的 `description`，实测 1596 条全同），
	# detaildesc 项目里原先没有；导出见 开发工具/导出物品详情文案.py。
	"物品详情文案": "res://数据/物品详情文案.json",
	# 技能出手时角色播哪个动作 —— 原版 `AbstractAttackSkill.setStances():592-599` 读技能记录的
	# `action` 字段；没写这条的技能退回基类默认 `[Action.alert]`（`AbstractSkill.as:16`）。
	# 只收「有 action」的 24 条，导出见 开发工具/导出技能动作.py。
	"技能动作": "res://数据/技能动作.json",
	# 技能释放消耗：查克拉（逐级表）与**查克拉精华**。原版 `AbstractSkill.isMpEnough()` 两样都查，
	# 我们原来只有 mp 一项 → 会放一个付不起的技能还不提示。导出见 开发工具/导出技能消耗.py。
	"技能消耗": "res://数据/技能消耗.json",
	# 主动 / 被动。原版技能记录的 `info.type_attack`（主动）与 `info.type_attr`（被动）互斥，
	# 导出见 开发工具/导出技能主动.py。**别再拿 `damage > 0` 当主动** —— 面积类技能的
	# damage 是负数（倍率），会被误判成被动。
	"技能主动": "res://数据/技能主动.json",
	# 宠物模板（GameData `Pet` 段整段 + common）。宠物窗每一格显示值都由
	# 脚本/角色/宠物数值.gd 现场算，算式吃的就是这张表；导出见 开发工具/导出宠物数据.py。
	"宠物": "res://数据/宠物.json",
	# 宠物技能（`Skill` 段 `PetSkill` 子表 33 条，被动加成读 info.type_attr）。
	"宠物技能": "res://数据/宠物技能.json",
	# 家族整段（GameData `BangHui`）：cost（令牌窗判定表）/ flagmap（领域战地图）/
	# flag（家徽各级 hp·attr·cost）/ war / boss / flagStyle（200 个家徽样式 → 图在哪个 swf）。
	# 导出见 开发工具/导出家族配置.py。
	# ⚠️ 这几张以前被当成"运行时 HTTP 下发的 dat，拿不到"——**其实 GameData 里就有**，
	#    查不到东西时先来这里看一眼，别急着写"服务端才有"。
	"家族": "res://数据/家族.json",
	# 荣誉（木叶大战）兑换货架：GameData `MuyeBattle.shop` 整段 11 条。
	# ⚠️ 这张**只读、不发请求** —— 原版 `RongYuPanel.setData():91-107` 就是
	#    `ImgUtil.getImg(ImgType.MuyeBattle,"shop")`，没有任何 HTTP/套接字半边。
	#    导出见 开发工具/导出荣誉商店.py；行序 = GameData 键序（`sort_keys` 会把 10 排到 2 前面）。
	"荣誉商店": "res://数据/荣誉商店.json",
}

## 只在用到时才读的大表。启动路径上真正必读的是 物品/怪物/NPC/技能/地图名 那几张
## （每个窗口都要查名字），下面这些合计 ~1.6 MB，全塞进 `_init` 会把首帧白等一截。
const 懒加载表 := ["任务", "成就", "活动", "经脉", "意志", "宝箱", "宝盒", "卡片", "礼包奖励", "礼包详情", "礼包", "原版杂项", "装备库", "状态图标", "物品详情文案", "忍具文案", "宠物", "家族", "荣誉商店", "意志图鉴", "意志界面文案"]

static var _tables := {}
static var _懒表已读 := {}

func _init() -> void:
	_ensure_loaded()

func _ready() -> void:
	_ensure_loaded()

## 空掉就说明导出/数据坏了，而且**每个查它的地方都会静默退化**的表
## （名字显示成原始 id、数值显示成 0），没人会知道是数据的问题。
const 必需表 := ["怪物", "NPC", "物品", "技能", "地图名"]


static func reload() -> void:
	_tables.clear()
	_懒表已读.clear()
	for table_name in DATA_FILES:
		_tables[table_name] = {} if 懒加载表.has(table_name) else _读表(table_name)
	# ⚠️ 空表不能只是"查不到就返回 {}" —— 那样调用点会静默退化成显示原始 id / 0。
	#    2026-09-25 起：必需表为空直接 push_error（§3.31.1 阶段 0）。
	for 名 in 必需表:
		if (_tables.get(名, {}) as Dictionary).is_empty():
			push_error("游戏数据：必需表「%s」是空的（导出坏了？）—— 所有查它的地方都会静默返回空。" % 名)

static func _读表(table_name: String) -> Dictionary:
	var base := _load_dictionary(DATA_FILES[table_name]) if not String(DATA_FILES[table_name]).is_empty() else {}
	var extension_path := "res://数据_扩展/%s.json" % table_name
	if FileAccess.file_exists(extension_path):
		base = _merge_dictionaries(base, _load_dictionary(extension_path))
	return base

## 取一张表；`懒加载表` 里的第一次用到才读盘。
static func 取表(表名: String) -> Dictionary:
	_ensure_loaded()
	if 懒加载表.has(表名) and not _懒表已读.has(表名):
		_懒表已读[表名] = true
		_tables[表名] = _读表(表名)
	return _tables.get(表名, {}) as Dictionary

## 家徽格的悬停文案 —— 逐字照原版 `FamillyManager.getJiaHuiJiaChengString`（`FM.as:603-628`）：
##   第一行 `FAMILLY_MANAGER_JIAHUI_SHUXING_JIACHENG`（`<font color='#fff000'>%1级家徽属性加成</font>`
##   + `<br/>` + `<font color='#ffffff'>%2级家徽为你带来的属性加成：`，`%1 = %2 = 等级`）
##   中间是 `flag[等级].attr` 逐项 `getPropString`（`:585-620`）后的结果、`，` 分隔
##   末尾 `FAMILLY_MANAGER_ALL_MAP_SHENGXIAO` = `（全地图生效）`
## ⚠️ 原版是**富文本**（带颜色），我们的 tooltip 是纯文本 ⇒ 这里去掉颜色标签、保留换行。
## ⚠️ `getPropString` 的属性名映射：maxhp→生命上限 / maxmp→魔法上限 / def→防御 / atk→攻击 /
##    avd→闪避 / bsk→暴击；键名带 `_rate` 的**值后面加 `%`**；拼法是 **值在前、名在后**。
const 家徽属性名 := {"maxhp": "生命上限", "maxmp": "魔法上限", "def": "防御",
	"atk": "攻击", "avd": "闪避", "bsk": "暴击"}


static func 家徽加成文案(等级: int) -> String:
	_ensure_loaded()
	var 级 := maxi(1, 等级)
	var 段: Dictionary = 取表("家族").get("flag", {})
	var 条: Dictionary = (段.get(str(级), {}) as Dictionary).get("attr", {}) as Dictionary
	if 条.is_empty():
		return ""
	var 项: Array[String] = []
	for 键 in 条:
		项.append(_家徽属性词(String(键), 条[键]))
	return "%d级家徽属性加成\n%d级家徽为你带来的属性加成：%s（全地图生效）" % [级, 级, "，".join(项)]


static func _家徽属性词(键: String, 值: Variant) -> String:
	var 段 := 键.split("_")
	var 名 := String(段[0])
	var 尾 := "" if 段.size() < 2 or 段[1] != "rate" else "%"
	# ⚠️ 数值要按 **AS3 的 Number→String** 来：`2.0` 在原版显示成 `2`。
	#    我们这份 `数据/家族.json` 里 attr 值是浮点（`2.0`），直接拼会成 "2.0%" ✗。
	var 数 := float(值)
	var 文本 := str(int(roundf(数))) if is_equal_approx(数, roundf(数)) else str(数)
	return "%s%s%s" % [文本, 尾, String(家徽属性名.get(名, 名))]


## 家族**族徽/族旗**那条增益（`数据/增益状态.json` 的 `flag[<家徽等级>]`）。
##
## 真值：原版 `SkillHandler.addFlagBuff`（`SkillHandler.as:641-665`）——
##   `ImgUtil.getImg(ImgType.Buff,"flag")[flag_level]` 取 `buffName` / `buffDesc`；
##   图标另用 `PicTool.getJiaHuiPic(flag_style)`；`remainTime = 21000000001`（**永久、不倒数**）。
## 文案是"打怪经验 +30~120% / 打坐速度 +3~28%"（**不是**攻防血），攻防血那条走
## `flag[等级].attr`（服务端 `_family_flag_attr_rates` 直接算进属性里，不在增益栏）。
static func 族徽增益(等级: int) -> Dictionary:
	_ensure_loaded()
	var 段: Dictionary = 取表("增益状态").get("flag", {})
	return 段.get(str(maxi(1, 等级)), {}) as Dictionary


## 荣誉兑换货架的 11 条（`数据/荣誉商店.json` 的 `条目`）。
## **顺序就是显示顺序** —— 原版 `RongYuPanel.setData():99-105` 按 `shop` 的键序
## `0..10` 逐条 `addChild`，`y = 62 * index`；返回数组而不是字典，别在调用点排序。
static func 荣誉商店() -> Array:
	_ensure_loaded()
	return (取表("荣誉商店").get("条目", []) as Array)


static func monster(monster_id: Variant) -> Dictionary:
	_ensure_loaded()
	return _record("怪物", monster_id)

static func npc(npc_id: Variant) -> Dictionary:
	_ensure_loaded()
	var key := _normalize_id(npc_id, 8)
	return 取表("NPC").get(key, {})

static func item(item_id: Variant) -> Dictionary:
	_ensure_loaded()
	var records := 取表("物品")
	var key := str(item_id)
	if not records.has(key) and key.is_valid_int():
		key = key.pad_zeros(8)
	var result: Dictionary = records.get(key, {})
	if result.is_empty():
		# 物品表里压根没有这一族（忍具 `65000001..65000013`）⇒ 回退到 `String/RenJu` 那份，
		# 别再让调用点拿到空字典、把名字显示成一串 id（#81 / §3.262）。
		return 忍具物品记录(item_id)
	if result.has("icon"):
		return result
	result = result.duplicate(true)
	result["icon"] = item_icon_path(key)
	return result


## 忍具的**静态** `info`（`数据/忍具.json`：`baseAttr` / `addAttr` / `specialAttr` /
## `reqLevel` / `reqJob` / `price`）。原版 `RenJuData.initVars` 从 GameData 的
## `RenJu.<id>.info` 读；wire 上根本不带这些，所以提示框只能走这张表
## （与灵器那张导出表同一口径，只是忍具表本来就在仓里）。
## 不是忍具 ⇒ 空字典。
static func 忍具属性(物品号: Variant) -> Dictionary:
	_ensure_loaded()
	var key := str(物品号)
	if not key.is_valid_int():
		return {}
	key = key.pad_zeros(8)
	return (取表("忍具").get(key, {}) as Dictionary).get("info", {}) as Dictionary


## 忍具段那条文案记录（`{name, desc, detaildesc, icon, icon符号}`）；不是忍具 ⇒ 空字典。
static func 忍具记录(物品号: Variant) -> Dictionary:
	_ensure_loaded()
	var 表: Dictionary = 取表("忍具文案").get("忍具", {}) as Dictionary
	var key := str(物品号)
	if not 表.has(key) and key.is_valid_int():
		key = key.pad_zeros(8)
	return 表.get(key, {}) as Dictionary


## 把忍具那段**伪装成一条物品记录**：字段名对齐 `物品.json`（`description` 是原版 `desc`
## 在我们这边的既有键名，见 `物品详情文案` 那条注释的实测「1596 条全同」），
## 这样只认 `name` / `description` / `icon` 的老调用点也照样显示得出来。
static func 忍具物品记录(物品号: Variant) -> Dictionary:
	var 录 := 忍具记录(物品号)
	if 录.is_empty():
		return {}
	var 出: Dictionary = 录.duplicate(true)
	出["description"] = String(录.get("desc", ""))
	出["icon"] = 资源解析.解析(String(录.get("icon", "")))
	# 需求等级/价格在 `数据/忍具.json` 的 `info` 里（文案表只管名字/描述/图标）。
	# 原版 `RenJuData.initVars` 就是这两段合起来用（`this.wzItem.reqLevel/price` + `itemDescObj`）。
	var 元 := 忍具属性(物品号)
	出["required_level"] = int(元.get("reqLevel", 0))
	出["price"] = int(元.get("price", 0))
	return 出

## 单摞数量上限。原版取法：`ItemData.as:248` `maxCount = info.slotMax`（`数据/物品.json` 的 `stack_max`
## 就是它的导出），合并堆叠时用它当闸（`DataCenter.as:1159` `quantity + n <= maxCount`）。
## ⚠️ **有意偏离原版**（用户 2026-10-21 要求）：作者值 **99 / 999 一律抬到 9999**，
##   1（装备、不可叠）和 5000 原样保留。服务端 `fake_flash_server.py:_item_stack_limit` 用**同一张表**，
##   两头不一致会表现为"买 200 只结算 99"。登记表见 `真值/物品/堆叠上限.md`。
const 堆叠上限抬升表 := {99: 9999, 999: 9999}

static func 堆叠上限(物品id: Variant) -> int:
	var 作者值 := maxi(1, int(item(物品id).get("stack_max", 9999)))
	return int(堆叠上限抬升表.get(作者值, 作者值))

## 装备的 `进阶目标`（原版 `EqpData.nextId` = `ZhuangBei.next`；**空串 = 满级**）。
## 导出见 `开发工具/导出装备库.mjs:82`（`info.next ? 八位(info.next) : ""`）。
## 装备库键是**八位补零**（`01410001`）—— §3.129 那条 id 形态的坑。
## 徽章打造 / 勾玉炼制（玉链升阶）两扇窗的那道「满级」闸门都查它。
static func 装备进阶目标(id: Variant) -> String:
	var key := str(id).pad_zeros(8)
	var 装备: Dictionary = 取表("装备库").get("装备", {}) as Dictionary
	return str((装备.get(key, {}) as Dictionary).get("进阶目标", ""))


## 宠物模板行（`数据/宠物.json` 的 templates，键是**八位补零** id，如 "00000404"）。
## ⚠️ 服务端帧里 item_id 走 `int()`（401），查表前必须补零 —— §3.61.2 病根一。
static func pet_template(pet_id: Variant) -> Dictionary:
	_ensure_loaded()
	var templates: Dictionary = 取表("宠物").get("templates", {}) as Dictionary
	var key := str(pet_id)
	if not templates.has(key) and key.is_valid_int():
		key = key.pad_zeros(8)
	return templates.get(key, {}) as Dictionary

## 宠物公共参数：`common = {extend, expTable, skillAddRatio}`（原版 ImgType.PetCfg "common"）。
static func pet_common() -> Dictionary:
	_ensure_loaded()
	return 取表("宠物").get("common", {}) as Dictionary

## 宠物技能行（101..126 主动 / 201..208 被动；被动读 `info.type_attr`）。
## 键是**不补零**的技能号（服务端 Skill 段 PetSkill 子表原本就这样）。
static func pet_skill(skill_id: Variant) -> Dictionary:
	_ensure_loaded()
	var result: Dictionary = 取表("宠物技能").get(str(int(skill_id)), {})
	var 图标 = result.get("icon")
	# 已经解析过（字符串路径）或没有图标就原样返回。
	if result.is_empty() or 图标 is String:
		return result
	# 宠物技能的 icon 是 AMF 原样的 `{origin, value:{className, swfName}}`
	# （与原版 `PicTool.getPetSkillPic` 同一份数据）；解析成工程里的贴图路径，
	# 让 Buff 图标/HUD 不必各自再懂一遍 className 映射。
	result = result.duplicate(true)
	var 类名 := ""
	if 图标 is Dictionary:
		var 值 = (图标 as Dictionary).get("value", {})
		if 值 is Dictionary:
			类名 = String((值 as Dictionary).get("className", ""))
	if not 类名.is_empty():
		result["icon"] = 资源解析.解析(String((取表("技能素材") as Dictionary).get(类名, "")))
	return result

## 全部宠物技能号（升序）。`PetSkillSelectWindow` 的候选清单就是 `Skill.PetSkill` 的键序
## （原版 `getPetSkillList` 遍历 AMF 对象键）；尾兽技能由调用方按 `PetSkillSelectWindow:96-98`
## 那四条 id 剔除。
static func pet_skill_ids() -> Array[int]:
	_ensure_loaded()
	var 表: Dictionary = 取表("宠物技能")
	var 号们: Array[int] = []
	for 键 in 表:
		号们.append(int(键))
	号们.sort()
	return 号们

## ── 家族（GameData `BangHui` 整段，见 开发工具/导出家族配置.py）────────────────
## **可捐献的书**：`cost.contri.item[*].id` —— 家族令牌窗拿它判定"这本能不能捐"
## （原版 `ZhuGongLingWindow.validateItem`，`ZGL.as:63-84`）。实测是 5 本：
## 16000022..16000026。⚠️ 别自己去猜物品 id 段，就查这张表。
static func family_contribution_books() -> Array[int]:
	_ensure_loaded()
	var 出: Array[int] = []
	var 项 := (取表("家族").get("cost", {}) as Dictionary).get("contri", {}) as Dictionary
	for v in (项.get("item", {}) as Dictionary).values():
		if v is Dictionary and (v as Dictionary).has("id"):
			出.append(int((v as Dictionary)["id"]))
	出.sort()
	return 出


## 家族领域战地图表：`flagmap` 的每一行 = `{mapid, x, y, childmaps}`（键是行号，无意义）。
## 家族旗帜窗「族旗安插列表」的行就是拿它排的（原版 `FamillyManager.getFamillyWarMaps`，
## `FM.as:529-532`；`FamillyFlagWindow.getFlags` 再按 map_id 去族旗表里配上数据）。
static func family_flag_maps() -> Array[Dictionary]:
	_ensure_loaded()
	var 出: Array[Dictionary] = []
	var 段 := 取表("家族").get("flagmap", {}) as Dictionary
	var 键 := 段.keys()
	键.sort_custom(func(a, b): return int(a) < int(b))
	for k in 键:
		if 段[k] is Dictionary:
			出.append(段[k] as Dictionary)
	return 出

## 领域战地图的 **mapid 集合**（`family_flag_maps()` 那份的 mapid 摘出来）。
##
## 给谁用：原版 `FamillyFlagWindow.updateButtonState`（`FFW:402-407`）里 `isInWarMaps(map_id)`
## 那道判定 —— 只有 `flagmap` 里这几张图才允许安插/修复族旗（`FM.as:529-532`）。
## ⚠️ 单独出一个函数而不是每次遍历 `family_flag_maps()`：旗帜窗选一行就判一次，
##    而这个表是常量，没必要重复解 JSON。
static func family_flag_map_ids() -> Array[int]:
	_ensure_loaded()
	var 出: Array[int] = []
	var 段 := 取表("家族").get("flagmap", {}) as Dictionary
	for k in 段:
		if 段[k] is Dictionary:
			出.append(int((段[k] as Dictionary).get("mapid", 0)))
	return 出



## 家徽某一级的配置（`flag.<级>`）：`hp.max_hp` / `attr.*` / `cost.money` + 四种材料 /
## `info.limit`。家族升级窗与家徽格都读它。
static func family_flag_config(level: int) -> Dictionary:
	_ensure_loaded()
	return (取表("家族").get("flag", {}) as Dictionary).get(str(maxi(1, level)), {}) as Dictionary

## ── 家族创建 / 升级的**单机版口径**（唯一来源，UI 与服务端必须一致）─────────────
##
## ⚠️ 这两张表和 `family_flag_config()` 的 `cost` **不是一回事**，别混用：
##   · `flag[<级>].cost` 是**原始线上数据**：创建（1 级）要 16000022×1、金币 0；
##     2 级起金币是 1000 万、3000 万…一路涨到 52 亿。
##   · 单机版**把升级成本改成写死的 666 金币 + 春夏秋冬书各 1**，客户端与服务端两边一致：
##       - 客户端 `getFamillyUpgradeCfg()`：`myFamillyInfo.level >= 10` 时返回 null，
##         否则 `{money:666, item:[{count:1}×4]}`；
##       - 服务端 `_handle_multiplayer_family` 的 `action == 10`：`money_cost = 666`、
##         `item_costs = {16000023..16000026: 1}`，超过 10 级直接拒绝。
##   拿原始数据当升级成本显示（我们之前就是这样）会**显示 1000 万而服务端只收 666**，
##   高级别时按钮还会被错误禁用 —— 这是"显示与服务端口径不一致"的典型。
const 家族最高等级 := 10
const 家族升级金币 := 666
const 家族创建材料 := 16000022
## 春夏秋冬书：捐进家族材料后，每升一级各消耗 1（服务端 `_family_contribution_item_ids` 里
## 的 16000022 是**捐献用**的书，升级只用后四本）。
const 家族升级材料: Array[int] = [16000023, 16000024, 16000025, 16000026]


## 创建家族的条件（单机版）：金币 0 + `16000022` ×1。
## 取的是 `flag["1"].cost`（原版 `FamillyManager.getFamillyCreateCfg()` 读的就是它）。
static func family_create_cost() -> Dictionary:
	var 消耗: Dictionary = family_flag_config(1).get("cost", {}) as Dictionary
	var 项目: Dictionary = 消耗.get("item", {}) as Dictionary
	var 行: Array[Dictionary] = []
	var 键: Array = 项目.keys()
	键.sort_custom(func(a, b): return int(a) < int(b) if str(a).is_valid_int() and str(b).is_valid_int() else str(a) < str(b))
	for k in 键:
		var 项 := 项目[k] as Dictionary
		行.append({"id": int(项.get("id", 0)), "count": maxi(1, int(项.get("count", 1)))})
	if 行.is_empty():
		行.append({"id": 家族创建材料, "count": 1})
	return {"money": int(float(消耗.get("money", 0))), "item": 行}


## 升级到 `等级` 的条件（单机版）：金币 666 + 春夏秋冬书各 1。
## 超过 `家族最高等级` ⇒ 返回空表（调用方据此禁用「确定」，同 `getFamillyUpgradeCfg()` 返回 null）。
static func family_upgrade_cost(等级: int) -> Dictionary:
	if 等级 <= 1 or 等级 > 家族最高等级:
		return {}
	var 行: Array[Dictionary] = []
	for 物品号 in 家族升级材料:
		行.append({"id": 物品号, "count": 1})
	return {"money": 家族升级金币, "item": 行}


## 创建窗可选的**旗帜样式**（家徽图案）。口径照原版 `FamillyCreateWindow.initView()`：
## 取 `ImgType.BangHui.flagStyle` 的键，只要**首位是 "1" 且长度 < 5** 的（即 1000~1019）。
## 实测 `数据/家族.json` 的 `flagStyle` 与 `素材/界面/原版窗口/家族/家徽_*.png` 在这 20 个上
## 完全一致，所以 `家徽图.取()` 一定能拿到图，不会出现"翻了页是空白"。
static func family_create_styles() -> Array[int]:
	_ensure_loaded()
	var 表 := 取表("家族").get("flagStyle", {}) as Dictionary
	var 出: Array[int] = []
	for 键 in 表.keys():
		var s := str(键)
		if s.begins_with("1") and s.length() < 5 and s.is_valid_int():
			出.append(int(s))
	出.sort()
	return 出


## 家族材料/物资的显示名（服务端 `_item_display_name` 同口径：查物品表，查不到给兜底）。
static func family_material_name(物品号: int, 兜底 := "家族材料") -> String:
	var 定义 := item(物品号)
	var 名 := String(定义.get("name", "")).strip_edges()
	return 名 if not 名.is_empty() else 兜底


static func item_icon_path(item_id: Variant) -> String:
	_ensure_loaded()
	var key := str(item_id)
	var icons := 取表("物品图标")
	if not icons.has(key) and key.is_valid_int():
		key = key.pad_zeros(8)
	var 路 := String(icons.get(key, ""))
	if 路.is_empty():
		# 物品图标索引是按 物品.json 那 2650 条建的 ⇒ 忍具那一族必然查不到，回退到
		# `忍具文案.icon`（值取自 `数据/原版直解清单.json`，只有**已直解**的符号才有）。
		路 = String(忍具记录(item_id).get("icon", ""))
	return 资源解析.解析(路)

static func item_icon(item_id: Variant) -> Texture2D:
	return 资源解析.纹理(item_icon_path(item_id))


## ═══ 自选礼包（`use_type == "libao_select"`，原版 `ChoiceLibaoWindow` 那一族）═══
## `数据/礼包奖励.json` 是**懒加载表**（654 条、一条 1~3 KB，绝不进主表），结构
## `{礼包id: {cost, broadcast, rewards_by_job: {组名: [{slot,item_id,count,bind,star,aptitude}]}}}`。
##
## ⚠️ 下面两个函数的**序与过滤**必须与服务端 `_authored_gift_reward_rows`
##   （`fake_flash_server.py:49562-49611`）逐条同一条：发回去的选择是 `{job, index}`，
##   `index` 是**服务端那份扁平清单的下标**。客户端这里多算/少算一行，玩家点第 3 格
##   就领到第 4 条奖励 —— 所以 `id<=0 或 count<=0` 的跳过条件也照抄，不是"顺手清洗数据"。
##   组序 = "0" 在前、本职业组在后；组内序 = 导出时已按内层键数值排好的数组序
##   （`开发工具/导出游戏数据.mjs:180-188`，与那句 AVM2 数字键枚举一致）。

## 这件礼包的 `rewards_by_job`；表里没有 ⇒ 空字典。
static func 礼包职业组(物品id: Variant) -> Dictionary:
	var 号 := str(物品id)
	var 包: Dictionary = 取表("礼包奖励").get(号, {}) as Dictionary
	if 包.is_empty() and 号.is_valid_int():
		包 = 取表("礼包奖励").get(str(int(号)), {}) as Dictionary		# 表键不补零，会话里可能带前导零
	return 包.get("rewards_by_job", {}) as Dictionary


## 「通用组 + 本职业组」拼出来的候选，每项带发回服务端要用的 `job`/`index`。
static func 礼包候选(物品id: Variant, 职业: int) -> Array:
	var 组: Dictionary = 礼包职业组(物品id)
	if 组.is_empty():
		return []
	var 职业组 := (maxi(0, 职业) / 100) * 100
	var 组名表: Array = ["0"] if 职业组 == 0 else ["0", str(职业组)]
	var 出: Array = []
	for 组名 in 组名表:
		var 行: Array = 组.get(String(组名), []) as Array
		for 条v in 行:
			var 条: Dictionary = 条v as Dictionary
			var 号 := String(条.get("item_id", ""))
			var 件 := int(条.get("count", 1))
			if 号.is_empty() or not 号.is_valid_int() or int(号) <= 0 or 件 <= 0:
				continue
			出.append({
				"job": int(String(组名)),
				"index": 出.size(),
				"item_id": 号,
				"count": 件,
				"star": int(条.get("star", 0)),
				"aptitude": int(条.get("aptitude", 0)),
			})
	return 出


## 选择窗那一枚**格子阵**要摆几枚（含尾巴的空格）= 原版 `getCellCountTotal:324-340`：
## 数**所有职业组**的行（不看职业、也不滤脏行），再 `ceil(总行数 / 5) × 5`。
static func 礼包格阵格数(物品id: Variant, 列数: int = 5) -> int:
	var 组: Dictionary = 礼包职业组(物品id)
	var 总 := 0
	for 组名 in 组:
		总 += (组[组名] as Array).size()
	return int(ceilf(总 / float(列数))) * 列数


## ═══ 「火影有礼」详情窗（`SelectGiftWindow`，`info.preview == 1` 的 libao / libao_fufei）═══
## 数据来自 `数据/礼包详情.json`（导出见 开发工具/导出礼包详情.py）。只有原版
## `StringTool.isPreviewLibao(id)` 为真的礼包才进这张表 —— `ItemWindow2.as:990-1017`
## 用它决定"先弹详情"还是"直接使用"。`type` 保留原版 `spec.type`，用于选 12 格
## （libao）还是 16 格 + 元宝栏（libao_fufei）那两套版式。
static func 礼包详情(物品id: Variant) -> Dictionary:
	var 号 := str(物品id)
	var 表 := 取表("礼包详情")
	var 条: Variant = 表.get(号)
	if not (条 is Dictionary) and 号.is_valid_int():
		条 = 表.get(str(int(号)))
	return 条 if 条 is Dictionary else {}


## 详情窗里当前职业能看到的奖励行：原版 `SelectGiftWindow.showIcon:190-225`
## 只遍历 `"0"` 与当前职业组，组内按槽号序。返回项带 `star/aptitude`，供品质覆盖层用。
static func 礼包详情物品(物品id: Variant, 职业: int) -> Array:
	var 条 := 礼包详情(物品id)
	if 条.is_empty():
		return []
	var 组: Dictionary = 条.get("items", {}) as Dictionary
	var 职业组 := (maxi(0, 职业) / 100) * 100
	var 组名表: Array = ["0"] if 职业组 == 0 else ["0", str(职业组)]
	var 出: Array = []
	for 组名 in 组名表:
		for 条v in (组.get(String(组名), []) as Array):
			var 行: Dictionary = 条v as Dictionary
			var 号 := int(行.get("id", 0))
			var 件 := int(行.get("count", 1))
			if 号 <= 0 or 件 <= 0:
				continue
			出.append({
				"item_id": str(号),
				"count": 件,
				"star": int(行.get("star", 0)),
				"aptitude": int(行.get("aptitude", 0)),
				"bind": int(行.get("bind", 0)),
				"pub": int(行.get("pub", 0)),
			})
	return 出


## ═══ 成就福袋（原版 `SuccessWindow`）═══
## 表 = `数据/宝盒.json` 的 `fudai[类型].itemid`（原版 `ImgUtil.getImg(ImgType.Box, "fudai")`，
## `StringTool.getFuDaiItemIdFromType:379-383` 按类型取 itemid）。
##
## ⚠️ `isFuDaiLeiItemByID:721-741` **第一行硬排除 15008005**（type 5 那只在原版里不是福袋族，
## 走别的分支），这里照抄 ⇒ 返回 0，不是漏抄。命中判据也是"遍历整个 fudai 比 itemid"，
## 不是号段猜测：15008001 / 15008006 / 15008007 才是福袋，15008002~04 是亲热天堂的宝书。
static func 福袋类型(物品id: Variant) -> int:
	var 号 := str(物品id)
	if not 号.is_valid_int() or int(号) == 15008005:
		return 0
	var 表: Dictionary = 取表("宝盒").get("fudai", {}) as Dictionary
	for 类型 in 表:
		var 条: Variant = 表[类型]
		# ⚠️ 表里 `itemid` 是 **int**（`数据/宝盒.json`），而 `String(15008001)` 在 GDScript 4
		#    是**非法构造** ⇒ 整句 SCRIPT ERROR、函数直接中止返回 null ⇒ `是福袋类()` 恒假、
		#    双击福袋照旧掉回 USE_ITEM —— 这就是 #74 那条链的末环（探针逮到，见 §3.261）。
		#    一律 `str()` + 数值比，两头（int 烘的 / 字符串烘的）都不挑。
		if 条 is Dictionary and int(str((条 as Dictionary).get("itemid", 0))) == int(号):
			return int(str(类型))
	return 0


## 类型 → 物品号（原版 `getFuDaiItemIdFromType`）。查不到返回空串。
## ⚠️ 返回值必须过一遍 `str(int(…))`：`数据/宝盒.json` 里烘的是 `15008001`，而 Godot 的 JSON
##    解析把这份读成了 **float** ⇒ 直接 `str()` 会给出 `"15008001.0"`，下游拿它查 `物品.json`
##    一律落空（探针实测，§3.261）。
static func 福袋物品号(类型: int) -> String:
	var 条: Variant = (取表("宝盒").get("fudai", {}) as Dictionary).get(str(类型))
	if not (条 is Dictionary) or not (条 as Dictionary).has("itemid"):
		return ""
	return str(int(str((条 as Dictionary).get("itemid"))))		# 同上：别用 `String(int)`


## ⚠️ 技能 id **必须补零到 7 位**再查：`数据/技能.json` 的键全是 7 位（"1001001"、"0009029"），
## 而服务端 39/WARP 帧下发的 id 走 `int()` 之后前导零没了（"0009029" → 9029）。
## 2026-09-27 就是这个导致**在线时角色真正的技能一个都查不到**：`服务端会话同步.应用技能` 拿到
## 9029 → 查空 → 塞进去一条 `power=0/icon=""` 的废定义 → `_rebuild_skill_slots` 把它跳过 →
## 技能槽退回离线示例数据里那两个**没学过**的技能 → 一放技能服务端就回 "这个技能还没有学习"。
static func skill(skill_id: Variant) -> Dictionary:
	_ensure_loaded()
	var result := _record("技能", _normalize_id(skill_id, 7))
	if result.is_empty():
		return result
	if not result.has("icon") or String(result.get("icon", "")).is_empty():
		result = result.duplicate(true)
		result["icon"] = skill_icon_path(result)
	return result

## 放这个技能时角色播哪个动作（原版 `AbstractAttackSkill.setStances()` 取技能记录的 `action`）。
## **表里没有不等于"随便挑一个"** —— 原版基类默认就是 `Action.alert`，所以返回 ["alert"]。
## 返回的是动作名（"stab1"/"attack"/…），调用方直接喂 `OriginalSprite.play_once`。
static func skill_stance(skill_id: Variant) -> Array:
	_ensure_loaded()
	var 动作 = 取表("技能动作").get(str(skill_id), [])
	if 动作 is Array and not 动作.is_empty():
		return 动作
	return ["alert"]

## 这个技能是不是**主动**技能（能绑快捷栏、能按出去）。
## 表里没有这条 → 按主动处理：原版拖拽端（`SkillCell.as:58`）对技能不设门槛，
## 我们只在**明确知道是被动**（`info.type_attr`）时才拦。
## 这一发放出去后，被打的人身上要飘的那条**流水字**（克制提示）。
## 原版 `AbstractSkillEffect.getPlayerSkillFlowText():501-510`：拿本技能记录的
## `info.desc.oppositeSkill`（`SkillDataTool.getDefSkill():731-735`），再去 GameData 顶层
## `String` 段的 `Skill` 子表取那条技能的 `name`（`StringTool.getSkillString():114-119`）
## ⇒ 我们已经导成 `数据/技能对手技.json`（生成器 `开发工具/导出技能对手技.py`）。
## **返回空串就是原版不飘**（`if(_loc13_)` 判的是非空）：这技能没有对手技、或文案表里查不到名字。
## 两个调用点：`DamageHandler.as:107-113`（在线 194 帧，`skillTrigger` 为 **false** 时才飘）
## 与 `AbstractSkillEffect.as:355-359`（老版客户端自己算伤害那一支）。
static func skill_flow_text(skill_id: Variant) -> String:
	_ensure_loaded()
	return String(取表("技能对手技").get(_normalize_id(skill_id, 7), {}).get("name", ""))

static func skill_is_active(skill_id: Variant) -> bool:
	_ensure_loaded()
	return bool(取表("技能主动").get(_normalize_id(skill_id, 7), true))

## 放这个技能要花多少查克拉 / 查克拉精华。
## 原版取法（`SkillDataTool.getSkillMp` / `getSkillConsumeZQ`）：查克拉按**技能等级**查表，
## 查克拉精华是个定值。表里没有这条技能时两样都给 0（= 不拦），与"表里没有"这件事分开记。
static func skill_cost(skill_id: Variant, level := 1) -> Dictionary:
	_ensure_loaded()
	var 条目 = 取表("技能消耗").get(_normalize_id(skill_id, 7), {})
	if not 条目 is Dictionary:
		return {"mp": 0, "zq": 0}
	var mp表: Dictionary = 条目.get("mp", {})
	return {
		"mp": int(mp表.get(str(maxi(1, level)), mp表.get("1", 0))),
		"zq": int(条目.get("zq", 0)),
	}

## 忍术详情区的文案与学习条件，来源见 开发工具/导出技能文案.py。
##
## 原版这两块不在 `Skill` 段里：名字与效果说明取自 GameData 顶层 `String` 段的 `Skill` 子表
## （`DataCenter.as:522` 的 `StringTool.getSkillString(id)` 与 `:535` 的 `getSkillDesc`），
## 学习条件取自 `Skill` 段的 `info.open` 与顶层 `JiNengShu`（技能书道具）段。
static func skill_text(skill_id: Variant) -> Dictionary:
	_ensure_loaded()
	## ⚠ 键要按原版 `ImgUtil.getSkillNumName:220-229` 归一化：**小于 10000 的号左补零到 7 位**
	## （`2000` → `0002000`、`3110` → `0003110`），否则这张表里所有四位数号（五枚 Debuff、
	## 四枚家族技、月读/天照）**一条都查不到**，调用方只能拿到空字典。
	var 键 := str(skill_id)
	if 键.is_valid_int() and int(键) < 10000:
		键 = 键.pad_zeros(7)
	return 取表("技能文案").get(键, {})


## 技能书道具 → 对应忍术 id 的反查（背包里双击技能书时用）。
## 原版这条关系在 `JiNengShu` 段的 `skillId`；客户端把它收在 `数据/技能文案.json` 的 `reqBook` 列里
## （`开发工具/导出技能文案.py`），所以这里反过来扫一遍。**不是**按名字猜：
## 同一本书可能对应多个忍术，表里写哪个就是哪个（目前每本一对一）。
static var _书到技能: Dictionary = {}

static func skill_id_for_book(book_id: Variant) -> String:
	_ensure_loaded()
	if _书到技能.is_empty():
		var 表: Dictionary = 取表("技能文案")
		for 编号 in 表:
			var 条目: Variant = 表[编号]
			# 表里混了一行 `"_说明": "..."` 的注释（字符串），不是忍术条目，跳过。
			if not 条目 is Dictionary:
				continue
			var 书 := String((条目 as Dictionary).get("reqBook", ""))
			if 书.is_empty():
				continue
			# 存成 8 位补零：背包里的 id 七位/八位两种写法都有（见 `物品菜单` 那段教训）。
			_书到技能[书.pad_zeros(8)] = String(编号)
	return String(_书到技能.get(String(book_id).pad_zeros(8), ""))


## 忍术【升级条件】的三个数。原版在客户端静态表里（见 开发工具/导出升级需求表.py）：
## `table[等级] = [需要人物等级, 需要金币, 需要精华]`，家族技能（id/100 为 31 或 32）走 tableFamily。
## **升到 N 级就查 table[N]**——所以技能等级不会超过人物等级。
static func skill_upgrade_req(level: int, skill_id: int) -> Array:
	_ensure_loaded()
	var 需求 := 取表("技能升级需求表")
	var 上限 := int(需求.get("maxLevel", 150))
	var 级 := clampi(level, 0, 上限)
	var 家族 := int(skill_id / 100) == 31 or int(skill_id / 100) == 32
	var 行表: Array = (需求.get("tableFamily", []) if 家族 else 需求.get("table", [])) as Array
	if 级 >= 行表.size() or not (行表[级] is Array):
		return [0, 0, 0]
	return 行表[级] as Array


static func skill_icon_path(skill_record: Dictionary) -> String:
	_ensure_loaded()
	var class_name_value := String(skill_record.get("icon_class", ""))
	if class_name_value.is_empty():
		return ""
	var index := 取表("技能素材")
	return 资源解析.解析(String(index.get(class_name_value, "")))

static func map_name(map_id: Variant) -> String:
	_ensure_loaded()
	return String(取表("地图名").get(str(map_id), str(map_id)))

static func copies() -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	var records := 取表("副本")
	for key in records:
		var record: Dictionary = (records[key] as Dictionary).duplicate(true)
		record["id"] = int(record.get("id", key))
		result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	return result

## 活跃度奖励档位，**按档位序号升序**（0 基）。
##
## 真值出处：GameData 的 `Huoyuedu.info`（导出见 `开发工具/导出活跃度奖励.py`）。
## 键是**原样**的 GameData 字段名 —— 不翻译，理由同 `装备打造表.gd`：
##   改一次名就等于把同一份真值抄成两份，抄漏一个字段客户端会**静默**错。
##   每档：`reqScore`（所需活跃分）/ `exp`（经验系数，实发 = exp × 等级³ ÷ 100）
##        / `dianjuan`（点券）/ `itemId1`,`cnt1`,`itemId2`,`cnt2`（两件物品与数量，0 表示没有）
##
## ⚠️ 别把服务端 `2326:0` 帧里那 15 项**每日任务次数**当成这里的需求分 ——
##    那个是 `authoritative_activity.task_counts`，和奖励档位是两回事。
static func 活跃度档位() -> Array[Dictionary]:
	_ensure_loaded()
	var 段 := 取表("活跃度奖励").get("info", {}) as Dictionary
	var 键 := 段.keys()
	键.sort_custom(func(a, b): return int(a) < int(b))
	var 出: Array[Dictionary] = []
	for 号 in 键:
		if 段[号] is Dictionary:
			出.append(段[号])
	return 出


## 活跃度「有没有一档够分可领」。
##
## 真值：`ActivityTaskWindow.setDataBottom:272-282` 的
## `param1 < 7 && levelArr[param1+1] <= param2`（`param1` = 已领档位、-1 = 一档没领，
## `param2` = 总活跃分）。`SmallMapWindow.setHuoyueduBtn:418-433` 拿这个结果决定
## 小地图活跃度图标挂不挂呼吸光晕 —— 没得领时 `filters = null`，光晕整块消失。
##
## 「领取奖励」钮的可点性与小地图光晕共用这一条，别各写一份（两边就容易漂）。
static func 活跃度可领(状态: Dictionary, 档位: Array = []) -> bool:
	if 档位.is_empty():
		档位 = 活跃度档位()
	var 下档 := int(状态.get("claimed_level", -1)) + 1
	return 下档 >= 0 and 下档 < 档位.size() \
		and int((档位[下档] as Dictionary).get("reqScore", 0)) <= int(状态.get("points", 0))


## 「线上有礼」的三档门槛，**按小时升序**。真值出处：GameData `Gift.monthly`
## （导出见 `开发工具/导出礼包配置.py`；服务端读同一份：`monthly_online_rewards():7433`）。
## 每档：`hours`（本周在线小时门槛）/ `cashbind`（达标给的点券）。
## 原版 `PrizeOnlinePane2.as:236-250` 就是拿 `本周分钟/60` 依次比这三档决定图标亮暗与进度条。
static func 线上有礼档位() -> Array[Dictionary]:
	_ensure_loaded()
	var 段 := 取表("礼包").get("monthly", {}) as Dictionary
	var 键 := 段.keys()
	键.sort_custom(func(a, b): return int(a) < int(b))
	var 出: Array[Dictionary] = []
	for 号 in 键:
		if 段[号] is Dictionary:
			出.append(段[号])
	return 出


## 每日签到第 `天`（1..7）给的奖励，形如 `[{itemId, count}, …]`。
## 真值出处：GameData `Gift.everyday.dayN`（键是 `item1/item2/…`，值是 `{itemId, count}`）。
## ⚠️ 原表里 `count` 是**字符串**，这里统一转 int —— 别在调用处再各写一遍 int()。
static func 每日签到奖励(天: int) -> Array[Dictionary]:
	_ensure_loaded()
	var 行: Variant = 取表("礼包").get("everyday", {}).get("day%d" % 天, null)
	var 出: Array[Dictionary] = []
	if 行 is not Dictionary:
		return 出
	for 键 in (行 as Dictionary).keys():
		var 项: Variant = (行 as Dictionary)[键]
		if 项 is Dictionary and int((项 as Dictionary).get("itemId", 0)) > 0:
			出.append({
				"itemId": int((项 as Dictionary).get("itemId", 0)),
				"count": int((项 as Dictionary).get("count", 0)),
			})
	return 出


## 活跃度的 15 个每日任务槽位，**按槽位序号升序**（0 基）。
##
## 真值出处：同一个 GameData 段的 `Huoyuedu.taskInfo`（同一份 数据/活跃度奖励.json，
## 导出见 `开发工具/导出活跃度奖励.py` —— 它把整段一起落盘，不止 `info`）。
## ⚠️ **槽位顺序**就是服务端 `2326:0` 帧里那 15 个次数的顺序，也是原版
##    `ActivityTaskWindow.setLeftCount()` 逐行 setCount 的顺序 —— 三个顺序是同一个，
##    别按名字重排。
## 每槽：`count`（所需次数，行文本的分母）/ `name` / `des` / `icon`（元件名）/ `open`（0 无链接）。
static func 活跃度任务() -> Array[Dictionary]:
	_ensure_loaded()
	var 段 := 取表("活跃度奖励").get("taskInfo", {}) as Dictionary
	var 键 := 段.keys()
	键.sort_custom(func(a, b): return int(a) < int(b))
	var 出: Array[Dictionary] = []
	for 号 in 键:
		if 段[号] is Dictionary:
			出.append(段[号])
	return 出


## 金币掉落物的图标。原版 `PicTool.getMesoPic(数量)`（`PicTool.as:383-403`）按数量分四档：
##   <100 → 90000000 / <500 → 90000001 / <1000 → 90000002 / 其余 → 90000003。
## 每一档是一段 **4 帧动画**（`ItemPic.TYPE_MESO` → `FrameQueueAnimation`），
## 逐帧延时取 `FrameQueueAnimation.calculate():119` 的**默认值 100ms**（=10fps）——
## 真值本该在物品定义的 `iconRaw` 里，但服务端 GameData 没建模这一段，取不到。
## ⚠️ 这四个 id（9000000x）**不在服务端的物品表里**（服务端叫"未知物品"），
##    所以这里不走 `取表("物品")`，直接按素材路径拼 —— 素材由
##    `2.2.3/map_extract/out/cache/FuZhuWuPin_9000000X_iconRaw/` 拷进 `素材/物品/原版/FuZhuWuPin/`。
## ⚠ **每帧必须垫成同一尺寸**：`AnimatedTexture` 内部把各帧叠成一张 texture array，
##   尺寸不齐时取到的宽高是错的（10-12 实测：90000000 报 23×24、90000002 报 32×30，
##   而它们各自的**最大**帧是 25×24 / 33×30 ⇒ 有一列被切掉），采样越界在部分机器上
##   就是"整块变纯白"（用户 10-12 报的现象：金币**有时**图标直接变纯白 —— 四档里
##   90000003 的 4 帧本来就同为 32×31，所以那一档不会犯）。
##   垫法：**底边对齐 + 水平居中** —— 钱堆是站在地面上转的，底边不能跳。
static var _金币贴图表: Dictionary = {}

static func 金币图标(数量: int) -> Texture2D:
	var 档 := 90000000
	if 数量 >= 1000:
		档 = 90000003
	elif 数量 >= 500:
		档 = 90000002
	elif 数量 >= 100:
		档 = 90000001
	if _金币贴图表.has(档):
		return _金币贴图表[档]
	var 原: Array[Image] = []
	for i in 4:
		var 路径 := "res://素材/物品/原版/FuZhuWuPin/FuZhuWuPin_%d_iconRaw_%d.png" % [档, i]
		if not ResourceLoader.exists(路径):
			continue
		var 贴 := load(路径) as Texture2D
		if 贴 == null:
			continue
		var 图 := 贴.get_image()
		if 图 == null:
			continue
		图.convert(Image.FORMAT_RGBA8)
		原.append(图)
	if 原.is_empty():
		push_warning("金币钱堆一档都没有（档 %d）⇒ 掉落物会是空的" % 档)
		return null
	var 宽 := 0
	var 高 := 0
	for 图 in 原:
		宽 = maxi(宽, 图.get_width())
		高 = maxi(高, 图.get_height())
	var 帧表: Array[Texture2D] = []
	for 图 in 原:
		var 垫 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
		垫.blend_rect(图, Rect2i(0, 0, 图.get_width(), 图.get_height()),
				Vector2i((宽 - 图.get_width()) / 2, 高 - 图.get_height()))
		帧表.append(ImageTexture.create_from_image(垫))
	var 动 := AnimatedTexture.new()
	动.frames = 帧表.size()
	for i in 帧表.size():
		动.set_frame_texture(i, 帧表[i])
		# ⚠️ Godot 4.7 的 `AnimatedTexture` **没有 `fps`**（写了会报 Invalid assignment），
		#    逐帧时长是 `frame_N/duration`，**单位是秒** → 100ms 写 0.1。
		动.set_frame_duration(i, 0.1)
	_金币贴图表[档] = 动
	return 动


static func monster_name(monster_id: Variant) -> String:
	var data := monster(monster_id)
	return String(data.get("name", str(monster_id)))

static func npc_name(npc_id: Variant) -> String:
	var data := npc(npc_id)
	return String(data.get("name", str(npc_id)))

static func item_name(item_id: Variant) -> String:
	var data := item(item_id)
	return String(data.get("name", str(item_id)))


## 物品的 `detaildesc`（商城说明框的绿字）。查不到返回空串 —— 大部分消耗品本来就没有这一行。
## 出处链：`StringTool.getItemStringObject(id)`（`StringTool.as:636`）→ GameData 的
## `String/<组>/<物品id>.detaildesc`，见 开发工具/导出物品详情文案.py。
static func item_detail(item_id: Variant) -> String:
	_ensure_loaded()
	var 详情: Dictionary = 取表("物品详情文案").get("详情", {}) as Dictionary
	var key := str(item_id)
	if not 详情.has(key) and key.is_valid_int():
		key = key.pad_zeros(8)
	var 文 := String(详情.get(key, ""))
	if 文.is_empty():
		# 物品详情文案那张表只并了商城那八个 String 组 ⇒ 忍具段查不到，回退 `String/RenJu.detaildesc`。
		文 = String(忍具记录(item_id).get("detaildesc", ""))
	return 文

static func skill_name(skill_id: Variant) -> String:
	if int(skill_id) == 0:
		return "普通攻击"
	var data := skill(skill_id)
	return String(data.get("name", str(skill_id)))

## ── 意志（Spirit）──────────────────────────────────────────────────────────
## 协议帧里的 color 是 **SpiritColor 枚举 int**（原版 `SpiritColor.as:6-20`：
## 1灰2绿3蓝4紫5粉6黄7红8淡粉）；夹具 `SPIRIT_COLOR_IDS` 与之同序。
## `YiZhiData.setColor:175-201` 收的却是 dat 里的色**名字符串**（gray/blue/…），
## 所以查表前要先过这一张。
const 意志色名 := {1: "gray", 2: "green", 3: "blue", 4: "pueple", 5: "pink", 6: "yellow", 7: "red", 8: "lpink"}

## 图鉴一行（`数据/意志图鉴.json`，键是**不补零**的意志 id）。
static func 意志图鉴项(编号: Variant) -> Dictionary:
	return 取表("意志图鉴").get(str(编号), {}) as Dictionary

## 融合经验的**色系基础值表**（`数据/意志.json` 的 `common.levelUp.level1`：
## blue60/green30/pueple120/pink240/lpink480/red480；**没有 gray** ⇒ 灰件贡献 0）。
static func 意志融基础表() -> Dictionary:
	var 意志 := 取表("意志")
	var 常 := 意志.get("common", {}) as Dictionary
	var 级 := 常.get("levelUp", {}) as Dictionary
	return 级.get("level1", {}) as Dictionary

## 单件意志给出的融合经验 —— 原版 `YiZhiData.rongHeExp:92-101`：
##   **黄 ⇒ 固定 1200**；其余 ⇒ `common.levelUp.level1[色名] + 自身 exp`。
## ⚠️ 协议第 4 列 exp 是**原始经验**（`SpiritState.experience`，新学得的件恒 0），
##    **不是** rongHeExp —— 2026-10-21 修：原 `游戏会话.意志力()` 只加这一列，
##    于是蓝件（基础 60）也显示 0，人物面板「意志：0」（用户实机报）。
## ⚠️ level1 表里**没有 gray 这一档**：原版 `_loc2_["gray"] + exp` 在 AS3 里是
##    `undefined + exp` = NaN，函数声明 `:int` ⇒ 收敛成 **0**（不是 0+exp）。
##    门 `人物窗意志格回归测试` 钉着这条（灰件 exp=999 也必须是 0）。
static func 意志融经验(行: Dictionary) -> int:
	var 色 := str(意志色名.get(int(行.get("color", 0)), ""))
	if 色 == "yellow":
		return 1200
	var 基础 := 意志融基础表()
	if not 基础.has(色):
		return 0
	return int(基础.get(色, 0)) + int(行.get("exp", 0))

## ⚠️ 意志力悬停提示正文**不在这里**：唯一一份是 `组件/意志提示框.gd:意志力提示文案()`
##    （原版 `YiZhiManager.getYiZhiPropToopTioInfo:392-405`）。合并 `意志模块` 时分支在这里
##    抄了第二份 `意志提示文()`，主线 §3.234 的活路（`人物窗口._挂文字提示` / `意志窗口._接意志力提示`
##    → 意志提示框）根本不走它 ⇒ 已删，别再抄回来。

static func _record(table_name: String, record_id: Variant) -> Dictionary:
	return 取表(table_name).get(str(record_id), {})

static func _normalize_id(value: Variant, width: int) -> String:
	var text := str(value)
	return text.pad_zeros(width) if text.is_valid_int() else text

static func _ensure_loaded() -> void:
	if _tables.is_empty():
		reload()

static func _load_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("游戏数据：无法读取 %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	if not parsed is Dictionary:
		push_error("游戏数据：格式错误 %s" % path)
		return {}
	return parsed

static func _merge_dictionaries(base: Dictionary, extension: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in extension:
		if result.get(key) is Dictionary and extension[key] is Dictionary:
			result[key] = _merge_dictionaries(result[key], extension[key])
		else:
			result[key] = extension[key]
	return result

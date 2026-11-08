extends RefCounted

## 装备打造（强化 / 进阶 / 破碎修复 …）的消耗与成功率 —— 读 `数据/装备打造.json`。
##
## 那张表是服务端 GameData `EquipSystem` 整段的**原样导出**（23 段，
## 生成器 `开发工具/导出装备强化表.py`）。**字段名一律用服务端自己的**
## （`prob` / `needItemId` / `maxHelpCnt` / `addRatio` …），不做中文改名 ——
## 改名等于把真值抄两份，抄漏一个字段客户端就静默错
## （实测：`stageup.stage2` 还有 `probLoseAptitude` / `keepStrengthItemId` 这些，
##   手抄一遍必漏）。
##
## ## 权威读法（客户端必须与服务端一致）
##
## 服务端 `_forge_strength_level`（`fake_flash_server.py:54563`）：
## ```
## config = EquipSystem.strength["level<下一级>"]
## 成功后 strength_level → 下一级
##        strength_value = round(base_attr_value * addRatio / 100)
## ```
## 成功率在 `_roll_forge`（`:54391-54394`）：
## ```
## chance = min(100, max(0, prob + 幸运符颗数 * 3)); randrange(100) < chance
## ```
## 消耗在 `_consume_forge_cost`（`:54362` 起）：
## ```
## needItemId × needItemCnt 个材料 + needMoney 金币；幸运符最多 maxHelpCnt 颗
## ```
##
## ⚠️ **普通强化 10 级封顶**（`:54270` 的 `next_level > 10` 就报
## 「已达普通强化上限，请使用百炼升到 11 级。」）。表里的 `strength.level11`
## 是**百炼**那条路（材料换成精炼锤 15028002、成功率 3%），别当成第 11 次普通强化。
##
## 客户端实测（照抄表，别改）：强化 level1..10 材料都是**强化灵珠 16000016**，
## 数量 1/2/5/10/20/40/60/80/120/180，**金币恒为 0**，成功率 100/90/80/70/60/50/40/35/30/25。
## → 原来写死的「金币 (等级+1)*100、成功率 100%」**两条都是错的**。

const 路径 := "res://数据/装备打造.json"
## 普通强化的等级上限（服务端 `_forge_strength_level` 的 `next_level > 10`）。
const 强化上限 := 10
## 每颗幸运符加多少个百分点（`_roll_forge` 里的那个 3）。
const 幸运符加成 := 3

static var _表: Dictionary = {}
static var _物品表: Dictionary = {}


static func _读表() -> Dictionary:
	if not _表.is_empty():
		return _表
	if not FileAccess.file_exists(路径):
		push_error("装备打造表缺失：%s（跑 开发工具/导出装备强化表.py 生成）" % 路径)
		return {}
	var 解析: Variant = JSON.parse_string(FileAccess.get_file_as_string(路径))
	if typeof(解析) != TYPE_DICTIONARY:
		push_error("装备打造表不是合法 JSON 对象：%s" % 路径)
		return {}
	_表 = 解析 as Dictionary
	return _表


## 取一整段（`strength` / `stageup` / `crash` / `inlay` …）。
static func 取段(段名: String) -> Dictionary:
	var 段: Variant = _读表().get(段名, {})
	return 段 as Dictionary if typeof(段) == TYPE_DICTIONARY else {}


## 强化到 `目标等级` 那一次的配置（`目标等级` = **强化后**的等级，1..10）。
static func 取强化(目标等级: int) -> Dictionary:
	return _取条(取段("strength"), "level%d" % 目标等级, "strength.level%d" % 目标等级)


## 宝石合成到 `目标等级` 那一次的配置（`merge.level{目标}` = `{needMoney, prob}`）。
## 原版客户端 `StringTool.getBaoShiMergeZhenqi/getBaoShiMergeRatio`（`StringTool.as:488-534`）
## 和服务端 `_merge_equipment_stone`（`fake_flash_server.py:54226`）读的是**同一行**：
## 键取「**合成后**那颗的等级」（stoneLevel+1）。表里**本来就没有**的行（勾玉 11..15 级——
## 满级 15 的链顶到不了合成、`level1` 也没有，最低合成目标就是 level2）返回空字典，
## 调用方按缺省 0 处理 —— 客户端显 0 金币/0%、服务端 `merge_config=None` 掷必败，口径一致。
## ⚠️ 这里**不走 `_取条`**：它对缺行 `push_error`，而合成页每次渲染都要查，会刷屏。
static func 取宝石合成(目标等级: int) -> Dictionary:
	var 条: Variant = 取段("merge").get("level%d" % 目标等级, {})
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 勾玉合成到 `目标等级` 那一次 —— `EquipSystem.jade.merge.level{目标}`。
## 出处 `GouYuCompositePanel.setConfigure:296-306`：`ObjectAccessor.getFromObject(整段,["jade","merge","level"+级])`，
## 级 = `StoneData.level + 1`。字段只有 `needItemCnt` / `needItemId` / `prob`（精玉灵珠）；
## **`needMoney` 是客户端写死的 0**（同一段 `:302` `_configure.needMoney = 0`），表里本来就没这列。
## 与普通宝石的 `EquipSystem.merge` **不是同一段** —— 后者是 10 级宝石那颗，勾玉最高 15 级。
## 缺行（满级 15 没有 level16）返回空 ⇒ 调用方走 0 金币 0%。
static func 取勾玉合成(目标等级: int) -> Dictionary:
	var 条: Variant = 取段("jade").get("merge", {}).get("level%d" % 目标等级, {})
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 勾玉重置那一次 —— `EquipSystem.jade.change.level{max(1, 勾玉等级)}`。
## 出处 `GouYuResetPanel.setConfigure:160-164`：级 = `level <= 0 ? 1 : level`（**重置不升级**，
## 取的是当前等级那一行，不是下一级）。字段 `needMoney` / `prob`。
static func 取勾玉重置(等级: int) -> Dictionary:
	var 条: Variant = 取段("jade").get("change", {}).get("level%d" % maxi(1, 等级), {})
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 「宝石幸运合成」的三个真值 —— 逐条照原版 `StoneLuckyCompositeWindow.as:31-37` 的常量。
## 三处互证（§3.100）：AS3 常量、语言表本页说明、以及**物品表里那颗道具自己的描述**
## （「使用一张增加3%宝石合成成功几率，最大允许使用20张」）—— 三者逐字吻合。
## 服务端侧的同名常量在 `服务端/runtime/tools/fake_flash_server.py` 文件尾。
const 宝石幸运符id := 16000556      ## `LUCKY_HELP_ITEM_ID`
const 宝石幸运符上限 := 20          ## `LUCKY_MAX_COUNT`
const 宝石幸运符每张加成 := 3       ## `LUCKY_RATIO_PER_CHARM`


## 进阶到 `目标阶数` 那一次的配置。
static func 取进阶(目标阶数: int) -> Dictionary:
	return _取条(取段("stageup"), "stage%d" % 目标阶数, "stageup.stage%d" % 目标阶数)


## **玉链升阶**那一次的配置 —— `EquipSystem.special.stageup.stage{阶+1}`。
## 出处 `YuLianUpgragePanel.setConfigure:187-190`：
## `ObjectAccessor.getFromObject(整段,["special","stageup","stage" + (阶 + 1)])`。
## ⚠️ 与顶层 `stageup` 段**不是同一份**：顶层那块带材料/保级道具（装备进阶窗用的），
## `special.stageup` 只有 `needMoney` / `prob`（玉链升阶不消耗材料）。两个都叫 stageup，别串。
static func 取特殊进阶(目标阶数: int) -> Dictionary:
	var 段: Variant = 取段("special").get("stageup", {})
	if typeof(段) != TYPE_DICTIONARY:
		return {}
	return _取条(段 as Dictionary, "stage%d" % 目标阶数, "special.stageup.stage%d" % 目标阶数)


## 洗附加属性那一次的配置 —— 原版 `StringTool.getResetEquipPropConfig()`（`StringTool.as:822-826`）
## 取的是 **`EquipSystem.changeAptitude`**（**不是** `resetStrength`，我一度搞混）。
##
## 形状：共享的 `needItemId` / `helpItemId` / `maxHelpCnt` / `probUp`，
## 外加 `apt1..apt4` 各自带 `needItemCnt` / `needMoney` / `prob` —— 面板拿共享那份，
## 再用 `apt<资质>` **逐项覆盖**（`EquipPropResetPanel.getPropRestCfg`）。
##
## ⚠️ **橙(5) 当紫(4) 用**：那一步写死了 `ORANGE → PURPLE`。
static func 取洗附加属性(资质: int) -> Dictionary:
	var 段 := 取段("changeAptitude")
	if 段.is_empty():
		return {}
	var 条 := 段.duplicate(true)
	var 档 := 4 if 资质 == 5 else 资质
	var 覆盖: Variant = 段.get("apt%d" % 档, null)
	if typeof(覆盖) == TYPE_DICTIONARY:
		for 键 in (覆盖 as Dictionary):
			条[键] = (覆盖 as Dictionary)[键]
	return 条


## 洗附加数值那一次的配置 —— `EquipSystem.plus.washvalue`。
## 出处 `EquipPropLianZhiPanel.getPropRestCfg(true)`（`:448-470`）：
##   `整段 = plus[isWashProp ? "washvalue" : "addcnt"]`
##   `needItemCnt` = `need["stage" + 阶]["plus" + 附加属性条数].needItemCnt`
##   `needMoney`   = `need["stage" + 阶].needMoney`
##   ⚠️ **`prob` 是写死的 100**（那函数里就一句 `_loc4_.prob = 100`）—— 不是配置里的值。
## 另外：`plus1` 的 `needItemCnt` 是 **0**（只有一条附加属性时不消耗材料）。
static func 取洗附加数值(阶数: int, 附加条数: int) -> Dictionary:
	var 段: Variant = 取段("plus").get("washvalue", null)
	if typeof(段) != TYPE_DICTIONARY:
		return {}
	var 整段 := 段 as Dictionary
	var 需: Variant = 整段.get("need", {})
	if typeof(需) != TYPE_DICTIONARY:
		return {}
	var 档: Variant = (需 as Dictionary).get("stage%d" % 阶数, null)
	if typeof(档) != TYPE_DICTIONARY:
		return {}
	var 条: Variant = (档 as Dictionary).get("plus%d" % 附加条数, null)
	return {
		"needItemId": int(整段.get("needItemId", 0)),
		"needItemCnt": int((条 as Dictionary).get("needItemCnt", 0)) if typeof(条) == TYPE_DICTIONARY else 0,
		"needMoney": int((档 as Dictionary).get("needMoney", 0)),
		"prob": 100,
	}


## 天生属性强化那一次的配置 —— `EquipSystem.born`。
## 出处 `EquipManager.getStrengthTianShengPropCfg(位置, 阶数)`（`:600-615`）：
##   `needItemId` = `born.needItemId`（共享）
##   `needMoney`  = `born.needMoney["stage" + 阶数]`
##   `needItemCnt`/`prob` = `born[<位置对应的 EquipX>]`（**按部位**取，不是按阶）
## 位置→`EquipX` 就是 `cell0..cell11 = EquipA..L`（§3.12.1），即 武器→A … 斗篷→L。
const _天生部位名 := {
	-1: "EquipA", -2: "EquipB", -3: "EquipC", -4: "EquipD",
	-5: "EquipE", -6: "EquipF", -7: "EquipG", -8: "EquipH",
	-9: "EquipI", -10: "EquipJ", -11: "EquipK", -12: "EquipL",
}

static func 取天生(位置: int, 阶数: int) -> Dictionary:
	var 段 := 取段("born")
	if 段.is_empty():
		return {}
	var 名: String = String(_天生部位名.get(位置, ""))
	if 名.is_empty():
		return {}          # 非标准 12 槽（神器/灵器/忍具…）没有天生强化配置
	var 部位: Variant = 段.get(名, null)
	if typeof(部位) != TYPE_DICTIONARY:
		return {}
	var 金额: Variant = 段.get("needMoney", {})
	return {
		"needItemId": int(段.get("needItemId", 0)),
		"needMoney": int((金额 as Dictionary).get("stage%d" % 阶数, 0)) if typeof(金额) == TYPE_DICTIONARY else 0,
		"needItemCnt": int((部位 as Dictionary).get("needItemCnt", 0)),
		"prob": int((部位 as Dictionary).get("prob", 0)),
	}


## 刻印那一次的配置 —— `EquipSystem.carve.req.<阶数>`。
## 出处：`EquipKeYinPanel.getKeYinCfg()` 里
## `ObjectAccessor.getFromObject(整段, ["carve", "req", 档])`（`EquipKeYinPanel.as:191-197` 附近），
## 档 = 装备的阶。字段：`needItemId` / `needItemCnt` / `needMoney` / `prob`，
## 另有 `keepItemId` / `keepItemCnt`（**保级道具**，不是每个阶都有）。
##
## ⚠️ 2026-10-01 更正一条旧注：这里原先写"刻印页**不自建按钮**、复用 `_strengthBtn`" ——
## **是错的**：`EquipKeYinPanel.as:252` 自己 `new` 了 `_keYinBtn`（x=50 写死）。
## 窗口那个执行按钮在这一页要**藏掉**、接线接面板这个（功能窗口 `_配置面板页` 就是这么做的）。
static func 取刻印(阶数: int) -> Dictionary:
	var 段 := 取段("carve")
	var 表: Variant = 段.get("req", null)
	if typeof(表) != TYPE_DICTIONARY:
		push_error("装备打造表的 carve 段没有 req")
		return {}
	return _取条(表 as Dictionary, "stage%d" % 阶数, "carve.req.stage%d" % 阶数)


## 已刻印装备的那行"秘印属性"要查的配置 —— `EquipSystem.carve.value.<carve_id>`。
## 出处：`StringTool.getCarveValueConfig(id)`（`EquipKeYinPanel.as:322`），
## 字段 `name` / `type`（属性英文名）/ `value_max` / `value_min`。
static func 取刻印值(刻印id: int) -> Dictionary:
	var 段 := 取段("carve")
	var 表: Variant = 段.get("value", null)
	if typeof(表) != TYPE_DICTIONARY:
		return {}
	var 条: Variant = (表 as Dictionary).get(str(刻印id), null)
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 精炼页下拉框的两个精炼项 —— 两项**各有各的配置来源**，不是同一份配置换个文案：
##   * 第 0 项「提升附加属性」→ `EquipSystem.forgeAdditive`
##     （`EquipBaiLianPanel.as:319-322`：`ObjectAccessor.getFromObject(整段,["forgeAdditive"])`）
##   * 第 1 项「提升强化星级」→ `EquipSystem.strength.level11`
##     （`:316`：`StringTool.getStrengthEquipConfig(11)` —— 就是 `取强化(11)` 那条**百炼**配置）
## 两边的 `needItemId` 都是**精炼锤 15028002**，差别在成功率（附加属性 7% / 强化星级 3%）。
##
## ⚠️ 下拉的次序照语言表 `EQUIPBAILIAN_JINGLIAN_TYPE`（"提升附加属性,提升强化星级"）
## **split(",") 之后的数组下标**，而且面板 `createChildren()` 末尾写死了 `selectedIndex = 0`
## —— 所以默认落在**附加属性**那一项。
const 精炼项_附加属性 := 0
const 精炼项_强化星级 := 1

static func 取精炼(项: int) -> Dictionary:
	if 项 == 精炼项_强化星级:
		return 取强化(11)
	return 取段("forgeAdditive")


## 附加属性的**上限表** —— 出处 `StringTool.getPlusPositionConfig(阶数, 部位类型名)`
## （`StringTool.as:23-27`）：`EquipSystem.plus["stage" + 阶数][<部位类型名>]`。
##
## 形状是**按序号键**的字典，每项 `{type(英文属性名), valueFrom, valueTo}`：
##   `{"0": {"type":"atk","valueFrom":4,"valueTo":7}, "1": {...}}`
## 提示框拿它跟装备上**实际**的附加属性逐条比对，决定那一行怎么写：
## 到顶了写【梦幻满值】，没到顶写「最大可提升至+N」。
##
## 部位类型名就是 `EquipA..L`（武器…斗篷），另有 `EquipS1` / `PetA` 等；
## 客户端从 `数据/物品装备元数据.json` 的 `type_name` 取（生成器 `开发工具/导出装备元数据.py`）。
## **查不到就返回空**——原版那时走"只印属性本身"那条分支，别硬编一个上限。
static func 取附加属性上限(阶数: int, 部位类型名: String) -> Dictionary:
	if 部位类型名.is_empty():
		return {}
	var 段: Variant = 取段("plus").get("stage%d" % 阶数, null)
	if typeof(段) != TYPE_DICTIONARY:
		return {}
	var 条: Variant = (段 as Dictionary).get(部位类型名, null)
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 破碎修复那一次的配置（`crash` 段本身就是一条，不分级）。
static func 取破碎修复() -> Dictionary:
	return 取段("crash")


## 「梦幻属性符」那件物品的 id（`EquipSystem.plus.fullone.needItemId`）。
## 原版 `MengHuanPropResetWindow.showPropPanle` 把**点的那一格**当材料，这里按表反查同一件。
static func 梦幻属性符id() -> int:
	var 全: Variant = 取段("plus").get("fullone", {})
	if typeof(全) != TYPE_DICTIONARY:
		return 0
	return int((全 as Dictionary).get("needItemId", 0))


## 「橙装打造 / 橙装精炼」两件材料的 id。原版 `ItemType.isItemCanDaZao` / `isItemCanJingLian`
## 就是拿 `EquipSystem.changeToOrange.needItemId` / `changeTaleAttribute.needItemId` 反查
## （`ItemType.as:385-394 / :102-111`）⇒ 这两个入口和 `_use_item` 的分派必须读同一处。
static func 橙装打造石id() -> int:
	return int(取段("changeToOrange").get("needItemId", 0))


static func 橙装精炼石id() -> int:
	return int(取段("changeTaleAttribute").get("needItemId", 0))


## 橙装打造那一次的配置（`YellowEquipLianZhiWindow.getEquipDaZaoCfg:219-242`）：
## 根段给 `needItemId`，**按部位类型名**（`EquipA..L` / `PetA..D`）取 `needItemCnt`。
## 原版在客户端把 `prob` 强置 100、`needMoney` 强置 0（显示口径；服务端另读同一段）。
static func 取橙装打造(部位类型名: String) -> Dictionary:
	var 根 := 取段("changeToOrange")
	var 配置: Dictionary = {}
	var 条: Variant = 根.get(部位类型名, null)
	if typeof(条) == TYPE_DICTIONARY:
		配置 = (条 as Dictionary).duplicate()
	配置["needItemId"] = int(根.get("needItemId", 0))
	配置["needMoney"] = 0
	配置["prob"] = 100
	return 配置


## 橙装精炼（`getEquipJingLianCfg:96-106`：`changeTaleAttribute`，原版同样强置 prob=100/needMoney=0）。
static func 取橙装精炼() -> Dictionary:
	var 配置 := 取段("changeTaleAttribute").duplicate()
	配置["needMoney"] = 0
	配置["prob"] = 100
	return 配置


## NPC 商店「装备修理」的**单点耐久价**（`StringTool.getEtcXiuliPrice(stage)` 返回的那一对：
## `[0] = naijiu.repair.stageN.normalPrice`、`[1] = specialPrice`）。
## 一件装备的费用 = `(最大耐久 - 当前耐久) × 本函数`；服务端 `_repair_all_equipped`
## 读的是**同一行同一个字段**，两边的合计必须能对上。
## 查不到行/字段返回 0 ⇒ 调用方把这件当"修不了"跳过（服务端同口径跳过、不计入合计）。
static func 取修理价(阶数: int, 特殊: bool) -> int:
	var 修理: Variant = 取段("naijiu").get("repair", {})
	if typeof(修理) != TYPE_DICTIONARY:
		return 0
	var 条: Variant = (修理 as Dictionary).get("stage%d" % 阶数, {})
	if typeof(条) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((条 as Dictionary).get("specialPrice" if 特殊 else "normalPrice", 0)))


static func _取条(段: Dictionary, 键: String, 全名: String) -> Dictionary:
	var 条: Variant = 段.get(键, {})
	if typeof(条) != TYPE_DICTIONARY:
		push_error("装备打造表里没有 %s" % 全名)
		return {}
	return 条 as Dictionary


## 加上幸运符之后的实际成功率（百分数，封顶 100）。照 `_roll_forge`。
static func 实际成功率(配置: Dictionary, 幸运符颗数: int = 0) -> int:
	return mini(100, maxi(0, int(配置.get("prob", 0)) + maxi(0, 幸运符颗数) * 幸运符加成))


## 这一次能用几颗幸运符（配置里的 `maxHelpCnt`；0 = 这个操作不能用幸运符）。
static func 幸运符上限(配置: Dictionary) -> int:
	return maxi(0, int(配置.get("maxHelpCnt", 0)))


## 材料/幸运符的名字。查 `数据/物品.json` —— 物品名的唯一真值源。
static func 物品名(物品id: int) -> String:
	if _物品表.is_empty():
		var 解析: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/物品.json"))
		_物品表 = 解析 as Dictionary if typeof(解析) == TYPE_DICTIONARY else {}
	for 键 in [str(物品id), str(物品id).lstrip("0")]:
		var 条: Variant = _物品表.get(键, null)
		if typeof(条) == TYPE_DICTIONARY:
			return String((条 as Dictionary).get("name", ""))
	return ""


## "强化灵珠 × 5" / "金币 10000" 这种给人看的一行（金币为 0 就不写那一行，
## 因为服务端 `needMoney=0` 根本不扣钱，写出来是噪音）。
static func 消耗文案(配置: Dictionary) -> String:
	if 配置.is_empty():
		return ""
	var 行: Array[String] = []
	var 材料id := int(配置.get("needItemId", 0))
	var 材料数 := maxi(0, int(配置.get("needItemCnt", 0)))
	if 材料id != 0 and 材料数 > 0:
		var 名 := 物品名(材料id)
		行.append("%s × %d" % [名 if not 名.is_empty() else str(材料id), 材料数])
	var 金币 := maxi(0, int(配置.get("needMoney", 0)))
	if 金币 > 0:
		行.append("金币 %d" % 金币)
	return "\n".join(行)


## 背包里某个物品有几件（界面拿它显示"拥有 N"、决定按钮能不能点）。
## ⚠ 原版 `DataCenter.isBagExistItem:3166-3182` 是**同 id 各摞累加**（`_loc2_ += quantity`），
##   原来这里 `return` 在循环里 ⇒ 只报**第一摞**：材料拆成两摞时角标偏小、该亮的格恒灰、
##   「你没有足够的镇灵石」这种拒绝也会误发（2026-10-25 做昆虫强化面板 §时对出来）。
##   另外取 id 用 `str()` 不用 `String()`：背包字典里 id 两种类型都有，`String(整数)`
##   是无效构造器，会当场中断整个函数（本工程老坑）。
static func 拥有数(会话, 物品id: int) -> int:
	if 会话 == null or 物品id == 0:
		return 0
	var 目标 := str(物品id).lstrip("0")
	var 总数 := 0
	for 物品 in 会话.inventory:
		if str((物品 as Dictionary).get("id", "")).lstrip("0") == 目标:
			总数 += int((物品 as Dictionary).get("quantity", 0))
	return 总数

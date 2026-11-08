class_name 宠物数值
extends RefCounted
## 宠物显示数值的计算引擎 —— **逐式**搬运原版 `com/mxw/roles/data/PetAddValue.as`
## （2.2.3/map_extract/out/mainlib_as/scripts，462 行）与
## `FightValue.computePetPsvSkillAttribute()`（:1030 附近）。
##
## ## 为什么不在窗口里现写
## 旧宠物窗（§3.61 病根四"自造物"）拿 `stage*2` 当暴击、`max_faith` 当生命 —— 那是没有表时
## 编的。原版面板上的**每一个数**都由这里的公式现算（服务端只下发潜力/悟性/技能等级这些存量），
## 所以要还原面板，先得有这台引擎。
##
## ## 输入字段的权威口径
## 入参 `宠` 用**服务端字段名**（`fake_flash_server.py` 的 `PetState` / `_encode_pet` 31 字段，
## 客户端 `后端连接._parse_pet_fields` 对得上）：
##   item_id / level / savvy / aptitude / skills[]（每项 {id, level}）
##   potential_real_atk|def|dex|str、potential_total_atk|def|dex|str、ling_zhu（=帧字段 30，
##   原版 lingZhuNum，服务端存档字段名是 dream）
## ⚠️ 原版 `caculateQianLiMengHuandu` 的分母**混用了 real 的 def/str**（:196，疑似原作者笔误），
##   服务端 `_pet_total_dream_score`（:48559）镜像了同一式子 —— 两边一致，**照搬，别"修正"**。

const 数据 = preload("res://脚本/单例/游戏数据.gd")

## 品质 → 名字。`PetAptitude.as:18` ApitudeNames = ["",普通,优秀,卓越,稀有,"尾兽"]
const 品质名 := ["", "普通", "优秀", "卓越", "稀有", "尾兽"]
## 品质 → 名字颜色。`PetAptitude.as:19` ColorArr（十进制原值：
## 0,16777215,589593,40191,9503487,16776960）
const 品质色 := [Color(0, 0, 0), Color("#ffffff"), Color("#08ff19"), Color("#009cff"), Color("#9102ff"), Color("#ffff00")]
## 尾兽模板 id（`PetSoulFusionSelection` 的四个目标；原版用 isWeiShouPet 判定，见 是尾兽）
const 是尾兽id表 := [401, 402, 403, 404]

## 属性 8 行的名字（语言表 PET_PROP_STRS_1..8，对照图左列逐行验证过）。
const 属性行名 := ["增加主人生命值", "增加主人查克拉", "增加主人攻击", "增加主人防御",
	"增加主人暴击", "增加主人闪避", "增加主人攻速", "增加主人移速"]

## 装备 5 格的名字（语言表 PET_EQUIP_STRS_1..5；与槽位号 1..5=兽铠/兽盔/兽符/兽爪/变身
## 的对应走 装备槽名表，格序按 PetWindow.as:482-508 的摆位）。
const 装备槽名 := ["兽铠", "兽盔", "兽符", "兽爪", "变身"]


static func 是尾兽(item_id: int) -> bool:
	return 是尾兽id表.has(item_id)


static func 品质名_of(aptitude: int) -> String:
	return 品质名[clampi(aptitude, 0, 品质名.size() - 1)]


static func 品质色_of(aptitude: int, wei_shou := false) -> Color:
	# PetAptitude.getApitudeColor(apt, isWeiShou)：尾兽一律 UI_YELLOW
	if wei_shou:
		return Color("#ffff00")
	return 品质色[clampi(aptitude, 0, 品质色.size() - 1)]


static func 显示名(宠: Dictionary) -> String:
	# PetAddValue.getPetDetailName:234 —— 尾兽直接用名字，其余追加"(品质)"
	var name := String(宠.get("name", ""))
	return name if 是尾兽(int(宠.get("item_id", 0))) else "%s(%s)" % [name, 品质名_of(int(宠.get("aptitude", 1)))]


static func 价格(宠: Dictionary) -> int:
	# PetAddValue.caculatePetPrice:61-65 = 四项潜力 real 之和 + 悟性 + 技能数×50
	return 潜力real和(宠) + int(宠.get("savvy", 0)) + int((宠.get("skills", []) as Array).size()) * 50


static func 经验上限(宠: Dictionary) -> int:
	# PetAddValue.getPetMaxExp:178-182 走 PetCfg.common.expTable[level]
	var 表: Dictionary = 数据.pet_common().get("expTable", {}) as Dictionary
	return int(表.get(str(int(宠.get("level", 1))), 0))


## 宠物等级上限 = min(120, 主人等级)。2026-10-29 用户规则：
## 「宠物等级不能超过人物等级 …… 宠物已经达到当前最高等级，将不再获取经验」。
## 服务端 `fake_flash_server._pet_level_cap` 同一条式子；这里是离线档与面板那一侧。
static func 等级上限(主人等级: int) -> int:
	return clampi(主人等级, 1, 120)


## 按主人等级收口一只宠物：**高于上限的压到上限**（经验清零，老档残留不跨级累计），
## **正好在上限的也清经验**（满级不再获取经验）。返回 true 表示真的改过。
static func 收口等级(宠: Dictionary, 主人等级: int) -> bool:
	var 上限 := 等级上限(主人等级)
	var 级 := int(宠.get("level", 1))
	var 经验 := int(宠.get("experience", 0))
	var 新级 := mini(级, 上限)
	var 新经验 := 0 if 新级 >= 上限 else 经验
	if 新级 == 级 and 新经验 == 经验:
		return false
	宠["level"] = 新级
	宠["experience"] = 新经验
	return true


static func 潜力上限(宠: Dictionary) -> int:
	# PetAddValue.getPetMaxPotential:74-78 = info.potential.values["apt"+资质].max
	var 行 := 数据.pet_template(int(宠.get("item_id", 0)))
	var values: Dictionary = (行.get("info", {}) as Dictionary).get("potential", {}).get("values", {})
	var 档: Dictionary = values.get("apt%d" % int(宠.get("aptitude", 1)), {})
	return int(档.get("max", 0))


static func 携带等级(宠: Dictionary) -> int:
	var 行 := 数据.pet_template(int(宠.get("item_id", 0)))
	return int((行.get("info", {}) as Dictionary).get("carryLevel", 0))


static func 模板速度(宠: Dictionary, 键: String) -> int:
	# getMoveSpeed:95-99 / getAttackSpeed:111-115 = info.speed["apt"+资质][wlkSpeed|atkSpeed]
	var 行 := 数据.pet_template(int(宠.get("item_id", 0)))
	var 档: Dictionary = (行.get("info", {}) as Dictionary).get("speed", {}).get("apt%d" % int(宠.get("aptitude", 1)), {})
	return int(档.get(键, 0))


static func 潜力real和(宠: Dictionary) -> int:
	return _i(宠, "potential_real_atk") + _i(宠, "potential_real_def") + _i(宠, "potential_real_dex") + _i(宠, "potential_real_str")


static func 技能加成(宠: Dictionary) -> Dictionary:
	# FightValue.computePetPsvSkillAttribute：**覆盖式**分槽累加 ——
	# 同类型多个技能时**后者胜**（`MHPR = value * skillLevel`，不是 +=），照搬。
	var 出 := {"MHPR": 0, "MMPR": 0, "ATKR": 0, "BSKR": 0, "AVDR": 0, "DEFR": 0, "walkSpeedR": 0, "attackSpeedR": 0}
	for 技 in (宠.get("skills", []) as Array):
		var 行 := 数据.pet_skill(int((技 as Dictionary).get("id", 0)))
		var ta: Dictionary = (行.get("info", {}) as Dictionary).get("type_attr", {})
		if ta.is_empty():
			continue
		var 映射 := {"maxhp": "MHPR", "maxmp": "MMPR", "atk": "ATKR", "bsk": "BSKR",
			"avd": "AVDR", "def": "DEFR", "wlkspeed": "walkSpeedR", "atkspeed": "attackSpeedR"}
		var 槽 := String(映射.get(String(ta.get("type", "")), ""))
		if 槽.is_empty():
			continue
		# 原版取的是 valueLevel（不是 valueBase），乘技能等级
		出[槽] = int(float(ta.get("valueLevel", 0))) * int((技 as Dictionary).get("level", 0))
	return 出


static func 梦幻度分量(宠: Dictionary) -> Dictionary:
	# PetAddValue.initData:385-388 —— 显示的是四个**百分比整数**（截断）
	var 悟 := float(_i(宠, "savvy")) / 100.0 / 10.0            # caculateWuXingMengHuandu:223-226
	var 潜 := float(潜力real和(宠)) / float(maxi(1, _i(宠, "potential_total_atk") + _i(宠, "potential_real_def") + _i(宠, "potential_total_dex") + _i(宠, "potential_real_str"))) / 3.0  # :194-197 分母混用，照搬
	var 技 := float((宠.get("skills", []) as Array).size()) / 8.0 / 10.0   # :90-93
	var 珠 := float(_i(宠, "ling_zhu"))                       # :208-211（灵珠数直接当点数）
	return {
		"wu_xing": int(悟 * 100.0), "qian_li": int(潜 * 100.0),
		"skill": int(技 * 100.0), "ling_zhu": int(珠),
		# 倍率（caculateMengHuandu:184-192）：四项小数和 + 灵珠**再 /100**，夹到 ≤1，
		# 原版 `toFixed(6)` 是**四舍五入**到 6 位小数
		"multiplier": clampf(roundf((悟 + 潜 + 技 + 珠 / 100.0) * 1000000.0) / 1000000.0, 0.0, 1.0),
	}


static func 总梦幻度(宠: Dictionary) -> int:
	var 分 := 梦幻度分量(宠)
	return int(分["wu_xing"]) + int(分["qian_li"]) + int(分["skill"]) + int(分["ling_zhu"])


## 面板主入口：8 属性行（白值+梦幻绿值）、经验、四潜力、总值、价值、名字色。
## `天气加成` 先给 0 —— 原版 getWeatherRate 查喂给附身主人的天气 buff，接通另批处理。
static func 计算(宠: Dictionary, 装备加成 := {}, 天气加成 := 0.0) -> Dictionary:
	if 宠.is_empty():
		return {}
	var 技增 := 技能加成(宠)
	var  equip := 默认加成(装备加成)
	var 倍率: float = 梦幻度分量(宠)["multiplier"]
	var 级 := _i(宠, "level")
	var 出 := {
		"属性行": [],
		"名字": 显示名(宠),
		"名字色": 品质色_of(_i(宠, "aptitude"), 是尾兽(_i(宠, "item_id"))),
		"等级": 级, "悟性": _i(宠, "savvy"), "资质名": 品质名_of(_i(宠, "aptitude")),
		"价值": 价格(宠),
		"经验": _i(宠, "experience"), "经验上限": 经验上限(宠),
		"梦幻度": 总梦幻度(宠), "梦幻分量": 梦幻度分量(宠),
		"潜力总值": 潜力real和(宠),   # _txtMax = 四项 real 之和（PetWindow.as:621）
	}
	# 六条基础属性：白值/绿值同参数不同（:260-368 —— hp/mp 都吃 **str**，暴击/闪避吃 **dex**）
	var str实 := _f(caculate_hp(_i(宠, "potential_real_str"), 级))
	var mp实 := _f(caculate_mp(_i(宠, "potential_real_str"), 级))
	var 攻实 := _f(caculate_attack(_i(宠, "potential_real_atk"), 级))
	var 防实 := _f(caculate_defend(_i(宠, "potential_real_def"), 级))
	var 暴实 := _f(caculate_baoji(_i(宠, "potential_real_dex"), 级))
	var 闪实 := _f(caculate_duck(_i(宠, "potential_real_dex"), 级))
	var 攻速实 := float(模板速度(宠, "atkSpeed"))
	var 移速实 := float(模板速度(宠, "wlkSpeed"))
	var 白 := [
		_属性(str实, 技增["MHPR"], equip["MHP"], 天气加成, 倍率),
		_属性(mp实, 技增["MMPR"], equip["MMP"], 天气加成, 倍率),
		_属性(攻实, 技增["ATKR"], equip["ATK"], 天气加成, 倍率),
		_属性(防实, 技增["DEFR"], equip["DEF"], 天气加成, 倍率),
		_属性(暴实, 技增["BSKR"], equip["BSK"], 天气加成, 倍率),
		_属性(闪实, 技增["AVDR"], equip["AVD"], 天气加成, 倍率),
		# 攻速/移速：白值 ceil(base*(100+w)/100) + R*base/100 + 装备攻速（原版 :405-409）。
		# 绿值（攻速 `attackSpeedMengHuan:421-426`、移速 `moveSpeedMengHuan:253-258`）原版写的是
		# `_skillAddValue.attackSpeed` —— 但 `_skillAddValue` 是
		# **纯技能聚合对象**（computePetPsvSkillAttribute 只填带 R 的槽），它的无 R 字段恒 0，
		# 所以原版绿值实际 = floor(基础 × 倍率)，**不吃装备也不吃技能**。这是原版的怪癖，照搬。
		_速度(攻速实, 技增["attackSpeedR"], equip["attackSpeed"], 天气加成, 倍率),
		_速度(移速实, 技增["walkSpeedR"], equip["walkSpeed"], 天气加成, 倍率),
	]
	for 号 in 8:
		(出["属性行"] as Array).append({"名": 属性行名[号], "值": 白[号][0], "梦幻加成": 白[号][1]})
	出["潜力条"] = [
		{"名": "攻击潜力", "实": _i(宠, "potential_real_atk"), "总": _i(宠, "potential_total_atk"), "上限": 潜力上限(宠)},
		{"名": "防御潜力", "实": _i(宠, "potential_real_def"), "总": _i(宠, "potential_total_def"), "上限": 潜力上限(宠)},
		{"名": "灵巧潜力", "实": _i(宠, "potential_real_dex"), "总": _i(宠, "potential_total_dex"), "上限": 潜力上限(宠)},
		{"名": "健体潜力", "实": _i(宠, "potential_real_str"), "总": _i(宠, "potential_total_str"), "上限": 潜力上限(宠)},
	]
	return 出


## 提升到**满潜力**后的六项加成 —— 原版 `PetAddValue` 的 `maxHp / maxMp / maxAttack / maxDefend /
## maxBaoJi / maxDuck`（`:271 / :290 / :351 / :320 / :428 / :331`）：与实值**同公式**，
## 只把 `potentialRealApX` 换成 `potentialTotalApX`。**下标与 `计算()["属性行"]` 的 0..5 对齐**。
## 攻速/移速原版没有 total 档（它们吃模板速度表，与潜力无关）⇒ 这两个不返回。
## 提升页中框「提升到最大后将加成 ：N」（`PetStrongTab.getStrongApaPrm:395-398`）用的就是它。
static func 满值六项(宠: Dictionary, 装备加成 := {}) -> Array:
	if 宠.is_empty():
		return []
	var 技增 := 技能加成(宠)
	var equip := 默认加成(装备加成)
	var 倍率: float = 梦幻度分量(宠)["multiplier"]
	var 级 := _i(宠, "level")
	# 顺序 = 属性行 0..5：生命 / 查克拉 / 攻击 / 防御 / 暴击 / 闪避
	var 总 := [
		caculate_hp(_i(宠, "potential_total_str"), 级),
		caculate_mp(_i(宠, "potential_total_str"), 级),
		caculate_attack(_i(宠, "potential_total_atk"), 级),
		caculate_defend(_i(宠, "potential_total_def"), 级),
		caculate_baoji(_i(宠, "potential_total_dex"), 级),
		caculate_duck(_i(宠, "potential_total_dex"), 级),
	]
	var 增: Array = [技增["MHPR"], 技增["MMPR"], 技增["ATKR"], 技增["DEFR"], 技增["BSKR"], 技增["AVDR"]]
	var 装: Array = [equip["MHP"], equip["MMP"], equip["ATK"], equip["DEF"], equip["BSK"], equip["AVD"]]
	var 出: Array = []
	for 号 in 6:
		出.append(_属性(float(总[号]), int(增[号]), int(装[号]), 0.0, 倍率)[0])
	return 出


## 六个基础公式（PetAddValue:80-251）。AS3 的 int() 是**向零截断**，这里保持同样语义。
static func caculate_hp(潜力: int, 级: int) -> int:
	if 潜力 > 1400: 潜力 = int(潜力 * 0.715 + 417)
	var v := (0.02 * 潜力 - 0.002) * 级 + 0.00012 * 潜力 * 潜力 + 0.057 * 潜力 - 2.803
	return 1 if int(v) < 1 else int(v)

static func caculate_mp(潜力: int, 级: int) -> int:
	if 潜力 > 1400: 潜力 = int(潜力 * 0.649 + 508)
	var v := (0.004 * 潜力 - 0.003) * 级 + 0.0000384 * 潜力 * 潜力 + 0.0191 * 潜力 - 1.232
	return 1 if int(v) < 1 else int(v)

static func caculate_attack(潜力: int, 级: int) -> int:
	if 潜力 > 1400: 潜力 = int(潜力 * 0.82 + 213)
	var v := (2.0 * 潜力 / 300.0 + 0.003) * 级 + 0.0000388 * 潜力 * 潜力 + 0.018 * 潜力 - 0.231
	return 1 if int(v) < 1 else int(v)

static func caculate_defend(潜力: int, 级: int) -> int:
	if 潜力 > 1400: 潜力 = int(潜力 * 0.772 + 346)
	var v := (0.006 * 潜力 - 0.005) * 级 + 0.000032 * 潜力 * 潜力 + 0.008 * 潜力 + 0.905
	return 1 if int(v) < 1 else int(v)

static func caculate_baoji(潜力: int, 级: int) -> int:
	if 潜力 > 1000: 潜力 = int(潜力 * 0.5 + 500)   # ⚠️ 只有暴击是 1000，其余三个是 1400 —— 原版如此
	var v := (0.0005 * 潜力 - 0.004) * 级 + 0.0000121 * 潜力 * 潜力 - 0.007 * 潜力 + 5.634
	return 1 if int(v) < 1 else int(v)

static func caculate_duck(潜力: int, 级: int) -> int:
	# 与 caculateAttack 同式（原版 :168-176 就是复制的），阈值同样 >1400
	if 潜力 > 1400: 潜力 = int(潜力 * 0.82 + 213)
	var v := (2.0 * 潜力 / 300.0 + 0.003) * 级 + 0.0000388 * 潜力 * 潜力 + 0.018 * 潜力 - 0.231
	return 1 if int(v) < 1 else int(v)


## 原版对**浮点结果**先 `<1→1` 再 floor（`Math.floor(_loc1_ < 1 ? 1 : _loc1_)`）。
static func _夹一再取整(x: float) -> int:
	return int(floor(1.0 if x < 1.0 else x))


static func _属性(基础: float, 技增百分比: int, 装备定值: int, 天气: float, 倍率: float) -> Array:
	# hp 族白值（PetAddValue:260-264）：floor( ceil(基础*(100+w)/100) + R*基础/100 + equip )
	var 白值 := int(floor(ceil(基础 * (100.0 + 天气) / 100.0) + 技增百分比 * 基础 / 100.0 + float(装备定值)))
	# 绿值（:277-282）：(基础 + R*基础/100) × 倍率 —— 注意**不吃天气与装备**
	return [白值, _夹一再取整((基础 + 技增百分比 * 基础 / 100.0) * 倍率)]


static func _速度(基础: float, 技增: int, 装备定值: int, 天气: float, 倍率: float) -> Array:
	var 白值 := int(floor(ceil(基础 * (100.0 + 天气) / 100.0) + 技增 * 基础 / 100.0 + float(装备定值)))
	# 绿值只吃基础×倍率（见 计算() 里的注释：原版引用了纯技能对象上恒 0 的无 R 字段）
	return [白值, _夹一再取整(基础 * 倍率)]


static func 默认加成(装备加成: Dictionary) -> Dictionary:
	var 出 := {"MHP": 0, "MMP": 0, "ATK": 0, "DEF": 0, "BSK": 0, "AVD": 0, "attackSpeed": 0, "walkSpeed": 0}
	for 键 in 出:
		出[键] = int(装备加成.get(键, 0))
	return 出


static func _i(宠: Dictionary, 键: String) -> int:
	return int(宠.get(键, 0))


static func _f(v: int) -> float:
	return float(v)

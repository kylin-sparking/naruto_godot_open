extends Control
## 原版**装备提示框**（`MToolTipZhuangBei`）。
##
## 真值来源
## --------
## * 分发：`MToolTipItem.setValue`（`MToolTipItem.as:73-109`）——`EqpData` 走
##   `MToolTipZhuangBei.createEqpTip`，其余走普通物品那套（见 `物品提示框.gd`）。
## * 排版：与普通物品 tooltip **完全同一套**（同一张底图符号 699、同一个 `bgHeight`
##   累加、图标框同样在 (170,38)），所以这里照抄 `物品提示框.gd` 的排版内核，
##   不另起一套。
## * 文案：`en_US$message_properties.as` 的 `MTOOTIP_*`（每条都标了行号）。
##
## 本文件覆盖的是**常见装备**那条路（含**镶嵌属性段**）。
## 稀有段（神话属性 / 特性属性 / 刻印 / 传说属性 / 套装）尚未实现，见文件末的 TODO。
## **两件对比**（右列「身上穿戴件」）2026-10-24 §3.259 起支持：调用点多传一个
## `是穿戴对比` ⇒ 标题带 `(已装备)`，摆位改走 `贴成一对`，接线在 `格子提示框.gd`。

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
## 资质（品质）的名字色、边框、流光 —— 全项目一份表，这里只是读。
const 装备品质表 := preload("res://脚本/单例/装备品质.gd")
## 附加属性**上限表**来自 `EquipSystem.plus.stage<N>`（原版 `StringTool.getPlusPositionConfig`），
## 与打造表同一份数据源，所以直接借 `装备打造表` 读，不另开一个读取器。
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")

## 装备元数据（stage / 基础属性 / 耐久上限）。`数据/物品.json` 里**没有**这些，
## 它们来自服务端 GameData 的 `ZhuangBei` 段，由 `开发工具/导出装备元数据.py` 导成静态表。
const 元数据路径 := "res://数据/物品装备元数据.json"
static var _元数据: Dictionary = {}

static func _元数据表() -> Dictionary:
	if _元数据.is_empty() and FileAccess.file_exists(元数据路径):
		var 解析 = JSON.parse_string(FileAccess.get_file_as_string(元数据路径))
		if typeof(解析) == TYPE_DICTIONARY:
			_元数据 = 解析
	return _元数据


## 单件装备的元数据条目。
## ⚠️ 表键是**八位补零**（`01010013`），而在线下发的 id 是整数形态的**七位**
## （`_parse_item_entry` 原样收 `String(values[1])`）⇒ 不补零直查会整条落空：
## `stage` 恒 1、`type_name` 空 ⇒ 附加属性上限表为空 ⇒ 详情框里「【梦幻满值】/
## 最大可提升至」两条**在线永远不出现**（2026-11-04 用户报「满值后没有梦幻满值标识」）。
static func _物品元(物品id: String) -> Dictionary:
	var 键 := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	return (_元数据表().get("物品", {}) as Dictionary).get(键, {}) as Dictionary


## 灵器（十拳剑一族）的**静态**属性。原版 `LingQiData.initVars` 从 GameData 的
## `LingQi.<id>.info` 读 `baseAttr` / `addAttr` / `specialAttr`；wire 上只有
## `plus_attributes`（`fake_flash_server._encode_item_payload` 的 LING_QI 支），
## 所以基础属性/上限/特殊属性必须走这张导出表，否则提示框里「基本属性」整段是空的
## —— 2026-10-20 用户报「十拳剑没有属性值」就是这个。
static func _灵器元(物品id: String) -> Dictionary:
	var 键 := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	return (_元数据表().get("灵器", {}) as Dictionary).get(键, {}) as Dictionary


## 刻印值配置（`EquipSystem.carve.value.<id>`，原版 `StringTool.getCarveValueConfig`）。
static func _刻印配置(carve_id: int) -> Dictionary:
	return (_元数据表().get("刻印值", {}) as Dictionary).get(str(carve_id), {}) as Dictionary

# ---- 版式常量（与 物品提示框.gd 同源，勿各自为政）----
const 内边距 := 8.0
const 最大宽 := 280.0
const 框宽 := 293.0            ## MAX_WIDTH + PADDING*2 - 3
const 块间距 := 5.0
const 行距 := 4.0
const 标题高 := 20.0
const 标题字号 := 14
const 正文字号 := 12
const 图标框尺寸 := 40.0
const 图标框位置 := Vector2(170.0, 38.0)
## 对比列标题后缀。原版 `compareSuffixHtml` 全工程**只有一个赋值点**
## （`MToolTipZhuangBei.as:1566 param2.compareSuffixHtml = CN.EQUIPMENT_ALREADY`，拼完立刻 `delete`），
## 值取 `数据/装备文案.json:38 EQUIPMENT_ALREADY`，剥掉 `<font>` 标签后的字面就是 `(已装备)`，
## 色 `#ff6600` 是那条文案自己带的。
const 对比后缀文案 := "(已装备)"
const 色_对比后缀 := Color("ff6600")

# ---- 文案（出处逐条标 `en_US$message_properties.as` 行号）----
const 装备分类 := "装备分类　"          ## EQPDATA_ZHUANGBEI_FENLEI :3233
const 装备阶数 := "装备阶数　"          ## EQPDATA_ZHUANGBEI_JIESHU :1209
## 【装备分类】那一行**没有**语言键前缀：`EqpData.setBaseInfo` 是
## `EQUIP_NAMES[...]` —— 即"武器/手套/衣服"这样的槽名本身。
## 我第一版把它写成了「装备分类　武器」重复一遍，与原版截图不符，已去掉。
const 适用职业 := "适用职业　"          ## ITEM_FIT_JOB :2021（不是"职业　"）
const 使用等级 := "使用等级　"          ## MTOOTIP_REPLEVEL :1463
const 阶 := "阶"                        ## SHOULIJIAN_PANEL_JIE :1706
const 级 := "级"                        ## QUEST_ITEMHAND_PETCELL :1467
const 耐久度 := "耐久度　"              ## MTOOTIP_ENDURE :1303
const 永不磨损 := "永不磨损"            ## MTOOTIP_MAX_ENDURE :403
const 强化等级 := "强化等级　"          ## MTOOTIP_STRENGH_LEVEL :2076
const 满星 := "(满星)"                  ## MTOOTIP_MANXING :2440
## 强化行的小蓝钻 + 星排（原版 `MToolTipZhuangBei.as:370-377` 的 `blueDiamond`/
## `:371-378` 的 `createStarSprite`）。蓝钻 12×10、星 14×13；灰版按 `getDisableFilter`
## 同系数离线烘焙（先例：套装灰版）。
const 蓝钻图 := "res://素材/界面/原版窗口/人物/角色/蓝钻.png"
const 蓝钻灰图 := "res://素材/界面/原版窗口/人物/角色/蓝钻_灰.png"
const 星图标 := "res://素材/界面/原版窗口/家族/星标.png"     ## StarLevelIconF(693)，家族页已导过
## `MTOOTIP_ITEM_E_WAI_JIAYIXING` :3241 本身就是带 `<font #ff9100>` 的模板 ⇒ BBCode 等价写法。
const 精炼额外 := "[color=#ff9100]【精炼额外加一星】[/color]"
const 色_强化橙 := "#ff9e16"             ## strengthColor = 16751126（等级>0 时整行橙色）
const 基本属性 := "基本属性"            ## MTOOTIP_BASS_ARRT :749
const 附加属性 := "附加属性"            ## MTOOTIP_PLUS_ARRT :3261
const 附加属性满 := "附加属性(满附加)"    ## MTOOTIP_PLUS_ARRT_1 :3262
const 天生前缀 := "天生"                ## MTOOTIP_TIANSHENG :2296
const 满天生 := "（满天生）"            ## MTOOTIP_MANTIANSHENG :1388
const 已绑定 := "[已绑定]"              ## MTOOTIP_CANTRADE :902
const 未绑定 := "[未绑定]"              ## MTOOTIP_NOT_CANTRADE :3315
const 出售总价 := "出售总价　"          ## MTOOTIP_SALE_TOTAL_PRICE :462
const 购买所需 := "购买所需金币　"      ## MTOOTIP_BUY_TOTAL_PRICE :1002
const 该装备破碎 := "该装备处于破碎状态" ## MTOOTIP_IS_STATE_POSUI :2334
const 可修复破碎 := "可以修复破碎状态"   ## MTOOTIP_USE_XUIFU_POSUI :2297
const 过期时间 := "过期时间："           ## MTOOTIP_EXPIRATION :641
const 镶嵌属性 := "镶嵌属性"             ## MTOOTIP_INLAY_ARRT :2007
const 镶嵌层 := "层"                     ## MTOOL_TIPITEM_CENG :648（勾玉那行的后缀）
const 传说属性 := "传说属性"             ## MTOOTIP_ITEM_CHUANSHUO_SHUXING :365
const 秘印属性 := "秘印属性"             ## MTOOL_MIYIN_SHUXING :2272
const 最大 := "最大"                     ## MTOOL_ZUIDA :1822
const 梦幻满值 := "【梦幻满值】"          ## MTOOTIP_MANMENGHUAN_ZHI :2219（去掉 font 标签）
## 刻印值的颜色 = 65280（绿）；传说属性的**抬头**是橙(16751126)、**值**按资质上色。
const 色_刻印值 := Color("00ff00")
## 宝石行的抬头色 = 16751126（橙）。原版 `MTTipZhuangBei.as:699` 是
## `setTextColor("<br/>" + MTOOTIP_INLAY_ARRT, 16751126)`，宝石行本身（`:1707`）
## 也用同一个色 —— 抬头与各行同色，别把抬头写成白色。
const 色_镶嵌 := Color("ff9100")
## 宝石图标在提示框里的边长。原版 `createInlaySprite`（`:1699`）把图标
## `width = height = 22`，文字 x=20、每行 `+= 18`。

## 属性类型 id → 中文名。逐字照抄 `ItemFactory.SUB_ATTR_TYPES/_NAMES`（`ItemFactory.as:31-35`），
## 那张表的每一项分别取 `ITEM_ATTR_NAME_*` / `ITEMFACTORY_*` 语言键。
const 属性名 := {
	0: "金币",
	1: "生命值上限",   ## ITEM_ATTR_NAME_MAXHP :2801
	2: "查克拉上限",   ## ITEM_ATTR_NAME_MAXMP :2720
	3: "体力值上限",   ## ITEM_ATTR_NAME_MAXTP :2604
	4: "攻击",         ## ITEM_ATTR_NAME_ATK :2994
	5: "防御",         ## ITEM_ATTR_NAME_DEF :1689
	6: "暴击",         ## ITEM_ATTR_NAME_BSK :2488
	7: "闪避",         ## ITEM_ATTR_NAME_AVD :2972
	8: "攻击速度",     ## ITEM_ATTR_NAME_ATK_SPEED :1487
	9: "移动速度",     ## ITEM_ATTR_NAME_WLK_SPEED :2759
	10: "技能等级加成", ## ITEMFACTORY_SKILL_LEVEL :2124
	11: "攻击力增加",   ## ITEMFACTORY_ATK_TATE :2950
	12: "伤害反弹",     ## ITEMFACTORY_DAMAGE_REFLECT :600
	13: "伤害减免",     ## ITEMFACTORY_DAMAGE_REDUCE :660
	14: "忽视防御",     ## ITEMFACTORY_IGNORE_DEF :2978
	15: "手里剑触发",   ## ITEMFACTORY_ANQI_TRIGGER :803
	## ⚠️ 2026-09-23 更正：这一条的键原来是 **16**，错的。
	## `ItemFactory` 那三个数组的**下标**确实是 16（`SUB_ATTR_TYPES` 的最后一项），
	## 但 `SubAttrType.MOB_EXP` 的**值是 25** —— 而线上/实例里传的是**值**，不是下标。
	## 原版读法 `getBaseAttrName(id) = SUB_ATTR_TYPE_NAMES[SUB_ATTR_TYPES.indexOf(id)]`
	## 也是先按**值**找下标。所以这里必须是 25；按 16 写的话
	## `属性名[25]` 取不到（经验加成行退化成"属性25"），而 16 其实是 `FIX_ATK_RATE`、不在那张表里。
	25: "经验加成",     ## ITEMFACTORY_MOB_EXP :517
}

## 标题 / 附加属性行的颜色按资质取，读 `数据/装备品质.json` 的「名字色」。
## 那张表的值逐档来自 `EqpData.APTITUDE_COLORS`（`EqpData.as:31`），
## 原版下标就是资质原值 0..6，两处取法：标题 `titleFormat.color`、
## 附加属性行 `APTITUDE_COLORS[value.aptitude]`（`MToolTipZhuangBei.as`）。
## ⚠️ 以前这里手抄过一份数组，四个十六进制的第 3、4 位抄反过（2026-09-23 更正）——
## 表收敛到 `装备品质.gd` 之后**不要再在这里抄值**，抄一次就多一处会错的地方。
## 附加属性那一行的颜色 —— 同一个 `APTITUDE_COLORS`，单独给个名字免得读代码时来回跳。
static func 附加属性色(资质: int) -> Color:
	return 装备品质表.名字色(资质)

## 属性类型 id → **英文名**。出处 `ItemFactory.SUB_ATTR_TYPES`（`:31`）与
## `SUB_ATTR_TYPE_EN_NAMES`（`:33`）的同下标配对 —— 那两个数组的**下标就是属性 id 本身**
## （`SubAttrType.MONEY=0` … `IGNORE_DEF=14`、`ANQI_TRIGGER=15`，最后一项 `MOB_EXP=25`）。
## 附加属性上限表 `plus.stage<N>[EquipX]` 里的 `type` 字段用的就是这套英文名，靠它逐条配对。
##
## ⚠️ `ANTI_SEAL_PET`(24) **不在**那两个数组里 —— 原版 `getBaseAttrStr(24)` 会取到 undefined，
## 所以它根本不参与配对，走单独一条"特殊属性"分支。别把它硬塞进来。
const 属性英文名 := {
	0: "money", 1: "maxhp", 2: "maxmp", 3: "maxtp", 4: "atk", 5: "def", 6: "bsk", 7: "avd",
	8: "atkspeed", 9: "wlkspeed", 10: "skill_level", 11: "atk_tate", 12: "damage_reflect",
	13: "damage_reduce", 14: "ignore_def", 15: "anqi_trigger", 25: "mob_exp",
}
## 数值带 `%` 的属性 —— 只有**伤害反弹(12)、伤害减免(13)** 两类。
## 出处 `MToolTipZhuangBei.as`（2.2.3 `:359`、新版 `:540`）：
##   `if(plusAttrText.indexOf(DAMAGE_REDUCE) != -1 || indexOf(DAMAGE_REFLECT) != -1) plusAttrText += "%"`
## ⚠️ 2026-09-26 更正：原来这张表写成 `[11, 12, 13, 14]`（以为"攻击力增加/忽视防御"也带百分号），
## 但原版那句判断里**只有这两个键**，且四个名字在语言表里本身都不含 `%`
## （`ITEMFACTORY_ATK_TATE`=攻击力增加 :2950、`ITEMFACTORY_IGNORE_DEF`=忽视防御 :2978）。
## 另一条原版怪癖：它是往**整段** plusAttrText 末尾补一个 `%`（挂在最后一行后面），
## 不是逐行补。我们一行一个 Label，做不到"整段末尾"，所以取逐行 —— 但**类别**照原版只留这两类。
## 同一份值在 `数据/装备属性名.json` 的「百分比」里（导出脚本从这两行正则抓的）。
const 百分比属性 := [12, 13]   ## DAMAGE_REFLECT / DAMAGE_REDUCE

## ── 精炼（百炼）那几件 ─────────────────────────────
## 倍率 = `MToolTipItem.as:24` 的 `protected static const RATIO:int = 5`。
## 就是精炼锤说明里那句"当前附加属性**五倍**的追加值"。
const 精炼倍率 := 5
## `MTOOTIP_ITEM_QIANCHUI_BAILIAN`（`:2455`）= "【精炼额外追加%1% * %2】"（去掉 font 标签）
const 精炼追加抬头 := "【精炼额外追加%d%% * %d】"
## `MTOOTIP_ITEM_ZHUI`（`:3064`）= "<font color='#fff000'>追+%1</font>"（去掉 font 标签）
const 追加前缀 := "追+%d"
const 色_追加 := Color("fff000")
## `MTOOTIP_ZUIDA_KETISHENG_DEMENGHUANZHI`（`:2903`）= "最大可提升至+%1"。
## ⚠️ **前面那 8 个空格是文案自带的**（原版整串是 `"<font…>        最大可提升至+%1</font>"`），
## 别自己再补空格，也别删。
const 最大可提升 := "        最大可提升至+%d"
## `MTOOTIP_MANMENGHUAN_ZHI`（`:2219`）—— 原串是 `"<font color='#00ff00'>    【梦幻满值】</font>"`，
## **那 4 个空格也在里面**。上面那个 `梦幻满值` 常量是去掉空格的版本，行内拼接要用带空格的。
const 梦幻满值带空格 := "    【梦幻满值】"
## 抬头色 = 原版那个 16751126（`MTToolTipZhuangBei.as:439`）。
const 色_附加抬头 := Color("ff9a16")
## 特性段抬头色 = 原版同一个 16751126（`MTToolTipZhuangBei.as:590` 的 `setTextColor(…,16751126)`）。
const 色_特性抬头 := Color("ff9a16")
## 特性段抬头那行文字（含那个 `⚡`，`:590` 的 `"<br/>特性属性 ⚡"` 逐字）。
const 特性属性闪电 := "特性属性 ⚡"
## `MTOOTIP_SPECIAL_ARRT`（`:534`）= "特殊属性"
const 特殊属性 := "特殊属性"
## `ITEMFACTORY_ANQI_SEAL_PET`（`:3308`）—— 解印那条，占位是 `%1`（数值）。
const 解印文案 := "【解印】\n战斗时有额外%d%%的几率抵抗【封印】技能对附身通灵兽的封印效果。"
## 经验加成那一行的色 = 16738484
const 色_经验加成 := Color("ff6a34")

## 职号 → 职业名。⚠️ 职号是**百位**不是 1..5：
## `CocoJob.as:6-14` = 火100 / 水200 / 雷300 / 风400 / 土500，
## 名字取 `JobTool.getJobName`（`JobTool.as:25-42`）→ `JOB_*_NAME` 语言键。
## （我第一版按 1..5 建表，结果职业行取不到名字、显示成空的「职业　」——
##  打实际值才看出来，见 §0.0d 第 1 条。）
# 职业表已收敛到 `脚本/单例/职业.gd`（唯一一份）—— 这里原先还抄了一份，删掉。
const 职业名表 := preload("res://脚本/单例/职业.gd")
const 色_超等级 := Color("ff0000")
## 职业行"符合"时的颜色。**实测原版截图**：需求职业与角色职业相符时那行是**绿色**
## （原版是 `<font color=...>` 包住整行，颜色不是纯白）。不满足时红。
const 色_职业符合 := Color("00ff21")

# ---- 忍具（`MToolTipRenJuTip.as`，2026-10-31 §3.332 实装）----
## 原版走 `MToolTipItem.createToolTip` 的**第三个家族**：`RenJuData` → `MToolTipRenJuTip`
## （`MToolTipItem.as:73-109`）。版式与装备/灵器都不同：标题**恒粉**（不看资质）、
## 基本信息三行、无阶数/强化/星排/镶嵌/秘印/价格/过期，两条分隔线，绑定行居中。
const 佩戴部位忍具 := "佩戴部位　忍具"  ## HUNJIE_DATA_PEIDAI_PUWEI :3276（模板 %1=忍具）
## `ITEM_ANY_JOB_OK`（`:1265`）的字面是「任何职业」—— 装备/灵器/忍具全走同一个语言键
## （`EqpData.as:401` / `LingQiData.as:76` / `RenJuData.as:76`），别写成「任意职业」。
const 任何职业 := "任何职业"
const 色_忍具标题 := Color("ff5498")     ## UIConfig.UI_PINK = 16733336（忍具标题 + 灵器标题）
const 色_忍具绿 := "#00ff00"             ## UIConfig.UI_GREEN = 65280
const 色_附加值 := "#ba01f9"             ## UIConfig.UI_ZHI_SE = 12190201（附加属性值那几行）
const 色_绑定行 := Color("8ea8d8")       ## 9349336，忍具那行绑定用它

@onready var _底: TextureRect = $底
@onready var _标题: Label = $标题
@onready var _信息: Label = $信息
@onready var _职业行: Label = $职业行
@onready var _描述: Label = $描述
@onready var _分隔线: TextureRect = $分隔线
## ⚠️ 是 **RichTextLabel**（原版 `contentText3` 是 htmlText，附加属性那块要混色），
## 不是 Label。见 `.tscn` 里那条注释。
@onready var _明细: RichTextLabel = $明细
## 稀有段容器与它里面两个 Label。**不用 `@onready`** —— 本组件会被工具在
## 刚 `add_child` 的同一帧里就调 `设置()`，那时 `_ready` 还没跑、`@onready` 仍是 null。
var _稀有明细: Control:
	get: return get_node_or_null("稀有明细") as Control
## ⚠️ 传说段**会被 `_排版` 从 `稀有明细` reparent 到根**（原版它在附加后、镶嵌前，不在秘印那块里）。
##    所以取节点要**两处都试** —— 只写 `稀有明细/传说段` 的话，reparent 之后这个 getter 恒 null。
var _传说段: Label:
	get:
		var 节点 := get_node_or_null("稀有明细/传说段")
		if 节点 == null:
			节点 = get_node_or_null("传说段")
		return 节点 as Label
var _秘印抬头: Label:
	get: return get_node_or_null("稀有明细/秘印抬头") as Label
var _秘印段: Label:
	get: return get_node_or_null("稀有明细/秘印段") as Label
@onready var _镶嵌块: Control = $镶嵌块

## `_排版` 末尾要重建镶嵌块，这里存一份本次的实例字段。
var _当前实例: Dictionary = {}
## 最近一次 `设置()` 的 `物品id`（实例字典不一定带 id，判玉链靠它）。
var _当前物品id := ""
@onready var _价格: Label = $价格
@onready var _绑定: Label = $绑定
@onready var _图标框: TextureRect = $图标框
@onready var _图标: TextureRect = $图标框/图标
## 覆盖层两个子节点（资质框 / 流光）**不由这里的 @onready 抓** ——
## `装备品质.挂覆盖层` 自己按名字找、没有就现建，见 `_设图标`。
@onready var _破碎: TextureRect = $图标框/破碎

## 标题后缀那半截（原版 `compareSuffixTF`，`:224-235`）。与 `_稀有明细` 同一个理由不用
## `@onready`：对比列是运行期 `add_child` 后才填的，那一帧 `_ready` 未必已经跑过。
var _对比后缀: Label:
	get: return get_node_or_null("对比后缀") as Label

## 忍具的「描述 + 特殊属性」块。原版是一个 TextField（`MToolTipRenJuTip.as:138-150`），
## 描述白、特殊属性绿 ⇒ Label 做不到混色，运行期建一个 RTL（场景是 SPEC 生成物，不手改）。
var _忍具说明: RichTextLabel:
	get:
		var 节点 := get_node_or_null("忍具说明") as RichTextLabel
		if 节点 == null:
			节点 = RichTextLabel.new()
			节点.name = "忍具说明"
			节点.bbcode_enabled = true
			节点.scroll_active = false
			节点.mouse_filter = Control.MOUSE_FILTER_IGNORE
			节点.add_theme_color_override("default_color", Color.WHITE)
			节点.add_theme_constant_override("line_separation", int(行距))
			节点.add_theme_font_size_override("normal_font_size", 正文字号)
			add_child(节点)
		return 节点

## 忍具的第二条分隔线（原版 `_loc14_`，`:229-234`：明细 → 线 → 绑定）。
var _忍具分隔二: TextureRect:
	get:
		var 节点 := get_node_or_null("忍具分隔二") as TextureRect
		if 节点 == null:
			节点 = TextureRect.new()
			节点.name = "忍具分隔二"
			节点.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			节点.mouse_filter = Control.MOUSE_FILTER_IGNORE
			节点.texture = _分隔线.texture
			add_child(节点)
		return 节点

## 本次标题要不要挂「(已装备)」。空串 = 不挂。
var _对比后缀文本 := ""

## 设置一件**装备**。`实例` 是这一件自己的运行时字段（来自服务端 `_parse_item_entry`）。
## `是穿戴对比` = 这一列是**身上正穿着的那件**：原版只有对比组右列会置 `compareSuffixHtml`
## （`createEqpTip:1566` 给的是 `param2`，`param1` 才是手上悬停那件）。
func 设置(物品id: String, 玩家等级: int, 职业: int, 实例 := {}, 商店总价 := -1, 是购买价 := false,
		是穿戴对比 := false) -> void:
	_当前物品id = 物品id
	var 物品 := GAME_DATA.item(物品id)
	var 数值 := int(物品id) if 物品id.is_valid_int() else 0
	var 前置 := int(数值 / 1000000)      ## 7 位前缀：19 魂戒 / 20 灵器 / 65 忍具
	var 分类码 := int(数值 / 10000)      ## 4 位前缀

	# ---- 忍具：原版是**另一个类**（`RenJuData` → `MToolTipRenJuTip`），整套版式都不同 ----
	var 忍具元 := GAME_DATA.忍具属性(物品id)
	if not 忍具元.is_empty():
		_填忍具(物品id, 物品, 实例, 职业, 忍具元, 是穿戴对比)
		return
	_收起忍具块()

	# ---- 标题：名字 + 神话锻造历史前缀（`decodeMythForgeHistory` :1012-1021）----
	var 标题 := String(物品.get("name", ""))
	_标题.text = 标题
	# 灵器的标题**恒粉**（`MToolTipLingQiTip.as:65` `_loc5_.color = 16733336`，
	# 就是 UIConfig.UI_PINK），跟忍具同一个色；不看 aptitude。忍具那条在 `_填忍具` 里另设。
	_标题.add_theme_color_override("font_color",
			色_忍具标题 if 装备品质表.是灵气(物品id)
			else 装备品质表.名字色(装备品质表.显示档(物品id, int(实例.get("aptitude", 1)))))
	_对比后缀文本 = 对比后缀文案 if 是穿戴对比 else ""

	# ---- baseInfo 四行（`EqpData.setBaseInfo` :345-375）----
	var 槽位 := 装备部位表.位置(物品id)
	var 行1 := 装备部位表.显示名(槽位)   ## 原版这一行就是槽名（武器/手套/…），无前缀
	var 元 := _物品元(物品id)
	var 灵器元 := _灵器元(物品id)
	if not 灵器元.is_empty():
		元 = 元.duplicate(true)
		元["灵器"] = 灵器元
	var 阶数 := int(元.get("stage", 1))   ## `EqpData.as:334` 从 EquipSystem/装备数据读
	var 需求等级 := int(物品.get("required_level", 0))
	var 需求职业 := 数值 % 10 * 100 if 分类码 >= 101 and 分类码 <= 112 else 0
	if not 灵器元.is_empty():
		# 灵器没有「阶数」——原版 `LingQiData.setBaseInfo` 是
		# 「佩戴部位：灵器 / 使用等级 / 适用职业」三行。
		_信息.text = "%s\n%s" % ["佩戴部位　灵器", 使用等级 + str(需求等级) + 级]
	else:
		_信息.text = "%s\n%s\n%s" % [行1, 装备阶数 + str(阶数) + 阶, 使用等级 + str(需求等级) + 级]
	# 等级不够 → 整块染红；职业不符 → 职业那一行染红。
	# 原版是 `<font color="#ff0000">` 包住对应行（`EqpData.setBaseInfo` :366-372），
	# 这里直接用 Label 的字色，效果等价且不用 BBCode。
	_信息.add_theme_color_override("font_color",
		色_超等级 if 需求等级 > 玩家等级 else Color.WHITE)
	_职业行.text = 适用职业 + (职业名表.取(需求职业) if 需求职业 != 0 else 任何职业)
	var 职业不符 := 需求职业 != 0 and 需求职业 != 职业
	_职业行.add_theme_color_override("font_color", 色_超等级 if 职业不符 else 色_职业符合)
	# ⚠️ 更正：上一版我在 baseInfo 后面加过一行「可镶嵌【红色宝石】」，**那是错的**——
	# 原版截图里那一行就是物品自己的 `description`（竹制忍杖的描述正是这句话），
	# 不是独立字段。已删除该节点，描述照常走下面的 `_描述`。
	# ---- 描述 ----
	var 描述 := String(物品.get("description", ""))
	_描述.text = 描述
	_描述.visible = not 描述.is_empty()

	# ---- 明细：耐久 → 强化等级 → 基本属性 → 附加属性 → 破碎提示 ----
	_明细.text = _拼明细(物品id, 数值, 前置, 分类码, 实例, 元)
	_填稀有段(实例)
	# ⚠️ 2026-10-02：传说段已**从稀有容器拆出去**（原版它在附加属性后面、镶嵌之前）；
	#   稀有容器现在**只装秘印组**（原版秘印在**最底、绑定之后**）。所以可见性只看秘印。
	_稀有明细.visible = _秘印段.visible

	# ---- 价格 / 绑定（与普通物品同规矩）----
	var 价格文本 := ""
	if 商店总价 >= 0:
		价格文本 = (购买所需 + str(商店总价)) if 是购买价 else (出售总价 + str(商店总价))
	_价格.text = 价格文本
	_价格.visible = not 价格文本.is_empty()
	# 原版全工程一条：`canTrade ? MTOOTIP_NOT_CANTRADE : MTOOTIP_CANTRADE`
	# （`MToolTipZhuangBei.as:829`；`canTrade` = 可交易 ⇒ 可交易才显示「未绑定」）。
	_绑定.text = 未绑定 if bool(实例.get("can_trade", true)) else 已绑定
	_绑定.visible = int(实例.get("is_show_can_trade", 0)) != -1
	_绑定.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT		# 忍具那支是居中，这里复位

	_当前实例 = 实例
	_设图标(物品id, 实例)
	_排版()


## 忍具（`MToolTipRenJuTip.createRenJuTipSprite`，`:43-253`）。
## 版式与装备/灵器都不同，所以**整套重排**，不借 `_排版` 那套增量：
##   标题（恒粉） → 基本信息三行（佩戴部位忍具 / 使用等级 / 适用职业；图标框按这三行的
##   纵向中点摆） → 描述（仅 desc，非空才有） → 分隔线 → 耐久(永不磨损,白)
##   / 基本属性(橙抬头+白值) / 附加属性(橙抬头+紫值) / 特殊属性(橙抬头+白值)
##   → 分隔线 → 绑定(居中, #8ea8d8)。
## 没有阶数 / 强化 / 星排 / 镶嵌 / 秘印 / 传说 / 价格 / 过期。
##
## ⚠️ 2026-11-01 用户要求：段序与色号对齐灵器（十拳剑）—— 八咫镜没有附加属性时
##    就是「基本属性 → 特殊属性」，特殊属性值与耐久行都是白字（原版把这两块放在
##    描述块里套绿 `UI_GREEN`，见 `MToolTipRenJuTip.as:110-165`；这里按用户口径改）。
func _填忍具(物品id: String, 物品: Dictionary, 实例: Dictionary, 职业: int,
		元: Dictionary, 是穿戴对比: bool) -> void:
	# 标题：`UIConfig.UI_PINK`，**不看资质**（原版这一段根本没读 aptitude）
	_标题.text = String(物品.get("name", ""))
	_标题.add_theme_color_override("font_color", 色_忍具标题)
	_对比后缀文本 = 对比后缀文案 if 是穿戴对比 else ""

	# 基本信息（`RenJuData.setBaseInfo`）：三行排在同一个 TextField 里，
	# 我们这个 Label 只能装两行、职业那行单独用 `_职业行`（颜色要能整行变红）。
	# 需求等级原版**不染红**（只有职业那行有 `<font color='#ff0000'>`）。
	var 需求等级 := int(元.get("reqLevel", 物品.get("required_level", 0)))
	var 需求职业 := int(元.get("reqJob", 0))
	_信息.text = "%s\n%s" % [佩戴部位忍具, 使用等级 + str(需求等级) + 级]
	_信息.add_theme_color_override("font_color", Color.WHITE)
	_信息.visible = true
	_职业行.text = 适用职业 + (职业名表.取(需求职业) if 需求职业 != 0 else 任何职业)
	_职业行.add_theme_color_override("font_color",
		色_超等级 if (需求职业 != 0 and 需求职业 != 职业) else Color.WHITE)
	_职业行.visible = true
	_描述.text = ""
	_描述.visible = false

	# 描述：原版**只有 desc 非空才建这一块**（`:110-151`）；特殊属性原来嵌在里面，
	# 2026-11-01 按用户口径挪到明细末尾（见 `_拼忍具明细`）——与灵器（十拳剑）段序一致。
	var 描述 := String(物品.get("description", ""))
	if 描述.begins_with("<br/>"):
		描述 = 描述.substr(5)
	var 说明 := _忍具说明
	说明.text = 描述
	说明.visible = not 描述.is_empty()

	_明细.text = _拼忍具明细(实例, 元)
	_明细.visible = true
	_价格.text = ""
	_价格.visible = false
	_稀有明细.visible = false
	_传说段.visible = false
	_建镶嵌块({})		# 清掉上一件（装备）留下的宝石行
	_镶嵌块.visible = false

	# 绑定：原版恒显示、居中、色 9349336；`canTrade` 真 = 可交易 = 「未绑定」。
	_绑定.text = 未绑定 if bool(实例.get("can_trade", true)) else 已绑定
	_绑定.add_theme_color_override("font_color", 色_绑定行)
	_绑定.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_绑定.visible = true

	_当前实例 = 实例
	_设图标(物品id, 实例)
	_排忍具()


## 普通渲染（装备/灵器）开头把忍具那两枚运行期节点收掉，免得串过来。
func _收起忍具块() -> void:
	var 说明 := get_node_or_null("忍具说明") as RichTextLabel
	if 说明 != null:
		说明.visible = false
	var 线 := get_node_or_null("忍具分隔二") as TextureRect
	if 线 != null:
		线.visible = false


## 忍具明细（`MToolTipRenJuTip.as:158-216`）：段序对齐灵器（十拳剑）——
## 耐久（恒"永不磨损"，白）→ 基本属性橙抬头 + 白值 → 附加属性橙抬头 + 紫值
## （到顶带【梦幻满值】、没到顶带"最大可提升至+上限"，绿）→ 特殊属性橙抬头 + 白值。
## 没有附加属性的八咫镜（65000001）就是「基本属性 → 特殊属性」两段。
## ⚠️ 忍具**不加 `%`** —— 原版这一段没有装备那边 `DAMAGE_REDUCE/DAMAGE_REFLECT` 的补百分号。
func _拼忍具明细(实例: Dictionary, 元: Dictionary) -> String:
	var 段: Array[String] = []
	段.append(耐久度 + 永不磨损)
	var 橙 := "[color=#%s]%%s[/color]" % 色_附加抬头.to_html(false)
	段.append(橙 % 基本属性)
	var 基础 := _忍具属性行(元, "baseAttr")
	if not 基础.is_empty():
		段.append("\n".join(基础))

	var 附加 := 实例.get("plus_attributes", []) as Array
	if not 附加.is_empty():
		var 上限 := _忍具上限(元)
		var 首值 := int((附加[0] as Dictionary).get("attribute_value", 0)) if 附加[0] is Dictionary else 0
		段.append(橙 % (附加属性满 if (上限 > 0 and 首值 == 上限) else 附加属性))
		var 行: Array[String] = []
		for 条 in 附加:
			if not (条 is Dictionary):
				continue
			var d := 条 as Dictionary
			var 类 := int(d.get("attribute_type", 0))
			var 值 := int(d.get("attribute_value", 0))
			var 尾 := ""
			if 上限 > 0:
				if 值 == 上限:
					尾 = "[color=%s]%s[/color]" % [色_忍具绿, 梦幻满值带空格]
				else:
					尾 = "[color=%s]%s[/color]" % [色_忍具绿, 最大可提升 % 上限]
			行.append(" %s　+%d%s" % [String(属性名.get(类, "属性%d" % 类)), 值, 尾])
		段.append("[color=%s]%s[/color]" % [色_附加值, "\n".join(行)])
	var 特殊 := _忍具特殊行(元)
	if not 特殊.is_empty():
		段.append(橙 % 特殊属性)
		段.append("\n".join(特殊))
	return "\n".join(段)


## `baseAttr` / 未来的同类串（`atk:3666;def:3666;...`）→ 属性行。
## 未知键直接跳过：原版 `ItemFactory.SUB_ATTR_TYPE_EN_NAMES.indexOf` 查不到时
## `SUB_ATTR_TYPES[-1]` 是 undefined，会印出「undefined　+N」（如 65000013 的 `SEAL_PET`）——
## 那是原版数据串自己写错，不该照抄成乱码。
func _忍具属性行(元: Dictionary, 键: String) -> Array[String]:
	var 行: Array[String] = []
	for 项 in String(元.get(键, "")).split(";", false):
		var 对 := 项.split(":")
		if 对.size() < 2:
			continue
		var 名 := _忍具属性名(String(对[0]))
		if 名.is_empty():
			continue
		行.append(" %s　+%d" % [名, int(对[1])])
	return 行


## 英文键 → 中文属性名。**大小写不敏感**：数据里混着 `atk` 与 `IGNORE_DEF` / `DAMAGE_REDUCE`，
## 原版那张数组是小写（`ItemFactory.as:33`）⇒ 大写那两条在 AS3 里其实查不到。
func _忍具属性名(英文键: String) -> String:
	var 小写 := 英文键.to_lower()
	for 类 in 属性英文名:
		if String(属性英文名[类]) == 小写:
			return String(属性名.get(int(类), 英文键))
	return ""


## 附加属性上限：原版 `getMaxPlusAttr` = `addAttr.split(":")[1]`（`:127-133`），
## 八咫镜那两条都是 `atk:200;def:333;avd:333` ⇒ 200。
func _忍具上限(元: Dictionary) -> int:
	var 对 := String(元.get("addAttr", "")).split(":")
	return int(对[1]) if 对.size() >= 2 else 0


## 特殊属性三行（`RenJuData.getSpecialAttr` 只认这三个键）。
## ⚠️ 数据里的 `SEAL_PET` **不在**原版 switch 里（它认的是 `ANTI_SEAL_PET_SHOW`）⇒ 忽略，
## 与 `SEAL_PET` 在 baseAttr 里落成 undefined 是同一个数据缺口，别自作主张补一行。
func _忍具特殊行(元: Dictionary) -> Array[String]:
	var 行: Array[String] = []
	for 项 in String(元.get("specialAttr", "")).split(";", false):
		var 对 := 项.split(":")
		if 对.size() < 2:
			continue
		var 值 := int(对[1])
		match String(对[0]):
			"JOB_SKILL_LEVEL":
				行.append("　职业忍术等级　+%d" % 值)
			"WORLD_SKILL_LEVEL":
				行.append("　世界忍术等级　+%d" % 值)
			"ANTI_SEAL_PET_SHOW":
				行.append(解印文案 % 值)
	return 行


## 忍具排版：`bgHeight` 累加，但块序是它自己那套（见 `_填忍具` 头注）。
func _排忍具() -> void:
	var 字号行高 := _单行高(正文字号)
	var y := 内边距
	_排标题()
	y += 标题高

	# 基本信息两行
	_信息.size = Vector2(最大宽, 0.0)
	_信息.size = Vector2(最大宽, _文字高(_信息.text, 正文字号))
	_信息.position = Vector2(内边距, y + 块间距)
	y += 块间距 + _信息.size.y
	# 职业行紧接着（原版三行在同一个 TextField 里，只有行距 4）
	y += 行距
	_职业行.size = Vector2(最大宽, 0.0)
	_职业行.size = Vector2(最大宽, _文字高(_职业行.text, 正文字号))
	_职业行.position = Vector2(内边距, y)
	y += _职业行.size.y

	# 图标框：x 固定 170，y = 基本信息块（三行）的纵向中点
	var 文字顶 := _信息.position.y
	var 文字总高 := _信息.size.y + 行距 + _职业行.size.y
	_图标框.position = Vector2(图标框位置.x, 文字顶 + (文字总高 - 图标框尺寸) / 2.0)
	_图标框.size = Vector2(图标框尺寸, 图标框尺寸)

	# 描述 + 特殊属性（原版这一块 y 不再额外 +5）
	var 说明 := _忍具说明
	if 说明.visible:
		说明.size = Vector2(最大宽, 0.0)
		说明.size = Vector2(最大宽, 说明.get_content_height())
		说明.position = Vector2(内边距, y)
		y += 说明.size.y

	var 线一 := _分隔线
	线一.size = Vector2(最大宽, 线一.texture.get_height() if 线一.texture else 2.0)
	线一.position = Vector2(内边距, y + 块间距)
	y += 块间距 + 线一.size.y

	_明细.size = Vector2(最大宽, 0.0)
	_明细.size = Vector2(最大宽, _明细.get_content_height())
	_明细.position = Vector2(内边距, y + 块间距)
	y += 块间距 + _明细.size.y

	var 线二 := _忍具分隔二
	线二.visible = true
	线二.size = Vector2(最大宽, 线二.texture.get_height() if 线二.texture else 2.0)
	线二.position = Vector2(内边距, y + 块间距)
	y += 块间距 + 线二.size.y

	_绑定.size = Vector2(最大宽, 字号行高)
	_绑定.position = Vector2(内边距, y + 块间距)
	y += 块间距 + _绑定.size.y

	var 框高 := y + 内边距
	_底.size = Vector2(框宽, 框高)
	size = Vector2(框宽, 框高)


## 灵器明细（原版 `MToolTipLingQiTip.createLingqiTipSprite`）。
## 版式与装备那份**不同**：没有强化/星排，耐久恒「永不磨损」，
## 基本属性逐条（`baseAttr` 可以是两条），附加属性上限来自 `addAttr`，
## 开光后再多一段「特殊属性」（职业/世界忍术等级、解印）。
func _拼灵器明细(实例: Dictionary, 灵器元: Dictionary) -> String:
	var 段: Array[String] = []
	段.append(耐久度 + 永不磨损)
	var 基础 := 灵器元.get("base_attr", []) as Array
	if not 基础.is_empty():
		段.append("[color=%s]%s[/color]" % [色_强化橙, 基本属性])
		for 项 in 基础:
			var 对 := 项 as Array
			if 对.size() < 2:
				continue
			var 类 := int(对[0])
			段.append("　%s　+%d" % [String(属性名.get(类, "属性%d" % 类)), int(对[1])])
	var 附加 := 实例.get("plus_attributes", []) as Array
	if not 附加.is_empty():
		var 上限 := 0
		var 上限表 := 灵器元.get("add_attr", []) as Array
		if not 上限表.is_empty() and (上限表[0] as Array).size() >= 2:
			上限 = int((上限表[0] as Array)[1])
		var 第一条值 := int((附加[0] as Dictionary).get("attribute_value", 0))
		var 抬头 := 附加属性满 if (上限 > 0 and 第一条值 == 上限) else 附加属性
		段.append("[color=%s]%s[/color]" % [色_强化橙, 抬头])
		for 项 in 附加:
			var 条 := 项 as Dictionary
			var 类 := int(条.get("attribute_type", 0))
			var 值 := int(条.get("attribute_value", 0))
			var 行 := "　%s　+%d" % [String(属性名.get(类, "属性%d" % 类)), 值]
			if 上限 > 0:
				行 += "（最大可提升至+%d）" % 上限 if 值 < 上限 else "【梦幻满值】"
			段.append(行)
	var 特殊 := 灵器元.get("special_attr", []) as Array
	if not 特殊.is_empty():
		段.append("[color=%s]%s[/color]" % [色_强化橙, 特殊属性])
		for 项 in 特殊:
			var 对 := 项 as Array
			if 对.size() < 2:
				continue
			var 名 := String(对[0])
			var 值 := int(对[1])
			match 名:
				"JOB_SKILL_LEVEL":
					段.append("　职业忍术等级　+%d" % 值)
				"WORLD_SKILL_LEVEL":
					段.append("　世界忍术等级　+%d" % 值)
				"ANTI_SEAL_PET":
					段.append("　解印　战斗中抵抗封印的几率 +%d%%" % 值)
	return "\n".join(段)


## 明细段。行序照 `MToolTipZhuangBei.as:348-380`（耐久 → 强化等级）与
## :405-553（基础属性 → 天生/强化/附加属性），破碎提示在 :789-808。
func _拼明细(物品id: String, 数值: int, 前置: int, 分类码: int, 实例: Dictionary, 元: Dictionary) -> String:
	var 段: Array[String] = []
	var 灵器元 := 元.get("灵器", {}) as Dictionary
	if not 灵器元.is_empty():
		return _拼灵器明细(实例, 灵器元)

	# 1) 耐久。原版：`(endure && maxEndure) == -1` 显示"永不磨损"，否则 "endure/maxEndure"
	var 耐久 := int(实例.get("endure", -1))
	var 上限 := int(实例.get("max_endure", 元.get("max_endure", -1)))
	var 耐久文本 := 永不磨损 if (耐久 == -1 and 上限 == -1) else "%d/%d" % [耐久, 上限]
	段.append(耐久度 + 耐久文本)

	# 2) 强化等级 + 行内蓝钻 + 星排。逐条对 `MToolTipZhuangBei.as`：
	#    · 行文本的数字是 **`strengthInfo.length`（强化"次数"，不是等级！）**（`:364`）；
	#      我们的字段 = `strength_info`（`后端连接:2880`）。字段缺失（离线示例数据）时
	#      退回旧口径按 `strengthen` 显示，**不新造次数**。
	#    · `满星` 附加的条件是"次数>0 且 `getStrengthState(等级)`（等级≥10）"（`:365-368`）；
	#    · 整行颜色 = 等级 0 ? 白 : 橙 `#ff9e16`（`:362`）；
	#    · 文字后面紧跟着**一枚小蓝钻**（`:732-743`）—— 等级<10 时原版挂
	#      `getDisableFilter()` 灰化，这里用预烘的灰版图（同流光的先例）；
	#    · 等级>10 再来**一枚蓝钻 + 橙色发光的【精炼额外加一星】**（`:744-754`）；
	#    · `createStarSprite`（`:370-377/1614-1644`）：星按**等级**给（最多 10 颗一行，
	#      >10 再缀一枚蓝钻），原版画在 x=22、行高 18 —— 我们排进明细流（缩进一个全角空格≈14px）。
	var 强化等级数 := int(实例.get("strengthen", 0))
	var 记录 = 实例.get("strength_info", null)
	var 有记录 := 记录 is Array
	var 次数 := (记录 as Array).size() if 有记录 else 强化等级数
	var 显示 := (次数 > 0) if 有记录 else (强化等级数 > 0)
	if 显示:
		var 行 := 强化等级 + str(次数)
		if 次数 > 0 and 强化等级数 >= 10:
			行 += 满星
		行 += "[img=12x10]%s[/img]" % (蓝钻图 if 强化等级数 >= 10 else 蓝钻灰图)
		if 强化等级数 > 10:
			行 += "[img=12x10]%s[/img]%s" % [蓝钻图, 精炼额外]
		段.append(("[color=%s]%s[/color]" % [色_强化橙, 行]) if 强化等级数 > 0 else 行)
		if 有记录 and 强化等级数 > 0:
			var 星行 := "　"
			for i in mini(强化等级数, 10):
				星行 += "[img=14x13]%s[/img]" % 星图标
			if 强化等级数 > 10:
				星行 += "[img=12x10]%s[/img]" % 蓝钻图
			段.append(星行)

	# 3) 基本属性段 —— 照 `MToolTipZhuangBei.as:405-429` 的**抬头 + 三条独立值行**，
	#    不是我们旧版的"一行大杂烩"（旧版三处失真，2026-10-01 用户报"天生打造看不到信息"）：
	#    ① 抬头三态（橙 16751126）：天生=基础 → `基本属性（满天生）`；两者>0 →
	#       `基本属性（天生NN%  +天生值）`，NN=`round(天生×100/基础)`、**算出 100 也写 99**（`:412-415`）；
	#       只有基础 → `基本属性`。**天生>0 但基础==0 时原版没有抬头**（只有下面的天生值行）——
	#       旧版整段被 `基础类型 != 0` 罩住，这类件（如基础类型未定的饰品）**天生/强化行整个不见**，
	#       就是用户那条反馈的真因之一。
	#    ② 名字行（白）：`　<属性名>　+<基础值>`，条件 `类型!=-1 且 !=MONEY(=0) 且 基础值>0`；
	#    ③ `　天生　+N` 行（橙，`MTOOTIP_INNATENESS :2136`）、④ `　强化　+N` 行（青 4059383=#3df0f7），
	#    两行**各看自己的值>0，互不牵连**（`:426-433`）。
	var 基础类型 := int(实例.get("base_attr_type", 元.get("base_attr_type", 0)))
	var 基础值 := int(实例.get("base_attr_value", 元.get("base_attr_value", 0)))
	var 天生值 := int(实例.get("born_attr_value", 0))
	var 强化值 := int(实例.get("strength_value", 0))
	# ⚠️ 2026-10-01 二次更正（用户拿原版满养成的图对出来）：**三段值在同一行**——
	#   原版的 `<br/>` 只出现在**抬头的两头**（`:407/:416/:419` 都是 "<br/>抬头<br/>"），
	#   名字段（:423）、`　天生　+N`（:427）、`　强化　+N`（:430）拼串时**都不带 <br/>**，
	#   所以是「攻击 +615 天生 +615 强化 +2245」一行三种色（图里正是这一行）。
	#   我第一版按"三条独立行"重写是读漏了 <br/> 的位置，这里改回合行、色标各管各段。
	if 天生值 > 0 and 基础值 > 0:
		var 抬头 := ""
		if 天生值 == 基础值:
			抬头 = 基本属性 + 满天生
		else:
			var 天生百分比 := int(round(float(天生值) * 100.0 / float(基础值)))
			if 天生百分比 == 100:
				天生百分比 = 99          # 原版那条 100→99 的怪癖，照抄
			抬头 = "%s（%s%d%%  +%d）" % [基本属性, 天生前缀, 天生百分比, 天生值]
		段.append("[color=%s]%s[/color]" % [色_强化橙, 抬头])
	elif 基础值 > 0:
		段.append("[color=%s]%s[/color]" % [色_强化橙, 基本属性])
	var 值行 := ""
	if 基础类型 != 0 and 基础类型 != -1 and 基础值 > 0:
		值行 += "　%s　+%d" % [String(属性名.get(基础类型, "属性%d" % 基础类型)), 基础值]
	if 天生值 > 0:
		值行 += "[color=%s]　%s　+%d[/color]" % [色_强化橙, 天生前缀, 天生值]
	if 强化值 > 0:
		值行 += "[color=#3df0f7]　强化　+%d[/color]" % 强化值
	if not 值行.is_empty():
		段.append(值行)

	# 4) 附加属性（`plus_attributes`，原版 `MToolTipZhuangBei.as:434-582`）
	#
	#    ⚠️ 这是整个提示框里**唯一一行混好几种颜色**的地方：抬头橙、属性行按资质、
	#    `追+N` 黄、`【梦幻满值】`/`最大可提升至+N` 绿。所以 `明细` 是 RichTextLabel，
	#    这一段拼的是 BBCode（原版那边是 htmlText 的 `<font>`）。
	#
	#    每条属性走**四条分支**（`:483-521`），由"上限表里有没有它 / 到没到顶 / 有没有精炼追加"
	#    三个开关决定；**上限表里没有的**那条只印属性本身 —— **连追加也不印**，
	#    这是原版的行为（`matched` 为假，`:524-532`），不是漏了。
	var 附加 := 实例.get("plus_attributes", []) as Array
	if not 附加.is_empty():
		var 精炼比例 := int(实例.get("forge_additive_ratio", 0))
		var 行色 := 附加属性色(装备品质表.显示档(物品id, int(实例.get("aptitude", 1))))
		var 抬头 := 附加属性
		if 精炼比例 > 0:
			抬头 += "   " + (精炼追加抬头 % [精炼比例, 精炼倍率])
		段.append("[color=#%s]%s[/color]" % [色_附加抬头.to_html(false), 抬头])

		# 上限表 `plus.stage<阶>[<部位类型名>]` —— 查不到就整段退化成"只印属性本身"
		# ⚠️ 名字别叫 `上限`：上面"耐久"那一段已经有一个 `上限` 了（parse error 只报这一句，
		# 而且**整个脚本直接加载失败** —— 场景根节点会退化成没脚本的空 Control）。
		var 上限表 := {}
		for 条目 in 装备打造表.取附加属性上限(
				int(元.get("stage", 1)), String(元.get("type_name", ""))).values():
			if 条目 is Dictionary:
				上限表[String((条目 as Dictionary).get("type", ""))] = int((条目 as Dictionary).get("valueTo", 0))

		var 附加行: Array[String] = []
		var 经验行: Array[String] = []
		var 特殊行: Array[String] = []
		var 白 := Color.WHITE.to_html(false)
		for 条 in 附加:
			if not (条 is Dictionary):
				continue
			var d := 条 as Dictionary
			var 类型 := int(d.get("attribute_type", 0))
			var 值 := int(d.get("attribute_value", 0))
			if 值 == 0:
				continue
			# 原版先把这两类**挑出来单独成段**（`:459-466`），它们不参与上面那四条分支
			if 类型 == 24:                       # ANTI_SEAL_PET
				特殊行.append(解印文案 % 值)
				continue
			if 类型 == 25:                       # MOB_EXP
				经验行.append("　%s　+%d%%" % [String(属性名.get(类型, "属性%d" % 类型)), 值])
				continue

			var 本行 := "　%s　+%d%s" % [
				String(属性名.get(类型, "属性%d" % 类型)), 值,
				"%" if 类型 in 百分比属性 else ""]
			# 这一条的精炼追加值：`ceil(值 × 比例 × 5 / 100)`（`:473`）
			var 追文本 := ""
			if 精炼比例 > 0:
				var 追加 := int(ceil(float(值) * float(精炼比例) * float(精炼倍率) / 100.0))
				if 追加 > 0:
					追文本 = "  [color=#%s]%s[/color]" % [色_追加.to_html(false), 追加前缀 % 追加]

			var 英文名 := String(属性英文名.get(类型, ""))
			var 上限值 := int(上限表.get(英文名, -1))
			var 行 := 本行
			if 上限表.has(英文名):
				if 值 == 上限值:                 # 到顶了（原版是 `==`，不是 `>=`）
					行 += 追文本 + "[color=#00ff00]%s[/color]" % 梦幻满值带空格
				else:
					行 += 追文本 + "[color=#00ff00]%s[/color]" % (最大可提升 % 上限值)
			elif 上限表.is_empty():
				行 += 追文本                     # 整张表都没有 → 原版走 `:534-542`
			# else：表在、但这一条不在表里 → 原版只印属性本身（`:524-532`），**不加追文本**
			附加行.append("[color=#%s]%s[/color]" % [行色.to_html(false), 行])

		if not 附加行.is_empty():
			段.append("\n".join(附加行))
		if not 经验行.is_empty():
			段.append("[color=#%s]%s[/color]" % [色_经验加成.to_html(false), "\n".join(经验行)])
		if not 特殊行.is_empty():
			段.append("[color=#%s]%s[/color]\n[color=#%s]%s[/color]"
				% [色_附加抬头.to_html(false), 特殊属性, 白, "\n".join(特殊行)])

	# 5) 镶嵌属性不在这里拼 —— 它每行带 22x22 石头图标，见 `_建镶嵌块`。

	# 6) 特性属性（`MTToolTipZhuangBei.as:589-621`）
	#
	#    ⚠️ 触发条件看着绕，其实是**原版那个开关的默认值**在起作用：
	#      `:590` = `(param2 || !SysCfg.splitEquipExtraTooltip || isTransformCard)`，
	#      `splitEquipExtraTooltip` **默认 true**（`SysCfg.as:50`、`CharacterConfig.as:37`），
	#      而 `param2` 是 `createEqpTip:1539` 传下来的
	#      `isTransformCardItem(甲) || isTransformCardItem(乙)`（甲/乙 = 本件与对比件）
	#      ⇒ **单件悬浮时条件就是"这件本身是变身卡"**（`itemId / 10000 == 121 或 205`）。
	#      （同一个开关还把「神话属性段」整段关掉 —— 那正是它在 TODO 里一直"没做"的原因，
	#       不是我们漏了；开关的 UI 与本工程都没做 ⇒ 一律按默认 true 实现。）
	#
	#    行文本、那个 `⚡`、三条「～の力」文案都是 AS3 里的字面量，逐字照抄（`:595-620`）：
	#    ⚠️ 这里的「の力」文案与**变身卡互换窗**那份**不一样**（那边是 `getSwapSpecialEffectDesc`
	#       的通用描述，这边是带「牛鬼/守鹤/矶抚」的三句），别互相抄。
	var 特性表 := 实例.get("special_attributes", []) as Array
	var 特性效 := int(实例.get("special_effect_type", 0))
	var 特性影 := int(实例.get("afterimage_flag", 0))
	# ⚠️ 用**入参的 物品id**，不是 `实例.id`：原版那两处判的是同一个 `value.itemId`
	#    （`isTransformCardItem`），而我们的 `实例` 在离线/部分调用点根本不带 `id` 键。
	var 本件号 := int(物品id) if 物品id.is_valid_int() else 0
	var 是变身卡 := 本件号 / 10000 == 121 or 本件号 / 10000 == 205
	if 是变身卡 and (not 特性表.is_empty() or 特性效 > 0 or 特性影 > 0):
		var 特性行 := ""
		var 序号 := 0
		for 条 in 特性表:
			if not (条 is Dictionary):
				continue
			var d := 条 as Dictionary
			var 类型 := int(d.get("attribute_type", 0))
			var 值 := int(d.get("attribute_value", 0))
			# 变身卡那支是 `specialIndex < 4`（`:601`；非变身卡才是 `< 3`）
			特性行 += "\n　%s　+%d%s" % [String(属性名.get(类型, "属性%d" % 类型)), 值,
				"%" if 序号 < 4 and 值 > 0 else ""]
			序号 += 1
		match 特性效:
			1: 特性行 += "\n　牛鬼の力：攻击时无论是否命中，回复自身2%血量"
			2: 特性行 += "\n　守鹤の力：攻击时2%概率获得特殊buff，提升10%防御，持续5秒"
			3: 特性行 += "\n　矶抚の力：攻击时2%概率获得特殊buff，提升10%攻击，持续5秒"
		if 特性影 > 0:
			特性行 += "\n　残影显现!(特殊效果)"
		段.append("[color=#%s]%s[/color][color=#%s]%s[/color]" % [
			色_特性抬头.to_html(false), 特性属性闪电,
			附加属性色(装备品质表.显示档(物品id, int(实例.get("aptitude", 1)))).to_html(false), 特性行])

	# 7) 破碎提示（`:789-808`）
	if int(实例.get("crash_time", 0)) > 0:
		段.append(该装备破碎 + "，" + 可修复破碎)

	return "\n".join(段)


## 建「镶嵌属性」段。**作为 `_明细` 标签的子节点**，y 直接用标签**实测的**
## `size.y`（排版里刚算过）—— 不依赖我对文字高的估算，估偏了也不会压字。
## 版式照原版 `createInlaySprite`（`MTTipZhuangBei.as:1686-1729`）：
## 抬头一行，然后每颗宝石一行（22x22 图标贴 x=0、文字 x=20、行高 18）。
## 版式照原版 `createInlaySprite`（`MTTipZhuangBei.as:1686-1729`）：
## 图标 `width = height = 22` 贴 x=0，文字 x=20，行高 18。
func _建镶嵌块(实例: Dictionary) -> void:
	# ⚠️⚠️ **挂到提示框根，不能挂 `_明细` 底下**（2026-10-02 用户报"镶嵌后提示框没宝石信息"的真因）：
	#   `_明细` 是 RichTextLabel，**`clip_contents = true` 会裁剪子节点**；而镶嵌块摆在
	#   `明细.size.y + 间距` 处 = **明细矩形之外** → 整段被裁掉、永远看不见。
	#   （旧门只数子节点文本/个数，**看不到"裁没裁"**，所以这 bug 藏了一轮多。）
	#   原版 `createInlaySprite` 是把这排东西加进**提示框内容**（参与 bgHeight 累加），
	#   本就该在根层。位置改为「明细左沿 + 明细底 + 间距」，与 RTL 文本左对齐。
	if _镶嵌块.get_parent() != self:
		if _镶嵌块.get_parent() != null:
			_镶嵌块.get_parent().remove_child(_镶嵌块)
		add_child(_镶嵌块)
	# ⚠️ 位置**不在这里定** —— 由 `_排版` 按当时**累计的 y**摆（`_建镶嵌块` 在稀有段之后调）。
	#   原来这里写「明细底 + 间距」，当**稀有段可见**时与稀有段**同 y 重叠**（两者都从明细底起算）。
	# ⚠️ **当场删**（`remove_child` + `free()`），别用 `queue_free()` —— 后者延迟到帧末，
	#    同一帧里紧跟着的"重建/判断"会看到**残留的旧行**（§3.79.8 那条"动态节点清理"。
	#    实测：连做两次 设置（先有镶嵌后无镶嵌），旧宝石行这一帧还在）。
	for 子 in _镶嵌块.get_children():
		_镶嵌块.remove_child(子)
		子.free()
	var 孔 := 实例.get("inlays", []) as Array
	if 孔.is_empty():
		return
	var 行高 := 18.0
	var y := 0.0
	var 抬头 := Label.new()
	抬头.text = 镶嵌属性
	抬头.add_theme_font_size_override("font_size", 正文字号)
	抬头.add_theme_color_override("font_color", 色_镶嵌)
	抬头.position = Vector2(0.0, y)
	抬头.size = Vector2(最大宽, 行高)
	抬头.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_镶嵌块.add_child(抬头)
	# 抬头右侧的金钻（`MToolTipZhuangBei.as:769-775 GoldDiamondIconF`）：`getInlayState` 为假时**置灰**
	# （原版 `filters = getInlayState ? null : getDisableFilter()`）。x = 抬头的实测文字宽之后。
	var 钻路径 := "res://素材/界面/原版窗口/人物/角色/金钻.png"
	if ResourceLoader.exists(钻路径):
		var 钻 := TextureRect.new()
		钻.texture = load(钻路径) as Texture2D
		var 字 := 抬头.get_theme_font("font")
		var 抬宽 := float(字.get_string_size(镶嵌属性, HORIZONTAL_ALIGNMENT_LEFT, -1, 正文字号).x)
		钻.position = Vector2(抬宽 + 2.0, y + 3.0)
		钻.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not _镶嵌齐全(孔):
			钻.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_镶嵌块.add_child(钻)
	y += 行高
	## 玉链那一路：镶嵌条目的 `attribute_type` 是 **-1**、真加成写在 `skill_id` 上
	## （`{"stone_id","stone_level","attribute_type","skill_id","attribute_value"}`，
	## 见 `后端连接.gd:6200`；实测 `[13101102, 3, -1, 3007, 3]`）。
	## 原版 `MToolTipZhuangBei.createInlaySprite:1709-1711` 对 `isItemAYuLian` 的分支是
	## `宝石名 + getSkillString(skillId) + "+" + attrValue + "层"`（`MTOOL_TIPITEM_CENG:648`），
	## **不是** `getBaseAttrName(-1)` —— 照旧写法会显示「火之勾玉属性-1+3」。
	var 本件id := String(实例.get("id", ""))
	if 本件id.is_empty():
		本件id = _当前物品id
	var 是玉链 := 装备部位表.位置(本件id) == 装备部位表.勾玉
	for 条 in 孔:
		if not (条 is Dictionary):
			continue
		var d := 条 as Dictionary
		var 石id := str(int(d.get("stone_id", 0)))
		# ⚠️ 原版行区整体 `x=22`（`createInlaySprite` 的 `inlaySprite.x=22`），块本身贴在「内边距」处
		#    ⇒ 块内图标 x = 22 − 内边距(8) = **14**、文字 x = 14 + 20 = **34**。
		#    （第一版图标摆 x=0 = 内边距处，且**没强制 22×22** —— `TextureRect` 默认 `KEEP_SIZE`
		#      会按原图大小画，宝石图标 ~34px 叠在一起，正是用户 2026-10-02 报的"位置不对"。）
		var 图标 := TextureRect.new()
		# ⚠️ **顺序**：先设 `expand_mode=IGNORE_SIZE` + `stretch_mode`，**再设贴图，最后设 size**。
		#   反过来（先贴图后设 size）时 expand 还是默认 `KEEP_SIZE`，节点最小尺寸被贴图(34)顶住、
		#   `size=22` 会被夹回 34 —— 实测图标仍是 34px 叠在一起（2026-10-02 用户报"位置不对"的根）。
		图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图标.size = Vector2(22.0, 22.0)
		图标.texture = GAME_DATA.item_icon(石id)
		图标.position = Vector2(14.0, y - 6.0)   ## 原版 `icon.y = 行号*18 - 6`（图比行高）
		图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_镶嵌块.add_child(图标)
		var 文字 := Label.new()
		if 是玉链:
			var 技能号 := int(d.get("skill_id", 0))
			var 技能名 := String(GAME_DATA.skill_text(技能号).get("name", ""))
			if 技能名.is_empty():
				技能名 = str(技能号)
			文字.text = "%s%s+%d%s" % [GAME_DATA.item_name(石id), 技能名,
				int(d.get("attribute_value", 0)), 镶嵌层]
		else:
			文字.text = "%s%s+%d" % [GAME_DATA.item_name(石id),
				String(属性名.get(int(d.get("attribute_type", 0)), "属性%d" % int(d.get("attribute_type", 0)))),
				int(d.get("attribute_value", 0))]
		文字.add_theme_font_size_override("font_size", 正文字号)
		文字.add_theme_color_override("font_color", 色_镶嵌)
		文字.position = Vector2(34.0, y)     # 行区 x=22（内边距8 + 14）+ 原版文字 x=20
		文字.size = Vector2(最大宽 - 34.0, 行高)
		文字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_镶嵌块.add_child(文字)
		y += 行高
	_镶嵌块.size = Vector2(最大宽, y)


## 金钻亮不亮 = 原版 `ItemFactory.getInlayState`：**孔数≥5**，且 5 孔时**全 6 级+**、
## 6 孔及以上时**最多允许 1 颗 < 6 级**；孔数<5 一律不亮。
func _镶嵌齐全(孔: Array) -> bool:
	if 孔.size() < 5:
		return false
	if 孔.size() == 5:
		for 条 in 孔:
			if int((条 as Dictionary).get("stone_level", 0)) < 6:
				return false
		return true
	var 低 := 0
	for 条 in 孔:
		if int((条 as Dictionary).get("stone_level", 0)) < 6:
			低 += 1
			if 低 > 1:
				return false
	return true


## 稀有段：传说属性 + 秘印属性。拆成两个 Label（颜色不同），外加刻印进度图。
## 抬头色照原版 `MTTipZhuangBei.as:585` / `:894` 都是橙(16751126)；值行另有颜色，
## 本版暂时整段同橙（已知差距，见 TODO）。
func _填稀有段(实例: Dictionary) -> void:
	# 传说属性（`:583-588`）
	var 传类型 := int(实例.get("tale_attr_type", -1))
	var 传值 := int(实例.get("tale_attr_value", 0))
	if 传值 > 0:
		var 加百分号 := 传类型 in [11, 12, 13, 14]   ## ATK_RATE / DAMAGE_REFLECT / DAMAGE_REDUCE / IGNORE_DEF
		_传说段.text = "%s
　%s　+%d%s" % [传说属性,
			String(属性名.get(传类型, "属性%d" % 传类型)), 传值, "%" if 加百分号 else ""]
	else:
		_传说段.text = ""
	_传说段.visible = not _传说段.text.is_empty()
	_传说段.size = Vector2(最大宽, 0.0)
	_传说段.size = Vector2(最大宽, _文字高(_传说段.text, 正文字号))

	# 秘印属性（`:892-955`）
	var 刻id := int(实例.get("carve_id", 0))
	_秘印段.text = ""
	var 有刻印 := false
	if 刻id != 0:
		var 配置 := _刻印配置(刻id)
		if not 配置.is_empty():
			var 刻值 := int(实例.get("carve_value", 0))
			var 刻印上限 := int(配置.get("value_max", 0))
			var 尾 := 梦幻满值 if 刻值 == 刻印上限 else "（%s%d%%）" % [最大, 刻印上限]
			# 抬头「秘印属性」在**另一个橙色 Label** 里，这里只放值行（绿）。
			_秘印抬头.text = 秘印属性
			_秘印抬头.visible = true
			_秘印段.text = "  %s   %s%d%%%s" % [String(配置.get("name", "")),
				String(属性名.get(int(实例.get("carve_type", 0)), "")), 刻值, 尾]
			有刻印 = true
	_秘印段.visible = 有刻印
	_秘印抬头.visible = 有刻印
	if not 有刻印:
		_秘印抬头.text = ""
	_秘印段.size = Vector2(最大宽, 0.0)
	_秘印段.size = Vector2(最大宽, _文字高(_秘印段.text, 正文字号))

	# 刻印进度图贴在秘印文字下方。⚠️ 传说段**已不在此容器内**（`_排版` 把它挂到根、紧跟明细），
	#    这里只排秘印组（抬头/段/图），从 0 起算（容器整体由 `_排版` 摆到最底）。
	var y := 0.0
	if _秘印抬头.visible:
		_秘印抬头.position = Vector2(0.0, y)
		_秘印抬头.size = Vector2(最大宽, _文字高(_秘印抬头.text, 正文字号))
		y += _秘印抬头.size.y
	if _秘印段.visible:
		_秘印段.position = Vector2(0.0, y)
		y += _秘印段.size.y
	_建刻印图(实例, y)
	_稀有明细.size = Vector2(最大宽, y + (120.0 if 有刻印 else 0.0))


## 刻印进度图。原版 `MToolTipZhuangBei.as:928-950`：
## * 图 = `UIBmp_KeYinTips_keyin<carve_id>.swf`，尺寸 **240x120**
##   （`KEYIN_ICON_WIDTH/HEIGHT`），x 居中 = `(280 - 240) / 2 + 8`。
## * **两层**：底层整图套灰（`Style.getDisableFilter()`），上层原图**裁到**
## * 已刻比例 `keyinPercent = 1 - carve_value / value_max`（`:907`）；
##   掩盖宽度 = `图宽 × keyinPercent`，**盖在彩色图的左侧**。
##   → 满值(比例 0) 时掩盖宽 0 ⇒ **整张彩色**；值越小左侧被盖得越多（露出灰底）。
##   ⚠️ 我第一版把方向搞反了（满值显示全灰），实测原版满值那张是**彩色**的，已改。
func _建刻印图(实例: Dictionary, y: float) -> void:
	# ⚠️ 清旧图必须 **remove_child + free() 当场生效**，不能 queue_free：
	#    queue_free 要等帧尾才真删，这一帧里同名节点还挂在父下——紧接着 add_child
	#    撞名会被 Godot 自动改名成 `@TextureRect@N`，而"按名清理"下一轮就再也匹配不到它们，
	#    **一层层摞出来**（彩色/灰盖各一套叠在同一坐标）。提示框短时间被反复重渲染
	#    （打造一路回包刷新 + 一帧里多次进入）就踩得着 —— 2026-10-01 用户报
	#    "装备多次打造后提示框图案重叠"，探针同帧连设三次当场复现。
	#    按 `begins_with("刻印图")` 筛，旧版改名留下的 "@N" 后缀也一并扫掉。
	for 子在 in _稀有明细.get_children():
		if String(子在.name).begins_with("刻印图"):
			_稀有明细.remove_child(子在)
			子在.free()
	var 刻id := int(实例.get("carve_id", 0))
	if 刻id == 0:
		return
	var 路径 := "res://素材/界面/原版窗口/人物/刻印/秘印%d.png" % 刻id
	if not ResourceLoader.exists(路径):
		return
	var 配置 := _刻印配置(刻id)
	var 上限 := int(配置.get("value_max", 0))
	var 比例 := 1.0 if 上限 <= 0 else 1.0 - float(int(实例.get("carve_value", 0))) / float(上限)
	var 图宽 := 240.0
	var 图高 := 120.0
	var 图x := (最大宽 - 图宽) / 2.0
	# 底层：整张彩色
	var 彩 := TextureRect.new()
	彩.name = "刻印图"
	彩.texture = load(路径) as Texture2D
	彩.size = Vector2(图宽, 图高)
	彩.position = Vector2(图x, y)
	彩.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_稀有明细.add_child(彩)
	# 上层：灰色遮罩盖住**左侧未刻到的部分**（宽度 = 图宽 × 比例）
	var 盖宽 := 图宽 * 比例
	if 盖宽 > 0.0:
		var 灰 := TextureRect.new()
		灰.name = "刻印图灰"
		灰.texture = load(路径) as Texture2D
		灰.size = Vector2(盖宽, 图高)
		灰.position = Vector2(图x, y)
		灰.modulate = Color(0.35, 0.35, 0.35, 1.0)   ## 近似原版 getDisableFilter 的观感
		灰.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_稀有明细.add_child(灰)


## 图标框里的三样：图标本身、资质框（+紫橙流光）、破碎角标（25x16 贴 (0,0)）。
## 条件与格子那条路同源，全在 `数据/装备品质.json`；
## 版式差别见 `装备品质.gd` —— 提示框的覆盖层是加在**图标**上（`MToolTipZhuangBei.as:172-181`：
## aptitudeIcon (-3,-3)、equipAnimationF (1,1)），格子里是加在**格子**上。
## 图标在 40x40 的框里是**居中**的、位置随图片尺寸动，所以 `起点` 传 `_图标.position`。
## 灵器/忍具两族**整族恒粉框 + 流光**，与资质无关（素材与「灵气」那档同一份），
## 各自的提示框类里是无条件建的：灵气 `MToolTipLingQiTip.as:91-101`、
## 忍具 `MToolTipRenJuTip.as:93-102`。所以这里按**物品 id 认族**，不靠调用方传开关。
func _设图标(物品id: String, 实例: Dictionary) -> void:
	_图标.texture = GAME_DATA.item_icon(物品id)
	if _图标.texture == null:
		_图标框.visible = false
		return
	_图标框.visible = true
	var 边 := _图标.texture.get_size()
	_图标.size = 边
	var 偏移 := floorf((图标框尺寸 - 边.y) / 2.0)
	_图标.position = Vector2(偏移, 偏移)
	# 灵气与忍具两族走各自提示框类的恒粉框分支（见函数头），其余按资质表。
	装备品质表.挂覆盖层(_图标框, 实例, 装备品质表.是灵气(物品id), "提示框", _图标.position,
			装备品质表.是忍具(物品id))
	_破碎.visible = int(实例.get("crash_time", 0)) > 0


## 标题排布。原版有两条：
## * **无后缀**（单列）：`titleTF.width = MAX_WIDTH` + `align = CENTER`，后缀（如果有）是
##   **拼在同一个 htmlText 里**一起居中的（`:205-211`）。
## * **有后缀**（渐变标题那条支路才有独立文本框）：名与后缀量宽后**整组**居中
##   `x = PADDING + (MAX_WIDTH - 组宽) / 2`，后缀顶在名的右边界（`:222-235`）。
## 我们没移植彩虹渐变标题（见文末 TODO），所以带后缀时借第二条那套**量宽**的算法 ——
## 效果与第一条等价（整组居中），但后缀能单独上色，不用 BBCode。
## ⚠️ 原版**不钳组宽**：名字长到超出 `MAX_WIDTH` 时标题往框外溢。这里照旧不钳 ——
##    实测最长的装备名（6 字）+ `(已装备)` 约 160px，离 280 还远。
func _排标题() -> void:
	var 后缀节点 := _对比后缀
	if _对比后缀文本.is_empty() or 后缀节点 == null:
		if 后缀节点 != null:
			后缀节点.visible = false
		_标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_标题.size = Vector2(最大宽, 标题高)
		_标题.position = Vector2(内边距, 内边距)
		return
	var 名宽 := _文字宽(String(_标题.text), 标题字号)
	var 后缀宽 := _文字宽(_对比后缀文本, 标题字号)
	_标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_标题.size = Vector2(名宽, 标题高)
	_标题.position = Vector2(内边距 + (最大宽 - 名宽 - 后缀宽) / 2.0, 内边距)
	后缀节点.text = _对比后缀文本
	后缀节点.add_theme_color_override("font_color", 色_对比后缀)
	后缀节点.size = Vector2(后缀宽, 标题高)
	后缀节点.position = Vector2(_标题.position.x + 名宽, 内边距)
	后缀节点.visible = true


## `bgHeight` 累加排版，与 `物品提示框.gd` 同一套增量。
func _排版() -> void:
	var 字号行高 := _单行高(正文字号)
	var y := 内边距
	_排标题()
	y += 标题高

	for 节点 in [_信息, _职业行, _描述]:
		if not 节点.visible:
			continue
		var 文本: String = (节点 as Label).text
		节点.size = Vector2(最大宽, 0.0)
		节点.size = Vector2(最大宽, _文字高(文本, 正文字号))
		节点.position = Vector2(内边距, y + 块间距)
		y += 块间距 + 节点.size.y

	# `明细` 是 RichTextLabel（原版 `contentText3` 是 htmlText，附加属性那一块一行里混几种颜色）。
	# ⚠️ 高度必须问它自己 —— `_文字高()` 不认识 BBCode，会把 `[color=…]` 标签也量进去。
	if _明细 != null and _明细.visible:
		_明细.size = Vector2(最大宽, 0.0)                 # 先定宽度，再问高度
		_明细.size = Vector2(最大宽, _明细.get_content_height())
		_明细.position = Vector2(内边距, y + 块间距)
		y += 块间距 + _明细.size.y

	# 传说段：**从稀有容器里拆出来**，紧跟附加属性（原版 `content3` = 附加→传说→镶嵌抬头，见 顶级装备.png）。
	# ⚠️ 2026-10-02 用户报"镶嵌跑到秘印下面"：原版秘印在**最底（绑定之后）**，而我把传说+秘印塞同一容器
	#    整块摆在明细后 → 秘印顶到镶嵌上面。现按原版拆开：**传说留这、秘印挪到最后**（下方绑定之后）。
	var 传 := _传说段            # ⚠️ 取一次存局部：getter 每次访问都重新 get_node，reparent 中途会取到 null
	if 传 != null and 传.visible:
		if 传.get_parent() != self:
			if 传.get_parent() != null:
				传.get_parent().remove_child(传)
			add_child(传)
		传.position = Vector2(内边距, y + 块间距)
		y += 块间距 + 传.size.y

	# 镶嵌块挂在明细之下（用明细的**实测高**定位，见 `_建镶嵌块`）。
	# ⚠️ 它占的高度必须在这里就并进 `y` —— 否则后面的分隔线/绑定行会压到宝石行上，
	# （第一版就是漏了这一步，"已绑定"叠在宝石行上）。原版是把它拼进 contentText3、
	# 天然参与 `bgHeight` 累加，所以这里也要算进去。
	_建镶嵌块(_当前实例)
	_镶嵌块.visible = true		# 忍具那支会把它藏起来（见 `_填忍具`），回到装备要复位
	if _镶嵌块.get_child_count() > 0:
		_镶嵌块.position = Vector2(内边距, y + 块间距)   # 接在**稀有段之后**（累计 y），不跟它撞
		y += 块间距 + _镶嵌块.size.y

	_分隔线.size = Vector2(最大宽, _分隔线.texture.get_height() if _分隔线.texture else 2.0)
	_分隔线.position = Vector2(内边距, y + 块间距)
	y += 块间距 + _分隔线.size.y

	var 行数 := (1 if _价格.visible else 0) + (1 if _绑定.visible else 0)
	if 行数 > 0:
		var 首行y := y + 块间距
		var 第几行 := 0
		for 行 in [_价格, _绑定]:
			if not 行.visible:
				continue
			行.size = Vector2(最大宽, 字号行高)
			行.position = Vector2(内边距, 首行y + 第几行 * (字号行高 + 行距))
			第几行 += 1
		y += 块间距 + 行数 * 字号行高 + (行数 - 1) * 行距

	# 秘印段（稀有容器现在只装秘印组）：原版在**最底、绑定行之后**（`MTipZhuangBei.as:889+`，
	# 见 `对比图/顶级装备.png`：…镶嵌属性 → 分隔线 → [已绑定] → 秘印属性）。
	if _稀有明细 != null and _稀有明细.visible:
		_稀有明细.position = Vector2(内边距, y + 块间距)
		y += 块间距 + _稀有明细.size.y

	_图标框.position = 图标框位置
	_图标框.size = Vector2(图标框尺寸, 图标框尺寸)

	var 框高 := y + 内边距
	_底.size = Vector2(框宽, 框高)
	size = Vector2(框宽, 框高)


## `MToolTip.setLocation`：贴鼠标右下再钳进舞台；比舞台高就整体缩放。
func 贴到鼠标(鼠标位置: Vector2, 舞台尺寸: Vector2) -> void:
	scale = Vector2.ONE
	if size.y > 舞台尺寸.y - 8.0:
		var 比 := (舞台尺寸.y - 8.0) / size.y
		scale = Vector2(比, 比)
	var 位置 := 鼠标位置 + Vector2(10.0, 20.0)
	位置.x = clampf(位置.x, 0.0, maxf(0.0, 舞台尺寸.x - size.x * scale.x))
	位置.y = clampf(位置.y, 0.0, maxf(0.0, 舞台尺寸.y - size.y * scale.y))
	position = 位置


## **两列一组**的摆位（悬停件在左、身上穿戴件在右）。
## 原版是把两列 `addChild` 进同一个 Sprite、列与列**紧贴**（`createEqpTip:1552-1575`
## 只做 `_loc6_ += 左.width; 右.x = _loc6_`，没有间距），组高取两列的较大者，
## 然后**整组**走一次 `MToolTip.setLocation`（`MToolTip.as:123-145`）——
## ⇒ 缩放按组高、右边界钳位按**组宽**（不是只钳左列），两列顶边对齐。
## ⚠️ `右列` 必须与自己是**同一个父节点**下的兄弟：这里全程用父局部坐标，没有换算。
func 贴成一对(鼠标位置: Vector2, 舞台尺寸: Vector2, 右列: Control) -> void:
	scale = Vector2.ONE
	if 右列 == null:
		贴到鼠标(鼠标位置, 舞台尺寸)
		return
	右列.scale = Vector2.ONE
	var 组宽 := size.x + 右列.size.x
	var 组高 := maxf(size.y, 右列.size.y)
	var 比 := 1.0
	if 组高 > 舞台尺寸.y - 8.0:
		比 = (舞台尺寸.y - 8.0) / 组高
	scale = Vector2(比, 比)
	右列.scale = Vector2(比, 比)
	var 位置 := 鼠标位置 + Vector2(10.0, 20.0)
	位置.x = clampf(位置.x, 0.0, maxf(0.0, 舞台尺寸.x - 组宽 * 比))
	位置.y = clampf(位置.y, 0.0, maxf(0.0, 舞台尺寸.y - 组高 * 比))
	position = 位置
	右列.position = 位置 + Vector2(size.x * 比, 0.0)


func _字体() -> Font:
	return _信息.get_theme_font("font")


func _单行高(字号: int) -> float:
	return _字体().get_height(字号)


func _文字高(文本: String, 字号: int) -> float:
	var 尺寸 := _字体().get_multiline_string_size(文本, HORIZONTAL_ALIGNMENT_LEFT, 最大宽, 字号)
	var 单行 := _单行高(字号)
	var 行数 := 1 if 单行 <= 0.0 else int(round(尺寸.y / 单行))
	行数 = maxi(行数, 1)
	return 尺寸.y + 行距 * (行数 - 1)


## 单行**宽度**（标题整组居中度量用，见 `_排标题`）。不限行宽、不换行。
func _文字宽(文本: String, 字号: int) -> float:
	return _字体().get_string_size(文本, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 字号).x


# TODO（原版有、本文件还没做，按 §3.11.3 往后排）：
#   * 神话属性段（`MToolTipZhuangBei.as:622-695`）+ 神话星级图标
#   * ~~特性属性段（:589-621）~~ —— **2026-10-14 §3.160 做了**（数据面 §3.159 打通，见上面第 6 段）
#   * 神话属性段在**默认开关下原版自己也不显示**（`!SysCfg.splitEquipExtraTooltip` 那半个条件，
#     默认 true ⇒ 恒假）⇒ 真要做得先做那个开关的 UI，不是"补一段文本"。
#   * 刻印段（:892-955）+ 传说属性（:583-588）+ 怪物经验/特殊属性（:555-581）
#   * 变身卡重铸时间（:244-273）
#   * ~~两件对比模式（SysCfg.splitEquipExtraTooltip，:1530-1612）~~
#     —— **2026-10-24 §3.259 做了两列那半**：标题挂「(已装备)」＋ `贴成一对` 的组摆位，
#     右列由 `格子提示框._填对比列` 按调用点现建。
#     ⚠️ **有意只做两列、没做四列**：原版默认 `splitEquipExtraTooltip = true`
#     （`SysCfg.as:50`）会把**附加属性另起一栏**，单件也是两栏（`:1596-1605`）。
#     本工程从第一版起就把附加属性排在主栏里（`物品提示框` 同一套内核），
#     所以对比沿用"`splitEquipExtraTooltip == false` 那支"的两列形状：
#     [查看件][穿戴件(已装备)]，与报修要的"右侧补身上穿戴件"一致。
#     四栏版式要动的是整个 tooltip 的内核（不只这里），单独立项。
#   * 标题彩虹渐变（神话件用 GradientTextField，:213-242）

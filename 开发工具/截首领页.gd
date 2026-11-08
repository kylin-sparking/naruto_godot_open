extends "res://开发工具/量具基类.gd"

## 量「首领」窗（原版 `com/mxw/uifl/controls/wangBoss/WangBossWindow.as` + `WangBossCell.as`，573×324）。
## 骨架在 `开发工具/量具基类.gd`；场景由 `开发工具/生成首领场景.py` 从本文件的
## `件路径 / 件期望 / 件文案` 三张表生成 ⇒ **改真值只改这里**，别手改 .tscn。
##
## 坐标链（逐条有出处，全表见 `game-client/真值/窗口/首领.md`）：
##   `background` MWindow_background 573×324 `:82-85`（**外壳 `_frame` 画，页面不重复画**）
##   `background2` MYellow @(6,39) 561×260 `:90-95`
##   `cell0/1/2` @(11/195/379, 44) 183×250 `:96-107`
##   `_pageComponent` = PageComponent(条数,3) @(224,299) 124×20 `:61-64`
##   页面容器原点 (0,29)（`窗口尺寸.json` 的「首领」标 `整框: true`）
##   ⇒ **场景 y = AS3 窗口局部 y − 29**
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截首领页.gd -- --出目录=res://测试/截图/首领

const 件路径 := {
	"外框黄底": "外框黄底",
	"卡片0": "卡片_0", "卡片1": "卡片_1", "卡片2": "卡片_2",
	"卡片0底": "卡片_0/卡片底", "卡片0头像底": "卡片_0/头像底", "卡片0头像": "卡片_0/头像底/头像",
	"卡片0序号": "卡片_0/序号", "卡片0名称": "卡片_0/名称", "卡片0类型": "卡片_0/类型",
	"卡片0信息底": "卡片_0/信息底", "卡片0等级标签": "卡片_0/等级标签", "卡片0等级数值": "卡片_0/等级数值",
	"卡片0地图标签": "卡片_0/地图标签", "卡片0地图数值": "卡片_0/地图数值",
	"卡片0时间标签": "卡片_0/时间标签", "卡片0时间数值": "卡片_0/时间数值",
	"卡片0爆率标签": "卡片_0/爆率标签", "卡片0挑战钮": "卡片_0/挑战钮", "卡片0星级": "卡片_0/星级",
	"卡片0星0": "卡片_0/星级/星_0", 	"卡片0星1": "卡片_0/星级/星_1", 	"卡片0星2": "卡片_0/星级/星_2",
	"卡片0星3": "卡片_0/星级/星_3", 	"卡片0星4": "卡片_0/星级/星_4", 	"卡片0星5": "卡片_0/星级/星_5",
	"卡片0星6": "卡片_0/星级/星_6",
	"卡片1底": "卡片_1/卡片底", "卡片1头像底": "卡片_1/头像底", "卡片1头像": "卡片_1/头像底/头像",
	"卡片1序号": "卡片_1/序号", "卡片1名称": "卡片_1/名称", "卡片1类型": "卡片_1/类型",
	"卡片1信息底": "卡片_1/信息底", "卡片1等级标签": "卡片_1/等级标签", "卡片1等级数值": "卡片_1/等级数值",
	"卡片1地图标签": "卡片_1/地图标签", "卡片1地图数值": "卡片_1/地图数值",
	"卡片1时间标签": "卡片_1/时间标签", "卡片1时间数值": "卡片_1/时间数值",
	"卡片1爆率标签": "卡片_1/爆率标签", "卡片1挑战钮": "卡片_1/挑战钮", "卡片1星级": "卡片_1/星级",
	"卡片1星0": "卡片_1/星级/星_0", 	"卡片1星1": "卡片_1/星级/星_1", 	"卡片1星2": "卡片_1/星级/星_2",
	"卡片1星3": "卡片_1/星级/星_3", 	"卡片1星4": "卡片_1/星级/星_4", 	"卡片1星5": "卡片_1/星级/星_5",
	"卡片1星6": "卡片_1/星级/星_6",
	"卡片2底": "卡片_2/卡片底", "卡片2头像底": "卡片_2/头像底", "卡片2头像": "卡片_2/头像底/头像",
	"卡片2序号": "卡片_2/序号", "卡片2名称": "卡片_2/名称", "卡片2类型": "卡片_2/类型",
	"卡片2信息底": "卡片_2/信息底", "卡片2等级标签": "卡片_2/等级标签", "卡片2等级数值": "卡片_2/等级数值",
	"卡片2地图标签": "卡片_2/地图标签", "卡片2地图数值": "卡片_2/地图数值",
	"卡片2时间标签": "卡片_2/时间标签", "卡片2时间数值": "卡片_2/时间数值",
	"卡片2爆率标签": "卡片_2/爆率标签", "卡片2挑战钮": "卡片_2/挑战钮", "卡片2星级": "卡片_2/星级",
	"卡片2星0": "卡片_2/星级/星_0", 	"卡片2星1": "卡片_2/星级/星_1", 	"卡片2星2": "卡片_2/星级/星_2",
	"卡片2星3": "卡片_2/星级/星_3", 	"卡片2星4": "卡片_2/星级/星_4", 	"卡片2星5": "卡片_2/星级/星_5",
	"卡片2星6": "卡片_2/星级/星_6",
	"分页": "分页", "首页": "分页/首页", "上一页": "分页/上一页", "页码": "分页/页码",
	"下一页": "分页/下一页", "末页": "分页/末页",
}

## 页面局部 = AS3 窗口局部 − (0,29)。每条注释是算式与出处行（`WangBossCell.as` 的坐标是**卡局部**，
## 卡原点：卡片_0 (11,15) / 卡片_1 (195,15) / 卡片_2 (379,15)，步距 184 = 183 宽 + 1）。
const 件期望 := {
	"外框黄底": [6, 10, 561, 260],				# Window:90-95 x=6 y=39 w=573−12 h=324−39−25
	"卡片0": [11, 15, 183, 250],					# Window:96-99 x=11 y=39+5
	"卡片1": [195, 15, 183, 250],				# Window:100-103 x=11+183+1
	"卡片2": [379, 15, 183, 250],				# Window:104-107 x=195+183+1
	"卡片0底": [11, 15, 183, 250],				# Cell:141-144 MPane_background 卡局部 (0,0) 183×250
	"卡片0头像底": [15, 19, 175, 118],			# Cell:145-149 PetPic_background x=y=4 w=183−8 h=118
	"卡片0头像": [15, 19, 173, 116],				# Cell:95-96 getWangBossPic(0) 原生 173×116 挂 potraitBg(0,0)
	"卡片0序号": [20, 24, 165, 18],				# Cell:152-163 w=175−10 h=18 x=4+5 y=4+5 **恒空串**(:98)
	"卡片0名称": [20, 140, 165, 18],				# Cell:164-170 橙 x=9 y=4+118+3=125
	"卡片0类型": [160, 140, 30, 18],				# Cell:171-177 橙 w=30 x=4+175−30=149 y=125
	"卡片0信息底": [15, 161, 175, 99],			# Cell:178-183 MPane_background x=4 y=125+18+3=146 h=99
	"卡片0等级标签": [25, 166, 60, 18],			# Cell:184-191 #FCC399 x=4+10 y=146+5=151
	"卡片0等级数值": [83, 166, 70, 18],			# Cell:192-198 白 x=14+60−2=72 y=151
	"卡片0地图标签": [25, 187, 60, 18],			# Cell:199-206 x=14 y=151+21=172
	"卡片0地图数值": [83, 187, 70, 18],			# Cell:209-216 绿+下划线 x=72 y=172
	"卡片0时间标签": [25, 208, 60, 18],			# Cell:217-224 x=14 y=172+21=193
	"卡片0时间数值": [83, 208, 70, 18],			# Cell:225-231 白 x=72 y=193
	"卡片0爆率标签": [25, 229, 60, 18],			# Cell:232-239 x=14 y=193+21=214
	"卡片0挑战钮": [160, 185, 22, 22],			# Cell:240-244 MWangBossKillBtnF x=14+135=149 y=172−2=170
	"卡片0星级": [83, 233, 42, 13],				# Cell:320-321 x=levelText.x=72 y=214+4=218 高写死 13
	# 星位每卡烘满 7 枚（原版最多 6 实 + 1 空），用不到的靠 visible=false；
	# 控制器只翻 visible / 换实空皮，不新建节点 ⇒ 编辑器看到的就是跑起来的。
	# Cell:301-307 StarLevelIconF / StarHollowF 原生 14×13，步距 = width = 14。
	# 首页数据：卡0 = 2 实 + 1 空；卡1 = 3 实；卡2 = 3 实 + 1 空。
	"卡片0星0": [83, 233, 14, 13], 	"卡片0星1": [97, 233, 14, 13], 	"卡片0星2": [111, 233, 14, 13],
	"卡片0星3": [125, 233, 14, 13], 	"卡片0星4": [139, 233, 14, 13], 	"卡片0星5": [153, 233, 14, 13],
	"卡片0星6": [167, 233, 14, 13],
	"卡片1底": [195, 15, 183, 250], "卡片1头像底": [199, 19, 175, 118], "卡片1头像": [199, 19, 173, 116],
	"卡片1序号": [204, 24, 165, 18], "卡片1名称": [204, 140, 165, 18], "卡片1类型": [344, 140, 30, 18],
	"卡片1信息底": [199, 161, 175, 99], "卡片1等级标签": [209, 166, 60, 18], "卡片1等级数值": [267, 166, 70, 18],
	"卡片1地图标签": [209, 187, 60, 18], "卡片1地图数值": [267, 187, 70, 18],
	"卡片1时间标签": [209, 208, 60, 18], "卡片1时间数值": [267, 208, 70, 18],
	"卡片1爆率标签": [209, 229, 60, 18], "卡片1挑战钮": [344, 185, 22, 22], "卡片1星级": [267, 233, 42, 13],
	"卡片1星0": [267, 233, 14, 13], 	"卡片1星1": [281, 233, 14, 13], 	"卡片1星2": [295, 233, 14, 13],
	"卡片1星3": [309, 233, 14, 13], 	"卡片1星4": [323, 233, 14, 13], 	"卡片1星5": [337, 233, 14, 13],
	"卡片1星6": [351, 233, 14, 13],
	"卡片2底": [379, 15, 183, 250], "卡片2头像底": [383, 19, 175, 118], "卡片2头像": [383, 19, 173, 116],
	"卡片2序号": [388, 24, 165, 18], "卡片2名称": [388, 140, 165, 18], "卡片2类型": [528, 140, 30, 18],
	"卡片2信息底": [383, 161, 175, 99], "卡片2等级标签": [393, 166, 60, 18], "卡片2等级数值": [451, 166, 70, 18],
	"卡片2地图标签": [393, 187, 60, 18], "卡片2地图数值": [451, 187, 70, 18],
	"卡片2时间标签": [393, 208, 60, 18], "卡片2时间数值": [451, 208, 70, 18],
	"卡片2爆率标签": [393, 229, 60, 18], "卡片2挑战钮": [528, 185, 22, 22], "卡片2星级": [451, 233, 56, 13],
	"卡片2星0": [451, 233, 14, 13], 	"卡片2星1": [465, 233, 14, 13], 	"卡片2星2": [479, 233, 14, 13],
	"卡片2星3": [493, 233, 14, 13], 	"卡片2星4": [507, 233, 14, 13], 	"卡片2星5": [521, 233, 14, 13],
	"卡片2星6": [535, 233, 14, 13],
	"分页": [224, 270, 124, 20],					# Window:61-64 x=(573−124)>>1 y=39+260=299；宽见 PageComponent:78-90
	"首页": [224, 270, 18, 13],					# PageComponent:80 firstBtn.x=0（MPageFirstBtnF 18×13）
	"上一页": [244, 270, 15, 13],				# :80 preBtn.x = 18+2 = 20（MPagePreBtnF 15×13）
	"页码": [261, 270, 50, 16],					# :81 pageText.x = 20+15+2 = 37，50×16 白 bold 居中
	"下一页": [313, 270, 15, 13],				# :82 nextBtn.x = 37+50+2 = 89
	"末页": [330, 270, 18, 13],					# :83 lastBtn.x = 89+15+2 = 106；:89 width = 106+18 = 124
}

## 固定标签 → 语言表键（值由 `开发工具/出首领原文数据.py` 落到 `数据/界面/首领_文案.json`，
## 场景与这里共读那一份 ⇒ 「等　　级：」里那两个 U+3000 不会被编辑器吃掉）。
const 件文案 := {
	"卡片0等级标签": "WANG_BOSS_CELL_LEVEL", "卡片1等级标签": "WANG_BOSS_CELL_LEVEL",
	"卡片2等级标签": "WANG_BOSS_CELL_LEVEL",
	"卡片0地图标签": "WANG_BOSS_REFURBISH_MAP", "卡片1地图标签": "WANG_BOSS_REFURBISH_MAP",
	"卡片2地图标签": "WANG_BOSS_REFURBISH_MAP",
	"卡片0时间标签": "WANG_BOSS_REFURBISH_TIMER", "卡片1时间标签": "WANG_BOSS_REFURBISH_TIMER",
	"卡片2时间标签": "WANG_BOSS_REFURBISH_TIMER",
	"卡片0爆率标签": "WANG_BOSS_INSTRUCTION", "卡片1爆率标签": "WANG_BOSS_INSTRUCTION",
	"卡片2爆率标签": "WANG_BOSS_INSTRUCTION",
}

## 首页烘的三条 = 原版静态表 `BossWang.boss` 的前三条（`WangBossWindow.setBaseData:130-146`）。
## alive/nextTime 是服务端字段（`WangInfo.as:24-31`），本工程无对应协议 ⇒ 烘 `alive=true`
## 这一合法原态（真值表 §6.1）。
const 首页索引 := [0, 1, 2]
const 每页条数 := 3
const 星位 := 7							# 每卡烘满 7 枚星位（原版最多 6 实 + 1 空），用不到的 visible=false


func 页名() -> String:
	return "首领"


func 根节点名() -> String:
	return "原版首领窗口内容"


func 页签数() -> int:
	return 1


## 原版这一页**没有页签条**：`分页` 是 `PageComponent`（翻页钮 + 页码），不是 `TabButtonBar`。
## 两个都要关掉：`有页签()` 管切页，`页签宽按文字()` 管基类去 `分页` 里按页签量宽
## —— 不关的话它会拿 `首页` 当页签 0 量出 `[10,9,6,22]` 的假红。
func 有页签() -> bool:
	return false


func 页签宽按文字() -> bool:
	return false


func 内容容器名() -> String:
	return "无内容盒"


func 期望() -> Dictionary:
	return 件期望


func 路径() -> Dictionary:
	return 件路径


func 页面件表() -> Dictionary:
	var 全: Array[String] = ["外框黄底", "分页", "首页", "上一页", "页码", "下一页", "末页"]
	for k in 3:
		全 += ["卡片%d" % k, "卡片%d底" % k, "卡片%d头像底" % k, "卡片%d头像" % k, "卡片%d序号" % k,
			"卡片%d名称" % k, "卡片%d类型" % k, "卡片%d信息底" % k, "卡片%d等级标签" % k,
			"卡片%d等级数值" % k, "卡片%d地图标签" % k, "卡片%d地图数值" % k, "卡片%d时间标签" % k,
			"卡片%d时间数值" % k, "卡片%d爆率标签" % k, "卡片%d挑战钮" % k, "卡片%d星级" % k]
		for s in 星位:
			全.append("卡片%d星%d" % [k, s])
	return {0: 全}


func 页面文案表() -> Dictionary:
	return {0: 件文案.keys()}


func 文案表() -> Dictionary:
	var 表 := {}
	var 原 := 原文表()
	for 名 in 件文案:
		表[名] = String(原.get(件文案[名], ""))
	return 表


func 公共件() -> Array[String]:
	return ["外框黄底", "卡片0", "卡片1", "卡片2", "分页"]


## ── 数据侧推导（与生成器 `生成首领场景.py` 同一套公式，两边互为对照）──
func 原文表() -> Dictionary:
	var 文 := {}
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/首领_文案.json"))
	assert(typeof(包) == TYPE_DICTIONARY and 包.has("文案"), "首领_文案.json 读不到，先跑 开发工具/出首领原文数据.py")
	for 键 in (包["文案"] as Dictionary):
		文[键] = String((包["文案"] as Dictionary)[键]["值"])
	assert(String(文.get("WANG_BOSS_NOT_DIED", "")) == "未死亡", "首领_文案.json 内容不对")
	return 文


func 王表() -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/原版杂项.json"))
	return (包["BossWang"]["boss"] as Dictionary) if typeof(包) == TYPE_DICTIONARY else {}


## `dropStars` 的枚数（`WangBossCell.createStarContainer:293-316`）。
## 原版是**字符串** `"2.5"` ⇒ `split(".")` ⇒ 点号前 = 实心枚数、**只要还有小数段**再补 1 枚空心。
## 本工程 `数据/原版杂项.json` 把它导成了**数字**，且 Godot 的 JSON 一律解成 float
## （实测 `str(3)` 在 GDScript 里是 `"3.0"` ⇒ 照字面 split 会多算一枚空心星）。
## 所以这里按等价的数值口径：**实心 = floor(值)，小数 > 0 再补一枚空心** ——
## 对 11 条真实数据（2.5/3/3.5/4/4/4.5/5/5.5/6/6/6）两种口径逐条相同。
func 星段(卡: int) -> Array:
	var 值: float = float((王表().get(str(首页索引[卡]), {}) as Dictionary).get("dropStars", 0.0))
	var 实: int = int(floor(值))
	return [实, (1 if 值 - float(实) > 0.0 else 0)]


func 星数(卡: int) -> int:
	var 段 := 星段(卡)
	return int(段[0]) + int(段[1])


func 星是空(卡: int, 序: int) -> bool:
	var 段 := 星段(卡)
	return int(段[1]) > 0 and 序 == int(段[0])


func 卡值(卡: int, 字段: String) -> String:
	return 序值(首页索引[卡], 字段)


## 与 `卡值()` 同一套公式，只是按**全局序号**取（翻页后的验收要用第 4..11 条）。
func 序值(序: int, 字段: String) -> String:
	# 名称 = StringTool.getMobString(mobid)（:99）；类型 = levelDesc（:100）；
	# 等级 = CN.replaceString(WANG_BOSS_CELL_JI, 怪.info.level)（:101）；地图 = getMapString(mapid)（:102）
	# ⚠️ GameData 的 id 在 Godot JSON 里是 **float** ⇒ 必须先 int() 再 str()，否则查出来是
	#    "2100001.0"、表里根本没这个键（实测踩过：整列文本假报「期望 ""」）。
	var 行: Dictionary = 王表().get(str(序), {}) as Dictionary
	var 怪: Dictionary = {}
	var 怪包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/怪物.json"))
	if typeof(怪包) == TYPE_DICTIONARY:
		怪 = (怪包 as Dictionary).get(str(int(行.get("mobid", 0))), {})
	match 字段:
		"名称":
			return String(怪.get("name", ""))
		"类型":
			return String(行.get("levelDesc", ""))
		"等级":
			return String(原文表().get("WANG_BOSS_CELL_JI", "%1级")).replace(
				"%1", str(int(怪.get("level", 0))))
		"地图":
			var 图包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/地图名.json"))
			return String((图包 as Dictionary).get(str(int(行.get("mapid", 0))), "")) if typeof(图包) == TYPE_DICTIONARY else ""
		"时间":
			return String(原文表().get("WANG_BOSS_NOT_DIED", ""))
		"简介":
			return String(行.get("mobDesc", ""))
		"掉落":
			return String(行.get("dropDesc", ""))
	return ""


func 总页数() -> int:
	return int(ceil(float(王表().size()) / float(每页条数)))


func 额外校验(页: Control, _页号: int) -> void:
	var 原 := 原文表()
	# 一、翻页四钮：各自的 MPage*BtnF 原件，尺寸 18/15/15/18，且**四张互不共用**
	var 皮表 := {"首页": 18, "上一页": 15, "下一页": 15, "末页": 18}
	var 见 := {}
	for 名 in 皮表:
		var 钮 := 页.get_node_or_null(件路径[名]) as TextureButton
		var 纹: Texture2D = 钮.texture_normal if 钮 != null else null
		var 对: bool = 纹 != null and int(纹.get_size().x) == 皮表[名]
		有错 = 有错 or not 对
		_行("  %-12s 皮宽=%s（MPage*BtnF 原生 %d）%s" % [名,
			纹.get_size().x if 纹 != null else "<无皮>", 皮表[名], "√" if 对 else "!! 错"])
		if 纹 != null:
			if 见.has(纹.resource_path):
				_错("%s 与 %s 共用一张皮（原版是四张不同图）" % [名, 见[纹.resource_path]])
			见[纹.resource_path] = 名
	# 二、PageComponent 首页态：`setBtnEnabled:102-120` ⇒ 第 1 页禁 首/上、启 下/末
	var 态表 := {"首页": false, "上一页": false, "下一页": true, "末页": true}
	for 名 in 态表:
		var 钮2 := 页.get_node_or_null(件路径[名]) as BaseButton
		var 对2: bool = 钮2 != null and bool(钮2.disabled) == (not bool(态表[名]))
		有错 = 有错 or not 对2
		_行("  %-12s disabled=%s（第 1 页 %s）%s" % [名, 钮2.disabled if 钮2 else "<无>",
			"应禁" if not 态表[名] else "应可点", "√" if 对2 else "!! 错"])
	# 三、页码 = currentPage/totalPage（PageComponent:98），11 条 / 3 一页 = 4
	var 码 := 页.get_node_or_null(件路径["页码"]) as Label
	var 想码 := "1/%d" % 总页数()
	var 码对: bool = 码 != null and 码.text == 想码
	有错 = 有错 or not 码对
	_行("  %-12s %s（应为 %s，条数 %d ÷ 每页 %d）%s" % ["页码", 码.text if 码 else "<无>", 想码,
		王表().size(), 每页条数, "√" if 码对 else "!! 错"])
	# 四、三张卡的数据文本：逐条回查 GameData 表（**不是**抄第二份，见 卡值()）
	for 卡 in 3:
		for 字段 in ["名称", "类型", "等级", "地图", "时间"]:
			var 件 := 页.get_node_or_null(件路径["卡片%d%s" % [卡, {"名称": "名称", "类型": "类型",
				"等级": "等级数值", "地图": "地图数值", "时间": "时间数值"}[字段]]]) as Label
			var 想 := 卡值(卡, 字段)
			var 对3: bool = 件 != null and 件.text == 想
			有错 = 有错 or not 对3
			_行("  %-12s 「%s」（%s）%s" % ["卡片%d%s" % [卡, 字段], 件.text if 件 else "<无>",
				"怪物.json/地图名.json/BossWang" if 字段 != "时间" else "WANG_BOSS_NOT_DIED",
				"√" if 对3 else "!! 期望「%s」" % 想])
	# 五、星级：7 枚星位的可见性与实/空皮（`createStarContainer:299-318`）
	for 卡 in 3:
		var 容 := 页.get_node_or_null(件路径["卡片%d星级" % 卡]) as Control
		var 段 := 星段(卡)
		var 想n := int(段[0]) + int(段[1])
		var 宽对: bool = 容 != null and is_equal_approx(容.size.x, float(想n * 14))
		有错 = 有错 or not 宽对
		_行("  %-12s 宽=%s（%d 实 + %d 空 ⇒ %d 枚 × 14）%s" % ["卡片%d星级" % 卡,
			容.size.x if 容 != null else "<无>", 段[0], 段[1], 想n, "√" if 宽对 else "!! 错"])
		for s in 星位:
			var 星 := 页.get_node_or_null(件路径["卡片%d星%d" % [卡, s]]) as TextureRect
			var 该见: bool = s < 想n
			var 期: String = ("半星.png" if 星是空(卡, s) else "星级.png") if 该见 else "（隐藏）"
			var 实: String = (星.texture.resource_path.get_file() if 星 != null and 星.texture != null else "<无>") if 该见 else "-"
			var 对5: bool = 星 != null and 星.visible == 该见 and (not 该见 or 实 == 期)
			有错 = 有错 or not 对5
			if 该见 or 星 == null or 星.visible:
				_行("  %-12s visible=%s %s（应 %s）%s" % ["卡片%d星%d" % [卡, s],
					星.visible if 星 != null else "<无>", 实, 期, "√" if 对5 else "!! 错"])
	# 六、序号恒空（`WangBossCell:98` 每次 setData 都写 ""）+ 头像皮 = Effect_Wang_<index>
	for 卡 in 3:
		var 序 := 页.get_node_or_null(件路径["卡片%d序号" % 卡]) as Label
		var 对6: bool = 序 != null and 序.text == ""
		有错 = 有错 or not 对6
		_行("  %-12s text=「%s」（原版恒空）%s" % ["卡片%d序号" % 卡, 序.text if 序 else "<无>",
			"√" if 对6 else "!! 错"])
		var 像 := 页.get_node_or_null(件路径["卡片%d头像" % 卡]) as TextureRect
		var 想像 := "Effect_Wang_%d.png" % 首页索引[卡]
		var 实像: String = 像.texture.resource_path.get_file() if 像 != null and 像.texture != null else "<无>"
		var 对7: bool = 实像 == 想像
		有错 = 有错 or not 对7
		_行("  %-12s %s（应 %s）%s" % ["卡片%d头像" % 卡, 实像, 想像, "√" if 对7 else "!! 错"])
	# 七、挑战钮：`removeData` 里 hidden、`setData` 里 visible=true ⇒ 有数据的三张必可见
	for 卡 in 3:
		var 钮3 := 页.get_node_or_null(件路径["卡片%d挑战钮" % 卡]) as CanvasItem
		var 对8: bool = 钮3 != null and 钮3.visible
		有错 = 有错 or not 对8
		_行("  %-12s visible=%s（setData:93 置 true）%s" % ["卡片%d挑战钮" % 卡,
			钮3.visible if 钮3 else "<无>", "√" if 对8 else "!! 错"])
	_行("  %-12s 标签四字 = 语言表逐字（含 U+3000 全角空格）见「文案 vs 语言表原文」段" % "固定标签")
	_行("  %-12s 提示 = %s / %s（tooltip_text，非窗口件）" % ["tooltip",
		"头像 = WANG_BOSS_TIP(简介/掉落)", "地图数值·挑战钮 = WANG_BOSS_KILL「%s」" % String(原.get("WANG_BOSS_KILL", ""))])


# ══════════════════ 运行期交互（真事件 + 隔帧，这一段决定"门不是摆设"）══════════════════
## ⚠ 三条硬口径（都在别页真踩过）：
##   1. 一律 `root.push_input` 送真事件，**送事件与验收拆成两步**（hover 归属在帧末
##      `Viewport.update_gui()` 才重算 ⇒ 同帧断言必假红）；
##   2. 每个 `_步验*` 自己盖"跑过"的戳，收尾缺戳判红 ⇒ 防"协程忘了 await 就 quit(0)"那种假绿；
##   3. **不点**「挑战钮 / 地图数值」：原版那两个的动作用是 `MovePlayerToMap`（跳图），
##      点了会把用户正在跑的角色传送走 ⇒ 改成断言"只连了一次、连的是哪个方法"。
const 空白落点 := Vector2(6, 250)
var _跑完: Dictionary = {}


func _戳(名: String) -> void:
	_跑完[名] = true


func _步点(名: String) -> void:
	var 件 := _件("分页/" + 名) as Control
	if 件 == null:
		_错("取不到 分页/%s" % 名)
		return
	var 心 := _中心(件)
	var 按 := InputEventMouseButton.new()
	按.position = 心
	按.global_position = 心
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.position = 心
	放.global_position = 心
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	root.push_input(放)
	等待 = 4


func _件(路: String) -> Node:
	return 页根().get_node_or_null(路)


func _中心(件: Control) -> Vector2:
	var 盒 := 件.get_global_rect()
	return 盒.position + 盒.size / 2.0


func _送移动(点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


## 分两跳进中心：大距离一步瞬移时同一帧只按最后一条 motion 做拾取，会不发 mouse_entered。
func _悬到(件: Control) -> void:
	var 心 := _中心(件)
	var 远 := 页根().get_global_position() + 空白落点
	_送移动((心 + 远) / 2.0)
	等待 = 2
	_送移动(心)
	等待 = 3


func _判(名: String, 对: bool, 文本: String) -> void:
	_戳(名)
	有错 = 有错 or not 对
	_行("  %-14s %s %s" % [名, 文本, "√" if 对 else "!! 错"])


## 第 1 页的禁用档：`disabled` + `texture_disabled` = **烘好的灰皮**（`getGrayFilter`）。
## ⚠ 不挂 material（会被子节点继承，也不是工程既有那条路 —— skill
##   `flash-mbutton3-state-skins` 两条「不许用」）；也不许"指回同一张皮"：那样 Godot 禁用时
##   会乘主题 `IconDisabledModulate`(0.55, α0.85)，比原版暗一截（实测末行半透阴影差 17~25）。
func _皮名(钮: TextureButton) -> String:
	return 钮.texture_normal.resource_path.get_file() if 钮 != null and 钮.texture_normal != null else "<无皮>"


func _步验钮禁用() -> void:
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		# 四枚都要有灰档：哪一枚禁用是**运行期按页**定的（第 1 页 首/上、末页 下/末）
		var 钮 := _件("分页/" + 名) as TextureButton
		var 灰file := 钮.texture_disabled.resource_path.get_file() if 钮 != null and 钮.texture_disabled != null else "<无>"
		_判("灰皮当禁用档" + 名, 灰file == "分页%s_灰.png" % 名,
				"texture_disabled 想 分页%s_灰.png，实际 %s" % [名, 灰file])
	for 名 in ["首页", "上一页"]:
		var 钮2 := _件("分页/" + 名) as TextureButton
		_判("禁用态" + 名, 钮2 != null and 钮2.disabled and 钮2.material == null,
				"disabled=%s material=%s" % [str(钮2.disabled) if 钮2 else "<无>",
					"有" if 钮2 != null and 钮2.material != null else "无"])
	for 名 in ["下一页", "末页"]:
		var 钮2 := _件("分页/" + 名) as TextureButton
		_判("可点态" + 名, 钮2 != null and not 钮2.disabled and 钮2.material == null,
				"disabled=%s material=%s" % [str(钮2.disabled) if 钮2 else "<无>",
					"有" if 钮2 != null and 钮2.material != null else "无"])
		_判("常态皮是原件" + 名, _皮名(钮2) == "%s.png" % 名, "实际 %s" % _皮名(钮2))
		_判("手型光标" + 名, 钮2 != null and 钮2.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"cursor=%s（`MButton3.init:135` buttonMode/useHandCursor）"
						% (str(钮2.mouse_default_cursor_shape) if 钮2 else "<无>"))


## 按住 / 松开（`_步点` 是 press+release 一把梭，验不了中间那一档）
func _按住(件: Control) -> void:
	var 心 := _中心(件)
	var 按 := InputEventMouseButton.new()
	按.position = 心
	按.global_position = 心
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	root.push_input(按)


func _松开(件: Control) -> void:
	var 心 := _中心(件)
	var 放 := InputEventMouseButton.new()
	放.position = 心
	放.global_position = 心
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	root.push_input(放)


## `MButton3` 六步状态机（`StyleUtil.skinFilters` up 0 / over +30 / down −40；
## `mouseUpHandler:103-108` **松手回 STATE_UP**）。
## ⚠ 送事件与验收**必须是两个队列步**：hover 归属在帧末 `update_gui()` 才重算，
##   同一个函数里连着做完 = 读到的全是上一帧的态（意志页那条门就是这么假绿过一次的）。
## ⚠ 断言的是**实际生效的 `texture_normal` 文件名**，不是"我确实调过换皮函数"（后者等于没断言）。
var _三态钮 := "下一页"


func _步三态事(什么: String) -> void:
	match 什么:
		"悬":
			_三态钮 = "下一页"
			_悬到(_件("分页/下一页") as Control)
		"按":
			_按住(_件("分页/下一页") as Control)
			等待 = 3
		"松":
			_松开(_件("分页/下一页") as Control)
			等待 = 3
		"移":
			_送移动(页根().get_global_position() + 空白落点)
			等待 = 3
		"悬灰":
			_三态钮 = "首页"
			_悬到(_件("分页/首页") as Control)


func _步三态验(想文件: String, 戳: String) -> void:
	var 钮 := _件("分页/" + _三态钮) as TextureButton
	var 实 := _皮名(钮)
	var 对: bool = 实 == 想文件
	if 戳 == "禁用不吃悬停":
		对 = 对 and 钮 != null and 钮.disabled
	_判(戳, 对, "texture_normal=%s（想 %s）" % [实, 想文件])
	_拍翻页条(戳)


## 每一档拍一条翻页条（窗口坐标 (224,299) 124×20 = 场景 (224,270) + 拖动区 29）
## ⇒ `出首领对照图.py` 把它们拼成 `8x_翻页条三态.png`（常态｜悬停｜按下｜松手｜禁用），
##   目视就能看出"到底有没有反馈"。裁法与 `_步抓图` 同一套（先按主窗口全局原点裁整窗，
##   再裁子矩形）—— 直接拿全局坐标去裁视口图会整块错位。
func _拍翻页条(戳: String) -> void:
	var 图像 := root.get_texture().get_image()
	var 主 := 主窗()
	if 图像 == null or 主 == null:
		return
	var 起点 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
	var 尺 := Vector2i(int(主.size.x), int(主.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起点.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起点.y)
	var 整窗 := 图像.get_region(Rect2i(起点, 尺))
	var 区 := Rect2i(224, 299, 124, 20)
	区.position.x = clampi(区.position.x, 0, 整窗.get_width() - 1)
	区.position.y = clampi(区.position.y, 0, 整窗.get_height() - 1)
	区.size.x = mini(区.size.x, 整窗.get_width() - 区.position.x)
	区.size.y = mini(区.size.y, 整窗.get_height() - 区.position.y)
	整窗.get_region(区).save_png("%s/钮态_%s.png" % [出目录, 戳])





func _步验第2页() -> void:
	var 码 := _件("分页/页码") as Label
	_判("页码2", 码 != null and 码.text == "2/%d" % 总页数(), "text=%s（想 2/%d）" % [码.text if 码 else "<无>", 总页数()])
	var 名 := _件("卡片_0/名称") as Label
	_判("卡0换到第4条", 名 != null and 名.text == 序值(3, "名称"),
			"名称=%s（想 %s）" % [名.text if 名 else "<无>", 序值(3, "名称")])
	var 像 := _件("卡片_0/头像底/头像") as TextureRect
	_判("头像换包", 像 != null and 像.texture != null and 像.texture.resource_path.ends_with("Effect_Wang_3.png"),
			"=%s" % (像.texture.resource_path.get_file() if 像 != null and 像.texture != null else "<无>"))
	for 名2 in ["首页", "上一页", "下一页", "末页"]:
		var 钮 := _件("分页/" + 名2) as TextureButton
		_判("第2页钮" + 名2, 钮 != null and not 钮.disabled and 钮.material == null,
				"第 2 页四枚全可点（既非首页也非末页）")


func _步验末页空态() -> void:
	var 码 := _件("分页/页码") as Label
	var 总 := 总页数()
	_判("页码末页", 码 != null and 码.text == "%d/%d" % [总, 总], "text=%s" % (码.text if 码 else "<无>"))
	_判("末页卡0", (_件("卡片_0/名称") as Label).text == 序值(9, "名称"),
			"名称=%s（想 %s）" % [(_件("卡片_0/名称") as Label).text, 序值(9, "名称")])
	_判("末页卡1", (_件("卡片_1/名称") as Label).text == 序值(10, "名称"),
			"名称=%s（想 %s）" % [(_件("卡片_1/名称") as Label).text, 序值(10, "名称")])
	# 11 条 ÷ 3 = 4 页 ⇒ 第 4 页只有两条 ⇒ **第三张卡停在 `removeData()` 后的空态**
	# （`WangBossWindow.requestData:116-128` 只喂切片命中的卡）。空态清的是**十个文本**，
	# 连「等　　级：」这四枚固定标签一起清（`Cell.removeData:247-258`），不是只清数值。
	var 空 := 0
	for 件名 in ["序号", "名称", "类型", "等级数值", "地图数值", "时间数值",
			"等级标签", "地图标签", "时间标签", "爆率标签"]:
		var 标 := _件("卡片_2/" + 件名) as Label
		if 标 != null and 标.text != "":
			空 += 1
	var 钮 := _件("卡片_2/挑战钮") as CanvasItem
	var 像 := _件("卡片_2/头像底/头像") as TextureRect
	var 隐星 := 0
	for 序 in 星位:
		var 星 := _件("卡片_2/星级/星_%d" % 序) as CanvasItem
		if 星 != null and not 星.visible:
			隐星 += 1
	_判("末页卡2空态", 空 == 0 and 钮 != null and not 钮.visible and 像 != null and 像.texture == null \
			and 隐星 == 星位,
			"非空文本 %d/10、挑战钮 visible=%s、头像=%s、隐星 %d/%d" % [空,
				str(钮.visible) if 钮 else "<无>",
				"有图" if 像 != null and 像.texture != null else "null", 隐星, 星位])
	for 名 in ["下一页", "末页"]:
		var 钮2 := _件("分页/" + 名) as TextureButton
		_判("末页钮%s灰" % 名, 钮2 != null and 钮2.disabled and 钮2.material == null 				and _皮名(钮2) == "%s.png" % 名,
				"末页 ⇒ 下/末 禁用（画 texture_disabled=灰皮、常态皮要装回去）；实际 %s" % _皮名(钮2))


func _步验回第1页() -> void:
	var 码 := _件("分页/页码") as Label
	_判("回首页", 码 != null and 码.text == "1/%d" % 总页数(), "text=%s" % (码.text if 码 else "<无>"))
	_判("回首页卡0", (_件("卡片_0/名称") as Label).text == 卡值(0, "名称"),
			"名称=%s" % (_件("卡片_0/名称") as Label).text)
	for 名 in ["首页", "上一页"]:
		var 钮 := _件("分页/" + 名) as TextureButton
		_判("复原" + 名, 钮 != null and 钮.disabled and 钮.material == null 				and _皮名(钮) == "%s.png" % 名,
				"翻回第 1 页 ⇒ 灰档要装回去、`texture_normal` 要落回常态；实际 %s" % _皮名(钮))


func _步悬头像() -> void:
	var 件 := _件("卡片_0/头像底") as Control
	if 件 == null:
		_错("取不到 卡片_0/头像底")
		return
	_悬到(件)


func _步验头像提示() -> void:
	var 框 := _件("文字提示_头像0") as Control
	var 文 := _件("文字提示_头像0/文字") as RichTextLabel
	var 简 := 序值(0, "简介")
	var 掉 := 序值(0, "掉落")
	_判("头像简介提示", 框 != null and 框.visible and 文 != null and 文.text.contains(简) \
			and 文.text.contains(掉),
			"visible=%s 含简介=%s 含掉落=%s" % [str(框.visible) if 框 else "<无>",
				str(简 in 文.text) if 文 != null else "<无>", str(掉 in 文.text) if 文 != null else "<无>"])


func _步悬地图() -> void:
	_悬到(_件("卡片_0/地图数值") as Control)


func _步验地图提示() -> void:
	var 框 := _件("文字提示_前往0") as Control
	var 文 := _件("文字提示_前往0/文字") as RichTextLabel
	var 想 := String(原文表().get("WANG_BOSS_KILL", "前往挑战"))
	_判("地图前往提示", 框 != null and 框.visible and 文 != null and 文.text.contains(想),
			"visible=%s 正文=%s（想含「%s」）" % [str(框.visible) if 框 else "<无>",
				文.text if 文 else "<无>", 想])


func _步移开() -> void:
	_送移动(页根().get_global_position() + 空白落点)
	等待 = 3


func _步验提示收() -> void:
	var a := _件("文字提示_头像0") as CanvasItem
	var b := _件("文字提示_前往0") as CanvasItem
	_判("移开收提示", a != null and b != null and not a.visible and not b.visible,
			"头像=%s 地图=%s" % [str(a.visible) if a else "<无>", str(b.visible) if b else "<无>"])


## 只验接线、不触发：原版点这两个 = `MovePlayerToMap(mapid)` + 停挂机，
## 在无头/有头门里真点会把用户的角色传送走 ⇒ 这里钉"连了几次、连的谁"。
## （`_首领活态` 是每次翻页都要跑的填卡逻辑，**在那里 connect 会越叠越多** ⇒ 这条就是它的哨兵。）
func _步验只连一次() -> void:
	var 坏 := ""
	for 卡 in 3:
		var 钮 := _件("卡片_%d/挑战钮" % 卡) as BaseButton
		var n: int = 钮.pressed.get_connections().size() if 钮 != null else -1
		if n != 1:
			坏 += " 卡片%d/挑战钮.pressed=%d" % [卡, n]
		var 图 := _件("卡片_%d/地图数值" % 卡) as Label
		var m: int = 图.gui_input.get_connections().size() if 图 != null else -1
		if m != 1:
			坏 += " 卡片%d/地图数值.gui_input=%d" % [卡, m]
	_判("跳图入口只连一次", 坏 == "", "连接数%s" % ("全部 = 1 √" if 坏 == "" else " 应各为 1：" + 坏))
	var 坏2 := ""
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		var 钮2 := _件("分页/" + 名) as BaseButton
		var n2: int = 钮2.pressed.get_connections().size() if 钮2 != null else -1
		if n2 != 1:
			坏2 += " %s=%d" % [名, n2]
	_判("翻页钮只连一次", 坏2 == "", "连接数%s" % ("全部 = 1 √" if 坏2 == "" else " 应各为 1：" + 坏2))


func _步收尾戳() -> void:
	var 该跑 := ["禁用态首页", "禁用态上一页", "灰皮当禁用档首页", "灰皮当禁用档上一页",
			"灰皮当禁用档下一页", "灰皮当禁用档末页",
			"可点态下一页", "可点态末页", "常态皮是原件下一页", "常态皮是原件末页",
			"手型光标下一页", "手型光标末页",
			"三态·常态", "三态·悬停", "三态·按下", "三态·松手回常态", "三态·移开",
			"三态·再悬停", "三态·收尾", "禁用不吃悬停", "页码2", "卡0换到第4条", "头像换包",
			"第2页钮首页", "第2页钮上一页", "第2页钮下一页", "第2页钮末页",
			"页码末页", "末页卡0", "末页卡1", "末页卡2空态", "末页钮下一页灰", "末页钮末页灰",
			"回首页", "回首页卡0", "复原首页", "复原上一页",
			"头像简介提示", "地图前往提示", "移开收提示", "跳图入口只连一次", "翻页钮只连一次"]
	var 缺: Array = []
	for 名 in 该跑:
		if not _跑完.has(名):
			缺.append(名)
	_判("段戳齐全", 缺.is_empty(), "跑了 %d/%d%s" % [len(_跑完), 该跑.size(),
			"" if 缺.is_empty() else " 缺：" + ", ".join(缺)])


func _队列尾() -> void:
	队列.append(_步验钮禁用)
	# —— `MButton3` 六步：常态 → 悬停 → 按下 → 松手(回 up) → 移开 → 再悬停 → 移开 → 禁用档 ——
	队列.append(_步三态验.bind("下一页.png", "三态·常态"))
	队列.append(_步三态事.bind("悬"))
	队列.append(_步三态验.bind("分页下一页_悬停.png", "三态·悬停"))
	队列.append(_步三态事.bind("按"))
	队列.append(_步三态验.bind("分页下一页_按下.png", "三态·按下"))
	队列.append(_步三态事.bind("松"))
	队列.append(_步三态验.bind("下一页.png", "三态·松手回常态"))
	队列.append(_步三态事.bind("移"))
	队列.append(_步三态验.bind("下一页.png", "三态·移开"))
	队列.append(_步三态事.bind("悬"))
	队列.append(_步三态验.bind("分页下一页_悬停.png", "三态·再悬停"))
	队列.append(_步三态事.bind("移"))
	队列.append(_步三态验.bind("下一页.png", "三态·收尾"))
	# ⚠ 上面那一串"按下→松手"**本身就是一次真点击** ⇒ 页已经翻到第 2 页。
	#   所以先点「首页」回到第 1 页（顺手把翻页也验了一遍），再验禁用档不吃悬停
	#   —— 不然第 2 页的「首页」是可点的，悬停变亮是对的，那条断言就成了假红。
	队列.append(_步点.bind("首页"))
	队列.append(_步验回第1页)
	队列.append(_步三态事.bind("悬灰"))
	队列.append(_步三态验.bind("首页.png", "禁用不吃悬停"))
	队列.append(_步三态事.bind("移"))
	队列.append(_步点.bind("下一页"))
	队列.append(_步验第2页)
	队列.append(_步点.bind("末页"))
	队列.append(_步验末页空态)
	队列.append(_步点.bind("首页"))
	队列.append(_步验回第1页)
	队列.append(_步悬头像)
	队列.append(_步验头像提示)
	队列.append(_步悬地图)
	队列.append(_步验地图提示)
	队列.append(_步移开)
	队列.append(_步验提示收)
	队列.append(_步验只连一次)
	队列.append(_步收尾戳)


func _行(文本: String) -> void:
	行.append(文本)
	print(文本)

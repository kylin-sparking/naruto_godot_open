extends SceneTree

## 「木叶村 NPC」离线回归门（2026-10-04）。
##
## 钉的是**这一整批 NPC 的菜单与落地**，不是某一扇窗：
##   * 菜单表由 `开发工具/出木叶村NPC表.py` 照服务端 `fake_flash_server.py:10924-10957 + 51342-51410`
##     导出 ⇒ 任何"从画面上数菜单"的改动都会在这里红。
##   * 原版没有「service → 窗口」表（全树 grep `service` 在 .as 里 0 命中），
##     菜单动作发回服务端、由**回帧**开窗 ⇒ 本工程的本地落地只许落到 `窗口尺寸.json` 已有的页，
##     没移植的**只许提示、不许自造窗**（判据 8 就是钉这条）。
##
## 口径与 纲手三页/宝石工艺/秘笈合成 同一条：**只读磁盘文本**，不 load 场景、不写 `user://玩家数据.json`；
## 每条判据都要能红。用法：Godot --headless --path . --script res://测试/木叶村NPC回归测试.gd

const 表路径 := "res://数据/界面/木叶村NPC.json"
const NPC路径 := "res://数据/NPC.json"
const 尺寸路径 := "res://数据/界面/窗口尺寸.json"
const 面板路径 := "res://脚本/界面/小地图面板.gd"
const 木叶村 := 100000000

var 红 := 0
var 日志: Array[String] = []
var 表: Dictionary = {}
var NPC: Dictionary = {}
var 尺寸: Dictionary = {}
var 面板 := ""


func _initialize() -> void:
	表 = 读JSON(表路径)
	NPC = 读JSON(NPC路径)
	尺寸 = 读JSON(尺寸路径)
	面板 = 读文(面板路径)
	验形状()
	验逐枚()
	验补行()
	验落地()
	验接线()
	for 一 in 日志:
		print(一)
	print("木叶村NPC回归：%s（红 %d 项）" % ["通过" if 红 == 0 else "不通过", 红])
	quit(1 if 红 > 0 else 0)


func 读文(路径: String) -> String:
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		记(false, "读不到 %s" % 路径)
		return ""
	return f.get_as_text()


func 读JSON(路径: String) -> Dictionary:
	var 解: Variant = JSON.parse_string(读文(路径))
	if typeof(解) != TYPE_DICTIONARY:
		记(false, "%s 不是字典（读不到/解不开）" % 路径)
		return {}
	return 解


func 记(过: bool, 文本: String) -> void:
	if not 过:
		红 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文本])


## ⚠ `JSON.parse_string` 在 Godot 4.7 把所有数字解成 float ⇒ 一律 `int()`（不 int 就比不过）。
func 枚() -> Array:
	return 表.get("npc", []) as Array


func 行们(条: Dictionary) -> Array:
	return 条.get("菜单", []) as Array


func 文字表(条: Dictionary) -> Array[String]:
	var 出: Array[String] = []
	for r in 行们(条):
		出.append(String((r as Dictionary)["文字"]))
	return 出


func 找(编号: String) -> Dictionary:
	for 条 in 枚():
		if String((条 as Dictionary)["id"]) == 编号:
			return 条
	return {}


## 4.7 没有 `Array.countv` ⇒ 自己数（少这一条就退回"只判最后一行"的弱判据）。
func 离开数(行: Array) -> int:
	var n := 0
	for r in 行:
		if int((r as Dictionary)["动作"]) == -1:
			n += 1
	return n


func 组装规() -> RegEx:
	# 只钉**形状**不钉数字：换一份服务端（2.2.3优化版 / nya-go / V2.6分发版 是三个不同文件），
	# 同一段代码的行号整段平移，钉数字会让门红在"出处"而不是"菜单内容"上。
	var r := RegEx.new()
	r.compile("^fake_flash_server\\.py:(\\d+)-(\\d+)（服务菜单→仓库→物品交易→卡片→离开）$")
	return r


func 验形状() -> void:
	记(int(表.get("地图", -1)) == 木叶村, "钉的是木叶村 %d（实 %s）" % [木叶村, str(表.get("地图"))])
	记(枚().size() == 25, "木叶村 25 枚 NPC（实 %d）" % 枚().size())
	var 总 := 0
	for 条 in 枚():
		总 += 行们(条).size()
	记(总 == 51, "菜单合计 51 行（实 %d）" % 总)
	# 出处这条**以前钉死了 `52313` 这个行号** ⇒ 2026-10-04 夜把数据源从 `nya-go` 换到
	# 「2.2.3优化版 自带的服务端」（用户令：按 2.2.3优化版、不要按分发版）时，
	# 门红在"出处"上而不是红在"菜单内容"上 —— 那是门自己在报错位置。
	# 换成两条真不变量：① 出处**形状**对（文件名 + 起-止 + 那五个字）；② 导出器读的确实是 2.2.3 那份。
	var 规 := String(表.get("组装规则", ""))
	var 匹 := 组装规().search(规)
	记(匹 != null and 匹.get_string(1).to_int() > 0 and 匹.get_string(1).to_int() < 匹.get_string(2).to_int(),
		"表里留了服务端组装规则的出处，形状对（实：%s；要 `fake_flash_server.py:<起>-<止>（服务菜单→…）`）" % 规)
	var 导 := FileAccess.get_file_as_string("res://开发工具/出木叶村NPC表.py")
	# 公开仓库不写死某台机器的路径：导出器按 NARUTO_GAME_ROOT / 工程旁的 2.2.3 找服务端，
	# 且读的必须是 2.2.3 自带的那份 fake_flash_server.py（不是分发版）。
	记(导.contains("NARUTO_GAME_ROOT") and 导.contains("\"2.2.3\"") and 导.contains("fake_flash_server.py"),
		"导出器按 NARUTO_GAME_ROOT / 工程旁的 2.2.3 找服务端（不写死分发版路径）")
	# 「离开」是服务端最后补的一行（出处段末），每枚都必须有且只有一行、且排最后
	var 缺 := []
	for 条 in 枚():
		var 行: Array = 行们(条)
		if 行.is_empty() or int((行[行.size() - 1] as Dictionary)["动作"]) != -1:
			缺.append(String((条 as Dictionary)["id"]))
		elif 离开数(行) != 1:
			缺.append(String((条 as Dictionary)["id"]) + " 有多个离开")
	记(缺.is_empty(), "每枚末尾恰好一行「离开&-1」（违规：%s）" % str(缺))
	# 同一枚里除「离开」外动作值不许重复（重复 = 点了会开两次/落地互相顶）
	var 撞 := []
	for 条 in 枚():
		var 见: Array[int] = []
		for r in 行们(条):
			var 码 := int((r as Dictionary)["动作"])
			if 码 == -1:
				continue
			if 见.has(码):
				撞.append(String((条 as Dictionary)["id"]))
			见.append(码)
	记(撞.is_empty(), "同一枚 NPC 的动作值不重复（违规：%s）" % str(撞))


func 验逐枚() -> void:
	# 名字/称号/台词逐字回 数据/NPC.json —— 表是派生物，源改了表没重导就是漂移
	var 歪 := []
	for 条 in 枚():
		var 编号 := String((条 as Dictionary)["id"])
		var n: Dictionary = NPC.get(编号, {})
		if n.is_empty():
			歪.append(编号 + " NPC.json 没有")
			continue
		for 字段 in ["name", "title", "dialogue", "service"]:
			var 键: String = ""
			if 字段 == "name":
				键 = "名"
			elif 字段 == "title":
				键 = "称号"
			elif 字段 == "dialogue":
				键 = "台词"
			else:
				键 = "service"
			if String((条 as Dictionary)[键]) != String(n[字段]):
				歪.append("%s.%s" % [编号, 键])
		if int((条 as Dictionary)["模板"]) != 编号.to_int():
			歪.append(编号 + " 模板≠编号")
	记(歪.is_empty(), "25 枚的 名/称号/台词/service 与 NPC.json 逐字一致（歪：%s）" % str(歪))
	# 服务端 NPC_SERVICE_MENUS 的木叶村 13 枚（:10890-10922），逐枚钉死第一行是什么
	var 钉 := {
		"00000011": "变身卡与道具兑换", "00000012": "跨服忍界大战", "00000013": "打开仓库",
		"00000017": "中忍考试", "00000018": "挑战副本", "00000019": "勾玉炼制",
		"00000020": "生命料理", "00000021": "亲热天堂", "00000022": "重置潜能点",
		"00000028": "百炼忍传", "00000030": "神器战场", "00000032": "徽章打造",
		"00000059": "灵器介绍",
	}
	var 错 := []
	for 编号 in 钉:
		var 条 := 找(编号)
		if 条.is_empty() or 文字表(条).is_empty() or 文字表(条)[0] != 钉[编号]:
			错.append("%s 期望首行「%s」实 %s" % [编号, 钉[编号], "缺" if 条.is_empty() else str(文字表(条))])
	记(错.is_empty(), "13 枚的服务菜单首行逐字钉住（错：%s）" % str(错))
	var 纲手 := 找("00000018")
	记(文字表(纲手) == ["挑战副本", "挑战精英副本", "离开"],
		"纲手三行与 10-03 已验收那张一致（实 %s）" % str(文字表(纲手)))
	var 空 := []
	for 编号 in ["00000016", "00000023", "00000027", "00000033"]:
		if 文字表(找(编号)) != ["离开"]:
			空.append("%s → %s" % [编号, str(文字表(找(编号)))])
	记(空.is_empty(), "宁次/志乃/富岳/失落秋千 服务端只给「离开」，客户端不许自己加行（%s）" % str(空))

	# ── 富岳（模板 27）的**环任务行**：2026-10-05 取证，上一版把它记成"没有菜单行"是错的 ──
	# 出处：服务端 `_npc_quest_selections`（`fake_flash_server.py` 里 `template_id == 27` 那两支，
	# 编码 `文字&questId&状态&次数&上限&questId`）。它走的是 328 帧的**第 6 段 selection**，
	# 与 menu 段不是一种东西 ⇒ 表里单独存一个 `任务行` 键，**不许并进 `菜单`**
	# （并进去就会把上面那条「离开恒为唯一行」的判据变成假绿，也丢了"点行不发 57:2"这条约束）。
	var 富 := 找("00000027")
	var 任: Array = (富 as Dictionary).get("任务行", []) as Array
	var 任文: Array = []
	var 任号: Array = []
	for t in 任:
		任文.append(String((t as Dictionary)["文字"]))
		任号.append(int((t as Dictionary)["任务id"]))
	记(任文 == ["每日环任务", "周试炼任务"],
		"富岳两行环任务逐字（`fake_flash_server.py` 硬编码那两支）实 %s" % str(任文))
	记(任号 == [8001, 8002], "任务id = 8001 / 8002（⚠ 不是动作值，别拿它查 NpcMenuAction）实 %s" % str(任号))
	记(String((任[0] as Dictionary)["键"]) == "QUEST_DAILY"
			and String((任[1] as Dictionary)["键"]) == "QUEST_WEEKLY",
		"两行的键 = QUEST_DAILY / QUEST_WEEKLY")
	记(String((任[0] as Dictionary)["原版类"]) == "component/RefreshDailyQuestWindow"
			and String((任[1] as Dictionary)["原版类"]) == "component/DailyQuestWindow",
		"日环开 RefreshDailyQuestWindow、周环开 DailyQuestWindow（⚠ 类名叫 Daily 但走 weekly 那一支，分流 `QuestDataManager.as:284-288`）")
	记(String((任[0] as Dictionary)["尺寸"]) == "355×407"
			and String((任[1] as Dictionary)["尺寸"]) == "355×367",
		"两扇尺寸钉住（`super(355,407,true)` :75 / `super(355,367,true)` :49）")
	记(int((任[0] as Dictionary)["门槛"]) == 20 and int((任[1] as Dictionary)["门槛"]) == 35,
		"等级门槛 20 / 35（服务端那两支 if 的条件）")
	# 本地配置侧：任务.json 里这两条的 loopCount 必须等于服务端行里的"上限"（20 / 100）
	var 任表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/任务.json")) as Dictionary
	var 日: Dictionary = 任表.get("8001", {}) as Dictionary
	var 周: Dictionary = 任表.get("8002", {}) as Dictionary
	记(int((日.get("info", {}) as Dictionary).get("loopCount", 0)) == 20
			and int((周.get("info", {}) as Dictionary).get("loopCount", 0)) == 100,
		"任务.json 的 loopCount = 20 / 100，与服务端行里的上限一致（实 %s / %s）"
		% [str((日.get("info", {}) as Dictionary).get("loopCount")), str((周.get("info", {}) as Dictionary).get("loopCount"))])
	记(String((日.get("info", {}) as Dictionary).get("type", "")) == "daily"
			and String((周.get("info", {}) as Dictionary).get("type", "")) == "weekly",
		"type = daily / weekly ⇒ 决定原版开哪一扇（`QuestDataManager.as:278-288`）")
	# 2026-10-05：两扇都建完了 ⇒ 落地页**必须有值**，而且值必须是 `窗口尺寸.json` 的键
	#（上面那条"落地集 ⊆ 尺寸键"的不变量已经扫过 菜单 行，这里单独钉 任务行 那两页）。
	var 页日 := String((任[0] as Dictionary).get("落地页", ""))
	var 页周 := String((任[1] as Dictionary).get("落地页", ""))
	var 尺: Dictionary = 读JSON(尺寸路径)
	记(页日 == "日环任务" and 页周 == "周试炼任务"
			and 尺.has(页日) and 尺.has(页周)
			and int((尺[页日] as Dictionary).get("宽", 0)) == 355
			and int((尺[页日] as Dictionary).get("高", 0)) == 407
			and int((尺[页周] as Dictionary).get("宽", 0)) == 355
			and int((尺[页周] as Dictionary).get("高", 0)) == 367,
			"两扇已建 ⇒ 落地页 = 日环任务 / 周试炼任务，且尺寸表里就是 355×407 / 355×367（实 %s / %s）"
			% [页日, 页周])
	记(String((尺.get(页日, {}) as Dictionary).get("标题", "")) == "木叶警所环式任务"
			and String((尺.get(页周, {}) as Dictionary).get("标题", "")) == "木叶警所环式任务",
			"两扇**同标题**（:669 那一句 DAILY_QUSET_WINDOW_TITLE，别抄成两句话）")


func 验补行() -> void:
	# 三条补行规则（:52317-52328）：仓库模板 13 / 商人 14,15,24,25,26,31,58 / 卡片 29
	var 商 := ["00000014", "00000015", "00000024", "00000025", "00000026", "00000031", "00000058"]
	var 缺商 := []
	for 编号 in 商:
		if not 文字表(找(编号)).has("物品交易"):
			缺商.append(编号)
	记(缺商.is_empty(), "7 枚商人都有「物品交易」补行（缺：%s）" % str(缺商))
	记(文字表(找("00000013")).has("打开仓库"), "小樱有「打开仓库」（MERCHANT/STORAGE 补行模板 13）")
	记(文字表(找("00000029")).has("卡片套册收集"), "鹿丸有「卡片套册收集」（卡片模板 29，注意不是「卡片收集」）")
	var 多 := []
	for 条 in 枚():
		var 编号 := String((条 as Dictionary)["id"])
		if 编号 in 商 or 编号 == "00000013" or 编号 == "00000029":
			continue
		if 文字表(条).has("物品交易") or 文字表(条).has("打开仓库") or 文字表(条).has("卡片套册收集"):
			多.append(编号)
	记(多.is_empty(), "补行没扩散到别的 NPC（扩散：%s）" % str(多))


func 验落地() -> void:
	# 不变量：落地页要么空（未移植），要么是 窗口尺寸.json 的键 ⇒ 不许指向一扇不存在的窗
	var 悬 := []
	var 有 := 0
	for 条 in 枚():
		for r in 行们(条):
			var 页 := String((r as Dictionary).get("落地页", ""))
			if 页.is_empty():
				continue
			有 += 1
			if not 尺寸.has(页):
				悬.append("%s→%s" % [String((r as Dictionary)["文字"]), 页])
	记(悬.is_empty(), "落地页全部在 窗口尺寸.json 里存在（悬空：%s）" % str(悬))
	记(有 > 0, "已落地的行数 = %d（0 = 接线全断了）" % 有)
	# 10-03 已验收的两条不许退化
	记(String(找("00000018")["菜单"][0]["落地页"]) == "副本", "挑战副本 → 副本（CopyWindow 570×283）")
	记(String(找("00000018")["菜单"][1]["落地页"]) == "精英副本", "挑战精英副本 → 精英副本（500×426）")
	# 「查无定论」的两个不许被偷偷建成窗：状态里必须还写着 查无
	var 造 := []
	for 编号 in ["00000030", "00000059"]:
		for r in 行们(找(编号)):
			var 态 := String((r as Dictionary).get("状态", ""))
			if 态.begins_with("查无") and not String((r as Dictionary)["落地页"]).is_empty():
				造.append(String((r as Dictionary)["文字"]))
	记(造.is_empty(), "「神器战场 / 灵器介绍」原版开哪扇窗没有定论 ⇒ 不许自造（造了：%s）" % str(造))
	# ⚠ 上面那条 2026-10-06 起对 00000030 **已经不成立了**：佐助那一跳查到底了
	#   （状态改成「查到底(2026-10-06)：…」，不再以 查无 开头）⇒ `begins_with("查无")`
	#   对它是**永假**、这条门对他等于没判。所以佐助单独钉三件事，一条都不许空转：
	var 佐 := {}
	for r in 行们(找("00000030")):
		if int((r as Dictionary).get("动作", -1)) == 19:
			佐 = r as Dictionary
	记(not 佐.is_empty(), "佐助 00000030 菜单里找得到动作 19（ARTIFACT_WAR）那一行")
	记(String(佐.get("落地页", "")) == "",
			"19 那一行**落地页必须是空**（原版 `_enter_artifact_warfield:52141` 只传送 + 发倒计时，"
			+ "不发 SHOW_NPC_PANEL、panelId switch 也没一枚对应）⇒ 实「%s」" % String(佐.get("落地页", "")))
	记(String(佐.get("状态", "")).contains("没有页面可移植"),
			"19 的状态必须写着「没有页面可移植」这个结论（不许被改回 待建 ⇒ 那样点击会回显"
			+ "「还没移植」这句**假话**）⇒ 实「%s…」" % String(佐.get("状态", "").substr(0, 24)))
	# 点击回显走的是 `小地图面板._开NPC菜单页` 的**非待建分支**（原样念状态），
	# 而 "还没移植" 只允许出现在 `待建` 那一支后面 ⇒ 文本上钉住顺序，别让它退化成假话。
	var 开页段 := 面板.substr(面板.find("func _开NPC菜单页"))
	记(开页段.length() > 0 and 开页段.find("还没移植") > 开页段.find('begins_with("待建")'),
			"「还没移植」只在 `待建` 那一支里出（19 走 else ⇒ 回显真结论）；实 待建 %d / 还没移植 %d"
			% [开页段.find('begins_with("待建")'), 开页段.find("还没移植")])
	# 鸣人 00000012：动作值 18（WAR）⇒ 跨服频道（KuaFuChannelWindow 595×451，2026-10-06 建）
	记(String(找("00000012")["菜单"][0]["落地页"]) == "跨服频道",
			"漩涡鸣人「跨服忍界大战」→ 跨服频道（尺寸表 595×451 = `newView:65` 的 setSize，不是 :39 的 414）")
	记(尺寸.has("跨服频道") and int(尺寸["跨服频道"]["宽"]) == 595 and int(尺寸["跨服频道"]["高"]) == 451,
			"跨服频道 在尺寸表里是 595×451（实 %s×%s）"
			% [str((尺寸.get("跨服频道", {}) as Dictionary).get("宽")), str((尺寸.get("跨服频道", {}) as Dictionary).get("高"))])


func 验接线() -> void:
	记(面板.contains('const NPC表路径 := "res://数据/界面/木叶村NPC.json"'), "小地图面板 读的是这张表")
	记(面板.contains("static func _读NPC表()"), "有表加载器")
	记(面板.contains("func NPC菜单行(npc_id: String)"), "对外给了 NPC菜单行()")
	记(面板.contains("_落地[码]"), "落地表由表里现算（不是硬编码页名字典）")
	var 用表 := 面板.find("菜单 = NPC菜单行(npc_id)")
	var 旧兜底 := 面板.find('菜单 = [["打开任务"')
	记(用表 > 0 and 旧兜底 > 0 and 用表 < 旧兜底,
		"取表在旧兜底**之前**（在线/离线同一张菜单；实 表 %d / 旧 %d）" % [用表, 旧兜底])
	var 段 := 面板.substr(面板.find("func _开NPC菜单页"))
	记(段.length() > 0 and not (段.contains(".tscn") or 段.contains("load(") or 段.contains("instantiate")),
		"未移植的动作只发提示，绝不 load 任何场景（防自造窗）")
	记(段.contains("show_notification"), "未移植那条走通知条（玩家看得见缺什么）")
	# 全工程只许有一张对话窗（25 枚 NPC 共用，不是每枚复制一张）
	var 目录 := DirAccess.open("res://场景/界面/窗口")
	var 找到的: Array[String] = []
	if 目录 != null:
		扫窗(目录, "res://场景/界面/窗口", 找到的)
	记(找到的.size() == 1, "全工程只有一张 NPC 对话窗 .tscn（实 %d：%s）" % [找到的.size(), str(找到的)])


func 扫窗(目录: DirAccess, 前缀: String, 出: Array[String]) -> void:
	目录.list_dir_begin()
	var 名 := 目录.get_next()
	while 名 != "":
		var 全 := 前缀 + "/" + 名
		if 目录.current_is_dir():
			if not 名.begins_with("."):
				var 子 := DirAccess.open(全)
				if 子 != null:
					扫窗(子, 全, 出)
		elif 名.contains("对话") and 名.ends_with(".tscn"):
			出.append(全)
		名 = 目录.get_next()
	目录.list_dir_end()

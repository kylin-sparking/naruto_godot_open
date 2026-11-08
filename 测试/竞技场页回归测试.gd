extends SceneTree
## 竞技场（主窗 + 英雄榜 + 对手帧 + 对战表现）**离线门**。
##
## 覆盖：① `2306` 十二档下行的**包形解析**（夹具是服务端原文串形状，不是手写猜）
##        ② 两扇场景的**逐件矩形**（读 `.tscn` 文本，参照值手抄 `真值/窗口/竞技场.md` §⑪/§⑮）
##        ③ 战报那套 `reportsList` 合并（按 timeStamp 去重覆盖 → 降序 → 截 5）与 `getZhanBao` 文案
##        ④ `238:arena-player` 那 26 段 ⇒ 认出对手、`对手` 字段逐项对上；**普通怪那一支不受影响**（阳性对照）
##        ⑤ 怪物动作词 → 角色动作词那层对照（`move/attack1/hit1/die1` ⇒ `walk/attack/hit/dead`），
##          并钉住"真怪物六个名字本来就有 ⇒ 别名一条都不该动它"
##        ⑥ `isPking` 那一步是**换图**翻、不是收帧翻；`2306:5` 只存数
##        ⑦ 尺寸表两条：`整框: true` 且**不许有 `原点` 键**（两道错会互相抵消，见 §体检门那条口径）
##        ⑧ 「第 N 格发第 N 行那个号」的映射 + 中文 `set_meta` 键这一族的复发闸（10-24 事故）
##        ⑨ 两扇 TextureRect 的**屏幕盒** == `.tscn` 声明盒、且非天然尺寸那几枚走整帧拉伸
##          （② 只读声明值 ⇒ 照不到 `expand_mode` 把盒顶大这一类；10-24 靠 窗口布局体检 才发现）
##
## 不覆盖（各归各处，别在这里假称判过）：
##   · 上行七条的**真实投递**与"点它有反应" ⇒ `开发工具/跑在线用例.ps1` 那一族（离线 `send_game_request` 直接 false）
##   · 需要视口图像/真点击的四份**有头**量具：`验竞技场开窗 / 验竞技场对手 / 验竞技场对战 / 验竞技场英雄榜`
##   · 逐像素四件套（本任务未列，见台账）
##
## 跑法：`Godot --headless --path . --script res://测试/竞技场页回归测试.gd`
## ⚠ 本门**只读不写**：不碰 `user://`、不走 `窗口管理.打开`；⑨ 那一段只把两扇 `instantiate()`
##   挂到 `root` 下等两帧量盒，量完当场 `free()`（不弹遮罩、不建会话）。

const 后端脚本 := preload("res://脚本/单例/后端连接.gd")
const 竞技场窗 := preload("res://脚本/界面/窗口/竞技场窗.gd")
const 主窗场景 := "res://场景/界面/窗口/竞技场/竞技场窗.tscn"
const 榜场景 := "res://场景/界面/窗口/竞技场/竞技场英雄榜.tscn"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 竞技场图 := 503000000

## 候选一行 12 段（`_arena_candidate_row:29193`）：角色号 排名 头像 等级 名字 在对战 攻 防 暴击 闪避 攻速 移速
const 候选行 := [
	"301&7&10000204&55&甲一&0&900&800&12&9&7&175",
	"302&8&10000205&54&甲二&1&880&810&11&8&7&175",
	"303&6&10000204&56&甲三&0&920&790&13&10&6&175"]
## 战报一行 8 段（`_arena_report_row:29225`）：挑战者 胜者号 胜者名 败者号 败者名 时间戳 用时 结果排名
const 战报甲 := "301&301&甲一&9001&乙一&111&60&7"
const 战报乙 := "9001&9001&乙一&302&甲二&222&120&6"
## 对手帧 26 段（`_arena_player_monster_spawn_payload:29490-29533` 逐段数过）
const 对手号 := 1500301301
const 对手帧 := "238:arena-player:%d:1:0:%d:1450:862:0:7:7:0:true:1:1450:862:" % [对手号, 竞技场图] \
		+ "10000204:55:乙一:7:175:101&3@102&5:2&30000101@3&30000102:9:8:111@222"
## 阳性对照：一条**普通怪**帧（模板号 1000001 在 mob 表里真有 `move`）
const 怪帧 := "238:1:700001:0:1000001:%d:1200:800:0:0:0:0:true:0:1200:800:0:0:-:-" % 竞技场图

var _判: Array = []
var _收: Array = []


func _过程(名: String, 过: bool) -> void:
	_判.append([名, 过])


func _初始化(后: Node) -> void:
	后.connect("竞技场帧", func(动作: int, 值: Dictionary) -> void: _收.append([动作, 值]))


func _喂帧(后: Node, 串: String) -> void:
	后.call("_handle_arena_text", PackedStringArray(串.split(":")))


func _最后一帧(动作: int) -> Dictionary:
	for i in range(_收.size() - 1, -1, -1):
		if int(_收[i][0]) == 动作:
			return _收[i][1] as Dictionary
	return {}


## 读 `.tscn` 文本 ⇒ `{节点全路径: {x,y,右,下}}`。
## ★ 键用**全路径**不是裸名：主窗里 `头像框`/`名字` 各有 5 枚，按裸名收会互相顶掉、
##   最后一枚赢 ⇒ 拿第 5 格的矩形去判第 2 格（假绿/假红都可能）。
func _取(路: String) -> Dictionary:
	var 文 := FileAccess.get_file_as_string(路)
	var 出: Dictionary = {}
	var 前 := ""
	for 行 in 文.split("\n"):
		var 串 := String(行).trim_suffix("\r")
		if 串.begins_with("[node "):
			var 名 := 串.trim_prefix("[node name=\"").split("\"")[0]
			var 父 := ""
			var 段: PackedStringArray = 串.split('parent="')
			if 段.size() > 1:
				父 = String(段[1]).split("\"")[0]
			前 = 名 if (父 == "." or 父.is_empty()) else 父 + "/" + 名
		elif 串.begins_with("offset_left = "):
			取数(出, 前, "x", 串)
		elif 串.begins_with("offset_top = "):
			取数(出, 前, "y", 串)
		elif 串.begins_with("offset_right = "):
			取数(出, 前, "右", 串)
		elif 串.begins_with("offset_bottom = "):
			取数(出, 前, "下", 串)
	return 出


func 取数(出: Dictionary, 名: String, 键: String, 行: String) -> void:
	if 名.is_empty():
		return
	var 一: Dictionary = 出.get(名, {})
	一[键] = float(行.trim_prefix("offset_left = ").trim_prefix("offset_top = ") \
			.trim_prefix("offset_right = ").trim_prefix("offset_bottom = "))
	出[名] = 一


func _矩(件: Dictionary, 名: String, 望: Array) -> bool:
	var v: Dictionary = 件.get(名, {})
	if v.is_empty():
		return false
	return is_equal_approx(float(v.get("x", 1e9)), 望[0]) and is_equal_approx(float(v.get("y", 1e9)), 望[1]) \
			and is_equal_approx(float(v.get("右", 1e9)) - float(v.get("x", 0.0)), 望[2]) \
			and is_equal_approx(float(v.get("下", 1e9)) - float(v.get("y", 0.0)), 望[3])


func _initialize() -> void:
	_判包形()
	_判几何()
	_判战报()
	_判对手帧()
	_判动作词()
	_判对战状态()
	_判尺寸表()
	_判格子取号()
	await _判贴图盒()
	var 红 := 0
	for 一 in _判:
		var 过: bool = bool(一[1])
		if not 过:
			红 += 1
		print("  %-4s  %s" % ["通过" if 过 else "红", 一[0]])
	print("竞技场离线门：判 %d 条，红 %d 条" % [_判.size(), 红])
	quit(0 if 红 == 0 else 1)


# ── ① 包形 ────────────────────────────────────────────────────────────────
func _判包形() -> void:
	var 后 = 后端脚本.new()
	_初始化(后)
	_喂帧(后, "2306:0:2:15:37:3:8000:12:" + "@".join(候选行) + ":" + "@".join([战报甲, 战报乙]))
	var 面 := _最后一帧(0)
	_过程("2306:0 计数五段（已用/上限/冷却/连胜/距明天）",
			int(面.get("已用", -1)) == 2 and int(面.get("上限", -1)) == 15
			and int(面.get("冷却", -1)) == 37 and int(面.get("连胜", -1)) == 3
			and int(面.get("距明天", -1)) == 8000)
	_过程("2306:0 排名 12", int(面.get("排名", -1)) == 12)
	var 候: Array = 面.get("候选", [])
	_过程("2306:0 候选 3 行、逐字段对上", 候.size() == 3
			and int((候[0] as Dictionary).get("charId", 0)) == 301
			and int((候[0] as Dictionary).get("pkLevel", 0)) == 7
			and int((候[0] as Dictionary).get("face", 0)) == 10000204
			and String((候[0] as Dictionary).get("name", "")) == "甲一"
			and int((候[0] as Dictionary).get("wlkspeed", 0)) == 175)
	_过程("2306:0 的 `inBattle` 是 **==1** 折出来的布尔（不是 int）",
			bool((候[1] as Dictionary).get("inBattle", false)) and not bool((候[0] as Dictionary).get("inBattle", true)))
	var 战: Array = 面.get("战报", [])
	_过程("2306:0 战报 2 行、八段对上", 战.size() == 2
			and int((战[0] as Dictionary).get("winnerId", 0)) == 301
			and String((战[1] as Dictionary).get("loserName", "")) == "甲二"
			and int((战[1] as Dictionary).get("resultPkLevel", 0)) == 6)
	_喂帧(后, "2306:1:9")
	_过程("2306:1 排名", int(_最后一帧(1).get("排名", -1)) == 9)
	_喂帧(后, "2306:2:" + "@".join(候选行))
	_过程("2306:2 只刷候选（3 行）", (int(_最后一帧(2).get("候选", []).size())) == 3)
	_喂帧(后, "2306:3:" + "@".join([战报甲, 战报乙]))
	_过程("2306:3 只刷战报（2 行）", (int(_最后一帧(3).get("战报", []).size())) == 2)
	_喂帧(后, "2306:4:5:15:66:1:7777")
	_过程("2306:4 计数五段独立一档", int(_最后一帧(4).get("冷却", -1)) == 66
			and int(_最后一帧(4).get("距明天", -1)) == 7777)
	_喂帧(后, "2306:5:900")
	_过程("2306:5 秒数", int(_最后一帧(5).get("秒", -1)) == 900)
	_喂帧(后, "2306:6:5")
	_过程("2306:6 秒数（与 5 同一键名、不同档）", int(_最后一帧(6).get("秒", -1)) == 5)
	_喂帧(后, "2306:7:1:50")
	_过程("2306:7 胜负 + 阅历", bool(_最后一帧(7).get("胜", false)) and int(_最后一帧(7).get("阅历", -1)) == 50)
	_喂帧(后, "2306:7:0:10")
	_过程("2306:7 负档 ⇒ 胜=false", not bool(_最后一帧(7).get("胜", true)))
	_喂帧(后, "2306:8:3:120")
	_过程("2306:8 排名 + 阅历", int(_最后一帧(8).get("排名", -1)) == 3 and int(_最后一帧(8).get("阅历", -1)) == 120)
	_喂帧(后, "2306:9:1&301&60&甲一&0@2&302&58&甲二&1@7&305&55&甲五&2")
	var 榜: Array = _最后一帧(9).get("英雄", [])
	_过程("2306:9 英雄榜 3 行五段", 榜.size() == 3
			and int((榜[0] as Dictionary).get("pkLevel", 0)) == 1
			and String((榜[1] as Dictionary).get("name", "")) == "甲二"
			and int((榜[2] as Dictionary).get("trend", -1)) == 2)
	_喂帧(后, "2306:10:301:301:甲一:9001:乙一:111:60:7")
	var 被: Dictionary = _最后一帧(10).get("战报", {})
	_过程("2306:10 这一档**按冒号**拆（服务端 `:29399` 自己把 & 换成 :）八段全在",
			not 被.is_empty() and int(被.get("challenger", 0)) == 301
			and String(被.get("winnerName", "")) == "甲一" and String(被.get("loserName", "")) == "乙一"
			and int(被.get("timeStamp", 0)) == 111 and int(被.get("resultPkLevel", 0)) == 7)
	_喂帧(后, "2306:11:4:1")
	_过程("2306:11 排名 + 状态", int(_最后一帧(11).get("排名", -1)) == 4 and int(_最后一帧(11).get("状态", -1)) == 1)
	_收.clear()
	_喂帧(后, "2306:0:1:2")			# 段数不够 ⇒ 一条都不该发
	_喂帧(后, "2306:12:1")			# 未定义档 ⇒ 不发
	_喂帧(后, "2306:x:1")			# 动作号不是整数 ⇒ 不发
	_过程("坏帧/未定义档 ⇒ 一条信号都不发（不是发半份）", _收.is_empty())
	后.free()


# ── ② 几何（读 .tscn 文本，不从运行期反查）────────────────────────────────
func _判几何() -> void:
	var 主 := _取(主窗场景)
	_过程("主窗：底图 = (10,11) 750×516", _矩(主, "底图", [10.0, 11.0, 750.0, 516.0]))
	_过程("主窗：公告 = (216,25) 490×20", _矩(主, "面板/公告", [216.0, 25.0, 490.0, 20.0]))
	_过程("主窗：公告底板 = (216,55) 496×87", _矩(主, "面板/公告底板", [216.0, 55.0, 496.0, 87.0]))
	_过程("主窗：候选块原点 = (240,155)", _矩(主, "面板/候选块", [240.0, 155.0, 0.0, 0.0]))
	_过程("主窗：战报块原点 = (240,361)", _矩(主, "面板/战报块", [240.0, 361.0, 0.0, 0.0]))
	_过程("主窗：候选容器原点 = (240+8,155+8)（块内再进 8）",
			_矩(主, "面板/候选块/候选容器", [8.0, 8.0, 0.0, 0.0]))
	_过程("主窗：候选格2 在容器内 x=104（步距 90）、75×156",
			_矩(主, "面板/候选块/候选容器/候选格2", [104.0, 0.0, 75.0, 156.0]))
	## 全路径键才判得出这一条：五枚格同名子件（头像框/名字/等级…）按裸名收会互相顶掉。
	_过程("主窗：五枚候选格 x = 14/104/194/284/374（步距恒 90、每枚 75×156）",
			_矩(主, "面板/候选块/候选容器/候选格1", [14.0, 0.0, 75.0, 156.0])
			and _矩(主, "面板/候选块/候选容器/候选格3", [194.0, 0.0, 75.0, 156.0])
			and _矩(主, "面板/候选块/候选容器/候选格4", [284.0, 0.0, 75.0, 156.0])
			and _矩(主, "面板/候选块/候选容器/候选格5", [374.0, 0.0, 75.0, 156.0]))
	_过程("主窗：战报块底 482×140、容器进 8、五行各 466×23（步距 23 ⇒ 缝 0）",
			_矩(主, "面板/战报块/底", [0.0, 0.0, 482.0, 140.0])
			and _矩(主, "面板/战报块/战报容器", [8.0, 8.0, 0.0, 0.0])
			and _矩(主, "面板/战报块/战报容器/战报行2", [0.0, 23.0, 466.0, 23.0])
			and _矩(主, "面板/战报块/战报容器/战报行5", [0.0, 92.0, 466.0, 23.0]))
	_过程("主窗：战报行3 内 剑 (0,2) 18×18（真值 §元件表 `UISwf_PvpUI_JianIcon`）+ 文本 (20,3) 440×20",
			_矩(主, "面板/战报块/战报容器/战报行3/剑", [0.0, 2.0, 18.0, 18.0])
			and _矩(主, "面板/战报块/战报容器/战报行3/文本", [20.0, 3.0, 440.0, 20.0]))
	var 榜 := _取(榜场景)
	_过程("英雄榜：内容底 = (8,9) 364×354", _矩(榜, "内容底", [8.0, 9.0, 364.0, 354.0]))
	_过程("英雄榜：面板 = (13,24) 354×309", _矩(榜, "面板", [13.0, 24.0, 354.0, 309.0]))
	_过程("英雄榜：滚动区 = (18,51) 342×277", _矩(榜, "滚动区", [18.0, 51.0, 342.0, 277.0]))
	_过程("英雄榜：表头四列 40/140/80/60 同排 y=29",
			_矩(榜, "表头排名", [18.0, 29.0, 40.0, 20.0]) and _矩(榜, "表头名字", [58.0, 29.0, 140.0, 20.0])
			and _矩(榜, "表头等级", [198.0, 29.0, 80.0, 20.0]) and _矩(榜, "表头趋势", [278.0, 29.0, 60.0, 20.0]))
	_过程("英雄榜：三条竖分隔线在 58/198/278、天然 2×20",
			_矩(榜, "竖分隔1", [58.0, 31.0, 2.0, 20.0]) and _矩(榜, "竖分隔2", [198.0, 31.0, 2.0, 20.0])
			and _矩(榜, "竖分隔3", [278.0, 31.0, 2.0, 20.0]))
	_过程("英雄榜：横分隔线 = (18,49) 342×2", _矩(榜, "横分隔线", [18.0, 49.0, 342.0, 2.0]))
	_过程("英雄榜：关闭钮 = (159,336) 61×22", _矩(榜, "关闭钮", [159.0, 336.0, 61.0, 22.0]))


# ── ③ 战报合并与文案 ───────────────────────────────────────────────────────
func _判战报() -> void:
	竞技场窗.新会话()
	竞技场窗._并战报([_一条(战报甲), _一条(战报乙)])
	_过程("两条 ⇒ 降序（戳 222 在前）", String(竞技场窗.战报[0].get("winnerName", "")) == "乙一")
	竞技场窗._并战报([_一条("301&301&甲一&9001&乙一&222&99&8")])
	_过程("同 timeStamp ⇒ **覆盖那一条**、不新增（`addReport:281-295`）",
			竞技场窗.战报.size() == 2 and int(竞技场窗.战报[0].get("timeIntv", 0)) == 99)
	var 多: Array = []
	for i in range(7):
		多.append(_一条("301&301&甲一&9001&乙一&%d&1&7" % (1000 + i)))
	竞技场窗._并战报(多)
	_过程("超过 5 条 ⇒ 截前 5（`sortReport:449-456` MAX_ZHANBAO_COUNT）", 竞技场窗.战报.size() == 5)
	_过程("截完留下的正是最新那 5 条（降序）",
			int(竞技场窗.战报[0].get("timeStamp", 0)) == 1006 and int(竞技场窗.战报[4].get("timeStamp", 0)) == 1002)
	## `getZhanBao:193-226`：本号不是胜者 ⇒ else 支取 **winnerName**；战败那档原版用的是**绿字**
	var 条 := _一条(战报甲)
	var 文 := 竞技场窗.战报文本(条, 9002)
	_过程("getZhanBao：else 支取胜者名（甲一），不是败者名", "甲一" in 文 and "乙一" not in 文)
	_过程("getZhanBao：本号是败者 ⇒ 走「战败」那一支且是绿字 #00ff00（原版的呆账，照抄）",
			"战败" in 文 and "#00ff00" in 文)
	var 文2 := 竞技场窗.战报文本(_一条("9002&9002&本号&301&甲一&111&60&4"), 9002)
	_过程("本号是挑战者**且胜** ⇒ 「排名升至%d」（`getZhanBao:199-202` 的那一支）",
			"排名升至4" in 文2 and "排名不变" not in 文2)
	_过程("本号是被挑战的那一方且胜 ⇒ 「排名不变」（升档只给挑战者）",
			"排名不变" in 竞技场窗.战报文本(_一条("9001&9002&本号&301&甲一&111&60&4"), 9002))
	_过程("挑战者那一支写「你挑战…」，被挑战那一支写「…挑战你」（两支行头互斥）",
			"你挑战" in 文2 and "你挑战" not in 文 and "挑战你" in 文)


func _一条(串: String) -> Dictionary:
	var 段 := 串.split("&", false)
	return {
		"challenger": int(段[0]), "winnerId": int(段[1]), "winnerName": String(段[2]),
		"loserId": int(段[3]), "loserName": String(段[4]), "timeStamp": int(段[5]),
		"timeIntv": int(段[6]), "resultPkLevel": int(段[7]),
	}


# ── ④ 对手帧 ───────────────────────────────────────────────────────────────
func _判对手帧() -> void:
	var 后 = 后端脚本.new()
	后.call("_handle_spawn_monster_text", PackedStringArray(对手帧.split(":")))
	var 状: Dictionary = (后.get("map_monsters") as Dictionary).get(对手号, {})
	_过程("arena-player 那一支认出来了（进了怪物那一本账）", not 状.is_empty())
	_过程("object_id / 坐标 / 落脚点 照段位",
			int(状.get("object_id", -1)) == 对手号 and int(状.get("x", -1)) == 1450
			and int(状.get("y", -1)) == 862 and int(状.get("foothold", -1)) == 7)
	_过程("第 4 段是**肤色**，没被当成模板号（monster_id 恒 0）",
			int(状.get("monster_id", -1)) == 0)
	var 对: Dictionary = 状.get("对手", {})
	_过程("对手字段：头像/等级/名字/攻速/移速",
			int(对.get("face", -1)) == 10000204 and int(对.get("level", -1)) == 55
			and String(对.get("name", "")) == "乙一" and int(对.get("attack_speed", -1)) == 7
			and int(对.get("walk_speed", -1)) == 175)
	_过程("招式两档（`101&3@102&5`）", (对.get("skills", []) as Array).size() == 2
			and int(((对.get("skills", []) as Array)[0] as Dictionary).get("level", 0)) == 3)
	_过程("装备两档（`2&30000101@3&30000102`）", (对.get("equipment", []) as Array).size() == 2
			and String(((对.get("equipment", []) as Array)[1] as Dictionary).get("item_id", "")) == "30000102")
	_过程("神器两个 + 灵面/灵色", (对.get("shenqi", []) as Array).size() == 2
			and int(对.get("ling_face", -1)) == 9 and int(对.get("ling_color", -1)) == 8)
	_过程("竞技场对手**没有**精英段（招式串没被误当精英串）", (状.get("jingying", []) as Array).is_empty())
	## 阳性对照：普通怪那一支一条都没变
	后.call("_handle_spawn_monster_text", PackedStringArray(怪帧.split(":")))
	var 怪: Dictionary = (后.get("map_monsters") as Dictionary).get(700001, {})
	_过程("普通怪那一支照旧（模板号 1000001、无 `对手` 键）",
			int(怪.get("monster_id", -1)) == 1000001 and 怪.get("对手", {}).is_empty())
	后.free()


# ── ⑤ 动作词对照 ───────────────────────────────────────────────────────────
func _判动作词() -> void:
	var 人 := OriginalSprite.new()
	var 怪 := OriginalSprite.new()
	_过程("角色表能 configure（10000204）", 人.configure("character", "10000204", "stand"))
	_过程("怪物表能 configure（1000001）", 怪.configure("mob", "1000001", "stand"))
	_过程("角色表里确实**没有** move（这才需要对照层）", not (人.actions as Dictionary).has("move"))
	for 名 in ["move", "attack1", "hit1", "die1"]:
		_过程("角色美术上解得到怪物帧动作名「%s」" % 名, bool(人.has_method("有动作")) and bool(人.有动作(名)))
	人.play("move")
	_过程("play(move) ⇒ 停在 walk", String(人.action) == "walk")
	人.play_once("attack1")
	_过程("play_once(attack1) ⇒ attack", String(人.action) == "attack")
	人.play_once("hit1")
	_过程("play_once(hit1) ⇒ hit（受击僵直拿得到时长）", String(人.action) == "hit" and 人.动作时长毫秒("hit1") > 0)
	人.play_once("die1")
	_过程("play_once(die1) ⇒ dead", String(人.action) == "dead")
	怪.play("move")
	_过程("普通怪 move 仍是 move（**别名层没污染它**）", String(怪.action) == "move")
	怪.play_once("attack1")
	_过程("普通怪 attack1 仍是 attack1", String(怪.action) == "attack1")
	_过程("别名层只改翻不到的名字：角色表里本来就有的 stand 原样返回", String(人._动作名("stand")) == "stand")
	_过程("两边都翻不到的名字（jump 在怪物侧）也**原样返回**、不会被弄成空串",
			String(怪._动作名("jump")) == "jump" and String(人._动作名("nope")) == "nope")
	_过程("真怪物那一侧有 move ⇒ 一条都不该翻（别名层对它透明）", String(怪._动作名("move")) == "move")
	人.free()
	怪.free()


# ── ⑥ isPking 是换图翻、不是收帧翻 ─────────────────────────────────────────
func _判对战状态() -> void:
	竞技场窗.新会话()
	竞技场窗.在对战 = false
	var 后 = 后端脚本.new()
	_初始化(后)
	## ★ 这一段判的是**控制器的状态**（战斗剩余 / isPking），所以必须把 `竞技场帧` 真接进 `竞技场窗._回帧`
	##   （运行期由 `窗口管理._ready` 调 `挂全局`；离线门里没人调 ⇒ 不接就是"0 比 0"的假绿）。
	竞技场窗.挂全局(后)
	_喂帧(后, "2306:5:900")
	_过程("2306:5 只把秒数存进 战斗剩余", 竞技场窗.战斗剩余 == 900)
	_过程("2306:5 **不**翻 isPking（`onPk_showBattleRemainTime:276-279` 一个字都不画）", not 竞技场窗.在对战)
	## 挨个把"最像开战"的几档都喂一遍：0（面板信息）、11（排名奖状态）、1（排名）都不许翻 isPking。
	_喂帧(后, "2306:0:2:15:37:3:8000:12:" + "@".join(候选行) + ":" + "@".join([战报甲, 战报乙]))
	_喂帧(后, "2306:11:4:1")
	_喂帧(后, "2306:1:9")
	_过程("2306:0/11/1 三档喂完仍是假 ⇒ isPking 只由**换图**翻",
			not 竞技场窗.对战中() and 竞技场窗.奖等级 == 4 and 竞技场窗.排名 == 9)
	竞技场窗.进图(竞技场图, null)
	_过程("进竞技场图 ⇒ isPking 翻真", 竞技场窗.对战中())
	竞技场窗.进图(竞技场图, null)
	_过程("同一张图重复进 ⇒ 不重复触发（`param1 == mapid && !isPking`）", 竞技场窗.对战中())
	竞技场窗.进图(101010000, null)
	_过程("离开竞技场图 ⇒ isPking 翻假", not 竞技场窗.对战中())
	_判开局转发()
	后.free()


## `onStartPk:230-237` / `onEndPk:321-325` 那几步**到底转发了什么** —— 用两枚假件接住调用记账。
## ★ 这一组顶掉「不崩就算过」那种空断言：`生命` 为空时的闸口也照样量得出来（一条都不许多转）。
func _判开局转发() -> void:
	var 生命源 := "\n".join([
		"extends Node", "var 喊: Array = []",
		"func 显示战场倒计时(秒: int) -> void:", "\t喊.append(['钟', 秒])",
		"func 隐藏战场倒计时() -> void:", "\t喊.append(['藏钟', 0])",
		"func 显示宠物(是否: bool) -> void:", "\t喊.append(['宠物', 是否])"])
	var 管理源 := "\n".join([
		"extends Node", "var 关了几次 := 0",
		"func 全部关闭() -> void:", "\t关了几次 += 1"])
	var 生 := GDScript.new()
	生.source_code = 生命源
	var 管 := GDScript.new()
	管.source_code = 管理源
	if 生.reload() != OK or 管.reload() != OK:
		_过程("假件编译失败（这条门没跑起来，别当成通过）", false)
		return
	var 父 := Node.new()
	var 假生命 := Node.new()
	假生命.name = "生命根"
	假生命.set_script(生)
	var 假管理 := Node.new()
	假管理.name = "窗口管理"
	假管理.set_script(管)
	父.add_child(假生命)
	父.add_child(假管理)
	竞技场窗.进图(竞技场图, 假生命)
	var 喊: Array = 假生命.get("喊") as Array
	_过程("进图 ⇒ 转发『显示战场倒计时(900)』= onStartPk 第三步用的是 2306:5 存的那份秒数",
			喊.size() == 2 and String(喊[0][0]) == "钟" and int(喊[0][1]) == 900)
	_过程("进图 ⇒ 转发『显示宠物(false)』= onStartPk 第四步（两只都要藏）",
			String(喊[1][0]) == "宠物" and not bool(喊[1][1]))
	_过程("进图 ⇒ `窗口管理.全部关闭()` 被喊到一次（closeWindowOnEnterBattle + 关那两扇塌成这条）",
			int(假管理.get("关了几次")) == 1)
	竞技场窗.进图(101010000, 假生命)
	_过程("离场 ⇒ 转发『隐藏战场倒计时』+『显示宠物(true)』（onEndPk 两步都回到原位）",
			喊.size() == 4 and String(喊[2][0]) == "藏钟" and String(喊[3][0]) == "宠物" and bool(喊[3][1]))
	## 闸口：`生命` 为空 ⇒ isPking 照翻，但**一条都不许多转**（`是活节点` 那两道闸 + 管理取不到）
	竞技场窗.进图(竞技场图, null)
	_过程("没有生命根时进图：isPking 照翻、但四下转发一条都没多",
			竞技场窗.对战中() and 喊.size() == 4 and int(假管理.get("关了几次")) == 1)
	竞技场窗.进图(101010000, null)
	_过程("没有生命根时离场：isPking 照翻假、也不崩", not 竞技场窗.对战中() and 喊.size() == 4)
	父.free()
	## ⚠ `生`/`管` 是 `GDScript`（RefCounted）⇒ **不许 `.free()`**（会刷 "Attempted to free a
	##   RefCounted object"，把日志搞脏还可能被误读成门坏了）；`父` 是 Node 才要手动 free。


# ── ⑦ 尺寸表两条 ───────────────────────────────────────────────────────────
func _判尺寸表() -> void:
	var 文 := FileAccess.get_file_as_string(尺寸表路径).trim_prefix("﻿")
	var 表 = JSON.parse_string(文)
	_过程("尺寸表能解析（带 BOM 要剥）", 表 is Dictionary)
	if not (表 is Dictionary):
		return
	var 主: Dictionary = (表 as Dictionary).get("竞技场", {})
	var 榜: Dictionary = (表 as Dictionary).get("竞技场英雄榜", {})
	_过程("竞技场 770×567 / 整框 true / 内容底 false",
			int(主.get("宽", 0)) == 770 and int(主.get("高", 0)) == 567
			and bool(主.get("整框", false)) and not bool(主.get("内容底", true)))
	_过程("英雄榜 380×400 / 整框 true / 内容底 false / 标题「英雄榜」",
			int(榜.get("宽", 0)) == 380 and int(榜.get("高", 0)) == 400
			and bool(榜.get("整框", false)) and not bool(榜.get("内容底", true))
			and String(榜.get("标题", "")) == "英雄榜")
	## ★ 两道错会互相抵消 ⇒ 体检门也会漏（`原点` 键优先于 `整框`）⇒ 这里直接钉"没有这个键"
	_过程("两条都**没有** `原点` 键（有的话会把整框顶掉、整页偏 29）",
			not 主.has("原点") and not 榜.has("原点"))


# ── ⑧ 「第 N 格发的是第 N 行那个号」这条映射 + 中文 meta 键这一族的复发闸 ──
## 10-24 的真实事故：`_喂格` 把号写进 `格.set_meta("号", …)`，而 Godot 4 的 metadata 键要求
## **合法标识符** ⇒ 中文键当场 `ERROR: Invalid metadata identifier: '号'` 且**存不进去**，
## `_点头像` 取回恒 0 ⇒ 点候选格头像永远没反应；更糟的是这行 ERROR 还把 `_刷页` 从中间打断，
## 面板永远不显形 ⇒ `窗口行为契约体检` / `窗口布局体检` 那两道扫全页的门一起报"空页"。
func _判格子取号() -> void:
	竞技场窗.新会话()
	竞技场窗.候选 = [_候(301, 7), _候(302, 9), _候(303, 8)]
	var 序: Array = 竞技场窗._排候选()
	_过程("_排候选 按 pkLevel 降序（7/9/8 ⇒ 302,303,301）——摆格与取号共用这一份",
			int((序[0] as Dictionary).get("charId", 0)) == 302
			and int((序[1] as Dictionary).get("charId", 0)) == 303
			and int((序[2] as Dictionary).get("charId", 0)) == 301)
	_过程("`候选序` 由 新会话 清回空（不许把上一场的排序留给下一页）", 竞技场窗.候选序.is_empty())
	var 坏: Array[String] = []
	for 路 in 竞技场文件:
		坏.append_array(_坏meta(路))
	_过程("竞技场这一族的 .gd 里**一个中文 meta 键都没有**（set_meta/get_meta 都算）：%s" % [坏], 坏.is_empty())
	_过程("阳性对照：这条扫描本身测得出东西（拿一条含中文键的样本必然点名）",
			not _坏meta(假meta样本).is_empty())


const 竞技场文件: Array[String] = [
	"res://脚本/界面/窗口/竞技场窗.gd",
	"res://脚本/界面/窗口/竞技场结算弹.gd",
	"res://脚本/界面/窗口/竞技场战报弹.gd",
	"res://脚本/界面/窗口/竞技场英雄榜窗.gd",
	"res://脚本/界面/组件/战场倒计时.gd",
]
## 阳性对照样本就放在工程里（一个字符都不碰运行时）：这道扫描要是哪天测不出它，说明扫描自己坏了。
const 假meta样本 := "res://数据/界面/竞技场meta阳性对照.txt"


func _候(号: int, 名次: int) -> Dictionary:
	return {"charId": 号, "pkLevel": 名次, "face": 10000204, "playerLevel": 55, "name": "甲%d" % 号}


## 扫源码文本里的 `set_meta("中文")` / `get_meta("中文")`。注释行剥掉（不然一条讲坑的注释会自造红）。
func _坏meta(路: String) -> Array[String]:
	var 出: Array[String] = []
	for 行 in FileAccess.get_file_as_string(路).split("\n"):
		var 串 := String(行).trim_suffix("\r")
		if 串.strip_edges().begins_with("#"):
			continue
		var 位 := 串.find("_meta(\"")
		if 位 < 0:
			continue
		var 余 := 串.substr(位 + 7)
		var 尾 := 余.find("\"")
		if 尾 <= 0:
			continue
		var 键 := 余.substr(0, 尾)
		if 键.length() > 0 and 键.unicode_at(0) >= 0x2E80:
			出.append("%s → %s" % [路.get_file(), 键])
	return 出


# ── ⑨ 贴图盒：**屏幕上的矩形** == `.tscn` 里声明的矩形 ─────────────────────────
## 10-24 抓到的一条：`战报块/底` 声明 482×140（原版 `PvpZhanBaoPanel.as:19-21` 把 482×198 那张皮
## **整帧压扁** —— `UISwfMovieClipAgent` 的 `set w/set h` 就是 `_content.width/height`，没有 scale9Grid），
## 可 Godot 的 `TextureRect` 缺省 `expand_mode=0`(KEEP_SIZE) 把**贴图天然尺寸当最小盒**，
## 而 `Control::set_size` 绝不低于最小盒 ⇒ 140 被顶回 198，整页从 567 高的框里掉出去 32 像素。
## 上面 ② 那道几何门读的是 `.tscn` **声明值** ⇒ 对这次事故完全失明（= 量具读声明、屏幕读解算）。
## ⇒ 这一族只能运行期量：两扇真装进树里、等两帧、逐件比 `get_size()`，并带一条阳性对照。
func _判贴图盒() -> void:
	var 坏: Array[String] = []
	var 件数 := 0
	for 项 in [[主窗场景, "主窗"], [榜场景, "英雄榜"]]:
		var 路 := String(项[0])
		var 景 := ResourceLoader.load(路) as PackedScene
		if 景 == null:
			坏.append("%s：场景载入失败" % 项[1])
			continue
		var 根: Node = 景.instantiate()
		root.add_child(根)
		await process_frame
		await process_frame
		var 声明: Dictionary = _取(路)
		var 收: Array = []
		_走贴图(根, "", 收)
		件数 += 收.size()
		if 收.size() != _数贴图(路):
			坏.append("%s：树上 %d 枚、`.tscn` 里 %d 枚 ⇒ 有一族根本没被量到" % [项[1], 收.size(), _数贴图(路)])
		for 条 in 收:
			var 名 := String(条[0])
			var 件 := 条[1] as TextureRect
			var v: Dictionary = 声明.get(名, {})
			if v.size() < 4:
				坏.append("%s：`%s` 在 `.tscn` 里四条 offset 不齐" % [项[1], 名])
				continue
			var 望 := Vector2(float(v.get("右", 0.0)) - float(v.get("x", 0.0)),
					float(v.get("下", 0.0)) - float(v.get("y", 0.0)))
			var 得 := 件.get_size()
			if 得.distance_to(望) > 0.51:
				坏.append("%s：`%s` 屏幕盒 %.0fx%.0f ≠ 声明 %.0fx%.0f（expand_mode=%d）" % [
					项[1], 名, 得.x, 得.y, 望.x, 望.y, 件.expand_mode])
			var 天 := Vector2.ZERO
			if 件.texture != null:
				天 = 件.texture.get_size()
			if 天 != 望 and 件.stretch_mode != TextureRect.STRETCH_SCALE:
				坏.append("%s：`%s` 声明 %.0fx%.0f ≠ 贴图天然 %.0fx%.0f 却没走整帧拉伸（stretch_mode=%d，原版是 `_content.width/height`）" % [
					项[1], 名, 望.x, 望.y, 天.x, 天.y, 件.stretch_mode])
		根.free()
	_过程("两扇逐件比过屏幕盒（枚数 %d：主窗 27 + 英雄榜 4）：%s" % [件数, 坏],
			件数 == 31 and 坏.is_empty())
	var 顶回 := 0
	var 照住 := 0
	for 档 in [TextureRect.EXPAND_KEEP_SIZE, TextureRect.EXPAND_IGNORE_SIZE]:
		var 样: TextureRect = TextureRect.new()
		样.expand_mode = 档
		样.stretch_mode = TextureRect.STRETCH_SCALE
		样.texture = ImageTexture.create_from_image(Image.create(482, 198, false, Image.FORMAT_RGBA8))
		root.add_child(样)
		样.offset_right = 482.0
		样.offset_bottom = 140.0
		await process_frame
		await process_frame
		if int(档) == 0:
			顶回 = int(round(样.get_size().y))
		else:
			照住 = int(round(样.get_size().y))
		样.free()
	_过程("阳性对照：同一条 482×140 声明压在 482×198 的皮上 —— 缺省档顶回 %d、IGNORE 档 %d（量法测得出这一族）" % [顶回, 照住],
			顶回 == 198 and 照住 == 140)


## 从场景根往下收 TextureRect，键与 `_取()` 的 `.tscn` 全路径同一口径（根的 parent 是 "." ⇒ 裸名）。
func _走贴图(节: Node, 前: String, 出: Array) -> void:
	for 子 in 节.get_children():
		var 路 := String(子.get_name()) if 前.is_empty() else 前 + "/" + String(子.get_name())
		if 子 is TextureRect:
			出.append([路, 子])
		_走贴图(子, 路, 出)


func _数贴图(路: String) -> int:
	var n := 0
	for 行 in FileAccess.get_file_as_string(路).split("\n"):
		var 串 := String(行).trim_suffix("\r")
		if 串.begins_with("[node ") and 串.contains('type="TextureRect"'):
			n += 1
	return n

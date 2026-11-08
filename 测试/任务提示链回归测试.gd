## 任务提示链（42 / 51 两条回帧 → 自动赶路 + 完成横幅）的形状门。
##
## 为什么只判形状：这三件事的**运行期证据**在另一把量具里 ——
## `开发工具/截任务标记与横幅.gd`（有头，真截图、真数像素）。
## 本门管的是"别在改别的时把这条链悄悄拆了"：
##   ① 客户端 `match opcode` 里必须真的有 42 与 51 两个分支（10-09 之前两个都没有，
##      于是服务端在发的两条回帧整条被丢掉 —— 这就是"任务做出来了但没有灵魂"的根因）；
##   ② 42 只认 `infoType=QUEST(1) && questStatus=START(1) && updateType=0` 那一条，
##      读错一位就会把经验/金币那些 infoType 也当接任务；
##   ③ HUD 两个信号都要接上，接完任务的自动赶路要照原版那条算式**分档**
##      （2 去怪 / 3 去 NPC / null 不赶路 —— 见 ⑥；1 去图在任务链上不可达）；
##   ④ 横幅的四个时间点与位置照 `QuestDataManager.as:739-756 / :787-811`，
##      图必须是 `数据/特效.json` 里那条 `questOverTip`（424×98、原点 212,0）。
extends SceneTree

var _失败: Array[String] = []
var _条数 := 0
var 换 := char(10)


func _initialize() -> void:
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


func _读(路: String) -> String:
	return FileAccess.get_file_as_string(路)


func _run() -> void:
	var 后端 := _读("res://脚本/单例/后端连接.gd")
	var HUD := _读("res://脚本/界面/小地图面板.gd")
	_断言(后端.contains("const OP_SHOW_STATUS_INFO := 42"), "后端连接.gd 没有 OP_SHOW_STATUS_INFO=42")
	_断言(后端.contains("const OP_SHOW_QUEST_COMPLETION := 51"), "后端连接.gd 没有 OP_SHOW_QUEST_COMPLETION=51")
	_断言(后端.contains("\t\tOP_SHOW_STATUS_INFO:\n\t\t\t_handle_show_status_info_text(fields)"),
			"42 没进 match 分发表（信号定义了但回帧永远不到）")
	_断言(后端.contains("\t\tOP_SHOW_QUEST_COMPLETION:\n\t\t\t_handle_quest_completion_text(fields)"),
			"51 没进 match 分发表")
	## ② 42 的三道闸：infoType / questStatus / updateType 一位都不能少
	var 处理体 := _截段(后端, "func _handle_show_status_info_text", "func _handle_quest_completion_text")
	_断言(处理体.contains("STATUS_INFO_QUEST"), "42 处理没筛 infoType ⇒ 经验/金币那些也会当接任务")
	_断言(处理体.contains("QUEST_STATUS_START"), "42 处理没筛 questStatus(START=1)")
	_断言(处理体.contains("int(fields[4]) != 0"), "42 处理没筛 updateType==0（原版 :4198 那条）")
	_断言(处理体.contains("fields.size() < 5"), "42 处理没查字段数，短帧会越界")
	_断言(_截段(后端, "func _handle_quest_completion_text", "func ").contains("fields[1]"),
			"51 的 questId 应当读 fields[1]（原版只 readInt 一个）")
	## ③ HUD 两条都要接
	_断言(HUD.contains("_backend.quest_accepted.connect(_于任务接上)"), "HUD 没接 quest_accepted ⇒ 接完任务不会自己赶路")
	_断言(HUD.contains("_backend.quest_completion_shown.connect(_于任务交付)"), "HUD 没接 quest_completion_shown")
	_断言(HUD.contains("func _于任务接上"), "HUD 缺 _于任务接上")
	_断言(HUD.contains("func _寻路目标"), "HUD 缺 _寻路目标（原版 getQuestPoint 那条算式）")
	## 交付那半边：51 不能只出横幅，还要「走去交付 NPC」。
	## ⚠ 2026-10-10 改过形状：走路那一支**不再写在 `_于任务交付` 里**，而是由那块提示条的
	##   `确定点击` 触发（原版 `isAutoQuestFun → __onOkClick → qusetClickText(3, endNpcId)`）。
	##   以前直接钉"交付段里要有 前往NPC(" ⇒ 语义改对了反而会红，所以这里改成钉**两头都在**：
	##   交付段挂上交付档的条 + `_于提示条确定` 的交付支真的走去交付 NPC。
	var 交付段 := _截段(HUD, "func _于任务交付", "
func ")
	_断言(交付段.contains("播任务完成横幅()"), "_于任务交付 没播横幅")
	_断言(交付段.contains("提示条.档交付"), "_于任务交付 没挂交付档的提示条")
	var 确定段 := _截段(HUD, "func _于提示条确定", "
func ")
	_断言(确定段.contains("任务交付NPC") and 确定段.contains("前往NPC("),
			"_于提示条确定 的交付支没接「自动赶路去交付 NPC」那一半（MessageTipPane2:280-283）")
	_断言(_读("res://脚本/单例/游戏会话.gd").contains("func 任务交付NPC"),
			"游戏会话.gd 缺 任务交付NPC()")
	_断言(HUD.contains("func _自动交接"), "HUD 缺 _自动交接（原版 closeCommitQuest 那一档）")
	## ④ 横幅的四个时间点 + 位置 + 图
	## 这条以前钉的是「写死 480」—— 钉错了：原版 :744 是 Config.STAGE_WIDTH/2，是运行期宽。
	## 钉成常数等于把「最大化窗口后横幅偏左」这个 bug 钉成了合格。
	_断言(HUD.contains("get_visible_rect().size.x * 0.5, 横幅y)"),
			"横幅 x 没跟着视口宽走（原版 STAGE_WIDTH/2 是运行期算的）")
	_断言(not HUD.contains("const 横幅x"), "横幅 x 又写死成常数了 ⇒ 窗口一变就不居中")
	_断言(HUD.contains("const 横幅y := 50.0"), "横幅 y 应为 50（`QuestDataManager.as:745`）")
	_断言(HUD.contains("const 横幅淡入完 := 0.5") and HUD.contains("const 横幅开始淡出 := 3.5")
			and HUD.contains("const 横幅移除 := 4.5"),
			"横幅三个时间点应为 0.5 / 3.5 / 4.5 秒（`:791-806`）")
	_断言(HUD.contains("const 横幅每帧步长 := 0.1"), "横幅 alpha 步长应为 0.1/帧（`:793`、`:803`）")
	_断言(HUD.contains("const 横幅特效 := \"questOverTip\""), "横幅必须播 特效.json 里那条 questOverTip")
	var 表: Variant = JSON.parse_string(_读("res://数据/特效.json").trim_prefix("\ufeff"))
	_断言(typeof(表) == TYPE_DICTIONARY, "数据/特效.json 读不出来")
	if typeof(表) == TYPE_DICTIONARY:
		var 条: Dictionary = (表.get("特效", {}) as Dictionary).get("questOverTip", {}) as Dictionary
		_断言(not 条.is_empty(), "特效.json 里没有 questOverTip")
		var 帧: Array = 条.get("帧", []) as Array
		_断言(帧.size() == 1, "questOverTip 应当只有 1 帧（Etc.effects 里 delay=1000），实际 %d" % 帧.size())
		if 帧.size() == 1:
			var 首: Dictionary = 帧[0] as Dictionary
			_断言(int(首.get("宽", 0)) == 424 and int(首.get("高", 0)) == 98,
					"questOverTip 尺寸应为 424x98，实际 %sx%s" % [首.get("宽", 0), 首.get("高", 0)])
			var 原: Array = 首.get("原点", []) as Array
			## JSON 里的数字**一律是 float**（ 读回来是 ）⇒ 逐位比 int，别比字符串
			_断言(原.size() == 2 and int(原[0]) == 212 and int(原[1]) == 0,
					"questOverTip 原点应为 [212, 0]（水平居中挂在锚点上），实际 %s" % str(原))
			_断言(ResourceLoader.exists(String(首.get("贴图", ""))), "questOverTip 的图不在盘上")
	# ⑤「关闭自动提交任务」那枚勾选框要真的管用（#144 的勾选框那一半）。
	#   原版：`MessageTipPane2.as:386-406` 的 `isAutoQuestFun()` 读 `SysCfg.closeCommitQuest`，
	#   勾上 ⇒ 不自动赶路、改弹那块提示条（提示条本体还欠着 = #143）。
	#   ⚠ 以前 `_自动交接()` 写死 `return true` ⇒ 那枚勾**点了没有任何作用**，
	#   而这条链的门测的恰好是「默认那一条」，所以它一直绿。
	var 面板源 := _读("res://脚本/界面/小地图面板.gd")
	var 段 := _截段(面板源, "func _自动交接", "func _于任务交付")
	_断言(段.contains("auto_commit_quest"), "交接开关读的是设置里那个键（不是常数）")
	_断言(段.count("return true") == 1,
			"只剩「没有会话」那一支兜底 return true，正常路径必须查表（实际 %d 处）" % 段.count("return true"))
	var 假 := _假会话.new()
	root.add_child(假)
	var 裸: Node = (load("res://脚本/界面/小地图面板.gd") as GDScript).new()
	裸.set("_session", 假)
	_断言(bool(裸.call("_自动交接")), "设置里没这个键 ⇒ 默认自动交接（原版 closeCommitQuest 初值 false）")
	假.game_settings["auto_commit_quest"] = false
	_断言(not bool(裸.call("_自动交接")), "勾了「关闭自动提交任务」⇒ 不再自动赶路（键存的是正向值，别取两次反）")
	假.game_settings["auto_commit_quest"] = true
	_断言(bool(裸.call("_自动交接")), "没勾 ⇒ 继续自动赶路")
	裸.free()
	假.free()
	# 跨模块对齐：设置页那枚写的键，必须就是这里读的键（两边各写一份就会静默失联）
	var 期望: Dictionary = JSON.parse_string(_读("res://数据/界面/设置页期望.json")) as Dictionary
	var 枚: Array = 期望.get("复选", []) as Array
	var 找: Array = []
	for 一条 in 枚:
		if str((一条 as Array)[5]) == "auto_commit_quest":
			找 = 一条
	_断言(找.size() >= 7, "设置页期望表里找得到那一枚（键 %s）" % str(找[5] if 找.size() > 5 else "无"))
	_断言(找.size() >= 7 and str(找[1]) == "关闭自动提交任务",
			"标题逐字照 `SYSCONFIG_CLOSE_COMMIT_QUEST`（en_US$message_properties.as:2240）实际 %s" % str(找[1] if 找.size() > 1 else "-"))
	_断言(找.size() >= 7 and bool(找[6]) == false,
			"写值取反位必须是 false（勾上=关掉 ⇒ 存 false）⇒ 面板那边就不许再取一次反")
	# ⑥「接完任务往哪走」= 原版 `BasicQuestInfoData.getQuestPoint()`（`:94-166`），#144 剩下的那一半。
	#   全量 214 条任务里 **84 条（39%）算出来是「去怪」那一档**：以前只接了「去 NPC」，
	#   于是接一个杀怪任务，人往**交任务的那个 NPC** 走 —— 方向正好相反，用户一眼就看出来。
	#   ⓪ 这里一律喂**自己造的**定义表，不读 `数据/任务.json`：数据会随版本变，
	#      而「六类目标的次序 + 每类只看第一条」这两条形状是 AS3 定的，不该跟着数据漂。
	var 板: Node = (load("res://脚本/界面/小地图面板.gd") as GDScript).new()
	var 寻 := func(定: Dictionary) -> Array: return 板.call("_寻路目标", {}, 定) as Array
	var 怪定 := {"check": {"1": {"mob": {"0": {"id": 1000001, "map": 101020000}}}}}
	_断言(寻.call(怪定) == [2, 1000001, 101020000],
			"目标里有怪 ⇒ 走去那只怪（实得 %s）" % str(寻.call(怪定)))
	var 又怪又人 := {"check": {"1": {
			"mob": {"0": {"id": 1000001, "map": 101020000}},
			"item": {"0": {"id": 4000001, "npc": 4}}}}}
	_断言(寻.call(又怪又人) == [2, 1000001, 101020000],
			"mobs 排在 items 之前（`:109-131`），有怪就不看物品（实得 %s）" % str(寻.call(又怪又人)))
	var 多条 := {"check": {"1": {"mob": {
			"0": {"id": 1000001, "map": 101020000},
			"1": {"id": 1000002, "map": 101030000}}}}}
	_断言(寻.call(多条) == [2, 1000001, 101020000],
			"多条目标**只看第一条**（AS3 那个 for each 每条都在第一项 return，不是挑最合适的）（实得 %s）"
					% str(寻.call(多条)))
	var 交物 := {"check": {"1": {"item": {"0": {"id": 4000001, "npc": 4, "count": 1}}}}}
	_断言(寻.call(交物) == [3, 4, 0],
			"交物品且写了交给谁 ⇒ 走去那个 NPC（实得 %s）" % str(寻.call(交物)))
	var 打物 := {"check": {"1": {"item": {"0": {"id": 4000001, "map": 101020000, "mob": 1000002}}}}}
	_断言(寻.call(打物) == [2, 1000002, 101020000],
			"交物品没写 npc、写了 map/mob ⇒ 先去打那只怪（`:120-129`）（实得 %s）" % str(寻.call(打物)))
	var 买物 := {"check": {"1": {"item": {"0": {"id": 15008002, "cash": 1}}}}}
	_断言(寻.call(买物).is_empty(),
			"npc/map/mob 全空（商城买的那类，如 5011）⇒ 原版 return null，这里必须是空数组、不赶路（实得 %s）"
					% str(寻.call(买物)))
	var 装备 := {"check": {"1": {"equip": {"0": {"id": 1020010, "npc": 31}}}}}
	_断言(寻.call(装备) == [3, 31, 0], "equips 与 items 同一支算式（`:133-148`）（实得 %s）" % str(寻.call(装备)))
	var 装比人前 := {"check": {"1": {
			"equip": {"0": {"id": 1020010, "npc": 31}},
			"npc": {"0": {"id": 5}}}}}
	_断言(寻.call(装比人前) == [3, 31, 0], "equips 排在 npcs 之前（实得 %s）" % str(寻.call(装比人前)))
	var 又装又物 := {"check": {"1": {
			"item": {"0": {"id": 4000001, "npc": 4}},
			"equip": {"0": {"id": 1020010, "npc": 31}}}}}
	_断言(寻.call(又装又物) == [3, 4, 0],
			"items 排在 equips 之前（`:116` 在 `:133` 之前）（实得 %s）" % str(寻.call(又装又物)))
	var 人比宠前 := {"check": {"1": {
			"npc": {"0": {"id": 5}},
			"pet": {"0": {"mob": 4000000, "map": 101040000}}}}}
	_断言(寻.call(人比宠前) == [3, 5, 0], "npcs 排在 pets 之前（实得 %s）" % str(寻.call(人比宠前)))
	var 零号人 := {"check": {"1": {"npc": {"0": {"id": 0}, "1": {"id": 7}}}}}
	_断言(寻.call(零号人) == [3, 7, 0],
			"npcs 那一支例外：id 为 0 要接着看下一条（`:152` 的 if(_loc8_)）（实得 %s）" % str(寻.call(零号人)))
	var 捉宠 := {"check": {"1": {"pet": {"0": {"id": 101, "mob": 4000000, "map": 101040000}}}}}
	_断言(寻.call(捉宠) == [2, 4000000, 101040000],
			"捕捉目标读的是 pet 条目的 mob/map，**不是 id**（id 是通灵兽序号、不能当怪号寻路）（实得 %s）"
					% str(寻.call(捉宠)))
	var 假接 := {"check": {"0": {"mob": {"0": {"id": 999, "map": 888}}}, "1": {"lvmin": 10}}}
	_断言(寻.call(假接) == [3, 0, 0],
			"接取条件那一档（check 的 0）里的怪不能当寻路目标（`:836` 只取 1 那一档）（实得 %s）"
					% str(寻.call(假接)))
	var 兜底 := {"check": {"1": {"lvmin": 10}}, "npc": {"0": 1, "1": 2}}
	_断言(寻.call(兜底) == [3, 2, 0], "六类全空 ⇒ 兜底走去付 NPC（endNpcId = npc[1]）（实得 %s）" % str(寻.call(兜底)))
	_断言(板.call("_寻路目标", {"target_npc": 9}, 兜底) == [3, 9, 0],
			"在线条目自己带了交付 NPC 时优先用它（= AS3 里 dynamicData 覆盖 endNpcId 那两条）")
	_断言(板.call("_寻路目标", {}, {}) == [3, 0, 0],
			"定义表整个查不到 ⇒ [3,0,0]，`前往NPC(0)` 那一头直接 return，不报错也不赶路")
	板.free()
	## 分派那一头（运行期 `_走向任务怪`/`前往NPC` 要树和会话，离线门里只钉形状）：
	var 接段 := _截段(HUD, "func _于任务接上", "func _接上的条目")
	_断言(接段.contains("_寻路目标("), "_于任务接上 还在只走 NPC 那一档（没改用算式）")
	_断言(接段.contains("目.is_empty()") and 接段.contains("return"),
			"_于任务接上 没把 null 那一档拦下来 ⇒ 会往 (0,0) 走")
	_断言(接段.contains("_走向任务怪("), "_于任务接上 缺「去怪」那一档（84 条任务接完不往怪走）")
	_断言(接段.contains("前往NPC("), "_于任务接上 缺「去 NPC」那一档")
	## 已完成那一行的怪名要转去交付 NPC（`QuestTrackerItemRenderer.as:193-201`）
	_断言(HUD.contains('body.set_meta("done", 完成)'), "追踪行没把「已完成」存进 meta ⇒ 点怪名分不出状态")
	var 点段 := _截段(HUD, "func _追踪链接点击", "func _到点开对话")
	_断言(点段.contains('get_meta("done")') and 点段.count("前往NPC(") == 2,
			"已完成的追踪行点怪名还往怪堆里钻（原版这时走去交付 NPC，实得 %d 处前往NPC）"
					% 点段.count("前往NPC("))
	_finish()

class _假会话:
	extends Node
	var game_settings := {}


## 截出 From 到 To 之间那一段源码（To 找不到就截到文件尾）。
func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _finish() -> void:
	if _失败.is_empty():
		print("任务提示链回归测试：通过（%d 条）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("任务提示链回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)

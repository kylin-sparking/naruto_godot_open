extends SceneTree

## #180 经验条实时（底栏 + 人物面板两处）的离线门。
##
## 用户 2026-10-10 原话：「修复角色经验值条不是实时跟随经验显示问题 和角色面板经验条不是实时显示问题」。
##
## 真值（2.2.3优化版反编译）：
##   * `DataCenter.as:2434-2446` 收到 `CocoStatType.EXP` 那一号时
##     `_loc5_ = ExpTable.getExpNeededForLevel(this.stats.level)` + `menuPane.setEXP(值, _loc5_)`；
##   * `DataCenter.as:1462` 构建人物窗口数据时同样现算 `maxExp = ExpTable.getExpNeededForLevel(level)`；
##   * `CharPane.as:240` `expBar.setData(experience, maxExp)`；`MenuPane.as:357-359` `setEXP → expBar.setData`。
##   ⇒ **分母从来不是服务端属性**，属性包里没有"升级所需经验"这一号，客户端必须自己查表。
##
## 修前的实测（`开发工具/_探针经验条.gd`）：喂 `{level:7, exp:300}` 之后 `max_exp` 仍是离线示例数据
## 那个 100 ⇒ `exp/max_exp` 恒被 clamp 到 1.0 ⇒ 两根条永远满格、百分比永远 100%，
## 经验再怎么涨都不动 —— 正是玩家看到的"不实时跟随"。
##
## 五条腿：① 表本体（生成器产物的形状与抽样值）② 在线落地（真调 `apply_backend_character`）
## ③ 离线升级（`_apply_level_ups` 也查同一张表，并钉死自造的 `*1.25` 不许回来）
## ④ 接线判据（底栏与人物面板那两处确实拿 `max_exp` 当分母、且都挂在 `player_stats_changed` 上）
## ⑤ 门不许动存档。
##
## 跑法：Godot --headless --path . --script res://测试/经验条实时回归测试.gd

const 表脚本 := preload("res://脚本/单例/等级经验表.gd")
const 出 := "res://测试/截图/经验条实时.txt"
const 存档 := "user://玩家数据.json"
const 设置档 := "user://玩家设置.json"
const 底栏源 := "res://脚本/界面/技能面板.gd"
const 面板源 := "res://脚本/界面/窗口/人物窗口.gd"
const 同步源 := "res://脚本/单例/服务端会话同步.gd"
const 会话源 := "res://脚本/单例/游戏会话.gd"
const 宿主源 := "res://脚本/界面/功能窗口.gd"

## 抽样真值：等级 → 本级所需，**从 `ExpTable.as` 现算出来的**（第一版我手抄错过两条：
## 把 表[11]=3114 当成 表[10]、把 表[44]=1276272 当成 表[50]，门当场报红 ⇒ 别再手抄）。
const 抽样 := {0: 0, 1: 20, 2: 84, 3: 190, 7: 1196, 8: 1602, 9: 2163, 10: 2595,
	11: 3114, 44: 1276272, 50: 4128502, 109: 42548881084, 120: 65502047576}

var 总 := 0
var 红 := 0
var 日志: Array[String] = []
var 存前 := PackedByteArray()
var 设前 := PackedByteArray()


func _记(过: bool, 说: String) -> void:
	总 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1


func _尾() -> void:
	日志.append("")
	日志.append("汇：判 %d 条 / 红 %d 条" % [总, 红])
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)


## ⚠ `PackedByteArray` 没有 `hash()`（这条门第一次就撞在自己身上）。
## 存档比对只要"变没变"，直接留整份字节做等值比较即可。
func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		var 空 := PackedByteArray([1])
		return 空
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _码(路: String) -> String:
	## 剥掉 `##`/`#` 注释行再比 —— 注释里会写 AS3 标识符与旧算式，拿原文 grep 会自证。
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return ""
	var 文 := g.get_buffer(g.get_length()).get_string_from_utf8()
	g.close()
	var 留: Array[String] = []
	for 行 in 文.split("\n"):
		var 头 := 行.lstrip("\t ")
		if 头.begins_with("#"):
			continue
		留.append(行)
	return "\n".join(留)


func _initialize() -> void:
	存前 = _字节(存档)
	设前 = _字节(设置档)
	_表腿()
	var 会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_记(false, "拿不到 GameSession 单例 ⇒ 后面三条腿全空谈")
		_尾()
		return
	_落地腿(会)
	_离线升级腿(会)
	_接线腿()
	_记(_字节(存档) == 存前, "门不许动存档（%s 字节要一致）" % 存档)
	_记(_字节(设置档) == 设前, "门不许动设置档（%s 字节要一致）" % 设置档)
	_尾()


func _表腿() -> void:
	var 表: Array = 表脚本.需要经验
	_记(表.size() == 表脚本.项数, "表项数与常量 项数 一致（%d）—— 生成器产物与常量不许各说各话" % 表.size())
	_记(表.size() == 121, "表 121 项（原版 ExpTable.as 的 exp 数组，索引 0..120）")
	_记(int(表[0]) == 0, "表[0] = 0")
	var 递增 := true
	for i in range(1, 表.size()):
		if int(表[i]) <= int(表[i - 1]):
			递增 = false
	_记(递增, "整表严格递增（升级所需经验必须一级比一级多）")
	for 级 in 抽样.keys():
		_记(int(表[级]) == int(抽样[级]), "表[%d] = %d（抽样真值），实际 %d" % [
				级, int(抽样[级]), int(表[级])])
	_记(表脚本.最高等级 == 表.size() - 1, "最高等级常量 = 项数-1（%d）" % 表脚本.最高等级)
	_记(表脚本.本级所需(7) == 1196, "本级所需(7) = 1196")
	_记(表脚本.本级所需(120) == int(表[120]), "本级所需(120) = 最后一档")
	_记(表脚本.本级所需(9999) == int(表[表.size() - 1]),
			"等级超范围回**最后一档**（原版 `ExpTable.as:16-18` 就是这个写法，不是我们兜底）")
	_记(表脚本.本级所需(-3) == 0, "负等级按 0 级看（回 0），不越界崩")


func _落地腿(会) -> void:
	会.apply_backend_character({"level": 7, "exp": 300.0, "maxHp": 5000})
	_记(int(会.player_stats.get("exp", -1)) == 300, "喂 {level:7,exp:300} ⇒ exp 落了 300")
	_记(int(会.player_stats.get("max_exp", -1)) == 1196,
			"同一包之后 max_exp = 表[7] = 1196（修前这里停在 100 ⇒ 条子恒满）")
	var 低 := _比例(会)
	_记(低 > 0.0 and 低 < 1.0, "300/1196 的比例落在 0..1 之间（实际 %.4f）—— 不再被 clamp 成 1.0" % 低)
	会.apply_backend_character({"exp": 900.0})
	var 高 := _比例(会)
	_记(int(会.player_stats.get("max_exp", -1)) == 1196, "只补 exp 不补等级 ⇒ 分母仍按当前等级 1196")
	_记(高 > 低, "经验从 300 涨到 900，条子比例跟着涨（%.4f → %.4f）—— 这就是「实时跟随」" % [低, 高])
	会.apply_backend_character({"level": 8, "exp": 40.0})
	_记(int(会.player_stats.get("max_exp", -1)) == 1602, "升到 8 级 ⇒ 分母换成 表[8] = 1602")
	_记(_比例(会) < 0.05, "升完级条子该回到低位（实际 %.4f）—— 不是继续顶满" % _比例(会))
	会.apply_backend_character({"level": 120, "exp": 1000.0})
	_记(int(会.player_stats.get("max_exp", -1)) == 65502047576,
			"最高等级 120 ⇒ 分母取最后一档 65502047576")
	会.apply_backend_character({"maxHp": 6000})
	_记(int(会.player_stats.get("max_exp", -1)) == 65502047576,
			"一包里没有 exp/level 时，分母按会话里的等级重算（不许回落到 100）")
	会.apply_backend_character({"level": 3, "exp": 0.0})
	_记(int(会.player_stats.get("max_exp", -1)) == 190, "0 经验时也有真分母（表[3]=190）")
	_记(_比例(会) == 0.0, "exp=0 ⇒ 比例为 0（空条），不是 1")


func _比例(会) -> float:
	var 分母 := maxf(1.0, float(会.player_stats.get("max_exp", 100)))
	return clampf(float(会.player_stats.get("exp", 0)) / 分母, 0.0, 1.0)


func _离线升级腿(会) -> void:
	会.set("backend_authoritative", false)
	会.player_stats["level"] = 7
	会.player_stats["exp"] = 1196
	会.player_stats["remaining_ap"] = 0
	会.player_stats["remaining_sp"] = 0
	会._apply_level_ups()
	_记(int(会.player_stats.level) == 8, "攒够 表[7]=1196 ⇒ 升到 8 级")
	_记(int(会.player_stats.exp) == 0, "升级把本级所需扣掉（余 0）")
	_记(int(会.player_stats.max_exp) == 1602, "升级后分母 = 表[8] = 1602")
	_记(int(会.player_stats.max_exp) != 1495,
			"分母**不是**自造的 1196*1.25=1495（那条等比递增是修前写法，不许回来）")
	_记(int(会.player_stats.remaining_ap) == 5 and int(会.player_stats.remaining_sp) == 1,
			"每级 +5 潜能 / +1 属性点（本门只钉形状没变，数值出处仍待查）")
	会.player_stats["level"] = 7
	会.player_stats["exp"] = 1196 + 1602
	会._apply_level_ups()
	_记(int(会.player_stats.level) == 9 and int(会.player_stats.exp) == 0,
			"一次给够两级 ⇒ 连升两级到 9 级、余 0（while 没被写成 if）")
	_记(int(会.player_stats.max_exp) == 2163, "9 级的分母 = 表[9] = 2163")
	会.player_stats["level"] = 7
	会.player_stats["exp"] = 1195
	会._apply_level_ups()
	_记(int(会.player_stats.level) == 7 and int(会.player_stats.exp) == 1195,
			"差 1 点不升级（阈值是 >= 而不是 >）")
	会._recalculate_stats(false)
	_记(int(会.player_stats.max_exp) == 1196, "非权威重算也把分母写回表（离线启动那一帧不停在 100）")


func _接线腿() -> void:
	var 底 := _码(底栏源)
	var 板 := _码(面板源)
	var 同 := _码(同步源)
	var 会 := _码(会话源)
	var 宿 := _码(宿主源)
	_记(底.contains("var maximum := maxf(1.0, float(stats.get(\"max_exp\", 100)))"),
			"底栏那根条的分母读 max_exp（技能面板._on_stats_changed）")
	_记(底.contains("var progress := clampf(float(stats.get(\"exp\", 0)) / maximum, 0.0, 1.0)"),
			"底栏那根条的分子读 exp")
	_记(底.contains("_session.player_stats_changed.connect(_on_stats_changed)"),
			"底栏挂在了 player_stats_changed 上（属性帧一到就重画）")
	_记(板.contains("var 经验上限 := maxf(1.0, float(属性.get(\"max_exp\", 100)))"),
			"人物面板经验条的分母读 max_exp")
	_记(板.contains("var 经验数 := float(属性.get(\"exp\", 0))"),
			"人物面板经验条的分子读 exp")
	_记(板.contains("进度条补间.灌值(经验条, 经验数, 经验上限,"),
			"人物面板经验条的填充走件（§3.243：0.5s 补间 + 同数据早退，不再直写 value）")
	_记(板.contains("经验数值.text = \"%d%%\""), "人物面板那行百分比还在")
	# 承 §3.247：2026-10-22 报修 3 把这一条从"直连 `_refresh_current`"改成了"直连 `_on_资源帧`"。
	# 语义没变（属性帧 ⇒ 人物页跟着刷），只是**停在修炼族子页时改走原地刷**（整页重绘会把玩家
	# 正开着的「突破瓶颈」弹窗拆了）。⇒ 判据从"连的是哪个函数"改成两条真判：
	#   ① 属性帧**有消费者**、且它确实会叫到 `_refresh_current`；② 这个消费者**也真的挂上了**。
	# ⚠ 这类"grep 源码字符串"的判据天生脆：改接线写法就红，红得没有信息量。要判行为请写行为腿
	#   （`手里剑修炼页回归测试.gd` 的 E/F 两条就是），这条留着只当"别把信号接丢"的最低闸。
	var 口 := 宿.find("func _on_资源帧() -> void:")
	_记(口 >= 0 and 宿.find("_refresh_current()", 口) > 0,
			"属性帧不再叫醒 `_refresh_current`（人物页经验条跟着刷这条路断了）")
	_记(宿.contains("_session.player_stats_changed.connect(_on_资源帧.unbind(1))"),
			"功能窗口没把属性帧接到 `_on_资源帧` 上（人物页不会跟着刷新）")
	_记(同.contains("会话.player_stats[\"max_exp\"] = 等级经验表.本级所需("),
			"权威落地处补分母（服务端会话同步.应用人物）")
	_记(同.find("会话.player_stats[\"max_exp\"]") < 同.find("会话.player_stats_changed.emit"),
			"补分母在 emit **之前** —— 在之后就晚了一帧，第一根条会拿旧分母画")
	_记(not 会.contains("* 1.25"), "游戏会话里那串自造的 `* 1.25` 升级公式已经没了")
	_记(会.contains("等级经验表.本级所需("), "游戏会话（离线那一路）也查同一张表")

extends SceneTree

## #181 的离线门：**放一个技能该报几只怪** + **当前选中的忍术**这个状态。
##
## 用户 2026-10-10 原话：「原版本中有一些技能是释放一次后再用鼠标点击敌人就会默认使用当前选中的忍术
## 并且忍术分为单体攻击和群体攻击 单体攻击只能攻击当前选中的那一只怪物」。
##
## 真值（2.2.3优化版，逐条到行号，全抄在 `脚本/角色/技能目标选择.gd` 文件头）：
##   `AbstractAttackSkill.as:598-637 hitTest()` 按 `SkillDataTool.getSkillTarget(id)` 分三档：
##     case 3 → 目标是 `API.player`（自身技）；case 1 → 只发 `targetHandler.curTarget`（单体）；
##     case 2 → **不带目标**（面积，服务端按范围结算）；
##   `SkillDataTool.as:177-181` `getSkillTarget = skillData.info.desc.target` ⇒ 本工程 `数据/技能.json` 的 `target`；
##   `AbstractAttackSkill.as:388-404 canReachTarget()` 用**该技能的命中盒**压目标体型盒，当前朝向压不到再按反方向试一次；
##   `TargetHandler.as:128-147 setDefaultSkill` = "当前选中的忍术"；`SkillExecute.as:205` 再点同一枚且在追打 ⇒ return。
##
## 六条腿：① 目标选择纯函数 ② 够得着纯函数 ③ 会话里的"当前选中的忍术" ④ 数据表现查（含分布计数）
## ⑤ 接线判据（源码钉：三处落点各在什么位置、谁不许回来） ⑥ 门不许动存档。
##
## 跑法：Godot --headless --path . --script res://测试/技能目标与选中忍术回归测试.gd

const 选择 := preload("res://脚本/角色/技能目标选择.gd")
const 出 := "res://测试/截图/技能目标与选中忍术.txt"
const 玩家源 := "res://脚本/角色/玩家.gd"
const 面板源 := "res://脚本/界面/技能面板.gd"
const 会话源 := "res://脚本/单例/游戏会话.gd"
const 技能表 := "res://数据/技能.json"
const 存档 := "user://玩家数据.json"
const 设置档 := "user://玩家设置.json"

## 抽样真值：`数据/技能.json` 现查（导出自 GameData 的 `info.desc.target`）
const 抽样 := {"1001001": 1, "1001002": 1, "1001003": 2, "0003001": 2,
	"0003000": 3, "0003004": 3, "0003006": 3, "0003007": 3}
## 全表分布（156 条）—— 这条钉的是**导出器没漂**，漂了这里必红
const 分布 := {0: 56, 1: 46, 2: 32, 3: 22}

var 判 := 0
var 红 := 0
var 日志: Array[String] = []
var 存前 := PackedByteArray()
var 设前 := PackedByteArray()


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _尾() -> void:
	_写()
	日志.append("汇：判 %d 条 / 红 %d 条" % [判, 红])
	_写()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _净码(路: String) -> String:
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return ""
	var 文 := g.get_buffer(g.get_length()).get_string_from_utf8()
	g.close()
	var 留: Array[String] = []
	for 行 in 文.split("\n"):
		if 行.lstrip("\t ").begins_with("#"):
			continue
		留.append(行)
	return "\n".join(留)


func _initialize() -> void:
	call_deferred("_开跑")


## ⚠ 自动加载的 `_ready()` 跑在 `_initialize()` **之后**（同一轮实测：直接读 `player_stats`
## 拿到的是 `离线示例数据` 的白板值、快捷栏是空的）。要先隔几帧，否则这条门量的是"还没初始化"。
func _开跑() -> void:
	for i in 6:
		await process_frame
	_跑()


func _跑() -> void:
	存前 = _字节(存档)
	设前 = _字节(设置档)
	_目标腿()
	_够得着腿()
	_会话腿()
	_数据腿()
	_接线腿()
	_接线补腿()
	_判(_字节(存档) == 存前, "门不许动存档（%s 字节一致）" % 存档)
	_判(_字节(设置档) == 设前, "门不许动设置档（%s 字节一致）" % 设置档)
	_尾()


func _怪(名: String) -> Node2D:
	var 节 := Node2D.new()
	节.name = 名
	return 节


func _目标腿() -> void:
	var 甲 := _怪("甲")
	var 乙 := _怪("乙")
	var 丙 := _怪("丙")
	var 框: Array = [甲, 乙, 丙]
	_判(选择.目标(1, 框, 乙) == [乙],
			"单体（target=1）只报**选中的那一只**，框到三只也只报一只 —— 用户点名的缺陷")
	_判(选择.目标(1, 框, null).is_empty(), "单体没选中 ⇒ 不报任何怪（调用方因此不放这一发）")
	var 面 := 选择.目标(2, 框, 乙)
	_判(面.size() == 3 and 面.has(甲) and 面.has(乙) and 面.has(丙), "面积（target=2）报命中盒框到的全部")
	面.append(_怪("丁"))
	_判(框.size() == 3, "返回值是副本 ⇒ 调用方改它不会污染传进来的框到的列表")
	_判(选择.目标(3, 框, 乙).is_empty(), "自身技（target=3：隐身/瞬移/加血单体…）不报怪")
	_判(选择.目标(0, 框, 乙).is_empty(), "target=0（被动/生活技那 56 条）⇒ 一律空，不猜成单体")
	_判(选择.目标(7, 框, 乙).is_empty(), "表里没见过的档位 ⇒ 空（走不到原版那个 switch 的任何 case）")
	var 死 := _怪("要删的")
	死.free()
	# ⚠ 这里原来有一条 `选择.目标(1, 框, 死)`（"选中的怪被释放 ⇒ 不报"）—— **那条永远没计过数**：
	#   失效引用根本过不了带类型的形参，在**调用处**就抛
	#   `Invalid type in function '目标' in base 'GDScript'. The Object-derived class of argument 3
	#   (previously freed) …` 并当场打断本函数（§3.245，全量日志 grep 出来的）。
	#   而这个场景在**真链路上取不到**：`地图实体.gd:1876` 的 `get_selected_enemy()` 自己判了
	#   `is_instance_valid`，怪一死就回 null ⇒ 上面第 130 行那条（`目标(1, 框, null)`）就是它的等价判据。
	#   别再把 freed 对象往带类型形参里塞 —— 那只会得到一条"抛错但门照样绿"的死腿。
	甲.free(); 乙.free(); 丙.free()


func _够得着腿() -> void:
	var 甲 := _怪("甲2")
	var 乙 := _怪("乙2")
	_判(选择.够得着(1, [甲], 甲, []), "本方向命中盒压到了 ⇒ 够得着（原版 `canReachTarget` 第一次判）")
	_判(选择.够得着(1, [甲], 乙, [乙]),
			"本方向压不到、**反方向压得到**也算 —— 原版 `:399-401` 会拿反方向再试一次")
	_判(not 选择.够得着(1, [甲], 乙, [甲]), "两个方向都压不到 ⇒ 不够得着（于是先去寻路靠近）")
	_判(选择.够得着(2, [甲, 乙], 乙, []), "面积技同样按「这个技能的命中盒」判，不是按固定半径")
	_判(选择.够得着(3, [], null, []), "自身技没有「够不够得着」这一说 ⇒ 直接可放")
	_判(not 选择.够得着(1, [甲], null, [甲]), "没有选中怪 ⇒ 判不够得着（单体技因此不会原地空放）")
	甲.free(); 乙.free()


func _会话腿() -> void:
	var 会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "缺 GameSession 单例 ⇒ 这一腿空谈")
		return
	_判(int(会.get("默认忍术")) == 0, "开局没有「选中的忍术」（原版 defaultSkill 初值 0）")
	_判(int(会.call("默认忍术槽")) == -1, "没选中时槽位回 -1")
	if 会.skill_slots.is_empty():
		_判(false, "快捷栏是空的 ⇒ 换绑那几条判不了")
		return
	var 槽0: Dictionary = 会.skill_slots[0]
	if String(槽0.get("id", "")).is_empty():
		_判(false, "第 0 格没技能 ⇒ 量具环境不对（离线示例数据该有技能）")
		return
	var 编号 := int(String(槽0.get("id", "")))
	会.call("设默认忍术", 编号)
	_判(int(会.get("默认忍术")) == 编号, "设默认忍术(%d) 存的是**技能编号**（原版 defaultSkill 也存编号）" % 编号)
	_判(int(会.call("默认忍术槽")) == 0, "选中第 0 格之后，按编号能反查回槽 0（冷却是按槽位算的）")
	会.call("设默认忍术", 9999999)
	_判(int(会.call("默认忍术槽")) == -1, "选中的编号不在栏里 ⇒ 槽回 -1（不拿错槽的冷却/等级放招）")
	会.call("设默认忍术", 0)
	_判(int(会.call("默认忍术槽")) == -1, "清 0 之后回 -1")


func _数据腿() -> void:
	var g := FileAccess.open(技能表, FileAccess.READ)
	if g == null:
		_判(false, "读不到 %s ⇒ 数据腿全空谈" % 技能表)
		return
	var 文 := g.get_buffer(g.get_length()).get_string_from_utf8()
	g.close()
	var 解 = JSON.parse_string(文)
	if not (解 is Dictionary):
		_判(false, "技能.json 解不出字典")
		return
	var 表: Dictionary = 解.get("skills", 解)
	_判(表.size() == 156, "技能表 156 条（现查），实际 %d" % 表.size())
	for 号 in 抽样.keys():
		if not 表.has(号):
			_判(false, "技能表里查不到 %s（抽样真值要有它）" % 号)
			continue
		_判(int((表[号] as Dictionary).get("target", -1)) == int(抽样[号]),
				"%s「%s」target=%s（原版 info.desc.target）" % [号,
						String((表[号] as Dictionary).get("name", "?")),
						str((表[号] as Dictionary).get("target", "?"))])
	var 计 := {}
	for 号 in 表.keys():
		var 档 := int((表[号] as Dictionary).get("target", -1))
		计[档] = int(计.get(档, 0)) + 1
	_判(计 == 分布, "target 分布 = %s（现查值），实际 %s —— 这条红说明导出器漂了" % [
			str(分布), str(计)])


func _接线腿() -> void:
	var 玩 := _净码(玩家源)
	var 板 := _净码(面板源)
	var 会 := _净码(会话源)
	_判(玩.contains("技能目标选择.目标(档, enemies, 选中)"),
			"施法的目标集合走那张 switch（玩家.use_skill_slot）")
	_判(玩.find("if 档 == 1 and 选中 == null:") < 玩.find("if not GameSession.use_skill(slot):"),
			"单体没选中就**在扣蓝/起冷却之前**返回 —— 反过来就是「白转一次冷却」")
	_判(玩.contains("var 槽 := GameSession.默认忍术槽()"),
			"追打循环里读「当前选中的忍术」（玩家._冲选中目标）")
	_判(玩.contains("use_skill_slot(槽)"), "够得着就放选中的那一枚，不是放普攻")
	_判(玩.contains("func 技能够得着(技号: String, 档: int, 目标: Node2D) -> bool:"),
			"够不够得着按**该技能命中盒 + 反方向再试一次**（原版 canReachTarget）")
	_判(not 玩.contains("显示目标框\", enemies[0]"),
			"反向判据：施法**不许**自己改选目标（原来那句「拿框到的第一只当选中」已删）")
	_判(板.contains("_session.call(\"设默认忍术\", 编号)"), "点快捷格 = 选中这枚（技能面板._use_skill）")
	_判(板.contains("if int(_session.get(\"默认忍术\")) == 编号 and 在追打:"),
			"再点同一枚且正在追打 ⇒ 什么都不做（原版 SkillExecute:205）")
	_判(会.contains("var 默认忍术 := 0") and 会.contains("func 设默认忍术(编号: int)")
			and 会.contains("func 默认忍术槽() -> int"), "会话里那三件都在（状态 + 设 + 反查槽）")


## ⑤-b 自动锁目标与 TAB 切目标的接线判据。
## 行为门是直接调 `切换目标()` 的，量不到"TAB 这个键有没有接上"这一环 ⇒ 只能钉源码
## （工程规矩：这类"只是接线判据"要写明它判的是接线，不是行为）。
func _接线补腿() -> void:
	var 玩 := _净码(玩家源)
	_判(玩.contains("技能目标选择.盒内最近(框到, global_position)"),
			"按技能键 ⇒ 先锁命中盒里最近的一只（原版 `SkillExecute.as:420-436`）")
	# ⚠ 不能拿 `if 档 == 1 and 选中 == null:` 当右边界 —— 玩家.gd 里这一句出现**两次**
	# （第一次是"先试着自动锁、锁不到再早退"那一段的开头），`find()` 取到的就是它，
	# 于是算出来的顺序永远是"锁在早退之后"，这条会假红。右边界改用它后面那句扣蓝。
	_判(玩.find("盒内最近(框到") < 玩.find("if not GameSession.use_skill(slot):"),
			"自动锁目标写在扣蓝/起冷却**之前** —— 反过来等于锁完还是白放一次")
	## ⚠ 10-25 #352 之后这一句的字面变成 `最近(怪 + 人, global_position, _选中目标())`：
	## 候选表从"只有怪"扩成"怪 + 可打的玩家"，排除项也从 `_选中怪()` 换成 `_选中目标()`
	## （原版 `SkillHandler.switchTarget:1022-1098` 遍历的是 `getFlagObjList` 那张表，
	## **人和怪本来就在同一张表里**、用同一把尺取最近 ⇒ TAB 从来不是"只在怪里轮"）。
	## 这条钉的是接线（源码里确有这一句），行为那一半由上面的 `切换目标()` 判据负责。
	_判(玩.contains("func 切换目标() -> Node2D:")
			and 玩.contains("技能目标选择.最近(怪 + 人, global_position, _选中目标())"),
			"TAB 切目标 = 在「怪 + 可打的玩家」里排除当前目标后取最近"
			+ "（等价原版 getNearestLifeObj 的 pop 轮换；#352 起人也在候选表里）")
	_判(玩.contains('Input.is_action_just_pressed("switch_target")'),
			"TAB 的输入接线在（行为门直接调 切换目标()，量不到这一环）")
	var 键 := _净码("res://脚本/单例/快捷键.gd")
	_判(键.contains('"switch_target": [KEY_TAB]'),
			"键位走 快捷键 那张默认表（原版 KeyDef 的 Tab 是 canSet=true ⇒ 设置页能改键）")

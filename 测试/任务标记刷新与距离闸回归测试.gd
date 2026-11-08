extends SceneTree
## 用户 2026-10-09 实机连报三条，三条都在「跑一遍游戏才看得见」那一层：
##  1) 小地图上有金色感叹号的 NPC，场景里头顶没有，点一下才出现；接了任务头顶那枚不消失，
##     也要再点一下才刷新。
##  2) 点 NPC 不限距离 —— 隔半张图也直接弹对话；原版过远会先自动走过去，到跟前才弹。
##  3) 点任务（追踪栏那行绿字）没反应，不会接、也不会自己走过去。
##
## 三条根因（都查到行号级）：
##  1) 服务端推 513 只写进 后端.npc_quest_status 那张表，**没人发信号**；头顶那枚只有
##     「NPC 生成时」与「点过一次之后」两个计算时机 => 进图时状态包晚到、交付后重推，头顶都不动。
##     （小地图那边有 0.5 秒轮询兜着，所以只有头顶错 —— 与用户描述完全一致。）
##  2) _on_npc_input 直接 _open_dialog，没有原版的射程判据 NPC.as:111-114。
##  3) 在线那两条任务列表（444:3 / 444:4）**只带 id 与状态**，NPC 编号要按 id 从
##     数据/任务.json 的 npc = {"0":接取,"1":回复} 合并（原版 QuestTrackerItemRenderer.as:122-125
##     用的就是 quest.npcId）。以前只读运行期条目 => 编号 0 => _找NPC链接 拼出**空串**
##     => 那一行根本没有可点的东西，且不报错、不提示。
##
## 跑法：Godot --headless --path . --script res://测试/任务标记刷新与距离闸回归测试.gd
## 本门不写存档：改过的会话状态与两张表一律快照 + 还原 + 断言还原成功。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 世界脚本 := preload("res://脚本/地图/地图实体.gd")
const 默认地图 := "101010000"

var _红: Array[String] = []
var _总数 := 0


func _判(说明: String, 成立: bool) -> void:
	_总数 += 1
	if not 成立:
		_红.append(说明)


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _跑() -> void:
	var 打包 := 地图资源.playable_scene(默认地图) as PackedScene
	_判("地图场景加载得到", 打包 != null)
	if 打包 == null:
		_收()
		return
	change_scene_to_packed(打包)
	await _帧(14)
	var 场 := current_scene
	_判("current_scene 有值（运行期换图同一条路）", 场 != null)
	var 根: Node = null
	if 场 != null:
		根 = 场.get_node_or_null("LifeRoot")
	_判("LifeRoot 在", 根 != null)
	var 后端: Node = root.get_node_or_null("BackendConnection")
	var 会话: Node = root.get_node_or_null("GameSession")
	var 玩家: Node2D = get_first_node_in_group("player") as Node2D
	_判("两个单例与玩家都在", 后端 != null and 会话 != null and 玩家 != null)
	if 根 == null or 后端 == null or 会话 == null or 玩家 == null:
		_收()
		return
	var 枚: Array = []
	for 谁 in (根.get("_entities") as Array):
		if str((谁 as Node).get("kind")) == "n":
			枚.append(谁)
	_判("本图有 NPC 可测（实 %d 枚）" % 枚.size(), 枚.size() > 0)
	if 枚.is_empty():
		_收()
		return
	await _513腿(根, 后端, 会话, 枚[0] as Node2D)
	await _距离腿(根, 玩家, 枚[0] as Node2D)
	await _追踪腿(会话)
	_收()


func _513腿(根: Node, 后端: Node, 会话: Node, 目标: Node2D) -> void:
	var 模板号 := int(str(目标.get("entity_id")))
	var 本图: Dictionary = 后端.get("map_npcs")
	var 态表: Dictionary = 后端.get("npc_quest_status")
	var 本图备份: Dictionary = 本图.duplicate(true)
	var 认证原 = 后端.get("authenticated")
	var 对象号 := 0
	for k in 本图:
		var 条v: Variant = 本图[k]
		if 条v is Dictionary and int((条v as Dictionary).get("npc_id", -1)) == 模板号:
			对象号 = int(k)
			break
	if 对象号 == 0:
		对象号 = 777001
		本图[对象号] = {"npc_id": 模板号}
	后端.set("authenticated", true)
	态表.erase(对象号)
	根.call("_挂任务标记", 目标, 0)
	var 标记: Node = 目标.get_node_or_null("QuestMarker")
	_判("状态 0 时头顶不亮（节点可以留着，但必须不可见）", 标记 == null or not bool(标记.visible))
	var 次数 := [0]
	后端.npc_quest_status_updated.connect(func(_a, _b): 次数[0] += 1)
	后端.call("_handle_npc_quest_status_text", PackedStringArray(["513", str(对象号), "1"]))
	_判("收到一行 513 会发信号（实发 %d 次）—— 没这条信号头顶就永远不刷新" % 次数[0], 次数[0] == 1)
	_判("值确实进了表（实 %d）" % int(态表.get(对象号, -1)), int(态表.get(对象号, -1)) == 1)
	await _帧(2)
	标记 = 目标.get_node_or_null("QuestMarker")
	var 名 := "无节点"
	if 标记 != null:
		名 = str(标记.get("entry_name"))
	_判("513=可接 时头顶换成 QuestIcon_0（实 %s）" % 名,
			标记 != null and bool(标记.visible) and 名 == "QuestIcon_0")
	_判("头顶与小地图读的是同一个数（问会话就得 1）",
			int(会话.call("npc_quest_status", str(模板号))) == 1)
	次数[0] = 0
	后端.call("_handle_npc_quest_status_text", PackedStringArray(["513", str(对象号), "1"]))
	_判("同一行重推、值没变 时不再发信号（进图那批几十枚不该各全场重挂一次）", 次数[0] == 0)
	后端.call("_handle_npc_quest_status_text", PackedStringArray(["513", str(对象号), "0"]))
	await _帧(2)
	_判("513=无 时头顶藏掉（用户报的「接了任务感叹号不消失」就是这一路没人通知）",
			标记 != null and not bool(标记.visible))
	态表.erase(对象号)
	本图.clear()
	for k in 本图备份:
		本图[k] = 本图备份[k]
	后端.set("authenticated", 认证原)
	_判("两张表都还原干净了", not 态表.has(对象号) and 本图 == 本图备份)


func _距离腿(根: Node, 玩家: Node2D, 演员: Node2D) -> void:
	_判("横距常数 == 100（NPC.as:113）", int(世界脚本.可对话横距) == 100)
	_判("纵距常数 == 50（同一行的 Math.abs(y) < 50）", int(世界脚本.可对话纵距) == 50)
	var 原 := 玩家.global_position
	var 基 := 演员.global_position
	玩家.global_position = 基
	_判("完全重叠能对话", bool(根.call("_能对话", 演员)))
	玩家.global_position = Vector2(基.x + 99.0, 基.y)
	_判("横 99 能对话", bool(根.call("_能对话", 演员)))
	玩家.global_position = Vector2(基.x + 101.0, 基.y)
	_判("横 101 不能对话", not bool(根.call("_能对话", 演员)))
	玩家.global_position = Vector2(基.x, 基.y + 49.0)
	_判("纵 49 能对话", bool(根.call("_能对话", 演员)))
	## 这一条专门打死 distance_to() < 100 那种写法：(10,60) 的欧氏距离约 60.8 < 100，
	## 拿一个圆去判会误判成「能对话」；原版两轴分别判，纵 60 已经出圈。
	玩家.global_position = Vector2(基.x + 10.0, 基.y + 60.0)
	_判("横 10 纵 60 不能对话（欧氏距离会把这一格误判进来）",
			not bool(根.call("_能对话", 演员)))
	玩家.global_position = 原
	_判("点 NPC 的回调里确实分了远近两支（源码判据）",
			_源码含("脚本/地图/地图实体.gd", "if _能对话(actor):"))
	_判("远处那一支交给「走到跟前自动开对话」而不是当场弹（源码判据）",
			_源码含("脚本/地图/地图实体.gd", "_走过去找NPC(actor, npc_id)"))
	_判("NPC 的点击拾取仍连着这个回调（漏了这条整块都点不动）",
			_源码含("脚本/地图/地图实体.gd", "input_event.connect(_on_npc_input"))
	_点击腿(根, 玩家, 演员)


## 远处点一下 NPC：**对话不该弹，人该开始走**（走到跟前由 `_待对话NPC` 兑现）。
## 直接调点击回调 = 走的是 Area2D `input_event` 那条真路径上的同一个函数；
## 判据不看"我确实调过"，看运行期结果：窗口的 visible 与玩家的 click_move_active。
func _点击腿(根: Node, 玩家: Node2D, 演员: Node2D) -> void:
	var 原 := 玩家.global_position
	var 基 := 演员.global_position
	var 窗: Node = null
	for 层 in root.get_children():
		窗 = 层.find_child("原版NPC对话窗", true, false)
		if 窗 != null:
			break
	玩家.global_position = Vector2(基.x + 400.0, 基.y)
	var 点 := InputEventMouseButton.new()
	点.button_index = MOUSE_BUTTON_LEFT
	点.pressed = true
	根.call("_on_npc_input", null, 点, 0, 演员, str(演员.get("entity_id")))
	var 开着 := false
	if 窗 != null:
		var 根控 = 窗.call("根")
		开着 = 根控 != null and bool(根控.visible)
	_判("远处点 NPC 不当场弹对话（窗 visible=%s）" % 开着, not 开着)
	_判("远处点 NPC 人开始走（click_move_active）", bool(玩家.get("click_move_active")))
	玩家.global_position = Vector2(基.x + 10.0, 基.y + 4.0)
	根.call("_on_npc_input", null, 点, 0, 演员, str(演员.get("entity_id")))
	var 开着2 := false
	if 窗 != null:
		var 根控2 = 窗.call("根")
		开着2 = 根控2 != null and bool(根控2.visible)
	_判("近处点 NPC 当场弹对话（窗 visible=%s）" % 开着2, 开着2)
	玩家.global_position = 原


func _追踪腿(会话: Node) -> void:
	var HUD := _读("res://脚本/界面/小地图面板.gd")
	var 实体源 := _读("res://脚本/地图/地图实体.gd")
	var 板: Node = null
	for 层 in root.get_children():
		板 = 层.find_child("小地图面板", true, false)
		if 板 != null:
			break
	_判("HUD 面板找得到（追踪行由它建）", 板 != null)
	if 板 == null:
		return
	var 定义: Dictionary = 板.call("_读任务定义") as Dictionary
	_判("任务定义表读到了（%d 条）" % 定义.size(), 定义.size() > 100)
	var 号 := ""
	var 定: Dictionary = {}
	for k in 定义:
		var 条: Dictionary = 定义[k] as Dictionary
		var 表: Dictionary = 条.get("npc", {}) as Dictionary
		var n0 := int(表.get("0", 0))
		var n1 := int(表.get("1", 0))
		if n0 > 0 and n1 > 0 and n0 != n1:
			号 = String(k)
			定 = 条
			break
	_判("找到一条接取/回复 NPC 不同的任务来测（实 %s）" % 号, not 号.is_empty())
	if 号.is_empty():
		return
	var 接取 := int((定.get("npc", {}) as Dictionary).get("0", 0))
	var 回复 := int((定.get("npc", {}) as Dictionary).get("1", 0))
	## 在线那副形状：444:4 的条目就是 {"id":…, "completed":false}，没有 npc 键。
	var 未接 := {"id": 号, "completed": false}
	_判("未接行的编号回落到定义表 npc.0（实 %d 期望 %d）"
			% [int(板.call("_追踪接取NPC", 未接, 定)), 接取],
			int(板.call("_追踪接取NPC", 未接, 定)) == 接取)
	var 文 := String(板.call("_追踪正文源", 未接, false, false, 定))
	_判("未接行长得出可点的 NPC 链接（实得 %s）" % 文, 文.contains("<a href="))
	var 已完 := {"id": 号, "completed": true, "flash_status": 2}
	_判("已完成行的编号回落到定义表 npc.1（实 %d 期望 %d）"
			% [int(板.call("_追踪回复NPC", 已完, 定)), 回复],
			int(板.call("_追踪回复NPC", 已完, 定)) == 回复)
	var 文2 := String(板.call("_追踪正文源", 已完, true, true, 定))
	_判("已完成行也长得出链接（实得 %s）" % 文2, 文2.contains("<a href="))
	## 定义表里本来就是 0 的任务（如 1003 的 npc.0 = 0）=> 原版也不给链接，别硬凑。
	var 零号 := ""
	var 零定: Dictionary = {}
	for k in 定义:
		var 条2: Dictionary = 定义[k] as Dictionary
		if int((条2.get("npc", {}) as Dictionary).get("0", 0)) == 0:
			零号 = String(k)
			零定 = 条2
			break
	if not 零定.is_empty():
		var 文3 := String(板.call("_追踪正文源", {"id": 零号, "completed": false}, false, false, 零定))
		_判("npc.0 本来是 0 的任务（%s）不给链接，与原版一致（实得 %s）" % [零号, 文3],
				not 文3.contains("<a href="))
	## 接完任务自动赶路的前提：在线那副形状（条目里只有 id、没有 target_npc）
	## 也要报得出目标 —— 以前 `_任务目标NPC` 返回空串 ⇒ 静默不赶路。
	## 现在这条走的是原版算式 `_寻路目标`（`getQuestPoint`），1006 算出来是「去 NPC」那一档。
	var 备份: Array = []
	for d in 会话.accepted_quests:
		备份.append(d)
	会话.accepted_quests.clear()
	会话.accepted_quests.append({"id": 号, "completed": false})
	var 条目: Dictionary = 板.call("_接上的条目", int(号)) as Dictionary
	_判("从会话里取得到刚接上那条（实得 %s）" % str(条目), not 条目.is_empty())
	var 目: Array = 板.call("_寻路目标", 条目, 定) as Array
	_判("在线形状下算得出的目标是「去 NPC」且号 > 0（实得 %s）" % str(目),
			目.size() == 3 and int(目[0]) == 3 and int(目[1]) > 0)
	会话.accepted_quests.clear()
	for d in 备份:
		会话.accepted_quests.append(d)
	_判("会话任务列表还原了", 会话.accepted_quests.size() == 备份.size())
	## ⑥ 「走到跟前才开对话」的时机契约（10-10 用户实机连着两条）：
	##   ① 打断后凭空弹框 = 拿「路线停了」当「走到了」；
	##   ② 修完①又变成"人还没停框就出来" = 我改成"一进距离就弹"。
	## 原版触发条件是**路径关节走完**（`KeyController.as:212`），打断那一支（`:196-211`）不说话。
	## 本工程用 `玩家.auto_path_arrive_stamp`（只在最后一个关节推完时 +1）分开这两条；
	## **不许**再用「停 + 横100/纵50」的距离闸 —— 原版这条支路没有距离条件，而
	## 失落秋千（life y=431 / 脚下平台 482）纵差 51，照距离判永远差 1 像素（2026-10-26 实机卡住）。
	var 到点段 := ""
	var 换 := char(10)
	for 行 in HUD.split(换):
		if 行.strip_edges().begins_with("if not _待对话NPC.is_empty()"):
			到点段 = HUD.substr(HUD.find(行.strip_edges()), 900)
			break
	_判("取到 _待对话NPC 那段判据（取不到就是写法被改了）", 到点段.length() > 0)
	var 停位 := 到点段.find("click_move_active")
	var 印位 := 到点段.find("auto_path_arrive_stamp")
	_判("外层必须先判「路线停了」，否则就是人还在走就弹框，实得 %s"
			% 到点段.left(90).replace(换, " | "), 停位 >= 0)
	_判("停下来之后要用「走完印」兑现对话（否则打断与走完分不开 = 凭空弹框）", 印位 >= 0)
	_判("两把判据必须先是停、后是印（反过来就是把②写回去）停=%d 印=%d",
			停位 >= 0 and 印位 >= 0 and 停位 < 印位)
	_判("HUD 不许再拿距离当这条支路的闸（失落秋千纵差 51 会被卡住）",
			not HUD.contains("func _能走到对话") and not 到点段.contains("_能走到对话"))
	_判("闸口常数只认 地图实体 那一份 ⇒ HUD 里不许出现字面 100/50",
			实体源.contains("const 可对话横距 := 100.0") and 实体源.contains("const 可对话纵距 := 50.0")
			and not HUD.contains("absf(差.x) < 100"))




func _读(路: String) -> String:
	var f := FileAccess.open(路, FileAccess.READ)
	return String(f.get_as_text()) if f != null else ""


func _源码含(相对: String, 式: String) -> bool:
	var f := FileAccess.open("res://" + 相对, FileAccess.READ)
	if f == null:
		return false
	## GDScript 的 String 没有 search()（那是 JS 的习惯）⇒ 用 contains()。
	return String(f.get_as_text()).contains(式)


func _收() -> void:
	if _红.is_empty():
		print("任务标记刷新与距离闸回归测试：共 %d 条，红 0 条" % _总数)
		quit(0)
		return
	for 条 in _红:
		printerr("!! " + 条)
	print("任务标记刷新与距离闸回归测试：共 %d 条，红 %d 条" % [_总数, _红.size()])
	quit(1)

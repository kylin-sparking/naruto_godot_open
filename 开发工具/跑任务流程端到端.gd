extends SceneTree
## 真连本地服务端，把任务主流程从头走到尾并留一份可读日志。
##
## 用哪个号：**新注册的测试号 flow_test@example.com**，角色名「流程测试角色」。
##   不复用你正在玩的那个号 —— 同端口第二次登录会互相顶，而且会把服务端那侧的状态搅乱。
## 启动方式必须把 user:// 隔离开（两个工程同名 ⇒ 默认共用同一个存档目录），见本文件末尾的跑法。
##
## 跑法（服务端要先起着，游戏口 18684 / GM 口 18680）：
##   APPDATA=./_tmp/appdata-flow godot \
##     --path . --script res://开发工具/跑任务流程端到端.gd
## 日志写到隔离后的 `user://任务流程端到端.txt`。
const 账号 := "flow_test@example.com"
const 口令 := "123456"
const 角色名 := "流程测试角色"
const 日志路 := "user://任务流程端到端.txt"

var 行: Array[String] = []
var 后端: Node
var 会话: Node
var 失败 := 0


func _initialize() -> void:
	call_deferred("_跑")


func _记(说明: String, 通过 := true) -> void:
	行.append(("  通过 " if 通过 else "  未过 ") + 说明)
	print(行.back())
	if not 通过:
		失败 += 1


func _说(说明: String) -> void:
	行.append("       " + 说明)
	print(行.back())


func _等(条件: Callable, 秒: float) -> bool:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await process_frame
	return bool(条件.call())


func _跑() -> void:
	行.append("=== 任务流程端到端 " + Time.get_datetime_string_from_system() + " ===")
	后端 = root.get_node_or_null("BackendConnection")
	会话 = root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_记("两个单例都在", false)
		_收()
		return
	## 走**真实登录界面**那一条路（它自己处理选角、进图、建 HUD），不自己拼场景
	var 包 := load("res://场景/界面/登录界面.tscn") as PackedScene
	if 包 == null:
		_记("登录场景加载得到", false)
		_收()
		return
	change_scene_to_packed(包)
	await _等(func(): return current_scene != null, 6.0)
	会话.game_settings["backend_account"] = 账号
	会话.game_settings["backend_password"] = 口令
	_记("切到登录场景并写好测试账号（user:// 已用 APPDATA 隔离到临时目录）", current_scene != null)
	后端.sync_character()
	## ⚠ 顺序很重要：**先等「认证通过」，再处理角色**。空号是 `authenticated=true` 而
	## `in_game=false`（状态停在「正在读取角色」）—— 第一版在这里等 in_game，25 秒白等。
	if not await _等(func(): return bool(后端.authenticated), 25.0):
		_记("登录认证（状态 %s / %s）" % [后端.status, 后端.detail], false)
		_收()
		return
	_记("登录成功，账号 %s" % 账号)
	var 角色列: Array = 后端.characters
	_说("这个号已有角色 %d 个" % 角色列.size())
	if 角色列.is_empty():
		后端.create_character(角色名)
		if not await _等(func(): return (后端.characters as Array).size() > 0, 15.0):
			## 有的实现建完角要重新拉一次列表才拿得到
			后端.sync_character()
			await _等(func(): return bool(后端.authenticated), 20.0)
		角色列 = 后端.characters
		_说("建角后角色列表 %d 个" % 角色列.size())
	_记("角色列表非空（要能拿到编号去选角）", 角色列.size() > 0)
	if 角色列.is_empty():
		_收()
		return
	var 我: Dictionary = 角色列[0] as Dictionary
	## 字段名先打出来再说：服务端回的角色条目键名与客户端内部命名不一定一致，猜着取会拿到空串
	_说("角色条目原样：%s" % JSON.stringify(我))
	if int(后端.character_id) <= 0:
		后端.select_character(int(我.get("id", 0)))
	if not await _等(func(): return bool(后端.in_game), 30.0):
		_记("选角后进不了游戏（状态 %s / %s）" % [后端.status, 后端.detail], false)
		_收()
		return
	_记("角色就位：id=%d 名字=%s" % [int(后端.character_id), String(会话.player_stats.get("name", ""))])
	await _等(func(): return get_first_node_in_group("game_hud") != null, 25.0)
	var HUD := get_first_node_in_group("game_hud")
	_记("HUD 建出来了（追踪栏与小地图都挂在它身上）", HUD != null)
	if HUD == null:
		_收()
		return
	var 板: Node = HUD.find_child("小地图面板", true, false)
	_记("面板实例找得到", 板 != null)
	后端.request_quest_list()
	await _等(func(): return (会话.accepted_quests as Array).size() + (会话.available_quests as Array).size() > 0, 12.0)
	_说("服务端回的列表：已接 %d 条、可接 %d 条" % [(会话.accepted_quests as Array).size(),
			(会话.available_quests as Array).size()])
	for 条 in (会话.available_quests as Array).slice(0, 6):
		_说("  可接 id=%s 键=%s" % [str((条 as Dictionary).get("id", "")),
				str((条 as Dictionary).keys())])
	## ── 追踪栏那一行到底有没有可点的绿字（#152 的验收点）────────────
	await _等(func(): return (板.get("_quest_list") as Node).get_child_count() > 0, 8.0)
	var 列: Array = (板.get("_quest_list") as Node).get_children()
	_记("追踪栏有行（实 %d 行）" % 列.size(), 列.size() > 0)
	var 有链接 := false
	var 样本 := ""
	for 项 in 列:
		var 正文 = (项 as Node).find_child("RichTextLabel", true, false)
		if 正文 == null:
			continue
		样本 = String((正文 as RichTextLabel).text)
		if 样本.contains("href"):
			有链接 = true
			break
	_记("追踪栏里长得出可点的 NPC 链接（在线数据形状，条目本身没有 npc 键）", 有链接)
	_说("第一行文本片段：%s" % 样本.replace("\n", " ").substr(0, 120))
	## ── 点它：人要走过去，到跟前自动开对话 ────────────────────────
	var 定义: Dictionary = 板.call("_读任务定义") as Dictionary
	var 图内: Dictionary = 后端.map_npcs
	var 本图号: Array = []
	for k in 图内:
		本图号.append(int((图内[k] as Dictionary).get("npc_id", 0)))
	var 挑到的任务 := ""
	var 挑到的NPC := 0
	for 条 in (会话.available_quests as Array):
		var id := String((条 as Dictionary).get("id", ""))
		var 定: Dictionary = 定义.get(id, {}) as Dictionary
		var n0 := int((定.get("npc", {}) as Dictionary).get("0", 0))
		if n0 > 0 and 本图号.has(n0):
			挑到的任务 = id
			挑到的NPC = n0
			break
	_记("挑到一条「接取 NPC 就在本图」的可接任务：id=%s NPC=%d（本图 NPC %s）"
			% [挑到的任务, 挑到的NPC, str(本图号)], not 挑到的任务.is_empty())
	if 挑到的任务.is_empty():
		_收()
		return
	板.call("前往NPC", 挑到的NPC, true)
	var 玩家 = get_first_node_in_group("player")
	_记("点完就在走（click_move_active）", bool(玩家.get("click_move_active")))
	后端.last_npc_dialog = {}
	var 到了 := await _等(func(): return int((后端.last_npc_dialog as Dictionary).get("npc_id", 0)) == 挑到的NPC, 60.0)
	_记("走到跟前自动发了对话包并收到回帧（npc_id=%d）" % 挑到的NPC, 到了)
	_说("回帧内容片段：%s" % JSON.stringify(后端.last_npc_dialog).substr(0, 240))
	## ── 接受任务：57:1 → 服务端 42 → 进已接列表 → 标记跟着变 ───────
	var 状态前 = (后端.npc_quest_status as Dictionary).get(_找对象号(图内, 挑到的NPC), null)
	_记("接之前服务端说这枚 NPC 是「可接(1)」（实 %s）" % str(状态前), int(状态前) == 1)
	会话.call("accept_quest", 挑到的任务)
	if not await _等(_在已接.bind(挑到的任务), 15.0):
		_记("接受后进了已接列表（服务端没回 444:3？）", false)
		_收()
		return
	_记("接受成功：任务 %s 进了已接列表" % 挑到的任务)
	var 状态后 := -5
	var 止 := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < 止:
		状态后 = int((后端.npc_quest_status as Dictionary).get(_找对象号(图内, 挑到的NPC), -5))
		if 状态后 != int(状态前):
			break
		await process_frame
	_记("服务端重推了 513：这枚 NPC 的状态从 %s 变成 %d" % [str(状态前), 状态后], 状态后 != int(状态前))
	await _等(func(): return _头顶标记(图内, 挑到的NPC, 后端) != "查无", 6.0)
	var 头顶 := _头顶标记(图内, 挑到的NPC, 后端)
	var 期望头顶 := String(会话.call("任务标记特效", 状态后))
	_记("头顶那枚跟着换了：实得 %s，服务端状态 %d 对应 %s" % [头顶, 状态后, 期望头顶],
			头顶 == 期望头顶)
	var 画布: Node = 板.get("_minimap")
	var 组: Dictionary = 画布.get("组") as Dictionary
	var 小地图类 := ""
	for 条 in (组.get("npc", []) as Array):
		if int((条 as Dictionary).get("号", 0)) == 挑到的NPC:
			小地图类 = String((条 as Dictionary).get("类", ""))
	var 期望小地图 := String(画布.get("NPC态")[状态后]) if 画布.get("NPC态") != null else ""
	_记("小地图上同一枚的元件名 = %s（与头顶同一个状态，期望 %s）" % [小地图类, 期望小地图],
			小地图类 == 期望小地图)
	_收()


## 多行 lambda 塞进函数参数里在 GDScript 里很容易踩（解析边界），提成具名函数。
func _在已接(任务号: String) -> bool:
	for 条 in (会话.accepted_quests as Array):
		if String((条 as Dictionary).get("id", "")) == 任务号:
			return true
	return false


func _找对象号(图内: Dictionary, 模板号: int) -> int:
	for k in 图内:
		if int((图内[k] as Dictionary).get("npc_id", 0)) == 模板号:
			return int(k)
	return 0


func _头顶标记(图内: Dictionary, 模板号: int, 被: Node) -> String:
	var 对象号 := _找对象号(图内, 模板号)
	var 状态 := int((被.npc_quest_status as Dictionary).get(对象号, 0))
	var 场 := current_scene
	if 场 == null:
		return "无场景"
	var 根: Node = 场.get_node_or_null("LifeRoot")
	if 根 == null:
		return "无LifeRoot"
	for 谁 in (根.get("_entities") as Array):
		if str((谁 as Node).get("kind")) != "n":
			continue
		if int(str((谁 as Node).get("entity_id"))) != 模板号:
			continue
		var 记 := (谁 as Node).get_node_or_null("QuestMarker")
		if 记 == null:
			return "无标记节点(状态%d)" % 状态
		return String(记.get("entry_name"))
	return "查无该NPC"


func _收() -> void:
	行.append("结论：未过 %d 条" % 失败)
	print(行.back())
	var f := FileAccess.open(日志路, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
	quit(0 if 失败 == 0 else 1)

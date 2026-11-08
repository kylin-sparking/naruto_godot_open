extends SceneTree
## 在线量 513：**站在服务端那边看它到底给每枚 NPC 推了什么状态**，
## 再和"按原版枚举该是什么"对一遍。
##
## 原版枚举（`com/mxw/data/enums/NpcQuestStatus.as`）：
##   NONE=0  QUEST_CAN_START=1  QUEST_CAN_COMPLETE=2  QUEST_IN_PROGRESS=3
## 图标（`NPCQuestPopup.as:19-29`）：1→QuestIcon_0（黄"!"）2→QuestIcon_2（黄"?"）3→QuestIcon_1（灰"?"）
##
## 跑法（要一份隔离服务端，别顶掉用户自己连的那条）：
##   python 开发工具/本地服务端夹具.py --root .fixture-513 --gm-http 18691 --port 18690
##   APPDATA=./_tmp/appdata513 godot --headless --path . --script res://开发工具/查在线513.gd -- --port=18690

const 出 = "res://测试/截图/在线513.txt"

var 行: Array[String] = []
var _b: Node
var _s: Node
var _收帧 := 0
var _等级前 := {}
var _等级后 := {}


func _log(s: String) -> void:
	行.append(s)


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()


func _等(pred: Callable, 毫秒 := 12000) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if bool(pred.call()):
			return true
		await create_timer(0.05).timeout
	return false


func _initialize() -> void:
	call_deferred("_run")


func _端口() -> int:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--port="):
			return int(String(a).substr(7))
	return 18690


func _run() -> void:
	_b = root.get_node_or_null("BackendConnection")
	_s = root.get_node_or_null("GameSession")
	if _b == null or _s == null:
		_写(); quit(1); return
	var 设置: Dictionary = _s.get("game_settings")
	设置["backend_port"] = _端口()
	设置["backend_account"] = "a33047518511@gmail.com"
	设置["backend_password"] = "123456"
	_b.quest_progress_received.connect(func(_x: Dictionary): _收帧 += 1)
	_b.sync_character()
	if not await _等(func(): return bool(_b.get("in_game"))):
		_log("没进游戏：%s - %s" % [str(_b.get("status")), str(_b.get("detail"))])
		_写(); quit(1); return
	await _等(func(): return (_b.get("map_npcs") as Dictionary).size() > 0, 8000)
	await create_timer(1.2).timeout
	var 表: Dictionary = _b.get("npc_quest_status")
	_log("进图 图号=%s 等级=%s 本图NPC=%d 条  513表=%d 条" % [
		str(_b.get("authoritative_map_id")),
		str((_b.get("authoritative_stats") as Dictionary).get("level", "?")),
		(_b.get("map_npcs") as Dictionary).size(), 表.size()])
	for 号 in (_b.get("map_npcs") as Dictionary).keys():
		var 状: Dictionary = (_b.get("map_npcs") as Dictionary)[号] as Dictionary
		var 模 := int(状.get("npc_id", 0))
		var 态 := int(表.get(int(号), -1))
		_等级前[str(模)] = 态
		_log("  NPC 模板%08d object=%s 状态=%s -> %s" % [模, str(号), 态, _图标名(态)])
	_log("汇总（模板→状态）= %s" % JSON.stringify(_等级前))
	# 换到木叶村再打一遍：那图上有 8 枚 NPC 发**无前置**任务（门槛 10~55 级），
	# 是"达到等级就该亮黄感叹号"最集中的一张图。
	var 图前 := int(_b.get("authoritative_map_id"))
	_b.call("request_map_change", 100000000, 0, 0)
	if not await _等(func(): return int(_b.get("authoritative_map_id")) == 100000000, 12000):
		_log("换不到木叶村（本图 %s 没有直达门）⇒ 只量了开局那张图" % 图前)
	else:
		await create_timer(1.5).timeout
		var 表2: Dictionary = _b.get("npc_quest_status")
		var 亮 := 0
		_log("")
		_log("=== 木叶村 100000000：NPC %d 条 / 513 表 %d 条 ===" % [
			(_b.get("map_npcs") as Dictionary).size(), 表2.size()])
		for 号 in (_b.get("map_npcs") as Dictionary).keys():
			var 状: Dictionary = (_b.get("map_npcs") as Dictionary)[号] as Dictionary
			var 模 := int(状.get("npc_id", 0))
			var 态 := int(表2.get(int(号), -1))
			if 态 == 1:
				亮 += 1
			_等级后[str(模)] = 态
			_log("  NPC %08d 状态=%s -> %s" % [模, 态, _图标名(态)])
		_log("木叶村亮黄感叹号的 NPC 枚数 = %d" % 亮)
		_log("汇总 = %s" % JSON.stringify(_等级后))
		# **画没画**：直接看每枚 NPC 节点上那枚标记子节点在不在、挂的是哪个特效。
		# 513 到了 ≠ 头顶亮了 —— 进图那一瞬服务端是**先推 513 再建实体**的话，
		# 建实体时读表能补上，但只有"值变了"才会再触发一次刷新。
		var 生怪根 := (root.get_node_or_null("地图_101010000_烘焙")
				or root.get_child(root.get_child_count() - 1))
		var 场 := current_scene
		var 根2 = 场.get_node_or_null("LifeRoot") if 场 != null else null
		if 根2 == null:
			_log("!! 找不到 LifeRoot，画没画这一项未验")
		else:
			var 漏画 := 0
			for e in (根2.get("_entities") as Array):
				var 谁 := e as Node2D
				if 谁 == null or str(谁.get("kind")) != "n":
					continue
				var 模 := int(str(谁.get("entity_id")))
				var 态 := int(表2.get(int(str(谁.get("object_id"))), -1)) if 谁.has_method("get") and 谁.get("object_id") != null else int(表2.get(-1, -1))
				var 该亮 := 态 == 1 or 态 == 2 or 态 == 3
				var 标记 = 谁.get_node_or_null("QuestMarker")
				var 挂的 := String(标记.get("entry_name")) if 标记 != null else ""
				if 该亮 and (标记 == null or not 标记.visible):
					漏画 += 1
				_log("  NPC %08d 态=%s 标记节点=%s entry=%s visible=%s ⇒ %s" % [
					模, 态, str(标记 != null), 挂的,
					str(标记.visible) if 标记 != null else "-",
					"该亮" if 该亮 else "该灭"])
			_log("该亮却没画上的枚数 = %d" % 漏画)
	_写()
	_b.call("disconnect_backend")
	await create_timer(0.4).timeout
	quit(0)


func _图标名(态: int) -> String:
	match 态:
		0: return "无标记"
		1: return "黄感叹号(可接)"
		2: return "黄问号(可交付)"
		3: return "灰问号(进行中)"
	return "没推过"

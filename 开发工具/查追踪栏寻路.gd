extends SceneTree
## 一次问清：**全 214 条任务**在追踪栏里各自建成什么链接、计数长什么样。
## 不喂会话（`accepted_quests` 是派生视图，set 不进去），直接调渲染函数本身。
## 跑法：Godot --headless --path . --script res://开发工具/查追踪栏寻路.gd

const 出 = "res://测试/截图/追踪栏寻路探针.txt"

var 行 := []
var 面板: Node


func _log(s: String) -> void:
	行.append(s)


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("
".join(行) + "
")
		f.close()


func _initialize() -> void:
	_跑()


func _跑() -> void:
	面板 = Node.new()
	面板.set_script(load("res://脚本/界面/小地图面板.gd"))
	var 表: Dictionary = 面板.call("_读任务定义")
	_log("任务定义表条数 = %d" % 表.size())
	var 类 = {}
	var 无定义 = []
	var 无链接 = []
	var 有计数 = 0
	var 怪链 = 0
	var NPC链 = 0
	for id in 表.keys():
		var 定: Dictionary = 表[id] as Dictionary
		var 条 := {"id": id, "progress": 0, "required": 3}
		var 源 := String(面板.call("_追踪正文源", 条, true, false, 定))
		var 指 := String(面板.call("_指标符", 定, 条))
		if 指.contains("event:mob"):
			怪链 += 1
		if 指.contains("event:npc"):
			NPC链 += 1
		if 指.contains("（"):
			有计数 += 1
		if 指.is_empty():
			无链接.append(id)
		类[指.split("：")[0] if 指.length() > 0 else "(空)"] = int(类.get(指.split("：")[0] if 指.length() > 0 else "(空)", 0)) + 1
	_log("mob 链接建出来的条数 = %d / npc 链接 = %d / 带（x/y）计数的 = %d" % [怪链, NPC链, 有计数])
	_log("指标符完全空白的条数 = %d" % 无链接.size())
	_log("  空白清单 = %s" % ", ".join(无链接))
	_log("")
	_log("=== 抽三条看原文 ===")
	for id in ["1018", "1030", "1024", "1003", "1006"]:
		var 定: Dictionary = 表.get(id, {}) as Dictionary
		_log("[%s] 定义有无=%s" % [id, str(not 定.is_empty())])
		_log("   指标符 = %s" % String(面板.call("_指标符", 定, {"id": id, "progress": 1, "required": 3})).replace("
", " ⏎ "))
		_log("   正文源 = %s" % String(面板.call("_追踪正文源", {"id": id, "progress": 1, "required": 3}, true, false, 定)).replace("
", " ⏎ "))
		_log("   接取NPC=%s 回复NPC=%s" % [str(面板.call("_追踪接取NPC", {"id": id}, 定)), str(面板.call("_追踪回复NPC", {"id": id}, 定))])
	_写()
	quit(0)

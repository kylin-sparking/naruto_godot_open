extends SceneTree
## 量「服务端属性帧 → 会话 player_stats」这一跳（2026-10-17 查"信息条算师徒档用的我方等级=1"）。
## 做法 = 把真帧原文喂进 `_handle_bridge_text`（在线门同款口径），不连服务端。
## ⚠ **只诊断、不当门**（打印两行数，不判红、退出码恒 0）。两条结论已写进 `真值/窗口/目标信息条.md` §⑭：
##   ① 必须 `call_deferred` 后再喂 —— 在 `_initialize()` 里**同步**调，`is_inside_tree()` 还是 false，
##      `后端连接` 里那些 `get_node_or_null("/root/GameSession")` 全部拿到 null ⇒ 属性落不了地，
##      看着像产品坏了，其实是量具没进树；
##   ② 最后那句「直喂会话」是**阳性对照**：绕过后端那一跳直接叫 `apply_backend_character`，
##      它要是也不变，坏的才是同步本体。

func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 后: Node = (load("res://脚本/单例/后端连接.gd") as GDScript).new()
	root.add_child(后)
	var 会: Node = root.get_node_or_null("GameSession")
	if 会 == null:
		printerr("没有 GameSession 单例")
		quit(1)
		return
	print("在树里=%s" % str(后.is_inside_tree()))
	print("跑前 会话.level=%d" % int((会.get("player_stats") as Dictionary).get("level", -1)))
	后.call("_handle_bridge_text", "34:4&100@25&300@13&5000@14&2500")
	print("authoritative_stats = %s" % str(后.get("authoritative_stats")))
	print("喂帧后 会话.level=%d 会话.exp=%s 会话.max_hp=%d" % [
		int((会.get("player_stats") as Dictionary).get("level", -1)),
		str((会.get("player_stats") as Dictionary).get("exp", -1)),
		int((会.get("player_stats") as Dictionary).get("max_hp", -1))])
	## 阳性对照：绕过后端那一跳、直接叫会话的应用函数。这一句如果不灵，坏的是同步本体不是取单例。
	会.call("apply_backend_character", 后.get("authoritative_stats"))
	print("直喂会话后 会话.level=%d 会话.exp=%s 会话.max_hp=%d" % [
		int((会.get("player_stats") as Dictionary).get("level", -1)),
		str((会.get("player_stats") as Dictionary).get("exp", -1)),
		int((会.get("player_stats") as Dictionary).get("max_hp", -1))])
	quit(0)

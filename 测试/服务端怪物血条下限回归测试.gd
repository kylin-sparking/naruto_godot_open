extends SceneTree
## 门：**服务端怪物血量百分比活着时不得下发 0%**。
##
## 2026-10-26 实机 1342「终极艺术」卡死：2000020【精英】迪达拉还剩 3166/796646 = 0.4%，
## 服务端 `round()` 下发 0% ⇒ 客户端按原版 `MonsterHandler.showMobHp`（0% 即
## `beginPendingMonsterDeath`）当场判死、最后一刀再也发不出去 ⇒ 服务端收不到击杀
## ⇒ 任务永远 0/1。修法 = 活着至少 1%（ceil），0% 只留给真死。
##
## 两条腿：
##  * **行为腿**：真 import 项目内服务端模块，构造 `MonsterState` 调 `_monster_hp_percent`
##    验边界（0.4%→1、1 血→1、0→0、满→100、刚好过 50%→51）。跑的是 Python 真函数，不是抄公式。
##  * **契约腿**：客户端 `战斗角色.apply_server_hp_percent` 必须仍然「百分比 <= 0 ⇒ 死」。
##    服务端下限的前提就是这一条；哪天客户端改成「KILL 包才死」，这道门要一起重写。

func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 失败: Array[String] = []
	var 根 := ProjectSettings.globalize_path("res://")
	var 脚本 := 根.path_join("开发工具/验服务端血条下限.py")
	if not FileAccess.file_exists(脚本):
		失败.append("缺 开发工具/验服务端血条下限.py")
	else:
		var 输出: Array = []
		var 码 := OS.execute("python", PackedStringArray([脚本]), 输出, true)
		for 行 in 输出:
			print(String(行))
		if 码 != 0:
			失败.append("验服务端血条下限.py 退出码 %d（期望 0）" % 码)
		var 文 := "\n".join(PackedStringArray(输出))
		if not 文.contains("RESULT PASS"):
			失败.append("Python 校验没打印 RESULT PASS")
		if 文.contains("BAD "):
			失败.append("Python 校验出现了 BAD 行")
	var 客户 := FileAccess.get_file_as_string("res://脚本/角色/战斗角色.gd")
	if not (客户.contains("if 百分比 <= 0:") and 客户.contains("_服务端死亡()")):
		失败.append("客户端 apply_server_hp_percent 不再按 0% 判死 —— 服务端下限契约的前提变了")
	if 失败.is_empty():
		print("服务端怪物血条下限回归：通过（活着至少 1%、0% 才死）")
		quit(0)
		return
	for 项 in 失败:
		push_error("服务端血条下限：" + 项)
	quit(1)

extends SceneTree

## 验 `脚本/调试/镜头节拍记录.gd`（游戏本体里那个"抖不抖"记录器）本身靠不靠谱。
##
## 这条量具判的是**工具**，不是游戏：它必须
##   ① 作为自动加载真的挂上了（名字不对 = 静默不跑 = 玩家按 F6 什么也不会发生）；
##   ② `follow` 只在**读得到刷新率**时才改节拍 —— 无头模式 `screen_get_refresh_rate` 给 0，
##      拿 0 去设 `physics_ticks_per_second` 是灾难，所以这一条必须是"不改"；
##   ③ 缓存空的时候必须**打红**（不许"0 比 0"恒绿）；
##   ④ 录到的东西真能落成那几行直方图。
##
## 跑：Godot --path . --script res://开发工具/验镜头节拍记录器.gd
## ⚠ 会开一个窗口几秒；进图但不连服务端 ⇒ 不动存档（仍按字节快照 `user://玩家数据.json`）。

const 地图场景 := "res://场景/生成/地图_100000000_烘焙.tscn"
const 存档 := "user://玩家数据.json"
const 出文件 := "user://镜头节拍_实机_物理60.txt"

var 判数 := 0
var 红数 := 0
var 存前 := PackedByteArray()
var 存前在 := false


func _判(文: String, 对: bool) -> void:
	判数 += 1
	if not 对:
		红数 += 1
		print("!!红 " + 文)
	else:
		print("ok  " + 文)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _快照() -> void:
	存前在 = FileAccess.file_exists(存档)
	if 存前在:
		var g := FileAccess.open(存档, FileAccess.READ)
		存前 = g.get_buffer(g.get_length())


func _还原() -> void:
	if not 存前在:
		return
	var 现 := FileAccess.open(存档, FileAccess.READ)
	if 现.get_buffer(现.get_length()) == 存前:
		return
	var h := FileAccess.open(存档, FileAccess.WRITE)
	h.store_buffer(存前)
	print("存档已按字节还原")


func _initialize() -> void:
	_快照()
	跑()


func _取记录器(根: Window) -> Node:
	return 根.get_node_or_null("CamCadence")


func 跑() -> void:
	await _帧(3)
	var 记 := _取记录器(root)
	_判("自动加载挂上了（root/CamCadence）", 记 != null)
	if 记 == null:
		print("⇒ 后面全部照跑不了，先修 project.godot 的注册")
		_还原()
		quit(1)
		return
	## ② 节拍这一族（2026-10-23 起默认就自动跟屏 ⇒ 判据要覆盖"谁的屏跟谁的数"）
	##    探针命令行 = 带 `--script` 的那种进程（全工程的门与量具都走这一条）
	var 探命令行: PackedStringArray = PackedStringArray(["--path", ".", "--script", "res://x.gd"])
	var 玩命令行: PackedStringArray = PackedStringArray(["--maximized"])
	_判("_是探针 认得出 --script（这条判错 = 玩家的高刷屏会把整批门带跑）",
			bool(记.call("_是探针", 探命令行)))
	_判("_是探针 不误伤玩家启动（这条判错 = 跟屏永远不生效）",
			not bool(记.call("_是探针", 玩命令行)))
	_判("**本进程开机时没被跟屏改过节拍**（量具进程保持 60）",
			not bool(记.get("_改了节拍")) and Engine.get_physics_ticks_per_second() == 60)
	OS.set_environment("NARUTO_PHYSICS", "")
	Engine.set_physics_ticks_per_second(60)
	_判("默认 + 探针进程 ⇒ 不跟屏，保持 60",
			not bool(记.call("_上节拍", 100.0, 探命令行)) and Engine.get_physics_ticks_per_second() == 60)
	_判("默认 + 玩家进程 + 屏 100 ⇒ 跟到 100，且标记成自动（才允许换屏复查）",
			bool(记.call("_上节拍", 100.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 100
			and bool(记.get("_自动跟屏")))
	Engine.set_physics_ticks_per_second(60)
	_判("**260Hz 的人跟着 260 走**（用户问的那一条：不焊死在本机 100）",
			bool(记.call("_上节拍", 260.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 260)
	Engine.set_physics_ticks_per_second(60)
	_判("360Hz 在上限内 ⇒ 也跟",
			bool(记.call("_上节拍", 360.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 360)
	Engine.set_physics_ticks_per_second(60)
	_判("读不到刷新率（无头给 −1）⇒ 绝不设成 0，保持 60",
			not bool(记.call("_上节拍", -1.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 60)
	_判("400Hz 越界 ⇒ 宁可不跟",
			not bool(记.call("_上节拍", 400.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 60)
	OS.set_environment("NARUTO_PHYSICS", "off")
	_判("NARUTO_PHYSICS=off ⇒ 回到原版 60（想逐条对原版的人用这一条）",
			not bool(记.call("_上节拍", 100.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 60)
	OS.set_environment("NARUTO_PHYSICS", "144")
	_判("NARUTO_PHYSICS=144 ⇒ 设成 144，且**不许**被换屏复查顶掉",
			bool(记.call("_上节拍", 100.0, 玩命令行)) and Engine.get_physics_ticks_per_second() == 144
			and not bool(记.get("_自动跟屏")))
	OS.set_environment("NARUTO_PHYSICS", "follow")
	_判("follow ⇒ 连探针进程也强行跟（做对照实验用的后门）",
			bool(记.call("_上节拍", 120.0, 探命令行)) and Engine.get_physics_ticks_per_second() == 120)
	Engine.set_physics_ticks_per_second(60)
	OS.set_environment("NARUTO_PHYSICS", "")
	记.set("_自动跟屏", false)
	## ⑤ 左上角状态字：正常启动必须一帧都不显示（哪怕节拍已经跟了高刷屏）；
	##    加参数启动（环境变量 / --camlog）或 F6 开录才显示。用户 2026-10-23 的要求。
	var 标: Label = 记.get("_标签") as Label
	_判("状态字节点拿得到（拿不到 = 后面三条判不了）", 标 != null)
	if 标 != null:
		记.set("_录", false)
		OS.set_environment("NARUTO_PHYSICS", "")
		记.call("_刷标签", 180.0)
		_判("★ 正常启动（无参数、未开录，屏 180）⇒ 状态字不显示", not 标.visible)
		OS.set_environment("NARUTO_PHYSICS", "off")
		记.call("_刷标签", 180.0)
		_判("NARUTO_PHYSICS=off 启动 ⇒ 状态字显示（对照启动算加参数）", 标.visible)
		OS.set_environment("NARUTO_PHYSICS", "")
		记.set("_录", true)
		记.call("_刷标签", 180.0)
		_判("F6 开录（或 --camlog / NARUTO_CAMLOG=1）⇒ 状态字显示", 标.visible)
		记.set("_录", false)
		记.call("_刷标签", 180.0)
		_判("关录且无参数 ⇒ 状态字又藏起来", not 标.visible)
	## ③ 阳性对照：缓存空的时候 _统计() 必须打红
	var 空: Array = 记.get("_采")
	空.clear()
	var 行空: Array = 记.call("_统计")
	var 见红 := false
	for s in 行空:
		if String(s).begins_with("!!红"):
			见红 = true
	_判("缓存空 ⇒ _统计() 必须打红（不许 0 比 0 恒绿）", 见红)
	print("   空缓存那行原文 = " + str(行空[1]))
	## ④ 进图、真的走一段、录下来、存证
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	var 们: Array = get_nodes_in_group("player")
	var 试 := 0
	while 们.size() == 0 and 试 < 600:
		await _帧(10)
		们 = get_nodes_in_group("player")
		试 += 10
	if 们.size() == 0:
		print("!!红 拿不到玩家")
		_还原()
		quit(1)
		return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	玩.set("move_speed", 300.0)
	await _帧(20)
	OS.set_environment("NARUTO_PHYSICS", "")
	记.set("_录", true)
	记.call("_归零")
	记.call("set_process", true)
	Input.action_press("ui_right")
	await _帧(320)
	Input.action_release("ui_right")
	var 采: Array = 记.get("_采")
	_判("录到拍数够（" + str(采.size()) + " ≥ 60）", 采.size() >= 60)
	记.call("_存证")
	await _帧(2)
	_判("存证文件写得出来", FileAccess.file_exists(出文件))
	var 文 := ""
	if FileAccess.file_exists(出文件):
		var f := FileAccess.open(出文件, FileAccess.READ)
		文 = f.get_as_text()
	for 键 in ["录到渲染拍", "★ 每渲染帧夹的物理拍数", "★ 镜头在屏幕上的 x 相邻帧位移",
			"★ 角色在屏幕上的 x 相邻帧位移", "★ 屏幕 x 的小数部分", "判读："]:
		_判("存证里有那一行：" + 键, 文.find(键) >= 0)
	var 屏 := float(记.call("_刷新率"))
	_判("有头跑得能读到显示器刷新率（现=" + _f(屏) + " Hz）——跟屏模式全靠它", 屏 >= 30.0)
	_判("收尾节拍仍是 60（这一条被改脏 = 记录器把工程默认值吃了）",
			Engine.get_physics_ticks_per_second() == 60)
	print("")
	print("=== 镜头节拍记录器自检：判 " + str(判数) + " 条，红 " + str(红数) + " 条 ===")
	_还原()
	if 红数 > 0:
		quit(1)
	quit(0)


func _f(x) -> String:
	return "%.1f" % float(x)

extends SceneTree

## 有头量具：**在游戏里逐引擎帧普查"这一拍到底亮了几帧"**，回答用户那个疑点 ——
## 「换到下一帧时，前一帧有没有被隐藏？」
##
## 为什么这条必须量而不是读代码了事（2026-10-13）：脚本里 `_刷可见()` 的循环上界是
## **帧表长度**，而场景里的子节点是另一回事。一旦两边不一致（帧表删了尾帧、场景里节点还留着，
## 或反过来），那个"帧表管不到"的节点就**永远不会被隐藏** ⇒ 它一直亮着叠在旁边，
## 看起来正是"盘在飘 / 有重影"。而且这种错**门全绿也发现不了**（门只逐帧量它自己遍历到的那些）。
##
## 跑：Godot --path . --script res://开发工具/查打坐换帧亮几帧.gd
## ⚠ 不加 --headless（要真视口）。会进图 ⇒ 按字节快照 `user://玩家数据.json`、收尾还原。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 存档 := "user://玩家数据.json"
const 采毫秒 := 15000		# 第 0 帧自己停 12000 毫秒 ⇒ 必须采过 12 秒才看得见整条换帧
const 出图 := "res://测试/截图/打坐/换帧那一拍.png"

var 起毫秒 := 0
var 帧计数 := 0
var 存前 := PackedByteArray()
var 存前在 := false


func _看门狗() -> void:
	帧计数 += 1
	if Time.get_ticks_msec() - 起毫秒 > 120000:
		print("!! 看门狗超时（%d 帧）" % 帧计数)
		_还原()
		quit(3)


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
		if FileAccess.file_exists(存档):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档))
			print("动手前没有存档 ⇒ 收尾删掉本量具造的那份")
		return
	var 现 := FileAccess.open(存档, FileAccess.READ)
	if 现.get_buffer(现.get_length()) == 存前:
		print("存档没动过")
		return
	var h := FileAccess.open(存档, FileAccess.WRITE)
	h.store_buffer(存前)
	print("存档被本量具改过 ⇒ 已按字节还原")


func _initialize() -> void:
	起毫秒 = Time.get_ticks_msec()
	_run()


func _run() -> void:
	_快照()
	process_frame.connect(_看门狗)
	root.size = Vector2i(960, 560)
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
	await _帧(20)
	玩.call("toggle_practise")
	await _帧(8)
	var 环: Node = 玩.get_node_or_null("打坐光环")
	if 环 == null:
		print("!!红 打坐时身上没挂光环节点")
		_还原()
		quit(1)
		return

	# ── 先把"场景里到底有几个贴图子节点"与"帧表管几个"对出来（这就是那个疑点的根）──
	var 子们: Array = []
	for c in 环.get_children():
		if c is Sprite2D:
			子们.append(c)
	var 状0: Dictionary = 环.call("状态")
	print("场景里的 Sprite2D 子节点 = %d 个；帧表管的帧 = %d 个" % [子们.size(), int(状0.get("帧数", 0))])
	var 红: Array = []
	if 子们.size() != int(状0.get("帧数", 0)):
		红.append("两边不一致 ⇒ 有 %d 个节点**永远不会被 _刷可见() 碰到**（会一直亮着叠在旁边）" % (
			子们.size() - int(状0.get("帧数", 0))))
	for c in 子们:
		var 在表 := false
		for i in range(子们.size()):
			if 子们[i] == c and i < int(状0.get("帧数", 0)):
				在表 = true
		if not 在表:
			print("   管不到的节点：%s  visible=%s" % [c.name, (c as CanvasItem).visible])

	# ── 逐引擎帧普查：每一拍亮几帧、亮的是哪一帧 ──
	var 起 := Time.get_ticks_msec()
	var 亮数计: Dictionary = {}
	var 换帧拍: Array = []
	var 上一帧号 := -1
	var 拍 := 0
	var 换帧图: Image = null
	while Time.get_ticks_msec() - 起 < 采毫秒 and 拍 < 4000:
		拍 += 1
		await _帧(1)
		var 亮: Array = []
		for c in 子们:
			if (c as CanvasItem).visible:
				亮.append(c.name)
		亮数计[亮.size()] = int(亮数计.get(亮.size(), 0)) + 1
		var 号: int = int(环.call("状态").get("当前帧", -1))
		if 号 != 上一帧号 and 上一帧号 >= 0:
			换帧拍.append("第%d拍：%d → %d  同时亮的帧 = %s" % [拍, 上一帧号, 号, 亮])
			if 换帧图 == null:
				换帧图 = root.get_viewport().get_texture().get_image()
		上一帧号 = 号
		if 亮.size() != 1:
			红.append("第%d拍 亮了 %d 帧：%s" % [拍, 亮.size(), 亮])

	print("采 %d 拍 / %d 毫秒" % [拍, Time.get_ticks_msec() - 起])
	print("「同时亮几帧」的分布（计数口径：多少拍出现该值）= ", 亮数计)
	print("换帧共 %d 次，前 12 次：" % 换帧拍.size())
	for s in 换帧拍.slice(0, 12):
		print("  " + s)
	if 换帧图 != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出图.get_base_dir()))
		换帧图.save_png(出图)
		print("换帧那一拍的实机截图 → ", 出图)
	_还原()
	if 红.is_empty():
		print("⇒ 每一拍都只亮一帧：换到下一帧时前一帧确实被隐藏了，没有重影")
		quit(0)
	for s in 红.slice(0, 12):
		print("!!红 " + s)
	quit(1)

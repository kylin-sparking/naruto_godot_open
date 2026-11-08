## 量具：点追踪栏绿名之后，`走向()` 到底在哪一步静默返回 false。
## 为什么要它：用户 2026-10-10 上午报「有时会自动寻路，有时不会」——
## 这种"时灵时不灵"用文本门永远照不到（门里只比源码字符串），只能把**决策输入**逐项打出来。
## 跑法：godot --path . --script res://开发工具/量寻路为什么不灵.gd
extends SceneTree

var 行: Array[String] = []
var 出 := "res://测试/截图/追踪栏/寻路为什么不灵.txt"


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _记(s: String) -> void:
	行.append(s)
	print(s)	# 逐条冲出去：跑到哪一步挂住，日志里就停在哪儿


func _跑() -> void:
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(60)
	var 玩: Node2D = get_first_node_in_group("player") as Node2D
	if 玩 == null:
		_记("没有玩家"); _收(); return
	var 板: Node = 场.find_child("小地图面板", true, false)
	var 实体: Node = 场.find_child("地图实体", true, false)
	_记("玩家起点=%s on_ground=%s current_fh_id=%s" % [
			str(玩.position), str(玩.get("on_ground")), str(玩.get("current_fh_id"))])
	## ⚠ 寻路器是 RefCounted、落脚点集是 Node —— 一律收 Variant，
	## 写死成 Node 会撞「Trying to assign RefCounted to Node」把整个函数打断（本轮真撞到过）。
	var 架: Variant = 玩.get("auto_pathfinder")
	var 脚: Variant = 玩.get("footholds")
	if 脚 == null or 架 == null:
		_记("缺 auto_pathfinder / footholds"); _收(); return
	# 把图里每个 NPC 都点一次，逐个看决策输入
	var 名单: Array = []
	for 客 in 场.get_children():
		if str(客.name) == "LifeRoot":
			for 条 in 客.get_children():
				if str(条.get("kind")) == "n":
					名单.append(条)
	_记("本图 NPC %d 个" % 名单.size())
	for 条 in 名单:
		var 位: Vector2 = (条 as Node2D).position
		var 号 := str(条.get("entity_id"))
		var 落: Dictionary = 脚.find_click_target(位)
		var 距 := absf(位.x - 玩.position.x)
		## 不自己调 plan()：参数给错（目标落脚点 id 不存在）会让它空转到天荒地老，
		## 那是量具造出来的假案，不是用户那条链。走向() 内部会调，读它的返回值与副作用就够。
		var 步数 := -1
		var 前 := float(玩.get("click_move_x"))
		var 走成 := bool(玩.call("走向", 位, true, true))
		var 后 := float(玩.get("click_move_x"))
		_记("NPC %s 位=%s 横距=%.0f | find_click y=%s(id=%s) | plan=%d 步 | 走向=%s | click_move_x %s→%s  active=%s" % [
				号, str(位), 距, str(落.get("y")), str(落.get("id")), 步数,
				str(走成), str(前), str(后), str(玩.get("click_move_active"))])
	# 再走一遍"真入口"：追踪栏那条链接
	if 板 != null and 名单.size() > 0:
		var 体: RichTextLabel = null
		var 列表: VBoxContainer = 板.find_child("任务列表", true, false) as VBoxContainer
		if 列表 != null:
			for 条2 in 列表.get_children():
				for 子 in (条2 as Node).get_children():
					if 子 is RichTextLabel:
						体 = 子 as RichTextLabel
						break
				if 体 != null:
					break
		if 体 == null:
			_记("追踪栏没有行（离线默认没任务）⇒ 只量了上面那批")
		else:
			var 远: Node2D = 名单[名单.size() - 1] as Node2D
			玩.position = Vector2(60.0, 玩.position.y)
			_记("把玩家挪到 x=60（离 NPC 最远）后再点一次真入口")
			板.call("_追踪链接点击", "event:npc" + str(int(远.get("entity_id"))), 体)
			await _帧(3)
			_记("点完 click_move_x=%s active=%s 自动寻路中=%s" % [
					str(玩.get("click_move_x")), str(玩.get("click_move_active")), str(玩.get("自动寻路中"))])
	_收()


func _收() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	for s in 行:
		print(s)
	quit(0)

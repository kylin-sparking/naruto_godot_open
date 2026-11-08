extends SceneTree

## 让角色在地图上按自己的物理落稳，然后**在一次运行内**截两张图（带角色 / 不带角色），
## 自己在内存里做差，把角色的**实际绘制范围**换算成世界坐标打出来。
##
## 为什么要这么写：分两次运行截两张图，会被"改动生效帧""动画当前帧""参数没解析"
## 三件事各坑一次，得到自相矛盾的结论。一次运行内完成，这些坑全没了。
##
## 用法（不要加 --headless）：
##   Godot --path . --script res://开发工具/看角色站姿.gd -- \
##     --地图=100000000 --x=2100 --y=1098 --帧=90 --出=res://测试/截图/站姿.png [--藏地形] [--抬z=5313]

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

var _地图 := "100000000"
var _x := 2100.0
var _y := 1098.0
var _帧数 := 90
var _出 := "res://测试/截图/_本轮地形/站姿.png"
var _藏地形 := false
var _抬z := 0
var _帧 := 0
var _带角色图: Image = null
var _报告完了 := false
var _查遮挡点 := Vector2.INF
var _列地形 := false
var _沉地形z := 0
var _藏这些 := []
var _旧npc := false

func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 1:
			键值.append("")   # 无值开关也要能解析（上一次漏了这条，开关一直静默失效）
		match 键值[0]:
			"--地图": _地图 = 键值[1]
			"--x": _x = float(键值[1])
			"--y": _y = float(键值[1])
			"--帧": _帧数 = int(键值[1])
			"--出": _出 = 键值[1]
			"--藏地形": _藏地形 = true
			"--抬z": _抬z = int(键值[1])
			"--列地形": _列地形 = true
			"--沉地形z": _沉地形z = int(键值[1])
			"--藏": _藏这些 = 键值[1].split(",", false)
			"--旧npc": _旧npc = true
			"--查遮挡":
				var 坐标 := 键值[1].split(",", true, 1)
				_查遮挡点 = Vector2(float(坐标[0]), float(坐标[1]))
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		会话.current_map_id = _地图
	var 场景 := load(MAP_RESOURCES.playable_scene_path(_地图)) as PackedScene
	if 场景 == null:
		push_error("加载地图场景失败")
		quit(1)
		return
	root.add_child(场景.instantiate())

func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 == 3:
		var 角色 := _找(root, "Player") as Node2D
		if 角色 != null:
			角色.global_position = Vector2(_x, _y)
			print("已把角色放到 (%.1f, %.1f)，随后交给它自己的物理" % [_x, _y])
	if _帧 == _帧数:
		if _藏地形:
			for 名 in ["TileRoot", "ObjectRoot"]:
				var 节点 := _找(root, 名)
				if 节点 is CanvasItem:
					(节点 as CanvasItem).visible = false
			print("诊断：已隐藏 TileRoot/ObjectRoot")
		for 名 in _藏这些:
			var 节点 := _找(root, 名)
			if 节点 is CanvasItem:
				(节点 as CanvasItem).visible = false
				print("诊断：已隐藏 %s" % 名)
		if _旧npc:
			var 生命 := _找(root, "LifeRoot")
			if 生命 != null:
				for 子 in 生命.get_children():
					if 子 is CanvasItem:
						(子 as CanvasItem).z_index = 0
				print("诊断：把 %d 个 LifeRoot 实体的 z_index 压回 0（改动前的值）" % 生命.get_child_count())
		if _抬z != 0:
			var 角色 := _找(root, "Player") as Node2D
			if 角色 != null:
				print("诊断：把角色 z_index 从 %d 抬到 %d" % [角色.z_index, _抬z])
				角色.z_index = _抬z
		if _沉地形z != 0:
			# 烘焙场景里的瓦片是"一批一个 Node2D + 自绘"，且 z_as_relative=false，
			# 所以要逐个子节点改，改 TileRoot 自己是没用的。
			var 改 := 0
			for 名 in ["TileRoot", "ObjectRoot"]:
				var 根 := _找(root, 名)
				if 根 == null:
					continue
				for 子 in 根.get_children():
					if 子 is CanvasItem:
						(子 as CanvasItem).z_index = _沉地形z
						改 += 1
			print("诊断：把 %d 个地形子节点的 z_index 压到 %d" % [改, _沉地形z])
		return false
	# 改动要到下一帧渲染才生效，所以改完再多等几帧
	# 玩家.gd 每帧都会把 z_index 重算成 100+y+1，所以"抬 z"必须**每帧压**才生效。
	# （第一次没压，白测了三轮 z，都是假阴性。）
	if _抬z != 0 and _帧 > _帧数:
		var 角色z := _找(root, "Player") as Node2D
		if 角色z != null:
			角色z.z_index = _抬z
	if _帧 == _帧数 + 3:
		if not _报告完了:
			_报告完了 = true
			_报告()
			if _查遮挡点 != Vector2.INF:
				_查遮挡(_查遮挡点.x, _查遮挡点.y)
			if _列地形:
				_列可绘节点(400)
		_带角色图 = root.get_texture().get_image()
		var 角色 := _找(root, "Player") as Node2D
		if 角色 != null:
			角色.visible = false
		return false
	if _帧 == _帧数 + 7:
		_算绘制范围(root.get_texture().get_image())
		_存图(_带角色图)
		quit(0)
		return true
	return false

func _算绘制范围(无角色图: Image) -> void:
	if _带角色图 == null:
		return
	var 宽 := _带角色图.get_width()
	var 高 := _带角色图.get_height()
	var 最小x := 1 << 30
	var 最大x := -1
	var 最小y := 1 << 30
	var 最大y := -1
	var 数 := 0
	for y in 高:
		for x in 宽:
			var a := _带角色图.get_pixel(x, y)
			var b := 无角色图.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.1:
				数 += 1
				最小x = mini(最小x, x); 最大x = maxi(最大x, x)
				最小y = mini(最小y, y); 最大y = maxi(最大y, y)
	if 数 == 0:
		print("角色实际绘制像素 = 0（角色根本没画出来）")
		return
	var 相机 := _找(root, "WorldCamera") as Camera2D
	var 视口 := root.get_visible_rect().size / 相机.zoom
	var 左上 := 相机.global_position - 视口 * 0.5
	print("角色实际绘制：屏幕 bbox x %d..%d y %d..%d（%d 像素）" % [最小x, 最大x, 最小y, 最大y, 数])
	print("换算世界坐标：x %d..%d  y %d..%d" % [
		左上.x + 最小x, 左上.x + 最大x, 左上.y + 最小y, 左上.y + 最大y])

func _报告() -> void:
	var 角色 := _找(root, "Player") as Node2D
	var 相机 := _找(root, "WorldCamera") as Camera2D
	if 角色 == null:
		print("没找到 Player")
		return
	var 视口 := root.get_visible_rect().size / 相机.zoom
	var 左上 := 相机.global_position - 视口 * 0.5
	print("角色 global_position=(%.2f, %.2f) on_ground=%s fh=%s z_index=%d" % [
		角色.global_position.x, 角色.global_position.y,
		角色.get("on_ground"), 角色.get("current_fh_id"), 角色.z_index])
	print("可见世界左上=(%.1f, %.1f)" % [左上.x, 左上.y])
	var 脚点 := _找(root, "Footholds")
	var 当前 := str(角色.get("current_fh_id"))
	if 脚点 != null:
		for s in 脚点.get("segments"):
			if str(s.get("id", "")) == 当前:
				print("当前脚点 id=%s 段=(%s,%s)-(%s,%s) 层=%s" % [
					s.get("id"), s.get("x1"), s.get("y1"), s.get("x2"), s.get("y2"), s.get("layer", "无")])
	for 项 in [["TileRoot", "地图块"], ["ObjectRoot", "物件"]]:
		var 根 := _找(root, 项[0])
		if 根 == null:
			continue
		var 样本 := []
		for 子 in 根.get_children():
			if 子 is CanvasItem and 样本.size() < 6:
				样本.append("z=%d" % (子 as CanvasItem).z_index)
		print("  %s 子节点 %d 个，前几个 z：%s" % [项[0], 根.get_child_count(), 样本])

## 查出"世界点 (px,py) 被哪些 CanvasItem 盖住"，按有效 z 从低到高列出。
## 用来定位"角色下半身被谁挡住"这类问题 —— 靠猜节点名会一直试错。
func _查遮挡(px: float, py: float) -> void:
	var 列表 := []
	_收集(root, Vector2(px, py), 列表)
	列表.sort_custom(func(a, b): return a[0] < b[0])
	print("盖住世界点 (%.0f, %.0f) 的 CanvasItem（按有效 z 从低到高）：" % [px, py])
	for 项 in 列表:
		print("   有效z=%-8s %-28s (类型 %s)" % [项[0], 项[1], 项[2]])

func _收集(节点: Node, 点: Vector2, 出: Array) -> void:
	if 节点 is CanvasItem:
		var 项 := 节点 as CanvasItem
		var 有效z := 项.get_global_transform_with_canvas().origin  # 仅占位，真实 z 见下
		var z := 项.z_index
		var 父 := 项.get_parent()
		while 父 is CanvasItem:
			if (项 as CanvasItem).z_as_relative:
				z += (父 as CanvasItem).z_index
			父 = 父.get_parent()
		var rect := Rect2()
		var 有大小 := false
		if 项 is Sprite2D and (项 as Sprite2D).texture != null:
			var s := 项 as Sprite2D
			var 尺寸 := s.texture.get_size() * s.scale
			var 左上 := s.global_position - (尺寸 * 0.5 if s.centered else Vector2.ZERO)
			rect = Rect2(左上, 尺寸)
			有大小 = true
		elif 项 is ColorRect:
			rect = Rect2((项 as ColorRect).global_position, (项 as ColorRect).size)
			有大小 = true
		if 有大小 and rect.has_point(点) and 项.visible:
			出.append([z, str(项.get_path()), 项.get_class()])
	for 子 in 节点.get_children():
		_收集(子, 点, 出)

## 把场景里所有"能画东西的节点"的**全局矩形 + 有效 z** 全列出来（限前 N 个）。
## 用于回答"这一点到底是谁画的 / 谁挡在前面的"。
func _列可绘节点(上限: int) -> void:
	var 列表 := []
	_收集全部(root, 列表)
	列表.sort_custom(func(a, b): return a[0] < b[0])
	print("场景里可绘节点（按有效 z，前 %d）：" % 上限)
	for 项 in 列表.slice(0, 上限):
		print("   z=%-7s %-52s %s rect=%s" % [项[0], 项[1], 项[2], 项[3]])

func _收集全部(节点: Node, 出: Array) -> void:
	if 节点 is Sprite2D and (节点 as Sprite2D).texture != null:
		var s := 节点 as Sprite2D
		var z := s.z_index
		if s.z_as_relative:
			var 父 := s.get_parent()
			while 父 is CanvasItem:
				z += (父 as CanvasItem).z_index
				父 = 父.get_parent()
		var 尺寸 := s.texture.get_size() * s.scale
		var 左上 := s.global_position - (尺寸 * 0.5 if s.centered else Vector2.ZERO)
		出.append([z, str(s.get_path()), s.texture.resource_path.get_file().substr(0, 30), Rect2(左上, 尺寸)])
	for 子 in 节点.get_children():
		_收集全部(子, 出)

func _存图(图: Image) -> void:
	if 图 == null:
		return
	DirAccess.make_dir_recursive_absolute(_出.get_base_dir())
	print("截图 -> %s 结果=%d" % [_出, 图.save_png(_出)])

func _找(起点: Node, 名称: String) -> Node:
	if 起点.name == 名称:
		return 起点
	for 子 in 起点.get_children():
		var 命中 := _找(子, 名称)
		if 命中 != null:
			return 命中
	return null

extends SceneTree

## 渲染一张地图的对照图，用于与 2.2.3 的**参照帧**逐像素比对。
##
## 参照帧由 2.2.3 的 map_extract/render_frame.py 生成（注释明确写着"照抄反编译的
## MapBackGroup 数学"）：
##   2.2.3\map_extract\out\frames\map_<地图>_cx<机位>.png   默认 cy=1100
##
## 参照的相机语义（render_frame.py 的 frame()）：
##   可见世界矩形 = (cx - 960/2, cy - 560/2 - 128, 960, 560)
## 其中 -128 是原版相机在 560 档的竖直偏移。本工具按同一矩形摆位，因此两张图应当
## 逐像素可比（缩放同为 1.0）。
##
## 用法（**不要加 --headless**：无头驱动拿不到视口图像，会报"渲染驱动未返回视口图像"）：
##   Godot --path . --script res://开发工具/渲染地图对照.gd -- \
##     --地图=100000000 --cx=2450 --cy=1100 --出=res://测试/截图/对照_100000000_cx2450.png
##
## 比对：把这张图与参照帧放进两个目录，跑 开发工具/截图比对.gd 出高亮差异图。

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

const 半宽 := 480.0
const 半高 := 280.0
const 原版垂直偏移 := 128.0
## 参照渲染器只画瓦片/物件/背景层，不画 HUD 与实体；这些节点要藏掉才比得准。
const 要隐藏的节点 := [
	"LifeRoot", "PortalRoot", "Player", "PerformanceProbe",
	"头像面板", "小地图面板", "聊天面板", "技能面板", "功能窗口",
]

var _地图 := "100000000"
var _cx := 2450
var _cy := 1100
var _出 := "res://测试/截图/地图对照.png"
## 给了 --玩家=x,y 就把角色放到那里、**让相机自己跟随**——用来验证取景（相机竖直落点）
## 是否与原版一致。不给则按 --cx/--cy 直接摆相机，用来验证地形/背景的绘制。
var _玩家 := Vector2.ZERO
var _有玩家 := false
var _帧 := 0
var _机位已摆 := false
## `--尺寸=1920x1032` 要的视口；`Vector2i(0,0)` = 不改（沿用工程默认 960×560）。
var _要尺寸 := Vector2i(0, 0)

func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() != 2:
			continue
		match 键值[0]:
			"--地图": _地图 = 键值[1]
			"--cx": _cx = int(键值[1])
			"--cy": _cy = int(键值[1])
			"--出": _出 = 键值[1]
			"--尺寸":
				## 把视口改成玩家实机那一档。工程默认 960×560，而**图比窗口矮**那一档
				## （竞技场 503000000 的 VR 只有 767 高）只有在 1032 高的窗口里才看得见 ——
				## 不加这一档，"地图悬空"这类问题在量具里根本不会出现。
				var 尺 := 键值[1].split("x", true, 1)
				if 尺.size() == 2:
					_要尺寸 = Vector2i(int(尺[0]), int(尺[1]))
			"--玩家":
				var 坐标 := 键值[1].split(",", true, 1)
				if 坐标.size() == 2:
					_玩家 = Vector2(float(坐标[0]), float(坐标[1]))
					_有玩家 = true

	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		会话.current_map_id = _地图
	if _要尺寸.x > 0 and _要尺寸.y > 0:
		## ⚠ 光改 `root.size` **不够**：实测 `root.get_texture().get_image()` 仍然回工程
		## 那档 960×560（`get_viewport_rect()` 却已经跟着变）。要拿到真那一档的**图像**，
		## 得走 DisplayServer 把窗口本身改掉，再等两帧让 backbuffer 重建。
		DisplayServer.window_set_size(_要尺寸)
		root.size = _要尺寸
		print("地图对照：视口改到 %s（窗口实际 %s）" % [str(_要尺寸), str(root.size)])
	var 路径 := MAP_RESOURCES.playable_scene_path(_地图)
	var 场景 := load(路径) as PackedScene
	if 场景 == null:
		push_error("加载地图场景失败：%s" % 路径)
		quit(1)
		return
	root.add_child(场景.instantiate())
	print("地图对照：加载 %s（机位 %d,%d）" % [路径, _cx, _cy])

func _process(_delta: float) -> bool:
	_帧 += 1
	# 等场景建好再摆机位、藏节点
	if _帧 == 3 and not _机位已摆:
		_摆机位()
		return false
	if _帧 < 20:
		return false
	var 视口纹理 := root.get_texture()
	if 视口纹理 == null:
		push_error("当前渲染驱动未返回视口图像（不能加 --headless）")
		quit(1)
		return true
	var 图像 := 视口纹理.get_image()
	if 图像 == null:
		push_error("视口图像为空")
		quit(1)
		return true
	var 目录 := _出.get_base_dir()
	if not DirAccess.dir_exists_absolute(目录):
		DirAccess.make_dir_recursive_absolute(目录)
	var 错误 := 图像.save_png(_出)
	print("地图对照：存图结果=%d 尺寸=%s 文件=%s" % [错误, 图像.get_size(), _出])
	quit(0 if 错误 == OK else 1)
	return true

func _摆机位() -> void:
	_机位已摆 = true
	for 名称 in 要隐藏的节点:
		# 验证取景时要留着角色，才能看出它落在屏幕什么位置。
		if 名称 == "Player" and _有玩家:
			continue
		var 节点 := _找节点(root, 名称)
		if 节点 is CanvasItem:
			(节点 as CanvasItem).visible = false
			print("地图对照：隐藏 %s" % 名称)
		elif 节点 != null:
			# CanvasLayer 之类不是 CanvasItem，用 visible 属性直接关
			节点.set("visible", false)
			print("地图对照：隐藏(非 CanvasItem) %s" % 名称)
		else:
			print("地图对照：没找到 %s" % 名称)
	var 相机 := _找节点(root, "WorldCamera")
	if 相机 == null:
		push_warning("没找到 WorldCamera，画面可能不是参照机位")
		return
	if _有玩家:
		# 验证取景：把角色摆到参照的焦点位置，让相机按自己的逻辑跟随。
		var 角色 := _找节点(root, "Player") as Node2D
		if 角色 == null:
			push_warning("没找到 Player，无法验证取景")
			return
		角色.global_position = _玩家
		if 相机.has_method("refresh"):
			相机.call("refresh")
		print("地图对照：角色置于 (%d,%d)，相机自行取景" % [int(_玩家.x), int(_玩家.y)])
		return
	# 验证绘制：接管相机，直接摆到与参照相同的可见矩形中心。
	相机.set_physics_process(false)
	相机.set_process(false)
	相机.position = Vector2(float(_cx), float(_cy) - 原版垂直偏移)
	if 相机.has_method("force_update_scroll"):
		相机.call("force_update_scroll")

func _找节点(起点: Node, 名称: String) -> Node:
	if 起点.name == 名称:
		return 起点
	for 子节点 in 起点.get_children():
		var 命中 := _找节点(子节点, 名称)
		if 命中 != null:
			return 命中
	return null

extends SceneTree

## A2：传送门动画必须走 `数据/特效.json`，而且在**真烘焙地图**里画得出来。
##
## 出处：`Etc.effects.portalPV`（8 帧）/ `portalPH`（7 帧），每帧 250ms，逐帧 origin 钉位。
## 2026-09-26 之前 `传送门.gd` 里手抄了帧数、`set_animation_speed(4.0)` 和两组 origin 表；
## 现在这些一律由 `特效播放器.gd` 查表。这条用例钉住改完之后仍然成立的那几件事：
##   ① 每张图的 PortalRoot 真的建出了特效播放器节点（不是静默 return false）
##   ② 垂直(pt 2/7)→portalPV 8 帧、水平(pt 10)→portalPH 7 帧
##   ③ 播放器就摆在地图数据给的那个 (x,y) 上
##
## 用法（要窗口，headless 截不出图）：
##   Godot --path . --script res://测试/传送门渲染回归测试.gd

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 播放器脚本路径 := "res://脚本/表现/特效播放器.gd"

const 默认地图 := "101010000"
const 输出目录 := "res://测试/输出"

var _失败: Array[String] = []

func _initialize() -> void:
	call_deferred("_跑")

func _跑() -> void:
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	if not 场景路径.contains("场景/生成/"):
		_失败.append("加载的不是烘焙场景（%s）—— 实机走 playable_scene_path()，拿源场景验等于验了个假" % 场景路径)
		_收尾()
		return
	var scene := (load(场景路径) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for _帧 in range(5):
		await process_frame
	var 根 := scene.get_node_or_null("PortalRoot")
	if 根 == null:
		_失败.append("烘焙场景里没有 PortalRoot")
		_收尾()
		return
	var 期望帧数 := {"portalPV": 8, "portalPH": 7}
	var 播放器数 := 0
	var 首个门 := Vector2.ZERO
	for 子 in 根.get_children():
		var 脚本 := 子.get_script() as GDScript
		if 脚本 == null or 脚本.resource_path != 播放器脚本路径:
			continue
		var 播放器 = 子	# 转成 Variant：特效播放器的成员不在 Node 的静态类型上
		播放器数 += 1
		var 键 := String(播放器.entry_name)
		if not 期望帧数.has(键):
			_失败.append("传送门画了表外的特效：%s" % 键)
			continue
		if 播放器.frames.size() != int(期望帧数[键]):
			_失败.append("%s 帧数不是 %s：%d" % [键, str(期望帧数[键]), 播放器.frames.size()])
		if bool(播放器.paused):
			_失败.append("%s 建出来了却没在播" % 键)
		var 数据位置 := Vector2(float(播放器.position.x), float(播放器.position.y))
		if 数据位置 == Vector2.ZERO:
			_失败.append("%s 摆在 (0,0) —— 没吃到地图数据里的传送门坐标" % 键)
		if 首个门.is_zero_approx():
			首个门 = 数据位置
	if 播放器数 == 0:
		_失败.append("%s 里一个传送门动画都没画出来（pt 2/7/10 的传送门应当都有）" % 默认地图)
	# 把人物挪到第一个传送门旁，让截图里真的看得见门（相机每帧跟着人物，改相机位置没用）
	if not 首个门.is_zero_approx():
		var 人物 := scene.get_node_or_null("Player")
		if 人物 != null:
			人物.position = 首个门
			for _帧 in range(12):
				await process_frame
	print("传送门渲染回归测试：%s 画出 %d 个特效播放器" % [场景路径, 播放器数])
	if DisplayServer.get_name() != "headless":
		var 图像 := get_root().get_texture().get_image()
		图像.save_png("%s/传送门渲染.png" % 输出目录)
		print("  截图 -> 测试/输出/传送门渲染.png")
	_收尾()

func _收尾() -> void:
	if _失败.is_empty():
		print("传送门渲染回归测试：全部通过")
		quit(0)
		return
	for 条 in _失败:
		print("  FAIL " + 条)
	print("传送门渲染回归测试：%d 项不通过" % _失败.size())
	quit(1)

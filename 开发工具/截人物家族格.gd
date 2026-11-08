extends SceneTree

## 截「人物面板 · 家族格」（2026-11-01 用户报修：已经有家族，那一格还是 `-`）。
##
## 离线门（`测试/人物面板家族格回归测试.gd`）验的是 `Label.text`；**字形有没有真画出来、
## 有没有被裁/压行**得拿眼睛看。这里走实机那条路（烘焙地图 → 窗口管理取「人物」页 →
## 灌真 1552 帧），真视口 960x560 截图。
##
## ⚠️ **不能加 --headless**。存图在 `res://测试/截图/家族格/`（`.gitignore` 挡着）。
##
## 用法：
##   Godot --path . --script res://开发工具/截人物家族格.gd

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 出目录 := "res://测试/截图/家族格"
const 帧_入族 := "1552:15:7:木叶家族:欢迎回家:1721552400:42:千手柱间"
const 帧_退族 := "1552:14:4242:木叶忍者"


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	call_deferred("_跑")


func _跑() -> void:
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	root.add_child((load(场景路径) as PackedScene).instantiate())
	current_scene = root.get_child(root.get_child_count() - 1)
	for _帧 in range(5):
		await process_frame
	var 后端 := root.get_node_or_null("BackendConnection")
	var 管理 := current_scene.get_node_or_null("窗口管理")
	if 后端 == null or 管理 == null:
		push_error("依赖节点不完整（BackendConnection / 窗口管理）")
		quit(1)
		return
	var 窗: Node = 管理.call("取或建窗口", "人物")
	if 窗 == null:
		push_error("没能建出「人物」页")
		quit(1)
		return
	窗.call("打开")
	for _帧 in range(3):
		await process_frame
	await _截(后端, 窗, 帧_入族, "入族_木叶家族")
	await _截(后端, 窗, 帧_退族, "退族_横杠")
	quit(0)


func _截(后端: Node, 窗: Node, 帧: String, 名: String) -> void:
	后端.call("_handle_bridge_text", 帧)
	for _帧 in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var 格 := _家族格(窗)
	var 节点 := ""
	if 格 != null:
		var 矩形 := 格.get_global_rect()
		节点 = "text=「%s」 rect=%s" % [格.text, 矩形]
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	var 路径 := "%s/%s.png" % [出目录, 名]
	图.save_png(路径)
	print("截人物家族格：%s → %s（%s）" % [名, 路径, 节点])


func _家族格(窗: Node) -> Label:
	var 内容 := 窗.get("_content") as Node
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		var 面板 := 子.get_node_or_null("原版人物属性面板") as Control
		if 面板 != null:
			return 面板.get_node_or_null("信息区/家族格/数值") as Label
	return null

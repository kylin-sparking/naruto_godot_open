extends SceneTree

## 把「物品提示框」组件单独渲染出来截图，用来和原版真机图做并排/8 倍单件对证。
##
## 为什么单独截：提示框是**贴着鼠标弹**的浮层，跑整个游戏去截会带上背包窗口和地图，
## 裁图时原点很难对；这里把它放在固定位置 (20,20)，裁图原点就是 (20,20)。
##
## 用法（**不能加 --headless**，无头驱动拿不到视口图像）：
##   Godot --path . --script res://开发工具/截物品提示框.gd -- --物品=15008001 --出=res://测试/截图/物品提示框.png
##   可重复 --物品 一次出多张（文件名带上物品 id）。

const 提示框场景 := preload("res://场景/界面/组件/物品提示框.tscn")

var _物品列表: Array[String] = ["15008001"]
var _等级 := 100
var _出 := "res://测试/截图/物品提示框.png"
var _帧 := 0
var _序号 := 0
var _框: Control
var _待截 := false
var _未绑定 := false


func _initialize() -> void:
	_物品列表.clear()
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		match 键值[0]:
			"--未绑定": _未绑定 = true     # 无值开关：不带 "="，别在上面按 size()==2 过滤掉
			"--物品": if 键值.size() == 2: _物品列表.append(键值[1])
			"--等级": if 键值.size() == 2: _等级 = int(键值[1])
			"--出": if 键值.size() == 2: _出 = 键值[1]
	if _物品列表.is_empty():
		_物品列表.append("15008001")


func _process(_delta: float) -> bool:
	_帧 += 1
	# 等主题与字体就绪（第一帧量字体会拿到空字体，量出来的行高会是 0）。
	if _帧 < 5:
		return false
	if _框 == null:
		_框 = 提示框场景.instantiate() as Control
		root.add_child(_框)
		return false
	# ⚠️ `设置()` 之后**必须再等两帧**才截图：本帧 set 的文本要到本帧末尾才画进视口，
	# 在 `_process` 里立刻 `get_image()` 抓到的是**上一帧**的画面（和「切页签要多等几帧」同一个坑）。
	if _待截:
		_待截 = false
		_保存(_物品列表[_序号 - 1])
		return false
	if _序号 >= _物品列表.size():
		print("截物品提示框：共 %d 张" % _序号)
		quit(0)
		return true
	var 物品 := _物品列表[_序号]
	_框.call("设置", 物品, 1, _等级,
			{"can_trade": false} if _未绑定 else {})
	_框.position = Vector2(20.0, 20.0)
	_框.scale = Vector2.ONE
	_序号 += 1
	_打印诊断()
	_待截 = true
	return false


func _打印诊断() -> void:
	print("  框 size=", _框.size)
	var 字体 := _框.call("_字体") as Font
	print("  字体=", 字体, " 单行高(12)=", 字体.get_height(12) if 字体 else -1)
	for 名 in ["标题", "等级", "描述", "分隔线", "价格", "绑定", "过期", "图标框", "图标框/图标"]:
		var 节点 := _框.get_node_or_null(名) as Control
		if 节点 == null:
			print("  %-10s <找不到>" % 名)
			continue
		var 文本 := (节点 as Label).text if 节点 is Label else ""
		var 纹理 := (节点 as TextureRect).texture if 节点 is TextureRect else null
		print("  %-10s pos=%s size=%s visible=%s text=%s tex=%s"
			% [名, 节点.position, 节点.size, 节点.visible, 文本.replace("\n", "\\n"), 纹理])


func _保存(物品: String) -> void:
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		quit(1)
		return
	var 目录 := _出.get_base_dir()
	if not DirAccess.dir_exists_absolute(目录):
		DirAccess.make_dir_recursive_absolute(目录)
	var 路径 := _出 if _物品列表.size() == 1 else "%s/%s.png" % [目录, 物品]
	图像.save_png(路径)
	print("截物品提示框：物品 %s → %s（框 %dx%d，落在 20,20）"
		% [物品, 路径, int(_框.size.x), int(_框.size.y)])

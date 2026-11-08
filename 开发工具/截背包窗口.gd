extends SceneTree

## 打开客户端的「背包」窗口并截图，用来和原版真机图并排对证。
## 走的是 截窗口页.gd / 截忍术窗口.gd 同一条路径：离线地图场景 → 底栏按钮 → 功能窗口，
## **不需要起服务端**。
##
## 用法（**不能加 --headless**，无头驱动拿不到视口图像）：
##   Godot --path . --script res://开发工具/截背包窗口.gd -- --出=res://测试/截图/背包窗口.png

var _出 := "res://测试/截图/背包窗口.png"
var _帧 := 0
var _场景: Node = null
var _功能窗口: Node = null
var _已就绪 := false
var _待截 := false
var _点格 := false
var _页 := "背包"
var _弹金额 := false
var _弹销毁 := false
## 点第一格装备 → 菜单「宝石镶嵌」（2026-10-02：验镶嵌窗）。
var _弹镶嵌 := false
var _弹扩容 := false
var _已点 := false
## `--塞物品=15008001,01210538,...`：把这些 id 当背包内容灌进去，走真机同一条渲染路径。
## 只写内存里的 `会话.inventory`，不发协议、不碰存档。
var _塞物品: Array[String] = []
## `--品质=1,2,3,4,5,6,0`：与 `--塞物品` **一一对应**的资质档（0 = 不写 aptitude 字段，
## 就是原版那种"非装备物品根本没有这个属性"的情况）。用来验资质框/流光的渲染。
var _品质: Array[String] = []
var _名字表 := {}


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出":
			_出 = 键值[1]
		if 键值.size() == 2 and 键值[0] == "--塞物品":
			for 号 in 键值[1].split(",", false):
				_塞物品.append(号.strip_edges())
		if 键值.size() == 2 and 键值[0] == "--品质":
			for 号 in 键值[1].split(","):
				_品质.append(号.strip_edges())
		if 参数 == "--点格":
			_点格 = true
		if 键值.size() == 2 and 键值[0] == "--页":
			_页 = 键值[1]
		if 参数 == "--弹金额":
			_弹金额 = true
		if 参数 == "--弹销毁":
			_弹销毁 = true
		if 参数 == "--弹扩容":
			_弹扩容 = true
		if 参数 == "--弹镶嵌":
			_弹镶嵌 = true
	var 场景脚本 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场景脚本 == null:
		push_error("无法加载地图场景")
		quit(1)
		return
	_场景 = 场景脚本.instantiate()
	root.add_child(_场景)


## 把 `--塞物品` 的 id 当背包内容灌进去（只写内存，不发协议、不碰存档）。
func _灌() -> void:
	if _塞物品.is_empty():
		return
	# `--script` 入口里 autoload 标识符还没注册，只能用 root.get_node 拿。
	var 数据: Node = root.get_node("GameData")
	var 会话: Node = root.get_node("GameSession")
	会话.inventory.clear()
	for 序 in _塞物品.size():
		# `--塞物品` 支持 `id` 或 `id:数量`（数量>1 才会显堆叠数字，用来核对数量字的观感）。
		var 段 := String(_塞物品[序]).split(":", false)
		var 号 := String(段[0])
		var 件数 := int(段[1]) if 段.size() >= 2 else 1
		var 名 := String(数据.item_name(号))
		_名字表[号] = 名
		var 条目 := {
			"id": 号,
			"name": 名,
			"quantity": 件数,
			"bind_state": 0,
			"icon": String(数据.item_icon_path(号)),
		}
		# `--品质` 里填 `-` 表示**不写 aptitude 字段** —— 原版非装备物品就是没有这个属性
		# （`ItemWindowCell.showIcon` 外面那道 `hasOwnProperty("aptitude")` 判断）。
		if 序 < _品质.size() and _品质[序] != "-":
			条目["aptitude"] = int(_品质[序])
		会话.inventory.append(条目)
	print("截背包窗口：已灌入 %d 件道具（品质 %s）" % [_塞物品.size(), str(_品质)])


func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 < 8:
		return false
	if not _已就绪:
		if not _打开背包():
			return true
		if _页 != "背包":
			# 仓库不是底栏按钮，是背包窗口里的「随身仓库」（`会话.request_feature("NPC仓库")`）。
			var 仓 := _功能窗口.find_child("随身仓库", true, false) as Button
			if 仓 == null:
				push_error("背包窗口里没找到 随身仓库 按钮")
				quit(1)
				return true
			仓.pressed.emit()
		_已就绪 = true
		return false
	# ⚠️ 打开之后**必须多等几帧**再截图：窗口有滑入补间，同帧抓图会抓到还没落位的画面。
	if _帧 < 24:
		return false
	if _待截:
		return true
	if _弹扩容 and not _已点:
		_已点 = true
		var 扩 := _功能窗口.find_child("扩充", true, false) as Button
		if 扩 != null:
			扩.pressed.emit()
		_帧 = 24
		return false
	if _弹销毁 and not _已点:
		_已点 = true
		# 先点格子弹菜单，再点菜单里的「销毁」
		var 格 := _功能窗口.find_child("物品格_0", true, false) as Button
		if 格 != null and not 格.disabled:
			格.pressed.emit()
		for 节点 in _功能窗口.find_children("项_*", "Button", true, false):
			var 按钮 := 节点 as Button
			if 按钮 != null and 按钮.visible and 按钮.text == "销毁":
				按钮.pressed.emit()
				break
		_帧 = 24
		return false
	if _弹金额 and not _已点:
		_已点 = true
		var 存 := _功能窗口.find_child("存钱", true, false) as Button
		if 存 != null:
			存.pressed.emit()
		_帧 = 24
		return false
	if _弹镶嵌 and not _已点:
		_已点 = true
		var 格 := _功能窗口.find_child("物品格_0", true, false) as Button
		if 格 != null and not 格.disabled:
			格.pressed.emit()
		for 节点 in _功能窗口.find_children("项_*", "Button", true, false):
			var 按钮 := 节点 as Button
			if 按钮 != null and 按钮.visible and 按钮.text == "宝石镶嵌":
				按钮.pressed.emit()
				break
		_帧 = 24          # 再等若干帧让镶嵌窗摆位后再截
		return false
	if _点格 and not _已点:
		# 点第一个格子：原版是**左键单击**弹物品菜单（ItemWindowCell.singleClickHandler）。
		_已点 = true
		var 格 := _功能窗口.find_child("物品格_0", true, false) as Button
		if 格 != null and not 格.disabled:
			格.pressed.emit()
		var 菜单 := 功能窗口菜单()
		if 菜单 != null:
			print("  菜单 visible=%s pos=%s size=%s n=%d" % [菜单.visible, 菜单.position, 菜单.size, 菜单.get_child_count()])
		else:
			print("  找不到 物品菜单 节点")
		_帧 = 24
		return false
	_保存(_出.replace(".png", "_%s.png" % _页) if _页 != "背包" else (_出 if not _点格 else _出.replace(".png", "_菜单.png")))
	_待截 = true
	return false


func _打开背包() -> bool:
	_灌()
	_功能窗口 = _场景.get_node_or_null("窗口管理").call("取或建窗口", "背包")
	var 底栏 := _场景.get_node_or_null("技能面板/技能栏") as Control
	if _功能窗口 == null or 底栏 == null:
		push_error("缺少 功能窗口 或 底栏")
		quit(1)
		return false
	for 节点 in 底栏.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 != null and 按钮.tooltip_text == "背包":
			按钮.pressed.emit()
			print("截背包窗口：已打开背包窗口")
			return true
	push_error("底栏没找到 tooltip=背包 的按钮")
	quit(1)
	return false


func 功能窗口菜单() -> Control:
	return _功能窗口.find_child("物品菜单", true, false) as Control


func _保存(路径: String) -> void:
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		quit(1)
		return
	var 目录 := _出.get_base_dir()
	if not DirAccess.dir_exists_absolute(目录):
		DirAccess.make_dir_recursive_absolute(目录)
	图像.save_png(路径)
	# 把窗口内容区的全局矩形打出来——比对时拿它裁原版真机截图，靠肉眼量会一直差十几像素。
	var 内容 := _功能窗口.get_node_or_null("遮罩/主窗口/内容底") as Control
	if 内容 != null:
		var 矩形 := 内容.get_global_rect()
		print("截背包窗口：内容底全局矩形 x=%d y=%d w=%d h=%d"
			% [int(矩形.position.x), int(矩形.position.y), int(矩形.size.x), int(矩形.size.y)])
	var 页 := _功能窗口.get("_content") as Control
	if 页 != null:
		var 矩形 := 页.get_global_rect()
		print("截背包窗口：页面容器全局矩形 x=%d y=%d w=%d h=%d"
			% [int(矩形.position.x), int(矩形.position.y), int(矩形.size.x), int(矩形.size.y)])
	var 格 := _功能窗口.find_child("格子容器", true, false) as Control
	if 格 != null:
		var 矩形 := 格.get_global_rect()
		print("截背包窗口：格子容器全局矩形 x=%d y=%d w=%d h=%d"
			% [int(矩形.position.x), int(矩形.position.y), int(矩形.size.x), int(矩形.size.y)])
	print("截背包窗口：已存 %s" % 路径)
	if not _塞物品.is_empty():
		_报格子()
	quit(0)


## 把渲染出来的格子逐个报一遍：物品 id、图标是否真成了纹理、件数文字。
## 光看截图会漏"图标是 null 但格子看着像有底"这种情况。
func _报格子() -> void:
	var 空图 := 0
	var 错名: Array[String] = []
	for 序号 in range(_塞物品.size()):
		var 格 := _功能窗口.find_child("物品格_%d" % 序号, true, false) as Button
		if 格 == null:
			print("  格 %d（%s）找不到节点" % [序号, _塞物品[序号]])
			空图 += 1
			continue
		var 纹理 := 格.icon as Texture2D
		if 纹理 == null:
			空图 += 1
		var 号 := _塞物品[序号]
		if String(_名字表.get(号, "")) == str(号):
			错名.append(str(号))
		# 品质覆盖层实测：光看截图会漏"框在但贴图是空的"这类问题。
		var 框 := 格.get_node_or_null("资质框") as TextureRect
		var 光 := 格.get_node_or_null("流光") as AnimatedSprite2D
		var 框信 := "无节点"
		if 框 != null:
			框信 = "可见=%s 位置=%s 尺寸=%s 图=%s" % [
				框.visible, 框.position, 框.size,
				# ⚠️ `CompressedTexture2D` **没有** `get_resource_path()`，调它会在这条
				# print 中途报"Nonexistent function"、整个循环当场断掉（只报得出第 0 格）。
				"" if 框.texture == null else String(框.texture.resource_path).get_file()]
		var 光信 := "无节点"
		if 光 != null:
			# 位置要一起报：流光的注册点在**贴图中心**，光看"可见/帧数"看不出它摆歪了
			# （曾经因为素材带 117x115 空边、按左上角对齐，环跑到格子右下角）。
			光信 = "可见=%s 位置=%s 动画=%s 帧=%d" % [
				光.visible, 光.position, 光.animation,
				光.sprite_frames.get_frame_count(光.animation) if 光.sprite_frames != null else 0]
		print("  格 %d id=%s 名字=%s 物品id=%s 图标=%s | 资质框 %s | 流光 %s" % [
			序号, 号, String(_名字表.get(号, "?")), String(格.get("物品id")),
			"%dx%d" % [int(纹理.get_size().x), int(纹理.get_size().y)] if 纹理 != null else "无",
			框信, 光信])
	print("截背包窗口：格子实测 %d 个，图标为空 %d，名字就是 id 的 %s" % [_塞物品.size(), 空图, str(错名)])

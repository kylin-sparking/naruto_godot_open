extends SceneTree

## 有头探针：把「卡片套册」开出来，**递归回读**右列那五行/五格/进度条到底填没填上。
##
## 为什么要它：首版实机图里框架（标题/树/选中条/表头/卡格）都对，但「需要卡片 / 已提交·需要数量 /
## 掉落怪物」那五行看不见 ⇒ 可能是 `get_node` 路径错（生成器把嵌套件命名成 `面板/行1/行1_卡名`，
## 控制器里却按 `页/行1` 取），也可能是取数空。两种的修法完全不同，只能把**实际节点树**打出来。
##
## 跑法（**不能加 --headless**，要走真实开窗路径）：
##   "godot" --path . --script res://开发工具/验卡片套册页.gd

var _帧 := 0
var _窗: Node = null
var _管理: Node = null
var 场景: Node = null


func _名们(n: Node) -> String:
	var 出 := []
	for c in n.get_children():
		出.append(String(c.name))
	return ", ".join(出)


func _init() -> void:
	root.size = Vector2i(960, 560)


func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 8:
		return false
	if _窗 == null:
		# 自己把地图场景摆上（口径同 截木叶村NPC页.gd 的 `_步开图`）——
		# 窗口管理/功能窗口 都挂在地图场景下，没有这张场景就开不了任何一页。
		if 场景 == null:
			var 地图 := load("res://场景/地图/地图场景.tscn") as PackedScene
			场景 = 地图.instantiate()
			root.add_child(场景)
			return false
		_管理 = 场景.get_node_or_null("窗口管理")
		if _管理 == null:
			print("地图场景下没有 窗口管理（子节点 = %s）" % _名们(场景))
			return true
		_管理.call("打开", "卡片套册")
		_窗 = _管理.call("取或建窗口", "卡片套册") as Node
		if _窗 == null:
			print("取或建窗口(卡片套册) 给了 null")
			return true
		return false
	if _帧 < 14:
		return false
	_打()
	return true


func _找(n: Node, 名: String) -> Node:
	if n == null:
		return null
	if String(n.name) == 名:
		return n
	for c in n.get_children():
		var r := _找(c, 名)
		if r != null:
			return r
	return null


func _打() -> void:
	print("_current_page = %s" % String(_窗.get("_current_page")))
	var 面板 := _找(_窗, "面板")
	if 面板 == null:
		print("!! 整棵树里找不到 面板 ⇒ 页根本没建出来")
		print("DONE")
		return
	print("面板路径 = %s　size=%s　子节点=%d" % [_路(面板), str(面板.size), 面板.get_child_count()])
	for 名 in ["面板_套卡名", "面板_加成说明", "面板_背包数量", "面板_进度标题", "面板_收集进度"]:
		var n := 面板.get_node_or_null(名)
		if n == null:
			print("  %-14s 缺" % 名)
		elif n is Label:
			print("  %-14s 可见=%s 文本=%r" % [名, n.visible, (n as Label).text])
		else:
			print("  %-14s %s size=%s" % [名, n.get_class(), str((n as Control).size)])
	for i in 5:
		var 行 := 面板.get_node_or_null("行%d" % (i + 1)) as Control
		var 格 := 面板.get_node_or_null("卡格%d" % (i + 1)) as Control
		var 出 := []
		if 行 != null:
			for 子 in 行.get_children():
				# 三列 2026-10-04 已从 `Label` 换成 `RichTextLabel`（原版那三件支持逐字混色）
				# ⇒ 取文本不许写死类型，用 `get()` 兜住两种件。
				出.append("%s=%s" % [String(子.name), str(子.get("text"))])
		print("  行%d %s 位置=%s 子件[%s] ｜ 卡格%d %s 纹=%s" % [
			i + 1, "缺" if 行 == null else ("可见=%s" % 行.visible),
			str(行.position) if 行 != null else "-", " / ".join(出), i + 1,
			"缺" if 格 == null else ("可见=%s" % 格.visible),
			"无" if 格 == null or 格.texture == null else 格.texture.resource_path.get_file()])
	var 条 := 面板.get_node_or_null("面板_收集进度") as Control
	if 条 != null:
		var 填 := 条.get_node_or_null("裁剪/填充") as Control
		print("  进度条 宽=%s 填充.x=%s" % [条.size.x, 填.position.x if 填 != null else "缺填充"])
	var 树 := _找(_窗, "树") as ScrollContainer
	if 树 != null:
		var 列 := 树.get_node_or_null("树_内容") as Control
		if 列 != null:
			var 可 := 0
			for c in 列.get_children():
				可 += 1 if c.visible else 0
			print("  树 区宽=%s 内容=%s 行 %d（可见 %d）｜ 前 3 行 %s" % [
				str(树.size), str(列.size), 列.get_child_count(), 可,
				", ".join(列.get_children().slice(0, 3).map(func(x): return String(x.name)))])
	# 出图：整屏 + 窗口裁块（有头才拿得到视口图像，口径同 `godot-cli-verify-harness`）
	var 图 := root.get_texture().get_image()
	var 整屏 := 图.save_png("res://测试/截图/卡片套册/实机整屏.png")
	var 框: Rect2 = (_找(_窗, "主窗口") as Control).get_global_rect()
	# ⚠ 别用「新建空图 + `blit_rect`」：那样失败是**静默**的（文件根本不出现，也不报错）。
	#   `Image.crop()` 在 Godot 4 只收 (x,y) 两个参数、**尺寸沿用原图** ⇒ 也不是我要的；
	#   要"按矩形取一块"只有 `get_region(Rect2i)`。两个 `save_png` 的返回码都回读打印。
	var 裁 := 图.get_region(Rect2i(int(框.position.x), int(框.position.y), int(框.size.x), int(框.size.y)))
	var 整窗 := 裁.save_png("res://测试/截图/卡片套册/实机整窗.png")
	print("落盘返回码：整屏=%d 整窗=%d（0 才是 OK）" % [整屏, 整窗])
	print("已出图：测试/截图/卡片套册/实机整屏.png ＋ 实机整窗.png（框 %s）" % str(框))
	print("DONE")


func _路(n: Node) -> String:
	var 出 := [String(n.name)]
	var p: Node = n.get_parent()
	while p != null:
		出.push_front(String(p.name))
		p = p.get_parent()
	return "/".join(出)

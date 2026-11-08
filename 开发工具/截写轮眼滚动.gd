extends SceneTree

## 证据量具：写轮眼页那一列阶段钮**用滚轮能不能翻到后面五档**。
## 有头跑（无头拿不到视口图像）：
##   Godot --path . --script res://开发工具/截写轮眼滚动.gd -- --出目录=res://测试/截图/写轮眼滚动1025
## 判四件事（都是"改了没生效"那种假绿的对手）：
##  ① 滚轮事件真的让内容上移 —— 不是我手动设 `scroll_vertical` 设出来的
##  ② 滚到底时第 12 枚「净眼」整枚落在裁剪框里面（用户要的就是"后面的档看得到"）
##  ③ 框仍是原版 90×200：出条之后不许把整框撑宽（90 = 内容 71 + 条 19，见 `Box.as:127/255`）
##  ④ 滚前/滚后两张裁图真的有差异（没有差异 = 量具自己坏了，不许报通过）

var _出目录 := "res://测试/截图/写轮眼滚动1025"
var _帧 := 0
var _场景: Node = null
var _窗 = null
var _已就绪 := false
var _已开跑 := false
var _跑完了 := false
var _判数 := 0
var _红数 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and String(键值[0]) == "--出目录":
			_出目录 = String(键值[1])
	_场景 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(_场景)


func _判(对: bool, 话: String) -> void:
	_判数 += 1
	if not 对:
		_红数 += 1
		push_error("写轮眼滚动量具：" + 话)


func _process(_秒: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	if not _已就绪:
		var 会话: Node = root.get_node_or_null("/root/GameSession")
		会话.cultivation_states["写轮眼"] = {"stage": 3, "count": 40, "blessing": 0}
		var 管理: Node = _场景.get_node_or_null("窗口管理")
		_窗 = 管理.call("取或建窗口", "人物")
		管理.call("打开", "人物")
		_已就绪 = true
		return false
	if _帧 < 18:
		return false
	# `MainLoop._process` 返回 true 就是**立刻退出**，而 `_跑一遍()` 里全是 await
	# ⇒ 只能在它自己跑到 `收尾()` 之后再让它返回 true，否则只判到第一条就退。
	if not _已开跑:
		_已开跑 = true
		_跑一遍()
	return _跑完了


func _取页() -> Control:
	var 内容 := _窗.get("_content") as Control
	if 内容 == null:
		return null
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	var 面板 := 页面.get_node_or_null("人物扩展页") as Panel
	return null if 面板 == null else 面板.get_node_or_null("写轮眼内容") as Control


func _滚轮(下: bool) -> void:
	var 滚 := _取页().get_node_or_null("滚动按钮列表") as ScrollContainer
	var 中: Vector2 = 滚.get_global_rect().get_center()
	var 事 := InputEventMouseButton.new()
	事.button_index = MOUSE_BUTTON_WHEEL_DOWN if 下 else MOUSE_BUTTON_WHEEL_UP
	事.position = 中
	事.global_position = 中
	事.pressed = true
	root.push_input(事, true)


## 裁视口上这一块并（可选）存盘。坐标先与屏幕求交，免得被屏缘切掉时报错。
func _裁(框: Rect2, 名: String) -> Image:
	var 图 := root.get_texture().get_image()
	var 想 := Rect2i(int(框.position.x), int(框.position.y), int(框.size.x), int(框.size.y))
	var 屏 := Rect2i(0, 0, 图.get_width(), 图.get_height())
	var 交: Rect2i = 屏.intersection(想)
	var 块 := 图.get_region(交)
	if 名 != "":
		DirAccess.make_dir_recursive_absolute(_出目录)
		块.save_png(_出目录 + "/" + 名 + ".png")
	return 块


func _跑一遍() -> void:
	# 开窗默认停在「人物」那一页，而子页是**按需建**的 ⇒ 必须先切到 血继界限/写轮眼 才有那一页
	_窗.call("_set_character_main_tab", 2)
	await process_frame
	_窗.call("_set_character_sub_tab", 0)
	for 次 in 6:
		await process_frame
	var 页 := _取页()
	if 页 == null:
		_判(false, "取不到写轮眼页 ⇒ 后面一条都没判")
		收尾()
		return
	var 滚 := 页.get_node_or_null("滚动按钮列表") as ScrollContainer
	var 内 := 滚.get_node_or_null("阶段列表") as Control
	var 末 := 内.get_node_or_null("净眼") as Control
	var 首 := 内.get_node_or_null("单勾玉") as Control
	if 滚 == null or 内 == null or 末 == null or 首 == null:
		_判(false, "滚动框/内容/首末两枚钮 取不到 ⇒ 这一腿没判")
		收尾()
		return
	_判(absf(滚.size.x - 90.0) < 0.01, "裁剪框宽 %s ≠ 90：出了滚动条也不该把整框撑宽（90 = 内容 71 + 条 19）" % str(滚.size.x))
	_判(absf(滚.size.y - 200.0) < 0.01, "裁剪框高 %s ≠ 200（setSize(90,200)）" % str(滚.size.y))
	滚.scroll_vertical = 0
	await process_frame
	await process_frame
	var 框: Rect2 = 滚.get_global_rect()
	var 前 := _裁(框, "滚前")
	_判(末.global_position.y > 框.end.y, "没滚的时候第 12 枚就该在框外，实测 y=%s 而框底=%s ⇒ 那道裁剪没了"
		% [str(末.global_position.y), str(框.end.y)])
	for 次 in 6:
		_滚轮(true)
		await process_frame
		await process_frame
	_判(滚.scroll_vertical > 0.0, "连发 6 下滚轮之后 scroll_vertical 还是 0 ⇒ 滚轮这条路没生效")
	_判(内.position.y < 0.0, "滚轮之后内容没上移（position=%s）" % str(内.position))
	print("滚轮 6 下之后 scroll_vertical=", 滚.scroll_vertical, " 内容.position=", 内.position)
	滚.scroll_vertical = 999
	await process_frame
	await process_frame
	var 后 := _裁(框, "滚后")
	_判(末.global_position.y >= 框.position.y - 0.01 and 末.global_position.y + 末.size.y <= 框.end.y + 0.01,
		"滚到底时「净眼」%s..%s 没整枚落在框 %s..%s 里面" % [str(末.global_position.y),
			str(末.global_position.y + 末.size.y), str(框.position.y), str(框.end.y)])
	_判(首.global_position.y + 首.size.y < 框.position.y + 1.0,
		"滚到底时第 1 枚「单勾玉」该已经滚出框顶，实测底边=%s" % str(首.global_position.y + 首.size.y))
	var 差 := 0
	var 高 := mini(前.get_height(), 后.get_height())
	var 宽 := mini(前.get_width(), 后.get_width())
	for y in 高:
		for x in 宽:
			if 前.get_pixel(x, y) != 后.get_pixel(x, y):
				差 += 1
	_判(差 > 400, "滚前/滚后两张裁图只差 %d 个像素 ⇒ 这块画面其实没动（量具自己坏了）" % 差)
	print("滚前/滚后差异像素=", 差)
	收尾()


func 收尾() -> void:
	_跑完了 = true
	print("写轮眼滚动量具：判 %d 条 / 红 %d 条" % [_判数, _红数])
	quit(0 if _红数 == 0 else 1)

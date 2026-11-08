extends SceneTree

# 把功能窗口渲染成 PNG，用来肉眼核对贴图是否和原版一致。
# 注意：SceneTree 脚本里不能在 _initialize 中 await，会卡死，所以用 _process 数帧。

var _frames := 0
var _done := false
# 用 --page=背包 之类的参数指定要抓的页面
var _page := "背包"
var _open_page := "背包"
# --all 依次抓取全部页面；--dir=基线 指定输出子目录
var _queue: Array[String] = []
var _out_dir := "截图"
var _win: Node = null
# --点=<节点名>：开页稳定后先按一下这枚 Button，再抓帧（抓"点开才出现的东西"，
# 如装备打造 刻印页的「刻印图解」帮助窗）。
var _点钮 := ""
var _点了 := false

# 人物与装备强化是多子页窗口，抓图时需注入子页索引
const 人物子页 := {
	"人物": [0, 0],
	"手里剑": [0, 1],
	"结印": [0, 2],
	"八门": [1, 0],
	"柔拳": [1, 1],
	"寄坏之术": [1, 2],
	"写轮眼": [2, 0],
	"轮回六道": [2, 1],
}
const 装备打造子页 := {
	"装备强化": 0,
	"洗附加属性": 1,
	"洗附加数值": 2,
	"装备进阶": 3,
	"天生": 4,
	"刻印": 5,
	"精炼": 6,
}
const 设置子页 := {
	"系统设置": 0,
	"快捷键设置": 1,
	"更多设置": 2,
}


func _initialize() -> void:
	var 抓全部 := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			_page = arg.trim_prefix("--page=")
		elif arg.begins_with("--dir="):
			_out_dir = arg.trim_prefix("--dir=")
		elif arg.begins_with("--点="):
			_点钮 = arg.trim_prefix("--点=")
		elif arg == "--all":
			抓全部 = true

	if 抓全部:
		# 主窗口页面 + 两组子页，覆盖全部可抓表面。
		# 页面清单来自窗口尺寸表（唯一事实来源）。
		var 页面脚本 := load("res://脚本/界面/功能窗口.gd")
		for 名字 in 页面脚本._取窗口尺寸表():
			_queue.append(String(名字))
		for 名字 in 人物子页:
			if not _queue.has(名字):
				_queue.append(String(名字))
		for 名字 in 装备打造子页:
			if not _queue.has(名字):
				_queue.append(String(名字))
	else:
		_queue.append(_page)

	DirAccess.make_dir_recursive_absolute("res://测试/%s" % _out_dir)

	var scene: PackedScene = load("res://场景/界面/功能窗口.tscn")
	if scene == null:
		push_error("功能窗口.tscn 加载失败")
		_done = true
		quit(1)
		return

	_win = scene.instantiate()
	get_root().add_child(_win)
	_打开下一页()


func _打开下一页() -> void:
	_page = _queue[0]
	_open_page = _page
	if 人物子页.has(_page):
		_open_page = "人物"
		_win._character_main_tab = int(人物子页[_page][0])
		_win._character_sub_tab = int(人物子页[_page][1])
	elif 装备打造子页.has(_page):
		_open_page = "装备强化"
		_win._strengthen_tab = int(装备打造子页[_page])
	elif 设置子页.has(_page):
		_open_page = "设置"
		_win._settings_tab = int(设置子页[_page])
	_frames = 0
	_点了 = false
	# 窗口默认隐藏，必须调 open_page 才会显示
	_win.call_deferred("open_page", _open_page)


## 深度优先按名字找一枚 Button 并按下去。找到返回 true。
func _按(名: String) -> bool:
	var 栈: Array[Node] = [_win]
	while not 栈.is_empty():
		var 节: Node = 栈.pop_back()
		if 节 is Button and 节.name == 名:
			(节 as Button).pressed.emit()
			return true
		for 子 in 节.get_children():
			栈.append(子)
	return false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	# 等主题、九宫格和容器布局都稳定下来再抓帧
	if _frames < 8:
		return false
	# `--点=<钮名>`：先按一下再抓，并**重新数 8 帧**等它弹出来的东西稳住。
	if _点钮 != "" and not _点了:
		_点了 = true
		if not _按(_点钮):
			push_error("找不到要点的钮：%s" % _点钮)
		_frames = 0
		return false

	var viewport_texture := get_root().get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动不支持视口截图，请使用 Windows 显示驱动运行")
		_done = true
		return true
	var img := viewport_texture.get_image()
	if img == null:
		push_error("当前渲染驱动未返回视口图像")
		_done = true
		return true
	var err := img.save_png("res://测试/%s/截图_%s.png" % [_out_dir, _page])
	print("保存 ", _page, " 结果=", err, " 尺寸=", img.get_size())

	_queue.remove_at(0)
	if _queue.is_empty():
		_done = true
		return true
	_打开下一页()
	return false

extends SceneTree

## 逐页体检功能窗口的布局，报出三类几何问题：
##   越界   —— 可见控件超出窗口外框（画到边框外或被裁掉）
##   空白   —— 内容包围盒离窗口底/右边太远，说明外框比内容高/宽
##   压标题 —— 内容控件和标题文字或关闭按钮矩形相交
##
## 运行：
##   Godot --headless --path . --script res://测试/窗口布局体检.gd -- [--空白阈值=24]

const 窗口脚本 := preload("res://脚本/界面/功能窗口.gd")

var _frames := 0
var _done := false
var _队列: Array[String] = []
var _空白阈值 := 24.0
## `--列出=页面名`：把那一页撑出包围盒的控件点名打出来（排查用）。
var _列出 := ""
var _win: Node = null
var _报告: Array[String] = []

## ⚠️ **已知问题（放行清单）** —— 只放行**逐字完全相同**的行，任何数字变了都会红。
##
## 为什么要有它：这两条从 §3.25.5 就挂着，它们让 `验证全部.ps1`（项目的主质量门）
## **一直过不去** —— 而门红久了就没人看，比不设门还坏。
## 所以把它们**显式登记**下来：主门能整条跑通，而**新出现的布局问题照样拦得住**。
##
## ⚠️ 这**不是修好**，只是登记。真要清掉得先拿到**原版这两个窗口的几何真值** ——
##   那是模块活，见 §3.25.5 待办第 4 条。
## ⚠️ 逐字匹配是故意的：数字一变（比如谁把背包改宽了）就**不会**落进这个清单，照样红。
const 已知问题 := [
	# 2026-10-01 整表清空："越界 背包"当场修掉（分隔线用回自然宽 252，原版 LineHPicF
	# 从不设宽，见 背包窗口.tscn 注）；"空白 宠物"实测已不再报（§3.62 宠物重建后治好，
	# 登记忘了撤）。**再出现任何问题就老实修，别往这里塞。**
	# 2026-10-04 并「木叶村NPC页」登记两条 —— **是原版真值、不是我们摆错**（作者 §2⑩）：
	# 护送任务那枚「为止」`MGlowLabel` 的**盒**宽 60、x=523 ⇒ 右缘 583 > 578（`HuSongQuestWindow.as:242-248`），
	# 墨迹只有两个字、不越框；周试炼那条同理（363 宽的文字盒）。照真值留着。
	"越界 护送任务     左-13 上-35 右+5 下-8（外框 578x342）",
	"越界 周试炼任务    左-8 上-38 右+16 下-5（外框 355x367）",
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--空白阈值="):
			_空白阈值 = float(arg.trim_prefix("--空白阈值="))
		elif arg.begins_with("--列出="):
			_列出 = arg.trim_prefix("--列出=")
	for 名字 in 窗口脚本._取窗口尺寸表():
		_队列.append(String(名字))
	# ⚠ 队列空 = 尺寸表取不到（多半是某个脚本编译失败 ⇒ `功能窗口.gd` 的 preload 断了）。
	#   没有这道闸时 `_process` 会拿 `_队列[0]` 空转，**每 8 帧刷一条越界错**、日志涨到十几 MB
	#   而进程永不退出（2026-10-15 实测：人物窗口.gd 一个 parse error 就这么来的）。
	#   门必须红得下来、不能崩 —— 这里直接点名原因再退出（第 15 条）。
	if _队列.is_empty():
		push_error("窗口布局体检：尺寸表为空（`功能窗口._取窗口尺寸表()` 取不到）—— 多半是某脚本编译失败，先跑 脚本加载回归测试")
		_done = true
		quit(1)
		return
	var scene: PackedScene = load("res://场景/界面/功能窗口.tscn")
	if scene == null:
		push_error("功能窗口.tscn 加载失败")
		_done = true
		quit(1)
		return
	_win = scene.instantiate()
	get_root().add_child(_win)
	_win.call_deferred("open_page", _队列[0])


func _可见(c: Control) -> bool:
	var 节点: Node = c
	while 节点 is Control:
		if not (节点 as Control).visible:
			return false
		节点 = 节点.get_parent()
	return true


## 计入包围盒的控件：叶子控件，外加"自己会画出边框"的容器（Panel/NinePatchRect 等）。
## 纯 Control 容器铺满外框是布局手段、不产生像素，把它算进来会让包围盒恒等于外框，
## 空白检查永远不触发；但 Panel 类容器的下沿就是玩家看得见的内容下沿，必须计入，
## 否则像"任务"这种把列表放在 Panel 里的页面会被误报成底部大片空白。
func _计入包围盒(c: Control) -> bool:
	for child in c.get_children():
		if child is Control:
			return c is Panel or c is NinePatchRect or c is TextureRect
	return true


func _收集(node: Node, 盒: Array, 名单: Array) -> void:
	if node is Control:
		var c := node as Control
		var r := c.get_global_rect()
		if _可见(c) and r.size.x > 0.0 and r.size.y > 0.0 and _计入包围盒(c):
			名单.append([String(c.name), r])
			if 盒[0] == null:
				盒[0] = r
			else:
				盒[0] = (盒[0] as Rect2).merge(r)
	# ⚠️ **被裁剪的容器，其子节点不计入包围盒** —— ScrollContainer 自带 `clip_contents = true`，
	#    子节点画到框外是**被裁掉**的（列表比视口长本来就该出滚动条）。
	#    把它们算进来是**检查本身**的错，不是版式的错：2026-09-27 合并活跃度页时实测，
	#    15 行任务在 `内容底/任务面板/任务滚动区` 里撑到 y≈790，而窗口只有 500 高，
	#    报出"越界 下+292"——可那 15 行玩家一像素也看不到。
	#    2026-10-03 合并意志页扩成通用判据：手搓滚动（原版 `fl.controls.List`/`TextArea2`
	#    的移植形态）用的就是 `Control + clip_contents = true`（`意志介绍/列表区`），
	#    放行条件看**属性**而不是看类型 —— 被裁掉的都看不见，类型不重要。
	#    ⚠️ 只放行**自己**被裁的子节点；容器本身的矩形照旧计入（它的边就是玩家看得见的可视边）。
	if (node is ScrollContainer) or (node is Control and (node as Control).clip_contents):
		return
	for child in node.get_children():
		_收集(child, 盒, 名单)


const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")


## 竞技场这扇按原版 `PvpWindow.initView:280-285` 的写法是「开窗即发上行 0 + `_panel.visible=false`」，
## 离线跑没有服务端 ⇒ 那一发永远不来，页一直是空的（10-24 这道门与 `窗口行为契约体检` 同时红在这条）。
## 喂 `数据/界面/竞技场夹具.json` 里那发**真服务端原文**（`NARUTO_PACKET_TRACE=1` 抓的），
## 页走它平时的腿显形 ⇒ 体检量到的是"有数据的那一版版式"，不是被削弱成"量空页"。
func _竞技场面板原文() -> String:
	var 解 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/竞技场夹具.json"))
	if 解 == null:
		return ""
	return String((解 as Dictionary).get("原文", {}).get("面板", ""))


func _喂竞技场(页名: String) -> void:
	var 后: Node = root.get_node_or_null("BackendConnection")
	if 后 == null:
		_报告.append("%s：取不到 BackendConnection ⇒ 没法喂面板帧" % 页名)
		return
	竞技场窗脚本.挂全局(后)		# 运行期这一句归 `窗口管理._ready`
	后.call("_handle_bridge_text", _竞技场面板原文())
	if 竞技场窗脚本.候选.is_empty():
		_报告.append("%s：面板帧没解出候选 ⇒ 夹具串与服务端口径脱节了" % 页名)


func _体检(页面: String) -> void:
	var 窗口 := _win.get_node_or_null("遮罩/主窗口") as Control
	var 容器 := _win.get_node_or_null("遮罩/主窗口/页面容器") as Control
	var 标题 := _win.get_node_or_null("遮罩/主窗口/标题") as Control
	var 关闭 := _win.get_node_or_null("遮罩/主窗口/关闭按钮") as Control
	if 窗口 == null or 容器 == null:
		_报告.append("%s：窗口节点缺失" % 页面)
		return

	var 外框 := 窗口.get_global_rect()
	var 盒: Array = [null]
	var 名单: Array = []
	_收集(容器, 盒, 名单)
	if 盒[0] == null:
		# 「家族」未入族时主窗内容为空是**真值**（`FM.as:1222-1239` 二选一：只有列表窗）。
		# 入族时照旧报 —— 这条豁免**只对"未入族"这一支**生效。
		var 会话 := get_root().get_node_or_null("GameSession")
		var 在族 := 会话 != null and bool((会话.get("guild") as Dictionary).get("joined", false))
		if not (页面 == "家族" and not 在族):
			_报告.append("%s：页面容器内没有可见控件" % 页面)
		return
	var 内容盒: Rect2 = 盒[0]

	# 越界：内容画到了外框之外
	var 出左 := 外框.position.x - 内容盒.position.x
	var 出上 := 外框.position.y - 内容盒.position.y
	var 出右 := 内容盒.end.x - 外框.end.x
	var 出下 := 内容盒.end.y - 外框.end.y
	if maxf(maxf(出左, 出上), maxf(出右, 出下)) > 1.0:
		_报告.append("越界 %-8s 左%+.0f 上%+.0f 右%+.0f 下%+.0f（外框 %.0fx%.0f）" % [
			页面, 出左, 出上, 出右, 出下, 外框.size.x, 外框.size.y,
		])
		# `--列出=页面名` 时把**撑出包围盒的那几个控件**点名。
		# 光看"左-6 上-39"这种数字没法定位是谁（2026-09-22 为了查这一条，
		# 在别处绕了好几圈）；名单本来就在手里，打出来是一行的事。
		if 页面 == _列出:
			print("--- %s 的可见控件名单（容器局部坐标）---" % 页面)
			for 项 in 名单:
				var r: Rect2 = 项[1]
				if r.position.x < 外框.position.x - 0.5 or r.position.y < 外框.position.y - 0.5 \
						or r.end.x > 外框.end.x + 0.5 or r.end.y > 外框.end.y + 0.5:
					print("    %s 局部=(%.0f,%.0f) 尺寸=(%.0f,%.0f)" % [
						项[0], r.position.x - 外框.position.x, r.position.y - 外框.position.y,
						r.size.x, r.size.y,
					])

	# 空白：内容没铺满 AS3 的可用内容区。跟外框比会把天生的边框（上 38、下 30、左右 8）
	# 也算成空白，每个页面都白挨 30px，所以这里跟内容区下沿/右沿比。
	var 内容区 := Rect2(
		外框.position + Vector2(8.0, 38.0),
		外框.size - Vector2(16.0, 68.0),
	)
	var 底空 := 内容区.end.y - 内容盒.end.y
	var 右空 := 内容区.end.x - 内容盒.end.x
	if 底空 > _空白阈值 or 右空 > _空白阈值:
		_报告.append("空白 %-8s 底%.0f 右%.0f（外框 %.0fx%.0f，内容区 %.0fx%.0f，内容 %.0fx%.0f）" % [
			页面, 底空, 右空, 外框.size.x, 外框.size.y,
			内容区.size.x, 内容区.size.y, 内容盒.size.x, 内容盒.size.y,
		])

	# 压标题：内容控件盖住标题文字或关闭按钮
	for 头: Control in [标题, 关闭]:
		if 头 == null or not _可见(头):
			continue
		var 头框 := 头.get_global_rect()
		var 撞: Array[String] = []
		for 项 in 名单:
			var r: Rect2 = 项[1]
			# 大块底图/背景铺到标题栏下面是原版做法（标题画在底图之上），不算压标题。
			# 高度拿内容区比、不拿外框比：矮窗口（如兑换 420x150）边框占掉的比例大，
			# 用外框当分母会让底图差几个像素就不算底图，白报一条压标题。
			if r.size.x >= 外框.size.x * 0.8 and r.size.y >= 内容区.size.y * 0.8:
				continue
			if r.intersects(头框):
				撞.append(String(项[0]))
		if not 撞.is_empty():
			_报告.append("压%s %-8s 撞上 %s" % [
				"标题" if 头 == 标题 else "关闭", 页面, ", ".join(撞),
			])


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames < 8:
		return false
	if String(_队列[0]) == "竞技场":
		_喂竞技场("竞技场")
	_体检(_队列[0])
	_队列.remove_at(0)
	if _队列.is_empty():
		_done = true
		print("=== 窗口布局体检（空白阈值 %.0f px）===" % _空白阈值)
		var 未知: Array[String] = []
		for 行 in _报告:
			if 行 in 已知问题:
				print("（已知，放行）%s" % 行)
			else:
				未知.append(行)
				print(行)
		print("\n共 %d 条（其中已知 %d 条）" % [_报告.size(), _报告.size() - 未知.size()])
		quit(1 if not 未知.is_empty() else 0)
		return false
	_frames = 0
	_win.call_deferred("open_page", _队列[0])
	return false

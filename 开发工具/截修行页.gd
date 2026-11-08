extends SceneTree

## 「修行设定与收益 + 领取修行收益」两扇的**有头**外观量具：拍整屏 + 按窗口矩形各裁一张（1:1 与 3 倍）。
##
## 为什么单开一支：这一页要判的是**外观**（原版对照图 本地原版对照图 里那两扇），
## 逐件几何已经有 `测试/修行收益页回归测试.gd` 钉着；这里只出给人眼看的裁图。
##
## ⚠ 不能加 `--headless`（无头拿不到视口图像）。
## 用法：Godot --path . --script res://开发工具/截修行页.gd -- --出目录=res://测试/截图/修行收益

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "领取修行收益"
const 密卷id := "16000003"

var 出目录 := ""
var 帧 := 0
var 队列: Array = []
var 格矩形 := Rect2()		# 密卷格在屏幕上的矩形（判灰要用，跑完就丢）
var 前一张: Image = null		# 「无卷」那一拍（套灰）
var 塞进去 := false			# 夹具有没有动过 inventory ⇒ 收尾要摘回去
var 红 := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--出目录="):
			出目录 = String(a).trim_prefix("--出目录=")
	if 出目录.is_empty():
		出目录 = "res://测试/截图/修行收益"
	DirAccess.make_dir_recursive_absolute(出目录 + "/证据")
	root.size = Vector2i(960, 560)
	call_deferred("_起手")


func _起手() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	队列.append(_开窗.bind(场景))
	队列.append(_拍.bind("无卷"))
	队列.append(_存基准.bind(场景))
	队列.append(_真点双倍.bind(场景))
	队列.append(_塞一枚密卷.bind(场景))
	队列.append(_重开.bind(场景))
	队列.append(_拍.bind("有卷"))
	队列.append(_判套灰.bind(场景))
	队列.append(_真点单倍.bind(场景))
	队列.append(_裁两扇.bind(场景))
	队列.append(_收尾)


## 把鼠标分两跳移到某件中心再真点（同一帧连发两条 motion 只会按最后一条做拾取 ⇒
## 大距离瞬移不触发 `mouse_entered`，实测踩过）。返回钮心。
func _移并点(件: Control) -> Vector2:
	var 心: Vector2 = 件.get_global_rect().get_center()
	var 当前 := Vector2(10.0, 10.0)
	for i in 2:
		var 到 := 当前.lerp(心, 0.5) if i == 0 else 心
		var 移 := InputEventMouseMotion.new()
		移.position = 到
		移.global_position = 到
		root.push_input(移)
		await process_frame
		await process_frame
		当前 = 到
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 心
	按.global_position = 心
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 心
	放.global_position = 心
	root.push_input(放)
	return 心


func _页件(场景: Node, 件名: String) -> Control:
	var 窗们: Dictionary = (场景.get_node_or_null("窗口管理")).get("_窗口们") as Dictionary
	var 窗: Node = 窗们.get(页名) as Node
	if 窗 == null:
		return null
	var 容: Node = 窗.get_node_or_null("遮罩/主窗口/页面容器")
	if 容 == null or 容.get_child_count() == 0:
		return null
	return (容.get_child(容.get_child_count() - 1) as Control).get_node_or_null(件名) as Control


## ★ 用户 10-20 报的"按钮点击无反应无效果"这一支：背包里没卷点「双倍领取」，
## 原版 `LingquBiguanShouyi.as:200-207` 要弹 `MDialog`「很抱歉,你的背包里没有修行密卷」。
## 判法 = 真 `push_input` 点下去 + **节点与文案**（主证）+ 暗层把屏幕压暗（辅证）。
## ⚠ 辅证只许看"整屏变暗"这一件事：这张图上有雨/云/怪物在动，**任何区域两拍都会有差**
##   ⇒ 拿"差了多少像素"当"字画出来了"的证据 = 假判（实测整屏差 51 万像素，全是天气）。
func _真点双倍(场景: Node) -> void:
	var 钮 := _页件(场景, "双倍领取") as Button
	if 钮 == null:
		_判(false, "找不到「双倍领取」⇒ 这一支没量到")
		return
	var 前 := root.get_texture().get_image()
	var 心 := await _移并点(钮)
	await process_frame
	await process_frame
	await process_frame
	var 窗: Node = (场景.get_node_or_null("窗口管理")).get("_窗口们").get(页名) as Node
	var 弹 := 窗.get_node_or_null("遮罩/消息确认框")
	var 文: RichTextLabel = null
	if 弹 != null:
		文 = 弹.get_node_or_null("主体/正文") as RichTextLabel
	var 后 := root.get_texture().get_image()
	var 暗了 := 0
	for i in range(0, 960 * 560, 37):
		var a := 前.get_pixel(i % 960, i / 960)
		var b := 后.get_pixel(i % 960, i / 960)
		if (a.r + a.g + a.b) - (b.r + b.g + b.b) > 0.06:
			暗了 += 1
	print("  真点了双倍领取（%s）⇒ 弹出节点 %s、正文「%s」、采样点里 %d 个被压暗"
			% [str(心), "在" if 弹 != null else "查无", 文.text if 文 != null else "—", 暗了])
	_判(弹 != null, "缺卷点双倍**真弹出了 MDialog**（`遮罩/消息确认框` 挂上了）")
	_判(文 != null and 文.text.contains("很抱歉") and 文.text.contains("修行密卷"),
			"弹的就是原版那句「很抱歉,你的背包里没有修行密卷」（`CN.LINGQU_SHOUYI_SORRY_XIUXINGFU`）")
	_判(暗了 > 40, "整屏被 50%% 暗层压暗（采样 %d 个里 %d 个变暗）⇒ 玩家一定看得见" % [int(960 * 560 / 37), 暗了])
	_拍("缺卷弹窗")
	## ⚠ 不收掉它，下一支「单倍领取」的点击会被这层全屏 STOP 遮罩吃掉（实测通知 0 次 = 假红）。
	if 弹 != null:
		弹.queue_free()
		await process_frame
		await process_frame


## ★ 离线点「单倍领取」：`request_修行收益领取` 发不出去 ⇒ 不许关窗、不许把数字刷 0，
## 但**必须给玩家一个看得见的说法**（10-20 之前写进标题条里那枚深灰 `后端状态` 标签 = 看不见）。
## 判法 = ① 收到 `notification_requested` 一次；② 两扇还开着；③ 屏幕真变了（那行字画出来了）。
var _通知文本: Array = []


func _真点单倍(场景: Node) -> void:
	var 会: Node = root.get_node_or_null("/root/GameSession")
	会.notification_requested.connect(func(文本: String) -> void: _通知文本.append(文本))
	var 钮 := _页件(场景, "单倍领取") as Button
	if 钮 == null:
		_判(false, "找不到「单倍领取」⇒ 离线那一支没量到")
		return
	var 心 := await _移并点(钮)
	await process_frame
	await process_frame
	await process_frame
	var 管: Node = 场景.get_node_or_null("窗口管理")
	var 窗们: Dictionary = 管.get("_窗口们") as Dictionary
	var 还开着: Array = []
	for 页 in 窗们:
		var 窗: Node = 窗们[页] as Node
		if (窗.get_node("遮罩") as CanvasItem).visible:
			还开着.append(页)
	print("  真点了单倍领取（%s）⇒ 通知 %s、还开着 %s" % [str(心), str(_通知文本), str(还开着)])
	_判(_通知文本.size() >= 1,
			"离线点单倍**真发了通知**（走聊天那条看得见的口子，不是只写进标题条里那枚深灰标签）")
	_判(_通知文本.any(func(t): return String(t).contains("离线")),
			"通知文案说的是「离线」这件事，实际 %s" % str(_通知文本))
	_判(还开着.size() == 2, "离线**不许关窗**（关了就等于假装领到了）⇒ 现在两扇还开着")


func _process(_d: float) -> bool:
	帧 += 1
	if 队列.is_empty():
		return 帧 > 40
	if 帧 % 4 != 0:
		return false
	var 步: Callable = 队列.pop_front()
	步.call()
	return false


func _开窗(场景: Node) -> void:
	var 管: Node = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		print("红：地图场景下没有 窗口管理")
		return
	管.call("全部关闭")
	管.call("打开", 页名)
	print("点了「%s」⇒ 已开窗：%s" % [页名, str((管.get("_窗口们") as Dictionary).keys())])


func _拍(名: String) -> void:
	var 图 := root.get_texture().get_image()
	var 路 := 出目录 + "/证据/整屏_" + 名 + ".png"
	图.save_png(路)
	print("拍了 %s（%dx%d）" % [路, 图.get_width(), 图.get_height()])


## 记下密卷格的屏幕矩形 + 存「无卷」那一拍（后面 A/B 就比这一块）。
func _存基准(场景: Node) -> void:
	var 格 := _格(场景)
	if 格 == null:
		_判(false, "找不到 密卷格 ⇒ 套灰那条没量到")
		return
	格矩形 = 格.get_global_rect()
	前一张 = root.get_texture().get_image()
	print("密卷格屏幕矩形 = %s" % str(格矩形))


func _格(场景: Node) -> Control:
	var 窗: Node = (场景.get_node_or_null("窗口管理")).get("_窗口们").get(页名) as Node
	if 窗 == null:
		return null
	var 容: Node = 窗.get_node_or_null("遮罩/主窗口/页面容器")
	if 容 == null or 容.get_child_count() == 0:
		return null
	return (容.get_child(容.get_child_count() - 1) as Control).get_node_or_null("密卷格") as Control


## 夹具：往会话背包里塞一枚修行密卷（只改内存，收尾摘回去 ⇒ 不落存档）。
func _塞一枚密卷(场景: Node) -> void:
	var 会: Node = root.get_node_or_null("/root/GameSession")
	var 背: Array = 会.get("inventory") as Array
	背.append({"id": 密卷id, "quantity": 1})
	塞进去 = true
	print("塞了一枚 %s ⇒ 背包里现在 %d 件" % [密卷id, 背.size()])


func _重开(场景: Node) -> void:
	var 管: Node = 场景.get_node_or_null("窗口管理")
	管.call("全部关闭")
	管.call("打开", 页名)


## ★ 这一页最容易假绿的一处：**没卷 ⇒ 整格套灰**（`LingquBiguanShouyi.as:189-191`
##   → `ItemWindowCell.as:77-87` 把 `Style.getDisableFilter()` 挂在 `itemIcon` = 格底本体上）。
## 判法 = **同一块矩形 A/B 两拍数差异像素**：只查 `material != null` 照不到"着色器根本没生效"
## （§3.18.9 那条老坑）。取**角标之上**那半格 ⇒ 差异只可能来自灰，不来自多出来的那个「1」。
func _判套灰(场景: Node) -> void:
	if 前一张 == null or 格矩形.size.x <= 0.0:
		_判(false, "基准那一拍没存到 ⇒ 无从比")
		return
	var 后 := root.get_texture().get_image()
	var 上 := int(round(格矩形.position.y))
	var 下 := int(round(格矩形.position.y + 22.0))		# 角标 tf 从 y=24 起，这 22 行里没有它
	var 左 := int(round(格矩形.position.x))
	var 右 := int(round(格矩形.position.x + 格矩形.size.x))
	var 差 := 0
	var 总 := 0
	for y in range(上, 下):
		for x in range(左, 右):
			if x < 0 or y < 0 or x >= 后.get_width() or y >= 后.get_height():
				continue
			总 += 1
			if 前一张.get_pixel(x, y) != 后.get_pixel(x, y):
				差 += 1
	print("  两拍比了 %d 个像素（格内 y 0..22 那一条）⇒ 差 %d 个" % [总, 差])
	_判(总 > 300 and 差 * 4 > 总, "有卷那一拍整格**真的换了画法**（差 %.0f%%）⇒ 灰是打在像素上的"
			% (100.0 * 差 / maxf(总, 1.0)))
	_裁(前一张, Rect2(格矩形.position, Vector2(格矩形.size.x, 22.0)), 出目录 + "/证据/格_无卷套灰_8x.png", 8)
	_裁(后, Rect2(格矩形.position, Vector2(格矩形.size.x, 22.0)), 出目录 + "/证据/格_有卷原色_8x.png", 8)


func _判(对: bool, 说明: String) -> void:
	if 对:
		print("  ✓ %s" % 说明)
	else:
		红 += 1
		print("  ✗ 红 %d：%s" % [红, 说明])


## 两扇各裁一张：1:1 原样 + 3 倍 NEAREST（判发丝级的皮边距要看 3 倍那张）。
func _裁两扇(场景: Node) -> void:
	var 管: Node = 场景.get_node_or_null("窗口管理")
	var 窗们: Dictionary = 管.get("_窗口们") as Dictionary
	var 屏 := root.get_texture().get_image()
	var 数 := 0
	for 页 in 窗们:
		var 窗: Node = 窗们[页] as Node
		var 壳: Control = 窗.get_node_or_null("遮罩/主窗口") as Control
		if 壳 == null:
			print("  %s：没有 遮罩/主窗口 ⇒ 裁不了" % 页)
			continue
		var 全: Rect2 = 壳.get_global_rect()
		print("  %s：屏幕矩形 %s" % [页, str(全)])
		_裁(屏, 全, 出目录 + "/证据/窗_" + String(页) + ".png")
		_裁(屏, 全, 出目录 + "/证据/窗_" + String(页) + "_3x.png", 3)
		数 += 1
	print("裁了两扇里的 %d 扇（成对开窗 ⇒ 应为 2）" % 数)
	if 数 != 2:
		push_error("成对开窗没成对：只裁到 %d 扇" % 数)


func _裁(屏: Image, 框: Rect2, 路: String, 倍 := 1) -> void:
	var 左 := int(round(框.position.x))
	var 上 := int(round(框.position.y))
	var 宽 := int(round(框.size.x))
	var 高 := int(round(框.size.y))
	宽 = mini(宽, 屏.get_width() - 左)
	高 = mini(高, 屏.get_height() - 上)
	var 小 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	for y in 高:
		for x in 宽:
			小.set_pixel(x, y, 屏.get_pixel(左 + x, 上 + y))
	if 倍 != 1:
		小.resize(宽 * 倍, 高 * 倍, Image.INTERPOLATE_NEAREST)
	小.save_png(路)
	print("    写了 %s（%dx%d，%d 倍）" % [路, 小.get_width(), 小.get_height(), 倍])


func _收尾() -> void:
	## 夹具还原：塞进去的那一枚必须摘掉（本量具不许落存档，也不给下一扇门留脏背包）。
	if 塞进去:
		var 背: Array = root.get_node_or_null("/root/GameSession").get("inventory") as Array
		for i in range(背.size() - 1, -1, -1):
			if String((背[i] as Dictionary).get("id", "")) == 密卷id:
				背.remove_at(i)
		print("夹具已摘：%s" % 密卷id)
	print("截图落在 %s/证据" % 出目录)
	print("修行页外观量具：红 %d" % 红)
	quit(0 if 红 == 0 else 1)

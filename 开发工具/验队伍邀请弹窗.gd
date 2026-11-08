extends SceneTree
## 有头像素证据：**托盘那一格点下去，屏幕上到底有没有东西出现**。
## 为什么必须有这道：我连续三版都用"节点存在/层号够高"当判据，实机三次"点了没反应"。
## 层号只是"应该看得见"，**看得见与否只能数像素**。
##
## 判据：点之前 / 点之后各拍一张视口图，数**中间区域**有多少像素不同；
##       弹窗（带半透明压暗 + 白框正文）必然让几十万像素变化；"没弹窗"时差异恒为 0。
##
## 跑法（**不能加 --headless**，无头拿不到视口图像）：
##   Godot_v4.7.2-stable_win64.exe --path . --script res://开发工具/验队伍邀请弹窗.gd

const 窗口管理场景 := "res://场景/界面/窗口管理.tscn"
const 队伍窗 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
const 后端脚本 := preload("res://脚本/单例/后端连接.gd")

var 失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _记(名: String, 过: bool, 附: String = "") -> void:
	print(("  ok  " if 过 else "  ✗  ") + 名 + ("" if 附.is_empty() else "  " + 附))
	if not 过:
		失败.append(名)


func _等帧(n: int) -> void:
	for i in n:
		await process_frame


func _拍() -> Image:
	return root.get_texture().get_image()


func _差像素(a: Image, b: Image, 框: Rect2i) -> int:
	if a == null or b == null:
		return -1
	var n := 0
	var 右 := mini(框.end.x, mini(a.get_width(), b.get_width()))
	var 下 := mini(框.end.y, mini(a.get_height(), b.get_height()))
	for y in range(maxi(框.position.y, 0), 下):
		for x in range(maxi(框.position.x, 0), 右):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _找钮(根: Node, 文字: String) -> Control:
	## ⚠ 这一族的钮是 **`TextureButton`**（不是 `Button`），文字在**子 Label** 里、
	##   节点自己的 `text` 属性根本不存在 ⇒ 两样都要认（实测踩过：只找 Button 恒为 null）。
	for n in 根.find_children("*", "", true, false):
		if not (n is TextureButton or n is Button):
			continue
		var 钮 := n as Control
		if n is Button and (n as Button).text == 文字:
			return 钮
		for l in 钮.find_children("*", "Label", true, false):
			if (l as Label).text == 文字:
				return 钮
	return null


func _点(件: Control) -> void:
	## 真鼠标按下/抬起（和玩家点的完全同一条输入链）。
	var 心 := 件.get_global_rect().get_center()
	for 按下 in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = 按下
		e.position = 心
		e.global_position = 心
		root.push_input(e)
		await _等帧(2)


func _跑() -> void:
	var 视口 := root.size
	print("视口 %s" % 视口)
	## 托盘在 (380,0) 40×40 起，格宽 40 —— 中间那块正好是屏幕正中
	var 框 := Rect2i(int(视口.x * 0.12), int(视口.y * 0.10), int(视口.x * 0.76), int(视口.y * 0.80))

	var 管理 := (load(窗口管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	await _等帧(4)
	var 盘 := 管理.get_node_or_null("邀请托盘")
	if 盘 == null:
		_记("窗口管理里找不到邀请托盘", false)
		print("验队伍邀请弹窗：有红 %d 条" % 失败.size())
		quit(1)
		return
	盘.call("清空")
	## ⚠ 数据必须从**真后端解析**的 `59:4` 文本帧来。手写 `{"troopId":4242,...}` 会把
	##   "后端没并出顶层 party_id/inviter_name" 这类真 bug 整条盖掉
	##   （实机症状：弹窗名字空、确定发 `120:3:0`、队伍进不去）。
	var 真后: Node = 后端脚本.new()
	root.add_child(真后)
	var 收到: Array = []
	真后.connect("party_state_received", func(s: Dictionary) -> void: 收到.append(s))
	真后.call("_handle_party_text", 59, PackedStringArray(["59", "4", "4242", "队长甲"]))
	_记("真 `59:4` 文本帧解出 1 条 state", 收到.size() == 1, str(收到.size()))
	if 收到.is_empty():
		print("验队伍邀请弹窗：有红 %d 条" % 失败.size())
		quit(1)
		return
	队伍窗.服务端队伍帧(收到[0])
	await _等帧(4)
	var 格们: Dictionary = 盘.call("格们")
	_记("托盘里有一格", 格们.size() == 1, str(格们.size()))
	if 格们.is_empty():
		print("验队伍邀请弹窗：有红 %d 条" % 失败.size())
		quit(1)
		return
	var 格 := 格们.values()[0] as Control
	var 格据: Dictionary = 格.get("数据") as Dictionary
	_记("托盘格拿到真队号/真邀请人（不是 0/空）",
		int(格据.get("troopId", 0)) == 4242 and String(格据.get("captainName", "")) == "队长甲",
		str(格据))
	await _等帧(2)
	var 前 := _拍()
	_记("拍到了点之前的画面", 前 != null, "" if 前 != null else "视口图拿不到（是不是加了 --headless？）")

	# 真鼠标：按下 → 抬起（和玩家点的完全同一条输入链）
	var 心 := 格.get_global_rect().get_center()
	var 下 := InputEventMouseButton.new()
	下.button_index = MOUSE_BUTTON_LEFT
	下.pressed = true
	下.position = 心
	下.global_position = 心
	root.push_input(下)
	await _等帧(2)
	var 上 := InputEventMouseButton.new()
	上.button_index = MOUSE_BUTTON_LEFT
	上.pressed = false
	上.position = 心
	上.global_position = 心
	root.push_input(上)
	await _等帧(6)

	var 弹 := root.find_child("队伍确认遮罩", true, false) as Control
	_记("点完托盘格，弹窗节点在了", 弹 != null, "")
	var 后 := _拍()
	_记("拍到了点之后的画面", 后 != null)
	var 差 := _差像素(前, 后, 框)
	_记("**屏幕中间真的变了**（弹窗看得见）", 差 > 5000, "差 %d 像素" % 差)
	if 弹 != null:
		var 层 := 弹.get_parent() as CanvasLayer
		print("  （参考）弹窗所在层 = %s，内容子件 = %d" % [层.layer if 层 != null else -1, 弹.get_child_count()])
		var 正文 := ""
		for n in 弹.find_children("*", "RichTextLabel", true, false):
			正文 += (n as RichTextLabel).text
		_记("弹窗正文带邀请人名字「队长甲」", 正文.contains("队长甲"), 正文)
		## 存两张图给眼睛复核
		var 目录 := "res://测试/截图/队伍邀请弹窗"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(目录))
		if 前 != null:
			前.save_png(ProjectSettings.globalize_path(目录 + "/点之前.png"))
		if 后 != null:
			后.save_png(ProjectSettings.globalize_path(目录 + "/点之后.png"))
		print("  裁图已存：%s/点之前.png、点之后.png" % 目录)

	# 点「确定」⇒ 必须发 `120:3:<队号>`（原版 `requestAcceptInvitation`）
	if 弹 != null:
		队伍窗.发件箱.clear()
		for n in 弹.find_children("*", "", true, false):
			print("    [树] %s (%s) %s" % [n.name, n.get_class(),
				("text=" + (n as Label).text) if n is Label else ""])
		var 确定 := _找钮(弹, "确定")
		_记("弹窗里有「确定」钮", 确定 != null, "")
		if 确定 != null:
			await _点(确定)
			await _等帧(3)
			_记("点确定 ⇒ 发出 `120:3:<4242>`", 队伍窗.发件箱.has([3, "4242"]), str(队伍窗.发件箱))

	print("验队伍邀请弹窗：%s（红 %d 条）" % ["全过" if 失败.is_empty() else "有红", 失败.size()])
	for t in 失败:
		print("  ✗ " + t)
	quit(0 if 失败.is_empty() else 1)

extends SceneTree

## 心法窗的**有头**截图量具：把「开窗常态」与「点开列表」两张图拍下来，供与原版实机图并排看。
##
## 为什么单开一支（而不是用 `量具基类`）：这一页要拍的**不是**逐件几何（那道门是
## `测试/原版服务窗回归测试.gd` + `测试/心法页回归测试.gd`），而是两张**外观对照图** ——
## 关闭钮边距、下拉箭头那枚 21×21 灰底按钮、三段文字的颜色与下划线，这些都是"眼睛判"的东西。
##
## ⚠ 不能加 `--headless`（无头拿不到视口图像）。
## 用法：Godot --path . --script res://开发工具/截心法页.gd -- --出目录=res://测试/截图/心法
##
## 夹具：列表要**有货**才拍得到（原版就是"已学 ∩ xinfa==1"），所以直接往真后端的
## `authoritative_skills` 里塞三条心法 + 一枚非心法（非心法那枚必须**不出现**，
## 图上就能看出来）；`authoritative_heal` 喂 action=3 ⇒ 主格由"服务端回帧"填上。
## 全程只改内存、跑完删回去，不碰存档。

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 心一 := 1000		# 体能强化
const 心二 := 1001		# 查克拉强化
const 心三 := 1004		# 替身术
const 非心 := 1001001
## 喂**六条**（1000~1005 都是 `xinfa==1`）：三条时内容高 122 只比可视 90 高一点点，
## 滑块会长得接近满轨，"太小了"这种偏差根本拍不出来 ⇒ 条数要够多才量得准（用户 10-14 报的那张）。
const 心法们 := [1000, 1001, 1002, 1003, 1004, 1005]

var 出目录 := ""
var 帧 := 0
var 量完 := false			# `_量滚动条` 是协程 ⇒ 收尾要等它跑完（见 `_收尾`）
var 飘字完 := false			# `_拍打坐飘字` 同样是协程（要等那一枚飘字出现）
var 红 := 0				# 滚动条那几条像素判据的红数 ⇒ 决定退出码（0 全过 / 1 确有偏差）
var 剖面: Array = []			# `_量画出来的` 的逐行涂到数（临时调试用，量完就清空）
var 队列: Array[Callable] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--出目录="):
			出目录 = String(a).trim_prefix("--出目录=")
	if 出目录.is_empty():
		出目录 = "res://测试/截图/心法"
	DirAccess.make_dir_recursive_absolute(出目录 + "/证据")
	root.size = Vector2i(960, 560)
	call_deferred("_起手")


func _起手() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	队列.append(_接后端.bind(场景))
	队列.append(_开窗.bind(场景))
	队列.append(_拍.bind("常态"))
	队列.append(_点箭头.bind(场景))
	队列.append(_拍.bind("展开"))
	队列.append(_量滚动条.bind(场景))
	队列.append(_拍打坐飘字.bind(场景))
	队列.append(_收尾)


func _process(_d: float) -> bool:
	帧 += 1
	if 队列.is_empty():
		return 帧 > 40
	if 帧 % 4 != 0:
		return false
	var 步: Callable = 队列.pop_front()
	步.call()
	return false


func _后端(场景: Node) -> Node:
	return root.get_node_or_null("/root/BackendConnection")


func _接后端(场景: Node) -> void:
	var 后 := _后端(场景)
	var 已: Dictionary = 后.get("authoritative_skills") as Dictionary
	for 号 in 心法们 + [非心]:
		已[号] = {"level": 7 if 号 == 心一 else 3, "master_level": 0}
	# 模拟"服务端已经回过 3 号帧"⇒ 主格该被填上（真回帧路径由在线门验）
	后.set("authoritative_heal", {"state": 1, "character_id": 0, "partner_id": 0,
			"pending_inviter_id": 0, "action": 3, "xinfa_id": 心一})
	print("夹具：已学塞了 %d 条心法 + 一枚非心法 %d，回帧那颗 = %d" % [心法们.size(), 非心, 心一])


func _开窗(场景: Node) -> void:
	var 管: Node = 场景.get_node_or_null("窗口管理")
	管.call("全部关闭")
	管.call("打开", "心法")
	var 窗: Node = 管._窗口们.get("心法") as Node
	var 钮: Control = 窗.get_node("遮罩/主窗口/关闭按钮") as Control
	var 框: Control = 窗.get_node("遮罩/主窗口") as Control
	print("关闭钮：距窗右 %.1f（原版 MWindow.as:215 = 6）、顶 %.1f（= 标题基准 5 + 1）"
			% [框.size.x - (钮.position.x + 钮.size.x), 钮.position.y])
	var 页: Control = 窗.get_node("遮罩/主窗口/页面容器").get_child(
			窗.get_node("遮罩/主窗口/页面容器").get_child_count() - 1) as Control
	var 箭: Control = 页.get_node("选择心法钮") as Control
	var 皮: Texture2D = (箭 as TextureRect).texture
	print("下拉箭头：矩形 %s 皮肤 %s" % [str(箭.get_rect()),
			String(皮.resource_path).get_file() if 皮 != null else "无"])


func _点箭头(场景: Node) -> void:
	var 窗: Node = (场景.get_node_or_null("窗口管理"))._窗口们.get("心法") as Node
	var 页: Control = 窗.get_node("遮罩/主窗口/页面容器").get_child(
			窗.get_node("遮罩/主窗口/页面容器").get_child_count() - 1) as Control
	var 箭: Control = 页.get_node("选择心法钮") as Control
	var 心: Vector2 = 箭.get_global_rect().get_center()
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
	# ⚠ `extends SceneTree` 的脚本里没有 `get_tree()`（那就是 SceneTree 本身）⇒ 直接 `await process_frame`
	await process_frame
	移 = InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
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
	print("真点了箭头（%s）⇒ 列表区 visible = %s" % [str(心), str(_区(窗).visible)])


func _区(窗: Node) -> Control:
	var 页: Control = 窗.get_node("遮罩/主窗口/页面容器").get_child(
			窗.get_node("遮罩/主窗口/页面容器").get_child_count() - 1) as Control
	return 页.get_node("心法列表") as Control


func _拍(名: String) -> void:
	var 图 := root.get_texture().get_image()
	var 路 := 出目录 + "/证据/整屏_" + 名 + ".png"
	图.save_png(路)
	print("拍了 %s（%dx%d）" % [路, 图.get_width(), 图.get_height()])


## 滚动条**滑轨里那颗可拖的块**（用户 2026-10-14 说"太小了"）：把 Godot 实际用的
## 样式与几何全部打出来 —— 光看图猜不出是"皮被 margins 挤小了"还是"长度算短了"。
func _量滚动条(场景: Node) -> void:
	var 窗: Node = (场景.get_node_or_null("窗口管理"))._窗口们.get("心法") as Node
	var 区 := _区(窗)
	var 条 := 区.get_v_scroll_bar() as VScrollBar
	print("滚动区 rect=%s  内容高=%.0f  可视高=%.0f" % [str(区.get_rect()),
			(区.get_child(0) as Control).size.y, 区.size.y])
	print("滚动条 rect=%s visible=%s  min=%d max=%d page=%d step=%d value=%d"
			% [str(条.get_global_rect()), str(条.visible), int(条.min_value), int(条.max_value),
				int(条.page), int(条.step), int(条.value)])
	for 项 in ["scroll", "grabber", "grabber_highlight", "grabber_disabled"]:
		var 板: StyleBox = 条.get_theme_stylebox(项) as StyleBox
		if 板 == null:
			print("  样式 %s = null ← 没有这一档，Godot 会回退到默认灰块" % 项)
			continue
		var 板文 := 板 as StyleBoxTexture
		if 板文 == null:
			print("  样式 %s = %s（不是贴图）" % [项, 板.resource_path])
			continue
		var 图 := 板文.texture
		print("  样式 %s ← %s  原生=%s  边距(左%.1f 右%.1f 上%.1f 下%.1f)  画中心=%s  外扩=%.1f"
				% [项, String(图.resource_path).get_file() if 图 != null else "无图",
					str(图.get_size()) if 图 != null else "-",
					板文.texture_margin_left, 板文.texture_margin_right,
					板文.texture_margin_top, 板文.texture_margin_bottom,
					str(板文.draw_center), 板文.expand_margin_left])
	for 项 in ["decrement_arrow", "increment_arrow", "decrement_highlight", "increment_highlight", "stepper"]:
		var 图: Texture2D = 条.get_theme_icon(项) as Texture2D
		print("  图标 %s ← %s" % [项, String(图.resource_path).get_file() if 图 != null else "无"])
	for 项 in ["thickness", "center_grabber", "scroller_speed", "scroll_deadzone", "arrow_single_step"]:
		print("  常量 %s = %s" % [项, str(条.get_theme_constant(项))])
	# ── 逐条数扫：滑块长度**跟着列表条数变**，只看一种条数必然得出错的结论 ──────────
	# 用户 2026-10-14 的原话："你测试画面里的大小和我进游戏看到的不一致" —— 就是这个：
	# 我那张喂 6 条（实测 21 像素），号上条数不同 ⇒ 看到的自然不同。
	# 原版算式 `ScrollBar.as:145-153`：`max(13, page / 内容高 × track高)`，track = 条高 − 2×15
	# ⇒ 有一条**硬下限 13**；Godot 的下限在引擎里（实测 10），主题没有开关能抬
	#   （`thickness` 从 13 试到 26，滑块长度纹丝不动 ⇒ 它只管粗细、不管长短）。
	var 表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/心法表.json")) as Dictionary
	var 全ids: Array = []
	for 键 in (表["条目"] as Dictionary).keys():
		全ids.append(int(键))
	var 后 := _后端(null)
	var 已: Dictionary = 后.get("authoritative_skills") as Dictionary
	print("条数  内容高  滑块实测  本件算式  原版算式(轨60)  ⇒ 与原版差")
	for 枚 in [2, 3, 4, 6, 8, 10, 12, 16]:
		for 号 in 心法们 + [非心]:
			已.erase(号)
		for i in mini(枚, 全ids.size()):
			已[int(全ids[i])] = {"level": 3, "master_level": 0}
		窗.call("_refresh_current")		# 换数据 ⇒ 整页重建（宿主对回帧做的正是这件事）
		await process_frame
		await process_frame
		await process_frame
		var 区内 := _区(窗)
		var 件 := 区内.get_parent().get_node_or_null("原版滚动条") as Control
		var 内容 := float(枚 * 40 + 2)
		if 件 == null:
			print("  %2d   %3.0f     共用件没挂上 ⇒ `配原版滚动区` 那条接线没走到" % [枚, 内容])
			continue
		var 滑 := 件.get_node("滑块") as Control
		var 帽: float = (件.get_node("上箭头") as Control).size.y
		var 轨长: float = 件.size.y - 2.0 * 帽
		var 实测 := int(round(滑.size.y)) if (件.visible and 滑.visible) else -1
		var 本件 := maxf(13.0, 区内.size.y / maxf(内容, 区内.size.y) * 轨长)
		var 原版 := maxf(13.0, 区内.size.y / maxf(内容, 区内.size.y) * 60.0)
		if 实测 < 0:
			print("  %2d   %3.0f      不滚（内容没超过可视高 ⇒ 原版这里也没有条，正确）" % [枚, 内容])
		else:
			print("  %2d   %3.0f      %2d       %4.1f       %4.1f        ⇒ %+d 像素"
					% [枚, 内容, 实测, 本件, 原版, int(round(原版)) - 实测])
		# 顺手把"条数最多那一档"的滚动条裁成 8x 图（差得最大的就是那一档）
		if 枚 == 12:
			_裁一条(件, "滚动条_12条_8x.png")
		if 枚 == 16:
			# 用户 2026-10-14 追问的那一张：**拖到底**看滑块底边是不是超出轨道
			区内.set_v_scroll(999999)
			await process_frame
			await process_frame
			var 滑3: Control = 件.get_node("滑块") as Control
			var 下3: Control = 件.get_node("下箭头") as Control
			var 槽3: TextureRect = 件.get_node("槽") as TextureRect
			print("  槽：size=%s visible=%s 贴图=%s 拉伸=%d 撑开=%d ｜ 件 size=%s"
					% [str(槽3.size), str(槽3.visible),
						String(槽3.texture.resource_path).get_file() if 槽3.texture != null else "无",
						槽3.stretch_mode, 槽3.expand_mode, str(件.size)])
			var 屏 := root.get_texture().get_image()
			var 测点 := 件.get_global_rect().position + Vector2(件.size.x / 2.0, 件.size.y * 0.45)
			print("  轨道中段那一点（%s）屏幕色 = %s ⇒ %s"
					% [str(测点), str(屏.get_pixel(测点.x as int, 测点.y as int)),
						"滑轨没画上（露出来的是底下的提示文字）"
						if 屏.get_pixel(测点.x as int, 测点.y as int).get_luminance() > 0.35
						else "滑轨在"])
			print("  ★ 拖到底（节点矩形）：滑块 y %.1f..%.1f ｜ 轨道底（下箭头上沿）= %.1f ｜ 条底 = %.1f ⇒ %s"
					% [滑3.position.y, 滑3.position.y + 滑3.size.y,
						件.size.y - 下3.size.y, 件.size.y,
						"超出 %.1f 像素" % (滑3.position.y + 滑3.size.y - (件.size.y - 下3.size.y))
						if 滑3.position.y + 滑3.size.y > 件.size.y - 下3.size.y + 0.5 else "没超"])
			_裁一条(件, "滚动条_16条_到底_8x.png")
			_拍("16条到底")
			# ── 节点矩形只说明"框多大"，说明不了"画出来多大" ⇒ 用户三次报"超出长度"，
			#    判据必须落在**屏幕上真被画到的行**：临时把某个节点涂成纯色再数行。
			var 自带 := 区内.get_v_scroll_bar() as Control
			print("  自带条：modulate=%s visible=%s rect=%s" % [str(自带.modulate), str(自带.visible), str(自带.get_global_rect())])
			print("  父节点子件：", 件.get_parent().get_children().map(func(n): return str(n.name)))
			var 涂滑 := await _量画出来的(件, 滑3, 0)
			print("  滑块属性：ignore_texture_size=%s stretch_mode=%d 皮=%s 矩形=%s 位置=%s 最小=%s"
					% [str(滑3.ignore_texture_size), 滑3.stretch_mode,
						str((滑3 as TextureButton).texture_normal.get_size()), str(滑3.size),
						str(滑3.position), str(滑3.get_combined_minimum_size())])
			var 顶: float = 滑3.position.y
			var 底: float = 滑3.position.y + 滑3.size.y
			print("  ★ 涂色实测（件内 y）：滑块画到 %.0f..%.0f ｜ 矩形 %.0f..%.0f ｜ 条底 = %.0f"
					% [涂滑.x, 涂滑.y, 顶, 底, 件.size.y])
			_判(涂滑.x >= 顶 - 1.0 and 涂滑.y <= 底 + 1.0 and 涂滑.y - 涂滑.x <= 15.0,
					"滑块**画出来**没超出自己的矩形（%.0f..%.0f 落在 %.0f..%.0f 内、高 %.0f ≤ 15）"
							% [涂滑.x, 涂滑.y, 顶, 底, 涂滑.y - 涂滑.x])
			_判(涂滑.y <= 件.size.y - 下3.size.y + 1.0,
					"拖到底时滑块画出的底边 %.0f 不越过下箭头上沿 %.0f"
							% [涂滑.y, 件.size.y - 下3.size.y])
			# A/B：把本件整个藏掉再比一次屏幕 —— 轨道区变了才证明"滑轨真被画上"
			#（`槽.stretch_mode` 一旦退回默认的 KEEP，这里就是 0 个像素差，而矩形照样是满的）
			var 屏有 := root.get_texture().get_image()
			var 全 := 件.get_global_rect()
			件.set_process(false)		# 本件的 `_process` 每帧会把 visible 写回 true
			件.visible = false
			await process_frame
			await process_frame
			await process_frame
			var 屏无 := root.get_texture().get_image()
			_裁一条(件, "滚动条_16条_到底_藏件_8x.png")
			件.visible = true
			件.set_process(true)
			var 差 := 0
			for y in range(int(全.position.y) + 20, int(全.position.y) + 50):
				for x in range(int(全.position.x) + 4, int(全.position.x) + 15):
					if 屏有.get_pixel(x, y) != 屏无.get_pixel(x, y):
						差 += 1
			_判(差 > 30, "藏掉本件后轨道区变了 %d/330 个像素 ⇒ 滑轨确实铺在整条上" % 差)
	量完 = true


## 打坐涨一层心法 ⇒ 角色头顶那行蓝字**在屏幕上真看得见**吗（用户 10-14 报的就是"没这行字"）。
##
## ⚠ 判法必须是"同一个矩形 A/B 两拍数差异像素"：飘字是运行期 `new()` 出来的 `Label` +
##   补间，只查"节点挂上了 / 文本对"= 假绿（这条链上一次就因为 `stretch_mode` 的默认值
##   把"矩形 13 高"和"画出来 30 高"混成一回事，被打回三次）。
## 取景以玩家当前帧贴图高为基准；先把所有窗关掉，免得窗皮盖住头顶那块。
func _拍打坐飘字(场景: Node) -> void:
	## ⚠ 必须等 `_量滚动条` 那个协程跑完再动：队列每 4 帧弹一步，两支协程会**交错**执行，
	##   而我这一步第一件事就是关所有窗 ⇒ 交错会把滚动条那段量在"窗已关、列表已收起"的态上
	##   （实测：滑块尺寸冻在 3 条那一档的 41.3、藏件差 0 个像素，全是假红）。
	while not 量完:
		await process_frame
	var 管: Node = 场景.get_node_or_null("窗口管理")
	管.call("全部关闭")
	await process_frame
	await process_frame
	await process_frame
	var 玩家 := get_first_node_in_group("player") as Node2D
	var 后 := _后端(null)
	if 玩家 == null or 后 == null:
		_判(false, "找不到 player 或后端 ⇒ 打坐飘字这条没量到")
		飘字完 = true
		return
	var 精灵 = 玩家.get("player_sprite")
	var 精灵高 := 0.0
	if 精灵 != null and (精灵 as Node).has_method("当前贴图高度"):
		精灵高 = float((精灵 as Node).call("当前贴图高度"))
	_判(精灵高 > 0.0, "参照物取到了：玩家当前帧贴图高 %.1f（飘字锚点就是它）" % 精灵高)
	var 屏位: Vector2 = 玩家.get_global_transform_with_canvas().origin
	var 左 := int(屏位.x - 110.0)
	var 上 := int(屏位.y - 精灵高 - 40.0)
	var 宽 := 220
	var 高 := 64
	var 已: Dictionary = 后.get("authoritative_skills") as Dictionary
	var 基准 := int((已.get(心一, {}) as Dictionary).get("master_level", 0))
	var 前 := root.get_texture().get_image()
	后.call("_apply_skill", 心一, 7, 基准 + 1)		# = 39 帧到达时解析器调的那一句
	var 件: Node = null
	for i in 60:
		await process_frame
		for 子 in 玩家.get_children():
			var 本: Script = (子 as Node).get_script() as Script
			if 本 != null and String(本.resource_path).contains("伤害数字"):
				件 = 子
				break
		if 件 != null:
			break
	if 件 == null:
		_判(false, "喂了「涨一层」之后 1 秒内玩家身上没出现飘字节点")
	else:
		var 后片 := root.get_texture().get_image()
		var 差 := 0
		for y in range(maxi(0, 上), mini(560, 上 + 高)):
			for x in range(maxi(0, 左), mini(960, 左 + 宽)):
				if 前.get_pixel(x, y) != 后片.get_pixel(x, y):
					差 += 1
		_判(差 > 300, "同一块头顶区域 A/B 两拍差 %d 个像素（框 %d×%d）⇒ 那行字真画在屏幕上" % [差, 宽, 高])
		var 签 = (件 as Node).get("_标签")
		print("  飘字节点：文本「%s」 屏幕位 %s 相对脚点 y=%.1f"
				% [(签 as Label).text if 签 is Label else "?",
					str(件.get_global_transform_with_canvas().origin),
					(件 as Node2D).position.y])
		_存裁(前, 左, 上, 宽, 高, 4, "打坐飘字_之前_4x.png")
		_存裁(后片, 左, 上, 宽, 高, 4, "打坐飘字_之后_4x.png")
	后.call("_apply_skill", 心一, 7, 基准)		# 层数还原，别把夹具状态留在+1
	飘字完 = true


## 从整屏图里裁一块、放大存盘（证据图，给人眼看的）。
func _存裁(图: Image, 左: int, 上: int, 宽: int, 高: int, 倍: int, 名: String) -> void:
	var 小 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	for y in 高:
		for x in 宽:
			var sx: int = 左 + x
			var sy: int = 上 + y
			if sx >= 0 and sy >= 0 and sx < 图.get_width() and sy < 图.get_height():
				小.set_pixel(x, y, 图.get_pixel(sx, sy))
	小.resize(宽 * 倍, 高 * 倍, Image.INTERPOLATE_NEAREST)
	var 路 := 出目录 + "/证据/" + 名
	小.save_png(路)
	print("拍了 %s（%dx%d，%d 倍）" % [路, 小.get_width(), 小.get_height(), 倍])


## 裁滚动条那一条并放大 8 倍存盘（眼睛判"像不像"要看放大图，指标只证得了像素数）。
func _裁一条(件: Control, 名: String) -> void:
	var 图全 := root.get_texture().get_image()
	var 裁 := (件.get_global_rect().position.x - 3.0) as int
	var 裁起 := (件.get_global_rect().position.y - 3.0) as int
	var 裁宽 := (件.get_global_rect().size.x + 6.0) as int
	var 裁高 := (件.get_global_rect().size.y + 6.0) as int
	var 小 := Image.create(裁宽, 裁高, false, Image.FORMAT_RGBA8)
	小.fill(Color(0, 0, 0, 0))
	for y in 裁高:
		for x in 裁宽:
			var sy: int = 裁起 + y
			var sx: int = 裁 + x
			if sx >= 0 and sy >= 0 and sx < 图全.get_width() and sy < 图全.get_height():
				小.set_pixel(x, y, 图全.get_pixel(sx, sy))
	小.resize(裁宽 * 8, 裁高 * 8, Image.INTERPOLATE_NEAREST)
	var 路 := 出目录 + "/证据/" + 名
	小.save_png(路)
	print("拍了 %s（%dx%d，8 倍）" % [路, 小.get_width(), 小.get_height()])


## 把某个节点临时涂成纯色（`self_modulate`），再数**屏幕上真被画到的行** ——
## 返回 `Vector2(件内起, 件内止)`，没画到返回 `(-1,-1)`。
## 为什么非要数像素：`滑块.size.y` 是"矩形多高"，TextureButton 完全可能把 37 高的皮
## 画到 13 高的矩形之外（用户 2026-10-14 三次报"超出长度"，只报矩形不算证据）。
func _量画出来的(件: Control, 节: Control, 档: int) -> Vector2:
	var 色 := Color(0.0, 1.0, 0.0) if 档 == 0 else Color(1.0, 0.0, 0.0)
	var 原: Color = 节.self_modulate
	节.self_modulate = 色
	await process_frame
	await process_frame
	await process_frame
	var 屏 := root.get_texture().get_image()
	var 全 := 件.get_global_rect()
	var 起 := -1.0
	var 止 := -1.0
	for i in int(round(全.size.y)) + 10:
		var y: int = int(全.position.y) - 5 + i
		if y < 0 or y >= 屏.get_height():
			continue
		var 中 := 0
		var 数 := 0
		for x in range(int(全.position.x) + 2, int(全.position.x + 全.size.x) - 1):
			if x < 0 or x >= 屏.get_width():
				continue
			var p := 屏.get_pixel(x, y)
			数 += 1
			if 档 == 0 and p.g > 0.28 and p.g > p.r + 0.08 and p.g > p.b + 0.08:
				中 += 1
			elif 档 == 1 and p.r > 0.12 and p.r > p.g + 0.10 and p.r > p.b + 0.10:
				中 += 1
		if 数 > 0 and 中 * 2 > 数:
			if 起 < 0.0:
				起 = float(i - 5)
			止 = float(i - 4)
		if 中 > 0:
			剖面.append("    件内y=%3d 涂到 %3d/%3d" % [i - 5, 中, 数])
	节.self_modulate = 原
	print("\n".join(剖面))
	剖面 = []
	return Vector2(起, 止)


## 一条硬判据：红了就记一笔（退出码 0 = 跑到的判据全过，1 = 确有偏差）。
## 为什么判据要落在"屏幕上真被画到的行"：`滑块.size` 只说明矩形多大 —— 13 高的矩形
## 配 `stretch_mode=KEEP`（TextureButton 的**默认值**）会把 37 高的皮原样画出去，
## 矩形门全绿而玩家看到滑块盖住下箭头、拖到底还超出条底（用户 2026-10-14 三次报的那条）。
func _判(对: bool, 说明: String) -> void:
	if 对:
		print("  ✓ %s" % 说明)
	else:
		红 += 1
		print("  ✗ 红 %d：%s" % [红, 说明])


func _收尾() -> void:
	# `_量滚动条` 是个协程（每档条数要等好几帧画出来），队列每 4 帧只弹一步 ⇒
	# 它还没跑完就 quit() 就是"日志缺尾"。量完之前这一步先把自己塞回队尾。
	if not 量完 or not 飘字完:
		队列.append(_收尾)
		return
	var 后 := _后端(null)
	if 后 != null:
		var 已: Dictionary = 后.get("authoritative_skills") as Dictionary
		for 号 in 心法们 + [非心]:
			已.erase(号)
		后.set("authoritative_heal", {"state": 0, "character_id": 0, "partner_id": 0,
				"pending_inviter_id": 0})
	print("夹具已清、截图落在 %s/证据" % 出目录)
	print("滚动条像素判据：红 %d" % 红)
	quit(0 if 红 == 0 else 1)

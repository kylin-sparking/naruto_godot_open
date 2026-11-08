extends SceneTree

## 共用滚动条件（`场景/界面/组件/原版滚动条.tscn` + `脚本/界面/组件/原版滚动条.gd`）的离线门。
##
## 为什么单独一道：用户 2026-10-14 报"滑轨里那颗可拖的按钮太小了"。量出来是
## **原版有一条硬下限 13 像素**（`fl/controls/ScrollBar.as:153` `Math.max(13, ...)`，
## 而且 `ScrollPane` 与 `SmallScrollBar` 两支共用同一个 `updateThumb`），
## Godot 自带那条下限是 10 且**没有开关**（`thickness` 从 13 试到 26 长度不动，只管粗细）。
## ⇒ 这条下限以前没有任何量具盯着：列表一长就悄悄比原版短（实测 12 条短 3、16 条短 5）。
##
## 门盯六件事：①件挂上了且四张皮是原版那四张 ②自带那条只占位不画也不吃点击
## ③各条数下滑块高等于 `max(13, 可视/内容高 × 轨道)` ④**长列表被 13 兜住**（本轮的靶）
## ⑤内容没超过可视 ⇒ 整条不出现 ⑥箭头/轨道点击与拖动改的是 `scroll_vertical`，
## 且滚到底时滑块底边正好贴住下箭头上沿（摆位算式与原版同一条）。
##
## 用法：Godot --headless --path . --script res://测试/滚动条滑块下限回归测试.gd

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 滚动件 := preload("res://脚本/界面/组件/原版滚动条.gd")
const 区宽 := 57.0
const 可视 := 90.0
const 格高 := 40.0		# 心法列表一格的步距（`XinfaWindow.as:223`）
const 下限 := 13.0		# `ScrollBar.as:153`

var 条 := 0
var 红 := 0
var 日志: Array[String] = []
var 存档路 := "user://玩家数据.json"
var 存档前 := PackedByteArray()
var 本来有 := false


func _记(过: bool, 文: String) -> void:
	条 += 1
	if not 过:
		红 += 1
		日志.append("!! " + 文)
	else:
		日志.append("  √ " + 文)
	# **当场就印**：这道门挂了两次都在中途（页被 queue_free 之后 `_process` 还在跑），
	# 攒到最后才印 = 卡住时一行都看不到，只能靠猜。
	print(日志[-1])


func _存档字节() -> PackedByteArray:
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	if 读 == null:
		return PackedByteArray()
	return 读.get_buffer(读.get_length())


## 造一个"页面 + 滚动区 + 内容"的最小现场。**两步分开跑**：
## 第一步只走各页共用的 `配原版滚动区` ⇒ 断言它**不**挂本件（用户 2026-10-14 令：只改心法一页，
## 商城那页被牵连过：滑块甩到列表中间）；第二步才走心法那条 `原版滚动条.挂到`。
func _搭(枚数: int) -> Dictionary:
	print("── 搭现场：%d 条" % 枚数)		# 卡住时至少知道卡在哪一档
	var 页 := Control.new()
	页.name = "页"
	页.size = Vector2(300.0, 300.0)
	root.add_child(页)
	var 区 := ScrollContainer.new()
	区.name = "列表区"
	区.size = Vector2(区宽, 可视)
	页.add_child(区)
	var 内容 := Control.new()
	内容.name = "内容"
	区.add_child(内容)
	皮肤表.配原版滚动区(区, 内容, 区宽, 可视, 格高 * float(枚数) + 2.0)
	_记(页.get_node_or_null("原版滚动条") == null,
			"共用的 `配原版滚动区()` **不**挂这个件 ⇒ 商城/副本/兑换/好友那几页维持 Godot 自带那条")
	滚动件.挂到(区, 内容, 区宽, 可视)
	await process_frame
	await process_frame
	return {"页": 页, "区": 区, "内容": 内容,
			"件": 页.get_node_or_null("原版滚动条") as Control}


func _拆(现场: Dictionary) -> void:
	(现场["页"] as Node).queue_free()
	await process_frame


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	本来有 = FileAccess.file_exists(存档路)
	存档前 = _存档字节()
	# ── ① 件挂上了、四张皮是原版那四张 ──────────────────────────────────────
	var 场 := await _搭(6)
	var 件: Control = 场["件"] as Control
	_记(件 != null, "配完滚动区之后，页上多出了共用件「原版滚动条」（没有 = 接线没走到）")
	if 件 == null:
		_收尾(); return
	for 名 in ["槽", "滑块", "上箭头", "下箭头"]:
		_记(件.get_node_or_null(名) != null, "件里有「%s」这一档（四件缺一不可，摆位全靠脚本按它们算）" % 名)
	var 皮 := {
		"槽": "滚动槽.png", "滑块": "滚动滑块.png",
		"上箭头": "滚动向上.png", "下箭头": "滚动向下.png",
	}
	for 名 in 皮.keys():
		var 节 := 件.get_node(名) as Node
		var 图: Texture2D = null
		if 节 is TextureRect:
			图 = (节 as TextureRect).texture
		elif 节 is TextureButton:
			图 = (节 as TextureButton).texture_normal
		_记(图 != null and String(图.resource_path).ends_with(String(皮[名])),
				"「%s」用的就是原版那张皮 %s（实测 %s）" % [名, 皮[名],
					String(图.resource_path).get_file() if 图 != null else "无图"])
	# ── ② Godot 自带那条只占位：不画、也不吃掉自绘件的点击 ────────────────────
	var 区: ScrollContainer = 场["区"] as ScrollContainer
	var 自带 := 区.get_v_scroll_bar() as Control
	# ★ 滑轨与三颗钮都必须是**整张拉伸**。用户 10-14 报"滑块超出范围/超出长度"，打回三次，
	#   先后抓到两处：① `滚动槽.png` 天然 19×140、条只有 90 高，贴图模式一旦是 KEEP(5)/TILE(1)，
	#   露出来的就只有图中间那一段（几乎全暗）⇒ 滑块像浮在窗口文字上；
	#   ② **`TextureButton` 的 `stretch_mode` 默认值是 KEEP(2)** —— 它按皮的天然尺寸画、
	#   完全不看控件矩形。箭头矩形本来就等于皮（19×17）看不出来，滑块要压到 13 高就露馅：
	#   实测矩形 60..73、屏幕上却画到 65..95（盖住下箭头、拖到底还超出条底 5 像素）。
	#   ⇒ 光量矩形是假绿，`开发工具/截心法页.gd` 里另有一道"涂色数屏幕行"的像素判据。
	#   原版 `MNoResizeWidth9ScaleSprite` 正是"宽度不动、高度整幅缩放"。
	var 槽节 := 件.get_node("槽") as TextureRect
	_记(槽节.stretch_mode == TextureRect.STRETCH_SCALE,
			"滑轨是整张拉伸（实测 %d；KEEP/TILE 会只露出 19×140 那张的中间一段 ⇒ 看着像滑块出界）"
			% 槽节.stretch_mode)
	_记(槽节.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
			"滑轨不拿贴图天然尺寸当最小尺寸（否则条会被顶成 140 高）")
	_记(槽节.size.distance_to(件.size) < 0.5,
			"滑轨铺满整条（%.0f×%.0f vs %.0f×%.0f）" % [槽节.size.x, 槽节.size.y, 件.size.x, 件.size.y])
	for 名 in ["滑块", "上箭头", "下箭头"]:
		var 钮 := 件.get_node(名) as TextureButton
		_记(钮.stretch_mode == TextureButton.STRETCH_SCALE,
				"「%s」按控件矩形缩放（实测 %d；KEEP 会把 %s 的皮原样画到矩形之外）"
						% [名, 钮.stretch_mode, str(钮.texture_normal.get_size())])
		_记(钮.ignore_texture_size,
				"「%s」不拿皮的天然尺寸当最小尺寸（实测最小 %s，否则矩形会被顶成 37 高）"
						% [名, str(钮.get_combined_minimum_size())])
	_记(is_zero_approx(自带.modulate.a),
			"自带那条被压成全透明（alpha=%.1f）⇒ 屏上只有我们画的那一条" % 自带.modulate.a)
	_记(自带.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"自带那条不吃鼠标（否则按下会被它抢走，自绘的拖不动）")
	# `ScrollContainer.vertical_scroll_mode`：0=自动 1=总是显示 2=总是隐藏 3=自定义。
	# 2 那一档会让 ScrollContainer 判定"不给纵向滚"⇒ 列表滚不动（本工程各页用的是 0/1/3）。
	_记(int(区.vertical_scroll_mode) != 2,
			"纵向滚动模式不是「总是隐藏」(实测 %d) —— 是 2 的话列表根本滚不动" % int(区.vertical_scroll_mode))
	# ── ③④ 各条数下滑块高度 = `max(13, 可视/内容高 × 轨道)` ──────────────────
	var 帽: float = (件.get_node("上箭头") as Control).size.y
	var 轨长: float = 件.size.y - 2.0 * 帽
	_记(absf(轨长 - (可视 - 2.0 * 帽)) < 0.5,
			"轨道 = 条高 %.0f − 2×箭头 %.0f = %.0f（原版 `:271-276` 箭头占 15，我们的皮天然 17 ⇒ #100 已登记）"
			% [件.size.y, 帽, 轨长])
	for 枚 in [3, 4, 6, 8, 10, 12, 16]:
		var 一: Dictionary = await _搭(枚)
		var 一件: Control = 一["件"] as Control
		var 一滑: Control = 一件.get_node("滑块") as Control
		var 内容高 := 格高 * float(枚) + 2.0
		var 应: float = maxf(下限, 可视 / 内容高 * ((一件.size.y - 2.0 * (一件.get_node("上箭头") as Control).size.y)))
		_记(absf(一滑.size.y - 应) < 1.0,
				"%2d 条 ⇒ 滑块 %.1f 像素（算式 %.1f，内容高 %.0f）" % [枚, 一滑.size.y, 应, 内容高])
		# ★ 用户 10-14 报"滑块超出范围"的头号嫌疑：**件算的值域和 ScrollContainer 自己那条
		#   上限不是同一个数** ⇒ 滚轮/拖到底时值会跑到件的算式之外，滑块就压到箭头上去。
		var 一区: ScrollContainer = 一["区"] as ScrollContainer
		一区.set_v_scroll(999999)		# 顶到 Godot 自己的上限
		await process_frame
		var 顶到底 := 一区.get_v_scroll()
		var 件算值域 := maxf(内容高, 可视) - 可视
		_记(absf(float(顶到底) - 件算值域) < 1.0,
				"%2d 条 ⇒ Godot 自己的滚动上限 %d == 件算的值域 %.0f（不等 = 滑块会跑出轨道）"
				% [枚, 顶到底, 件算值域])
		var 滑2: Control = 一件.get_node("滑块") as Control
		_记(滑2.position.y + 滑2.size.y <= 一件.size.y - (一件.get_node("下箭头") as Control).size.y + 1.0,
				"%2d 条滚到底 ⇒ 滑块底边不越过下箭头（%.1f vs %.1f）"
				% [枚, 滑2.position.y + 滑2.size.y, 一件.size.y - (一件.get_node("下箭头") as Control).size.y])
		if 枚 >= 12:
			_记(一滑.size.y >= 下限 - 0.01,
					"★ %d 条这种长列表也被 13 兜住（Godot 自带那条这里只有 10/8 ⇒ 用户报的'太小'）" % 枚)
		await _拆(一)
	# ── ⑤ 内容没超过可视 ⇒ 整条不出现 ───────────────────────────────────────
	var 短: Dictionary = await _搭(2)
	var 短件: Control = 短["件"] as Control
	_记(not 短件.visible or not (短件.get_node("滑块") as Control).visible,
			"2 条（内容 82 ≤ 可视 90）⇒ 没有滚动条（原版这里也没有：`track.height<=12 || max<=min` 那一支）")
	await _拆(短)
	# ── ⑥ 交互：箭头 / 轨道 / 拖拽都落在 scroll_vertical 上 ──────────────────
	var 底: Dictionary = await _搭(16)
	var 底件: Control = 底["件"] as Control
	var 底区: ScrollContainer = 底["区"] as ScrollContainer
	var 值域 := 格高 * 16.0 + 2.0 - 可视
	_记(底区.scroll_vertical == 0, "刚搭好停在顶部（scroll_vertical=0）")
	var 滑块: Control = 底件.get_node("滑块") as Control
	var 下: TextureButton = 底件.get_node("下箭头") as TextureButton
	下.pressed.emit()
	_记(底区.scroll_vertical == 1,
			"点一次下箭头滚 **1 像素**（`:83` `_lineScrollSize = 1`，`ScrollPane` 从没改过 ⇒ 不许自作主张改成滚一行）")
	(底件.get_node("槽") as TextureRect).gui_input.emit(_点(Vector2(9.0, 80.0)))
	_记(底区.scroll_vertical == int(clampf(1.0 + 可视, 0.0, 值域)),
			"点轨道下半 = 往下滚**一整页**（`:352-354` pageScrollSize 缺省 = pageSize），实测 %d" % 底区.scroll_vertical)
	# 滚到底：滑块底边必须正好贴住下箭头上沿（摆位算式与原版同一条）
	底区.scroll_vertical = int(值域)
	await process_frame
	var 帽2: float = (底件.get_node("上箭头") as Control).size.y
	_记(absf(滑块.position.y + 滑块.size.y - (底件.size.y - 帽2)) < 1.0,
			"滚到底 ⇒ 滑块底边贴下箭头上沿（%.1f + %.1f vs %.1f）"
			% [滑块.position.y, 滑块.size.y, 底件.size.y - 帽2])
	底区.scroll_vertical = 0
	await process_frame
	_记(absf(滑块.position.y - 帽2) < 1.0,
			"滚到顶 ⇒ 滑块顶边贴上箭头下沿（%.1f vs %.0f）" % [滑块.position.y, 帽2])
	# 拖拽：按住滑块往下拖 20 像素 ⇒ 滚动量按 可拖行程/值域 线性换算
	#（⚠ 这里发的是控件自己的 gui_input / Button.pressed，测的是"信号有没有接上 + 算式对不对"；
	#  命中测试（鼠标点得到点不到）由上面那两条 mouse_filter 断言 + 有头量具的截图各自盯一半）
	var 起值 := 底区.scroll_vertical		# **发事件之前**读：拖完之后它就不是起点值了（第一版就踩了这个）
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.global_position = Vector2(9.0, 滑块.get_global_rect().get_center().y)
	滑块.gui_input.emit(按)
	var 移 := InputEventMouseMotion.new()
	移.button_mask = MOUSE_BUTTON_MASK_LEFT
	移.global_position = 按.global_position + Vector2(0.0, 20.0)
	滑块.gui_input.emit(移)
	var 可拖: float = 底件.size.y - 2.0 * 帽2 - 滑块.size.y
	var 应滚 := int(clampf(float(起值) + 20.0 / 可拖 * 值域, 0.0, 值域))
	_记(底区.scroll_vertical == 应滚,
			"拖滑块 20 像素 ⇒ 滚到 %d（算式：起值 %d + 20/%.0f × %.0f），实测 %d"
			% [应滚, 起值, 可拖, 值域, 底区.scroll_vertical])
	await _拆(底)
	_收尾()


func _点(位: Vector2) -> InputEventMouseButton:
	var 事 := InputEventMouseButton.new()
	事.button_index = MOUSE_BUTTON_LEFT
	事.pressed = true
	事.position = 位
	事.global_position = 位
	return 事


func _收尾() -> void:
	var 后 := _存档字节()
	_记(后 == 存档前 or (后.is_empty() and not 本来有),
			"跑完 `user://玩家数据.json` **字节没变**（本门只碰内存里的控件，不落存档）")
	_记(条 >= 24, "一共判了 %d 条（下限 24）—— 条数掉了 = 有断言没执行到" % 条)
	# 每条已经在 `_记` 里当场印过了，这里别再接着印一遍（印两遍 = 看日志的人分不清哪段是本次）
	print("滚动条滑块下限回归：通过（红 0 项）" if 红 == 0 else "滚动条滑块下限回归：不通过（红 %d 项）" % 红)
	quit(0 if 红 == 0 else 1)

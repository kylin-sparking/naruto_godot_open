extends SceneTree
## 底栏技能格的有头量具（#187 + 技能栏返工，2026-10-12）。
##
## 为什么必须有头：要看的是**屏幕上真画出来的那一排**（底板皮、标号、层数、选中流光），
## 无头拿不到视口图像。跑法（不要加 --headless）：
##   "godot" --path . --script res://开发工具/截技能栏页.gd
##
## 它同时是一份判据：逐格打「标号文本 / 层数文本 / 流光是否可见 / 底板贴图路径」，
## 末行 `汇：判 N 条 / 红 M 条`，不绿就退出码 1。

const 出目录 := "res://测试/截图/技能栏/"
const 真值底板 := "res://素材/界面/技能面板/技能格底板.png"
const 标号表 := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

var 判数 := 0
var 红: Array[String] = []


func _查(成立: bool, 话: String) -> void:
	判数 += 1
	if not 成立:
		红.append(话)


func _帧(n := 1) -> void:
	for i in range(n):
		await process_frame


func _尾() -> void:
	for 条 in 红:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（截技能栏页：%s）" % [判数, 红.size(), "通过" if 红.is_empty() else "失败"])
	quit(0 if 红.is_empty() else 1)


func _放大(图: Image, 倍: int, 名: String) -> void:
	var 放: Image = 图.duplicate()
	放.resize(图.get_width() * 倍, 图.get_height() * 倍, Image.INTERPOLATE_NEAREST)
	放.save_png(ProjectSettings.globalize_path(出目录) + "/" + 名)


func _找格子(栏: Node, 名: String) -> Control:
	## ⚠ 传进来的是 `技能栏` **本身**（不是 HUD 那层 CanvasLayer），路径不能再带 `技能栏/` 前缀。
	return 栏.get_node_or_null("SkillShortcut" + 名) as Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	call_deferred("_run")


func _喂槽(会话: Node) -> void:
	## ⚠ 两个坑都实测过：
	## 1) 必须在**场景起来之后**喂 —— `GameSession._ready` 会 `_rebuild_skill_slots()`
	##    （离线示例数据就两枚：1001001 / 0002000），比这早喂的那份会被整排顶掉。
	## 2) `skill_slots` 是 `Array[Dictionary]`，**`set()` 塞一个无类型 Array 进去会被静默丢掉**
	##    （不报错、值也没变）⇒ 只能拿它自己的那个数组**逐格就地改**。
	会话.skill_slots.resize(10)
	for i in range(10):
		会话.skill_slots[i] = {}
	会话.skill_slots[0] = {"id": "1001001", "name": "火遁·豪火球", "cooldown": 5.0, "icon": "", "level": 80}
	会话.skill_slots[1] = {"id": "1001002", "name": "火遁·凤仙花", "cooldown": 8.0, "icon": "", "level": 60}
	会话.skill_slots[4] = {"id": "1001005", "name": "写轮眼", "cooldown": 12.0, "icon": "", "level": 80}
	会话.call("设默认忍术", 1001005)
	会话.emit_signal("skills_changed", 会话.skill_slots.duplicate(true))


func _run() -> void:
	var 会话 = root.get_node_or_null("GameSession")
	if 会话 == null:
		printerr("汇：判 1 条 / 红 1 条（截技能栏页：中断）\n  红 - 没有 GameSession 单例")
		quit(1)
		return

	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await _帧(30)
	_喂槽(会话)
	await _帧(6)

	var 面板: Node = null
	for 候 in 图.find_children("*", "CanvasLayer", true, false):
		if 候.get_node_or_null("技能栏") != null:
			面板 = 候
			break
	_查(面板 != null, "地图场景里该找得到带 `技能栏` 的那层 HUD")
	if 面板 == null:
		_尾()
		return
	var 栏: Control = 面板.get_node("技能栏") as Control

	# ── 逐格核对 ──
	var 亮格: Array[String] = []
	for 序号 in range(10):
		var 格 := _找格子(栏, str(序号))
		_查(格 != null, "第 %d 格该存在" % 序号)
		if 格 == null:
			continue
		var 标 := 格.get_node_or_null("KeyLabel") as Label
		var 层 := 格.get_node_or_null("SkillLevel") as Label
		var 光 := 格.get_node_or_null("选中流光") as CanvasItem
		var 皮 := 格.get_node_or_null("ShortcutFrame") as TextureRect
		var 图标件 := 格.get_node_or_null("ShortcutFrame/SkillIcon") as CanvasItem
		## 父子关系要照原版：`addIcon():89` 是 `cellBg.addChild(icon)` ⇒ **图标是底板的子件**、
		## 坐标相对底板。用户 10-12 把底板从 (0,0) 挪到 (-1,0)，硬按格子算 (3,3) 的写法当场错位。
		if 图标件 != null and 皮 != null:
			_查(图标件.get_parent() == 皮, "第 %d 格：图标该挂在底板里（原版 cellBg.addChild）" % 序号)
			_查(图标件.position == Vector2(3, 3),
					"第 %d 格：图标相对底板该是 (3,3)（`(40-34)/2`）；实得 %s" % [序号, str(图标件.position)])
		if 标 != null and 皮 != null:
			## 标号是格子的直接子件、且在底板之后 ⇒ 底板连同里面的图标都在它之下
			## （`KeyboardCell.as:51` vs `:89`）。实测踩过：图标与标号做兄弟时，
			## 放了技能的三格标号被整个盖住，只看"标号文本对不对"量不出来。
			_查(格.get_children().find(皮) < 格.get_children().find(标),
					"第 %d 格：底板(连同图标)该在标号之下 ⇒ 标号永远看得见" % 序号)
		_查(标 != null and 标.text == 标号表[序号],
				"第 %d 格标号该是「%s」；实得 %s" % [序号, 标号表[序号], "" if 标 == null else 标.text])
		## 原版 `keyTextField.bold = true`（`KeyboardCell.as:50` → `:64-67` 默认参数 true）
		## ⇒ 底栏标号必须是**合成粗体**。这条是用户 10-12 用眼睛打回的（"数字有点细"），
		## 只判文本量不出来 ⇒ 判真正生效的那张字体。
		if 标 != null:
			var 字 := 标.get_theme_font("font") as FontVariation
			_查(字 != null and 字.variation_embolden > 0.0 and 字.base_font != null,
					"第 %d 格标号该是合成粗体（embolden>0 且有 base_font）；实得 %s" % [序号,
					"无字体覆盖" if 字 == null else "embolden=%s base=%s" % [
						str(字.variation_embolden), str(字.base_font) if 字.base_font != null else "null"]])
		_查(皮 != null and 皮.texture != null and String(皮.texture.resource_path) == 真值底板,
				"第 %d 格底板该用元件 398 那张（%s）；实得 %s" % [序号, 真值底板,
				"无" if 皮 == null or 皮.texture == null else String(皮.texture.resource_path)])
		_查(光 != null, "第 %d 格该有流光节点（原版空格子也建、只是不可见）" % 序号)
		if 光 != null and bool(光.visible):
			亮格.append(str(序号))
		if 层 != null and bool(层.visible):
			var 本格: Dictionary = 会话.skill_slots[序号]
			_查(层.text == str(int(本格.get("level", 0))),
					"第 %d 格层数文本该是 %s；实得 %s" % [序号, 本格.get("level", 0), 层.text])
	var 槽ids: Array = []
	for 格 in 会话.skill_slots:
		槽ids.append(str(格.get("id", "?")))
	print("[诊断] 默认忍术=%s ⇒ 反查槽=%s；槽里的 id=%s" % [
		str(会话.get("默认忍术")), str(会话.call("默认忍术槽")), str(槽ids)])
	## 阳性对照：先证「夹具真的落地了」，否则下面那条「一格都不亮」既可能是画面坏、
	## 也可能是喂进去的数据被顶掉 —— 两种红完全不是一个活。
	_查(int(会话.call("默认忍术槽")) == 4,
			"夹具该落地：1001005 反查到的槽该是 4；实得 %s" % str(会话.call("默认忍术槽")))
	_查(亮格 == ["4"], "只有「当前选中的那一枚」亮流光 ⇒ 该是第 4 格（默认忍术 1001005）；实得 %s" % str(亮格))

	# ── 摆位：元件 406 `MenuPaneF` 里 `shortcutColumnPane @(249,5)`，元件 405 里十枚格子的 x
	#   = 0/41/82/123/164 · 287/328/369/410/451（`读符号时间轴.py --符号 405` 现查）；
	#   本场景 `技能栏` 原点相对元件 406 是 x−11（`menuBg` 摆在 −11）⇒ 第 i 格左边 = 238 + 元件x。
	#   烤之前是 40/41/42/40 的不匀步距（空格子之间缝一眼看得出宽窄不一）。
	var 元件格x := [0.0, 41.0, 82.0, 123.0, 164.0, 287.0, 328.0, 369.0, 410.0, 451.0]
	for 序号 in range(10):
		var 格 := _找格子(栏, str(序号))
		if 格 == null:
			continue
		_查(格.position.x == 238.0 + 元件格x[序号] and 格.position.y == 47.0
				and 格.size == Vector2(40, 40),
				"第 %d 格摆位该是 (%s, 47) 40×40；实得 (%s, %s) %s" % [序号,
				str(238.0 + 元件格x[序号]), str(格.position.x), str(格.position.y), str(格.size)])

	# ── 流光的几何与相位 ──
	# 原版 `KeyboardCell.setDefaultSkill():163-168`：40 宽的格子 ⇒ 注册点摆到 `x = 3, y = 3`，
	# `mouseEnabled = false`，`addChild` 在最上层；元件 115 的导出画布 35×35。
	# ⚠ **要判的是"亮轨盒"，不是节点盒**：65 帧逐像素数出来亮点只跑四条边
	#   （上=画布第 1 行、下=第 34 行、左=第 0 列、右=第 33 列）⇒ 亮轨盒 = (0,1)..(33,34) = 34×34，
	#   在节点盒里是**偏心**的。用户 10-12 的 flash 同格实拍（43×46，按底板第 1/38 行列定位）
	#   量到亮轨四条边全在底板局部 3..36 ⇒ 亮轨盒与图标盒(3,3,34,34) 严丝合缝。
	#   拿节点盒当"框住图标"会低 1 像素（10-12 实测上边落在局部 4、下边落在 37，被打回"靠右/歪"）。
	const 轨偏 := Vector2(0, 1)		# 亮轨盒左上角在 35×35 画布里的位置
	var 亮格节点 := _找格子(栏, "4")
	var 亮流 := 亮格节点.get_node("选中流光") as Control
	var 亮皮 := 亮格节点.get_node("ShortcutFrame") as Control
	var 亮图 := 亮格节点.get_node_or_null("ShortcutFrame/SkillIcon") as Control
	_查(亮流.global_position == 亮皮.global_position + Vector2(3, 2),
			"流光屏幕位 = 底板位 + (3,2)（注册点 (3,3) 减去画布比注册点高的那 1 像素）；实得 %s" % str(亮流.global_position - 亮皮.global_position))
	_查(亮流.size == Vector2(35, 35), "流光该是元件 115 的内容盒 35×35；实得 %s" % str(亮流.size))
	if 亮图 != null:
		var 轨左 := 亮流.global_position + 轨偏
		var 轨差 := 轨左 - 亮图.global_position
		_查(轨差 == Vector2.ZERO and 亮图.size == Vector2(34, 34),
				"亮轨盒该与图标盒重合（圈把图标框进、四边各留 2 像素到内圈）；实得轨左上差 %s、图标 %s"
				% [str(轨差), str(亮图.size)])
	_查(亮流.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"流光不吃鼠标（原版 `mouseEnabled = false`）⇒ 否则它挡住整格的点击")
	# 相位钉死再拍：AnimatedTexture 每帧都在变，不暂停的话同一份代码两次跑出的图不一样。
	var 动 := 亮流.texture as AnimatedTexture
	_查(动 != null and 动.frames == 65, "流光贴图该是 65 帧 AnimatedTexture；实得 %s"
			% ("null" if 动 == null else str(动.frames)))
	if 动 != null:
		## ⚠ 60 帧/秒，不是 SWF 头上的 24：`Engine.as:13` `STAGE_FRAME_RATE = 60` +
		##   `:50-52` 启动就把舞台帧率改掉 ⇒ 时间轴每舞台帧走一格。按 24 做出来慢 2.5 倍。
		_查(absf(动.get_frame_duration(0) - 1.0 / 60.0) < 0.0001,
				"每帧时长该是 1/60 秒（`Engine.as:13/50-52` 强制舞台 60fps，不是 MainLib 声明的 24）；实得 %s"
				% str(动.get_frame_duration(0)))
		_查(not 动.one_shot, "流光要一直转（原版挂在格子上就不停）")
		动.pause = true
		动.current_frame = 24
		await _帧(3)

	# ── 截图：整条 + 单格 4 倍 ──
	var 视口图: Image = root.get_texture().get_image()
	_查(视口图 != null, "拿得到视口图像（无头跑就会是 null ⇒ 这条量具必须带窗口跑）")
	if 视口图 != null:
		视口图.save_png(ProjectSettings.globalize_path(出目录) + "/整屏.png")
		var 全局: Rect2 = 栏.get_global_rect()
		var 裁 := Rect2i(int(全局.position.x), int(全局.position.y), int(全局.size.x), int(全局.size.y))
		裁.position.y = maxi(0, 裁.position.y)
		裁.size.y = mini(裁.size.y, 视口图.get_height() - 裁.position.y)
		var 条: Image = 视口图.get_region(裁)
		条.save_png(ProjectSettings.globalize_path(出目录) + "/技能条.png")
		var 放大: Image = 条.duplicate()
		放大.resize(条.get_width() * 4, 条.get_height() * 4, Image.INTERPOLATE_NEAREST)
		放大.save_png(ProjectSettings.globalize_path(出目录) + "/技能条_4x.png")
		# 九道缝逐道量：屏幕上这一列的亮度 vs 底条素材（元件 296）本来该是什么。
		# 原版元件 405 的步距是 41、格子宽 40 ⇒ 每两道格子中间正好留 **1 像素**，
		# 而元件 296 在那 1 像素上画了一条亮线（用户说的"竖着的长条"）。
		var 底皮 := (栏.get_node("@TextureRect@111") as TextureRect).texture as Texture2D
		var 底图: Image = 底皮.get_image()
		var 亮缝 := 0
		for 序号 in range(9):
			var 缝 := int(全局.position.x + 栏.get_node("SkillShortcut%d" % 序号).position.x + 40)
			var 屏y := int(全局.position.y + 67)
			var 观测 := 视口图.get_pixel(缝, 屏y)
			var 该是 := 底图.get_pixel(缝 - int(全局.position.x) + 11, 16)
			var 亮 := (观测.r + 观测.g + 观测.b) * 255.0 / 3.0 > 90.0
			if 亮:
				亮缝 += 1
			_查(亮, "第 %d→%d 格之间的分隔亮线该看得见（元件 296 那一列本来 亮度%d/alpha%d）；屏幕 (%d,%d) 实得 (%d,%d,%d) ⇒ 被别的件盖住了" % [
				序号, 序号 + 1, int((该是.r + 该是.g + 该是.b) * 85), int(该是.a * 255), 缝, 屏y,
				int(观测.r * 255), int(观测.g * 255), int(观测.b * 255)])
		print("[缝] 九道里亮的 %d 道" % 亮缝)
		print("[底条皮] %s 图=%s  (617,16)=%s  (289,16)=%s" % [
			String(底皮.resource_path), str(底图.get_size()),
			str(底图.get_pixel(617, 16)), str(底图.get_pixel(289, 16))])
		# 底条本身必须是**整数倍缩放**：元件 296 是 989×50，塞进 988 宽的框 ⇒ 整条被
		# 非整数重采样，1 像素宽的分隔亮线摊成两像素的暗糊（越往右偏得越多，实测右边三道
		# 缝直接变黑 ⇒ 用户看到的"细条没了、还变粗"）。这条判据钉"框宽 == 皮的天然宽"。
		var 皮框 := 栏.get_node("@TextureRect@111") as Control
		_查(皮框.size.x == 底图.get_width() and 皮框.size.y == 底图.get_height(),
				"底条框该正好等于元件 296 的天然尺寸 %d×%d（差一像素就会重采样把分隔线抹糊）；实得 %s" % [
				底图.get_width(), 底图.get_height(), str(皮框.size)])
		print("[位置] 技能栏全局矩形=%s（视口 %dx%d）" % [str(全局), 视口图.get_width(), 视口图.get_height()])
		# 十枚格子紧贴的一条（不含左右无关件）+ 亮着流光那一枚的 8 倍单件 ——
		# 并排全景看不出 34px 框里偏了 3px，这排东西就是要逐件放大的。
		var 左上 := 栏.get_node("SkillShortcut0") as Control
		var 右下 := 栏.get_node("SkillShortcut9") as Control
		var 行 := Rect2i(int(全局.position.x + 左上.position.x), int(全局.position.y + 左上.position.y),
				int(右下.position.x + 右下.size.x - 左上.position.x), int(左上.size.y))
		var 行图: Image = 视口图.get_region(行)
		行图.save_png(ProjectSettings.globalize_path(出目录) + "/格子行.png")
		_放大(行图, 4, "格子行_4x.png")
		var 亮 := _找格子(栏, "4")
		if 亮 != null:
			var 单 := Rect2i(int(全局.position.x + 亮.position.x), int(全局.position.y + 亮.position.y),
					int(亮.size.x), int(亮.size.y))
			_放大(视口图.get_region(单), 8, "第4格_8x.png")

	# ── 换选中：流光要搬家（原版是重建格子，本工程是订阅信号） ──
	会话.call("设默认忍术", 1001001)
	await _帧(6)
	var 再亮: Array[String] = []
	for 序号 in range(10):
		var 格 := _找格子(栏, str(序号))
		var 光 = 格.get_node_or_null("选中流光") if 格 != null else null
		if 光 != null and bool(光.visible):
			再亮.append(str(序号))
	_查(再亮 == ["0"], "改选第 0 枚之后流光该搬过去；实得 %s" % str(再亮))
	# ── 冷却：扇形 + 整格灰度（原版 `MCell.showCoolDown():100-113` → `GirdCool.as`）──
	# 走的是会话那条**信号契约**（`skill_cooldown_changed(槽, 剩余, 总)`），不是自调面板内部函数。
	# ⚠ "总"必须取会话自己那份（= 这枚技能表里的 cooldown），不能自己编一个 6.0：
	#   会话每帧 tick 会用**它自己的总时长**重发信号，喂假总数只会让判据对不上。
	var 总1 := float(会话.skill_slots[1].get("cooldown", 1.0))
	会话.set("skill_cooldowns", {1: 总1 * 0.75})
	会话.emit_signal("skill_cooldown_changed", 1, 总1 * 0.75, 总1)	# 已消耗 25%
	await _帧(4)
	var 格1 := _找格子(栏, "1")
	var 罩 := 格1.get_node_or_null("CooldownOverlay") as ColorRect
	var 皮1 := 格1.get_node("ShortcutFrame") as Control
	_查(罩 != null and 罩.visible, "放完技能该出现冷却遮罩（原版把 GirdCool addChild 到格子上）")
	if 罩 != null:
		_查(罩.position == 皮1.position,
				"遮罩原点该与底板对齐（原版 board 从 cellBg 原点起算）；实得 %s vs %s" % [str(罩.position), str(皮1.position)])
		_查(absf(罩.size.x - 42.0) < 0.01 and absf(罩.size.y - 42.0) < 0.01,
				"遮罩该是 board=42（`GirdCool` 构造第三参，比 40 的底板四周各多 1 像素，圆角才对得上）；实得 %s" % str(罩.size))
		var 材 := 罩.material as ShaderMaterial
		## ⚠ 不能钉死 0.25：会话每帧都在把冷却往下 tick 并重新发信号，等 4 帧之后剩余早就不是 4.5 了
		##   （实测跑到 3.35 ⇒ progress 0.44）。所以拿**会话此刻的剩余**反算期望值，
		##   判的是"喂给 shader 的是 已消耗/总 这个公式"，不是某个具体数。
		var 剩 := float(会话.call("get_skill_cooldown", 1))
		var 期望 := (总1 - 剩) / 总1
		var 进 := -1.0 if 材 == null else float(材.get_shader_parameter("progress"))
		_查(材 != null and absf(进 - 期望) < 0.06,
				"progress 该是 **已消耗/总** = (%s-%s)/%s = %s（原版 `draw():56` 用 lastTime/coolTime，不是剩余/总）；实得 %s" % [
				str(总1), str(剩), str(总1), str(期望), str(进)])
	var 图1 := 格1.get_node_or_null("ShortcutFrame/SkillIcon") as TextureRect
	_查(图1 != null and 图1.texture != null and String(图1.texture.resource_path).is_empty(),
			"冷却中图标该换成**去色副本**（原版给整格挂 Style.getDisableFilter，本工程等价做法是换图，不用 modulate）")
	var 标1 := 格1.get_node_or_null("KeyLabel") as Label
	var 黄 := 标1.get_theme_color("font_color") if 标1 != null else Color.TRANSPARENT
	_查(标1 != null and absf(黄.r - 黄.g) < 0.001 and absf(黄.g - 黄.b) < 0.001,
			"冷却中标号也该变灰（R=G=B）；实得 %s" % str(黄))
	# ⚠ **必须看像素**：上面那些"节点属性对不对"的判据，在着色器编译失败时会全绿 ——
	#   因为 `ColorRect` 拿不到有效材质就退回它自己的默认色 = **纯白**，格子上就是一块白。
	#   （10-12 实测踩过：`uniform float corner : float = 5.0` 编译不过，15 条判据照样过。）
	var 视口冷: Image = root.get_texture().get_image()
	if 罩 != null and 视口冷 != null:
		var 冷格: Rect2 = 格1.get_global_rect()
		var 暗点 := 视口冷.get_pixel(int(冷格.position.x + 9), int(冷格.position.y + 31))	# 左下：还该被黑盖着
		var 亮点 := 视口冷.get_pixel(int(冷格.position.x + 31), int(冷格.position.y + 9))	# 右上：已转掉，该露图标
		var 暗 := (暗点.r + 暗点.g + 暗点.b) / 3.0
		var 亮 := (亮点.r + 亮点.g + 亮点.b) / 3.0
		print("[冷却像素] 左下(该暗)=%.2f 右上(该亮)=%.2f" % [暗, 亮])
		_查(暗 < 0.55 and 亮 > 暗 + 0.08,
				"冷却扇形该真的画出「转掉一块」：左下被黑盖住(亮度<0.55)、右上已转开(比左下亮)；实得 左下 %.2f 右上 %.2f" % [暗, 亮])
		_查(暗 < 0.9 or 亮 < 0.9,
				"整格不许是白块（着色器没生效时 ColorRect 退回默认白，属性判据量不出来）；实得 左下 %.2f 右上 %.2f" % [暗, 亮])
	# 冷却中的那一格单独出一张 8 倍图，给人眼验收用
	var 视口2: Image = root.get_texture().get_image()
	if 视口2 != null:
		var 全2: Rect2 = 栏.get_global_rect()
		var 单2 := Rect2i(int(全2.position.x + 格1.position.x) - 2, int(全2.position.y + 格1.position.y) - 2, 44, 44)
		_放大(视口2.get_region(单2), 8, "冷却中_第2格_8x.png")
	# 冷却结束 ⇒ 原版 `destroy()`：遮罩消失、灰度撤掉
	会话.set("skill_cooldowns", {})
	会话.emit_signal("skill_cooldown_changed", 1, 0.0, 总1)
	await _帧(4)
	_查(罩 != null and not 罩.visible, "冷却结束遮罩该消失（原版剩余 ≤ 0 直接 removeCoolDown）")
	_查(图1 != null and not String(图1.texture.resource_path).is_empty(),
			"冷却结束图标该换回彩色原皮；实得 %s" % ("还是无路径的副本" if 图1 == null or String(图1.texture.resource_path).is_empty() else String(图1.texture.resource_path)))
	_查(标1 != null and absf(标1.get_theme_color("font_color").b - 0.490196) < 0.001,
			"冷却结束标号该回到黄色 #FEF37D；实得 %s" % str(标1.get_theme_color("font_color") if 标1 else "无"))
	图.queue_free()
	await _帧(3)
	_尾()

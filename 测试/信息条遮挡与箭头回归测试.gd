extends SceneTree
## 有头量具：目标信息条**在真实场景里**到底被谁压住，以及选中箭头到底落在头顶还是脚边。
##
## 为什么要有它（10-15 用户实机两条打回，两条都是上一轮的门结构上测不到的）：
##   · `截目标信息条页.gd` 只把头像面板单独 instantiate 到空 root 上 ⇒ 屏幕上**根本没有别的
##     HUD**，"被其他按钮挡住"这一条它测不出来（138 条全绿仍被打回）。
##   · 箭头那条的门钉的是"我调过 `_更新头顶挂件位置`"，而远程玩家的演员是裸 `Node2D`、
##     压根没有那个方法 ⇒ `has_method` 落空、箭头停在原点（脚边）。
## 所以这里加载**真正的地图场景**（底栏/技能栏/精气球/小地图/窗口管理全在），
## 再逐节点算画序键 = (所属 CanvasLayer.layer, z_index 累计, 全树先序号)。
##
## 用法（**不能加 --headless**，无头拿不到视口图像）：
##     "godot" --path . --script res://测试/信息条遮挡与箭头回归测试.gd

const 出目录 := "res://测试/截图/目标信息条"

var 通过 := 0
var 红: Array[String] = []
var 能出图 := false		## 无头跑时 false：跳过一切取视口图像的动作
var _序 := 0
var _序表 := {}


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		红.append(话)
		print("红：%s" % 话)


## 遮挡那几条**依赖视口宽度**（条是 `anchor=0.5` 居中，原版算式
## `x = round((960 − 232)/2) = 364`），而无头模式下 `root.size` 不跟窗口走、视口只有几十像素宽
## ⇒ 条被甩到屏幕外，"重叠"与"没被挡"都失去意义 ⇒ 明说跳过，**不许让它伪装成绿**。
## （箭头落点 / 冻帧 / 层序那几条与宽度无关，无头照判。）
func _视口够宽() -> bool:
	return root.get_visible_rect().size.x >= 900.0


func _initialize() -> void:
	await _跑()
	quit(1 if 红.size() > 0 else 0)


func _跑() -> void:
	print("信息条遮挡 + 箭头 有头量具开始")
	## 判据本身**不需要渲染**（矩形、树序、箭头 position、精灵 paused 都是数据），
	## 只有裁图要视口图像 ⇒ 无头跑时跳过出图，这条才进得了 `验证全部.ps1` 那份全量清单
	## （那份是 `--headless` 逐条跑的）。手工出证据时才带上窗口。
	能出图 = DisplayServer.get_name() != "headless"
	root.size = Vector2i(960, 560)
	for i in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for i in 20:
		await process_frame
	var 面板 = 场景.get_node_or_null("头像面板")
	_判(面板 != null, "地图场景里挂了头像面板（没有就是场景变了，这条量具要跟着改）")
	if 面板 == null:
		return
	var 会话 = root.get_node("/root/GameSession")
	var 生怪根 = 场景.get_node_or_null("LifeRoot")

	# ── ① 选中一个玩家，把信息条真画出来 ──────────────────────────────
	会话.call("select_map_character", {
			"name": "木叶忍者", "level_text": "LV.11", "hp": 381, "max_hp": 381,
			"mp": 349, "max_mp": 349, "type": 1, "char_id": 1, "level": 11, "face": 1})
	for i in 40:
		await process_frame
	var 条 := 面板.get_node("头像区域/选中人物信息") as Control
	var 我 := 面板.get_node("头像区域/角色状态") as Control
	_判(条.visible, "选中玩家后信息条 visible")
	print("条矩形 %s" % str(条.get_global_rect()))
	print("自己头像区矩形 %s" % str(我.get_global_rect()))
	if _视口够宽():
		_判(not 条.get_global_rect().intersects(我.get_global_rect()) or not 我.visible,
				"信息条与自己那套头像不重叠（重叠就是两条同时画，看着像被挡）")

	# ── ② 全树画序普查：谁画在条上面、且和条相交 ─────────────────────
	## ⚠ 先把 6 枚 Buff 图标**摆成可见**再普查：原版 `BuffPane` 一行 6 枚、步距 41
	## （`BuffPane.as:89-90`，`BuffCell.as:70-71` 每枚 40×40），起点 = 头像窗宽 260
	## （`UIMain2.as:5756` `buffPanel.x = charactorInfoPane.width`）⇒ 占 x 260..506，
	## 与居中那条（x 365..597）**原版就是重叠的**，靠"窗口后 addChild ⇒ 画在上面"解决。
	## 离线默认六枚全 hidden ⇒ 不喂就是假绿（上一轮 138 条全绿却被打回的同一条坑）。
	var 排 = 面板.get_node("头像区域/状态效果")
	for 枚 in 排.get_children():
		(枚 as CanvasItem).visible = true
	for i in 3:
		await process_frame
	_序 = 0
	_序表 = {}
	_编号(root)
	var 条键 := _画序(条)
	var 条框 := 条.get_global_rect()
	var 压: Array[String] = []
	for 项 in _所有控件(root):
		if 项 == 条 or _是祖先(项, 条) or _是后代(项, 条):
			continue
		if not _在屏幕上(项):
			continue
		var 框: Rect2 = (项 as Control).get_global_rect()
		var 交 := 框.intersection(条框)
		if 交.size.x < 1.0 or 交.size.y < 1.0:
			continue
		var 键 := _画序(项 as CanvasItem)
		if _在上面(键, 条键):
			压.append("%s 层%d z%d 序%d 交=%.0fx%.0f" % [
					项.get_path(), 键[0], 键[1], 键[2], 交.size.x, 交.size.y])
	print("条的画序键 = 层%d z%d 序%d" % [条键[0], 条键[1], 条键[2]])
	for 行 in 压:
		print("  压在条上面 → %s" % 行)
	print("条的画序键 = 层%d z%d 序%d" % [条键[0], 条键[1], 条键[2]])
	for 行 in 压:
		print("  压在条上面 → %s" % 行)
	## 阳性对照：Buff 排与条**必须**在几何上真的重叠，否则上面那条绿是"没东西可挡"的空转。
	var 排交: Rect2 = 排.get_global_rect().intersection(条框)
	## ⚠ 这两条**依赖视口宽度**（条是 `anchor=0.5` 居中，原版算式
	## `x = round((960 − 232)/2) = 364`），而无头模式下 `root.size` 不跟窗口走、视口只有
	## 几十像素宽 ⇒ 条被甩到屏幕外，"重叠"与"没被挡"两条都失去意义。
	## 所以无头时**明说跳过**，不许让它伪装成绿（箭头落点 / 冻帧 / 层序那三条与宽度无关，照判）。
	if not _视口够宽():
		print("跳过遮挡两条：视口只有 %.0f 宽（要有头跑才量得出居中后的条与 Buff 排重叠）"
				% root.get_visible_rect().size.x)
	else:
		_判(压.is_empty(), "没有任何控件画在信息条上面（实得 %d 个，见上面名单）" % 压.size())
		_判(排交.size.x > 20.0 and 排交.size.y > 10.0,
				"阳性对照：Buff 排与条几何重叠（交 %.0f×%.0f）⇒ 层序这一判据有东西可挡" % [排交.size.x, 排交.size.y])

	# ── ②b 像素级 A/B：**Buff 排到底有没有盖在条上面** ─────────────────
	## 只读 `z_index` 的值 = 自证（"我确实设了 1"，用户 10-15 反复打回的就是这种绿）。
	## ⚠ 第一版直接拿"全量渲染"与"藏掉 Buff 排"比 ⇒ 4018 像素差，**但那是假红**：
	## 条自己有很多透明缝（钮之间、圆框之外），藏掉 Buff 后那些缝露的是**会动的世界**，
	## 差异来自"背景换了"而不是"谁盖谁"。
	## ⇒ 正确量法：**先把世界层全藏掉**（两拍背景都是黑的），再比 A/B ——
	## 这样条的透明处两拍相同，**唯一的差异来源就是 HUD 之间的层序**。
	if 能出图:
		var 藏 := await _藏世界()
		var 条矩形 := 条.get_global_rect()
		var A := _取区(条矩形)
		排.visible = false
		for i in 3:
			await process_frame
		var B := _取区(条矩形)
		排.visible = true
		## ⚠ **不设 alpha 门槛**：世界已经藏掉 ⇒ 背景两拍完全相同，唯一可能的差异来源就是
		## 那排 Buff 图标。上一版在这里加了"B 不透明才比"，而 Buff 盖住的地方 B 反而是透明的
		## ⇒ 恰好把要抓的点跳过了（自己把自己判没了）。
		var 差 := 0
		var 首个 := ""
		for y in B.get_height():
			for x in B.get_width():
				if A.get_pixel(x, y) != B.get_pixel(x, y):
					差 += 1
					if 首个.is_empty():
						首个 = "(%d,%d)" % [x, y]
		await _还世界(藏)
		print("藏掉 Buff 排后条矩形内 %d 个像素跟着变（第一处 %s）" % [差, 首个])
		## ⚠ **这条现在是"已知未修"，只报数不判红**（用户 10-15 判定：他全屏玩，全屏时
		## 两者不重叠 ⇒ 不收）。真实原因：条是 `anchor=0.5` **居中**（跟着窗口宽度跑），
		## Buff 排是**绝对定位**钉在头像右边 ⇒ 960 宽窗口下重叠、全屏下错开；
		## 而原版舞台恒 960 ⇒ **永远重叠、永远靠 addChild 顺序盖**（`UIMain2.as:5756`）。
		## ⚠ 实测 `z_index = 1` **压不过树序**（藏掉 Buff 排仍有 4018 像素变化）⇒
		## 真要收这条得把 `选中人物信息` 整块挪到 `状态效果` **之后**（Godot 里 Control 兄弟
		## 的先后按树序），不是加 z_index。见任务 #226。
		if 差 > 0:
			print("未修（用户判定全屏不收）：窗口模式下 Buff 排仍盖在信息条上面 %d 像素 ⇒ 要修就挪树序" % 差)

	# ── ③ 截屏证据：整屏 + 左上角放大 ────────────────────────────────
	if 能出图:
		var 屏 := root.get_texture().get_image()
		屏.save_png(ProjectSettings.globalize_path(出目录) + "/真实场景_整屏.png")
		_裁(屏, Rect2i(0, 0, 660, 140), 2, "真实场景_左上")

	## ⚠ `_on_server_player_spawned` 开头有三道闸（有 backend / in_game / 同图），离线全不满足
	## ⇒ 直接喂帧会被静默丢掉（第一版就是这么"红"的）。闸的对象要**从 `生怪根._backend` 取**：
	## 那是它自己认得的那个后端对象，按 autoload 名字去 root 下找会找错（第一版找"后端连接"
	## 就是 null，判据看起来是"造不出演员"，其实是闸没打开）。
	var 后端 = 生怪根.get("_backend") if 生怪根 != null else null
	if 后端 != null:
		后端.set("in_game", true)
	if 生怪根 != null:
		var 本图 = str(会话.get("current_map_id"))
		var 我的编号: int = int(后端.get("character_id")) if 后端 != null else -999
		print("三道闸现值：backend=%s in_game=%s 我的编号=%d 本图=%s" % [
				str(后端 != null), str(后端.get("in_game")) if 后端 != null else "?",
				我的编号, 本图])
		## 编号要**避开"我自己那一个"**：`_on_server_player_spawned` 第二道闸就是
		## `remote_id == 自己的 character_id ⇒ return`（自己不该被建成远程演员）。
		var 别人: int = 我的编号 + 777
		生怪根.call("_on_server_player_spawned", {
				"character_id": 别人, "name": "木叶忍者", "face": 1, "direction": 1,
				"x": 500.0, "y": 300.0, "movement_action": 1, "map_id": 本图})
		for i in 6:
			await process_frame
		var 演员 = 生怪根.get("_remote_players").get(别人) as Node2D
		_判(演员 != null, "造出了远程玩家演员（编号 %d）" % 别人)
		if 演员 != null:
			var 精灵 = 演员.get_child(0)
			var 高 := float(精灵.call("当前贴图高度"))
			_判(高 > 0.0, "远程玩家精灵取到了贴图高（实得 %.1f）" % 高)
			生怪根.call("_attach_selection_marker", 演员)
			(演员.get_node_or_null("SelectionMarker") as CanvasItem).visible = true
			for i in 4:
				await process_frame
			var 箭头 := 演员.get_node_or_null("SelectionMarker") as Node2D
			_判(箭头 != null, "远程玩家身上挂到了箭头")
			if 箭头 != null:
				var 期望y := -高 - 8.0
				print("箭头 position=%s  期望 y=%.1f（= −贴图高 %.1f − 8）" % [
						str(箭头.position), 期望y, 高])
				_判(箭头.position.y < 0.0, "箭头在脚点**之上**（y<0），不是停在原点")
				_判(absf(箭头.position.y - 期望y) <= 1.0,
						"箭头 y = −贴图高 − 8（实得 %.1f，期望 %.1f）" % [箭头.position.y, 期望y])

			# 攀爬：喂一条带竖直速度的移动帧，画面必须**在动**（上一版恒冻在第 0 帧）
			生怪根.call("_on_server_player_moved", {
					"character_id": 别人, "x": 500.0, "y": 260.0, "direction": 1,
					"velocity_x": 0.0, "velocity_y": -125.0, "movement_action": 4})
			for i in 8:
				await process_frame
			var 爬帧号 = 精灵.get("frame_index")
			var 爬着 = 精灵.get("action")
			_判(str(爬着) == "ladder" or str(爬着) == "rope",
					"攀爬时动作切到了 ladder/rope（实得 %s）" % str(爬着))
			_判(not bool(精灵.get("paused")),
					"正在爬的人**不许被冻帧**（paused=true 就是那个恒真判据：位置在动、画面不动）")
			print("攀爬 8 帧后：动作=%s 帧号=%s paused=%s" % [
					str(爬着), str(爬帧号), str(精灵.get("paused"))])
			# 停在绳上（速度 0）才该冻第 0 帧
			生怪根.call("_on_server_player_moved", {
					"character_id": 别人, "x": 500.0, "y": 260.0, "direction": 1,
					"velocity_x": 0.0, "velocity_y": 0.0, "movement_action": 4})
			for i in 4:
				await process_frame
			_判(bool(精灵.get("paused")), "停在绳上（速度 0）才冻在第 0 帧")
			# ── 打坐：旁观端那具身体也要有那圈光环（原版挂在**角色基类**上）────────
			## `Character.as:2742-2762 tickHealAnimation()` 的条件只有
			## `movementAction == SIT0 || SIT1` ⇒ 远程玩家也是 Character、movementAction 由
			## `CommandController` 从 187 帧设 ⇒ 旁观者本来就该看到。用户 10-15 报的就是这一漏。
			生怪根.call("_on_server_player_moved", {
					"character_id": 别人, "x": 500.0, "y": 260.0, "direction": 1,
					"velocity_x": 0.0, "velocity_y": 0.0, "movement_action": 7})
			for i in 8:
				await process_frame
			var 环 := 演员.get_node_or_null("打坐光环") as Node2D
			_判(环 != null, "对端坐下（动作 7）后，旁观端那具身体上挂出了打坐光环")
			if 环 != null:
				var 牌 := 演员.get_node_or_null("Nameplate")
				if 牌 != null:
					var 环序 := 演员.get_children().find(环)
					var 牌序 := 演员.get_children().find(牌)
					_判(环序 >= 0 and 牌序 >= 0 and 环序 < 牌序,
							"光环排在名字牌之前（盖住身体、不糊名字）：环=%d 牌=%d" % [环序, 牌序])
				if 能出图:
					## ⚠ 只查"节点存在"= 假绿（记忆那条"特效只查节点属性=假绿"同一条坑）
					## ⇒ 数像素：藏掉背景层（**留着 LifeRoot**，光环是演员的子节点，
					## 把 LifeRoot 一起藏就连演员也看不见、两拍都相同 ⇒ 判据自己把自己判没）,
					## 再比"光环在"与"光环藏"两拍。
					var 藏2 := await _藏世界(false)
					var 中心: Vector2 = 演员.get_viewport().get_canvas_transform() * 演员.get_global_position()
					var 框2 := Rect2(中心 + Vector2(-70, -150), Vector2(150, 170))
					var 有环 := _取区(框2)
					环.visible = false
					for i in 3:
						await process_frame
					var 无环 := _取区(框2)
					环.visible = true
					var 多 := 0
					for y in 无环.get_height():
						for x in 无环.get_width():
							if 有环.get_pixel(x, y) != 无环.get_pixel(x, y):
								多 += 1
					await _还世界(藏2)
					_裁(root.get_texture().get_image(),
							Rect2i(int(中心.x) - 70, int(中心.y) - 150, 150, 170), 3, "真实场景_别人打坐")
					print("打坐光环真画在屏幕上：藏掉它少 %d 个像素" % 多)
					_判(多 >= 200, "光环不是空节点：藏掉它屏幕上有 %d 个像素跟着消失（阈值 200）" % 多)
			## 站起来 ⇒ 光环必须摘掉（挂着就是孤儿特效）
			生怪根.call("_on_server_player_moved", {
					"character_id": 别人, "x": 500.0, "y": 260.0, "direction": 1,
					"velocity_x": 0.0, "velocity_y": 0.0, "movement_action": 1})
			for i in 8:
				await process_frame
			_判(演员.get_node_or_null("打坐光环") == null,
					"站起来（动作 1）之后光环摘掉了（挂着就是孤儿特效）")
			var 世界 := 演员.get_global_position()
			var 箭头屏: Vector2 = 演员.get_viewport().get_canvas_transform() * 箭头.get_global_position()
			print("箭头屏幕位 %s（角色世界位 %s）" % [str(箭头屏), str(世界)])
			## 裁框要按**屏幕位**取：相机跟着玩家走，世界坐标和屏幕坐标不是一回事。
			if 能出图:
				_裁(root.get_texture().get_image(),
						Rect2i(int(箭头屏.x) - 95, int(箭头屏.y) - 20, 200, 230), 3, "真实场景_箭头与攀爬")
	print("信息条遮挡 + 箭头量具：通过 %d，红 %d" % [通过, 红.size()])


## 全树先序编号：同一父节点下**后出现**的先序号更大，而 Godot 正是"后画的在上面"。
func _编号(节: Node) -> void:
	_序 += 1
	_序表[节.get_instance_id()] = _序
	for 子 in 节.get_children():
		_编号(子)


func _所有控件(节: Node, 收: Array = []) -> Array:
	for 子 in 节.get_children():
		if 子 is Control:
			收.append(子)
		_所有控件(子, 收)
	return 收


func _在屏幕上(件: Control) -> bool:
	var 查: Node = 件
	while 查 != null:
		if 查 is CanvasItem and not (查 as CanvasItem).visible:
			return false
		if 查 is CanvasLayer and not (查 as CanvasLayer).visible:
			return false
		查 = 查.get_parent()
	return true


## 画序键 = [所属 CanvasLayer 的 layer, 该层内 z_index 累计, 全树先序号]。
func _画序(件: CanvasItem) -> Array:
	var 层号 := 0
	var 层根: Node = null
	var 上: Node = 件.get_parent()
	while 上 != null:
		if 上 is CanvasLayer:
			层号 = (上 as CanvasLayer).layer
			层根 = 上
			break
		上 = 上.get_parent()
	var 链: Array = []
	var m: Node = 件
	while m != null and m != 层根:
		链.push_front(m)
		m = m.get_parent()
	var 累 := 0
	var 首 := true
	for 项 in 链:
		if not (项 is CanvasItem):
			continue
		var ci := 项 as CanvasItem
		累 = int(ci.z_index) if (首 or not ci.z_as_relative) else 累 + int(ci.z_index)
		首 = false
	return [层号, 累, int(_序表.get(件.get_instance_id(), 0))]


func _在上面(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return int(a[0]) > int(b[0])
	if a[1] != b[1]:
		return int(a[1]) > int(b[1])
	return int(a[2]) > int(b[2])


func _是祖先(候: Node, 节: Node) -> bool:
	var 上: Node = 节.get_parent()
	while 上 != null:
		if 上 == 候:
			return true
		上 = 上.get_parent()
	return false


func _是后代(候: Node, 节: Node) -> bool:
	return _是祖先(节, 候)


## 把世界层全藏掉，返回"被谁藏了"以便还原。
## ⚠ 数像素判"某特效到底画出来没有"之前**必须**先藏世界：世界里有会动的角色与背景，
## 两拍之间本来就不同 ⇒ 不藏就是假红（本轮 ②b 第一版就被这个坑过一次"4018 像素"）。
func _藏世界(藏角色: bool = true) -> Array:
	var 名单 := ["TileRoot", "ObjectRoot", "Footholds", "LadderRoot", "PortalRoot"]
	if 藏角色:
		名单.append("LifeRoot")
	var 藏: Array = []
	for 世界名 in 名单:
		var 世 = root.get_node("地图场景").get_node_or_null(世界名)
		if 世 is CanvasItem and (世 as CanvasItem).visible:
			(世 as CanvasItem).visible = false
			藏.append(世)
	for i in 3:
		await process_frame
	return 藏


func _还世界(藏: Array) -> void:
	for 世 in 藏:
		if is_instance_valid(世):
			(世 as CanvasItem).visible = true
	for i in 3:
		await process_frame


## 从视口图像里按屏幕矩形裁一块（A/B 两拍各取一次，用来逐像素比）。
func _取区(框: Rect2) -> Image:
	var 屏 := root.get_texture().get_image()
	var 左: int = clampi(int(框.position.x), 0, 屏.get_width() - 1)
	var 上: int = clampi(int(框.position.y), 0, 屏.get_height() - 1)
	var 宽: int = maxi(1, mini(int(框.size.x), 屏.get_width() - 左))
	var 高: int = maxi(1, mini(int(框.size.y), 屏.get_height() - 上))
	var 出 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	for y in 高:
		for x in 宽:
			出.set_pixel(x, y, 屏.get_pixel(左 + x, 上 + y))
	return 出


func _裁(屏: Image, 框: Rect2i, 倍: int, 名: String) -> void:
	var 左: int = maxi(0, 框.position.x)
	var 上: int = maxi(0, 框.position.y)
	var 宽: int = mini(框.size.x, 屏.get_width() - 左)
	var 高: int = mini(框.size.y, 屏.get_height() - 上)
	if 宽 <= 0 or 高 <= 0:
		print("裁 %s 失败：框在屏外 %s" % [名, str(框)])
		return
	var 裁 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	for y in 高:
		for x in 宽:
			裁.set_pixel(x, y, 屏.get_pixel(左 + x, 上 + y))
	裁.save_png(ProjectSettings.globalize_path(出目录) + "/" + 名 + ".png")
	裁.resize(宽 * 倍, 高 * 倍, Image.INTERPOLATE_NEAREST)
	裁.save_png(ProjectSettings.globalize_path(出目录) + "/%d倍_%s.png" % [倍, 名])
	print("拍了 %s：矩形 (%d,%d,%d,%d)" % [名, 左, 上, 宽, 高])

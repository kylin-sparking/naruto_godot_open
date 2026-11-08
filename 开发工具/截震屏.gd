extends SceneTree

## 震屏端到端量具（**有头**，无头拿不到视口图像）。
##
## 为什么要它：离线门只能证到"键的值 → 相机排了几拍"，证不到用户那句
## 「暴击了但没有震动效果」——那是一条**整条链**：设置页那枚框点下去 → 会话里的键 →
## 玩家打出暴击 → 相机真的把世界挪了 → 而且**HUD 不能跟着晃**。这五步离线门各管一段，
## 中间那截"值写对了但方向反了"（2026-10-11 就是栽在这）只有走真入口才看得见。
##
## 跑法（不要加 --headless）：
##   "godot" --path . --script res://开发工具/截震屏.gd
## 出图：测试/截图/震屏/{静止,抖动中,复位}.png
##
## ⚠ 会点设置页 ⇒ 会落 `user://玩家数据.json`：开头按字节快照、结尾原样写回，并断言字节一致
##   （离线门不许留存档，这条规矩对量具同样成立）。

const 出目录 := "res://测试/截图/震屏"

var _红 := 0
var _判 := 0


func _判据(条件: bool, 说明: String) -> void:
	_判 += 1
	if not 条件:
		_红 += 1
		push_error("✗ " + 说明)
	else:
		print("  ok " + 说明)


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for _i in n:
		await process_frame


func _存档路径() -> String:
	return OS.get_user_data_dir() + "/玩家数据.json"


func _读(路径: String) -> PackedByteArray:
	if not FileAccess.file_exists(路径):
		return PackedByteArray()
	var 文 := FileAccess.open(路径, FileAccess.READ)
	if 文 == null:
		return PackedByteArray()
	return 文.get_buffer(文.get_length())


func _跑() -> void:
	var 会 := root.get_node_or_null("GameSession")
	if 会 == null:
		push_error("没有 GameSession autoload")
		quit(1)
		return
	# ── 存档快照（点设置页会写盘）────────────────────────────────────────
	var 存档 := _存档路径()
	var 原样 := _读(存档)
	var 设置原样: Dictionary = 会.game_settings.duplicate(true)
	_判据(true, "存档快照：%s（%d 字节）" % [存档, 原样.size()])

	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(14)
	var 玩 := 场景.get_node_or_null("Player") as Node2D
	var 相机 := root.get_viewport().get_camera_2d() as Camera2D
	_判据(相机 != null, "地图场景起来后有当前相机（震屏要写它的 offset）")
	if 相机 == null or 玩 == null:
		_收尾(存档, 原样, 设置原样)
		return
	_判据(相机.is_class("Camera2D"), "当前相机是 Camera2D（%s）" %相机.get_class())

	# ── ① 起步：新号默认不抖（与原版 `forbidEarthQuake = true` 同向）──────
	## ⚠ 这里读的是**新号的默认档**（`离线示例数据.create()` 现造一份），不是当前会话里的值：
	## 会话那份是从 `user://玩家数据.json` 读回来的 —— 用户自己勾过、别的量具写过，拿它当
	## "默认值对不对"的证据必然错（2026-10-11 这条连红三次才查到是读错了对象）。
	var 默认档: Dictionary = (load("res://脚本/单例/离线示例数据.gd") as GDScript)\
			.call("create").get("game_settings", {})
	var 默认值 = 默认档.get("screen_shake", "(没这个键)")
	会.game_settings["screen_shake"] = false
	玩.call("_震屏")
	_判据(int(相机.get("_震剩余拍")) == 0 and 相机.offset == Vector2.ZERO,
			"① 勾着「遮罩暴击震屏」（键 false）时喊震**什么都不动**；实得 默认=%s 剩余=%d 偏移=%s"
			% [str(默认值), int(相机.get("_震剩余拍")), str(相机.offset)])
	_判据(bool(默认值) == false,
			"①b 新号默认就得是 false（= 起步不抖，对齐 `SysCfg.as:30`）；实得 %s" % str(默认值))

	# ── ② 真点设置页那枚框：走会话的 `request_feature("设置")`（= 底栏那颗钮的入口），
	#    再真 push_input 点它，不许 `emit` 信号（emit 会演绿）。
	会.set("in_game", true)
	var 管理 = root.find_child("窗口管理", true, false)
	会.call("request_feature", "设置")
	await _帧(14)
	var 框: Control = root.find_child("复选遮罩暴击震屏", true, false) as Control
	var 钮: Button = null
	if 框 != null:
		钮 = 框.find_child("点击区域", true, false) as Button
	# 找不到就把窗口侧的真相打出来（是窗没开、还是开了但层级不对）
	if 钮 == null:
		print("  [诊断] 窗口管理=%s 取窗口(设置)=%s 层的直接子节点=%s" % [str(管理),
				str(管理.call("取窗口", "设置")) if 管理 != null and 管理.has_method("取窗口") else "(没这个入口)",
				str(框.get_children()) if 框 != null else "(连 复选遮罩暴击震屏 都没找到)"])
	_判据(钮 != null, "② 设置页里找得到「遮罩暴击震屏」那枚的点击区（找不到就是窗没真开成）")
	if 钮 != null and is_instance_valid(钮):
		## ⚠ 用之前按**名字**重新找一次：① 设置页整页重画会把旧节点 free 掉
		## （2026-10-11 栽在 `Cannot call method 'get_node' on a previously freed instance`）；
		## ② 全工程有很多个都叫「点击区域」的节点，`root.find_child("点击区域")` 会点到别家的框上
		## （实测就是这条：值前=值后=false，看着像"那枚勾没响应"，其实压根没点到它）。
		var 框2: Control = root.find_child("复选遮罩暴击震屏", true, false) as Control
		var 钮2: Button = (框2.find_child("点击区域", true, false) as Button) if 框2 != null else null
		var 标记2: CanvasItem = (框2.find_child("标记", true, false) as CanvasItem) if 框2 != null else null
		_判据(钮2 != null and is_instance_valid(钮2) and 标记2 != null,
				"②b 复选本体往下找得到「点击区域」与「标记」（重画后引用的存活检查）；框=%s" % str(框2))
		if 钮2 != null and is_instance_valid(钮2):
			var 勾前 := 标记2 != null and 标记2.visible
			var 值前 = 会.game_settings.get("screen_shake", null)
			# 真输入：两步瞬移（大距离一跳不触发 mouse_entered），再按一次松一次
			var 钮尺寸: Vector2 = 钮2.size
			var 心: Vector2 = 钮2.global_position + 钮尺寸 * 0.5
			var 屏2: Vector2 = root.get_viewport().get_visible_rect().size
			心.x = clampf(心.x, 1.0, 屏2.x - 2.0)
			心.y = clampf(心.y, 1.0, 屏2.y - 2.0)
			var 移 := InputEventMouseMotion.new()
			移.position = 心 * 0.5
			root.get_viewport().push_input(移)
			await process_frame
			移 = InputEventMouseMotion.new()
			移.position = 心
			root.get_viewport().push_input(移)
			await process_frame
			var 按 := InputEventMouseButton.new()
			按.position = 心
			按.button_index = MOUSE_BUTTON_LEFT
			按.pressed = true
			root.get_viewport().push_input(按)
			await process_frame
			按 = InputEventMouseButton.new()
			按.position = 心
			按.button_index = MOUSE_BUTTON_LEFT
			按.pressed = false
			root.get_viewport().push_input(按)
			await _帧(6)
			var 勾后 := 标记2 != null and is_instance_valid(标记2) and 标记2.visible
			var 值后 = 会.game_settings.get("screen_shake", null)
			_判据(值前 != 值后 and bool(值后) == true,
					("②c 真点一下那枚框 ⇒ 会话键翻成 true（取消遮罩=允许抖）；"
					+ "实得 前=%s 后=%s 勾=%s→%s 钮位置=%s 尺寸=%s")
					% [str(值前), str(值后), str(勾前), str(勾后), str(心), str(钮尺寸)])
	# 关窗也走真入口（那枚钮的 `pressed` 还连着 `request_feature`，重复连会报错）
	if 管理 != null and is_instance_valid(管理) and 管理.has_method("全部关闭"):
		管理.call("全部关闭")
		await _帧(6)
	# ── ③ 取消勾选之后，打出一发暴击就该真的抖 ─────────────────────────
	会.game_settings["screen_shake"] = true
	相机.call("_震复位")
	var 怪: Node2D = null
	var 根 = 场景.get_node_or_null("LifeRoot")
	for 实体 in (根.get("_entities") as Array):
		var 谁 := 实体 as Node2D
		if 谁 != null and String(谁.get("kind")) == "m" and bool(谁.get("alive")):
			怪 = 谁
			break
	if 怪 == null:
		_判据(false, "③ 本图没有活怪，端到端这一腿没地方打")
	else:
		会.player_stats["critical"] = 50000
		会.player_stats["attack"] = 1
		会.player_stats["hp"] = 100000000
		会.player_stats["dodge"] = 0
		var 抖上 := false
		for _下 in 80:
			怪.set("hp", 200000)
			怪.set("alive", true)
			玩.call("_结算一只", 怪, 0)
			if int(相机.get("_震剩余拍")) > 0:
				抖上 = true
				break
		_判据(抖上, "③ 取消勾选后玩家打出暴击，真的把相机排上了拍子（80 下里至少一次）")
		var 界内 := true
		var 动过 := false
		for _拍 in 6:
			await process_frame
			var 偏: Vector2 = 相机.offset
			for 轴 in [偏.x, 偏.y]:
				if 轴 != 0.0 and (轴 < -15.0 or 轴 > 14.0 or 轴 != floorf(轴)):
					界内 = false
			if 偏 != Vector2.ZERO:
				动过 = true
		_判据(界内, "④ 真帧里跑完这 6 拍，每一拍偏移都在 [-15,14] 的整数上")
		_判据(动过, "④b 这 6 拍里至少有一帧相机 offset 真的不是 0（不然屏上看不到任何晃动）")

	# ── ⑤ 像素级证据：**抖的是世界、HUD 不动** ──────────────────────────
	## 量法：先连拍**两帧都静止**的图算出噪声底（世界本来就在动：怪走、动画、视差），
	## 再把相机 offset 钉成已知的 (15,-9) 拍一帧。两条判据都建立在这个噪声底上：
	##   · HUD 带（底栏最下一条）：噪声必须是 0（这块本来就不动）⇒ 钉上 offset 后也必须 0 差异；
	##   · 世界带（屏幕中部 300×200）：钉上 offset 后必须**远大于**噪声 ⇒ 世界真的被挪走了。
	## ⚠ 以前这条用 `get_canvas_transform()` 的 origin 差当证据 —— 那是错的：相机的跟位
	##   每物理帧重算 `global_position`，取到的是上一帧画完的变换，跟我刚设的 offset 无关
	##   （实测报 Δ=(-7,7) 这种既不是 (15,-9) 也不是 0 的数）。像素才是证据。
	var 视口尺寸: Vector2 = root.get_viewport().get_visible_rect().size
	var 世界带 := Rect2i(300, 150, 300, 200)
	var HUD带 := Rect2i(2, int(视口尺寸.y) - 30, 260, 26)
	相机.offset = Vector2.ZERO
	await _帧(3)
	var 静止 := root.get_texture().get_image()
	await process_frame
	var 静止2 := root.get_texture().get_image()
	_判据(静止 != null and 静止2 != null and 静止.get_width() > 0,
			"拿得到视口图像（有头跑才有）：视口 %s" % str(视口尺寸))
	var 噪声世界 := _数不同(静止, 静止2, 世界带)
	var 噪声HUD := _数不同(静止, 静止2, HUD带)
	print("  [诊断] 噪声底（两帧静止之差）：世界带 %d 个、HUD 带 %d 个（带子 %s ／ %s）"
			% [噪声世界, 噪声HUD, str(世界带), str(HUD带)])
	_判据(噪声HUD == 0,
			"⑤a 噪声底：连拍两帧静止，HUD 那条 260×26 该一个像素都不变（否则这块不能当判据，"
			+ "要换一条不带动画的带子）；实变 %d 个" % 噪声HUD)
	相机.offset = Vector2(15.0, -9.0)
	await process_frame
	var 钉住帧 := root.get_texture().get_image()
## 带子普查：哪些矩形**本来就是静态的**（噪声=0）、钉上 offset 后仍不动（⇒ 真 HUD），
	## 哪些跟着动（⇒ 那是透过 HUD 边框露出来的世界，不能当判据）。
	var 候选: Dictionary = {
		"底栏最下8行": Rect2i(0, int(视口尺寸.y) - 8, 960, 8),
		"底栏左20行": Rect2i(0, int(视口尺寸.y) - 30, 200, 20),
		"底栏中16行": Rect2i(330, int(视口尺寸.y) - 26, 300, 16),
		"顶栏左上": Rect2i(0, 0, 120, 40),
		"顶栏中": Rect2i(300, 0, 300, 20),
	}
	for 名 in 候选:
		print("  [带子普查] %-12s 噪声=%-6d 钉offset后=%-6d %s"
			% [str(名), _数不同(静止, 静止2, 候选[名]), _数不同(静止, 钉住帧, 候选[名]), str(候选[名])])

	## ⑧ 平移一致性：把静止帧整体搬 (+15,-9) ／ (-15,+9) 之后，应当与钉住帧逐像素对得上
	## —— 这才叫"世界整块被挪走了那么多"，而不只是"有些像素变了"。
	var 带总 := 世界带.size.x * 世界带.size.y
	var 正搬 := _平移匹配(静止, 钉住帧, 世界带, Vector2i(15, -9))
	var 反搬 := _平移匹配(静止, 钉住帧, 世界带, Vector2i(-15, 9))
	print("  [平移] 带内 %d 个像素：按 (+15,-9) 搬对上 %d 个、按 (-15,+9) 搬对上 %d 个"
		% [带总, 正搬, 反搬])
	钉住帧.save_png(ProjectSettings.globalize_path(出目录 + "/世界_钉offset.png"))
	_判据(maxi(正搬, 反搬) * 100 >= 带总 * 70,
			"⑧a 世界是**整块平移**了钉进去的那个偏移：按对的那个方向搬之后，带内 ≥70% 像素逐点相等"
			+ "（对不上的那部分是视差层 —— 它按 `rx=-10` 只跟着相机走 1/10，再加怪物自己在走）；"
			+ "实得 最好 %d/%d = %d%%" % [maxi(正搬, 反搬), 带总, maxi(正搬, 反搬) * 100 / 带总])
	_判据(mini(正搬, 反搬) * 100 <= 带总 * 35,
			"⑧b 反方向必须对不上（反向对照：只判'画面变了'的话，把偏移抖反方向也照样绿）；"
			+ "实得 最差 %d/%d = %d%%" % [mini(正搬, 反搬), 带总, mini(正搬, 反搬) * 100 / 带总])
	_判据(_数不同(静止, 钉住帧, 世界带) > maxi(噪声世界 * 3, 200),
			"⑤b 世界带：钉上 offset 之后必须**大幅**变（世界被挪走了）；噪声底 %d ／ 实得 %d"
			% [噪声世界, _数不同(静止, 钉住帧, 世界带)])
	print("  [只报数] ⑤c 带 HUD 的半透底栏钉上 offset 后变了 %d 个 —— 那是**透出来的世界**在动，"
			% _数不同(静止, 钉住帧, HUD带))
	## ⚠ 这条不当判据：底栏那条皮半透（`世界相机.gd:6-9` 记着"顶部 16px 是半透明边框，
	## 透过它能看见世界"），相机一挪透出来的世界就在变 ⇒ 硬判据在 ⑦（先把世界藏掉再比 HUD）。
	_出差值图(静止, 钉住帧, 世界带, 出目录 + "/差值_世界.png")
	_出差值图(静止, 钉住帧, HUD带, 出目录 + "/差值_HUD.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	相机.offset = Vector2.ZERO
	if 静止 != null:
		静止.save_png(ProjectSettings.globalize_path(出目录 + "/静止.png"))
		# 真抖的那一帧：走真入口喊震 + 立刻喂一拍，让 offset 非 0 的那一帧被画出来
		玩.call("_震屏")
		相机.call("抖一拍", 0.05)
		await process_frame
		var 抖帧 := root.get_texture().get_image()
		if 抖帧 != null:
			抖帧.save_png(ProjectSettings.globalize_path(出目录 + "/抖动中.png"))
			var 差 := _数不同(静止, 抖帧, 世界带)
			_判据(差 > 0, "⑥ 真抖的那一帧，世界带必须跟静止帧不一样（屏上真的在晃）；实得 %d 个" % 差)
			print("  [只报数] ⑥b 真抖那一帧，半透底栏那条带子变了 %d 个（同上：透出来的世界）"
					% _数不同(静止, 抖帧, HUD带))
			_出差值图(静止, 抖帧, HUD带, 出目录 + "/差值_真抖HUD.png")
		相机.call("_震复位")
		await _帧(8)
		var 复位 := root.get_texture().get_image()
		if 复位 != null:
			复位.save_png(ProjectSettings.globalize_path(出目录 + "/复位.png"))
			_判据(_数不同(复位, 静止, HUD带) == 0,
					"⑥c 抖完复位：HUD 带回到静止帧那份样子（复位没把界面留在歪处）；实变 %d 个"
					% _数不同(复位, 静止, HUD带))


	# ── ⑦ 把世界整个藏掉，再判 HUD：**HUD 一个像素都不许动** ────────────────
	## 为什么 ⑤c/⑥b 那种"HUD 带逐像素相同"不能当硬判据：底栏那条皮是**半透**的，
	## 透过它能看见世界（`世界相机.gd:6-9` 那句注释就是这事）⇒ 相机一挪，透出来的世界就在变，
	## 这不是 HUD 在晃。原版也一样（Flash 只裁 `map.scrollRect`，HUD 那层照样透出底下在动的地图）。
	## ⇒ 正确的量法：**先把画在 0 号画布（会跟着相机走）的东西全藏掉**，剩下的就只有 HUD 各层
	## （实测层号：头像/小地图 20、技能面板 100、功能窗口/窗口管理 110 —— 都 ≥1，不吃相机变换），
	## 这时候再钉 offset，HUD 必须逐像素全等。
	var 藏掉 := _藏世界(场景)
	await _帧(4)
	var HUD静 := root.get_texture().get_image()
	相机.offset = Vector2(15.0, -9.0)
	await process_frame
	var HUD钉 := root.get_texture().get_image()
	相机.offset = Vector2.ZERO
	await process_frame
	var HUD归零 := root.get_texture().get_image()
	var HUD带普查: Array[String] = []
	var 最坏 := 0
	for 带 in [Rect2i(0, 0, 140, 130), Rect2i(0, int(视口尺寸.y) - 101, int(视口尺寸.x), 101),
			Rect2i(int(视口尺寸.x) - 150, 0, 150, 120), Rect2i(300, 0, 300, 24)]:
		var d := _数不同(HUD静, HUD钉, 带)
		HUD带普查.append("%s→%d" % [str(带.size), d])
		最坏 = maxi(最坏, d)
	_判据(最坏 == 0,
			("⑦ 世界藏掉后钉住 offset：HUD 四块（头像面板/整条底栏/小地图区/顶部条）必须逐像素全等"
			+ "（= 抖的是世界、HUD 一层都不跟着晃，对齐 `Camera.as:194-215` 只改 scrollRect）；"
			+ "实得 %s ｜ 藏了 %d 个 0 号画布的绘制件") % [str(HUD带普查), 藏掉.size()])
	_判据(_数不同(HUD静, HUD归零, Rect2i(0, int(视口尺寸.y) - 101, int(视口尺寸.x), 101)) == 0,
			"⑦b 钉完归零 ⇒ 底栏整条回到静止那份（判据里没有'回不去'的残留）")
	if HUD静 != null and HUD钉 != null:
		# 差值图（品红=不同）：这条应该是**整幅干净**的，肉眼复核用
		_出差值图(HUD静, HUD钉, Rect2i(0, 0, int(视口尺寸.x), int(视口尺寸.y)),
				出目录 + "/差值_HUD整屏_世界已藏.png")
		HUD静.save_png(ProjectSettings.globalize_path(出目录 + "/HUD_世界已藏_静止.png"))
		HUD钉.save_png(ProjectSettings.globalize_path(出目录 + "/HUD_世界已藏_钉offset.png"))
	_还原世界(藏掉)
	await _帧(4)
	_收尾(存档, 原样, 设置原样)



## 两块图在同一块矩形里逐像素比，数出不同的像素个数（图不一样大就按交集算，免得越界）。
func _数不同(A: Image, B: Image, 带: Rect2i) -> int:
	if A == null or B == null:
		return -1
	var 不同 := 0
	var 右 := mini(带.position.x + 带.size.x, mini(A.get_width(), B.get_width()))
	var 下 := mini(带.position.y + 带.size.y, mini(A.get_height(), B.get_height()))
	for y in range(maxi(带.position.y, 0), 下):
		for x in range(maxi(带.position.x, 0), 右):
			if A.get_pixelv(Vector2(x, y)) != B.get_pixelv(Vector2(x, y)):
				不同 += 1
	return 不同


## 把"变了哪些像素"画成品红，底下铺一层压暗的参照 —— 判据之外还得自己看过图。
func _出差值图(A: Image, B: Image, 带: Rect2i, 路径: String) -> void:
	if A == null or B == null:
		return
	var 图 := B.duplicate()
	for y in range(带.position.y, 带.position.y + 带.size.y):
		for x in range(带.position.x, 带.position.x + 带.size.x):
			if x >= 图.get_width() or y >= 图.get_height():
				continue
			if A.get_pixelv(Vector2(x, y)) != B.get_pixelv(Vector2(x, y)):
				图.set_pixelv(Vector2(x, y), Color(1.0, 0.0, 1.0))
	图.save_png(ProjectSettings.globalize_path(路径))

## 把画在 **0 号画布**（会跟着相机走）的绘制件全藏掉，返回藏了哪些（好还原）。
## 相机自己跳过：`Camera2D` 也是 CanvasItem，把它藏了就等于没相机。
## 把世界整个藏掉：地图场景的**直接子节点**里，凡是自己就是绘制件（`CanvasItem`）的都关掉，
## 子树跟着一起没；`CanvasLayer`（HUD 各面板：头像/小地图 20、技能 100、功能窗口/窗口管理 110）跳过、
## `Camera2D` 跳过（它也是 CanvasItem，藏掉就没相机了）。
## ⚠ 不用 `get_canvas_layer()` 判归属：本机这版 Godot 在 Node2D 上**没有这个方法**
## （实测报 `Nonexistent function 'get_canvas_layer' in base 'Node2D (地图块.gd)'`，2026-10-11）。
func _藏世界(场景: Node) -> Array:
	var 藏: Array = []
	for 子 in 场景.get_children():
		if 子 is CanvasLayer or 子 is Camera2D:
			continue
		if 子 is CanvasItem and (子 as CanvasItem).visible:
			(子 as CanvasItem).visible = false
			藏.append(子)
	return 藏

## B 的第 (x,y) 个像素 = A 的第 (x-量.x, y-量.y) 个像素 ⇒ 数出"整块搬了 量 这么多"对得上的像素数。
func _平移匹配(A: Image, B: Image, 带: Rect2i, 量: Vector2i) -> int:
	if A == null or B == null:
		return -1
	var 同 := 0
	for y in range(带.position.y, 带.position.y + 带.size.y):
		for x in range(带.position.x, 带.position.x + 带.size.x):
			var sx := x - 量.x
			var sy := y - 量.y
			if sx < 0 or sy < 0 or sx >= A.get_width() or sy >= A.get_height():
				continue
			if A.get_pixelv(Vector2(sx, sy)) == B.get_pixelv(Vector2(x, y)):
				同 += 1
	return 同

func _还原世界(藏: Array) -> void:
	for 节 in 藏:
		if is_instance_valid(节):
			(节 as CanvasItem).visible = true

func _收尾(存档: String, 原样: PackedByteArray, 设置原样: Dictionary) -> void:
	# 还原会话设置 + 存档，免得下一次跑（或用户自己开客户端）读到门留下的脏值
	var 会 := root.get_node_or_null("GameSession")
	if 会 != null:
		会.game_settings = 设置原样
	if 原样.size() > 0:
		var 文 := FileAccess.open(存档, FileAccess.WRITE)
		if 文 != null:
			文.store_buffer(原样)
	_判据(_读(存档) == 原样 or 原样.size() == 0,
			"存档字节回到开跑前（量具不许给用户留脏档）")
	print("震屏量具：判 %d 条 / 红 %d 条" % [_判, _红])
	quit(1 if _红 > 0 else 0)

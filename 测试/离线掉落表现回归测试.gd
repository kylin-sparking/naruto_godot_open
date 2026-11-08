## 本地（离线）打怪掉的战利品，表现要和服务端掉落**同一条**。
##
## 原版掉落物是 `DropItemSprite`：**图标本体**（金币走 `PicTool.getMesoPic(数量)` 那四档钱堆）
## \+ **常显名字** + 两段动画。
##
## ⚠️ 我们离线那条原来是一个写着「拾取 +5 金币」的 **`Button`** —— 纯自造
## （§3.61.4 待办第 6 条）。这条门就是钉"它不再是个文字按钮"：
## 节点下必须有 `DropIcon` / `DropName`，**且不能有带文字的子 `Button`**。
extends SceneTree
const 快捷键表 := preload("res://脚本/单例/快捷键.gd")
## `--script` 模式下自动加载的单例还没挂上来 ⇒ 全局名 `GAME_DATA` 编译不过，
## 和 `掉落物名字颜色回归测试` 一样直接 preload 那个脚本类用它的静态函数。
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _run() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _frame in 12:
		await process_frame
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	if 生怪根 == null:
		_check(false, "没有 LifeRoot")
		_finish()
		return

	var 容器 := 生怪根.get_parent()
	var 前 := 容器.get_child_count()
	生怪根.call("_create_loot", Vector2(123.0, 456.0))
	var 掉: Node2D = null
	for 子 in 容器.get_children():
		if 子.get_node_or_null("DropIcon") != null and 子.get_node_or_null("DropName") != null:
			掉 = 子 as Node2D
			break
	_check(掉 != null, "本地掉落应建出带 DropIcon/DropName 的掉落物节点（服务端那条同一套）")
	_check(容器.get_child_count() > 前, "创建后容器子节点数应增加")
	if 掉 == null:
		_finish()
		return

	# ① 图标：金币是 `TextureRect`，不是按钮上的文字
	var 图标 := 掉.get_node_or_null("DropIcon") as TextureRect
	_check(图标 != null and 图标.texture != null, "掉落物应有金币图标贴图")
	# ② 名字：`<数量>金币`，常显（落地后可见）
	var 名 := 掉.get_node_or_null("DropName") as Label
	_check(名 != null, "掉落物应有名字标签")
	if 名 != null:
		_check(名.text == "%d金币" % 生怪根.get("离线掉落金币"),
				"名字应是 `<数量>金币`（实际 %s）" % 名.text)
		_check(名.get_theme_color("font_color").is_equal_approx(Color.WHITE), "金币名字应是白的")
	# ③ **不能**再有那个自造的文字按钮
	var 有文字按钮 := false
	for 子 in 掉.get_children():
		var 按 := 子 as Button
		if 按 != null and not 按.text.strip_edges().is_empty():
			有文字按钮 = true
	_check(not 有文字按钮, "掉落物下不该再有带文字的自造按钮（原版是图标本体）")

	# ④ 登记进了掉落表（动画/移除都靠它），键是负数、不撞服务端的 object_id
	## ⚠ 默认值不能写 -1：离线掉落物的编号就是 -1 往下走的，"没找到"和"找到第一枚"
	##   会撞成同一个值 ⇒ 后面所有断言都变成空判（探针自我污染）。用 0（服务端 oid 是正数、
	##   离线是负数 ⇒ 0 一定不是编号）。
	var 键 := 0
	for k in (生怪根.get("_server_drops") as Dictionary).keys():
		if (生怪根.get("_server_drops") as Dictionary)[k] == 掉:
			键 = int(k)
	_check(键 != 0, "掉落表里该能找到这枚离线掉落物（实得编号 %d）" % 键)
	_check(键 < 0, "本地掉落应登记在负数编号下（实际 %d）—— 服务端的 object_id 是正数，不能撞" % 键)

	# ⑤ ── 用户 10-12 报的三条：金币有时整块变纯白 / 大小不对 / 躺在地上不动 ──────
	## ⓐ 金币那四帧**必须同尺寸**。`AnimatedTexture` 是把各帧叠成一张 texture array 的，
	##   尺寸不齐 ⇒ 它报出来的宽高是错的（实测 90000000 报 23×24、真实最大 25×24），
	##   采样越界在部分机器上就是"整块变纯白"。四档里只有 90000003 本来同为 32×31
	##   —— 与"金币**有时**变纯白"对得上。
	var 动 := 图标.texture as AnimatedTexture
	_check(动 != null and 动.frames == 4, "金币钱堆该是 4 帧 AnimatedTexture（实得 %s）"
			% ("null" if 动 == null else str(动.frames)))
	if 动 != null:
		var 首宽 := 动.get_frame_texture(0).get_width()
		var 首高 := 动.get_frame_texture(0).get_height()
		var 齐 := true
		for i in range(动.frames):
			var 帧 := 动.get_frame_texture(i)
			if 帧.get_width() != 首宽 or 帧.get_height() != 首高:
				齐 = false
		_check(齐, "钱堆四帧必须同一尺寸（首帧 %d×%d），否则 AnimatedTexture 采样越界 ⇒ 图标变白"
				% [首宽, 首高])
		_check(absf(图标.size.x - 首宽) < 0.01 and absf(图标.size.y - 首高) < 0.01,
				"图标盒应等于贴图的天然尺寸、不许缩放（盒 %s 贴图 %d×%d）" % [str(图标.size), 首宽, 首高])
	## ⓑ 摆位：金币是"站在地上"的 ⇒ **盒底边 = 锚点 + 15 = 地面线**、水平居中于锚点。
	##   真值 `DropItemSprite.render():304-310`（`content.x=-15, content.y=15`，锚点 = 落点 y−15）
	_check(absf(图标.position.x + 图标.size.x / 2.0) < 0.01,
			"金币盒应水平居中于锚点（实得盒左上 %s 盒 %s）" % [str(图标.position), str(图标.size)])
	_check(absf(图标.position.y - (15.0 - 图标.size.y)) < 0.01,
			"金币盒底边应正好压在地面线（锚点+15）上（实得盒左上 y=%s 盒高=%s）"
			% [str(图标.position.y), str(图标.size.y)])
	## ⓒ 名字：原版 `RoleNamePane` 是 `autoSize = CENTER` ⇒ 给的 y 是**文本盒中心**（金币 30）
	_check(absf(名.position.y - (30.0 - 名.size.y / 2.0)) < 0.01,
			"金币名字的中心该在锚点下方 30 像素（实得 position=%s size=%s）" % [str(名.position), str(名.size)])
	## ⓓ 档位与缓存：同一档复用同一张（四档 = 4 个对象），跨档必须是不同的
	var 五十 = GAME_DATA.金币图标(50)
	var 六十 = GAME_DATA.金币图标(60)
	var 二百 = GAME_DATA.金币图标(200)
	var 七百 = GAME_DATA.金币图标(700)
	var 一千五 = GAME_DATA.金币图标(1500)
	_check(五十 == 六十, "50 与 60 同档（<100 → 90000000）⇒ 应复用同一张贴图")
	_check(五十 != 二百 and 二百 != 七百 and 七百 != 一千五,
			"<100 / <500 / <1000 / ≥1000 四档该是四张不同的钱堆（`PicTool.as:383-403`）")
	## ⓔ 浮动：先跑完 800ms 出场抛物线，再连推 120 帧（≈ 2 秒 > 一圈 1885ms）
	for _i in 70:
		生怪根.call("_推进掉落动画", 1.0 / 60.0)
	_check(not bool(掉.get_meta("drop_air", false)), "推满 70 帧（≈1.17 秒）后该落地了")
	_check(名.visible, "落地后名字要显出来（原版 `tick():470-473`）")
	var 落点: Vector2 = 掉.get_meta("drop_to")
	var 档集 := {}
	for _i in 120:
		生怪根.call("_推进掉落动画", 1.0 / 60.0)
		档集[掉.position.y] = true
	var 值: Array = 档集.keys()
	值.sort()
	_check(值.size() >= 3,
			"躺在地上要上下浮动（原版 `floor(3*sin(t/300))`）⇒ 2 秒里 y 至少该有 3 个值，实得 %d 个 %s"
			% [值.size(), str(值)])
	var 在带内 := true
	for v in 值:
		if v < 落点.y - 15.0 - 3.0 - 0.01 or v > 落点.y - 15.0 + 2.0 + 0.01:
			在带内 = false
	_check(在带内, "浮动的取值必须落在 落点y−15 ±3 这条带里（实得 %s）" % str(值))
	_check(float(掉.get_meta("drop_phase", -1.0)) >= 0.0 and float(掉.get_meta("drop_phase", -1.0)) < 600.0,
			"落地相位 `drop_phase` 该在 [0,600)（原版 `MathAD.rnd(0,600)`）⇒ 满地掉落物才不齐动；实得 %s"
			% str(掉.get_meta("drop_phase", "没存上")))

	# ⑥ 拾取：**点远处的掉落物不该立刻捡、更不该立刻播动画**。
	# 原版 `DropItemHandler.gotoPickUpItem():131-164`：距离 ≥50 ⇒ 先 `pathFind` 走过去，
	# `tickItemGotoPickUp():451-467` 每帧看到 <50 才 `pickDropItem`。
	生怪根.call("_点掉落物", 键)
	_check(int(生怪根.get("_要去捡")) == 键,
			"点远处的掉落物应先记成「要去捡」（实得 %s）" % str(生怪根.get("_要去捡")))
	_check(not bool(掉.get_meta("drop_picking", false)),
			"人还没走到跟前就起拾取动画 ⇒ 错（原来就是这个 bug：隔着半张地图把东西拽过来）")
	# 走到跟前 ⇒ `_推进去捡` 该发拾取；离线这条没有服务端回帧，就地按"回帧说要播动画"处理
	var 捡 = 生怪根.call("_掉落拾取者")
	## ⚠ 必须写 `global_position`：掉落物挂在会随相机滚动偏移的世界里层，
	##   把**局部** position 设成玩家的全局坐标并不等于"贴到玩家脚下"。
	if 捡 is Node2D:
		掉.global_position = (捡 as Node2D).global_position
		生怪根.call("_推进去捡", 16.0)
	_check(bool(掉.get_meta("drop_picking", false)), "走到跟前之后离线掉落应起拾取动画")
	_check(int(生怪根.get("_要去捡")) == -999999999,
			"发过拾取之后「要去捡」该回到哨兵「无拾取目标」（实得 %s）" % str(生怪根.get("_要去捡")))
	_check(bool(掉.get_meta("drop_offline", false)), "掉落物应带 drop_offline 标记（拾取时据此不发协议）")

	# ⑥ ⭐ 拾取动画要**真的朝拾取者挪 x**。
	# 原实现里这一行写的是 `拾取者.x`（`Node2D` 上没有 `x`）⇒ 每帧报错、x 永远不挪。
	# 只断言 `drop_picking` 是抓不到它的 —— 必须看**位置有没有动**。
	var 玩家 := 场景.get_node_or_null("Player") as Node2D
	if 玩家 == null:
		_check(false, "没有 Player，拾取追人这条没验到")
	else:
		var 玩家x := 玩家.global_position.x
		# 把拾取物摆到离玩家有点距离的地方，不然"没挪"和"已经到了"分不出来
		掉.position.x = 玩家x - 200.0
		var 前x := 掉.position.x
		for _i in 10:
			生怪根.call("_推进掉落动画", 1.0 / 60.0)
		var 后x := 掉.position.x
		_check(后x > 前x, "拾取动画期间掉落物应朝玩家（+x）挪（前 %.1f → 后 %.1f）" % [前x, 后x])
		_check(absf(后x - 玩家x) < absf(前x - 玩家x), "拾取动画应缩短与玩家的水平距离")
	# ⑧ ── 按住 Z 挑"能捡的里面最近的一枚"（原版 `getOnePickableDropItem():99-124`
	#   + `canItemPickup():478-486`）。无头里按不出键 ⇒ 判的是**挑哪一枚**这套判定；
	#   "每 100ms 调一次它"那两行由 ⑨ 的键位断言 + 有头量具兜。
	_检查可捡与挑最近(生怪根)
	# ⑨ 拾取键本身：原版 `KEYBOARD_SHORTCUT_KEY_PICK` 默认 `KEY_ID_44` = **Z**
	_check(快捷键表.默认.has("pick_up"), "默认键位表里该有「拾取」这一档（原版 Z 键）")
	if 快捷键表.默认.has("pick_up"):
		_check((快捷键表.默认["pick_up"] as Array).has(KEY_Z),
				"拾取默认键该是 Z（原版 KEY_ID_44）；实得 %s" % str(快捷键表.默认["pick_up"]))
	_finish()


## ⑧ 的正文：**另造两枚干净的离线掉落**当主角 —— 前面 ⑥⑦ 已经把第一枚推进到
## "拾取动画跑完 ⇒ 从掉落表里移除"了，拿它当判据主角测的是上一段的尾巴
## （10-12 第一版就红在这里：断言全 false，看着像判定写错）。
func _检查可捡与挑最近(生怪根: Node) -> void:
	var 玩家: Node2D = get_first_node_in_group("player") as Node2D
	if 玩家 == null:
		_check(false, "没有 Player，可捡判定与挑最近都没验到")
		return
	生怪根.set("_锁定表", {})
	生怪根.set("_要去捡", int(生怪根.get("无拾取目标")))
	# 两枚：一枚贴脚边、一枚在右边 400 像素外
	生怪根.call("_create_loot", Vector2(玩家.global_position.x + 400.0, 玩家.global_position.y))
	生怪根.call("_create_loot", Vector2(玩家.global_position.x + 20.0, 玩家.global_position.y))
	var 表: Dictionary = 生怪根.get("_server_drops")
	## 先推过 800ms 让两枚落地，**再**扫表 —— 前几段那枚正在播拾取动画的旧掉落
	## 会在这一百多毫秒里被收掉，先扫后推就会拿到一个已经不在表里的键（10-12 第一版
	## 报 `Out of bounds get index '-1' (on base: 'Dictionary')` 就是这么来的）。
	for _i in 70:
		生怪根.call("_推进掉落动画", 1.0 / 60.0)
	var 键表: Array = []
	for k in 表.keys():
		if is_instance_valid(表[k]) and not bool((表[k] as Node).get_meta("drop_picking", false)):
			键表.append(int(k))
	_check(键表.size() >= 2, "⑧ 该有两枚干净的离线掉落（实得 %s）" % str(键表))
	if 键表.size() < 2:
		return
	# 近的、远的：按 x 排
	var 近键: int = int(键表[0])
	var 远键: int = int(键表[1])
	if (表[近键] as Node2D).global_position.x > (表[远键] as Node2D).global_position.x:
		var 换: int = 近键
		近键 = 远键
		远键 = 换
	var 近: Node2D = 表[近键]
	_check(bool(生怪根.call("_可捡", 近, 近键, 0)), "落地、没锁、无主的掉落物该算「可捡」")
	近.set_meta("drop_air", true)
	_check(not bool(生怪根.call("_可捡", 近, 近键, 0)), "还在空中飞的不算可捡（原版 canPickUp）")
	近.set_meta("drop_air", false)
	近.set_meta("drop_removed", true)
	_check(not bool(生怪根.call("_可捡", 近, 近键, 0)), "已经叫收掉的不算可捡")
	近.set_meta("drop_removed", false)
	近.set_meta("drop_owner", 888888)
	_check(not bool(生怪根.call("_可捡", 近, 近键, 0)), "别人掉的（归属不是自己）不算可捡")
	_check(bool(生怪根.call("_可捡", 近, 近键, 888888)), "自己掉的就算可捡")
	近.set_meta("drop_owner", 0)
	生怪根.set("_锁定表", {近键: 5000.0})
	_check(not bool(生怪根.call("_可捡", 近, 近键, 0)), "被 5 秒锁定挡住的不算可捡（原版 _hasPickUpDic）")
	生怪根.set("_锁定表", {})
	_check(int(生怪根.call("_最近可捡掉落物")) == 近键,
			"两枚都能捡时该挑离玩家近的那枚（实得 %s，期望 %s）"
			% [str(生怪根.call("_最近可捡掉落物")), str(近键)])
	# 把近的那枚标成"正在拾取" ⇒ 该改挑远的那枚
	近.set_meta("drop_picking", true)
	_check(int(生怪根.call("_最近可捡掉落物")) == 远键,
			"正在被捡的那枚该跳过（实得 %s，期望 %s）" % [str(生怪根.call("_最近可捡掉落物")), str(远键)])
	近.set_meta("drop_picking", false)
	# 同队归属（原版 `canItemPickup():480` 的 `isInTroop` 那一支）
	近.set_meta("drop_owner", 888888)
	_check(not bool(生怪根.call("_可捡", 近, 近键, 0, [])), "队友表为空时别人掉的仍不算可捡")
	_check(bool(生怪根.call("_可捡", 近, 近键, 0, [888888])), "同队成员掉的该算可捡")
	近.set_meta("drop_owner", 0)
	_检查身体捡(生怪根, 近, 玩家)


## `touch_up=true` 那一档：无名、无钮、Z 键挑不到，但**身体碰到就自动捡**。
func _检查身体捡(生怪根: Node, 参照: Node2D, 玩家: Node2D) -> void:
	var 状态 := {
		"object_id": -5001, "is_meso": true, "item_id": 35, "item_name": "",
		"owner_id": 0, "touch_up": true,
		"x": 参照.global_position.x + 900.0, "y": 参照.global_position.y,
		"from_x": 参照.global_position.x + 900.0, "from_y": 参照.global_position.y,
		"drop_mode": 0,
	}
	var 掉: Node2D = 生怪根.call("_create_drop_node", 状态, -5001, true)
	生怪根.get_parent().add_child(掉)
	var 表: Dictionary = 生怪根.get("_server_drops")
	表[-5001] = 掉
	for _i in 70:
		生怪根.call("_推进掉落动画", 1.0 / 60.0)
	_check(bool(掉.get_meta("drop_touch_up", false)), "touch_up 该记在节点上")
	_check(掉.get_node_or_null("DropName") == null,
			"touch_up 的掉落物原版**不建名字标签**（render():311/355 那句 if(!touchUp)）")
	_检查身体钮(掉)
	# Z 键/鼠标那条不该挑它
	var 挑: int = int(生怪根.call("_最近可捡掉落物"))
	_check(挑 != -5001, "touch_up 的不该被 Z 键挑走（原版 getOnePickableDropItem:109）；实得 %d" % 挑)
	# 身体碰到判定：盒 = 身体(-27,-120,54,120) 与 掉落物(-17,-34,34,34) 平移到同一原点比
	玩家.velocity = Vector2.ZERO
	玩家.global_position = 掉.global_position
	_check(bool(生怪根.call("_身体碰到掉落物", 玩家, 掉)), "站在掉落物上就该碰到")
	玩家.global_position = 掉.global_position + Vector2(0.0, 100.0)
	_check(bool(生怪根.call("_身体碰到掉落物", 玩家, 掉)), "掉落物在人头顶 100 像素内（身体盒高 120）算碰到")
	玩家.global_position = 掉.global_position + Vector2(0.0, -60.0)
	_check(not bool(生怪根.call("_身体碰到掉落物", 玩家, 掉)), "人比掉落物还高 60 像素 ⇒ 没碰到")
	玩家.global_position = 掉.global_position + Vector2(60.0, 0.0)
	_check(not bool(生怪根.call("_身体碰到掉落物", 玩家, 掉)), "横向差 60 像素（27+17=44 之外）⇒ 没碰到")
	玩家.global_position = 掉.global_position + Vector2(300.0, 0.0)
	_check(not bool(生怪根.call("_身体碰到掉落物", 玩家, 掉)), "超出 ±200 粗筛 ⇒ 没碰到")
	# 走回去 ⇒ 该自动发拾取（且**不吃 200ms 全局节流**）
	生怪根.set("_拾取闸", 999.0)
	玩家.global_position = 掉.global_position
	生怪根.call("_推进身体捡", 16.0)
	_check(bool(掉.get_meta("drop_picking", false)), "身体碰到就该自动捡，且不吃 200ms 节流")
	掉.queue_free()
	表.erase(-5001)


func _检查身体钮(掉: Node2D) -> void:
	var 有钮 := false
	for 子 in 掉.get_children():
		if 子 is Button:
			有钮 = true
	_check(not 有钮, "touch_up 的掉落物不该有点击钮（原版 ctor:142-151 不挂鼠标监听）")


func _finish() -> void:
	if _failures.is_empty():
		print("离线掉落表现回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)

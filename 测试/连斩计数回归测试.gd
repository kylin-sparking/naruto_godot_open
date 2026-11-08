extends SceneTree

## 「连斩计数」门（#198）。量的是主界面左上角那枚 `LianZhanMC` 移植件 + 1291 两条子命令的解码。
## 原版出处全部钉在 `脚本/界面/连斩面板.gd` 文件头（一处一行号），这里只写"该看到什么"。
## ⚠ 不许写存档：这条门只 `new()` 面板、只喂文本桥串，不点任何原生按钮、不碰 `user://`。

const 面板路 := "res://脚本/界面/连斩面板.gd"
const 标题皮 := "res://素材/界面/通用界面/连斩标题.png"
const 数字目录 := "res://素材/特效/Effect_colorNumber/NoRed0/"
const 条宽 := 165.0
## 现查 `数据/原版杂项.json` 的 `Etc.Lianzhan.interval`（`LianZhanMC.as:88-91` 拿它当窗口长度）
const 窗口档 := [15000, 12000, 9000, 6000, 3000, 2000, 1000, 750, 500]

var _失败: Array[String] = []
var 判数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _查(ok: bool, 话: String) -> void:
	判数 += 1
	if not ok:
		_失败.append(话)


func _停(话: String) -> void:
	判数 += 1
	_失败.append(话)
	print("汇：判 %d 条 / 红 %d 条（连斩计数回归测试：%s）" % [判数, _失败.size(), "失败"])
	quit(1)


func _帧(次: int) -> void:
	for i in range(次):
		await process_frame


func _run() -> void:
	var 脚本 = load(面板路)
	if 脚本 == null:
		_停("面板脚本 load 不到：%s" % 面板路)
		return
	var 面板 = 脚本.new()
	root.add_child(面板)
	await _帧(4)
	if not is_instance_valid(面板):
		_停("面板建出来就被释放了")
		return

	# ── ① 摆位与"默认隐藏"（`UIMain2.as:5345-5349`）──
	_查(面板.position == Vector2(200.0, 36.0),
			"连斩块该摆在主界面 x=200 y=36（原版那四句 `setVisible(false)/x/y/setParent`）；实得 %s"
			% str(面板.position))
	_查(面板.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"原版 `mouseChildren=false; mouseEnabled=false` ⇒ 整块不吃鼠标；实得 %s" % str(面板.mouse_filter))
	_查(bool(面板.get("在显示")) == false and not 面板.visible,
			"刚建好该是隐藏的（没连斩就没有这块 UI）；实得 visible=%s" % str(面板.visible))

	# ── ② 数 0 ⇒ 收起（`Client.as:5594-5604` 那两个分支）──
	面板.call("设连斩数", 0)
	_查(not 面板.visible, "收到 0 该把整块收起来（原版走 setVisible(false)，不是显示一个 0）")

	# ── ③ 设数 ⇒ 显形 + 窗口档按 `斩数/100` 现查数据（`LianZhanMC.as:88-91`）──
	for 样本 in [[150, 1], [3, 0], [899, 8], [250, 2]]:
		面板.call("设连斩数", int(样本[0]))
		var 应档 := float(窗口档[int(样本[1])])
		_查(面板.visible and float(面板.get("窗口毫秒")) == 应档,
				"斩数 %d 的窗口该是 interval[%d] = %d 毫秒（斩数越大窗口越短）；实得 %s 毫秒、visible=%s"
				% [int(样本[0]), int(样本[1]), 窗口档[int(样本[1])], str(面板.get("窗口毫秒")), str(面板.visible)])
		_查(float(面板.get("攒下的毫秒")) == 0.0,
				"设数要把攒的时间清零（原版 `setCount` 里 `this.pastTime = 0`）；实得 %s" % str(面板.get("攒下的毫秒")))

	# ── ④ 数字：位数 = 十进制位数、每个字一张真图、整串居中 ──
	面板.call("设连斩数", 328)
	var 块数 := int((面板.get("数字块") as Array).size())
	_查(块数 == 3, "328 该排 3 个数字块；实得 %d" % 块数)
	var 第一块 = (面板.get("数字块") as Array)[0]
	_查(第一块 != null and (第一块 as TextureRect).texture != null,
			"数字块要有真纹理（原版 NoRed0 那 11 帧）")
	var 图 = (第一块 as TextureRect).texture as AtlasTexture
	_查(图 != null and 图.region.size.x > 0.0 and 图.region.size.y > 0.0,
			"每个字按**墨迹包围盒**裁（Flash 的 `getRect` 量的就是墨迹，不是 98×38 的画布）；实得 %s"
			% str(null if 图 == null else 图.region))
	var 宿主: Control = 面板.get("数字区") as Control
	_查(宿主 != null and absf(宿主.position.x - 10.0) < 0.01,
			"数字那串的 x 该是 10（`LianZhanMC.as:102` `this.cn.x = 10`）；实得 %s"
			% str(null if 宿主 == null else 宿主.position))
	_查(宿主 != null and 宿主.position.y > 20.0,
			"y = 数字高 + 20（`LianZhanMC.as:101`）；实得 %s" % str(null if 宿主 == null else 宿主.position.y))
	_查(宿主 != null and 宿主.scale == Vector2(2.0, 2.0),
			"刚设数时该放大 2 倍、再由 0.5 秒补间回原尺寸（`LianZhanMC.as:103-108`）；实得 %s"
			% str(null if 宿主 == null else 宿主.scale))
	await create_timer(0.8).timeout
	_查(宿主 != null and is_instance_valid(宿主) and 宿主.scale.distance_to(Vector2(1.0, 1.0)) < 0.2,
			"0.75 秒后补间该把它收回原尺寸附近；实得 %s" % str(null if 宿主 == null else 宿主.scale))
	var 左: float = (面板.get("数字块") as Array).map(func(x): return (x as Control).position.x)[0]
	var 右端 := 0.0
	for 个 in (面板.get("数字块") as Array):
		右端 = maxf(右端, (个 as Control).position.x + (个 as Control).size.x)
	_查(absf((左 + 右端) * 0.5) < 0.5 and 右端 - 左 > 1.0,
			"整串要以数字原点那条线**居中**（`ColorNumber.as:99` `container.x = -宽/2`）⇒ 串的中点该落在 0、"
			+ "宽度要大于 1px；实得 首=%s 尾=%s 中点=%s" % [str(左), str(右端), str((左 + 右端) * 0.5)])

	# ── ⑤ 帧号映射（`ColorNumber.as:42` 的 dicts，帧号 = 数字 + 1；第 11 帧是 miss）──
	for 对 in [["0", 1], ["1", 2], ["9", 10]]:
		var 字: String = str(对[0])
		var 望: int = int(对[1])
		_查(int(面板.call("_帧号", 字)) == 望,
				"字「%s」该取第 %d 帧（dicts=[null,0..9,miss]）；实得 %d" % [字, 望, int(面板.call("_帧号", 字))])
	_查(int(面板.call("_帧号", "miss")) == 11, "非数字（count==0 那一档）该取第 11 帧「miss」")

	# ── ⑥ 进度机制与倒计时（用户 10-12 实机口径：两层都是全尺寸静止图，只擦黑色那张）──
	## 判三件事：① 红层**永远在 (0,0)、永远不缩放**；② 黑层在**屏幕上的位置一像素都不动**；
	## ③ 随倒计时变的只有"擦除窗口"（左边被裁掉多少）。
	## 前两条就是被打回两次的地方：第一版让黑整块平移、第二版让红整块平移，两次门都是绿的
	## —— 因为门只钉了"某个 x 等于某个算式"，没钉"这张图在屏幕上一动不动"。
	面板.call("设连斩数", 20)
	var 红: Control = 面板.get("红条")
	var 黑: Control = 面板.get("黑底")
	var 窗: Control = 面板.get("黑裁")
	var 面左: float = float(面板.get_global_position().x)
	_查(absf(窗.size.x - 条宽) < 0.01,
			"刚显示时比例 1 ⇒ 擦除量 0、黑整块都在 ⇒ 窗口宽该是 165；实得 %s" % str(窗.size.x))
	_查(红.position == Vector2.ZERO, "红血溅是最底层静止图 ⇒ position 恒 (0,0)；实得 %s" % str(红.position))
	_查(absf(黑.get_global_position().x - 面左) < 0.01,
			"黑图在屏幕上的左缘该与面板左缘重合；实得 %s vs %s" % [str(黑.get_global_position().x), str(面左)])
	面板.call("放进度", 0.5)
	_查(absf(窗.size.x - 条宽 * 0.5) < 0.01 and (窗.position == Vector2.ZERO),
			"比例 0.5 ⇒ 擦除窗口该**钉在左端不动、只把宽度从 165 收到 82.5**（右边先露红）；实得 x=%s 宽=%s"
			% [str(窗.position.x), str(窗.size.x)])
	_查(absf(黑.get_global_position().x - 面左) < 0.01,
			"**用户打回点**：比例掉一半时黑图仍不许在屏幕上动（只是被裁）；实得左缘 %s（面板 %s）"
			% [str(黑.get_global_position().x), str(面左)])
	_查(红.position == Vector2.ZERO and 红.scale == Vector2.ONE,
			"红色不许移动也不许缩放 ⇒ position 恒 (0,0)、scale 恒 (1,1)；实得 %s / %s" % [str(红.position), str(红.scale)])
	面板.call("设连斩数", 20)
	面板.call("投喂", 6000.0)
	_查(面板.visible and absf(float(面板.get("攒下的毫秒")) - 6000.0) < 0.01,
			"每帧喂毫秒是**累加**的（原版 `this.pastTime += param1`）；喂 6000 后该攒 6000；实得 %s"
			% str(面板.get("攒下的毫秒")))
	var 六 := float((面板.get("黑裁") as Control).size.x)
	_查(absf(六 - 条宽 * 0.6) < 0.02,
			"窗口 15000、攒 6000 ⇒ 比例 0.6 ⇒ 可见黑宽该是 165×0.6=99（右边已擦掉 66）；实得 %s" % str(六))
	面板.call("投喂", 9001.0)
	_查(not 面板.visible and int(面板.get("连斩数")) == 0,
			"攒满窗口就把整块收掉（原版 `setVisible(false)`，并把 count 归 0）；实得 visible=%s 数=%s"
			% [str(面板.visible), str(面板.get("连斩数"))])
	面板.call("投喂", 500.0)
	_查(not 面板.visible, "已经收起了再喂时间不该自己活回来（`tick` 开头那句 `if(!this.parent) return`）")

	# ── ⑦ 1291 的两条子命令（落点=后端连接，喂的是服务端字面量）──
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_停("缺 BackendConnection 单例，没法量 1291 的解码")
		return
	var 收数: Array[int] = []
	var 收阶段: Array[Dictionary] = []
	后端.connect("lianzhan_count_changed", func(数量: int): 收数.append(数量))
	后端.connect("lianzhan_stage_changed", func(阶段: int, 加成: int, 剩余: int, 总: int, 号: int):
		收阶段.append({"阶段": 阶段, "加成": 加成, "剩余": 剩余, "总": 总, "号": 号}))
	后端.call("_handle_bridge_text", "1291:1:250")
	_查(收数.size() == 1 and 收数[0] == 250, "1291:1 该解出连斩数；实得 %s" % str(收数))
	后端.call("_handle_bridge_text", "1291:2:3:40:120:900:77")
	_查(收阶段.size() == 1 and int(收阶段[0]["阶段"]) == 3 and int(收阶段[0]["加成"]) == 40
			and int(收阶段[0]["剩余"]) == 120 and int(收阶段[0]["总"]) == 900 and int(收阶段[0]["号"]) == 77,
			"1291:2 的五段该是 阶段/经验加成/剩余秒/总秒/角色号（原版 readShort,readShort,readInt,readInt,readInt）；实得 %s" % str(收阶段))
	var 前 := 收数.size()
	后端.call("_handle_bridge_text", "1291:1")
	后端.call("_handle_bridge_text", "1291:x:1")
	后端.call("_handle_bridge_text", "1291:2:3:40")
	_查(收数.size() == 前 and 收阶段.size() == 1,
			"段数不够或子命令号不是数字 ⇒ 整条丢（不拿默认值凑半个真状态）；实得 数=%d 阶段=%d" % [收数.size(), 收阶段.size()])
	后端.call("_handle_bridge_text", "1291:1:0")
	# ⚠ 别写 `收数[收数.size() - 1]`：变异把那一支打掉时数组是空的，空数组取 -1 会**运行期报错 ⇒ 协程死掉 ⇒ 门永不退出**
	#   （2026-10-11 变异 P3 实测超时 300 秒就是这么来的）。用 `count(0)`，空数组也安全。
	_查(收数.count(0) == 1, "1291:1:0 该解出一个 0（接线那条要拿它喂面板）；实得 %s" % str(收数))
	面板.call("收到连斩数", 0)
	_查(not 面板.visible, "0 走到面板 ⇒ 收起（这条判的是**接线**，不只是解码）")

	# ── ⑧ 数据与素材的明账（防"表和图哪天被清空了，上面还全绿"）──
	var 表: Dictionary = load("res://脚本/单例/游戏数据.gd").取表("原版杂项")
	var 段: Dictionary = (表.get("Lianzhan", {}) as Dictionary).get("interval", {})
	_查(段.size() == 9, "Etc.Lianzhan.interval 该有 9 档（斩数/100 = 0..8）；实得 %d" % 段.size())
	var 一致 := true
	for i in range(9):
		if int(段.get(str(i), -1)) != int(窗口档[i]):
			一致 = false
	_查(一致, "数据表那 9 档要与门里钉的数逐档相同（现在是 %s）" % str(窗口档))
	_查(int((表.get("Lianzhan", {}) as Dictionary).get("cooldown", 0)) == 900,
			"连斩阶段 buff 的总时长该是 900 秒（服务端 `_send_lianzhan_stage` 直接拿它当 totalSec）；实得 %s"
			% str((表.get("Lianzhan", {}) as Dictionary).get("cooldown", null)))
	_查(ResourceLoader.exists(标题皮), "「连斩」二字的皮要在盘上（原版符号 UISwf_Text_LianZhan，符号 114）")
	var 题图: Image = (load(标题皮) as Texture2D).get_image()
	_查(题图 != null and 题图.get_size() == Vector2i(54, 30),
			"皮该是导出那张 54×30（换了别的东西就该红）；实得 %s" % str(null if 题图 == null else 题图.get_size()))
	var 全齐 := true
	for i in range(1, 12):
		if not ResourceLoader.exists("%s%d.png" % [数字目录, i]):
			全齐 = false
	_查(全齐, "NoRed0 的 11 帧（0~9 + miss）该都在盘上，缺一条就会有个数字永远排不出来")

	# ── ⑨b 条的皮（`UISwf_LianZhan_Skin` = 符号 3、165×136 那圈血溅形）──
	_查(ResourceLoader.exists("res://素材/界面/通用界面/连斩条底.png"),
			"连斩条的底皮要在盘上（原版 `bgMC` 与 `maskMC` 是同一个符号的两张实例）")
	var 黑底 = 面板.get("黑底")
	var 红皮 = 面板.get("红条")
	_查(黑底 != null and 红皮 != null and (黑底 as TextureRect).texture != null
			and (红皮 as TextureRect).texture == (黑底 as TextureRect).texture,
			"黑底与红皮该是**同一张皮**画两遍（原版两遍 `new UISwfMovieClipAgent(\"UISwf_LianZhan_Skin\")`）")
	_查(黑底 != null and (黑底 as CanvasItem).self_modulate == Color(0, 0, 0, 1),
			"黑底该被涂黑（等价于原版那个 `beginFill(0)` 的黑矩形被皮当遮罩）；实得 %s"
			% str(null if 黑底 == null else (黑底 as CanvasItem).self_modulate))
	_查(红皮 != null and (红皮 as CanvasItem).self_modulate == Color(1, 1, 1, 1),
			"红皮该按**原色**画（它就是「填进来的那截红」）；实得 %s"
			% str(null if 红皮 == null else (红皮 as CanvasItem).self_modulate))
	var 窗2 = 面板.get("黑裁")
	_查(窗2 != null and bool((窗2 as Control).clip_contents),
			"黑色那张必须套在一个 clip_contents 的擦除窗口里（原版那个遮罩的角色）")
	_查(窗2 != null and (黑底 as Node).get_parent() == 窗2 and (红皮 as Node).get_parent() == 面板,
			"黑底必须在擦除窗口里、红条必须直接挂在面板上（红是被露出来的，不该被裁）；实得 黑父=%s 红父=%s"
			% [str(null if 黑底 == null else (黑底 as Node).get_parent().name),
				str(null if 红皮 == null else (红皮 as Node).get_parent().name)])
	_查(窗2 != null and (红皮 as Node).get_index() < (窗2 as Node).get_index(),
			"层序：红在下、黑在上（反了的话擦掉黑会连红一起看不见）")
	面板.call("放进度", 1.0)
	_查(窗2 != null and (窗2 as Control).size == Vector2(165.0, 136.0),
			"比例 1 ⇒ 擦除量 0 ⇒ 窗口该恢复成原版 `drawRect(0,0,165,136)` 那么大；实得 %s"
			% str(null if 窗2 == null else (窗2 as Control).size))

	# ── ⑨ HUD 侧真接上了没有（这条防"面板写好了但没人喂"）──
	面板.queue_free()
	await _帧(2)
	var 场景 := (load("res://场景/界面/小地图面板.tscn") as PackedScene)
	if 场景 == null:
		_停("小地图面板场景 load 不到，接线那条没法判")
		return
	var hud = 场景.instantiate()
	root.add_child(hud)
	await _帧(10)
	var 挂着 = hud.get("_连斩面板")
	_查(挂着 != null and is_instance_valid(挂着) and (挂着 as Node).get_parent() == hud,
			"HUD 该把连斩块**建出来并挂在自己下面**（`_ready` 里那两句 new/add_child）；"
			+ "实得 对象=%s 父=%s" % [str(挂着), str(null if 挂着 == null else (挂着 as Node).get_parent())])
	if 挂着 != null and is_instance_valid(挂着) and 后端.has_signal("lianzhan_count_changed"):
		_查(bool(后端.is_connected("lianzhan_count_changed", Callable(hud, "_于连斩数"))),
				"HUD 该把 1291:1 的信号接到自己的回调上（不然面板建好了也没人喂 —— 这条判的是接线）")
	hud.queue_free()

	# ── ⑩ 阶段光环（`Character.as:663-676`）：挂在玩家身上、按阶段换那 8 档 80 帧 ──
	var 玩 = load("res://脚本/角色/玩家.gd").new()
	root.add_child(玩)
	await _帧(3)
	_查(is_instance_valid(玩), "玩家节点该能单独建出来（阶段光环要挂在它身上）")
	# ⚠ 这一枚是**直接挂在 root 下**的 ⇒ 兄弟节点里没有 `Footholds`。旧写法照样
	#   `AUTO_PATHFINDER_SCRIPT.new(null, …)`，而它的 `_init` 当场读 `footholds.segments` 就抛。
	#   §3.245 实测：构造器里抛错**只中断 `_init` 自己**，`_ready` 照跑完 ⇒ 结果是拿到一个
	#   **图没建起来的半构建寻路器**（脚点全查不到 ⇒ 寻路静默失效），而不是"初始化半路断"。
	#   ⇒ 真正咬人的是下面第三条（`auto_pathfinder == null`）；前两条钉的是"`_ready` 的后半截
	#   确实跑到了"（变异下它们不红，别把它们当这条的证据，但它们防的是另一类回归）。
	_查(玩.get("player_sprite") != null,
			"`_ready` 后半截跑了 ⇒ 人物贴图建出来了（这条与寻路器无关，是初始化的通用前提）")
	_查(玩.get("_backend") != null,
			"`_ready` 后半截跑了 ⇒ `/root/BackendConnection` 绑上了（同上）")
	_查(玩.get("auto_pathfinder") == null,
			"场景里没有 Footholds ⇒ 不建寻路器（下游一律走 `走向()`，那里已判 null）")
	玩.call("设连斩阶段", 3)
	var 环 = _找光环(玩)
	_查(环 != null, "阶段 3 该在玩家身上挂一圈光环（原版 `new AuraLayerItem(\"Effect_LianZhanGuanHuan_\" + stage)`）")
	if 环 != null:
		_查(int((环.get("帧表") as Array).size()) == 80,
				"每档阶段的光环该是 80 帧；实得 %d" % int((环.get("帧表") as Array).size()))
		var 尺: Vector2 = 环.get("scale")
		_查(absf(尺.x - 139.6 / 109.5) < 0.001 and absf(尺.y - 33.0 / 109.5) < 0.001,
				"压扁的倍数要照原版 scaleX=139.6/109.5、scaleY=33/109.5；实得 %s" % str(尺))
		_查(int(环.get("z_index")) == -1, "光环该压在人物贴图之后画（脚下一圈扁环被身体挡一半）；实得 %s" % str(环.get("z_index")))
		环.call("投喂帧", 0.1)
		_查(int(环.get("当前帧")) == 4, "40 帧/秒 ⇒ 喂 0.1 秒该走到第 4 帧（`autoTick=false; fps=40`）；实得 %s" % str(环.get("当前帧")))
	玩.call("设连斩阶段", 5)
	var 环2 = _找光环(玩)
	_查(环2 != null and 环2 != 环, "换档该是**拆旧的建新的**（原版第一句就是 destroyLianZhanAura）；旧=%s 新=%s" % [str(环), str(环2)])
	玩.call("设连斩阶段", 0)
	_查(_找光环(玩) == null, "阶段 0 ⇒ 只拆不建（1291:2 发 0 就是到期了）")
	玩.call("设连斩阶段", 99)
	_查(_找光环(玩) == null, "阶段号越界（素材查不到）⇒ 不该留一个空壳光环在身上")

	玩.remove_from_group("player")	# ⚠ 不摘会串场：地图场景那个 地图实体 按 group 找玩家，会抓到这个旧的

	# ── ⑪ 地图场景里的真接线：喂一条 1291:2 给本人 ⇒ 玩家身上真的长出光环 ──
	var 场2 := (load("res://场景/地图/地图场景.tscn") as PackedScene)
	var 图2 = 场2.instantiate()
	root.add_child(图2)
	await _帧(14)
	var 玩2 = 图2.get_node_or_null("Player")
	_查(玩2 != null, "地图场景该建出玩家节点（接线那条要拿它当观测点）")
	var 我号2 := int(后端.get("character_id"))
	后端.call("_handle_bridge_text", "1291:2:4:50:600:900:%d" % 我号2)
	_查(_找光环(玩2) != null,
			"真 1291:2（角色号=本人）该让**玩家身上**长出光环；没长出来=解码到人物这一段断了")
	后端.call("_handle_bridge_text", "1291:2:6:70:600:900:%d" % (我号2 + 1))
	_查(_光环档号(玩2) != 6 if 玩2 != null else true,
			"角色号不是本人 ⇒ 一帧都不该往我身上套（原版那个 playerId 判断）；实得档 %s" % str(_光环档号(玩2)))
	后端.call("_handle_bridge_text", "1291:2:0:0:0:900:%d" % 我号2)
	_查(_找光环(玩2) == null if 玩2 != null else true, "发 0 ⇒ 我身上那圈该被拆掉")
	图2.queue_free()
	玩.queue_free()
	await _帧(3)

	if not _失败.is_empty():
		for 条 in _失败:
			print("红：" + 条)
		print("汇：判 %d 条 / 红 %d 条（连斩计数回归测试：失败）" % [判数, _失败.size()])
		quit(1)
		return
	print("汇：判 %d 条 / 红 0 条（连斩计数回归测试：通过）" % 判数)
	quit(0)

## 玩家身上那个连斩光环节点（按脚本路径认，别拿名字认——名字可能被别的特效占用）。
func _找光环(谁: Node) -> Node:
	if 谁 == null or not is_instance_valid(谁):
		return null
	for 子 in 谁.get_children():
		var 脚 = 子.get_script()
		if 脚 != null and String((脚 as Script).resource_path).contains("连斩光环"):
			return 子
	return null

func _光环档号(谁: Node) -> int:
	var 环 := _找光环(谁)
	return -1 if 环 == null else int(环.get("阶段"))

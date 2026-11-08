extends SceneTree

## 用户 2026-10-21 报修 3：「地图正中间下面的查克拉精华框，显示框虽然显示出来了，
## 但是在左上角，不在精华框旁边」。
##
## 根因一句话：**提示框的宿主是 CanvasLayer，而组件只认 Control 父节点**。
## `技能面板` 的根是 CanvasLayer（`场景/界面/技能面板.tscn:54`，layer=100），`_显精华提示`
## 把 `文字提示框` `add_child` 到它身上 ⇒ `get_parent() as Control` 恒 null ⇒ 组件里
## `_input`（跟鼠标）与 `_notification`（浮出那一帧定位）**两条自定位路径一起静默 return**
## ⇒ 提示框停在 `贴到鼠标(Vector2.ZERO, …)` 算出的 (10,20)，也就是"左上角"。
## 框本身弹得出来、四行文案也对 ⇒ 上一轮 `精华容器行为门` 只读文本，全绿却没发现跑偏。
##
## 原版没有这一道岔（真值详表见 `真值/窗口/精华容器.md`「提示框宿主」一节）：
##   · `BreathPane.as:44` `MToolTipText.createToolTip(stage, this.breath_background, …)` —— 挂 **stage**
##   · `MToolTip.as:94-98` `showTip()` 没给 container 时兜到 `PopUpMananger.stage`
##   · `:103` `_container.addChild(this)` ⇒ 提示框的局部系**恒等于舞台系**
##   · `:136-137` `x = container.mouseX + 10`、`y = container.mouseY + 20`
##   · `:138-141` 再钳进 `Config.STAGE_WIDTH/HEIGHT`（下/右探出就顶回去，负值钳 0）
##   · `:104` container 挂 MOUSE_MOVE ⇒ 事件驱动跟随（不是每帧轮询）
## 本工程 CanvasLayer 没有 offset/rotation/scale ⇒ 它的局部系就是舞台系 ⇒ 宿主原点认 (0,0)，
## 与原版逐像素同值。
##
## 腿：① 宿主与浮出那一帧的定位（用户报的本体）② MOUSE_MOVE 跟随 + 边沿钳制
## ③ Control 宿主的旧口径没被带坏（回归保护）+ 认不出宿主时保持旧行为
## ④ 舞台尺寸真的传进了 `设置`（不传就一直用组件默认的 960×560）⑤ 字面钉 + 旧账 ⑥ 存档字节不变。

const 出 := "res://测试/截图/追踪栏/精华提示位置.txt"
const 面板场景 := "res://场景/界面/技能面板.tscn"
const 面板脚本 := "res://脚本/界面/技能面板.gd"
const 提示场景 := "res://场景/界面/组件/文字提示框.tscn"
const 提示脚本 := "res://脚本/界面/组件/文字提示框.gd"
const 舞台 := Vector2(960, 560)
## 球底（`OriginalChakraCore`）在 `技能栏` 里的烘值 x 428..537、y 1..90
## （`场景/界面/技能面板.tscn:79-84`）；960×560 下 `技能栏` 全局在 (0,459)、960×101。
const 球底局部 := Rect2(428.0, 1.0, 109.0, 89.0)
const 栏全局 := Vector2(0.0, 459.0)
## 悬停点取球底中心（全局）：x (428+537)/2 ≈ 482、y 459+1+89/2 ≈ 504。
const 球心 := Vector2(482.0, 504.0)

var 日志: Array[String] = []
var 判 := 0
var 红 := 0
var 收 := false
var 存前 := PackedByteArray()
var 景: Node
var 提示: Control


func _判(过: bool, 说: String, 得 := "") -> void:
	判 += 1
	var 行 := "%s %s" % ["ok " if 过 else "!!红", 说]
	if 得 != "":
		行 += "　｜实得 " + 得
	日志.append(行)
	if not 过:
		红 += 1
	_写()


func _步(说: String) -> void:
	日志.append("· " + 说)
	_写()


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < 截止:
		if not 日志.is_empty() and str(日志[日志.size() - 1]).begins_with("汇"):
			return
		await create_timer(0.2).timeout
	if 收:
		return
	_判(false, "看门狗：120 秒没跑到汇总（看最后一条停在哪一步）")
	_尾()


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


## `MToolTip.as:136-141`：鼠标 +(10,20)，再钳进舞台（量具里框比舞台矮，scale 恒 1）。
func _期望(鼠标: Vector2, 舞台尺: Vector2, 框尺: Vector2) -> Vector2:
	var p := 鼠标 + Vector2(10.0, 20.0)
	p.x = clampf(p.x, 0.0, maxf(0.0, 舞台尺.x - 框尺.x))
	p.y = clampf(p.y, 0.0, maxf(0.0, 舞台尺.y - 框尺.y))
	return p


func _点(p: Vector2) -> String:
	return "(%.1f, %.1f)" % [p.x, p.y]


## 推一条合成移动事件。`_input` 读的是**事件自带坐标**，绝不能用 `get_local_mouse_position()`
## —— OS 真实光标在 headless + `push_input` 下不更新（2026-09-28 探针实测），那样跟随永远验不出来。
func _移(位: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	await _帧(2)


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await _帧(2)
	## 存档基线要在**单例启动之后**取：跨天首次启动时 `游戏会话._reset_daily_quests_if_needed()`
	## 会按日重置并落一次盘（产品行为，不是本门写的）。基线取在启动前 ⇒ 每天第一次跑都假红。
	存前 = _字节("user://玩家数据.json")
	景 = (load(面板场景) as PackedScene).instantiate()
	root.add_child(景)
	await _帧(10)
	var 栏 := 景.get_node_or_null("技能栏") as Control
	_判(栏 != null, "技能栏在")
	var 球底 := 栏.get_node_or_null("OriginalChakraCore") as Control if 栏 != null else null
	_判(球底 != null, "球底 OriginalChakraCore 在（原版提示框就挂它身上）")
	if 球底 != null:
		var 局 := Rect2(球底.position.x, 球底.position.y, 球底.size.x, 球底.size.y)
		_判(局 == 球底局部, "球底在技能栏里的矩形 = 烘值 (428,1,109,89)", str(局))
		_判(栏.get_global_position() == 栏全局,
				"960×560 下技能栏全局在 (0,459)（底锚、高 101）⇒ 悬停点 (482,504) 有出处",
				_点(栏.get_global_position()))
	await _量浮出(球底)
	await _量跟随(球底)
	await _量控制宿主()
	await _量舞台尺寸(球底)
	_量字面()
	_尾()


## ── ① 宿主与浮出那一帧（用户报的本体）────────────────────────────────────
func _量浮出(球底) -> void:
	if 球底 == null:
		_判(false, "球底缺件 ⇒ ①②④ 整段没跑")
		return
	await _移(球心)
	球底.mouse_entered.emit()
	await _帧(2)
	提示 = 景.get_node_or_null("精华提示框") as Control
	_判(提示 != null and 提示.visible, "悬停球底 ⇒ 四行说明框弹出来")
	if 提示 == null:
		return
	_判(提示.get_parent() is CanvasLayer,
			"提示框挂的是面板那根 **CanvasLayer**（= 原版 `createToolTip(stage, …)` 的那个 stage）",
			str(提示.get_parent().get_class()))
	_判(提示.global_position.distance_to(Vector2(10.0, 20.0)) > 5.0,
			"**不再钉死在左上角 (10,20)** —— 那就是用户看到的「在左上角」", _点(提示.global_position))
	var 尺 := 提示.size
	_判(尺.y > 60.0 and 尺.y < 200.0 and 尺.x > 100.0 and 尺.x <= 354.0 + 17.0,
			"框尺寸 sane（四行；宽不超过原版 MAX_WIDTH+PADDING 的换算）",
			"(%.0f, %.0f)" % [尺.x, 尺.y])
	var 期望 := _期望(球心, 舞台, 尺)
	_判(提示.position.distance_to(期望) < 0.6,
			"浮出来那一帧就贴在鼠标右下：= 悬停点+(10,20) 再钳进舞台（`MToolTip.as:136-141`）",
			"%s ≠ %s" % [_点(提示.position), _点(期望)])
	_判(absf(提示.position.y - (舞台.y - 尺.y)) < 0.6,
			"悬在球底时 y 被顶回舞台下沿（560−框高），不探出画布", _点(提示.position))


## ── ② 球底宿主：球内跟随、出球即收 ────────────────────────────────────────
## ⚠ 跟随后"把鼠标推到别处"这条腿以前写在球底宿主上，跑出来是假红：
## 合成 motion 会同时走 **pick**，鼠标一离开球底（428..537 × 460..549）真 `MOUSE_EXIT` 就把框收了，
## 于是 `_input` 里 `if visible:` 不成立、位置自然不动。边沿钳制那种"鼠标离得很远"的量法
## 挪到 ③ 的量具宿主（没人管它可见性）上去做；这里只留两条**真在球底上**的。
func _量跟随(球底) -> void:
	if 提示 == null or not is_instance_valid(提示):
		_判(false, "② 起跑时提示框已经没了（① 的宿主认错了？）")
		return
	var 旧 := 提示.position
	await _移(Vector2(470.0, 530.0))
	_判(提示.visible, "鼠标还在球底里 ⇒ 框不会被自己关掉")
	_判(提示.position.distance_to(_期望(Vector2(470.0, 530.0), 舞台, 提示.size)) < 0.6
			and 提示.position.x < 旧.x,
			"球底内跟随：落点 = 悬停点+(10,20) 再钳进舞台，且比上一次靠左",
			"%s → %s" % [_点(旧), _点(提示.position)])
	await _移(Vector2(700.0, 200.0))
	_判(not 提示.visible,
			"鼠标移出球底 ⇒ 框收起（这一条是 pick 真发的 MOUSE_EXIT，不是量具手动 emit）",
			str(提示.visible))
	_判(提示.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"框自己不吃鼠标（`MToolTip.as:32` mouseChildren=mouseEnabled=false）",
			str(提示.mouse_filter))
	await _移(球心)
	球底.mouse_entered.emit()
	await _帧(2)
	_判(提示.visible, "重新悬回球底 ⇒ 框又浮出来（节点留着复用，见 ⑤ 旧账）")
	球底.mouse_exited.emit()
	await _帧(2)
	_判(not 提示.visible, "移开 ⇒ 框收起（`:34-46 closeTip` 的位置，本工程用切可见性代替 removeChild）")


## ── ③ 量具宿主：Control 宿主的旧口径 + 四边钳制 + 认不出宿主 ───────────────
## 这块父节点是**普通 Control**（不是技能栏、没有 hover 归属），可见性由量具自己说了算，
## 所以敢把鼠标推到舞台四角去量钳制；同时它也是"窗口类宿主没被带坏"的回归保护。
func _量控制宿主() -> void:
	var 页 := Control.new()
	页.name = "提示宿主页"
	页.position = Vector2(200.0, 100.0)
	页.size = Vector2(600.0, 400.0)
	root.add_child(页)
	await _帧(2)
	var 框 := (load(提示场景) as PackedScene).instantiate() as Control
	页.add_child(框)
	框.call("设置", "[color=#ffffff]量具[/color]", 舞台)
	框.visible = true
	await _移(Vector2(400.0, 300.0))
	_判(框.position == Vector2(210.0, 220.0),
			"父节点是 Control（窗口页）时仍旧**减页面全局位置**：全局(400,300) ⇒ 局部(210,220)"
			+ "（`人物窗口._挂文字提示` 那一族宿主没被这次改动带坏）", _点(框.position))
	_判(框.call("_舞台矩形") == Vector2(760.0, 460.0),
			"`_舞台矩形()` = 舞台 − 页面全局位置（窗口类宿主的老算法原样保留）",
			str(框.call("_舞台矩形")))
	await _移(Vector2(700.0, 300.0))
	_判(框.position == Vector2(510.0, 220.0), "一路跟：全局(700,300) ⇒ 局部(510,220)", _点(框.position))
	await _移(Vector2(950.0, 300.0))
	_判(absf(框.position.x - (760.0 - 框.size.x)) < 0.6 and 框.position.y == 220.0,
			"贴舞台右边缘 ⇒ x 钳到 (舞台−页面原点)−框宽（`MToolTip.as:138`），y 不动", _点(框.position))
	await _移(Vector2(950.0, 540.0))
	_判(absf(框.position.y - (460.0 - 框.size.y)) < 0.6,
			"贴舞台下边缘 ⇒ y 钳到 (舞台−页面原点)−框高（`:139`）", _点(框.position))
	await _移(Vector2(2.0, 2.0))
	_判(框.position == Vector2(0.0, 0.0),
			"推到舞台左上角之外 ⇒ 负值钳 0（`:140-141`），不越出画布", _点(框.position))
	框.queue_free()
	页.queue_free()
	await _帧(3)
	var 裸 := (load(提示场景) as PackedScene).instantiate() as Control
	root.add_child(裸)
	裸.call("设置", "[color=#ffffff]量具[/color]", 舞台)
	裸.visible = true
	await _帧(2)
	await _移(Vector2(400.0, 300.0))
	_判(裸.position == Vector2(10.0, 20.0),
			"父节点既不是 Control 也不是 CanvasLayer ⇒ 跟随照旧不接管（停在 (10,20)）"
			+ " —— 这条就是改动前精华框的真实处境", _点(裸.position))
	裸.queue_free()


## ── ④ 舞台尺寸真的传进了 `设置` ───────────────────────────────────────────
## 组件默认 `_舞台 = (960,560)`，本工程舞台恰好也是 960×560 ⇒ "没传参"在现尺寸下**看不出来**。
## 所以把窗口改成 1200×760 再重悬一次：传了 ⇒ 钳到 760−框高；没传 ⇒ 还钳在 560−框高。
func _量舞台尺寸(球底) -> void:
	if 球底 == null or 提示 == null or not is_instance_valid(提示):
		_判(false, "④ 缺球底或提示框，跑不了")
		return
	root.size = Vector2i(1200, 760)
	await _帧(4)
	var 栏 := 球底.get_parent() as Control
	## 技能栏是 `anchor_left = anchor_right = 0.5` + offsets −480..480 ⇒ **水平居中**：
	## 960 宽时全局 x=0（所以 ① 的悬停点取 482），1200 宽时全局 x=(1200−960)/2=**120**。
	_判(栏 != null and 栏.get_global_position() == Vector2(120.0, 659.0),
			"改尺寸后技能栏重新锚到底（全局 = (120, 760−101)）",
			_点(栏.get_global_position() if 栏 != null else Vector2.INF))
	var 悬 := Vector2(120.0 + 482.0, 659.0 + 1.0 + 44.0)
	await _移(悬)
	球底.mouse_entered.emit()
	await _帧(2)
	_判(提示.visible, "1200×760 下重悬 ⇒ 框又浮出来")
	_判(提示.get("_舞台") == Vector2(1200.0, 760.0),
			"`设置` 的第二参把**当前视口尺寸**交给了组件（不传就一直停在默认 960×560）",
			str(提示.get("_舞台")))
	_判(absf(提示.position.y - (760.0 - 提示.size.y)) < 0.6,
			"1200×760 下 y 钳到 760−框高（传参没落地就会钳到 560−框高 ⇒ 这条红）",
			_点(提示.position))
	_判(提示.position.distance_to(_期望(悬, Vector2(1200.0, 760.0), 提示.size)) < 0.6
			and 提示.position.x == 612.0,
			"x = 悬停点(602)+10=612，落在新舞台里没被钳", _点(提示.position))


## ── ⑤ 字面钉：改动本身不许被"顺手优化"掉；旧账要留在明面上 ────────────────
func _量字面() -> void:
	var 提 := FileAccess.get_file_as_string(提示脚本)
	_判(提.contains("func _宿主原点() -> Variant"), "组件里有了**统一的宿主原点**取法（不再各写一份）")
	_判(提.contains("if 主 is CanvasLayer:") and 提.contains("return Vector2.ZERO"),
			"CanvasLayer 宿主认原点 (0,0)（对应原版 `MToolTip.as:94-98/103` 挂 stage）")
	_判(提.contains("if 主 is Control:") and 提.contains("(主 as Control).get_global_position()"),
			"Control 宿主那一路原样保留（窗口类提示框共用同一个组件）")
	_判(not 提.contains("get_parent() as Control"),
			"老的 `get_parent() as Control` 已经没了（就是它让 CanvasLayer 宿主静默 no-op）")
	_判(提.count("_宿主原点()") >= 3, "`_input`、`_舞台矩形` 与定义都走同一个取法",
			str(提.count("_宿主原点()")))
	var 技 := FileAccess.get_file_as_string(面板脚本)
	_判(技.contains("_精华提示.call(\"设置\", 精华提示文本(), get_viewport().get_visible_rect().size)"),
			"技能面板把视口尺寸交给 `设置`（CanvasLayer 没有 `get_viewport_rect()`，只能走 `get_viewport()`）")
	_判(技.contains("add_child(_精华提示)"),
			"提示框仍挂在本面板（舞台层）上，没塞进 技能栏（那里只有 101px 高，会把框钳出缩放）")
	_判(技.contains("BreathPane.as:44") and not 技.contains("BreathPane.as:37"),
			"createToolTip 的行号订正到 `:44`（旧注释写的 :37 是错的）")
	_判(技.contains("BreathPane.as:43"), "mouseEnabled 那行的行号订正到 `:43`")
	_判(技.contains("en_US$message_properties.as:330"),
			"四行文案的行号出处钉在注释里（原句本身就是 `<font color>` + `<br/>`）")
	var 值 := FileAccess.get_file_as_string("res://真值/窗口/精华容器.md")
	_判(值.contains("提示框宿主"), "真值表补了「提示框宿主」这一节（CanvasLayer = stage）")
	_判(技.contains("§3.240"), "技能面板把「原版移出即 removeChild、我们留着节点只切 visible」写成旧账挂编年史")


## ── 汇总 ──────────────────────────────────────────────────────────────────
func _尾() -> void:
	if 收:
		return
	收 = true
	var 现 := _字节("user://玩家数据.json")
	_判(现 == 存前, "跑完 `user://玩家数据.json` **字节没变**（门只推合成事件，不落盘）")
	日志.append("汇：判 %d，红 %d ｜%s" % [判, 红, "全绿" if 红 == 0 else "有红，见上面 !!红 那几行"])
	_写()
	print("判 %d 红 %d" % [判, 红])
	quit(1 if 红 > 0 else 0)

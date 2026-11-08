extends SceneTree

## 「Boss 房门确认」在线门（`1349 PORTAL_PANEL`，§3.327）——走真实服务端夹具。
##
## 用户 2026-10-31 报「BOSS 地图都进不去了」：服务端对**专门 Boss 房间**
## （`_is_boss_room_map:15060`：世界 Boss 图 + 11 张首领图）**先把换图挂起**
## （`_request_boss_map_confirmation:15067` 写 `pending_map_confirmation`、60 秒过期），
## 回一条 `1349:<request_id>:<整句>`；客户端必须回 `1349:<request_id>:<1|0>`
## （`handle_portal_panel_confirmation:15114`）服务端才 `_warp_to_map`。
## 移植端原先**一帧 1349 都不接** ⇒ 门点下去什么都不发生，且不发系统消息。
##
## 钉七条：
##   ① 普通门（非 Boss 房间）**不弹**确认、直接换图 —— 防止把确认框接成"逢门必弹"。
##   ② Boss 门回帧 ⇒ 确认框出现，正文 = 服务端那句（逐字钉，抄自
##      `fake_flash_server.py:15101-15104`），且**此刻还没换图**（挂起语义）。
##   ③ 按「取消」⇒ 框消失、人留在原图 ⇒ 回帧是 0 不是 1。
##   ④ 取消之后**立刻再点同一扇门**能再弹一次 —— 证明挂起被清掉了、不是要占满 60 秒。
##   ⑤ 再按「确定」⇒ 服务端发 129、会话地图 = Boss 图（回帧是 1、挂起被放行）。
##   ⑥ **几何腿**：遮罩尺寸 = 视口尺寸，框/主体/确定/取消 全在屏幕内。
##      2026-10-31 用户报「BOSS 地图的提示框不显示，无法点击确认」：`窗口管理._on_portal_panel`
##      在遮罩**进树前**写 `遮罩.size = 视口尺寸`，满铺锚点把它烘成偏移 ⇒ 进树后 1920×1120，
##      `弹消息` 按双倍尺寸居中 ⇒ 主体在 (809,509)、确定钮 y=576，960×560 屏上只剩右下角一条字。
##      旧门只查节点在不在，整块摆到屏幕外照样绿 —— ⑥ 就是补这个盲区。
##   ⑦ ③/⑤ 的按钮改走**真鼠标**（`root.push_input` GUI 拾取），不再 `emit_signal("pressed")`；
##      信号只能证明"钮连着回调"，证明不了"点得到"。
## 由 `开发工具/跑在线用例.ps1 -用例 boss门确认在线` 调（起隔离夹具；**不能并行**）。

## 服务端 `_request_boss_map_confirmation` 的整句（`fake_flash_server.py:15101-15104`，
## 源里是 \u 转义；这里钉成可读字面量，改服务端文案就该红）。
const 确认正文 := "即将进入Boss房间，房间内存在强力首领，死亡可能受到惩罚。是否确认进入？"
## 夹具主角色出生图 101010000 ⇒ 两跳普通门到 102010000，第三跳才是 Boss 图。
## 门号取自 `数据/地图/<图>/地图.json` 的门表（BFS 过一遍的实链）。
const 起始图 := "101010000"
const 普通跳 := [
	{"门": 2, "到": "100000000"},
	{"门": 3, "到": "102010000"},
]
const Boss图 := "102030000"

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")
	# 看门狗：中断/崩在某一帧时别把跑批器吊死
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("首领房门确认在线回归测试：超时中断")
		quit(2))

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	for 条 in _失败:
		printerr("首领房门确认在线回归测试：" + 条)
	printerr("首领房门确认在线回归测试：中断 - " + 话)
	quit(1)

func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())

func _找遮罩() -> Control:
	var 场景 := current_scene
	if 场景 == null:
		return null
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		return null
	return 管理.find_child("进图确认遮罩", true, false) as Control

func _找框() -> Control:
	var 遮 := _找遮罩()
	if 遮 == null:
		return null
	return 遮.find_child("消息确认框", true, false) as Control

## **真鼠标点**（走 GUI 拾取，不是发信号）。
## `emit_signal("pressed")` 只能证明"钮连着回调"，证明不了"钮在屏上、点得到" ——
## 10-31 那版确认框整块被摆到屏幕外，信号腿照样全绿，用户实机却是看不见、点不了。
func _按(钮名: String) -> bool:
	var 框 := _找框()
	if 框 == null:
		return false
	var 钮 := 框.get_node_or_null("主体/" + 钮名) as Button
	if 钮 == null or 钮.disabled:
		return false
	var 位 := 钮.get_global_rect().get_center()
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	for 下 in [true, false]:
		var 点 := InputEventMouseButton.new()
		点.position = 位
		点.global_position = 位
		点.button_index = MOUSE_BUTTON_LEFT
		点.pressed = 下
		root.push_input(点)
	return true

func _run() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_停("缺单例")
		return
	## 无头跑批器里根视口只有 **64×64**（`DisplayServer.window_get_size()=(0,0)`），
	## 302 宽的确认框怎么摆都"在屏幕外" —— 几何腿量不出真假。这里钉回设计尺寸 960×560，
	## 与真客户端一开始的窗口一致（`project.godot` 的 `viewport_width/height`）。
	if root.size != Vector2i(960, 560):
		root.size = Vector2i(960, 560)
		await process_frame
		await process_frame
	_查(root.get_viewport().get_visible_rect().size == Vector2(960.0, 560.0),
			"批跑器视口没钉到 960×560（实际 %s），几何腿不可信" % root.get_viewport().get_visible_rect().size)
	后端.sync_character()
	if not await _等(func(): return bool(后端.in_game), 15000):
		_停("进不了后端：%s - %s" % [后端.status, 后端.detail])
		return
	_查(String(会话.current_map_id) == 起始图,
			"进图后当前地图 %s ≠ %s（夹具出生点变了？门链要重算）" % [会话.current_map_id, 起始图])

	# —— ① 普通门不弹确认 ——
	for 跳 in 普通跳:
		var 发: bool = 后端.request_portal_enter(int(跳["门"]))
		_查(发, "普通门 %d 请求发出失败（%s → %s）" % [int(跳["门"]), 会话.current_map_id, 跳["到"]])
		var 到: bool = await _等(func(): return String(会话.current_map_id) == String(跳["到"]), 12000)
		_查(到, "普通门 %d 没换到 %s（停在 %s）" % [int(跳["门"]), 跳["到"], 会话.current_map_id])
		if not 到:
			_停("普通门链就断了，后面的 Boss 门腿没法跑")
			return
		_查(_找框() == null, "普通门 %d 也弹了确认框（1349 接成逢门必弹了？）" % int(跳["门"]))
		await create_timer(2.4).timeout		# 过 PORTAL_STALE_REQUEST_GUARD_SECONDS=2.0

	# —— ② Boss 门 ⇒ 1349 确认框，正文逐字、且还没换图 ——
	_查(后端.request_portal_enter(0), "Boss 门请求发出失败")
	if not await _等(func(): return _找框() != null, 5000):
		_停("5 秒没等到 Boss 房门确认框（1349 没解析？服务端那条挂起没人答就永远不动）")
		return
	var 框 := _找框()
	var 正文 := String((框.get_node("主体/正文") as RichTextLabel).text)
	_查(正文 == 确认正文, "确认框正文「%s」≠ 服务端原句「%s」" % [正文, 确认正文])
	await create_timer(0.8).timeout
	_查(String(会话.current_map_id) == "102010000",
			"确认框还开着人就已经在 %s 了 —— 挂起语义没对上（客户端自己换的图？）" % 会话.current_map_id)

	# —— ⑥ 几何：遮罩铺满视口、框和两枚钮都在屏幕内（否则看不见也点不到） ——
	var 视口矩形 := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	var 遮 := _找遮罩()
	if 遮 == null:
		_停("找不着 进图确认遮罩（框在却没有遮罩？节点结构变了）")
		return
	_查(遮.size.is_equal_approx(视口矩形.size),
			"确认遮罩 %s ≠ 视口 %s —— 满铺锚点被烘成双倍偏移，框会被摆到屏幕外" % [遮.size, 视口矩形.size])
	_查(框.is_visible_in_tree(), "确认框在树里却不可见")
	for 件 in [框, 框.get_node_or_null("主体"), 框.get_node_or_null("主体/确定"), 框.get_node_or_null("主体/取消")]:
		if 件 == null:
			_查(false, "确认框缺件：框/主体/确定/取消 里出现了 null")
			continue
		var 矩: Rect2 = (件 as Control).get_global_rect()
		_查(视口矩形.encloses(矩), "「%s」不在屏幕内：%s ⊄ %s" % [件.name, 矩, 视口矩形])

	# —— ③ 真鼠标点「取消」⇒ 框关、人不动 ——
	_查(_按("取消"), "找不着确认框的「取消」钮")
	if not await _等(func(): return _找框() == null, 3000):
		_停("真鼠标点了取消，确认框没消失（钮在屏幕外/被别的层挡住？）")
	await create_timer(1.5).timeout		# 给服务端足够时间证明它没偷偷换图
	_查(String(会话.current_map_id) == "102010000",
			"取消之后人却到了 %s —— 回帧没发 0 或者服务端当成了 1" % 会话.current_map_id)

	# —— ④ 取消清挂起：同一扇门能再弹一次 ——
	await create_timer(1.0).timeout		# 合计 2.5 秒，过本地门点击时效保护
	_查(后端.request_portal_enter(0), "取消后重发 Boss 门请求失败")
	if not await _等(func(): return _找框() != null, 5000):
		_停("取消后同一扇门不再弹确认框（服务端挂起没清掉？那 60 秒内所有 Boss 门都会哑）")
		return

	# —— ⑤ 真鼠标点「确定」⇒ 129 到、进 Boss 图 ——
	_查(_按("确定"), "找不着确认框的「确定」钮")
	if not await _等(func(): return String(会话.current_map_id) == Boss图, 12000):
		_停("真鼠标点了确定 12 秒还停在 %s（钮点不到 / 1349 回帧没到服务端 / request_id 对不上？）"
				% 会话.current_map_id)
		return
	_查(_找框() == null, "进 Boss 图之后确认框还挂着")

	if not _失败.is_empty():
		for 条 in _失败:
			printerr("首领房门确认在线回归测试：" + 条)
		quit(1)
		return
	print("首领房门确认在线回归测试：通过（%d 条断言：普通门不弹/正文逐字/挂起不换图/框在屏内/取消/确定才换图）" % _受检)
	后端.disconnect_backend()
	quit(0)

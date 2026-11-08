extends SceneTree

## 「一键三钮在线」门（2026-10-22）—— 用户**第三次**实机报「一键学习/一键拾取/一键卖出
## 点击后没有反应」。
##
## 病史（同一个钮，三次报障）：
##   ① §3.178（`7ffe97b`）：Label mouse_filter=IGNORE / 「拾取」宽 52 盖住「卖出」/
##      服务端失败路径静默 —— 修完用户仍报没反应；
##   ② §3.182（`e18b522`）：服务端实话走 `CHAR_NOTICE(512)` 帧，客户端 `_handle_chat_text`
##      只发 `chat_received`、聊天面板页签位没有 512 ⇒ **397 处反馈全游戏一句都显示不出来**；
##      外加空面板时拾取/卖出静默 —— 修完用户仍报没反应；
##   ③ 本轮（真凶）：`_接学习钮` 的 lambda 里 `match 动作` 的三个分支名写的是
##      「一键学习/全部拾取/全部卖出」，而 `学习钮表` 第三列（= 实际传入的 动作）是
##      「学习全部/拾取全部/卖出全部」——**词序对不上，match 永远不命中** ⇒ `发` 恒 false
##      ⇒ **请求一个都没发出客户端**，恒弹「需要连接原版服务端」。§3.178 的
##      `验意志一键钮.gd` 又把那句离线回执当期望断言 ⇒ 门把 bug 钉住了（假绿）。
##
## 本门堵的是这个洞：**在线 + 真点按钮 + 真界面反馈**这条组合（此前离线门只覆盖离线，
## 在线门只直调会话方法，按钮这一跳从来没人测过）。
##   ① 悬停归属必须是按钮自己（点击没被别家吃）；
##   ② 点完**不许**再弹「需要连接原版服务端」（bug 签名，直接钉死）；
##   ③ 必须有**可观测反馈**：会话状态真变了（面板/背包/阅历）或收到通知
##      （空面板/阅历不足时服务端的 512 实话）——两者都没有就是钮没通。
## 由 `bash 测试/跑在线门.sh 一键三钮在线回归测试.gd` 调（夹具 `--run` 起游戏，
## 端口 18684；跑前会清端口，别在用户实机跑的时候用）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")

var _失败: Array[String] = []
var _受检 := 0
var _通知: Array[String] = []
var _会话 = null
var _后端 = null


func _initialize() -> void:
	call_deferred("_跑")


func _查(条件: bool, 话: String) -> void:
	_受检 += 1
	if not 条件:
		_失败.append(话)


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


func _印(话: String) -> void:
	print("[一键三钮在线] " + 话)


## 第二层显示 + 独接不叠线（§3.185，2026-10-22 用户实机报「应该有第二层，但是没有显示」）：
##   真凶：`_填学习格` 上界 10 ⇒ 只填一排；服务端 `SPIRIT_PANEL_LIMIT = 20`、原版
##   `YiZhiContainer` 动态排两行（`getYiZhiPoint:65-71` y=(i/10)·82）⇒ 面板 ≥11 件时
##   多出的件在客户端不显示、不可拾取/卖出。阅历只够学几次 ⇒ 真点凑不出 11 件，
##   这里直接用**会话里的真实 id** 把面板灌到 15 件再重渲（纯客户端渲染链，不落存档）。
##   顺带钉 `_独接输入`：重渲 N 次后「卖出」的 gui_input 仍恰好 1 条连接
##   （旧代码每帧重接一条 ⇒ 点一次卖出发 N 个请求，是 §3.183 服务端 pop 竞态的放大器）。
func _验第二层与独接(窗: Node) -> void:
	# ⚠️ 页面**每次渲染都是新建**的（`功能窗口._instantiate_page:4387`）⇒ 渲染函数跑完
	#    必须重新拿页面节点，旧引用指向的是已释放的页。
	var 页面容器: Node = _页根(窗)
	if 页面容器 == null:
		_停("学习窗没有页面容器")
		return
	var 脚本: Script = load("res://脚本/界面/窗口/意志窗口.gd")
	# ⚠️ 页面**每次渲染都是新建**的（`功能窗口._instantiate_page:4387`）⇒ 先清旧页，
	#    否则 `add_child` 撞名 ⇒ Godot 把新页自动改名 `@Control@id`、旧页还占着树
	#    ⇒ find_child 拿到旧页的容器、断言看旧页而填充写新页（首版假红就这么来的）。
	for 子 in 页面容器.get_children():
		页面容器.remove_child(子)
		子.queue_free()
	# ⚠️ 候选 id 必须**过图鉴**：背包行里的 id 不一定是意志域（可能是四书材料 16000023..26）
	#   ⇒ `图鉴项` 查不到的 id 会让 `_填学习格` 当场 continue、格子留隐（首版就是这么假红的）。
	var 源: Array = []
	for 行 in _会话.spirit_panel:
		var 号 := int(行)
		if 号 > 0 and not 脚本.call("图鉴项", 号).is_empty():
			源.append(号)
	for 行 in _会话.spirit_bag:
		if 源.size() >= 4:
			break
		var d := 行 as Dictionary
		var 号2 := int(d.get("id", 0))
		if 号2 > 0 and not 脚本.call("图鉴项", 号2).is_empty():
			源.append(号2)
	_查(源.size() > 0, "会话里一件图鉴认得的意志都没有，灌不了第二层")
	if 源.is_empty():
		return
	var 面板: Array = []
	for k in 15:
		面板.append(源[k % 源.size()])
	_会话.set("spirit_panel", 面板)
	# 重渲两遍：第一遍显示、第二遍验「独接」不叠线
	for _遍 in range(2):
		脚本.call("渲染学习", 窗)
		for _帧 in range(3):
			await process_frame
	var 容器 := 页面容器.find_child("意志容器", true, false) as Control
	_查(容器 != null, "页面里没有 意志容器")
	if 容器 == null:
		return
	for k in 20:
		_查(容器.get_node_or_null("意志格_%d" % k) != null,
				"场景里缺 意志格_%d（第二层 10 格没烘进场景？）" % k)
	var 全显 := true
	for k in 10:
		var 格 := 容器.get_node_or_null("意志格_%d" % k) as Control
		if 格 != null and not 格.visible:
			全显 = false
	_查(全显, "第一排有格子没显示出来（面板 15 件时前 10 格应全显）")
	for k in range(10, 15):
		var 格 := 容器.get_node_or_null("意志格_%d" % k) as Control
		_查(格 != null and 格.visible, "第二层 意志格_%d 不可见（= 用户报的「第二层没有显示」）" % k)
		var 图 := 格.get_node_or_null("图标") as TextureRect if 格 != null else null
		_查(图 != null and 图.texture != null, "第二层 意志格_%d 没有图标 texture" % k)
	for k in range(15, 20):
		var 格 := 容器.get_node_or_null("意志格_%d" % k) as Control
		_查(格 != null and not 格.visible, "第二层 意志格_%d 应该空着不可见（面板只有 15 件）" % k)
	# 独接：重渲两遍后每格「卖出」仍恰好 1 条连接
	var 卖 := 容器.get_node_or_null("意志格_12/卖出") as Control
	if 卖 != null:
		var 连线数 := 卖.gui_input.get_connections().size()
		_查(连线数 == 1,
				"重渲两遍后 意志格_12/卖出 的 gui_input 有 %d 条连接（_独接输入 没去重 ⇒ 点一次发多次请求）"
				% 连线数)


func _跑() -> void:
	# 无头视口是 (64,64)，钉尺寸（门卫生）
	root.size = Vector2i(960, 560)
	_会话 = root.get_node_or_null("GameSession")
	_后端 = root.get_node_or_null("BackendConnection")
	if _会话 == null or _后端 == null:
		_停("缺单例")
		return
	# 端口覆盖（只改内存里的 game_settings，不落盘）：`NARUTO_TEST_PORT=18699` 可让本门
	# 连到另一份夹具上自测——注册运行（跑在线门.sh 起 18684 夹具）不设这个变量，走默认。
	# ⚠️ 跑在线门.sh 会清 18684 端口 ⇒ 用户实机在跑时绝不注册运行。
	var 端口 := OS.get_environment("NARUTO_TEST_PORT")
	if not 端口.is_empty():
		_会话.game_settings["backend_port"] = int(端口)
		_印("backend_port 覆盖为 %s（仅内存）" % 端口)
	_后端.sync_character()
	if not await _等(func(): return bool(_后端.in_game), 25000):
		_停("进不了后端：%s - %s" % [_后端.status, _后端.detail])
		return

	# `--script` 模式下主场景不自动加载 ⇒ 手动实例化地图场景（与实机同一条
	# playable_scene_path；离线门 `人物窗意志格回归测试` 同款手法）。
	var 场景路径: String = 地图资源.playable_scene_path(String(_会话.current_map_id))
	var 打包 := load(场景路径) as PackedScene
	if 打包 == null:
		_停("加载不了地图场景：%s" % 场景路径)
		return
	var 场景 := 打包.instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(10):
		await process_frame
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_停("地图场景里没有 窗口管理")
		return

	var 窗: Node = 管理.call("取或建窗口", "意志学习")
	if 窗 == null:
		_停("建不出「意志学习」窗")
		return
	_会话.notification_requested.connect(func(文: String) -> void: _通知.append(文))
	窗.call("打开")
	# 等开窗那一串回帧（action0 ⇒ cmd0/1/6/7）把页面渲染出来
	for _帧 in range(40):
		await process_frame
	_印("学习窗已开：阅历=%d 面板=%d 包=%d" % [
		_会话.阅历, _会话.spirit_panel.size(), _会话.spirit_bag.size()])

	for 名 in ["一键学习", "全部拾取", "全部卖出"]:
		await _真点并查(窗, 名)

	await _验第二层与独接(窗)

	if not _失败.is_empty():
		for 话 in _失败:
			_印("!! " + 话)
		printerr("一键三钮在线回归测试：失败 %d 项" % _失败.size())
		quit(1)
		return
	_印("通过（%d 条断言）" % _受检)
	quit(0)


func _停(话: String) -> void:
	printerr("一键三钮在线回归测试：中断 - " + 话)
	quit(1)


func _页根(窗: Node) -> Node:
	return 窗.get_node_or_null("遮罩/主窗口/页面容器")


## 页面里递归找「导师面板」（页面节点名各窗不同，找按钮的稳定父级）
func _找导师面板(页: Node) -> Node:
	if 页 == null:
		return null
	if 页.name == "导师面板":
		return 页
	for 子 in 页.get_children():
		var 中 := _找导师面板(子)
		if 中 != null:
			return 中
	return null


func _取钮(窗: Node, 名: String) -> Control:
	var 导师面板 := _找导师面板(_页根(窗))
	return 导师面板.get_node_or_null(名) as Control if 导师面板 != null else null


func _后端态(窗: Node) -> String:
	var 标 := 窗.get_node_or_null("遮罩/主窗口/后端状态") as Label
	return 标.text if 标 != null else ""


func _真点并查(窗: Node, 名: String) -> void:
	# 回帧会整页重建（`_render_page` 先 remove+queue_free）⇒ 每次现取，取了还要验活着
	var 钮 := _取钮(窗, 名)
	if 钮 == null or not is_instance_valid(钮):
		_查(false, "%s：页面里没有这颗钮（或已被重渲释放）" % 名)
		return
	var 心: Vector2 = 钮.get_global_rect().position + 钮.get_global_rect().size / 2.0
	var 通知前: int = _通知.size()
	var 阅历前: int = _会话.阅历
	var 面板前: int = _会话.spirit_panel.size()
	var 包前: int = _会话.spirit_bag.size()

	# 悬停过去分两跳（同 `验意志一键钮.gd`：一步瞬移不发 mouse_entered）
	for 点 in [(心 + Vector2(20.0, 20.0)) / 2.0, 心]:
		var 移 := InputEventMouseMotion.new()
		移.position = 点
		移.global_position = 点
		root.push_input(移)
		await process_frame
		await process_frame
	var 悬 := root.get_viewport().gui_get_hovered_control()
	_查(悬 == 钮, "%s：悬停归属是 %s 不是自己 ⇒ 点击会被别家吃" % [名, str(悬)])

	for 按 in [true, false]:
		var 键 := InputEventMouseButton.new()
		键.position = 心
		键.global_position = 心
		键.button_index = MOUSE_BUTTON_LEFT
		键.pressed = 按
		root.push_input(键)
		await process_frame
	for _帧 in range(90):
		await process_frame

	# ② bug 签名：修好后绝不再弹离线回执（发送真的失败了才允许——但本门在线，不许）
	var 态 := _后端态(窗)
	_查(not 态.contains("需要连接原版服务端"),
			"%s：点了还弹「%s」⇒ 请求没发出去（match 分支名与钮表对不上？）" % [名, 态])
	# ③ 可观测反馈：状态真变了，或收到服务端通知（空面板/阅历不足的实话）
	var 新通知 := _通知.slice(通知前) as Array
	var 有反馈: bool = (_会话.阅历 != 阅历前) or (_会话.spirit_panel.size() != 面板前) \
			or (_会话.spirit_bag.size() != 包前) or not 新通知.is_empty()
	_查(有反馈, "%s：零反馈——状态没变（阅历 %d→%d 面板 %d→%d 包 %d→%d）也没收到通知"
			% [名, 阅历前, _会话.阅历, 面板前, _会话.spirit_panel.size(), 包前, _会话.spirit_bag.size()])
	_印("%-6s 阅历 %d→%d 面板 %d→%d 包 %d→%d 新通知=%s 后端态=「%s」" % [
		名, 阅历前, _会话.阅历, 面板前, _会话.spirit_panel.size(), 包前, _会话.spirit_bag.size(),
		str(新通知), 态])

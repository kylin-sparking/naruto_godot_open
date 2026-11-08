extends SceneTree

## 在线用例：**从登录界面那一步开始，一路真点到进图**，钉住"建完角还要再选一次角色"这条抱怨。
##
## 用户 2026-10-10 原话：「注册完账号选完职业输入名字后点击进入游戏 应该直接进入游戏世界内
## 不应该在选择角色登陆一下 纯多余」。
##
## 和 `创角端到端回归测试.gd` 的分工：那条走的是**后端 + 创角窗**（自己实例化创角窗），
## 照不到登录界面这一层的窗口调度 —— 这次的病根恰好在那一层
## （建角回帧 jylx:17 顺手 emit 了 `character_list_received` ⇒ 登录界面把选角窗弹了出来）。
## 所以这条**只走真 UI**：注册弹窗 → 填号密 → 点「登录」→ 创角窗自己冒出 → 选格/填名 →
## 点「进入游戏」→ 断言 ①选角窗从头到尾没露过一次脸 ②`in_game` 到了 ③列表里有这个新角色。
##
## ①为什么能抓得住"只闪了一下又被关掉"：判据挂的是 `选角窗.visibility_changed` 信号，
##   不是轮询截图。`_显示选角窗()` 一置 visible=true 就立刻发信号，后面 `建好角了` 再关掉
##   也已经被记下了 —— 轮询（50ms 一拍）会漏掉同一帧内的先开后关。
##
## 跑法（要一份隔离服务端；别顶掉用户自己连的 18684）：
##   python 开发工具/本地服务端夹具.py --root .fixture-flow-ui --gm-http 18695 --port 18694
##   或  powershell -File 开发工具\跑在线用例.ps1 -用例 创角进图
## 可选：--port= --注册口= --密码= --名字=

const 出 = "res://测试/截图/创角进图在线.txt"
const 登录场景 := "res://场景/界面/登录界面.tscn"

var 行: Array[String] = []
var 红 := 0
var _b: Node
var _s: Node
var _原档 := {}
var _原设置 := {}
var _选角露过 := false


func _记(s: String) -> void:
	行.append(s)


func _判(成立: bool, 说明: String) -> void:
	if not 成立:
		红 += 1
		_记("  !! 红：" + 说明)
	else:
		_记("  ok：" + 说明)


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()


func _参(前缀: String, 默认: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(前缀):
			return str(a).substr(前缀.length())
	return 默认


func _等(谓词: Callable, 毫秒 := 12000) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if bool(谓词.call()):
			return true
		await create_timer(0.05).timeout
	return false


func _帧(n: int) -> void:
	for i in n:
		await process_frame


## 状态栏 = `登录卡片/状态文字`（`_set_status` 唯一落点）。注册成没成、登录走到哪一步，
## 玩家能看见的就是这一行字 ⇒ 用例也只看它，不去读内部变量。
func _状态文(UI: Node) -> String:
	if not is_instance_valid(UI):
		return ""
	var 条 := UI.get_node_or_null("登录卡片/状态文字") as Label
	if 条 == null:
		return ""
	return 条.text


func _状态含(UI: Node, 关键词: String) -> bool:
	return _状态文(UI).find(关键词) >= 0


func _存档快照() -> void:
	for 路 in ["user://玩家数据.json", "user://玩家设置.json"]:
		if FileAccess.file_exists(路):
			var f := FileAccess.open(路, FileAccess.READ)
			if f != null:
				_原档[路] = f.get_buffer(f.get_length())
				f.close()
		else:
			_原档[路] = PackedByteArray()


func _还原存档() -> void:
	for 路 in _原档.keys():
		var 字: PackedByteArray = _原档[路]
		var 全 := ProjectSettings.globalize_path(String(路))
		if 字.is_empty():
			if FileAccess.file_exists(String(路)):
				DirAccess.remove_absolute(全)
			continue
		var g := FileAccess.open(String(路), FileAccess.WRITE)
		if g != null:
			g.store_buffer(字)
			g.close()


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _看门狗() -> void:
	if await _等(func(): return 行.size() > 0 and str(行[行.size() - 1]).begins_with("汇"), 180000):
		return
	红 += 1
	_记("!! 看门狗：180 秒没跑到汇总（中途 script error 或某步没回帧）")
	_写()
	quit(1)


func _跑() -> void:
	_b = root.get_node_or_null("BackendConnection")
	_s = root.get_node_or_null("GameSession")
	if _b == null or _s == null:
		_记("缺单例")
		_写()
		quit(1)
		return
	_存档快照()

	var 口 := int(_参("--port=", OS.get_environment("NARUTO_SERVER_PORT")))
	# 注册口 = 夹具的 GM 控制台（原版注册本来就是网页那条，游戏 TCP 没有这一号）。
	var 注册口 := int(_参("--注册口=", OS.get_environment("NARUTO_GM_HTTP")))
	var 密 := _参("--密码=", "123456")
	var 戳 := str(int(Time.get_unix_time_from_system()) % 1000000)
	var 号 := "flow_ui_%s@example.com" % 戳
	var 名 := _参("--名字=", "流程UI%s" % 戳.substr(0, 5))
	if 口 == 0:
		口 = 18694
	if 注册口 == 0:
		注册口 = 18695

	## 登录界面把注册地址从 `game_settings.backend_url` 的 origin 推出来（`_注册地址()`），
	## 所以指到夹具的控制台口就够了，不在别处另立一份配置。
	var 设置: Dictionary = _s.get("game_settings")
	for k in ["backend_port", "backend_account", "backend_password", "backend_url"]:
		_原设置[k] = 设置.get(k, null)
	设置["backend_url"] = "http://127.0.0.1:%d/ruffle.html" % 注册口
	设置["backend_port"] = 口
	设置["backend_account"] = 号
	设置["backend_password"] = 密

	_记("== 1) 起真登录界面：在它里面注册一个全新号 %s（注册口 %d / 游戏口 %d）" % [号, 注册口, 口])
	var 包 = load(登录场景)
	_判(包 != null, "登录界面能 load")
	if 包 == null:
		收尾()
		return
	var UI: Control = (包 as PackedScene).instantiate() as Control
	root.add_child(UI)
	await _帧(8)

	var 选: Control = UI.get_node_or_null("选角窗") as Control
	_判(选 != null, "拿得到「选角窗」节点")
	if 选 != null:
		# 场景里烘的就是 visible=false（已核 `登录界面.tscn:321`）⇒ 之后任何一次 visible
		# 翻转都只可能是代码弹的，挂这个信号做"露过脸"的判据没有初始噪声。
		选.visibility_changed.connect(func(): if 选.visible: _选角露过 = true)

	var 卡: Control = UI.get_node_or_null("登录卡片") as Control
	_判(卡 != null, "拿得到「登录卡片」")
	if 卡 == null or 选 == null:
		收尾()
		return

	## 注册：点「注册账号」→ 弹窗里填三格 → 点提交（全走按钮自己的 pressed 分发）。
	(卡.get_node("注册按钮") as Button).pressed.emit()
	await _帧(3)
	_判((UI.get_node("注册弹窗") as CanvasItem).visible, "点「注册账号」把弹窗开出来了")
	var 弹: Control = UI.get_node("注册弹窗/面板") as Control
	(弹.get_node("账号输入") as LineEdit).text = 号
	(弹.get_node("密码输入") as LineEdit).text = 密
	(弹.get_node("确认输入") as LineEdit).text = 密
	(弹.get_node("提交按钮") as Button).pressed.emit()
	_判(bool(await _等(func(): return _状态含(UI, "注册成功") or _状态含(UI, "注册失败"), 10000)),
			"注册有回帧（状态栏给了结论）")
	_判(_状态含(UI, "注册成功"), "注册成功：%s" % _状态文(UI))
	if not _状态含(UI, "注册成功"):
		_记("!! 注册这一步没过 ⇒ 后面全是空谈，直接收尾")
		收尾()
		return

	## 登录：把号密填回主卡片，点「登录」。
	(卡.get_node("账号输入") as LineEdit).text = 号
	(卡.get_node("密码输入") as LineEdit).text = 密
	(卡.get_node("登录按钮") as Button).pressed.emit()
	_判(bool(await _等(func(): return bool(_b.get("authenticated")), 12000)), "登录成功（authenticated）")

	_记("== 2) 等创角窗自己冒出来（空号 → jylx:10 或 loginStatus=1，不手工实例化）")
	_判(bool(await _等(func(): return _创角窗露出(UI), 12000)), "创角窗自己开了")
	var 窗: Control = _创角窗取(UI)
	if 窗 == null:
		_记("!! 创角窗没开 ⇒ 后面没法走")
		收尾()
		return

	_记("== 3) 选格 + 填名 + 点「进入游戏」，全程盯住选角窗有没有露脸")
	窗.set("_用户输入过", true)
	(窗.get("_输入") as LineEdit).text = 名
	窗.call("_选中", 窗.get_node("窗口/职业格2"))
	var 松 := InputEventMouseButton.new()
	松.button_index = MOUSE_BUTTON_LEFT
	松.pressed = false
	窗.call("_点进入", 松)
	var 进了 := await _等(func(): return bool(_b.get("in_game")), 20000)
	_判(进了, "点完「进入游戏」直接进图（in_game）；状态=%s - %s" % [
			str(_b.get("status")), str(_b.get("detail"))])
	## 进图那一步 `change_scene_to_file` 会把登录界面整棵卸掉，之后不能再碰 UI。
	await _帧(5)
	_判(not _选角露过, "整条路上**选角窗一次都没露过脸**（露过 = 玩家还要再点一次角色）")
	_判((_b.get("characters") as Array).size() >= 1, "后端那份角色列表里确实有新建的角色")
	_记("   图号=%s　角色号=%s" % [str(_b.get("authoritative_map_id")), str(_b.get("character_id"))])
	收尾()


func _创角窗露出(UI: Node) -> bool:
	if not is_instance_valid(UI):
		return false
	var 窗 = UI.get("_创角窗")
	return 窗 != null and is_instance_valid(窗) and (窗 as CanvasItem).visible


func _创角窗取(UI: Node) -> Control:
	if not is_instance_valid(UI):
		return null
	var 窗 = UI.get("_创角窗")
	if 窗 != null and is_instance_valid(窗):
		return 窗 as Control
	return null


func 收尾() -> void:
	## 还原设置（否则用户客户端明天连到临时口）+ 还原存档（离线/在线量具都不许留笔）
	var 设置: Dictionary = _s.get("game_settings")
	for k in _原设置.keys():
		if _原设置[k] == null:
			设置.erase(k)
		else:
			设置[k] = _原设置[k]
	_还原存档()
	_记("")
	_记("汇：红 %d 项" % 红)
	_写()
	for 项 in 行:
		print(项)
	quit(0 if 红 == 0 else 1)

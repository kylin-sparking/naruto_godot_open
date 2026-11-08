extends SceneTree
## 创角端到端：**用真服务端、真协议、真窗口**跑一遍「空号 → 开窗 → 随机名 → 建角 → 进图」。
##
## 为什么单独一条：#156 的验收口径不是"窗画得像"，而是**注册完的新账号真的能进游戏**。
## 上一轮就是因为空号那条被当成"一枚空角色"塞进列表 ⇒ `select_character(0)` 直接 return ⇒
## 界面永远停在"正在读取角色"，既不报错也不提示。所以每一步都断言**服务端回帧**，不接受本地自证。
##
## 也可以走跑批：`PowerShell -File 开发工具\跑在线用例.ps1 -用例 创角端到端`
##   （那条路会带上夹具导出的 NARUTO_SERVER_PORT / NARUTO_GM_HTTP 两个环境变量。）
##
## 跑法（要一份隔离服务端，**别顶掉用户自己连的 18684**）：
##   python 开发工具/本地服务端夹具.py --root .fixture-flow --gm-http 18691 --port 18690
##   APPDATA=./_tmp/appdata-flow godot --path . --script res://开发工具/跑创角端到端.gd
##
## 默认**自己注册一个新号再打它**（`--账号=` 给了才复用旧号）：一个号只许一个角色，
## 复用旧号第二次必然撞「角色名已存在」，那道"空号 0 条"也会红 —— 那是自堵不是回归。
## 可选：--port= --注册口= --账号= --密码= --名字=

const 出 = "res://测试/截图/创角端到端.txt"

var 行: Array[String] = []
var 红 := 0
var _b: Node
var _s: Node
var _随机名帧 := ""
var _建角帧 := {}
var _列表次 := 0
var _已接次 := 0
var _注册回 := {}
var _原设置 := {}


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


## 注册 = 服务端**控制台口**的 `POST /api/account/register`（`开发工具/GM控制台服务.py:106`；
## 原版的注册从来不走游戏 TCP，走的是网页 `register.php`）。
## 这一步要在量具里真跑一遍：用户报的那条本来是"注册完的新号进不去游戏"，
## 只测建角不测注册 = 把最前面那一环留成盲区。
func _注册(口: int, 号: String, 密: String) -> Dictionary:
	_注册回 = {}
	var 求 := HTTPRequest.new()
	root.add_child(求)
	# ⚠ 回帧必须落到**成员变量**：GDScript 的 lambda 对局部量是**按值捕获**，
	#    在 `request_completed` 里写局部 `回` 写的是副本 ⇒ 外面永远看到空表
	#    （本轮实测：号确实注册成功了，量具却判"8 秒没回帧"）。
	求.request_completed.connect(
			func(_r: int, 码: int, _h: PackedStringArray, 体: PackedByteArray):
				_注册回 = {"http": 码, "body": 体.get_string_from_utf8()})
	var 错 := 求.request("http://127.0.0.1:%d/api/account/register" % 口,
			["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify({"username": 号, "password": 密}))
	if 错 != OK:
		求.queue_free()
		return {"ok": false, "error": "请求发不出去（错误 %d）" % 错}
	if not await _等(func(): return not _注册回.is_empty(), 8000):
		求.queue_free()
		return {"ok": false, "error": "8 秒没回帧"}
	求.queue_free()
	var 解 = JSON.parse_string(str(_注册回.get("body", "")))
	# `解 as Dictionary` 在解是 null/String 时会直接抛 `Invalid cast`（量具一死就什么都测不到了）
	# ⇒ 先用 `is` 判，不判死。
	if 解 is Dictionary:
		return 解
	return {"ok": false, "error": "HTTP %s 回的不是 JSON 对象，正文=%s" % [
			str(_注册回.get("http")), str(_注册回.get("body"))]}


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


## 兜底：`_跑` 里任何一条 script error 都会让它直接中断（不 return、不 quit）⇒ 进程挂着不走，
## 外面看就是"跑了 5 分钟没结果"。3 分钟内没落到汇总就按红退出，至少日志能拿到。
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
		_记("缺单例"); _写(); quit(1); return
	_存档快照()	# ← 动手前把 user:// 那两份文件按字节存下来，收尾原样写回
	# 单独跑 → 18690/18691；从 `跑在线用例.ps1` 进来 → 读夹具导出的两个环境变量
	# （`prepare_environment()` 把 `NARUTO_SERVER_PORT` 写进进程环境，`run_godot()` 原样带进 Godot）。
	var 口 := int(_参("--port=", OS.get_environment("NARUTO_SERVER_PORT")))
	var 密 := _参("--密码=", "123456")
	var 名 := _参("--名字=", "")
	# ⚠ 每次跑都**新注册一个号**：本服一个账号只许一个角色（MAX_CHARACTERS_PER_ACCOUNT=1），
	#    复用同一个号第二次就会撞「角色名已存在」，第 1 步的"空号 0 条"也必然红 —— 那不是回归，是自堵。
	var 号 := _参("--账号=", "")
	var 戳 := str(int(Time.get_unix_time_from_system()) % 1000000)
	if 号 == "":
		号 = "flow_e2e_%s@example.com" % 戳
	if 名 == "":
		名 = "流程%s" % 戳
	# 注册走的是服务端**控制台口**（原版注册本来就是网页那条，游戏 TCP 没有这一号）。
	var 注册口 := int(_参("--注册口=", OS.get_environment("NARUTO_GM_HTTP")))
	if 口 == 0:
		口 = 18690
	if 注册口 == 0:
		注册口 = 18691
	_原设置 = {}
	var 设置: Dictionary = _s.get("game_settings")
	for k in ["backend_port", "backend_account", "backend_password"]:
		_原设置[k] = 设置.get(k, null)
	设置["backend_port"] = 口
	设置["backend_account"] = 号
	设置["backend_password"] = 密
	_b.char_name_generated.connect(func(n: String): _随机名帧 = n)
	_b.character_created.connect(func(c: Dictionary): _建角帧 = c)
	_b.character_list_received.connect(func(_a: Array, _m: int): _列表次 += 1)

	_记("== 0) 注册一个全新的号 %s（控制台口 %d）" % [号, 注册口])
	var 注 = await _注册(注册口, 号, 密)
	var 账 = 注.get("account", {})
	_判(bool(注.get("ok", false)), "注册回 ok=true（账号 id=%s）；实际回帧 %s" % [
			str(账.get("id", "?")) if 账 is Dictionary else "?", str(注)])

	_记("== 1) 登录空号 %s @%d" % [号, 口])
	_b.call("connect_backend", 号, 密, false)
	if not await _等(func(): return bool(_b.get("authenticated"))):
		_记("  !! 没登上：" + str(_b.get("status")) + " - " + str(_b.get("detail")))
		_写(); quit(1); return
	await create_timer(1.5).timeout
	_记("   状态=%s 角色数=%d" % [str(_b.get("status")), (_b.get("characters") as Array).size()])
	_判((_b.get("characters") as Array).size() == 0, "空号的角色列表必须是 0 条（以前把 `jylx:10 maxChars` 当成一枚空角色塞进去）")
	_判(str(_b.get("status")) == "需要创建角色", "空号状态要落到「需要创建角色」")

	_记("== 2) 开原版那扇创建角色窗")
	var 场景路 := "res://场景/界面/窗口/创建角色/创建角色窗.tscn"
	var 包 = load(场景路)
	_判(包 != null, "创角窗场景能 load")
	if 包 == null:
		_写(); quit(1); return
	var 窗: Control = 包.instantiate() as Control
	_判(窗 != null, "创角窗能实例化")
	if 窗 == null:
		_写(); quit(1); return
	root.add_child(窗)
	await _帧(8)
	var 内: Node = 窗.get_node("窗口")
	_判(内.get_child_count() == 12, "窗内 12 件（窗口底/标题/面板底/四格/名标签/输入框/随机钮/进入游戏/转圈）——输入框自己挂原版皮，没有第二块底，实际 %d" % 内.get_child_count())
	_判(str(窗.get("_当前").get("job", 0)) != "0" and not (窗.get("_当前") as Dictionary).is_empty(),
			"开窗就自动随机选好了一格（原版 ADDED_TO_STAGE → randomChar）")

	_记("== 3) 随机名（op 1028 → jylx 1028）")
	_随机名帧 = ""
	窗.call("_点随机")
	if await _等(func(): return not _随机名帧.is_empty(), 8000):
		_判(_随机名帧.length() >= 2, "服务端回了随机名：%s（%d 字）" % [_随机名帧, _随机名帧.length()])
		_判(str(窗.get("_输入").text) == _随机名帧, "随机名落进了输入框")
	else:
		_判(false, "8 秒没收到 jylx:1028 的随机名")

	_记("== 4) 建角（op 17 → jylx 17）")
	# 名字直接写进输入框（原版 setName 之后 _userInput 仍为假，点格子会再换名 ⇒ 先钉住）
	窗.set("_用户输入过", true)
	(窗.get("_输入") as LineEdit).text = 名
	窗.call("_选中", 内.get_node("职业格2"))
	# **发包前**把窗口要寄出去的那对值抄下来 —— 服务端会按自己的 look 编码重写 gender，
	# 所以只看回帧分不清"客户端发错了"还是"服务端换了编码"（本轮就撞过一次：回 1 判 2 红）。
	var 寄出: Dictionary = (窗.get("_当前") as Dictionary).duplicate(true)
	_建角帧 = {}
	## 走**真点击**：`_点进入` 收的是 `InputEventMouseButton`，松开那一拍才做校验 + 发包。
	var 松 := InputEventMouseButton.new()
	松.button_index = MOUSE_BUTTON_LEFT
	松.pressed = false
	窗.call("_点进入", 松)
	_判(int(寄出.get("job", 0)) == 200 and int(寄出.get("gender", 0)) == 2,
			"寄出去的 = 水 200 / 女 2（原版 `CreateCharWindow3.as:28-30` MAIL=1 FAMAIL=2、"
			+ "`:259-260` WATER=200+FAMAIL），实际 job=%s gender=%s" % [
			str(寄出.get("job")), str(寄出.get("gender"))])
	if await _等(func(): return not _建角帧.is_empty(), 10000):
		_判(str(_建角帧.get("name", "")) == 名, "服务端回的角色名 = %s（实际 %s）" % [名, str(_建角帧.get("name", ""))])
		_判(int(_建角帧.get("job", 0)) == 200, "职业 = 水 200（点的是格2），实际 %s" % str(_建角帧.get("job")))
		# 本服的存档编码是 look 那一套（0=男 / 1=女，`multiplayer_backend.py:447` 由 job 推：
		# `1 if job in (200,400) else 0`）⇒ 200 应当回 **1**。这里钉的是"两层编码各自对得上自己那份真值"，
		# 不是"客户端发什么服务端就原样回什么"。
		_判(int(_建角帧.get("gender", 0)) == (1 if int(_建角帧.get("job", 0)) in [200, 400] else 0),
				"服务端回的性别按本服 look 编码（女=1）= %s，实际 %s" % [
				str(1 if int(_建角帧.get("job", 0)) in [200, 400] else 0), str(_建角帧.get("gender"))])
	else:
		_判(false, "10 秒没收到 jylx:17 ⇒ 建角没成（看 _点进入 的校验是不是把名字判死了）")

	_记("== 5) 选角 → 入口票(jylx 11) → 进图(op 11)")
	if not await _等(func(): return bool(_b.get("in_game")), 15000):
		_判(false, "建角后没进游戏：状态=%s - %s" % [str(_b.get("status")), str(_b.get("detail"))])
	else:
		_判(true, "进图成功，图号=%s 角色号=%s" % [str(_b.get("authoritative_map_id")), str(_b.get("character_id"))])
	# ⚠ 归位：这三条是**存档里的**设置（`游戏会话` 会写 user://玩家数据.json），
	#    量具把它们改道到隔离夹具就不还回去 ⇒ 用户第二天开的客户端会连到 18690 上，
	#    次日满屏"连不上服务端"的假红（工程老规矩：离线量具不许落存档）。
	var 还: Dictionary = _s.get("game_settings")
	for k in _原设置.keys():
		if _原设置[k] == null:
			还.erase(k)
		else:
			还[k] = _原设置[k]
	var 干净 := true
	for k in ["backend_port", "backend_account", "backend_password"]:
		if _原设置[k] == null:
			干净 = 干净 and not 还.has(k)
		else:
			干净 = 干净 and 还[k] == _原设置[k]
	_判(干净, "三条 game_settings 已原样还回（不许把探测端口留在存档里）")
	_还原存档()

	_记("")
	_记("汇：红 %d 条" % 红)
	_写()
	if _b != null:
		_b.call("disconnect_backend")
	await create_timer(0.3).timeout
	quit(0 if 红 == 0 else 1)


## ⚠ 整份存档级还原（2026-10-10 补，起因是真的把邻居门弄红了）。
## 两份工程同名 ⇒ **共用同一个 `user://` 目录**，而这个量具是**注册一个新小号再登录**：
## 登录成功那一刻 `游戏会话` 会把整份 `玩家数据.json` 换成这个小号的（背包、任务、页签全换），
## 于是隔壁 `格子悬停提示回归测试` 第二天报「背包里找不到有物品的格子」。
## 只还原三条 `game_settings` 挡不住这种覆盖，所以动手前先把**文件字节**存下来，收尾逐字节写回并断言。
## 动手前 `user://` 里那两份文件的**原始字节**（路 → PackedByteArray）。
var _原档 := {}


func _存档快照() -> void:
	for 路 in ["user://玩家数据.json", "user://launcher.json"]:
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
			## 动手前就没有这个文件（全新机器）⇒ 本量具造出来的那份要删掉，别留下。
			if FileAccess.file_exists(路):
				DirAccess.remove_absolute(全)
			_判(not FileAccess.file_exists(路), "%s 动手前不存在，收尾应删掉" % 路)
			continue
		var g := FileAccess.open(String(路), FileAccess.WRITE)
		if g == null:
			_判(false, "%s 打不开写句柄，还原不了" % 路)
			continue
		g.store_buffer(字)
		g.close()
		var 读回 := _读字节(String(路))
		_判(读回 == 字, "%s 没还原成动手前那份（%d 字节 vs %d 字节）" % [路, 读回.size(), 字.size()])


func _读字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var f := FileAccess.open(路, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var 字 := f.get_buffer(f.get_length())
	f.close()
	return 字


func _帧(n: int) -> void:
	for i in n:
		await process_frame

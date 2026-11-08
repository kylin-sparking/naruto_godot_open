extends SceneTree

## 修行收益（原版「修行设定与收益」/「领取修行收益」）协议回归。
##
## 包形按**原版 AS3**（2026-10-20 客户端与服务端一起对齐到这一形，不再吃 10/11 方言）：
##   `AllInOneProcessor.as:3271-3276` 查询 = `byte 2`                    ⇒ 文本形 `1284:2`
##   `AllInOneProcessor.as:4272-4278` 领取 = `byte 1` + `byte(双倍?1:0)` ⇒ `1284:1:0` / `1284:1:1`
##   `AllInOneProcessor.as:3882-3889` 答随机问 = `byte 3` + `int`
##   下行 `1286 BIGUAN_INFO` = 四 int（seconds/expGain/zqGain/problem，`:1899-1922`）
## 对应服务端 `fake_flash_server.py:17946 handle_biguan`、`:18022 _send_biguan_info`、
## 收益口径 `:18004 _calculate_biguan_rewards`：
##   经验 = 分钟 × 等级 × BIGUAN_EXPERIENCE_PER_LEVEL_MINUTE(50)
##   精华 = 分钟 × 等级 ÷ BIGUAN_CHAKRA_LEVEL_MINUTE_DIVISOR(10)，至少 1
##   上限 BIGUAN_MAX_SECONDS = 12 小时
##
## ⚠ 为什么这一条要**真等 65 秒**：收益是从「服务端记的起点」按墙上钟累积的
## （`_current_biguan_seconds` = 存档 seconds + (now − biguan_updated_at)）。不先铺累积就直接领，
## `seconds` 本来就是 0 ⇒「领完归零」量出来是 **0 比 0**、「经验 = 分钟×等级×50」也是 **0 比 0** ——
## 两条判据都恒真，包形改回 10/11 也不会红。所以顺序钉死：
## 归零 ⇒ 等到真累积过 1 分钟（阳性对照）⇒ 判算式 ⇒ 判单倍把计时归零 ⇒ 判双倍那一字节。
##
## 存档纪律：本腿会登录临时号、并把 `backend_port` 写进 `game_settings` ⇒ 开局按字节快照两份
## user:// 文件，收口**先把内存里那套换回快照、再按字节写盘**（只还原文件不够：`quit()` 前任何
## 一处 `_save_local_state()` 都会把临时值再写回去 —— 10-19 挂机腿实测）。
##
## 跑法（要夹具服务端；端口经 `NARUTO_SERVER_PORT` 传给本进程）：
##   powershell -File 开发工具/跑在线用例.ps1 -用例 修行收益

const 每级每分钟经验 := 50
const 每级每分钟精华除数 := 10
const 上限秒数 := 12 * 60 * 60
const 累积等待秒 := 65.0
## 这条腿一趟该判满多少条 —— 协程被中途打断时，末行只数得出「跑了多少条」，
## 不钉这个数就没法区分「全过」和「后面几段压根没执行」。
const 判满条数 := 17
## 服务端「要双倍但背包没密卷」那一支的原话（`fake_flash_server.py:18056`）。
## 这条提示**只有** `action==1` 且第二字节 ==1 才会发 ⇒ 拿它当「第二字节真被读到」的证据。
const 没卷提示 := "Cultivation scroll not found"
const 存档路 := "user://玩家数据.json"
const 设置路 := "user://玩家设置.json"
## 归零那一发不封装成方法（原版没有 `action 0`，这是本地服务端的夹具档），所以 opcode 直接从
## 脚本常量里取 —— 别在 `Node` 类型的实例上摸常量（摸不到，`get()` 回 null ⇒ `int(null)` 当场崩）。
const 后端脚本 := preload("res://脚本/单例/后端连接.gd")

var _失败: Array[String] = []
var _判数 := 0
var _收到: Array = []
var _聊天: Array[String] = []
var _存档前 := {}
var _跑过 := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_存档前 = _快照()
	var backend := root.get_node_or_null("BackendConnection")
	var session := root.get_node_or_null("GameSession")
	if backend == null or session == null:
		_结束("缺 BackendConnection / GameSession 单例")
		return

	## 客户端连哪个口**只认** `game_settings.backend_port`（`后端连接.gd:705`），环境变量它不读
	## ⇒ 夹具起的是临时口时这一键必须本腿自己写（旧坑：拿默认 18684 去连 = 连到用户自己那台）。
	var 设置: Dictionary = session.get("game_settings")
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 > 0:
		设置["backend_port"] = 口
	print("修行收益在线腿：连夹具端口 %s" % str(口 if 口 > 0 else int(设置.get("backend_port", -1))))

	backend.biguan_info_received.connect(func(seconds: int, exp_gain: int, zq_gain: int):
		_收到.append({"seconds": seconds, "exp": exp_gain, "zq": zq_gain}))
	backend.chat_received.connect(func(message: Dictionary):
		_聊天.append(String(message.get("message", ""))))

	backend.sync_character()
	if not await _等到(func(): return backend.in_game, 10000):
		_结束("未能进入原版后端游戏会话：%s - %s" % [backend.status, backend.detail])
		return

	var 等级 := int(session.get("player_stats").get("level", 1))
	_判(等级 >= 1, "等级应 >= 1，实际 %d" % 等级)

	# ---- 归零（`1284:0` 是本地服务端的夹具档，原版没有这一档）----
	_收到.clear()
	_判(backend.send_game_request(后端脚本.OP_BIGUAN, "0"), "归零请求应发出")
	if not await _等到(func(): return not _收到.is_empty(), 8000):
		_结束("发 1284:0 后没有收到 1286 BIGUAN_INFO 帧")
		return
	_判(int(_收到[-1].seconds) <= 1, "归零后 seconds 应为 0，实际 %d" % int(_收到[-1].seconds))

	# ---- 阳性对照：让服务端真累积过 1 分钟，否则下面几条全是「0 比 0」----
	await create_timer(累积等待秒).timeout
	_收到.clear()
	_判(backend.request_biguan_query(), "查询请求应发出")
	if not await _等到(func(): return not _收到.is_empty(), 8000):
		_结束("发 1284:2 后没有收到 1286 BIGUAN_INFO 帧")
		return
	var 信息: Dictionary = _收到[-1]
	var 秒 := int(信息.seconds)
	_判(秒 >= 60 and 秒 <= 上限秒数,
		"等了 %d 秒，seconds 应已累积过 1 分钟（这一步不过 ⇒ 后面算式/归零都是 0 比 0），实际 %d"
			% [int(累积等待秒), 秒])

	# ---- 收益口径应与服务端公式一致 ----
	var 分钟 := 秒 / 60
	var 期望经验 := 分钟 * 等级 * 每级每分钟经验
	var 期望精华 := 0 if 分钟 <= 0 else maxi(1, 分钟 * 等级 / 每级每分钟精华除数)
	_判(分钟 >= 1, "样本应至少累积 1 分钟，实际 %d 分钟（不足 ⇒ 算式判据没判到东西）" % 分钟)
	_判(int(信息.exp) == 期望经验,
		"经验应 = 分钟%d × 等级%d × %d = %d，实际 %d" % [分钟, 等级, 每级每分钟经验, 期望经验, int(信息.exp)])
	_判(int(信息.zq) == 期望精华,
		"精华应 = 分钟%d × 等级%d ÷ %d = %d，实际 %d" % [分钟, 等级, 每级每分钟精华除数, 期望精华, int(信息.zq)])

	# ---- 单倍领取 `1284:1:0`：服务端必须真走领取那一支（把计时归零）----
	_收到.clear()
	_聊天.clear()
	_判(backend.request_biguan_claim(false), "单倍领取请求应发出")
	if not await _等到(func(): return not _收到.is_empty(), 8000):
		_结束("发 1284:1:0 后没有收到 1286 帧 ⇒ 服务端没把这一发包当领取（包形又退回方言了？）")
		return
	_判(int(_收到[-1].seconds) <= 1,
		"单倍领取后 seconds 应归零（服务端 `_claim_biguan_rewards` 重置计时），实际 %d" % int(_收到[-1].seconds))
	## 服务端发提示的顺序在回 1286 之前（`:18055` 早于 `:18061`），隔 0.3 秒再收这条负判据，
	## 免得把「提示还在路上」读成「第二字节没读到」。
	await create_timer(0.3).timeout
	_判(not _有那条双倍提示(),
		"单倍那一发（第二字节 0）不该进双倍分支 ⇒ 不该收到「%s」，实际聊天 %s" % [没卷提示, str(_聊天)])

	# ---- 双倍领取 `1284:1:1`：第二字节要真被读成「双倍」----
	await create_timer(2.0).timeout			# 服务端同文提示 1.5 秒去重，隔开发出
	_收到.clear()
	_聊天.clear()
	_判(backend.request_biguan_claim(true), "双倍领取请求应发出")
	if not await _等到(func(): return not _收到.is_empty(), 8000):
		_结束("发 1284:1:1 后没有收到 1286 帧")
		return
	_判(await _等到(func(): return _有那条双倍提示(), 8000),
		"双倍那一发没让服务端进 `use_double` 分支 ⇒ 第二字节没送到/没被读（聊天 %s）" % str(_聊天))

	# ---- 再查一次，确认状态是服务端在维护、不是客户端自算 ----
	_收到.clear()
	_判(backend.request_biguan_query(), "二次查询应发出")
	if not await _等到(func(): return not _收到.is_empty(), 8000):
		_结束("二次查询没有回帧")
		return
	var 二次: Dictionary = _收到[-1]
	_判(int(二次.exp) < 期望经验,
		"领完再查，可领经验应已回落（领之前 %d，现在 %d）" % [期望经验, int(二次.exp)])

	# ---- 会话里应能读到这份状态 ----
	var 状态: Dictionary = session.call("修行收益状态")
	_判(not 状态.is_empty(), "游戏会话里应存有「修行收益」状态")
	_判(状态.has("seconds") and 状态.has("exp_gain") and 状态.has("zq_gain"),
		"状态应包含 seconds/exp_gain/zq_gain，实际键 %s" % str(状态.keys()))

	_结束("")

func _有那条双倍提示() -> bool:
	for 条 in _聊天:
		if String(条).find(没卷提示) >= 0:
			return true
	return false

func _判(条件: bool, 说明: String) -> void:
	_判数 += 1
	if not 条件:
		_失败.append(说明)

func _等到(条件: Callable, 超时毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 超时毫秒
	while Time.get_ticks_msec() < 截止:
		if 条件.call():
			return true
		await create_timer(0.05).timeout
	return 条件.call()

func _快照() -> Dictionary:
	## 一份文件一段原字节；不存在 ⇒ 空字节，还原时**删掉**本腿新建的那份。
	var 出 := {}
	for 路 in [存档路, 设置路]:
		出[路] = FileAccess.get_file_as_bytes(路) if FileAccess.file_exists(路) else PackedByteArray()
	return 出

func _结束(硬失败: String) -> void:
	if _跑过:
		return
	_跑过 = true
	if 硬失败 != "":
		_判(false, 硬失败)
	## ① 内存里那套 game_settings 先换回快照那份（顺序要紧，见文件头）
	var 会 = root.get_node_or_null("GameSession")
	if 会 != null:
		var 原字节: PackedByteArray = _存档前.get(存档路, PackedByteArray())
		if not 原字节.is_empty():
			var 解 = JSON.parse_string(原字节.get_string_from_utf8())
			if 解 is Dictionary and (解 as Dictionary).has("game_settings"):
				var 旧: Dictionary = (解 as Dictionary)["game_settings"]
				var 设置: Dictionary = 会.get("game_settings")
				设置.clear()
				for 键名 in 旧:
					设置[键名] = 旧[键名]
	## ② 两份 user:// 文件按字节还原（本腿新建的那份直接删）
	for 路 in _存档前:
		var 字节: PackedByteArray = _存档前[路]
		if 字节.is_empty():
			if FileAccess.file_exists(路):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(路))
			continue
		var f := FileAccess.open(路, FileAccess.WRITE)
		if f != null:
			f.store_buffer(字节)
			f.close()
	## ③ 条数门：走完全程却只判到一半 ⇒ 有段落被跳过，不许当成通过
	if 硬失败 == "" and _判数 != 判满条数:
		_失败.append("只判到 %d 条，本腿应当判满 %d 条 ⇒ 有段落被跳过（这条别当通过）" % [_判数, 判满条数])
	if _失败.is_empty():
		print("修行收益协议回归测试：通过（%d 条判据，未判 0 条）" % _判数)
		quit(0)
		return
	for 条 in _失败:
		print("红：" + 条)
	print("修行收益协议回归测试：%d 条判据，红 %d 条（跑完的段才计数 ⇒ 条数不足就是中途死了）" % [_判数, _失败.size()])
	quit(1)

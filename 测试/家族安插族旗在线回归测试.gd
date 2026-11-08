extends SceneTree
## 家族族旗「安插」真机回归（在线，需要夹具 `--main-family`）。
##
## 为什么必须有这条门：族旗安插一直是"点了没反应"，而它在离线环境里
## **根本验不出来** —— 三个条件里有两个只有真服务端才知道：
##   ① 你必须**是族长**：`fake_flash_server.handle_map_flag_action` 第一句就是
##      `if int(family["leaderAccountId"]) != int(self.account_id): 提示「只有族长可以操作族旗。」`
##      ⇒ 夹具必须用 `--main-family` 让主角色自己当族长（同伴那个族再大也没用）；
##   ② 目标图必须是 13 张领域战图之一（`map_id in self.MAP_FLAG_LOCATIONS`），且**当前没有族旗**；
##   ③ 本族已安插总数 < 10（`len(maps) >= 10` ⇒ 「本族可安插的族旗已达上限。」）。
##
## ⚠️ 还要钉住"客户端别再自己加锁"：原版那道 `myFlagCount < MAX_INSERT_FLAGS`
##    （`FFW:383`）里的 `myFlagCount` **只来自服务端推送** `onBanghuiUpdatePlugFlagCnt`
##    （`Client.as:7792-7795`），本机服务端从不发 ⇒ 恒为 0 ⇒ 在原版里也不触发。
##    我们曾经拿"族旗表里本族占了几面"顶替它，只要本族有 1 面旗就把下一次安插拦死 ——
##    那才是"旗帜还是无法安插"的直接原因。本门第 ④ 步之后会**再安插一次**（换一张空图）
##    就是为了钉死"本族已有族旗时仍然允许安插"。
##
## 用法（走跑批脚本；夹具给独立端口 18714/18715，**绝不顶用户那台 18684**）：
##   powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 家族安插族旗
##   夹具额外参数：`--main-family`（主角自己当族长，见 `开发工具/本地服务端夹具.py`）
##
## ⚠️ 存档根两个都在工程内（gitignore）：玩档 `.fixture-play`（启动游戏.bat 用，**不带 reset**）、
##    门禁 `.fixture`（跑批用，每条 `--reset`）。别往工程根丢临时存档（用户 2026-10-09 提过）。

const 壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 填充 := preload("res://脚本/界面/窗口/家族/家族旗帜填充.gd")
const 地图实体脚本 := preload("res://脚本/地图/地图实体.gd")

var _失败: Array[String] = []
var _宿主: Node
var _后端: Node
var _会话: Node
var _页: Control
var _通知: Array[String] = []
## 跑前 `game_settings.backend_port` 的原值（收尾还原，见 §3.183 的教训）。
var _原端口 := -1


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 家族id := int(OS.get_environment("NW_MAIN_FAMILY_ID"))
	if 家族id <= 0:
		_失败.append("夹具没给主角家族（NW_MAIN_FAMILY_ID=0）—— 跑这条门要加 --main-family")
		_收尾()
		return
	_会话 = root.get_node_or_null("GameSession")
	_后端 = root.get_node_or_null("BackendConnection")
	if _会话 == null or _后端 == null:
		_失败.append("缺 GameSession / BackendConnection")
		_收尾()
		return
	## ⚠ 客户端只认 `game_settings.backend_port`、**不读环境变量**（`后端连接.gd` 默认 18684）。
	##   不写这一键时，夹具给独立端口也没用 —— 用例会静默连到 18684 上用户自己那台，
	##   开着的时候就是拿用例点用户的真角色（§3.183 实测踩过）。缺环境变量就**直接红**，
	##   绝不回落 18684。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 <= 0:
		_失败.append("夹具没给 NARUTO_SERVER_PORT（这条门只能由 跑在线用例.ps1 起，绝不默认连 18684）")
		_收尾()
		return
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_会话.notification_requested.connect(func(文本: String) -> void: _通知.append(文本))
	_宿主 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(_宿主)
	await create_timer(0.25).timeout

	_后端.sync_character()
	if not await _等待(func(): return bool(_后端.in_game), 15000):
		_失败.append("主角色进不了真实后端：%s - %s" % [_后端.status, _后端.detail])
		_收尾()
		return
	if not await _等待(func(): return bool((_会话.guild as Dictionary).get("joined", false)), 8000):
		_失败.append("主角家族没同步进会话（guild=%s）" % [_会话.guild])
		_收尾()
		return
	# ── ① 「是族长」这条判据必须是**角色 id**（原版 `FM.as:455-462`）────────────
	# ⚠️ "我的角色 id"在 `BackendConnection.character_id`，**不在 `player_stats`**（那里没有 `id` 键）
	#    —— 取错地方会让"是管理"恒为假、安插钮恒灰。
	var 族长id := int((_会话.guild as Dictionary).get("leader_id", 0))
	var 自己id := int(_后端.get("character_id"))
	if 族长id <= 0:
		_失败.append("家族摘要里没有族长角色 id（`1552:15` 的 fields[6] 没解析到）")
	elif 自己id <= 0:
		_失败.append("`BackendConnection.character_id` 是 0，取不到自己的角色 id")
	elif 族长id != 自己id:
		_失败.append("家族族长 id(%d) 与当前角色 id(%d) 不一致；夹具 --main-family 没生效？"
			% [族长id, 自己id])

	# ── ② 开旗帜窗（走真实动作：先说明窗 → 进入旗帜）─────────────────────────
	_宿主.call("open_page", "家族")
	await create_timer(0.25).timeout
	_宿主.call("_show_guild_action", "家族旗帜")
	await create_timer(0.35).timeout
	if 壳.已开(_宿主, "家族旗帜帮助窗"):
		_宿主.call("_show_guild_action", "家族旗帜帮助窗:进入旗帜")
		await create_timer(0.35).timeout
	if not 壳.已开(_宿主, "家族旗帜窗"):
		_失败.append("旗帜窗没开出来")
		_收尾()
		return
	_页 = 壳.取内容(_宿主, "家族旗帜窗")
	if _页 == null:
		_失败.append("旗帜窗内容页取不到")
		_收尾()
		return

	# ── ③ 族旗表（`1815:0`）到齐：**13 行**（按 flagmap 铺，含空点）──────────
	# ⚠️ 条件写成具名方法、不写成跨行 lambda：跨行 lambda 当实参时缩进规则很容易踩空
	#    （这个工程里已经因此解析失败过好几次）。
	if not await _等待(_表到齐, 8000):
		_失败.append("没等到 13 行族旗表（现有 %d 行）" % (_后端.get("authoritative_flag_list") as Array).size())
		_收尾()
		return
	var 行 := 行们()
	if 行.size() != 13:
		_失败.append("列表铺了 %d 行，应为 13 行（`FFW.getFlags` 按 flagmap 铺）" % 行.size())
	# 新夹具里本族一面旗都没有 ⇒ 13 行必须全是空点。
	# ⭐ 优先选**当前地图**：这条门后面还要验"地图上真的立出那面旗"（离线门抓不到），
	#    换图能不换就不换。夹具新建的角色出生在终结谷浅滩 101010000，本身就是 13 张之一。
	var 当前图 := int(_后端.get("authoritative_map_id"))
	var 空行 := _本图空点(当前图)
	if 空行 == null:
		空行 = _第一个空点()
		if 空行 == null:
			_失败.append("13 行里一个空点都没有（本族已占满？）")
			_收尾()
			return
		var 换到 := int(空行.get_meta("map_id", 0))
		# 真门换图：`request_map_change` 按本图 portal 表反查门号，发的是 `33:2:-1:<门号>`，
		# 与玩家自己走到门口点门同一条服务端路径（不是给客户端塞假状态）。
		if not bool(_后端.call("request_map_change", 换到, 0, 0)):
			_失败.append("本图 %d 的 portal 表里没有通往 %d 的门；这条门要求角色出生在领域战图上"
				% [当前图, 换到])
			_收尾()
			return
		if not await _等待(func(): return int(_后端.get("authoritative_map_id")) == 换到, 15000):
			_失败.append("请求去 %d 后 15 秒 authoritative_map_id 还是 %s"
				% [换到, _后端.get("authoritative_map_id")])
			_收尾()
			return
		if not await _等待(_会话图是.bind(换到), 8000):
			_失败.append("服务端换到 %d 后 8 秒会话 current_map_id 还是 %s（换图帧没进会话）"
				% [换到, _会话.get("current_map_id")])
			_收尾()
			return
		当前图 = 换到
	var 目标图 := int(空行.get_meta("map_id", 0))

	# ── ④ 点行 → 安插钮必须可点 → 走确认弹 → 发 `1815:1` ────────────────────
	_点行(空行)
	await create_timer(0.15).timeout
	var 插 := _页.get_node_or_null("钮安插本族旗帜") as TextureButton
	if 插 == null:
		_失败.append("取不到「钮安插本族旗帜」")
		_收尾()
		return
	if 插.disabled:
		_失败.append("选中空点后「安插本族旗帜」还是灰的 ｜ %s"
			% 填充.按钮态说明(_页, _宿主))
		_收尾()
		return
	插.pressed.emit()
	await create_timer(0.25).timeout
	var 弹 := 壳.取内容(_宿主, "家族确认弹")
	if 弹 == null:
		_失败.append("点安插没有弹确认弹")
		_收尾()
		return
	var 确定 := 弹.get_node_or_null("钮确定") as TextureButton
	if 确定 == null:
		_失败.append("确认弹里没有「钮确定」")
		_收尾()
		return
	确定.pressed.emit()

	# ── ⑤ 服务端真的把那面旗安上了 ──────────────────────────────────────────
	if not await _等待(func(): return _本族在图(目标图), 8000):
		_失败.append("确认后服务端没把族旗安到图 %d 上（族旗表=%s，通知=%s）"
			% [目标图, _后端.get("authoritative_flag_list"), _通知])
		_收尾()
		return
	print("  安插成功：图 %d 现在归本族（id=%d）" % [目标图, 家族id])

	# ── ⑤b **地图上真的立出这面旗**（离线门抓不到的那一层）────────────────────
	# 为什么必须在线：旗节点是 `地图实体._刷新族旗` 按 `1815` 的族旗行建的；用户 10-11 实机报
	# "日志说建了旗、visible=true，画面里什么都没有" —— 根因是 `z_index` 没设（=0）被地面盖住。
	# 这里把真地图实体建出来，钉住：节点在 / 可见 / 落点=服务端坐标 / z=_角色层次(pos) 且非 0。
	if 目标图 != int(_后端.get("authoritative_map_id")):
		_失败.append("安插后不在目标图 %d 上（当前 %s），地图节点这一层没量到"
			% [目标图, _后端.get("authoritative_map_id")])
	else:
		if not await _等待(_会话图是.bind(目标图), 8000):
			_失败.append("会话 current_map_id 还停在 %s，地图实体不会按 %d 立旗"
				% [_会话.get("current_map_id"), 目标图])
		else:
			var 地图 := (地图实体脚本.new()) as Node2D
			地图.name = "族旗验证地图"
			root.add_child(地图)
			if not await _等待(_地图有旗.bind(地图), 8000):
				_失败.append("地图实体没立出「族旗」节点（本图=%d，表行=%s）—— 看 user://族旗诊断.txt 末几行"
					% [目标图, str(_按图取行(目标图))])
			else:
				var 旗 := _地图族旗(地图)
				var 行0 := _按图取行(目标图)
				var 预期位置 := Vector2(float(行0.get("x", 0)), float(行0.get("y", 0)))
				var 预期z := int(地图.call("_角色层次", 旗.position))
				if not 旗.is_visible_in_tree():
					_失败.append("族旗节点建出来了但不在可见树里（节点或祖先被隐藏）")
				if 旗.position != 预期位置:
					_失败.append("族旗落点 %s ≠ 服务端族旗行里的 %s" % [str(旗.position), str(预期位置)])
				if 旗.z_index == 0:
					_失败.append("族旗 z_index=0 ⇒ 会被地面/街道物件整个盖住（用户 10-11 实机症状）")
				elif 旗.z_index != 预期z:
					_失败.append("族旗 z_index=%d ≠ _角色层次(pos)=%d" % [旗.z_index, 预期z])
				else:
					print("  地图上立旗：位置 %s，z=%d，可见=%s"
						% [str(旗.position), 旗.z_index, str(旗.is_visible_in_tree())])
			地图.queue_free()
			await process_frame

	# ── ⑥ **本族已经有旗了，再安插一面别的空图仍须放行** ────────────────────
	# 这一条专门钉"客户端别拿'本族已有几面旗'去顶替 `myFlagCount`"那个错。
	var 另一个空点 := _第一个空点()
	if 另一个空点 == null:
		_失败.append("第二面旗时没有别的空点可测（夹具状态不对）")
		_收尾()
		return
	var 第二图 := int(另一个空点.get_meta("map_id", 0))
	_点行(另一个空点)
	await create_timer(0.15).timeout
	if 插.disabled:
		_失败.append("本族已有 1 面旗后，第二面被客户端拦住了（`myFlagCount` 那条不能自己数族旗表）")
		_收尾()
		return
	插.pressed.emit()
	await create_timer(0.25).timeout
	var 弹2 := 壳.取内容(_宿主, "家族确认弹")
	if 弹2 == null:
		_失败.append("第二面旗点安插没有弹确认弹")
		_收尾()
		return
	var 确定2 := 弹2.get_node_or_null("钮确定") as TextureButton
	if 确定2 == null:
		_失败.append("第二面旗的确认弹里没有「钮确定」")
		_收尾()
		return
	确定2.pressed.emit()
	if not await _等待(func(): return _本族在图(第二图), 8000):
		_失败.append("第二面旗没安上（图 %d；通知=%s）" % [第二图, _通知])
		_收尾()
		return
	print("  第二面也安上了：图 %d" % 第二图)

	_收尾()


## 族旗表（`1815:0`）到齐 = 13 行。
func _表到齐() -> bool:
	var 表: Variant = _后端.get("authoritative_flag_list")
	if 表 == null or not (表 is Array):
		return false
	return (表 as Array).size() >= 13


## 列表里当前渲染出来的行（挂在 `列表/内容列` 下）。
func 行们() -> Array:
	var 列 := _页.get_node_or_null("列表/内容列")
	if 列 == null:
		return []
	var 出: Array = []
	for 子 in 列.get_children():
		出.append(子)
	return 出


## 第一个「空点」行：服务端族旗表里没有它，也没被本族占。
func _第一个空点() -> Control:
	var 表: Array = _后端.get("authoritative_flag_list") as Array
	var 占着 := {}
	for 行数据 in 表:
		占着[int((行数据 as Dictionary).get("map_id", 0))] = int((行数据 as Dictionary).get("bang_id", 0))
	for 行 in 行们():
		var 图 := int((行 as Control).get_meta("map_id", 0))
		if int(占着.get(图, 0)) == 0:
			return 行 as Control
	return null


## 当前地图上的那个空点（本图正好是领域战图时优先它，见 ③b 的说明）。
func _本图空点(图: int) -> Control:
	for 行 in 行们():
		if int((行 as Control).get_meta("map_id", 0)) == 图 and _是空点(行 as Control):
			return 行 as Control
	return null


## 这一行在服务端族旗表里是不是空点（bang_id=0；没旗的图也有一行）。
func _是空点(行: Control) -> bool:
	var 图 := int(行.get_meta("map_id", 0))
	for 行数据 in (_后端.get("authoritative_flag_list") as Array):
		var 记 := 行数据 as Dictionary
		if int(记.get("map_id", 0)) == 图:
			return int(记.get("bang_id", 0)) == 0
	return false


## 服务端族旗表里那一图的行（12 字段，`_解族旗行` 的口径）。
func _按图取行(map_id: int) -> Dictionary:
	for 行数据 in (_后端.get("authoritative_flag_list") as Array):
		var 记 := 行数据 as Dictionary
		if int(记.get("map_id", 0)) == map_id:
			return 记
	return {}


## 会话当前地图 = `图`（地图实体的 `_get_current_map_id()` 读的就是它）。
func _会话图是(图: int) -> bool:
	return str(_会话.get("current_map_id")) == str(图)


func _地图有旗(地图: Node) -> bool:
	return _地图族旗(地图) != null


func _地图族旗(地图: Node) -> Node2D:
	var 节点 := 地图.get_node_or_null("族旗")
	if 节点 is Node2D:
		return 节点 as Node2D
	return null


func _本族在图(map_id: int) -> bool:
	var 表: Array = _后端.get("authoritative_flag_list") as Array
	var 自己 := int((_会话.guild as Dictionary).get("id", 0))
	for 行数据 in 表:
		var 记 := 行数据 as Dictionary
		if int(记.get("map_id", 0)) == map_id and int(记.get("bang_id", 0)) == 自己:
			return true
	return false


## 模拟玩家点行（走的就是行上那条 `gui_input`）。
func _点行(行: Control) -> void:
	var 事件 := InputEventMouseButton.new()
	事件.button_index = MOUSE_BUTTON_LEFT
	事件.pressed = true
	行.gui_input.emit(事件)


func _等待(条件: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while not 条件.call() and Time.get_ticks_msec() < 截止:
		await create_timer(0.05).timeout
	return true if 条件.call() else false


func _收尾() -> void:
	if _后端 != null:
		_后端.disconnect_backend()
	if _原端口 >= 0 and _会话 != null:
		(_会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
	if _失败.is_empty():
		print("家族安插族旗在线回归测试：通过（13 行按 flagmap 铺 → 选空点 → 确认弹 → 服务端真安上 → 地图上立旗且 z 对 → 已有旗后仍可再安）")
		quit(0)
		return
	for 条 in _失败:
		push_error("家族安插族旗在线回归测试：失败 - %s" % 条)
	print("家族安插族旗在线回归测试：FAIL %d 条" % _失败.size())
	quit(1)

extends SceneTree

## 「查看信息」的在线回帧门（#240，2026-10-15）。
##
## 玩家实机里那一下是：点中对面那个人 → 顶栏那排钮点「查看信息」→ 开出**对方的人物属性窗**。
## 原版这条链是 `UI.as:674-677 clickCharacter()` → `Client.as:4310 requestCharFullInfo()`
## ⇒ 上行 `94:4:<角色号>` → 下行 `58:4:<CharacterFullInfo 全字段>` → `DetailsWindow.setData()`。
##
## 这道门只判**链的前半段**（包发得出去、帧收得回来、字段解得对），建窗本身另开几何/行为门。
##
## ⚠ 三条口径（都是这工程踩过的）：
##   · **参照值不许问被测对象要**：属性那十二项的参照是**对端自己那条连接**的 `authoritative_stats`
##     （下行 34 属性帧），与本题的下行 58 档案帧是**两个不同的写者** ⇒ 不是自证；
##   · 样本串不许手写猜 ⇒ 本体判的是**真帧**；只有「截断帧整条丢」那两条用合成串，
##     所以另钉服务端拼串源没改（号 58、档 4）；
##   · 两个号都登录 ⇒ `user://玩家数据.json` 会被写 ⇒ 按字节快照 + 还原 + 断言。
##
## 跑法：由 `开发工具/跑在线用例.ps1 -用例 查看信息` 调（夹具给独立端口 18706/18707、
## 第二个账号 `naruto/123456` 与角色编号 `NW_SOCIAL_PEER_ID`）。

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 表脚本 := preload("res://脚本/单例/等级经验表.gd")
const 服务端文件 := "res://服务端/runtime/tools/fake_flash_server.py"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"
## 解析器要求的**下限**（`后端连接.他人信息段数`）：低于它整条丢。
## 真帧到底几段由本门**打印**出来 —— 建窗要用的字段数照这一行的实测值写，别猜。
const 段数下限 := 29

## 档案 vs 属性帧**同名字段**的对照表：键 = 档案里的中文键，值 = 对端 `authoritative_stats` 的键。
const 对照 := {
	"等级": "level", "职业": "job", "血上限": "maxHp", "蓝上限": "maxMp",
	"攻击": "attack", "防御": "defense", "暴击": "critical", "闪避": "dodge",
	"攻击速度": "attack_speed", "移动速度": "move_speed", "精华": "zq", "经验": "exp",
}

var _主		# autoload BackendConnection（主号 = 看别人的那一台）
var _对		# 第二条连接 = 被看的那个号自己登进来
var _对编号 := 0
var _档: Array = []			# 收到的每一条 58:4 档案（按到达顺序）
var _失败: Array[String] = []
var _原端口 := -1
var 存档路 := "user://玩家数据.json"
var 存档前 := PackedByteArray()
var 本来有存档 := false


func _initialize() -> void:
	call_deferred("_跑")


func 拍快照() -> void:
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	if 读 == null:
		本来有存档 = false
		return
	本来有存档 = true
	存档前 = 读.get_buffer(读.get_length())


func 还原存档() -> void:
	if 本来有存档:
		var 写 := FileAccess.open(存档路, FileAccess.WRITE)
		if 写 != null:
			写.store_buffer(存档前)
			写.close()
		var 读 := FileAccess.open(存档路, FileAccess.READ)
		var 现 := 读.get_buffer(读.get_length()) if 读 != null else PackedByteArray()
		_记(现.size() == 存档前.size(), "跑完把 %s **按字节还原**了（跑前 %d 字节）"
				% [存档路, 存档前.size()])
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
		_记(not FileAccess.file_exists(存档路), "跑前没有存档 ⇒ 跑完也不该留下（本门两个号都登录过）")


func _记(过: bool, 文: String) -> void:
	if 过:
		print("  √ " + 文)
	else:
		_失败.append(文)
		printerr("  !! " + 文)


func _等秒(秒: float, 条件: Callable) -> bool:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.1).timeout
	return bool(条件.call())


func _收档(档: Dictionary) -> void:
	_档.append(档.duplicate(true))


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if _主 == null or 会话 == null:
		printerr("查看信息：缺 BackendConnection / GameSession 单例")
		quit(1)
		return
	## ⚠ `extends SceneTree` 里**不许写裸 `GameSession`**（编译期就找不到标识符，整道门零覆盖）。
	_记(_主.has_signal("他人详细信息收到"),
			"后端声明了 他人详细信息收到（没有 ⇒ 服务端发了也没人接，窗永远是空的）")
	_记(_主.get("他人详细信息") is Dictionary, "后端有 他人详细信息 这个存放位")

	#  钉拼串源没改：合成串（截断那两条）的形状靠这两行撑着
	var 源 := FileAccess.get_file_as_string(服务端文件)
	_记(源.contains("CHAR_INFO = 58"), "服务端 CHAR_INFO 还是 58（改了 ⇒ 合成串要同步改）")
	_记(源.contains("CHAR_INFO_REQUEST = 94"), "服务端 CHAR_INFO_REQUEST 还是 94")
	_记(源.contains("ServerOpcode.CHAR_INFO,"),
			"服务端 action 4 那一支还在用 (ServerOpcode.CHAR_INFO, 4) 拼**完整档案**（撤掉 ⇒ 顶栏有血、窗里没属性）")

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18706
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；被看的那个号 = %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		printerr("查看信息：夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号，本门无从判起")
		还原端口()
		quit(1)
		return

	_主.connect("他人详细信息收到", Callable(self, "_收档"))
	_主.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(_主.in_game)):
		printerr("查看信息：主号进不了游戏（%s - %s）" % [_主.status, _主.detail])
		收拾并退出()
		return

	## 第二个号自己登进来 —— 它的 `authoritative_stats` 是本门的**参照值**来源。
	_对 = BACKEND_SCRIPT.new()
	_对.name = "查看信息被看的那个号"
	root.add_child(_对)
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	if not await _等秒(10.0, func() -> bool: return bool(_对.authenticated)):
		printerr("查看信息：第二个号登录不上（夹具里有没有 %s 这个账号？）" % PEER_ACCOUNT)
		收拾并退出()
		return
	if not bool(_对.select_character(_对编号)):
		printerr("查看信息：第二个号选不上角色 %d" % _对编号)
		收拾并退出()
		return
	if not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对.character_id) == _对编号):
		printerr("查看信息：第二个号进不了游戏（%s - %s）" % [_对.status, _对.detail])
		收拾并退出()
		return
	## 参照值也得**先取到**才准比（取不到时 `int(null)` 会报错，把「没数据」伪装成门坏了）。
	await _等秒(6.0, func() -> bool: return (_对.authoritative_stats as Dictionary).has("maxHp"))
	var 参照: Dictionary = _对.authoritative_stats
	_记(not 参照.is_empty(), "对端自己的属性帧（参照值）到了：现有键 %s" % str(参照.keys()))
	if 参照.is_empty():
		收拾并退出()
		return

	# ── ① 真发一发 94:4，等真帧 ─────────────────────────────────────────────
	var 发 := bool(_主.call("request_character_info", _对编号))
	_记(发, "主号把 94:4 发出去了（request_character_info 返回 %s）" % str(发))
	var 到了 := await _等秒(8.0, func() -> bool: return not _档.is_empty())
	_记(到了, "★ 真收到 58:4 档案帧（实得 %d 条）—— 收不到就是服务端那发没接上" % _档.size())
	if not 到了:
		收拾并退出()
		return

	var 档: Dictionary = _档[0]
	print("实测：段数 %s ｜ 名「%s」cid %s ｜ 等级 %s 职业 %s 头像 %s" % [
			str(档.get("段数", 0)), str(档.get("名", "")), str(档.get("cid", 0)),
			str(档.get("等级", 0)), str(档.get("职业", 0)), str(档.get("头像", 0))])
	print("实测：血 %s/%s 蓝 %s/%s 攻 %s 防 %s 暴 %s 闪 %s 攻速 %s 移速 %s" % [
			str(档.get("血", 0)), str(档.get("血上限", 0)), str(档.get("蓝", 0)), str(档.get("蓝上限", 0)),
			str(档.get("攻击", 0)), str(档.get("防御", 0)), str(档.get("暴击", 0)), str(档.get("闪避", 0)),
			str(档.get("攻击速度", 0)), str(档.get("移动速度", 0))])
	print("实测：精华 %s 经验 %s/%s 家族「%s」配偶「%s」声望 %s 罪恶 %s 忍术境界 %s 经脉 %s 八门 %s 成就 %s 宠物上限 %s" % [
			str(档.get("精华", 0)), str(档.get("经验", 0)), str(档.get("经验上限", 0)),
			str(档.get("家族", "")), str(档.get("配偶", "")), str(档.get("声望", 0)),
			str(档.get("罪恶值", 0)), str(档.get("忍术境界", 0)), str(档.get("经脉等级", 0)),
			str(档.get("八门进度", 0)), str(档.get("成就点", 0)), str(档.get("宠物上限", 0))])

	# ── ② 形状：段数下限与「是谁」 ────────────────────────────────────────────
	_记(int(档.get("段数", 0)) >= 段数下限,
			"帧里至少 %d 段（实得 %s）—— 少了说明服务端那份 builder 短了" % [段数下限, str(档.get("段数", 0))])
	_记(int(档.get("cid", 0)) == _对编号,
			"档案里那个 cid 就是被看的号 %d（实得 %s）—— 不是 ⇒ 把别人的属性填到我打开的窗上"
					% [_对编号, str(档.get("cid", 0))])
	_记(String(档.get("名", "")).length() > 0, "名字解出来了：「%s」" % str(档.get("名", "")))
	_记(int(档.get("头像", 0)) > 0, "头像位 %s 有效（窗左上那张脸，0 就画不出人）" % str(档.get("头像", 0)))
	_记(String(档.get("装备串", "")).length() > 0, "装备串非空（长度 %d）"
			% String(档.get("装备串", "")).length())

	# ── ③ 逐项与对端自己的属性帧对齐（两个写者，不是自证）────────────────────
	for 中文 in 对照.keys():
		var 参照键 := String(对照[中文])
		if not 参照.has(参照键):
			_记(false, "参照侧没有「%s」⇒ 这一项没判到（对端属性帧键名变了？）" % 参照键)
			continue
		_记(int(档.get(中文, -99999)) == int(参照[参照键]),
				"档案「%s」= 对端属性帧 %s = %s（实得 %s）"
						% [中文, 参照键, str(int(参照[参照键])), str(档.get(中文, "<无>"))])

	# ── ④ 经验上限：分母只能在客户端查原版等级表（服务端不发这一号）──────────
	_记(int(档.get("经验上限", 0)) == 表脚本.本级所需(int(参照.get("level", 1))),
			"经验上限 = 等级经验表[%s] = %s（实得 %s）" % [str(int(参照.get("level", 1))),
					str(表脚本.本级所需(int(参照.get("level", 1)))), str(档.get("经验上限", 0))])

	# ── ⑤ 两道守卫：段数不够 / 不是档 4 ⇒ 整条丢，已有的不许被盖 ─────────────
	var 旧 := (_主.get("他人详细信息") as Dictionary).duplicate(true)
	_主.call("_handle_bridge_text", "58:4:%d:假:5" % _对编号)
	for 帧 in 4:
		await process_frame
	_记((_主.get("他人详细信息") as Dictionary) == 旧,
			"截断的 58:4（只有 5 段）整条丢掉，窗上那份不动")
	_主.call("_handle_bridge_text", "58:0:%d:自己人:9:3:1:1:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0" % _对编号)
	for 帧 in 4:
		await process_frame
	_记((_主.get("他人详细信息") as Dictionary) == 旧,
			"档 0（自己的档案）不会当成「别人的」填进这扇窗 —— 只有档 4 才进")
	_记(_档.size() == 1, "两条废帧都没发信号（实得 %d 条）" % _档.size())

	收拾并退出()


func 还原端口() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null and _原端口 >= 0:
		(会话.get("game_settings") as Dictionary)["backend_port"] = _原端口


func 收拾并退出() -> void:
	if _对 != null and is_instance_valid(_对):
		_对.queue_free()
	await create_timer(0.2).timeout
	还原端口()
	还原存档()
	for 项 in _失败:
		printerr("查看信息在线门：红 - %s" % 项)
	print("查看信息在线门：红 %d 条%s" % [_失败.size(),
			"" if _失败.is_empty() else "（见上面 !! 行）"])
	quit(1 if not _失败.is_empty() else 0)

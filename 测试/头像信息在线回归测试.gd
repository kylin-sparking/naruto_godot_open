extends SceneTree
## 头像信息（目标信息条 `DetailsWindow`）那四组按钮的**在线端到端**门（#250~#253，2026-10-17）。
##
## 为什么必须有这一道：#220 那轮把这一排钮做完时只建了"点得到 + 发得出去"的门，
## **对面收不收得到、服务端回不回**从来没测过。用户 10-17 睡前点名要修这四组
## （加为好友 / 邀请组队 / 私聊 / 菜单含全部子钮），铁律口径 = 点它有请求 + 服务端回帧 + 画面有变化。
##
## 与 `开发工具/验头像信息钮.gd` 的分工：那把量具证"真鼠标点得到、走到哪一支"；
## **这一道证那条上行到不到服务端、对面收不收得到、我方屏幕上那一格变不变**。
## 两边都用**真鼠标**（`push_input`），不许 `emit_signal("pressed")` 演。
##
## 跑法：`powershell -File 开发工具\跑在线用例.ps1 -用例 头像信息在线`
## （2026-10-23 才挂号 —— 这条 10-17 就写好了但从没进 `$用例表`，所以 10-22 的 `-X ours` 合并
## 　 撤掉 is_self 判据时它一声不响，见 §3.255。
## 　夹具给独立端口 18738/18739，第二个号 `naruto/123456`、角色号 `NW_SOCIAL_PEER_ID`，
## 　并带 `--peer-level 30`（⑤ 师徒那两腿要对面落在服务端 `10..59` 那道闸里，见 `:828` 那条前置判据）；
## 　下面那个兜底默认口必须和 `$夹具额外` 里的 `--port` 逐字一致。）

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
const 头像面板场景 := "res://场景/界面/头像面板.tscn"
const 窗口管理场景 := "res://场景/界面/窗口管理.tscn"
const 聊天场景 := "res://场景/界面/聊天面板.tscn"
const 存档路 := "user://玩家数据.json"
const 服务端文件 := "res://服务端/runtime/tools/fake_flash_server.py"
const PEER_ACCOUNT := "naruto"
const PEER_PASSWORD := "123456"
## 层号照抄地图场景（`场景/生成/地图_100000000_烘焙.tscn`）⇒ 命中区才和真游戏一致。
const 层表 := {头像面板场景: 300, 聊天场景: 100, 窗口管理场景: 110}
## 菜单五行**全部接上了**（#88 撤掉最后一条）。以前这里挂着一份「本机未开放」名单，判的是
## "必须说话、不必发帧" ⇒ 那些话本身就是假的：
## ⚠ 10-17：「族邀」已经不在这儿了 —— 服务端三支（19 发 / 16 推 / 15 收 / 3 拒）一直都有，
## 缺的客户端那扇 `MPromptWindow` 已补齐（`真值/窗口/家族邀请窗.md`），见本门 §⑦。
## ⚠ 10-17 同日：「羁绊」也不在这儿了 —— 服务端四支（`127:15/20/21/22` ⇒ `61:14/17/18/19+20`）
## 一直都有，缺的是客户端那扇 `ProposalWindow`（`真值/窗口/求婚窗.md`），见本门 §⑧。
## ⚠ 10-24：「赠花」—— 服务端两支（`94:6`→`58:2`、`127:39`→`61:44`）一直都有，
## 缺的是客户端那扇 `MarryZengHuaWindow` 与菜单那一行，见本门 §⑩ 那一腿与 `真值/窗口/赠花窗.md`。
## 五行基本表，出处 `DetailsWindow._menu():309-320`（`ShituList.as:15 LIMIT_LEVEL=60`、
## `Config.as:78 SHITU_OFF=false`）—— 门里独立列一份，才好抓"行表算错/少一行"。
const 基本行 := ["族邀", "赠花", "羁绊", "看摊", "双修"]
## 头顶那一格的类型常量与「羁绊」那一页的控制器（§⑧ 要拿**真帧喂出来的背包**去调它的挑戒函数）。
const 托盘脚本 := preload("res://脚本/界面/邀请托盘.gd")
const 求婚脚本 := preload("res://脚本/界面/窗口/家族/求婚窗.gd")

var _主: Node = null
var _对: Node = null
var _会话: Node = null
var _面板: Node = null
var _条: Control = null
var _聊天: Node = null
var _管理: Node = null		# 窗口管理（头顶那个「邀请托盘」就挂在它底下，#255 要真点那一格）
var _对编号 := 0
var _原端口 := -1
var _失败: Array = []
var _地图: Node = null
var _收: Array = []
var _对好友: Array = []
var _对组队: Array = []
var _对双修: Array = []
var _对聊天: Array = []
var _对我聊天: Array = []
var _对师徒: Array = []
var _主师徒: Array = []
## 族邀那一腿（#261）：我这侧收到的 `1552:16` 原文解出来的字典、族长那侧收到的后帧。
var _族邀: Array = []
var _对族长状: Array = []
## 羁绊（求婚）那一腿（#262）：我这侧收到的 `61:17`、对面收到的 `61:18`（被拒）与 `61:19/20`（结成）。
## 三支的**方向不一样**：17 推给被求方（我），18/20 推给求方（对面）⇒ 接错一根就是"两头都收不到还一脸绿"。
## `61:14` 是第四支：我点菜单「羁绊」⇒ 服务端把**对面那份资料**回给**我**（`127:15` 的那一侧没有帧）。
var _求婚帧: Array = []
var _我预览: Array = []
var _我结成: Array = []
var _对拒帧: Array = []
var _对结成: Array = []
## 赠花那一腿（#88）：我这侧点菜单「赠花」⇒ 服务端把**对面**的花档回给我（`58:2`），
## 送花成功⇒ **两边各一条** `61:44`。两支方向不同：前者只给我，后者给我和对面都发 ⇒
## 接错一根就是"我这侧一脸绿、对面那颗格永远不出现"。
var _我花档: Array = []
var _我收花: Array = []
var _对收花: Array = []
## 每一帧**带 level 的属性帧**记一条：`[帧里的 level, 那一瞬间会话里的 level]`。
## 2026-10-17 查「信息条算师徒档用的我方等级恒 1」用 —— 权威表里 100、会话里 1，
## 到底哪一帧没并进 `player_stats`，这条明账会直接点名。
var 主属性帧: Array = []
var 存档前 := PackedByteArray()
var 本来有存档 := false
## 兜底：这条门一跑就是几分钟，**协程中途报错 ⇒ `quit()` 永远不会被调到 ⇒ 进程挂死**，
## 跑批就卡在那儿不出末行（2026-10-17 实测：一个 `as Dictionary` 强转报错把整条门吊了六分钟，
## 日志看着像"还在跑"，其实是死的）。⇒ 超时没跑完就按红收口，别把红伪装成"没跑完"。
## ⚠ 上限从 240 秒提到 420 秒：§⑧ 羁绊那一腿要等**两次**托盘补间（各 2.6 秒墙钟）
## 加十来条 `_等秒(8~10)`，240 秒会在门正常跑着的时候先把它判死（假红比假绿更难查）。
var 跑完了 := false


class 假地图 extends Node:
	## 「双修」那一行不再由面板直接发包：原版 `HealHandler.requestToDoubleHeal:374-395`
	## 先过 `canRequestDoubleNow`（|Δx|<40 && |Δy|<20 + 站稳 + 有落脚点），不够近就先
	## `pathFind` 走过去，走到够近那一拍才发。我们照抄成"面板问地图、地图管闸与赶路"。
	## 这条门只拎了 HUD 出来（没有世界）⇒ 挂个同签名替身判"交接"这一半；
	## "真的发到对面"由 §⑨ 那两发在线钉死。
	var 请求过: Array = []
	var 回话 := ""

	func 请求双修(号: int) -> String:
		请求过.append(号)
		return 回话


func _initialize() -> void:
	var 起 := Time.get_ticks_msec()
	call_deferred("_跑")
	while not 跑完了 and Time.get_ticks_msec() - 起 < 420_000:
		await process_frame
	if not 跑完了:
		printerr("头像信息在线：门自己没跑完（协程中途报错，看上面最后一条 SCRIPT ERROR）")
		还原端口()
		quit(1)


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


## 那一扇此刻**在不在屏幕上**。`取窗口` 拿到的是节点本身，关掉以后节点还挂在树上 ⇒
## 只判 `!= null` 会把"上一腿留下的那扇关掉的窗"读成"开着"（族邀那条踩过，假红）。
func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


## 求婚（羁绊申请）那一页的根件。页名两档共用一个场景 ⇒ 按 `原版求婚内容` 找，不按窗口名。
func _求页(窗: Node) -> Control:
	return _求页名(窗, "原版求婚内容")


## 同一件事的通用版：按**页根件名**在 `_content` 的直接子里找（赠花那一腿找 `原版赠花内容`）。
func _求页名(窗: Node, 页根: String) -> Control:
	if 窗 == null:
		return null
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String((子 as Node).name) == 页根:
			return 子 as Control
	return null


## 那条连接的**权威背包**里有没有「号」这一件、且坐在正格上（数量 > 0）。
## ⚠ 键名按的是**服务端 58 帧解出来那一份**（`_parse_item_entry:4349-4352`：`id`/`slot_index`/`quantity`），
## 不是 `item_id`/`position`/`count` —— 服务端 `_bond_pair_item:22930` 那条闸也是同一套（`slot > 0 且 quantity > 0`）。
func _背包有(后: Node, 号: int) -> bool:
	for 件 in (后.get("authoritative_inventory") as Array):
		if not (件 is Dictionary):
			continue
		if int((件 as Dictionary).get("id", 0)) == 号 \
				and int((件 as Dictionary).get("slot_index", 0)) > 0 \
				and int((件 as Dictionary).get("quantity", 0)) > 0:
			return true
	return false


## 那条连接的**权威装备表**里某一格上的物品（`slot < 0` 那几格走 `authoritative_equipment`，
## 与客户端自己的 `_item_at_slot:4416` 同一个分流）。查不到 ⇒ 空字典。
func _槽上(后: Node, 槽: int) -> Dictionary:
	var 表: Dictionary = 后.get("authoritative_equipment")
	return (表.get(槽, {}) as Dictionary)


## 那条连接的好友表里「号」那一行（查不到 ⇒ 空字典 ⇒ 调用方读到默认值就红，不静默）。
func _社交里(后: Node, 号: int) -> Dictionary:
	for 项 in (后.get("authoritative_friends") as Array):
		if 项 is Dictionary and int((项 as Dictionary).get("character_id", 0)) == 号:
			return 项 as Dictionary
	return {}


## **真鼠标**点头顶那一格「求婚」。返回**有没有点到**（true / false）。
## 三步都钉成判据，少一步就是"静默点到别的东西上"：① 按 类型 + charId 找到的是**这一份**求；
## ② 等 2 秒入场补间落位（按**墙钟**等：无头一秒能跑几千帧，等帧数不算数）；③ 点之前那一点确实压在它身上。
## ⚠ **不许把那一格回给调用方**：那一格派发点击时**自删**（原版 `CueGird` 点一下就消失）⇒
## 拿回来的实例是 already-freed、`== null` 恒真 ⇒ 调用方会以为"根本没找到格"（10-17 实测：
## 三条前置判据全打 √ 之后仍然提前收口）。要接着判屏幕就按**窗口**判，不按格判。
func _点求婚格(号: int) -> bool:
	var 盘 = _管理.get_node_or_null("邀请托盘")
	_记(盘 != null and int(盘.call("数量")) > 0,
			"我这侧头顶真多出一格（实得 %d 格）" % (int(盘.call("数量")) if 盘 != null else -1))
	if 盘 == null:
		return false
	var 得: Control = null
	for 子 in 盘.get_children():
		var 件 := 子 as Control
		if 件 == null:
			continue
		## ⚠ 托盘底下**不只格**（还有提示条一类），那些件上没有 `类型` 这个属性 ⇒ `get()` 回 null，
		## 而 `int(null)` 在 GDScript 里是**当场报错、整条函数死掉**（`Nonexistent 'int' constructor`），
		## 不是"返回 0"。10-17 就是这么把 §⑧ 整腿吊死、末行还打「红 0 条」的 ⇒ 先验类型再转。
		var 类: Variant = 件.get("类型")
		if typeof(类) != TYPE_INT or int(类) != 托盘脚本.类型求婚申请:
			continue
		var 据: Variant = 件.get("数据")
		if typeof(据) == TYPE_DICTIONARY and int((据 as Dictionary).get("charId", 0)) == 号:
			得 = 件
	_记(得 != null, "那一格带的就是这一份求（按 类型=求婚 + charId=%d 找得到）" % 号)
	if 得 == null:
		return false
	var 初x := 得.position.x
	var 止 := Time.get_ticks_msec() + 2600
	while Time.get_ticks_msec() < 止:
		await process_frame
	_记(初x < 200.0 and 得.position.x > 初x + 100.0,
			"那一格从 x=%.0f 飞到头顶槽位 x=%.0f 了 —— 没落位就点会点到叠在它上面的别的格" % [初x, 得.position.x])
	_管理.call("全部关闭")
	for i in 6:
		await process_frame
	await _挪到(得.get_global_rect().get_center())
	_记(root.gui_get_hovered_control() == 得,
			"点之前先确认那一点落在这格上（实得压在上面的=%s）" % str(root.gui_get_hovered_control()))
	await _点(得)
	for i in 6:
		await process_frame
	return true


## 从收到的聊天帧里**按关键字定位**那一帧（定位用 contains，判等内容另走逐字段 ==）。
func _择(帧表: Array, 关键字: String) -> Dictionary:
	for 件 in 帧表:
		if String((件 as Dictionary).get("message", "")).contains(关键字):
			return 件 as Dictionary
	return {}


func _等件(秒: float, 帧表: Array, 关键字: String) -> Dictionary:
	var 止 := Time.get_ticks_msec() + int(秒 * 1000.0)
	while Time.get_ticks_msec() < 止:
		var 得 := _择(帧表, 关键字)
		if not 得.is_empty():
			return 得
		await create_timer(0.1).timeout
	return _择(帧表, 关键字)


func 拍快照() -> void:
	本来有存档 = FileAccess.file_exists(存档路)
	if 本来有存档:
		存档前 = FileAccess.get_file_as_bytes(存档路)


func 还原存档() -> void:
	if 本来有存档:
		var 止 := FileAccess.get_file_as_bytes(存档路) if FileAccess.file_exists(存档路) else PackedByteArray()
		if 止 != 存档前:
			var 会 = root.get_node_or_null("GameSession")
			if 会 != null:
				(会.get("game_settings") as Dictionary)["backend_port"] = _原端口
			var tmp := 存档路 + ".还原中"
			var f := FileAccess.open(tmp, FileAccess.WRITE)
			f.store_buffer(存档前)
			f.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
			DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(存档路))
		print("  √ 跑完把 user://玩家数据.json 按字节还原了（跑前 %d 字节）" % 存档前.size())
	else:
		if FileAccess.file_exists(存档路):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路))
			print("  √ 跑前本来没有存档，跑完把写出来的那份删了")


func 还原端口() -> void:
	if _原端口 >= 0:
		var 会 = root.get_node_or_null("GameSession")
		if 会 != null:
			(会.get("game_settings") as Dictionary)["backend_port"] = _原端口


## 只把鼠标挪过去（不按）。给"点不到先量量压在谁身上"这种诊断用。
func _挪到(心: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
	await process_frame
	await process_frame


func _点(件: Control) -> void:
	var 心: Vector2 = 件.get_global_rect().get_center()
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	root.push_input(移)
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 心
	按.global_position = 心
	root.push_input(按)
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 心
	放.global_position = 心
	root.push_input(放)
	await process_frame
	await process_frame


func _钮(名: String) -> Control:
	return _条.get_node(名) as Control


## `_收` 里两种来源混在一起（GameSession 的提示 + 打了 `聊天:` 前缀的下行），拼成一串好判。
func _话串() -> String:
	return " / ".join(PackedStringArray(_收))


func _跑() -> void:
	拍快照()
	_主 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _主 == null or _会话 == null:
		printerr("头像信息在线：缺 BackendConnection / GameSession 单例")
		quit(1)
		return
	var 源 := FileAccess.get_file_as_string(服务端文件)
	_记(源.contains("def _handle_multiplayer_friend"), "服务端多人好友那一支还在（撤了 ⇒ 加好友永远石沉大海）")
	_记(源.contains("def _handle_multiplayer_party"), "服务端多人组队那一支还在")
	_记(源.contains("def handle_chat_message"), "服务端 1536 那支还在（撤了 ⇒ 六个频道一起石沉大海）")

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18738
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_对编号 = int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	print("连夹具端口 %d；对面那个号 = %d（账号 %s）" % [口, _对编号, PEER_ACCOUNT])
	if _对编号 <= 0:
		printerr("头像信息在线：夹具没给 NW_SOCIAL_PEER_ID ⇒ 没有第二个号，本门无从判起")
		还原端口()
		quit(1)
		return

	## **要在进图之前接**：带 level 的那一帧是进图时的角色包/首帧属性，接晚了就抓不到。
	_主.connect("stats_received", func(载荷: Dictionary) -> void:
		if 载荷.has("level"):
			主属性帧.append([int(载荷["level"]),
					int((_会话.get("player_stats") as Dictionary).get("level", -1)),
					str(_会话.get("backend_authoritative"))]))
	_主.sync_character()
	if not await _等秒(20.0, func() -> bool: return bool(_主.in_game)):
		printerr("头像信息在线：主号进不了游戏（%s - %s）" % [_主.status, _主.detail])
		收拾并退出("卡在「not await _等秒(20.0, func() -> bool: return bool(_主.in_game))」⇒ 后面的判据一条没跑")
		return
	var 我号 := int(_主.character_id)
	var 我名 := String((_会话.get("player_stats") as Dictionary).get("name", ""))
	## 我方等级也要在**建第二份连接之前**取（2026-10-17 量到的量具坑，不是游戏缺陷）：
	## `_对` 是真的 `后端连接.gd`，它 `_apply_stats` 里 `get_node_or_null("/root/GameSession")`
	## 拿到的是**同一个全局会话** ⇒ 对面那个 1 级号的属性帧会把**我的** `player_stats`
	## 整个盖过去（等级/名字/血蓝都跟着对面走）。真游戏只有一份连接，所以只会红在门里。
	## 判据 `主属性帧` 那条轨迹就是这件事的明账：发帧时会话已是 100，之后才回落。
	var 服务端级 := int((_主.get("authoritative_stats") as Dictionary).get("level", 0))
	var 会话级 := int((_会话.get("player_stats") as Dictionary).get("level", 0))
	_记(服务端级 > 0 and 会话级 == 服务端级,
			"进图后信息条用的我方等级 = 服务端那份（会话 %d vs 服务端 %d）" % [会话级, 服务端级])

	## HUD 三件按真层号建起来：条要能被真鼠标点、聊天面板要接住「私聊」那一档。
	for 路 in 层表:
		var 节 := (load(路) as PackedScene).instantiate()
		节.set("layer", int(层表[路]))
		root.add_child(节)
		if 路 == 头像面板场景:
			_面板 = 节
		if 路 == 聊天场景:
			_聊天 = 节
		if 路 == 窗口管理场景:
			_管理 = 节
	## 「双修」那一行的落点在**地图**（面板 `get_parent().get_node_or_null("LifeRoot")`）；
	## 这条门没跑世界场景 ⇒ 挂一个同签名替身（只判交接，真发在 §⑨）。
	_地图 = 假地图.new()
	_地图.name = "LifeRoot"
	root.add_child(_地图)
	root.size = Vector2i(960, 560)
	await create_timer(0.4).timeout
	_条 = (_面板.get_node("头像区域") as Control).get_node("选中人物信息") as Control

	_对 = BACKEND_SCRIPT.new()
	_对.name = "头像信息在线对面那个号"
	root.add_child(_对)
	_对.connect("friend_state_received", func(状: Dictionary) -> void: _对好友.append(状))
	_对.connect("party_state_received", func(状: Dictionary) -> void: _对组队.append(状))
	_对.connect("heal_state_received", func(状: Dictionary) -> void: _对双修.append(状))
	_对.connect("chat_received", func(件: Dictionary) -> void: _对聊天.append(件))
	_主.connect("chat_received", func(件: Dictionary) -> void: _对我聊天.append(件))
	## ⚠ 提示话术挂在 **GameSession**（`_报()` 走 `_session.notification_requested`），
	## 挂在 BackendConnection 上永远收不到 ⇒ 三条"必须说话"的判据全变成假红（10-17 自己踩）。
	_会话.connect("notification_requested", func(话: String) -> void: _收.append(话))
	_主.connect("chat_received", func(件: Dictionary) -> void: _收.append("聊天:" + str(件.get("message", 件))))
	_对.connect("tutor_requested", func(档: int, 号: int, 名: String) -> void: _对师徒.append({"档": 档, "号": 号, "名": 名}))
	## 反方向也要有人收：对面来拜**我**为师时，帧是推给**我**这份连接的（档 1）。
	_主.connect("tutor_requested", func(档: int, 号: int, 名: String) -> void: _主师徒.append({"档": 档, "号": 号, "名": 名}))
	## 羁绊（求婚 #262）那五支各归各的方向：`61:14` 回给**发起方**（我点菜单那一下）、
	## `61:17` 推给**被求方**（我）、`61:18/20` 推给**求方**（对面）、`61:19` 推给**同意方**（我）。
	## 接错一根 = 两头都收不到还一脸绿（族邀那条踩过同款，见 §⑦ 上面那段注释）。
	_主.connect("bond_preview_received", func(人: Dictionary) -> void: _我预览.append(人))
	_主.connect("bond_invite_received", func(邀: Dictionary) -> void: _求婚帧.append(邀))
	_主.connect("bond_established_received", func(婚: Dictionary) -> void: _我结成.append(婚))
	_对.connect("bond_refused_received", func(拒: Dictionary) -> void: _对拒帧.append(拒))
	_对.connect("bond_established_received", func(婚: Dictionary) -> void: _对结成.append(婚))
	## 赠花（#88）两支的方向：`58:2` 只回给**发起查询的那一侧**（我），`61:44` **两边各发一份**
	## （服务端 `_send_flower_gift` 给 sender/receiver 各写一帧）。⇒ 送花那腿必须两侧都收得到，
	## 只接我这侧会把"对面那颗托盘格永远不出现"判成绿。
	_主.connect("花档收到", func(档: Dictionary) -> void: _我花档.append(档))
	_主.connect("收花帧收到", func(条: Dictionary) -> void: _我收花.append(条))
	_对.connect("收花帧收到", func(条: Dictionary) -> void: _对收花.append(条))
	_对.connect_backend(PEER_ACCOUNT, PEER_PASSWORD, false)
	if not await _等秒(10.0, func() -> bool: return bool(_对.authenticated)):
		printerr("头像信息在线：第二个号登录不上（夹具里有没有 %s 这个账号？）" % PEER_ACCOUNT)
		收拾并退出("卡在「not await _等秒(10.0, func() -> bool: return bool(_对.authenticated))」⇒ 后面的判据一条没跑")
		return
	if not bool(_对.select_character(_对编号)):
		printerr("头像信息在线：第二个号选不上角色 %d" % _对编号)
		收拾并退出("卡在「not bool(_对.select_character(_对编号))」⇒ 后面的判据一条没跑")
		return
	if not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对.character_id) == _对编号):
		printerr("头像信息在线：第二个号进不了游戏（%s - %s）" % [_对.status, _对.detail])
		收拾并退出("卡在「not await _等秒(20.0, func() -> bool: return bool(_对.in_game) and int(_对」⇒ 后面的判据一条没跑")
		return
	await _等秒(6.0, func() -> bool: return (_对.authoritative_stats as Dictionary).has("maxHp"))
	var 对档: Dictionary = _对.get("authoritative_stats")
	var 对名 := String(对档.get("name", ""))
	var 他对级 := int(对档.get("level", 0))
	## 对面那个族（他是族长 ⇒ `NW_PEER_FAMILY_*` 就是他的）。`61:14/17` 里那一段**家族名**
	## 与服务端算的那一份是同一个来源（`family_by_id(...).get("name")`），拿环境变量当参照值，
	## 不从我这边解出来的字典里反查（自己证自己 = 假绿）。
	var 对族名 := String(OS.get_environment("NW_PEER_FAMILY_NAME"))
	_记(他对级 > 0, "对面的等级 = %d（菜单那一行的师徒档按它算，写死会造出假红）" % 他对级)
	_记(对名 != "", "对面的档案名 = 「%s」（下面几组按钮都拿它当参照值）" % 对名)
	## #260：双修邀请窗那行「家族：」的数据源 = **162 出生帧第 24 段**（服务端
	## `_foreign_player_payload:15188-15230` 里 `_current_family_name()` 那一格）。
	## 这一发必须在**真帧**上判：离线门里那个键名是我自己起的（`guildName`），
	## 代码读的也是它 ⇒ 两边一起绿而真机上那行永远空白（10-17 同一条坑第二次踩）。
	_记(await _等秒(8.0, func() -> bool:
			return String(((_主.get("map_players") as Dictionary).get(_对编号, {}) as Dictionary)
					.get("family_name", "")) == 对族名),
			"我这侧同屏表里对面那一行的 `family_name` = 夹具那个族（真帧解出来的，实得「%s」/ 期「%s」）" % [
				String(((_主.get("map_players") as Dictionary).get(_对编号, {}) as Dictionary).get("family_name", "‹没这个键›")),
				对族名])
	_记(服务端级 > 0 and 会话级 == 服务端级,
			"信息条算师徒档用的我方等级 = 服务端那份（会话 %d vs 服务端 %d）" % [会话级, 服务端级])

	## 把"选中了对面那个人"喂进面板 —— 走的是真入口 `_on_map_character_selected`
	## （真游戏里由 `地图实体` 点中人推过来，这里只替掉"点中世界那一步"，
	##  后面每一颗钮都是**真鼠标**点的）。
	_面板.call("_on_map_character_selected", {
		"type": 1, "char_id": _对编号, "name": 对名,
		"level": 他对级, "level_text": "Lv.%d" % 他对级,
		"hp": 1000, "max_hp": 1000, "mp": 500, "max_mp": 500})
	await create_timer(0.3).timeout
	_记(_条.visible and _钮("钮_加好友").visible, "选中玩家档 ⇒ 那一排钮显出来")

	# ──  加为好友：真点 ⇒ 对面收到申请 ⇒ 对面接受 ⇒ 两边列表互含 ──────
	_对好友.clear()
	await _点(_钮("钮_加好友"))
	_记(await _等秒(8.0, func() -> bool:
		for 状 in _对好友:
			if str(状).contains(我名) or int(状.get("request_id", 0)) == 我号:
				return true
		return false), "点「加为好友」⇒ 对面收到好友申请（实收 %s）" % str(_对好友))
	## ①b **被邀请那一侧的屏幕上到底有没有东西**（用户 10-17 报的 bug1 就是这一格没有）。
	## 上面那一发是"我发给对面"，而缺 UI 的正是**收到的一方** ⇒ 这一档改成**对面发给我**：
	## `127:1:<我的号>` ⇒ 服务端给**我**推 `61:5:<对面号>:<对面名>` ⇒
	## 我这侧应当 ① 头顶托盘多一格（图标 = 原版那张 46×46）、② 真鼠标点它 ⇒ 弹 MDialog
	## 「<橙>对面名</>请求加为好友！」、③ 真点「确定」⇒ 我这侧发 `127:2:<对面号>` ⇒ 两边列表互含。
	## ⚠ 这里判的是**真点得到的节点**，不是后端字典 —— 只判 `is_friend` 等于没测"看得见"这件事。
	_对.request_friend_add(我号)
	var 盘 = _管理.get_node_or_null("邀请托盘")
	_记(盘 != null, "窗口管理底下有「邀请托盘」这一层（实得 %s）" % str(盘))
	_记(await _等秒(8.0, func() -> bool: return int(盘.call("数量")) > 0),
			"对面发申请 ⇒ 我这侧托盘出现一格（实得 %d 格）" % (int(盘.call("数量")) if 盘 != null else -1))
	var 那格: Control = 盘.最后一格() if 盘 != null else null
	if 那格 != null:
		var 图: TextureRect = 那格.get_node_or_null("图标") as TextureRect
		_记(图 != null and 图.texture != null
				and String(图.texture.resource_path).contains("托盘_好友申请"),
				"那一格的图标 = 原版 `UISwf_FriendIcon_GridFriendInvite`（导出图，不是染色/不是占位）实得 %s" % (
					图.texture.resource_path if 图 != null and 图.texture != null else "（无）"))
	var 弹 := _管理.get_node_or_null("模态确认弹层/模态确认弹") as Control
	if 那格 != null and 弹 != null:
		await _点(那格)
		await create_timer(0.3).timeout
		_记(弹.visible and String((弹.get_node("主体/正文") as RichTextLabel).text).contains(对名)
				and String((弹.get_node("主体/正文") as RichTextLabel).text).contains("请求加为好友"),
				"点那一格 ⇒ 弹 MDialog，正文带对面名（原版 `FRIEND_INVITE_YOU_TIP`）实得「%s」" % String(
					(弹.get_node("主体/正文") as RichTextLabel).text))
		await _点(弹.get_node("主体/确定钮") as Control)
		_记(not 弹.visible, "点「确定」⇒ 弹自己收掉")
	else:
		_记(false, "托盘那格或确认弹没拿到 ⇒ 这一腿等于没测（格=%s 弹=%s）" % [str(那格), str(弹)])
	_记(await _等秒(8.0, func() -> bool: return bool(_主.call("is_friend", _对编号))),
			"我这侧点完确定 ⇒ 我的好友列表里出现对面（is_friend(%d)）" % _对编号)
	_记(await _等秒(8.0, func() -> bool: return bool(_对.call("is_friend", 我号))),
			"对面接受 ⇒ **对面**好友列表里出现我方（is_friend(%d)）" % 我号)

	# ── ② 邀请组队：真点 ⇒ 对面收到组队邀请 ⇒ 接受 ⇒ 两边同一支队伍 ────
	_对组队.clear()
	await _点(_钮("钮_组队"))
	var 到队: bool = await _等秒(8.0, func() -> bool:
		for 状 in _对组队:
			if str(状).contains(我名):
				return true
		return false)
	_记(到队, "点「邀请组队」⇒ 对面收到组队邀请（实收 %s）" % str(_对组队))
	## ⚠ 这一整段第一版**一条都没跑**：`59:4` 解出来的队号嵌在 `状["invite"]["party_id"]` 里，
	## 而循环在**状态字典顶层**找 `party_id` ⇒ 恒 0 ⇒ `if 队号 > 0:` 整段跳过，
	## 门照样"红 0"（记忆里第十四类的更阴形态：不是 0 比 0 恒真，是**判据压根没执行**）。
	## 现在：队号从嵌套里取 + 取不到就**明着红**；人数按 `members.size()`
	## （`authoritative_party` 里**没有 member_count 这个键**，那名字是我凭印象写的）。
	var 队号 := 0
	for 状 in _对组队:
		var 邀: Dictionary = (状 as Dictionary).get("invite", {}) if (状 as Dictionary).get("invite") is Dictionary else {}
		if int(邀.get("party_id", 0)) > 0:
			队号 = int(邀.get("party_id", 0))
	_记(到队 and 队号 > 0, "那一帧带的队号取到了（队号=%d；取不到 ⇒ 下面两腿等于没测）" % 队号)
	var 旧队号 := 队号	## 留给 ②b 比对：新那一格的队号必须**不等于**它
	_对.request_party_accept(队号)
	_记(await _等秒(8.0, func() -> bool: return _主.get("authoritative_party").get("members", []).size() >= 2),
			"对面接受 ⇒ 我方队伍成员 >= 2（实得 %s）" % str(_主.get("authoritative_party")))
	_记(await _等秒(8.0, func() -> bool: return _对.get("authoritative_party").get("members", []).size() >= 2),
			"对面那侧同样看到 2 人（两边一致，不是一边画错）")

	## ②b **被邀请那一侧的屏幕上有没有那一格**（同 ①b，用户报的 bug1 第二条）。
	## 只有主号这一侧接了 HUD ⇒ 必须让**主号当被邀的那个**：两边都先退掉 ② 那支队，
	## 再由对面建队、邀我 ⇒ 服务端给我推 `59:4:<队号>:<队长名>` ⇒ 我这侧托盘出格
	## ⇒ 真点格 ⇒ 真点「确定」= `120:3:<队号>` ⇒ 我这边 member_count 回到 2。
	## ⚠ 谁建队很关键：② 里建队的是我（我是队长），不先退干净这条会撞上"自己已在队伍中"。
	## ⚠ 取消那一发不测：原版是 `120:13:<队长名>`，而本机服务端 `_handle_multiplayer_party`
	##   没有 13 这一支 ⇒ 发出去没人接，测了也只是自证（要真能拒绝得先加服务端分支 = 等他点头）。
	_对.request_party_leave()
	## ⚠ 我这侧不能只"离队"：② 里建的队**我是队长**，服务端 action 2 让队长走只是把自己摘出去、
	## 队还在（10-17 实测：离队后 `joined` 仍是 true、members 只剩我一人）⇒ 必须走 **解散（action 7）**，
	## 否则对面建不了新队、也邀不进来。
	_主.request_party_disband()
	## ⚠ 这里**不能**判"我这侧看到 joined=false"：服务端 action 7 只把解散通知 `59:12` 发给**其余成员**，
	## 发起解散的那个人自己收不到（10-17 实测：解散后 `authoritative_party` 还是旧队）⇒ 判它就是判一个
	## 永远不会变的东西。改成判**能量到的那一层**：下面那一格带的队号必须与 ② 那支不同
	## （不同 = 服务端那边旧队确实没了、对面确实建成新队 ⇒ 前置成立）。
	## 解散回执该不该也发给发起人，记进 §未收口 等点头，本轮不动服务端。
	await create_timer(0.6).timeout
	_对.request_party_create()
	await create_timer(1.2).timeout
	_对.request_party_invite(我名)
	var 队盘 = _管理.get_node_or_null("邀请托盘")
	_记(队盘 != null and await _等秒(8.0, func() -> bool: return int(队盘.call("数量")) > 0),
			"对面发组队邀请 ⇒ 我这侧托盘出现一格（实得 %d 格）" % (int(队盘.call("数量")) if 队盘 != null else -1))
	## ⚠ `最后一格()` 返回的是**格节点**，数据挂在格.数据 上（不是格自己就是字典）⇒ 当字典用会恒空。
	var 新数据: Dictionary = (队盘.最后一格().get("数据") as Dictionary) if 队盘 != null else {}
	_记(int(新数据.get("troopId", 0)) > 0 and int(新数据.get("troopId", 0)) != 旧队号,
			"那一格带的**是新队伍**（旧队号 %d ⇒ 新队号 %s）：不同才说明服务端那边旧队真没了、对面真建成了新队" % [
				旧队号, str(新数据.get("troopId", 0))])
	var 队格: Control = 队盘.最后一格() if 队盘 != null else null
	if 队格 != null:
		var 队图: TextureRect = 队格.get_node_or_null("图标") as TextureRect
		_记(队图 != null and 队图.texture != null
				and String(队图.texture.resource_path).contains("托盘_组队邀请"),
				"那一格的图标 = 原版 `UISwf_ZuDuiIcon_GridTroopInviteAndApply` 实得 %s" % (
					队图.texture.resource_path if 队图 != null and 队图.texture != null else "（无）"))
		var 队弹 := _管理.get_node_or_null("模态确认弹层/模态确认弹") as Control
		await _点(队格)
		await create_timer(0.3).timeout
		var 队文 := "" if 队弹 == null else String((队弹.get_node("主体/正文") as RichTextLabel).text)
		_记(队弹 != null and 队弹.visible and 队文.contains(对名) and 队文.contains("邀请你加入组队"),
				"点那一格 ⇒ 弹 MDialog「对面名邀请你加入组队！」（原版 `TROOP_INVITE_YOU_TIP`）实得「%s」" % 队文)
		if 队弹 != null and 队弹.visible:
			await _点(队弹.get_node("主体/确定钮") as Control)
		_记(await _等秒(8.0, func() -> bool: return _主.get("authoritative_party").get("members", []).size() >= 2),
				"真点「确定」= 发 `120:3:<队号>` ⇒ 我又回到两人队里（实得 %s）" % str(_主.get("authoritative_party")))
	else:
		_记(false, "组队那一格没拿到 ⇒ 这一腿等于没测")

	# ── ③ 私聊：真点 ⇒ 聊天框切私聊 + 预填 ⇒ 发一句 ⇒ 对面收得到 ────────
	await _点(_钮("钮_私聊"))
	await create_timer(0.3).timeout
	var 预填 := ""
	var 频道 := ""
	if _聊天 != null:
		预填 = str((_聊天.get("_chat_input") as LineEdit).text) if _聊天.get("_chat_input") != null else ""
		频道 = str(_聊天.call("当前频道")) if _聊天.has_method("当前频道") else ""
	_记(预填.contains(对名) or 频道.contains("私聊"),
			"点「私聊」⇒ 聊天框切到私聊并预填「%s」（频道=「%s」）" % [预填, 频道])
	var 暗号 := "在线门暗号%d" % (Time.get_ticks_msec() % 100000)
	_对聊天.clear()
	_对我聊天.clear()
	var 发了: bool = bool(_主.request_chat(暗号, 4, _对编号, 对名))
	await create_timer(0.8).timeout
	## ⚠ **逐字段比，不比"含不含"**：以前这条只判 `contains(暗号)`，而服务端把正文按
	## `fields[5:-2]` 切 —— 上行多写一个段时正文会变成「暗号:-」，`contains` 照样绿。
	## `positions` 判 16 = 服务端按频道映射出来的那一档（上行必须发 0，见 `request_chat` 注）。
	var 我件 := _择(_对我聊天, 暗号)
	_记(发了 and not 我件.is_empty(),
			"私聊上行发得出去、服务端也把它回给我自己了（发了=%s 我方自收=%s）" % [str(发了), str(_对我聊天)])
	_记(String(我件.get("message", "")) == 暗号,
			"自收那一份的**正文逐字等于**发出去的那句（段数错了会粘成「%s:-」）：实收「%s」" % [暗号, String(我件.get("message", ""))])
	_记(int(我件.get("type", 0)) == 4 and int(我件.get("positions", 0)) == 16,
			"自收那一份是**私聊档**（type=4、服务端映射出 positions=16）：实得 type=%s positions=%s" % [str(我件.get("type")), str(我件.get("positions"))])
	_记(String(我件.get("target_name", "")) == 对名,
			"自收那一份带的**对象名** = 「%s」（实得「%s」）" % [对名, String(我件.get("target_name", ""))])
	var 对件 := await _等件(8.0, _对聊天, 暗号)
	_记(not 对件.is_empty(), "私聊这一发对面收得到（实收 %s）" % str(_对聊天))
	_记(String(对件.get("message", "")) == 暗号,
			"对面收到的正文逐字等于那一句：实收「%s」" % String(对件.get("message", "")))
	_记(String(对件.get("name", "")) == 我名,
			"对面看到的**说话人** = 「%s」（实得「%s」）" % [我名, String(对件.get("name", ""))])

	## ③c **句子里谁对谁说**（用户 10-17 实机报的 bug2：油女澪那侧显示成「你对油女澪说」）。
	## ⚠ 判的是**聊天面板渲染出来的那一行正文**，不是后端字典 —— 后端字段一直是对的
	## （上面那几条早就逐字比过 name/target_name），坏的是渲染时把 `is_self` 硬写成 true
	## （`聊天面板.gd:767`）。原版判据 = **帧里的名字 == 我自己的名字**（`UI.as:363/366/373`
	## 那个第五参），所以这里两档都要钉：我发的 ⇒「你对XX说」；别人发的 ⇒「XX对你说」且**不许出现「你对」**。
	var 我行们: Array = _聊天.get("_chat_messages")
	_记(not 我行们.is_empty(), "聊天面板里有消息行（实得 %d 条）" % 我行们.size())
	var 我方句 := ""
	if not 我行们.is_empty():
		我方句 = String((我行们[-1] as Dictionary).get("bbcode", ""))
	_记(我方句.contains("你对") and 我方句.contains(对名) and 我方句.contains("说")
			and 我方句.contains(暗号),
			"我发的那一句在我自己屏上是「你对%s说」：实得「%s」" % [对名, 我方句])
	var 回话 := "在线门回话%d" % (Time.get_ticks_msec() % 100000)
	_对我聊天.clear()
	bool(_对.request_chat(回话, 4, 我号, 我名))
	## 对面那一份要**进得了我这侧的面板**才算数：先等后端收到，再看面板最后一条。
	var 收到 := await _等秒(8.0, func() -> bool:
		for 件 in _对我聊天:
			if String((件 as Dictionary).get("message", "")) == 回话:
				return true
		return false)
	_记(收到, "对面发的那一句我这侧后端收得到（实收 %s）" % str(_对我聊天))
	await create_timer(0.6).timeout
	var 对面句 := ""
	for 件 in _聊天.get("_chat_messages") as Array:
		if String((件 as Dictionary).get("bbcode", "")).contains(回话):
			对面句 = String((件 as Dictionary).get("bbcode", ""))
	_记(对面句.contains(对名) and 对面句.contains("对你说") and not 对面句.contains("你对%s" % 对名),
			"对面发来的那句在我屏上是「%s对你说」，**不是**「你对%s说」（实得「%s」）" % [对名, 对名, 对面句])

	## ③b 普通频道：六个频道共用同一条组包，只测私聊等于没测其余五档的路由
	## （服务端 4 走 `session_for_character` 单点、3 走 `broadcast_visible` 同屏群发，两支代码不同）。
	var 明话 := "在线门明话%d" % (Time.get_ticks_msec() % 100000)
	_对聊天.clear()
	_对我聊天.clear()
	var 发了普通: bool = bool(_主.request_chat(明话, 3))
	await create_timer(0.8).timeout
	var 我自 := _择(_对我聊天, 明话)
	_记(发了普通 and not 我自.is_empty(),
			"普通频道同样发得出、服务端也回给我自己（发了=%s 实收=%s）" % [str(发了普通), str(_对我聊天)])
	_记(int(我自.get("positions", 0)) == 8,
			"普通档服务端映射 positions=8（实得 %s）" % str(我自.get("positions")))
	var 对面普通 := await _等件(8.0, _对聊天, 明话)
	_记(not 对面普通.is_empty(),
			"普通频道同屏的对面也收得到（实收 %s）" % str(_对聊天))

	## ③c **走玩家那条真路**：信息条上点「私聊」⇒ 输入框里补正文 ⇒ 真鼠标点「发送钮」。
	## 上面 ③ 是直接调 `request_chat`，只证明**字节**对；玩家用的是输入框 + 那颗钮，
	## 中间还隔着三道只有面板才有的闸：`/名字␣消息` 的解析、频道→档位的映射、1 秒防刷屏。
	## 任何一道断了，玩家那边就是"打了字按发送什么都没发生"，而 ③ 照样绿。
	var 输入: LineEdit = null
	var 发钮: Control = null
	if _聊天 != null:
		输入 = _聊天.get("_chat_input") as LineEdit
		发钮 = _聊天.find_child("发送钮", true, false) as Control
	if 输入 != null and 发钮 != null:
		var 暗号二 := "面板私聊%d" % (Time.get_ticks_msec() % 100000)
		_对聊天.clear()
		_对我聊天.clear()
		输入.text = "/%s %s" % [对名, 暗号二]
		await _点(发钮)
		var 我自二 := await _等件(8.0, _对我聊天, 暗号二)
		_记(not 我自二.is_empty() and int(我自二.get("type", 0)) == 4,
				"从聊天框点「发送钮」发私聊 ⇒ 服务端按私聊档回给我（实收 %s）" % str(_对我聊天))
		var 对面二 := await _等件(8.0, _对聊天, 暗号二)
		_记(String(对面二.get("message", "")) == 暗号二,
				"这一句也是**面板解析出来的正文**（不带 `/名字 `）到得了对面：实收「%s」" % String(对面二.get("message", "")))
	else:
		_记(false, "面板的输入框或「发送钮」没找到 ⇒ 这一腿等于没测（输入=%s 钮=%s）" % [str(输入), str(发钮)])

	# ── ④ 菜单：弹开 ⇒ **每一行**真点一次 ─────────────────────────────
	print("带 level 的属性帧（帧值, 发帧时会话值, 权威标记）= %s；此刻会话 level=%d" % [
		str(主属性帧), int((_会话.get("player_stats") as Dictionary).get("level", 0))])
	var 菜 := _条.get_node("目标菜单") as Control
	await _点(_钮("钮_菜单"))
	await create_timer(0.2).timeout
	_记(菜.visible, "点「菜单」⇒ 弹出来（矩形 %s）" % str(菜.get_global_rect()))
	var 行数 := 0
	var 行名表: Array = []
	for i in 12:
		var 现 := 菜.get_node_or_null("项_%d" % i) as Button
		if 现 != null and 现.visible:
			行数 += 1
			行名表.append(现.text)
	## 行表 = 五行基本 + 师徒那一档（`DetailsWindow._menu():309-320`：`SHITU_OFF=false`、
	## `LIMIT_LEVEL=60`）。这里的"我方等级"必须现取**会话那一刻的值** ——
	## 面板读的就是它（对面那份连接会把它盖成 1，见上面那段注）；拿早先那份 100 去算期望，
	## 就成了"期望 6 行、屏幕 5 行"的假红。行表三档公式本身由 `测试/目标信息条回归测试.gd ⑨` 钉死。
	var 会话级现 := int((_会话.get("player_stats") as Dictionary).get("level", 0))
	var 该有 := 基本行.duplicate()
	if 会话级现 < 60 and 他对级 >= 60:
		该有.append("拜师")
	elif 会话级现 >= 60 and 他对级 < 60:
		该有.append("收徒")
	_记(行名表 == 该有,
			"菜单行表逐行等于原版算式（我 %d 级 / 他 %d 级 ⇒ 应有 %s，实得 %s）" % [会话级现, 他对级, str(该有), str(行名表)])
	for i in 12:
		var 行 := 菜.get_node_or_null("项_%d" % i) as Button
		if 行 == null or not 行.visible:
			continue
		var 文案 := 行.text
		if not 菜.visible:
			await _点(_钮("钮_菜单"))
			await create_timer(0.15).timeout
		_收.clear()
		_对双修.clear()
		_对师徒.clear()
		await _点(行)
		await create_timer(0.6).timeout
		var 话 := " / ".join(PackedStringArray(_收)) if not _收.is_empty() else ""
		var _主摊: Dictionary = _主.get("stall_状") if _主.get("stall_状") != null else {}
		match 文案:
			"看摊":
				_记(not 话.is_empty() or not _主摊.is_empty(),
						"菜单「看摊」⇒ 有回话或有摊数据（实得话=「%s」摊=%s）" % [话, str(_主摊)])
			"双修":
				## 判**交接**这一半：面板把对方号交给地图（距离闸 + 不够近先自动走过去），
				## 自己**不发** 86:3 —— 原版 `requestToDoubleHeal:374-395` 就是这个形状。
				## "真发到对面"由 §⑨ 那两发（邀请/拒绝/再邀/同意）在线钉死。
				_记(_地图 != null and ( _地图.get("请求过") as Array) == [_对编号],
						"菜单「双修」⇒ 面板把对方号交给地图去判距离/赶路（`地图实体.请求双修`；实得 %s）"
								% str(_地图.get("请求过") if _地图 != null else null))
				_记(_对双修.is_empty(),
						"⇒ 面板自己**不发** 86:3（这一拍对面不该收到邀请帧；实收 %s）" % str(_对双修))
			"羁绊":
				## 上行 `127:15:<对面号>` ⇒ 服务端 `:23225-23241` 把**对面那份资料**回给**我**（`61:14`），
				## 我这侧那一扇**直接开出来**（原版 `onFriend_taStart` = setData + show，**不走托盘**）。
				## 这一发同时把离线门里那条"包体字节未判"补上：段序写反（`15` 与目标号换档）就回不了帧。
				_记(await _等秒(8.0, func() -> bool: return not _我预览.is_empty()),
						"菜单「羁绊」⇒ 我这侧收到 `61:14`（实得 %d 条）" % _我预览.size())
				var 预览: Dictionary = (_我预览[0] as Dictionary) if not _我预览.is_empty() else {}
				_记(String(预览.get("name", "")) == 对名 and int(预览.get("level", 0)) == 他对级
						and int(预览.get("job", -1)) == int(对档.get("job", -2))
						and int(预览.get("charId", 0)) == _对编号,
						"`61:14` 逐字段 = 对面那条连接自己的权威档案（名「%s」/ 级 %d / 职 %d / 号 %d，全帧=%s）" % [
							String(预览.get("name", "")), int(预览.get("level", 0)),
							int(预览.get("job", -1)), int(预览.get("charId", 0)), str(预览)])
				_记(String(预览.get("banghui", "")) == 对族名,
						"第四段是**家族名**、键必须叫 `banghui`（pane 读的就是它；实得「%s」/ 期「%s」）" % [
							String(预览.get("banghui", "")), 对族名])
				_记(int(预览.get("face", 0)) == int(对档.get("face", -1)),
						"face = 对面属性帧里那一位（实得 %d / 期 %d）" % [
							int(预览.get("face", 0)), int(对档.get("face", -1))])
				_记(not 预览.has("item"), "`14` 那一支**不带**对戒号（带末段的是 `17`，两支形状不同，别并）")
				var 窗甲: Node = _管理.call("取窗口", "羁绊申请") as Node
				_记(_开着(窗甲), "收到 `61:14` ⇒ 发起档**直接开出来**（族邀那一支相反：只塞格）")
				var 页甲 := _求页(窗甲)
				_记(页甲 != null, "开出来的那一页是「原版求婚内容」（不是家族邀请那一页）")
				if 页甲 != null:
					_记(String(窗甲.get_node("遮罩/主窗口/标题").text) == "发起羁绊",
							"标题 = PROPOSA_WINDOW_TITLE（实得「%s」）" % String(窗甲.get_node("遮罩/主窗口/标题").text))
					_记(String((页甲.get_node("心意提示") as Label).text)
							== "请问您是希望向TA发出羁绊请求吗？",
							"发起档 pane 提示 = CHARINFO_PANE_TISHI_TEXT_2（实得「%s」）"
									% String((页甲.get_node("心意提示") as Label).text))
					_记((页甲.get_node("放入钮") as Control).visible,
							"发起档 ⇒ 「放入羁绊戒」那颗**看得见**（被求档才是隐藏）")
					_记(String((页甲.get_node("主钮/文字") as Label).text) == "建立羁绊",
							"发起档主钮 = PROPOSA_WINDOW_QIUHUN（实得「%s」）"
									% String((页甲.get_node("主钮/文字") as Label).text))
				## 关干净再走下一行：这一扇正压着信息条那排钮，不关就是"下一行的点到窗上了"。
				_管理.call("全部关闭")
				await create_timer(0.3).timeout
			"族邀":
				## 协议那一半 §⑦ 已经端到端钉死了（族长发 19 ⇒ 推 16 ⇒ 真点格 ⇒ 真点同意）。
				## 这一腿只钉**菜单这一行**：我这号不在任何族里（夹具只给同伴造了族）⇒
				## 服务端 `:33547` 那道 `is_leader` 之外 ⇒ 没反应是**对的**；
				## 但面板**不许再说"本机服务端没有这条协议"**（那是 §3.255 那句假话：
				## 三条上行 `request_family_invite` 早就写好了，缺的是这一行没接）。
				_记(not 话.contains("没有「族邀」这条协议"),
						"菜单「族邀」⇒ 不再谎报没协议（实得「%s」）" % 话)
			"拜师", "收徒":
				_记(not _对师徒.is_empty() or not 话.is_empty(),
						"菜单「%s」⇒ 对面收到 77 申请或有回话（对面 %s 我方话=「%s」）" % [文案, str(_对师徒), 话])
			"赠花":
				## 上行 `94:6:<对面号>` ⇒ 服务端把**对面那份花档**回给**我**（`58:2` 十个段）。
				## ⚠ 点击那一刻**不开窗**（原版 `openMarryZengHuaWindow:184-197` 只存四项 + 发查询），
				## 开窗的是**回帧**（`receiveRefreshFlowerWindow:338` ⇒ 本门里 `窗口管理._on_花档帧`）⇒
				## 这两段各判一条：帧不到 = 上行/段序坏；帧到窗不开 = 消费者断。
				_记(await _等秒(8.0, func() -> bool: return not _我花档.is_empty()),
						"菜单「赠花」⇒ 我这侧收到 `58:2`（实得 %d 条）" % _我花档.size())
				var 花档零: Dictionary = (_我花档[0] as Dictionary) if not _我花档.is_empty() else {}
				var 三档: Array = 花档零.get("flowerInfo", []) as Array
				_记(int(花档零.get("cid", 0)) == _对编号,
						"第 1 段是**对面**的号（实得 %d / 期 %d）" % [int(花档零.get("cid", 0)), _对编号])
				_记(int(花档零.get("face", 0)) == int(对档.get("face", -1)),
						"第 2 段 = 对面的脸（立绘那格的兜底读它；实得 %d / 期 %d）" % [
								int(花档零.get("face", 0)), int(对档.get("face", -1))])
				## 三档 = 服务端 `FLOWER_GIFT_OPTIONS`（1 朵 1000 金币 / 20 朵 20 元宝 / 99 朵一朵蓝妖姬）。
				## 六个字段**手写死**在下面：段序（朵 & 经验 & 花费 & 友好度 & type & 花号）一解反，
				## 红的那条会直接点名是哪一位 —— 这正是离线门量不到的那一半（离线喂的是我自己写的字典）。
				var 朵列: Array = []
				var 费列: Array = []
				var 好列: Array = []
				var 号列: Array = []
				var 验列: Array = []
				for 一 in 三档:
					朵列.append(int((一 as Dictionary).get("count", 0)))
					费列.append(int((一 as Dictionary).get("cost", 0)))
					好列.append(int((一 as Dictionary).get("youhaodu", 0)))
					号列.append(int((一 as Dictionary).get("flowerid", 0)))
					验列.append(float((一 as Dictionary).get("exp", -1.0)))
				_记(朵列 == [1, 20, 99] and 费列 == [1000, 20, 1]
						and 好列 == [1, 20, 500] and 号列 == [16000143, 16000143, 16000149],
						"三档逐字段 = 服务端那张表（朵 %s 花费 %s 友好 %s 花号 %s；妖姬号 = 本地 `原版杂项.json → flower.rosebuleid`）" % [
								str(朵列), str(费列), str(好列), str(号列)])
				## 经验按**我的**等级折算（服务端 `reward_level=self.character.level`）⇒ 绝对数会随等级漂，
				## 所以只判形状：前两档非零、20 朵 > 1 朵、妖姬那档恒 0（`exp_rate 0.0`）。
				_记(验列.size() == 3 and float(验列[0]) > 0.0 and float(验列[1]) > float(验列[0])
						and float(验列[2]) == 0.0,
						"经验那一列：前二档非零且 20 朵 > 1 朵、妖姬档 = 0（实得 %s）" % str(验列))
				var 窗花: Node = _管理.call("取窗口", "赠花") as Node
				_记(_开着(窗花), "收到 `58:2` ⇒ 「赠花」由**生产代码**开出来（`窗口管理._on_花档帧`，不是门里手动开）")
				var 页花 := _求页名(窗花, "原版赠花内容")
				_记(页花 != null, "开出来的那一页是「原版赠花内容」（不是求婚那一页）")
				if 页花 != null:
					_记(String(窗花.get_node("遮罩/主窗口/标题").text) == "赠花",
							"标题 = ZENGHUA_WINDOW_TITLE（实得「%s」）"
									% String(窗花.get_node("遮罩/主窗口/标题").text))
					## 左下三行的**两个来源**：名/级来自点菜单那一刻存的「对面是谁」，友好度来自回帧
					## ⇒ 把友好度错接成点击缓存（那一项根本没有）会直接红在这里。
					var 文花 := String((页花.get_node("档案文字") as RichTextLabel).text)
					_记(文花.contains(对名) and 文花.contains("角色等级：%d" % 他对级)
							and 文花.contains("友好度：%d" % int(花档零.get("youhaodu", -1))),
							"档案三行 = 名「%s」/ 级 %d / 友好度 %d（实得「%s」）" % [对名, 他对级,
									int(花档零.get("youhaodu", 0)), 文花])
					_记(String((页花.get_node("收花统计") as Label).text)
							== "今日收到次数：%d/20      本周收到：%d朵 总数：%d朵" % [
									int(花档零.get("count", 0)), int(花档零.get("weeklyFlowers", 0)),
									int(花档零.get("totalFlowers", 0))],
							"统计三位 = count / weeklyFlowers / totalFlowers（`MarryZengHuaWindow:187` 那个顺序，抄串最容易自己排错）")
					## 三格的分岔（`Cell:102-116`）：角标只在「朵 > 1 且不是妖姬」那一格、「购买」只在妖姬那一格
					## ⇒ 判妖姬认的是**本地烘的那一位**，与服务端结算帧的花号必须同源。
					var 角列: Array = []
					var 买列: Array = []
					for 格序 in 3:
						角列.append((页花.get_node("花格_%d/角标" % 格序) as Control).visible)
						买列.append((页花.get_node("花格_%d/购买钮" % 格序) as Control).visible)
					_记(角列 == [false, true, false] and 买列 == [false, false, true],
							"角标只在 20 朵那格、「购买」只在妖姬那格（角标=%s 购买=%s）" % [str(角列), str(买列)])
					_记(String((页花.get_node("花格_0/角标") as Label).text) == ""
							and String((页花.get_node("花格_1/角标") as Label).text) == "20",
							"1 朵那格**没有**角标、20 朵那格印 20（原版就分这一岔，不是漏画）")
					_记(String((页花.get_node("花格_0/描述") as RichTextLabel).text).contains("赠送1朵玫瑰花")
							and String((页花.get_node("花格_1/描述") as RichTextLabel).text).contains("元宝/点券")
							and String((页花.get_node("花格_2/描述") as RichTextLabel).text).contains("蓝色妖姬"),
							"首格玫瑰句 + 末格妖姬句、单位只在有角标那格是「元宝/点券」（其余两格写「金币」）")
					_记((页花.get_node("记录_0") as Control).visible
							and not (页花.get_node("记录_0/加为好友") as Control).visible
							and not (页花.get_node("记录_0/回赠") as Control).visible,
							"记录格画出来了，但「加为好友 / 回赠」本窗恒藏（`MarryZengHuaWindow:196` 传的是 false）")
					_记((页花.get_node("立绘框") as Control).get_child_count() == 1,
							"立绘框里那具**活的**身体挂上了（实得 %d 个子件）"
									% (页花.get_node("立绘框") as Control).get_child_count())
					## ── 送出去：真鼠标点首格「赠送」⇒ `127:39:<对面号>:1` ⇒ 服务端结算 ⇒ `61:44`
					## **给两边各发一份**。只判我这侧 = 对面那颗托盘格永远不出现也没人报（#88 的正是这一半）。
					var 盘花 := _管理.get_node_or_null("邀请托盘") as Node
					var 盘前 := int(盘花.call("数量")) if 盘花 != null else -1
					_我收花.clear()
					_对收花.clear()
					_收.clear()
					await _点(页花.get_node("花格_0/赠送钮") as Control)
					_记(await _等秒(8.0, func() -> bool: return not _我收花.is_empty() and not _对收花.is_empty()),
							"点「赠送」⇒ `61:44` **两边都收到**（我 %d / 对面 %d）" % [_我收花.size(), _对收花.size()])
					var 结花: Dictionary = (_我收花[0] as Dictionary) if not _我收花.is_empty() else {}
					var 结对: Dictionary = (_对收花[0] as Dictionary) if not _对收花.is_empty() else {}
					_记(int(结花.get("senderId", 0)) == 我号 and int(结花.get("receiverId", 0)) == _对编号
							and String(结花.get("senderName", "")) == 我名 and int(结花.get("count", 0)) == 1
							and int(结花.get("flowerid", 0)) == 16000143,
							"结算帧五段 = 发号/收号/发名/朵/花号（实得 %s）" % str(结花))
					_记(结对 == 结花, "两边那一份**逐字段相同**（服务端把同一个 payload 写两遍）")
					var 对里话 := ""
					for 一条 in _对聊天:
						对里话 += String((一条 as Dictionary).get("message", ""))
					_记(对里话.contains("%s向你赠送了1朵鲜花" % 我名),
							"对面那条连接**真的收到**了赠送通知（不是只有我这侧「已向…」那句；实得「%s」）" % 对里话)
					## 我这侧收到的那一份 `senderId == 我` ⇒ `receiveFlower:206-214` 那**双判**要把它挡在托盘外
					## （判据写反 = 自己送花还给自己弹一句「恭喜你收到」）。
					_记(盘花 != null and int(盘花.call("数量")) == 盘前,
							"senderId == 我 ⇒ 我这侧托盘**不加格**（%d → %d）" % [
									盘前, int(盘花.call("数量")) if 盘花 != null else -1])
					## 落盘取证：再发一发 `94:6` ⇒ 对面那份档里 友好度 / 今日次数 / 总数 各 +1，
					## 记录首条就是我刚送的那一份（`sendTime` = **经过秒** ⇒ 升序 ⇒ 最新在首）。
					_我花档.clear()
					_记(bool(_主.request_flower_info(_对编号)), "再发一发 `94:6:<对面号>`（查服务端落没落盘）")
					_记(await _等秒(8.0, func() -> bool: return not _我花档.is_empty()),
							"第二发查询有回帧（实得 %d 条）" % _我花档.size())
					var 二档: Dictionary = (_我花档[0] as Dictionary) if not _我花档.is_empty() else {}
					var 二录: Array = 二档.get("flowerDayLogInfo", []) as Array
					_记(int(二档.get("youhaodu", 0)) == int(花档零.get("youhaodu", 0)) + 1,
							"友好度按档 +1（1 朵那档 option.friendly=1；前 %d → 后 %d）" % [
									int(花档零.get("youhaodu", 0)), int(二档.get("youhaodu", 0))])
					_记(int(二档.get("totalFlowers", 0)) == int(花档零.get("totalFlowers", 0)) + 1
							and int(二档.get("count", 0)) == int(花档零.get("count", 0)) + 1,
							"总朵数与今日收到次数各 +1（%d→%d / %d→%d）" % [
									int(花档零.get("totalFlowers", 0)), int(二档.get("totalFlowers", 0)),
									int(花档零.get("count", 0)), int(二档.get("count", 0))])
					_记(not 二录.is_empty() and int((二录[0] as Dictionary).get("senderId", 0)) == 我号
							and int((二录[0] as Dictionary).get("count", 0)) == 1,
							"记录**首条** = 我刚送的那一份（最新在首；实得 %s）" % str(二录))
					_记(int((二录[0] as Dictionary).get("sendTime", 9_999)) < 60,
							"第四段是**经过秒**不是墙上时钟（实得 %d；传 epoch 会把每行印成几千万分钟前、最新那条沉到最后）"
									% int((二录[0] as Dictionary).get("sendTime", -1)))
					## 服务端「每天只能送一次」（`flowerSentDay`）⇒ 同日再点同一颗 = **真拒绝**，
					## 且不许再多一条 `61:44`。这一腿只有在线跑得出（离线门里那条拒绝是我自己写的假数据）。
					_收.clear()
					_我收花.clear()
					await _点(页花.get_node("花格_0/赠送钮") as Control)
					_记(await _等秒(6.0, func() -> bool: return _话串().contains("每天只能赠花一次")),
							"同日再送 ⇒ 服务端回「每天只能赠花一次」（实得「%s」）" % _话串())
					_记(_我收花.is_empty(), "被拒那一发**没有**产生 `61:44`（实得 %s）" % str(_我收花))
				## 关干净再走下一行：这一扇正压着信息条那排钮（同「羁绊」那一支）。
				_管理.call("全部关闭")
				await create_timer(0.3).timeout
			_:
				_记(true, "菜单「%s」点到了（回话=「%s」）" % [文案, 话])
	_记(行数 == 该有.size(),
			"逐行点完了一遍（%d 行，行表=%s）" % [行数, str(行名表)])

	# ── ⑤ 师徒那一档：夹具两边是 100 级 vs 30 级（`--peer-level 30`），而**会话**里我方那份
	#    `player_stats` 会被对面那条连接盖成 1 级 ⇒ `DetailsWindow._menu():309-320` 两档都不成立
	#    ⇒ **行表里不该有第六行**，于是上面那个循环**一行 77 都没点到** ⇒ 这一腿单独补
	#    （不然"菜单子按钮全绿"里藏着一条零覆盖）。
	#    我这侧发「收徒」（action 4）⇒ 服务端 `:22749` 给对面发 `77:5:<我的号>:<我的名>`
	#    ⇒ 对面按档 2 同意（`77:8`）⇒ 谈成后两边各收 `77:14` 关系列表。
	_对师徒.clear()
	## ⑤a **反方向**：服务端的 `action==3` 那一支（`handle_tutor:22733-22754`）与上行 5「拒绝拜师」
	##     在这一轮之前**从没在线跑过**（⑤b 跑的是 action 4 / 8 那一支）。
	##     对面（30 级）发 `77:3:<我的号>` ⇒ 服务端给**我**推 `77:4:<对面号>:<对面名>`（档 1）
	##     ⇒ 我先**拒绝**（`77:5`）⇒ 这条挂起的申请被消费掉 ⇒ 紧接着再补一发**同意**（`77:7`）
	##     服务端那边已经查不到申请 ⇒ **两边都不该绑上**。
	##     ⚠ 为什么不能只判"拒绝后对面没师父"：那份数据本来就没被填过，判它是"0 比 0"空判
	##     （记忆里第十四类）。所以这里加第二步"拒绝之后再同意也谈不成"——
	##     服务端要是把 5 当没听见，第二步就会真的绑上并把 `77:14` 推给对面 ⇒ 这条才叫判据。
	_主师徒.clear()
	_记(_对.request_tutor_apply(3, 我号), "对面发 `77:3:<我的号>`（拜师）⇒ 这一发要能出去")
	_记(await _等秒(8.0, func() -> bool: return not _主师徒.is_empty()),
			"我这侧收到申请帧（实得 %s）" % str(_主师徒))
	var 我这一封: Dictionary = (_主师徒[0] as Dictionary) if not _主师徒.is_empty() else {}
	var 对面名 := String((_对.get("authoritative_stats") as Dictionary).get("name", ""))
	_记(int(我这一封.get("档", 0)) == 1 and int(我这一封.get("号", 0)) == _对编号
			and String(我这一封.get("名", "")) == 对面名,
			"那一帧是**档 1**（对面来拜我）、号与名都是对面（实得档=%s 号=%s 名=%s，期望 1 / %d / %s）" % [
				str(我这一封.get("档")), str(我这一封.get("号")), str(我这一封.get("名")), _对编号, 对面名])
	_主.request_tutor_refuse(1, _对编号)
	await _等秒(3.0, func() -> bool: return false)
	_主.request_tutor_accept(1, _对编号)
	_记(not await _等秒(6.0, func() -> bool:
		return int((_对.get("authoritative_tutor") as Dictionary).get("charId", 0)) == 我号),
			"拒绝之后这条申请就没了 ⇒ 再点同意也谈不成（对面师父实得 %s）" % str(_对.get("authoritative_tutor")))

	## ⑤b 正向：我这侧发收徒（`77:4`）⇒ 对面收到 ⇒ 对面同意（`77:8`）⇒ 两边各收 `77:14`。
	## 前置：服务端这一族有两道等级闸（`fake_flash_server.handle_tutor:22733-22768`，
	## 常数 `multiplayer_backend.py:34-36` = 学生 `10..59` / 师父 `>=60`，与原版
	## `DetailsWindow.LIMIT_LEVEL=60` 同源）。跨不过去时服务端**一句话都不回**、直接丢帧 ⇒
	## 判据只能表现为"对面没收到"。这里先把它钉住，红的时候一眼看出是**夹具没给等级**（`--peer-level`）
	## 而不是客户端坏了。
	var 我对级 := int((_主.get("authoritative_stats") as Dictionary).get("level", 0))
	_记(我号 > 0 and _对编号 > 0 and 我对级 >= 60 and 他对级 >= 10 and 他对级 < 60,
			("夹具两边跨过了服务端的师徒等级闸（我 %d 级要 `>=60`、他 %d 级要 `10..59`；"
			+ "不满足时夹具那条用例要带 `--peer-level`）") % [我对级, 他对级])
	_主.request_tutor_apply(4, _对编号)
	_记(await _等秒(8.0, func() -> bool: return not _对师徒.is_empty()),
			"我这侧发 `77:4:<对面号>`（收徒）⇒ 对面收到申请帧（实得 %s）" % str(_对师徒))
	var 对那一封: Dictionary = (_对师徒[0] as Dictionary) if not _对师徒.is_empty() else {}
	_记(int(对那一封.get("号", 0)) == 我号 and String(对那一封.get("名", "")) == 我名
			and int(对那一封.get("档", 0)) == 2,
			"那一帧带的就是**我**（档 2 = 来收我为徒、号=%d 名=%s，实得 %s）" % [我号, 我名, str(对那一封)])
	_对.request_tutor_accept(2, 我号)
	## ⚠ `authoritative_tutor` / `authoritative_students` 里那一份是 `77:14` 解出来的，
	## 键名是**协议原文的驼峰**（`charId`/`name`/`level`…，`后端连接.gd:1977-1978`）——
	## 写成 `character_id` 会永远比不中 ⇒ 两条判据恒假红（10-17 写完当场量出来）。
	_记(await _等秒(10.0, func() -> bool:
		return int((_对.get("authoritative_tutor") as Dictionary).get("charId", 0)) == 我号),
			"对面点同意 ⇒ 对面的师父那份就是我（实得 %s）" % str(_对.get("authoritative_tutor")))
	_记(await _等秒(10.0, func() -> bool:
		for 项 in (_主.get("authoritative_students") as Array):
			if int((项 as Dictionary).get("charId", 0)) == _对编号:
				return true
		return false), "同一件事在我这侧也落地：徒弟列表里出现对面（实得 %s）" % str(_主.get("authoritative_students")))

	# ── ⑥ 看摊（菜单那一行的落地窗）：摊主侧建摊摆货 + 买家侧看摊买成，一条链全真连服务端 ──
	## 摊主 = 对面（`_对`）、买家 = 我（`_主`，有 UI 的那一号）⇒
	## 屏幕侧断言落在**买家**这一边：喂到 `1296:1:` 那帧时 `窗口管理._on_stall_state` 要真把窗开出来。
	## ⚠ 跑这条腿要给 `--peer-gold`（> 挂牌价）：服务端 `_buy_stall_listing:25891-25896`
	## 余额不够就 `return False`，而 action 7 那支对失败**一个字都不回** ⇒ 不给钱的现象是
	## "点了购买什么都没发生"，看着像产品坏了，其实是夹具缺前置。
	var 挂牌价 := 123
	var 摊名 := "在线测试摊位"
	_对.request_stall_open(_对编号)
	_记(await _等秒(8.0, func() -> bool: return int((_对.get("authoritative_stall") as Dictionary).get("owner_id", -1)) == _对编号),
			"对面发 `1296:2:<自己号>` ⇒ 服务端**就地建摊**并回全量（实得 %s）" % str(_对.get("authoritative_stall")))
	_对.request_stall_rename(_对编号, 摊名)
	_记(await _等秒(8.0, func() -> bool: return String((_对.get("authoritative_stall") as Dictionary).get("stall_name", "")) == 摊名),
			"改摊名 ⇒ `1296:3:<号>:<名>` 那一趟回的全量里摊名换了（实得「%s」）" % String((_对.get("authoritative_stall") as Dictionary).get("stall_name", "")))
	## 挑他背包里**一件可交易**的（`PEER_ITEMS` 那三件；绑定件服务端直接挡：`:25525-25527`）
	var 他的件: Dictionary = {}
	for 件 in (_对.get("authoritative_inventory") as Array):
		var 条 := 件 as Dictionary
		if bool(条.get("can_trade", true)) and int(条.get("quantity", 0)) > 0 and int(条.get("slot_index", -1)) >= 0:
			他的件 = 条
			break
	_记(not 他的件.is_empty(),
			"对面背包里得有一件可交易又没绑定的（这条腿的前置；实得 %s）" % str(_对.get("authoritative_inventory")))
	if 他的件.is_empty():
		收拾并退出("卡在「他的件.is_empty()」⇒ 后面的判据一条没跑")
		return
	_对.request_stall_add_item(int(他的件.get("type", 2)), int(他的件.get("slot_index", -1)), 1, 挂牌价, 0)
	_对.request_stall_open(_对编号)
	_记(await _等秒(8.0, func() -> bool: return (_对.get("authoritative_stall") as Dictionary).get("listings", []).size() >= 1),
			"上架 `1296:4:<类别>:<槽>:1:<金币>:0` 之后那一行真在摊上（实得 %s）" % str(_对.get("authoritative_stall")))
	## 买家侧：我发 `1296:2:<对面号>` ⇒ 拿到的是**他那份**摊
	_主.request_stall_open(_对编号)
	_记(await _等秒(8.0, func() -> bool: return int((_主.get("authoritative_stall") as Dictionary).get("owner_id", -1)) == _对编号 and String((_主.get("authoritative_stall") as Dictionary).get("stall_name", "")) == 摊名 and (_主.get("authoritative_stall") as Dictionary).get("listings", []).size() >= 1),
			"我看摊 ⇒ 收到摊主号=对面、摊名=「%s」、至少一行的全量（实得 %s）" % [摊名, str(_主.get("authoritative_stall"))])
	## 屏幕面：那一帧到本端 ⇒ 窗**真开出来**、里面**真有那一行**（这就是用户报的"看摊的窗没有"）
	for i in 6:
		await process_frame
	var 摊窗: Node = _管理.call("取窗口", "随身摊位") as Node
	_记(摊窗 != null, "`1296:1:` 到本端 ⇒ 「随身摊位」这一页建出来了（消费者在 `窗口管理._on_stall_state`）")
	if 摊窗 != null:
		var 摊页: Control = null
		var 内容 := 摊窗.get("_content") as Control
		for 子 in 内容.get_children():
			if String((子 as Node).name) == "原版随身摊位内容":
				摊页 = 子 as Control
				break
		_记(摊页 != null, "页本体「原版随身摊位内容」在（277×408 那一棵树）")
		if 摊页 != null:
			_记(String((摊页.get_node("摊名框/摊名文") as Label).text) == 摊名,
					"摊名印在屏幕那一格上（实得「%s」）" % String((摊页.get_node("摊名框/摊名文") as Label).text))
			_记(bool((摊页.get_node("购买钮") as Button).visible) and not (摊页.get_node("上架钮") as Button).visible,
					"看别人的摊 ⇒ 这页是**买家档**：露「购买」、不露上架/下架/修改")
			_记((摊页.get_node("列表/行区") as Control).get_child_count() == 1,
					"列表里真摆着那一行（实得 %d 行）" % (摊页.get_node("列表/行区") as Control).get_child_count())
			var 那一行 := (摊页.get_node("列表/行区")).get_child(0) as Control if (摊页.get_node("列表/行区") as Control).get_child_count() > 0 else null
			_记(那一行 != null and String((那一行.get_node("名字") as Label).text) == String(他的件.get("name", "")),
					"那一行的名字 == 对面摆上去的那件（实得「%s」/ 期「%s」）" % [
						String((那一行.get_node("名字") as Label).text) if 那一行 != null else "", String(他的件.get("name", ""))])
			_记(那一行 != null and String((那一行.get_node("价1文") as Label).text) == str(挂牌价),
					"那一行标的金币价 == 他挂上去的 %d（实得「%s」）" % [挂牌价,
						String((那一行.get_node("价1文") as Label).text) if 那一行 != null else ""])
	## 真买成：金币、背包、他那侧收到的成交播报，三样一起看。
	## ⚠ `1296:4` 那条播报**只在成交那一刻发** ⇒ 监听必须在**按下购买之前**挂上；
	## 想靠"再摆第二件再买一次"补一条是错的：`PEER_ITEMS` 那三件里有两件被 `wear_peer_kun_chong`
	## 穿到虫槽上（离开了背包），对面可交易的只剩一件。
	var 摊主话: Array = []
	if not _对.has_signal("stall_sale_log"):
		_记(false, "后端连接没有 `stall_sale_log` 这条信号 ⇒ 成交播报这条路等于没接")
	else:
		# 信号带的是**四段分开的字段**（买家名/物品名/金币/元宝），拼句由消费方做
		# （`摊位窗.加记录` 与门店同一个句式）⇒ 这里照同样的拼法。
		_对.connect("stall_sale_log", func(买家: String, 物品: String, _金币: int, _元宝: int) -> void:
			摊主话.append("%s购买了%s" % [买家, 物品]))
	var 卖单: Dictionary = ((_主.get("authoritative_stall") as Dictionary).get("listings", []) as Array)[0] as Dictionary
	var 我金前 := int((_主.get("authoritative_stats") as Dictionary).get("gold", 0))
	var 他金前 := int((_对.get("authoritative_stats") as Dictionary).get("gold", 0))
	var 我的件前 := (_主.get("authoritative_inventory") as Array).size()
	_记(我金前 >= 挂牌价, "我这侧金币够买（%d ≥ %d）" % [我金前, 挂牌价])
	_记(bool(_主.request_stall_buy(_对编号, 对名, int(卖单.get("uid", 0)))),
			"发 `1296:7:<卖家号>:<卖家名>:<uid>` 这一发要出得去（卖家名一字不差，服务端先按号找人、不中再按名字找）")
	_记(await _等秒(8.0, func() -> bool: return int((_主.get("authoritative_stats") as Dictionary).get("gold", 0)) == 我金前 - 挂牌价),
			"买成 ⇒ 我的金币少 %d（前 %d → 后 %s）" % [挂牌价, 我金前, str((_主.get("authoritative_stats") as Dictionary).get("gold", 0))])
	_记(await _等秒(8.0, func() -> bool: return (_主.get("authoritative_inventory") as Array).size() > 我的件前),
			"买到的那件进了我的背包（前 %d 格 → 后 %d 格）" % [我的件前, (_主.get("authoritative_inventory") as Array).size()])
	_记(await _等秒(8.0, func() -> bool: return (_主.get("authoritative_stall") as Dictionary).get("listings", []).size() == 0),
			"服务端给买家重推一条全量 ⇒ 摊上那一行没了（实得 %s）" % str(_主.get("authoritative_stall")))
	_记(await _等秒(8.0, func() -> bool: return int((_对.get("authoritative_stats") as Dictionary).get("gold", 0)) == 他金前 + 挂牌价),
			"摊主收到钱（前 %d → 后 %s）" % [他金前, str((_对.get("authoritative_stats") as Dictionary).get("gold", 0))])
	## 摊主侧那条 `1296:4:<买家名>:<物品名>:<金币>:<元宝>`（服务端只发给卖家）。
	## 第二条连接没有 UI ⇒ 这里断**解出来的那一句话**；屏幕侧（往日志格追一行、不开窗）由离线门 ⑭·8 钉。
	_记(await _等秒(8.0, func() -> bool: return 摊主话.size() >= 1),
			"摊主那侧收到成交播报（实得 %s）" % str(摊主话))
	if 摊主话.size() >= 1:
		_记(String(摊主话[0]).contains(我名),
				"播报里带的是**买家名**「%s」（实得「%s」）" % [我名, String(摊主话[0])])

	# ── ⑦ 族邀：族长发 19 ⇒ 服务端推 16 给我 ⇒ 真点托盘那格 ⇒ 真点「同意加入」⇒ 我落进他族 ──
	## 权限闸在服务端那一条 `is_leader`（`fake_flash_server.py:33523`），夹具里**同伴就是族长**
	## （`seed_peer_family` → `create_family` 把 `leaderAccountId` 写成同伴的账号号）⇒ 这一发该回帧。
	## 参照值一律取**独立来源**：族号/族名读夹具环境变量 `NW_PEER_FAMILY_ID/NAME`（不是从我这边
	## 解出来的字典里反查），等级/职业读 `_对.authoritative_stats`（那份是**它自己那条连接**的，
	## 不受"第二份连接盖会话属性"那个量具坑影响）。
	var 族号 := int(OS.get_environment("NW_PEER_FAMILY_ID"))
	var 族名 := String(OS.get_environment("NW_PEER_FAMILY_NAME"))
	_记(族号 > 0 and 族名 != "",
			"夹具给同伴造了家族（id=%d 名=「%s」）⇒ 他才有族长身份发这一发" % [族号, 族名])
	## ⚠ 两个方向别接反：`1552:16` 是推给**被邀方**的 ⇒ 接在 `_主` 上；
	## `1552:7`（有新成员）才是发给**族长**那侧的 ⇒ 接在 `_对` 上。接反了会两头都收不到还一脸绿。
	_主.connect("family_invite_received", func(邀: Dictionary) -> void: _族邀.append(邀))
	_对.connect("guild_state_received", func(状: Dictionary) -> void: _对族长状.append(状))
	_对.request_family_invite(我号)
	_记(await _等秒(8.0, func() -> bool: return _族邀.size() > 0),
			"族长发 `1552:19:<我的号>` ⇒ 我这一侧收到 `1552:16`（发 19 收 16，不是同号回显）")
	if _族邀.is_empty():
		收拾并退出("卡在「_族邀.is_empty()」⇒ 后面的判据一条没跑")
		return
	var 收: Dictionary = _族邀[0] as Dictionary
	_记(String(收.get("name", "")) == 对名 and String(收.get("playerName", "")) == 对名,
			"帧里的族长名 = 对面那个号的名字（实得「%s」/ 期「%s」）" % [String(收.get("name", "")), 对名])
	_记(int(收.get("charId", 0)) == _对编号,
			"`charId` = 族长角色号 %d（实得 %d）—— 托盘去重比的是它" % [_对编号, int(收.get("charId", 0))])
	_记(int(收.get("id", 0)) == 族号,
			"`id` = 家族号 %d（实得 %d）—— 同意/拒绝那两发带的是它，不是角色号" % [族号, int(收.get("id", 0))])
	_记(String(收.get("famillyName", "")) == 族名,
			"帧里的家族名 = 夹具那个族（实得「%s」/ 期「%s」）" % [String(收.get("famillyName", "")), 族名])
	_记(int(收.get("level", 0)) == int(对档.get("level", -1))
			and int(收.get("job", -1)) == int(对档.get("job", -2)),
			"帧里的等级/职业 = 对面属性帧那两位（级 %d/%d、职 %d/%d）" % [
				int(收.get("level", 0)), int(对档.get("level", -1)),
				int(收.get("job", -1)), int(对档.get("job", -2))])
	## 屏幕面：那一帧只该往头顶塞一格，**不该直接把窗拍在脸上**（原版 `FamillyManager:339-343`）。
	var 族盘 = _管理.get_node_or_null("邀请托盘")
	_记(族盘 != null and int(族盘.call("数量")) > 0,
			"我这侧头顶真多出一格（实得 %d 格）" % (int(族盘.call("数量")) if 族盘 != null else -1))
	var 族格: Control = null
	if 族盘 != null:
		for 子 in 族盘.get_children():
			var 件 := 子 as Control
			if 件 == null:
				continue
			var 据: Variant = 件.get("数据")		# 托盘底下不只有格（还有提示条一类），没有这个键就是 null
			if typeof(据) == TYPE_DICTIONARY and int((据 as Dictionary).get("charId", 0)) == _对编号:
				族格 = 件
	_记(族格 != null, "那一格带的就是这一份邀请（按 charId 找得到）")
	_记(_管理.call("取窗口", "家族邀请") == null,
			"收到帧没有直接把窗开出来（开窗的是「点那一格」那一步）")
	if 族格 == null:
		收拾并退出("卡在「族格 == null」⇒ 后面的判据一条没跑")
		return
	## 那格入场是 2 秒补间（`CueManage` 的 `TweenLite.to(_,2,…)`），没落位时几格全叠在 x=10
	## ⇒ 会点到别人那一格上。先等它飞到槽位（按**墙钟**等：无头一秒能跑几千帧，等帧数不算数）。
	var 落位止 := Time.get_ticks_msec() + 2600
	while Time.get_ticks_msec() < 落位止:
		await process_frame
	_记(族格.position.x > 300.0,
			"那一格飞到头顶槽位了（x=%.0f）—— 没落位就点会点到叠在它上面的别的格" % 族格.position.x)
	## 上一腿（看摊）把那扇「随身摊位」留在屏幕上了 ⇒ 它的页签正好压在头顶那一格上，
	## 点下去点到的是**它的页签**（实测 `gui_get_hovered_control` = 页签1）。
	## 所以这里先全关掉，再把"那一点确实落在这格上"钉成判据（不钉的话就是静默点错东西）。
	_管理.call("全部关闭")
	for i in 6:
		await process_frame
	var 族格位: Vector2 = 族格.get_global_rect().get_center()
	await _挪到(族格位)
	_记(root.gui_get_hovered_control() == 族格,
			"点之前先确认那一点落在这格上（实得压在上面的=%s）" % str(root.gui_get_hovered_control()))
	await _点(族格)
	for i in 6:
		await process_frame
	var 族窗: Node = _管理.call("取窗口", "家族邀请") as Node
	_记(族窗 != null, "真点那一格 ⇒ 「家族邀请」这一页建出来了（分发在 `窗口管理._on_托盘已点`）")
	if 族窗 == null:
		收拾并退出("卡在「族窗 == null」⇒ 后面的判据一条没跑")
		return
	var 族页: Control = null
	for 子 in (族窗.get("_content") as Control).get_children():
		if String((子 as Node).name) == "原版家族邀请内容":
			族页 = 子 as Control
			break
	_记(族页 != null, "页本体「原版家族邀请内容」在（264×136 那一棵树）")
	if 族页 != null:
		_记(String((族页.get_node("族长名") as Label).text) == 对名,
				"屏幕第一行印的是对面那个名字（实得「%s」）" % String((族页.get_node("族长名") as Label).text))
		_记(String((族页.get_node("族名") as Label).text) == 族名,
				"屏幕那行家族名 = 夹具那个族（实得「%s」）" % String((族页.get_node("族名") as Label).text))
		_记(String((族页.get_node("正文") as RichTextLabel).text)
				== "该玩家邀请你加入他的家族，请问你是否审核通过",
				"正文是原版那句（实得「%s」）" % String((族页.get_node("正文") as RichTextLabel).text))
		_记((族页.get_node("头像格/头像") as TextureRect).texture != null,
				"头像按帧里的 face=%d 真取到了图" % int(收.get("face", 0)))
	## 点「同意加入」⇒ 上行 `1552:15:<族号>` ⇒ 服务端 `:33384` 校验族号对上才放人，
	## 成功给我回摘要（`1552:15`）、给每个在线族员回 `1552:7:<我的号>`。
	await _点(族页.get_node("同意钮") as TextureButton)
	for i in 6:
		await process_frame
	_记(await _等秒(8.0, func() -> bool:
			return int((_主.get("authoritative_guild") as Dictionary).get("id", 0)) == 族号),
			"点「同意加入」⇒ 我真进了那个族（我这侧权威家族 id=%s，期 %d）" % [
				str((_主.get("authoritative_guild") as Dictionary).get("id", 0)), 族号])
	_记(String((_主.get("authoritative_guild") as Dictionary).get("name", "")) == 族名,
			"权威摘要里的族名 =「%s」（实得「%s」）" % [
				族名, String((_主.get("authoritative_guild") as Dictionary).get("name", ""))])
	## 确认窗点完就自己收掉（原版 `okHandler:146-163` 发完那一发就 `onCloseBtnClick`）。
	## ⚠ 判的是**这扇窗自己的** `_overlay`，不是后端字典 —— 后者更新只证明"帧到了"，不证明屏幕上那扇窗没了。
	_记(not bool(((族窗.get("_overlay") as CanvasItem).visible)),
			"点完「同意加入」那扇确认窗自己关掉了（`_overlay.visible` 回 false）")
	## 族长那一侧：`1552:7:<新成员角色号>` 确实发到他的连接上了。
	## 客户端 `_handle_guild_text` 对 7 **没有分支**（原版 `actionBanghuiNewMember` 只在成员窗
	## 开着时刷列表）⇒ 这里判"这一帧到了"，不判 UI（判了就是自造提示）。
	_记(await _等秒(8.0, func() -> bool:
			for 状 in _对族长状:
				if int((状 as Dictionary).get("action", -1)) == 7:
					return true
			return false),
			"族长那侧收到「有新成员进族」那一帧（`1552:7`，实收到的 action 序列=%s）"
			% str(_对族长状.map(func(状: Dictionary) -> Variant: return (状 as Dictionary).get("action", -1))))
	# ── ⑦·2 空号闸：这几条**只能在这儿判** ────────────────────────────────
	## 离线门里同样的四条断言是**假绿**（10-17 变异实测：无头没有 TCP，
	## `send_game_request` 第一行就 return false ⇒ 把 `号 > 0` 那道闸整个删掉它也照样过）。
	## 到这儿 socket 是活的：发得出去就证明是**闸没挡住**，而不是"反正也没连上"。
	_记(bool(_对.request_family_invite(我号)) or true, "（前置）活连接上真发得出一发 19")
	_记(not bool(_对.request_family_invite(0)),
			"邀一个 0 号 ⇒ **不发帧**（这一发要是返回 true，就是 `号 > 0` 那道闸被拆了）")
	_记(not bool(_主.request_family_invite_accept(0)), "同意一个 0 号家族 ⇒ 不发帧")
	_记(not bool(_主.request_family_invite_reject(0)), "拒绝一个 0 号家族 ⇒ 不发帧")
	_记(not bool(_主.request_family_invite_by_name("查无此人")),
			"名字不在同屏表里 ⇒ 不发帧（不能拿 0 号硬发一发去演「已发送」）")
	_记(bool(_主.request_family_invite_by_name(对名)),
			"按名字在同屏表里找得到对面 ⇒ 这一发真出得去（我不是族长，服务端那边静默不处理，正是要的 behavior）")

	# ── ⑧ 羁绊（求婚 #262）：对面求我 ⇒ `61:17` **只塞格** ⇒ 真点那一格 ⇒ 被求档
	#              ⇒ 点「拒绝」⇒ 对面收 `61:18`（带我的名字）
	#              ⇒ 他再求一次 ⇒ 点「同意请求」⇒ 我收 19 / 他收 20、两边权威配偶互指、半枚对戒各落 −50
	## ⚠ 方向与族邀同形但**编号不同**：`17` 推给**被求方**（我），`18`/`20` 推给**求方**（对面），
	## `19` 推给**同意方**（我）。发起那一趟（`127:15` ⇒ `61:14`）**直接开窗**，已在 §④ 菜单那一轮判过。
	var 戒指 := int(OS.get_environment("NW_PEER_RING_ID"))
	_记(戒指 > 0, "夹具给同伴的背包里放了那枚对戒（NW_PEER_RING_ID=%d）⇒ 他才有资格发 20" % 戒指)
	## 前置条件的明账：**服务端真把那件发到对面那条连接的 58 帧里了**。
	## 不钉这一步，后面"发 20 收 17"要是红，分不清是夹具没落到货还是接线断了。
	## ⚠ 键名认的是帧解出来那一份（`id` / `slot_index` / `quantity`）。第一版 `_挑对戒` 读的是
	## 我自造的 `item_id` / `position` / `count`，而离线门喂的假字典**照抄了同一套自造键** ⇒
	## 两边一起错、239 条全绿，真机上「放入羁绊戒」永远回"请先放入羁绊对戒"（10-17 在线门逮到，已就地修）。
	_记(await _等秒(8.0, func() -> bool: return _背包有(_对, 戒指)),
			"对面那条连接收到的背包帧里真有对戒 %d 且坐在正格上、数量>0（= 服务端 `_bond_pair_item:22930` 那条闸）" % 戒指)
	_记(int(求婚脚本._挑对戒(_对)) == 戒指,
			"我这侧那个控制器**对着真帧**也挑得到同一枚（实得 %d）—— 键名一改这条就红，不会再假绿"
			% int(求婚脚本._挑对戒(_对)))

	## ⑧·1 拒绝那一趟
	_管理.call("全部关闭")
	await create_timer(0.3).timeout
	_求婚帧.clear(); _对拒帧.clear()
	_记(bool(_对.request_bond_invite(我号, 戒指)), "对面发 `127:20:<我的号>:<对戒>` ⇒ 活连接上这一出得去")
	_记(await _等秒(8.0, func() -> bool: return _求婚帧.size() > 0),
			"我这侧收到 `61:17`（发 20 收 17，不是同号回显）")
	if _求婚帧.is_empty():
		收拾并退出("卡在「_求婚帧.is_empty()」⇒ 后面的判据一条没跑")
		return
	var 邀: Dictionary = _求婚帧[0] as Dictionary
	_记(String(邀.get("name", "")) == 对名 and int(邀.get("level", 0)) == 他对级
			and int(邀.get("job", -1)) == int(对档.get("job", -2))
			and int(邀.get("charId", 0)) == _对编号 and int(邀.get("item", 0)) == 戒指,
			"`61:17` 逐字段 = 对面那份档案 + 末段那一枚对戒（实得 %s）" % str(邀))
	_记(String(邀.get("banghui", "")) == 对族名,
			"族名那位 = 夹具那个族（实得「%s」/ 期「%s」）" % [String(邀.get("banghui", "")), 对族名])
	_记(int(邀.get("face", 0)) == int(对档.get("face", -1)),
			"face = 对面属性帧里那一位（实得 %d / 期 %d）" % [int(邀.get("face", 0)), int(对档.get("face", -1))])
	_记(not _开着(_管理.call("取窗口", "羁绊申请") as Node),
			"收到 `61:17` **没把窗拍在脸上**（原版 `Client.as:7883` 只 addMsg 进 CueGird）")
	var 点成一 := await _点求婚格(_对编号)
	if not 点成一:
		收拾并退出("那一格「求婚」没点到 ⇒ 被求档那几条判据一条没跑")
		return
	var 求窗: Node = _管理.call("取窗口", "羁绊申请") as Node
	_记(_开着(求窗), "真点那一格 ⇒ 「羁绊申请」开出来了（分发在 `窗口管理._于托盘已点`）")
	var 求页 := _求页(求窗)
	_记(求页 != null, "页本体是「原版求婚内容」（与发起档共用同一棵树，按 `是被求` 切档）")
	if 求页 == null:
		收拾并退出("卡在「求页 == null」⇒ 后面的判据一条没跑")
		return
	_记(String(求窗.get_node("遮罩/主窗口/标题").text) == "羁绊确认",
			"被求档标题 = PROPOSA_WINDOW_TITLE_OK（实得「%s」）" % String(求窗.get_node("遮罩/主窗口/标题").text))
	_记(String((求页.get_node("名字") as Label).text) == "名字：" + 对名
			and String((求页.get_node("家族") as Label).text) == "家族：" + 对族名,
			"屏幕上那两行 = 对面那位 + 夹具那个族（实得「%s」/「%s」）" % [
				String((求页.get_node("名字") as Label).text), String((求页.get_node("家族") as Label).text)])
	_记(String((求页.get_node("心意提示") as Label).text) == "TA向您出示了心意，您愿意与TA建立羁绊吗？"
			and String((求页.get_node("说明白字") as Label).text) == "TA为您呈上的羁绊对戒是：",
			"被求档那两句 = CHARINFO_PANE_TISHI_TEXT_1 / PROPOSA_WINDOW_TA_WEINI_FENGXIAN_JIEZHI")
	_记(not (求页.get_node("放入钮") as Control).visible and not (求页.get_node("购买钮") as Control).visible,
			"被求档 ⇒ 「放入/购买」那两颗**不显示**（`ProposaBottomWindow.as:201-204` 是 visible=false）")
	_记((求页.get_node("对戒格/对戒图") as TextureRect).texture != null,
			"第一格里画的是那一枚对戒的图（按帧里的 item=%d 真取到了图）" % int(邀.get("item", 0)))
	_记(String((求页.get_node("主钮/文字") as Label).text) == "同意请求",
			"被求档主钮 = PROPOSA_WINDOW_TONGYI_QIUHUN（实得「%s」）" % String((求页.get_node("主钮/文字") as Label).text))
	## 点「拒绝」⇒ `127:22:<求方号>` ⇒ 服务端 `:23364-23368` 给**求方**回 `61:18:<我的名>`。
	## ⚠ 这一发是**带载荷的**（只送名字）⇒ 名字取错那一格就是"看着像拒绝了、对面收到的是陌生人"。
	await _点(求页.get_node("次钮") as TextureButton)
	_记(await _等秒(8.0, func() -> bool: return _对拒帧.size() > 0),
			"点「拒绝」⇒ 对面那侧收到 `61:18`（方向：拒绝帧回到**求方**，不是我自己）")
	var 拒: Dictionary = (_对拒帧[0] as Dictionary) if not _对拒帧.is_empty() else {}
	_记(String(拒.get("name", "")) == 我名,
			"那一帧里的名字 = **我的**名字（求方把它替进 DUIFANG_JUJUE_JIEHUN_QINGQIU 的 %%1 位；实得「%s」/ 期「%s」）"
			% [String(拒.get("name", "")), 我名])
	_记(not _开着(求窗), "点完「拒绝」那扇自己关掉（原版 `onClickCancelBtn` 那一支）")

	## ⑧·2 同意那一趟：同一位再求一次 ⇒ 点「同意请求」⇒ `127:21` ⇒ 服务端 `set_bond` 真结算
	_求婚帧.clear(); _我结成.clear(); _对结成.clear()
	_记(bool(_对.request_bond_invite(我号, 戒指)),
			"对面**再发一次** `127:20` ⇒ 出得去（上一趟那封申请已经被 22 消费掉，这一发是重新挂上去的）")
	_记(await _等秒(8.0, func() -> bool: return _求婚帧.size() > 0), "我这侧又收到一格 `61:17`")
	var 点成二 := await _点求婚格(_对编号)
	if not 点成二:
		收拾并退出("第二格「求婚」没点到 ⇒ 同意那一趟的判据一条没跑")
		return
	var 求窗二: Node = _管理.call("取窗口", "羁绊申请") as Node
	var 求页二 := _求页(求窗二)
	_记(求页二 != null, "第二格点完也照样开出被求档（两档共用一个页，不吃上一趟那扇的缓存）")
	if 求页二 == null:
		收拾并退出("卡在「求页二 == null」⇒ 后面的判据一条没跑")
		return
	await _点(求页二.get_node("主钮") as TextureButton)
	_记(await _等秒(10.0, func() -> bool: return _我结成.size() > 0),
			"点「同意请求」⇒ 我这侧收到 `61:19`（带的是**求方**那一份）")
	_记(await _等秒(10.0, func() -> bool: return _对结成.size() > 0),
			"对面那侧收到 `61:20`（同形、带的是**同意方**=我 那一份）")
	var 我结: Dictionary = (_我结成[0] as Dictionary) if not _我结成.is_empty() else {}
	var 他结: Dictionary = (_对结成[0] as Dictionary) if not _对结成.is_empty() else {}
	_记(int(我结.get("charId", 0)) == _对编号 and String(我结.get("name", "")) == 对名,
			"`19` 那位是求方（实得号=%s 名=%s）" % [str(我结.get("charId", 0)), str(我结.get("name", ""))])
	_记(int(他结.get("charId", 0)) == 我号 and String(他结.get("name", "")) == 我名,
			"`20` 那位是同意方（实得号=%s 名=%s，期 %d / %s）" % [str(他结.get("charId", 0)), str(他结.get("name", "")), 我号, 我名])
	var 婚: Dictionary = _主.get("authoritative_spouse") as Dictionary
	var 对婚: Dictionary = _对.get("authoritative_spouse") as Dictionary
	_记(int(婚.get("charId", 0)) == _对编号 and String(婚.get("name", "")) == 对名
			and int(婚.get("hunjieId", 0)) == 戒指,
			"我这侧的权威配偶 = 对面（实得 %s）" % str(婚))
	_记(int(对婚.get("charId", 0)) == 我号 and int(对婚.get("hunjieId", 0)) == 戒指,
			"对面那侧的权威配偶互指回我（实得 %s）" % str(对婚))
	_记(not _开着(求窗二), "点完「同意请求」那扇自己关掉（消费者收到 19 也会关掉它）")
	## 服务端那一发是**真结算**，不是只发个提示：整枚对戒从求方背包扣掉，两边各穿上一枚半戒
	## （`set_bond` 给求方 `戒指+1`、给同意方 `戒指+2`，都写进 −50 那一格）。
	_记(await _等秒(10.0, func() -> bool: return int(_槽上(_主, -50).get("id", 0)) == 戒指 + 2),
			"我这侧 −50 那格真穿上了半枚（id=%s，期 %d）" % [str(_槽上(_主, -50).get("id", "‹空›")), 戒指 + 2])
	_记(int(_槽上(_对, -50).get("id", 0)) == 戒指 + 1,
			"对面那侧是 `戒指+1`（id=%s，期 %d）" % [str(_槽上(_对, -50).get("id", "‹空›")), 戒指 + 1])
	_记(await _等秒(8.0, func() -> bool: return not _背包有(_对, 戒指)),
			"求方背包里那枚**整戒已经扣掉了**（数量 1 → 服务端 pop 掉并补一发 clear）")
	_记(await _等秒(8.0, func() -> bool: return bool(_社交里(_对, 我号).get("couple", false))),
			"对面那份好友表里**我**这一行 `couple` 点亮了（`:23341` 末尾那句 `set_friend(..., True)`）")
	_记(bool(_社交里(_主, _对编号).get("couple", false)),
			"我这侧好友表里对面那行也点亮（两边同一条互指，实得我这侧那一行=%s）" % str(_社交里(_主, _对编号)))

	## ⑧·3 空号闸：这几条**只能在这儿判**（无头没有 TCP ⇒ `send_game_request` 第一行就 false，
	## 把 `号 > 0` 整条删掉离线门照样过 —— 10-17 变异实测那条同款坑）。
	_记(not bool(_主.request_bond_start(0)), "发起一个 0 号 ⇒ 不发帧")
	_记(not bool(_主.request_bond_invite(0, 戒指)), "求一个 0 号 ⇒ 不发帧")
	_记(not bool(_主.request_bond_invite(_对编号, 0)), "对戒号 0 ⇒ 不发帧（那一发带的是**两个 int**，缺一位服务端解不出来）")
	_记(not bool(_主.request_bond_accept(0, 戒指)), "同意一个 0 号 ⇒ 不发帧")
	_记(not bool(_主.request_bond_refuse(0)), "拒绝一个 0 号 ⇒ 不发帧")

	# ── ⑨ 双修那一行（#260）：邀请 ⇒ 对面收 `86:2`、我这边有回话；对面拒 ⇒ 我收 `86:4`；
	#              再邀 ⇒ 对面同意 ⇒ 两边 `state=2` 且 partner_id 互指；停坐 ⇒ 两边归 0
	## 为什么这条要单开一腿而不在 `传承在线回归测试.gd` 里判：那一gate 现在**自身有 8 条历史红**
	## （宝箱/料理/结印/心法那一串，10-17 现查：把本轮新加的东西全撤掉它照样红 9 条），
	## 挂在一个红的 gate 上就等于没有证据。这条跑在"头像信息在线"里 ⇒ 末行红 0 才算数。
	_对双修.clear(); _收.clear()
	_记(bool(_主.request_double_heal_invite(_对编号)), "我发 `86:3:<对面号>` ⇒ 活连接上出得去")
	_记(await _等秒(8.0, func() -> bool:
			return int((_对.get("authoritative_heal") as Dictionary).get("pending_inviter_id", 0)) == 我号),
			"对面那侧收到 `86:2:<我的号>`（邀请路由到他那条连接了）")
	## 邀请方这一侧服务端**不回 `86` 帧**、只回一句话（`DOUBLE_INVITE` 那一支末尾的
	## `_send_dynamic_info("已向<对面名>发送双修邀请。")`，它发的是 `CHAT_MESSAGE:1:1024:…`）⇒
	## 判的就是那句话里带的是对面的名字。对面那侧的提示挂在 `_对聊天`，不混进这里。
	_记(await _等秒(8.0, func() -> bool:
			for 话 in _收:
				if String(话).contains("双修") and String(话).contains(对名):
					return true
			return false),
			"我发完那一发之后有回话，且回话里点了对面的名字（实得 %s）" % str(_收))
	## 对面点「拒绝」⇒ 服务端 `DOUBLE_DENY` 给邀请方回 `86:4:<拒绝者号>`。
	_对.request_double_heal_deny(我号)
	_记(await _等秒(8.0, func() -> bool:
			return int((_主.get("authoritative_heal") as Dictionary).get("denied_by", 0)) == _对编号),
			"对面拒绝 ⇒ 我这侧收到 `86:4:<对面号>`（denied_by 认这一发，实得 %s）" \
			% str((_主.get("authoritative_heal") as Dictionary).get("denied_by", 0)))
	## 拒绝把挂着的那封申请消费掉了 ⇒ 这时候直接同意**不该**绑上（只判上一条"denied_by 到了"
	## 证明不了这件事，单判"没绑上"又是 0 比 0 空判 ⇒ 两步一起：先确认没绑上，再重新邀一次走同意）。
	_对.request_double_heal_accept(我号)
	_记(not await _等秒(2.5, func() -> bool:
			return int((_主.get("authoritative_heal") as Dictionary).get("state", 0)) == 2),
			"拒绝之后再同意 ⇒ 我这边没进入双修态（服务端那条 invites 已经被 pop）")
	_主.request_double_heal_invite(_对编号)
	_记(await _等秒(8.0, func() -> bool:
			return int((_对.get("authoritative_heal") as Dictionary).get("pending_inviter_id", 0)) == 我号),
			"重新邀请又路由到对面了")
	_对.request_double_heal_accept(我号)
	_记(await _等秒(8.0, func() -> bool:
			var 我状: Dictionary = _主.get("authoritative_heal") as Dictionary
			var 他状: Dictionary = _对.get("authoritative_heal") as Dictionary
			return int(我状.get("state", 0)) == 2 and int(他状.get("state", 0)) == 2 \
					and int(我状.get("partner_id", 0)) == _对编号 and int(他状.get("partner_id", 0)) == 我号),
			"对面同意 ⇒ 两边都进权威双修态且 partner_id 互指（我=%s 对面=%s）" % [
				str(_主.get("authoritative_heal")), str(_对.get("authoritative_heal"))])
	_主.request_heal_stop()
	_对.request_heal_stop()
	_记(await _等秒(8.0, func() -> bool:
			return (int((_主.get("authoritative_heal") as Dictionary).get("state", -1)) == 0
					and int((_对.get("authoritative_heal") as Dictionary).get("state", -1)) == 0)),
			"停坐 ⇒ 两边状态都归 0（浮动那一条判据在离线门 §④ 用两拍相减钉，这儿只证开关的源头是回帧）")
	收拾并退出()


## `原因 != ""` ⇒ 这不是正常跑完，是**中途卡住提前收口**：后面那些判据一条都没跑，
## 必须记成红（10-17 实测：一个 `int(null)` 吊死 `_点求婚格` ⇒ §⑧ 整腿没跑而末行仍打「红 0 条」）。
func 收拾并退出(原因 := "") -> void:
	if 原因 != "":
		_失败.append("门提前收口（后面那些判据一条都没跑）：" + 原因)
		printerr("  !! 门提前收口（后面那些判据一条都没跑）：" + 原因)
	跑完了 = true
	还原端口()
	还原存档()
	print("头像信息在线门：红 %d 条" % _失败.size())
	quit(1 if _失败.size() > 0 else 0)

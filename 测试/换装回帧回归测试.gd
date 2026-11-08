extends SceneTree
## 199(UPDATE_CHAR_LOOK) 换装/变身回帧的离线门（#190）。
##
## 背景：服务端在 7 个地方会发这一帧（穿/卸装备的 `handle_item_move`、变身卡、转职、吃变身药、
## 写轮眼进阶…，逐条见 `真值/窗口/角色造型.md` §199），而客户端**以前一个处理都没有**
## ⇒ 穿完装备本人身上那具身体不会变，得重进图才换。这条门钉的就是「接上了、而且接对」。
##
## 三条硬口径（与工程里其余门一致）：
##   · **无头跑**、**不点任何会落盘的按钮** ⇒ 跑前记 `user://玩家数据.json` 的字节、跑完断言没变；
##   · 观测点只用「屏幕上真看得到的东西」（身体那具的贴图路径、左上角头像的贴图），不看内部标志位；
##   · 计数口径：一条 `_查` 算一条 ⇒ 循环会乘，末行「判 N 条」就是这个数。
##
## 跑法：Godot --path . --headless --script res://测试/换装回帧回归测试.gd

const 存档 := "user://玩家数据.json"
const 门名 := "换装回帧回归测试"

var 判数 := 0
var _失败: Array[String] = []


func _查(成立: bool, 说明: String) -> void:
	判数 += 1
	if not 成立:
		_失败.append(说明)


func _帧(n := 1) -> void:
	for i in range(n):
		await process_frame


## ⚠ `PackedByteArray` 在 4.7 没有 `sha256_hex()`（只有 `sha256_buffer()`），
## 而这份存档本来就是文本 ⇒ 直接比全文，别绕哈希（绕一层只会多一个"两边都算错还是相等"的盲区）。
func _字节() -> String:
	var f := FileAccess.open(存档, FileAccess.READ)
	if f == null:
		return "缺"
	return f.get_as_text()


## 身体/头像那具精灵现在用的是哪一套（返回贴图资源路径，里面带八位号）。取不到返回 ""。
func _精灵路径(节: Node) -> String:
	if 节 == null or not is_instance_valid(节):
		return ""
	var 内 = 节.get("sprite")
	if 内 == null or not (内 is Sprite2D):
		return ""
	var 贴: Texture2D = (内 as Sprite2D).texture
	if 贴 == null:
		return ""
	return String(贴.resource_path)


func _头像路径(头: TextureRect) -> String:
	if 头 == null or not is_instance_valid(头) or 头.texture == null:
		return ""
	return String(头.texture.resource_path)


func _initialize() -> void:
	call_deferred("_run")


func _尾() -> void:
	if not _失败.is_empty():
		for 条 in _失败:
			print("红：" + 条)
		print("汇：判 %d 条 / 红 %d 条（%s：失败）" % [判数, _失败.size(), 门名])
		quit(1)
		return
	print("汇：判 %d 条 / 红 0 条（%s：通过）" % [判数, 门名])
	quit(0)


## 左上角那枚自己的头像（`头像面板.gd` 里的 `_self_portrait`）。
func _找头像(节: Node) -> TextureRect:
	var 脚 = 节.get_script()
	if 脚 != null and String(脚.resource_path) == "res://脚本/界面/头像面板.gd":
		var 头 = 节.get("_self_portrait")
		if 头 is TextureRect:
			return 头 as TextureRect
	for 子 in 节.get_children():
		var 找 := _找头像(子)
		if 找 != null:
			return 找
	return null


func _run() -> void:
	var 存前 := _字节()
	var 后端 = root.get_node_or_null("/root/BackendConnection")
	var 会话 = root.get_node_or_null("/root/GameSession")
	_查(后端 != null and 会话 != null, "autoload 里该有 BackendConnection / GameSession")
	if 后端 == null or 会话 == null:
		_尾()
		return
	_查(后端.has_signal("char_look_changed"), "后端连接该声明 char_look_changed 这条信号")

	# ──  解码：字段序照服务端 `_send_character_look`（`fake_flash_server.py:17596`）──
	var 收: Array = []
	后端.connect("char_look_changed", func(角色号: int, 性别: int, 肤色: int, 脸: int, 灵气脸: int, 装备串: String):
		收.append([角色号, 性别, 肤色, 脸, 灵气脸, 装备串]))
	后端.call("_handle_bridge_text", "199:77:0:0:2:1:103:0:0:-:-:55")
	_查(收.size() == 1, "一条完整 199 该发一次信号；实得 %d 次" % 收.size())
	if 收.size() == 1:
		_查(int(收[0][0]) == 77 and int(收[0][1]) == 2 and int(收[0][2]) == 1 and int(收[0][3]) == 103 and int(收[0][4]) == 55,
				"六个字段该按位取对（角色号/性别/肤色/脸/灵气脸）；实得 %s" % str(收[0]))
	后端.call("_handle_bridge_text", "199:77:0:0:2:1:103:0:0:-:-")
	_查(收.size() == 1, "只有 11 段的坏包该整条丢（不凑默认值）；实得发到了 %d 次" % 收.size())
	后端.call("_handle_bridge_text", "199:x:0:0:2:1:103:0:0:-:-:55")
	_查(收.size() == 1, "角色号不是数字 ⇒ 丢")
	后端.call("_handle_bridge_text", "199:77:0:0:2:1:x:0:0:-:-:55")
	_查(收.size() == 1, "脸不是数字 ⇒ 丢（拿 0 当脸会把人刷成裸体）")
	后端.call("_handle_bridge_text", "199:77:0:0:1:0:1:0:0:-3&1040002@-5&1060002:-:0")
	var 串 := "" if 收.size() < 2 else String(收[1][5])
	_查(收.size() == 2 and 串 == "-3&1040002@-5&1060002",
			"装备串该原样带出（部位&物品、@ 分隔）；实得 %s" % 串)

	# ── ② 本人那一发要落到「唯一取值口」authoritative_stats，且只动外观三键 ──
	## ⚠ `游戏会话.自身外观()` 只在 **`in_game` 为真**时才读 `authoritative_stats`，否则退回离线那份
	## `player_stats`（`游戏会话.gd:2754-2766`）。199 这帧现实里只会在进游戏之后到 ⇒ 夹具必须把它当在线跑，
	## 不然下面三条"身体/头像真的换了"会全去读兜底号 00000001，看着像没接上（10-12 第一次跑就是这么红的）。
	后端.set("in_game", true)
	var 权: Dictionary = 后端.get("authoritative_stats")
	权.clear()
	权.merge({"face": 1, "gender": 1, "skinColor": 0, "level": 7, "money": 100}, true)
	后端.set("character_id", 77)
	后端.call("_handle_bridge_text", "199:77:0:0:2:5:103:0:0:-:-:55")
	_查(int(权.get("face")) == 103 and int(权.get("gender")) == 2 and int(权.get("skinColor")) == 5,
			"本人 ⇒ face/gender/skinColor 三键该被覆盖；实得 %s / %s / %s"
			% [str(权.get("face")), str(权.get("gender")), str(权.get("skinColor"))])
	_查(int(权.get("level")) == 7 and int(权.get("money")) == 100,
			"别的键一个都不许碰（等级/金币是别的帧在管的）；实得 level=%s money=%s"
			% [str(权.get("level")), str(权.get("money"))])
	var 口: Dictionary = 会话.call("自身外观")
	_查(int(口.get("face")) == 103 and int(口.get("gender")) == 2,
			"身体/头像/立绘共用的那个取值口该跟着变；实得 %s" % str(口))
	权.clear()
	后端.call("_handle_bridge_text", "199:77:0:0:1:0:2:0:0:-:-:0")
	_查(权.is_empty(), "authoritative_stats 还空着（没收到属性帧）时不许凭空建一个只含外观的字典，"
			+ "否则读 money 那类地方会因字典非空而拿到 0；实得 %s" % str(权))
	权.merge({"face": 1, "gender": 1, "money": 100}, true)
	后端.call("_handle_bridge_text", "199:88:0:0:2:0:2:0:0:-:-:0")
	_查(int(权.get("face")) == 1,
			"角色号不是本人 ⇒ 一律不许往我身上套（原版那个 playerId 判断）；实得 face=%s" % str(权.get("face")))

	# ── ③ 真接线：地图场景里喂一条 199 ⇒ 玩家身上那具身体真的换了 ──
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await _帧(16)
	var 玩 = 图.get_node_or_null("Player")
	_查(玩 != null, "地图场景该建出玩家节点（这一段的观测点）")
	var 我号 := int(后端.get("character_id"))
	if 玩 != null:
		var 起先 := _精灵路径(玩.get("player_sprite"))
		_查(起先.length() > 0, "开局身体该有贴图（空的话下面四条全是假绿）；实得 %s" % 起先)
		后端.call("_handle_bridge_text", "199:%d:0:0:1:0:2:0:0:-:-:0" % 我号)
		await _帧(3)
		var 换后 := _精灵路径(玩.get("player_sprite"))
		_查(换后.contains("00000002") and 换后 != 起先,
				"喂 face=2 ⇒ 玩家身上那具该换成 00000002 那套；实得 %s（换前 %s）" % [换后, 起先])
		后端.call("_handle_bridge_text", "199:%d:0:0:1:0:99999999:0:0:-:-:0" % 我号)
		await _帧(3)
		_查(_精灵路径(玩.get("player_sprite")) == 换后,
				"face 指向一套不存在的动画 ⇒ 留着原来那具，绝不刷成空白（空白比「暂时没换」更难查）；实得 %s"
				% _精灵路径(玩.get("player_sprite")))
		## ⚠ 上面那条只钉住了「贴图没被换掉」，钉不住「动画表还在不在」：
		##   `原始动画精灵.configure` 拿不存在的号时会**先把 actions 清成空再返回 false**（:100-102），
		##   于是拆掉 `刷新外观` 里那道 `has_animation` 闸之后，贴图看着没变、身体却从此不再换帧
		##   （10-12 变异 W1 就是这么"不红"的）。这一条补的就是这个洞。
		_查(not ((玩.get("player_sprite") as Node).get("actions") as Dictionary).is_empty(),
				"坏 face 之后动画表该还是满的（`has_animation` 那道闸的作用：不让 configure 把 actions 清成空）；实得 %d 条"
				% ((玩.get("player_sprite") as Node).get("actions") as Dictionary).size())
		后端.call("_handle_bridge_text", "199:%d:0:0:1:0:1:0:0:-:-:0" % 我号)
		await _帧(3)
		_查(_精灵路径(玩.get("player_sprite")).contains("00000001"),
				"再换回 face=1 ⇒ 该跟着换回去（不是只在第一次生效）；实得 %s" % _精灵路径(玩.get("player_sprite")))
		var 头: TextureRect = _找头像(图)
		_查(头 != null, "地图场景里该找得到左上角头像节点（找不到=这条腿没测到，别当过了）")
		if 头 != null:
			var 头前 := _头像路径(头)
			后端.call("_handle_bridge_text", "199:%d:0:0:1:0:2:0:0:-:-:0" % 我号)
			await _帧(3)
			var 头后 := _头像路径(头)
			_查(头后 != 头前 and 头后.contains("00000002"),
					"左上角头像该跟着 199 换（原版本人那一支写完 stats.face 立刻 setCharacterImage）；换前 %s → 换后 %s"
					% [头前, 头后])
	图.queue_free()
	await _帧(3)

	# ── ④ 明账：两套号在表里、服务端真的会发 ──
	var 元 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/角色/动画元数据.json"))
	var 表: Dictionary = (元 as Dictionary).get("character", {}) if 元 is Dictionary else {}
	_查(表.has("00000001") and 表.has("00000002"),
			"00000001 / 00000002 两套身体动画都该在元数据里（上面那四条腿全靠它们）")
	_查(not 表.has("99999999"), "99999999 该是查不到的那一套（「刷不成空白」那条判据的前提）")
	var 服务端 := FileAccess.get_file_as_string("res://服务端/runtime/tools/fake_flash_server.py")
	_查(服务端.contains("UPDATE_CHAR_LOOK = 199"), "服务端常量表里该有 UPDATE_CHAR_LOOK = 199")
	var 发处 := 服务端.count("self._send_character_look()")
	_查(发处 >= 5, "服务端真会发这一帧（现查调用点 %d 处：穿卸/变身卡/转职/变身药/写轮眼…）⇒ 不是死代码" % 发处)

	_查(_字节() == 存前, "门不许动存档（user://玩家数据.json 字节要一致）")
	_尾()

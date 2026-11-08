extends SceneTree
## 199(UPDATE_CHAR_LOOK) 的**在线端到端**门（#190 第 1 步，2026-10-12）。
##
## 它和离线门 `换装回帧回归测试.gd` 的分工：那条是**我喂一条假帧**证明「客户端收到会解、
## 会换身体」；这一条是**真背包里真穿一件衣服**，证明
##   ① 服务端 `handle_item_move` 在穿/卸那一刻真的把 199 发出来（:47524-47525），
##   ② 这一发走到真连接上、被真解码、
##   ③ 屏幕上看得到的那具身体与左上角头像真的跟着换。
## 只测 ② 不测 ① 的话，服务端哪天不再发这一帧，客户端这一头照样绿。
##
## face 的三档不是猜的，读的是服务端那一处算式（`fake_flash_server.py:17545-17581`）：
##   身上没有身体装 ⇒ 职业 300 走 `NAKED_MALE` = **1**（:17570-17573）
##   穿了 ⇒ 职业 300 + (最高需求等级 ≥ 40 ? 3 : 0) ⇒ **300** 或 **303**
## 夹具那个号是 `create_character(account, name, 300, 0, 1, 0)`（job=300、gender=0、等级 100），
## 所以两件衣服都挑的 job=300 那一支：`01030013 轻皮忍服`(lv1) 与 `01030033 豹皮忍服`(lv40)。
##
## 跑法（由 开发工具/跑在线用例.ps1 -用例 换装在线 调；它起隔离夹具 + 预置这两件）：
##   python 开发工具/本地服务端夹具.py --root .fixture --reset \
##     --port 18700 --gm-http 18701 --items 1030013:1,1030033:1 \
##     --run res://测试/换装在线回归测试.gd --godot <Godot console exe>

const 门名 := "换装在线回归测试"
const 存档 := "user://玩家数据.json"
const 地图实体脚本 := preload("res://脚本/地图/地图实体.gd")

const 低级衣服 := "01030013"
const 高级衣服 := "01030033"
const 衣服槽 := -3
const 裸脸 := 1
const 低档脸 := 300
const 高档脸 := 303

var 判数 := 0
var _失败: Array[String] = []
var 收帧: Array = []
var 我号 := 0
var 原端口 := -1
var 会话引用: Node = null


func _查(成立: bool, 说明: String) -> void:
	判数 += 1
	if not 成立:
		_失败.append(说明)


func _停(话: String) -> void:
	_还原设置()
	printerr("汇：判 %d 条 / 红 %d 条（%s：中断）" % [判数, _失败.size() + 1, 门名])
	printerr("  红 - " + 话)
	quit(1)


func _帧(n := 1) -> void:
	for i in range(n):
		await process_frame


func _等待(条件: Callable, 毫秒: int = 8000) -> bool:
	for _轮 in range(毫秒 / 50):
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


## `PackedByteArray` 在 4.7 没有 `sha256_hex()`，而这份存档本来就是文本 ⇒ 直接比全文。
func _字节() -> String:
	var f := FileAccess.open(存档, FileAccess.READ)
	if f == null:
		return "缺"
	return f.get_as_text()


func _on_look(角色号: int, 性别: int, 肤色: int, 脸: int, 灵气脸: int, 装备串: String) -> void:
	收帧.append([角色号, 性别, 肤色, 脸, 灵气脸, 装备串])


func _背包有(后端: Node, 物品号: String) -> bool:
	for 条 in (后端.get("authoritative_inventory") as Array):
		if int(String((条 as Dictionary).get("id", "0"))) == int(物品号):
			return true
	return false


## 身体那具现在用的是哪一套（返回贴图资源路径，里面带八位号）；取不到返回 ""。
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


func _末条() -> Array:
	return 收帧[收帧.size() - 1] as Array


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var 后端 = root.get_node_or_null("BackendConnection")
	var 会话 = root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_停("缺单例（BackendConnection / GameSession）")
		return
	后端.connect("char_look_changed", _on_look)
	## ⚠ 本条走**独立端口**（18700），不是客户端默认那台 18684 —— 默认口是用户自己那台客户端
	##   在连的号，绝不能拿用例去顶。夹具只把端口号放进环境变量，客户端不会自己读 ⇒
	##   不写回 `game_settings.backend_port` 就会连到 18684 上超时（写法照 交付后自动弹对话在线回归测试.gd:113-123）。
	会话引用 = 会话
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18700
	var 设置: Dictionary = 会话.get("game_settings")
	原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	后端.call("sync_character")
	if not await _等待(
			func(): return bool(后端.get("in_game")) and (后端.get("authoritative_inventory") as Array).size() > 0,
			15000):
		_停("进不了真实后端：%s - %s" % [后端.get("status"), 后端.get("detail")])
		return
	我号 = int(后端.get("character_id"))
	var 镜像: Dictionary = 后端.get("authoritative_stats")

	# ── ① 前置：夹具给料对不对，一眼能分清「门红」和「夹具没喂」 ──
	_查(镜像.size() > 0, "① 在线权威属性镜像该有内容（199 那三条键要写进这里）")
	var 起先等级 := int(镜像.get("level", -1))
	var 起先金币 := int(镜像.get("money", -1))
	_查(_背包有(后端, 低级衣服),
			"① 背包里该有 轻皮忍服(01030013) —— 查不到就是夹具没发（--items 1030013:1），不是客户端坏")
	_查(_背包有(后端, 高级衣服), "① 背包里该有 豹皮忍服(01030033)（≥40 那一档的料）")
	var 存前 := _字节()

	# ── ② 真进图：世界场景建出来才有真玩家与真头像（这一棵是客户端自己那张地图场景） ──
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await _帧(24)
	var 玩 = 图.get_node_or_null("Player")
	_查(玩 != null, "② 地图场景该建出玩家节点（后面四条腿的观测点都在它身上）")
	if 玩 == null:
		_尾()
		return
	var 身体起 := _精灵路径(玩.get("player_sprite"))
	_查(身体起.contains("00000001"),
			"② 开局身上没有身体装 ⇒ 该是裸体那具 00000001（服务端 :17570-17573：职业 300 ⇒ 男裸体）；实得 %s" % 身体起)
	_查((会话.get("equipped_items") as Dictionary).has(衣服槽) == false,
			"② 反向：开局装备栏镜像里不该已经有 -3 这一格（有的话下面「穿上才变」那条就成了假绿）")

	# ── ③ 穿上一件 lv1 的衣服：服务端真发 → 客户端真解 → 身体真换 ──
	收帧.clear()
	var 发出去了: bool = bool(会话.call("equip_item", 低级衣服))
	_查(发出去了, "③ equip_item 该把 ITEM_MOVE(0, 背包格, -3, 0) 发出去（false = 客户端这一头就没走）")
	if not await _等待(func(): return 收帧.size() > 0, 8000):
		_停("③ 穿了衣服但一条 199 都没收到 ⇒ 服务端 handle_item_move 那一发没落到连接上（:47524-47525）")
		return
	var 甲 := _末条()
	_查(int(甲[0]) == 我号, "③ 199 的收件人该是我自己（角色号 %d，实得 %d）" % [我号, int(甲[0])])
	_查(int(甲[3]) == 低档脸,
			"③ face 该是 300（职业 300 + 最高需求等级 1 < 40 ⇒ +0，服务端 :17579-17581）；实得 %d" % int(甲[3]))
	_查(String(甲[5]).contains("-3&1030013"),
			"③ 装备串该含刚穿上那一件 `-3&1030013`（槽&物品，服务端 :17585-17593）；实得 %s" % 甲[5])
	_查(int(镜像.get("face", -1)) == 低档脸,
			"③ 权威镜像的 face 该被这一发改掉（左上角头像与人物窗读的就是它）；实得 %s" % 镜像.get("face"))
	_查(int((会话.call("自身外观") as Dictionary).get("face", -1)) == 低档脸,
			"③ 会话那一头问「我该长什么样」也得答 300（不是只写了字典没人读）")
	_查(int(镜像.get("level", -1)) == 起先等级 and int(镜像.get("money", -1)) == 起先金币,
			"③ 199 只许改外观那三条键，别把等级/金币一起写坏（防的是「建了半截 authoritative_stats」那一版）")
	await _帧(4)
	var 身体穿 := _精灵路径(玩.get("player_sprite"))
	_查(身体穿.contains("00000300") and 身体穿 != 身体起,
			"③ 身上那具该真的换成 00000300；换前 %s → 换后 %s" % [身体起, 身体穿])
	_查(not _背包有(后端, 低级衣服), "③ 反向：穿上了 ⇒ 背包镜像里那件就该不在包里了")
	_查((会话.get("equipped_items") as Dictionary).has(衣服槽),
			"③ 卸下之前装备栏镜像里该有 -3 这一格（没有 = 回包没被吃，下一条会静默 no-op）")

	# ── ④ 卸下：换回裸体那一档（反向对照，防「只在第一次生效」） ──
	收帧.clear()
	会话.call("unequip_item", 衣服槽)
	if not await _等待(func(): return 收帧.size() > 0, 8000):
		_停("④ 卸下了但没收到 199（服务端 :47524 同一处，卸也是 source<0 or dest<0）")
		return
	var 乙 := _末条()
	_查(int(乙[3]) == 裸脸,
			"④ 卸下后 face 该回裸体那一档 1（身上没身体装了）；实得 %d" % int(乙[3]))
	_查(String(乙[5]) == "-", "④ 身上没东西了，装备串该空成 `-`（服务端 :17593 那一串是 `-`，不是空串）；实得 %s" % 乙[5])
	await _帧(4)
	var 身体卸 := _精灵路径(玩.get("player_sprite"))
	_查(身体卸.contains("00000001"),
			"④ 身上那具该跟着换回 00000001（真链路两个方向都要走）；实得 %s" % 身体卸)
	_查(_背包有(后端, 低级衣服), "④ 反向：卸下来的那件该回到背包镜像里")

	# ── ⑤ ≥40 那一档：同一处算式的另一支 ──
	收帧.clear()
	var 发高: bool = bool(会话.call("equip_item", 高级衣服))
	_查(发高, "⑤ equip_item(豹皮忍服) 该发得出去")
	if await _等待(func(): return 收帧.size() > 0, 8000):
		var 丙 := _末条()
		_查(int(丙[3]) == 高档脸,
				"⑤ 需求等级 40 ⇒ face 该是 300+3=303（服务端 :17580-17581 那一支）；实得 %d" % int(丙[3]))
		await _帧(4)
		var 身体高 := _精灵路径(玩.get("player_sprite"))
		_查(身体高.contains("00000303"), "⑤ 身上那具该换成 00000303；实得 %s" % 身体高)
		var 头: TextureRect = _找头像(图)
		_查(头 != null, "⑤ 地图场景里该找得到左上角头像节点（找不到=这一条腿没测到，别当过了）")
		if 头 != null:
			_查(_头像路径(头).contains("00000303"),
					"⑤ 左上角头像该跟着**真回帧**换（离线门是喂假帧测的，这条才是真链路）；实得 %s" % _头像路径(头))
	else:
		_查(false, "⑤ 穿上 40 级的衣服后没收到 199")

	_查(_字节() == 存前, "⑥ 整条穿/卸链不许动 user://玩家数据.json（在线分支在落盘之前就 return）")

	图.queue_free()
	await _帧(3)
	_尾()


## 只还原自己动过的那一个键，别顺手整份覆盖 `game_settings`。
func _还原设置() -> void:
	if 会话引用 == null or 原端口 < 0:
		return
	var 设置: Dictionary = 会话引用.get("game_settings")
	设置["backend_port"] = 原端口


func _尾() -> void:
	_还原设置()
	for 条 in _失败:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（%s：%s）" % [判数, _失败.size(), 门名, "通过" if _失败.is_empty() else "失败"])
	quit(0 if _失败.is_empty() else 1)

extends SceneTree

## 追踪栏「点一行就该走过去」这一族的四条实机 bug 的回归门（2026-10-10 凌晨）。
##
## 用户报的 four 条（原话摘要）：① 点绿色 NPC 名字自动寻路**时灵时不灵**；② 点怪物名字**根本不寻路**；
## ③ NPC **不在当前地图**时点寻路**没反应**；④ 击杀任务面板**不实时更新**（一直显示 0/3）。
##
## 四条查到底的根子（都量过，不是猜）：
##   ① `id` 是从 href 里**抠数字**抠出来的（`event:npc101010000:23`），以前按整串比过 meta ⇒ 偶尔取到 0
##      就直接 return；两条链接现在都汇到 `前往NPC(id)`。
##   ② 怪那一条以前**没判 `走向()` 的返回值**：这一段没有落脚点时它返回 false，而调用方一句都不说
##      ⇒ 看着就是"点了没反应"。现在 false 必须出一条提示。
##   ③ 不在本图时以前落到 `show_npc_dialog(键)` —— **本地假对话**：人没到、包没发、窗先开了。
##      现在改成查 `数据/界面/实体所在图.json` → 本图有直达传送点就先走到门口（`前往别的图`），
##      查不到/没有门都必须**说话**，不许静默。
##   ④ 服务端把 `kind` 发成字符串（"mob"），客户端按 `int(fields[4])` 解 ⇒ 一律解成 0，进度那一层
##      整个丢掉；而且进度帧 `key+curr+count!…` 以前**没解过**。两处一起修，追踪栏才拿得到 (2/3)。
##
## 所以这道门分三段：
##   A 解码三段（`_解目标数据` / `_解进度帧` + `_并目标` / `_目标计数`）—— ④ 的每一层各自钉死，
##     少修任何一层都会红（以前只测了"行在不在"，照不到"数字对不对"）。
##   B 寻路形状（假玩家记 `走向()` 的调用与返回值 + `_toast` 的文案）—— ①②③ 各自的**反应**。
##   C 源上没有自造假对话（`show_npc_dialog` 不许出现在 `_追踪链接点击` 里）—— 防融合方改回去。
##
## ⚠ 口径：无头跑；载**真地图场景**（`_找本图NPC`/`_本图最近怪` 都要 LifeRoot）；
##   把真玩家摘出 "player" 组、换成假玩家（`前往别的图` 先读 `_player`，`_走向任务怪` 读组）；
##   不落存档（跑前记 `user://玩家数据.json` 字节，跑完断言没变）。
## 运行：Godot --headless --path . --script res://测试/追踪栏寻路四修回归测试.gd

const 地图路 := "res://场景/地图/地图场景.tscn"
const 面板路 := "res://场景/界面/小地图面板.tscn"
const 实体脚本 := "res://脚本/地图/地图实体.gd"
const 会话路 := "res://脚本/单例/游戏会话.gd"
const 后端路 := "res://脚本/单例/后端连接.gd"
const 本图 := 101010000
const 查无怪 := 9999999		# 任何图都不会有这只怪，专门用来走"场上没活口"那两支

## 假玩家：只记 `走向()` 被叫了几次、参数是什么，并按 `答` 决定成不成。
class 假玩家:
	extends Node2D
	var 走过: Array = []
	var 答 := true
	## 真玩家身上这两个字段 HUD 会读（`_走向NPC` 记走完印、`_process` 判路线停没停），
	## 假玩家必须同形，否则 `int(null)` 当场打断 `_走向NPC` ⇒ 走向() 一次都没叫到。
	var auto_path_arrive_stamp := 0
	var click_move_active := false

	func 走向(位: Vector2, 画 := false, 提示 := false) -> bool:
		走过.append({"位": 位, "画": 画, "提示": 提示})
		return 答

var 红数 := 0
var 总 := 0
var 日志: Array[String] = []
var 场景: Node
var 面板: Node
var 假: 假玩家
var 后端: Node
var 会话: Node
var 存档前 := ""
var 换行 := char(10)
var 引 := char(34)


func _记(过: bool, 话: String) -> void:
	总 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 话])
	if not 过:
		红数 += 1


func _帧(n: int) -> void:
	for _i in n:
		await process_frame


func _存档字节() -> String:
	var 路 := OS.get_user_data_dir() + "/玩家数据.json"
	return "无" if not FileAccess.file_exists(路) else str(FileAccess.get_file_as_string(路).length())


## 在子树里找挂了指定脚本的那个节点
func _找(根: Node, 脚本路: String) -> Node:
	if 根.get_script() != null and str(根.get_script().resource_path) == 脚本路:
		return 根
	for 子 in 根.get_children():
		var 出 := _找(子, 脚本路)
		if 出 != null:
			return 出
	return null


func _提示文() -> String:
	var 条 := 面板.get("_toast") as Label
	return 条.text if 条 != null else "<_toast 没接上>"


func _清提示() -> void:
	var 条 := 面板.get("_toast") as Label
	if 条 != null:
		条.text = ""
	假.走过 = []
	假.答 = true


func _本图NPC号() -> int:
	var 根 := 场景.get_node_or_null("LifeRoot")
	if 根 == null:
		return 0
	for 实体 in (根.get("_entities") as Array):
		var 谁 := 实体 as Node2D
		if 谁 == null or str(谁.get("kind")) != "n":
			continue
		return int(str(谁.get("entity_id")))
	return 0


func _本图怪号() -> int:
	var 根 := 场景.get_node_or_null("LifeRoot")
	if 根 == null:
		return 0
	for 实体 in (根.get("_entities") as Array):
		var 谁 := 实体 as Node2D
		if 谁 == null or str(谁.get("kind")) != "m":
			continue
		if not bool(谁.get("alive")):
			continue
		return int(str(谁.get("entity_id")))
	return 0

const 面板脚本 := "res://脚本/界面/小地图面板.gd"


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _跑() -> void:
	root.size = Vector2i(1280, 720)		# 无头也要钉视口
	存档前 = _存档字节()
	后端 = root.get_node_or_null("BackendConnection")
	会话 = root.get_node_or_null("GameSession")
	_记(后端 != null and 会话 != null, "两个单例都在（_本图号/_通往 都要问它们）")
	_记(FileAccess.file_exists(地图路) and FileAccess.file_exists(面板脚本),
			"地图场景与面板脚本都在盘上")
	后端.set("authoritative_map_id", 本图)
	会话.set("current_map_id", str(本图))
	_A_解码()
	场景 = (load(地图路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(14)
	面板 = 场景.get_node_or_null("小地图面板")
	if 面板 == null:
		面板 = _找(场景, 面板脚本)
	_记(面板 != null and str(面板.get_script().resource_path) == 面板脚本,
			"地图场景里挂着小地图面板（① 的两支都要它）")
	if 面板 == null:
		_尾()
		return
	假 = 假玩家.new()
	假.name = "假玩家"
	假.position = Vector2(300, 300)
	root.add_child(假)
	假.add_to_group("player")
	for 真 in get_nodes_in_group("player"):
		if 真 != 假:
			(真 as Node).remove_from_group("player")
	_记(get_first_node_in_group("player") == 假,
			"「player」组里只剩假玩家 ⇒ `走向()` 的每一声都被记下来（不记就等于没测）")
	await _B_本图NPC()
	await _B_跨图NPC()
	await _B_怪()
	await _E_转身()
	_C_源形状()
	_尾()


## —— A：④「击杀进度不实时更新」的三层解码，各钉各的，少修一层就红 ——
func _A_解码() -> void:
	var 后: Node = load(后端路).new()
	var 会: Node = load(会话路).new()
	var 条: Dictionary = 后.call("_解任务状态条目", "1018&3&mob&1000001+2+3!1000002+0+1")
	# kind 落在**每个目标项**上（`_解目标数据` 把这一批的类原样交出去）；
	# 帧级那个 `"kind": String(fields[4])` 在 444:1/2 两条分支里，那里另有一条源判据。
	_记(str((条.get("目标进度", []) as Array)) != "[]", "444:3 的进度段解出了目标列表")
	var 目: Array = 条.get("目标进度", []) as Array
	_记(目.size() == 2, "一条两个目标都解出来（实际 %d）" % 目.size())
	if 目.size() == 2:
		_记(str((目[0] as Dictionary).get("kind", "")) == "mob",
				"目标项带 kind 且是字符串 mob（以前帧级 int() 一律 0 ⇒ 整层进度丢掉）实际 %s"
				% str((目[0] as Dictionary).get("kind")))
		_记(int(目[0].get("curr", -1)) == 2 and int(目[0].get("count", -1)) == 3
				and int(目[1].get("curr", -1)) == 0 and int(目[1].get("count", -1)) == 1,
				"进度帧 `key+curr+count!…` 的四个数字逐个对（实际 %s/%s 与 %s/%s）" % [
				str(目[0].get("curr")), str(目[0].get("count")), str(目[1].get("curr")), str(目[1].get("count"))])
	var 空: Dictionary = 后.call("_解任务状态条目", "1018&3&mob&-")
	_记((空.get("目标进度", [1]) as Array).is_empty(), "数据是 `-` ⇒ 没有目标，不许凭空造一个")
	# 真格式（`fake_flash_server.py:_send_original_quest_full_progress` 56997-57001）：
	# 同 kind 的多个目标用 `@` 连，每一项是 `key&curr&count`；`444:1` 就是其中**一项**。
	var 新: Array = 会.call("_解进度帧", "mob", "1000001&1&3@1000002&2&2")
	_记(新.size() == 2, "会话侧 444:1 那种 `@` 分隔也解得出两项（实际 %d）" % 新.size())
	var 并: Array = 会.call("_并目标",
			[{"kind": "item", "key": "5001", "curr": 1, "count": 2}], 新)
	_记(并.size() == 3, "不同 kind 的目标要**并**进来（抹掉 item 那条就是「进度一刷新别的都归零」）实际 %d" % 并.size())
	var 再: Array = 会.call("_并目标", 新, 会.call("_解进度帧", "mob", "1000001&3&3"))
	_记(再.size() == 2 and int((再[0] as Dictionary).get("curr", -1)) == 3,
			"同 kind 同 key ⇒ 只盖计数（实际 %d 项，第一项目前 %s）" % [
			再.size(), str((再[0] as Dictionary).get("curr"))])
	# ⚠ 这三条以前写在 `if 面板 != null:` 里，而 `_A_解码()` 是**载图之前**跑的
	# ⇒ 三条判据静默跳过、门照样绿（变异实测第 5 条打不响才暴露出来）。
	# `_目标计数` 是个纯函数，直接拿脚本 new 一个裸面板调，不依赖场景，永远会跑。
	var 裸: Node = load(面板脚本).new()
	var 数1: String = 裸.call("_目标计数",
			{"目标进度": [{"kind": "mob", "key": "1000001", "curr": 2, "count": 3},
					{"kind": "mob", "key": "1000002", "curr": 0, "count": 1}]},
			"mob", 1000002, 1, 2, true)
	_记(数1 == "（0/1）", "两项目标时按**目标号**取那一项，不许拿总数顶（实际「%s」）" % 数1)
	var 数2: String = 裸.call("_目标计数",
			{"目标进度": [{"kind": "mob", "key": "1000001", "curr": 2, "count": 3}],
				"progress": 2, "required": 3}, "mob", 1000001, 3, 1, true)
	_记(数2 == "（2/3）", "只有一项目标时才回落到整条的 progress/required（实际「%s」）" % 数2)
	_记(str(裸.call("_目标计数", {"目标进度": []}, "mob", 1, 3, 1, false)) == "",
			"没有进度信息 ⇒ 空串（原版这一行不带计数）")
	var 数3: String = 裸.call("_目标计数",
			{"目标进度": [{"kind": "mob", "key": "1000001", "curr": 2, "count": 3},
					{"kind": "mob", "key": "1000002", "curr": 0, "count": 1}],
				"progress": 2, "required": 4}, "mob", 1000099, 4, 2, true)
	_记(数3 == "", "表里没有这个目标号 ⇒ 空串，不许拿整条的 2/4 蒙（实际「%s」）" % 数3)
	裸.free()


## —— B①：点**本图**那个绿名 ⇒ 必须真的起步 ——
func _B_本图NPC() -> void:
	var 号 := _本图NPC号()
	_记(号 > 0, "本图找得到一只 NPC 用来点（实际 %d）" % 号)
	if 号 <= 0:
		return
	_清提示()
	面板.call("前往NPC", 号, true)
	await _帧(3)
	_记(假.走过.size() == 1, "点本图 NPC ⇒ 玩家收到恰好一次 `走向()`（0 次=点了没反应，>1 次=重复发）实际 %d"
			% 假.走过.size())
	if 假.走过.size() == 1:
		_记(bool(假.走过[0]["提示"]),
				"这一支的 showtip = 真 ⇒「自动寻路中」会亮（`CharacterHandler.as:710` 传 true）")
	_清提示()
	假.答 = false
	面板.call("前往NPC", 号, true)
	await _帧(3)
	_记(_提示文() != "",
			"`走向()` 返回假（那一段没落脚点）⇒ **必须说一句**，不许静默（以前忽略返回值就是「时灵时不灵」）")
	_记(假.走过.size() == 1, "失败那一次也确实是尝试过一次的（实际 %d）" % 假.走过.size())


## —— B③：目标 NPC 不在本图 ⇒ 查表 + 一步跨图，任何分支都要有反应 ——
func _B_跨图NPC() -> void:
	var 表: Dictionary = 面板.call("_实体图") as Dictionary
	var 列: Dictionary = 表.get("npc", {}) as Dictionary
	var 别处的号 := 0
	var 别处的图: Array = []
	for 键 in 列.keys():
		var 图们: Array = 列[键]
		if 图们.is_empty():
			continue
		if not 图们.has(str(本图)):
			别处的号 = int(str(键))
			别处的图 = 图们
			break
	_记(别处的号 > 0, "实体所在图表里找得到一只**不在本图**的 NPC（用来测跨图那支，实际 %d）" % 别处的号)
	if 别处的号 <= 0:
		return
	_清提示()
	面板.call("前往NPC", 别处的号, true)
	await _帧(3)
	var 说 := _提示文()
	_记(假.走过.size() >= 1 or 说 != "",
			"跨图那一支三条路都要出声：走到门口 / 本图没直达门 / 查无此图。现在走了 %d 次，提示「%s」"
			% [假.走过.size(), 说])
	_记(not 说.contains("对话"), "不许再用本地假对话假装「到了」（用户报的③就是这么来的）")
	if 假.走过.size() >= 1:
		_记(str(说).contains("传送点") or str(说) == "",
				"起步去跨图时提示里要点明是去传送点（实际「%s」）" % 说)
	_清提示()
	_记((面板.call("_在哪图", "npc", 别处的号) as Array) == 别处的图,
			"_在哪图 直接回表里那一列（不查表就永远「查不到」）")


## —— B②：点怪名 ——
func _B_怪() -> void:
	var 怪 := _本图怪号()
	_记(怪 > 0, "本图找得到一只活口怪（实际 %d）" % 怪)
	if 怪 > 0:
		_清提示()
		面板.call("_走向任务怪", "event:mob%d:%d" % [本图, 怪])
		await _帧(3)
		_记(假.走过.size() == 1, "点本图怪名 ⇒ 玩家收到一次 `走向()`（用户报的②以前是 0 次）实际 %d"
				% 假.走过.size())
		if 假.走过.size() == 1:
			_记(bool(假.走过[0]["提示"]),
					"点怪赶路也要 showtip=真（`CharacterHandler.as:881` MovePlayerToMob 第三参 true）")
		_清提示()
		假.答 = false
		面板.call("_走向任务怪", "event:mob%d:%d" % [本图, 怪])
		await _帧(3)
		_记(_提示文().contains("走不到"),
				"怪那一步寻不到路 ⇒ 必须报「走不到…」（漏判返回值就是这句没有，看着像没反应）实际「%s」" % _提示文())
	_清提示()
	面板.call("_走向任务怪", "event:mob%d:%d" % [本图, 查无怪])
	await _帧(3)
	_记(_提示文().contains("暂时没有"),
			"任务写本图、场上没这只活口 ⇒ 说「本图暂时没有…等它刷出来」（不许假装在赶路）实际「%s」" % _提示文())
	_清提示()
	var 别的怪图: Array = 面板.call("_在哪图", "mob", 1000001) as Array
	if 别的怪图.is_empty() or 别的怪图.has(str(本图)):
		for 键 in ((面板.call("_实体图") as Dictionary).get("mob", {}) as Dictionary).keys():
			var 图们: Array = ((面板.call("_实体图") as Dictionary).get("mob", {}) as Dictionary)[键]
			if not 图们.is_empty() and not 图们.has(str(本图)):
				别的怪图 = 图们
				_清提示()
				面板.call("_走向任务怪", "event:mob0:%s" % str(键))
				await _帧(3)
				_记(假.走过.size() >= 1 or _提示文() != "",
						"href 里没带图号（图=0）时也要拿实体所在图表兜一下（走了 %d 次，提示「%s」）"
						% [假.走过.size(), _提示文()])
				break
	else:
		_清提示()
		面板.call("_走向任务怪", "event:mob%d:1000001" % int(str(别的怪图[0])))
		await _帧(3)
		_记(假.走过.size() >= 1 or _提示文() != "",
				"怪在别的图 ⇒ 要么起步去传送点要么说清他在哪张图（走了 %d 次，提示「%s」）"
				% [假.走过.size(), _提示文()])


## —— E：说话那一拍 NPC 要转身面朝玩家（原版 `NPCHandler.directionNPC`，欠的 #153）——
func _E_转身() -> void:
	var 根: Node = 场景.get_node_or_null("LifeRoot")
	_记(根 != null, "LifeRoot 在（这一段要它调 _open_dialog）")
	if 根 == null:
		return
	# 地图根的 `_player` 是 _ready 时缓存的**真**玩家；本门把 player 组换成假玩家时必须一并换掉这个缓存，
	# 否则算的是「离真玩家多远」，测的已经不是这条规则了。
	根.set("_player", 假)
	var 号 := _本图NPC号()
	var 甲: Node = 面板.call("_找本图NPC", "%08d" % 号)
	_记(甲 != null, "找得到一只能对话的 NPC（编号 %d / 字符串 %s）" % [号, str(甲.get("entity_id")) if 甲 != null else "-"])
	if 甲 == null:
		return
	# ⚠ 传**实体自己那个** entity_id：`_让NPC面朝玩家` 是拿字符串比的，
	# 而 `int(entity_id)` 会丢掉前导零（"00000002" → 2），拿 "2" 去比对永远找不到 ⇒ 门红得像是没实现。
	var 编号 := str(甲.get("entity_id"))
	var 基: Vector2 = 甲.global_position
	甲.set("_朝向", 0)
	假.position = Vector2(基.x + 200.0, 基.y)
	根.call("_open_dialog", 编号)
	var 朝右: int = int(甲.get("_朝向"))
	var 皮子: Node = 甲.get("_sprite") as Node
	var 皮右 := 0.0
	var 皮左 := 0.0
	if 皮子 != null:
		皮右 = signf(皮子.scale.x)
	_记(朝右 == 1,
		"玩家在 NPC 右边 ⇒ NPC 面朝右（`npc.x > player.x ? LEFT : RIGHT` 的另一侧）实际 _朝向=%d" % 朝右)
	假.position = Vector2(基.x - 200.0, 基.y)
	根.call("_open_dialog", 编号)
	var 朝左: int = int(甲.get("_朝向"))
	if 皮子 != null:
		皮左 = signf(皮子.scale.x)
	_记(朝左 == -1,
		"玩家在左边 ⇒ NPC 面朝左（转身真的发生了，不是保持原样）实际 _朝向=%d" % 朝左)
	if 皮子 != null:
		_记(皮右 != 0.0 and 皮左 != 0.0 and 皮右 != 皮左,
			"精灵真的翻了（scale.x 符号 %s → %s；只改 _朝向 不改画面 = 等于没做）" % [str(皮右), str(皮左)])
	# 源形状：原版三个入口都是 talkToNPC → requestNPCTalk(54) → directionNPC；本工程把转身挂在
	# `_open_dialog` 第一句 ⇒ 三条路一起生效，这里钉「先转身再发 54」这个顺序。
	var 源 := FileAccess.get_file_as_string(实体脚本)
	var 起 := 源.find("func _open_dialog")
	if 起 >= 0:
		var 段 := 源.substr(起, 320)
		_记(段.contains("_让NPC面朝玩家(npc_id)") and 段.find("_让NPC面朝玩家") < 段.find("request_npc_dialog"),
			"先转身、再发 54/开窗（顺序与原版一致）")
	_记(源.contains("_player.global_position.x else 1.0"),
		"转身算式照原版：NPC 的 x 比玩家大 ⇒ 面朝左，否则面朝右")

## —— C：源形状（防融合方把这两处改回去）——
func _C_源形状() -> void:
	var 源 := FileAccess.get_file_as_string(面板脚本)
	var 起 := 源.find("func _追踪链接点击")
	var 止 := 源.find("func _到点开对话")
	_记(起 >= 0 and 止 > 起, "取到 _追踪链接点击 的函数体")
	if 起 >= 0 and 止 > 起:
		var 段 := 源.substr(起, 止 - 起)
		# 只看**真正的调用**：函数里那段解释"以前为什么错"的注释也写着这个词，
		# 拿整段 contains 比会把注释当罪证（门红得没道理，下次就有人删注释来"修门"）。
		var 假对话: Array[String] = []
		for 行 in 段.split(换行):
			var 去 := 行.strip_edges()
			if 去.begins_with("#"):
				continue
			if 去.contains("show_npc_dialog("):
				假对话.append(去)
		_记(假对话.is_empty(),
				"_追踪链接点击 里不许再有 show_npc_dialog **调用**（那是本地假对话 = ③ 的根因）%s" % str(假对话))
		_记(段.contains("前往NPC(id)"), "两条 NPC 链接都汇到 前往NPC(id) 这一份出口")
		_记(段.contains("_走向任务怪(u)"), "怪那一条从同一个入口分出去（不许再另起一套）")
	var 起2 := 源.find("func _走向任务怪")
	var 止2 := 源.find("func _通往")
	if 起2 >= 0 and 止2 > 起2:
		var 段2 := 源.substr(起2, 止2 - 起2)
		_记(段2.contains("if not bool(玩家.call("), "点怪那一条判了 `走向()` 的返回值（② 的根因）")
	_记(源.contains("_待进门 = 门.duplicate(true)"), "走到传送点后有个「待进门」状态（一步跨图真的接了门）")
	# 会话那一层：进度帧到达时**必须真的调解析**，`data` 丢掉就等于 ④ 一个数字都不动
	var 会话源 := FileAccess.get_file_as_string(会话路)
	_记(会话源.contains("var 新目标: Array = _解进度帧("),
			"会话收到 444 进度帧时调了 _解进度帧（不调 = 面板永远 0/3）")
	_记(会话源.contains("条[\"目标进度\"] = _并目标("),
			"解出来的逐项进度**并进**这条任务的 目标进度（覆盖式赋值会抹掉别的 kind）")
	# kind 那条判据要读**后端**的源（面板里根本没有 444）
	var 后端源 := FileAccess.get_file_as_string(后端路)
	var 几处 := 0
	for 行 in 后端源.split(换行):
		if 行.strip_edges().begins_with(引 + "kind" + 引 + ": str(fields[4])"):
			几处 += 1
	_记(几处 == 2,
			"444:1 与 444:2 两条进度分支都把 kind 当**字符串**交出去（服务端发的就是 mob/item/npc…，"
			+ "④ 的第一层就坏在这儿）现在 %d 处" % 几处)
	var 退回 := false
	for 行 in 后端源.split(换行):
		if 行.strip_edges().begins_with("#"):
			continue
		if 行.contains(引 + "kind" + 引 + ": String("):
			退回 = true
	_记(not 退回, "这两条上不许再退回 `String(Variant)` —— #149 那一类无效调用")





## 看门狗：`_跑` 里任何一条 script error 都会让它**直接中断**（不 return、不 quit）
## ⇒ 进程挂着不走，外面看就是「跑了三分钟没结果」（本轮量具真挂过一次，180 秒超时才发现）。
## 有了这条，中途坏掉也会留下「共 N 条，红 >=1」和一个非 0 退出码，变异实测才读得懂。
func _等条件(谓词: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if bool(谓词.call()):
			return true
		await create_timer(0.05).timeout
	return false

func _看门狗() -> void:
	if await _等条件(func(): return 总 > 0 and str(日志[日志.size() - 1]).begins_with("汇"), 90000):
		return
	_记(false, "看门狗：90 秒没跑到汇总（_跑 中途 script error 或某步没回帧）")
	_尾()



func _尾() -> void:
	# 单例里的图号是我为了驱动 _通往 改的，别把它留给后面的门
	# （跑批是同进程顺序跑，上一道门留的态会让下一道门假绿/假红）。
	if 后端 != null:
		后端.set("authoritative_map_id", 0)
	if 会话 != null:
		会话.set("current_map_id", "")
	var 存档后 := _存档字节()
	_记(存档后 == 存档前, "跑完 user://玩家数据.json 没被写（前 %s 后 %s）" % [存档前, 存档后])
	日志.append("")
	日志.append("汇：共 %d 条，红 %d 条" % [总, 红数])
	var f := FileAccess.open("res://测试/截图/追踪栏四修门日志.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(换行.join(日志) + 换行)
		f.close()
	for 行 in 日志:
		print(行)
	quit(0 if 红数 == 0 else 1)

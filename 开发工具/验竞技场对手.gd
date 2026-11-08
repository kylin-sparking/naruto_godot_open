extends SceneTree

## 竞技场**对手实体**自检（#334，**有头**，不能加 --headless —— 要拿视口图像）。
##
## 判的是这一条链：服务端那条 `238:arena-player:…`（26 段）喂进 `_handle_bridge_text` 之后
## ① 认得出是"对手"而不是普通怪（`后端连接._arena_对手帧`）
## ② 在**怪物那一本账**上成了形（`_entities_by_object` 有号 ⇒ 可选中、可追打、掉血照 243/252 走）
## ③ 身体按**玩家**画（取 `character` 那张动作表，不是 mob 的 `1000001`）
## ④ 怪物帧的四个动作名（move/attack1/hit1/die1）在角色美术上**解得到**（`原始动画精灵._动作名`）
## ⑤ 头顶那行字是他的名字
## ⑥ **打得着它**：体型盒等于原版角色那一档常量（`Character.as:86`）、玩家贴过去之后
##    `get_enemies_in_rect(玩家.攻击矩形())` 收得到它、`perform_basic_attack()` 回 true
##    —— 用户实机报的「为什么我攻击不了」就是这一条整条是空的（人物帧没有逐帧 lt/rb，
##    而每一条谓词都写 `盒.size == ZERO ⇒ 跳过`）。
## 外加两条对照：**普通怪**仍然走自己的名字（别名层不许污染它）、`face=0` 也有身体，
## 以及一条**门的自检**：怪换成一档不存在的动作 ⇒ 盒子必须回空（否则⑥那两条是"一律给个盒"骗过去的）。
##
## 夹具是**服务端原文串**（段序逐条数过 `服务端/runtime/tools/fake_flash_server.py:29490-29533`），
## 不是手写的猜测串。
##
## 用法：Godot --path . --script res://开发工具/验竞技场对手.gd
##   退出码 0 = 全过；1 = 有红；2 = 前置条件不满足（拿不到 LifeRoot/会话）

const 出图 := "res://测试/截图/竞技场/对手.png"
const 竞技场图 := "503000000"
const 对手号 := 1500301301
const 对照怪号 := 700001
## 26 段：0=238 1=arena-player 2=oid 3=1 4=肤色 5=图 6/7=坐标 8=0 9/10=落脚点 11=0 12=true
## 13=首攻 14/15=出生 16=头像 17=等级 18=名字 19=攻速 20=移速 21=招式 22=装备 23=灵面 24=灵色 25=神器
const 对手帧 := "238:arena-player:%d:1:0:%s:1450:862:0:0:0:0:true:1:1450:862:" % [对手号, 竞技场图] \
	+ "10000204:55:乙一:7:175:101&3@102&5:2&30000101@3&30000102:0:0:111@222"
## face=0（老档/服务端没写头像）⇒ 该走 `角色造型.造型号` 的兜底档，而不是画成一团空气
const 零脸帧 := "238:arena-player:%d:1:0:%s:1500:862:0:0:0:0:true:1:1500:862:" % [对手号 + 1, 竞技场图] \
	+ "0:55:丙零:7:175:-:-:0:0:-"
## 阳性对照：一条**普通怪**帧（模板号 1000001 在 `数据/角色/动画元数据.json` 的 mob 表里真有 move）
const 普通怪帧 := "238:1:%d:0:1000001:%s:1200:800:0:0:0:0:true:0:1200:800:0:0:-:-" % [对照怪号, 竞技场图]

var _帧 := 0
var _场景: Node = null
var _生命: Node = null
var _后端: Node = null
var _会话: Node = null
var _对手: Node = null
var _怪: Node = null
var _精灵: Node = null
var _判: Array = []
var _阶段 := 0
var _等待 := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://测试/截图/竞技场"))
	var 场 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场 == null:
		push_error("拿不到 地图场景.tscn")
		quit(2)
		return
	_场景 = 场.instantiate()
	root.add_child(_场景)


func _演员(object_id: int) -> Node:
	if _生命 == null:
		return null
	return _生命.call("_活演员", object_id)


func _精灵_of(演员: Node) -> Node:
	if 演员 == null:
		return null
	for 子 in 演员.get_children():
		if 子.has_method("configure"):
			return 子
	return null


func _process(_秒: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	match _阶段:
		0:
			_后端 = root.get_node_or_null("BackendConnection")
			_会话 = root.get_node_or_null("GameSession")
			_生命 = _场景.get_node_or_null("LifeRoot")
			_判.append(["后端自动加载在（root/BackendConnection）", _后端 != null])
			_判.append(["会话自动加载在（root/GameSession）", _会话 != null])
			_判.append(["地图场景里有 LifeRoot（地图实体）", _生命 != null])
			if _后端 == null or _会话 == null or _生命 == null:
				push_error("前置条件不满足")
				quit(2)
				return true
			_会话.set("current_map_id", 竞技场图)
			_判.append(["把当前图切进竞技场图 503000000", String(_会话.get("current_map_id")) == 竞技场图])
			_后端.call("_handle_bridge_text", 对手帧)
			_后端.call("_handle_bridge_text", 普通怪帧)
			_阶段 = 1
			_等待 = 4
		1:
			if _等待 > 0:
				_等待 -= 1
				return false
			_对手 = _演员(对手号)
			_怪 = _演员(对照怪号)
			_判.append(["arena-player 那一支认出来了（对手演员建出）", _对手 != null])
			_判.append(["普通怪那一支没被误认（对照演员也建出）", _怪 != null])
			if _对手 == null or _怪 == null:
				_收()
				return true
			_精灵 = _精灵_of(_对手)
			var 怪精灵 := _精灵_of(_怪)
			if _精灵 == null or 怪精灵 == null:
				_判.append(["两具都挂上了精灵", false])
				_收()
				return true
			_判身体(_精灵, 怪精灵)
			_判动作(_对手, _精灵, _怪, 怪精灵)
			_判可打(_对手, _怪)
			_喂("252:%d:50" % 对手号)
			_喂("243:%d:12" % 对手号)
			_阶段 = 2
			_等待 = 3
		2:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 比 := float(_对手.get("hp")) / maxf(1.0, float(_对手.get("max_hp")))
			_判.append(["252 那档 50% ⇒ 血条比例跟着到 0.5（服务端说了算）", absf(比 - 0.5) <= 0.01])
			_喂("252:%d:0" % 对手号)
			_阶段 = 3
			_等待 = 3
		3:
			if _等待 > 0:
				_等待 -= 1
				return false
			_判.append(["血包到 0 ⇒ 当场死（不等 239）", not bool(_对手.get("alive"))])
			_后端.call("_handle_bridge_text", 零脸帧)
			_阶段 = 4
			_等待 = 4
		4:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 零 := _演员(对手号 + 1)
			_判.append(["face=0 的对手也建得出（走 造型号 兜底档）", 零 != null])
			var 零精灵 := _精灵_of(零)
			var 零表: Dictionary = (零精灵.get("actions") as Dictionary) if 零精灵 != null else {}
			_判.append(["face=0 那具同样是角色那套表（有 walk）", 零表.has("walk")])
			_判.append(["face=0 那具头顶名字照旧（读屏幕值）", 零 != null and _名牌(零).begins_with("丙零")])
			_把镜头挪到对手旁边()
			_阶段 = 5
			_等待 = 6
		5:
			if _等待 > 0:
				_等待 -= 1
				return false
			_抓图()
			_收()
			return true
	return false


## 出证据图用的：把本地那具挪到对手旁边，相机自己跟过去 ⇒ 截图里能同时看见
## 「对手（人形）」与「对照怪」。这一步不参与任何判据。
func _把镜头挪到对手旁边() -> void:
	var 玩家 := _生命.get("_player") as Node2D
	if 玩家 == null:
		玩家 = _场景.get_tree().get_first_node_in_group("player") as Node2D
	if 玩家 != null and _对手 != null:
		玩家.position = Vector2(float(_对手.position.x) - 150.0, float(_对手.position.y))


func _喂(串: String) -> void:
	_后端.call("_handle_bridge_text", 串)


## 头顶那行字**读屏幕值**（Nameplate 那个 Label），不读 `actor.display_name` ——
## 后者是声明值，kind=="m" 那一支还会在 `_add_nameplate` 里被改写成「名字 N级」。
func _名牌(演员: Node) -> String:
	var 牌 := 演员.get_node_or_null("Nameplate") as Label
	return 牌.text if 牌 != null else "〈没有 Nameplate〉"


## 这一帧**真的画在屏幕上**的那张贴图的路径（`_apply_frame` 把 className 解成路径再 load）。
func _贴图路(演员: Node) -> String:
	var 精灵 := _精灵_of(演员)
	if 精灵 == null:
		return ""
	var 内 := 精灵.get("sprite") as Sprite2D
	if 内 == null or 内.texture == null:
		return ""
	return String(内.texture.resource_path)


## 原版 `Character.as:86` 给**每一具角色**一个固定体型盒（人物帧里没有逐帧 lt/rb，
## 实测 `数据/角色/动画元数据.json`：mob 45678/45678 帧全带、character 0/6521 帧带）：
##   `protected var _bodyRect:Rectangle = new Rectangle(-27,-95,54,95);`
## `Character.as:728-738` 的 `outerBodyRect` = 它按朝向镜像（`GeomUtil.copyRectangle`）
## 再 `offset(x, y)` 平移到角色坐标。参照值在这里**自己算**，不向被测对象要。
const 原版人物体型 := Rect2(-27.0, -95.0, 54.0, 95.0)


## 「我攻击不了」那一条的判据（2026-10-24）。
## 对手是"穿人物皮的怪"，而**每一条**命中/选敌谓词都写着 `盒.size == ZERO ⇒ 跳过`
## （`地图实体.gd:353/377/511`）⇒ 体型盒一空，它就永远进不了任何矩形，
## `_够得着()` 恒假、`_结算攻击` 的 enemy 恒 null ⇒ 连上行 40 都不发。
func _判可打(对手: Node, 怪: Node) -> void:
	var 玩家 := _玩家() as Node2D
	if 玩家 == null:
		_判.append(["拿得到本地那具玩家（打人的链要从它身上走）", false])
		return
	var 期望 := 原版人物体型
	期望.position += 对手.position
	var 盒: Rect2 = _生命.call("怪物体型盒", 对手) as Rect2
	_判.append(["对手有体型盒，且等于原版 Character.as:86 那一档平移到角色坐标（实测 %s / 期望 %s）" % [str(盒), str(期望)], 盒 == 期望])
	var 怪盒: Rect2 = _生命.call("怪物体型盒", 怪) as Rect2
	_判.append(["对照那只怪的盒子仍是逐帧解出来的（非空、且不是人物那一档）",
			怪盒.size != Vector2.ZERO and 怪盒.size != 原版人物体型.size])
	## 阳性对照：兜底**只许**对穿人物皮的生效 —— 把怪的动作改成一档不存在的，
	## 帧里查不到 lt/rb 而造型类别是 mob ⇒ 必须回空盒。少了这条，"一律给个盒"也能骗过上面两条。
	var 怪精灵 := _精灵_of(怪)
	var 原动作 := String(怪精灵.get("action"))
	怪精灵.set("action", "_这一档不存在_")
	_判.append(["怪换成一档不存在的动作 ⇒ 盒子回空（证明人物那一档没被当万能兜底）",
			(_生命.call("怪物体型盒", 怪) as Rect2) == Rect2()])
	怪精灵.set("action", 原动作)
	## ★ 真走一遍"出手"里的那一步判定：把玩家摆到对手左侧 40 像素、朝右，
	## 让 `玩家.攻击矩形()`（50×50，贴着朝向那一侧）罩住对手，再问一次收敌函数。
	玩家.position = Vector2(float(对手.position.x) - 40.0, float(对手.position.y))
	玩家.set("facing", 1)
	玩家.set("attack_cooldown", 0.0)
	玩家.set("出手中", false)
	var 命中盒: Rect2 = 玩家.call("攻击矩形") as Rect2
	var 命中: Array = _生命.call("get_enemies_in_rect", 命中盒) as Array
	_判.append(["玩家贴到对手左边时，攻击矩形 %s **收得到**对手（修前这一条恒空）" % str(命中盒), 命中.has(对手)])
	_判.append(["perform_basic_attack() 真认下了目标（回 true ⇒ `_结算攻击` 里 enemy 非空）",
			bool(玩家.call("perform_basic_attack", -1, 105.0, true))])


func _玩家() -> Node2D:
	var 玩 := _生命.get("_player") as Node2D
	if 玩 == null:
		玩 = _场景.get_tree().get_first_node_in_group("player") as Node2D
	return 玩


func _判身体(精灵: Node, 怪精灵: Node) -> void:
	var 表: Dictionary = 精灵.get("actions") as Dictionary
	var 怪表: Dictionary = 怪精灵.get("actions") as Dictionary
	## ③ 身体取的是角色表：有 walk、**没有** move（mob 表才有 move）⇒ 证明按 face 画成了人
	_判.append(["对手身体取自角色那张表（有 walk）", 表.has("walk")])
	_判.append(["对手身体不是怪物那张表（没有 move）", not 表.has("move")])
	## 造型号取对了没有：帧上的 className 里烙着 `Char_<造型号>`（`动画元数据.json` 现查的形状），
	## 拿它当独立证据 ⇒ 判的是"真按帧里那个头像号解出了身体"，不是"我确实调过 configure"。
	_判.append(["对手造型号 = 帧里的头像号 10000204", str(表.get("stand", {})).contains("Char_10000204")])
	_判.append(["对照那具是怪物表（真有 move）", 怪表.has("move")])
	_判.append(["对手头顶那行字是他的名字（读 Nameplate 的屏幕值）", _名牌(_对手).begins_with("乙一")])
	_判.append(["对手头顶没写成「怪物」（屏幕值）", "怪物" not in _名牌(_对手)])
	_判.append(["对手在怪物那一本账上（可被选中/追打）", bool(_对手.get("authoritative"))])
	## "按玩家样子画"这句必须落到**屏幕上那张贴图**，不是落到 actions 字典：
	## 帧上的 className 一路带到 `素材/角色动画/玩家/原版角色_<号>/…`，拿路径当独立证据。
	var 贴图 := _贴图路(_对手)
	var 怪贴图 := _贴图路(_怪)
	_判.append(["对手屏幕上画的是头像号 10000204 那张身体", 贴图.contains("10000204")])
	_判.append(["对照那具画的仍是怪物图（Mob_1000001）", 怪贴图.contains("Mob_1000001")])
	_判.append(["两具画的不是同一张贴图", 贴图 != 怪贴图])


func _判动作(演员: Node, 精灵: Node, 怪演员: Node, 怪精灵: Node) -> void:
	## ④ 服务端发的是怪物帧的名字，角色美术里没这四个 ⇒ 精灵那一层必须翻得到
	for 名 in ["move", "attack1", "hit1", "die1"]:
		_判.append(["角色美术上解得到怪物帧的动作名「%s」" % 名, bool(演员.call("有动作", 名))])
	演员.call("_play_state", "move")
	_判.append(["_play_state(move) ⇒ 停在 walk", String(精灵.get("action")) == "walk"])
	演员.call("_play_state_once", "attack1")
	_判.append(["_play_state_once(attack1) ⇒ attack", String(精灵.get("action")) == "attack"])
	演员.call("_play_state_once", "hit1")
	_判.append(["_play_state_once(hit1) ⇒ hit", String(精灵.get("action")) == "hit"])
	演员.call("_play_state_once", "die1")
	_判.append(["_play_state_once(die1) ⇒ dead", String(精灵.get("action")) == "dead"])
	_判.append(["受击僵直拿得到时长（hit1 翻成 hit 之后 >0 毫秒）", int(精灵.call("动作时长毫秒", "hit1")) > 0])
	## 阳性对照：普通怪六个名字本来就有 ⇒ 别名层一条都不该动它
	怪演员.call("_play_state", "move")
	_判.append(["普通怪 move 仍是 move（别名层没污染它）", String(怪精灵.get("action")) == "move"])
	怪演员.call("_play_state_once", "attack1")
	_判.append(["普通怪 attack1 仍是 attack1", String(怪精灵.get("action")) == "attack1"])


func _抓图() -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	if 图.save_png(出图) != OK:
		push_error("存图失败：" + 出图)
		return
	print("竞技场对手：%s（%dx%d）" % [出图, 图.get_width(), 图.get_height()])


func _收() -> void:
	var 红 := 0
	for 一 in _判:
		var 过: bool = bool(一[1]) if 一.size() > 1 else false
		if not 过:
			红 += 1
		print("  %-4s  %s" % ["通过" if 过 else "红", 一[0]])
	print("竞技场对手自检：判 %d 条，红 %d 条" % [_判.size(), 红])
	quit(0 if 红 == 0 else 1)

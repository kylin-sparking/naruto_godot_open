extends SceneTree

## 「点世界里的角色不许崩」回归门（2026-10-04，用户实机报「为什么点击npc就崩溃了」，
## 调试面板那行是 `_select_character: Invalid call. Nonexistent 'String' constructor.`）。
##
## 根因：`地图实体.gd` 用 `String(actor.get("kind"))` 判"是不是怪"。
##   远程玩家是 `_on_server_player_spawned()` 里 `Node2D.new()` 建的**裸节点**（`:256`），
##   它**没有 `kind` 属性** ⇒ `Object.get("kind")` 返回 null；
##   而 4.7 的 `String(null)` 没有对应构造器 ⇒ 当场抛、函数**中途死掉**
##   （`select_map_character` 再也发不出去，点谁都没反应）。
##   ⇒ 一律写 `str()`（`str(null)` = "<null>"，比 `== "m"` 恒假，正好落回"这是角色/NPC"那一支）。
##
## 两条判据：① 行为 —— 点 NPC / 怪 / 裸节点（远程玩家形状）三种，都必须把选中设上、
##   非怪必须真的把 `map_character_selected` 发出去（崩在半路就发不出来）；
##   ② 文本 —— 那四处读 `kind` 的地方不许再出现 `String(`。
##
## 运行：Godot --headless --path . --script res://测试/点角色不崩回归测试.gd

const 地图场景 := "res://场景/地图/地图场景.tscn"
const 实体脚本 := "res://脚本/地图/地图实体.gd"
## 文本判据要递归扫的目录（写成常量，免得注释里出现 `res://…*.gd` 这种假依赖骗过打包器自审）
const 脚本根 := "res://脚本"
## 全工程只允许**这一种**读 kind 的写法；数一遍是几条，改了/加了都会红。
## 第 5 处是 2026-10-10 #153 加的 `地图实体.gd::_让NPC面朝玩家()`
## （说话时要挑出那个 NPC 让它转身 ⇒ 同样只能用 `str(实体.get("kind"))`，
##   远程玩家是裸 Node2D、没有 kind，`String(null)` 会把整条对话打挂 = 本门原来钉的那件事）。
const 读kind处数 := 5

var 帧 := 0
var 场景: Node
var 实体: Node
var 信号数 := 0
var 红 := 0
var 日志: Array[String] = []
## ③「点地面不清选中」那一段要跨帧（`push_input` 的事件在下一帧才走到 `_unhandled_input`），
## 所以把这几样存成成员，帧 26 布景、帧 32 收账。
var 裸点: Node2D = null
var 原玩: Node2D = null
var 假玩: Node2D = null
var 原后: Node = null
var 记后: Node = null
var 清数 := 0


func _记(过: bool, 文本: String) -> void:
	if not 过:
		红 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文本])


func _process(_d: float) -> bool:
	帧 += 1
	if 帧 == 4:
		场景 = (load(地图场景) as PackedScene).instantiate()
		root.add_child(场景)
	elif 帧 == 26:
		_跑()
	elif 帧 == 32:
		_收点地面()
		for 一 in 日志:
			print(一)
		print("点角色不崩回归：%s（红 %d 项）" % ["通过" if 红 == 0 else "不通过", 红])
		quit(1 if 红 > 0 else 0)
		return true
	return false


func _找脚本(父: Node, 尾: String) -> Node:
	var s = 父.get_script()
	if s != null and String(s.resource_path).ends_with(尾):
		return 父
	for 子 in 父.get_children():
		var 果 := _找脚本(子, 尾)
		if 果 != null:
			return 果
	return null


## 递归扫 脚本根 目录下所有 .gd，把 `String(X.get("键"))`（无默认值）的行点名出来。
## 返回扫过的 .gd 文件数（顺手钉一下"门确实扫到了全工程"，别扫了个空目录还报绿）。
func _扫脚本(路: String, 坏: Array) -> int:
	var 数 := 0
	var d := DirAccess.open(路)
	if d == null:
		坏.append("打不开目录 %s（门没扫到东西）" % 路)
		return 0
	d.list_dir_begin()
	var 名 := d.get_next()
	while 名 != "":
		var 全 := 路.path_join(名)
		if d.current_is_dir():
			if 名 != "addons" and not 名.begins_with("."):
				数 += _扫脚本(全, 坏)
		elif 名.ends_with(".gd"):
			数 += 1
			var 行号 := 0
			for 行 in FileAccess.get_file_as_string(全).split("\n"):
				行号 += 1
				var 去 := 行.strip_edges()
				if 去.begins_with("#"):
					continue
				var i := 去.find("String(")
				while i >= 0:
					var j := 去.find('.get("', i)
					if j < 0:
						break
					var 闭 := 去.find("\"", j + 6)
					if 闭 > 0 and 去.substr(闭 + 1, 2) == "))":
						坏.append("%s:%d %s" % [全, 行号, 去.left(88)])
					i = 去.find("String(", i + 7)
		名 = d.get_next()
	d.list_dir_end()
	return 数


func _跑() -> void:
	# ──  文本判据（**全工程**，不只这个文件）──────────────────────────────
	# `String(X.get("属性"))`（**没有默认值**那一型）= 读的是节点属性/可能缺失的键，
	# 拿到 null 就当场抛、函数中途死掉。带默认值的 `String(dict.get("k",""))` 不在此列。
	# 2026-10-04 一次修掉 12 处（地图实体 5 + 功能窗口/小地图面板/人物窗口/宠物窗口/家族令牌填充 7），
	# 基线钉在 0 ⇒ 谁再写这种形状，这道门直接红并且点名文件行号。
	var 坏 := []
	var 扫文件数 := _扫脚本(脚本根, 坏)
	_记(坏.is_empty(), "全工程 %d 个 .gd 里没有 `String(X.get(\"属性\"))`（违规：%s）" % [扫文件数, str(坏)])
	var 文 := FileAccess.get_file_as_string(实体脚本)
	var 计数 := 0
	for 行 in 文.split("\n"):
		var 去: String = 行.strip_edges()
		if 去.begins_with("#"):
			continue
		if 去.contains('.get("kind")'):
			计数 += 1
	_记(计数 == 读kind处数, "读 kind 的行数 = %d（登记值 %d，多了说明新加了判点、少了说明有人删了判据）"
			% [计数, 读kind处数])

	# ── ① 行为判据 ──────────────────────────────────────────────────────
	实体 = _找脚本(场景, "地图实体.gd")
	if 实体 == null:
		_记(false, "找不到挂 地图实体.gd 的节点")
		return
	var 会 = root.get_node("/root/GameSession")
	会.connect("map_character_selected", func(_i: Dictionary) -> void: 信号数 += 1)
	var 列: Array = 实体.get("_entities")
	_记(列.size() > 0, "地图里有可点角色（%d 个）" % 列.size())
	var 怪数 := 0
	var 非怪数 := 0
	for 个 in 列:
		if str(个.get("kind")) == "m":
			怪数 += 1
		else:
			非怪数 += 1
		信号数 = 0
		实体.call("_select_character", 个, {"id": String(个.name)})
		_记(实体.get("_selected_character") == 个, "%s 选中设上了" % String(个.name))
		# 两种都必须**恰好发一次**：NPC 走 `_session.select_map_character(info)`，
		# 怪走 `显示目标框()`（`:726-731` 里面同样调了 `select_map_character`）。
		# 发 0 次 = 函数在半路抛了（就是这次的 bug）；发 2 次 = 两条路都走了。
		_记(信号数 == 1, "%s kind=%s ⇒ 选中信号发了 %d 次（两种都该恰好 1 次）"
				% [String(个.name), str(个.get("kind")), 信号数])
	_记(怪数 > 0 and 非怪数 > 0, "样本覆盖两种：怪 %d、NPC %d" % [怪数, 非怪数])

	# 远程玩家那一支：**没有 kind 属性**的裸 Node2D（`Node2D.new()` + SelectionMarker）
	var 裸 := Node2D.new()
	裸.name = "裸节点_远程玩家形状"
	var 标记 := Node2D.new()
	标记.name = "SelectionMarker"
	裸.add_child(标记)
	实体.add_child(裸)
	信号数 = 0
	实体.call("_select_character", 裸, {"id": "裸"})
	_记(裸.get("kind") == null, "前提成立：裸节点确实没有 kind（get 返 null）")
	_记(实体.get("_selected_character") == 裸 and 信号数 == 1,
			"点裸节点（远程玩家形状）：选中设上、信号发出（崩在半路就发不出）；实发 %d 次" % 信号数)

	# ──  选中**玩家**那一刻要发 `94:4` 去要对方的真实属性 ─────────────────────
	# 用户 10-15：「血量值和查克拉值应该是跟选中角色真实属性一致的」。
	# 原版 `TargetHandler.set viewTarget():275-278` 就是 `param1 is Character ⇒
	# requestTargetCharacterInfo(objectId)`，服务端回 `TARGET_INFO(1284)` 才有条上那四个数；
	# 而出场帧 162 **没有**血量段（`SpawnPlayerInfo.decode():61-94` 那 29 段里没有 hp）⇒
	# 不发这一发，条上只能是自造的 100/100。
	原后 = 实体.get("_backend")
	记后 = 记属性后端.new()
	实体.set("_backend", 记后)
	信号数 = 0
	实体.call("_select_character", 裸, {"id": "裸", "type": 1, "char_id": 1002})
	_记((记后.get("发过") as Array) == [1002],
			"选中玩家档(type=1) ⇒ 发一次 `94:4:1002` 要真实属性（实发 %s）" % str(记后.get("发过")))
	(记后.get("发过") as Array).clear()
	实体.call("_select_character", 裸, {"id": "裸", "type": 2, "char_id": 1002})
	_记((记后.get("发过") as Array).is_empty(),
			"NPC 档(type=2) 不发这一发 —— 原版 NPC 走 `showDetailWindowOnMe`（实发 %s）" % str(记后.get("发过")))
	实体.set("_backend", 原后)

	# ── ③ 点地面**不清选中**（用户 10-15：点完角色再点地面，头像界面不该消失）────
	# 原版 `viewTarget = null` 只有四个来源：`cancelTarget()`（点信息条上那枚头像）、
	# `setCurTarget(null)`、`clear()`（换图/死亡）、角色/怪**离场**
	# （`TargetHandler.as:253/315/466`、`CharacterHandler.as:120`、`MonsterHandler.as:426/477`）。
	# 移动指令根本不动它 ⇒ 这里要验的是"一次没被任何控件接住的左键落到 `_unhandled_input`
	# 之后，选中还在、也不发 cleared 信号"。
	# ⚠ `push_input` 的事件要**下一帧**才走到回调 ⇒ 这一段只布景，账在帧 32 收。
	裸点 = 裸
	原玩 = 实体.get("_player")
	假玩 = 记停追打.new()
	实体.set("_player", 假玩)
	会连清()
	root.size = Vector2i(960, 560)		# 无头默认 64×64 ⇒ 不顶掉的话点不到"空白处"
	## 先把上一段留下的"目标框还盯着最后那只怪"清掉：`_process` 的轮询会在接下来几帧里
	## 反复替那只怪重发选中信号（怪的血在动），不清就把这一段的计数搅浑。
	实体.set("_view_target", null)
	实体.set("_selected_character", null)
	实体.call("_select_character", 裸点, {"id": "裸"})
	信号数 = 0		# 布景之后才清零 ⇒ 判的是"这一下点击有没有再发"
	清数 = 0
	## ⚠ 这里**不走 `push_input`**：实测往 (480,230) 投一发左键，那一点正好落在某只怪的
	## 交互区（`_add_monster_interaction` 那颗 90×110 的 Area2D）⇒ 事件被怪接走、
	## `_selected_character` 直接换成那只怪，测的就不是"没被接住的点击"了。
	## 相机位置随落脚点变 ⇒ 没有一个稳定的"空地屏幕坐标"可写。所以把**真事件对象**
	## 交给真回调（`InputEventMouseButton` 是真的、走的就是 `_unhandled_input` 这一段），
	## 而"这一击确实走到了回调"由 `停止追打` 的计数当正向对照 —— 停在 0 就是门自己坏了。
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = Vector2(480.0, 230.0)
	按.global_position = 按.position
	按.pressed = true
	实体.call("_unhandled_input", 按)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.position = 按.position
	放.global_position = 按.position
	放.pressed = false
	实体.call("_unhandled_input", 放)


## 清选中的信号计数要在**布景之前**接上（`_ready` 早就接完了，这里只是再加一个监听）。
func 会连清() -> void:
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null and not 会.is_connected("map_character_selection_cleared", 数清):
		会.connect("map_character_selection_cleared", 数清)


func 数清() -> void:
	清数 += 1


## 帧 32：收"点地面"那一下的账。
func _收点地面() -> void:
	## **正向对照**：这一击要真的落到 `_unhandled_input` 里，否则下面两条是空判。
	## 拿"停止追打被叫到"当证据 —— 它和"不清选中"在同一个函数体里，
	## 停在 0 就说明事件根本没进来（那就是门自己坏了，不是行为对了）。
	_记(int(假玩.get("停")) == 1,
			"点地面这一下真的走到了 _unhandled_input（正向对照：停止追打被叫到 %d 次）" % int(假玩.get("停")))
	_记(实体.get("_selected_character") == 裸点,
			"点地面之后**选中还在**（原版移动指令不清 viewTarget）")
	_记(清数 == 0, "点地面没有发 `map_character_selection_cleared`（实发 %d 次）" % 清数)
	_记(信号数 == 0, "点地面也没有重复发选中信号（实发 %d 次）" % 信号数)
	## 反向对照：**点头像**那一下必须清掉（`onClickHead` = `cancelTarget()`），
	## 不然上面三条可以靠"谁都别清"混过去。
	实体.call("取消选中")
	_记(实体.get("_selected_character") == null, "反向对照：点「取消选中」这条路径仍然清得掉")
	_记(清数 == 1, "反向对照：清掉时确实发了 1 次 cleared 信号（实发 %d）" % 清数)
	实体.set("_player", 原玩)
	假玩.free()


## 记下发过哪几发 `94:4`。`in_game` 必须是**真属性**（地图实体那支会先判在线）。
class 记属性后端 extends Node:
	var in_game := true
	var 发过: Array = []

	func request_character_info(号: int) -> bool:
		发过.append(号)
		return true


## 只记一件事：自动追打被叫停了几次（当作"这一击走到了回调"的正向对照）。
class 记停追打 extends Node2D:
	var 停 := 0

	func 停止追打() -> void:
		停 += 1

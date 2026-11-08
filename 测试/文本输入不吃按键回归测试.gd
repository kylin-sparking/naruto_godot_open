extends SceneTree

## 「焦点在文本输入里时，动作键一律不生效」回归门。
##
## 真值：原版靠 Flash 的**舞台焦点**分流 —— `ChatPane.__onKeyDown`（`ChatPane.as:813`）：
##
##     if(API.stage.focus == this.inputTextField) { …只喂输入框（ESC 收焦点、上下翻记录、ENTER 发送）… }
##     else { …ENTER 抢焦点 / ESC 关窗… }
##
## ⇒ 在聊天框里打字时，键盘事件**根本走不到 `KeyController`**，不会顺手走路/跳跃/普攻。
## Godot 侧：`Input.is_action_pressed` 是**轮询 Input 单例**、不认 GUI 焦点
## （认焦点的只有 `_unhandled_input` —— `技能面板.gd:29` 的快捷键格用的就是那条）
## ⇒ 2026-10-13 之前，在聊天框/搜索框里打 "asd" 会一边打字一边左右移动、按空格还会跳。
## （`聊天面板.is_input_focused()` 早就在那儿、一直零调用点、就是为这件事留的 —— 已删，
##  判据统一收在 `玩家._键盘被文本占用()`：对**整个视口**判 `gui_get_focus_owner()`。）
##
## 门判的是**行为**，不是"我加了一行 if"：
##   · 没焦点：按住 jump ⇒ 角色**离地**（`on_ground` 翻 false）；
##   · 焦点在 LineEdit 里：按住同一个键 ⇒ 角色**一动不动**。
## 两半必须在**同一次运行**里都量到，否则记红（"没量到不是通过"）。
##
## ⚠ 本门不许写存档：进图会真跑会话 ⇒ 快照 + 还原 + 断言还原本身。
##
## 运行：Godot --headless --path . --script res://测试/文本输入不吃按键回归测试.gd

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 存档 := "user://玩家数据.json"

var _红: Array[String] = []
var _条数 := 0


func _判(说明: String, 成立: bool) -> void:
	_条数 += 1
	if not 成立:
		_红.append(说明)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 快照 := ""
	if FileAccess.file_exists(存档):
		var 原 := FileAccess.open(存档, FileAccess.READ)
		快照 = 原.get_as_text()
		原.close()
	await _行为腿()
	# 还原 + 断言还原本身（旧教训：还原不判 = 门自己把存档改了也没人知道）
	if 快照 != "":
		var 写 := FileAccess.open(存档, FileAccess.WRITE)
		写.store_string(快照)
		写.close()
	var 现 := ""
	if FileAccess.file_exists(存档):
		var 再 := FileAccess.open(存档, FileAccess.READ)
		现 = 再.get_as_text()
		再.close()
	_判("门不许动存档（user://玩家数据.json）", 现 == 快照)
	print("文本输入不吃按键回归测试：共 %d 条，红 %d 条%s" % [_条数, _红.size(), "" if _红.is_empty() else "："] )
	for 项 in _红:
		print("  ✗ ", 项)
	quit(0 if _红.is_empty() else 1)


## 进图 → 找到玩家 → 同一次运行里比"没焦点"与"焦点在输入框"两种状态下的按键效果。
func _行为腿() -> void:
	var 路: String = 地图资源.playable_scene_path(默认地图)
	var 包 := load(路) as PackedScene
	if 包 == null:
		_红.append("加载不到地图场景 %s" % 路)
		return
	## ⚠ 必须在 add_child **之前**钉尺寸：无头默认视口是 (64,64)。
	root.size = Vector2i(960, 560)
	var 场 := 包.instantiate()
	root.add_child(场)
	current_scene = 场
	var 玩: Node = null
	for _i in 180:
		await physics_frame
		玩 = get_first_node_in_group("player") as Node
		if 玩 != null and 玩.get("footholds") != null and bool(玩.get("on_ground")):
			break
	if 玩 == null:
		_红.append("进图后找不到玩家（组 player）⇒ 这一腿没量到")
		return
	if 玩.get("footholds") == null:
		_红.append("玩家的 footholds 是空的（没落到脚点上）⇒ 跳跃这一腿没量到")
		return
	_判("玩家已落到脚点上（footholds=%s，on_ground=%s）"
			% [str(玩.get("current_fh_id")), str(玩.get("on_ground"))], bool(玩.get("on_ground")))

	# ① 没焦点：按住 jump ⇒ 离地。
	var 没焦点离地 := await _按一下(玩, "jump")
	_判("没焦点时按住 jump ⇒ 角色离地（原版 `KeyController` 照收）", 没焦点离地)

	# ② 焦点在文本输入里：按住同一个键 ⇒ 一动不动。
	var 框 := LineEdit.new()
	框.name = "门用输入框"
	框.size = Vector2(160.0, 24.0)
	root.add_child(框)
	框.grab_focus()
	await process_frame
	_判("门用输入框真的拿到了焦点（gui_get_focus_owner = %s）" % str(root.gui_get_focus_owner()),
			root.gui_get_focus_owner() == 框)
	_判("玩家的『键盘被文本占用』判据认得出焦点件（实测 %s）" % str(玩.call("_键盘被文本占用")),
			bool(玩.call("_键盘被文本占用")))
	var 有焦点离地 := await _按一下(玩, "jump")
	_判("焦点在文本输入里时按住 jump ⇒ 角色**不离地**（`ChatPane.as:813` 的焦点分流）", not 有焦点离地)

	框.queue_free()
	await process_frame
	_判("输入框拿掉后判据不再认（实测 %s）" % str(玩.call("_键盘被文本占用")),
			not bool(玩.call("_键盘被文本占用")))
	场.queue_free()


## 按住 `动作` 三帧物理帧，返回"玩家是否离地"。按之前先等他落稳，按完放键再等落稳。
func _按一下(玩: Node, 动作: String) -> bool:
	for _i in 180:
		await physics_frame
		if bool(玩.get("on_ground")):
			break
	Input.action_press(动作)
	for _i in 3:
		await physics_frame
	var 离地 := not bool(玩.get("on_ground"))
	Input.action_release(动作)
	for _i in 180:
		await physics_frame
		if bool(玩.get("on_ground")):
			break
	return 离地

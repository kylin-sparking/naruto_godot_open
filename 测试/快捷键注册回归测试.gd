extends SceneTree

## 快捷键**开局就绪**回归：默认那 7 个动作，必须在**建任何场景/窗口之前**
## 就已经存在于 `InputMap` 里，并且绑着默认表里的键。
##
## 为什么需要它（2026-09-25 查出来的实病）
## ----------------------------------------
## 这套注册原先只挂在 `界面/功能窗口.gd` 的 `_ready()` 上，而 `窗口管理` 是**懒建**
## 窗口的（`窗口管理.gd:144`）—— 于是**玩家打开第一个功能窗口之前**：
##
##   * `jump` 这个 action 压根不存在（`project.godot` 的 `[input]` 从没声明过它），
##     而 `玩家.gd:335` 每物理帧直接调 `Input.is_action_pressed("jump")`
##     → 每帧一条 `The InputMap action "jump" doesn't exist`，**跳跃同时是死的**；
##   * **WASD 不生效**：`ui_left/right/up/down` 是内建动作、只自带方向键，
##     A/D/W/S 是那套注册后加的；
##   * 玩家在设置页改过的键位（`game_settings["keybind_*"]`）重启后不生效。
##
## 本用例**故意不建任何场景、不建任何窗口** —— 这正是它有意义的地方：
## 只要有人把注册重新挪回"某个 UI 的构造副作用"上，这里立刻红。
##
## 运行：Godot --headless --path . --script res://测试/快捷键注册回归测试.gd

const 快捷键 := preload("res://脚本/单例/快捷键.gd")

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_验默认已就绪()
	_验应用已存()
	_验改键清空重绑()
	if _失败.is_empty():
		print("快捷键注册回归测试：通过（%d 个动作，默认键 + 存档键 + 改键）" % 快捷键.默认.size())
		quit(0)
	else:
		for 项 in _失败:
			push_error("快捷键注册回归测试：失败 - %s" % 项)
		print("快捷键注册回归测试：失败 %d" % _失败.size())
		quit(1)


## A 组：开局（零场景、零窗口）时，7 个动作全在，且默认键都绑上了。
func _验默认已就绪() -> void:
	for 动作 in 快捷键.默认:
		if not InputMap.has_action(动作):
			_失败.append("开局 `%s` 不在 InputMap 里 —— 注册又被挂到懒加载的窗口上了？" % 动作)
			continue
		for 键码 in 快捷键.默认[动作]:
			if not 快捷键.已有该键(动作, int(键码)):
				_失败.append("开局 `%s` 没绑上默认键 %s" % [动作, OS.get_keycode_string(int(键码))])


## B 组：玩家改过键位后重启，`应用已存` 要把它生效（原来要等开一次窗口才管用）。
func _验应用已存() -> void:
	var 备份 := _快照("jump")
	快捷键.应用已存({"keybind_jump": KEY_K})
	if not 快捷键.已有该键("jump", KEY_K):
		_失败.append("`应用已存` 没把 keybind_jump=K 应用上去")
	if 快捷键.已有该键("jump", KEY_C):
		_失败.append("`应用已存` 之后 jump 仍绑着旧键 C（应当只剩 K）")
	_还原("jump", 备份)
	# 没存过的动作不能被连累
	if not 快捷键.已有该键("ui_left", KEY_A):
		_失败.append("`应用已存` 把没存过的 ui_left 也改坏了")


## C 组：设置页改键走 `应用单个` —— 清空重绑成单个键。
func _验改键清空重绑() -> void:
	var 备份 := _快照("basic_attack")
	快捷键.应用单个("basic_attack", KEY_J)
	if not 快捷键.已有该键("basic_attack", KEY_J):
		_失败.append("`应用单个` 没把 basic_attack 绑到 J")
	if 快捷键.已有该键("basic_attack", KEY_X):
		_失败.append("`应用单个` 没有清掉旧键 X —— 它是「清空重绑」，不是「追加」")
	_还原("basic_attack", 备份)


func _快照(动作: String) -> Array:
	var 出: Array = []
	for 事件 in InputMap.action_get_events(动作):
		if 事件 is InputEventKey:
			出.append(int((事件 as InputEventKey).physical_keycode))
	return 出


func _还原(动作: String, 键码们: Array) -> void:
	InputMap.action_erase_events(动作)
	for 键码 in 键码们:
		var 事件 := InputEventKey.new()
		事件.physical_keycode = int(键码)
		InputMap.action_add_event(动作, 事件)

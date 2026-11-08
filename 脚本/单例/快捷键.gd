extends RefCounted

## 快捷键 —— 默认键位表 + InputMap 注册，**全项目唯一一份**。
##
## 为什么要有这个文件（2026-09-25）
## --------------------------------
## 原先这套东西只活在 `脚本/界面/功能窗口.gd` 里，而且只在 **`功能窗口._ready()`**
## 被调用。问题是 `窗口管理` 是**懒建**窗口的（`窗口管理.gd:144` `_新建窗口`，
## 它自己的 `_ready` 一个都不建）—— 于是**在玩家打开第一个功能窗口之前**：
##
##   * `jump` 这个 action **根本不存在**。`project.godot` 的 `[input]` 只声明了
##     `interact` 与 `basic_attack`，`jump` 从来没进去过。而 `玩家.gd:335` 每物理帧
##     直接调 `Input.is_action_pressed("jump")` —— 实测每帧报一条
##     `The InputMap action "jump" doesn't exist`，**跳跃同时是死的**。
##   * **WASD 不生效**：`ui_left/right/up/down` 是 Godot 内建动作，自带**方向键**；
##     A/D/W/S 是这里后加的，注册之前只有方向键能走。
##   * 玩家在设置页改过的键位（`game_settings["keybind_*"]`）**重启后不生效**，
##     得先随便开一个功能窗口把它带起来。
##
## 注册按键是**开局就该就绪**的事，不该挂在某个 UI 的构造副作用上 ——
## 所以搬到 `脚本/单例/` 下，由 `游戏会话._ready()`（`_load_local_state()` 之后、
## 进图之前）调用。
##
## 分层
## ----
## 本文件不引用 `脚本/界面/` 的任何东西；方向是 `界面/功能窗口.gd` 反向 preload 本文件
## 来渲染「快捷键设置」页。`脚本/界面/` → `脚本/单例/` 是既有的依赖方向，别反过来。

const 默认 := {
	"ui_left": [KEY_A],
	"ui_right": [KEY_D],
	"ui_up": [KEY_W],
	"ui_down": [KEY_S],
	"jump": [KEY_C, KEY_SPACE],
	"basic_attack": [KEY_X],
	"interact": [KEY_E],
	# 原版 `KeyDef.as:479-484` 的 `keyId=KEY_ID_15, name="Tab", canSet=true`：
	# 派发在 `GameKey.as:402`（动作号 51）⇒ `SkillHandler.switchTarget()`。`canSet=true`
	# ⇒ 玩家能在设置页改键，所以走这张表而不是硬判 KEY_TAB。
	"switch_target": [KEY_TAB],
	# 拾取。原版 `KeyDef` 的动作表里 `KEYBOARD_SHORTCUT_KEY_PICK`（名"拾取"、
	# `canSet=true`）默认 `KEY_ID_44` = **Z**；派发在
	# `KeyController.tickPickUpDropItems():793-811`（按住 ⇒ 每 `PICKDELAY=100ms` 挑一次）。
	# 10-12 用户点名"拾取应该是按键盘的 Z"—— 之前这条**根本没有**，只能鼠标点。
	"pick_up": [KEY_Z],
}


## 把默认键位补进 `InputMap`。**只补缺的**，不覆盖已有事件。
##
## `ui_left` 之类是内建动作、自带方向键，这里只把 A/D/W/S 追加进去；
## `interact` / `basic_attack` 已在 `project.godot` 里，会被 `已有该键()` 挡掉、不重复加。
static func 确保默认() -> void:
	for 动作 in 默认:
		if not InputMap.has_action(动作):
			InputMap.add_action(动作)
		for 键码 in 默认[动作]:
			if 已有该键(动作, int(键码)):
				continue
			var 事件 := InputEventKey.new()
			事件.physical_keycode = int(键码)
			InputMap.action_add_event(动作, 事件)


## 应用玩家存过的键位（`game_settings["keybind_<动作>"]`）。
## 没存过的动作保持默认，不动。
static func 应用已存(设置: Dictionary) -> void:
	for 动作 in 默认:
		var 键 := "keybind_%s" % 动作
		if not 设置.has(键):
			continue
		应用单个(动作, int(设置[键]))


## 把某个动作**清空重绑**成单个键 —— 设置页改键走这条（与原来的 `_apply_shortcut_key` 同义）。
static func 应用单个(动作: String, 键码: int) -> void:
	if not InputMap.has_action(动作):
		InputMap.add_action(动作)
	InputMap.action_erase_events(动作)
	var 事件 := InputEventKey.new()
	事件.physical_keycode = 键码
	InputMap.action_add_event(动作, 事件)


## 该动作是否已经绑了这个键（`physical_keycode` 与 `keycode` 都看）。
static func 已有该键(动作: String, 键码: int) -> bool:
	for 事件 in InputMap.action_get_events(动作):
		if not 事件 is InputEventKey:
			continue
		var 按键 := 事件 as InputEventKey
		if int(按键.physical_keycode) == 键码 or int(按键.keycode) == 键码:
			return true
	return false

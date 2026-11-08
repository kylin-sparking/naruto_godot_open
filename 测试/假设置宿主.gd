extends Node

## 设置页回归用的假宿主：只提供 `设置窗口.gd` 会碰的出口 ——
## `_session.game_settings`（读）、`_set_check` / `_set_slider`（写，功能窗口.gd:3453-3457 同签名）、
## `_show_guild_action`（动作出口）。
## 独立成文件：往 GDScript.source_code 里塞多行字符串容易静默失配（好友那轮就把假宿主喂成假通过）。

class 假会话 extends Node:
	var game_settings := {
		"show_other_characters": false,		# 已遮罩 ⇒ 「遮罩其他玩家造型」该显示勾选
		"show_names": true,					# 未遮罩 ⇒ 不勾
		"mute_music": true,					# 「关闭地图音乐」该显示勾选
		"allow_whisper": true,				# 未禁止 ⇒ 不勾
		"music_volume": 0.5,
		"sound_volume": 1.0,
	}

	## 开窗信号（`设置窗口.gd` 点「快速键」页签时走这条，不是协议）。
	## 必须待在本类里：控制器是先取宿主的 `_session`，记在宿主身上门就验不到真通路。
	var 特性: Array[String] = []

	func request_feature(名: String) -> void:
		特性.append(名)

var _session := 假会话.new()
var 写: Array[String] = []
var 动作: Array[String] = []
var _缺件: Array[String] = []
## 真宿主 `功能窗口` 有 `_overlay`（`功能窗口.gd:171/677` 的「遮罩」节点），
## `输入确认弹.弹消息/弹出/弹勾选` 都往它上面挂。假宿主不给 ⇒ 快捷键窗的两枚二次确认
## 会走"_拿不到遮罩就直接执行"的回退分支，门就**永远测不到确认框那条路**。
var _overlay: Control


func _init() -> void:
	# ⚠ **必须在 `_init` 里建，不能等 `_ready`**：门是在 `SceneTree._initialize()` 里
	#    `root.add_child(宿)` 的，那一刻 `root` **还没进树**（实测 `root.is_inside_tree() == false`）
	#    ⇒ 宿主的 `_ready()` **一次都不跑**。第一版写在 `_ready` 里，遮罩恒 null，
	#    快捷键窗那两枚二次确认静默走"没有遮罩就直接执行"的回退分支，门永远看不见确认框。
	_overlay = Control.new()
	_overlay.name = "遮罩"
	_overlay.size = Vector2(960.0, 560.0)
	add_child(_overlay)


func _ready() -> void:
	_session.name = "假设置会话"		# ⚠ 别叫 GameSession：与 autoload 撞名会被改名，门就在读真数据还报绿


func _set_check(值: Variant, 键: String) -> void:
	写.append("%s=%s" % [键, 值])
	_session.game_settings[键] = 值


func _set_slider(值: float, 键: String) -> void:
	写.append("%s=%.2f" % [键, 值])
	_session.game_settings[键] = 值


## **照抄真宿主 `功能窗口._render_more_settings:3009-3020` 的危害**：它自己写 `more.visible = true`。
## 假宿主要是"乖乖只填值不显形"，门就复现不出实机那次返工（客户端层整片压在主页上）——
## 假宿主与真宿主行为不一致 = 假通过（同 好友页 §9 撞名那条教训）。
func _render_more_settings(页: Control, 设: Dictionary) -> void:
	var 层 := 页.get_node_or_null("更多设置") as Control
	if 层 == null:
		_缺件.append("更多设置")
		return
	层.visible = true
	var 面板 := 层.get_node_or_null("音乐面板/音量文字") as Label
	if 面板 != null:
		面板.text = "音乐音量  %d%%" % int(float(设.get("music_volume", 0.7)) * 100.0)
	var 主机 := 层.get_node_or_null("主机") as LineEdit
	if 主机 != null:
		主机.text = "127.0.0.1"


func _show_guild_action(名: String) -> void:
	动作.append(名)

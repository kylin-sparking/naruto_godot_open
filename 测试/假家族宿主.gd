extends Node

## 家族页回归用的假宿主：只提供 `家族窗口.gd` / `家族列表窗.gd` 会碰的两样东西
## —— `_session.guild`（数据源）与 `_show_guild_action()`（动作出口）。
## 独立成文件：往 GDScript.source_code 里塞多行字符串容易静默失配（上一版就这么把主窗喂成未入族态）。

class 假会话 extends Node:
	var guild := {"joined": true, "id": 7, "level": 3, "name": "木叶", "leader": "瑞树",
		"flag_name": "火之意志", "members": 1, "contribution": 120, "notice": "团结协作",
		"member_list": [{"name": "瑞树", "level": 60, "rank": 5, "contribution": 900,
			"weekly_contribution": 30}]}

var _session := 假会话.new()
var _overlay := Control.new()		# 真宿主的 `遮罩`：家族子窗壳要把浮窗挂在这里
var 动作: Array[String] = []

func _ready() -> void:
	add_child(_session)
	_overlay.name = "遮罩"
	_overlay.size = Vector2(960, 560)
	add_child(_overlay)

func _show_guild_action(名: String) -> void:
	动作.append(名)
